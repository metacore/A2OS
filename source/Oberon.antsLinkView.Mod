MODULE antsLinkView IN Oberon;   (** fof  **)
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




IMPORT Display, vyBase, vyName, vyGraphBase, vyDisplay2d, vyPort, vyEvents, vyLinks, antsObjects, Attributes, antsPlots,
	vyTracking, Files, vyHighlight, Gadgets, vyGraph := antsGraph, Objects, antsCommands, Strings, vyCommandMenus, aM := antsMessages;

TYPE
	Real = FLOAT64;

	tNode = POINTER TO tNodeDesc;
	tNodeDesc = RECORD (vyGraph.tNodeDesc)
		o: Objects.Object;
		dir: SIGNED16;
		level, levelpos: SIGNED16
	END;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		graph: vyGraph.tGraph;
		root: vyBase.Object
	END;

CONST
	sourcenode = 1;  usernode = 2;

VAR
	minlevel, maxlevel: SIGNED16;
	currange: POINTER TO ARRAY OF SIGNED16;
	graph: vyGraph.tGraph;   (* temp *)
	min, max: SIGNED16;  vvv: tNode;  tempLayer: tLayer;  tempN: tNode;

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
						IF M.name = "Gen" THEN COPY( 'antsLinkView.GenN', M.s );  M.class := Objects.String;  M.res := 0;  RETURN END
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
		NEW( v );  v.handle := NHandler;  Objects.NewObj := v
	END GenN;

	PROCEDURE Select( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR x0, y0, x1O, y1O, x1N, y1N: SIGNED16;  X0, Y0, X1O, Y1O, X1N, Y1N: Real;  node: vyGraph.tNode;  link: vyLinks.Link;

		PROCEDURE Frame( x, y, u, v: SIGNED16 );
		VAR w, h, r: SIGNED16;
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

	PROCEDURE InstallGraph*( level: tLayer;  debug: BOOLEAN );
	VAR graph: vyGraph.tGraph;  i: SIGNED16;  vtroot: tNode;  e: vyGraph.tEdge;  name: vyName.tNameArray;  count: SIGNED32;
		installed, cur: antsObjects.tlinkList;

		PROCEDURE MarkInstalled( obj: Objects.Object );
		BEGIN
			IF installed = NIL THEN NEW( installed );  cur := installed END;
			NEW( cur.next );  cur := cur.next;  cur.obj := obj
		END MarkInstalled;

		PROCEDURE IsInstalled( obj: Objects.Object ): BOOLEAN;
		VAR l: antsObjects.tlinkList;
		BEGIN
			IF installed # NIL THEN
				l := installed.next;
				WHILE (l # NIL ) DO
					IF l.obj = obj THEN  (* Out.Ln; Out.String("already installed obj"); *) RETURN TRUE END;
					l := l.next;
				END;
			END;
			RETURN FALSE;

		END IsInstalled;

		PROCEDURE DoFindContext( obj: Objects.Object;  objname: ARRAY OF CHAR;  up, down: BOOLEAN;  VAR node: tNode );
		VAR name: vyName.tNameArray;  list: antsObjects.tlinkList;  vt: tNode;
		CONST bothdir = FALSE;
		BEGIN
			aM.dSS( "------ checking: ", objname );  list := antsObjects.linklist.next;
			WHILE (list # NIL ) DO
				IF list.host = obj THEN
					IF down & (~IsInstalled( list.obj )) THEN
						MarkInstalled( list.obj );  NEW( vt );  vt.o := list.obj;  vt.level := 0;  vt.handle := NHandler;  vt.dir := usernode;
						IF vt.o = NIL THEN name := "NIL" ELSE Attributes.GetString( list.obj, "Name", name ) END;
						Strings.Append( name, "(" );  Strings.Append( name, list.name );  Strings.Append( name, ")" );
						vyGraph.AddNode( graph, vt, 0, 0, name, vyGraph.normalNode, vyGraph.rect, -1, -1 );

						NEW( e );  vyGraph.AddEdge( graph, e, node, vt );

						aM.dSS( ">>> ", name );

						DoFindContext( list.obj, name, bothdir, TRUE , vt )

					END
				ELSIF list.obj = obj THEN
					IF up & (~IsInstalled( list.host )) THEN
						MarkInstalled( list.host );  NEW( vt );  vt.o := list.host;  vt.level := 0;  vt.handle := NHandler;  vt.dir := sourcenode;

						IF vt.o = NIL THEN name := "NIL"
						ELSE Attributes.GetString( list.host, "Name", name )
						END;
						Strings.Append( name, "(" );  Strings.Append( name, list.name );  Strings.Append( name, ")" );

						vyGraph.AddNode( graph, vt, 0, 0, name, vyGraph.normalNode, vyGraph.rect, -1, -1 );  NEW( e );
						vyGraph.AddEdge( graph, e, vt, node );

						Attributes.GetString( list.host, "Name", name );  aM.dSS( "<<<", name );  aM.dSS( " as ", list.name );

						DoFindContext( list.host, name, TRUE , bothdir, vt )
					END
				END;
				list := list.next
			END
		END DoFindContext;


	(*
PROCEDURE AlreadyInstalled (rt: Objects.Object;    dir: SIGNED16): BOOLEAN;
BEGIN
ref2 := GetNodeOfObject(graph, rt, dir);
IF ref2 = NIL THEN RETURN FALSE ELSE RETURN TRUE END
END AlreadyInstalled;

PROCEDURE^ NodeUsers (t: Objects.Object;      vtfrom: tNode );

PROCEDURE NodeSources (t: Objects.Object;      vtfrom: tNode);
VAR  items: vyLinks.Link;      vt: tNode;      name: vyName.tNameArray;
BEGIN
INC(count);     IF count > 1000 THEN HALT (202)    END;
WITH t: vyBase.Object DO
items := vyBase.GetSources(t);
WHILE(items # NIL) DO
IF items.obj IS vyBase.Object THEN
vyName.GetObjId(items.obj(vyBase.Object), name);
IF name[0] = 0X THEN COPY("?", name) END;
IF ~(AlreadyInstalled(items.obj(vyBase.Object), usernode) OR AlreadyInstalled(items.obj(vyBase.Object), sourcenode))
THEN
NEW(vt);      vt.o := items.obj(vyBase.Object);  vt.level := 0;
vt.handle := NHandler;      vt.dir := sourcenode;
vyGraph.AddNode (graph, vt, 0, 0, name, vyGraph.normalNode, vyGraph.rect, - 1, - 1);
NEW(e);
vyGraph.AddEdge (graph, e, vt, vtfrom);
NodeSources(items.obj(vyBase.Object), vt);
IF debug THEN NodeUsers(items.obj(vyBase.Object), vt) END;
ELSE
vt := ref2;
NEW(e);
vyGraph.AddEdge (graph, e, vt, vtfrom)
END
END;
items := items.link
END
ELSE (* t: vyBase.Object *)
RETURN
END
END NodeSources;

PROCEDURE NodeUsers (t: Objects.Object;      vtfrom: tNode);
VAR  items: vyLinks.Link;      vt: tNode;      name: vyName.tNameArray;
BEGIN
INC(count);     IF count > 1000 THEN  HALT (202)    END;
WITH t: vyBase.Object DO
items := vyBase.GetUsers(t);
WHILE(items # NIL) DO
IF items.obj IS vyBase.Object THEN
vyName.GetObjId(items.obj(vyBase.Object), name);
IF name[0] = 0X THEN COPY("?", name) END;
IF ~(AlreadyInstalled(items.obj(vyBase.Object), usernode) OR
AlreadyInstalled(items.obj(vyBase.Object), sourcenode)) THEN
NEW(vt);      vt.o := items.obj(vyBase.Object);  vt.level := 0;
vt.handle := NHandler;      vt.dir := usernode;
vyGraph.AddNode (graph, vt, 0, 0, name, vyGraph.normalNode, vyGraph.rect, - 1, - 1);
NEW(e);
vyGraph.AddEdge (graph, e, vtfrom, vt);
NodeUsers(items.obj(vyBase.Object), vt);
IF debug THEN NodeSources(items.obj(vyBase.Object), vt) END;
ELSE
vt := ref2;
NEW(e);
vyGraph.AddEdge (graph, e, vtfrom, vt)
END
END;
items := items.link
END
ELSE (* t: vyBase.Object *)
RETURN
END
END NodeUsers;
*)

	BEGIN
		count := 0;  graph := level.graph;  i := 0;  vyName.GetObjId( level.root, name );  NEW( vtroot );  vtroot.o := level.root;
		vtroot.handle := NHandler;  vtroot.dir := usernode;  vtroot.level := 0;
		vyGraph.AddNode( graph, vtroot, 0, 0, name, vyGraph.specialNode, vyGraph.rect, -1, 2 );
		(* NodeUsers(level.root, vtroot);
	NodeSources (level.root, vtroot);
	*)
		antsObjects.MakeLinkList;  DoFindContext( level.root, name, TRUE , TRUE , vtroot );  vvv := vtroot
	END InstallGraph;

	PROCEDURE range( n: vyGraph.tNode );
	BEGIN
		IF minlevel > n( tNode ).level THEN minlevel := n( tNode ).level END;
		IF maxlevel < n( tNode ).level THEN maxlevel := n( tNode ).level END
	END range;

	PROCEDURE rangepos( n: vyGraph.tNode );
	BEGIN
		n( tNode ).levelpos := currange[n( tNode ).level - minlevel];  INC( currange[n( tNode ).level - minlevel] )
	END rangepos;

	PROCEDURE posit( n: vyGraph.tNode );
	VAR x, y: FLOAT64;
	BEGIN
		y := -n( tNode ).level;
		x := (maxlevel - minlevel) / 2 - currange[n( tNode ).level - minlevel] / 2 + n( tNode ).levelpos;
		vyGraph.PlaceNode( graph, n, x, y )
	END posit;

	PROCEDURE minlevel1( n: vyGraph.tNode );
	VAR name: vyName.tNameArray;  old: SIGNED16;
	BEGIN
		IF (n( tNode ).o # NIL ) THEN
			Attributes.GetString( n( tNode ).o, "Name", name );
			(* vyName.GetObjId(n(tNode).o(vyBase.Object),name); *)
			aM.dSS( "minlevel1", name );  aM.dSI( "at min: ", min );
		END;
		old := min;
		IF n( tNode ).level < min THEN n( tNode ).level := min;  min := min + 1 END;
		vyGraph.ForEachFollowNodeDo( n, minlevel1 );  min := old
	END minlevel1;

	PROCEDURE maxlevel1( n: vyGraph.tNode );
	VAR name: vyName.tNameArray;  old: SIGNED16;
	BEGIN
		IF n( tNode ).o # NIL THEN
			vyName.GetObjId( n( tNode ).o( vyBase.Object ), name );  aM.dSS( "maxlevel1", name );  aM.dSI( "at max: ", max );
		END;
		old := max;
		IF n( tNode ).level > max THEN n( tNode ).level := max;  max := max - 1 END;
		vyGraph.ForEachPrevNodeDo( n, maxlevel1 );  max := old
	END maxlevel1;

	PROCEDURE RefineGraph( g: vyGraph.tGraph );
	BEGIN
		graph := g;  minlevel := MAX( SIGNED16 );  maxlevel := MIN( SIGNED16 );  min := 1;  max := -1;  vyGraph.ForEachFollowNodeDo( vvv, minlevel1 );
		vyGraph.ForEachPrevNodeDo( vvv, maxlevel1 );  vyGraph.ForEachNodeDo( g, range );
		NEW( currange, maxlevel - minlevel + 1 );  vyGraph.ForEachNodeDo( g, rangepos );  vyGraph.ForEachNodeDo( g, posit )
	END RefineGraph;

	PROCEDURE Recall( layer: tLayer;  msg: Display.DisplayMsg );
	VAR x, y, w, h: SIGNED16;  hp: vyPort.Picture;
	BEGIN
		vyGraph.Recall( layer.graph );  hp := msg.dlink( vyPort.Picture );  vyPort.GetPictureScreenRegion( hp, x, y, w, h )
	END Recall;

	PROCEDURE Respond( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR v: vyGraph.tNode;  x2d, y2d: Real;  x, y, w, h, dx, dy, dsr: SIGNED16;  g: vyGraph.tGraph;
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

	PROCEDURE DoubleClick( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR v: vyGraph.tNode;  x2d, y2d: Real;  n: tNode;  xr, yr, wr, hr: FLOAT64;
	BEGIN
		vyGraphBase.PointToPoint2d( event.x, event.y, x2d, y2d );  v := vyGraph.ThisNode( layer.graph, x2d, y2d );
		IF (v # NIL ) & (v IS tNode) THEN
			n := v( tNode );
			IF (n.o # NIL ) & (n.o IS vyBase.Object) THEN
				layer.root := n.o( vyBase.Object );  NEW( graph );  vyGraph.OpenGraph( graph );  layer.graph := graph;
				InstallGraph( layer, FALSE );  RefineGraph( layer.graph );  vyGraph.GetGraphFrame( layer.graph, xr, yr, wr, hr );
				vyPort.SetC2d( vyPort.GetFocusPicture(), SHORT( xr - 0.2 ), SHORT( yr - 0.2 ), SHORT( wr + 0.4 ), SHORT( hr + 0.4 ) );

				vyBase.Update( layer )
				(*
			antsPlots.DoShow(n.o(vyBase.Object));
			*)
			END
		END
	END DoubleClick;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR priority: SIGNED16;  x2d, y2d: Real;  v: vyGraph.tNode;
	BEGIN
		priority := vyEvents.PrioNone;  vyGraphBase.PointToPoint2d( event.x, event.y, x2d, y2d );
		v := vyGraph.ThisNode( layer.graph, x2d, y2d );

		IF (event.gesture = vyEvents.EvtSelect) OR (event.gesture = vyEvents.EvtIdent) OR
		    (((event.gesture = vyEvents.EvtLoc) OR (event.gesture = vyEvents.EvtDoubleClick)) & (v # NIL )) THEN
			priority := vyEvents.PrioHigh
		END;
		IF event.priority < priority THEN event.responder := layer;  event.priority := priority END
	END Responsible;

	PROCEDURE StoreL( VAR R: Files.Rider;  L: tLayer );
	BEGIN
		Files.WriteInt( R, 0 );  Gadgets.WriteRef( R, L.lib, L.graph );  Gadgets.WriteRef( R, L.lib, L.root )
	END StoreL;

	PROCEDURE LoadL( VAR R: Files.Rider;  n: tLayer );
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		Files.ReadInt( R, version );  Gadgets.ReadRef( R, n.lib, objsub );
		ASSERT ( objsub # NIL );
		IF (objsub # NIL ) THEN n.graph := objsub( vyGraph.tGraph ) END;
		Gadgets.ReadRef( R, n.lib, objsub );
		IF (objsub # NIL ) THEN n.root := objsub( vyBase.Object ) END
	END LoadL;

	PROCEDURE viewNode;
	BEGIN
		vyCommandMenus.Wait();  antsPlots.DoShow( tempN.o( vyBase.Object ) )
	END viewNode;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR layer, copy: tLayer;  done: BOOLEAN;  x2d, y2d: FLOAT64;  v: vyGraph.tNode;
	BEGIN
		layer := o( tLayer );  done := FALSE;
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( layer, msg );  done := TRUE
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF msg.callForResponder THEN Responsible( layer, msg ) ELSE
					IF msg.gesture = vyEvents.EvtSelect THEN Select( layer, msg )
					ELSIF (msg.gesture = vyEvents.EvtIdent) OR (msg.gesture = vyEvents.EvtLoc) THEN Respond( layer, msg )
					ELSIF (msg.gesture = vyEvents.EvtDoubleClick) THEN DoubleClick( layer, msg )
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
					IF msg.name = "Gen" THEN COPY( 'antsLinkView.GenL', msg.s );  msg.class := Objects.String;  msg.res := 0 ELSE vyPort.LayerHandler( layer, msg ) END
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
			WITH msg: vyCommandMenus.enumMsg DO
				tempLayer := layer;  msg.EnumSender( "", NIL , layer );  vyCommandMenus.Ask( layer.graph );
				vyGraphBase.PointToPoint2d( msg.x, msg.y, x2d, y2d );  v := vyGraph.ThisNode( layer.graph, x2d, y2d );
				IF (v # NIL ) & (v IS tNode) THEN
					tempN := v( tNode );
					IF (tempN.o # NIL ) & (tempN.o IS vyBase.Object) THEN msg.Enum( "View as .. ", viewNode, o ) END
				END
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
		id := "LinkView:";  vyName.AppendObjId( root( vyBase.Object ), id );  vyPort.OpenLayer( layer, id );  NEW( graph );
		vyGraph.OpenGraph( graph );  layer.graph := graph;  layer.style.fcol := vyGraphBase.black;
		layer.style.fillcol := vyGraphBase.green;  layer.style.selectcol := vyGraphBase.dkgreen;  layer.handle := Handler;
		layer.root := root( vyBase.Object );  InstallGraph( layer, debug );  RefineGraph( layer.graph )
	END Open;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  layer: tLayer;  c: vyDisplay2d.tCoordinate2d;  pict: vyPort.Picture;  x, y, w, h: Real;
	BEGIN
		data := vyBase.NextParObj();
		WHILE (data # NIL ) DO
			NEW( layer );  Open( layer, data( vyBase.Object ), FALSE );  vyGraph.GetGraphFrame( layer.graph, x, y, w, h );  NEW( c );
			vyDisplay2d.OpenC2d( c, x - 1, y - 1, w + 2, h + 2 );  pict := vyPort.XNewCPicture( 0, 0, 1, 1, c );
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
			vyGraph.GetGraphFrame( layer.graph, x, y, w, h );  NEW( c );  vyDisplay2d.OpenC2d( c, x - 1, y - 1, w + 2, h + 2 );
			pict := vyPort.XNewCPicture( 0, 0, 1, 1, c );  pict.backGround := vyGraphBase.dgrey;  vyPort.AddLayer( pict, layer );
			vyPort.Write( pict )
		END
	END Show;

BEGIN
	aM.launch
END antsLinkView.

System.Free antsLinkView ~

Voyager.Show Array1 as antsLinkView ~
antsLinkView.Show Array ~

Desktops.OpenWinDoc Caracas3a.Panel ~

Voyager.Show f3Kernel as antsLinkView ~
Voyager.Show f3Kernel as antsDependency ~


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
antsLinkView.Show PS ~
~

antsLinkView.Show array1  ~

vy / src / vyBase.Mod

System.Free antsDependency ~
