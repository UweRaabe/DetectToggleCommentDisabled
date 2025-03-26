unit DetectToggleCommentDisabled.Main;

interface

procedure Register;

implementation

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Actions, System.UITypes, System.Rtti,
  Vcl.ActnList, Vcl.Menus, Vcl.Dialogs, Vcl.ActnPopup,
  ToolsAPI;

type
  TMenuManager = class
  private
    FActionList: TActionList;
    FecToggleComment: TAction;
    FElideActionList: TActionList;
    FMsgResult: Integer;
    FRegistered: Boolean;
    FSaveEditorPopupMenuPopup: TNotifyEvent;
    FSaveStateChange: TNotifyEvent;
    FTestAction: TAction;
    procedure EditorPopupMenuPopup(Sender: TObject);
    procedure ElideStateChange(Sender: TObject);
    procedure LogMessage(const AMessage: string);
    procedure SetecToggleComment(const Value: TAction);
    procedure SetElideActionList(const Value: TActionList);
    procedure SetTestAction(const Value: TAction);
    procedure TestActionExecute(Sender: TObject);
    procedure TestActionUpdate(Sender: TObject);

  public
    constructor Create;
    destructor Destroy; override;
    property ecToggleComment: TAction read FecToggleComment write SetecToggleComment;
    property ElideActionList: TActionList read FElideActionList write SetElideActionList;
    property TestAction: TAction read FTestAction write SetTestAction;
  end;

type
  TIDEWizard = class(TNotifierObject, IOTAWizard)
  private
    FMenuManager: TMenuManager;
  public
    constructor Create;
    destructor Destroy; override;
    function GetIDString: string;
    procedure Execute;
    function GetName: string;
    function GetState: TWizardState;
  end;

procedure Register;
begin
  RegisterPackageWizard(TIDEWizard.Create);
end;

constructor TIDEWizard.Create;
begin
  FMenuManager := TMenuManager.Create;
end;

destructor TIDEWizard.Destroy;
begin
  // It is important to free FMenuManager when the package is unloaded because
  // it will unregister its action list in the destructor which is required.
  FreeAndNil(FMenuManager);
  inherited;
end;

procedure TIDEWizard.Execute;
begin
end;

function TIDEWizard.GetIDString: string;
begin
  Result := '[44B2E446-97C5-4D7D-918E-18FBC29D8B5E]';
end;

function TIDEWizard.GetName: string;
begin
  Result := 'Editor.LocalMenu.Demo';
end;

function TIDEWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

constructor TMenuManager.Create;
var
  editorServices: IOTAEditorServices;
begin
  inherited;

  FActionList := TActionList.Create(nil);
  TestAction := TAction.Create(nil);

  if Supports(BorlandIDEServices, IOTAEditorServices, editorServices) then begin
    var P := editorServices.TopView.GetEditWindow.Form.FindComponent('EditorLocalMenu') as TPopupActionBar;
    FSaveEditorPopupMenuPopup := P.OnPopup;
    P.OnPopup := EditorPopupMenuPopup;
    FRegistered := True;
  end;

  FMsgResult := mrNone;
end;

destructor TMenuManager.Destroy;
var
  editorServices: IOTAEditorServices;
begin
  TestAction := nil;
  ElideActionList := nil;
  ecToggleComment := nil;
  if FRegistered then begin
    if Supports(BorlandIDEServices, IOTAEditorServices, editorServices) then begin
      var P := editorServices.TopView.GetEditWindow.Form.FindComponent('EditorLocalMenu') as TPopupActionBar;
      P.OnPopup := FSaveEditorPopupMenuPopup;
      FRegistered := False;
    end;
  end;
  FreeAndNil(FActionList);
  inherited;
end;

procedure TMenuManager.EditorPopupMenuPopup(Sender: TObject);
var
  item: TMenuItem;
begin
  if Assigned(FSaveEditorPopupMenuPopup) then
    FSaveEditorPopupMenuPopup(Sender);

  if Sender is TMenuItem then
    item := Sender as TMenuItem
  else if Sender is TPopupMenu then
    item := (Sender as TPopupMenu).Items
  else begin
    LogMessage('Sender is ' + Sender.ClassName);
    Exit;
  end;

  for var I := 0 to item.Count - 1 do begin
    var act := item[I].Action;
    if (act <> nil) and SameText(act.Name, 'ecToggleComment') then begin
      if act is TAction then begin
        ecToggleComment := act as TAction;
        var list := ecToggleComment.ActionList;
        if list is TActionList then
          ElideActionList := ecToggleComment.ActionList as TActionList
        else
          LogMessage('ecToggleComment.ActionList is ' + list.ClassName);
      end
      else begin
        LogMessage('act is ' + act.ClassName);
      end;
      Break;
    end;
  end;

end;

procedure TMenuManager.ElideStateChange(Sender: TObject);
begin
  var state := (Sender as TActionList).State;
  var msg := 'ElideActionList state change to ' + TRttiEnumerationType.GetName(state);
  LogMessage(msg);
end;

procedure TMenuManager.LogMessage(const AMessage: string);
var
  msgServices: IOTAMessageServices;
begin
  if BorlandIDEServices.GetService(IOTAMessageServices, msgServices) then
    msgServices.AddTitleMessage(AMessage);
end;

procedure TMenuManager.SetecToggleComment(const Value: TAction);
begin
  if FecToggleComment <> Value then
  begin
    FecToggleComment := Value;
  end;
end;

procedure TMenuManager.SetElideActionList(const Value: TActionList);
begin
  if FElideActionList <> Value then
  begin
    if FElideActionList <> nil then begin
      FElideActionList.OnStateChange := FSaveStateChange;
    end;
    FElideActionList := Value;
    if FElideActionList <> nil then begin
      FSaveStateChange := FElideActionList.OnStateChange;
      FElideActionList.OnStateChange := ElideStateChange;
    end;
  end;
end;

procedure TMenuManager.SetTestAction(const Value: TAction);
begin
  if FTestAction <> Value then begin
    FTestAction.Free;
    FTestAction := Value;
    if FTestAction <> nil then begin
      FTestAction.ShortCut := ShortCut(VK_OEM_2, [ssCtrl]);
      FTestAction.OnExecute := TestActionExecute;
      FTestAction.OnUpdate := TestActionUpdate;
      FTestAction.ActionList := FActionList;
    end;
  end;
end;

procedure TMenuManager.TestActionExecute(Sender: TObject);
begin
  if ecToggleComment.Suspended then begin
    if FMsgResult <> mrNone then begin
      var res := MessageDlg('Ctrl+# is currently suspended.'#13'Shall I fix this?', TMsgDlgType.mtConfirmation, mbYesAllNoAllCancel, 0);
      case res of
        mrYes, mrYesToAll: begin
          ElideActionList.State := asNormal;
          ecToggleComment.Execute;
        end;
      end;
      case res of
        mrYesToAll, mrNoToAll : begin
          FMsgResult := res;
        end;
      else
        FMsgResult := mrNone;
      end;
    end;
  end;
end;

procedure TMenuManager.TestActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := (ElideActionList <> nil) and (ecToggleComment <> nil) and ecToggleComment.Suspended;
end;

end.
