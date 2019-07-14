﻿//+------------------------------------------------------------------+
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

const int White_Hole_1_Compra=  1;
const int White_Hole_2_Compra=  2;
const int White_Hole_3_Compra= 3;
const int Black_Hole_1_Venda =  -1;
const int Black_Hole_2_Venda=   -2;
const int Black_Hole_3_Venda=  -3;

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
double m_match_b_h_1[4][60];//condicao 1 de venda
double m_match_b_h_2[4][60];
double m_match_b_h_3[4][60];
double m_now[4][60];
double m_erro_w_h_1[4][60];
double m_erro_w_h_2[4][60];
double m_erro_w_h_3[4][60];
double m_erro_b_h_1[4][60];
double m_erro_b_h_2[4][60];
double m_erro_b_h_3[4][60];
double m_temp_erro_w_h_1[4][60];
double m_temp_erro_w_h_2[4][60];
double m_temp_erro_w_h_3[4][60];
double m_temp_erro_b_h_1[4][60];
double m_temp_erro_b_h_2[4][60];
double m_temp_erro_b_h_3[4][60];
datetime end=TimeCurrent();        //horario atual em datetime nao convertido  
datetime start=TimeCurrent();
int trade_type=0;
int qtdd_loss=0;
bool on_trade=false;
double last,ask,bid;
//+------------------------------------------------------------------+
//| Classe para salvar os candles absorvidos do historico do Metatrader                                                                 |
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
//| funcao para preencher candle, facilita a utilizacao do looping                                                                 |
//+------------------------------------------------------------------+
void criar_candle_simples(candle &ca[],int ind,double o,double c,double h,double l)
  {
   ca[ind].close=c;
   ca[ind].open=o;
   ca[ind].max=h;
   ca[ind].min=l;
  }
//+------------------------------------------------------------------+
//| Funcao obsoleta                                                                 |
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
//|  Funcao obsoleta                                                                |
//+------------------------------------------------------------------+  
void recalcular_matriz_erro_fail(double &m_match[][60],double &now[][60],double &m_erro[][60])
  {
   int i=0;
   int j=0;
   for(i=0;i<4;i++)
     {
      for(j=0;j<60;j++)
        {
         //m_erro[i][j]=(3*m_erro[i][j]+MathAbs(m_match[i][j]-now[i][j]))/4;
         m_erro[i][j]-=m_erro[i][j]*(Min_Val_Neg*0.01*(MathRand()%20))/(0.001+MathAbs(m_erro[i][j]));
         m_erro[i][j]=MathAbs(m_erro[i][j]);
        }
     }
  }
//+------------------------------------------------------------------+
//|calculo das matrizes match , usada na primeira execução do programa
//|antes que uma matriz exista no disco
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
//| Matrizes nao são salvas no disco no MQL5, só arrays unidimensionais                                                                 |
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
//| Carregar matriz do disco                                                                 |
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
//| Criar matriz de valores randomicos                                                                 |
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
//|Usada para aproximar a matriz erro da matriz erro que funcionou                                                                 |
//+------------------------------------------------------------------+
void aproximar_matriz(double &Matriz_temp[][60],double &Matriz_erro[][60])
  {
   int i=0;
   for(int j=0;j<4;j++)
     {
      for(i=0;i<60;i++)
        {
         Matriz_temp[j][i]=0.75*Matriz_temp[j][i]+0.25*Matriz_erro[j][i];
        }
     }
   printf("Matriz aproximada com sucesso");
  }
//+------------------------------------------------------------------+
//| Copiar M2 em M1                                                                 |
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
   printf("Copia_concluida");
  }
//+------------------------------------------------------------------+
//| Ler matriz erro do disco                                                                 |
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
//|busca dos holes (obsoleta)                                                                  |
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
//|Obsoleta                                                                  |
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
//|Ler erro aceitavel do disco                                                                  |
//+------------------------------------------------------------------+
double ler_erro_aceitavel(string path)
  {
   if(FileIsExist(path,FILE_COMMON))
     {
      int filehandle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
         return MathAbs(FileReadDouble(filehandle));
      else return Min_Val_Neg*20;
     }
   else return Min_Val_Neg*2;
  }
