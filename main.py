import csv
import numpy as np
from datetime import datetime
import matplotlib.pyplot as plt
import pandas as pd
from pandas.plotting import register_matplotlib_converters
register_matplotlib_converters()
import MetaTrader5 as mt5
import mysql.connector



def dist_media(cube,brain,dist_media__):
    i=0
    dist_cont_temp=np.ones(30)
    temp=0
    distancia=np.zeros(1)
    while i<len(cube):
        temp=dist_id(i,cube,brain,distancia)
        dist_media__[temp]+=distancia[0]
        dist_cont_temp[temp]+=1
        i+=1
    i=0
    while i<30:
        dist_media__[i]/=(dist_cont_temp[i]-0.99)
        i+=1
    print("distancia media entre sinais:")
    print( dist_media__)

def probabilidade(elemento,cerebro,cube,provavel):
    i=0;
    qtdd=np.ones(30);
    temp=0
    distancia=np.zeros(1)
    dist_media__=np.zeros(30)
    dist_media(cube,cerebro,dist_media__)
    while i<len(cube):
        temp=dist_id(i,cube,cerebro,distancia)
        provavel[temp]+=cube[i][-1]*pow(dist_media__[temp]/distancia[0],2)
        qtdd[temp]+=pow(dist_media__[temp]/distancia[0],2)
        i+=1
    i=0
    while i<len(provavel):
        provavel[i]/=(qtdd[i]-0.9999)
        provavel[i]=pow(provavel[i],2)
        i+=1
    print("vetor de probabilidades:" )
    print(provavel)
    return provavel[elemento]

def aproxima(elemento,cubo,neuro_id,brain,distancia__,dist_minima__):
    j=0
    while j<90:
        brain[neuro_id][j]=((1-(0.02*dist_minima__/distancia__))*brain[neuro_id][j])+(0.02*dist_minima__*cubo[elemento][j]/distancia__)
        j+=1

#retorna o neuronio mais proximo do elemento
def dist_id(elemento,cubo,brain,distancia):
    imin=0
    d=0
    brain_id=0
    dist=[]
    j = 0
    while brain_id<30:
        while j<6:
            while k<12:
                if(j<1):
                    d+=0.30*pow(cubo[j][elemento][k]-brain[j][brain_id][k],2)
                elif(j<2):
                    d += 0.45* pow(cubo[j][elemento][k] - brain[j][brain_id][k], 2)
                elif(j<3):
                    d += 0.65 * pow(cubo[j][elemento][k]- brain[j][brain_id][k], 2)
                elif (j<4):
                    d += 0.75 * pow(cubo[j][elemento][k] - brain[j][brain_id][k], 2)
                elif (j<5):
                    d += 0.75 * pow(cubo[j][elemento][k]- brain[j][brain_id][k], 2)
                else:
                    d += 0.9 * pow(cubo[j][elemento][k] - brain[j][brain_id][k], 2)
                k+=1
            k=0
            j+=1
        dist.append(d)
        d=0
        k=0
        j=0
        brain_id+=1
    i=0
    while i<len(dist):
        if dist[i]<dist[imin]:
            imin=i
        i+=1
    distancia[0]=dist[imin]
    return imin

#retorna a distancia ao neuronio mais proximo do elemento
def dist(elemento,cubo,brain):
    imin=0
    d=0
    brain_id=0
    dist=[]
    j = 0
    while brain_id<30:
        while j<90:
            if (j < 15):
                d += 0.30 * pow(cubo[elemento][j] - brain[brain_id][j], 2)
            elif (j < 30):
                d += 0.45 * pow(cubo[elemento][j] - brain[brain_id][j], 2)
            elif (j < 45):
                d += 0.65 * pow(cubo[elemento][j] - brain[brain_id][j], 2)
            elif (j < 60):
                d += 0.75 * pow(cubo[elemento][j] - brain[brain_id][j], 2)
            elif (j < 75):
                d += 0.75 * pow(cubo[elemento][j] - brain[brain_id][j], 2)
            else:
                d += 0.9 * pow(cubo[elemento][j] - brain[brain_id][j], 2)
            j += 1
        dist.append(d)
        d=0
        j=0
        brain_id+=1
    i=0
    while i<len(dist):
        if dist[i]<dist[imin]:
            imin=i
        i+=1
    return dist[imin]

