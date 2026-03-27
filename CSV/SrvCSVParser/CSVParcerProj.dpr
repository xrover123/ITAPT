program CSVParcerProj;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Main},
  CSVParser in 'CSVParser.pas',
  FileFunc in 'FileFunc.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMain, Main);
  Application.Run;
end.
