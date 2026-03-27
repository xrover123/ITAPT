unit Unit1;

interface

uses
   Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,CSVParser, DB, ADODB, DBXpress, FMTBcd, SqlExpr;

type
  TMain = class(TForm)
    Label1: TLabel;
    ORAConnection: TSQLConnection;
    OraProc: TSQLStoredProc;
    SP: TSQLStoredProc;
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    P: TCSVParser;
    Regime: byte;
  public
    { Public declarations }
  end;

var
  Main: TMain;

implementation

{$R *.dfm}
uses IniFiles, EasyCript, NetConf, FileFunc;

const LR:char=chr(10);
function CheckFields(const FileName: String;const SS:TStringList; const P: TSQLStoredProc; var MSG: String): boolean;
  var i,t: integer;
      ProcName: String;
  function fndPRM(S: String): boolean;
    var i: integer;
    begin
    for i:=0 to P.Params.Count-1 do
      if P.Params.Items[i].Name=S then
        begin
        result:=True;
        exit
        end;
    result:=False;
    end;
  begin
  ProcName:=P.StoredProcName;
  if SS.Count<>P.Params.Count then
    begin
    MSG:=LR+'  В процедуре '+ProcName+' и в файле '+FileName+' разное количество полей.'
    end
    else
    MSG:='';
  t:=0;
  for i:=0 to SS.Count-1 do
    if fndPRM(SS.Strings[i]) then
      inc(t)
      else
      MSG:=MSG+LR+'  В файле '+FileName+' присутствует поле '+SS.Strings[i]+', но его нет в описании процедуры '+P.StoredProcName+' в ini-файле.';
  for i:=0 to P.Params.Count-1 do
    if SS.IndexOf(P.Params.Items[i].Name)<0 then
      MSG:=MSG+LR+'  В описании процедуры '+P.StoredProcName+' в ini-фафйле присутствует поле '+P.Params.Items[i].Name+', но его нет в файле '+FileName+'.';
  if t=0 then
    MSG:=LR+'В файле '+FileName+' и в процедуре '+P.StoredProcName+', описанной в ini-файле, нет ни одного совпадающего поля.';
  result:=(t<>0);
  end;

function GetPC: word; stdcall;
  external 'NetParam.dll' name 'GetPCCode';


procedure TMain.FormShow(Sender: TObject);
var INI: TINIFile;
    S,FN,PN,LOG,LOG_P,LOG_F: String;
    i,j,t: integer;
    SL,PL: TStringList;
    DLM, PSW: String;
    w: word;
    TS: TTransactionDesc;
    LF: TextFile;
    LogCnt:integer;
    PRM: TParam;
    ProcStr: String;
    bErr: boolean;
    sERR: String;
    ch:char;
    nBuff: integer;
    //SP: TSQLStoredProc;
procedure OpenLog;
  begin
  AssignFile(LF,FN);
  if FileExists(FN) then
    Append(LF)
    else
    Rewrite(LF);
  WriteLn(LF,'begin IMPORT('+DateTimeToStr(now)+')');
  LogCnt:=0;
  end;
procedure SaveLog(N: integer);
  begin
  if (length(LOG)<>0) and (LogCnt>=N) then
    begin
    WriteLN(LF,LOG);
    setLength(LOG,0);
    LogCnt:=0;
    end;
  end;
procedure SetLog(const MSG,endChar: String);
  begin
  LOG:=LOG+DateTimeToStr(now)+' '+MSG+endChar;
  inc(LogCnt);
  SaveLog(50);
  end;
procedure CloseLog;
  begin
  if (Regime>0) and (Regime<10) then
    begin
    SaveLog(0);
    WriteLn(LF,'end IMPORT('+DateTimeToStr(now)+')'+LR);

    try
    CloseFile(LF);
    finally;
    end;
    //with TTextRec(LF) do if (Handle<>0) and (Mode<>fmClosed) then CloseFile(LF);
    //SafeTextClose(LF);
    end;
  end;
procedure ShowException(MSG: String);
  begin
  if Regime>=10 then
    ShowMessage(MSG)
  else if Regime>0 then
    begin
    SetLog(MSG,'');
    CloseLog;
    end;
  end;
procedure CloseFromError(MSG: String);
  begin
  ShowException(MSG);
  INI.Free;
  Close;
  end;
