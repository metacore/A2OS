(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE PS IN Oberon;	(** portable *)

IMPORT Display, Texts, Oberon, Pictures, Files;

CONST
	(*PW = 576; PH = 792;	*)
	PW = 580; PH = 820;	(*dia*)
	EOL = 0DX;

	PROCEDURE FadeUp(P: Pictures.Picture; max: SIGNED16);	(*fade picture colors to maximum*)
	VAR i, r, g, b, mr, mg, mb, n: SIGNED16;
		f: FLOAT32;
	BEGIN
		n := SIGNED16(ASH(1, P.depth));
		i := 0; mr := 0; mg := 0; mb := 0;
		WHILE i < n DO
			Pictures.GetColor(P, i, r, g, b);
			IF r > mr THEN mr := r END;
			IF g > mg THEN mg := g END;
			IF b > mb THEN mb := b END;
			INC(i)
		END;
		IF mg > mr THEN mr := mg END;
		IF mb > mr THEN mr := mb END;
		f := max / mr;
		i := 0;
		WHILE i < n DO
			Pictures.GetColor(P, i, r, g, b);
			Pictures.SetColor(P, i, SHORT(ENTIER(f*r)), SHORT(ENTIER(f*g)), SHORT(ENTIER(f*b)));
			INC(i)
		END
	END FadeUp;

		PROCEDURE ChName(VAR t: ARRAY OF CHAR);
		VAR i, k: SIGNED16;
		BEGIN i := 0; k := i;
			WHILE t[i] # 0X DO	(*find last "."*)
				IF t[i] = "." THEN k := i END; INC(i)
			END;
			IF k = 0 THEN k := i END;
			t[k] := "."; t[k+1] := "p"; t[k+2] := "s"; t[k+3] := 0X
		END ChName;

	PROCEDURE PictToPost*;
	VAR
		P: Pictures.Picture;
		S: Texts.Scanner;
		T: Texts.Text;
		F: Files.File;
		R: Files.Rider;
		ch: CHAR;
		x, y, k, i, h0, h1, n: SIGNED16;
		tx, ty, dw: FLOAT32;
		h: ARRAY 128 OF SIGNED16;
		rle, a3, rot, eps: BOOLEAN;
		name: ARRAY 32 OF CHAR;
		adjust: FLOAT32;
		linew: SIGNED32;

		PROCEDURE Int(n: SIGNED16);
		VAR d: ARRAY 8 OF CHAR; i: SIGNED16;
		BEGIN Files.Write(R, " ");
			i := 0;
			REPEAT
				d[i] := CHR(n MOD 10+30H); n := n DIV 10; INC(i)
			UNTIL n = 0;
			WHILE i > 0 DO DEC(i); Files.Write(R, d[i]) END
		END Int;

		PROCEDURE H(n: SIGNED16);
		VAR d0, d1: SIGNED16;
		BEGIN
			d0 := n MOD 16; IF d0 > 9 THEN INC(d0, 7) END;
			d1 := n DIV 16; IF d1 > 9 THEN INC(d1, 7) END;
			Files.Write(R, CHR(d1+30H)); Files.Write(R, CHR(d0+30H));
			INC(linew, 2);
			IF (linew MOD 80) = 0 THEN
				Files.Write(R, EOL)
			END
		END H;

		PROCEDURE Str(s: ARRAY OF CHAR);
		VAR i: SIGNED16;
		BEGIN
			i := 0; WHILE s[i] # 0X DO Files.Write(R, s[i]); INC(i) END;
		END Str;

		PROCEDURE Real(x: FLOAT32);
		VAR
			n, i, xi: SIGNED16;
			d: ARRAY 4 OF CHAR;
		BEGIN
			xi := SHORT(ENTIER(x));
			IF x = xi THEN Int(xi); RETURN END;
			IF x < 0 THEN Files.Write(R, "-"); x := -x; xi := -xi END;
			Int(xi); Files.Write(R, "."); x := x-xi;
			n := SHORT(ENTIER(x*1000));
			i := 0;
			REPEAT
				d[i] := CHR(n MOD 10+30H); n := n DIV 10; INC(i)
			UNTIL i = 3;
			WHILE i > 0 DO DEC(i); Files.Write(R, d[i]) END
		END Real;

		PROCEDURE ScaleTo(w, h, W, H: SIGNED16; adjust: FLOAT32; VAR tx, ty, dw: FLOAT32; rot: BOOLEAN);
		(*compute translation vector (tx, ty) scaling factor dx in order to fit [w, h] optimally into [W, H]*)
		VAR d0, d1: FLOAT32;
		BEGIN
			IF rot THEN d0 := H/w; d1 := W/h ELSE d0 := W/w; d1 := H/h END;
			IF d0 < d1 THEN dw := d0*adjust ELSE dw := d1*adjust END;
			IF rot THEN tx := (W + dw*h)/2; ty := (H - dw*w)/2
			ELSE tx := (W - dw*w)/2; ty := (H - dw*w)/2
			END
		END ScaleTo;

		PROCEDURE Transform(tx, ty, dw: FLOAT32; rot: BOOLEAN);
		BEGIN
			Real(tx); Real(ty); Str(" translate");
			Real(dw); Real(dw); Str(" scale");
			IF rot THEN Str(" 90 rotate") END; Files.Write(R, EOL)
		END Transform;

		PROCEDURE WColTab(n: SIGNED16);
		VAR
			r, g, b: ARRAY 256 OF SIGNED16;
			i, d: SIGNED16;
		BEGIN d := SIGNED16(ASH(1, P.depth));
			i := 0; WHILE i < d DO Pictures.GetColor(P, i, r[i], g[i], b[i]); INC(i) END;
			WHILE i < n DO r[i] := 0; g[i] := 0; b[i] := 0; INC(i) END;
			i := 0; WHILE i < n DO H(r[i]); INC(i) END; Files.Write(R, EOL);
			i := 0; WHILE i < n DO H(g[i]); INC(i) END; Files.Write(R, EOL);
			i := 0; WHILE i < n DO H(b[i]); INC(i) END; Files.Write(R, EOL)
		END WColTab;

		PROCEDURE Out;
		BEGIN
			IF n > 0 THEN
				IF n = 1 THEN H(0); H(h[0])
				ELSIF (n = 2) & (h[0] = h[1]) THEN H(81H); H(h[0])
				ELSE H(n-1); i := 0; WHILE i < n DO H(h[i]); INC(i) END
				END;
				n := 0
			END;
			WHILE k > 128 DO H(127+128); H(h0); DEC(k, 128) END;
			H(127+k); H(h0)
		END Out;

		PROCEDURE DateTime;
		VAR t, d: SIGNED32;
			PROCEDURE Pair(ch: CHAR; n: SIGNED32);
			BEGIN Files.Write(R, ch); Files.Write(R, CHR(n DIV 10 MOD 10+30H)); Files.Write(R, CHR(n MOD 10 +30H))
			END Pair;
		BEGIN Oberon.GetClock(t, d);
			Pair(" ", d MOD 32); Pair(".", (d DIV 32) MOD 16); Pair(".", (d DIV (32*16)));	(*date*)
			Pair(" ", (t DIV (64*64)) MOD 32); Pair(":", (t DIV 64) MOD 64); Pair(":", t MOD 64);	(*time*)
		END DateTime;

		PROCEDURE BoundingBox(w, h: SIGNED16; tx, ty, dw: FLOAT32; rot: BOOLEAN);
		BEGIN Str("%%BoundingBox: ");
			IF rot THEN Real(tx-h*dw); Real(ty); Real(tx); Real(ty+w*dw)
			ELSE Real(tx); Real(ty); Real(tx+w*dw); Real(ty+h*dw)
			END
		END BoundingBox;

		PROCEDURE EPSHeader(P: Pictures.Picture; tx, ty, dw: FLOAT32; rot: BOOLEAN);
		BEGIN
			Str("%!PS-Adobe-1.0"); Files.Write(R, EOL);
			BoundingBox(P.width, P.height, tx, ty, dw, rot); Files.Write(R, EOL);
			Str("%%Creator: PS"); Files.Write(R, EOL);
			Str("%%Title: "); Str(name); Files.Write(R, EOL);
			Str("%%CreationDate: "); DateTime; Files.Write(R, EOL);
			Str("%%EndComments"); Files.Write(R, EOL)
		END EPSHeader;

		PROCEDURE EPSTrailer;
		BEGIN
			Str("showpage"); Files.Write(R, EOL);
			Str("%%Trailer"); Files.Write(R, EOL);
			Str("%%EOF"); Files.Write(R, EOL)
		END EPSTrailer;

	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		NEW(P); Pictures.Open(P, S.s, TRUE);
		 COPY(S.s, name);
		FadeUp(P, 255); rot := FALSE;
		Texts.Scan(S); rle := FALSE; a3 := FALSE; eps := FALSE;
		IF (S.class = Texts.Char) & (S.c = Oberon.OptionChar) THEN Texts.Scan(S);
			IF S.class = Texts.Name THEN k := 0;
				WHILE S.s[k] # 0X DO
					IF S.s[k] = "r" THEN rle := TRUE END;
					IF S.s[k] = "a" THEN a3 := TRUE END;
					IF S.s[k] = "e" THEN eps := TRUE END;
					IF S.s[k] = "l" THEN rot := TRUE END;
					IF S.s[k] = "p" THEN rot := FALSE END;
					INC(k)
				END;
				Texts.Scan(S)
			END
		END;
		IF S.class = Texts.Real THEN adjust := S.x ELSE adjust := 1 END;
		NEW(T);
		IF rle THEN Texts.Open(T, "PS.HeaderR.Text" ) ELSE Texts.Open(T, "PS.Header.Text") END;
		IF T.len > 0 THEN
			ChName(name); F := Files.New(name); Files.Set(R, F, 0);
			IF a3 THEN ScaleTo(P.width, P.height, PH, SHORT(PH*14142 DIV Display.Unit), adjust, tx, ty, dw, rot)	(*A3 page*)
			ELSE ScaleTo(P.width, P.height, PW, PH, adjust, tx, ty, dw, rot)
			END;
			IF eps THEN EPSHeader(P, tx, ty, dw, rot) ELSE Str("%!"); Files.Write(R, EOL) END;
			(*program*)
			Texts.OpenReader(S, T, 0); Texts.Read(S, ch);
			WHILE ~S.eot DO
				IF ch = 0DX THEN ch := EOL END;	(*CR->LF*)
				Files.Write(R, ch); Texts.Read(S, ch)
			END;
			Transform(tx, ty, dw, rot);
			Int(P.width); Int(P.height);
			IF rle THEN Str(" rlepic") ELSE Str(" colorpic") END; Files.Write(R, EOL);
			(*data*)
			WColTab(256);
			y := P.height;
			WHILE y > 0 DO
				DEC(y); x := 0;
				IF rle THEN	(*run length encoded*)
					n := 0; h0 := Pictures.Get(P, 0, y); k := 1; x := 1; linew := 0;
					WHILE x < P.width DO
						h1 := Pictures.Get(P, x, y); h[n] := h1;
						IF h1 = h0 THEN INC(k)
						ELSE
							IF k < 3 THEN
								IF n + k >= 128 THEN H(127);
									i := 0; WHILE i < n DO H(h[i]); INC(i) END;
									i := 0; WHILE n + i < 128 DO H(h0); INC(i); DEC(k) END;
									n := 0
								END;
								WHILE k > 0 DO DEC(k); h[n] := h0; INC(n) END
							ELSE Out
							END;
							h0 := h1; k := 1
						END;
						INC(x)
					END;
					Out
				ELSE
					WHILE x < P.width DO H(Pictures.Get(P, x, y)); INC(x) END
				END;
				Files.Write(R, EOL)
			END;
			IF eps THEN EPSTrailer ELSE Str("showpage"); Files.Write(R, EOL) END;
			Files.Register(F)
		END
	END PictToPost;

END PS.

PS.PictToPost name ["\rae"][adjust] ~ r = run length encoding; e = EPS; a = A3
PS.PictToPost  Figure3.Pict \re 0.9 ~
Helv.ps

Hex.Open Clown.ps
