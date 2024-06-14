unit Mes;

interface

uses Windows, SysUtils, WinSock, Global;

const
  MesTimeout = 20000;
  MesWdogMessageId: String     = 'WDOG';
  MesTubeInfoMessageId: String = 'TBIN';

function MesCreateSocket: TSocket;
procedure MesCloseSocket(S: TSocket);
function MesSetSockOpt(S: TSocket; Level, OptName: Integer; OptVal: PChar;
  OptLen: Integer): Boolean;
function MesSetSocketTimeout(S: TSocket): Boolean;
function MesIsSocketValid(S: TSocket): Boolean;
function MesSend(S: TSocket; Buff: PChar; BuffLen: Integer): Boolean;
function MesSendWdog(S: TSocket; Buff: PChar; BuffSize: Integer): Boolean;
function MesRecv(S: TSocket; Buff: PChar; BuffSize: Integer): Integer;
function MesRecvAnswer(S: TSocket; Buff: PChar; BuffSize: Integer): Boolean;
function MesBind(S: TSocket; Port: Integer): Boolean;
function MesListen(S: TSocket): Boolean;
function MesAccept(S: TSocket): TSocket;

procedure MesFillData(Dst: PChar; Value: Byte; N: Integer);
procedure MesSetData(Dst: PChar; Src: PChar; N: Integer);
procedure MesSetInt16(Dst: PChar; Value: Int16);
procedure MesSetWord(Dst: PChar; Value: Word);
procedure MesSetDword(Dst: PChar; Value: Dword);
procedure MesSetStr(Dst: PChar; Value: String);
procedure MesPrepareHeader(Buff: PChar);
procedure MesPrepareWdogHeader(buff: PChar);
procedure MesGetData(Dst: PChar; Src: PChar; N: Integer);
function MesGetInt16(Src: PChar): Int16;
function MesGetWord(Src: PChar): Word;
function MesGetDword(Src: PChar): Dword;
function MesGetStr(Src: PChar; N: Integer): String;
function MesGetRawStr(Src: PChar; N: Integer): String;
function MesStrToHexStr(Src: String): String;
procedure MesLog(Txt: String);

implementation

const
  MesHeaderSize                = 64;

var
  MesSendCounter: Integer;

function MesCreateSocket: TSocket;
begin
  Result := Socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
end;

procedure MesCloseSocket(S: TSocket);
begin
  if S <> TSocket(SOCKET_ERROR) then
  begin
   ShutDown(S, 4);
   CloseSocket(S);
  end;
end;

function MesSetSockOpt(S: TSocket; Level, OptName: Integer; OptVal: PChar;
  OptLen: Integer): Boolean;
begin
  Result := SetSockOpt(S, Level, OptName, OptVal, OptLen) = 0;
end;

function MesSetSocketTimeout(S: TSocket): Boolean;
var
 T: Integer;
begin
  Result := False;
  T := MesTimeout;
  if not MesSetSockOpt(S, SOL_SOCKET, SO_SNDTIMEO, @T, sizeof(T)) then Exit;
  if not MesSetSockOpt(S, SOL_SOCKET, SO_RCVTIMEO, @T, sizeof(T)) then Exit;
  Result := True;
end;

function MesIsSocketValid(S: TSocket): Boolean;
begin
  Result := S <> TSocket(SOCKET_ERROR);
end;

function MesBind(S: TSocket; Port: Integer): Boolean;
var
  SockAddr: TSockAddr;
begin
  with SockAddr do
  begin
    sin_family      := AF_INET;
    sin_port        := Htons(Port);
    sin_addr.s_addr := INADDR_ANY;
  end;
  Result := Bind(S, SockAddr, sizeof(SockAddr)) = 0;
end;

function MesListen(S: TSocket): Boolean;
begin
  Result := Listen(S, 1) = 0;
end;

function MesSend(S: TSocket; Buff: PChar; BuffLen: Integer): Boolean;
var
  I, N: Integer;
begin
  Result := False;

  if not MesIsSocketValid(S) then Exit;

  I := 0;
  while BuffLen > 0 do begin
    N := Send(S, Buff[I], BuffLen, 0);
    if N < 0 then begin
      Result := False; Exit;
    end;
    Dec(BuffLen, N);
    Inc(I, N);
  end;
  Result := True;
end;

function MesAccept(S: TSocket): TSocket;
var
  ClientAddr:     TSockAddr;
  ClientAddrSize: Integer;
begin
  ClientAddrSize := SizeOf(ClientAddr);
  Result         := Accept(S, @ClientAddr, ClientAddrSize);
end;

function MesRecv(S: TSocket; Buff: PChar; BuffSize: Integer): Integer;
var
  I, N: Integer;
  Bytes: Integer;
begin
  Result := -1;

  I := 0;
  while I < 2 do
  begin
    Bytes := Recv(S, Buff[I], BuffSize - I, 0);
    if Bytes <= 0 then Exit;
    Inc(I, Bytes);
  end;
  //MesLog('Recv: ' + IntToStr(I));

  if MesGetWord(Buff) <> $0202 then Exit;

  //MesLog('Recv: KeyWord = ' + IntToHex(MesGetWord(Buff), 4));

  while I < 6 do
  begin
    Bytes := Recv(S, Buff[I], BuffSize - I, 0);
    if Bytes <= 0 then Exit;
    Inc(I, Bytes);
  end;

  N := MesGetDword(Buff + 2);
  if N > BuffSize - 6 then Exit;
  while I < N + 6 do begin
    Bytes := Recv(S, Buff[I], BuffSize - I, 0);
    if Bytes <= 0 then Exit;
    Inc(I, Bytes);
  end;
  Result := N + 6;
  //MesLog('Recv: Length = ' + IntToStr(Result));
