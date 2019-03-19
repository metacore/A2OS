MODULE antsCommands IN Oberon;   (** fof  **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

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
Report any problems as soon as possible to ants@AntsInFields.de
*)



(* module to parse a command for keywords and succeeding Parameters, uses vyScanners *)
(* if you intend to use this module, please have a short glance at the procedure Test first *)
(* goal: make command preparation easy like
	usage = "obj=OBJECT name=NAME test=INT";
	include preparationproc to test.
*)
(*
		RESTRICTION: antsCommands expects (at least one) blank between symbols +-+-+ gets interpreted as +++.
*)
(*
	020904: can use keyword only once now, allows WHILE(GetName()) DO ...
*)

IMPORT vyName, vyHostStrings, vyBase, vyScanners, Texts, Objects, Gadgets, Links, aM := antsMessages, Modules,
	antsPortability, vyLongintVec, vyLongrealVec;

TYPE
	tParameter* = POINTER TO tParameterDesc;   (* Parameter list, generic type *)
	tParameterDesc* = RECORD
		used: BOOLEAN;
		next-: tParameter;
	END;

	(*** Implement routine for Strings, e.g. filenames !! ***)
	tString* = POINTER TO tStringDesc;
	tStringDesc* = RECORD (tParameterDesc)
		string-: ARRAY 1024 OF CHAR
	END;

	tName* = POINTER TO tNameDesc;   (* caution: here a name MAY be an object as well *)
	tNameDesc* = RECORD (tStringDesc) (* Names are Strings *)
		name-: vyName.tNameArray
	END;

	tReal* = POINTER TO tRealDesc;   (* caution: a real number MAY be an integer number, check the type *)
	tRealDesc* = RECORD (tParameterDesc)
		real-: LONGREAL
	END;

	tNumber* = POINTER TO tNumberDesc;   (* be aware of the fact that a number IS a real number*)
	tNumberDesc* = RECORD (tRealDesc)
		number-: LONGINT
	END;

	tObject* = POINTER TO tObjectDesc;   (* since an Object is identified by a name, in this case an object is treated as name *)
	tObjectDesc* = RECORD (tNameDesc)
		object-: vyBase.Object
	END;

	tSymbol* = POINTER TO tSymbolDesc;
	tSymbolDesc* = RECORD (tParameterDesc)
		symbol-: CHAR
	END;

	tScanList* = POINTER TO tItemDesc;
	tItemDesc = RECORD
		keyname: vyName.tNameArray;
		pars: tParameter;
		text: Texts.Text;
		pos: LONGINT;
		end: LONGINT;
		next: tScanList;
		spos*: LONGINT
	END;

VAR
	keytoken*: CHAR;  lastScanned-: tScanList;
	(* global and exported, always be careful with modes , realize that if once changed will "ever" be *)
CONST
	UnqualifiedName* = "unqualified";  ctObject* = 100;
	(* this is the name under which you may access an unqualified first part of your command *)

