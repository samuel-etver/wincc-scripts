# -*- coding: cp1251 -*-
#-----------------------------------------------------------
# wna-mes_main.py
#-----------------------------------------------------------

from Tkinter import *
import ConfigParser
import socket
import os.path
import thread
import time
import datetime

APP_PATH      = os.path.dirname(os.path.realpath(__file__))
CFG_FILE_NAME = os.path.join(APP_PATH, 'wna_mes.ini')
BUFF_SIZE     = 4096

MainWnd                = None
StartBtn               = None
StopBtn                = None
SendBtn                = None
IpLabel                = None
IpEntry                = None
SendPortLabel          = None
SendPortEntry          = None
RecvPortLabel          = None
RecvPortEntry          = None
PipeNumLabel           = None
PipeNumEntry           = None
PipeDiameterLabel      = None
PipeDiameterEntry      = None
PipeThicknessLabel     = None
PipeThicknessEntry     = None
LoginLabel             = None
LoginEntry             = None
PersonnelNoLabel       = None
PersonnelNoEntry       = None
SendStatusCaptionLabel = None
SendStatusLabel        = None
RecvStatusCaptionLabel = None
RecvStatusLabel        = None

Ip       = '127.0.0.1'
SendPort = str(2000)
RecvPort = str(2001)

PipeNum       = ''
PipeDiameter  = ''
PipeThickness = ''
Login         = ''
PersonnelNo   = ''

SendSock       = None
RecvSock       = None
SendThread     = None
RecvThread     = None
SendTerminated = False
RecvTerminated = False
SendStatus     = -1
RecvStatus     = -1
SendEx         = None
RecvEx         = None
SendPipeOn     = False
SendCounter    = 0

