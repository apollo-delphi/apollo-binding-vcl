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
    procedure ApplyToComboBox(aComboBox: TComboBox; aBindItem: TBindItem; aRttiProperty: TRttiProperty);
    procedure ApplyToDateTimePicker(aPicker: TDateTimePicker; aBindItem: TBindItem; const aValue: TDateTime);
    procedure ApplyToEdit(aEdit: TEdit; aBindItem: TBindItem; const aValue: string);
    procedure ApplyToLabeledEdit(aLabeledEdit: TLabeledEdit; aBindItem: TBindItem; const aValue: string);
    procedure ApplyToRichEdit(aRichEdit: TRichEdit; aBindItem: TBindItem; const aValue: string);
    procedure ApplyToStringGrid(aStringGrid: TStringGrid; aBindItem: TBindItem);
    procedure ApplyToTreeView(aTreeView: TTreeView; aBindItem: TBindItem; aParentNode: TTreeNode);
    procedure DateTimePickerOnChange(Sender: TObject);
    procedure EditOnChange(Sender: TObject);
    procedure EditOnCloseUp(Sender: TObject);
  protected
    function GetSourceFromControl(aControl: TObject): TObject; override;
    function IsValidControl(aControl: TObject; out aControlName: string;
      out aChildControls: TArray<TObject>): Boolean; override;
    procedure ApplyToControls(aBindItem: TBindItem; aRttiProperty: TRttiProperty); override;
  end;

  TBind = record
  public
    class function BindToControlItem(aSource: TObject; aControl: TObject; aPopulateProc: TPopulateProc): Integer; static;
    class function BindToControlNode<T: class>(aSource: TObject; aControl: TObject; aParentNode: T): T; static;
    class function GetControlItemOrNode<T: class>(aControl, aSource: TObject): T; static;
    class function GetSource<T: class>(aControl: TObject): T; static;
    class function HasSource(aControl: TObject): Boolean; static;
    class procedure Bind(aSource: TObject; aRootControl: TObject; const aControlNamePrefix: string = ''); static;
    class procedure ClearControl(aControl: TObject); static;
    class procedure Notify(aSource: TObject); static;
    class procedure RemoveBind(aControl: TObject); static;
    class procedure SubscribeNotification(aSource: TObject; aNotifySourceType: TClass;
      const aKeyPropName: string; const aKeyPropValue: Variant); static;
  end;

var
  gBindingVCL: TBindingVCL;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.TypInfo,
  System.Variants,
  Vcl.Controls;

{ TBind }

class procedure TBind.Bind(aSource, aRootControl: TObject;
  const aControlNamePrefix: string);
begin
  gBindingVCL.Bind(aSource, aRootControl, aControlNamePrefix);
end;

class function TBind.BindToControlItem(aSource, aControl: TObject; aPopulateProc: TPopulateProc): Integer;
begin
  Result := gBindingVCL.BindToControlItem(aSource, aControl, aPopulateProc);
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

class procedure TBind.Notify(aSource: TObject);
begin
  gBindingVCL.Notify(aSource);
end;

class procedure TBind.RemoveBind(aControl: TObject);
begin
  gBindingVCL.RemoveBind(aControl);
end;

class procedure TBind.SubscribeNotification(aSource: TObject; aNotifySourceType: TClass;
  const aKeyPropName: string; const aKeyPropValue: Variant);
begin
  gBindingVCL.SubscribeNotification(aSource, aNotifySourceType, aKeyPropName, aKeyPropValue);
end;

{ TBindingVCL }

procedure TBindingVCL.ApplyToComboBox(aComboBox: TComboBox;
  aBindItem: TBindItem; aRttiProperty: TRttiProperty);
var
  ControlName: string;
  i: Integer;
  Index: Integer;
  Prop: string;
  Props: TArray<string>;
  ReferObject: TObject;
  ReferProp: string;
  ReferValue: Variant;
  Value: Variant;
begin
  if not Assigned(aRttiProperty) then
  begin
    Index := aComboBox.Items.AddObject('', aBindItem.Source);
    SetLastBindedControlItemIndex(Index);
  end
  else
  begin
    ControlName := aComboBox.Name;

    if ControlName.Contains('_') then
    begin
      Props := ControlName.Split(['_']);
      Prop := Props[2];
      Value := GetRttiProperty(aBindItem.Source, Prop).GetValue(aBindItem.Source).AsVariant;

      ReferProp := Props[1];
      for i := 0 to aComboBox.Items.Count - 1 do
      begin
        ReferObject := aComboBox.Items.Objects[i];
        ReferValue := GetRttiProperty(ReferObject, ReferProp).GetValue(ReferObject).AsVariant;

        if ReferValue = Value then
        begin
          aComboBox.ItemIndex := i;
          Break;
        end;
      end
    end
    else
    begin
      Value := GetRttiProperty(aBindItem.Source, aBindItem.PropName).GetValue(aBindItem.Source).AsVariant;

      for i := 0 to aComboBox.Items.Count - 1 do
      begin
        ReferValue := Integer(aComboBox.Items.Objects[i]);

        if ReferValue = Value then
        begin
          aComboBox.ItemIndex := i;
          Break;
        end;
      end;
    end;

    SetNativeEvent(aBindItem.New, aComboBox, TMethod(aComboBox.OnCloseUp));
    aComboBox.OnCloseUp := EditOnCloseUp;
  end;
end;

procedure TBindingVCL.ApplyToControls(aBindItem: TBindItem; aRttiProperty: TRttiProperty);
var
  Control: TObject;
  Source: TObject;
