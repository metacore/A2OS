MODULE dbgSortTest IN Oberon;   	(** fof  **)
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)



IMPORT vyParser, vyRandom, vyTypes, vyHostTexts, vyBase, vyOut, vyRealVec, vyLongrealVec, vyLongintVec, vyIntVec;

PROCEDURE TestReal*;
	VAR size, i, j, count, show: SIGNED32;   sc: vyParser.Scanner;   X: vyBase.tVector;
BEGIN
	NEW(sc);   vyParser.OpenParScanner(sc);
	IF vyParser.ExpectNumber(sc, size) & vyParser.ExpectNumber(sc, count) & vyParser.ExpectNumber(sc, show)THEN
		FOR j := 1 TO count DO
			vyHostTexts.NoteSI(vyHostTexts.cNotify, "Producing random vector, length: ", size);
			X := vyRealVec.New(0);
			FOR i := 1 TO size DO
				vyRealVec.Append(SHORT(vyRandom.Uniform()), X);
				IF i MOD (size DIV show) = 0 THEN vyHostTexts.MsgSR(" = ", vyRealVec.Get(X, i - 1) )END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Sorting Vector");
			vyTypes.Sort(X);
			FOR i := 1 TO size - 1 DO
				IF vyRealVec.Get(X, i - 1) > vyRealVec.Get(X, i) THEN
					vyHostTexts.NoteSI(vyHostTexts.cAlert, "There was an error at pos : ", i);   HALT(200)
				END;
				IF (i + 1) MOD (size DIV show) = 0 THEN vyHostTexts.MsgSR(" = ", vyRealVec.Get(X, i - 1) )END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Real vector sorted, ok.");
			vyHostTexts.Note(vyHostTexts.cNotify, " ---------------------------------")
		END;
		vyHostTexts.Note(vyHostTexts.cNotify, "#### No errors ####")
	END
END TestReal;

PROCEDURE TestLongReal*;
	VAR size, i, j, count, show: SIGNED32;   sc: vyParser.Scanner;   X: vyBase.tVector;
BEGIN
	NEW(sc);   vyParser.OpenParScanner(sc);
	IF vyParser.ExpectNumber(sc, size) & vyParser.ExpectNumber(sc, count) & vyParser.ExpectNumber(sc, show)THEN
		FOR j := 1 TO count DO
			vyHostTexts.NoteSI(vyHostTexts.cNotify, "Producing random vector, length: ", size);
			X := vyLongrealVec.New(0);
			FOR i := 1 TO size DO
				vyLongrealVec.Append(vyRandom.Uniform(), X);
				IF i MOD (size DIV show) = 0 THEN vyHostTexts.MsgSR(" = ", SHORT(vyLongrealVec.Get(X, i - 1) ))END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Sorting Vector");
			vyTypes.Sort(X);
			FOR i := 1 TO size - 1 DO
				IF vyLongrealVec.Get(X, i - 1) > vyLongrealVec.Get(X, i) THEN
					vyHostTexts.NoteSI(vyHostTexts.cAlert, "There was an error at pos : ", i);   HALT(200)
				END;
				IF (i + 1) MOD (size DIV show) = 0 THEN vyHostTexts.MsgSR(" = ", SHORT(vyLongrealVec.Get(X, i - 1) ))END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Longreal vector sorted, ok.");
			vyHostTexts.Note(vyHostTexts.cNotify, " ---------------------------------")
		END;
		vyHostTexts.Note(vyHostTexts.cNotify, "#### No errors ####")
	END
END TestLongReal;

PROCEDURE TestInteger*;
	VAR size, i, j, count, show: SIGNED32;   sc: vyParser.Scanner;   X: vyBase.tVector;