#-----------------------------------------------------------
def Init():
    global MainWnd
    global StartBtn
    global StopBtn
    global SendBtn
    global IpEntry
    global IpLabel
    global SendPortEntry
    global SendPortLabel
    global RecvPortEntry
    global RecvPortLabel
    global PipeNumEntry
    global PipeNumLabel
    global PipeDiameterEntry
    global PipeDiameterLabel
    global PipeThicknessEntry
    global PipeThicknessLabel
    global LoginEntry
    global LoginLabel
    global PersonnelNoEntry
    global PersonnelNoLabel
    global SendStatusCaptionLabel
    global SendStatusLabel
    global RecvStatusCaptionLabel
    global RecvStatusLabel

    def create_separator():
        return Frame(MainWnd, height=2, bd=1, relief=SUNKEN)

    MainWnd = Tk()
    MainWnd.title(u"MES-Симулятор")
    MainWnd.protocol('WM_DELETE_WINDOW', OnDestroy)

    IpLabel         = Label(MainWnd)
    IpLabel['text'] = u'IP:'

    IpEntry          = Entry(MainWnd)
    IpEntry['width'] = 20

    SendPortLabel         = Label(MainWnd)
    SendPortLabel['text'] = u'Порт передатчика:'

    SendPortEntry          = Entry(MainWnd)
    SendPortEntry['width'] = 8

    RecvPortLabel         = Label(MainWnd)
    RecvPortLabel['text'] = u'Порт получателя:'

    RecvPortEntry          = Entry(MainWnd)
    RecvPortEntry['width'] = SendPortEntry['width']

    pipe_separator = create_separator()

    PipeNumLabel          = Label(MainWnd)
    PipeNumLabel['text']  = u'Номер трубы:'

    PipeNumEntry          = Entry(MainWnd)
    PipeNumEntry['width'] = IpEntry['width']

    PipeDiameterLabel         = Label(MainWnd)
    PipeDiameterLabel['text'] = u'Диаметр трубы:'

    PipeDiameterEntry          = Entry(MainWnd)
    PipeDiameterEntry['width'] = SendPortEntry['width']

    PipeThicknessLabel         = Label(MainWnd)
    PipeThicknessLabel['text'] = u'Толщина стенки:'

    PipeThicknessEntry          = Entry()
    PipeThicknessEntry['width'] = SendPortEntry['width']

    LoginLabel         = Label(MainWnd)
    LoginLabel['text'] = u'Логин:'

    LoginEntry          = Entry(MainWnd)
    LoginEntry['width'] = IpEntry['width']

    PersonnelNoLabel         = Label(MainWnd)
    PersonnelNoLabel['text'] = u'Персональный номер:'

    PersonnelNoEntry          = Entry()
    PersonnelNoEntry['width'] = IpEntry['width']

    buttons_separator = create_separator()

    buttons_frame = Frame(MainWnd)
        
    StartBtn            = Button(buttons_frame)
    StartBtn['text']    = u'Старт'
    StartBtn['command'] = StartBtnClicked
    StartBtn['width']   = 8
    
    StopBtn            = Button(buttons_frame)
    StopBtn['text']    = u'Стоп'
    StopBtn['state']   = 'disable'
    StopBtn['command'] = StopBtnClicked
    StopBtn['width']   = StartBtn['width']

    SendBtn            = Button(buttons_frame)
    SendBtn['text']    = u'Послать'
    SendBtn['state']   = 'disable'
    SendBtn['command'] = SendBtnClicked
    SendBtn['width']   = StartBtn['width']
    
    StartBtn.grid(row=0, column=0, padx=4)
    StopBtn.grid(row=0,  column=1, padx=4)
    SendBtn.grid(row=0,  column=2, padx=4)

    status_separator = create_separator()

    SendStatusCaptionLabel         = Label(bd=0, pady=0)
    SendStatusCaptionLabel['text'] = u'Передача:'

    SendStatusLabel = Label(bd=1, relief=GROOVE, height=2, bg='#E0FFE0',
     wraplength=240, justify=LEFT, anchor='nw')

    RecvStatusCaptionLabel         = Label(bd=0, pady=0)
    RecvStatusCaptionLabel['text'] = u'Прием:'
    
    RecvStatusLabel = Label(bd=1, relief=GROOVE, height=2, bg='#E0FFE0',
     wraplength=240, justify=LEFT, anchor='nw')

    curr_row = 0
    IpLabel.grid(row=curr_row, column=0, sticky='e')
    IpEntry.grid(row=curr_row, column=1, columnspan=2, sticky='w')
    curr_row += 1
    SendPortLabel.grid(row=curr_row, column=0, sticky='e')
    SendPortEntry.grid(row=curr_row, column=1, sticky='w')
    curr_row += 1
    RecvPortLabel.grid(row=curr_row, column=0, sticky='e')
    RecvPortEntry.grid(row=curr_row, column=1, sticky='w')
    curr_row += 1
    pipe_separator.grid(row=curr_row, column=0, columnspan=3, sticky="we",
     pady=4)
    curr_row += 1
    PipeNumLabel.grid(row=curr_row, column=0, sticky='e')
    PipeNumEntry.grid(row=curr_row, column=1, columnspan=2, sticky='w')
    curr_row += 1
    PipeDiameterLabel.grid(row=curr_row, column=0, sticky='e')
    PipeDiameterEntry.grid(row=curr_row, column=1, sticky='w')
    curr_row += 1
    PipeThicknessLabel.grid(row=curr_row, column=0, sticky='e')
    PipeThicknessEntry.grid(row=curr_row, column=1, sticky='w')
    curr_row += 1
    LoginLabel.grid(row=curr_row, column=0, sticky='e')
    LoginEntry.grid(row=curr_row, column=1, columnspan=2, sticky='w')
    curr_row += 1
    PersonnelNoLabel.grid(row=curr_row, column=0, sticky='e')
    PersonnelNoEntry.grid(row=curr_row, column=1, columnspan=2, sticky='w')
    curr_row += 1
    buttons_separator.grid(row=curr_row, column=0, columnspan=3, sticky="we",
     pady=4)
    curr_row += 1
    buttons_frame.grid(row=curr_row, column=0, columnspan=3)
    curr_row += 1
    status_separator.grid(row=curr_row, column=0, columnspan=3, sticky="we",
     pady=4)
    curr_row += 1
    SendStatusCaptionLabel.grid(row=curr_row, column=0, sticky='w')
    curr_row += 1
    SendStatusLabel.grid(row=curr_row, column=0, columnspan=3, sticky='we')
    curr_row += 1
    RecvStatusCaptionLabel.grid(row=curr_row, column=0, sticky='w')
    curr_row += 1
    RecvStatusLabel.grid(row=curr_row, column=0, columnspan=3, sticky='we')

#-----------------------------------------------------------
def Load():
    LoadCfg()

    IpEntry.insert(0, Ip)
    SendPortEntry.insert(0, SendPort)
    RecvPortEntry.insert(0, RecvPort)
    PipeNumEntry.insert(0, PipeNum)
    PipeDiameterEntry.insert(0, PipeDiameter)
    PipeThicknessEntry.insert(0, PipeThickness)
    LoginEntry.insert(0, Login)
    PersonnelNoEntry.insert(0, PersonnelNo)

    UpdateStatus()

