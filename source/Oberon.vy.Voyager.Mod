MODULE Voyager IN Oberon;
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


(* 	(c) Project Voyager, StatLab Heidelberg
(c) G. Sawitzki, F. Friedrich. StatLab Heidelberg
*)

(***** 	Voyager i/o module *****)

(*= Unify and arbitrate various low level services.
While before beta stage, this unit may be used to try ad-hoc implementations and have a lot of garbage
*)
(* jb 4.8.01, 19.8.01, 5.11.01 - extended command line syntax for Show *)


(*!To add:
Voyager.Define Factor xyz levels: a b c
Voyager.Define Design cross xyz*abc(def)
Voyager.Define Format nice 8.2 km/h
Voyager.Forget
Voyager.GC
*)
(* vy/tools/Voyager.Panel
LayLa.OpenAsDoc
(TABLE Panel (border=2 sameWidth=TRUE orientation=HOR cols=4 rows=4)  (ATTR Color=5)
(NEW Caption  ( w=80 h=16) (ATTR Value='Voyager'))
(NEW  Button (w=80 h=16)  (ATTR Caption='Log' Cmd='Voyager.OpenLog temp.log'  Color=4))
(NEW  Button (w=80 h=16)  (ATTR Caption='Free' Cmd='System.Free Voyager ~' ))
VIRTUAL

VIRTUAL
(NEW  Button (w=80 h=16)  (ATTR Caption='ReadData @' Cmd='Voyager.ReadData @ ~'))
(NEW  Button (w=80 h=16)  (ATTR Caption='ReadData ^' Cmd='Voyager.ReadData ^ ~'))
VIRTUAL

VIRTUAL
(NEW  Button (w=80 h=16)  (ATTR Caption='Summary @' Cmd='Voyager.Summary @ ~'))
(NEW  Button (w=80 h=16)  (ATTR Caption='Show @' Cmd='Voyager.Show @ ~'))

VIRTUAL
)) ~
*)
IMPORT Objects, Texts, vyLinks, vyHostTexts
	, vyBase (* object management *)
	, vyName (* name arbitration *)
	, vyScanners (*! Remove dependency on Scanners *)
	, vyParser, vyRealVec
	, vyTypes (* basic data types *)
	, vyRanBase, vyRandom (* random number generation *)
	, vyMouseData, vyRegress, vyHostStrings, Gadgets, Links;

CONST
	idversion* = 'Voyager v0.1a3';  cDefaultPlotName = 'vyScatter';

TYPE
	tGeneratorProc = PROCEDURE ( ): FLOAT64;

