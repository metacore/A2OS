MODULE antsFctVector IN Oberon;
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

IMPORT vyBase, Objects, antsObjects, Files, Gadgets, antsCommands, vyName, antsFunctions, vyLongrealVec, vyRealVec, aM := antsMessages;

TYPE
	Object* = POINTER TO ObjectDesc;
	ObjectDesc* = RECORD (vyBase.ObjDesc)
		x-: vyBase.tVector;
		from-, to-: LONGREAL;
		f-: antsFunctions.Function
	END;

	PROCEDURE HandleAttributes( o: Object;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  vyBase.objecthandle( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsFctVector.Gen', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyBase.objecthandle( o, M ) END
		ELSIF M.id = Objects.set THEN vyBase.objecthandle( o, M )
		ELSE vyBase.objecthandle( o, M )
		END
	END HandleAttributes;

	PROCEDURE FrameLinks( F: Object;  VAR M: Objects.LinkMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "x" );  M.Enum( "f" );  vyBase.objecthandle( F, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "x" THEN M.obj := F.x;  M.res := 0
			ELSIF M.name = "f" THEN M.obj := F.f;  M.res := 0
			ELSE vyBase.objecthandle( F, M )
			END
		ELSE vyBase.objecthandle( F, M )
		END
	END FrameLinks;

	PROCEDURE HandleFileMsg( obj: Object;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: INTEGER;
		(*! store Picts as GIF for color preserving or store colors *)
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Files.ReadLReal( msg.R, obj.from );
			Files.ReadLReal( msg.R, obj.to );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.x := objsub( vyLongrealVec.tVector ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.f := objsub( antsFunctions.Function ) END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  Files.WriteLReal( msg.R, obj.from );
			Files.WriteLReal( msg.R, obj.to );  Gadgets.WriteRef( msg.R, obj.lib, obj.x );  Gadgets.WriteRef( msg.R, obj.lib, obj.f )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE Sync*( obj: Object );
	VAR i: LONGINT;  get, at: LONGREAL;
	BEGIN
		IF obj.f # NIL THEN
			FOR i := 0 TO obj.x.nrData - 1 DO
				at := obj.from + (obj.to - obj.from) * i / obj.x.nrData;  get := obj.f.get( obj.f, at );  vyLongrealVec.Set( get, obj.x, i )
			END;
			vyBase.Update( obj.x )
		END
	END Sync;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		WITH obj: Object DO
			IF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO Sync( obj );  vyBase.Update( obj );
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO HandleFileMsg( obj, msg )
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO FrameLinks( obj, msg )
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF obj.lib # msg.lib THEN
						vyBase.objecthandle( obj, msg );  antsObjects.Bind( obj.x, msg );  antsObjects.Bind( obj.f, msg )
					END
				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Gen*;
	VAR obj: Object;
	BEGIN
		aM.cmd;  NEW( obj );  obj.handle := Handler;  obj.x := NIL;  obj.f := NIL;  Objects.NewObj := obj
	END Gen;

(*
PROCEDURE New*;
VAR l: antsCommands.tScanList;    name: vyName.tNameArray;    fct, vect:  vyBase.Object;   obj: Object; 	from, to: LONGREAL;
BEGIN
l := antsCommands.ScanFromPar("name = NAME fct = OBJ  vect= OBJ [from=REAL to=REAL]");
IF antsCommands.ExpectNameFromKeyword(l, "name",  name) &
antsCommands.ExpectObjectFromKeyword(l, "fct",  fct) &
antsCommands.ExpectObjectFromKeyword(l, "vect", vect)
THEN
WITH fct: antsFunctions.Function DO
Gen;   obj := Objects.NewObj(Object);
vyName.RegisterNamed(obj, name);    antsObjects.Register(obj);
obj.x := vect(vyLongrealVec.tVector);
obj.f := fct;
obj.from := 0;
obj.to := 1;
IF antsCommands.GetRealFromKeyword(l, "from", from) &
antsCommands.GetRealFromKeyword(l, "from", to)  THEN
obj.from := from;
obj.to := to
END;
vyBase.Subscribe(obj.f, obj);
vyBase.Subscribe(obj, obj.x);
Sync(obj)
END
END
END New;

PROCEDURE NewVec*;
VAR l: antsCommands.tScanList;   vec: vyLongrealVec.tVector;   len: LONGINT;   name: vyName.tNameArray ;   from: vyBase.Object;
val: LONGREAL;    i: LONGINT;
BEGIN
l := antsCommands.ScanFromPar("name=NAME ( len=INT| from=OBJ )");
IF antsCommands.ExpectNameFromKeyword(l, "name",  name) THEN
IF antsCommands.GetNumberFromKeyword(l, "len",  len) THEN
vec := vyLongrealVec.New(len);
vyLongrealVec.Fill(vec, 0, 0, len);
IF len > 0 THEN
vyLongrealVec.Set(1, vec, len - 1)  (* just for coordinate systems of plots *)
END
ELSIF  antsCommands.ExpectObjectFromKeyword(l, "from", from) THEN
WITH from: vyLongrealVec.tVector DO
vec := vyLongrealVec.New(vyLongrealVec.Len(from));
vyLongrealVec.CopyData(from, vec);
| from: vyRealVec.tVector DO
vec := vyLongrealVec.New(vyLongrealVec.Len(from));
FOR i := 0 TO vyLongrealVec.Len(from) - 1 DO
val := vyRealVec.Get(from, i);
vyLongrealVec.Set(val, vec, i)
END
END
ELSE
vec := vyLongrealVec.New(0);
END;
vyName.RegisterNamed(vec, name);
aM.vSS("antsFctVector.NewVec, ok:",name);
END
END NewVec;
*)
	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  fct, vect: vyBase.Object;  obj: Object;  from, to: LONGREAL;
	BEGIN
		l := antsCommands.ScanFromPar( "name = NAME fct = OBJ  vect= OBJ[from=REAL to=REAL]" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "fct", fct ) &
		    antsCommands.ExpectObjectFromKeyword( l, "vect", vect ) THEN
			WITH fct: antsFunctions.Function DO
				Gen;  obj := Objects.NewObj( Object );  vyName.RegisterNamed( obj, name );  antsObjects.Register( obj );
				obj.x := vect( vyLongrealVec.tVector );  obj.f := fct;  obj.from := 0;  obj.to := 1;
				IF antsCommands.GetRealFromKeyword( l, "from", from ) & antsCommands.GetRealFromKeyword( l, "to", to ) THEN
					obj.from := from;  obj.to := to
				END;
				vyBase.Subscribe( obj.f, obj );  vyBase.Subscribe( obj, obj.x );  Sync( obj )
			END
		END
	END New;

(*
PROCEDURE New*;
VAR l: antsCommands.tScanList;
	name: vyName.tNameArray;
	fct, vect:  vyBase.Object;
	from, to: LONGREAL;
BEGIN
	l := antsCommands.ScanFromPar("name = NAME fct = OBJ  vect= OBJ [from=REAL to=REAL]");
	IF antsCommands.ExpectNameFromKeyword(l, "name",  name) &
		antsCommands.ExpectObjectFromKeyword(l, "fct",  fct) &
		antsCommands.ExpectObjectFromKeyword(l, "vect", vect) THEN
		IF antsCommands.GetRealFromKeyword(l, "from", from) &
			antsCommands.GetRealFromKeyword(l, "to", to)  THEN
		END;

		WITH fct: antsFunctions.Function DO
			DoNew(name, fct, vect(vyLongrealVec.tVector), from, to)
		END
	END
END New;
*)

	PROCEDURE DoNew*( name: vyName.tNameArray;  fct: antsFunctions.Function;  vect: vyLongrealVec.tVector;  from, to: LONGREAL );
	VAR obj: Object;
	BEGIN
		Gen;  obj := Objects.NewObj( Object );  vyName.RegisterNamed( obj, name );  antsObjects.Register( obj );
		obj.x := vect;  obj.f := fct;  obj.from := 0;  obj.to := 1;
		IF (from # 0) THEN obj.from := from
		ELSIF (to # 0) THEN obj.to := to
		END;
		vyBase.Subscribe( obj.f, obj );  vyBase.Subscribe( obj, obj.x );  Sync( obj )
	END DoNew;

	PROCEDURE DoSetObject*( VAR obj: Object;  fct: antsFunctions.Function;  vect: vyLongrealVec.tVector;  from, to: LONGREAL );
	BEGIN
		obj.x := vect;  obj.f := fct;  obj.from := 0;  obj.to := 1;

		IF (from # 0) THEN obj.from := from
		END;
		IF (to # 0) THEN obj.to := to END;

		vyBase.Subscribe( obj.f, obj );  vyBase.Subscribe( obj, obj.x );  Sync( obj )
	END DoSetObject;

	PROCEDURE NewVec*;
	VAR l: antsCommands.tScanList;  vec: vyLongrealVec.tVector;  len: LONGINT;  name: vyName.tNameArray;  from: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME ( len=INT| from=OBJ )" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			IF antsCommands.GetNumberFromKeyword( l, "len", len ) THEN DoNewVec1( len, vec )
			ELSIF antsCommands.ExpectObjectFromKeyword( l, "from", from ) THEN DoNewVec2( from, vec )
			END;
			vyName.RegisterNamed( vec, name )
		END
	END NewVec;

	PROCEDURE DoNewVec1*( len: LONGINT;  VAR vec: vyLongrealVec.tVector );
	BEGIN
		vec := vyLongrealVec.New( len );  vyLongrealVec.Fill( vec, 0, 0, len );
		IF len > 0 THEN
			vyLongrealVec.Set( 1, vec, len - 1 ) (* just for coordinate systems of plots *)
		END
	END DoNewVec1;

	PROCEDURE DoNewVec2*( from: vyBase.Object;  VAR vec: vyLongrealVec.tVector );
	VAR i: LONGINT;  val: LONGREAL;
	BEGIN
		IF from IS vyLongrealVec.tVector THEN
			WITH from: vyLongrealVec.tVector DO
				vec := vyLongrealVec.New( vyLongrealVec.Len( from ) );  vyLongrealVec.CopyData( from, vec );
			END;
		ELSIF from IS vyRealVec.tVector THEN
			WITH from: vyRealVec.tVector DO
				vec := vyLongrealVec.New( vyLongrealVec.Len( from ) );
				FOR i := 0 TO vyLongrealVec.Len( from ) - 1 DO val := vyRealVec.Get( from, i );  vyLongrealVec.Set( val, vec, i ) END
			END;
		END;
		IF vec = NIL THEN vec := vyLongrealVec.New( 0 ) END
	END DoNewVec2;

	PROCEDURE ClearVec*;
	VAR v: vyBase.Object;
	BEGIN
		antsCommands.InitScan( "vec=OBJ" );
		IF antsCommands.ExpectObject( "vec", v ) THEN
			WITH v: vyLongrealVec.tVector DO vyLongrealVec.SetLen( v, 0 );  vyBase.Update( v )
			END
		END
	END ClearVec;

BEGIN
	aM.launch;
END antsFctVector.
System.Free antsFctVector ~

fofAutomatic.Do
antsFctVector.NewVec data 256~
antsFunctions.Define myfunction ~
antsFunctions.Set myfunction "IF x>0.5 THEN y := 1 ELSE y := sin(x*2*pi) END"
Voyager.Show myfunction as antsFctEdit ~
antsFctVector.New connect myfunction data ~
Voyager.Show data as antsPointPlot ~
antsObjects.WriteAttributes myfunction
~
Voyager.Show data as antsObjectView ~
ants / antsFunctions.Mod
