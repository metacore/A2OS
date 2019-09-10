(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE BMP IN Oberon; (** portable *)

	IMPORT Display, Files, Pictures, Objects, Texts, Oberon;

	CONST
		TypeTag = "BM";
		FHeaderSize = 14;

		(* compression *)
		RGB = 0; RLE8 = 1; RLE4 = 2;

	TYPE
		FileHeader = RECORD
			type: ARRAY 4 OF CHAR;	(* must be "BM" *)
			size: SIGNED32;	(* filesize in double words *)
			res1, res2: SIGNED16;	(* reserved, must be 0 *)
			offBits: SIGNED32	(* offset in bytes from the FileHeader to the bitmap data *)
		END;

		BitmapHeader = RECORD
			size: SIGNED32;	(* size of this record *)
			width, height: SIGNED32;	(* image's width and height *)
			planes: SIGNED16;	(* must be 1 *)
			depth: SIGNED16;	(* number of bits per pixel [1, 4, 8, 16, 24 or 32] *)
			compression: SIGNED32;	(* type of compression *)
			sizeImage: SIGNED32;	(* can be 0 if bitmap is not compressed *)
			Xppm, Yppm: SIGNED32;	(* pixels per meter *)
			clrUsed: SIGNED32;	(* colors used by actual bitmap *)
			clrImportant: SIGNED32	(* number of colors that are considered important *)
		END;

	VAR
		ColorMap: ARRAY 256 OF SIGNED16;
		W: Texts.Writer;
		error: BOOLEAN;

(** BMP-File support (depth: 1, 4 and 8 / compression: RLE4 and RLE8) / ps 2.8.96 *)
(* BMP
	original code from M. Dätwyler
*)

PROCEDURE WriteError (str: ARRAY OF CHAR);
BEGIN Texts.WriteString(W, str); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf); error := TRUE
END WriteError;

PROCEDURE ScanFileHeader (VAR R: Files.Rider; VAR header: FileHeader);
BEGIN
	Files.ReadBytes(R, header.type, 2); header.type[2] := 0X;
	Files.ReadLInt(R, header.size);
	Files.ReadInt(R, header.res1); Files.ReadInt(R, header.res2);
	Files.ReadLInt(R, header.offBits);
END ScanFileHeader;

PROCEDURE ScanBitmapHeader (VAR R: Files.Rider; VAR header: BitmapHeader);
BEGIN
	Files.ReadLInt(R, header.size);
	Files.ReadLInt(R, header.width); Files.ReadLInt(R, header.height);
	Files.ReadInt(R, header.planes); Files.ReadInt(R, header.depth);
	Files.ReadLInt(R, header.compression);
	Files.ReadLInt(R, header.sizeImage);
	Files.ReadLInt(R, header.Xppm); Files.ReadLInt(R, header.Yppm);
	Files.ReadLInt(R, header.clrUsed); Files.ReadLInt(R, header.clrImportant)
END ScanBitmapHeader;

PROCEDURE ScanCol (VAR R: Files.Rider; pict: Pictures.Picture; nrColor: SIGNED32; conversion: BOOLEAN);
VAR Red, Green, Blue, c: CHAR; C, min, d, x, y, z: SIGNED32; i, j, minj: SIGNED16; r, g, b: ARRAY 256 OF SIGNED16;
BEGIN
	C := ASH(1, Display.Depth(0)) - 1;
	IF nrColor > C THEN nrColor := C ELSE DEC(nrColor) END;
	IF conversion THEN
		FOR i := 0 TO SHORT(C) DO Display.GetColor(i, r[i], g[i], b[i]) END;
		FOR i := 0 TO SHORT(nrColor) DO
			Files.Read(R, Blue); Files.Read(R, Green); Files.Read(R, Red); Files.Read(R, c);
			min := MAX(SIGNED32);
			FOR j := 0 TO SHORT(C) DO
				x := ABS(ORD(Red) - r[j]); y := ABS(ORD(Green) - g[j]); z := ABS(ORD(Blue) - b[j]);
				d := x;
				IF y > d THEN d := y END;
				IF z > d THEN d := z END;
				d := d*d + (x*x + y*y + z*z);
				IF d < min THEN min := d; minj := j END
			END;
			ColorMap[i] := minj;
			Pictures.SetColor(pict, i, r[i], g[i], b[i])
		END
	ELSE
		FOR i := 0 TO SHORT(nrColor) DO
			Files.Read(R, Blue); Files.Read(R, Green); Files.Read(R, Red); Files.Read(R, c);
			Pictures.SetColor(pict, i, ORD(Red), ORD(Green), ORD(Blue));
			ColorMap[i] := i
		END
	END
END ScanCol;

PROCEDURE LoadRLE8 (VAR R: Files.Rider; pict: Pictures.Picture);
VAR count, x, y, i: SIGNED16; b: CHAR;
BEGIN
	x:= 0; y:= 0;
	WHILE ~R.eof DO
		Files.Read(R, b);
		IF b # 0X THEN
			count:= ORD(b); Files.Read(R, b);
			FOR i := 1 TO count DO
				Pictures.Dot(pict, ColorMap[ORD(b)], x, y, Display.replace); INC(x)
			END
		ELSE
			Files.Read(R, b);
			IF b > 2X THEN
				count:= ORD(b);
				FOR i := 1 TO count DO
					Files.Read(R, b);
					Pictures.Dot(pict, ColorMap[ORD(b)], x, y, Display.replace); INC(x)
				END;
				IF ODD(count) THEN Files.Read(R, b) END
			ELSIF b = 0X THEN x := 0; INC(y) (* end of line *)
			ELSIF b = 1X THEN RETURN (* end of data *)
			ELSIF b = 2X THEN (* Delta-Record *)
				Files.Read(R, b); INC(x, ORD(b));
				Files.Read(R, b); INC(y, ORD(b))
			END
		END
	END
END LoadRLE8;

PROCEDURE LoadRLE4 (VAR R: Files.Rider; pict: Pictures.Picture);
VAR count, x, y, i, clr1, clr2: SIGNED16; b: CHAR;
BEGIN
	x:= 0; y:= 0;
	WHILE ~R.eof DO
		Files.Read(R, b);
		IF b # 0X THEN (* encoded *)
			count:= ORD(b); Files.Read(R, b);
			clr1 := ORD(b) DIV 16; clr2 := ORD(b) MOD 16;
			i := 1;
			FOR i := 1 TO count DO
				IF ODD(i) THEN Pictures.Dot(pict, ColorMap[clr1], x, y, Display.replace)
				ELSE Pictures.Dot(pict, ColorMap[clr2], x, y, Display.replace)
				END;
				INC(x)
			END
		ELSE
			Files.Read(R, b);
			IF b > 2X THEN (* absolute *)
				count:= ORD(b);
				FOR i := 1 TO count DO
					IF ODD(i) THEN
						Files.Read(R, b);
						Pictures.Dot(pict, ColorMap[ORD(b) DIV 16], x, y, Display.replace)
					ELSE
						Pictures.Dot(pict, ColorMap[ORD(b) MOD 16], x, y, Display.replace)
					END;
					INC(x)
				END;
				IF (count-1) MOD 4 < 2 THEN Files.Read(R, b) END
			ELSIF b = 0X THEN x := 0; INC(y) (* end of line *)
			ELSIF b = 1X THEN RETURN (* end of data *)
			ELSIF b = 2X THEN (* Delta-Record *)
				Files.Read(R, b); INC(x, ORD(b));
				Files.Read(R, b); INC(y, ORD(b))
			END
		END
	END
END LoadRLE4;

PROCEDURE LoadRGB8 (VAR R: Files.Rider; pict: Pictures.Picture);
VAR x, y: SIGNED16; b: CHAR;
BEGIN
	x:= 0; y:= 0;
	WHILE ~R.eof DO
		Files.Read(R, b);
		Pictures.Dot(pict, ColorMap[ORD(b)], x, y, Display.replace); INC(x);
		IF (x >= pict.width) & (x MOD 4 = 0) THEN x:= 0; INC(y) END
	END
END LoadRGB8;

PROCEDURE LoadRGB4 (VAR R: Files.Rider; pict: Pictures.Picture);
VAR x, y: SIGNED16; b: CHAR;
BEGIN
	x:= 0; y:= 0;
	WHILE ~R.eof DO
		Files.Read(R, b);
		Pictures.Dot(pict, ColorMap[ORD(b) DIV 16], x, y, Display.replace); INC(x);
		Pictures.Dot(pict, ColorMap[ORD(b) MOD 16], x, y, Display.replace); INC(x);
		IF (x >= pict.width) & (x MOD 8 = 0) THEN x:= 0; INC(y) END
	END
END LoadRGB4;

PROCEDURE LoadRGB1 (VAR R: Files.Rider; pict: Pictures.Picture);
VAR p: SIGNED32; i, x, y: SIGNED16; b: CHAR;
BEGIN
	x := 0; y := 0;
	WHILE ~R.eof DO
		Files.Read(R, b); p := ORD(b); INC(x, 8);
		FOR i := 0 TO 7 DO
			IF ODD(p) THEN Pictures.Dot(pict, 0, x - i, y, Display.replace)
			ELSE Pictures.Dot(pict, 15, x - i, y, Display.replace)
			END;
			p := ASH(p, -1)
		END;
		IF (x >= pict.width) & (x MOD 32 = 0) THEN x := 0; INC(y) END
	END
END LoadRGB1;

PROCEDURE CheckFile*(VAR R: Files.Rider): BOOLEAN;
	VAR fHeader: FileHeader;
BEGIN
	ScanFileHeader(R, fHeader);
	RETURN fHeader.type = TypeTag
END CheckFile;

(** Read BMP file.  colorConversion indicates if the BMP file palette and contents should be converted to
the current physical palette. Color matching is done by euclidean distance *)
PROCEDURE LoadBmp* (VAR R: Files.Rider; colorConversion: BOOLEAN; pict: Pictures.Picture);
VAR F: Files.File; pos: SIGNED32; fHeader: FileHeader; bHeader: BitmapHeader;
BEGIN
	pos := Files.Pos(R); F := Files.Base(R);
	ScanFileHeader(R, fHeader);
	IF fHeader.type # TypeTag THEN Files.Set(R, F, pos); RETURN END;

	ScanBitmapHeader(R, bHeader);
	IF ~(bHeader.depth IN {1, 4, 8}) THEN WriteError("BMP-format not supported"); RETURN END;
	Pictures.Create(pict, SHORT(bHeader.width), SHORT(bHeader.height), SHORT(bHeader.depth));
	IF pict.depth = 0 THEN WriteError("not enough memory"); RETURN ELSE pict.handle := Handle END;

	(* do the color stuff *)
	Files.Set(R, F, pos + FHeaderSize + bHeader.size);
	IF bHeader.clrUsed = 0 THEN bHeader.clrUsed := ASH(1, pict.depth) END;
	ScanCol(R, pict, bHeader.clrUsed, colorConversion);

	(* load pix data *)
	Files.Set(R, F, pos + fHeader.offBits);
	IF bHeader.compression = RLE8 THEN LoadRLE8(R, pict)
	ELSIF bHeader.compression = RLE4 THEN LoadRLE4(R, pict)
	ELSIF bHeader.compression = RGB THEN
		IF bHeader.depth = 1 THEN LoadRGB1(R, pict)
		ELSIF bHeader.depth = 4 THEN LoadRGB4(R, pict)
		ELSIF bHeader.depth = 8 THEN LoadRGB8(R, pict)
		END
	ELSE WriteError("BMP-format not supported")
	END
END LoadBmp;

PROCEDURE Handle* (obj: Objects.Object; VAR M: Objects.ObjMsg);
	VAR pos: SIGNED32;
BEGIN
	WITH obj: Pictures.Picture DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF (M.id = Objects.get) & (M.name = "Gen") THEN
					M.class := Objects.String; COPY("Pictures.NewPicture", M.s); M.res:=0
				END;
			END;
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF (M.id = Objects.load) THEN
					error := FALSE;  pos := Files.Pos(M.R); LoadBmp(M.R, FALSE, obj); (* LoadBmp; TRUE -> FALSE, fof 030904 *)
					IF error THEN M.len := 0 ELSE M.len := Files.Pos(M.R) - pos END
				ELSE
					Pictures.Handle(obj, M)
				END
			END
		ELSE
			Pictures.Handle(obj, M)
		END
	END
END Handle;

(** Called from Pictures.Open to try and load a BMP picture. The picture descriptor is pre-allocated by Pictures in
Objects.NewObj. InitPicture overwrites the handler of the picture with a new handler that will load the BMP picture
when a FileMsg is received (variant load). *)
PROCEDURE InitPicture*;
BEGIN Objects.NewObj.handle := Handle
END InitPicture;

PROCEDURE NewPicture*;
	VAR P: Pictures.Picture;
BEGIN NEW(P); P.handle := Handle; Objects.NewObj := P
END NewPicture;

BEGIN Texts.OpenWriter(W)
END BMP.

System.Free BMP ~
