MODULE antsObjectView IN Oberon;   (** fof  **)
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




IMPORT Objects, vyBase, vyHostStrings, vyName, vyLinks, vyPort, Display, vyDisplay2d, vyHostTexts, vyTracking,
	aM := antsMessages, vyGraphBase, vyRectangles, vyEvents, vyCommandMenus, Oberon, Texts, Gadgets, vyHost, Files, antsObjects;

CONST
	disty = 1;  distx = 15;  TICKS = 100;  HideEntryConstName = "** hide **";  MAXD = 20;  RegisterEntryConstName = " ! ReRegister Object ! ";
	WriteAllEntriesConstName = "Write Out All Entries";  ShowConstName = "Show Plot";

TYPE
	ViewList = POINTER TO ViewListDesc;
	ViewListDesc = RECORD
		this: vyTracking.List;
		gen: vyTracking.List;
		next: ViewList
	END;

	tNode* = POINTER TO tNodeDesc;

	tEntry = POINTER TO tEntryDesc;
	tEntryDesc = RECORD (vyLinks.LinkDesc)
		name, val: ARRAY 256 OF CHAR;
		X, Y, W, H: INTEGER;
		selected: BOOLEAN;
		visible: BOOLEAN;
		node: tNode
	END;

	tNodeDesc* = RECORD
		entries: vyLinks.Link;
		root: Objects.Object;
		name, val: ARRAY 256 OF CHAR;
		entriesvisible: BOOLEAN;
		entriescount: LONGINT;
		repetition: BOOLEAN;
		X, Y, W, H: INTEGER;
		x, y: LONGREAL;
		selected: BOOLEAN;
		visible: BOOLEAN
	END;

	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		node: tNode;
		distance: INTEGER;
		forbidden: ARRAY 128 OF vyName.tNameArray;
		forbiddencount: INTEGER;
		commands: vyCommandMenus.List;
		lastLink: LONGINT;
		lifeUpdate: BOOLEAN
	END;

	NodeProc = PROCEDURE ( n: tNode );
	EntryProc = PROCEDURE ( e: tEntry );

