//+------------------------------------------------------------------------------+
//|                                                       Cosmos.mq5 
//|                                         Autor: Guilherme Martins
//|O principio de funcionamento do expert se baseia na comparacao de 
//|duas matrizes, match e now.
//|A matriz now armazena os ultimos 30 candles a serem analisados.
//|A matriz match armazena um padrão que se observado durante a execução do
//|expert gera uma entrada de compra ou venda.
//|Uma terceira matriz armazena a tolerancia entre as matrizes match e now 
//|se comparadas podem ser consideradas iguais.
//|Se as matrizes match e now forem consideradas iguais exceto por um erro
//|registrado na matriz erro Deve haver uma entrada em operacao.
//|A geracao dessas matrizes é inicialmente aleatoria e a medida que há acertos 
//|e erros no simulador elas são atualizadas e se tornam cada vez mais precisas.
//|Espero que quando for usado no mundo real este expert já esteja acertando mais
//|de 65%.
//+--------------------------------------------------------------------------------+
//TO DO
//Implementar sistema de vizinhanca separar loss e gain em funcoes distintas
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
COrderInfo info;
CTrade trade;
#define n_holes 16//metade inicial é hole de venda e a final hole de compra
#define n_candles 20
string paths[n_holes][3];

//+------------------------------------------------------------------+
//| Expert initialization                                |
//+------------------------------------------------------------------+
double Min_Val_Neg=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
ENUM_TIMEFRAMES Periodo=_Period;
int lotes=1;
double super_brain[n_holes][4][n_candles];//metade inicial do brain é venda, o resto é compra
double m_now[4][n_candles];
double m_erro_brain[n_holes][4][n_candles];
double m_e_temp_brain[n_holes][4][n_candles];
double Vet_temp_erro[n_holes];
double distancias[n_holes];
double Vet_erro[n_holes];//metade inicial desse vetor são erros aceitaveis de venda (black_hole) outra metade (white_hole)
double counter_t_profit=0.15;
int treinamento_ativo=0;
double Buy_Sell_Simulado=0;
bool fim_do_pregao=true;
datetime    tm=TimeCurrent();
MqlDateTime stm;
uint end=GetTickCount();        //horario atual em datetime nao convertido  
uint timer=GetTickCount();
datetime start=TimeCurrent();
int trade_type=0;
int qtdd_loss=0;
bool on_trade=false;
bool on_trade_simulado=false;
double Stop_tp_Simulado=0;
double last,ask,bid;
double distancia=2;
double temp_dist=30;
double dist_tp=25000;
double dist_sl=25005;
int simulacao_contabil=0;
int oper_counter=0;
double op_gain=0.42;
double Modulador=0.11;
double forcar_entrada=450;
//+------------------------------------------------------------------+
//| Salva matrizes n_holesx4xn_candles sempre que necessario                                                                 |
//+------------------------------------------------------------------+
void salvar_matriz_N_4_30(double  &matriz[][4][n_candles],string path)
  {
   int filehandle;
   double vec[n_candles];
   string add;
   string linha="";
   int i;
   int j=0;
   int file_handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
   FileWrite(file_handle,"matriz "+path+"\n");
   for(int w=n_holes-1;w>=0;w--)
     {
      for(j=0;j<4;j++)
        {
         for(i=0;i<n_candles;i++)
           {
            vec[i]=matriz[w][j][i];
            if(i<n_candles-1)
               linha+=string(vec[i])+",";
            else linha+=string(vec[i])+"\n";
           }
         //FileWrite(file_handle,linha);
         linha="";
         add=path+"_"+string(w)+"_"+string(j)+"_"+_Symbol+"_"+string(_Period);
         filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
         FileWriteArray(filehandle,vec,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }
     }
   FileClose(file_handle);
  }
//+------------------------------------------------------------------+
//|  funcao para salvar vetor dos erros aceitaveis                                                                |
//+------------------------------------------------------------------+
void salvar_vet_erro(double &erro[],string path)
  {
   string add=path+"_"+_Symbol+"_"+string(_Period);
   int handle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteArray(handle,erro,0,WHOLE_ARRAY);
   FileClose(handle);
  }
//+------------------------------------------------------------------+
//| le matrizes Nx4x30 do disco                                                                 |
//+------------------------------------------------------------------+
void ler_matriz_N_4_30(double  &matriz[][4][n_candles],string path,int tipo_erro)
  {
   int filehandle;
   double vec[n_candles];
   ArrayInitialize(vec,0);
   string add;
   int i=0;
   int j=0;
   for(int w=0;w<n_holes;w++)
     {
      for(j=0;j<4;j++)
        {
         add=path+"_"+string(w)+"_"+string(j)+"_"+_Symbol+"_"+string(_Period);
         if(FileIsExist(add,FILE_COMMON))
           {
            filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
            FileReadArray(filehandle,vec,0,WHOLE_ARRAY);
            FileClose(filehandle);
            for(i=0;i<n_candles;i++)matriz[w][j][i]=vec[i];
           }
         else
           {
            Alert("arquivo "+add+" nao encontrado");
            if(tipo_erro==true) for(i=0;i<n_candles;i++) matriz[w][j][i]=((1+(i/n_candles))*MathRand()*Min_Val_Neg/16383.5)+((1-i%2)*Min_Val_Neg/10000);
            else for(i=0;i<n_candles;i++) matriz[w][j][i]=(2*Min_Val_Neg*(16383.5-MathRand())/16383.5)+((1-i%2)*Min_Val_Neg/1000);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Aproxima matrizes por um fator 20%    N dimensoes                                                             |
//+------------------------------------------------------------------+
void aproximar_matriz_N(double &Matriz_temp[][4][n_candles],double &Matriz_erro[][4][n_candles],int D)
  {
   int i=0;
   for(int j=0;j<4;j++)
      for(i=0;i<n_candles;i++) Matriz_temp[D][j][i]=0.9*Matriz_temp[D][j][i]+0.1*Matriz_erro[D][j][i]+(16383.5-MathRand())*Min_Val_Neg/(1638350);//Oscilacao de 0.01*Min_Val_Neg
  }
//+------------------------------------------------------------------+
//|Copia M2 em M1       N dimensoes                                                           |
//+------------------------------------------------------------------+
void copiar_matriz_N(double &M1[][4][n_candles],double &M2[][4][n_candles],int D)
  {
   int i=0;
   for(int j=0;j<4;j++)
      for(i=0;i<n_candles;i++) M1[D][j][i]=M2[D][j][i];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void ler_vetor_erro_aceitavel(string path)//se não existir já cria
  {
   double erro=0;
   uint ok=0;
   string add=path+"_"+_Symbol+"_"+string(_Period);
   if(FileIsExist(add,FILE_COMMON))
     {
      int filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
        {
         ok=FileReadArray(filehandle,Vet_erro,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }
      else ArrayInitialize(Vet_erro,-2*Min_Val_Neg);
     }
   else  ArrayInitialize(Vet_erro,-2*Min_Val_Neg);
  }
//+----------------------------------------------------------------------------+
//Funcao para normalizar os erros aceitaveis, evita que os torne muito grandes                    |
//+----------------------------------------------------------------------------+
void Normalizar_erros()
  {
   int i=ArrayMaximum(Vet_erro,0,WHOLE_ARRAY);//Menor negativo
   double menor=Vet_erro[i];
   for(i=0;i<ArraySize(Vet_erro);i++)
      Vet_erro[i]=MathMin(Vet_erro[i]-menor,-0.002*Min_Val_Neg);//Esse valor não pode ser positivo senão ocorre overflow
  }
//+------------------------------------------------------------------+
//|
//+------------------------------------------------------------------+
void Embaralhar_matriz(double &matriz[][4][n_candles],int d)//usada quando a matriz de erro explode
  {
   int i=0;
   int j=0;
   for(j=0;j<4;j++)
      for(i=0;i<n_candles;i++)
         matriz[d][j][i]=0.05*(1+(i*0.1/n_candles))*Min_Val_Neg;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Recriar_matriz(double &M[][4][n_candles],double &M0[][n_candles],int d)//usado quando a matriz match explode
  {
   int j=0;
   int i=0;
   for(i=0;i<4;i++)
      for(j=0;j<n_candles;j++)
        {
         if(MathIsValidNumber(M[d][i][j]) && MathIsValidNumber(M0[i][j]))
            M[d][i][j]=0.3*M[d][i][j]+0.7*M0[i][j];
         else
            M[d][i][j]=0.01;
        }
  }
//+------------------------------------------------------------------+
//|funcao que compara parcialmente as matrizes match com as matrizes              |
//now(valores atuais) e decide se houve similaridade                 |  
//funcao mais requisitada do expert                                                                   |
//+------------------------------------------------------------------+
int compara_matrizes_N(double &match[][4][n_candles],double &now[][n_candles],double &m_erro[][4][n_candles],double &err_aceitavel[],int tipo)
  {
   int i=n_candles-1;
   int j=3;
   int hole=tipo;
//comecar pelos ultimos valores que correspondem aos candles mais atuais
   double d_temp=0;
   distancias[tipo-1]=-err_aceitavel[tipo-1];
   if(!MathIsValidNumber(err_aceitavel[tipo-1])) err_aceitavel[tipo-1]=-2*Min_Val_Neg;
   for(i=n_candles-1;i>=0;i--)
     {
      for(j=3;j>=0;j--)
        {
         if(MathIsValidNumber(match[tipo-1][j][i]) && MathIsValidNumber(now[j][i]) && MathIsValidNumber(m_erro[tipo-1][j][i]))
           {
            //funcao de ativacao
            if(m_erro[tipo-1][j][i]==0) m_erro[tipo-1][j][i]=0.0002*Min_Val_Neg;
           }
         else
           {
            now[j][i]=2.1*Min_Val_Neg;
            match[tipo-1][j][i]=2*Min_Val_Neg;
            m_erro[tipo-1][j][i]=0.001;
           }
         d_temp+=MathPow((now[j][i]-match[tipo-1][j][i])*m_erro[tipo-1][j][i],2);
        }
      distancias[tipo-1]+=MathSqrt(d_temp);
      d_temp=0;
     }
   if((distancias[tipo-1]+err_aceitavel[tipo-1])>=4*dist_tp+10*Min_Val_Neg)
     {
      printf("dist. muito grande: "+string(distancias[hole-1]+err_aceitavel[tipo-1])+" regenerando matriz: "+string(tipo-1)+" Erro Aceit.: "+string(err_aceitavel[tipo-1]));
      Embaralhar_matriz(m_erro_brain,hole-1);
      Recriar_matriz(super_brain,m_now,hole-1);
     }
   if(err_aceitavel[tipo-1]<=-2*dist_tp-10*Min_Val_Neg)
      err_aceitavel[tipo-1]=-dist_tp-0.1*Min_Val_Neg;
   return 1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Operar_na_Media(double &m_media[])
  {
   if(MathAbs(m_now[1][n_candles-1]-m_media[n_candles-1])<=0.5*Min_Val_Neg)
     {//compra
      if(m_now[3][n_candles-2]-m_media[n_candles-2]>=0.5*Min_Val_Neg)
        {
         if(m_now[3][n_candles-3]-m_media[n_candles-3]>=1.5*Min_Val_Neg)
           {
            if(m_now[3][n_candles-4]-m_media[n_candles-4]>=4*Min_Val_Neg || m_now[3][n_candles-3]-m_media[n_candles-3]>=4*Min_Val_Neg || m_now[3][n_candles-2]-m_media[n_candles-2]>=4*Min_Val_Neg)
              {
               return 1;//compra
              }
           }
        }
      //Venda
      else if(m_now[2][n_candles-2]-m_media[n_candles-2]<=-0.5*Min_Val_Neg)
        {
         if(m_now[2][n_candles-3]-m_media[n_candles-3]<=-1.5*Min_Val_Neg)
           {
            if(m_now[2][n_candles-4]-m_media[n_candles-4]<=-4*Min_Val_Neg || m_now[2][n_candles-3]-m_media[n_candles-3]<=-4*Min_Val_Neg || m_now[2][n_candles-2]-m_media[n_candles-2]<=-4*Min_Val_Neg)
              {
               return -1;//venda
              }
           }
        }
     }
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void afastar_candles(int num_candles,double fator_de_afastamento,int loss_gain)//caso loss afastar os candles mais proximos
  {
//caso de loss procurar o indice do menor erro e afastar
//significa que aquele valor nao era importante
//fazer essa alteração 30 x (25% dos candles)
//super_brain,m_erro_brain,m_e_temp_brain,Vet_erro,Vet_temp_erro,m_now
   int i=0;
   int w=0;
   int j=0;
   int ind[2]={0,0};
   int analisados[4][n_candles];
   ArrayFill(analisados,0,4*n_candles,0);
   for(i=0;i<4;i++)
      for(j=0;j<n_candles;j++)
        {
         analisados[i][j]=0;
        }
   num_candles=int(MathMin(num_candles,n_candles));
   double analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0])+0.5*Min_Val_Neg;
   if(loss_gain==0)//loss - afasta os mais proximos
     {
      for(j=0;j<num_candles;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<n_candles;w++)
               if(MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w])<analisado)
                 {
                  if(analisados[i][w]==0)
                    {
                     analisado=MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w]);//m_erro_w_h_1[i][w];
                     ind[0]=i;
                     ind[1]=w;
                    }
                 }
         //os minimos precisam ser afastados o suficiente para aumentar a distancia mais do que os maximos diminuiram
         m_erro_brain[trade_type-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);
         if(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]<0)
            super_brain[trade_type-1][ind[0]][ind[1]]+=Modulador*fator_de_afastamento*MathSqrt(MathPow((m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]),2))+3*Min_Val_Neg;//36
         else super_brain[trade_type-1][ind[0]][ind[1]]+=-Modulador*fator_de_afastamento*MathSqrt(MathPow((m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]),2))-3*Min_Val_Neg;
         m_erro_brain[trade_type-1][ind[0]][ind[1]]/=0.99*(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);
         if(super_brain[trade_type-1][ind[0]][ind[1]]!=0)
           {
            super_brain[trade_type-1][ind[0]][ind[1]]/=MathAbs(super_brain[trade_type-1][ind[0]][ind[1]]);
            super_brain[trade_type-1][ind[0]][ind[1]]*=MathMin(MathAbs(super_brain[trade_type-1][ind[0]][ind[1]]),12000*Min_Val_Neg);
           }
         analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
         analisados[ind[0]][ind[1]]=0;//desativado anti repeticao em loss
        }
     }
   else//gain
     {//afasta  os mais distantes
      analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0])-0.5*Min_Val_Neg;
      for(j=0;j<num_candles;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<n_candles;w++)
               if(MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w])>analisado)
                 {
                  if(analisados[i][w]==0)
                    {
                     analisado=MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w]);
                     ind[0]=i;
                     ind[1]=w;
                    }
                 }
         if(super_brain[trade_type-1][ind[0]][ind[1]]!=0)
           {
            super_brain[trade_type-1][ind[0]][ind[1]]/=MathAbs(super_brain[trade_type-1][ind[0]][ind[1]]);
            super_brain[trade_type-1][ind[0]][ind[1]]*=MathMin(MathAbs(super_brain[trade_type-1][ind[0]][ind[1]]),1200*Min_Val_Neg);
           }
         m_erro_brain[trade_type-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);
         if(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]>0)
           {
            super_brain[trade_type-1][ind[0]][ind[1]]=super_brain[trade_type-1][ind[0]][ind[1]]-Modulador*fator_de_afastamento*MathSqrt(MathPow((m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]),2))-0.01*(MathRand()/1638.35)*Min_Val_Neg;//36 - +232.3//30 -100
           }
         else
           {
            super_brain[trade_type-1][ind[0]][ind[1]]=super_brain[trade_type-1][ind[0]][ind[1]]+Modulador*fator_de_afastamento*MathSqrt(MathPow((m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]),2))+0.01*(MathRand()/1638.35)*Min_Val_Neg;
           }
         m_erro_brain[trade_type-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);
         if(MathAbs(m_erro_brain[trade_type-1][ind[0]][ind[1]])<0.0001*Min_Val_Neg)
            m_erro_brain[trade_type-1][ind[0]][ind[1]]+=0.00005*Min_Val_Neg *m_erro_brain[trade_type-1][ind[0]][ind[1]]/MathAbs(m_erro_brain[trade_type-1][ind[0]][ind[1]]);//Para não zerar m_erro               
         analisados[ind[0]][ind[1]]=1;
         analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void aproximar_candles(int num_candles,double fator_de_aproximacao,int loss_gain)
  {
   num_candles=int(MathMin(num_candles,n_candles));
   int ind[2]={0,0};
   int i=0;
   int j=0;
   int w=0;
   double analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
   int analisados[4][n_candles];
   ArrayFill(analisados,0,4*n_candles,0);
   for(i=0;i<4;i++)
      for(j=0;j<n_candles;j++)
        {
         analisados[i][j]=0;
        }
//aproximar os mais distantes
   if(loss_gain==0)//loss
     {
      for(j=0;j<num_candles;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<n_candles;w++)
               if(MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w])>analisado)
                 {
                  if(analisados[i][w]==0)
                    {
                     analisado=MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w]);
                     ind[0]=i;
                     ind[1]=w;
                    }
                 }
         m_erro_brain[trade_type-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);
         if(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]<0)
           {
            super_brain[trade_type-1][ind[0]][ind[1]]=super_brain[trade_type-1][ind[0]][ind[1]]+Modulador*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]])-2*Min_Val_Neg;//38
           }
         else
           {
            super_brain[trade_type-1][ind[0]][ind[1]]=super_brain[trade_type-1][ind[0]][ind[1]]+Modulador*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]])+2*Min_Val_Neg;
           }
         m_erro_brain[trade_type-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);
         //funcao de ativacao
         super_brain[trade_type-1][ind[0]][ind[1]]=MathMin(super_brain[trade_type-1][ind[0]][ind[1]],12000*Min_Val_Neg);
         super_brain[trade_type-1][ind[0]][ind[1]]=MathMax(super_brain[trade_type-1][ind[0]][ind[1]],-12000*Min_Val_Neg);
         //
         m_e_temp_brain[trade_type-1][ind[0]][ind[1]]+=(0.005-(MathRand()/1638350))*Min_Val_Neg;// oscilação de 0.01*0.5 pontos
         analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
         analisados[ind[0]][ind[1]]=0;//desativado sistema anti repeticao em loss
        }
     }
   else//gain
     {
      //aproximar os menos distantes
      for(j=0;j<num_candles;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<n_candles;w++)
               if(MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w])<analisado && analisados[i][w]==0)
                 {
                  analisado=MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w]);
                  ind[0]=i;
                  ind[1]=w;
                 }
         m_erro_brain[trade_type-1][ind[0]][ind[1]]*=m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]];

         super_brain[trade_type-1][ind[0]][ind[1]]=super_brain[trade_type-1][ind[0]][ind[1]]+Modulador*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);//44//48 -300

         m_erro_brain[trade_type-1][ind[0]][ind[1]]/=1.001*m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]];
         //funcao de ativacao
         super_brain[trade_type-1][ind[0]][ind[1]]=MathMin(super_brain[trade_type-1][ind[0]][ind[1]],12000*Min_Val_Neg);
         super_brain[trade_type-1][ind[0]][ind[1]]=MathMax(super_brain[trade_type-1][ind[0]][ind[1]],-12000*Min_Val_Neg);
         //
         analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
         analisados[ind[0]][ind[1]]=1;
        }
     }
  }
