# coding: utf-8
# import csv
import numpy as np
from datetime import datetime
# import matplotlib.pyplot as plt
# import pandas as pd
# from pandas.plotting import register_matplotlib_converters
# register_matplotlib_converters()
import MetaTrader5 as Mt5
import mysql.connector
import multiprocessing as mp
# from numba import jit
import random
import time
from saver_ import save_brain
from saver_ import read_create_brain


# recebe o elemento do cubo e o neuronio a ser aproximado e aproxima proporcianal a menor distancia
# retorna true se a nova distancia for menor do que a distancia inicial
def aproxima_neuronio(id_elemento, id_neuronio, cube, brain, tentativa=1):
    try:
        alpha = 1 / (1 + tentativa % 5)  # ToDo maior quantidadde de aproximações, menor porcentagem de atualização
        # alpha=1
    except:
        alpha = 1
    # nova_dist = 0
    # velha_dist = 0
    j = 0
    i = 0
    while i < 6:
        while j < 12:
            # velha_dist=pow(brain[i][id_neuronio][j]-cube[i][id_elemento][j],2)
            brain[i][id_neuronio][j] = (1 - (alpha * 0.02)) * brain[i][id_neuronio][j] + alpha * 0.02 * (
                cube[i][id_elemento][j])
            brain[i][id_neuronio][j] = min(max(brain[i][id_neuronio][j], -14), 14)
            # nova_dist+=pow(brain[i][id_neuronio][j]-cube[i][id_elemento][j],2)
            j += 1
        i += 1
        j = 0
    # if (nova_dist<velha_dist): return True
    return False


# separa o calculo dist_id em threads #não funcionou
def dist_parcial_id(elemento, cube, brain, parcial, distancia):
    '''elemento=tupla[0]
    cube=tupla[1]
    brain=tupla[2]
    parcial=tupla[3]
    distancia=tupla[4]'''
    imin = 0
    d = 0
    d0 = 0
    j = 0
    k = 0
    pesos = (0.85, 0.9, 0.95, 0.98, 1, 0.5)  # n usar o ultimo elemento para calculo de distancia
    looping_end = 0  # o elemento do cubo deve decidir se o neuronio é de compra ou venda
    looping_start = 0  # no teste de probabilidade

    if parcial < 3:
        looping_end = (parcial + 1) * int(len(brain[0][:][:]) / 4)
    else:
        looping_end = len(brain[0][:][:])

    looping_start = parcial * int(len(brain[0][:][:]) / 4)
    dist = np.zeros(looping_end - looping_start)
    for brain_id in range(looping_start, (looping_end)):
        for j in range(0, 5):  # elemento 6 será usado para definir compra ou venda
            for k in range(12):
                d += pow(cube[j][elemento][k] - brain[j][brain_id][k], 2)
            d = pesos[j]
            d0 += d
            d = 0
            try:
                if d0 >= np.max(
                        dist):  # esse if torna as distancias maiores que a minima não confiaveis, mas acelera o processo
                    j = 6
            except:
                pass
        dist[brain_id - looping_start] = d0
        d = 0
        d0 = 0

    imin = int(np.argmin(dist)) + looping_start
    return int(imin), np.min(dist)


# separa o calculo dist_id em threads #não funcionou
def dist_id_thread(elemento, cube, brain, distancia):
    p = mp.Pool(4)
    lista = [(elemento, cube, brain, 0, distancia), (elemento, cube, brain, 1, distancia),
             (elemento, cube, brain, 2, distancia), (elemento, cube, brain, 3, distancia)]
    out = p.starmap(dist_parcial_id, lista)
    imin = 0
    dmin = out[0][1]
    for i in range(1, len(out)):
        if (out[i][1] < dmin):
            dmin = out[i][1]
            imin = i
    return imin, dmin

# retorna o neuronio mais proximo do elemento
# distancia[] armazena a distancia para uso futuro
def dist_id(elemento, cube, brain, distancia=[], parcial=0):
    #return dist_id_thread(elemento, cube, brain, distancia) #não deu certo usar threads
    imin = 0
    d = 0
    d0 = 0
    dist = []
    j = 0
    k = 0
    pesos = (0.85, 0.9, 0.95, 0.98, 1, 0.5)  # usar o ultimo elemento para calculo de distancia com peso reduzido
    looping_end = 0  # o elemento do cubo deve decidir se o neuronio é de compra ou venda
    looping_start = 0  # no teste de probabilidade e atualizar novamente
    for parcial in range(0, 4):  # looping dividido para usar threads (#ToDo - separar as parcias em threads)
        if parcial < 3:
            looping_end = (parcial + 1) * int(len(brain[0][:][:]) / 4)
        else:
            looping_end = len(brain[0][:][:])

        looping_start = parcial * int(len(brain[0][:][:]) / 4)
        for brain_id in range(looping_start, (looping_end)):
            for j in range(0, 6):  # elemento 6 será usado para definir compra ou venda
                for k in range(0, 12):
                    d += pow(cube[j][elemento][k] - brain[j][brain_id][k], 2)
                d = pesos[j]
                d0 += d
                d = 0
            dist.append(d0)
            d0 = 0
    for i in range(0, 30):
        if dist[i] < dist[imin]:
            imin = i
    return imin, dist[imin]


