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
#define n_holes 20//metade inicial é hole de venda e a final hole de compra, declarar aqui apenas valores par
#define n_candles 16
#define prof_cube 15


//+------------------------------------------------------------------+
//| Expert initialization                                |
//+------------------------------------------------------------------+
double Min_Val_Neg=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
int Clear=1;
ENUM_TIMEFRAMES Periodo=_Period;
int lotes=1;
double super_brain[n_holes][prof_cube][n_candles];//metade inicial do brain é venda, o resto é compra
double m_now[prof_cube][n_candles];
double m_erro_brain[n_holes][prof_cube][n_candles];
double m_e_temp_brain[n_holes][prof_cube][n_candles];
double Vet_temp_erro[n_holes];
double distancias[n_holes];
double Vet_erro[n_holes];//metade inicial desse vetor são erros aceitaveis de venda (black_hole) outra metade (white_hole)
double counter_t_profit=0.5;
int treinamento_ativo=0;
double Buy_Sell_Simulado=0;
bool fim_do_pregao=true;
datetime    tm=TimeCurrent();
MqlDateTime stm;
uint end=GetTickCount();        //horario atual em datetime nao convertido
uint timer=GetTickCount();
datetime start=TimeCurrent();
int trade_type=1;
int trade_type_reverso=2;
int qtdd_loss=0;
bool on_trade=false;
bool on_trade_simulado=false;
double Stop_tp_Simulado=0;
double last,ask,bid;
double distancia=40000;
double temp_dist=30;
double dist_tp=2500;
double dist_sl=3500;
int simulacao_contabil=0;
int oper_counter=0;
double op_gain=1;
int op_media=0;
double forcar_entrada=450;
double parametrizadores[10];
double save_ma=20;
double save_tend=1;
double Modulador=0.05;
double close[n_candles];
double open[n_candles];
double high[n_candles];
double low[n_candles];
double m_close[n_candles];
double m_parametros[prof_cube];
double m_pre_par[prof_cube];
double lucro_prej=0;
int Type=0;
int analisados[prof_cube][n_candles];
double Const_dist=3500;
double tendencia=0;
int loss_suportavel_dia=1;//qtdd de loss suportavel em um dia
int posicoes=0;
int qtdd_op_dia=0;
bool fechou_posicao=false;
double stopar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
double gainar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
int m_handle_close=NULL;
int m_handle_tend=NULL;
int m_handle_ima=NULL;
int primeiro_t_media_cp=0;
int primeiro_t_media_venda=0;
int temporizator=2701;
double last_op_gain=0;
int alfa_c=0;
int alfa_v=0;
//+------------------------------------------------------------------+
//| Salva matrizes n_holesx4xn_candles sempre que necessario                                                                 |
//+------------------------------------------------------------------+
void salvar_matriz_N_4_30(double  &matriz[][prof_cube][n_candles],string path)
  {
   int filehandle;
   double vec[n_candles];
   string add;
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string linha="";
   int i;
   int j=0;
//int file_handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
//FileWrite(file_handle,"matriz "+path+"\n");
   for(int w=n_holes-1; w>=0; w--)
     {
      for(j=0; j<prof_cube; j++)
        {
         for(i=0; i<n_candles; i++)
           {
            vec[i]=matriz[w][j][i];
            /*if(i<n_candles-1)
                           linha+=string(vec[i])+",";
                        else linha+=string(vec[i])+"\n";*/
           }
         //FileWrite(file_handle,linha);
         //linha="";"cosmos_training"+"//"+"match"
         add=Ativo+"_"+string(_Period)+"//"+path+"_"+string(w)+"_"+string(j);
         filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
         FileWriteArray(filehandle,vec,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }
     }
  }
//+------------------------------------------------------------------+
//|  funcao para salvar vetor dos erros aceitaveis                                                                |
//+------------------------------------------------------------------+
void salvar_vet_erro(double &erro[],string path)
  {
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   int handle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteArray(handle,erro,0,WHOLE_ARRAY);
   FileClose(handle);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void salvar_parametrizadores(double &paramet[],string path)
  {
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   int handle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteArray(handle,paramet,0,WHOLE_ARRAY);
   FileClose(handle);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void salvar_m_parametros(double &paramet[],string path)
  {
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   int handle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteArray(handle,paramet,0,WHOLE_ARRAY);
   FileClose(handle);
  }
//+------------------------------------------------------------------+
//| le matrizes Nx4x30 do disco                                                                 |
//+------------------------------------------------------------------+
void ler_matriz_N_4_30(double  &matriz[][prof_cube][n_candles],string path,bool tipo_erro)
  {
   int filehandle;
   double vec[n_candles];
   ArrayInitialize(vec,0);
   string add;
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   int i=0;
   int j=0;
   for(int w=0; w<n_holes; w++)
     {
      for(j=0; j<prof_cube; j++)
        {
         add=Ativo+"_"+string(_Period)+"//"+path+"_"+string(w)+"_"+string(j);
         if(FileIsExist(add,FILE_COMMON))
           {
            filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
            FileReadArray(filehandle,vec,0,WHOLE_ARRAY);
            FileClose(filehandle);
            for(i=0; i<n_candles; i++)
               matriz[w][j][i]=vec[i];
           }
         else
           {
            Alert("arquivo "+add+" nao encontrado");
            if(tipo_erro==true)
               for(i=0; i<n_candles; i++)
                  matriz[w][j][i]=((1+(i/n_candles))*MathRand()*Min_Val_Neg/16383.5)+((1-i%2)*Min_Val_Neg/10000);
            else
               for(i=0; i<n_candles; i++)
                  matriz[w][j][i]=(2*Min_Val_Neg*(16383.5-MathRand())/16383.5)+((1-i%2)*Min_Val_Neg/1000);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Aproxima matrizes por um fator 10%    N dimensoes                                                             |
//+------------------------------------------------------------------+
void aproximar_matriz_N(double &Matriz_temp[][prof_cube][n_candles],double &Matriz_erro[][prof_cube][n_candles],int D)
  {
   int i=0;
   for(int j=0; j<prof_cube; j++)
      for(i=0; i<n_candles; i++)
         Matriz_temp[D][j][i]=0.9*Matriz_temp[D][j][i]+0.1*Matriz_erro[D][j][i]+(16383.5-MathRand())*Min_Val_Neg/(1638350);//Oscilacao de 0.01*Min_Val_Neg
  }
//+------------------------------------------------------------------+
//|Copia M2 em M1       N dimensoes                                                           |
//+------------------------------------------------------------------+
void copiar_matriz_N(double &M1[][prof_cube][n_candles],double &M2[][prof_cube][n_candles],int D)
  {
   int i=0;
   for(int j=0; j<prof_cube; j++)
      for(i=0; i<n_candles; i++)
         M1[D][j][i]=M2[D][j][i];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ler_vetor_erro_aceitavel(string path)//se não existir já cria
  {
   double erro=0;
   uint ok=0;
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   if(FileIsExist(add,FILE_COMMON))
     {
      int filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
        {
         ok=FileReadArray(filehandle,Vet_erro,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }
      else
         ArrayInitialize(Vet_erro,-2*Min_Val_Neg);
     }
   else
      ArrayInitialize(Vet_erro,-2*Min_Val_Neg);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ler_vetor_parametros(string path)//se não existir já cria
  {
   uint ok=0;
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   ArrayFill(parametrizadores,0,10,0);
//parametros de controle
   parametrizadores[0]=Modulador;
   parametrizadores[1]=20;
   parametrizadores[2]=0.2; //modulo tendencia
   parametrizadores[3]=dist_tp;
   parametrizadores[4]=dist_sl;
   parametrizadores[5]=7000*Min_Val_Neg;
   if(FileIsExist(add,FILE_COMMON))
     {
      int filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
        {
         ok=FileReadArray(filehandle,parametrizadores,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }

     }
   /*parametrizadores[0]=0.0000001;
      parametrizadores[2]=0.03;*/
//parametrizadores[5]=7000*Min_Val_Neg;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ler_matriz_parametros(string path)//se não existir já cria//nunca chamar antes de ler parametros
  {
   uint ok=0;
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   ArrayInitialize(m_parametros,0.1*Min_Val_Neg);
//parametros de controle
   m_parametros[0]=7000*Min_Val_Neg;
   m_parametros[1]=7000*Min_Val_Neg;
   m_parametros[2]=7000*Min_Val_Neg; //modulo tendencia
   m_parametros[3]=7000*Min_Val_Neg;
   m_parametros[4]=7000*Min_Val_Neg;
   for(int i=5; i<prof_cube; i++)
      m_parametros[i]=1*Min_Val_Neg;
   if(FileIsExist(add,FILE_COMMON))
     {
      int filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
        {
         ok=FileReadArray(filehandle,m_parametros,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }
     }
   /*parametrizadores[0]=0.0000001;
      parametrizadores[2]=0.03;*/
//parametrizadores[5]=7000*Min_Val_Neg;
  }
//+----------------------------------------------------------------------------+
//Funcao para normalizar os erros aceitaveis, evita que os torne muito grandes                    |
//+----------------------------------------------------------------------------+
void Normalizar_erros()
  {
   int i=ArrayMaximum(Vet_erro,0,WHOLE_ARRAY);//Menor negativo
   double menor=-MathAbs(Vet_erro[i]);
   for(i=0; i<ArraySize(Vet_erro); i++)
      Vet_erro[i]=MathMin(Vet_erro[i]-menor,-0.000002*Min_Val_Neg);//Esse valor não pode ser positivo senão ocorre overflow
  }
//+------------------------------------------------------------------+
//|
//+------------------------------------------------------------------+
void Embaralhar_matriz(double &matriz[][prof_cube][n_candles],int d)//usada quando a matriz de erro explode
  {
   int i=0;
   int j=0;
   for(j=0; j<prof_cube; j++)

      for(i=0; i<n_candles; i++)
        {
         if(MathIsValidNumber(matriz[d][j][i]))
           {
            matriz[d][j][i]=0.5*matriz[d][j][i];
           }
         else
            matriz[d][j][i]=0.005*(1+(i*0.1/n_candles))*Min_Val_Neg;

        }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Recriar_matriz(double &M[][prof_cube][n_candles],double &M0[][n_candles],int d)//usado quando a matriz match explode
  {
   int j=0;
   int i=0;
   for(i=0; i<prof_cube; i++)
      for(j=0; j<n_candles; j++)
        {
         if(MathIsValidNumber(m_erro_brain[d][i][j]))
            m_erro_brain[d][i][j]*=0.9;
         else
            m_erro_brain[d][i][j]=0.001*Min_Val_Neg;
         if(MathIsValidNumber(M[d][i][j]) && MathIsValidNumber(M0[i][j]))
            M[d][i][j]=0.5*M[d][i][j]+0.5*M0[i][j];
         else
            if(MathIsValidNumber(M0[i][j]))
              {
               M[d][i][j]=0.9*M0[i][j];
               m_erro_brain[d][i][j]=0.9*MathAbs(m_erro_brain[d][i][j]);
              }
            else
               if(MathIsValidNumber(M[d][i][j]))
                 {
                  M[d][i][j]=MathAbs(M[d][i][j]);
                  m_erro_brain[d][i][j]=0.9*MathAbs(m_erro_brain[d][i][j]);
                 }
               else
                 {
                  M[d][i][j]=10*Min_Val_Neg;
                  m_erro_brain[d][i][j]=0.9*MathAbs(m_erro_brain[d][i][j]);
                 }
        }
  }
//+------------------------------------------------------------------+
//| Funcao para oscilar uma matriz em 3% do seu valor atual
//Usada em caso de loss para tentar encontrar um valor melhor       |
//+------------------------------------------------------------------+
void Oscilar_matriz(double &m_osc[],double &m_pre[])
  {
   for(int i=0; i<prof_cube; i++)
     {
      if(MathAbs(m_osc[i])<0.1*Min_Val_Neg)
         m_osc[i]=0.01*Min_Val_Neg*(16383.5-MathRand())/16383.5;
      else
        {
         m_osc[i]+=m_osc[i]*0.03*(16383.5-MathRand())/16383.5;
         m_osc[i]=0.3*m_osc[i]+0.7*m_pre[i];
        }//recupera 70% do valor que deu certo por ultimo
     }
  }
//+------------------------------------------------------------------+
//| Usada em caso de gain para salvar matriz que deu certo                                                                 |
//+------------------------------------------------------------------+
void estabiliza_matriz()
  {
   for(int i=0; i<prof_cube; i++)
      m_pre_par[i]=m_parametros[i];
  }
//+------------------------------------------------------------------+
//|funcao que compara parcialmente as matrizes match com as matrizes |
//now(valores atuais) e decide se houve similaridade                 |
//funcao mais requisitada do expert                                  |
//+------------------------------------------------------------------+
int compara_matrizes_N(double &match[][prof_cube][n_candles],double &now[][n_candles],double &m_erro[][prof_cube][n_candles],double &err_aceitavel[],int tipo)
  {
   int i=n_candles-1;
   int j=4;
   int hole=tipo;
//comecar pelos ultimos valores que correspondem aos candles mais atuais
   double d_temp=0;
   if(!MathIsValidNumber(err_aceitavel[tipo-1]))
      err_aceitavel[tipo-1]=-2*Min_Val_Neg;
   distancias[tipo-1]=-err_aceitavel[tipo-1];
   for(i=n_candles-1; i>=0; i--)
     {
      for(j=prof_cube-1; j>=0; j--)
        {
         if(MathIsValidNumber(now[j][i]) && MathIsValidNumber(match[tipo-1][j][i]) && MathIsValidNumber(m_erro[tipo-1][j][i]))
           {
            d_temp+=MathPow((now[j][i]-match[tipo-1][j][i])*m_erro[tipo-1][j][i],2);
            if(m_erro[tipo-1][j][i]==0)
               m_erro[tipo-1][j][i]=0.0002*Min_Val_Neg;//Uma vez sendo igual a 0 esse valor não volta a ser atualizado
           }
         else// if(!MathIsValidNumber(now[j][i])||!MathIsValidNumber(match[tipo-1][j][i])||!MathIsValidNumber(m_erro[tipo-1][j][i]))
           {
            d_temp+=0;
            if(!MathIsValidNumber(now[j][i]))
               now[j][i]=7000*Min_Val_Neg;
            if(!MathIsValidNumber(match[tipo-1][j][i]))
               match[tipo-1][j][i]=0.999*now[j][i];
            if(!MathIsValidNumber(m_erro[tipo-1][j][i]))
               m_erro[tipo-1][j][i]=0.01*Min_Val_Neg;
           }                                                                    //por isso precisa  dessa atualizaçao
        }
      distancias[tipo-1]+=d_temp;//MathSqrt(d_temp);
      d_temp=0;
     }
   if((distancias[tipo-1]+err_aceitavel[tipo-1])>=15*dist_tp+10*Min_Val_Neg)
     {
      printf("dist. muito grande: %.3f regenerando matriz: %d Erro Aceit.: %.3f",distancias[hole-1]+err_aceitavel[tipo-1],tipo-1,err_aceitavel[tipo-1]);
      Embaralhar_matriz(m_erro_brain,hole-1);
      Recriar_matriz(super_brain,m_now,hole-1);
      err_aceitavel[tipo-1]=-0.00001*Min_Val_Neg;
     }
   if(err_aceitavel[tipo-1]<=-6*dist_tp-10*Min_Val_Neg)
      err_aceitavel[tipo-1]=-6*dist_tp-10*Min_Val_Neg;
   return 1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Operar_na_Media(double &m_media[])
  {
   if((MathAbs(low[n_candles-1]-m_media[n_candles-1])<=0.5*Min_Val_Neg) && temporizator>2700)
     {
      //compra
      if(low[n_candles-2]-m_media[n_candles-2]>=0.1*Min_Val_Neg && close[n_candles-2]-m_media[n_candles-2]<=3.5*Min_Val_Neg)
        {
         if(low[n_candles-3]-m_media[n_candles-3]>=0.3*Min_Val_Neg)
           {
            if(low[n_candles-4]-m_media[n_candles-4]>=0.5*Min_Val_Neg && (low[n_candles-3]-m_media[n_candles-3]>=1*Min_Val_Neg || low[n_candles-2]-m_media[n_candles-2]>=1*Min_Val_Neg))
              {
               if(primeiro_t_media_cp<=1 && temporizator>=2701)
                 {
                  temporizator=0;
                  primeiro_t_media_cp=MathMin(primeiro_t_media_cp+1,2);
                 }
               Alert("Toque na media nivel 3");
               if(tendencia>parametrizadores[2]*Min_Val_Neg && primeiro_t_media_cp>=0)
                  return 1;
               Alert("Toque na media bloqueado por tendencia ou unico toque n"+string(primeiro_t_media_cp));
               return 0;//compra
              }
           }
        }
     }
   else
      if((MathAbs(high[n_candles-1]-m_media[n_candles-1])<=0.5*Min_Val_Neg) && temporizator>2700)
        {
         //Venda
         if(high[n_candles-2]-m_media[n_candles-2]<=-0.1*Min_Val_Neg && close[n_candles-2]-m_media[n_candles-2]>=-3.5*Min_Val_Neg)
           {
            if(high[n_candles-3]-m_media[n_candles-3]<=-0.3*Min_Val_Neg)
              {
               if(high[n_candles-4]-m_media[n_candles-4]<=-0.5*Min_Val_Neg && (high[n_candles-3]-m_media[n_candles-3]<=-1*Min_Val_Neg || high[n_candles-2]-m_media[n_candles-2]<=-1*Min_Val_Neg))
                 {
                  Alert("Toque na media nivel -3");
                  if(primeiro_t_media_venda<=1 && temporizator>=2701)
                    {
                     temporizator=0;
                     primeiro_t_media_venda=MathMin(primeiro_t_media_venda+1,2);
                    }
                  if(tendencia<-parametrizadores[2]*Min_Val_Neg && primeiro_t_media_venda>=0)
                     return -1;//venda
                  Alert("Toque na media bloqueado por tendencia ou toque unico toque n:"+string(primeiro_t_media_venda));
                  return 0;

                 }
              }
           }
        }
      else
         if(close[n_candles-1]-m_media[n_candles-1]>1*Min_Val_Neg)
            primeiro_t_media_venda=0;
         else
            if(close[n_candles-1]-m_media[n_candles-1]<-1*Min_Val_Neg)
               primeiro_t_media_cp=0;
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int operar_perfuracao()
  {
   double alta_baixa[5];
   alta_baixa[4]=close[n_candles-1]-open[n_candles-1];//>0 alta <0 baixa ==0 doji
   alta_baixa[3]=close[n_candles-2]-open[n_candles-2];
   alta_baixa[2]=close[n_candles-3]-open[n_candles-3];
   alta_baixa[1]=close[n_candles-4]-open[n_candles-4];
   alta_baixa[0]=close[n_candles-5]-open[n_candles-5];
   if(alta_baixa[0]<0 && close[n_candles-5]<close[n_candles-6])
     {
      //baaixa 1
      if(alta_baixa[1]<0 && close[n_candles-4]<close[n_candles-5])//baixa 2
         if(alta_baixa[2]<0 && close[n_candles-3]<(close[n_candles-4]-2*Min_Val_Neg))//baixa forte
            //perfuracao (alta)
            if(alta_baixa[3]>0 && open[n_candles-2]<close[n_candles-3]-0.5*Min_Val_Neg && close[n_candles-2]>0.5*(close[n_candles-3]+open[n_candles-3]+1*Min_Val_Neg))
               if(close[n_candles-1]>(close[n_candles-2])&&close[n_candles-1]<(close[n_candles-2]+6*Min_Val_Neg))//confirmou
                  return 2;
     }//comprar por padrão piercing ou engolfo
   if(alta_baixa[0]>0 && close[n_candles-5]>close[n_candles-6])
     {
      if(alta_baixa[1]>0 && close[n_candles-4]>close[n_candles-5])//alta 2
         if(alta_baixa[2]>0 && close[n_candles-3]>(close[n_candles-4]+2*Min_Val_Neg))//alta forte
            //perfuracao
            if(alta_baixa[3]<0 && open[n_candles-2]>(close[n_candles-3]+0.5*Min_Val_Neg )&& close[n_candles-2]<0.5*(close[n_candles-3]+open[n_candles-3]-1*Min_Val_Neg))
               if( close[n_candles-1]<close[n_candles-2]&&close[n_candles-1]>(close[n_candles-2]-6*Min_Val_Neg))//confirmou
                  return -2;
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
   int a=0;
   int b=0;
   int ind[2]= {0,0};
   num_candles=int(MathMin(num_candles,n_candles));
   double analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0])+0.5*Min_Val_Neg;
   if(loss_gain==0)//loss - afasta os mais proximos
     {
      for(j=0; j<num_candles; j++)
        {
         for(i=0; i<prof_cube; i++)
            for(w=0; w<n_candles; w++)
               if(MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w])<analisado)
                 {
                  if(analisados[i][w]<1)
                    {
                     analisado=MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w]);//m_erro_w_h_1[i][w];
                     ind[0]=i;
                     ind[1]=w;
                    }
                 }
         //os minimos precisam ser afastados o suficiente para aumentar a distancia mais do que os maximos diminuiram
         double temp_err=m_e_temp_brain[trade_type-1][ind[0]][ind[1]];
         m_erro_brain[trade_type-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);
         super_brain[trade_type-1][ind[0]][ind[1]]-=parametrizadores[0]*fator_de_afastamento*(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//36
         m_erro_brain[trade_type-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]+0.00000001*Min_Val_Neg);
         m_erro_brain[trade_type-1][ind[0]][ind[1]]=0.6*m_erro_brain[trade_type-1][ind[0]][ind[1]]+0.4*temp_err;
         m_erro_brain[trade_type-1][ind[0]][ind[1]]=MathMax(MathMin(m_erro_brain[trade_type-1][ind[0]][ind[1]],10),-10);
         if(m_erro_brain[trade_type-1][ind[0]][ind[1]]==0)
            m_erro_brain[trade_type-1][ind[0]][ind[1]]=0.000001*Min_Val_Neg;//Para a reducao não zerar m_erro
         super_brain[trade_type-1][ind[0]][ind[1]]=MathMax(MathMin(super_brain[trade_type-1][ind[0]][ind[1]],10000*Min_Val_Neg),-10000*Min_Val_Neg);
         analisados[ind[0]][ind[1]]+=1;//ativado anti repeticao em loss
         b=0;
         for(a=0; a<prof_cube; a++)
           {
            while(analisados[a][b]>0 && b<n_candles)
               b++;
            if(b!=n_candles)
               break;
            b=0;
           }
         if(b==n_candles)
           {
            b=0;
            a=0;
            Comment("Passou do limite vetorial");
           }
         analisado=MathAbs((m_now[a][b]-super_brain[trade_type-1][a][b])*m_erro_brain[trade_type-1][a][b]);
        }
     }
   else
      if(loss_gain==1)//gain
        {
         //afasta  os mais distantes
         analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0])-0.5*Min_Val_Neg;
         for(j=0; j<num_candles; j++)
           {
            for(i=0; i<prof_cube; i++)
               for(w=0; w<n_candles; w++)
                  if(MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w])>analisado)
                    {
                     if(analisados[i][w]<1)
                       {
                        analisado=MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w]);
                        ind[0]=i;
                        ind[1]=w;
                       }
                    }
            if(super_brain[trade_type-1][ind[0]][ind[1]]!=0)
              {
               super_brain[trade_type-1][ind[0]][ind[1]]=MathMax(MathMin(super_brain[trade_type-1][ind[0]][ind[1]],10000*Min_Val_Neg),-10000*Min_Val_Neg);
              }
            double temp_err=m_erro_brain[trade_type-1][ind[0]][ind[1]];
            m_erro_brain[trade_type-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);
            super_brain[trade_type-1][ind[0]][ind[1]]-=parametrizadores[0]*fator_de_afastamento*(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//36 - +232.3//30 -100
            m_erro_brain[trade_type-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]+0.00000001*Min_Val_Neg);
            m_erro_brain[trade_type-1][ind[0]][ind[1]]=0.9*m_erro_brain[trade_type-1][ind[0]][ind[1]]+0.1*temp_err;
            m_erro_brain[trade_type-1][ind[0]][ind[1]]=MathMax(MathMin(m_erro_brain[trade_type-1][ind[0]][ind[1]],10),-10);
            m_e_temp_brain[trade_type-1][ind[0]][ind[1]]=temp_err;
            analisados[ind[0]][ind[1]]+=1;
            analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
           }
        }
      else
         if(loss_gain==2)//gain trade tipe reverso
           {
            //afasta  os mais distantes
            analisado=MathAbs((m_now[0][0]-super_brain[trade_type_reverso-1][0][0])*m_erro_brain[trade_type_reverso-1][0][0])-0.5*Min_Val_Neg;
            for(j=0; j<num_candles; j++)
              {
               for(i=0; i<prof_cube; i++)
                  for(w=0; w<n_candles; w++)
                     if(MathAbs((m_now[i][w]-super_brain[trade_type_reverso-1][i][w])*m_erro_brain[trade_type_reverso-1][i][w])>analisado)
                       {
                        if(analisados[i][w]==0)
                          {
                           analisado=MathAbs((m_now[i][w]-super_brain[trade_type_reverso-1][i][w])*m_erro_brain[trade_type_reverso-1][i][w]);
                           ind[0]=i;
                           ind[1]=w;
                          }
                       }
               super_brain[trade_type_reverso-1][ind[0]][ind[1]]=MathMax(MathMin(super_brain[trade_type_reverso-1][ind[0]][ind[1]],10000*Min_Val_Neg),-10000*Min_Val_Neg);
               double temp_err=m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]];
               m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]]);
               super_brain[trade_type_reverso-1][ind[0]][ind[1]]-=parametrizadores[0]*fator_de_afastamento*(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//36 - +232.3//30 -100
               m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]]-0.00000001*Min_Val_Neg);
               m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=0.9*m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]+0.1*temp_err;
               m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=MathMax(MathMin(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]],10),-10);
               m_e_temp_brain[trade_type_reverso-1][ind[0]][ind[1]]=temp_err;
               if(MathAbs(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]])<0.0000001*Min_Val_Neg)
                  m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]+=0.000005*Min_Val_Neg *m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]/MathAbs(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]);//Para não zerar m_erro
               analisados[ind[0]][ind[1]]=1;
               analisado=MathAbs((m_now[0][0]-super_brain[trade_type_reverso-1][0][0])*m_erro_brain[trade_type_reverso-1][0][0]);
              }
           }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void aproximar_candles(int num_candles,double fator_de_aproximacao,int loss_gain)
  {
   num_candles=int(MathMin(num_candles,n_candles));
   int ind[2]= {0,0};
   int i=0;
   int j=0;
   int w=0;
   double analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
//aproximar os mais distantes
   if(loss_gain==0)//loss
     {
      for(j=0; j<num_candles; j++)
        {
         for(i=0; i<prof_cube; i++)
            for(w=0; w<n_candles; w++)
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

         super_brain[trade_type-1][ind[0]][ind[1]]+=parametrizadores[0]*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//38

         m_erro_brain[trade_type-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]-0.000000001*Min_Val_Neg);
         m_erro_brain[trade_type-1][ind[0]][ind[1]]=0.2*m_e_temp_brain[trade_type_reverso-1][ind[0]][ind[1]]+0.9*m_erro_brain[trade_type-1][ind[0]][ind[1]];
         //funcao de ativacao
         m_erro_brain[trade_type-1][ind[0]][ind[1]]=MathMax(MathMin(m_erro_brain[trade_type-1][ind[0]][ind[1]],10),-10);
         super_brain[trade_type-1][ind[0]][ind[1]]=MathMax(MathMin(super_brain[trade_type-1][ind[0]][ind[1]],10000*Min_Val_Neg),-10000*Min_Val_Neg);
         //

         analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
         analisados[ind[0]][ind[1]]=1;//desativado sistema anti repeticao em loss
        }
     }
   else
      if(loss_gain==1)//gain
        {
         //aproximar os menos distantes
         for(j=0; j<num_candles; j++)
           {
            for(i=0; i<prof_cube; i++)
               for(w=0; w<n_candles; w++)
                  if(MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w])<analisado && analisados[i][w]==0)
                    {
                     analisado=MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w]);
                     ind[0]=i;
                     ind[1]=w;
                    }
            double temp_err=m_erro_brain[trade_type-1][ind[0]][ind[1]];
            m_erro_brain[trade_type-1][ind[0]][ind[1]]*=m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]];
            super_brain[trade_type-1][ind[0]][ind[1]]+=parametrizadores[0]*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);//44//48 -300
            m_erro_brain[trade_type-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]-0.00000001*Min_Val_Neg);
            m_erro_brain[trade_type-1][ind[0]][ind[1]]=0.9*m_erro_brain[trade_type-1][ind[0]][ind[1]]+0.1*temp_err;
            //funcao de ativacao
            m_erro_brain[trade_type-1][ind[0]][ind[1]]=MathMax(MathMin(m_erro_brain[trade_type-1][ind[0]][ind[1]],10),-10);
            super_brain[trade_type-1][ind[0]][ind[1]]=MathMax(MathMin(super_brain[trade_type-1][ind[0]][ind[1]],10000*Min_Val_Neg),-10000*Min_Val_Neg);
            m_e_temp_brain[trade_type-1][ind[0]][ind[1]]=temp_err;
            //
            analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
            analisados[ind[0]][ind[1]]=1;
           }
        }
      else
         if(loss_gain==2)//gain reverso
           {
            //aproximar os menos distantes
            for(j=0; j<num_candles; j++)
              {
               for(i=0; i<prof_cube; i++)
                  for(w=0; w<n_candles; w++)
                     if(MathAbs((m_now[i][w]-super_brain[trade_type_reverso-1][i][w])*m_erro_brain[trade_type_reverso-1][i][w])<analisado && analisados[i][w]==0)
                       {
                        analisado=MathAbs((m_now[i][w]-super_brain[trade_type_reverso-1][i][w])*m_erro_brain[trade_type_reverso-1][i][w]);
                        ind[0]=i;
                        ind[1]=w;
                       }
               double temp_err=m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]];
               m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]*=m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]];
               super_brain[trade_type_reverso-1][ind[0]][ind[1]]+=parametrizadores[0]*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]]);//44//48 -300
               m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]]-0.00000001*Min_Val_Neg);
               m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=0.9*m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]+0.1*temp_err;
               //funcao de ativacao
               m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=MathMax(MathMin(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]],10),-10);
               super_brain[trade_type_reverso-1][ind[0]][ind[1]]=MathMax(MathMin(super_brain[trade_type_reverso-1][ind[0]][ind[1]],10000*Min_Val_Neg),-10000*Min_Val_Neg);
               m_e_temp_brain[trade_type_reverso-1][ind[0]][ind[1]]=temp_err;
               //
               analisado=MathAbs((m_now[0][0]-super_brain[trade_type_reverso-1][0][0])*m_erro_brain[trade_type_reverso-1][0][0]);
               analisados[ind[0]][ind[1]]=1;
              }
           }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double tendency()//linearizacao da tendencia; evita operar em congestão
  {
   double b=0;
   double d_b=0;
   double a=0;
   double b_e[5];
   double b_l[5];
   double m_x=0;
   double m_y=0;
   m_x=2*(n_candles-1)+1.5*(int(0.9*n_candles))+1*(int(0.8*n_candles))+1*int(0.7*n_candles)+int(0.4*n_candles);
   m_x/=6.5;
   m_y=2*m_close[n_candles-1]+1.5*m_close[int(0.9*n_candles)]+1*m_close[int(0.8*n_candles)]+1*m_close[int(0.7*n_candles)]+m_close[int(0.4*n_candles)];
   m_y/=6.5;
   b_e[0]=2*((n_candles-1))*(m_close[n_candles-1]-m_y);
   b_e[1]=1.5*(int(0.9*n_candles))*(m_close[int(0.9*n_candles)]-m_y);
   b_e[2]=1*(int(0.8*n_candles))*(m_close[int(0.8*n_candles)]-m_y);
   b_e[3]=(int(0.7*n_candles))*(m_close[int(0.7*n_candles)]-m_y);
   b_e[4]=(int(0.4*n_candles))*(m_close[int(0.4*n_candles)]-m_y);
   b_l[0]=2*((n_candles-1))*(n_candles-1-m_x);
   b_l[1]=1.5*(int(0.9*n_candles))*(int(0.9*n_candles)-m_x);
   b_l[2]=1*(int(0.8*n_candles))*(int(0.8*n_candles)-m_x);
   b_l[3]=(int(0.7*n_candles))*(int(0.7*n_candles)-m_x);
   b_l[4]=(int(0.4*n_candles))*(int(0.4*n_candles)-m_x);
   for(int i=0; i<5; i++)
     {
      b+=b_e[i];
      d_b+=b_l[i];
     }
   b/=d_b;
   a=m_y-(b*m_x);
   return b;
  }
