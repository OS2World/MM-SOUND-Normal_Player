{
Copyright 2002 Darwin O'Connor

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}
program nplay;

{$PMType PM}
{$H+}
{$J+}

uses sysutils, os2base, os2def, os2pmapi, os2mm;

{$R nplay.res}

type
   TState = (Closed,Stop,Play,Pause);
   TStateSet = set of TState;
   TTextIcon = (tiText, tiIcon, tiTextIcon);
   TMainBtns = (btnRwd, btnPlay, btnStop, btnFFwd, btnOpen, btnClose);

var
   ab : HAB;
   mq : HMQ;
   Frame,
   Client : HWnd;
   rc : ULONG;
   MainBtns : array[TMainBtns] of HWnd;
   FileEntry,
//   LoadBtn,
   PosStatic,
   LenStatic,
   PosSlider,
   PauseBtn,
//   CloseBtn,
   MainMenu : HWnd;
   DeviceId : UShort;
   CurrState : TState;
   CurrLength : ULong;
   WidthSlider,
   TickOrgX,
   TickOrgY : UShort;
   SliderPos : ULong;
   ManualSlide : boolean;
//   DrawTicks : boolean;
   counter : ULong;
   countstr : string;
   HeightBtn,
   HeightIconBtn,
   WidthBtn,
   HeightEntry : Long;
   HeightStatic,
   WidthStatic : long;
   HeightSlider : long;
   Boarder : long;
   CurrTextIcon : TTextIcon;
   Initing : boolean;

const
   MainId = 50;
   PosId = 500;
   LenId = 600;
   SliderId = 700;
   CloseId = 1100;
   MenuOpenId = 2101;
   FitId =2301;
   DisplayId = 2302;

   FileNameLimit = 1024;
   DiplayDlgId = 3000;
   JumpBy = 30000;
   MainIds : array[TMainBtns] of ULONG = (1000,100,200,900,400,1100);
   PlayId = 100;
   StopId = 200;
   FileId = 300;
   LoadId = 400;
   PauseId = 800;
   FFwdId = 900;
   RwdId = 1000;

   RwdString = 1;
   PlayString = 3;
   StopString = 4;
   FFwdString = 5;

type
   EMCIErr = class(Exception)
   public
      rc : ULONG;
      constructor CreateMCIErr(inrc : ULONG);
   end;

function IIf(b : boolean; t, f : USHORT) : USHORT; inline;
begin
   if b then result:=t else result:=f;
end;

constructor EMCIErr.CreateMCIErr(inrc : ULONG);
const
   MaxLen = 128;
var
   ErrString : string;
   Loop : integer;
