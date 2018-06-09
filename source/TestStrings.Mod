MODULE TestStrings; (** AUTHOR "staubesv"; PURPOSE "Testbed for Strings.Mod"; *)

IMPORT
	SYSTEM,
	Commands, Strings, KernelLog;

CONST
	Step = MAX(LONGINT) DIV 5;

PROCEDURE TestIntegerConversion*(context : Commands.Context);
VAR i, temp : LONGINT; string : ARRAY 16 OF CHAR;
BEGIN
	context.out.String("Test integer <-> string conversion... "); context.out.Update;
	i := MIN(LONGINT);
	WHILE (i < MAX(LONGINT)) DO
		Strings.IntToStr(i, string);
		Strings.StrToInt(string, temp);
		ASSERT(i = temp);
		INC(i);
		IF (i MOD Step = 0) THEN
			IF (i < 0) THEN
				context.out.Int(ENTIER(100* ((MAX(LONGINT) + i)  / MAX(LONGINT) / 2)), 0);
			ELSE
				context.out.Int(ENTIER(100* (i / MAX(LONGINT) / 2)) + 50, 0);
			END;
			context.out.String("% "); context.out.Update;
		END;
	END;
	Strings.IntToStr(MAX(LONGINT), string);
	Strings.StrToInt(string, temp);
	ASSERT(temp = MAX(LONGINT));
	context.out.String("100% done."); context.out.Ln;
END TestIntegerConversion;

