unit Net;

interface

uses Windows, SysUtils, Global, WinSock, PipeNum, Classes;

var
  NetHostName: string;
  NetHostIp:   string;

procedure NetInit;
procedure NetFin;
procedure NetLoadLib;
procedure NetFreeLib;
function NetIsLibLoaded: Boolean;
function NetCreateSocket: Boolean;
function NetIsSocketValid: Boolean;
procedure NetFreeSocket;
function NetSetSockOpt(Level, OptName: Integer; OptVal: PChar;
  OptLen: Integer): Boolean;
function NetConnect: Boolean;
function NetBeginWrite(DataDir: string; PipeNumItem: TPipeNumItem): Boolean;
function NetEndWrite: Boolean;
{function NetWriteMsg: Boolean;
function NetWriteData: Boolean;
function NetWriteParam(Param, Con: Integer): Boolean;
function NetLoadParam(Buff: PChar; Param, Con: Integer): Boolean;}

procedure NetSetArchivePort(Port: Int32); cdecl;
procedure NetSetArchiveIp(Ip: PChar); cdecl;
procedure NetSetArchiveFolder(Folder: PChar); cdecl;

{
  send:
    0..9: Key word ('WELDING')

    header:
    0..2:  Packet size
    4..5:  packet id

    data packet:
    6: param id
    7: controler
    8..: Data

  recv:
    0..1: (0=FALSE,1=OK)
}

implementation

const
  NetMemSize            = $10000;
  NetFileSizeMax        = $8000;
  NetTimeout            = 5000;
  NetKeySize            = 10;
  NetPipeNumSize        = 20;
  NetPipeThicknessSize  = 20;
  NetPacketFastKey      = $01230123;
  NetPacketHeaderSize   = 10;
  NetPacketBeginId      = 1;
  NetPacketEndId        = 2;
  NetPacketWriteDataId  = 3;
  NetPacketWriteMsgId   = 4;
  NetPacketWriteParamId = 5;
  NetPacketWriteIniFileId = 6;

var
  NetLibLoaded: Boolean;
  NetMem:       PChar;
  NetRecvSize:  Integer;
  NetFileSize:  Integer;
  NetKey:       string;
  NetDataDir:   string;
  S:            TSocket;
  NetVersion:   Word;

procedure NetSetBytes(Index: Integer; Data: PChar; DataSize: Integer); forward;
procedure NetSetByte(Index: Integer; Value: Byte); forward;
procedure NetSetWord(Index: Integer; Value: Word); forward;
procedure NetSetDword(Index: Integer; Value: Dword); forward;
procedure NetSetString(Index: Integer; Value: string); forward;
procedure NetCreatePacketHeader(PacketSize: Integer; PacketId: Integer); forward;
{function NetLoadMsg(Buff: PChar): Boolean; forward;
function NetLoadData(Buff: PChar): Boolean; forward;   }{
function NetLoadIniFile(Buff: PChar): Boolean; forward;
function NetLoadFile(Buff: PChar; FileName: String): Boolean; forward; }
function NetLoadFileWithAbsolutePath(Buff: PChar; FullFilePath: String): Boolean; forward;


procedure NetInit;
begin
  NetLoadLib;
end;


procedure NetFin;
begin
  NetFreeLib;
end;

procedure NetLoadLib;
var
  WSAData:  TWSAData;
  I:     Integer;
  HostName: array[0..255] of Char;
  HostEnt:  PHostEnt;
  Ip:       string;
begin
  NetMem := AllocMem(NetMemSize);
  NetFileSize := 0;
  NetLibLoaded := WSAStartup(1*$100+1, WSAData) = 0;
  NetKey := 'WELDING';
  while Length(NetKey) < NetKeySize do
    NetKey := NetKey + ' ';
  if NetLibLoaded then
  begin
    gethostname(HostName, SizeOf(HostName));
    NetHostName := HostName;
    HostEnt := gethostbyname(HostName);
    Ip := '';
    for I := 0 to HostEnt^.h_length - 1 do
    begin
      Ip := Ip + IntToStr(Ord(HostEnt^.h_addr_list^[i])) + '.';
    end;
    Ip := Copy(Ip, 1, Length(Ip) - 1);
    NetHostIp := Ip;
  end
  else
  begin
    NetHostName := '';
    NetHostIp   := '';
  end;
end;

function NetIsLibLoaded: Boolean;
begin
  Result := NetLibLoaded;
end;

procedure NetFreeLib;
begin
 WSACleanup;

 FreeMem(NetMem);
end;

function NetCreateSocket: Boolean;
var
  T: Integer;
label
  OnError;
begin
  Result := False;

  S := Socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
  if not NetIsSocketValid then Exit;

  T := NetTimeout;
  if not NetSetSockOpt(SOL_SOCKET, SO_SNDTIMEO, @T, sizeof(T)) then
    goto OnError;

  T := NetTimeout;
  if not NetSetSockOpt(SOL_SOCKET, SO_RCVTIMEO, @T, sizeof(T)) then
    goto OnError;

  Result := True;
  Exit;

  OnError: begin
    NetFreeSocket;
  end;
