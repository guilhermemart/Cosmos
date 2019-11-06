//+------------------------------------------------------------------+
//|                                                   OneKickMan.mq5 |
//|                                               Senhor_dos_Pasteis |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>

#define n_holes 20//metade inicial é hole de venda e a final hole de compra, declarar aqui apenas valores par
#define n_candles 10
#define prof_cube 10
//---
//---Variaveis globais
//---
ENUM_TIMEFRAMES Periodo=_Period;
COrderInfo info;
CTrade trade;
input int Clear=1;
input int lotes=1;
double m1 = 0.5;
double m2= 0.52;
double m3=0.5;
double m4=0.5;
double restore_m1=0.5;
double restore_m2=0.5;
double restore_m3=0.5;
double restore_m4=0.5;
double temp_m2=0.8;
double temp_m3=0.8;
double temp_m4=1;
input double prox_fact_loss=0.75;
input double afast_fact_loss_real=1;
input double afast_fact_loss_n_real=0.5;
input double prox_fact_loss_viz=1;
input double afast_fact_loss_viz=1;
input double prox_fact_gain=2;
input double afast_fact_gain=1;
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
double Const_dist=3500;//usado para normalizar os valores da matriz now (obsoleta)
double temp_dist=0.2;//variavel que salva a distancia que deu certo
double dist_tp=2500;//distancia em que as distancias medidas são aceitas como certeiras
double dist_sl=3500;//distancias em que as distancias medidas são consideradas falhas
double counter_t_profit=0.4;//media da contagem dos acertos
double op_gain=1;//medias da contagem dos acertos que permite entrada
double last_op_gain=0;//salva o op_gain anterior para substituir o op_gain novo que deu stop
int treinamento_ativo=NULL;//variavel para avisar a funcao stop que foi uma entrada virtual
double Buy_Sell_Simulado=0;//ask ou bid para simulação de stop ou gain
bool fim_do_pregao=true;//variavel setada como true até o inicio do horario do pregão
datetime    tm=TimeCurrent();//variavel para detectar inicio e fim de pregão
MqlDateTime stm;//variavel para receber tm como struct
//uint end=GetTickCount();  //horario atual em datetime nao convertido
//uint timer=GetTickCount();
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
int loss_suportavel_dia=1;//qtdd de loss suportavel em um dia
int op_media=0;//variavel para receber definição de padroes de entrada
int op_media_virtual=0;
double forcar_entrada=450;//para não entrar em operações muito rapidamente
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
double m_parametros[prof_cube];//normalizadores para os termos da matriz now
double m_pre_par[prof_cube];//salva a matriz parametros para recuperar em caso de loss
int analisados[prof_cube][n_candles];//matriz para não repetir a atualização de candles já aprox/afastados
double tendencia=0;//salva a tendencia atual para uso durante as operações
int posicoes=0;//posicionado ou não
bool fechou_posicao=false;//já ouve a ordem de fechar posicoes e ainda não foi executada
double stopar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);//valor para stopar de emergancia
double gainar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);//valor para take_profit de emergencia
int m_handle_close=NULL;//handle para invocar a media de fechamento personalizada
int handle_touch=NULL;
double m_volumetricas[5];//vetor com os 5 ultimos medias volumetricas
double m_close[n_candles];//media
//int primeiro_t_media_cp=0;
//int primeiro_t_media_venda=0;
int alfa_c=0;
int alfa_v=0;
int tentativa=0;
double temp_tend=0;
int m_handle_periodo;

//+------------------------------------------------------------------+
//|Funcao para salvar matrizes n_holes x n_candles                   |
//+------------------------------------------------------------------+
void salvar_matriz_N_4_30(double  &matriz[][prof_cube][n_candles],string path);
//+------------------------------------------------------------------+
//|  funcao para salvar vetor dos erros aceitaveis                   |
//+------------------------------------------------------------------+
void salvar_vet_erro(double &erro[],string path);
//+------------------------------------------------------------------+
//| Salvar parametrizadores                               |
//+------------------------------------------------------------------+
void salvar_parametrizadores(double &paramet[],string path);
//+------------------------------------------------------------------+
//|Salvar os parametrizadores da funcao Now - brain (vetor[prof.cubo])                                                                 |
//+------------------------------------------------------------------+
void salvar_m_parametros(double &paramet[],string path);
//+------------------------------------------------------------------+
//| le matrizes Nx4x30 do disco                                      |
//+------------------------------------------------------------------+
void ler_matriz_N_4_30(double  &matriz[][prof_cube][n_candles],string path,bool tipo_erro);
//+------------------------------------------------------------------+
//| Aproxima matrizes por um fator 10%    N dimensoes                |
//+------------------------------------------------------------------+
void aproximar_matriz_N(double &Matriz_temp[][prof_cube][n_candles],double &Matriz_erro[][prof_cube][n_candles],int D);
//+------------------------------------------------------------------+
//|Copia M2 em M1       N dimensoes                                                           |
//+------------------------------------------------------------------+
void copiar_matriz_N(double &M1[][prof_cube][n_candles],double &M2[][prof_cube][n_candles],int D);
//+------------------------------------------------------------------+
//| Ler vetor erro //se não existir já cria                                                               |
//+------------------------------------------------------------------+
void ler_vetor_erro_aceitavel(string path);
//+------------------------------------------------------------------+
//|ler vetor parametros       //se não existir já cria                                                           |
//+------------------------------------------------------------------+
void ler_vetor_parametros(string path);
//+------------------------------------------------------------------+
//+mattriz (vetor) Now-Match
//|//se não existir já cria//nunca chamar antes de ler parametros                                                                  |
//+------------------------------------------------------------------+
void ler_matriz_parametros(string path);
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
void estabiliza_matriz();
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
   ArrayFill(distancias,0,n_holes,100000);
   ArrayInitialize(Vet_erro,-1);
   ArrayInitialize(Vet_temp_erro,-1);
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   Min_Val_Neg=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   stopar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
   gainar=SymbolInfoDouble(_Symbol,SYMBOL_LAST);

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
   ler_matriz_csv(super_brain,"cosmos_training"+"//"+"match"+"//"+"csv",false);