BEGIN
	NEW(sc);   vyParser.OpenParScanner(sc);
	IF vyParser.ExpectNumber(sc, size) & vyParser.ExpectNumber(sc, count) & vyParser.ExpectNumber(sc, show) THEN
		FOR j := 1 TO count DO
			vyHostTexts.NoteSI(vyHostTexts.cNotify, "Producing random vector, length: ", size);
			X := vyIntVec.New(0);
			FOR i := 1 TO size DO
				vyIntVec.Append(SHORT(ENTIER(vyRandom.Uniform() * MAX(SIGNED16))), X);
				IF i MOD (size DIV show) = 0 THEN vyHostTexts.NoteSI(vyHostTexts.cNotify, " = ", vyIntVec.Get(X, i - 1) )END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Sorting Vector");
			vyTypes.Sort(X);
			FOR i := 1 TO size - 1 DO
				IF vyIntVec.Get(X, i - 1) > vyIntVec.Get(X, i) THEN
					vyHostTexts.NoteSI(vyHostTexts.cAlert, "There was an error at pos : ", i);   HALT(200)
				END;
				IF (i + 1) MOD (size DIV show) = 0 THEN vyHostTexts.NoteSI(vyHostTexts.cNotify, " = ", vyIntVec.Get(X, i - 1) )END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Integer vector sorted, ok.");
			vyHostTexts.Note(vyHostTexts.cNotify, " ---------------------------------")
		END;
		vyHostTexts.Note(vyHostTexts.cNotify, "#### No errors ####")
	END
END TestInteger;

PROCEDURE TestLongInt*;
	VAR size, i, j, count, show: SIGNED32;   sc: vyParser.Scanner;   X: vyBase.tVector;
BEGIN
	NEW(sc);   vyParser.OpenParScanner(sc);
	IF vyParser.ExpectNumber(sc, size) & vyParser.ExpectNumber(sc, count) & vyParser.ExpectNumber(sc, show)THEN
		FOR j := 1 TO count DO
			vyHostTexts.NoteSI(vyHostTexts.cNotify, "Producing random vector, length: ", size);
			X := vyLongintVec.New(0);
			FOR i := 1 TO size DO
				vyLongintVec.Append(ENTIER(vyRandom.Uniform() * MAX(SIGNED32)), X);
				IF i MOD (size DIV show) = 0 THEN vyHostTexts.NoteSI(vyHostTexts.cNotify, " = ", vyLongintVec.Get(X, i - 1) )END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Sorting Vector");
			vyTypes.Sort(X);
			FOR i := 1 TO size - 1 DO
				IF vyLongintVec.Get(X, i - 1) > vyLongintVec.Get(X, i) THEN
					vyHostTexts.NoteSI(vyHostTexts.cAlert, "There was an error at pos : ", i);   HALT(200)
				END;
				IF (i + 1) MOD (size DIV show) = 0 THEN vyHostTexts.NoteSI(vyHostTexts.cNotify, " = ", vyLongintVec.Get(X, i - 1) )END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Longint vector sorted, ok.");
			vyHostTexts.Note(vyHostTexts.cNotify, " ---------------------------------")
		END;
		vyHostTexts.Note(vyHostTexts.cNotify, "#### No errors ####")
	END
END TestLongInt;

PROCEDURE TestRealWId*;
	VAR size, i, j, count: SIGNED32;   sc: vyParser.Scanner;   X, Xcopy: vyBase.tVector;   temp, tempcopy: vyBase.tVector;
	XA: POINTER TO ARRAY OF FLOAT32;   tempA: POINTER TO ARRAY OF SIGNED32;   failed: BOOLEAN;
