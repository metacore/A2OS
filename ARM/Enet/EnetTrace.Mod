MODULE EnetTrace;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack, trace utilities
*)

IMPORT Timing := EnetTiming, Utils := EnetUtils;

CONST
	(** New line types *)
	LnCRLF* = 0;
	LnCR* = 1;
	LnLF* = 2;

	LnType* = LnCRLF;

TYPE
	Int = SIGNED32;

	StringType* = ARRAY OF CHAR;
	LongString* = ARRAY 2048 OF CHAR;

	(* concatenate two strings "str1" and "str2" into string "str" (no inplace possible!) *)
	PROCEDURE Concat(CONST str1, str2: ARRAY OF CHAR; VAR str: ARRAY OF CHAR);
	VAR i, j: Int;
	BEGIN
		i := 0; WHILE str1[i] # 0X DO str[i] := str1[i]; INC(i); END;
		j := 0; WHILE str2[j] # 0X DO str[i] := str2[j]; INC(i); INC(j); END;
		str[i] := 0X;
	END Concat;

	(* append string "str1" to string "str" (no inplace possible!) *)
	PROCEDURE Append(VAR str: ARRAY OF CHAR; CONST str1: ARRAY OF CHAR);
	VAR i, j: Int;
	BEGIN
		i := 0; WHILE str[i] # 0X DO INC(i); END;
		j := 0; WHILE str1[j] # 0X DO str[i] := str1[j]; INC(i); INC(j); END;
		str[i] := 0X;
	END Append;

	(* prepend string "str1" to string "str" (no inplace possible!) *)
	PROCEDURE Prepend(CONST str1: ARRAY OF CHAR; VAR str: ARRAY OF CHAR);
	VAR i, j: Int;
	BEGIN
		i := 0; WHILE str1[i] # 0X DO INC(i); END;
		j := 0; WHILE str[j] # 0X DO INC(j); END;
		WHILE j > 0 DO DEC(j); str[i+j] := str[j]; END;
		WHILE j < i DO str[j] := str1[j]; INC(j); END;
	END Prepend;

	(**
		Get a hexadecimal representation of a decimal integer

		numDigits: number of used hexadecimal digits
	*)
	PROCEDURE Hx*(x: SIGNED64; numDigits: Int): LongString;
	VAR
		str: LongString;
		ch: CHAR;
	BEGIN
		DEC(numDigits);
		str[numDigits+1] := 0X;
		WHILE numDigits >= 0 DO
			ch := CHR(x MOD 10H + ORD("0"));
			IF ch > "9" THEN ch := CHR((x MOD 10H - 10) + ORD("A")) END;
			str[numDigits] := ch;
			x := x DIV 10H;
			DEC(numDigits);
		END;
		RETURN str;
	END Hx;

	OPERATOR "&"*(CONST x, y: StringType): LongString;
	VAR str: LongString;
	BEGIN
		Concat(x,y,str);
		RETURN str;
	END "&";

	OPERATOR "&"*(CONST x: StringType; y: SIGNED64): LongString;
	VAR str: LongString;
	BEGIN
		Utils.IntToStr(y, str);
		Prepend(x,str);
		RETURN str;
	END "&";

	OPERATOR "&"*(x: SIGNED64; CONST y: StringType): LongString;
	VAR str: LongString;
	BEGIN
		Utils.IntToStr(x,str);
		Append(str,y);
		RETURN str;
	END "&";

	OPERATOR "&"*(CONST x: StringType; y: BOOLEAN): LongString;
	VAR str: LongString;
	BEGIN
		IF y THEN str := "TRUE"; ELSE str := "FALSE"; END;
		Prepend(x,str);
		RETURN str;
	END "&";

	OPERATOR "&"*(x: BOOLEAN; CONST y: StringType): LongString;
	VAR str: LongString;
	BEGIN
		IF x THEN str := "TRUE"; ELSE str := "FALSE"; END;
		Append(str,y);
		RETURN str;
	END "&";

	PROCEDURE String*(CONST str: ARRAY OF CHAR);
	BEGIN
		string(str);
	END String;

	PROCEDURE StringLn*(CONST str: ARRAY OF CHAR);
	BEGIN
		string(str); string(ln);
	END StringLn;

	PROCEDURE Enter*;
	BEGIN
		IF acquire # NIL THEN acquire; END;
	END Enter;

	PROCEDURE Exit*;
	BEGIN
		IF release # NIL THEN release; END;
	END Exit;

VAR
	string*: PROCEDURE{DELEGATE}(CONST str: ARRAY OF CHAR);
	acquire*, release*: PROCEDURE{DELEGATE}();

	ln: ARRAY 3 OF CHAR;
	refTimestamps: ARRAY 32 OF Timing.Time;

	PROCEDURE RefTimestamp*(id: Int);
	BEGIN
		refTimestamps[id] := Timing.getTimeCounter();
	END RefTimestamp;

	PROCEDURE Timestamp*(id: Int; CONST msg: ARRAY OF CHAR);
	VAR t: Timing.Time;
	BEGIN
		t := Timing.getTimeCounter() - refTimestamps[id];
		StringLn(msg & t);
	END Timestamp;

BEGIN
	CASE LnType OF
		|LnCRLF: ln[0] := 0DX; ln[1] := 0AX; ln[2] := 0X;
		|LnCR: ln[0] := 0DX;  ln[1] := 0X;
		|LnLF: ln[0] := 0AX;  ln[1] := 0X;
	END;
END EnetTrace.

