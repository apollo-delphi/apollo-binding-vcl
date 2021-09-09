program Apollo_BindingVCL_Test;

{$STRONGLINKTYPES ON}

{$DEFINE UseVCL}
{DEFINE UseFMX}

uses
  {$IFDEF UseVCL}
  VCL.Forms,
  DUnitX.Loggers.GUI.VCL,
  {$ENDIF }
  {$IFDEF UseFMX}
  FMX.Forms,
  {$ENDIF }
  System.SysUtils,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  tstApollo_BindingVCL in 'tstApollo_BindingVCL.pas',
  Apollo_BindingVCL in 'Apollo_BindingVCL.pas',
  Apollo_Binding_Core in '..\Vendors\Apollo_Binding_Core\Apollo_Binding_Core.pas',
  Apollo_Types in '..\Vendors\Apollo_Types\Apollo_Types.pas';

begin
  Application.Initialize;
  Application.Title := 'DUnitX';
  {$IFDEF UseFMX}
  Application.CreateForm(TGUIXTestRunner, GUIXTestRunner);
  {$ENDIF}
  {$IFDEF UseVCL}
  Application.CreateForm(TGUIVCLTestRunner, GUIVCLTestRunner);
  {$ENDIF}
  Application.Run;
end.
