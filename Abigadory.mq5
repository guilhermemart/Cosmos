//+------------------------------------------------------------------+
//|                                                   Abigadory.mq5  |
//|                                               Senhor_dos_Pasteis |
//|                                                                  |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>

#define n_holes 20//metade inicial é neuronio (hole) de venda e a final hole de compra, declarar aqui apenas valores par
#define n_candles 10// candles a serem analisados em sequencia
#define prof_cube 10// quais elementos serão analisados por neuronio // ver 
#define Loss_Direto 0 //loss na operacao principal
#define Loss_Reverso 3 //loss na operacao secundaria (vizinhanca)
#define Gain_Direto 1 //gain na operacao principal
#define Gain_Reverso 2 //gain na operacao secundaria (vizinhanca)
//---
//---Variaveis globais
//---
ENUM_TIMEFRAMES Periodo=_Period;
COrderInfo info;
CTrade trade;
input int Clear=0;
input int lotes=1;
input int processos=1;
double m1 = 0.5;
double m2= 0.5;
double m3=0.56;
double m4=0.56;
double restore_m1=0.5;
double restore_m2=0.5;
double restore_m3=0.56;
double restore_m4=0.56;
double temp_m2=0.5;
double temp_m3=0.56;
double temp_m4=0.56;
int to_debug[n_holes];
input double prox_fact_loss=100;
input double afast_fact_loss_real=300;
input double afast_fact_loss_n_real=200;
input double prox_fact_loss_viz=100;
input double afast_fact_loss_viz=100;
input double prox_fact_gain=150;
input double afast_fact_gain=100;
input int loss_suportavel_dia=1;//qtdd de loss suportavel em um dia
string simbolo="WDO$";
double Min_Val_Neg=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
double super_brain[n_holes][prof_cube][n_candles];//metade inicial do brain é venda, o resto é compra//match's
double m_now[prof_cube][n_candles];//entradas atuais
double m_erro_brain[n_holes][prof_cube][n_candles];//valor de ajuste de importancia
double m_e_temp_brain[n_holes][prof_cube][n_candles];//usado para regenerar m_erro_brain em caso de loss
double Vet_erro[n_holes];//metade inicial desse vetor são erros aceitaveis de venda (black_hole) outra metade (white_hole)
double Vet_temp_erro[n_holes];//usado para regenerar Vet_erro em caso de loss
double distancias[n_holes];//distancias medidas a partir da matriz now[][]
double distancia=0.01;//variavel que aumenta para forçar uma entrada virtual
double temp_dist=0.2;//variavel que salva a distancia que deu certo
double dist_tp=190;//distancia em que as distancias medidas são aceitas como certeiras
double dist_sl=250;//distancias em que as distancias medidas são consideradas falhas
double counter_t_profit=0.4;//media da contagem dos acertos
double op_gain=1;//medias da contagem dos acertos que permite entrada
double last_op_gain=0;//salva o op_gain anterior para substituir o op_gain novo que deu stop
int treinamento_ativo=NULL;//variavel para avisar a funcao stop que foi uma entrada virtual
double Buy_Sell_Simulado=0;//ask ou bid para simulação de stop ou gain
bool fim_do_pregao=true;//variavel setada como true até o inicio do horario do pregão
datetime    tm=TimeCurrent();//variavel para detectar inicio e fim de pregão
MqlDateTime stm;//variavel para receber tm como struct
datetime start=TimeCurrent();//inicio do history dos valores negociados
int trade_type=1;//qual hole foi usado na entrada
int trade_type_reverso=n_candles/2;//qual hole reverso
int qtdd_loss=0;//quantidade de operações dia
bool on_trade=false;//entrou em operação
bool on_trade_simulado=false;//entrou em operação simulada, funciona como o posicoes, mas para simulações
double Stop_tp_Simulado=0;//Assume o valor last para detectart stop ou gain em simulações
double last,ask,bid;//variaveis para entrar em trades
int simulacao_contabil=0;//simulaçao foi valida para atualizar parametros ou não
int oper_counter=0;//numero de gains ao final da simulação
int op_media=0;//variavel para receber definição de padroes de entrada
int op_media_virtual=0;
double forcar_entrada=100;//para não entrar em operações muito rapidamente
double parametrizadores[12];//parametros que são atualizados durante o treinamensto
double save_ma=17;//define a media que vai ser usada para trabalhar op_media
double recover_tend=1;//recupera tendencia que será usada para autorizar entradas caso a ultima modificação de ruim
double Modulador=0.05;//salva o parametrizadores[0] em caso de gain para recuperar em caso de loss
double close[n_candles];//fechamentos
double open[n_candles];//aberturas
double high[n_candles];//maior
double low[n_candles];//menor
double large_close[5*n_candles];
double large_open[5*n_candles];
int analisados[prof_cube][n_candles];//matriz para não repetir a atualização de candles já aprox/afastados
double tendencia=0;//salva a tendencia atual para uso durante as operações
int posicoes=0;//posicionado ou não
bool fechou_posicao=false;//já ouve a ordem de fechar posicoes e ainda não foi executada
double stopar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);//valor para stopar de emergencia
double gainar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);//valor para take_profit de emergencia
int m_handle_close=NULL;//handle para invocar a media de fechamento personalizada
int handle_touch=NULL;
int handle_quick=NULL;
int m_handle_tendency=NULL;
int ifr_ind_handle=NULL;
double m_volumetricas[5];//vetor com os 5 ultimos medias volumetricas
double m_close[n_candles];//media
double m_quick[n_candles];//media rapida
int alfa_c=0;
int alfa_v=0;
int tentativa=0;
double temp_tend=0;
int m_handle_periodo;
int ultimo_hole_ativo=n_holes;//serve para nao operar o mesmo hole duas vezes em sequencia

//+------------------------------------------------------------------+
//| Aproxima matrizes por um fator 10%    N dimensoes                |
//+------------------------------------------------------------------+
void aproximar_matriz_N(double &Matriz_temp[][prof_cube][n_candles],double &Matriz_erro[][prof_cube][n_candles],int D);
//+------------------------------------------------------------------+
//|Copia M2 em M1       N dimensoes                                                           |
//+------------------------------------------------------------------+
void copiar_matriz_N(double &M1[][prof_cube][n_candles],double &M2[][prof_cube][n_candles],int D);

//+----------------------------------------------------------------------------+
//Funcao para normalizar os erros aceitaveis, evita que os torne muito grandes                    |
//+----------------------------------------------------------------------------+
void Normalizar_erros();
//+------------------------------------------------------------------+
//|//usada quando a matriz de erro explode
//+------------------------------------------------------------------+
void Embaralhar_matriz(double &matriz[][prof_cube][n_candles],int d);
//+------------------------------------------------------------------+
//| //usado quando a matriz match explode                                                                 |
//+------------------------------------------------------------------+
void Recriar_matriz(double &M[][prof_cube][n_candles],double &M0[][n_candles],int d);
//+------------------------------------------------------------------+
//| Funcao para oscilar uma matriz em 3% do seu valor atual
//Usada em caso de loss para tentar encontrar um valor melhor
//para os parametros   de normalização da matriz now    |
//+------------------------------------------------------------------+
void Oscilar_matriz(double &m_osc[],double &m_pre[]);
//+------------------------------------------------------------------+
//| Usada em caso de gain para salvar matriz parametros normalizadores
//| que deu certo                                                    |
//+------------------------------------------------------------------+
//void estabiliza_matriz();
//+------------------------------------------------------------------+
//|funcao que compara parcialmente as matrizes match com as matrizes |
//now(valores atuais) e decide se houve similaridade                 |
//funcao mais requisitada do expert                                  |
//+------------------------------------------------------------------+
int compara_matrizes_N(double &match[][prof_cube][n_candles],double &now[][n_candles],double &m_erro[][prof_cube][n_candles],double &err_aceitavel[],int tipo);
//+------------------------------------------------------------------+
//|Funcao que define se tocou ou não na media                                                                  |
//+------------------------------------------------------------------+
int Operar_na_Media(double &m_media[]);
//+------------------------------------------------------------------+
//|Operar em engolfo ou perfuração                                                                  |
//+------------------------------------------------------------------+
int operar_perfuracao();
//+------------------------------------------------------------------+
//|  Linearização poderada de 5 medias para calcula da tendencia                                                                |
//+------------------------------------------------------------------+
double tendency();//linearizacao da tendencia; evita operar em congestão
//+------------------------------------------------------------------+
//| Aproxima candles dependendo de loss ou gain                                                                 |
//+------------------------------------------------------------------+
void aproximar_candles(int num_candles,double fator_de_aproximacao,int loss_gain);
//+------------------------------------------------------------------+
//| Afasta candles dependendo de loss ou gain                                                                 |
//+------------------------------------------------------------------+
void afastar_candles(int num_candles,double fator_de_afastamento,int loss_gain);//caso loss afastar os candles mais proximos
//+------------------------------------------------------------------+
//| funcao para atualizar valores ao fim de cada operacao
//| retorna true caso seja um loss                                   |
//+------------------------------------------------------------------+
bool stops_N_dimensional(double &match[][prof_cube][n_candles],double &m_erro[][prof_cube][n_candles],double &m_temp_erro[][prof_cube][n_candles],double &erro[],double &temp_erro[],double &mnow[][n_candles]);
//---
//---funcao para normailzar os erros (hole a hole) da matriz erro dividindo pela media de cada hole
//---
void normalizar_m_erros();
//---
//---funcao para calcular a proxima resistencia
//---
double next_resist();
//---
//---funcao para calcular a proxima suporte
//---
double next_suporte();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   printf("Expert iniciado");
//Inicializacao das strings address dos valores de treinamento
   ArrayFill(Vet_erro,0,n_holes,-2000*Min_Val_Neg);
   ArrayFill(Vet_temp_erro,0,n_holes,-1);
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   Min_Val_Neg=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   stopar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
   gainar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
   ArrayFill(to_debug,0,n_holes,0);
//---Inicializar Menor valor negociavel
   simbolo="WDO$";
   if(Ativo=="WIN")
     {
      Min_Val_Neg=Min_Val_Neg*7;
      simbolo="WIN$";
     }
   if(Clear==1 && (_Symbol=="WDO$" || _Symbol=="WIN$"))
      Min_Val_Neg*=500;
//--- Inicializar o gerador de números aleatórios
   MathSrand(uint(GetMicrosecondCount()));
//+------------------------------------------------------------------+
//| ler/inicializar matrizes match                                   |
//+------------------------------------------------------------------+
//ler_matriz_N_4_30(super_brain,"cosmos_training"+"//"+"match",false);
   ler_matriz_csv(super_brain,"cosmos_training"+"//"+"match"+"//"+"treino.csv",false);
//Ler/inicializar matriz diferencas/erro
//ler_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro",true);
   ler_matriz_csv(m_erro_brain,"cosmos_training"+"//"+"erro"+"//"+"treino.csv",true);
//Gerar arrays copia dos arrays salvos
//Usados para retornar ao valor anterior caso de loss em uma operacao
   for(int x=0; x<n_holes; x++)
      copiar_matriz_N(m_e_temp_brain,m_erro_brain,x);
   ler_vet_csv(Vet_erro,"cosmos_training"+"//"+"Ve"+"//"+"treino.csv",0);
   ler_vet_csv(parametrizadores,"cosmos_training"+"//"+"Vp"+"//"+"treino.csv",1);
   recover_tend=parametrizadores[2];
   dist_tp=parametrizadores[3];
   dist_sl=parametrizadores[4];
   op_gain=parametrizadores[6];
   last_op_gain=op_gain;
   counter_t_profit=parametrizadores[7];
   distancia=0;
   ArrayFill(distancias,0,n_holes,10000000000000000*Min_Val_Neg);
   ArrayInitialize(Vet_temp_erro,0);
   EventSetMillisecondTimer(400);// number of seconds ->0.4 segundos por evento
   fim_do_pregao=stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<10) || (stm.hour==10 && stm.min<=45);
   start=TimeCurrent();
//end=GetTickCount()-250000;
   forcar_entrada=550;
   trade_type=1;
   trade_type_reverso=(n_candles/2);
   on_trade=false;
   qtdd_loss=0;//enquanto o dia não inicia essa variavel se mantem zerada
   if(PositionsTotal()!=0)
      trade.PositionClose(_Symbol,ULONG_MAX);
   m_handle_periodo=iMA(_Symbol,_Period,21,0,MODE_EMA,PRICE_CLOSE);
   temp_tend=parametrizadores[2];
   handle_quick=iMA(simbolo,_Period,9,0,MODE_EMA,PRICE_CLOSE);
   handle_touch=iMA(simbolo,_Period,1,0,MODE_EMA,PRICE_CLOSE);
   m_handle_close=iMA(simbolo,_Period,21,0,MODE_EMA,PRICE_CLOSE);
   m_handle_tendency=iMA(simbolo,_Period,21,0,MODE_EMA,PRICE_CLOSE);
   ifr_ind_handle=iRSI(simbolo,_Period,100,PRICE_CLOSE);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   printf("numero de operacoes simuladas: "+string(oper_counter)+" modulador: "+string(parametrizadores[0])+" curr. media: "+string(parametrizadores[1]));
   printf("Tendencia: "+string(parametrizadores[2])+" Dist_offset: "+string(parametrizadores[3]));
//---desinicializar Menor valor negociavel
   EventKillTimer();
//reforcar parametrizadores importantes
   parametrizadores[3]=dist_tp;
   parametrizadores[6]=op_gain;
   parametrizadores[7]=counter_t_profit;
   parametrizadores[8]=m1;
   parametrizadores[9]=m2;
   parametrizadores[10]=m3;
   parametrizadores[11]=m4;
//salvar os arrays de match (brain)
   Salvar_Matriz_csv(super_brain,"cosmos_training"+"//"+"match"+"//"+"treino.csv");
//salvar as matrizes de erro
   Salvar_Matriz_csv(m_erro_brain,"cosmos_training"+"//"+"erro"+"//"+"treino.csv");
//Salvar os erros aceitaveis
   salvar_vet_csv(Vet_erro,"cosmos_training"+"//"+"Ve"+"//"+"treino.csv");
//Salvar parametros
   salvar_vet_csv(parametrizadores,"cosmos_training"+"//"+"Vp"+"//"+"treino.csv");
//Verificar escrita em disco
//double parametro_open=m_parametros[0];
   double erro_0 = Vet_erro[0];
   double match_0=super_brain[0][0][0];
   double erro_brain=m_erro_brain[0][0][0];
   ler_vet_csv(parametrizadores,"cosmos_training"+"//"+"Vp"+"//"+"treino.csv",1);
   ler_vet_csv(Vet_erro,"cosmos_training"+"//"+"Ve"+"//"+"treino.csv",0);
   ler_matriz_csv(super_brain,"cosmos_training"+"//"+"match"+"//"+"treino.csv",false);
   ler_matriz_csv(m_erro_brain,"cosmos_training"+"//"+"erro"+"//"+"treino.csv",true);
   if(MathRound(100*parametrizadores[3])!=MathRound(100*dist_tp))
      printf("Warning, parametrizadores salvos incorretamente");
   if(MathRound(100*match_0)!=MathRound(100*super_brain[0][0][0]))
      printf("Warning,Holes salvos incorretamente %f != %f",match_0,super_brain[0][0][0]);
   if(MathRound(100*erro_brain)!=MathRound(100*m_erro_brain[0][0][0]))
      printf("Warning,potencializadores salvos incorretamente %f != %f",erro_brain,m_erro_brain[0][0][0]);
   if(MathRound(100*erro_0)!=MathRound(100*Vet_erro[0]))
      printf("Warning,erros aceitaveis salvos incorretamente %f != %f",Vet_erro[0],erro_0);
   printf("parametros de aproximação: m1: %f m2: %f m3: %f m4: %f",MathRound(100*m1)/100,MathRound(100*m2)/100,MathRound(100*m3)/100,MathRound(100*m4)/100);
   ArrayPrint(Vet_erro);
   ArrayPrint(distancias);
   ArrayPrint(to_debug);
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
   double ifr_ind[1];
   double m_21[n_candles];
