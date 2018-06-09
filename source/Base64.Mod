MODULE Base64; (** AUTHOR "P.Hunziker - Ported from Oberon.Base64.Mod (JG 23.8.94) "; PURPOSE "Base64 encoding and decoding"; *)

IMPORT Streams, KernelLog;

VAR
		encTable: ARRAY 64 OF CHAR;
		decTable: ARRAY 128 OF INTEGER;

PROCEDURE Decode*(R: Streams.Reader; W:Streams.Writer);
		VAR
			codes: ARRAY 4 OF INTEGER;
			i: INTEGER;
			ch: CHAR;
			ok, end: BOOLEAN;
	BEGIN
		ok := TRUE; end := FALSE;
		ch:=R.Get();
		REPEAT
			i := 0;
			WHILE ok & (i < 4) DO
				WHILE ch<=" " DO ch:=R.Get(); END;
				codes[i] := decTable[ORD(ch)];
				ok := codes[i] >= 0; INC(i);
				IF ok THEN ch:=R.Get() END;
			END;
			IF i > 0 THEN
				IF ok THEN
					W.Char(CHR(ASH(codes[0], 2)+ASH(codes[1], -4)));
					W.Char(CHR(ASH(codes[1], 4)+ASH(codes[2], -2)));
					W.Char(CHR(ASH(codes[2], 6)+codes[3]))
				ELSIF ch = "=" THEN
					ok := TRUE; end := TRUE; DEC(i);
					IF i = 2 THEN W.Char( CHR(ASH(codes[0], 2)+ASH(codes[1], -4)))
					ELSIF i = 3 THEN
						W.Char( CHR(ASH(codes[0], 2)+ASH(codes[1], -4)));
						W.Char( CHR(ASH(codes[1], 4)+ASH(codes[2], -2)))
					ELSIF i # 0 THEN ok := FALSE
					END
				ELSIF i = 4 THEN
					ok := TRUE; end := TRUE;
					W.Char( CHR(ASH(codes[0], 2)+ASH(codes[1], -4)));
					W.Char( CHR(ASH(codes[1], 4)+ASH(codes[2], -2)));
					W.Char( CHR(ASH(codes[2], 6)+codes[3]))
				ELSIF i = 1 THEN ok := TRUE; end := TRUE
				END
			ELSE
				end := TRUE
			END;
		UNTIL end;
		W.Update;
	END Decode;

	PROCEDURE Encode*(R:Streams.Reader; W:Streams.Writer);
		VAR
			i, j, c, c0, c1, c2, l: LONGINT;
			chars: ARRAY 3 OF CHAR;

		PROCEDURE OutCode(k:LONGINT);
		BEGIN
			IF l > 80 THEN	W.Ln; l := 0	END;

			c0 :=ORD(chars[0]);
			c := ASH(c0, -2);
			W.Char( encTable[c]);

			c0 := c0-ASH(c, 2);
			c1 := ORD(chars[1]);
			c := ASH(c0, 4)+ASH(c1, -4);
			IF k>=1 THEN W.Char(encTable[c]); END;

			c1 := c1 MOD ASH(1, 4);
			c2 := ORD(chars[2]);
			c := ASH(c1, 2)+ASH(c2, -6);
			IF k>=2 THEN W.Char(encTable[c]); END;

			c2 := c2 MOD ASH(1, 6);
			IF k>=3 THEN W.Char(encTable[c2]); END;
			INC(l, 4)
		END OutCode;
	BEGIN
		l := 0;
		R.Char(chars[0]); i := 1;
		WHILE R.res=Streams.Ok DO
			IF i >= 3 THEN OutCode(i); i := 0 END;
			R.Char(chars[i]); INC(i)
		END;
		DEC(i);
		IF i > 0 THEN
			j := i;
			WHILE i < 3 DO chars[i] := 0X; INC(i) END;
			OutCode(j);
			WHILE j<3 DO W.Char("="); INC(j) END;
		END;
		W.Update;
	END Encode;

	PROCEDURE InitTables;
		VAR i, max: INTEGER;
	BEGIN
		max := ORD("Z")-ORD("A");
		FOR i := 0 TO max DO encTable[i] := CHR(i+ORD("A")) END;
		INC(max);
		FOR i := max TO max+ORD("z")-ORD("a") DO encTable[i] := CHR(i-max+ORD("a")) END;
		max := max+ORD("z")-ORD("a")+1;
		FOR i := max TO max+ORD("9")-ORD("0") DO encTable[i] := CHR(i-max+ORD("0")) END;
		encTable[62] := "+";
		encTable[63] := "/";
		FOR i := 0 TO 127 DO decTable[i] := -1 END;
		FOR i := 0 TO 63 DO decTable[ORD(encTable[i])] := i END
	END InitTables;

	(*
	(* testing: expected behaviour:  "admin:1234" encode => "YWRtaW46MTIzNA==" decode => "admin:1234"*)
	PROCEDURE Test*;
	VAR W:Streams.StringWriter; R: Streams.StringReader; plain, base64: ARRAY 80 OF CHAR;
	BEGIN
		NEW(W,80); NEW(R,80);
		KernelLog.String('admin:1234 => '); KernelLog.Ln;
		R.Set('admin:1234');
		Encode(R,W);
		W.Get(base64);
		KernelLog.String(base64); KernelLog.String(" => ");

		NEW(W,80); NEW(R,80);
		R.Set(base64);
		Decode(R,W);
		W.Get(plain);
		KernelLog.String(plain); KernelLog.Ln;
	END Test;
	*)

BEGIN
	InitTables;
END Base64.

Base64.Test
System.Free Base64 ~
