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
#define n_holes 20//metade inicial é hole de venda e a final hole de compra
string paths[n_holes][3];

//+------------------------------------------------------------------+
//| Expert initialization                                |
//+------------------------------------------------------------------+
double Min_Val_Neg=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
ENUM_TIMEFRAMES Periodo=_Period;
int lotes=1;
double super_brain[n_holes][4][30];//metade inicial do brain é venda, o resto é compra
double m_now[4][30];
double m_erro_brain[n_holes][4][30];
double m_e_temp_brain[n_holes][4][30];
double Vet_temp_erro[n_holes];
double distancias[n_holes];
double Vet_erro[n_holes];//metade inicial desse vetor são erros aceitaveis de venda (black_hole) outra metade (white_hole)
double counter_t_profit=0.5;
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
double distancia=0;
double temp_dist=100;
double dist_tp=20;
double dist_sl=20;
int simulacao_contabil=0;
int oper_counter=0;
double op_gain=0.75;
double Modulador=0.225;
//+------------------------------------------------------------------+
//| Salva matrizes n_holesx4x30 sempre que necessario                                                                 |
//+------------------------------------------------------------------+
void salvar_matriz_N_4_30(double  &matriz[][4][30],string path)
  {
   int filehandle;
   double vec[30];
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
         for(i=0;i<30;i++)
           {
            vec[i]=matriz[w][j][i];
            if(i<29)
               linha+=string(vec[i])+",";
            else linha+=string(vec[i])+"\n";
           }
         FileWrite(file_handle,linha);
         add=path+"_"+string(w)+"_"+string(j);
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
   int handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteArray(handle,erro,0,WHOLE_ARRAY);
   FileClose(handle);
  }
