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
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
    P: TCSVParser;
    Regime: byte;
    sAnswer: String;
    AnswPrm:TStringList;
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
    sDBN,sDBU,sFiles: String;
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
    //LOG:='';
    SetLength(LOG,0);
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
  AnswPrm.Clear;
  AnswPrm.Add('SUCCESS=FALSE');
  AnswPrm.Add('ERR='+StringReplace(MSG,chr(10),' ',[rfReplaceAll]));
  AnswPrm.SaveToFile(sAnswer);
  INI.Free;
  SL.Free;
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
SL:=nil;
sFiles:='';
AnswPrm:=TStringList.Create;
if ParamCount=1 then
  if (ParamStr(1)='-V') or (ParamStr(1)='-v') then
    begin
    Label1.Caption:='Version 2.3';
    exit
    end;
Label1.Caption:='Импорт данных из CSV файлов.'; Application.ProcessMessages;
FN := ExtractFilePath(ParamStr(0))+'exchange.ini';
if not FileExists(FN) then PrintIniExample;

try
INI:=TINIFile.Create(FN);

S := UpperCase(trim(INI.ReadString('OTHERS','REGIME','0')));
if (S='0') or (S='SILENCE') or (S='SILENT') then
  begin

  FN:=trim(INI.ReadString('OTHERS','LOG',''));
  {$B-}
  if (length(FN)=0) or (FN[length(FN)]<>'\') then
    FN:=trim(INI.ReadString('OTHERS','IMP_LOG',''))
    else
    FN:=FN+trim(INI.ReadString('OTHERS','IMP_LOG',''));

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

sAnswer := trim(INI.ReadString('FILE','ANSWER',ExtractFilePath(ParamStr(0))+'Answer.prm'));
if not delFile(sAnswer) then
  begin
  CloseFromError('Не удален файл ответа "'+sAnswer+'".');
  exit;
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
    SetLog(sErr,LR)
    else
    begin
    CloseFromError('Процедура определения ID компьютера выдала ошибку: '+sErr);
    exit
    end;

DLM:=trim(INI.ReadString('FILE','IMP_DLM',','));
Label1.Caption:='Чтение файла инициализации.';Application.ProcessMessages;
if length(DLM)>0 then
  P:=TCSVParser.Create(DLM[1])
  else
  P:=TCSVParser.Create(',');
sDBN:=trim(INI.ReadString('DB','DB_NAME',''));
sDBU:=trim(INI.ReadString('DB','USER',''));
ORAConnection.Params.Values['DataBase']:=sDBN;
ORAConnection.Params.Values['User_Name']:=sDBU;
if bErr then
  ORAConnection.Params.Values['Password'] := ParamStr(3)
  else
  begin
  PSW := trim(INI.ReadString('DB','PSW',''));
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

  //Настройка перемещения файла во временную дирректорию для разбора.
  FileMoveAttempts:=INI.ReadInteger('FILE','IMP_FILE_MOVE_ATT',FileMoveAttempts);
  FileMoveSleep:=INI.ReadInteger('FILE','IMP_FILE_MOVE_SLEEP',FileMoveSleep);
  FileMoveTime:=INI.ReadInteger('FILE','IMP_FILE_MOVE_TIME',FileMoveTime);
  FileMoveTmpDir:=trim(INI.ReadString('FILE','IMP_FILE_MOVE_TMP',ExtractFilePath(ParamStr(0))));

  Label1.Caption:='Connectted '+ORAConnection.Params.Values['User_Name']+'@'+ORAConnection.Params.Values['DataBase']+'.' ;Application.ProcessMessages;
  OraProc.StoredProcName:=trim(INI.ReadString('DB','PREP_PROC',''));
  if OraProc.StoredProcName<>'' then
    begin
    OraProc.ExecProc;
    end;

  SL := TStringList.Create;
  INI.ReadSection('FILES',SL);

  Label1.Caption:='Импорт файлов.';Application.ProcessMessages;

  for j:=0 to SL.Count-1 do//Цикл по файлам, указанным в INI
    begin
    //В строке содердится имя файла и название процедуры с параметрами, которая
    FN:= trim(INI.ReadString('FILES',SL.Strings[j],''));//,будет обрабатывать строки
    //Выделение названия файла и процедуры
    t:=pos(';',FN);
    SP.Prepared:=false;
    //Выделили подстроку с названием процедуры
    ProcStr:=copy(FN,t+1,Length(FN));
    //Выделили подстроку с названием файла
    FN := copy(FN,1,t-1);
    //Выделяем параметры процедуры
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
        begin
        PL.Strings[i]:=trim(PL.Strings[i]);
        with SP.Params.CreateParam(ftString,PL.Strings[i],ptInput) do
          begin
          Size:=2000;
          end;
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
      TmpFN:=trim(INI.ReadString('FILE','IMP_FILE_PATH',''))+'~'+ExtractFileNameWOExt(FN)+'.tmp';
      {
      Перемещаем файл во временный файл для дальнейшего разбора.
      Если файл не хочет перемещаться, ждем некоторое время и выходим.
      Логика различных ожиданий описана в самой процедуре MVFile.
      }
      if not MVFile(FN,TmpFN) then
        begin
        CloseFromError(FileMoveErr);
        exit;
        end;
      P.Open
        (
        TmpFN,
        nBuff,
        True,
        ProcStr
        );
      if CheckFields(FN,P.FNames,SP,sErr) then //Проверка соответствия полей.
        begin
        if sErr<>'' then SetLog(sErr,LR); //В любом случае записываем сообщение.
        if P.First then
          //-----------------------------------
          //Цикл по записям в файле    (начало)
          //-----------------------------------
          repeat
            begin
            for i:=0 to P.FNames.Count-1 do //Цикл по полям таблицы
              begin
              PN:=P.FNames.Strings[i];//Название поля из открытого файла
              //Назначение параметров оракловой процедуре
              SP.Params.ParamByName(PN).AsString:=P.getFieldByName(PN);
              end;
            SP.ExecProc;//Выполнение процедуры вставки
            end;
          DelFile(TmpFN);{Удаляем временный файл ошибки не анализируем,
                          он же временный...}
          //-----------------------------------
          //Цикл по записям в файле (окончание)
          //-----------------------------------
          until not P.Next;
        P.Close;
        end
        else       //Если проверка полей прошла неудачно
        begin
        CloseFromError(sErr);//Пишем в лог и закрываемся
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
      CloseFromError('Ошибки при распознавании файла "'+FN+'".');
      end;
    sFiles:=sFiles+FN+',';
    end;

  OraProc.Prepared:=False;
  OraProc.StoredProcName:=trim(INI.ReadString('DB','SAVE_PROC',''));
  if OraProc.StoredProcName<>'' then
    begin
    OraProc.ExecProc;
    end;  //ADOConnection.CommitTrans;
  AnswPrm.Clear;
  AnswPrm.Add('SUCSESS=TRUE');
  if length(sFiles)>0 then AnswPrm.Add('FILES='+copy(sFiles,1,length(sFiles)-1));
  AnswPrm.SaveToFile(sAnswer);
  SL.Free;
  SL:=nil;
  end;
//ORAConnection.Commit(TS);
INI.Free;
if AnswPrm.Count=0 then
  begin
  AnswPrm.Add('SUCCESS=FALSE');
  AnswPrm.SaveToFile(sAnswer);
  end;
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

procedure TMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
AnswPrm.Free;
end;

end.
