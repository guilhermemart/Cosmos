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
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
COrderInfo info;
CTrade trade;

#define Black_Hole_1_Venda   1
#define Black_Hole_2_Venda   2
#define Black_Hole_3_Venda   3
#define Black_Hole_4_Venda   4
#define Black_Hole_5_Venda   5
#define White_Hole_1_Compra  6
#define White_Hole_2_Compra  7
#define White_Hole_3_Compra  8
#define White_Hole_4_Compra  9
#define White_Hole_5_Compra  10
#define Modulador            0.04
/*
//save adress das matrizes de trabalho

//caminho matriz de comparacao
#define path_match1 "cosmos_training"+"//"+"match1"
#define path_match2 "cosmos_training"+"//"+"match2"
#define path_match3 "cosmos_training"+"//"+"match3"
#define path_match4 "cosmos_training"+"//"+"match4"
#define path_match5 "cosmos_training"+"//"+"match5"
#define path_match6 "cosmos_training"+"//"+"match6"
#define path_match7 "cosmos_training"+"//"+"match7"
#define path_match8 "cosmos_training"+"//"+"match8"
#define path_match9 "cosmos_training"+"//"+"match9"
#define path_match10 "cosmos_training"+"//"+"match10"
//caminho das matrizes erro
#define path_erro1 "cosmos_training"+"//"+"erro1"
#define path_erro2 "cosmos_training"+"//"+"erro2"
#define path_erro3 "cosmos_training"+"//"+"erro3"
#define path_erro4 "cosmos_training"+"//"+"erro4"
#define path_erro5 "cosmos_training"+"//"+"erro5"
#define path_erro6 "cosmos_training"+"//"+"erro6"
#define path_erro7 "cosmos_training"+"//"+"erro7"
#define path_erro8 "cosmos_training"+"//"+"erro8"
#define path_erro9 "cosmos_training"+"//"+"erro9"
#define path_erro10 "cosmos_training"+"//"+"erro10"
//caminho candles de inicializacao das matrizes erro
#define path_black_hole1 "cosmos_training"+"//"+"bh1"
#define path_black_hole2 "cosmos_training"+"//"+"bh2"
#define path_black_hole3 "cosmos_training"+"//"+"bh3"
#define path_black_hole4 "cosmos_training"+"//"+"bh4"
#define path_black_hole5 "cosmos_training"+"//"+"bh5"
#define path_white_hole1 "cosmos_training"+"//"+"wh1"
#define path_white_hole2 "cosmos_training"+"//"+"wh2"
#define path_white_hole3 "cosmos_training"+"//"+"wh3"
#define path_white_hole4 "cosmos_training"+"//"+"wh4"
#define path_white_hole5 "cosmos_training"+"//"+"wh5"
//caminho das variaveis erro de cada hole
#define path_black_erro1 "cosmos_training"+"//"+"be1"
#define path_black_erro2 "cosmos_training"+"//"+"be2"
#define path_black_erro3 "cosmos_training"+"//"+"be3"
#define path_black_erro4 "cosmos_training"+"//"+"be4"
#define path_black_erro5 "cosmos_training"+"//"+"be5"
#define path_white_erro1 "cosmos_training"+"//"+"we1"
#define path_white_erro2 "cosmos_training"+"//"+"we2"
#define path_white_erro3 "cosmos_training"+"//"+"we3"
#define path_white_erro4 "cosmos_training"+"//"+"we4"
#define path_white_erro5 "cosmos_training"+"//"+"we5"
//Array bidimensional com todos os valores acima*/
#define n_holes 10
string paths[n_holes][3];
/* {
     {path_erro1,path_match1,path_black_erro1},
     {path_erro2,path_match2,path_black_erro2},
     {path_erro3,path_match3,path_black_erro3},
     {path_erro4,path_match4,path_black_erro4},
     {path_erro5,path_match5,path_black_erro5},
     {path_erro6,path_match6,path_white_erro1},
     {path_erro7,path_match7,path_white_erro2},
     {path_erro8,path_match8,path_white_erro3},
     {path_erro9,path_match9,path_white_erro4},
     {path_erro10,path_match10,path_white_erro5},
  };*/



//+------------------------------------------------------------------+
//| Expert initialization                                |
//+------------------------------------------------------------------+
double Min_Val_Neg=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
ENUM_TIMEFRAMES Periodo=_Period;
int lotes=1;
int caso=5;
double m_match_w_h_1[4][30];//condicao 1 de compra
double m_match_w_h_2[4][30];
double m_match_w_h_3[4][30];
double m_match_w_h_4[4][30];
double m_match_w_h_5[4][30];
double m_match_b_h_1[4][30];//condicao 1 de venda
double m_match_b_h_2[4][30];
double m_match_b_h_3[4][30];
double m_match_b_h_4[4][30];
double m_match_b_h_5[4][30];
double m_now[4][30];
double m_erro_w_h_1[4][30];
double m_erro_w_h_2[4][30];
double m_erro_w_h_3[4][30];
double m_erro_w_h_4[4][30];
double m_erro_w_h_5[4][30];
double m_erro_b_h_1[4][30];
double m_erro_b_h_2[4][30];
double m_erro_b_h_3[4][30];
double m_erro_b_h_4[4][30];
double m_erro_b_h_5[4][30];
double m_temp_erro_w_h_1[4][30];
double m_temp_erro_w_h_2[4][30];
double m_temp_erro_w_h_3[4][30];
double m_temp_erro_w_h_4[4][30];
double m_temp_erro_w_h_5[4][30];
double m_temp_erro_b_h_1[4][30];
double m_temp_erro_b_h_2[4][30];
double m_temp_erro_b_h_3[4][30];
double m_temp_erro_b_h_4[4][30];
double m_temp_erro_b_h_5[4][30];
double counter_t_profit=0.5;
double distancias[n_holes];
double alpha=ArrayInitialize(distancias,0.0);
int treinamento_ativo=0;
double Buy_Sell_Simulado=0;
datetime end=TimeCurrent();        //horario atual em datetime nao convertido  
datetime start=TimeCurrent();
int trade_type=0;
int qtdd_loss=0;
bool on_trade=false;
bool on_trade_simulado=false;
bool Stop_tp_Simulado=false;
double last,ask,bid;
double distancia=75;
double temp_dist=100;
double dist_tp=130;
double dist_sl=130;
int simulacao_contabil=0;
int oper_counter=0;
double op_gain=0.75;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*int n=0;
double dvp=0;
double variancia[];
double q_erro=0;
int y=0;
double dvp_loss=0;
double var_loss[];
double q_erro_loss=0;*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*class candle
  {
public:
   double            max;
   double            min;
   double            open;
   double            close;
   int               type;  //tipos de candle existentes
                     candle(){};
                     candle(double m,double mi,double op,double cl)
     {
      max=m;
      min=mi;
      open=op;
      close=cl;
      if(open<close)type=1;//comum de alta
      else if(open>close)type=-1;//comum de baixa       
      else if(m==close  &&  mi==open)type=2; //maruboso de alta        
      else if(mi==close && m==open) type=-2; //maruboso de baixa        
      else type=0;//Doji        
     }
  };*/

/*candle cd[30];//To Do criar isso aqui
              //candles para gerar a matriz match primeira vez
candle b_h_1 = new candle(4000,3994,3996,3998);
candle b_h_2 = new candle(4002,3996,3998,4000);
candle b_h_3 = new candle(4000,3994,3998,3996);
candle b_h_4 = new candle(4002,3996,3998,4000);
candle b_h_5 = new candle(4000,3994,3998,3996);
candle w_h_1 = new candle(3998,3992,3996,3994);
candle w_h_2 = new candle(4002,3996,3999,3998);
candle w_h_3 = new candle(4000,3994,3997,3995);
candle w_h_4 = new candle(4002,3996,3999,3998);
candle w_h_5 = new candle(4000,3994,3997,3995);*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*void criar_candle_simples(candle &ca[],int ind,double o,double c,double h,double l)
  {
   ca[ind].close=c;
   ca[ind].open=o;
   ca[ind].max=h;
   ca[ind].min=l;
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+  
void recalcular_matriz_erro(double &m_match[][30],double &now[][30],double &m_erro[][30])
  {
   int i=0;
   int j=0;
   for(i=0;i<4;i++)
     {
      for(j=0;j<30;j++)
        {
         //m_erro[i][j]=(3*m_erro[i][j]+MathAbs(m_match[i][j]-now[i][j]))/4;
         m_erro[i][j]=now[i][j]-m_match[i][j];
         m_erro[i][j]=MathAbs(m_erro[i][j]);
        }
     }
  }
//+------------------------------------------------------------------+
//|calculo das matrizes match                                          |
//+------------------------------------------------------------------+
/*void calcular_m_match(double &match[][30],candle &hole)
  {
   for(int w=29;w>=0;w-=1)
     {
      match[0][w]=cd[w].open-hole.open;
      match[1][w]=cd[w].close-hole.close;
      match[2][w]=cd[w].max-hole.max;
      match[3][w]=cd[w].min-hole.min;
     }
  }*/