//Ler/inicializar matriz diferencas/erro
   //ler_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro",true);
   ler_matriz_csv(m_erro_brain,"cosmos_training"+"//"+"erro"+"//"+"csv",false);
//Gerar arrays copia dos arrays salvos
//Usados para retornar ao valor anterior caso de loss em uma operacao
   for(int x=0; x<n_holes; x++)
      copiar_matriz_N(m_e_temp_brain,m_erro_brain,x);
//ler erros aceitaveis
   ler_vetor_erro_aceitavel("cosmos_training"+"//"+"Ve");
//ler parametros de configuração
   ler_vetor_parametros("cosmos_training"+"//"+"Vp");
   recover_tend=parametrizadores[2];
   dist_tp=parametrizadores[3];
   dist_sl=parametrizadores[4];
   op_gain=parametrizadores[6];
   last_op_gain=op_gain;
   counter_t_profit=parametrizadores[7];
//m1=0.5;
//m2=0.8;//parametrizadores[9];
//m3=0.8;//parametrizadores[10];
//m4=0.8;//parametrizadores[11];
   ArrayInitialize(distancias,0.0);
   ler_matriz_parametros("cosmos_training"+"//"+"Mp");
   ler_distancias_0("cosmos_training"+"//"+"Vd0");
   ArrayInitialize(Vet_temp_erro,0);
   EventSetMillisecondTimer(400);// number of seconds ->0.4 segundos por evento
//tm=TimeCurrent();
//TimeToStruct(tm,stm);
   fim_do_pregao=stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<9) || (stm.hour==9 && stm.min<=30);
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
// m_handle_ima=iMA(_Symbol,_Period,21,0,MODE_EMA,PRICE_CLOSE);//int(MathRound(parametrizadores[1]))
   temp_tend=parametrizadores[2];
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
   parametrizadores[8]=m1;
   parametrizadores[9]=m2;
   parametrizadores[10]=m3;
   parametrizadores[11]=m4;
//salvar os arrays de match (brain)
   salvar_matriz_N_4_30(super_brain,"cosmos_training"+"//"+"match");
   Salvar_Matriz_csv(super_brain,"cosmos_training"+"//"+"match"+"//"+"csv");
//salvar as matrizes de erro
   salvar_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro");
   Salvar_Matriz_csv(m_erro_brain,"cosmos_training"+"//"+"erro"+"//"+"csv");
//Salvar os erros aceitaveis
   salvar_vet_erro(Vet_erro,"cosmos_training"+"//"+"Ve");
//Salvar parametros
   salvar_parametrizadores(parametrizadores,"cosmos_training"+"//"+"Vp");
   salvar_m_parametros(m_parametros,"cosmos_training"+"//"+"Mp");
   salvar_distancias_0(distancias,"cosmos_training"+"//"+"Vd0");
