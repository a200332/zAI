program GPUPerf;

uses
  Vcl.Forms,
  GPUPerfFrm in 'GPUPerfFrm.pas' {GPUPerfForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TGPUPerfForm, GPUPerfForm);
  Application.Run;
end.
