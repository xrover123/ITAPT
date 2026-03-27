object ITWHAT_PARUS_EXCHANGE: TITWHAT_PARUS_EXCHANGE
  OldCreateOrder = False
  DisplayName = 'Data exchange between ITWHAT and PARUS'
  OnExecute = ServiceExecute
  Left = 976
  Top = 98
  Height = 150
  Width = 215
  object TN: TIdTelnetServer
    Active = True
    Bindings = <>
    CommandHandlers = <>
    DefaultPort = 50505
    Greeting.NumericCode = 0
    MaxConnectionReply.NumericCode = 0
    OnExecute = TNExecute
    ReplyExceptionCode = 0
    ReplyTexts = <>
    ReplyUnknownCommand.NumericCode = 0
    LoginMessage = 'Indy Telnet Server'
    Left = 72
    Top = 40
  end
end
