unit DNN_Dog_MainFrm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects,
  FMX.ScrollBox, FMX.Memo, FMX.Edit, FMX.Layouts,
  FMX.ListBox,
  System.IOUtils,

  Winapi.ShellApi, Winapi.Windows,

  CoreClasses, PascalStrings, UnicodeMixedLib, Geometry2DUnit, Geometry3DUnit,
  MemoryRaster, MemoryStream64, DoStatusIO, zDrawEngine,
  zExpression,
  zDrawEngineInterface_FMX,
  zAI, zAI_Common, zAI_TrainingTask, zAI_Editor_Common,
  Learn, LearnTypes,
  PictureViewerInterface;

type
  TDNN_Dog_MainForm = class(TForm)
    Timer1: TTimer;
    Layout1: TLayout;
    Memo: TMemo;
    Layout2: TLayout;
    pb: TPaintBox;
    ListBox: TListBox;
    DogDetectorButton: TButton;
    Splitter1: TSplitter;
    MetricButton: TButton;
    OpenEditorForDogDetectorButton: TButton;
    OpenEditorForDogMetricButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure DogDetectorButtonClick(Sender: TObject);
    procedure MetricButtonClick(Sender: TObject);
    procedure OpenEditorForDogDetectorButtonClick(Sender: TObject);
    procedure OpenEditorForDogMetricButtonClick(Sender: TObject);
    procedure pbMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure pbMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure pbMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure pbMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
    procedure pbPaint(Sender: TObject; Canvas: TCanvas);
    procedure Timer1Timer(Sender: TObject);
  private
    dIntf: TDrawEngineInterface_FMX;
    viewIntf: TPictureViewerInterface;
    AI: TAI;
    OD_Hnd: TMMOD6L_Handle;
    Metric_Hnd: TMetric_Handle;
    Metric_Learn: TLearn;
    imgList: TAI_ImageList;
    procedure DoStatusMethod(Text_: SystemString; const ID: Integer);
    procedure ItemClick(Sender: TObject);
  public
  end;

var
  DNN_Dog_MainForm: TDNN_Dog_MainForm;

implementation

{$R *.fmx}


uses StyleModuleUnit;

procedure TDNN_Dog_MainForm.FormCreate(Sender: TObject);
begin
  AddDoStatusHook(Self, DoStatusMethod);
  dIntf := TDrawEngineInterface_FMX.Create;
  ReadAIConfig();
  AI := TAI.OpenEngine();

  viewIntf := TPictureViewerInterface.Create(DrawPool(pb));
  viewIntf.ShowHistogramInfo := False;
  viewIntf.ShowPixelInfo := True;
  viewIntf.ShowPictureInfo := True;
  viewIntf.ShowBackground := True;
  viewIntf.PictureViewerStyle := pvsLeft2Right;
  viewIntf.ShowPictureInfoFontSize := 12;

  TCompute.RunP_NP(procedure
    var
      stream: TMemoryStream64;
      EditImgList: TEditorImageDataList;
      i, j: Integer;
      img: TAI_Image;
      det: TAI_DetectorDefine;
    begin
      // 使用TTrainingTask打开模型训练后的输出数据
      with TAI_TrainingTask.OpenMemoryTask(WhereFileFromConfigure('dog_train_output_detector.OX')) do
        begin
          stream := TMemoryStream64.Create;
          // 从训练输出结果读取小狗检测器模型
          Read('output.svm_dnn_od', stream);
          TCompute.Sync(procedure
            begin
              OD_Hnd := AI.MMOD6L_DNN_Open_Stream(stream);
            end);
          DisposeObject(stream);
          DoStatus('load dog detector done..');
          Free;
        end;

      // 使用TTrainingTask打开模型训练后的输出数据
      with TAI_TrainingTask.OpenMemoryTask(WhereFileFromConfigure('dog_train_output_metric.OX')) do
        begin
          stream := TMemoryStream64.Create;
          // 从训练输出结果读取小狗度量化模型
          Read('output.metric', stream);
          TCompute.Sync(procedure
            begin
              Metric_Hnd := AI.Metric_ResNet_Open_Stream(stream);
            end);
          DisposeObject(stream);
          DoStatus('load dog metric done..');

          // 从训练输出结果读取小狗度量化的kdtree模型
          stream := TMemoryStream64.Create;
          Read('output.learn', stream);
          Metric_Learn := TLearn.CreateClassifier(ltKDT, zAI.C_Metric_Dim);
          Metric_Learn.LoadFromStream(stream);
          DoStatus('load kdtree from learn');
          Metric_Learn.Training();
          DoStatus('training kdtree.');
          DisposeObject(stream);
          Free;
        end;

      // 读取编辑器样本
      EditImgList := TEditorImageDataList.Create(True);
      EditImgList.LoadFromFile(WhereFileFromConfigure('dog_metric.AI_Set'));
      DoStatus('load Editor Dataset done.');
      stream := TMemoryStream64.Create;
      // 将编辑器样本转换成TAI_ImageList
      EditImgList.SaveToStream_AI(stream, TRasterSaveFormat.rsRGB);
      DisposeObject(EditImgList);
      DoStatus('Editor Dataset export done.');

      stream.Position := 0;
      imgList := TAI_ImageList.Create;
      // 读取TAI_ImageList数据
      imgList.LoadFromStream(stream);
      DisposeObject(stream);
      DoStatus('ImageList load done.');

      // 将TAI_ImageList数据添加到Listbox
      for j := 0 to imgList.Count - 1 do
        begin
          img := imgList[j];
          for i := 0 to img.DetectorDefineList.Count - 1 do
            begin
              det := img.DetectorDefineList[i];
              TCompute.Sync(procedure
                var
                  LItem: TListBoxItem;
                begin
                  LItem := TListBoxItem.Create(ListBox);
                  LItem.TagObject := det;
                  LItem.Text := Format('%d %s', [ListBox.Count + 1, det.Token.Text]);
                  LItem.Height := 20;
                  LItem.OnClick := ItemClick;
                  ListBox.AddObject(LItem);
                end);
            end;
        end;
      DoStatus('update list done.');
    end);