//+------------------------------------------------------------------+
//|Inicio do expert                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//Inicializacao das strings address dos valores de treinamento
   ArrayInitialize(Vet_erro,1);
   ArrayInitialize(Vet_temp_erro,1);
   for(int j=0;j<(n_holes/2);j++)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      paths[j][0]="cosmos_training"+"//"+"erro"+string(j+1);
      paths[j][1]="cosmos_training"+"//"+"match"+string(j+1);
      paths[j][2]="cosmos_training"+"//"+"be"+string(j+1);
     }
   for(int j=n_holes/2;j<(n_holes);j++)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      paths[j][0]="cosmos_training"+"//"+"erro"+string(j+1);
      paths[j][1]="cosmos_training"+"//"+"match"+string(j+1);
      paths[j][2]="cosmos_training"+"//"+"we"+string(j+1);
     }
//---Inicializar Menor valor negociavel
   if(_Symbol=="WINQ19" || _Symbol=="WIN$" || _Symbol=="WINV19" || _Symbol=="WINZ19" || _Symbol=="WING20")
     {
      Min_Val_Neg=Min_Val_Neg*7;
     }
//--- Inicializar o gerador de números aleatórios  
   MathSrand(uint(GetMicrosecondCount()));

//+------------------------------------------------------------------+
//| ler/inicializar matrizes match                                                                 |
//+------------------------------------------------------------------+
   ler_matriz_N_4_30(super_brain,"cosmos_training"+"//"+"match",0);

