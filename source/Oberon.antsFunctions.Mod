MODULE antsFunctions IN Oberon;   (** fof  **)
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




IMPORT antsObjects, vyName, antsCommands, vyBase, vyLongrealVec, Files, Objects, Gadgets, vyHostTexts, antsOnTheFly,
	Texts, Links, aM := antsMessages;

TYPE
	Array* = POINTER TO ARRAY OF FLOAT64;

	Function* = POINTER TO FunctionDesc;

	FunctionDesc* = RECORD (vyBase.ObjDesc)
		of: Function;
		x, val: vyBase.tVector;   (* if get: interpolate, if set insert new value, cache should be kept outside this module. *)
		f1d: antsOnTheFly.Function1d;   (* if f1d set then set f values , point get procedure on f1d *)
		(* if no f1d then point get procedure on interpolation *)
		Mapping-: ARRAY 1024 OF CHAR;
		set*: PROCEDURE ( f: Function;  at, val: FLOAT64 );
		get*: PROCEDURE ( f: Function;  at: FLOAT64 ): FLOAT64;
		editable-: BOOLEAN
	END;

	FunctionXd* = POINTER TO FunctionXdDesc;
	FunctionXdDesc* = RECORD (vyBase.ObjDesc)
		Mapping-: ARRAY 1024 OF CHAR;
		get*: PROCEDURE ( f: FunctionXd;  at: ARRAY OF FLOAT64 ): FLOAT64;
		fxd: antsOnTheFly.FunctionXd
	END;

	(**** Set & Get Management *****)

	(*
	PROCEDURE GetPosition( at: FLOAT64;  v: vyBase.tVector;  VAR pos: SIGNED32 ): BOOLEAN;
	VAR lx, mx, ux: FLOAT64;  lp, mp, up, len: SIGNED32;
	BEGIN
		len := vyLongrealVec.Len( v );
		IF len = 0 THEN pos := 0;  RETURN FALSE END;
		lp := 0;  up := len - 1;  lx := vyLongrealVec.Get( v, lp );  ux := vyLongrealVec.Get( v, up );
		IF at < lx THEN pos := 0;  RETURN FALSE
		ELSIF at > ux THEN pos := up;  RETURN FALSE
		ELSIF at = lx THEN pos := 0;  RETURN TRUE
		ELSIF at = ux THEN pos := up;  RETURN TRUE;
		END;
		WHILE (lp < up) DO
			mp := lp + (up - lp) DIV 2;  mx := vyLongrealVec.Get( v, mp );
			IF at < mx THEN ux := mx;  up := mp;
			ELSIF at > mx THEN lx := mx;  lp := mp;
			ELSIF at = mx THEN pos := mp;  RETURN TRUE
			END;
		END;
		pos := lp;  RETURN FALSE

	END GetPosition;
	*)

	PROCEDURE GetInterpolated( f: Function;  at: FLOAT64 ): FLOAT64;
	VAR len, lp, up, mp: SIGNED32;  lx, ux, mx: FLOAT64;
	BEGIN
		(*
		mind := MAX( FLOAT64 );
		FOR i := 0 TO vyLongrealVec.Len( f.x ) - 1 DO
			d := ABS( vyLongrealVec.Get( f.x, i ) - at );
			IF d < mind THEN mind := d;  min := i END
		END;
		RETURN vyLongrealVec.Get( f.val, min )
		*)
		len := vyLongrealVec.Len( f.x );
		IF len = 0 THEN RETURN 0 END;
		lp := 0;  up := len - 1;  lx := vyLongrealVec.Get( f.x, lp );  ux := vyLongrealVec.Get( f.x, up );

		IF at <= lx THEN lp := 0;
		ELSIF at >= ux THEN lp := up;
		ELSE
			mp := up;
			WHILE (lp < up - 1) DO
				mp := lp + (up - lp) DIV 2;  mx := vyLongrealVec.Get( f.x, mp );
				IF at < mx THEN ux := mx;  up := mp;
				ELSIF at > mx THEN lx := mx;  lp := mp;
				ELSE lp := mp;  up := mp;
				END;
			END;
		END;
		RETURN vyLongrealVec.Get( f.val, lp );

		(*
		len := vyLongrealVec.Len( f.x );
		IF len = 0 THEN RETURN 0
		ELSE
			lpos := 0;  upos := len - 1;  lx := vyLongrealVec.Get( f.x, lpos );  ux := vyLongrealVec.Get( f.x, upos );
			IF at > ux THEN lpos := upos;
			ELSIF at <= lx THEN upos := lpos;
			ELSE
				WHILE (lpos < upos) DO
					mpos := lpos + (upos - lpos) DIV 2;  mx := vyLongrealVec.Get( f.x, mpos );
					IF at < mx THEN ux := mx
					ELSIF at > mx THEN lx := mx
					ELSIF at = mx THEN lpos := mpos;  upos := mpos
					END;
				END;
			END;
			RETURN vyLongrealVec.Get( f.val, lpos );
		END;
		*)
	END GetInterpolated;

	PROCEDURE GetDefault( f: Function;  at: FLOAT64 ): FLOAT64;
	BEGIN
		RETURN 0
	END GetDefault;

	PROCEDURE GetDefaultXd( f: FunctionXd;  at: ARRAY OF FLOAT64 ): FLOAT64;
	BEGIN
		RETURN 0
	END GetDefaultXd;

	PROCEDURE SetValue( f: Function;  at, val: FLOAT64 );
	VAR i, len, pos: SIGNED32;  lp, mp, up: SIGNED32;  lx, ux, mx: FLOAT64;
	BEGIN
		len := vyLongrealVec.Len( f.x );
		IF len = 0 THEN vyLongrealVec.Append( val, f.val );  vyLongrealVec.Append( at, f.x );  RETURN END;
		lp := 0;  up := len - 1;  lx := vyLongrealVec.Get( f.x, lp );  ux := vyLongrealVec.Get( f.x, up );

		IF at < lx THEN pos := 0;
		ELSIF at > ux THEN vyLongrealVec.Append( val, f.val );  vyLongrealVec.Append( at, f.x );  RETURN
		ELSIF at = lx THEN vyLongrealVec.Set( val, f.val, 0 );  RETURN
		ELSIF at = ux THEN vyLongrealVec.Set( val, f.val, up );  RETURN
		END;
		WHILE (lp < up - 1) DO
			mp := lp + (up - lp) DIV 2;  mx := vyLongrealVec.Get( f.x, mp );
			IF at < mx THEN ux := mx;  up := mp;
			ELSIF at > mx THEN lx := mx;  lp := mp;
			ELSIF at = mx THEN vyLongrealVec.Set( val, f.val, mp );  RETURN
			END;
		END;

		IF ABS( at - lx ) > ABS( at - ux ) THEN lx := ux;  lp := up;
		END;

		vyLongrealVec.Append( vyLongrealVec.Get( f.x, len - 1 ), f.x );
		vyLongrealVec.Append( vyLongrealVec.Get( f.val, len - 1 ), f.val );
		FOR i := len - 1 TO lp + 1 BY -1 DO
			vyLongrealVec.Set( vyLongrealVec.Get( f.val, i - 1 ), f.val, i );
			vyLongrealVec.Set( vyLongrealVec.Get( f.x, i - 1 ), f.x, i );
		END;
		vyLongrealVec.Set( val, f.val, lp );  vyLongrealVec.Set( at, f.x, lp );

		(*
		pos := lp;  RETURN FALSE

		IF GetPosition( at, f.x, pos ) THEN
			aM.SI("GetPosition success: ",pos);
			vyLongrealVec.Set( val, f.val, pos );
		ELSE
			aM.SI("GetPosition, new: ",pos);
			len := vyLongrealVec.Len( f.x );

			IF len > 0 THEN
				vyLongrealVec.Append( vyLongrealVec.Get( f.x, len - 1 ), f.x );
				vyLongrealVec.Append( vyLongrealVec.Get( f.val, len - 1 ), f.val );
				FOR i := len-1 TO pos + 1 BY -1 DO
					vyLongrealVec.Set( vyLongrealVec.Get( f.val, i - 1 ), f.val, i );
					vyLongrealVec.Set( vyLongrealVec.Get( f.x, i - 1 ), f.x, i );
				END;
				vyLongrealVec.Set( val, f.val, pos );  vyLongrealVec.Set( at, f.x, pos );
			ELSE vyLongrealVec.Append( at, f.x );  vyLongrealVec.Append( val, f.val );
			END;
		END;
		*)
		(*
		len := vyLongrealVec.Len( f.x );
		IF len = 0 THEN vyLongrealVec.Append( val, f.val );  vyLongrealVec.Append( at, f.x );
		ELSE
			lpos := 0;  upos := len - 1;  lx := vyLongrealVec.Get( f.x, lpos );  ux := vyLongrealVec.Get( f.x, upos );
			IF at > ux THEN vyLongrealVec.Append( val, f.val );  vyLongrealVec.Append( at, f.x );  RETURN
			ELSIF at <= lx THEN lpos := 0;  upos := 0;
			ELSE
				WHILE (lpos < upos) DO
					mpos := lpos + (upos - lpos) DIV 2;  mx := vyLongrealVec.Get( f.x, mpos );
					IF at < mx THEN ux := mx;  upos := mpos;
					ELSIF at > mx THEN lx := mx;  lpos := mpos;
					ELSIF at = mx THEN lpos := mpos;  upos := mpos
					END;
				END;
			END;
			IF at = lx THEN vyLongrealVec.Set( val, f.val, lpos );
			ELSE
				vyLongrealVec.SetLen( f.val, len + 1 );  vyLongrealVec.SetLen( f.x, len + 1 );
				FOR i := len TO lpos + 1 BY -1 DO
					vyLongrealVec.Set( vyLongrealVec.Get( f.val, i - 1 ), f.val, i );
					vyLongrealVec.Set( vyLongrealVec.Get( f.x, i - 1 ), f.x, i );
				END;
			END;
			vyLongrealVec.Set( val, f.val, lpos );  vyLongrealVec.Set( at, f.x, lpos );

			(*

	FOR i := 0 TO vyLongrealVec.Len(f.x) - 1 DO
		IF vyLongrealVec.Get(f.x, i) = at THEN
			vyLongrealVec.Set(val, f.val, i);    RETURN
		END
	END;
	vyLongrealVec.Append(val, f.val);
	vyLongrealVec.Append(at, f.x);
	*)
		END;  *)
	END SetValue;

	PROCEDURE SetCreate( f: Function;  at, val: FLOAT64 );
	BEGIN
		f.x := vyLongrealVec.New( 0 );  f.val := vyLongrealVec.New( 0 );  f.set := SetValue;  f.set( f, at, val );
		f.get := GetInterpolated
	END SetCreate;

	PROCEDURE NoopSet( f: Function;  at, val: FLOAT64 );
	END NoopSet;

	PROCEDURE GetF1d( f: Function;  at: FLOAT64 ): FLOAT64;
	BEGIN
		RETURN f.f1d( at )
	END GetF1d;

	PROCEDURE GetFxd( f: FunctionXd;  at: ARRAY OF FLOAT64 ): FLOAT64;
	BEGIN
		RETURN f.fxd( at )
	END GetFxd;

	PROCEDURE Get1dOf( f: Function;  at: FLOAT64 ): FLOAT64;
	BEGIN
		RETURN f.f1d( f.of.get( f.of, at ) )
	END Get1dOf;

	PROCEDURE SetProcedures( f: Function );
	BEGIN
		IF f.f1d = NIL THEN
			f.editable := TRUE;  f.Mapping := "edit";
			IF f.x # NIL THEN f.get := GetInterpolated;  f.set := SetValue ELSE f.get := GetDefault;  f.set := SetCreate END
		ELSE
			f.editable := FALSE;
			IF f.of # NIL THEN f.get := Get1dOf;  f.set := NoopSet ELSE f.get := GetF1d;  f.set := NoopSet END
		END
	END SetProcedures;

	PROCEDURE GetCache*( f: Function;  from, to, by: FLOAT64;  VAR a: Array );
	VAR x: FLOAT64;  i: SIGNED32;
	BEGIN
		IF (a = NIL ) OR (LEN( a^ ) # ENTIER( (to - from) / by + 1.5 (*2*) )) THEN NEW( a, ENTIER( (to - from) / by + 1.5 (*2*) ) ) END;
		x := from;  i := 0;
		WHILE (i < LEN( a^ )) DO a[i] := f.get( f, x );  x := x + by;  INC( i ) END
	END GetCache;

	PROCEDURE SetCache*( f: Function;  from, to, by: FLOAT64;  a: Array );
	VAR x: FLOAT64;  i: SIGNED32;
	BEGIN
		f.set := SetCreate;   (* recreate the values, SetCache fills whole function values *)
		IF (a # NIL ) & (LEN( a^ ) >= ENTIER( (to - from) / by + 1.5 (*2 *) )) THEN
			x := from;  i := 0;
			WHILE (i < ENTIER( (to - from) / by + 1.5 (*2 *) )) DO f.set( f, x, a[i] );  x := x + by;  INC( i ) END
		END;
		vyBase.Update( f.x );  vyBase.Update( f.val )
	END SetCache;

	PROCEDURE StoreFXd( VAR R: Files.Rider;  s: FunctionXd );
	BEGIN
		Files.WriteInt( R, 0 );  Files.WriteString( R, s.Mapping )
	END StoreFXd;

	PROCEDURE LoadFXd( VAR R: Files.Rider;  s: FunctionXd );
	VAR version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadString( R, s.Mapping );
		IF antsOnTheFly.SetXd( "", s.Mapping ) THEN
			s.fxd := antsOnTheFly.fXd;  COPY( antsOnTheFly.fXdName, s.Mapping );  s.get := GetFxd
		END
	END LoadFXd;

	PROCEDURE StoreF( VAR R: Files.Rider;  s: Function );
	BEGIN
		Files.WriteInt( R, 0 );  Gadgets.WriteRef( R, s.lib, s.of );  Gadgets.WriteRef( R, s.lib, s.x );
		Gadgets.WriteRef( R, s.lib, s.val );  Files.WriteString( R, s.Mapping );  Files.WriteBool( R, s.editable )
	END StoreF;

	PROCEDURE LoadF( VAR R: Files.Rider;  s: Function );
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version );  Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.of := objsub( Function ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.x := objsub( vyBase.tVector ) END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.val := objsub( vyBase.tVector ) END;
		Files.ReadString( R, s.Mapping );  Files.ReadBool( R, s.editable );
		IF s.f1d = NIL THEN  (* maybe someone already set a procedure while reading links ?*)
			IF s.Mapping = "edit" THEN s.f1d := NIL;  SetProcedures( s );  vyBase.Update( s )
			ELSIF antsOnTheFly.Set1d( "", s.Mapping ) THEN
				s.f1d := antsOnTheFly.f1d;  COPY( antsOnTheFly.f1dName, s.Mapping );  SetProcedures( s )
			ELSE SetProcedures( s )
			END
		END;
	END LoadF;

	PROCEDURE Bind( o: Objects.Object;  VAR M: Objects.BindMsg );
	BEGIN
		IF (o # NIL ) & (M.lib # o.lib) THEN
			Gadgets.BindObj( o, M.lib );
			IF o.handle # NIL THEN o.handle( o, M ) END
		END
	END Bind;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: Function DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "Mapping" );  M.Enum( "editable" );  vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsFunctions.Gen', M.s );  M.class := Objects.String;  M.res := 0
						ELSIF M.name = "Mapping" THEN M.class := Objects.String;  COPY( o.Mapping, M.s );  M.res := 0
						ELSIF M.name = "editable" THEN M.class := Objects.Bool;  M.b := o.editable;  M.res := 0
						ELSE vyBase.objecthandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "Mapping" THEN
							IF M.class = Objects.String THEN
								IF M.s = "edit" THEN
									o.f1d := NIL;  SetProcedures( o );  vyBase.Update( o );  Gadgets.Update( o );  vyBase.Update( o );
									M.res := 0
								ELSIF antsOnTheFly.Set1d( "", M.s ) THEN
									o.f1d := antsOnTheFly.f1d;  COPY( antsOnTheFly.f1dName, o.Mapping );  SetProcedures( o );
									vyBase.Update( o );  M.res := 0
								END
							END
						ELSIF M.name = "editable" THEN
							IF o.editable = FALSE THEN
								o.f1d := NIL;  SetProcedures( o );  vyBase.Update( o );  Gadgets.Update( o );  vyBase.Update( o );
								M.res := 0
							END
						ELSE vyBase.objecthandle( o, M )
						END
					ELSE vyBase.objecthandle( o, M )
					END;
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF M.id = Objects.enum THEN M.Enum( "x" );  M.Enum( "y" );  M.Enum( "functionOf" );  vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "x" THEN M.obj := o.x;  M.res := 0
						ELSIF M.name = "y" THEN M.obj := o.val;  M.res := 0
						ELSIF M.name = "functionOf" THEN M.obj := o.of;  M.res := 0
						ELSE vyBase.objecthandle( o, M )
						END
					ELSE vyBase.objecthandle( o, M )
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  LoadF( M.R, o )
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  StoreF( M.R, o )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					IF o.lib # M.lib THEN Bind( o.val, M );  Bind( o.of, M );  Bind( o.x, M );  vyBase.objecthandle( o, M ) END;
				END;
			ELSIF M IS vyBase.UpdateMessage THEN
				WITH M: vyBase.UpdateMessage DO SetProcedures( o );  vyBase.Update( o )
				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END  (* tVector*)
	END Handler;

	PROCEDURE HandlerXd*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: FunctionXd DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "Mapping" );  vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsFunctions.GenXd', M.s );  M.class := Objects.String;  M.res := 0
						ELSIF M.name = "Mapping" THEN M.class := Objects.String;  COPY( o.Mapping, M.s );  M.res := 0
						ELSE vyBase.objecthandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "Mapping" THEN
							IF M.class = Objects.String THEN
								IF antsOnTheFly.SetXd( "", M.s ) THEN
									o.fxd := antsOnTheFly.fXd;  COPY( antsOnTheFly.fXdName, o.Mapping );  o.get := GetFxd;
									vyBase.Update( o );  M.res := 0
								END
							END
						ELSE vyBase.objecthandle( o, M )
						END
					ELSE vyBase.objecthandle( o, M )
					END;
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF M.id = Objects.enum THEN vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN vyBase.objecthandle( o, M )
					ELSE vyBase.objecthandle( o, M )
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  LoadFXd( M.R, o )
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  StoreFXd( M.R, o )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO vyBase.objecthandle( o, M );
				END;
			ELSIF M IS vyBase.UpdateMessage THEN
				WITH M: vyBase.UpdateMessage DO vyBase.Update( o )
				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END  (* tVector*)
	END HandlerXd;

	PROCEDURE Gen*;
	VAR m: Function;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := Handler;  Objects.NewObj := m;  SetProcedures( m );  antsObjects.Register( m )

	END Gen;

	PROCEDURE GenXd*;
	VAR m: FunctionXd;
	BEGIN
		aM.cmd;  NEW( m );  m.handle := HandlerXd;  Objects.NewObj := m;  m.get := GetDefaultXd;  antsObjects.Register( m )
	END GenXd;


(*
PROCEDURE Define*;
VAR l: antsCommands.tScanList;    name: vyName.tNameArray;     f: Function;
BEGIN
l := antsCommands.ScanFromPar("name=NAME");
IF antsCommands.ExpectNameFromKeyword(l, "name",  name) THEN
Gen;    f := Objects.NewObj(Function);
vyName.RegisterNamed(f, name);
aM.vSS("antsFunctions: defined ", name);
END
END Define;

PROCEDURE DefineXd*;
VAR l: antsCommands.tScanList;    name: vyName.tNameArray;     f: FunctionXd;
BEGIN
l := antsCommands.ScanFromPar("name=NAME");
IF antsCommands.ExpectNameFromKeyword(l, "name",  name) THEN
GenXd;    f := Objects.NewObj(FunctionXd);
vyName.RegisterNamed(f, name);
aM.vSS("antsFunctions: defined ", name);
END

END DefineXd;


PROCEDURE IsFunctionOf*;
VAR l: antsCommands.tScanList;     f: Function;    obj1, obj2: vyBase.Object;    trafo: Function;
BEGIN
l := antsCommands.ScanFromPar("name=OBJ from=OBJ");
IF antsCommands.ExpectObjectFromKeyword(l, "name", obj1) & antsCommands.ExpectObjectFromKeyword(l, "from",  obj2) THEN
f := obj1(Function);
trafo := obj2(Function);
f.of := trafo;
vyBase.Subscribe(f.of, f);
SetProcedures(f);
aM.vS("antsFunctions: ok.");
END
END IsFunctionOf;
*)

	PROCEDURE Define*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  f: Function;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN DoDefine( name, f ) END
	END Define;

	PROCEDURE DoDefine*( name: vyName.tNameArray;  VAR f: Function );
	BEGIN
		Gen;  f := Objects.NewObj( Function );  vyName.RegisterNamed( f, name )
	END DoDefine;

	PROCEDURE DefineXd*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  f: FunctionXd;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN DoDefineXd( name ) END
	END DefineXd;

	PROCEDURE DoDefineXd*( name: vyName.tNameArray );
	VAR f: FunctionXd;
	BEGIN
		GenXd;  f := Objects.NewObj( FunctionXd );  vyName.RegisterNamed( f, name )
	END DoDefineXd;

	PROCEDURE IsFunctionOf*;
	VAR l: antsCommands.tScanList;  f: Function;  obj1, obj2: vyBase.Object;  trafo: Function;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ from=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj1 ) & antsCommands.ExpectObjectFromKeyword( l, "from", obj2 ) THEN
			DoIsFunctionOf( obj1, obj2 )
		END
	END IsFunctionOf;

	PROCEDURE DoIsFunctionOf*( obj1, obj2: vyBase.Object );
	VAR f: Function;  trafo: Function;
	BEGIN
		f := obj1( Function );  trafo := obj2( Function );  f.of := trafo;  vyBase.Subscribe( f.of, f );  SetProcedures( f )
	END DoIsFunctionOf;

