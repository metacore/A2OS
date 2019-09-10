MODULE TFLog; (** AUTHOR "TF"; PURPOSE "Log utility"; *)

IMPORT KernelLog, Clock, Files;

CONST
	Unknown* = 0;
	Information* = 1;
	Warning* = 2;
	Error* = 3;

TYPE
	Log* = OBJECT
	VAR
		appName : ARRAY 64 OF CHAR;
		logPos : SIGNED32;
		logLine : ARRAY 1024 OF CHAR;
		kind : SIGNED32;
		locked : BOOLEAN;
		disableLogToOut : BOOLEAN;
		f : Files.File;
		w : Files.Writer;

		PROCEDURE &Init*(logName : ARRAY OF CHAR);
		BEGIN
			COPY(logName, appName)
		END Init;

		PROCEDURE SetLogFile*(fn : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			IF f # NIL THEN Files.Register(f) END;
			IF fn = "" THEN f := NIL
			ELSE
				f := Files.Old(fn);
				IF f = NIL THEN f := Files.New(fn) END;
				Files.OpenWriter(w, f, f.Length())
			END
		END SetLogFile;

		PROCEDURE SetLogToOut*(enabled : BOOLEAN);
		BEGIN {EXCLUSIVE}
			disableLogToOut := ~enabled
		END SetLogToOut;

		PROCEDURE SetKind(kind : SIGNED32);
		BEGIN {EXCLUSIVE}
			SELF.kind := kind
		END SetKind;

		PROCEDURE InternalLn;
		BEGIN
			logPos := 0; kind := Unknown;
			IF ~disableLogToOut THEN
				KernelLog.Enter;
				IF kind = Information THEN KernelLog.String("[I] ") END;
				IF kind = Warning THEN KernelLog.String("[W] ") END;
				IF kind = Error THEN KernelLog.String("[E] ") END;
				KernelLog.String(appName); KernelLog.String(" : "); KernelLog.String(logLine);
				KernelLog.Exit
			END;
			logLine[0] := 0X;
			IF f # NIL THEN w.Ln; w.Update; f.Update() END
		END InternalLn;

		PROCEDURE Ln*;
		BEGIN {EXCLUSIVE}
			InternalLn
		END Ln;

		PROCEDURE Enter*;
		BEGIN {EXCLUSIVE}
			AWAIT(~locked); locked := TRUE
		END Enter;

		PROCEDURE Exit*;
		BEGIN {EXCLUSIVE}
			InternalLn;
			locked := FALSE
		END Exit;

		PROCEDURE InternalChar(x: CHAR);
		BEGIN
			IF logPos >= LEN(logLine) - 1 THEN InternalLn END;
			logLine[logPos] := x; logLine[logPos + 1] := 0X; INC(logPos);
			IF f # NIL THEN w.Char(x) END
		END InternalChar;

		PROCEDURE Char*(x: CHAR);
		BEGIN {EXCLUSIVE}
			InternalChar(x)
		END Char;

		PROCEDURE InternalString*(VAR x: ARRAY OF CHAR);
		VAR i : SIGNED32;
		BEGIN
			WHILE (i < LEN(x)) & (x[i] # 0X) DO InternalChar(x[i]); INC(i) END
		END InternalString;

		PROCEDURE String*(x: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			InternalString(x)
		END String;

		PROCEDURE Hex*(x, w: SIGNED32);
		VAR i, j: SIGNED32; buf: ARRAY 10 OF CHAR;
		BEGIN {EXCLUSIVE}
			IF w >= 0 THEN j := 8 ELSE j := 2; w := -w END;
			FOR i := j+1 TO w DO InternalChar(" ") END;
			FOR i := j-1 TO 0 BY -1 DO
				buf[i] := CHR(x MOD 10H + 48);
				IF buf[i] > "9" THEN
					buf[i] := CHR(ORD(buf[i]) - 48 + 65 - 10)
				END;
				x := x DIV 10H
			END;
			buf[j] := 0X;
			InternalString(buf)
		END Hex;

		PROCEDURE Int*(x: SIGNED64; w: SIGNED32);
		VAR i: SIGNED32; x0: SIGNED64; a: ARRAY 21 OF CHAR;
		BEGIN {EXCLUSIVE}
			IF x < 0 THEN
				IF x = MIN( SIGNED64 ) THEN
					DEC(w, 20);
					WHILE w > 0 DO Char(" "); DEC(w) END;
					 a := "-9223372036854775808"; InternalString(a);
					RETURN
				ELSE
					DEC(w); x0 := -x
				END
			ELSE
				x0 := x
			END;
			i := 0;
			REPEAT
				a[i] := CHR(x0 MOD 10 + 30H); x0 := x0 DIV 10; INC(i)
			UNTIL x0 = 0;
			WHILE w > i DO InternalChar(" "); DEC(w) END;
			IF x < 0 THEN InternalChar("-") END;
			REPEAT DEC(i); InternalChar(a[i]) UNTIL i = 0
		END Int;

		PROCEDURE TimeStamp*;
		TYPE TimeDate = RECORD h, m, s, day,month,year: SIGNED32 END;
			VAR s : ARRAY 32 OF CHAR;
				now : TimeDate;

			PROCEDURE LZ(v, len: SIGNED32; VAR s: ARRAY OF CHAR; VAR pos: SIGNED32);
			VAR i: SIGNED32;
			BEGIN
				FOR i := 1 TO len DO s[pos+len-i] := CHR(ORD("0")+v MOD 10); v := v DIV 10 END;
				INC(pos, len)
			END LZ;

			PROCEDURE GetTime(VAR dt: TimeDate);
			BEGIN
				Clock.Get(dt.h, dt.year);
				dt.s := dt.h MOD 64; dt.h := dt.h DIV 64;
				dt.m := dt.h MOD 64; dt.h := dt.h DIV 64;
				dt.h := dt.h MOD 24;
				dt.day := dt.year MOD 32; dt.year := dt.year DIV 32;
				dt.month := dt.year MOD 16; dt.year := dt.year DIV 16;
				INC(dt.year, 1900)
			END GetTime;

			PROCEDURE TimeDateToStr(dt: TimeDate; VAR s: ARRAY OF CHAR);
			VAR p: SIGNED32;
			BEGIN
				LZ(dt.day, 2, s, p); s[p] := "."; INC(p);
				LZ(dt.month, 2, s, p); s[p] := "."; INC(p);
				LZ(dt.year, 2, s, p); s[p] := " "; INC(p);
				LZ(dt.h, 2, s, p); s[p] := ":"; INC(p);
				LZ(dt.m, 2, s, p); s[p] := ":"; INC(p);
				LZ(dt.s, 2, s, p); s[p] := 0X
			END TimeDateToStr;

		BEGIN
			GetTime(now);
			TimeDateToStr(now, s);
			InternalString(s); InternalChar(" ")
		END TimeStamp;

		PROCEDURE Close*;
		BEGIN
			IF f # NIL THEN Files.Register(f)
			END
		END Close;

	END Log;

END TFLog.


System.Free TFLog ~