program CriptForm;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  EasyCript in 'EasyCript.pas',
  NetConf in 'NetConf.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
