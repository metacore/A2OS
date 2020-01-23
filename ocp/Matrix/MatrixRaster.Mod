MODULE MatrixRaster ;	(**  AUTHOR "Patrick Hunziker"; PURPOSE "visualize Matrix contents";  **)
IMPORT Raster , Reals, SYSTEM, Files, WMGraphics, Rand:=Random, WM:=WMWindowManager, Strings, RasterPixelFormats;

CONST Random*=-1;

VAR rand:Rand.Generator;

TYPE Enumerator*=OBJECT(Files.Enumerator) (*extract single or multiple images from file directory using path, mask; yield tensor data *)
		VAR currentImg*: WMGraphics.Image;
			array: ARRAY [?] OF SIGNED16;
			w*,h*, depth*:SIZE;
			scale*: SIGNED32;

		PROCEDURE &Init*;
		BEGIN
			w:=100; h:=100;
		END Init;

		PROCEDURE GetImage*(VAR name:ARRAY OF CHAR; VAR flags:SET; VAR time, date: SIGNED32; VAR size: Files.Size ):WMGraphics.Image; (*get next image*)
		BEGIN
			currentImg:=NIL;
			WHILE HasMoreEntries() & (currentImg=NIL) DO
				IF GetEntry(name, flags, time, date, size) THEN
					currentImg:=WMGraphics.LoadImage(name, FALSE)
				ELSE
					name:=""; flags:={}; time:=0; date:=0; size:=0;
				END;
			END;
			RETURN currentImg
		END GetImage;

		PROCEDURE SetRoiSize*(w,h, scale: SIGNED32);
		BEGIN
			SELF.w:=w; SELF.h:=h;
			ASSERT(scale=1, 300);SELF.scale:=scale;
		END SetRoiSize;

		PROCEDURE GetBGR*(img: Raster.Image): ARRAY [?] OF SIGNED16; (* yield [BGR,height, width] of current image.   *)
		BEGIN
			(*! implementation limitation: scaling not yet implemented *)
			ImageToArray(img, array); (*img is BGRA, array is [4,..,..] OF SIGNED16*)
			RETURN array [0..2,?];
			(*	RETURN array[0,*,*] + array[1,*,*] + array[2,*,*]; (*grayscale*)			*)
		END GetBGR;

		PROCEDURE GetGray*(img: Raster.Image): ARRAY [?] OF SIGNED16; (* yield [height, width].  of current image*)
		BEGIN
			(*! implementation limitation: scaling not yet implemented *)
			ImageToArray(img, array); (*img is BGRA, array is [4,..,..] OF SIGNED16*)
			RETURN array[0,*,*] + array[1,*,*] + array[2,*,*]; (*grayscale*)
		END GetGray;


		PROCEDURE GetRoiBGR*(img: Raster.Image; VAR x,y:SIZE): ARRAY [?] OF SIGNED16; (* yield ROI[BGR,h,w] of current image;  use "Random" for random position within window*)
		BEGIN
			IF x=Random THEN x:= rand.Dice((img.width-w)(SIGNED32)) END; (*! implementation limitation: scaling not yet implemented *)
			IF y=Random THEN y:= rand.Dice((img.height-h)(SIGNED32)) END;
			ImageToArray(img, array); (*img is BGRA, array is [4,..,..] OF SIGNED16*)
			RETURN array [0..2,y..y+h-1, x..x+w-1];
		END GetRoiBGR;

		PROCEDURE GetRoiGray*(img: Raster.Image; VAR x,y:SIZE): ARRAY [?] OF SIGNED16; (* yield ROI[h,w] of current Image.  use "Random" for random position within window*)
		BEGIN
			IF x=Random THEN x:= rand.Dice((img.width-w)(SIGNED32)) END; (*! implementation limitation: scaling not yet implemented *)
			IF y=Random THEN y:= rand.Dice((img.height-h)(SIGNED32)) END;
			ImageToArray(img, array); (*img is BGRA, array is [4,..,..] OF SIGNED16*)
			RETURN array[0,y..y+h-1, x..x+w-1] + array[1,y..y+h-1, x..x+w-1] + array[2,y..y+h-1, x..x+w-1]; (*BGR to grayscale*) (*!! ROI IS MISSING*)
		END GetRoiGray;


		(* from an image, extract a stack of ROIs with random positions, that are also returned  *)
		PROCEDURE GetRoiStackRandom*(img: Raster.Image; depth, colorPlanes: SIZE; VAR positions: ARRAY [*,*] OF SIZE): ARRAY [?] OF SIGNED16;
		VAR i:SIZE;
		BEGIN
			SELF.depth:=depth;
			IF LEN(positions)#[depth,2] THEN NEW(positions, depth, 2) END;
			positions:=Random;
			IF colorPlanes=1 THEN
				IF LEN(RESULT)#[depth,h,w] THEN NEW(RESULT,[depth,h,w]) END;
				FOR i:=0 TO depth-1 DO
					RESULT[i,?]:=GetRoiGray(img, positions[i,0], positions[i,1]);
				END;
			ELSE
				IF LEN(RESULT)#[depth,colorPlanes, h,w] THEN
					NEW(RESULT,[depth,colorPlanes, h,w]); (* BGR *)
				END;
				FOR i:=0 TO depth-1 DO
					RESULT[i,?]:=GetRoiBGR(img, positions[i,0], positions[i,1]);
				END;
			END;
			RETURN RESULT
		END GetRoiStackRandom;

	END Enumerator;

