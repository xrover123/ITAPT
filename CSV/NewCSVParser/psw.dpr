program psw;

{$APPTYPE CONSOLE}

uses
  SysUtils, EasyCript, {NetConf,} IniFiles;
const psw_len: word = 30;
var i,w: word;
    psw_str: String;
    INI: TIniFile;
function GetPC: word; stdcall;
  external 'NetParam.dll' name 'GetPCCode';
begin
  { TODO -oUser -cConsole Main : Insert code here }
  if ParamCount<>1 then
    begin
    writeLn('The format of the command:');
    writeLn('psw <password>');
    readln;
    exit;
    end;
  w:=GetPC;//GetCriptCode;
  psw_str:=ParamStr(1);
  i := length(psw_str);
  if i<=psw_len then
    begin
    setLength(psw_str, psw_len);
    for i := i+1 to psw_len do psw_str[i]:=chr(10);
    end;
  psw_str:=EncryptStr(psw_str,w);

  INI := TIniFile.Create(ExtractFilePath(paramStr(0))+'exchange.ini');
  INI.WriteString('DB','PSW',psw_str);
  INI.Free;
  writeLn('The password is saved.');
end.