end;

function NetSetSockOpt(Level, OptName: Integer; OptVal: PChar;
  OptLen: Integer): Boolean;
begin
  Result := SetSockOpt(S, Level, OptName, OptVal, OptLen) = 0;
end;

function NetIsSocketValid: Boolean;
begin
  Result := S <> TSocket(SOCKET_ERROR);
end;

procedure NetFreeSocket;
begin
 ShutDown(S, 4);
 CloseSocket(S);
 S := 0;
end;

function NetConnect: Boolean;
var
  SockAddr: TSockAddr;
begin
  with SockAddr do begin
    sin_family := AF_INET;
    sin_port := Htons(ArchiveNetPort);
    sin_addr.s_addr := Inet_Addr(PChar(ArchiveNetIp));
  end;
  Result := Connect(S, SockAddr, SizeOf(SockAddr)) <> SOCKET_ERROR;
end;

function NetSend: Boolean;
var
  I, N, Len: Integer;
begin
  Len := 2 + Byte(NetMem[0]) + $100*Byte(NetMem[1]);
  I := 0;
  while Len > 0 do begin
    N := Send(S, NetMem[I], Len, 0);
    if N < 0 then begin
      Result := False; Exit;
    end;
    Dec(Len, N);
    Inc(I, N);
  end;
  Result := True;
end;

function NetRecv: Boolean;
var
  I, N: Integer;
  Bytes: Integer;
begin
  Result := False;
  I := 0;
  while I < 2 do begin
    Bytes := Recv(S, NetMem[I], NetMemSize - I, 0);
    if Bytes < 0 then Exit;
    Inc(I, Bytes);
  end;

  N := Byte(NetMem[0]) + $100*Byte(NetMem[1]);
  if N > NetMemSize then Exit;
  while I < N + 2 do begin
    Bytes := Recv(S, NetMem[I], NetMemSize - I, 0);
    if Bytes < 0 then Exit;
    Inc(I, Bytes);
  end;
  NetRecvSize := N + 2;
  Result := True;
end;

function NetRecvSucceeded: Boolean;
begin
  Result := False;
  if not NetRecv then Exit;
  if NetRecvSize <> 4 then Exit;
  if NetMem[2] <> Char($FF) then Exit;
  if NetMem[3] <> Char($FF) then Exit;
  Result := True;
end;
{
procedure NetSavePipeNumItem(PipeNumItem: TPipeNumItem);
var
  Lines:    TStringList;
  FilePath: string;
begin
  FilePath := NetDataDir + 'data';
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FilePath);
    with PipeNumItem do
    begin
      Lines.Add('PipeNumber=' + PipeNumber);
      Lines.Add('Login=' + Login);
      Lines.Add('PersonnelNo=' + PersonnelNo);
      Lines.Add('PipeThickness=' + PipeThickness);
      Lines.Add('PipeDiameter=' + PipeDiameter);
    end;
    Lines.SaveToFile(FilePath);
  except
  end;
  Lines.Free;
end;     }

function NetBeginWrite(DataDir: string; PipeNumItem: TPipeNumItem): Boolean;
var
  I, N:          Integer;
  PipeNum:       string;
  PipeThickness: string;
begin
  Result := False;
  N := Length(DataDir);
  if N > 0 then
    if DataDir[N] <> '\' then
      DataDir := DataDir + '\';
  NetDataDir := DataDir;

  if Assigned(PipeNumItem) then
  begin
    //NetSavePipeNumItem(PipeNumItem);
    NetVersion := $110;
    N := NetKeySize + NetPipeNumSize + NetPipeThicknessSize;
    PipeNum := Copy(PipeNumItem.PipeNumber, 1, NetPipeNumSize);
    for I := Length(PipeNum) + 1 to NetPipeNumSize do
      PipeNum := PipeNum + Chr(0);
    PipeThickness := Copy(PipeNumItem.PipeThickness, 1, NetPipeThicknessSize);
    for I := Length(PipeThickness) + 1 to NetPipeThicknessSize do
      PipeThickness := PipeThickness + Chr(0);
  end
  else
  begin
    NetVersion := $100;
    N := NetKeySize;
  end;

  NetCreatePacketHeader(N, NetPacketBeginId);
  I := NetPacketHeaderSize;
  NetSetstring(I, NetKey);
  Inc(I, NetKeySize);
  if NetVersion = $110 then
  begin
    NetSetString(I, PipeNum);
    Inc(I, NetPipeNumSize);
    NetSetString(I, PipeThickness);
    Inc(I, NetPipeThicknessSize);
  end;

  if not NetSend then Exit;
  Result := NetRecvSucceeded;
end;