PROCEDURE SIntToImage*(CONST data:ARRAY [*,*] OF SIGNED8; VAR palette: ARRAY [*,*] OF SIGNED32; im:Raster.Image); (*palette values in range 0..10000H*)
VAR F:Raster.Format; pal:Raster.Palette; i,x,y:SIZE;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;
	NEW(pal);
	(*NEW(pal.col,256);*)
	IF LEN(palette,0)=0 THEN
		FOR i:=0 TO LEN(pal.col)-1 DO
			pal.col[i,0]:=CHR(i);
			pal.col[i,1]:=CHR(i);
			pal.col[i,2]:=CHR(i);
			pal.col[i,3]:=0FFX;
		END;
	ELSE
		FOR i:=0 TO LEN(palette,0)-1 DO
			pal.col[i,0]:= CHR(SHORT(palette[i,2] MOD 10000H DIV 256));
			pal.col[i,1]:=CHR(SHORT(palette[i,1] MOD 10000H DIV 256));
			pal.col[i,2]:=CHR(SHORT(palette[i,0] MOD 10000H DIV 256));
			pal.col[i,3]:=0FFX;
		END;
	END;
	Raster.InitPaletteFormat(F,pal);
	Raster.Create(im,LEN(data,1),LEN(data,0),F);	(*TO DO: reuse if fitting ...*)
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			im.mem[y*im.bpr+x]:= CHR(data[y,x] MOD 256);
		END;
	END;
END SIntToImage;

PROCEDURE SIntRGBToImage*(CONST data:ARRAY [*,*,*] OF SIGNED8; im:Raster.Image);
VAR F:Raster.Format; pal:Raster.Palette; i,x,y:SIZE;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;
	F:=Raster.BGR888;
	Raster.Create(im,LEN(data,1),LEN(data,0),F);
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			im.mem[y*im.bpr+3*x+0]:= CHR(data[y,x,2] MOD 256);
			im.mem[y*im.bpr+3*x+1]:= CHR(data[y,x,1] MOD 256);
			im.mem[y*im.bpr+3*x+2]:= CHR(data[y,x,0] MOD 256);
		END;
	END;
END SIntRGBToImage;