def save_brain(brain):
    f = open("brain.csv", 'w',newline='')  # caminho do arquivo
    to_write=csv.writer(f,delimiter=";", quotechar='"', quoting=csv.QUOTE_MINIMAL)
    for row in brain:
        to_write.writerow(row)

def read_brain(brain):
    try:
        with open('brain.csv', 'r',newline='') as f:
            file_data = csv.reader(f, delimiter=";")  # variavel que receberá o arquivo escolhido
            candle_ = []
            for row in file_data:
                for item in row:
                    candle_.append(float(item))
                brain.append(candle_)
                candle_ = []
        f.close()
    except IOError:
        print("File does not exist!")
        i = 0
        j = 0
        neuron=[]
        while j<6:
            while i < 30:
                neuron.append(4 * (1 - 2 * np.random.random_sample()))
                i+=1
            brain.append(neuron)
            neuron=[]
            i=0
            j+=1
        save_brain(brain)

def open_cube(cubo):
    try:
        f=open("data_bank.csv",'r',newline='') #caminho do arquivo
        file_data = csv.reader(f,delimiter=";") #variavel que receberá o arquivo escolhido
        print(f)
        np.random.seed(987654)
        candle=[]
        for row in file_data:
            for item in row:
                candle.append(float(item))
            cubo.append(candle)
            candle=[]
    except IOError:
        print("Sem arquivo de entrada")
        exit()
def montar_cubo(cube,dol):
    media=np.ones((len(dol)+1,2))*dol[0]["close"]
    i = 0
    for val in dol:
        cube[5][i][0] = dol[i]["open"] - dol[i]["close"]
        cube[5][i][1] = dol[i]["open"] - dol[i]["high"]
        cube[5][i][2] = dol[i]["open"] - dol[i]["low"]
        cube[5][i][3] = dol[i]["close"] - dol[i]["high"]
        cube[5][i][4] = dol[i]["close"] - dol[i]["low"]
        cube[5][i][5] = dol[i]["high"] - dol[i]["low"]
        cube[5][i][6] = dol[i]["open"] - dol[i]["close"]
        media[i + 1][0] = media[i][0] + ((dol[i]["close"] - media[i][0]) / 21)
        media[i + 1][1] = media[i][1] + ((dol[i]["close"] - media[i][1]) / 9)
        cube[5][i][7] = dol[i]["open"] - media[i][0]
        cube[5][i][8] = dol[i]["close"] - media[i][0]
        cube[5][i][9] = dol[i]["high"] - media[i][0]
        cube[5][i][10] = dol[i]["low"] - media[i][0]
        cube[5][i][11] = media[i][0] - media[i][1]
        i += 1
    j=4
    while j>=0:
        cube[j][:-1:1][:]=cube[j+1][1:][:]
        j-=1

def aproxima_e_reporta_todos(cubo,brain):#retorna um array com quantas vezes um neuronio foi aproximado
    to_be_aprox=31
    distancia=np.zeros(1)
    tratados=np.zeros(30)
    distanc=np.ones(len(cubo[0][:]))
    dist_min=np.zeros(30)
    distanc = distancias_e_dist_minimas(brain, cubo, dist_min, tratados)
    k=len(cubo[0][:][0])
    i=0
    while(i<k):
        to_be_aprox=dist_id(i,cubo,brain,distancia)#recebe qual neuronio deve ser aproximado desse input
        tratados[to_be_aprox]+=1#registra quantas vezes esse neuronio foi tratado
        aproxima(i,cubo,to_be_aprox,brain,distanc[i],dist_min[to_be_aprox])#aproxima o neuronio do input
        i+=1
    print("elementos tratados: ")
    print(tratados)
    return tratados

def refaz_neuronios_pouco_usados(tratados,brain,cubo):#reajusta o brain ate todos os neuronios serem usados
    reload = 0
    distanc=np.zeros(len(cubo))
    dist_min=np.zeros(30)
    distancia=np.zeros(1)
    while np.min(tratados)<=50:
        reload = np.argmin(tratados)
        print (reload)
        tratados = np.zeros(30)
        neuron=[]
        i=0
        temp=0
        j=0
        while i < 90:
            while j<30:
                temp+=brain[j][i]/30
                j+=1
            neuron.append(temp)
            i += 1
            temp=0
            j=0
        brain[reload]=neuron
        distanc=distancias_e_dist_minimas(brain,cubo,dist_min,tratados)
        i=0
        while(i<len(cubo)):#retrata e testa neuronios
            to_be_aprox=dist_id(i,cubo,brain,distancia)
            tratados[to_be_aprox]+=1
            aproxima(i,cubo,to_be_aprox,brain,distanc[i],dist_min[to_be_aprox])
            i+=1
        print("neuronios re-tratados> ")
        print(tratados)
    return tratados

