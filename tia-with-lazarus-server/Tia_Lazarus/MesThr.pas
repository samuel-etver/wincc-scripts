unit MesThr;

interface

uses
  Classes, Mes, SysUtils, Global, WinSock, PipeNum;

type
  TMesActionType = (
    MES_AT_SEND,
    MES_AT_RECV
  );

  TMesActionThread = class;
  TMesSendThread   = class;
  TMesRecvThread   = class;

  TMesThread = class(TThread)
  private
    FListenSocket: TSocket;
    FAcceptSocket: TSocket;
    FActionType:   TMesActionType;
    FActionThread: TMesActionThread;
    FDescription:  string;
    procedure CloseListenSocket;
    procedure CloseAcceptSocket;
  protected
    procedure Execute; override;
  public
    constructor Create(ActionType: TMesActionType);
    destructor Destroy; override;
    procedure CloseSockets;
  end;

  TMesActionThread = class(TThread)
  private
    FSocket:  THandle;
  protected
    FMem:     PChar;
    FMemSize: Integer;
    function AnswerOnWdog: Integer;
    function AnswerOnUnknown: Integer;
  public
    constructor Create(ASocket: THandle);
    destructor Destroy; override;
    procedure CloseSocket;
    property Socket: THandle read FSocket;
  end;

  TMesSendThread = class(TMesActionThread)
  private
  protected
    procedure Execute; override;
  public
  end;

  TMesRecvThread = class(TMesActionThread)
  private
    FPipeNumItem: TPipeNumItem;
    function AnswerOnTubeInfo: Integer;
  protected
    procedure Execute; override;
    procedure AssignPipeNum;
  public
    constructor Create(ASocket: THandle);
    destructor Destroy; override;
    property PipeNumItem: TPipeNumItem read FPipeNumItem write FPipeNumItem;
  end;

implementation

const
  RecvDescription = 'Получатель';
  SendDescription = 'Отправитель';


// TMesThread
constructor TMesThread.Create(ActionType: TMesActionType);
begin
  inherited Create(False);
  FActionType   := ActionType;
  FActionThread := nil;
  FListenSocket := TSocket(SOCKET_ERROR);
  FAcceptSocket := TSocket(SOCKET_ERROR);
  case FActionType of
    MES_AT_RECV: FDescription := RecvDescription;
    MES_AT_SEND: FDescription := SendDescription;
  end;
end;

destructor TMesThread.Destroy;
begin
  Terminate;
  CloseAcceptSocket;
  CloseListenSocket;
  inherited;
end;

procedure TMesThread.Execute;
var
  OldActionThread: TMesActionThread;
  Port: Integer;
begin
  FListenSocket := MesCreateSocket;
  if not MesIsSocketValid(FListenSocket) then Exit;
  MesLog(FDescription + '. Cокет создан');

  if FActionType = MES_AT_RECV
    then Port := MesFromServerPort
    else Port := MesToServerPort;

  if not MesBind(FListenSocket, Port) then Exit;
  MesLog(FDescription + '. Bind успешен');

  if not MesListen(FListenSocket) then Exit;
  MesLog(FDescription + '. Listen успешен');

  while not Terminated do
  begin
    FAcceptSocket := MesAccept(FListenSocket);
    MesLog(FDescription + '. Accept вернул соединение');
    if not MesIsSocketValid(FAcceptSocket) then
    begin
      Sleep(100);
      Continue;
    end;
    MesLog(FDescription + '. Соединение установлено');

    if (not MesEnabled) or (not MesSetSocketTimeout(FAcceptSocket)) then
    begin
      CloseAcceptSocket;
      Sleep(100);
      Continue;
    end;

    OldActionThread := FActionThread;
    case FActionType of
      MES_AT_RECV: FActionThread := TMesRecvThread.Create(FAcceptSocket);
      MES_AT_SEND: FActionThread := TMesSendThread.Create(FAcceptSocket);
      else         CloseAcceptSocket;
    end;
    if Assigned(OldActionThread) then
    begin
      OldActionThread.Terminate;
      OldActionThread.CloseSocket;
      OldActionThread.WaitFor;
      OldActionThread.Free;
    end;
  end;
end;

procedure TMesThread.CloseListenSocket;
begin
  MesCloseSocket(FListenSocket);
  FListenSocket := TSocket(SOCKET_ERROR);
end;

procedure TMesThread.CloseAcceptSocket;
begin
  MesCloseSocket(FAcceptSocket);
  FAcceptSocket := TSocket(SOCKET_ERROR);
end;

procedure TMesThread.CloseSockets;
var
  CurrActionThread: TMesActionThread;
begin
  CurrActionThread := FActionThread;
  FActionThread := nil;
  if Assigned(CurrActionThread) then
  begin
    CurrActionThread.Terminate;
    CurrActionThread.CloseSocket;
    CurrActionThread.WaitFor;
    CurrActionThread.Free;
  end;

  CloseListenSocket;
  CloseAcceptSocket;
end;

//---------------------------------------------------------
// MesActionThread
//---------------------------------------------------------
constructor TMesActionThread.Create(ASocket: THandle);
begin
  inherited Create(False);
  FSocket  := ASocket;
  FMemSize := 4096;
  FMem     := AllocMem(FMemSize);
end;