//+------------------------------------------------------------------+
//|Verificação de stops aceitaveis                                                                  |
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
//+-----------------------------------------------------------------------------------------------+
//| Funcao que define se havera uma compra ou venda de acordo com a proximidade das matrizes match                                                                 |
//+-----------------------------------------------------------------------------------------------+
int compara_matrizes(double &match[][60],double &now[][60],double &m_erro[][60],double &err_aceitavel)
  {
   int i=0;
   int j=0;
   bool teste=true;
   for(j=0;j<4;j++)
     {
      for(i=0;i<60;i++)
        {
         if(MathIsValidNumber(m_match_w_h_1[j][i]) && MathIsValidNumber(m_now[j][i]) && MathIsValidNumber(m_erro_w_h_1[j][i]))
           {
            if(MathAbs(m_match_w_h_1[j][i]-m_now[j][i])>=m_erro_w_h_1[j][i]+erro_wh1*Min_Val_Neg)//+0*MathAbs(m_erro[j][i])+MathAbs(erro_aceitavel)
              {
               teste=false;
               m_erro_w_h_1[j][i]=MathAbs(m_erro_w_h_1[j][i]+0.000002*0.01*(MathRand()%100)*Min_Val_Neg*(MathRand()%200));
               //err_aceitavel+=0.00005*Min_Val_Neg;
              }
            else m_erro_w_h_1[j][i]=MathAbs(0.01*m_erro_w_h_1[j][i]*Min_Val_Neg*(90+(MathRand()%11)));
           }
         else
           {
            m_match_w_h_1[j][i]=10000*Min_Val_Neg;
            m_now[j][i]=10008*Min_Val_Neg;
            m_erro_w_h_1[j][i]=2*Min_Val_Neg;
            teste=false;
           }
        }
     }
   if(teste==true)
     {
      Comment("M Now: "+string(erro_wh1)+" \n"+string(match[1][59])+" \n"+string(match[2][59])+" \n"+string(match[3][59]));
      erro_wh1=MathAbs(erro_wh1-10*Min_Val_Neg);
      return 1;
     }
   else erro_wh1=MathAbs(erro_wh1+0.001*Min_Val_Neg);

   teste=true;
   for(j=0;j<4;j++)
     {
      for(i=0;i<60;i++)
        {
         if(MathIsValidNumber(m_match_w_h_2[j][i]) && MathIsValidNumber(m_now[j][i]) && MathIsValidNumber(m_erro_w_h_2[j][i]))
           {
            if(MathAbs(m_match_w_h_2[j][i]-m_now[j][i])>=m_erro_w_h_2[j][i]+erro_wh2*Min_Val_Neg)//+0*MathAbs(m_erro[j][i])+MathAbs(erro_aceitavel)
              {
               teste=false;
               m_erro_w_h_2[j][i]=MathAbs(m_erro_w_h_2[j][i]+0.000002*0.01*(MathRand()%100)*Min_Val_Neg*(MathRand()%200));
               //err_aceitavel+=0.00005*Min_Val_Neg;
              }
            else m_erro_w_h_2[j][i]=MathAbs(0.01*m_erro_w_h_2[j][i]*Min_Val_Neg*(90+(MathRand()%11)));
           }
         else
           {
            m_match_w_h_2[j][i]=10000*Min_Val_Neg;
            m_now[j][i]=10008*Min_Val_Neg;
            m_erro_w_h_2[j][i]=2*Min_Val_Neg;
            teste=false;
           }
        }
     }
   if(teste==true)
     {
      Comment("M Now: "+string(erro_wh2)+" \n"+string(match[1][59])+" \n"+string(match[2][59])+" \n"+string(match[3][59]));
      erro_wh2=MathAbs(erro_wh2-10*Min_Val_Neg);
      return 2;
     }
   else erro_wh2=MathAbs(erro_wh2+0.001*Min_Val_Neg);

   teste=true;
   for(j=0;j<4;j++)
     {
      for(i=0;i<60;i++)
        {
         if(MathIsValidNumber(m_match_b_h_1[j][i]) && MathIsValidNumber(m_now[j][i]) && MathIsValidNumber(m_erro_b_h_1[j][i]))
           {
            if(MathAbs(m_match_b_h_1[j][i]-m_now[j][i])>=m_erro_b_h_1[j][i]+erro_bh1*Min_Val_Neg)//+0*MathAbs(m_erro[j][i])+MathAbs(erro_aceitavel)
              {
               teste=false;
               m_erro_b_h_1[j][i]=MathAbs(m_erro_b_h_1[j][i]+0.000002*0.01*(MathRand()%100)*Min_Val_Neg*(MathRand()%200));
               //err_aceitavel+=0.00005*Min_Val_Neg;
              }
            else m_erro_b_h_1[j][i]=MathAbs(0.01*m_erro_b_h_1[j][i]*Min_Val_Neg*(90+(MathRand()%11)));
           }
         else
           {
            m_match_b_h_1[j][i]=10000*Min_Val_Neg;
            m_now[j][i]=10008*Min_Val_Neg;
            m_erro_b_h_1[j][i]=2*Min_Val_Neg;
            teste=false;
           }
        }
     }
   if(teste==true)
     {
      erro_bh1=MathAbs(erro_bh1-10*Min_Val_Neg);
      Comment("M Now: "+string(erro_bh1)+" \n"+string(match[1][59])+" \n"+string(match[2][59])+" \n"+string(match[3][59]));
      return -1;
     }
   else erro_bh1=MathAbs(erro_bh1+0.001*Min_Val_Neg);

   teste=true;
   for(j=0;j<4;j++)
     {
      for(i=0;i<60;i++)
        {
         if(MathIsValidNumber(m_match_b_h_2[j][i]) && MathIsValidNumber(m_now[j][i]) && MathIsValidNumber(m_erro_b_h_2[j][i]))
           {
            if(MathAbs(m_match_b_h_2[j][i]-m_now[j][i])>=m_erro_b_h_2[j][i]+erro_bh2*Min_Val_Neg)//+0*MathAbs(m_erro[j][i])+MathAbs(erro_aceitavel)
              {
               teste=false;
               m_erro_b_h_2[j][i]=MathAbs(m_erro_b_h_2[j][i]+0.000002*0.01*(MathRand()%100)*Min_Val_Neg*(MathRand()%200));
               //err_aceitavel+=0.00005*Min_Val_Neg;
              }
            else m_erro_b_h_2[j][i]=MathAbs(0.01*m_erro_b_h_2[j][i]*Min_Val_Neg*(90+(MathRand()%11)));
           }
         else
           {
            m_match_b_h_2[j][i]=10000*Min_Val_Neg;
            m_now[j][i]=10008*Min_Val_Neg;
            m_erro_b_h_2[j][i]=2*Min_Val_Neg;
            teste=false;
           }
        }
     }
   if(teste==true)
     {
      erro_bh2=MathAbs(erro_bh2-10*Min_Val_Neg);
      Comment("M Now: "+string(erro_bh2)+" \n"+string(match[1][59])+" \n"+string(match[2][59])+" \n"+string(match[3][59]));
      return -2;
     }
   else erro_bh2=MathAbs(erro_bh2+0.001*Min_Val_Neg);


   teste=true;
   for(j=0;j<4;j++)
     {
      for(i=0;i<60;i++)
        {
         if(MathIsValidNumber(match[j][i]) && MathIsValidNumber(now[j][i]) && MathIsValidNumber(m_erro[j][i]))
           {
            if(MathAbs(match[j][i]-now[j][i])>=m_erro[j][i]+err_aceitavel*Min_Val_Neg)//+0*MathAbs(m_erro[j][i])+MathAbs(erro_aceitavel)
              {
               teste=false;
               m_erro[j][i]=MathAbs(m_erro[j][i]+0.000002*0.01*(MathRand()%100)*Min_Val_Neg*(MathRand()%200));
               //err_aceitavel+=0.00005*Min_Val_Neg;
              }
            else m_erro[j][i]=MathAbs(0.01*m_erro[j][i]*Min_Val_Neg*(90+(MathRand()%11)));
           }
         else
           {
            match[j][i]=10000*Min_Val_Neg;
            now[j][i]=10008*Min_Val_Neg;
            m_erro[j][i]=2*Min_Val_Neg;
            teste=false;
           }
        }
     }
   if(teste==true)
     {
      err_aceitavel=MathAbs(err_aceitavel-10*Min_Val_Neg);
      Comment("M erro: "+string(m_erro[0][59])+" \n"+string(m_erro[1][59])+" \n"+string(m_erro[2][59])+" \n"+string(m_erro[3][59])+" \n"+string(err_aceitavel));
      return 3;
     }
   else erro_bh2=MathAbs(erro_bh2+0.001*Min_Val_Neg);
   return 0;
  }
