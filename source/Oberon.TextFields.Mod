(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE TextFields IN Oberon; (** portable *)	(* jm 16.11.95 *)

(** Module TextFields implements text captions and textfields. *)

(*
	JM 4.2.93 - Textfields sends update message down
	jm 9.2.93 - correct response on Viewers.ViewerMsg
	jm 11.2.93 - Display.ControlMsg
	jm 22.2.93 - ConsumeText corrected
	13.4.93 - takes no focus if unmoveable
	5.4.94 - selection is returned in full
	2.5.94 - Added Lineup for TF
	2.5.94 - Fixed Tab'ing
	27.5.94 - Added vertical offsets to captions
		The text captions are a complete hack due to the wrong placement of the optimizations (kr).
		They should be rewritten.
	15.11.94 - InsertObj deleted
	6.12.94 - Can set textcaptions with link message
	2.1.95 - replaced the text captions with completely new implementation
	23.2.95 - fixed caption focus when no contents
	19.4.95 - added delete right support for TF
	15.5.95 - fixed empty string delete in TF
	26.10.95 - added scrolling support to TextFields
	16.11.95 - Fixed copy of selected caption in panel
	12.12.95 - tk added underlined attribute
	22.4.97 - ps added Font attribute
	16.3.2005 - ph; captions are now automatically resizable when used with an organizer panel or button and given
					Constraints in relative notation (  -1.0 <= .. <= 1.0  see Organizer.Mod).
					Automatic resizing works only if  ~ ({Gagets.lockedsize} IN caption.state) .
	19.3.05 - ph TextFields now
							- can change their Font
							- can change their Font Color
							- can adapt their Font size on TextField resizing
*)

IMPORT
	Objects, Gadgets, Display, Display3, Effects, Oberon, Texts, Files, Input, Printer, Printer3, Fonts, Attributes, Strings, Colors;

CONST
	MaxLen = 256; CarHeight = 14; CarWidth = 2; Yoffset = 2 (*5*); Xoffset = 5;

TYPE
	(** Captions for displaying a text. *)
	Caption* = POINTER TO CaptionDesc;
	CaptionDesc* = RECORD (Gadgets.FrameDesc)
		focused*,	(** Has the keyboard focus or not ? *)
		underlined*: BOOLEAN;	(** Is text underlined ? *)
		text*: Texts.Text;	(** Displayed Text. *)
		time: SIGNED32;
	END;

	TextField* = POINTER TO TextFieldDesc;
	TextFieldDesc* = RECORD (Gadgets.FrameDesc)
		selbeg*, selend*: SIGNED16;	(** Starting and ending position of selected characters [selbeg, selend). *)
		time*: SIGNED32;	(** Selection time. *)
		carpos*, carx*, cary*: SIGNED16;	(** Caret position and relative coordinates. *)
		val*: ARRAY MaxLen OF CHAR;	(** Current value. *)
		font*:Fonts.Font;
		textcol*:SIGNED16;
		consistent*: BOOLEAN;	(** Is the textfield consistent with its model value ? *)
		col*: SIGNED16;	(** Background color. *)
		start: SIGNED16;
		topC,bottomC:SIGNED16;
	END;

	TextFieldUpdateMsg = RECORD (Gadgets.UpdateMsg)
		beg: SIGNED32;
	END;

	PassFocusMsg = RECORD (Display.FrameMsg)
		X, Y, foundX, foundY: SIGNED16;
		from, to: TextField
	END;

VAR
	W: Texts.Writer;
	invTF: SIGNED16; (* focus & selection color for text fields *)
	linebuf: ARRAY 256 OF SIGNED16;
	lastfont, lastlib: Fonts.Font;

PROCEDURE ForceString(F: Display.Frame; VAR M: Objects.AttrMsg);
BEGIN Gadgets.framehandle(F, M);
	IF M.res < 0 THEN M.class := Objects.String; M.s := ""; M.res := 0 END
END ForceString;

(* ------------------------- CAPTIONS ---------------------- *)

PROCEDURE Max(x, y: SIGNED16): SIGNED16;
BEGIN IF x > y THEN RETURN x; ELSE RETURN y; END;
END Max;

PROCEDURE Min(x, y: SIGNED16): SIGNED16;
BEGIN IF x < y THEN RETURN x; ELSE RETURN y; END;
END Min;

(* lookup the size of a character on the printer *)
PROCEDURE Lookup(L: Fonts.Font; ch: CHAR; VAR minY, maxY, dx: SIGNED16);
VAR obj: Objects.Object; metric: Fonts.Font;

	PROCEDURE Dev(x: SIGNED16): SIGNED16;
	BEGIN RETURN SHORT(LONG(x) * Display.Unit DIV Printer.Unit)
	END Dev;

BEGIN
	IF L = lastfont THEN metric := lastlib
	ELSE
		metric := Printer.GetMetric(L);
		lastlib := metric; lastfont := L
	END;
	IF metric # NIL THEN
		metric.GetObj(metric, ORD(ch), obj);
		WITH obj: Fonts.Char DO minY := metric.minY; maxY := metric.maxY; dx := obj.dx END
	ELSE (* scale display font *)
		L.GetObj(L, ORD(ch), obj);
		WITH obj: Fonts.Char DO
			minY := Dev(L.minY); maxY := Dev(L.maxY); dx := Dev(obj.dx)
		END
	END;
END Lookup;

PROCEDURE GetFont (T: Texts.Text; VAR font: ARRAY OF CHAR);
VAR lib: Objects.Library; R: Texts.Reader; ch: CHAR;
BEGIN
	Texts.OpenReader(R, T, 0); Texts.Read(R, ch); lib := R.lib;
	WHILE ~R.eot & (R.lib = lib) DO Texts.Read(R, ch) END;
	IF ~R.eot THEN COPY("mixed", font)
	ELSIF lib = NIL THEN COPY(Fonts.Default.name, font)
	ELSE COPY(lib.name, font)
	END
END GetFont;

		(*Following 5 procedures are Copy/Paste from EditTools Mod; to keep current module load order*)

	PROCEDURE IsFont(lib: Objects.Library): BOOLEAN;
	BEGIN RETURN (lib # NIL) & (lib IS Fonts.Font)
	END IsFont;

	PROCEDURE ThisFont(name: ARRAY OF CHAR): Fonts.Font;
		VAR fnt: Fonts.Font;
	BEGIN
		fnt := Fonts.This(name);
		IF (fnt = Fonts.Default) & (fnt.name # name) THEN RETURN NIL
		ELSE RETURN fnt
		END
	END ThisFont;

		PROCEDURE SplitFontName (fn: ARRAY OF CHAR; VAR i, j, size: SIGNED16);
		(*Copy/Paste from EditTools Mod; to keep current module load order*)
		VAR k: SIGNED16;
	BEGIN i := 0; size := 0;
		WHILE (fn[i] # 0X) & ((fn[i] < "0") OR ("9" < fn[i])) DO INC(i) END;
		j := i; WHILE ("0" <= fn[j]) & (fn[j] <= "9") DO INC(j) END;
		k := i; WHILE k < j DO size := size * 10 + ORD(fn[k]) - 30H; INC(k) END
	END SplitFontName;

	PROCEDURE CombineFontName (prefix, suffix: ARRAY OF CHAR; i, j, size: SIGNED16; VAR fn: ARRAY OF CHAR);
		VAR k: SIGNED16; ch: CHAR; dig: ARRAY 10 OF CHAR;
	BEGIN COPY(prefix, fn); k := 0;
		IF size < 6 THEN size := 6 ELSIF size > 128 THEN size := 128 END;
		REPEAT dig[k] := CHR(size MOD 10 + 30H); size := size DIV 10; INC(k) UNTIL size = 0;
		REPEAT DEC(k); fn[i] := dig[k]; INC(i) UNTIL k = 0;
		REPEAT ch := suffix[j]; fn[i] := ch; INC(i); INC(j) UNTIL ch = 0X
	END CombineFontName;

PROCEDURE IncFontSize (T: Texts.Text; beg, end: SIGNED32; delta: SIGNED16);
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


(** Calculate the size and # of lines of caption. If displayspace then the size on the display is returned (adjusted according to the size on the printer) and if not, the size in printer pixels is returned. *)
PROCEDURE CalcSize*(F: Caption; VAR W, H, nolines: SIGNED16; displayspace: BOOLEAN);
VAR R: Texts.Reader; ch: CHAR;
	linew, dsr, asr, lineh, top: SIGNED16;	(* for display *)
	plinew, pdsr, pasr, pdx, plineh, d, a, pW, pH: SIGNED16;	(* for printer *)
	obj: Objects.Object; fnt, lastfnt: Fonts.Font;
BEGIN
	IF F.text.len = 0 THEN W := 5; H := 5; nolines := 0;
	ELSE
		W := 0; H := 0; pW := 0; pH := 0;
		lastfnt := NIL; nolines := 0; top := 0;
		Texts.OpenReader(R, F.text, 0); Texts.Read(R, ch);
		linew := 0; lineh := 0; asr := 0; dsr := 0;
		plinew := 0; plineh := 0; pasr := 0; pdsr := 0;
		WHILE ~R.eot DO
			IF R.lib IS Fonts.Font THEN
				fnt := R.lib(Fonts.Font); fnt.GetObj(fnt, ORD(ch), obj);
				WITH obj: Fonts.Char DO
					INC(linew, obj.dx);
					Lookup(fnt, ch, d, a, pdx); INC(plinew, pdx);
					IF fnt # lastfnt THEN
						dsr := Max(dsr, -fnt.minY); asr := Max(asr, fnt.maxY);
						lineh := dsr + asr;

						pdsr := Max(pdsr, ABS(d)); pasr := Max(pasr, a);
						plineh := pdsr + pasr;
						lastfnt := fnt
					END;

					IF ch = 0DX THEN
						IF displayspace THEN DEC(top, asr); linebuf[nolines] := top; DEC(top, dsr);
						ELSE DEC(top, pasr); linebuf[nolines] := top; DEC(top, pdsr)
						END;
						INC(nolines); INC(H, lineh); INC(pH, plineh);
						IF linew > W THEN W := linew END;
						IF plinew > pW THEN pW := plinew END;
						asr := 0; dsr := 0; lineh := 0; linew := 0;
						pasr := 0; pdsr := 0; plineh := 0; plinew := 0;
						IF nolines = LEN(linebuf) THEN RETURN END;
						lastfnt := NIL
					END
				END
			END;
			Texts.Read(R, ch)
		END;
		IF displayspace THEN DEC(top, asr); linebuf[nolines] := top; DEC(top, dsr);
		ELSE DEC(top, pasr); linebuf[nolines] := top; DEC(top, pdsr)
		END;
		INC(nolines); INC(H, lineh); INC(pH, plineh);
		IF linew > W THEN W := linew END;
		IF plinew > pW THEN pW := plinew END;

		IF displayspace THEN
			pW := SHORT(ENTIER(LONG(pW) * Printer.Unit/Display.Unit) + 1);
			pH := SHORT(ENTIER(LONG(pH) * Printer.Unit/Display.Unit) + 1);
			IF pW > W THEN W := pW END;
			IF pH > H THEN H := pH END;
		ELSE
			W := pW; H := pH
		END
	END
END CalcSize;

PROCEDURE Update(F: Caption);
VAR A: Display.ModifyMsg; nolines: SIGNED16;
BEGIN
	CalcSize(F, A.W, A.H, nolines, TRUE);
	A.id := Display.move;
	A.F := F; A.X := F.X; A.Y := F.Y + F.H - A.H;
	A.dX := A.X - F.X; A.dY := A.Y - F.Y; A.dH := A.H - F.H; A.dW := A.W - F.W;
	IF (A.dX # 0) OR (A.dY # 0) OR (A.dW # 0) OR (A.dH # 0) THEN
		A.mode := Display.display; Display.Broadcast(A);
		IF (F.W # A.W) OR (F.H # A.H) THEN
			F.W := A.W; F.H := A.H; F.mask := NIL
		END;
	ELSE Gadgets.Update(F);
	END;
END Update;

PROCEDURE RestoreCaption(F: Caption; M: Display3.Mask; x, y, w, h: SIGNED16);
VAR X, X0, Y, W, H, nolines, i: SIGNED16; R: Texts.Reader; ch: CHAR; obj: Objects.Object; fnt: Fonts.Font;
BEGIN
	IF F.text.len = 0 THEN
		IF F.focused THEN
			Display3.Rect(M, Display3.red, Display.solid, x, y, w, h, 1, Display.replace);
			Display3.ReplConst(M, Display.BG, x+1, y+1, w-2, h-2, Display.replace)
		ELSE
			Display3.Rect(M, Display.FG, Display.solid, x, y, w, h, 1, Display.replace)
		END
	ELSE
		IF F.focused THEN
			Display3.Rect(M, Display3.red, Display.solid, x, y, w, h, 1, Display.replace);
			Display3.ReplConst(M, Display.BG, x+1, y+1, w-2, h-2, Display.replace)
		END;
		CalcSize(F, W, H, nolines, TRUE);
		X := x; Y := y + h + linebuf[0]; i := 1;
		X0 := X;
		Texts.OpenReader(R, F.text, 0);
		Texts.Read(R, ch);
		WHILE ~R.eot & (i # LEN(linebuf)) DO
			IF R.lib IS Fonts.Font THEN
				fnt := R.lib(Fonts.Font); fnt.GetObj(fnt, ORD(ch), obj);
				WITH obj: Fonts.Char DO
					IF ch = 0DX THEN
						IF F.underlined THEN
							Display3.Line(M, 15, Display.grey1, X0-1, Y+fnt.minY, X+1, Y+fnt.minY, 1, Display.replace)
						END;
						Y := y + h + linebuf[i]; INC(i);
						X := x; X0 := X
					ELSE
						Display3.CopyPattern(M, R.col, obj.pat, X + obj.x, Y + obj.y, Display3.textmode);
						INC(X, obj.dx)
					END
				END
			END;
			Texts.Read(R, ch)
		END;
		IF F.underlined & (X0 # X) THEN
			Display3.Line(M, 15, Display.grey1, X0-1, Y+fnt.minY, X+1, Y+fnt.minY, 1, Display.replace)
		END
	END;
	IF Gadgets.selected IN F.state THEN
		Display3.FillPattern(M, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint)
	END
END RestoreCaption;

PROCEDURE CaptionAttributes(F: Caption; VAR M: Objects.AttrMsg);
VAR str: ARRAY 256 OF CHAR;
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN M.class := Objects.String; COPY("TextFields.NewCaption", M.s); M.res := 0
		ELSIF M.name = "Value" THEN Attributes.TxtToStr(F.text, M.s); M.class := Objects.String; M.res := 0
		ELSIF M.name = "LineupHY" THEN M.class := Objects.Int; M.i := ABS(Fonts.Default.minY)+1; M.res := 0
		ELSIF M.name = "Cmd" THEN
			Gadgets.framehandle(F, M);
			IF M.res < 0 THEN (* no such attribute, simulate one *)
				M.class := Objects.String; M.s := ""; M.res := 0;
			END
		ELSIF M.name = "Underlined" THEN M.class := Objects.Bool; M.b:=F.underlined; M.res :=0
		ELSIF M.name = "Font" THEN
			M.class := Objects.String; GetFont(F.text, M.s); M.res :=0
		ELSE Gadgets.framehandle(F, M)
		END
	ELSIF M.id = Objects.set THEN
		IF M.name = "Value" THEN
			IF M.class = Objects.String THEN
				Attributes.TxtToStr(F.text, str);
				IF str # M.s THEN
					GetFont(F.text, str);
					Attributes.StrToTxt(M.s, F.text);
					IF str # "mixed" THEN Texts.ChangeLooks(F.text, 0, F.text.len, {0}, Fonts.This(str), 0, 0) END;
					Update(F)
				END;
				M.res := 0
			END
		ELSIF M.name = "Color" THEN
			IF M.class = Objects.Int THEN
				Texts.ChangeLooks(F.text, 0, F.text.len, {1}, NIL, SHORT(SHORT(M.i)), 0); M.res := 0
			END;
		ELSIF M.name = "Underlined" THEN
			IF M.class = Objects.Bool THEN
				IF M.b THEN F.underlined := TRUE ELSE F.underlined := FALSE END;
				M.res := 0
			END
		ELSIF M.name = "Font" THEN
			IF M.class = Objects.String THEN
				IF M.s # "mixed" THEN Texts.ChangeLooks(F.text, 0, F.text.len, {0}, Fonts.This(M.s), 0, 0) END;
				M.res :=0
			END
		ELSE
			Gadgets.framehandle(F, M);
		END
	ELSIF M.id = Objects.enum THEN
		M.Enum("Value"); M.Enum("Font"); M.Enum("Cmd"); M.Enum("Underlined"); Gadgets.framehandle(F, M)
	END;
END CaptionAttributes;

PROCEDURE PrintCaption(F: Caption; VAR M: Display.DisplayMsg);
VAR Q: Display3.Mask; X, X0, Y, W, H, nolines, i: SIGNED16; R: Texts.Reader; ch: CHAR;
	fnt: Fonts.Font; d, pdx: SIGNED16;

	(* buffer stuff *)
	buf: ARRAY 1024 OF CHAR; bufpos, bufx, bufy: SIGNED16;
	lastfnt: Fonts.Font; lastcol: SIGNED16;

	PROCEDURE P(x: SIGNED16): SIGNED16;
	BEGIN RETURN SHORT(x * Display.Unit DIV Printer.Unit)
	END P;

	PROCEDURE InitBuf;
	BEGIN bufpos := 0; lastfnt := NIL; lastcol := -1
	END InitBuf;

	PROCEDURE FlushBuf;
	BEGIN
		IF bufpos > 0 THEN
			buf[bufpos] := 0X;
			Printer3.String(Q, lastcol, bufx, bufy, lastfnt, buf, Display.paint);
			bufpos := 0; lastfnt := NIL
		END
	END FlushBuf;

	PROCEDURE WriteChar(fnt: Fonts.Font; col: SIGNED16; ch: CHAR);
	BEGIN
		IF (fnt # lastfnt) OR (col # lastcol) THEN
			FlushBuf;
			lastcol := col; lastfnt := fnt;
			bufx := X; bufy := Y;
		END;
		buf[bufpos] := ch; INC(bufpos);
	END WriteChar;

BEGIN
	Gadgets.MakePrinterMask(F, M.x, M.y, M.dlink, Q);
	CalcSize(F, W, H, nolines, FALSE);

	X := M.x; Y := M.y + P(F.H) + linebuf[0]; i := 1;
	X0 := X;

	InitBuf;

	Texts.OpenReader(R, F.text, 0);
	Texts.Read(R, ch);
	WHILE ~R.eot DO
		IF R.lib IS Fonts.Font THEN
			fnt := R.lib(Fonts.Font);
			IF ch = 0DX THEN
				FlushBuf;
				IF F.underlined THEN
					Printer3.Line(Q, 15, Display.grey1, X0-1, Y+fnt.minY, X+1, Y+fnt.minY, 1, Display.replace)
				END;
				Y := M.y + P(F.H) + linebuf[i]; INC(i);
				X := M.x; X0 := X
			ELSE
				WriteChar(fnt, R.col, ch);
				Lookup(fnt, ch, d, d, pdx);
				INC(X, pdx)
			END
		END;
		Texts.Read(R, ch)
	END;
	FlushBuf;
	IF F.underlined & (X0 # X) THEN
		Printer3.Line(Q, 15, Display.grey1, X0-1, Y+fnt.minY, X+1, Y+fnt.minY, 1, Display.replace)
	END
END PrintCaption;

PROCEDURE CopyCaption* (VAR M: Objects.CopyMsg; from, to: Caption);
VAR B: Texts.Buffer;
BEGIN
	Gadgets.CopyFrame(M, from, to); to.focused := FALSE; to.underlined := from.underlined;
	NEW(to.text); Texts.Open(to.text, "");
	IF from.text.len > 0 THEN
		NEW(B); Texts.OpenBuf(B); Texts.Save(from.text, 0, from.text.len, B); Texts.Append(to.text, B);
	END;
END CopyCaption;

PROCEDURE ResizeCaptionToFit* (VAR caption:Caption;newW,newH:SIGNED16);
VAR w,h,nolines,oldw,oldh:SIGNED16; A:Objects.AttrMsg;
		t:Texts.Text;
BEGIN
	IF caption=NIL THEN RETURN END;
	A.id:=Objects.get; COPY("Constraints",A.name); A.res:=-1; A.class:=Objects.String; Gadgets.framehandle(caption,A);
	IF A.res<0 THEN RETURN END;
	CalcSize(caption,oldw,oldh,nolines,TRUE);
	t:=caption.text;
	IF (newH=oldh) THEN RETURN
	ELSIF (newH<oldh) OR (newW<oldw)  THEN (*not yet fully handled: grow in X/ shrink in Y ... *)
		REPEAT
			oldw:=w; oldh:=h;
				(*temporarily remove caption text from display space because
					IncFontSize->Text.ChangeLooks destroys as side effect the correct Gadgets.link list order
					and sends unnessesary update messages*)
			caption.text:=NIL; IncFontSize(t,0,t.len,-1); caption.text:=t;
			CalcSize(caption,w,h,nolines,TRUE);
		UNTIL  ((h<newH) & (w<newW)) OR ((w=oldw)&(h=oldh)); 	(*overshooting a little or no progress (no more fonts...) *)
		IF ~ ((w=oldw)&(h=oldh)) THEN caption.text:=NIL; IncFontSize(t,0,t.len,1); caption.text:=t; (*step back*)
		END;
	ELSE
		REPEAT
			oldw:=w; oldh:=h;
			caption.text:=NIL; IncFontSize(t,0,t.len, 1); caption.text:=t;
			CalcSize(caption,w,h,nolines,TRUE);
		UNTIL (h >newH)  OR (w >newW) OR ((w=oldw)&(h=oldh));  (*overshooting a little or no progress (no more fonts...) *)
		IF ~ ((w=oldw)&(h=oldh)) THEN  caption.text:=NIL; IncFontSize(t,0,t.len,-1); caption.text:=t; (*step back*)
		END
	END;
	caption.W:=newW; caption.H:=newH;
END ResizeCaptionToFit;

PROCEDURE ConsumeCh(F: Caption; ch: CHAR; fnt: Objects.Library; col, voff: SIGNED8);
VAR R: Texts.Reader; chr: CHAR;
BEGIN
	IF ch = 7FX THEN	(* DEL *)
		IF F.text.len > 0 THEN Texts.Delete(F.text, F.text.len-1, F.text.len) END
	ELSIF (ch >= " ") OR (ch = 09X) OR (ch = 0DX) THEN
		IF F.text.len > 0 THEN
			Texts.OpenReader(R, F.text, F.text.len - 1);
			Texts.Read(R, chr);
			IF (R.lib # NIL) & (R.lib IS Fonts.Font) THEN fnt := R.lib; col := R.col END
		END;
		Texts.SetFont(W, fnt); Texts.SetColor(W, col); Texts.SetOffset(W, voff); Texts.Write(W, ch);
		Texts.Append(F.text, W.buf)
	END
END ConsumeCh;

PROCEDURE LoadCaption(F: Caption; VAR M: Objects.FileMsg);
VAR ver, len: SIGNED32; chr: CHAR; name: ARRAY 256 OF CHAR; i, col: SIGNED16;
	fnt: Objects.Library; ch: CHAR;
BEGIN
	Files.ReadNum(M.R, ver);
	IF (ver = 4) OR (ver = 5) THEN
		IF ver = 5 THEN Files.ReadNum(M.R, ver); F.underlined:=(ver=1) END;
		Files.Read(M.R, chr); (* read TextBlockId *)
		IF chr # Texts.TextBlockId THEN HALT(99) END;
		Texts.Load(F.text, Files.Base(M.R), Files.Pos(M.R), len);
		Files.Set(M.R, Files.Base(M.R), Files.Pos(M.R)+len);
		Gadgets.framehandle(F, M);
	ELSIF (ver = 2) OR (ver = 3) THEN
		Files.Read(M.R, chr); (* read TextBlockId *)
		IF (chr = 01X) OR (chr = Texts.TextBlockId) THEN
			Texts.Load(F.text, Files.Base(M.R), Files.Pos(M.R), len);
			Files.Set(M.R, Files.Base(M.R), Files.Pos(M.R)+len);
			Gadgets.framehandle(F, M);
		ELSIF chr = 02X THEN
			Gadgets.framehandle(F, M);
			 IF ver = 3 THEN Files.ReadInt(M.R, col) ELSE col := Display.FG END;
			Files.ReadInt(M.R, i); Objects.GetName(F.lib.dict, i, name);
			(* IF name = "Elektra.Scn.Fnt" THEN name := "Electra.Scn.Fnt" END; *)
			fnt := Objects.ThisLibrary(name);
			Texts.SetFont(W, fnt); Texts.SetColor(W, SHORT(col));

			i := 0; Files.Read(M.R, ch);
			WHILE ch # 0X DO Texts.Write(W, ch); Files.Read(M.R, ch) END;
			Texts.Append(F.text, W.buf);
			Texts.SetFont(W, Fonts.Default); Texts.SetColor(W, Display.FG);
			F.state := F.state + {Gadgets.transparent, Gadgets.lockedsize};
		ELSE HALT(99)
		END
	ELSE HALT(99)
	END
END LoadCaption;

PROCEDURE CaptionHandler* (F: Objects.Object; VAR M: Objects.ObjMsg);
VAR x, y, w, h: SIGNED16; F1: Caption; Q: Display3.Mask; keysum: SET;
	text: Texts.Text; tbeg, tend, time: SIGNED32; R: Texts.Reader; buf: Texts.Buffer; ch: CHAR;
	len: SIGNED32;
BEGIN
	WITH F: Caption DO
		IF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF (M.F = NIL) OR (M.F = F) THEN (* message addressed to box *)
					x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H;
					IF M IS Display.DisplayMsg THEN
						WITH M: Display.DisplayMsg DO
							IF M.device = Display.screen THEN
								IF (M.id = Display.full) OR (M.F = NIL) THEN
									ResizeCaptionToFit(F,F.W,F.H);
									Gadgets.MakeMask(F, x, y, M.dlink, Q);
									RestoreCaption(F, Q, x, y, w, h)
								ELSIF M.id = Display.area THEN
									ResizeCaptionToFit(F,F.W,F.H);
									Gadgets.MakeMask(F, x, y, M.dlink, Q);
									Display3.AdjustMask(Q, x + M.u, y + h - 1 + M.v, M.w, M.h);
									RestoreCaption(F, Q, x, y, w, h)
								END
							ELSIF M.device = Display.printer THEN PrintCaption(F, M)
							END
						END
					ELSIF M IS Oberon.InputMsg THEN
						WITH M: Oberon.InputMsg DO
							IF (M.id = Oberon.consume) & (F.focused) THEN
								ConsumeCh(F, M.ch, M.fnt, M.col, M.voff); M.res := 0;
							ELSIF (M.id = Oberon.track) & (M.keys = {2}) & Effects.Inside(M.X, M.Y, x, y, w, h) THEN
								keysum := M.keys;
								REPEAT Effects.TrackMouse(M.keys, M.X, M.Y, Effects.Arrow); keysum := keysum + M.keys
								UNTIL M.keys = {};
								M.res := 0;
								IF keysum = {2, 0} THEN (* copy style over *)
									Oberon.GetSelection(text, tbeg, tend, time);
									IF time # -1 THEN
										Texts.OpenReader(R, F.text, 0); Texts.Read(R, ch);
										Texts.ChangeLooks(text, tbeg, tend, {0, 1, 2}, R.lib, R.col, R.voff);
									END;
								ELSIF keysum = {2, 1} THEN (* copy from selection *)
									Oberon.GetSelection(text, tbeg, tend, time);
									IF time # -1 THEN
										NEW(buf); Texts.OpenBuf(buf);
										Texts.Save(text, tbeg, tend, buf);
										Texts.Insert(F.text, F.text.len, buf);
									END;
								ELSIF ~F.focused & ~Gadgets.IsLocked(F, M.dlink) THEN Oberon.Defocus;
									F.focused := TRUE; Gadgets.Update(F);
								END;
							ELSIF ~(Gadgets.selected IN F.state) THEN Gadgets.framehandle(F, M)
							END
						END
					ELSIF M IS Texts.UpdateMsg THEN
						WITH M : Texts.UpdateMsg DO
							IF (M.text = F.text) THEN Update(F); END;
						END
				ELSIF M IS Oberon.SelectMsg THEN
						WITH M: Oberon.SelectMsg DO
							IF (M.id = Oberon.get) & (Gadgets.selected IN F.state) & (F.time > M.time) THEN
								M.text := F.text; M.beg := 0; M.end := F.text.len; M.time := F.time;
							END
						END
					ELSIF M IS Oberon.ConsumeMsg THEN
						WITH M: Oberon.ConsumeMsg DO
							IF F.focused THEN
								NEW(buf); Texts.OpenBuf(buf);
								Texts.Save(M.text, M.beg, M.end, buf); Texts.Append(F.text, buf); M.res := 0;
							END
						END
					ELSIF M IS Oberon.ControlMsg THEN
						WITH M: Oberon.ControlMsg DO
							IF F.focused & ((M.id = Oberon.defocus) OR (M.id = Oberon.neutralize)) THEN
								F.focused := FALSE; Gadgets.Update(F)
							END
						END
					ELSIF M IS Display.SelectMsg THEN
						WITH M: Display.SelectMsg DO
							IF M.id = Display.set THEN F.time := Oberon.Time()-1 ELSE F.time := -1 END;
							Gadgets.framehandle(F, M);
						END
					ELSIF M IS Display.ControlMsg THEN
						WITH M: Display.ControlMsg DO
							IF M.id = Display.newprinter THEN
								lastfont := NIL; lastlib := NIL
							END
						END
					ELSIF M IS Display.ModifyMsg THEN
						WITH M:Display.ModifyMsg DO
							IF M.F=F THEN ResizeCaptionToFit(F,M.W,M.H); END;
							Gadgets.framehandle(F,M);
						END;
					ELSE Gadgets.framehandle(F, M)
					END
				END
			END
		ELSIF M IS Objects.AttrMsg THEN
			CaptionAttributes(F, M(Objects.AttrMsg));
		ELSIF M IS Objects.LinkMsg THEN
			WITH M: Objects.LinkMsg DO
				IF M.id = Objects.get THEN
					IF M.name = "Model" THEN M.obj := F.text; M.res := 0
					ELSE Gadgets.framehandle(F, M)
					END
				ELSIF M.id = Objects.set THEN
					IF (M.name = "Model") & (M.obj IS Texts.Text) THEN F.text := M.obj(Texts.Text); M.res := 0;
						Update(F);
					ELSE Gadgets.framehandle(F, M)
					END
				ELSE Gadgets.framehandle(F, M)
				END
			END
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN
					Files.WriteNum(M.R, 5);
					IF F.underlined THEN Files.WriteNum(M.R, 1) ELSE Files.WriteNum(M.R, 0) END;
					Texts.Store(F.text, Files.Base(M.R), Files.Pos(M.R), len);
					Files.Set(M.R, Files.Base(M.R), Files.Pos(M.R) + len);
					Gadgets.framehandle(F, M)
				ELSIF M.id = Objects.load THEN LoadCaption(F, M);
					CalcSize(F, F.W, F.H, x, TRUE);
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN M.obj := F.dlink (*non-first arrival*)
				ELSE (*first arrival*)
					NEW(F1); F.stamp := M.stamp; F.dlink := F1; CopyCaption(M, F, F1); M.obj := F1
				END
			END
		ELSE Gadgets.framehandle(F, M)
		END
	END
END CaptionHandler;

(** initialize caption F with text T. *)
PROCEDURE InitCaption* (F: Caption; T: Texts.Text);
VAR nolines: SIGNED16;
BEGIN F.state := {Gadgets.transparent (*, Gadgets.lockedsize*)};
	F.text := T;
	IF T.len = 0 THEN F.W := 5; F.H := 5
	ELSE CalcSize(F, F.W, F.H, nolines, TRUE)
	END;
	F.handle := CaptionHandler
END InitCaption;

(** Makes a caption out of the text object found in Objects.NewObj, returning the result in Objects.NewObj.. *)
PROCEDURE MakeCaption*;
VAR F: Caption; T: Texts.Text;
BEGIN
	NEW(F); F.H := 5; F.W := 5; F.handle := CaptionHandler;
	IF (Objects.NewObj # NIL) & (Objects.NewObj IS Texts.Text) THEN
		T := Objects.NewObj(Texts.Text);
	ELSE NEW(T); Texts.Open(T, "");
	END;
	InitCaption(F, T);
	F.focused := TRUE; Objects.NewObj := F;
END MakeCaption;

PROCEDURE NewCaption*;
VAR F: Caption; T: Texts.Text;
BEGIN NEW(F);
	NEW(T); Texts.Open(T, "");
	InitCaption(F, T); Objects.NewObj := F
END NewCaption;

(* ------------------------- TEXTFIELDS ---------------------- *)

PROCEDURE Length(VAR S: ARRAY OF CHAR): SIGNED16;
VAR p: SIGNED16;
BEGIN
	p := 0; WHILE S[p] # 0X DO INC(p); END; RETURN p
END Length;

PROCEDURE InsertChar(VAR S: ARRAY OF CHAR; pos: SIGNED16; ch: CHAR);
VAR len, p: SIGNED16;
BEGIN
	len := Length(S);
	IF pos > len THEN pos := len ELSIF pos < 0 THEN pos := 0 END;
	IF len < LEN(S)-1 THEN (* space left *)
		p := len; S[len + 1] := 0X;
		WHILE p > pos DO S[p] := S[p-1]; DEC(p); END;
		S[pos] := ch;
	END
END InsertChar;

PROCEDURE DeleteChar(VAR S: ARRAY OF CHAR; pos: SIGNED16);
VAR len, p: SIGNED16;
BEGIN
	len := Length(S);
	IF pos > len THEN pos := len ELSIF pos < 0 THEN pos := 0 END;
	IF (pos < LEN(S)) & (len > 0) THEN
		p := pos; WHILE S[p] # 0X DO S[p] := S[p+1]; INC(p); END;
	END
END DeleteChar;

PROCEDURE Delete(VAR S: ARRAY OF CHAR; beg, end: SIGNED16); (* [beg, end) *)
VAR len, p: SIGNED16;
BEGIN
	IF beg < 0 THEN beg := 0 END;
	len := Length(S); IF end > len THEN end := len END;
	p := end;
	WHILE p <= len DO S[beg] := S[p]; INC(beg); INC(p) END
END Delete;

(* --- passing of the focus to the next textfield --- *)

PROCEDURE Pass(F: TextField; dlink: Objects.Object);
VAR M: PassFocusMsg;
BEGIN
	IF dlink # NIL THEN
		(* determine my coordinates *)
		M.F := F; M.x := 0; M.y := 0; M.dlink := NIL; M.X := 0; M.Y := 0; M.from := F; M.to := NIL; M.res := -1;
		dlink.handle(dlink, M); (* sets M.X, M.X *)

		M.F := NIL; M.x := 0; M.y := 0; M.dlink := NIL; (*M.X := F.X; M.Y := F.Y; *) M.from := F; M.to := NIL; M.res := -1;
		M.foundX := MAX(SIGNED16); M.foundY := MIN(SIGNED16);
		dlink.handle(dlink, M);
		IF M.to # NIL THEN (* focus found *)
			IF F.carpos >= 0 THEN F.carpos := -1; Gadgets.Update(F) END;
			M.to.carpos := 0; M.to.start := 0;
			Gadgets.Update(M.to)
		END
	END
END Pass;

PROCEDURE passFocusMsg(F: TextField; VAR M: PassFocusMsg);

	PROCEDURE Distance(x, y: SIGNED32): SIGNED32;
	BEGIN
		IF y = M.Y THEN (* on the same line *)
			IF x < M.X THEN RETURN MAX(SIGNED32)
			ELSE RETURN x - M.X
			END
		ELSE
			IF y > M.Y THEN RETURN MAX(SIGNED32)
			ELSE RETURN (M.Y - y) * 1000
			END
		END
	END Distance;

BEGIN
	IF M.F = F THEN (* found *) M.X := M.x + F.X; M.Y := M.y + F.Y
	ELSIF M.F = NIL THEN
		IF F # M.from THEN
			IF Distance(M.x + F.X, M.y + F.Y) < Distance(M.foundX, M.foundY) THEN
				M.to := F; M.foundY := M.y + F.Y; M.foundX := M.x + F.X
			END
		END
	END
END passFocusMsg;

(* ----------- *)

PROCEDURE Inval(F: TextField; VAR hint: SIGNED32);
BEGIN
	IF F.consistent THEN
		hint := -1;
		F.consistent := FALSE
	END
END Inval;

PROCEDURE UpdateTextField(F: TextField; beg: SIGNED32);
VAR M: TextFieldUpdateMsg;
BEGIN
	M.F := NIL; M.obj := F; M.beg := beg; F.slink := NIL; Display.Broadcast(M)
END UpdateTextField;

PROCEDURE ConsumeChar(F: TextField; ch: CHAR; dlink: Objects.Object);
VAR beg: SIGNED32; x, y: SIGNED16;
BEGIN
	beg := -1;
	IF ch = 7FX THEN
		IF F.carpos > 0 THEN
			DEC(F.carpos); DeleteChar(F.val, F.carpos); beg := F.carpos;
			IF F.selbeg >= 0 THEN F.selbeg := -1; beg := -1 END; Inval(F, beg);
			IF F.start > F.carpos THEN DEC(F.start); beg := -1 END;
			UpdateTextField(F, beg)
		END
	ELSIF ch = 0A1X THEN (* Delete right *)
		IF F.val[F.carpos] # 0X THEN
			DeleteChar(F.val, F.carpos); beg := F.carpos;
			IF F.selbeg >= 0 THEN F.selbeg := -1; beg := -1 END; Inval(F, beg);
			UpdateTextField(F, beg)
		END;
	ELSIF ch = 0DX THEN
		MakeConsistent(F, dlink);
		Gadgets.ExecuteAttr(F, "Cmd", dlink, NIL, NIL)
	ELSIF ch = 0C4X THEN (* left arrow *)
		IF F.carpos > 0 THEN
			DEC(F.carpos); beg := F.carpos;
			IF F.start > F.carpos THEN DEC(F.start); beg := -1 END;
			IF F.selbeg >= 0 THEN F.selbeg := -1; beg := -1 END;
			UpdateTextField(F, beg)
		END
	ELSIF ch = 0C3X THEN (* right arrow *)
		IF F.val[F.carpos] # 0X THEN
			beg := F.carpos; INC(F.carpos);
			LocatePos(F, F.carpos, x, y);
			WHILE (x >= F.W - 3) & (F.val[F.start] # 0X) DO
				INC(F.start); beg := -1; LocatePos(F, F.carpos, x, y);
			END;
			IF F.selbeg >= 0 THEN F.selbeg := -1; beg := -1 END;
			UpdateTextField(F, beg)
		END
	ELSIF ch = 0A8X THEN (* home *)
		IF F.carpos > 0 THEN
			F.carpos := 0; beg := F.carpos;
			IF F.start > F.carpos THEN F.start := F.carpos; beg := -1 END;
			IF F.selbeg >= 0 THEN F.selbeg := -1; beg := -1 END;
			UpdateTextField(F, beg)
		END
	ELSIF ch = 0A9X THEN (* end *)
		IF F.val[F.carpos] # 0X THEN
			beg := F.carpos;
			WHILE F.val[F.carpos] # 0X DO
				INC(F.carpos)
			END;
			LocatePos(F, F.carpos, x, y);
			WHILE (x >= F.W - 3) & (F.val[F.start] # 0X) DO
				INC(F.start); beg := -1; LocatePos(F, F.carpos, x, y);
			END;
			IF F.selbeg >= 0 THEN F.selbeg := -1; beg := -1 END;
			UpdateTextField(F, beg)
		END
	ELSIF ch = 09X THEN (* TAB *)
		F.start := 0;
		MakeConsistent(F, dlink);
		Gadgets.ExecuteAttr(F, "Cmd", dlink, NIL, NIL);
		Pass(F, dlink)
	ELSIF (ch >= " ") & (Length(F.val) < MaxLen-1) THEN
		beg := F.carpos;
		InsertChar(F.val, F.carpos, ch);
		INC(F.carpos);
		IF F.selbeg >= 0 THEN F.selbeg := -1; beg := -1 END; Inval(F, beg);
		LocatePos(F, F.carpos, x, y);
		WHILE (x >= F.W - 3) & (F.val[F.start] # 0X) DO
			INC(F.start); beg := -1; LocatePos(F, F.carpos, x, y)
		END;
		UpdateTextField(F, beg)
	END
END ConsumeChar;

PROCEDURE LocateChar(F: TextField; x, mx: SIGNED16; VAR pos: SIGNED16);
VAR p: SIGNED16; r: Objects.Object; X: SIGNED16;
BEGIN
	p := F.start; X := x + Xoffset;
	WHILE (F.val[p] # 0X) DO
		(*Fonts.Default.GetObj(Fonts.Default, ORD(F.val[p]), r);*)
		F.font.GetObj(F.font, ORD(F.val[p]), r);
		IF mx < X + r(Fonts.Char).dx THEN pos := p; RETURN; END;
		INC(X, r(Fonts.Char).dx); INC(p);
	END;
	pos := p;
END LocateChar;

PROCEDURE LocatePos(F: TextField; pos: SIGNED16; VAR x, y: SIGNED16);
VAR r: Objects.Object; p: SIGNED16;
BEGIN
	x := Xoffset; (*y := Yoffset*) y:= Yoffset - F.font.minY ; p := F.start;
	WHILE (F.val[p] # 0X) & (p < pos) DO
		(*Fonts.Default.GetObj(Fonts.Default, ORD(F.val[p]), r);*)
		F.font.GetObj(F.font, ORD(F.val[p]), r);
		INC(x, r(Fonts.Char).dx); INC(p);
	END;
END LocatePos;

PROCEDURE FlipCaret(R: Display3.Mask; F: TextField; x, y: SIGNED16);
BEGIN
	IF F.carpos >= 0 THEN Display3.ReplConst(R, invTF, x + F.carx, y + F.cary-3, CarWidth, F.font.maxY+3+2 (*CarHeight*), Display.invert); END;
END FlipCaret;

PROCEDURE SetCaret(R: Display3.Mask; F: TextField; x, y, pos: SIGNED16);
BEGIN
	LocatePos(F, pos, F.carx, F.cary);
	Display3.ReplConst(R, invTF, x + F.carx, y + F.cary-3, CarWidth, F.font.maxY+3+2 (*CarHeight*), Display.invert);
END SetCaret;

PROCEDURE RemoveCaret(R: Display3.Mask; F: TextField; x, y: SIGNED16);
BEGIN
	IF F.carpos >= 0 THEN FlipCaret(R, F, x, y); F.carpos := -1; END;
END RemoveCaret;

PROCEDURE TrackCaret(VAR DR: Display3.Mask; F: TextField; x, y: SIGNED16);
VAR mx, my, pos: SIGNED16; keys, keysum: SET; time, beg, end, p, hint: SIGNED32; text: Texts.Text;
	R: Texts.Reader; ch: CHAR;
BEGIN
	RemoveCaret(DR, F, x, y); keysum := {};
	LOOP
		Input.Mouse(keys, mx, my); keysum := keysum + keys;
		IF keys = {} THEN EXIT; END;
		LocateChar(F, x, mx, pos);
		IF pos # F.carpos THEN
			Oberon.FadeCursor(Oberon.Mouse);
			FlipCaret(DR, F, x, y); F.carpos := pos; LocatePos(F, F.carpos, F.carx, F.cary); FlipCaret(DR, F, x, y);
		END;
		Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, mx, my);
	END;
	IF keysum = {2, 1} THEN
		Oberon.GetSelection(text, beg, end, time);
		IF time # -1 THEN
			hint := F.carpos;
			p := beg; Texts.OpenReader(R, text, p);
			LOOP
				IF p = end THEN EXIT END;
				Texts.Read(R, ch);
				IF R.eot THEN EXIT END;
				IF Length(F.val) >= MaxLen-1 THEN EXIT END;
				IF (20X <= ch) & (ch < 86X) OR (ch = " ") OR (ch = 9X) THEN
					InsertChar(F.val, F.carpos, ch); INC(F.carpos);
				END;
				INC(p);
			END;
			IF F.selbeg >= 0 THEN F.selbeg := -1; hint := -1 END; Inval(F, hint);
			UpdateTextField(F, hint);
		END;
	ELSE
		Gadgets.Update(F);
	END;
END TrackCaret;

PROCEDURE FlipSelection(R: Display3.Mask; F: TextField; x, y: SIGNED16; spos, epos: SIGNED16);
VAR sx, sy, ex, ey: SIGNED16;
BEGIN
	LocatePos(F, spos, sx, sy); LocatePos(F, epos, ex, ey);
	Display3.ReplConst(R, invTF, x + sx, y + sy - 3, (ex - sx), Min(F.font.maxY+3+2 (*CarHeight*), F.H - 4), Display.invert);
END FlipSelection;

PROCEDURE RemoveSelection(R: Display3.Mask; F: TextField; x, y: SIGNED16);
BEGIN
	IF F.selbeg >= 0 THEN FlipSelection(R, F, x, y, F.selbeg, F.selend); F.selbeg := -1; END;
END RemoveSelection;

PROCEDURE TrackSelection(R: Display3.Mask; F: TextField; x, y: SIGNED16);
VAR mx, my, pos, spos, epos, len: SIGNED16; keys, keysum: SET; time: SIGNED32;
	C: Oberon.ConsumeMsg;
BEGIN
	Oberon.FadeCursor(Oberon.Mouse);
	Input.Mouse(keys, mx, my);
	IF keys = {} THEN RETURN END;
	keysum := keys; len := Length(F.val);
	LocateChar(F, x, mx, spos);
	IF spos >= len THEN DEC(spos) END;
	IF (F.selbeg >= 0) & (F.selbeg = spos) & (F.selend = F.selbeg + 1) THEN
		RemoveSelection(R, F, x, y);
		epos := spos; spos := 0; FlipSelection(R, F, x, y, spos, epos+1);
	ELSE
		RemoveSelection(R, F, x, y);
		epos := spos;
		FlipSelection(R, F, x, y, spos, epos+1);
	END;
	LOOP
		Input.Mouse(keys, mx, my); keysum := keysum + keys;
		IF keys = {} THEN EXIT; END;
		LocateChar(F, x, mx, pos);
		IF pos >= len THEN DEC(pos) END;
		IF (pos >= spos) & (pos # epos) THEN
			Oberon.FadeCursor(Oberon.Mouse);
			IF (pos < epos) THEN
				FlipSelection(R, F, x, y, pos+1, epos+1);
			ELSE
				FlipSelection(R, F, x, y, epos+1, pos+1);
			END;
			epos := pos;
		END;
		Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, mx, my);
	END;
	FlipSelection(R, F, x, y, spos, epos+1);
	F.selbeg := -1;
	IF (keysum = {0}) & (spos # -1) THEN
		F.time := Oberon.Time();
		F.selbeg := spos; F.selend := epos+1;
		Gadgets.Update(F)
	ELSIF (keysum = {0, 1}) & (spos # -1) THEN (* copy out *)
		F.selbeg := spos; F.selend := epos+1; F.time := Oberon.Time();
		Gadgets.Update(F);
		Oberon.GetSelection(C.text, C.beg, C.end, time);
		C.F := NIL; C.res := -1;
		Display.Broadcast(C)
	ELSIF (keysum = {0, 2}) & (spos # -1) THEN (* delete *)
		IF F.carpos < 0 THEN Oberon.Defocus END;
		Delete(F.val, spos, epos+1); F.carpos := spos; Inval(F, time);
		UpdateTextField(F, -1)
	ELSE
		Gadgets.Update(F)
	END
END TrackSelection;

PROCEDURE GetSelection(F: TextField; VAR text: Texts.Text; VAR beg, end, time: SIGNED32);
VAR p: SIGNED16; W: Texts.Writer;
BEGIN
	NEW(text); Texts.Open(text, "");
	(* old
	p := F.selbeg; Texts.OpenWriter(W);
	WHILE p < F.selend DO
		Texts.Write(W, F.val[p]); INC(p);
	END;
	*)
	p := 0; Texts.OpenWriter(W);
	WHILE F.val[p] # 0X DO
		Texts.Write(W, F.val[p]); INC(p);
	END;
	Texts.Append(text, W.buf);
	beg := F.selbeg; end := F.selend; time := F.time;
END GetSelection;

PROCEDURE TextFieldAttr(F: TextField; VAR M: Objects.AttrMsg);
BEGIN
	IF M.id = Objects.get THEN
		IF M.name = "Gen" THEN M.class := Objects.String; COPY("TextFields.NewTextField", M.s); M.res := 0
		ELSIF M.name = "Value" THEN M.class := Objects.String; COPY(F.val, M.s); M.res := 0
		ELSIF M.name = "Color" THEN M.class := Objects.Int; M.i := F.col; M.res := 0
		ELSIF M.name= "TextCol" THEN M.class :=Objects.Int; M.i := F.textcol; M.res:=0
		ELSIF M.name = "LineupHY" THEN M.class := Objects.Int; M.i := Yoffset-F.font.minY; M.res := 0
		ELSIF M.name = "Field" THEN ForceString(F, M)
		ELSIF M.name = "Cmd" THEN ForceString(F, M)
		ELSIF M.name= "Font" THEN M.class := Objects.String; COPY(F.font.name, M.s); M.res := 0
		ELSE Gadgets.framehandle(F, M)
		END;
	ELSIF M.id = Objects.set THEN
		IF M.name = "Value" THEN
			IF M.class = Objects.String THEN COPY(M.s, F.val); M.res := 0 END
		ELSIF M.name = "Color" THEN
			IF M.class = Objects.Int THEN F.col := SHORT(M.i); ComputeColors(F,F.col); M.res := 0 END
		ELSIF M.name = "TextCol" THEN
			IF M.class = Objects.Int THEN F.textcol := SHORT(M.i); M.res := 0 END
		ELSIF M.name="Font" THEN
			IF M.class = Objects.String THEN F.font:=ThisFont(M.s); IF F.font=NIL THEN F.font:=Fonts.Default END; M.res := 0 END
		ELSE Gadgets.framehandle(F, M);
		END;
	ELSIF M.id = Objects.enum THEN
		M.Enum("Value"); M.Enum("Color"); M.Enum("TextCol"); M.Enum("Font"); M.Enum("Field"); M.Enum("Cmd"); Gadgets.framehandle(F, M);
	END;
END TextFieldAttr;

PROCEDURE ConsumeText(F: TextField; VAR M: Oberon.ConsumeMsg);
VAR R: Texts.Reader; ch: CHAR; pos, beg: SIGNED32;
BEGIN
	pos := M.beg; Texts.OpenReader(R, M.text, pos); beg := F.carpos;
	IF F.selbeg >= 0 THEN F.selbeg := -1; beg := -1 END;
	LOOP
		IF pos = M.end THEN EXIT END;
		Texts.Read(R, ch);
		IF R.eot THEN EXIT END;
		IF Length(F.val) >= MaxLen-1 THEN EXIT END;
		IF (20X <= ch) OR (ch = " ") OR (ch = 9X) THEN
			InsertChar(F.val, F.carpos, ch); INC(F.carpos);
		END;
		INC(pos);
	END;
	Inval(F, beg);
	UpdateTextField(F, beg);
END ConsumeText;

PROCEDURE AdaptFontSizeProportional*(F:TextField);
VAR i,j,size,newsize:SIGNED16; oldfont:Fonts.Font; oldfn,newfn:ARRAY 256 OF CHAR;
BEGIN
	IF F=NIL THEN RETURN END;
	oldfont:=F.font;
	COPY(oldfont.name,oldfn);
	SplitFontName(oldfn,i,j,size);
	newsize:=( (F.H - Yoffset -3 (*upper border*)) * 10 DIV 12)   ;
		(* *10 DIV 12 because font size 10 goes from -3 to 9 (range 12) pixels*)
	CombineFontName(oldfn,oldfn,i,j,newsize,newfn);
	F.font:=ThisFont(newfn);
	IF F.font=NIL THEN F.font:=oldfont END;
END AdaptFontSizeProportional;

PROCEDURE ComputeColors(F:TextField; col:SIGNED32);
VAR r,g,b:FLOAT32;
BEGIN
	IF col=Display3.textbackC THEN F.topC:=Display3.textbackC; F.bottomC:=Display3.bottomC;
	ELSE
		Colors.DisplayToRGB(col, r,g,b);
		col:=Colors.Match(Colors.DisplayIndex,Colors.DisplayBits,SHORT(ENTIER(255*r/1.5)),
																			SHORT(ENTIER( 255*g/1.5)), SHORT(ENTIER(255*b/1.5)));
		IF Display3.bottomC=Display.FG (*hardlook*) THEN F.bottomC:=Display.FG ELSE F.bottomC:=SHORT(col) END;
		col:=Colors.Match(Colors.DisplayIndex,Colors.DisplayBits, SHORT(ENTIER(255*(1-(1-r)/1.5))),
																				SHORT(ENTIER(255*(1-(1-g)/1.5))), SHORT(ENTIER(255*(1-(1-b)/1.5))));
		F.topC:=SHORT(col);
	END;
END ComputeColors;

PROCEDURE RestoreTextField(R: Display3.Mask; F: TextField; x, y, w, h: SIGNED16; beg: SIGNED32);
VAR p, X, Y, cx, cy, cw, ch: SIGNED16; r: Objects.Object;
BEGIN
	Oberon.RemoveMarks(x, y, w, h);
	AdaptFontSizeProportional(F);
	ComputeColors(F,F.col);
	IF beg < 0 THEN
		IF F.consistent THEN
			Display3.Rect3D(R, F.bottomC, F.topC, x, y, w, h, 1, Display.replace)
		ELSE
			Display3.Rect3D(R, F.topC, F.bottomC, x, y, w, h, 1, Display.replace)
		END;
		Display3.ReplConst(R, F.col, x+1, y+1, Xoffset, h-2, Display.replace);
	END;

	p := F.start; X := x + Xoffset; Y := y + Yoffset-F.font.minY;
	cx := R.X; cy := R.Y; cw := R.W; ch := R.H;
	Display3.AdjustMask(R, x + 1, y + 1, w - 2, h - 2);
	WHILE F.val[p] # 0X DO
		(*Fonts.Default.GetObj(Fonts.Default, ORD(F.val[p]), r);*)
		F.font.GetObj(F.font, ORD(F.val[p]), r);
		WITH r: Fonts.Char DO
			IF p >= beg THEN
				Display3.ReplConst(R, F.col, X, y+1, r.dx, h-2, Display.replace);
				Display3.CopyPattern(R, F.textcol (*Display3.textC*), r.pat, X + r.x, Y + r.y, Display3.textmode)
			END;
			INC(X, r.dx); INC(p);
		END
	END;
	IF X < x + w - 1 THEN
		Display3.ReplConst(R, F.col, X, y+1, x + w - X - 1, h-2, Display.replace);
	END;
	IF F.carpos >= 0 THEN
		IF F.carpos > Length(F.val) THEN
			F.carpos := Length(F.val)
		END;
		SetCaret(R, F, x, y, F.carpos);
	END;
	IF F.selbeg >= 0 THEN
		FlipSelection(R, F, x, y, F.selbeg, F.selend);
	END;
	R.X := cx; R.Y := cy; R.W := cw; R.H := ch;
	IF Gadgets.selected IN F.state THEN
		Display3.FillPattern(R, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint)
	END
END RestoreTextField;

PROCEDURE PrintTextField(F: TextField; VAR M: Display.DisplayMsg);
VAR R: Display3.Mask; x, y, w, h: SIGNED16;

	PROCEDURE P(x: SIGNED16): SIGNED16;
	BEGIN RETURN SHORT(x * Display.Unit DIV Printer.Unit)
	END P;

BEGIN
	Gadgets.MakePrinterMask(F, M.x, M.y, M.dlink, R);
	x := M.x; y := M.y; w := P(F.W); h := P(F.H);
	Printer3.Rect3D(R, F.bottomC, F.topC, x, y, w, h, P(1), Display.replace);
	Printer3.ReplConst(R, F.col, x+P(1), y+P(1), w - P(2), h-P(2), Display.replace);
	Display3.AdjustMask(R, x+P(1), y+P(1), w-P(2), h-P(2));
	Printer3.String(R, F.textcol (*Display3.textC*), x + P(Xoffset), y + P(Yoffset-F.font.minY), F.font (*Fonts.Default*), F.val, Display.replace)
END PrintTextField;

(* --- Model view consistency --- *)

PROCEDURE Field(F: TextField; VAR name: ARRAY OF CHAR);
VAR A: Objects.AttrMsg;
BEGIN
	A.id := Objects.get; A.name := "Field"; A.class := Objects.Inval; A.s := "";
	F.handle(F, A);
	IF (A.res >= 0) & (A.class = Objects.String) & (A.s # "") THEN COPY(A.s, name)
	ELSE COPY("Value", name)
	END
END Field;

PROCEDURE SetValue(obj: Objects.Object; field, value: ARRAY OF CHAR; dlink: Objects.Object; VAR res: SIGNED16);
VAR A: Objects.AttrMsg;
BEGIN
	A.id := Objects.set; COPY(field, A.name); COPY(value, A.s); A.class := Objects.String; A.res := -1; A.dlink := dlink;
	obj.handle(obj, A);
	res := A.res
END SetValue;

PROCEDURE GetValue(obj: Objects.Object; field: ARRAY OF CHAR; VAR value: ARRAY OF CHAR);
VAR A: Objects.AttrMsg;
BEGIN
	A.id := Objects.get; COPY(field, A.name); A.class := Objects.Inval; A.s := ""; A.res := -1;
	obj.handle(obj, A);
	IF A.res >= 0 THEN
		IF A.class = Objects.String THEN COPY(A.s, value)
		ELSIF A.class = Objects.Int THEN Strings.IntToStr(A.i, value)
		ELSIF A.class = Objects.Real THEN Strings.RealToStr(A.x, value)
		ELSIF A.class = Objects.LongReal THEN Strings.RealToStr(A.y, value)
		ELSE value[0] := 0X
		END
	ELSE value[0] := 0X
	END
END GetValue;

PROCEDURE CopyTextField*(VAR M: Objects.CopyMsg; from, to: TextField);
VAR field: ARRAY 256 OF CHAR;
BEGIN
	Gadgets.CopyFrame(M, from, to);
	COPY(from.val, to.val); to.carpos := -1; to.selbeg := -1;
	to.col := from.col; to.font:=from.font; to.textcol:=from.textcol;
	to.topC:=from.topC; to.bottomC:=from.bottomC;
	Field(to, field);
	IF to.obj # NIL THEN GetValue(to.obj, field, to.val) END;
	to.consistent := TRUE;
END CopyTextField;

PROCEDURE Recall(F: TextField; dlink: Objects.Object);
VAR buf: Texts.Buffer; t: Texts.Text; str: ARRAY MaxLen OF CHAR; i: SIGNED32;
BEGIN
	NEW(buf); Texts.OpenBuf(buf); Texts.Recall(buf);
	NEW(t); Texts.Open(t, ""); Texts.Append(t, buf);
	Attributes.TxtToStr(t, str);
	i := 0;
	WHILE (i < MaxLen) & (str[i] # 0X) DO
		ConsumeChar(F, str[i], dlink); INC(i)
	END
END Recall;

PROCEDURE UpdateMsg(F: TextField; VAR M: Gadgets.UpdateMsg);
VAR field: ARRAY 256 OF CHAR; obj: Objects.Object;
BEGIN
	IF F.obj # NIL THEN F.obj.handle(F.obj, M) END;
	IF M.obj = F.obj THEN
		IF M.stamp # F.stamp THEN
			F.stamp := M.stamp;
			Field(F, field);
			GetValue(F.obj, field, F.val); F.selbeg := -1; F.carpos := -1; F.consistent := TRUE;
			UpdateTextField(F, -1)
		END
	ELSE
		obj := M.obj;
		WHILE obj # NIL DO
			IF obj = F THEN
				IF F.obj # NIL THEN
					Field(F, field);
					GetValue(F.obj, field, F.val)
				END;
				F.selbeg := -1; F.carpos := -1;
				F.consistent := TRUE;
				Gadgets.framehandle(F, M)
			END;
			obj := obj.slink
		END
	END
END UpdateMsg;

PROCEDURE MakeConsistent(F: TextField; dlink: Objects.Object);
VAR field: ARRAY 256 OF CHAR; res: SIGNED16;
BEGIN
	IF ~F.consistent THEN
		IF F.obj # NIL THEN
			Field(F, field);
			SetValue(F.obj, field, F.val, dlink, res);
			F.start := 0;
			Gadgets.Update(F.obj); (* even when successfull or not *)
		ELSE F.consistent := TRUE; Gadgets.Update(F)
		END
	ELSE Gadgets.Update(F)
	END
END MakeConsistent;

PROCEDURE TextFieldHandler*(F: Objects.Object; VAR M: Objects.ObjMsg);
VAR F2: TextField; x, y, w, h: SIGNED16; R: Display3.Mask; ver: SIGNED32; field,fontname: ARRAY 256 OF CHAR;
BEGIN
	WITH F: TextField DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO TextFieldAttr(F, M) END;
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.load THEN
					Files.ReadNum(M.R, ver); IF (ver < 2) OR (ver > 5) THEN HALT(99) END;
					Files.ReadString(M.R, F.val);
					IF ver >= 3 THEN
						Files.ReadInt(M.R, F.col);
						IF (ver = 3) & (F.col = 0) THEN F.col := Display3.textbackC END;
						IF ver>=5 THEN
							Files.ReadString(M.R, fontname); F.font:=ThisFont(fontname);
							Files.ReadInt(M.R, F.textcol);
							IF F.font=NIL THEN F.font:=Fonts.Default END;
						ELSE F.font:=Fonts.Default; F.textcol:=Display3.textC
						END;
					ELSE F.col := Display3.textbackC
					END;
					ComputeColors(F,F.col);
					Gadgets.framehandle(F, M)
				ELSIF M.id = Objects.store THEN
					Files.WriteNum(M.R, 5);
					Files.WriteString(M.R, F.val); Files.WriteInt(M.R, F.col);
					Files.WriteString(M.R, F.font.name);
					Files.WriteInt(M.R, F.textcol);
					Gadgets.framehandle(F, M)
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = F.stamp THEN M.obj := F.dlink
				ELSE NEW(F2); F.stamp := M.stamp; F.dlink := F2; CopyTextField(M, F, F2); M.obj := F2
				END
			END;
		ELSIF M IS Display.FrameMsg THEN
			WITH M: Display.FrameMsg DO
				IF M.res >= 0 THEN RETURN END;
				x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H;
				IF M IS Display.DisplayMsg THEN
					WITH M: Display.DisplayMsg DO
						IF M.device = Display.screen THEN
							IF (M.F = NIL) OR ((M.id = Display.full) & (M.F = F)) THEN
								Gadgets.MakeMask(F, x, y, M.dlink, R);
								RestoreTextField(R, F, x, y, w, h, -1);
							ELSIF (M.id = Display.area) & (M.F = F) THEN
								Gadgets.MakeMask(F, x, y, M.dlink, R);
								Display3.AdjustMask(R, x + M.u, y + h - 1 + M.v, M.w, M.h);
								RestoreTextField(R, F, x, y, w, h, -1);
							END
						ELSIF M.device = Display.printer THEN PrintTextField(F, M)
						END
					END
				ELSIF M IS Display.ModifyMsg THEN
					WITH M:Display.ModifyMsg DO
						Gadgets.framehandle(F, M);
						IF M.F=F THEN
							AdaptFontSizeProportional(F);
						END;
					END;
				ELSIF M IS Oberon.ControlMsg THEN
					WITH M: Oberon.ControlMsg DO
						IF (M.id = Oberon.defocus) & (F.carpos >= 0) THEN F.carpos := -1; F.start := 0;
							MakeConsistent(F, M.dlink);
						ELSIF (M.id = Oberon.neutralize) & (F.carpos >= 0) THEN F.carpos := -1; F.start := 0;
							F.selbeg := -1;
							IF F.obj # NIL THEN Gadgets.Update(F.obj) ELSE MakeConsistent(F, M.dlink) END
						ELSIF (M.id = Oberon.neutralize) & (F.selbeg >= 0) THEN F.carpos := -1; F.start := 0;
							F.selbeg := -1;
							IF F.obj # NIL THEN Gadgets.Update(F.obj) ELSE MakeConsistent(F, M.dlink) END
						ELSIF M.id = Oberon.mark THEN Oberon.DrawCursor(Oberon.Pointer, Oberon.Star, M.X, M.Y);
						END;
					END;
				ELSIF M IS TextFieldUpdateMsg THEN
					WITH M: TextFieldUpdateMsg DO
						IF M.obj = F THEN
							Gadgets.MakeMask(F, x, y, M.dlink, R);
							RestoreTextField(R, F, x, y, w, h, M.beg)
						END
					END
				ELSIF M IS PassFocusMsg THEN
					WITH M: PassFocusMsg DO passFocusMsg(F, M);
					END
				ELSIF M IS Gadgets.UpdateMsg THEN
					WITH M: Gadgets.UpdateMsg DO UpdateMsg(F, M) END
				ELSIF M IS Display.ControlMsg THEN (*!!! *)
					WITH M: Display.ControlMsg DO
						IF F.obj # NIL THEN F.obj.handle(F.obj, M) END;
						IF (M.id = Display.restore) & (F.obj # NIL) THEN
							IF (M.stamp # F.stamp) THEN F.stamp := M.stamp;
								Field(F, field); GetValue(F.obj, field, F.val)
							END;
							F.selbeg := -1; F.carpos := -1; F.consistent := TRUE;
						ELSIF M.id = Display.newprinter THEN
							lastfont := NIL; lastlib := NIL
						END
					END
				ELSIF M IS Oberon.SelectMsg THEN
					WITH M: Oberon.SelectMsg DO
						IF (F.selbeg >= 0) & (((M.time-F.time) < 0) OR (M.time = -1)) THEN GetSelection(F, M.text, M.beg, M.end, M.time) END
					END
				ELSIF M IS Oberon.ConsumeMsg THEN
					WITH M: Oberon.ConsumeMsg DO
						IF (F.carpos >= 0) & (F.stamp # M.stamp) THEN
							F.stamp := M.stamp; ConsumeText(F, M)
						END
					END
				ELSIF M IS Oberon.RecallMsg THEN
					IF F.carpos >= 0 THEN
						Recall(F, M.dlink); M.res := 0
					END
				ELSIF M IS Oberon.InputMsg THEN
					WITH M: Oberon.InputMsg DO
						IF (M.id = Oberon.track) & Gadgets.InActiveArea(F, M) THEN
							IF 2 IN M.keys THEN
								IF F.carpos < 0 THEN Oberon.Defocus; END;
								Gadgets.MakeMask(F, x, y, M.dlink, R);
								TrackCaret(R, F, x, y); M.res := 0
							ELSIF 0 IN M.keys THEN
								Gadgets.MakeMask(F, x, y, M.dlink, R);
								TrackSelection(R, F, x, y); M.res := 0
							END
						ELSIF (M.id = Oberon.consume) & (F.carpos >= 0) THEN
							ConsumeChar(F, M.ch, M.dlink); M.res := 0
						ELSIF ~(Gadgets.selected IN F.state) THEN Gadgets.framehandle(F, M)
						END;
					END
				ELSE
					Gadgets.framehandle(F, M);
				END
			END
		ELSE
			Gadgets.framehandle(F, M);
		END
	END
END TextFieldHandler;

PROCEDURE InitTextField*(F: TextField);
BEGIN F.handle := TextFieldHandler; COPY("", F.val); F.W := 100; F.H := 20;
	F.selbeg := -1; F.carpos := -1; F.consistent := TRUE;
	F.font:=Fonts.Default; F.textcol:=Display3.textC; F.col := Display3.textbackC; ComputeColors(F,F.col);
END InitTextField;

PROCEDURE NewTextField*;
VAR F: TextField;
BEGIN
	NEW(F); InitTextField(F); Objects.NewObj := F;
END NewTextField;

BEGIN Texts.OpenWriter(W);
	invTF := 15 - 14
END TextFields.


System.Free TextFields

Gadgets.Insert TextFields.NewCaption ~