#-----------------------------------------------------------
def Save():
    SaveCfg()

#-----------------------------------------------------------
def Run():
    MainWnd.mainloop()

#-----------------------------------------------------------
def Main():
    Init()
    Load()
    Run()
    Save()

#-----------------------------------------------------------
def StartBtnClicked():
    global Ip
    global SendPort
    global RecvPort
    global SendThread
    global RecvThread
    global SendPipeOn
    global RecvTerminated
    global SendTerminated

    SendPipeOn = False
    
    StartBtn['state'] = 'disable'
    StopBtn['state']  = 'normal'
    SendBtn['state']  = 'normal'

    Ip       = IpEntry.get()
    SendPort = SendPortEntry.get()
    RecvPort = RecvPortEntry.get()

    RecvTerminated = False
    SendTerminated = False

    SendThread = thread.start_new_thread(SendComm, ())
    RecvThread = thread.start_new_thread(RecvComm, ())

#-----------------------------------------------------------
def StopBtnClicked():
    global SendTerminated
    global RecvTerminated

    SendTerminated = True
    RecvTerminated = True
    
    StartBtn['state'] = 'normal'
    StopBtn['state']  = 'disable'
    SendBtn['state']  = 'disable'

    try:
        RecvSock.close()
    except:
        pass
    
    try:
        SendSock.close()
    except:
        pass
    
#-----------------------------------------------------------
def SendBtnClicked():
    global PipeNum
    global PipeDiameter
    global PipeThickness
    global Login
    global PersonnelNo
    global SendPipeOn

    PipeNum       = PipeNumEntry.get()
    PipeDiameter  = PipeDiameterEntry.get()
    PipeThickness = PipeThicknessEntry.get()
    Login         = LoginEntry.get()
    PersonnelNo   = PersonnelNoEntry.get()
    SendPipeOn    = True

#-----------------------------------------------------------
def LoadCfg():
    global Ip
    global SendPort
    global RecvPort
    global PipeNum
    global PipeDiameter
    global PipeThickness
    global Login
    global PersonnelNo

    cfg = ConfigParser.ConfigParser()
    cfg.read(CFG_FILE_NAME)

    curr_sect = ['']

    def begin_sect(sect):
        curr_sect[0] = sect
    def rd(key, def_val = ''):
        try:
            val = cfg.get(curr_sect[0], key)
            if val != None:
                return val
        except:
            pass
        return def_val

    begin_sect('Net')
    Ip       = rd('Ip',       Ip)
    SendPort = rd('SendPort', SendPort)
    RecvPort = rd('RecvPort', RecvPort)
    
    begin_sect('Pipe')
    PipeNum       = rd('PipeNum')
    PipeDiameter  = rd('PipeDiameter')
    PipeThickness = rd('PipeThickness')
    Login         = rd('Login')
    PersonnelNo   = rd('PersonnelNo')
    

#-----------------------------------------------------------
def SaveCfg():
    cfg = ConfigParser.ConfigParser()
    cfg.optionxform = str
    try:
        cfg.read(open(CFG_FILE_NAME), 'r')
    except:
        pass

    curr_sect = ['']

    def begin_sect(sect):
        curr_sect[0] = sect
        cfg.add_section(sect)
    def wr(key, value):
        cfg.set(curr_sect[0], key, value)

    begin_sect('Net')
    wr('Ip',       Ip)
    wr('SendPort', SendPort)
    wr('RecvPort', RecvPort)
    
    begin_sect('Pipe')
    wr('PipeNum',       PipeNum)
    wr('PipeDiameter',  PipeDiameter)
    wr('PipeThickness', PipeThickness)
    wr('Login',         Login)
    wr('PersonnelNo',   PersonnelNo)
    
    try:
        cfg.write(open(CFG_FILE_NAME, 'w'))
    except:
        pass

#-----------------------------------------------------------
def OnDestroy():
    global Ip
    global SendPort
    global RecvPort
    global PipeNum
    global PipeDiameter
    global PipeThickness
    global Login
    global PersonnelNo

    try:
        RecvSock.close()
    except:
        pass

    try:
        SendSock.close()
    except:
        pass

    Ip            = IpEntry.get()
    SendPort      = SendPortEntry.get()
    RecvPort      = RecvPortEntry.get()
    PipeNum       = PipeNumEntry.get()
    PipeDiameter  = PipeDiameterEntry.get()
    PipeThickness = PipeThicknessEntry.get()
    Login         = LoginEntry.get()
    PersonnelNo   = PersonnelNoEntry.get()
    
    MainWnd.destroy()