//+------------------------------------------------------------------+
//| Salva matrizes 4x30 sempre que necessario                                                                 |
//+------------------------------------------------------------------+
void salvar_matriz_4_30(double  &matriz[][30],string path)
  {
   int filehandle;
   double vec[30];
   string add;
   string linha="";
   int i;
   int file_handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
   FileWrite(file_handle,"matriz "+path+"\n");
   for(int j=0;j<4;j++)
     {
      for(i=0;i<30;i++)
        {
         vec[i]=matriz[j][i];
         if(i<29)
            linha+=string(vec[i])+", ";
         else linha+=string(vec[i])+"\n";

        }
      FileWrite(file_handle,linha);
      add=path+"_"+string(j);
      filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      FileWriteArray(filehandle,vec,0,WHOLE_ARRAY);
      FileClose(filehandle);

     }
   FileClose(file_handle);
  }
//+------------------------------------------------------------------+
//|  funcao para salvar os erros aceitaveis                                                                |
//+------------------------------------------------------------------+
void salvar_erro(double &erro,string path)
  {
   int handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro);
   FileClose(handle);
  }
//+------------------------------------------------------------------+
//| le matrizes 4x30 do disco                                                                 |
//+------------------------------------------------------------------+
void ler_matriz_4_30(double  &matriz[][30],string path)
  {
   int filehandle;
   double vec[30];
   ArrayInitialize(vec,0);
   string add;
   int i=0;
   double close[30];
   double open[30];
   double high[30];
   double low[30];
   for(int j=0;j<4;j++)
     {
      add=path+"_"+string(j);
      if(FileIsExist(add,FILE_COMMON))
        {
         filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
         FileReadArray(filehandle,vec,0,WHOLE_ARRAY);
         FileClose(filehandle);
         for(i=0;i<30;i++)matriz[j][i]=vec[i];
        }
      else
        {
         Alert("arquivo "+add+" nao encontrado");
         if(j==0)
           {
            if(CopyOpen(_Symbol,Periodo,0,30,open)!=-1)
               for(i=0;i<30;i++)matriz[j][i]=open[i]+(2*Min_Val_Neg*(16383.5-MathRand())/16383.5);
           }
         else if(j==1)
           {
            if(CopyClose(_Symbol,Periodo,0,30,close)!=-1)
               for(i=0;i<30;i++)matriz[j][i]=close[i]+(2*Min_Val_Neg*(16383.5-MathRand())/16383.5);
           }
         else if(j==2)
           {
            if(CopyHigh(_Symbol,Periodo,0,30,high)!=-1)
               for(i=0;i<30;i++)matriz[j][i]=high[i]+(2*Min_Val_Neg*(16383.5-MathRand())/16383.5);
           }
         else if(j==3)
           {
            if(CopyLow(_Symbol,Periodo,0,30,low)!=-1)
               for(i=0;i<30;i++)matriz[j][i]=low[i]+(2*Min_Val_Neg*(16383.5-MathRand())/16383.5);
           }
         else for(i=0;i<30;i++) matriz[j][i]=10000*Min_Val_Neg-(MathRand()/16383.5)*2*Min_Val_Neg;
        }
     }
  }
