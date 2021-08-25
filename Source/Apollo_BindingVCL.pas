unit Apollo_Binding_VCL;

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
    function GetSourceFromStringGrid(aStringGrid: TStringGrid): TObject;
    procedure ApplyToLabeledEdit(aLabeledEdit: TLabeledEdit; aBindItem: TBindItem; const aValue: string);
    procedure ApplyToRichEdit(aRichEdit: TRichEdit; aBindItem: TBindItem; const aValue: string);
    procedure ApplyToStringGrid(aStringGrid: TStringGrid; aBindItem: TBindItem);
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
    class function GetSource<T: class>(aControl: TObject): T; static;
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

class procedure TBind.ClearControl(aControl: TObject);
var
  i: Integer;
  StringGrid: TStringGrid;
begin
  if aControl is TStringGrid then
  begin
    StringGrid := TStringGrid(aControl);
    StringGrid.RowCount := 1;
    for i := 0 to StringGrid.ColCount - 1 do
      StringGrid.Cells[i, 0] := '';
    StringGrid.Objects[0, 0] := nil;
  end
  else
    raise Exception.CreateFmt('TBind.ClearControl: Control %s is not support', [aControl.ClassName]);

  RemoveBind(aControl);
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
    raise Exception.CreateFmt('TBind.GetSource: source binded with control %s is not %s type', [aControl.ClassName, T.ClassName]);
end;

class procedure TBind.RemoveBind(aControl: TObject);
begin
  gBindingVCL.RemoveBind(aControl);
end;

{ TBindingVCL }

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
    raise Exception.CreateFmt('TBindingVCL: Control class %s does not supported', [Control.ClassName]);
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
  RowCount: Integer;
  i: Integer;
  Index: Integer;
begin
  Index := -1;
  if aBindItem.New then
  begin
    if aStringGrid.Objects[0, 0] = nil then
      RowCount := 1
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

function TBindingVCL.GetSourceFromControl(aControl: TObject): TObject;
begin
  if aControl is TStringGrid then
    Result := GetSourceFromStringGrid(TStringGrid(aControl))
  else
    raise Exception.CreateFmt('TBindingVCL.GetSourceFromControl: Control class %s does not support', [aControl.ClassName]);
end;

function TBindingVCL.GetSourceFromStringGrid(aStringGrid: TStringGrid): TObject;
begin
  Result := aStringGrid.Objects[0, aStringGrid.Row];
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
