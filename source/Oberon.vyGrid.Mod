MODULE vyGrid IN Oberon;   (*vs 0.0a1 md   09.08.95 *)
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
(*=	Contents: displays a equidistance horizontal and vertical grid in a picture *)
(*	history:
9.8.95 md 0.0a1	alpha version
9.6.95 md 0.0d5	renamed: Lattice -> Grid and adapted to the new graphic definitions
26.1.95 md 0.0d4	cleaned
27.10.94 md 0.0d3	adaped to the renamed vyGraphBase
27.07.94	md	0.1d1	created *)
IMPORT Files, Objects, Display, vyHostTexts, vyBase, vyName, vyGraphBase, vyPort, vyParser, vyEvents;

CONST
	idversion* = "vyGrid v0r0a2";  Syntax = "Lattice.Insert <x0> <y0> <dx> <dy>";

TYPE
	Real = vyBase.Real;
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc)
		x0, y0, dx, dy: Real
	END;

VAR
	slink*, dlink*: Objects.Object;  newlayer-: tLayer;

(*PROCEDURE^ Alloc*;*)

	PROCEDURE Setparameter( grid: tLayer;  x0, y0, dx, dy: Real );
	BEGIN
		grid.x0 := x0;  grid.y0 := y0;  grid.dx := dx;  grid.dy := dy
	END Setparameter;

	PROCEDURE Recall( grid: tLayer;  VAR msg: Objects.ObjMsg );
	VAR x2d, y2d, w2d, h2d, x0, y0, dx, dy: Real;  x, y, w, h, i: SIGNED16;
	BEGIN
		IF (grid.dx # 0) & (grid.dy # 0) THEN
			vyPort.GetPictureScreenRegion( msg.dlink( vyPort.Picture ), x, y, w, h );
			vyGraphBase.PointToPoint2d( x, y, x2d, y2d );  vyGraphBase.PointToPoint2d( x + w, y + h, w2d, h2d );
			w2d := w2d - x2d;  h2d := h2d - y2d;

			grid.x0 := grid.x0 - ENTIER( (grid.x0 - x2d) / grid.dx ) * grid.dx;  grid.y0 := grid.y0 - ENTIER( (grid.y0 - y2d) / grid.dy ) * grid.dy;

			x0 := grid.x0;  dx := grid.dx;  i := 0;
			(*	WHILE x0+i*dx < x+w DO
		vyGraphBase.Line2d (x0+i*dx, y2d, x0+i*dx, y2d+h2d); INC (i);
		END;

		y0 := grid.y0; dy := grid.dy;
		i := 0;
		WHILE y0+i*dy <= y+h DO
		vyGraphBase.Line2d (x2d, y0+i*dy, x2d+w2d, y0+i*dy); INC (i);
		END;
		*)
			ASSERT ( dx # 0 );
			WHILE i * dx < w2d DO  (*changed by fof*)
				vyGraphBase.Line2d( x0 + i * dx, y2d, x0 + i * dx, y2d + h2d );  INC( i )
			END;

			y0 := grid.y0;  dy := grid.dy;  i := 0;
			ASSERT ( dy # 0 );
			WHILE i * dy <= h2d DO  (* changed by fof*)
				vyGraphBase.Line2d( x2d, y0 + i * dy, x2d + w2d, y0 + i * dy );  INC( i )
			END
		END
	END Recall;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Respond( grid: tLayer;  VAR event: vyEvents.EventMsg );
	VAR pict: vyPort.Picture;  x2d, y2d, x, y, dx, dy: Real;
	BEGIN
		pict := event.dlink( vyPort.Picture );  x := grid.x0;  y := grid.y0;  dx := grid.dx;  dy := grid.dy;
		vyGraphBase.SetDisplayMode( vyGraphBase.invert );  vyGraphBase.FrameRect2d( x, y, dx, dy );
		WHILE event.gesture = vyEvents.EvtIdent DO
			vyGraphBase.PointToPoint2d( event.x, event.y, x2d, y2d );
			IF (ABS( x2d - x ) >= dx / 4) OR (ABS( y2d - y ) >= dy / 4) THEN
				vyGraphBase.FrameRect2d( x, y, dx, dy );
				IF x2d - x < 0 THEN x := x - dx / 4;  dx := dx + dx / 4 ELSE x := x + dx / 4;  dx := dx - dx / 4 END;
				IF y2d - y < 0 THEN y := y - dy / 4;  dy := dy + dy / 4 ELSE y := y + dy / 4;  dy := dy - dy / 4 END;
				vyGraphBase.FrameRect2d( x, y, dx, dy )
			END;
			vyEvents.GetEvent( event )
		END;
		vyGraphBase.FrameRect2d( x, y, dx, dy );

		IF (grid.x0 # x) OR (grid.y0 # y) OR (grid.dx # dx) OR (grid.dy # dy) THEN
			(*grid.x0 := x; grid.y0 := y; grid.dx := dx; grid.dy := dy;*)
			Setparameter( grid, x, y, dx, dy );  vyPort.PictureUpdate( pict )
		END
	END Respond;

	PROCEDURE Responsible( grid: tLayer;  VAR event: vyEvents.EventMsg );
	CONST toleranz = 4;
	VAR priority: SIGNED16;  x, y: SIGNED16;
	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtIdent) THEN
			vyGraphBase.Point2dToPoint( grid.x0, grid.y0, x, y );
			IF (ABS( x - event.x ) + ABS( y - event.y ) < toleranz) THEN priority := vyEvents.PrioHigh END
		END;
		IF event.priority < priority THEN event.responder := grid;  event.priority := priority END
	END Responsible;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyGrid.New', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteLReal( M.R, obj.x0 );  Files.WriteLReal( M.R, obj.y0 );  Files.WriteLReal( M.R, obj.dx );
		Files.WriteLReal( M.R, obj.dy )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		dlink := M.dlink;  Files.ReadLReal( M.R, obj.x0 );  Files.ReadLReal( M.R, obj.y0 );  Files.ReadLReal( M.R, obj.dx );
		Files.ReadLReal( M.R, obj.dy )
	END Load0;

	PROCEDURE New*;
	BEGIN
		NEW( newlayer );  Init( newlayer, 0, 0, 1, 10 );  Objects.NewObj := newlayer
	END New;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  20.07.94 *)
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj, msg );
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
				(*Alloc; copy := Objects.NewObj(tLayer); msg.obj := copy;  vyPort.LayerHandler (obj, msg);
			Copy (obj, msg.obj(tLayer));	*)
					New;  msg.obj := newlayer;  vyPort.LayerHandler( obj, msg );  Copy( obj, msg.obj( tLayer ) );
				END;
			ELSIF msg IS vyEvents.EventMsg THEN
				WITH msg: vyEvents.EventMsg DO
					IF msg.callForResponder THEN Responsible( obj, msg ) ELSE
						IF msg.gesture = vyEvents.EvtSelect THEN
						ELSIF msg.gesture = vyEvents.EvtIdent THEN Respond( obj, msg )
						END
					END
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN Load0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSIF msg.id = Objects.store THEN Store0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSE vyPort.LayerHandler( obj, msg )
					END;
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END
	END Handler;

(*PROCEDURE Init (F : tLayer);
BEGIN 	F.handle := Handler
END Init;*)

	PROCEDURE Init( F: tLayer;  x0, y0, dx, dy: FLOAT32 );
	VAR id: vyName.tNameArray;
	BEGIN
		F.handle := Handler;  COPY( "Grid: ", id );  vyPort.OpenLayer( F, id );  F.style.fcol := 12;
		(*F.x0 := x0;
	F.y0 := y0;
	F.dx := dx;
	F.dy := dy;*)
		Setparameter( F, x0, y0, dx, dy )
	END Init;

(*PROCEDURE Show*;
VAR data: Objects.Object;  F: tLayer;  count: SIGNED16;
pict: vyPort.Picture;
x0, y0, dx, dy : FLOAT32;
inconsistentConditions : BOOLEAN;
BEGIN
data := vyBase.showParameter; count := vyBase.parameterCount;
vyBase.showParameter := NIL;  vyBase.parameterCount := 0;
WITH data:  vyBase.tVector DO
IF (data.nrData # 4) OR (data = NIL) THEN
vyHostTexts.Msg ("can't plot this data as grid : need 4 variables!");
inconsistentConditions := TRUE; ASSERT (~inconsistentConditions)
END;
x0 := vyRealVec.Get(data,0); y0 := vyRealVec.Get(data,1);
dx := vyRealVec.Get(data,2); dy := vyRealVec.Get(data,3);
ELSE
END;
WHILE count >= 1 DO
NEW (F);  Init (F,x0, y0, dx, dy);
pict := vyPort.NewVecPicture (NIL,NIL);	(*should get coord. from picture*)
vyPort.AddLayer (pict, F);
DEC (count)
END;
Objects.NewObj := pict
END Show;*)

	PROCEDURE Insert*;
	VAR x0, y0, dx, dy: FLOAT32;  sc: vyParser.Scanner;
	BEGIN
		vyParser.OpenParScanner( sc );  x0 := 0;  y0 := 0;  dx := 1;  dy := 10;
		IF ~(vyParser.Real( sc, x0 ) & vyParser.Real( sc, y0 ) & vyParser.Real( sc, dx ) & vyParser.Real( sc, dy )) THEN
			vyHostTexts.Msg( Syntax );  RETURN
		END;
		(*NEW (grid); Init (grid, x0, y0, dx, dy);*)
		New;  Setparameter( newlayer, x0, y0, dx, dy );  vyPort.AddLayer( vyPort.GetFocusPicture(),  (*grid*) newlayer )
	END Insert;

(*PROCEDURE Alloc*;
VAR	layer : tLayer;
BEGIN NEW (layer); layer.handle := Handler;  Objects.NewObj := layer END Alloc;*)


END vyGrid.