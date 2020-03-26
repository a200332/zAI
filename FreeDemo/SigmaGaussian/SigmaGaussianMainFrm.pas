﻿unit SigmaGaussianMainFrm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Objects, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,
  FMX.StdCtrls,

  CoreClasses,
  PascalStrings,
  UnicodeMixedLib,
  DoStatusIO,
  Geometry2DUnit,
  MemoryRaster,
  zDrawEngine,
  zDrawEngineInterface_SlowFMX,
  FastHistogramSpace;

type
  TSigmaGaussianMainForm = class(TForm)
    Memo: TMemo;
    oriImage: TImage;
    dstImage: TImage;
    sigmaGaussianButton: TButton;
    fastBlurButton: TButton;
    gaussianButton: TButton;
    grayGaussianButton: TButton;
    ShowGradientHistogramCheckBox: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure sigmaGaussianButtonClick(Sender: TObject);
    procedure fastBlurButtonClick(Sender: TObject);
    procedure gaussianButtonClick(Sender: TObject);
    procedure grayGaussianButtonClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  SigmaGaussianMainForm: TSigmaGaussianMainForm;
  tab: THOGTable;

procedure BuildHOG(mr: TMemoryRaster);

implementation

{$R *.fmx}


procedure BuildHOG(mr: TMemoryRaster);
var
  HOG: THOG;
begin
  HOG := THOG.Create(tab, mr);
  HOG.BuildViewer(mr);
  DisposeObject(HOG);
end;

procedure TSigmaGaussianMainForm.FormCreate(Sender: TObject);
begin
  tab := THOGTable.Create(36, 72, 16);
end;

procedure TSigmaGaussianMainForm.sigmaGaussianButtonClick(Sender: TObject);
var
  mr: TMemoryRaster;
  tk: TTimeTick;
begin
  mr := NewRaster;
  BitmapToMemoryBitmap(oriImage.Bitmap, mr);
  tk := GetTimeTick;
  mr.SigmaGaussian(5.0, 3);
  mr.DrawText(Format('%dms', [(GetTimeTick - tk)]), 0, 0, 16, RColorF(1, 1, 1, 1));
  if ShowGradientHistogramCheckBox.IsChecked then
      BuildHOG(mr);
  MemoryBitmapToBitmap(mr, dstImage.Bitmap);
  DisposeObject(mr);
  Invalidate;
end;

procedure TSigmaGaussianMainForm.fastBlurButtonClick(Sender: TObject);
var
  mr: TMemoryRaster;
  tk: TTimeTick;
begin
  mr := NewRaster;
  BitmapToMemoryBitmap(oriImage.Bitmap, mr);
  tk := GetTimeTick;
  fastBlur(mr, 5.0, mr.BoundsRect);
  mr.DrawText(Format('%dms', [(GetTimeTick - tk)]), 0, 0, 16, RColorF(1, 1, 1, 1));
  if ShowGradientHistogramCheckBox.IsChecked then
      BuildHOG(mr);
  MemoryBitmapToBitmap(mr, dstImage.Bitmap);
  DisposeObject(mr);
  Invalidate;
end;

procedure TSigmaGaussianMainForm.gaussianButtonClick(Sender: TObject);
var
  mr: TMemoryRaster;
  tk: TTimeTick;
begin
  mr := NewRaster;
  BitmapToMemoryBitmap(oriImage.Bitmap, mr);
  tk := GetTimeTick;
  GaussianBlur(mr, 5.0, mr.BoundsRect);
  mr.DrawText(Format('%dms', [(GetTimeTick - tk)]), 0, 0, 16, RColorF(1, 1, 1, 1));
  if ShowGradientHistogramCheckBox.IsChecked then
      BuildHOG(mr);
  MemoryBitmapToBitmap(mr, dstImage.Bitmap);
  DisposeObject(mr);
  Invalidate;
end;

procedure TSigmaGaussianMainForm.grayGaussianButtonClick(Sender: TObject);
var
  mr: TMemoryRaster;
  tk: TTimeTick;
begin
  mr := NewRaster;
  BitmapToMemoryBitmap(oriImage.Bitmap, mr);
  tk := GetTimeTick;
  GrayscaleBlur(mr, 5.0, mr.BoundsRect);
  mr.DrawText(Format('%dms', [(GetTimeTick - tk)]), 0, 0, 16, RColorF(1, 1, 1, 1));
  if ShowGradientHistogramCheckBox.IsChecked then
      BuildHOG(mr);
  MemoryBitmapToBitmap(mr, dstImage.Bitmap);
  DisposeObject(mr);
  Invalidate;
end;

end.
