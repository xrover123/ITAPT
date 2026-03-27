unit ITWHAT_PARUS;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  IdBaseComponent, IdComponent, IdTCPServer, IdTelnetServer;

type
  TITWHAT_PARUS_EXCHANGE = class(TService)
    TN: TIdTelnetServer;
    procedure TNExecute(AThread: TIdPeerThread);
    procedure ServiceExecute(Sender: TService);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  ITWHAT_PARUS_EXCHANGE: TITWHAT_PARUS_EXCHANGE;

implementation

{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ITWHAT_PARUS_EXCHANGE.Controller(CtrlCode);
end;

function TITWHAT_PARUS_EXCHANGE.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TITWHAT_PARUS_EXCHANGE.TNExecute(
  AThread: TIdPeerThread);
var strText: String;
begin
    // Принимаем от клиента строку
    strText := AContext.Connection.Socket.ReadLn;
    // Отвечаем
    AContext.Connection.Socket.WriteLn(strText);
    // Закрываем соединение с пользователем
    AContext.Connection.Disconnect;
end;

procedure TITWHAT_PARUS_EXCHANGE.ServiceExecute(Sender: TService);
begin
TN.Active:=True;

TN.Active:=False;
TN.Destroy;
end;

end.