end;

function MesRecvAnswer(S: TSocket; Buff: PChar; BuffSize: Integer): Boolean;
var
  N: Integer;
begin
  Result := False;
  N := MesRecv(S, Buff, BuffSize);
  if N <> 64 + 6 then Exit;
  Result := True;
end;

procedure MesFillData(Dst: PChar; Value: Byte; N: Integer);
var
  I: Integer;
  C: Char;
begin
  C := Char(Value);
  for I := 0 to N - 1 do
   Dst[I] := C;
end;

procedure MesSetData(Dst: PChar; Src: PChar; N: Integer);
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    Dst[N - 1 - I] := Src[I];
end;

procedure MesSetInt16(Dst: PChar; Value: Int16);
begin
  MesSetData(Dst, @Value, 2);
end;

procedure MesSetWord(Dst: PChar; Value: Word);
begin
  MesSetData(Dst, @Value, 2);
end;

procedure MesSetDword(Dst: PChar; Value: Dword);
begin
  MesSetData(Dst, @Value, 4);
end;

procedure MesSetStr(Dst: PChar; Value: String);
var
  I, N: Integer;
begin
  N := Length(Value);
  for I := 1 to N do
    Dst[I - 1] := Value[I];
end;

procedure MesGetData(Dst: PChar; Src: PChar; N: Integer);
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    Dst[N - 1 - I] := Src[I];
end;

function MesGetInt16(Src: PChar): Int16;
begin
  MesGetData(@Result, Src, 2);
end;

function MesGetWord(Src: PChar): Word;
begin
  MesGetData(@Result, Src, 2);
end;

function MesGetDword(Src: PChar): Dword;
begin
  MesGetData(@Result, Src, 4);
end;

function MesGetStr(Src: PChar; N: Integer): String;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 0 to N - 1 do
  begin
    C := Src[I];
    if C = Char(0) then Break;
    Result := Result + C;
  end;
end;

function MesGetRawStr(Src: PChar; N: Integer): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to N - 1 do
    Result := Result + Src[I];
end;

function MesStrToHexStr(Src: String): String;
var
  I: Integer;
  N: Integer;
begin
  N := Length(Src);
  Result := '';
  for I := 1 to N do
    Result := Result + IntToHex(Ord(Src[I]), 2);
end;

procedure MesPrepareHeader(Buff: PChar);
var
  I:    Integer;
  Hour,
  Min,
  Sec:  Word;
  Day,
  Mon,
  Year: Word;
  Utc:  TSystemTime;

begin
  GetSystemTime(Utc{%H-});

  Year := Utc.wYear;
  Mon  := Utc.wMonth;
  Day  := Utc.wDay;
  Hour := Utc.wHour;
  Min  := Utc.wMinute;
  Sec  := Utc.wSecond;

  I := 0;

  // 0
  MesSetWord(Buff + I, $0202);
  Inc(I, 2);
  MesSetDword(Buff + I, 64);
  Inc(I, 4);

  // 1
  MesFillData(Buff + I, 0, 6);
  Inc(I, 6);

  // 2 Sender
  MesSetStr(Buff + I, MesStanName);
  Inc(I, 4);

  // 3 Receiver
  MesSetStr(Buff + I, 'GRSC');
  Inc(I, 4);

  // 4 Counter
  MesSetWord(Buff + I, MesSendCounter);
  Inc(MesSendCounter);
  if MesSendCounter = 10000 then
    MesSendCounter := 0;
  Inc(I, 2);

  // 5 DTYear
  MesSetWord(Buff + I, Year);
  Inc(I, 2);

  // 6 DTMonth
  MesSetWord(Buff + I, Mon);
  Inc(I, 2);

  // 7 DTDay
  MesSetWord(Buff + I, Day);
  Inc(I, 2);

  // 8 DTHour
  MesSetWord(Buff + I, Hour);
  Inc(I, 2);

  // 9 DTMin
  MesSetWord(Buff + I, Min);
  Inc(I, 2);

  // 10 DTSec
  MesSetWord(Buff + I, Sec);
  Inc(I, 2);

  // 11 Line
  if Stan = 800
    then {%H-}MesSetStr(Buff + I, '0800')
    else {%H-}MesSetStr(Buff + I, '1000');
  Inc(I, 4);

  // 12 Machine
  MesSetStr(Buff + I, 'MACH');
  Inc(I, 4);

  // 13 Index
  MesSetStr(Buff + I, '0000');
  Inc(I, 4);

  // 14 User
  MesFillData(Buff + I, 0, 16);
  Inc(I, 16);

  // 15 Return status (0=ok, 1-refused)
  MesSetInt16(Buff + I, 0);
  Inc(I, 2);

  // 16 Reserved
  while I < MesHeaderSize do
  begin
    Buff[I] := Chr(0);
    Inc(I);
  end;
end;

procedure MesPrepareWdogHeader(Buff: PChar);
begin
  MesPrepareHeader(Buff);
  MesSetStr(Buff + 6, 'WDOG');
end;

function MesSendWdog(S: TSocket; Buff: PChar; BuffSize: Integer): Boolean;
begin
  Result := False;
  MesPrepareWdogHeader(Buff);
  if not MesSend(S, Buff, 64 + 6) then
    Exit;
  Result := MesRecvAnswer(S, Buff, BuffSize);
end;

procedure MesLog(Txt: String);
var
  DtTm: TDateTime;
begin
  if LogEnabled then
  begin
    DtTm := Now;
    LogWrite(DateToStr(DtTm) + ' ' + TimeToStr(DtTm) + '    ' + Txt);
    LogNL;
  end;
end;


end.
