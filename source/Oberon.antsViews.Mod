MODULE antsViews IN Oberon;   (* fof *)
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




IMPORT vyPort, Oberon, vyName, vyBase, Display, vyEvents, vyColorPalettes, antsObjects, antsArrayObjects,
	antsArrayPictures16, antsArrayImages16, antsArrayPictures, antsArrayImages, Files, aM := antsMessages, vyHostStrings,
	vyTracking, antsToolbox, vyHost, antsCommands, antsPictCoordinate, Objects, vyCommandMenus, Gadgets, vyLinks,
	vyGraphBase, ants3dArrayObjects, antsColors, ants1dArrayVectors;

TYPE

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		refArray*: antsArrayObjects.tINTEGERObject;
		commands*: vyCommandMenus.List;
		pal*: vyColorPalettes.Palette;
		grid-: BOOLEAN;
		preview: BOOLEAN
	END;

VAR
	tempLayer-: tLayer;

	PROCEDURE CheckColors*( l: tLayer;  depth: SIGNED32 );
	BEGIN
		IF depth > 256 THEN RETURN END;
		IF depth - 1 # l.pal.last THEN vyColorPalettes.ShiftPath( l.pal, 0, SHORT( depth - 1 ) ) END
	END CheckColors;

	PROCEDURE Recall( layer: tLayer );
	END Recall;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;
	BEGIN
		priority := vyEvents.PrioNone;
		IF ((event.gesture = vyEvents.EvtIdent) OR (event.gesture = vyEvents.EvtSelect)) THEN priority := vyEvents.PrioNormal END;
		IF event.priority < priority THEN event.responder := layer;  event.priority := priority END
	END Responsible;

	PROCEDURE incSize;
	BEGIN
		antsPictCoordinate.IncSize( antsPictCoordinate.tc );  vyBase.Update( tempLayer )
	END incSize;

	PROCEDURE decSize;
	BEGIN
		antsPictCoordinate.DecSize( antsPictCoordinate.tc );  vyBase.Update( tempLayer )
	END decSize;

	PROCEDURE Prompt( layer: tLayer;  VAR event: vyEvents.EventMsg );
	BEGIN
		tempLayer := layer;  antsToolbox.StartDisplayHelp( "command button: select command to execute" );  vyCommandMenus.Init( layer.commands, event.x, event.y );
		vyCommandMenus.Ask( layer );  vyCommandMenus.Execute( event.x, event.y );  antsToolbox.EndDisplayHelp
	END Prompt;

	PROCEDURE Select( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR x, y, dx, dy: SIGNED16;
		str: ARRAY 64 OF CHAR;
	BEGIN
		antsToolbox.StartDisplayHelp( "select button: Shows Coordinates under pointer" );  tempLayer := layer;
		antsPictCoordinate.GetXY( antsPictCoordinate.tc, event.x, event.y, x, y );  str := "";  vyHostStrings.Append( str, " x = " );
		vyHostStrings.AppendInt( x, 1, str );  vyHostStrings.Append( str, ", y = " );  vyHostStrings.AppendInt( y, 1, str );
		vyHostStrings.Append( str, " " );  vyTracking.FramedString( event.x, event.y, "Syntax10.Scn.Fnt", str, dx, dy );  antsToolbox.EndDisplayHelp
	END Select;

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		IF msg.id = Objects.load THEN
			Files.ReadInt( msg.R, version );  vyPort.LayerHandler( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.refArray := objsub( antsArrayObjects.tINTEGERObject ) END;
			Gadgets.ReadRef( msg.R, obj.lib, objsub );
			IF objsub # NIL THEN obj.pal := objsub( vyColorPalettes.Palette ) END;
			IF version > 0 THEN Files.ReadBool( msg.R, obj.grid ) END;
			IF version > 1 THEN Files.ReadBool( msg.R, obj.preview ) END
		ELSIF msg.id = Objects.store THEN
			Files.WriteInt( msg.R, 2 );  vyPort.LayerHandler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.refArray );
			Gadgets.WriteRef( msg.R, obj.lib, obj.pal );  Files.WriteBool( msg.R, obj.grid );  Files.WriteBool( msg.R, obj.preview )
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleFileMsg;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.enum THEN M.Enum( "grid" );  M.Enum( "preview" );  vyPort.LayerHandler( obj, M )
		ELSIF M.id = Objects.get THEN
			IF M.name = "grid" THEN M.class := Objects.Bool;  M.b := obj.grid;  M.res := 0
			ELSIF M.name = "preview" THEN M.class := Objects.Bool;  M.b := obj.preview;  M.res := 0
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.set THEN
			IF M.name = "grid" THEN
				IF M.class = Objects.Bool THEN obj.grid := M.b;  M.res := 0;  vyBase.Update( obj ) END
			ELSIF M.name = "preview" THEN
				IF M.class = Objects.Bool THEN obj.preview := M.b;  M.res := 0;  vyBase.Update( obj ) END
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	BEGIN
		IF (msg.id = Objects.enum) THEN vyPort.LayerHandler( obj, msg ) ELSE vyPort.LayerHandler( obj, msg ) END
	END HandleLinks;

	PROCEDURE View3d;
	VAR res: SIGNED16;
	BEGIN
		vyHost.CallWString( "ants3D.View3d", "", FALSE , res )
	END View3d;

	PROCEDURE exchange;
	VAR res: SIGNED16;
	BEGIN
		vyHost.CallWString( "antsLayerOps.Exchange", "", FALSE , res )
	END exchange;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR layer: tLayer;  done: BOOLEAN;
	BEGIN
		ASSERT ( o IS tLayer, 100 );
		layer := o( tLayer );  done := FALSE;
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO
				Recall( layer );  done := TRUE;
				IF ~layer.preview THEN antsPictCoordinate.tc.pictW := 0 END;
			END;
		ELSIF msg IS vyColorPalettes.NewColMsg THEN
			WITH msg: vyColorPalettes.NewColMsg DO vyColorPalettes.CopyPalette( msg.pal, layer.pal );
			END;
		ELSIF msg IS vyColorPalettes.GetColMsg THEN
			WITH msg: vyColorPalettes.GetColMsg DO msg.pal := layer.pal;
			END;
		ELSIF msg IS antsToolbox.GetCoordMsg THEN
			WITH msg: antsToolbox.GetCoordMsg DO
				IF msg.update = TRUE THEN vyBase.Update( layer ) END;
				vyGraphBase.PointToPoint2d( msg.x, msg.y, msg.xr, msg.yr );  msg.layer := layer;
			END;
		ELSIF msg IS vyBase.UpdateMessage THEN
			WITH msg: vyBase.UpdateMessage DO vyPort.LayerHandler( layer, msg );
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN Responsible( layer, msg ) ELSE
					IF msg.gesture = vyEvents.EvtIdent THEN Prompt( layer, msg )
					ELSIF msg.gesture = vyEvents.EvtSelect THEN Select( layer, msg )
					ELSE vyPort.LayerHandler( layer, msg )
					END
				END;
				done := TRUE
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO vyPort.LayerHandler( layer, msg )
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
				IF layer.lib # msg.lib THEN
					vyPort.LayerHandler( layer, msg );  antsObjects.Bind( layer, msg );  antsObjects.Bind( layer.refArray, msg );
					antsObjects.Bind( layer.pal, msg )
				END
			END;
		ELSIF msg IS vyCommandMenus.enumMsg THEN
			WITH msg: vyCommandMenus.enumMsg DO
				tempLayer := layer;  msg.EnumSender( "", NIL , layer );  msg.Enum( "toggle fixed coordinates", fix, layer );  msg.Enum( "toggle free coordinates", free, layer );
				msg.Enum( "toggle grid", grid, layer );  msg.Enum( "view colors", ColorView, layer );  msg.Enum( "exchange (!)", exchange, layer );
				IF (antsPictCoordinate.currentsel # NIL ) & (layer.refArray # NIL ) THEN msg.Enum( "view Selection 3D", View3d, layer ) END
			END;
		ELSE vyPort.LayerHandler( layer, msg )
		END;
		IF ~done THEN END
	END Handler;

	PROCEDURE ObjectView;
	VAR vylist: vyLinks.Link;
	BEGIN
		vyLinks.InsertObj( vylist, tempLayer );  vyBase.Show( vylist, 1, "antsObjectView" )
	END ObjectView;

	PROCEDURE ColorView;
	BEGIN
		antsColors.ShowPalette( tempLayer.pal )
	END ColorView;

	PROCEDURE TColorView;
	BEGIN
		antsColors.ShowTinyPalette( tempLayer.pal )
	END TColorView;

	PROCEDURE decalpha;
	BEGIN
		IF tempLayer.style.alpha > 1 THEN tempLayer.style.alpha := tempLayer.style.alpha * 2 DIV 3 END;
		vyBase.Update( tempLayer )
	END decalpha;

	PROCEDURE incalpha;
	BEGIN
		IF tempLayer.style.alpha < 255 THEN tempLayer.style.alpha := tempLayer.style.alpha * 3 DIV 2 END;
		IF tempLayer.style.alpha > 255 THEN tempLayer.style.alpha := 255 END;
		vyBase.Update( tempLayer )
	END incalpha;

	PROCEDURE fix*;
	BEGIN
		antsPictCoordinate.tc.fixed := ~antsPictCoordinate.tc.fixed;
		IF tempLayer # NIL THEN vyBase.Update( tempLayer ) END
	END fix;

	PROCEDURE free*;
	BEGIN
		antsPictCoordinate.tc.free := ~antsPictCoordinate.tc.free;
		IF tempLayer # NIL THEN vyBase.Update( tempLayer ) END
	END free;

	PROCEDURE grid;
	BEGIN
		tempLayer.grid := ~tempLayer.grid;  vyBase.Update( tempLayer )
	END grid;

	PROCEDURE prev;
	BEGIN
		tempLayer.preview := ~tempLayer.preview
	END prev;

	PROCEDURE Init*( layer: tLayer );
	BEGIN
		IF layer.handle = NIL THEN layer.handle := Handler END;
		layer.commands := NIL;  vyCommandMenus.Add( layer.commands, incalpha, "inc alpha" );
		vyCommandMenus.Add( layer.commands, decalpha, "dec alpha" );  vyCommandMenus.Add( layer.commands, ObjectView, "Object Viewer" );
		vyCommandMenus.Add( layer.commands, ColorView, "View Colors" );  vyCommandMenus.Add( layer.commands, TColorView, "Colors" );
		vyCommandMenus.Add( layer.commands, fix, "Fixed Boundary" );  vyCommandMenus.Add( layer.commands, free, "Toggle FreeCoord" );
		vyCommandMenus.Add( layer.commands, prev, "Toggle Preview" );  vyCommandMenus.Add( layer.commands, grid, "grid" );
		vyCommandMenus.Add( layer.commands, incSize, "incSize" );  vyCommandMenus.Add( layer.commands, decSize, "decSize" );
		NEW( layer.pal );  vyColorPalettes.InitPalette( layer.pal );  vyBase.Subscribe( layer.pal, layer );  layer.grid := FALSE;
		layer.style.fcol := vyGraphBase.green;  layer.style.fillcol := vyGraphBase.red;
		layer.style.selectcol := vyGraphBase.black;  layer.preview := TRUE
	END Init;

	PROCEDURE DefaultPath*( layer: tLayer;  textureplot: BOOLEAN );
	BEGIN
		IF textureplot THEN vyColorPalettes.DefaultPath2( layer.pal ) ELSE vyColorPalettes.DefaultPath( layer.pal ) END
	END DefaultPath;

	PROCEDURE Open*( layer: tLayer;  id: vyName.tNameArray );
	VAR
	BEGIN
		Init( layer );  vyPort.OpenLayer( layer, id )
	END Open;

	PROCEDURE DoShowI*( a: antsArrayObjects.tINTEGERArray;  depth: SIGNED32 );
	VAR A: antsArrayObjects.tINTEGERObject;  a16o: antsArrayPictures16.tObject;  ao: antsArrayPictures.tObject;
	BEGIN
		A := antsArrayObjects.NewINTEGERObject( LEN( a[0] ), LEN( a ), depth );  antsArrayObjects.SetInt( A, a );
		IF depth > 255 THEN antsArrayPictures16.DoShow( A, a16o ) ELSE antsArrayPictures.DoShow( A, ao ) END
	END DoShowI;

	PROCEDURE DoShowR*( a: antsArrayObjects.tLONGREALArray;  depth: SIGNED32 );
	VAR A: antsArrayObjects.tINTEGERObject;  a16o: antsArrayPictures16.tObject;  ao: antsArrayPictures.tObject;
	BEGIN
		A := antsArrayObjects.NewINTEGERObject( LEN( a[0] ), LEN( a ), depth );  antsArrayObjects.SetLongreal( A, a );
		IF depth > 255 THEN antsArrayPictures16.DoShow( A, a16o ) ELSE antsArrayPictures.DoShow( A, ao ) END
	END DoShowR;

	PROCEDURE DoShow*( obj: vyBase.Object );
	VAR res: SIGNED16;
	BEGIN
		IF obj IS antsArrayObjects.tObject THEN
			WITH obj: antsArrayObjects.tObject DO Oberon.Call( "antsArrayViews.Show", Oberon.Par, FALSE , res );
			END;
		ELSIF obj IS antsArrayPictures.tObject THEN
			WITH obj: antsArrayPictures.tObject DO Oberon.Call( "antsPictureViews.Show", Oberon.Par, FALSE , res );
			END;
		ELSIF obj IS antsArrayImages.tObject THEN
			WITH obj: antsArrayImages.tObject DO Oberon.Call( "antsImageViews.Show", Oberon.Par, FALSE , res )
			END;
		ELSE aM.S( "not the right type, try using Voyager.Show .. as antsViews " )
		END
	END DoShow;

	PROCEDURE Show*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN DoShow( obj ) END
	END Show;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  link: vyLinks.Link;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO
			(* call one of antsImageViews antsPictureViews or antsArrayViews *)
			link := NIL;  vyLinks.InsertObj( link, data );
			IF data IS antsArrayObjects.tObject THEN
				WITH data: antsArrayObjects.tObject DO vyBase.Show( link, 1, "antsArrayViews" );
				END;
			ELSIF data IS antsArrayPictures.tObject THEN
				WITH data: antsArrayPictures.tObject DO vyBase.Show( link, 1, "antsPictureViews" );
				END;
			ELSIF data IS antsArrayPictures16.tObject THEN
				WITH data: antsArrayPictures16.tObject DO vyBase.Show( link, 1, "antsPictureViews" );
				END;
			ELSIF data IS antsArrayImages16.tObject THEN
				WITH data: antsArrayImages16.tObject DO vyBase.Show( link, 1, "antsImageViews" );
				END;
			ELSIF data IS antsArrayImages.tObject THEN
				WITH data: antsArrayImages.tObject DO vyBase.Show( link, 1, "antsImageViews" );
				END;
			ELSIF data IS ants1dArrayVectors.tObject THEN
				WITH data: ants1dArrayVectors.tObject DO link := NIL;  vyLinks.InsertObj( link, data.vec );  vyBase.Show( link, 1, "antsPointPlot" );
				END;
			ELSIF data IS ants3dArrayObjects.tObject THEN
				WITH data: ants3dArrayObjects.tObject DO vyBase.Show( link, 1, "ants3dArrayViews" )
				END;
			END;
			data := vyBase.NextParObj()
		END
	END ShowP;

BEGIN
	aM.launch;
END antsViews.