//+------------------------------------------------------------------+
//|Inicio do expert                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//Inicializacao das strings address dos valores de treinamento
   ArrayInitialize(Vet_erro,1);
   ArrayInitialize(Vet_temp_erro,1);
   uchar Symb[3];
   string Ativo;
   Min_Val_Neg=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   stopar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
   gainar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
//---Inicializar Menor valor negociavel
   if(Ativo=="WIN")
     {
      Min_Val_Neg=Min_Val_Neg*7;
     }
   if(Clear==1 && (_Symbol=="WDO$" || _Symbol=="WIN$"))
      Min_Val_Neg*=500;
//--- Inicializar o gerador de números aleatórios
   MathSrand(uint(GetMicrosecondCount()));
//+------------------------------------------------------------------+
//| ler/inicializar matrizes match                                                                 |
//+------------------------------------------------------------------+
   ler_matriz_N_4_30(super_brain,"cosmos_training"+"//"+"match",false);

//Ler/inicializar matriz diferencas/erro
   ler_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro",true);

//Gerar arrays copia dos arrays salvos
//Usados para retornar ao valor anterior caso de loss em uma operacao
   for(int x=0; x<n_holes; x++)
      copiar_matriz_N(m_e_temp_brain,m_erro_brain,x);

//ler erros aceitaveis
   ler_vetor_erro_aceitavel("cosmos_training"+"//"+"Ve");
