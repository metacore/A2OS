MODULE VideoExample; (** AUTHOR "fnecati"; PURPOSE "V4L2 support for UnixAos"; *)

(*  AUTHOR "thomas.frey@alumni.ethz.ch"; PURPOSE "Webcam support for WinA2"; *)
(* PH 100317: proposal for more video formats from webcams and built-in cameras delivering YUV422 data *)
(* fnecati: adapted to UnixAos using V4L2 library *)

IMPORT
	Modules, Kernel, KernelLog, SYSTEM, Unix,  WMDialogs, Math:=MathL,
	WM := WMWindowManager, Strings, WMRectangles, WMGraphics, Raster,
	Commands, Streams, WMComponents, WMStandardComponents,
	lib := libv4l2, V := V4L2, WMMessages, WMEditors, Files; (* FreeImageUtils; *)

CONST deviceName0 = "/dev/video0";
	
TYPE
	FrameHandler* = PROCEDURE {DELEGATE} (buffer32 : Raster.Image);

	KillerMsg = OBJECT
	END KillerMsg;

TYPE ControlWindow = OBJECT(WMComponents.FormWindow)
		VAR 
			fd: SIGNED32;
			pan: WMStandardComponents.Panel;

		PROCEDURE &New(f: SIGNED32);
		BEGIN
			fd := f;
			
			pan := CreateControls();
			Init(pan.bounds.GetWidth(), pan.bounds.GetHeight(), FALSE);

			SetContent(pan);
			SetTitle(Strings.NewString("Video Controls"));
		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				END
			ELSE Handle^(x)
			END
		END Handle;
		
		PROCEDURE CreateControls(): WMStandardComponents.Panel;
		VAR 
			queryctrl: V.v4l2_queryctrl;
			id, err: SIGNED32;	
			pan: WMStandardComponents.Panel;
			en: WMEditors.TextField;
			lb: WMStandardComponents.Label;
			cb: WMStandardComponents.Button;
			cnt: SIGNED32;
			i, j: SIGNED32;
			qmenu: V.v4l2_querymenu;
			
			PROCEDURE MakeEdit( x, y: SIZE; ctrl: V.v4l2_queryctrl): WMEditors.TextField;
			VAR e: WMEditors.TextField;
				str: ARRAY 128 OF CHAR;
				val: SIGNED32;
			BEGIN
				Strings.AppendInt(str, ctrl.id);
				NEW(e); e.uid.SetAOC(str);
				e.bounds.Set(WMRectangles.MakeRect(x, y, x+60, y+25));
				e.type.Set(WMEditors.Decimal);
				val := GetControl(fd, ctrl.id);
				str := ""; Strings.AppendInt(str, val);
				e.SetAsString(str);
				e.alignment.Set(WMComponents.AlignNone);
				e.onEnter.Add(TextFieldHandler);
				IF V.CTRL_FLAG_DISABLED IN ctrl.flags THEN e.enabled.Set(FALSE); END;
				IF V.CTRL_FLAG_INACTIVE IN ctrl.flags THEN e.readOnly.Set(TRUE); END;
				RETURN e;
			END MakeEdit;

			PROCEDURE MakeLabel( x, y: SIZE; ctrl: V.v4l2_queryctrl): WMStandardComponents.Label;
			VAR l: WMStandardComponents.Label;
			BEGIN
				NEW(l); 
				l.bounds.Set(WMRectangles.MakeRect(x, y, x+100, y+25));
				l.caption.SetAOC(ctrl.name);				
				l.alignment.Set(WMComponents.AlignNone);
				RETURN l;
			END MakeLabel;

			PROCEDURE MakeCheckBox( x, y: SIZE; ctrl: V.v4l2_queryctrl): WMStandardComponents.Button;
			VAR b: WMStandardComponents.Button;
				str: ARRAY 128 OF CHAR;
				val: SIGNED32;
			BEGIN
				Strings.AppendInt(str, ctrl.id);				
				NEW(b); b.uid.SetAOC(str);
				b.bounds.Set(WMRectangles.MakeRect(x, y, x+25, y+25));
			(* 	b.caption.SetAOC(ctrl.name);*)
				b.alignment.Set(WMComponents.AlignNone);
				(* b.hasThreeStates.Set(FALSE); *)
				b.isToggle.Set(TRUE); 
				val := GetControl(fd, ctrl.id);
				b.SetPressed(val=1);
				IF val=1 THEN b.caption.SetAOC("x") ELSE b.caption.SetAOC("") END;
				b.onClick.Add(CheckboxHandler);
				RETURN b;
			END MakeCheckBox;

			PROCEDURE MakeMenu( x, y: SIZE; ctrl: V.v4l2_querymenu): WMStandardComponents.Button;
			VAR b: WMStandardComponents.Button;
				str: ARRAY 128 OF CHAR;
				val: SIGNED32;
			BEGIN
				Strings.AppendInt(str, ctrl.id);
				NEW(b); b.uid.SetAOC(str);
				b.bounds.Set(WMRectangles.MakeRect(x, y, x+75, y+25));
			(* 	b.caption.SetAOC(ctrl.name);*)
				b.alignment.Set(WMComponents.AlignNone);
				(* b.hasThreeStates.Set(FALSE); *)
				b.isToggle.Set(TRUE); 
				b.caption.SetAOC(ctrl.name); 
				b.onClick.Add(MenuHandler);
				RETURN b;
			END MakeMenu;
			
		BEGIN
			NEW(pan); pan.alignment.Set(WMComponents.AlignClient);
			pan.bounds.Set(WMRectangles.MakeRect(0, 0, 300, 400));
			pan.fillColor.Set(0CCCCCCCCH);
					
			queryctrl.id := SYSTEM.VAL(SIGNED32, {V.CTRL_FLAG_NEXT_CTRL});
			WHILE xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl)) > - 1 DO

				(*IF V.CTRL_FLAG_DISABLED IN queryctrl.flags THEN
					out.String(queryctrl.name); out.String(" is disabled"); out.Ln; out.Update;
				ELSE *)
					IF queryctrl.type = V.CTRL_TYPE_INTEGER THEN (* editor *)
						INC(cnt);
						lb := MakeLabel(10, cnt*30, queryctrl);
						en := MakeEdit(lb.bounds.GetWidth()+13, cnt*30, queryctrl);
						pan.AddContent(lb);
						pan.AddContent(en);
					ELSIF queryctrl.type = V.CTRL_TYPE_BOOLEAN THEN (* checkbox *)
						INC(cnt);
						lb := MakeLabel(10, cnt*30, queryctrl);
						cb := MakeCheckBox(lb.bounds.GetWidth()+13, cnt*30, queryctrl);
						pan.AddContent(lb);
						pan.AddContent(cb);
					ELSIF queryctrl.type = V.CTRL_TYPE_MENU THEN
						INC(cnt);
						lb := MakeLabel(10, cnt*30, queryctrl);
						pan.AddContent(lb);

					
						FOR j :=  queryctrl.minimum TO queryctrl.maximum+1 DO
							qmenu.id :=queryctrl.id;
							qmenu.index := j;
							err := xioctl (fd, V.VIDIOC_QUERYMENU, ADDRESSOF(qmenu));
							IF err # -1 THEN
								cb := MakeMenu(lb.bounds.GetWidth()+j*75, cnt*30, qmenu);
								pan.AddContent(cb);

								out.String("qmenu.id= "); out.Int(qmenu.id, 0); out.Ln; 
								out.String("qmenu.index= "); out.Int(qmenu.index, 0); out.Ln; 
								out.String("qmenu.name= "); out.String(qmenu.name); out.Ln;								
							END;
						END;
					ELSIF queryctrl.type = V.CTRL_TYPE_BUTTON THEN
						out.String("CTRL_TYPE_BUTTON"); out.Ln; 
					ELSIF queryctrl.type = V.CTRL_TYPE_INTEGER64 THEN
						out.String("CTRL_TYPE_INTEGER64"); out.Ln;
					ELSIF queryctrl.type = V.CTRL_TYPE_CTRL_CLASS THEN
						out.String("CTRL_TYPE_CTRL_CLASS: ");
							out.String("queryctrl.name: "); out.String(queryctrl.name); out.Ln; 
							out.String("queryctrl.id: "); out.Int(queryctrl.id, 0); out.Ln; 
							out.String("queryctrl.type: "); out.Int(queryctrl.type, 0); out.Ln; 
						out.Ln;
					ELSIF queryctrl.type = V.CTRL_TYPE_STRING THEN
						out.String("CTRL_TYPE_STRING"); out.Ln; 
					ELSIF queryctrl.type = V.CTRL_TYPE_BITMASK THEN
							out.String("V.CTRL_TYPE_BITMASK"); out.Ln; 
					ELSE
						out.String("queryctrl.name= "); out.String(queryctrl.name); out.Ln;
						out.String("queryctrl.id:"); out.Int(queryctrl.id, 0);
						out.String(" queryctrl.type:"); out.Int(queryctrl.type, 0);
						out.String(" queryctrl.flags: "); out.Set(queryctrl.flags);
						out.Ln; 
	
					END;
				(*END; *)
				queryctrl.id  := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET32, queryctrl.id) + {V.CTRL_FLAG_NEXT_CTRL});
			END;
			out.Update();
			RETURN pan;
		END CreateControls;
		
		PROCEDURE SetReadOnly(s: BOOLEAN);
		VAR c: WMComponents.VisualComponent;
			str: ARRAY 32 OF CHAR;	
		BEGIN
			 Strings.IntToStr(V.CID_BRIGHTNESS, str);
			 c := WMEditors.FindTextField(str, pan);
			 IF c # NIL THEN 
				 IF c IS WMEditors.TextField THEN 
				 	c(WMEditors.TextField).readOnly.Set(s)
				 END;
			END;			
		END SetReadOnly;
		
		PROCEDURE CheckboxHandler(sender, data: ANY);
		VAR b: WMStandardComponents.Button;
			id: SIGNED32;
			res: SIGNED32;
			checked: BOOLEAN;
		BEGIN
			b := sender(WMStandardComponents.Button);
			Strings.StrToInt(b.uid.Get()^, id);
			checked := b.GetPressed();
			IF checked THEN b.caption.SetAOC("x") ELSE b.caption.SetAOC("") END;
			res := ToggleControl(fd, id);
			IF id = V.CID_AUTOBRIGHTNESS THEN
				(*out.String("checkbox uid= "); out.Int(id, 0); out.Ln; *)
				IF checked THEN
					SetReadOnly(TRUE);	
				ELSE
					SetReadOnly(FALSE)
				END;
			END;	
		END CheckboxHandler;

		PROCEDURE TextFieldHandler(sender, data: ANY);
		VAR c: WMEditors.TextField;
			str: ARRAY 32 OF CHAR;
			id: SIGNED32;
			val, res: SIGNED32;
		BEGIN		
			 Strings.IntToStr(V.CID_BRIGHTNESS, str);
			 c := sender(WMEditors.TextField);
			 Strings.StrToInt(c.uid.Get()^, id);
			 c.GetAsString(str);
			 Strings.StrToInt(str, val);
			 res := SetControl(fd, id, val);	
		END TextFieldHandler;
		
		PROCEDURE MenuHandler(sender, data: ANY);
		BEGIN
			out.String("MenuHandler"); out.Ln; out.Update();
		END MenuHandler;
		
	END ControlWindow;
		
	PreviewWindow = OBJECT (WM.BufferWindow);
		VAR startX, startY, stopX, stopY: FLOAT64; (* measurement points *)
				labelw, labelh: SIZE;
		PROCEDURE &New(width, height : SIGNED32; CONST title: ARRAY OF CHAR);
		BEGIN
			Init(width, height, FALSE);
			(* WM.AddWindow(SELF, 200, 200); *)
			WM.ExtAddWindow(SELF, 200, 200, {WM.FlagFrame, WM.FlagClose, WM.FlagNoResizing});
			SetTitle(Strings.NewString(title));
			canvas.SetFont(WMGraphics.GetFont("Vera",	10, {}));
			canvas.GetFont().GetStringSize("O", labelw, labelh);
		END New;
		
		(* Overwrite draw procedure because we do not want any interpolation *)
		PROCEDURE Draw(canvas : WMGraphics.Canvas; w, h: SIZE; q : INTEGER);
		BEGIN
			Draw^(canvas, w, h, 0);
		END Draw;
		
		PROCEDURE Update;
		VAR sx, sy, dxy, teta: FLOAT64;
			sxs, sys: ARRAY 32 OF CHAR;
			str: ARRAY 128 OF CHAR;	
			rect: WMRectangles.Rectangle;	
		BEGIN			
			canvas.DrawImage(0, 0, buffer32, WMGraphics.ModeCopy);
			IF showms THEN
				canvas.SetColor(WMGraphics.Red);
				canvas.DrawString(5, 12, timestr);
			END;
			IF showRuler THEN

				
				rect := WMRectangles.MakeRect( 10, 10, GetWidth()-10, labelh+10);
				canvas.Fill( rect, WMGraphics.Yellow, WMGraphics. ModeSrcOverDst);
				canvas.SetColor(WMGraphics.Black);
				
				(* show vector dx, dy, magnitude and angle *)
				Strings.IntToStr(ENTIER(startX), sxs); 
				Strings.IntToStr(ENTIER(startY), sys); 
				str := "("; Strings.Append(str, sxs); Strings.Append(str, ",");
				Strings.Append(str, sys);
				
				Strings.Append(str,") (");
				sx := (stopX - startX)*scaleX;
				sy := (stopY - startY)*scaleY;
				Strings.FloatToStr(sx, 0, 1,0, sxs); 
				Strings.FloatToStr(sy, 0, 1,0, sys); 
				Strings.Append(str, sxs); Strings.Append(str, ",");
				Strings.Append(str, sys); Strings.Append(str,"),");
				
				(* calc magnitude *)				
				dxy := Math.sqrt(sx*sx + sy*sy);				
				Strings.FloatToStr(dxy, 0, 1, 0, sys);
				Strings.Append(str, " r:" );
				Strings.Append(str, sys);
				(* calc angle in degrees *)
				Strings.Append(str, " ang:");
				teta := atan2(-sy, sx)*180/Math.pi; (* degrees *)
				Strings.FloatToStr(teta, 0, 1, 0, sys);
				Strings.Append(str, sys);
				
				WMGraphics.DrawStringInRect(canvas, rect, FALSE, WMGraphics.AlignCenter, WMGraphics.AlignTop, str);
				
				canvas.Line(ENTIER(startX), ENTIER(startY), ENTIER(stopX +0.5), ENTIER(stopY+0.5), WMGraphics.Red, WMGraphics.ModeSrcOverDst(*ModeCopy*));
			END;
			Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))						
		END Update;
		
		PROCEDURE KeyEvent (ucs: SIZE; flags: SET; keysym: SIZE);
		BEGIN
			CASE CHR(ucs) OF
				| "s": SaveImage;
				| "q": Close;
				| "m": showms := ~showms;
				|  "r": showRuler := ~showRuler;
			ELSE
			END;
		END KeyEvent;

		PROCEDURE PointerMove (x, y : SIZE; keys : SET);
		BEGIN
			IF 0 IN keys THEN  (* ML: measure started *)
				showRuler := TRUE;
				stopX :=  x;
				stopY := y;
				Update();				
			END;
		END PointerMove;
		
		PROCEDURE PointerDown (x, y : SIZE; keys : SET);
		BEGIN
			startX := x;
			startY := y;
		END PointerDown;
 
 		PROCEDURE PointerUp (x, y : SIZE; keys : SET);
		BEGIN
			showRuler := FALSE;
		END PointerUp;
        	
		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				END
			ELSE Handle^(x)
			END
		END Handle;
					
		PROCEDURE SaveImage;
		VAR res: SIGNED32;
		BEGIN
			IF WMDialogs.QueryString(" Save File name:", filename) = WMDialogs.ResOk THEN
				WMGraphics.StoreImage(img, filename,res); 
				(* FreeImageUtils.StoreImage2(buffer32, filename); *)
			END;
		END SaveImage;
					
	END PreviewWindow;

	Starter = OBJECT
	VAR opened, stopped : BOOLEAN;
		timer: Kernel.Timer;
		
		PROCEDURE &New();
		BEGIN
			stopped := FALSE;
			opened := TRUE;
			NEW(timer);
		END New;
		
		PROCEDURE Start;
		BEGIN {EXCLUSIVE}
			stopped := FALSE;
			opened := TRUE;
		END Start;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			stopped := TRUE;
			opened := FALSE;
			out.String("Stoped"); out.Ln; out.Update;
		END Stop;


	BEGIN {ACTIVE}
		WHILE opened DO
			IF ~ stopped THEN 	
				FrameReceived();
			(*	Objects.Yield();*)
				(* Objects.Sleep( 20); *)				
			END;
			timer.Sleep(20);
		END;	
		
		(*CloseDevice();*)

	END Starter;

