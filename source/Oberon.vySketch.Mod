MODULE vySketch IN Oberon;
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

(*= 	drawing a sketch in a picture *)

(*	history:
9.8.95 md 0.0a1	alpha version
26.1.95 md 0.0d2	cleaned
27.10.94 md 0.0d1	removed from import list vyPaint & vyPictures
27.10.94 md 0.0d0	created *)

IMPORT Objects, Display, vyHostTexts, vyTypes, vyPort, vyGraphBase, vyCharts, vyName, vyEvents;

CONST
	idversion* = "vySketch v0r0a2";

TYPE
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyCharts.tLayerDesc)
		breaks: ARRAY 32 OF SIGNED32;
		nrOfBreaks: SIGNED16
	END;

	PROCEDURE Recall( sketch: tLayer );
	VAR x1, y1, x0, y0: FLOAT32;  break: SIGNED16;  i, from, to: SIGNED32;
	BEGIN
		FOR break := 1 TO sketch.nrOfBreaks DO
			from := sketch.breaks[break - 1];  to := sketch.breaks[break] - 1;  x0 := vyTypes.VGetR( sketch.x, from );
			y0 := vyTypes.VGetR( sketch.y, from );  vyGraphBase.MoveTo2d( x0, y0 );
			FOR i := from + 1 TO to DO
				x1 := vyTypes.VGetR( sketch.x, i );  y1 := vyTypes.VGetR( sketch.y, i );  vyGraphBase.LineTo2d( x1, y1 )
			END
		END
	END Recall;

	PROCEDURE Copy( src, dest: tLayer );
	VAR i: SIGNED16;
	BEGIN
		dest.nrOfBreaks := src.nrOfBreaks;  i := 0;
		WHILE (i < 32) DO dest.breaks[i] := src.breaks[i];  INC( i ) END
	END Copy;

	PROCEDURE Respond( sketch: tLayer;  VAR event: vyEvents.EventMsg );
	BEGIN
		vyCharts.Handler( sketch, event );  INC( sketch.nrOfBreaks );  sketch.breaks[sketch.nrOfBreaks] := sketch.x.nrData;
		(*vyPort.PictureUpdate (vyPort.Host (sketch))*)
	END Respond;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );   (*vs 0.0a1	md  20.07.94 *)
	VAR sketch, copy: tLayer;  done: BOOLEAN;
	BEGIN
		sketch := o( tLayer );  done := FALSE;

		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( sketch );  done := TRUE
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN
					IF sketch.nrOfBreaks = 32 THEN vyHostTexts.Msg( "Sketch full" );  done := TRUE END
				ELSE
					IF msg.gesture = vyEvents.EvtSelect THEN
					ELSIF msg.gesture = vyEvents.EvtIdent THEN Respond( sketch, msg )
					END;
					done := TRUE
				END;
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				NEW( copy );  msg.obj := copy;  vyCharts.Handler( sketch, msg );  Copy( sketch, msg.obj( tLayer ) );  done := TRUE
			END;
		ELSE
		END;

		IF ~done THEN vyCharts.Handler( sketch, msg )
		END
	END Handler;

	PROCEDURE Open( sketch: tLayer );
	VAR name: vyName.tNameArray;

	BEGIN
		name := "sketch";  vyCharts.OpenChart128( sketch, name );   (*vyCharts.OpenChart128 (sketch, "sketch");*)
		sketch.handle := Handler;  sketch.breaks[0] := 0;  sketch.nrOfBreaks := 0
	END Open;

	PROCEDURE New*;
	VAR layer: tLayer;
	BEGIN
		NEW( layer );  Open( layer );  Objects.NewObj := layer
	END New;

	PROCEDURE Insert*;
	VAR sketch: tLayer;
	BEGIN
		NEW( sketch );  Open( sketch );  vyPort.AddLayer( vyPort.GetFocusPicture(), sketch )
	END Insert;

	PROCEDURE Alloc*;
	VAR sketch: tLayer;
	BEGIN
		NEW( sketch );  sketch.handle := Handler;  Objects.NewObj := sketch
	END Alloc;

	PROCEDURE Clear*;
	(*! clear the sketch in the focus picture *)
	BEGIN
		vyHostTexts.Msg( "not yet implemented" )
	END Clear;

END vySketch.