//ler parametros de configuração
   ler_vetor_parametros("cosmos_training"+"//"+"Vp");
   save_tend=parametrizadores[2];
   dist_tp=parametrizadores[3];
   dist_sl=parametrizadores[4];
   op_gain=parametrizadores[6];
   last_op_gain=op_gain;
   counter_t_profit=parametrizadores[7];
   ler_matriz_parametros("cosmos_training"+"//"+"Mp");
   ArrayInitialize(Vet_temp_erro,0);
   ArrayInitialize(distancias,0.0);
   EventSetMillisecondTimer(400);// number of seconds ->0.4 segundos por evento
   tm=TimeCurrent();
   TimeToStruct(tm,stm);
   fim_do_pregao=stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<9) || (stm.hour==9 && stm.min<=30);
   start=TimeCurrent();
   end=GetTickCount()-250000;
   forcar_entrada=550;
   trade_type=1;
   trade_type_reverso=(n_candles/2);
   on_trade=false;
   qtdd_loss=0;//enquanto o dia não inicia essa variavel se mantem zerada
   if(PositionsTotal()!=0)
      trade.PositionClose(_Symbol,ULONG_MAX);
//m_handle_ima=iMA(_Symbol,_Period,int(MathRound(parametrizadores[1])),0,MODE_EMA,PRICE_CLOSE);
//m_handle_tend=iCustom(_Symbol,_Period,"tendencia//tendencia",10);
   if(m_handle_tend==INVALID_HANDLE)
      m_handle_tend=NULL;
   temporizator=2701;
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   printf("numero de operacoes simuladas: "+string(oper_counter)+" modulador: "+string(parametrizadores[0])+" curr. media: "+string(parametrizadores[1]));
   printf("Tendencia: "+string(parametrizadores[2])+" Dist_offset: "+string(Const_dist));
