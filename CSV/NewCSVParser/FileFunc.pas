unit FileFunc;

interface
var FileMoveAttempts: integer; //Задает количество попвток операции перемещения
    FileMoveSleep:  cardinal;  //Задает время ожидания следующей попытки перемещения
    FileMoveTime:  int64;      //Задает время которое программы бутет ожидать разблокировки файла
    FileMoveErr:  String;      //Возвращает ошибку перемещения файла

    FileMoveTmpDir: String;    //Дирректория для временных файлов
    TmpFN: String;             //Временный файл


function isTextOpen( var f: TextFile ) : boolean;
function isFileOpen( var f: File ) : boolean;
procedure ChangeExt(var FileName: String; const NewExt: String);
function MVFile(const F1,F2: String): boolean;
function ExtractFileNameWOExt(S: String): String;
function DelFile(FileName: String): boolean;

implementation

uses Windows,DateUtils,SysUtils;

function isTextOpen( var f: TextFile ) : boolean;
begin
   with TTextRec(f) do
     Result := (Handle<>0) and (Mode<>fmClosed)
end;

function isFileOpen( var f: File ) : boolean;
begin
   with TFileRec(f) do
     Result := (Handle<>0) and (Mode<>fmClosed)
end;

function MoveAFile(const SourceFile, DestFile: string): integer;
var
  ErrorCode: cardinal;
begin
  if MoveFile(PChar(SourceFile), PChar(DestFile)) then
    result:=0
  else
    result := GetLastError;
{
32:  ERROR_SHARING_VIOLATION
 2:  ERROR_FILE_NOT_FOUND
 3:  ERROR_PATH_NOT_FOUND
 5:  ERROR_ACCESS_DENIED
}
end;

function DelFile(FileName: String): boolean;
var i: cardinal;
begin
if FileExists(FileName) then
  if not DeleteFile(PChar(FileName)) then
    begin
    i:=GetLastError;
    case i of
      ERROR_FILE_NOT_FOUND: FileMoveErr:='Файл "'+FileName+'" не найден.';
      ERROR_PATH_NOT_FOUND: FileMoveErr:='Путь "'+ExtractFilePath(FileName)+'" не найден.';
      ERROR_ACCESS_DENIED:  FileMoveErr:='Не хватает прав для удаления "'+ExtractFilePath(FileName)+'".';
      else                  FileMoveErr:='Ошибка (код: '+IntToStr(i)+') при удалении файла "'+ExtractFilePath(FileName)+'".';
      end;
    end
  else
    begin
    FileMoveErr:='';
    result:=true;
    end;
end;

function MVFile(const F1,F2: String): boolean;
{
Процедура перемещения файла. Ожидает пока файл появится,
потом пытается его переместить, если это не получается,
ждет какое-то время разблокировки файла.
Если файл разбокирован перемещает его.
  Используемые глобальные переменные:
    FileMoveAttempts: integer; //Задает количество попвток операции перемещения
    FileMoveSleep:  cardinal;  //Задает время ожидания следующей попытки перемещения
    FileMoveTime:  int64;      //Задает время которое программы бутет ожидать разблокировки файла
    FileMoveErr:  String;      //Возвращает ошибку перемещения файла
}
var i: int64;
    n: integer;
    t: TDateTime;
    r: integer;
begin
if not delFile(F2) then//Удаление старого временного файла, если он существует.
 begin
 result:=False;//Ошибка удаления временного файла приводит к невозможности
 exit;         //перемещения файла, поэтому выходим из процедуры перемещения.
 end;
t:=now();
n:=0;
repeat
  r:=MoveAFile(F1,F2);
  case r of
    0: result:=true;
    2: begin
       i:=SecondsBetween(t,now());
       result:=false;
       if i>FileMoveTime then
         begin
         FileMoveErr:='Файл "F1" не разблокирован в течении '+IntToStr(i)+' секунд.';
         exit;
         end;
       sleep(3000);
       end;
    3,5:
       begin //Файл не найден или запрешен доступ, ожидаем
       result:=false;
       if n>FileMoveAttempts then
         begin
         i:=SecondsBetween(t,now());
         FileMoveErr:='Файл "F1" не найден. Попыток доступа:'+IntToStr(n+1)+' в течении '+IntToStr(i)+' секунд.';
         exit;
         end;
       sleep(FileMoveSleep);
       inc(n);
       end;
    else
      begin
      result:=false;
      i:=SecondsBetween(t,now());
      FileMoveErr:='При перемещении файла "F1" во временную дирректорию произошла ошибка. Попыток доступа:'+IntToStr(n+1)+' в течении '+IntToStr(i)+' секунд.';
      exit;
      end;
    end;
  until result;
end;
function ExtractFileNameWOExt(S: String): String;
  var
    T: String;
    i: integer;
  begin
  result:=ExtractFileName(S);
  for i:=length(result) downto 1 do
    if result[i]='.' then
      begin
      SetLength(result, i-1);
      exit;
      end;
  end;
procedure ChangeExt(var FileName: String; const NewExt: String);
var i,j,n,t: integer;
begin
j:=Length(FileName)+2;//j - начало расширения с учетом того, что файл без расширения
n:=Length(NewExt);
for i:=j-2 downto 1 do
  case FileName[i] of
    '.': begin j:=i+1;break;end;  //начало расширения сразу после точки
    '\': break;//начало расширения сразу после названия файла, но еще надо поставить точку
    end;
setLength(FileName,j+n-1);
FileName[j-1]:='.';//Точки может и не быть, если файл без расширения
for i:=j to j+n-1 do FileName[i]:=NewExt[i-j+1];
end;
begin
FileMoveSleep:=60000; //1 минута до следующей попытки переместить файл
FileMoveTime:=60*5;   //5 минут ожидания разблокировки файла
FileMoveAttempts:=120;//120 попыток переместить файл
end.
