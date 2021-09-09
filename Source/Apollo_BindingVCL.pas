unit Apollo_BindingVCL;

interface

uses
  Apollo_Binding_Core,
  System.Rtti,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Grids,
  Vcl.StdCtrls;

type
  TBindingVCL = class(TBindingEngine)
  private
    function GetControlItem(aControl, aSource: TObject): TObject;
    function GetControlItemFromTreeView(aTreeView: TTreeView; aSource: TObject): TTreeNode;
    function GetSourceFromComboBox(aComboBox: TComboBox): TObject;
    function GetSourceFromStringGrid(aStringGrid: TStringGrid): TObject;
    function GetSourceFromTreeView(aTreeView: TTreeView): TObject;
    procedure ApplyToComboBox(aComboBox: TComboBox; aBindItem: TBindItem);
    procedure ApplyToLabeledEdit(aLabeledEdit: TLabeledEdit; aBindItem: TBindItem; const aValue: string);
    procedure ApplyToRichEdit(aRichEdit: TRichEdit; aBindItem: TBindItem; const aValue: string);
    procedure ApplyToStringGrid(aStringGrid: TStringGrid; aBindItem: TBindItem);
    procedure ApplyToTreeView(aTreeView: TTreeView; aBindItem: TBindItem; aParentNode: TTreeNode);
    procedure EditOnChange(Sender: TObject);
  protected
    function GetSourceFromControl(aControl: TObject): TObject; override;
    function IsValidControl(aControl: TObject; out aControlName: string;
      out aChildControls: TArray<TObject>): Boolean; override;
    procedure ApplyToControls(aBindItem: TBindItem; aRttiProperty: TRttiProperty); override;
  end;

  TBind = record
  public
    class function BindToControlItem(aSource: TObject; aControl: TObject): Integer; static;
    class function BindToControlNode<T: class>(aSource: TObject; aControl: TObject; aParentNode: T): T; static;
    class function GetControlItemOrNode<T: class>(aControl, aSource: TObject): T; static;
    class function GetSource<T: class>(aControl: TObject): T; static;
    class function HasSource(aControl: TObject): Boolean; static;
    class procedure Bind(aSource: TObject; aRootControl: TObject; const aControlNamePrefix: string = ''); static;
    class procedure ClearControl(aControl: TObject); static;
    class procedure RemoveBind(aControl: TObject); static;
  end;

var
  gBindingVCL: TBindingVCL;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.TypInfo,
  Vcl.Controls;

{ TBind }

class procedure TBind.Bind(aSource, aRootControl: TObject;
  const aControlNamePrefix: string);
begin
  gBindingVCL.Bind(aSource, aRootControl, aControlNamePrefix);
end;

class function TBind.BindToControlItem(aSource, aControl: TObject): Integer;
begin
  Result := gBindingVCL.BindToControlItem(aSource, aControl);
end;

class function TBind.BindToControlNode<T>(aSource: TObject; aControl: TObject; aParentNode: T): T;
begin
  Result := gBindingVCL.BindToControlItem(aSource, aControl, aParentNode) as T;
end;

class procedure TBind.ClearControl(aControl: TObject);
var
  i: Integer;
  Index: Integer;
  StringGrid: TStringGrid;
begin
  if aControl.InheritsFrom(TStringGrid) then
  begin
    StringGrid := TStringGrid(aControl);
    Index := StringGrid.FixedRows;
    StringGrid.RowCount := Index + 1;
    for i := 0 to StringGrid.ColCount - 1 do
      StringGrid.Cells[i, Index] := '';
    StringGrid.Objects[0, Index] := nil;
  end
  else
  if aControl.InheritsFrom(TComboBox) then
  begin
    TComboBox(aControl).Clear;
  end
  else
    raise Exception.CreateFmt('TBind.ClearControl: Control %s is not support', [aControl.ClassName]);

  RemoveBind(aControl);
end;

class function TBind.GetControlItemOrNode<T>(aControl, aSource: TObject): T;
begin
  Result := gBindingVCL.GetControlItem(aControl, aSource) as T;
end;

class function TBind.GetSource<T>(aControl: TObject): T;
var
  Source: TObject;
begin
  Source := gBindingVCL.GetSource(aControl);

  if not Assigned(Source) then
    Result := nil
  else
  if Source is T then
    Result := Source as T
  else
    Result := nil;
end;

class function TBind.HasSource(aControl: TObject): Boolean;
var
  Source: TObject;
begin
  Source := gBindingVCL.GetSource(aControl);
  Result := Assigned(Source);
end;

class procedure TBind.RemoveBind(aControl: TObject);
begin
  gBindingVCL.RemoveBind(aControl);
end;

{ TBindingVCL }

procedure TBindingVCL.ApplyToComboBox(aComboBox: TComboBox;
  aBindItem: TBindItem);
var
  Index: Integer;
begin
  Index := aComboBox.Items.AddObject('', aBindItem.Source);
  SetLastBindedControlItemIndex(Index);
end;

procedure TBindingVCL.ApplyToControls(aBindItem: TBindItem; aRttiProperty: TRttiProperty);
var
  Control: TObject;
  Source: TObject;
begin
  Control := aBindItem.Control;
  Source := aBindItem.Source;

  if Control.InheritsFrom(TLabeledEdit) then
    ApplyToLabeledEdit(TLabeledEdit(Control), aBindItem, aRttiProperty.GetValue(Source).AsString)
  else
  if Control.InheritsFrom(TStringGrid) then
    ApplyToStringGrid(TStringGrid(Control), aBindItem)
  else
  if Control.InheritsFrom(TRichEdit) then
    ApplyToRichEdit(TRichEdit(Control), aBindItem, aRttiProperty.GetValue(Source).AsString)
  else
  if Control.InheritsFrom(TTreeView) then
    ApplyToTreeView(TTreeView(Control), aBindItem, TTreeNode(FControlParentItem))
  else
  if Control.InheritsFrom(TComboBox) then
    ApplyToComboBox(TComboBox(Control), aBindItem)
  else
    raise Exception.CreateFmt('TBindingVCL: Control class %s does not support.', [Control.ClassName]);