//+------------------------------------------------------------------+
//| Cria matriz 4x30 usado na primeira vez que o programa roda                                                                 |
//+------------------------------------------------------------------+
void criar_matriz(double &Matriz[][30])
  {
   double arr[30];
   int x=0;
   for(int j=0;j<4;j++)
      for(x=0;x<30;x++) Matriz[j][x]=(MathRand())*Min_Val_Neg/1638.35;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void aproximar_matriz(double &Matriz_temp[][30],double &Matriz_erro[][30])
  {
   int i=0;
   for(int j=0;j<4;j++)
      for(i=0;i<30;i++) Matriz_temp[j][i]=0.8*Matriz_temp[j][i]+0.2*Matriz_erro[j][i]+(16383.5-MathRand())*Min_Val_Neg/(1638350);//Oscilacao de 0.01*Min_Val_Neg
  }
//+------------------------------------------------------------------+
//|Copia M2 em M1                                                                  |
//+------------------------------------------------------------------+
void copiar_matriz(double &M1[][30],double &M2[][30])
  {
   int i=0;
   for(int j=0;j<4;j++)
      for(i=0;i<30;i++) M1[j][i]=M2[j][i];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ler_m_erro_4_30(double &matriz[][30],string path)
  {
   int filehandle;
   string add;
   int i=0;
   double vec[30];
   for(int j=0;j<4;j++)
     {
      add=path+"_"+string(j);
      if(FileIsExist(add,FILE_COMMON))
        {
         filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
         FileReadArray(filehandle,vec,0,WHOLE_ARRAY);
         FileClose(filehandle);
         for(i=0;i<30;i++) matriz[j][i]=vec[i];
        }
      else
        {
         Alert("arquivo "+add+" nao encontrado");
         //Iniciar matriz com valor Aleatorio proximo ao valor Min_Val_Neg
         //Valor aumenta para reduzir o peso dos candles mais antigos
         for(i=0;i<30;i++) matriz[j][i]=(1+(i/30))*MathRand()*Min_Val_Neg/16383.5;
        }
     }
  }
//+------------------------------------------------------------------+
//|busca dos holes                                                                  |
//+------------------------------------------------------------------+

/*void ler_candle(candle &x_cd,string path)
  {
   if(FileIsExist(path,FILE_COMMON))
     {
      double temp[4];
      int filehandle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
        {
         FileReadArray(filehandle,temp,0,WHOLE_ARRAY);
         FileClose(filehandle);
         x_cd.max=temp[0];
         x_cd.min=temp[1];
         x_cd.open=temp[2];
         x_cd.close=temp[3];
        }
      else Print("Falha para abrir o arquivo candle , erro ",GetLastError());
     }
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*void save_candle(candle &x_cd,string path)
  {
   double temp[4];
   int filehandle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   if(filehandle!=INVALID_HANDLE)
     {
      temp[0]=x_cd.max;
      temp[1]=x_cd.min;
      temp[2]=x_cd.open;
      temp[3]=x_cd.close;
      FileWriteArray(filehandle,temp,0,WHOLE_ARRAY);
      FileClose(filehandle);
     }
   else Print("Falha para abrir o arquivo candle , erro ",GetLastError());
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ler_erro_aceitavel(string path)//se não existir já cria
  {
   double erro=0;
   if(FileIsExist(path,FILE_COMMON))
     {
      int filehandle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
        {
         erro=FileReadDouble(filehandle);
         FileClose(filehandle);
         return erro;
        }
      else return Min_Val_Neg*2;
     }
   else  return Min_Val_Neg*2;
  }
//+------------------------------------------------------------------+
//|Para gerar holes melhores ao desinicializar o bot                                                             |
//+------------------------------------------------------------------+
/*double calcular_erro(double &matrix[][30])
  {
   double erro=0;
   for(int i=0;i<30;i++)
      for(int w=0;w<4;w++) erro+=MathAbs(matrix[w][i])/240;
   return erro;
  }*/
//+------------------------------------------------------------------+
//Funcao para normalizar os erros aceitaveis, evita que os torne muito grandes                    |
//+------------------------------------------------------------------+
void Normalizar_erros()
  {
   int i=0;
   double menor=1;
   i=ArrayMaximum(Vet_erro);//Menor negativo
   menor=MathAbs(Vet_erro[i]);
   if(menor>=5) //10 ainda é um valor baixo
     {
      for(i=0;i<ArraySize(Vet_erro);i++)
         Vet_erro[i]/=menor;
     }
  }
//+------------------------------------------------------------------+
//|funcao que compara as matrizes match com as matrizes              |
//now(valores atuais) e decide se houve similaridade                 |  
//funcao mais requisitada do expert                                  |
//+------------------------------------------------------------------+
int compara_matrizes(double &match[][30],double &now[][30],double &m_erro[][30],double &err_aceitavel,int tipo)
  {
   int i=29;
   int j=3;
//comecar pelos ultimos valores que correspondem aos candles mais atuais
   bool teste=true;
   double d_temp=0;
   distancias[tipo-1]=0;
   if(!MathIsValidNumber(err_aceitavel)) err_aceitavel=2*Min_Val_Neg;
   for(i=29;i>=0;i--)
     {
      for(j=3;j>=0;j--)
        {
         if(MathIsValidNumber(match[j][i]) && MathIsValidNumber(now[j][i]) && MathIsValidNumber(m_erro[j][i]))
           {
            if(MathAbs((now[j][i]-match[j][i])*m_erro[j][i])-(1+(3/(1+i)))*Min_Val_Neg>=0)//+0*MathAbs(m_erro[j][i])+MathAbs(erro_aceitavel)
              {
               teste=false;
               //oscilar m_erro para buscar um valor true no futuro
               //m_erro[j][i]+=0.2*(-16383.45+(MathRand()))*Min_Val_Neg/16383.5;
               //err_aceitavel+=0.001*(-16383.499+MathRand())*Min_Val_Neg/16383.5;
               //match[j][i]+=(now[j][i]-match[j][i])/380;
              }
            if(m_erro[j][i]>=10) m_erro[j][i]=10;
            else if(m_erro[j][i]<=-10) m_erro[j][i]=-10;
            match[j][i]*=MathMin(MathAbs(match[j][i]),15000*Min_Val_Neg)/MathAbs(match[j][i]);
           }
         else
           {
            now[j][i]=10004*Min_Val_Neg;
            match[j][i]=10000*Min_Val_Neg;
            m_erro[j][i]=8*Min_Val_Neg;
            teste=false;
           }
         d_temp+=MathPow((now[j][i]-match[j][i])*m_erro[j][i],2);
        }
      distancias[tipo-1]+=MathSqrt(d_temp);
      d_temp=0;
     }
   distancias[tipo-1]-=(err_aceitavel*Min_Val_Neg);
/*if(tipo!=0 && tipo<=5)
      if(MathAbs((now[1][29]-match[1][29])*m_erro[1][29])<0.25*Min_Val_Neg)
         if((now[1][28]-match[1][28])*m_erro[1][28]<2*Min_Val_Neg)
            if((now[1][27]-match[1][27])*m_erro[1][27]<4*Min_Val_Neg)
            teste=true;
   else if(tipo>=6)
      if(MathAbs((now[1][29]-match[1][29])*m_erro[1][29])<0.25*Min_Val_Neg)
         if((now[1][28]-match[1][28])*m_erro[1][28]>-2*Min_Val_Neg)
            if((now[1][27]-match[1][27])*m_erro[1][27]>-4*Min_Val_Neg)
               teste=true;*/
   if(teste==true) return 1;//caso perfeito - muito raro
   else return 0;
  }
//+------------------------------------------------------------------+
//| funcao para atualizar valores ao fim de cada operacao     
//| retorna true caso seja um loss                                                            |
//+------------------------------------------------------------------+
bool situacao_stops_dia(double &match[][30],double &m_erro[][30],double &m_temp_erro[][30],double &erro,double &temp_erro,double &mnow[][30])
  {
   bool stop=false;
   double last_trade;
   double l_last_trade;

   if(treinamento_ativo==0)
     {
      HistorySelect(start,end);
      int total=HistoryOrdersTotal();
      ulong last_ticket=HistoryOrderGetTicket(total-1);
      ulong l_last_ticket=HistoryOrderGetTicket(total-2);
      last_trade=double(HistoryOrderGetDouble(last_ticket,ORDER_PRICE_OPEN));
      l_last_trade=double(HistoryOrderGetDouble(l_last_ticket,ORDER_PRICE_OPEN));
     }
   else
     {
      last_trade=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
      l_last_trade=Buy_Sell_Simulado;
     }
   double minimum;
   double maximum;
   int i=0;
   int w=0;
   int j=0;
   int ind_max[2]={0,0};
   int ind_min[2]={0,0};
//-trade_type variavel global que é atualizada de acordo com a ultima operacao >= 1->compra <=-1->venda
   bool compra=false;
   bool venda =false;
   if(trade_type<=(n_holes/2))venda=true;
   else compra=true;
//venda=(trade_type==1 || trade_type==2 || trade_type==3 || trade_type==4 || trade_type==5);
//compra=(trade_type==6 || trade_type==7 || trade_type==8 || trade_type==9 || trade_type==10);
   if((compra && l_last_trade>=last_trade) || (venda && l_last_trade<=last_trade))//------loss 
     {
      oper_counter-=1;
      maximum=MathAbs((mnow[0][29]-match[0][29])*m_erro[0][29]);
      //caso de loss procurar o indice do maior erro e aproximar
      //significa que aquele valor era importante
      //fazer essa alteração 24 x (10% da matriz)
      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<30;w++)
               if(MathAbs((mnow[i][w]-match[i][w])*m_erro[i][w])>maximum)
                 {
                  maximum=MathAbs((mnow[i][w]-match[i][w])*m_erro[i][w]);
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
         if(mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]<0)
            match[ind_max[0]][ind_max[1]]=match[ind_max[0]][ind_max[1]]-Modulador*0.5*MathPow((mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]),2)-2*Min_Val_Neg;//38
         else
            match[ind_max[0]][ind_max[1]]=match[ind_max[0]][ind_max[1]]+Modulador*0.5*MathPow((mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]),2)+2*Min_Val_Neg;
         match[ind_min[0]][ind_min[1]]*=MathMin(MathAbs(match[ind_min[0]][ind_min[1]]),15000*Min_Val_Neg)/MathAbs(match[ind_min[0]][ind_min[1]]);
        }
      //caso de loss procurar o indice do menor erro e afastar
      //significa que aquele valor nao era importante
      //fazer essa alteração 12 x (5% dos candles)
      minimum=MathAbs((mnow[0][29]-match[0][29])*m_erro[0][29]);
      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<30;w++)
               if(MathAbs((mnow[i][w]-match[i][w])*m_erro[i][w])<minimum)
                 {
                  minimum=MathAbs((mnow[i][w]-match[i][w])*m_erro[i][w]);//m_erro_w_h_1[i][w];
                  ind_min[0]=i;
                  ind_min[1]=w;
                 }
         //os minimos precisam ser afastados o suficiente para aumentar a distancia mais do que os maximos diminuiram
         if(mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]<0)
            match[ind_min[0]][ind_min[1]]=match[ind_min[0]][ind_min[1]]+Modulador*0.5*MathPow((mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]),2)+3*Min_Val_Neg;//36
         else match[ind_min[0]][ind_min[1]]=match[ind_min[0]][ind_min[1]]-Modulador*0.5*MathPow((mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]),2)-3*Min_Val_Neg;
         match[ind_min[0]][ind_min[1]]*=MathMin(MathAbs(match[ind_min[0]][ind_min[1]]),15000*Min_Val_Neg)/MathAbs(match[ind_min[0]][ind_min[1]]);
        }
      if(MathAbs(treinamento_ativo)==6)
        {
         erro=temp_erro-(0.2*distancia);//diminuir esse valor para dificultar um nova entrada (para treinamento)
        }
      printf("stop loss caso: "+string(trade_type)+" counter t. profit "+string(counter_t_profit));
      if(simulacao_contabil==1)counter_t_profit=0.9*counter_t_profit;
      copiar_matriz(m_erro,m_temp_erro);
      distancia=temp_dist*0.3;
      //ArrayPrint(distancias);
      dist_sl+=(distancias[trade_type-1]-dist_sl)/21;
      stop=true;
     }
