MODULE vySurface IN Oberon;
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
(c) M. Diller, StatLab Heidelberg
*)

(*=  surface plot *)

(*	history:
10.8.95 md 0.0a1	alpha version
16.2.95 md 0.0d3	Dumpvector removed
26.1.95 md 0.0d2	cleaned
12.12.94 md 0.0d0	created *)

IMPORT Objects, Display, vyLinks, vyParser, vyHostDisplay := vyGraphBase, vyHostStrings, antsColors := vyColorPalettes,
	antsCommandList := vyCommandMenus, Files, Gadgets, vyBase, vyName, vyHost, vyRealVec, vyPort, vyPolyWorld,
	vyLayers3d
	, vyPHIGS3D, vyPaint3d, vyAxis (* just for the scales*)
	, vyEvents;

CONST
	idversion* = 'vySurfacePlot v0r0a2';

TYPE
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyLayers3d.tLayerDesc)
		m: vyRealVec.tChunkedMatrix;
		pal: antsColors.Palette;
		sp: vyPolyWorld.tObject;
		axisx0, axisx1, axisxstep: REAL;
		axisy0, axisy1, axisystep: REAL;
		axisz0, axisz1, axiszstep: REAL;
		commands*: antsCommandList.List;
		lines: BOOLEAN;
	END;
