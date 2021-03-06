MODULE WMAStar; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "A* Pathfinder"; *)

IMPORT

	SYSTEM, Modules, Commands, Raster, WMWindowManager,
	WMDialogs, WMGraphics, WMRectangles, Strings,
	Generics;
	
CONST

	A_STAR = "A* Pathfinder";

	MAP =
		[
			[8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 4, 4, 6, 4, 4, 6, 4, 6, 4, 4, 4, 6, 4],
			[8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4],
			[8, 0, 3, 3, 0, 0, 0, 0, 0, 8, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6],
			[8, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6],
			[8, 0, 3, 3, 0, 0, 0, 0, 0, 8, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4],
			[8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 4, 0, 0, 0, 0, 0, 6, 6, 6, 0, 6, 4, 6],
			[8, 8, 8, 8, 0, 8, 8, 8, 8, 8, 8, 4, 4, 4, 4, 4, 4, 6, 0, 0, 0, 0, 0, 6],
			[7, 7, 7, 7, 0, 7, 7, 7, 7, 0, 8, 0, 8, 0, 8, 0, 8, 4, 0, 4, 0, 6, 0, 6],
			[7, 7, 0, 0, 0, 0, 0, 0, 7, 8, 0, 8, 0, 8, 0, 8, 8, 6, 0, 0, 0, 0, 0, 6],
			[7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 6, 0, 0, 0, 0, 0, 4],
			[7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 6, 0, 6, 0, 6, 0, 6],
			[7, 7, 0, 0, 0, 0, 0, 0, 7, 8, 0, 8, 0, 8, 0, 8, 8, 6, 4, 6, 0, 6, 6, 6],
			[7, 7, 7, 7, 0, 7, 7, 7, 7, 8, 8, 4, 0, 6, 8, 4, 8, 3, 3, 3, 0, 3, 3, 3],
			[2, 2, 2, 2, 0, 2, 2, 2, 2, 4, 6, 4, 0, 0, 6, 0, 6, 3, 0, 0, 0, 0, 0, 3],
			[2, 2, 0, 0, 0, 0, 0, 2, 2, 4, 0, 0, 0, 0, 0, 0, 4, 3, 0, 0, 0, 0, 0, 3],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 4, 3, 0, 0, 0, 0, 0, 3],
			[1, 0, 0, 0, 0, 0, 0, 0, 1, 4, 4, 4, 4, 4, 6, 0, 6, 3, 3, 0, 0, 0, 3, 3],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 1, 2, 2, 2, 6, 6, 0, 0, 5, 0, 5, 0, 5],
			[2, 2, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 0, 5, 0, 5, 0, 0, 0, 5, 5],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 5, 0, 5, 0, 5, 0, 5, 0, 5],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 5, 0, 5, 0, 5, 0, 5, 0, 5],
			[2, 2, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 0, 5, 0, 5, 0, 0, 0, 5, 5],
			[2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5]
		];
	
	MAP_HEIGHT = LEN(MAP, 0);
	MAP_WIDTH = LEN(MAP, 1);
	
	CELL_WIDTH	= 20;
	