VAR
	controlWin: ControlWindow;
	deviceName: ARRAY 16 OF CHAR;
	preview : PreviewWindow;
	out: Streams.Writer;
	
	fd: SIGNED32; (* device file handle *)
	buffer, buffer32 : WMGraphics.Image;  (* captured image buffer *)
	mode: Raster.Mode;
	starter : Starter;
	camWidth, camHeight: SIGNED32;
	showms: BOOLEAN;
	
	frameHandler : FrameHandler;
	timestr: ARRAY 16 OF CHAR;	
	filename :="captured1.bmp" : ARRAY 128 OF CHAR;
	showRuler: BOOLEAN;
	scaleX := 1.0: FLOAT64; (* default measurement scales *)
	scaleY := 1.0: FLOAT64;
	
	dummyimg: WMGraphics.Image;

(* http://en.wikipedia.org/wiki/Atan2 *)
PROCEDURE atan2(y, x: FLOAT64): FLOAT64; (*arctan in range -pi .. pi *)
BEGIN
	IF (x > 0)  THEN RETURN Math.arctan(y/x)
	ELSIF (y >= 0) & (x < 0) THEN RETURN Math.arctan(y/x)+Math.pi
	ELSIF (y < 0 ) & (x < 0) THEN RETURN Math.arctan(y/x)-Math.pi
	ELSIF (y > 0) & (x = 0) THEN RETURN Math.pi/2
	ELSIF (y < 0) & (x  = 0) THEN RETURN -Math.pi/2
	ELSE (*( y=0) & (x=0) *) RETURN 0 (*or RETURN NaN ?*)
	END
END atan2;
		
PROCEDURE ReadFrame(): BOOLEAN;
VAR
	fds: Unix.FdSet;
	tv: Unix.Timeval;
	r: SIGNED32;
	bufsize: SIZE;
	(* --------for ioctl ------------ *)
	PROCEDURE FDZERO(VAR fs: Unix.FdSet);
	VAR i: SIGNED32;
	BEGIN 
		FOR i:=0 TO LEN(fs)-1 DO fs[i] := {}; END;
	END FDZERO;

	PROCEDURE FDSET(fd: SIGNED32; VAR fs: Unix.FdSet);
	BEGIN 
		INCL( fs[fd DIV Unix.FdSetLen],  fd MOD Unix.FdSetLen );	
	END FDSET;
	
BEGIN
		
	FDZERO(fds);
	FDSET(fd, fds);
	tv.sec := 2;
	tv.usec := 0;
	r := Unix.select(fd+1,  ADDRESSOF(fds), NIL, NIL, tv);
	IF r = -1 THEN RETURN FALSE END;
	bufsize := buffer.width*buffer.height*3;
	 IF -1 = lib.read(fd, ADDRESSOF(buffer.mem[0]), bufsize) THEN
	 	RETURN FALSE;
	END;
	(* convert to BGRA8888 image *)
	
	Raster.Copy(buffer, buffer32, 0, 0, buffer.width, buffer.height, 0, 0, mode);
	(* CovertToGray(buffer32); *)
	RETURN TRUE;
END ReadFrame;

(* Get buffer as 32 bit BGRA image *)
PROCEDURE GetImage*(): WMGraphics.Image;
BEGIN 
	RETURN buffer32;
END GetImage;

(** Get buffer as 24 bit BGR image *)
PROCEDURE GetImageBGR*(): WMGraphics.Image;
BEGIN 
	RETURN buffer;
END GetImageBGR;

PROCEDURE CloseDevice();
VAR err: SIGNED32;
BEGIN
	IF fd > 0 THEN	
 		err := lib.close(fd);
 		out.String(deviceName); out.String(" closed"); out.Ln; 
 		fd := 0;
 	ELSE
 		(* out.String(deviceName);*)  out.String(" is allready closed"); out.Ln; 
	END; 
	out.Update();
END CloseDevice;

PROCEDURE OpenDevice(CONST devicename: ARRAY OF CHAR): BOOLEAN;
BEGIN
 	fd := lib.open(devicename, Unix.rdwr, 0);
 	IF fd = -1 THEN
 		out.String("Error: Could not open video device : "); out.String(deviceName);
 		RETURN FALSE;
 	END;	
	out.String("video device opened: "); out.String(deviceName);
	out.Ln; out.Update();
	RETURN (fd > 0);
END OpenDevice;

PROCEDURE EnumerateFrameSizes*;
VAR 

     frmsize: V.v4l2_frmsizeenum;
     err: SIGNED32;
     discrete: V.v4l2_frmsize_discrete;
     stepwise: V.v4l2_frmsize_stepwise;
     
BEGIN
	frmsize.pixel_format := V.PIX_FMT_BGR24;
	frmsize.index := 0;
	err :=  xioctl(fd, V.VIDIOC_ENUM_FRAMESIZES, ADDRESSOF(frmsize));

	IF (err >= 0) THEN
		IF frmsize.type = V.FRMSIZE_TYPE_DISCRETE THEN
		
			REPEAT
				discrete := SYSTEM.VAL(V.v4l2_frmsize_discrete, frmsize.frame);
				out.Int(frmsize.index, 0); out.String(". frame width x height = "); out.Int(discrete.width, 0);
				out.Int(discrete.height, 5); out.Ln;
				frmsize.index := frmsize.index + 1;
			UNTIL xioctl(fd, V.VIDIOC_ENUM_FRAMESIZES, ADDRESSOF(frmsize)) < 0;
			
		ELSIF frmsize.type = V.FRMSIZE_TYPE_CONTINUOUS THEN
				out.String("FRMSIZE_TYPE_CONTINUOUS"); out.Ln;
		ELSIF frmsize.type = V.FRMSIZE_TYPE_STEPWISE THEN
				out.String("FRMSIZE_TYPE_STEPWISE"); out.Ln;
		END;
	ELSE
		out.String("Error: "); out.Int(err, 0); out.Ln; 
	END;
	out.Update();
END EnumerateFrameSizes;

PROCEDURE PrintCapabilities*;
VAR
	cap: V.v4l2_capability;
	cropcap: V.v4l2_cropcap;
	crop: V.v4l2_crop;
	fmt: V.v4l2_format;
	min: SIGNED32;	
 	pix: V.v4l2_pix_format;
 	fmtdesc: V.v4l2_fmtdesc;
 	
	err, i: SIGNED32;
BEGIN
	err := xioctl(fd, V.VIDIOC_QUERYCAP, ADDRESSOF(cap));

	out.String("------------------------------"); out.Ln; 
	out.String("VIDIOC_QUERYCAP:"); out.Ln; 
	out.String("cap.driver= "); out.String(cap.driver); out.Ln; 
	out.String("cap.card= "); out.String(cap.card); out.Ln; 
	out.String("cap.businfo= "); out.String(cap.bus_info); out.Ln; 

	out.String("------------------------------"); out.Ln; 	
	IF V.CAP_VIDEO_CAPTURE IN cap.capabilities THEN out.String(" is video capture device, ");END;
	IF V.CAP_VIDEO_OUTPUT IN cap.capabilities THEN out.String(" is video output device, ");END;
	IF V.CAP_VIDEO_OVERLAY IN cap.capabilities THEN out.String(" can do overlay, ");END;
	IF V.CAP_VBI_CAPTURE IN cap.capabilities THEN out.String(" Is a raw VBI capture device, ");END;
	IF V.CAP_VBI_OUTPUT IN cap.capabilities THEN out.String(" Is a raw VBI output device, ");END;
	IF V.CAP_SLICED_VBI_CAPTURE IN cap.capabilities THEN out.String(" Is a sliced VBI capture device, ");END;
	IF V.CAP_SLICED_VBI_OUTPUT IN cap.capabilities THEN out.String(" Is a sliced VBI output device, ");END;
	IF V.CAP_RDS_CAPTURE IN cap.capabilities THEN out.String(" RDS data capture, ");END;
	IF V.CAP_VIDEO_OUTPUT_OVERLAY IN cap.capabilities THEN out.String(" Can do video output overlay, ");END;
	
	IF V.CAP_HW_FREQ_SEEK IN cap.capabilities THEN out.String(" Can do hardware frequency seek, ");END;
	IF V.CAP_RDS_OUTPUT IN cap.capabilities THEN out.String(" Is an RDS encoder, ");END;
	IF V.CAP_TUNER IN cap.capabilities THEN out.String(" has a tuner, ");END;
	IF V.CAP_AUDIO IN cap.capabilities THEN out.String(" has audio support, ");END;
	IF V.CAP_RADIO IN cap.capabilities THEN out.String(" is a radio device, ");END;
	IF V.CAP_MODULATOR IN cap.capabilities THEN out.String(" has a modulator, ");END;
	IF V.CAP_READWRITE IN cap.capabilities THEN out.String(" supports read i/o, "); END;
	IF V.CAP_ASYNCIO IN cap.capabilities THEN out.String(" async I/O, ");END;
	IF V.CAP_STREAMING IN cap.capabilities  THEN	out.String(" supports streaming i/o ioctls"); out.Ln; END;
	out.Ln; 
	
	(* formats *)
	i := 0;
	fmtdesc.index := 0;
	fmtdesc.type  := V.BUF_TYPE_VIDEO_CAPTURE;
	WHILE xioctl(fd, V.VIDIOC_ENUM_FMT, ADDRESSOF(fmtdesc))  > - 1 DO
		out.String("fmtdesc.index= "); out.Int(fmtdesc.index, 0); out.Ln; 
		out.String("fmtdesc.type= "); out.Int(fmtdesc.type, 0); out.Ln; 
		out.String("fmtdesc.description= "); out.String(fmtdesc.description); out.Ln; 
		out.String("fmtdesc.pixelformat= "); out.Int(fmtdesc.pixelformat, 0); out.Ln;
		INC(i);
		fmtdesc.index := i;
	END;
	out.Update();
END PrintCapabilities;

PROCEDURE InitDevice(): BOOLEAN;
VAR
	cap: V.v4l2_capability;
	cropcap: V.v4l2_cropcap;
	crop: V.v4l2_crop;
	fmt: V.v4l2_format;
	min: V.u32;	
 	pix: V.v4l2_pix_format;
	err: SIGNED32;
	
BEGIN
    out.String("errno-initdev-0: "); out.Int(Unix.errno(), 0); out.Ln;        
	err := xioctl(fd, V.VIDIOC_QUERYCAP, ADDRESSOF(cap));
   out.String("errno-initdev-1: "); out.Int(Unix.errno(), 0); out.Ln;      
	out.String("------------------------------"); out.Ln; 
	out.String("VIDIOC_QUERYCAP:"); out.Ln; 
	out.String("cap.driver= "); out.String(cap.driver); out.Ln; 
	out.String("cap.card= "); out.String(cap.card); out.Ln; 
	out.String("cap.businfo= "); out.String(cap.bus_info); out.Ln; 

	out.String("------------------------------"); out.Ln; out.Update();
	IF ~ (V.CAP_VIDEO_CAPTURE IN cap.capabilities) THEN
		out.String(deviceName); out.String(" is not video capture device"); out.Ln; out.Update();
		RETURN FALSE;
	ELSE
		out.String(deviceName); out.String(" is  video capture device"); out.Ln; out.Update();
	END;

	IF ~(V.CAP_READWRITE IN cap.capabilities) THEN
		out.String(deviceName); out.String(" does not support read i/o"); out.Ln; out.Update();
		RETURN FALSE	
	ELSE
		out.String(deviceName); out.String(" supports read i/o"); out.Ln;	
	END;

	IF ~ (V.CAP_STREAMING IN cap.capabilities)  THEN
		out.String(deviceName); out.String(" does not support streaming i/o"); out.Ln; out.Update();
	ELSE 	
		out.String(deviceName); out.String(" supports streaming i/o"); out.Ln; out.Update();
	END;

(* Select video input, video standard and tune here. *)

(*	cropcap.type := V.BUF_TYPE_VIDEO_CAPTURE; 	(* -------- *)
	IF 0 = xioctl(fd, V.VIDIOC_CROPCAP, ADDRESSOF(cropcap)) THEN
		crop.type := V.BUF_TYPE_VIDEO_CAPTURE;
		crop.c := cropcap.defrect; (* reset to default *)
		IF (-1 = xioctl(fd, V.VIDIOC_S_CROP, ADDRESSOF(crop))) THEN
			IF Unix.EINVAL=Unix.errno()  THEN
				out.String("Cropping not supported."); out.Ln; 
			END;
		END;
	END;
*)
      out.String("errno-0: "); out.Int(Unix.errno(), 0); out.Ln;               
	fmt.type := V.BUF_TYPE_VIDEO_CAPTURE;
 	    
	pix.width := camWidth;
	pix.height := camHeight;
	pix.pixelformat := V.PIX_FMT_BGR24; (*V.PIX_FMT_YUV420;*)
	pix.field := V.FIELD_INTERLACED;
(*	pix.field := V.FIELD_NONE; *)
	fmt.fmt := SYSTEM.VAL(V.D200, pix);
 
	IF -1 = xioctl(fd, V.VIDIOC_S_FMT, ADDRESSOF(fmt) ) THEN
		out.String("errno: "); out.Int(Unix.errno(), 0); out.Ln;               
		out.String("error: VIDIOC_S_FMT."); out.Ln; out.Update();
		
	END;
    
	(* Note VIDIOC_S_FMT may change width and height. *)
    
	(* Buggy driver paranoia. *)
	pix := SYSTEM.VAL(V.v4l2_pix_format, fmt.fmt); (* convert union struct to pix_format type *)
	
	out.Int(V.BUF_TYPE_VIDEO_CAPTURE, 5); out.Int(fmt.type, 10);  out.Ln;
	out.Int(pix.width, 0); out.Int(pix.height, 10); out.Ln;
	out.Hex(V.PIX_FMT_BGR24, 4); out.String(" ?? "); out.Hex(pix.pixelformat, 4); out.Ln;
	
	 out.Update;

	
	IF pix.pixelformat # V.PIX_FMT_BGR24 THEN
		out.String("libv4l didn't accept BGR24 format."); out.Ln; out.Update();
		RETURN FALSE
	END;

	IF (pix.width # camWidth) OR (pix.height # camHeight) THEN
		out.String("Warning: driver is sending image at ");
		out.Int(pix.width, 0);  out.String(" x "); out.Int(pix.height, 0); out.Ln; out.Update();
	END;
            
	min := pix.width * 2;
	IF (pix.bytesperline < min) THEN
		pix.bytesperline := min;
	END;        
	min := pix.bytesperline * pix.height;
	IF (pix.sizeimage < min) THEN
		pix.sizeimage := min;
	END;
	out.String("pix.sizeimage= "); out.Int(pix.sizeimage, 0); out.Ln; 
	out.String("pix.width= "); out.Int(pix.width, 0); out.Ln; 
	out.String("pix.height= "); out.Int(pix.height, 0); out.Ln; out.Update();
	
	camWidth := SIGNED32(pix.width);
	camHeight := SIGNED32(pix.height);

  	fmt.fmt := SYSTEM.VAL(V.D200, pix);

	NEW(buffer);
	Raster.Create(buffer, camWidth, camHeight, Raster.BGR888);
	NEW(buffer32);
	Raster.Create(buffer32, camWidth, camHeight, Raster.BGRA8888);
	RETURN TRUE
END InitDevice;

PROCEDURE xioctl(fh: SIGNED32; request: SIGNED32; arg: ADDRESS): SIGNED32;
BEGIN
	RETURN  lib.ioctl(fh, request, arg);
END xioctl;

PROCEDURE FrameReceived ();
VAR
	trap : BOOLEAN;
	t0, t1: SIGNED32;
	
BEGIN
	trap := TRUE;
	t0 := Kernel.GetTicks();
	
	IF ~ReadFrame() THEN RETURN END;
	
	IF (frameHandler # NIL) & (buffer32 # NIL) THEN frameHandler(buffer32) END;
	IF preview # NIL THEN
		(* preview.canvas.DrawImage(0, 0, buffer32, WMGraphics.ModeCopy);*)
		t1 :=  Kernel.GetTicks();
		t0 := t1 - t0;
		Strings.IntToStr(t0, timestr);
		preview.Update();
		(*preview.Invalidate(WMRectangles.MakeRect(0, 0, preview.GetWidth(), preview.GetHeight())) *)
	END;		
	trap := FALSE;
FINALLY
	IF trap THEN
		out.String("Handler failed, removing it."); out.Ln; out.Update();
		frameHandler := NIL
	END;
END FrameReceived;

PROCEDURE Start*(context: Commands.Context); (* [devicename], ex: /dev/video1 *)
VAR devicestr: ARRAY 64 OF CHAR;
BEGIN
	IF context.arg.GetString(devicestr) THEN 
		COPY(devicestr, deviceName);
	ELSE COPY(deviceName0, deviceName);	
	END;	

	IF fd > 0 THEN
		IF starter # NIL THEN starter.Stop(); END;
		CloseDevice();
	END;	
	IF OpenDevice(deviceName) THEN
		IF InitDevice() THEN NEW(starter); END;
	ELSE
		CloseDevice();	
	END;	
END Start;

PROCEDURE Stop*;
BEGIN
	IF starter # NIL THEN
		starter.Stop;
		frameHandler := NIL;
		starter := NIL;
	END;	
END Stop;

PROCEDURE EnumControls*;
VAR 
	queryctrl: V.v4l2_queryctrl;
	id, err: SIGNED32;
	
	PROCEDURE EnumerateMenus;
	VAR k: SIGNED32;
		querymenu: V.v4l2_querymenu;
	BEGIN
		out.String("   Menu items: "); out.Ln; out.Update();
		FOR k := queryctrl.minimum TO queryctrl.maximum DO
			querymenu.index := k;
			IF (0 = xioctl (fd, V.VIDIOC_QUERYMENU, ADDRESSOF(querymenu))) THEN
				out.String(querymenu.name); out.Ln; out.Update;
			END;
		END;
	END EnumerateMenus;
	
BEGIN
	FOR id := V.CID_BASE TO V.CID_LASTP1 -1 DO
		queryctrl.id := id;
		err := xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl));
		IF err >= 0 THEN
			IF V.CTRL_FLAG_DISABLED IN queryctrl.flags THEN
				out.String(queryctrl.name); out.String(" is disabled"); out.Ln; out.Update;
			ELSE
				out.String("queryctrl.name= "); out.String(queryctrl.name); out.Ln;
				out.String("queryctrl.id:"); out.Int(queryctrl.id, 0);
				out.String(" queryctrl.type:"); out.Int(queryctrl.type, 0);
				out.String(" queryctrl.flags: "); out.Set(queryctrl.flags);
				out.Ln; out.Update();
				IF queryctrl.type = V.CTRL_TYPE_MENU THEN							
					EnumerateMenus();
				END;	
			END;
		END;
	END;

(*
(* ------------------------------------ *)	
	FOR id := V.CID_PRIVATE_BASE TO V.CID_PRIVATE_BASE+100 DO
		queryctrl.id := id;
		err := xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl));
		IF err >= 0 THEN
			IF V.CTRL_FLAG_DISABLED IN queryctrl.flags THEN
				out.String(queryctrl.name); out.String(" is disabled"); out.Ln; out.Update;
			ELSE
				out.String("queryctrl.name= "); out.String(queryctrl.name); out.Ln;
				out.String("queryctrl.id:"); out.Int(queryctrl.id, 0);
				out.String(" queryctrl.type:"); out.Int(queryctrl.type, 0);
				out.String(" queryctrl.flags: "); out.Set(queryctrl.flags);
				out.Ln; out.Update();
				IF queryctrl.type = V.CTRL_TYPE_MENU THEN							
					EnumerateMenus();
				END;	
			END;
		END;
	END;
