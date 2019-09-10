(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Fonts IN Oberon;	(** portable *) (*JG 16.3.94*)

(**
The Module Fonts implement the Oberon font manager. Fonts are collections
of characters, each character being a pattern and and metric data.
*)

	IMPORT SYSTEM, Kernel, Files, Objects, Display, OberonFonts IN A2;

	CONST MaxRuns = 32; IndexSize = 256*SIZE OF ADDRESS;
		substitute* = -1; font* = 0; metric* = 1; (** Font types. *)
		TraceMissing = TRUE;  TraceAlias = FALSE;

	TYPE
		Char* = POINTER TO CharDesc;
		Font* = POINTER TO FontDesc;

		CharDesc* = RECORD (Objects.ObjDesc)	(** The objects in a font library. *)	(* Note: offset used in GetCharObj *)
			dx*, x*, y*, w*, h*: SIGNED16;	(** Character width, pattern offset (x, y), pattern size (w, h). *)
			pat*: Display.Pattern	(** Character raster data. *)
		END;

		FontDesc* = RECORD (Objects.LibDesc)
			type*: SIGNED8;	(** Substitute, font, or metric. *)
			height*, minX*, maxX*, minY*, maxY*: SIGNED16	(** Font height, extremal values of characters in font. *)
		END;

		RunRec = RECORD beg, end: SIGNED16 END;

		BoxRec = RECORD
			dx, x, y, w, h: SIGNED16
		END;

	VAR FontId*: CHAR;	(** Initial character of font files (.Fnt). *)
			Default*: Font;	(** Default system screen font (typically Oberon10.Scn.Fnt). *)
			theChar: Char;
			conv: BOOLEAN;

	PROCEDURE Put1 (VAR a: ADDRESS; x: SIGNED16);
	VAR y: SIGNED8;
	BEGIN y := SHORT(x); SYSTEM.PUT(a, y); INC(a)
	END Put1;

	PROCEDURE Put2 (VAR a: ADDRESS; x: SIGNED32);
	VAR y: SIGNED16;
	BEGIN y := SHORT(x); SYSTEM.PUT(a, y); a := a + 2
	END Put2;

	PROCEDURE PutAdr (VAR a: ADDRESS; x: ADDRESS);
	BEGIN SYSTEM.PUT(a, x); a := a + SIZE OF ADDRESS
	END PutAdr;

	PROCEDURE ReadInt (VAR R: Files.Rider; VAR x: SIGNED16);
	VAR c0: CHAR; s1: SIGNED8;
	BEGIN Files.Read(R, c0); Files.Read(R, s1); x := s1; x := x * 100H + ORD(c0)
	END ReadInt;

(*
	PROCEDURE GetCharObj (L: Objects.Library; ref: SIGNED16; VAR obj: Objects.Object);
	CODE {SYSTEM.i386}
		MOV EAX, L[EBP]
		MOV EAX, 4[EAX]	; Objects.LibDesc ind
		MOVSX EBX, ref[EBP]
		MOV EAX, [EAX][EBX*4]
		MOV ECX, theChar
		MOVZX DX, BYTE -3[EAX] ;dx
		MOV 24[ECX], DX
		MOVSX DX, BYTE -2[EAX] ;x
		MOV 26[ECX], DX
		MOVSX DX, BYTE -1[EAX] ;y
		MOV 28[ECX], DX
		MOVZX DX, BYTE [EAX] ;w
		MOV 30[ECX], DX
		MOVZX DX, BYTE 1[EAX] ;h
		MOV 32[ECX], DX
		MOV 36[ECX], EAX
		MOV EAX, obj[EBP]
		MOV [EAX], ECX
	END GetCharObj;
*)
	(* portable version *)
	PROCEDURE GetCharObj (L: Objects.Library; ref: SIGNED16; VAR obj: Objects.Object);
	VAR m: ADDRESS; h1: SIGNED8; h2: ADDRESS; ch: CHAR;
	BEGIN
		m := L.ind;
		SYSTEM.GET(m + ref * SIZEOF(ADDRESS), h2); (* pat adr*)
		theChar.pat := h2;
		SYSTEM.GET(h2-3, h1); theChar.dx := h1;
		SYSTEM.GET(h2-2, h1); theChar.x := h1;
		SYSTEM.GET(h2-1, h1); theChar.y := h1;
		SYSTEM.GET(h2, ch); theChar.w := ORD(ch);	(*width & height always positive*)
		SYSTEM.GET(h2+1,ch); theChar.h := ORD(ch);
		obj := theChar
	END GetCharObj;

(** Return the character and data of ch in a font. *)
	PROCEDURE GetChar* (F: Font; ch: CHAR; VAR dx, x, y, w, h: SIGNED16; VAR pat: Display.Pattern);
	VAR obj: Objects.Object;
	BEGIN F.GetObj(F, ORD(ch), obj);
		WITH obj: Char DO
			dx := obj.dx; x := obj.x; y := obj.y; w := obj.w; h := obj.h; pat := obj.pat
		END
	END GetChar;

	PROCEDURE Internalize (F: Font; VAR R: Files.Rider; type: SIGNED8);
	VAR ch: CHAR;
			NofRuns, NofBoxes, i, k, l, m: SIGNED16;
			NofBytes: SIGNED32; RasterBase, A, a: ADDRESS;
			run: ARRAY MaxRuns OF RunRec;
			box: ARRAY 256 OF BoxRec;
	BEGIN F.type := type;
		Files.Read(R, ch); (*family*)
		Files.Read(R, ch); (*variant*)
		ReadInt(R, F.height);
		ReadInt(R, F.minX); ReadInt(R, F.maxX);
		ReadInt(R, F.minY); ReadInt(R, F.maxY);
		ReadInt(R, NofRuns);
		NofBoxes := 0; k := 0;
		WHILE k # NofRuns DO
			ReadInt(R, run[k].beg); ReadInt(R, run[k].end);
			NofBoxes := NofBoxes + run[k].end - run[k].beg;
			INC(k)
		END;
		l := 0;
		WHILE l # NofBoxes DO
			ReadInt(R, box[l].dx);
			ReadInt(R, box[l].x); ReadInt(R, box[l].y);
			ReadInt(R, box[l].w); ReadInt(R, box[l].h);
			INC(l)
		END;
		IF type = font THEN
			NofBytes := IndexSize + 29; l := 0;
			WHILE l # NofBoxes DO
				NofBytes := NofBytes + 5 + (box[l].w + 7) DIV 8 * box[l].h; INC(l)
			END;
			SYSTEM.NEW(F.ind, NofBytes);
			RasterBase := F.ind;
			A := RasterBase; a := A + IndexSize;
			Put1(a, 12); Put1(a, 0); Put1(a, -3); Put1(a, 12); Put1(a, 12); (*null char*)
			Put2(a, 0FFFH);
			Put2(a, 0801H); Put2(a, 0801H); Put2(a, 0801H); Put2(a, 0801H); Put2(a, 0801H);
			Put2(a, 0801H); Put2(a, 0801H); Put2(a, 0801H); Put2(a, 0801H); Put2(a, 0801H);
			Put2(a, 0FFFH);
			k := 0; l := 0; m := 0;
			WHILE k < NofRuns DO
				WHILE m < run[k].beg DO PutAdr(A, RasterBase + IndexSize + 3); INC(m) END;
				WHILE m < run[k].end DO PutAdr(A, a + 3);
					Put1(a, box[l].dx);
					Put1(a, box[l].x); Put1(a, box[l].y);
					Put1(a, box[l].w); Put1(a, box[l].h);
					i := (box[l].w + 7) DIV 8 * box[l].h;
					WHILE i # 0 DO Files.Read(R, ch); Put1(a, ORD(ch)); DEC(i) END;
					INC(l); INC(m)
				END;
				INC(k)
			END;
			WHILE m < 256 DO PutAdr(A, RasterBase + IndexSize + 3); INC(m) END
		ELSE (*type := metric*)
			SYSTEM.NEW(F.ind, IndexSize + 5 + NofBoxes*5);
			RasterBase := F.ind;
			A := RasterBase; a := A + IndexSize;
			Put1(a, 12); Put1(a, 0); Put1(a, -3); Put1(a, 12); Put1(a, 12); (*null char*)
			k := 0; l := 0; m := 0;
			WHILE k < NofRuns DO
				WHILE m < run[k].beg DO PutAdr(A, RasterBase + IndexSize + 3); INC(m) END;
				WHILE m < run[k].end DO PutAdr(A, a + 3);
					Put1(a, box[l].dx);
					Put1(a, box[l].x); Put1(a, box[l].y);
					Put1(a, box[l].w); Put1(a, box[l].h);
					INC(l); INC(m)
				END;
				INC(k)
			END;
			WHILE m < 256 DO PutAdr(A, RasterBase + IndexSize + 3); INC(m) END
		END
	END Internalize;

	PROCEDURE Substitute (F: Font);
	BEGIN F.type := substitute;
		F.height := Default.height;
		F.minX := Default.minX; F.maxX := Default.maxX;
		F.minY := Default.minY; F.maxY := Default.maxY;
		F.ind := Default.ind;
		IF TraceMissing THEN
			Kernel.WriteString("Missing: ");  Kernel.WriteString(F.name);  Kernel.WriteLn
		END
	END Substitute;

	PROCEDURE Load (L: Objects.Library);
	VAR f: Files.File; R: Files.Rider; id: CHAR; i, j: SIGNED32;
			name: Objects.Name;
	BEGIN
		WITH L: Font DO
			OberonFonts.ProvideFont(L.name);
			f := Files.Old(L.name);
			IF f = NIL THEN
				COPY(L.name, name);  name[7] := 0X;
				IF name = "Default" THEN
					IF TraceAlias THEN Kernel.WriteString(L.name);  Kernel.WriteString(" -> ") END;
					COPY(Default.name, name);
					i := 0;  WHILE (name[i] # 0X) & ((name[i] < "0") OR (name[i] > "9")) DO INC(i) END;
					j := 7;  WHILE L.name[j] # 0X DO name[i] := L.name[j];  INC(i);  INC(j) END;
					name[i] := 0X;
					IF TraceAlias THEN Kernel.WriteString(name);  Kernel.WriteLn END;
					COPY(name, L.name);
					f := Files.Old(name)
				ELSE
					name[6] := 0X;
					IF conv & (name = "Syntax") THEN
						IF TraceAlias THEN Kernel.WriteString(L.name);  Kernel.WriteString(" -> ") END;
						name := Default.name;
						j := 0;  WHILE (name[j] # 0X) & ((name[j] < "0") OR (name[j] > "9")) DO INC(j) END;
						i := 6;  WHILE (L.name[i] >= "0") & (L.name[i] <= "9") DO name[j] := L.name[i];  INC(i);  INC(j) END;
						IF L.name[i] = "m" THEN name[j] := "b";  INC(i);  INC(j) END;	(* Syntax medium -> Oberon bold *)
						WHILE L.name[i] # 0X DO name[j] := L.name[i];  INC(i);  INC(j) END;
						name[j] := 0X;
						IF TraceAlias THEN Kernel.WriteString(name);  Kernel.WriteLn END;
						COPY(name, L.name);
						f := Files.Old(name)
					END
				END
			END;
			IF f # NIL THEN
				Files.Set(R, f, 0); Files.Read(R, id);
				IF id = FontId THEN Files.Read(R, L.type);
					IF (L.type = metric) OR (L.type = font) THEN Internalize(L, R, L.type) ELSE Substitute(L) END
				ELSE Substitute(L) END
			ELSE
				COPY(L.name, name); i := 0;
				WHILE name[i] # 0X DO INC(i) END;
				IF (i >= 8) & (name[i-8] = ".") & (name[i-7] = "M") & (name[i-6] = "d") THEN
					name[i-7] := "P"; name[i-6] := "r";
					OberonFonts.ProvideFont(name);
					f := Files.Old(name);
					IF f # NIL THEN
						Files.Set(R, f, 0); Files.Read(R, id);
						IF id = FontId THEN Files.Read(R, L.type);
							IF (L.type = metric) OR (L.type = font) THEN Internalize(L, R, metric) ELSE Substitute(L) END
						ELSE Substitute(L) END
					ELSE Substitute(L) END
				ELSE Substitute(L) END
			END
		END
	END Load;

(** Load and cache a font. *)
	PROCEDURE This* (CONST name: ARRAY OF CHAR): Font;
	VAR L: Objects.Library;
	BEGIN
		OberonFonts.ProvideFont(name);
		L := Objects.ThisLibrary(name);
		IF (L # NIL) & (L IS Font) THEN  RETURN L(Font)  ELSE  RETURN NIL  END
	END This;

	PROCEDURE New (): Objects.Library;
	VAR F: Font;
	BEGIN NEW(F);
		F.Load := Load; F.GetObj := GetCharObj; RETURN F
	END New;

	PROCEDURE Init;
	VAR s: ARRAY 8 OF CHAR;
	BEGIN
		FontId := Objects.LibBlockId; NEW(theChar);
		Kernel.GetConfig("FontConv", s);
		conv := s[0] # "0";
		Objects.Register("Fnt", New)
	END Init;

BEGIN
	Init
END Fonts.

(* Remarks:

1. Screen fonts and printer fonts are stored in files with extensions .Scn.Fnt and .Prx.Fnt respectively (the x refers to x00dpi printer fonts). A full font name (like Syntax12b.Scn.Fnt) has to be specified to load a font. Should the font not be available, a substitute font is created. This has the same name but the wrong character metrics (often the Syntax10 font is used instead). A file with an .Mdx.Fnt extension is a metric font containing only metric data and no raster patterns. Each printer font has an associated metric font. A metric font is used to make measurements while printing. Sometimes the font module is clever enough to simulate the presence of a metric font by reading the metric data from a printer font (the metric fonts need not necessarily be available). If you need to find out the size of a character on paper, you should always request a metric font (it is faster to load and requires less memory than the printer fonts). Some Font modules support Truetype fonts implemented in the host operating system.

2. Fonts are extensions of Libraries. Each letter of the font is a (virtual) object indexed by ASCII code. Note that to optimize garbage collection, the same object instance is returned for each call to the GetObj library method (no matter what font or character is involved). This is realized by copying the character raster and metrics from a specially compressed representation of the font data. The GetChar procedure fetches a character from the font using this mechanism. The PutObj, GenRef and Store methods of fonts have no function.

3. The pattern (raster) of a character is only as large as required. The x, y, w, h values of a character metric specify the offset of the pattern from a virtual text baseline and the width and height of the pattern. Display.CopyPattern is used to draw the character patterns of the display. Help procedures like Display3.String hides the low-level display process and allows you to display strings at a time.

4. The default font is Oberon10.Scn.Fnt.
*)