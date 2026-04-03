unit Unit1;

interface

uses
  VCLFixes, VCLFixPack, VCLFlickerReduce, Windows, Messages, SysUtils, Variants,
  Classes, Graphics, Controls, Forms, Dialogs, StdCtrls,
  EasyCript, NetConf;

type
  TForm1 = class(TForm)
    STR: TEdit;
    CRPT: TEdit;
    Button1: TButton;
    Button2: TButton;
    KEY: TEdit;
    Button3: TButton;
    Memo1: TMemo;
    Button4: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
var S: String;
    i: integer;
begin
S:=STR.Text;
for i := length(S)+1 to 30 do S:=S+chr(10);
CRPT.Text:=EncryptStr(S,StrToInt(KEY.Text));
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
STR.Text:=DecryptStr(CRPT.Text,StrToInt(KEY.Text));
end;

procedure TForm1.Button3Click(Sender: TObject);
var IpMacList: TStringList;
    i,cd: integer;
    IP, MAC, S, CODE: String;
begin
IpMacList := TStringList.Create;
GetNICDeviceInfo(IpMacList);
Memo1.Clear;
for i := IpMacList.Count - 1 downto 0 do
  begin
  IP := IpMacList.Names[i];
  MAC := IpMacList.ValueFromIndex[i];
  S:=MAC;
  Memo1.Lines.Add('IP:' + IP + ', MAC:' + MAC);
  end;

for i:=1 to length(S)-1 do if S[i]<>'-' then CODE:=CODE+S[i];
for i:=1 to length(CODE)-1 do if CODE[i]<>'0' then
  begin
  S:=copy(CODE,i,length(CODE));
  break;
  end;

Memo1.Lines.Add('CODE='+CODE);
Memo1.Lines.Add('S='+S);
KEY.Text:=IntToStr(GetCriptCode);
//i:=StrToInt('0x'+CODE);

IpMacList.Free;
end;

function GetPC: word; stdcall;
  external 'NetParam.dll' name 'GetPCCode';

procedure TForm1.Button4Click(Sender: TObject);
begin
KEY.Text := IntToStr(GetPC);
end;

end.