//+---------------------------------------------------------------------------------+
//| Funcao para definir se foi stop ou gain e atualizar as match e erros_aceitaveis                                                                  |
//+---------------------------------------------------------------------------------+
bool situacao_stops_dia()
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
//trade_type variavel global que é atualizada de acordo com a ultima operacao 1->compra -1->venda

   int ind_max[2]={0,0};
   int ind_min[2]={0,0};

   if(trade_type==White_Hole_1_Compra && l_last_trade>=last_trade)//loss de compra
     {
      maximum=MathAbs(m_match_w_h_1[0][0]-m_now[0][0]);
      //caso de loss procurar o indice do maior erro e aproximar,reduzir a tolerancia
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<8;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_w_h_1[i][w]-m_now[i][w])>maximum)
                 {
                  maximum=MathAbs(m_match_w_h_1[i][w]-m_now[i][w]);
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
              }
           }
         //se match-now>0 match-(match-now)*% else match-(match-now)% -->(match - now gera o sinal necessário
         m_match_w_h_1[ind_max[0]][ind_max[1]]=MathAbs(m_match_w_h_1[ind_max[0]][ind_max[1]]);
         if(m_match_w_h_1[ind_max[0]][ind_max[1]]>m_now[ind_max[0]][ind_max[1]])
           {
            m_match_w_h_1[ind_max[0]][ind_max[1]]=m_match_w_h_1[ind_max[0]][ind_max[1]]-1*Min_Val_Neg;
           }
         else m_match_w_h_1[ind_max[0]][ind_max[1]]=m_match_w_h_1[ind_max[0]][ind_max[1]]+1*Min_Val_Neg;
         m_match_w_h_1[ind_max[0]][ind_max[1]]=MathAbs(m_match_w_h_1[ind_max[0]][ind_max[1]]);
         m_erro_w_h_1[ind_max[0]][ind_max[1]]*=(1+0.01*(MathRand()%21));
        }

      minimum=MathAbs(m_match_w_h_1[0][0]-m_now[0][0]);
      //caso de loss procurar o indice do menor erro e afastar,aumentar a tolerancia e reduzir o erro de gatilho
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<8;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_w_h_1[i][w]-m_now[i][w])<minimum)
                 {
                  minimum=MathAbs(m_match_w_h_1[i][w]-m_now[i][w]);//m_erro_w_h_1[i][w];
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
              }
           }
         //se match-now>0 match-(match-now)*% else match-(match-now)% -->(match - now gera o sinal necessário
         //os minimos precisam ser afastados o suficiente para não entrar novamente
         m_match_w_h_1[ind_max[0]][ind_max[1]]=MathAbs(m_match_w_h_1[ind_max[0]][ind_max[1]]);
         if(m_match_w_h_1[ind_max[0]][ind_max[1]]>m_now[ind_max[0]][ind_max[1]])
           {
            m_match_w_h_1[ind_max[0]][ind_max[1]]=m_match_w_h_1[ind_max[0]][ind_max[1]]+(temp_erro_wh1+1.2*m_erro_w_h_1[ind_max[0]][ind_max[1]]+2*Min_Val_Neg);
           }
         else m_match_w_h_1[ind_max[0]][ind_max[1]]=m_match_w_h_1[ind_max[0]][ind_max[1]]-(temp_erro_wh1+1.2*m_erro_w_h_1[ind_max[0]][ind_max[1]]+2*Min_Val_Neg);
         m_match_w_h_1[ind_max[0]][ind_max[1]]=MathAbs(m_match_w_h_1[ind_max[0]][ind_max[1]]);
         m_erro_w_h_1[ind_max[0]][ind_max[1]]*=(0.7+0.01*(MathRand()%36));
        }
      erro_wh1=temp_erro_bh1;
      copiar_matriz(m_erro_w_h_1,m_temp_erro_w_h_1);
      //erro_wh1=MathAbs(erro_wh1);
      //erro_wh1+=0.2*Min_Val_Neg;
      //recalcular_matriz_erro_fail(m_match_w_h_1,m_now,m_erro_w_h_1);

      trade_type=0;
      printf("stop loss W H 1");
      stop=true;//0x0
     }
   else if(trade_type==Black_Hole_1_Venda && l_last_trade<=last_trade)
     {
      maximum=MathAbs(m_match_b_h_1[0][0]-m_now[0][0]);
      //caso de loss procurar o indice do maior erro e aproximar,reduzir a tolerancia
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)

      for(j=0;j<8;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_b_h_1[i][w]-m_now[i][w])>maximum)
                 {
                  maximum=MathAbs(m_match_b_h_1[i][w]-m_now[i][w]);//m_erro_b_h_1[i][w];
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
              }
           }
         //se match-now>0 match-(match-now)*% else match-(match-now)% -->(match - now gera o sinal necessário
         m_match_b_h_1[ind_max[0]][ind_max[1]]=MathAbs(m_match_b_h_1[ind_max[0]][ind_max[1]]);
         if(m_match_b_h_1[ind_max[0]][ind_max[1]]>m_now[ind_max[0]][ind_max[1]])
           {
            m_match_b_h_1[ind_max[0]][ind_max[1]]=m_match_b_h_1[ind_max[0]][ind_max[1]]-1*Min_Val_Neg;
           }
         else m_match_b_h_1[ind_max[0]][ind_max[1]]=m_match_b_h_1[ind_max[0]][ind_max[1]]+1*Min_Val_Neg;
         m_match_b_h_1[ind_max[0]][ind_max[1]]=MathAbs(m_match_b_h_1[ind_max[0]][ind_max[1]]);
         m_erro_b_h_1[ind_max[0]][ind_max[1]]*=(1+0.01*(MathRand()%21));
        }
      //agora afasta o minimo
      minimum=MathAbs(m_match_b_h_1[0][0]-m_now[0][0]);
      //caso de loss procurar o indice do menor erro e afastar,reduzir o erro de gatilho proporcionalmente
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<8;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_b_h_1[i][w]-m_now[i][w])<minimum)
                 {
                  minimum=MathAbs(m_match_b_h_1[i][w]-m_now[i][w]);
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
              }
           }
         //se match-now>0 match-(match-now)*% else match-(match-now)% -->(match - now gera o sinal necessário
         m_match_b_h_1[ind_max[0]][ind_max[1]]=MathAbs(m_match_b_h_1[ind_max[0]][ind_max[1]]);
         if(m_match_b_h_1[ind_max[0]][ind_max[1]]>m_now[ind_max[0]][ind_max[1]])
           {
            m_match_b_h_1[ind_max[0]][ind_max[1]]=m_match_b_h_1[ind_max[0]][ind_max[1]]+(temp_erro_bh1+1.2*m_erro_b_h_1[ind_max[0]][ind_max[1]]+2*Min_Val_Neg);
           }
         else m_match_b_h_1[ind_max[0]][ind_max[1]]=m_match_b_h_1[ind_max[0]][ind_max[1]]-(temp_erro_bh1+1.2*m_erro_b_h_1[ind_max[0]][ind_max[1]]+2*Min_Val_Neg);
         m_match_b_h_1[ind_max[0]][ind_max[1]]=MathAbs(m_match_b_h_1[ind_max[0]][ind_max[1]]);
         m_erro_b_h_1[ind_max[0]][ind_max[1]]*=(0.7+0.01*(MathRand()%36));
        }
      erro_bh1=temp_erro_bh1;
      copiar_matriz(m_erro_b_h_1,m_temp_erro_b_h_1);
      //erro_bh1=(0.5*erro_bh1-erro_bh1*(0.01*(MathRand()%25)*Min_Val_Neg))/MathAbs(erro_bh1);

      //recalcular_matriz_erro_fail(m_match_b_h_1,m_now,m_erro_b_h_1);
      trade_type=0;
      printf("stop loss B H 1");
      stop=true;//0x0
     }

   else if(trade_type==White_Hole_2_Compra && l_last_trade>=last_trade)//loss de compra
     {
      maximum=MathAbs(m_match_w_h_2[0][0]-m_now[0][0]);
      //caso de loss procurar o indice do maior erro e aproximar,reduzir o erro de gatilho proporcionalmente
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<8;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_w_h_2[i][w]-m_now[i][w])>maximum)
                 {
                  maximum=MathAbs(m_match_w_h_2[i][w]-m_now[i][w]);
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
              }
           }
         //se match-now>0 match-(match-now)*% else match-(match-now)% -->(match - now gera o sinal necessário
         m_match_w_h_2[ind_max[0]][ind_max[1]]=MathAbs(m_match_w_h_2[ind_max[0]][ind_max[1]]);
         if(m_match_w_h_2[ind_max[0]][ind_max[1]]>m_now[ind_max[0]][ind_max[1]])
           {
            m_match_w_h_2[ind_max[0]][ind_max[1]]=m_match_w_h_2[ind_max[0]][ind_max[1]]-0.5;
           }
         else m_match_w_h_2[ind_max[0]][ind_max[1]]=m_match_w_h_2[ind_max[0]][ind_max[1]]+0.5;
         m_match_w_h_2[ind_max[0]][ind_max[1]]=MathAbs(m_match_w_h_2[ind_max[0]][ind_max[1]]);
         m_erro_w_h_2[ind_max[0]][ind_max[1]]*=(1+0.01*(MathRand()%21));
        }

      minimum=MathAbs(m_match_w_h_2[0][0]-m_now[0][0]);
      //caso de loss procurar o indice do menor erro e afastar,reduzir o erro de gatilho proporcionalmente
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<8;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_w_h_2[i][w]-m_now[i][w])<minimum)
                 {
                  minimum=MathAbs(m_match_w_h_2[i][w]-m_now[i][w]);//m_erro_w_h_1[i][w];
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
              }
           }
         //se match-now>0 match-(match-now)*% else match-(match-now)% -->(match - now gera o sinal necessário
         //os minimos precisam ser afastados
         m_match_w_h_2[ind_max[0]][ind_max[1]]=MathAbs(m_match_w_h_2[ind_max[0]][ind_max[1]]);
         if(m_match_w_h_2[ind_max[0]][ind_max[1]]>m_now[ind_max[0]][ind_max[1]])
           {
            m_match_w_h_2[ind_max[0]][ind_max[1]]=m_match_w_h_2[ind_max[0]][ind_max[1]]+temp_erro_wh2+1.2*m_erro_w_h_2[ind_max[0]][ind_max[1]]+2*Min_Val_Neg;
           }
         else m_match_w_h_2[ind_max[0]][ind_max[1]]=m_match_w_h_2[ind_max[0]][ind_max[1]]-(temp_erro_wh2+1.2*m_erro_w_h_2[ind_max[0]][ind_max[1]]+2*Min_Val_Neg);
         m_match_w_h_2[ind_max[0]][ind_max[1]]=MathAbs(m_match_w_h_2[ind_max[0]][ind_max[1]]);
         m_erro_w_h_2[ind_max[0]][ind_max[1]]*=(0.7+0.01*(MathRand()%36));
        }
      erro_wh2=temp_erro_wh2;
      copiar_matriz(m_erro_w_h_2,m_temp_erro_w_h_2);
      //erro_wh1=MathAbs(erro_wh1);
      //erro_wh1+=0.2*Min_Val_Neg;
      //recalcular_matriz_erro_fail(m_match_w_h_1,m_now,m_erro_w_h_1);
      trade_type=0;
      printf("stop loss W H 2");
      stop=true;//0x0
     }
   else if(trade_type==Black_Hole_2_Venda && l_last_trade<=last_trade)
     {
      maximum=MathAbs(m_match_b_h_1[0][0]-m_now[0][0]);
      //caso de loss procurar o indice do maior erro e aproximar,reduzir o erro de gatilho proporcionalmente
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)

      for(j=0;j<8;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_b_h_2[i][w]-m_now[i][w])>maximum)
                 {
                  maximum=MathAbs(m_match_b_h_2[i][w]-m_now[i][w]);//m_erro_b_h_1[i][w];
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
              }
           }
         //se match-now>0 match-(match-now)*% else match-(match-now)% -->(match - now gera o sinal necessário
         m_match_b_h_2[ind_max[0]][ind_max[1]]=MathAbs(m_match_b_h_2[ind_max[0]][ind_max[1]]);
         if(m_match_b_h_2[ind_max[0]][ind_max[1]]>m_now[ind_max[0]][ind_max[1]])
           {
            m_match_b_h_2[ind_max[0]][ind_max[1]]=m_match_b_h_2[ind_max[0]][ind_max[1]]-1*Min_Val_Neg;
           }
         else m_match_b_h_2[ind_max[0]][ind_max[1]]=m_match_b_h_2[ind_max[0]][ind_max[1]]+1*Min_Val_Neg;
         m_match_b_h_2[ind_max[0]][ind_max[1]]=MathAbs(m_match_b_h_2[ind_max[0]][ind_max[1]]);
         m_erro_b_h_2[ind_max[0]][ind_max[1]]*=(1+0.01*(MathRand()%21));
        }
      //agora afasta o minimo
      minimum=MathAbs(m_match_b_h_2[0][0]-m_now[0][0]);
      //caso de loss procurar o indice do menor erro e afastar,reduzir o erro de gatilho proporcionalmente
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<8;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_b_h_2[i][w]-m_now[i][w])<minimum)
                 {
                  minimum=MathAbs(m_match_b_h_2[i][w]-m_now[i][w]);
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
              }
           }
         //se match-now>0 match-(match-now)*% else match-(match-now)% -->(match - now gera o sinal necessário
         m_match_b_h_2[ind_max[0]][ind_max[1]]=MathAbs(m_match_b_h_2[ind_max[0]][ind_max[1]]);
         if(m_match_b_h_2[ind_max[0]][ind_max[1]]>m_now[ind_max[0]][ind_max[1]])
           {
            m_match_b_h_2[ind_max[0]][ind_max[1]]=m_match_b_h_2[ind_max[0]][ind_max[1]]+(temp_erro_bh2+1.2*m_erro_b_h_2[ind_max[0]][ind_max[1]]+2*Min_Val_Neg);
           }
         else m_match_b_h_2[ind_max[0]][ind_max[1]]=m_match_b_h_2[ind_max[0]][ind_max[1]]-(temp_erro_bh2+1.2*m_erro_b_h_2[ind_max[0]][ind_max[1]]+2*Min_Val_Neg);
         m_match_b_h_2[ind_max[0]][ind_max[1]]=MathAbs(m_match_b_h_2[ind_max[0]][ind_max[1]]);
         m_erro_b_h_2[ind_max[0]][ind_max[1]]*=(0.7+0.01*(MathRand()%36));
        }
      erro_bh2=temp_erro_bh2;
      copiar_matriz(m_erro_b_h_2,m_temp_erro_b_h_2);
      //erro_bh1=(0.5*erro_bh1-erro_bh1*(0.01*(MathRand()%25)*Min_Val_Neg))/MathAbs(erro_bh1);

      //recalcular_matriz_erro_fail(m_match_b_h_1,m_now,m_erro_b_h_1);
      trade_type=0;
      printf("stop loss B H 2");
      stop=true;//0x0
     }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//foi gain 

   else if(trade_type==White_Hole_1_Compra && l_last_trade<last_trade)
     {
      minimum=MathAbs(m_match_w_h_1[0][0]-m_now[0][0]);
      //caso de gain procurar o indice de menor  erro e aproximar,reduzir o erro de gatilho proporcionalmente
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)
      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_w_h_1[i][w]-m_now[i][w])<minimum)
                 {
                  minimum=MathAbs(m_match_w_h_1[i][w]-m_now[i][w]);
                  ind_min[0]=i;
                  ind_min[1]=w;
                 }
              }
           }
         m_match_w_h_1[ind_min[0]][ind_min[1]]=MathAbs(m_match_w_h_1[ind_min[0]][ind_min[1]]);
         if(m_match_w_h_1[ind_min[0]][ind_min[1]]>m_now[ind_min[0]][ind_min[1]])
           {
            m_match_w_h_1[ind_min[0]][ind_min[1]]=m_match_w_h_1[ind_min[0]][ind_min[1]]-0.5*Min_Val_Neg;
           }
         else m_match_w_h_1[ind_min[0]][ind_min[1]]=m_match_w_h_1[ind_min[0]][ind_min[1]]+0.5*Min_Val_Neg;
         m_match_w_h_1[ind_min[0]][ind_min[1]]=MathAbs(m_match_w_h_1[ind_min[0]][ind_min[1]]);
         m_erro_w_h_1[ind_min[0]][ind_min[1]]*=(0.85+0.01*(MathRand()%16));
        }
      temp_erro_wh1=(erro_wh1+9*temp_erro_wh1)/10;
      erro_wh1*=1+(0.05-0.01*(MathRand()%20));
      aproximar_matriz(m_temp_erro_w_h_1,m_erro_w_h_1);
      //erro_wh1=MathAbs(erro_wh1);
      //erro_wh1+=0.1*Min_Val_Neg;

      //recalcular_matriz_erro(m_match_w_h_1,m_now,m_erro_w_h_1);
      trade_type=0;
      printf("t prof W_H_1");
      stop=false;
     }
   else if(trade_type==White_Hole_2_Compra && l_last_trade<last_trade)
     {
      minimum=MathAbs(m_match_w_h_2[0][0]-m_now[0][0]);
      //caso de gain procurar o indice de menor  erro e aproximar,reduzir o erro de gatilho proporcionalmente
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (5% dos candles)

      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_w_h_2[i][w]-m_now[i][w])<minimum)
                 {
                  minimum=MathAbs(m_match_w_h_2[i][w]-m_now[i][w]);
                  ind_min[0]=i;
                  ind_min[1]=w;
                 }
              }
           }
         m_match_w_h_2[ind_min[0]][ind_min[1]]=MathAbs(m_match_w_h_2[ind_min[0]][ind_min[1]]);
         if(m_match_w_h_2[ind_min[0]][ind_min[1]]>m_now[ind_min[0]][ind_min[1]])
           {
            m_match_w_h_2[ind_min[0]][ind_min[1]]=m_match_w_h_2[ind_min[0]][ind_min[1]]-0.5*Min_Val_Neg;
           }
         else m_match_w_h_2[ind_min[0]][ind_min[1]]=m_match_w_h_2[ind_min[0]][ind_min[1]]+0.5*Min_Val_Neg;
         m_match_w_h_2[ind_min[0]][ind_min[1]]=MathAbs(m_match_w_h_2[ind_min[0]][ind_min[1]]);
         m_erro_w_h_2[ind_min[0]][ind_min[1]]*=(0.85+0.01*(MathRand()%16));
        }
      temp_erro_wh2=(erro_wh2+9*temp_erro_wh2)/10;
      erro_wh2*=1+(0.05-0.01*(MathRand()%20));
      aproximar_matriz(m_temp_erro_w_h_2,m_erro_w_h_2);
      //erro_wh1=MathAbs(erro_wh1);
      //erro_wh1+=0.1*Min_Val_Neg;

      //recalcular_matriz_erro(m_match_w_h_1,m_now,m_erro_w_h_1);
      trade_type=0;
      stop=false;
      printf("t prof W_H_2");
     }

   else if(trade_type==Black_Hole_1_Venda && l_last_trade>last_trade)
     {
      minimum=MathAbs(m_match_b_h_1[0][0]-m_now[0][0]);

      //caso de gain procurar o indice do menor erro e nao alterar o erro de gatilho
      //significa que aquele valor era o mais importante
      //fazer essa alteração 12 x (5% dos candles)

      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_b_h_1[i][w]-m_now[i][w])<minimum)
                 {
                  minimum=MathAbs(m_match_b_h_1[i][w]-m_now[i][w]);
                  ind_min[0]=i;
                  ind_min[1]=w;
                 }
              }
           }
         //se match-now>0 match-(match-now)*% else match-(match-now)% -->(match - now gera o sinal necessário
         m_match_b_h_1[ind_min[0]][ind_min[1]]=MathAbs(m_match_b_h_1[ind_min[0]][ind_min[1]]);
         if(m_match_b_h_1[ind_min[0]][ind_min[1]]>m_now[ind_min[0]][ind_min[1]])
           {
            m_match_b_h_1[ind_min[0]][ind_min[1]]=m_match_b_h_1[ind_min[0]][ind_min[1]]-0.5*Min_Val_Neg;
           }
         else m_match_b_h_1[ind_min[0]][ind_min[1]]=m_match_b_h_1[ind_min[0]][ind_min[1]]+0.5*Min_Val_Neg;
         m_match_b_h_1[ind_min[0]][ind_min[1]]=MathAbs(m_match_b_h_1[ind_min[0]][ind_min[1]]);
         m_erro_b_h_1[ind_min[0]][ind_min[1]]*=(0.85+0.01*(MathRand()%16));
        }
      temp_erro_bh1=(erro_bh1+9*temp_erro_bh1)/10;
      erro_bh1*=1+(0.05-0.01*(MathRand()%20));
      aproximar_matriz(m_temp_erro_b_h_1,m_erro_b_h_1);
      //erro_bh1=MathAbs(erro_bh1);
      //erro_bh1+=0.1*Min_Val_Neg;

      //recalcular_matriz_erro(m_match_b_h_1,m_now,m_erro_b_h_1);
      trade_type=0;
      stop=false;
      printf("t prof B_H_1");
     }

   else if(trade_type==Black_Hole_2_Venda && l_last_trade>last_trade)
     {
      minimum=MathAbs(m_match_b_h_2[0][0]-m_now[0][0]);

      //caso de gain procurar o indice do menor erro e nao alterar o erro de gatilho
      //significa que aquele valor era o mais importante
      //fazer essa alteração 12 x (5% dos candles)

      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
           {
            for(w=0; w<60;w++)
              {
               if(MathAbs(m_match_b_h_2[i][w]-m_now[i][w])<minimum)
                 {
                  minimum=MathAbs(m_match_b_h_2[i][w]-m_now[i][w]);
                  ind_min[0]=i;
                  ind_min[1]=w;
                 }
              }
           }
         //se match-now>0 match-(match-now)*% else match-(match-now)% -->(match - now gera o sinal necessário
         m_match_b_h_2[ind_min[0]][ind_min[1]]=MathAbs(m_match_b_h_2[ind_min[0]][ind_min[1]]);
         if(m_match_b_h_2[ind_min[0]][ind_min[1]]>m_now[ind_min[0]][ind_min[1]])
           {
            m_match_b_h_2[ind_min[0]][ind_min[1]]=m_match_b_h_2[ind_min[0]][ind_min[1]]-0.5*Min_Val_Neg;
           }
         else m_match_b_h_2[ind_min[0]][ind_min[1]]=m_match_b_h_2[ind_min[0]][ind_min[1]]+0.5*Min_Val_Neg;
         m_match_b_h_2[ind_min[0]][ind_min[1]]=MathAbs(m_match_b_h_2[ind_min[0]][ind_min[1]]);
         m_erro_b_h_2[ind_min[0]][ind_min[1]]*=(0.85+0.01*(MathRand()%16));
        }
      temp_erro_bh2=(erro_bh2+9*temp_erro_bh2)/10;
      erro_bh2*=1+(0.05-0.01*(MathRand()%20));
      aproximar_matriz(m_temp_erro_b_h_2,m_erro_b_h_2);

      //erro_bh1=MathAbs(erro_bh1);
      //erro_bh1+=0.1*Min_Val_Neg;

      //recalcular_matriz_erro(m_match_b_h_1,m_now,m_erro_b_h_1);
      trade_type=0;
      printf("t prof B_H_2");
      stop=false;
     }
   salvar_matriz_4_60(m_match_b_h_1,path_match1);
   salvar_matriz_4_60(m_match_b_h_2,path_match2);
   salvar_matriz_4_60(m_match_b_h_3,path_match3);
   salvar_matriz_4_60(m_match_w_h_1,path_match4);
   salvar_matriz_4_60(m_match_w_h_2,path_match5);
   salvar_matriz_4_60(m_match_w_h_3,path_match6);

   salvar_matriz_4_60(m_erro_b_h_1,path_erro1);
   salvar_matriz_4_60(m_erro_b_h_2,path_erro2);
   salvar_matriz_4_60(m_erro_b_h_3,path_erro3);
   salvar_matriz_4_60(m_erro_w_h_1,path_erro4);
   salvar_matriz_4_60(m_erro_w_h_2,path_erro5);
   salvar_matriz_4_60(m_erro_w_h_3,path_erro6);

   trade_type=0;
   printf("Analise Stop Concluida");
   return stop;//0x0
               //procurar o indice do menor erro e aproximar da matriz Now (media poderada) e suas mediacoes media mais poderada ainda
