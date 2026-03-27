program SRV_ITWHAT_PARUS;

uses
  Forms,
  ITWHAT_PARUS in 'ITWHAT_PARUS.pas' {ITWHAT_PARUS_EXCHANGE: TService};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TITWHAT_PARUS_EXCHANGE, ITWHAT_PARUS_EXCHANGE);
  Application.Run;
end.