PROCEDURE IntToImage*(CONST data:ARRAY [*,*] OF SIGNED16; VAR palette: ARRAY [*,*] OF SIGNED32; im:Raster.Image);  (*data >=0; palette values in range 0..10000H*)
VAR F:Raster.Format; pal:Raster.Palette; max,valI,i,col:SIGNED32;x,y:SIZE;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;
	F:=Raster.BGR888;
	max:=MAX(data MOD 10000H);(*!to do: avoid temp allocation*)
	Raster.Create(im,LEN(data,1),LEN(data,0),F);
	IF LEN(palette)=0 THEN
		NEW(palette, max+1,3);
		FOR col:=0 TO LEN(palette,0)(SIGNED32)-1 DO
			valI:=col*10000H DIV LEN(palette,0)(SIGNED32); palette[col,0]:=valI; palette[col,1]:=valI; palette[col,2]:=valI
		END;
	END;
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			valI:=LONG(data[y,x]) MOD 10000H;
			im.mem[y*im.bpr+3*x+0]:= CHR(palette[valI,2] DIV 256); (*variant for Format BGR888 - compress palette to 8 bit depth *)
			im.mem[y*im.bpr+3*x+1]:=CHR(palette[valI,1] DIV 256);
			im.mem[y*im.bpr+3*x+2]:=CHR(palette[valI,0] DIV 256);
		END;
	END;
END IntToImage;

PROCEDURE LIntToImage*(CONST data:ARRAY [*,*] OF SIGNED32; VAR palette: ARRAY [*,*] OF SIGNED32; im:Raster.Image); (*palette values in range 0..10000H*)
VAR F:Raster.Format; pal:Raster.Palette; max,valI,i,col:SIGNED32; x,y:SIZE;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;
	F:=Raster.BGR888;
	max:=MAX(data);
	IF im=NIL THEN NEW(im); END;
	Raster.Create(im,LEN(data,1),LEN(data,0),F);
	IF LEN(palette)=0 THEN
		NEW(palette, max+1,3);
		FOR col:=0 TO LEN(palette,0)(SIGNED32)-1 DO
			valI:=col*10000H DIV LEN(palette,0)(SIGNED32); palette[col,0]:=valI; palette[col,1]:=valI; palette[col,2]:=valI
		END;
	END;
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			valI:=data[y,x] MOD 10000H;
			im.mem[y*im.bpr+3*x+0]:= CHR(palette[valI,2] DIV 256); (*variant for Format BGR888 - compress palette to 8 bit depth *)
			im.mem[y*im.bpr+3*x+1]:=CHR(palette[valI,1] DIV 256);
			im.mem[y*im.bpr+3*x+2]:=CHR(palette[valI,0] DIV 256);
		END;
	END;
END LIntToImage;