//Ler/inicializar matriz diferencas/erro
   ler_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro",1);

//Gerar arrays copia dos arrays salvos
//Usados para retornar ao valor anterior caso de loss em uma operacao
   for(int x=0;x<n_holes;x++)
      copiar_matriz_N(m_e_temp_brain,m_erro_brain,x);

//ler erros aceitaveis
   ler_vetor_erro_aceitavel("cosmos_training"+"//"+"Ve");
   ArrayInitialize(Vet_temp_erro,0);
   ArrayInitialize(distancias,0.0);
   EventSetMillisecondTimer(200);// number of seconds ->0.2 segundos por evento
   tm=TimeCurrent();
   TimeToStruct(tm,stm);
   fim_do_pregao=stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<9) || (stm.hour==9 && stm.min<=30);
   start=TimeCurrent();
   end=GetTickCount()-250000;
   forcar_entrada=550;
   trade_type=0;
   on_trade=false;
   qtdd_loss=0;//enquanto o dia não inicia essa variavel se mantem zerada
   if(PositionsTotal()!=0) trade.PositionClose(_Symbol,ULONG_MAX);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   printf("numero de operacoes simuladas: "+string(oper_counter));
//---desinicializar Menor valor negociavel
   if(_Symbol=="WINQ19" || _Symbol=="WIN$" || _Symbol=="WINV19" || _Symbol=="WINZ19" || _Symbol=="WING20")
     {
      Min_Val_Neg=Min_Val_Neg*7;
     }
   EventKillTimer();
