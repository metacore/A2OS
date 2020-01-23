MODULE WMRaster; (** AUTHOR "Patrick Hunziker"; PURPOSE "Simple Display of Images on Screen"; *)
IMPORT WM:=WMWindowManager, Strings, Raster, WMGraphics, WMRectangles;

TYPE Window*= OBJECT (WM.BufferWindow)

	PROCEDURE &Initialize*(img:Raster.Image; CONST title: ARRAY OF CHAR);
	BEGIN
		Init(img.width, img.height,FALSE);
		manager:=WM.GetDefaultManager();
		SetImage(img);
		SetTitle(Strings.NewString(title));
	END Initialize;

	PROCEDURE SetImage*(img:Raster.Image);
	BEGIN
		SELF.img:=img(WMGraphics.Image);
		Draw(canvas,img.width,img.height,0);
		Invalidate(WMRectangles.MakeRect(0, 0, img.width, img.height));
	END SetImage;

	PROCEDURE Integrate*; (** deprecated *)
	BEGIN
		AddWindow;
	END Integrate;

	PROCEDURE AddWindow*;
	BEGIN
		WM.ExtAddWindow(SELF, InsertPosX, InsertPosY, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		InsertPosX:= (InsertPosX +16)MOD 512; InsertPosY:=(InsertPosY + 16) MOD 512;
	END AddWindow;

	END Window;

VAR InsertPosX,InsertPosY: SIGNED32;

PROCEDURE Integrate*(img:Raster.Image; CONST title: ARRAY OF CHAR); (** deprecated *)
BEGIN
	AddWindow(img, title);
END Integrate;

PROCEDURE AddWindow*(img:Raster.Image; CONST title: ARRAY OF CHAR);
VAR pw: Window;
BEGIN
	NEW(pw, img,  title);
	pw.AddWindow;
END AddWindow;

BEGIN
	InsertPosX:=20; InsertPosY:=20;
END WMRaster.
