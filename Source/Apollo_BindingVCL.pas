unit Apollo_BindingVCL;

interface

uses
  Apollo_Binding_Core,
  System.Classes,
  System.Rtti,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls;

type
  TBindingVCL = class(TBindingEngine)
  private
    procedure EditOnChange(Sender: TObject);
    procedure SetToEdit(aEdit: TEdit; const aValue: string; var aBindItem: TBindItem);
    procedure SetToLabeledEdit(aLabeledEdit: TLabeledEdit; const aValue: string; var aBindItem: TBindItem);
    procedure SetToRichEdit(aRichEdit: TRichEdit; const aValue: string; var aBindItem: TBindItem);
    procedure SetToTreeView(aTreeView: TTreeView; const aValue: string; aParentNode: TTreeNode; var aBindItem: TBindItem);
    procedure SetToTreeNode(aTreeNode: TTreeNode; var aBindItem: TBindItem);
    procedure TreeViewOnEdited(Sender: TObject; Node: TTreeNode; var S: string);
  protected
    procedure BindPropertyToControl(aSource: TObject; aRttiProperty: TRttiProperty; aControl: TObject); override;
    procedure DoBind(aSource: TObject; aControl: TObject; const aControlNamePrefix: string;
      aRttiProperties: TArray<TRttiProperty>); override;
  end;

  TBind = class
  public
    class function GetBindItem<T: class>(aSource: TObject): TBindItem; overload;
    class function GetBindItem(aControl: TControl): TBindItem; overload;
    class function GetSource<T: class>(aControl: TControl): T;
    class procedure Bind(aSource: TObject; aRootControl: TObject; const aControlNamePrefix: string = '');
    class procedure Notify(aSource: TObject);
    class procedure SingleBind(aSource: TObject; aControl: TObject);
  end;

var
  gBindingVCL: TBindingVCL;

implementation

uses
  System.SysUtils,
  System.TypInfo;

{ TBind }

class procedure TBind.Bind(aSource: TObject; aRootControl: TObject;
  const aControlNamePrefix: string);
begin
  gBindingVCL.Bind(aSource, aRootControl, aControlNamePrefix);
end;

class function TBind.GetBindItem(aControl: TControl): TBindItem;
begin
  Result := gBindingVCL.GetFirstBindItem(aControl);
end;

class function TBind.GetBindItem<T>(aSource: TObject): TBindItem;
var
  BindItem: TBindItem;
  BindItems: TArray<TBindItem>;
begin
  BindItems := gBindingVCL.GetBindItemsBySource(aSource);
  for BindItem in BindItems do
    if BindItem.Control.ClassType = T then
      Exit(BindItem);
end;

class function TBind.GetSource<T>(aControl: TControl): T;
begin
  Result := GetBindItem(aControl).Source as T;
end;

class procedure TBind.Notify(aSource: TObject);
begin
  gBindingVCL.Notify(aSource);
end;

class procedure TBind.SingleBind(aSource: TObject; aControl: TObject);
begin
  gBindingVCL.SingleBind(aSource, aControl);
end;

{ TBindingVCL }

procedure TBindingVCL.BindPropertyToControl(aSource: TObject;
  aRttiProperty: TRttiProperty; aControl: TObject);
var
  BindItem: TBindItem;
begin
  if Assigned(aRttiProperty) then
    BindItem := AddBindItem(aSource, aRttiProperty.Name, aControl)
  else
    BindItem := AddBindItem(aSource, '', aControl);

  if aControl is TEdit then
    SetToEdit(TEdit(aControl), aRttiProperty.GetValue(aSource).AsString, BindItem)
  else
  if aControl is TLabeledEdit then
    SetToLabeledEdit(TLabeledEdit(aControl), aRttiProperty.GetValue(aSource).AsString, BindItem)
  else
  if aControl is TRichEdit then
    SetToRichEdit(TRichEdit(aControl), aRttiProperty.GetValue(aSource).AsString, BindItem)
  else
  if aControl is TTreeView then
    SetToTreeView(TTreeView(aControl), aRttiProperty.GetValue(aSource).AsString, nil, BindItem)
  else
  if aControl is TTreeNode then
    SetToTreeNode(TTreeNode(aControl), BindItem)
  else
    raise Exception.CreateFmt('TBindingVCL: Control class %s does not supported', [aControl.ClassName]);
end;

procedure TBindingVCL.DoBind(aSource: TObject; aControl: TObject;
  const aControlNamePrefix: string; aRttiProperties: TArray<TRttiProperty>);
