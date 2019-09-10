(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE FontRes IN Oberon; (** non-portable / source: Win32.FontRes.Mod *)	(* MH 20.5.1994 *)	(* Converts Oberon Fonts to Windows FON Resources *)

IMPORT Out, Oberon, Texts, Files,SYSTEM;

CONST
	Version = "Ver 1.0 (MH May 20 1994)";
	FontFileId = 0DBX;
	SPC = 20X;
	normal = 0; italic = 1; bold = 2; medium = 3; (* style *)

TYPE
	FontInfo = RECORD	(* Version 2.0 *)
		version: SIGNED16;
		size: SIGNED32;
		copyright: ARRAY 60 OF CHAR;
		type: SIGNED16;
		points: SIGNED16;
		vertRes, horizRes: SIGNED16;
		ascent: SIGNED16;
		internalLeading, externalLeading: SIGNED16;
		italic, underline, strikeOut: CHAR;
		weight: SIGNED16;
		charSet: CHAR;
		pixWidth, pixHeight: SIGNED16;
		pitchAndFamily: CHAR;
		avgWidth, maxWidth: SIGNED16;
		firstChar, lastChar, defaultChar, breakChar: CHAR;
		widthBytes: SIGNED16;
		device: SIGNED32;
		face: SIGNED32;
		bitsPointer: SIGNED32;
		bitsOffset: SIGNED32;
		res: CHAR;
	END;

	CharEntry = RECORD
		width: SIGNED16;
		offs: SIGNED16;
	END;

VAR
	oname: ARRAY 64 OF CHAR;
	Info: FontInfo;
	CharTab: ARRAY 257 OF CharEntry; (* one dummy entry at the end *)
	PowTwo: ARRAY 9 OF SIGNED16; (* 2^0 .. 2^8 *)
	C: ARRAY 50 OF SIGNED32;	(* DOS Stub and New Executable Header *)

PROCEDURE Append (VAR s: ARRAY OF CHAR; suff: ARRAY OF CHAR);
	VAR i, j, max: SIZE;
BEGIN
	i := 0; j := 0; max := LEN(s)-1;
	WHILE s[i] # 0X DO INC(i) END;
	WHILE (i < max) & (suff[j] # 0X) DO s[i] := suff[j]; INC(i); INC(j) END;
	s[i] := 0X;
END Append;

PROCEDURE WriteStringFix (VAR out: Files.Rider; s: ARRAY OF CHAR; len: SIGNED16);
	VAR i: SIGNED16; ch: CHAR;
BEGIN i := 0;
	REPEAT ch := s[i]; Files.Write(out, ch); INC(i) UNTIL ch = 0X;
	ASSERT(i < len);
	WHILE i < len DO Files.Write(out, 0X); INC(i) END;
END WriteStringFix;

PROCEDURE Do (VAR R, out: Files.Rider; face: ARRAY OF CHAR; size: SIGNED16; style: SIGNED16; res: SIGNED16);
	CONST
		True = 1X; False = 0X;
	TYPE
		RunRec = RECORD beg, end: SIGNED16 END;
		BoxRec = RECORD dx, x, y, w, h: SIGNED16 END;
	VAR
		height, minX, maxX, minY, maxY, maxDX: SIGNED16;
		NofRuns, NofBoxes: SIGNED16;
		i, j, k, l, m, n, r, dx, x, y, w, h: SIGNED16;
		ascii: SIGNED16;
		run: ARRAY 16 OF RunRec;
		box: ARRAY 256 OF BoxRec;
		ch, raster: CHAR;
		map: POINTER TO ARRAY OF ARRAY OF CHAR;	(* raster font bitmap *)
		bitmapH: SIGNED16;	(* height of map in pixels *)
		bitmapW: SIGNED16;	(* width of map in bytes *)
		bitmapX: SIGNED16;	(* current offset in map from left, in bytes *)
		charW: SIGNED16;
		bitY, bitX: SIGNED16;
		fix: Files.Rider;
		FaceFixup1, FaceFixup2, FONTSizeFixup1, FONTSizeFixup2, BitsFixup, mapPos: SIGNED32;
		FontDirStartFix, FontStartFixup: SIGNED32;
		FontDirStart, FontDirEnd: SIGNED32; (* start and end of FONTDIR resource *)
		FontStart, FontEnd: SIGNED32; (* start and end of FONT resource *)
		s: ARRAY 128 OF CHAR;
BEGIN
	Info.version := 200H;	(* Version 2.0 *)
	Info.copyright := "Copyright (c) ETH Zuerich, Switzerland";
	Info.type := 0;
	Info.device := 0;
	Info.bitsPointer := 0;

	Files.Read(R, ch); Files.Read(R, ch); Files.Read(R, ch); (* abstraction, family, variant *)
	Files.ReadInt(R, height); (* line spacing *)
	Files.ReadInt(R, minX); Files.ReadInt(R, maxX);
	Files.ReadInt(R, minY); Files.ReadInt(R, maxY);
	bitmapH := maxY - minY;

	Info.points := size;
	Info.vertRes := res; Info.horizRes := res;
	Info.ascent := maxY;
	Info.internalLeading := 0;
	Info.externalLeading := 0 (*height - (maxY - minY)*);
	IF style = italic THEN Info.italic := True ELSE Info.italic := False END;
	Info.underline := False;
	Info.strikeOut := False;
	IF style = bold THEN Info.weight := 700
	ELSIF style = medium THEN Info.weight := 600
	ELSE Info.weight := 400
	END;
	Info.charSet := 0X;	(* ANSI_CHARSET *)
	Info.pixWidth := 0; (* proportional raster font *)
	Info.pixHeight := bitmapH;	(* height of map *)
	Info.pitchAndFamily := CHR(1 (* variable pitch *) + 0 (* FF_DONTCARE *));
	k := 0;
	WHILE k < 257 DO CharTab[k].width := 0; CharTab[k].offs := 0; INC(k) END;
	Files.ReadInt(R, NofRuns);
	NofBoxes := 0; r := 0;
	WHILE r # NofRuns DO
		Files.ReadInt(R, run[r].beg); Files.ReadInt(R, run[r].end);
		NofBoxes := NofBoxes + run[r].end - run[r].beg;
		INC(r)
	END;
	Info.firstChar := 0X;
	Info.lastChar := 0FFX;
	Info.defaultChar := SPC;
	Info.breakChar := SPC;

	l := 0;
	maxDX := MIN(SIGNED16); bitmapW := 0;
	WHILE l # NofBoxes DO
		Files.ReadInt(R, dx); box[l].dx := dx;
		IF maxDX < dx THEN maxDX := dx END;
		bitmapW := bitmapW + (dx + 7) DIV 8;
		Files.ReadInt(R, box[l].x); Files.ReadInt(R, box[l].y);
		Files.ReadInt(R, box[l].w); Files.ReadInt(R, box[l].h);
		INC(l)
	END;
	bitmapW := bitmapW +1 (*dummy character CharTab[256]*) + (-bitmapW) MOD 2;	(* bitmap width must be even *)
	Info.widthBytes := bitmapW;
	Info.maxWidth := maxDX;
	Info.avgWidth := Info.maxWidth;	(* patched with width of letter X later *)

	NEW(map, bitmapH, bitmapW);
	FOR i := 0 TO bitmapH - 1 DO
		FOR j := 0 TO bitmapW - 1 DO map[i, j] := 0X END;
	END;
	r := 0; l := 0; m := 0; bitmapX := 0; ascii := 0;
	WHILE r < NofRuns DO
		m := run[r].beg;

		(* fill in the gap between runs *)
		WHILE ascii < m DO
			CharTab[ascii].width := 0; CharTab[ascii].offs := bitmapX * bitmapH; INC(ascii)
		END;

		WHILE m < run[r].end DO
			dx := box[l].dx; x := box[l].x; y := box[l].y; w := box[l].w; h := box[l].h;
			CharTab[ascii].width := dx;
			IF ascii = ORD("X") THEN Info.avgWidth := dx END;
			CharTab[ascii].offs := bitmapX * bitmapH;

			charW := (dx + 7) DIV 8;	(* width of Windows character box in bytes *)
			i := 0; n := (w + 7) DIV 8;
			WHILE i < h DO j := 0;
				bitY := bitmapH - (-minY + y + i) - 1;	(* y coord of bit in Windows character box *)
				WHILE j < n DO
					Files.Read(R, raster);
					k := 0;
					WHILE k < 8 DO
						IF (j*8 + k) < w THEN
							IF ODD(ORD(raster) DIV PowTwo[k]) THEN (* bit k is set *)
								bitX := -minX + x + j*8 + k;	(* x coord of bit in Windows character box *)
								ch := map[bitY, bitmapX + (bitX DIV 8)];
								ch := CHR(ORD(ch) + PowTwo[7 - (bitX MOD 8)]);
								map[bitY, bitmapX + (bitX DIV 8)] := ch;
							END;
						END;
						INC(k);
					END;
					INC(j);
				END;
				INC(i);
			END;
			INC(bitmapX, charW);
			INC(l); INC(m); INC(ascii);
		END;
		INC(r)
	END;
	WHILE ascii < 256 DO
		CharTab[ascii].width := 0; CharTab[ascii].offs := bitmapX*bitmapH; INC(ascii)
	END;
	CharTab[256].width := 8; CharTab[256].offs := (bitmapW-1)*bitmapH; (* dummy entry *)

	(* Write FON file *)
	(* DOS Stub and New Executable header *)
	FOR i := 0 TO 47 DO Files.WriteLInt(out, C[i]) END;

	(* Resource Table *)
	Files.WriteInt(out, 0004H); (* alignment *)
	Files.WriteInt(out, -32761 (*8007H*)); (* RT_FONTDIR *)
	Files.WriteInt(out, 0001H); (* 1 FONTDIR resource *)
	Files.WriteLInt(out, 0); (* 4 bytes reserved *)
	FontDirStartFix := Files.Pos(out); Files.WriteInt(out, 0000H); (* FONTDIR start, fixup later *)
	Files.WriteInt(out, 0000H); (* FONTDIR length, fixup later *)
	Files.WriteInt(out, 0C50H); (* flags *)
	Files.WriteInt(out, 002CH); (* offset to resource identifier *)
	Files.WriteLInt(out, 0); (* 4 bytes reserved *)
	Files.WriteInt(out, -32760 (*8008H*)); (* RT_FONT *)
	Files.WriteInt(out, 0001H); (* 1 FONT resource *)
	Files.WriteLInt(out, 0); (* 4 bytes reserved *)
	FontStartFixup := Files.Pos(out); Files.WriteInt(out, 0000H); (* FONT resource start, fixup later *)
	Files.WriteInt(out, 0000H); (* FONT length, fixup later *)
	Files.WriteInt(out, 1C30H); Files.WriteInt(out, -32767 (*8001H*)); (* flags, resource id *)
	Files.WriteLInt(out, 0); (* 4 bytes reserved *)
	Files.WriteInt(out, 000H); (* end of resource table *)

	Files.Write(out, 7); s := "FONTDIR"; Files.WriteBytes(out, s, 7);
	Files.Write(out, 7); s := "FONTRES"; Files.WriteBytes(out, s, 7);
	Files.WriteLInt(out, 0); (* 4 bytes reserved *)

	s := "'FONTRES 100,96,96 : ";
	Append(s, oname);
	WriteStringFix(out, s, 48);

	ASSERT (Files.Pos(out) MOD 16 = 0);
	(* FONTDIR resource *)
	FontDirStart := Files.Pos(out);
	Files.WriteInt(out, 0001); (* 1 resource *)
	Files.WriteInt(out, 0001); (* font no 1 follows *)
	Files.WriteInt(out, Info.version);
	FONTSizeFixup1 := Files.Pos(out);
	Files.WriteLInt(out, Info.size);
	WriteStringFix(out, Info.copyright, 60);
	Files.WriteInt(out, Info.type);
	Files.WriteInt(out, Info.points);
	Files.WriteInt(out, Info.vertRes);
	Files.WriteInt(out, Info.horizRes);
	Files.WriteInt(out, Info.ascent);
	Files.WriteInt(out, Info.internalLeading);
	Files.WriteInt(out, Info.externalLeading);
	Files.Write(out, Info.italic);
	Files.Write(out, Info.underline);
	Files.Write(out, Info.strikeOut);
	Files.WriteInt(out, Info.weight);
	Files.Write(out, Info.charSet);
	Files.WriteInt(out, Info.pixWidth);
	Files.WriteInt(out, Info.pixHeight);
	Files.Write(out, Info.pitchAndFamily);
	Files.WriteInt(out, Info.avgWidth);
	Files.WriteInt(out, Info.maxWidth);
	Files.Write(out, Info.firstChar);
	Files.Write(out, Info.lastChar);
	Files.Write(out, Info.defaultChar);
	Files.Write(out, Info.breakChar);
	Files.WriteInt(out, Info.widthBytes);
	Files.WriteLInt(out, Info.device);
	FaceFixup1 := Files.Pos(out); Files.WriteLInt(out, Info.face);
	Files.WriteLInt(out, 0); (* reserved *)
	Files.WriteString(out, "DISPLAY");
	i := 0; REPEAT Files.Write(out, face[i]); INC(i) UNTIL face[i] = 0X;
	WHILE Files.Pos(out) MOD 16 # 0 DO Files.Write(out, 0X) END; (* filler bytes *)
	FontDirEnd := Files.Pos(out);
	ASSERT ((FontDirEnd - FontDirStart) MOD 16 = 0);

	(* FONT resource *)
	FontStart := Files.Pos(out);
	Files.WriteInt(out, Info.version);
	FONTSizeFixup2 := Files.Pos(out);
	Files.WriteLInt(out, Info.size);
	WriteStringFix(out, Info.copyright, 60);
	Files.WriteInt(out, Info.type);
	Files.WriteInt(out, Info.points);
	Files.WriteInt(out, Info.vertRes);
	Files.WriteInt(out, Info.horizRes);
	Files.WriteInt(out, Info.ascent);
	Files.WriteInt(out, Info.internalLeading);
	Files.WriteInt(out, Info.externalLeading);
	Files.Write(out, Info.italic);
	Files.Write(out, Info.underline);
	Files.Write(out, Info.strikeOut);
	Files.WriteInt(out, Info.weight);
	Files.Write(out, Info.charSet);
	Files.WriteInt(out, Info.pixWidth);
	Files.WriteInt(out, Info.pixHeight);
	Files.Write(out, Info.pitchAndFamily);
	Files.WriteInt(out, Info.avgWidth);
	Files.WriteInt(out, Info.maxWidth);
	Files.Write(out, Info.firstChar);
	Files.Write(out, Info.lastChar);
	Files.Write(out, Info.defaultChar);
	Files.Write(out, Info.breakChar);
	Files.WriteInt(out, Info.widthBytes);
	Files.WriteLInt(out, Info.device);
	FaceFixup2 := Files.Pos(out); Files.WriteLInt(out, Info.face);
	Files.WriteLInt(out, Info.bitsPointer);
	BitsFixup := Files.Pos(out);
	Files.WriteLInt(out, Info.bitsOffset);
	Files.Write(out, Info.res);
	mapPos := Files.Pos(out) - FontStart + 257*SIZEOF(CharEntry);
	FOR i := 0 TO 256 DO
		Files.WriteInt(out, CharTab[i].width);
		Files.WriteInt(out, SHORT(CharTab[i].offs + mapPos));
	END;
	(* character bitmaps *)
	Files.Set(fix, Files.Base(out), BitsFixup); Files.WriteLInt(fix, Files.Pos(out) - FontStart);
	FOR i := 0 TO Info.widthBytes - 1 DO
		FOR j := 0 TO Info.pixHeight - 1 DO
			Files.Write(out, map[j, i])
		END;
	END;
	Files.Set(fix, Files.Base(out), FaceFixup1); Files.WriteLInt(fix, Files.Pos(out)-FontStart);
	Files.Set(fix, Files.Base(out), FaceFixup2); Files.WriteLInt(fix, Files.Pos(out)-FontStart);
	i := 0; REPEAT Files.Write(out, face[i]); INC(i) UNTIL face[i] = 0X;
	Files.Write(out, 0X);
	Files.Set(fix, Files.Base(out), FONTSizeFixup1); Files.WriteLInt(fix, Files.Pos(out)-FontStart);
	Files.Set(fix, Files.Base(out), FONTSizeFixup2); Files.WriteLInt(fix, Files.Pos(out)-FontStart);
	WHILE Files.Pos(out) MOD 16 # 0 DO Files.Write(out, 0X) END; (* filler bytes *)
	FontEnd := Files.Pos(out);

	(* fixups in resource table *)
	Files.Set(fix, Files.Base(out), FontDirStartFix);
	Files.WriteInt(fix, SHORT(FontDirStart DIV 16)); Files.WriteInt(fix, SHORT((FontDirEnd - FontDirStart) DIV 16));
	Files.Set(fix, Files.Base(out), FontStartFixup);
	Files.WriteInt(fix, SHORT(FontStart DIV 16)); Files.WriteInt(fix, SHORT((FontEnd - FontStart) DIV 16));
END Do;


PROCEDURE ParseName (VAR name, faceName: ARRAY OF CHAR; VAR res, size, style: SIGNED16);
	VAR i, j: SIGNED16; fonttype: ARRAY 6 OF CHAR;
BEGIN
	(* face name in Windows raster font is Oberon font name *)
	COPY(name, faceName);
	i := 0;
	WHILE ("A" <= CAP(name[i])) & (CAP(name[i]) <= "Z") DO INC(i) END;
	size := 0;
	IF ("0" <= name[i]) & (name[i] <= "9") THEN
		size := ORD(name[i]) - ORD("0"); INC(i);
		IF ("0" <= name[i]) & (name[i] <= "9") THEN
			size := 10*size + ORD(name[i]) - ORD("0"); INC(i);
		END;
	END;
	style := normal;
	IF ("A" <= CAP(name[i])) & (CAP(name[i]) <= "Z") THEN
		CASE CAP(name[i]) OF
			| "I": style := italic;
			| "B": style := bold;
			| "M": style := medium;
		ELSE style := normal;
		END;
		INC(i);
	END;
	j := 0;
	WHILE j < 4 DO fonttype[j] := name[i]; INC(j); INC(i) END;
	fonttype[4] := 0X; res := 96
END ParseName;


PROCEDURE Convert*;	(** { OberonFontFile => [Path]WindowsFontFile } ~ **)
	VAR F, f: Files.File; R, r: Files.Rider;
		size, res, style: SIGNED16; ch: CHAR;
		face, wname: ARRAY 64 OF CHAR;
		S: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(text, beg, end, time);
		IF time > 0 THEN Texts.OpenScanner(S, text, beg); Texts.Scan(S) END;
	END;
	LOOP
		IF S.class # Texts.Name THEN EXIT END;
		COPY(S.s, oname);
		Texts.Scan(S); IF (S.class # Texts.Char) OR (S.c # "=") THEN EXIT END;
		Texts.Scan(S); IF (S.class # Texts.Char) OR (S.c # ">") THEN EXIT END;
		Texts.Scan(S); IF S.class # Texts.Name THEN EXIT END;
		COPY(S.s, wname);
		ParseName(oname, face, res, size, style);
		Out.String(face);
		F := Files.Old(oname);
		IF F # NIL THEN
			Files.Set(R, F, 0); Files.Read(R, ch);
			IF ch = FontFileId THEN
				f := Files.New(wname);
				IF f # NIL THEN
					Out.String("  =>  ");
					Files.Set(r, f, 0);
					Do(R, r, face, size, style, res);
					Files.Register(f);
					Out.String(wname); Out.Ln;
				END
			ELSE
				Out.String(" not a font"); Out.Ln;
			END;
			Files.Close(F)
		ELSE
			Out.String(" not found"); Out.Ln;
		END;
		Texts.Scan(S)
	END
END Convert;

PROCEDURE SetUnsigned(VAR dest: SIGNED32; src: SIGNED64);
BEGIN
	dest := SHORT(src);
END SetUnsigned;


PROCEDURE Init;
BEGIN
	SetUnsigned(C[0] , 0F75A4DH); SetUnsigned(C[1] , 1); SetUnsigned(C[2] , 4); SetUnsigned(C[3] , 0FFFFH);
	SetUnsigned(C[4] , 0B8H); SetUnsigned(C[5] , 0); SetUnsigned(C[6] , 40H); SetUnsigned(C[7] , 0);
	SetUnsigned(C[8] , 0); SetUnsigned(C[9] , 0); SetUnsigned(C[10] , 0); SetUnsigned(C[11] , 0);
	SetUnsigned(C[12] , 0); SetUnsigned(C[13] , 0); SetUnsigned(C[14] , 0); SetUnsigned(C[15] , 80H);
	SetUnsigned(C[16] , 0EBA1F0EH); SetUnsigned(C[17] , 0CD09B400H); SetUnsigned(C[18] , 4C01B821H); SetUnsigned(C[19] , 685421CDH);
	SetUnsigned(C[20] , 70207369H); SetUnsigned(C[21] , 72676F72H); SetUnsigned(C[22] , 72206D61H); SetUnsigned(C[23] , 69757165H);
	SetUnsigned(C[24] , 20736572H); SetUnsigned(C[25] , 7263694DH); SetUnsigned(C[26] , 666F736FH); SetUnsigned(C[27] , 69572074H);
	SetUnsigned(C[28] , 776F646EH); SetUnsigned(C[29] , 0A0D2E73H); SetUnsigned(C[30] , 24H); SetUnsigned(C[31] , 0);
	SetUnsigned(C[32] , 3205454EH); SetUnsigned(C[33] , 01007FH); SetUnsigned(C[34] , 0); SetUnsigned(C[35] , 8300H);
	SetUnsigned(C[36] , 0); SetUnsigned(C[37] , 0); SetUnsigned(C[38] , 0); SetUnsigned(C[39] , 0);
	SetUnsigned(C[40] , 40002BH); SetUnsigned(C[41] , 740040H); SetUnsigned(C[42] , 7F007FH); SetUnsigned(C[43] , 0100H);
	SetUnsigned(C[44] , 040000H); SetUnsigned(C[45] , 020000H); SetUnsigned(C[46] , 0); SetUnsigned(C[47] , 030A0000H);
END Init;

BEGIN Init;
	Out.String("Oberon to Windows Font Conversion Utility  "); Out.String(Version); Out.Ln;
	PowTwo[0] := 1; PowTwo[1] := 2; PowTwo[2] := 4; PowTwo[3] := 8;
	PowTwo[4] := 16; PowTwo[5] := 32; PowTwo[6] := 64; PowTwo[7] := 128; PowTwo[8] := 256;
END FontRes.


FontRes.Convert
Converts an Oberon screen font to a Windows FON resource that is used by Oberon for Windows to speed up text output. The Windows .FNT file format used to produce the resource is documented in the Microsoft Windows Programmer's Reference, Vol. 4, Chapter 4: Font File Format.

Syntax:
FontRes.Convert { OberonFontFile => [Path]WindowsFontFile } ~

Example:
FontRes.Convert Syntax10.Scn.Fnt => &SYNTA10.FON ~

Naming Convention:
The name of a FON file consists of 4 parts:

	NNNNNSSF.FON

where

	NNNNN	first five letters of font family name (e.g. Synta for Syntax, Math for Math)
	SS	maximum two digits for font size
	F	optional character for face style (b = bold, i = italics, m = medium)
	.FON	standard name extension

This naming convention is hard-coded into module Fonts. It allows module Fonts to search for Windows font
resources belonging to an Oberon font.

System.ChangeDirectory Fonts ~

FontRes.Convert
	Courier8.Scn.Fnt => COURI8.FON
	Courier10.Scn.Fnt => COURI10.FON
	Courier12.Scn.Fnt => COURI12.FON
	Math10.Scn.Fnt => MATH10.FON
	Math12.Scn.Fnt => MATH12.FON
	Math14.Scn.Fnt => MATH14.FON
	Math16.Scn.Fnt => MATH16.FON
	Math20.Scn.Fnt => MATH20.FON
	Math24.Scn.Fnt => MATH24.FON
	Greek10.Scn.Fnt => GREEK10.FON
	Greek12.Scn.Fnt => GREEK12.FON
	Greek14.Scn.Fnt => GREEK14.FON
	Greek16.Scn.Fnt => GREEK16.FON
	Greek20.Scn.Fnt => GREEK20.FON
	Greek24.Scn.Fnt => GREEK24.FON
	Oberon8.Scn.Fnt => OBERO8.FON
	Oberon8b.Scn.Fnt => OBERO8B.FON
	Oberon8i.Scn.Fnt => OBERO8I.FON
	Oberon10.Scn.Fnt => OBERO10.FON
	Oberon10b.Scn.Fnt => OBERO10B.FON
	Oberon10i.Scn.Fnt => OBERO10I.FON
	Oberon12.Scn.Fnt => OBERO12.FON
	Oberon12b.Scn.Fnt => OBERO12B.FON
	Oberon12i.Scn.Fnt => OBERO12I.FON
	Oberon14.Scn.Fnt => OBERO14.FON
	Oberon14b.Scn.Fnt => OBERO14B.FON
	Oberon14i.Scn.Fnt => OBERO14I.FON
	Oberon16.Scn.Fnt => OBERO16.FON
	Oberon16b.Scn.Fnt => OBERO16B.FON
	Oberon16i.Scn.Fnt => OBERO16I.FON
	Oberon20.Scn.Fnt => OBERO20.FON
	Oberon20b.Scn.Fnt => OBERO20B.FON
	Oberon20i.Scn.Fnt => OBERO20I.FON
	Oberon24.Scn.Fnt => OBERO24.FON
	Oberon24b.Scn.Fnt => OBERO24B.FON
	Oberon24i.Scn.Fnt => OBERO24I.FON
	Syntax8.Scn.Fnt => SYNTA8.FON
	Syntax8b.Scn.Fnt => SYNTA8B.FON
	Syntax8i.Scn.Fnt => SYNTA8I.FON
	Syntax8m.Scn.Fnt => SYNTA8M.FON
	Syntax10.Scn.Fnt => SYNTA10.FON
	Syntax10b.Scn.Fnt => SYNTA10B.FON
	Syntax10i.Scn.Fnt => SYNTA10I.FON
	Syntax10m.Scn.Fnt => SYNTA10M.FON
	Syntax12.Scn.Fnt => SYNTA12.FON
	Syntax12b.Scn.Fnt => SYNTA12B.FON
	Syntax12i.Scn.Fnt => SYNTA12I.FON
	Syntax12m.Scn.Fnt => SYNTA12M.FON
	Syntax14.Scn.Fnt => SYNTA14.FON
	Syntax14b.Scn.Fnt => SYNTA14B.FON
	Syntax14i.Scn.Fnt => SYNTA14I.FON
	Syntax14m.Scn.Fnt => SYNTA14M.FON
	Syntax16.Scn.Fnt => SYNTA16.FON
	Syntax16b.Scn.Fnt => SYNTA16B.FON
	Syntax16i.Scn.Fnt => SYNTA16I.FON
	Syntax16m.Scn.Fnt => SYNTA16M.FON
	Syntax20.Scn.Fnt => SYNTA20.FON
	Syntax20b.Scn.Fnt => SYNTA20B.FON
	Syntax20i.Scn.Fnt => SYNTA20I.FON
	Syntax20m.Scn.Fnt => SYNTA20M.FON
	Syntax24.Scn.Fnt => SYNTA24.FON
	Syntax24b.Scn.Fnt => SYNTA24B.FON
	Syntax24i.Scn.Fnt => SYNTA24I.FON
	Syntax24m.Scn.Fnt => SYNTA24M.FON ~
