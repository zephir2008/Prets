unit mysql01;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, mysql57conn, SQLDB, Forms, Controls, Graphics, Dialogs,
  DBGrids, StdCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    Afficher: TButton;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    MySQLConnection: TMySQL57Connection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
    procedure AfficherClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.AfficherClick(Sender: TObject);
begin
  SQLQuery1.Close;
  SQLQuery1.SQL.Text := 'select * from MAIL_EXCHANGE';
  SQLQuery1.Open;
end;

procedure TForm1.FormActivate(Sender: TObject);
var  LPassword : String;
begin
  MySQLConnection.HostName := 'localhost';
  MySQLConnection.DatabaseName := 'accoord_db';
  MySQLConnection.UserName := 'adm_accoord';
  if InputQuery('Connexion à la base de données', 'Tapez votre mot de passe :', True, LPassword) then
  begin
    MySQLConnection.Password := LPassword;
    try
      MySQLConnection.Connected := True;
      SQLTransaction1.Active := True;
      except
        on e: EDatabaseError do
        begin
          MessageDlg('Erreur de connexion à la base de données.'#10#13'Le mot de passe est peut-être incorrect ?'#10#10#13'Fin de programme.', mtError, [mbOk], 0);
          Close;
        end;
      end;
  end
  else                          (* Pas de mot de passe : fin de programme *)
    Close;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SQLQuery1.Close;
  SQLTransaction1.Active:= False;
  MySQLConnection.Connected:= False;
end;

end.

