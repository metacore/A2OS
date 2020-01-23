MODULE WMMatrix; (** AUTHOR "Patrick Hunziker"; PURPOSE "quick display of 2D array data as raster image"; *)
IMPORT Modules, Files, Raster, MatrixRaster, MatrixUtilities, WM:=WMWindowManager,  Strings, Models, WMRectangles,
WMMessages, WMGraphics, Commands;

CONST
		gray=0;
		signed=1;
		lut=2;
		rgb=3;
		heat=4;

TYPE Matrix= ARRAY [*,*] OF FLOAT64;

TYPE Model*= OBJECT (Models.Model)
		VAR m*, r*,g*,b*: Matrix;
	END Model;

TYPE Window*= OBJECT (WM.BufferWindow)
	VAR model*:Model;
		max,min, gain*:FLOAT64;
		exists:BOOLEAN;
		type*:SIGNED32;
		offset,mx0,my0,mx1,my1:SIZE;
		palette*:Raster.Palette;
		source*:ANY;

	PROCEDURE &Initialize*(CONST m: ARRAY [*,*] OF FLOAT64; CONST title: ARRAY OF CHAR);
	BEGIN
		IF (~exists  & (LEN(m)>0))  OR (LEN(m,1)#GetWidth()) OR (LEN(m,0)#GetHeight()) THEN
			Init(LEN(m,1), LEN(m,0), TRUE); exists:=TRUE;
			bounds := WMGraphics.MakeRectangle(0, 0, LEN(m,1), LEN(m,0));
		END;
		NEW(model);
		IF LEN(m,0)>0 THEN SetImage(m);END;
		SetTitle(Strings.NewString(title));
		INCL(flags, WM.FlagStorable);
		(*maxInterpolation:=1; => default bilinear interpolation;  maxInterpolation:=0; => nearest neighbour interpolation*)
	END Initialize;

	PROCEDURE PostInvalidate;
	VAR m: WMMessages.Message;
	BEGIN
			m.sender:=SELF; m.msgType := WMMessages.MsgInvalidate; m.msgSubType := WMMessages.MsgSubAll;
			IF (sequencer#NIL) & sequencer.Add(m) THEN END; (* Invalidate window contents when first put on display. *)
	END PostInvalidate;

	PROCEDURE Handle*(VAR x : WMMessages.Message);
		VAR filename: Files.FileName; f:Files.File; w:Files.Writer;
		BEGIN
			IF (x.msgType = WMMessages.MsgSerialize) THEN
				GenerateName(GetTitle(),filename);
				Strings.Append(filename, ".MtA"); (* file type "MathArray" *)
				f:=Files.New(filename);
				Files.OpenWriter(w,f,0);
				MatrixUtilities.StoreLR(w, model.m);
				w.Update;
				Files.Register(f);
			ELSIF x.msgType = WMMessages.MsgInvalidate THEN
				IF x.msgSubType = WMMessages.MsgSubAll THEN
					Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
				ELSE
					HALT(200)
				END;
			ELSE Handle^(x)
			END
		END Handle;

	PROCEDURE PointerDown*(x, y : SIZE; keys : SET);
		BEGIN
			mx0:=x; my0:=y;
		END PointerDown;

	PROCEDURE PointerUp*(x, y : SIZE; keys : SET);
		BEGIN
			mx1:=x; my1:=y;
		END PointerUp;

	PROCEDURE PointerMove*(x, y : SIZE; keys : SET);
		BEGIN
			IF keys={2} THEN
				mx1:=x; my1:=y;
				gain:=gain*(1 + (mx1-mx0)/100);
				offset:=offset+(my0-my1);
				mx0:=mx1; my0:=my1;
				Render;
			ELSE
				PointerMove^(x,y,keys)
			END;
		END PointerMove;

	PROCEDURE SetImage*(CONST m: Matrix);
	BEGIN
		IF ~exists  & (LEN(m)>0) THEN
			Init(LEN(m,1), LEN(m,0), TRUE); exists:=TRUE;
			bounds := WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight());
		END;
		IF LEN(m,0)>0 THEN
			model.m:=m;
			(* model.m:=ALIAS OF m; *)(* no-copy version *)
			max:=MAX(m); min:=MIN(m); IF min<0 THEN type:=signed ELSE type:=0 END;;
			offset:=0;
			IF max#min THEN gain:= 255/MAX( ABS(max),ABS(min));
			ELSE gain :=1;
			END;
			Render;
		ELSE type:=0;
		END;
	END SetImage;

	PROCEDURE SetImageB*(CONST m: Matrix; offset:SIGNED32;gain: FLOAT64);
	BEGIN
		IF ~exists  & (LEN(m)>0) THEN
			Init(LEN(m,1), LEN(m,0), TRUE); exists:=TRUE;
			bounds := WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight());
		END;
		model.m:=m;
		(*model.m:=ALIAS OF m;*)(* no-copy version *)
		max:=MAX(m); min:=MIN(m); IF min<0 THEN type:=signed ELSE type:=0 END;
		SELF.offset:=offset; SELF.gain:=gain;
		Render;
	END SetImageB;

	(*Expects a lookup table in a binary LUT file "name", formatted according to the ImageJ convention:
	for color:=0 to 2 do (*RGB*)
	   for index:=0 to 255 do
	      char:=ColorComponent  in range CHR(0)..CHR(255)
	   end
	end.
	Can add a custom background (0=none, 1=black, 2=transparent)*)
	PROCEDURE SetPalette*(CONST name:ARRAY OF CHAR; background:SIGNED32); (*background=0: none; 1=transparent; 2=black*)
	VAR format: Raster.Format;
	BEGIN
		palette:=GetPalette(name, background);
		IF palette=NIL THEN
		ELSE
			type:=lut;
			Raster.InitPaletteFormat(format, palette);
			Raster.Create(img, GetWidth(), GetHeight(), format)
		END;
	END SetPalette;

	PROCEDURE SetImageLUT*(CONST m: Matrix);
	BEGIN
		IF ~exists  & (LEN(m)>0) THEN
			Init(LEN(m,1), LEN(m,0), TRUE); exists:=TRUE;
			bounds := WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight());
		END;
		model.m:=m;
		(*model.m:=ALIAS OF m;*)(* no-copy version *)
		max:=MAX(m); min:=MIN(m);
		type:=lut;
		IF max#min THEN gain:= 255/(max-min);
		ELSE gain:=1;
		END;
		offset:=0;
		Render;
	END SetImageLUT;

	PROCEDURE SetImageRGB*(CONST r,g,b: Matrix);
	BEGIN
		IF ~exists  & (LEN(r)>0) THEN
			Init(LEN(r,1), LEN(r,0), TRUE); exists:=TRUE;
			bounds := WMGraphics.MakeRectangle(0, 0, GetWidth(), GetHeight());
		END;
		model.r:=r; model.g:=g; model.b:=b;
		(*model.r:=ALIAS OF r; model.g:=ALIAS OF g; model.b:=ALIAS OF b; *)(* no-copy version*)
		type:=rgb;
		Render;
	END SetImageRGB;

	PROCEDURE Render*;
	VAR min,max: FLOAT64;
	BEGIN
		IF type=signed THEN MatrixRaster.LRealToImageBR(model.m, offset, gain, img)
		ELSIF type=heat THEN MatrixRaster.LRealToImageHeat(model.m, offset, gain, img)
		ELSIF type=lut THEN MatrixRaster.LRealToImageLUT(model.m, offset, gain, img);
		ELSIF type=rgb THEN MatrixRaster.LRealRGBToImage( model.r, model.g, model.b, img)
		ELSIF LEN(model.m)>0 THEN MatrixRaster.LRealToImage(model.m, offset, gain, img)
		ELSE
		END;
		PostInvalidate;
		(*
		Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
		*)
	END Render;

	PROCEDURE RenderScaled*(offset:SIGNED32;gain: FLOAT64);
	BEGIN
		SELF.offset:=offset; SELF.gain:=gain;
		Render;
	END RenderScaled;

	PROCEDURE SetParameters(context: Commands.Context);
	VAR offset, gain:SIGNED32; res:BOOLEAN;
	BEGIN
		res:=context.arg.GetInteger(offset, FALSE);
		res:=context.arg.GetInteger(gain, FALSE);
	END SetParameters;

	PROCEDURE AddWindow*;
	BEGIN
		ASSERT(exists);
		WM.ExtAddWindow(SELF,  32+(pos MOD 10)*48 + (pos DIV 10) *200, 96+(pos MOD 10) *48,
									{WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		INC(pos);

		(*WM.DefaultAddWindow(SELF);*)
	END AddWindow;

END Window;

VAR InsertPosX*,InsertPosY*, pos: SIGNED32; (* default insertion point for new window *)
	(*registry-,last:Registry;*)

PROCEDURE GenerateName(prefix: Strings.String; VAR str: ARRAY OF CHAR);
VAR  i,j:SIGNED32; title: Files.FileName; c:CHAR;
BEGIN
	i:=0; j:=0;
	IF prefix#NIL THEN
		WHILE (i<LEN(prefix)) & (j<LEN(title)-1) DO
			c:=prefix[i];
			IF (c>="A")&(c<="Z") OR (c>="a")&(c<="z") OR(c>="0")&(c<="9") OR (c="_") OR (c=" ")THEN
				IF c=" " THEN c:="_" END;
				title[j]:=c; INC(i); INC(j);
			ELSE
				INC(i);
			END;
		END;
		title[j]:=0X;
		IF title="" THEN title:="Matrix" END;
	ELSE title:="Matrix"
	END;
	COPY(title, str);
END GenerateName;

PROCEDURE GetPalette(CONST name:ARRAY OF CHAR; background:SIGNED32):Raster.Palette; (*background=0: none; 1=transparent; 2=black*)
VAR pal: Raster.Palette;
	f: Files.File;
	reader:Files.Reader;
	j,i:SIGNED32;
	VAR raw: ARRAY 3,256 OF CHAR;
BEGIN
	f:=Files.Old(name);
	IF f#NIL THEN
		Files.OpenReader(reader,f,0);
		NEW(pal);
		FOR j:=0 TO 2 DO
			FOR i:=0 TO 255 DO
				raw[j,i]:=reader.Get();
			END;
		END;
		FOR i:=0 TO 255 DO
			Raster.SetRGBA(pal.col[i], ORD(raw[0,i]), ORD(raw[1,i]), ORD(raw[2,i]), 255 );
		END;
		IF background=1 THEN Raster.SetRGBA(pal.col[0], 0,0,0,0);
		ELSIF background=2 THEN Raster.SetRGBA(pal.col[0], 0,0,0,255);
		END;
		Raster.InitPalette(pal, 256, 4);
	END;
	RETURN pal
END GetPalette;


PROCEDURE AddWindow*(CONST m: Matrix; CONST title: ARRAY OF CHAR); (*deprecated*)
VAR pw: WM.BufferWindow; max,min:FLOAT64; type:BOOLEAN;
BEGIN
	max:=MAX(m);
	min:=MIN(m);
	NEW(pw, LEN(m,0), LEN(m,1), TRUE);
	pw.SetTitle(Strings.NewString(title));
	IF min<0 THEN type:=TRUE; MatrixRaster.LRealToImageBR(m,0,255/MAX(ABS(max),ABS(min)),pw.img);
	ELSE
		MatrixRaster.LRealToImage(m,0,255/MAX(ABS(max),ABS(min)),pw.img);
	END;
	WM.DefaultAddWindow(pw);
END AddWindow;

PROCEDURE RemoveWindows*(context:Commands.Context);
VAR manager:WM.WindowManager; w,remove:WM.Window; i:SIGNED32;
BEGIN {EXCLUSIVE}
	IF (context=NIL) OR (~context.arg.GetInteger(i,FALSE)) THEN i:=MAX(SIGNED32) END;
	manager:=WM.GetDefaultManager();
	manager.lock.AcquireWrite;
	w:=manager.GetFirst();
	WHILE (w#NIL) & (i>0) DO
		remove:=w;
		w:=manager.GetNext(w);
		IF (remove#NIL)&(remove IS Window) THEN manager.Remove(remove); DEC(i) END;
	END;
	manager.lock.ReleaseWrite;
END RemoveWindows;

PROCEDURE RemoveAllWindows;
BEGIN
	RemoveWindows(NIL)
END RemoveAllWindows;

BEGIN
	Modules.InstallTermHandler(RemoveAllWindows);
	InsertPosX:=30; InsertPosY:=30;
END WMMatrix.
~
WMMatrix.RemoveWindows ~ (*close and remove all matrix windows*)
WMMatrix.RemoveWindows 5 ~ (* close and remove a number of matrix windows*)

SystemTools.FreeDownTo WMMatrix~
SystemTools.CollectGarbage

--------------example application of LUT --------------
PROCEDURE Do*;
VAR m:ARRAY [100,100] OF FLOAT32;
	i:SIGNED32;
	w:WMMatrix.Window;
BEGIN
	FOR i:=0 TO 99 DO
		m[i,..]:=i
	END;
	NEW(w, m, "LUT");
	w.SetPalette("Thermal.lut",2);
	w.SetImageLUT(m);
	w.AddWindow
END Do;