destructor TMesActionThread.Destroy;
begin
  CloseSocket;
  if Assigned(FMem) then
    FreeMem(FMem, FMemSize);
  inherited;
end;

procedure TMesActionThread.CloseSocket;
var
  SocketTemp: THandle;
begin
  SocketTemp := FSocket;
  FSocket := INVALID_SOCKET;
  MesCloseSocket(SocketTemp);
end;

function TMesActionThread.AnswerOnWdog: Integer;
begin
  // Ok
  MesSetWord(FMem + 6 + 56, 0);
  Result := 64 + 6;
end;

function TMesActionThread.AnswerOnUnknown: Integer;
begin
  // Size
  MesSetDword(FMem + 2, 64);
  // Reject
  MesSetWord(FMem + 6 + 56, 1);
  Result := 64 + 6;
end;

//---------------------------------------------------------
// MesSendThread
//---------------------------------------------------------
procedure TMesSendThread.Execute;
var
  I:          Integer;
  ErrorCount: Integer;
begin
  ErrorCount := 0;

  if Assigned(FMem) then
  begin
    while (not Terminated) and MesEnabled do
    begin
      for I := 1 to 30 do
      begin
        Sleep(100);
        if Terminated then Exit;
      end;
      if MesSendWdog(FSocket, FMem, FMemSize) then
      begin
        MesCommST := True;
        MesCommTicks := GetTickCount64;
        ErrorCount := 0;
        MesLog(SendDescription + '. Wdog успешно послан')
      end
      else begin
        MesLog(SendDescription + '. Wdog вернул ошибку');
        Inc(ErrorCount);
        if ErrorCount = 7 then Break;
      end;
    end;
  end;

  MesCloseSocket(FSocket);
  FSocket := TSocket(SOCKET_ERROR);
end;


//---------------------------------------------------------
// MesRecvThread
//---------------------------------------------------------
constructor TMesRecvThread.Create(ASocket: THandle);
begin
  inherited Create(ASocket);
  FPipeNumItem  := nil;
end;

destructor TMesRecvThread.Destroy;
var
  Item: TPipeNumItem;
begin
  if Assigned(FPipeNumItem) then
  begin
    Item := FPipeNumItem;
    FPipeNumItem := nil;
    Item.Free;
  end;

  inherited;
end;

procedure TMesRecvThread.Execute;
var
  RecvSize:  Integer;
  SendSize:  Integer;
  MessageId: String;
begin
  while (not Terminated) and MesEnabled do
  begin
    RecvSize := MesRecv(FSocket, FMem, FMemSize);
    if RecvSize < 64 + 6 then Break;

    MessageId := MesGetStr(FMem + 6, 6);
    MesLog(RecvDescription + '. MessageId: ' + MessageId + '.');
    if MessageId = 'WDOG' then
      SendSize := AnswerOnWdog
    else if MessageId = 'TBIN' then
      SendSize := AnswerOnTubeInfo
    else
      SendSize := AnswerOnUnknown;

    if MesSend(FSocket, FMem, SendSize) then
    begin
      MesCommST := True;
      MesCommTicks := GetTickCount64;
      MesLog(RecvDescription + '. Ответ послан');
    end;
  end;
end;

function TMesRecvThread.AnswerOnTubeInfo: Integer;
var
  I:             Integer;
  PipeNumber:    String;
  Login:         String;
  PersonnelNo:   String;
  PipeThickness: String;
  PipeDiameter:  String;
  F:             String;
begin
  // 1
  I := 6 + 64;
  // 2
  PipeNumber := MesGetStr(FMem + I, 14);
  Inc(I, 14);
  // 3
  Login := MesGetStr(FMem + I, 14);
  Inc(I, 14);
  // 4
  PersonnelNo := MesGetStr(FMem + I, 14);
  Inc(I, 14);
  // 5
  PipeThickness := MesGetStr(FMem + I, 14);
  Inc(I, 14);
  // 6
  PipeDiameter  := MesGetStr(FMem + I, 14);
  Inc(I, 14);

  // Size
  MesSetDword(FMem + 2, 64);
  // Ok
  MesSetWord(FMem + 6 + 56, 0);
  Result := 64 + 6;

  FPipeNumItem               := TPipeNumItem.Create;
  FPipeNumItem.PipeNumber    := PipeNumber;
  FPipeNumItem.Login         := Login;
  FPipeNumItem.PersonnelNo   := PersonnelNo;
  FPipeNumItem.PipeThickness := PipeThickness;
  FPipeNumItem.PipeDiameter  := PipeDiameter;

  PipeNumListLock.Acquire;
  try
    AssignPipeNum;
  finally
    PipeNumListLock.Release;
  end;

  try
    F:='';
    for i:=1 to length(PipeThickness) do
    begin
      if PipeThickness[i]='.' then break;
      if PipeThickness[i]=',' then break;
      F:=F+PipeThickness[i];
    end;
    MesPipeThicknessR:=StrToInt(F);
  except
    MesPipeThicknessR:=0;
  end;
  MesPipeThickMessageEn := True;
end;

procedure TMesRecvThread.AssignPipeNum;
begin
  PipeNumList.Clear;
  PipeNumList.Add(FPipeNumItem);
  FPipeNumItem := nil;
end;

end.
