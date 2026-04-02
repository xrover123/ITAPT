unit Unit1;

interface

uses
   Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DB, ADODB, DBXpress, FMTBcd, SqlExpr;

type
  TMain = class(TForm)
    Label1: TLabel;
    ORAConnection: TSQLConnection;
    OraProc: TSQLStoredProc;
    V: TSQLQuery;
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    Regime: byte;
    bSuccess_all: boolean;
    sFiles_all: string;
  public
    { Public declarations }
  end;

var
  Main: TMain;

implementation

{$R *.dfm}
uses IniFiles, EasyCript, NetConf, FileFunc;

const LR:char=chr(10);

function GetPC: word; stdcall;
  external 'NetParam.dll' name 'GetPCCode';


procedure TMain.FormShow(Sender: TObject);
var INI: TINIFile;
    S,FN,LOG,F_PATH,EXP_STATR: String;
    i,j,t: integer;
    WAIT_INT,WAIT_TIME: cardinal;
    EXP_END: String;
    PSW: String;
    w: word;
    LF: TextFile;
    LogCnt:integer;
    bErr: boolean;
    sERR: String;
    sSQL: String;
    MemoryStream: TMemoryStream;
    FileStream: TFileStream;
    RetryCount, MaxRetries: integer;
    bSuccess, bSetPath: boolean;
    sAnswer, sSourceFile: String;
    RetryDelayMs: integer;
    //SP: TSQLStoredProc;
procedure StopFileCrt;
  var F: File;
  begin
  AssignFile(F,EXP_END);
  Rewrite(F);
  CloseFile(F);
  end;
procedure OpenLog;
  begin
  AssignFile(LF,FN);
  if FileExists(FN) then
    Append(LF)
    else
    Rewrite(LF);
  WriteLn(LF,'begin EXPORT('+DateTimeToStr(now)+')');
  LogCnt:=0;
  end;
procedure SaveLog;
  begin
  if (length(LOG)<>0) then
    begin
    WriteLN(LF,LOG);
    setLength(LOG,0);
//    LogCnt:=0;
    end;
  end;
procedure SetLog(const MSG: String);
  begin
  LOG:=LOG+DateTimeToStr(now)+' '+MSG;
//  inc(LogCnt);
  SaveLog;
  end;
procedure SetAnsw(var SS: TStringlist);
  begin
  if bSuccess_all then
    SS.Add('SUCCESS=TRUE')
    else
    SS.Add('SUCCESS=FALSE');
  if length(sFiles_all)>0 then SS.Add('FILES='+sFiles_all);
  end;
procedure CloseLog(bAnsw: boolean);
  var SS: TStringList;
  begin
  if (Regime>0) and (Regime<10) then
    begin
    SaveLog;
    WriteLn(LF,'end EXPORT('+DateTimeToStr(now)+')'+LR);
    try
    CloseFile(LF);
    finally;
    end;
    if bAnsw then
      begin
      SS := TStringList.Create;
      SetAnsw(SS);
      SS.SaveToFile(sAnswer);
      SS.Free;
      end;
    end;
  end;
procedure ShowException(MSG: String);
  begin
  if Regime>=10 then
    ShowMessage(MSG)
  else if Regime>0 then
    begin
    SetLog(MSG);
    CloseLog(False);
    end;
  end;
procedure CloseFromError(const MSG,FName,sERR: String);
  var SS: TStringList;
  begin
  ShowException(MSG);
  SS:=TStringList.Create;
  bSuccess_all:=False;
  setAnsw(SS);
  if FName <> '' then SS.Add('FILE='+FName);
  if sERR <> '' then SS.Add('ERROR='+sERR);
  if FileExists(sAnswer) then DeleteFile(sAnswer);
  SS.SaveToFile(sAnswer);
  SS.Free;
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

procedure CloseFileSleep;
  begin
  if Assigned(FileStream) then FileStream.Free;
  if RetryCount < MaxRetries then
    Sleep(RetryDelayMs)
    else
    begin
    CloseFromError('Файл "'+sSourceFile+'" не был звписан!',sSourceFile,'Файл не передан!');
    exit
    end;
  end;

begin
bSuccess_all:=True;
sFiles_all:='';
if ParamCount=1 then
  if (ParamStr(1)='-V') or (ParamStr(1)='-v') then
    begin
    Label1.Caption:='Version 2.2';
    exit
    end;
Label1.Caption:='Экспорт данных в CSV файлы.'; Application.ProcessMessages;
FN := ExtractFilePath(ParamStr(0))+'exchange.ini';
if not FileExists(FN) then PrintIniExample;

try
INI:=TINIFile.Create(FN);

RetryDelayMs := INI.ReadInteger('FILE','DELAY',10000);
MaxRetries := INI.ReadInteger('FILE','MAX_RET',36);
sAnswer := INI.ReadString('FILE','ANSWER',ExtractFilePath(ParamStr(0))+'Answer.prm');

