(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE PCXImages IN Oberon;	(** portable *)	(* by afi *)

IMPORT BIT IN A2, Files, Images, Out, Display,SYSTEM;
TYPE
	PCXHeader = RECORD
		manufacturer,	(* File-Id, should be 10 for ZSoft *)
		version,	(* Version: 0 = V2.5 of PC Paintbrush
										  2 = V2.8 with palette information
										  3 = V2.8 without palette information
										  4 = PC Paintbrush for Windows
										  5 = V3.0 and above PC Paintbrush and PC Paintbrush Plus with palette *)
		encoding,	(* 1 = Run length encoding *)
		bits: CHAR;	(* Bits/Pixel - 1, 2, 4 or 8 *)
		xMin, yMin, xMax, yMax,	(* Logical image coordinates *)
		hRes, vRes: SIGNED16;	(* Resolution of the origin device in dpi *)
		palPos, picPos: SIGNED32;	(* File position of palette and picture data *)
		vMode, planes: CHAR;	(* not used *)
		bytesPerLine,	(* Bytes per Scan Line *)
		paletteInfo: SIGNED16	(* Color info: 0 = ?, 1 = Color, 2 = Grayscale *)
	END;

VAR pcxh: PCXHeader;
		pal: Images.Palette;

(* Scan the PCX File Header *)
PROCEDURE ReadPCXHeader(VAR R: Files.Rider; VAR pcxh: PCXHeader): BOOLEAN;
VAR filler: ARRAY 58 OF CHAR;
BEGIN
	Files.Read(R, pcxh.manufacturer);
	IF (pcxh.manufacturer # 0AX) THEN
		Files.Set(R, Files.Base(R), Files.Pos(R)-SIZEOF(CHAR));
		RETURN(FALSE)
	ELSE
		Files.Read(R, pcxh.version); Files.Read(R, pcxh.encoding);
		Files.Read(R, pcxh.bits);
		Files.ReadInt(R, pcxh.xMin); Files.ReadInt(R, pcxh.yMin);
		Files.ReadInt(R, pcxh.xMax); Files.ReadInt(R, pcxh.yMax);
		Files.ReadInt(R, pcxh.hRes); Files.ReadInt(R, pcxh.vRes);
		IF (pcxh.bits <= 4X) OR (pcxh.version = 00X) OR (pcxh.version = 03X) THEN
			pcxh.palPos := Files.Pos(R)
		ELSE
			pcxh.palPos := Files.Length(Files.Base(R)) - (256 * 3)
		END;
		Files.ReadBytes(R, filler, 48);
		Files.Read(R, pcxh.vMode); Files.Read(R, pcxh.planes);
		Files.ReadInt(R, pcxh.bytesPerLine); Files.ReadInt(R, pcxh.paletteInfo);
		Files.ReadBytes(R, filler, 58); pcxh.picPos := Files.Pos(R);
		RETURN(TRUE)
	END
END ReadPCXHeader;

(* Write the PCX File Header *)
PROCEDURE WritePCXHeader(VAR R: Files.Rider; img: Images.Image);
VAR j: SIGNED16;
BEGIN
	Files.Write(R, 0AX);	(* manufacturer *)
	Files.Write(R, 5X);
	Files.Write(R, 1X);
	Files.Write(R, 8X);	(* full 256 colors *)
	Files.WriteInt(R, 0); Files.WriteInt(R, 0);
	Files.WriteInt(R, img.width-1); Files.WriteInt(R, img.height-1);
	Files.WriteInt(R, img.width-1); Files.WriteInt(R, img.height-1);
	j := 0;
	WHILE j < 48 DO Files.Write(R, 0X); INC(j) END;
	Files.Write(R, 0X);
	IF img.fmt.code = Images.bgr888 THEN
		Files.Write(R, 3X); Files.WriteInt(R, SHORT(img.bpr DIV 3))
	ELSE
		Files.Write(R, 1X); Files.WriteInt(R, SHORT(img.bpr))
	END;
	Files.WriteInt(R, 1);
	j := 0;
	WHILE j < 58 DO Files.Write(R, 0X); INC(j) END
END WritePCXHeader;

PROCEDURE LoadPCX(VAR R: Files.Rider; img: Images.Image);
VAR
(*	pcxh: PCXHeader;	*)
	line: ARRAY 4 OF POINTER TO ARRAY OF CHAR;
	x, y, z, w, h, rep, pcount: SIGNED16;
	k, p: SIGNED8;
	c: CHAR; fmt: Images.Format; pix, thispix: Images.Pixel; col: SIGNED16; colors: SIGNED32;
BEGIN
	IF ReadPCXHeader(R,pcxh) THEN
		w := pcxh.xMax-pcxh.xMin; h := pcxh.yMax-pcxh.yMin;
		p := 0; x := 0; y := h; z := ORD(pcxh.planes);
		Out.String("ZSoft PC Paintbrush"); Out.Ln;
		Out.String("Display color depth: "); Out.Int(ASH(1, Display.Depth(0)) - 1, 0); Out.Ln;
		Out.Int(w+1, 0); Out.Char("*"); Out.Int(h+1, 0); Out.String(", ");
		Out.Int(ORD(pcxh.bits), 0); Out.String(" bits, ");
		Out.Int(z, 0); Out.String(" planes, ");
		colors := ASH(1, z*ORD(pcxh.bits));
		Out.Int(colors, 0);
		IF pcxh.paletteInfo = 2 THEN Out.String(" grayscales, ") ELSE Out.String(" colors, ") END;
		Out.Int(pcxh.bytesPerLine, 0); Out.String(" bytes/line"); Out.Ln;
		IF (pcxh.bits # 1X) & (pcxh.bits # 4X) & (pcxh.bits # 8X) THEN
			Out.String("Plane depth not supported"); Out.Ln; RETURN
		END;
		IF (z * ORD(pcxh.bits) = 0) THEN
			Out.String("not enough memory"); Out.Ln
		ELSE
			FOR pcount := 0 TO z-1 DO
				NEW(line[pcount], w+1);
				FOR rep := 0 TO pcxh.xMax-1 DO line[pcount, rep] := 0X END
			END;
			IF (pcxh.bits = 8X) & (z = 3) THEN
				Images.Create(img, w+1, h+1, Images.BGR888)
			ELSE
				Files.Set(R, Files.Base(R), pcxh.palPos);
				(* color table *)
				NEW(pal); col := 0; pix[Images.a] := 0FFX;
				WHILE col < colors DO
					Files.Read(R, pix[Images.r]); Files.Read(R, pix[Images.g]); Files.Read(R, pix[Images.b]);
					pal.col[col] := pix;
					INC(col)
				END;
				Images.InitPalette(pal, SHORT(colors), 2 + ORD(pcxh.bits) DIV 4);
				Images.InitPaletteFormat(fmt, pal);
				Images.Create(img, w+1, h+1, fmt);
			END;

			Files.Set(R, Files.Base(R), pcxh.picPos);
			WHILE (y >= 0) DO	(* picture scan lines *)
				p := 0;
				WHILE (p < z) DO	(* color planes *)
					Files.Read(R, c);
					(* If bit 7 and 8 are both 1, run length encoding is activated *)
					IF (pcxh.encoding = 1X) & (BIT.CAND(c, 0C0X) = 0C0X) THEN
						rep := ORD(BIT.CAND(c, 3FX)); Files.Read(R, c);
					ELSE
						rep := 1
					END;
					WHILE (rep > 0) DO	(* run length encoding *)
						IF (pcxh.bits = 8X) & (z = 3) THEN	(* 24-bit, TrueColor *)
							line[p, x] := c;
							IF (x = w) THEN x := 0; INC(p);
							ELSE INC(x)
							END
						ELSIF (pcxh.bits = 8X) THEN	(* 8-bit, full 256 colors *)
							line[0, x] := c;
							IF (x = w) THEN x := 0; INC(p);
							ELSE INC(x)
							END
						ELSIF (pcxh.bits = 4X) THEN	(* 4-bit *)
							line[0, x] := BIT.CAND(c, 0F0X);
							line[0, x+1] := BIT.CAND(c, 00FX);
							IF (x = w-1) THEN x := 0; INC(p)
							ELSE x := x + 2
							END
						ELSIF (pcxh.bits = 1X) THEN	(* color plane coding *)
							FOR k := 7 TO 0 BY -1 DO
								IF BIT.BIT(ORD(c), k) THEN BIT.CSETBIT(line[0, x], p); END;
								IF (x = w) THEN k := -1; x := 0; INC(p) ELSE INC(x) END
							END
						END;
						DEC(rep);
					END
				END;
				IF (pcxh.bits = 8X) & (z = 3) THEN
					FOR x := 0 TO w DO
						Images.SetRGB(thispix, ORD(line[0, x]), ORD(line[1, x]), ORD(line[2, x]));
						Images.Put(img, x, y, thispix, Images.SrcCopy);
						line[0, x] := 0X; line[1, x] := 0X; line[2, x] := 0X
					END
				ELSE
					FOR x := 0 TO w DO
						Images.Put(img, x, y, pal.col[ORD(line[0, x])], Images.SrcCopy);
						line[0, x] := 0X
					END;
				END;
				x := 0; DEC(y); p := 0
			END
		END
	END
END LoadPCX;

PROCEDURE StorePCX(VAR R: Files.Rider; img: Images.Image);
VAR
	x, y, h, depth, inc, col, runcount, plane, maxplane: SIGNED16;
	fmt: Images.Format;
	count: SIGNED32;
	lastCh: CHAR;
	row: ARRAY 3 OF POINTER TO ARRAY OF CHAR; thisred, thisgreen, thisblue, thisalpha: SIGNED16; thispix: Images.Pixel;

	PROCEDURE ProcessRun (lastCh: CHAR; VAR runcount: SIGNED16);
	BEGIN
		IF (runcount = 1) & (BIT.CAND(lastCh, 0C0X) # 0C0X) THEN
		ELSE
			Files.Write(R, BIT.COR(CHR(runcount), 0C0X));
		END;
		Files.Write(R, lastCh);
		runcount := 0
	END ProcessRun;

BEGIN
	WritePCXHeader(R, img);
	(* find out which format to use *)
	pal := img.fmt.pal;
	IF (img.fmt.components = {Images.index}) & (pal # NIL) THEN	(* contains index information *)
		IF img.fmt.bpp > 4 THEN
			Images.InitPaletteFormat(fmt, pal);
			depth := 8
		END
	ELSE	(* calculate palette *)
		NEW(pal);
		Images.ComputePalette(img, pal, 16, 240, 4);
		Images.InitPaletteFormat(fmt, pal);
		depth := 8
	END;
	(* Write run-length encoded data *)
	NEW(row[0], img.width); h := img.height-1; inc := 8 DIV depth;
	IF img.fmt.code = Images.bgr888 THEN
		FOR plane := 1 TO 2 DO NEW(row[plane], img.width) END;
		maxplane := 3
	ELSE
		maxplane := 1
	END;
	y := h;
	WHILE y > 0 DO
		IF (pcxh.version = 05X) & (img.fmt.code = Images.bgr888) THEN
			x := 0;
			WHILE x < img.width DO
				Images.Get(img, x, y, thispix, Images.SrcCopy);
				Images.GetRGBA(thispix, thisred, thisgreen, thisblue, thisalpha);
				row[0]^[x] := CHR(thisred);
				row[1]^[x] := CHR(thisgreen);
				row[2]^[x] := CHR(thisblue);
				INC(x)
			END
		ELSE
			Images.GetPixels(img, 0, y, img.width, fmt, row[0]^, Images.SrcCopy);
		END;
		plane := 0;
		WHILE plane < maxplane DO
			x := 0; lastCh := row[plane]^[0];
			runcount := 0;
			count := 0;
			WHILE x < img.width DO
				IF row[plane]^[x] = lastCh THEN	(* There is a run *)
					INC(runcount); INC(x, inc);
					IF runcount = 63 THEN ProcessRun(lastCh, runcount) END
				ELSE
					ProcessRun(lastCh, runcount);
					lastCh := row[plane]^[x]
				END
			END;
			IF runcount > 0 THEN ProcessRun(lastCh, runcount) END;
			INC(plane)
		END;
		DEC(y)
	END;
	IF (pcxh.version = 05X) & (img.fmt.code # Images.bgr888) THEN
		Files.Write(R, 0CX);	(* Show the presence of a 256-color palette *)
		col := 0;
		WHILE col < 256 DO
			Files.Write(R, pal.col[col, Images.r]);
			Files.Write(R, pal.col[col, Images.g]);
			Files.Write(R, pal.col[col, Images.b]);
			INC(col)
		END
	END
END StorePCX;

PROCEDURE Load(img: Images.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
VAR F: Files.File; R: Files.Rider;
BEGIN
	done := FALSE;
	F := Files.Old(fname); Files.Set(R, F, 0);
	IF F # NIL THEN
		LoadPCX(R, img);
		done := TRUE
	END
END Load;

PROCEDURE Store (img: Images.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
VAR F: Files.File; R: Files.Rider;
BEGIN
	F := Files.New(fname); Files.Set(R, F, 0);
	StorePCX(R, img);
	Files.Register (F);
	done := TRUE
END Store;

PROCEDURE Install*;
BEGIN	Images.LoadProc := Load; Images.StoreProc := Store
END Install;

END PCXImages.

System.Free PCXImages ~
ImageDocs.Open sample.pcx ~
ImageDocs.Open ^ afi.pcx ~ image1.pcx
System.CopyFiles sample.pcx.Bak=> sample.pcx~
System.CopyFiles pic22869.pcx.Bak=> pic22869.pcx~
System.CopyFiles nm0169.pcx.Bak=> nm0169.pcx~
ImageDocs.Open nm0169.pcx ~
Hex.Open ^ afi.pcx
System.Directory *S.pcx*
readme.pcx Music.pcx

(** Remarks:

The PCX format is the native format of Z-Soft's PC Paintbrush program and uses run length encoding.
It has a 128-byte header followed by image data for monochrome as well as 4, 8 and 24-bit color images.
The palette for 4-bit images is included in the header while the 8-bit palette is appended after the image data.
This non-uniformity is the result of an older format being updated for newer hardware. For this reason,
the use of PCX has dwindled in favour of the more coherent and unified BMP.

*)
