(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxFonts0 IN Oberon; (** non-portable *)	(* eos  *)

	(**
		Non-portable part of GfxFonts

			Native Oberon: Builder.Compile GfxFonts0.Mod ~
			Windows Oberon: Builder.Compile \D=WIN GfxFonts0.Mod ~
	**)

	(*
		16.2.99 - made unknown font types have ppm=MIN(SIGNED32) (to avoid .Md?)
		20.4.99 - merged Native and Windows version (using Builder preprocessor)
		22.02.2000 - made name matching more robust to be compatible with device specifiers in Native
		30.03.2000 - fixed dimensionless fonts not being recognized (Elektra)
	*)

	IMPORT
		FileDir, Strings;


	VAR
		Name, Style: ARRAY 32 OF CHAR;
		PPM, FPPM, Error: SIGNED16;



	PROCEDURE EnumFile (name: ARRAY OF CHAR; time, date, size: SIGNED32; VAR continue: BOOLEAN);
		CONST isdir = FALSE;
		VAR i, ppm: SIGNED16; s: ARRAY 4 OF CHAR;

	BEGIN
		IF ~isdir THEN
			i := 0; ppm := 0;
			WHILE (name[i] # 0X) & (name[i] # ".") & (name[i] < "0") OR ("9" < name[i]) DO INC(i) END;
			WHILE ("0" <= name[i]) & (name[i] <= "9") DO
				ppm := 10*ppm + ORD(name[i]) - ORD("0");
				INC(i)
			END;
			IF ppm = 0 THEN ppm := 10 END;
			IF (Style = "") & (name[i] = ".") OR (CAP(Style[0]) = CAP(name[i])) THEN
				WHILE (name[i] # 0X) & (name[i] # ".") DO INC(i) END;
				IF name[i] = "." THEN INC(i) END;
				s[0] := name[i]; s[1] := name[i+1]; s[2] := name[i+2]; s[3] := 0X;
				IF s = "Scn" THEN
				ELSIF s = "Pr2" THEN ppm := SHORT(200 * LONG(ppm) DIV 91)
				ELSIF s = "Pr3" THEN ppm := SHORT(300 * LONG(ppm) DIV 91)
				ELSIF s = "Pr6" THEN ppm := SHORT(600 * LONG(ppm) DIV 91)
				ELSE ppm := MIN(SIGNED16)
				END;
				IF ABS(PPM - ppm) < Error THEN
					Error := ABS(PPM - ppm); COPY(name, Name); FPPM := ppm;
					IF Error = 0 THEN continue := FALSE END
				END
			END
		END
	END EnumFile;

	(** find raster font file that most closely matches the requested number of pixels per em **)
	PROCEDURE Find* (VAR family, style: ARRAY OF CHAR; ppm: SIGNED16; VAR name: ARRAY OF CHAR; VAR fppm: SIGNED16);
		VAR pattern: ARRAY 64 OF CHAR;
	BEGIN
		Name := ""; FPPM := 0;
		COPY(style, Style); PPM := ppm; Error := MAX(SIGNED16);
		COPY(family, pattern); Strings.AppendCh(pattern, "*");
		IF style = "Bold" THEN Strings.AppendCh(pattern, "b")
		ELSIF style = "Italic" THEN Strings.AppendCh(pattern, "i")
		ELSIF style = "Medium" THEN Strings.AppendCh(pattern, "m")
		ELSIF style = "BoldItalic" THEN Strings.AppendCh(pattern, "j")
		END;
		Strings.Append(pattern, ".*.Fnt");

		FileDir.Enumerate(pattern, FALSE, EnumFile);

		COPY(Name, name); fppm := FPPM
	END Find;


END GfxFonts0.
