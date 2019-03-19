MODULE ants1dArrayVectors IN Oberon;   (* fof *)
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



(* when applying changes to this module think of do similar changes to module antsArrayImages ! *)


IMPORT vyBase, Objects, antsObjects, Files, Gadgets, antsCommands, vyName, aM := antsMessages, ants1dArrayObjects,
	vyLinks, vyLongrealVec, vyHostStrings;

TYPE

	tObject* = POINTER TO tObjectDesc;
	tObjectDesc* = RECORD (vyBase.ObjDesc)
		synced-: BOOLEAN;
		vec-: vyLongrealVec.tVector;
		w-, depth-: antsObjects.Index;   (* cache *)
		A-: ants1dArrayObjects.tObject;
		trans*: antsObjects.PAConsistTrafoProc
	END;

	PROCEDURE HandleAttributes( o: tObject;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN
			M.Enum( "Gen" );  M.Enum( "w" );  M.Enum( "depth" );  M.Enum( "synced" );  M.Enum( "ARRAY" );  vyBase.objecthandle( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'ants1dArrayVectors.Gen', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "w" THEN M.class := Objects.Int;  M.i := o.w;  M.res := 0
			ELSIF M.name = "depth" THEN M.class := Objects.Int;  M.i := o.depth;  M.res := 0
			ELSIF M.name = "synced" THEN M.class := Objects.Bool;  M.b := o.synced;  M.res := 0
			ELSIF M.name = "ARRAY" THEN
				M.class := Objects.String;
				IF o.A = NIL THEN M.s := "NIL" ELSE M.s := "EXISTS" END;
				M.res := 0
			ELSE vyBase.objecthandle( o, M )
			END
		ELSIF M.id = Objects.set THEN vyBase.objecthandle( o, M )
		ELSE vyBase.objecthandle( o, M )
		END
	END HandleAttributes;

	PROCEDURE FrameLinks( F: tObject;  VAR M: Objects.LinkMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "vect" );  vyBase.objecthandle( F, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "vect" THEN M.obj := F.vec;  M.res := 0 ELSE vyBase.objecthandle( F, M ) END
		ELSE vyBase.objecthandle( F, M )
		END
	END FrameLinks;

	PROCEDURE HandleFileMsg( obj: tObject;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  w, depth: LONGINT;  version: INTEGER;
		(*! store Picts as GIF for color preserving or store colors *)
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Files.ReadLInt( msg.R, w );
			Files.ReadLInt( msg.R, depth );  obj.w := w;  obj.depth := depth;  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS vyLongrealVec.tVector) THEN obj.vec := objsub( vyLongrealVec.tVector ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS ants1dArrayObjects.tObject) THEN obj.A := objsub( ants1dArrayObjects.tObject ) END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  Files.WriteLInt( msg.R, obj.w );
			Files.WriteLInt( msg.R, obj.depth );  Gadgets.WriteRef( msg.R, obj.lib, obj.vec );
			Gadgets.WriteRef( msg.R, obj.lib, obj.A )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE CheckDimensions( obj: tObject );
	BEGIN
		IF (obj.w # obj.A.w) THEN obj.w := obj.A.w;  vyLongrealVec.SetLen( obj.vec, obj.w ) END;
		IF (obj.depth # obj.A.depth) THEN
			obj.depth := obj.A.depth
			(* do nothing, will be done by viewers *)
		END
	END CheckDimensions;

	PROCEDURE Sync*( obj: tObject );
	VAR A: ants1dArrayObjects.tArray;  i: LONGINT;
	BEGIN
		IF obj.A # NIL THEN
			CheckDimensions( obj );  A := obj.A.A;
			(* get picture contents *)
			IF obj.trans = NIL THEN
				FOR i := 0 TO obj.w - 1 DO vyLongrealVec.Set( A[i], obj.vec, i ) END;
				obj.synced := TRUE;  vyBase.Update( obj.vec )
			ELSE
				HALT( 99 ) (* not yet implemented *)
			END
		END
	END Sync;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR
	BEGIN
		WITH obj: tObject DO
			IF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO
					obj.synced := FALSE;  obj.depth := obj.A.depth;  Sync( obj );
					vyBase.Update( obj );   (* double update ???, no, ok.*)
					(* vyBase.ForUsersHandle(obj, msg);*)
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF ~obj.synced THEN Sync( obj ) END;
					HandleFileMsg( obj, msg )
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO
					IF ~obj.synced THEN Sync( obj ) END;
					FrameLinks( obj, msg )
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF ~obj.synced THEN Sync( obj ) END;
					IF obj.lib # msg.lib THEN
						antsObjects.Bind( obj.A, msg );  antsObjects.Bind( obj.vec, msg );  vyBase.objecthandle( obj, msg )
					END
				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Gen*;
	VAR obj: tObject;
	BEGIN
		aM.dS( "ants1dArrayVectors.Gen" );  NEW( obj );  obj.vec := NIL;  obj.A := NIL;  obj.w := 0;  obj.depth := 0;  obj.handle := Handler;  obj.trans := NIL;
		obj.synced := FALSE;  Objects.NewObj := obj
	END Gen;

	PROCEDURE FromArray*( obj: tObject;  A: ants1dArrayObjects.tObject );
	BEGIN
		obj.A := A;  obj.w := A.w;  obj.depth := A.depth;

		obj.vec := vyLongrealVec.New( obj.w );  vyBase.Subscribe( obj.A, obj );  vyBase.Subscribe( obj, obj.vec );  Sync( obj )
	END FromArray;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  from: vyBase.Object;  obj: tObject;  link: vyLinks.Link;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME from=OBJ [>show] ~# Create a (synced) Voyager vector from ants1dArrayObjects.Object " );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "from", from ) THEN
			WITH from: ants1dArrayObjects.tObject DO
				Gen;  obj := Objects.NewObj( tObject );  FromArray( obj, from );  vyName.RegisterNamed( obj, name );
				antsObjects.Register( obj );  vyHostStrings.Append( name, "Vec" );  vyName.RegisterNamed( obj.vec, name );
				antsObjects.Register( obj.vec );
				IF antsCommands.FindKeyword( l, "show" ) THEN link := NIL;  vyLinks.InsertObj( link, obj.vec );  vyBase.Show( link, 1, "antsPointPlot" ) END
			END
		END
	END New;

BEGIN
	aM.launch;
END ants1dArrayVectors.

System.Free antsPictureViews antsArrayPictures ~

ants1dArrayObjects.New array 100 10 ~
ants1dArrayVectors.New test array ~
Voyager.Show testVec as antsPointPlot ~