begin
  Control := aBindItem.Control;
  Source := aBindItem.Source;

  if Control.InheritsFrom(TLabeledEdit) then
    ApplyToLabeledEdit(TLabeledEdit(Control), aBindItem, PropertyValToStr(aRttiProperty, Source))
  else
  if Control.InheritsFrom(TEdit) then
    ApplyToEdit(TEdit(Control), aBindItem, PropertyValToStr(aRttiProperty, Source))
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
    ApplyToComboBox(TComboBox(Control), aBindItem, aRttiProperty)
  else
  if Control.InheritsFrom(TDrawGrid) then
  else
  if Control.InheritsFrom(TDateTimePicker) then
    ApplyToDateTimePicker(TDateTimePicker(Control), aBindItem, aRttiProperty.GetValue(Source).AsExtended)
  else
    raise Exception.CreateFmt('TBindingVCL: Control class %s does not support.', [Control.ClassName]);
end;

procedure TBindingVCL.ApplyToDateTimePicker(aPicker: TDateTimePicker;
  aBindItem: TBindItem; const aValue: TDateTime);
begin
  aPicker.DateTime := aValue;

  SetNativeEvent(aBindItem.New, aPicker, TMethod(aPicker.OnChange));
  aPicker.OnChange := DateTimePickerOnChange;
end;

procedure TBindingVCL.ApplyToEdit(aEdit: TEdit; aBindItem: TBindItem;
  const aValue: string);
begin
  aEdit.Text := aValue;

  SetNativeEvent(aBindItem.New, aEdit, TMethod(aEdit.OnChange));
  aEdit.OnChange := EditOnChange;
end;

procedure TBindingVCL.ApplyToLabeledEdit(aLabeledEdit: TLabeledEdit;
  aBindItem: TBindItem; const aValue: string);
begin
  aLabeledEdit.Text := aValue;

  SetNativeEvent(aBindItem.New, aLabeledEdit, TMethod(aLabeledEdit.OnChange));
  aLabeledEdit.OnChange := EditOnChange;
end;

procedure TBindingVCL.ApplyToRichEdit(aRichEdit: TRichEdit;
  aBindItem: TBindItem; const aValue: string);
begin
  aRichEdit.Text := aValue;

  SetNativeEvent(aBindItem.New, aRichEdit, TMethod(aRichEdit.OnChange));
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
      Index := FirstDataRow
    else
    begin
      RowCount := aStringGrid.RowCount + 1;
      aStringGrid.RowCount := RowCount;
      Index := RowCount - 1;
    end;
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

procedure TBindingVCL.DateTimePickerOnChange(Sender: TObject);
var
  BindItem: TBindItem;
  Method: TMethod;
  NotifyEvent: TNotifyEvent;
  Picker: TDateTimePicker;
begin
  Picker := Sender as TDateTimePicker;
  BindItem := GetFirstBindItemHavingProp(Picker);

  SetPropValue(BindItem.Source, BindItem.PropName, Picker.DateTime);

  if TryGetNativeEvent(Picker, Method) then
  begin
    TMethod(NotifyEvent) := Method;
    NotifyEvent(Sender);
  end;
end;

procedure TBindingVCL.EditOnChange(Sender: TObject);
var
  BindItem: TBindItem;
  Edit: TCustomEdit;
  Method: TMethod;
  NotifyEvent: TNotifyEvent;
  Value: Variant;
  RttiContext: TRttiContext;
  RttiProperty: TRttiProperty;
begin
  Edit := Sender as TCustomEdit;
  BindItem := GetFirstBindItemHavingProp(Edit);

  RttiContext := TRttiContext.Create;
  try
    RttiProperty := GetRttiProperty(BindItem.Source, BindItem.PropName);
    Value := StrToPropertyVal(RttiProperty, Edit.Text);
    RttiProperty.SetValue(BindItem.Source, TValue.FromVariant(Value));
  finally
    RttiContext.Free;
  end;

  if TryGetNativeEvent(Edit, {out}Method) then
  begin
    TMethod(NotifyEvent) := Method;
    NotifyEvent(Sender);
  end;
end;

procedure TBindingVCL.EditOnCloseUp(Sender: TObject);
var
  BindItem: TBindItem;
  ComboBox: TCustomComboBox;
  Method: TMethod;
  NotifyEvent: TNotifyEvent;
  RttiContext: TRttiContext;
  RttiProperty: TRttiProperty;
begin
  ComboBox := Sender as TCustomComboBox;

  if ComboBox.ItemIndex > -1 then
  begin
    BindItem := GetFirstBindItemHavingProp(ComboBox);
    RttiContext := TRttiContext.Create;
    try
      RttiProperty := GetRttiProperty(BindItem.Source, BindItem.PropName);

      if RttiProperty.PropertyType.IsInstance then
        RttiProperty.SetValue(BindItem.Source, ComboBox.Items.Objects[ComboBox.ItemIndex])
      else
      if RttiProperty.PropertyType.IsOrdinal then
        RttiProperty.SetValue(BindItem.Source, TValue.FromOrdinal(RttiProperty.PropertyType.Handle,
          Integer(ComboBox.Items.Objects[ComboBox.ItemIndex])));
    finally
      RttiContext.Free;
    end;
  end;

  if TryGetNativeEvent(ComboBox, {out}Method) then
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
  if aControl.InheritsFrom(TWinControl) then
  begin
    if aControl.InheritsFrom(TPanel) then
      Result := False
    else
      Result := True;
    Control := aControl as TWinControl;
    aControlName := Control.Name;

    aChildControls := [];
    if Control.ControlCount > 0 then
    begin
      for i := 0 to Control.ControlCount - 1 do
        aChildControls := aChildControls + [Control.Controls[i]];
    end;
  end
  else
    Result := False;
end;

initialization
  gBindingVCL := TBindingVCL.Create;

finalization
  gBindingVCL.Free;

end.