//foi gain 
   else if((compra && l_last_trade<last_trade) || (venda && l_last_trade>last_trade))
     {
      oper_counter+=1;
      ind_max[0]=0;
      ind_max[1]=0;
      ind_min[0]=0;
      ind_min[1]=0;
      minimum=MathAbs((match[0][29]-mnow[0][29])*m_erro[0][29]);
      //caso de gain procurar o indice de menor  erro e reduzir a distancia
      //alterar m_erro para manter a mesma distancia (aumentar a significancia)
      //significa que aquele valor era importante
      //fazer essa alteração 6 x (20% dos candles)
      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<30;w++)
               if(MathAbs((mnow[i][w]-match[i][w])*m_erro[i][w])<minimum)
                 {
                  minimum=MathAbs((mnow[i][w]-match[i][w])*m_erro[i][w]);
                  ind_min[0]=i;
                  ind_min[1]=w;
                 }
         if((mnow[ind_min[0]][ind_min[1]]-match[ind_min[0]][ind_min[1]])>0)
           {
            //decremento de 10% da diferenca + um valor constante
            match[ind_min[0]][ind_min[1]]*=MathMin(MathAbs(match[ind_min[0]][ind_min[1]]),15000*Min_Val_Neg)/MathAbs(match[ind_min[0]][ind_min[1]]);
            m_erro[ind_min[0]][ind_min[1]]*=mnow[ind_min[0]][ind_min[1]]-match[ind_min[0]][ind_min[1]];
            match[ind_min[0]][ind_min[1]]=match[ind_min[0]][ind_min[1]]+Modulador*0.3*MathPow((mnow[ind_min[0]][ind_min[1]]-match[ind_min[0]][ind_min[1]]),2)+(MathRand()/16383.5)*Min_Val_Neg*0.2;//44//48 -300
            m_erro[ind_min[0]][ind_min[1]]/=match[ind_min[0]][ind_min[1]];
           }
         else
           {
            match[ind_min[0]][ind_min[1]]*=MathMin(MathAbs(match[ind_min[0]][ind_min[1]]),15000*Min_Val_Neg)/MathAbs(match[ind_min[0]][ind_min[1]]);
            m_erro[ind_min[0]][ind_min[1]]*=mnow[ind_min[0]][ind_min[1]]-match[ind_min[0]][ind_min[1]];
            match[ind_min[0]][ind_min[1]]=match[ind_min[0]][ind_min[1]]-Modulador*0.3*MathPow((mnow[ind_min[0]][ind_min[1]]-match[ind_min[0]][ind_min[1]]),2)-(MathRand()/16383.5)*Min_Val_Neg*0.2;
            m_erro[ind_min[0]][ind_min[1]]/=match[ind_min[0]][ind_min[1]];
           }
        }
      //caso de gain procurar o indice de maior  erro e aumentar a distancia
      //reduzir o erro de gatilho proporcionalmente diminuindo a significancia
      //significa que aquele valor realmente não era importante
      //fazer essa alteração 12 x (5% dos candles)
      maximum=MathAbs((mnow[0][29]-match[0][29])*m_erro[0][29]);
      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<30;w++)
               if(MathAbs((mnow[i][w]-match[i][w])*m_erro[i][w])>maximum)
                 {
                  maximum=MathAbs((mnow[i][w]-match[i][w])*m_erro[i][w]);
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
         if(mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]>0)
           {
            match[ind_min[0]][ind_min[1]]*=MathMin(MathAbs(match[ind_min[0]][ind_min[1]]),15000*Min_Val_Neg)/MathAbs(match[ind_min[0]][ind_min[1]]);
            m_erro[ind_max[0]][ind_max[1]]*=(mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]);
            match[ind_max[0]][ind_max[1]]=match[ind_max[0]][ind_max[1]]-Modulador*0.3*MathPow((mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]),2)-0.01*(MathRand()/1638.35)*Min_Val_Neg;//36 - +232.3//30 -100
            m_erro[ind_max[0]][ind_max[1]]/=match[ind_max[0]][ind_max[1]];
           }
         else
           {
            match[ind_min[0]][ind_min[1]]*=MathMin(MathAbs(match[ind_min[0]][ind_min[1]]),15000*Min_Val_Neg)/MathAbs(match[ind_min[0]][ind_min[1]]);
            m_erro[ind_max[0]][ind_max[1]]*=(mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]);
            match[ind_max[0]][ind_max[1]]=match[ind_max[0]][ind_max[1]]+Modulador*0.3*MathPow((mnow[ind_max[0]][ind_max[1]]-match[ind_max[0]][ind_max[1]]),2)+0.01*(MathRand()/1638.35)*Min_Val_Neg;
            m_erro[ind_max[0]][ind_max[1]]/=match[ind_max[0]][ind_max[1]];
           }
        }
      if(MathAbs(treinamento_ativo)==6)
        {
         temp_erro=(0.2*erro+0.7*temp_erro);//Absorver valor que deu certo e diminuir um pouco
         erro=temp_erro-(6*(16383.5-MathRand())*Min_Val_Neg/(16383.5));//Oscilar em 3* o min val neg
         Normalizar_erros();//normalizar erros
        }
      if(simulacao_contabil==1)
        {
         counter_t_profit=(0.9*counter_t_profit)+0.1;
        }
      printf("t prof. caso: "+string(trade_type)+" "+"Err acc.: "+string(erro)+" tk p "+string(counter_t_profit)+" dist "+string(distancias[trade_type-1])+" op_gain: "+string(op_gain));
      op_gain+=(counter_t_profit-op_gain)/200;
      aproximar_matriz(m_temp_erro,m_erro);
      temp_dist=(0.5*distancias[trade_type-1]+0.5*temp_dist);
      distancia=0.3*temp_dist;
      copiar_matriz(m_temp_erro,m_erro);
      //ArrayPrint(distancias);
      dist_tp+=(distancias[trade_type-1]-dist_tp)/21;
      stop=false;
     }
   if(trade_type!=0)
     {
      salvar_matriz_4_30(match,paths[trade_type-1][1]);
      salvar_matriz_4_30(m_erro,paths[trade_type-1][0]);
      salvar_erro(erro,paths[trade_type-1][2]);
      printf("distancia: "+string(distancia/0.3)+" d. tp: "+string(dist_tp)+" d. sl: "+string(dist_sl));
     }
   if(stop==true)trade_type=0;
//Comments geram um atraso razoavel na simulação, usado pra debugar
//Comment("M erro: \n"+string(m_erro_w_h_1[ind_min[0]][29])+" \n"+string(m_erro_w_h_2[ind_min[0]][29])+" \n"+string(m_erro_w_h_3[ind_min[0]][29])+" \n"+string(m_erro_w_h_4[ind_min[0]][29])+" \n"+string(m_erro_w_h_5[ind_min[0]][29])+" \n"+string(m_erro_b_h_1[ind_min[0]][29])+" \n"+string(m_erro_b_h_2[ind_min[0]][29])+" \n"+string(m_erro_b_h_3[ind_min[0]][29])+" \n"+string(m_erro_b_h_4[ind_min[0]][29])+" \n"+string(m_erro_b_h_5[ind_min[0]][29])+" \n");//+string(erro_wh1)+" \n"+string(erro_wh2)+" \n"+string(erro_wh3)+" \n"+string(erro_bh1)+" \n"+string(erro_bh2)+" \n"+string(erro_bh1));
   return stop;
  }
//+------------------------------------------------------------------+
//|Inicialização do expert                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Estes valores são relidos depois, do disco                                                                 |
//+------------------------------------------------------------------+
double    erro_bh1=1;
double    erro_bh2=1;
double    erro_bh3=1;
double    erro_bh4=1;
double    erro_bh5=1;
double    erro_wh1=1;
double    erro_wh2=1;
double    erro_wh3=1;
double    erro_wh4=1;
double    erro_wh5=1;
double Vet_erro[n_holes];//metade inicial desse vetor são erros aceitaveis de venda (black_hole) outra metade (white_hole)
double beta=ArrayInitialize(Vet_erro,1);
double    temp_erro_bh1=1;
double    temp_erro_bh2=1;
double    temp_erro_bh3=1;
double    temp_erro_bh4=1;
double    temp_erro_bh5=1;
double    temp_erro_wh1=1;
double    temp_erro_wh2=1;
double    temp_erro_wh3=1;
double    temp_erro_wh4=1;
double    temp_erro_wh5=1;
double Vet_temp_erro[n_holes];
double charlie=ArrayInitialize(Vet_temp_erro,1);
//+------------------------------------------------------------------+
//|Inicio do expert                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//Para uma futura implementacao
   for(int j=0;j<(n_holes/2);j++)
     {
      paths[j][0]="cosmos_training"+"//"+"erro"+string(j+1);
      paths[j][1]="cosmos_training"+"//"+"match"+string(j+1);
      paths[j][2]="cosmos_training"+"//"+"be"+string(j+1);
     }
   for(int j=n_holes;j>(n_holes/2);j--)
     {
      paths[j-1][0]="cosmos_training"+"//"+"erro"+string(j);
      paths[j-1][1]="cosmos_training"+"//"+"match"+string(j);
      paths[j-1][2]="cosmos_training"+"//"+"we"+string(j);
     }