//aumentar o gatilho uma pequena porcentagem proporcional a quanto abaixo do valor aceitavel ele estava

  }
//+------------------------------------------------------------------+
//|Inicialização do expert                                          |
//+------------------------------------------------------------------+


candle b_h_1 = new candle(4000,3994,3996,3998);
candle b_h_2 = new candle(4002,3996,3998,4000);
candle b_h_3 = new candle(4000,3994,3998,3996);
candle w_h_1 = new candle(3998,3992,3996,3994);
candle w_h_2 = new candle(4002,3996,3999,3998);
candle w_h_3 = new candle(4000,3994,3997,3995);


//+------------------------------------------------------------------+
//save adress das matrizes de trabalho                                                                 |
//+------------------------------------------------------------------+
string path_match1="cosmos_training"+"//"+"match1";
string path_match2="cosmos_training"+"//"+"match2";
string path_match3="cosmos_training"+"//"+"match3";
string path_match4="cosmos_training"+"//"+"match4";
string path_match5="cosmos_training"+"//"+"match5";
string path_match6="cosmos_training"+"//"+"match6";

string path_erro1="cosmos_training"+"//"+"erro1";
string path_erro2="cosmos_training"+"//"+"erro2";
string path_erro3="cosmos_training"+"//"+"erro3";
string path_erro4="cosmos_training"+"//"+"erro4";
string path_erro5="cosmos_training"+"//"+"erro5";
string path_erro6="cosmos_training"+"//"+"erro6";

