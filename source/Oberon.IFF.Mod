(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE IFF IN Oberon;	(** portable *)	(* IFF Interleave bitmap files to Oberon Picture Format *)

	(*	November '96			first release						-> V 1.0	*)

IMPORT BIT IN A2,Display,Files,Objects,Pictures,Out;

CONST
	FORM = "FORM";	(* Start-Chunk of an iff-file *)
	ILBM = "ILBM";	(* Interleave Bitmap *)
	BMHD = "BMHD";	(* Bitmap Header *)
	CMAP = "CMAP";	(* Colormap *)
	BODY = "BODY";	(* Graphic Body *)

TYPE
	ChunkId = ARRAY 5 OF CHAR;

	ChunkHeader = RECORD
		id: ChunkId;
		len: SIGNED32;
	END;

	ILBMHD = RECORD
		w,h,x,y: SIGNED16;	(* picture dimension *)
		planes,	(* amount of bit planes *)
		masking,compression: CHAR;	(* mask and compression *)
		transparentCol: SIGNED16;
		xAspect,yAspect: CHAR;	(* relation width to height *)
		pageWidth,pageHeight: SIGNED16;	(* width and height of page *)
	END;
VAR
	ColorMap: ARRAY 256 OF SIGNED16;

PROCEDURE ReadChunkId(VAR R: Files.Rider; VAR id: ChunkId);
BEGIN
	Files.ReadBytes(R,id,4); id[4]:= 0X;
END ReadChunkId;

PROCEDURE ReadChunkHeader(VAR R: Files.Rider; VAR hd: ChunkHeader);
BEGIN
	ReadChunkId(R,hd.id);
	Files.ReadLInt(R,hd.len); hd.len:= BIT.LSWAP(hd.len);
END ReadChunkHeader;

PROCEDURE ReadILBMHD(VAR R: Files.Rider; VAR ilbmhd: ILBMHD);
	(* Scan the Interleave Bitmap Header *)
VAR
	filler: CHAR;
BEGIN
	Files.ReadInt(R,ilbmhd.w); Files.ReadInt(R,ilbmhd.h);
	Files.ReadInt(R,ilbmhd.x); Files.ReadInt(R,ilbmhd.y);
	Files.Read(R,ilbmhd.planes); Files.Read(R,ilbmhd.masking);
	Files.Read(R,ilbmhd.compression); Files.Read(R,filler);
	Files.ReadInt(R,ilbmhd.transparentCol);
	Files.Read(R,ilbmhd.xAspect); Files.Read(R,ilbmhd.yAspect);
	Files.ReadInt(R,ilbmhd.pageWidth); Files.ReadInt(R,ilbmhd.pageHeight);
END ReadILBMHD;

PROCEDURE ScanCol (VAR R: Files.Rider; pict: Pictures.Picture; nrColor: SIGNED32; conversion: BOOLEAN);
	(* copied from BMP.Mod *)
VAR Red, Green, Blue: CHAR; C, min, d, x, y, z: SIGNED32; i, j, minj: SIGNED16; r, g, b: ARRAY 256 OF SIGNED16;
BEGIN
	C := ASH(1, Display.Depth(0)) - 1;
	IF nrColor > C THEN nrColor := C ELSE DEC(nrColor) END;
	IF conversion THEN
		FOR i := 0 TO SHORT(C) DO Display.GetColor(i, r[i], g[i], b[i]) END;
		FOR i := 0 TO SHORT(nrColor) DO
			Files.Read(R, Red); Files.Read(R, Green); Files.Read(R, Blue);
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
			Pictures.SetColor(pict, i, r[i], g[i], b[i]);
		END
	ELSE
		FOR i := 0 TO SHORT(nrColor) DO
			Files.Read(R, Red); Files.Read(R, Green); Files.Read(R, Blue);
			Pictures.SetColor(pict, i, ORD(Red), ORD(Green), ORD(Blue));
			ColorMap[i] := i
		END
	END
END ScanCol;

PROCEDURE LoadIFF(VAR R: Files.Rider; transparentCol: SIGNED16; colorConversion: BOOLEAN; pict: Pictures.Picture);
	(* Load the IFF picture information into an Oberon Pictures.Picture *)
VAR
	hd: ChunkHeader;
	ilbmhd: ILBMHD;
	type: ChunkId;
	c,k,z: SIGNED8;
	line: POINTER TO ARRAY OF CHAR;
	start,bpos,cpos,hpos,size: SIGNED32;
	p,w,h,x,y,cols,rep,cnt: SIGNED16;
BEGIN
	start:= Files.Pos(R);
	ReadChunkHeader(R,hd);
	IF (hd.id # FORM) OR (hd.len # (Files.Length(Files.Base(R)))-8) THEN
		Files.Set(R,Files.Base(R),start);
	ELSE
		ReadChunkId(R,type); DEC(hd.len,4);
		WHILE ~R.eof & (hd.id = FORM) & (type # ILBM) DO
			Files.Set(R,Files.Base(R),Files.Pos(R)+hd.len);
			ReadChunkHeader(R,hd); ReadChunkId(R,type); DEC(hd.len,4);
		END;
		IF ~R.eof THEN
			size:= Files.Pos(R)+hd.len; cnt:= 3;
			WHILE ~R.eof & (Files.Pos(R) < size) & (cnt > 0) DO
				ReadChunkHeader(R,hd);
				IF (hd.id = BMHD) THEN
					hpos:= Files.Pos(R); ReadILBMHD(R,ilbmhd); DEC(cnt);
					Files.Set(R,Files.Base(R),hpos+hd.len);
				ELSIF (hd.id = CMAP) THEN
					cpos:= Files.Pos(R); cols:= SHORT(hd.len DIV 3); DEC(cnt);
					Files.Set(R,Files.Base(R),cpos+hd.len);
				ELSIF (hd.id = BODY) THEN
					bpos:= Files.Pos(R); DEC(cnt);
					Files.Set(R,Files.Base(R),bpos+hd.len);
				ELSE
					Files.Set(R,Files.Base(R),Files.Pos(R)+hd.len);
				END;
			END;
			IF (cnt = 0) THEN
				w:= BIT.ISWAP(ilbmhd.w)-1; h:= BIT.ISWAP(ilbmhd.h)-1;
				x:= 0; y:= h; p:= ORD(ilbmhd.planes);
				Out.String("Amiga InterleaveBitmap (ILBM)"); Out.Ln();
				Out.Int(w,0); Out.Char("*"); Out.Int(h,0); Out.String(", ");
				Out.Int(p,0); Out.String(" planes, ");
				Out.Int(cols,0); Out.String(" colors."); Out.Ln();
				NEW(line,w+1); Pictures.Create(pict,w+1,h+1,p);
				IF (pict.depth = 0) THEN
					Out.String("not enough memory"); Out.Ln();
				ELSE
					Files.Set(R,Files.Base(R),cpos);
					ScanCol(R,pict,cols,colorConversion);
					Files.Set(R,Files.Base(R),bpos);
					FOR rep:= 0 TO w DO line[rep]:= 0X; END;
					WHILE (y >= 0) DO	(* picture scan lines *)
						rep:= 0; cnt:= 0; z:= 0;
						WHILE (z < p) DO	(* color planes *)
							IF (ilbmhd.compression = 0X) THEN
								Files.Read(R,c);
							ELSIF (ilbmhd.compression = 1X) THEN
								IF (rep > 0) THEN
									DEC(rep);
								ELSE
									Files.Read(R,c);
									IF (cnt > 0) THEN
										DEC(cnt);
									ELSIF (c <= 0) THEN
										rep:= ABS(c); Files.Read(R,c);
									ELSE
										cnt:= c; Files.Read(R,c);
									END;
								END;
							END;
							FOR k:= 7 TO 0 BY -1 DO
								IF BIT.BIT(c,k) THEN BIT.CSETBIT(line[x],z); END;
								IF (x = w) THEN k:= -1; x:= 0; INC(z); ELSE INC(x); END;
							END;
						END;
						FOR x:= 0 TO w DO
							Pictures.Dot(pict,ColorMap[ORD(line[x])],x,y,Display.replace);
							line[x]:= 0X;
						END;
						x:= 0; DEC(y); z:= 0;
					END;
				END;
			END;
		ELSE
			Files.Set(R,Files.Base(R),start);
		END;
	END;
END LoadIFF;

PROCEDURE Handle*(obj: Objects.Object; VAR msg: Objects.ObjMsg);
VAR
	pos: SIGNED32;
BEGIN
	WITH obj: Pictures.Picture DO
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN
					msg.class:= Objects.String; COPY("Pictures.NewPicture",msg.s); msg.res:=0
				END;
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF (msg.id = Objects.load) THEN
					pos:= Files.Pos(msg.R);
					LoadIFF(msg.R,14,TRUE,obj); msg.len:= Files.Pos(msg.R) - pos;
				ELSE
					Pictures.Handle(obj,msg)
				END;
			END;
		ELSE
			Pictures.Handle(obj, msg)
		END;
	END;
END Handle;

(** Called from Pictures.Open to try and load an PCX bitmap. The picture descriptor is pre-allocated by Pictures in
Objects.NewObj. InitPicture overwrites the handler of the picture with a new handler that will load the PCX
Picture when a FileMsg is received (variant load). *)
PROCEDURE InitPicture*;
BEGIN
	Objects.NewObj.handle:= Handle;
END InitPicture;

PROCEDURE NewPicture*;
VAR
	P: Pictures.Picture;
BEGIN
	NEW(P); P.handle:= Handle; Objects.NewObj:= P;
END NewPicture;

END IFF.