procedure PrintIniExample;
  var T: TextFile;
  begin
  if not FileExists(FN) then
    begin
    AssignFile(T,extractFilePath(ParamStr(0))+'SAMPLE.INI');
    Rewrite(T);
    writeLN(T,'[FILES]#Секция описания файлов импорта');
    writeLN(T,'  FILE1=<Файл>;<Процедура импорта строки>');
    writeLN(T,'  FILE2=<Файл>;<Процедура импорта строки>');
    writeLN(T,'[DB]');
    writeLN(T,'  DB_NAME=<Псевдоним БД>');
    writeLN(T,'  USER=<Пользователь>');
    writeLN(T,'  PSW=<Закодированный пароль (записать пароль можно с помошью утилиты psw <пароль>)>');
    writeLN(T,'  PREP_PROC=<Процедура перед импортом>');
    writeLN(T,'  SAVE_PROC=<Процедура после импорта>');
    writeLN(T,'[OTHERS]');
    writeLN(T,'  REGIME=<0 - все сообщения выводятся в LOG (если он задан); 10 - сообщения выводятся.>');
    writeLN(T,'  LOG=<Лог файл>');
    CloseFile(T);
    Close
    end;
  end;
begin
if ParamCount=1 then
  if (ParamStr(1)='-V') or (ParamStr(1)='-v') then
    begin
    Label1.Caption:='Version 1.1.1.1';
    exit
    end;
Label1.Caption:='Импорт данных из CSV файлов.'; Application.ProcessMessages;
FN := ExtractFilePath(ParamStr(0))+'imp.ini';
if not FileExists(FN) then PrintIniExample;

try
INI:=TINIFile.Create(FN);
S := UpperCase(INI.ReadString('OTHERS','REGIME','0'));
if (S='0') or (S='SILENCE') or (S='SILENT') then
  begin
  FN:=trim(INI.ReadString('OTHERS','LOG',''));
  LOG_P:=ExtractFilePath(FN);
  if length(FN)>0 then
    begin
    OpenLog;
    Regime:=1;
    end
    else
    Regime:=0;
  end
else if (S='10') or (S='DEBUG') or (S='SHOW_MESSAGE') then
  Regime:=10;

try
  w := GetPC;//GetCriptCode;
  bErr:=False
  except on E: Exception do
    begin
    bErr:=True;
    sErr:=E.Message;
    end;
  end;
if bErr then
  if ParamCount>=2 then
    SetLog(sErr,LR)
    else
    begin
    CloseFromError('Процедура определения ID компьютера выдала ошибку: '+sErr);
    exit
    end;

DLM:=trim(INI.ReadString('FILE','DLM',','));
Label1.Caption:='Чтение файла инициализации.';Application.ProcessMessages;
if length(DLM)>0 then
  P:=TCSVParser.Create(DLM[1])
  else
  P:=TCSVParser.Create(',');

ORAConnection.Params.Values['DataBase']:=INI.ReadString('DB','DB_NAME',ParamStr(1));
ORAConnection.Params.Values['User_Name']:=INI.ReadString('DB','USER',ParamStr(2));
if bErr then
  ORAConnection.Params.Values['Password'] := ParamStr(3)
  else
  begin
  PSW := INI.ReadString('DB','PSW','');
  if PSW='' then
    PSW := ParamStr(3)
    else
    begin
    PSW := DecryptStr(PSW,w);
    j := length(PSW);
    t := j;
    for i := 1 to j do
      if PSW[i] = chr(10) then
        begin
        t:=i-1;
        break;
        end;
    if t<>j then SetLength(PSW,t);
    end;
  ORAConnection.Params.Values['Password'] := PSW;
  end;
Label1.Caption:='Connect '+ORAConnection.Params.Values['User_Name']+'@'+ORAConnection.Params.Values['DataBase']+'.' ;Application.ProcessMessages;
try
  ORAConnection.Connected:=True
  except on E: Exception do
    begin
    CloseFromError
      (
      LR+'DBName='+ORAConnection.Params.Values['DataBase']+
      LR+'USER='+ORAConnection.Params.Values['User_Name']+
      //LR+'Password='+ORAConnection.Params.Values['Password']+
      LR+LR+E.Message
      );
    exit
    end;
  end;