string path_black_hole1="cosmos_training"+"//"+"bh1";
string path_black_hole2="cosmos_training"+"//"+"bh2";
string path_black_hole3="cosmos_training"+"//"+"bh3";
string path_white_hole1="cosmos_training"+"//"+"wh1";
string path_white_hole2="cosmos_training"+"//"+"wh2";
string path_white_hole3="cosmos_training"+"//"+"wh3";

string path_black_erro1="cosmos_training"+"//"+"be1";
string path_black_erro2="cosmos_training"+"//"+"be2";
string path_black_erro3="cosmos_training"+"//"+"be3";
string path_white_erro1="cosmos_training"+"//"+"we1";
string path_white_erro2="cosmos_training"+"//"+"we2";
string path_white_erro3="cosmos_training"+"//"+"we3";
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double    erro_bh1=1;
double    erro_bh2=1;
double    erro_bh3=1;
double    erro_wh1=1;
double    erro_wh2=1;
double    erro_wh3=1;
double    temp_erro_bh1=1;
double    temp_erro_bh2=1;
double    temp_erro_bh3=1;
double    temp_erro_wh1=1;
double    temp_erro_wh2=1;
double    temp_erro_wh3=1;
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
   ler_matriz_4_60(m_match_b_h_1,path_match1);
   ler_matriz_4_60(m_match_b_h_2,path_match2);
   ler_matriz_4_60(m_match_b_h_3,path_match3);
   ler_matriz_4_60(m_match_w_h_1,path_match4);
   ler_matriz_4_60(m_match_w_h_2,path_match5);
   ler_matriz_4_60(m_match_w_h_3,path_match6);

