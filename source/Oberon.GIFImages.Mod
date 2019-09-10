(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GIFImages IN Oberon; (** non-portable *)	(* eos  **)

	(**
		Load GIF images (storing prohibited by Unisys patent)
	**)

	IMPORT
		SYSTEM, Files, Texts, Oberon, Colors, Images;


	VAR
		W: Texts.Writer;


	(*--- Image Format T8 (8 bit palette with transparent color 0) ---*)

	PROCEDURE PackT8 (VAR fmt: Images.Format0; adr: ADDRESS; bit: SIGNED32; VAR pix: Images.Pixel);
		CONST r = Images.r; g = Images.g; b = Images.b;
	BEGIN
		IF pix[Images.a] # 0X THEN
			SYSTEM.PUT(adr, CHR(Images.PaletteIndex(fmt.pal, ORD(pix[r]), ORD(pix[g]), ORD(pix[b]))))
		ELSE
			SYSTEM.PUT(adr, 0X)
		END
	END PackT8;

	PROCEDURE UnpackT8 (VAR fmt: Images.Format0; adr: ADDRESS; bit: SIGNED32; VAR pix: Images.Pixel);
		CONST r = Images.r; g = Images.g; b = Images.b; a = Images.a;
		VAR idx: CHAR;
	BEGIN
		SYSTEM.GET(adr, idx);
		IF idx = 0X THEN
			pix[r] := 0X; pix[g] := 0X; pix[b] := 0X; pix[a] := 0X
		ELSE
			pix := fmt.pal.col[ORD(idx)]
		END
	END UnpackT8;


	(*--- GIF Loader ---*)

	PROCEDURE Log (msg: ARRAY OF CHAR);
	BEGIN
		Texts.WriteString(W, "GIFImages: "); Texts.WriteString(W, msg); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
	END Log;

	PROCEDURE LoadData (VAR r: Files.Rider; img: Images.Image; interlaced: BOOLEAN);
		VAR
			ch: CHAR;
			codeBits, clearCode, endCode, curBits, maxCode, nextCode, bits, x, y, lines, prevCode, curCode, seq, len: SIGNED16;
			n, buf, blkPos, blkSize, ptr: SIGNED32;
			pix, run: ARRAY 1000H OF CHAR;
			prev: ARRAY 1000H OF SIGNED16;
			block: ARRAY 255 OF CHAR;

		PROCEDURE dot (pix: CHAR);
		BEGIN
			img.mem[ptr] := pix; INC(ptr); INC(x);
			IF x = img.width THEN
				IF interlaced THEN
					IF lines >= 8 THEN DEC(y, 8) ELSE DEC(y, lines) END;
					WHILE y < 0 DO
						lines := lines DIV 2; y := (img.height-1) - lines DIV 2
					END
				ELSE
					DEC(y)
				END;
				x := 0; ptr := y * img.bpr
			END
		END dot;

	BEGIN
		Files.Read(r, ch); codeBits := ORD(ch);
		clearCode := SIGNED16(ASH(1, codeBits)); endCode := clearCode+1;
		n := 0;
		WHILE n < clearCode DO
			pix[n] := CHR(n); prev[n] := -1; INC(n)
		END;
		WHILE n <= endCode DO
			pix[n] := 0X; prev[n] := -1; INC(n)
		END;
		curBits := codeBits+1; maxCode := SIGNED16(ASH(1, curBits)); nextCode := endCode+1;
		buf := 0; bits := 0; blkPos := 0; blkSize := 0;	(* bit buffer and current block are empty *)
		x := 0; y := img.height-1; ptr := y * img.bpr;
		IF interlaced THEN lines := 16 END;

		prevCode := clearCode;
		LOOP
			(* read next code *)
			WHILE bits < curBits DO	(* not enough bits available *)
				IF blkPos = blkSize THEN	(* at end of block *)
					Files.Read(r, ch);
					IF ch = 0X THEN	(* terminator block mark *)
						Log("not enough image data"); RETURN
					END;
					blkPos := 0; blkSize := ORD(ch);
					Files.ReadBytes(r, block, blkSize)
				END;
				buf := buf + ASH(ORD(block[blkPos]), bits); INC(blkPos); INC(bits, 8)
			END;
			curCode := SHORT(buf MOD maxCode);
			buf := ASH(buf, -curBits); DEC(bits, curBits);

			IF curCode = clearCode THEN
				curBits := codeBits+1; maxCode := SIGNED16(ASH(1, curBits)); nextCode := endCode+1
			ELSIF curCode = endCode THEN
				EXIT
			ELSIF prevCode = clearCode THEN
				dot(CHR(curCode)); seq := curCode
			ELSE
				IF curCode < nextCode THEN	(* reuse sequence *)
					seq := curCode; len := 0
				ELSE	(* append previous first char to previous sequence *)
					run[0] := pix[seq]; len := 1; seq := prevCode
				END;
				WHILE prev[seq] >= 0 DO
					run[len] := pix[seq]; INC(len); seq := prev[seq]
				END;
				dot(pix[seq]);
				WHILE len > 0 DO
					DEC(len); dot(run[len])
				END;

				(* the sequence just output gets a new code *)
				pix[nextCode] := pix[seq]; prev[nextCode] := prevCode; INC(nextCode);
				IF (nextCode = maxCode) & (curBits < 12) THEN
					INC(curBits); maxCode := SIGNED16(ASH(1, curBits))
				END
			END;
			prevCode := curCode
		END;

		(* search terminator block *)
		Files.Read(r, ch);
		WHILE ch # 0X DO
			Files.Set(r, Files.Base(r), Files.Pos(r) + ORD(ch));
			Files.Read(r, ch)
		END
	END LoadData;

	PROCEDURE Load (img: Images.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
		VAR
			file: Files.File; r: Files.Rider; sig: ARRAY 7 OF CHAR; w, h, images, left, top: SIGNED16;
			lcdFlags, backGrndIdx, ch, label, transPix, idFlags: CHAR; pal: Images.Palette; n, size: SIGNED32;
			backGrndCol: Images.Pixel; fmt: Images.Format; transparent, interlaced: BOOLEAN;
	BEGIN
		file := Files.Old(fname);
		IF file = NIL THEN RETURN END;

		(* check signature and version *)
		Files.Set(r, file, 0);
		Files.ReadBytes(r, sig, 6); sig[6] := 0X;
		IF (sig # "GIF87a") & (sig # "GIF89a") THEN RETURN END;

		(* logical screen descriptor *)
		Files.ReadInt(r, w); Files.ReadInt(r, h);	(* dimensions of logical screen *)
		Files.Read(r, lcdFlags); Files.Read(r, backGrndIdx); Files.Read(r, ch);	(* ignore aspect ratio *)

		(* set up default color table *)
		NEW(pal);
		FOR n := 0 TO 255 DO
			Images.SetRGB(pal.col[n], Colors.Red[n], Colors.Green[n], Colors.Blue[n])
		END;

		(* global color table *)
		IF ODD(ASH(ORD(lcdFlags), -7)) THEN
			n := 0; size := ASH(1, 1 + ORD(lcdFlags) MOD 8);
			WHILE n < size DO
				Files.Read(r, pal.col[n, Images.r]); Files.Read(r, pal.col[n, Images.g]); Files.Read(r, pal.col[n, Images.b]);
				INC(n)
			END;
			backGrndCol := pal.col[ORD(backGrndIdx)]
		ELSE
			Images.SetRGB(backGrndCol, 0C0H, 0C0H, 0C0H)	(* color 14 in Oberon standard palette, used for text background *)
		END;
		Images.InitPaletteFormat(fmt, pal);

		images := 0; transparent := FALSE;
		LOOP
			Files.Read(r, ch);
			IF r.eof THEN
				Log("unexpected end of file"); RETURN
			ELSIF ch = 3BX THEN	(* trailer *)
				EXIT
			ELSIF ch = 21X THEN	(* extension introducer *)
				Files.Read(r, label); Files.Read(r, ch);	(* extension label and block size *)
				IF label = 0F9X THEN	(* graphic control block *)
					IF ch # 4X THEN Log("graphic control extension block size # 4"); RETURN END;
					Files.Read(r, ch); transparent := ODD(ORD(ch));
					Files.Set(r, file, Files.Pos(r)+2); Files.Read(r, transPix);
					IF transparent THEN
						Images.InitFormat(fmt, Images.custom, 8, 1, {Images.index, Images.alpha}, pal, PackT8, UnpackT8)
					END;
					Files.Read(r, ch)	(* read next block size (should be zero) *)
				END;
				WHILE ch # 0X DO	(* skip data blocks *)
					Files.Set(r, file, Files.Pos(r) + ORD(ch)); Files.Read(r, ch)
				END
			ELSIF ch = 2CX THEN	(* image descriptor *)
				INC(images);
				IF images > 1 THEN
					Log("ignoring all but first image"); EXIT
				END;
				Files.ReadInt(r, left); Files.ReadInt(r, top);
				Files.ReadInt(r, w); Files.ReadInt(r, h);
				Files.Read(r, idFlags);
				interlaced := ODD(ASH(ORD(idFlags), -6));

				(* local color table *)
				IF ODD(ASH(ORD(idFlags), -7)) THEN
					n := 0; size := ASH(1, 1 + ORD(idFlags) MOD 8);
					WHILE n < size DO
						Files.Read(r, pal.col[n, Images.r]); Files.Read(r, pal.col[n, Images.g]); Files.Read(r, pal.col[n, Images.b]);
						INC(n)
					END
				END;

				(* create image and load image data *)
				Images.Create(img, w, h, fmt);
				LoadData(r, img, interlaced);

				IF transparent THEN	(* ensure that transparent color has index 0 *)
					IF transPix # 0X THEN
						pal.col[ORD(transPix)] := pal.col[0];
						n := 0;
						WHILE n < LEN(img.mem^) DO
							IF img.mem[n] = 0X THEN img.mem[n] := transPix
							ELSIF img.mem[n] = transPix THEN img.mem[n] := 0X
							END;
							INC(n)
						END
					END;
					pal.col[0] := backGrndCol
				END;

				(* don't forget to initialize the palette *)
				Images.InitPalette(pal, SHORT(size), 4)
			ELSE
				Log("confused by unknown block type"); RETURN
			END
		END;

		done := images > 0	(* successful if image has been read *)
	END Load;

	PROCEDURE Install*;
	BEGIN
		Images.LoadProc := Load
	END Install;


BEGIN
	Texts.OpenWriter(W)
END GIFImages.
