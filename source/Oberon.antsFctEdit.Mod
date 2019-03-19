MODULE antsFctEdit IN Oberon (** fof  **) ;
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




(*removing axis completely *)

IMPORT Objects, Display, vyBase, vyGraphBase, antsObjects, Attributes, vyName, vyScale, vyDisplay2d, Gadgets,
	antsCommands, vyPort, vyStrings := vyHostStrings, vyEvents, Files, vyCommandMenus, antsFunctions, aM := antsMessages;

TYPE
	Real = vyGraphBase.Real;  Coordinate = vyGraphBase.Coordinate;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc)
		f: antsFunctions.Function;
		xr, yr, wr, hr: Real;
		dx: Real;
		grid: INTEGER;
		inedit: BOOLEAN;   (* temp *)
		viewEditWin: BOOLEAN;
		fcache: antsFunctions.Array;   (* temp *)
		commands: vyCommandMenus.List;   (* const from Alloc *)
		edit: BOOLEAN;   (* temp *)
		noLoc: BOOLEAN
	END;
VAR
	tempLayer: tLayer;

	PROCEDURE sync( o: tLayer );
	BEGIN
		antsFunctions.GetCache( o.f, o.xr, o.xr + o.wr, o.dx, o.fcache )
	END sync;

	PROCEDURE Grid( editor: tLayer;  v, h: Coordinate );
	VAR dx, dy: Real;  i: Coordinate;  xx, yy, ww, hh: Coordinate;
	BEGIN
		vyGraphBase.SetPenSize( 1 );  vyGraphBase.SetForeColor( editor.style.selectcol );  dx := editor.wr / (v + 1);
		FOR i := 1 TO v DO vyGraphBase.Line2d( editor.xr + i * dx, editor.yr, editor.xr + i * dx, editor.yr + editor.hr ) END;
		dy := editor.hr / (h + 1);
		FOR i := 1 TO h DO vyGraphBase.Line2d( editor.xr, editor.yr + i * dy, editor.xr + editor.wr, editor.yr + i * dy ) END;
		vyGraphBase.Rect2dToRect( editor.xr, editor.yr, editor.wr, editor.hr, xx, yy, ww, hh );
		vyGraphBase.FrameRect( xx, yy, ww + 1, hh + 1 );  vyGraphBase.SetPenSize( editor.style.pensize );
	END Grid;

	PROCEDURE Recall( editor: tLayer );
	VAR x, y, w, h: Coordinate;  X, Y, W, H: Real;  xr, dx: LONGREAL;  i, count, accuracy: LONGINT;

		PROCEDURE Min( r1, r2: LONGREAL ): LONGREAL;
		BEGIN
			IF r1 < r2 THEN RETURN r1 ELSE RETURN r2 END
		END Min;

	BEGIN
		Attributes.GetInt( tempLayer, "Accuracy", accuracy );
		IF accuracy = 0 THEN accuracy := 1 END;

		editor.edit := editor.f.editable;
		IF editor.fcache = NIL THEN antsFunctions.GetCache( editor.f, editor.xr, editor.xr + editor.wr, editor.dx, editor.fcache );  END;

		vyGraphBase.SetStyle( editor.style );
		IF ~editor.f.editable THEN
			vyGraphBase.GetScreenRgn( x, y, w, h );  vyGraphBase.RectToRect2d( x, y, w, h, X, Y, W, H );

			vyGraphBase.SetForeColor( editor.style.fillcol );

			dx := W / w / accuracy;  xr := X;  vyGraphBase.MoveTo2d( xr, editor.f.get( editor.f, xr ) );
			WHILE (xr < X + W) DO
				xr := xr + dx;  vyGraphBase.LineTo2d( xr, editor.f.get( editor.f, xr ) );
				IF (xr < 0) & (xr + dx > 0) THEN
					vyGraphBase.LineTo2d( -Min( ABS( xr ), ABS( xr + dx ) ), editor.f.get( editor.f, -Min( ABS( xr ), ABS( xr + dx ) ) ) );
					vyGraphBase.LineTo2d( 0, editor.f.get( editor.f, 0 ) );
					vyGraphBase.LineTo2d( Min( ABS( xr ), ABS( xr + dx ) ), editor.f.get( editor.f, Min( ABS( xr ), ABS( xr + dx ) ) ) )
				END
			END
		END;
		i := 0;

		IF editor.edit OR editor.viewEditWin THEN
			IF ~editor.noLoc THEN Grid( editor, editor.grid, editor.grid );  END;
			IF editor.f.editable THEN vyGraphBase.SetForeColor( editor.style.fcol )
			ELSE vyGraphBase.SetForeColor( editor.style.fillcol )
			END;

			xr := editor.xr;  dx := editor.dx;  count := ENTIER( (editor.wr + editor.dx / 2) / editor.dx );

			count := LEN( editor.fcache ) - 1;

			vyGraphBase.MoveTo2d( xr, editor.fcache[i] );
			WHILE (i < count) DO
				vyGraphBase.LineTo2d( xr + dx / 2, editor.fcache[i] );  xr := xr + dx;  INC( i );
				vyGraphBase.LineTo2d( xr - dx / 2, editor.fcache[i] )
			END;
			vyGraphBase.LineTo2d( xr, editor.fcache[i] )
		END

	END Recall;

	PROCEDURE Edit( editor: tLayer;  event: vyEvents.EventMsg ): BOOLEAN;
	(*vs 0.0a1   md  14.02.95 *)
	VAR x2d, y2d, oldy2d, oldx2d: Real;  i, oldi: LONGINT;
		sx2d, sy2d, soldy2d, soldx2d: Real;  si, soldi: LONGINT;  symmetric: BOOLEAN;   (* if symmetric *)
		out: BOOLEAN;  changed: BOOLEAN;  c: vyGraphBase.tCoordinate2d;  x, y, w, h: INTEGER;  gesture: INTEGER;

		PROCEDURE Get2dLocation( x, y: Coordinate;  VAR X, Y: Real );
		BEGIN
			vyGraphBase.PointToPoint2d( x, y, X, Y );  out := TRUE;
			IF X < editor.xr THEN X := editor.xr
			ELSIF X > editor.xr + editor.wr THEN X := editor.xr + editor.wr
			ELSE out := FALSE
			END;
			IF Y < editor.yr THEN Y := editor.yr
			ELSIF Y > editor.yr + editor.hr THEN Y := editor.yr + editor.hr
			ELSE out := out & FALSE
			END
		END Get2dLocation;

		PROCEDURE Discretize( VAR x: Real;  VAR mult: LONGINT );
		BEGIN
			mult := ENTIER( (x - editor.xr + editor.dx / 2) / editor.dx );  x := editor.xr + editor.dx * mult
		END Discretize;

		PROCEDURE Linear( a: antsFunctions.Array;  from, to: LONGINT );
		VAR t, i: LONGINT;  a1, a2: LONGREAL;
		BEGIN
			IF from > to THEN t := to;  to := from;  from := t END;
			a1 := a[from];  a2 := a[to];
			FOR i := from + 1 TO to - 1 DO a[i] := a1 + (a2 - a1) * (i - from) / (to - from) END
		END Linear;

	BEGIN
		Attributes.GetBool( editor, "symmetric", symmetric );  gesture := event.gesture;  changed := FALSE;
		c := vyGraphBase.GetCoordinate();  vyGraphBase.GetScreenRgn( x, y, w, h );  vyGraphBase.SetStyle( editor.style );
		editor.inedit := TRUE;  vyGraphBase.SetDisplayMode( vyGraphBase.replace );
		Get2dLocation( event.x, event.y, x2d, y2d );  sx2d := -x2d;  Discretize( x2d, i );  oldi := i;  Discretize( sx2d, si );
		soldi := si;  tempLayer := editor;
		IF out THEN vyCommandMenus.ExecuteListedCommand( event.x, event.y, event, editor.commands ) ELSE
			WHILE event.gesture = gesture DO
				vyEvents.GetEvent( event );  Get2dLocation( event.x, event.y, x2d, y2d );  sx2d := -x2d;  Discretize( x2d, i );
				Discretize( sx2d, si );
				IF (y2d # oldy2d) OR (x2d # oldx2d) THEN
					changed := TRUE;  vyGraphBase.SetStyle( editor.style );  editor.fcache[i] := y2d;
					IF symmetric & (si >= 0) THEN editor.fcache[si] := y2d;  Linear( editor.fcache, soldi, si ) END;
					Linear( editor.fcache, oldi, i );  soldx2d := x2d;  soldy2d := y2d;  soldi := si;  oldx2d := x2d;  oldy2d := y2d;
					oldi := i;

					(*vyBase.Update(editor.f);      *) vyBase.Update( editor );

					vyGraphBase.SetCoordinate( c );  vyGraphBase.SetScreenRgn( x, y, w, h )
				END
			END;   (* WHILE (event.gesture=vyEvents.EvtIdent) *)
			editor.inedit := FALSE
		END;
		IF changed THEN
			antsFunctions.SetCache( editor.f, editor.xr, editor.xr + editor.wr, editor.dx, editor.fcache );  vyBase.Update( editor.f )
		END;
		RETURN changed
	END Edit;

	PROCEDURE Responsible( editor: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;

		PROCEDURE Check( x, y: Coordinate ): BOOLEAN;
		VAR X, Y: LONGREAL;
		BEGIN
			vyGraphBase.PointToPoint2d( x, y, X, Y );
			IF (X >= editor.xr) & (Y >= editor.yr) & (X <= editor.xr + editor.wr) & (Y <= editor.yr + editor.hr) THEN RETURN TRUE
			ELSE RETURN FALSE
			END
		END Check;

	BEGIN

		IF event.gesture = vyEvents.EvtIdent THEN
			IF editor.edit THEN priority := vyEvents.PrioNormal ELSE priority := vyEvents.PrioNone END
		ELSIF event.gesture = vyEvents.EvtLoc THEN
			IF editor.edit & (~editor.noLoc) & Check( event.x, event.y ) THEN priority := vyEvents.PrioNormal
			ELSE priority := vyEvents.PrioNone
			END
		ELSIF event.gesture = vyEvents.EvtSelect THEN priority := vyEvents.PrioNone
		END;

		IF event.priority < priority THEN event.responder := editor;  event.priority := priority
		END
	END Responsible;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteInt( M.R, 2 );  Gadgets.WriteRef( M.R, obj.lib, obj.f );  Files.WriteLReal( M.R, obj.xr );
		Files.WriteLReal( M.R, obj.yr );  Files.WriteLReal( M.R, obj.wr );  Files.WriteLReal( M.R, obj.hr );
		Files.WriteLReal( M.R, obj.dx );  Files.WriteInt( M.R, obj.grid );  Files.WriteBool( M.R, obj.viewEditWin );
		Files.WriteBool( M.R, obj.noLoc )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		Files.ReadInt( M.R, version );  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF objsub # NIL THEN obj.f := objsub( antsFunctions.Function ) END;
		Files.ReadLReal( M.R, obj.xr );  Files.ReadLReal( M.R, obj.yr );  Files.ReadLReal( M.R, obj.wr );
		Files.ReadLReal( M.R, obj.hr );  Files.ReadLReal( M.R, obj.dx );  Files.ReadInt( M.R, obj.grid );
		IF version > 0 THEN Files.ReadBool( M.R, obj.viewEditWin );  END;
		IF version > 1 THEN Files.ReadBool( M.R, obj.noLoc );  END;
	END Load0;

	PROCEDURE Copy*( VAR M: Objects.CopyMsg;  src, dest: tLayer );
	BEGIN
		(*
	vyPort.LayerCopy(M, src, dest);
	dest.xr := src.xr;
	dest.yr := src.yr;
	dest.wr := src.wr;
	dest.hr := src.hr;
	dest.dx := src.dx;
	dest.f := src.f
	*)
		dest^ := src^
	END Copy;

	PROCEDURE Bind( o: Objects.Object;  VAR M: Objects.BindMsg );
	BEGIN
		IF (o # NIL ) & (M.lib # o.lib) THEN
			Gadgets.BindObj( o, M.lib );
			IF o.handle # NIL THEN o.handle( o, M ) END
		END
	END Bind;

	PROCEDURE IncY;
	BEGIN
		tempLayer.yr := tempLayer.yr - 1;  tempLayer.hr := tempLayer.hr + 2;  vyBase.Update( tempLayer )
	END IncY;

	PROCEDURE DecY;
	BEGIN
		tempLayer.yr := tempLayer.yr + 1;  tempLayer.hr := tempLayer.hr - 2;  vyBase.Update( tempLayer )
	END DecY;

	PROCEDURE Alloc*;
	VAR layer: tLayer;
	BEGIN
		NEW( layer );  layer.handle := Handler;  Objects.NewObj := layer;  layer.inedit := FALSE;  layer.grid := 1;
		layer.commands := NIL;  vyCommandMenus.Add( layer.commands, IncY, "IncYRange" );
		vyCommandMenus.Add( layer.commands, DecY, "DecYRange" );  vyCommandMenus.Add( layer.commands, edit, "toggle edit" );
		vyCommandMenus.Add( layer.commands, symmetric, "toggle symmetric" );  layer.edit := TRUE;  layer.viewEditWin := FALSE;
		antsObjects.Register( layer );  aM.cmd;
	END Alloc;

	PROCEDURE edit;
	BEGIN
		tempLayer.noLoc := ~tempLayer.noLoc;
	END edit;

	PROCEDURE symmetric;
	VAR symmetric: BOOLEAN;
	BEGIN
		Attributes.GetBool( tempLayer, "symmetric", symmetric );  Attributes.SetBool( tempLayer, "symmetric", ~symmetric );
	END symmetric;

	PROCEDURE IncAccuracy;
	VAR accuracy: LONGINT;
	BEGIN
		Attributes.GetInt( tempLayer, "Accuracy", accuracy );
		IF accuracy = 0 THEN accuracy := 1 END;
		IF accuracy < 64 THEN
			accuracy := accuracy * 2;  Attributes.SetInt( tempLayer, "Accuracy", accuracy );  vyBase.Update( tempLayer );
		END;
	END IncAccuracy;

	PROCEDURE DecAccuracy;
	VAR accuracy: LONGINT;
	BEGIN
		Attributes.GetInt( tempLayer, "Accuracy", accuracy );
		IF accuracy > 1 THEN accuracy := accuracy DIV 2;  END;
		Attributes.SetInt( tempLayer, "Accuracy", accuracy );  vyBase.Update( tempLayer );
	END DecAccuracy;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR copy: tLayer;  uhandle: Objects.Handler;  gen: PROCEDURE;
		accstr: ARRAY 64 OF CHAR;
		acc: LONGINT;

	CONST GenProc = "antsFctEdit.Alloc";   (* Gen Procedure as String *)
	BEGIN
		uhandle := vyPort.LayerHandler;   (* handler of root object*)
		gen := Alloc;   (* gen Procedure as PROCEDURE *)

		WITH o: tLayer DO
			IF M IS Display.DisplayMsg THEN
				WITH M: Display.DisplayMsg DO  (* Copyox(o); *) Recall( o );   (* uhandle(o,M); *)  (* call root handle*)
				END;
			ELSIF M IS vyBase.UpdateMessage THEN
				WITH M: vyBase.UpdateMessage DO
					IF (o.edit = FALSE ) & (o.f.editable = TRUE ) THEN
						IF o.fcache # NIL THEN antsFunctions.SetCache( o.f, o.xr, o.xr + o.wr, o.dx, o.fcache ) END
					END;
					IF ~o.inedit THEN antsFunctions.GetCache( o.f, o.xr, o.xr + o.wr, o.dx, o.fcache ) END;
					uhandle( o, M );
				END;
			ELSIF M IS vyEvents.EventMsg THEN
				WITH M: vyEvents.EventMsg DO
					IF M.callForResponder THEN
						Responsible( o, M );  uhandle( o, M ) (* if not responsible: maybe root is *)
					ELSE
						IF (M.gesture = vyEvents.EvtIdent) OR (M.gesture = vyEvents.EvtLoc) THEN
							IF Edit( o, M ) THEN
								(* vyBase.Update (o.ox);*)
								vyPort.PictureUpdate( M.dlink( vyPort.Picture ) )
							END
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
					IF M.id = Objects.enum THEN
						M.Enum( "grid" );  M.Enum( "AllwaysEditWin" );  M.Enum( "left" );  M.Enum( "right" );  M.Enum( "stepsize" );  M.Enum( "lower" );  M.Enum( "upper" );  M.Enum( "noloc" );
						uhandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( GenProc, M.s );  M.class := Objects.String;  M.res := 0
						ELSIF M.name = "AllwaysEditWin" THEN M.class := Objects.Bool;  M.b := o.viewEditWin;  M.res := 0
						ELSIF M.name = "grid" THEN M.class := Objects.Int;  M.i := o.grid;  M.res := 0
						ELSIF M.name = "left" THEN M.class := Objects.LongReal;  M.y := o.xr;  M.res := 0
						ELSIF M.name = "lower" THEN M.class := Objects.LongReal;  M.y := o.yr;  M.res := 0
						ELSIF M.name = "right" THEN M.class := Objects.LongReal;  M.y := o.wr + o.xr;  M.res := 0
						ELSIF M.name = "upper" THEN M.class := Objects.LongReal;  M.y := o.hr + o.yr;  M.res := 0
						ELSIF M.name = "stepsize" THEN M.class := Objects.LongReal;  M.y := o.dx;  M.res := 0
						ELSIF M.name = "noloc" THEN M.class := Objects.Bool;  M.b := o.noLoc;  M.res := 0
						ELSE uhandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "grid" THEN
							IF M.class = Objects.Int THEN o.grid := SHORT( M.i );  M.res := 0;  vyBase.Update( o );  aM.vSI( "antsFctEdit: grid = ", o.grid );  END
						ELSIF M.name = "AllwaysEditWin" THEN
							IF M.class = Objects.Bool THEN
								o.viewEditWin := M.b;  M.res := 0;  vyBase.Update( o );  aM.vSB( "antsFctEdit: EditWin = ", o.viewEditWin );
							END
						ELSIF M.name = "left" THEN
							IF M.class = Objects.LongReal THEN
								o.wr := o.xr + o.wr - M.y;  o.xr := M.y;  M.res := 0;  sync( o );  vyBase.Update( o );  aM.vSR( "antsFctEdit: left = ", o.xr );
							END
						ELSIF M.name = "lower" THEN
							IF M.class = Objects.LongReal THEN
								o.hr := o.hr + o.yr - M.y;  o.yr := M.y;  M.res := 0;  vyBase.Update( o );  aM.vSR( "antsFctEdit: lower = ", o.yr );
							END
						ELSIF M.name = "right" THEN
							IF M.class = Objects.LongReal THEN
								o.wr := M.y - o.xr;  M.res := 0;  sync( o );  vyBase.Update( o );  aM.vSR( "antsFctEdit:  right = ", M.y );
							END
						ELSIF M.name = "upper" THEN
							IF M.class = Objects.LongReal THEN o.hr := M.y - o.yr;  M.res := 0;  vyBase.Update( o );  aM.vSR( "antsFctEdit:  upper = ", M.y );  END
						ELSIF M.name = "stepsize" THEN
							IF M.class = Objects.LongReal THEN
								o.dx := M.y;  M.res := 0;  sync( o );  vyBase.Update( o );  aM.vSR( "antsFctEdit:  stepsize = ", M.y );
							END
						ELSIF M.name = "noloc" THEN
							IF M.class = Objects.Bool THEN o.noLoc := M.b;  M.res := 0;  vyBase.Update( o );  aM.vSB( "antsFctEdit: noLoc = ", o.noLoc );  END

						ELSE uhandle( o, M )
						END
					ELSE uhandle( o, M )
					END
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF M.id = Objects.enum THEN M.Enum( "function" );  uhandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "function" THEN M.obj := o.f;  M.res := 0 ELSE uhandle( o, M ) END
					ELSIF M.id = Objects.set THEN
						IF M.name = "function" THEN
							vyBase.UnSubscribe( o.f, o );  o.f := M.obj( antsFunctions.Function );  o.fcache := NIL;  M.res := 0;
							vyBase.Subscribe( o.f, o );  vyBase.Update( o.f )
						ELSE uhandle( o, M )
						END
					ELSE uhandle( o, M )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					IF M.lib # o.lib THEN uhandle( o, M );  Bind( o.f, M );
						ASSERT ( o.f.handle # NIL )
					END
				END;
			ELSIF M IS vyCommandMenus.enumMsg THEN
				WITH M: vyCommandMenus.enumMsg DO
					uhandle( o, M );  M.EnumSender( "", NIL , o );  M.Enum( "toggle edit", edit, o );  M.Enum( "toggle symmetric", symmetric, o );
					Attributes.GetInt( o, "Accuracy", acc );  accstr := "Dec accuracy (";  vyStrings.AppendInt( acc, 3, accstr );  vyStrings.Append( accstr, ")" );
					M.Enum( accstr, DecAccuracy, o );  accstr := "Inc accuracy (";  vyStrings.AppendInt( acc, 3, accstr );
					vyStrings.Append( accstr, ")" );  M.Enum( accstr, IncAccuracy, o );  tempLayer := o;

				END;
			ELSE uhandle( o, M )
			END
		END
	END Handler;

	PROCEDURE Open*( editor: tLayer;  f: antsFunctions.Function;  x, y, w, h, dx: Real );
	(*vs 0.0a1   md  23.06.95 *)
	VAR id: vyName.tNameArray;
	BEGIN
		id := "edit:";  vyName.AppendObjId( f, id );  vyPort.OpenLayer( editor, id );  editor.f := f;  editor.xr := x;  editor.yr := y;
		editor.wr := w;  editor.hr := h;  editor.dx := dx;  editor.style.fcol := vyGraphBase.yellow;
		editor.style.selectcol := vyGraphBase.white;  editor.style.fillcol := vyGraphBase.red;  editor.style.fnt := "Syntax10.Scn.Fnt";
		editor.handle := Handler;

		vyBase.Subscribe( (*for messages from source*) f, editor )

	END Open;

	PROCEDURE DoShow*( f: antsFunctions.Function;  x, y, w, h, dx: Real );
	VAR pict: vyPort.Picture;  editor: tLayer;
	BEGIN
		Alloc;  editor := Objects.NewObj( tLayer );  Open( editor, f, x, y, w, h, dx );
		pict := vyPort.NewP( vyDisplay2d.NewC2d( x, y, w, h ) );
		vyGraphBase.SetCoordinate( pict.gcontext( vyDisplay2d.tCoordinate2d ).c2d );
		vyGraphBase.SetRealWorldRgn( x, y, w, h, 0 );  vyPort.AddLayer( pict, editor );
		pict.backGround := vyGraphBase.dgrey;  vyPort.Write( pict )
	END DoShow;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  f: antsFunctions.Function;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO
			f := data( antsFunctions.Function );  DoShow( f, -1, 0, 2, 1, 0.01 );  vyScale.Insert();  data := vyBase.NextParObj()
		END
	END ShowP;

	PROCEDURE Show*;
	VAR l: antsCommands.tScanList;  from, to, by: LONGREAL;  f: antsFunctions.Function;  obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ from=REAL to=REAL by=REAL" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectRealFromKeyword( l, "from", from ) &
		    antsCommands.ExpectRealFromKeyword( l, "to", to ) & antsCommands.ExpectRealFromKeyword( l, "by", by ) THEN
			f := obj( antsFunctions.Function );  DoShow( f, from, 0, to, 1, by )
		END
	END Show;

BEGIN
	aM.launch;
END antsFctEdit.

antsFunctions.Define test ~
Voyager.Show test as antsFctEdit ~
antsFctVector.NewVec testvec 1000 ~
antsFctVector.New connext test testvec~
Voyager.Show testvec as LinePlot ~

System.Free antsFctEdit  ~
antsObjects.WriteAttributes ~


vyScale.Insert ~
vyGrid.Insert 0 0 1 1

vyScale.Insert


