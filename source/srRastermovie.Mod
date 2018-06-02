MODULE srRastermovie;

IMPORT Strings, Raster, WMGraphics, Out:=KernelLog, WMWindowManager, Rectangles:=WMRectangles, Kernel,Modules(*srRenderBase*);

TYPE Screen = OBJECT(WMWindowManager.BufferWindow)
VAR
	alive: BOOLEAN;
	timer: Kernel.Timer;
	frame: LONGINT;
	playing: BOOLEAN;

PROCEDURE & New*;
BEGIN
(*	Init(srRenderBase.W*16 + 2, srRenderBase.H*16 + 2, FALSE); *)
	manager := WMWindowManager.GetDefaultManager();
	manager.Add(300, 0, SELF, { WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop});
END New;

PROCEDURE Close*;
BEGIN
	alive := FALSE;
	Close^;
END Close;

PROCEDURE playframe;
VAR
	t: ARRAY 24 OF CHAR;
	n: ARRAY 8 OF CHAR;
BEGIN
	t:="";
	INC(frame);
	Strings.Append(t,title);
	Strings.IntToStr(frame, n);
	Strings.Append(t,n);
	Strings.Append(t,".bmp");
(*	WMGraphics.LoadImage(t,FALSE); *)
(*	IF ~done THEN playing := FALSE END; *)
	screen.Invalidate(Rectangles.MakeRect(0, 0, screen.GetWidth(), screen.GetHeight()));
END playframe;

(*BEGIN {ACTIVE}
	alive := TRUE;
	NEW(timer);
	Objects.SetPriority(Objects.Normal);
	REPEAT
	timer.Sleep(0);
	IF playing THEN playframe END;
	UNTIL ~playing;
	srBase.worldalive :=FALSE;
	Close; *)
END Screen;
VAR
	title: ARRAY 24 OF CHAR;
	frame: LONGINT;
	screen: Screen;

PROCEDURE snap*(img: Raster.Image);
VAR
	t: ARRAY 24 OF CHAR;
	n: ARRAY 8 OF CHAR;
	res: WORD;
BEGIN
	INC(frame);
	Strings.Append(t,title);
	Strings.IntToStr(frame, n);
	Strings.Append(t,n);
	Strings.Append(t,".bmp");
	WMGraphics.StoreImage(img,t, res);
	Out.String(t); Out.Ln;
END snap;

PROCEDURE snapshot*(img: Raster.Image);
VAR
	res: WORD;
BEGIN
	WMGraphics.StoreImage(img,"SYS:snapshot.bmp", res);
	Out.String("snap snap"); Out.Ln;
END snapshot;

PROCEDURE play*;
BEGIN
	NEW(screen);
	screen.frame := 1000;
	screen.playing := TRUE;
END play;

PROCEDURE Close*;
BEGIN
	IF screen#NIL THEN screen.Close END;
END Close;

BEGIN
	title := "FAT:x";
	frame := 10000;
	Modules.InstallTermHandler(Close);
END srRastermovie.play

System.Free srRastermovie