MODULE antsPictureViews IN Oberon;   (* fof *)
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




IMPORT vyPort, vyName, vyBase, vyGraphBase, Display, vyEvents, antsArrayPictures, Pictures, antsArrayObjects, antsViews,
	antsObjects, vyRectangles, antsCommands, antsPictCoordinate, Objects, vyCommandMenus, Gadgets, vyHostTexts, Files,
	antsToolbox, antsArrayPictures16, vyTracking, Effects, Links, vyColorPalettes, aM := antsMessages;

TYPE

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (antsViews.tLayerDesc)
		E-: antsArrayPictures.tObject
	END;

VAR
	newlayer-: tLayer;  maxw, maxh: INTEGER;  texture: BOOLEAN;

	PROCEDURE Copy( msg: Objects.CopyMsg;  source, dest: tLayer );
	BEGIN
		aM.dS( "copy pict views called" );
		dest^ := source^ (* vyPort.LayerCopy(msg,source,dest); *)
	END Copy;

	PROCEDURE Recall( layer: tLayer );
	VAR pw, ph: INTEGER;  vx, vy, vpx, vpy, vpw, vph: INTEGER;  c: antsPictCoordinate.tCoordinate;  pict: Pictures.Picture;  i: INTEGER;  r, g, b: INTEGER;
	BEGIN
		IF layer.E.A # NIL THEN  (* use colors of pal *)  (*! only when sync ? *)
			antsViews.CheckColors( layer, layer.E.depth )
		END;
		IF ~layer.E.synced THEN antsArrayPictures.Sync( layer.E ) END;
		layer.refArray := layer.E.A;
		IF layer.E.A # NIL THEN  (* use colors of pal *)  (*! only when sync ? *)
			pict := layer.E.pict;
			FOR i := 0 TO 255 DO Display.GetColor( layer.pal.dcol[i], r, g, b );  Pictures.SetColor( pict, i, r, g, b ) END
		END;

		c := antsPictCoordinate.tc;

		vx := c.vx;  vy := c.vy;   (* coordinates of first visible point in array coordinates*)
		vpx := c.px;  vpy := c.py;  vpw := c.pw;  vph := c.ph;   (* coordinates of visible area in display-array coordinates (with stretching) *)
		pw := SHORT( layer.E.w );  ph := SHORT( layer.E.h );   (* array width and height *)
		c.pictW := pw;  c.pictH := ph;  vyRectangles.RectIntersection( vpx, vpy, vpw, vph, 0, 0, SHORT( layer.E.w ), SHORT( layer.E.h ) );

		pict := layer.E.pict;  c.p := pict;  vpx := c.px;  vpy := c.py;  vpw := c.pw;  vph := c.ph;
		vyRectangles.RectIntersection( vpx, vpy, vpw, vph, 0, 0, pict.width, pict.height );
		IF c.fixed THEN
			vyGraphBase.SetRealWorldRgn( 0, 0, layer.E.w, layer.E.h, 0 );
			vyGraphBase.StretchedPict2d( layer.E.pict, 0, 0, SHORT( layer.E.w ), SHORT( layer.E.h ), 0, 0, layer.E.w, layer.E.h );  vpx := 0;
			vpy := 0;  vpw := SHORT( layer.E.w );  vph := SHORT( layer.E.h )
		ELSIF c.free THEN vyGraphBase.StretchedPict2d( layer.E.pict, 0, 0, SHORT( layer.E.w ), SHORT( layer.E.h ), 0, 0, layer.E.w, layer.E.h );
		ELSE
			IF (c.dx = 1) & (c.dy = 1) THEN vyGraphBase.Pict( layer.E.pict, vpx, vpy, vpw, vph, c.vx, c.vy )
			ELSE vyGraphBase.StretchedPict( layer.E.pict, vpx, vpy, vpw, vph, c.vx, c.vy, vpw * c.dx, vph * c.dy )
			END
		END;

		IF layer.grid & (c.dx > 1) & (c.dy > 1) THEN
			vyGraphBase.SetForeColor( layer.style.selectcol );  vx := vpx;
			WHILE (vx < vpx + vpw) DO vyGraphBase.Line2d( vx, vpy, vx, vpy + vph );  INC( vx ) END;
			vy := vpy;
			WHILE (vy < vpy + vph) DO vyGraphBase.Line2d( vpx, vy, vpx + vpw, vy );  INC( vy ) END
		END

	END Recall;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtIdent)) THEN priority := vyEvents.PrioNormal END;
		IF event.priority < priority THEN event.responder := layer;  event.priority := priority END
	END Responsible;

	PROCEDURE Center;
	VAR tempLayer: tLayer;
	BEGIN
		tempLayer := antsViews.tempLayer( tLayer );
		antsPictCoordinate.Center( SHORT( tempLayer.E.w ), SHORT( tempLayer.E.h ), antsPictCoordinate.tc );  vyBase.Update( tempLayer )
	END Center;

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  antsViews.Handler( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS antsArrayPictures.tObject) THEN obj.E := objsub( antsArrayPictures.tObject ) END
		ELSIF msg.id = Objects.store THEN
			ASSERT ( obj.lib = obj.E.lib, 100 );
			Files.WriteInt( msg.R, 0 );  antsViews.Handler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.E )
		ELSE antsViews.Handler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  antsViews.Handler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsPictureViews.New', M.s );  M.class := Objects.String;  M.res := 0 ELSE antsViews.Handler( obj, M ) END
		ELSIF M.id = Objects.set THEN antsViews.Handler( obj, M )
		ELSE antsViews.Handler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "E" );  antsViews.Handler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "E") THEN msg.obj := obj.E;  msg.res := 0
		ELSIF (msg.id = Objects.set) & ((msg.name = "E") OR (msg.name = "Model")) & (msg.obj # NIL ) &
				(msg.obj IS antsArrayObjects.tObject) THEN
		ELSE antsViews.Handler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE finalize( VAR F: Files.File;  name: ARRAY OF CHAR );
	VAR R: Files.Rider;  tempLayer: tLayer;
	BEGIN
		IF F = NIL THEN RETURN END;
		Files.Set( R, F, 0 );  tempLayer := antsViews.tempLayer( tLayer );  antsToolbox.StorePictAsGIF( tempLayer.E.pict, R );
		Files.Register( F );  Files.Close( F )
	END finalize;

	PROCEDURE StoreAsGIF;
	VAR name, prefix, suffix: ARRAY 256 OF CHAR;
		tempLayer: tLayer;
	BEGIN
		tempLayer := antsViews.tempLayer( tLayer );

		COPY( "GIF", suffix );  COPY( "FromViewer", prefix );  antsToolbox.MakefileName( prefix, suffix, name );

		antsToolbox.FileStore( finalize, "GIF Images", "*.GIF", "GIF", name )
		(*
	F := Files.New(name);
	IF F = NIL THEN aM.SS("Could not write to", name);   RETURN END;
	Files.Set(R, F, 0);
	antsToolbox.StorePictAsGIF(tempLayer.E.pict, R);
	(*
	vyPort.StorePictAsGIF(f, R);
	INSERT DisplayGrabbing and Storing here.
	*)
	Files.Register(F);    Files.Close(F);
	aM.SS("Picture stored as", name)
	*)
	END StoreAsGIF;

	PROCEDURE SendPictTo;
	VAR tempLayer: tLayer;  obj: antsArrayPictures.tObject;  msg: antsArrayPictures.setPictMsg;  keys: SET;  dx, dy: INTEGER;
		pict: Pictures.Picture;  i, r, g, b: INTEGER;  copy: antsArrayObjects.tINTEGERArray;  orig: Objects.Object;
	BEGIN
		vyCommandMenus.Wait();  tempLayer := antsViews.tempLayer( tLayer );  obj := tempLayer.E;  NEW( pict );
		Pictures.Create( pict, obj.pict.width, obj.pict.height, obj.pict.depth );
		Pictures.Copy( obj.pict, pict, 0, 0, obj.pict.width, obj.pict.height, 0, 0, obj.pict.width, obj.pict.height, Display.replace );
		FOR i := 0 TO 255 DO Pictures.GetColor( obj.pict, i, r, g, b );  Pictures.SetColor( pict, i, r, g, b ) END;
		msg.pict := pict;  vyTracking.Help( "Click on destination" );  vyTracking.TrackMouseCont( keys, dx, dy, Effects.PointHand );
		antsToolbox.MsgToTypedXY( dx, dy, msg, "antsViews.tLayerDesc" );
		IF msg.changed # NIL THEN  (* now look for original array, maybe we changed the sampling array *)
			Links.GetLink( msg.changed, "orig", orig );

			IF orig # NIL THEN
				WITH orig: antsArrayObjects.tINTEGERObject DO
					antsArrayObjects.CopyII( msg.changed( antsArrayObjects.tINTEGERObject ).A, copy, 0, 0,
															 msg.changed( antsArrayObjects.tINTEGERObject ).w,
															 msg.changed( antsArrayObjects.tINTEGERObject ).h, 0, 0 );
					antsArrayObjects.EmbedINTEGERArray( copy, orig )
				END
			END;
			(*
		vyName.GetObjId(msg.changed,name);
		(* name := msg.changed; *)
		Strings.Append(name,"O");
		chobj := vyName.FindObj(name);
		Out.Ln; Out.String("Trying to change "); Out.String(name);
		IF chobj # NIL THEN
		Out.Ln; Out.String("Found Orig");
		WITH chobj: antsArrayObjects.tINTEGERObject DO
		antsArrayObjects.CopyII(msg.changed(antsArrayObjects.tINTEGERObject).A,copy,0,0,msg.changed(antsArrayObjects.tINTEGERObject).w,
		msg.changed(antsArrayObjects.tINTEGERObject).h,0,0);
		antsArrayObjects.EmbedINTEGERArray(copy,chobj);
		END;
		END;
		*)
			vyTracking.HelpEnd
		END

	END SendPictTo;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR layer, copy: tLayer;  done: BOOLEAN;
	BEGIN
		ASSERT ( o IS tLayer, 100 );
		layer := o( tLayer );  done := FALSE;
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( layer );  done := TRUE;  antsViews.Handler( layer, msg );
			END;
		ELSIF msg IS vyColorPalettes.NewColMsg THEN
			WITH msg: vyColorPalettes.NewColMsg DO vyColorPalettes.CopyPalette( msg.pal, layer.pal );
			END;
		ELSIF msg IS antsToolbox.GetCoordMsg THEN
			WITH msg: antsToolbox.GetCoordMsg DO
				IF msg.update THEN vyBase.Update( layer ) END;
				vyGraphBase.PointToPoint2d( msg.x, msg.y, msg.xr, msg.yr );  msg.w := layer.E.w;  msg.h := layer.E.h;
				msg.layer := layer;  msg.a := layer.E.A;
			END;
		ELSIF msg IS vyBase.UpdateMessage THEN
			WITH msg: vyBase.UpdateMessage DO
				antsViews.CheckColors( layer, layer.E.depth );  antsViews.Handler( layer, msg );
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN Responsible( layer, msg );  antsViews.Handler( layer, msg )
				ELSE antsViews.Handler( layer, msg )
				END;
				done := TRUE
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				NEW( copy );  msg.obj := copy;
				Copy( msg, layer, msg.obj( tLayer ) );  antsViews.Handler( layer, msg );   (*! ordering ? *)
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO HandleFileMsg( layer, msg )
			END;
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO HandleAttributes( layer, msg )
			END;
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO HandleLinks( layer, msg )
			END;
		ELSIF msg IS Objects.BindMsg THEN
			WITH msg: Objects.BindMsg DO
				antsViews.Handler( layer, msg );
				antsObjects.Bind( layer.E, msg ) (* not necessary, will be done by subscribe mechanism ?? *)
			END;
		ELSIF msg IS vyCommandMenus.enumMsg THEN
			WITH msg: vyCommandMenus.enumMsg DO
				antsViews.Handler( layer, msg );  msg.Enum( "Store Pict as GIF", StoreAsGIF, layer );  msg.Enum( "Send Pict To", SendPictTo, layer );
				IF layer.E # NIL THEN layer.E.handle( layer.E, msg ) END
			END;
		ELSIF msg IS antsArrayPictures.setPictMsg THEN
			WITH msg: antsArrayPictures.setPictMsg DO
				IF layer.E # NIL THEN layer.E.handle( layer.E, msg ) END
			END;
		ELSE antsViews.Handler( layer, msg )
		END;
		IF ~done THEN END
	END Handler;

	PROCEDURE Init( layer: tLayer );
	BEGIN
		antsViews.Init( layer );  layer.handle := Handler;  vyCommandMenus.Add( layer.commands, StoreAsGIF, "Store" );
		vyCommandMenus.Add( layer.commands, Center, "Center" )
	END Init;

	PROCEDURE Open*( layer: tLayer;  E: antsArrayPictures.tObject );
	VAR id: vyName.tNameArray;
	BEGIN
		Init( layer );  id := "ViewP:";  vyName.AppendObjId( E, id );  vyPort.OpenLayer( layer, id );  layer.E := E;
		IF E.A # NIL THEN layer.pal.first := 0;  layer.pal.last := SHORT( E.depth - 1 );

			antsViews.DefaultPath( layer, texture );  texture := FALSE
		END;

		vyBase.Subscribe( layer.E, layer )
	END Open;

	PROCEDURE New*;
	BEGIN
		aM.cmd;  NEW( newlayer );  Init( newlayer );  Objects.NewObj := newlayer
	END New;

	PROCEDURE DoShow*( E: antsArrayPictures.tObject;  add: BOOLEAN;  VAR c: antsPictCoordinate.tCoordinate ): vyPort.tLayer;
	VAR port: vyPort.Frame;  p: vyPort.Picture;  layer: tLayer;  w, h: INTEGER;
		name: ARRAY 256 OF CHAR;
	BEGIN
		NEW( layer );  Open( layer, E );  name := "View of ";  vyName.AppendObjId( E, name );

		IF c = NIL THEN NEW( c );  antsPictCoordinate.OpenC( c, 1, 1 )
		END;
		IF ~add THEN
			w := SHORT( E.w );  h := SHORT( E.h );
			IF w > maxw THEN w := maxw END;
			IF h > maxh THEN h := maxh END;
			port := vyPort.XNewFrame( w + 2 * vyPort.Border, h + 2 * vyPort.Border );  port.W := (w + 2 * vyPort.Border);
			port.H := (h + 2 * vyPort.Border);  p := vyPort.NewP( c );  p.W := (w);  p.H := (h);
			p.backGround := vyGraphBase.dgrey;  vyPort.AddPicture( port, p, 0, 0, 1, 1 )
		ELSE p := vyPort.GetFocusPicture()
		END;
		layer.style.fcol := vyGraphBase.green;  layer.style.fillcol := vyGraphBase.red;
		layer.style.selectcol := vyGraphBase.black;  vyPort.AddLayer( p, layer );
		IF ~add THEN vyHostTexts.InsertGadget( port );  antsToolbox.NameOpened( name ) END;

		RETURN layer
	END DoShow;

	PROCEDURE Show*;
	VAR l: antsCommands.tScanList;  obj, o: vyBase.Object;  la: vyPort.tLayer;  name: vyName.tNameArray;  add: BOOLEAN;
		c: antsPictCoordinate.tCoordinate;  dx: LONGINT;  pobj: antsArrayPictures.tObject;
	BEGIN
		l := antsCommands.ScanFromPar( "name= NAME [>add] [>texture] [gridsize=INT]" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			add := antsCommands.FindKeyword( l, "add" );  obj := vyName.FindObj( name );  o := obj;
			IF antsCommands.FindKeyword( l, "texture" ) THEN texture := TRUE END;
			IF antsCommands.GetNumberFromKeyword( l, "gridsize", dx ) THEN NEW( c );  antsPictCoordinate.OpenC( c, SHORT( dx ), SHORT( dx ) ) END;
			IF o IS antsArrayPictures.tObject THEN la := DoShow( o( antsArrayPictures.tObject ), add, c )
			ELSIF o IS antsArrayObjects.tINTEGERObject THEN
				antsArrayPictures.Gen;  pobj := Objects.NewObj( antsArrayPictures.tObject );
				antsArrayPictures.FromArray( pobj, o( antsArrayObjects.tINTEGERObject ) );  la := DoShow( pobj, add, c )
			END
		END
	END Show;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  editor: vyPort.tLayer;  c: antsPictCoordinate.tCoordinate;  pobj: antsArrayPictures.tObject;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO
			IF data IS antsArrayPictures.tObject THEN editor := DoShow( data( antsArrayPictures.tObject ), FALSE , c )
			ELSIF data IS antsArrayObjects.tINTEGERObject THEN
				IF data( antsArrayObjects.tINTEGERObject ).depth > 256 THEN
					antsArrayPictures16.Gen;  pobj := Objects.NewObj( antsArrayPictures16.tObject );
					antsArrayPictures16.FromArray( pobj( antsArrayPictures16.tObject ), data( antsArrayObjects.tINTEGERObject ) );
					editor := DoShow( pobj, FALSE , c )
				ELSE
					antsArrayPictures.Gen;  pobj := Objects.NewObj( antsArrayPictures.tObject );
					antsArrayPictures.FromArray( pobj, data( antsArrayObjects.tINTEGERObject ) );
					editor := DoShow( pobj, FALSE , c )
				END
			END;
			data := vyBase.NextParObj()
		END
	END ShowP;

BEGIN
	aM.launch;  maxw := Display.Width DIV 3;  maxh := Display.Height DIV 3;  texture := FALSE
END antsPictureViews.
System.Free antsPictureViews~

