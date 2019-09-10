MODULE vyXPValues IN Oberon;   (** jb  **)
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


(*
XPValue:
object containing pointers to a real value (x) and its p-value (p) and the name of the distribution type (e.g. "N(0,1)" )
update x value first, as, by convention, objects that need both values should subscibe to p

ActiveXPValue:
abstract base object for objects which self calculate x and/or p
*)
(*
created:
11.1.01 by Johannes Becker
changes:
30.6.01 by Johannes Becker - minor changes (subscribe mechanism, set handler before calling Init...)
14.8.01 by Johannes Becker - handle LinkMsg
18.8.01 by Johannes Becker - KolSmirXP handles NewSimMsg now
11.1.01 by Johannes Becker - bug fixed (subscribe problems)
*)

IMPORT jbrtStdNormal, vyKolSmirL, M := MathL IN A2, vyLongrealVec, vyLongreal, vyBase, Objects, Strings, Gadgets, Files;

TYPE
	Real = vyBase.Real;

	XPValue* = OBJECT  (* POINTER TO XPValueDesc;
	XPValueDesc* = RECORD (vyBase.ObjDesc)*)
	(vyBase.Object)
	VAR x-, p-: vyLongrealVec.tLONGREAL;
		distrName*: ARRAY 32 OF CHAR;

		PROCEDURE  (*VAR xp: XPValueDesc*) GetGenString*( VAR s: ARRAY OF CHAR );
		BEGIN
			COPY( "vyXPValues.AllocXPValue", s )
		END GetGenString;

		PROCEDURE  (*v: XPValue*) Store*( VAR M: Objects.FileMsg );
		BEGIN
			Gadgets.WriteRef( M.R, SELF.lib, SELF.x );  Gadgets.WriteRef( M.R, SELF.lib, SELF.p );
			Files.WriteString( M.R, SELF.distrName );  vyBase.objecthandle( SELF, M )
		END Store;

		PROCEDURE  (*v: XPValue*) Load*( VAR M: Objects.FileMsg );
		VAR objsub: Objects.Object;
		BEGIN
			Gadgets.ReadRef( M.R, SELF.lib, objsub );
			IF (objsub # NIL ) THEN
				WITH objsub: vyLongrealVec.tLONGREAL DO SELF.x := objsub
				END
			END;
			Gadgets.ReadRef( M.R, SELF.lib, objsub );
			IF (objsub # NIL ) THEN
				WITH objsub: vyLongrealVec.tLONGREAL DO SELF.p := objsub
				END
			END;
			Files.ReadString( M.R, SELF.distrName );  vyBase.objecthandle( SELF, M )
		END Load;

	END XPValue;

	ActiveXPValue* = OBJECT  (* POINTER TO ActiveXPValueDesc;
	ActiveXPValueDesc* = RECORD (XPValueDesc)*)
	(XPValue)
	PROCEDURE (* VAR xp: ActiveXPValueDesc*)GetGenString*( VAR s: ARRAY OF CHAR );
	BEGIN
		COPY( "vyXPValues.AllocActiveXPValue", s )
	END GetGenString;

	PROCEDURE (* VAR obj: ActiveXPValueDesc*)NewData*;
	BEGIN
		HALT( 100 )
	END NewData;

	PROCEDURE (*obj: ActiveXPValue*)TakeNewSource*( newSource: Objects.Object;  VAR accepted: BOOLEAN );
	BEGIN
		accepted := FALSE
	END TakeNewSource;

	END ActiveXPValue;

	CalcPXP* = OBJECT  (* POINTER TO CalcPXPDesc;
	CalcPXPDesc* = RECORD (ActiveXPValueDesc) *)
	(ActiveXPValue)
		PROCEDURE (* VAR xp: CalcPXPDesc*)GetGenString*( VAR s: ARRAY OF CHAR );
	BEGIN
		COPY( "vyXPValues.AllocCalcPXP", s )
	END GetGenString;

	PROCEDURE (*obj: CalcPXP*)TakeNewSource*( newSource: Objects.Object;  VAR accepted: BOOLEAN );
	BEGIN
		IF newSource IS vyLongrealVec.tLONGREAL THEN
			WITH newSource: vyLongrealVec.tLONGREAL DO
				vyBase.UnSubscribe( SELF.x, SELF );  SELF.x := newSource;  vyBase.Subscribe( newSource, SELF );  accepted := TRUE
			END;
		ELSE accepted := FALSE
		END
	END TakeNewSource;

	END CalcPXP;

	StdNormalXP* = OBJECT  (* POINTER TO StdNormalXPDesc;
	StdNormalXPDesc* = RECORD (CalcPXPDesc) *)
	(CalcPXP)
		PROCEDURE (* VAR xp: StdNormalXPDesc*)GetGenString*( VAR s: ARRAY OF CHAR );
	BEGIN
		COPY( "vyXPValues.AllocStdNormalXP", s )
	END GetGenString;

	PROCEDURE (* VAR obj: StdNormalXPDesc*)NewData*;
	BEGIN
		SELF.p.x := jbrtStdNormal.Phi( SELF.x.x );  vyBase.Update( SELF.p )
	END NewData;

	END StdNormalXP;

	ExpXP* = OBJECT  (*POINTER TO ExpXPDesc;
	ExpXPDesc* = RECORD (CalcPXPDesc)*)
	(CalcPXP)
	VAR lambda-: Real;

	PROCEDURE (* VAR xp: ExpXPDesc*)GetGenString*( VAR s: ARRAY OF CHAR );
	BEGIN
		COPY( "vyXPValues.AllocExpXP", s )
	END GetGenString;

	PROCEDURE (*v: ExpXP*)Store*( VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteLReal( M.R, SELF.lambda );  SELF.Store^( M )
	END Store;

	PROCEDURE (*v: ExpXP*)Load*( VAR M: Objects.FileMsg );
	BEGIN
		Files.ReadLReal( M.R, SELF.lambda );  SELF.Load^( M )
	END Load;

	PROCEDURE (* VAR obj: ExpXPDesc*)NewData*;
	BEGIN
		SELF.p.x := 1.0 - M.exp( -SELF.lambda * SELF.x.x );  vyBase.Update( SELF.p )
	END NewData;
	END ExpXP;

	KolSmirXP* = OBJECT  (* POINTER TO KolSmirXPDesc;
	KolSmirXPDesc* = RECORD (ActiveXPValueDesc)*)
	(ActiveXPValue)
	VAR source-: vyLongrealVec.tLONGREAL;
		n-: SIGNED32;
		values: POINTER TO ARRAY OF Real;
		cur: SIGNED32;
		PROCEDURE (* VAR xp: KolSmirXPDesc*)GetGenString*( VAR s: ARRAY OF CHAR );
	BEGIN
		COPY( "vyXPValues.AllocKolSmirXP", s )
	END GetGenString;

	PROCEDURE (* VAR obj: KolSmirXPDesc*)NewData*;
	BEGIN
		SELF.values[SELF.cur] := SELF.source.x;  INC( SELF.cur );
		IF SELF.cur >= SELF.n THEN
			vyLongreal.Sort( SELF.n, SELF.values^, 0 );  vyKolSmirL.KS1Id( SELF.values^, SELF.n, SELF.x.x, SELF.p.x );  SELF.cur := 0;
			vyBase.Update( SELF.p )
		END
	END NewData;

	PROCEDURE (*obj: KolSmirXP*)TakeNewSource*( newSource: Objects.Object;  VAR accepted: BOOLEAN );
	BEGIN
		IF newSource IS vyLongrealVec.tLONGREAL THEN
			WITH newSource: vyLongrealVec.tLONGREAL DO
				vyBase.UnSubscribe( SELF.source, SELF );  SELF.source := newSource;  vyBase.Subscribe( newSource, SELF );
				SELF.cur := 0;  accepted := TRUE
			END;
		ELSE accepted := FALSE
		END
	END TakeNewSource;
	PROCEDURE (*v: KolSmirXP*)Store*( VAR M: Objects.FileMsg );
	VAR i, len: SIGNED32;
	BEGIN
		Gadgets.WriteRef( M.R, SELF.lib, SELF.source );  Files.WriteLInt( M.R, SELF.n );  len := LEN( SELF.values^ );  Files.WriteLInt( M.R, len );
		FOR i := 0 TO len - 1 DO Files.WriteLReal( M.R, SELF.values[i] ) END;
		Files.WriteLInt( M.R, SELF.cur );  SELF.Store^( M )
	END Store;

	PROCEDURE (*v: KolSmirXP*)Load*( VAR M: Objects.FileMsg );
	VAR i, len: SIGNED32;  objsub: Objects.Object;
	BEGIN
		Gadgets.ReadRef( M.R, SELF.lib, objsub );
		WITH objsub: vyLongrealVec.tLONGREAL DO SELF.source := objsub
		END;
		Files.ReadLInt( M.R, SELF.n );  Files.ReadLInt( M.R, len );  NEW( SELF.values, len );
		FOR i := 0 TO len - 1 DO Files.ReadLReal( M.R, SELF.values[i] ) END;
		Files.ReadLInt( M.R, SELF.cur );  SELF.Load^( M )
	END Load;

	END KolSmirXP;

	KolSmirVecXP* = OBJECT  (* POINTER TO KolSmirVecXPDesc;
	KolSmirVecXPDesc* = RECORD (ActiveXPValueDesc)*)
	(ActiveXPValue)
	VAR source-: vyBase.tVector;
		n-: SIGNED32;
		a: POINTER TO ARRAY OF Real;
	PROCEDURE (* VAR xp: KolSmirVecXPDesc*)GetGenString*( VAR s: ARRAY OF CHAR );
	BEGIN
		COPY( "vyXPValues.AllocKolSmirVecXP", s )
	END GetGenString;

	PROCEDURE (*v: KolSmirVecXP*)Store*( VAR M: Objects.FileMsg );
	VAR len, i: SIGNED32;
	BEGIN
		Gadgets.WriteRef( M.R, SELF.lib, SELF.source );  Files.WriteLInt( M.R, SELF.n );  len := LEN( SELF.a^ );  Files.WriteLInt( M.R, len );
		FOR i := 0 TO len - 1 DO Files.WriteLReal( M.R, SELF.a[i] ) END;
		SELF.Store^( M )
	END Store;

	PROCEDURE (*v: KolSmirVecXP*)Load*( VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;  len, i: SIGNED32;
	BEGIN
		Gadgets.ReadRef( M.R, SELF.lib, objsub );
		WITH objsub: vyBase.tVector DO SELF.source := objsub
		END;
		Files.ReadLInt( M.R, SELF.n );  Files.ReadLInt( M.R, len );  NEW( SELF.a, len );
		FOR i := 0 TO len - 1 DO Files.ReadLReal( M.R, SELF.a[i] ) END;
		SELF.Load^( M )
	END Load;

	PROCEDURE (* VAR obj: KolSmirVecXPDesc*)NewData*;
	BEGIN
		vyLongrealVec.CopyToArray( SELF.source, SELF.a^ );  vyLongreal.Sort( SELF.n, SELF.a^, 0 );
		vyKolSmirL.KS1Id( SELF.a^, SELF.n, SELF.x.x, SELF.p.x );  vyBase.Update( SELF.x );  vyBase.Update( SELF.p )
	END NewData;

	PROCEDURE (*obj: KolSmirVecXP*)TakeNewSource*( newSource: Objects.Object;  VAR accepted: BOOLEAN );
	VAR vec: vyBase.tVector;
	BEGIN
		IF newSource IS vyBase.Object THEN
			WITH newSource: vyBase.Object DO
				vec := vyBase.GetVFromObj( newSource );
				IF vec = NIL THEN accepted := FALSE;  RETURN END;
				vyBase.UnSubscribe( SELF.source, SELF );  KolSmirVecXPNewSource( SELF, vec );  vyBase.Subscribe( vec, SELF );
				accepted := TRUE
			END;
		ELSE accepted := FALSE
		END
	END TakeNewSource;

	END KolSmirVecXP;


	(** XPValue *)


	PROCEDURE XPValueHandleLinkMsg( o: XPValue;  VAR M: Objects.LinkMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "x" THEN M.obj := o.x;  M.res := 0
			ELSIF M.name = "p" THEN M.obj := o.p;  M.res := 0
			ELSE vyBase.objecthandle( o, M )
			END
		ELSIF M.id = Objects.set THEN
			IF (M.name = "x") OR (M.name = "p") THEN  (* *) ELSE vyBase.objecthandle( o, M ) END
		ELSIF M.id = Objects.enum THEN M.Enum( "x" );  M.Enum( "p" );  vyBase.objecthandle( o, M )
		ELSE vyBase.objecthandle( o, M )
		END
	END XPValueHandleLinkMsg;

	PROCEDURE HandleXPValue*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR xp: XPValue;
	BEGIN
		WITH o: XPValue DO xp := o
		END;

		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF (M.id = Objects.get) & (M.name = "Gen") THEN o( XPValue ).GetGenString( M.s );  M.class := Objects.String;  M.res := 0
				ELSE vyBase.objecthandle( o, M )
				END
			END;
		ELSIF M IS Objects.LinkMsg THEN
			WITH M: Objects.LinkMsg DO XPValueHandleLinkMsg( xp, M )

			END;
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.load THEN xp.Load( M );  vyBase.objecthandle( o, M )
				ELSIF M.id = Objects.store THEN xp.Store( M );  vyBase.objecthandle( o, M )
				ELSE vyBase.objecthandle( o, M )
				END
			END;
		ELSIF M IS Objects.BindMsg THEN
			WITH M: Objects.BindMsg DO
				Gadgets.BindObj( xp.x, M.lib );  Gadgets.BindObj( xp.p, M.lib );  vyBase.objecthandle( o, M )
			END;
		ELSE vyBase.objecthandle( o, M )
		END
	END HandleXPValue;

	PROCEDURE InitXPValue*( value: XPValue;  x, p: vyLongrealVec.tLONGREAL );
	BEGIN
		ASSERT ( x # NIL , 100 );
		ASSERT ( p # NIL , 101 );
		IF value.handle = NIL THEN value.handle := HandleXPValue END;   (* jb 30.6.01 *)
		value.x := x;  value.p := p;  value.distrName := "";
		(* vyBase.Subscribe (x, value); *) vyBase.Subscribe( value, p ) (* jb 30.6.01 *)  (* jb 1.11.01 *)
	END InitXPValue;

	PROCEDURE AllocXPValue*;
	VAR value: XPValue;
	BEGIN
		NEW( value );  value.handle := HandleXPValue;  Objects.NewObj := value
	END AllocXPValue;

	(*
PROCEDURE NewXPValue* (): XPValue;
VAR
value: XPValue;
BEGIN
NEW (value); value.handle := HandleXPValue; RETURN value
END NewXPValue;

PROCEDURE GenXPValue*;
(*= generate uninitialized XPValue *)
BEGIN
Objects.NewObj := NewXPValue ()
END GenXPValue;
*)

(** ActiveXPValue *)


	PROCEDURE HandleActiveXPValue*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR value: ActiveXPValue;
	BEGIN
		value := o( ActiveXPValue );
		IF M IS vyBase.UpdateMessage THEN
			WITH M: vyBase.UpdateMessage DO value.NewData
				(*! | msg: vyBase.CopyMsg DO *)
			END;
		ELSE HandleXPValue( o, M )
		END
	END HandleActiveXPValue;

	PROCEDURE InitActiveXPValue*( value: XPValue;  x, p: vyLongrealVec.tLONGREAL );
	BEGIN
		IF value.handle = NIL THEN value.handle := HandleActiveXPValue END;
		InitXPValue( value, x, p )
	END InitActiveXPValue;

	PROCEDURE AllocActiveXPValue*;
	VAR value: ActiveXPValue;
	BEGIN
		NEW( value );  value.handle := HandleActiveXPValue;  Objects.NewObj := value
	END AllocActiveXPValue;


(** CalcPXP *)


	PROCEDURE InitCalcPXP*( value: CalcPXP;  x, p: vyLongrealVec.tLONGREAL );
	BEGIN
		InitActiveXPValue( value, x, p );  vyBase.Subscribe( x, value )
	END InitCalcPXP;

	PROCEDURE AllocCalcPXP*;
	VAR value: CalcPXP;
	BEGIN
		NEW( value );  value.handle := HandleActiveXPValue;  Objects.NewObj := value
	END AllocCalcPXP;


(** StdNormalXP *)


	PROCEDURE InitStdNormalXP*( obj: StdNormalXP;  x, p: vyLongrealVec.tLONGREAL );
	BEGIN
		InitCalcPXP( obj, x, p );  obj.distrName := "N (0,1)"
	END InitStdNormalXP;

	PROCEDURE AllocStdNormalXP*;
	VAR value: StdNormalXP;
	BEGIN
		NEW( value );  value.handle := HandleActiveXPValue;  Objects.NewObj := value
	END AllocStdNormalXP;


(** ExpXP *)


	PROCEDURE ExpXPGetName( VAR s: ARRAY OF CHAR;  lambda: Real );
	VAR t: ARRAY 16 OF CHAR;
	BEGIN
		COPY( "Exp (", s );  Strings.RealToFixStr( lambda, t, 3, 3, 0 );  Strings.Append( s, t );  Strings.Append( s, ")" )
	END ExpXPGetName;

	PROCEDURE InitExpXP*( obj: ExpXP;  lambda: Real;  x, p: vyLongrealVec.tLONGREAL );
	BEGIN
		InitCalcPXP( obj, x, p );  ExpXPGetName( obj.distrName, lambda );  obj.lambda := lambda
	END InitExpXP;

	PROCEDURE AllocExpXP*;
	VAR value: ExpXP;
	BEGIN
		NEW( value );  value.handle := HandleActiveXPValue;  Objects.NewObj := value
	END AllocExpXP;


(** KolSmirXP *)


	PROCEDURE KolSmirXPGetName( VAR s: ARRAY OF CHAR;  n: SIGNED32 );
	VAR t: ARRAY 16 OF CHAR;
	BEGIN
		COPY( "KS (", s );  Strings.IntToStr( n, t );  Strings.Append( s, t );  Strings.Append( s, ")" )
	END KolSmirXPGetName;

	PROCEDURE KolSmirXPClear*( obj: KolSmirXP );
	BEGIN
		obj.cur := 0
	END KolSmirXPClear;

	PROCEDURE HandleKolSmirXP*( obj: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		HandleActiveXPValue( obj, M );
		IF M IS vyBase.NewSimMsg THEN
			WITH obj: KolSmirXP DO KolSmirXPClear( obj )
			END
		END
	END HandleKolSmirXP;

	PROCEDURE InitKolSmirXP*( obj: KolSmirXP;  n: SIGNED32;  source, x, p: vyLongrealVec.tLONGREAL );
	BEGIN
		IF obj.handle = NIL THEN obj.handle := HandleKolSmirXP END;
		InitActiveXPValue( obj, x, p );  KolSmirXPGetName( obj.distrName, n );  obj.n := n;  obj.source := source;
		NEW( obj.values, n );  obj.cur := 0;  vyBase.Subscribe( obj.source, obj )
	END InitKolSmirXP;

	PROCEDURE AllocKolSmirXP*;
	VAR value: KolSmirXP;
	BEGIN
		NEW( value );  value.handle := HandleKolSmirXP;  Objects.NewObj := value
	END AllocKolSmirXP;


(** KolSmirVecXP *)


	PROCEDURE KolSmirVecXPGetName( VAR s: ARRAY OF CHAR;  n: SIGNED32 );
	VAR t: ARRAY 16 OF CHAR;
	BEGIN
		COPY( "KS (", s );  Strings.IntToStr( n, t );  Strings.Append( s, t );  Strings.Append( s, ")" )
	END KolSmirVecXPGetName;

	PROCEDURE KolSmirVecXPNewSource( obj: KolSmirVecXP;  source: vyBase.tVector );
	VAR n: SIGNED32;
	BEGIN
		n := source.nrData;  KolSmirVecXPGetName( obj.distrName, n );  obj.n := n;  obj.source := source;  NEW( obj.a, n )
	END KolSmirVecXPNewSource;


	PROCEDURE InitKolSmirVecXP*( obj: KolSmirVecXP;  source: vyBase.tVector;  x, p: vyLongrealVec.tLONGREAL );
	BEGIN
		InitActiveXPValue( obj, x, p );  KolSmirVecXPNewSource( obj, source );  vyBase.Subscribe( source, obj )
	END InitKolSmirVecXP;

	PROCEDURE AllocKolSmirVecXP*;
	VAR value: KolSmirVecXP;
	BEGIN
		NEW( value );  value.handle := HandleActiveXPValue;  Objects.NewObj := value
	END AllocKolSmirVecXP;

END vyXPValues.
