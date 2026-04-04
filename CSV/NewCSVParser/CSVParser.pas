Unit CSVParser;

interface
uses Classes;

type
{
  TLnkTStrArray = ^TStrField;
  TStrField = record
    P: TLnkTStrArray;
    S: String;
    end;
}
  TStrArray = array of String;

  TLnkRow = ^TRow;
  TRow = record
    P: TLnkRow;
    Fields: TStrArray;
    end;


  TRowList = Class
    protected
    FirstRow: TLnkRow;
    LastRow:  TLnkRow;
    CurrentRow: TLnkRow;
    BuffCNT: integer;
    FieldCNT: integer;
    public
    ErrMessages: TStringList;
    FNames: TStringList;
    constructor Create;
    procedure Clear;  //Очистка строк
    procedure AddRow; //Добавление строки
    procedure setFieldByInd(ind: integer; Value: String);  //Присвоение значения поля по имени
    procedure setFieldByName(const Name, Value: String);  //Присвоение значения поля по имени
    function FieldInd(const Name: String): integer; //Индекс поля по имени
    function getFieldByInd(ind: integer): String; //Значение по индексу поля
    function getFieldByName(const Name: String): String; //Значение по названию поля

    procedure AddField(const Name: string);
    procedure ClearFields;//Полная очистка (удаляется список полей)
    end;

  TCSVParser = Class(TRowList)
    private
    F: TextFile;
    nBuffSize: integer;
    nBuffFillness: integer;
    nRowNumber: integer;
    bColNames: boolean;
    bEof: boolean;
    cDLM: char;
    bEscaping: boolean;
    public
    ErrMessage: String;
    constructor Create(DLM: char; Escaping: boolean);
    function Open(const FName: string; BuffSize: integer; ColNames: boolean; FieldsList: String):boolean;
    procedure Close;
    function First: boolean;
    function Next: boolean;
//    function ReadRow: boolean;
    end;
//function ParseStr(var S, sVal: String; cDLM: char; var ERR: TStringList): boolean;
function ParseStr(var S, sVal: String; cDLM: char; bEscaping: boolean; var ERR: TStringList): boolean;

implementation
uses {Dialogs, }SysUtils, FileFunc;

type TPCh =  array of Char;

procedure SafeTextClose( var f: TextFile );
begin
   if isTextOpen(f) then Close( f )
end;