#-----------------------------------------------------------
def UpdateStatus():
    ss = SendStatus
    if ss == 0:
        txt = u'Создание сокета.'        
    elif ss == 1:
        txt = u'Подключение.'
    elif ss == 2:
        txt = u'Установка таймаута.'
    elif ss == 100:
        txt = u'Передача TubeInfo.'
    elif ss == 101:
        txt = u'Передача WDOG.'
    else:
        txt = ''
    if SendEx != None:
        txt = txt + str(SendEx).decode('cp1251')
    if SendStatusLabel['text'] != txt:
        SendStatusLabel['text'] = txt

    rs = RecvStatus
    if rs == 0:
        txt = u'Создание сокета.'
    elif rs == 1:
        txt = u'Подключение.'
    elif rs == 2:
        txt = u'Установка таймаута.'
    elif rs == 100:
        txt = u'Прием.'
    elif rs == 101:
        txt = u'Отправка.'
    else:
        txt = ''
    if RecvEx != None:
        txt = txt + str(RecvEx).decode('cp1251')
    if RecvStatusLabel['text'] != txt:
        RecvStatusLabel['text'] = txt
                
    MainWnd.after(500, UpdateStatus)

#-----------------------------------------------------------
def RecvComm():
    global RecvEx
    global RecvSock

    RecvEx = None
    
    try:
        RecvCommImpl()
    except Exception as e:
        RecvEx = e
        
    try:
        RecvSock.close()
    except:
        pass
    
    RecvSock = None

#-----------------------------------------------------------
def RecvCommImpl():
    global RecvSock
    global RecvStatus    
    
    RecvStatus = 0
    RecvSock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    RecvStatus = 1
    RecvSock.connect((Ip, int(RecvPort)))
    RecvStatus = 2

    while not RecvTerminated:
        RecvStatus = 100
        request = Recv(RecvSock)
        if len(request) < 70:
            continue
        message_id = request[6 : 6 + 6].rstrip(chr(0))
        if message_id == 'WDOG':
            answer = AnswerOnWdog(request)
        else:
            answer = AnswerOnUnknown(request)
        RecvStatus = 101
        Send(RecvSock, answer)
            
#-----------------------------------------------------------
def SendComm():
    global SendEx

    SendEx = None

    try:
        SendCommImpl()
    except Exception as e:
        SendEx = e

#-----------------------------------------------------------
def SendCommImpl():
    global SendSock
    global SendStatus
    global SendPipeOn

    SendStatus = 0
    SendSock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    SendStatus = 1
    SendSock.connect((Ip, int(SendPort)))
    SendStatus = 2

    while not SendTerminated:
        if SendPipeOn:
            SendStatus = 100
            SendPipe(SendSock)
            SendPipeOn = False
        else:
            SendStatus = 101
            SendWdog(SendSock)
        for i in xrange(30):
            time.sleep(0.1)
            if SendTerminated:
                break

#-----------------------------------------------------------
def AnswerOnWdog(request):
    return request[0 : 6 + 56] + NetWordToStr(0) + request[6 + 56 + 2:]

#-----------------------------------------------------------
def AnswerOnUnknown(request):
    return request[0 : 6 + 56] + NetWordToStr(1) + request[6 + 56 + 2:]    

#-----------------------------------------------------------
def SendWdog(s):
    global SendStatus
    global SendCounter

    dttm = datetime.datetime.utcnow()

    i = 0
    # 0
    buff = NetWordToStr(0x0202)
    i += 2
    buff = buff + NetDwordToStr(64)
    i += 4
    # 1
    buff = buff + 'WDOG\000\000'
    i += 6
    # 2
    buff = buff + 'PC11'
    i += 4
    # 3
    buff = buff + 'GRSC'
    i += 4
    # 4
    buff = buff + NetWordToStr(SendCounter)
    SendCounter += 1
    if SendCounter == 10000:
        SendCounter = 0
    i += 2
    # 5
    buff = buff + NetWordToStr(dttm.year)
    i += 2
    # 6
    buff = buff + NetWordToStr(dttm.month)
    i += 2
    # 7
    buff = buff + NetWordToStr(dttm.day)
    i += 2
    # 8
    buff = buff + NetWordToStr(dttm.hour)
    i += 2
    # 9
    buff = buff + NetWordToStr(dttm.minute)
    i += 2
    # 10
    buff = buff + NetWordToStr(dttm.second)
    i += 2
    # 11
    buff = buff + '0800'
    i += 4
    # 12
    buff = buff + 'MACH'
    i += 4
    # 13
    buff = buff + '0000'
    i += 4
    # 14
    for j in xrange(0, 16):
        buff = buff + chr(0)
    i += 16
    # 15
    buff = buff + NetWordToStr(0)
    i += 2
    # 16
    while i < 70:
        buff = buff + chr(0)
        i += 1
    s.sendall(buff)
    answer = Recv(s)
    