//Verificar escrita em disco
   double parametro_open=m_parametros[0];
   double erro_0 = Vet_erro[0];
   double match_0=super_brain[0][0][0];
   double erro_brain=m_erro_brain[0][0][0];
   ler_vetor_parametros("cosmos_training"+"//"+"Vp");
   ler_matriz_parametros("cosmos_training"+"//"+"Mp");
   ler_vetor_erro_aceitavel("cosmos_training"+"//"+"Ve");
   //ler_matriz_N_4_30(super_brain,"cosmos_training"+"//"+"match",false);
   ler_matriz_csv(super_brain,"cosmos_training"+"//"+"match"+"//"+"csv",false);
   //ler_matriz_N_4_30(m_erro_brain,"cosmos_training"+"//"+"erro",true);
   ler_matriz_csv(m_erro_brain,"cosmos_training"+"//"+"erro"+"//"+"csv",true);
   if(parametrizadores[3]!=dist_tp)
      printf("Warning, parametrizadores salvos incorretamente");
   if(parametro_open!=m_parametros[0])
      printf("Warning,parametros normalizadores salvos incorretamente");
   if(match_0!=super_brain[0][0][0])
      printf("Warning,Holes salvos incorretamente %f.3 != %f.3",match_0,super_brain[0][0][0]);
   if(erro_brain!=m_erro_brain[0][0][0])
      printf("Warning,potencializadores salvos incorretamente %f.3 != %f.3" ,erro_brain,m_erro_brain[0][0][0]);
   if(erro_0!=Vet_erro[0])
      printf("Warning,erros aceitaveis salvos incorretamente");
   printf("parametros de aproximação: m1: %f.3 m2: %f.3 m3: %f.3 m4: %f.3",m1,m2,m3,m4);
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
   if(m_handle_close==NULL)
      m_handle_close=iMA(simbolo,_Period,21,0,MODE_EMA,PRICE_CLOSE);//iCustom(_Symbol,_Period,"MASVol",int(MathRound(parametrizadores[1])));
   if(CopyBuffer(m_handle_close,0,0,n_candles,m_close)==-1)
     {
      ArrayInitialize(m_close,0);
      printf("problemas com o indicador");
      m_handle_close=NULL;
     }
   if(handle_touch==NULL)
      handle_touch=iMA(simbolo,_Period,1,0,MODE_EMA,PRICE_CLOSE);//iCustom(_Symbol,_Period,"MASVol",int(MathRound(parametrizadores[1])));
   if(CopyBuffer(handle_touch,0,0,5,m_volumetricas)==-1)
     {
      ArrayInitialize(m_volumetricas,0);
      printf("problemas com o indicador");
      handle_touch=NULL;
     }
   int i=0;
   if(posicoes==0 && fim_do_pregao==false && on_trade==false)
     {
      if(CopyClose(simbolo,Periodo,0,n_candles,close)!=-1 && CopyOpen(simbolo,Periodo,0,n_candles,open)!=-1 && CopyHigh(simbolo,Periodo,0,n_candles,high)!=-1 && CopyLow(simbolo,Periodo,0,n_candles,low)!=-1)
        {
         double minimo=low[ArrayMinimum(low,0)];
         i=0;
         while(i<n_candles)
           {
            if(MathIsValidNumber(open[i]) && MathIsValidNumber(close[i]) && MathIsValidNumber(high[i]) && MathIsValidNumber(low[i]))
              {
               //copiano candles 30 ultimos normalizados
               m_now[prof_cube-10][i]=close[i]-minimo-m_parametros[prof_cube-10];
               m_now[prof_cube-9][i]=open[i]-minimo-m_parametros[prof_cube-9];
               m_now[prof_cube-8][i]=low[i]-minimo-m_parametros[prof_cube-8];
               m_now[prof_cube-7][i]=high[i]-minimo-m_parametros[prof_cube-7];
               m_now[prof_cube-6][i]=m_close[i]-minimo-m_parametros[prof_cube-6];
               m_now[prof_cube-5][i]=close[i]-open[i]-m_parametros[prof_cube-5];
               m_now[prof_cube-4][i]=close[i]-high[i]-m_parametros[prof_cube-4];
               m_now[prof_cube-3][i]=close[i]-low[i]-m_parametros[prof_cube-3];
               m_now[prof_cube-2][i]=close[i]-m_close[i]-m_parametros[prof_cube-2];
               m_now[prof_cube-1][i]=high[i]-low[i]-m_parametros[prof_cube-1];
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
      if(op_media>=4)
        {
         double resistencia=next_resist()-8*Min_Val_Neg;
         if(close[n_candles-1]>resistencia)
            op_media=0 ;
        }
      else
         if(op_media<=-4)
           {
            double suporte= next_suporte()+8*Min_Val_Neg;
            if(close[n_candles-1]<suporte)
               op_media=0;
           }
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
         //     timer=GetTickCount();
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         if((d_compra_menor)<1.01*(0.95*dist_tp+0.05*dist_sl+5*Min_Val_Neg))
            simulacao_contabil=1;//operar na media nao contabiliza
         else
            simulacao_contabil=0;//compra simulada não será contabilizada
         if(compra==true && posicoes==0 && tendencia>=parametrizadores[2]*Min_Val_Neg && qtdd_loss<loss_suportavel_dia && (forcar_entrada)>=900 && (op_media>=4 || ((d_compra_menor)<1.1*dist_tp && counter_t_profit>op_gain)))
           {
            trade_type=1+alfa_c;//ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);
            trade_type_reverso=1+alfa_v;//ArrayMinimum(distancias,0,n_holes/2);
            stopar=ask-8*Min_Val_Neg;
            gainar=ask+8*Min_Val_Neg;
            trade.Buy(lotes,_Symbol,ask,stopar,gainar,"Compra dist "+string(trade_type)+" mean "+string(op_media)+" tend: "+string(tendencia)+" Tf: "+string(_Period));
            printf("------------Compra-------- "+string(ask)+" tendencia: "+string(parametrizadores[2]*Min_Val_Neg));
            Buy_Sell_Simulado=ask;
            Stop_tp_Simulado=ask;
            on_trade=true;
            //on_trade_simulado=false;
            treinamento_ativo=0;
            //end=GetTickCount();
            forcar_entrada=1;
            tentativa+=1;
            temp_tend=tendencia;
            Sleep(3000);
           }
         else
           {
            if(tendencia<parametrizadores[2]*Min_Val_Neg&&op_media>=4)
               printf("compra bloqueada por tendencia");
            if(op_media<+4&&forcar_entrada>=1200&&compra&&tendencia>=0)//simula uma compra na media
              {
               //forcar_entrada=900;
               Stop_tp_Simulado=last;
               if(on_trade_simulado==false)
                 {
                  Buy_Sell_Simulado=ask;
                  trade_type=1+alfa_c;
                  trade_type_reverso=1+alfa_v;//ArrayMinimum(distancias,0,n_holes/2);
                  on_trade_simulado=true;
                  treinamento_ativo=1;
                  op_media_virtual=1;
                  temp_tend=tendencia;
                  //distancia=d_compra_menor-Vet_erro[alfa_c];
                  printf("distancia de entrada em compra media simulada:%.3f dist hole:%.3f tendencia:%.3f tend_min_aceitavel:%.3f ",distancia,distancias[ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY)],tendencia,parametrizadores[2]);
                 }
               else
                  if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
                    {
                     on_trade=true;
                     treinamento_ativo=6;
                     on_trade_simulado=false;
                     forcar_entrada=900;
                    }
              }

            else
               if(ArrayMinimum(distancias,0)>=n_holes/2&&forcar_entrada>=1200)//simula uma compra forcada
                 {
                  //forcar_entrada=900;
                  Stop_tp_Simulado=last;
                  if(on_trade_simulado==false)
                    {
                     Buy_Sell_Simulado=ask;
                     trade_type=1+ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);
                     trade_type_reverso=1+alfa_v;//ArrayMinimum(distancias,0,n_holes/2);
                     on_trade_simulado=true;
                     treinamento_ativo=1;
                     temp_tend=parametrizadores[2];
                     printf("distancia de entrada em compra:%.3f dist hole:%.3f tendencia:%.3f tend_min_aceitavel:%.3f ",distancia,distancias[ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY)],tendencia,parametrizadores[2]);
                    }
                  else
                     if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
                       {
                        on_trade=true;
                        treinamento_ativo=6;
                        on_trade_simulado=false;
                        forcar_entrada=900;
                       }
                 }
           }
        }
      else
         if(op_media_virtual>0)
           {
            if(MathAbs(Buy_Sell_Simulado-Stop_tp_Simulado)>=8*Min_Val_Neg)
              {
               on_trade=true;
               treinamento_ativo=6;
               on_trade_simulado=false;
               forcar_entrada=900;
              }
           }
      if((d_venda_menor-Vet_erro[alfa_v]<1*distancia || op_media<=-1) && posicoes==0 && on_trade==false)//&&venda==true
        {

         //timer=GetTickCount();
         last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
         //Analise de venda
         if(((d_venda_menor)<1.01*(0.95*dist_tp+0.05*dist_sl+5*Min_Val_Neg)))
            simulacao_contabil=1;//valido como entrada para atualizar parametros
         else
            simulacao_contabil=0;
         if(venda==true && posicoes==0 && tendencia<=-parametrizadores[2]*Min_Val_Neg && qtdd_loss<loss_suportavel_dia && (forcar_entrada)>=900 && (op_media<=-4 || ((d_venda_menor)<1.1*dist_tp && counter_t_profit>=op_gain)))//aguarda ao menos 5min antes da proxima operação real
           {
            //vender
            trade_type=1+alfa_v;//ArrayMinimum(distancias,0,n_holes/2);
            trade_type_reverso=1+alfa_c;//ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);
            stopar=bid+8*Min_Val_Neg;
            gainar=bid-8*Min_Val_Neg;
            trade.Sell(lotes,_Symbol,bid,stopar,gainar,"Venda dist "+string(trade_type)+" mean "+string(op_media)+" tend: "+string(tendencia)+" Tf: "+string(_Period));
            printf("------------V. distancia-----------"+string(bid)+" tendencia: "+string(-parametrizadores[2]*Min_Val_Neg));
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
            Sleep(3000);
            Comment("Timeframe de entrada:"+string(_Period));
           }
         else
           {
            if(op_media>-4&&forcar_entrada>=1200&&venda&&tendencia<=0)
              {
               //forcar_entrada=900;
               Stop_tp_Simulado=last;
               if(on_trade_simulado==false)
                 {
                  //primeira passagem pela entrada virtual
                  Buy_Sell_Simulado=bid;
                  trade_type=1+alfa_v;
                  trade_type_reverso=1+alfa_c;
                  on_trade_simulado=true;
                  treinamento_ativo=-1;
                  op_media_virtual=-1;
                  temp_tend=-tendencia;
                  //distancia=d_venda_menor-Vet_erro[alfa_v];
                  printf("media venda simulada distancia de entrada em venda:%.3f dist hole:%.3f tendencia:%.3f tend_min_aceitavel: -%.3f",distancia,distancias[ArrayMinimum(distancias,0,n_holes/2)],tendencia,parametrizadores[2]);
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
               if(ArrayMinimum(distancias,0)<n_holes/2&&forcar_entrada>=1200)//só  entrada venda virtual forcada
                 {
                  //forcar_entrada=900;
                  Stop_tp_Simulado=last;
                  if(on_trade_simulado==false)
                    {
                     //primeira passagem pela entrada virtual
                     Buy_Sell_Simulado=bid;
                     trade_type=1+alfa_v;
                     trade_type_reverso=1+ArrayMinimum(distancias,n_holes/2,WHOLE_ARRAY);
                     on_trade_simulado=true;
                     treinamento_ativo=-1;
                     temp_tend=parametrizadores[2];
                     printf("distancia de entrada em venda:%.3f dist hole:%.3f tendencia:%.3f tend_min_aceitavel: -%.3f",distancia,distancias[ArrayMinimum(distancias,0,n_holes/2)],tendencia,parametrizadores[2]);
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
      //end=GetTickCount();
      double lucro_prej=0;
      if(compra)
         lucro_prej+=last_trade-l_last_trade;
      else
         if(venda)
            lucro_prej-=last_trade-l_last_trade;
      if(lucro_prej<=0)
         qtdd_loss+=1;
      stop=true;//considera um stop true, caso seja gain esse valor será atualizado para false
      printf("operaçao real lucro/prej.: "+string(lucro_prej));
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
   int ind_max[2]= {0,0};
   int ind_min[2]= {0,0};
   if((compra && l_last_trade>=last_trade) || (venda && l_last_trade<=last_trade))
     {
      //--================----loss - aproxima pouco afasta muito
      oper_counter-=1;
      ArrayFill(analisados,0,prof_cube*n_candles,0);
      //caso de loss procurar o indice do maior erro e aproximar
      //significa que aquele valor era importante
      //fazer essa alteração 12 x (10% da matriz)
      aproximar_candles(int(0.3*prof_cube*n_candles),prox_fact_loss,0);
      //manter a mesma distancia para não alterar o resultado da operação de afastamento
      //caso de loss procurar o indice do menor erro e afastar
      //significa que aquele valor nao era importante
      //fazer essa alteração  (25% dos candles)
      if(treinamento_ativo==0)//operacao foi real
         afastar_candles(int(0.6*prof_cube*n_candles),afast_fact_loss_real,0);
      else
         afastar_candles(int(0.6*prof_cube*n_candles),afast_fact_loss_n_real,0);
      ArrayFill(analisados,0,prof_cube*n_candles,0);
      //----------trabalhando com as vizinhancas - aproxima muito afasta pouco
      //caso de loss procurar todoso indice do menor erro da operacao inversa e tratar como gain
      //diferente de tratar a operacao isso aproxima holes distantes do valor now
      //significa que aquele valor era para ser o de real entrada
      //fazer essa alteração  (25% dos candles)
      afastar_candles(int(0.3*prof_cube*n_candles),afast_fact_loss_viz,2);//operar vizinhanca, tratar como gain a operacao inversa
      aproximar_candles(int(0.4*prof_cube*n_candles),prox_fact_loss_viz,2);//operar vizinhanca, tratar como gain a operacao inversa
      Normalizar_erros();//normalizar erros
      erro[hole]=0.8*erro[hole]+0.2*temp_erro[hole]-(0.55*distancia);//diminuir esse valor para dificultar um nova entrada (para treinamento)
      if(simulacao_contabil==1)
        {
         counter_t_profit+=(0-counter_t_profit)/21;
         dist_sl=MathMin(dist_sl+(distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_sl)/(0.9*n_candles),1.5*dist_tp);
         dist_tp=MathMin(dist_tp+((distancias[trade_type_reverso-1]+Vet_erro[trade_type_reverso-1]-dist_tp)/(0.9*n_candles)),1000000000000);
        }
      else
        {
         dist_sl=MathMax(MathMin((distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_sl)/200,1.2*dist_tp),1.2);
         dist_tp=MathMax(MathMin(dist_tp+((distancias[trade_type_reverso-1]+Vet_erro[trade_type_reverso-1]-dist_tp)/200),1000000000000),1);
        }
      //copiar_matriz_N(m_erro,m_temp_erro,trade_type-1);
      parametrizadores[0]+=0.05*(16383.5-MathRand())*Min_Val_Neg/(16383.50);//alimentar o modulador
      parametrizadores[0]=0.5*parametrizadores[0]+0.5*Modulador;
      parametrizadores[0]=MathMax(MathMin(parametrizadores[0],0.005),0.001);
      Oscilar_matriz(m_parametros,m_pre_par);
      parametrizadores[5]=m_parametros[4];
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
      distancia=temp_dist*0.2;
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
         afastar_candles(int(0.3*prof_cube*n_candles),afast_fact_gain,1);
         //caso de gain procurar o indice de menor  erro e reduzir a distancia
         //alterar m_erro para manter a mesma distancia (aumentar a significancia)
         //significa que aquele valor era importante
         //fazer essa alteração 6 x (5% dos candles)
         aproximar_candles(int(0.5*prof_cube*n_candles),prox_fact_gain,1);
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
            dist_tp=MathMin(dist_tp+((distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_tp)/(0.9*n_candles)),1000000000000);
           }
         else
            dist_tp=MathMax(MathMin(dist_tp+((distancias[trade_type-1]+Vet_erro[trade_type-1]-dist_tp)/(200)),1000000000000),1);
         if(dist_tp==1000000000000)
            parametrizadores[0]+=0.03*(16383.5-MathRand())*Min_Val_Neg/(16383.50);
         Modulador=parametrizadores[0];
         estabiliza_matriz();
         Const_dist=parametrizadores[5];
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
         distancia=0.2*temp_dist;
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
   parametrizadores[3]=dist_tp;
   parametrizadores[4]=dist_sl;
   parametrizadores[6]=op_gain;
   parametrizadores[7]=counter_t_profit;
   //salvar_matriz_N_4_30(match,"cosmos_training"+"//"+"match");
   Salvar_Matriz_csv(super_brain,"cosmos_training"+"//"+"match"+"//"+"csv");
   //salvar_matriz_N_4_30(m_erro,"cosmos_training"+"//"+"erro");
   Salvar_Matriz_csv(m_erro,"cosmos_training"+"//"+"erro"+"//"+"csv");
   salvar_vet_erro(Vet_erro,"cosmos_training"+"//"+"Ve");
   salvar_parametrizadores(parametrizadores,"cosmos_training"+"//"+"Vp");
   salvar_m_parametros(m_parametros,"cosmos_training"+"//"+"Mp");
   salvar_distancias_0(distancias,"cosmos_training"+"//"+"Vd0");
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
   fim_do_pregao=stm.hour>17 || (stm.hour==17 && stm.min>=30) || (stm.hour<9) || (stm.hour==9 && stm.min<=45);
   if(fim_do_pregao==true)
     {
      //operar apenas apos 9:30 e antes das 17:30
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
      double incrementer=distancias[ArrayMinimum(distancias,0,WHOLE_ARRAY)]/4000;
      distancia=distancia+(incrementer);
      fechou_posicao=false;
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
//|Alguns parametros são atualizados durante o treinamento                                                                  |
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
//|Salvar os parametrizadores da funcao Now - brain (vetor[prof.cubo])                                                                 |
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
void salvar_distancias_0(double &paramet[],string path)
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
//| le matrizes Nx4x30 do disco                                     |
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
//| Ler vetor erro aceitavel//se nao existir já cria                                                                 |
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
//|ler vetor parametros       //se não existir já cria                                                           |
//+------------------------------------------------------------------+
void ler_vetor_parametros(string path)
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
      Modulador=parametrizadores[0];
      dist_tp=parametrizadores[3];
      dist_sl=parametrizadores[4];
     }

   /*parametrizadores[0]=0.0000001;
      parametrizadores[2]=0.03;*/
//parametrizadores[5]=7000*Min_Val_Neg;
  }
//+------------------------------------------------------------------+
//|//se não existir já cria//nunca chamar antes de ler parametros    |
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
  }
void ler_distancias_0(string path)//se não existir já cria//nunca chamar antes de ler parametros
  {
   uint ok=0;
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   ArrayInitialize(distancias,0.1*Min_Val_Neg);
//parametros de controle
   if(FileIsExist(add,FILE_COMMON))
     {
      int filehandle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
        {
         ok=FileReadArray(filehandle,distancias,0,WHOLE_ARRAY);
         FileClose(filehandle);
        }
     }
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
            m_erro_brain[d][i][j]=0.001*Min_Val_Neg;
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
void estabiliza_matriz()
  {
   for(int i=0; i<prof_cube; i++)
      m_pre_par[i]=m_parametros[i];
  }
//+------------------------------------------------------------------+
//|funcao que termo a termo as matrizes match com as matrizes |
//now(valores atuais) e decide se houve similaridade                 |
//funcao mais requisitada do expert                                  |
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
      err_aceitavel[tipo-1]=-2*Min_Val_Neg;
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
            d_temp+=0;
            if(!MathIsValidNumber(now[j][i]))
               now[j][i]=10000*Min_Val_Neg;
            if(!MathIsValidNumber(match[tipo-1][j][i]))
               match[tipo-1][j][i]=0.7*now[j][i];
            if(!MathIsValidNumber(m_erro[tipo-1][j][i]))
               m_erro[tipo-1][j][i]=0.0001*Min_Val_Neg;
           }
        }
      distancias[tipo-1]+=d_temp;//MathSqrt(d_temp);
      d_temp=0;
     }
   for(i=0; i<n_holes; i++)
      media_distancias+=(distancias[i]+err_aceitavel[i])/n_holes;
   if((distancias[tipo-1]+err_aceitavel[tipo-1])>=5*media_distancias+10*Min_Val_Neg)
     {
      printf("dist. muito grande: %.3f dist. aceit.: %3f regenerando matriz: %d Erro Aceit.: %.3f",distancias[hole-1]+err_aceitavel[tipo-1],media_distancias,tipo-1,err_aceitavel[tipo-1]);
      Embaralhar_matriz(m_erro_brain,hole-1);
      Recriar_matriz(super_brain,m_now,hole-1);
     }
   if(err_aceitavel[tipo-1]<=-5*media_distancias-10*Min_Val_Neg)
      err_aceitavel[tipo-1]=-5*media_distancias-10*Min_Val_Neg;
   return 1;
  }
//+------------------------------------------------------------------+
//|Funcao que define se tocou ou não na media                        |
//+------------------------------------------------------------------+
int Operar_na_Media(double &m_media[], double &m_volumetrica[])
  {
   int retorno=0;
   int charlie=ArraySize(m_volumetrica);
   if((low[n_candles-1]-m_media[n_candles-1])<=m1*Min_Val_Neg&&(low[n_candles-1]-m_media[n_candles-1]>=0))
     {
      //compra
      temp_m2=MathMax((m_volumetrica[charlie-2]-m_media[n_candles-2])/Min_Val_Neg,0.01);
      temp_m3=MathMax((m_volumetrica[charlie-3]-m_media[n_candles-3])/Min_Val_Neg,0.01);
      temp_m4=MathMax((m_volumetrica[charlie-4]-m_media[n_candles-4])/Min_Val_Neg,0.01);
      retorno=1;
      if(m_volumetrica[charlie-2]-m_media[n_candles-2]>=m2*Min_Val_Neg && m_volumetrica[charlie-2]-m_media[n_candles-2]<=(9*m2)*Min_Val_Neg&&low[n_candles-2]-m_media[n_candles-2]>=0)
        {
         retorno=2;
         if(m_volumetrica[charlie-3]-m_media[n_candles-3]>=m3*Min_Val_Neg)
           {
            retorno=3;
            if(m_volumetrica[charlie-4]-m_media[n_candles-4]>=m4*Min_Val_Neg || (m_volumetrica[charlie-3]-m_media[n_candles-3]>=m4*Min_Val_Neg || m_volumetrica[charlie-2]-m_media[n_candles-2]>=m4*Min_Val_Neg))
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
         temp_m2=MathMin((m_volumetrica[charlie-2]-m_media[n_candles-2])/Min_Val_Neg,0);
         temp_m3=MathMin((m_volumetrica[charlie-3]-m_media[n_candles-3])/Min_Val_Neg,0);
         temp_m4=MathMin((m_volumetrica[charlie-4]-m_media[n_candles-4])/Min_Val_Neg,0);
         retorno=-1;
         if(m_volumetrica[charlie-2]-m_media[n_candles-2]<=-m2*Min_Val_Neg && m_volumetrica[charlie-2]-m_media[n_candles-2]>=-(9*m2)*Min_Val_Neg&&high[n_candles-2]-m_media[n_candles-2]<=0)
           {
            retorno=-2;
            if(m_volumetrica[charlie-3]-m_media[n_candles-3]<=-m3*Min_Val_Neg)
              {
               retorno=-3;
               if(m_volumetrica[charlie-4]-m_media[n_candles-4]<=-m4*Min_Val_Neg || (m_volumetrica[charlie-3]-m_media[n_candles-3]<=-m4*Min_Val_Neg || m_volumetrica[charlie-2]-m_media[n_candles-2]<=-m4*Min_Val_Neg))
                 {
                  //printf("Toque na média aceitavel");
                  retorno =-4;//venda
                 }
              }
           }
        }
   return retorno;
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
int operar_t_line_strike()
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
                  //if(analisados[i][w]<1)
                  //{
                  analisado=MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w]);//m_erro_w_h_1[i][w];
                  ind[0]=i;
                  ind[1]=w;
                  // }
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
         //analisados[ind[0]][ind[1]]+=1;//ativado anti repeticao em loss
         analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
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
            if(m_erro_brain[trade_type-1][ind[0]][ind[1]]==0)
               m_erro_brain[trade_type-1][ind[0]][ind[1]]=0.000001*Min_Val_Neg;//Para a reducao não zerar m_erro
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
               if(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]==0)
                  m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=0.000001*Min_Val_Neg;//Para a reducao não zerar m_erro
               analisados[ind[0]][ind[1]]=1;
               analisado=MathAbs((m_now[0][0]-super_brain[trade_type_reverso-1][0][0])*m_erro_brain[trade_type_reverso-1][0][0]);
              }
           }
  }
