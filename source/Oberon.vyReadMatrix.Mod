MODULE vyReadMatrix IN Oberon;
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



(* - to extract a compilable version with debug-information use command:
SpotPP.Preprocess \D=debug rw/vyReadMatrix.Mpp => rw/vyReadMatrix.Mod
to extract compilable version without debug-information:
SpotPP.Preprocess rw/vyReadMatrix.Mpp => rw/vyReadMatrix.Mod
- table will be read by columns, that means that each column of the table which has to be read will be stored in one
vector of the ListItem
- a table with rownames & columnnames is not supposed to habe a Header(a colheader) for the column of rownames,
only one for each column of numbers of the table*)

IMPORT	Reals IN A2,
	vyScanners, vyHostTexts, Texts,  vyLinks,
	vyLongrealVec := vyRealVec, vyCG := vyName, vyHostStrings, vyStringVec;

CONST idversion* = "vyReadMatrix 0.1d0";

TYPE
	Vec = vyLongrealVec.tVector;
	String = ARRAY 32 OF CHAR;
	StringVec = vyStringVec.tVector;

	ListItem* = POINTER TO ListItemDesc;      						(*?move to vyBase?*)
	ListItemDesc = RECORD (vyLinks.LinkDesc);
		row-, col- : SIGNED16;
		cname-, rname- : StringVec
	END;

	(*VAR
	debug : BOOLEAN;*)

PROCEDURE InitList (row, col: SIGNED16;  rowheader, colheader : BOOLEAN) : ListItem;
VAR
	i: SIGNED16;
	tempvec: Vec;
	templist, templistold : ListItem;
	name : String;
	List : ListItem;
BEGIN
	IF colheader & rowheader THEN
		DEC(row) 				(*the line of columnheaders does not count as a row of the matrix*)
	ELSIF colheader & ~rowheader THEN
		DEC(row) 					(*the line of columnheaders does not count as a row of the matrix*)
	ELSIF ~colheader & rowheader THEN
		DEC(col) 					(*the line of rowheaders does not count as a column of the matrix*)
	END;

	NEW(templist);
	NEW(List);
	NEW(templistold);
	tempvec := vyLongrealVec.New(row);
	templist.obj := tempvec;
	vyCG.RegisterNamed(tempvec, "Vector01");
	List := templist;
	List.row := row;
	List.col := col;
	FOR i := 1 TO col - 1 DO
		templistold := templist;
		NEW(templist);
		tempvec := vyLongrealVec.New(row);

		name := "Vector";  								(*? same name-conventions for all vy-Vecs?*)
		IF (i + 1) < 9 THEN vyHostStrings.AppendInt(0, 1, name)  END;
		vyHostStrings.AppendInt(i + 1, 1, name);
		vyCG.RegisterNamed(tempvec, name);

		templist.obj := tempvec;
		templistold.link := templist
	END;

	IF colheader & rowheader THEN
		List.cname := vyStringVec.New(List.col);
		List.rname := vyStringVec.New(List.row)

	ELSIF colheader & ~rowheader THEN
		List.cname := vyStringVec.New(List.col)

	ELSIF ~colheader & rowheader THEN
		List.rname := vyStringVec.New(List.row)

	ELSE

	END;

	RETURN List
END InitList;

PROCEDURE Adjustcr (VAR check : BOOLEAN;    VAR cr : SIGNED16);
BEGIN
	IF check THEN
		check := FALSE;
		INC(cr)

	END
END Adjustcr;

PROCEDURE readMatrix (VAR List: ListItem;     pos : SIGNED32;  selend: SIGNED32;  text: Texts.Text );
VAR
	s : vyScanners.Scanner;
	cr, cc: SIGNED16;      		(*cr=checkrow; cc=checkcolumn; variables in use to detect deviations from the structure of the table; i.e. wrong nr of rows or columns*)
	l : SIGNED32;       r: FLOAT32;       lr : FLOAT64;
	temp : ListItem;
	neg, negold, check : BOOLEAN;      				(*check is set to TRUE after reading a newlinesymbol(vyScanners.ctNL) - if check is TRUE and anything is being read, cr is being increased*)
	string : String;