BEGIN
	failed := FALSE;
	NEW(sc);   vyParser.OpenParScanner(sc);
	IF vyParser.ExpectNumber(sc, size) & vyParser.ExpectNumber(sc, count) THEN
		FOR j := 1 TO count DO
			vyHostTexts.NoteSI(vyHostTexts.cNotify, "Producing random vector, length: ", size);
			X := vyRealVec.New(0);
			temp := vyLongintVec.New(0);
			FOR i := 0 TO size - 1 DO
				vyRealVec.Append(SHORT(vyRandom.Uniform()), X);
				vyLongintVec.Append(i, temp)
			END;
			NEW(XA, size);   NEW(tempA, size);
			vyRealVec.CopyToArray(X, XA^);   vyLongintVec.CopyToArray(temp, tempA^);
			tempcopy := vyLongintVec.New(size);
			Xcopy := vyRealVec.New(size);
			vyRealVec.CopyToVec(XA^, Xcopy, size, 0, 0);
			vyLongintVec.CopyToVec(tempA^, tempcopy, size, 0, 0);
			vyHostTexts.Note(vyHostTexts.cNotify, "Comparing Vector , copy");
			FOR i := 0 TO size - 1 DO
				IF vyRealVec.Get(X, i) # vyRealVec.Get(Xcopy, i) THEN HALT(201) END;
				IF vyLongintVec.Get(temp, i) # vyLongintVec.Get(tempcopy, i) THEN HALT(201) END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "compare ok");
			vyHostTexts.Note(vyHostTexts.cNotify, "Sorting Vector");
			vyTypes.SortWId(X, temp);
			FOR i := 1 TO size - 1 DO
				IF vyRealVec.Get(X, i - 1) > vyRealVec.Get(X, i) THEN
					vyHostTexts.NoteSI(vyHostTexts.cAlert, "There was an error at pos : ", i);  HALT(200)
				END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Real vector sorted, ok.");
			vyHostTexts.Note(vyHostTexts.cNotify, " ---------------------------------");

			FOR i := 0 TO size - 1 DO
				IF vyRealVec.Get(Xcopy, vyLongintVec.Get(temp, i)) # vyRealVec.Get(X, i) THEN
					FOR i := 0 TO size - 1 DO

						vyOut.Ln();
						vyOut.String("Place:  ");
						vyOut.Int(i, 10);
						vyOut.String(" Id: ");
						vyOut.Int(vyLongintVec.Get(temp, i), 10);
						vyOut.String(" value:  ");
						vyOut.Real(vyRealVec.Get(X, i), 10);
						vyOut.String(" copy (Id):  ");
						vyOut.Real(vyRealVec.Get(Xcopy, vyLongintVec.Get(temp, i)), 10);
						IF vyRealVec.Get(Xcopy, vyLongintVec.Get(temp, i)) # vyRealVec.Get(X, i) THEN vyOut.String("*") END;
						failed := TRUE
					END;
					HALT(202)
				END
			END;
			IF failed THEN vyHostTexts.Note(vyHostTexts.cWarning, "ERROR OCCURED IN Id !");   RETURN END
		END;
		vyHostTexts.Note(vyHostTexts.cNotify, "#### No errors in sort and id####")
	END
END TestRealWId;

PROCEDURE TestLongRealWId*;
	VAR size, i, j, count: SIGNED32;   sc: vyParser.Scanner;   X, Xcopy: vyBase.tVector;   temp, tempcopy: vyBase.tVector;
	XA: POINTER TO ARRAY OF FLOAT64;   tempA: POINTER TO ARRAY OF SIGNED32;   failed: BOOLEAN;