//+------------------------------------------------------------------+
//| Aproxima candles dependendo de loss ou gain                                                                 |
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
                  //if(analisados[i][w]==0)
                  //{
                  analisado=MathAbs((m_now[i][w]-super_brain[trade_type-1][i][w])*m_erro_brain[trade_type-1][i][w]);
                  ind[0]=i;
                  ind[1]=w;
                  //}
                 }
         m_erro_brain[trade_type-1][ind[0]][ind[1]]*=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]);

         super_brain[trade_type-1][ind[0]][ind[1]]+=parametrizadores[0]*fator_de_aproximacao*(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]])-(0.001*(16383.5-MathRand())/16383.5)*Min_Val_Neg;//38

         m_erro_brain[trade_type-1][ind[0]][ind[1]]/=(m_now[ind[0]][ind[1]]-super_brain[trade_type-1][ind[0]][ind[1]]-0.000000001*Min_Val_Neg);
         m_erro_brain[trade_type-1][ind[0]][ind[1]]=0.2*m_e_temp_brain[trade_type_reverso-1][ind[0]][ind[1]]+0.9*m_erro_brain[trade_type-1][ind[0]][ind[1]];
         //funcao de ativacao
         m_erro_brain[trade_type-1][ind[0]][ind[1]]=MathMax(MathMin(m_erro_brain[trade_type-1][ind[0]][ind[1]],10),-10);
         if(m_erro_brain[trade_type-1][ind[0]][ind[1]]==0)
            m_erro_brain[trade_type-1][ind[0]][ind[1]]=0.000001*Min_Val_Neg;//Para a reducao não zerar m_erro
         super_brain[trade_type-1][ind[0]][ind[1]]=MathMax(MathMin(super_brain[trade_type-1][ind[0]][ind[1]],10000*Min_Val_Neg),-10000*Min_Val_Neg);
         analisado=MathAbs((m_now[0][0]-super_brain[trade_type-1][0][0])*m_erro_brain[trade_type-1][0][0]);
         //analisados[ind[0]][ind[1]]=1;//ativado sistema anti repeticao em loss
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
            //Para não re-trabalhar valores que já foram mexidos
            if(m_erro_brain[trade_type-1][ind[0]][ind[1]]==0)
               m_erro_brain[trade_type-1][ind[0]][ind[1]]=0.000001*Min_Val_Neg;//Para a reducao não zerar m_erro
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
               if(m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]==0)
                  m_erro_brain[trade_type_reverso-1][ind[0]][ind[1]]=0.000001*Min_Val_Neg;//Para a reducao não zerar m_erro
               //
               analisado=MathAbs((m_now[0][0]-super_brain[trade_type_reverso-1][0][0])*m_erro_brain[trade_type_reverso-1][0][0]);
               analisados[ind[0]][ind[1]]=1;
              }
           }
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