*)	
	(* extended controls *)
	out.String("extended controls:"); out.Ln; 
	queryctrl.id := SYSTEM.VAL(SIGNED32, {V.CTRL_FLAG_NEXT_CTRL});
	WHILE xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl)) = 0 DO
			out.String("queryctrl.name= "); out.String(queryctrl.name); out.Ln;
			out.String("queryctrl.id:"); out.Int(queryctrl.id, 0);
			out.String(" queryctrl.type:"); out.Int(queryctrl.type, 0);
			out.String(" queryctrl.flags: "); out.Set(queryctrl.flags);
			out.Ln; out.Update();
		queryctrl.id := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET32, queryctrl.id) +{V.CTRL_FLAG_NEXT_CTRL});
	END;
(*
	(* extended controls *)
		queryctrl.id := id;
		err := xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl));
		IF err >= 0 THEN
			IF V.CTRL_FLAG_DISABLED IN queryctrl.flags THEN
				out.String(queryctrl.name); out.String(" is disabled"); out.Ln; out.Update;
			ELSE
				out.String("queryctrl.name= "); out.String(queryctrl.name); out.Ln;
				out.String("queryctrl.id:"); out.Int(queryctrl.id, 0);
				out.String(" queryctrl.type:"); out.Int(queryctrl.type, 0);
				out.String(" queryctrl.flags: "); out.Set(queryctrl.flags);
				out.Ln; out.Update();
				IF queryctrl.type = V.CTRL_TYPE_MENU THEN							
					EnumerateMenus();
				END;	
			END;
		END;
		*)
