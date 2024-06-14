unit ArchiveServer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type

  TArchiveServerStatus = packed record
    State: Int32;
    LoopCount: Int32;
  end;

procedure ArchiveServerRun; cdecl;
procedure ArchiveServerGetStatus(var Status: TArchiveServerStatus); cdecl;

implementation

var
  ArchiveServerLoopCount: Int32;

procedure ArchiveServerRun; cdecl;
begin
  ArchiveServerLoopCount := (ArchiveServerLoopCount + 1) mod 10000;
end;


procedure ArchiveServerGetStatus(var Status: TArchiveServerStatus); cdecl;
begin
  with Status do
  begin
    State := 0;
    LoopCount := ArchiveServerLoopCount;
  end;
end;

end.

