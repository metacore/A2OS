MODULE antsMeanArray IN Oberon;   (** fof  **)
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




IMPORT vyBase, antsObjects, Objects, antsCommands, vyName, antsArrayObjects, Files, aM := antsMessages;

TYPE
	tMeanArray = POINTER TO ARRAY OF ARRAY OF LONGREAL;
	tArray* = antsArrayObjects.tINTEGERArray;

	tMean* = POINTER TO tMeanDesc;
	tMeanDesc = RECORD (vyBase.ObjDesc)
		A: tMeanArray;
		count: LONGINT
	END;

	PROCEDURE Add*( A: tArray;  to: tMean );
	VAR y, x: LONGINT;
	BEGIN
		IF to.A = NIL THEN
			NEW( to.A, LEN( A^ ), LEN( A[0] ) );
			FOR y := 0 TO LEN( A^ ) - 1 DO
				FOR x := 0 TO LEN( A[0] ) - 1 DO to.A[y, x] := A[y, x] END
			END
		ELSE
			FOR y := 0 TO LEN( A^ ) - 1 DO
				FOR x := 0 TO LEN( A[0] ) - 1 DO to.A[y, x] := to.A[y, x] + A[y, x] END
			END
		END;
		INC( to.count )
	END Add;

	PROCEDURE Get*( from: tMean;  to: tArray;  depth: LONGINT );
	VAR y, x: LONGINT;
	BEGIN
		FOR y := 0 TO LEN( to^ ) - 1 DO
			FOR x := 0 TO LEN( to[0] ) - 1 DO to[y, x] := SHORT( ENTIER( (from.A[y, x] * (depth - 1)) / from.count + 0.5 ) ) END
		END
	END Get;

	PROCEDURE Update*( from: tMean;  to: antsArrayObjects.tINTEGERObject );
	BEGIN
		IF from.A # NIL THEN Get( from, to.A, to.depth ) END;
		antsArrayObjects.Refresh( to )
	END Update;

	PROCEDURE DoInit*( m: tMean );
	BEGIN
		m.A := NIL;  m.count := 0
	END DoInit;

	PROCEDURE HandleAttributes( o: tMean;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "count" );  vyBase.objecthandle( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsMeanArray.Gen', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "count" THEN M.i := o.count;  M.class := Objects.Int;  M.res := 0
			ELSE vyBase.objecthandle( o, M )
			END
		ELSIF M.id = Objects.set THEN vyBase.objecthandle( o, M )
		ELSE vyBase.objecthandle( o, M )
		END
	END HandleAttributes;

	PROCEDURE FrameLinks( F: tMean;  VAR M: Objects.LinkMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "picture" );  vyBase.objecthandle( F, M )
		ELSIF M.id = Objects.get THEN vyBase.objecthandle( F, M )
		ELSE vyBase.objecthandle( F, M )
		END
	END FrameLinks;

	PROCEDURE HandleFileMsg( obj: tMean;  VAR msg: Objects.FileMsg );
	VAR version: INTEGER;
		(*! store Picts as GIF for color preserving or store colors *)
	BEGIN
		IF msg.id = Objects.load THEN Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg )
		ELSIF msg.id = Objects.store THEN Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE GetDestArray( o: tMean;  VAR array: antsArrayObjects.tINTEGERObject );
	VAR link: Objects.Object;
	BEGIN
		link := antsObjects.GetLink( o, "dest" );  array := link( antsArrayObjects.tINTEGERObject )
	END GetDestArray;

	PROCEDURE GetSrcArray( o: tMean;  VAR array: antsArrayObjects.tINTEGERObject );
	VAR link: Objects.Object;
	BEGIN
		link := antsObjects.GetLink( o, "source" );  array := link( antsArrayObjects.tINTEGERObject )
	END GetSrcArray;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR array: antsArrayObjects.tINTEGERObject;
	BEGIN
		WITH obj: tMean DO
			IF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO
					GetSrcArray( obj, array );
					IF array # NIL THEN Add( array.A, obj ) END;
					GetDestArray( obj, array );
					IF array # NIL THEN Update( obj, array ) END;
					(*
			| msg: antsGibbs.NewSampleMsg DO
			GetSrcArray(obj,array);
			IF array # NIL THEN Add(array.A, obj) END;
			| msg: antsGibbs.InitSampleMsg DO
			DoInit(obj);
			GetSrcArray(obj,array);
			IF array # NIL THEN Add(array.A, obj) END; *)
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO HandleFileMsg( obj, msg );
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO FrameLinks( obj, msg )
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
				(* IF obj.bindcount <4 THEN *)
					vyBase.objecthandle( obj, msg )
				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Gen*;
	VAR m: tMean;
	BEGIN
		aM.dS( "antsMeanArray.Gen" );
		NEW( m );  m.handle := Handler;  DoInit( m );  Objects.NewObj := m (* m.bindcount := 0; *)
	END Gen;

	PROCEDURE New*;
	VAR m: tMean;  l: antsCommands.tScanList;  srcobj, destobj: vyBase.Object;
		name: ARRAY 64 OF CHAR;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME src=OBJ dest=OBJ" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "src", srcobj ) &
		    antsCommands.ExpectObjectFromKeyword( l, "dest", destobj ) THEN
			Gen;  m := Objects.NewObj( tMean );  vyName.RegisterNamed( m, name );  antsObjects.SetLink( srcobj, m, "source" );
			antsObjects.SetLink( destobj, m, "dest" );  vyBase.Subscribe( srcobj, m );
			vyBase.Subscribe( m, destobj ) (*  cycles when storing !! *)
		END
	END New;

	PROCEDURE Init*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  umsg: vyBase.UpdateMessage;
	BEGIN
		l := antsCommands.ScanFromPar( "mean=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "mean", obj ) THEN
			WITH obj: tMean DO DoInit( obj );  obj.handle( obj, umsg )
			END
		END
	END Init;

BEGIN
	aM.launch;
END antsMeanArray.


fofAutomatic.Do
antsDiscreteFields.NewArray > name Array > w 50 > h 50 > depth 2~
antsViews.Show > name Array ~
antsArrayObjects.Copy > name FieldEv > to MeanArray ~
antsViews.Show > name MeanArray ~
antsMeanArray.New src = FieldEv dest = MeanArray ~
antsBinaryIsingS.NewModel > name Model  > h 0.0 > beta 0.3 ~
antsGibbs.DefineGibbsSampler > name Sampler > presteps 0 > steps 10 ~
antsGibbs.AttachModel > sampler Sampler > model Model ~
antsGibbs.AttachArray > sampler Sampler > array Array ~
antsGibbs.Step > sampler Sampler > times 10 ~
System.Time
~
Voyager.Show Array as antsObjectView ~
Voyager.Show Array as antsDependency ~