//---desinicializar Menor valor negociavel
   EventKillTimer();

// m_handle_close=iMA(_Symbol,_Period,int(MathRound(parametrizadores[1])),0,MODE_EMA,PRICE_CLOSE);
//reforcar parametrizadores importantes
   parametrizadores[3]=dist_tp;
   parametrizadores[6]=op_gain;
   parametrizadores[7]=counter_t_profit;
//salvar os arrays de match (brain)
   salvar_matriz_N_4_30(super_brain,"cosmos_training"+"//"+"match");
//salvar as matrizes de erro
   salvar_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro");
//Salvar os erros aceitaveis
   salvar_vet_erro(Vet_erro,"cosmos_training"+"//"+"Ve");
//Salvar parametros
   salvar_parametrizadores(parametrizadores,"cosmos_training"+"//"+"Vp");
   salvar_m_parametros(m_parametros,"cosmos_training"+"//"+"Mp");
//Verificar escrita em disco
   double parametro_open=m_parametros[0];
   double erro_0 = Vet_erro[0];
   double match_0=super_brain[0][0][0];
   double erro_brain=m_erro_brain[0][0][0];
   ler_vetor_parametros("cosmos_training"+"//"+"Vp");
   ler_matriz_parametros("cosmos_training"+"//"+"Mp");
   ler_vetor_erro_aceitavel("cosmos_training"+"//"+"Ve");
   ler_matriz_N_4_30(super_brain,"cosmos_training"+"//"+"match",false);
   ler_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro",true);
   if(parametrizadores[3]!=dist_tp)
      printf("Warning, parametrizadores salvos incorretamente");
   if(parametro_open!=m_parametros[0])
      printf("Warning,parametros normalizadores salvos incorretamente");
   if(match_0!=super_brain[0][0][0])
      printf("Warning,Holes salvos incorretamente");
   if(erro_brain!=m_erro_brain[0][0][0])
      printf("Warning,potencializadores salvos incorretamente");
   if(erro_0!=Vet_erro[0])
      printf("Warning,erros aceitaveis salvos incorretamente");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   /* if(m_handle_tend==NULL)
      {
       m_handle_tend=iCustom(_Symbol,_Period,"tendencia//tendencia",10);
      }*/
   double m_21[n_candles];
   CopyBuffer(m_handle_ima,0,0,n_candles,m_21);

   posicoes=PositionsTotal();