VAR
	tempLayer: tLayer;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Recall( surface: tLayer );
	(*VAR err, x0, y0, xx, yx, xy, yy, xz, yz: INTEGER;*)
	VAR lines: BOOLEAN;

		PROCEDURE Scale;
		(** vs 0.0d0 *)  (* md  24.08.95 14:06:04 *)
		VAR err, x0, y0, xx, yx, xy, yy, xz, yz: INTEGER;
		BEGIN
			vyAxis.SetColors( surface.style.fillcol, surface.style.fillcol, surface.style.fillcol );
			vyPHIGS3D.PointToDisplayPoint( 0, 0, 0, err, x0, y0 );  vyPHIGS3D.PointToDisplayPoint( 1, 0, 0, err, xx, yx );
			vyPHIGS3D.PointToDisplayPoint( 0, 1, 0, err, xy, yy );  vyPHIGS3D.PointToDisplayPoint( 0, 0, 1, err, xz, yz );
			vyAxis.ForcePlot( x0, y0, xx, yx, surface.axisx0, surface.axisx1, surface.axisxstep );
			vyAxis.ForcePlot( x0, y0, xy, yy, surface.axisy0, surface.axisy1, surface.axisystep );
			vyAxis.ForcePlot( x0, y0, xz, yz, surface.axisz0, surface.axisz1, surface.axiszstep );

			vyHostDisplay.SetStringJustification( vyHostDisplay.center, vyHostDisplay.center );  vyPaint3d.String( 0, 1.05, 0, "Syntax14b.Scn.Fnt", "y" );
			vyPaint3d.String( 1.05, 0, 0, "Syntax14b.Scn.Fnt", "x" );  vyPaint3d.String( 0, 0, 1.05, "Syntax14b.Scn.Fnt", "z" )
		END Scale;

	BEGIN
		Scale;  vyHostDisplay.SetStyle( surface.style );  vyPolyWorld.SetColorMap( surface.pal.dcol );  lines := surface.lines;
		vyPolyWorld.SetLines( lines );  surface.sp.plot( surface.sp );  vyPolyWorld.SetLines( lines );
	END Recall;

	PROCEDURE Responsible( surface: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtIdent) THEN priority := vyEvents.PrioNormal END;

		IF event.priority < priority THEN event.responder := surface;  event.priority := priority
		END
	END Responsible;

	PROCEDURE Prompt( layer: tLayer;  VAR event: vyEvents.EventMsg );
	BEGIN
		tempLayer := layer;  antsCommandList.Init( layer.commands, event.x, event.y );  antsCommandList.Ask( layer );
		antsCommandList.Execute( event.x, event.y )
	END Prompt;

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyPort.LayerHandler( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.m := objsub( vyRealVec.tChunkedMatrix ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.pal := objsub( antsColors.Palette ) END;
			vyPolyWorld.LoadObj( msg.R, obj.lib, obj.sp );  Files.ReadReal( msg.R, obj.axisx0 );
			Files.ReadReal( msg.R, obj.axisx1 );  Files.ReadReal( msg.R, obj.axisxstep );  Files.ReadReal( msg.R, obj.axisy0 );
			Files.ReadReal( msg.R, obj.axisy1 );  Files.ReadReal( msg.R, obj.axisystep );  Files.ReadReal( msg.R, obj.axisz0 );
			Files.ReadReal( msg.R, obj.axisz1 );  Files.ReadReal( msg.R, obj.axiszstep );
			IF version > 0 THEN Files.ReadBool( msg.R, obj.lines );  END;
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 1 );  vyPort.LayerHandler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.m );
			Gadgets.WriteRef( msg.R, obj.lib, obj.pal );  vyPolyWorld.StoreObj( msg.R, obj.lib, obj.sp );
			Files.WriteReal( msg.R, obj.axisx0 );  Files.WriteReal( msg.R, obj.axisx1 );  Files.WriteReal( msg.R, obj.axisxstep );
			Files.WriteReal( msg.R, obj.axisy0 );  Files.WriteReal( msg.R, obj.axisy1 );  Files.WriteReal( msg.R, obj.axisystep );
			Files.WriteReal( msg.R, obj.axisz0 );  Files.WriteReal( msg.R, obj.axisz1 );  Files.WriteReal( msg.R, obj.axiszstep );
			Files.WriteBool( msg.R, obj.lines );
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE ColorView;
	VAR res: INTEGER;
	BEGIN
		antsColors.current := tempLayer.pal;  vyHost.CallWString( "antsColors.ShowCurrent", "", FALSE , res )
	END ColorView;

	PROCEDURE wireFrame;
	BEGIN
		DoSetRendering( tempLayer, vyPolyWorld.wireFrameId );  vyBase.Update( tempLayer )
	END wireFrame;

	PROCEDURE niveauline;
	BEGIN
		DoSetRendering( tempLayer, vyPolyWorld.niveauLineId );  vyBase.Update( tempLayer )
	END niveauline;

	PROCEDURE smoothlighting;
	BEGIN
		DoSetRendering( tempLayer, vyPolyWorld.smoothLightingId );  vyBase.Update( tempLayer )
	END smoothlighting;

	PROCEDURE lighting;
	BEGIN
		DoSetRendering( tempLayer, vyPolyWorld.lightingId );  vyBase.Update( tempLayer )
	END lighting;

	PROCEDURE painter;
	BEGIN
		DoSetRendering( tempLayer, vyPolyWorld.painterId );  vyBase.Update( tempLayer )
	END painter;

	PROCEDURE niveau;
	BEGIN
		DoSetRendering( tempLayer, vyPolyWorld.niveauColoringId );  vyBase.Update( tempLayer )
	END niveau;

	PROCEDURE lines;
	BEGIN
		tempLayer.lines := ~tempLayer.lines;
	END lines;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN vyPort.LayerHandler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vySurface.Alloc', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END
		ELSIF M.id = Objects.set THEN vyPort.LayerHandler( obj, M )
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN vyPort.LayerHandler( obj, msg ) ELSE vyPort.LayerHandler( obj, msg ) END
	END HandleLinks;

	PROCEDURE Bind( obj: Objects.Object;  VAR msg: Objects.BindMsg );   (* 020625 fof, procedure from ANTS  *)
	BEGIN
		IF (obj # NIL ) & (msg.lib # obj.lib) THEN
			(* Gadgets.BindObj(obj,msg.lib); *)
			IF obj.handle # NIL THEN obj.handle( obj, msg )
			ELSE
				Gadgets.BindObj( obj, msg.lib );   (*!!! fof 010419 changed !! *)
			END;
			obj.lib := msg.lib
		END
	END Bind;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  08.08.94 *)
	VAR surface, copy: tLayer;  done: BOOLEAN;
	BEGIN
		surface := o( tLayer );  done := FALSE;

		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( surface );  done := TRUE
			END;
		ELSIF msg IS antsColors.NewColMsg THEN
			WITH msg: antsColors.NewColMsg DO antsColors.CopyPalette( msg.pal, surface.pal );
			END;
		ELSIF msg IS antsColors.GetColMsg THEN
			WITH msg: antsColors.GetColMsg DO msg.pal := surface.pal;
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO HandleFileMsg( surface, msg )
			END;
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO HandleAttributes( surface, msg )
			END;
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO HandleLinks( surface, msg )
			END;
		ELSIF msg IS Objects.BindMsg THEN
			WITH msg: Objects.BindMsg DO
				IF surface.lib # msg.lib THEN
					vyPort.LayerHandler( surface, msg );  Bind( surface, msg );  Bind( surface.m, msg );  Bind( surface.pal, msg )
				END
			END;
		ELSIF msg IS antsCommandList.enumMsg THEN
			WITH msg: antsCommandList.enumMsg DO
				tempLayer := surface;  msg.EnumSender( "", NIL , surface );  msg.Enum( "View Colors", ColorView, surface );
				msg.Enum( "-------------------------------", NIL , surface );  msg.Enum( "render:wireFrame", wireFrame, surface );  msg.Enum( "niveauLinue", niveauline, surface );
				msg.Enum( "render:painter", painter, surface );  msg.Enum( "render:lighting", lighting, surface );  msg.Enum( "render:smoothlighting", smoothlighting, surface );
				msg.Enum( "render:niveauColoring", niveau, surface );  msg.Enum( "render:toggle lines", lines, surface );

			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN Responsible( surface, msg ) ELSE
					IF msg.gesture = vyEvents.EvtIdent THEN Prompt( surface, msg ) END
				END;
				done := TRUE
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				NEW( copy );  msg.obj := copy;  vyLayers3d.Handler( surface, msg );  Copy( surface, msg.obj( tLayer ) );  done := TRUE
			END;
		ELSE vyLayers3d.Handler( surface, msg )
		END

	END Handler;

	PROCEDURE Open*( surface: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;

		PROCEDURE CheckedData( item: Objects.Object ): vyRealVec.tChunkedMatrix;
		(** vs 0.0d0 *)  (* md  08.06.95 16:57:02 *)
		VAR ref: Objects.Object;
		BEGIN
			IF item = NIL THEN
				ASSERT ( item # NIL )
			ELSE ref := item
			END;
			IF ~(ref IS vyRealVec.tChunkedMatrix) THEN RETURN NIL ELSE RETURN ref( vyRealVec.tChunkedMatrix ) END

		END CheckedData;

	BEGIN
		surface.m := CheckedData( data );  id := 'surface: ';  vyName.AppendObjId( surface.m, id );  vyLayers3d.Open( surface, id );
		surface.sp := vyPolyWorld.OpenMap( 0, 0, 1, 1, surface.m );  surface.handle := Handler;  surface.axisx0 := 0;
		surface.axisx1 := 1;  surface.axisxstep := 0.1;  surface.axisy0 := 0;  surface.axisy1 := 1;  surface.axisystep := 0.1;
		surface.axisz0 := 0;  surface.axisz1 := 1;  surface.axiszstep := 0.1;  vyBase.Subscribe( (*for messages from source*) surface.m,
																																															 surface )
	END Open;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  surface: tLayer;  c: vyLayers3d.tCoordinate3d;
	BEGIN
		data := vyBase.NextParObj();
		WHILE data # NIL DO
			Alloc;  surface := Objects.NewObj( tLayer );  Open( surface, data );  NEW( c );  vyLayers3d.OpenC3d( c );
			(*	pict := vyPort.NewCPicture (0, 0, 1, 1, c);*)
			vyPort.AddLayer( vyPort.InsertNewCPicture( 0, 0, 1, 1, c ), surface );

			data := vyBase.NextParObj()
		END
	END ShowP;

	PROCEDURE New*;
	VAR layer: tLayer;  data: Objects.Object;
	BEGIN
		IF Objects.NewObj = NIL THEN RETURN END;
		data := Objects.NewObj;  Alloc;  layer := Objects.NewObj( tLayer );  Open( layer, data );  Objects.NewObj := layer
	END New;

	PROCEDURE Alloc*;
	VAR layer: tLayer;
	BEGIN
		NEW( layer );  layer.handle := Handler;  Objects.NewObj := layer;  layer.lines := TRUE;  NEW( layer.pal );
		antsColors.InitPalette( layer.pal );
		antsColors.RGBPath( layer.pal, 0, 255, 0, 0, 0, 1, 1, 1 (* 166 / 255, 203 / 255, 243 / 255 *) );
		vyBase.Subscribe( layer.pal, layer )

	END Alloc;

	PROCEDURE DoSetRendering*( surface: tLayer;  renderId: INTEGER );
	BEGIN
		vyPolyWorld.SetRendering( surface.sp, renderId );
		(*vyPort.PictureUpdate (vyPort.HostPicture (surface))*)  (*? use broadcast??*)
	END DoSetRendering;

	PROCEDURE SetRendering*;
	VAR layer: Objects.Object;  sc: vyParser.Scanner;
		id: ARRAY 32 OF CHAR;
		HLHSRidentifier: INTEGER;
	BEGIN
		(*layer := vyPort.GetFrontMostLayer (vyPort.GetFocusPicture1 ());*)
		layer := vyLinks.GetLastObj( vyPort.focusPicture.vylinks );

		vyParser.OpenParScanner( sc );
		IF vyParser.Name( sc, id ) THEN
			IF vyHostStrings.Equal( id, "wireFrame" ) THEN HLHSRidentifier := vyPolyWorld.wireFrameId
			ELSIF vyHostStrings.Equal( id, "niveauLine" ) THEN HLHSRidentifier := vyPolyWorld.niveauLineId
			ELSIF vyHostStrings.Equal( id, "backFaceColoring" ) THEN HLHSRidentifier := vyPolyWorld.backFaceColoringId
			ELSIF vyHostStrings.Equal( id, "painter" ) THEN HLHSRidentifier := vyPolyWorld.painterId
			ELSIF vyHostStrings.Equal( id, "lighting" ) THEN HLHSRidentifier := vyPolyWorld.lightingId
			ELSIF vyHostStrings.Equal( id, "smoothLighting" ) THEN HLHSRidentifier := vyPolyWorld.smoothLightingId
			ELSIF vyHostStrings.Equal( id, "hiddenLine" ) THEN HLHSRidentifier := vyPolyWorld.hiddenLineId
			ELSIF vyHostStrings.Equal( id, "niveauColoring" ) THEN HLHSRidentifier := vyPolyWorld.niveauColoringId
			END
		ELSE
		END;

		IF ~(layer IS tLayer) THEN vyPolyWorld.SetHLHSRIdentifier( HLHSRidentifier )
		ELSE DoSetRendering( layer( tLayer ), HLHSRidentifier )
		END
	END SetRendering;

	PROCEDURE SetAxis*;
	VAR layer: Objects.Object;  sc: vyParser.Scanner;  l: tLayer;
	BEGIN
		layer := vyLinks.GetLastObj( vyPort.focusPicture.vylinks );  l := layer( tLayer );  vyParser.OpenParScanner( sc );
		IF vyParser.ExpectReal( sc, l.axisx0 ) & vyParser.ExpectReal( sc, l.axisx1 ) & vyParser.ExpectReal( sc, l.axisxstep ) &
		    vyParser.ExpectReal( sc, l.axisy0 ) & vyParser.ExpectReal( sc, l.axisy1 ) & vyParser.ExpectReal( sc, l.axisystep ) &
		    vyParser.ExpectReal( sc, l.axisz0 ) & vyParser.ExpectReal( sc, l.axisz1 ) & vyParser.ExpectReal( sc, l.axiszstep ) THEN
			vyPort.PictureUpdate( vyPort.GetFocusPicture() )
		END
	END SetAxis;

END vySurface.