//+------------------------------------------------------------------+
void normalizar_m_erros()
  {
   double media=0;
   double Pdev=0;
   for(int i=n_holes-1; i>=0; i--) //normalizar para cada hole
     {
      for(int j=n_candles-1; j>=0; j--)
        {
         for(int k=prof_cube-1; k>=0; k--)
           {
            media+=m_erro_brain[i][k][j]/(prof_cube*n_candles);
           }
        }
      for(int j=n_candles-1; j>=0; j--)
        {
         for(int k=prof_cube-1; k>=0; k--)
           {
            Pdev+=MathPow(m_erro_brain[i][k][j]-media,2);
           }
        }
      Pdev=MathSqrt(Pdev);
      for(int j=n_candles-1; j>=0; j--)
        {
         for(int k=prof_cube-1; k>=0; k--)
           {
            m_erro_brain[i][k][j]=MathTanh(m_erro_brain[i][k][j]/(media+(2*Pdev)));
            if(m_erro_brain[i][k][j]==0)
               m_erro_brain[i][k][j]=0.000001*Min_Val_Neg;//Para a reducao não zerar m_erro
           }
        }
      Pdev=0;
      media=0;
     }
  }

//+------------------------------------------------------------------+
//---funcao para calcular o proximo resistencia
//---
double next_resist()
  {
   CopyClose(simbolo,_Period,0,5*n_candles,large_close);
   CopyOpen(simbolo,_Period,0,5*n_candles,large_open);
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
      return max2;
   return 100000*Min_Val_Neg;
  }
