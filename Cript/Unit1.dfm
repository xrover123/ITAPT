object Form1: TForm1
  Left = 547
  Top = 239
  Width = 928
  Height = 480
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object STR: TEdit
    Left = 88
    Top = 16
    Width = 729
    Height = 21
    TabOrder = 0
    Text = 'parusina'
  end
  object CRPT: TEdit
    Left = 88
    Top = 48
    Width = 729
    Height = 21
    TabOrder = 1
  end
  object Button1: TButton
    Left = 88
    Top = 88
    Width = 75
    Height = 25
    Caption = 'Encript'
    TabOrder = 2
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 88
    Top = 120
    Width = 75
    Height = 25
    Caption = 'Decript'
    TabOrder = 3
    OnClick = Button2Click
  end
  object KEY: TEdit
    Left = 328
    Top = 88
    Width = 121
    Height = 21
    TabOrder = 4
  end
  object Button3: TButton
    Left = 424
    Top = 320
    Width = 97
    Height = 25
    Caption = 'MAC Address'
    TabOrder = 5
    OnClick = Button3Click
  end
  object Memo1: TMemo
    Left = 328
    Top = 136
    Width = 281
    Height = 161
    TabOrder = 6
  end
  object Button4: TButton
    Left = 576
    Top = 320
    Width = 75
    Height = 25
    Caption = 'Button4'
    TabOrder = 7
    OnClick = Button4Click
  end
end