//+------------------------------------------------------------------+
//| le matrizes Nx4x30 do disco                                                                 |
//+------------------------------------------------------------------+
void ler_matriz_N_4_30(double  &matriz[][4][30],string path,int tipo_erro)
  {
   int filehandle;
   double vec[30];
   ArrayInitialize(vec,0);
   string add;
   int i=0;
   int j=0;
   double close[30];
   double open[30];
   double high[30];
   double low[30];
   for(int w=0;w<n_holes;w++)
     {
      for(j=0;j<4;j++)
        {
         add=path+"_"+string(w)+"_"+string(j);
         if(FileIsExist(add,FILE_COMMON))
           {
            filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
            FileReadArray(filehandle,vec,0,WHOLE_ARRAY);
            FileClose(filehandle);
            for(i=0;i<30;i++)matriz[w][j][i]=vec[i];
           }
         else
           {
            Alert("arquivo "+add+" nao encontrado");
            if(tipo_erro==true) for(i=0;i<30;i++) matriz[w][j][i]=(1+(i/30))*MathRand()*Min_Val_Neg/16383.5;
            else if(j==0)
              {
               if(CopyOpen(_Symbol,Periodo,0,30,open)!=-1)
                  for(i=0;i<30;i++)matriz[w][j][i]=open[i]+(2*Min_Val_Neg*(16383.5-MathRand())/16383.5);
              }
            else if(j==1)
              {
               if(CopyClose(_Symbol,Periodo,0,30,close)!=-1)
                  for(i=0;i<30;i++)matriz[w][j][i]=close[i]+(2*Min_Val_Neg*(16383.5-MathRand())/16383.5);
              }
            else if(j==2)
              {
               if(CopyHigh(_Symbol,Periodo,0,30,high)!=-1)
                  for(i=0;i<30;i++)matriz[w][j][i]=high[i]+(2*Min_Val_Neg*(16383.5-MathRand())/16383.5);
              }
            else if(j==3)
              {
               if(CopyLow(_Symbol,Periodo,0,30,low)!=-1)
                  for(i=0;i<30;i++)matriz[w][j][i]=low[i]+(2*Min_Val_Neg*(16383.5-MathRand())/16383.5);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Aproxima matrizes por um fator 20%    N dimensoes                                                             |
//+------------------------------------------------------------------+
void aproximar_matriz_N(double &Matriz_temp[][4][30],double &Matriz_erro[][4][30],int D)
  {
   int i=0;
   for(int j=0;j<4;j++)
      for(i=0;i<30;i++) Matriz_temp[D][j][i]=0.8*Matriz_temp[D][j][i]+0.2*Matriz_erro[D][j][i]+(16383.5-MathRand())*Min_Val_Neg/(1638350);//Oscilacao de 0.01*Min_Val_Neg
  }
//+------------------------------------------------------------------+
//|Copia M2 em M1       N dimensoes                                                           |
//+------------------------------------------------------------------+
void copiar_matriz_N(double &M1[][4][30],double &M2[][4][30],int D)
  {
   int i=0;
   for(int j=0;j<4;j++)
      for(i=0;i<30;i++) M1[D][j][i]=M2[D][j][i];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void ler_vetor_erro_aceitavel(string path)//se não existir já cria
  {
   double erro=0;
   uint ok=0;
   if(FileIsExist(path,FILE_COMMON))
     {
      int filehandle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
        {
         ok=FileReadArray(filehandle,Vet_erro,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }
      else ArrayInitialize(Vet_erro,-2*Min_Val_Neg);
     }
   else  ArrayInitialize(Vet_erro,-2*Min_Val_Neg);
  }
//+------------------------------------------------------------------+
//Funcao para normalizar os erros aceitaveis, evita que os torne muito grandes                    |
//+------------------------------------------------------------------+
void Normalizar_erros()
  {
   int i=0;
   double menor=1;
   i=ArrayMaximum(Vet_erro);//Menor negativo
   menor=MathAbs(Vet_erro[i]);
   if(menor>=2) //2 ainda é um valor baixo
     {
      for(i=0;i<ArraySize(Vet_erro);i++)
         Vet_erro[i]/=menor;
     }
  }
//+------------------------------------------------------------------+
//|funcao que compara parcialmente as matrizes match com as matrizes              |
//now(valores atuais) e decide se houve similaridade                 |  
//funcao mais requisitada do expert                                  |
//+------------------------------------------------------------------+
int compara_matrizes_N(double &match[][4][30],double &now[][30],double &m_erro[][4][30],double &err_aceitavel[],int tipo)
  {
   int i=29;
   int j=3;
//comecar pelos ultimos valores que correspondem aos candles mais atuais
   bool teste=true;
   double d_temp=0;
   distancias[tipo-1]=0;
   if(!MathIsValidNumber(err_aceitavel[tipo-1])) err_aceitavel[tipo-1]=-2*Min_Val_Neg;
   for(i=29;i>=0;i--)
     {
      for(j=3;j>=0;j--)
        {
         if(MathIsValidNumber(match[tipo-1][j][i]) && MathIsValidNumber(now[j][i]) && MathIsValidNumber(m_erro[tipo-1][j][i]))
           {
            //funcao de ativacao
            m_erro[tipo-1][j][i]=((16383.5-MathRand())*Min_Val_Neg/1638350000)+(m_erro[tipo-1][j][i]*MathMin(MathAbs(m_erro[tipo-1][j][i]),8*Min_Val_Neg)/(MathAbs(m_erro[tipo-1][j][i])));
            match[tipo-1][j][i]=((16383.5-MathRand())*Min_Val_Neg/1638350000)+(match[tipo-1][j][i]*MathMin(MathAbs(match[tipo-1][j][i]),15000*Min_Val_Neg)/(MathAbs(match[tipo-1][j][i])));
           }
         else
           {
            now[j][i]=10004*Min_Val_Neg;
            match[tipo-1][j][i]=10000*Min_Val_Neg;
            m_erro[tipo-1][j][i]=1;
            teste=false;
           }
         d_temp+=MathPow((now[j][i]-match[tipo-1][j][i])*m_erro[tipo-1][j][i],2);
        }
      distancias[tipo-1]+=MathSqrt(d_temp);
      d_temp=0;
     }
   distancias[tipo-1]-=MathMin((err_aceitavel[tipo-1]*Min_Val_Neg),0);
   if(teste==true) return 1;//caso perfeito - obsoleto
   else return 0;
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

//salvar os arrays de match (brain)
   salvar_matriz_N_4_30(super_brain,"cosmos_training"+"//"+"match");

//salvar as matrizes de erro
   salvar_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro");

//Salvar os erros aceitaveis
   salvar_vet_erro(Vet_erro,"cosmos_training"+"//"+"Ve");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime    tm=TimeCurrent();
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
         if(stops_N_dimensional(super_brain,m_erro_brain,m_e_temp_brain,Vet_erro,Vet_temp_erro,m_now)) qtdd_loss=1;
         //Atencao retirado o incremento para treinamento
         //else qtdd_loss-=1;
         //mudar depois para resolver o problema do reinicio do bot
         //rodar o historico inteiro do dia pode ser uma solução sacrificando processamento
        }
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
      double comparacoes[n_holes];
      for(int Type=1;Type<=n_holes;Type++)
         comparacoes[Type-1]=compara_matrizes_N(super_brain,m_now,m_erro_brain,Vet_erro,Type);

      if(false)//ativo apenas na fase de treinamento---entradas forcadas
        {//treinamento habilitado ->true
         //gera compras e vendas aleatorias para treinar matrizes match e erro
         //1 vez por semana
         if(stm.day_of_week==3 && (stm.hour==14) && stm.min==2 && stm.sec==1)
           {
            treinamento_ativo=6;
           }
         else if(stm.day_of_week==5 && (stm.hour==16) && stm.min==8 && stm.sec==1)
           {
            treinamento_ativo=-6;//6 e -6 valor herdado de versões anteriores mas 
                                 //poderia ser qqer valor desde que um seja >0 e o outro <0 
           }
         else treinamento_ativo=0;
        }

      if((distancias[ArrayMinimum(distancias,0,n_holes/2)]<1*distancia || treinamento_ativo==-6) && posicoes==0 && on_trade==false)
        {
         printf("distancia de entrada em venda: "+string(distancia)+" dist hole: "+string(distancias[ArrayMinimum(distancias,0,n_holes/2)]));
         bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(distancias[ArrayMinimum(distancias,0,n_holes/2)]<1.2*dist_tp)simulacao_contabil=1;//valido como entrada para atualizar parametros
         else simulacao_contabil=0;
         if(distancias[ArrayMinimum(distancias,0,n_holes/2)]<1*dist_tp && counter_t_profit>=op_gain && treinamento_ativo!=-6 && (TimeCurrent()-end)>=300000)//aguarda ao menos 5min antes da proxima operação real
           {
            //vender
            if(int(100*bid)%50==0)
              {
               trade_type=1+ArrayMinimum(distancias,0,n_holes/2);
               trade.Sell(lotes,_Symbol,bid,bid+8*Min_Val_Neg,bid-8*Min_Val_Neg,"Venda dist "+string(trade_type)+" "+string(distancia));
               if(treinamento_ativo==0) printf("------------V. distancia "+string(bid+8*Min_Val_Neg)+" "+string(trade_type));
               on_trade_simulado=false;
               on_trade=true;
               Sleep(1000);
               end=TimeCurrent();
              }
           }
         else//entrada virtual
           {
            Stop_tp_Simulado=last;
            if(on_trade_simulado==false)
              {//primeira passagem pela entrada virtual
               Buy_Sell_Simulado=bid;
               trade_type=1+ArrayMinimum(distancias,0,n_holes/2);
               on_trade_simulado=true;
              }
            if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
              {//loss ou gain virtual
               on_trade=true;
               treinamento_ativo=-6;//entra novamente na operacao como treinamento forcado de venda
               on_trade_simulado=false;
              }
           }
        }
      else if(( distancias[ArrayMinimum(distancias,n_holes/2,n_holes/2)]<1*distancia || treinamento_ativo==6) && posicoes==0 && on_trade==false)
        {
         //comprar
         printf("distancia de entrada em compra: "+string(distancia)+" dist hole: "+string(distancias[ArrayMinimum(distancias,n_holes/2,n_holes/2)]));
         ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if(distancias[ArrayMinimum(distancias,n_holes/2,n_holes/2)]<1.2*dist_tp)simulacao_contabil=1;
         else simulacao_contabil=0;
         if(distancias[ArrayMinimum(distancias,n_holes/2,n_holes/2)]<1*dist_tp && counter_t_profit>op_gain && treinamento_ativo!=6 && (TimeCurrent()-end)>=300000)
           {
            if(int(100*ask)%50==0)//aguarda ao menos 5min antes da proxima operação real
              {
               trade_type=1+ArrayMinimum(distancias,n_holes/2,n_holes/2);
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
               trade_type=1+ArrayMinimum(distancias,n_holes/2,n_holes/2);
               on_trade_simulado=true;
              }
            if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
              {
               on_trade=true;
               treinamento_ativo=6;
               on_trade_simulado=false;
              }
            //on_trade=true;
           }
        }
      else
        {
         trade_type=0;
         distancia+=0.25*Min_Val_Neg;
         ArrayFill(comparacoes,0,n_holes,0);
        }
     }
   else
     {
      if(posicoes!=0)
        {
         counter_t_profit=0.25;
         distancia-=0.001*Min_Val_Neg;
        }
      posicoes=PositionsTotal();
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| funcao para atualizar valores ao fim de cada operacao     
//| retorna true caso seja um loss                                                            |
//+------------------------------------------------------------------+
bool stops_N_dimensional(double &match[][4][30],double &m_erro[][4][30],double &m_temp_erro[][4][30],double &erro[],double &temp_erro[],double &mnow[][30])
  {
   bool stop=false;
   double last_trade;
   double l_last_trade;
   int hole=trade_type;
   if(treinamento_ativo==0)
     {
      HistorySelect(start,TimeCurrent());
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
   if((compra && l_last_trade>=last_trade) || (venda && l_last_trade<=last_trade))
     {//--================----loss 
      oper_counter-=1;
      maximum=MathAbs((mnow[0][29]-match[hole-1][0][29])*m_erro[hole-1][0][29]);
      //caso de loss procurar o indice do maior erro e aproximar
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (10% da matriz)
      for(j=0;j<12;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<30;w++)
               if(MathAbs((mnow[i][w]-match[hole-1][i][w])*m_erro[hole-1][i][w])>maximum)
                 {
                  maximum=MathAbs((mnow[i][w]-match[hole-1][i][w])*m_erro[hole-1][i][w]);
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
         if(mnow[ind_max[0]][ind_max[1]]-match[hole-1][ind_max[0]][ind_max[1]]<0)
            match[hole-1][ind_max[0]][ind_max[1]]=match[hole-1][ind_max[0]][ind_max[1]]-Modulador*0.3*MathPow((mnow[ind_max[0]][ind_max[1]]-match[hole-1][ind_max[0]][ind_max[1]]),2)-2*Min_Val_Neg;//38
         else
            match[hole-1][ind_max[0]][ind_max[1]]=match[hole-1][ind_max[0]][ind_max[1]]+Modulador*0.3*MathPow((mnow[ind_max[0]][ind_max[1]]-match[hole-1][ind_max[0]][ind_max[1]]),2)+2*Min_Val_Neg;
         match[hole-1][ind_min[0]][ind_min[1]]*=MathMin(MathAbs(match[hole-1][ind_min[0]][ind_min[1]]),15000*Min_Val_Neg)/MathAbs(match[hole-1][ind_min[0]][ind_min[1]]);
         m_temp_erro[hole-1][ind_min[0]][ind_min[1]]+=(0.005-(MathRand()/1638350))*Min_Val_Neg;// oscilação de 0.01*0.5 pontos
        }
      //caso de loss procurar o indice do menor erro e afastar
      //significa que aquele valor nao era importante
      //fazer essa alteração 30 x (25% dos candles)
      minimum=MathAbs((mnow[0][29]-match[hole-1][0][29])*m_erro[hole-1][0][29]);
      for(j=0;j<30;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<30;w++)
               if(MathAbs((mnow[i][w]-match[hole-1][i][w])*m_erro[hole-1][i][w])<minimum)
                 {
                  minimum=MathAbs((mnow[i][w]-match[hole-1][i][w])*m_erro[hole-1][i][w]);//m_erro_w_h_1[i][w];
                  ind_min[0]=i;
                  ind_min[1]=w;
                 }
         //os minimos precisam ser afastados o suficiente para aumentar a distancia mais do que os maximos diminuiram
         if(mnow[ind_min[0]][ind_min[1]]-match[hole-1][ind_min[0]][ind_min[1]]<0)
            match[hole-1][ind_min[0]][ind_min[1]]=match[hole-1][ind_min[0]][ind_min[1]]+Modulador*0.3*MathPow((mnow[ind_min[0]][ind_min[1]]-match[hole-1][ind_min[0]][ind_min[1]]),2)+3*Min_Val_Neg;//36
         else match[hole-1][ind_min[0]][ind_min[1]]=match[hole-1][ind_min[0]][ind_min[1]]-Modulador*0.3*MathPow((mnow[ind_min[0]][ind_min[1]]-match[hole-1][ind_min[0]][ind_min[1]]),2)-3*Min_Val_Neg;
         match[hole-1][ind_min[0]][ind_min[1]]*=MathMin(MathAbs(match[hole-1][ind_min[0]][ind_min[1]]),15000*Min_Val_Neg)/MathAbs(match[hole-1][ind_min[0]][ind_min[1]]);
        }
      erro[hole-1]=temp_erro[hole-1]-(distancia/2);//diminuir esse valor para dificultar um nova entrada (para treinamento)
      if(simulacao_contabil==1)counter_t_profit=0.9*counter_t_profit;
      copiar_matriz_N(m_erro,m_temp_erro,trade_type-1);
      Modulador+=(16383.5-MathRand())*Min_Val_Neg/(16383500);
      distancia=temp_dist*0.0025;
      //ArrayPrint(distancias);
      if(MathAbs(treinamento_ativo)==6)
        {
         treinamento_ativo=0;
         Sleep(10000);
        }
      dist_sl+=(distancias[trade_type-1]-dist_sl)/21;
      printf("stop loss caso: "+string(trade_type)+" dist t_prof.: "+string(dist_tp)+" Err acc.: "+string(erro[hole-1])+" tk p "+string(counter_t_profit)+" op_gain: "+string(op_gain));
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
      minimum=MathAbs((match[hole-1][0][29]-mnow[0][29])*m_erro[hole-1][0][29]);
      //caso de gain procurar o indice de menor  erro e reduzir a distancia
      //alterar m_erro para manter a mesma distancia (aumentar a significancia)
      //significa que aquele valor era importante
      //fazer essa alteração 6 x (5% dos candles)
      for(j=0;j<6;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<30;w++)
               if(MathAbs((mnow[i][w]-match[hole-1][i][w])*m_erro[hole-1][i][w])<minimum)
                 {
                  minimum=MathAbs((mnow[i][w]-match[hole-1][i][w])*m_erro[hole-1][i][w]);
                  ind_min[0]=i;
                  ind_min[1]=w;
                 }
         if((mnow[ind_min[0]][ind_min[1]]-match[hole-1][ind_min[0]][ind_min[1]])>0)
           {
            //decremento de 10% da diferenca + um valor constante
            match[hole-1][ind_min[0]][ind_min[1]]*=MathMin(MathAbs(match[hole-1][ind_min[0]][ind_min[1]]),15000*Min_Val_Neg)/MathAbs(match[hole-1][ind_min[0]][ind_min[1]]);
            m_erro[hole-1][ind_min[0]][ind_min[1]]*=mnow[ind_min[0]][ind_min[1]]-match[hole-1][ind_min[0]][ind_min[1]];
            match[hole-1][ind_min[0]][ind_min[1]]=match[hole-1][ind_min[0]][ind_min[1]]+Modulador*0.1*MathPow((mnow[ind_min[0]][ind_min[1]]-match[hole-1][ind_min[0]][ind_min[1]]),2)+(MathRand()/16383.5)*Min_Val_Neg*0.2;//44//48 -300
            m_erro[hole-1][ind_min[0]][ind_min[1]]/=mnow[ind_min[0]][ind_min[1]]-match[hole-1][ind_min[0]][ind_min[1]];
           }
         else
           {
            match[hole-1][ind_min[0]][ind_min[1]]*=MathMin(MathAbs(match[hole-1][ind_min[0]][ind_min[1]]),15000*Min_Val_Neg)/MathAbs(match[hole-1][ind_min[0]][ind_min[1]]);
            m_erro[hole-1][ind_min[0]][ind_min[1]]*=mnow[ind_min[0]][ind_min[1]]-match[hole-1][ind_min[0]][ind_min[1]];
            match[hole-1][ind_min[0]][ind_min[1]]=match[hole-1][ind_min[0]][ind_min[1]]-Modulador*0.1*MathPow((mnow[ind_min[0]][ind_min[1]]-match[hole-1][ind_min[0]][ind_min[1]]),2)-(MathRand()/16383.5)*Min_Val_Neg*0.2;
            m_erro[hole-1][ind_min[0]][ind_min[1]]/=mnow[ind_min[0]][ind_min[1]]-match[hole-1][ind_min[0]][ind_min[1]];
           }
        }
      //caso de gain procurar o indice de maior  erro e aumentar a distancia
      //reduzir o erro de gatilho proporcionalmente diminuindo a significancia
      //significa que aquele valor realmente não era importante
      //fazer essa alteração 6 x (5% dos candles)
      maximum=MathAbs((mnow[0][29]-match[hole-1][0][29])*m_erro[hole-1][0][29]);
      for(j=0;j<6;j++)
        {
         for(i=0; i<4;i++)
            for(w=0; w<30;w++)
               if(MathAbs((mnow[i][w]-match[hole-1][i][w])*m_erro[hole-1][i][w])>maximum)
                 {
                  maximum=MathAbs((mnow[i][w]-match[hole-1][i][w])*m_erro[hole-1][i][w]);
                  ind_max[0]=i;
                  ind_max[1]=w;
                 }
         if(mnow[ind_max[0]][ind_max[1]]-match[hole-1][ind_max[0]][ind_max[1]]>0)
           {
            match[hole-1][ind_max[0]][ind_max[1]]*=MathMin(MathAbs(match[hole-1][ind_max[0]][ind_max[1]]),15000*Min_Val_Neg)/MathAbs(match[hole-1][ind_max[0]][ind_max[1]]);
            m_erro[hole-1][ind_max[0]][ind_max[1]]*=(mnow[ind_max[0]][ind_max[1]]-match[hole-1][ind_max[0]][ind_max[1]]);
            match[hole-1][ind_max[0]][ind_max[1]]=match[hole-1][ind_max[0]][ind_max[1]]-Modulador*0.2*MathPow((mnow[ind_max[0]][ind_max[1]]-match[hole-1][ind_max[0]][ind_max[1]]),2)-0.01*(MathRand()/1638.35)*Min_Val_Neg;//36 - +232.3//30 -100
            m_erro[hole-1][ind_max[0]][ind_max[1]]/=mnow[ind_max[0]][ind_max[1]]-match[hole-1][ind_max[0]][ind_max[1]];
           }
         else
           {
            match[hole-1][ind_max[0]][ind_max[1]]*=MathMin(MathAbs(match[hole-1][ind_max[0]][ind_max[1]]),15000*Min_Val_Neg)/MathAbs(match[hole-1][ind_max[0]][ind_max[1]]);
            m_erro[hole-1][ind_max[0]][ind_max[1]]*=(mnow[ind_max[0]][ind_max[1]]-match[hole-1][ind_max[0]][ind_max[1]]);
            match[hole-1][ind_max[0]][ind_max[1]]=match[hole-1][ind_max[0]][ind_max[1]]+Modulador*0.2*MathPow((mnow[ind_max[0]][ind_max[1]]-match[hole-1][ind_max[0]][ind_max[1]]),2)+0.01*(MathRand()/1638.35)*Min_Val_Neg;
            m_erro[hole-1][ind_max[0]][ind_max[1]]/=mnow[ind_max[0]][ind_max[1]]-match[hole-1][ind_max[0]][ind_max[1]];
            if(MathAbs(m_erro[hole-1][ind_max[0]][ind_max[1]])<0.01*Min_Val_Neg)
               m_erro[hole-1][ind_max[0]][ind_max[1]]*=0.0005*Min_Val_Neg/MathAbs(m_erro[hole-1][ind_max[0]][ind_max[1]]);//Para não zerar m_erro
           }
        }
      if(MathAbs(treinamento_ativo)==6)
        {
         temp_erro[hole-1]=(0.4*erro[hole-1]+0.6*temp_erro[hole-1]);//Absorver valor que deu certo
         erro[hole-1]=temp_erro[hole-1]-(2*(16383.5-MathRand())*Min_Val_Neg/(16383.5));//Oscilar em 2* o min val neg
         Normalizar_erros();//normalizar erros
         treinamento_ativo=0;
         Sleep(10000);
        }
      if(simulacao_contabil==1)
        {
         counter_t_profit=(0.9*counter_t_profit)+0.1;
        }
      printf("t. prof. caso: "+string(trade_type)+" dist t_prof.: "+string(dist_tp)+" Err acc.: "+string(erro[hole-1])+" tk p "+string(counter_t_profit)+" op_gain: "+string(op_gain));
      op_gain=MathMax(op_gain+(counter_t_profit-op_gain)/200,0.600001);
      aproximar_matriz_N(m_temp_erro,m_erro,trade_type-1);
      temp_dist+=(distancias[trade_type-1]-temp_dist)/17;
      distancia=0.02*temp_dist;
      copiar_matriz_N(m_erro,m_temp_erro,trade_type-1);
      //ArrayPrint(distancias);
      dist_tp+=(distancias[trade_type-1]-dist_tp)/21;
      stop=false;
     }
   if(trade_type!=0)
     {
      salvar_matriz_N_4_30(match,"cosmos_training"+"//"+"match");
      salvar_matriz_N_4_30(m_erro,"cosmos_training"+"//"+"erro");
      salvar_vet_erro(Vet_erro,"cosmos_training"+"//"+"Ve");
     }
   if(stop==true)trade_type=0;
//Comments geram um atraso razoavel na simulação, usado pra debugar
//Comment("M erro: \n"+string(m_erro_w_h_1[ind_min[0]][29])+" \n"+string(m_erro_w_h_2[ind_min[0]][29])+" \n"+string(m_erro_w_h_3[ind_min[0]][29])+" \n"+string(m_erro_w_h_4[ind_min[0]][29])+" \n"+string(m_erro_w_h_5[ind_min[0]][29])+" \n"+string(m_erro_b_h_1[ind_min[0]][29])+" \n"+string(m_erro_b_h_2[ind_min[0]][29])+" \n"+string(m_erro_b_h_3[ind_min[0]][29])+" \n"+string(m_erro_b_h_4[ind_min[0]][29])+" \n"+string(m_erro_b_h_5[ind_min[0]][29])+" \n");//+string(erro_wh1)+" \n"+string(erro_wh2)+" \n"+string(erro_wh3)+" \n"+string(erro_bh1)+" \n"+string(erro_bh2)+" \n"+string(erro_bh1));
   return stop;
  }
//+------------------------------------------------------------------+
