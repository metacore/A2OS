MODULE antsArrayPictures IN Oberon;   (* fof *)
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


IMPORT vyBase, Objects, Pictures, antsObjects, Files, Gadgets, antsCommands, vyName, antsToolbox, vyCommandMenus,
	antsArrayObjects, vyColorPalettes, aM := antsMessages, vyLinks, antsSecurity;

TYPE

	(* Benutzungsregel mit Get(): Wenn Get aufgerufen, dann Konsistenz garantieren, generell für Images und Pictures, evtl. weiteres Format *)

	tObject* = POINTER TO tObjectDesc;
	tObjectDesc* = RECORD (vyBase.ObjDesc)
		synced-: BOOLEAN;
		pict*: Pictures.Picture;
		w*, h*, depth*: antsObjects.Index;   (* cache *)
		A*: antsArrayObjects.tINTEGERObject;
		trans*: antsObjects.PAConsistTrafoProc
	END;

	setPictMsg* = RECORD (Objects.ObjMsg);
		pict*: Pictures.Picture;
		changed*: vyBase.Object
	END;

	PROCEDURE Min( a, b: LONGINT ): LONGINT;
	BEGIN
		IF a < b THEN RETURN a ELSE RETURN b END
	END Min;

	PROCEDURE HandleAttributes( o: tObject;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN
			M.Enum( "Gen" );  M.Enum( "w" );  M.Enum( "h" );  M.Enum( "depth" );  M.Enum( "synced" );  M.Enum( "ARRAY" );  vyBase.objecthandle( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsArrayPictures.Gen', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "w" THEN M.class := Objects.Int;  M.i := o.w;  M.res := 0
			ELSIF M.name = "h" THEN M.class := Objects.Int;  M.i := o.h;  M.res := 0
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
		IF M.id = Objects.enum THEN M.Enum( "pict" );  M.Enum( "array" );  vyBase.objecthandle( F, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "pict" THEN M.obj := F.pict;  M.res := 0
			ELSIF M.name = "array" THEN M.obj := F.A;  M.res := 0
			ELSE vyBase.objecthandle( F, M )
			END
		ELSE vyBase.objecthandle( F, M )
		END
	END FrameLinks;

	PROCEDURE HandleFileMsg( obj: tObject;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  w, h, depth: LONGINT;  version: INTEGER;
		(*! store Picts as GIF for color preserving or store colors *)
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Files.ReadLInt( msg.R, w );
			Files.ReadLInt( msg.R, h );  Files.ReadLInt( msg.R, depth );  obj.w := w;  obj.h := h;  obj.depth := depth;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS Pictures.Picture) THEN obj.pict := objsub( Pictures.Picture ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS antsArrayObjects.tObject) THEN obj.A := objsub( antsArrayObjects.tINTEGERObject ) END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  Files.WriteLInt( msg.R, obj.w );
			Files.WriteLInt( msg.R, obj.h );  Files.WriteLInt( msg.R, obj.depth );  Gadgets.WriteRef( msg.R, obj.lib, obj.pict );
			Gadgets.WriteRef( msg.R, obj.lib, obj.A )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE CheckDimensions( obj: tObject );
	VAR pict: Pictures.Picture;  col: INTEGER;  r, g, b: INTEGER;
	BEGIN
		IF (obj.w # obj.A.w) OR (obj.h # obj.A.h) THEN
			obj.w := obj.A.w;  obj.h := obj.A.h;  pict := obj.pict;  Pictures.Create( obj.pict, SHORT( obj.w ), SHORT( obj.h ), 8 );
			FOR col := 0 TO 255 DO Pictures.GetColor( pict, col, r, g, b );  Pictures.SetColor( obj.pict, col, r, g, b ) END
		END;
		IF (obj.depth # obj.A.depth) THEN
			obj.depth := Min( obj.A.depth, 256 )
			(* do nothing, will be done by viewers *)
		END
	END CheckDimensions;

	PROCEDURE Sync*( obj: tObject );
	VAR x, y: INTEGER;  A: antsArrayObjects.tINTEGERArray;
	BEGIN
		IF obj.A # NIL THEN
			CheckDimensions( obj );  A := obj.A.A;
			(* get picture contents *)
			IF obj.trans = NIL THEN
				(*
			y := 0;
			WHILE y < obj.h DO
				Pictures.PutLine(obj.pict, A[y], 0, y, SHORT(obj.w));
				INC(y)
			END;
			*)

				y := 0;
				WHILE y < obj.h DO
					x := 0;
					WHILE x < obj.w DO
						IF A[y, x] >= 255 THEN
							Pictures.Dot( obj.pict, 254, x, y, 1 );   (* bug in Linux oberon *)
						ELSIF A[y, x] < 0 THEN Pictures.Dot( obj.pict, 0, x, y, 1 );
						ELSE Pictures.Dot( obj.pict, A[y, x], x, y, 1 );
						END;
						INC( x );
					END;
					INC( y )
				END;

				obj.synced := TRUE
			ELSE
				obj.trans( obj );  obj.synced := TRUE
				(*
			HALT(99); (* not yet implemented *)
			*)
			END
		END
	END Sync;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR
	BEGIN
		WITH obj: tObject DO
			IF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO
					obj.synced := FALSE;  obj.depth := Min( 256, obj.A.depth );
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
			ELSIF msg IS vyCommandMenus.enumMsg THEN
				WITH msg: vyCommandMenus.enumMsg DO vyCommandMenus.Ask( obj.A );
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					IF ~obj.synced THEN Sync( obj ) END;
					IF msg.lib # obj.lib THEN
						vyBase.objecthandle( obj, msg );  antsObjects.Bind( obj.A, msg );  antsObjects.Bind( obj.pict, msg )
					END;
				END;
			ELSIF msg IS setPictMsg THEN
				WITH msg: setPictMsg DO
					obj.pict := msg.pict;  obj.w := msg.pict.width;  obj.h := msg.pict.height;
					IF obj.A # NIL THEN DoToArray( obj, obj.A.depth, "" );  msg.changed := obj.A ELSE obj.depth := 256 END

				END;
			ELSE vyBase.objecthandle( obj, msg )

			END
		END
	END Handler;

	PROCEDURE Init*( obj: tObject );
	BEGIN
		obj.pict := NIL;  obj.A := NIL;  obj.w := 0;  obj.h := 0;  obj.depth := 0;  obj.handle := Handler;  obj.trans := NIL;
		obj.synced := FALSE
	END Init;

	PROCEDURE Gen*;
	VAR obj: tObject;
	BEGIN
		NEW( obj );  Init( obj );  Objects.NewObj := obj
	END Gen;

	PROCEDURE FromArray*( obj: tObject;  A: antsArrayObjects.tINTEGERObject );
	VAR r, g, b: INTEGER;  i: LONGINT;
	BEGIN
		obj.A := A;  obj.w := A.w;  obj.h := A.h;  obj.depth := A.depth;

		NEW( obj.pict );  Pictures.Create( obj.pict, SHORT( obj.w ), SHORT( obj.h ), 8 );
		FOR i := 0 TO obj.depth - 1 DO r := SHORT( (i) * 255 DIV (obj.depth - 1) );  g := r;  b := r;  Pictures.SetColor( obj.pict, SHORT( i ), r, g, b ) END;
		FOR i := obj.depth TO 255 DO Pictures.SetColor( obj.pict, SHORT( i ), 255, 0, 0 ) END;
		vyBase.Subscribe( obj.A, obj );  Sync( obj )
	END FromArray;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  from: vyBase.Object;  obj: tObject;  link: vyLinks.Link;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME from=OBJ [>show] ~ create new Picture <name> from antsArrayObjects.Object <from>" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "from", from ) THEN
			WITH from: antsArrayObjects.tINTEGERObject DO
				Gen;  obj := Objects.NewObj( tObject );  FromArray( obj, from );  vyName.RegisterNamed( obj, name );
				antsObjects.Register( obj );
				IF antsCommands.FindKeyword( l, "show" ) THEN link := NIL;  vyLinks.InsertObj( link, obj );  vyBase.Show( link, 1, "antsViews" ) END

			END
		END
	END New;

	PROCEDURE P2A( obj: tObject;  depth: LONGINT );
	VAR x, y: INTEGER;  r, g, b: INTEGER;  ncm: vyColorPalettes.NewColMsg;  img: Pictures.Picture;
	BEGIN
		aM.vSI( "Pict Array Conversion, depth = ", depth );  img := obj.pict;  vyColorPalettes.InitConversion( depth, ncm.pal );
		FOR y := 0 TO img.height - 1 DO
			FOR x := 0 TO img.width - 1 DO
				Pictures.GetColor( img, Pictures.Get( img, x, y ), r, g, b );  obj.A.A[y, x] := SHORT(vyColorPalettes.Convert( r, g, b ));
			END
		END;
		obj.depth := depth;  obj.synced := FALSE;  vyBase.ForUsersHandle( obj, ncm )

	END P2A;

	PROCEDURE DoToArray*( obj: tObject;  depth: LONGINT;  name: vyName.tNameArray );
	BEGIN
		IF obj.A # NIL THEN aM.S( "overwriting existing ARRAY" );
			(* Now: new Array object*)
			antsArrayObjects.ChangeSize( obj.A, obj.w, obj.h )
		ELSE
			obj.A := antsArrayObjects.NewINTEGERObject( obj.w, obj.h, depth );  vyName.RegisterNamed( obj.A, name );
			vyBase.Subscribe( obj.A, obj )

		END;
		(* now convert to Array, colors will be set in Recall procedure *)
		P2A( obj, depth );  vyBase.Update( obj )
	END DoToArray;

	PROCEDURE SetPicture*( obj: tObject;  pict: Pictures.Picture;  syncarray: BOOLEAN );
	VAR A: antsArrayObjects.tINTEGERArray;
	BEGIN
		obj.pict := pict;
		IF (pict.width # obj.w) OR (pict.height # obj.h) THEN
			obj.w := pict.width;  obj.h := pict.height;  NEW( A, obj.w, obj.h );  antsArrayObjects.EmbedINTEGERArray( A, obj.A )
		END;
		IF syncarray THEN P2A( obj, obj.depth ) END;
		vyBase.Update( obj )
	END SetPicture;

	PROCEDURE ToArray*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  from: vyBase.Object;  obj: tObject;  depth: LONGINT;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME from=OBJ depth=INT ~# Convert Image to Array with <depth> greyvalues / colors." );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "from", from ) &
		    antsCommands.ExpectNumberFromKeyword( l, "depth", depth ) THEN
			WITH from: tObject DO Gen;  obj := Objects.NewObj( tObject );  DoToArray( from, depth, name )
			END
		END
	END ToArray;

	PROCEDURE Load*;
	VAR l: antsCommands.tScanList;  name, fname: vyName.tNameArray;  obj: tObject;  done: BOOLEAN;  link: vyLinks.Link;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME fname=STR [>show] ~# Load picture from File" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectStringFromKeyword( l, "fname", fname ) THEN
			Gen;  obj := Objects.NewObj( tObject );  antsToolbox.LoadPicture( obj.pict, fname, done );
			IF done THEN
				obj.w := obj.pict.width;  obj.h := obj.pict.height;  obj.depth := MAX( LONGINT );  vyName.RegisterNamed( obj, name );
				antsObjects.Register( obj );
				IF antsCommands.FindKeyword( l, "show" ) THEN link := NIL;  vyLinks.InsertObj( link, obj );  vyBase.Show( link, 1, "antsViews" ) END

			END
		END
	END Load;

	PROCEDURE finishFile*( VAR f: Files.File;  name: ARRAY OF CHAR );
	VAR obj: tObject;  done: BOOLEAN;  link: vyLinks.Link;  o1: vyBase.Object;  picture: Pictures.Picture;
	BEGIN
		IF f = NIL THEN RETURN END;
		antsToolbox.LoadPicture( picture, name, done );
		IF (picture = NIL ) OR (~done) THEN antsSecurity.Halt( "Loading Image failed" );  RETURN END;
		IF antsCommands.ExpectName( "name", name ) THEN
			IF antsCommands.Find( "replace" ) THEN
				o1 := vyName.FindObj( name );
				IF o1 # NIL THEN obj := o1( tObject ) END
			END;

			IF obj = NIL THEN
				Gen;  obj := Objects.NewObj( tObject );  vyName.RegisterNamed( obj, name );  antsObjects.Register( obj )
			END;
			obj.pict := picture;  obj.w := obj.pict.width;  obj.h := obj.pict.height;  obj.depth := MAX( LONGINT );
			IF antsCommands.Find( "show" ) & (o1 = NIL ) THEN link := NIL;  vyLinks.InsertObj( link, obj );  vyBase.Show( link, 1, "antsViews" ) END;
			vyBase.Update( obj )
		END
	END finishFile;

	PROCEDURE DoShow*( A: antsArrayObjects.tINTEGERObject;  VAR obj: tObject );
	VAR link: vyLinks.Link;
	BEGIN
		Gen;  obj := Objects.NewObj( tObject );  FromArray( obj, A );  link := NIL;  vyLinks.InsertObj( link, obj );
		vyBase.Show( link, 1, "antsViews" )
	END DoShow;

	PROCEDURE LoadDialoged*;
	BEGIN
		antsCommands.InitScan( "name=NAME [>replace] [>show] ~# Load picture from file, dialoged" );  antsToolbox.FileOpen( finishFile, "Pictures", "*.GIF;*.JPG;*.JPEG;*.PGM;*.PPM" )
	END LoadDialoged;

BEGIN
	aM.launch;
END antsArrayPictures.

System.Free antsPictureViews antsArrayPictures ~

antsDiscreteFields.NewArray > name Array > w 50 > h 50 > depth 50~
antsArrayPictures.ImgFromArray > name testpict > from Array ~
antsArrayPictures.LoadImg > name testpict > fname "Bart.Pict"
Voyager.Show testpict as antsObjectView ~

Voyager.Show testpict as antsPictureViews ~

Voyager.Show Array as antsViews ~

antsArrayPictures.LoadPict > name testpict > fname ^

antsArrayPictures.LoadDialoged > name testpict   > show > replace~

System.Free antsArrayPictures ~
fofAutomatic.Do
antsViews.Show testpict ~

fofAutomatic.Do
antsArrayPictures.LoadDialoged > name testpict   > show > replace~
System.Time
~
