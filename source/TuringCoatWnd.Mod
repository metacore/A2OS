MODULE TuringCoatWnd;	(* Soren Renner / TF *)

IMPORT
	Raster, Random, Objects, Kernel, WMRectangles, WMGraphics, Modules, Strings,
	WM := WMWindowManager, WMMessages, Commands, Options;

CONST
	m = 50;
	size = 4;

	WindowWidth = m * size; WindowHeight = m * size;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	TCW* =  OBJECT(WM.BufferWindow)
	VAR
		mesh1, mesh2, n1 : ARRAY m, m OF FLOAT32;
		random : Random.Generator;
		alive, dead, alpha, delay : BOOLEAN;
		t0 : SIGNED32;
		timer : Kernel.Timer;

		PROCEDURE &New*(alpha, delay : BOOLEAN);
		VAR i, j : SIGNED32;
		BEGIN
			Init(WindowWidth, WindowHeight, alpha);
			SELF.alpha :=alpha;
			SELF.delay := delay;
			manager := WM.GetDefaultManager();
			manager.Add(100, 100, SELF, {WM.FlagFrame, WM.FlagClose, WM.FlagNoResizing});

			SetTitle(Strings.NewString("Turing"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://TuringCoatWnd.png", TRUE));

			NEW(random);

			NEW( timer );  t0 := Kernel.GetTicks( );

			FOR i := 0 TO m - 1 DO
				FOR j := 0 TO m - 1 DO
					mesh1[i, j] := 0;
					mesh2[i, j] := 0;
					n1[i, j] := 0
				END
			END;
			FOR i :=  1 TO m - 2 DO
				FOR j := 1 TO m - 2 DO
					IF random.Dice(100) > 90 THEN mesh1[i, j] := random.Dice(1000)/1000 END
				END
			END;
			IncCount;
		END New;

		PROCEDURE Handle*(VAR m: WMMessages.Message);
		BEGIN
			IF (m.msgType = WMMessages.MsgExt) & (m.ext # NIL) & (m.ext IS KillerMsg) THEN
				Close;
			ELSE Handle^(m)
			END
		END Handle;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h : SIZE; q : SIGNED32);
		BEGIN
			Draw^(canvas, w, h, 0)
		END Draw;

		PROCEDURE Close*;
		BEGIN
			alive := FALSE;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			Close^;
			DecCount;
		END Close;

		PROCEDURE Delay;
		VAR t: SIGNED32;
		BEGIN
			t := Kernel.GetTicks( ) - t0;
			IF t < 8 THEN
				IF t >= 0 THEN  timer.Sleep( 8 - t )  END;
			END;
			t0 := Kernel.GetTicks( )
		END Delay;

		PROCEDURE Generation;
		VAR i, j : SIGNED32;
		BEGIN
			FOR i := 1 TO m - 2 DO
				n1[i, 0] := mesh1[i - 1, 0] + mesh1[i + 1, 0] + mesh1[i, m - 1] + mesh1[i, 1]
				 	+ mesh1[i - 1, m - 1] +  mesh1[i + 1, 1] + mesh1[i + 1, m - 1] + mesh1[i - 1,  1];
				n1[i, m - 1] := mesh1[i - 1, m - 1] + mesh1[i + 1, m - 1] + mesh1[i, m - 2] + mesh1[i, 0]
					+ mesh1[i - 1, m - 2] +  mesh1[i + 1, 0] + mesh1[i + 1, m - 2] + mesh1[i - 1, 0];
				END;
			FOR j := 1 TO m - 2 DO
				n1[0, j] := mesh1[m - 1, j] + mesh1[1, j] + mesh1[0, j - 1] + mesh1[0, j + 1]
					+ mesh1[m - 1, j - 1] +  mesh1[1, j + 1] + mesh1[1, j - 1] + mesh1[m - 1, j + 1];
				n1[m - 1, j] := mesh1[m - 2, j] + mesh1[0, j] + mesh1[m - 1, j - 1] + mesh1[m - 1, j + 1]
					+ mesh1[m - 2, j - 1] +  mesh1[0, j + 1] + mesh1[0, j - 1] + mesh1[m - 2, j + 1]
			END;

			FOR i := 1 TO m - 2 DO
				FOR j := 1 TO m - 2 DO
					n1[i, j] := mesh1[i - 1, j] + mesh1[i + 1, j] + mesh1[i, j - 1] + mesh1[i, j + 1]
						+ mesh1[i - 1, j - 1] +  mesh1[i + 1, j + 1] + mesh1[i + 1, j - 1] + mesh1[i - 1, j + 1]
				END
			END;
			FOR i := 1 TO m - 2 DO
				FOR j := 1 TO m - 2 DO
					(*  HERE ARE THE DIFFERENCE RULES! *)
					mesh1[i, j] := mesh1[i, j] + n1[i, j] / 80- (mesh2[i, j] * mesh2[i, j])  ;
					mesh2[i, j] := mesh2[i, j] +  mesh1[i, j] / 20 - 0.03 ;
					IF mesh1[i, j] < 0 THEN mesh1[i, j] := 0 END;
					IF mesh2[i, j] < 0 THEN mesh2[i, j] := 0 END;
					IF mesh1[i, j] > 1 THEN mesh1[i, j] := 1 END;
					IF mesh2[i, j] > 1 THEN mesh2[i, j] := 1 END;
				END;
			END;
		END Generation;

		PROCEDURE DrawIt;
		VAR i, j, ix, jy : SIGNED32;
			pix : Raster.Pixel;
			mode : Raster.Mode;
		BEGIN
			Raster.InitMode(mode, Raster.srcCopy);
			FOR i := 0 TO m - 1 DO
				ix := i * size ;
				FOR j := 0 TO m - 1 DO
					jy := j * size;
					IF alpha THEN
						Raster.SetRGBA(pix, SHORT((255-ENTIER(mesh1[i, j] * 255)) ), SHORT((255-ENTIER(mesh2[i, j] * 255)) ), 0,
						SHORT( (255-ENTIER(mesh2[i, j] * 255))+ENTIER(mesh1[i, j] * 255)) MOD 128+127 )
					ELSE
						Raster.SetRGB(pix, SHORT((255-ENTIER(mesh1[i, j] * 255)) ), SHORT((255-ENTIER(mesh2[i, j] * 255)) ), 0)
					END;
					Raster.Fill(img, ix, jy, ix+size, jy+size, pix, mode)
				END
			END;
			Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
		END DrawIt;

	BEGIN {ACTIVE}
		alive := TRUE;
		Objects.SetPriority(Objects.Low);
		WHILE alive DO
			Generation;
			IF delay THEN Delay END;	(* GF, make animation speed independent of CPU speed *)
			DrawIt;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END TCW;

VAR
	nofWindows : SIGNED32;

PROCEDURE Open*(context: Commands.Context);
VAR window : TCW; options: Options.Options;
BEGIN
	NEW(options);
	options.Add("d", "delay", Options.Flag);
	options.Add("a", "alpha", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		NEW(window, options.GetFlag("alpha"), options.GetFlag("delay"));
	END;
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
END TuringCoatWnd.

System.Free TuringCoatWnd ~
TuringCoatWnd.Open ~
TuringCoatWnd.Open --alpha~
TuringCoatWnd.Open --delay ~