BEGIN
	failed := FALSE;
	NEW(sc);   vyParser.OpenParScanner(sc);
	IF vyParser.ExpectNumber(sc, size) & vyParser.ExpectNumber(sc, count) THEN
		FOR j := 1 TO count DO
			vyHostTexts.NoteSI(vyHostTexts.cNotify, "Producing random vector, length: ", size);
			X := vyLongrealVec.New(0);
			temp := vyLongintVec.New(0);
			FOR i := 0 TO size - 1 DO
				vyLongrealVec.Append((vyRandom.Uniform()), X);
				vyLongintVec.Append(i, temp)
			END;
			NEW(XA, size);   NEW(tempA, size);
			vyLongrealVec.CopyToArray(X, XA^);   vyLongintVec.CopyToArray(temp, tempA^);
			tempcopy := vyLongintVec.New(size);
			Xcopy := vyLongrealVec.New(size);
			vyLongrealVec.CopyToVec(XA^, Xcopy, size, 0, 0);
			vyLongintVec.CopyToVec(tempA^, tempcopy, size, 0, 0);
			vyHostTexts.Note(vyHostTexts.cNotify, "Comparing Vector , copy");
			FOR i := 0 TO size - 1 DO
				IF vyLongrealVec.Get(X, i) # vyLongrealVec.Get(Xcopy, i) THEN HALT(201) END;
				IF vyLongintVec.Get(temp, i) # vyLongintVec.Get(tempcopy, i) THEN HALT(201) END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "compare ok");
			vyHostTexts.Note(vyHostTexts.cNotify, "Sorting Vector");
			vyTypes.SortWId(X, temp);
			FOR i := 1 TO size - 1 DO
				IF vyLongrealVec.Get(X, i - 1) > vyLongrealVec.Get(X, i) THEN
					vyHostTexts.NoteSI(vyHostTexts.cAlert, "There was an error at pos : ", i); HALT(200)
				END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Real vector sorted, ok.");
			vyHostTexts.Note(vyHostTexts.cNotify, " ---------------------------------");

			FOR i := 0 TO size - 1 DO
				IF vyLongrealVec.Get(Xcopy, vyLongintVec.Get(temp, i)) # vyLongrealVec.Get(X, i) THEN
					failed := TRUE
				END
			END;
			IF failed THEN vyHostTexts.Note(vyHostTexts.cWarning, "ERROR OCCURED IN Id !");   RETURN END
		END;
		vyHostTexts.Note(vyHostTexts.cNotify, "#### No errors in sort and id####")

	END
END TestLongRealWId;


PROCEDURE TestIntegerWId*;
	VAR size, i, j, count: SIGNED32;   sc: vyParser.Scanner;   X, Xcopy: vyBase.tVector;   temp, tempcopy: vyBase.tVector;
	XA: POINTER TO ARRAY OF SIGNED16;   tempA: POINTER TO ARRAY OF SIGNED32;   failed: BOOLEAN;
BEGIN
	failed := FALSE;
	NEW(sc);   vyParser.OpenParScanner(sc);
	IF vyParser.ExpectNumber(sc, size) & vyParser.ExpectNumber(sc, count) THEN
		FOR j := 1 TO count DO
			vyHostTexts.NoteSI(vyHostTexts.cNotify, "Producing random vector, length: ", size);
			X := vyIntVec.New(0);
			temp := vyLongintVec.New(0);
			FOR i := 0 TO size - 1 DO
				vyIntVec.Append(SHORT(ENTIER(1000 * vyRandom.Uniform())), X);
				vyLongintVec.Append(i, temp)
			END;
			NEW(XA, size);   NEW(tempA, size);
			vyIntVec.CopyToArray(X, XA^);   vyLongintVec.CopyToArray(temp, tempA^);
			tempcopy := vyLongintVec.New(size);
			Xcopy := vyIntVec.New(size);
			vyIntVec.CopyToVec(XA^, Xcopy, size, 0, 0);
			vyLongintVec.CopyToVec(tempA^, tempcopy, size, 0, 0);
			vyHostTexts.Note(vyHostTexts.cNotify, "Comparing Vector , copy");
			FOR i := 0 TO size - 1 DO
				IF vyIntVec.Get(X, i) # vyIntVec.Get(Xcopy, i) THEN HALT(201) END;
				IF vyLongintVec.Get(temp, i) # vyLongintVec.Get(tempcopy, i) THEN HALT(201) END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "compare ok");
			vyHostTexts.Note(vyHostTexts.cNotify, "Sorting Vector");
			vyTypes.SortWId(X, temp);
			FOR i := 1 TO size - 1 DO
				IF vyIntVec.Get(X, i - 1) > vyIntVec.Get(X, i) THEN
					vyHostTexts.NoteSI(vyHostTexts.cAlert, "There was an error at pos : ", i); HALT(200)
				END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Real vector sorted, ok.");
			vyHostTexts.Note(vyHostTexts.cNotify, " ---------------------------------");

			FOR i := 0 TO size - 1 DO
				IF vyIntVec.Get(Xcopy, vyLongintVec.Get(temp, i)) # vyIntVec.Get(X, i) THEN
					failed := TRUE
				END
			END;
			IF failed THEN vyHostTexts.Note(vyHostTexts.cWarning, "ERROR OCCURED IN Id !");   RETURN END
		END;
		vyHostTexts.Note(vyHostTexts.cNotify, "#### No errors in sort and id####")

	END
