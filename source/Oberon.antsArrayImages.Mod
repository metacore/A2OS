MODULE antsArrayImages IN Oberon;   (* fof *)
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




IMPORT vyBase, Objects, Images, antsObjects, Files, Gadgets, SYSTEM, antsCommands, vyName, antsToolbox,
	antsArrayObjects, aM := antsMessages, vyColorPalettes, vyLinks, antsSecurity, vyCommandMenus;

TYPE

	tObject* = POINTER TO tObjectDesc;
	tObjectDesc* = RECORD (vyBase.ObjDesc)
		synced-: BOOLEAN;
		img*: Images.Image;
		w*, h*, depth*: antsObjects.Index;   (* cache *)
		A*: antsArrayObjects.tINTEGERObject;
		trans*: antsObjects.PAConsistTrafoProc
	END;

	PROCEDURE HandleAttributes( o: tObject;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN
			M.Enum( "Gen" );  M.Enum( "w" );  M.Enum( "h" );  M.Enum( "depth" );  M.Enum( "synced" );  M.Enum( "ARRAY" );  vyBase.objecthandle( o, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsArrayImages.Gen', M.s );  M.class := Objects.String;  M.res := 0
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
		IF M.id = Objects.enum THEN M.Enum( "img" );  M.Enum( "array" );  vyBase.objecthandle( F, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "img" THEN M.obj := F.img;  M.res := 0
			ELSIF M.name = "array" THEN M.obj := F.A;  M.res := 0
			ELSE vyBase.objecthandle( F, M )
			END
		ELSE vyBase.objecthandle( F, M )
		END
	END FrameLinks;

	PROCEDURE HandleFileMsg( obj: tObject;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  w, h, depth: SIGNED32;  version: SIGNED16;
		(*! store Picts as GIF for color preserving or store colors *)
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyBase.objecthandle( obj, msg );  Files.ReadLInt( msg.R, w );
			Files.ReadLInt( msg.R, h );  Files.ReadLInt( msg.R, depth );  obj.w := w;  obj.h := h;  obj.depth := depth;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS Images.Image) THEN obj.img := objsub( Images.Image ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS antsArrayObjects.tObject) THEN obj.A := objsub( antsArrayObjects.tINTEGERObject ) END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  vyBase.objecthandle( obj, msg );  Files.WriteLInt( msg.R, obj.w );
			Files.WriteLInt( msg.R, obj.h );  Files.WriteLInt( msg.R, obj.depth );  Gadgets.WriteRef( msg.R, obj.lib, obj.img );
			Gadgets.WriteRef( msg.R, obj.lib, obj.A )
		ELSE vyBase.objecthandle( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE CheckDimensions( obj: tObject );
	VAR fmt: Images.Format;
	BEGIN
		IF (obj.w # obj.A.w) OR (obj.h # obj.A.h) THEN
			fmt := obj.img.fmt;  obj.w := obj.A.w;  obj.h := obj.A.h;  Images.Create( obj.img, SHORT( obj.w ), SHORT( obj.h ), fmt )
		END;
		IF (obj.depth # obj.A( antsArrayObjects.tINTEGERObject ).depth) THEN
			obj.depth := obj.A( antsArrayObjects.tINTEGERObject ).depth
			(* do nothing, will be done by viewers *)
		END
	END CheckDimensions;

	PROCEDURE MinMax( x, min, max: SIGNED16 ): SIGNED16;
	BEGIN
		IF x < min THEN RETURN min
		ELSIF x > max THEN RETURN max
		ELSE RETURN x
		END
	END MinMax;

	PROCEDURE Sync*( obj: tObject );
	VAR y, x: SIGNED16;  A: antsArrayObjects.tINTEGERArray;  adr: SIGNED32;  depth: SIGNED16;
	BEGIN
		(* caution: Don't send any update messages, Sync is called while writing to double buffer *)
		IF obj.A # NIL THEN
			CheckDimensions( obj );  A := obj.A.A;  depth := SHORT( obj.depth ) - 1;
			(* get picture contents *)
			IF obj.trans = NIL THEN
				y := 0;  adr := obj.img.adr;
				WHILE y < obj.h DO
					x := 0;
					WHILE x < obj.w DO SYSTEM.PUT( adr, CHR( MinMax( A[y, x], 0, depth ) ) );  INC( adr );  INC( x ) END;
					INC( y )
				END;
				obj.synced := TRUE
			ELSE obj.trans( obj );  obj.synced := TRUE
			END
		END
	END Sync;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR
	BEGIN
		WITH obj: tObject DO
			IF msg IS vyBase.UpdateMessage THEN
				WITH msg: vyBase.UpdateMessage DO
					obj.synced := FALSE;
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
					IF obj.lib # msg.lib THEN
						vyBase.objecthandle( obj, msg );  antsObjects.Bind( obj, msg );  antsObjects.Bind( obj.A, msg );
						antsObjects.Bind( obj.img, msg )
					END
				END;
			ELSE vyBase.objecthandle( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Init*( obj: tObject );
	BEGIN
		obj.img := NIL;  obj.A := NIL;  obj.w := 0;  obj.h := 0;  obj.depth := 0;  obj.handle := Handler;  obj.trans := NIL;
		obj.synced := FALSE
	END Init;

	PROCEDURE Gen*;
	VAR obj: tObject;
	BEGIN
		NEW( obj );  Init( obj );  Objects.NewObj := obj
	END Gen;

	PROCEDURE FromArray*( obj: tObject;  A: antsArrayObjects.tINTEGERObject );
	VAR r, g, b: SIGNED16;  i: SIGNED32;  pal: Images.Palette;  fmt: Images.Format;
	BEGIN
		obj.A := A;  obj.w := A.w;  obj.h := A.h;  obj.depth := A.depth;

		NEW( pal );
		FOR i := 0 TO obj.depth - 1 DO r := SHORT( (i) * 255 DIV (obj.depth - 1) );  g := r;  b := r;  Images.SetRGB( pal.col[i], r, g, b ) END;
		FOR i := obj.depth TO 255 DO Images.SetRGB( pal.col[i], 255, 0, 0 ) END;
		Images.InitPalette( pal, 255, 4 );  Images.InitPaletteFormat( fmt, pal );  NEW( obj.img );
		Images.Create( obj.img, SHORT( obj.w ), SHORT( obj.h ), fmt );  vyBase.Subscribe( obj.A, obj );  Sync( obj )
	END FromArray;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  from: vyBase.Object;  obj: tObject;  link: vyLinks.Link;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME from=OBJ [>show] # Create new ArrayImage from antsArrayObjects.Object <from>" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "from", from ) THEN
			WITH from: antsArrayObjects.tINTEGERObject DO
				Gen;  obj := Objects.NewObj( tObject );  FromArray( obj, from );  vyName.RegisterNamed( obj, name );
				antsObjects.Register( obj );
				IF antsCommands.FindKeyword( l, "show" ) THEN link := NIL;  vyLinks.InsertObj( link, obj );  vyBase.Show( link, 1, "antsViews" ) END
			END
		END
	END New;

	PROCEDURE DoToArray*( obj: tObject;  depth: SIGNED32;  name: vyName.tNameArray );
	VAR img: Images.Image;  pal: Images.Palette;  fmt: Images.Format;  x, y: SIGNED16;  r, g, b, a: SIGNED16;  pix: Images.Pixel;
		ncm: vyColorPalettes.NewColMsg;
	BEGIN
		IF obj.A # NIL THEN aM.S( "overwriting existing ARRAY" ) END;
		img := obj.img;  NEW( pal );  Images.InitPalette( pal, 255, 4 );  Images.InitPaletteFormat( fmt, pal );  NEW( obj.img );
		Images.Create( obj.img, SHORT( obj.w ), SHORT( obj.h ), fmt );
		Images.Copy( img, obj.img, 0, 0, img.width - 1, img.height - 1, 0, 0, Images.SrcCopy );
		(* NEW Image in palette Format *)
		(* Now: new Array object*)
		obj.A := antsArrayObjects.NewINTEGERObject( obj.w, obj.h, depth );  vyName.RegisterNamed( obj.A, name );
		vyBase.Subscribe( obj.A, obj );
		(* now convert to Array, colors will be set in Recall procedure *)
		vyColorPalettes.InitConversion( depth, ncm.pal );
		FOR y := 0 TO img.height - 1 DO
			FOR x := 0 TO img.width - 1 DO
				Images.Get( img, x, y, pix, Images.SrcCopy );  Images.GetRGBA( pix, r, g, b, a );
				obj.A.A[y, x] := SHORT(vyColorPalettes.Convert( r, g, b ));
			END
		END;
		obj.depth := depth;  obj.synced := FALSE;  vyBase.ForUsersHandle( obj, ncm );  vyBase.Update( obj )
	END DoToArray;

	PROCEDURE ToArray*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  from: vyBase.Object;  obj: tObject;  depth: SIGNED32;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME from=OBJ depth=INT ~# Convert Image to Array with <depth> greyvalues / colors." );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "from", from ) &
		    antsCommands.ExpectNumberFromKeyword( l, "depth", depth ) THEN
			WITH from: tObject DO Gen;  obj := Objects.NewObj( tObject );  DoToArray( from, depth, name )
			END
		END
	END ToArray;

	PROCEDURE finishFile*( VAR f: Files.File;  name: ARRAY OF CHAR );
	VAR obj: tObject;  done: BOOLEAN;  link: vyLinks.Link;  o1: vyBase.Object;  picture: Images.Image;
	BEGIN
		IF f = NIL THEN RETURN END;
		antsToolbox.LoadImage( picture, name, done );
		IF (picture = NIL ) OR (~done) THEN antsSecurity.Halt( "loading image failed, wrong format?" );  RETURN END;
		IF antsCommands.ExpectName( "name", name ) THEN
			IF antsCommands.Find( "replace" ) THEN
				o1 := vyName.FindObj( name );
				IF o1 # NIL THEN obj := o1( tObject ) END
			END;

			IF obj = NIL THEN
				Gen;  obj := Objects.NewObj( tObject );  vyName.RegisterNamed( obj, name );  antsObjects.Register( obj )
			END;
			obj.img := picture;  obj.w := obj.img.width;  obj.h := obj.img.height;  obj.depth := MAX( SIGNED32 );
			IF antsCommands.Find( "show" ) & (o1 = NIL ) THEN link := NIL;  vyLinks.InsertObj( link, obj );  vyBase.Show( link, 1, "antsViews" ) END;
			vyBase.Update( obj )
		END
	END finishFile;

	PROCEDURE Load*;
	VAR l: antsCommands.tScanList;  name, fname: vyName.tNameArray;  obj: tObject;  done: BOOLEAN;  link: vyLinks.Link;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME fname=STR [>show] ~# Load Image from File" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectStringFromKeyword( l, "fname", fname ) THEN
			Gen;  obj := Objects.NewObj( tObject );  antsToolbox.LoadImage( obj.img, fname, done );
			IF done THEN
				obj.w := obj.img.width;  obj.h := obj.img.height;  obj.depth := MAX( SIGNED32 );  vyName.RegisterNamed( obj, name );
				antsObjects.Register( obj );
				IF antsCommands.FindKeyword( l, "show" ) THEN link := NIL;  vyLinks.InsertObj( link, obj );  vyBase.Show( link, 1, "antsViews" ) END
			END
		END
	END Load;

	PROCEDURE LoadDialoged*;
	BEGIN
		antsCommands.InitScan( "name=NAME [>replace] [>show] ~# Load Image from File, dialoged" );  antsToolbox.FileOpen( finishFile, "Pictures", "*.GIF;*.JPG;*.JPEG" )
	END LoadDialoged;

BEGIN
	aM.launch;
END antsArrayImages.

System.Free antsImageViews antsArrayImages ~

antsDiscreteFields.NewArray > name Array > w 50 > h 50 > depth 50~
antsArrayImages.ImgFromArray > name testimg > from Array ~
antsArrayImages.LoadImg > name testimg > fname "Bart.Pict"
Voyager.Show testimg as antsObjectView ~

Voyager.Show testimg as antsImageViews ~


Voyager.Show Array as antsViews ~

antsArrayImages.LoadImg > name testimg > fname ^

