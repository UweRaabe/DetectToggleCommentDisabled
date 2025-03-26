unit DetectToggleCommentDisabled.Main;

interface

procedure Register;

implementation

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Actions, System.UITypes, System.Rtti,
  Vcl.ActnList, Vcl.Menus, Vcl.Dialogs, Vcl.ActnPopup,
  ToolsAPI, DockForm;

type
  TEditorMenuManager = class(TComponent)
  private
    FActionList: TActionList;
    FecToggleComment: TAction;
    FElideActionList: TActionList;
    FLocalMenu: TPopupMenu;
    FMsgResult: Integer;
    FNotifierID: Integer;
    FRegistered: Boolean;
    FSaveEditorPopupMenuPopup: TNotifyEvent;
    FSaveStateChange: TNotifyEvent;
    FTestAction: TAction;
    procedure EditorPopupMenuPopup(Sender: TObject);
    procedure ElideStateChange(Sender: TObject);
    procedure LogMessage(const AMessage: string);
    procedure SetecToggleComment(const Value: TAction);
    procedure SetElideActionList(const Value: TActionList);
    procedure SetLocalMenu(const Value: TPopupMenu);
    procedure SetTestAction(const Value: TAction);
    procedure TestActionExecute(Sender: TObject);
    procedure TestActionUpdate(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DoRegister;
    procedure DoUnregister;
    property ecToggleComment: TAction read FecToggleComment write SetecToggleComment;
    property ElideActionList: TActionList read FElideActionList write SetElideActionList;
    property LocalMenu: TPopupMenu read FLocalMenu write SetLocalMenu;
    property TestAction: TAction read FTestAction write SetTestAction;
  end;

type
  TEditServicesNotifier = class(TNotifierObject, INTAEditServicesNotifier)
  private
    FMenuManager: TEditorMenuManager;
  protected
    procedure WindowShow(const EditWindow: INTAEditWindow; Show, LoadedFromDesktop: Boolean);
    procedure WindowNotification(const EditWindow: INTAEditWindow; Operation: TOperation);
    procedure WindowActivated(const EditWindow: INTAEditWindow);
    procedure WindowCommand(const EditWindow: INTAEditWindow; Command, Param: Integer; var Handled: Boolean);
    procedure EditorViewActivated(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
    procedure EditorViewModified(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
    procedure DockFormVisibleChanged(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
    procedure DockFormUpdated(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
    procedure DockFormRefresh(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
  public
    constructor Create(AMenuManager: TEditorMenuManager);
  end;

type
  TMagician = class
  strict private
  class var
    FInstance: TMagician;
  private
    FMenuManager: TEditorMenuManager;
  public
    constructor Create;
    destructor Destroy; override;
    class procedure CreateInstance;
    class procedure DestroyInstance;
  end;

procedure Register;
begin
  TMagician.CreateInstance;
end;

constructor TEditorMenuManager.Create(AOwner: TComponent);
begin
  inherited;
  FActionList := TActionList.Create(nil);
  TestAction := TAction.Create(nil);
  FMsgResult := mrNone;
  DoRegister;
end;

destructor TEditorMenuManager.Destroy;
begin
  TestAction := nil;
  ElideActionList := nil;
  ecToggleComment := nil;
  DoUnregister;
  FreeAndNil(FActionList);
  inherited;
end;

procedure TEditorMenuManager.DoRegister;
var
  editorServices: IOTAEditorServices;
begin
  if FRegistered then Exit;

  if Supports(BorlandIDEServices, IOTAEditorServices, editorServices) then begin
    if editorServices.TopView = nil then begin
      if FNotifierID = 0 then begin
        FNotifierID := editorServices.AddNotifier(TEditServicesNotifier.Create(Self));
      end;
      Exit;
    end;
    LocalMenu := editorServices.TopView.GetEditWindow.Form.FindComponent('EditorLocalMenu') as TPopupActionBar;
    FRegistered := True;
  end;
end;

procedure TEditorMenuManager.DoUnregister;
var
  editorServices: IOTAEditorServices;
begin
  if Supports(BorlandIDEServices, IOTAEditorServices, editorServices) then begin
    if FNotifierID <> 0 then begin
      editorServices.RemoveNotifier(FNotifierID);
      FNotifierID := 0;
    end;
  end;

  if not FRegistered then Exit;

  LocalMenu := nil;
  FRegistered := False;
end;

procedure TEditorMenuManager.EditorPopupMenuPopup(Sender: TObject);
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

procedure TEditorMenuManager.ElideStateChange(Sender: TObject);
begin
  var state := (Sender as TActionList).State;
  var msg := 'ElideActionList state change to ' + TRttiEnumerationType.GetName(state);
  LogMessage(msg);
end;

procedure TEditorMenuManager.LogMessage(const AMessage: string);
var
  msgServices: IOTAMessageServices;
begin
  if BorlandIDEServices.GetService(IOTAMessageServices, msgServices) then
    msgServices.AddTitleMessage(AMessage);
end;

procedure TEditorMenuManager.SetecToggleComment(const Value: TAction);
begin
  if FecToggleComment <> Value then
  begin
    FecToggleComment := Value;
  end;
end;

procedure TEditorMenuManager.SetElideActionList(const Value: TActionList);
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

procedure TEditorMenuManager.SetLocalMenu(const Value: TPopupMenu);
begin
  if FLocalMenu <> Value then
  begin
    if FLocalMenu <> nil then begin
      FLocalMenu.OnPopup := FSaveEditorPopupMenuPopup;
    end;
    FLocalMenu := Value;
    if FLocalMenu <> nil then begin
      FSaveEditorPopupMenuPopup := FLocalMenu.OnPopup;
      FLocalMenu.OnPopup := EditorPopupMenuPopup;
    end;
  end;
end;

procedure TEditorMenuManager.SetTestAction(const Value: TAction);
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

procedure TEditorMenuManager.TestActionExecute(Sender: TObject);
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

procedure TEditorMenuManager.TestActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := (ElideActionList <> nil) and (ecToggleComment <> nil) and ecToggleComment.Suspended;
end;

constructor TEditServicesNotifier.Create(AMenuManager: TEditorMenuManager);
begin
  inherited Create;
  FMenuManager := AMenuManager;
end;

procedure TEditServicesNotifier.DockFormRefresh(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
begin
end;

procedure TEditServicesNotifier.DockFormUpdated(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
begin
end;

procedure TEditServicesNotifier.DockFormVisibleChanged(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
begin
end;

procedure TEditServicesNotifier.EditorViewActivated(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
begin
end;

procedure TEditServicesNotifier.EditorViewModified(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
begin
end;

procedure TEditServicesNotifier.WindowActivated(const EditWindow: INTAEditWindow);
begin

end;

procedure TEditServicesNotifier.WindowCommand(const EditWindow: INTAEditWindow; Command, Param: Integer; var Handled: Boolean);
begin
end;

procedure TEditServicesNotifier.WindowNotification(const EditWindow: INTAEditWindow; Operation: TOperation);
begin
  case Operation of
    opInsert: FMenuManager.DoRegister;
    opRemove: ;
  end;
end;

procedure TEditServicesNotifier.WindowShow(const EditWindow: INTAEditWindow; Show, LoadedFromDesktop: Boolean);
begin
end;

constructor TMagician.Create;
begin
  inherited;
  FMenuManager := TEditorMenuManager.Create(nil);
end;

destructor TMagician.Destroy;
begin
  FMenuManager.Free;
  FMenuManager := nil;
  inherited;
end;

class procedure TMagician.CreateInstance;
begin
  FInstance := TMagician.Create;
end;

class procedure TMagician.DestroyInstance;
begin
  FInstance.Free;
end;

initialization
finalization
  TMagician.DestroyInstance;
end.