END TestIntegerWId;

PROCEDURE TestLongintWId*;
	VAR size, i, j, count: SIGNED32;   sc: vyParser.Scanner;   X, Xcopy: vyBase.tVector;   temp, tempcopy: vyBase.tVector;
	XA: POINTER TO ARRAY OF SIGNED32;   tempA: POINTER TO ARRAY OF SIGNED32;   failed: BOOLEAN;
BEGIN
	failed := FALSE;
	NEW(sc);   vyParser.OpenParScanner(sc);
	IF vyParser.ExpectNumber(sc, size) & vyParser.ExpectNumber(sc, count) THEN
		FOR j := 1 TO count DO
			vyHostTexts.NoteSI(vyHostTexts.cNotify, "Producing random vector, length: ", size);
			X := vyLongintVec.New(0);
			temp := vyLongintVec.New(0);
			FOR i := 0 TO size - 1 DO
				vyLongintVec.Append((ENTIER(100000 * vyRandom.Uniform())), X);
				vyLongintVec.Append(i, temp)
			END;
			NEW(XA, size);   NEW(tempA, size);
			vyLongintVec.CopyToArray(X, XA^);   vyLongintVec.CopyToArray(temp, tempA^);
			tempcopy := vyLongintVec.New(size);
			Xcopy := vyLongintVec.New(size);
			vyLongintVec.CopyToVec(XA^, Xcopy, size, 0, 0);
			vyLongintVec.CopyToVec(tempA^, tempcopy, size, 0, 0);
			vyHostTexts.Note(vyHostTexts.cNotify, "Comparing Vector , copy");
			FOR i := 0 TO size - 1 DO
				IF vyLongintVec.Get(X, i) # vyLongintVec.Get(Xcopy, i) THEN HALT(201) END;
				IF vyLongintVec.Get(temp, i) # vyLongintVec.Get(tempcopy, i) THEN HALT(201) END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "compare ok");
			vyHostTexts.Note(vyHostTexts.cNotify, "Sorting Vector");
			vyTypes.SortWId(X, temp);
			FOR i := 1 TO size - 1 DO
				IF vyLongintVec.Get(X, i - 1) > vyLongintVec.Get(X, i) THEN
					vyHostTexts.NoteSI(vyHostTexts.cAlert, "There was an error at pos : ", i); HALT(200)
				END
			END;
			vyHostTexts.Note(vyHostTexts.cNotify, "Real vector sorted, ok.");
			vyHostTexts.Note(vyHostTexts.cNotify, " ---------------------------------");

			FOR i := 0 TO size - 1 DO
				IF vyLongintVec.Get(Xcopy, vyLongintVec.Get(temp, i)) # vyLongintVec.Get(X, i) THEN
					failed := TRUE
				END
			END;
			IF failed THEN vyHostTexts.Note(vyHostTexts.cWarning, "ERROR OCCURED IN Id !");   RETURN END
		END;
		vyHostTexts.Note(vyHostTexts.cNotify, "#### No errors in sort and id####")

	END
END TestLongintWId;