//---Inicializar Menor valor negociavel
   if(_Symbol=="WINQ19" || _Symbol=="WIN$" || _Symbol=="WINV19" || _Symbol=="WINZ19" || _Symbol=="WING20")
     {
      Min_Val_Neg=Min_Val_Neg*7;
     }
//--- Inicializar o gerador de números aleatórios  
   MathSrand(uint(GetMicrosecondCount()));
//--- Inicializar os 30 candles de trabalho
/* double close[30];
   double open[30];
   double high[30];
   double low[30];
   int i=0;*/
//Verificacao se há valores a serem lidos no buffer do metatrader
/*  if(CopyClose(_Symbol,Periodo,0,30,close)!=-1 && CopyOpen(_Symbol,Periodo,0,30,open)!=-1 && CopyHigh(_Symbol,Periodo,0,30,high)!=-1 && CopyLow(_Symbol,Periodo,0,30,low)!=-1)
     {
      i=0;
      while(i<30)
        {
         //copiano candles 30 ultimos -posteriormente usado para calculo de suporte e resistencia
         cd[i].max=high[i];
         cd[i].min=low[i];
         cd[i].open=open[i];
         cd[i].close=close[i];
         i+=1;
        }
     }*/
//+------------------------------------------------------------------+
//| ler/inicializar matrizes match                                                                 |
//+------------------------------------------------------------------+
   ler_matriz_4_30(m_match_b_h_1,paths[0][1]);
   ler_matriz_4_30(m_match_b_h_2,paths[1][1]);
   ler_matriz_4_30(m_match_b_h_3,paths[2][1]);
   ler_matriz_4_30(m_match_b_h_4,paths[3][1]);
   ler_matriz_4_30(m_match_b_h_5,paths[4][1]);
   ler_matriz_4_30(m_match_w_h_1,paths[5][1]);
   ler_matriz_4_30(m_match_w_h_2,paths[6][1]);
   ler_matriz_4_30(m_match_w_h_3,paths[7][1]);
   ler_matriz_4_30(m_match_w_h_4,paths[8][1]);
   ler_matriz_4_30(m_match_w_h_5,paths[9][1]);

//Ler/inicializar matriz diferencas/erro
   ler_m_erro_4_30(m_erro_b_h_1,paths[0][0]);
   ler_m_erro_4_30(m_erro_b_h_2,paths[1][0]);
   ler_m_erro_4_30(m_erro_b_h_3,paths[2][0]);
   ler_m_erro_4_30(m_erro_b_h_4,paths[3][0]);
   ler_m_erro_4_30(m_erro_b_h_5,paths[4][0]);
   ler_m_erro_4_30(m_erro_w_h_1,paths[5][0]);
   ler_m_erro_4_30(m_erro_w_h_2,paths[6][0]);
   ler_m_erro_4_30(m_erro_w_h_3,paths[7][0]);
   ler_m_erro_4_30(m_erro_w_h_4,paths[8][0]);
   ler_m_erro_4_30(m_erro_w_h_5,paths[9][0]);

//Gerar arrays copia dos arrays salvos
//Usados para retornar ao valor anterior caso de loss em uma operacao
   copiar_matriz(m_temp_erro_b_h_1,m_erro_b_h_1);
   copiar_matriz(m_temp_erro_b_h_2,m_erro_b_h_2);
   copiar_matriz(m_temp_erro_b_h_3,m_erro_b_h_3);
   copiar_matriz(m_temp_erro_b_h_4,m_erro_b_h_4);
   copiar_matriz(m_temp_erro_b_h_5,m_erro_b_h_5);
   copiar_matriz(m_temp_erro_w_h_1,m_erro_w_h_1);
   copiar_matriz(m_temp_erro_w_h_2,m_erro_w_h_2);
   copiar_matriz(m_temp_erro_w_h_3,m_erro_w_h_3);
   copiar_matriz(m_temp_erro_w_h_4,m_erro_w_h_4);
   copiar_matriz(m_temp_erro_w_h_5,m_erro_w_h_5);

//ler candles alvo (obsoleto)
/* ler_candle(b_h_1,path_black_hole1);
   ler_candle(b_h_2,path_black_hole2);
   ler_candle(b_h_3,path_black_hole3);
   ler_candle(b_h_4,path_black_hole4);
   ler_candle(b_h_5,path_black_hole5);
   ler_candle(w_h_1,path_white_hole1);
   ler_candle(w_h_2,path_white_hole2);
   ler_candle(w_h_3,path_white_hole3);
   ler_candle(w_h_4,path_white_hole4);
   ler_candle(w_h_5,path_white_hole5);*/

//ler erros aceitaveis
   Vet_erro[0]=ler_erro_aceitavel(paths[0][2]);
   Vet_erro[1]=ler_erro_aceitavel(paths[1][2]);
   Vet_erro[2]=ler_erro_aceitavel(paths[2][2]);
   Vet_erro[3]=ler_erro_aceitavel(paths[3][2]);
   Vet_erro[4]=ler_erro_aceitavel(paths[4][2]);
   Vet_erro[5]=ler_erro_aceitavel(paths[5][2]);
   Vet_erro[6]=ler_erro_aceitavel(paths[6][2]);
   Vet_erro[7]=ler_erro_aceitavel(paths[7][2]);
   Vet_erro[8]=ler_erro_aceitavel(paths[8][2]);
   Vet_erro[9]=ler_erro_aceitavel(paths[9][2]);

//copiar valores de erro aceitavel para variaveis de trabalho
//Usado para retornar ao valor anterior caso haja um loss na utima operacao
   temp_erro_bh1=Vet_erro[0];
   temp_erro_bh2=Vet_erro[1];
   temp_erro_bh3=Vet_erro[2];
   temp_erro_bh4=Vet_erro[3];
   temp_erro_bh5=Vet_erro[4];
   temp_erro_wh1=Vet_erro[5];
   temp_erro_wh2=Vet_erro[6];
   temp_erro_wh3=Vet_erro[7];
   temp_erro_wh4=Vet_erro[8];
   temp_erro_wh5=Vet_erro[9];


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
//ArrayFree(variancia);
/*// salvar os candles alvo
   int i=0;
   while(i<30)
     {
      w_h_1.open=w_h_1.open+(m_match_w_h_1[0][i]/30);
      w_h_1.close=w_h_1.close+(m_match_w_h_1[1][i]/30);
      w_h_1.max=w_h_1.max+(m_match_w_h_1[2][i]/30);
      w_h_1.min=w_h_1.min+(m_match_w_h_1[3][i]/30);
      i++;
     }
   save_candle(w_h_1,path_white_hole1);
   i=0;
   while(i<30)
     {
      w_h_2.open=w_h_2.open+(m_match_w_h_2[0][i]/30);
      w_h_2.close=w_h_2.close+(m_match_w_h_2[1][i]/30);
      w_h_2.max=w_h_2.max+(m_match_w_h_2[2][i]/30);
      w_h_2.min=w_h_2.min+(m_match_w_h_2[3][i]/30);
      i++;
     }
   save_candle(w_h_2,path_white_hole2);
   i=0;
   while(i<30)
     {
      w_h_3.open=w_h_3.open+(m_match_w_h_3[0][i]/30);
      w_h_3.close=w_h_3.close+(m_match_w_h_3[1][i]/30);
      w_h_3.max=w_h_3.max+(m_match_w_h_3[2][i]/30);
      w_h_3.min=w_h_3.min+(m_match_w_h_3[3][i]/30);
      i++;
     }
   save_candle(w_h_3,path_white_hole3);
   i=0;
   while(i<30)
     {
      w_h_4.open=w_h_4.open+(m_match_w_h_4[0][i]/30);
      w_h_4.close=w_h_4.close+(m_match_w_h_4[1][i]/30);
      w_h_4.max=w_h_4.max+(m_match_w_h_4[2][i]/30);
      w_h_4.min=w_h_4.min+(m_match_w_h_4[3][i]/30);
      i++;
     }
   save_candle(w_h_4,path_white_hole3);
   i=0;
   while(i<30)
     {
      w_h_5.open=w_h_5.open+(m_match_w_h_5[0][i]/30);
      w_h_5.close=w_h_5.close+(m_match_w_h_5[1][i]/30);
      w_h_5.max=w_h_5.max+(m_match_w_h_5[2][i]/30);
      w_h_5.min=w_h_5.min+(m_match_w_h_5[3][i]/30);
      i++;
     }
   save_candle(w_h_5,path_white_hole3);
   i=0;
   while(i<30)
     {
      b_h_1.open=b_h_1.open+(m_match_b_h_1[0][i]/30);
      b_h_1.close=b_h_1.close+(m_match_b_h_1[1][i]/30);
      b_h_1.max=b_h_1.max+(m_match_b_h_1[2][i]/30);
      b_h_1.min=b_h_1.min+(m_match_b_h_1[3][i]/30);
      i++;
     }
   save_candle(b_h_1,path_black_hole1);
   i=0;
   while(i<30)
     {
      b_h_2.open=b_h_2.open+(m_match_b_h_2[0][i]/30);
      b_h_2.close=b_h_2.close+(m_match_b_h_2[1][i]/30);
      b_h_2.max=b_h_2.max+(m_match_b_h_2[2][i]/30);
      b_h_2.min=b_h_2.min+(m_match_b_h_2[3][i]/30);
      i++;
     }
   save_candle(b_h_2,path_black_hole2);
   i=0;
   while(i<30)
     {
      b_h_3.open=b_h_3.open+(m_match_b_h_3[0][i]/30);
      b_h_3.close=b_h_3.close+(m_match_b_h_3[1][i]/30);
      b_h_3.max=b_h_3.max+(m_match_b_h_3[2][i]/30);
      b_h_3.min=b_h_3.min+(m_match_b_h_3[3][i]/30);
      i++;
     }
   save_candle(b_h_3,path_black_hole3);
   i=0;
   while(i<30)
     {
      b_h_4.open=b_h_4.open+(m_match_b_h_4[0][i]/30);
      b_h_4.close=b_h_4.close+(m_match_b_h_4[1][i]/30);
      b_h_4.max=b_h_4.max+(m_match_b_h_4[2][i]/30);
      b_h_4.min=b_h_4.min+(m_match_b_h_4[3][i]/30);
      i++;
     }
   save_candle(b_h_4,path_black_hole4);
   i=0;
   while(i<30)
     {
      b_h_5.open=b_h_5.open+(m_match_b_h_5[0][i]/30);
      b_h_5.close=b_h_5.close+(m_match_b_h_5[1][i]/30);
      b_h_5.max=b_h_5.max+(m_match_b_h_5[2][i]/30);
      b_h_5.min=b_h_5.min+(m_match_b_h_5[3][i]/30);
      i++;
     }
   save_candle(b_h_5,path_black_hole5);*/