(*
PROCEDURE Set*;
VAR l: antsCommands.tScanList;    f: Function;    obj: vyBase.Object;    const, function: ARRAY 1024 OF CHAR;
BEGIN
l := antsCommands.ScanFromPar("name=OBJ [const=STR] function=STR");
IF
antsCommands.ExpectObjectFromKeyword(l, "name",  obj) THEN
f := obj(Function);
IF antsCommands.FindKeyword(l, "const") THEN
IF antsCommands.ExpectStringFromKeyword(l, "const",  const) THEN END
ELSE const := ""END;
IF antsCommands.ExpectStringFromKeyword(l, "function",  function) THEN
vyHostTexts.NoteSS(vyHostTexts.cNotify, "Compiling ", function);
vyHostTexts.NoteSS(vyHostTexts.cNotify, "with constants:", const);
IF antsOnTheFly.Set1d(const, function) THEN
f.f1d := antsOnTheFly.f1d;
COPY(antsOnTheFly.f1dName, f.Mapping);
SetProcedures(f);
vyBase.Update(f);
aM.vSS("antsFunctions.Set ok: ",function);
ELSE
aM.eSS("antsFunctions.Set failed: ",function);
END
END
END
END Set;

PROCEDURE SetXd*;
VAR l: antsCommands.tScanList;    f: FunctionXd;    obj: vyBase.Object;    const, function: ARRAY 1024 OF CHAR;
BEGIN
l := antsCommands.ScanFromPar("name=OBJ [const=STR] function=STR");
IF 	antsCommands.ExpectObjectFromKeyword(l, "name",  obj) THEN
f := obj(FunctionXd);
IF antsCommands.FindKeyword(l, "const") THEN
IF antsCommands.ExpectStringFromKeyword(l, "const",  const) THEN END
ELSE const := ""END;
IF antsCommands.ExpectStringFromKeyword(l, "function",  function) THEN
vyHostTexts.NoteSS(vyHostTexts.cNotify, "Compiling ", function);
vyHostTexts.NoteSS(vyHostTexts.cNotify, "with constants:", const);
IF antsOnTheFly.SetXd(const, function) THEN
f.fxd := antsOnTheFly.fXd;
f.get := GetFxd;
COPY(antsOnTheFly.fXdName, f.Mapping);
vyBase.Update(f);
aM.vSS("antsFunctions.SetXd ok: ",function);
ELSE
aM.eSS("antsFunctions.SetXd failed: ",function);
END
END
END
END SetXd;

*)

	PROCEDURE SetF1d*( f: Function;  map: antsOnTheFly.Function1d );
	BEGIN
		f.f1d := map;  SetProcedures( f );
	END SetF1d;

	PROCEDURE Set*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;
		const, function: ARRAY 1024 OF CHAR;
		f: Function;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ [const=STR] function=STR" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			f := obj( Function );
			IF antsCommands.FindKeyword( l, "const" ) THEN
				IF antsCommands.ExpectStringFromKeyword( l, "const", const ) THEN END
			ELSE const := ""
			END;
			IF antsCommands.ExpectStringFromKeyword( l, "function", function ) THEN DoSet( const, function, f ) END
		END
	END Set;

	PROCEDURE DoSet*( const: ARRAY OF CHAR;  VAR function: ARRAY OF CHAR;  VAR f: Function );

	BEGIN
		vyHostTexts.NoteSS( vyHostTexts.cNotify, "Compiling ", function );  vyHostTexts.NoteSS( vyHostTexts.cNotify, "with constants:", const );
		IF antsOnTheFly.Set1d( const, function ) THEN
			f.f1d := antsOnTheFly.f1d;  COPY( antsOnTheFly.f1dName, f.Mapping );  SetProcedures( f );  vyBase.Update( f )
		END
	END DoSet;

	PROCEDURE SetXd*;
	VAR l: antsCommands.tScanList;  f: FunctionXd;  obj: vyBase.Object;
		const, function: ARRAY 1024 OF CHAR;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ [const=STR] function=STR" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			f := obj( FunctionXd );
			IF antsCommands.FindKeyword( l, "const" ) THEN
				IF antsCommands.ExpectStringFromKeyword( l, "const", const ) THEN END
			ELSE const := ""
			END;
			IF antsCommands.ExpectStringFromKeyword( l, "function", function ) THEN DoSetXd( obj, const, function ) END
		END
	END SetXd;

	PROCEDURE DoSetXd*( obj: vyBase.Object;  const, function: ARRAY OF CHAR );
	VAR f: FunctionXd;
	BEGIN
		vyHostTexts.NoteSS( vyHostTexts.cNotify, "Compiling ", function );  vyHostTexts.NoteSS( vyHostTexts.cNotify, "with constants:", const );
		f := obj( FunctionXd );
		IF antsOnTheFly.SetXd( const, function ) THEN
			f.fxd := antsOnTheFly.fXd;  f.get := GetFxd;  COPY( antsOnTheFly.fXdName, f.Mapping );  vyBase.Update( f )
		END
	END DoSetXd;

	PROCEDURE CompileText*;
	VAR obj: Objects.Object;  obj1: Objects.Object;  pos: SIGNED32;  t: Texts.Text;
		function: ARRAY 1024 OF CHAR;
		r: Texts.Reader;  l: antsCommands.tScanList;  f: FunctionXd;  bobj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", bobj ) THEN DoCompileText( bobj ) END;
		antsOnTheFly.debug := FALSE
	END CompileText;

	PROCEDURE DoCompileText*( VAR bobj: vyBase.Object );
	VAR obj: Objects.Object;  obj1: Objects.Object;  pos: SIGNED32;  t: Texts.Text;
		function: ARRAY 1024 OF CHAR;
		r: Texts.Reader;  l: antsCommands.tScanList;  f: FunctionXd;
	BEGIN
		f := bobj( FunctionXd );  antsOnTheFly.debug := TRUE;  obj := Gadgets.FindObj( Gadgets.context, "CompileText" );
		IF obj # NIL THEN
			Links.GetLink( obj, "Model", obj1 );
			IF (obj1 # NIL ) & (obj1 IS Texts.Text) THEN
				t := obj1( Texts.Text );  Texts.OpenReader( r, t, 0 );  pos := 0;
				WHILE (~r.eot) & (pos < 1024) DO Texts.Read( r, function[pos] );  INC( pos ) END;
				function[pos] := 0X;  aM.S( "Compiling" );
				IF antsOnTheFly.SetXd( "", function ) THEN
					f.fxd := antsOnTheFly.fXd;  f.get := GetFxd;  COPY( antsOnTheFly.fXdName, f.Mapping );  vyBase.Update( f )
				END
			END
		END;
		antsOnTheFly.debug := FALSE
	END DoCompileText;


(*

PROCEDURE CompileText*;
VAR obj: Objects.Object; obj1: Objects.Object; pos: SIGNED32; t: Texts.Text;
function: ARRAY 1024 OF CHAR; r: Texts.Reader; l: antsCommands.tScanList;    f: FunctionXd; bobj: vyBase.Object;
BEGIN
l := antsCommands.ScanFromPar("name=OBJ; # 'CompileText' expected in context");
IF 	antsCommands.ExpectObjectFromKeyword(l, "name",  bobj) THEN
f := bobj(FunctionXd);

antsOnTheFly.debug := TRUE;
obj := Gadgets.FindObj(Gadgets.context, "CompileText");
IF obj # NIL THEN
Links.GetLink(obj, "Model", obj1);
IF (obj1 # NIL) & (obj1 IS Texts.Text) THEN
t := obj1(Texts.Text);
Texts.OpenReader(r, t, 0);
pos := 0;
WHILE(~r.eot) & (pos < 1024) DO
Texts.Read(r, function[pos]); INC(pos)
END;
function[pos] := 0X;
aM.S("Compiling");
IF antsOnTheFly.SetXd("", function) THEN
f.fxd := antsOnTheFly.fXd;
f.get := GetFxd;
COPY(antsOnTheFly.fXdName, f.Mapping);
vyBase.Update(f)
END
ELSE
aM.usage("antsFunctions.CompileText","name=OBJ ; 'CompileText' expected in context");
END
ELSE
aM.usage("antsFunctions.CompileText","name=OBJ ; 'CompileText' expected in context");

END
END;
antsOnTheFly.debug := FALSE
END CompileText;

*)
	PROCEDURE CompileText2*;
	VAR obj: Objects.Object;  obj1: Objects.Object;  pos: SIGNED32;  t: Texts.Text;
		function: ARRAY 1024 OF CHAR;
		r: Texts.Reader;  l: antsCommands.tScanList;  f: FunctionXd;  bobj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ; # 'CompileText' expected in context" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", bobj ) THEN f := bobj( FunctionXd );

			antsOnTheFly.debug := TRUE;  obj := Gadgets.FindObj( Gadgets.context, "CompileText" );
			IF obj # NIL THEN
				Links.GetLink( obj, "Model", obj1 );
				IF (obj1 # NIL ) & (obj1 IS Texts.Text) THEN
					t := obj1( Texts.Text );

					(*
				Texts.OpenReader(r, t, 0);
				pos := 0;
				WHILE(~r.eot) & (pos < 1024) DO
				Texts.Read(r, function[pos]); INC(pos)
				END;
				function[pos] := 0X;
				*)
					aM.S( "Compiling" );
					IF antsOnTheFly.CompileText( t, "antsGenericModelMod.Text", "SetFunctionXd", "(*startreplace", "endreplace*)" ) THEN
						(*
					IF antsOnTheFly.SetXd("", function) THEN
					*)
						f.fxd := antsOnTheFly.fXd;  f.get := GetFxd;
						(*
					COPY(antsOnTheFly.fXdName, f.Mapping);
					*)
						vyBase.Update( f )
					END
				ELSE aM.usage( "antsFunctions.CompileText", "name=OBJ ; 'CompileText' expected in context" )
				END
			ELSE aM.usage( "antsFunctions.CompileText", "name=OBJ ; 'CompileText' expected in context" )

			END
		END;
		antsOnTheFly.debug := FALSE
	END CompileText2;

BEGIN
	aM.launch;
END antsFunctions.

antsFunctions.DefineXd interactionFunction ~
System.Free antsFunctions ~

