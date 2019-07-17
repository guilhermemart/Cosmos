//+------------------------------------------------------------------+
//|                                                       Cosmos.mq5 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
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
#define Black_Hole_4_Venda   7
#define Black_Hole_5_Venda   8
#define White_Hole_1_Compra  4
#define White_Hole_2_Compra  5
#define White_Hole_3_Compra  6
#define White_Hole_4_Compra  9
#define White_Hole_5_Compra  10


//+------------------------------------------------------------------+
//| Expert initialization                                |
//+------------------------------------------------------------------+
double Min_Val_Neg=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
ENUM_TIMEFRAMES Periodo=_Period;
int lotes=1;
int caso=5;
double m_match_w_h_1[4][60];//condicao 1 de compra
double m_match_w_h_2[4][60];
double m_match_w_h_3[4][60];
double m_match_w_h_4[4][60];
double m_match_w_h_5[4][60];
double m_match_b_h_1[4][60];//condicao 1 de venda
double m_match_b_h_2[4][60];
double m_match_b_h_3[4][60];
double m_match_b_h_4[4][60];
double m_match_b_h_5[4][60];
double m_now[4][60];
double m_erro_w_h_1[4][60];
double m_erro_w_h_2[4][60];
double m_erro_w_h_3[4][60];
double m_erro_w_h_4[4][60];
double m_erro_w_h_5[4][60];
double m_erro_b_h_1[4][60];
double m_erro_b_h_2[4][60];
double m_erro_b_h_3[4][60];
double m_erro_b_h_4[4][60];
double m_erro_b_h_5[4][60];
double m_temp_erro_w_h_1[4][60];
double m_temp_erro_w_h_2[4][60];
double m_temp_erro_w_h_3[4][60];
double m_temp_erro_w_h_4[4][60];
double m_temp_erro_w_h_5[4][60];
double m_temp_erro_b_h_1[4][60];
double m_temp_erro_b_h_2[4][60];
double m_temp_erro_b_h_3[4][60];
double m_temp_erro_b_h_4[4][60];
double m_temp_erro_b_h_5[4][60];
datetime end=TimeCurrent();        //horario atual em datetime nao convertido  
datetime start=TimeCurrent();
int trade_type=0;
int qtdd_loss=0;
bool on_trade=false;
double last,ask,bid;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class candle
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

      if(open<close)
        {
         type=1;//comum de alta
        }
      else if(open>close)
        {
         type=-1;//comum de baixa
        }
      else if(m==close && mi==open)
        {
         type=2; //maruboso de alta
        }
      else if(mi==close && m==open)
        {
         type=-2; //maruboso de baixa
        }
      else
        {
         type=0;//Doji
        }
     }
  };

