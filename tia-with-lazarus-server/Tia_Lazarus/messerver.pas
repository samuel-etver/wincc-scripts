unit MesServer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  TMesPipeNumberData = packed record
    PipeNumber: PChar;
    PipeDiameter: PChar;
    PipeThickness: PChar;
    PersonnelNo: PChar;
  end;

  TMesStatus = packed record
    State: Int32;
    LoopCount: Int32;
  end;

  procedure Init;
  procedure Fin;

  procedure MesServerRun; cdecl;
  procedure MesSetFromServerPort(Port: Int32); cdecl;
  procedure MesSetToServerPort(Port: Int32); cdecl;
  function MesGetPipeNumberData(var Data: TMesPipeNumberData): Int32; cdecl;
  procedure MesGetStatus(var Status: TMesStatus); cdecl;
  function GetInt32: Int32; cdecl;

implementation

uses Global, MesThr, PipeNum, Main;

var
  MesServerThread: TMesThread;
  MesClientThread: TMesThread;

procedure MesReconnect; forward;
procedure MesDisconnect; forward;
function MesGetPipeNumberDataImpl(var Data: TMesPipeNumberData): Int32; forward;

procedure Init;
begin

end;

procedure Fin;
begin
  MesDisconnect;
end;

procedure MesServerRun; cdecl;
var
  ReconnectRequered: Boolean;
begin
  Main.Init;

  MesLoopCount := (MesLoopCount + 1) mod 10000;

  ReconnectRequered := (MesFromServerPortNew <> MesFromServerPort) or
                       (MesToServerPortNew <> MesToServerPort);

  if Assigned(MesServerThread) and MesServerThread.Finished then
    ReconnectRequered := True;
  if Assigned(MesClientThread) and MesClientThread.Finished then
    ReconnectRequered := True;

  if ReconnectRequered then
    MesReconnect;

  if GetTickCount64 - MesCommTicks > 20000 then
  begin
    MesCommST := False;
  end;
end;


procedure MesSetFromServerPort(Port: Int32); cdecl;
begin
  MesFromServerPortNew := Port;
end;


procedure MesSetToServerPort(Port: Int32); cdecl;
begin
  MesToServerPortNew := Port;
end;

procedure MesDisconnect;
begin
  if Assigned(MesServerThread) then
  begin
    MesServerThread.Terminate;
    MesServerThread.CloseSockets;
  end;
  if Assigned(MesClientThread) then
  begin
    MesClientThread.Terminate;
    MesClientThread.CloseSockets;
  end;

  if Assigned(MesServerThread) then
  begin
    MesServerThread.WaitFor;
    MesServerThread.Free;
    MesServerThread := nil;
  end;

  if Assigned(MesClientThread) then
  begin
    MesClientThread.WaitFor;
    MesClientThread.Free;
    MesClientThread := nil;
  end;
end;

procedure MesConnect;
begin
  MesFromServerPort := MesFromServerPortNew;
  MesToServerPort := MesToServerPortNew;

  MesClientThread := TMesThread.Create(MES_AT_SEND);
  MesServerThread := TMesThread.Create(MES_AT_RECV);
end;

procedure MesReconnect;
begin
  MesDisconnect;
  MesConnect;
end;

function MesGetPipeNumberData(var Data: TMesPipeNumberData): Int32; cdecl;
begin
  PipeNumListLock.Acquire;
  try
    Result := MesGetPipeNumberDataImpl(Data);
  finally
    PipeNumListLock.Release;
  end;
end;

function MesGetPipeNumberDataImpl(var Data: TMesPipeNumberData): Int32;
var
  PipeNumItem: TPipeNumItem;
begin
  if PipeNumList.Empty then
  begin
    Result := 0;
    Exit;
  end;

  PipeNumItem := PipeNumList.First;

  with Data do
  begin
    StrPCopy(PipeNumber, PipeNumItem.PipeNumber);
    StrPCopy(PipeDiameter, PipeNumItem.PipeDiameter);
    StrPCopy(PipeThickness, PipeNumItem.PipeThickness);
    StrPCopy(PersonnelNo, PipeNumItem.PersonnelNo);
  end;

  PipeNumList.DeleteFirst;

  Result := 1;
end;

procedure MesGetStatus(var Status: TMesStatus); cdecl;
begin
  with Status do
  begin
    if MesCommST
      then State := 0
      else State := 1;
    LoopCount := MesLoopCount;
  end;
end;

function GetInt32: Int32; cdecl;
begin
  Result := 173;
end;

end.

