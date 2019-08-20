MODULE WMBunny;	(** AUTHOR "TF"; PURPOSE "Visual active objects"; *)

IMPORT
	Commands, WMMessages, WMGraphics, Modules,
	Raster, Random, Kernel, KernelLog, Rectangles := WMRectangles,
	WM := WMWindowManager;

CONST
	Width = 1024; Height = 768;	(* temp hack *)

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	Bunny = OBJECT (WM.Window)
	VAR
		posX, posY : SIZE;
		alive : BOOLEAN;
		timer : Kernel.Timer;
		random : Random.Generator;
		nofFrames, frame, step : LONGINT;
		movie : Raster.Image;
		keyPressed : SET;

		PROCEDURE &New*(movie : Raster.Image; frames, step : LONGINT);
		BEGIN
			bounds := Rectangles.MakeRect(0, 0, movie.width DIV frames, movie.height);
			useAlpha := TRUE;
			isVisible := TRUE;
			NEW(random);
			nofFrames := frames; frame := 0; SELF.movie := movie; SELF.step := step;
			NEW(timer);
			posX := (posX+ step) MOD (Width * 2 + movie.width);
			posY := random.Dice((Height - movie.height)(LONGINT) DIV 2);
			manager := WM.GetDefaultManager();
			manager.Add(posX, posY, SELF, {});
		END New;

		PROCEDURE Move;
		VAR opx : SIZE;
		BEGIN
			opx := posX;
			posX := (posX+ step) MOD (Width * 2 + movie.width);
			IF ((step < 0) & (posX > opx)) OR ((step > 0) & (posX < opx)) THEN
				posY := random.Dice((Height - movie.height)(LONGINT))
			END;
			frame := (frame + 1) MOD nofFrames;
			manager.SetWindowPos(SELF, posX - movie.width, posY)
		END Move;

		PROCEDURE PointerDown*(x, y : SIZE; keys : SET);
		BEGIN
			keyPressed := keyPressed + (keys * {0, 1, 2})
		END PointerDown;

		PROCEDURE PointerUp*(x, y : SIZE; keys : SET);
		BEGIN
			IF keys={} THEN
				IF keyPressed#{0, 1, 2} THEN
					IF keyPressed={0} THEN manager.ToFront(SELF)
					ELSIF keyPressed={0, 2} THEN Close END
				END;
				keyPressed := {}
			END
		END PointerUp;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h : SIZE; q : WORD);
		BEGIN
			IF movie # NIL THEN
				IF (w = GetWidth()) & (h = GetHeight()) THEN
					canvas.ScaleImage(movie, Rectangles.MakeRect(frame * GetWidth(), 0, (frame + 1) * GetWidth(), GetHeight()),
						Rectangles.MakeRect(0, 0, w, h), WMGraphics.ModeSrcOverDst, 0);
				ELSE
					canvas.ScaleImage(movie, Rectangles.MakeRect(frame * GetWidth(), 0, (frame + 1) * GetWidth(), GetHeight()),
						Rectangles.MakeRect(0, 0, w, h), WMGraphics.ModeSrcOverDst, q)
				END
			END
		END Draw;

		PROCEDURE IsHit*(x, y  : SIZE) : BOOLEAN;
		BEGIN
			RETURN WMGraphics.IsBitmapHit(frame * GetWidth() + x, y, 128, movie)
		END IsHit;

		PROCEDURE Close*;
		BEGIN alive := FALSE
		END Close;

		PROCEDURE Handle*(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^(x)
			END
		END Handle;

	BEGIN {ACTIVE}
		alive := TRUE;
		WHILE alive DO timer.Sleep(100); Move END;
	FINALLY
		manager.Remove(SELF);
		DecCount;
	END Bunny;

VAR
	nofWindows : LONGINT;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Free*;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WM.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Free;

PROCEDURE InternalInsert(CONST fname : ARRAY OF CHAR; frames, step : LONGINT);
VAR b : Bunny;
	img : Raster.Image;
BEGIN {EXCLUSIVE}
	img := WMGraphics.LoadImage(fname, TRUE);
	IF img # NIL THEN
		NEW(b, img, frames, step)
	ELSE
		KernelLog.Enter; KernelLog.String(fname); KernelLog.String(" not found."); KernelLog.Exit
	END
END InternalInsert;

PROCEDURE Insert*(context : Commands.Context);
VAR fn : ARRAY 65 OF CHAR;	(* a filename equivalent to Files.FileName - do not import Files *)

	(* Assign an integer value to a variable: extracted from the command parameter if present or
		else a default one *)
	PROCEDURE SetVal(def : LONGINT) : LONGINT;
	VAR int : LONGINT;
	BEGIN
		int := def;
		context.arg.SkipWhitespace;
		IF (context.arg.Peek() >= '0') & (context.arg.Peek() <= '9') OR (context.arg.Peek() = '-') THEN
			context.arg.Int(int, FALSE);
		END;
		RETURN int;
	END SetVal;

BEGIN
	context.arg.SkipWhitespace; context.arg.String(fn);
	IncCount;
	InternalInsert(fn, SetVal(8), SetVal(32));
END Insert;

PROCEDURE Cleanup;
BEGIN
	Free;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WMBunny.

WMBunny.Insert WMBunnyImages.tar://BunnyLinear.gif 8 40 ~
WMBunny.Insert WMBunnyImages.tar://bones.gif 25 10 ~
WMBunny.Insert WMBunnyImages.tar://phantom.png 25 10 ~
WMBunny.Insert WMBunnyImages.tar://SisiphusLinear.gif 5 8 ~
WMBunny.Insert WMBunnyImages.tar://frog.gif 17 -4 ~
WMBunny.Insert WMBunnyImages.tar://aos1.gif 25 -15 ~
WMBunny.Insert WMBunnyImages.tar://aos2.gif 25 10 ~
WMBunny.Insert WMBunnyImages.tar://aos3.gif 25 15 ~

WMBunny.Free~
System.Free WMBunny