function NetEndWrite: Boolean;
begin
  Result := True;
  NetCreatePacketHeader(0, NetPacketEndId);
  if not NetSend then Exit;
  Result := NetRecvSucceeded;
end;
{
function NetWriteMsg: Boolean;
begin
  Result := False;
  if not NetLoadMsg(@NetMem[NetPacketHeaderSize]) then begin
    Result := True; Exit;
  end;
  NetCreatePacketHeader(NetFileSize, NetPacketWriteMsgId);
  if not NetSend then Exit;
  Result := NetRecvSucceeded;
end;

function NetWriteData: Boolean;
begin
  Result := False;
  if not NetLoadData(@NetMem[NetPacketHeaderSize]) then begin
    Result := True; Exit;
  end;
  NetCreatePacketHeader(NetFileSize, NetPacketWriteDataId);
  if not NetSend then Exit;
  Result := NetRecvSucceeded;
end;

function NetWriteIniFile: Boolean;
begin
  Result := False;
  if not NetLoadIniFile(@NetMem[NetPacketHeaderSize]) then begin
    Result := True; Exit;
  end;
  NetCreatePacketHeader(NetFileSize, NetPacketWriteIniFileId);
  if not NetSend then Exit;
  Result := NetRecvSucceeded;
end;

function NetWriteParam(Param, Con: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;

  I := NetPacketHeaderSize;
  NetSetByte(I + 0, Param);
  NetSetByte(I + 1, Con);
  if not NetLoadParam(@NetMem[I + 2], Param, Con) then begin
    Result := True; Exit;
  end;

  NetCreatePacketHeader(NetFileSize + 2, NetPacketWriteParamId);
  if not NetSend then Exit;
  Result := NetRecvSucceeded;
end;    }

procedure NetSetBytes(Index: Integer; Data: PChar; DataSize: Integer);
var
  I: Integer;
begin
  for I := 1 to DataSize do
    NetMem[Index + I - 1] := Data[I - 1];
end;

procedure NetSetByte(Index: Integer; Value: Byte);
begin
  NetSetBytes(Index, @Value, 1);
end;

procedure NetSetWord(Index: Integer; Value: Word);
begin
  NetSetBytes(Index, @Value, 2);
end;

procedure NetSetDword(Index: Integer; Value: Dword);
begin
  NetSetBytes(Index, @Value, 4);
end;

procedure NetSetString(Index: Integer; Value: string);
var
  I, N: Integer;
begin
  N := Length(Value);
  for I := 1 to N do
    NetSetByte(Index + I - 1, Ord(Value[I]));
end;

procedure NetCreatePacketHeader(PacketSize: Integer; PacketId: Integer);
begin
  NetSetWord(0, PacketSize + 8);
  NetSetDword(2, NetPacketFastKey);
  NetSetWord(6, NetVersion);
  NetSetWord(8, PacketId);
end;

function NetLoadFileWithAbsolutePath(Buff: PChar; FullFilePath: String): Boolean;
var
  FileHandle: Integer;
  Tmp: Integer;
label
  OnError;
begin
  Result := False;

  FileHandle := FileOpen(FullFilePath, fmOpenRead);
  if FileHandle < 0 then Exit;

  NetFileSize := FileSeek(FileHandle, 0, File_End);
  if GetLastError() <> 0 then goto OnError;
  if NetFileSize > NetFileSizeMax then
    NetFileSize := NetFileSizeMax;

  FileSeek(FileHandle, 0, File_Begin);
  if GetLastError() <> 0 then goto OnError;

  Tmp := FileRead(FileHandle, Buff[0], NetFileSize);

  FileClose(FileHandle);

  if Tmp < NetFileSize then
    if Tmp < 0
      then NetFileSize := 0
      else NetFileSize := Tmp;

  Result := True;
  Exit;

  OnError: begin
    FileClose(FileHandle);
  end;
end;
{
function NetLoadFile(Buff: PChar; FileName: String): Boolean;
begin
  Result := NetLoadFileWithAbsolutePath(Buff, NetDataDir + FileName);
end;

function NetLoadParam(Buff: PChar; Param, Con: Integer): Boolean;
var
  Txt: string;
begin
  Txt := IntToStr(Param);
  if Length(Txt) < 2 then
    Txt := '0' + Txt;
  Result := NetLoadFile(Buff, Txt + '_' + IntToStr(Con));
end;

function NetLoadMsg(Buff: PChar): Boolean;
begin
  Result := NetLoadFile(Buff, 'msg');
end;

function NetLoadData(Buff: PChar): Boolean;
begin
  Result := NetLoadFile(Buff, 'data');
end;
  }

procedure NetSetArchivePort(Port: Int32); cdecl;
begin
  ArchiveNetPort := Port;
end;

procedure NetSetArchiveIp(Ip: PChar); cdecl;
begin
  ArchiveNetIp := Ip;
end;

procedure NetSetArchiveFolder(Folder: PChar); cdecl;
begin
  ArchiveFolder := Folder;
end;

end.