#-----------------------------------------------------------
def SendPipe(s):
    global SendStatus
    global SendCounter

    dttm = datetime.datetime.utcnow()

    i = 0
    # 0
    buff = NetWordToStr(0x0202)
    i += 2
    buff = buff + NetDwordToStr(64)
    i += 4
    # 1
    buff = buff + 'TBIN\000\000'
    i += 6
    # 2
    buff = buff + 'PC11'
    i += 4
    # 3
    buff = buff + 'GRSC'
    i += 4
    # 4
    buff = buff + NetWordToStr(SendCounter)
    SendCounter += 1
    if SendCounter == 10000:
        SendCounter = 0
    i += 2
    # 5
    buff = buff + NetWordToStr(dttm.year)
    i += 2
    # 6
    buff = buff + NetWordToStr(dttm.month)
    i += 2
    # 7
    buff = buff + NetWordToStr(dttm.day)
    i += 2
    # 8
    buff = buff + NetWordToStr(dttm.hour)
    i += 2
    # 9
    buff = buff + NetWordToStr(dttm.minute)
    i += 2
    # 10
    buff = buff + NetWordToStr(dttm.second)
    i += 2
    # 11
    buff = buff + '0800'
    i += 4
    # 12
    buff = buff + 'MACH'
    i += 4
    # 13
    buff = buff + '0000'
    i += 4
    # 14
    for j in xrange(0, 16):
        buff = buff + chr(0)
    i += 16
    # 15
    buff = buff + NetWordToStr(0)
    i += 2
    # 16
    while i < 70:
        buff = buff + chr(0)
        i += 1
        
    # 2
    buff = buff + (PipeNum + (chr(0) * 14))[0 : 14]
    i += 14
    # 3
    buff = buff + (Login + (chr(0) * 14))[0 : 14]
    i += 14
    # 4
    buff = buff + (PersonnelNo + (chr(0) * 14))[0 : 14]
    i += 14
    # 5
    buff = buff + (PipeThickness + (chr(0) * 14))[0 : 14]
    i += 14
    # 6
    buff = buff + (PipeDiameter + (chr(0) * 14))[0 : 14]
    i += 14
    s.sendall(buff)
    answer = Recv(s)

#-----------------------------------------------------------
def Recv(s):
    data = ''
    i    = 0
    while i < 2:
        buff = s.recv(BUFF_SIZE)
        if buff == '':
            raise Exception('Receive error')
        data = data + buff
        i = len(data)

    if NetStrToWord(data[0:2]) != 0x0202:
        return ''

    while i < 6:
        buff = s.recv(BUFF_SIZE)
        if buff == '':
            raise Exception('Receive error')
        data = data + buff
        i = len(data)

    n = NetStrToDword(data[2:6])
    while i < n + 6:
        buff = s.recv(BUFF_SIZE)
        if buff == '':
            raise Exception('Receive error')
        data = data + buff
        i = len(data)
    return data

#-----------------------------------------------------------
def Send(s, buff):
    s.sendall(buff)

#-----------------------------------------------------------
def NetStrToWord(buff):
    return ord(buff[0])*0x100 + ord(buff[1])

#-----------------------------------------------------------
def NetStrToDword(buff):
    return ord(buff[0])*0x1000000 + \
           ord(buff[1])*0x10000   + \
           ord(buff[2])*0x100     + \
           ord(buff[3])

#-----------------------------------------------------------
def NetWordToStr(v):
    v %= 0x10000
    return chr(v/0x100) + chr(v%0x100)

#-----------------------------------------------------------
def NetDwordToStr(v):
    buff = ''
    for i in xrange(0, 4):
        buff = chr(v%0x100) + buff
        v /= 0x100
    return buff