// CopyBuffer(m_handle_ima,0,0,n_candles,m_21);
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
         /*if(treinamento_ativo==0)
           {
            //stopou em caso real
            end=GetTickCount();
           }*/
         stops_N_dimensional(super_brain,m_erro_brain,m_e_temp_brain,Vet_erro,Vet_temp_erro,m_now);//1--> 1 loss dia 0-->infinito                                                                                                                    //Atencao retirado o incremento para treinamento
         //else qtdd_loss+=1;//gain tb conta como stop para realizar apenas 1 operação por dia --> transferido para dentro da funcao stop
         //mudar depois para resolver o problema do reinicio do bot
         //rodar o historico inteiro do dia pode ser uma solução sacrificando processamento
        }
     }
   if(CopyBuffer(m_handle_close,0,0,n_candles,m_close)==-1)
     {
      ArrayFill(m_close,0,n_candles,0);
      printf("problemas com o indicador");
      m_handle_close=iMA(simbolo,_Period,21,0,MODE_EMA,PRICE_CLOSE);
     }
   if(CopyBuffer(handle_touch,0,0,5,m_volumetricas)==-1)
     {
      ArrayFill(m_volumetricas,0,n_candles,0);
      printf("problemas com o indicador");
      handle_touch=iMA(simbolo,_Period,1,0,MODE_EMA,PRICE_CLOSE);
     }
   if(CopyBuffer(handle_quick,0,0,n_candles,m_quick)==-1)
     {
      ArrayFill(m_quick,0,n_candles,0);
      printf("problemas com o indicador");
      handle_quick=iMA(simbolo,_Period,9,0,MODE_EMA,PRICE_CLOSE);
     }
   int i=0;
   if(posicoes==0 && fim_do_pregao==false && on_trade==false)
     {
      if(CopyClose(simbolo,Periodo,0,n_candles,close)!=-1 && CopyOpen(simbolo,Periodo,0,n_candles,open)!=-1 && CopyHigh(simbolo,Periodo,0,n_candles,high)!=-1 && CopyLow(simbolo,Periodo,0,n_candles,low)!=-1)
        {
         i=0;
         while(i<n_candles)
           {
            if(MathIsValidNumber(open[i]) && MathIsValidNumber(close[i]) && MathIsValidNumber(high[i]) && MathIsValidNumber(low[i]))
              {
               //copiano candles 10 ultimos normalizados
               m_now[prof_cube-10][i]=close[i]-close[n_candles-1];//-m_parametros[prof_cube-10];
               m_now[prof_cube-9][i]=open[i]-close[n_candles-1];//-m_parametros[prof_cube-9];
               m_now[prof_cube-8][i]=low[i]-close[n_candles-1];//-m_parametros[prof_cube-8];
               m_now[prof_cube-7][i]=high[i]-close[n_candles-1];//-m_parametros[prof_cube-7];
               m_now[prof_cube-6][i]=m_close[i]-close[n_candles-1];//-m_parametros[prof_cube-6];
               m_now[prof_cube-5][i]=close[i]-open[i];//-m_parametros[prof_cube-5];
               m_now[prof_cube-4][i]=close[i]-high[i];//-m_parametros[prof_cube-4];
               m_now[prof_cube-3][i]=close[i]-low[i];//-m_parametros[prof_cube-3];
               m_now[prof_cube-2][i]=close[i]-m_close[i];//-m_parametros[prof_cube-2];
               m_now[prof_cube-1][i]=high[i]-low[i];//-m_parametros[prof_cube-1];
              }
            i+=1;
           }
        }
      tendencia=tendency();
      op_media=Operar_na_Media(m_close,m_volumetricas);//verifica toque na media m_volumetricas==media de 0 periodos ou seja, valor atual
      if(MathAbs(op_media)<4&&operar_perfuracao()!=0)
         op_media=operar_perfuracao();//verifica padrão perfuracao e engolfo
      if(MathAbs(op_media)<4&&operar_t_line_strike()!=0)
         op_media=operar_t_line_strike();//verifica padrão 3_strike_line
      if(MathAbs(op_media)<4&&operar_green_hammer()!=0)
         op_media=operar_green_hammer();
      if(MathAbs(op_media)<4&&operar_cruz_Media(m_close,m_quick)!=0)
         op_media=operar_cruz_Media(m_close,m_quick);
      if(CopyBuffer(ifr_ind_handle,0,0,1,ifr_ind)==-1)
        {
         ArrayFill(ifr_ind,0,1,0);
         printf("problemas com o indicador ifr");
         ifr_ind_handle=iRSI(simbolo,_Period,100,PRICE_CLOSE);;
        }
      if(op_media>=4)
        {
         double resistencia=next_resist()-8*Min_Val_Neg;
         if(ifr_ind[0]>55)
            op_media=0;
         else
            if(close[n_candles-1]>resistencia)
               op_media=0 ;
        }
      else
         if(op_media<=-4)
           {
            double suporte= next_suporte()+8*Min_Val_Neg;
            if(ifr_ind[0]<45)
               op_media=0;
            else
               if(close[n_candles-1]<suporte)
                  op_media=0;
           }
      double comparacoes[n_holes];// Inicio da seção de comparações
      int temp_type=n_holes-1;
      while(temp_type>=0)
        {
         comparacoes[temp_type]=compara_matrizes_N(super_brain,m_now,m_erro_brain,Vet_erro,temp_type+1);//vetor distancias é preenchido aqui
         temp_type--;
        }
      double d_venda_menor=distancias[0]+Vet_erro[0];
      int alfa=0;
      alfa_c=n_holes/2;
      alfa_v=0;
      for(alfa=0; alfa<n_holes/2; alfa++)
        {
         if((distancias[alfa]+Vet_erro[alfa])<=d_venda_menor)
           {
            if((alfa+1)!=ultimo_hole_ativo)
              {
               d_venda_menor=distancias[alfa]+Vet_erro[alfa];//distancia sem penalidade
               alfa_v=alfa;
              }
           }
        }
      double d_compra_menor=distancias[n_holes/2]+Vet_erro[n_holes/2];
      for(alfa=n_holes/2; alfa<n_holes; alfa++)
        {
         if((distancias[alfa]+Vet_erro[alfa])<=d_compra_menor)
           {
            if((alfa+1)!=ultimo_hole_ativo)
              {
               d_compra_menor=distancias[alfa]+Vet_erro[alfa];//distancia sem penalidade
               alfa_c=alfa;
              }
           }
        }
      //printf(string(alfa_c)+" "+string(alfa_v)+" "+string(distancias[alfa_c])+" "+string(distancias[alfa_v]));
      bool venda=false;
      bool compra=false;
      if(d_venda_menor<d_compra_menor)
         venda=true; // possivel venda real
      else
         if(d_compra_menor<d_venda_menor)
            compra=true;//possivel compra real
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
      if((MathAbs(distancias[ArrayMinimum(distancias,n_holes/2,n_holes/2)])<1*distancia || op_media>=4) && posicoes==0 && on_trade==false)//&&compra==true)
        {
         //entrou com padrao classico ou forcado (distancia)
         //comprar
         //     timer=GetTickCount();
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if((d_compra_menor)<1.01*(0.95*dist_tp+0.05*dist_sl+5*Min_Val_Neg))
            simulacao_contabil=1;//operar na media nao contabiliza
         else
            simulacao_contabil=0;//compra simulada não será contabilizada

         if(compra==true && posicoes==0 && tendencia>=3*parametrizadores[2]*Min_Val_Neg && qtdd_loss<loss_suportavel_dia && (forcar_entrada)>=900 && (d_compra_menor)<1.1*dist_tp &&(op_media>=4 || ( counter_t_profit>op_gain)))
            //entrou com padrão classico e apresentou condiçoes favoraveis
           {
            trade_type=1+alfa_c;//ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);
            trade_type_reverso=1+alfa_v;//ArrayMinimum(distancias,0,n_holes/2);
            stopar=ask-8*Min_Val_Neg;
            gainar=ask+8*Min_Val_Neg;
            trade.Buy(lotes,_Symbol,ask,stopar,gainar,"Compra dist "+string(trade_type)+" mean "+string(op_media)+" tend: "+string(tendencia)+" Tf: "+string(_Period));
            printf("------------Compra-------- "+string(ask)+" tendencia: "+string(parametrizadores[2]*Min_Val_Neg)+ "Trade Type "+ string(trade_type)+"IFR: "+string(ifr_ind[0]));
            double dist_real[n_holes];
            for(int f=0; f<n_holes; f++)
               dist_real[f]=distancias[f]+Vet_erro[f];
            ArrayPrint(dist_real);
            ArrayPrint(distancias);
            ArrayPrint(Vet_erro);
            Buy_Sell_Simulado=ask;
            Stop_tp_Simulado=ask;
            on_trade=true;
            //on_trade_simulado=false;
            treinamento_ativo=0;
            //end=GetTickCount();
            forcar_entrada=1;
            tentativa+=1;
            temp_tend=tendencia;
            ultimo_hole_ativo=trade_type;
            Sleep(3000);
           }
         else
           {
            if(op_media>=4&&forcar_entrada>=1200&&tendencia>=0&&ArrayMinimum(distancias,0,WHOLE_ARRAY)>=n_candles/2)//&&compra)//simula uma compra por padrões
               //entrou com padrão classico mas em condicoes desfavoraveis
               //rede com penalidade aponta compra
              {
               //forcar_entrada=900;
               Stop_tp_Simulado=last;
               if(on_trade_simulado==false)
                 {
                  Buy_Sell_Simulado=ask;
                  trade_type=1+ArrayMinimum(distancias,(n_holes/2),n_holes/2);
                  trade_type_reverso=1+ArrayMinimum(distancias,0,(n_holes/2));
                  on_trade_simulado=true;
                  treinamento_ativo=1;
                  op_media_virtual=1;
                  temp_tend=tendencia;
                  //distancia=d_compra_menor-Vet_erro[alfa_c];
                  printf("distancia de entrada em compra em padrao simulada:%.3f dist hole:%.3f tendencia:%.3f tend_min_aceitavel:%.3f ",distancia,distancias[ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY)],tendencia,parametrizadores[2]);
                 }
               else
                  if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
                     //stop virtual
                    {
                     on_trade=true;
                     treinamento_ativo=6;
                     on_trade_simulado=false;
                     forcar_entrada=900;
                    }
              }

            else
               if(ArrayMinimum(distancias,0,n_holes)>=n_holes/2&&forcar_entrada>=1200)//simula uma compra forcada só baseado na rede
                 {
                  //entrou forcado sem padrao classico
                  //forcar_entrada=900;
                  Stop_tp_Simulado=last;
                  if(on_trade_simulado==false)
                     //simula compra forcada sem padrão
                    {
                     Buy_Sell_Simulado=ask;
                     trade_type=1+ArrayMinimum(distancias,n_holes/2,n_holes/2);
                     trade_type_reverso=1+ArrayMinimum(distancias,0,(n_holes/2));
                     on_trade_simulado=true;
                     treinamento_ativo=1;
                     temp_tend=parametrizadores[2];
                     printf("distancia de entrada em compra:%.3f dist hole:%.3f tendencia:%.3f tend_min_aceitavel:%.3f ",distancia,distancias[ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY)],tendencia,parametrizadores[2]);
                    }
                  else
                     if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
                       {
                        //stop virtual
                        on_trade=true;
                        treinamento_ativo=6;
                        on_trade_simulado=false;
                        forcar_entrada=900;
                       }
                 }
           }
        }
      else
         if(op_media_virtual>0)//esta operando por padrao classico
           {
            if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
              {
               on_trade=true;
               treinamento_ativo=6;
               on_trade_simulado=false;
               forcar_entrada=900;
              }
           }
      if((MathAbs(distancias[ArrayMinimum(distancias,0,n_holes/2)])<1*distancia || op_media<=-4) && posicoes==0 && on_trade==false)//&&venda==true
        {

         //timer=GetTickCount();
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         //Analise de venda
         if(((d_venda_menor)<1.01*(0.95*dist_tp+0.05*dist_sl+5*Min_Val_Neg)))
            simulacao_contabil=1;//valido como entrada para atualizar parametros
         else
            simulacao_contabil=0;
         if(venda==true && posicoes==0 && tendencia<=-3*parametrizadores[2]*Min_Val_Neg && qtdd_loss<loss_suportavel_dia && (forcar_entrada)>=900 &&(d_venda_menor)<1.1*dist_tp &&  (op_media<=-4 || (counter_t_profit>=op_gain)))//aguarda ao menos 5min antes da proxima operação real
           {
            //vender
            trade_type=1+alfa_v;//ArrayMinimum(distancias,0,n_holes/2);
            trade_type_reverso=1+alfa_c;//ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);
            stopar=bid+8*Min_Val_Neg;
            gainar=bid-8*Min_Val_Neg;
            trade.Sell(lotes,_Symbol,bid,stopar,gainar,"Venda dist "+string(trade_type)+" mean "+string(op_media)+" tend: "+string(tendencia)+" Tf: "+string(_Period));
            printf("------------V. distancia-----------"+string(bid)+" tendencia: "+string(-parametrizadores[2]*Min_Val_Neg)+" trade_type= "+string(trade_type)+" IFR: "+string(ifr_ind[0]));
            double dist_real[n_holes];
            for(int f=0; f<n_holes; f++)
               dist_real[f]=distancias[f]+Vet_erro[f];
            ArrayPrint(dist_real);
            ArrayPrint(distancias);
            ArrayPrint(Vet_erro);
            Buy_Sell_Simulado=bid;
            Stop_tp_Simulado=bid;
            on_trade=true;
            //on_trade_simulado=true;
            treinamento_ativo=0;
            //end=GetTickCount();
            forcar_entrada=1;
            last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
            tentativa+=1;
            temp_tend=-tendencia;
            ultimo_hole_ativo=trade_type;
            Sleep(3000);
           }
         else
           {
            if(op_media<=-4&&forcar_entrada>=1200&&ArrayMinimum(distancias,0,WHOLE_ARRAY)<n_candles/2&&tendencia<=0)
              {
               //forcar_entrada=900;
               Stop_tp_Simulado=last;
               if(on_trade_simulado==false)
                 {
                  //primeira passagem pela entrada virtual
                  Buy_Sell_Simulado=bid;
                  trade_type=1+ArrayMinimum(distancias,0,n_holes/2);
                  trade_type_reverso=1+ArrayMinimum(distancias,n_holes/2,n_holes/2);
                  on_trade_simulado=true;
                  treinamento_ativo=-1;
                  op_media_virtual=-1;
                  temp_tend=-tendencia;
                  //distancia=d_venda_menor-Vet_erro[alfa_v];
                  printf("media venda simulada distancia de entrada em venda:%.3f dist hole:%.3f tendencia:%.3f tend_min_aceitavel: -%.3f",distancia,distancias[ArrayMinimum(distancias,0,(n_holes/2)-1)],tendencia,parametrizadores[2]);
                 }
               else
                  if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg&&forcar_entrada>=1200)
                    {
                     //loss ou gain virtual
                     on_trade=true;
                     treinamento_ativo=-5;//entra novamente na operacao stop como treinamento forcado de venda
                     on_trade_simulado=false; //funcao semelhante ao getpositions
                     forcar_entrada=900;
                    }
              }
            else
               if(ArrayMinimum(distancias,0,n_holes)<n_holes/2&&forcar_entrada>=1200)//só  entrada venda virtual forcada
                 {
                  //forcar_entrada=900;
                  Stop_tp_Simulado=last;
                  if(on_trade_simulado==false)
                    {
                     //primeira passagem pela entrada virtual
                     Buy_Sell_Simulado=bid;
                     trade_type=1+ArrayMinimum(distancias,0,n_holes/2);
                     trade_type_reverso=1+ArrayMinimum(distancias,n_holes/2,n_holes/2);
                     on_trade_simulado=true;
                     treinamento_ativo=-1;
                     temp_tend=parametrizadores[2];
                     printf("distancia de entrada em venda:%.3f dist hole:%.3f tendencia:%.3f tend_min_aceitavel: -%.3f",distancia,distancias[ArrayMinimum(distancias,0,(n_holes/2)-1)],tendencia,parametrizadores[2]);
                    }
                  else
                     if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
                       {
                        //loss ou gain virtual
                        on_trade=true;
                        treinamento_ativo=-6;//entra novamente na operacao stop como treinamento forcado de venda
                        on_trade_simulado=false; //funcao semelhante ao getpositions
                        forcar_entrada=900;
                       }
                 }
           }
        }
      else
         if(op_media_virtual<0)
           {
            if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
              {
               //loss ou gain virtual
               on_trade=true;
               treinamento_ativo=-6;//entra novamente na operacao stop como treinamento forcado de venda
               on_trade_simulado=false; //funcao semelhante ao getpositions
               forcar_entrada=900;
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
         //end=GetTickCount();
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
   int hole=trade_type-1;//ArrayMinimum(distancias);
   bool compra=false;
   bool venda=false;
   if(trade_type!=0 && hole<=(n_holes/2))
      venda=true;
   else
      if(hole>(n_holes/2))
         compra=true;
   if(treinamento_ativo==0)//operacao foi real
     {
      //--- request trade history
      HistorySelect(0,TimeCurrent());
      ulong    ticket=0;
      uint     total=HistoryDealsTotal();
      double profit=0;

      /*      if((ticket=HistoryDealGetTicket(total))>0)
              {
               profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
               if(profit<=0)
                  qtdd_loss+=1;
              }
            else
               qtdd_loss+=1; //por via das duvidas nao opera mais
      */
      /*HistorySelect(start,TimeCurrent());
      total=HistoryOrdersTotal();
      ulong last_ticket=HistoryOrderGetTicket(total-1);
      ulong l_last_ticket=HistoryOrderGetTicket(total-2);
      last_trade=double(HistoryOrderGetDouble(last_ticket,ORDER_PRICE_OPEN));
      l_last_trade=double(HistoryOrderGetDouble(l_last_ticket,ORDER_PRICE_OPEN));
      //end=GetTickCount();*/
      double lucro_prej=0;
      last_trade=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
      l_last_trade=Buy_Sell_Simulado;
      Buy_Sell_Simulado=last_trade;
      if(compra)
         lucro_prej+=last_trade-l_last_trade;
      else
         if(venda)
            lucro_prej-=last_trade-l_last_trade;
      /*if(lucro_prej<=0)
         qtdd_loss+=1;*/
      stop=true;//considera um stop true, caso seja gain esse valor será atualizado para false
      printf("operaçao real lucro/prej.: "+string(lucro_prej));
      if(lucro_prej<4*Min_Val_Neg)//margem de seguranca, considerar loss operacoes com lucro menor que o esperado
         qtdd_loss+=1;
     }
   else//operacao só treinamento
     {
      last_trade=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
      l_last_trade=Buy_Sell_Simulado;
      Buy_Sell_Simulado=last_trade;
     }
//double minimum;
//double maximum;
   int i=0;
   int w=0;
   int j=0;
   if((compra && l_last_trade>=last_trade) || (venda && l_last_trade<=last_trade))
     {
      //--================----loss - aproxima pouco afasta muito
      oper_counter-=1;
      ArrayFill(analisados,0,prof_cube*n_candles,0);
      //caso de loss procurar o indice do maior erro e aproximar
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (10% da matriz)
      aproximar_candles(int(0.2*prof_cube*n_candles),prox_fact_loss,Loss_Direto);
      //manter a mesma distancia para não alterar o resultado da operação de afastamento
      //caso de loss procurar o indice do menor erro e afastar
      //significa que aquele valor nao era importante
      //fazer essa alteração  (25% dos candles)
      if(treinamento_ativo==0)//operacao foi real
         afastar_candles(int(0.8*prof_cube*n_candles),afast_fact_loss_real,Loss_Direto);
      else
         afastar_candles(int(0.8*prof_cube*n_candles),afast_fact_loss_n_real,Loss_Direto);
      ArrayFill(analisados,0,prof_cube*n_candles,0);
      //----------trabalhando com as vizinhancas - aproxima muito afasta pouco
      //caso de loss procurar todoso indice do menor erro da operacao inversa e tratar como gain
      //diferente de tratar a operacao isso aproxima holes distantes do valor now
      //significa que aquele valor era para ser o de real entrada
      //fazer essa alteração  (25% dos candles)
      afastar_candles(int(0.3*prof_cube*n_candles),afast_fact_loss_viz,Gain_Reverso);//operar vizinhanca, tratar como gain a operacao inversa
      aproximar_candles(int(0.4*prof_cube*n_candles),prox_fact_loss_viz,Gain_Reverso);//operar vizinhanca, tratar como gain a operacao inversa
      erro[hole]=0.9*erro[hole]+0.1*temp_erro[hole]-MathAbs(0.8*distancia);//diminuir esse valor para dificultar um nova entrada (para treinamento)
      Normalizar_erros();//normalizar erros
      if(simulacao_contabil==1)
        {
         counter_t_profit+=(0-counter_t_profit)/21;
         dist_sl=MathMax(dist_sl+(distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_sl)/(0.9*n_candles),1.2*dist_tp);
         dist_tp=MathMax(dist_tp+((distancias[trade_type_reverso-1]+Vet_erro[trade_type_reverso-1]-dist_tp)/(0.9*n_candles)),4*Min_Val_Neg);
        }
      else
        {
         dist_sl=MathMax(dist_sl+(distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_sl)/(9*n_candles),1.2*dist_tp);
         dist_tp=MathMax(dist_tp+((distancias[trade_type_reverso-1]+Vet_erro[trade_type_reverso-1]-dist_tp)/(9*n_candles)),4*Min_Val_Neg);
        }
      //copiar_matriz_N(m_erro,m_temp_erro,trade_type-1);
      parametrizadores[0]+=0.05*(16383.5-MathRand())*Min_Val_Neg/(16383.50);//alimentar o modulador
      parametrizadores[0]=0.5*parametrizadores[0]+0.5*Modulador;
      parametrizadores[0]=MathMax(MathMin(parametrizadores[0],0.1),0.01);
      //Oscilar_matriz(m_parametros,m_pre_par);
      //parametrizadores[5]=m_parametros[4];
      if(op_media!=0)
        {
         parametrizadores[1]+=0.5*(16383.5-MathRand())/(16383.5);//alimentar a media
         parametrizadores[1]=0.5*save_ma+0.5*parametrizadores[1];
         parametrizadores[1]=MathMax(MathMin(parametrizadores[1],25),17);
         op_media=0;
        }
      else
         if(op_media_virtual!=0)
           {
            m2=1.02*restore_m2;
            m3=1.02*restore_m3;
            m4=1.02*restore_m4;
            op_media_virtual=0;
           }
      parametrizadores[2]=1.02*recover_tend;
      op_gain=last_op_gain;
      distancia=0;
      printf("stop loss caso:%d dist t_prof.:%.3f Err acc.:%.3f tk p:%.3f op_gain:%.3f",trade_type,dist_tp,erro[hole],counter_t_profit,op_gain);
     }
//foi gain
   else
      if((compra && l_last_trade<last_trade) || (venda && l_last_trade>last_trade))
        {
         oper_counter+=1;
         //caso de gain procurar o indice de maior  erro e aumentar a distancia
         //reduzir o erro de gatilho proporcionalmente diminuindo a significancia
         //significa que aquele valor realmente não era importante
         //fazer essa alteração 6 x (5% dos candles)
         afastar_candles(int(0.2*prof_cube*n_candles),afast_fact_gain,Gain_Direto);
         //caso de gain procurar o indice de menor  erro e reduzir a distancia
         //alterar m_erro para manter a mesma distancia (aumentar a significancia)
         //significa que aquele valor era importante
         //fazer essa alteração 6 x (5% dos candles)
         aproximar_candles(int(0.8*prof_cube*n_candles),prox_fact_gain,Gain_Direto);
         //
         afastar_candles(int(0.25*prof_cube*n_candles),afast_fact_loss_viz,Loss_Reverso);//operar vizinhanca, tratar como loss a operacao inversa
         aproximar_candles(int(0.25*prof_cube*n_candles),prox_fact_loss_viz,Loss_Reverso);//operar vizinhanca, tratar como loss a operacao inversa
         int temp_trade_type=trade_type;
         /*if(venda==true)
            trade_type=1+ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);//procurar menor distancia nas compras
         //compra==true
         else
            trade_type=1+ArrayMinimum(distancias,0,n_holes/2);*/
         trade_type=temp_trade_type;
         //absorver o erro aceitavel
         temp_erro[hole]=(0.1*erro[hole]+0.9*temp_erro[hole]);//Absorver valor que deu certo para futuro loss
         erro[hole]=MathMin(erro[hole]+0.02*(((16383.5-MathRand())/16383.5)*Min_Val_Neg),-0.00000000001*Min_Val_Neg);//Oscilar em 0.04* o min val neg
         Normalizar_erros();//normalizar erros
         if(simulacao_contabil==1)
           {
            counter_t_profit+=(1-counter_t_profit)/21;//media exponencial 21
            dist_tp=MathMin(dist_tp+((distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_tp)/(0.9*n_candles)),1000000000000);
           }
         else
            dist_tp=MathMax(MathMin(dist_tp+((distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_tp)/(200)),1000000000000),1);
         if(dist_tp==1000000000000)
            parametrizadores[0]+=0.03*(16383.5-MathRand())*Min_Val_Neg/(16383.50);
         Modulador=parametrizadores[0];
         //estabiliza_matriz();
         //Const_dist=parametrizadores[5];
         if(op_media!=0)
           {
            save_ma=parametrizadores[1];
            op_media=0;
           }
         else
            if(op_media_virtual!=0)
              {
               restore_m2=m2;
               restore_m3=m3;
               restore_m4=m4;
               m2=0.1*MathAbs(temp_m2)+(0.85*m2);
               m3=0.1*MathAbs(temp_m3)+(0.85*m3);
               m4=0.1*MathAbs(temp_m4)+(0.85*m4);
               m2=MathMin(MathMax(m2,0.5),2.5*m1);
               m3=MathMin(MathMax(m3,m2),2.5*m2);
               m4=MathMin(MathMax(m4,MathMax(m3,MathMax(m2,m1))),1.5*m3);
               op_media_virtual=0;
              }
         printf("t. prof. caso:%d dist t_prof.:%.3f Err acc.:%.3f tk p:%.3f op_gain:%.3f",trade_type,dist_tp,erro[hole],counter_t_profit,op_gain);
         last_op_gain=op_gain;
         op_gain=MathMax(op_gain+(counter_t_profit-op_gain)/n_holes,0.8);
         //aproximar_matriz_N(m_temp_erro,m_erro,trade_type-1);
         //parametrizadores[0]-=(2*16383.5-MathRand())*Min_Val_Neg/(2*163835000);//reduzir o modulador
         temp_dist+=(distancias[hole]-temp_dist)/17;
         distancia=MathMin(MathMax(0.2*temp_dist,0),20*Min_Val_Neg);
         //copiar_matriz_N(m_erro,m_temp_erro,trade_type-1);
         stop=false;//mesmo sendo operacao real se for gain stop returna false - reverção
         recover_tend=parametrizadores[2];
         parametrizadores[2]=MathMin(MathMax(0.85*parametrizadores[2]+0.1*temp_tend,0.001),0.25);
        }
      else
        {
         printf("Obstrucao por tendencia 0x0 compra: "+string(compra)+" venda: "+string(venda));
        }
   normalizar_m_erros();
//normalizar_m_match();
   parametrizadores[3]=dist_tp;
   parametrizadores[4]=dist_sl;
   parametrizadores[6]=op_gain;
   parametrizadores[7]=counter_t_profit;
//salvar_matriz_N_4_30(match,"cosmos_training"+"//"+"match");
//Salvar_Matriz_csv(super_brain,"cosmos_training"+"//"+"match"+"//"+"csv");
//salvar_matriz_N_4_30(m_erro,"cosmos_training"+"//"+"erro");
//Salvar_Matriz_csv(m_erro,"cosmos_training"+"//"+"erro"+"//"+"csv");
//salvar_vet_erro(Vet_erro,"cosmos_training"+"//"+"Ve");
//salvar_vet_csv(Vet_erro,"cosmos_training"+"//"+"Ve"+"//"+"csv");
//salvar_parametrizadores(parametrizadores,"cosmos_training"+"//"+"Vp"+"//"+"csv");
//salvar_vet_csv(parametrizadores,"cosmos_training"+"//"+"Vp"+"//"+"csv");
//salvar_m_parametros(m_parametros,"cosmos_training"+"//"+"Mp");
//salvar_vet_csv(m_parametros,"cosmos_training"+"//"+"Mp");
//salvar_distancias_0(distancias,"cosmos_training"+"//"+"Vd0");
//salvar_vet_csv(distancias,"cosmos_training"+"//"+"Vd0"+"//"+"csv");
   to_debug[trade_type-1]++;
   return stop;
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
// iVolume(_Symbol,Periodo,0);
//timer=GetTickCount();
   tm=TimeCurrent();
   TimeToStruct(tm,stm);
   fim_do_pregao=stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<10) || (stm.hour==10 && stm.min<=45);
   if(fim_do_pregao==true)
     {
      //operar apenas apos 10:30 e antes das 17:30
      //primeiro_t_media_cp=0;
      //primeiro_t_media_venda=0;
      start=TimeCurrent();//inicio da history dos valores negociados
      //end=GetTickCount()-250000;
      forcar_entrada=550;
      trade_type=1+ArrayMinimum(distancias,0);
      on_trade=false;
      tentativa =0;
      counter_t_profit=0.5;
      qtdd_loss=0;//enquanto o dia não inicia essa variavel se mantem zerada

      if(PositionsTotal()!=0 && fechou_posicao==false)
        {
         trade.PositionClose(_Symbol,ULONG_MAX); //Operacao perigosa, entra em looping se não for executada instantaneamente
         fechou_posicao=true;//deu uma vez esse ordem - Só libera para dar denovo caso ela seja executada
        }
      if(PositionsTotal()==0)
         fechou_posicao=false; //Melhor deixar as operações morrerem por tempo ou por stop/gain
      treinamento_ativo=NULL;
     }
   else
     {
      forcar_entrada=MathMin(forcar_entrada+0.4,18000);
      double incrementer=distancias[ArrayMinimum(distancias,0,WHOLE_ARRAY)]/5000;
      if(MathAbs(close[n_candles-1]-close[0])>=8*Min_Val_Neg&&on_trade==0&&on_trade_simulado==0&&(forcar_entrada>=1800&&forcar_entrada<=1800.5))
        {
         distancia=distancia+2000*(incrementer);//entra em operação forcada
         forcar_entrada+=0.4;
        }
      fechou_posicao=false;
      distancia=distancia+(incrementer);//entra em operação forcada
     }
   /*if((stm.hour==13 && stm.min==05)&&tentativa==1)  //entrada da parte inicial da tarde
     {
      tentativa=2;
      qtdd_loss=0;
     }
   else
      if((stm.hour==14 && stm.min==00)&&tentativa==2)
        {
         qtdd_loss=1;
         tentativa=3;
        }*/
  }