//+------------------------------------------------------------------+
//---funcao para calcular o proximo suporte
//---
double next_suporte()
  {
   CopyClose(simbolo,_Period,0,5*n_candles,large_close);
   CopyOpen(simbolo,_Period,0,5*n_candles,large_open);
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
void Salvar_Matriz_csv(double &matriz[][prof_cube][n_candles],string path)
  {
   uchar Symb[3];
   string Ativo;
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   string linha="";
   int file_handle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_TXT);
   int j;
   int i;
   for(int w=0; w<n_holes; w++)
     {
      for(j=0; j<prof_cube; j++)
        {
         for(i=0; i<n_candles; i++)
           {
            if(i==n_candles-1)
              {
               linha+=DoubleToString(matriz[w][j][i],12);
              }
            else
              {
               linha+=DoubleToString(matriz[w][j][i],12);
               linha+=";";
              }

           }
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
   StringToCharArray(_Symbol,Symb,0,3);
   Ativo=CharArrayToString(Symb,0);
   string add=Ativo+"_"+string(_Period)+"//"+path;
   if(FileIsExist(add,FILE_COMMON))
     {
      int file_handle=FileOpen(add,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_CSV,';');
      int j=0;
      int i=0;
      for(int w=0; w<n_holes; w++)
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
      int i,j,w;
      Alert("arquivo "+add+" nao encontrado");
      if(tipo_erro==true)
         for(w=0; w<n_holes; w++)
            for(j=0; j<prof_cube; j++)
               for(i=0; i<n_candles; i++)
                  Matriz[w][j][i]=((1+(i/n_candles))*MathRand()*Min_Val_Neg/16383.5)+((1-i%2)*Min_Val_Neg/10000);
      else
         for(w=0; w<n_holes; w++)
            for(j=0; j<prof_cube; j++)
               for(i=0; i<n_candles; i++)
                  Matriz[w][j][i]=(2*Min_Val_Neg*(16383.5-MathRand())/16383.5)+((1-i%2)*Min_Val_Neg/1000);
     }


  }
//+------------------------------------------------------------------+