def cria_neuronio_aproximado(brain):
    i=0
    temp=0
    neuron=[]
    while i < 90:
        j=0
        while j<30:
            temp+=brain[j][i]/30
            j+=1
        neuron.append(temp+(0.5 * (1 - 2 * np.random.random_sample())))
        i += 1
        temp=0
    return neuron

#recebe os dados do cubo, os neuronios brain, um array vazio para retornar com
# as distancias minimas dos elementos ate o seus neuronios e o array com a
# quantidade de vezes que cada elemento foi tratado
def distancias_e_dist_minimas(brain,cubo,dist_min,tratados):
    dist_min.fill(0)
    dists=np.ones(len(cubo[0][:][0]))
    distancia=np.zeros(1)
    i = len(cubo[0][:][0])
    while i>=0:
        distancia[0]=(1)
        distancia_id=dist_id(i,cubo,brain,distancia)#descobre qual neuronio mais se aproxima e calcula a distancia, retorna qual neuronio
        #salva todas as distancias dos inputs aos neuronios mais proximos
        dists[i]=distancia[0]
        #se a distancia do elemento ao seu neuronio mais proximo for < do que a salva anteriormente, atualiza
        if (distancia[0]<dist_min[distancia_id]) or (dist_min[distancia_id]==0):
            dist_min[distancia_id]=distancia[0]
        i-=1
    return dists #retorna um array com todas as distancias
def read_create_brain(brain):
    mydb = mysql.connector.connect(host="localhost", user="user", passwd="asdfg", database="cosmos")
    print(mydb)
    mycursor = mydb.cursor()
    try:
        mycursor.execute("select * from brain0")
    except:
        print("tabela brain0 n existente")
        mycursor.execute("create table brain0(candle_indice VARCHAR(255),data0 VARCHAR(255),data1 VARCHAR(255),"
                         "data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),"
                         "data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),"
                         "data10 VARCHAR(255),data11 VARCHAR(255))")
        mycursor.execute("select * from brain0")
    mytable=mycursor.fetchall()
    i=0
    j=0
    temp=[];
    brain0= []
    for row in mytable:
        for element in row:
            temp.append(float(element))
            print("teste")
            j+=1
        brain0.append(temp)
        temp=[]
        i+=1
        j=0
    try:
        mycursor.execute("select * from brain1")
    except:
        print("tabela brain1 n existente")
        mycursor.execute("create table brain1(candle_indice VARCHAR(255),data0 VARCHAR(255),data1 VARCHAR(255),"
                         "data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),"
                         "data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),"
                         "data10 VARCHAR(255),data11 VARCHAR(255))")
        mycursor.execute("select * from brain1")
    mytable=mycursor.fetchall()
    i=0
    j=0
    temp=[];
    brain1= []
    for row in mytable:
        for element in row:
            temp.append(float(element))
            print("teste")
            j+=1
        brain1.append(temp)
        temp=[]
        i+=1
        j=0
    try:
        mycursor.execute("select * from brain2")
    except:
        print("tabela brain2 n existente")
        mycursor.execute("create table brain2(candle_indice VARCHAR(255),data0 VARCHAR(255),data1 VARCHAR(255),"
                         "data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),"
                         "data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),"
                         "data10 VARCHAR(255),data11 VARCHAR(255))")
        mycursor.execute("select * from brain2")
    mytable=mycursor.fetchall()
    i=0
    j=0
    temp=[];
    brain2= []
    for row in mytable:
        for element in row:
            temp.append(float(element))
            print("teste")
            j+=1
        brain2.append(temp)
        temp=[]
        i+=1
        j=0
    try:
        mycursor.execute("select * from brain3")
    except:
        print("tabela brain3 n existente")
        mycursor.execute("create table brain3(candle_indice VARCHAR(255),data0 VARCHAR(255),data1 VARCHAR(255),"
                         "data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),"
                         "data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),"
                         "data10 VARCHAR(255),data11 VARCHAR(255))")
        mycursor.execute("select * from brain3")
    mytable=mycursor.fetchall()
    i=0
    j=0
    temp=[];
    brain3= []
    for row in mytable:
        for element in row:
            temp.append(float(element))
            print("teste")
            j+=1
        brain3.append(temp)
        temp=[]
        i+=1
        j=0
    try:
        mycursor.execute("select * from brain4")
    except:
        print("tabela brain4 n existente")
        mycursor.execute("create table brain4(candle_indice VARCHAR(255),data0 VARCHAR(255),data1 VARCHAR(255),"
                         "data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),"
                         "data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),"
                         "data10 VARCHAR(255),data11 VARCHAR(255))")
        mycursor.execute("select * from brain4")
    mytable=mycursor.fetchall()
    i=0
    j=0
    temp=[];
    brain4= []
    for row in mytable:
        for element in row:
            temp.append(float(element))
            print("teste")
            j+=1
        brain4.append(temp)
        temp=[]
        i+=1
        j=0
    try:
        mycursor.execute("select * from brain5")
    except:
        print("tabela brain5 n existente")
        mycursor.execute("create table brain5(candle_indice VARCHAR(255),data0 VARCHAR(255),data1 VARCHAR(255),"
                         "data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),"
                         "data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),"
                         "data10 VARCHAR(255),data11 VARCHAR(255))")
        mycursor.execute("select * from brain5")
    mytable=mycursor.fetchall()
    i=0
    j=0
    temp=[];
    brain5= []
    for row in mytable:
        for element in row:
            temp.append(float(element))
            print("teste")
            j+=1
        brain5.append(temp)
        temp=[]
        i+=1
        j=0
    brain=[[[]],[[]],[[]],[[]],[[]],[[]]]

    brain[0][:][:] = brain0[:][:]
    brain[1][:][:] = brain1[:][:]
    brain[2][:][:] = brain2[:][:]
    brain[3][:][:] = brain3[:][:]
    brain[4][:][:] = brain4[:][:]
    brain[5][:][:] = brain5[:][:]
    print(brain)

