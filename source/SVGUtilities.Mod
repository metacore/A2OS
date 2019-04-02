MODULE SVGUtilities;

IMPORT Strings, KernelLog;

(* Print a message to the log *)
PROCEDURE Log*(msg: ARRAY OF CHAR);
BEGIN
	KernelLog.String(msg); KernelLog.Ln
END Log;

(* Report a warning *)
PROCEDURE Warning*(msg: ARRAY OF CHAR);
BEGIN
	KernelLog.String("SVG Warning: "); KernelLog.String(msg); KernelLog.Ln
END Warning;

(* Report an error *)
PROCEDURE Error*(msg: ARRAY OF CHAR);
BEGIN
	KernelLog.String("SVG Error: "); KernelLog.String(msg); KernelLog.Ln
END Error;

(* Is ch a lowercase character? *)
PROCEDURE IsLowercase*(ch: CHAR):BOOLEAN;
BEGIN
	RETURN (ch >= "a") & (ch <= "z")
END IsLowercase;

(* Is ch a uppercase character? *)
PROCEDURE IsUppercase*(ch: CHAR):BOOLEAN;
BEGIN
	RETURN (ch >= "A") & (ch <= "Z")
END IsUppercase;

(* Is ch an alphabetic character? *)
PROCEDURE IsAlpha*(ch: CHAR):BOOLEAN;
BEGIN
	RETURN IsLowercase(ch) OR IsUppercase(ch)
END IsAlpha;

(* Skip any whitespace characters *)
PROCEDURE SkipWhiteSpace*(VAR i: SIZE; s: Strings.String);
BEGIN
	WHILE (s[i] = 20X) OR
		(s[i] = 09X) OR
		(s[i] = 0AX) OR
		(s[i] = 0DX) DO INC(i) END
END SkipWhiteSpace;

(* Skip a specified character *)
PROCEDURE SkipChar*(VAR i: SIZE; s: Strings.String; c: CHAR);
BEGIN
	IF s[i] # c THEN
		Error("Expected a different character");
		Log(s^);
	END;
	INC(i)
END SkipChar;

(* Optionally skip a specified character *)
PROCEDURE SkipCharOptional*(VAR i: SIZE; s: Strings.String; c: CHAR);
BEGIN
	IF s[i] = c THEN INC(i) END
END SkipCharOptional;

(* Skip a comma and/or any whitespace characters *)
PROCEDURE SkipCommaWhiteSpace*(VAR i: SIZE; s: Strings.String);
BEGIN
	SkipWhiteSpace(i, s);
	SkipCharOptional(i, s, ',');
	SkipWhiteSpace(i, s);
END SkipCommaWhiteSpace;

(* Convert the substring beginning at position i in str into a real value. Leading whitespace is ignored.
	After the conversion i points to the first character after the real value. *)
PROCEDURE StrToFloatPos*(VAR str: ARRAY OF CHAR; VAR val: LONGREAL; VAR i: SIZE);
VAR noStr: ARRAY 16 OF CHAR;
	count: SIZE;
BEGIN
	WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;

	count := 0;
	IF str[i] = "-" THEN
		noStr[count] := str[i]; INC(count); INC(i);
		WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END
	END;
	IF str[i] = "+" THEN
		 INC(i);
		WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END
	END;
	WHILE (str[i] >= "0") & (str[i] <= "9") DO noStr[count] := str[i]; INC(count); INC(i) END;

	IF str[i] = "." THEN
		noStr[count] := str[i]; INC(count); INC(i);
		WHILE (str[i] >= "0") & (str[i] <= "9") DO noStr[count] := str[i]; INC(count); INC(i) END;
	END;

	IF (str[i] = "D") OR (str[i] ="E") OR (str[i] = "d") OR (str[i] ="e") THEN
		noStr[count] := CAP(str[i]); INC(count); INC(i);
		IF str[i] = "-" THEN
			noStr[count] := str[i]; INC(count); INC(i);
		END;
		WHILE (str[i] >= "0") & (str[i] <= "9") DO noStr[count] := str[i]; INC(count); INC(i) END;
	END;

	noStr[count] := 0X;
	Strings.StrToFloat(noStr, val)
END StrToFloatPos;

END SVGUtilities.
