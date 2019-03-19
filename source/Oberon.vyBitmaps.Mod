MODULE vyBitmaps IN Oberon;
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


IMPORT Files, vyBase, vyHostTexts;

CONST
	ClusterSize = 1024;
	MaxNumOfClusters = 1024;
	BUFSIZE = 1024;

TYPE
	Color* = RECORD r*, g*, b*: INTEGER  END;
	Colors* = ARRAY 256 OF Color;

	PixelCluster = POINTER TO PixelClusterDesc;
	PixelClusterDesc = RECORD
		pixel: ARRAY ClusterSize OF SET
	END;

	PClusterArray = ARRAY MaxNumOfClusters OF PixelCluster;

	(*		EdgesCluster = POINTER TO EdgesClusterDesc;
	EdgesClusterDesc = RECORD
	edge: ARRAY ClusterSize OF SET;
	END;

	EClusterArray= ARRAY MaxNumOfClusters OF EdgesCluster;*)

	tBitmap* = POINTER TO tBitmapDesc;
	tBitmapDesc* = RECORD
		(vyBase.ObjDesc)
		W-, H-, Depth-, ColorDepth-: INTEGER;
		PCluster: POINTER TO PClusterArray;
		(* ECluster: POINTER TO EClusterArray; *)
		colors-: Colors
	END;

VAR
	NPOS, NCLUSTER, NSET, NBIT: LONGINT;
	BUFFER:  ARRAY BUFSIZE OF CHAR;

PROCEDURE exp2* (z: INTEGER): INTEGER;   VAR
BEGIN
	RETURN INTEGER(ASH(1, z))
END exp2;

PROCEDURE bit* (VAR pos: SHORTINT;  VAR number: INTEGER): INTEGER;
BEGIN (* returns 1 if bit is set, else 0 *)
	RETURN number MOD (exp2(pos + 1)) DIV (exp2(pos))
END bit;



PROCEDURE NewBitmap* (W, H, Depth, ColorDepth: LONGINT): tBitmap;
VAR
	NumOfClusters, NumOfBytes, i, j: LONGINT;  Bitmap: tBitmap;
BEGIN
	NEW(Bitmap);
	Bitmap.W := SHORT(W);  Bitmap.H := SHORT(H);
	NumOfBytes := (W * H) * Depth DIV MAX(SET) + 1 ;
	NumOfClusters := NumOfBytes DIV ClusterSize;
	IF NumOfClusters * ClusterSize < NumOfBytes THEN INC(NumOfClusters) END;
	NEW(Bitmap.PCluster);
	(* vyHostTexts.NoteSISI(vyHostTexts.cNotify,"NumOfBytes: ",NumOfBytes,"NumOfClusters: ",
	SHORT(NumOfClusters));
	vyHostTexts.NoteSI(vyHostTexts.cNotify,"ColorDepth",ColorDepth);
	vyHostTexts.NoteSI(vyHostTexts.cNotify,"Depth",Depth); *)
	i := 0;
	WHILE(i < NumOfClusters) DO
		NEW(Bitmap.PCluster[i]);
		j := 0;
		WHILE(j < ClusterSize) DO Bitmap.PCluster[i].pixel[j] := {};  INC(j); END;
		INC(i);
	END;
	WHILE(i < MaxNumOfClusters) DO Bitmap.PCluster[i] := NIL;  INC(i);  END;
	Bitmap.ColorDepth := SHORT(ColorDepth);
	Bitmap.Depth := SHORT(Depth);
	FOR i := 0 TO   exp2(Bitmap.ColorDepth) - 1 DO
		Bitmap.colors[i].r := 255 DIV ( exp2(SHORT(ColorDepth)) - 1) * SHORT( i);
		Bitmap.colors[i].g := Bitmap.colors[i].r;  Bitmap.colors[i].b := Bitmap.colors[i].r;
	END;
	(* Bitmap.ECluster := NIL; *)
	RETURN Bitmap;
