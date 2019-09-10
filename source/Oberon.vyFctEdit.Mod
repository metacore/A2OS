MODULE vyFctEdit IN Oberon;
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


(* 		(c) Project Voyager, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
(c) F. Friedrich, StatLab Heidelberg
*)
(*= 	an editor for functions, given as a vector *)
(*		history:
10.8.95 md 0.0a1	alpha version
16.2.95 md 0.0d3	scales added
26.1.95 md 0.0d2	cleaned
27.10.94 md 0.0d1	adaped to the renamed vyHostDisplay & vyPictures
26.10.94 md 0.0d0	created *)

IMPORT Objects, Display, vyHostTexts, vyBase, vyGraphBase, vyRealVec, vyTypes, vyParser, vyName, vyRectangles,
	vyDisplay2d, Gadgets, vyPort, vyCharts, vyAxis, vyLongrealVec, vyEvents, Files;

CONST
	idversion* = "vyFunctionEdit v0r0a2";

TYPE
	Real = vyGraphBase.Real;  Color = vyGraphBase.Color;  Coordinate = vyGraphBase.Coordinate;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyCharts.tLayerDesc)
		ox: vyBase.Object;
		xr, yr, wr, hr: Real;   (* the region, the vector lifes in *)
		dx: Real;
		ticks: SIGNED32;
		hot: BOOLEAN;
		vScale, hScale: BOOLEAN
	END;
