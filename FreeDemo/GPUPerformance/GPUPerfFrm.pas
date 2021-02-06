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

  // 读取zAI的配置
  CheckAndReadAIConfig;
  // 这一步会连接Key服务器，验证ZAI的Key
  // 连接服务器验证Key是在启动引擎时一次性的验证，只会当程序启动时才会验证，假如验证不能通过，zAI将会拒绝工作
  // 在程序运行中，反复创建TAI，不会发生远程验证
  // 验证需要一个userKey，通过userkey推算出ZAI在启动时生成的随机Key，userkey可以通过web申请，也可以联系作者发放
  // 验证key都是抗量子级，无法被破解
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
          TestResultLabel.Caption := '测试结果: 运行中';
        end);

      DoStatus('生成测试光栅');
      bear_ImgL := TAI_ImageList.Create;
      bear_ImgL.LoadFromFile(bear_dataset_file);
      while True do
        if bear_ImgL.RunScript(nil, 'width*height>200*200', 'scale(0.5)') = 0 then
            break;
      detTarget := bear_ImgL.PackingRaster;
      DoStatus('测试光栅尺寸: %d * %d', [detTarget.Width, detTarget.Height]);

      pool := TAI_DNN_ThreadPool.Create;
      DoStatus('构建GPU计算池');
      for i := 0 to GPUListBox.Count - 1 do
        if GPUListBox.Checked[i] then
            pool.BuildDeviceThread(i, umlStrToInt(ThNumEdit.Text), TAI_DNN_Thread_MMOD3L);

      DoStatus('载入模型');
      Model_Mem := TMemoryStream64.Create;
      Model_Mem.LoadFromFile(bear_od_file);
      Model_Mem.Position := 0;
      for i := 0 to pool.Count - 1 do
          TAI_DNN_Thread_MMOD3L(pool[i]).Open_Stream(Model_Mem);
      pool.Wait;
      DisposeObject(Model_Mem);
      DoStatus('预置GPU内存');
      for i := 0 to pool.Count - 1 do
        begin
          TAI_DNN_Thread_MMOD3L(pool[i]).ProcessP(nil, detTarget, False, nil);
        end;
      pool.Wait;

      DoStatus('性能估算测试');
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
      DoStatus('测试测试完成,大约在5秒内总共处理了 %d 帧检测, 平均每秒 %d 帧', [num, num div 5]);
      TCompute.Sync(procedure
        begin
          TestResultLabel.Caption := PFormat('测试结果: 大约在5秒内总共处理了 %d 帧检测, 平均每秒 %d 帧', [num, num div 5]);
        end);
      DoStatus('回收冗余负载.');
      pool.Wait;

      DoStatus('释放物理内存.');
      DisposeObject(bear_ImgL);
      DisposeObject(detTarget);
      DoStatus('释放GPU显存.');
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
