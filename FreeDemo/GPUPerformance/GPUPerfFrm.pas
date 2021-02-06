unit GPUPerfFrm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.CheckLst, Vcl.ExtCtrls,

  System.IOUtils,

  CoreClasses, PascalStrings, UnicodeMixedLib, ListEngine, DoStatusIO, TextParsing,
  MemoryStream64, Geometry2DUnit, MemoryRaster, zAI_Common, zAI;

type
  TGPUPerfForm = class(TForm)
    Memo: TMemo;
    TestButton: TButton;
    GPUListBox: TCheckListBox;
    ThNumEdit: TLabeledEdit;
    Timer1: TTimer;
    TestResultLabel: TLabel;
    procedure TestButtonClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    procedure DoStatusMethod(Text_: SystemString; const ID: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  GPUPerfForm: TGPUPerfForm;

implementation

{$R *.dfm}


procedure TGPUPerfForm.DoStatusMethod(Text_: SystemString; const ID: Integer);
begin
  Memo.Lines.Add(Text_);
end;

constructor TGPUPerfForm.Create(AOwner: TComponent);
var
  i: Integer;
  AI: TAI;
begin
  inherited Create(AOwner);
  WorkInParallelCore.V := True;
  AddDoStatusHook(Self, DoStatusMethod);

  // ��ȡzAI������
  CheckAndReadAIConfig;
  // ��һ��������Key����������֤ZAI��Key
  // ���ӷ�������֤Key������������ʱһ���Ե���֤��ֻ�ᵱ��������ʱ�Ż���֤��������֤����ͨ����zAI����ܾ�����
  // �ڳ��������У���������TAI�����ᷢ��Զ����֤
  // ��֤��Ҫһ��userKey��ͨ��userkey�����ZAI������ʱ���ɵ����Key��userkey����ͨ��web���룬Ҳ������ϵ���߷���
  // ��֤key���ǿ����Ӽ����޷����ƽ�
  zAI.Prepare_AI_Engine();

  AI := TAI.OpenEngine;

  if AI.Activted then
    begin
      for i := 0 to AI.GetComputeDeviceNumOfProcess - 1 do
        begin
          GPUListBox.Items.Add(AI.GetComputeDeviceNameOfProcess(i));
        end;
    end;
  AI.Free;
end;

destructor TGPUPerfForm.Destroy;
begin
  DeleteDoStatusHook(Self);
  inherited Destroy;
end;

procedure TGPUPerfForm.TestButtonClick(Sender: TObject);
begin
  TCompute.RunP_NP(procedure
    var
      bear_dataset_file, bear_od_file: U_String;
      bear_ImgL: TAI_ImageList;
      Model_Mem: TMemoryStream64;
      detTarget: TRaster;
      i: Integer;
      pool: TAI_DNN_ThreadPool;
      tk: TTimeTick;
      num: Integer;
    begin
      bear_dataset_file := umlCombineFileName(TPath.GetLibraryPath, 'bear.ImgDataSet');
      bear_od_file := umlCombineFileName(TPath.GetLibraryPath, 'bear3L' + C_MMOD3L_Ext);
      if (not umlFileExists(bear_od_file)) or (not umlFileExists(bear_dataset_file)) then
          exit;

      TCompute.Sync(procedure
        begin
          TestButton.Enabled := False;
          TestResultLabel.Caption := '���Խ��: ������';
        end);

      DoStatus('���ɲ��Թ�դ');
      bear_ImgL := TAI_ImageList.Create;
      bear_ImgL.LoadFromFile(bear_dataset_file);
      while True do
        if bear_ImgL.RunScript(nil, 'width*height>200*200', 'scale(0.5)') = 0 then
            break;
      detTarget := bear_ImgL.PackingRaster;
      DoStatus('���Թ�դ�ߴ�: %d * %d', [detTarget.Width, detTarget.Height]);

      pool := TAI_DNN_ThreadPool.Create;
      DoStatus('����GPU�����');
      for i := 0 to GPUListBox.Count - 1 do
        if GPUListBox.Checked[i] then
            pool.BuildDeviceThread(i, umlStrToInt(ThNumEdit.Text), TAI_DNN_Thread_MMOD3L);

      DoStatus('����ģ��');
      Model_Mem := TMemoryStream64.Create;
      Model_Mem.LoadFromFile(bear_od_file);
      Model_Mem.Position := 0;
      for i := 0 to pool.Count - 1 do
          TAI_DNN_Thread_MMOD3L(pool[i]).Open_Stream(Model_Mem);
      pool.Wait;
      DisposeObject(Model_Mem);
      DoStatus('Ԥ��GPU�ڴ�');
      for i := 0 to pool.Count - 1 do
        begin
          TAI_DNN_Thread_MMOD3L(pool[i]).ProcessP(nil, detTarget, False, nil);
        end;
      pool.Wait;

      DoStatus('���ܹ������');
      tk := GetTimeTick();
      num := 0;
      while GetTimeTick - tk < 15000 do
        begin
          if pool.GetMinLoad_DNN_Thread_TaskNum < 100 then
              TAI_DNN_Thread_MMOD3L(pool.MinLoad_DNN_Thread).ProcessP(nil, detTarget, False,
              procedure(ThSender: TAI_DNN_Thread_MMOD3L; UserData: Pointer; Input: TMemoryRaster; output: TMMOD_Desc)
              begin
                if umlInRange(GetTimeTick - tk, 10000, 15000) then
                    atomInc(num);
              end);
        end;
      DoStatus('���Բ������,��Լ��5�����ܹ������� %d ֡���, ƽ��ÿ�� %d ֡', [num, num div 5]);
      TCompute.Sync(procedure
        begin
          TestResultLabel.Caption := PFormat('���Խ��: ��Լ��5�����ܹ������� %d ֡���, ƽ��ÿ�� %d ֡', [num, num div 5]);
        end);
      DoStatus('�������ฺ��.');
      pool.Wait;

      DoStatus('�ͷ������ڴ�.');
      DisposeObject(bear_ImgL);
      DisposeObject(detTarget);
      DoStatus('�ͷ�GPU�Դ�.');
      pool.Free;
      TCompute.Sync(procedure
        begin
          TestButton.Enabled := True;
        end);
    end);
end;

procedure TGPUPerfForm.Timer1Timer(Sender: TObject);
begin
  DoStatus();
  CheckThreadSynchronize;
end;

end.
