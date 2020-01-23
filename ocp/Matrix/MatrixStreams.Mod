MODULE MatrixStreams ;	(**  AUTHOR "Patrick Hunziker"; PURPOSE "";  **)
IMPORT Streams;

TYPE Datatype = FLOAT64;

TYPE Reader* = OBJECT (Streams.Reader);
			(*
			PROCEDURE Tensor*(): ARRAY [?] OF Datatype;
			VAR dims, Rows,Cols, Start, Row,Col: SIGNED32; m:ARRAY [?] OF Datatype;
			BEGIN
				RawLInt(dims); RawLInt(Rows); RawLInt(Cols);
				NEW(m,Rows,Cols);
				FOR Row:=0 TO Rows-1 DO
					FOR Col:=0 TO Cols-1 DO
						RawLReal(m[Row,Col])
					END;
				END;

				RETURN m
			END Tensor;
			*)
			PROCEDURE Volume(lenX,lenY,lenZ:SIGNED32): ARRAY [*,*,*] OF SIGNED8;
			VAR res: ARRAY [*,*,*] OF SIGNED8; x,y,z:SIGNED32;
			BEGIN
				NEW(res,lenZ,lenY,lenX);
				FOR z:=0 TO lenZ-1 DO
					FOR y:=0 TO lenY-1 DO
						FOR x:=0 TO lenX-1 DO
							RawSInt(res[z,y,x]);
						END;
					END;
				END;
				RETURN res
			END Volume;


			PROCEDURE Matrix*(): ARRAY [*,*] OF Datatype;
			VAR Rows,Cols, Start, Row,Col: SIGNED32; m:ARRAY [*,*] OF Datatype;
			BEGIN
				RawLInt(Rows); RawLInt(Cols);
				NEW(m,Rows,Cols);
				FOR Row:=0 TO Rows-1 DO
					FOR Col:=0 TO Cols-1 DO
						RawLReal(m[Row,Col])
					END;
				END;
				RETURN m
			END Matrix;

			PROCEDURE Vector*():ARRAY [*] OF Datatype;
			VAR Rows,Cols, Start, Row,Col: SIGNED32; v:ARRAY [*] OF Datatype;
			BEGIN
				RawLInt(Cols);
				NEW(v,Cols);
				FOR Col:=0 TO Cols-1 DO
					RawLReal(v[Col])
				END;
				RETURN v
			END Vector;

		END Reader;

		Writer* = OBJECT (Streams.Writer);
			(*
			PROCEDURE Tensor*( m: ARRAY [?] OF Datatype);
			VAR dims, Rows,Cols, Start, Row,Col: SIGNED32;
			BEGIN
				RawLInt(dims); RawLInt(Rows); RawLInt(Cols);
				NEW(m,Rows,Cols);
				FOR Row:=0 TO Rows-1 DO
					FOR Col:=0 TO Cols-1 DO
						RawLReal(m[Row,Col])
					END;
				END;
			END Tensor;
			*)

			PROCEDURE Matrix*(CONST m: ARRAY [*,*] OF Datatype);
			VAR Rows,Cols, Start, Row,Col: SIGNED32;
			BEGIN
				Rows:=LEN(m,0)(SIGNED32); Cols:=LEN(m,1)(SIGNED32);
				RawLInt(Rows); RawLInt(Cols);
				FOR Row:=0 TO Rows-1 DO
					FOR Col:=0 TO Cols-1 DO
						RawLReal(m[Row,Col])
					END;
				END;
			END Matrix;

			PROCEDURE Vector*(CONST v : ARRAY [*] OF Datatype);
			VAR Rows,Cols, Start, Row,Col: SIGNED32;
			BEGIN
				Cols:=LEN(v,0)(SIGNED32);
				RawLInt(Cols);
				FOR Col:=0 TO Cols-1 DO
					RawLReal(v[Col])
				END;
			END Vector;

		END Writer;

	(** Open a writer to the specified stream sender.  Update must be called after writing to ensure the buffer is written to the stream. *)
	PROCEDURE OpenWriter*( VAR b: Writer;  send: Streams.Sender );
	BEGIN
		NEW( b, send, Streams.DefaultWriterSize )
	END OpenWriter;


(** Open a reader from the specified stream receiver. *)
	PROCEDURE OpenReader*( VAR b: Reader;  receive: Streams.Receiver );
	BEGIN
		NEW( b, receive, Streams.DefaultReaderSize )
	END OpenReader;

END MatrixStreams.


fofPC.Compile *