# pega os dados recebidos do metatrader e organiza em forma de um array [][][]
# (delays temporais,elementos recebidos,parametros do candle)
def montar_cubo(dol, cube=[]):
    media = np.ones((len(dol) + 1, 2)) * dol[0]["close"]
    elemento = []
    frame = []
    i = 0
    for val in dol:  # monta o ultimo frame do cubo cube[5][:][:]
        elemento.append(dol[i]["open"] - dol[i]["close"])
        elemento.append(dol[i]["open"] - dol[i]["high"])
        elemento.append(dol[i]["open"] - dol[i]["low"])
        elemento.append(dol[i]["close"] - dol[i]["high"])
        elemento.append(dol[i]["close"] - dol[i]["low"])
        elemento.append(dol[i]["high"] - dol[i]["low"])
        elemento.append(dol[i]["open"] - dol[i]["close"])
        media[i + 1][0] = media[i][0] + ((dol[i]["close"] - media[i][0]) / 21)
        media[i + 1][1] = media[i][1] + ((dol[i]["close"] - media[i][1]) / 9)
        elemento.append(dol[i]["open"] - media[i][0])
        elemento.append(dol[i]["close"] - media[i][0])
        elemento.append(dol[i]["high"] - media[i][0])
        elemento.append(dol[i]["low"] - media[i][0])
        elemento.append(media[i][0] - media[i][1])
        frame.append(elemento[:])
        elemento = []
        i += 1
    cube.append(frame[5:-1])
    cube.append(frame[4:-2])
    cube.append(frame[3:-3])
    cube.append(frame[2:-4])
    cube.append(frame[1:-5])
    cube.append(frame[:-6])
    k = len(cube[0][:][:])-1
    while k >= 0:
        if abs(cube[5][k][0]) < 2:
            for w in range(0, 6):
                cube[w].pop(k)
            k -= 1
        else:
            k -= 1

    print(f"cubo loaded. n elementos: {len(cube[0][:][:])}")
    return cube

    # retorna um array com quantas vezes um neuronio foi aproximado
    # Aproxima os neuronios do correspondente input mais proximo


# aproxima todos os neuronios dos inputs
def aproxima_brain(cube, brain, tratados=[]):
    start = time.time()
    to_be_aprox = 31
    distancia = [0]
    dist_min = np.zeros(30)
    # distanc = distancias_e_dist_minimas(brain, cubo, dist_min, tratados)
    k = len(cube[0][:][:])
    distancia_minima = 0
    for i in range(0, k):
        to_be_aprox, distancia_minima = dist_id(i, cube, brain,
                                                distancia)  # identifica qual neuronio esta mais proximo desse input#usar multiproc aqui #ToDo
        tratados[int(to_be_aprox)] += 1  # registra quantas vezes esse neuronio foi tratado
        aproxima_neuronio(i, to_be_aprox, cube, brain)  # aproxima o neuronio do input #ToDo aproximacao proporcional
    print("tempo de ciclo: " + str(time.time() - start))
    return tratados


# acrescenta aleatoriedade em neuronio k
def randomiza_neuronio(k, brain):
    for i in range(0, 6):
        for j in range(0, 12):
            brain[i][k][j] += ((random.random() - 0.5) / 50)


# reajusta o neuronio menos usado
# return true if all neurons are well used
def refaz_neuronios_pouco_usados(tratados_list, brain, cube, trying):
    tratados = np.asarray(tratados_list)
    alfa = np.min(tratados)
    if alfa < (np.max(tratados) * 0.1):  # 10% do maior neuronio
        k = tratados.argmin()
        print(f"recriando neuronio {k}")
        neuron = []
        temp = 0
        j = 0
        i = random.randint(0, 20)  # aproxima aleatoriamente de varios inputs
        while i < len(cube[0][:][:]):
            aproxima_neuronio(i, k, cube, brain, trying)
            i += random.randint(0, 20)
        randomiza_neuronio(k, brain)
        return False
    return True