END EnumControls;

(*
(** *)
PROCEDURE SetBrightness*(par: Commands.Context);
VAR
	queryctrl : V.v4l2_queryctrl ;
	control: V.v4l2_control;
	val: SIGNED32;
BEGIN
	IF ~ par.arg.GetInteger(val, FALSE) THEN RETURN; END;
	
	queryctrl.id := V.CID_BRIGHTNESS;
	IF (-1 = xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl))) THEN
		IF Unix.errno() # Unix.EINVAL THEN
			out.String("VIDIOC_QUERYCTRL"); out.Ln; 
			RETURN;
	
		ELSE
			out.String ("CID_BRIGHTNESS is not supported"); out.Ln; 
		END;	

	ELSIF V.CTRL_FLAG_DISABLED IN queryctrl.flags THEN
			out.String ("CID_BRIGHTNESS is not supported"); out.Ln; 
			
	ELSE

		control.id := V.CID_BRIGHTNESS;
		control.value := val; (* queryctrl.default_value;*)

		IF (-1 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
			out.String ("VIDIOC_S_CTRL"); out.Ln; 
		END;
	END;
END SetBrightness;


(** set auto brightness menu control: on, off *)
PROCEDURE AutoBrightness*;
VAR
	querymenu : V.v4l2_querymenu;
	queryctrl : V.v4l2_queryctrl ;
	control: V.v4l2_control;
	val: SIGNED32;
BEGIN
	
	queryctrl.id := V.CID_AUTOBRIGHTNESS;
	
	IF (0 = xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl))) THEN
		out.String("found CID_AUTOBRIGHTNESS" ); out.Ln;
		out.String(queryctrl.name); out.Ln; 
		
		control.id := V.CID_AUTOBRIGHTNESS;
		IF (0 = xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(control))) THEN
			out.String("control.val= "); out.Int(control.value, 0); out.Ln;
			IF control.value= 0 THEN
				control.value := 1;
			ELSE
				control.value := 0;
			END;
			IF (-1 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
				out.String ("Error: Auto Brightness  VIDIOC_S_CTRL"); out.Ln; 
			END;
		ELSE
			out.String ("Error: Auto Brightness  VIDIOC_G_CTRL"); out.Ln; 	
		END;
(*		IF BIT.LAND(queryctrl.flags,  V.CTRL_FLAG_DISABLED)= V.CTRL_FLAG_DISABLED THEN
			
			out.String ("CID_AUTOBRIGHTNESS CTRL_FLAG_DISABLED"); out.Ln; 
		ELSE
			out.String ("CID_AUTOBRIGHTNESS -NOT- CTRL_FLAG_DISABLED"); out.Ln; 
		END;
		*)
	ELSE
		out.String ("CID_AUTOBRIGHTNESS is not found"); out.Ln; 
	END;	
END AutoBrightness;

(** *)
PROCEDURE SetContrast*(par: Commands.Context);
VAR
	queryctrl : V.v4l2_queryctrl ;
	control: V.v4l2_control;
	val: SIGNED32;
BEGIN
	IF ~ par.arg.GetInteger(val, FALSE) THEN RETURN; END;
	
		queryctrl.id := V.CID_CONTRAST;
		IF (-1 = xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(queryctrl))) THEN
			IF Unix.errno() # Unix.EINVAL THEN
				out.String("ERROR: SetContrast VIDIOC_QUERYCTRL"); out.Ln; 
				RETURN;
			ELSE
				out.String ("CID_CONTRAST is not supported"); out.Ln; 
			END;
			
		ELSE
			control.id := V.CID_CONTRAST;
			control.value := val; (* queryctrl.default_value;*)

			IF (-1 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
				out.String ("Error: SetContrast VIDIOC_S_CTRL"); out.Ln; 
			END;
		END;	
END SetContrast;

(** *)
PROCEDURE IncContrast*;
VAR
	queryctrl : V.v4l2_queryctrl;
	control: V.v4l2_control;
	val: SIGNED32;
BEGIN
	
	queryctrl.id := V.CID_CONTRAST;
	IF (0 = xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl))) THEN
	
		control.id := V.CID_CONTRAST;	
		IF (0 = xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(control))) THEN
			
			control.value := control.value + queryctrl.step; 
					
				(* The driver may clamp the value or return ERANGE, ignored here *)
			IF (0 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
			
			ELSE
				out.String ("Error: IncContrast VIDIOC_S_CTRL"); out.Ln;
			END;
		ELSE
			out.String ("Error: IncContrast VIDIOC_G_CTRL"); out.Ln; 		
		END;
	ELSE 
		out.String ("Error: IncContrast VIDIOC_QUERYCTRL"); out.Ln; 			
	END;

END IncContrast;

PROCEDURE DecContrast*;
VAR
	control: V.v4l2_control;
	val: SIGNED32;
BEGIN

	control.id := V.CID_CONTRAST;
	IF (0 = xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(control))) THEN	
		control.value := control.value - 10; (* queryctrl.default_value;*)

		(* The driver may clamp the value or return ERANGE, ignored here *)
		IF (-1 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
			IF  (Unix.errno() # Unix.ERANGE) THEN
				out.String ("Error: SetContrast VIDIOC_S_CTRL"); out.Ln; 
			END;
		END;
	ELSIF (Unix.errno() # Unix.EINVAL) THEN
		out.String ("Error: SetContrast VIDIOC_G_CTRL"); out.Ln; 
	END;
END DecContrast;

(** set flipvertical: on, off *)
PROCEDURE FlipVertical*;
VAR
	querymenu : V.v4l2_querymenu;
	queryctrl : V.v4l2_queryctrl ;
	control: V.v4l2_control;
	val: SIGNED32;
BEGIN
	
	queryctrl.id := V.CID_VFLIP;
	
	IF (0 = xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl))) THEN
		out.String("found V4L2_CID_VFLIP" ); out.Ln;
		out.String(queryctrl.name); out.Ln; 
		
		control.id := V.CID_VFLIP;
		IF (0 = xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(control))) THEN
			out.String("control.val= "); out.Int(control.value, 0); out.Ln;
			IF control.value= 0 THEN
				control.value := 1;
			ELSE
				control.value := 0;
			END;
			IF (-1 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
				out.String ("Error: FlipVertical VIDIOC_S_CTRL"); out.Ln; 
			END;
		ELSE
			out.String ("Error: FlipVertical  VIDIOC_G_CTRL"); out.Ln; 	
		END;
	ELSE
		out.String ("V4L2_CID_VFLIP is not found"); out.Ln; 
	END;	
END FlipVertical;

(** set fliphorizontal: on, off *)
PROCEDURE FlipHorizontal*;
VAR
	querymenu : V.v4l2_querymenu;
	queryctrl : V.v4l2_queryctrl ;
	control: V.v4l2_control;
	val: SIGNED32;
BEGIN
	
	queryctrl.id := V.CID_HFLIP;
	
	IF (0 = xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl))) THEN
		out.String("found V4L2_CID_HFLIP" ); out.Ln;
		out.String(queryctrl.name); out.Ln; 
		
		control.id := V.CID_HFLIP;
		IF (0 = xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(control))) THEN
			out.String("control.val= "); out.Int(control.value, 0); out.Ln;
			IF control.value= 0 THEN
				control.value := 1;
			ELSE
				control.value := 0;
			END;
			IF (-1 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
				out.String ("Error: FlipHorizontal VIDIOC_S_CTRL"); out.Ln; 
			END;
		ELSE
			out.String ("Error: FlipVertical  VIDIOC_G_CTRL"); out.Ln; 	
		END;
	ELSE
		out.String ("V4L2_CID_HFLIP is not found"); out.Ln; 
	END;	
END FlipHorizontal;
*)

