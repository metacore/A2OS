MODULE vyCharts IN Oberon;
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
(c) G. Sawitzki, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
*)
(*= This Module contains the abstract ancestor of all painting layers like
MouseData, ARMACoeff, Sketch etc.. *)
(*	history:
9.8.95 md 0.0a1	alpha version
26.1.95 md 0.0d7	cleaned
27.10.94 md 0.0d6	adaped to the renamed vyHostDisplay
27.10.94 md 0.0d5	rename: Chart -> Charts; this layer is merely abstrct now
25.10.94 md 0.0d4	VoyagerTypes.CHunkREALEntry
28.07.94 0.0d1		created *)
(*!	clear a chart *)
IMPORT Files, Objects, Display, vyHostDisplay := vyGraphBase, vyHostTexts, vyHostStrings, vyBase, vyGraphBase, vyLinks,
	vyName, vyRealVec, vyTypes, vyPort, vyEvents, vyLongrealVec, Attributes;

CONST
	idversion* = "vyCharts v0r0a4";

TYPE
	Real = vyGraphBase.Real;  Coordinate = vyGraphBase.Coordinate;
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		paint: BOOLEAN;
		(* closed: BOOLEAN by way of Attributes.Mod *)
	END;

VAR
	slink*, dlink*: Objects.Object;

	PROCEDURE Recall( chart: tLayer );
	VAR i: SIGNED32;  closed: BOOLEAN;   (* fof 020624 *)

		PROCEDURE Min( x, y: SIGNED32 ): SIGNED32;
		BEGIN
			IF (x < y) THEN RETURN x ELSE RETURN y END;
		END Min;

	BEGIN  (*ASSERT((chart.X.nrData=chart.y.nrData) & (chart.x.nrData>0));*)
		IF Min( (chart.x.nrData - 1), (chart.y.nrData - 1) ) > 0 THEN
			vyGraphBase.MoveTo2d( vyTypes.VGetR( chart.x, 0 ), vyTypes.VGetR( chart.y, 0 ) );
		END;
		FOR i := 0 TO Min( (chart.x.nrData - 1), (chart.y.nrData - 1) ) DO
			vyGraphBase.LineTo2d( vyTypes.VGetR( chart.x, i ), vyTypes.VGetR( chart.y, i ) )
		END;
		Attributes.GetBool( chart, "closed", closed );
		IF closed THEN vyGraphBase.LineTo2d( vyTypes.VGetR( chart.x, 0 ), vyTypes.VGetR( chart.y, 0 ) ) END;
	END Recall;

	PROCEDURE Respond( chart: tLayer;  VAR event: vyEvents.EventMsg );
	VAR x, y: Coordinate;

		PROCEDURE WriteData;
		VAR x2d, y2d: Real;
		BEGIN
			vyGraphBase.PointToPoint2d( x, y, x2d, y2d );
			IF chart.x IS vyRealVec.tVector THEN vyRealVec.Append( x2d, chart.x );  vyRealVec.Append( y2d, chart.y )
			ELSIF chart.x IS vyLongrealVec.tVector THEN  (* fof 020624 *)
				vyLongrealVec.Append( x2d, chart.x );  vyLongrealVec.Append( y2d, chart.y )
			END
			(*	chart.firstUnUsed := chart.firstUnUsed+1;*)
		END WriteData;

	BEGIN
		vyHostDisplay.SetStyle( chart.style );  vyHostDisplay.SetDisplayMode( vyHostDisplay.replace );  x := event.x;
		y := event.y;  WriteData;
		WHILE event.gesture = vyEvents.EvtIdent DO
			IF (x # event.x) OR (y # event.y) THEN
				vyHostDisplay.FadeCursor;  vyHostDisplay.Line( x, y, event.x, event.y );
				vyHostDisplay.DrawCursor( event.x, event.y );  x := event.x;  y := event.y;  WriteData
			END;
			vyEvents.GetEvent( event )
		END;   (* WHILE (event IS Events.tPick) *)
		vyBase.Update( chart );
	END Respond;

(*PROCEDURE Copy (src, dest: tLayer);
(*VAR i: SIGNED32;*)
BEGIN ASSERT((src.x.nrData = src.y.nrData) & (src.x.nrData > 0));
dest^ := src^;
dest.x := vyRealVec.New (src.x.nrData); vyRealVec.CopyData(src.x, dest.x);
dest.y := vyRealVec.New (src.y.nrData); vyRealVec.CopyData(src.y, dest.y);
(*
FOR i := 0 TO SHORT(src.x.nrData -  1)  DO
Append (vyRealVec.Get (src.x, i), dest.x);
vyRealVec.Append (vyRealVec.Get (src.y, i), dest.y)
END
*)
(*	dest.firstUnUsed := src.firstUnUsed*)
END Copy; *)
	PROCEDURE Copy*( VAR M: Objects.CopyMsg;  src, dest: tLayer );
	BEGIN
		vyPort.LayerCopy( M, src, dest );
		(* (* never deepcopy data in a layer ! *)
	IF M.id = Objects.deep THEN
	ELSE
	END;
	*)
		dest.paint := src.paint
	END Copy;

	PROCEDURE Responsible( chart: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;
	BEGIN
		priority := vyEvents.PrioNone;
		IF event.gesture = vyEvents.EvtIdent THEN priority := vyEvents.PrioNormal END;
		IF event.priority < priority THEN event.responder := chart;  event.priority := priority END
	END Responsible;

	PROCEDURE Consume( o: tLayer;  msg: Display.ConsumeMsg );
	VAR v, w: vyBase.tVector;  minX, maxX, minY, maxY: FLOAT32;  pict: vyPort.Picture;  data: Objects.Object;  nans: SIGNED32;
	BEGIN
		pict := msg.dlink( vyPort.Picture );  data := msg.obj;  v := vyBase.GetVFromObj( data );  data := data.slink;
		w := vyBase.GetVFromObj( data );
		IF (v # NIL ) & (w # NIL ) THEN Open( o, msg.obj );

			vyTypes.VGetMinMaxR( o.x, minX, maxX, nans );  vyTypes.VGetMinMaxR( o.y, minY, maxY, nans );
			vyPort.SetNewC2d( pict, minX, minY, maxX - minX, maxY - minY );  vyBase.Update( v )
		END
	END Consume;

	PROCEDURE Store0( o: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteBool( M.R, o.paint ) (* fof, no chance for version management, use Attributes for extensions, bad. *)
	END Store0;

	PROCEDURE Load0( o: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Files.ReadBool( M.R, o.paint ) (* fof, no chance for version management, use Attributes for extensions,  bad. *)
	END Load0;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyCharts.Alloc', M.s );  M.class := Objects.String;  M.res := 0
			ELSIF M.name = "paint" THEN M.class := Objects.Bool;  M.b := obj.paint;  M.res := 0
			ELSIF M.name = "closed" THEN
				vyPort.LayerHandler( obj, M );
				IF M.class # Objects.Bool THEN M.class := Objects.Bool;  M.b := FALSE END;
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.set THEN  (* fof 020624 *)
			IF M.name = "paint" THEN
				IF M.class = Objects.Bool THEN obj.paint := M.b;  M.res := 0 END
			ELSIF M.name = "closed" THEN vyPort.LayerHandler( obj, M );  vyBase.Update( obj );
			ELSE vyPort.LayerHandler( obj, M )
			END
		ELSIF M.id = Objects.enum THEN M.Enum( "paint" );  M.Enum( "closed" );  vyPort.LayerHandler( obj, M )
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	(*
PROCEDURE Store0 (obj: tLayer;      VAR M: Objects.FileMsg);
BEGIN
Gadgets.WriteRef(M.R, obj.lib, obj.x);
Gadgets.WriteRef(M.R, obj.lib, obj.y);
Files.WriteBool(M.R, obj.paint);
END Store0;

PROCEDURE Load0 (obj: tLayer;      VAR M: Objects.FileMsg);
VAR     objsub: Objects.Object;
BEGIN
dlink:=M.dlink;
Gadgets.ReadRef(M.R, obj.lib, objsub);
IF (objsub # NIL) & (objsub IS vyBase.tVector) THEN  obj.x := objsub(vyBase.tVector);
END;
Gadgets.ReadRef(M.R, obj.lib, objsub);
IF (objsub # NIL) & (objsub IS vyBase.tVector) THEN  obj.y := objsub(vyBase.tVector);
END;
Files.ReadBool(M.R, obj.paint);
END Load0;
*)
(*PROCEDURE Handler* (obj: Objects.Object;  VAR msg: Objects.ObjMsg);
VAR copy: tLayer;
pict : vyPort.Picture;
minX, maxX, minY, maxY : FLOAT32;
nans : SIGNED32;
uhandle: Objects.Handler; gen: PROCEDURE;

CONST GenProc = "vyCharts.Alloc";  	(* Gen Procedure as String *)

BEGIN
uhandle := vyPort.LayerHandler;   (* handler of root object*)
gen := Alloc; 								(* gen Procedure as PROCEDURE *)

WITH obj:tLayer DO
WITH
msg : Display.DisplayMsg DO
uhandle (obj,msg); Recall (obj)
| msg: vyEvents.EventMsg DO
IF msg.callForResponder THEN Responsible (obj, msg); uhandle(o,M) (* if not responsible: maybe root is *)
ELSE
IF msg.gesture = vyEvents.EvtSelect THEN
ELSIF msg.gesture = vyEvents.EvtIdent THEN IF obj.paint = TRUE THEN Respond (obj, msg) END
END
END;
| msg: Objects.CopyMsg DO
Alloc; copy := Objects.NewObj(tLayer); msg.obj := copy; vyPort.LayerHandler (obj, msg);
Copy(obj, msg.obj(tLayer));
| msg: Objects.FileMsg DO
IF msg.id = Objects.load THEN  vyPort.LayerHandler (obj, msg); Load0(obj, msg);
(* fof, replaced from Load0(obj, msg); vyPort.LayerHandler (obj, msg);, wrong order ! *)
(*! hack *) IF ((obj.x # NIL) & (obj.y # NIL)) THEN pict:=msg.dlink(vyPort.Picture);
IF pict#NIL THEN vyTypes.VGetMinMaxR(obj.x,minX,maxX,nans);
vyTypes.VGetMinMaxR(obj.y,minY,maxY,nans);
vyPort.SetNewC2d (pict, minX, minY, maxX - minX, maxY - minY)
ELSE (*vyHostTexts.Note(vyHostTexts.cWarning,"vyCharts: no host picture  ");*)
END
ELSE vyHostTexts.Note(vyHostTexts.cWarning,"vyCharts: no x obj loaded  ")
END
ELSIF msg.id = Objects.store THEN  vyPort.LayerHandler (obj, msg); Store0(obj, msg)
(* fof, replaced from Store0(obj, msg); vyPort.LayerHandler (obj, msg);, wrong order ! *)
ELSE vyPort.LayerHandler (obj, msg) END;
| msg: Display.ConsumeMsg DO
Consume(obj, msg); vyPort.LayerHandler(obj, msg)
| msg: Objects.AttrMsg DO HandleAttributes(obj, msg)
| msg: Objects.LinkMsg DO HandleLinks(obj, msg)
| msg: Objects.BindMsg DO vyPort.LayerHandler(obj, msg);
IF obj.x# NIL THEN Gadgets.BindObj(obj.x, msg.lib) END;
IF obj.y# NIL THEN Gadgets.BindObj(obj.y, msg.lib) END
ELSE
vyPort.LayerHandler (obj, msg)
END
END
END Handler;
*)
	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR copy: tLayer;  uhandle: Objects.Handler;  gen: PROCEDURE;
	BEGIN
		uhandle := vyPort.LayerHandler;   (* handler of root object*)
		gen := Alloc;   (* gen Procedure as PROCEDURE *)

		WITH o: tLayer DO
			IF M IS Display.DisplayMsg THEN
				WITH M: Display.DisplayMsg DO
					uhandle( o, M );  Recall( o ) (* call root handle first if in background *)
				END;
			ELSIF M IS vyEvents.EventMsg THEN
				WITH M: vyEvents.EventMsg DO
					IF M.callForResponder THEN
						Responsible( o, M );  uhandle( o, M ) (* if not responsible: maybe root is *)
					ELSE
						IF M.gesture = vyEvents.EvtIdent THEN
							IF o.paint = TRUE THEN Respond( o, M ) END
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
						gen;  copy := Objects.NewObj( tLayer );  M.obj := copy;   (* Generator  *)
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
			ELSIF M IS Display.ConsumeMsg THEN
				WITH M: Display.ConsumeMsg DO Consume( o, M );  vyPort.LayerHandler( o, M )
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					HandleAttributes( o, M );
					(*
			IF M.id = Objects.get THEN
			IF M.name = "Gen"THEN
			COPY(GenProc, M.s);   M.class := Objects.String;    M.res := 0
			ELSIF M.name = "paint" THEN M.class := Objects.Bool; M.b := o.paint; M.res := 0
			ELSE uhandle(o, M)
			END
			ELSIF M.id = Objects.enum THEN
			M.Enum("paint"); uhandle(o, M);
			ELSE uhandle(o, M)

			END*)
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					uhandle( o, M )
					(* add own binds here: Bind(o.entry,M) *)
				END;
			ELSE uhandle( o, M )
			END
		END
	END Handler;

	PROCEDURE OpenChart128*( chart: tLayer;  id: vyName.tNameArray );
	BEGIN
		vyPort.OpenLayer( chart, id );  chart.x := vyRealVec.New( 128 );  chart.y := vyRealVec.New( 128 );
		(*	chart.firstUnUsed := 0;*)
		chart.handle := Handler;  chart.paint := TRUE;
		(*! RENAME OpenChart 128 to OpenDrawChart, when should drawing be allowed ? *)
	END OpenChart128;

	PROCEDURE Open*( chart: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;  inconsistentConditions: BOOLEAN;
	BEGIN
		chart.x := vyBase.GetVFromObj( data );  data := data.slink;  chart.y := vyBase.GetVFromObj( data );
		IF (chart.x = NIL ) OR (chart.y = NIL ) THEN vyHostTexts.Msg( "can't plot this data as lines : not the right type!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions )
		ELSIF (chart.x.nrData # chart.y.nrData) THEN vyHostTexts.Msg( "can't plot this data as lines : not the same length!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions )
		END;
		COPY( "lines: ", id );  vyName.AppendObjId( chart.y, id );  vyHostStrings.Append( id, " by " );  vyName.AppendObjId( chart.x, id );
		vyPort.OpenLayer( chart, id );  chart.handle := Handler;  chart.paint := FALSE;
		vyBase.Subscribe( (*for messages from source*) chart.x, chart );
		vyBase.Subscribe( (*for messages from source*) chart.y, chart )
	END Open;

	PROCEDURE OpenO*( chart: tLayer;  x, y: Objects.Object );
	VAR id: vyName.tNameArray;  inconsistentConditions: BOOLEAN;
	BEGIN
		chart.x := vyBase.GetVFromObj( x );  chart.y := vyBase.GetVFromObj( y );
		IF (chart.x = NIL ) OR (chart.y = NIL ) THEN vyHostTexts.Msg( "can't plot this data as lines : not the right type!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions )
		ELSIF (chart.x.nrData # chart.y.nrData) THEN vyHostTexts.Msg( "can't plot this data as lines : not the same length!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions )
		END;
		COPY( "lines: ", id );  vyName.AppendObjId( chart.y, id );  vyHostStrings.Append( id, " by " );  vyName.AppendObjId( chart.x, id );
		vyPort.OpenLayer( chart, id );  chart.handle := Handler;  chart.paint := FALSE;
		vyBase.Subscribe( (*for messages from source*) chart.x, chart );
		vyBase.Subscribe( (*for messages from source*) chart.y, chart )
	END OpenO;

	PROCEDURE OpenL*( chart: tLayer;  data: vyLinks.Link );
	VAR x, y: Objects.Object;
	BEGIN
		x := data.obj;  data := data.link;  y := data.obj;  OpenO( chart, x, y )
	END OpenL;

(*PROCEDURE New*;
VAR layer: tLayer; data: Objects.Object;
BEGIN
IF vyPort.NewObj = NIL THEN RETURN END;
data := vyPort.NewObj;
NEW (layer); Open (layer, data);
vyPort.NewObj := layer
END New;*)

	PROCEDURE New*;
	VAR layer: tLayer;  data: Objects.Object;
	BEGIN
		IF Objects.NewObj # NIL THEN data := Objects.NewObj ELSE RETURN END;
		NEW( layer );  Open( layer, data );  Objects.NewObj := layer
	END New;

	PROCEDURE Alloc*;
	VAR layer: tLayer;
	BEGIN
		NEW( layer );  layer.handle := Handler;  Objects.NewObj := layer;
	END Alloc;

	PROCEDURE ShowP*;
	VAR chart: tLayer;  data: Objects.Object;  pic: vyPort.Picture;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) & (vyBase.parameterCount >= 1) DO
			data.slink := vyBase.NextParObj();   (* y coordinate *)
			NEW( chart );  Open( chart, data );  pic := vyPort.InsertNewVecPicture( chart.x, chart.y );  vyPort.AddLayer( pic, chart );
			Objects.NewObj := pic;  data := vyBase.NextParObj()
		END
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	VAR chart: tLayer;  pic: vyPort.Picture;  i: SIGNED16;
	BEGIN
		WHILE list # NIL DO
			NEW( chart );  OpenL( chart, list );  pic := vyPort.InsertNewVecPicture( chart.x, chart.y );  vyPort.AddLayer( pic, chart );
			FOR i := 1 TO 2 DO
				IF list # NIL THEN
					IF list.link = NIL THEN list := NIL ELSE list := list.link END
				END
			END;
			Objects.NewObj := pic
		END
	END ShowL;

	PROCEDURE ShowO*( x, y: Objects.Object );
	VAR chart: tLayer;  pic: vyPort.Picture;
	BEGIN
		NEW( chart );  OpenO( chart, x, y );  pic := vyPort.InsertNewVecPicture( chart.x, chart.y );  vyPort.AddLayer( pic, chart );
		Objects.NewObj := pic
	END ShowO;

END vyCharts.