unit Archive;

interface

uses Classes, SysUtils, ptypes;

type
  TArchive = class
  private
    FList: TStringList;
    FNewList: TStringList;
    FNewListStarted: Boolean;
    FNewListSearchRec: TSearchRec;

    function GetCount: Int16;
    function DateToDirName(DtTm: TDateTime): string;
    function ToStr(Value: Word): string;
    function ReadFile(DirName, FileName: string; Stream: TMemoryStream): Boolean;
    function DeleteDir(DirName: string): Boolean;

  public
    constructor Create;
    destructor Destroy;

    procedure Add(Pipe: string);
    function GetPipe(Index: Int16): string;
    procedure Clear;
    procedure Load;
    procedure Save;
    function CreateDir(DtTm: TDateTime): string;
    function IsValid(DirName: string): Boolean;
    function Find(Pipe: string): Int16;
    function GetNext(Pipe: string): string;
    function GetPrev(Pipe: string): string;
    function GetNextDay(Pipe: string): string;
    function GetPrevDay(Pipe: string): string;
    function GetFirst: string;
    function GetLast: string;
    procedure WriteParam(DirName: string; Param: Word; Controller: Word;
     Stream: TMemoryStream);
    procedure WriteData(DirName: string; Stream: TMemoryStream);
    procedure WriteMsg(DirName: string; Stream: TMemoryStream);
    function ReadParam(DirName: string; Param: Byte; Controller: Byte;
      Stream: TMemoryStream): Boolean;
    function ReadData(DirName: string; Stream: TMemoryStream): Boolean;
    function ReadMsg(DirName: string; Stream: TMemoryStream): Boolean;
    procedure Idle;

    property Count: Int16 read GetCount;
    property Pipes[Index: Int16]: string read GetPipe;
  end;



implementation

uses Global, MainUnit;

const
  ArchiveListFileName = 'archive.txt';

constructor TArchive.Create;
begin
  FList := TStringList.Create;
  FList.Duplicates := dupIgnore;
  FList.Sorted := True;
  FNewList := TStringList.Create;
  FNewList.Duplicates := dupIgnore;
  FNewList.Sorted := True;
  FNewListStarted := False;
end;

destructor TArchive.Destroy;
begin
  FList.Destroy;
  FNewList.Destroy;
end;

function TArchive.GetCount: Int16;
begin
  Result := FList.Count;
end;

procedure TArchive.Add(Pipe: string);
begin
  FList.Add(Pipe);
end;

function TArchive.GetPipe(Index: Int16): string;
begin
  Result := FList.Strings[Index];
end;

procedure TArchive.Clear;
begin
  FList.Clear;
end;

procedure TArchive.Load;
var
  DirName: string;
  TmpList: TStringList;
  I, N: Int16;
begin
  DirName := ArchivePath;
  if DirName = '' then Exit;
  if DirName[Length(DirName)] <> '\' then
    DirName := DirName + '\';

  TmpList := TStringList.Create;
  try
    TmpList.LoadFromFile(DirName + ArchiveListFileName);
  except
  end;

  N := TmpList.Count - 1;
  for I := 0 to N do begin
    DirName := TmpList.Strings[I];
    if IsValid(DirName) then Add(DirName);
  end;

  TmpList.Free;
end;

procedure TArchive.Save;
var
  DirName: string;
begin
  DirName := ArchivePath;
  if DirName = '' then Exit;
  if DirName[Length(DirName)] <> '\' then
    DirName := DirName + '\';
  try
    FList.SaveToFile(DirName + ArchiveListFileName);
  except
  end;
end;

function TArchive.IsValid(DirName: string): Boolean;
const
  Len = 12;
var
  I: Int16;
begin
  Result := False;

  if Length(DirName) <> Len then Exit;

  for I := 1 to 12 do
    if I in [1..2, 4..8, 10..12] then
      if not (DirName[I] in ['0'..'9']) then Exit;

  if not (DirName[3] in ['1'..'9', 'A'..'C']) then Exit;

  if DirName[9] <> '.' then Exit;

  I := StrToInt(Copy(DirName, 4, 2));
  if (I < 1) or (I > 31) then Exit;

  I := StrToInt(Copy(DirName, 6, 2));
  if I > 23 then Exit;

  I := StrToInt(DirName[8])*10 + StrToInt(DirName[10]);
  if I > 59 then Exit;

  I := StrToInt(Copy(DirName, 11, 2));
  if I > 59 then Exit;

  Result := True;