(* ==================== *)
(*  return >= 0 ok otherwhise -1 *)
PROCEDURE IsControl (fd: SIGNED32; cid: V.u32;  VAR queryctrl: V.v4l2_queryctrl): SIGNED32;
VAR err: SIGNED32;
BEGIN
	queryctrl.id := cid;
	err := xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl));
	IF err < 0 THEN
		out.String("ioctl querycontrol error "); out.Int(err, 0); out.Ln; out.Update();
	ELSIF V.CTRL_FLAG_DISABLED IN queryctrl.flags THEN
		out.String("control "); out.String(queryctrl.name); out.String(" disabled"); out.Ln; out.Update();
  	ELSIF queryctrl.type = V.CTRL_TYPE_BOOLEAN THEN
		RETURN 1;
	ELSIF queryctrl.type =  V.CTRL_TYPE_INTEGER THEN
		RETURN 0;
	ELSE
		out.String("contol "); out.String(queryctrl.name); out.String(" unsupported"); out.Ln; out.Update();
	END;
	RETURN -1;
END IsControl;

PROCEDURE GetControl (fd: SIGNED32; cid: V.u32): SIGNED32;
VAR
	queryctrl: V.v4l2_queryctrl;
	scontrol: V.v4l2_control;
	err: SIGNED32;