function ParseStr(var S, sVal: String; cDLM: char; bEscaping: boolean; var ERR: TStringList): boolean;
  var i,j,t,n,L: integer;
      bQuot: boolean;
      sTMP: String;
  begin

  if length(S)=0 then
    begin
    result:=false;
    exit;
    end;

  if not bEscaping then
    begin
    i:=pos(cDLM,S);
    if i=0 then
      begin
      result:=true;
      sVal:=S;
      S:='';
      end
    else
      begin
      sTMP:=copy(S,i+1,length(S));
      setLength(S,i-1);
      sVal:=S;
      S:=sTMP;
      end;
    exit;
    end;
  n:=0;

  S:=trim(S);
  bQuot:=False;
  j:=1;
  L:=Length(S);
  for i := 1 to L do
    case S[i] of
      '"': begin
           t := i + 1;
           {$B-}
           while (t<=L) and (S[t]='"') do inc(t);//Считаем количество следующих кавычек
           //всего кавычек вместе с первой: t-i
           if (t-i mod 2) = 0  then //Если четное кол-во берем всю строку
             j:=i
             else
             begin //Если нечетное кол-во берем первую кавычку пропускаем
             j:=i+1;
             bQuot:=True;
             end;
           break;
           end;
      ' ': continue;
      chr(9): continue
      else begin
           j:=i;  // Пропускать лидирующие пробелы
           //j:=1 // Если не пропускать лидирующие пробелы
           break;
           end;
      end;

  i:=j;
  t:=0;
  SetLength(sVal,length(S));
  while i<=L do
    begin
    {$B-}
    if S[i] = '"' then
      begin
      if (i<=L) and (S[i+1]='"') then
        inc(i) //Если это сдвоеная кавычка пропускаем 1 символ
        else   //Если одинарная кавычка это конец строки (если было нвчало)
        if bQuot then
          begin
          SetLength(sVal, t);
          if i + 1 > L then
            begin //Lfkmit идти некуда возвращаемся в вызывающую процедуру
            S:='';//setLength(S,0);
            result:=True;
            exit
            end;
          for t := i + 1 to L do  //Надо дойти до следующего разделителя!
            if S[t] = cDLM then
              begin
              if t<L then
                S := copy(S, t+1, L-t)
                else
                S:='';//setLength(S,0);
              result:=True;
              exit;
              end;
          break;
          end
          else
          begin //Если начала строки не было - это ошибка!
          ERR.Add('Лишние кавычки в строке '''+S+'''.');//ShowMessage('Лишние кавычки в строке '''+S+'''.');
          result:=False;
          exit;
          end;
      end
      else
      if  (not bQuot) and (S[i]=cDLM) then
        begin
        S:=copy(S,i+1,L-i);
        SetLength(sVal,t);
        result:=True;
        exit;
        end;
    inc(t);
    sVal[t]:=S[i];
    inc(i);
    end;

  S:='';//setLength(S,0);
  SetLength(sVal,t);
  result:=True;
  end;


constructor TCSVParser.Create(DLM: char; Escaping: boolean);
  begin
  inherited Create;
  cDLM:=DLM;
  bEscaping:=Escaping;
  end;

function TCSVParser.First: boolean;
  begin
  CurrentRow:=FirstRow;
  nRowNumber:=0;
  result := (CurrentRow<>nil);
  end;

function TCSVParser.Next: boolean;
  var SS, S, sVal: String;
      i,j: integer;
//      FLD: TLnkTStrArray;
  begin

  if CurrentRow=nil then
    begin
    result:=false;
    nRowNumber:=-1;
    exit;
    end;

  if (CurrentRow^.P = nil) or (nRowNumber>=nBuffFillness) then
    begin
    if bEof then
      begin
      result:=false;
      CurrentRow:=nil;
      nRowNumber:=-1;
      end
      else
      begin
//      ClearValues;
      i:=0;
      nRowNumber:=-1;
      nBuffFillness:=0;
      while (not eof(F)) and (nBuffFillness < nBuffSize) do
        begin
        ReadLn(F, S);
        j:=0;
        if ParseStr(S,sVal,cDLM,bEscaping,ErrMessages) then
          begin
          nRowNumber:=0;
          CurrentRow:=FirstRow;
          setFieldByInd(nRowNumber, sVal);
          while ParseStr(SS,sVal,cDLM,bEscaping,ErrMessages) do
            begin
            setFieldByInd(j, sVal);
            inc(j);
            end;
          inc(nBuffFillness);
          if FieldCNT=-1 then setLength(CurrentRow^.Fields,j);
          end;
        end;
      bEof :=  eof(F);
      if not bEof then CloseFile(F);
      First;
      end;
    end
    else
    begin
    if (nRowNumber<nBuffFillness) and (nRowNumber>=0) then
      begin
      CurrentRow:=CurrentRow^.P;
      inc(nRowNumber);
      result:=true;
      end
      else
      begin
      result:=False;
      nRowNumber:=-1
      end;
    end;
  end;

procedure TCSVParser.Close;
  begin
  if not bEof then SafeTextClose(F);
  ClearFields;
  end;


function TCSVParser.Open(const FName: string; BuffSize: integer; ColNames: boolean; FieldsList: String):boolean;
  var S, sVal: String;
      i: integer;
      ErrLog: String;
  begin
  ErrLog:=ExtractFilePath(FName)+ExtractFileName(FName)+'.ERR';
  ErrMessage:='';
  ErrMessages.Clear;
  nBuffSize := BuffSize;
  nBuffFillness := 0;
  bColNames:=ColNames;
  nRowNumber:=-1;
  if FileExists(FName) then
    begin
    AssignFile(F,FName);
    Reset(F);
    bEof:=eof(F);
    if bColNames then //Определение имен столбцов если bColNames=True.
      begin
      if bEof then
        begin
        result:=False;
        SafeTextClose(F);
        ErrMessage:='Файл пуст.';//ShowMessage('Файл пуст.');
        FieldCNT:=0; //Если файл пустой, то и определения солбцов нет.
        end
        else
        begin
        ReadLn(F, S);//Считываем строку с названиями слобцов.
        if ParseStr(S,sVal,cDLM,bEscaping,ErrMessages) then//Разбираем ее
          begin
          FNames.Add(sVal); //Если разбор прошел, добавляем первый столбец
          while ParseStr(S,sVal,cDLM,bEscaping,ErrMessages) do//и обрабатываем дальше строку
            FNames.Add(sVal);
          FieldCNT:=FNames.Count;
          end;
        end;
      end
      else
      if Length(FieldsList)=0 then
        FieldCNT:=-1//Если не задано bColNames=True, то указываем FieldCNT:=-1 если список полей не задан.
        else
        begin
        FNames.Clear;
        FNames.CommaText:=FieldsList;
        FieldCNT:=FNames.Count;
        end;//Если не задано bColNames=True, то указываем FieldCNT:=-1.
    {
    Если файл не пустой продолжаем обработку по строкам и nBuffSize задоно
    как 0, запихиваем сразу все строки в буфер.
    }
    if (not bEof) and ((nBuffFillness<nBuffSize) or (nBuffSize=0)) then
      begin
      while not eof(F) do
        begin
        ReadLn(F, S);
        i:=0;//Счетчик количества столбцов
        {
        Если есть хотя бы один столбец добавляем строку и приступаем к
        дальнейшей обработке столбцов
        }
        if ParseStr(S,sVal,cDLM,bEscaping,ErrMessages) and (FieldCNT<>0) then
          begin
          AddRow;
          setFieldByInd(i,sVal);
          inc(i);
          while ParseStr(S,sVal,cDLM,bEscaping,ErrMessages) do
            begin
            setFieldByInd(i,sVal);
            inc(i);
            {
            Если названия столбцов заданы (соответственно задано и их количество)
            и счетчик полей выходит за пределы описания полей, выходим из цикла
            }
            if (i>FieldCNT) and (FieldCNT<>-1) then break;
            end;
          {//Если поля не заданы, обрезаем массив со значениями полей до реального.}
          if FieldCNT=-1 then
            setLength(CurrentRow^.Fields,i);
          inc(nBuffFillness);
          end;
        end;
      bEof:=eof(F);
      if bEof then SafeTextClose(F);
      nBuffSize:=nBuffFillness;
      nRowNumber:=0;
      end;
    end
    else
    begin
    ErrMessage:='Файл "'+FName+'" не найден.';//ShowMessage('Файл "'+FName+'" не найден.');
    result:=false;
    end;
  end;

procedure TRowList.AddField(const Name: string);
begin
FNames.Add(Name);
end;


constructor TRowList.Create;
  begin
  ErrMessages:=TStringList.Create;
  FNames:=TStringList.Create;
  FirstRow:=nil;
  CurrentRow:=nil;
  end;

function TRowList.FieldInd(const Name: String): integer;
  begin
  result := FNames.IndexOf(Name);
  end;

function TRowList.getFieldByInd(ind: integer): String;
  var F: TStrArray;
      i: integer;
  begin
  if CurrentRow <> nil then
    begin
    F := CurrentRow^.Fields;
    result:=F[ind];
    end
    else
    result:='';
  end;

function TRowList.getFieldByName(const Name: String): String;
  var i: integer;
  begin
  i := FieldInd(Name);
  if i>=0 then
    result := getFieldByInd(i)
    else
    begin
//    ShowMessage('Поле "'+Name+' не найдено.');
    result := '';
    end;
  end;

procedure TRowList.Clear;
  var //R: TLnkRow;
      i: integer;
  begin
  //R := FirstRow;
  while FirstRow <> nil do
    begin
    for i:=0 to Length(FirstRow.Fields)-1 do SetLength(FirstRow.Fields[i],0);
    SetLength(FirstRow.Fields,0);
    CurrentRow:=FirstRow^.P;
    Dispose(FirstRow);
    FirstRow:=CurrentRow;
    end;
  LastRow  := nil;
  end;
procedure TRowList.AddRow;
  var RX: TRow;
  begin
  if FirstRow <> nil then
    begin
    new(LastRow^.P);
    LastRow:=LastRow^.P;
    CurrentRow := LastRow;
    if FieldCNT<>-1 then
      setLength(LastRow.Fields,FieldCNT)
      else
      setLength(LastRow.Fields,100);
    end
    else
    begin
    new(FirstRow);
    LastRow := FirstRow;
    CurrentRow := FirstRow;
    end;
  LastRow^.Fields := nil;
  LastRow^.P := nil;
  end;
procedure TRowList.ClearFields;
  begin
  Clear;
  FNames.Clear;
  end;
procedure TRowList.setFieldByInd(ind: integer; Value: String);
  var i,j: integer;
  begin
  if ((ind>=FieldCNT) and (FieldCNT<>-1)) or (CurrentRow=nil) then exit;
  j:=length(CurrentRow^.Fields);
  if j<=ind then
    begin
    setLength(CurrentRow^.Fields,ind+1);
    for i:=j to ind-1 do CurrentRow^.Fields[i]:='';
    end;
  CurrentRow^.Fields[ind]:= Value;
  end;
procedure TRowList.SetFieldByName(const Name, Value: String);
  var i,j: integer;
  begin
  if (FieldCNT=-1) or (CurrentRow=nil) then exit;
  i := FieldInd(Name);
  if i>=0 then
    begin
    if i<FieldCNT then
      CurrentRow^.Fields[i]:= Value;
    end
    else
    ErrMessages.Add('Поле "'+Name+' не найдено.');//ShowMessage('Поле "'+Name+' не найдено.');
  end;
end.