//+------------------------------------------------------------------+
//+Funcao para salvar matrizes n_holes x n_candles
//+------------------------------------------------------------------+
/*void salvar_matriz_N_4_30(double  &matriz[][prof_cube][n_candles],string path)
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
                        else linha+=string(vec[i])+"\n";
           }
         //FileWrite(file_handle,linha);
         //linha="";"cosmos_training"+"//"+"match"
         add=Ativo+"_"+string(_Period)+"//"+path+"_"+string(w)+"_"+string(j);
         filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
         FileWriteArray(filehandle,vec,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }
     }
  }*/
//+------------------------------------------------------------------+
//|  funcao para salvar vetor dos erros aceitaveis                                                                |
//+------------------------------------------------------------------+
/*void salvar_vet_erro(double &erro[],string path)
  {
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   int handle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteArray(handle,erro,0,WHOLE_ARRAY);
   FileClose(handle);
  }*/
//+------------------------------------------------------------------+
//|Alguns parametros são atualizados durante o treinamento                                                                  |
//+------------------------------------------------------------------+
/*void salvar_parametrizadores(double &paramet[],string path)
  {
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   int handle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
   FileWriteArray(handle,paramet,0,WHOLE_ARRAY);
   FileClose(handle);
  }*/



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
//| Ler vetor erro aceitavel//se nao existir já cria                                                                 |
//+------------------------------------------------------------------+
/*void ler_vetor_erro_aceitavel(string path)//se não existir já cria
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
  }*/

//+----------------------------------------------------------------------------+
//Funcao para normalizar os erros aceitaveis, evita que os torne muito grandes                    |
//+----------------------------------------------------------------------------+
void Normalizar_erros()
  {
   int i=0;
   double media=0;
   for(int j=0; j<n_holes; j++)
     {
      if(MathAbs(Vet_erro[j])<MathAbs(Vet_erro[i]))
        {
         i=j;
        }
      media+=Vet_erro[j]/n_holes;
     }
   double menor=-MathAbs(Vet_erro[i]);
   for(i=0; i<ArraySize(Vet_erro); i++)
      Vet_erro[i]=MathMax(MathMin(Vet_erro[i]-menor,-0.0000000000001*Min_Val_Neg),1.6*media);//Esse valor não pode ser positivo senão ocorre overflow
  }
