MODULE GIFCodec; (** AUTHOR "eos, tf, dk, pl, staubesv"; PURPOSE "GIF image format"; *)

IMPORT
	KernelLog, Streams, Codecs, Raster, WMGraphics;

CONST
	Dummy = -1;

	(* Graphic Control Extension disposal *)
	Unspecified* = 0;
	DoNotDispose* = 1;
	RestoreToBackground* = 2;
	RestoreToPrevious* = 3;

	BlockTerminator = 0X;

TYPE
	CodePages = RECORD code, ref: LONGINT END;
	CodeBook = ARRAY 4096 OF CodePages;

	Header = RECORD
		signature, version : ARRAY 4 OF CHAR;
	END;

TYPE

	GIFEncoder* = OBJECT(Codecs.ImageEncoder)
	VAR
		w : Streams.Writer;
		cb: CodeBook;
		lastBlock: ARRAY 4096 OF LONGINT;

		(* open the encoder on a Streams writer *)
		PROCEDURE Open*(out : Streams.Writer);
		BEGIN
			w := out
		END Open;

		PROCEDURE SetQuality*(quality : LONGINT);
		END SetQuality;

		PROCEDURE WriteImage*(img : Raster.Image; VAR res : WORD);
		VAR pal : Raster.Palette;
		BEGIN
			NEW(pal); Raster.ComputePalette(img, pal, 0,256, 8);
			WriteGlobal(w, img, pal);
			WriteImageDesc(w, img);
			WriteData(w, img, pal);
			w.Char(3BX);
			w.Update;
			res := 0
		END WriteImage;

		PROCEDURE WriteScrDesc(w: Streams.Writer; img: Raster.Image);
		VAR i: LONGINT;
		BEGIN
			w.RawInt(SHORT(img.width)); w.RawInt(SHORT(img.height));
			i := ASH(7+ 8 (*img.fmt.bpp*), 4); i := i+ 8 (*img.fmt.bpp*) - 1;
			w.Char( CHR(i) );
			w.Char( 0X );
			w.Char( 0X )
		END WriteScrDesc;

		PROCEDURE WriteColMap(w: Streams.Writer; img: Raster.Image; pal : Raster.Palette);
		VAR i: LONGINT;
		BEGIN
			FOR i :=  0 TO 255 DO
				w.Char(pal.col[i][Raster.r]); w.Char(pal.col[i][Raster.g]); w.Char(pal.col[i][Raster.b])
			END;
		END WriteColMap;

		PROCEDURE WriteGlobal(w: Streams.Writer; img: Raster.Image; pal : Raster.Palette);
		BEGIN
			w.String("GIF89a");
			WriteScrDesc(w, img);
			WriteColMap(w, img, pal)
		END WriteGlobal;

		PROCEDURE WriteImageDesc(w: Streams.Writer; img: Raster.Image);
		BEGIN
			w.Char(2CX);
			w.RawInt( 0); w.RawInt(0);
			w.RawInt(SHORT(img.width)); w.RawInt(SHORT(img.height));
			w.Char(CHR(8 (*img.fmt.bpp*) - 1));
		END WriteImageDesc;

		PROCEDURE InitCodeBook(codeLen: LONGINT);
		VAR i, to: LONGINT;
		BEGIN
			i := 0; to := ASH(1, codeLen);
			WHILE i < to DO
				cb[i].code := i; cb[i].ref := Dummy; lastBlock[i] := Dummy; INC(i)
			END;
			cb[i].code := Dummy; cb[i].ref := Dummy; INC(i);
			cb[i].code := Dummy; cb[i].ref := Dummy;
		END InitCodeBook;

		PROCEDURE WriteData(w: Streams.Writer; img: Raster.Image; pal : Raster.Palette);
		CONST byteLen=8;
		VAR
			last, in, clearCode, endCode, codept, startSize, prefix, bufpos, bitsfree, codelen: LONGINT;
			buffer: ARRAY 256 OF CHAR;
			i2, len: LONGINT;
			page: CodePages;
			x, y, width : LONGINT;
			pix : Raster.Pixel;
			mode : Raster.Mode;

			PROCEDURE WriteCode(code: LONGINT);
			VAR temp, bitsleft: LONGINT;
			BEGIN
				bitsleft := codelen;
				WHILE bitsleft > 0 DO
					IF bitsleft <= bitsfree THEN
						temp := ASH(code, byteLen-bitsfree);
						buffer[bufpos] := CHR(ORD(buffer[bufpos]) + temp);
						bitsfree := bitsfree - bitsleft; bitsleft := 0;
						IF bitsfree = 0 THEN INC(bufpos); buffer[bufpos] := 0X; bitsfree := byteLen END
					ELSE
						temp := ASH(code, byteLen-bitsfree) MOD 256;
						buffer[bufpos] := CHR(ORD(buffer[bufpos]) + temp);
						INC(bufpos); buffer[bufpos] := 0X;
						code := INTEGER(ASH(code, -bitsfree));
						bitsleft := bitsleft - bitsfree; bitsfree := byteLen
					END;
					IF bufpos = 255 THEN
						w.Char( 0FFX); w.Bytes(buffer, 0, 255); bufpos:=0;
						buffer[bufpos] := 0X
					END
				END
			END WriteCode;

		BEGIN
			codelen := 8 (*img.fmt.bpp*); IF codelen < 2 THEN codelen := 2 END;
			w.Char(CHR(codelen));
			clearCode := INTEGER(ASH(1, codelen)); endCode := clearCode + 1;
			codept := endCode + 1; lastBlock[codept] := Dummy;

			startSize := codelen;
			InitCodeBook(codelen); INC(codelen);
			x := 0; y := 0; width := img.width;

			Raster.InitMode(mode, Raster.srcCopy);

			Raster.Get(img, x, y, pix, mode);
			prefix := Raster.PaletteIndex(pal, ORD(pix[Raster.r]), ORD(pix[Raster.g]), ORD(pix[Raster.b]));
			INC(x); bufpos := 0; buffer[0] := 0X; bitsfree := 8;
			len := INTEGER(ASH(1, codelen));

			WriteCode(clearCode);
			LOOP
				Raster.Get(img, x,y, pix, mode);
				in := Raster.PaletteIndex(pal, ORD(pix[Raster.r]),ORD(pix[Raster.g]), ORD(pix[Raster.b]));
				i2 := lastBlock[prefix];
				IF i2 # Dummy THEN
					page := cb[i2];
					WHILE (page.ref # Dummy) & (page.code # in) DO
						i2 := page.ref; page := cb[page.ref]
					END
				END;
				IF (i2 = Dummy) OR ((page.ref = Dummy) & (page.code # in)) THEN
					WriteCode(prefix);
					IF codept = len THEN
						INC(codelen); len := INTEGER(ASH(1, codelen))
					END;
					IF codept >= 4095 THEN
							WriteCode(clearCode);
							codelen := startSize; InitCodeBook(codelen); INC(codelen); len := INTEGER(ASH(1, codelen));
							codept := endCode+1
					ELSE
						cb[codept].ref := lastBlock[prefix]; cb[codept].code := in; lastBlock[prefix] := codept;
						lastBlock[codept] := Dummy;
						INC(codept)
					END;
					last := prefix; prefix := in
				ELSE last := prefix; prefix := i2
				END;
				INC(x);
				IF x = width THEN
					IF y = img.height - 1  THEN EXIT END;
					x := 0; INC(y)
				END
			END;
			WriteCode(last);
			WriteCode(clearCode); codelen := startSize+1;
			WriteCode(cb[prefix].code); WriteCode(endCode);

			IF bufpos > 0 THEN
				IF bitsfree = 8 THEN
					w.Char(CHR(bufpos)); w.Bytes(buffer, 0,bufpos);
				ELSE
					w.Char(CHR(bufpos+1)); w.Bytes(buffer, 0, bufpos+1);
				END
			END;
			w.Char( 0X)
		END WriteData;

	END GIFEncoder;

TYPE

	GIFDecoder* = OBJECT(Codecs.ImageDecoder)
	VAR
		r : Streams.Reader;
		errors : BOOLEAN;
		width, height : LONGINT;
		pal, localPal, globalPal : Raster.Palette;
		backGrndCol: Raster.Pixel; transparent, interlaced: BOOLEAN;
		lcdFlags, backGrndIdx : CHAR;
		img : Raster.Image;

		PROCEDURE Error(CONST x : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("GIF Decoder : ");
			KernelLog.String(x); KernelLog.Ln;
			errors := TRUE
		END Error;

		(* open the decoder on an InputStream *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		VAR
			header : Header;
			ch : CHAR;
			n, size, length : LONGINT;
			w, h : INTEGER;
		BEGIN
			IF in = NIL THEN Error("Input Stream is NIL"); RETURN END;
			SELF.r := in;
			res := -1; errors := FALSE;

			r.Bytes(header.signature, 0, 3, length); header.signature[3] := 0X;
			IF (length # 3) OR (header.signature # "GIF") THEN
				Error("This is not a GIF data stream");
				RETURN;
			END;

			r.Bytes(header.version, 0, 3, length); header.version[3] := 0X;
			IF (length # 3) OR ((header.version # "87a") & (header.version # "89a")) THEN
				Error("Version not supported");
				RETURN;
			END;

			(* logical screen descriptor *)
			r.RawInt(w); r.RawInt(h);	(* dimensions of logical screen *)
			width := w; height := h;
			r.Char(lcdFlags); r.Char(backGrndIdx); r.Char(ch);	(* ignore aspect ratio *)
			NEW(globalPal); NEW(localPal);
			FOR n := 0 TO 255 DO
				Raster.SetRGB(globalPal.col[n], red[n], green[n], blue[n]);
				Raster.SetRGB(localPal.col[n], red[n], green[n], blue[n]);
			END;
			(* global color table *)
			IF ODD(ASH(ORD(lcdFlags), -7)) THEN
				n := 0; size := ASH(1, 1 + ORD(lcdFlags) MOD 8);
				WHILE n < size DO
					r.Char(globalPal.col[n, Raster.r]); r.Char(globalPal.col[n, Raster.g]);
					r.Char(globalPal.col[n, Raster.b]); globalPal.col[n, Raster.a] := 0FFX;
					INC(n)
				END;
				backGrndCol := globalPal.col[ORD(backGrndIdx)]
			ELSE
				Raster.SetRGB(backGrndCol, 0C0H, 0C0H, 0C0H)	(* color 14 in Oberon standard palette, used for text background *)
			END;
			pal := globalPal;
			res := 0;
		END Open;

		PROCEDURE GetImageInfo*(VAR width, height, format, maxProgressionLevel : LONGINT);
		BEGIN
			width := SELF.width; height := SELF.height
		END GetImageInfo;

		(** Render will read and decode the image data up to progrssionLevel.
			If the progressionLevel is lower than a previously rendered progressionLevel,
			the new level can be ignored by the decoder. If no progressionLevel is set with
			SetProgressionLevel, the level is assumed to be maxProgressionLevel of the image,
			which corresponds to best image quality.
		 *)
		PROCEDURE SetProgressionLevel*(progressionLevel: LONGINT);
		END SetProgressionLevel;

		(* return the image in Raster format that best matches the format *)
		PROCEDURE GetNativeImage*(VAR img : Raster.Image);
		VAR
			images, w, h, left, top : INTEGER;
			label, ch, transPix, idFlags : CHAR;
			n, size : LONGINT;
			error : BOOLEAN;
		BEGIN
			NEW(img);
			images := 0; transparent := FALSE;
			LOOP
				r.Char(ch);
				IF r.res # Streams.Ok THEN Error("unexpected end of file"); RETURN
				ELSIF ch = 3BX THEN	(* trailer *)
					EXIT
				ELSIF ch = 21X THEN	(* extension introducer *)
					r.Char(label); r.Char(ch);	(* extension label and block size *)
					IF label = 0F9X THEN (* graphic control block *)
						IF ch # 4X THEN Error("graphic control extension block size # 4"); RETURN END;
						r.Char(ch); transparent := ODD(ORD(ch));
						r.SkipBytes(2); r.Char(transPix);
						r.Char(ch)	(* read next block size (should be zero) *)
					END;
					WHILE ch # 0X DO	(* skip data blocks *)
						r.SkipBytes(ORD(ch)); r.Char(ch)
					END
				ELSIF ch = 2CX THEN	(* image descriptor *)
					INC(images);
					IF images > 1 THEN
						Error("ignoring all but first image"); EXIT
					END;
					r.RawInt(left); r.RawInt(top);
					r.RawInt(w); r.RawInt(h);
					r.Char(idFlags);
					interlaced := ODD(ASH(ORD(idFlags), -6));

					(* local color table *)
					IF ODD(ASH(ORD(idFlags), -7)) THEN
						n := 0; size := ASH(1, 1 + ORD(idFlags) MOD 8);
						WHILE n < size DO
							r.Char(pal.col[n, Raster.r]); r.Char(pal.col[n, Raster.g]); r.Char(pal.col[n, Raster.b]);
							INC(n)
						END;
					END;

					(* create image and load image data *)
					Raster.Create(img, w, h, Raster.BGRA8888);
					IF transparent THEN
						pal.col[ORD(transPix), Raster.b] := 0X;
						pal.col[ORD(transPix), Raster.g] := 0X;
						pal.col[ORD(transPix), Raster.r] := 0X;
						pal.col[ORD(transPix), Raster.a] := 0X
					END;
					LoadData(r, pal, img, interlaced, error);
					IF error THEN Error("Not enough image data"); RETURN; END;
				ELSE
					Error("confused by unknown block type"); RETURN
				END
			END;
		END GetNativeImage;

		(* renders the image into the given Raster.Image at the given progressionLevel *)
		PROCEDURE Render*(img : Raster.Image);
		VAR canvas : WMGraphics.BufferCanvas;
		BEGIN
			GetNativeImage(SELF.img);
			NEW(canvas, img);
			canvas.DrawImage(0, 0, SELF.img, WMGraphics.ModeCopy)
		END Render;

	END GIFDecoder;

TYPE

	GIFAnimationDecoder* = OBJECT(Codecs.AnimationDecoder)
	VAR
		r : Streams.Reader;
		errors : BOOLEAN;
		width, height : LONGINT;
		pal, localPal, globalPal : Raster.Palette;
		backGrndCol: Raster.Pixel; transparent, interlaced: BOOLEAN;
		lcdFlags, backGrndIdx : CHAR;

		PROCEDURE Error(CONST x : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("GIF Animation Decoder : ");
			KernelLog.String(x); KernelLog.Ln;
			errors := TRUE
		END Error;

		(* open the decoder on an InputStream *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		VAR
			header : Header;
			ch : CHAR;
			n, size, length : LONGINT;
			w, h : INTEGER;
		BEGIN
			IF in = NIL THEN Error("Input Stream is NIL"); RETURN END;
			SELF.r := in;
			res := -1; errors := FALSE;

			r.Bytes(header.signature, 0, 3, length); header.signature[3] := 0X;
			IF (length # 3) OR (header.signature # "GIF") THEN
				Error("This is not a GIF data stream");
				RETURN;
			END;

			r.Bytes(header.version, 0, 3, length); header.version[3] := 0X;
			IF (length # 3) OR ((header.version # "87a") & (header.version # "89a")) THEN
				Error("Version not supported");
				RETURN;
			END;

			(* logical screen descriptor *)
			r.RawInt(w); r.RawInt(h);	(* dimensions of logical screen *)
			width := w; height := h;
			r.Char(lcdFlags); r.Char(backGrndIdx); r.Char(ch);	(* ignore aspect ratio *)
			NEW(globalPal); NEW(localPal);
			FOR n := 0 TO 255 DO
				Raster.SetRGB(globalPal.col[n], red[n], green[n], blue[n]);
				Raster.SetRGB(localPal.col[n], red[n], green[n], blue[n]);
			END;
			(* global color table *)
			IF ODD(ASH(ORD(lcdFlags), -7)) THEN
				n := 0; size := ASH(1, 1 + ORD(lcdFlags) MOD 8);
				WHILE n < size DO
					r.Char(globalPal.col[n, Raster.r]); r.Char(globalPal.col[n, Raster.g]);
					r.Char(globalPal.col[n, Raster.b]); globalPal.col[n, Raster.a] := 0FFX;
					INC(n)
				END;
				backGrndCol := globalPal.col[ORD(backGrndIdx)]
			ELSE
				Raster.SetRGB(backGrndCol, 0C0H, 0C0H, 0C0H)	(* color 14 in Oberon standard palette, used for text background *)
			END;
			pal := globalPal;
			res := 0;
		END Open;

		PROCEDURE GetImageSequence*(VAR sequence : Codecs.ImageSequence; VAR res : WORD);
		VAR
			first, last, current : Codecs.ImageDescriptor;
			label, ch, transPix, idFlags : CHAR;
			n, size : LONGINT;
			temp, delayTime, disposeMode : INTEGER;
			valid, userInput, error : BOOLEAN;
		BEGIN
			res := Codecs.ResFailed;
			sequence.width := SELF.width; sequence.height := SELF.height;
			sequence.bgColor := GetColor(backGrndCol);
			first := NIL; last := NIL;
			transparent := FALSE; valid := FALSE;
			LOOP
				r.Char(ch);
				IF r.res # Streams.Ok THEN Error("unexpected end of file"); RETURN;
				ELSIF ch = 3BX THEN	(* trailer *)
					EXIT
				ELSIF ch = 21X THEN	(* extension introducer *)
					r.Char(label); r.Char(ch);	(* extension label and block size *)
					IF label = 0F9X THEN (* graphic control block *)
						IF ch # 4X THEN Error("graphic control extension block size # 4"); RETURN END;
						r.Char(ch); transparent := ODD(ORD(ch));
						valid := TRUE;
						userInput := ODD(ORD(ch) DIV 2);
						disposeMode := (ORD(ch) DIV 4) MOD 8;
						r.RawInt(delayTime);
						r.Char(transPix);
						r.Char(ch);
						IF (ch # BlockTerminator) THEN Error("Expected block terminator 1"); RETURN; END;
					ELSE
						WHILE ch # BlockTerminator DO	(* skip extension and data blocks that follow  *)
							r.SkipBytes(ORD(ch)); r.Char(ch)
						END
					END;
				ELSIF ch = 2CX THEN	(* image descriptor *)
					NEW(current);
					valid := FALSE;
					current.delayTime := 10 * delayTime;
					IF userInput THEN INCL(current.flags, Codecs.WaitForUserInput); END;
					current.disposeMode := disposeMode;
					NEW(current.image);
					IF (first = NIL) THEN
						first := current; last := current;
					ELSE
						current.previous := last;
						last.next := current;
						last := current;
					END;
					r.RawInt(temp); current.left := temp;
					r.RawInt(temp); current.top := temp;
					r.RawInt(temp); current.width := temp;
					r.RawInt(temp); current.height := temp;
					r.Char(idFlags);
					interlaced := ODD(ASH(ORD(idFlags), -6));

					(* local color table *)
					IF ODD(ASH(ORD(idFlags), -7)) THEN
						n := 0; size := ASH(1, 1 + ORD(idFlags) MOD 8);
						WHILE n < size DO
							r.Char(localPal.col[n, Raster.r]); r.Char(localPal.col[n, Raster.g]); r.Char(localPal.col[n, Raster.b]);
							INC(n)
						END;
						pal := localPal;
					ELSE
						pal := globalPal;
					END;

					(* create image and load image data *)
					Raster.Create(current.image, current.width, current.height, Raster.BGRA8888);
					IF transparent THEN
						pal.col[ORD(transPix), Raster.b] := 0X;
						pal.col[ORD(transPix), Raster.g] := 0X;
						pal.col[ORD(transPix), Raster.r] := 0X;
						pal.col[ORD(transPix), Raster.a] := 0X
					END;
					LoadData(r, pal, current.image, interlaced, error);
					IF error THEN Error("no enough image data"); RETURN; END;
				ELSE
					Error("confused by unknown block type"); KernelLog.String("Type="); KernelLog.Int(ORD(ch), 0); KernelLog.Ln; RETURN
				END
			END;
			sequence.images := first;
			res := Codecs.ResOk;
			ASSERT(sequence.images # NIL);
		END GetImageSequence;

	END GIFAnimationDecoder;

VAR
	red, green, blue : ARRAY 256 OF INTEGER;

PROCEDURE LoadData (r : Streams.Reader; pal : Raster.Palette; img: Raster.Image; interlaced: BOOLEAN; VAR error : BOOLEAN);
VAR
	ch: CHAR;
	codeBits, clearCode, endCode, curBits, maxCode, nextCode, bits, x, y, lines, prevCode, curCode, seq, len: INTEGER;
	n, buf, blkPos, blkSize, ptr, bytesRead: LONGINT;
	pix, run: ARRAY 1000H OF CHAR;
	prev: ARRAY 1000H OF INTEGER;
	block: ARRAY 255 OF CHAR;

	PROCEDURE Dot (pix: CHAR);
	BEGIN
		IF y >=  img.height THEN RETURN END;
		img.mem[ptr + x * 4] := pal.col[ORD(pix), Raster.b];
		img.mem[ptr + x * 4 + 1] := pal.col[ORD(pix), Raster.g];
		img.mem[ptr + x * 4 + 2] := pal.col[ORD(pix), Raster.r];
		img.mem[ptr + x * 4 + 3] := pal.col[ORD(pix), Raster.a];
		(*INC(ptr);*) INC(x);
		IF x = img.width THEN
			IF interlaced THEN
				IF lines >= 8 THEN INC(y, 8) ELSE INC(y, lines) END;
				WHILE y > SHORT(img.height-1) DO
					lines := lines DIV 2; y := lines DIV 2
				END
			ELSE
				INC(y)
			END;
			x := 0; ptr := y * img.bpr
		END
	END Dot;

BEGIN
	error := FALSE;
	r.Char(ch); codeBits := ORD(ch);
	clearCode := INTEGER(ASH(1, codeBits)); endCode := clearCode+1;
	n := 0;
	WHILE n < clearCode DO
		pix[n] := CHR(n); prev[n] := -1; INC(n)
	END;
	WHILE n <= endCode DO
		pix[n] := 0X; prev[n] := -1; INC(n)
	END;
	curBits := codeBits + 1; maxCode := INTEGER(ASH(1, curBits)); nextCode := endCode+1;
	buf := 0; bits := 0; blkPos := 0; blkSize := 0;	(* bit buffer and current block are empty *)
	x := 0; y := 0; ptr := 0;
	IF interlaced THEN lines := 16 END;

	prevCode := clearCode;
	LOOP
		(* read next code *)
		WHILE bits < curBits DO	(* not enough bits available *)
			IF blkPos = blkSize THEN	(* at end of block *)
				r.Char(ch);
				IF ch = 0X THEN	(* terminator block mark *)
					error := TRUE; RETURN
				END;
				blkPos := 0; blkSize := ORD(ch);
				r.Bytes(block, 0, blkSize, bytesRead)	(* ignore bytesRead *)
			END;
			buf := buf + ASH(ORD(block[blkPos]), bits); INC(blkPos); INC(bits, 8)
		END;
		curCode := SHORT(buf MOD maxCode);
		buf := ASH(buf, -curBits); DEC(bits, curBits);

		IF curCode = clearCode THEN
			curBits := codeBits+1; maxCode := INTEGER(ASH(1, curBits)); nextCode := endCode+1
		ELSIF curCode = endCode THEN
			EXIT
		ELSIF prevCode = clearCode THEN
			Dot(CHR(curCode)); seq := curCode
		ELSE
			IF curCode < nextCode THEN	(* reuse sequence *)
				seq := curCode; len := 0
			ELSE	(* append previous first char to previous sequence *)
				run[0] := pix[seq]; len := 1; seq := prevCode
			END;
			WHILE prev[seq] >= 0 DO
				run[len] := pix[seq]; INC(len); seq := prev[seq]
			END;
			Dot(pix[seq]);
			WHILE len > 0 DO
				DEC(len); Dot(run[len])
			END;

			(* the sequence just output gets a new code *)
			pix[nextCode] := pix[seq]; prev[nextCode] := prevCode; INC(nextCode);
			IF (nextCode = maxCode) & (curBits < 12) THEN
				INC(curBits); maxCode := INTEGER(ASH(1, curBits))
			END
		END;
		prevCode := curCode
	END;

	(* search terminator block *)
	r.Char(ch);
	WHILE ch # 0X DO
		r.SkipBytes(ORD(ch));
		r.Char(ch)
	END
END LoadData;

PROCEDURE GetColor(CONST pixel : Raster.Pixel) : LONGINT;
BEGIN
	RETURN ORD(pixel[Raster.a]) + 100H * ORD(pixel[Raster.b]) + 10000H * ORD(pixel[Raster.g]) + 1000000H * ORD(pixel[Raster.r]);
END GetColor;

PROCEDURE InitDefaultPalette;
BEGIN
	red[0] := 255; green[0] := 255; blue[0] := 255;
	red[1] := 255; green[1] := 0; blue[1] := 0;
	red[2] := 0; green[2] := 255; blue[2] := 0;
	red[3] := 0; green[3] := 0; blue[3] := 255;
	red[4] := 255; green[4] := 0; blue[4] := 255;
	red[5] := 255; green[5] := 255; blue[5] := 0;
	red[6] := 0; green[6] := 255; blue[6] := 255;
	red[7] := 154; green[7] := 0; blue[7] := 0;
	red[8] := 0; green[8] := 146; blue[8] := 0;
	red[9] := 0; green[9] := 0; blue[9] := 130;
	red[10] := 154; green[10] := 219; blue[10] := 255;
	red[11] := 0; green[11] := 146; blue[11] := 130;
	red[12] := 134; green[12] := 134; blue[12] := 134;
	red[13] := 195; green[13] := 195; blue[13] := 195;
	red[14] := 227; green[14] := 227; blue[14] := 227;
	red[15] := 0; green[15] := 0; blue[15] := 0;
	red[16] := 0; green[16] := 182; blue[16] := 0;
	red[17] := 0; green[17] := 146; blue[17] := 65;
	red[18] := 0; green[18] := 182; blue[18] := 130;
	red[19] := 0; green[19] := 146; blue[19] := 190;
	red[20] := 0; green[20] := 0; blue[20] := 65;
	red[21] := 0; green[21] := 0; blue[21] := 190;
	red[22] := 0; green[22] := 36; blue[22] := 0;
	red[23] := 0; green[23] := 36; blue[23] := 65;
	red[24] := 0; green[24] := 36; blue[24] := 130;
	red[25] := 0; green[25] := 36; blue[25] := 190;
	red[26] := 0; green[26] := 36; blue[26] := 255;
	red[27] := 0; green[27] := 73; blue[27] := 0;
	red[28] := 0; green[28] := 73; blue[28] := 65;
	red[29] := 0; green[29] := 73; blue[29] := 130;
	red[30] := 0; green[30] := 73; blue[30] := 190;
	red[31] := 0; green[31] := 73; blue[31] := 255;
	red[32] := 0; green[32] := 109; blue[32] := 0;
	red[33] := 0; green[33] := 109; blue[33] := 65;
	red[34] := 0; green[34] := 109; blue[34] := 130;
	red[35] := 0; green[35] := 109; blue[35] := 190;
	red[36] := 0; green[36] := 109; blue[36] := 255;
	red[37] := 0; green[37] := 146; blue[37] := 255;
	red[38] := 0; green[38] := 182; blue[38] := 65;
	red[39] := 0; green[39] := 182; blue[39] := 190;
	red[40] := 0; green[40] := 182; blue[40] := 255;
	red[41] := 0; green[41] := 219; blue[41] := 0;
	red[42] := 0; green[42] := 219; blue[42] := 65;
	red[43] := 0; green[43] := 219; blue[43] := 130;
	red[44] := 0; green[44] := 219; blue[44] := 190;
	red[45] := 0; green[45] := 219; blue[45] := 255;
	red[46] := 0; green[46] := 255; blue[46] := 65;
	red[47] := 0; green[47] := 255; blue[47] := 130;
	red[48] := 0; green[48] := 255; blue[48] := 190;
	red[49] := 48; green[49] := 0; blue[49] := 0;
	red[50] := 48; green[50] := 0; blue[50] := 65;
	red[51] := 48; green[51] := 0; blue[51] := 130;
	red[52] := 48; green[52] := 0; blue[52] := 190;
	red[53] := 48; green[53] := 0; blue[53] := 255;
	red[54] := 48; green[54] := 36; blue[54] := 0;
	red[55] := 48; green[55] := 36; blue[55] := 65;
	red[56] := 48; green[56] := 36; blue[56] := 130;
	red[57] := 48; green[57] := 36; blue[57] := 190;
	red[58] := 48; green[58] := 36; blue[58] := 255;
	red[59] := 48; green[59] := 73; blue[59] := 0;
	red[60] := 48; green[60] := 73; blue[60] := 65;
	red[61] := 48; green[61] := 73; blue[61] := 130;
	red[62] := 48; green[62] := 73; blue[62] := 190;
	red[63] := 48; green[63] := 73; blue[63] := 255;
	red[64] := 48; green[64] := 109; blue[64] := 0;
	red[65] := 48; green[65] := 109; blue[65] := 65;
	red[66] := 48; green[66] := 109; blue[66] := 130;
	red[67] := 48; green[67] := 109; blue[67] := 190;
	red[68] := 48; green[68] := 109; blue[68] := 255;
	red[69] := 48; green[69] := 146; blue[69] := 0;
	red[70] := 48; green[70] := 146; blue[70] := 65;
	red[71] := 48; green[71] := 146; blue[71] := 130;
	red[72] := 48; green[72] := 146; blue[72] := 190;
	red[73] := 48; green[73] := 146; blue[73] := 255;
	red[74] := 48; green[74] := 182; blue[74] := 0;
	red[75] := 48; green[75] := 182; blue[75] := 65;
	red[76] := 48; green[76] := 182; blue[76] := 130;
	red[77] := 48; green[77] := 182; blue[77] := 190;
	red[78] := 48; green[78] := 182; blue[78] := 255;
	red[79] := 48; green[79] := 219; blue[79] := 0;
	red[80] := 48; green[80] := 219; blue[80] := 65;
	red[81] := 48; green[81] := 219; blue[81] := 130;
	red[82] := 48; green[82] := 219; blue[82] := 190;
	red[83] := 48; green[83] := 219; blue[83] := 255;
	red[84] := 48; green[84] := 255; blue[84] := 0;
	red[85] := 48; green[85] := 255; blue[85] := 65;
	red[86] := 48; green[86] := 255; blue[86] := 130;
	red[87] := 48; green[87] := 255; blue[87] := 190;
	red[88] := 48; green[88] := 255; blue[88] := 255;
	red[89] := 101; green[89] := 0; blue[89] := 0;
	red[90] := 101; green[90] := 0; blue[90] := 65;
	red[91] := 101; green[91] := 0; blue[91] := 130;
	red[92] := 101; green[92] := 0; blue[92] := 190;
	red[93] := 101; green[93] := 0; blue[93] := 255;
	red[94] := 101; green[94] := 36; blue[94] := 0;
	red[95] := 101; green[95] := 36; blue[95] := 65;
	red[96] := 101; green[96] := 36; blue[96] := 130;
	red[97] := 101; green[97] := 36; blue[97] := 190;
	red[98] := 101; green[98] := 36; blue[98] := 255;
	red[99] := 101; green[99] := 73; blue[99] := 0;
	red[100] := 101; green[100] := 73; blue[100] := 65;
	red[101] := 101; green[101] := 73; blue[101] := 130;
	red[102] := 101; green[102] := 73; blue[102] := 190;
	red[103] := 101; green[103] := 73; blue[103] := 255;
	red[104] := 101; green[104] := 109; blue[104] := 0;
	red[105] := 101; green[105] := 109; blue[105] := 65;
	red[106] := 101; green[106] := 109; blue[106] := 130;
	red[107] := 101; green[107] := 109; blue[107] := 190;
	red[108] := 101; green[108] := 109; blue[108] := 255;
	red[109] := 101; green[109] := 146; blue[109] := 0;
	red[110] := 101; green[110] := 146; blue[110] := 65;
	red[111] := 101; green[111] := 146; blue[111] := 130;
	red[112] := 101; green[112] := 146; blue[112] := 190;
	red[113] := 101; green[113] := 146; blue[113] := 255;
	red[114] := 101; green[114] := 182; blue[114] := 0;
	red[115] := 101; green[115] := 182; blue[115] := 65;
	red[116] := 101; green[116] := 182; blue[116] := 130;
	red[117] := 101; green[117] := 182; blue[117] := 190;
	red[118] := 101; green[118] := 182; blue[118] := 255;
	red[119] := 101; green[119] := 219; blue[119] := 0;
	red[120] := 101; green[120] := 219; blue[120] := 65;
	red[121] := 101; green[121] := 219; blue[121] := 130;
	red[122] := 101; green[122] := 219; blue[122] := 190;
	red[123] := 101; green[123] := 219; blue[123] := 255;
	red[124] := 101; green[124] := 255; blue[124] := 0;
	red[125] := 101; green[125] := 255; blue[125] := 65;
	red[126] := 101; green[126] := 255; blue[126] := 130;
	red[127] := 101; green[127] := 255; blue[127] := 190;
	red[128] := 101; green[128] := 255; blue[128] := 255;
	red[129] := 154; green[129] := 0; blue[129] := 65;
	red[130] := 154; green[130] := 0; blue[130] := 130;
	red[131] := 154; green[131] := 0; blue[131] := 190;
	red[132] := 154; green[132] := 0; blue[132] := 255;
	red[133] := 154; green[133] := 36; blue[133] := 0;
	red[134] := 154; green[134] := 36; blue[134] := 65;
	red[135] := 154; green[135] := 36; blue[135] := 130;
	red[136] := 154; green[136] := 36; blue[136] := 190;
	red[137] := 154; green[137] := 36; blue[137] := 255;
	red[138] := 154; green[138] := 73; blue[138] := 0;
	red[139] := 154; green[139] := 73; blue[139] := 65;
	red[140] := 154; green[140] := 73; blue[140] := 130;
	red[141] := 154; green[141] := 73; blue[141] := 190;
	red[142] := 154; green[142] := 73; blue[142] := 255;
	red[143] := 154; green[143] := 109; blue[143] := 0;
	red[144] := 154; green[144] := 109; blue[144] := 65;
	red[145] := 154; green[145] := 109; blue[145] := 130;
	red[146] := 154; green[146] := 109; blue[146] := 190;
	red[147] := 154; green[147] := 109; blue[147] := 255;
	red[148] := 154; green[148] := 146; blue[148] := 0;
	red[149] := 154; green[149] := 146; blue[149] := 65;
	red[150] := 154; green[150] := 146; blue[150] := 130;
	red[151] := 154; green[151] := 146; blue[151] := 190;
	red[152] := 154; green[152] := 146; blue[152] := 255;
	red[153] := 154; green[153] := 182; blue[153] := 0;
	red[154] := 154; green[154] := 182; blue[154] := 65;
	red[155] := 154; green[155] := 182; blue[155] := 130;
	red[156] := 154; green[156] := 182; blue[156] := 190;
	red[157] := 154; green[157] := 182; blue[157] := 255;
	red[158] := 154; green[158] := 219; blue[158] := 0;
	red[159] := 154; green[159] := 219; blue[159] := 65;
	red[160] := 154; green[160] := 219; blue[160] := 130;
	red[161] := 154; green[161] := 219; blue[161] := 190;
	red[162] := 154; green[162] := 255; blue[162] := 0;
	red[163] := 154; green[163] := 255; blue[163] := 65;
	red[164] := 154; green[164] := 255; blue[164] := 130;
	red[165] := 154; green[165] := 255; blue[165] := 190;
	red[166] := 154; green[166] := 255; blue[166] := 255;
	red[167] := 207; green[167] := 0; blue[167] := 0;
	red[168] := 207; green[168] := 0; blue[168] := 65;
	red[169] := 207; green[169] := 0; blue[169] := 130;
	red[170] := 207; green[170] := 0; blue[170] := 190;
	red[171] := 207; green[171] := 0; blue[171] := 255;
	red[172] := 207; green[172] := 36; blue[172] := 0;
	red[173] := 207; green[173] := 36; blue[173] := 65;
	red[174] := 207; green[174] := 36; blue[174] := 130;
	red[175] := 207; green[175] := 36; blue[175] := 190;
	red[176] := 207; green[176] := 36; blue[176] := 255;
	red[177] := 207; green[177] := 73; blue[177] := 0;
	red[178] := 207; green[178] := 73; blue[178] := 65;
	red[179] := 207; green[179] := 73; blue[179] := 130;
	red[180] := 207; green[180] := 73; blue[180] := 190;
	red[181] := 207; green[181] := 73; blue[181] := 255;
	red[182] := 207; green[182] := 109; blue[182] := 0;
	red[183] := 207; green[183] := 109; blue[183] := 65;
	red[184] := 207; green[184] := 109; blue[184] := 130;
	red[185] := 207; green[185] := 109; blue[185] := 190;
	red[186] := 207; green[186] := 109; blue[186] := 255;
	red[187] := 207; green[187] := 146; blue[187] := 0;
	red[188] := 207; green[188] := 146; blue[188] := 65;
	red[189] := 207; green[189] := 146; blue[189] := 130;
	red[190] := 207; green[190] := 146; blue[190] := 190;
	red[191] := 207; green[191] := 146; blue[191] := 255;
	red[192] := 207; green[192] := 182; blue[192] := 0;
	red[193] := 207; green[193] := 182; blue[193] := 65;
	red[194] := 207; green[194] := 182; blue[194] := 130;
	red[195] := 207; green[195] := 182; blue[195] := 190;
	red[196] := 207; green[196] := 182; blue[196] := 255;
	red[197] := 207; green[197] := 219; blue[197] := 0;
	red[198] := 207; green[198] := 219; blue[198] := 65;
	red[199] := 207; green[199] := 219; blue[199] := 130;
	red[200] := 207; green[200] := 219; blue[200] := 190;
	red[201] := 207; green[201] := 219; blue[201] := 255;
	red[202] := 207; green[202] := 255; blue[202] := 0;
	red[203] := 207; green[203] := 255; blue[203] := 65;
	red[204] := 207; green[204] := 255; blue[204] := 130;
	red[205] := 207; green[205] := 255; blue[205] := 190;
	red[206] := 207; green[206] := 255; blue[206] := 255;
	red[207] := 255; green[207] := 0; blue[207] := 65;
	red[208] := 255; green[208] := 0; blue[208] := 130;
	red[209] := 255; green[209] := 0; blue[209] := 190;
	red[210] := 255; green[210] := 36; blue[210] := 0;
	red[211] := 255; green[211] := 36; blue[211] := 65;
	red[212] := 255; green[212] := 36; blue[212] := 130;
	red[213] := 255; green[213] := 36; blue[213] := 190;
	red[214] := 255; green[214] := 36; blue[214] := 255;
	red[215] := 255; green[215] := 73; blue[215] := 0;
	red[216] := 255; green[216] := 73; blue[216] := 65;
	red[217] := 255; green[217] := 73; blue[217] := 130;
	red[218] := 255; green[218] := 73; blue[218] := 190;
	red[219] := 255; green[219] := 73; blue[219] := 255;
	red[220] := 255; green[220] := 109; blue[220] := 0;
	red[221] := 255; green[221] := 109; blue[221] := 65;
	red[222] := 255; green[222] := 109; blue[222] := 130;
	red[223] := 255; green[223] := 109; blue[223] := 190;
	red[224] := 255; green[224] := 109; blue[224] := 255;
	red[225] := 255; green[225] := 146; blue[225] := 0;
	red[226] := 255; green[226] := 146; blue[226] := 65;
	red[227] := 255; green[227] := 146; blue[227] := 130;
	red[228] := 255; green[228] := 146; blue[228] := 190;
	red[229] := 255; green[229] := 146; blue[229] := 255;
	red[230] := 255; green[230] := 182; blue[230] := 0;
	red[231] := 255; green[231] := 182; blue[231] := 65;
	red[232] := 255; green[232] := 182; blue[232] := 130;
	red[233] := 255; green[233] := 182; blue[233] := 190;
	red[234] := 255; green[234] := 182; blue[234] := 255;
	red[235] := 255; green[235] := 219; blue[235] := 0;
	red[236] := 255; green[236] := 219; blue[236] := 65;
	red[237] := 255; green[237] := 219; blue[237] := 130;
	red[238] := 255; green[238] := 219; blue[238] := 190;
	red[239] := 255; green[239] := 219; blue[239] := 255;
	red[240] := 255; green[240] := 255; blue[240] := 65;
	red[241] := 255; green[241] := 255; blue[241] := 130;
	red[242] := 255; green[242] := 255; blue[242] := 190;
	red[243] := 243; green[243] := 243; blue[243] := 243;
	red[244] := 211; green[244] := 211; blue[244] := 211;
	red[245] := 182; green[245] := 182; blue[245] := 182;
	red[246] := 166; green[246] := 166; blue[246] := 166;
	red[247] := 150; green[247] := 150; blue[247] := 150;
	red[248] := 121; green[248] := 121; blue[248] := 121;
	red[249] := 105; green[249] := 105; blue[249] := 105;
	red[250] := 89; green[250] := 89; blue[250] := 89;
	red[251] := 73; green[251] := 73; blue[251] := 73;
	red[252] := 60; green[252] := 60; blue[252] := 60;
	red[253] := 44; green[253] := 44; blue[253] := 44;
	red[254] := 28; green[254] := 28; blue[254] := 28;
	red[255] := 12; green[255] := 12; blue[255] := 12;
END InitDefaultPalette;

PROCEDURE ImageEncoderFactory*() : Codecs.ImageEncoder;
VAR p : GIFEncoder;
BEGIN
	NEW(p); RETURN p
END ImageEncoderFactory;

PROCEDURE ImageDecoderFactory*() : Codecs.ImageDecoder;
VAR p : GIFDecoder;
BEGIN
	NEW(p); RETURN p
END ImageDecoderFactory;

PROCEDURE AnimationDecoderFactory*() : Codecs.AnimationDecoder;
VAR p : GIFAnimationDecoder;
BEGIN
	NEW(p); RETURN p
END AnimationDecoderFactory;

BEGIN
	InitDefaultPalette;
END GIFCodec.

-----------------------------------------

SystemTools.Free GIFCodec ~

