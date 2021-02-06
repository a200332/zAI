unit ODDemoFrm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Controls.Presentation,
  FMX.StdCtrls, FMX.Objects, FMX.ScrollBox, FMX.Memo,

  CoreClasses, PascalStrings, DoStatusIO,
  zAI, zAI_Common, zDrawEngineInterface_SlowFMX, zDrawEngine, MemoryRaster;

type
  TODDemoForm = class(TForm)
    Image1: TImage;
    Button1: TButton;
    Image2: TImage;
    Button2: TButton;
    Button3: TButton;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    procedure DoStatusMethod(Text_: SystemString; const ID: Integer);
  public
    { Public declarations }
    bk1, bk2: TMemoryRaster;
    procedure OD_Marshal(bitmap: TBitmap);
    procedure OD_Bear(bitmap: TBitmap);
    procedure OD_Dog(bitmap: TBitmap);
  end;

var
  ODDemoForm: TODDemoForm;

implementation

{$R *.fmx}


procedure TODDemoForm.Button1Click(Sender: TObject);
begin
  MemoryBitmapToBitmap(bk1, Image1.bitmap);
  MemoryBitmapToBitmap(bk2, Image2.bitmap);

  OD_Marshal(Image1.bitmap);
  OD_Marshal(Image2.bitmap);
end;

procedure TODDemoForm.Button2Click(Sender: TObject);
begin
  MemoryBitmapToBitmap(bk1, Image1.bitmap);
  MemoryBitmapToBitmap(bk2, Image2.bitmap);

  OD_Bear(Image1.bitmap);
  OD_Bear(Image2.bitmap);
end;

procedure TODDemoForm.Button3Click(Sender: TObject);
begin
  MemoryBitmapToBitmap(bk1, Image1.bitmap);
  MemoryBitmapToBitmap(bk2, Image2.bitmap);

  OD_Dog(Image1.bitmap);
  OD_Dog(Image2.bitmap);
end;

procedure TODDemoForm.DoStatusMethod(Text_: SystemString; const ID: Integer);
begin
  Memo1.Lines.Add(Text_);
  Memo1.GoToTextEnd;
end;

procedure TODDemoForm.FormCreate(Sender: TObject);
begin
  AddDoStatusHook(Self, DoStatusMethod);

  // ��ȡzAI������
  ReadAIConfig;
  // ��һ��������Key����������֤ZAI��Key
  // ���ӷ�������֤Key������������ʱһ���Ե���֤��ֻ�ᵱ��������ʱ�Ż���֤��������֤����ͨ����zAI����ܾ�����
  // �ڳ��������У���������TAI�����ᷢ��Զ����֤
  // ��֤��Ҫһ��userKey��ͨ��userkey�����ZAI������ʱ���ɵ����Key��userkey����ͨ��web���룬Ҳ������ϵ���߷���
  // ��֤key���ǿ����Ӽ����޷����ƽ�
  zAI.Prepare_AI_Engine();

  bk1 := NewRaster();
  BitmapToMemoryBitmap(Image1.bitmap, bk1);
  bk2 := NewRaster();
  BitmapToMemoryBitmap(Image2.bitmap, bk2);
end;

procedure TODDemoForm.OD_Marshal(bitmap: TBitmap);
var
  ai: TAI;
  odm: TOD6L_Marshal_Handle;
  raster: TMemoryRaster;
begin
  // TAI.OpenEngine����ʾ������AI.conf�����ļ���ָ����AI����
  ai := TAI.OpenEngine;

  // .svm_od_marshal�Ƕ����⼯����չ��
  // .svm_od_marshal����ʹ��PackageTool�򿪱༭�������汣�����ʵ������svm_od�ļ���OD_Marshal���Բ��з�ʽ���
  odm := ai.OD6L_Marshal_Open_Stream('bear.svm_od_marshal');

  // ������դʵ��
  raster := NewRaster();
  // ��fmx��ͼƬת���ɹ�դ��ʽ
  BitmapToMemoryBitmap(bitmap, raster);

  // bear.svm_od_marshal����Ը���ͼƬѵ���ģ�����ߴ粻�������ʶ��ļ��ʽ��ή��
  // �������ǰѳߴ����
  // raster.Scale(2.0);

  // �����������raster��
  ai.DrawODM(odm, raster, DEColor(0, 0, 1, 0.9));

  // �رն����⼯�ľ��
  ai.OD6L_Marshal_Close(odm);

  // ����դʵ��ת����fmx��ʽ��ͼƬ������ʾ
  MemoryBitmapToBitmap(raster, bitmap);

  // �ͷ�ai����
  disposeObject(ai);
end;

procedure TODDemoForm.OD_Bear(bitmap: TBitmap);
var
  ai: TAI;
  od: TOD6L_Handle;
  raster: TMemoryRaster;
begin
  // TAI.OpenEngine����ʾ������AI.conf�����ļ���ָ����AI����
  ai := TAI.OpenEngine;

  // .svm_od��ѵ���õĶ��������ݼ���չ��
  od := ai.OD6L_Open_Stream('bear.svm_od');

  // ������դʵ��
  raster := NewRaster();
  // ��fmx��ͼƬת���ɹ�դ��ʽ
  BitmapToMemoryBitmap(bitmap, raster);

  // bear.svm_od����Ը���ͼƬѵ���ģ�����ߴ粻�������ʶ��ļ��ʽ��ή��
  // �������ǰѳߴ����
  // raster.Scale(2.0);

  // �����������raster��
  ai.DrawOD6L(od, raster, DEColor(0, 0, 1, 0.9));

  // �رն����⼯�ľ��
  ai.OD6L_Close(od);

  // ����դʵ��ת����fmx��ʽ��ͼƬ������ʾ
  MemoryBitmapToBitmap(raster, bitmap);

  // �ͷ�ai����
  disposeObject(ai);
end;

procedure TODDemoForm.OD_Dog(bitmap: TBitmap);
var
  ai: TAI;
  od: TOD6L_Handle;
  raster: TMemoryRaster;
begin
  // TAI.OpenEngine����ʾ������AI.conf�����ļ���ָ����AI����
  ai := TAI.OpenEngine;

  // .svm_od��ѵ���õĶ��������ݼ���չ��
  od := ai.OD6L_Open_Stream('dog.svm_od');

  // ������դʵ��
  raster := NewRaster();
  // ��fmx��ͼƬת���ɹ�դ��ʽ
  BitmapToMemoryBitmap(bitmap, raster);

  // dog.svm_od����Ը���ͼƬѵ���ģ�����ߴ粻�������ʶ��ļ��ʽ��ή��
  // �������ǰѳߴ����
  // raster.Scale(2.0);

  // �����������raster��
  ai.DrawOD6L(od, raster, DEColor(0, 0, 1, 0.9));

  // �رն����⼯�ľ��
  ai.OD6L_Close(od);

  // ����դʵ��ת����fmx��ʽ��ͼƬ������ʾ
  MemoryBitmapToBitmap(raster, bitmap);

  // �ͷ�ai����
  disposeObject(ai);
end;

end.
