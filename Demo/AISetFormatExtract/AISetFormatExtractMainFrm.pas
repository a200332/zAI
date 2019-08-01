unit AISetFormatExtractMainFrm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,

  System.Threading,

  System.IOUtils,

  CoreClasses, ListEngine,
  Learn, LearnTypes,
  zAI_Common, zAI_Editor_Common,
  zDrawEngineInterface_SlowFMX, zDrawEngine, Geometry2DUnit, Geometry3DUnit, MemoryRaster,
  MemoryStream64, PascalStrings, UnicodeMixedLib, DoStatusIO;

type
  TAISetFormatExtractMainForm = class(TForm)
    Memo1: TMemo;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
    procedure DoStatusMethod(AText: SystemString; const ID: Integer);
  public
    { Public declarations }
  end;

var
  AISetFormatExtractMainForm: TAISetFormatExtractMainForm;

implementation

{$R *.fmx}


procedure TAISetFormatExtractMainForm.DoStatusMethod(AText: SystemString; const ID: Integer);
begin
  Memo1.Lines.Add(AText);
  Memo1.GoToTextEnd;
end;

procedure TAISetFormatExtractMainForm.FormCreate(Sender: TObject);
begin
  AddDoStatusHook(Self, DoStatusMethod);
  TComputeThread.RunP(nil, nil, procedure(SenderTh: TComputeThread)
    var
      fn: U_String;
      i, j: Integer;
      editor_dataset: TEditorImageDataList;
      editor_ImgData: TEditorImageData;
      editor_ImgData_raster: TMemoryRaster;
      editor_ImgData_Det: TEditorDetectorDefine;
      editor_ImgData_Geo: TEditorGeometry;
      editor_ImgData_SegMask: TEditorSegmentationMask;
    begin
      // .AI_Set �Ǳ༭����ԭʼ����
      editor_dataset := TEditorImageDataList.Create(True);
      fn.Text := umlCombineFileName(TPath.GetLibraryPath, 'demoDataset.AI_Set');
      DoStatus('load .AI_Set file: %s', [fn.Text]);
      editor_dataset.LoadFromFile(fn);
      DoStatus('load done.', []);

      for i := 0 to editor_dataset.Count - 1 do
        begin
          // �ڱ༭���� editor_ImgData ÿ��ͼƬ������
          // ����:ͼ���դ��������������Χ+���ݼ���������ͼ��ָ��դ����
          editor_ImgData := editor_dataset[i];

          DoStatus('');

          DoStatus('���ڽ��� %s �е�����', [editor_ImgData.FileName]);

          // ԭʼ��դ����
          editor_ImgData_raster := editor_ImgData.Raster;
          DoStatus(' %s ԭʼ�Ĺ�դ�ߴ� %d * %d', [editor_ImgData.FileName, editor_ImgData_raster.Width, editor_ImgData_raster.Height]);

          for j := 0 to editor_ImgData.DetectorDefineList.Count - 1 do
            begin
              // editor_ImgData_Det�����Ǽ�������嶨���ShapePredictor����
              editor_ImgData_Det := editor_ImgData.DetectorDefineList[j];
              DoStatus(' %s �еļ��������%d: %d %d %d %d shapePredictor������ %d ��', [editor_ImgData.FileName, j,
                editor_ImgData_Det.R.Left, editor_ImgData_Det.R.Top,
                editor_ImgData_Det.R.Right, editor_ImgData_Det.R.Bottom, editor_ImgData_Det.Part.Count]);
            end;

          for j := 0 to editor_ImgData.GeometryList.Count - 1 do
            begin
              // editor_ImgData_Geo���������ڼ��������Ķ��������
              // ��������ԭ������Geometry2DUnit�е�T2DPolygonGraph
              // T2DPolygonGraph��һ����Χ����κ�n�����ݶ���ι�ͬ���
              editor_ImgData_Geo := editor_ImgData.GeometryList[j];
              DoStatus(' %s �еļ��������� %s �� %d ������ ', [editor_ImgData.FileName, editor_ImgData_Geo.Token, editor_ImgData_Geo.CollapsesCount]);
            end;

          for j := 0 to editor_ImgData.SegmentationMaskList.Count - 1 do
            begin
              // editor_ImgData_SegMask ����������ͼ������ָ�������ɰ�
              // ��Щ�ɰ�����Ƕ�����ϵ���������壬Ҳ�����ǵ�����������壬���ǵ��������úͼ����������һ��
              editor_ImgData_SegMask := editor_ImgData.SegmentationMaskList[j];
              DoStatus(' %s ����һ���� %s �ķָ��ɰ��������� ', [editor_ImgData.FileName, editor_ImgData_SegMask.Token]);
            end;

          // �������ǿ�ʼ�ع�һ�����ݽṹ
          // ���ǵ�Ŀ�ģ�ɾ���������ݣ�Ȼ����ͼ������ָ�������ɰ����������ݣ�Ȼ���ٸɵ���������ָ����ݣ�ֻ�����µĿ���

          // ��һ����ɾ���������ݣ�ֻ���� ͼ������ָ�������ɰ�����
          // �༭�������ݽṹ��Ҫȫ���ֶ��ͷ�
          for j := 0 to editor_ImgData.DetectorDefineList.Count - 1 do
            begin
              editor_ImgData_Det := editor_ImgData.DetectorDefineList[j];
              DisposeObject(editor_ImgData_Det);
            end;
          editor_ImgData.DetectorDefineList.Clear;
          for j := 0 to editor_ImgData.GeometryList.Count - 1 do
            begin
              editor_ImgData_Geo := editor_ImgData.GeometryList[j];
              DisposeObject(editor_ImgData_Geo);
            end;
          editor_ImgData.GeometryList.Clear;
          // ��һ�����Ƴ������ɼ��������Ķ�������ݲ���������ָ��ɰ棬���������������о�Դ��
          editor_ImgData.SegmentationMaskList.RemoveGeometrySegmentationMask;

          // �ڶ�������ͼ������ָ�������ɰ�����������
          for j := 0 to editor_ImgData.SegmentationMaskList.Count - 1 do
            begin
              editor_ImgData_SegMask := editor_ImgData.SegmentationMaskList[j];
              // �����µĿ������ݽṹ
              editor_ImgData_Det := TEditorDetectorDefine.Create(editor_ImgData);
              // ���¼��������ɰ�FGColor�����ذ�Χ��
              editor_ImgData_Det.R := editor_ImgData_SegMask.Raster.ColorBoundsRect(editor_ImgData_SegMask.FGColor);
              editor_ImgData_Det.Token := editor_ImgData_SegMask.Token;
              editor_ImgData.DetectorDefineList.Add(editor_ImgData_Det);
            end;

          // �ѵ�һ��ûɾ���ɾ���β�ʹ�����
          // ��һ������Ժ���������ֻ��ʣ�����Ǹղ����������ļ��������
          for j := 0 to editor_ImgData.SegmentationMaskList.Count - 1 do
            begin
              editor_ImgData_SegMask := editor_ImgData.SegmentationMaskList[j];
              DisposeObject(editor_ImgData_SegMask);
            end;
          editor_ImgData.SegmentationMaskList.Clear;
        end;

      DoStatus('all done.');

      // ���ڣ����ǰ��ؽ����.ai_set�������һ���ļ���Ȼ���ñ༭��������
      // �����Ǳ��������õ�������������������������������ģ��ǰ�ù������κ�ģ�Ͷ���Ҫ����������
      // �������������Ĺ����У������ڴ�й©����Щ��������ν�ģ�ֻҪ����û�������ܱ�֤����������.AI_Set���Ա���ģ���ߴ򿪾Ϳ�����
      // ʣ�µ�����ģ��ѵ�������ڲ�����Ӳ�����ܣ���ο����demo
      fn.Text := umlCombineFileName(TPath.GetLibraryPath, 'demoDataset_rebuild_output.AI_Set');
      DoStatus('rebuild output to: %s', [fn.Text]);
      editor_dataset.SaveToFile(fn);

      DisposeObject(editor_dataset);
    end);
end;

procedure TAISetFormatExtractMainForm.Timer1Timer(Sender: TObject);
begin
  DoStatus;
end;

end.