END NewBitmap;

PROCEDURE GetPosition (bmp: tBitmap;  x, y: LONGINT;  VAR pos, cluster, set, bit: LONGINT);
BEGIN
	pos := x * bmp.Depth + bmp.W * y * bmp.Depth;
	cluster := pos DIV (MAX(SET) + 1) DIV (ClusterSize) ;
	set := pos DIV (MAX(SET) + 1) MOD (ClusterSize);
	bit :=  pos MOD (MAX(SET) + 1) ;
END GetPosition;


PROCEDURE SetNextPixel* (Bitmap: tBitmap; val: LONGINT);
	VAR i: INTEGER;
BEGIN
	i := Bitmap.Depth - 1;
	WHILE(i >= 0) DO
		IF ODD(ASH(val, - i)) THEN INCL(Bitmap.PCluster[NCLUSTER].pixel[NSET], NBIT)
		ELSE EXCL(Bitmap.PCluster[NCLUSTER].pixel[NSET], NBIT) END;
		INC(NBIT);
		IF NBIT > MAX(SET) THEN NBIT := 0;  INC(NSET);
			IF NSET = ClusterSize THEN NSET := 0;  INC(NCLUSTER);  END;
		END;
		DEC(i);
	END;
END SetNextPixel;

PROCEDURE SetAPixel* (Bitmap: tBitmap;  X, Y: LONGINT; val: LONGINT);
	VAR i: INTEGER;
BEGIN
	(*
	NPOS := X* Bitmap.Depth+Bitmap.W*Y * Bitmap.Depth;
	NCLUSTER := NPOS DIV (MAX(SET)+1) DIV (ClusterSize) ;
	NSET := NPOS DIV (MAX(SET)+1) MOD (ClusterSize);
	NBIT :=  NPOS MOD (MAX(SET)+1) ;
	*)
	GetPosition(Bitmap, X, Y, NPOS, NCLUSTER, NSET, NBIT);
	i := Bitmap.Depth - 1;
	WHILE(i >= 0) DO
		IF ODD(ASH(val, - i)) THEN INCL(Bitmap.PCluster[NCLUSTER].pixel[NSET], NBIT)
		ELSE EXCL(Bitmap.PCluster[NCLUSTER].pixel[NSET], NBIT) END;
		INC(NBIT);
		IF NBIT > MAX(SET) THEN NBIT := 0;  INC(NSET);
			IF NSET = ClusterSize THEN NSET := 0;  INC(NCLUSTER);  END;
		END;
		DEC(i);
	END;
END SetAPixel;

PROCEDURE SetARect* (Bitmap: tBitmap;  RectX, RectY, W, H: LONGINT; val: LONGINT);
	(*! Optimize. Should we have global Bresenham ? *)
	VAR i: INTEGER;  X, Y: LONGINT;
BEGIN
	ASSERT((W > 0) & (H > 0), 110);
	X := RectX; Y := RectY;  WHILE ((Y <= RectY + H) & (X <= RectX + W)) DO
		GetPosition(Bitmap, X, Y, NPOS, NCLUSTER, NSET, NBIT);
		i := Bitmap.Depth - 1;
		WHILE(i >= 0) DO
			IF ODD(ASH(val, - i)) THEN INCL(Bitmap.PCluster[NCLUSTER].pixel[NSET], NBIT)
			ELSE EXCL(Bitmap.PCluster[NCLUSTER].pixel[NSET], NBIT) END;
			INC(NBIT);
			IF NBIT > MAX(SET) THEN NBIT := 0;  INC(NSET);
				IF NSET = ClusterSize THEN NSET := 0;  INC(NCLUSTER);  END;
			END;
			DEC(i);
		END;
		IF (Y < RectY + H) THEN INC(Y) ELSE INC(X);  Y := RectY END;
	END;  (* WHILE  ((Y<=RectY+H) & (X<=RectX+W)) *)
