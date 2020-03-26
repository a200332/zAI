program sigmaGaussian;

uses
  System.StartUpCopy,
  FMX.Forms,
  SigmaGaussianMainFrm in 'SigmaGaussianMainFrm.pas' {SigmaGaussianMainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TSigmaGaussianMainForm, SigmaGaussianMainForm);
  Application.Run;
end.