BEGIN
	IF IsControl (fd, cid, queryctrl) < 0 THEN RETURN -1 END;
	scontrol.id := cid;  
	err := xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(scontrol));
	IF err < 0 THEN
		out.String("ioctl get control error"); out.Ln; out.Update();
		RETURN -1;
	END;
	RETURN scontrol.value;
END GetControl;

PROCEDURE SetControl (fd: SIGNED32; cid: SIGNED32; value: SIGNED32): SIGNED32;
VAR
	scontrol: V.v4l2_control;
	queryctrl: V.v4l2_queryctrl ;
	min, max, step, defval: SIGNED32;
	err: SIGNED32;
BEGIN
	IF IsControl (fd, cid, queryctrl) < 0 THEN RETURN -1; END;
	min := queryctrl.minimum;
	max := queryctrl.maximum;
	step := queryctrl.step;
	defval := queryctrl.default_value;
	IF ((value >= min) & (value <= max)) THEN
		scontrol.id := cid;
		scontrol.value := value;
		err := xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(scontrol));
		IF err < 0 THEN
			out.String("ioctl set control error"); out.Ln; out.Update();
			RETURN -1;
		END;
	END;
	RETURN 0;
END SetControl;

PROCEDURE UpControl (fd: SIGNED32; cid: SIGNED32): SIGNED32;
VAR
	scontrol: V.v4l2_control;
	queryctrl: V.v4l2_queryctrl ;
	min, max, current, step, defval: SIGNED32;
	err: SIGNED32;