# gera array bidimensional qual neuronio aquele elemento pertence
# e sua distancia ao neuronio
def n_proximos_brain(brain, cube):
    n = []
    delta = len(cube[0][:][:])
    n0 = []
    temp = []
    for i in range(0, delta):  # todos os elementos
        temp2 = dist_id(i, cube, brain)
        temp = [temp2[0], temp2[1]]
        n.append(temp)
    return n[:][:]  # retorna uma copia de n


# entra um array com a neuronio e distancia de cada elemento
# retorna um array com a distancia media de cada neuronio
def DistMedia(n):
    dist = np.zeros(30)
    cont = np.ones(30) * 0.000001
    for i in range(0, len(n[:][:])):
        dist[int(n[i][0])] += n[i][1]
        cont[int(n[i][0])] += 1
    for i in range(0, 30):
        dist[i] = dist[i] / cont[i]
    return dist[:]


# entra um array com o neuro de cada elemento e sua distancia do seu neuronio
# entra distancia média de cada neuronio
# retorna um array com os elementos analisaveis seu neuronio e compra ou venda
def Elementos_Analisaveis(n, dist, cube):
    out = []
    buy_sell = 0
    temp = []
    for i in range(0, len(cube[0][:][:])):
        if (n[i][1]) <= 0.3 * dist[n[i][0]]:
            if (cube[5][i][0]) >= 1:
                buy_sell = 1
            else:
                if (cube[5][i][0] <= -1):
                    buy_sell = -1
                else:
                    buy_sell = 0
            temp.append(i)
            temp.append(n[i][0])
            temp.append(buy_sell)
            out.append(temp[:])
            temp.pop()
            temp.pop()
            temp.pop()
    return out[:][:]  # elemento[analizaveis][3](element indice,neuronio correspondente,buy_sell)


# recebe os inputs analisaveis de acordo com a distancia ao seu neuronio
# retorna a probabilidade do neuronio ser de compra (+) ou venda (-)
# preenche o brain com se o neuronio é compra(2), venda(-2), ou nada(0)
# usada inicialmente para reiniciar treinamento
def probabilidade_neuronio(analisaveis, brain):
    probabilidade = np.zeros(30)
    contador = np.ones(30) * 0.000001
    for i in range(0, len(analisaveis[:][:])):
        probabilidade[analisaveis[i][1]] += analisaveis[i][2]
        contador[analisaveis[i][1]] += 1
    for i in range(0, 30):
        probabilidade[i] /= contador[i]
        if probabilidade[i] > 0.15:  #
            brain[5][i][0] = 0.5 * brain[5][i][0] + 0.5 * 2  # converge fortemente para 2
        else:
            if probabilidade[i] < -0.15:
                brain[5][i][0] = 0.5 * brain[5][i][0] - 0.5 * 2  # converge fortemente para -2
            else:
                brain[5][i][0] = 0.5 * brain[5][i][0]  # converge fortemente para 0
    out = probabilidade.tolist()
    # print(f"probabilidade de compra ou venda {out}")
    return out[:]


# entra o neuronio, o input (o id do input no cubo)
# retorna se seria um acerto um loss ou uma nem entrada de acordo com o neuronio
def teste_de_acertos(cube, brain, dist_media, elemento=0):
    to_test, distancia = dist_id(elemento, cube, brain)  # descobre qual neuronio está mais perto e a distancia
    buy_sell = brain[5][to_test][0]  # descobre se o neuronio e de compra ou venda #ver probabilidade_neuronio
    if buy_sell >= 1.2:
        buy_sell = 1
    else:
        if buy_sell <= -1.2:
            buy_sell = -1
        else:
            buy_sell = 0
    if (distancia <= 0.30 * dist_media[to_test]):  # descobre se o elemento é aceitavel para comparacao
        if buy_sell == 1:  # define se o elemento acertaria ou falharia
            if cube[5][elemento][0] >= 2:
                return (1, 1)  # compra(1) e acerto(1)
            else:
                return (1, 0)  # compra(1) e erro(0)
        else:
            if (buy_sell == -1):
                if cube[5][elemento][0] <= -2:
                    return (1, 1)  # venda acerto
                else:
                    return (1, 0)  # venda e erro
            else:  # buy_sell==0
                if cube[5][elemento][0] > -2 and cube[5][elemento][0] < 2:
                    return (1, 1)  # nem compra, nem venda e acerto
                else:
                    return (1, 0)  # nem compra, nem venda e erro
    else:
        return (0, 0)  # elemento não tratavel


