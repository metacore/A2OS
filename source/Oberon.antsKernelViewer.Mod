MODULE antsKernelViewer IN Oberon;
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




IMPORT antsKernel, antsObjects, vyPort, Files, Gadgets, vyGraphBase, vyEvents, Display, Objects, vyBase, vyName,
	vyDisplay2d, Attributes, vyLinks, vyRectangles, aM := antsMessages;

TYPE

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		kernel: antsKernel.Kernel
	END;

	Real = LONGREAL;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Recall( layer: tLayer;  msg: Display.DisplayMsg );
	VAR y: INTEGER;  hp: vyPort.Picture;
		name: ARRAY 64 OF CHAR;
		kernel: antsKernel.Kernel;  l: vyLinks.Link;
	BEGIN
		kernel := layer.kernel;  hp := msg.dlink( vyPort.Picture );  Attributes.GetString( kernel.A, "Name", name );
		vyGraphBase.String2d( 0, 0, "", name );
		(*Attributes.GetString(kernel.Aorig,"Name",name);
	vyGraphBase.String2d(0,-1,"",name); *)
		Attributes.GetString( kernel.par, "Name", name );  vyGraphBase.String2d( 0, -2, "", name );  l := kernel.ModelClass;  y := -3;
		WHILE (l # NIL ) DO
			Attributes.GetString( l.obj, "Name", name );
			IF antsKernel.ModelActive IN l.flags THEN vyGraphBase.SetForeColor( layer.style.selectcol )
			ELSE vyGraphBase.SetForeColor( layer.style.fillcol )
			END;
			vyGraphBase.String2d( 0, y, "", name );  DEC( y );  l := l.link
		END

		(*
	vyPort.GetPictureScreenRegion (hp, x, y, w, h)
	*)
	END Recall;

	PROCEDURE StoreL( VAR R: Files.Rider;  L: tLayer );
	BEGIN
		Files.WriteInt( R, 0 );  Gadgets.WriteRef( R, L.lib, L.kernel )
	END StoreL;

	PROCEDURE LoadL( VAR R: Files.Rider;  n: tLayer );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Gadgets.ReadRef( R, n.lib, objsub );
		IF objsub # NIL THEN n.kernel := objsub( antsKernel.Kernel ) END
	END LoadL;

	PROCEDURE Respond( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR x2d, y2d: Real;
	BEGIN
		vyGraphBase.PointToPoint2d( event.x, event.y, x2d, y2d )
	END Respond;

	PROCEDURE Select( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR x2d, y2d: Real;  yy, x, y, w, h, dsr: INTEGER;  l: vyLinks.Link;
		name: ARRAY 64 OF CHAR;
	BEGIN
		vyGraphBase.PointToPoint2d( event.x, event.y, x2d, y2d );  yy := -3;  l := layer.kernel.ModelClass;
		WHILE (l # NIL ) DO
			Attributes.GetString( l.obj, "Name", name );  vyGraphBase.GetStringFrame2d( 0, yy, "", name, x, y, w, h, dsr );
			IF vyRectangles.PointInRect( event.x, event.y, x, y, w, h + dsr ) THEN
				antsKernel.DoAttachModel( layer.kernel, l.obj( vyBase.Object ) );  vyBase.Update( layer )
			END;
			DEC( yy );  l := l.link
		END
	END Select;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtSelect) OR (event.gesture = vyEvents.EvtIdent) THEN priority := vyEvents.PrioHigh END;
		IF event.priority < priority THEN event.responder := layer;  event.priority := priority END
	END Responsible;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR layer, copy: tLayer;  done: BOOLEAN;
	BEGIN
		layer := o( tLayer );  done := FALSE;
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( layer, msg );  done := TRUE
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN Responsible( layer, msg ) ELSE
					IF msg.gesture = vyEvents.EvtSelect THEN Select( layer, msg )
					ELSIF msg.gesture = vyEvents.EvtIdent THEN Respond( layer, msg )
					END
				END;
				done := TRUE
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				NEW( copy );  msg.obj := copy;  vyPort.LayerHandler( layer, msg );  Copy( layer, msg.obj( tLayer ) );  done := TRUE
			END;
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN COPY( 'antKernelViewer.GenL', msg.s );  msg.class := Objects.String;  msg.res := 0 ELSE vyPort.LayerHandler( layer, msg ) END
				ELSE vyPort.LayerHandler( layer, msg )
				END;
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.load THEN vyPort.LayerHandler( layer, msg );  LoadL( msg.R, layer )
				ELSIF msg.id = Objects.store THEN vyPort.LayerHandler( layer, msg );  StoreL( msg.R, layer )
				END;
			END;
		ELSIF msg IS Objects.BindMsg THEN
			WITH msg: Objects.BindMsg DO
				IF layer.lib # msg.lib THEN vyPort.LayerHandler( layer, msg );  antsObjects.Bind( layer.kernel, msg ) END;
				done := TRUE
			END;
		ELSE
		END;   (*WITH*)
		IF (~done) THEN vyPort.LayerHandler( layer, msg ) END  (* of ~done *)
	END Handler;

	PROCEDURE GenL*;
	VAR L: tLayer;
	BEGIN
		aM.cmd;  NEW( L );  L.handle := Handler;  Objects.NewObj := L
	END GenL;

	PROCEDURE Open( layer: tLayer;  kernel: antsKernel.Kernel );
	VAR id: vyName.tNameArray;
	BEGIN
		id := "kernelv:";  vyName.AppendObjId( kernel, id );  vyPort.OpenLayer( layer, id );  layer.kernel := kernel;
		layer.style.fcol := vyGraphBase.black;  layer.style.fillcol := vyGraphBase.green;
		layer.style.selectcol := vyGraphBase.dkgreen;  layer.handle := Handler
	END Open;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  layer: tLayer;  c: vyDisplay2d.tCoordinate2d;  pict: vyPort.Picture;  x, y, w, h: Real;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO
			NEW( layer );  Open( layer, data( antsKernel.Kernel ) );  x := 0;  y := 0;  w := 1;  h := 1;  NEW( c );
			vyDisplay2d.OpenC2d( c, x - 1, y - 1, w + 2, h + 2 );  pict := vyPort.XNewCPicture( 0, 0, 1, 1, c );
			pict.backGround := vyGraphBase.dgrey;  vyPort.AddLayer( pict, layer );  vyPort.Write( pict );
			data := vyBase.NextParObj()
		END
	END ShowP;

BEGIN
	aM.launch;
END antsKernelViewer.

Voyager.Show f3Kernel as antsKernelViewer ~
System.Free antsKernelViewer ~