(*
PROCEDURE TestLongRealWId*;
VAR size,i,j,count,show: SIGNED32; sc: vyParser.Scanner; X,temp: vyBase.tVector;
BEGIN
NEW(sc); vyParser.OpenParScanner(sc);
IF vyParser.ExpectNumber(sc,size) & vyParser.ExpectNumber(sc,count) & vyParser.ExpectNumber(sc,show)THEN
FOR j := 1 TO count DO
vyHostTexts.NoteSI(vyHostTexts.cNotify,"Producing random vector, length: ", size);
X := vyLongrealVec.NewLongrealVector(0);
temp := vyLongintVec.New(0);
FOR i := 1 TO size DO
vyLongrealVec.Append(vyRandom.Uniform(),X);
vyLongintVec.Append(i,temp);
IF i MOD (size DIV show) = 0 THEN vyHostTexts.MsgSR(" = ",SHORT(vyLongrealVec.Get(X,i-1) ))END;
END;
vyHostTexts.Note(vyHostTexts.cNotify,"Sorting Vector");
vyTypes.SortWId(X,temp);
FOR i := 1 TO size-1 DO
IF vyLongrealVec.Get(X,i-1) > vyLongrealVec.Get(X,i) THEN
vyHostTexts.NoteSI(vyHostTexts.cAlert,"There was an error at pos : ",i); HALT(200)
END;
IF (i+1) MOD (size DIV show) = 0 THEN vyHostTexts.MsgSR(" = ",SHORT(vyLongrealVec.Get(X,i-1) ))END;
END;
vyHostTexts.Note(vyHostTexts.cNotify,"Longreal vector sorted, ok.");
vyHostTexts.Note(vyHostTexts.cNotify," ---------------------------------");
END;
vyHostTexts.Note(vyHostTexts.cNotify,"#### No errors ####");
END;
END TestLongRealWId;

PROCEDURE TestIntegerWId*;
VAR size,i,j,count,show: SIGNED32; sc: vyParser.Scanner; X,temp: vyBase.tVector;
BEGIN
NEW(sc); vyParser.OpenParScanner(sc);
IF vyParser.ExpectNumber(sc,size) & vyParser.ExpectNumber(sc,count) & vyParser.ExpectNumber(sc,show) THEN
FOR j := 1 TO count DO
vyHostTexts.NoteSI(vyHostTexts.cNotify,"Producing random vector, length: ", size);
X := vyIntVec.NewIntegerVector(0);
temp := vyLongintVec.New(0);
FOR i := 1 TO size DO
vyIntVec.Append(SHORT(ENTIER(vyRandom.Uniform()*MAX(SIGNED16))),X);
vyLongintVec.Append(i,temp);
IF i MOD (size DIV show) = 0 THEN vyHostTexts.NoteSI(vyHostTexts.cNotify," = ",vyIntVec.Get(X,i-1) )END;
END;
vyHostTexts.Note(vyHostTexts.cNotify,"Sorting Vector");
vyTypes.SortWId(X,temp);
FOR i := 1 TO size-1 DO
IF vyIntVec.Get(X,i-1) > vyIntVec.Get(X,i) THEN
vyHostTexts.NoteSI(vyHostTexts.cAlert,"There was an error at pos : ",i); HALT(200)
END;
IF (i+1) MOD (size DIV show) = 0 THEN vyHostTexts.NoteSI(vyHostTexts.cNotify," = ",vyIntVec.Get(X,i-1) )END;
END;
vyHostTexts.Note(vyHostTexts.cNotify,"Integer vector sorted, ok.");
vyHostTexts.Note(vyHostTexts.cNotify," ---------------------------------");
END;
vyHostTexts.Note(vyHostTexts.cNotify,"#### No errors ####");
END;
END TestIntegerWId;

PROCEDURE TestLongIntWId*;
VAR size,i,j,count,show: SIGNED32; sc: vyParser.Scanner; X,temp: vyBase.tVector;
BEGIN
NEW(sc); vyParser.OpenParScanner(sc);
IF vyParser.ExpectNumber(sc,size) & vyParser.ExpectNumber(sc,count) & vyParser.ExpectNumber(sc,show)THEN
FOR j := 1 TO count DO
vyHostTexts.NoteSI(vyHostTexts.cNotify,"Producing random vector, length: ", size);
X := vyLongintVec.New(0);
temp := vyLongintVec.New(0);
FOR i := 1 TO size DO
vyLongintVec.Append(ENTIER(vyRandom.Uniform()*MAX(SIGNED32)),X);
vyLongintVec.Append(i,temp);
IF i MOD (size DIV show) = 0 THEN vyHostTexts.NoteSI(vyHostTexts.cNotify," = ",vyLongintVec.Get(X,i-1) )END;
END;
vyHostTexts.Note(vyHostTexts.cNotify,"Sorting Vector");
vyTypes.SortWId(X,temp);
FOR i := 1 TO size-1 DO
IF vyLongintVec.Get(X,i-1) > vyLongintVec.Get(X,i) THEN
vyHostTexts.NoteSI(vyHostTexts.cAlert,"There was an error at pos : ",i); HALT(200)
END;
IF (i+1) MOD (size DIV show) = 0 THEN vyHostTexts.NoteSI(vyHostTexts.cNotify," = ",vyLongintVec.Get(X,i-1) )END;
END;
vyHostTexts.Note(vyHostTexts.cNotify,"Longint vector sorted, ok.");
vyHostTexts.Note(vyHostTexts.cNotify," ---------------------------------");
END;
vyHostTexts.Note(vyHostTexts.cNotify,"#### No errors ####");
END;
END TestLongIntWId;
*)

