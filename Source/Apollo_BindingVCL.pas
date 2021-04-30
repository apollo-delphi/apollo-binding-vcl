unit Apollo_BindingVCL;

interface

uses
  Apollo_Binding_Core,
  System.Classes,
  System.Rtti,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls;

type
  TBindingVCL = class(TBindingEngine)
  private
    procedure EditOnChange(Sender: TObject);
    procedure SetToEdit(aEdit: TEdit; const aValue: string; var aBindItem: TBindItem);
    procedure SetToLabeledEdit(aLabeledEdit: TLabeledEdit; const aValue: string; var aBindItem: TBindItem);
  protected
    procedure BindPropertyToControl(aSource: TObject; aRttiProperty: TRttiProperty; aControl: TComponent); override;
    procedure DoBind(aSource: TObject; aControl: TComponent; const aControlNamePrefix: string;
      aRttiProperties: TArray<TRttiProperty>); override;
  end;

  TBind = class
  public
    class function GetBindItem(aControl: TControl; const aIndex: Integer = 0): TBindItem;
    class function GetSource<T: class>(aControl: TControl; const aIndex: Integer = 0): T;
    class procedure Bind(aSource: TObject; aRootControl: TWinControl; const aControlNamePrefix: string = '');
    class procedure Notify(aSource: TObject);
    class procedure SingleBind(aSource: TObject; aControl: TControl; const aIndex: Integer = 0);
  end;

var
  gBindingVCL: TBindingVCL;

implementation

uses
  System.SysUtils,
  System.TypInfo;

{ TBind }

class procedure TBind.Bind(aSource: TObject; aRootControl: TWinControl;
  const aControlNamePrefix: string);
begin
  gBindingVCL.Bind(aSource, aRootControl, aControlNamePrefix);
end;

class function TBind.GetBindItem(aControl: TControl; const aIndex: Integer): TBindItem;
begin
  Result := gBindingVCL.GetBindItem(aControl, aIndex);
end;

class function TBind.GetSource<T>(aControl: TControl; const aIndex: Integer): T;
begin
  Result := GetBindItem(aControl, aIndex).Source as T;
end;

class procedure TBind.Notify(aSource: TObject);
begin
  gBindingVCL.Notify(aSource);
end;

class procedure TBind.SingleBind(aSource: TObject; aControl: TControl; const aIndex: Integer);
begin
  gBindingVCL.SingleBind(aSource, aControl, aIndex);
end;

{ TBindingVCL }

procedure TBindingVCL.BindPropertyToControl(aSource: TObject;
  aRttiProperty: TRttiProperty; aControl: TComponent);
var
  BindItem: TBindItem;
begin
  BindItem := AddBindItem(aSource, aRttiProperty.Name, aControl, 0);

  if aControl is TEdit then
    SetToEdit(TEdit(aControl), aRttiProperty.GetValue(aSource).AsString, BindItem)
  else
  if aControl is TLabeledEdit then
    SetToLabeledEdit(TLabeledEdit(aControl), aRttiProperty.GetValue(aSource).AsString, BindItem)
  else
    raise Exception.CreateFmt('TBindingVCL: Control class %s does not supported', [aControl.ClassName]);
end;

procedure TBindingVCL.DoBind(aSource: TObject; aControl: TComponent;
  const aControlNamePrefix: string; aRttiProperties: TArray<TRttiProperty>);
var
  ChildControl: TControl;
  Control: TWinControl;
  i: Integer;
  RttiProperty: TRttiProperty;
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
    if Assigned(RttiProperty) then
      BindPropertyToControl(aSource, RttiProperty, ChildControl);
  end;
end;

procedure TBindingVCL.EditOnChange(Sender: TObject);
var
  BindItem: TBindItem;
  Edit: TCustomEdit;
begin
  Edit := Sender as TCustomEdit;
  BindItem := GetBindItem(Edit);

  SetPropValue(BindItem.Source, BindItem.PropName, Edit.Text);

  if Assigned(BindItem.NativeEvent) then
    BindItem.NativeEvent(Sender);
end;

procedure TBindingVCL.SetToEdit(aEdit: TEdit; const aValue: string; var aBindItem: TBindItem);
begin
  aEdit.Text := aValue;

  if Assigned(aEdit.OnChange) then
    aBindItem.NativeEvent := aEdit.OnChange;

  aEdit.OnChange := EditOnChange;
end;

procedure TBindingVCL.SetToLabeledEdit(aLabeledEdit: TLabeledEdit;
  const aValue: string; var aBindItem: TBindItem);
begin
  aLabeledEdit.Text := aValue;

  if Assigned(aLabeledEdit.OnChange) then
    aBindItem.NativeEvent := aLabeledEdit.OnChange;

  aLabeledEdit.OnChange := EditOnChange;
end;

initialization
  gBindingVCL := TBindingVCL.Create;

finalization
  gBindingVCL.Free;

end.