VAR
	usageS, callerS: ARRAY 256 OF CHAR;
	haveCaller: BOOLEAN;
	(*
	usage  keywords

	OBJ = vyBase.Object
	REAL = LONGREAL
	INT = LONGINT
	STR = ARRAY OF CHAR
	NAME = Voyager.Name (ARRAY OF CHAR with restrictions)
	[] optional
	{} several
	| or
	() embracement
*)

	PROCEDURE NewItem( VAR item: tScanList;  keyname: ARRAY OF CHAR;  text: Texts.Text;  start, pos: LONGINT );
	BEGIN
		IF item = NIL THEN NEW( item ) ELSE item.end := start;  NEW( item.next );  item := item.next END;
		COPY( keyname, item.keyname );  item.text := text;  item.pos := pos;  item.end := MAX( LONGINT )
	END NewItem;

	PROCEDURE AppendParameter( item: tScanList;  par: tParameter );
	VAR par0: tParameter;
		s: ARRAY 2 OF CHAR;
	BEGIN
		par.used := FALSE;
		IF item.pars = NIL THEN item.pars := par
		ELSE
			par0 := item.pars;
			WHILE par0.next # NIL DO par0 := par0.next END;
			par0.next := par
		END
	END AppendParameter;

	PROCEDURE GetSymbol( sc: vyScanners.Scanner ): CHAR;
	VAR r: Texts.Reader;  ch: CHAR;
	BEGIN
		Texts.OpenReader( r, sc.text, sc.curTokPos );  Texts.Read( r, ch );  RETURN ch
	END GetSymbol;

	PROCEDURE ReadUntilChar( text: Texts.Text;  VAR pos: LONGINT;  start: CHAR;  VAR s: ARRAY OF CHAR;  VAR eot: BOOLEAN );
	VAR re: Texts.Reader;  t: LONGINT;  ch: CHAR;
	BEGIN
		Texts.OpenReader( re, text, pos );  t := 0;  eot := FALSE;
		REPEAT
			Texts.Read( re, ch );  s[t] := ch;  INC( t );
			IF t = LEN( s ) THEN eot := TRUE;  aM.eSI( "String not closed:", pos ) END;
			eot := eot OR re.eot
		UNTIL (ch = start) OR (eot);
		s[t - 1] := 0X;  pos := Texts.Pos( re );
	END ReadUntilChar;

	PROCEDURE ReadString( text: Texts.Text;  VAR pos: LONGINT;  VAR s: ARRAY OF CHAR );
	VAR sc: Texts.Scanner;
	BEGIN
		Texts.OpenScanner( sc, text, pos );  Texts.Scan( sc );
		IF sc.class = Texts.Name THEN COPY( sc.s, s ) ELSE COPY( "", s ) END;
		pos := Texts.Pos( sc ) - 1;
	END ReadString;

	PROCEDURE Qualifier( VAR scanner: vyScanners.Scanner;  VAR start, pos: LONGINT ): BOOLEAN;
	VAR sc: vyScanners.Scanner;  tok: INTEGER;
	BEGIN
		NEW( sc );  sc^ := scanner^;  start := sc.curTokPos;  tok := sc.GetNext( sc );
		IF (sc.class = vyScanners.ctSym) & (GetSymbol( sc ) = "=") THEN
			tok := scanner.GetNext( scanner );  pos := scanner.chpos;  RETURN TRUE
		ELSE RETURN FALSE
		END
	END Qualifier;

	PROCEDURE Qualifier2( VAR scanner: vyScanners.Scanner;  VAR start, pos: LONGINT;  VAR name: ARRAY OF CHAR ): BOOLEAN;
	VAR sc: vyScanners.Scanner;  tok: INTEGER;
	BEGIN
		NEW( sc );  sc^ := scanner^;  start := sc.curTokPos;  tok := sc.GetNext( sc );
		IF (sc.class = vyScanners.ctId) THEN
			IF vyScanners.GetName( sc, name ) THEN tok := scanner.GetNext( scanner );  pos := scanner.chpos;  RETURN TRUE END
		ELSE RETURN FALSE
		END
	END Qualifier2;

	PROCEDURE WaitForEndOfComment( VAR sc: vyScanners.Scanner;  VAR eot: BOOLEAN );
	VAR pos: LONGINT;  re: Texts.Reader;  ch: CHAR;  done: BOOLEAN;
	BEGIN
		pos := sc.curTokPos + 1;  Texts.OpenReader( re, sc.text, pos );  aM.dSI( "antsCommands: Start comment", pos );  ch := 0X;
		REPEAT done := (ch = "*");  Texts.Read( re, ch );  done := (done & (ch = ")"));  eot := eot OR re.eot UNTIL (done) OR (eot);
		pos := Texts.Pos( re );  aM.dSI( "antsCommands: End comment", pos - 2 );  vyScanners.OpenScanner( sc, sc.text, pos, MAX( LONGINT ) );
	END WaitForEndOfComment;

	PROCEDURE Scan*( VAR sc: vyScanners.Scanner ): tScanList;
	VAR anchor, this: tScanList;  Real: tReal;  Number: tNumber;  Name: tName;  sstring: tString;  Symbol: tSymbol;
		name: vyName.tNameArray;  pos, num: LONGINT;  real: REAL;  object: vyBase.Object;  Object: tObject;  negative: BOOLEAN;  count: LONGINT;  start: LONGINT;
		eot: BOOLEAN;  strpos: LONGINT;  tok: INTEGER;  s: CHAR;
		string: ARRAY 1024 OF CHAR;
		temppos: LONGINT;  text: Texts.Text;  noscanonce: BOOLEAN;  objsc: Texts.Scanner;  objpos: LONGINT;  s3obj, vyobj: Objects.Object;

		PROCEDURE check( VAR num: LONGINT );
		BEGIN
			INC( num );
			IF num > 10000 THEN HALT( 100 ) END
		END check;

	BEGIN
		count := 0;  eot := sc.eot;  negative := FALSE;  noscanonce := FALSE;  objpos := -1;
		NewItem( anchor, UnqualifiedName, sc.text, sc.chpos, sc.chpos );  this := anchor;
		WHILE ~eot DO check( count );  pos := sc.curTokPos;

			Texts.OpenScanner( objsc, sc.text, sc.chpos );  Texts.Scan( objsc );
			IF objsc.class = Texts.Object THEN
				s3obj := objsc.obj;  vyScanners.OpenScanner( sc, sc.text, Texts.Pos( objsc ) - 1, MAX( LONGINT ) );  vyobj := NIL;
				Links.GetLink( s3obj, "Model", vyobj );
				IF (vyobj = NIL ) OR (~(vyobj IS vyBase.Object)) THEN Links.GetLink( s3obj, "Value", vyobj ) END;
				IF (vyobj # NIL ) & (vyobj IS vyBase.Object) THEN
					sc.class := ctObject;  name := "";  vyName.AppendObjId( vyobj( vyBase.Object ), name )
				ELSE sc.class := vyScanners.ctStuff
				END;
				noscanonce := TRUE
			END;

			IF ~noscanonce THEN tok := sc.GetNext( sc )
			ELSE noscanonce := FALSE
			END;
			CASE sc.class OF
			vyScanners.ctSym:
					s := GetSymbol( sc );
					IF s = "-" THEN negative := ~negative
					ELSIF (s = "'") OR (s = '"') THEN
						pos := sc.curTokPos + 1;  ReadUntilChar( sc.text, pos, s, string, eot );  NEW( sstring );  COPY( string, sstring.string );
						AppendParameter( this, sstring );
						(*
				text := sc.text;
				WHILE (sc.curTokPos < pos) & (sc.text = text) & (~sc.eot) DO
				tok := sc.GetNext(sc);
				END;
				noscanonce:= TRUE;
				*)

						vyScanners.OpenScanner( sc, sc.text, pos, MAX( LONGINT ) );  negative := FALSE
					ELSIF s = "~" THEN eot := TRUE
					ELSIF s = "(" THEN
						tok := sc.GetNext( sc );
						IF sc.class = vyScanners.ctSym THEN
							s := GetSymbol( sc );
							IF s = "*" THEN WaitForEndOfComment( sc, eot ) END;
						END;
						(* ELSIF s="*" THEN aM.vS("Star"); tok := sc.GetNext(sc); *)
					ELSIF s = keytoken THEN
						IF Qualifier2( sc, start, pos, name ) THEN NewItem( this, name, sc.text, start, pos ) END
					ELSE NEW( Symbol );  Symbol.symbol := s;  AppendParameter( this, Symbol )
					END;
			| ctObject:
					NEW( Object );  COPY( name, Object.name );  Object.object := vyobj( vyBase.Object );  COPY( name, Object.string );
					AppendParameter( this, Object );
			| vyScanners.ctId:
					pos := sc.curTokPos;  strpos := pos;  ReadString( sc.text, strpos, string );
					IF vyScanners.GetName( sc, name ) THEN
						IF Qualifier( sc, start, pos ) THEN NewItem( this, name, sc.text, start, pos ) ELSE
							IF vyHostStrings.Equal( string, name ) THEN
								object := vyName.Find( vyName.NameBase, name );
								IF object # NIL THEN
									NEW( Object );  COPY( name, Object.name );  Object.object := object;  COPY( name, Object.string );
									AppendParameter( this, Object )
								ELSE NEW( Name );  COPY( name, Name.name );  COPY( name, Name.string );  AppendParameter( this, Name )
								END
							ELSE
								NEW( sstring );  COPY( string, sstring.string );  AppendParameter( this, sstring );  text := sc.text;
								WHILE (sc.curTokPos < strpos) & (sc.text = text) & (~sc.eot) DO
									temppos := sc.chpos;  tok := sc.GetNext( sc );
									IF sc.chpos = temppos THEN vyScanners.Ch( sc ) END
								END;
								noscanonce := TRUE
								(*
						vyScanners.OpenScanner(sc, sc.text, strpos, MAX(LONGINT));
						*)
							END
						END;
						negative := FALSE
					END;
			| vyScanners.ctFixed, vyScanners.ctReal:
					IF vyScanners.GetReal( sc, negative, real ) THEN
						NEW( Real );  Real.real := real;  AppendParameter( this, Real );  negative := FALSE
					END;
			| vyScanners.ctNumber:
					IF vyScanners.GetNumber( sc, negative, num ) THEN
						NEW( Number );  Number.number := num;  Number.real := num;  AppendParameter( this, Number );
						negative := FALSE
					END;
			| vyScanners.ctString, vyScanners.ctStuff, vyScanners.ctEOT, vyScanners.ctComment, vyScanners.ctNL:  (*noop*)
			END;
			eot := (eot OR sc.eot OR (count > 5000) OR (sc.ch = "~"))
		END;
		IF sc.eot THEN this.end := sc.chpos ELSE this.end := sc.curTokPos END;
		lastScanned := anchor;  anchor.spos := 1;  RETURN anchor
	END Scan;

	PROCEDURE ScanFromPar*( usage: ARRAY OF CHAR ): tScanList;
	VAR sc: vyScanners.Scanner;  m: Modules.Module;  pc: LONGINT;
	BEGIN
		IF ~haveCaller THEN antsPortability.IdentifyCaller( m, pc );  antsPortability.IdentifyCommand( m, pc, callerS ) END;
		COPY( usage, usageS );  aM.vS( callerS );  vyScanners.NewSScanner( sc );  vyScanners.OpenParScanner( sc );
		haveCaller := FALSE;  RETURN Scan( sc )
	END ScanFromPar;

	PROCEDURE InitScan*( usage: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: LONGINT;
	BEGIN
		antsPortability.IdentifyCaller( m, pc );  antsPortability.IdentifyCommand( m, pc, callerS );  haveCaller := TRUE;
		lastScanned := ScanFromPar( usage );
	END InitScan;

	PROCEDURE ItemFromKeyword( list: tScanList;  key: ARRAY OF CHAR ): tScanList;
	BEGIN
		IF list = NIL THEN list := lastScanned END;
		IF vyHostStrings.Equal( key, "" ) THEN COPY( UnqualifiedName, key ) END;
		WHILE (list # NIL ) DO
			IF vyHostStrings.Equal( key, list.keyname ) THEN RETURN list END;
			list := list.next
		END;
		RETURN NIL
	END ItemFromKeyword;

	PROCEDURE ParsFromKeyword*( list: tScanList;  key: ARRAY OF CHAR ): tParameter;
	(* gives back the ParList from ScanList list identified by token key *)
	(* if keyword is empty, automatically UnqualifiedName will be inserted *)
	VAR this: tScanList;
	BEGIN
		IF key = "" THEN RETURN NIL END;
		this := ItemFromKeyword( list, key );
		IF this # NIL THEN SetPosition( list, this );  RETURN this.pars ELSE RETURN NIL END
	END ParsFromKeyword;

	PROCEDURE SetPosition( list: tScanList;  to: tScanList );
	VAR pars: tParameter;  tpos, pos: LONGINT;
	BEGIN
		pos := 1;
		(* aM.dSI("antsCommands.GetFromPosition: ",pos); *)
		IF list = NIL THEN list := lastScanned END;
		tpos := 1;
		WHILE (list # NIL ) DO
			IF list = to THEN list.spos := pos;  RETURN END;
			pars := list.pars;
			WHILE pars # NIL DO
				(* aM.dSI("tpos: ",tpos); *)
				INC( tpos );  pars := pars.next
			END;
			list := list.next;
		END;
	END SetPosition;

	PROCEDURE GetFromPosition*( list: tScanList ): tParameter;
	VAR pars: tParameter;  tpos, pos: LONGINT;
	BEGIN
		pos := list.spos;
		(* aM.dSI("antsCommands.GetFromPosition: ",pos); *)
		IF list = NIL THEN list := lastScanned END;
		IF list.spos < 1 THEN RETURN NIL END;
		(* pars := ParsFromKeyword(list, UnqualifiedName); *)
		tpos := 1;
		WHILE (list # NIL ) DO
			pars := list.pars;
			WHILE pars # NIL DO
				(* aM.dSI("tpos: ",tpos); *)
				IF pos = tpos THEN RETURN pars END;
				INC( tpos );  pars := pars.next
			END;
			list := list.next;
		END;
		RETURN pars
	END GetFromPosition;

	PROCEDURE GetRealFromKeyword*( list: tScanList;  key: ARRAY OF CHAR;  VAR r: LONGREAL ): BOOLEAN;
	VAR p: tParameter;
	BEGIN
		p := ParsFromKeyword( list, key );
		IF p = NIL THEN
			p := GetFromPosition( list );
			IF (p # NIL ) & (p.used) THEN RETURN FALSE END;
		END;
		IF (p # NIL ) THEN
			IF p IS tReal THEN
				WITH p: tReal DO r := p.real;  p.used := TRUE;  INC( list.spos );  RETURN TRUE
				END;
			ELSIF p IS tObject THEN
				WITH p: tObject DO
					IF p.object IS vyLongintVec.tLONGINT THEN
						r := p.object( vyLongintVec.tLONGINT ).i;  INC( list.spos );  p.used := TRUE;  RETURN TRUE
					ELSIF p.object IS vyLongrealVec.tLONGREAL THEN
						r := p.object( vyLongrealVec.tLONGREAL ).x;  INC( list.spos );  p.used := TRUE;  RETURN TRUE
					END;
				END;
			ELSE
			END
		END;
		RETURN FALSE
	END GetRealFromKeyword;

	PROCEDURE GetReal*( key: ARRAY OF CHAR;  VAR r: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN GetRealFromKeyword( lastScanned, key, r )
	END GetReal;

	PROCEDURE GetNumberFromKeyword*( list: tScanList;  key: ARRAY OF CHAR;  VAR l: LONGINT ): BOOLEAN;
	VAR p: tParameter;
	BEGIN
		p := ParsFromKeyword( list, key );
		IF p = NIL THEN
			p := GetFromPosition( list );
			IF (p # NIL ) & (p.used) THEN RETURN FALSE END;
		END;
		IF (p # NIL ) THEN
			IF p IS tNumber THEN
				WITH p: tNumber DO INC( list.spos );  p.used := TRUE;  l := p.number;  RETURN TRUE
				END;
			ELSIF p IS tObject THEN
				WITH p: tObject DO
					IF p.object IS vyLongintVec.tLONGINT THEN
						l := p.object( vyLongintVec.tLONGINT ).i;  INC( list.spos );  p.used := TRUE;  RETURN TRUE
					END;
				END;
			ELSE
			END
		END;
		RETURN FALSE
	END GetNumberFromKeyword;

	PROCEDURE GetNumber*( key: ARRAY OF CHAR;  VAR l: LONGINT ): BOOLEAN;
	BEGIN
		RETURN GetNumberFromKeyword( lastScanned, key, l )
	END GetNumber;

	PROCEDURE GetStringFromKeyword*( list: tScanList;  key: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR ): BOOLEAN;
	VAR p: tParameter;
	BEGIN
		p := ParsFromKeyword( list, key );
		IF p = NIL THEN
			p := GetFromPosition( list );
			IF (p # NIL ) & (p.used) THEN RETURN FALSE END;
		END;
		IF (p # NIL ) THEN
			IF p IS tString THEN
				WITH p: tString DO INC( list.spos );  p.used := TRUE;  COPY( p.string, name );  RETURN TRUE
				END;
			ELSE
			END
		END;
		RETURN FALSE
	END GetStringFromKeyword;

	PROCEDURE GetString*( key: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		RETURN GetStringFromKeyword( lastScanned, key, name )
	END GetString;

	PROCEDURE GetNameFromKeyword*( list: tScanList;  key: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR ): BOOLEAN;
	VAR p: tParameter;
	BEGIN
		p := ParsFromKeyword( list, key );
		IF (p = NIL ) THEN
			p := GetFromPosition( list );
			IF (p # NIL ) & (p.used) THEN RETURN FALSE END;
		END;
		IF (p # NIL ) THEN
			IF p IS tName THEN
				WITH p: tName DO INC( list.spos );  p.used := TRUE;  COPY( p.name, name );  RETURN TRUE
				END;
			ELSE
			END
		END;
		RETURN FALSE
	END GetNameFromKeyword;

	PROCEDURE GetName*( key: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		RETURN GetNameFromKeyword( lastScanned, key, name )
	END GetName;

	PROCEDURE GetObjectInContext*( key: ARRAY OF CHAR ): Objects.Object;
	VAR context, obj: Objects.Object;
	BEGIN
		context := Gadgets.executorObj;  obj := NIL;  Links.GetLink( context, key, obj );  RETURN obj
	END GetObjectInContext;

	PROCEDURE GetObjectFromKeyword*( list: tScanList;  key: ARRAY OF CHAR;  VAR obj: vyBase.Object ): BOOLEAN;
	VAR p: tParameter;  obj0: Objects.Object;
	BEGIN

		p := ParsFromKeyword( list, key );   (* force name handling by keyword *)
		IF (p = NIL ) THEN
		(* now we try to get the object as a model in current executor context, *)
			(*! disable that functionality !! *)
			obj0 := GetObjectInContext( key );
			IF (obj0 # NIL ) & (obj0 IS vyBase.Object) THEN obj := obj0( vyBase.Object );  RETURN TRUE END
		END;
		IF (p = NIL ) THEN
			p := GetFromPosition( list );
			IF (p # NIL ) & (p.used) THEN RETURN FALSE END;
		END;
		IF (p # NIL ) THEN
			IF p IS tObject THEN
				WITH p: tObject DO INC( list.spos );  p.used := TRUE;  obj := p.object;  RETURN TRUE
				END;
			ELSE
			END
		END;
		RETURN FALSE
	END GetObjectFromKeyword;

	PROCEDURE GetObject*( key: ARRAY OF CHAR;  VAR obj: vyBase.Object ): BOOLEAN;
	BEGIN
		RETURN GetObjectFromKeyword( lastScanned, key, obj )
	END GetObject;

	PROCEDURE ExpectRealFromKeyword*( list: tScanList;  key: ARRAY OF CHAR;  VAR r: LONGREAL ): BOOLEAN;
	BEGIN
		IF ~GetRealFromKeyword( list, key, r ) THEN
			aM.eSS( "antsCommands: Real expected, key:", key );  aM.eSI( "or expected at Position", list.spos );  aM.usage( callerS, usageS );
			IF aM.mode >= aM.debugMode THEN dDumpScanList( list ) END;
			RETURN FALSE
		ELSE RETURN TRUE
		END
	END ExpectRealFromKeyword;

	PROCEDURE ExpectReal*( key: ARRAY OF CHAR;  VAR r: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ExpectRealFromKeyword( lastScanned, key, r )
	END ExpectReal;

	PROCEDURE ExpectNumberFromKeyword*( list: tScanList;  key: ARRAY OF CHAR;  VAR l: LONGINT ): BOOLEAN;
	BEGIN
		IF ~GetNumberFromKeyword( list, key, l ) THEN
			aM.eSS( "antsCommands: Number expected, key:", key );  aM.eSI( "or expected at Position", list.spos );  aM.usage( callerS, usageS );  RETURN FALSE
		ELSE RETURN TRUE
		END
	END ExpectNumberFromKeyword;

	PROCEDURE ExpectNumber*( key: ARRAY OF CHAR;  VAR l: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ExpectNumberFromKeyword( lastScanned, key, l )
	END ExpectNumber;

	PROCEDURE ExpectStringFromKeyword*( list: tScanList;  key: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		IF ~GetStringFromKeyword( list, key, name ) THEN
			aM.eSS( "antsCommands: String expected, key:", key );  aM.eSI( "or expected at Position", list.spos );  aM.usage( callerS, usageS );
			IF aM.mode >= aM.debugMode THEN dDumpScanList( list ) END;
			RETURN FALSE
		ELSE RETURN TRUE
		END
	END ExpectStringFromKeyword;

	PROCEDURE ExpectString*( key: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		RETURN ExpectStringFromKeyword( lastScanned, key, name )
	END ExpectString;

	PROCEDURE ExpectNameFromKeyword*( list: tScanList;  key: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		IF ~GetNameFromKeyword( list, key, name ) THEN
			aM.eSS( "antsCommands: Name expected, key:", key );  aM.eSI( "or expected at Position", list.spos );  aM.usage( callerS, usageS );
			IF aM.mode >= aM.debugMode THEN dDumpScanList( list ) END;
			RETURN FALSE
		ELSE RETURN TRUE
		END
	END ExpectNameFromKeyword;

	PROCEDURE ExpectName*( key: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		RETURN ExpectNameFromKeyword( lastScanned, key, name )
	END ExpectName;

	PROCEDURE ExpectObjectFromKeyword*( list: tScanList;  key: ARRAY OF CHAR;  VAR obj: vyBase.Object ): BOOLEAN;
	BEGIN
		IF ~GetObjectFromKeyword( list, key, obj ) THEN
			aM.eSS( "antsCommands: Object expected, key:", key );  aM.eSI( "or expected at Position", list.spos );  aM.usage( callerS, usageS );
			IF aM.mode >= aM.debugMode THEN dDumpScanList( list ) END;
			RETURN FALSE
		ELSE RETURN TRUE
		END
	END ExpectObjectFromKeyword;

	PROCEDURE ExpectObject*( key: ARRAY OF CHAR;  VAR obj: vyBase.Object ): BOOLEAN;
	BEGIN
		RETURN ExpectObjectFromKeyword( lastScanned, key, obj )
	END ExpectObject;

	PROCEDURE dDumpParList( p: tParameter );
	VAR s: ARRAY 2 OF CHAR;
	BEGIN
		WHILE (p # NIL ) DO
			IF p IS tReal THEN
				WITH p: tReal DO
					aM.dSR( "Real found: ", p.real );
					IF p IS tNumber THEN
						WITH p: tNumber DO aM.dSI( "IS Number:", p.number )
						END;
					ELSE
					END;
				END;
			ELSIF p IS tNumber THEN
				WITH p: tNumber DO aM.dSI( "Number found:", p.number );
				END;
			ELSIF p IS tString THEN
				WITH p: tString DO
					aM.dSS( "String found: ", p.string );
					IF p IS tName THEN aM.dS( "is Name " ) END;
					IF p IS tObject THEN aM.dS( "IS Object" ) END
				END;
			ELSIF p IS tSymbol THEN
				WITH p: tSymbol DO s[0] := p.symbol;  s[1] := 0X;  aM.dSS( "Symbol found:", s )
				END;
			ELSE aM.dS( "???" )
			END;
			p := p.next
		END
	END dDumpParList;

	PROCEDURE dDumpScanList( m: tScanList );
	VAR p: tParameter;  l: tScanList;
	BEGIN
		aM.dS( "antsCommands: Scanning Output  ####################" );
		IF m = NIL THEN m := lastScanned END;
		l := m;
		WHILE (m # NIL ) DO
			aM.dS( "antsCommands Keyword start ------------------" );  aM.dSS( "Keyword:", m.keyname );  aM.dSI( "Position", m.pos );  aM.dSI( "End", m.end );
			(* GetArrayFromKeyword(l,m.keyname,a);aM.S(a); *)
			p := m.pars;  dDumpParList( p );  m := m.next;  aM.dS( "antsCommands Keyword end ------------------" );
		END
	END dDumpScanList;

	PROCEDURE DumpParList*( p: tParameter );
	VAR s: ARRAY 2 OF CHAR;
	BEGIN
		WHILE (p # NIL ) DO
			IF p IS tReal THEN
				WITH p: tReal DO
					aM.SR( "Real found: ", p.real );
					IF p IS tNumber THEN
						WITH p: tNumber DO aM.SI( "IS Number:", p.number )
						END;
					ELSE
					END;
				END;
			ELSIF p IS tNumber THEN
				WITH p: tNumber DO aM.SI( "Number found:", p.number );
				END;
			ELSIF p IS tString THEN
				WITH p: tString DO
					aM.SS( "String found: ", p.string );
					IF p IS tName THEN aM.S( "is Name " ) END;
					IF p IS tObject THEN aM.S( "IS Object" ) END
				END;
			ELSIF p IS tSymbol THEN
				WITH p: tSymbol DO s[0] := p.symbol;  s[1] := 0X;  aM.SS( "Symbol found:", s )
				END;
			ELSE aM.S( "???" )
			END;
			p := p.next
		END
	END DumpParList;

	PROCEDURE DumpScanList*( m: tScanList );
	VAR p: tParameter;  l: tScanList;
	BEGIN

		IF m = NIL THEN m := lastScanned
		END;
		l := m;
		WHILE (m # NIL ) DO
			aM.S( "------------------" );  aM.SS( "Keyword:", m.keyname );  aM.SI( "Position", m.pos );  aM.SI( "End", m.end );
			(* GetArrayFromKeyword(l,m.keyname,a);aM.S(a); *)
			p := m.pars;  DumpParList( p );  m := m.next
		END
	END DumpScanList;

	PROCEDURE FindKeyword*( list: tScanList;  key: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		IF ItemFromKeyword( list, key ) # NIL THEN RETURN TRUE ELSE RETURN FALSE END
	END FindKeyword;

	PROCEDURE ExpectKeyword*( list: tScanList;  key: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		IF FindKeyword( list, key ) THEN RETURN TRUE ELSE aM.eSS( "antsCommands: Keyword expected:", key );  aM.usage( callerS, usageS );  RETURN FALSE END
	END ExpectKeyword;

	PROCEDURE Find*( key: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		RETURN FindKeyword( lastScanned, key )
	END Find;

	PROCEDURE Expect*( key: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		RETURN ExpectKeyword( lastScanned, key );
	END Expect;

	PROCEDURE Test*;
	VAR sc: vyScanners.Scanner;  m: tScanList;  p: tParameter;  name: vyName.tNameArray;  real: LONGREAL;  number: LONGINT;
	BEGIN
		vyScanners.NewSScanner( sc );  vyScanners.OpenParScanner( sc );  m := Scan( sc );  DumpScanList( m );  aM.S( "------------------" );
		aM.SS( "Looking for Keyword:", "ww" );
		IF FindKeyword( m, "ww" ) THEN aM.S( "Keword found, looking for parameters:" ) END;
		p := ParsFromKeyword( m, "ww" );
		IF p # NIL THEN aM.S( "found:" );  DumpParList( p ) ELSE aM.S( " not found !! " ) END;
		IF GetNameFromKeyword( m, "test1", name ) THEN aM.SS( "value(test1,1)=", name ) END;
		IF GetRealFromKeyword( m, "test2", real ) THEN aM.SR( "value(test2,2)=", real ) END;
		IF GetNumberFromKeyword( m, "test3", number ) THEN aM.SI( "value(test3,3)=", number ) END;
		IF GetStringFromKeyword( m, "test4", name ) THEN aM.SS( "value(test4,4)=", name ) END
	END Test;

BEGIN
	aM.launch;  keytoken := ">";
END antsCommands.


(* remember to set the caret to System.Log first, since the test-procedure writes to the caret *)
System.Free antsCommands ~

antsCommands.Test > name name > file @ ~~~

System.Free antsCommands vyParser vyScanners~
antsCommands.ScannerTest Felix = "Test"Capture = "session"~

antsCommands.Test   a b 12 "String x*x"Felix = aha "Dies ist @"

ein Test" number =  -1.23 from = test -55 +55 "

1.2E05  test2 = 2.513

antsCommands.ScannerTest > test @  name 123

2.4 ~
test = felix ~


antsCommands.Test  123abc+a+a +-+-+ *) a b a 12 "String x*x" Felix = aha "Dies ist @" (*oh jeh*)  aaaaa    Desktops.OpenWinDoc
antsLog.Panel ww=hhh ~

antsMessages.SetMode debug
antsCommands.Test +-+-+-+   ~