TYPE

	PointDesc = RECORD
		x, y: LONGINT;
	END;

	(** Data used for A* pathfinding *)
	Node = POINTER TO RECORD
		nodeParent: Node;
		(* World coordinates *)
		p: PointDesc;
		(* Costs *)
		F, G, H: LONGINT;
		(* Beeng in Open or Closed list *)
		bOpen: BOOLEAN;
	END;
	
	NodeItem = RECORD(Generics.Item)
		value: Node
	END;
	
	(** Binary node's heap. F cost used as a key *)
	NodeFHeap = OBJECT(Generics.Heap)
	VAR
		array: POINTER TO ARRAY OF NodeItem;

		PROCEDURE &New*;
		VAR
			pCompA, pCompB: POINTER TO NodeItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewHeap(SIZEOF(NodeItem), pCompA, pCompB, Less)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;
		
		PROCEDURE Less(pA, pB: Generics.PItem): BOOLEAN;
		BEGIN
			RETURN pA^(NodeItem).value.F < pB^(NodeItem).value.F
		END Less;
		
		PROCEDURE Add(node: Node);
		VAR
			item: NodeItem;
		BEGIN
			item.value := node;
			AddInternal(item)
		END Add;
		
		PROCEDURE Update(node: Node);
		VAR
			item: NodeItem;
		BEGIN
			item.value := node;
			UpdateInternal(item)
		END Update;
		
		PROCEDURE Remove(VAR node: Node): BOOLEAN;
		VAR
			item: NodeItem;
		BEGIN
			IF RemoveInternal(item) THEN
				node := item.value;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END Remove;
		
	END NodeFHeap;
	
	NodeTreeItem = RECORD(Generics.TreeItem)
		key: Node
	END;
	
	(** Node's map. (X, Y) pair used as a key *)
	NodeXYMap = OBJECT(Generics.Tree)
	VAR
		array: POINTER TO ARRAY OF NodeTreeItem;

		PROCEDURE &New*;
		VAR
			pCompA, pCompB: POINTER TO NodeTreeItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewTree(SIZEOF(NodeTreeItem), pCompA, pCompB, Less)
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;
		
		PROCEDURE Less(pA, pB: Generics.PItem): BOOLEAN;
		BEGIN
			(* Lexicographical coordinates ordering *)
			RETURN (pA^(NodeTreeItem).key.p.x < pB^(NodeTreeItem).key.p.x) OR
				((pA^(NodeTreeItem).key.p.x = pB^(NodeTreeItem).key.p.x) &
					(pA^(NodeTreeItem).key.p.y < pB^(NodeTreeItem).key.p.y))
		END Less;
		
		PROCEDURE Insert(node: Node);
		VAR
			item: NodeTreeItem;
		BEGIN
			item.key := node;
			InsertInternal(item)
		END Insert;
		
		PROCEDURE Contains(node: Node): BOOLEAN;
		VAR
			item: NodeTreeItem;
		BEGIN
			item.key := node;
			RETURN ContainsInternal(item)
		END Contains;
			
		PROCEDURE Get(node: Node): Node;
		VAR
			item: NodeTreeItem;
		BEGIN
			item.key := node;
			GetInternal(item);
			RETURN item.key
		END Get;
			
	END NodeXYMap;
	
	Window = OBJECT(WMWindowManager.BufferWindow);
		VAR
			bPointerDown, bSetStart, bSetStop: BOOLEAN;
			ptStart, ptStop: PointDesc;
			nodeStop: Node;

		PROCEDURE &New*;
		BEGIN
			bPointerDown := FALSE;
			bSetStart := FALSE;
			bSetStop := FALSE;
			nodeStop := NIL;
			Init(nMapPixelsWidth, nMapPixelsHeight, FALSE);
			WMWindowManager.ExtAddWindow(SELF, 200, 200,
				{WMWindowManager.FlagFrame, WMWindowManager.FlagClose,
					WMWindowManager.FlagMinimize, WMWindowManager.FlagNoResizing});
			SetTitle(Strings.NewString(A_STAR));
			canvas.Fill(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()), WMGraphics.Black, WMGraphics.ModeCopy);
			Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
			Frame;
			SetPointerInfo(manager.pointerCrosshair)
		END New;
		
		PROCEDURE DrawPath(canvas: WMGraphics.Canvas);
		VAR
			n: LONGINT;
			node: Node;
		BEGIN
			(*Draw^(canvas, w, h, q);*)
			n := CELL_WIDTH DIV 2;
			IF bSetStart & bSetStop THEN
				(* Draw path *)
				node := nodeStop;
				WHILE node # NIL DO
					IF node.nodeParent # NIL THEN
						canvas.Line(
							(node.p.x - 1) * CELL_WIDTH + n,
							(node.p.y - 1) * CELL_WIDTH + n,
							(node.nodeParent.p.x - 1) * CELL_WIDTH + n,
							(node.nodeParent.p.y - 1) * CELL_WIDTH + n,
							WMGraphics.Cyan, WMGraphics.ModeCopy)
					END;
					node := node.nodeParent
				END
			ELSIF bSetStart THEN
				(* Draw start *)
				canvas.SetPixel((ptStart.x - 1) * CELL_WIDTH + n,
					(ptStart.y - 1) * CELL_WIDTH + n,
					WMGraphics.Cyan, WMGraphics.ModeCopy)
			END
		END DrawPath;
		
		PROCEDURE Frame;
		VAR
			y: LONGINT;
			mode: Raster.Mode;
		BEGIN
			(* Draw map *)
			Raster.InitMode(mode, Raster.srcCopy);
			FOR y := 0 TO nMapPixelsHeight - 1 DO
				Raster.PutPixels(img, 0, y, nMapPixelsWidth, Raster.BGRA8888,
					bufMapPixels^, y * nMapPixelsWidth * 4, mode)
			END;
			(*FOR y := 0 TO nMapPixelsHeight - 1 DO
				FOR x := 0 TO nMapPixelsWidth  - 1 DO
					pixel[0] := bufMapPixels^[y * nMapPixelsWidth * 4 + x * 4];
					pixel[1] := bufMapPixels^[y * nMapPixelsWidth * 4 + x * 4 + 1];
					pixel[2] := bufMapPixels^[y * nMapPixelsWidth * 4 + x * 4 + 2];
					pixel[3] := bufMapPixels^[y * nMapPixelsWidth * 4 + x * 4 + 3];
					IF ORD(pixel[1]) > 0 THEN
						canvas.SetPixel(x, y, WMGraphics.White, WMGraphics.ModeCopy);
					ELSE
						canvas.SetPixel(x, y, WMGraphics.Black, WMGraphics.ModeCopy);
					END;
				END
			END;*)
			DrawPath(canvas);
			Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
		END Frame;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		BEGIN
			IF ~IsHit(x, y) THEN
				RETURN
			END;
			IF bSetStart & bSetStop THEN
				bSetStop := FALSE;
				ptStart.x := x DIV CELL_WIDTH + 1;
				ptStart.y := y DIV CELL_WIDTH + 1;
			ELSIF bSetStart THEN
				bSetStop := TRUE;
				ptStop.x := x DIV CELL_WIDTH + 1;
				ptStop.y := y DIV CELL_WIDTH + 1;
				FindPath(ptStart, ptStop, nodeStop);
				IF nodeStop = NIL THEN
					bSetStart := FALSE;
					bSetStop := FALSE;
				END;
			ELSE
				bSetStart := TRUE;
				ptStart.x := x DIV CELL_WIDTH + 1;
				ptStart.y := y DIV CELL_WIDTH + 1;
			END;
			Frame;
		END PointerDown;

	END Window;
	
VAR
	instance: Window;
  bufMapPixels, bufNodePixels: POINTER TO ARRAY OF CHAR;
	nMapPixelsWidth, nMapPixelsHeight: LONGINT;
	
	PROCEDURE NewNode(nodeParent: Node; x, y: LONGINT; ptStop: PointDesc): Node;
	VAR
		node: Node;
	BEGIN
		NEW(node);
		node.nodeParent := nodeParent;
		IF nodeParent = NIL THEN
			(** absolute start position *)
			node.p.x := x;
			node.p.y := y;
			node.G := 0
		ELSE
			(** relative to parent position *)
			ASSERT((x # 0) OR (y # 0));
			node.p.x := nodeParent.p.x + x;
			node.p.y := nodeParent.p.y + y;
			IF (x # 0) & (y # 0) THEN
				node.G := nodeParent.G + 14
			ELSE
				node.G := nodeParent.G + 10
			END
		END;
		(** estimation to target position *)
		node.H := (ABS(node.p.x - ptStop.x) + ABS(node.p.y - ptStop.y)) * 10;
		(** total cost *)
		node.F := node.G + node.H;
		node.bOpen := TRUE;
		RETURN node
	END NewNode;
	
	PROCEDURE AddAdjacentNodes(heapOpen: NodeFHeap; mapXY: NodeXYMap; node: Node; ptStop: PointDesc);
	VAR
		dx, dy, x, y, G: LONGINT;
		nodeNew, nodeTmp: Node;
		
		PROCEDURE NoCorner(): BOOLEAN;
		VAR
			b: BOOLEAN;
		BEGIN
			b := TRUE;
			IF (dx # 0) & (dy # 0) THEN
				b := (MAP[y, node.p.x] = 0) & (MAP[node.p.y, x] = 0)
			END;
			RETURN b
		END NoCorner;
		
	BEGIN
		FOR dx := -1 TO 1 DO
			FOR dy := -1 TO 1 DO
				IF ~((dx = 0) & (dy = 0)) THEN
					x := node.p.x + dx;
					y := node.p.y + dy;
					IF (0 <= x) & (x < MAP_WIDTH) & (0 <= y) & (y < MAP_HEIGHT) &
						(MAP[y, x] = 0) & NoCorner()
					THEN
						nodeNew := NewNode(node, dx, dy, ptStop);
						IF ~mapXY.Contains(nodeNew) THEN
							heapOpen.Add(nodeNew);
							mapXY.Insert(nodeNew)
						ELSE
							nodeTmp := mapXY.Get(nodeNew);
							(* Figure out G cost *)
							IF (ABS(node.p.x - x) # 0) &
								(ABS(node.p.y - y) # 0)
							THEN
								G := node.G + 14
							ELSE
								G := node.G + 10
							END;
							IF G < nodeTmp.G THEN
								nodeTmp.nodeParent := node;
								nodeTmp.G := G;
								nodeTmp.F := nodeTmp.H + G;
								heapOpen.Update(nodeTmp)
							END
						END
					END
				END 
			END
		END
	END AddAdjacentNodes;
	
	PROCEDURE DialogPos(VAR x, y: LONGINT; win: WMWindowManager.Window; dlgWidth, dlgHeight: LONGINT);
	VAR
		manager: WMWindowManager.WindowManager;
		s: WMWindowManager.WindowStyle;
	BEGIN
		manager := WMWindowManager.GetDefaultManager();
		s := manager.GetStyle();
		x := ENTIER(win.bounds.l + (win.bounds.r - win.bounds.l - dlgWidth) / 2);
		y := ENTIER(win.bounds.t + (win.bounds.b - win.bounds.t - dlgHeight) / 2);
		(*IF s # NIL THEN y := y +  s.th END;*)
	END DialogPos;
	
	PROCEDURE FindPath(ptStart, ptStop: PointDesc; VAR nodeStop: Node);
	VAR
		node, nodeStart: Node;
		heapOpen: NodeFHeap;
		mapXY: NodeXYMap;
		nRes, x, y: LONGINT;
	BEGIN
	
		nodeStart := NewNode(NIL, ptStart.x, ptStart.y, ptStop);
		nodeStop := NewNode(NIL, ptStop.x, ptStop.y, ptStop);
	
		NEW(heapOpen);
		NEW(mapXY);

		mapXY.Insert(nodeStart);
		heapOpen.Add(nodeStart);
		REPEAT
			IF heapOpen.Remove(node) THEN
				node.bOpen := FALSE;
				AddAdjacentNodes(heapOpen, mapXY, node, ptStop)
			END;
			(*iStop := mapXY.IndexOf(nodeStop)*)
			IF mapXY.Contains(nodeStop) THEN
				nodeStop := mapXY.Get(nodeStop)
			END
		UNTIL ~nodeStop.bOpen OR
			(heapOpen.Count() = 0);
		
		IF heapOpen.Count() = 0 THEN
			DialogPos(x, y, instance, 350, 100);
			nRes := WMDialogs.MessageXY(WMDialogs.TError, x, y, A_STAR,
			  "There is no path!", {WMDialogs.ResOk})
		ELSE
			(*nodeStart := mapXY.GetItem(mapXY.IndexOf(nodeStart));
			nodeStop := mapXY.GetItem(iStop);*)
			
			(*nodeStart := mapXY.Get(nodeStart);*)
			(*nodeStop := mapXY.Get(nodeStop);*)
			
			(*KernelLog.String("H: ");
			KernelLog.Int(nodeStart.H, 0);
			KernelLog.Ln;
			KernelLog.String("G: ");
			KernelLog.Int(nodeStop.G, 0);
			KernelLog.Ln;*)
		END;
		
		(*KernelLog.Ln;
		KernelLog.Ln;
		KernelLog.String("nCompAdd: ");
		KernelLog.Int(heapOpen.heap.nCompAdd, 0);
		KernelLog.Ln;
		KernelLog.String("nCompRemove: ");
		KernelLog.Int(heapOpen.heap.nCompRemove, 0);
		KernelLog.Ln;*)
		
	END FindPath;
	
	PROCEDURE InitMapPixels;
	VAR
		x, y, tileX, tileY, x2, y2: LONGINT;
		pixelWall, pixelFloor: Raster.Pixel;
		bTop, bBottom, bLeft, bRight: BOOLEAN;
	BEGIN
		NEW(bufMapPixels, nMapPixelsWidth * nMapPixelsHeight * 4);
		pixelWall[Raster.r] := 080X;
		pixelWall[Raster.g] := 050X;
		pixelWall[Raster.b] := 0X;
		pixelWall[Raster.a] := 020X;
		pixelFloor[Raster.r] := 0X;
		pixelFloor[Raster.g] := 0X;
		pixelFloor[Raster.b] := 0X;
		pixelFloor[Raster.a] := 020X;
		(* draw border *)
		
		FOR y := 0 TO nMapPixelsHeight - 1 DO
			FOR x := 0 TO nMapPixelsWidth - 1 DO
				IF (x = 0) OR (x = nMapPixelsWidth - 1) OR
					(y = 0) OR (y = nMapPixelsHeight - 1)
				THEN
					SYSTEM.PUT32(SYSTEM.ADR(bufMapPixels^[0]) + nMapPixelsWidth * 4 * y + 4 * x,
						SYSTEM.VAL(LONGINT, pixelWall))
				ELSE
					SYSTEM.PUT32(SYSTEM.ADR(bufMapPixels^[0]) + nMapPixelsWidth * 4 * y + 4 * x,
						SYSTEM.VAL(LONGINT, pixelFloor))
				END
			END
		END;
		
		
		tileY := 1;
		FOR y := 1 TO MAP_HEIGHT - 2 DO
			tileX := 1;
			FOR x := 1 TO MAP_WIDTH - 2 DO
				IF MAP[y, x] > 0 THEN
					bBottom := (y + 1 <= MAP_HEIGHT - 2) & (MAP[y + 1, x] = 0);
					bTop := (y - 1 >= 1) & (MAP[y - 1, x] = 0);
					bLeft := (x - 1 >= 1) & (MAP[y, x - 1] = 0);
					bRight := (x + 1 <= MAP_WIDTH - 2) & (MAP[y, x + 1] = 0);
					FOR y2 := 0 TO CELL_WIDTH - 1 DO
						FOR x2 := 0 TO CELL_WIDTH - 1 DO
							IF ((x2 = 0) & bLeft) OR ((y2 = 0) & bTop) OR
								((x2 = CELL_WIDTH - 1) & bRight) OR
								((y2 = CELL_WIDTH - 1) & bBottom) OR
								((x2 + y2) MOD 5 = 0)
							THEN
								SYSTEM.PUT32(SYSTEM.ADR(bufMapPixels^[0]) +
									nMapPixelsWidth * 4 * (tileY + y2) + 4 * (tileX + x2),
									SYSTEM.VAL(LONGINT, pixelWall))
							END
						END
					END
				END;
				INC(tileX, CELL_WIDTH)
			END;
			INC(tileY, CELL_WIDTH)
		END
		
	END InitMapPixels;

	PROCEDURE InitNodePixels;
	VAR
		x, y: LONGINT;
		pixelNode: Raster.Pixel;
	BEGIN
		NEW(bufNodePixels, CELL_WIDTH * CELL_WIDTH * 4);
		pixelNode[Raster.r] := 0X;
		pixelNode[Raster.g] := 0AAX;
		pixelNode[Raster.b] := 055X;
		pixelNode[Raster.a] := 050X;
		FOR y := 0 TO CELL_WIDTH - 1 DO
			FOR x := 0 TO CELL_WIDTH - 1 DO
				SYSTEM.PUT32(SYSTEM.ADR(bufNodePixels^[0]) + CELL_WIDTH * 4 * y + 4 * x,
					SYSTEM.VAL(LONGINT, pixelNode))
			END
		END
	END InitNodePixels;
	
	PROCEDURE WindowGenerator*(ctx: Commands.Context): WMWindowManager.Window;
	BEGIN
		IF instance # NIL THEN RETURN NIL END;
		nMapPixelsWidth := CELL_WIDTH * (MAP_WIDTH - 2) + 2;
		nMapPixelsHeight := CELL_WIDTH * (MAP_HEIGHT - 2) + 2;
		InitMapPixels;
		InitNodePixels;		
		NEW(instance);
		RETURN instance
	END WindowGenerator;

	PROCEDURE Open*(ctx: Commands.Context);
	VAR
		wDummy: WMWindowManager.Window;
	BEGIN
		IF instance = NIL THEN
			wDummy := WindowGenerator(ctx)
		END
	END Open;
	
	PROCEDURE Cleanup;
	BEGIN
		IF instance # NIL THEN
			instance.Close
		END
	END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WMAStar.

WMAStar.Open ~
SystemTools.Free WMAStar Generics ~