begin
   rc:=inrc;
   SetLength(ErrString,MaxLen);
   mciGetErrorString(rc,pchar(ErrString),MaxLen);
   loop:=1;
   while (loop<=MaxLen) and (ErrString[loop]<>#0) do Inc(loop);
   SetLength(ErrString,loop);
   inherited Create(ErrString);
end;

procedure MMCheck(rc : ULong);
begin
   if (rc and $FFFF)<>MCIERR_SUCCESS then raise EMCIErr.CreateMCIErr(rc);
end;

procedure EnableMenu(Id : UShort; Enable : boolean);
begin
   WinSendMsg(MainMenu,MM_SETITEMATTR,MPFrom2Short(Id,ord(true)),MPFrom2Short(MIA_DISABLED,iif(Enable,0,MIA_DISABLED)));
end;

procedure ChangeState(NewState : TState);
const
   EnableStates : array[TMainBtns] of TStateSet = ([Stop,Play],[Stop],[Play],[Stop,Play],[Closed,Stop,Play,Pause],[Stop,Play,Pause]);
var
   CurrBtn : TMainBtns;
begin
   for CurrBtn:=Low(TMainBtns) to High(TMainBtns) do begin
      WinEnableWindow(MainBtns[CurrBtn],NewState in EnableStates[CurrBtn]);
      WinSendMsg(MainMenu,MM_SETITEMATTR,MPFrom2Short(MainIds[CurrBtn],ord(true)),MPFrom2Short(MIA_DISABLED,iif(NewState in EnableStates[CurrBtn],0,MIA_DISABLED)));
   end;
   CurrState:=NewState;
end;

procedure SetTimeText(Static : HWnd; Pos : ULONG);
var
   s : string;
begin
   if Pos=-1 then begin
      WinSetWindowText(Static,'');
   end else begin
      s:=IntToStr((Pos div 3000) mod 60);
      if Length(s)<2 then s:='0'+s;
      s:=IntToStr(pos div 180000)+':'+s;
      WinSetWindowText(Static,pchar(s));
   end;
end;

procedure SetCurrLength(NewLen : ULong);
begin
   CurrLength:=NewLen;
   SetTimeText(LenStatic,CurrLength);
   WinEnableWindow(PosSlider,CurrLength<>-1);
//   WinInvalidateRect(PosSlider,nil,false);
end;

procedure CheckCurrTime(CurrTime : ULong);
var
   StatusParm : MCI_Status_Parms;
   CurrSliderPos : ULong;
begin
   if CurrTime=-1 then
      if CurrState=Closed then CurrTime:=0
      else begin
         StatusParm.ulItem:=MCI_STATUS_POSITION;
         mmCheck(mciSendCommand(DeviceId,MCI_STATUS,MCI_WAIT+MCI_STATUS_ITEM,StatusParm,0));
         CurrTime:=Statusparm.ulReturn;
      end;
   SetTimeText(PosStatic,CurrTime);
   if CurrLength<>-1 then begin
      if (CurrTime>CurrLength) then SetCurrLength(CurrTime);
      CurrSliderPos:=currtime*WidthSlider div CurrLength;
      if SliderPos<>CurrSliderPos then begin
         ManualSlide:=false;
         WinSendMsg(PosSlider,SLM_SETSLIDERINFO,MPFrom2Short(SMA_SLIDERARMPOSITION,SMA_RANGEVALUE),MPFromLong(CurrSliderPos));
         ManualSlide:=true;
         SliderPos:=CurrSliderPos;
      end;
   end;
end;

procedure SortButtons;
var
   CurrX,
   CurrY,
   Width,
   TickOrg : MResult;
   CurrSWP : SWP;
   CurrBtn : TMainBtns;
begin
   if Initing then exit;
   WinQueryWindowPos(Client,CurrSWP);
   Width:=CurrSWP.cx-Boarder;
   CurrX:=Boarder;
   CurrY:=Boarder;
   WinSetWindowPos(FileEntry,HWND_TOP,CurrX,CurrY+((HeightBtn-HeightEntry) div 2),((Width*2) div 4)-Boarder,HeightEntry,SWP_SIZE+SWP_MOVE+SWP_NOADJUST);   inc(CurrX,(Width*2) div 4);
   WinSetWindowPos(MainBtns[btnOpen],HWND_TOP,CurrX,CurrY,(Width) div 4-Boarder,HeightBtn,SWP_SIZE+SWP_MOVE);
   inc(CurrX,(Width) div 4);
   WinSetWindowPos(MainBtns[btnClose],HWND_TOP,CurrX,CurrY,(Width) div 4-Boarder,HeightBtn,SWP_SIZE+SWP_MOVE);
   CurrX:=Boarder;
   Inc(CurrY,HeightBtn+Boarder);
   for CurrBtn:=btnRwd to btnFFwd do begin
      WinSetWindowPos(MainBtns[CurrBtn],HWND_TOP,CurrX,CurrY,(Width) div 4-Boarder,HeightIconBtn,SWP_SIZE+SWP_MOVE);
      inc(CurrX,(Width) div 4);
   end;
   CurrX:=Boarder;
   Inc(CurrY,HeightIconBtn+Boarder);
   HeightSlider:=Short2FromMR(WinSendMsg(PosSlider,SLM_QUERYSLIDERINFO,MPFrom2Short(SMA_SLIDERARMDIMENSIONS,0),0))+10;
   WinSetWindowPos(PosStatic,HWND_TOP,CurrX,CurrY,WidthStatic,HeightSlider,SWP_SIZE+SWP_MOVE);
   Inc(CurrX,WidthStatic+Boarder);
   WinSetWindowPos(LenStatic,HWND_TOP,Width-WidthStatic-Boarder,CurrY,WidthStatic,HeightSlider,SWP_SIZE+SWP_MOVE);
   WinSetWindowPos(PosSlider,HWND_TOP,CurrX,CurrY,Width-(2*(WidthStatic)+(4*Boarder)),HeightSlider,SWP_SIZE+SWP_MOVE);
   WidthSlider:=Short2FromMR(WinSendMsg(PosSlider,SLM_QUERYSLIDERINFO,MPFrom2Short(SMA_SLIDERARMPOSITION,SMA_RANGEVALUE),0))-1;
   TickOrg:=WinSendMsg(PosSlider,SLM_QUERYTICKPOS,MPFromShort(0),0);
   TickOrgX:=Short1FromMR(TickOrg);
   TickOrgY:=Short2FromMR(TickOrg);
   CheckCurrTime(-1);
end;

function GetBtnText(CurrBtn : TMainBtns) : string ;
var
   btnText : string;
begin
   if CurrTextIcon in [tiIcon,tiTextIcon] then begin
      result:='#'+IntToStr(MainIds[CurrBtn]);
      if CurrTextIcon=tiTextIcon then result:=result+#9
   end else result:='';
   if CurrTextIcon in [tiText,tiTextIcon] then begin
      SetLength(btnText,FileNameLimit);
      SetLength(btnText,WinLoadString(ab,NullHandle,MainIds[CurrBtn],FileNameLimit,pchar(btnText)));
      result:=result+btnText;
   end;
end;

procedure TextIconChange;
const
   TextIconStyle : array[TTextIcon] of ULONG = (0,BS_MINIICON,BS_MINIICON+BS_TEXT);
var
   CurrSWP : SWP;
   CurrRect : RectL;
   TestWnd : HWnd;
   CurrBtn : TMainBtns;
begin
   WinQueryWindowRect(FileEntry,CurrRect);
   HeightEntry:=CurrRect.yTop-CurrRect.yBottom;
   TestWnd:=WinCreateWindow(Client,WC_STATIC,'999:99',SS_TEXT+SS_AUTOSIZE,100,100,-1,-1,Client,HWND_TOP,0,nil,nil);
   WinQueryWindowPos(TestWnd,CurrSWP);
   HeightStatic:=CurrSWP.cy;
   WidthStatic:=CurrSWP.cx;
   WinDestroyWindow(TestWnd);
   TestWnd:=WinCreateWindow(Client,WC_BUTTON,pchar(GetBtnText(btnPlay)),BS_PUSHBUTTON+BS_AUTOSIZE+TextIconStyle[CurrTextIcon],100,100,-1,-1,Client,HWND_TOP,0,nil,nil);
   WinQueryWindowPos(TestWnd,CurrSWP);
   HeightBtn:=CurrSWP.cy;
   WidthBtn:=CurrSWP.cx;
   HeightIconBtn:=CurrSWP.cy;
   WinDestroyWindow(TestWnd);
   for CurrBtn:=Low(TMainBtns) to High(TMainBtns) do begin
//      WinSetWindowText(MainBtns[CurrBtn],pchar(GetBtnText(CurrBtn)));
      WinSetWindowBits(MainBtns[CurrBtn],QWL_Style,TextIconStyle[CurrTextIcon],BS_MINIICON+BS_TEXT);
   end;
   SortButtons;
   WinInvalidateRect(Client,nil,false);
end;

procedure CloseFile;
var
   GenericParm : MCI_GENERIC_PARMS;
begin
   if CurrState<>Closed then begin
      mmCheck(mciSendCommand(DeviceId,MCI_CLOSE,MCI_WAIT,GenericParm,0));
      ChangeState(Closed);
      SetCurrLength(-1);
      SetTimeText(PosStatic,0);
      WinSetWindowText(Frame,'Normal Player');
      ManualSlide:=false;
      WinSendMsg(PosSlider,SLM_SETSLIDERINFO,MPFrom2Short(SMA_SLIDERARMPOSITION,SMA_RANGEVALUE),MPFromLong(0));
      ManualSlide:=true;
   end;
end;

procedure LoadFile(FileName : string);
var
   OpenParm : MCI_Open_Parms;
   StatusParm : MCI_Status_Parms;
   PositionParm : MCI_Position_Parms;
   GenericParm : MCI_Generic_Parms;
   rc : ULONG;
begin
   CloseFile;
   FillChar(OpenParm,sizeof(MCI_Open_Parms),0);
   OpenParm.hwndCallBack:=Client;
   OpenParm.pszElementName:=pchar(FileName);
   mmCheck(mciSendCommand(0,MCI_OPEN,MCI_WAIT+MCI_OPEN_ELEMENT+MCI_OPEN_SHAREABLE+MCI_READONLY,OpenParm,0));
   DeviceId:=OpenParm.usDeviceId;
   ChangeState(Stop);
   WinSetWindowText(FileEntry,pchar(FileName));
   WinSetWindowText(Frame,pchar('Normal Player-'+FileName));
   FillChar(PositionParm,sizeof(PositionParm),0);
   PositionParm.hwndCallBack:=Client;
   PositionParm.ulUnits:=1500;
   mmCheck(mciSendCommand(DeviceId,MCI_SET_POSITION_ADVISE,MCI_WAIT+MCI_SET_POSITION_ADVISE_ON,PositionParm,0));
   StatusParm.ulItem:=MCI_STATUS_LENGTH;
   rc:=mciSendCommand(DeviceId,MCI_STATUS,MCI_WAIT+MCI_STATUS_ITEM,StatusParm,0);
   if rc=MCIERR_INDETERMINATE_LENGTH then SetCurrLength(-1)
   else begin
      MMCheck(rc);
      SetCurrLength(StatusParm.ulReturn);
   end;
   CheckCurrTime(-1);
end;

procedure create;
type
   TColorParm = record
      id : ULONG;
      cb : ULONG;
      ab : Color;
   end;
   TColorPresParm = record
      cb : ULong;
      ColorParm : TColorParm;
   end;
var
   Msg : QMsg;
   CreateFlags : ULong;
   ColorAttr : COLOR;
   ColorPresParm : TColorPresParm;
   CurrMenu : MenuItem;
   CurrBtn : TMainBtns;
   Buffer : ULONG;
begin
   ColorAttr:=SYSCLR_DIALOGBACKGROUND;
   WinSetPresParam(Client,PP_BACKGROUNDCOLORINDEX,sizeof(ColorAttr),@ColorAttr);
   PosStatic:=WinCreateWindow(Client,WC_STATIC,'999:99',WS_VISIBLE+SS_TEXT+DT_RIGHT+DT_VCENTER+SS_AUTOSIZE+WS_CLIPSIBLINGS,100,100,-1,-1,Client,HWND_TOP,PosId,nil,nil);
   PosSlider:=WinCreateWindow(Client,WC_SLIDER,'',WS_VISIBLE+SLS_TOP+SLS_OWNERDRAW+SLS_PRIMARYSCALE2+WS_TABSTOP+WS_CLIPSIBLINGS,100,100,100,100,Client,HWND_TOP,SliderId,nil,nil);
   LenStatic:=WinCreateWindow(Client,WC_STATIC,'999:99',WS_VISIBLE+SS_TEXT+DT_LEFT+DT_VCENTER+SS_AUTOSIZE+WS_CLIPSIBLINGS,100,100,-1,-1,Client,HWND_TOP,LenId,nil,nil);
   for CurrBtn:=Low(TMainBtns) to High(TMainBtns) do
      MainBtns[CurrBtn]:=WinCreateWindow(Client,WC_BUTTON,pchar(GetBtnText(CurrBtn)),WS_VISIBLE+BS_PUSHBUTTON+BS_AUTOSIZE+WS_TABSTOP+BS_MINIICON+BS_TEXT+WS_CLIPSIBLINGS,100,140,400,-1,Client,HWND_TOP,MainIds[CurrBtn],nil,nil);
   FileEntry:=WinCreateWindow(Client,WC_ENTRYFIELD,'',WS_VISIBLE+ES_AUTOSCROLL+ES_AUTOSIZE+ES_MARGIN+WS_TABSTOP+WS_CLIPSIBLINGS,100,180,400,-1,Client,HWND_TOP,FileId,nil,nil);
   WinSendMsg(FileEntry,EM_SETTEXTLIMIT,FileNameLimit,0);
   MainMenu:=WinWindowFromId(Frame,FID_MENU);
   ChangeState(Closed);
   SetCurrLength(-1);
   Buffer:=SizeOf(Boarder);
   PRFQueryProfileData(HINI_Profile,'NormalPlayer','Spacing',@Boarder,Buffer);
   Buffer:=SizeOf(CurrTextIcon);
   PRFQueryProfileData(HINI_Profile,'NormalPlayer','TextIcon',@CurrTextIcon,Buffer);
   WinRestoreWindowPos('NormalPlayer','MainWindow',Frame);
   if ParamCount>0 then LoadFile(ParamStr(1));
   Initing:=false;
   TextIconChange;
end;

procedure ShinkToFit;
var
   NewSize : RectL;
begin
   NewSize.yBottom:=0;
   NewSize.xLeft:=0;
   NewSize.yTop:=Heightbtn+HeightIconBtn+Boarder*4+HeightSlider;
   NewSize.xRight:=Widthbtn*4+Boarder*5;
   WinCalcFrameRect(Frame,NewSize,false);
   WinSetWindowPos(Frame,HWND_TOP,0,0,NewSize.xRight-NewSize.xLeft,NewSize.yTop-NewSize.yBottom,SWP_SIZE);
end;

procedure DisplayDlg;
type
   TDisplayWnds = record
      SpacingSpin,
      SpacingText,
      TextIconGroup : HWnd;
      TextIconRadio : array[TTextIcon] of HWnd;
   end;
var
   Dlg : HWnd;
   Wnds : TDisplayWnds;
   SpaceStr : string;
   SpaceValue : LONG;
begin
   Dlg:=WinLoadDlg(HWND_DESKTOP,Client,nil,NullHandle,DiplayDlgId,nil);
   WinMultWindowFromIds(Dlg,@Wnds,3001,3006);
   WinSendMsg(Wnds.SpacingSpin,SPBM_SETLIMITS,100,0);
   WinSendMsg(Wnds.SpacingSpin,SPBM_SETCURRENTVALUE,Boarder,0);
   WinSendMsg(Wnds.TextIconRadio[CurrTextIcon],BM_SETCHECK,1,0);
   if WinProcessDlg(Dlg)=DID_OK then begin
      WinSendMsg(Wnds.SpacingSpin,SPBM_QUERYVALUE,MPFromP(@SpaceValue),MPFrom2Short(0,SPBQ_DONOTUPDATE));
      Boarder:=SpaceValue;
      CurrTextIcon:=TTextIcon(WinSendMsg(Wnds.TextIconRadio[tiText],BM_QueryCheckIndex,0,0)-1);
      TextIconChange;
      SortButtons;
   end;
   WinDestroyWindow(Dlg);
end;


function NPlayWndProc(Window : HWnd; Msg : ULong; MP1, MP2 : MParam): MResult; CDECL;
const
   TickTime=30*3000;
   FilD : FileDlg = (cbSize:SizeOf(FileDlg);fl:FDS_OPEN_DIALOG;ulUser:0;lReturn:0;lSRC:0;pszTitle:'File Open';pszOKButton:nil;pfnDlgProc:nil;pszIType:nil;papszITypeList:nil;pszIDrive:nil;papszIDriveList:nil;hMod:NULLHANDLE;szFullFile:'*';
                     papszFQFilename:nil;ulFQFCount:0;usDlgID:0;x:0;y:0;sEAType:0);
var
   ps : HPS;
   PaintArea : RECTL;
   PlayParm : MCI_PLAY_PARMS;
   GenericParm : MCI_GENERIC_PARMS;
   FilePath,
   FileName : string;
   loop : ULong;
   Pos : PointL;
   SeekParm : MCI_Seek_Parms;
   StatusParm : MCI_Status_Parms;
   WinRect : RectL;
   CurrDragItem : PDragItem;
begin
   result:=0;
   try
      case msg of
      WM_CREATE : begin
         Client:=Window;
         Frame:=WinQueryWindow(Client,QW_Parent);
         Create;
      end;
      WM_PAINT : begin
         ps:=WinBeginPaint(Client,NullHandle,@PaintArea);
         WinFillRect(ps,PaintArea,SYSCLR_DIALOGBACKGROUND);
   {      GPISetBackColor(ps,SYSCLR_DIALOGBACKGROUND);
         GPIErase(ps);}
         WinEndPaint(Client);
      end;
      WM_Command :
         case Short1FromMP(MP1) of
         PlayId :
            if CurrState=Stop then begin
               PlayParm.hwndCallBack:=Client;
               mmCheck(mciSendCommand(DeviceId,MCI_PLAY,MCI_NOTIFY,PlayParm,0));
               ChangeState(Play);
            end;
         StopId :
            if CurrState=Play then begin
               mmCheck(mciSendCommand(DeviceId,MCI_STOP,MCI_WAIT,GenericParm,0));
               ChangeState(Stop);
               CheckCurrTime(-1);
            end;
         LoadId : begin
            SetLength(FileName,FileNameLimit);
            SetLength(FileName,WinQueryWindowText(FileEntry,FileNameLimit,@(FileName[1])));
            LoadFile(FileName);
         end;
         PauseId :
            if CurrState=Pause then begin
               mmCheck(mciSendCommand(DeviceId,MCI_RESUME,MCI_WAIT,GenericParm,0));
               ChangeState(Play);
            end else begin
               mmCheck(mciSendCommand(DeviceId,MCI_PAUSE,MCI_WAIT,GenericParm,0));
               ChangeState(Pause);
            end;
         FFwdId,
         RwdId :
            if CurrState in [Stop,Play] then begin
               StatusParm.ulItem:=MCI_STATUS_POSITION;
               mmCheck(mciSendCommand(DeviceId,MCI_STATUS,MCI_WAIT+MCI_STATUS_ITEM,StatusParm,0));
               if Short1FromMP(MP1)=FFwdId then SeekParm.ulTo:=JumpBy
               else SeekParm.ulTo:=-JumpBy;
               Inc(SeekParm.ulTo,Statusparm.ulReturn);
               if SeekParm.ulTo<0 then SeekParm.ulTo:=0;
               if SeekParm.ulTo>CurrLength then SeekParm.ulTo:=CurrLength;
               mmCheck(mciSendCommand(DeviceId,MCI_SEEK,MCI_WAIT+MCI_TO,SeekParm,0));
               CheckCurrTime(SeekParm.ulTo);
            end;
         CloseId : if CurrState<>Closed then Closefile;
         MenuOpenId : begin
            WinFileDlg(HWND_DESKTOP,Client,FilD);
            if filD.lReturn=DID_OK then LoadFile(filD.szFullFile);
         end;
         FitId : ShinkToFit;
         DisplayId : DisplayDlg;
         end;
      WM_Control :
         if (MP1=MPFrom2Short(SliderId,SLN_CHANGE)) and ManualSlide then begin
            SeekParm.ulTo:=LongFromMP(MP2)*CurrLength div WidthSlider;
            mmCheck(mciSendCommand(DeviceId,MCI_SEEK,MCI_WAIT+MCI_TO,SeekParm,0));
            CheckCurrTime(SeekParm.ulTo);
         end;
      MM_MCINotify : begin
         if MP2=MPFrom2Short(DeviceId,MCI_PLAY) then begin
            ChangeState(Stop);
            CheckCurrTime(-1);
         end;
      end;
      WM_SIZE : SortButtons;
      MM_MCIPOSITIONCHANGE : if Short2FromMP(MP1)=DeviceId then CheckCurrTime(LongFromMP(MP2));
      WM_DRAWITEM :
         if (Short1FromMP(MP1)=SliderId) and (POwnerItem(PVoidFromMP(MP2))^.idItem=SDA_BACKGROUND) and (CurrLength>0) {and (POwnerItem(PVoidFromMP(MP2))^.rclItem.yBottom<TickOrgY)} then
            with POwnerItem(PVoidFromMP(MP2))^ do begin
   //            Pos.x:=0;Pos.y:=0;
   //            GPISetColor(hps,{SYSCLR_OUTPUTTEXT}CLR_GREEN);
   //            GPIMarker(hps,pos);
               WinFillRect(hps,rclItem,SYSCLR_DIALOGBACKGROUND{counter mod 16});
               GPISetColor(hps,SYSCLR_OUTPUTTEXT);
               loop:=0;
   //            Pos.x:=0;Pos.y:=0;
   //            GpiMove(hps,pos);
               while loop<=Currlength do begin
                  Pos.x:=TickOrgX+(loop*WidthSlider div CurrLength);
                  Pos.y:=TickOrgY;
                  GpiMove(hps,pos);
                  if loop mod (TickTime*2)=0  then Dec(Pos.y,5) else Dec(Pos.y,3);
                  GPILine(hps,pos);
                  inc(loop,TickTime);
               end;
   //            GPISetColor(hps,{SYSCLR_OUTPUTTEXT}CLR_BLUE);
   //            GPISetMarker(hps,MARKSYM_SMALLCIRCLE);}
   {            Pos.x:=5;Pos.y:=5;
               GpiMove(hps,Pos);
               Pos.y:=-5;Pos.y:=-5;
               GPILine(hps,Pos);
               Pos.x:=5;Pos.y:=-5;
               GpiMove(hps,Pos);
               Pos.y:=-5;Pos.y:=5;
               GPILine(hps,Pos);   }
               result:=MRFromLong(1);
   {            rc:=GpiConvert(hps,CVTC_WORLD,CVTC_DEVICE,1,pos);
               CountStr:=CountStr+IntToStr(counter)+':'+IntToStr(pos.x)+','+IntToStr(pos.y)+';';
               if rc then countstr:=countstr+'! ' else countstr:=countstr+'* ';}
   {            GPIQueryPageViewport(hps,WinRect);
               CountStr:=CountStr+IntToStr(counter)+':'+IntToStr(WinRect.yBottom)+','+IntToStr(WinRect.YTop)+','+IntToStr(WinRect.XLeft)+','+IntToStr(WinRect.XRight)+' ';
   //            CountStr:=CountStr+IntToStr(counter)+':'+IntToStr(rclItem.yBottom)+','+IntToStr(rclItem.YTop)+','+IntToStr(rclItem.XLeft)+','+IntToStr(rclItem.XRight)+' ';
               WinSetWindowText(FileEntry,pchar(countstr));
               Inc(counter);}
            end;
      DM_DRAGOVER : begin
         DrgAccessDragInfo(PDragInfo(PVoidFromMP(MP1))^);
         CurrDragItem:=PDragItem(DrgQueryDragItemPtr(PDragInfo(MP1)^,0));
         if DrgVerifyRMF(CurrDragItem^,'DRM_OS2FILE',nil) then result:=MPFrom2Short(DOR_DROP,DO_COPY)
         else result:=MPFromShort(DOR_NEVERDROP);
         DrgFreeDragInfo(PDragInfo(PVoidFromMP(MP1))^);
      end;
      DM_DROP : begin
         DrgAccessDragInfo(PDragInfo(PVoidFromMP(MP1))^);
         CurrDragItem:=PDragItem(DrgQueryDragItemPtr(PDragInfo(MP1)^,0));
         if DrgVerifyRMF(CurrDragItem^,'DRM_OS2FILE',nil) then begin
            SetLength(FilePath,FileNameLimit);
            SetLength(Filepath,DrgQueryStrName(CurrDragItem^.hstrContainerName,FileNameLimit,pchar(FilePath)));
            SetLength(FileName,FileNameLimit);
            SetLength(FileName,DrgQueryStrName(CurrDragItem^.hstrSourceName,FileNameLimit,pchar(FileName)));
            LoadFile(FilePath+FileName);
         end;
         DrgFreeDragInfo(PDragInfo(PVoidFromMP(MP1))^);
      end;
      WM_Close : begin
         WinStoreWindowPos('NormalPlayer','MainWindow',Frame);
         PRFWriteProfileData(HINI_Profile,'NormalPlayer','Spacing',@Boarder,SizeOf(Boarder));
         PRFWriteProfileData(HINI_Profile,'NormalPlayer','TextIcon',@CurrTextIcon,SizeOf(CurrTextIcon));
         result:=WinDefWindowProc(Window,Msg,MP1,MP2);
      end
      else begin
         result:=WinDefWindowProc(Window,Msg,MP1,MP2);
      end;
      end;
   except
      on E : EMCIErr do WinMessageBox(HWND_DESKTOP,Client,pchar(E.Message),'Normal Player MMOS/2 Error',0,MB_OK+MB_ERROR+MB_MOVEABLE);
   end;
end;

type
   TColorParm = record
      id : ULONG;
      cb : ULONG;
      ab : Color;
   end;
   TColorPresParm = record
      cb : ULong;
      ColorParm : TColorParm;
   end;
var
   Msg : QMsg;
   CreateFlags : ULong;
   ColorAttr : COLOR;
   ColorPresParm : TColorPresParm;
begin
   Initing:=true;
   ab:=WinInitialize(0);
   mq:=WinCreateMsgQueue(ab,0);
   WinRegisterClass(ab,'NPLAY',NPlayWndProc,0,0);
   DeviceId:=0;
   Counter:=0;
   CountStr:='';{
   DrawTicks:=true;}
   Boarder:=5;
   CurrTextIcon:=tiTextIcon;
   ManualSlide:=true;
   Createflags:=FCF_TITLEBAR+FCF_SYSMENU+FCF_SIZEBORDER+FCF_MINBUTTON+FCF_MAXBUTTON+FCF_SHELLPOSITION+FCF_TASKLIST+FCF_ICON+FCF_AUTOICON+FCF_MENU+FCF_ACCELTABLE;
   Frame:=WinCreateStdWindow(HWND_DESKTOP,WS_VISIBLE,CreateFlags,'NPLAY','Normal Player',WS_CLIPCHILDREN,0,MainId,@Client);
   while WinGetMsg(ab,Msg,0,0,0) do WinDispatchMsg(ab,Msg);
   WinDestroyWindow(Frame);
   WinDestroyMsgQueue(mq);
   WinTerminate(ab)
end.