//salvar os arrays de match (brain)
   salvar_matriz_N_4_30(super_brain,"cosmos_training"+"//"+"match");
//salvar as matrizes de erro
   salvar_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro");
//Salvar os erros aceitaveis
   salvar_vet_erro(Vet_erro,"cosmos_training"+"//"+"Ve");
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnTick()
  {
   int posicoes=PositionsTotal();
//Analise de stops
//chamada da funcao situacao_stops_dia que promove o treinamento dos arrays
   if(PositionsTotal()==0 || on_trade_simulado==false)
     {
      if(on_trade==true)
        {//houve uma ordem finalizada recentemente
         on_trade=false;
         if(treinamento_ativo==0)
           {//stopou em caso real
            end=GetTickCount();
           }
         if(stops_N_dimensional(super_brain,m_erro_brain,m_e_temp_brain,Vet_erro,Vet_temp_erro,m_now)) qtdd_loss=1;

         //Atencao retirado o incremento para treinamento
         //else qtdd_loss-=1;
         //mudar depois para resolver o problema do reinicio do bot
         //rodar o historico inteiro do dia pode ser uma solução sacrificando processamento
        }
     }
   int i=0;
   if(PositionsTotal()==0 && fim_do_pregao==false && qtdd_loss<=3 && on_trade==false)
     {
      double close[n_candles];
      double open[n_candles];
      double high[n_candles];
      double low[n_candles];
      double m_close[n_candles];
/*double m_open[n_candles];
      double m_high[n_candles];
      double m_low[n_candles];
      int m_handle_open=iMA(_Symbol,_Period,n_candles,0,MODE_SMA,PRICE_OPEN);
      int m_handle_close=iMA(_Symbol,_Period,n_candles,0,MODE_SMA,PRICE_CLOSE);
      int m_handle_high=iMA(_Symbol,_Period,n_candles,0,MODE_SMA,PRICE_HIGH);
      int m_handle_low=iMA(_Symbol,_Period,n_candles,0,MODE_SMA,PRICE_LOW);
      if(CopyBuffer(m_handle_open,0,0,n_candles,m_open)<0)ArrayInitialize(m_open,12000*Min_Val_Neg);
      if(CopyBuffer(m_handle_close,0,0,n_candles,m_close)<0)ArrayInitialize(m_close,12000*Min_Val_Neg);
      if(CopyBuffer(m_handle_high,0,0,n_candles,m_high)<0)ArrayInitialize(m_high,12000*Min_Val_Neg);
      if(CopyBuffer(m_handle_low,0,0,n_candles,m_low)<0)ArrayInitialize(m_low,12000*Min_Val_Neg);*/
      if(CopyClose(_Symbol,Periodo,0,n_candles,close)!=-1 && CopyOpen(_Symbol,Periodo,0,n_candles,open)!=-1 && CopyHigh(_Symbol,Periodo,0,n_candles,high)!=-1 && CopyLow(_Symbol,Periodo,0,n_candles,low)!=-1)
        {
         i=0;
         while(i<n_candles)
           {
            //copiano candles 30 ultimos normalizados
            m_now[0][i]=open[i];//m_open[n_candles-1];
            m_now[1][i]=close[i];//m_close[n_candles-1];
            m_now[2][i]=high[i];//m_high[n_candles-1];
            m_now[3][i]=low[i];//m_low[n_candles-1];
            i+=1;
           }
        }
      int m_handle_close=iMA(_Symbol,_Period,21,0,MODE_EMA,PRICE_CLOSE);
      if(CopyBuffer(m_handle_close,0,0,n_candles,m_close)<0)ArrayInitialize(m_close,12000*Min_Val_Neg);
      int op_media=Operar_na_Media(m_close);
      //| Inicio da seção de comparações  
      double comparacoes[n_holes];
      for(int Type=1;Type<=n_holes;Type++)
         comparacoes[Type-1]=compara_matrizes_N(super_brain,m_now,m_erro_brain,Vet_erro,Type);//vetor distancias é preenchido aqui
      double d_venda_menor=distancias[0]+Vet_erro[0];
      int alfa=0;
      int alfa_c=0;
      int alfa_v=0;
      for(alfa=0;alfa<n_holes/2;alfa++)
        {
         if((distancias[alfa]+Vet_erro[alfa])<d_venda_menor)
           {
            d_venda_menor=distancias[alfa]+Vet_erro[alfa];//distancia sem penalidade
            alfa_v=alfa;
           }
        }
      double d_compra_menor=distancias[0]+Vet_erro[0];
      for(alfa=n_holes/2;alfa<n_holes;alfa++)
        {
         if((distancias[alfa]+Vet_erro[alfa])<d_compra_menor)
           {
            d_compra_menor=distancias[alfa]+Vet_erro[alfa];
            alfa_c=alfa;
           }
        }
      bool venda=false;
      bool compra=false;
      if(d_venda_menor<d_compra_menor || d_venda_menor<dist_tp) venda=true;
      else if(d_compra_menor<d_venda_menor || d_compra_menor<dist_tp)compra=true;
      double tendencia=m_close[n_candles-1]-m_close[int(0.2*n_candles)];
      last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
      if(compra && (d_compra_menor-Vet_erro[alfa_c]<1*distancia || op_media==1) && PositionsTotal()==0 && on_trade==false)
        {
         //comprar
         timer=GetTickCount();
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         ask=int((1000*ask)+499)-(int((1000*ask)+499)%500);
         ask/=1000;
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         bid=int(1000*bid)-(int(1000*bid)%500);
         bid/=1000;
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if((d_compra_menor)<1.01*(0.95*dist_tp+0.05*dist_sl+5*Min_Val_Neg))simulacao_contabil=1;//operar na media nao contabiliza
         else simulacao_contabil=0;//compra simulada não será contabilizada
         if(tendencia>=3*Min_Val_Neg && int(100*ask)%50==0 && (forcar_entrada)>=900 && (op_media==1 || ((d_compra_menor)<1.1*dist_tp && counter_t_profit>op_gain)))
           {
            trade_type=1+ArrayMinimum(distancias,n_holes/2,n_holes/2);
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra dist "+string(trade_type)+" mean "+string(op_media));
            printf("------------Compra--------"+string(ask-8*Min_Val_Neg));
            Buy_Sell_Simulado=ask;
            Sleep(3000);
            on_trade=true;
            on_trade_simulado=true;
            treinamento_ativo=0;
            end=GetTickCount();
            forcar_entrada=1;
           }
         else//simula uma compra
           {
            if(forcar_entrada>=18000) forcar_entrada=900;
/*if(int(100*ask)%50!=0)printf("problemas com request de Valor Oferecido - Ask Buy");
            //else if(counter_t_profit<=op_gain) printf("Compra anulada por excesso de loss");
            else if(d_venda_menor>1.1*dist_tp) printf("Compra anulada por distancia muito grande");
            else if(forcar_entrada<900)printf("Aguardar "+string(900-forcar_entrada)+" segundos para a proxima Compra");
            else printf("Venda anulada, investigar motivo");*/
            Stop_tp_Simulado=last;
            if(on_trade_simulado==false)
              {
               Buy_Sell_Simulado=ask;
               trade_type=1+ArrayMinimum(distancias,n_holes/2,n_holes/2);
               on_trade_simulado=true;
               treinamento_ativo=1;
               printf("distancia de entrada em compra: "+string(distancia)+" dist hole: "+string(distancias[ArrayMinimum(distancias,n_holes/2,n_holes/2)]));
              }
            else if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
              {
               on_trade=true;
               treinamento_ativo=6;
               on_trade_simulado=false;
              }
            //on_trade=true;
           }
        }
      else if(venda && (d_venda_menor-Vet_erro[alfa_v]<1*distancia || op_media==-1) && PositionsTotal()==0 && on_trade==false)
        {
         timer=GetTickCount();
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         bid=int(1000*bid)-(int(100*bid)%500);
         bid/=1000;
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         ask=int((1000*ask)+499)-(int((1000*ask)+499)%500);
         ask/=1000;
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         //Analise de venda
         if(((d_venda_menor)<1.01*(0.95*dist_tp+0.05*dist_sl+5*Min_Val_Neg)))simulacao_contabil=1;//valido como entrada para atualizar parametros
         else simulacao_contabil=0;
         if(tendencia<=-3*Min_Val_Neg && int(100*bid)%50==0 && (forcar_entrada)>=900 && (op_media==-1 || ((d_venda_menor)<1.1*dist_tp && counter_t_profit>=op_gain)))//aguarda ao menos 5min antes da proxima operação real 
           {
            //vender
            trade_type=1+ArrayMinimum(distancias,0,n_holes/2);
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda dist "+string(trade_type)+" mean "+string(op_media));
            printf("------------V. distancia "+string(bid+8*Min_Val_Neg)+" "+string(trade_type));
            Buy_Sell_Simulado=bid;
            Sleep(3000);
            on_trade=true;
            on_trade_simulado=true;
            treinamento_ativo=0;
            end=GetTickCount();
            forcar_entrada=1;
           }
         else//só  entrada venda virtual
           {
            if(forcar_entrada>=18000) forcar_entrada=900;
/*if(int(100*bid)%50!=0) printf("problemas com request de Valor Pedido - Bid Sell");
            else if(counter_t_profit<=op_gain) printf("Venda anulada por excesso de loss");
            else if(d_venda_menor>=1.1*dist_tp) printf("Venda anulada por distancia muito grande");
            else if((forcar_entrada)<900)printf("Aguardar "+string(900-forcar_entrada)+" segundos para a proxima Venda");
            else printf("Venda anulada, investigar motivo");*/
            Stop_tp_Simulado=last;
            if(on_trade_simulado==false)
              {//primeira passagem pela entrada virtual
               Buy_Sell_Simulado=bid;
               trade_type=1+ArrayMinimum(distancias,0,n_holes/2);
               on_trade_simulado=true;
               treinamento_ativo=-1;
               printf("distancia de entrada em venda: "+string(distancia)+" dist hole: "+string(distancias[ArrayMinimum(distancias,0,n_holes/2)]));
              }
            else if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
              {//loss ou gain virtual
               on_trade=true;
               treinamento_ativo=-6;//entra novamente na operacao stop como treinamento forcado de venda
               on_trade_simulado=false; //funcao semelhante ao getpositions
              }
           }
        }

      else
        {
         ArrayFill(comparacoes,0,n_holes,0);
        }
     }
   else
     {
      if(PositionsTotal()!=0)
        {
         counter_t_profit=0.20;
         distancia-=0.00002*Min_Val_Neg;
         end=GetTickCount();
         forcar_entrada=1;
        }
     }
  }
