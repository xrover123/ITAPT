object Main: TMain
  Left = 423
  Top = 134
  Width = 392
  Height = 105
  Caption = 'Import CSV to Oracle'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 27
    Top = 24
    Width = 3
    Height = 13
  end
  object ORAConnection: TSQLConnection
    ConnectionName = 'OracleConnection'
    DriverName = 'Oracle'
    GetDriverFunc = 'getSQLDriverORACLE'
    LibraryName = 'dbexpora.dll'
    LoginPrompt = False
    Params.Strings = (
      'DriverName=Oracle'
      'DataBase='
      'User_Name='
      'Password='
      'RowsetSize=20'
      'BlobSize=-1'
      'ErrorResourceFile='
      'LocaleCode=0000'
      'Oracle TransIsolation=ReadCommited'
      'OS Authentication=False'
      'Multiple Transaction=False'
      'Trim Char=False')
    VendorLib = 'oci.dll'
    Left = 8
  end
  object OraProc: TSQLStoredProc
    MaxBlobSize = -1
    Params = <
      item
        DataType = ftString
        ParamType = ptInput
      end
      item
        DataType = ftUnknown
        ParamType = ptUnknown
      end>
    SQLConnection = ORAConnection
    Left = 72
  end
  object SP: TSQLStoredProc
    MaxBlobSize = -1
    Params = <>
    SQLConnection = ORAConnection
    Left = 40
  end
end