//salvar os arrays de match
   salvar_matriz_4_30(m_match_b_h_1,paths[0][1]);
   salvar_matriz_4_30(m_match_b_h_2,paths[1][1]);
   salvar_matriz_4_30(m_match_b_h_3,paths[2][1]);
   salvar_matriz_4_30(m_match_b_h_4,paths[3][1]);
   salvar_matriz_4_30(m_match_b_h_5,paths[4][1]);
   salvar_matriz_4_30(m_match_w_h_1,paths[5][1]);
   salvar_matriz_4_30(m_match_w_h_2,paths[6][1]);
   salvar_matriz_4_30(m_match_w_h_3,paths[7][1]);
   salvar_matriz_4_30(m_match_w_h_4,paths[8][1]);
   salvar_matriz_4_30(m_match_w_h_5,paths[9][1]);

//salvar as matrizes de erro
   salvar_matriz_4_30(m_erro_b_h_1,paths[0][0]);
   salvar_matriz_4_30(m_erro_b_h_2,paths[1][0]);
   salvar_matriz_4_30(m_erro_b_h_3,paths[2][0]);
   salvar_matriz_4_30(m_erro_b_h_4,paths[6][0]);
   salvar_matriz_4_30(m_erro_b_h_5,paths[7][0]);
   salvar_matriz_4_30(m_erro_w_h_1,paths[3][0]);
   salvar_matriz_4_30(m_erro_w_h_2,paths[4][0]);
   salvar_matriz_4_30(m_erro_w_h_3,paths[5][0]);
   salvar_matriz_4_30(m_erro_w_h_4,paths[8][0]);
   salvar_matriz_4_30(m_erro_w_h_5,paths[9][0]);

