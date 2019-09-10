(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE PasswordFields IN Oberon;	(** portable *) (* ejz,  *)
	IMPORT Files, Objects, Display, Oberon, Gadgets, TextFields;

	CONST
		CR = CHR(13);
		DEL = CHR(127);
		Left = CHR(196);
		Right = CHR(195);
		Tab = CHR(9);
		right = 0;

	TYPE
		Frame* = POINTER TO FrameDesc;
		FrameDesc* = RECORD (TextFields.TextFieldDesc)
			passWord: ARRAY 64 OF CHAR;
			len: SIGNED32
		END;

	PROCEDURE Copy*(VAR M: Objects.CopyMsg; from, to: Frame);
	BEGIN
		COPY(from.passWord, to.passWord);
		to.len := from.len;
		TextFields.CopyTextField(M, from, to)
	END Copy;

	PROCEDURE Handler*(F: Objects.Object; VAR M: Objects.ObjMsg);
		VAR
			F1: Frame;
			i: SIGNED32;
	BEGIN
		WITH F: Frame DO
			IF M IS Display.FrameMsg THEN
				WITH M: Display.FrameMsg DO
					IF ((M.F = NIL) OR (M.F = F)) THEN
						IF M IS Oberon.InputMsg THEN
							WITH M: Oberon.InputMsg DO
								IF (M.id = Oberon.consume) & (F.carpos >= 0) THEN
									IF M.ch = DEL THEN
										IF (F.len > 0) & (F.carpos > 0) THEN
											i := F.carpos-1;
											WHILE i < F.len DO
												F.passWord[i] := F.passWord[i+1];
												INC(i)
											END;
											DEC(F.len)
										END;
										TextFields.TextFieldHandler(F, M)
									ELSIF (M.ch >= " ") & (M.ch < DEL) & (F.len < 63) THEN
										i := F.len;
										WHILE i > F.carpos DO
											F.passWord[i] := F.passWord[i-1];
											DEC(i)
										END;
										F.passWord[F.carpos] := M.ch;
										INC(F.len);
										M.ch := "*";
										TextFields.TextFieldHandler(F, M)
									ELSIF (M.ch = CR) OR (M.ch = Left) OR (M.ch = Right) OR (M.ch = Tab) THEN
										TextFields.TextFieldHandler(F, M)
									END
								ELSIF (M.id # Oberon.track) OR ~(right IN M.keys) THEN
									TextFields.TextFieldHandler(F, M)
								END
							END
						ELSIF ~(M IS Oberon.ConsumeMsg) THEN
							TextFields.TextFieldHandler(F, M)
						END
					END
				END
			ELSIF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO
					IF M.stamp = F.stamp THEN
						M.obj := F.dlink
					ELSE
						NEW(F1);
						F.stamp := M.stamp;
						F.dlink := F1;
						Copy(M, F, F1);
						M.obj := F1
					END
				END
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					M.obj := NIL; M.res := 0
				END
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					TextFields.TextFieldHandler(F, M);
					IF M.id = Objects.store THEN
						F.passWord[F.len] := 0X;
						Files.WriteString(M.R, F.passWord);
						Files.WriteLInt(M.R, F.len)
					ELSIF M.id = Objects.load THEN
						Files.ReadString(M.R, F.passWord);
						Files.ReadLInt(M.R, F.len)
					END
				END
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN
							M.class := Objects.String;
							M.s := "PasswordFields.New";
							M.res := 0
						ELSIF M.name = "Value" THEN
							M.class := Objects.String;
							F.passWord[F.len] := 0X;
							COPY(F.passWord, M.s);
							M.res := 0
						ELSE
							TextFields.TextFieldHandler(F, M)
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "Value" THEN
							IF M.class = Objects.String THEN
								COPY(M.s, F.passWord);
								i := 0;
								WHILE F.passWord[i] # 0X DO
									M.s[i] := "*"; INC(i)
								END;
								M.s[i] := 0X;
								F.len := i;
								TextFields.TextFieldHandler(F, M)
							END
						ELSE
							TextFields.TextFieldHandler(F, M)
						END
					ELSIF M.id = Objects.enum THEN
						Gadgets.framehandle(F, M);
						M.Enum("Color");
						M.Enum("Cmd");
						M.res := 0
					ELSE
						TextFields.TextFieldHandler(F, M)
					END
				END
			ELSE
				TextFields.TextFieldHandler(F, M)
			END
		END
	END Handler;

	PROCEDURE New*;
		VAR F: Frame;
	BEGIN
		NEW(F);
		TextFields.InitTextField(F);
		F.passWord := "";
		F.len := 0;
		F.handle := Handler;
		Objects.NewObj := F
	END New;

END PasswordFields.