BEGIN
	negold := FALSE;       neg := FALSE;      check := TRUE;
	cc := 0;      cr := 0;
	vyScanners.NewSScanner(s);
	vyScanners.OpenScanner(s, text, pos , selend);
	REPEAT
		negold := neg;       neg := FALSE;
		IF (cc > 0) & (cc < List.col) THEN
			INC(cc);
			temp := temp.link(ListItem)
		ELSE
			cc := 1;
			temp := List
		END;
		CASE vyScanners.NextToken(s) OF
			vyScanners.ctNumber:
			Adjustcr(check, cr);
			IF ~(cr <= List.row) THEN List := NIL;  RETURN  END;      		(*ASSERT; if number of read rows > number of prefixed rows*)
			IF vyScanners.GetNumber(s, negold, l) THEN
				vyLongrealVec.Set(l, temp.obj(Vec), cr - 1)
			ELSE
				string := "handle number out of range";
				vyHostTexts.Note(30, string)
			END
			;
		|vyScanners.ctReal:
			Adjustcr(check, cr);
			IF ~(cr <= List.row) THEN List := NIL;  RETURN  END;       		(*ASSERT; if number of read rows > number of prefixed rows*)
			IF vyScanners.GetReal(s, negold, r) THEN
				vyLongrealVec.Set(r, temp.obj(Vec), cr - 1)
			ELSE
				string := "handle real out of range";
				vyHostTexts.Note(30, string)
			END
			;
		|vyScanners.ctFixed:
			Adjustcr(check, cr);
			IF ~(cr <= List.row) THEN List := NIL;  RETURN  END;      		(*ASSERT; if number of read rows > number of prefixed rows*)
			IF vyScanners.GetReal(s, negold, r) THEN
				vyLongrealVec.Set(r, temp.obj(Vec), cr - 1)
			ELSE
				string := "handle number out of range";
				vyHostTexts.Note(30, string)
			END
			;
		|vyScanners.ctEOT:
			IF cr > 0 THEN IF ~(cr = List.row) THEN List := NIL;  RETURN  END     END;     		(*ASSERT; if number of read rows < number of prefixed rows*)

		|vyScanners.ctNL:
			IF ~(cc = 1) THEN List := NIL;  RETURN  END;
			(*ASSERT; if number of read columns # number of prefixed columns*)
			check := TRUE;
			DEC(cc)
			;
		|vyScanners.ctSym:
			Adjustcr(check, cr);
			IF s.v = vyScanners.csMinus THEN
				neg := TRUE
			ELSE
				lr := Reals.NaN(0);
				vyLongrealVec.Set(lr, temp.obj(Vec), cr - 1)
			END;
			DEC(cc)

		ELSE
			Adjustcr(check, cr);
			lr := Reals.NaN(0);
			vyLongrealVec.Set(lr, temp.obj(Vec), cr - 1)

		END;      	(*Case*)
	UNTIL s.class = vyScanners.ctEOT
END readMatrix;

PROCEDURE readMatrixwrownames (VAR List: ListItem;     pos : SIGNED32;  selend: SIGNED32;  text: Texts.Text );
	(*for commentaries look at procedure readMatrix*)
VAR
	s : vyScanners.Scanner;
	cr, cc, i, j : SIGNED16;
	l : SIGNED32;       r: FLOAT32;       lr : FLOAT64;
	temp : ListItem;
	neg, negold, check, check2 : BOOLEAN;      					(*check2 is set to FALSE after reading a rowname*)
	string, string2: String;
	name : vyStringVec.nameptr;
BEGIN
	negold := FALSE;       neg := FALSE;      check := TRUE;
	cc := 0;      cr := 0;
	vyScanners.NewSScanner(s);
	vyScanners.OpenScanner(s, text, pos , selend);
	FOR i := 0 TO List.row - 1 DO							(*FOR1*)
		check2 := FALSE;
		FOR j := 0 TO List.col  DO									(*FOR2*)
			IF (cc > 0) & (cc < List.col) THEN		(*IF1*)
				INC(cc);
				temp := temp.link(ListItem)
			ELSE
				cc := 1;
				temp := List
			END;     												(*END IF1*)
			negold := neg;       neg := FALSE;
			CASE vyScanners.NextToken(s) OF		(*Case*)
				vyScanners.ctNumber:
				IF ~(cr <= List.row) THEN List := NIL;  RETURN  END;
				(*ASSERT; if number of read rows > number of prefixed rows*)
				IF ((~check2) & (cc = 1)) THEN HALT(104)	END;  					(*ASSERT; if row`s first read symbol is not a name*)
				IF vyScanners.GetNumber(s, negold, l) THEN
					vyLongrealVec.Set(l, temp.obj(Vec), cr - 1)
				ELSE
					string2 := "handle number out of range";
					vyHostTexts.Note(30, string2)
				END;
			|vyScanners.ctReal:
				IF ~(cr <= List.row) THEN List := NIL;  RETURN  END;
				(*ASSERT; if number of read rows > number of prefixed rows*)
				IF ((~check2) & (cc = 1)) THEN HALT(104)	END;  							(*ASSERT; if row`s first read symbol is not a name*)
				IF vyScanners.GetReal(s, negold, r) THEN
					vyLongrealVec.Set(r, temp.obj(Vec), cr)
				ELSE
					string2 := "handle real out of range";
					vyHostTexts.Note(30, string2)
				END
				;
			|vyScanners.ctFixed:
				IF ~(cr <= List.row) THEN List := NIL;  RETURN  END;
				(*ASSERT; if number of read rows > number of prefixed rows*)
				IF ((~check2) & (cc = 1)) THEN HALT(104)	END;  					(*ASSERT; if row`s first read symbol is not a name*)
				IF vyScanners.GetReal(s, negold, r) THEN
					vyLongrealVec.Set(r, temp.obj(Vec), cr - 1)
				ELSE
					string2 := "handle number out of range";
					vyHostTexts.Note(30, string2)
				END;
			|vyScanners.ctEOT:
				IF cr > 0 THEN IF ~(cr = List.row) THEN List := NIL;  RETURN  END     END;     		(*ASSERT; if number of read rows < number of prefixed rows*)
			|vyScanners.ctNL:
				IF ~(cc = 1) THEN List := NIL;  RETURN  END;
				(*ASSERT; if number of read columns # number of prefixed columns*)
				check := TRUE;
				DEC(cc);
				DEC(j);
			|vyScanners.ctSym:
				IF s.v = vyScanners.csMinus THEN
					neg := TRUE
				ELSE
					check := TRUE;
					lr := Reals.NaN(0);
					vyLongrealVec.Set(lr, temp.obj(Vec), cr - 1)
				END;
				DEC(cc)

			ELSE
				IF ((cc = 1) & (~check2)) THEN
					IF check THEN INC(cr);    check := FALSE  END;
					IF vyScanners.GetName(s, string) THEN
						NEW(name);
						(* vyName.SetName(name, string); *)
						vyStringVec.Set(name, List.rname, i)
					END;
					DEC(cc);    check2 := TRUE

				ELSE
					lr := Reals.NaN(0);
					vyLongrealVec.Set(lr, temp.obj(Vec), cr - 1)

				END
			END     	(*Case*)
		END  						(*END FOR2*)
	END  						(*END FOR1*)
	(*List.rname[i + 1] := 0X; *)
END readMatrixwrownames;

PROCEDURE Countrows  ( pos : SIGNED32;  selend: SIGNED32;  text: Texts.Text )
: SIGNED16;
VAR
	s : vyScanners.Scanner;
	row: SIGNED16;
	check : BOOLEAN;      			(*counts rows that contain at least one Token*)
BEGIN
	row := 0;      check := TRUE;
	vyScanners.NewSScanner(s);
	vyScanners.OpenScanner(s, text, pos , selend);
	REPEAT
		CASE vyScanners.NextToken(s) OF
			vyScanners.ctNL:
			check := TRUE;
		|vyScanners.ctNumber:
			IF check THEN
			INC(row);    check := FALSE 			END;
		|vyScanners.ctId:
			IF check THEN
				INC(row);    check := FALSE
			END;
		|vyScanners.ctFixed:
			IF check THEN
				INC(row);    check := FALSE
			END
		ELSE
			(*check := FALSE;*)
		END (*case*)
	UNTIL	s.class = vyScanners.ctEOT
	;
	IF row > 0 THEN
		RETURN row
	ELSE
		RETURN 1
	END
END Countrows;

PROCEDURE ReadColumnHeader* (VAR M: ListItem;     VAR pos: SIGNED32;  selend: SIGNED32;  text: Texts.Text);
VAR
	scanner: vyScanners.Scanner;
	i, c: SIGNED16;
	posold : SIGNED32;
	string : String;
	name : vyStringVec.nameptr;
BEGIN
	vyScanners.NewSScanner(scanner);
	vyScanners.OpenScanner(scanner, text, pos , selend);

	i := 0;
	WHILE vyScanners.NextToken(scanner) = vyScanners.ctNL DO END;     			(*Scan empty lines & do nothing*)
	IF vyScanners.GetName(scanner, string) THEN
		NEW(name);
		(* vyName.SetName(name, string);*)
		vyStringVec.Set(name, M.cname, i);
		INC(i)
	END;
	REPEAT
		c := vyScanners.NextToken(scanner);
		IF vyScanners.GetName(scanner, string) & ((c = vyScanners.ctId) OR (c = vyScanners.ctString)) THEN
			NEW(name);
			(* vyName.SetName(name, string);*)
			vyStringVec.Set(name, M.cname, i);
			INC(i)
		END;
		posold := pos;
		pos := Texts.Pos(scanner^)
	UNTIL (c = vyScanners.ctNL) OR (c = vyScanners.ctEOT);
	(*M.cname[i + 1] := 0X;*)
	pos := posold - scanner.curTokLen
END ReadColumnHeader;


PROCEDURE Countcolumn ( pos : SIGNED32;  selend: SIGNED32;  text: Texts.Text): SIGNED16;
VAR
	s : vyScanners.Scanner;
	col, c : SIGNED16;
BEGIN
	col := 0;
	vyScanners.NewSScanner(s);
	vyScanners.OpenScanner(s, text, pos , selend);
	WHILE vyScanners.NextToken(s) = vyScanners.ctNL DO END;     		(*Scan empty lines & do nothing*)

	IF (s.class # vyScanners.ctNL) & (s.class # vyScanners.ctEOT) & (s.class # vyScanners.ctSym) THEN
		INC(col)
	END;

	REPEAT
		c := vyScanners.NextToken(s);
		IF (s.class # vyScanners.ctNL) & (s.class # vyScanners.ctEOT) & (s.class # vyScanners.ctSym) THEN
			INC(col)
		END
	UNTIL (c = vyScanners.ctNL) OR (c = vyScanners.ctEOT)
	;
	RETURN (col)
END Countcolumn;

PROCEDURE ReadMatrix* (VAR C: ListItem;     colheader, rowheader : BOOLEAN;  text: Texts.Text;  pos, end: SIGNED32);
VAR
	row, col : SIGNED16;
BEGIN
	col := Countcolumn(pos, end, text);
	row := Countrows(pos, end, text);
	C := InitList(row, col, rowheader, colheader)
	;
	pos := 0;
	IF colheader THEN ReadColumnHeader(C, pos, end, text)   END
	;
	IF rowheader THEN
		readMatrixwrownames(C, pos, end, text)
	ELSE
		readMatrix(C, pos, end, text)
	END
END ReadMatrix;


END vyReadMatrix.

(*Commentaries:
(i)	Error: 101 - (read nr of columns) unequal (prefixed nr of columns)
102 - (read nr of rows) > (prefixed nr of rows)
103 - (read nr of rows) < (prefixed nr of rows)
104 - the procedure was told to read a table with rownames, but the first read symbol is not a name
*)