BEGIN
	IF IsControl (fd, cid, queryctrl) < 0 THEN RETURN -1 END;
	min := queryctrl.minimum;
	max := queryctrl.maximum;
	step := queryctrl.step;
	defval := queryctrl.default_value;
	current := GetControl (fd, cid);
	INC(current, step);
	IF current <= max THEN
		scontrol.id := cid;
		scontrol.value := current;
		err := xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(scontrol));
		IF err < 0 THEN
			out.String("ioctl set control error"); out.Ln; out.Update();
			RETURN -1;
		END;
	END;
	RETURN scontrol.value;
END UpControl;

PROCEDURE DownControl (fd: SIGNED32; cid: SIGNED32): SIGNED32;
VAR
	scontrol: V.v4l2_control;
	queryctrl: V.v4l2_queryctrl ;
	min, max, current, step, defval: SIGNED32;
	err: SIGNED32;
BEGIN
	IF IsControl (fd, cid, queryctrl) < 0 THEN RETURN -1 END;
	min := queryctrl.minimum;
	max := queryctrl.maximum;
	step := queryctrl.step;
	defval := queryctrl.default_value;
	current := GetControl (fd, cid);
	DEC(current, step);
	IF current >= max THEN
		scontrol.id := cid;
		scontrol.value := current;
		err := xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(scontrol));
		IF err < 0 THEN
			out.String("ioctl set control error"); out.Ln; out.Update();
			RETURN -1;
		END;
	END;
	RETURN scontrol.value;
END DownControl;

PROCEDURE ToggleControl (fd: SIGNED32; cid: SIGNED32): SIGNED32;
VAR
	scontrol: V.v4l2_control;
	queryctrl: V.v4l2_queryctrl ;
	current: SIGNED32;
	err: SIGNED32;
BEGIN
	IF IsControl (fd, cid, queryctrl) # 1 THEN RETURN -1 END;
	current := GetControl (fd, cid);
	scontrol.id := cid;
	IF current=0 THEN scontrol.value := 1 ELSE scontrol.value := 0; END;
	
	err := xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(scontrol)); 
	IF err< 0 THEN
		out.String("ioctl toggle control error"); out.Ln; out.Update();
		RETURN -1;
	END;
	RETURN scontrol.value;
END ToggleControl;

PROCEDURE ResetControl (fd: SIGNED32; cid: V.u32 ): SIGNED32;
VAR
	scontrol: V.v4l2_control;
	queryctrl: V.v4l2_queryctrl;
	defval: SIGNED32;
	err: SIGNED32;
BEGIN
	IF IsControl (fd, cid, queryctrl) < 0 THEN RETURN -1 END; 
	defval := queryctrl.default_value;
	scontrol.id := cid;
	scontrol.value := defval;
	err := xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(scontrol)); 
	IF err< 0 THEN
		out.String("ioctl reset control error"); out.Ln; out.Update();
		RETURN -1;
	END;
	RETURN 0;
END ResetControl;

PROCEDURE GetWidth*(): SIGNED32;
BEGIN
	RETURN camWidth;
END GetWidth;

PROCEDURE GetHeight*(): SIGNED32;
BEGIN
	RETURN camHeight;
END GetHeight;

PROCEDURE ResetAllControls*;
VAR res: SIGNED32;
	queryctrl: V.v4l2_queryctrl;
BEGIN

	queryctrl.id := SYSTEM.VAL(UNSIGNED32, {V.CTRL_FLAG_NEXT_CTRL});
	WHILE xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl)) > - 1 DO
		res := ResetControl(fd, queryctrl.id);
		queryctrl.id  := SYSTEM.VAL(UNSIGNED32, SYSTEM.VAL(SET32, queryctrl.id) + {V.CTRL_FLAG_NEXT_CTRL});
	END;
END ResetAllControls;

