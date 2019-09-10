(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GIF IN Oberon;	(** portable *) (* rm 1.9.1996, ejz 8.11.96 *)
	IMPORT Files, Objects, Display, Pictures;

	CONST
		dummy = -1;

	TYPE
		CodePages = RECORD
			code, ref: SIGNED16
		END;
		CodeBook = ARRAY 4096 OF CodePages;

		RGBType = RECORD
			r, g, b: CHAR
		END;
		ColorTable = RECORD
			colTrans, IcolTrans: ARRAY 256 OF SIGNED16;
			rgb: ARRAY 256 OF RGBType
		END;

		LogicalScrDesc = RECORD
			width, height: SIGNED16;
			GCTSize: SIGNED16;
			GCTFlag: BOOLEAN
		END;

		ImageDesc = RECORD
			left, top, width, height: SIGNED16;
			sequential, LCTFlag: BOOLEAN;
			LCTSize: SIGNED16;
			LCT: ColorTable
		END;

		ExtBlock = RECORD
			transparencyIndex: SIGNED16;
			transparency: BOOLEAN
		END;

		Gif = RECORD
			LSD: LogicalScrDesc;   (* logical Screen Descriptor *)
			GCT: ColorTable;  (* Global Color Table *)
			IDesc: ImageDesc; (* Image Descriptor *)
			Ext: ExtBlock
		END;

	VAR
		GifImage: Gif;
		CB: CodeBook;

	PROCEDURE ComputeColors(VAR CT: ColorTable; colorConversion: BOOLEAN);
		VAR
			x, y, z, min, d, red, green, blue: SIGNED32;
			r, g, b: ARRAY 256 OF SIGNED16;
			i, j, minj, size: SIGNED16;
	BEGIN
		size := 256;
		FOR i := 0 TO size-1 DO
			Display.GetColor(i, r[i], g[i], b[i]); CT.colTrans[i] := i; CT.IcolTrans[i] := i
		END;
		IF colorConversion THEN
			FOR i := 0 TO size-1 DO
				red := ORD(CT.rgb[i].r); green := ORD(CT.rgb[i].g); blue := ORD(CT.rgb[i].b);
				j := 0; minj := 0; min := MAX(SIGNED32);
				WHILE (j < size) & (min > 0) DO
					x := ABS(red-r[j]); y := ABS(green-g[j]); z := ABS(blue-b[j]);
					d := x; IF y > d THEN d := y END; IF z > d THEN d := z END;
					d := d*d + (x*x + y*y + z*z);
					IF d < min THEN min := d; minj := j END;
					INC(j)
				END;
				CT.colTrans[i] := minj; CT.IcolTrans[minj] := i;
				red := r[minj]; green := g[minj]; blue := b[minj];
				CT.rgb[i].r:=CHR(red); CT.rgb[i].g:=CHR(green); CT.rgb[i].b:=CHR(blue)
			END
		END
	END ComputeColors;

	PROCEDURE GetLogicalScrDesc(VAR R: Files.Rider; VAR LSD: LogicalScrDesc);
		VAR
			i: SIGNED32;
			ch: CHAR;
	BEGIN
		Files.ReadInt(R, LSD.width); Files.ReadInt(R, LSD.height);
		Files.Read(R, ch); i := ORD(ch);
		Files.Read(R, ch); (* Background Color Index into Global Color Table*)
		Files.Read(R, ch);
		LSD.GCTSize := SIGNED16(ASH(1, (i MOD 8)+1)); i := i DIV 8;
		i := i DIV 2;
		i := i DIV 8;
		LSD.GCTFlag := i > 0
	END GetLogicalScrDesc;

	PROCEDURE GetCMap(VAR R: Files.Rider; VAR map: ColorTable; size: SIGNED32);
		VAR i: SIGNED32;
	BEGIN
		FOR i := 0 TO size-1 DO
			Files.ReadBytes(R, map.rgb[i], 3)
		END
	END GetCMap;

	PROCEDURE GetExtBlock(VAR R: Files.Rider; VAR Ext: ExtBlock);
		VAR
			buffer: ARRAY 256 OF CHAR;
			time: SIGNED16;
			ch: CHAR;
	BEGIN
		Files.Read(R, ch);
		IF ch = 0FEX THEN (* Comment Extension: read only first block *)
			Files.Read(R, ch);
			Files.ReadBytes(R, buffer, ORD(ch)); buffer[ORD(ch)] := 0X
		ELSIF ch = 0F9X THEN (* Graphic Control Extension *)
			Files.Read(R, ch); Files.Read(R, ch);
			Ext.transparency := ODD(ORD(ch));
			Files.ReadInt(R, time); Files.Read(R, ch);
			Ext.transparencyIndex := ORD(ch)
		ELSE
		END;
		Files.Read(R, ch);
		WHILE ch # 0X DO
			Files.Set(R, Files.Base(R), Files.Pos(R)+ORD(ch)); Files.Read(R, ch)
		END
	END GetExtBlock;

	PROCEDURE GetImageDesc(VAR R: Files.Rider; VAR IDesc: ImageDesc);
		VAR
			i: SIGNED32;
			ch: CHAR;
	BEGIN
		Files.ReadInt(R, IDesc.left); Files.ReadInt(R, IDesc.top);
		Files.ReadInt(R, IDesc.width); Files.ReadInt(R, IDesc.height);
		Files.Read(R, ch); i := ORD(ch);
		IDesc.LCTSize := SIGNED16(ASH(1, (i MOD 8)+1)); i := i DIV 32;
		i := i DIV 2;
		IDesc.sequential := ~ODD(i); i := i DIV 2;
		IDesc.LCTFlag := i > 0
	END GetImageDesc;

	PROCEDURE InitCodeBook(codeLen: SIGNED32);
		VAR i, to: SIGNED32;
	BEGIN
		to := ASH(1, codeLen)-1;
		FOR i := 0 TO to DO
			CB[i].code := SHORT(i); CB[i].ref := dummy
		END;
		CB[i].code := dummy; CB[i].ref := dummy; INC(i);
		CB[i].code := dummy; CB[i].ref := dummy
	END InitCodeBook;

PROCEDURE GetData(VAR r: Files.Rider; VAR Image: Gif; P: Pictures.Picture);
	CONST byteLen=8;
	VAR bufferSize, bufpos, buf, bitsleft: SIGNED32;
		code, codept, maxCode, clearCode, endCode, oldcode, codeLen, startSize, stackpt: SIGNED32;
		page: CodePages;
		dots: POINTER TO ARRAY OF SIGNED16;
		buffer: ARRAY 256 OF CHAR;
		stack: ARRAY 1024 OF SIGNED16;
		x, y, w, n: SIGNED16;
		ch: CHAR;

	PROCEDURE Dot(col: SIGNED32);
	BEGIN
		dots[x]:=Image.IDesc.LCT.colTrans[col]; INC(x);
		IF x=w THEN x:=0;
			Pictures.PutLine(P, dots^, x, y, w);
			IF Image.IDesc.sequential THEN DEC(y)
			ELSE
				IF n>=8 THEN DEC(y, 2*4) ELSE DEC(y, 2*n) END;
				IF y<0 THEN n:=n DIV 2; y:=P.height-1-n END
			END
		END
	END Dot;

	PROCEDURE ReadCode(VAR code: SIGNED32);
		VAR bitsneed, b, val: SIGNED32;
	BEGIN
		IF bitsleft<codeLen THEN
			bitsneed:=codeLen-bitsleft; b:=0;
			WHILE bitsneed>0 DO
				IF bufpos>=bufferSize THEN bufpos:=0;
					Files.Read(r, ch);
					bufferSize:=ORD(ch);
					IF bufferSize=0 THEN code:=endCode; RETURN ELSE Files.ReadBytes(r, buffer, bufferSize) END
				 END;
				val:=ORD(buffer[bufpos]); INC(bufpos);
				IF bitsneed<byteLen THEN
					b:=ASH(val, -bitsneed);
					DEC(val, ASH(b, bitsneed));
					bitsneed:=0
				ELSE
					DEC(bitsneed, byteLen)
				END;
				INC(buf, ASH(val, bitsleft));
				INC(bitsleft, byteLen)
			END;
			code:=buf; DEC(bitsleft, codeLen); buf:=b
		ELSE
			code:=buf MOD maxCode; buf:=buf DIV maxCode;
			DEC(bitsleft, codeLen)
		END
	END ReadCode;

BEGIN
	Files.Read(r, ch); codeLen:=ORD(ch); bufpos := 0;
	clearCode:=ASH(1, codeLen); endCode:=clearCode+1;
	(* Init Codebook *)
	InitCodeBook(codeLen);
	INC(codeLen); startSize:=codeLen; codept:=endCode+1;
	maxCode:=ASH(1, codeLen);
	(* Init Read *)
	bufferSize:=0; buf:=0; bitsleft:=0; x:=0; y:=P.height-1; w:=P.width;
	NEW(dots, w); bufpos := 0;
	(* go *)
	REPEAT ReadCode(code) UNTIL code#clearCode;
	IF code=endCode THEN RETURN END;

	page.code:= SHORT(code); Dot(code);
	IF ~Image.IDesc.sequential THEN n := 1;
		WHILE (n < P.height)&(n<8) DO INC(n, n) END
	END;

	LOOP
		oldcode:=code; ReadCode(code);
		IF code=clearCode THEN
			codeLen:=startSize; codept:=endCode+1;
			maxCode:=ASH(1, startSize);
			ReadCode(code); Dot(code); page.code:=SHORT(code)
		ELSIF code= endCode THEN EXIT
		ELSE
			IF code<codept THEN
				page:=CB[code]; stackpt:=0
			ELSE
				stack[0]:=page.code; page:=CB[oldcode]; stackpt:=1
			END;
			WHILE page.ref#dummy DO
				IF stackpt >= 1024 THEN stackpt := 1023 END;
				stack[stackpt]:=page.code; page:=CB[page.ref]; INC(stackpt)
			END;
			Dot(page.code);
			WHILE stackpt>0 DO DEC(stackpt); Dot(stack[stackpt]) END;
			CB[codept].code:=page.code; CB[codept].ref:=SHORT(oldcode); INC(codept);
			IF codept>=maxCode THEN
				INC(codeLen);
				IF codeLen>12 THEN codeLen:=12 END;
				maxCode:=ASH(1, codeLen)
			END
		END
	END
END GetData;

PROCEDURE CheckFile*(f: Files.File): BOOLEAN;
	VAR r: Files.Rider; sig: ARRAY 7 OF CHAR;
BEGIN
	Files.Set(r, f, 0); Files.ReadBytes(r, sig, 6); sig[6]:=0X;
	RETURN (sig="GIF87a") OR (sig="GIF89a")
END CheckFile;

PROCEDURE Load*(VAR R: Files.Rider; transparentCol: SIGNED16; colorConversion: BOOLEAN; pict: Pictures.Picture);
	VAR i, idx, r, g, b: SIGNED16; ch: CHAR;
BEGIN
	IF ~CheckFile(Files.Base(R)) THEN RETURN END;
	Files.Set(R, Files.Base(R), Files.Pos(R)+6);
	idx:=0;
	GetLogicalScrDesc(R, GifImage.LSD);
	IF GifImage.LSD.GCTFlag THEN
		GetCMap(R, GifImage.GCT, GifImage.LSD.GCTSize);
		ComputeColors(GifImage.GCT, colorConversion)
	END;
	Files.Read(R, ch);
	WHILE ~R.eof & (ch#3BX) DO
		IF ch=21X THEN GetExtBlock(R, GifImage.Ext)
		ELSIF ch=2CX THEN
			IF idx>0 THEN (* there are more pictures *) END;
			GetImageDesc(R, GifImage.IDesc);
			IF GifImage.IDesc.LCTFlag THEN
				GetCMap(R, GifImage.IDesc.LCT, GifImage.IDesc.LCTSize);
				ComputeColors(GifImage.IDesc.LCT, colorConversion)
			ELSE
				GifImage.IDesc.LCT:=GifImage.GCT
			END;
			Pictures.Create(pict, GifImage.IDesc.width, GifImage.IDesc.height, 8); (* depth problem *)
			IF pict.depth=0 THEN RETURN ELSE pict.handle:=Handle END;
			IF GifImage.Ext.transparency THEN
				Display.GetColor(transparentCol, r, g, b);
				GifImage.IDesc.LCT.rgb[GifImage.Ext.transparencyIndex].r:=CHR(r);
				GifImage.IDesc.LCT.rgb[GifImage.Ext.transparencyIndex].g:=CHR(g);
				GifImage.IDesc.LCT.rgb[GifImage.Ext.transparencyIndex].b:=CHR(b)
			END;
			IF ~colorConversion THEN
				i:=0;
				WHILE i<256 DO  (* 256 because depth is 8 fixed *)
					Pictures.SetColor(pict, i,
						GifImage.IDesc.LCT.IcolTrans[ ORD(GifImage.IDesc.LCT.rgb[i].r) ],
						GifImage.IDesc.LCT.IcolTrans[ ORD(GifImage.IDesc.LCT.rgb[i].g) ],
						GifImage.IDesc.LCT.IcolTrans[ ORD(GifImage.IDesc.LCT.rgb[i].b) ] );
					INC(i)
				END
			END;
			GetData(R, GifImage, pict); Files.Read(R, ch); INC(idx); GifImage.Ext.transparency:=FALSE
		ELSE RETURN
		END;
		Files.Read(R, ch)
	END;
	IF idx>1 THEN (* there are more pictures *) END
END Load;

	PROCEDURE Handle*(obj: Objects.Object; VAR M: Objects.ObjMsg);
	BEGIN
		WITH obj: Pictures.Picture DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF (M.id = Objects.get) & (M.name = "Gen") THEN
						M.class := Objects.String; M.s := "Pictures.NewPicture"; M.res := 0
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN
						obj.depth := 0;
						Load(M.R, 14 (* Display3.textbackC *), FALSE (* fof *), obj);
						IF obj.depth = 0 THEN M.len := 0 ELSE M.len := Files.Length(Files.Base(M.R)) END
					ELSE
						Pictures.Handle(obj, M)
					END
				END
			ELSE
				Pictures.Handle(obj, M)
			END
		END
	END Handle;

	(** Called from Pictures.Open to try and load a GIF picture. The picture descriptor is pre-allocated by Pictures in
	Objects.NewObj. InitPicture overwrites the handler of the picture with a new handler that will load the GIF picture
	when a FileMsg is received (variant load). *)
	PROCEDURE InitPicture*;
	BEGIN
		Objects.NewObj.handle := Handle;
	END InitPicture;

	PROCEDURE NewPicture*;
		VAR P: Pictures.Picture;
	BEGIN
		NEW(P); P.handle := Handle;
		Objects.NewObj := P
	END NewPicture;

END GIF.
