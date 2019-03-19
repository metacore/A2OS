MODULE vyGraph IN Oberon;
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


(*
(c) Project Voyager, StatLab Heidelberg
(c) G. Sawitzki, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
(c) F.Friedrich, StatLab Heidelberg
*)


(*= 	Contents definition of an abstract Graph
*)

IMPORT vyHostTexts, vyName, vyRectangles, vyBase, Files, Gadgets, vyGraphBase, Objects, Out;

CONST
	idversion* = "Graph v0r0d4";  rect* = 0;  circle* = 1;  ellipse* = 2;  specialNode* = 0;  normalNode* = 1;

TYPE
	Real = vyBase.Real;

	tEdge* = POINTER TO tEdgeDesc;

	tNode* = POINTER TO tNodeDesc;
	tNodeDesc* = RECORD (Gadgets.ObjDesc)
		x, y: Real;   (* location *)
		name*: vyName.tNameArray;   (* output string *)
		mode: INTEGER;   (* specialNode* = 0 / normalNode* = 1 *)
		mark: BOOLEAN;   (* for algorithmical use *)
		selected: BOOLEAN;   (* *)
		shape, col, bkCol: INTEGER;   (*display attributes *)
		next, nextSelected*: tNode;   (**)
		firstOutEdge: tEdge;   (**)
		firstInEdge: tEdge;   (**)
		inDegree, outDegree: INTEGER;
		vis: BOOLEAN;   (*visible flag*)
	END;

	tNodeOperation* = PROCEDURE ( v: tNode );

	tEdgeDesc* = RECORD (Gadgets.ObjDesc)
		from, to: tNode;
		next: tEdge;
		vis: BOOLEAN;   (*visible flag*)
	END;

	tGraph* = POINTER TO tGraphDesc;
	tGraphDesc* = RECORD (Gadgets.ObjDesc)
		firstNode: tNode;   (* the first vertex in that list is a dummy *)
		firstEdge: tEdge;   (* the first edge in that list is a dummy *)
		fnt: ARRAY 32 OF CHAR
	END;

VAR
	stdFnt: ARRAY 32 OF CHAR;

	PROCEDURE SendMsg( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		IF o.handle # NIL THEN o.handle( o, msg ) END
	END SendMsg;

	PROCEDURE BindIt( o: Objects.Object;  VAR msg: Objects.BindMsg );
	BEGIN
		IF (o # NIL ) & (msg.lib # o.lib) THEN Gadgets.BindObj( o, msg.lib );  SendMsg( o, msg ) END
	END BindIt;

	PROCEDURE StoreNode( VAR R: Files.Rider;  n: tNode );
	BEGIN
		Files.WriteLReal( R, n.x );  Files.WriteLReal( R, n.y );  Files.WriteString( R, n.name );  Files.WriteInt( R, n.mode );
		Files.WriteBool( R, n.mark );  Files.WriteBool( R, n.selected );  Files.WriteInt( R, n.shape );  Files.WriteInt( R, n.col );
		Files.WriteInt( R, n.bkCol );  Files.WriteInt( R, n.inDegree );  Files.WriteInt( R, n.outDegree );
		Files.WriteBool( R, n.vis );  Gadgets.WriteRef( R, n.lib, n.next );  Gadgets.WriteRef( R, n.lib, n.nextSelected );
		Gadgets.WriteRef( R, n.lib, n.firstOutEdge );  Gadgets.WriteRef( R, n.lib, n.firstInEdge )
	END StoreNode;

	PROCEDURE LoadNode( VAR R: Files.Rider;  n: tNode );
	VAR objsub: Objects.Object;
	BEGIN
		Files.ReadLReal( R, n.x );  Files.ReadLReal( R, n.y );  Files.ReadString( R, n.name );  Files.ReadInt( R, n.mode );
		Files.ReadBool( R, n.mark );  Files.ReadBool( R, n.selected );  Files.ReadInt( R, n.shape );  Files.ReadInt( R, n.col );
		Files.ReadInt( R, n.bkCol );  Files.ReadInt( R, n.inDegree );  Files.ReadInt( R, n.outDegree );  Files.ReadBool( R, n.vis );
		Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) & (objsub IS tNode) THEN n.next := objsub( tNode ) END;
		Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) & (objsub IS tNode) THEN n.nextSelected := objsub( tNode ) END;
		Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) & (objsub IS tEdge) THEN n.firstOutEdge := objsub( tEdge ) END;
		Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) & (objsub IS tEdge) THEN n.firstInEdge := objsub( tEdge ) END
	END LoadNode;

	PROCEDURE StoreEdge( VAR R: Files.Rider;  n: tEdge );
	BEGIN
		Files.WriteBool( R, n.vis );  Gadgets.WriteRef( R, n.lib, n.from );  Gadgets.WriteRef( R, n.lib, n.to );
		Gadgets.WriteRef( R, n.lib, n.next )
	END StoreEdge;

	PROCEDURE LoadEdge( VAR R: Files.Rider;  n: tEdge );
	VAR objsub: Objects.Object;
	BEGIN
		Files.ReadBool( R, n.vis );  Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) & (objsub IS tNode) THEN n.from := objsub( tNode ) END;
		Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) & (objsub IS tNode) THEN n.to := objsub( tNode ) END;
		Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) & (objsub IS tEdge) THEN n.next := objsub( tEdge ) END
	END LoadEdge;

	PROCEDURE StoreGraph( VAR R: Files.Rider;  n: tGraph );
	BEGIN
		Files.WriteString( R, n.fnt );  Gadgets.WriteRef( R, n.lib, n.firstNode );  Gadgets.WriteRef( R, n.lib, n.firstEdge )
	END StoreGraph;

	PROCEDURE LoadGraph( VAR R: Files.Rider;  n: tGraph );
	VAR objsub: Objects.Object;
	BEGIN
		Files.ReadString( R, n.fnt );  Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) THEN n.firstNode := objsub( tNode ) END;
		Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) THEN n.firstEdge := objsub( tEdge ) END
	END LoadGraph;

	PROCEDURE EHandler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tEdge DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'vyGraph.GenE', M.s );  M.class := Objects.String;  M.res := 0;  RETURN END
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN LoadEdge( M.R, o )
					ELSIF M.id = Objects.store THEN StoreEdge( M.R, o )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO Out.String( "Bind Msg came,EH" );  Out.Ln();  BindIt( o.from, M );  BindIt( o.to, M );  BindIt( o.next, M )
				END;
			END;   (*WITH*)
			Gadgets.objecthandle( o, M )
		END;   (* tVector*)
	END EHandler;

	PROCEDURE GenE*;
	VAR v: tEdge;
	BEGIN
		NEW( v );  v.handle := EHandler;  Objects.NewObj := v
	END GenE;

	PROCEDURE NHandler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tNode DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'vyGraph.GenN', M.s );  M.class := Objects.String;  M.res := 0;  RETURN END
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN LoadNode( M.R, o )
					ELSIF M.id = Objects.store THEN StoreNode( M.R, o )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					Out.String( "Bind Msg came,NH" );  Out.Ln();  BindIt( o.next, M );  BindIt( o.nextSelected, M );  BindIt( o.firstOutEdge, M );
					BindIt( o.firstInEdge, M )

				END;
			END;   (*WITH*)
			Gadgets.objecthandle( o, M )
		END;   (* tVector*)
	END NHandler;

	PROCEDURE GenN*;
	VAR v: tNode;
	BEGIN
		NEW( v );  v.handle := NHandler;  Objects.NewObj := v
	END GenN;

	PROCEDURE GHandler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tGraph DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'vyGraph.GenG', M.s );  M.class := Objects.String;  M.res := 0;  RETURN END
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN LoadGraph( M.R, o )
					ELSIF M.id = Objects.store THEN StoreGraph( M.R, o )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO Out.String( "Bind Msg came,GH" );  Out.Ln();  BindIt( o.firstNode, M );  BindIt( o.firstEdge, M )
				END;
			END;   (*WITH*)
			Gadgets.objecthandle( o, M )
		END;   (* tVector*)
	END GHandler;

	PROCEDURE GenG*;
	VAR v: tGraph;
	BEGIN
		NEW( v );  v.handle := GHandler;  Objects.NewObj := v
	END GenG;