if not ORAConnection.Connected then
  begin
  CloseFromError('База данных закрыта!');
  exit
  end
  else
  begin
  Label1.Caption:='Connectted '+ORAConnection.Params.Values['User_Name']+'@'+ORAConnection.Params.Values['DataBase']+'.' ;Application.ProcessMessages;
  OraProc.StoredProcName:=trim(INI.ReadString('DB','PREP_PROC',''));
  if OraProc.StoredProcName<>'' then
    begin
    OraProc.ExecProc;
    end;

  SL := TStringList.Create;
  INI.ReadSection('FILES',SL);

  Label1.Caption:='Импорт файлов.';Application.ProcessMessages;

  for j:=0 to SL.Count-1 do
    begin
    FN:= INI.ReadString('FILES',SL.Strings[j],'');

    t:=pos(';',FN);
    SP.Prepared:=false;
    ProcStr:=copy(FN,t+1,Length(FN));
    FN := copy(FN,1,t-1);
    t:=pos('(', ProcStr);
    SP.StoredProcName := trim(copy(ProcStr,1,t-1));
    if SP.StoredProcName='' then
      begin
      CloseFromError('Не задана процедура импорта строки файла '+FN+'.');
      exit
      end;
    bErr:=True;
    for i:=t+1 to length(ProcStr) do
      begin
      ch:=ProcStr[i];
      if ch<>')'
        then ProcStr[i-t]:=ch
        else begin setLength(ProcStr,i-t-1);bErr:=False;break end;
      end;

    if bErr then
      begin
      CloseFromError('Ошибка при чтении параметров процедцры '+SP.StoredProcName+' из файла инициализации.');
      exit
      end
      else
      begin
      PL:=TStringList.Create;
      PL.CommaText:=ProcStr;
      SP.Params.Clear;
      for i:=0 to PL.Count-1 do
        with SP.Params.CreateParam(ftString,PL.Strings[i],ptInput) do
          begin
          Size:=2000;
          end;
      SP.Prepared:=True;
      PL.Destroy;
      end;

    Label1.Caption:='Импорт файла '+FN+'.';Application.ProcessMessages;

    if SP.StoredProcName='' then
      begin
      CloseFromError('Не задана процедура импорта для файла '+FN);
      exit
      end
      else
      begin
      nBuff:=INI.ReadInteger('FILE','BUF_SIZE',0);
      P.Open
        (
        FN,
        nBuff,
        True,
        ProcStr
        );

      if CheckFields(FN,P.FNames,SP,sErr) then
        begin
        if sErr<>'' then SetLog(sErr,LR);
        if P.First then
          repeat
            begin
            for i:=0 to P.FNames.Count-1 do
              begin
              //ShowMessage('Name: '+SP.Params.Items[i].Name);
              PN:=P.FNames.Strings[i];
              SP.Params.ParamByName(PN).AsString:=P.getFieldByName(PN);
              end;
            SP.ExecProc;
            end;
          until not P.Next;
        P.Close;
        end
        else
        begin
        CloseFromError(sErr);
        exit
        end
      end;
    Label1.Caption:='Импорт файла '+FN+' выполнен.';Application.ProcessMessages;
    SetLog(Label1.Caption,LR);

    if P.ErrMessages.Count>0 then
      begin
      LOG_F:=FN;
      ChangeExt(LOG_F,'ERR');
      LOG_F:=LOG_P+LOG_F;
      P.ErrMessages.SaveToFile(LOG_F);
      end;

    end;

  OraProc.Prepared:=False;
  OraProc.StoredProcName:=trim(INI.ReadString('DB','SAVE_PROC',''));
  if OraProc.StoredProcName<>'' then
    begin
    OraProc.ExecProc;
    end;  //ADOConnection.CommitTrans;
  end;
//ORAConnection.Commit(TS);
INI.Free;
if (Regime>0) and (Regime<10) then CloseLog;
Close;
except on E:Exception do
  begin
  //ORAConnection.Rollback(TS);
  if (Regime>0) and (Regime<10) then
    begin
    SetLog(E.Message,LR);
    SaveLog(0);
    CloseLog
    end
  else if Regime>=10 then ShowMessage('Ошибка: ' + E.Message);
  if INI<>nil then
    begin
    INI.Free;
    Close;
    end;
  end;
end;
end;

end.
