unit main;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Global;

procedure Init;
procedure MesFin; cdecl;

implementation

uses Net, MesServer;

var
  MainInited: Boolean;

procedure Init;
begin
  if not MainInited then
  begin
    MainInited := True;
    Global.Init;
    NetInit;
    MesServer.Init;
  end;
end;


procedure MesFin; cdecl;
begin
  if MainInited then
  begin
    MainInited := False;
    MesServer.Fin;
    NetFin;
    Global.Fin;
  end;
end;



end.