END dbgSortTest.

System.Free dbgSortTest * ~

Usage: dbgSortTest.TestXXXX  # Number of data # Number of vectors # Number of some example data

If there was an error, a TRAP HALT 200 should occur.

Caret to System Log, please.

Automatic.Do
dbgSortTest.TestReal 1000 5 2
dbgSortTest.TestLongReal 1000 5 2
dbgSortTest.TestInteger 1000 5 2
dbgSortTest.TestLongInt 1000 5 2
dbgSortTest.TestRealWId 1000 1 1
dbgSortTest.TestLongRealWId 1000 5 2
dbgSortTest.TestIntegerWId 1000 5 2
dbgSortTest.TestLongintWId 1000 5 2
~
Automatic.Do
dbgSortTest.TestReal 10000 5 2
dbgSortTest.TestLongReal 10000 5 2
dbgSortTest.TestInteger 10000 5 2
dbgSortTest.TestLongInt 10000 5 2
dbgSortTest.TestRealWId 10000 5 2
dbgSortTest.TestLongRealWId 10000 5 2
dbgSortTest.TestIntegerWId 10000 5 2
dbgSortTest.TestLongintWId 10000 5 2
~
Automatic.Do
dbgSortTest.TestReal 100000 1 2
dbgSortTest.TestLongReal 100000 1 2
dbgSortTest.TestInteger 100000 1 2
dbgSortTest.TestLongInt 100000 1 2
dbgSortTest.TestRealWId 100000 1 2
dbgSortTest.TestLongRealWId 100000 1 2
dbgSortTest.TestIntegerWId 100000 1 2
dbgSortTest.TestLongintWId 100000 1 2
~
Automatic.Do
dbgSortTest.TestReal 1000000 1 2
dbgSortTest.TestLongReal 1000000 1 2
dbgSortTest.TestInteger 1000000 1 2
dbgSortTest.TestLongInt 1000000 1 2
dbgSortTest.TestRealWId 1000000 1 2
dbgSortTest.TestLongRealWId 1000000 1 2
dbgSortTest.TestIntegerWId 1000000 1 2
dbgSortTest.TestLongintWId 1000000 1 2
~

dbgSortTest.TestRealWId 1000 5 ~

dbgSortTest.TestLongRealWId 1000 5 ~
dbgSortTest.TestIntegerWId 1000 5 ~
dbgSortTest.TestLongintWId 1000 5 ~