END SetARect;

PROCEDURE SetALine* (Bitmap: tBitmap;  FromX, FromY, ToX, ToY: LONGINT; val: LONGINT);
	(*! Optimize. Should we have global Bresenham ? *)
	VAR  x, y: LONGINT;  d, dx, dy, dx2, dy2, inx, iny: LONGINT;
BEGIN
	ASSERT((FromX # ToX) OR (FromY # ToY), 110);
	dx := ToX - FromX;  dy := ToY - FromY;  x := FromX;  y := FromY;
	IF ABS(dy) > ABS(dx) THEN
		d := - ABS(dx);  dy2 := 2 * ABS(dy);  dx2 := 2 * ABS(dx);
		IF dx < 0 THEN inx := - 1;  ELSE inx := 1;  END;
		IF dy < 0 THEN iny := - 1;  ELSE iny := 1;  END;
		WHILE y # ToY DO
			INC(y, iny);
			INC(d, dx2);
			IF d > 0 THEN INC(x, inx);  DEC(d, dy2);  END;
			SetAPixel(Bitmap, x, y, val);
		END;  (* WHILE *)
	ELSE
		d := - ABS(dx);  dy2 := 2 * ABS(dy);  dx2 := 2 * ABS(dx);
		IF dx < 0 THEN inx := - 1;  ELSE inx := 1;  END;
		IF dy < 0 THEN iny := - 1;  ELSE iny := 1;  END;
		WHILE x # ToX DO
			INC(x, inx);
			INC(d, dy2);
			IF d > 0 THEN INC(y, iny);  DEC(d, dx2);  END;
			SetAPixel(Bitmap, x, y, val);
		END; (* WHILE *)
	END;
END SetALine;
(*
PROCEDURE GetNextPixel (Bitmap: tBitmap): LONGINT;
VAR val: LONGINT; i: INTEGER;
BEGIN
i := Bitmap.Depth-1; val := 0;
WHILE(i>=0) DO
IF (NBIT) IN Bitmap.PCluster[NCLUSTER].pixel[NSET] THEN INC(val,ASH(1,i)) END;
INC(NBIT);
IF NBIT > MAX(SET) THEN NBIT:= 0; INC(NSET);
IF NSET = ClusterSize THEN NSET := 0; INC(NCLUSTER); END;
END;
DEC(i);
END;
RETURN val;
END GetNextPixel;
*)
PROCEDURE GetAPixel* (Bitmap: tBitmap;  X, Y: LONGINT): LONGINT;
	VAR val: LONGINT;  i: INTEGER;

BEGIN
	(*
	NPOS := X* Bitmap.Depth+Bitmap.W*Y * Bitmap.Depth;
	NCLUSTER := NPOS DIV (MAX(SET)+1) DIV (ClusterSize) ;
	NSET := NPOS DIV (MAX(SET) +1) MOD (ClusterSize);
	NBIT :=  NPOS MOD (MAX(SET)+1) ;
	*)
	GetPosition(Bitmap, X, Y, NPOS, NCLUSTER, NSET, NBIT);
	i := Bitmap.Depth - 1;  val := 0;
	WHILE(i >= 0) DO
		IF (NBIT) IN Bitmap.PCluster[NCLUSTER].pixel[NSET] THEN INC(val, ASH(1, i)) END;
		INC(NBIT);
		IF NBIT > MAX(SET) THEN NBIT := 0;  INC(NSET);
			IF NSET = ClusterSize THEN NSET := 0;  INC(NCLUSTER);  END;
		END;
		DEC(i);
	END;
	RETURN val;
END GetAPixel;

PROCEDURE SetAColor* (Bitmap: tBitmap;  i: INTEGER;  col: Color);
BEGIN Bitmap.colors[i] := col;
END SetAColor;

PROCEDURE WriteColor (RF: vyBase.FilesWriter;  col: Color);
BEGIN Files.WriteInt(RF, col.r);  Files.WriteInt(RF, col.g);  Files.WriteInt(RF, col.b);
END WriteColor;

PROCEDURE ReadColor (RF: vyBase.FilesReader;  VAR col: Color);
BEGIN Files.ReadInt(RF, col.r);  Files.ReadInt(RF, col.g);  Files.ReadInt(RF, col.b);
END ReadColor;


PROCEDURE Write* (VAR RF: vyBase.FilesWriter;  Bitmap: tBitmap );
VAR
	NumOfBytes, NumOfColors, count: LONGINT;
BEGIN
	Files.WriteInt(RF, Bitmap.W);  Files.WriteInt(RF, Bitmap.H);  Files.WriteInt(RF, Bitmap.Depth);
	Files.WriteInt(RF, Bitmap.ColorDepth);
	NumOfColors :=  exp2(Bitmap.ColorDepth);
	count := 0;
	WHILE(count < NumOfColors) DO WriteColor(RF, Bitmap.colors[count]);  INC(count);  END;
	NumOfBytes := (Bitmap.W * Bitmap.H) * Bitmap.Depth DIV MAX(SET) + 1 ;
	count := 0;
	WHILE(count < NumOfBytes) DO
		Files.WriteSet(RF, Bitmap.PCluster[count DIV ClusterSize].pixel[count MOD ClusterSize]);
		INC(count);
	END;
END Write;

PROCEDURE Read* (VAR RF: vyBase.FilesReader;  VAR Bitmap: tBitmap);
VAR
	NumOfBytes, NumOfColors, count: LONGINT;
	W, H, Depth, ColorDepth : INTEGER;
BEGIN
	Files.ReadInt(RF, W);  Files.ReadInt(RF, H);  Files.ReadInt(RF, Depth);
	Files.ReadInt(RF, ColorDepth);
	Bitmap := NewBitmap(W, H, Depth, ColorDepth);
	NumOfColors :=  exp2(Bitmap.ColorDepth);
	count := 0;
	WHILE(count < NumOfColors) DO ReadColor(RF, Bitmap.colors[count]);  INC(count);  END;
	NumOfBytes := (Bitmap.W * Bitmap.H) * Bitmap.Depth DIV MAX(SET) + 1 ;
	count := 0;
	WHILE(count < NumOfBytes) DO
		Files.ReadSet(RF, Bitmap.PCluster[count DIV ClusterSize].pixel[count MOD ClusterSize]);
		INC(count);
	END;
END Read;

PROCEDURE ImportGIF* (VAR RF: vyBase.FilesReader;  VAR Bitmap: tBitmap);
TYPE
	codes = ARRAY 2 OF INTEGER;
VAR

	chars: ARRAY 32 OF CHAR;
	char : CHAR;
	int: INTEGER;
	count: INTEGER;

	SW, SH: LONGINT;  (* screenwidth / height *)
	SColors: Colors;
	globalcolormap: BOOLEAN;
	bitsofcolres, bitsperpixel, backgroundcolor: INTEGER;
	IX, IY, IW, IH: LONGINT;
	localcolormap, seqentialordered: BOOLEAN;
	bitsperpixelinimage: INTEGER;

	minimumcodesize: INTEGER;
	byte: INTEGER;
	blocksize: INTEGER;
	bytecount: INTEGER;
	bytepos: SHORTINT;
	msgcount : INTEGER;
	fpos : INTEGER;

PROCEDURE LoadBuffer;
BEGIN
	Files.ReadBytes(RF, BUFFER, BUFSIZE);
END LoadBuffer;


PROCEDURE getnextint (numberofbits: INTEGER): INTEGER;
VAR
	val: INTEGER;
	intpos: SHORTINT;
BEGIN
	val := 0;
	intpos := 0;
	REPEAT
		IF bytepos > 7 THEN
			INC(fpos);  IF fpos >= BUFSIZE THEN LoadBuffer() ; fpos := 0;  END;
			INC(bytecount);
			IF bytecount - 1 = blocksize THEN
				blocksize := ORD(BUFFER[fpos]);
				bytecount := 1;
				INC(msgcount);
				IF (msgcount > 9) THEN
					msgcount := 0;
					vyHostTexts.Note(vyHostTexts.cNotify, ".");
				END;
				INC(fpos);   IF fpos >= BUFSIZE THEN LoadBuffer() ; fpos := 0;  END;
			END;
			(*ASSERT(~RF.eof); *)
			byte := ORD(BUFFER[fpos]);
			bytepos := 0;
		END;
		val := val +  exp2(intpos) * bit(bytepos, byte);
		INC(bytepos);
		INC(intpos);
	UNTIL intpos = numberofbits ;

	RETURN val;

END getnextint;


PROCEDURE decompress;
VAR
	stt : ARRAY 4096 OF codes;  (* code table *)
	sttlen: INTEGER;  (* length of code table *)
	codesize, rootsize: INTEGER;
	cc, eoi, code, old: INTEGER;
	(*	i: LONGINT; *)

PROCEDURE output (VAR input: INTEGER);

BEGIN
	ASSERT(input <= sttlen);
	IF input <= rootsize THEN
		SetNextPixel(Bitmap, input);
	ELSE
		output(stt[input, 0]);
		output(stt[input, 1]);
	END;
END output;


PROCEDURE findfirstchar (VAR input: INTEGER): INTEGER;
BEGIN
	IF input <= rootsize THEN
		RETURN input;
	ELSE
		RETURN findfirstchar(stt[input, 0])
	END;
END findfirstchar;



BEGIN
	NPOS := 0;  NCLUSTER := 0;  NSET := 0; NBIT := 0;
	LoadBuffer(); fpos := - 1;
	msgcount := 0;  bytecount := 0;  bytepos := 8;
	rootsize :=  exp2(minimumcodesize);
	codesize := minimumcodesize + 1;
	IF codesize = 2 THEN cc := 4;  eoi := 5;  codesize := 3;  sttlen := 6;  ELSE
	cc := INTEGER(ASH(1, minimumcodesize));  eoi := cc + 1;  sttlen := cc + 2;  END;

	REPEAT
		code := getnextint(codesize);
	UNTIL (code # cc)	; 	(* do that, because first code should be cc *)

	SetNextPixel(Bitmap, code);  (* first code is root ! *)
	old := code;

	LOOP
		code := getnextint(codesize);
		IF code = eoi THEN  RETURN;
		ELSIF code = cc THEN
			codesize := minimumcodesize + 1;
			IF codesize = 2 THEN cc := 4;  eoi := 5;  codesize := 3;  sttlen := 6;  ELSE
			cc := INTEGER(ASH(1, minimumcodesize));  eoi := cc + 1;  sttlen := cc + 2;  END;
			code := getnextint(codesize);
			IF code = eoi THEN  RETURN;  END;
			SetNextPixel(Bitmap, code);
			old := code;
		ELSE
			stt[sttlen, 0] := old;
			IF code < sttlen THEN
				output(code);
				stt[sttlen, 1] := findfirstchar(code);
			ELSE
				stt[sttlen, 1] := findfirstchar(old);
				output (sttlen);
			END;
			INC(sttlen);
			IF sttlen = ( exp2(codesize)) THEN
				INC(codesize);
			END;
			old := code;
		END;
	END;

END decompress;


BEGIN

	Files.ReadBytes(RF, chars, 6);
	chars[6] := 0X;
	IF (chars[0] # "G") OR (chars[1] # "I") OR (chars[2] # "F") THEN
		vyHostTexts.Note(vyHostTexts.cNotify, "no GIF File");
		RETURN ;
	END;
	vyHostTexts.Note(vyHostTexts.cNotify, "Loading image of type: ");
	vyHostTexts.Note(vyHostTexts.cNotify, chars);
	Files.ReadBytes(RF, chars, 4);
	SW := ORD(chars[0]) + 256 * ORD(chars[1]);
	SH := ORD(chars[2]) + 256 * ORD(chars[3]);
	Files.ReadBytes(RF, chars, 3);
	int := ORD(chars[0]);
	IF (int DIV 128) = 1 THEN
		globalcolormap := TRUE;
	ELSE
		globalcolormap := FALSE
	END;
	int := int MOD 128;
	bitsofcolres := int DIV 16 + 1;
	int := int MOD 16;
	bitsperpixel := int + 1;
	backgroundcolor := ORD(chars[1]);

	IF globalcolormap THEN
		count := 0;
		WHILE(count <  exp2(bitsperpixel)) DO
			Files.ReadBytes(RF, chars, 3);
			SColors[count].r := ORD(chars[0]);
			SColors[count ].g := ORD(chars[1]);
			SColors[count].b := ORD(chars[2]);
			INC(count);
		END;
	END;




	Files.ReadBytes(RF, chars, 10);
	IF chars[0] # ","THEN
		vyHostTexts.Note(vyHostTexts.cNotify, "no image seperation character found .. ??.");
	END;

	IX := ORD(chars[1]) + 256 * ORD(chars[2]);
	IY := ORD(chars[3]) + 256 * ORD(chars[4]);
	IW := ORD(chars[5]) + 256 * ORD(chars[6]);
	IH := ORD(chars[7]) + 256 * ORD(chars[8]);
	int := ORD(chars[9]);

	Bitmap := NewBitmap(SHORT(IW), SHORT(IH), bitsperpixel, bitsperpixel);
	Bitmap.colors :=  SColors;

	IF (int DIV 128) = 1 THEN
		localcolormap := TRUE;
	ELSE
		localcolormap := FALSE;
	END;

	int := int MOD 128;

	IF (int DIV 64) = 1 THEN
		seqentialordered := FALSE;
	ELSE
		seqentialordered := TRUE;
	END;

	int := int MOD 8;

	bitsperpixelinimage := int + 1;


	IF localcolormap THEN
		vyHostTexts.Note(vyHostTexts.cNotify, "image contents a local color map, not yet supported !");
		vyHostTexts.Note(vyHostTexts.cNotify, "please take files with only one image !");
		RETURN ;
	END;

	IF ~seqentialordered THEN
		vyHostTexts.Note(vyHostTexts.cNotify, "image is not seqential ordered, not yet supported !");
		RETURN ;
	END;

	Files.Read(RF, char);
	minimumcodesize := ORD(char);
	Files.Read(RF, char);
	blocksize := ORD(char);
	vyHostTexts.Note(vyHostTexts.cNotify, "decoding image, please wait ");

	decompress;
	Files.Read(RF, char);
	Files.Read(RF, char);
	IF char # ";"THEN vyHostTexts.Note(vyHostTexts.cNotify, "FileEnd not found");  END;

	vyHostTexts.Note(vyHostTexts.cNotify, "image loaded .");
	RETURN ;





END ImportGIF;

PROCEDURE ExportGIF* (VAR RF: vyBase.FilesWriter;  Bitmap: tBitmap);

TYPE
	codes = ARRAY 2 OF INTEGER;
VAR

	filespos : LONGINT;
	x, y: INTEGER;
	chars: ARRAY 32 OF CHAR;
	char : CHAR;
	count: INTEGER;



	minimumcodesize: INTEGER;


	byte: INTEGER;
	blocksize: INTEGER;
	bytecount: INTEGER;
	bytepos: SHORTINT;





PROCEDURE compress;
VAR

	stt : ARRAY 4096 OF codes;  (* code table *)
	sttlen: INTEGER;  (* length of code table *)
	codesize: INTEGER;  (* codesize in pixel *)
	cc: INTEGER;
	eoi : INTEGER;
	new: INTEGER;
	code : codes;
	i: LONGINT;
	fp: LONGINT;

PROCEDURE resetstt;

BEGIN
	(* stt is only dummy-array for the roots !*)
	codesize := minimumcodesize + 1;

	IF codesize = 2 THEN
		cc := 4;
		eoi := 5;
		codesize := 3;
		sttlen := 6;
	ELSE
		cc :=  exp2(minimumcodesize);
		eoi :=  exp2(minimumcodesize) + 1;
		sttlen :=  exp2(minimumcodesize) + 2;
	END;
END resetstt;


PROCEDURE getnextcol (): INTEGER;

BEGIN
	x := SHORT(i MOD (Bitmap.W));
	y := SHORT(i DIV (Bitmap.W));
	IF y >= Bitmap.H THEN
	RETURN - 1;  END;
	INC(i);

	RETURN SHORT(GetAPixel(Bitmap, x, y));
END getnextcol;



PROCEDURE codeinstt (c: codes): INTEGER;
VAR
	m: INTEGER;
BEGIN
	m := eoi + 1;
	WHILE m < sttlen DO
		IF (c[0] = stt[m, 0]) & (c[1] = stt[m, 1]) THEN RETURN m;  END;
		INC(m);
	END;
	RETURN - 1;
END codeinstt;

PROCEDURE storeinstt (c: codes);
VAR
BEGIN
	stt[sttlen] := c;
	INC(sttlen);
END storeinstt;


PROCEDURE output (val, numberofbits: INTEGER);

VAR
	intpos: SHORTINT;
BEGIN
	intpos := 0;
	REPEAT
		IF bytepos > 7 THEN
			char := CHR(byte);
			Files.Write(RF, char);
			INC(bytecount);
			IF bytecount = blocksize THEN
				char := CHR(blocksize);
				bytecount := 0;
				filespos := Files.Pos(RF);
				Files.Write(RF, char);
			END;
			bytepos := 0;
			byte := 0;
		END;
		byte := byte +  exp2(bytepos) * bit(intpos, val);
		INC(bytepos);
		INC(intpos);
	UNTIL intpos = numberofbits ;


END output;


BEGIN
	bytepos := 0;
	bytecount := 0;
	byte := 0;
	i := 0;
	resetstt;

	output(cc, codesize);

	code[0] := getnextcol();
	code[1] := getnextcol();

	WHILE (code[1] # - 1) DO  (* are there still any pixels ? *)
		new := codeinstt(code);    (* is that code already in codetable ? *)
		IF (new # - 1) THEN	(* it is -> code[0] gets codenumber *)
			code[0] := new;
		ELSE					(* it isn`t -> code gets stored *)
			storeinstt(code);

			output(code[0], codesize);  	(* code[0] is put out *)

			IF sttlen - 1 = ( exp2(codesize)) THEN
				INC(codesize);
			END;
			IF sttlen = ( exp2(12)) THEN
				output(cc, codesize);
				resetstt;
			END;
			code[0] := code[1]; 		(* code[0] is code[1] *)
		END;
		code[1] := getnextcol();
	END;
	output(code[0], codesize);
	output(cc, codesize);
	resetstt;
	output(eoi, codesize);
	Files.Write(RF, CHR(byte));
	fp := Files.Pos(RF);
	Files.Set(RF, Files.Base(RF), filespos);
	Files.Write(RF, CHR(SHORT(bytecount + 1)));
	Files.Set(RF, Files.Base(RF), fp);



END compress;


BEGIN

	vyHostTexts.Note(vyHostTexts.cNotify, "File Format Gif87a");
	COPY("GIF87a", chars);
	Files.WriteBytes(RF, chars, 6);
	chars[0] := CHR(Bitmap.W MOD 256);
	chars[1] := CHR(Bitmap.W DIV 256);
	chars[2] := CHR(Bitmap.H MOD 256);
	chars[3] := CHR(Bitmap.H DIV 256);
	Files.WriteBytes(RF, chars, 4);

	chars[0] := CHR(128 + 7 * 16 + Bitmap.ColorDepth - 1);
	chars[1] := CHR(0);
	chars[2] := CHR(0);
	Files.WriteBytes(RF, chars, 3);

	count := 0;
	WHILE(count <  exp2(Bitmap.ColorDepth)) DO
		chars[0] := CHR(Bitmap.colors[count].r) ;
		chars[1] := CHR(Bitmap.colors[count ].g );
		chars[2] := CHR(Bitmap.colors[count].b );
		Files.WriteBytes(RF, chars, 3);
		INC(count);
	END;


	chars[0] := ",";
	chars[1] := CHR(0 MOD 256);
	chars[2] := CHR(0 DIV 256);
	chars[3] := CHR(0 MOD 256);
	chars[4] := CHR(0 DIV 256);
	chars[5] := CHR(Bitmap.W MOD 256);
	chars[6] := CHR(Bitmap.W DIV 256);
	chars[7] := CHR(Bitmap.H MOD 256);
	chars[8] := CHR(Bitmap.H DIV 256);
	chars[9] := CHR(Bitmap.ColorDepth - 1);

	Files.WriteBytes(RF, chars, 10);

	minimumcodesize := Bitmap.ColorDepth;
	IF minimumcodesize # 1 THEN
		char := CHR(minimumcodesize);
	ELSE
		char := CHR(minimumcodesize + 1);
	END;


	Files.Write(RF, char);

	filespos := Files.Pos(RF);  (* for later identification of blocksize *)

	Files.Write(RF, CHR(255));
	blocksize := 255;

	vyHostTexts.Note(vyHostTexts.cNotify, "encoding image, please wait.");
	compress;

	Files.Write(RF, 0X);
	Files.Write(RF, ";");

	vyHostTexts.Note(vyHostTexts.cNotify, "image stored .");
	RETURN ;




END ExportGIF;

PROCEDURE CopyColors* (source: tBitmap;  VAR dest: tBitmap);
	VAR count : INTEGER;
BEGIN
	count := 0;
	WHILE(count < 256) DO dest.colors[count] := source.colors[count];  INC(count);  END;
END CopyColors;

PROCEDURE CopyBitmap* (source: tBitmap;  VAR dest: tBitmap);
	VAR NumOfBytes, count: LONGINT;
BEGIN
	dest := NewBitmap(source.W, source.H, source.Depth, source.ColorDepth);
	CopyColors(source, dest);
	NumOfBytes := (source.W * source.H) * source.Depth DIV MAX(SET) + 1 ;
	count := 0;
	WHILE(count < NumOfBytes) DO
		dest.PCluster[count DIV ClusterSize].pixel[count MOD ClusterSize] :=
		source.PCluster[count DIV ClusterSize].pixel[count MOD ClusterSize];
		INC(count);
	END;
END CopyBitmap;

PROCEDURE ResizedBitmap* (source: tBitmap;  w, h: INTEGER): tBitmap;
	VAR x, y, neww, newh: INTEGER;  dest: tBitmap;
BEGIN
	dest := NewBitmap(w, h, source.Depth, source.ColorDepth);
	CopyColors(source, dest);
	(*neww := vyCG.Min(w,source.W); *)	IF w <= source.W THEN neww := w ELSE neww := source.W END;
	(*	newh := vyCG.Min(h,source.H);*)IF h <= source.H THEN newh := h ELSE newh := source.H END;

	FOR y := 0 TO newh - 1 DO
		FOR x := 0 TO neww - 1 DO
			SetAPixel(dest, x, y, GetAPixel(source, x, y));
		END;
	END;
	RETURN dest;
END ResizedBitmap;

END vyBitmaps.