//Salvar os erros aceitaveis
   int handle=FileOpen(paths[0][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,Vet_erro[0]);
   FileClose(handle);
   handle=FileOpen(paths[1][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,Vet_erro[1]);
   FileClose(handle);
   handle=FileOpen(paths[2][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,Vet_erro[2]);
   FileClose(handle);
   handle=FileOpen(paths[3][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,Vet_erro[3]);
   FileClose(handle);
   handle=FileOpen(paths[4][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,Vet_erro[4]);
   FileClose(handle);
   handle=FileOpen(paths[5][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,Vet_erro[5]);
   FileClose(handle);
   handle=FileOpen(paths[6][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,Vet_erro[6]);
   FileClose(handle);
   handle=FileOpen(paths[7][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,Vet_erro[7]);
   FileClose(handle);
   handle=FileOpen(paths[8][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,Vet_erro[8]);
   FileClose(handle);
   handle=FileOpen(paths[9][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,Vet_erro[9]);
   FileClose(handle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime    tm=TimeCurrent();
   end=TimeCurrent();
   MqlDateTime stm;
   TimeToStruct(tm,stm);
   bool fim_do_pregao=false;
   int posicoes=PositionsTotal();
//Comments geram um atraso razoavel na simulação, usado pra debugar
//Comment("M erro: \n"+string(m_erro_w_h_1[1][29])+" \n"+string(m_erro_w_h_2[1][29])+" \n"+string(m_erro_w_h_3[1][29])+" \n"+string(m_erro_w_h_4[1][29])+" \n"+string(m_erro_w_h_5[1][29])+" \n"+string(m_erro_b_h_1[1][29])+" \n"+string(m_erro_b_h_2[1][29])+" \n"+string(m_erro_b_h_3[1][29])+" \n"+string(m_erro_b_h_4[1][29])+" \n"+string(m_erro_b_h_5[1][29])+" \n we1: "+string(erro_wh1)+" \nwe2: "+string(erro_wh2)+" \n we3: "+string(erro_wh3)+" \n we4: "+string(erro_wh4)+" \n we5:"+string(erro_wh5)+" \n be1: "+string(erro_bh1)+" \n be2: "+string(erro_bh2)+" \n be3: "+string(erro_bh3)+" \n be4: "+string(erro_bh4)+" \n be5: "+string(erro_bh5)+"\n dst:"+string(distancia));
//Verificar inicio e fim do pregao
   if(stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<10) || (stm.hour==10 && stm.min<=10))
     {
      //operar apenas apos 11:05 e antes das 17:25 
      fim_do_pregao=true;
      start=TimeCurrent()-5*60;
      end=start;
      trade_type=0;
      on_trade=false;
      //dessa forma consigo pegar ao menos 1 dia de  pregão para analise dos stops
      //se o bot for ligado ao final do pregão ainda analisa o pregão inteiro  1 dia=86400s 1h = 3600 9h=32400
      qtdd_loss=0;//enquanto o dia não inicia essa variavel se mantem zerada
      if(PositionsTotal()!=0) trade.PositionClose(_Symbol,ULONG_MAX);
     }
   else fim_do_pregao=false;
//Analise de stops
//chamada da funcao situacao_stops_dia que promove o treinamento dos arrays
   if(posicoes==0)
     {
      if(on_trade==true)
        {//houve uma ordem finalizada recentemente
         on_trade=false;
         Sleep(30000);
         switch(trade_type)
           {
            case White_Hole_1_Compra:
               if(situacao_stops_dia(m_match_w_h_1,m_erro_w_h_1,m_temp_erro_w_h_1,Vet_erro[5],temp_erro_wh1,m_now))
                 {
                  qtdd_loss=1;
                  break;
                 }///ATENCAO desativado o incremento ´para treinamento
            case White_Hole_2_Compra:
               if(situacao_stops_dia(m_match_w_h_2,m_erro_w_h_2,m_temp_erro_w_h_2,Vet_erro[6],temp_erro_wh2,m_now))
                 {
                  qtdd_loss=1;
                  break;
                 }///ATENCAO desativado o incremento ´para treinamento
            case White_Hole_3_Compra:
               if(situacao_stops_dia(m_match_w_h_3,m_erro_w_h_3,m_temp_erro_w_h_3,Vet_erro[7],temp_erro_wh3,m_now))
                 {
                  qtdd_loss=1;
                  break;
                 }///ATENCAO desativado o incremento ´para treinamento
            case White_Hole_4_Compra:
               if(situacao_stops_dia(m_match_w_h_4,m_erro_w_h_4,m_temp_erro_w_h_4,Vet_erro[8],temp_erro_wh4,m_now))
                 {
                  qtdd_loss=1;
                  break;
                 }///ATENCAO desativado o incremento ´para treinamento
            case White_Hole_5_Compra:
               if(situacao_stops_dia(m_match_w_h_5,m_erro_w_h_5,m_temp_erro_w_h_5,Vet_erro[9],temp_erro_wh5,m_now))
                 {
                  qtdd_loss=1;
                  break;
                 }///ATENCAO desativado o incremento ´para treinamento
            case Black_Hole_1_Venda:
               if(situacao_stops_dia(m_match_b_h_1,m_erro_b_h_1,m_temp_erro_b_h_1,Vet_erro[0],temp_erro_bh1,m_now))
                 {
                  qtdd_loss=1;
                  break;
                 }///ATENCAO desativado o incremento ´para treinamento
            case Black_Hole_2_Venda:
               if(situacao_stops_dia(m_match_b_h_2,m_erro_b_h_2,m_temp_erro_b_h_2,Vet_erro[1],temp_erro_bh2,m_now))
                 {
                  qtdd_loss=1;
                  break;
                 }///ATENCAO desativado o incremento ´para treinamento
            case Black_Hole_3_Venda:
               if(situacao_stops_dia(m_match_b_h_3,m_erro_b_h_3,m_temp_erro_b_h_3,Vet_erro[2],temp_erro_bh3,m_now))
                 {
                  qtdd_loss=1;
                  break;
                 }///ATENCAO desativado o incremento ´para treinamento
            case Black_Hole_4_Venda:
               if(situacao_stops_dia(m_match_b_h_4,m_erro_b_h_4,m_temp_erro_b_h_4,Vet_erro[3],temp_erro_bh4,m_now))
                 {
                  qtdd_loss=1;
                  break;
                 }///ATENCAO desativado o incremento ´para treinamento
            case Black_Hole_5_Venda:
               if(situacao_stops_dia(m_match_b_h_5,m_erro_b_h_5,m_temp_erro_b_h_5,Vet_erro[4],temp_erro_bh5,m_now))
                 {
                  qtdd_loss=1;
                  break;
                 }///ATENCAO desativado o incremento ´para treinamento
            default:
               break;
           }
         //else qtdd_loss-=1;
         //mudar depois para resolver o problema do reinicio do bot
         //rodar o historico inteiro do dia pode ser uma solução sacrificando processamento
        }
     }
   if(true)//ativo apenas na fase de treinamento---entradas forcadas
     {//treinamento habilitado ->true
      //gera compras e vendas aleatorias para treinar matrizes match e erro
      if((stm.hour==12 || stm.hour==16) && stm.min==1 && stm.sec<=20)
        {
         treinamento_ativo=1;
        }
      else if(stm.day_of_week==3 && (stm.hour==12) && stm.min==7 && stm.sec<=5)
        {
         treinamento_ativo=2;
        }
      else if(stm.day_of_week==4 && (stm.hour==13) && stm.min==13 && stm.sec<=5)
        {
         treinamento_ativo=-1;
        }
      else if(stm.day_of_week==5 && (stm.hour==14) && stm.min==19 && stm.sec<=5)
        {
         treinamento_ativo=-2;
        }
      else if(stm.day_of_week==3 && (stm.hour==15) && stm.min==25 && stm.sec<=5)
        {
         treinamento_ativo=3;
        }
      else if(stm.day_of_week==4 && (stm.hour==16) && stm.min==31 && stm.sec<=5)
        {
         treinamento_ativo=-3;
        }
      else if(stm.day_of_week==5 && (stm.hour==17) && stm.min==37 && stm.sec<=5)
        {
         treinamento_ativo=4;
        }
      else if(stm.day_of_week==3 && (stm.hour==11) && stm.min==44 && stm.sec<=5)
        {
         treinamento_ativo=-4;
        }
      else if(stm.day_of_week==4 && (stm.hour==10) && stm.min==50 && stm.sec<=5)
        {
         treinamento_ativo=5;
        }
      else if(stm.day_of_week==5 && (stm.hour==12 || stm.hour==16) && stm.min==56 && stm.sec<=5)
        {
         treinamento_ativo=-5;
        }
      else if(stm.day_of_week==3 && (stm.hour==14) && stm.min==2 && stm.sec<=20)
        {
         treinamento_ativo=6;
        }
      else if(stm.day_of_week==5 && (stm.hour==16) && stm.min==8 && stm.sec<=20)
        {
         treinamento_ativo=-6;
        }
      else treinamento_ativo=0;
     }

   int i=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(posicoes==0 && fim_do_pregao==false && qtdd_loss<=3 && on_trade==false)
     {
      double close[30];
      double open[30];
      double high[30];
      double low[30];
      if(CopyClose(_Symbol,Periodo,0,30,close)!=-1 && CopyOpen(_Symbol,Periodo,0,30,open)!=-1 && CopyHigh(_Symbol,Periodo,0,30,high)!=-1 && CopyLow(_Symbol,Periodo,0,30,low)!=-1)
        {
         i=0;
         while(i<30)
           {
            //copiano candles 30 ultimos
            m_now[0][i]=open[i];
            m_now[1][i]=close[i];
            m_now[2][i]=high[i];
            m_now[3][i]=low[i];
            i+=1;
           }
        }
      //| Inicio da seção de comparações  
      double comparacoes[10];
      comparacoes[0]= compara_matrizes(m_match_w_h_1,m_now,m_erro_w_h_1,Vet_erro[5],White_Hole_1_Compra);
      comparacoes[1]= compara_matrizes(m_match_w_h_2,m_now,m_erro_w_h_2,Vet_erro[6],White_Hole_2_Compra);
      comparacoes[2]= compara_matrizes(m_match_w_h_3,m_now,m_erro_w_h_3,Vet_erro[7],White_Hole_3_Compra);
      comparacoes[3]= compara_matrizes(m_match_w_h_4,m_now,m_erro_w_h_4,Vet_erro[8],White_Hole_4_Compra);
      comparacoes[4]= compara_matrizes(m_match_w_h_5,m_now,m_erro_w_h_5,Vet_erro[9],White_Hole_5_Compra);
      comparacoes[5]= compara_matrizes(m_match_b_h_1,m_now,m_erro_b_h_1,Vet_erro[0],Black_Hole_1_Venda);
      comparacoes[6]= compara_matrizes(m_match_b_h_2,m_now,m_erro_b_h_2,Vet_erro[1],Black_Hole_2_Venda);
      comparacoes[7]= compara_matrizes(m_match_b_h_3,m_now,m_erro_b_h_3,Vet_erro[2],Black_Hole_3_Venda);
      comparacoes[8]= compara_matrizes(m_match_b_h_4,m_now,m_erro_b_h_4,Vet_erro[3],Black_Hole_4_Venda);
      comparacoes[9]= compara_matrizes(m_match_b_h_5,m_now,m_erro_b_h_5,Vet_erro[4],Black_Hole_5_Venda);

/*if((comparacoes[0]==1 || treinamento_ativo==1) && on_trade==false && posicoes==0)
        {
         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*ask)%50==0 && treinamento_ativo!=1)
           {
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra w h 1 "+string(qtdd_loss));
            Sleep(10000);
            if(treinamento_ativo==0) printf("------------C. White Hole 1 "+string(ask-8*Min_Val_Neg));
            trade_type=White_Hole_1_Compra;
            on_trade_simulado=false;
            on_trade=true;
            end=TimeCurrent();
           }
         else
           {
            Buy_Sell_Simulado=ask;
            trade_type=White_Hole_1_Compra;
            on_trade_simulado=true;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else if((comparacoes[1]==1 || treinamento_ativo==2) && posicoes==0 && on_trade==false)
        {
         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*ask)%50==0 && treinamento_ativo!=2)
           {
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra w h 2 "+string(qtdd_loss));
            Sleep(1000);
            if(treinamento_ativo==0) printf("------------C. White Hole 2 "+string(ask-8*Min_Val_Neg));
            trade_type=White_Hole_2_Compra;
            on_trade_simulado=false;
            on_trade=true;
            end=TimeCurrent();
           }
         else
           {
            Buy_Sell_Simulado=ask;
            trade_type=White_Hole_2_Compra;
            on_trade_simulado=true;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else if((comparacoes[2]==1 || treinamento_ativo==3) && posicoes==0 && on_trade==false)
        {
         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*ask)%50==0 && treinamento_ativo!=3)
           {
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra w h 3 "+string(qtdd_loss));
            Sleep(1000);
            if(treinamento_ativo==0) printf("------------C. White Hole 3 "+string(ask-8*Min_Val_Neg));
            trade_type=White_Hole_3_Compra;
            on_trade_simulado=false;
            on_trade=true;
            end=TimeCurrent();
           }
         else
           {
            Buy_Sell_Simulado=ask;
            trade_type=White_Hole_3_Compra;
            on_trade_simulado=true;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else  if((comparacoes[3]==1 || treinamento_ativo==4) && posicoes==0 && on_trade==false)
        {
         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*ask)%50==0 && treinamento_ativo!=4)
           {
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra w h 4 "+string(qtdd_loss));
            Sleep(5000);
            if(treinamento_ativo==0) printf("------------C. White Hole 4 "+string(ask-8*Min_Val_Neg));
            trade_type=White_Hole_4_Compra;
            on_trade_simulado=false;
            on_trade=true;
            end=TimeCurrent();
           }
         else
           {
            Buy_Sell_Simulado=ask;
            trade_type=White_Hole_4_Compra;
            on_trade_simulado=true;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else  if((comparacoes[4]==1 || treinamento_ativo==5) && posicoes==0 && on_trade==false)
        {
         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*ask)%50==0 && treinamento_ativo!=5)
           {
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra w h 4 "+string(qtdd_loss));
            Sleep(1000);
            if(treinamento_ativo==0) printf("------------C. White Hole 5 "+string(ask-8*Min_Val_Neg));
            trade_type=White_Hole_5_Compra;
            on_trade_simulado=false;
            on_trade=true;
            end=TimeCurrent();
           }
         else
           {
            Buy_Sell_Simulado=ask;
            trade_type=White_Hole_5_Compra;
            on_trade_simulado=true;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else if((comparacoes[5]==1 || treinamento_ativo==-1) && posicoes==0 && on_trade==false)
        {
         //vender
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*bid)%50==0 && treinamento_ativo!=-1)
           {
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda b h 1 "+string(qtdd_loss));
            if(treinamento_ativo==0) printf("------------V. Black Hole 1 "+string(bid+8*Min_Val_Neg));
            on_trade_simulado=false;
            on_trade=true;
            Sleep(1000);
            trade_type=Black_Hole_1_Venda;
            end=TimeCurrent();
           }
         else
           {
            Buy_Sell_Simulado=ask;
            trade_type=Black_Hole_1_Venda;
            on_trade_simulado=true;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else if((comparacoes[6]==1 || treinamento_ativo==-2) && posicoes==0 && on_trade==false)
        {
         //vender
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*bid)%50==0 && treinamento_ativo!=-2)
           {
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda b h 2 "+string(qtdd_loss));
            if(treinamento_ativo==0) printf("------------V. Black Hole 2 "+string(bid+8*Min_Val_Neg));
            on_trade_simulado=false;
            on_trade=true;
            Sleep(1000);
            trade_type=Black_Hole_2_Venda;
            end=TimeCurrent();
           }
         else
           {
            Buy_Sell_Simulado=ask;
            trade_type=Black_Hole_2_Venda;
            on_trade_simulado=true;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else if((comparacoes[7]==1 || treinamento_ativo==-3) && posicoes==0 && on_trade==false)
        {
         //vender
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*bid)%50==0 && treinamento_ativo!=-3)
           {
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda b h 3 "+string(qtdd_loss));
            if(treinamento_ativo==0) printf("------------V. Black Hole 3 "+string(bid+8*Min_Val_Neg));
            on_trade_simulado=false;
            on_trade=true;
            Sleep(1000);
            trade_type=Black_Hole_3_Venda;
            end=TimeCurrent();
           }
         else
           {
            Buy_Sell_Simulado=ask;
            trade_type=Black_Hole_3_Venda;
            on_trade_simulado=true;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else if((comparacoes[8]==1 || treinamento_ativo==-4) && posicoes==0 && on_trade==false)
        {
         //vender
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*bid)%50==0 && treinamento_ativo!=-4)
           {
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda b h 4 "+string(qtdd_loss));
            if(treinamento_ativo==0) printf("------------V. Black Hole 4 "+string(bid+8*Min_Val_Neg));
            on_trade_simulado=false;
            on_trade=true;
            Sleep(1000);
            trade_type=Black_Hole_4_Venda;
            end=TimeCurrent();
           }
         else
           {
            Buy_Sell_Simulado=ask;
            trade_type=Black_Hole_4_Venda;
            on_trade_simulado=true;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else if((comparacoes[9]==1 || treinamento_ativo==-5) && posicoes==0 && on_trade==false)
        {
         //vender
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*bid)%50==0 && treinamento_ativo!=-5)
           {
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda b h 5 "+string(qtdd_loss));
            if(treinamento_ativo==0) printf("------------V. Black Hole 5 "+string(bid+8*Min_Val_Neg));
            on_trade_simulado=false;
            on_trade=true;
            Sleep(1000);
            trade_type=Black_Hole_5_Venda;
            end=TimeCurrent();
           }
         else
           {
            Buy_Sell_Simulado=ask;
            on_trade_simulado=true;
            trade_type=Black_Hole_5_Venda;
            on_trade_simulado=true;
            on_trade=true;
            end=TimeCurrent();
           }
        }*/
      if((distancias[ArrayMinimum(distancias,0,5)]<1*distancia || treinamento_ativo==-6) && posicoes==0 && on_trade==false)
        {
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(distancias[ArrayMinimum(distancias,0,5)]<1.2*dist_tp)simulacao_contabil=1;
         else simulacao_contabil=0;
         if(distancias[ArrayMinimum(distancias,0,5)]<1*dist_tp && counter_t_profit>=op_gain && treinamento_ativo!=-6)
           {
            //vender
            if(int(100*bid)%50==0)
              {
               trade_type=1+ArrayMinimum(distancias,0,5);
               trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda dist "+string(trade_type)+" "+string(distancia));
               if(treinamento_ativo==0) printf("------------V. distancia "+string(bid+8*Min_Val_Neg)+" "+string(trade_type));
               on_trade_simulado=false;
               on_trade=true;
               Sleep(1000);
               end=TimeCurrent();
              }
           }
         else
           {
            Stop_tp_Simulado=last;
            if(on_trade_simulado==false)
              {
               Buy_Sell_Simulado=bid;
               trade_type=1+ArrayMinimum(distancias,0,5);
               on_trade_simulado=true;
              }
            if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
              {
               on_trade=true;
               treinamento_ativo=-6;
               on_trade_simulado=false;
              }
            end=TimeCurrent();
           }
        }
      else if(( distancias[ArrayMinimum(distancias,5,5)]<1*distancia || treinamento_ativo==6) && posicoes==0 && on_trade==false)
        {
         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(distancias[ArrayMinimum(distancias,5,5)]<1.2*dist_tp)simulacao_contabil=1;
         else simulacao_contabil=0;
         if(distancias[ArrayMinimum(distancias,5,5)]<1*dist_tp && counter_t_profit>op_gain && treinamento_ativo!=6)
           {
            if(int(100*ask)%50==0)
              {
               trade_type=1+ArrayMinimum(distancias,5,5);
               trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra dist "+string(trade_type)+" "+string(distancia));
               Sleep(1000);
               if(treinamento_ativo==0) printf("------------C. distancia "+string(ask-8*Min_Val_Neg));
               on_trade_simulado=false;
               on_trade=true;
               end=TimeCurrent();
              }
           }
         else
           {
            Stop_tp_Simulado=last;
            if(on_trade_simulado==false)
              {
               Buy_Sell_Simulado=ask;
               trade_type=1+ArrayMinimum(distancias,5,5);
               on_trade_simulado=true;
              }
            if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
              {
               on_trade=true;
               treinamento_ativo=6;
               on_trade_simulado=false;
              }
            //on_trade=true;
            end=TimeCurrent();
           }
        }
      else
        {
         trade_type=0;
         end=TimeCurrent();
         if(distancia<0.3*dist_tp) distancia+=0.14*Min_Val_Neg;
         else distancia=MathMin(distancia+0.014*Min_Val_Neg,300);
         ArrayFill(comparacoes,0,10,0);
        }
     }
   else
     {
      if(posicoes!=0)
        {
         counter_t_profit=0.25;
         distancia=-3*dist_tp;
        }
      posicoes=PositionsTotal();
     }
  }

//+------------------------------------------------------------------+