end;

function TArchive.Find(Pipe: string): Int16;
var
  I, N: Int16;
begin
  N := Count;
  for I := 0 to N - 1 do
    if Pipes[I] = Pipe then begin
      Result := I; Exit;
    end;
  Result := -1;
end;

function TArchive.GetNext(Pipe: string): string;
var
  I: Int16;
begin
  I := Find(Pipe);
  if I < 0 then begin
    Result := GetLast; Exit;
  end;

  if I < Count - 1 then begin
    Result := Pipes[I + 1]; Exit;
  end;

  Result := '';
end;

function TArchive.GetPrev(Pipe: string): string;
var
  I: Int16;
begin
  I := Find(Pipe);
  if I < 0 then begin
    Result := GetFirst; Exit;
  end;

  if I > 0 then begin
    Result := Pipes[I - 1]; Exit;
  end;

  Result := '';
end;

function TArchive.GetNextDay(Pipe: string): string;
var
  I, N: Int16;
  CurrDt: string;
  NextPipe: string;
begin
  I := Find(Pipe);
  if I < 0 then begin
    Result := GetLast; Exit;
  end;

  CurrDt := Copy(Pipe, 1, 5);
  N := Count - 1;

  while I < N do begin
    Inc(I);
    NextPipe := FList.Strings[I];
    if CurrDt < Copy(NextPipe, 1, 5) then begin
      Result := NextPipe; Exit;
    end;
  end;

  Result := GetLast;
end;

function TArchive.GetPrevDay(Pipe: string): string;
var
  I: Int16;
  CurrDt: string;
  PrevPipe: string;
begin
  I := Find(Pipe);
  if I < 0 then begin
    Result := GetFirst; Exit;
  end;

  CurrDt := Copy(Pipe, 1, 5);

  while I > 0 do begin
    Dec(I);
    PrevPipe := FList.Strings[I];
    if CurrDt > Copy(PrevPipe, 1, 5) then begin
      Result := PrevPipe; Exit;
    end;
  end;

  Result := GetFirst;
end;

function TArchive.GetFirst: string;
begin
  if Count > 0
    then Result := Pipes[0]
    else Result := '';
end;

function TArchive.GetLast: string;
begin
  if Count > 0
    then Result := Pipes[Count - 1]
    else Result := '';
end;

function TArchive.CreateDir(DtTm: TDateTime): string;
var
  DirName: string;
  SearchRec: TSearchRec;
  PipeDirName: string;
begin
  Result := '';

  if ArchivePath = '' then Exit;
  DirName := ArchivePath;
  if DirName[Length(DirName)] <> '\' then
    DirName := DirName + '\';
  PipeDirName := DateToDirName(DtTm);
  DirName := DirName + PipeDirName;

  if FindFirst(DirName, faDirectory, SearchRec) = 0 then
  begin
    Result := DirName;
  end
  else
  begin
    try
      Mkdir(DirName);
      Add(PipeDirName);
      Result := DirName;
    except
    end;
  end;

  FindClose(SearchRec);
end;

procedure TArchive.WriteParam(DirName: string; Param: Word;
 Controller: Word; Stream: TMemoryStream);
var
  FileName: string;
begin
  FileName := DirName + '\' + ToStr(Param) + '_' + IntToStr(Controller);
  try
    Stream.Position := 0;
    Stream.SaveToFile(FileName);
  except
  end;
end;

procedure TArchive.WriteData(DirName: string; Stream: TMemoryStream);
var
  FileName: string;
begin
  FileName := DirName + '\data';
  try
    Stream.Position := 0;
    Stream.SaveToFile(FileName);
  except
  end;
end;

procedure TArchive.WriteMsg(DirName: string; Stream: TMemoryStream);
var
  FileName: string;