//+------------------------------------------------------------------+
//|//usada quando a matriz de erro explode
//+------------------------------------------------------------------+
void Embaralhar_matriz(double &matriz[][prof_cube][n_candles],int d)
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
//| //usado quando a matriz match explode                                                                 |
//+------------------------------------------------------------------+
void Recriar_matriz(double &M[][prof_cube][n_candles],double &M0[][n_candles],int d)
  {
   int j=0;
   int i=0;
   for(i=0; i<prof_cube; i++)
      for(j=0; j<n_candles; j++)
        {
         if(MathIsValidNumber(m_erro_brain[d][i][j]))
            m_erro_brain[d][i][j]*=0.9;
         else
            m_erro_brain[d][i][j]=1;
         if(MathIsValidNumber(M[d][i][j]) && MathIsValidNumber(M0[i][j]))
            M[d][i][j]=0.7*M[d][i][j]+0.3*M0[i][j];
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
//+ Funcao para oscilar uma matriz em 3% do seu valor atual
//+ Usada em caso de loss para tentar encontrar um valor melhor      |
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
/*void estabiliza_matriz()
  {
   for(int i=0; i<prof_cube; i++)
      m_pre_par[i]=m_parametros[i];
  }*/
//+------------------------------------------------------------------+
//|funcao que termo a termo as matrizes match com as matrizes        |
//now(valores atuais) e decide se houve similaridade                 |
//funcao mais requisitada do expert                                  |
//preenche um array com as distancias                                |
//+------------------------------------------------------------------+
int compara_matrizes_N(double &match[][prof_cube][n_candles],double &now[][n_candles],double &m_erro[][prof_cube][n_candles],double &err_aceitavel[],int tipo)
  {
   int i=n_candles-1;
   int j=4;
   int hole=tipo;
   double diferencas_temp=0;
//comecar pelos ultimos valores que correspondem aos candles mais atuais
   double d_temp=0;
   double media_distancias=0;
   if(!MathIsValidNumber(err_aceitavel[tipo-1]))
      err_aceitavel[tipo-1]=-200000*Min_Val_Neg;
   distancias[tipo-1]=-err_aceitavel[tipo-1];
   for(i=n_candles-1; i>=0; i--)
     {
      for(j=prof_cube-1; j>=0; j--)
        {
         diferencas_temp=(now[j][i]-match[tipo-1][j][i]);
         diferencas_temp*=m_erro[tipo-1][j][i];
         diferencas_temp*=diferencas_temp;
         if(MathIsValidNumber(diferencas_temp))
           {
            d_temp+=diferencas_temp;
           }
         else// if(!MathIsValidNumber(now[j][i])||!MathIsValidNumber(match[tipo-1][j][i])||!MathIsValidNumber(m_erro[tipo-1][j][i]))
           {
            //d_temp+=0; //desconsidera para soma das distancias
            if(!MathIsValidNumber(now[j][i]))
               now[j][i]=5*Min_Val_Neg;
            if(!MathIsValidNumber(match[tipo-1][j][i]))
               match[tipo-1][j][i]=0.7*now[j][i];
            if(!MathIsValidNumber(m_erro[tipo-1][j][i]))
               m_erro[tipo-1][j][i]=1;
           }
        }
      distancias[tipo-1]+=d_temp;//MathSqrt(d_temp);
      d_temp=0;
     }
   for(i=0; i<n_holes; i++)
      media_distancias+=MathAbs((distancias[i]+err_aceitavel[i])/n_holes);
   if((distancias[tipo-1]+err_aceitavel[tipo-1])>=20*media_distancias+10*Min_Val_Neg)//explodiu
     {
      printf("dist. muito grande: %.3f dist. aceit.: %3f regenerando matriz: %d Erro Aceit.: %.3f",distancias[hole-1]+err_aceitavel[tipo-1],media_distancias,tipo-1,err_aceitavel[tipo-1]);
      Embaralhar_matriz(m_erro_brain,hole-1);
      Recriar_matriz(super_brain,m_now,hole-1);
     }
   /*if(err_aceitavel[tipo-1]<=-5*media_distancias-10*Min_Val_Neg)//explodiu
      err_aceitavel[tipo-1]=-5*media_distancias-10*Min_Val_Neg;*/
   return 1;
  }
//+------------------------------------------------------------------+
//|Funcao que define se tocou ou não na media //padrao classico      |
//+------------------------------------------------------------------+
int Operar_na_Media(double &m_media[], double &m_volumetrica[])
  {
   int retorno=0;
   int charlie=ArraySize(open);
   if((low[n_candles-1]-m_media[n_candles-1])<=m1*Min_Val_Neg&&(low[n_candles-1]-m_media[n_candles-1]>=0))
     {
      //compra
      temp_m2=MathMax((low[charlie-2]-m_media[n_candles-2])/Min_Val_Neg,0.01);
      temp_m3=MathMax((low[charlie-3]-m_media[n_candles-3])/Min_Val_Neg,0.01);
      temp_m4=MathMax((low[charlie-4]-m_media[n_candles-4])/Min_Val_Neg,0.01);
      retorno=1;
      if(low[charlie-2]-m_media[n_candles-2]>=m2*Min_Val_Neg && low[charlie-2]-m_media[n_candles-2]<=(9*m2)*Min_Val_Neg&&low[n_candles-2]-m_media[n_candles-2]>=0)
        {
         retorno=2;
         if(low[charlie-3]-m_media[n_candles-3]>=m3*Min_Val_Neg)
           {
            retorno=3;
            if(low[charlie-4]-m_media[n_candles-4]>=m4*Min_Val_Neg || (low[charlie-3]-m_media[n_candles-3]>=m4*Min_Val_Neg || low[charlie-2]-m_media[n_candles-2]>=m4*Min_Val_Neg))
              {
               //printf("Toque na média compra aceitavel");
               retorno=4;
              }
           }
        }
     }
   else
      if((high[n_candles-1]-m_media[n_candles-1])>=-m1*Min_Val_Neg&& (high[n_candles-1]-m_media[n_candles-1])<=0)
        {
         //Venda
         temp_m2=MathMin((high[charlie-2]-m_media[n_candles-2])/Min_Val_Neg,0);
         temp_m3=MathMin((high[charlie-3]-m_media[n_candles-3])/Min_Val_Neg,0);
         temp_m4=MathMin((high[charlie-4]-m_media[n_candles-4])/Min_Val_Neg,0);
         retorno=-1;
         if(high[charlie-2]-m_media[n_candles-2]<=-m2*Min_Val_Neg && high[charlie-2]-m_media[n_candles-2]>=-(9*m2)*Min_Val_Neg&&high[n_candles-2]-m_media[n_candles-2]<=0)
           {
            retorno=-2;
            if(high[charlie-3]-m_media[n_candles-3]<=-m3*Min_Val_Neg)
              {
               retorno=-3;
               if(high[charlie-4]-m_media[n_candles-4]<=-m4*Min_Val_Neg || (high[charlie-3]-m_media[n_candles-3]<=-m4*Min_Val_Neg || high[charlie-2]-m_media[n_candles-2]<=-m4*Min_Val_Neg))
                 {
                  //printf("Toque na média aceitavel");
                  retorno =-4;//venda
                 }
              }
           }
        }
   return retorno;
  }
//+------------------------------------------------------------------------+
//|Funcao que define se cruzou 2 medias ou não na media //padrao classico  |
//+------------------------------------------------------------------------+
int operar_cruz_Media(double &slow[],double &quick[])
  {
   int retorno=0;
   int charlie=ArraySize(slow);
   double e1=1;
   double e2=1;
   double e3=3;
   double e4=4;
   if((quick[n_candles-1]-slow[n_candles-1])>=e1*Min_Val_Neg)
     {
      //compra
      retorno=0;
      if(quick[charlie-2]-slow[n_candles-2]<=-e2*Min_Val_Neg)
        {
         retorno=0;
         if(quick[charlie-3]-slow[n_candles-3]<=-e3*Min_Val_Neg)
           {
            retorno=0;
            if(quick[charlie-4]-slow[n_candles-4]<=-e4*Min_Val_Neg)
              {
               //printf("cruz média compra aceitavel");
               retorno=8;
              }
           }
        }
     }
   else
      if((quick[n_candles-1]-slow[n_candles-1])<=-e1*Min_Val_Neg)
        {
         //Venda
         retorno=-0;
         if(quick[charlie-2]-slow[n_candles-2]>=e2*Min_Val_Neg)
           {
            retorno=-0;
            if(quick[charlie-3]-slow[n_candles-3]>=e3*Min_Val_Neg)
              {
               retorno=-0;
               if(quick[charlie-4]-slow[n_candles-4]>=e4*Min_Val_Neg)
                 {
                  //printf("cruz  média aceitavel -- venda");
                  retorno =-8;//venda
                 }
              }
           }
        }
   return retorno;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int operar_perfuracao()//padrao candle classico
  {
   double alta_baixa[5];
   alta_baixa[4]=close[n_candles-1]-open[n_candles-1];//>0 alta <0 baixa ==0 doji
   alta_baixa[3]=close[n_candles-2]-open[n_candles-2];
   alta_baixa[2]=close[n_candles-3]-open[n_candles-3];
   alta_baixa[1]=close[n_candles-4]-open[n_candles-4];
   alta_baixa[0]=close[n_candles-5]-open[n_candles-5];
   if(alta_baixa[0]<0 && close[n_candles-5]<close[n_candles-6])//baixa 1
     {
      if(alta_baixa[1]<0 && close[n_candles-4]<close[n_candles-5])//baixa 2
         if(alta_baixa[2]<0 && close[n_candles-3]<(close[n_candles-4]-2*Min_Val_Neg))//baixa forte
            //perfuracao (alta)
            if(alta_baixa[3]>0 && open[n_candles-2]<(close[n_candles-3]-0.5*Min_Val_Neg) && close[n_candles-2]>0.5*(close[n_candles-3]+open[n_candles-3]+1*Min_Val_Neg))
               if(close[n_candles-1]>(close[n_candles-2]+2*Min_Val_Neg)&&close[n_candles-1]<(close[n_candles-2]+6*Min_Val_Neg))//confirmou
                 {
                  return 5;
                 }
     }//comprar por padrão piercing ou engolfo
   if(alta_baixa[0]>0 && close[n_candles-5]>close[n_candles-6])
     {
      if(alta_baixa[1]>0 && close[n_candles-4]>close[n_candles-5])//alta 2
         if(alta_baixa[2]>0 && close[n_candles-3]>(close[n_candles-4]+2*Min_Val_Neg))//alta forte
            //perfuracao
            if(alta_baixa[3]<0 && open[n_candles-2]>(close[n_candles-3]+0.5*Min_Val_Neg)&& close[n_candles-2]<0.5*(close[n_candles-3]+open[n_candles-3]-1*Min_Val_Neg))
               if(close[n_candles-1]<(close[n_candles-2]-2*Min_Val_Neg)&&close[n_candles-1]>(close[n_candles-2]-6*Min_Val_Neg)) //confirmou
                 {
                  return -5;
                 }
     }
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int operar_t_line_strike() //padrao candle classico
  {
   int retorno =0;
   if(close[n_candles-1]>high[n_candles-4])
     {
      retorno=0;
      if(open[n_candles-1]<low[n_candles-2])
        {
         retorno=0;
         if(low[n_candles-2]<low[n_candles-3]&&(close[n_candles-2]-low[n_candles-2])<=2*Min_Val_Neg)
           {
            retorno =1;
            if(low[n_candles-3]<low[n_candles-4]&&(close[n_candles-3]-low[n_candles-3])<=2*Min_Val_Neg)
              {
               retorno=2;
               if((close[n_candles-4]-low[n_candles-4])<=2*Min_Val_Neg)
                 {
                  retorno=6;
                 }
              }
           }
        }
     }
   else
      if(close[n_candles-1]<low[n_candles-4])
        {
         retorno=0;
         if(open[n_candles-1]>high[n_candles-2])
           {
            retorno=0;
            if(high[n_candles-2]>high[n_candles-3]&&(high[n_candles-2]-close[n_candles-2])<=2*Min_Val_Neg)
              {
               retorno =-1;
               if(high[n_candles-3]>high[n_candles-4]&&(high[n_candles-3]-close[n_candles-3])<=2*Min_Val_Neg)
                 {
                  retorno=-2;
                  if((high[n_candles-4]-close[n_candles-4])<=2*Min_Val_Neg)
                    {
                     retorno=-6;
                    }
                 }
              }
           }
        }
   return retorno;
  }
//+------------------------------------------------------------------+
//| Afasta candles dependendo de loss ou gain                                                                 |
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
   double analisado=0;
   for(i=0; i<n_candles; i++)
      for(j=0; j<prof_cube; j++)
         analisados[j][i]=0;
   int ind[2]= {-1,-1};
   num_candles=int(MathMin(num_candles,n_candles*prof_cube));
   int vizinho=0;//0;
   int limite=(n_holes/2)-1;//n_holes/2;
   if(trade_type-1>=(n_holes/2))
     {
      vizinho=n_holes/2;//n_holes/2;
      limite=n_holes-1;//n_holes;
     }
   if(loss_gain==0)//loss - afasta os mais proximos
     {
      if(treinamento_ativo!=0)   //operacao n foi real
        {
         if((trade_type-1-3)>vizinho)
            vizinho=trade_type-1-3;
         else
            if((trade_type-1-2)>vizinho)
               vizinho=trade_type-1-2;
            else
               if((trade_type-1-1)>vizinho)
                  vizinho=trade_type-1-1;
               else
                  vizinho=trade_type-1;
         if((trade_type-1+3)<limite)
            limite=trade_type-1+3;
         else
            if((trade_type-1+2)<limite)
              {
               limite=trade_type-1+2;
               vizinho--;
              }
            else
               if((trade_type-1+1)<limite)
                 {
                  limite=trade_type-1+1;
                  vizinho-=2;
                 }
               else
                 {
                  limite=trade_type-1;
                  vizinho-=3;
                 }
        }
      for(; vizinho<=limite; vizinho++)
        {
         analisado=MathAbs((m_now[prof_cube-1][n_candles-1]-super_brain[vizinho][prof_cube-1][n_candles-1])*m_erro_brain[vizinho][prof_cube-1][n_candles-1]);
         for(j=0; j<num_candles; j++)
           {
            for(i=0; i<prof_cube; i++)
               for(w=0; w<n_candles; w++)
                  if(MathAbs((m_now[i][w]-super_brain[vizinho][i][w])*m_erro_brain[vizinho][i][w])<=analisado)
                    {
                     if(analisados[i][w]<1)
                       {
                        analisado=MathAbs((m_now[i][w]-super_brain[vizinho][i][w])*m_erro_brain[vizinho][i][w]);
                        ind[0]=i;
                        ind[1]=w;
                       }
                    }
            //os minimos precisam ser afastados o suficiente para aumentar a distancia mais do que os maximos diminuiram
            if(ind[0]!=-1)
              {
               double temp_err=m_e_temp_brain[vizinho][ind[0]][ind[1]];
               //m_erro_brain[trade_type-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);
               super_brain[vizinho][ind[0]][ind[1]]-=MathPow((distancias[trade_type-1]+Vet_erro[trade_type-1])/(distancias[vizinho]+Vet_erro[vizinho]),2)*parametrizadores[0]*2*fator_de_afastamento*(m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//36
               //m_erro_brain[trade_type-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]+0.000001*Min_Val_Neg);
               m_erro_brain[vizinho][ind[0]][ind[1]]=0.01*m_erro_brain[vizinho][ind[0]][ind[1]]+0.99*temp_err;
               m_erro_brain[vizinho][ind[0]][ind[1]]=Ativacao_erro(m_erro_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(m_erro_brain[trade_type-1][ind[0]][ind[1]],2),0);
               super_brain[vizinho][ind[0]][ind[1]]=Ativacao(super_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(super_brain[trade_type-1][ind[0]][ind[1]],16*Min_Val_Neg),-16*Min_Val_Neg);
               analisados[ind[0]][ind[1]]+=1;//ativado anti repeticao em loss
              }
            int a=0;
            int b=0;
            for(a=0; a<n_candles; a++)
              {
               for(b=0; b<prof_cube ; b++)
                 {
                  if(analisados[b][a]==0)
                     break;
                 }

              }
            if(a!=n_candles)
               analisado=MathAbs((m_now[b][a]-super_brain[vizinho][b][a])*m_erro_brain[vizinho][b][a]);
            else
               break;
            ind[0]=-1;
            ind[1]=-1;
           }
        }
     }
   else
      if(loss_gain==1)//gain
        {
         //afasta  os mais distantes
         vizinho=0;//0;
         limite=(n_holes/2)-1;//n_holes/2;
         if(trade_type-1>=(n_holes/2))
           {
            vizinho=n_holes/2;//n_holes/2;
            limite=n_holes-1;//n_holes;
           }
         vizinho=trade_type-1;
         limite=vizinho;
         for(; vizinho<=limite; vizinho++)
           {
            analisado=MathAbs((m_now[0][0]-super_brain[vizinho][0][0])*m_erro_brain[vizinho][0][0]);
            for(j=0; j<num_candles; j++)
              {
               for(i=0; i<prof_cube; i++)
                  for(w=0; w<n_candles; w++)
                     if(MathAbs((m_now[i][w]-super_brain[vizinho][i][w])*m_erro_brain[vizinho][i][w])>=analisado)
                       {
                        if(analisados[i][w]<1)
                          {
                           analisado=MathAbs((m_now[i][w]-super_brain[vizinho][i][w])*m_erro_brain[vizinho][i][w]);
                           ind[0]=i;
                           ind[1]=w;
                          }
                       }
               if(ind[0]!=-1)
                 {
                  //super_brain[vizinho][ind[0]][ind[1]]=Ativacao(super_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(super_brain[vizinho][ind[0]][ind[1]],20*Min_Val_Neg),-20*Min_Val_Neg);
                  double temp_err=m_erro_brain[vizinho][ind[0]][ind[1]];
                  m_e_temp_brain[vizinho][ind[0]][ind[1]]=0.2*temp_err+0.8*m_e_temp_brain[vizinho][ind[0]][ind[1]];
                  //m_erro_brain[vizinho][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]]);
                  super_brain[vizinho][ind[0]][ind[1]]-=MathPow((distancias[trade_type-1]+Vet_erro[trade_type-1])/(distancias[vizinho]+Vet_erro[vizinho]),2)*parametrizadores[0]*fator_de_afastamento*(m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//36 - +232.3//30 -100
                  //m_erro_brain[vizinho][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]]+0.000001*Min_Val_Neg);
                  //m_erro_brain[vizinho][ind[0]][ind[1]]=0.2*m_erro_brain[vizinho][ind[0]][ind[1]]+0.8*temp_err;
                  m_erro_brain[vizinho][ind[0]][ind[1]]+=(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;
                  m_erro_brain[vizinho][ind[0]][ind[1]]=Ativacao_erro(m_erro_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(m_erro_brain[vizinho][ind[0]][ind[1]],2),0);
                  //if(m_erro_brain[vizinho][ind[0]][ind[1]]<=0.001*Min_Val_Neg)
                  //  m_erro_brain[vizinho][ind[0]][ind[1]]=(0.005*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//Para a reducao não zerar m_erro
                  analisados[ind[0]][ind[1]]+=1;
                  super_brain[vizinho][ind[0]][ind[1]]=Ativacao(super_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(super_brain[vizinho][ind[0]][ind[1]],16*Min_Val_Neg),-16*Min_Val_Neg);
                 }
               int a=0;
               int b=0;
               for(a=0; a<n_candles; a++)
                 {

                  for(b=0; b<prof_cube ; b++)
                    {
                     if(analisados[b][a]==0)
                        break;
                    }

                 }
               if(a!=n_candles)
                  analisado=MathAbs((m_now[b][a]-super_brain[vizinho][b][a])*m_erro_brain[vizinho][b][a]);
               else
                  break;
               ind[0]=-1;
               ind[1]=-1;
              }
           }
        }
      else
         if(loss_gain==2)//gain trade tipe reverso
           {
            vizinho=0;//trade_type_reverso-1;//0;
            limite=(n_holes/2)-1;//trade_type_reverso;//n_holes/2;
            if(trade_type_reverso-1>=n_holes/2)
              {
               vizinho=n_holes/2;//trade_type_reverso-1;//n_holes/2;
               limite=n_holes-1;//trade_type_reverso;//n_holes;
              }
            vizinho=trade_type_reverso-1;
            limite=vizinho;
            //afasta  os mais distantes
            for(; vizinho<=limite; vizinho++)
              {
               analisado=MathAbs((m_now[0][0]-super_brain[vizinho][0][0])*m_erro_brain[vizinho][0][0]);
               for(j=0; j<num_candles; j++)
                 {
                  for(i=0; i<prof_cube; i++)
                     for(w=0; w<n_candles; w++)
                        if(MathAbs((m_now[i][w]-super_brain[vizinho][i][w])*m_erro_brain[vizinho][i][w])>=analisado)
                          {
                           if(analisados[i][w]==0)
                             {
                              analisado=MathAbs((m_now[i][w]-super_brain[vizinho][i][w])*m_erro_brain[vizinho][i][w]);
                              ind[0]=i;
                              ind[1]=w;
                             }
                          }

                  if(ind[0]!=-1)
                    {
                     //super_brain[vizinho][ind[0]][ind[1]]=Ativacao(super_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(super_brain[vizinho][ind[0]][ind[1]],10*Min_Val_Neg),-10*Min_Val_Neg);
                     double temp_err=m_erro_brain[vizinho][ind[0]][ind[1]];
                     m_e_temp_brain[vizinho][ind[0]][ind[1]]=0.2*temp_err+0.8*m_e_temp_brain[vizinho][ind[0]][ind[1]];
                     //m_erro_brain[vizinho][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]]);
                     super_brain[vizinho][ind[0]][ind[1]]-=MathPow((distancias[trade_type_reverso-1]+Vet_erro[trade_type_reverso-1])/(distancias[vizinho]+Vet_erro[vizinho]),2)*parametrizadores[0]*fator_de_afastamento*(m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//36 - +232.3//30 -100
                     //m_erro_brain[vizinho][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]]+0.000001*Min_Val_Neg);
                     //m_erro_brain[vizinho][ind[0]][ind[1]]=0.1*m_erro_brain[vizinho][ind[0]][ind[1]]+0.9*temp_err;
                     m_erro_brain[vizinho][ind[0]][ind[1]]+=(0.0005*(16383.5-MathRand())/16383.5)*Min_Val_Neg;
                     m_erro_brain[vizinho][ind[0]][ind[1]]=Ativacao_erro(m_erro_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(m_erro_brain[vizinho][ind[0]][ind[1]],2),0);
                     //m_e_temp_brain[vizinho][ind[0]][ind[1]]=temp_err;
                     //if(m_erro_brain[vizinho][ind[0]][ind[1]]<=0.001*Min_Val_Neg)
                     //   m_erro_brain[vizinho][ind[0]][ind[1]]=(0.005*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//Para a reducao não zerar m_erro
                     analisados[ind[0]][ind[1]]=1;
                     super_brain[vizinho][ind[0]][ind[1]]=Ativacao(super_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(super_brain[trade_type-1][ind[0]][ind[1]],16*Min_Val_Neg),-16*Min_Val_Neg);
                    }
                  int a=0;
                  int b=0;
                  for(a=0; a<n_candles; a++)
                    {

                     for(b=0; b<prof_cube ; b++)
                       {
                        if(analisados[b][a]==0)
                           break;
                       }

                    }
                  if(a!=n_candles)
                     analisado=MathAbs((m_now[b][a]-super_brain[vizinho][b][a])*m_erro_brain[vizinho][b][a]);
                  else
                     break;
                  ind[0]=-1;
                  ind[1]=-1;
                 }
              }
           }
         else
            if(loss_gain==3)//loss vizinhanca - afasta os mais proximos
              {
               analisado=MathAbs((m_now[0][0]-super_brain[trade_type_reverso-1][0][0])*m_erro_brain[trade_type_reverso-1][0][0]);
               for(j=0; j<num_candles; j++)
                 {
                  for(i=0; i<prof_cube; i++)
                     for(w=0; w<n_candles; w++)
                        if(MathAbs((m_now[i][w]-super_brain[trade_type_reverso-1][i][w])*m_erro_brain[trade_type_reverso-1][i][w])<analisado)
                          {
                           if(analisados[i][w]<1)
                             {
                              analisado=MathAbs((m_now[i][w]-super_brain[trade_type_reverso-1][i][w])*m_erro_brain[trade_type_reverso-1][i][w]);//m_erro_w_h_1[i][w];
                              ind[0]=i;
                              ind[1]=w;
                             }
                          }
                  //os minimos precisam ser afastados o suficiente para aumentar a distancia mais do que os maximos diminuiram


                  if(ind[0]!=-1)
                    {
                     double temp_err=m_e_temp_brain[trade_type_reverso-1][ind[0]][ind[1]];
                     //m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]]);
                     super_brain[trade_type_reverso-1][ind[0]][ind[1]]-=parametrizadores[0]*0.2*fator_de_afastamento*(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//38//m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]]+0.000001*Min_Val_Neg);
                     m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=0.02*m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]+0.98*temp_err;
                     m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=Ativacao_erro(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]);//MathMax(MathMin(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]],2),0);
                     //if(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]<=0.001*Min_Val_Neg)
                     //   m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=0.001*Min_Val_Neg;//Para a reducao não zerar m_erro
                     super_brain[trade_type_reverso-1][ind[0]][ind[1]]=Ativacao(super_brain[trade_type_reverso-1][ind[0]][ind[1]]);//MathMax(MathMin(super_brain[trade_type_reverso-1][ind[0]][ind[1]],16*Min_Val_Neg),-16*Min_Val_Neg);
                     analisados[ind[0]][ind[1]]+=1;//ativado anti repeticao em loss
                    }
                  int a=0;
                  int b=0;
                  for(a=0; a<n_candles; a++)
                    {

                     for(b=0; b<prof_cube ; b++)
                       {
                        if(analisados[b][a]==0)
                           break;
                       }

                    }
                  if(a!=n_candles)
                     analisado=MathAbs((m_now[b][a]-super_brain[trade_type_reverso-1][b][a])*m_erro_brain[trade_type_reverso-1][b][a]);
                  else
                     break;
                  ind[0]=-1;
                  ind[1]=-1;
                 }
              }
  }
//+------------------------------------------------------------------+
//| Aproxima candles dependendo de loss ou gain                                                                 |
//+------------------------------------------------------------------+
void aproximar_candles(int num_candles,double fator_de_aproximacao,int loss_gain)
  {
   num_candles=int(MathMin(num_candles,n_candles*prof_cube));
   int ind[2]= {-1,-1};
   int i=0;
   int j=0;
   int w=0;
   for(i=0; i<n_candles; i++)
      for(j=0; j<prof_cube; j++)
         analisados[j][i]=0;
   double analisado=0;//MathAbs((m_now[prof_cube-1][n_candles-1]-super_brain[trade_type-1][prof_cube-1][n_candles-1])*m_erro_brain[trade_type-1][prof_cube-1][n_candles-1]);
//aproximar os mais distantes

   if(loss_gain==0)//loss
     {
      analisado=MathAbs((m_now[prof_cube-1][n_candles-1]-super_brain[trade_type-1][prof_cube-1][n_candles-1])*m_erro_brain[trade_type-1][prof_cube-1][n_candles-1]);
      for(j=0; j<num_candles; j++)
        {
         for(i=0; i<prof_cube; i++)
            for(w=n_candles-1; w>=0; w--)
               if(MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w])>analisado)
                 {
                  if(analisados[i][w]==0)
                    {
                     analisado=MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w]);
                     ind[0]=i;
                     ind[1]=w;
                    }
                 }
         if(ind[0]!=-1)
           {
            double temp_err=m_e_temp_brain[trade_type-1][ind[0]][ind[1]];
            //m_erro_brain[trade_type-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);
            super_brain[trade_type-1][ind[0]][ind[1]]+=parametrizadores[0]*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//38
            //m_erro_brain[trade_type-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]-0.000000001*Min_Val_Neg);
            m_erro_brain[trade_type-1][ind[0]][ind[1]]=0.01*m_erro_brain[trade_type-1][ind[0]][ind[1]]+0.99*temp_err;
            //funcao de ativacao
            m_erro_brain[trade_type-1][ind[0]][ind[1]]=Ativacao_erro(m_erro_brain[trade_type-1][ind[0]][ind[1]],ind[0],ind[1]);//MathMax(MathMin(m_erro_brain[trade_type-1][ind[0]][ind[1]],2),0);
            //if(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]<=0.001*Min_Val_Neg)
            //  m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=0.001*Min_Val_Neg;//Para a reducao não zerar m_erro
            super_brain[trade_type-1][ind[0]][ind[1]]=Ativacao(super_brain[trade_type-1][ind[0]][ind[1]]);//MathMax(MathMin(super_brain[trade_type-1][ind[0]][ind[1]],16*Min_Val_Neg),-16*Min_Val_Neg);
            analisados[ind[0]][ind[1]]=1;//ativado sistema anti repeticao em loss
           }
         int a=0;
         int b=0;
         for(a=0; a<n_candles; a++)
           {

            for(b=0; b<prof_cube ; b++)
              {
               if(analisados[b][a]==0)
                  break;
              }

           }
         if(a!=n_candles)
            analisado=MathAbs((m_now[b][a]-super_brain[trade_type-1][b][a])*m_erro_brain[trade_type-1][b][a]);
         else
            break;
         ind[0]=-1;
         ind[1]=-1;

        }
     }
   else
      if(loss_gain==1)//gain
        {
         int vizinho=0;//trade_type-1;//0;
         int limite=(n_holes/2)-1;//trade_type;//n_holes/2;
         if(trade_type-1>=n_holes/2)
           {
            vizinho=n_holes/2;//trade_type-1;//n_holes/2;
            limite=n_holes-1;//trade_type;//n_holes;
           }
         if(treinamento_ativo!=0)   //operacao n foi real
           {
            if((trade_type-1-3)>vizinho)
               vizinho=trade_type-1-3;
            else
               if((trade_type-1-2)>vizinho)
                  vizinho=trade_type-1-2;
               else
                  if((trade_type-1-1)>vizinho)
                     vizinho=trade_type-1-1;
                  else
                     vizinho=trade_type-1;
            if((trade_type-1+3)<limite)
              {
               limite=trade_type-1+3;
              }
            else
               if((trade_type-1+2)<limite)
                 {
                  limite=trade_type-1+2;
                  vizinho-=1;
                 }
               else
                  if((trade_type-1+1)<limite)
                    {
                     limite=trade_type-1+1;
                     vizinho-=2;
                    }
                  else
                    {
                     limite=trade_type-1;
                     vizinho-=3;
                    }
           }
         for(; vizinho<=limite; vizinho++)
           {
            //aproximar os menos distantes
            analisado=MathAbs((m_now[prof_cube-1][n_candles-1]-super_brain[vizinho][prof_cube-1][n_candles-1])*m_erro_brain[vizinho][prof_cube-1][n_candles-1]);
            for(j=0; j<num_candles; j++)
              {
               for(i=0; i<prof_cube; i++)
                  for(w=0; w<n_candles; w++)
                     if(MathAbs((m_now[i][w]-super_brain[vizinho][i][w])*m_erro_brain[vizinho][i][w])<analisado && analisados[i][w]==0)
                       {
                        analisado=MathAbs((m_now[i][w]-super_brain[vizinho][i][w])*m_erro_brain[vizinho][i][w]);
                        ind[0]=i;
                        ind[1]=w;
                       }
               if(ind[0]!=-1)
                 {
                  double temp_err=m_erro_brain[vizinho][ind[0]][ind[1]];
                  m_e_temp_brain[vizinho][ind[0]][ind[1]]=0.2*temp_err+0.8*m_e_temp_brain[vizinho][ind[0]][ind[1]];
                  //m_erro_brain[vizinho][ind[0]][ind[1]]*=m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]];
                  super_brain[vizinho][ind[0]][ind[1]]+=MathPow((distancias[trade_type-1]+Vet_erro[trade_type-1])/(distancias[vizinho]+Vet_erro[vizinho]),2)*parametrizadores[0]*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]]);//44//48 -300
                  //m_erro_brain[vizinho][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]]+0.000002*Min_Val_Neg);
                  m_erro_brain[vizinho][ind[0]][ind[1]]+=(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;
                  //funcao de ativacao
                  super_brain[vizinho][ind[0]][ind[1]]=Ativacao(super_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(super_brain[vizinho][ind[0]][ind[1]],16*Min_Val_Neg),-16*Min_Val_Neg);
                  m_erro_brain[vizinho][ind[0]][ind[1]]=Ativacao_erro(m_erro_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(m_erro_brain[vizinho][ind[0]][ind[1]],2),0);
                  //Para não re-trabalhar valores que já foram mexidos
                  //if(m_erro_brain[vizinho][ind[0]][ind[1]]<=0.001*Min_Val_Neg)
                  //   m_erro_brain[vizinho][ind[0]][ind[1]]=(0.005*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//Para a reducao não zerar m_erro
                  analisados[ind[0]][ind[1]]=1;
                  super_brain[vizinho][ind[0]][ind[1]]=Ativacao(super_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(super_brain[vizinho][ind[0]][ind[1]],16*Min_Val_Neg),-16*Min_Val_Neg);
                 }
               int a=0;
               int b=0;
               for(a=0; a<n_candles; a++)
                 {
                  for(b=0; b<prof_cube ; b++)
                    {
                     if(analisados[b][a]==0)
                        break;
                    }
                 }
               if(a!=n_candles)
                  analisado=MathAbs((m_now[b][a]-super_brain[vizinho][b][a])*m_erro_brain[vizinho][b][a]);
               else
                  break;
               ind[0]=-1;
               ind[1]=-1;
              }
           }
        }
      else
         if(loss_gain==2)//gain reverso
           {
            int vizinho=0;//trade_type_reverso-1;
            int limite=(n_holes/2)-1;//trade_type_reverso;//n_holes/2;
            if(trade_type_reverso-1>=n_holes/2)
              {
               vizinho=n_holes/2;//trade_type_reverso-1;//n_holes/2;
               limite=n_holes-1;//trade_type_reverso;//n_holes;
              }
            if(treinamento_ativo!=0)   //operacao n foi real
              {
               if((trade_type-1-3)>vizinho)
                  vizinho=trade_type-1-3;
               else
                  if((trade_type-1-2)>vizinho)
                     vizinho=trade_type-1-2;
                  else
                     if((trade_type-1-1)>vizinho)
                        vizinho=trade_type-1-1;
                     else
                        vizinho=trade_type-1;
               if((trade_type-1+3)<limite)
                  limite=trade_type-1+3;
               else
                  if((trade_type-1+2)<limite)
                    {
                     limite=trade_type-1+2;
                     vizinho--;
                    }
                  else
                     if((trade_type-1+1)<limite)
                       {
                        limite=trade_type-1+1;
                        vizinho-=2;
                       }
                     else
                       {
                        limite=trade_type-1;
                        vizinho-=3;
                       }
              }
            //aproximar os menos distantes
            for(; vizinho<=limite; vizinho++)
              {
               analisado=MathAbs((m_now[prof_cube-1][n_candles-1]-super_brain[vizinho][prof_cube-1][n_candles-1])*m_erro_brain[vizinho][prof_cube-1][n_candles-1]);
               for(j=0; j<num_candles; j++)
                 {
                  for(i=0; i<prof_cube; i++)
                     for(w=0; w<n_candles; w++)
                        if(MathAbs((m_now[i][w]-super_brain[vizinho][i][w])*m_erro_brain[vizinho][i][w])<analisado && analisados[i][w]==0)
                          {
                           analisado=MathAbs((m_now[i][w]-super_brain[vizinho][i][w])*m_erro_brain[vizinho][i][w]);
                           ind[0]=i;
                           ind[1]=w;
                          }
                  if(ind[0]!=-1)
                    {
                     double temp_err=m_erro_brain[vizinho][ind[0]][ind[1]];
                     m_e_temp_brain[vizinho][ind[0]][ind[1]]=0.2*temp_err+0.8*m_e_temp_brain[vizinho][ind[0]][ind[1]];
                     super_brain[vizinho][ind[0]][ind[1]]+=MathPow((distancias[trade_type_reverso-1]+Vet_erro[trade_type_reverso-1])/(distancias[vizinho]+Vet_erro[vizinho]),2)*parametrizadores[0]*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[vizinho][ind[0]][ind[1]]);//44//48 -300
                     m_erro_brain[vizinho][ind[0]][ind[1]]+=(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;
                     //funcao de ativacao
                     m_erro_brain[vizinho][ind[0]][ind[1]]=Ativacao_erro(m_erro_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(m_erro_brain[vizinho][ind[0]][ind[1]],2),0);
                     super_brain[vizinho][ind[0]][ind[1]]=Ativacao(super_brain[vizinho][ind[0]][ind[1]]);//MathMax(MathMin(super_brain[vizinho][ind[0]][ind[1]],16*Min_Val_Neg),-16*Min_Val_Neg);
                     analisados[ind[0]][ind[1]]=1;
                    }
                  int a=0;
                  int b=0;
                  for(a=0; a<n_candles; a++)
                    {

                     for(b=0; b<prof_cube ; b++)
                       {
                        if(analisados[b][a]==0)
                           break;
                       }

                    }
                  if(a!=n_candles)
                     analisado=MathAbs((m_now[b][a]-super_brain[vizinho][b][a])*m_erro_brain[vizinho][b][a]);
                  else
                     break;
                  ind[0]=-1;
                  ind[1]=-1;
                 }
              }
           }
         else
            if(loss_gain==3)//loss reverso aprox os distantes
              {
               analisado=MathAbs((m_now[0][0]-super_brain[trade_type_reverso-1][0][0])*m_erro_brain[trade_type_reverso-1][0][0]);
               for(j=0; j<num_candles; j++)
                 {
                  for(i=0; i<prof_cube; i++)
                     for(w=n_candles-1; w>=0; w--)
                        if(MathAbs((m_now[i][w]-super_brain[trade_type_reverso-1][i][w])*m_erro_brain[trade_type_reverso-1][i][w])>analisado)
                          {
                           if(analisados[i][w]==0)
                             {
                              analisado=MathAbs((m_now[i][w]-super_brain[trade_type_reverso-1][i][w])*m_erro_brain[trade_type_reverso-1][i][w]);
                              ind[0]=i;
                              ind[1]=w;
                             }
                          }
                  if(ind[0]!=-1)
                    {
                     double temp_err=m_e_temp_brain[trade_type_reverso-1][ind[0]][ind[1]];
                     //m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]]);
                     super_brain[trade_type_reverso-1][ind[0]][ind[1]]+=parametrizadores[0]*0.2*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//38

                     //m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type_reverso-1][ind[0]][ind[1]]+0.000001*Min_Val_Neg);
                     m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=0.98*temp_err+0.02*m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]];
                     //funcao de ativacao
                     m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=Ativacao_erro(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]);//MathMax(MathMin(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]],2),0);
                     //if(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]<=0.001*Min_Val_Neg)
                     //   m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=(0.005*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//Para a reducao não zerar m_erro
                     super_brain[trade_type_reverso-1][ind[0]][ind[1]]=Ativacao(super_brain[trade_type_reverso-1][ind[0]][ind[1]]);//(MathMax(MathMin(super_brain[trade_type_reverso-1][ind[0]][ind[1]],16*Min_Val_Neg),-16*Min_Val_Neg);
                     analisados[ind[0]][ind[1]]=1;//ativado sistema anti repeticao em loss
                    }
                  int a=0;
                  int b=0;
                  for(a=0; a<n_candles; a++)
                    {
                     if(analisados[b][a]==0)
                        break;
                     for(b=0; b<prof_cube ; b++)
                       {

                       }
                    }
                  if(a!=n_candles)
                     analisado=MathAbs((m_now[b][a]-super_brain[trade_type_reverso-1][b][a])*m_erro_brain[trade_type_reverso-1][b][a]);
                  else
                     break;
                  ind[0]=-1;
                  ind[1]=-1;
                 }
              }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Ativacao(double in,int i=0, int j=0)
  {
   if(in>=40*Min_Val_Neg)
      in=40*Min_Val_Neg;
   else
      if(in>30*Min_Val_Neg)
         in=30*Min_Val_Neg+(in-30*Min_Val_Neg)/8;
   if(in<-40*Min_Val_Neg)
      in=-40*Min_Val_Neg;
   else
      if(in<-30*Min_Val_Neg)
         in= -30*Min_Val_Neg+(in-30*Min_Val_Neg)/8;
   return in;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Ativacao_erro(double in,int i=0,int j=0)
  {
   if(in<=0.85)
      in=0.85;
   else
      if(in<=0.9)
         in=0.9+(in-0.9)/10;
      else
         if(in>1.25)
            in=1.25;
         else
            if(in>=1.12)
               in= 1.12+(in-1.12)/10;

   return in;
  }
//+------------------------------------------------------------------+
//|  Linearização ponderada de 5 medias para calculo da tendencia                                                                |
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
   double m_tend_close[5*n_candles];

   if(CopyBuffer(m_handle_tendency,0,0,5*n_candles,m_tend_close)==-1)
     {
      ArrayFill(m_tend_close,0,n_candles,0);
      printf("problemas com o indicador");
      m_handle_tendency=iMA(simbolo,_Period,21,0,MODE_EMA,PRICE_CLOSE);
     }
   m_x=2*(5*n_candles-2)+1.5*(int(0.8*5*n_candles))+1*(int(0.7*5*n_candles))+1*int(0.6*5*n_candles)+int(0.05*5*n_candles);
   m_x/=6.5;
   m_y=2*m_tend_close[n_candles-2]+1.5*m_tend_close[int(0.8*n_candles)]+1*m_tend_close[int(0.7*n_candles)]+1*m_tend_close[int(0.6*n_candles)]+m_tend_close[int(0.05*n_candles)];
   m_y/=6.5;
   b_e[0]=2*((5*n_candles-2))*(m_tend_close[5*n_candles-2]-m_y);
   b_e[1]=1.5*(int(0.8*5*n_candles))*(m_tend_close[int(0.8*5*n_candles)]-m_y);
   b_e[2]=1*(int(0.7*5*n_candles))*(m_tend_close[int(0.7*5*n_candles)]-m_y);
   b_e[3]=(int(0.6*5*n_candles))*(m_tend_close[int(0.6*5*n_candles)]-m_y);
   b_e[4]=(int(0.05*5*n_candles))*(m_tend_close[int(0.05*5*n_candles)]-m_y);
   b_l[0]=2*((5*n_candles-2))*(5*n_candles-1-m_x);
   b_l[1]=1.5*(int(0.8*5*n_candles))*(int(0.8*5*n_candles)-m_x);
   b_l[2]=1*(int(0.7*5*n_candles))*(int(0.7*5*n_candles)-m_x);
   b_l[3]=(int(0.6*5*n_candles))*(int(0.6*5*n_candles)-m_x);
   b_l[4]=(int(0.05*5*n_candles))*(int(0.05*5*n_candles)-m_x);
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

//+------------------------------------------------------------------+
void normalizar_m_erros()
  {
   /*double media_erro=0;
   double max_erro=0;
   int i,j,k;
   for(i=n_holes-1; i>=0; i--)
      for(j=n_candles-1; j>=0; j--) //normalizar para cada hole
         for(k=prof_cube-1; k>=0; k--)
           {
            max_erro=MathMax(m_erro_brain[i][k][j],max_erro);
            media_erro+=MathAbs(m_erro_brain[i][k][j])/(prof_cube*n_candles*n_holes);
           }
   for(i=n_holes-1; i>=0; i--)
      for(k=prof_cube-1; k>=0; k--)
         for(j=n_candles-1; j>=0; j--)
           {
            m_erro_brain[i][k][j]/=media_erro;
            m_erro_brain[i][k][j]=Ativacao_erro(m_erro_brain[i][k][j]);
           }

   media_erro=0;
   */
  }

//+------------------------------------------------------------------+
//---funcao para calcular a proxima resistencia
//---
double next_resist()
  {
   CopyClose(simbolo,_Period,0,6*n_candles,large_close);
   CopyOpen(simbolo,_Period,0,6*n_candles,large_open);
   double max0=large_close[0];
   double max1=large_close[1];
   double max2=100000*Min_Val_Neg;
   double max3=large_close[3];
   double max4=large_close[4];
   double max5=large_close[5];
   int imax0=0;
   int imax1=1;
   int imax2=2;
   int imax3=3;
   int imax4=4;
   bool valido=false;
   while(imax4<5*n_candles)
     {
      if(MathMax(large_close[imax0],large_open[imax0])<MathMax(large_close[imax2],large_open[imax1])&&MathMax(large_close[imax1],large_open[imax1])<=MathMax(large_close[imax2],large_open[imax2])&&MathMax(large_close[imax3],large_open[imax3])<=MathMax(large_close[imax2],large_open[imax2])&&MathMax(large_close[imax4],large_open[imax4])<MathMax(large_close[imax2],large_open[imax2]))
        {
         if(MathMax(large_close[imax2],large_open[imax2])>large_close[ArraySize(large_close)-1])
           {
            valido=true;
            if(MathMax(large_close[imax2],large_open[imax2])<max2)
               max2=MathMax(large_close[imax2],large_open[imax2]);
           }
        }
      imax0++;
      imax1++;
      imax2++;
      imax3++;
      imax4++;
     }
   if(valido)
     {
      return max2;
      Comment(" resistencia: "+ string(max2)+"\n suporte: "+string(next_suporte()));
     }
   return 100000*Min_Val_Neg;
  }
//+------------------------------------------------------------------+
//---funcao para calcular o proximo suporte
//---
double next_suporte()
  {
   CopyClose(simbolo,_Period,0,6*n_candles,large_close);
   CopyOpen(simbolo,_Period,0,6*n_candles,large_open);
   double min0=large_close[0];
   double min1=large_close[1];
   double min2=0;
   double min3=large_close[3];
   double min4=large_close[4];
   int imin0=0;
   int imin1=1;
   int imin2=2;
   int imin3=3;
   int imin4=4;
   bool valido=false;
   while(imin4<5*n_candles)
     {
      if(MathMin(large_close[imin0],large_open[imin0])>MathMin(large_close[imin2],large_open[imin2])&&MathMin(large_close[imin1],large_open[imin1])>=MathMin(large_close[imin2],large_open[imin2])&&MathMin(large_close[imin3],large_open[imin3])>=MathMin(large_close[imin2],large_open[imin2])&&MathMin(large_close[imin4],large_open[imin4])>MathMin(large_close[imin2],large_open[imin2]))
        {
         if(MathMin(large_close[imin2],large_open[imin2])<large_close[ArraySize(large_close)-1])
           {
            valido=true;
            if(MathMin(large_close[imin2],large_open[imin2])>min2)
               min2=MathMin(large_close[imin2],large_open[imin2]);
           }
        }
      imin0++;
      imin1++;
      imin2++;
      imin3++;
      imin4++;
     }
   if(valido)
      return min2;
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int operar_green_hammer()
  {
   int retorno =0;
   if(close[n_candles-2]>=(high[n_candles-2]-Min_Val_Neg)&&MathAbs(close[n_candles-2]-open[n_candles-2])*2.5<=(MathMin(open[n_candles-2],close[n_candles-2])-low[n_candles-2]))
     {
      retorno=1;//martelinho vermelho
      if(close[n_candles-5]>close[n_candles-4])
        {
         retorno=2;
         if(close[n_candles-4]>close[n_candles-3])
           {
            retorno =3;
            if(close[n_candles-2]>open[n_candles-2])//martelinho verde
              {
               retorno=7;
              }
           }
        }
     }
   else
      if(open[n_candles-2]>=(high[n_candles-2]-Min_Val_Neg)&&MathAbs(open[n_candles-2]-close[n_candles-2])*2.5<=(MathMin(close[n_candles-2],open[n_candles-2])-low[n_candles-2]))
        {
         retorno =-1;
         if(close[n_candles-5]<close[n_candles-4])
           {
            retorno=-2;
            if(close[n_candles-4]<close[n_candles-3])
              {
               retorno=-3;
               if(close[n_candles-2]<open[n_candles-2])
                 {
                  retorno=-7;
                 }
              }
           }
        }
   return retorno;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Salvar_Matriz_csv(double &matriz[][prof_cube][n_candles],string path)
  {
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   string linha="";
   FileDelete(add,FILE_COMMON);
   int file_handle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_TXT);
   int j;
   int i;
   for(int w=0; w<n_holes; w++)
     {
      for(j=0; j<prof_cube; j++)
        {
         for(i=0; i<n_candles-1; i++)
           {
            linha+=DoubleToString(matriz[w][j][i],12);
            linha+=";";
           }
         //if(i==n_candles-1)
         linha+=DoubleToString(matriz[w][j][i],12);
         FileWrite(file_handle,linha);
         linha="";
        }
     }
   FileClose(file_handle);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
void ler_matriz_csv(double &Matriz[][prof_cube][n_candles],string path,bool tipo_erro)
  {
   uchar Symb[3];
   string Ativo;
   int i,j,w;
///Inicialização das matrizes erro e match aleatoriamente
   /*double matriz_ini_erro[n_holes][prof_cube][n_candles];
   ArrayInitialize(matriz_ini_erro,1);
   for(i=0; i<n_holes; i++)
     {
      for(j=0; j<prof_cube; j++)
        {
         for(w=0; w<n_candles; w++)
           {
            matriz_ini_erro[i][j][w]=(MathRand())/(2*16383.5);
            if(w==0)
              {
               w=0;
              }
           }
         w=0;
        }
      j=0;
     }
   double matriz_ini_match[n_holes][prof_cube][n_candles];
   ArrayInitialize(matriz_ini_match,10*Min_Val_Neg);
   for(i=0; i<n_holes; i++)
     {
      for(j=0; j<prof_cube; j++)
        {
         for(w=0; w<n_candles; w++)
           {
            matriz_ini_match[i][j][w]=8*((MathRand())/(2*16383.5));
           }
         w=0;
        }
      j=0;
     }*/
   double matriz_ini_match[n_holes][prof_cube][n_candles]= {{{15.079127709161,2.123232030856,5.309079518608,4.821629491345,2.908811821678,3.450043653474,5.458986058522,4.736206993524,5.668627884639,0.000501022251},{0.42348880676,-19.262332497096,4.401501238451,1.819107367905,2.624380798931,-8.824844386159,2.608334498808,4.058959494624,3.863962875191,6.803750041971},{-0.6015982909,2.154298689552,2.130674588924,2.716649185419,0.817173947828,1.155781779771,2.430065912736,8.436853942015,1.715881765812,-0.697881467456},{6.831654772547,-19.261917395589,4.234097618131,-9.089717675691,3.267828851563,3.36792587267,6.747080183531,3.315009013197,4.402193420235,2.157534919292},{-19.264047367757,-3.247484321119,-0.825885587164,-1.110145213526,0.621423077068,15.085312124577,3.018845268166,0.178660232341,10.721497557124,3.66056287},{6.581033820375,0.555951383348,0.286817050613,-0.529790884042,6.264638164393,6.909369243986,-0.069498344296,1.110811013891,14.82983927218,7.455144766526},{4.850492941883,-0.738782005281,-1.221587650863,-1.297051776455,-2.068601387198,13.73931291512,5.605555797923,5.643007913761,-2.185235254352,6.545470418514},{7.452175285749,13.330442337657,1.599870684005,1.234881275399,9.079518978081,15.074385041222,1.593047616995,13.35469050445,7.890076722042,8.104928727156},{1.876663114707,10.512578673848,1.88666766252,0.465875318595,1.173371058616,1.111249107224,0.781589670273,11.795809068524,7.339880997104,-0.301422359983},{9.213265007065,2.962100491748,2.880747652304,3.355986954539,2.889442610125,2.811966518584,2.806554300559,2.25208347013,2.443117433069,9.276622870775}},
        {{13.344873520454,3.158962565542,2.409972427034,1.656641733635,0.506076293327,0.661793068157,1.746017626089,2.443723531343,2.927455097229,-0.161489429073},{3.605626514088,3.193591978014,2.974262715851,2.380709063341,1.60792177066,0.880095819311,1.429857505191,2.061222110368,2.44195041926,2.848050011633},{2.062380266244,1.877664618004,1.202660642912,0.40658038451,-1.454161766768,-0.771079490706,-0.02958614206,0.514902247181,1.37408809049,-0.539874138472},{4.809078036827,4.198359164673,4.129644946612,3.781380562403,3.365925927279,2.933553154446,3.064204665289,3.51294771442,4.31401146455,3.578031117184},{5.503855326195,5.30559099585,-19.366160996116,4.731056484564,4.373939397327,4.412058264192,3.428489690972,3.326086171218,3.315011931912,3.196393774693},{0.16873973623,1.080064104168,-0.405980741725,-1.574371109212,-1.311266552633,-1.28225832792,0.891214160465,0.175983393231,-1.434439405725,-2.852336295512},{-0.498462050384,0.103266699863,-0.986442461235,-3.044334646734,-2.173591903519,-1.714537670757,-0.442931000785,-1.002459463244,-2.000467243421,-3.577897662261},{1.331861459772,2.499578086898,1.001440717744,0.999155442177,1.50102975597,1.00193795745,2.001719920765,1.146544949767,0.103440607926,0.495446433809},{-0.95890536391,-1.67978660433,-2.636568996013,-2.898429669413,-3.593461418872,-3.766349387879,-2.796389489405,-2.783675174172,-2.245330965811,-2.925579369311},{2.254781164056,2.694776758095,1.662548699376,4.423754926881,3.400975742184,3.271564450186,-19.267659874187,2.31812474383,2.131781150233,3.860360955287}},
        {{12.020449468655,0.07023369505,-0.255104467443,0.18693581779,-0.253648826956,-1.167551153926,-0.529999719635,-0.146225836367,0.471917959413,0.000286043759},{0.150713068642,0.485308591439,0.109423168399,-0.160277731431,0.010123955619,0.017217813661,-0.944243424378,-0.657160233562,-0.328261478911,0.706665536553},{-1.319415637946,-0.152509345275,-1.77532002734,-1.577287856844,-1.640246944771,-1.751684248572,-1.860951414546,-1.856158681072,-0.889158493756,0.547133117309},{1.400443219505,-20,1.425872942647,1.699879449164,1.092645096375,0.82233613501,0.43619635904,0.987691396201,1.765323695607,2.527850267266},{-1.823670222167,-0.762977027938,-0.734558291007,-0.59068848488,-0.579430777632,-0.507268525176,-0.537242288706,-0.573192136646,0.482887042945,-0.486926781688},{0.608286539425,0.187124686802,-0.091026936973,0.815553849621,-0.030210642761,-1.156561898935,0.041462957032,1.404351108186,2.166901784785,2.000593583694},{-1.003395903963,-1.284184326504,-1.854459570002,0.598828222767,-1.800226938158,-2.347941925447,-1.225842682959,-1.595507937853,-1.90278292121,-1.897027867287},{1.911680261855,1.77978774739,0.999697033101,2.328004576636,1.480459183174,1.872261663587,1.139235028345,1.230940471432,2.779806651529,2.611877425667},{5.621036883286,1.872221423153,1.588213267592,1.850029612632,1.692047594487,1.607516526529,1.264388080626,1.847748744354,2.015160889222,-19.169329578284},{4.111220065776,2.791352287853,2.874827208435,2.840934462886,2.776403544336,3.325226331239,2.672146170308,4.009894939205,2.98448086467,2.821526589535}},
        {{15.063520275834,1.732066811093,1.466537002303,3.54004086517,-7.647678651282,2.498927991294,13.742559786367,2.01743695869,1.315926053286,0.001073529601},{-1.424898948283,-19.222610788417,-19.268792229209,2.67122683319,7.18401359576,-0.145541460091,8.632319180528,1.112497366627,1.632875773079,1.666497487799},{-4.73766788905,-0.159574809956,-1.579323344467,1.123541330279,-2.736315715016,-0.444316021127,0.728094667937,3.454162722628,0.673328040486,14.402413971768},{-5.490287030422,2.73166683212,2.401143980528,1.421535621344,-19.316062130643,1.467304325082,2.857729337428,0.814265986049,5.551113077409,3.356239106847},{1.089377767445,1.42478506135,0.347554824509,-1.092686070282,4.040517358607,2.360644484743,2.185894174007,-0.581825527521,2.020992707644,-5.539643128891},{11.877994715614,4.999465634854,5.277696862473,-0.498906809081,1.312057622031,0.081937705869,2.134854977294,-0.513530554942,5.176110786706,-2.157897180526},{-1.574824957256,4.458782063079,-0.501037944023,-1.040238395127,-1.055579760297,4.341652711506,-0.42025677983,0.834970210846,13.543267296028,13.597534127283},{5.893837423878,3.224129164423,2.094334917327,1.745204116925,1.254589806597,2.217723351685,2.35157962849,1.283033478939,0.958824765333,0.000062024091},{0.22195384184,0.433583180999,5.369763104824,5.512257277253,4.124822110166,4.972831585084,5.182334523087,0.532717966153,6.06934048459,-0.685823369414},{7.50258022012,1.740830690945,1.794182881385,2.17918807201,2.77338449862,3.689421894008,3.265689471349,2.004198690686,2.690582792604,1.81824733281}},
        {{1.909871533251,0.63398278609,0.985257332558,0.227952684024,0.30200203494,0.586654605956,2.060657624746,0.36974165226,2.309605684702,0.864148205684},{0.976370535822,4.865714319304,0.709378846711,0.821681917494,-19.343723151273,0.343691737725,0.541684024562,15.014943172459,1.557119814924,2.388280769068},{-0.458821802611,-0.365715626395,-0.626850753046,-0.730295191508,-1.18493681394,-0.895071020929,-0.663557450596,-0.392118511965,0.739737229126,1.998476336713},{2.096388240946,2.311540342185,1.70086483737,-3.041183517599,1.589556012654,-19.238735525446,1.809785663481,2.33841091639,-1.29167626927,3.840887535632},{-0.338280710558,-1.848319436261,0.006287294623,0.209976830305,0.388622407161,-0.023299023358,0.167919172516,0.23150646419,2.573579324377,0.882623634767},{3.15864675109,0.997950429733,3.132407012733,0.601762938699,3.628424392148,3.299248378401,3.495277639884,-1.00146513718,1.002928413717,1.492356694737},{8.651597860836,2.761270425968,-0.499028118134,7.746915631685,9.104070748483,2.562336952554,2.421096448102,2.836136222507,2.259760988847,3.324301623948},{1.829729705526,5.039569379855,3.014117112523,1.000311736082,2.000016647391,5.025013759501,0.989468992168,2.476630031316,5.023641564941,-1.276987153475},{2.138819285641,0.129162052297,0.738343581887,2.285301491407,0.637577068808,-0.427553926652,2.477866122542,-0.978359096878,3.412304852053,-0.858652161858},{-2.401471773831,1.50102850583,5.929776552964,2.499444493926,-0.016798291556,6.136332361782,1.986959019471,9.481813362775,3.997076497925,5.61709781671}},
        {{-0.07020858933,3.871403668558,-1.367676305733,-7.737067849085,-0.968345898501,-19.277609305986,-1.801926763153,-9.655741874491,5.261481741997,7.543672898898},{-11.878523273395,2.064663614687,3.839065639131,1.293450456594,-1.330348605573,-1.983841693905,-5.810524536924,-0.1339777745,-2.11711877903,4.080120851147},{-3.159066961339,-19.254502632014,-0.976069668646,-19.255444580832,-4.08088667988,-3.619186574483,-8.227017340449,4.065098877662,-3.508096165133,-1.338294073874},{5.609348501752,-0.336023161878,3.559108198521,3.280569026867,3.69938357375,0.378304129029,-19.246895685073,3.945705658605,0.742046820007,1.425662449986},{-3.409855959867,-3.412706263336,0.322748259609,-0.976327442223,-19.372042692505,2.684500530209,-5.406645456009,1.240441116665,-19.27828393582,14.156806786267},{0.638825762768,0.500427176274,-0.500281323076,8.154841553045,12.820411717183,8.170037900502,1.101265021513,14.402910887296,12.629336977843,9.646499601682},{-0.999793476175,-1.003022825542,-0.044675254016,8.918086144293,0.20803659956,7.054215231036,2.065257884829,-0.475988397307,-1.176170877931,-1.338322342279},{0.618190533734,1.55115194558,1.193561815565,1.926223940154,1.277749759712,8.680948133077,2.040718802083,1.829650907338,1.001093356529,1.758947868278},{8.11323961126,7.717760710858,1.844791204267,1.491081956553,1.349239094854,8.536346692837,2.365869783499,3.736167233581,3.244836856041,14.667772464875},{3.072946503701,3.922572567016,3.861781846507,3.045648574249,2.998946149566,9.53097456611,3.002192113603,12.981348701395,2.500916300699,-19.240035797537}},
        {{-0.325226075379,-1.633775576714,-0.821057097739,-1.123153796936,-0.879062026808,-0.561087786436,-0.653518604707,-0.324322231667,-0.060547199043,-0.000000030971},{-2.27019169718,-2.587460022285,-1.930272945581,-1.360622453105,-2.6557240958,-1.316307357809,-0.75660305799,-0.622889532843,-0.101744176064,-0.728600312357},{-2.940085788336,-3.259563879342,-4.453640576311,-2.206064474145,-1.853821833211,-1.416211942817,-4.267105563648,-2.980341846569,-0.438282843697,0.906457523862},{-0.27949394002,0.148554272259,-0.633567251344,0.230358251083,-19.343603130677,-0.286404103676,-0.296282536346,-1.30965166002,1.853177043642,2.259904995528},{-3.639597759993,-5.414161316585,-2.555526489757,-3.986568036033,-2.091127607309,-3.236279665612,-2.271146007813,-4.005205845838,-3.279925488054,-3.957415217287},{0.789448780127,0.418213435491,1.184986696251,-0.735484438096,1.17408480863,0.771398830313,0.167494486011,3.233288995117,-0.758796554451,-1.010083864483},{1.996460292579,1.580678027774,7.925131789938,1.53235513184,-0.970828678326,-1.500028212374,-1.288496041558,-1.500014635127,-1.260256127211,-2.513299619381},{2.675896332461,3.923879120646,1.99978875397,1.518600065279,2.73468094649,1.787574401354,1.70558459888,5.18060341519,1.013558973259,4.833928180848},{2.038772449758,1.406941385762,3.053193724393,3.539961746955,2.542511315136,1.778787668347,3.235514888715,3.764341539991,4.136197915634,1.663553426164},{4.99847285439,3.012575732452,2.500805506572,4.788285110852,3.006155679689,2.797074076708,3.161582891028,3.231395510668,2.298211046394,2.348128681048}},
        {{0.758331708644,-3.505455213079,1.781910490494,1.903151627987,1.972486971757,-6.118503701146,2.186934531291,5.994299691173,-1.069874840787,0.011378687779},{-0.261374392296,1.867384116569,1.338329598807,3.014749772134,-3.171029902944,1.475637306702,3.025556409013,2.609146838005,3.131281316408,0.362594899686},{-6.695658755574,-5.203392281345,0.355506967414,8.338408667715,3.133720611375,-1.84562580749,2.938575421605,1.521524655073,-2.682873468074,-1.506878659206},{2.493030621977,-19.245728222191,-19.319496833506,-5.130851533387,4.579411951282,8.206984601819,2.961069285652,0.935301641145,6.02482497176,0.384868393432},{-6.47908490793,11.718344079062,-5.030289003208,1.086743331396,0.971398632366,1.398069274125,-2.96498701729,-3.534342702867,-1.064790476768,9.54847668841},{0.499776444573,6.825768362627,0.480391629853,10.209242294569,5.8970631517,6.167545382914,5.318236298749,5.299570099466,3.910349558371,1.420512463009},{-0.99942723826,-1.025856209181,4.680348361091,4.000816345132,4.682820541056,5.005402428759,-0.999953488122,4.846521390314,-0.454485689694,5.254291624718},{1.503144100384,1.642441663278,1.501063050699,1.741784055455,1.501946367064,0.49937454308,2.000505081336,8.489605395541,6.85351327667,7.082430840532},{5.703518991363,1.738684008714,6.616902688279,5.592082171158,5.954604434449,6.34985011689,6.140222727182,4.424878528644,3.188019131089,4.191651554225},{3.004446073835,-0.118787994236,2.121389429143,2.75618830211,6.350333172698,2.70772479008,2.500732962324,2.000328470483,3.000588018549,3.326038007887}},
        {{-5.492547321798,-3.629547231577,-5.450223488095,-0.583623751489,-3.112461342531,1.727381363049,-2.398281920724,-3.013589127933,2.298222391988,0},{-9.575559354988,-6.177612353398,-7.758479566897,-5.510238765944,-1.58142883624,0.028136343641,-4.557023252091,-5.111130834817,-3.531967505408,-0.932701802731},{-8.581927116627,-7.137265462308,-11.283763061686,-3.588349780089,-7.066462572695,-5.430533564113,-3.007453182955,-5.458015811295,-0.117303650097,1.428160071667},{-19.320521831983,-2.866636870067,-5.685251476658,-8.774510997177,-2.966415999932,2.946771916767,-2.146404695446,2.966295416793,0.087714649616,5.223775889643},{-12.048853165776,-9.855533663682,-9.895677171297,-9.598732471574,-9.313133005359,-19.350273500365,-8.961542381122,-7.015175620083,-6.693193792621,-6.453832817779},{6.635678592511,-1.007182426217,2.000097986419,7.700128456049,-0.500668166586,0.626188886176,-0.500563766629,1.638946291147,0.580915046156,5.462315582412},{1.781197816513,3.668688082873,-1.50064500306,-1.0002743433,-1.997723976651,-2.000333193733,-1.000826201528,6.925695896673,6.947382813816,-0.904321881497},{7.060366985351,-3.636245106266,0.823929265326,5.874331897914,7.392557402335,0.92682974551,1.803544972913,2.263716142478,3.766696896236,0.865774854566},{10.131660802175,8.757111383525,2.470079423437,4.976162195115,3.322719814081,4.655299311241,2.802015408258,2.659883742608,5.333816263019,11.813461847877},{3.81985411265,2.738977457725,8.299462138614,1.474266014862,2.748567092029,2.99630379948,7.157359635186,2.861981104064,6.559109899269,1.294891701011}},
        {{-2.319297426919,1.425664880015,-10.195905547395,-3.578706451686,-19.320636277626,-4.517634285023,2.868845892133,2.734038854925,-1.29029009716,-0.000000076491},{-19.344998974436,-0.146572648289,-5.283922388155,-19.247814379396,-9.96311951574,-5.040412549563,1.10967604144,0.529189049915,1.65077510722,-1.35760472464},{-3.72438385013,-2.923909194459,-6.568566613056,-19.250350329704,-0.842842993423,-1.440536708993,0.091312373727,1.801452401595,-3.536012050376,-0.998494271773},{-8.697710987685,0.493989415652,-19.304233299841,-0.624048155599,-0.570970278777,-3.434533908,-20,-2.402493964925,-0.31072455936,0.218042729458},{-10.792242205474,-9.993361661406,-1.788865115895,-8.295898316314,-8.20825810033,-19.24994448231,-7.761291043823,-4.172178950149,-6.517914228204,0.322555461168},{0.489259418399,0.756792051082,0.698349367565,1.985220094021,0.739530414512,-0.256692416286,7.393985552345,-0.713419153833,1.316360054945,12.426947129158},{-1.161668386835,-1.499580677857,9.606822150662,9.546963844318,10.376575453173,-1.000633212273,1.826485749908,-1.001291066737,-1.000108363948,-0.670293671279},{1.335208043868,6.798933233543,10.875352500786,2.03670861571,5.641886003218,1.000341094514,10.34345693029,1.002279609685,1.69099279458,1.291880454767},{1.766964085018,3.544030660103,5.113652153967,1.203986424217,12.408376011169,7.043152809522,7.725498817736,5.231680761796,10.712183161438,12.573391207344},{9.002673908356,2.958458687899,3.004015835195,3.237117847003,2.500366952588,4.259176727042,2.665171688253,2.497579436156,3.022812950527,3.58593403376}},
        {{10.768108292205,8.143366050046,11.1924773308,9.637536917739,10.675368699897,4.313451117959,8.434013302451,3.707968846499,11.488940039918,7.625573061376},{6.876873487785,-3.080081089257,11.088490501888,3.228938836957,10.669329285675,5.527766452982,10.360028927139,8.619724857952,3.429326282019,13.825735256542},{9.35635004963,3.730597262792,11.426722766378,6.742547254456,14.711506802803,2.849706364229,15.011110788793,3.487334033711,9.48204589316,13.374553880766},{13.375209016559,12.138379467584,9.860536624199,6.60913026504,2.903767242086,5.161077451814,6.040202313467,4.742931637118,11.486333660239,12.526258978847},{10.309123258815,10.201928154623,7.371293541756,13.94499010526,3.127035541303,3.265591835263,6.223162591727,11.954362700408,7.113409549057,13.267406039475},{5.986735519406,10.529060055019,11.764141639973,-0.044697637768,10.759669632704,0.801556759701,10.382747361751,14.677816960818,9.715798228463,-1.238964385781},{8.754520599784,-0.103126638707,10.892772577372,9.316832978407,15.008835877162,7.734604223572,-1.50763933054,9.330075133587,8.297746949496,11.294433108561},{4.099617564614,1.000635773799,1.850954535754,-0.149210247087,0.831161682211,1.694427319235,13.6340130743,10.364669190093,0.499845162455,11.420122143215},{7.952886609952,-0.146601845048,10.286964731334,0.74910007451,-1.405505954037,8.679558338627,-1.838551198717,-1.894469781276,-2.410387471174,15.265632894},{2.483031508612,1.843131516461,5.813985046834,15.008237591412,1.505706346631,2.003824864521,12.238568856097,0.730708179212,2.633978233461,3.039296229071}},
        {{15.223532026144,4.143841942396,1.752340635102,1.506565203978,-0.060520573113,14.905333605813,-1.621581015193,-1.642169095634,-0.009897878628,-0.48630914451},{4.118836192034,4.895028065555,1.151332627256,0.387005677744,0.494791678031,6.666281303728,-1.573899465443,-0.306339909889,-2.640328885931,0.311855154714},{0.513623813414,-1.613649732585,3.499147310355,-2.791289299038,-1.505361033735,-2.681328206509,-1.236435883768,1.677841599888,-0.186264165833,-0.985621968724},{2.941358800944,4.501186292382,3.841883769538,3.675892608563,5.567583586089,-0.749665621215,-0.757961406034,-0.841778854232,1.949777011983,1.314973744411},{3.232181574728,0.366956275695,2.404271466952,2.429220960414,1.075751147785,0.261561729918,14.744110065029,1.264693987693,8.148673093643,1.431084320466},{-0.001617238291,0.376883336056,0.195996403942,-0.871669445923,0.5013823715,-0.4997961957,0.497872455447,0.400127030044,0.14200831597,0.463357445898},{-1.500622887491,-0.914358642924,-0.246611940648,-1.095847363527,-0.490828558626,-1.501199357591,-1.000576281968,-0.119423317888,-0.999062411628,-0.889169271051},{0.999438908215,1.157614897905,0.999485995886,1.003979076297,1.615908901911,1.001062183721,0.634312922139,1.500203342288,0.974705053238,0.560045203599},{0.107998999727,0.519050523189,-0.077527120124,-0.027824684415,0.141804558044,-1.2011020718,3.102041362973,0.29591406246,1.038270045688,-0.55984172923},{2.475875570325,2.501347261837,2.023298923289,2.049860091947,3.501307681142,2.004730443322,1.503931190863,-19.360647093685,1.999182665722,1.533668042486}},
        {{14.282904173843,0.440437022833,5.895069250173,1.100184603994,0.650290139003,0.704085000649,0.552398269873,0.322480804268,-0.331028358525,1.021048766126},{1.625168230331,1.482846154898,4.061732901076,1.608195386526,1.180748450886,0.851081554035,0.737576032335,0.426263137411,4.867287794988,-0.579550899327},{-0.154177192646,14.822068541543,0.127887919639,0.146963704194,7.994629666685,-0.806696008563,-0.48424300633,6.198637011504,-0.916921635404,11.0103598572},{2.901207727249,2.962390137126,3.021092697156,6.065724051345,2.534229729098,6.000062480803,2.060591012477,1.261701860101,1.38711568701,-0.000045787727},{1.17111575659,1.391348405894,1.68513356836,2.673651142262,0.808493301361,7.266592545571,1.050121727146,1.053952664419,0.026953526491,0.41652331511},{0.507551298063,-0.356054581338,0.557959055245,0.374701020392,-0.999774605912,0.448780411809,0.000415633445,0.84836598958,0.122199008826,0.701126066818},{-2.007755846077,-1.291469663356,0.000334129939,-1.821977582788,-2.11700818805,-2.00032461855,0.853433165716,-0.498588971054,-1.046074774155,-0.728275447679},{1.498891430361,1.001627716864,0.497457151538,3.930810259948,1.927783935738,1.499267700003,0.500998800757,2.081203955326,1.211746231369,3.112811590345},{1.782197079514,2.122676712129,3.336260203155,1.193637828087,1.7216014788,1.088394997563,1.305745639376,0.972415400652,-0.240774135502,-0.516272891137},{2.746813060078,2.988690259286,2.499103075158,4.358647790563,1.364017266613,2.528873369069,3.451192254846,3.502562055803,1.69679334401,2.665342629835}},
        {{13.58435938636,2.475836140596,1.65879316429,11.185238782292,14.68513391576,1.499813458383,10.878086038741,10.04360097618,-1.026674823497,5.115791497239},{14.320671609733,9.425639057015,14.38173435244,4.071650786359,12.322483977261,7.48417104962,11.881309168257,11.14182979874,-0.525417513022,0.518979772378},{1.337320294909,-0.711529206825,0.966537242852,1.034849093666,11.384109249952,1.294273550088,1.26982008402,-1.688276574378,0.422045487072,-2.254915610074},{2.751262608377,2.644325024223,4.776516875395,2.87561029674,12.815640127625,2.112399375082,3.296864450229,2.386554196904,11.49894025994,2.064408495767},{14.455102266599,2.254187129673,1.084875004774,1.430243824631,2.413349918324,0.641616737518,2.192827969873,11.600870832233,12.137259217623,1.776473966037},{1.374479379193,-0.317890936825,1.205525461406,0.342274475223,1.921746074944,1.500618469787,-0.998597978502,-0.501222764315,0.193093364789,-0.665228304338},{0.736823111128,1.929800252062,5.565486612175,-1.00081664604,0.730913509865,-2.763166942974,-2.391248870725,-3.147193282521,0.457665713739,-0.007241121895},{2.158059669632,0.500934885288,1.751971971415,2.213102795086,2.937537139132,2.351277038094,3.382388098042,-0.746042873419,1.998768146627,-0.974067981236},{-0.450058496344,-0.345930290352,-0.163793262025,-1.244257552742,-1.072154984154,-0.973331092389,-1.767294858525,-1.144491359103,-2.057957907886,-2.09763704274},{3.37197652706,3.874906980995,3.499658187642,1.823826365539,4.000568840999,5.753911790474,4.020824858811,0.840111286664,0.689998807439,2.268491836429}},
        {{15.167270968069,1.622054084604,2.576795376076,1.976724315949,1.999376164152,2.177807481137,2.425276496864,1.97520430718,0.949572153541,-0.224652547154},{1.271696125102,1.606279456745,1.678365528286,2.829202115484,1.94881570659,1.999770987519,3.090325462734,3.40592321275,1.91319865483,1.055000580633},{-0.003942296732,0.324887844962,0.595397657081,0.865062857271,0.619071097882,0.600518692873,1.669401318712,0.685877613417,0.391722292955,-6.274260531832},{2.94085822665,3.160264056036,3.316373111465,3.743462949705,3.133378759745,3.92774214756,3.659608271096,3.346980990969,2.97649975769,1.439850665257},{-0.960250021541,15.001909275558,-0.228283804061,0.258692682016,0.556962961134,0.891542592669,-19.273078895241,1.2864404548,-19.272969617874,0.82786280716},{-19.274656584664,0.635311016716,0.608294639435,0.367030396012,-0.433208728826,-0.149570164808,0.3103006473,-0.402204080489,-0.007421536805,-0.83886941898},{-1.960292542102,-1.001377841054,-1.252626935735,-1.500405640553,-2.518587457483,-1.599830903641,-0.809857231239,-1.814894084308,-1.286874741506,-1.147613950829},{1.60559960727,1.883792269925,1.500643990635,0.999957181629,1.025298113719,1.99985039975,1.498453161246,0.819811253027,1.001020785111,1.245032581507},{3.146726485763,3.325191802839,3.445204521535,3.184599220913,2.563113593422,2.540468272127,2.301493053663,1.569538396566,0.666612028342,-0.741441425654},{2.685902230562,3.069809138752,3.001894595353,3.003827792635,3.838913719179,3.138338960766,3.938643945963,2.065115581118,0.875845743314,1.89192830023}},
        {{4.623476434908,6.612364194207,15.470282303153,3.813907082692,12.933565725117,12.885127548408,12.376805262749,1.562347681819,11.134251595788,0.001938071992},{12.457281901609,12.151082454735,14.19567686182,14.789757561022,14.831981238685,4.07226520211,3.951524932937,3.364611779783,12.010940028637,8.141986086441},{15.280212074994,15.148454504376,13.067119098745,14.535714826516,15.056291829771,13.90122436021,2.793311195602,2.68712877202,10.473570951889,-1.245185744475},{13.560955274395,14.612829969671,14.874205653316,14.788866320412,14.601014045083,4.171950763324,12.886820687618,4.128917466692,12.560749277421,11.816172847345},{12.222640102894,13.361569351228,6.852204885297,14.143607828959,14.215862422254,13.924783630676,13.971251743188,13.198615930018,13.103502483777,7.027071959438},{-0.221282802244,-1.088568069751,-0.500889432179,-0.225884248137,0.483359801061,-0.155130975534,-0.489059369183,2.8141682006,-0.495328223233,-1.408777015559},{5.369653357237,-0.992305289451,-1.501042570039,5.481370654342,-1.587105812347,-0.500383116838,-1.607535675969,4.560039248384,-1.501404285904,-0.501364201802},{1.181994678747,10.603853989074,10.405880335045,1.47420828638,1.203715025478,1.130440841989,1.573676243314,0.733684934756,1.730984373497,0.939448324188},{7.265012023384,5.920634701936,7.993743307259,-2.332376778643,9.568624643665,2.818306362604,1.551297651682,2.802649840434,1.588510933896,15.085640392247},{7.502913859189,2.965357706825,2.493439576577,-1.900012131709,3.116073783856,2.561264997697,2.22413795925,6.628547042362,2.063026500969,14.061746505978}},
        {{1.516072364399,14.394582487484,1.153239737135,4.624062924501,1.741490469956,1.387088566687,1.670697271541,-0.249973938209,0.059701345424,-0.001369603496},{4.615949280272,3.270220623728,5.129925709349,5.793981471683,1.053937103713,-0.141822217068,8.139267983763,1.560132275689,1.146853755359,1.629685586458},{2.32976385064,4.67574585495,1.223418855112,3.025657928269,-1.054089108621,0.577316103795,9.68970233301,-0.281163094927,5.504567362601,-0.212195208584},{7.393360688611,7.245862668062,6.800982316981,7.006470648407,2.525834865448,1.118041413483,5.963300385223,1.265900126477,1.902670605217,1.005192071405},{8.478974507854,14.992393235659,8.801654632047,6.103500103849,4.631840793018,5.933884533689,3.097070575489,2.975226429256,2.722623642552,9.043063454662},{-2.020569227038,-0.500905805233,-1.000169374333,-0.505422921781,-0.044884426045,0.05638663257,5.486239216575,-1.929936729969,10.445750194059,0.495465105717},{-1.000856822355,-1.999552824164,3.678539906074,-2.884657217505,4.839982613495,2.82409127878,2.512187562707,-3.176757786648,-1.4660857341,-1.395317968622},{2.001083148599,1.001077202257,1.186600159023,1.935671637545,0.501377923695,3.3957020194,1.144962724092,0.262461432836,2.001721116273,0.26236015198},{-0.827681382877,-2.864891390036,-2.25503877675,-19.148068388181,-2.520927596786,-3.234370629424,-1.641451609145,-4.250485390165,-3.048008291125,-8.797446173054},{3.476979553481,2.997329262826,3.863626100955,4.448443393255,2.733253130054,2.501540406545,2.516778325626,3.499719128993,6.162236182685,3.514358479722}},
        {{6.343786676555,8.396492390718,4.705527707692,1.589233303662,5.130341307074,8.982472189353,10.842047107922,12.748261280778,13.169103825937,7.619833813537},{3.196143954142,13.85471501615,1.070392714989,12.72070655826,13.177438370732,12.328592501019,6.963455622325,10.571339851675,12.520901725016,2.500446115582},{14.654294121909,13.291875339634,11.119955438822,8.931999782759,14.550389550223,15.019236636558,13.250855811588,12.480557024634,10.615490134214,8.290121600016},{5.050159654973,2.967497064133,12.914017452989,7.130316293978,8.247079264816,1.547444942793,5.907940476748,13.605582639391,12.575722999631,6.268590078465},{13.903252722776,12.693774289508,13.006965618105,9.248081708237,13.755843950239,2.971912063086,7.447564529715,0.567277015273,13.031186606205,13.02446113154},{3.759351986407,0.28044997949,3.507650453811,0.590184474764,-0.600065414444,-0.50089930514,4.602145232006,3.142966337701,4.025176056837,6.488997389931},{0.900093852061,5.430737353631,7.102945592949,-1.48734104625,-1.000033194398,-1.539783655655,6.775259706727,3.425488156001,3.240029533591,4.891549639324},{5.031397756345,4.186651203955,6.679775085437,0.499570163362,3.99588999971,3.948820575519,3.707602223175,3.421324753637,4.507258468843,4.25297541472},{1.092953858294,2.714997277764,1.062779991226,1.875070158794,-1.380821456004,-0.246934360902,1.575638178976,2.946198718611,1.360180345214,-5.603202594708},{0.418390620567,5.466227687367,2.37297142733,8.093606230481,4.93350039942,8.137189974356,3.240508696219,4.491208605713,2.683619186264,6.153309139458}},
        {{2.266863637201,13.080193934552,9.806927934943,12.772450313344,12.157954532409,11.521988477102,12.797527887303,0.110725680814,2.404503500412,3.620104048707},{14.785704899965,3.730069184107,9.800891552816,14.509501736659,8.043658697129,12.249557960155,5.324505431399,-1.072946907908,3.142966715819,7.863655188599},{4.250976520674,9.60315290671,0.536625686474,12.353164651,5.271565258089,2.153739756753,2.513978766083,4.308232908169,0.555016264455,-2.031644395125},{13.67672014608,4.743739586573,2.68123521161,13.128083895667,4.067765429412,8.406239398525,3.311046451848,5.509262024806,4.951699601429,4.030501489393},{5.988788374997,6.194265078853,5.630901899441,14.764782196824,4.018191464746,12.534122130322,2.610299639042,6.646263589803,11.446316353473,3.558394996827},{5.042430378573,-3.134865562794,1.000044100649,6.521518476498,-2.473700885103,-1.000537610987,-1.88899138455,0.512257394742,2.477541027327,-2.769190638883},{-6.02427310466,-5.42301351558,-3.111888805427,0.269118463943,-0.753175069364,-1.000255634701,-3.772785728987,4.268713684303,8.988788415757,-4.083388995901},{4.838589343566,0.978615701031,5.940451759358,1.999439746397,1.002217787839,0.498988655792,1.501174813039,0.242657030789,2.884626627885,0.504819455196},{-1.358801368106,-1.863616013946,1.262931410852,-6.813133309572,-1.138262713522,-6.440903541442,-5.996563511367,1.17306528154,-7.269938897816,-4.274367520429},{5.994822244014,6.627162421821,6.304990750472,1.501856626637,3.606724989496,6.893687047594,2.166166644595,1.900839867365,4.003199927504,2.732096239967}},
        {{10.117831311723,13.615667143605,13.681748095082,13.71157149499,12.505507665494,1.817750300673,13.296524765403,1.928521330011,0.505045148444,4.587720232987},{8.901987683808,10.860794948918,3.262702616729,12.708638565998,13.909463653424,5.236311110531,13.672878420224,7.980156790173,0.43288844925,3.823939264574},{10.737734793395,1.487903715463,12.810728324159,0.653496652366,14.174081633896,13.857119753251,1.189254711084,13.155593536725,11.619569111876,2.870498004501},{7.361533216143,14.41040784618,11.526296267951,14.312437895152,2.417025980371,9.176114795775,13.773210405735,3.28928417814,2.288121949323,2.502340008728},{13.667605286542,7.597235385333,7.483010882448,14.916811995557,10.928704124899,7.033992794376,8.880670369359,14.282177372149,8.476750689218,9.288074265785},{2.999198891902,-2.8954421129,8.702434443958,2.552211415604,-3.768059441237,9.135380594376,-0.001271663101,0.010008334426,0.999222307545,-0.511686147199},{1.403472126439,-1.332069924706,-1.468250784675,7.227770136786,-4.942431349041,1.088039798587,-2.935923582103,0.260408574598,-1.755030458007,2.917647647392},{-0.132936563017,5.006158559592,2.501490725567,0.047412869298,7.325566236145,3.880099180107,3.508021685742,1.99773450299,5.282943252386,1.430953884352},{-1.77883293154,-4.294764724711,0.185217908213,-7.946772941177,-8.837480498151,1.056897677232,2.943663112928,-10.43229551378,-4.654192352797,-19.230356487744},{3.012375074255,4.493424039988,2.000383444202,4.361919718401,7.19820776567,1.79859400424,3.020824745934,2.639936268359,3.097206475455,10.151220930355}}
     };

   double matriz_ini_erro[n_holes][prof_cube][n_candles]= {{{0.388348033082,0.960783715323,0.85,0.100924710837,0.85,0.85,0.445844904935,0.85,0.9,0.901035448166},{0.916776024659,0.85,0.85,0.85,0.85,0.85,0.85,0.85,0.267708365123,0.85},{0.97497482223,0.191564683981,0.85,0.85,0.85,0.85,0.85,0.005005035554,0.973540452284,0.85},{0.586687826167,0.90084318639,0.367290261544,0.010437330241,0.85,0.899999999791,0.482467116306,0.727683339946,0.432996612445,0.229865413373},{0.900177284056,0.9,0.196783349101,0.85,0.85,0.096591082492,0.899504749138,0.673818170721,0.85,0.924405652028},{0.85,0.247230445265,0.268410290841,0.899604083377,0.85,0.85,0.361644337291,0.609576708274,0.207373271889,0.85},{0.9,0.411114841151,0.85,0.303811761834,0.85,0.194616534928,0.85,0.85,0.971129490036,0.85},{0.9,0.277871028779,0.03845332194,0.26322214423,0.85,0.150914029359,0.325235755486,0.288949247719,0.9,0.85},{0.85,0.290780358287,0.263924069948,0.85,0.89999999998,0.85,0.85,0.85,0.925443396069,0.89951025396},{0.85,0.170506912442,0.85,0.85,0.069490646077,0.270088808863,0.075624866482,0.950102237007,0.413983581042,0.85}},
        {{0.85,0.900263343276,0.85,0.899999706216,0.9,0.979552598651,0.900441996622,0.85,0.895017491684,0.900031571655},{0.899995117257,0.899999961211,0.900073081629,0.899999950128,0.899999999995,0.958522482743,0.899999999995,0.899999950317,0.85,0.85},{0.900208201091,0.899999999995,0.85,0.9,0.900004134695,0.9,0.899999586734,0.899999999613,0.899999952841,0.995120616016},{0.935175904723,0.90142324299,0.899999995,0.89999509,0.899999998811,0.899999999526,0.899999999995,0.926659108249,0.85,0.85},{0.85,0.899999999995,0.988947715085,0.85,0.990874909128,0.9,0.900458802588,0.85,0.899999995207,0.900139853057},{0.85,0.899995073806,0.901460299594,0.983346826403,0.900087040957,0.899995350737,0.85,0.899968072816,0.899999878136,0.899517855711},{0.901116083855,0.85,0.901000497829,0.899999969771,0.9,0.85,0.900132467616,0.900913330068,0.90170761061,0.85},{0.85,0.902809702847,0.901877976975,0.901195501479,0.900120057799,0.900391266341,0.902223060739,0.977347614869,0.85,0.900380383291},{0.85,0.85,0.9,0.90000543567,0.900008906111,0.9,0.900501782192,0.9,0.900620826857,0.899999963584},{0.962889361388,0.899735113972,0.89999509009,0.900231843126,0.90133077226,0.899996280136,0.911781198467,0.899996393839,0.89999992305,0.85}},
        {{0.900358630575,0.899999999953,0.9,0.900231219456,0.903866693728,0.895001570177,0.9,0.899999999568,0.900371572314,0.911718618143},{0.915879279153,0.900000027509,0.9,0.899999999766,0.900468962145,0.899503720054,0.900394539476,0.911089803589,0.899985110019,0.900102648329},{0.85,0.9,0.85,0.9,0.900066801584,0.899999995517,0.85,0.895,0.85,0.336832789087},{0.85,0.901191369048,0.978038987396,0.900028458054,0.90024179281,0.85,0.85,0.89999999956,0.899999954344,0.899934665502},{0.900391567476,0.899999999605,0.992820525419,0.899999999518,0.85,0.900075481927,0.900265000117,0.9,0.899999999518,0.900312799463},{0.899974786931,0.899999999986,0.85,0.900068623516,0.900033700504,0.900195202205,0.899999691954,0.895045017943,0.85,0.900173257515},{0.899998453574,0.895040844447,0.899999554356,0.908747376972,0.899999999749,0.899946030617,0.85,0.901094155754,0.899972738058,0.900726887269},{0.899950391446,0.89999967,0.901990487479,0.933751164341,0.900120343313,0.899950218711,0.899954013906,0.85,0.899999974363,0.899985767211},{0.899999535079,0.895032790613,0.900437055571,0.899999853191,0.900232947664,0.94812587412,0.899996391186,0.9,0.909848353527,0.900056698213},{0.85,0.899998003002,0.901162826,0.85,0.899999999991,0.900053976982,0.85,0.901126960847,0.900173474662,0.9}},
        {{0.304818872646,0.85,0.9,0.932521631972,0.85,0.899999996261,0.203650013733,0.85,0.85,0.901290659439},{0.900182824791,0.900843952142,0.900098878028,0.85,0.85,0.899999650452,0.114535966063,0.85,0.900611282736,0.889736625263},{0.900736233433,0.986232072505,0.900602357788,0.85,0.900806671241,0.899999967091,0.899999999995,0.318399609363,0.895011717582,0.059785760063},{0.900000051185,0.899999530781,0.899999999954,0.85,0.901305979407,0.900423719796,0.899999999805,0.900012237377,0.85,0.85},{0.9,0.90000726693,0.85,0.900539243143,0.85,0.85,0.9,0.900757829414,0.944674613788,0.85},{0.059816278573,0.85,0.9,0.901190222189,0.896671309397,0.900130564913,0.899967085292,0.900312802562,0.990508743553,0.443372905667},{0.901857106377,0.9,0.904001825906,0.9004843923,0.900329383148,0.9,0.900171278724,0.373821222571,0.121250038148,0.219458601642},{0.957520034858,0.981958510086,0.900002751368,0.899995045006,0.900654763379,0.900269459387,0.85,0.976406720176,0.902294578297,0.90137567027},{0.899999999999,0.901352646703,0.899999999956,0.89995265268,0.913284009216,0.899993104343,0.9,0.900566959301,0.85,0.985341463603},{0.9,0.900004166343,0.899998176747,0.900402288152,0.85,0.900842575678,0.913913312173,0.901472099949,0.900366420428,0.85}},
        {{0.900470491298,0.925880766119,0.9,0.900411526837,0.900320474651,0.899996662872,0.900469830744,0.90069633151,0.900686669172,0.542985320597},{0.899999998047,0.899999669716,0.899999899169,0.90000315977,0.900963020456,0.922665083789,0.900490722338,0.108432264168,0.900457266466,0.900039596168},{0.899999904694,0.9,0.9,0.9,0.970078419744,0.900000490436,0.900116667684,0.901229875058,0.900171276398,0.85},{0.986443827401,0.900004518253,0.9,0.899999997576,0.9,0.900629966962,0.900345838208,0.900374955992,0.900116113882,0.993046712272},{0.900007248146,0.900005504169,0.933137139365,0.900059388847,0.899995350908,0.971471855545,0.900617988702,0.911496214099,0.90033864864,0.9},{0.899999995265,0.901378899228,0.900015114175,0.901573744131,0.85,0.900237083041,0.85,0.899996577883,0.901043672792,0.900981044406},{0.170873134556,0.85,0.903685306816,0.85,0.18231757561,0.85,0.9,0.85,0.99160646209,0.85},{0.899998575528,0.85,0.899983184224,0.900050443817,0.905131739108,0.85,0.900936661242,0.899999959994,0.85,0.60747093112},{0.90055693218,0.899999601406,0.900486279995,0.899999999994,0.90058080502,0.902121964807,0.900261425925,0.899999998201,0.900112751745,0.90008895327},{0.162144840846,0.907837210107,0.912686544389,0.904594019981,0.85,0.899999953924,0.90050152162,0.85,0.900380404212,0.91381572924}},
        {{0.900216990371,0.900229212089,0.899975487108,0.899977008502,0.900233214919,0.85,0.899987768375,0.85,0.85,0.85},{0.85,0.900013486751,0.900025039724,0.901638187159,0.900229567243,0.85,0.85,0.85,0.900483244042,0.75},{0.900929422281,0.85,0.899950301019,0.900158307149,0.900355953052,0.900530813793,0.85,0.85,0.900451248691,0.900972907395},{0.900611699344,0.89997187304,0.935556112709,0.900485983194,0.900236241709,0.971005722221,0.953538332712,0.900395614346,0.991917188025,0.900094352904},{0.900233100566,0.899999662502,0.899999999985,0.900418543422,0.899995900597,0.900204655294,0.900091204547,0.900689172918,0.9,0.175664540544},{0.899510013581,0.901249661469,0.901168555666,0.9,0.196600238044,0.9,0.900438094799,0.080996124149,0.095187231056,0.85},{0.902257312478,0.921181472398,0.900869437996,0.85,0.89951161153,0.85,0.738242744224,0.8999910231,0.900573961507,0.901151067667},{0.979349070711,0.900832401807,0.899528507797,0.90034812688,0.85,0.9,0.901227841068,0.85,0.904561724348,0.900260164943},{0.89998490509,0.9,0.900373591284,0.899999548752,0.900006409675,0.85,0.900107354123,0.909520337077,0.900079965991,0.325632496109},{0.900544178481,0.9,0.899673166448,0.900546890922,0.900481720512,0.85,0.90041626106,0.184087649159,0.909771708483,0.161595507675}},
        {{0.899981629324,0.899999982249,0.899999999583,0.899999999946,0.9,0.900528764198,0.899951266004,0.9,0.900004162015,0.903945587905},{0.961648355485,0.85,0.9,0.920586420509,0.85,0.9,0.85,0.900405049388,0.900001341899,0.90008932785},{0.900745006409,0.932277779474,0.899999096074,0.899999999995,0.900006727805,0.900089302329,0.85,0.9,0.900165346001,0.85},{0.899513422724,0.899967697683,0.982761568947,0.899999860343,0.900176378519,0.899999998073,0.85,0.895014586322,0.900448104341,0.965898453636},{0.899999999996,0.85,0.900246130568,0.90008569747,0.900146059148,0.85,0.8995,0.900006157719,0.9,0.980128412346},{0.899999999513,0.900460898411,0.899999999995,0.899999995205,0.900209404963,0.900094958342,0.900001088427,0.85,0.969610883194,0.900860491671},{0.85,0.85,0.036317026276,0.9,0.9008175131,0.901149580743,0.900847669105,0.90064130584,0.900441385715,0.85},{0.899465406812,0.85,0.948071017941,0.901289371402,0.85,0.9,0.899998097482,0.85,0.900809876116,0.85},{0.900098040667,0.900025649437,0.900071702241,0.901224899939,0.899999998151,0.933635763267,0.900258145387,0.900521944792,0.900124747888,0.899999510678},{0.899967628542,0.90125963916,0.900502077684,0.916843219001,0.900246553928,0.87454341258,0.900285151493,0.903562849424,0.895005973998,0.900601214637}},
        {{0.75,0.899995209357,0.899971390341,0.90017812219,0.900016786948,0.895035625782,0.996176342996,0.895001039155,0.930788912847,0.90017657907},{0.961216663259,0.899998688009,0.85,0.85,0.85,0.9,0.899999999954,0.899999999996,0.899999999996,0.900145458126},{0.899999999686,0.900695897887,0.900168918378,0.058351390118,0.899952653428,0.90044594966,0.85,0.899991604391,0.900112702088,0.901111484928},{0.899999999996,0.900048085867,0.968113340326,0.85,0.900008037049,0.85,0.900489487984,0.900191153208,0.85,0.899999998223},{0.9,0.190282906583,0.900387596731,0.900610714456,0.972422540848,0.994541459395,0.899999035427,0.996520666786,0.85,0.296395764031},{0.900981738212,0.900008456399,0.901224582291,0.166692098758,0.939085055086,0.85,0.9,0.9,0.700949125645,0.899973037219},{0.907145700456,0.900376960135,0.85,0.9,0.85,0.85,0.902462210439,0.85,0.899974750937,0.9},{0.900581284754,0.997888285318,0.901436802473,0.85,0.907741217726,0.903616843208,0.903251802708,0.85,0.9,0.9},{0.89995,0.899996954073,0.85,0.987676458022,0.899951785568,0.899999999954,0.85,0.905575563831,0.899996605712,0.899500584582},{0.900555927912,0.89908352916,0.932121781213,0.961672063356,0.85,0.89500406354,0.90425280388,0.902808923414,0.900542615786,0.85}},
        {{0.89999901035,0.936720807672,0.85,0.900789611904,0.899991151235,0.900904709123,0.899996819062,0.90020520966,0.902574105271,0.904334027484},{0.899999999998,0.899986869056,0.85,0.899973396507,0.902212360364,0.85,0.936738741875,0.899986148184,0.899998862154,0.900004409491},{0.900122178766,0.899509006299,0.85,0.899999975092,0.85,0.900376984423,0.899970930786,0.900617067714,0.948484669638,0.75},{0.901412595249,0.900384280984,0.89502218543,0.85,0.899999891179,0.900825138146,0.900104860464,0.900653018191,0.899973601506,0.899999951202},{0.899950380398,0.85,0.899999959559,0.85,0.900412103185,0.900210466213,0.85,0.75,0.85,0.899946261485},{0.8995,0.902056236957,0.901625474319,0.85,0.901440552509,0.89999989234,0.900520079829,0.85,0.900121504094,0.896936405921},{0.899954684936,0.997047204505,0.90117228328,0.900809425735,0.901136065576,0.901914818784,0.901566656686,0.85,0.85,0.900036107935},{0.899509002178,0.245277260659,0.903065217376,0.969415066988,0.85,0.902719287603,0.899631945936,0.899964135359,0.660786767174,0.899513558916},{0.85,0.900011595098,0.901008585031,0.85,0.900253518759,0.986201325267,0.900191416288,0.900616891774,0.899998578462,0.85},{0.85,0.984867366557,0.900477282149,0.900461418682,0.899994289078,0.902230361873,0.85,0.900164441614,0.899500609607,0.85}},
        {{0.75,0.85,0.916167149877,0.89999931205,0.927168068951,0.900241788857,0.900403588275,0.90024140886,0.85,0.901671482568},{0.98891138833,0.85,0.85,0.85,0.921126865444,0.85,0.85,0.85,0.900962630389,0.85},{0.89967861631,0.899950827232,0.899982419262,0.85,0.976634476095,0.973326822718,0.899978411388,0.900526040666,0.89500630665,0.935362926115},{0.895022621845,0.8950118305,0.895021254616,0.85,0.899997172658,0.85,0.900231107665,0.946836756493,0.900144196225,0.947279793697},{0.899934270165,0.85,0.744285409101,0.85,0.85,0.85,0.979624942778,0.895026870022,0.899996750705,0.900109464904},{0.901126327995,0.895022276986,0.900246277491,0.900294090655,0.85,0.85,0.899980009867,0.85,0.895004435865,0.85},{0.900402104846,0.909833020106,0.85,0.900084827038,0.85,0.903553115544,0.75,0.903773298346,0.906682660496,0.900041779959},{0.900060519302,0.164250618,0.85,0.900348602966,0.303231910154,0.900129181053,0.85,0.940326606613,0.895029961547,0.899990632177},{0.900633060885,0.895005391095,0.900747647587,0.90496929838,0.85,0.85,0.85,0.85,0.85,0.85},{0.414166692099,0.901267406469,0.899999749727,0.855067598498,0.901623334172,0.85,0.900668311395,0.900897105423,0.901075666436,0.85}},
        {{0.900004858602,0.993017075106,0.424359874264,0.892600161748,0.75,0.901550874849,0.75,0.899470698111,0.899999999995,0.900174595866},{0.914738471633,0.900158081704,0.85,0.900266158908,0.85,0.901884852146,0.85,0.85,0.988641746056,0.386761070589},{0.75,0.85,0.85,0.85,0.048615985595,0.900133027127,0.342204046754,0.900462024392,0.9,0.423596911527},{0.75,0.586931974242,0.85,0.85,0.899523970763,0.900102238263,0.900558600406,0.899544219337,0.603320413831,0.85},{0.900030366949,0.89999996718,0.85,0.900020813992,0.900047559237,0.922857402264,0.899504244057,0.899999960482,0.895007252724,0.246223334452},{0.895041991943,0.85,0.85,0.899962470658,0.85,0.900066432587,0.9,0.381725516526,0.9,0.900594275193},{0.9,0.910179818614,0.08969389935,0.85,0.268959624012,0.899995020003,0.900888442663,0.900248634267,0.900593309366,0.995565719132},{0.895036794641,0.903712853523,0.90080171235,0.899956147997,0.899978383531,0.900634507573,0.040223395489,0.9,0.902305994588,0.85},{0.932903317362,0.900863507497,0.900065847778,0.901588342261,0.900542027157,0.975176938688,0.900209226275,0.900313181746,0.899966716651,0.986447110243},{0.901760963676,0.981589327678,0.85,0.18988616596,0.899996592114,0.90360923342,0.85,0.900825775735,0.900796060118,0.85}},
        {{0.708365123447,0.899999846643,0.999307458724,0.899999999998,0.899999999998,0.155308694723,0.85,0.8999730758,0.991695883053,0.90162275659},{0.899950083239,0.899980581444,0.85,0.9,0.85,0.9,0.899999968284,0.85,0.8995,0.990925519578},{0.85,0.85,0.899958186198,0.30109561449,0.85,0.900002089617,0.986571855831,0.90017278315,0.85,0.899854093004},{0.85,0.900227488679,0.85,0.85,0.85,0.899995010234,0.908103760186,0.899999995545,0.899485382702,0.90021307474},{0.85,0.899999828359,0.90013893551,0.85,0.85,0.85,0.947269356983,0.9,0.85,0.952348963896},{0.901080395756,0.85,0.895007829524,0.85,0.900505660941,0.913536209299,0.900382063544,0.898220770898,0.85,0.895034130375},{0.902908035625,0.900350567656,0.85,0.85,0.900219751739,0.900222000314,0.901355496914,0.899929123615,0.900226943722,0.899961647547},{0.902092692142,0.895017525254,0.906006269152,0.901508729046,0.75,0.903464131332,0.85,0.935868621006,0.900229024587,0.901927644016},{0.899980422376,0.85,0.900047424924,0.900434378771,0.85,0.8995,0.899999999519,0.900629927154,0.85,0.85},{0.901296176149,0.903042476996,0.900059940934,0.900512474517,0.901756734268,0.900583602184,0.901696052383,0.905742686088,0.900067829927,0.85}},
        {{0.85,0.899999999627,0.900153275215,0.85,0.85,0.899999999847,0.85,0.899989664878,0.895090018284,0.900272656293},{0.899999996116,0.85,0.900312650852,0.899999956451,0.899995010082,0.924914788153,0.900177229361,0.85,0.85,0.8999629394},{0.85,0.951563471124,0.85,0.899998834343,0.902403462841,0.85,0.900014116076,0.85,0.975676747948,0.126773888363},{0.89999574918,0.900698128299,0.92803645436,0.955984476845,0.89999558748,0.899979763202,0.89950259331,0.85,0.900377055944,0.901537210107},{0.9,0.899999999956,0.9,0.9,0.85,0.900108032136,0.9,0.85,0.900396091495,0.900180431662},{0.900770022408,0.899503417615,0.899977309691,0.901599639717,0.900919346179,0.90044569712,0.961868060528,0.994114642933,0.902039582094,0.900413103559},{0.9017909758,0.85,0.902597807333,0.895046179083,0.900231779503,0.901413912989,0.8999509,0.901416150503,0.900515364503,0.900642898025},{0.901248330618,0.903610847761,0.900050774286,0.9,0.900293623841,0.901288336367,0.901087682626,0.90081417038,0.900332806542,0.85},{0.959215740531,0.895020528275,0.89995,0.901143026108,0.899999999995,0.901623828693,0.900214698625,0.9,0.900138227273,0.9},{0.85,0.92799173386,0.900808826116,0.944237492433,0.899999996826,0.900372691914,0.900552373138,0.900315872274,0.899998908661,0.922360911893}},
        {{0.85,0.900214393402,0.952771189045,0.900016437284,0.899999801662,0.964900047297,0.895018526261,0.937833796789,0.900152847453,0.419049653615},{0.900325358381,0.901379303081,0.963321027371,0.900324424344,0.85,0.900476737879,0.85,0.85,0.900222113336,0.900748340396},{0.901145142152,0.900243591621,0.899999869285,0.900469088285,0.899502009491,0.900001618882,0.90013305889,0.900045358443,0.901770698788,0.90037872867},{0.900309251997,0.85,0.924085987123,0.895038805811,0.85,0.900402259119,0.90043549492,0.899998024475,0.85,0.927467773261},{0.900739206388,0.90045302933,0.85,0.900005430921,0.899999983345,0.895002867214,0.85,0.899999693744,0.899998266415,0.895034420301},{0.900460578413,0.995908665786,0.90045475864,0.900359009671,0.899950254479,0.900101453903,0.901614762862,0.903768269912,0.900314192634,0.90123332777},{0.895045045045,0.85,0.8995045,0.901771569126,0.899692174755,0.928765171527,0.901225431608,0.968342191838,0.876908597064,0.906373316604},{0.899998036079,0.900822265844,0.925016366093,0.900391277969,0.900246862895,0.900853114832,0.901393551902,0.899708995376,0.900763054304,0.905931301168},{0.901966403764,0.900739285974,0.900379732109,0.900012554232,0.900132024881,0.90064808628,0.900965759052,0.900565967041,0.899991432269,0.900629042009},{0.899999511231,0.899978709859,0.900136396911,0.900015545241,0.901190351661,0.899999938855,0.899964715743,0.900817096542,0.899976349593,0.85}},
        {{0.23120822779,0.9,0.90000260323,0.900458616901,0.9,0.9,0.899999999999,0.9,0.900446182921,0.916850495214},{0.85,0.9,0.900412979216,0.9,0.900083644819,0.9,0.900465800669,0.899997794791,0.9,0.900101076908},{0.9,0.9,0.900013590567,0.9,0.9,0.900009003876,0.90033365657,0.900063157094,0.900049881283,0.246192815943},{0.900000590533,0.926239280373,0.899999953508,0.9,0.899999999997,0.900000042835,0.900003396563,0.9,0.900446647571,0.899999487463},{0.953838482202,0.949006873512,0.924771877578,0.899999543451,0.9,0.900763890509,0.900000042473,0.85,0.9,0.900015824083},{0.900303636788,0.900494031554,0.899999999613,0.899989845073,0.959584037227,0.900820967987,0.899999510503,0.899999564059,0.900229743684,0.901004705307},{0.899999875464,0.900314510992,0.900084706241,0.904053863171,0.983639347515,0.900255659834,0.85,0.85,0.900352502062,0.900909945291},{0.901101787673,0.901535737023,0.900422957461,0.901445798024,0.900194398039,0.89998372505,0.900181987845,0.899998655638,0.901306986303,0.900501024368},{0.900000000627,0.9,0.900000869844,0.9,0.995513485676,0.900392032904,0.900033330008,0.899999996333,0.9,0.9},{0.900311719929,0.900368852583,0.900658758026,0.901979798656,0.900055989781,0.900160157214,0.900022648283,0.901746269795,0.9,0.85}},
        {{0.994628742332,0.85,0.899908176595,0.85,0.85,0.85,0.110324411756,0.896705838038,0.85,0.902606162357},{0.85,0.29703665273,0.389599291971,0.85,0.138218329417,0.85,0.89997998188,0.899952004405,0.899950430693,0.141026032289},{0.901022534303,0.979741505432,0.495284890286,0.900393843698,0.899990676773,0.899999826335,0.899967938846,0.897898665273,0.85,0.899987440126},{0.502578814051,0.467238380078,0.368144779809,0.85,0.85,0.75,0.85,0.85,0.266823328349,0.85},{0.899950266961,0.85,0.899950151601,0.85,0.85,0.330668050172,0.309518723106,0.85,0.971194056063,0.89502424543},{0.81307412946,0.899988281148,0.900888224869,0.896660602283,0.90018634308,0.896703209784,0.900757305452,0.75,0.900939467656,0.899997442655},{0.998931852168,0.900077705034,0.901818212876,0.959715567492,0.900193709058,0.904162697633,0.899674087817,0.85,0.902070627865,0.901377354976},{0.895026445814,0.488692892239,0.85,0.90095469465,0.85,0.85,0.899956120351,0.75,0.92655345317,0.899964159087},{0.85,0.85,0.35874507889,0.899501328623,0.232886745811,0.940602298044,0.899995030845,0.899999998699,0.85,0.058717612232},{0.899799703187,0.9005741777,0.899953581789,0.418134098331,0.899703567293,0.899958289363,0.879185204474,0.75,0.899991558016,0.048554948576}},
        {{0.85,0.900377769294,0.9,0.900352675986,0.85,0.899999997898,0.89999980519,0.899999980537,0.900184544865,0.902307275203},{0.899999996732,0.896700733512,0.85,0.9,0.985554536576,0.9,0.9,0.900143457727,0.900516371648,0.85},{0.89999610792,0.85,0.899970328532,0.900167815719,0.900118919952,0.899997697614,0.900861675629,0.899999997615,0.85,0.899999066882},{0.899999999987,0.900903894194,0.899999982389,0.899999951986,0.98629711066,0.899999956398,0.899997934162,0.900084504001,0.934598834193,0.899987065784},{0.9,0.899984484299,0.899952116393,0.85,0.900356964104,0.85,0.899999977662,0.899999832057,0.85,0.85},{0.900359931432,0.940364438185,0.900859846324,0.901112012918,0.900581341359,0.900439938077,0.85,0.900836948812,0.050172429579,0.995033767449},{0.902523949127,0.899980968465,0.85,0.899950014817,0.201849421674,0.9,0.85,0.85,0.900335308984,0.89997299084},{0.899998526168,0.901978226992,0.901284616076,0.900790892142,0.901032637109,0.85,0.89997715385,0.89999715125,0.900180571827,0.900707873036},{0.899999997745,0.900076202436,0.900357841316,0.129490035707,0.899995090029,0.900338724466,0.901823203984,0.900824823731,0.899999897129,0.85},{0.90030739015,0.900370487012,0.89501499527,0.941693193231,0.956816309091,0.900109969669,0.900534712502,0.900068729259,0.85,0.85}},
        {{0.964729703666,0.919626194037,0.899999983388,0.900373055026,0.973789333627,0.900137823275,0.85,0.899999592531,0.297494430372,0.97027497177},{0.900335411909,0.975797437767,0.899998298775,0.89999995772,0.900238235295,0.89995017336,0.895007649464,0.899997733586,0.35645619068,0.900691922428},{0.94892220439,0.899951420915,0.439802240059,0.689382610553,0.900539496546,0.064912869655,0.358928189947,0.072450941496,0.203344828639,0.322000793481},{0.954864049501,0.901007557425,0.899503069094,0.900136260612,0.989335646078,0.899999956371,0.900888320335,0.85,0.85,0.89502091586},{0.899999998431,0.899500010529,0.900873764507,0.900850162805,0.899967582141,0.94450439916,0.900097012517,0.900714704617,0.85,0.85},{0.897518730735,0.901719030705,0.899954913633,0.902385230749,0.902688184053,0.900495886726,0.936457121494,0.899500592212,0.899977672311,0.281197546312},{0.75,0.85,0.319193090609,0.900426571736,0.900267487623,0.953428795026,0.85,0.788323618274,0.942747276223,0.509414960173},{0.977366278421,0.799249244667,0.973265785699,0.900736180229,0.899998976545,0.939962545823,0.900367843013,0.900592450766,0.900863290571,0.9004368603},{0.901049766595,0.901196918029,0.899979316103,0.895029750969,0.90059325876,0.901361078206,0.90032191922,0.90011540123,0.900100826455,0.899973179621},{0.8537858211,0.900485951042,0.89999288302,0.417371135594,0.900316864328,0.899995565661,0.902498681598,0.901045643115,0.90219885957,0.85}},
        {{0.899995256043,0.899999952634,0.991576891385,0.919163631025,0.85,0.97333732078,0.03555406354,0.899999502176,0.9002836509,0.321390423292},{0.899999806891,0.85,0.899999708757,0.968933117468,0.85,0.85,0.85,0.899999999503,0.85,0.85},{0.85,0.85,0.899998257244,0.921349190091,0.899999504732,0.900619615967,0.901216650277,0.85,0.901114168361,0.900877141987},{0.85,0.900096097626,0.899945676855,0.976343234199,0.899504479354,0.89999999956,0.9,0.900249329241,0.900077770197,0.899950165059},{0.85,0.900610482759,0.899950224754,0.901059978238,0.899999018656,0.899951043388,0.90044442528,0.899990974262,0.85,0.85},{0.85,0.85,0.901010326809,0.85,0.85,0.900731215304,0.899463904385,0.900710703558,0.900077456431,0.869257606739},{0.85,0.899998023982,0.899529875027,0.992064119387,0.909068466599,0.972029648666,0.85,0.85,0.220831934568,0.85},{0.267799920652,0.900819256877,0.85,0.902411767067,0.903097650967,0.90244850467,0.900432725205,0.89950258446,0.899998147833,0.899993715374},{0.900646314904,0.900573132629,0.899999996804,0.85,0.899997798374,0.900006002804,0.899999997136,0.900878079492,0.899999996876,0.85},{0.899999998578,0.75,0.85,0.90057426396,0.899949760994,0.899995002477,0.929679876095,0.900634379559,0.899975228287,0.85}},
        {{0.8950116657,0.959844145711,0.85,0.85,0.899998000006,0.85,0.85,0.900026528356,0.926156857263,0.350962858974},{0.909482100894,0.75,0.85,0.85,0.85,0.899483774682,0.85,0.551347392193,0.895002500992,0.782464064455},{0.465681936094,0.900709826847,0.85,0.973906674398,0.929979016088,0.118137150182,0.900342038837,0.900225952008,0.85,0.391888180181},{0.85,0.85,0.897876276278,0.223944822535,0.90028269638,0.542405468917,0.85,0.900055885581,0.899998647613,0.959801517075},{0.899999511605,0.85,0.899941082018,0.196722312082,0.896758519242,0.85,0.75,0.85,0.899693043077,0.897368279061},{0.895045034143,0.85,0.381572923978,0.900063690756,0.85,0.85,0.900951144716,0.900672034761,0.901424378547,0.900355141605},{0.326425977355,0.900245192496,0.901277758006,0.187292092654,0.85,0.65462202826,0.9,0.85,0.899971463142,0.905301065096},{0.85,0.901488269237,0.900249675554,0.900678222654,0.29352702414,0.85,0.899998894197,0.901180185321,0.472151860103,0.901351040713},{0.85,0.85,0.85,0.85,0.900612358942,0.899986700586,0.900140754519,0.321756645405,0.992706076235,0.900741131084},{0.900285260905,0.900936326425,0.903214070243,0.900480916623,0.85,0.900074415248,0.900593183276,0.901123230202,0.973064321299,0.228339487899}}
     };

   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   if(FileIsExist(add,FILE_COMMON))
     {
      int file_handle=FileOpen(add,FILE_READ|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_CSV,';');
      for(w=0; w<n_holes; w++)
        {
         for(j=0; j<prof_cube; j++)
           {
            for(i=0; i<n_candles; i++)
              {
               Matriz[w][j][i]=StringToDouble(FileReadString(file_handle));
              }
           }
        }
      FileClose(file_handle);
     }
   else
     {
      printf("arquivo "+add+" nao encontrado");
      if(tipo_erro==true)
         for(w=0; w<n_holes; w++)
            for(j=0; j<prof_cube; j++)
               for(i=0; i<n_candles; i++)
                  Matriz[w][j][i]=matriz_ini_erro[w][j][i];
      else
         for(w=0; w<n_holes; w++)
            for(j=0; j<prof_cube; j++)
               for(i=0; i<n_candles; i++)
                  Matriz[w][j][i]=matriz_ini_match[w][j][i];
     }
  }
//+------------------------------------------------------------------+
//|  funcao para salvar vetor dos erros aceitaveis em csv                                                           |
//+------------------------------------------------------------------+
void salvar_vet_csv(double &vet[],string path)
  {
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   string linha="";
   FileDelete(add);
   int handle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_TXT);
   int size=ArraySize(vet);
   int i=0;
   for(i=0; i<size-1; i++)
     {
      linha+=DoubleToString(vet[i],12);
      linha+=";";
     }
   linha+=DoubleToString(vet[i],12);
   FileWrite(handle,linha);
   linha="";
   FileClose(handle);
  }
//+------------------------------------------------------------------+
//|  funcao para salvar vetor dos erros aceitaveis em csv                                                           |
//+------------------------------------------------------------------+
void ler_vet_csv(double &vet[],string path, int qual)
  {
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   double vet_ini_erro[n_holes]; //n_holes
   ArrayFill(vet_ini_erro,0,n_holes,-2000*Min_Val_Neg);
   double vet_ini_parametrizadores[12]= {0.042,17.08,0.3,2927,3500,-0.005,0.8,0.55,0.5,0.73,1.16,1.16};
//modulador
//media lenta
//tendencia
//dist_tp
//dist_sl
//m_parametros---obsoleto
//op_gain
//counter_tp
//m1
//m2
//m3
//m4
//double vet_ini_parametros[prof_cube]= {0,0,0,0,0,0,0,0,0,0};
   double vet_ini_distancias[n_holes];
   ArrayFill(vet_ini_distancias,0,n_holes,0);
   int size=ArraySize(vet);
   if(FileIsExist(add,FILE_COMMON))
     {
      int file_handle=FileOpen(add,FILE_READ|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_CSV,';');
      for(int i=0; i<size; i++)
        {
         vet[i]=StringToDouble(FileReadString(file_handle));
        }
      FileClose(file_handle);
     }
   else
     {
      if(qual==0)
        {
         for(int j=0; j<size; j++)
           {
            vet[j]=vet_ini_erro[j];
           }
        }
      else
         if(qual==1)
           {
            printf("Vetor parametrizadores n encontrado");
            for(int j=0; j<size; j++)
              {
               vet[j]=vet_ini_parametrizadores[j];
              }
           }
         else
            if(qual==3)
              {
               for(int j=0; j<size; j++)
                 {
                  vet[j]=vet_ini_distancias[j];
                 }
              }

     }

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
