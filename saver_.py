import mysql.connector

#Salva o brain em tabelas do MySql
def save_brain(brain,mycursor,mydb):
    print("Saving Brain 0%")
    mycursor.execute("drop table brain0")
    mycursor.execute("drop table brain1")
    mycursor.execute("drop table brain2")
    mycursor.execute("drop table brain3")
    mycursor.execute("drop table brain4")
    mycursor.execute("drop table brain5")
    mycursor.execute("create table brain0(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
    mycursor.execute("create table brain1(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
    mycursor.execute("create table brain2(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
    mycursor.execute("create table brain3(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
    mycursor.execute("create table brain4(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
    mycursor.execute("create table brain5(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
    my_insert=""
    if(len(brain[0][0][:])>0):
        for row in brain[0][:][:]:
            my_insert="INSERT INTO brain0(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)"
            mycursor.execute(my_insert, (
            str(row[0]), str(row[1]), str(row[2]), str(row[3]), str(row[4]), str(row[5]), str(row[6]), str(row[7]),
            str(row[8]), str(row[9]),
            str(row[10]), str(row[11])))
        for row in brain[1][:][:]:
            my_insert = "INSERT INTO brain1(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)"
            mycursor.execute(my_insert, (
            str(row[0]), str(row[1]), str(row[2]), str(row[3]), str(row[4]), str(row[5]), str(row[6]), str(row[7]),
            str(row[8]), str(row[9]),
            str(row[10]), str(row[11])))
        for row in brain[2][:][:]:
            my_insert = "INSERT INTO brain2(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)"
            mycursor.execute(my_insert, (
            str(row[0]), str(row[1]), str(row[2]), str(row[3]), str(row[4]), str(row[5]), str(row[6]), str(row[7]),
            str(row[8]), str(row[9]),
            str(row[10]), str(row[11])))
        for row in brain[3][:][:]:
            my_insert = "INSERT INTO brain3(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)"
            mycursor.execute(my_insert, (
            str(row[0]), str(row[1]), str(row[2]), str(row[3]), str(row[4]), str(row[5]), str(row[6]), str(row[7]),
            str(row[8]), str(row[9]),
            str(row[10]), str(row[11])))
        for row in brain[4][:][:]:
            my_insert = "INSERT INTO brain4(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)"
            mycursor.execute(my_insert, (
            str(row[0]), str(row[1]), str(row[2]), str(row[3]), str(row[4]), str(row[5]), str(row[6]), str(row[7]),
            str(row[8]), str(row[9]),
            str(row[10]), str(row[11])))
        for row in brain[5][:][:]:
            my_insert = "INSERT INTO brain5(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)"
            mycursor.execute(my_insert, (str(row[0]), str(row[1]), str(row[2]), str(row[3]), str(row[4]), str(row[5]), str(row[6]), str(row[7]), str(row[8]), str(row[9]),
                             str(row[10]), str(row[11])))
        mydb.commit()
        print("Save brain 100%")

#Le as tabelas do MySql e retorna um brain montado
#ou cria aleatoriamente se não houver tabelas
def read_create_brain(brain,mycursor,cube):
    brain0 = []
    brain1 = []
    brain2 = []
    brain3 = []
    brain4 = []
    brain5 = []
    temp0=[]
    k=0
    try:
        mycursor.execute("select * from brain0")
        mytable = mycursor.fetchall()
        i = 0
        j = 0
        temp = [];
        for row in mytable:
            for element in row:
                temp.append(float(element))
                j += 1
            brain0.append(temp[:])
            temp = []
            i += 1
            j = 0
        k=len(brain0[0][:])
    except:
        try:
            mycursor.execute("drop table brain0")
        except:
            print("tabela brain0 n existente, criando...")
        mycursor.execute("create table brain0(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
        i=0
        j=0
        temp0=cube[0][10][:12]
        while(i<30):
            my_insert = "INSERT INTO brain0(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) VALUES(1,1,1,1,1,1,1,1,1,1,1,1)"
            mycursor.execute(my_insert)
            i += 1
            brain0.append(temp0[:])
            temp0=cube[0][10+i][:]

    try:
        mycursor.execute("select * from brain1")
        mytable = mycursor.fetchall()
        i = 0
        j = 0
        temp = [];
        brain1 = []
        for row in mytable:
            for element in row:
                temp.append(float(element))
                j += 1
            brain1.append(temp[:])
            temp = []
            i += 1
            j = 0
        k=len(brain1[0][:])
    except:
        try:
            mycursor.execute("drop table brain1")
        except:
            print("tabela brain1 n existente, criando...")
        mycursor.execute("create table brain1(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
        i = 0
        temp0 = cube[1][40][:]
        while (i <30):
            mycursor.execute(
                "insert into brain1(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) values(1,1,1,1,1,1,1,1,1,1,1,1)")
            i += 1
            brain1.append(temp0[:])
            temp0=cube[1][40+i][:]

    try:
        mycursor.execute("select * from brain2")
        mytable = mycursor.fetchall()
        i = 0
        j = 0
        temp = [];
        brain2 = []
        for row in mytable:
            for element in row:
                temp.append(float(element))
                j += 1
            brain2.append(temp[:])
            temp = []
            i += 1
            j = 0
        k=len(brain2[0][:])
    except:
        try:
            mycursor.execute("drop table brain2")
        except:
            print("tabela brain2 n existente, criando...")
        mycursor.execute("create table brain2(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
        i = 0
        temp0 [:]= cube[2][70][:]
        while (i <30):
            mycursor.execute(
                "insert into brain2(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) values(1,1,1,1,1,1,1,1,1,1,1,1)")
            i += 1
            brain2.append(temp0[:])
            temp0 [:]= cube[2][70 + i][:]

    try:
        mycursor.execute("select * from brain3")
        mytable = mycursor.fetchall()
        i = 0
        j = 0
        temp = [];
        brain3 = []
        for row in mytable:
            for element in row:
                temp.append(float(element))
                j += 1
            brain3.append(temp[:])
            temp = []
            i += 1
            j = 0
        k=len(brain3[0][:])
    except:
        try:
            mycursor.execute("drop table brain3")
        except:
            print("tabela brain3 n existente, criando...")
        mycursor.execute("create table brain3(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
        i = 0
        temp0 [:]= cube[3][100][:]
        while (i < 30):
            mycursor.execute(
                "insert into brain3(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) values(1,1,1,1,1,1,1,1,1,1,1,1)")
            i += 1
            brain3.append(temp0[:])
            temp0 [:]= cube[3][100 + i][:12]

    try:
        mycursor.execute("select * from brain4")
        mytable = mycursor.fetchall()
        i = 0
        j = 0
        temp = [];
        brain4 = []
        for row in mytable:
            for element in row:
                temp.append(float(element))
                j += 1
            brain4.append(temp)
            temp = []
            i += 1
            j = 0
        k=len(brain4[0][:])
    except:
        try:
            mycursor.execute("drop table brain4")
        except:
            print("tabela brain4 n existente, criando...")
        mycursor.execute("create table brain4(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
        i = 0
        temp0 [:]= cube[4][130][:]
        while (i < 30):
            mycursor.execute(
                "insert into brain4(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) values(1,1,1,1,1,1,1,1,1,1,1,1)")
            i += 1
            brain4.append(temp0[:])
            temp0 [:]= cube[4][130 + i][:]

    try:
        mycursor.execute("select * from brain5")
        mytable = mycursor.fetchall()
        i = 0
        j = 0
        temp = [];
        brain5 = []
        for row in mytable:
            for element in row:
                temp.append(float(element))
                j += 1
            brain5.append(temp[:])
            temp = []
            i += 1
            j = 0
        k=len(brain5[0][:])
    except:
        try:
            mycursor.execute("drop table brain5")
        except:
            print("tabela brain5 n existente, criando...")
        mycursor.execute("create table brain5(data0 VARCHAR(255),data1 VARCHAR(255),data2 VARCHAR(255),data3 VARCHAR(255),data4 VARCHAR(255),data5 VARCHAR(255),data6 VARCHAR(255),data7 VARCHAR(255),data8 VARCHAR(255),data9 VARCHAR(255),data10 VARCHAR(255),data11 VARCHAR(255))")
        i = 0
        temp0 [:]= cube[5][180][:]
        while (i < 30):
            mycursor.execute(
                "insert into brain5(data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10,data11) values(1,1,1,1,1,1,1,1,1,1,1,1)")
            i += 1
            brain5.append(temp0[:])
            temp0 [:]= cube[5][180 + i][:]

    brain.append(brain0)
    brain.append(brain1)
    brain.append(brain2)
    brain.append(brain3)
    brain.append(brain4)
    brain.append(brain5)
    print("brain mounted")
    return brain