(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE EditTools IN Oberon; (** portable *)	(** CAS/HM 3.12.93  jm 3.5.95 ported/extended to System 3 /  tk 6.2.96**)

(*
	22.2.96 ejz/jm - added ISO support
	11.7.96 tk - added StoreMac
	29.1.97 afi - ChangeColor, ChangeVoff
	28.5.97 ps - fixed IncSize
	30.9.97 ejz - added Upper & Lower
	5.5.98 ejz - added FlipCase
*)

IMPORT
	Objects, Texts, Oberon, Fonts, Files, Display, Attributes, Gadgets, Documents, TextGadgets, TextDocs, Desktops, Strings;

CONST
	Ascii = 0; Unix = 1; Mac = 2; Unicode = 3;

VAR
	W, WR: Texts.Writer;

	PROCEDURE Plural (n: SIGNED32; CONST s: ARRAY OF CHAR);
	BEGIN Texts.WriteInt(W, n, 0); Texts.Write(W, " "); Texts.WriteString(W, s);
		IF n # 1 THEN Texts.Write(W, "s") END;
		Texts.Append(Oberon.Log, W.buf);
	END Plural;

	PROCEDURE SkipArrow (VAR S: Texts.Scanner);
	BEGIN Texts.Scan(S);
		IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
			IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S) ELSE S.class := Texts.Inval END
		ELSE S.class := Texts.Inval
		END
	END SkipArrow;

	(* string primitives *)

	PROCEDURE SplitFontName (CONST fn: ARRAY OF CHAR; VAR i, j, size: SIGNED16);
		VAR k: SIGNED16;
	BEGIN i := 0; size := 0;
		WHILE (fn[i] # 0X) & ((fn[i] < "0") OR ("9" < fn[i])) DO INC(i) END;
		j := i; WHILE ("0" <= fn[j]) & (fn[j] <= "9") DO INC(j) END;
		k := i; WHILE k < j DO size := size * 10 + ORD(fn[k]) - 30H; INC(k) END
	END SplitFontName;

	PROCEDURE CombineFontName (CONST prefix, suffix: ARRAY OF CHAR; i, j, size: SIGNED16; VAR fn: ARRAY OF CHAR);
		VAR k: SIGNED16; ch: CHAR; dig: ARRAY 10 OF CHAR;
	BEGIN COPY(prefix, fn); k := 0;
		IF size < 6 THEN size := 6 ELSIF size > 128 THEN size := 128 END;
		REPEAT dig[k] := CHR(size MOD 10 + 30H); size := size DIV 10; INC(k) UNTIL size = 0;
		REPEAT DEC(k); fn[i] := dig[k]; INC(i) UNTIL k = 0;
		REPEAT ch := suffix[j]; fn[i] := ch; INC(i); INC(j) UNTIL ch = 0X
	END CombineFontName;

	PROCEDURE IsFont(lib: Objects.Library): BOOLEAN;
	BEGIN RETURN (lib # NIL) & (lib IS Fonts.Font)
	END IsFont;

	PROCEDURE ThisFont(CONST name: ARRAY OF CHAR): Fonts.Font;
		VAR fnt: Fonts.Font;
	BEGIN
		fnt := Fonts.This(name);
		IF (fnt = Fonts.Default) & (fnt.name # name) THEN
			RETURN NIL
		ELSE
			RETURN fnt
		END
	END ThisFont;

	(** text manipulation **)

	PROCEDURE IncFontSize* (T: Texts.Text; beg, end: SIGNED32; delta: SIGNED16);
		CONST MinSize = 6; MaxSize = 96;
		VAR R: Texts.Reader; fnt: Objects.Library; fn: Objects.Name; org: SIGNED32; i, j, size: SIGNED16; ch: CHAR;
	BEGIN Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
		WHILE ~R.eot & (beg < end) DO org := beg;
			fnt := R.lib;
			WHILE ~R.eot & (beg < end) & (R.lib = fnt) DO INC(beg); Texts.Read(R, ch) END;
			IF IsFont(fnt) THEN SplitFontName(fnt.name, i, j, size);
				IF (i < j) & ((size+delta) >= MinSize) & ((size+delta) <= MaxSize) THEN
					CombineFontName(fnt.name, fnt.name, i, j, size + delta, fn); fnt := ThisFont(fn);
					IF fnt # NIL THEN Texts.ChangeLooks(T, org, beg, {0}, fnt, 0, 0) END
				END
			END
		END
	END IncFontSize;

	PROCEDURE ChangeFontSize* (T: Texts.Text; beg, end: SIGNED32; old, new: SIGNED16);
		VAR R: Texts.Reader; fnt: Objects.Library; fn: Objects.Name; org: SIGNED32; i, j, size: SIGNED16; ch: CHAR;
	BEGIN Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
		WHILE ~R.eot & (beg < end) DO org := beg; fnt := R.lib;
			WHILE ~R.eot & (beg < end) & (R.lib = fnt) DO INC(beg); Texts.Read(R, ch) END;
			IF IsFont(fnt) THEN
				SplitFontName(fnt.name, i, j, size);
				IF (i < j) & ((size = old) OR (old = -1)) THEN
					CombineFontName(fnt.name, fnt.name, i, j, new, fn); fnt := ThisFont(fn);
					IF fnt # NIL THEN Texts.ChangeLooks(T, org, beg, {0}, fnt, 0, 0) END
				END
			END
		END
	END ChangeFontSize;

	PROCEDURE ChangeFontFamily* (T: Texts.Text; beg, end: SIGNED32; CONST old, new: ARRAY OF CHAR);
		VAR R: Texts.Reader; fnt: Objects.Library; fn: Objects.Name; org: SIGNED32; i, i1, j, j1, size, size1: SIGNED16; ch: CHAR;
	BEGIN Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
		WHILE ~R.eot & (beg < end) DO org := beg; fnt := R.lib;
			WHILE ~R.eot & (beg < end) & (R.lib = fnt) DO INC(beg); Texts.Read(R, ch) END;
			IF IsFont(fnt) THEN SplitFontName(fnt.name, i, j, size); COPY(fnt.name, fn); fn[i] := 0X;
				IF (i < j) & ((fn = old) OR (old[0] = "?")) THEN SplitFontName(new, i1, j1, size1);
					CombineFontName(new, fnt.name, i1, j, size, fn); fnt := ThisFont(fn);
					IF fnt # NIL THEN Texts.ChangeLooks(T, org, beg, {0}, fnt, 0, 0) END
				END
			END
		END
	END ChangeFontFamily;

	PROCEDURE ChangeFontStyle* (T: Texts.Text; beg, end: SIGNED32; old, new: CHAR);
		VAR R: Texts.Reader; fnt: Objects.Library; fn: Objects.Name; org: SIGNED32; i, j, k, size: SIGNED16; ch: CHAR;
	BEGIN Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
		WHILE ~R.eot & (beg < end) DO org := beg; fnt := R.lib;
			WHILE ~R.eot & (beg < end) & (R.lib = fnt) DO INC(beg); Texts.Read(R, ch) END;
			IF IsFont(fnt) THEN
				SplitFontName(fnt.name, i, j, size);
				IF (i < j) & ((fnt.name[j] = old) OR (old = "?")) & (fnt.name[j] # new) THEN COPY(fnt.name, fn);
					IF fn[j] = "." THEN k := j+1;
						WHILE fn[k] # 0X DO INC(k) END;
						WHILE k >= j DO fn[k+1] := fn[k]; DEC(k) END
					ELSIF new = "." THEN k := j;
						REPEAT fn[k] := fn[k+1]; INC(k) UNTIL fn[k] = 0X
					END;
					fn[j] := new; fnt := ThisFont(fn);
					IF fnt # NIL THEN Texts.ChangeLooks(T, org, beg, {0}, fnt, 0, 0) END
				END
			END
		END
	END ChangeFontStyle;

	PROCEDURE ChangeFont* (T: Texts.Text; beg, end: SIGNED32; CONST old, new: ARRAY OF CHAR);
		VAR R: Texts.Reader; fnt: Objects.Library; org: SIGNED32; ch: CHAR;
	BEGIN Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
		WHILE ~R.eot & (beg < end) DO org := beg; fnt := R.lib;
			WHILE ~R.eot & (beg < end) & (R.lib = fnt) DO INC(beg); Texts.Read(R, ch) END;
			IF IsFont(fnt) THEN
				IF (fnt.name = old) OR (old = "?") THEN fnt := ThisFont(new);
					IF fnt # NIL THEN Texts.ChangeLooks(T, org, beg, {0}, fnt, 0, 0) END
				END
			END
		END
	END ChangeFont;

	(** increment or decrement font size of selected text *)
	PROCEDURE IncSize*;	(** size; selection **)
		CONST MinSize = -6; MaxSize = 6;
		VAR S: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32;
	BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		Oberon.GetSelection(text, beg, end, time);
		IF (time # -1) & (S.class = Texts.Int) & (S.line = 0) & (MinSize <= S.i) & (S.i <= MaxSize) THEN
			IncFontSize(text, beg, end, SHORT(S.i))
		END
	END IncSize;

	(** change font size of selected text (from => to) *)
	PROCEDURE ChangeSize*;	(** {old "=>" new}, selection **)
		CONST MinSize = 6; MaxSize = 96;
		VAR S: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; old: SIGNED16;
	BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		Oberon.GetSelection(text, beg, end, time);
		IF (time # -1) & (S.line = 0) THEN
			WHILE ~S.eot & ((S.class = Texts.Int) & (MinSize <= S.i) & (S.i <= MaxSize) OR (S.class = Texts.Char) & (S.c = "?")) DO
				IF (S.class = Texts.Char) & (S.c = "?") THEN old := -1 ELSE old := SHORT(S.i) END;
				SkipArrow(S);
				IF (S.class = Texts.Int) & (MinSize <= S.i) & (S.i <= MaxSize) THEN
					ChangeFontSize(text, beg, end, old, SHORT(S.i)); Texts.Scan(S)
				END
			END
		END
	END ChangeSize;

	(** change style of selected text (from => to) *)
	PROCEDURE ChangeStyle*;	(** {old "=>" new}, selection **)
		VAR S: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; old, new: CHAR;
	BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		Oberon.GetSelection(text, beg, end, time);
		IF (time # -1) & (S.line = 0) THEN
			WHILE ~S.eot & ((S.class = Texts.Name) OR (S.class = Texts.Char)) DO
				IF S.class = Texts.Char THEN old := S.c ELSE old := S.s[0] END;
				SkipArrow(S);
				IF (S.class = Texts.Name) OR (S.class = Texts.Char) THEN
					IF S.class = Texts.Char THEN new := S.c ELSE new := S.s[0] END;
					ChangeFontStyle(text, beg, end, old, new); Texts.Scan(S)
				END
			END
		END
	END ChangeStyle;

	(** change font family of selected text (from => to) *)
	PROCEDURE ChangeFamily*;	(** {old "=>" new}, selection **)
		VAR S: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; old: Objects.Name;
	BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		Oberon.GetSelection(text, beg, end, time);
		IF (time # -1) & (S.line = 0) THEN
			WHILE ~S.eot & ((S.class = Texts.Name) OR (S.class = Texts.Char) & (S.c = "?")) DO
				IF (S.class = Texts.Char) & (S.c = "?") THEN old[0] := "?"; old[1] := 0X ELSE COPY(S.s, old) END;
				SkipArrow(S);
				IF S.class = Texts.Name THEN
					ChangeFontFamily(text, beg, end, old, S.s); Texts.Scan(S)
				END
			END
		END
	END ChangeFamily;

	(** change font of selected text *)
	PROCEDURE Change*;	(** {old "=>" new}, selection **)
		VAR S: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; old: Objects.Name;
	BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		Oberon.GetSelection(text, beg, end, time);
		IF (time # -1) & (S.line = 0) THEN
			WHILE (S.class = Texts.Name) OR ((S.class = Texts.Char) & (S.c = "?")) DO
				IF S.class = Texts.Name THEN COPY(S.s, old) ELSE old := "?" END;
				SkipArrow(S);
				IF S.class = Texts.Name THEN
					ChangeFont(text, beg, end, old, S.s); Texts.Scan(S)
				END
			END
		END
	END Change;

	PROCEDURE ChangeCol* (T: Texts.Text; beg, end: SIGNED32; old, new: SIGNED16);
		VAR R: Texts.Reader; org: SIGNED32; color: SIGNED16; ch: CHAR;
	BEGIN
		Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
		WHILE ~R.eot & (beg < end) DO
			org := beg; color := R.col;
			WHILE ~R.eot & (beg < end) & (R.col = color) DO INC(beg); Texts.Read(R, ch) END;
			IF (color = old) OR (old = -1) THEN
				Texts.ChangeLooks(T, org, beg, {1}, NIL, SHORT(new), 0);
			END;
		END
	END ChangeCol;

	(** change color of selected text *)
	PROCEDURE ChangeColor*;	(** {old "=>" new}, selection / old may be "?" / Color = 0 .. 255 **)
		CONST Range=256;
		VAR S: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; old: SIGNED16;
	BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		Oberon.GetSelection(text, beg, end, time);
		IF (time # -1) & (S.line = 0) THEN
			WHILE ~S.eot & ((S.class = Texts.Int) & (0 <= S.i) & (S.i < Range) OR (S.class = Texts.Char) & (S.c = "?")) DO
				IF (S.class = Texts.Char) & (S.c = "?") THEN old := -1 ELSE old := SHORT(S.i) END;
				SkipArrow(S);
				IF (S.class = Texts.Int) & (0 <= S.i) & (S.i < Range) THEN
					ChangeCol(text, beg, end, old, SHORT(S.i)); Texts.Scan(S)
				END
			END
		END
	END ChangeColor;

	PROCEDURE Changevoff* (T: Texts.Text; beg, end: SIGNED32; old, new: SIGNED16);
		VAR R: Texts.Reader; org: SIGNED32; voff: SIGNED16; ch: CHAR;
	BEGIN
		Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
		WHILE ~R.eot & (beg < end) DO
			org := beg; voff := R.voff;
			WHILE ~R.eot & (beg < end) & (R.voff = voff) DO INC(beg); Texts.Read(R, ch) END;
			IF (voff = old) OR (old = -1) THEN
				Texts.ChangeLooks(T, org, beg, {2}, NIL, 0, SHORT(new));
			END;
		END
	END Changevoff;

	(** change offset of selected text *)
	PROCEDURE ChangeVoff*;	(** {old "=>" new}, selection / old may be "?" / Voff = -32 .. 32 **)
		CONST Range=32;

		VAR S: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; old: SIGNED16;
	BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		Oberon.GetSelection(text, beg, end, time);
		IF (time # -1) & (S.line = 0) THEN
			WHILE ~S.eot & ((S.class = Texts.Int) & (-Range <= S.i) & (S.i <= Range) OR (S.class = Texts.Char) & (S.c = "?")) DO
				IF (S.class = Texts.Char) & (S.c = "?") THEN old := -1 ELSE old := SHORT(S.i) END;
				SkipArrow(S);
				IF (S.class = Texts.Int) & (-Range <= S.i) & (S.i <= Range) THEN
					Changevoff(text, beg, end, old, SHORT(S.i)); Texts.Scan(S)
				END
			END
		END
	END ChangeVoff;

	PROCEDURE Incvoff* (T: Texts.Text; beg, end: SIGNED32; delta: SIGNED16);
		VAR R: Texts.Reader; org: SIGNED32; voff: SIGNED16; ch: CHAR;
	BEGIN
		Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
		WHILE ~R.eot & (beg < end) DO
			org := beg; voff := R.voff;
			WHILE ~R.eot & (beg < end) & (R.voff = voff) DO INC(beg); Texts.Read(R, ch) END;
			Texts.ChangeLooks(T, org, beg, {2}, NIL, 0, SHORT(voff + delta))
		END
	END Incvoff;

	PROCEDURE IncVoff*;	(** Voff increment; selection / size = -32 .. 32 **)
		CONST Range=32;
		VAR S: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32;
	BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		Oberon.GetSelection(text, beg, end, time);
		IF (time # -1) & (S.class = Texts.Int) & (S.line = 0) & (-Range <= S.i) & (S.i <= Range) THEN
			Incvoff(text, beg, end, SHORT(S.i))
		END
	END IncVoff;

	PROCEDURE upper*(T: Texts.Text; beg, end: SIGNED32);
		VAR
			R: Texts.Reader;
			pos: SIGNED32;
			ch: CHAR;
	BEGIN
		pos := beg;
		Texts.OpenReader(R, T, pos); Texts.Read(R, ch);
		WHILE ~R.eot & (pos < end) DO
			Texts.SetFont(W, R.lib); Texts.SetColor(W, R.col); Texts.SetOffset(W, R.voff);
			IF R.lib IS Fonts.Font THEN
				Texts.Write(W, Strings.UpperCh(ch))
			ELSE
				Texts.Write(W, ch)
			END;
			INC(pos); Texts.Read(R, ch)
		END;
		Texts.Delete(T, beg, end);
		Texts.Insert(T, beg, W.buf)
	END upper;

	(** make selection uppercase *)
	PROCEDURE Upper*;
		VAR
			text: Texts.Text;
			beg, end, time: SIGNED32;
	BEGIN
		Oberon.GetSelection(text, beg, end, time);
		IF time # -1 THEN
			upper(text, beg, end)
		END
	END Upper;

	PROCEDURE lower*(T: Texts.Text; beg, end: SIGNED32);
		VAR
			R: Texts.Reader;
			pos: SIGNED32;
			ch: CHAR;
	BEGIN
		pos := beg;
		Texts.OpenReader(R, T, pos); Texts.Read(R, ch);
		WHILE ~R.eot & (pos < end) DO
			Texts.SetFont(W, R.lib); Texts.SetColor(W, R.col); Texts.SetOffset(W, R.voff);
			IF R.lib IS Fonts.Font THEN
				Texts.Write(W, Strings.LowerCh(ch))
			ELSE
				Texts.Write(W, ch)
			END;
			INC(pos); Texts.Read(R, ch)
		END;
		Texts.Delete(T, beg, end);
		Texts.Insert(T, beg, W.buf)
	END lower;

	(** make selection lowercase *)
	PROCEDURE Lower*;
		VAR
			text: Texts.Text;
			beg, end, time: SIGNED32;
	BEGIN
		Oberon.GetSelection(text, beg, end, time);
		IF time # -1 THEN
			lower(text, beg, end)
		END
	END Lower;

	PROCEDURE flipCase*(T: Texts.Text; beg, end: SIGNED32);
		VAR
			R: Texts.Reader;
			pos: SIGNED32;
			flip, ch: CHAR;
	BEGIN
		pos := beg;
		Texts.OpenReader(R, T, pos); Texts.Read(R, ch);
		WHILE ~R.eot & (pos < end) DO
			Texts.SetFont(W, R.lib); Texts.SetColor(W, R.col); Texts.SetOffset(W, R.voff);
			IF R.lib IS Fonts.Font THEN
				flip := Strings.UpperCh(ch);
				IF flip = ch THEN
					flip := Strings.LowerCh(ch)
				END;
				Texts.Write(W, flip)
			ELSE
				Texts.Write(W, ch)
			END;
			INC(pos); Texts.Read(R, ch)
		END;
		Texts.Delete(T, beg, end);
		Texts.Insert(T, beg, W.buf)
	END flipCase;

	(** flip case of the selection *)
	PROCEDURE FlipCase*;
		VAR
			text: Texts.Text;
			beg, end, time: SIGNED32;
	BEGIN
		Oberon.GetSelection(text, beg, end, time);
		IF time # -1 THEN
			flipCase(text, beg, end)
		END
	END FlipCase;

	PROCEDURE open(os: SIGNED8);
	VAR S: Attributes.Scanner; F: Files.File; R: Files.Rider; T: Texts.Text; ch, ch2: CHAR;
		D: Documents.Document; f: TextGadgets.Frame;
	BEGIN
		Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Attributes.Scan(S);
		IF S.class IN {Attributes.Name, Attributes.String} THEN
			NEW(T); Texts.Open(T, "");
			F := Files.Old(S.s);
			NEW(D); TextDocs.InitDoc(D); (* make document wrapper *)
			IF F # NIL THEN
				Files.Set(R, F, 0);
				IF os = Ascii THEN
					D.Store := StoreAsciiDoc;
					Files.Read(R, ch);
					WHILE ~R.eof DO
						IF ch # Strings.LF THEN Texts.Write(W, Strings.ISOToOberon[ORD(ch)]) END;
						Files.Read(R, ch);
					END
				ELSIF os = Unix THEN
					D.Store := StoreUnixDoc;
					Files.Read(R, ch);
					WHILE ~R.eof DO
						IF ch = Strings.LF THEN ch := Strings.CR END;
						Texts.Write(W, Strings.ISOToOberon[ORD(ch)]);
						Files.Read(R, ch);
					END
				ELSIF os = Unicode THEN
					D.Store := StoreUnicodeDoc;
					Files.Read(R, ch); Files.Read(R, ch2); (* FF FE or FE FF *)
					IF ch > ch2 THEN
						Files.Read(R, ch); Files.Read(R, ch2);
						WHILE ~R.eof DO
							IF ch # Strings.LF THEN Texts.Write(W, Strings.ISOToOberon[ORD(ch)]) END;
							Files.Read(R, ch); Files.Read(R, ch2)
						END
					ELSE
						Files.Read(R, ch2); Files.Read(R, ch);
						WHILE ~R.eof DO
							IF ch # Strings.LF THEN Texts.Write(W, Strings.ISOToOberon[ORD(ch)]) END;
							Files.Read(R, ch2); Files.Read(R, ch)
						END
					END
				ELSE
					HALT(99)
				END;
				Texts.Append(T, W.buf)
			END;
			NEW(f); TextGadgets.Init(f, T, FALSE);	(* create content *)
			Documents.Init(D, f); (* and merge together *)
			COPY(S.s, D.name);
			D.W := Display.Width DIV 8 * 3 + 20;
			Desktops.ShowDoc(D)
		END
	END open;

	(** Open ASCII file as Oberon text *)
	PROCEDURE OpenAscii*;
	BEGIN
		open(Ascii)
	END OpenAscii;

	(** Open UNIX ASCII file as Oberon text *)
	PROCEDURE OpenUnix*;
	BEGIN
		open(Unix)
	END OpenUnix;

	(** Open Unicode file as Oberon text *)
	PROCEDURE OpenUnicode*;
	BEGIN
		open(Unicode)
	END OpenUnicode;

	PROCEDURE StoreDoc(D: Documents.Document; os: SIGNED8);
	VAR L: Objects.LinkMsg;
		R: Texts.Reader; F: Files.File; r: Files.Rider; bak: ARRAY 64 OF CHAR; ch: CHAR;
		i, res: SIGNED16;
	BEGIN
		IF (D # NIL) & (D.dsc # NIL) THEN
			Texts.WriteString(W, "EditTools.Store");
			CASE os OF
				Unix: Texts.WriteString(W, "Unix ")
				|Mac: Texts.WriteString(W, "Mac ")
				|Unicode: Texts.WriteString(W, "Unicode ")
				|Ascii: Texts.WriteString(W, "Ascii ")
			END;
			Texts.Append(Oberon.Log, W.buf);
			IF D.name # "" THEN
				L.id := Objects.get; L.name := "Model"; L.obj := NIL; L.res := -1; D.dsc.handle(D.dsc, L);
				IF (L.obj # NIL) & (L.obj IS Texts.Text) THEN
					F := Files.New(D.name);
					IF F # NIL THEN
						COPY(D.name, bak); i := 0;
						WHILE bak[i] # 0X DO INC(i) END;
						bak[i] := "."; bak[i+1] := "B"; bak[i+2] := "a"; bak[i+3] := "k"; bak[i+4] := 0X;
						Files.Rename(D.name, bak, res);

						Files.Set(r, F, 0);
						IF os = Unicode THEN
							Files.Write(r, 0FFX); Files.Write(r, 0FEX)
						END;
						Texts.OpenReader(R, L.obj(Texts.Text), 0);
						Texts.Read(R, ch);
						WHILE ~R.eot DO
							IF (R.lib # NIL) & (R.lib IS Fonts.Font) THEN
								IF ch = Strings.CR THEN
									IF os = Ascii THEN Files.Write(r, ch) END;
									IF os = Unicode THEN Files.Write(r, ch); Files.Write(r, 0X) END;
									IF os # Mac THEN ch := Strings.LF END
								END;
								Files.Write(r, Strings.OberonToISO[ORD(ch)]);
								IF os = Unicode THEN Files.Write(r, 0X) END
							END;
							Texts.Read(R, ch)
						END;
						Files.Register(F);
						Texts.WriteString(W, D.name); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
					ELSE Texts.WriteString(W, "[invalid title]"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
					END
				END
			ELSE Texts.WriteString(W, "[untitled document]"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
			END
		END
	END StoreDoc;

	PROCEDURE StoreUnixDoc(D: Documents.Document);
	BEGIN
		StoreDoc(D, Unix)
	END StoreUnixDoc;

(*
	PROCEDURE StoreMacDoc(D: Documents.Document);
	BEGIN
		StoreDoc(D, Mac)
	END StoreMacDoc;
*)

	PROCEDURE StoreUnicodeDoc(D: Documents.Document);
	BEGIN
		StoreDoc(D, Unicode)
	END StoreUnicodeDoc;

	PROCEDURE StoreAsciiDoc(D: Documents.Document);
	BEGIN
		StoreDoc(D, Ascii)
	END StoreAsciiDoc;

	PROCEDURE store(os: SIGNED8);
	VAR S: Attributes.Scanner; D: Documents.Document;
	BEGIN
		Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Attributes.Scan(S);
		IF (S.class = Attributes.Char) & (S.c = "*") THEN D := Documents.MarkedDoc()
		ELSE D := Desktops.CurDoc(Gadgets.context)
		END;
		StoreDoc(D, os);
	END store;

	(** Store Oberon text as ASCII file *)
	PROCEDURE StoreAscii*;
	BEGIN store(Ascii)
	END StoreAscii;

	(** Store Oberon text as UNIX ASCII file *)
	PROCEDURE StoreUnix*;
	BEGIN store(Unix)
	END StoreUnix;

	(** Store Oberon text as Macintosh ASCII file *)
	PROCEDURE StoreMac*;
	BEGIN store(Mac)
	END StoreMac;

	(** Store Oberon text as Unicode file *)
	PROCEDURE StoreUnicode*;
	BEGIN store(Unicode)
	END StoreUnicode;

	(** Strip objects from text *)
	PROCEDURE RemoveObjects*;
	VAR D: Documents.Document; L: Objects.LinkMsg; R: Texts.Reader; ch: CHAR; pos: SIGNED32;
	BEGIN
		D := Documents.MarkedDoc();
		IF (D # NIL) & (D.dsc # NIL) THEN
			L.id := Objects.get; L.name := "Model"; L.obj := NIL; L.res := -1; D.dsc.handle(D.dsc, L);
			IF (L.obj # NIL) & (L.obj IS Texts.Text) THEN
				Texts.OpenReader(R, L.obj(Texts.Text), 0);
				pos := 0;
				Texts.Read(R, ch);
				WHILE ~R.eot DO
					IF (R.lib # NIL) & ~(R.lib IS Fonts.Font) THEN
						Texts.Delete(L.obj(Texts.Text), pos, pos+1); Texts.OpenReader(R, L.obj(Texts.Text), pos)
					ELSE INC(pos);
					END;
					Texts.Read(R, ch)
				END
			END
		END
	END RemoveObjects;

	PROCEDURE Count* (T: Texts.Text; beg, end: SIGNED32; VAR wc, pc, ec: SIGNED32);
		VAR R: Texts.Reader; ch: CHAR;
	BEGIN wc:=0; pc:=0; ec:=0;
		Texts.OpenReader(R, T, beg); Texts.Read(R, ch); INC(beg);
		WHILE beg <= end DO
			WHILE (beg <= end) & (ch <= " ") DO
				IF (R.lib # NIL) & ~(R.lib IS Fonts.Font) THEN INC(ec)
				ELSIF ch = Strings.CR THEN INC(pc)
				END;
				Texts.Read(R, ch); INC(beg)
			END;
			IF beg <= end THEN INC(wc);
				WHILE (beg <= end) & (ch > " ") DO Texts.Read(R, ch); INC(beg) END
			END
		END
	END Count;

	PROCEDURE GetMainArg (VAR S: Texts.Scanner; VAR beg, end: SIGNED32);
		VAR text: Texts.Text; sbeg, send, time: SIGNED32;
	BEGIN beg:=Oberon.Par.pos; end:=Oberon.Par.text.len;
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		IF (S.class=Texts.Char) & (S.line=0) & (S.c="^") THEN Oberon.GetSelection(text, sbeg, send, time);
			IF time # -1 THEN beg:=sbeg; end:=send; Texts.OpenScanner(S, text, beg); Texts.Scan(S) END
		END
	END GetMainArg;

	(** Calculates # words, chars, and objects *)
	PROCEDURE Words*;	(** "@" | "^" | "*" *)
		VAR S: Texts.Scanner; D: Documents.Document; text: Texts.Text; L: Objects.LinkMsg;
			cc, wc, pc, ec, beg1, end1, beg, end, time: SIGNED32;  done: BOOLEAN;
	BEGIN GetMainArg(S, beg1, end1); D:=Documents.MarkedDoc(); Oberon.GetSelection(text, beg, end, time);
		done := FALSE;
		IF (S.class=Texts.Char) & (S.c="*") & (D # NIL) THEN
			L.id := Objects.get; L.name := "Model"; L.obj := NIL; L.res := -1; D.dsc.handle(D.dsc, L);
			IF (L.obj # NIL) & (L.obj IS Texts.Text) THEN
				cc:=L.obj(Texts.Text).len; Count(L.obj(Texts.Text), 0, cc, wc, pc, ec); done := TRUE
			END
		ELSIF (S.class=Texts.Char) & (S.c="@") & (time # -1) THEN
			cc:=end - beg; Count(text, beg, end, wc, pc, ec); done := TRUE
		END;
		IF done THEN
			Plural(pc, "CR"); Texts.WriteString(W, ", "); Plural(wc, "word"); Texts.WriteString(W, ", ");
			Plural(cc, "char"); Texts.WriteString(W, ", ");
			Plural(ec, "object"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END
	END Words;

	(** Show attributes of selected text *)
	PROCEDURE ShowAttrs*;	(** "^" **)
		VAR
			T: Texts.Text;
			beg, end, time: SIGNED32;
			R: Texts.Reader;
			gen: ARRAY 64 OF CHAR;
			obj: Objects.Object;
			lib: Objects.Library;
			col, voff: SIGNED8;
			ch: CHAR;

		PROCEDURE Voff (obj: Objects.Object): SIGNED16;
		VAR A: Objects.AttrMsg;
		BEGIN
			A.id := Objects.get; A.name := "LineupHY"; A.class := Objects.Inval; A.res := -1;
			obj.handle(obj, A);
			IF (A.res >= 0) & (A.class = Objects.Int) THEN RETURN -SHORT(A.i)
			ELSE RETURN 0
			END
		END Voff;

	BEGIN
		Oberon.GetSelection(T, beg, end, time);
		IF (time # -1) & (T # NIL) THEN
			lib := NIL; col := MIN(SIGNED8); voff := MIN(SIGNED8);
			Texts.OpenReader(R, T, beg);
			Texts.Read(R, ch);
			WHILE ~R.eot & (beg <= end) DO
				IF (R.lib # lib) OR (col # R.col) OR (voff # R.voff) THEN
					lib := R.lib; col := R.col; voff := R.voff;
					Texts.WriteInt(W, beg, 6); Texts.Write(W, 09X);
					IF lib IS Fonts.Font THEN
						Texts.WriteString(W, lib.name)
					ELSE
						lib.GetObj(lib, ORD(ch), obj);
						IF lib.name # "" THEN
							Texts.WriteString(W, lib.name);
							Texts.Write(W, ".");
							Attributes.GetString(obj, "Name", gen);
							Texts.WriteString(W, gen)
						ELSE
							Texts.WriteString(W, "(private)")
						END;
						Texts.Write(W, 09X);
						Attributes.GetString(obj, "Gen", gen);
						Texts.WriteString(W, gen);
						voff := SHORT(Voff(obj))
					END;
					Texts.Write(W, 09X);
					Texts.WriteInt(W, col, 3); Texts.Write(W, 09X);
					Texts.WriteInt(W, voff, 3);
					Texts.WriteLn(W)
				END;
				Texts.Read(R, ch); INC(beg)
			END;
			Texts.Append(Oberon.Log, W.buf)
		END
	END ShowAttrs;

	(** Show position of selected text *)
	PROCEDURE ShowPos*;	(** "^" **)
		VAR T: Texts.Text; beg, end, time: SIGNED32;
	BEGIN
		Oberon.GetSelection(T, beg, end, time);
		IF (time # -1) & (T # NIL) THEN
			Texts.WriteString(W, "text selected from "); Texts.WriteInt(W, beg, 0);
			Texts.WriteString(W, " to "); Texts.WriteInt(W, end, 0);
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END
	END ShowPos;

(** EditTools.LocateLine ^ *)
	PROCEDURE LocateLine*;
		VAR
			S: Attributes.Scanner;
			C: Oberon.CaretMsg;
			line: SIGNED32;
			T: Texts.Text;
			beg, end, time: SIGNED32;
			R: Texts.Reader;
			ch: CHAR;
	BEGIN
		Oberon.GetSelection(T, beg, end, time);
		IF (T # NIL) & (time # -1) THEN
			Attributes.OpenScanner(S, T, beg); Attributes.Scan(S);
			IF S.class = Attributes.Int THEN
				line := S.i;
				C.F := Oberon.MarkedFrame();
				C.text := Oberon.MarkedText();
				IF (C.text # NIL) & (C.F # NIL) THEN
					Texts.OpenReader(R, C.text, 0); Texts.Read(R, ch);
					WHILE ~R.eot & (line > 1) DO
						IF ch = Strings.CR THEN
							DEC(line); Texts.Read(R, ch);
							IF ch = Strings.LF THEN
								Texts.Read(R, ch)
							END
						ELSE
							Texts.Read(R, ch)
						END
					END;
					C.car := C.F; C.id := Oberon.set; C.pos := Texts.Pos(R)-1; C.res := -1;
					Display.Broadcast(C)
				END
			END
		END
	END LocateLine;

BEGIN Texts.OpenWriter(W); Texts.OpenWriter(WR);
END EditTools.