//+------------------------------------------------------------------+
//| funcao para atualizar valores ao fim de cada operacao     
//| retorna true caso seja um loss                                                            |
//+------------------------------------------------------------------+
bool stops_N_dimensional(double &match[][4][n_candles],double &m_erro[][4][n_candles],double &m_temp_erro[][4][n_candles],double &erro[],double &temp_erro[],double &mnow[][n_candles])
  {
   bool stop=false;
   double last_trade;
   double l_last_trade;
   int hole=trade_type;
   if(treinamento_ativo==0)//operacao foi real
     {
      HistorySelect(start,TimeCurrent());
      int total=HistoryOrdersTotal();
      ulong last_ticket=HistoryOrderGetTicket(total-1);
      ulong l_last_ticket=HistoryOrderGetTicket(total-2);
      last_trade=double(HistoryOrderGetDouble(last_ticket,ORDER_PRICE_OPEN));
      l_last_trade=double(HistoryOrderGetDouble(l_last_ticket,ORDER_PRICE_OPEN));
      end=GetTickCount();
      stop=true;//considera um stop true, caso seja gain esse valor será atualizado para false
      printf("operaçao real");
     }
   else//operacao só treinamento
     {
      last_trade=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
      l_last_trade=Buy_Sell_Simulado;
     }
//double minimum;
//double maximum;
   int i=0;
   int w=0;
   int j=0;
   int ind_max[2]={0,0};
   int ind_min[2]={0,0};
   bool compra=false;
   bool venda =false;
   if(trade_type!=0 && trade_type<=(n_holes/2))venda=true;
   else if(trade_type>(n_holes/2)) compra=true;
   if((compra && l_last_trade>=last_trade) || (venda && l_last_trade<=last_trade))
     {//--================----loss 
      oper_counter-=1;
      //caso de loss procurar o indice do maior erro e aproximar
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (10% da matriz)
      aproximar_candles(int(0.2*n_candles),0.2,0);
      //manter a mesma distancia para não alterar o resultado da operaação de afastamento
      //caso de loss procurar o indice do menor erro e afastar
      //significa que aquele valor nao era importante
      //fazer essa alteração  (25% dos candles)
      afastar_candles(int(0.4*n_candles),0.4,0);
      //----------trabalhando com as vizinhancas
      //caso de loss procurar o indice do menor erro da operacao inversa e tratar como gain
      //significa que aquele valor era para ser o de real entrada
      //fazer essa alteração  (25% dos candles)
      int temp_trade_type=trade_type;
      if(venda==true)
         trade_type=1+ArrayMinimum(distancias,n_holes/2,n_holes/2);
      //compra==true
      else trade_type=1+ArrayMinimum(distancias,0,n_holes/2);

      trade_type=temp_trade_type;
      double d;
      if(compra==true) d=ArrayMinimum(distancias,0,n_holes/2);
      else d=ArrayMinimum(distancias,n_holes/2,n_holes/2);
      Normalizar_erros();//normalizar erros
      erro[hole-1]=0.8*erro[hole-1]+0.2*temp_erro[hole-1]-(0.1*distancia);//diminuir esse valor para dificultar um nova entrada (para treinamento)
      if(simulacao_contabil==1)
        {
         counter_t_profit+=(0-counter_t_profit)/21;
         dist_sl+=(distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_sl)/(0.65*n_candles);
        }
      else dist_sl+=(distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_sl)/200;
      copiar_matriz_N(m_erro,m_temp_erro,trade_type-1);
      Modulador+=(16383.5-MathRand())*Min_Val_Neg/(163835000);
      distancia=temp_dist*0.2;
      //ArrayPrint(distancias);

      printf("stop loss caso: "+string(trade_type)+" dist t_prof.: "+string(dist_tp)+" Err acc.: "+string(erro[hole-1])+" tk p "+string(counter_t_profit)+" op_gain: "+string(op_gain));
     }
//foi gain 
   else if((compra && l_last_trade<last_trade) || (venda && l_last_trade>last_trade))
     {
      oper_counter+=1;
      //caso de gain procurar o indice de maior  erro e aumentar a distancia
      //reduzir o erro de gatilho proporcionalmente diminuindo a significancia
      //significa que aquele valor realmente não era importante
      //fazer essa alteração 6 x (5% dos candles)
      afastar_candles(int(0.4*n_candles),0.3,1);
      //caso de gain procurar o indice de menor  erro e reduzir a distancia
      //alterar m_erro para manter a mesma distancia (aumentar a significancia)
      //significa que aquele valor era importante
      //fazer essa alteração 6 x (5% dos candles)
      aproximar_candles(int(0.5*n_candles),0.4,1);
      //----------trabalhando com as vizinhancas
      //caso de gain procurar o indice do menor erro da operacao inversa e tratar como loss
      //significa que aquele valor era para estar distante da real entrada
      //fazer essa alteração  (5% dos candles)
      int temp_trade_type=trade_type;
      if(venda==true)
         trade_type=1+ArrayMinimum(distancias,n_holes/2,n_holes/2);//procurar menor distancia nas compras
      //compra==true
      else trade_type=1+ArrayMinimum(distancias,0,n_holes/2);
      trade_type=temp_trade_type;
      //absorver o erro aceitavel
      temp_erro[hole-1]=(0.05*erro[hole-1]+0.95*temp_erro[hole-1]);//Absorver valor que deu certo para futuro loss
      erro[hole-1]+=0.01*(2*(16383.5-MathRand())*Min_Val_Neg/(16383.5));//Oscilar em 0.04* o min val neg
      Normalizar_erros();//normalizar erros
      if(simulacao_contabil==1)
        {
         counter_t_profit+=(1-counter_t_profit)/21;//media exponencial 9
         dist_tp=MathMin(dist_tp+((distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_tp)/(0.65*n_candles)),30000);
        }
      else dist_tp=MathMin(dist_tp+((distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_tp)/(200)),30000);
      printf("t. prof. caso: "+string(trade_type)+" dist t_prof.: "+string(dist_tp)+" Err acc.: "+string(erro[hole-1])+" tk p "+string(counter_t_profit)+" op_gain: "+string(op_gain));
      op_gain=MathMax(op_gain+(counter_t_profit-op_gain)/n_holes,0.75);
      aproximar_matriz_N(m_temp_erro,m_erro,trade_type-1);
      temp_dist+=(distancias[trade_type-1]-temp_dist)/17;
      distancia=0.2*temp_dist;
      copiar_matriz_N(m_erro,m_temp_erro,trade_type-1);
      stop=false;//mesmo sendo operacao real se for gain stop returna false
     }
   else
     {
      printf("Tendencia reversa 0x0 compra: "+string(compra)+" venda: "+string(venda));
     }
   if(trade_type!=0)
     {
      salvar_matriz_N_4_30(match,"cosmos_training"+"//"+"match");
      salvar_matriz_N_4_30(m_erro,"cosmos_training"+"//"+"erro");
      salvar_vet_erro(Vet_erro,"cosmos_training"+"//"+"Ve");
     }
   if(stop==true)trade_type=0;
   return stop;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   timer=GetTickCount();
   tm=TimeCurrent();
   TimeToStruct(tm,stm);
   fim_do_pregao=stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<9) || (stm.hour==9 && stm.min<=30);
   if(fim_do_pregao==true)
     {
      //operar apenas apos 9:30 e antes das 17:30 
      start=TimeCurrent();
      end=GetTickCount()-250000;
      forcar_entrada=550;
      trade_type=0;
      on_trade=false;
      qtdd_loss=0;//enquanto o dia não inicia essa variavel se mantem zerada
      if(PositionsTotal()!=0) trade.PositionClose(_Symbol,ULONG_MAX);
     }
   else
     {
      forcar_entrada=MathMin(forcar_entrada+0.2,18000);
      double incrementer=distancias[ArrayMinimum(distancias,0,n_holes)]/3800;
      distancia=distancia+(incrementer);//(10s)*60-->300s=5min Entra ao menos 1 vez a cada 5min
      int temp_t_type=trade_type;
      for(trade_type=1;trade_type<=n_holes;trade_type++)
         if(int(forcar_entrada)%499==0)
           {
            aproximar_candles(n_candles,0.008,1);
            forcar_entrada+=1;
           }
      trade_type=temp_t_type;
     }
  }
//+------------------------------------------------------------------+