(** *)
PROCEDURE OpenPreview*;
VAR title: ARRAY 128 OF CHAR;
BEGIN
	IF preview # NIL THEN preview.Close(); END;
	title := "Preview Window: ";
	Strings.Append(title, deviceName);
	NEW(preview, camWidth, camHeight, title);
END OpenPreview;

PROCEDURE OpenControlWin*;
BEGIN
	IF controlWin # NIL THEN controlWin.Close(); END;
	NEW(controlWin, fd);
	WM.DefaultAddWindow(controlWin);
END OpenControlWin;

PROCEDURE StoreControlWin*;
VAR file: Files.File; writer: Files.Writer;
BEGIN
	IF controlWin = NIL THEN RETURN END;
	file := Files.New("v4l2gui.xml");
	IF (file # NIL) THEN
		NEW(writer, file, 0);
		controlWin.form.Write(writer, NIL, 0);
		writer.Update;
		Files.Register(file);
		out.String("v4l2gui.xml  is saved"); out.Ln; out.Update();
	END;	
END StoreControlWin;

PROCEDURE InstallFrameHandler*(handler : FrameHandler);
BEGIN {EXCLUSIVE}
	frameHandler := handler
END InstallFrameHandler;

PROCEDURE ColorToGray(pix: Raster.Pixel): Raster.Pixel;
VAR gcolor: SIGNED32;
	  gval, rx, gx ,bx: FLOAT32;
	  gpix: Raster.Pixel;
BEGIN
(*	rx := 0.2126; gx := 0.7152; bx := 0.0272;  (* HDTV *) *)
	rx := 0.299; gx := 0.587; bx := 0.114;  (* PAL, SECAM .. *)
	
	gval := rx*ORD(pix[Raster.r]) + gx*ORD(pix[Raster.g]) + bx*ORD(pix[Raster.b]);
	gcolor := ENTIER(gval + 0.5);
	gpix[Raster.r]:=CHR(gcolor); gpix[Raster.g]:=CHR(gcolor); gpix[Raster.b]:=CHR(gcolor); gpix[Raster.a]:= 0FFX;
	RETURN gpix;
END ColorToGray;

PROCEDURE ColorToGrayR(pix: Raster.Pixel): Raster.Pixel;
VAR gcolor: CHAR;
	  gpix: Raster.Pixel;
BEGIN
	gcolor := pix[Raster.r];
	gpix[Raster.r]:=gcolor; gpix[Raster.g]:=gcolor; gpix[Raster.b]:=gcolor; gpix[Raster.a]:= 0FFX;
	RETURN gpix;
END ColorToGrayR;

PROCEDURE CovertToGray(im: WMGraphics.Image);
VAR 
	  i, j: SIZE;
	  pix: Raster.Pixel; 
	  mode: Raster.Mode;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	FOR j := 0 TO im.height-1 DO
		FOR i := 0 TO im.width-1 DO
			Raster.Get(im, i, j, pix, mode);				 
			Raster.Put(im, i, j, ColorToGrayR(pix), mode);
		END;
	END;
END CovertToGray;

PROCEDURE LoadDummyImage*(CONST fname: ARRAY 128 OF CHAR);
BEGIN
	dummyimg := WMGraphics.LoadImage(fname, FALSE);
	camWidth := dummyimg.width(SIGNED32);
	camHeight := dummyimg.height(SIGNED32);
END LoadDummyImage;

PROCEDURE GetDummyImage*(): WMGraphics.Image;
BEGIN
	RETURN dummyimg
END GetDummyImage;

PROCEDURE Cleanup;
BEGIN
	IF starter # NIL THEN starter.Stop; END; starter := NIL;
	CloseDevice();
	IF preview # NIL THEN preview.Close; END; preview := NIL;
END Cleanup;

(* set scale factor for distance measurement on the image *)
PROCEDURE SetMeasurementScale*(cmd: Commands.Context);
VAR sx, sy: FLOAT64;
BEGIN
	IF cmd.arg.GetReal(sx) & cmd.arg.GetReal(sy) THEN
		scaleX := sx;
		scaleY := sy;
		cmd.out.String("scalex, scaley: "); cmd.out.FloatFix(sx, 0, 4, 0);  cmd.out.String(", ");
		cmd.out.FloatFix(sy, 0, 4, 0);
		cmd.out.Ln; cmd.out.Update;
	ELSE
		cmd.error.String("input error "); cmd.error.Ln; cmd.error.Update;
	END;
END SetMeasurementScale;


BEGIN
	
(*	camWidth := 1280; (* default *)
	camHeight := 960;	
*)	

(*     camWidth := 720; (* special camera *)
	camHeight := 576; 
*)	

     camWidth := 320; (* webcam *)
	camHeight := 240; 
	
	Streams.OpenWriter(out, KernelLog.Send);
	Raster.InitMode(mode, Raster.srcCopy);
	Modules.InstallTermHandler(Cleanup)
END VideoExample.

System.Free VideoExample  libv4l2 V4L2 ~

VideoExample.Start "/dev/video0" ~

VideoExample.Start ~		VideoExample.Stop ~

VideoExample.PrintCapabilities ~ 

VideoExample.OpenPreview ~  

VideoExample.OpenControlWin ~        VideoExample.StoreControlWin ~

VideoExample.EnumControls ~  VideoExample.EnumerateFrameSizes ~ 

VideoExample.ResetAllControls ~ 

Compiler.Compile 
      V4L2/Unix.V4L2.Mod
      V4L2/Unix.libv4l2.Mod
      V4L2/Unix.VideoExample.Mod
~~      

# measured with micrometer scale
VideoExample.SetMeasurementScale 1  1 ~ 
VideoExample.SetMeasurementScale 3.06  3.06 ~ x4 icin
VideoExample.SetMeasurementScale 0.58 0.58 ~ x20 icin
VideoExample.SetMeasurementScale  0.29 0.29 ~ x40 icin

# eskisi
VideoExample.SetMeasurementScale 2.74  2.74 ~   # x4 scalex, scaley: um/pix
VideoExample.SetMeasurementScale 0.55  0.55 ~   # x20 scalex, scaley: um/pix
VideoExample.SetMeasurementScale 0.274  0.274 ~   # x40 scalex, scaley: um/pix



VideoExample.IncContrast~  VideoExample.DecContrast~ 
VideoExample.FlipVertical ~    VideoExample.FlipHorizontal ~


System.Free VideoExample ~

System.Free VideoExample  libv4l2 V4L2 ~

System.FreeDownTo V4L2 ~ 

System.CollectGarbage ~ 

---------------------------
$ v4l2-ctl  -L

User Controls

          brightness (int)    : min=0 max=255 step=1 default=127 value=127 flags=inactive, slider
          contrast (int)    : min=0 max=255 step=1 default=127 value=127 flags=slider
          saturation (int)    : min=0 max=255 step=1 default=127 value=127 flags=slider
          power_line_frequency (menu)   : min=0 max=2 default=0 value=0
				0: Disabled
				1: 50 Hz
				2: 60 Hz
           brightness_automatic (bool)   : default=1 value=1 flags=update

$ v4l2-ctl  -l

User Controls

          brightness (int)    : min=0 max=255 step=1 default=127 value=127 flags=inactive, slider
          contrast (int)    : min=0 max=255 step=1 default=127 value=127 flags=slider
          saturation (int)    : min=0 max=255 step=1 default=127 value=127 flags=slider
          power_line_frequency (menu)   : min=0 max=2 default=0 value=0
          brightness_automatic (bool)   : default=1 value=1 flags=update

!! For EasyCap usb socket, install mplayer on linux to capture colored image. (YHDO, YH-9628 Color Camera )

