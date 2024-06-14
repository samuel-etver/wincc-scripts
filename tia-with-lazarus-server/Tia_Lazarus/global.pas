unit Global;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, PipeNum, syncobjs;

const
  Stan = 800;
  MesStanNameLen = 4;
  MesFromServerPortDef = 2001;
  MesToServerPortDef = 2000;

var
  LogEnabled: Boolean = True;
  MesStanName: String = '?';
  MesEnabled:            Boolean = True;
  MesFromServerPortNew:  Int16 = MesFromServerPortDef;
  MesToServerPortNew:    Int16 = MesToServerPortDef;
  MesFromServerPort:     Int16 = MesFromServerPortDef;
  MesToServerPort:       Int16 = MesToServerPortDef;
  PipeNumList:           TPipeNumList;
  PipeNumListLock:       TCriticalSection;
  MesPipeThicknessR:     Int16;
  MesPipeThickMessageEn: Boolean;
  MesCommTicks: Int64;
  MesCommST: Boolean;
  MesLoopCount: Integer;

  ArchiveNetPort: Integer;
  ArchiveNetIp: String;
  ArchiveFolder: String;

  procedure Init;
  procedure Fin;

  procedure LogWrite(Buff: PChar);
  procedure LogWrite(Txt: String);
  procedure LogNL;



implementation

const
  LogFileName = 'c:\Temp\WeldingLog.txt';

var
  LogStream: TFileStream;

procedure LogCreate; forward;
procedure LogFree; forward;


procedure Init;
var
  I: Integer;
begin
  for I := Length(MesStanName) to MesStanNameLen do
    MesStanName := MesStanName + ' ';

  MesCommST := False;

  PipeNumList := TPipeNumList.Create;
  PipeNumListLock := TCriticalSection.Create;

  LogCreate;
end;


procedure Fin;
begin
  PipeNumListLock.Free;
  PipeNumList.Free;
  LogFree;
end;

procedure LogCreate;
begin
  if LogEnabled then
    LogStream := TFileStream.Create(LogFileName, fmOpenWrite or fmCreate or fmShareDenyNone);
end;

procedure LogFree;
begin
  if LogEnabled then LogStream.Free;
end;

procedure LogWrite(Buff: PChar);
begin
  if LogEnabled then
    LogStream.Write(Buff[0], StrLen(Buff));
end;

procedure LogWrite(Txt: String);
begin
  if LogEnabled then
    LogStream.Write(PChar(Txt)[0], Length(Txt));
end;

procedure LogNL;
begin
  if LogEnabled then
    LogWrite(Chr($0D) + Chr($0A));
end;

end.