PROCEDURE CombineLIntToImage*(CONST data,data1:ARRAY [*,*] OF SIGNED32; VAR palette, palette1: ARRAY [*,*] OF SIGNED32; threshold:SIGNED32; im:Raster.Image); (*palette values in range 0..10000H; threshold indicates minimum value of data1 to take precedence over data*)
VAR F:Raster.Format; pal:Raster.Palette; max,valI, valI1,i,col:SIGNED32;x,y:SIZE;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) OR (LEN(data,0)#LEN(data1,0)) OR (LEN(data,1)#LEN(data1,1)) THEN RETURN END;
	F:=Raster.BGR888;
	max:=MAX(data);
	IF im=NIL THEN NEW(im); END;
	Raster.Create(im,LEN(data,1),LEN(data,0),F);
	IF LEN(palette)=0 THEN
		NEW(palette, max+1,3);
		FOR col:=0 TO LEN(palette,0)(SIGNED32)-1 DO
			valI:=col*10000H DIV LEN(palette,0)(SIGNED32); palette[col,0]:=valI; palette[col,1]:=valI; palette[col,2]:=valI
		END;
	END;
	IF LEN(palette1)=0 THEN
		NEW(palette1, max+1,3);
		FOR col:=0 TO LEN(palette1,0)(SIGNED32)-1 DO
			valI:=col*10000H DIV LEN(palette1,0)(SIGNED32); palette1[col,0]:=valI;  palette1[col,1]:=10000H - valI-1; palette1[col,2]:=10000H - valI-1
		END;
	END;
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			valI:=data[y,x] MOD 10000H;
			valI1:=data[y,x] MOD 10000H;
			IF valI1>= threshold THEN (* display overlay*)
				im.mem[y*im.bpr+3*x+0]:= CHR(palette1[valI1,2] DIV 256); (*variant for Format BGR888 - compress palette to 8 bit depth *)
				im.mem[y*im.bpr+3*x+1]:=CHR(palette1[valI1,1] DIV 256);
				im.mem[y*im.bpr+3*x+2]:=CHR(palette1[valI1,0] DIV 256);
			ELSE
				im.mem[y*im.bpr+3*x+0]:= CHR(palette[valI,2] DIV 256); (*variant for Format BGR888 - compress palette to 8 bit depth *)
				im.mem[y*im.bpr+3*x+1]:=CHR(palette[valI,1] DIV 256);
				im.mem[y*im.bpr+3*x+2]:=CHR(palette[valI,0] DIV 256);
			END;
		END;
	END;
END CombineLIntToImage;

PROCEDURE LIntBGRAToImage*(CONST data:ARRAY [*,*,*] OF SIGNED8; im:Raster.Image);
VAR F:Raster.Format; pal:Raster.Palette; i,col:SIGNED32; x,y: SIZE; putMode:Raster.Mode;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;
	Raster.InitMode(putMode, Raster.srcCopy);
	F:=Raster.BGRA8888;
	Raster.Create(im,LEN(data,1),LEN(data,0),F);
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			Raster.Put(im,x,y, SYSTEM.VAL(Raster.Pixel,data[y,x]),putMode);
		END;
	END;
END LIntBGRAToImage;


PROCEDURE RealToImage*(CONST data:ARRAY [*,*] OF FLOAT32; offset:SIZE; gain:FLOAT64; im:Raster.Image);
VAR F:Raster.Format; pal:Raster.Palette; max,valI,i,col:SIGNED32; x,y:SIZE; val:FLOAT32; palette:ARRAY [*,*] OF SIGNED32;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;
	F:=Raster.BGR888;
	Raster.Create(im,LEN(data,1),LEN(data,0),F);
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			val:=data[y,x]; IF Reals.IsNaN(val) THEN val:=0 END;
			valI:=ENTIER(offset+gain*data[y,x]);
			im.mem[y*im.bpr+3*x+0]:= CHR(Clamp(valI,0,255)); (*variant for Format BGR888 - compress palette to 8 bit depth *)
			im.mem[y*im.bpr+3*x+1]:=CHR(Clamp(valI,0,255));
			im.mem[y*im.bpr+3*x+2]:=CHR(Clamp(valI,0,255));
		END;
	END;
END RealToImage;

PROCEDURE LRealToImage*(CONST data:ARRAY [*,*] OF FLOAT64; offset:SIZE; gain:FLOAT64; im:Raster.Image);
VAR F:Raster.Format; pal:Raster.Palette; max,valI,i,col:SIGNED32; x,y:SIZE; val:FLOAT64; palette:ARRAY [*,*] OF SIGNED32;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;
	F:=Raster.BGR888;
	Raster.Create(im,LEN(data,1),LEN(data,0),F);
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			val:=data[y,x]; IF Reals.IsNaNL(val) THEN val:=0 END;
			valI:=ENTIER(0.5+offset+gain*val);
			im.mem[y*im.bpr+3*x+0]:= CHR(Clamp(valI,0,255)); (*variant for Format BGR888 - compress palette to 8 bit depth *)
			im.mem[y*im.bpr+3*x+1]:=CHR(Clamp(valI,0,255));
			im.mem[y*im.bpr+3*x+2]:=CHR(Clamp(valI,0,255));
		END;
	END;
END LRealToImage;


PROCEDURE LRealToImageBR*(CONST data:ARRAY [*,*] OF FLOAT64; offset:SIZE; gain:FLOAT64; im:Raster.Image);
VAR F:Raster.Format; pal:Raster.Palette; max,valI,i,col:SIGNED32; x,y:SIZE; val:FLOAT64; palette:ARRAY [*,*] OF SIGNED32;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;
	F:=Raster.BGR888;
	Raster.Create(im,LEN(data,1),LEN(data,0),F);
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			val:=data[y,x]; IF Reals.IsNaNL(val) THEN val:=0 END;
			valI:=ENTIER(0.5+offset+gain*val);
			IF valI<0 THEN
				im.mem[y*im.bpr+3*x+0]:= CHR(-Clamp(valI,-255,0));
				im.mem[y*im.bpr+3*x+1]:= 0X;
				im.mem[y*im.bpr+3*x+2]:= 0X;
			ELSE
				im.mem[y*im.bpr+3*x+0]:= 0X;
				im.mem[y*im.bpr+3*x+1]:= 0X;
				im.mem[y*im.bpr+3*x+2]:=CHR(Clamp(valI,0,255));
			END;
		END;
	END;
END LRealToImageBR;

(*transparency for low values*)
PROCEDURE LRealToImageBRA*(CONST data:ARRAY [*,*] OF FLOAT64; offset:SIZE; gain:FLOAT64; im:Raster.Image);
VAR F:Raster.Format; pal:Raster.Palette; max,valI,i,col:SIGNED32; x,y:SIZE; val:FLOAT64; palette:ARRAY [*,*] OF SIGNED32;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;
	F:=Raster.BGRA8888;
	Raster.Create(im,LEN(data,1),LEN(data,0),F);
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			val:=data[y,x]; IF Reals.IsNaNL(val) THEN val:=0 END;
			valI:=ENTIER(0.5+offset+gain*val);
			IF valI<0 THEN
				im.mem[y*im.bpr+4*x+0]:= CHR(-Clamp(valI,-255,0));
				im.mem[y*im.bpr+4*x+1]:= 0X;
				im.mem[y*im.bpr+4*x+2]:= 0X;
				im.mem[y*im.bpr+4*x+3]:= CHR(-Clamp(valI,-255,0));
			ELSE
				im.mem[y*im.bpr+4*x+0]:= 0X;
				im.mem[y*im.bpr+4*x+1]:= 0X;
				im.mem[y*im.bpr+4*x+2]:= CHR(Clamp(valI,0,255));
				im.mem[y*im.bpr+4*x+3]:= CHR(Clamp(valI,0,255));
			END;
		END;
	END;
END LRealToImageBRA;


PROCEDURE LRealToImageHeat*(CONST data:ARRAY [*,*] OF FLOAT64; offset:SIZE; gain:FLOAT64; im:Raster.Image);
VAR F:Raster.Format; pal:Raster.Palette; max,valI,i,col:SIGNED32; x,y:SIZE; val:FLOAT64; palette:ARRAY [*,*] OF SIGNED32;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;
	F:=Raster.BGR888;
	Raster.Create(im,LEN(data,1),LEN(data,0),F);
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			val:=data[y,x];
			IF ~Reals.IsNaNL(val) THEN
				valI:=ENTIER(0.5+offset+gain*val)
			END;
			IF Reals.IsNaNL(val) THEN
				im.mem[y*im.bpr+3*x+0]:= 0X;
				im.mem[y*im.bpr+3*x+1]:= 0X;
				im.mem[y*im.bpr+3*x+2]:= 0X;
			ELSIF valI<0 THEN
				im.mem[y*im.bpr+3*x+0]:= CHR(-Clamp(valI,-255,0));
				im.mem[y*im.bpr+3*x+1]:= CHR(255+Clamp(valI DIV 2,-255,0));(*! TO DO: make nicer colors*)
				im.mem[y*im.bpr+3*x+2]:= 0X;
			ELSE
				im.mem[y*im.bpr+3*x+0]:= 0X;
				im.mem[y*im.bpr+3*x+1]:= CHR(255-Clamp(valI DIV 2,0,255));
				im.mem[y*im.bpr+3*x+2]:=CHR(Clamp(valI,0,255));
			END;
		END;
	END;
END LRealToImageHeat;

PROCEDURE LRealToImageLUT*(CONST data:ARRAY [*,*] OF FLOAT64; offset:SIZE; gain:FLOAT64; im:Raster.Image);
VAR F:Raster.Format; max,valI,i,col:SIGNED32; x,y: SIZE; val:FLOAT64; palette:ARRAY [*,*] OF SIGNED32;
BEGIN
	IF (LEN(data,0)=0) OR (LEN(data,1)=0) THEN RETURN END;


	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			val:=data[y,x];
			IF ~Reals.IsNaNL(val) THEN
				valI:=ENTIER(0.5+offset+gain*val);
				im.mem[y*im.bpr+x(*  *im.fmt.bpp*)]:=CHR(Clamp(valI,0,255));
			ELSE
				im.mem[y*im.bpr+x(*  *im.fmt.bpp*)]:= 0X;
			END;
		END;
	END;
END LRealToImageLUT;



PROCEDURE LRealRGBToImage*(CONST R,G,B:ARRAY [*,*] OF FLOAT64; im:Raster.Image);
VAR x,y, w,h:SIZE;
	gain, r,g,b :FLOAT64;
BEGIN
	w:=LEN(R,1); h:=LEN(R,0);
	r:=MAX(R); IF Reals.IsNaNL(r) THEN r:=0 END;
	g:=MAX(G); IF Reals.IsNaNL(g) THEN g:=0 END;
	b:=MAX(B); IF Reals.IsNaNL(b) THEN b:=0 END;
	gain:=255/MAX(r, MAX(g,b));
	Raster.Create(im,w,h,Raster.BGR888);
	FOR y:=0 TO h-1 DO
		FOR x:=0 TO w-1 DO
			im.mem[y*im.bpr+3*x+0]:= CHR(ENTIER(gain*B[y,x]));
			im.mem[y*im.bpr+3*x+1]:= CHR(ENTIER(gain*G[y,x]));
			im.mem[y*im.bpr+3*x+2]:= CHR(ENTIER(gain*R[y,x]));
		END;
	END;
END LRealRGBToImage;

PROCEDURE LRealRGBToImageB*(CONST R,G,B:ARRAY [*,*] OF FLOAT64;  offset, gain:FLOAT64; im:Raster.Image);
VAR x,y, w,h:SIZE;
BEGIN
	w:=LEN(R,1); h:=LEN(R,0);
	Raster.Create(im,w,h,Raster.BGR888);
	FOR y:=0 TO h-1 DO
		FOR x:=0 TO w-1 DO
			im.mem[y*im.bpr+3*x+0]:= CHR(ENTIER(offset+gain*B[y,x]));
			im.mem[y*im.bpr+3*x+1]:= CHR(ENTIER(offset+gain*G[y,x]));
			im.mem[y*im.bpr+3*x+2]:= CHR(ENTIER(offset+gain*R[y,x]));
		END;
	END;
END LRealRGBToImageB;

PROCEDURE BoolToImage*(CONST data:ARRAY [*,*] OF BOOLEAN; im:Raster.Image);
VAR y,x:SIZE; val:FLOAT32; SIntData: ARRAY [*,*] OF SIGNED8; palette: ARRAY [*,*] OF SIGNED32;
BEGIN
	NEW(SIntData,LEN(data,0),LEN(data,1));
	FOR y:=0 TO LEN(data,0)-1 DO
		FOR x:=0 TO LEN(data,1)-1 DO
			IF data[y,x] THEN SIntData[y,x]:=127 ELSE SIntData[y,x]:=0 END;
		END;
	END;
	SIntToImage(SIntData, palette, im);
END BoolToImage;

PROCEDURE ImageToArray*(img:Raster.Image; VAR data: ARRAY [?] OF SIGNED16);
VAR row,col,p: SIZE; int: SIGNED32; fmt: INTEGER; msg: ARRAY 20 OF CHAR;
BEGIN
	p:=0;
	IF img.fmt.code=Raster.bgr888 THEN
		NEW(data, 3, img.height, img.width) ;
		FOR row:=0 TO img.height-1 DO
			FOR col:=0 TO img.width-1 DO
				data[0,row,col]:= ORD(img.mem[p+2]);
				data[1,row,col]:= ORD(img.mem[p+1]);
				data[2,row,col]:= ORD(img.mem[p]);
				INC(p,3);
			END;
		END;
	ELSIF img.fmt.code=Raster.yuv422 THEN
		NEW(data, 3, img.height, img.width) ;
		FOR row:=0 TO img.height-1 DO
			FOR col:=0 TO img.width-1 BY 2 DO
				data[0,row,col]:= ORD(img.mem[p]);
				data[1,row,col]:= ORD(img.mem[p+1]);
				data[2,row,col]:= ORD(img.mem[p+3]);

				data[0,row,col+1]:= ORD(img.mem[p+2]);
				data[1,row,col+1]:= ORD(img.mem[p+1]);
				data[2,row,col+1]:= ORD(img.mem[p+3]);
				INC(p,4);
			END;
		END;
	ELSIF img.fmt.code=Raster.bgra8888 THEN
		NEW(data, 4, img.height, img.width) ;
		FOR row:=0 TO img.height-1 DO
			FOR col:=0 TO img.width-1 DO
				data[0,row,col]:= ORD(img.mem[p+2]);
				data[1,row,col]:= ORD(img.mem[p+1]);
				data[2,row,col]:= ORD(img.mem[p]);
				data[3,row,col]:= ORD(img.mem[p+3]);
				INC(p,4);
			END;
		END;
	ELSIF img.fmt.code=Raster.bgr565 THEN
		NEW(data, 3, img.height, img.width) ;
		FOR row:=0 TO img.height-1 DO
			FOR col:=0 TO img.width-1 DO
				int:=ASH(ORD(img.mem[p+1]), 8) + ORD(img.mem[p]);
				data[0,row,col]:= SIGNED16(ASH(ASH(int, -11) MOD 20H, 3) + 4);
				data[1,row,col]:= SIGNED16(ASH(ASH(int, -5) MOD 40H, 2) + 2);
				data[2,row,col]:= SIGNED16(ASH(int MOD 20H, 3) + 4);
				INC(p,2);
			END;
		END;
	ELSE 
		COPY("failed on format ",msg);; fmt:=img.fmt.code;
		HALT(200);(* not yet implemented*)
	END;
END ImageToArray;

PROCEDURE ImagePlaneToArray*(img:Raster.Image; planeIndex: SIZE):ARRAY [*,*] OF SIGNED16;
VAR row,col,p, i0, i1: SIZE; int: SIGNED32; fmt: INTEGER; msg: ARRAY 20 OF CHAR;
VAR data: ARRAY [*,*] OF SIGNED16;
BEGIN
	p:=0;
	IF LEN(RESULT)#[img.height,img.width] THEN 
		NEW(data, img.height, img.width);
	ELSIF RESULT[0,0] IS SIGNED16 THEN
		data:=ALIAS OF RESULT
	ELSE 
		NEW(data, img.height, img.width);
	END;
		
	IF img.fmt.code=Raster.bgr888 THEN
		FOR row:=0 TO img.height-1 DO
			FOR col:=0 TO img.width-1 DO
				data[row,col]:= SIGNED16(ORD(img.mem[p+planeIndex]));
				INC(p,3);
			END;
		END;
	ELSIF img.fmt.code=Raster.yuv422 THEN
		IF planeIndex=0 THEN i0:=0; i1:=2;
		ELSIF planeIndex=1 THEN i0:=1; i1:=1;
		ELSIF planeIndex=2 THEN i0:=3; i1:=3;
		END;
		FOR row:=0 TO img.height-1 DO
			FOR col:=0 TO img.width-1 BY 2 DO
				data[row,col]:= SIGNED16(ORD(img.mem[p+i0]));
				data[row,col+1]:= SIGNED16(ORD(img.mem[p+i1]));
				INC(p,4);
			END;
		END;
	ELSIF img.fmt.code=Raster.bgra8888 THEN
		FOR row:=0 TO img.height-1 DO
			FOR col:=0 TO img.width-1 DO
				data[row,col]:= SIGNED16(ORD(img.mem[p+planeIndex]));
				INC(p,4);
			END;
		END;
	ELSIF img.fmt.code=Raster.bgr565 THEN
		FOR row:=0 TO img.height-1 DO
			FOR col:=0 TO img.width-1 DO
				int:=ASH(ORD(img.mem[p+1]), 8) + ORD(img.mem[p]);
				IF planeIndex=0 THEN data[row,col]:= SIGNED8(ASH(ASH(int, -11) MOD 20H, 3) + 4);
				ELSIF planeIndex=1 THEN data[row,col]:= SIGNED8(ASH(ASH(int, -5) MOD 40H, 2) + 2);
				ELSIF planeIndex=2 THEN data[row,col]:= SIGNED8(ASH(int MOD 20H, 3) + 4);
				END;
				INC(p,2);
			END;
		END;
	ELSE 
		COPY("failed on format ",msg);; fmt:=img.fmt.code;
		HALT(200);(* not yet implemented*)
	END;
	RETURN data
END ImagePlaneToArray;

(*
PROCEDURE IntegrateLReal(CONST m: ARRAY OF FLOAT64);
VAR max:FLOAT64;
BEGIN
	max:=MAX(m); min:=MIN(m);

END IntegrateLReal;
*)

PROCEDURE Clamp(val:SIGNED32; min,max:SIGNED32):SIGNED32;
BEGIN
	IF val>max THEN RETURN max
	ELSIF val<min THEN RETURN min
	ELSE RETURN val
	END;
END Clamp;


PROCEDURE Test*;
VAR
	s:ARRAY [*,*] OF SIGNED8;
	i:ARRAY [*,*] OF SIGNED16;
	l:ARRAY [*,*] OF SIGNED32;
	r:ARRAY [*,*] OF FLOAT32;
	lr:ARRAY [*,*] OF FLOAT64;
	p:ARRAY [*,*] OF SIGNED32;
	ind:SIGNED32;
	pw, pw1, pw2, pw3, pw4, pw5, pw6, pw7: WM.BufferWindow;
	res, w, h, x : SIGNED32;
	n: SIZE;
BEGIN


	NEW(s,100,100); s[50..80,40..90]:=100;
	NEW(i,100,100); i[50..80,40..90]:=100;
	NEW(l,100,100); l[50..80,40..90]:=100;
	NEW(r,100,100); r[50..80,40..90]:=100;
	NEW(lr,100,100); lr[50..80,40..90]:=100;
			FOR n:=0 TO LEN(lr,0)-1 DO lr[0..10,n]:= 5.11*n-255 END; (*color ramp*)

	NEW(p,256,3);
	FOR ind:=0 TO 255 DO
		p[ind,0]:=ind*256; p[ind,2]:=(255-ind)*256
	END;

	w:=100; h:=100; x:=50;
	NEW(pw, w, h, TRUE); pw.SetTitle(Strings.NewString("pw"));
	NEW(pw1, w, h, TRUE);
	NEW(pw2, w, h, TRUE);
	NEW(pw3, w, h, TRUE);
	NEW(pw4, w, h, TRUE);
	NEW(pw5, w, h, TRUE);
	NEW(pw6, w, h, TRUE);
	NEW(pw7, w, h, TRUE);

	SIntToImage(s,p,pw.img);
	IntToImage(i,p,pw1.img);
	LIntToImage(l,p,pw2.img);
	RealToImage(r,128,1,pw3.img);
	LRealToImage(lr,128,1,pw4.img);
	LRealToImageHeat(lr,128,1,pw5.img);
	LRealToImageBR(lr,128,1,pw6.img);
	LRealToImageBRA(lr,0,1,pw7.img);

	WM.DefaultAddWindow(pw);
	WM.DefaultAddWindow(pw1);
	WM.DefaultAddWindow(pw2);
	WM.DefaultAddWindow(pw3);
	WM.DefaultAddWindow(pw4);
	WM.DefaultAddWindow(pw5);
	WM.DefaultAddWindow(pw6);
	WM.DefaultAddWindow(pw7);

END Test;

BEGIN
	NEW(rand);
END MatrixRaster.

System.FreeDownTo
MatrixRaster~
MatrixRaster.Test ~
