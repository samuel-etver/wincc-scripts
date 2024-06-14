unit PipeNum;

interface

uses Classes;

type

TPipeNumItem = class
private
  FPipeNumber:    string;
  FLogin:         string;
  FPersonnelNo:   string;
  FPipeThickness: string;
  FPipeDiameter:  string;
public
  constructor Create;
  function Clone: TPipeNumItem;
  property PipeNumber: string read FPipeNumber write FPipeNumber;
  property Login: string read FLogin write FLogin;
  property PersonnelNo: string read FPersonnelNo write FPersonnelNo;
  property PipeThickness: string read FPipeThickness write FPipeThickness;
  property PipeDiameter: string read FPipeDiameter write FPipeDiameter;
end;

TPipeNumList = class
private
  FList: TList;
  function GetCount: Integer;
  function GetItem(Index: Integer): TPipeNumItem;
  function GetFirst: TPipeNumItem;
  function IsEmpty: Boolean;
public
  constructor Create;
  destructor Destroy; override;
  procedure Add(NewItem: TPipeNumItem);
  procedure Delete(Index: Integer);
  procedure Remove(Index: Integer);
  procedure DeleteFirst;
  procedure RemoveFirst;
  procedure Clear;
  property Count: Integer read GetCount;
  property Items[Index: Integer]: TPipeNumItem read GetItem;
  property First: TPipeNumItem read GetFirst;
  property Empty: Boolean read IsEmpty;
end;

implementation

// TPipeNumItem
constructor TPipeNumItem.Create;
begin
  FPipeNumber    := '';
  FLogin         := '';
  FPersonnelNo   := '';
  FPipeThickness := '';
  FPipeDiameter  := '';
end;

function TPipeNumItem.Clone: TPipeNumItem;
begin
  Result := TPipeNumItem.Create;
  Result.FPipeNumber    := FPipeNumber;
  Result.FLogin         := FLogin;
  Result.FPersonnelNo   := FPersonnelNo;
  Result.FPipeThickness := FPipeThickness;
  Result.FPipeDiameter  := FPipeDiameter;
end;

// TPipeNumList
constructor TPipeNumList.Create;
begin
  FList := TList.Create;
end;

destructor TPipeNumList.Destroy;
begin
  Clear;
  FList.Free;
  inherited;
end;

function TPipeNumList.GetCount: Integer;
begin
  Result := Flist.Count;
end;

function TPipeNumList.GetItem(Index: Integer): TPipeNumItem;
begin
  Result := TPipeNumItem(FList.Items[Index]);
end;

function TPipeNumList.GetFirst: TPipeNumItem;
begin
  Result := Items[0];
end;

function TPipeNumList.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

procedure TPipeNumList.Add(NewItem: TPipeNumItem);
begin
  FList.Add(NewItem);
end;

procedure TPipeNumList.Delete(Index: Integer);
var
  Item: TPipeNumItem;
begin
  Item := Items[Index];
  FList.Delete(Index);
  Item.Free;
end;

procedure TPipeNumList.DeleteFirst;
begin
  if not Empty then Delete(0);
end;

procedure TPipeNumList.Clear;
var
  I: Integer;
begin
  for I := Count - 1 downto 0 do
    Items[I].Free;
  FList.Clear;
end;

procedure TPipeNumList.Remove(Index: Integer);
begin
  FList.Delete(Index);
end;

procedure TPipeNumList.RemoveFirst;
begin
  if not Empty then Remove(0);
end;

end.