VAR
	enumChar: ARRAY 1024 OF vyName.tNameArray;
	enumCount: INTEGER;  ObjList: vyLinks.Link;  LastObj: vyLinks.Link;  tempLayer: tLayer;  Xtemp, Ytemp, Wtemp, Htemp: INTEGER;
	tempNode: tNode;  nousersandsources: BOOLEAN;  GVList: ViewList;  gadgets: ViewList;  maxdepth: INTEGER;

	PROCEDURE StoreEntry( VAR R: Files.Rider;  lib: Objects.Library;  entry: vyLinks.Link );
	BEGIN
		Files.WriteInt( R, 0 );
		IF entry = NIL THEN Files.WriteInt( R, -1 );  RETURN ELSE Files.WriteInt( R, 0 ) END;
		WITH entry: tEntry DO
			Files.WriteString( R, entry.name );  Files.WriteString( R, entry.val );  Files.WriteBool( R, entry.selected );
			Files.WriteBool( R, entry.visible );  Files.WriteInt( R, entry.X );  Files.WriteInt( R, entry.Y );
			Files.WriteInt( R, entry.W );  Files.WriteInt( R, entry.H );  StoreNode( R, lib, entry.node )
		END;
		StoreEntry( R, lib, entry.link )
	END StoreEntry;

	PROCEDURE LoadEntry( VAR R: Files.Rider;  lib: Objects.Library;  VAR entry: vyLinks.Link );
	VAR i: INTEGER;  mentry: tEntry;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadInt( R, i );
		IF i < 0 THEN entry := NIL;  RETURN END;
		NEW( mentry );  entry := mentry;
		WITH entry: tEntry DO
			Files.ReadString( R, entry.name );  Files.ReadString( R, entry.val );  Files.ReadBool( R, entry.selected );
			Files.ReadBool( R, entry.visible );  Files.ReadInt( R, entry.X );  Files.ReadInt( R, entry.Y );
			Files.ReadInt( R, entry.W );  Files.ReadInt( R, entry.H );  LoadNode( R, lib, entry.node )
		END;
		LoadEntry( R, lib, entry.link )
	END LoadEntry;

	PROCEDURE StoreNode( VAR R: Files.Rider;  lib: Objects.Library;  node: tNode );
	BEGIN
		Files.WriteInt( R, 0 );
		IF node = NIL THEN Files.WriteInt( R, -1 );  RETURN ELSE Files.WriteInt( R, 0 ) END;
		StoreEntry( R, lib, node.entries );  Gadgets.WriteRef( R, lib, node.root );  Files.WriteString( R, node.name );
		Files.WriteString( R, node.val );  Files.WriteBool( R, node.entriesvisible );  Files.WriteLInt( R, node.entriescount );
		Files.WriteBool( R, node.repetition );  Files.WriteInt( R, node.X );  Files.WriteInt( R, node.Y );
		Files.WriteInt( R, node.W );  Files.WriteInt( R, node.H );  Files.WriteLReal( R, node.x );  Files.WriteLReal( R, node.y );
		Files.WriteBool( R, node.selected );  Files.WriteBool( R, node.visible )
	END StoreNode;

	PROCEDURE LoadNode( VAR R: Files.Rider;  lib: Objects.Library;  VAR node: tNode );
	VAR i: INTEGER;  subobj: Objects.Object;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Files.ReadInt( R, i );
		IF i < 0 THEN node := NIL;  RETURN END;
		NEW( node );  LoadEntry( R, lib, node.entries );  Gadgets.ReadRef( R, lib, subobj );
		IF subobj # NIL THEN node.root := subobj END;

		Files.ReadString( R, node.name );  Files.ReadString( R, node.val );  Files.ReadBool( R, node.entriesvisible );
		Files.ReadLInt( R, node.entriescount );  Files.ReadBool( R, node.repetition );  Files.ReadInt( R, node.X );
		Files.ReadInt( R, node.Y );  Files.ReadInt( R, node.W );  Files.ReadInt( R, node.H );  Files.ReadLReal( R, node.x );
		Files.ReadLReal( R, node.y );  Files.ReadBool( R, node.selected );  Files.ReadBool( R, node.visible )
	END LoadNode;

	PROCEDURE Store0( o: tLayer;  VAR M: Objects.FileMsg );
	VAR i: INTEGER;
	BEGIN
		Files.WriteInt( M.R, 0 );  StoreNode( M.R, o.lib, o.node );  Files.WriteInt( M.R, o.distance );
		Files.WriteInt( M.R, o.forbiddencount );
		FOR i := 0 TO o.forbiddencount - 1 DO Files.WriteString( M.R, o.forbidden[i] ) END;
		Files.WriteLInt( M.R, o.lastLink );  Files.WriteBool( M.R, o.lifeUpdate )
	END Store0;

	PROCEDURE Load0( o: tLayer;  VAR M: Objects.FileMsg );
	VAR i: INTEGER;  version: INTEGER;
	BEGIN
		Files.ReadInt( M.R, version );  LoadNode( M.R, o.lib, o.node );  Files.ReadInt( M.R, o.distance );
		Files.ReadInt( M.R, o.forbiddencount );
		FOR i := 0 TO o.forbiddencount - 1 DO Files.ReadString( M.R, o.forbidden[i] ) END;
		Files.ReadLInt( M.R, o.lastLink );  Files.ReadBool( M.R, o.lifeUpdate );
		IF o.node.root = antsObjects.obj THEN UpdateSpecial( o ) END
	END Load0;

	PROCEDURE InList( obj: Objects.Object ): BOOLEAN;
	VAR n: vyLinks.Link;
	BEGIN
		IF obj = NIL THEN RETURN FALSE END;
		n := ObjList;
		WHILE (n.link # NIL ) DO
			n := n.link;
			IF obj = n.obj THEN RETURN TRUE END
		END;
		RETURN FALSE
	END InList;

	PROCEDURE PutInList( obj: Objects.Object );
	VAR n: vyLinks.Link;
	BEGIN
		NEW( n );  LastObj.link := n;  LastObj := n;  n.obj := obj
	END PutInList;

	PROCEDURE Equal( CONST s1, s2: ARRAY OF CHAR ): BOOLEAN;
	VAR j: INTEGER;
	BEGIN
		j := 0;
		WHILE (s1[j] # 0X) DO
			IF s1[j] # s2[j] THEN RETURN FALSE END;
			INC( j )
		END;
		RETURN TRUE
	END Equal;

	PROCEDURE Min( a, b: INTEGER ): INTEGER;
	BEGIN
		IF a < b THEN RETURN a ELSE RETURN b END
	END Min;

	PROCEDURE MyEnum( CONST name: ARRAY OF CHAR );
	VAR i: INTEGER;
	BEGIN
		FOR i := 0 TO Min( tempLayer.forbiddencount, LEN( tempLayer.forbidden ) ) - 1 DO
			IF Equal( tempLayer.forbidden[i], name ) THEN RETURN END
		END;
		COPY( name, enumChar[enumCount] );  INC( enumCount )
	END MyEnum;

	PROCEDURE Enqueue( VAR start: vyLinks.Link;  link: vyLinks.Link );
	VAR tlink: vyLinks.Link;
	BEGIN
		IF start = NIL THEN start := link
		ELSE
			tlink := start;
			WHILE tlink.link # NIL DO tlink := tlink.link END;
			tlink.link := link
		END
	END Enqueue;

	PROCEDURE Entries( node: tNode;  CONST rname, rval: ARRAY OF CHAR;  depth: LONGINT );
	VAR msg: Objects.AttrMsg;  lmsg: Objects.LinkMsg;
	VAR i: LONGINT;  ec1, ec2: LONGINT;  name: vyName.tNameArray;  Entry: tEntry;  subnode: tNode;
	BEGIN

		node.selected := FALSE;  node.visible := TRUE;  node.entriesvisible := TRUE;  COPY( rname, node.name );  COPY( rval, node.val );
		IF node.root = NIL THEN RETURN END;
		IF node.root.handle = NIL THEN node.val := "! has no handler";  RETURN END;

		msg.name := "Gen";  msg.res := -1;  msg.id := Objects.get;  node.root.handle( node.root, msg );
		IF msg.res >= 0 THEN
			IF msg.class = Objects.String THEN
				vyHostStrings.Append( node.val, "(" );  vyHostStrings.Append( node.val, msg.s );  vyHostStrings.Append( node.val, ")" )
			END
		END;
		IF node.repetition THEN RETURN END;
		INC( depth );
		IF depth > maxdepth THEN RETURN END;

		msg.id := Objects.enum;  msg.Enum := MyEnum;  enumCount := 0;  msg.res := -1;  node.root.handle( node.root, msg );
		ec1 := enumCount;  lmsg.id := Objects.enum;  lmsg.Enum := MyEnum;  lmsg.res := -1;
		node.root.handle( node.root, lmsg );  ec2 := enumCount;
		FOR i := 0 TO ec1 - 1 DO msg.id := Objects.get;  COPY( enumChar[i], msg.name );  msg.res := -1;
			ASSERT ( node.root.handle # NIL );
			node.root.handle( node.root, msg );
			IF msg.res >= 0 THEN
				NEW( Entry );  COPY( msg.name, Entry.name );  Entry.val := "";  Entry.selected := FALSE;  Entry.visible := TRUE;
				CASE msg.class OF
				Objects.String:
						vyHostStrings.Append( Entry.val, msg.s );
				| Objects.Bool:
						IF msg.b = TRUE THEN vyHostStrings.Append( Entry.val, "TRUE" ) ELSE vyHostStrings.Append( Entry.val, "FALSE" ) END;
				| Objects.Char:
						Entry.val[0] := msg.c;  Entry.val[1] := 0X;
				| Objects.LongReal:
						vyHostStrings.AppendLongReal( msg.y, 1, Entry.val );
				| Objects.Real:
						vyHostStrings.AppendReal( msg.x, 1, Entry.val );
				| Objects.Int:
						vyHostStrings.AppendInt( msg.i, 1, Entry.val )
				END;
				Entry.node := NIL;  Enqueue( node.entries, Entry )
			END
		END;
		FOR i := ec1 TO ec2 - 1 DO

			lmsg.id := Objects.get;  COPY( enumChar[i], lmsg.name );
			(* Out.String(enumChar[i]); Out.Ln(); *)
			lmsg.obj := NIL;  lmsg.res := -1;
			ASSERT ( node.root.handle # NIL );
			node.root.handle( node.root, lmsg );
			IF lmsg.res >= 0 THEN
				IF (lmsg.obj # NIL ) & (lmsg.obj IS tLayer) THEN
				ELSE
					NEW( Entry );  COPY( lmsg.name, Entry.name );  Entry.val := "";  Entry.visible := TRUE;
					IF (lmsg.obj # NIL ) & (lmsg.obj IS vyBase.Object) THEN
						vyName.GetObjId( lmsg.obj( vyBase.Object ), name );  vyHostStrings.Append( Entry.val, name )
					END;
					NEW( subnode );  subnode.root := lmsg.obj;
					IF InList( subnode.root ) THEN subnode.repetition := TRUE ELSE subnode.repetition := FALSE END;
					PutInList( subnode.root );  Enqueue( node.entries, Entry );  Entry.node := subnode
				END
			END
		END;

		IF node.entries # NIL THEN
			ASSERT ( node.entries IS tEntry );
			Entry := node.entries( tEntry )
		ELSE Entry := NIL
		END;
		WHILE Entry # NIL DO
			IF Entry.node # NIL THEN Entries( Entry.node, Entry.name, Entry.val, depth ) END;
			IF Entry.link = NIL THEN Entry := NIL ELSE Entry := Entry.link( tEntry ) END
		END;

		node.entriescount := vyLinks.LinkCount( node.entries );  RETURN
	END Entries;

	PROCEDURE ListFromDummy( layer: tLayer );
	VAR obj: vyBase.Object;  node: tNode;  i: LONGINT;
	BEGIN
		NEW( obj );  obj.handle := vyBase.objecthandle;  NEW( node );  node.root := obj;  Entries( node, "", "", 0 );
		FOR i := 0 TO enumCount - 1 DO COPY( enumChar[i], layer.forbidden[layer.forbiddencount] );  INC( layer.forbiddencount ) END;
		layer.forbidden[layer.forbiddencount] := "User ";  INC( layer.forbiddencount );  layer.forbidden[layer.forbiddencount] := "Source ";
		INC( layer.forbiddencount );  layer.forbidden[layer.forbiddencount] := "Gen";  INC( layer.forbiddencount )
	END ListFromDummy;

	PROCEDURE BoxedText( a1, a2: ARRAY OF CHAR;  x, y: LONGREAL;  VAR X, Y, W, H: INTEGER;  n: tNode;  selected: BOOLEAN );
	VAR dsr: INTEGER;
	BEGIN
		vyHostStrings.Append( a1, ": " );  vyHostStrings.Append( a1, a2 );
		vyGraphBase.GetStringFrame2d( x, y, vyGraphBase.S.fnt, a1, X, Y, W, H, dsr );  H := H + dsr;  Y := Y - dsr;
		IF n # NIL THEN vyGraphBase.SetBackColor( vyGraphBase.red ) ELSE vyGraphBase.SetBackColor( vyGraphBase.S.fillcol )

		END;
		IF selected THEN vyGraphBase.SetBackColor( vyGraphBase.S.selectcol ) END;

		vyGraphBase.EraseRect( X - 1, Y, W + 3, H );  vyGraphBase.FrameRect( X - 2, Y - 1, W + 4, H + 2 );
		vyGraphBase.String2d( x, y, vyGraphBase.S.fnt, a1 );
		IF (n # NIL ) & (n.repetition) THEN
			vyGraphBase.Line( X - 2, Y - 1, X + W + 4, Y + H + 1 );  vyGraphBase.Line( X - 2, Y + H + 1, X + W + 4, Y - 1 )
		END
	END BoxedText;

	PROCEDURE RecallNode( n: tNode;  VAR x, y: LONGREAL;  oldx, oldy: LONGREAL;  drx, dry: LONGREAL;  SY1, SY2: INTEGER );
	VAR e: tEntry;  X, Y, W, H: INTEGER;  w, h: LONGREAL;  firstline: BOOLEAN;
	BEGIN
		IF ~n.visible THEN RETURN END;
		vyGraphBase.Line2d( oldx, y, x, y );  BoxedText( n.name, n.val, x, y, X, Y, W, H, n, n.selected );  n.X := X;  n.Y := Y;
		n.W := W;  n.H := H;  n.x := x;  n.y := y;  vyGraphBase.Global2Local( n.X, n.Y );
		vyGraphBase.VectorToVector2d( W + 2, H + 2, w, h );  x := x + w / 2;  n.x := x;
		vyGraphBase.Line2d( oldx, oldy - h / 2, oldx, y );

		IF (n.entries # NIL ) & (n.entriesvisible) THEN
			e := n.entries( tEntry );  firstline := TRUE;
			WHILE (e # NIL ) DO
				IF (e.visible) & ((e.node = NIL ) OR (e.node.visible)) THEN
					IF firstline THEN vyGraphBase.Line2d( x, y - h / 2, x, y - dry - h );  firstline := FALSE
					ELSE vyGraphBase.Line2d( x, y, x, y - dry - h )
					END;
					y := y - dry - h;  vyGraphBase.Line2d( x, y, x + drx, y );
					IF e.node # NIL THEN
						x := x + drx;
						IF (Y >= SY1) THEN RecallNode( e.node, x, y, n.x, n.y, drx, dry, SY1, SY2 ) END;
						x := x - drx
					ELSE
						BoxedText( e.name, e.val, x + drx, y, X, Y, W, H, NIL , e.selected );  e.X := X;  e.Y := Y;  e.W := W;  e.H := H;
						vyGraphBase.Global2Local( e.X, e.Y )
					END
				END;
				IF e.link = NIL THEN e := NIL ELSE e := e.link( tEntry ) END
			END
		END;
		x := x - w / 2
	END RecallNode;

	PROCEDURE xyinNode( n: tNode;  VAR x, y: INTEGER ): tNode;
	VAR e: tEntry;  n0: tNode;
	BEGIN
		IF vyRectangles.PointInRect( x, y, n.X, n.Y, n.W, n.H ) THEN RETURN n END;

		IF n.entries # NIL THEN
			e := n.entries( tEntry );
			WHILE (e # NIL ) DO
				IF e.node # NIL THEN
					n0 := xyinNode( e.node( tNode ), x, y );
					IF n0 # NIL THEN RETURN n0 END
				END;
				IF e.link = NIL THEN e := NIL ELSE e := e.link( tEntry ) END
			END
		END;
		RETURN NIL
	END xyinNode;

	PROCEDURE xyinEntry( n: tNode;  VAR x, y: INTEGER;  VAR mynode: tNode ): tEntry;
	VAR e: tEntry;  n0: tEntry;
	BEGIN
		IF n.entries # NIL THEN
			e := n.entries( tEntry );  mynode := n;
			WHILE (e # NIL ) DO
				IF e.node # NIL THEN
					n0 := xyinEntry( e.node, x, y, mynode );
					IF n0 # NIL THEN RETURN n0 END
				ELSE
					IF vyRectangles.PointInRect( x, y, e.X, e.Y, e.W, e.H ) THEN RETURN e END
				END;
				IF e.link = NIL THEN e := NIL ELSE e := e.link( tEntry ) END
			END
		END;
		RETURN NIL

	END xyinEntry;

	PROCEDURE SelectNode( n: tNode );
	BEGIN
		n.selected := TRUE
	END SelectNode;

	PROCEDURE SelectEntry( e: tEntry );
	BEGIN
		e.selected := TRUE
	END SelectEntry;

	PROCEDURE DeSelectNode( n: tNode );
	BEGIN
		n.selected := FALSE
	END DeSelectNode;

	PROCEDURE DeSelectEntry( e: tEntry );
	BEGIN
		e.selected := FALSE
	END DeSelectEntry;

	PROCEDURE HideSelectedNode( n: tNode );
	BEGIN
		IF n.selected THEN n.visible := FALSE END
	END HideSelectedNode;

	PROCEDURE HideSelectedEntry( e: tEntry );
	BEGIN
		IF e.selected THEN e.visible := FALSE END
	END HideSelectedEntry;

	PROCEDURE ShowSelectedNode( n: tNode );
	BEGIN
		IF n.selected THEN n.visible := TRUE END
	END ShowSelectedNode;

	PROCEDURE ShowSelectedEntry( e: tEntry );
	BEGIN
		IF e.selected THEN e.visible := TRUE END
	END ShowSelectedEntry;

	PROCEDURE ForAllDo( n: tNode;  nP: NodeProc;  nE: EntryProc );
	VAR e: tEntry;
	BEGIN
		IF nP # NIL THEN nP( n ) END;
		IF n.entries # NIL THEN
			e := n.entries( tEntry );
			WHILE (e # NIL ) DO
				IF e.node # NIL THEN ForAllDo( e.node, nP, nE ) ELSE
					IF nE # NIL THEN nE( e ) END
				END;
				IF e.link = NIL THEN e := NIL ELSE e := e.link( tEntry ) END
			END
		END
	END ForAllDo;

	PROCEDURE ForAllVisibleDo( n: tNode;  nP: NodeProc;  nE: EntryProc );
	VAR e: tEntry;
	BEGIN
		IF nP # NIL THEN nP( n ) END;
		IF (n.entries # NIL ) & (n.entriesvisible) THEN
			e := n.entries( tEntry );
			WHILE (e # NIL ) DO
				IF e.visible THEN
					IF (e.node # NIL ) & (e.node.visible) THEN ForAllVisibleDo( e.node, nP, nE ) ELSE
						IF nE # NIL THEN nE( e ) END
					END
				END;
				IF e.link = NIL THEN e := NIL ELSE e := e.link( tEntry ) END
			END
		END
	END ForAllVisibleDo;

	PROCEDURE UnSelectAll( L: tLayer );
	BEGIN
		ForAllDo( L.node, DeSelectNode, DeSelectEntry )
	END UnSelectAll;

	PROCEDURE UnHideAll( L: tLayer );
	BEGIN
		ForAllDo( L.node, SelectNode, SelectEntry );  ForAllDo( L.node, ShowSelectedNode, ShowSelectedEntry );
		ForAllDo( L.node, DeSelectNode, DeSelectEntry )
	END UnHideAll;

	PROCEDURE DoHideSelection( L: tLayer );
	BEGIN
		ForAllDo( L.node, HideSelectedNode, HideSelectedEntry )
	END DoHideSelection;

	PROCEDURE SelectInRectNode( n: tNode );
	BEGIN
		IF vyRectangles.EmptyIntersection( n.X, n.Y, n.W, n.H, Xtemp, Ytemp, Wtemp, Htemp ) THEN n.selected := FALSE
		ELSE n.selected := TRUE
		END
	END SelectInRectNode;

	PROCEDURE SelectInRectEntry( n: tEntry );
	BEGIN
		IF vyRectangles.EmptyIntersection( n.X, n.Y, n.W, n.H, Xtemp, Ytemp, Wtemp, Htemp ) THEN n.selected := FALSE
		ELSE n.selected := TRUE
		END
	END SelectInRectEntry;

	PROCEDURE DoSelect( L: tLayer;  x, y, w, h: INTEGER );
	BEGIN
		Xtemp := x;  Ytemp := y;  Wtemp := w;  Htemp := h;  vyGraphBase.Global2Local( Xtemp, Ytemp );
		ForAllVisibleDo( L.node, SelectInRectNode, SelectInRectEntry )
	END DoSelect;

	PROCEDURE SubscribeNameNode( n: tNode );
	BEGIN
		IF n.selected THEN COPY( n.name, tempLayer.forbidden[tempLayer.forbiddencount] );  INC( tempLayer.forbiddencount ) END
	END SubscribeNameNode;

	PROCEDURE SubscribeNameEntry( n: tEntry );
	BEGIN
		IF n.selected THEN COPY( n.name, tempLayer.forbidden[tempLayer.forbiddencount] );  INC( tempLayer.forbiddencount ) END
	END SubscribeNameEntry;

	PROCEDURE HideIfForbiddenNode( n: tNode );
	VAR i: INTEGER;
	BEGIN
		FOR i := 0 TO tempLayer.forbiddencount - 1 DO
			IF Equal( tempLayer.forbidden[i], n.name ) THEN n.visible := FALSE END
		END
	END HideIfForbiddenNode;

	PROCEDURE HideIfForbiddenEntry( n: tEntry );
	VAR i: INTEGER;
	BEGIN
		FOR i := 0 TO tempLayer.forbiddencount - 1 DO
			IF Equal( tempLayer.forbidden[i], n.name ) THEN n.visible := FALSE END
		END
	END HideIfForbiddenEntry;

	PROCEDURE SelectIfForbiddenNode( n: tNode );
	VAR i: INTEGER;
	BEGIN
		FOR i := 0 TO tempLayer.forbiddencount - 1 DO
			IF Equal( tempLayer.forbidden[i], n.name ) THEN n.selected := TRUE END
		END
	END SelectIfForbiddenNode;

	PROCEDURE SelectIfForbiddenEntry( n: tEntry );
	VAR i: INTEGER;
	BEGIN
		FOR i := 0 TO tempLayer.forbiddencount - 1 DO
			IF Equal( tempLayer.forbidden[i], n.name ) THEN n.selected := TRUE END
		END
	END SelectIfForbiddenEntry;

	PROCEDURE HideNamed;
	BEGIN
		ForAllDo( tempLayer.node, SubscribeNameNode, SubscribeNameEntry );
		ForAllDo( tempLayer.node, HideIfForbiddenNode, HideIfForbiddenEntry );  vyBase.Update( tempLayer )
	END HideNamed;

	PROCEDURE Select( L: tLayer;  VAR event: vyEvents.EventMsg );
	VAR x0, y0: INTEGER;  oldx, oldy: INTEGER;
	BEGIN
		tempLayer := L;  UnSelectAll( L );  vyGraphBase.SetDisplayMode( vyGraphBase.invert );  x0 := event.x;  y0 := event.y;
		vyEvents.GetEvent( event );
		WHILE (event.gesture = vyEvents.EvtSelect) DO
			oldx := event.x;  oldy := event.y;  vyEvents.GetEvent( event );
			IF (oldx # event.x) OR (oldy # event.y) THEN
				vyGraphBase.FrameRect( x0, y0, oldx - x0, oldy - y0 );  DoSelect( L, x0, y0, event.x - x0, event.y - y0 );
				vyBase.Update( L );  vyGraphBase.SetDisplayMode( vyGraphBase.invert );
				vyGraphBase.FrameRect( x0, y0, event.x - x0, event.y - y0 )
			END
		END;
		vyGraphBase.FrameRect( x0, y0, event.x - x0, event.y - y0 );
		IF event.gesture = vyEvents.EvtRemove THEN HideNamed() END
	END Select;

	PROCEDURE InNode( L: tLayer;  x, y: INTEGER ): tNode;
	BEGIN
		vyGraphBase.Global2Local( x, y );  RETURN xyinNode( L.node, x, y )
	END InNode;

	PROCEDURE InEntry( L: tLayer;  x, y: INTEGER;  VAR mynode: tNode ): tEntry;
	BEGIN
		vyGraphBase.Global2Local( x, y );  RETURN xyinEntry( L.node, x, y, mynode )
	END InEntry;

	PROCEDURE EntryUpdate( Entry: tEntry );
	VAR msg: Objects.AttrMsg;
	BEGIN
		IF tempNode # NIL THEN
			IF Entry.visible THEN
				msg.id := Objects.get;  COPY( Entry.name, msg.name );  msg.res := -1;  tempNode.root.handle( tempNode.root, msg );
				IF msg.res >= 0 THEN
					Entry.val := "";
					CASE msg.class OF
					Objects.String:
							vyHostStrings.Append( Entry.val, msg.s );
					| Objects.Bool:
							IF msg.b = TRUE THEN vyHostStrings.Append( Entry.val, "TRUE" ) ELSE vyHostStrings.Append( Entry.val, "FALSE" ) END;
					| Objects.Char:
							Entry.val[0] := msg.c;  Entry.val[1] := 0X;
					| Objects.LongReal:
							vyHostStrings.AppendLongReal( msg.y, 1, Entry.val );
					| Objects.Real:
							vyHostStrings.AppendReal( msg.x, 1, Entry.val );
					| Objects.Int:
							vyHostStrings.AppendInt( msg.i, 1, Entry.val )
					END
				END
			END
		END
	END EntryUpdate;

	PROCEDURE SetTempNode( n: tNode );
	BEGIN
		IF n.visible THEN tempNode := n ELSE tempNode := NIL END
	END SetTempNode;

	PROCEDURE SubscribeMe( n: tNode );
	BEGIN
		IF (n.visible & (~n.repetition) & (n.root # NIL )) THEN vyBase.Subscribe( n.root, tempLayer ) END
	END SubscribeMe;

	PROCEDURE NodeSubscribe( L: tLayer );
	BEGIN
		tempLayer := L;  ForAllDo( L.node, SubscribeMe, NIL )
	END NodeSubscribe;

	PROCEDURE LinksUpdate( L: tLayer );
	BEGIN
		ForAllVisibleDo( L.node, SetTempNode, EntryUpdate )
	END LinksUpdate;

	PROCEDURE UpdateSpecial( L: tLayer );
	BEGIN
		tempLayer := L;  maxdepth := 1;  L.node.entries := NIL;  NEW( ObjList );  LastObj := ObjList;  Entries( L.node, "All", "", 0 );
		L.lastLink := 0;  maxdepth := MAXD;  ForAllDo( L.node, DeSelectNode, SelectEntry );  DeleteSelected( L.node )
	END UpdateSpecial;

	PROCEDURE Recall( layer: tLayer;  msg: Display.DisplayMsg );
	VAR x, y, w, h: INTEGER;  hp: vyPort.Picture;  drx, dry, xr, yr: LONGREAL;
	BEGIN
		IF (layer.lifeUpdate) & ((Oberon.Time() - layer.lastLink) > TICKS) THEN
			LinksUpdate( layer );  layer.lastLink := Oberon.Time()
		END;
		hp := msg.dlink( vyPort.Picture );  vyPort.GetPictureScreenRegion( hp, x, y, w, h );
		vyGraphBase.SetStringJustification( vyGraphBase.left, vyGraphBase.center );
		vyGraphBase.SetBackColor( layer.style.fillcol );  vyGraphBase.VectorToVector2d( distx, disty, drx, dry );  xr := 0;
		yr := 1;

		RecallNode( layer.node, xr, yr, 0, 1, drx, dry, y, y + h )
	END Recall;

	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );
	(** vs 0.0d0	md  14.07.94 *)
	VAR priority: INTEGER;  node, entrynode: tNode;  entry: tEntry;
	BEGIN
		priority := vyEvents.PrioNone;
		IF (event.gesture = vyEvents.EvtIdent) THEN priority := vyEvents.PrioNormal
		ELSIF (event.gesture = vyEvents.EvtSelect) THEN priority := vyEvents.PrioNormal
		ELSIF (event.gesture = vyEvents.EvtLoc) THEN
			node := InNode( layer, event.x, event.y );  entry := InEntry( layer, event.x, event.y, entrynode );
			IF (node # NIL ) OR (entry # NIL ) THEN priority := vyEvents.PrioNormal END;
		END;

		IF event.priority < priority THEN event.responder := layer;  event.priority := priority
		END
	END Responsible;

	PROCEDURE GetGadgetsTable( CONST name: ARRAY OF CHAR ): vyTracking.List;
	VAR list: ViewList;  gen: vyTracking.List;
	BEGIN
		list := gadgets;
		WHILE list # NIL DO
			gen := list.gen;
			WHILE (gen # NIL ) DO
				IF (name = gen.name) THEN RETURN list.this END;
				gen := gen.next
			END;
			list := list.next
		END;
		RETURN GVList.this
	END GetGadgetsTable;

	PROCEDURE MakeTextField( n: tNode;  e: tEntry;  event: vyEvents.EventMsg );
	VAR model, TF: Objects.Object;  list, res: vyTracking.List;
		class: ARRAY 32 OF CHAR;

	BEGIN
		model := antsObjects.BasicModel( n.root, e.name, class );  list := GetGadgetsTable( class );

		IF list # NIL THEN
			vyTracking.ScrollList( list, event.x, event.y, res );
			IF res # NIL THEN
				IF res.name = HideEntryConstName THEN e.visible := ~e.visible;  RETURN END
			ELSE RETURN
			END
		ELSE RETURN
		END;

		TF := Gadgets.CreateObject( res.name );  Texts.WriteString( vyHostTexts.w, n.name );
		Texts.WriteString( vyHostTexts.w, " " );  Texts.WriteString( vyHostTexts.w, n.val );
		Texts.WriteString( vyHostTexts.w, e.name );  Texts.WriteString( vyHostTexts.w, " :: " );  Texts.Write( vyHostTexts.w, 09X );
		vyHostTexts.InsertLog( vyHostTexts.w.buf );

		antsObjects.GadgetToModel( res.name, model );  vyHostTexts.Msg( " " )
	END MakeTextField;

	PROCEDURE GetTable( CONST name: ARRAY OF CHAR ): vyTracking.List;
	VAR list: ViewList;  gen: vyTracking.List;
	BEGIN
		list := GVList;
		WHILE list # NIL DO
			gen := list.gen;
			WHILE (gen # NIL ) DO
				IF (name = gen.name) THEN RETURN list.this END;
				gen := gen.next
			END;
			list := list.next
		END;
		RETURN GVList.this
	END GetTable;

	PROCEDURE ViewObject( n: tNode;  e: vyEvents.EventMsg );
	VAR list, res: vyTracking.List;  vylist: vyLinks.Link;  msg: Objects.AttrMsg;  idname: vyName.tNameArray;
	BEGIN

		msg.name := "Gen";  msg.res := -1;  msg.id := Objects.get;
		IF n.root # NIL THEN n.root.handle( n.root, msg ) ELSE RETURN END;
		IF (msg.res >= 0) THEN
			list := GetTable( msg.s );
			IF list # NIL THEN
				vyTracking.ScrollList( list, e.x, e.y, res );
				IF res # NIL THEN
					IF res.name = HideEntryConstName THEN n.entriesvisible := ~n.entriesvisible
					ELSIF res.name = RegisterEntryConstName THEN
						IF n.root IS vyBase.Object THEN
							vyName.GetObjId( n.root( vyBase.Object ), idname );
							vyName.RegisterNamed( n.root( vyBase.Object ), idname ) (* -> first in queue *)
						END
					ELSIF res.name = WriteAllEntriesConstName THEN antsObjects.DoAllFields( n.root, FALSE )
					ELSIF res.name = ShowConstName THEN
						IF n.root IS vyBase.Object THEN vyLinks.InsertObj( vylist, n.root );  vyBase.Show( vylist, 1, "antsPlots" ) END
					ELSIF n.root IS vyBase.Object THEN vyLinks.InsertObj( vylist, n.root );  vyBase.Show( vylist, 1, res.name )
					END
				END
			END
		END
	END ViewObject;

	PROCEDURE ViewEntry( entrynode: tNode;  entry: tEntry;  event: vyEvents.EventMsg );
	BEGIN
		MakeTextField( entrynode, entry, event )
	END ViewEntry;

	PROCEDURE Respond( layer: tLayer;  VAR event: vyEvents.EventMsg );
	VAR node: tNode;  entry: tEntry;  entrynode: tNode;
	BEGIN
		tempLayer := layer;

		node := InNode( layer, event.x, event.y );  entry := InEntry( layer, event.x, event.y, entrynode );
		IF entry # NIL THEN ViewEntry( entrynode, entry, event );  vyBase.Update( layer )
		ELSIF node # NIL THEN
			ViewObject( node, event );  vyBase.Update( layer )
			(*ELSIF entry # NIL THEN
		ViewEntry(entrynode, entry, event);
		vyBase.Update(layer)
		*)
		ELSE vyCommandMenus.ExecuteListedCommand( event.x, event.y, event, layer.commands )
		END

	END Respond;

	PROCEDURE Copy( M: Objects.ObjMsg;  source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Bind( o: Objects.Object;  VAR M: Objects.BindMsg );
	BEGIN
		IF (o # NIL ) & (M.lib # o.lib) THEN
			Gadgets.BindObj( o, M.lib );
			IF o.handle # NIL THEN o.handle( o, M ) END
		END
	END Bind;

	PROCEDURE BindAll( n: tNode;  VAR M: Objects.BindMsg );
	VAR e: tEntry;
	BEGIN
		IF n = NIL THEN RETURN END;
		IF n.root # NIL THEN Bind( n.root, M ) END;
		IF n.entries # NIL THEN
			e := n.entries( tEntry );
			WHILE (e # NIL ) DO
				IF e.node # NIL THEN BindAll( e.node, M ) END;
				IF e.link = NIL THEN e := NIL ELSE e := e.link( tEntry ) END
			END
		END
	END BindAll;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR copy: tLayer;  uhandle: Objects.Handler;  gen: PROCEDURE;

	CONST GenProc = "antsObjectView.Gen";   (* Gen Procedure as String *)
	BEGIN
		uhandle := vyPort.LayerHandler;   (* handler of root object*)
		gen := Gen;   (* gen Procedure as PROCEDURE *)

		WITH o: tLayer DO
			IF M IS Display.DisplayMsg THEN
				WITH M: Display.DisplayMsg DO
					uhandle( o, M );  Recall( o, M ) (* call root handle first if in background *)
				END;
			ELSIF M IS vyBase.UpdateMessage THEN
				WITH M: vyBase.UpdateMessage DO
					IF o.node.root = antsObjects.obj THEN UpdateSpecial( o ) END;
					uhandle( o, M );
				END;
			ELSIF M IS vyEvents.EventMsg THEN
				WITH M: vyEvents.EventMsg DO
					IF M.callForResponder THEN
						Responsible( o, M );  uhandle( o, M ) (* if not responsible: maybe root is *)
					ELSE
						IF (M.gesture = vyEvents.EvtIdent) OR (M.gesture = vyEvents.EvtLoc) THEN Respond( o, M )
						ELSIF M.gesture = vyEvents.EvtSelect THEN Select( o, M )
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
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( GenProc, M.s );  M.class := Objects.String;  M.res := 0 ELSE uhandle( o, M ) END
					ELSIF M.id = Objects.enum THEN M.Enum( "Gen" );  uhandle( o, M )
					ELSE uhandle( o, M )
					END
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					IF M.lib # o.lib THEN uhandle( o, M );  BindAll( o.node, M ) END
					(* add own binds here: Bind(o.entry,M) *)
				END;
			ELSE uhandle( o, M )
			END
		END
	END Handler;

	PROCEDURE HideSelection;
	BEGIN
		DoHideSelection( tempLayer );  vyBase.Update( tempLayer )
	END HideSelection;

	PROCEDURE InvSelNode( n: tNode );
	BEGIN
		n.selected := ~n.selected
	END InvSelNode;

	PROCEDURE InvSelEntry( e: tEntry );
	BEGIN
		e.selected := ~e.selected
	END InvSelEntry;

	PROCEDURE InverseSelection;
	BEGIN
		ForAllDo( tempLayer.node, InvSelNode, InvSelEntry )
	END InverseSelection;

	PROCEDURE InvHideSelection;
	BEGIN
		InverseSelection();  HideSelection()
	END InvHideSelection;

	PROCEDURE ShowAll;
	BEGIN
		UnHideAll( tempLayer );  tempLayer.forbiddencount := 0;  tempLayer.lastLink := 0;  vyBase.Update( tempLayer )
	END ShowAll;

	PROCEDURE AutoUpdate;
	BEGIN
		tempLayer.lifeUpdate := TRUE
	END AutoUpdate;

	PROCEDURE NoAutoUpdate;
	BEGIN
		tempLayer.lifeUpdate := FALSE
	END NoAutoUpdate;

	PROCEDURE ManualUpdate;
	BEGIN
		LinksUpdate( tempLayer );  vyBase.Update( tempLayer )
	END ManualUpdate;

	PROCEDURE Big;
	BEGIN
		tempLayer.style.fnt := "Syntax12.Scn.Fnt";  vyBase.Update( tempLayer )

	END Big;

	PROCEDURE Med;
	BEGIN
		tempLayer.style.fnt := "Syntax10.Scn.Fnt";  vyBase.Update( tempLayer )

	END Med;

	PROCEDURE Small;
	BEGIN
		tempLayer.style.fnt := "Syntax8.Scn.Fnt";  vyBase.Update( tempLayer )
	END Small;

	PROCEDURE CollapseNode( n: tNode );
	BEGIN
		n.entriesvisible := FALSE
	END CollapseNode;

	PROCEDURE Collapse;
	BEGIN
		ForAllDo( tempLayer.node, CollapseNode, NIL );  tempLayer.node.entriesvisible := TRUE;  vyBase.Update( tempLayer )
	END Collapse;

	PROCEDURE DeleteSelected( n: tNode );
	VAR e: tEntry;  laste: tEntry;
	BEGIN
		IF n.entries # NIL THEN
			e := n.entries( tEntry );
			WHILE (e # NIL ) DO
				IF ((e.node # NIL ) & (e.node.selected)) OR (e.selected) THEN
					IF (e.node # NIL ) & (e.node.root # NIL ) THEN vyBase.UnSubscribe( e.node.root, tempLayer ) END;
					IF e = n.entries THEN
						n.entries := e.link;  e.link := NIL;
						IF n.entries # NIL THEN e := n.entries( tEntry ) ELSE e := NIL END
					ELSIF e.link = NIL THEN laste.link := NIL;  e.link := NIL;  e := NIL
					ELSE laste.link := e.link;  e.link := NIL;  e := laste.link( tEntry )
					END
				ELSIF e.node # NIL THEN
					DeleteSelected( e.node );  laste := e;
					IF e.link = NIL THEN e := NIL ELSE e := e.link( tEntry ) END
				ELSE
					laste := e;
					IF e.link = NIL THEN e := NIL ELSE e := e.link( tEntry ) END
				END
			END
		END
	END DeleteSelected;

	PROCEDURE Delete;
	BEGIN
		DeleteSelected( tempLayer.node );  vyBase.Update( tempLayer )
	END Delete;

	PROCEDURE InvDelete;
	BEGIN
		InverseSelection;  Delete
	END InvDelete;

	PROCEDURE DeleteFromDummy;
	BEGIN
		ListFromDummy( tempLayer );  UnSelectAll( tempLayer );
		ForAllDo( tempLayer.node, SelectIfForbiddenNode, SelectIfForbiddenEntry );  Delete
	END DeleteFromDummy;

	PROCEDURE Noop;
	END Noop;

	PROCEDURE DeleteNamed;
	BEGIN
		ForAllDo( tempLayer.node, SubscribeNameNode, SubscribeNameEntry );
		ForAllDo( tempLayer.node, SelectIfForbiddenNode, SelectIfForbiddenEntry );  Delete
	END DeleteNamed;

	PROCEDURE Init( image: tLayer );
	BEGIN
		image.commands := NIL;  vyCommandMenus.Add( image.commands, DeleteFromDummy, "Delete vyBaseObj Entries" );
		vyCommandMenus.Add( image.commands, InvDelete, "! Delete But Selected " );  vyCommandMenus.Add( image.commands, DeleteNamed, "! Delete Named " );
		vyCommandMenus.Add( image.commands, Delete, "! Delete Selected " );  vyCommandMenus.Add( image.commands, Collapse, "Collapse All" );
		vyCommandMenus.Add( image.commands, HideSelection, "Hide Selection" );
		vyCommandMenus.Add( image.commands, InvHideSelection, "View Only Selection" );
		vyCommandMenus.Add( image.commands, ShowAll, "Show All" );  vyCommandMenus.Add( image.commands, HideNamed, "Hide  Named" );
		vyCommandMenus.Add( image.commands, ManualUpdate, "Manual Update" );
		vyCommandMenus.Add( image.commands, AutoUpdate, "Automatic Updates" );
		vyCommandMenus.Add( image.commands, NoAutoUpdate, "No Automatic Updates" );  vyCommandMenus.Add( image.commands, Big, "Font: Big" );
		vyCommandMenus.Add( image.commands, Med, "Font: Medium" );  vyCommandMenus.Add( image.commands, Small, "Font: Small" );
		vyCommandMenus.Add( image.commands, Noop, "-- ** antsObjectView, fof ** --" )
	END Init;

	PROCEDURE Gen*;
	VAR l: tLayer;
	BEGIN
		aM.cmd;  NEW( l );  Init( l );  l.handle := Handler;  Objects.NewObj := l
	END Gen;

	PROCEDURE AllObjects*;
	VAR obj: vyBase.Object;  c: vyDisplay2d.tCoordinate2d;  pict: vyPort.Picture;  x, y, w, h: REAL;  L: tLayer;
		name: ARRAY 256 OF CHAR;
	BEGIN
		aM.vS( "antsObejctView.AllObjects, view all current Objects" );  aM.vS( "Warning; antsObjectViews decrease system speed" );  obj := antsObjects.obj;  NEW( L );  L.forbiddencount := 0;  vyPort.OpenLayer( L, "OV" );
		L.style.selectcol := vyGraphBase.lgrey;  L.style.fillcol := vyGraphBase.yellow;  L.style.fnt := "Syntax8.Scn.Fnt";  tempLayer := L;
		L.handle := Handler;  Init( L );  vyName.GetObjId( obj, name );  NEW( ObjList );  LastObj := ObjList;  NEW( L.node );
		L.node.root := obj;  L.node.repetition := FALSE;  UpdateSpecial( L );  L.lifeUpdate := FALSE;  x := 0;  y := 0;  w := 1;  h := 1;
		NEW( c );  vyDisplay2d.OpenC2d( c, x, y, w, h );  pict := vyPort.XNewCPicture( 0, 0, 1, 1, c );
		pict.backGround := vyGraphBase.dgrey;  vyPort.AddLayer( pict, L );  vyBase.Subscribe( pict, L );  vyPort.Write( pict );
		vyBase.Subscribe( obj, L )
	END AllObjects;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;  c: vyDisplay2d.tCoordinate2d;  pict: vyPort.Picture;  x, y, w, h: REAL;  L: tLayer;
		name: ARRAY 256 OF CHAR;
	BEGIN
		aM.vS( "antsObjectView.ShowP" );  data := vyBase.NextParObj();
		WHILE (data # NIL ) DO

			IF ~(data IS vyBase.Object) THEN aM.eS( "Object view needs an object" );  RETURN
			END;

			NEW( L );  L.forbiddencount := 0;
			IF nousersandsources THEN
				L.forbidden[L.forbiddencount] := "User ";  INC( L.forbiddencount );  L.forbidden[L.forbiddencount] := "Source ";  INC( L.forbiddencount )
			END;
			vyPort.OpenLayer( L, "OV" );  L.style.selectcol := vyGraphBase.orange;  L.style.fillcol := vyGraphBase.yellow;
			L.style.fnt := "Syntax8.Scn.Fnt";  tempLayer := L;  L.handle := Handler;  Init( L );  vyName.GetObjId( data( vyBase.Object ), name );
			NEW( ObjList );  LastObj := ObjList;  NEW( L.node );  L.node.root := data;  L.node.repetition := FALSE;
			Entries( L.node, "root", name, 0 );  L.lastLink := Oberon.Time();  NodeSubscribe( L );  L.lifeUpdate := TRUE;

			x := 0;  y := 0;  w := 1;  h := 1;  NEW( c );  vyDisplay2d.OpenC2d( c, x, y, w, h );
			pict := vyPort.XNewCPicture( 0, 0, 1, 1, c );  pict.backGround := vyGraphBase.dgrey;  vyPort.AddLayer( pict, L );
			vyBase.Subscribe( pict, L );  vyPort.Write( pict );  data := vyBase.NextParObj()
		END
	END ShowP;

	PROCEDURE EnableUsersAndSources*;
	BEGIN
		aM.vS( "antsObjectView.DisableUsersAndSources, Users and Sources do get displayed in new plots" );  nousersandsources := FALSE
	END EnableUsersAndSources;

	PROCEDURE DisableUsersAndSources*;
	BEGIN
		aM.vS( "antsObjectView.DisableUsersAndSources, Users and Sources don't get displayed in new plots" );  nousersandsources := TRUE
	END DisableUsersAndSources;

	PROCEDURE TrackingInsertName( VAR list: vyTracking.List;  CONST name: ARRAY OF CHAR );
	VAR temp: vyTracking.List;
	BEGIN
		IF list = NIL THEN NEW( list );  COPY( name, list.name );  RETURN END;
		temp := list;
		WHILE (temp.next # NIL ) DO temp := temp.next END;
		NEW( temp.next );  temp := temp.next;  COPY( name, temp.name )
	END TrackingInsertName;

	PROCEDURE InitGVList;
	VAR list: ViewList;  T: Texts.Text;  gen, show: vyTracking.List;  sc: Texts.Scanner;
	BEGIN
		NEW( GVList );  list := GVList;  TrackingInsertName( list.gen, "DUMMY" );  TrackingInsertName( list.this, WriteAllEntriesConstName );
		TrackingInsertName( list.gen, "DUMMY" );  TrackingInsertName( list.this, RegisterEntryConstName );
		TrackingInsertName( list.gen, "DUMMY" );  TrackingInsertName( list.this, HideEntryConstName );
		TrackingInsertName( list.gen, "DUMMY" );  TrackingInsertName( list.this, ShowConstName );

		NEW( gadgets );  list := gadgets;  TrackingInsertName( list.gen, "DUMMY" );  TrackingInsertName( list.this, HideEntryConstName );
		vyHost.GetNamedText( "antsObjectView.Gadgets", T );  Texts.OpenScanner( sc, T, 0 );
		REPEAT
			gen := NIL;  show := NIL;  Texts.Scan( sc );
			WHILE (sc.class = Texts.Name) DO TrackingInsertName( gen, sc.s );  Texts.Scan( sc ) END;
			Texts.Scan( sc );
			WHILE (sc.class = Texts.Name) DO TrackingInsertName( show, sc.s );  Texts.Scan( sc ) END;
			TrackingInsertName( show, HideEntryConstName );  NEW( list.next );  list := list.next;  list.gen := gen;  list.this := show
		UNTIL sc.eot

	END InitGVList;

BEGIN
	aM.launch;  nousersandsources := FALSE;  InitGVList;  maxdepth := MAXD;
END antsObjectView.

antsObjectView.TryOut > name Array ~
Voyager.Show Sampler as antsObjectView~


antsObjectView.AllObjects ~


fofAutomatic.Do
System.Time
antsDiscreteFields.NewArray > name Array > size 50 50 > depth 2~
antsViews.Show > name Array ~
antsBinaryIsingS.NewModel > name Model  > h 0.0 > beta 0.3 ~
antsGibbs.DefineGibbsSampler > name Sampler > presteps 0 > steps 100 ~
antsGibbs.AttachModel > sampler Sampler > model Model ~
antsGibbs.AttachArray > sampler Sampler > array Array ~
System.Time
~

System.Free antsObjectView ~

