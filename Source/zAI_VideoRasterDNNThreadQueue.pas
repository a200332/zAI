{ ****************************************************************************** }
{ * AI Rasterization Recognition ON Video                                      * }
{ * by QQ 600585@qq.com                                                        * }
{ ****************************************************************************** }
{ * https://zpascal.net                                                        * }
{ * https://github.com/PassByYou888/zAI                                        * }
{ * https://github.com/PassByYou888/ZServer4D                                  * }
{ * https://github.com/PassByYou888/PascalString                               * }
{ * https://github.com/PassByYou888/zRasterization                             * }
{ * https://github.com/PassByYou888/CoreCipher                                 * }
{ * https://github.com/PassByYou888/zSound                                     * }
{ * https://github.com/PassByYou888/zChinese                                   * }
{ * https://github.com/PassByYou888/zExpression                                * }
{ * https://github.com/PassByYou888/zGameWare                                  * }
{ * https://github.com/PassByYou888/zAnalysis                                  * }
{ * https://github.com/PassByYou888/FFMPEG-Header                              * }
{ * https://github.com/PassByYou888/zTranslate                                 * }
{ * https://github.com/PassByYou888/InfiniteIoT                                * }
{ * https://github.com/PassByYou888/FastMD5                                    * }
{ ****************************************************************************** }
unit zAI_VideoRasterDNNThreadQueue;

{$INCLUDE zDefine.inc}

interface

uses CoreClasses, PascalStrings, UnicodeMixedLib, DoStatusIO, MemoryStream64, ListEngine,
{$IFDEF FPC}
  FPCGenericStructlist,
{$ENDIF FPC}
  MemoryRaster, Geometry2DUnit,
  H264, FFMPEG, FFMPEG_Reader, FFMPEG_Writer,
  zAI, zAI_Common, zAI_FFMPEG, Learn, LearnTypes, KDTree;

type
  TRasterInputQueue = class;

  TRasterRecognitionData = class
  protected
    FOwner: TRasterInputQueue;
    FID: SystemString;
    FRaster: TRaster;
    FIDLE: Boolean;
    FNullRec: Boolean;
    FDNNThread: TAI_DNN_Thread;
    FInputTime, FDoneTime: TTimeTick;
    FUserData: Pointer;
  public
    constructor Create(Owner_: TRasterInputQueue); virtual;
    destructor Destroy; override;
    procedure SetDone;
    function Busy(): Boolean;
    function UsageTime: TTimeTick;
    property IDLE: Boolean read FIDLE;
    property Raster: TRaster read FRaster;
    property ID: SystemString read FID;
    property NullRec: Boolean read FNullRec;
    property UserData: Pointer read FUserData write FUserData;
  end;

  TRasterRecognitionData_ = record
    Data: TRasterRecognitionData;
  end;

  TRasterRecognitionData_Ptr = ^TRasterRecognitionData_;

  TRasterRecognitionDataClass = class of TRasterRecognitionData;

  TRasterRecognitionData_Passed = class(TRasterRecognitionData)
  public
    constructor Create(Owner_: TRasterInputQueue); override;
    destructor Destroy; override;
  end;

  TRasterRecognitionData_Metric = class(TRasterRecognitionData)
  public
    Output: TLVec;
    L: TLearn;
    constructor Create(Owner_: TRasterInputQueue); override;
    destructor Destroy; override;
  end;

  TRasterRecognitionData_LMetric = class(TRasterRecognitionData)
  public
    Output: TLVec;
    L: TLearn;
    constructor Create(Owner_: TRasterInputQueue); override;
    destructor Destroy; override;
  end;

  TRasterRecognitionData_MMOD6L = class(TRasterRecognitionData)
  public
    Output: TMMOD_Desc;
    constructor Create(Owner_: TRasterInputQueue); override;
    destructor Destroy; override;
  end;

  TRasterRecognitionData_MMOD3L = class(TRasterRecognitionData)
  public
    Output: TMMOD_Desc;
    constructor Create(Owner_: TRasterInputQueue); override;
    destructor Destroy; override;
  end;

  TRasterRecognitionData_RNIC = class(TRasterRecognitionData)
  public
    Output: TLVec;
    ClassifierIndex: TPascalStringList;
    constructor Create(Owner_: TRasterInputQueue); override;
    destructor Destroy; override;
  end;

  TRasterRecognitionData_LRNIC = class(TRasterRecognitionData)
  public
    Output: TLVec;
    ClassifierIndex: TPascalStringList;
    constructor Create(Owner_: TRasterInputQueue); override;
    destructor Destroy; override;
  end;

  TRasterRecognitionData_GDCNIC = class(TRasterRecognitionData)
  public
    Output: TLVec;
    ClassifierIndex: TPascalStringList;
    constructor Create(Owner_: TRasterInputQueue); override;
    destructor Destroy; override;
  end;

  TRasterRecognitionData_GNIC = class(TRasterRecognitionData)
  public
    Output: TLVec;
    ClassifierIndex: TPascalStringList;
    constructor Create(Owner_: TRasterInputQueue); override;
    destructor Destroy; override;
  end;

  TRasterRecognitionData_SS = class(TRasterRecognitionData)
  public
    Output: TMemoryRaster;
    SSTokenOutput: TPascalStringList;
    ColorPool: TSegmentationColorTable;
    constructor Create(Owner_: TRasterInputQueue); override;
    destructor Destroy; override;
  end;

  TRasterRecognitionDataList = {$IFDEF FPC}specialize {$ENDIF FPC} TGenericsList<TRasterRecognitionData>;

  IOnRasterInputQueue = interface
    procedure DoInput(Sender: TRasterInputQueue; Raster: TRaster);
    procedure DoRecognitionDone(Sender: TRasterInputQueue; RD: TRasterRecognitionData);
    procedure DoQueueDone(Sender: TRasterInputQueue);
    procedure DoCutNullRec(Sender: TRasterInputQueue; bIndex, eIndex: Integer);
    procedure DoCutMaxLimit(Sender: TRasterInputQueue; bIndex, eIndex: Integer);
  end;

  TRasterInputQueue = class
  private
    FQueue: TRasterRecognitionDataList;
    FCritical: TCritical;
    FCutNullQueue: Boolean;
    FMaxQueue: Integer;
    FSyncEvent: Boolean;
    procedure DoDelayCheckBusyAndFree;
    function BeforeInput(ID_: SystemString; UserData_: Pointer; Raster: TRaster; instance_: Boolean; dataClass: TRasterRecognitionDataClass): TRasterRecognitionData;
    procedure Sync_DoFinish(Data1: Pointer; Data2: TCoreClassObject; Data3: Variant);
    procedure DoFinish(RD: TRasterRecognitionData; RecSuccessed: Boolean);

    procedure Do_Input_Metric_Result(ThSender: TAI_DNN_Thread_Metric; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
    procedure Do_Input_LMetric_Result(ThSender: TAI_DNN_Thread_LMetric; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
    procedure Do_Input_MMOD3L_Result(ThSender: TAI_DNN_Thread_MMOD3L; UserData: Pointer; Input: TMemoryRaster; Output: TMMOD_Desc);
    procedure Do_Input_MMOD6L_Result(ThSender: TAI_DNN_Thread_MMOD6L; UserData: Pointer; Input: TMemoryRaster; Output: TMMOD_Desc);
    procedure Do_Input_RNIC_Result(ThSender: TAI_DNN_Thread_RNIC; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
    procedure Do_Input_LRNIC_Result(ThSender: TAI_DNN_Thread_LRNIC; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
    procedure Do_Input_GDCNIC_Result(ThSender: TAI_DNN_Thread_GDCNIC; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
    procedure Do_Input_GNIC_Result(ThSender: TAI_DNN_Thread_GNIC; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
    procedure Do_Input_SS_Result(ThSender: TAI_DNN_Thread_SS; UserData: Pointer; Input: TMemoryRaster; SSTokenOutput: TPascalStringList; Output: TMemoryRaster);
  public
    OnInterface: IOnRasterInputQueue;
    constructor Create;
    destructor Destroy; override;

    function Input_Passed(ID_: SystemString; UserData_: Pointer; Raster: TRaster; instance_: Boolean): TRasterRecognitionData_Passed;
    function Input_Metric(ID_: SystemString; UserData_: Pointer; Raster: TRaster; L: TLearn; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_Metric): TRasterRecognitionData_Metric;
    function Input_LMetric(ID_: SystemString; UserData_: Pointer; Raster: TRaster; L: TLearn; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_LMetric): TRasterRecognitionData_LMetric;
    function Input_MMOD3L(ID_: SystemString; UserData_: Pointer; Raster: TRaster; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_MMOD3L): TRasterRecognitionData_MMOD3L;
    function Input_MMOD6L(ID_: SystemString; UserData_: Pointer; Raster: TRaster; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_MMOD6L): TRasterRecognitionData_MMOD6L;
    function Input_RNIC(ID_: SystemString; UserData_: Pointer; Raster: TRaster; ClassifierIndex: TPascalStringList; num_crops: Integer; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_RNIC): TRasterRecognitionData_RNIC;
    function Input_LRNIC(ID_: SystemString; UserData_: Pointer; Raster: TRaster; ClassifierIndex: TPascalStringList; num_crops: Integer; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_LRNIC): TRasterRecognitionData_LRNIC;
    function Input_GDCNIC(ID_: SystemString; UserData_: Pointer; Raster: TRaster; ClassifierIndex: TPascalStringList; SS_width, SS_height: Integer; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_GDCNIC): TRasterRecognitionData_GDCNIC;
    function Input_GNIC(ID_: SystemString; UserData_: Pointer; Raster: TRaster; ClassifierIndex: TPascalStringList; SS_width, SS_height: Integer; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_GNIC): TRasterRecognitionData_GNIC;
    function Input_SS(ID_: SystemString; UserData_: Pointer; Raster: TRaster; ColorPool: TSegmentationColorTable; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_SS): TRasterRecognitionData_SS;

    function FindDNNThread(DNNThread: TAI_DNN_Thread): Integer;
    function BusyNum: Integer;
    function Busy: Boolean; overload;
    function Busy(bIndex, eIndex: Integer): Boolean; overload;
    function Delete(bIndex, eIndex: Integer): Boolean;
    procedure RemoveNullOutput;
    procedure GetQueueState();
    function Count: Integer;

    function LockQueue: TRasterRecognitionDataList;
    procedure UnLockQueue;
    procedure Clean;
    procedure DelayCheckBusyAndFree;

    property CutNullQueue: Boolean read FCutNullQueue write FCutNullQueue;
    property MaxQueue: Integer read FMaxQueue write FMaxQueue;
    property SyncEvent: Boolean read FSyncEvent write FSyncEvent;
  end;

implementation

constructor TRasterRecognitionData.Create(Owner_: TRasterInputQueue);
begin
  inherited Create;
  FOwner := Owner_;
  FID := '';
  FRaster := nil;
  FIDLE := False;
  FNullRec := True;
  FDNNThread := nil;
  FInputTime := 0;
  FDoneTime := 0;
  FUserData := nil;
end;

destructor TRasterRecognitionData.Destroy;
begin
  DisposeObjectAndNil(FRaster);
  inherited Destroy;
end;

procedure TRasterRecognitionData.SetDone;
begin
  FIDLE := True;
  FDoneTime := GetTimeTick();
end;

function TRasterRecognitionData.Busy(): Boolean;
begin
  Result := True;
  if not FIDLE then
      exit;
  Result := False;
end;

function TRasterRecognitionData.UsageTime: TTimeTick;
begin
  if Busy then
      Result := 0
  else
      Result := FDoneTime - FInputTime;
end;

constructor TRasterRecognitionData_Passed.Create(Owner_: TRasterInputQueue);
begin
  inherited Create(Owner_);
end;

destructor TRasterRecognitionData_Passed.Destroy;
begin
  inherited Destroy;
end;

constructor TRasterRecognitionData_Metric.Create(Owner_: TRasterInputQueue);
begin
  inherited Create(Owner_);
  SetLength(Output, 0);
  L := nil;
end;

destructor TRasterRecognitionData_Metric.Destroy;
begin
  SetLength(Output, 0);
  inherited Destroy;
end;

constructor TRasterRecognitionData_LMetric.Create(Owner_: TRasterInputQueue);
begin
  inherited Create(Owner_);
  SetLength(Output, 0);
  L := nil;
end;

destructor TRasterRecognitionData_LMetric.Destroy;
begin
  SetLength(Output, 0);
  inherited Destroy;
end;

constructor TRasterRecognitionData_MMOD6L.Create(Owner_: TRasterInputQueue);
begin
  inherited Create(Owner_);
  SetLength(Output, 0);
end;

destructor TRasterRecognitionData_MMOD6L.Destroy;
begin
  SetLength(Output, 0);
  inherited Destroy;
end;

constructor TRasterRecognitionData_MMOD3L.Create(Owner_: TRasterInputQueue);
begin
  inherited Create(Owner_);
  SetLength(Output, 0);
end;

destructor TRasterRecognitionData_MMOD3L.Destroy;
begin
  SetLength(Output, 0);
  inherited Destroy;
end;

constructor TRasterRecognitionData_RNIC.Create(Owner_: TRasterInputQueue);
begin
  inherited Create(Owner_);
  SetLength(Output, 0);
  ClassifierIndex := nil;
end;

destructor TRasterRecognitionData_RNIC.Destroy;
begin
  SetLength(Output, 0);
  inherited Destroy;
end;

constructor TRasterRecognitionData_LRNIC.Create(Owner_: TRasterInputQueue);
begin
  inherited Create(Owner_);
  SetLength(Output, 0);
  ClassifierIndex := nil;
end;

destructor TRasterRecognitionData_LRNIC.Destroy;
begin
  SetLength(Output, 0);
  inherited Destroy;
end;

constructor TRasterRecognitionData_GDCNIC.Create(Owner_: TRasterInputQueue);
begin
  inherited Create(Owner_);
  SetLength(Output, 0);
  ClassifierIndex := nil;
end;

destructor TRasterRecognitionData_GDCNIC.Destroy;
begin
  SetLength(Output, 0);
  inherited Destroy;
end;

constructor TRasterRecognitionData_GNIC.Create(Owner_: TRasterInputQueue);
begin
  inherited Create(Owner_);
  SetLength(Output, 0);
  ClassifierIndex := nil;
end;

destructor TRasterRecognitionData_GNIC.Destroy;
begin
  SetLength(Output, 0);
  inherited Destroy;
end;

constructor TRasterRecognitionData_SS.Create(Owner_: TRasterInputQueue);
begin
  inherited Create(Owner_);
  Output := NewRaster();
  SSTokenOutput := TPascalStringList.Create;
  ColorPool := nil;
end;

destructor TRasterRecognitionData_SS.Destroy;
begin
  DisposeObject(Output);
  DisposeObject(SSTokenOutput);
  inherited Destroy;
end;

procedure TRasterInputQueue.DoDelayCheckBusyAndFree;
begin
  while Busy do
      TCompute.Sleep(10);
  DisposeObject(self);
end;

function TRasterInputQueue.BeforeInput(ID_: SystemString; UserData_: Pointer; Raster: TRaster; instance_: Boolean; dataClass: TRasterRecognitionDataClass): TRasterRecognitionData;
var
  RD: TRasterRecognitionData;
begin
  RD := dataClass.Create(self);
  if instance_ then
      RD.FRaster := Raster
  else
      RD.FRaster := Raster.Clone;

  RD.FID := ID_;
  RD.FInputTime := GetTimeTick();
  RD.FDoneTime := RD.FInputTime;
  RD.UserData := UserData_;

  FCritical.Lock;
  FQueue.Add(RD);
  FCritical.UnLock;

  if Assigned(OnInterface) then
      OnInterface.DoInput(self, RD.FRaster);

  Result := RD;
end;

procedure TRasterInputQueue.Sync_DoFinish(Data1: Pointer; Data2: TCoreClassObject; Data3: Variant);
var
  RD: TRasterRecognitionData; RecSuccessed: Boolean;
  i: Integer;
begin
  RD := TRasterRecognitionData(Data2);
  RecSuccessed := Data3;

  RD.SetDone;
  RD.FNullRec := not RecSuccessed;

  if Assigned(OnInterface) then
      OnInterface.DoRecognitionDone(self, RD);

  if RD.FNullRec and FCutNullQueue then
    begin
      FCritical.Lock;
      i := FQueue.IndexOf(RD);
      FCritical.UnLock;
      if i >= 0 then
        if not Busy(0, i) then
          begin
            if Assigned(OnInterface) then
                OnInterface.DoCutNullRec(self, 0, i);
            Delete(0, i);
          end;
    end;

  if Count > FMaxQueue then
    begin
      if not Busy(0, Count - FMaxQueue) then
        begin
          if Assigned(OnInterface) then
              OnInterface.DoCutMaxLimit(self, 0, Count - FMaxQueue);
          Delete(0, Count - FMaxQueue);
        end;
    end;

  if not Busy then
    if Assigned(OnInterface) then
        OnInterface.DoQueueDone(self);
end;

procedure TRasterInputQueue.DoFinish(RD: TRasterRecognitionData; RecSuccessed: Boolean);
begin
  if RD.FOwner <> self then
      exit;

  if FSyncEvent then
      TCompute.PostM3(nil, RD, RecSuccessed, {$IFDEF FPC}@{$ENDIF FPC}Sync_DoFinish)
  else
      Sync_DoFinish(nil, RD, RecSuccessed);
end;

procedure TRasterInputQueue.Do_Input_Metric_Result(ThSender: TAI_DNN_Thread_Metric; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
var
  p: TRasterRecognitionData_Ptr;
begin
  p := UserData;
  TRasterRecognitionData_Metric(p^.Data).Output := LVecCopy(Output);
  DoFinish(p^.Data, True);
  Dispose(p);
end;

procedure TRasterInputQueue.Do_Input_LMetric_Result(ThSender: TAI_DNN_Thread_LMetric; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
var
  p: TRasterRecognitionData_Ptr;
begin
  p := UserData;
  TRasterRecognitionData_LMetric(p^.Data).Output := LVecCopy(Output);
  DoFinish(p^.Data, True);
  Dispose(p);
end;

procedure TRasterInputQueue.Do_Input_MMOD3L_Result(ThSender: TAI_DNN_Thread_MMOD3L; UserData: Pointer; Input: TMemoryRaster; Output: TMMOD_Desc);
var
  p: TRasterRecognitionData_Ptr;
  i: Integer;
begin
  p := UserData;
  SetLength(TRasterRecognitionData_MMOD3L(p^.Data).Output, Length(Output));
  for i := 0 to Length(Output) - 1 do
      TRasterRecognitionData_MMOD3L(p^.Data).Output[i] := Output[i];
  DoFinish(p^.Data, Length(Output) > 0);
  Dispose(p);
end;

procedure TRasterInputQueue.Do_Input_MMOD6L_Result(ThSender: TAI_DNN_Thread_MMOD6L; UserData: Pointer; Input: TMemoryRaster; Output: TMMOD_Desc);
var
  p: TRasterRecognitionData_Ptr;
  i: Integer;
begin
  p := UserData;
  SetLength(TRasterRecognitionData_MMOD6L(p^.Data).Output, Length(Output));
  for i := 0 to Length(Output) - 1 do
      TRasterRecognitionData_MMOD6L(p^.Data).Output[i] := Output[i];
  DoFinish(p^.Data, Length(Output) > 0);
  Dispose(p);
end;

procedure TRasterInputQueue.Do_Input_RNIC_Result(ThSender: TAI_DNN_Thread_RNIC; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
var
  p: TRasterRecognitionData_Ptr;
begin
  p := UserData;
  TRasterRecognitionData_RNIC(p^.Data).Output := LVecCopy(Output);
  DoFinish(p^.Data, True);
  Dispose(p);
end;

procedure TRasterInputQueue.Do_Input_LRNIC_Result(ThSender: TAI_DNN_Thread_LRNIC; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
var
  p: TRasterRecognitionData_Ptr;
begin
  p := UserData;
  TRasterRecognitionData_LRNIC(p^.Data).Output := LVecCopy(Output);
  DoFinish(p^.Data, True);
  Dispose(p);
end;

procedure TRasterInputQueue.Do_Input_GDCNIC_Result(ThSender: TAI_DNN_Thread_GDCNIC; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
var
  p: TRasterRecognitionData_Ptr;
begin
  p := UserData;
  TRasterRecognitionData_GDCNIC(p^.Data).Output := LVecCopy(Output);
  DoFinish(p^.Data, True);
  Dispose(p);
end;

procedure TRasterInputQueue.Do_Input_GNIC_Result(ThSender: TAI_DNN_Thread_GNIC; UserData: Pointer; Input: TMemoryRaster; Output: TLVec);
var
  p: TRasterRecognitionData_Ptr;
begin
  p := UserData;
  TRasterRecognitionData_GNIC(p^.Data).Output := LVecCopy(Output);
  DoFinish(p^.Data, True);
  Dispose(p);
end;

procedure TRasterInputQueue.Do_Input_SS_Result(ThSender: TAI_DNN_Thread_SS; UserData: Pointer; Input: TMemoryRaster; SSTokenOutput: TPascalStringList; Output: TMemoryRaster);
var
  p: TRasterRecognitionData_Ptr;
begin
  p := UserData;
  TRasterRecognitionData_SS(p^.Data).Output.SwapInstance(Output);
  TRasterRecognitionData_SS(p^.Data).SSTokenOutput.Assign(SSTokenOutput);
  DoFinish(p^.Data, SSTokenOutput.Count > 0);
  Dispose(p);
end;

constructor TRasterInputQueue.Create;
begin
  inherited Create;
  FQueue := TRasterRecognitionDataList.Create;
  FCritical := TCritical.Create;
  FCutNullQueue := True;
  FMaxQueue := 50;
  FSyncEvent := False;
  OnInterface := nil;
end;

destructor TRasterInputQueue.Destroy;
begin
  Clean;
  DisposeObject(FQueue);
  FCritical.Free;
  inherited Destroy;
end;

function TRasterInputQueue.Input_Passed(ID_: SystemString; UserData_: Pointer; Raster: TRaster; instance_: Boolean): TRasterRecognitionData_Passed;
begin
  Result := BeforeInput(ID_, UserData_, Raster, instance_, TRasterRecognitionData_Passed) as TRasterRecognitionData_Passed;
  DoFinish(Result, True);
end;

function TRasterInputQueue.Input_Metric(ID_: SystemString; UserData_: Pointer; Raster: TRaster; L: TLearn; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_Metric): TRasterRecognitionData_Metric;
var
  p: TRasterRecognitionData_Ptr;
begin

  if NoQueue_ and (FindDNNThread(DNNThread) > 0) then
    begin
      // skip this raster
      if instance_ then
          DisposeObject(Raster);
      Result := nil;
      exit;
    end;

  Result := BeforeInput(ID_, UserData_, Raster, instance_, TRasterRecognitionData_Metric) as TRasterRecognitionData_Metric;
  Result.L := L;

  New(p);
  p^.Data := Result;
  DNNThread.ProcessM(p, Result.Raster, False, {$IFDEF FPC}@{$ENDIF FPC}Do_Input_Metric_Result);
end;

function TRasterInputQueue.Input_LMetric(ID_: SystemString; UserData_: Pointer; Raster: TRaster; L: TLearn; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_LMetric): TRasterRecognitionData_LMetric;
var
  p: TRasterRecognitionData_Ptr;
begin
  if NoQueue_ and (FindDNNThread(DNNThread) > 0) then
    begin
      // skip this raster
      if instance_ then
          DisposeObject(Raster);
      Result := nil;
      exit;
    end;

  Result := BeforeInput(ID_, UserData_, Raster, instance_, TRasterRecognitionData_LMetric) as TRasterRecognitionData_LMetric;
  Result.L := L;

  New(p);
  p^.Data := Result;
  DNNThread.ProcessM(p, Result.Raster, False, {$IFDEF FPC}@{$ENDIF FPC}Do_Input_LMetric_Result);
end;

function TRasterInputQueue.Input_MMOD3L(ID_: SystemString; UserData_: Pointer; Raster: TRaster; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_MMOD3L): TRasterRecognitionData_MMOD3L;
var
  p: TRasterRecognitionData_Ptr;
begin
  if NoQueue_ and (FindDNNThread(DNNThread) > 0) then
    begin
      // skip this raster
      if instance_ then
          DisposeObject(Raster);
      Result := nil;
      exit;
    end;

  Result := BeforeInput(ID_, UserData_, Raster, instance_, TRasterRecognitionData_MMOD3L) as TRasterRecognitionData_MMOD3L;

  New(p);
  p^.Data := Result;
  DNNThread.ProcessM(p, Result.Raster, False, {$IFDEF FPC}@{$ENDIF FPC}Do_Input_MMOD3L_Result);
end;

function TRasterInputQueue.Input_MMOD6L(ID_: SystemString; UserData_: Pointer; Raster: TRaster; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_MMOD6L): TRasterRecognitionData_MMOD6L;
var
  p: TRasterRecognitionData_Ptr;
begin
  if NoQueue_ and (FindDNNThread(DNNThread) > 0) then
    begin
      // skip this raster
      if instance_ then
          DisposeObject(Raster);
      Result := nil;
      exit;
    end;

  Result := BeforeInput(ID_, UserData_, Raster, instance_, TRasterRecognitionData_MMOD6L) as TRasterRecognitionData_MMOD6L;

  New(p);
  p^.Data := Result;
  DNNThread.ProcessM(p, Result.Raster, False, {$IFDEF FPC}@{$ENDIF FPC}Do_Input_MMOD6L_Result);
end;

function TRasterInputQueue.Input_RNIC(ID_: SystemString; UserData_: Pointer; Raster: TRaster; ClassifierIndex: TPascalStringList; num_crops: Integer; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_RNIC): TRasterRecognitionData_RNIC;
var
  p: TRasterRecognitionData_Ptr;
begin
  if NoQueue_ and (FindDNNThread(DNNThread) > 0) then
    begin
      // skip this raster
      if instance_ then
          DisposeObject(Raster);
      Result := nil;
      exit;
    end;

  Result := BeforeInput(ID_, UserData_, Raster, instance_, TRasterRecognitionData_RNIC) as TRasterRecognitionData_RNIC;
  Result.ClassifierIndex := ClassifierIndex;

  New(p);
  p^.Data := Result;
  DNNThread.ProcessM(p, Result.Raster, num_crops, False, {$IFDEF FPC}@{$ENDIF FPC}Do_Input_RNIC_Result);
end;

function TRasterInputQueue.Input_LRNIC(ID_: SystemString; UserData_: Pointer; Raster: TRaster; ClassifierIndex: TPascalStringList; num_crops: Integer; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_LRNIC): TRasterRecognitionData_LRNIC;
var
  p: TRasterRecognitionData_Ptr;
begin
  if NoQueue_ and (FindDNNThread(DNNThread) > 0) then
    begin
      // skip this raster
      if instance_ then
          DisposeObject(Raster);
      Result := nil;
      exit;
    end;

  Result := BeforeInput(ID_, UserData_, Raster, instance_, TRasterRecognitionData_LRNIC) as TRasterRecognitionData_LRNIC;
  Result.ClassifierIndex := ClassifierIndex;

  New(p);
  p^.Data := Result;
  DNNThread.ProcessM(p, Result.Raster, num_crops, False, {$IFDEF FPC}@{$ENDIF FPC}Do_Input_LRNIC_Result);
end;

function TRasterInputQueue.Input_GDCNIC(ID_: SystemString; UserData_: Pointer; Raster: TRaster; ClassifierIndex: TPascalStringList; SS_width, SS_height: Integer; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_GDCNIC): TRasterRecognitionData_GDCNIC;
var
  p: TRasterRecognitionData_Ptr;
begin
  if NoQueue_ and (FindDNNThread(DNNThread) > 0) then
    begin
      // skip this raster
      if instance_ then
          DisposeObject(Raster);
      Result := nil;
      exit;
    end;

  Result := BeforeInput(ID_, UserData_, Raster, instance_, TRasterRecognitionData_GDCNIC) as TRasterRecognitionData_GDCNIC;
  Result.ClassifierIndex := ClassifierIndex;

  New(p);
  p^.Data := Result;
  DNNThread.ProcessM(p, Result.Raster, SS_width, SS_height, False, {$IFDEF FPC}@{$ENDIF FPC}Do_Input_GDCNIC_Result);
end;

function TRasterInputQueue.Input_GNIC(ID_: SystemString; UserData_: Pointer; Raster: TRaster; ClassifierIndex: TPascalStringList; SS_width, SS_height: Integer; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_GNIC): TRasterRecognitionData_GNIC;
var
  p: TRasterRecognitionData_Ptr;
begin
  if NoQueue_ and (FindDNNThread(DNNThread) > 0) then
    begin
      // skip this raster
      if instance_ then
          DisposeObject(Raster);
      Result := nil;
      exit;
    end;

  Result := BeforeInput(ID_, UserData_, Raster, instance_, TRasterRecognitionData_GNIC) as TRasterRecognitionData_GNIC;
  Result.ClassifierIndex := ClassifierIndex;

  New(p);
  p^.Data := Result;
  DNNThread.ProcessM(p, Result.Raster, SS_width, SS_height, False, {$IFDEF FPC}@{$ENDIF FPC}Do_Input_GNIC_Result);
end;

function TRasterInputQueue.Input_SS(ID_: SystemString; UserData_: Pointer; Raster: TRaster; ColorPool: TSegmentationColorTable; instance_, NoQueue_: Boolean; DNNThread: TAI_DNN_Thread_SS): TRasterRecognitionData_SS;
var
  p: TRasterRecognitionData_Ptr;
begin
  if NoQueue_ and (FindDNNThread(DNNThread) > 0) then
    begin
      // skip this raster
      if instance_ then
          DisposeObject(Raster);
      Result := nil;
      exit;
    end;

  Result := BeforeInput(ID_, UserData_, Raster, instance_, TRasterRecognitionData_SS) as TRasterRecognitionData_SS;
  Result.ColorPool := ColorPool;

  New(p);
  p^.Data := Result;
  DNNThread.ProcessM(p, Result.Raster, ColorPool, False, {$IFDEF FPC}@{$ENDIF FPC}Do_Input_SS_Result);
end;

function TRasterInputQueue.FindDNNThread(DNNThread: TAI_DNN_Thread): Integer;
var
  i: Integer;
begin
  FCritical.Lock;
  Result := 0;
  for i := 0 to FQueue.Count - 1 do
    if FQueue[i].FDNNThread = DNNThread then
        inc(Result);
  FCritical.UnLock;
end;

function TRasterInputQueue.BusyNum: Integer;
var
  i: Integer;
begin
  Result := 0;
  FCritical.Lock;
  for i := 0 to FQueue.Count - 1 do
    if FQueue[i].Busy() then
        inc(Result);
  FCritical.UnLock;
end;

function TRasterInputQueue.Busy: Boolean;
begin
  Result := Busy(0, FQueue.Count - 1);
end;

function TRasterInputQueue.Busy(bIndex, eIndex: Integer): Boolean;
var
  i: Integer;
begin
  FCritical.Lock;
  Result := False;
  for i := umlMax(0, bIndex) to umlMin(FQueue.Count - 1, eIndex) do
      Result := Result or FQueue[i].Busy();
  FCritical.UnLock;
end;

function TRasterInputQueue.Delete(bIndex, eIndex: Integer): Boolean;
var
  i, j: Integer;
  RD: TRasterRecognitionData;
begin
  Result := False;
  if not Busy(bIndex, eIndex) then
    begin
      FCritical.Lock;
      for i := umlMax(0, bIndex) to umlMin(FQueue.Count - 1, eIndex) do
        begin
          RD := FQueue[bIndex];
          DisposeObject(RD);
          FQueue.Delete(bIndex);
        end;
      FCritical.UnLock;
      Result := True;
    end;
end;

procedure TRasterInputQueue.RemoveNullOutput;
var
  i, j: Integer;
  RD: TRasterRecognitionData;
begin
  FCritical.Lock;
  i := 0;
  while i < FQueue.Count do
    begin
      RD := FQueue[i];
      if (not RD.Busy) then
        begin
          DisposeObject(RD);
          FQueue.Delete(i);
        end
      else
          inc(i);
    end;
  FCritical.UnLock;
end;

procedure TRasterInputQueue.GetQueueState();
var
  i, j: Integer;
  RD: TRasterRecognitionData;
begin
  FCritical.Lock;
  for i := 0 to FQueue.Count - 1 do
    begin
      RD := FQueue[i];
      if RD.Busy then
        begin
        end
      else
        begin
        end;
    end;
  FCritical.UnLock;
end;

function TRasterInputQueue.Count: Integer;
begin
  Result := FQueue.Count;
end;

function TRasterInputQueue.LockQueue: TRasterRecognitionDataList;
begin
  FCritical.Lock;
  Result := FQueue;
end;

procedure TRasterInputQueue.UnLockQueue;
begin
  FCritical.UnLock;
end;

procedure TRasterInputQueue.Clean;
var
  i, j: Integer;
  RD: TRasterRecognitionData;
begin
  while Busy do
      TCompute.Sleep(1);

  FCritical.Lock;
  for i := 0 to FQueue.Count - 1 do
    begin
      RD := FQueue[i];
      DisposeObject(RD);
    end;
  FQueue.Clear;
  FCritical.UnLock;
end;

procedure TRasterInputQueue.DelayCheckBusyAndFree;
begin
  TCompute.RunM_NP({$IFDEF FPC}@{$ENDIF FPC}DoDelayCheckBusyAndFree);
end;

end.
