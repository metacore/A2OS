MODULE WMAAGraphicsExample;

IMPORT
	Commands, Kernel, Raster, Random, Objects, WMRectangles, WMGraphics, Modules, Strings,
	WM := WMWindowManager, WMMessages, AAGraphics;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	WND* =  OBJECT(WM.BufferWindow)
	VAR
		timer: Kernel.Timer;
		random : Random.Generator;
		alive, dead, alpha : BOOLEAN;

		PROCEDURE &New*(alpha : BOOLEAN);
		BEGIN
			Init(800, 600, alpha);
			SELF.alpha := alpha;
			manager := WM.GetDefaultManager();
			manager.Add(100, 100, SELF, {WM.FlagFrame, WM.FlagClose, WM.FlagMinimize, WM.FlagNoResizing});

			SetTitle(Strings.NewString("AAGraphics example"));

			NEW(timer);
			NEW(random);
			
			IncCount;
		END New;

		PROCEDURE Handle(VAR m: WMMessages.Message);
		BEGIN
			IF (m.msgType = WMMessages.MsgExt) & (m.ext # NIL) & (m.ext IS KillerMsg) THEN
				Close;
			ELSE Handle^(m)
			END
		END Handle;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		BEGIN
			Draw^(canvas, w, h, 0)
		END Draw;

		PROCEDURE Close;
		BEGIN
			alive := FALSE;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			Close^;
			DecCount;
		END Close;

		PROCEDURE DrawIt;
		VAR i, x, y, r, cl1, cl2: LONGINT;
			pix : Raster.Pixel;
			mode : Raster.Mode;
			
		BEGIN
		
			Raster.InitMode(mode, Raster.srcOverDst);
			
			Raster.SetRGB(pix, 0AAH, 0AAH, 0AAH);
			
			Raster.Fill(img, 0, 0, GetWidth(), GetHeight(), pix, mode);
			FOR i := 0 TO 499 DO
				cl1 := WMGraphics.RGBAToColor(random.Dice(256), random.Dice(256), random.Dice(256), 255);
				cl2 := WMGraphics.RGBAToColor(random.Dice(256), random.Dice(256), random.Dice(256), 255);
				x := 40 + random.Dice(GetWidth() - 80);
				y := 40 + random.Dice(GetHeight() - 80);
				r := 5 + random.Dice(25);

				AAGraphics.DiskGrad(img, x, y, r + 3, cl1, cl1);
				AAGraphics.DiskGrad(img, x, y, r, cl2, cl2);

				(*
				AAGraphics.AADisk(img, x, y, r + 3, cl1);
				AAGraphics.AADisk(img, x, y, r, cl2);
				*)	

			END;
			Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
			
		END DrawIt;

	BEGIN {ACTIVE}
		alive := TRUE;
		Objects.SetPriority(Objects.Low);
		WHILE alive DO
			DrawIt;
			timer.Sleep(25);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE END;
	END WND;

VAR
	nofWindows: LONGINT;

PROCEDURE WindowGenerator*(ctx: Commands.Context): WM.Window;
VAR
	window: WND;
BEGIN
	NEW(window, FALSE);
	RETURN window
END WindowGenerator;

PROCEDURE Open*(ctx: Commands.Context);
VAR
	wDummy: WM.Window;
BEGIN
	wDummy := WindowGenerator(ctx)
END Open;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WM.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMAAGraphicsExample.

System.Free WMAAGraphicsExample ~
WMAAGraphicsExample.Open ~
