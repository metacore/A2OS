MODULE WMColorLines; (** AUTHOR "SAGE"; PURPOSE "The ColorLines game"; *)

IMPORT
	Modules, Commands, WMWindowManager, Random,
	Kernel, WMGraphics, Strings, WMDialogs;

CONST
	M = 13;
	CELL_SIZE = 30;
	STATUS_SIZE = 16;
	TOTAL_SIZE = M * CELL_SIZE;
	RES = "WMColorLines.zip";
	ICON = "WMColorLines.png";
	BOARD_COLOR = WMGraphics.White;
	GRID_COLOR = WMGraphics.Black;
	LINES = "Lines: ";
	SCORE = "Score: ";

TYPE

	String = Strings.String;
	Chars = ARRAY OF CHAR;
	
	Desk = ARRAY M, M OF SIZE;

	Form = OBJECT(WMWindowManager.BufferWindow)
	VAR
		random: Random.Sequence;
		alpha: BOOLEAN;
		Map, WaveMap, Road: Desk;
		RoadFlag, DestroyFlag: BOOLEAN;
		clisp: BOOLEAN;
		xsp, ysp: SIZE;
		numlines, score: INTEGER;
		imgSpheres: ARRAY 7 OF WMGraphics.Image;
		timer: Kernel.Timer;
		strTitle, strLines, strScore: String;
		frame: ARRAY 4 OF WMGraphics.Point2d;
		
	PROCEDURE &New(alpha: BOOLEAN);
	VAR
		i: INTEGER;
		a: ARRAY 2 OF CHAR;
		s: String;
		x, y: SIZE;
	BEGIN
		SELF.alpha :=  alpha;
		NEW(random);
		NEW(timer);
		FOR i := 0 TO LEN(imgSpheres) - 1 DO
			Strings.IntToStr(i + 1, a); s := a + ".png";
			imgSpheres[i] := LoadImage(RES, s^)
		END;
		Restart;
		Data(0, 0);
		Init(TOTAL_SIZE + 1, TOTAL_SIZE + STATUS_SIZE + 1, alpha);
		
		frame[0].x := 0; frame[0].y := 0;
		frame[1].x := TOTAL_SIZE; frame[1].y := 0;
		frame[2].x := TOTAL_SIZE; frame[2].y := TOTAL_SIZE + STATUS_SIZE;
		frame[3].x := 0; frame[3].y := TOTAL_SIZE + STATUS_SIZE;
		
		strTitle := Strings.NewString("WM Color Lines");
		SetTitle(strTitle);
		SetIcon(LoadImage(RES, ICON));
		NewSpheres(3);
		manager := WMWindowManager.GetDefaultManager();
		WMDialogs.DefaultPos(x, y, GetWidth(), GetHeight());
		manager.Add(x, y, SELF,
			{WMWindowManager.FlagFrame, WMWindowManager.FlagClose, WMWindowManager.FlagMinimize, WMWindowManager.FlagNoResizing});
	END New;

	PROCEDURE LoadImage(CONST archfile, imagefile: ARRAY OF CHAR): WMGraphics.Image;
	VAR
		s: String;
	BEGIN
		s := archfile + "://" + imagefile;
		RETURN WMGraphics.LoadImage(s^, TRUE)
	END LoadImage;

	PROCEDURE AllDraw;
	VAR
		x, y, i, pos: INTEGER;
	BEGIN
		canvas.Fill(WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight()), BOARD_COLOR, WMGraphics.ModeCopy);
		FOR y := 0 TO M - 1 DO
			FOR x := 0 TO M - 1 DO
				IF Map[x, y] > 0 THEN
					canvas.DrawImage(x * 30 + 1, y * 30 + 1, imgSpheres[Map[x, y] - 1], WMGraphics.ModeCopy)
				END
			END
		END;
		FOR i := 0 TO M DO
			pos := i * CELL_SIZE;
			canvas.Line(0, pos, TOTAL_SIZE, pos, GRID_COLOR, WMGraphics.ModeCopy);
			canvas.Line(pos, 0, pos, TOTAL_SIZE, GRID_COLOR, WMGraphics.ModeCopy)
		END;
		canvas.PolyLine(frame, 4, TRUE, GRID_COLOR, WMGraphics.ModeCopy);
		
		canvas.SetColor(GRID_COLOR);
		canvas.DrawString(4, TOTAL_SIZE + STATUS_SIZE - 2, strLines^); 
		canvas.DrawString(TOTAL_SIZE DIV 2 + 4, TOTAL_SIZE + STATUS_SIZE - 2, strScore^); 
		Invalidate(WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight()))
	END AllDraw;
	
	PROCEDURE Close;
	BEGIN
		Close^;
		frm := NIL
	END Close;

	PROCEDURE PointerUp(x, y : SIZE; keys : SET);
	BEGIN
		IF clisp THEN
			clisp := FALSE;
			Move(xsp, ysp, x DIV 30, y DIV 30);
			IF RoadFlag THEN
				timer.Sleep(100);
				DestroyLines;
				timer.Sleep(150);
				IF ~DestroyFlag THEN
					NewSpheres(3);
					DestroyLines
				END
			END;
			RoadFlag := FALSE
		ELSE
			IF Map[x DIV 30, y DIV 30] > 0 THEN
				clisp := TRUE;
				xsp := x DIV 30;
				ysp := y DIV 30
			END
		END
	END PointerUp;

	PROCEDURE Set(map, wave, road: BOOLEAN);
	VAR
		x, y: INTEGER;
	BEGIN
		FOR y := 0 TO M - 1 DO
			FOR x := 0 TO M - 1 DO
				IF map THEN Map[x, y] := 0 END;
				IF wave THEN WaveMap[x, y] := 0 END;
				IF road THEN Road[x, y] := 0 END
			END
		END
	END Set;

	PROCEDURE Restart;
	BEGIN
		Set(TRUE, TRUE, TRUE);
		score := 0;
		numlines := 0;
	END Restart;

	PROCEDURE Data(sc, nl: INTEGER);
	VAR
		buf: ARRAY 8 OF CHAR;
	BEGIN
		INC(numlines, nl);
		INC(score, sc);
		Strings.IntToStr(numlines, buf);
		strLines := LINES + buf;
		Strings.IntToStr(score, buf);
		strScore := SCORE + buf
	END Data;

	PROCEDURE EmptyPos(n: INTEGER): BOOLEAN;
	VAR
		x, y, e: INTEGER;
	BEGIN
		e := 0;
		FOR y := 0 TO M - 1 DO
			FOR x := 0 TO M - 1 DO
				IF Map[x, y] = 0 THEN INC(e) END
			END
		END;
		RETURN e > n
	END EmptyPos;

	PROCEDURE InMap(x, y: SIZE): BOOLEAN;
	BEGIN
		RETURN (x >= 0) & (x < M) & (y >= 0) & (y < M)
	END InMap;

	PROCEDURE Wave(x1, y1, x2, y2: SIZE);
	VAR
		x, y, k: SIZE;
		flag: BOOLEAN;
	BEGIN
		flag := TRUE;
		FOR y := 0 TO M - 1 DO
			FOR x := 0 TO M - 1 DO
				IF Map[x, y] > 0 THEN
					WaveMap[x, y] := -1
				ELSE
					WaveMap[x, y] := 0
				END
			END
		END;
		k := 1; WaveMap[x1, y1] := k;
		WHILE flag DO
			flag := FALSE;
			FOR y := 0 TO M - 1 DO
				FOR x := 0 TO M - 1 DO
					IF WaveMap[x, y] = k THEN
						IF InMap(x - 1, y) & (WaveMap[x - 1, y] = 0)  THEN
							WaveMap[x - 1, y] := k + 1;
							flag := TRUE
						END;
						IF InMap(x + 1, y) & (WaveMap[x + 1, y] = 0)  THEN
							WaveMap[x + 1, y] := k + 1;
							flag := TRUE
						END;
						IF InMap(x, y - 1) & (WaveMap[x, y - 1] = 0) THEN
							WaveMap[x, y - 1] := k + 1;
							flag := TRUE
						END;
						IF InMap(x, y + 1) & (WaveMap[x, y + 1] = 0) THEN
							WaveMap[x, y + 1] := k + 1;
							flag := TRUE
						END
					END
				END
			END;
			IF WaveMap[x2, y2] > 0 THEN
				flag := FALSE
			ELSE
				INC(k)
			END
		END
	END Wave;

	PROCEDURE Way(x1, y1, x2, y2: SIZE);
	VAR
		k: SIZE;
	BEGIN
		k := WaveMap[x2, y2];
		Road[x2, y2] := k - WaveMap[x1, y1] + 1;
		IF InMap(x2 - 1, y2) & (WaveMap[x2 - 1, y2] = k - 1) THEN
			Way(x1, y1, x2 - 1, y2)
		ELSIF InMap(x2 + 1, y2) & (WaveMap[x2 + 1, y2] = k - 1) THEN
			Way(x1, y1, x2 + 1, y2)
		ELSIF InMap(x2, y2 - 1) & (WaveMap[x2, y2 - 1] = k - 1) THEN
			Way(x1, y1, x2, y2 - 1)
		ELSIF InMap(x2, y2 + 1) & (WaveMap[x2, y2 + 1] = k - 1) THEN
			Way(x1, y1, x2, y2 + 1)
		END
	END Way;

	PROCEDURE Move(x1, y1, x2, y2: SIZE);
	VAR
		x, y, c: SIZE;
	BEGIN
		RoadFlag := FALSE;
		Set(FALSE, TRUE, TRUE);
		Wave(x1, y1, x2, y2);
		IF WaveMap[x2, y2] > 0 THEN
			RoadFlag := TRUE;
			Way(x1, y1, x2, y2);
			x := x1;
			y := y1;
			c := Map[x, y];
			REPEAT
				timer.Sleep(50);
				Map[x, y] := 0;
				IF (x # 0) & (Road[x - 1, y] - Road[x, y] = 1) THEN
					DEC(x)
				ELSIF (x < M - 1) & (Road[x + 1, y] - Road[x, y] = 1) THEN
					INC(x)
				ELSIF (y # 0) & (Road[x, y - 1] - Road[x, y] = 1) THEN
					DEC(y)
				ELSIF (y < M - 1) & (Road[x, y + 1] - Road[x, y] = 1) THEN
					INC(y)
				END;
				Map[x, y] := c;
				AllDraw
			UNTIL (x = x2) & (y = y2)
		END
	END Move;

	PROCEDURE FindLine(x, y, i, j: INTEGER): INTEGER;
	VAR
		dx, dy, k: INTEGER;
	BEGIN
		dx := x; dy := y; k := 0;
		WHILE InMap(dx, dy) & (Map[x, y] = Map[dx, dy]) DO
			INC(k); INC(dx, i); INC(dy, j)
		END;
		RETURN k
	END FindLine;

	PROCEDURE DestroyLines;
	VAR
		x, y: INTEGER;
	BEGIN
		DestroyFlag := FALSE;
		FOR y := 0 TO M - 1 DO
			FOR x := 0 TO M - 1 DO
				IF Map[x, y] # 0 THEN
					IF FindLine(x, y, 1, 0) > 3 THEN
						DestroySpheres(x, y, FindLine(x, y, 1, 0), 1, 0)
					ELSIF FindLine(x, y, 1, 1) > 3 THEN
						DestroySpheres(x, y, FindLine(x, y, 1, 1), 1, 1)
					ELSIF FindLine(x, y, 0, 1) > 3 THEN
						DestroySpheres(x, y, FindLine(x, y, 0, 1), 0, 1)
					ELSIF FindLine(x, y, -1, 1) > 3 THEN
						DestroySpheres(x, y, FindLine(x, y, -1, 1), -1, 1)
					END
				END
			END
		END
	END DestroyLines;

	PROCEDURE DestroySpheres(x, y, k, i, j: INTEGER);
	VAR
		n, dx, dy: INTEGER;
	BEGIN
		n := 0; dx := x; dy := y;
		WHILE n # k DO
			Map[dx, dy] := 0;
			INC(n); INC(dx, i); INC(dy, j)
		END;
		Data(k, 1);
		DestroyFlag := TRUE;
		AllDraw
	END DestroySpheres;

	PROCEDURE NewSpheres(quantity: INTEGER);
	VAR
		i, x, y, res: SIGNED32;
	BEGIN
		random.InitSeed(Kernel.GetTicks());
		IF EmptyPos(3) THEN
			FOR i := 1 TO quantity DO
				REPEAT
					x := SHORT(random.Dice(M));
					y := SHORT(random.Dice(M))
				UNTIL Map[x, y] = 0;
				Map[x, y] := SHORT(random.Dice(7)) + 1
			END
		ELSE
			DialogPos(x, y, SELF, 350, 100);
			res := WMDialogs.MessageXY(WMDialogs.TInformation, x, y,
				strTitle^, "You lose!", {WMDialogs.ResOk});
			Restart;
			NewSpheres(3)
		END;
		AllDraw
	END NewSpheres;

	END Form;

VAR
	frm: Form;

OPERATOR "+" (CONST a1, a2: Chars): String;
BEGIN
	RETURN Strings.ConcatToNew(a1, a2)
END "+";

PROCEDURE DialogPos(VAR x, y: SIGNED32; win: WMWindowManager.Window; dlgWidth, dlgHeight: SIGNED32);
VAR
	manager: WMWindowManager.WindowManager;
	s: WMWindowManager.WindowStyle;
BEGIN
	manager := WMWindowManager.GetDefaultManager();
	s := manager.GetStyle();
	x := ENTIER(win.bounds.l + (win.bounds.r - win.bounds.l - dlgWidth) / 2);
	y := ENTIER(win.bounds.t + (win.bounds.b - win.bounds.t - dlgHeight) / 2);
	(*IF s # NIL THEN y := y +  s.th END;*)
END DialogPos;

PROCEDURE WindowGenerator*(ctx: Commands.Context): WMWindowManager.Window;
BEGIN
	IF frm = NIL THEN
		NEW(frm, FALSE)
	END;
	RETURN frm
END WindowGenerator;

PROCEDURE Open*(ctx: Commands.Context);
VAR
	wDummy: WMWindowManager.Window;
BEGIN
	IF frm = NIL THEN
		wDummy := WindowGenerator(ctx)
	END
END Open;

PROCEDURE Cleanup;
BEGIN
	IF frm # NIL THEN
		frm.Close
	END
END Cleanup;

BEGIN
	Modules.InstallTermHandler (Cleanup)
END WMColorLines.

WMColorLines.Open ~
System.Free WMColorLines ~
