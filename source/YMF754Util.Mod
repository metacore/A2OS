MODULE YMF754Util;

IMPORT
	Commands, Streams, Codecs, Files, Strings;

CONST
	FNameInstRAM = "YMF754.Bin";

PROCEDURE Open* (context : Commands.Context);
VAR
	name, str: ARRAY 256 OF CHAR;
	in: Streams.Reader;
	w, binW: Files.Writer;
	token: ARRAY 1024 OF CHAR;
	f, binF: Files.File;
	c, l, res: LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(name);
	c := 1;

	in := Codecs.OpenInputStream (name);
	IF in # NIL THEN

		Strings.Concat (name, ".Bin", str);
		binF := Files.New (FNameInstRAM);
		Files.OpenWriter (binW, binF, 0);

		REPEAT

			in.SkipWhitespace;
			in.Token (token);

			IF Strings.Pos ("{", token) # -1 THEN
				Strings.IntToStr (c, str); INC (c);
				Strings.Concat (name, str, str);
				Strings.Concat (str, ".txt", str);
				f := Files.New (str);
				Files.OpenWriter (w, f, 0);

				Strings.Concat ("Creating file: ", str, str);
				context.out.String(str); context.out.Ln;
			END;

			IF Strings.Pos ("0x", token) = 0 THEN
				Strings.Delete (token, 0, 2);
				Strings.TrimRight (token, ",");

				IF w # NIL THEN
					w.String (token); w.Ln;
				END;

				IF (w # NIL) & (binW # NIL) THEN
					Strings.HexStrToInt (token, l, res);
					IF res = Strings.Ok THEN
						binW.RawLInt (l);
					ELSE
						context.error.String("Error!!!"); context.error.Ln;
					END;
				END;

			END;

			IF Strings.Pos ("}", token) # -1 THEN
				context.out.String("Closing file"); context.out.Ln;
				w.Update;
				Files.Register (f);
			END;

		UNTIL in.res = Streams.EOF;

		binW.Update;
		Files.Register (binF);
	END;
END Open;

END YMF754Util.

System.Free YMF754Util~
YMF754Util.Open 724hwmcode.c~

Tar.Create Sage.YMF754.tar
	Sage.YMF754.Mod
	YMF754.Bin
	Sage.DriverDatabase.XML
	Sage.YMF754Util.Mod
	724hwmcode.c
	Sage.YMF754.txt
~