if __name__ == '__main__':  # Inicio
    # abrir banco de dados sql
    mydb = mysql.connector.connect(host="localhost", user="user", passwd="asdfg", database="cosmos")
    print(mydb)
    mycursor = mydb.cursor()

    # conecte-se ao MetaTrader 5
    if not Mt5.initialize():
        print("initialize() Metatrader failed")
        Mt5.shutdown()
        exit()
    else:
        print("metatrader initialized sucessfull")

    # obtemos barras (30 dias)
    dolbrl_rates = Mt5.copy_rates_range("WDO$", Mt5.TIMEFRAME_M5, datetime(2020, 5, 2, 10), datetime(2020, 8, 18, 16))
    print(f"size_of database= {len(dolbrl_rates)}")
    cubo = []
    montar_cubo(dolbrl_rates, cubo)
    cube = tuple(cubo)
    random.seed()
    brain = []
    read_create_brain(brain, mycursor, cube)
    save_brain(brain, mycursor, mydb)
    tratados = [0 for i in range(30)]  # armazena quais neuronios foram aproximados e quantas vezes
    tupla = aproxima_brain(cube, brain, tratados)
    trying = 1
    retrying = 0
    print(f"elementos tratados: {sum(tratados)}")
    print(f'utilização do neuronio menos usado: {min(tratados)}')
    n_elementos = []
    dist_media = []
    prob = []
    probabilidade_minima = 0
    argprobmin = -1
    prob_acertos = 0
    temp = len(cube[0][:][:])
    while prob_acertos < 0.65:
        while (probabilidade_minima < 0.15 and retrying < 5) or retrying == 5:
            if argprobmin == -1:
                tratados = [0 for i in range(30)]
                refaz_neuronios_pouco_usados(tratados, brain, cube, trying)
                tupla2 = aproxima_brain(cube, brain, tratados)
                print(f"elementos tratados: {sum(tratados)}")
                print(f'utilização do neuronio menos usado: {min(tratados)}')
                print(f'Aproximacoes (parcial): {trying}')
            while ((refaz_neuronios_pouco_usados(tratados, brain, cube, trying) == False) and trying < 5) or trying <= 5:
                tratados = [0 for i in range(30)]
                tupla2 = aproxima_brain(cube, brain, tratados)
                if trying % 3 == 0:
                    save_brain(brain, mycursor, mydb)
                mydb.commit()
                print(f"elementos tratados: {sum(tratados)}")
                print(f'utilização do neuronio menos usado: {min(tratados)}')
                print(f'Aproximacoes (parcial): {trying}')
                trying += 1
            n_elementos[:] = n_proximos_brain(brain, cube)
            # print(f'n_elementos:  {n_elementos}')
            dist_media[:] = DistMedia(n_elementos)
            # print(f'distancias medias: {dist_media}')
            print(f'Total aproximacoes: {5 * retrying}')
            n_analisaveis = []
            n_analisaveis[:] = Elementos_Analisaveis(n_elementos, dist_media, cube)
            prob[:] = probabilidade_neuronio(n_analisaveis, brain)
            probabilidade_minima = abs(prob[0])
            argprobmin = 0
            menos_provaveis = np.ones(30)
            menos_provaveis[0] = 0
            for i in range(1, 30):
                if probabilidade_minima > abs(prob[i]):
                    probabilidade_minima = abs(prob[i])
                    argprobmin = i
                    menos_provaveis.fill(1)
                    menos_provaveis[i] = 0
                    # funciona igual os elementos tratados, mas faz o
                    # neuronio com menor probabilidade ser o menor forcadamente
            tratados[:] = menos_provaveis[:]
            retrying += 1
            trying = 5
            total = 0
        acertos = 0
        n_elementos[:] = n_proximos_brain(brain, cube)
        dist_media[:] = DistMedia(n_elementos)
        temp = len(cube[0][:][:])
        for i in range(0, len(cube[0][:][:])):
            buy_sell_acertos = teste_de_acertos(cube, brain, dist_media, i)
            acertos += buy_sell_acertos[1]
            temp += buy_sell_acertos[0]
        if temp != 0:
            prob_acertos = (acertos / temp)
        else:
            prob_acertos = 0
        print(f' ***** prob_de_acertos *****: {prob_acertos}')
        print(f'hora local {time.time()}')
        retrying = 4 # executa mais de uma vez o ciclo para envolver os cases
        trying = 4   # probabilidade de acertos, probabilidade comum, e utilizacao menor
    # print(f'Probabilidade_compra_venda: {prob}')
    print(f' ***** prob_de_acertos *****: {prob_acertos}')
    print(f"quantidade de operacoes: {temp}")
    print("Training End")
    save_brain(brain, mycursor, mydb)

    Mt5.shutdown()
    mydb.commit()
    mycursor.close()
    mydb.close()