VAR
	gnrObjects: SIGNED16;  gplotname: vyName.tNameArray;  gobjects: Objects.Object;  gGenerator: tGeneratorProc;

	PROCEDURE ReadData*;   (*vs 0.1d3 gs *)
	(*= Syntax: ReadData <Name> <data>. Line breaks are ignored *)
	(*! support mixed type input *)
	VAR x: FLOAT32;  name: vyName.tNameArray;  o: vyBase.tVector;  sc: vyParser.Scanner;
	BEGIN
		o := vyRealVec.New( 0 );  vyParser.OpenParScanner( sc );
		IF ~vyParser.Name( sc, name ) THEN name := "no name" END;
		WHILE vyParser.Real( sc, x ) DO vyRealVec.Append( x, o ) END;
		(* Debug *)
		Texts.WriteString( vyHostTexts.w, name );  Texts.Write( vyHostTexts.w, ":" );
		Texts.WriteInt( vyHostTexts.w, o.nrData, 8 );  Texts.WriteString( vyHostTexts.w, " numeric values read. " );  Texts.WriteLn( vyHostTexts.w );
		vyHostTexts.InsertLog( vyHostTexts.w.buf );
		(* Debug End *)
		vyName.RegisterNamed( o, name )
	END ReadData;

	PROCEDURE ReadTable*;   (*vs 0.1d1 gs *)
	(*= Syntax: ReadData <Name> <data>. Cases are separated by line breaks. Vars must be same as nuber of names. *)
	(*! support mixed type input *)
	VAR x: FLOAT32;  name: vyName.tNameArray;  o: vyBase.tVector;  first, q: vyLinks.Link;  sc: vyParser.Scanner;
	BEGIN
		NEW( first );  first.link := NIL;  q := first;  vyParser.OpenParScanner( sc );
		WHILE vyParser.Name( sc, name ) DO
			o := vyRealVec.New( 0 );  NEW( q.link );  q := q.link;  q.obj := o;  q.link := NIL;  vyName.RegisterNamed( o, name );
			(* Debug *)
			Texts.WriteString( vyHostTexts.w, name );  Texts.Write( vyHostTexts.w, 09X );
			vyHostTexts.InsertLog( vyHostTexts.w.buf )
			(* Debug End *)
		END;
		Texts.WriteLn( vyHostTexts.w );  vyHostTexts.InsertLog( vyHostTexts.w.buf );
		(*vyScanners.Dump(vyHostTexts.w,sc);*)
		q := first.link;
		WHILE vyParser.Real( sc, x ) DO  (*vyScanners.Dump(vyHostTexts.w,sc);*)
			vyRealVec.Append( x, q.obj( vyBase.tVector ) );
			IF q.link = NIL THEN q := first.link ELSE q := q.link END
		END
	END ReadTable;

	PROCEDURE WriteData*;
	VAR name: vyName.tNameArray;  ob: vyBase.Object;  sc: vyParser.Scanner;
	BEGIN
		vyParser.OpenParScanner( sc );
		IF ~vyParser.Name( sc, name ) THEN vyParser.MsgSyntax( "WriteData", "name/1" );  RETURN END;

		ob := vyName.Find( vyName.NameBase, name );
		IF ob = NIL THEN vyHostTexts.MsgSS( "Did not find", name )
		ELSE
			(*! replace generic write*)
			IF ob IS vyBase.tData THEN
				vyTypes.Write( vyHostTexts.w, ob( vyBase.tData ) );  Texts.WriteLn( vyHostTexts.w );
				vyHostTexts.InsertLog( vyHostTexts.w.buf )
			ELSE vyHostTexts.MsgSS( "No write procedure for type of ", name )
			END
		END
		(*	vyHostTexts.MsgStS("End of",name);*)
	END WriteData;

	PROCEDURE WriteTable*;
	(*! transpose, and use decent format *)
	VAR name: vyName.tNameArray;  ob: vyBase.Object;  sc: vyParser.Scanner;
	BEGIN
		vyParser.OpenParScanner( sc );

		LOOP
			IF ~vyParser.Name( sc, name ) THEN EXIT END;
			(*! needs generic procedure: list of names -> queue *)
			ob := vyName.Find( vyName.NameBase, name );
			IF ob = NIL THEN vyHostTexts.MsgSS( "Did not find", name )
			ELSE
				(*! replace generic write*)
				IF ob IS vyBase.tData THEN
					vyTypes.Write( vyHostTexts.w, ob( vyBase.tData ) );  Texts.WriteLn( vyHostTexts.w );
					vyHostTexts.InsertLog( vyHostTexts.w.buf )
				ELSE vyHostTexts.MsgSS( "No write procedure for type of ", name )
				END
			END
		END
		(*	vyHostTexts.MsgStS("End of",name);*)
	END WriteTable;

	PROCEDURE Summary*;
	VAR name: vyName.tNameArray;  ob: vyBase.Object;  sc: vyParser.Scanner;
	BEGIN
		vyParser.OpenParScanner( sc );
		IF ~vyParser.Name( sc, name ) THEN vyHostTexts.Msg( "Syntax: Summary <name>" );  RETURN END;

		ob := vyName.Find( vyName.NameBase, name );
		IF ob = NIL THEN vyHostTexts.MsgSS( "Did not find", name )
		ELSE
			(*! replace generic write*)
			IF ob IS vyBase.tVector THEN
				vyTypes.Summary( vyHostTexts.w, ob( vyBase.tVector ) );
				(*
			Texts.WriteString(vyHostTexts.w,"Nr of observations: "); Texts.WriteInt(vyHostTexts.w,ob(vyBase.tVector).nrData,0);Texts.WriteLn(vyHostTexts.w);
			(*	VoyagerTypes.Summary(vyHostTexts.w,ob(VoyagerTypes.tVector).buf);  *)
			c:=ob(vyBase.tVector);
			Texts.WriteString(vyHostTexts.w,"Summary by chunks: "); Texts.WriteLn(vyHostTexts.w);
			WHILE c#NIL DO
			Texts.WriteString(vyHostTexts.w,"Nr in chunk: ");
			Texts.WriteInt(vyHostTexts.w,c.usedentries,0);Texts.WriteLn(vyHostTexts.w);
			IF c IS vyTypes.tChunkREAL THEN
			Texts.WriteString(vyHostTexts.w,"min in chunk: "); Texts.WriteReal(vyHostTexts.w,c(vyTypes.tChunkREAL).min,8);Texts.WriteLn(vyHostTexts.w);
			Texts.WriteString(vyHostTexts.w,"max in chunk: "); Texts.WriteReal(vyHostTexts.w,c(vyTypes.tChunkREAL).max,8);Texts.WriteLn(vyHostTexts.w);

			Texts.WriteString(vyHostTexts.w,"mean in chunk: "); Texts.WriteReal(vyHostTexts.w,SHORT(c(vyTypes.tChunkREAL).mean),8);Texts.WriteLn(vyHostTexts.w);
			IF c(vyTypes.tChunkREAL).usedentries>1 THEN Texts.WriteString(vyHostTexts.w,"var in chunk: "); Texts.WriteReal(vyHostTexts.w,SHORT(c(vyTypes.tChunkREAL).ssq/(c(vyTypes.tChunkREAL).usedentries-1)),8);Texts.WriteLn(vyHostTexts.w);END;
			END;
			c:=c.link;
			END; *)
				Texts.WriteLn( vyHostTexts.w );  vyHostTexts.InsertLog( vyHostTexts.w.buf )
			ELSE vyHostTexts.MsgSS( "No summary procedure for type of ", name )
			END
		END
		(*	vyHostTexts.MsgStS("End of",name);*)
	END Summary;

	PROCEDURE Regress*;
	BEGIN
		vyRegress.Regress
	END Regress;

	PROCEDURE capsarg( VAR arg: vyName.tNameArray );
	VAR j: SIGNED16;
	BEGIN
		COPY( vyHostTexts.S.s, arg );  j := 0;
		WHILE arg[j] # 0X DO
			IF arg[j] # 32X THEN arg[j] := CAP( arg[j] ) END;
			INC( j )
		END;
		arg[j] := 0X
	END capsarg;