S := UpperCase(INI.ReadString('OTHERS','REGIME','0'));
if (S='0') or (S='SILENCE') or (S='SILENT') then
  begin
  FN:=trim(INI.ReadString('OTHERS','LOG',''));
  {$B-}
  if (length(FN)=0) or (FN[length(FN)]<>'\') then
    FN:=trim(INI.ReadString('OTHERS','EXP_LOG',''))
    else
    FN:=FN+trim(INI.ReadString('OTHERS','EXP_LOG',''));
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

EXP_END:=trim(INI.ReadString('FILE','EXP_END_FILE',''));
WAIT_INT:=INI.ReadInteger('FILE','WAIT_INTERVAL',1000);
WAIT_TIME:=INI.ReadInteger('FILE','WAIT_HOUR',0)*60*60*1000+INI.ReadInteger('FILE','WAIT_MIN',0)*60*1000;
i:=0;
if WAIT_INT>0 then
  while FileExists(EXP_END) do
    begin
    sleep(WAIT_INT);
    inc(i,WAIT_INT);
    if i> WAIT_TIME then
      begin
      CloseFromError('Файл блокировки "'+EXP_END+'" не удален. Время ожидания прошло!','','Файл блокировки не удален!');
      exit;
      end;
    end;

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
    SetLog(sErr)
    else
    begin
    CloseFromError('Процедура определения ID компьютера выдала ошибку: '+sErr,'','Не получен ключ расшифровки пароля');
    exit
    end;

//DLM:=trim(INI.ReadString('FILE','DLM',','));
Label1.Caption:='Чтение файла инициализации.';Application.ProcessMessages;
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
      LR+LR+E.Message,
      '','Ошибка присоединения к ORACLE.'
      );
    exit
    end;
  end;
if not ORAConnection.Connected then
  begin
  CloseFromError('База данных закрыта!','','База данных закрыта!');
  exit
  end
  else
  begin
  F_PATH:=trim(INI.ReadString('FILE','EXP_FILE_PATH',''));
  Label1.Caption:='Connectted '+ORAConnection.Params.Values['User_Name']+'@'+ORAConnection.Params.Values['DataBase']+'.' ;Application.ProcessMessages;
  OraProc.StoredProcName:=trim(INI.ReadString('DB','EXP_PREP_PROC',''));
  if OraProc.StoredProcName<>'' then
    begin
    OraProc.ExecProc;
    end;
  Label1.Caption:='Импорт файлов.';Application.ProcessMessages;

  sSQL := trim(INI.ReadString('DB','EXP_LOAD_VIEW',''));
  if sSQL='' then
    begin
    CloseFromError('Не задано представления для експорта файла.','','Не задано представление экспорта файлов!');
    exit
    end;
  V.SQL.Text:='select FileBuff,FileName from '+sSQL;
  V.Active:=True;
  MemoryStream := TMemoryStream.Create;
  bSetPath:=True;
  while not V.Eof do
    begin
    if bSetPath then
      begin
      SetLog('Директория экспорта: '+F_PATH);
      bSetPath:=False;
      end;
    MemoryStream.Clear;
    //(V.FieldByName('FileBuff') as TBlobField).SaveToFile(F_PATH+V.FieldByName('FileName').AsString);
    (V.FieldByName('FileBuff') as TBlobField).SaveToStream(MemoryStream);
    MemoryStream.Position := 0;
    RetryCount := 0;
    bSuccess := False;
    repeat
      try
        sSourceFile:=F_PATH+V.FieldByName('FileName').AsString;
        FileStream := TFileStream.Create(sSourceFile, fmCreate or fmShareExclusive);
        try
          // Копируем данные из MemoryStream в файл
          FileStream.CopyFrom(MemoryStream, MemoryStream.Size);
          bSuccess:=True;
          finally
          FileStream.Free;
          Inc(RetryCount);
          if not bSuccess then Sleep(RetryDelayMs);
          end;
        except on E: Exception{EFOpenError} do
          CloseFileSleep;
        end;
      until bSuccess or (RetryCount < MaxRetries);
    bSuccess_all:=bSuccess_all and bSuccess;
    if length(sFiles_all)=0 then
      sFiles_all:=V.FieldByName('FileName').AsString
      else
      sFiles_all:=sFiles_all+';'+V.FieldByName('FileName').AsString;

    Label1.Caption:='Импорт файла '+sSourceFile+' выполнен.';Application.ProcessMessages;
    SetLog(Label1.Caption);

    V.Next;
    end;
  V.Active:=False;

  OraProc.Prepared:=False;
  OraProc.StoredProcName:=trim(INI.ReadString('DB','EXP_CLEAR_PROC',''));
  if OraProc.StoredProcName<>'' then
    begin
    OraProc.ExecProc;
    end;  //ADOConnection.CommitTrans;
  StopFileCrt;
  end;
//ORAConnection.Commit(TS);
INI.Free;
if (Regime>0) and (Regime<10) then CloseLog(True);
Close;
except on E:Exception do
  begin
  //ORAConnection.Rollback(TS);
  if (Regime>0) and (Regime<10) then
    begin
    CloseFromError(E.Message,'','Глобальная ошибка см. лог-файл.');
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