//inicializar matriz diferencas/erro
   ler_m_erro_4_60(m_erro_b_h_1,path_erro1);
   ler_m_erro_4_60(m_erro_b_h_2,path_erro2);
   ler_m_erro_4_60(m_erro_b_h_3,path_erro3);
   ler_m_erro_4_60(m_erro_w_h_1,path_erro4);
   ler_m_erro_4_60(m_erro_w_h_2,path_erro5);
   ler_m_erro_4_60(m_erro_w_h_3,path_erro6);

   copiar_matriz(m_temp_erro_b_h_1,m_erro_b_h_1);
   copiar_matriz(m_temp_erro_b_h_2,m_erro_b_h_1);
   copiar_matriz(m_temp_erro_b_h_3,m_erro_b_h_1);
   copiar_matriz(m_temp_erro_w_h_1,m_erro_b_h_1);
   copiar_matriz(m_temp_erro_w_h_2,m_erro_b_h_1);
   copiar_matriz(m_temp_erro_w_h_3,m_erro_b_h_1);
//+------------------------------------------------------------------+
//| Inicializar os candles de trabalho e os erros aceitaveis                                                                 |
//+------------------------------------------------------------------+

//ler candles alvo
   ler_candle(b_h_1,path_black_hole1);
   ler_candle(b_h_2,path_black_hole2);
   ler_candle(b_h_3,path_black_hole3);
   ler_candle(w_h_1,path_white_hole1);
   ler_candle(w_h_2,path_white_hole2);
   ler_candle(w_h_3,path_white_hole3);