begin
  FileName := DirName + '\msg';
  try
    Stream.Position := 0;
    Stream.SaveToFile(FileName);
  except
  end;
end;

function TArchive.ToStr(Value: Word): string;
begin
  if Value < 10
    then Result := '0'
    else Result := '';
  Result := Result + IntToStr(Value);
end;


function TArchive.DateToDirName(DtTm: TDateTime): string;
var
  Day, Mon, Year: Word;
  Hour, Min, Sec, MSec: Word;

begin
  DecodeDate(DtTm, Year, Mon, Day);
  DecodeTime(DtTm, Hour, Min, Sec, MSec);

  Result := ToStr(Year mod 100);
  if Mon < 10
    then Result := Result + IntToStr(Mon)
    else Result := Result + Chr(Ord('A') + Mon - 10);
  Result := Result +
    ToStr(Day) +
    ToStr(Hour) +
    IntToStr(Min div 10) + '.' + IntToStr(Min mod 10) +
    ToStr(Sec);
end;

function TArchive.ReadFile(DirName, FileName: string;
 Stream: TMemoryStream): Boolean;
var
  Path: string;
begin
  Result := False;
  Path := ArchivePath;
  if Path <> '' then
    if Path[Length(Path)] <> '\' then
      Path := Path + '\';
  Path := Path + DirName + '\' + FileName;
  Stream.Clear;
  try
    Stream.LoadFromFile(Path);
    Result := True;
  except
  end;
end;

function TArchive.ReadParam(DirName: string; Param: Byte; Controller: Byte;
 Stream: TMemoryStream): Boolean;
begin
  Result := ReadFile(DirName, ToStr(Param) + '_' + IntToStr(Controller), Stream);
end;

function TArchive.ReadData(DirName: string; Stream: TMemoryStream): Boolean;
begin
  Result := ReadFile(DirName, 'data', Stream);
end;

function TArchive.ReadMsg(DirName: string; Stream: TMemoryStream): Boolean;
begin
  Result := ReadFile(DirName, 'msg', Stream);
end;

procedure TArchive.Idle;
var
  Ret: Int16;
  Path: string;
  DirName: string;
begin
  if ArchivePath = '' then begin
    FList.Clear;
    FNewListStarted := False;
    Exit;
  end;

  Path := ArchivePath;
  if Path[Length(Path)] <> '\' then Path := Path + '\';

  if (ArchiveMaxSize < Count) and (Count > 0) then begin
    if DeleteDir(Path + FList.Strings[0]) then FList.Delete(0);
  end;

  if not FNewListStarted then begin
    Ret := FindFirst(Path + '*.*', faDirectory, FNewListSearchRec);
    if Ret <> 0 then begin
      FList.Clear;
      FindClose(FNewListSearchRec);
      Exit;
    end;

    FNewListStarted := True;
    FNewList.Clear;
    DirName := FNewListSearchRec.Name;
    if IsValid(DirName) then FNewList.Add(DirName);
    Exit;
  end;

  Ret := FindNext(FNewListSearchRec);
  if Ret = 0 then begin
    DirName := FNewListSearchRec.Name;
    if IsValid(DirName) then FNewList.Add(DirName);
    Exit;
  end;

  FindClose(FNewListSearchRec);
  FNewListStarted := False;
  FList.Assign(FNewList);
end;

function TArchive.DeleteDir(DirName: string): Boolean;
var
  SearchRec: TSearchRec;
  Ret: Int16;
begin
  Result := False;

  if DirName = '' then Exit;
  if DirName[Length(DirName)] <> '\' then
    DirName := DirName + '\';

  Ret := FindFirst(DirName + '*.*', 0, SearchRec);
  if Ret = 0 then
  begin
    while Ret = 0 do
    begin
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        DeleteFile(DirName + '\' + SearchRec.Name);
      Ret := FindNext(SearchRec);
    end;
  end;
  FindClose(SearchRec);

  try
    Rmdir(Copy(DirName, 1, Length(DirName) - 1));
  except
  end;

  Result := True;
end;

end.