candle cd[60];//To Do criar isso aqui
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void criar_candle_simples(candle &ca[],int ind,double o,double c,double h,double l)
  {
   ca[ind].close=c;
   ca[ind].open=o;
   ca[ind].max=h;
   ca[ind].min=l;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+  
void recalcular_matriz_erro(double &m_match[][60],double &now[][60],double &m_erro[][60])
  {
   int i=0;
   int j=0;
   for(i=0;i<4;i++)
     {
      for(j=0;j<60;j++)
        {
         //m_erro[i][j]=(3*m_erro[i][j]+MathAbs(m_match[i][j]-now[i][j]))/4;
         m_erro[i][j]=m_match[i][j]-now[i][j];
         m_erro[i][j]=MathAbs(m_erro[i][j]);

        }
     }
  }
//+------------------------------------------------------------------+
//|calculo das matrizes match                                          |
//+------------------------------------------------------------------+
void calcular_m_match(double &match[][60],candle &hole)
  {
   for(int w=ArrayRange(match,1)-1;w>=0;w-=1)
     {
      match[0][w]=cd[w].open-hole.open;
      match[1][w]=cd[w].close-hole.close;
      match[2][w]=cd[w].max-hole.max;
      match[3][w]=cd[w].min-hole.min;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void salvar_matriz_4_60(double  &matriz[][60],string path)
  {
   int filehandle;
   double vec[60];
   string add;
   int i;
   for(int j=0;j<4;j++)
     {

      for(i=0;i<60;i++)
        {
         vec[i]=matriz[j][i];
        }
      add=path+"_"+string(j);
      filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      FileWriteArray(filehandle,vec,0,WHOLE_ARRAY);
      FileClose(filehandle);
     }
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
//|                                                                  |
//+------------------------------------------------------------------+
void ler_matriz_4_60(double  &matriz[][60],string path)
  {

   int filehandle;
   double vec[60];
   ArrayInitialize(vec,0);
   string add;
   int i=0;
   for(int j=0;j<4;j++)
     {

      add=path+"_"+string(j);
      if(FileIsExist(add,FILE_COMMON))
        {
         filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
         FileReadArray(filehandle,vec,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }
      else
        {
         Alert("arquivo "+add+" nao encontrado");
         if(j==0)
           {
            for(i=0;i<60;i++)
              {
               vec[i]=cd[i].open;
              }
           }
         else if(j==1)
           {
            for(i=0;i<60;i++)
              {
               vec[i]=cd[i].close;
              }
           }
         else if(j==2)
           {
            for(i=0;i<60;i++)
              {
               vec[i]=cd[i].max;
              }
           }
         else //if(j==3)
           {
            for(i=0;i<60;i++)
              {
               vec[i]=cd[i].min;
              }
           }
        }
      for(i=0;i<60;i++)
        {
         matriz[j][i]=vec[i];
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void criar_matriz(double &Matriz[][60])
  {
   double arr[60];
   int x=0;
   for(int j=0;j<4;j++)
     {
      for(x=0;x<60;x++)
        {
         Matriz[j][x]=(1+(MathRand()%4))*Min_Val_Neg;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void aproximar_matriz(double &Matriz_temp[][60],double &Matriz_erro[][60])
  {
   int i=0;
   for(int j=0;j<4;j++)
     {
      for(i=0;i<60;i++)
        {
         Matriz_temp[j][i]=(2*Matriz_temp[j][i]+1*Matriz_erro[j][i])/3;
        }
     }
  }
//+------------------------------------------------------------------+
//|Copia M2 em M1                                                                  |
//+------------------------------------------------------------------+
void copiar_matriz(double &M1[][60],double &M2[][60])
  {
   int i=0;
   for(int j=0;j<4;j++)
     {
      for(i=0;i<60;i++)
        {
         M1[j][i]=M2[j][i];
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ler_m_erro_4_60(double &matriz[][60],string path)
  {
   int filehandle;
   double vec[60];
   string add;
   int i=0;
   for(int j=0;j<4;j++)
     {

      add=path+"_"+string(j);
      if(FileIsExist(add,FILE_COMMON))
        {
         filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
         FileReadArray(filehandle,vec,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }
      else
        {
         Alert("arquivo "+add+" nao encontrado");
         ArrayInitialize(vec,Min_Val_Neg);
        }
      for(i=0;i<60;i++)
        {
         matriz[j][i]=vec[i];
        }
     }
  }
//+------------------------------------------------------------------+
//|busca dos holes                                                                  |
//+------------------------------------------------------------------+

void ler_candle(candle &x_cd,string path)
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
      else
         Print("Falha para abrir o arquivo candle , erro ",GetLastError());
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void save_candle(candle &x_cd,string path)
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
   else
      Print("Falha para abrir o arquivo candle , erro ",GetLastError());

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ler_erro_aceitavel(string path)
  {
   double erro=0;
   if(FileIsExist(path,FILE_COMMON))
     {
      int filehandle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
        {
         erro=MathAbs(FileReadDouble(filehandle));
         FileClose(filehandle);
         return erro;
        }
      else
        {
         return Min_Val_Neg*2;
        }
     }
   else
     {
      int filehandle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
        {
         erro=2*Min_Val_Neg;
         MathAbs(FileWriteDouble(filehandle,erro));
         FileClose(filehandle);
         return erro;
        }
      else
        {
         return Min_Val_Neg*2;
        }
     }
  }
//+------------------------------------------------------------------+
//|Para gerar holes melhores ao desinicializar o bot                                                             |
//+------------------------------------------------------------------+
double calcular_erro(double &matrix[][60])
  {
   double erro=0;
   for(int i=0;i<60;i++)
     {
      for(int w=0;w<4;w++)
        {
         erro+=MathAbs(matrix[w][i])/240;
        }
     }
   return erro;
  }
//+------------------------------------------------------------------+
//|funcao que compara as metrizes match com as matrizes 
//now(valores atuais) e decide se houve similaridade                                                                  |
//+------------------------------------------------------------------+
int compara_matrizes(double &match[][60],double &now[][60],double &m_erro[][60],double &err_aceitavel)
  {
  int i=0;
   int j=0;
   bool teste=true;
   if(!MathIsValidNumber(err_aceitavel)) err_aceitavel=2*Min_Val_Neg;
   for(j=0;j<4;j++)
     {
      for(i=0;i<60;i++)
        {
         if(MathIsValidNumber(match[j][i]) && MathIsValidNumber(now[j][i]) && MathIsValidNumber(m_erro[j][i]))
           {
            if(MathAbs(match[j][i]-now[j][i])>=m_erro[j][i]+err_aceitavel*Min_Val_Neg)//+0*MathAbs(m_erro[j][i])+MathAbs(erro_aceitavel)
              {
               teste=false;
              }
            m_erro[j][i]=m_erro[j][i]+0.001*(100-(MathRand()%201))*Min_Val_Neg;
           }
         else
           {
            now[j][i]=10004*Min_Val_Neg;
            match[j][i]=10000*Min_Val_Neg;
            m_erro[j][i]=8*Min_Val_Neg;
            teste=false;
           }
        }

     }
   if(teste==true) return 1;
   else return 0;
  }
//+------------------------------------------------------------------+
//| funcao para atualizar valores ao fim de cada operacao     
//| retorna true caso seja um loss                                                            |
//+------------------------------------------------------------------+
bool situacao_stops_dia(double &match[][60],double &m_erro[][60],double &m_temp_erro[][60],double &erro,double &temp_erro,double &mnow[][60])
  {
   bool stop=false;
   HistorySelect(start,end);
   int total=HistoryOrdersTotal();
   ulong last_ticket=HistoryOrderGetTicket(total-1);
   ulong l_last_ticket=HistoryOrderGetTicket(total-2);
   double last_trade=double(HistoryOrderGetDouble(last_ticket,ORDER_PRICE_OPEN));
   double l_last_trade=double(HistoryOrderGetDouble(l_last_ticket,ORDER_PRICE_OPEN));
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
   venda=(trade_type==7 || trade_type==8 || trade_type==1 || trade_type==2 || trade_type==3);
   compra=(trade_type==9 || trade_type==10 || trade_type==4 || trade_type==5 || trade_type==6);
   if((compra && l_last_trade>=last_trade) || (venda && l_last_trade<=last_trade))//loss 
     {
      maximum=MathAbs(match[0][0]-mnow[0][0]);
      //caso de loss procurar o indice do maior erro e aproximar
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(match[i][w]-mnow[i][w])>maximum)
                 {
                  maximum=MathAbs(match[i][w]-mnow[i][w]);
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
              }
           }
         if(match[ind_max[0]][ind_max[1]]>mnow[ind_max[0]][ind_max[1]])
           {
            match[ind_max[0]][ind_max[1]]=match[ind_max[0]][ind_max[1]]-1*Min_Val_Neg;
           }
         else match[ind_max[0]][ind_max[1]]=match[ind_max[0]][ind_max[1]]+1*Min_Val_Neg;
         match[ind_max[0]][ind_max[1]]=MathAbs(match[ind_max[0]][ind_max[1]]);
        }
      minimum=MathAbs(match[0][0]-mnow[0][0]);
      //caso de loss procurar o indice do menor erro e afastar
      //significa que aquele valor nao era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<8;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(match[i][w]-mnow[i][w])<minimum)
                 {
                  minimum=MathAbs(match[i][w]-mnow[i][w]);//m_erro_w_h_1[i][w];
                  ind_min[0]=i;
                  ind_min[1]=w;
                 }
              }
           }
         //os minimos precisam ser afastados o suficiente para não entrar novamente
         if(match[ind_min[0]][ind_min[1]]>mnow[ind_min[0]][ind_min[1]])
           {
            match[ind_min[0]][ind_min[1]]=match[ind_min[0]][ind_min[1]]+(1.1*m_erro[ind_min[0]][ind_min[1]]+2*Min_Val_Neg);
           }
         else match[ind_min[0]][ind_min[1]]=match[ind_min[0]][ind_min[1]]-(1.1*m_erro[ind_min[0]][ind_min[1]]+2*Min_Val_Neg);
         match[ind_min[0]][ind_min[1]]=MathAbs(match[ind_min[0]][ind_min[1]]);
        }
      erro=temp_erro;//voltar esses valores para o ultimo que deu certo
      copiar_matriz(m_erro,m_temp_erro);
      printf("stop loss caso: "+string(trade_type));
      stop=true;
     }
//foi gain 

   else if((compra && l_last_trade<last_trade) || (venda && l_last_trade>last_trade))
     {
      ind_max[0]=0;
      ind_max[1]=0;
      ind_min[0]=0;
      ind_min[1]=0;
      minimum=MathAbs(match[0][0]-mnow[0][0]);
      //caso de gain procurar o indice de menor  erro e aproximar,reduzir o erro de gatilho proporcionalmente
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(MathAbs(match[i][w])-mnow[i][w])<minimum)
                 {
                  minimum=MathAbs(MathAbs(match[i][w])-mnow[i][w]);
                  ind_min[0]=i;
                  ind_min[1]=w;
                 }
              }
           }
         if(match[ind_min[0]][ind_min[1]]>mnow[ind_min[0]][ind_min[1]])
           {
            match[ind_min[0]][ind_min[1]]=match[ind_min[0]][ind_min[1]]-(0.01*(100-(MathRand()%191))*Min_Val_Neg);
           }
         else match[ind_min[0]][ind_min[1]]=match[ind_min[0]][ind_min[1]]+(0.01*(100-(MathRand()%191))*Min_Val_Neg);
        }

      maximum=MathAbs(match[0][0]-mnow[0][0]);
      //caso de gain procurar o indice de maior  erro e fastar,aumentar o erro de gatilho proporcionalmente
      //significa que aquele valor não era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(MathAbs(match[i][w])-mnow[i][w])>maximum)
                 {
                  maximum=MathAbs(MathAbs(match[i][w])-mnow[i][w]);
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
              }
           }
         if(match[ind_max[0]][ind_max[1]]>mnow[ind_max[0]][ind_max[1]])
           {
            match[ind_max[0]][ind_max[1]]=match[ind_max[0]][ind_max[1]]+(0.01*(100-(MathRand()%201))*Min_Val_Neg);
           }
         else match[ind_max[0]][ind_max[1]]=match[ind_max[0]][ind_max[1]]-(0.01*(100-(MathRand()%201))*Min_Val_Neg);
        }

      temp_erro=(0.15*erro+0.85*temp_erro);
      erro=temp_erro-(0.01*(100-(MathRand()%201))*Min_Val_Neg);
      aproximar_matriz(m_temp_erro,m_erro);
      copiar_matriz(m_erro,m_temp_erro);
      printf("t prof. caso: "+string(trade_type)+" "+"Err acc.: "+string(erro));
      stop=false;
     }
   if(trade_type!=0)
     {
      salvar_matriz_4_60(match,paths[trade_type-1][1]);
      salvar_matriz_4_60(m_erro,paths[trade_type-1][0]);
      salvar_erro(erro,paths[trade_type-1][2]);
     }
   if(stop==true)trade_type=0;
   return stop;
  }
//+------------------------------------------------------------------+
//|Inicialização do expert                                          |
//+------------------------------------------------------------------+

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
candle w_h_5 = new candle(4000,3994,3997,3995);


//+------------------------------------------------------------------+
//save adress das matrizes de trabalho                                                                 |
//+------------------------------------------------------------------+
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
//Matriz com todos os valores acima
string paths[10][3]=
  {
     {path_erro1,path_match1,path_black_erro1},
     {path_erro2,path_match2,path_black_erro2},
     {path_erro3,path_match3,path_black_erro3},
     {path_erro4,path_match4,path_white_erro1},
     {path_erro5,path_match5,path_white_erro2},
     {path_erro6,path_match6,path_white_erro3},
     {path_erro7,path_match7,path_black_erro4},
     {path_erro8,path_match8,path_black_erro5},
     {path_erro9,path_match9,path_white_erro4},
     {path_erro10,path_match10,path_white_erro5},
  };

//+------------------------------------------------------------------+
//| Estes valores são relidos depois do disco                                                                 |
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//---Inicializar Menor valor negociavel
   if(_Symbol=="WINQ19" || _Symbol=="WIN$" || _Symbol=="WINV19" || _Symbol=="WINZ19" || _Symbol=="WING20")
     {
      Min_Val_Neg=Min_Val_Neg*7;
     }
//---
//--- Inicializar o gerador de números aleatórios  
   MathSrand(GetTickCount());

//--- Inicializar os 60 candles de trabalho
   double close[60];
   double open[60];
   double high[60];
   double low[60];
   int i=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(CopyClose(_Symbol,Periodo,0,60,close)!=-1 && CopyOpen(_Symbol,Periodo,0,60,open)!=-1 && CopyHigh(_Symbol,Periodo,0,60,high)!=-1 && CopyLow(_Symbol,Periodo,0,60,low)!=-1)
     {
      i=0;
      while(i<60)
        {
         //copiano candles 60 ultimos -posteriormente usado para calculo de suporte e resistencia
         cd[i].max=high[i];
         cd[i].min=low[i];
         cd[i].open=open[i];
         cd[i].close=close[i];
         i+=1;
        }
     }
//+------------------------------------------------------------------+
//| ler/iniciar matrizes match                                                                 |
//+------------------------------------------------------------------+
   ler_matriz_4_60(m_match_b_h_1,paths[0][1]);
   ler_matriz_4_60(m_match_b_h_2,paths[1][1]);
   ler_matriz_4_60(m_match_b_h_3,paths[2][1]);
   ler_matriz_4_60(m_match_b_h_4,paths[6][1]);
   ler_matriz_4_60(m_match_b_h_5,paths[7][1]);
   ler_matriz_4_60(m_match_w_h_1,paths[3][1]);
   ler_matriz_4_60(m_match_w_h_2,paths[4][1]);
   ler_matriz_4_60(m_match_w_h_3,paths[5][1]);
   ler_matriz_4_60(m_match_w_h_4,paths[8][1]);
   ler_matriz_4_60(m_match_w_h_5,paths[9][1]);

//inicializar matriz diferencas/erro
   ler_m_erro_4_60(m_erro_b_h_1,paths[0][0]);
   ler_m_erro_4_60(m_erro_b_h_2,paths[1][0]);
   ler_m_erro_4_60(m_erro_b_h_3,paths[2][0]);
   ler_m_erro_4_60(m_erro_b_h_4,paths[6][0]);
   ler_m_erro_4_60(m_erro_b_h_5,paths[7][0]);
   ler_m_erro_4_60(m_erro_w_h_1,paths[3][0]);
   ler_m_erro_4_60(m_erro_w_h_2,paths[4][0]);
   ler_m_erro_4_60(m_erro_w_h_3,paths[5][0]);
   ler_m_erro_4_60(m_erro_w_h_4,paths[8][0]);
   ler_m_erro_4_60(m_erro_w_h_5,paths[9][0]);

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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//ler candles alvo
   ler_candle(b_h_1,path_black_hole1);
   ler_candle(b_h_2,path_black_hole2);
   ler_candle(b_h_3,path_black_hole3);
   ler_candle(b_h_4,path_black_hole4);
   ler_candle(b_h_5,path_black_hole5);
   ler_candle(w_h_1,path_white_hole1);
   ler_candle(w_h_2,path_white_hole2);
   ler_candle(w_h_3,path_white_hole3);
   ler_candle(w_h_4,path_white_hole4);
   ler_candle(w_h_5,path_white_hole5);
//ler erros aceitaveis
   erro_bh1=ler_erro_aceitavel(paths[0][2]);
   erro_bh2=ler_erro_aceitavel(paths[1][2]);
   erro_bh3=ler_erro_aceitavel(paths[2][2]);
   erro_bh4=ler_erro_aceitavel(paths[6][2]);
   erro_bh5=ler_erro_aceitavel(paths[7][2]);
   erro_wh1=ler_erro_aceitavel(paths[3][2]);
   erro_wh2=ler_erro_aceitavel(paths[4][2]);
   erro_wh3=ler_erro_aceitavel(paths[5][2]);
   erro_wh4=ler_erro_aceitavel(paths[8][2]);
   erro_wh5=ler_erro_aceitavel(paths[9][2]);
   temp_erro_bh1=erro_bh1;
   temp_erro_bh2=erro_bh2;
   temp_erro_bh3=erro_bh3;
   temp_erro_bh4=erro_bh4;
   temp_erro_bh5=erro_bh5;
   temp_erro_wh1=erro_wh1;
   temp_erro_wh2=erro_wh2;
   temp_erro_wh3=erro_wh3;
   temp_erro_wh4=erro_wh4;
   temp_erro_wh5=erro_wh5;

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
//---desinicializar Menor valor negociavel
   if(_Symbol=="WINQ19" || _Symbol=="WIN$" || _Symbol=="WINV19" || _Symbol=="WINZ19" || _Symbol=="WING20")
     {
      Min_Val_Neg=Min_Val_Neg*7;
     }

// salvar os holes
   int i=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   while(i<60)
     {
      w_h_1.open=w_h_1.open+(m_match_w_h_1[0][i]/60);
      w_h_1.close=w_h_1.close+(m_match_w_h_1[1][i]/60);
      w_h_1.max=w_h_1.max+(m_match_w_h_1[2][i]/60);
      w_h_1.min=w_h_1.min+(m_match_w_h_1[3][i]/60);
      i++;
     }
   save_candle(w_h_1,path_white_hole1);
   i=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   while(i<60)
     {
      w_h_2.open=w_h_2.open+(m_match_w_h_2[0][i]/60);
      w_h_2.close=w_h_2.close+(m_match_w_h_2[1][i]/60);
      w_h_2.max=w_h_2.max+(m_match_w_h_2[2][i]/60);
      w_h_2.min=w_h_2.min+(m_match_w_h_2[3][i]/60);
      i++;
     }
   save_candle(w_h_2,path_white_hole2);
   i=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   while(i<60)
     {
      w_h_3.open=w_h_3.open+(m_match_w_h_3[0][i]/60);
      w_h_3.close=w_h_3.close+(m_match_w_h_3[1][i]/60);
      w_h_3.max=w_h_3.max+(m_match_w_h_3[2][i]/60);
      w_h_3.min=w_h_3.min+(m_match_w_h_3[3][i]/60);
      i++;
     }
   save_candle(w_h_3,path_white_hole3);
   i=0;
   while(i<60)
     {
      w_h_4.open=w_h_4.open+(m_match_w_h_4[0][i]/60);
      w_h_4.close=w_h_4.close+(m_match_w_h_4[1][i]/60);
      w_h_4.max=w_h_4.max+(m_match_w_h_4[2][i]/60);
      w_h_4.min=w_h_4.min+(m_match_w_h_4[3][i]/60);
      i++;
     }
   save_candle(w_h_4,path_white_hole3);
   i=0;   while(i<60)
     {
      w_h_5.open=w_h_5.open+(m_match_w_h_5[0][i]/60);
      w_h_5.close=w_h_5.close+(m_match_w_h_5[1][i]/60);
      w_h_5.max=w_h_5.max+(m_match_w_h_5[2][i]/60);
      w_h_5.min=w_h_5.min+(m_match_w_h_5[3][i]/60);
      i++;
     }
   save_candle(w_h_5,path_white_hole3);
   i=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   while(i<60)
     {
      b_h_1.open=b_h_1.open+(m_match_b_h_1[0][i]/60);
      b_h_1.close=b_h_1.close+(m_match_b_h_1[1][i]/60);
      b_h_1.max=b_h_1.max+(m_match_b_h_1[2][i]/60);
      b_h_1.min=b_h_1.min+(m_match_b_h_1[3][i]/60);
      i++;
     }
   save_candle(b_h_1,path_black_hole1);
   i=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   while(i<60)
     {
      b_h_2.open=b_h_2.open+(m_match_b_h_2[0][i]/60);
      b_h_2.close=b_h_2.close+(m_match_b_h_2[1][i]/60);
      b_h_2.max=b_h_2.max+(m_match_b_h_2[2][i]/60);
      b_h_2.min=b_h_2.min+(m_match_b_h_2[3][i]/60);
      i++;
     }
   save_candle(b_h_2,path_black_hole2);
   i=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   while(i<60)
     {
      b_h_3.open=b_h_3.open+(m_match_b_h_3[0][i]/60);
      b_h_3.close=b_h_3.close+(m_match_b_h_3[1][i]/60);
      b_h_3.max=b_h_3.max+(m_match_b_h_3[2][i]/60);
      b_h_3.min=b_h_3.min+(m_match_b_h_3[3][i]/60);
      i++;
     }
   save_candle(b_h_3,path_black_hole3);
   i=0;
   while(i<60)
     {
      b_h_4.open=b_h_4.open+(m_match_b_h_4[0][i]/60);
      b_h_4.close=b_h_4.close+(m_match_b_h_4[1][i]/60);
      b_h_4.max=b_h_4.max+(m_match_b_h_4[2][i]/60);
      b_h_4.min=b_h_4.min+(m_match_b_h_4[3][i]/60);
      i++;
     }
   save_candle(b_h_4,path_black_hole4);
   i=0;
   while(i<60)
     {
      b_h_5.open=b_h_5.open+(m_match_b_h_5[0][i]/60);
      b_h_5.close=b_h_5.close+(m_match_b_h_5[1][i]/60);
      b_h_5.max=b_h_5.max+(m_match_b_h_5[2][i]/60);
      b_h_5.min=b_h_5.min+(m_match_b_h_5[3][i]/60);
      i++;
     }
   save_candle(b_h_5,path_black_hole5);
   i=0;

   salvar_matriz_4_60(m_match_b_h_1,paths[0][1]);
   salvar_matriz_4_60(m_match_b_h_2,paths[1][1]);
   salvar_matriz_4_60(m_match_b_h_3,paths[2][1]);
   salvar_matriz_4_60(m_match_b_h_4,paths[6][1]);
   salvar_matriz_4_60(m_match_b_h_5,paths[7][1]);
   salvar_matriz_4_60(m_match_w_h_1,paths[3][1]);
   salvar_matriz_4_60(m_match_w_h_2,paths[4][1]);
   salvar_matriz_4_60(m_match_w_h_3,paths[5][1]);
   salvar_matriz_4_60(m_match_w_h_4,paths[8][1]);
   salvar_matriz_4_60(m_match_w_h_5,paths[9][1]);

   salvar_matriz_4_60(m_erro_b_h_1,paths[0][0]);
   salvar_matriz_4_60(m_erro_b_h_2,paths[1][0]);
   salvar_matriz_4_60(m_erro_b_h_3,paths[2][0]);
   salvar_matriz_4_60(m_erro_b_h_4,paths[6][0]);
   salvar_matriz_4_60(m_erro_b_h_5,paths[7][0]);
   salvar_matriz_4_60(m_erro_w_h_1,paths[3][0]);
   salvar_matriz_4_60(m_erro_w_h_2,paths[4][0]);
   salvar_matriz_4_60(m_erro_w_h_3,paths[5][0]);
   salvar_matriz_4_60(m_erro_w_h_2,paths[8][0]);
   salvar_matriz_4_60(m_erro_w_h_3,paths[9][0]);

   int handle=FileOpen(paths[0][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_bh1);
   FileClose(handle);
   handle=FileOpen(paths[1][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_bh2);
   FileClose(handle);
   handle=FileOpen(paths[2][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_bh3);
   FileClose(handle);
   handle=FileOpen(paths[6][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_bh4);
   FileClose(handle);
   handle=FileOpen(paths[7][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_bh5);
   FileClose(handle);
   handle=FileOpen(paths[3][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_wh1);
   FileClose(handle);
   handle=FileOpen(paths[4][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_wh2);
   FileClose(handle);
   handle=FileOpen(paths[5][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_wh3);
   FileClose(handle);
   handle=FileOpen(paths[8][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_wh4);
   FileClose(handle);
   handle=FileOpen(paths[9][2],FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_wh5);
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
   int treinamento_ativo=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<9) || (stm.hour==9 && stm.min<=40))
     {
      //operar apenas apos 11:05 e antes das 17:25 
      fim_do_pregao=true;
      start=TimeCurrent()-5*60;
      end=start;
      trade_type=0;
      on_trade=false;
      //dessa forma consigo pegar ao menos 1 dia de  pregão
      //se o bot for ligado ao final do pregão ainda analisa o pregão inteiro  1 dia=86400s 1h = 3600 9h=32400
      qtdd_loss=0;//enquanto o dia não inicia essa variavel se mantem zerada
      if(PositionsTotal()!=0)
        {
         trade.PositionClose(_Symbol,ULONG_MAX);
        }
     }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   else
     {
      fim_do_pregao=false;
     }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(posicoes==0)
     {
      if(on_trade==true)
        {//houve uma ordem finalizada recentemente
         on_trade=false;
         switch(trade_type)
           {
            case White_Hole_1_Compra:
               if(situacao_stops_dia(m_match_w_h_1,m_erro_w_h_1,m_temp_erro_w_h_1,erro_wh1,temp_erro_wh1,m_now)==true)
               qtdd_loss=1;///ATENCAO desativado o incremento ´para treinamento
               break;

            case White_Hole_2_Compra:
               if(situacao_stops_dia(m_match_w_h_2,m_erro_w_h_2,m_temp_erro_w_h_2,erro_wh2,temp_erro_wh2,m_now)==true)
               qtdd_loss=1;///ATENCAO desativado o incremento ´para treinamento
               break;
            case White_Hole_3_Compra:
               if(situacao_stops_dia(m_match_w_h_3,m_erro_w_h_3,m_temp_erro_w_h_3,erro_wh3,temp_erro_wh3,m_now)==true)
               qtdd_loss=1;///ATENCAO desativado o incremento ´para treinamento
               break;
            case White_Hole_4_Compra:
               if(situacao_stops_dia(m_match_w_h_4,m_erro_w_h_4,m_temp_erro_w_h_4,erro_wh4,temp_erro_wh4,m_now)==true)
               qtdd_loss=1;///ATENCAO desativado o incremento ´para treinamento
               break;
            case White_Hole_5_Compra:
               if(situacao_stops_dia(m_match_w_h_5,m_erro_w_h_5,m_temp_erro_w_h_5,erro_wh5,temp_erro_wh5,m_now)==true)
               qtdd_loss=1;///ATENCAO desativado o incremento ´para treinamento
               break;
            case Black_Hole_1_Venda:
               if(situacao_stops_dia(m_match_b_h_1,m_erro_b_h_1,m_temp_erro_b_h_1,erro_bh1,temp_erro_bh1,m_now)==true)
               qtdd_loss=1;///ATENCAO desativado o incremento ´para treinamento
               printf("Stop bh1");
               break;
            case Black_Hole_2_Venda:
               if(situacao_stops_dia(m_match_b_h_2,m_erro_b_h_2,m_temp_erro_b_h_2,erro_bh2,temp_erro_bh2,m_now)==true)
               qtdd_loss=1;///ATENCAO desativado o incremento ´para treinamento
               break;
            case Black_Hole_3_Venda:
               if(situacao_stops_dia(m_match_b_h_3,m_erro_b_h_3,m_temp_erro_b_h_3,erro_bh3,temp_erro_bh3,m_now)==true)
               qtdd_loss=1;///ATENCAO desativado o incremento ´para treinamento
               break;
            default:
               printf("gain");
               break;
           }
         //else qtdd_loss-=1;
         //mudar depois para resolver o problema do reinicio do bot
         //rodar o historico inteiro do dia pode ser uma solução sacrificando processamento
         Sleep(300000);//minimo de 300 segundos entre duas ordens- evita grandes pernadas
        }
      if(false)//ativo apenas na fase de treinamento
        {//treinamento habilitado ->true
         if(stm.min<=6 && stm.sec<=30) treinamento_ativo=1;
         else if(stm.min<12&&stm.sec<=30)treinamento_ativo = 2;
         else if(stm.min<18&&stm.sec<=30)treinamento_ativo = -1;
         else if(stm.min<24&&stm.sec<=30)treinamento_ativo = -2;
         else if(stm.min<30&&stm.sec<=30)treinamento_ativo = 3;
         else if(stm.min<36&&stm.sec<=30)treinamento_ativo = -3;
         else if(stm.min<42 && stm.sec<=30)treinamento_ativo=4;
         else if(stm.min<48 && stm.sec<=30)treinamento_ativo=-4;
         else if(stm.min<54 && stm.sec<=30)treinamento_ativo=5;
         else if(stm.min<59 && stm.sec<=55)treinamento_ativo=-5;
         else treinamento_ativo=0;
        }
     }

   int i=0;
   if(posicoes==0 && fim_do_pregao==false && qtdd_loss<=3 && on_trade==false)
     {
      double close[60];
      double open[60];
      double high[60];
      double low[60];

      if(CopyClose(_Symbol,Periodo,0,60,close)!=-1 && CopyOpen(_Symbol,Periodo,0,60,open)!=-1 && CopyHigh(_Symbol,Periodo,0,60,high)!=-1 && CopyLow(_Symbol,Periodo,0,60,low)!=-1)
        {
         i=0;
         while(i<60)
           {
            //copiano candles 60 ultimos
            m_now[0][i]=open[i];
            m_now[1][i]=close[i];
            m_now[2][i]=high[i];
            m_now[3][i]=low[i];
            i+=1;
           }
        }
      //| Inicio da seção de comparações                                   |                              
      //+------------------------------------------------------------------+
      if((compara_matrizes(m_match_w_h_1,m_now,m_erro_w_h_1,erro_wh1)==1 || treinamento_ativo==1) && on_trade==false && posicoes==0)
        {

         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*ask)%50==0)
           {
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra w h 1 "+string(qtdd_loss));
            Sleep(1000);
            printf("C. White Hole 1 "+string(ask-8*Min_Val_Neg));
            trade_type=White_Hole_1_Compra;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else  if((compara_matrizes(m_match_w_h_2,m_now,m_erro_w_h_2,erro_wh2)==1 || treinamento_ativo==2) && posicoes==0 && on_trade==false)
        {

         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*ask)%50==0)
           {
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra w h 2 "+string(qtdd_loss));
            Sleep(1000);
            printf("C. White Hole 2 "+string(ask-8*Min_Val_Neg));
            trade_type=White_Hole_2_Compra;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else  if((compara_matrizes(m_match_w_h_3,m_now,m_erro_w_h_3,erro_wh3)==1 || treinamento_ativo==3) && posicoes==0 && on_trade==false)
        {
         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*ask)%50==0)
           {
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra w h 3 "+string(qtdd_loss));
            Sleep(1000);
            printf("C. White Hole 3 "+string(ask-8*Min_Val_Neg));
            trade_type=White_Hole_3_Compra;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else  if((compara_matrizes(m_match_w_h_4,m_now,m_erro_w_h_4,erro_wh4)==1 || treinamento_ativo==4) && posicoes==0 && on_trade==false)
        {
         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*ask)%50==0)
           {
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra w h 4 "+string(qtdd_loss));
            Sleep(1000);
            printf("C. White Hole 4 "+string(ask-8*Min_Val_Neg));
            trade_type=White_Hole_4_Compra;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else  if((compara_matrizes(m_match_w_h_5,m_now,m_erro_w_h_5,erro_wh5)==1 || treinamento_ativo==5) && posicoes==0 && on_trade==false)
        {
         //comprar
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*ask)%50==0)
           {
            trade.Buy(lotes,_Symbol,ask,ask-8*Min_Val_Neg,ask+8*Min_Val_Neg,"Compra w h 4 "+string(qtdd_loss));
            Sleep(1000);
            printf("C. White Hole 5 "+string(ask-8*Min_Val_Neg));
            trade_type=White_Hole_5_Compra;
            on_trade=true;
            end=TimeCurrent();
           }
        }
      else if((compara_matrizes(m_match_b_h_1,m_now,m_erro_b_h_1,erro_bh1)==1 || treinamento_ativo==-1) && posicoes==0 && on_trade==false)
        {
         //vender
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*bid)%50==0)
           {
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda b h 1 "+string(qtdd_loss));
            printf("V. Black Hole 1 "+string(bid+8*Min_Val_Neg));
            on_trade=true;
            Sleep(1000);
            trade_type=Black_Hole_1_Venda;
            end=TimeCurrent();
           }
        }
      else if((compara_matrizes(m_match_b_h_2,m_now,m_erro_b_h_2,erro_bh2)==1 || treinamento_ativo==-2) && posicoes==0 && on_trade==false)
        {
         //vender
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*bid)%50==0)
           {
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda b h 2 "+string(qtdd_loss));
            printf("V. Black Hole 2 "+string(bid+8*Min_Val_Neg));
            on_trade=true;
            Sleep(1000);
            trade_type=Black_Hole_2_Venda;
            end=TimeCurrent();
           }
        }
      else if((compara_matrizes(m_match_b_h_3,m_now,m_erro_b_h_3,erro_bh3)==1 || treinamento_ativo==-3) && posicoes==0 && on_trade==false)
        {
         //vender
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*bid)%50==0)
           {
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda b h 3 "+string(qtdd_loss));
            printf("V. Black Hole 3 "+string(bid+8*Min_Val_Neg));
            on_trade=true;
            Sleep(1000);
            trade_type=Black_Hole_3_Venda;
            end=TimeCurrent();
           }
        }
      else if((compara_matrizes(m_match_b_h_4,m_now,m_erro_b_h_4,erro_bh4)==1 || treinamento_ativo==-4) && posicoes==0 && on_trade==false)
        {
         //vender
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*bid)%50==0)
           {
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda b h 4 "+string(qtdd_loss));
            printf("V. Black Hole 4 "+string(bid+8*Min_Val_Neg));
            on_trade=true;
            Sleep(1000);
            trade_type=Black_Hole_4_Venda;
            end=TimeCurrent();
           }
        }
      else if((compara_matrizes(m_match_b_h_5,m_now,m_erro_b_h_5,erro_bh5)==1 || treinamento_ativo==-5) && posicoes==0 && on_trade==false)
        {
         //vender
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(int(100*bid)%50==0)
           {
            trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda b h 5 "+string(qtdd_loss));
            printf("V. Black Hole 5 "+string(bid+8*Min_Val_Neg));
            on_trade=true;
            Sleep(1000);
            trade_type=Black_Hole_5_Venda;
            end=TimeCurrent();
           }
        }
      else
        {
         //Comment("M erro: \n"+string(m_erro_w_h_1[1][59])+" \n"+string(m_erro_w_h_2[1][59])+" \n"+string(m_erro_w_h_3[1][59])+" \n"+string(m_erro_w_h_4[1][59])+" \n"+string(m_erro_w_h_5[1][59])+" \n"+string(m_erro_b_h_1[1][59])+" \n"+string(m_erro_b_h_2[1][59])+" \n"+string(m_erro_b_h_3[1][59])+" \n"+string(m_erro_b_h_4[1][59])+" \n"+string(m_erro_b_h_5[1][59])+" \n"+string(erro_wh1)+" \n"+string(erro_wh2)+" \n"+string(erro_wh3)+" \n"+string(erro_bh1)+" \n"+string(erro_bh2)+" \n"+string(erro_bh1));
         trade_type=0;
         end=TimeCurrent();
        }

     }
   else
     {
      posicoes=PositionsTotal();
     }
  }
//+------------------------------------------------------------------+
