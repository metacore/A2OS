(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE DBFDump IN Oberon; (* ejz  *)
	IMPORT Files, DBF, Reals IN A2, Strings, Texts, Oberon;

	VAR
		W: Texts.Writer;

	(** Show the contents of a dBASE III data file. *)

	PROCEDURE Show*;
		VAR
			S: Texts.Scanner;
			F: Files.File;
			R: DBF.Reader;
			field: DBF.Field;
			value: DBF.FieldValue;
			i, j: SIGNED32;
		PROCEDURE Error;
		BEGIN
			CASE R.res OF
				DBF.CorruptedFile: Texts.WriteString(W, "corrupted file")
				|DBF.OutOfRange: Texts.WriteString(W, "out of range")
				|DBF.RecordDeleted: Texts.WriteString(W, "record deleted")
				|DBF.TypeNotSupported: Texts.WriteString(W, "type not supported")
			ELSE
				Texts.WriteString(W, "failed")
			END
		END Error;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Texts.Scan(S);
		IF S.class IN {Texts.Name, Texts.String} THEN
			Texts.WriteString(W, "DBFDump.Show "); Texts.WriteString(W, S.s); Texts.Write(W, " ");
			F := Files.Old(S.s);
			IF F # NIL THEN
				DBF.Open(R, F, 0);
				IF R.res = DBF.Done THEN
					Texts.WriteInt(W, R.nRecords, 0); Texts.WriteString(W, " records"); Texts.WriteLn(W); Texts.WriteLn(W);
					field := R.fields;
					WHILE field # NIL DO
						Texts.Write(W, Strings.Tab); Texts.WriteString(W, field.name);
						field := field.next
					END;
					Texts.WriteLn(W); Texts.WriteLn(W);
					i := 0;
					WHILE (i < R.nRecords) & (R.res IN {DBF.Done, DBF.RecordDeleted, DBF.TypeNotSupported}) DO
						Texts.WriteInt(W, i, 0); DBF.Set(R, i);
						IF R.res = DBF.Done THEN
							field := R.fields;
							WHILE (field # NIL) & (R.res IN {DBF.Done, DBF.TypeNotSupported}) DO
								Texts.Write(W, Strings.Tab);
								DBF.Read(R, field, value);
								IF R.res = DBF.Done THEN
									CASE field.type OF
										DBF.Date: Texts.WriteDate(W, 0, value.date)
										|DBF.Logical: IF value.logical THEN
															Texts.WriteString(W, "TRUE")
														ELSE
															Texts.WriteString(W, "FALSE")
														END
										|DBF.Numeric: value.numeric := value.numeric+0.5*Reals.Ten(-field.digits);
														Strings.RealToStr(value.numeric, value.character);
														j := 0;
														WHILE (value.character[j] # 0X) & (value.character[j] # ".") DO
															INC(j)
														END;
														IF value.character[j] = "." THEN
															IF field.digits <= 0 THEN
																value.character[j] := 0X
															ELSE
																INC(j);
																value.character[j+field.digits] := 0X
															END
														END;
														Texts.WriteString(W, value.character)
									ELSE (* Character *)
										Texts.WriteString(W, value.character)
									END
								ELSE
									Error()
								END;
								field := field.next
							END
						ELSE
							Error()
						END;
						Texts.WriteLn(W); INC(i)
					END;
					Texts.WriteLn(W)
				ELSE
					Error()
				END
			ELSE
				Texts.WriteString(W, "not found")
			END;
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END
	END Show;

BEGIN
	Texts.OpenWriter(W)
END DBFDump.

DBFDump.Show some.dbf