(* jb 20.8.01 *)
	PROCEDURE NextDot( VAR str: ARRAY OF CHAR;  VAR i: SIGNED16;  VAR part: ARRAY OF CHAR ): BOOLEAN;
	VAR c: CHAR;  partlen: SIGNED32;  j: SIGNED32;
	BEGIN
		partlen := LEN( part );
		IF i >= LEN( str ) THEN COPY( "", part );  RETURN FALSE END;
		j := 0;
		LOOP
			c := str[i];
			IF j < partlen THEN part[j] := c ELSE part[partlen - 1] := 0X END;
			IF c = 0X THEN RETURN FALSE END;
			IF c = "." THEN part[j] := 0X;  RETURN TRUE END;
			INC( i );  INC( j )
		END
	END NextDot;
	(* jb 20.8.01 *)
(*? use vyParser instead??? *)
	PROCEDURE Locate( VAR procname: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR;  context: Objects.Object ): Objects.Object;
	VAR curpos: SIGNED16;  part: vyName.tNameArray;  obj, objlink: Objects.Object;  dotfound, searchInContext: BOOLEAN;
	BEGIN
		curpos := 0;
		IF name[0] = ":" THEN searchInContext := TRUE;  INC( curpos ) ELSE searchInContext := FALSE END;
		dotfound := NextDot( name, curpos, part );
		IF part # "" THEN
			IF searchInContext THEN obj := Gadgets.FindObj( context, part ) ELSE obj := vyName.Find( vyName.NameBase, part ) END;
			IF obj = NIL THEN vyHostTexts.NoteSSS( vyHostTexts.cWarning, procname, "Did not find", part );  RETURN NIL END
		ELSE obj := context
		END;
		WHILE dotfound DO
			INC( curpos );  dotfound := NextDot( name, curpos, part );  Links.GetLink( obj, part, objlink );  obj := objlink;
			IF obj = NIL THEN vyHostTexts.NoteSSS( vyHostTexts.cWarning, procname, "Did not find link", part );  RETURN NIL END
		END;
		RETURN obj
	END Locate;

	PROCEDURE Show*;   (*vs 0.1d1 gs *)
	(*! uses extended syntax: name name as: plot-type  *)
	VAR ob: vyBase.Object;  parsdone: BOOLEAN;  cmd, plotname, secname: vyName.tNameArray;  nrObjects: SIGNED16;
		tempref, objects: vyLinks.Link;  sc: vyParser.Scanner;

		tmp: ARRAY 64 OF CHAR;   (* jb, 5.11.01 *)
		procname: ARRAY 10 OF CHAR;
		objobj: Objects.Object;

		PROCEDURE GetPlotName;
		BEGIN
			capsarg( cmd );
			IF (cmd # "AS") & (cmd # "AS:") (* Hack for MacOberon 4.10 *) THEN
				vyHostTexts.NoteSS( vyHostTexts.cWarning, "Did not understand", cmd );  RETURN
			ELSE
				Texts.Read( vyHostTexts.S, vyHostTexts.S.nextCh );   (*skip delim*)
				Texts.Scan( vyHostTexts.S );
				IF vyHostTexts.S.class # Texts.Name THEN vyHostTexts.Note( vyHostTexts.cWarning, "Plot type name expected" );  RETURN END;
				COPY( vyHostTexts.S.s, plotname )
				(* md * capsarg(plotname);*)
			END  (* cmd AS *)
		END GetPlotName;

	BEGIN
		procname := "Show:";   (* jb, 5.11.01 *)

		vyParser.OpenParScanner( sc );
		IF ~vyHostTexts.OpenScanner( vyHostTexts.S ) THEN RETURN END;
		nrObjects := 0;  objects := NIL;  plotname := cDefaultPlotName;  parsdone := FALSE;   (* default values *)
		LOOP  (* jb 5.11.01 - handle eot *)
			IF parsdone THEN EXIT END;
			Texts.Scan( vyHostTexts.S );
			IF vyHostTexts.S.eot THEN EXIT END;

			(*! Hack: special case for @ *)
			IF ((vyHostTexts.S.class = Texts.Char) & (vyHostTexts.S.c = "@")) THEN
				vyScanners.OpenSelScanner( sc );
				IF vyParser.Name( sc, secname ) THEN
					(*	vyHostTexts.MsgSS('Insert ',secname);*)
				ELSE vyHostTexts.Note( 0, "Expected a selection" )
				END
			ELSE secname[0] := 0X
			END;

			IF (((vyHostTexts.S.class = Texts.Char) & (vyHostTexts.S.c = "~")) OR (ORD( vyHostTexts.S.nextCh ) = 12)) THEN
				parsdone := TRUE
			ELSIF (vyHostTexts.S.class = Texts.Name) OR (secname[0] # 0X) THEN
				capsarg( cmd );   (* Hack for MacOberon 4.10*)
				(*vyHostTexts.MsgSS("Show: cmd:",cmd);*)
				IF (secname[0] = 0X) & ((vyHostTexts.S.nextCh = ":") OR (vyHostTexts.S.nextCh = "=")) OR
				    ((vyHostTexts.S.s[0] = "a") & (vyHostTexts.S.s[1] = "s") & (vyHostTexts.S.s[2] = 0X))
				(* ! Hack for MacOberon 4.10 *) THEN
					GetPlotName
				ELSE  (* an object name *)
					IF (secname[0] = 0X) THEN
						COPY( vyHostTexts.S.s, tmp ) (* jb 5.11.01 *)
					ELSE
						COPY( secname, tmp ) (* jb 5.11.01 *)
					END;
					(* vyHostTexts.MsgSS('find ',name); *)

					(* changed - jb, 5.11.01 *)
					(*
				ob := vyName.Find(vyName.NameBase, name);
				IF ob = NIL THEN vyHostTexts.NoteSS(vyHostTexts.cWarning, "Show: Did not find", name); RETURN
				ELSE (*! add to list. should use generic insert *)
				NEW(tempref); tempref.obj := ob; tempref.link := objects;
				objects := tempref; INC(nrObjects)
				END;
				*)
					(* jb *)
					objobj := Locate( procname, tmp, Gadgets.context );
					IF objobj = NIL THEN RETURN  (* *) END;
					IF objobj IS vyBase.Object THEN
						WITH objobj: vyBase.Object DO ob := objobj
						END;
					ELSE ob := NIL
					END;
					IF ob = NIL THEN vyHostTexts.NoteSS( vyHostTexts.cWarning, "Show: Not a voyager object ", tmp );  RETURN
							ELSE  (*! add to list. should use generic insert *)
						NEW( tempref );  tempref.obj := ob;  tempref.link := objects;  objects := tempref;  INC( nrObjects )
					END
					(* end jb *)

				END  (* an object name *)
			ELSE vyHostTexts.Note( vyHostTexts.cWarning, "Bad parameter type " )
			END  (* IF *)
		END;   (* WHILE *)
		(*	vyHostTexts.MsgSISI(" Show ",nrObjects,plotname,0); *)  (* for debug *)
		vyBase.Show( objects, nrObjects, plotname );   (*! use translation table ? *)
		gobjects := objects.obj;  gnrObjects := nrObjects;  gplotname := plotname
	END Show;


(*
PROCEDURE Show*; (*vs 0.1d1 gs *)
(*! uses extended syntax: name name as: plot-type  *)
VAR name: vyName.tNameArray; ob: vyBase.Object; parsdone: BOOLEAN;
cmd, plotname, secname: vyName.tNameArray;newobj:Objects.Object;
nrObjects: SIGNED16;
tempref, objects: vyLinks.Link;
sc: vyParser.Scanner;
tmp: ARRAY 64 OF CHAR;	(* jb, 5.11.01 *)
procname: ARRAY 10 OF CHAR;
objobj: Objects.Object;

PROCEDURE GetPlotName;
BEGIN capsarg(cmd);
IF (cmd # "AS") & (cmd # "AS:") (* Hack for MacOberon 4.10 *)THEN
vyHostTexts.NoteSS(vyHostTexts.cWarning, "Did not understand", cmd); RETURN
ELSE Texts.Read(vyHostTexts.S, vyHostTexts.S.nextCh);  (*skip delim*)
Texts.Scan(vyHostTexts.S);
IF vyHostTexts.S.class # Texts.Name THEN
vyHostTexts.Note(vyHostTexts.cWarning, "Plot type name expected"); RETURN END;
COPY(vyHostTexts.S.s, plotname)
(* md * capsarg(plotname);*)
END; (* cmd AS *)
END GetPlotName;

BEGIN
procname := "Show:"; (* jb, 5.11.01 *)


vyParser.OpenParScanner(sc); IF ~ vyHostTexts.OpenScanner(vyHostTexts.S) THEN RETURN END;
nrObjects := 0; objects := NIL; plotname := cDefaultPlotName; parsdone := FALSE; (* default values *)
WHILE ~parsdone DO Texts.Scan(vyHostTexts.S);
(*! Hack: special case for @ *)
IF  ( (vyHostTexts.S.class = Texts.Char) & (vyHostTexts.S.c = "@") ) THEN
vyScanners.OpenSelScanner(sc);
IF vyParser.Name(sc, secname) THEN
(*	vyHostTexts.MsgSS('Insert ',secname);*)
ELSE vyHostTexts.Note(0, "Expected a selection")
END;
ELSE secname[0] := 0X  END;

IF ( ( (vyHostTexts.S.class = Texts.Char) & (vyHostTexts.S.c = "~") ) OR (ORD(vyHostTexts.S.nextCh) = 12) )
THEN parsdone := TRUE
ELSIF (vyHostTexts.S.class = Texts.Name) OR (secname[0] # 0X) THEN
capsarg(cmd); (* Hack for MacOberon 4.10*)
(*vyHostTexts.MsgSS("Show: cmd:",cmd);*)
IF  (secname[0] = 0X) &
((vyHostTexts.S.nextCh = ":") OR (vyHostTexts.S.nextCh = "=")) OR
((vyHostTexts.S.s[0] = "a") & (vyHostTexts.S.s[1] = "s") & (vyHostTexts.S.s[2] = 0X))
(* ! Hack for MacOberon 4.10 *)THEN
GetPlotName
ELSE (* an object name *)
IF (secname[0] = 0X)  THEN COPY(vyHostTexts.S.s, name)
ELSE COPY(secname, name)
END;
(* vyHostTexts.MsgSS('find ',name); *)
ob := vyName.Find(vyName.NameBase, name);
IF ob = NIL THEN vyHostTexts.NoteSS(vyHostTexts.cWarning, "Show: Did not find", name); RETURN
ELSE (*! add to list. should use generic insert *)
NEW(tempref); tempref.obj := ob; tempref.link := objects;
objects := tempref; INC(nrObjects)
END;
END(* an object name *)
ELSE vyHostTexts.Note(vyHostTexts.cWarning, "Bad parameter type ")
END; (* IF *)
END; (* WHILE *)
(*	vyHostTexts.MsgSISI(" Show ",nrObjects,plotname,0); *)	(* for debug *)
vyBase.Show (objects, nrObjects, plotname); (*! use translation table ? *)
gobjects := objects.obj; gnrObjects := nrObjects; gplotname := plotname;
END Show;
*)

	PROCEDURE Sort*;   (*! uses extended syntax: name {name} as: type *)
	VAR name: vyName.tNameArray;  ob: vyBase.Object;  sc: vyParser.Scanner;  ttv: vyBase.tVector;
	BEGIN
		vyParser.OpenParScanner( sc );
		IF ~vyParser.Name( sc, name ) THEN vyHostTexts.Msg( "Syntax: Sort <name>" );  RETURN END;

		ob := vyName.Find( vyName.NameBase, name );
		IF ob = NIL THEN vyHostTexts.MsgSS( "Did not find", name )
		ELSE
			(*! replace generic sort*)
			IF ob IS vyBase.tVector THEN
				ttv := ob( vyBase.tVector );   (* fof for Ob S3 Windows 960528*)
				vyTypes.Sort( ttv )
			ELSE vyHostTexts.MsgSS( "No sort procedure for type of ", name )
			END
		END
		(*	vyHostTexts.MsgStS("End of",name);*)
	END Sort;

	PROCEDURE StdGauss( ): FLOAT64;
	BEGIN
		RETURN vyRandom.Gauss( 0, 1 )
	END StdGauss;

	PROCEDURE TrappedMouse( ): FLOAT64;
	BEGIN
		RETURN vyMouseData.Random()
	END TrappedMouse;

	PROCEDURE Random*;
	(*! uses extended syntax: n: count samples: nrsamples from: generator pars *)
	VAR i, j, samples, res: SIGNED16;  cmd, generator, name: vyName.tNameArray;  o: vyBase.tVector;  parsdone: BOOLEAN;  skipped: BOOLEAN;
		pre: ARRAY 2 OF CHAR;
	BEGIN
		IF vyHostTexts.OpenScanner( vyHostTexts.S ) THEN
			gGenerator := vyRandom.Uniform;
			i := -1;  samples := 1;  generator := "U";  parsdone := FALSE;   (*default values*)

			WHILE ~parsdone DO
				Texts.Scan( vyHostTexts.S );  skipped := FALSE;
				IF ((vyHostTexts.S.class = Texts.Char) OR (ORD( vyHostTexts.S.nextCh ) = 12)) THEN parsdone := TRUE
				ELSIF vyHostTexts.S.class = Texts.Int THEN i := SHORT( vyHostTexts.S.i );  parsdone := TRUE
				ELSIF (vyHostTexts.S.class = Texts.Name) & ((vyHostTexts.S.nextCh = ":") OR (vyHostTexts.S.nextCh = "=")) OR
						((vyHostTexts.S.s[0] = "f") & (vyHostTexts.S.s[1] = "r") & (vyHostTexts.S.s[2] = "o") & (vyHostTexts.S.s[3] = "m") &
						  (vyHostTexts.S.s[4] = 0X))
				(* ! Hack for MacOberon 4.10 *) THEN  (* named parameter ? *)
					COPY( vyHostTexts.S.s, cmd );
					(*	Texts.WriteString(vyHostTexts.w,cmd); *)
					j := 0;
					WHILE cmd[j] # 0X DO cmd[j] := CAP( cmd[j] );  INC( j )
						END;   (* WHILE *)
					(* ! Hack for MacOberon 4.10 *)
					IF ((cmd[j - 1] = ":") OR (cmd[j - 1] = "=")) THEN DEC( j ) END;
					cmd[j] := 0X;
					(*	vyHostTexts.Msg(cmd);  gs! *)
					Texts.Read( vyHostTexts.S, vyHostTexts.S.nextCh );   (*skip delim*)  (* END *)
					Texts.Scan( vyHostTexts.S );

					IF cmd = "N" THEN
						IF vyHostTexts.S.class = Texts.Int THEN i := SHORT( vyHostTexts.S.i ) ELSE vyHostTexts.Msg( "Syntax error in call to procedure Random.Bad N" );  RETURN END

					ELSIF cmd = "SAMPLES" THEN
						IF vyHostTexts.S.class = Texts.Int THEN samples := SHORT( vyHostTexts.S.i ) ELSE vyHostTexts.Msg( "Syntax error in call to procedure Random.Bad nr of samples" );  RETURN END

					ELSIF cmd = "FROM" THEN  (*! call by name string. avoid dependency *)
						IF vyHostTexts.S.class = Texts.Name THEN
							COPY( vyHostTexts.S.s, generator );
							IF CAP( generator[0] ) = "U" THEN gGenerator := vyRandom.Uniform
							ELSIF CAP( generator[0] ) = "C" THEN gGenerator := vyRandom.Cauchy
							ELSIF CAP( generator[0] ) = "G" THEN gGenerator := StdGauss
							ELSIF CAP( generator[0] ) = "M" THEN gGenerator := TrappedMouse
							ELSE vyHostTexts.Msg( "Sorry. Only uniform, Gauss, Maus and Cauchy random numbers so far..." );  RETURN
							END;
							parsdone := TRUE
						END  (* FROM: name *)
					ELSE vyHostTexts.Msg( "Syntax error in call to procedure Random. No name of generator" );  RETURN
					END

				ELSE
					Texts.WriteInt( vyHostTexts.w, vyHostTexts.S.class, 4 );  Texts.Write( vyHostTexts.w, vyHostTexts.S.nextCh );
					vyHostTexts.Msg( "Syntax error in call to procedure Random." );  RETURN
				END
			END;
			vyHostTexts.MsgSS( "Generator: ", generator );
			IF i < 0 THEN vyHostTexts.Msg( "Random needs an integer count" );  RETURN END;
			IF samples > 0 THEN vyHostTexts.Msg( "New random numbers generated as " ) END;
			WHILE samples > 0 DO o := vyRealVec.New( 0 );
				ASSERT ( (o # NIL ) );
				(*	name := "";
			vyHostStrings.AppendHex(vyRandom.Z,name);
			j := 0;
			WHILE name[j]#0X DO INC(j) END;
			WHILE j>0 DO name[j+1]:=name[j]; DEC(j); END;
			name[0]:=CAP(generator[0]); *)
				pre[0] := CAP( generator[0] );  pre[1] := 0X;  name := '';  vyRanBase.RandomName( pre, name );  j := 0;
				WHILE j < i DO vyRealVec.Append( SHORT( gGenerator() ), o );  INC( j ) END;

				vyName.RegisterNamed( o, name );  vyHostTexts.MsgSS( " ", name );  vyHostStrings.Append( name, " ~" );
				vyBase.CallWString( "Voyager", "vyIcons.MakeIcon", name, FALSE , res );  DEC( samples );  vyHostTexts.Msg( "" )
			END
		END  (* Scanner ok *)
	END Random;

	PROCEDURE NewSampleMd*;
	VAR tempobj: vyBase.Object;  i: SIGNED32;  msg: vyBase.UpdateMessage;
	BEGIN
		tempobj := gobjects( vyBase.Object );
		IF gobjects IS vyBase.tVector THEN
			i := 0
			(* WHILE i< gobjects.o(vyBase.tVector).buf(vyTypes.tChunk).usedentries DO
		(*						IF 	gobjects.o(vyBase.tVector).buf IS vyTypes.tREAL128Chunk THEN
		gobjects.o(vyBase.tVector).buf(vyTypes.tREAL128Chunk).data[i]:=gGenerator();INC(i);
		ELSIF	gobjects.o(vyBase.tVector).buf IS vyTypes.tREAL1024Chunk THEN
		gobjects.o(vyBase.tVector).buf(vyTypes.tREAL1024Chunk).data[i]:=gGenerator();INC(i);

		ELSE (* *) END; (* IF *) *)END;(*WHILE *) *)
		END;
		IF gobjects.slink # NIL THEN gobjects := gobjects.slink;  gobjects.slink := tempobj END;
		gobjects.handle( gobjects( vyBase.Object ), msg );  vyBase.Update( gobjects( vyBase.Object ) )
	END NewSampleMd;

	PROCEDURE NewSample*;
	VAR tempobj: vyBase.Object;  i: SIGNED32;
	BEGIN
		tempobj := gobjects( vyBase.Object );
		IF gobjects IS vyBase.tVector THEN
			i := 0;
			WHILE i < gobjects( vyBase.tVector ).nrData DO
				vyRealVec.Set( SHORT( gGenerator() ), gobjects( vyBase.tVector ), i );  INC( i )
				(*			IF
			gobjects.o(vyBase.tVector).buf IS vyTypes.tREAL128Chunk THEN
			gobjects.o(vyBase.tVector).buf(vyTypes.tREAL128Chunk).data[i]:=gGenerator();INC(i);
			ELSIF	gobjects.o(vyBase.tVector).buf IS vyTypes.tREAL1024Chunk THEN
			gobjects.o(vyBase.tVector).buf(vyTypes.tREAL1024Chunk).data[i]:=gGenerator();INC(i);

			ELSE (* *) END; (* IF *) *)
			END;   (*WHILE *)
		END;
		IF gobjects.slink # NIL THEN gobjects := gobjects.slink;  gobjects.slink := tempobj( vyBase.Object ) END;
		vyBase.Update( gobjects( vyBase.Object ) )
	END NewSample;

(* Background simulation runs *)
	PROCEDURE Register*;   (* set up environments, graphics etc. *)
	BEGIN
		vyBase.ActionRegister( NewSample, 5 )
	END Register;

	PROCEDURE DeRegister*;
	BEGIN
		vyBase.ActionDeRegister( NewSample )
	END DeRegister;
(*
PROCEDURE Prep*; (* set up environments, graphics etc. *)
BEGIN vyHost.Open END Prep;
*)
	PROCEDURE Step*;   (* do one step *)
	BEGIN
		vyBase.Step
	END Step;

	PROCEDURE Run*;   (* run continuously until stop *)
	BEGIN
		vyBase.Run
	END Run;

	PROCEDURE Stop*;   (* suspend simulation *)
	BEGIN
		vyBase.Stop
	END Stop;

	PROCEDURE Id*;   (*vs 0.1d0.gs  show module and version identification *)
	BEGIN
		vyHostTexts.Msg( idversion )
	END Id;

	PROCEDURE help;   (*vs 0.1d0*)
	END help;   (* use this to implement a non-generic version *)

	PROCEDURE set;   (*vs 0.1d0*)
	END set;   (* use this to implement a non-generic version *)

	PROCEDURE status;
	BEGIN
		Id
	END status;   (* use this to implement a non-generic version *)

	PROCEDURE Help*;   (* show help information. If a command is given, show help on this command *)  (* may be maintained or changed by tools *)
	BEGIN
		help
	END Help;

	PROCEDURE Set*;   (* set a status variable. Syntax: set var=val
	set var or set var =? is equivalent to Status var *)
	(* may be maintained or changed by tools *)
	BEGIN
		set
	END Set;

	PROCEDURE Status*;
	BEGIN
		status
	END Status;   (* may be maintained or changed by tools *)

	PROCEDURE Launch*;
	(* Start Voyager, initialize to a well defined state. If a parameter is given, assume it is a filed session and resume *)
	VAR res: SIGNED16;
	BEGIN
		vyBase.CallWString( idversion, "vyHostTexts.OpenLog", "Voyager.Log", FALSE , res );  status;  vyHostTexts.MsgSS( "VoyagerBase", vyBase.idversion );
		vyHostTexts.MsgSS( "Name", vyName.idversion )
	END Launch;

	PROCEDURE OpenLog*;
	BEGIN
		vyHostTexts.OpenLog
	END OpenLog;

END Voyager.
