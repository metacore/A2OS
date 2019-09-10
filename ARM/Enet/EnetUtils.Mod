MODULE EnetUtils;

IMPORT
	S := SYSTEM;

TYPE
	Int8 = SIGNED8;
	Int16 = SIGNED16;
	Int32 = SIGNED32;

	UnalignedInt32* = ARRAY 4 OF Int8;

	(*
		Get a string representation of an integer (in decimal format)
	*)
	PROCEDURE IntToStr*(x: SIGNED64; VAR str: ARRAY OF CHAR);
	VAR
		i, j: Int32;
		ch: CHAR;
		negative: BOOLEAN;
	BEGIN
		IF x < 0 THEN
			IF x = MIN(SIGNED64) THEN
				str := "-9223372036854775808";
				RETURN;
			ELSE
				x := -x;
				negative := TRUE;
			END;
		ELSE negative := FALSE;
		END;
		i := 0;
		REPEAT
			str[i] := CHR((x MOD 10)+48);
			x := x DIV 10;
			INC(i);
		UNTIL x = 0;
		(* reverse the output string *)
		IF ~negative THEN DEC(i); ELSE str[i] := "-"; END;
		FOR j := 0 TO (i DIV 2) BY 1 DO
			ch := str[j];
			str[j] := str[i-j];
			str[i-j] := ch;
		END;
		str[i+1] := 0X;
	END IntToStr;

	PROCEDURE StrAppend*(VAR dst: ARRAY OF CHAR; CONST src: ARRAY OF CHAR);
	VAR
		i, j: Int32;
	BEGIN
		i := 0; j := 0;
		WHILE (i < LEN(dst)) & (dst[i] # 0X) DO INC(i); END;
		WHILE (j < LEN(src)) & (src[j] # 0X) DO
			dst[i + j] := src[j];
			INC(j);
		END;
		dst[i + j] := src[j];
	END StrAppend;

	(** Switch endianness of a 16-bit integer *)
	PROCEDURE SwitchEndianness16*(x: Int16): Int16;
	TYPE Array2OfInt8 = ARRAY 2 OF Int8;
	VAR xx, yy: Array2OfInt8;
	BEGIN
		xx := S.VAL(Array2OfInt8,x);
		yy[0] := xx[1]; yy[1] := xx[0];
		RETURN S.VAL(Int16,yy);
	END SwitchEndianness16;

	(** Switch endianness of a 32-bit integer *)
	PROCEDURE SwitchEndianness32*(x: Int32): Int32;
	TYPE Array4OfInt8 = ARRAY 4 OF Int8;
	VAR xx, yy: Array4OfInt8;
	BEGIN
		xx := S.VAL(Array4OfInt8,x);
		yy[0] := xx[3]; yy[1] := xx[2]; yy[2] := xx[1]; yy[3] := xx[0];
		RETURN S.VAL(Int32,yy);
	END SwitchEndianness32;

	OPERATOR ":="*(VAR y: Int32; x: UnalignedInt32);
	BEGIN
		S.MOVE(ADDRESSOF(x),ADDRESSOF(y),SIZEOF(Int32));
	END ":=";

	OPERATOR ":="*(VAR y: UnalignedInt32; x: Int32);
	BEGIN
		S.MOVE(ADDRESSOF(x),ADDRESSOF(y),SIZEOF(Int32));
	END ":=";

	OPERATOR "="*(x: Int32; y: UnalignedInt32): BOOLEAN;
	VAR y1: Int32;
	BEGIN
		S.MOVE(ADDRESSOF(y),ADDRESSOF(y1),SIZEOF(Int32));
		RETURN x = y1;
	END "=";

	OPERATOR "="*(x: UnalignedInt32; y: Int32): BOOLEAN;
	VAR x1: Int32;
	BEGIN
		S.MOVE(ADDRESSOF(x),ADDRESSOF(x1),SIZEOF(Int32));
		RETURN x1 = y;
	END "=";

END EnetUtils.
