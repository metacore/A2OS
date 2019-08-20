MODULE WMCharCodes; (** AUTHOR "TF"; PURPOSE "Convert encoded byte arrays to UTF8 arrays"; *)
(* quick and dirty implementation to test GB2312 in the webbrowser *)


IMPORT
	Strings, UTF8Strings, Files, Streams;

VAR
	gb2312Table : ARRAY 65536 OF LONGINT;

PROCEDURE GB2312ToUTF8*(from : Strings.String) : Strings.String;
VAR buf : Strings.Buffer;
	w : Streams.Writer;
	temp : ARRAY 8 OF CHAR;
	i, len : SIZE; code: WORD;
BEGIN
	NEW(buf, LEN(from) * 2);
	w := buf.GetWriter();
	i := 0;
	WHILE i < LEN(from) - 1 DO
		code := ORD(from[i]) * 256 + ORD(from[i + 1]);
		INC(i, 2);
		IF UTF8Strings.EncodeChar(gb2312Table[code MOD 10000H], temp, len) THEN
			w.String(temp)
		ELSE
			w.Char("*")
		END;
	END;
	RETURN buf.GetString()

END GB2312ToUTF8;

PROCEDURE LoadGBTable;
VAR f : Files.File;
	r : Files.Reader;
	codeS, unicodeS : ARRAY 8 OF CHAR;
	code, unicode: LONGINT; res : WORD;
BEGIN
	f := Files.Old("gb2312.txt");
	Files.OpenReader(r, f, 0);
	WHILE r.res = 0 DO
		IF r.Peek() = "#" THEN r.SkipLn
		ELSE
			IF r.Peek() = "0" THEN
				r.Token(codeS); r.SkipWhitespace; r.Token(unicodeS); r.SkipLn;
				Strings.Delete(codeS, 0, 2);
				Strings.HexStrToInt(codeS, code, res);
				Strings.Delete(unicodeS, 0, 2);
				Strings.HexStrToInt(unicodeS, unicode, res);
				gb2312Table[code MOD 10000H] := unicode;
			ELSE r.SkipLn;
			END;
		END;
	END;
END LoadGBTable;

BEGIN
	LoadGBTable;

END WMCharCodes.

WMCharCodes.MakeCodePage ~

System.Free WMCharCodes ~

