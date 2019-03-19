MODULE antsDependency IN Oberon;   (** fof  **)
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




IMPORT Display, vyBase, vyName, vyGraphBase, vyDisplay2d, vyPort, vyEvents, vyLinks, antsObjects, aM := antsMessages,
	vyTracking, Files, vyHighlight, Gadgets, vyGraph := antsGraph, Objects, antsCommands, vyCommandMenus;

TYPE
	Real = LONGREAL;

	tNode = POINTER TO tNodeDesc;
	tNodeDesc = RECORD (vyGraph.tNodeDesc)
		o: Objects.Object;
		dir: INTEGER;
		level, levelpos: INTEGER
	END;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		graph: vyGraph.tGraph;
		root: vyBase.Object
	END;

CONST
	sourcenode = 1;  usernode = 2;

VAR
	gNode: tNode;  gObject: Objects.Object;
	minlevel, maxlevel: INTEGER;
	currange: POINTER TO ARRAY OF INTEGER;
	graph: vyGraph.tGraph;   (* temp *)
	min, max: INTEGER;  rangex: LONGREAL;  tempLayer: tLayer;  vvv: tNode;

	PROCEDURE StoreNode( VAR R: Files.Rider;  n: tNode );
	BEGIN
		Gadgets.WriteRef( R, n.lib, n.o )
	END StoreNode;

	PROCEDURE LoadNode( VAR R: Files.Rider;  n: tNode );
	VAR objsub: Objects.Object;
	BEGIN
		Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) THEN n.o := objsub( vyBase.Object ) END
	END LoadNode;

	PROCEDURE NHandler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: tNode DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsDependency.GenN', M.s );  M.class := Objects.String;  M.res := 0;  RETURN END
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
					IF o.lib # M.lib THEN
						vyGraph.NHandler( o, M );
						IF o.o # NIL THEN antsObjects.Bind( o.o, M ) END
					END
				END;
			END;   (*WITH*)
			vyGraph.NHandler( o, M )
		END;   (* tVector*)
	END NHandler;

	PROCEDURE GenN*;
	VAR v: tNode;
	BEGIN
		aM.cmd;  NEW( v );  v.handle := NHandler;  Objects.NewObj := v
	END GenN;

	PROCEDURE Select( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR x0, y0, x1O, y1O, x1N, y1N: INTEGER;  X0, Y0, X1O, Y1O, X1N, Y1N: Real;  node: vyGraph.tNode;  link: vyLinks.Link;

		PROCEDURE Frame( x, y, u, v: INTEGER );
		VAR w, h, r: INTEGER;
		BEGIN
			vyGraphBase.SetDisplayMode( vyGraphBase.invert );
			IF u < x THEN r := u;  u := x;  x := r END;
			IF v < y THEN r := v;  v := y;  y := r END;
			w := u - x;  h := v - y;  vyGraphBase.FrameRect( x, y, w, h )
		END Frame;

		PROCEDURE DoSelection;
		VAR X0Or, Y0Or, X1Or, Y1Or, X0Nr, Y0Nr, X1Nr, Y1Nr: Real;

			PROCEDURE RegRect( x0, y0, x1, y1: Real;  VAR x0r, y0r, x1r, y1r: Real );
			VAR r: Real;
			BEGIN
				x0r := x0;  y0r := y0;  x1r := x1;  y1r := y1;
				IF x1r < x0r THEN r := x0r;  x0r := x1r;  x1r := r END;
				IF y1r < y0r THEN r := y0r;  y0r := y1r;  y1r := r END
			END RegRect;

		BEGIN
			vyGraphBase.PointToPoint2d( x0, y0, X0, Y0 );  vyGraphBase.PointToPoint2d( x1O, y1O, X1O, Y1O );
			vyGraphBase.PointToPoint2d( x1N, y1N, X1N, Y1N );  RegRect( X0, Y0, X1O, Y1O, X0Or, Y0Or, X1Or, Y1Or );
			RegRect( X0, Y0, X1N, Y1N, X0Nr, Y0Nr, X1Nr, Y1Nr );
			vyGraph.SelectionActor( layer.graph, X0Or, Y0Or, X1Or, Y1Or, X0Nr, Y0Nr, X1Nr, Y1Nr, vyHighlight.selectionMode )
		END DoSelection;

	BEGIN
		IF vyHighlight.selectionMode = vyHighlight.define THEN vyGraph.ClearSelection( layer.graph ) END;
		x0 := event.x;  y0 := event.y;  x1O := x0;  y1O := y0;
		WHILE (event.gesture = vyEvents.EvtSelect) & (x0 = event.x) & (y0 = event.y) DO vyEvents.GetEvent( event ) END;

		vyGraphBase.PointToPoint2d( x0, y0, X0, Y0 );
		vyGraph.SelectNode( layer.graph, vyGraph.ThisNode( layer.graph, X0, Y0 ) );
		IF event.gesture # vyEvents.EvtSelect THEN vyBase.Update( layer );  RETURN END;

		x1N := event.x;  y1N := event.y;

		DoSelection;  Frame( x0, y0, x1N, y1N );

		vyEvents.GetEvent( event );
		WHILE event.gesture = vyEvents.EvtSelect DO
			IF (event.x # x1N) OR (event.y # y1N) THEN
				Frame( x0, y0, x1N, y1N );  x1O := x1N;  y1O := y1N;  x1N := event.x;  y1N := event.y;  DoSelection;
				Frame( x0, y0, x1N, y1N )
			END;
			vyEvents.GetEvent( event )
		END;
		Frame( x0, y0, x1N, y1N );
		IF event.gesture = vyEvents.EvtRemove THEN
			node := vyGraph.GetSelection( layer.graph );
			WHILE node # NIL DO vyGraph.DeleteNode( layer.graph, node );  node := node.nextSelected END
		ELSIF event.gesture = vyEvents.EvtCopy THEN
			node := vyGraph.GetSelection( layer.graph );
			IF node # NIL THEN link := NIL;  vyLinks.InsertObj( link, node( tNode ).o( vyBase.Object ) );  vyBase.Show( link, 1, "antsPlots" ) END
		END;
		vyBase.Update( layer )
	END Select;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^;  vyGraph.Copy( source.graph, dest.graph )
	END Copy;

	PROCEDURE Identify( v: vyGraph.tNode );
	BEGIN
		IF (gNode = NIL ) & (v IS tNode) & (v( tNode ).o = gObject) THEN gNode := v( tNode ) END
	END Identify;

	PROCEDURE GetNodeOfObject( graph: vyGraph.tGraph;  o: Objects.Object ): tNode;
	BEGIN
		gNode := NIL;  gObject := o;  vyGraph.ForEachNodeDo( graph, Identify );  RETURN gNode
	END GetNodeOfObject;

	PROCEDURE ThereIsEdge( from, to: tNode ): BOOLEAN;
	VAR edges: vyGraph.tEdge;
	BEGIN
		edges := from.firstOutEdge;
		WHILE (edges # NIL ) DO
			IF edges.to = to THEN RETURN TRUE END;
			edges := edges.next;
		END;
		RETURN FALSE;
	END ThereIsEdge;

	PROCEDURE InstallGraph*( level: tLayer;  debug: BOOLEAN );
	VAR graph: vyGraph.tGraph;  i: INTEGER;  ref2: tNode;  vtroot: tNode;  e: vyGraph.tEdge;  name: vyName.tNameArray;  count: LONGINT;

		PROCEDURE AlreadyInstalled( rt: Objects.Object ): BOOLEAN;
		BEGIN
			ref2 := GetNodeOfObject( graph, rt );
			IF ref2 = NIL THEN RETURN FALSE ELSE RETURN TRUE END
		END AlreadyInstalled;

		PROCEDURE NodeSources( t: Objects.Object;  vtfrom: tNode );
		VAR items: vyLinks.Link;  vt: tNode;  name: vyName.tNameArray;
		BEGIN
			INC( count );
			IF count > 10000 THEN HALT( 202 ) END;
			IF t IS vyBase.Object THEN
				WITH t: vyBase.Object DO
					items := vyBase.GetSources( t );
					WHILE (items # NIL ) DO
						IF items.obj IS vyBase.Object THEN
							vyName.GetObjId( items.obj( vyBase.Object ), name );
							IF name[0] = 0X THEN COPY( "?", name ) END;
							IF ~(AlreadyInstalled( items.obj( vyBase.Object ) )) THEN
								NEW( vt );  vt.o := items.obj( vyBase.Object );  vt.level := 0;  vt.handle := NHandler;  vt.dir := sourcenode;
								vyGraph.AddNode( graph, vt, 0, 0, name, vyGraph.normalNode, vyGraph.rect, -1, -1 );  NEW( e );
								vyGraph.AddEdge( graph, e, vt, vtfrom );  NodeSources( items.obj( vyBase.Object ), vt );
								IF debug THEN NodeUsers( items.obj( vyBase.Object ), vt ) END
							ELSE
								vt := ref2;
								IF ~ThereIsEdge( vt, vtfrom ) THEN
									NEW( e );  vyGraph.AddEdge( graph, e, vt, vtfrom );  NodeSources( items.obj( vyBase.Object ), vt );
									IF debug THEN NodeUsers( items.obj( vyBase.Object ), vt );  END
								END;
							END
						END;
						items := items.link
					END
				END;
			ELSE  (* t: vyBase.Object *)
				RETURN
			END
		END NodeSources;

		PROCEDURE NodeUsers( t: Objects.Object;  vtfrom: tNode );
		VAR items: vyLinks.Link;  vt: tNode;  name: vyName.tNameArray;
		BEGIN
			INC( count );
			IF count > 100000 THEN HALT( 202 ) END;
			IF t IS vyBase.Object THEN
				WITH t: vyBase.Object DO
					items := vyBase.GetUsers( t );
					WHILE (items # NIL ) DO
						IF items.obj IS vyBase.Object THEN
							vyName.GetObjId( items.obj( vyBase.Object ), name );
							IF name[0] = 0X THEN COPY( "?", name ) END;
							IF ~(AlreadyInstalled( items.obj( vyBase.Object ) )) THEN
								NEW( vt );  vt.o := items.obj( vyBase.Object );  vt.level := 0;  vt.handle := NHandler;  vt.dir := usernode;
								vyGraph.AddNode( graph, vt, 0, 0, name, vyGraph.normalNode, vyGraph.rect, -1, -1 );  NEW( e );
								vyGraph.AddEdge( graph, e, vtfrom, vt );  NodeUsers( items.obj( vyBase.Object ), vt );
								IF debug THEN NodeSources( items.obj( vyBase.Object ), vt ) END
							ELSE
								vt := ref2;
								IF ~ThereIsEdge( vtfrom, vt ) THEN
									NEW( e );  vyGraph.AddEdge( graph, e, vtfrom, vt );  NodeUsers( items.obj( vyBase.Object ), vt );
									IF debug THEN NodeSources( items.obj( vyBase.Object ), vt ) END
								END;
							END
						END;
						items := items.link
					END
				END;
			ELSE  (* t: vyBase.Object *)
				RETURN
			END
		END NodeUsers;

	BEGIN
		count := 0;  graph := level.graph;  i := 0;  vyName.GetObjId( level.root, name );  NEW( vtroot );  vtroot.o := level.root;
		vtroot.handle := NHandler;  vtroot.dir := usernode;  vtroot.level := 0;
		vyGraph.AddNode( graph, vtroot, 0, 0, name, vyGraph.specialNode, vyGraph.rect, -1, 2 );
		NodeUsers( level.root, vtroot );  NodeSources( level.root, vtroot );  vvv := vtroot
	END InstallGraph;

	PROCEDURE range( n: vyGraph.tNode );
	BEGIN
		IF minlevel > n( tNode ).level THEN minlevel := n( tNode ).level END;
		IF maxlevel < n( tNode ).level THEN maxlevel := n( tNode ).level END
	END range;

	PROCEDURE rangepos( n: vyGraph.tNode );
	BEGIN
		n( tNode ).levelpos := currange[n( tNode ).level - minlevel];  INC( currange[n( tNode ).level - minlevel] );
		IF currange[n( tNode ).level - minlevel] > rangex THEN rangex := currange[n( tNode ).level - minlevel] END;
	END rangepos;

	PROCEDURE posit( n: vyGraph.tNode );
	VAR x, y: LONGREAL;
	BEGIN
		y := -n( tNode ).level;  x := ((n( tNode ).levelpos) + 1) / (currange[n( tNode ).level - minlevel] + 1);
		vyGraph.PlaceNode( graph, n, x, y )
	END posit;

	PROCEDURE minlevel1( n: vyGraph.tNode );
	VAR name: vyName.tNameArray;  old: INTEGER;
	BEGIN
		IF n( tNode ).o # NIL THEN
			vyName.GetObjId( n( tNode ).o( vyBase.Object ), name );
			(*
		Out.String("minlevel1");  Out.String(name);  Out.Ln();
		Out.String("at min: ");  Out.Int(min, 10);  Out.Ln()
		*)
		END;
		old := min;
		IF n( tNode ).level < min THEN n( tNode ).level := min;  min := min + 1 END;
		vyGraph.ForEachFollowNodeDo( n, minlevel1 );  min := old
	END minlevel1;

	PROCEDURE maxlevel1( n: vyGraph.tNode );
	VAR name: vyName.tNameArray;  old: INTEGER;
	BEGIN
		IF n( tNode ).o # NIL THEN
			vyName.GetObjId( n( tNode ).o( vyBase.Object ), name );
			(*
		Out.String("maxlevel1");  Out.String(name);  Out.Ln();
		Out.String("at max: ");  Out.Int(max, 10);  Out.Ln()
		*)
		END;
		old := max;
		IF n( tNode ).level > max THEN n( tNode ).level := max;  max := max - 1 END;
		vyGraph.ForEachPrevNodeDo( n, maxlevel1 );  max := old
	END maxlevel1;

(*
PROCEDURE RefineGraph (g: vyGraph.tGraph);
BEGIN
	graph := g;
	minlevel := MAX(INTEGER);   maxlevel := MIN(INTEGER);
	min := 1;  max := - 1;
	vyGraph.ForEachFollowNodeDo(vvv, minlevel1);
	vyGraph.ForEachPrevNodeDo(vvv, maxlevel1);
	vyGraph.ForEachNodeDo(g, range);
	NEW(currange, maxlevel - minlevel + 1);
	vyGraph.ForEachNodeDo(g, rangepos);
	vyGraph.ForEachNodeDo(g, posit)
END RefineGraph;
*)

	PROCEDURE init0( v: vyGraph.tNode );
	BEGIN
		v( tNode ).level := 0;
	END init0;

	PROCEDURE reverse( v: vyGraph.tNode );
	BEGIN
		v( tNode ).level := maxlevel - v( tNode ).level;
	END reverse;

	PROCEDURE up( down, upn: vyGraph.tNode );
	VAR edge: vyGraph.tEdge;
	BEGIN
		WITH upn: tNode DO
			WITH down: tNode DO
				IF upn.level <= down.level THEN upn.level := down.level + 1 END;
				IF maxlevel < upn.level THEN maxlevel := upn.level END;
				edge := upn( tNode ).firstInEdge.next;
				WHILE (edge # NIL ) DO up( edge.to, edge.from );
					ASSERT ( edge.to = upn );
					edge := edge.next;
				END;
			END;
		END;
	END up;

	PROCEDURE startup( n: vyGraph.tNode );
	VAR edge: vyGraph.tEdge;
	BEGIN
		IF n( tNode ).firstOutEdge.next = NIL  (* no successors *) THEN
			edge := n( tNode ).firstInEdge.next;
			WHILE (edge # NIL ) DO up( edge.to, edge.from );
				ASSERT ( edge.to = n );
				edge := edge.next;
			END;
		END;
	END startup;

	PROCEDURE RefineGraph( g: vyGraph.tGraph );
	BEGIN
		graph := g;  minlevel := MAX( INTEGER );  maxlevel := MIN( INTEGER );  min := 1;  max := -1;  vyGraph.ForEachNodeDo( g, init0 );
		vyGraph.ForEachNodeDo( g, startup );
		(*
	vyGraph.ForEachFollowNodeDo(vvv, minlevel1);
	vyGraph.ForEachPrevNodeDo(vvv, maxlevel1);
	vyGraph.ForEachNodeDo(g, range);
	*)
		rangex := 0;  minlevel := 0;  vyGraph.ForEachNodeDo( g, reverse );
		IF maxlevel >= 0 THEN
			NEW( currange, maxlevel - 0 + 1 );  vyGraph.ForEachNodeDo( g, rangepos );  vyGraph.ForEachNodeDo( g, posit );
		END;
	END RefineGraph;

	PROCEDURE checkSelection( n: vyGraph.tNode );
	VAR nx, ny: LONGREAL;  sel: vyDisplay2d.Selection;
	BEGIN

		vyGraph.GetNodePlace( graph, n, nx, ny );  sel := vyDisplay2d.currentsel;
		IF (sel.x < nx) & (sel.x + sel.w > nx) & (sel.y < ny) & (sel.y + sel.h > ny) THEN vyGraph.SelectNode( graph, n ) END;
	END checkSelection;

	PROCEDURE Recall( layer: tLayer;  msg: Display.DisplayMsg );
	VAR x, y, w, h: INTEGER;  hp: vyPort.Picture;
	BEGIN
		(*
	IF vyDisplay2d.currentsel # NIL THEN
	graph := layer.graph;
	vyGraph.ClearSelection(graph);
	vyGraph.ForEachNodeDo(layer.graph,checkSelection);
	END;
	*)
		vyGraph.Recall( layer.graph );  hp := msg.dlink( vyPort.Picture );  vyPort.GetPictureScreenRegion( hp, x, y, w, h )
	END Recall;

	PROCEDURE Respond( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR v: vyGraph.tNode;  x2d, y2d: Real;  x, y, w, h, dx, dy, dsr: INTEGER;  g: vyGraph.tGraph;
	BEGIN
		vyGraphBase.PointToPoint2d( event.x, event.y, x2d, y2d );  v := vyGraph.ThisNode( layer.graph, x2d, y2d );
		IF v # NIL THEN
			g := layer.graph;  vyGraph.GetNodeRect( g, v, x, y, w, h, dsr );  vyTracking.Rectangle( x, y, w, h, dx, dy );
			IF (dx # 0) OR (dy # 0) THEN
				IF vyGraph.Selected( v ) THEN vyGraph.MoveSelection( g, dx, dy ) ELSE vyGraph.MoveNode( g, v, dx, dy ) END;
				vyBase.Update( layer )
			END
		END
	END Respond;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: INTEGER;
	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtSelect) OR (event.gesture = vyEvents.EvtIdent) THEN priority := vyEvents.PrioHigh END;
		IF event.priority < priority THEN event.responder := layer;  event.priority := priority END
	END Responsible;

	PROCEDURE StoreL( VAR R: Files.Rider;  L: tLayer );
	BEGIN
		Files.WriteInt( R, 0 );  Gadgets.WriteRef( R, L.lib, L.graph );  Gadgets.WriteRef( R, L.lib, L.root )
	END StoreL;

	PROCEDURE LoadL( VAR R: Files.Rider;  n: tLayer );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Gadgets.ReadRef( R, n.lib, objsub );
		ASSERT ( objsub # NIL );
		IF (objsub # NIL ) THEN n.graph := objsub( vyGraph.tGraph ) END;
		Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) THEN n.root := objsub( vyBase.Object ) END
	END LoadL;

	PROCEDURE updwonsel( n: vyGraph.tNode );
	VAR x, y: LONGREAL;
	BEGIN
		IF vyGraph.Selected( n ) THEN
			vyGraph.GetNodePlace( graph, n, x, y );
			IF ODD( maxlevel ) THEN y := y + 0.1 ELSE y := y - 0.1 END;
			INC( maxlevel );  vyGraph.PlaceNode( graph, n, x, y );
		END;
	END updwonsel;

	PROCEDURE updown;
	BEGIN
		graph := tempLayer.graph;  maxlevel := 0;  vyGraph.ForEachNodeDo( tempLayer.graph, updwonsel );
		vyBase.Update( tempLayer.graph );
	END updown;

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
					IF msg.name = "Gen" THEN COPY( 'antsDependency.GenL', msg.s );  msg.class := Objects.String;  msg.res := 0 ELSE vyPort.LayerHandler( layer, msg ) END
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
				IF layer.lib # msg.lib THEN
					vyPort.LayerHandler( layer, msg );
					IF layer.graph # NIL THEN antsObjects.Bind( layer.graph, msg ) END;
					IF layer.root # NIL THEN antsObjects.Bind( layer.root, msg ) END
				END;
				done := TRUE
			END;
		ELSIF msg IS vyCommandMenus.enumMsg THEN
			WITH msg: vyCommandMenus.enumMsg DO tempLayer := layer;  msg.Enum( "updown selection", updown, layer );
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

	PROCEDURE Open( layer: tLayer;  root: vyBase.Object;  debug: BOOLEAN );
	VAR graph: vyGraph.tGraph;  id: vyName.tNameArray;
	BEGIN
		id := "dependency:";  vyName.AppendObjId( root( vyBase.Object ), id );  vyPort.OpenLayer( layer, id );  NEW( graph );
		vyGraph.OpenGraph( graph );  layer.graph := graph;  layer.style.fcol := vyGraphBase.black;
		layer.style.fillcol := vyGraphBase.green;  layer.style.selectcol := vyGraphBase.dkgreen;  layer.handle := Handler;
		layer.root := root( vyBase.Object );  InstallGraph( layer, debug );  RefineGraph( layer.graph )
	END Open;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  layer: tLayer;  c: vyDisplay2d.tCoordinate2d;  pict: vyPort.Picture;  x, y, w, h: Real;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO
			NEW( layer );  Open( layer, data( vyBase.Object ), TRUE );  vyGraph.GetGraphFrame( layer.graph, x, y, w, h );  NEW( c );
			vyDisplay2d.OpenC2d( c, x - 0.1, y - 0.1, w + 0.2, h + 0.2 );  pict := vyPort.XNewCPicture( 0, 0, 1, 1, c );
			pict.backGround := vyGraphBase.dgrey;  vyPort.AddLayer( pict, layer );  vyPort.Write( pict );
			data := vyBase.NextParObj()
		END
	END ShowP;

	PROCEDURE Show*;
	VAR layer: tLayer;  c: vyDisplay2d.tCoordinate2d;  pict: vyPort.Picture;  x, y, w, h: Real;  l: antsCommands.tScanList;
		obj: vyBase.Object;  debug: BOOLEAN;
	BEGIN
		l := antsCommands.ScanFromPar( "obj=OBJ [>debug]" );
		IF antsCommands.ExpectObjectFromKeyword( l, "obj", obj ) THEN
			debug := antsCommands.FindKeyword( l, "debug" );  NEW( layer );  Open( layer, obj, debug );
			vyGraph.GetGraphFrame( layer.graph, x, y, w, h );  NEW( c );
			vyDisplay2d.OpenC2d( c, x - 0.1, y - 0.1, w + 0.2, h + 0.2 );  pict := vyPort.XNewCPicture( 0, 0, 1, 1, c );
			pict.backGround := vyGraphBase.dgrey;  vyPort.AddLayer( pict, layer );  vyPort.Write( pict )
		END
	END Show;

BEGIN
	aM.launch;
END antsDependency.

System.Free antsDependency ~

Voyager.Show Array1 as antsDependency ~
antsDependency.Show Array ~

fofAutomatic.Do
antsDiscreteFields.NewArray array1 10 10 2 ~
antsDiscreteFields.NewArray array2 10 10 2 ~
antsBinaryIsingS.NewModel model 0.3 0 ~
antsGibbs.DefineGibbsSampler sampler1 1 ~
antsGibbs.DefineGibbsSampler sampler2 1 ~
antsGibbs.AttachArray sampler1 array1 ~
antsGibbs.AttachArray sampler2 array2 ~
antsPerfectS.NewScheme PS sampler1 sampler2 ~
antsPerfectS.AttachModel PS model ~
Voyager.Show array1 as antsObjectView ~
antsDependency.Show PS ~
~

(* testing: *)
fofAutomatic.Do
ants.NewVec a1 ~
ants.NewVec a2 ~
ants.NewVec a3 ~
ants.NewVec b1 ~
ants.NewVec b2 ~
ants.NewVec b3 ~
ants.NewVec c1 ~
ants.NewVec c2 ~
ants.NewVec c3 ~
antsObjects.Subscribe a1 b1
antsObjects.Subscribe a2 b1~
antsObjects.Subscribe a3 b2~
antsObjects.Subscribe a3 b3~
antsObjects.Subscribe a2 b3~
antsObjects.Subscribe a3 c2~
antsObjects.Subscribe b3 c3~
antsObjects.Subscribe b2 c2~
antsDependency.Show  b2   >debug ~
 ~
 antsDependency.Show f9Chain >debug ~

 ~
  vyScale.Insert
antsDependency.Show array1  ~
antsDependency.Show  antsObjects ~
antsDependency.Show  antsObjects >debug~

Voyager.Show ants as antsDependency ~
Voyager.Show f1Chain as antsDependency ~
antsDependency.Show f1Chain >debug ~
vyScale.Insert

antsModuleView.Add

ants/src/Diff.Mod
ants/src/FofAutomatic.Mod

ants/src/S3.Builder.Mod
ants/src/S3.ScrollViews.Mod
ants/src/S3.Win32.WinMenus.Mod
ants/src/S3.ScrollbarsR.Mod

ants/src/antsScriptObjects.Mod

ants/src/antsGlobals.Mod
ants/src/antsTrapper.Mod
ants/src/antsSecurity.Mod

ants/src/antsOPS.Mod
ants/src/antsOPT.Mod
ants/src/antsOPV.Mod
ants/src/antsOPC.Mod
ants/src/antsOPL.Mod
ants/src/vyPointerVec.Mod
ants/src/antsExpressionsObjects.Mod
ants/src/antsExpressionsDefaults.Mod
ants/src/antsExpressions.Mod


 ants/src/antsProgress.Mod
 ants/src/antsCommands.Mod
 ants/src/FofAutomatic.Mod
 ants/src/antsToolbox.Mod
 ants/src/antsPackageBuilder.Mod
 ants/src/antsWinEffects.Mod
  ants/src/antsPictCoordinate.Mod

 ants/src/antsMessages.Mod
  ants/src/antsContainers.Mod
 ants/src/antsScale.Mod

 ants/src/antsBasicGadgets.Mod
 ants/src/antsObjects.Mod
 ants/src/antsObjectView.Mod

 ants/src/antsGraph.Mod
 ants/src/antsOnTheFly.Mod
 ants/src/antsFunctions.Mod
 ants/src/antsFctEdit.Mod
 ants/src/antsFctVector.Mod
 ants/src/antsVecOpt.Mod
 ants/src/ants1dCup.Mod

 ants/src/antsDependency.Mod
 ants/src/antsLinkView.Mod
 ants/src/antsPointPlot.Mod
 ants/src/antsValuePlot.Mod
 ants/src/antsVectors.Mod
 ants/src/antsFiles.Mod
 ants/src/antsReadWrite.Mod
 ants/src/antsPlots.Mod
