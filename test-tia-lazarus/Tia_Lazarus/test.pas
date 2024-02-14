unit Test;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  TRec = packed record
    A: Byte;
    B: Word;
    C: Byte;
  end;
  PRec = ^TRec;

procedure DoSomething; cdecl;
function GetInt16: Int16; cdecl;
function GetInt32: Int32; cdecl;
function GetInt64: Int64; cdecl;
function GetFloat32: Single; cdecl;
function GetFloat64: Double; cdecl;
procedure SetInt16(Value: Int16); cdecl;
procedure SetInt32(Value: Int32); cdecl;
procedure SetInt64(Value: Int64); cdecl;
procedure SetFloat32(Value: Single); cdecl;
procedure SetFloat64(Value: Double); cdecl;

function GetRec: TRec; cdecl;
procedure GetPRec(P: PRec); cdecl;
procedure SetRec(Rec: TRec); cdecl;
procedure SetPRec(P: PRec); cdecl;

procedure GetPStr(P: PChar); cdecl;
procedure SetPStr(P: PChar); cdecl;

implementation

procedure DoSomething; cdecl;
begin
end;

function GetInt16: Int16; cdecl;
begin
  Result := 16;
end;

function GetInt32: Int32; cdecl;
begin
  Result := 32;
end;

function GetInt64: Int64; cdecl;
begin
  Result := 64;
end;

function GetFloat32: Single; cdecl;
begin
  Result := 32.32;
end;

function GetFloat64: Double; cdecl;
begin
  Result := 64.64;
end;

procedure SetInt16(Value: Int16); cdecl;
begin
  Value := Value;
end;

procedure SetInt32(Value: Int32); cdecl;
begin
  Value := Value;
end;

procedure SetInt64(Value: Int64); cdecl;
begin
  Value := Value;
end;

procedure SetFloat32(Value: Single); cdecl;
begin
  Value := Value;
end;

procedure SetFloat64(Value: Double); cdecl;
begin
  Value := Value;
end;

function GetRec: TRec; cdecl;
begin
  with Result do begin
    A := 1;
    B := 2;
    C := 3;
  end;
end;

procedure GetPRec(P: PRec); cdecl;
begin
   with P^ do begin
      A := 11;
      B := 12;
      C := 13;
   end;
end;

procedure SetRec(Rec: TRec); cdecl;
begin
  Rec := Rec;
end;

procedure SetPRec(P: PRec); cdecl;
begin
  P := P;
end;

procedure GetPStr(P: PChar); cdecl;
const
  SrcStr: PChar = 'It''s a string';
begin
  StrCopy(P, SrcStr);
end;

procedure SetPStr(P: PChar); cdecl;
begin
  P := P;
end;


exports DoSomething,

        GetInt16,
        GetInt32,
        GetInt64,
        GetFloat32,
        GetFloat64,

        SetInt16,
        SetInt32,
        SetInt64,
        SetFloat32,
        SetFloat64,

        GetRec,
        GetPRec,
        SetRec,
        SetPRec,

        GetPStr,
        SetPStr;

end.

