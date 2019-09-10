MODULE vyParser IN Oberon;
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



(***** Generic parser *****)
(*	Based on Mess 0.1
(C) G. Sawitzki, StatLab Heidelberg 1995 <gs@statlab.uni-heidelberg.de>
To save compilation time, additional information is placed at the end of this file. *)
(*! CW
- beim Parsen von "-"-Zeichen tritt ein Fehler auf.  In ww werden Eingabe keywords mit einem
vorangestelltem "-" gekennzeichnet z.B. in wwGC.ChangeParameters estimator -ar 2.
Wenn man versucht, zuerst die beiden Symbole "-" und "ar" als Zahl zu lesen, dann wird das
"-" geschluckt; d.h. vyParser.Number wird FALSE zurückliefern. Wenn man dann versucht,
das "-" mit vyParser.Symbol einzulesen, wird das misslinger, da es aus dem Scanner entfernt
wurde. Abhilfe: Scanner vor den ersten Interpretationsversuchen zwischenspeichern (in der
neuen variablen "copy" und mach einem missglückten Interpretationsversuch wiederherstellen.
*)
(*! scanner now falls back in case of error in number, smbol etc. This may be changed!! *)
IMPORT Texts, vyBase, vyHostTexts, vyName, vyScanners, Links, Objects, Gadgets (* jb, 5.11.01 *);
CONST idversion* = "vyParser v0r0a3";

	(** syntax description *)
	(*= Items are descibed as <name> ["/" <class> <repeat mark> <disposition> ] *)
	cSeparator = "/";
	(*= class is scanner class - one digit *)
	(*= repeat marks. using PERL regular expression syntax *)
	cOnceOrMore* = '+';
	cZeroOrOne* = "?";
	cZeroOrMore* = '*';
	cOnce = ' ';
	(*= disposition. must exist ? *)
	cMustExist* = '!';
	cMustNotExist* = '~';
	cAnyDisposition* = ' ';
	(*check for range*)
	cTerminator = ';';
	cAnyString = {1, 2};
	cAnyNumber = {4, 5, 6};
TYPE
	Scanner* = vyScanners.Scanner;

	tSyntaxItem = POINTER TO tSyntaxItemDesc;
	tSyntaxItemDesc = RECORD
		name: vyName.tNameArray;
		scannerclass: SET;
		repeat: CHAR;
		disposition: CHAR
	END;

	VAR w: vyBase.TextsWriter;
	class-: SIGNED16;  (*= recent class - reported for test and debugging *)
	copy: Scanner; 	(*cw990927*)
	(*=
	Note: scanner may be switched during read process. Always use scanner as VAR parameter.
	*)
PROCEDURE NextSyntaxItem (syntaxString: ARRAY OF CHAR;  VAR pos: SIGNED16;  VAR sit: tSyntaxItem);
	VAR i: SIGNED16;
BEGIN
	IF syntaxString[pos] = 0X THEN  sit := NIL;  RETURN END;
	IF sit = NIL THEN NEW(sit) END;
	sit.scannerclass := {};  sit.repeat := cOnce;  sit.disposition := cAnyDisposition;
	i := 0;  WHILE (syntaxString[pos] # cSeparator) &  (syntaxString[pos] # 0X) DO
	sit.name[i] := syntaxString[pos];  INC(pos);  INC(i) END;
	sit.name[i] := 0X;
	IF syntaxString[pos] = 0X THEN  RETURN END;
	INC(pos);
	WHILE (syntaxString[pos] # cTerminator) &  (syntaxString[pos] # 0X) DO
		CASE syntaxString[pos] OF
			'0'..'9': sit.scannerclass := sit.scannerclass + {(ORD(syntaxString[pos]) - ORD('0'))}
		| cOnceOrMore, cZeroOrOne, cZeroOrMore: sit.repeat := syntaxString[pos];
		| cMustExist, cMustNotExist: sit.disposition := syntaxString[pos]
		END;  (* CASE *)
		INC(pos)
	END;
	IF syntaxString[pos] = cTerminator THEN INC(pos) END
END NextSyntaxItem;

PROCEDURE MsgSyntax* (caller: ARRAY OF CHAR;  syntaxString: ARRAY OF CHAR);
	VAR sit: tSyntaxItem;  pos: SIGNED16;
PROCEDURE WriteId (sit: tSyntaxItem);
BEGIN
	Texts.WriteString(w, '<');
	Texts.WriteString(w, sit.name);  Texts.WriteString(w, ':');
	IF sit.scannerclass = {1, 2}
		THEN Texts.WriteString(w, 'AnyString')
	ELSIF sit.scannerclass = cAnyNumber THEN Texts.WriteString(w, 'AnyNumber')
	ELSE
		IF 1 IN sit.scannerclass THEN Texts.WriteString(w, ' Id') END;
		IF 2 IN sit.scannerclass THEN Texts.WriteString(w, ' String') END;
		IF 3 IN sit.scannerclass THEN Texts.WriteString(w, ' Symbol') END;
		IF 4 IN sit.scannerclass THEN Texts.WriteString(w, ' Number') END;
		IF 5 IN sit.scannerclass THEN Texts.WriteString(w, ' Real') END;
		IF 6 IN sit.scannerclass THEN Texts.WriteString(w, ' Fixed') END;
		IF 7 IN sit.scannerclass THEN Texts.WriteString(w, ' NL') END;
		IF 8 IN sit.scannerclass THEN Texts.WriteString(w, ' Comment') END
	END;
	Texts.WriteString(w, '>')
END WriteId;
BEGIN pos := 0;  Texts.WriteString(w, 'Syntax: ');  Texts.WriteString(w, caller);
	WHILE  syntaxString[pos] # 0X  DO
		Texts.WriteString(w, ' ');
		NextSyntaxItem(syntaxString, pos, sit);
		CASE sit.repeat OF
			cZeroOrOne: Texts.WriteString(w, '[');
			WriteId(sit);  Texts.WriteString(w, ']');
		| cOnce: 	WriteId(sit);
		| cOnceOrMore: 	WriteId(sit);  Texts.WriteString(w, ' { ');
			WriteId(sit);  Texts.WriteString(w, ' } ');
		| cZeroOrMore: Texts.WriteString(w, ' { ');
			WriteId(sit);
			Texts.WriteString(w, ' } ')
		END
	END;  (* WHILE *)
	Texts.WriteLn(w);  vyHostTexts.InsertErrW(vyHostTexts.cNotify, w)
END MsgSyntax;

(** default access **)
(*= default access to parameter, and simple read procedures. Linefeeds are skipped.
*)

(*	Based on EasyScanner by fof *)
PROCEDURE OpenParScanner* (VAR sc: Scanner);
	VAR i: SIGNED16;
BEGIN
	vyScanners.NewSScanner(sc); 	vyScanners.OpenParScanner(sc);
	i := vyScanners.NextToken(sc)
END OpenParScanner;

PROCEDURE Name* (VAR sc: Scanner;  VAR name: ARRAY OF CHAR): BOOLEAN; 	(*cw990927*)
	VAR done: BOOLEAN;  j: SIGNED16;
BEGIN
	copy^ := sc^;
	LOOP
		CASE sc.class OF
			vyScanners.ctId:  done := vyScanners.GetName(sc, name);  j := vyScanners.NextToken(sc);   RETURN done;
		| vyScanners.ctNL: j := vyScanners.NextToken(sc)
		ELSE sc^ := copy^;  RETURN FALSE
		END
	END
END Name;

PROCEDURE NamedObject* (VAR sc: Scanner;  VAR ob: vyBase.Object): BOOLEAN;
	(*= read a name, and try to find named Voyager object *)
	VAR  name: vyName.tNameArray;
BEGIN
	IF Name(sc, name) THEN ob := vyName.Find(vyName.NameBase, name);  RETURN ob # NIL
	ELSE ob := NIL;  RETURN FALSE END
END NamedObject;
(*jb 20.8.01 *)
PROCEDURE linkedobject (
VAR sc: Scanner;  linkof: Objects.Object;  VAR ob: Objects.Object;  verbose: BOOLEAN
): BOOLEAN;
VAR
	class: SIGNED16;
	obj, objlink: Objects.Object;
	done: BOOLEAN;
	name: vyName.tNameArray;
BEGIN
	obj := linkof;
	class := sc.class;
	LOOP
		IF class # vyScanners.ctId THEN
			IF verbose THEN
				PosMsg(sc);
				Texts.WriteInt (w, class, 10);
				Texts.WriteInt (w, sc.v, 10);
				Texts.WriteString(w, 'an identifier was expected');  Texts.WriteLn(w);
				vyHostTexts.InsertErrW (vyHostTexts.cNotify, w)
			END;
			ob := NIL;  RETURN FALSE
		END;
		done := vyScanners.GetName (sc, name);  ASSERT (done, 101);
		Links.GetLink (obj, name, objlink);  obj := objlink;
		IF obj = NIL THEN
			IF verbose THEN
				PosMsg(sc);
				Texts.WriteString(w, 'did not find link');  Texts.WriteLn(w);
				vyHostTexts.InsertErrW (vyHostTexts.cNotify, w)
			END;
			ob := NIL;  RETURN FALSE
		END;
		class := vyScanners.NextToken (sc);
		IF class # vyScanners.ctSym THEN EXIT (* *)END;
		IF sc.v # vyScanners.csDot THEN EXIT (* *)END;

		class := vyScanners.NextToken (sc)
	END; 	(* LOOP *)
	ob := obj;  RETURN (ob # NIL)

END linkedobject;

(* jb, 20.8.01 *)
PROCEDURE LinkedObject* (
VAR sc: Scanner;  linkof: Objects.Object;  VAR ob: Objects.Object
): BOOLEAN;
BEGIN
	copy^ := sc^;
	IF ~ linkedobject (sc, linkof, ob, FALSE) THEN sc^ := copy^;  RETURN FALSE
	ELSE RETURN TRUE END
END LinkedObject;
(* jb, 20.8.01 *)
PROCEDURE qnamedobject (
VAR sc: Scanner;  context: Objects.Object;  VAR ob: Objects.Object;  verbose: BOOLEAN
): BOOLEAN;
	(*= read a qualified name, and try to find named Voyager object or named Gadgets object or named Link *)
	VAR  name: vyName.tNameArray;
	class: SIGNED16;
	searchInContext, done: BOOLEAN;
	obj: Objects.Object;
BEGIN
	obj := context;
	class := sc.class;
	IF (class = vyScanners.ctSym) & (sc.v = vyScanners.csColon) THEN
		searchInContext := TRUE;
		class := vyScanners.NextToken (sc)
	ELSE
		searchInContext := FALSE
	END;
	IF class = vyScanners.ctId THEN
		done := vyScanners.GetName(sc, name);  ASSERT (done, 100);
		IF searchInContext THEN
			obj := Gadgets.FindObj (context, name)
		ELSE
			obj := vyName.Find (vyName.NameBase, name)
		END;
		IF obj = NIL THEN
			IF verbose THEN
				PosMsg(sc);
				Texts.WriteString(w, 'did not find object');  Texts.WriteLn(w);
				vyHostTexts.InsertErrW (vyHostTexts.cNotify, w)
			END;
			ob := NIL;  RETURN FALSE
		END;
		class := vyScanners.NextToken(sc)
	END;

	IF (class = vyScanners.ctSym) & (sc.v = vyScanners.csDot) THEN
		class := vyScanners.NextToken (sc);
		RETURN linkedobject (sc, obj, ob, verbose)
	ELSE
		ob := obj;  RETURN (ob # NIL)
	END
END qnamedobject;
(* jb, 20.8.01 *)
PROCEDURE QNamedObject* (
VAR sc: Scanner;  context: Objects.Object;  VAR ob: Objects.Object
): BOOLEAN;
BEGIN
	copy^ := sc^;
	IF ~ qnamedobject (sc, context, ob, FALSE) THEN sc^ := copy^;  RETURN FALSE
	ELSE RETURN TRUE END
END QNamedObject;

PROCEDURE Real* (VAR sc: Scanner;  VAR x: FLOAT32): BOOLEAN; 	(*cw990927*)
	(*=read input, and try to evaluate as real number *)
	VAR done: BOOLEAN;  neg: BOOLEAN;  j: SIGNED16;
BEGIN neg := FALSE;
	copy^ := sc^;

	LOOP
		class := sc.class;
		CASE sc.class OF
			vyScanners.ctReal, vyScanners.ctNumber, vyScanners.ctFixed:
			done := vyScanners.GetReal(sc, neg, x);
			j := vyScanners.NextToken(sc);  RETURN done;
		| vyScanners.ctSym: IF sc.v = 7 THEN neg := ~ neg;  j := vyScanners.NextToken(sc)
			ELSE sc^ := copy^; 	RETURN FALSE END;
		| vyScanners.ctNL: j := vyScanners.NextToken(sc)
		ELSE sc^ := copy^; 	RETURN FALSE END
	END
END Real;
(*! add read procedures for other basic types *)
(*! add read procedures to fill complete chunks, eg. Reals *)

PROCEDURE Number* (VAR sc: Scanner;  VAR i: SIGNED32): BOOLEAN; 	(*cw990927*)
	(*= read input, and try to evaluate as SIGNED32 number *)
	VAR done, neg: BOOLEAN;  j: SIGNED16;
BEGIN
	neg := FALSE;
	copy^ := sc^;
	LOOP class := sc.class;
		CASE sc.class OF
			vyScanners.ctNumber: done := vyScanners.GetNumber(sc, neg, i);  j := vyScanners.NextToken(sc);  RETURN done;
		| vyScanners.ctNL: j := vyScanners.NextToken(sc);
		| vyScanners.ctSym: IF sc.v = 7 THEN neg := ~
			neg;  j := vyScanners.NextToken(sc) ELSE sc^ := copy^; 	RETURN FALSE END
		ELSE sc^ := copy^; 	RETURN FALSE END
	END
END Number;

PROCEDURE Symbol* (VAR sc: Scanner;  VAR sym: ARRAY OF CHAR): BOOLEAN; 	(*cw990927*)
	VAR done: BOOLEAN;  j: SIGNED16;
BEGIN	LOOP
		copy^ := sc^;
		CASE sc.class OF
			vyScanners.ctSym: done := vyScanners.GetName(sc, sym) ;  j := vyScanners.NextToken(sc);  RETURN done ;
		| vyScanners.ctNL: j := vyScanners.NextToken(sc)
		ELSE sc^ := copy^;  RETURN FALSE
		END
	END
END Symbol;


(** noisy variants **)
(*= same as above, but write an error message if input is not of expectd type.*)

PROCEDURE PosMsg (sc: Scanner);
BEGIN	Texts.WriteString(w, 'pos ');
	Texts.WriteInt(w, sc.curTokPos, 6);
	Texts.Write(w, ' ')
END PosMsg;

PROCEDURE ExpectName* (VAR sc: Scanner;  VAR name: ARRAY OF CHAR): BOOLEAN;
	VAR temp: BOOLEAN;
BEGIN	temp := Name(sc, name);
	IF ~temp THEN 	PosMsg(sc);
		Texts.WriteString(w, 'a name was expected');  Texts.WriteLn(w);
		vyHostTexts.InsertErrW(vyHostTexts.cNotify, w)
	END;  	RETURN temp
END ExpectName;

PROCEDURE ExpectNamedObject* (VAR sc: Scanner;  VAR ob: vyBase.Object): BOOLEAN;
	VAR temp: BOOLEAN;
BEGIN	temp := NamedObject(sc, ob);
	IF ~temp THEN 	PosMsg(sc);
		Texts.WriteString(w, 'a name of an existing object was expected');
		Texts.WriteLn(w);
		vyHostTexts.InsertErrW(vyHostTexts.cNotify, w)
	END;  	RETURN temp
END ExpectNamedObject;
(* jb, 20.8.01 *)
PROCEDURE ExpectLinkedObject* (
VAR sc: Scanner;  linkof: Objects.Object;  VAR ob: Objects.Object
): BOOLEAN;
BEGIN
	copy^ := sc^;
	IF ~ linkedobject (sc, linkof, ob, TRUE) THEN
		sc^ := copy^;
		PosMsg (sc);
		Texts.WriteString(w, 'a name of existing link name was expected');
		Texts.WriteLn(w);
		vyHostTexts.InsertErrW(vyHostTexts.cNotify, w);
		RETURN FALSE
	ELSE RETURN TRUE END
END ExpectLinkedObject;

(* jb, 20.8.01 *)
PROCEDURE ExpectQNamedObject* (
VAR sc: Scanner;  context: Objects.Object;  VAR ob: Objects.Object
): BOOLEAN;
BEGIN
	copy^ := sc^;
	IF ~ qnamedobject (sc, context, ob, TRUE) THEN
		sc^ := copy^;
		PosMsg (sc);
		Texts.WriteString(w, 'a qualified name of an existing object was expected');
		Texts.WriteLn(w);
		vyHostTexts.InsertErrW(vyHostTexts.cNotify, w);
		RETURN FALSE
	ELSE RETURN TRUE END
END ExpectQNamedObject;

PROCEDURE ExpectReal* (VAR sc: Scanner;  VAR x: FLOAT32): BOOLEAN;
	VAR temp: BOOLEAN;
BEGIN	temp := Real(sc, x);
	IF ~temp THEN 	PosMsg(sc);
		Texts.WriteString(w, 'a FLOAT32 number was expected');  Texts.WriteLn(w);
		vyHostTexts.InsertErrW(vyHostTexts.cNotify, w)
	END;  	RETURN temp
END ExpectReal;

PROCEDURE ExpectNumber* (VAR sc: Scanner;  VAR i: SIGNED32): BOOLEAN;
	VAR temp: BOOLEAN;
BEGIN	temp := Number(sc, i);
	IF ~temp THEN 	PosMsg(sc);
		Texts.WriteString(w, 'an SIGNED16 number was expected');  Texts.WriteLn(w);
		vyHostTexts.InsertErrW(vyHostTexts.cNotify, w)
	END;  	RETURN temp
END ExpectNumber;

(*! Add Unix style getargs *)
BEGIN
	Texts.OpenWriter(w);
	NEW(copy); 	(*cw990927*)

	(*	MsgSyntax('Parser test: Parser.Parse','Rule/2;ThingsToParse/*'); *)
END vyParser.