VAR
	hotColor, coolColor: Color;

	PROCEDURE Grid( editor: tLayer;  v, h: Coordinate );
	VAR dx, dy: Real;  i: Coordinate;
	BEGIN
		vyGraphBase.SetForeColor( vyGraphBase.white );  dx := editor.wr / (v + 1);
		FOR i := 1 TO v DO vyGraphBase.Line2d( editor.xr + i * dx, editor.yr, editor.xr + i * dx, editor.yr + editor.hr ) END;
		dy := editor.hr / (h + 1);
		FOR i := 1 TO h DO vyGraphBase.Line2d( editor.xr, editor.yr + i * dy, editor.xr + editor.wr, editor.yr + i * dy ) END
	END Grid;

	PROCEDURE Recall( editor: tLayer;  VAR msg: Objects.ObjMsg );
	CONST ticks = 5;
	VAR bkCol: Color;  x, y, w, h: Coordinate;  X, Y, W, H: Real;
	BEGIN
		vyGraphBase.GetBackColor( bkCol );

		X := editor.xr;  Y := editor.yr;  W := editor.wr;  H := editor.hr;
		vyGraphBase.Rect2dToRect( editor.xr, editor.yr, editor.wr, editor.hr, x, y, w, h );
		vyRectangles.InsetRect( x, y, w, h, -1, -1 );
		vyAxis.SetColors( editor.style.selectcol, editor.style.selectcol, editor.style.selectcol );
		IF editor.hScale THEN
			vyAxis.PlotLabels( TRUE );  vyAxis.ForcePlot( x, y, x + w, y, X, X + W, (X + W) / ticks );
			vyAxis.FlipAxesOrientation( TRUE );  vyAxis.ForcePlot( x, y + h, x + w, y + h, X, X + W, (X + W) / ticks );
			vyAxis.FlipAxesOrientation( FALSE )
		ELSE
			vyAxis.PlotLabels( TRUE );  vyAxis.ForcePlot( x, y, x + w, y, X, X + W, (X + W) / ticks );
			vyAxis.FlipAxesOrientation( TRUE );  vyAxis.ForcePlot( x, y + h, x + w, y + h, X, X + W, (X + W) / ticks );
			vyAxis.FlipAxesOrientation( FALSE )
		END;

		IF editor.vScale THEN vyAxis.PlotLabels( TRUE );  vyAxis.ForcePlot( x, y, x, y + h, Y, Y + H, (Y + H) / ticks );

			vyAxis.FlipAxesOrientation( TRUE );  vyAxis.ForcePlot( x + w, y, x + w, y + h, Y, Y + H, (Y + H) / ticks );
			vyAxis.FlipAxesOrientation( FALSE )

		ELSE vyAxis.PlotLabels( TRUE );  vyAxis.ForcePlot( x, y, x, y + h, Y, Y + H, (Y + H) / ticks );

			vyAxis.FlipAxesOrientation( TRUE );  vyAxis.ForcePlot( x + w, y, x + w, y + h, Y, Y + H, (Y + H) / ticks );
			vyAxis.FlipAxesOrientation( FALSE )

		END;
		vyGraphBase.SetBackColor( editor.style.fillcol );  vyGraphBase.EraseRect2d( editor.xr, editor.yr, editor.wr, editor.hr );
		Grid( editor, 4, 4 );  vyGraphBase.SetStyle( editor.style )
	END Recall;

	PROCEDURE Edit( editor: tLayer;  event: vyEvents.EventMsg ): BOOLEAN;
	(*vs 0.0a1   md  14.02.95 *)
	CONST erase = TRUE;  draw = FALSE;
	VAR x2d, y2d, oldy2d: Real;  i, oldi: SIGNED32;  changed: BOOLEAN;

		PROCEDURE Get2dLocation( x, y: Coordinate;  VAR X, Y: Real );
		BEGIN
			vyGraphBase.PointToPoint2d( x, y, X, Y );
			IF X < editor.xr THEN X := editor.xr
			ELSIF X > editor.xr + editor.wr THEN X := editor.xr + editor.wr
			END;
			IF Y < editor.yr THEN Y := editor.yr
			ELSIF Y > editor.yr + editor.hr THEN Y := editor.yr + editor.hr
			END
		END Get2dLocation;

		PROCEDURE Line( j: SIGNED32;  action: BOOLEAN );
		VAR col, bkCol: Color;
		BEGIN
			IF action = erase THEN
				vyGraphBase.GetForeColor( col );  vyGraphBase.GetBackColor( bkCol );
				vyGraphBase.SetForeColor( editor.style.fillcol );
				vyGraphBase.Line2d( vyTypes.VGetR( editor.x, j ), vyTypes.VGetR( editor.y, j ), vyTypes.VGetR( editor.x, j + 1 ),
												   vyTypes.VGetR( editor.y, j + 1 ) );
				vyGraphBase.SetForeColor( col )
			ELSE
				vyGraphBase.Line2d( vyTypes.VGetR( editor.x, j ), vyTypes.VGetR( editor.y, j ), vyTypes.VGetR( editor.x, j + 1 ),
												   vyTypes.VGetR( editor.y, j + 1 ) )
			END
		END Line;

		PROCEDURE GetIndex( ): SIGNED32;
		BEGIN
			RETURN ENTIER( (x2d - editor.xr) / editor.dx + 0.5 )
		END GetIndex;

		PROCEDURE Update;
		VAR from, to, tick: SIGNED32;  yFrom, yTo: Real;

			PROCEDURE UpdateEntry( v: Real );
			VAR g: vyBase.tVector;
			BEGIN  (* remove old lines *)
				IF (tick > 0) THEN Line( tick - 1, erase ) END;
				IF (tick < editor.ticks) THEN Line( tick, erase ) END;
				(* remember new information *)
				g := editor.y;
				IF g IS vyRealVec.tVector THEN
					WITH g: vyRealVec.tVector DO vyRealVec.Set( v, g, tick );
					END;
				ELSIF g IS vyLongrealVec.tVector THEN
					WITH g: vyLongrealVec.tVector DO vyLongrealVec.Set( v, g, tick )
					END;
				END;
				(* draw new lines *)
				IF (tick > 0) THEN Line( tick - 1, draw ) END;
				IF (tick < editor.ticks) THEN Line( tick, draw ) END
			END UpdateEntry;

		BEGIN  (* hide cursor *)
			vyGraphBase.FadeCursor;
			IF (i = oldi) THEN tick := i;  UpdateEntry( y2d ) ELSE
				IF i < oldi THEN from := i;  yFrom := y2d;  to := oldi;  yTo := oldy2d
				ELSE from := oldi;  yFrom := oldy2d;  to := i;  yTo := y2d
				END;
				FOR tick := from TO to DO UpdateEntry( yFrom + (tick - from) * (yTo - yFrom) / (to - from) ) END
			END
		END Update;

	BEGIN
		changed := FALSE;  vyGraphBase.SetStyle( editor.style );  vyGraphBase.SetDisplayMode( vyGraphBase.replace );
		Get2dLocation( event.x, event.y, x2d, y2d );  i := GetIndex();  oldi := i;  oldy2d := y2d;  Update;
		WHILE event.gesture = vyEvents.EvtIdent DO
			vyEvents.GetEvent( event );  Get2dLocation( event.x, event.y, x2d, y2d );  i := GetIndex();
			IF (y2d # oldy2d) OR (i # oldi) THEN
				changed := TRUE;  Grid( editor, 4, 4 );  vyGraphBase.SetStyle( editor.style );  Update;  oldi := i;  oldy2d := y2d
			END
		END;   (* WHILE (event.gesture=vyEvents.EvtIdent) *)
		RETURN changed
	END Edit;

	PROCEDURE Responsible( editor: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;
	BEGIN
		priority := vyEvents.PrioHigh;

		IF event.priority < priority THEN event.responder := editor;  event.priority := priority
		END
	END Responsible;

	PROCEDURE ChangeNumberData*( editor: tLayer;  num: SIGNED32 );
	VAR X: vyBase.tVector;  i: SIGNED32;
	BEGIN
		editor.ticks := num - 1;  X := editor.x;  vyLongrealVec.SetLen( X, num );  editor.dx := editor.wr / (num - 1);
		FOR i := 0 TO num - 1 DO
			IF X IS vyRealVec.tVector THEN
				WITH X: vyRealVec.tVector DO vyRealVec.Set( editor.xr + i * editor.wr / (num - 1), X, i );
				END;
			ELSIF X IS vyLongrealVec.tVector THEN
				WITH X: vyLongrealVec.tVector DO vyLongrealVec.Set( editor.xr + i * editor.wr / (num - 1), X, i )
				END;
			END
		END
	END ChangeNumberData;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Gadgets.WriteRef( M.R, obj.lib, obj.ox );  Files.WriteLReal( M.R, obj.xr );  Files.WriteLReal( M.R, obj.yr );
		Files.WriteLReal( M.R, obj.wr );  Files.WriteLReal( M.R, obj.hr );  Files.WriteLReal( M.R, obj.dx );
		Files.WriteLInt( M.R, obj.ticks );  Files.WriteBool( M.R, obj.hot );  Files.WriteBool( M.R, obj.vScale );
		Files.WriteBool( M.R, obj.hScale )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;
	BEGIN
		Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF objsub # NIL THEN obj.ox := objsub( vyBase.Object ) END;
		Files.ReadLReal( M.R, obj.xr );  Files.ReadLReal( M.R, obj.yr );  Files.ReadLReal( M.R, obj.wr );
		Files.ReadLReal( M.R, obj.hr );  Files.ReadLReal( M.R, obj.dx );  Files.ReadLInt( M.R, obj.ticks );
		Files.ReadBool( M.R, obj.hot );  Files.ReadBool( M.R, obj.vScale );  Files.ReadBool( M.R, obj.hScale )
	END Load0;

	PROCEDURE Copy*( VAR M: Objects.CopyMsg;  src, dest: tLayer );
	BEGIN
		vyCharts.Copy( M, src, dest );
		(* (* never deepcopy data in a layer ! *)
	IF M.id = Objects.deep THEN
	ELSE
	END;
	*)
		dest.xr := src.xr;  dest.yr := src.yr;  dest.wr := src.wr;  dest.hr := src.hr;  dest.dx := src.dx;  dest.ticks := src.ticks;
		dest.hot := src.hot;  dest.vScale := src.vScale;  dest.hScale := src.hScale;  dest.ox := src.ox

	END Copy;

	PROCEDURE Bind( o: Objects.Object;  VAR M: Objects.BindMsg );
	BEGIN
		IF (o # NIL ) & (M.lib # o.lib) THEN
			Gadgets.BindObj( o, M.lib );
			IF o.handle # NIL THEN o.handle( o, M ) END
		END
	END Bind;

	PROCEDURE Alloc*;
	VAR layer: tLayer;
	BEGIN
		NEW( layer );  layer.handle := Handler;  Objects.NewObj := layer
	END Alloc;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR copy: tLayer;  uhandle: Objects.Handler;  gen: PROCEDURE;

	CONST GenProc = "vyFctEdit.Alloc";   (* Gen Procedure as String *)
	BEGIN
		uhandle := vyCharts.Handler;   (* handler of root object*)
		gen := Alloc;   (* gen Procedure as PROCEDURE *)

		WITH o: tLayer DO
			IF M IS Display.DisplayMsg THEN
				WITH M: Display.DisplayMsg DO
					Recall( o, M );  uhandle( o, M );   (* call root handle*)
				END;
			ELSIF M IS vyEvents.EventMsg THEN
				WITH M: vyEvents.EventMsg DO
					IF M.callForResponder THEN
						Responsible( o, M );  uhandle( o, M ) (* if not responsible: maybe root is *)
					ELSE
						IF M.gesture = vyEvents.EvtIdent THEN
							IF Edit( o, M ) & o.hot THEN vyBase.Update( o.ox );  vyPort.PictureUpdate( M.dlink( vyPort.Picture ) ) END
						ELSE
							uhandle( o, M ) (* that M belongs to root *)
						END
					END;
				END;
			ELSIF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO
					IF M.stamp = o.stamp THEN
						M.obj := o.dlink (* copy M arrives again *)
					ELSE
						gen;  copy := Objects.NewObj( tLayer );  M.obj := copy;  o.dlink := copy;   (* Generator  *)
						Copy( M, o, M.obj( tLayer ) ) (* do not call uhanlde, may result in new object of type "root" *)
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					uhandle( o, M );
					IF M.id = Objects.load THEN Load0( o, M )
					ELSIF M.id = Objects.store THEN Store0( o, M )
					END;
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( GenProc, M.s );  M.class := Objects.String;  M.res := 0
						ELSIF M.name = "vScale" THEN M.class := Objects.Bool;  M.b := o.vScale;  M.res := 0
						ELSIF M.name = "hScale" THEN M.class := Objects.Bool;  M.b := o.vScale;  M.res := 0
						ELSE uhandle( o, M )
						END
					ELSIF M.id = Objects.enum THEN M.Enum( "vScale" );  M.Enum( "hScale" )
					ELSE uhandle( o, M )
					END
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO uhandle( o, M );  Bind( o.ox, M );
					ASSERT ( o.ox.handle # NIL )
				END;
			ELSE uhandle( o, M )
			END
		END
	END Handler;

	PROCEDURE Embed*( editor: tLayer;  obj: vyBase.tVector;  x, y, w, h: FLOAT32;  vScale, hScale, hot: BOOLEAN ): vyPort.Picture;
	(*vs 0.0a1   md  23.06.95 *)
	VAR N, i: SIGNED32;  X: vyBase.tVector;  pict: vyPort.Picture;  id: vyName.tNameArray;
	BEGIN
		N := obj.nrData;  editor.ox := obj;  editor.xr := x;  editor.yr := y;  editor.wr := w;  editor.hr := h;  editor.ticks := N - 1;
		editor.dx := w / (N - 1);  editor.hot := hot;  X := vyLongrealVec.New( N );
		FOR i := 0 TO N - 1 DO
			IF X IS vyRealVec.tVector THEN
				WITH X: vyRealVec.tVector DO vyRealVec.Set( x + i * w / (N - 1), X, i );
				END;
			ELSIF X IS vyLongrealVec.tVector THEN
				WITH X: vyLongrealVec.tVector DO vyLongrealVec.Set( x + i * w / (N - 1), X, i )
				END;
			END
		END;
		COPY( "editor: ", id );  vyName.AppendObjId( obj, id );  vyCharts.OpenChart128( editor, id );
		IF editor.hot THEN editor.style.fcol := hotColor ELSE editor.style.fcol := coolColor END;
		editor.style.selectcol := vyGraphBase.black;  editor.style.fillcol := vyGraphBase.mgrey;  editor.x := X;  editor.y := obj;
		(*	editor.firstUnUsed := N;*)
		editor.handle := Handler;  editor.vScale := vScale;  editor.hScale := hScale;

		vyBase.Subscribe( (*for messages from source*) obj, editor );

		(*	vyGraphBase.SetRealWorldRgn (x, y, w, h, 0.1);*)
		pict := vyPort.NewP( vyDisplay2d.NewC2d( x, y, w, h ) );
		vyGraphBase.SetCoordinate( pict.gcontext( vyDisplay2d.tCoordinate2d ).c2d );
		vyGraphBase.SetRealWorldRgn( x, y, w, h, 0.1 );

		vyGraphBase.InsetRealWorldRegion( 32, 24 );  vyPort.AddLayer( pict, editor );  pict.backGround := vyGraphBase.dgrey;
		RETURN pict
	END Embed;

	PROCEDURE Apply*;   (* gs *)
	VAR s: vyParser.Scanner;  obj: vyBase.Object;
	BEGIN
		vyParser.OpenParScanner( s );
		IF ~vyParser.NamedObject( s, obj ) THEN vyHostTexts.Note( vyHostTexts.cNotify, "variable identifier expected for existing object" ) ELSE vyBase.Update( obj ) END
	END Apply;

BEGIN
	hotColor := vyGraphBase.red;  coolColor := vyGraphBase.blue
END vyFctEdit.