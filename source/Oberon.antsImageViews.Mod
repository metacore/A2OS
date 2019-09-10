MODULE antsImageViews IN Oberon;   (* fof *)
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




IMPORT vyPort, vyName, vyBase, vyGraphBase, Display, vyEvents, antsArrayImages, Images, Attributes, antsArrayObjects,
	antsViews, antsObjects, Files, antsToolbox, aM := antsMessages, vyRectangles, antsCommands, antsPictCoordinate,
	Objects, vyCommandMenus, Gadgets, vyHostTexts;

TYPE

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (antsViews.tLayerDesc)
		E-: antsArrayImages.tObject
	END;

VAR
	newlayer-: tLayer;  maxw, maxh: SIGNED16;  texture: BOOLEAN;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Recall( layer: tLayer );
	VAR pw, ph, vx, vy, vpx, vpy, vpw, vph: SIGNED16;  c: antsPictCoordinate.tCoordinate;  img: Images.Image;  i: SIGNED16;
	BEGIN
		IF ~layer.E.synced THEN antsArrayImages.Sync( layer.E ) END;
		layer.refArray := layer.E.A;

		IF layer.E.A # NIL THEN  (* use colors of pal *)  (*! only when sync ? *)
			img := layer.E.img;  antsViews.CheckColors( layer, layer.E.depth );
			IF img.fmt.pal # NIL THEN
				FOR i := 0 TO 255 DO img.fmt.pal.col[i] := layer.pal.icol[i] END
			END
		END;
		c := antsPictCoordinate.tc;

		vx := c.vx;  vy := c.vy;   (* coordinates of first visible point in array coordinates*)
		vpx := c.px;  vpy := c.py;  vpw := c.pw;  vph := c.ph;   (* coordinates of visible area in display-array coordinates (with stretching) *)
		pw := SHORT( layer.E.w );  ph := SHORT( layer.E.h );   (* array width and height *)
		c.pictW := pw;  c.pictH := ph;

		vyRectangles.RectIntersection( vpx, vpy, vpw, vph, 0, 0, SHORT( layer.E.w ), SHORT( layer.E.h ) );

		img := layer.E.img;  c.i := img;  vpx := c.px;  vpy := c.py;  vpw := c.pw;  vph := c.ph;
		vyRectangles.RectIntersection( vpx, vpy, vpw, vph, 0, 0, img.width, img.height );
		IF ~c.fixed THEN

			IF (c.dx = 1) & (c.dy = 1) THEN vyGraphBase.Image( layer.E.img, vpx, vpy, vpw, vph, c.vx, c.vy )
			ELSE vyGraphBase.StretchedImage( layer.E.img, vpx, vpy, vpw, vph, c.vx, c.vy, vpw * c.dx, vph * c.dy )
			END
		ELSE
			vyGraphBase.SetRealWorldRgn( 0, 0, layer.E.w, layer.E.h, 0 );
			vyGraphBase.StretchedImage2d( layer.E.img, 0, 0, SHORT( layer.E.w ), SHORT( layer.E.h ), 0, 0, layer.E.w, layer.E.h );  vpx := 0;
			vpy := 0;  vpw := SHORT( layer.E.w );  vph := SHORT( layer.E.h )
		END;
		IF layer.grid THEN
			vyGraphBase.SetForeColor( layer.style.selectcol );  vx := vpx;
			WHILE (vx < vpx + vpw) DO vyGraphBase.Line2d( vx, vpy, vx, vpy + vph );  INC( vx ) END;
			vy := vpy;
			WHILE (vy < vpy + vph) DO vyGraphBase.Line2d( vpx, vy, vpx + vpw, vy );  INC( vy ) END
		END

	END Recall;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;
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
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  antsViews.Handler( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF (objsub # NIL ) & (objsub IS antsArrayImages.tObject) THEN obj.E := objsub( antsArrayImages.tObject ) END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 0 );  antsViews.Handler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.E )
		ELSE antsViews.Handler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "hor" );  M.Enum( "ver" );  antsViews.Handler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'antsImageViews.New', M.s );  M.class := Objects.String;  M.res := 0 ELSE antsViews.Handler( obj, M ) END
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

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR layer, copy: tLayer;  done: BOOLEAN;
	BEGIN
		ASSERT ( o IS tLayer, 100 );
		layer := o( tLayer );  done := FALSE;
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( layer );  done := TRUE;  antsViews.Handler( layer, msg );
			END;
		ELSIF msg IS vyBase.UpdateMessage THEN
			WITH msg: vyBase.UpdateMessage DO antsViews.CheckColors( layer, layer.E.depth );

				antsViews.Handler( layer, msg );
			END;
		ELSIF msg IS antsToolbox.GetCoordMsg THEN
			WITH msg: antsToolbox.GetCoordMsg DO
				IF msg.update THEN vyBase.Update( layer ) END;
				vyGraphBase.PointToPoint2d( msg.x, msg.y, msg.xr, msg.yr );  msg.w := layer.E.w;  msg.h := layer.E.h;
				msg.layer := layer;  msg.a := layer.E.A;
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
				NEW( copy );  msg.obj := copy;  Copy( layer, msg.obj( tLayer ) );  antsViews.Handler( layer, msg );  done := TRUE
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
				IF msg.lib # layer.lib THEN antsViews.Handler( layer, msg );  antsObjects.Bind( layer.E, msg ) END;
			END;
		ELSIF msg IS vyCommandMenus.enumMsg THEN
			WITH msg: vyCommandMenus.enumMsg DO
				antsViews.Handler( layer, msg );
				IF layer.E # NIL THEN layer.E.handle( layer.E, msg ) END
			END;
		ELSE antsViews.Handler( layer, msg )
		END;
		IF ~done THEN END
	END Handler;

	PROCEDURE StoreAsGIF;
	VAR name, prefix, suffix: ARRAY 256 OF CHAR;
		F: Files.File;  R: Files.Rider;  tempLayer: tLayer;
	BEGIN
		tempLayer := antsViews.tempLayer( tLayer );

		COPY( "GIF", suffix );  COPY( "FromViewer", prefix );  antsToolbox.MakefileName( prefix, suffix, name );  F := Files.New( name );
		IF F = NIL THEN aM.SS( "Could not write to", name );  RETURN END;
		Files.Set( R, F, 0 );  antsToolbox.StoreImageAsGIF( tempLayer.E.img, R );
		(*
	vyPort.StorePictAsGIF(f, R);
	INSERT DisplayGrabbing and Storing here.
	*)
		Files.Register( F );  Files.Close( F );  aM.SS( "Picture stored as", name )
	END StoreAsGIF;

	PROCEDURE Init( layer: tLayer );
	BEGIN
		antsViews.Init( layer );  Attributes.SetBool( layer, "preview", FALSE );  layer.handle := Handler;
		vyCommandMenus.Add( layer.commands, StoreAsGIF, "Store" );  vyCommandMenus.Add( layer.commands, Center, "Center" )
	END Init;

	PROCEDURE Open*( layer: tLayer;  E: antsArrayImages.tObject );
	VAR id: vyName.tNameArray;
	BEGIN
		Init( layer );  id := "ViewI:";  vyName.AppendObjId( E, id );  vyPort.OpenLayer( layer, id );  layer.E := E;
		IF E.A # NIL THEN
			layer.pal.first := 0;  layer.pal.last := SHORT( E.A.depth - 1 );  antsViews.DefaultPath( layer, texture );  texture := FALSE
		END;
		vyBase.Subscribe( layer.E, layer )
	END Open;

	PROCEDURE New*;
	BEGIN
		aM.cmd;  NEW( newlayer );  Init( newlayer );  Objects.NewObj := newlayer
	END New;

	PROCEDURE DoShow*( E: antsArrayImages.tObject;  add: BOOLEAN;  VAR c: antsPictCoordinate.tCoordinate ): tLayer;
	VAR port: vyPort.Frame;  picture: vyPort.Picture;  layer: tLayer;  w, h: SIGNED16;
	BEGIN
		NEW( layer );  Open( layer, E );
		IF c = NIL THEN NEW( c );  antsPictCoordinate.OpenC( c, 1, 1 ) END;
		IF ~add THEN
			w := SHORT( E.w );  h := SHORT( E.h );
			IF w > maxw THEN w := maxw END;
			IF h > maxh THEN h := maxh END;
			port := vyPort.XNewFrame( w + 2 * vyPort.Border, h + 2 * vyPort.Border );  port.W := (w + 2 * vyPort.Border);
			port.H := (h + 2 * vyPort.Border);  picture := vyPort.NewP( c );  picture.W := (w);  picture.H := (h);
			picture.backGround := vyGraphBase.dgrey;  vyPort.AddPicture( port, picture, 0, 0, 1, 1 )
		ELSE picture := vyPort.GetFocusPicture()
		END;
		layer.style.fcol := vyGraphBase.green;  layer.style.fillcol := vyGraphBase.red;  vyPort.AddLayer( picture, layer );
		IF ~add THEN vyHostTexts.InsertGadget( port ) END;
		RETURN layer
	END DoShow;

	PROCEDURE Show*;
	VAR l: antsCommands.tScanList;  obj, o: vyBase.Object;  la: tLayer;  name: vyName.tNameArray;  hor, ver, add: BOOLEAN;
		c: antsPictCoordinate.tCoordinate;
	BEGIN
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			hor := FALSE;  ver := FALSE;  add := antsCommands.FindKeyword( l, "add" );  obj := vyName.FindObj( name );  o := obj;
			IF antsCommands.FindKeyword( l, "texture" ) THEN texture := TRUE END;
			la := DoShow( o( antsArrayImages.tObject ), add, c )
		END
	END Show;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  editor: tLayer;  c: antsPictCoordinate.tCoordinate;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO editor := DoShow( data( antsArrayImages.tObject ), FALSE , c );  data := vyBase.NextParObj() END
	END ShowP;

BEGIN
	aM.launch;  maxw := Display.Width DIV 3;  maxh := Display.Height DIV 3;  texture := FALSE
END antsImageViews.
System.Free antsImageViews~