var
  ChildControl: TControl;
  Control: TWinControl;
  i: Integer;
  RttiProperty: TRttiProperty;
begin
  if aControl is TWinControl then
  begin
    Control := aControl as TWinControl;

    for i := 0 to Control.ControlCount - 1 do
    begin
      ChildControl := Control.Controls[i];

      if ChildControl.InheritsFrom(TWinControl) and
         (TWinControl(ChildControl).ControlCount > 0)
      then
        DoBind(aSource, ChildControl, aControlNamePrefix, aRttiProperties);

      RttiProperty := GetMatchedSourceProperty(aControlNamePrefix, ChildControl.Name, aRttiProperties);
      BindPropertyToControl(aSource, RttiProperty, ChildControl);
    end;

    RttiProperty := GetMatchedSourceProperty(aControlNamePrefix, Control.Name, aRttiProperties);
    BindPropertyToControl(aSource, RttiProperty, Control);
  end
  else
    BindPropertyToControl(aSource, nil, aControl);
end;

procedure TBindingVCL.EditOnChange(Sender: TObject);
var
  BindItem: TBindItem;
  Edit: TCustomEdit;
  Method: TMethod;
  NotifyEvent: TNotifyEvent;
begin
  Edit := Sender as TCustomEdit;
  BindItem := GetFirstBindItem(Edit);
  SetPropValue(BindItem.Source, BindItem.PropName, Edit.Text);

  if TryGetNativeEvent(Edit, Method) then
  begin
    TMethod(NotifyEvent) := Method;
    NotifyEvent(Sender);
  end;
end;

procedure TBindingVCL.SetToEdit(aEdit: TEdit; const aValue: string; var aBindItem: TBindItem);
begin
  aEdit.Text := aValue;

  if Assigned(aEdit.OnChange) then
    SetNativeEvent(aEdit, TMethod(aEdit.OnChange));

  aEdit.OnChange := EditOnChange;
end;

procedure TBindingVCL.SetToLabeledEdit(aLabeledEdit: TLabeledEdit;
  const aValue: string; var aBindItem: TBindItem);
begin
  aLabeledEdit.Text := aValue;

  if Assigned(aLabeledEdit.OnChange) then
    SetNativeEvent(aLabeledEdit, TMethod(aLabeledEdit.OnChange));

  aLabeledEdit.OnChange := EditOnChange;
end;

procedure TBindingVCL.SetToRichEdit(aRichEdit: TRichEdit; const aValue: string;
  var aBindItem: TBindItem);
begin
  aRichEdit.Text := aValue;

  if Assigned(aRichEdit.OnChange) then
    SetNativeEvent(aRichEdit, TMethod(aRichEdit.OnChange));

  aRichEdit.OnChange := EditOnChange;
end;

procedure TBindingVCL.SetToTreeNode(aTreeNode: TTreeNode;
  var aBindItem: TBindItem);
var
  BindItem: TBindItem;
  TreeView: TTreeView;
begin
  TreeView := aTreeNode.TreeView as TTreeView;
  aBindItem.Control := TreeView;

  BindItem := GetFirstBindItem(TreeView);
  SetToTreeView(TreeView, GetPropValue(BindItem.Source, BindItem.PropName), aTreeNode, aBindItem);
end;

procedure TBindingVCL.SetToTreeView(aTreeView: TTreeView; const aValue: string;
  aParentNode: TTreeNode; var aBindItem: TBindItem);
var
  Node: TTreeNode;
begin
  Node := aTreeView.Items.AddChild(aParentNode, aValue);
  Node.Data := aBindItem.Source;

  aBindItem.SecondaryControl := Node;

  if Assigned(aTreeView.OnEdited) then
    SetNativeEvent(aTreeView, TMethod(aTreeView.OnEdited));

  aTreeView.OnEdited := TreeViewOnEdited;
end;

procedure TBindingVCL.TreeViewOnEdited(Sender: TObject; Node: TTreeNode;
  var S: string);
var
  BindItem: TBindItem;
  Method: TMethod;
  TreeView: TTreeView;
  TVEditedEvent: TTVEditedEvent;
begin
  TreeView := Sender as TTreeView;
  BindItem := GetFirstBindItem(TreeView);
  SetPropValue(Node.Data, BindItem.PropName, S);

  if TryGetNativeEvent(TreeView, Method) then
  begin
    TMethod(TVEditedEvent) := Method;
    TVEditedEvent(TreeView, Node, S);
  end;
end;

initialization
  gBindingVCL := TBindingVCL.Create;

finalization
  gBindingVCL.Free;

end.