(** help routines *)
	PROCEDURE Max*( a, b: INTEGER ): INTEGER;
	BEGIN
		IF a > b THEN RETURN a ELSE RETURN b END
	END Max;

	PROCEDURE Copy*( sg, dg: tGraph );
	(*! not yet implemented *)
	BEGIN
		dg := sg
	END Copy;

	PROCEDURE UnmarkGraph( graph: tGraph );
	VAR v: tNode;
	BEGIN
		v := graph.firstNode.next;
		WHILE v # NIL DO v.mark := FALSE;  v := v.next END
	END UnmarkGraph;

	PROCEDURE GetGraphFrame*( graph: tGraph;  VAR x, y, w, h: Real );
	(*= returns the size of the visible(!) subgraph *)
	VAR xMax, yMax: Real;  v: tNode;
	BEGIN
		x := 0;  y := 0;  w := 0;  h := 0;  v := graph.firstNode.next;
		WHILE (v # NIL ) & ~(v.vis) DO v := v.next END;
		IF v # NIL THEN x := v.x;  y := v.y;  xMax := x;  yMax := y END;
		WHILE v # NIL DO
			IF v.vis THEN
				IF v.x < x THEN x := v.x END;
				IF v.x > xMax THEN xMax := v.x END;
				IF v.y < y THEN y := v.y END;
				IF v.y > yMax THEN yMax := v.y END
			END;
			v := v.next
		END;
		w := xMax - x;  h := yMax - y;
		IF w = 0 THEN w := 1 END;
		IF h = 0 THEN h := 1 END
	END GetGraphFrame;

	PROCEDURE GetGraphSize*( graph: tGraph;  VAR nrVertices, nrEdges: INTEGER );
	(*= returns the number of vertices (=m) and edges (=n) of the complete graph *)
	VAR vertex: tNode;  edge: tEdge;
	BEGIN
		nrVertices := 0;  nrEdges := 0;  vertex := graph.firstNode.next;
		WHILE (vertex # NIL ) DO INC( nrVertices );  vertex := vertex.next END;
		edge := graph.firstEdge.next;
		WHILE edge # NIL DO INC( nrEdges );  edge := edge.next END
	END GetGraphSize;

	PROCEDURE GetFont*( graph: tGraph;  VAR fnt: ARRAY OF CHAR );
	BEGIN
		COPY( graph.fnt, fnt )
	END GetFont;

	PROCEDURE ChangeFont*( graph: tGraph;  fnt: ARRAY OF CHAR );
	BEGIN
		COPY( fnt, graph.fnt )
	END ChangeFont;

	PROCEDURE GetName*( v: tNode;  VAR id: vyName.tNameArray );
	BEGIN
		IF v # NIL THEN id := v.name END
	END GetName;

	PROCEDURE GetNodeByName*( graph: tGraph;  name: vyName.tNameArray ): tNode;
	VAR v: tNode;
	BEGIN
		v := graph.firstNode.next;
		WHILE v # NIL DO
			IF v.name = name THEN RETURN v END;
			v := v.next
		END;
		RETURN NIL
	END GetNodeByName;

	PROCEDURE Selected*( vertex: tNode ): BOOLEAN;
	BEGIN
		RETURN vertex.selected
	END Selected;

	PROCEDURE GetNodeRect*( graph: tGraph;  v: tNode;  VAR x, y, w, h, dsr: INTEGER );
	BEGIN
		vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );
		vyGraphBase.GetStringFrame2d( v.x, v.y, graph.fnt, v.name, x, y, w, h, dsr );  x := x - 2;  w := w + 2
	END GetNodeRect;

	PROCEDURE ThisNode*( graph: tGraph;  x, y: Real ): tNode;
	VAR dist, thisDist: Real;  v, this: tNode;  px, py, X, Y, W, H, dsr: INTEGER;

		PROCEDURE Distance( ): Real;
		BEGIN
			RETURN (ABS( v.x - x ) + ABS( v.y - y ))
		END Distance;

	BEGIN
		v := graph.firstNode.next;
		IF v = NIL THEN RETURN NIL END;
		this := v;  thisDist := Distance();  v := v.next;
		WHILE (v # NIL ) DO
			dist := Distance();
			IF dist < thisDist THEN this := v;  thisDist := dist END;
			v := v.next
		END;

		GetNodeRect( graph, this, X, Y, W, H, dsr );  vyGraphBase.Point2dToPoint( x, y, px, py );
		IF vyRectangles.PointInRect( px, py, X, Y, W, H ) THEN RETURN this ELSE RETURN NIL END;
		(* return v only if x, y is inside the vertex *)
		RETURN this
	END ThisNode;

(** drawing routines *)
	PROCEDURE RecallNode( graph: tGraph;  v: tNode );
	VAR x, y, w, h, dsr: INTEGER;  oldCol, oldBkCol: LONGINT;  dsrr, temp: Real;
		name: ARRAY 32 OF CHAR;

		PROCEDURE DrawNode( v: tNode );
		(** vs 0.0d0 *)  (* md  03.05.95 09:42:17 *)
		BEGIN
			IF v.shape = circle THEN vyGraphBase.FrameCircle( x + (w DIV 2), y + (h DIV 2), Max( w DIV 2, h DIV 2 ) )
			ELSIF v.shape = ellipse THEN vyGraphBase.FrameEllipse( x + (w DIV 2), y + (h DIV 2), w DIV 2, h DIV 2 )
			ELSE  (* treat it as a rectangle *)
				IF v.mode = specialNode THEN
					vyGraphBase.EraseRect( x - 3, y - 2, w + 5, h + 4 );  vyGraphBase.FrameRect( x - 1, y, w + 1, h );
					vyGraphBase.FrameRect( x - 3, y - 2, w + 5, h + 4 )
				ELSE vyGraphBase.EraseRect( x, y, w, h );  vyGraphBase.FrameRect( x - 1, y, w + 1, h )
				END
			END
		END DrawNode;

	BEGIN
		vyGraphBase.GetForeColor( oldCol );  vyGraphBase.GetBackColor( oldBkCol );
		IF v.col = -1 THEN
			vyGraphBase.SetForeColor( vyGraphBase.S.fcol );  vyGraphBase.SetBackColor( vyGraphBase.S.fillcol );
			IF v.selected THEN vyGraphBase.SetBackColor( vyGraphBase.S.selectcol ) END
		ELSE vyGraphBase.SetForeColor( v.col );  vyGraphBase.SetBackColor( v.bkCol )
		END;
		COPY( v.name, name );
		(*
IF (v.mode # specialNode)  & (~v.selected)  THEN
v.name[6] := 0X
END;
*)
		(* fof 020323*)

		GetNodeRect( graph, v, x, y, w, h, dsr );  y := y - 1;  h := h + 2;  w := w + 1;  DrawNode( v );
		vyGraphBase.VectorToVector2d( 0, dsr, temp, dsrr );  vyGraphBase.String2d( v.x, v.y + dsrr, graph.fnt, v.name );

		IF v.col # -1 THEN
			IF v.selected THEN vyGraphBase.InvertRect( x, y, w + 1, h ) END
		END;

		COPY( name, v.name );  vyGraphBase.SetForeColor( oldCol );  vyGraphBase.SetBackColor( oldBkCol )
	END RecallNode;

	PROCEDURE RecallEdge( g: tGraph;  e: tEdge );
	VAR  (*x, y, w, h, X, Y, W, H: INTEGER;*) x, y: INTEGER;
	BEGIN
		(*GetNodeRect (g, e.from, x, y, w, h); GetNodeRect (g, e.to, X, Y, W, H);
vyGraphBase.Line (x+w DIV 2, y+h, X+W DIV 2, Y)*)
		vyGraphBase.SetForeColor( vyGraphBase.S.fcol );  vyGraphBase.Line2d( e.from.x, e.from.y, e.to.x, e.to.y );
		vyGraphBase.Point2dToPoint( e.to.x + (e.from.x - e.to.x) / 4, e.to.y + (e.from.y - e.to.y) / 4, x, y );
		vyGraphBase.FrameRect( x - 1, y - 1, 3, 3 )
	END RecallEdge;

	PROCEDURE Recall*( graph: tGraph );
	VAR e: tEdge;  v: tNode;
	BEGIN
		vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );

		e := graph.firstEdge.next;
		WHILE e # NIL DO
			IF e.vis THEN RecallEdge( graph, e ) END;
			e := e.next
		END;

		v := graph.firstNode.next;
		WHILE v # NIL DO
			IF v.vis THEN RecallNode( graph, v ) END;
			v := v.next
		END
	END Recall;



(** selection support *)
	PROCEDURE SelectionActor*( graph: tGraph;  x0O, y0O, x1O, y1O, x0N, y0N, x1N, y1N: Real;  mode: INTEGER );
	(*vs 0.0a1	md  16.08.94 *)
	(* mode meaning:
add=2;
define=0;
invert=1;
remove=3;
*)
	VAR v: tNode;  i: LONGINT;  inNew, inOld, chg: BOOLEAN;

		PROCEDURE PointInRect( px, py, x0, y0, x1, y1: Real ): BOOLEAN;
		BEGIN
			RETURN (x0 <= px) & (px <= x1) & (y0 <= py) & (py <= y1)
		END PointInRect;

	BEGIN
		v := graph.firstNode.next;  i := 0;
		WHILE (v # NIL ) DO
			IF v.vis THEN
				inNew := PointInRect( v.x, v.y, x0N, y0N, x1N, y1N );  inOld := PointInRect( v.x, v.y, x0O, y0O, x1O, y1O );
				IF mode = 0 THEN  (*define*)
					chg := (inNew & ~inOld) OR (~inNew & inOld)
				ELSIF mode = 1 THEN  (*invert*)
					chg := (inNew & ~inOld) OR (~inNew & inOld)
				ELSIF mode = 2 THEN  (*add*)
					chg := (inNew & ~inOld & ~v.selected) OR (~inNew & inOld & v.selected)
				ELSIF (mode = 3) & (v.selected) THEN  (*remove*)
					chg := (inNew & ~inOld) OR (~inNew & inOld)
				END;
				IF chg THEN v.selected := ~v.selected;  RecallNode( graph, v ) END
			END;
			v := v.next
		END
	END SelectionActor;

	PROCEDURE GetSelection*( graph: tGraph ): tNode;
	VAR v, first, next: tNode;
	BEGIN
		first := NIL;  v := graph.firstNode.next;
		WHILE (v # NIL ) DO
			IF v.selected THEN
				IF first = NIL THEN first := v ELSE next.nextSelected := v END;
				next := v;  next.nextSelected := NIL
			END;
			v := v.next
		END;
		RETURN first
	END GetSelection;

	PROCEDURE SelectNode*( graph: tGraph;  sv: tNode );
	BEGIN
		IF sv = NIL THEN RETURN END;
		vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );
		IF sv # NIL THEN sv.selected := TRUE;  RecallNode( graph, sv ) END
	END SelectNode;

	PROCEDURE ClearSelection*( graph: tGraph );
	VAR v: tNode;
	BEGIN
		v := graph.firstNode.next;
		WHILE (v # NIL ) DO
			IF v.selected THEN v.selected := FALSE;  RecallNode( graph, v ) END;
			v := v.next
		END
	END ClearSelection;

(** construction support: Add/Hide/Remove of edges, vertices and selections *)
	PROCEDURE AddNode*( graph: tGraph;  v: tNode;  x, y: Real;  name: vyName.tNameArray;  mode, shape, col, bkCol: INTEGER );
	VAR eo, ei: tEdge;
	BEGIN
		IF v.handle = NIL THEN v.handle := NHandler END;
		v.x := x;  v.y := y;  COPY( name, v.name );  v.selected := FALSE;  v.mode := mode;  v.shape := shape;  v.col := col;
		v.bkCol := bkCol;  v.next := graph.firstNode.next;  graph.firstNode.next := v;  NEW( eo );  eo.from := NIL;  eo.to := NIL;
		eo.next := NIL;  eo.vis := FALSE;  v.firstOutEdge := eo;
		IF eo.handle = NIL THEN eo.handle := EHandler END;
		NEW( ei );  ei.from := NIL;  ei.to := NIL;  ei.next := NIL;  ei.vis := FALSE;  v.firstInEdge := ei;
		IF ei.handle = NIL THEN ei.handle := EHandler END;
		v.inDegree := 0;  v.outDegree := 0;  v.vis := TRUE
	END AddNode;

	PROCEDURE AddEdge*( graph: tGraph;  e: tEdge;  from, to: tNode );
	VAR veo, vei: tEdge;
	BEGIN
		ASSERT ( from # to );   (*! no support of loops *)
		IF e.handle = NIL THEN e.handle := EHandler END;
		e.from := from;  e.to := to;  e.next := graph.firstEdge.next;  graph.firstEdge.next := e;  e.vis := TRUE;  NEW( veo );
		veo.from := from;  veo.to := to;  veo.vis := TRUE;  veo.next := from.firstOutEdge.next;  from.firstOutEdge.next := veo;
		INC( from.outDegree );
		IF veo.handle = NIL THEN veo.handle := EHandler END;
		NEW( vei );  vei.from := from;  vei.to := to;  vei.vis := TRUE;  vei.next := to.firstInEdge.next;  to.firstInEdge.next := vei;
		INC( to.inDegree );
		IF vei.handle = NIL THEN vei.handle := EHandler END
	END AddEdge;

	PROCEDURE DeleteEdge( graph: tGraph;  from, to: tNode );
	VAR le: tEdge;
	BEGIN
		(* delete it from the graphs edge list *)
		le := graph.firstEdge;
		WHILE (le # NIL ) & ((le.next.from # from) OR (le.next.to # to)) DO le := le.next END;
		ASSERT ( le # NIL );
		le.next := le.next.next;
		(* delete it from the edgelist of the source vertex *)
		le := from.firstOutEdge;
		WHILE (le # NIL ) & ((le.next.from # from) OR (le.next.to # to)) DO le := le.next END;
		ASSERT ( le # NIL );
		le.next := le.next.next;  from.outDegree := from.outDegree - 1;
		(* delete it from the edgelist of the sink vertex *)
		le := to.firstInEdge;
		WHILE (le # NIL ) & ((le.next.from # from) OR (le.next.to # to)) DO le := le.next END;
		ASSERT ( le # NIL );
		le.next := le.next.next;  to.inDegree := to.inDegree - 1
	END DeleteEdge;

	PROCEDURE DeleteNode*( graph: tGraph;  v: tNode );
	VAR lv: tNode;  e, ne: tEdge;
	BEGIN
		(* delee all incoming edges*)
		e := v.firstInEdge.next;
		WHILE e # NIL DO ne := e.next;  DeleteEdge( graph, e.from, e.to );  e := ne END;
		(*delete all outgoing edges*)
		e := v.firstOutEdge.next;
		WHILE e # NIL DO ne := e.next;  DeleteEdge( graph, e.from, e.to );  e := ne END;
		(*delete the vertex*)
		lv := graph.firstNode;
		WHILE (lv # NIL ) & (lv.next # v) DO lv := lv.next END;
		ASSERT ( lv # NIL );
		lv.next := lv.next.next
	END DeleteNode;

	PROCEDURE DeleteSelection*( graph: tGraph );
	VAR vertex: tNode;
	BEGIN
		vertex := graph.firstNode.next;
		WHILE (vertex # NIL ) DO
			IF vertex.selected THEN DeleteNode( graph, vertex ) END;
			vertex := vertex.next
		END
	END DeleteSelection;

	PROCEDURE HideEdge( graph: tGraph;  from, to: tNode );
	VAR le: tEdge;
	BEGIN
		(* hide it in the graphs edge list *)
		le := graph.firstEdge;
		WHILE (le # NIL ) & ((le.from # from) OR (le.to # to)) DO le := le.next END;
		ASSERT ( le # NIL );
		le.vis := FALSE;
		(* hide it in the edgelist of the source vertex *)
		le := from.firstOutEdge;
		WHILE (le # NIL ) & ((le.from # from) OR (le.to # to)) DO le := le.next END;
		ASSERT ( le # NIL );
		le.vis := FALSE;  from.outDegree := from.outDegree - 1;   (*!? what's about the degrees ? *)
		(* hide it in the edgelist of the sink vertex *)
		le := to.firstInEdge;
		WHILE (le # NIL ) & ((le.from # from) OR (le.to # to)) DO le := le.next END;
		ASSERT ( le # NIL );
		le.vis := FALSE;  to.inDegree := to.inDegree - 1
	END HideEdge;

	PROCEDURE HideNode( graph: tGraph;  v: tNode );
	VAR lv: tNode;  e: tEdge;
	BEGIN
		(* hide all incoming edges*)
		e := v.firstInEdge.next;
		WHILE e # NIL DO HideEdge( graph, e.from, e.to );  e := e.next END;
		(* hide all outgoing edges*)
		e := v.firstOutEdge.next;
		WHILE e # NIL DO HideEdge( graph, e.from, e.to );  e := e.next END;
		(* hide the vertex*)
		lv := graph.firstNode.next;
		WHILE (lv # NIL ) & (lv # v) DO lv := lv.next END;
		ASSERT ( lv # NIL );
		lv.vis := FALSE
	END HideNode;

	PROCEDURE HideSelection*( graph: tGraph );
	VAR vertex: tNode;
	BEGIN
		vertex := graph.firstNode.next;
		WHILE (vertex # NIL ) DO
			IF vertex.selected THEN vertex.selected := FALSE;  HideNode( graph, vertex ) END;
			vertex := vertex.next
		END
	END HideSelection;

	PROCEDURE FlipVisible*( graph: tGraph );
	VAR v: tNode;
	BEGIN
		v := graph.firstNode.next;
		WHILE (v # NIL ) DO v.selected := FALSE;  v.vis := ~v.vis;  v := v.next END
	END FlipVisible;

	PROCEDURE ShowAll*( graph: tGraph );
	VAR vertex: tNode;  edge: tEdge;

		PROCEDURE ShowNode( v: tNode );
		VAR e: tEdge;
		BEGIN
			v.vis := TRUE;  e := v.firstOutEdge.next;
			WHILE (e # NIL ) DO e.vis := TRUE;  e := e.next END;
			e := v.firstInEdge.next;
			WHILE (e # NIL ) DO e.vis := TRUE;  e := e.next END
		END ShowNode;

	BEGIN
		vertex := graph.firstNode.next;
		WHILE (vertex # NIL ) DO ShowNode( vertex );  vertex := vertex.next END;
		edge := graph.firstEdge.next;
		WHILE edge # NIL DO edge.vis := TRUE;  edge := edge.next END
	END ShowAll;


	(** collapse/expand *)
(*! not yet implemented *)
	PROCEDURE Collapse*( graph: tGraph );
	END Collapse;

	PROCEDURE Expand*( graph: tGraph;  vertex: tNode );
	END Expand;

(** placing support *)
	PROCEDURE MoveNode*( graph: tGraph;  v: tNode;  dx, dy: INTEGER );
	VAR dx2d, dy2d: Real;
	BEGIN
		vyGraphBase.VectorToVector2d( dx, dy, dx2d, dy2d );  v.x := v.x + dx2d;  v.y := v.y + dy2d
	END MoveNode;

	PROCEDURE MoveSelection*( graph: tGraph;  dx, dy: INTEGER );
	VAR dx2d, dy2d: Real;  v: tNode;
	BEGIN
		vyGraphBase.VectorToVector2d( dx, dy, dx2d, dy2d );  v := graph.firstNode.next;
		WHILE (v # NIL ) DO
			IF v.selected THEN v.x := v.x + dx2d;  v.y := v.y + dy2d END;
			v := v.next
		END
	END MoveSelection;

	PROCEDURE PlaceNode*( graph: tGraph;  v: tNode;  x, y: Real );
	BEGIN
		v.x := x;  v.y := y
	END PlaceNode;

	PROCEDURE GetNodePlace*( graph: tGraph;  v: tNode;  VAR x, y: Real );
	BEGIN
		x := v.x;  y := v.y
	END GetNodePlace;

	PROCEDURE ClusterNode*( v: tNode );
	VAR e: tEdge;  nr: INTEGER;  i, dx: Real;
	BEGIN
		e := v.firstOutEdge.next;  nr := 0;
		WHILE (e # NIL ) DO INC( nr );  e := e.next END;
		dx := 1 / nr;  i := -nr / 2;  e := v.firstOutEdge.next;
		WHILE (e # NIL ) DO e.to.x := v.x + i * dx;  e.to.y := v.y + 1 + i * dx * 0.75;  e := e.next;  i := i + 1 END;
		e := v.firstInEdge.next;  nr := 0;
		WHILE (e # NIL ) DO INC( nr );  e := e.next END;
		dx := 1 / nr;  i := -nr / 2;  e := v.firstInEdge.next;
		WHILE (e # NIL ) DO e.from.x := v.x + i * dx;  e.from.y := v.y - 1 + i * dx * 0.75;  e := e.next;  i := i + 1 END
	END ClusterNode;

	PROCEDURE AlignSelection*( graph: tGraph;  horizontal: BOOLEAN );
	VAR min, max, d, pos, c: Real;  count, done: INTEGER;  v, next: tNode;
	BEGIN
		count := 0;  c := 0;  v := graph.firstNode.next;
		WHILE (v # NIL ) DO
			IF v.selected THEN
				INC( count );
				IF count = 1 THEN
					IF horizontal THEN c := c + v.y;  min := v.x;  max := v.x ELSE c := c + v.x;  min := v.y;  max := v.y END
				ELSE
					IF horizontal THEN
						c := c + v.y;
						IF v.x < min THEN min := v.x END;
						IF max < v.x THEN max := v.x END
					ELSE
						c := c + v.x;
						IF v.y < min THEN min := v.y END;
						IF max < v.y THEN max := v.y END
					END
				END

			END;   (*IF v.selected*)
			v := v.next
		END;

		IF count < 2 THEN RETURN
		END;
		pos := min;  d := (max - min) / (count - 1);  done := 0;  c := c / count;

		UnmarkGraph( graph );
		IF horizontal THEN
			WHILE count > done DO
				min := max;  v := graph.firstNode.next;
				WHILE (v # NIL ) DO
					IF (v.selected) & ~(v.mark) & (v.x <= min) THEN next := v;  min := v.x END;
					v := v.next
				END;
				next.x := pos;  pos := pos + d;  next.y := c;  next.mark := TRUE;  INC( done )
			END
		ELSE
			WHILE count > done DO
				min := max;  v := graph.firstNode.next;
				WHILE (v # NIL ) DO
					IF (v.selected) & ~(v.mark) & (v.y <= min) THEN next := v;  min := v.y END;
					v := v.next
				END;
				next.y := pos;  pos := pos + d;  next.x := c;  next.mark := TRUE;  INC( done )
			END
		END;   (* of horizontal *)
	END AlignSelection;


(** Open *)
	PROCEDURE OpenGraph*( graph: tGraph );
	VAR e: tEdge;  v: tNode;
	BEGIN
		NEW( v );  v.x := 0;  v.y := 0;  v.name := "dummy";  v.mode := 0;  v.next := NIL;  v.vis := FALSE;  v.handle := NHandler;  NEW( e );  e.from := v;
		e.to := v;  e.next := NIL;  e.vis := FALSE;  e.handle := EHandler;  graph.firstNode := v;  graph.firstEdge := e;
		COPY( stdFnt, graph.fnt );  graph.handle := GHandler
	END OpenGraph;


(** sorting stuff *)
	PROCEDURE InvertNodeOrder( g: tGraph );
	VAR v0, v1, v2: tNode;
	BEGIN
		IF (g.firstNode.next = NIL ) OR (g.firstNode.next.next = NIL ) THEN RETURN END;
		v0 := g.firstNode.next;  v1 := v0.next;  v2 := v1.next;  v0.next := NIL;  v1.next := v0;
		WHILE v2 # NIL DO v0 := v1;  v1 := v2;  v2 := v2.next;  v1.next := v0 END;
		g.firstNode.next := v1
	END InvertNodeOrder;

	PROCEDURE InvertOutEdgeOrder( v: tNode );
	VAR e0, e1, e2: tEdge;
	BEGIN
		IF (v.firstOutEdge.next = NIL ) OR (v.firstOutEdge.next.next = NIL ) THEN RETURN END;
		e0 := v.firstOutEdge.next;  e1 := e0.next;  e2 := e1.next;  e0.next := NIL;  e1.next := e0;
		WHILE e2 # NIL DO e0 := e1;  e1 := e2;  e2 := e2.next;  e1.next := e0 END;
		v.firstOutEdge.next := e1
	END InvertOutEdgeOrder;

(*	PROCEDURE SortVerticesByOutDegree (g: tGraph; ascendent: BOOLEAN);
VAR v, prev, scan: tNode;
BEGIN
prev := g.firstNode.next; v := prev.next;
WHILE v#NIL DO
IF v.outDegree>prev.outDegree THEN
scan := g.firstNode;
WHILE scan.next.outDegree>v.outDegree DO scan := scan.next END;
prev.next := v.next;
v.next := scan.next;
scan.next := v;
v := prev.next;
ELSE
v := v.next;
prev := prev.next;
END;
END;

IF ascendent THEN InvertNodeOrder (g) END;
END SortVerticesByOutDegree;
*)
	PROCEDURE SortVerticesByInDegree( g: tGraph;  ascendent: BOOLEAN );
	VAR v, prev, scan: tNode;
	BEGIN
		prev := g.firstNode.next;  v := prev.next;
		WHILE v # NIL DO
			IF v.inDegree > prev.inDegree THEN
				scan := g.firstNode;
				WHILE scan.next.inDegree > v.inDegree DO scan := scan.next END;
				prev.next := v.next;  v.next := scan.next;  scan.next := v;  v := prev.next
			ELSE v := v.next;  prev := prev.next
			END
		END;

		IF ascendent THEN InvertNodeOrder( g )
		END
	END SortVerticesByInDegree;

	PROCEDURE SortEdgesByInDegree( g: tGraph;  ascendent: BOOLEAN );
	VAR e, prev, scan: tEdge;  v: tNode;
	BEGIN
		v := g.firstNode.next;
		WHILE v # NIL DO
			prev := v.firstOutEdge.next;
			IF prev # NIL THEN
				e := prev.next;
				WHILE e # NIL DO
					IF e.to.inDegree > prev.to.inDegree THEN
						scan := v.firstOutEdge;
						WHILE scan.next.to.inDegree > e.to.inDegree DO scan := scan.next END;
						prev.next := e.next;  e.next := scan.next;  scan.next := e;  e := prev.next
					ELSE e := e.next;  prev := prev.next
					END
				END
			END;
			IF ascendent THEN InvertOutEdgeOrder( v ) END;
			v := v.next
		END;

		IF ascendent THEN
		END
	END SortEdgesByInDegree;

	PROCEDURE AddRoot( g: tGraph ): tNode;
	(*= adds a vertex as root to all selected vertices
if there is no selection, it will be connected to all vertices with indegree = 0 *)
	VAR root, v: tNode;  e: tEdge;  name: vyName.tNameArray;
	BEGIN
		name := "root";   (* fof, dismisses weird error "not yet implemented" *)
		NEW( root );  AddNode( g, root, 0, 0, name, normalNode, rect, 15, 0 );  v := GetSelection( g );
		IF v # NIL THEN
			WHILE v # NIL DO
				IF (v # root) THEN NEW( e );  AddEdge( g, e, root, v ) END;
				v := v.nextSelected
			END
		ELSE
			v := g.firstNode.next;
			WHILE v # NIL DO
				IF (v # root) & (v.inDegree = 0) THEN NEW( e );  AddEdge( g, e, root, v ) END;
				v := v.next
			END
		END;

		RETURN root
	END AddRoot;

	PROCEDURE DFSSortRec( graph: tGraph;  root: tNode );
	VAR nr, i: INTEGER;  e: tEdge;  dx: Real;
	BEGIN
		root.mark := TRUE;  e := root.firstOutEdge.next;
		IF e = NIL THEN RETURN END;
		nr := 0;
		WHILE e # NIL DO INC( nr );  e := e.next END;
		dx := 1 / nr;  e := root.firstOutEdge.next;  i := 0;
		WHILE e # NIL DO
			IF (e.to.y <= root.y) & (e.to.vis) THEN
				dx := -dx;  e.to.x := root.x + i * dx;  e.to.y := root.y + 1 - i * dx * 0.75;  INC( i );  DFSSortRec( graph, e.to )
			END;
			e := e.next
		END
	END DFSSortRec;

	PROCEDURE DFSSort*( graph: tGraph );
	VAR root: tNode;
	BEGIN
		SortVerticesByInDegree( graph, TRUE );  SortEdgesByInDegree( graph, TRUE );  root := AddRoot( graph );
		UnmarkGraph( graph );  DFSSortRec( graph, root );  DeleteNode( graph, root )
	END DFSSort;

	PROCEDURE PreOrder*( g: tGraph );
	(*! not yet implemented *)
	(*= *)
	VAR root: tNode;
	BEGIN
		root := AddRoot( g );

		DeleteNode( g, root )
	END PreOrder;

(** vertex operation *)
	PROCEDURE DFS*( graph: tGraph;  start: tNode;  op: tNodeOperation );
	(*! not yet implemented *)
	(*=  in the order of the DFS algorithm (starting by vertex start) the operation op
will be done for each vertex reachable from start *)
	BEGIN
		UnmarkGraph( graph )

	END DFS;

	PROCEDURE ForEachNodeDo*( graph: tGraph;  op: tNodeOperation );
	VAR v: tNode;
	BEGIN
		v := graph.firstNode.next;
		WHILE v # NIL DO op( v );  v := v.next END
	END ForEachNodeDo;

	PROCEDURE ForEachFollowNodeDo*( v: tNode;  op: tNodeOperation );
	(** vs 0.0d0 *)  (* md  17.05.95 14:21:00 *)
	VAR e: tEdge;
	BEGIN
		e := v.firstOutEdge.next;
		WHILE (e # NIL ) DO op( e.to );  e := e.next END
	END ForEachFollowNodeDo;

	PROCEDURE ForEachPrevNodeDo*( v: tNode;  op: tNodeOperation );
	(** vs 0.0d0 *)  (* md  17.05.95 14:21:00 *)
	VAR e: tEdge;
	BEGIN
		e := v.firstInEdge.next;
		WHILE (e # NIL ) DO op( e.from );  e := e.next END
	END ForEachPrevNodeDo;

(** component support *)
	PROCEDURE DFSReachableRec( root, goal: tNode ): BOOLEAN;
	VAR e: tEdge;
	BEGIN
		e := root.firstOutEdge.next;
		IF e = NIL THEN RETURN FALSE END;
		WHILE e # NIL DO
			e.to.mark := TRUE;
			IF (e.to = goal) OR DFSReachableRec( e.to, goal ) THEN RETURN TRUE END;
			e := e.next
		END;
		RETURN FALSE
	END DFSReachableRec;

	PROCEDURE Reachable*( g: tGraph;  from, to: tNode ): BOOLEAN;
	BEGIN
		UnmarkGraph( g );  RETURN (from = to) OR (DFSReachableRec( from, to ))
	END Reachable;

	PROCEDURE Component*( g: tGraph;  v: tNode ): tGraph;
	VAR cg: tGraph;  lv, nv: tNode;
	BEGIN
		Copy( g, cg );  cg := g;  lv := cg.firstNode.next;
		WHILE lv # NIL DO
			nv := lv.next;
			IF ~(Reachable( g, lv, v ) OR Reachable( g, v, lv )) THEN DeleteNode( g, lv ) END;
			lv := nv
		END;
		RETURN cg
	END Component;

(** dumps *)
	PROCEDURE DumpPrevNode( v: tNode );
	BEGIN
		vyHostTexts.MsgSS( v.name, " _____>" )
	END DumpPrevNode;

	PROCEDURE DumpFollowNode( v: tNode );
	BEGIN
		vyHostTexts.MsgSS( " <_____", v.name )
	END DumpFollowNode;

	PROCEDURE DumpNode( v: tNode );
	BEGIN
		vyHostTexts.Msg( v.name );  ForEachPrevNodeDo( v, DumpPrevNode );  ForEachFollowNodeDo( v, DumpFollowNode )
	END DumpNode;

	PROCEDURE DumpGraph*( graph: tGraph );
	BEGIN
		ForEachNodeDo( graph, DumpNode )
	END DumpGraph;

BEGIN
	COPY( "System10.Scn.Fnt", stdFnt )
END vyGraph.