//ler erros aceitaveis
   erro_bh1=ler_erro_aceitavel(path_black_erro1);
   erro_bh2=ler_erro_aceitavel(path_black_erro2);
   erro_bh3=ler_erro_aceitavel(path_black_erro3);
   erro_wh1=ler_erro_aceitavel(path_white_erro1);
   erro_wh2=ler_erro_aceitavel(path_white_erro2);
   erro_wh3=ler_erro_aceitavel(path_white_erro3);
   temp_erro_bh1=erro_bh1;
   temp_erro_bh2=erro_bh2;
   temp_erro_bh3=erro_bh3;
   temp_erro_wh1=erro_wh1;
   temp_erro_wh2=erro_wh2;
   temp_erro_wh3=erro_wh3;

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

   salvar_matriz_4_60(m_match_b_h_1,path_match1);
   salvar_matriz_4_60(m_match_b_h_2,path_match2);
   salvar_matriz_4_60(m_match_b_h_3,path_match3);
   salvar_matriz_4_60(m_match_w_h_1,path_match4);
   salvar_matriz_4_60(m_match_w_h_2,path_match5);
   salvar_matriz_4_60(m_match_w_h_3,path_match6);

   salvar_matriz_4_60(m_erro_b_h_1,path_erro1);
   salvar_matriz_4_60(m_erro_b_h_2,path_erro2);
   salvar_matriz_4_60(m_erro_b_h_3,path_erro3);
   salvar_matriz_4_60(m_erro_w_h_1,path_erro4);
   salvar_matriz_4_60(m_erro_w_h_2,path_erro5);
   salvar_matriz_4_60(m_erro_w_h_3,path_erro6);

   int handle=FileOpen(path_black_erro1,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_bh1);
   FileClose(handle);
   handle=FileOpen(path_black_erro2,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_bh2);
   FileClose(handle);
   handle=FileOpen(path_black_erro3,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_bh3);
   FileClose(handle);
   handle=FileOpen(path_white_erro1,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_wh1);
   FileClose(handle);
   handle=FileOpen(path_white_erro2,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_wh2);
   FileClose(handle);
   handle=FileOpen(path_white_erro3,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteDouble(handle,erro_wh3);
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<10) || (stm.hour==10 && stm.min<=40))
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
         if(situacao_stops_dia()==true)
           {
            printf("Stop");
            qtdd_loss=1;///ATENCAO desativado o incremento ´para treinamento
           }
         //else qtdd_loss-=1;
         //mudar depois para resolver o problema do reinicio do bot
         //rodar o historico inteiro do dia pode ser uma solução sacrificando processamento

         Sleep(300000);//minimo de 300 segundos entre duas ordens- evita grandes pernadas
        }
     }

   int i=0;


//+------------------------------------------------------------------+
//| Inicio das comparações e condicoes de entrada em operacao                                                                 |
//+------------------------------------------------------------------+
   if(posicoes==0 && fim_do_pregao==false && qtdd_loss<=10 && on_trade==false)
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
      if(compara_matrizes(m_match_w_h_1,m_now,m_erro_w_h_1,erro_wh1)==1 && posicoes==0 && on_trade==false)
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
      else  if(compara_matrizes(m_match_w_h_2,m_now,m_erro_w_h_2,erro_wh2)==2 && posicoes==0 && on_trade==false)
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

      else if(compara_matrizes(m_match_b_h_1,m_now,m_erro_b_h_1,erro_bh1)==-1 && posicoes==0 && on_trade==false)
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
      else if(compara_matrizes(m_match_b_h_2,m_now,m_erro_b_h_2,erro_bh2)==-2 && posicoes==0 && on_trade==false)
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
      else
        {
         trade_type=0;
         end=TimeCurrent();
        }
     }
   else posicoes=PositionsTotal();
  }
//+------------------------------------------------------------------+