end;

procedure TBindingVCL.ApplyToLabeledEdit(aLabeledEdit: TLabeledEdit;
  aBindItem: TBindItem; const aValue: string);
begin
  aLabeledEdit.Text := aValue;

  if Assigned(aLabeledEdit.OnChange) then
    SetNativeEvent(aLabeledEdit, TMethod(aLabeledEdit.OnChange));

  aLabeledEdit.OnChange := EditOnChange;
end;

procedure TBindingVCL.ApplyToRichEdit(aRichEdit: TRichEdit;
  aBindItem: TBindItem; const aValue: string);
begin
  aRichEdit.Text := aValue;

  if Assigned(aRichEdit.OnChange) then
    SetNativeEvent(aRichEdit, TMethod(aRichEdit.OnChange));

  aRichEdit.OnChange := EditOnChange;
end;

procedure TBindingVCL.ApplyToStringGrid(aStringGrid: TStringGrid;
  aBindItem: TBindItem);
var
  FirstDataRow: Integer;
  RowCount: Integer;
  i: Integer;
  Index: Integer;
begin
  Index := -1;
  if aBindItem.New then
  begin
    FirstDataRow := aStringGrid.FixedRows;
    if aStringGrid.Objects[0, FirstDataRow] = nil then
      RowCount := FirstDataRow + 1
    else
      RowCount := aStringGrid.RowCount + 1;

    aStringGrid.RowCount := RowCount;
    Index := RowCount - 1;
    aStringGrid.Objects[0, Index] := aBindItem.Source;
  end
  else
    for i := 0 to aStringGrid.RowCount - 1 do
      if aStringGrid.Objects[0, i] = aBindItem.Source then
      begin
        Index := i;
        Break;
      end;

  SetLastBindedControlItemIndex(Index);
end;

procedure TBindingVCL.ApplyToTreeView(aTreeView: TTreeView;
  aBindItem: TBindItem; aParentNode: TTreeNode);
var
  TreeNode: TTreeNode;
begin
  if Assigned(aParentNode) then
    TreeNode := aTreeView.Items.AddChildObject(aParentNode, '', aBindItem.Source)
  else
    TreeNode := aTreeView.Items.AddObject(nil, '', aBindItem.Source);

  SetLastBindedControlItem(TreeNode);
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

function TBindingVCL.GetControlItem(aControl, aSource: TObject): TObject;
begin
  if aControl.InheritsFrom(TTreeView) then
    Result := GetControlItemFromTreeView(TTreeView(aControl), aSource)
  else
    raise Exception.CreateFmt('TBindingVCL.GetControlItem: Control class %s does not support', [aControl.ClassName]);
end;

function TBindingVCL.GetControlItemFromTreeView(aTreeView: TTreeView;
  aSource: TObject): TTreeNode;

  function FindInItem(aItem: TTreeNode): TTreeNode;
  var
    i: Integer;
  begin
    Result := nil;

    for i := 0 to aItem.Count - 1 do
    begin
      if aItem.Item[i].Data = Pointer(aSource) then
        Exit(aItem.Item[i]);

      Result := FindInItem(aItem.Item[i]);
    end;
  end;

var
  i: Integer;
begin
  Result := nil;

  for i := 0 to aTreeView.Items.Count - 1 do
  begin
    if aTreeView.Items.Item[i].Data = Pointer(aSource) then
      Exit(aTreeView.Items.Item[i]);

    Result := FindInItem(aTreeView.Items.Item[i]);
  end;
end;

function TBindingVCL.GetSourceFromComboBox(aComboBox: TComboBox): TObject;
begin
  Result := aComboBox.Items.Objects[aComboBox.ItemIndex];
end;

function TBindingVCL.GetSourceFromControl(aControl: TObject): TObject;
begin
  if aControl is TStringGrid then
    Result := GetSourceFromStringGrid(TStringGrid(aControl))
  else
  if aControl.InheritsFrom(TTreeView) then
    Result := GetSourceFromTreeView(TTreeView(aControl))
  else
  if aControl.InheritsFrom(TComboBox) then
    Result := GetSourceFromComboBox(TComboBox(aControl))
  else
    raise Exception.CreateFmt('TBindingVCL.GetSourceFromControl: Control class %s does not support', [aControl.ClassName]);
end;

function TBindingVCL.GetSourceFromStringGrid(aStringGrid: TStringGrid): TObject;
begin
  Result := aStringGrid.Objects[0, aStringGrid.Row];
end;

function TBindingVCL.GetSourceFromTreeView(aTreeView: TTreeView): TObject;
begin
  if Assigned(aTreeView.Selected) then
    Result := aTreeView.Selected.Data
  else
    Result := nil;
end;

function TBindingVCL.IsValidControl(aControl: TObject; out aControlName: string;
  out aChildControls: TArray<TObject>): Boolean;
var
  Control: TWinControl;
  i: Integer;
begin
  if aControl.InheritsFrom((TWinControl) ) then
  begin
    Result := True;
    Control := aControl as TWinControl;
    aControlName := Control.Name;

    aChildControls := [];
    for i := 0 to Control.ControlCount - 1 do
      aChildControls := aChildControls + [Control.Controls[i]];
  end
  else
    Result := False;
end;

initialization
  gBindingVCL := TBindingVCL.Create;

finalization
  gBindingVCL.Free;

end.