end;

procedure TDNN_Dog_MainForm.DogDetectorButtonClick(Sender: TObject);
var
  desc: TMMOD_Desc;
  raster: TMemoryRaster;
  d: TDrawEngine;
  i: Integer;
  tmp: TMemoryRaster;
  vec: TLVec;
begin
  if viewIntf.Count < 2 then
      exit;
  while viewIntf.Count > 2 do
      viewIntf.Delete(2);
  // 执行检测器
  desc := AI.MMOD6L_DNN_Process(OD_Hnd, viewIntf[0].raster);

  // 如果找到小狗
  if length(desc) > 0 then
    begin
      DoStatus('found dog of %d', [length(desc)]);
      raster := viewIntf[0].raster.clone;

      d := TDrawEngine.Create;
      d.Options := [];
      d.Rasterization.SetWorkMemory(raster);
      d.Rasterization.UsedAgg := True;
      for i := 0 to length(desc) - 1 do
        begin
          // 按尺度抠图
          tmp := viewIntf[0].raster.BuildAreaOffsetScaleSpace(desc[i].R, zAI.C_Metric_Input_Size, zAI.C_Metric_Input_Size);
          // 计算抠图的度量化
          vec := AI.Metric_ResNet_Process(Metric_Hnd, tmp);
          DisposeObject(tmp);
          // 把找到小狗的框体画出来
          d.DrawLabelBox(
            Metric_Learn.ProcessMaxIndexToken(vec), // 从kdtree查询度量化标签
          12, DEColor(0.5, 0.5, 1), desc[i].R, DEColor(1, 1, 1), 2);
        end;
      d.Flush;
      DisposeObject(d);
      viewIntf.InputPicture(raster, '', True, False, True);
      viewIntf.ComputeDrawBox;
      viewIntf.Fit(viewIntf.Last.DrawBox);
    end
  else
      DoStatus('no found.');
end;

procedure TDNN_Dog_MainForm.MetricButtonClick(Sender: TObject);
var
  vec: TLVec;
  raster: TMemoryRaster;
begin
  if viewIntf.Count < 2 then
      exit;
  // 小狗旁边有个尺度规范的图,我们不检测小狗,直接从该图计算度量化
  vec := AI.Metric_ResNet_Process(Metric_Hnd, viewIntf[1].raster);
  // 从learn查询度量化标签,并打印出来
  DoStatus(Metric_Learn.ProcessMaxIndexToken(vec));
end;

procedure TDNN_Dog_MainForm.pbMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  viewIntf.TapDown(vec2(X, Y));
end;

procedure TDNN_Dog_MainForm.pbMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  viewIntf.TapMove(vec2(X, Y));
end;

procedure TDNN_Dog_MainForm.pbMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  viewIntf.TapUp(vec2(X, Y));
end;

procedure TDNN_Dog_MainForm.pbMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  Handled := True;
  if WheelDelta > 0 then
      viewIntf.ScaleCamera(1.1)
  else
      viewIntf.ScaleCamera(0.9);
end;

procedure TDNN_Dog_MainForm.pbPaint(Sender: TObject; Canvas: TCanvas);
var
  d: TDrawEngine;
begin
  dIntf.SetSurface(Canvas, Sender);
  d := DrawPool(Sender, dIntf);
  viewIntf.DrawEng := d;
  viewIntf.Render;
end;

procedure TDNN_Dog_MainForm.Timer1Timer(Sender: TObject);
begin
  EnginePool.Progress();
  DoStatus;
  Invalidate;
end;

procedure TDNN_Dog_MainForm.DoStatusMethod(Text_: SystemString; const ID: Integer);
begin
  Memo.Lines.Add(Text_);
  Memo.GoToTextEnd;
end;

procedure TDNN_Dog_MainForm.ItemClick(Sender: TObject);
var
  det: TAI_DetectorDefine;
  scaleSpace_raster: TMemoryRaster;
begin
  viewIntf.Clear;
  det := TAI_DetectorDefine(TListBoxItem(Sender).TagObject);
  viewIntf.InputPicture(det.Owner.raster, '该图用于检测器计算' + #13#10 + '点|color(1,0,0)|Run Detector||时计算此图', True, False, False);
  scaleSpace_raster := det.Owner.raster.BuildAreaOffsetScaleSpace(det.R, zAI.C_Metric_Input_Size, zAI.C_Metric_Input_Size);
  viewIntf.InputPicture(scaleSpace_raster, '该图用于度量计算)' + #13#10 + '点|color(1,0,0)|Run Metric||时计算此图', True, False, True);
end;

procedure TDNN_Dog_MainForm.OpenEditorForDogDetectorButtonClick(Sender: TObject);
begin
  ShellExecute(0, 'Open',
    PWideChar(AI_ModelTool.Text),
    PWideChar(WhereFileFromConfigure('dog_detector.AI_Set').Text),
    PWideChar(umlGetFilePath(AI_ModelTool).Text),
    SW_SHOW);
end;

procedure TDNN_Dog_MainForm.OpenEditorForDogMetricButtonClick(Sender: TObject);
begin
  ShellExecute(0, 'Open',
    PWideChar(AI_ModelTool.Text),
    PWideChar(WhereFileFromConfigure('dog_metric.AI_Set').Text),
    PWideChar(umlGetFilePath(AI_ModelTool).Text),
    SW_SHOW);
end;

end.