PROCEDURE TestHexConversion*(context : Commands.Context);
VAR i, val, res : LONGINT; string : ARRAY 16 OF CHAR;
BEGIN
	context.out.String("Test hex <-> string conversion... "); context.out.Update;
	i := MIN(LONGINT);
	WHILE (i < MAX(LONGINT)) DO
		Strings.IntToHexStr(i, 8, string);
		Strings.HexStrToInt(string, val, res);
		IF (res # Strings.Ok) OR (i # val) THEN
			context.out.String("Error for string "); context.out.String(string); context.out.Ln;
		END;
		ASSERT((res = Strings.Ok) & (i = val));
		INC(i);
		IF (i MOD Step = 0) THEN
			IF (i < 0) THEN
				context.out.Int(ENTIER(100* ((MAX(LONGINT) + i)  / MAX(LONGINT) / 2)), 0);
			ELSE
				context.out.Int(ENTIER(100* (i / MAX(LONGINT) / 2)) + 50, 0);
			END;
			context.out.String("% "); context.out.Update;
		END;
	END;
	Strings.IntToHexStr(i, 8, string);
	Strings.HexStrToInt(string, val, res);
	ASSERT((res = Strings.Ok) & (i = val));
	context.out.String("100% done."); context.out.Ln;
END TestHexConversion;

PROCEDURE TestNegativeHexConversion*(context : Commands.Context);
VAR i : LONGINT;

	PROCEDURE Test(number : HUGEINT);
	VAR string, signedString : ARRAY 16 OF CHAR; val, idx, res : LONGINT;
	BEGIN
		Strings.IntToHexStr(number, 8, string);
		signedString[0] := "-";
		idx := 0; WHILE (string[idx] # 0X) DO signedString[idx + 1] := string[idx]; INC(idx); END;
		signedString[idx + 1] := 0X;
		Strings.HexStrToInt(signedString, val, res);
		IF (res # Strings.Ok) OR (-i # val) THEN
			context.out.String("Error for string "); context.out.String(string); context.out.Ln;
		END;
		ASSERT((res = Strings.Ok) & (-i = val));
	END Test;

	PROCEDURE TestMaxLongintPlus1;
	VAR string : ARRAY 16 OF CHAR; val, res : LONGINT;
	BEGIN
		string := "-80000000";
		Strings.HexStrToInt(string, val, res);
		ASSERT((res = Strings.Ok) & (val = MIN(LONGINT)));
	END TestMaxLongintPlus1;

BEGIN
	context.out.String("Test negative hex <-> string conversion... "); context.out.Update;
	i := 0;
	WHILE (i < MAX(LONGINT)) DO
		Test(i);
		INC(i);
		IF (i MOD Step = 0) THEN
			IF (i < 0) THEN
				context.out.Int(ENTIER(100* ((MAX(LONGINT) + i)  / MAX(LONGINT) / 2)), 0);
			ELSE
				context.out.Int(ENTIER(100* (i / MAX(LONGINT) / 2)) + 50, 0);
			END;
			context.out.String("% "); context.out.Update;
		END;
	END;
	Test(MAX(LONGINT));
	TestMaxLongintPlus1;
	context.out.String("100% done."); context.out.Ln;
END TestNegativeHexConversion;

PROCEDURE TestSetConversion*(context : Commands.Context);
VAR i : LONGINT; temp : SET; string : ARRAY 64 OF CHAR;
BEGIN
	context.out.String("Test set <-> string conversion...  "); context.out.Update;
	i := MIN(LONGINT);
	WHILE (i < MAX(LONGINT)) DO
		Strings.SetToStr(SYSTEM.VAL(SET, i), string);
		Strings.StrToSet(string, temp);
		IF (SYSTEM.VAL(SET, i) # temp) THEN
			KernelLog.Bits(SYSTEM.VAL(SET, i), 0, 32); KernelLog.String(" # "); KernelLog.Bits(temp, 0, 32); KernelLog.Ln;
		END;
		ASSERT(SYSTEM.VAL(SET, i) = temp);
		INC(i);
		IF (i MOD Step = 0) THEN
			IF (i < 0) THEN
				context.out.Int(ENTIER(100* ((MAX(LONGINT) + i)  / MAX(LONGINT) / 2)), 0);
			ELSE
				context.out.Int(ENTIER(100* (i / MAX(LONGINT) / 2)) + 50, 0);
			END;
			context.out.String("% "); context.out.Update;
		END;
	END;
	Strings.SetToStr(SYSTEM.VAL(SET, MAX(LONGINT)), string);
	Strings.StrToSet(string, temp);
	ASSERT(SYSTEM.VAL(SET, MAX(LONGINT)) = temp);
	context.out.String("100% done."); context.out.Ln;
END TestSetConversion;

PROCEDURE TestSplitJoin*(context : Commands.Context);
VAR string : ARRAY 1024 OF CHAR; separator : CHAR; sa : Strings.StringArray; s : Strings.String; i : LONGINT;
BEGIN
	separator := 0X;
	context.arg.SkipWhitespace; context.arg.String(string);
	context.arg.SkipWhitespace; context.arg.Char(separator);
	context.out.String("String: '"); context.out.String(string); context.out.String("', separator: ");
	IF (separator # 0X) THEN context.out.Char(separator); ELSE context.out.String("none"); END;
	context.out.Ln;
	sa := Strings.Split(string, separator);
	FOR i := 0 TO LEN(sa)-1 DO
		context.out.Int(i, 2); context.out.String(": ");
		context.out.String(sa[i]^);
		context.out.Ln;
	END;
	s := Strings.Join(sa, 0, LEN(sa)-1, separator);
	context.out.String("Joined string: '"); context.out.String(s^); context.out.String("'"); context.out.Ln;
	context.out.String("Success: ");
	IF (s^ = string) THEN context.out.String("Yes"); ELSE context.out.String("No"); END;
	context.out.Ln;
END TestSplitJoin;

PROCEDURE PerformTests*(context : Commands.Context);
BEGIN
	TestIntegerConversion(context);
	TestHexConversion(context);
	TestNegativeHexConversion(context);
	TestSetConversion(context);
END PerformTests;

END TestStrings.

TestStrings.TestIntegerConversion ~
TestStrings.TestHexConversion ~
TestStrings.TestNegativeHexConversion ~
TestStrings.TestSetConversion ~

TestStrings.TestSplitJoin A:/Test/HelloWord/Test.Mod / ~

TestStrings.PerformTests ~

System.Free TestStrings ~