//Analise de stops
//chamada da funcao situacao_stops_dia que promove o treinamento dos arrays
   last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
   if(posicoes!=0 && on_trade==true)
     {
      if((trade_type-1)>=(n_holes/2) && (last<stopar || last>gainar))
        {
         //compra
         if(fechou_posicao==false)
           {
            trade.PositionClose(_Symbol,ULONG_MAX); //Operacao perigosa, entra em looping se não for executada instantaneamente
            fechou_posicao=true;
            printf("Encerramento de posicao comprado de emergencia");
           }
        }
      if((trade_type-1)<(n_holes/2) && (last>stopar || last<gainar))
        {
         //venda
         if(fechou_posicao==false)
           {
            trade.PositionClose(_Symbol,ULONG_MAX); //Operacao perigosa, entra em looping se não for executada instantaneamente
            fechou_posicao=true;
            printf("Encerramento de posicao vendido de emergencia");
           }
        }
     }
   else
      if(posicoes==0)
         fechou_posicao=false;

   if(posicoes==0 || on_trade_simulado==false)
     {
      if(on_trade==true)
        {
         //houve uma ordem finalizada recentemente
         on_trade=false;
         if(treinamento_ativo==0)
           {
            //stopou em caso real
            end=GetTickCount();
           }
         stops_N_dimensional(super_brain,m_erro_brain,m_e_temp_brain,Vet_erro,Vet_temp_erro,m_now);//1--> 1 loss dia 0-->infinito                                                                                                                    //Atencao retirado o incremento para treinamento
         //else qtdd_loss+=1;//gain tb conta como stop para realizar apenas 1 operação por dia --> transferido para dentro da funcao stop
         //mudar depois para resolver o problema do reinicio do bot
         //rodar o historico inteiro do dia pode ser uma solução sacrificando processamento
        }
     }
   if(m_handle_close==NULL)
      m_handle_close=iCustom(_Symbol,_Period,"MASVol",17);//iCustom(_Symbol,_Period,"MASVol",int(MathRound(parametrizadores[1])));
   if(CopyBuffer(m_handle_close,0,0,n_candles,m_close)==-1)
     {
      ArrayInitialize(m_close,0);
      printf("problemas com o indicador");
      m_handle_close=NULL;
     }
   int i=0;
   if(posicoes==0 && fim_do_pregao==false && on_trade==false)
     {
      if(CopyClose(_Symbol,Periodo,0,n_candles,close)!=-1 && CopyOpen(_Symbol,Periodo,0,n_candles,open)!=-1 && CopyHigh(_Symbol,Periodo,0,n_candles,high)!=-1 && CopyLow(_Symbol,Periodo,0,n_candles,low)!=-1)
        {
         i=0;
         while(i<n_candles)
           {
            if(MathIsValidNumber(open[i]) && MathIsValidNumber(close[i]) && MathIsValidNumber(high[i]) && MathIsValidNumber(low[i]))
              {
               //copiano candles 30 ultimos normalizados
               m_now[0][i]=(open[i]/high[i])-m_parametros[0];//m_open[n_candles-1];
               m_now[1][i]=(close[i]/high[i])-m_parametros[1];//m_close[n_candles-1];
               m_now[2][i]=(high[i]/high[i])-m_parametros[2];//m_high[n_candles-1];
               m_now[3][i]=(low[i]/high[i])-m_parametros[3];//m_low[n_candles-1];
               m_now[4][i]=(m_close[i]/high[i])-m_parametros[4];//m_low[n_candles-1];
               m_now[5][i]=close[i]-open[i]-m_parametros[5];
               m_now[6][i]=close[i]-high[i]-m_parametros[6];
               m_now[7][i]=close[i]-low[i]-m_parametros[7];
               m_now[8][i]=close[i]-m_close[i]-m_parametros[8];
               m_now[9][i]=open[i]-high[i]-m_parametros[9];
               m_now[10][i]=open[i]-low[i]-m_parametros[10];
               m_now[11][i]=open[i]-m_close[i]-m_parametros[11];
               m_now[12][i]=high[i]-low[i]-m_parametros[12];
               m_now[13][i]=high[i]-m_close[i]-m_parametros[13];
               m_now[14][i]=low[i]-m_close[i]-m_parametros[14];
              }
            i+=1;
           }
        }
      tendencia=tendency();
      op_media=Operar_na_Media(m_close);//verifica toque na media
      if(op_media==0)
         op_media=operar_perfuracao();//verifica padrão perfuracao e engolfo
      double comparacoes[n_holes];// Inicio da seção de comparações
      int temp_type=0;
      while(temp_type<n_holes)
        {
         comparacoes[temp_type]=compara_matrizes_N(super_brain,m_now,m_erro_brain,Vet_erro,temp_type+1);//vetor distancias é preenchido aqui
         temp_type++;
        }
      double d_venda_menor=distancias[0]+Vet_erro[0];
      int alfa=0;
      alfa_c=n_holes/2;
      alfa_v=0;
      for(alfa=0; alfa<n_holes/2; alfa++)
        {
         if((distancias[alfa]+Vet_erro[alfa])<d_venda_menor)
           {
            d_venda_menor=distancias[alfa]+Vet_erro[alfa];//distancia sem penalidade
            alfa_v=alfa;
           }
        }
      double d_compra_menor=distancias[n_holes/2]+Vet_erro[n_holes/2];
      for(alfa=n_holes/2; alfa<n_holes; alfa++)
        {
         if((distancias[alfa]+Vet_erro[alfa])<d_compra_menor)
           {
            d_compra_menor=distancias[alfa]+Vet_erro[alfa];
            alfa_c=alfa;
           }
        }
      bool venda=false;
      bool compra=false;
      if(d_venda_menor<d_compra_menor)
         venda=true;//|| d_venda_menor<dist_tp
      else
         if(d_compra_menor<d_venda_menor)
            compra=true;//|| d_compra_menor<dist_tp
      last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
      ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      ask=round(10*ask);
      if(int(ask)%5==0)
         ask/=10;
      else
         if(int(ask)%10>5)
            ask=((ask+10)-int(ask)%10)/10;
         else
            ask=(ask-(int(ask)%10)+5)/10;
      bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      bid*=10;
      bid=(bid-int(bid)%5)/10;
      if(((d_compra_menor-Vet_erro[alfa_c])<1*distancia || op_media>=1) && posicoes==0 && on_trade==false)//&&compra==true)
        {
         //comprar
         timer=GetTickCount();
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if((d_compra_menor)<1.01*(0.95*dist_tp+0.05*dist_sl+5*Min_Val_Neg))
            simulacao_contabil=1;//operar na media nao contabiliza
         else
            simulacao_contabil=0;//compra simulada não será contabilizada
         if(compra==true && posicoes==0 && tendencia>=parametrizadores[2]*Min_Val_Neg && qtdd_loss<loss_suportavel_dia && (forcar_entrada)>=900 && (op_media>=1 || ((d_compra_menor)<1.1*dist_tp && counter_t_profit>op_gain)))
           {
            trade_type=1+alfa_c;//ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);
            trade_type_reverso=1+alfa_v;//ArrayMinimum(distancias,0,n_holes/2);
            stopar=ask-8*Min_Val_Neg;
            gainar=ask+8*Min_Val_Neg;
            trade.Buy(lotes,_Symbol,ask,stopar,gainar,"Compra dist "+string(trade_type)+" mean "+string(op_media)+" tend: "+string(tendencia)+" Tf: "+string(_Period));
            printf("------------Compra-------- "+string(ask)+" tendencia: "+string(parametrizadores[2]*Min_Val_Neg));
            Buy_Sell_Simulado=ask;
            on_trade=true;
            on_trade_simulado=true;
            treinamento_ativo=0;
            end=GetTickCount();
            forcar_entrada=1;
            Sleep(3000);
           }
         else
            if(ArrayMinimum(distancias,0)>=n_holes/2)//simula uma compra
              {
               if(op_media>=1)
                  printf("operação de compra na media bloqueada op_media= "+op_media);
               if(forcar_entrada>=18000)
                  forcar_entrada=900;
               Stop_tp_Simulado=last;
               if(on_trade_simulado==false)
                 {
                  Buy_Sell_Simulado=ask;
                  trade_type=1+ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);
                  trade_type_reverso=1+alfa_v;//ArrayMinimum(distancias,0,n_holes/2);
                  on_trade_simulado=true;
                  treinamento_ativo=1;
                  printf("distancia de entrada em compra:%.3f dist hole:%.3f tendencia:%.3f tend_min_aceitavel:%.3f ",distancia,distancias[ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY)],tendencia,parametrizadores[2]);
                 }
               else
                  if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
                    {
                     on_trade=true;
                     treinamento_ativo=6;
                     on_trade_simulado=false;
                    }
               //on_trade=true;
              }
        }

      if((d_venda_menor-Vet_erro[alfa_v]<1*distancia || op_media<=-1) && posicoes==0 && on_trade==false)//&&venda==true
        {

         timer=GetTickCount();
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         //Analise de venda
         if(((d_venda_menor)<1.01*(0.95*dist_tp+0.05*dist_sl+5*Min_Val_Neg)))
            simulacao_contabil=1;//valido como entrada para atualizar parametros
         else
            simulacao_contabil=0;
         if(venda==true && posicoes==0 && tendencia<=-parametrizadores[2]*Min_Val_Neg && qtdd_loss<loss_suportavel_dia && (forcar_entrada)>=900 && (op_media<=-1 || ((d_venda_menor)<1.1*dist_tp && counter_t_profit>=op_gain)))//aguarda ao menos 5min antes da proxima operação real
           {
            //vender
            trade_type=1+alfa_v;//ArrayMinimum(distancias,0,n_holes/2);
            trade_type_reverso=1+alfa_c;//ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);
            stopar=bid+8*Min_Val_Neg;
            gainar=bid-8*Min_Val_Neg;
            trade.Sell(lotes,_Symbol,bid,stopar,gainar,"Venda dist "+string(trade_type)+" mean "+string(op_media)+" tend: "+string(tendencia)+" Tf: "+string(_Period));
            printf("------------V. distancia-----------"+string(bid)+" tendencia: "+string(-parametrizadores[2]*Min_Val_Neg));
            Buy_Sell_Simulado=bid;
            on_trade=true;
            on_trade_simulado=true;
            treinamento_ativo=0;
            end=GetTickCount();
            forcar_entrada=1;
            last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
            Sleep(3000);
            Comment("Timeframe de entrada:"+string(_Period));
           }
         else
            if(ArrayMinimum(distancias,0)<n_holes/2)//só  entrada venda virtual
              {
               if(op_media<=-1)
                  printf("operação de venda na media bloqueada op_media= "+op_media);
               if(forcar_entrada>=18000)
                  forcar_entrada=900;
               Stop_tp_Simulado=last;
               if(on_trade_simulado==false)
                 {
                  //primeira passagem pela entrada virtual
                  Buy_Sell_Simulado=bid;
                  trade_type=1+alfa_v;
                  trade_type_reverso=1+ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);
                  on_trade_simulado=true;
                  treinamento_ativo=-1;
                  printf("distancia de entrada em venda:%.3f dist hole:%.3f tendencia:%.3f tend_min_aceitavel: -%.3f",distancia,distancias[ArrayMinimum(distancias,0,n_holes/2)],tendencia,parametrizadores[2]);
                 }
               else
                  if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
                    {
                     //loss ou gain virtual
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
      if(posicoes!=0)
        {
         //counter_t_profit=0.5;
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
bool stops_N_dimensional(double &match[][prof_cube][n_candles],double &m_erro[][prof_cube][n_candles],double &m_temp_erro[][prof_cube][n_candles],double &erro[],double &temp_erro[],double &mnow[][n_candles])
  {
   bool stop=false;
   double last_trade;
   double l_last_trade;
   int hole=ArrayMinimum(distancias);
   bool compra=false;
   bool venda=false;
   if(trade_type!=0 && hole<=(n_holes/2))
      venda=true;
   else
      if(hole>(n_holes/2))
         compra=true;
   if(treinamento_ativo==0)//operacao foi real
     {
      HistorySelect(start,TimeCurrent());
      int total=HistoryOrdersTotal();
      ulong last_ticket=HistoryOrderGetTicket(total-1);
      ulong l_last_ticket=HistoryOrderGetTicket(total-2);
      last_trade=double(HistoryOrderGetDouble(last_ticket,ORDER_PRICE_OPEN));
      l_last_trade=double(HistoryOrderGetDouble(l_last_ticket,ORDER_PRICE_OPEN));
      end=GetTickCount();
      if(compra)
         lucro_prej+=last_trade-l_last_trade;
      else
         if(venda)
            lucro_prej-=last_trade-l_last_trade;
      stop=true;//considera um stop true, caso seja gain esse valor será atualizado para false
      printf("operaçao real lucro/prej.: "+string(lucro_prej));
      qtdd_loss+=1;//mesmo sendo gain, se for real bloqueia o resto do dia
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
   int ind_max[2]= {0,0};
   int ind_min[2]= {0,0};
   if((compra && l_last_trade>=last_trade) || (venda && l_last_trade<=last_trade))
     {
      //--================----loss
      oper_counter-=1;
      ArrayFill(analisados,0,prof_cube*n_candles,0);
      //caso de loss procurar o indice do maior erro e aproximar
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (10% da matriz)
      aproximar_candles(int(0.3*prof_cube*n_candles),10,0);
      //manter a mesma distancia para não alterar o resultado da operação de afastamento
      //caso de loss procurar o indice do menor erro e afastar
      //significa que aquele valor nao era importante
      //fazer essa alteração  (25% dos candles)
      if(treinamento_ativo==0)//operacao foi real
         afastar_candles(int(0.6*prof_cube*n_candles),300,0);
      else
         afastar_candles(int(0.6*prof_cube*n_candles),200,0);
      ArrayFill(analisados,0,prof_cube*n_candles,0);
      //----------trabalhando com as vizinhancas
      //caso de loss procurar todoso indice do menor erro da operacao inversa e tratar como gain
      //diferente de tratar a operacao isso aproxima holes distantes do valor now
      //significa que aquele valor era para ser o de real entrada
      //fazer essa alteração  (25% dos candles)
      afastar_candles(int(0.3*prof_cube*n_candles),100,2);//operar vizinhanca, tratar como gain a operacao inversa
      aproximar_candles(int(0.4*prof_cube*n_candles),150,2);//operar vizinhanca, tratar como gain a operacao inversa
      Normalizar_erros();//normalizar erros
      erro[hole]=0.8*erro[hole]+0.2*temp_erro[hole]-(0.55*distancia);//diminuir esse valor para dificultar um nova entrada (para treinamento)
      if(simulacao_contabil==1)
        {
         counter_t_profit+=(0-counter_t_profit)/21;
         dist_sl=MathMin(dist_sl+(distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_sl)/(0.9*n_candles),50200);
         dist_tp=MathMin(dist_tp+((distancias[trade_type_reverso-1]+Vet_erro[trade_type_reverso-1]-dist_tp)/(0.9*n_candles)),200000);
        }
      else
        {
         dist_sl=MathMin((distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_sl)/200,10200);
         dist_tp=MathMin(dist_tp+((distancias[trade_type_reverso-1]+Vet_erro[trade_type_reverso-1]-dist_tp)/200),150000);
        }
      //copiar_matriz_N(m_erro,m_temp_erro,trade_type-1);
      parametrizadores[0]+=0.05*(16383.5-MathRand())*Min_Val_Neg/(16383.50);//alimentar o modulador
      parametrizadores[0]=0.5*parametrizadores[0]+0.5*Modulador;
      parametrizadores[0]=MathMax(MathMin(parametrizadores[0],0.1),0.000005);
      Oscilar_matriz(m_parametros,m_pre_par);
      parametrizadores[5]=m_parametros[4];
      if(op_media!=0)
        {
         parametrizadores[1]+=0.5*(16383.5-MathRand())/(16383.5);//alimentar a media
         parametrizadores[1]=0.5*save_ma+0.5*parametrizadores[1];
         parametrizadores[1]=MathMax(MathMin(parametrizadores[1],25),17);
         parametrizadores[2]+=0.4*(16383.5-MathRand())/(16383.5);
         parametrizadores[2]=0.5*parametrizadores[2]+0.5*save_tend;
         parametrizadores[2]=MathMax(MathMin(parametrizadores[2],0.2),0.003);
         op_media=0;
         if(compra)
            primeiro_t_media_cp=0;
         else
            if(venda)
               primeiro_t_media_venda=0;
         printf("foi media");
        }
      op_gain=last_op_gain;
      distancia=temp_dist*0.2;
      //ArrayPrint(distancias);
      printf("stop loss caso:%d dist t_prof.:%.3f Err acc.:%.3f tk p:%.3f op_gain:%.3f",trade_type,dist_tp,erro[hole],counter_t_profit,op_gain);
     }
//foi gain
   else
      if((compra && l_last_trade<last_trade) || (venda && l_last_trade>last_trade))
        {
         oper_counter+=1;
         ArrayFill(analisados,0,prof_cube*n_candles,0);
         //caso de gain procurar o indice de maior  erro e aumentar a distancia
         //reduzir o erro de gatilho proporcionalmente diminuindo a significancia
         //significa que aquele valor realmente não era importante
         //fazer essa alteração 6 x (5% dos candles)
         afastar_candles(int(0.3*prof_cube*n_candles),10,1);
         //caso de gain procurar o indice de menor  erro e reduzir a distancia
         //alterar m_erro para manter a mesma distancia (aumentar a significancia)
         //significa que aquele valor era importante
         //fazer essa alteração 6 x (5% dos candles)
         aproximar_candles(int(0.5*prof_cube*n_candles),100,1);
         int temp_trade_type=trade_type;
         /*if(venda==true)
            trade_type=1+ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);//procurar menor distancia nas compras
         //compra==true
         else
            trade_type=1+ArrayMinimum(distancias,0,n_holes/2);*/
         trade_type=temp_trade_type;
         //absorver o erro aceitavel
         temp_erro[hole]=(0.1*erro[hole]+0.9*temp_erro[hole]);//Absorver valor que deu certo para futuro loss
         erro[hole]=MathMin(erro[hole]+0.01*(2*(16383.5-MathRand())*Min_Val_Neg/(16383.5)),-0.00001*Min_Val_Neg);//Oscilar em 0.04* o min val neg
         Normalizar_erros();//normalizar erros
         if(simulacao_contabil==1)
           {
            counter_t_profit+=(1-counter_t_profit)/21;//media exponencial 21
            dist_tp=MathMin(dist_tp+((distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_tp)/(0.9*n_candles)),150000);
           }
         else
            dist_tp=MathMin(dist_tp+((distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_tp)/(200)),150000);
         if(dist_tp==150000)
            parametrizadores[0]+=0.03*(16383.5-MathRand())*Min_Val_Neg/(16383.50);
         Modulador=parametrizadores[0];
         estabiliza_matriz();
         Const_dist=parametrizadores[5];
         if(op_media!=0)
           {
            save_ma=parametrizadores[1];
            save_tend=parametrizadores[2];
            op_media=0;
           }
         printf("t. prof. caso:%d dist t_prof.:%.3f Err acc.:%.3f tk p:%.3f op_gain:%.3f",trade_type,dist_tp,erro[hole],counter_t_profit,op_gain);
         last_op_gain=op_gain;
         op_gain=MathMax(op_gain+(counter_t_profit-op_gain)/n_holes,0.8);
         //aproximar_matriz_N(m_temp_erro,m_erro,trade_type-1);
         //parametrizadores[0]-=(2*16383.5-MathRand())*Min_Val_Neg/(2*163835000);//reduzir o modulador
         temp_dist+=(distancias[hole]-temp_dist)/17;
         distancia=0.2*temp_dist;
         //copiar_matriz_N(m_erro,m_temp_erro,trade_type-1);
         stop=false;//mesmo sendo operacao real se for gain stop returna false - reverção
        }
      else
        {
         printf("Tendencia reversa 0x0 compra: "+string(compra)+" venda: "+string(venda));
        }

   parametrizadores[3]=dist_tp;
   parametrizadores[4]=dist_sl;
   parametrizadores[6]=op_gain;
   parametrizadores[7]=counter_t_profit;
   salvar_matriz_N_4_30(match,"cosmos_training"+"//"+"match");
   salvar_matriz_N_4_30(m_erro,"cosmos_training"+"//"+"erro");
   salvar_vet_erro(Vet_erro,"cosmos_training"+"//"+"Ve");
   salvar_parametrizadores(parametrizadores,"cosmos_training"+"//"+"Vp");
   salvar_m_parametros(m_parametros,"cosmos_training"+"//"+"Mp");
//verificar escrita em disco
   double parametro_open=m_parametros[0];
   double erro_0 = Vet_erro[0];
   double match_0=super_brain[0][0][0];
   double erro_brain=m_erro_brain[0][0][0];
   ler_vetor_parametros("cosmos_training"+"//"+"Vp");
   ler_matriz_parametros("cosmos_training"+"//"+"Mp");
   ler_vetor_erro_aceitavel("cosmos_training"+"//"+"Ve");
   ler_matriz_N_4_30(super_brain,"cosmos_training"+"//"+"match",false);
   ler_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro",true);
   if(parametrizadores[3]!=dist_tp)
      printf("Warning, parametrizadores salvos incorretamente");
   if(parametro_open!=m_parametros[0])
      printf("Warning,parametros normalizadores salvos incorretamente");
   if(match_0!=super_brain[0][0][0])
      printf("Warning,Holes salvos incorretamente");
   if(erro_brain!=m_erro_brain[0][0][0])
      printf("Warning,potencializadores salvos incorretos");
   return stop;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
// iVolume(_Symbol,Periodo,0);
   timer=GetTickCount();
   tm=TimeCurrent();
   TimeToStruct(tm,stm);
   fim_do_pregao=stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<9) || (stm.hour==9 && stm.min<=45);
   if(fim_do_pregao==true)
     {
      //operar apenas apos 9:30 e antes das 17:30
      temporizator=2701;
      primeiro_t_media_cp=0;
      primeiro_t_media_venda=0;
      start=TimeCurrent();
      end=GetTickCount()-250000;
      forcar_entrada=550;
      trade_type=1+ArrayMinimum(distancias,0);
      on_trade=false;
      counter_t_profit=0.5;
      qtdd_loss=0;//enquanto o dia não inicia essa variavel se mantem zerada
      if(PositionsTotal()!=0 && fechou_posicao==false)
        {
         trade.PositionClose(_Symbol,ULONG_MAX); //Operacao perigosa, entra em looping se não for executada instantaneamente
         fechou_posicao=true;
        }
      if(PositionsTotal()==0)
         fechou_posicao=false;                                                                  //Melhor deixar as operações morrerem por tempo ou por stop/gain
     }
   else
     {
      forcar_entrada=MathMin(forcar_entrada+0.4,18000);
      temporizator++;
      temporizator=MathMin(temporizator,2701);
      double incrementer=distancias[ArrayMinimum(distancias,0,WHOLE_ARRAY)]/3900;
      distancia=distancia+(incrementer);
      fechou_posicao=false;
     }
  }
//+------------------------------------------------------------------+