def save_brain():
    print("to do")
brain=[[[]],[[]],[[]],[[]],[[]],[[]]]
read_create_brain(brain)
# conecte-se ao MetaTrader 5
if not mt5.initialize():
    print("initialize() failed")
    mt5.shutdown()
else: print("metatrader initialized sucessfull" )

# obtemos barras
dolbrl_rates = mt5.copy_rates_range("WDO$", mt5.TIMEFRAME_M1, datetime(2020, 6, 30, 9), datetime(2020, 7, 29, 9))
cubo=np.ones((6,len(dolbrl_rates),12))
montar_cubo(cubo,dolbrl_rates)
#open_cube(cubo,dolbrl_rates)
brain=np.ones(6,30)
read_brain(brain)
tratados=[]
tratados=aproxima_e_reporta_todos(cubo,brain)
refaz_neuronios_pouco_usados(tratados,brain,cubo)
save_brain(brain)
provavel=np.zeros(30)
prob_neuro_0=probabilidade(0,brain,cubo,provavel)
print("probabilidade do neuronio 0: "+str(prob_neuro_0))

while(np.min(provavel)<0.01):#roda ate todos os padroes serem encontrados
    tratados.fill(0)
    print(" Probabilidade baixa: ")
    print(np.min(provavel))
    print("destruir neuronio: "+str(np.argmin(provavel)))
    brain[np.argmin(provavel)]=cria_neuronio_aproximado(brain)
    tratados=aproxima_e_reporta_todos(cubo,brain)
    print("neuronios reaproximados")
    print(tratados)
    refaz_neuronios_pouco_usados(tratados,brain,cubo)
    print("quantidade de elementos de entrada:" +str(np.sum(tratados)))
    save_brain(brain)
    provavel=np.zeros(30)
    probabilidade(0,brain,cubo,provavel)
    print("neuronio mais apto: "+ str(np.max(provavel))+"indice: "+str(np.argmax(provavel)))

print("Finished:  "+str(provavel))
save_brain(brain)
mt5.shutdown()