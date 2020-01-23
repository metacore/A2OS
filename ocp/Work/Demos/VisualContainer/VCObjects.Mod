MODULE VCObjects;

(** AUTHOR "Yaroslav Romanchenko (SAGE) http://sage.com.ua/";
	PURPOSE "Visual Objects Container objects"; *)

IMPORT
	Strings, Math, WMEvents, WMComponents,
	Generics, VCTypes, VCBase;

TYPE

	HT* = ENUM
		OUTSIDE*,
		INSIDE*,
		VERTEX*,
		SIDE*
	END;

	CR* = ENUM
		DEFAULT*,
		SIZEALL*,
		HORIZONTAL*,
		VERTICAL*,
		DIAG1*,
		DIAG2*
	END;

	HitTest* = RECORD
		Type*: HT;
		Index*: LONGINT;
	END;

	HitTestParams* = RECORD
		Pos*: VCTypes.Point2i;
		Tolerance*: LONGINT;
	END;

	Command = RECORD
	END;

	CommandBeginDrag* = RECORD(Command)
		Hit*: HitTest;
		StartPos*: VCTypes.Point2f;
	END;

	CommandEndDrag* = RECORD(Command)
	END;

	CommandDrag* = RECORD(Command)
		NewPos*: VCTypes.Point2f;
	END;

	CommandVertexMove = RECORD(Command)
		Index: LONGINT;
		NewPos: VCTypes.Point2f;
	END;

	CommandSideMove = RECORD(Command)
		Index: LONGINT;
		NewPos: VCTypes.Point2f;
	END;

	CommandMove = RECORD(Command)
		DeltaX: REAL;
		DeltaY: REAL;
	END;

	CommandHitTest* = RECORD(Command)
		ConvertIntf*: VCBase.VisualContainerBase;
		Params*: HitTestParams;
		Hit*: HitTest;
	END;

	CommandGetCursor* = RECORD(Command)
		Hit*: HitTest;
		Cursor*: CR;
	END;

	CommandConstructPoint* = RECORD(Command)
		Pos*: VCTypes.Point2f;
		Result*: BOOLEAN
	END;

	CommandProcessConstruct* = RECORD(Command)
		Pos*: VCTypes.Point2f;
	END;

	CommandStopConstruct* = RECORD(Command)
		Result*: BOOLEAN
	END;

	CommandVControl = RECORD(Command)
		Hit: HitTest;
		Pos: VCTypes.Point2f;
	END;

	BaseVisualObject* = OBJECT(WMComponents.Component)
	VAR

		FBasePoints: VCBase.Point2fVector;

		onChange-: WMEvents.EventSource;

		FLockCount: LONGINT;
		FDragging: BOOLEAN;
		FDragHitTest: HitTest;
		FDragStartPos: VCTypes.Point2f;

		PROCEDURE &Init;
		BEGIN
			Init^;

			NEW(FBasePoints);

			(* events *)
			NEW(onChange, SELF, Strings.NewString("onChange"), Strings.NewString("Object changed"), NIL);
			events.Add(onChange);

		END Init;

		PROCEDURE HandleCommand*(VAR command: Command);
		VAR
			i: LONGINT;
			pos: VCTypes.Point2f;
			cmdMove: CommandMove;
			cmdVertexMove: CommandVertexMove;
			cmdSideMove: CommandSideMove;
		BEGIN
			IF command IS CommandBeginDrag THEN
				WITH command: CommandBeginDrag DO
					FDragging := TRUE;
					FDragHitTest := command.Hit;
					FDragStartPos := command.StartPos
				END
			ELSIF command IS CommandDrag THEN
				WITH command: CommandDrag DO
					IF FDragging THEN
						CASE FDragHitTest.Type OF
							HT.INSIDE:
								cmdMove.DeltaX := command.NewPos.x - FDragStartPos.x;
								cmdMove.DeltaY := command.NewPos.y - FDragStartPos.y;
								FDragStartPos := command.NewPos;
								HandleCommand(cmdMove)
						|	HT.VERTEX:
								cmdVertexMove.Index := FDragHitTest.Index;
								cmdVertexMove.NewPos := command.NewPos;
								HandleCommand(cmdVertexMove)
						|	HT.SIDE:
								cmdSideMove.Index := FDragHitTest.Index;
								cmdSideMove.NewPos := command.NewPos;
								HandleCommand(cmdSideMove)
						ELSE
						END
					END
				END
			ELSIF command IS CommandEndDrag THEN
				FDragging := FALSE
			ELSIF command IS CommandGetCursor THEN
				command(CommandGetCursor).Cursor := CR.DEFAULT
			ELSIF command IS CommandHitTest THEN
				command(CommandHitTest).Hit.Type := HT.OUTSIDE
			ELSIF command IS CommandMove THEN
				WITH command: CommandMove DO
					BeginUpdate;
					FOR i := 0 TO GetBasePointsCount() - 1 DO
						pos := GetBasePoint(i);
						SetBasePoint(i, pos.x + command.DeltaX, pos.y + command.DeltaY)
					END;
					EndUpdate
				END
			ELSIF command IS CommandVertexMove THEN
				WITH command: CommandVertexMove DO
					SetVertex(command.Index, command.NewPos.x, command.NewPos.y)
				END
			END
		END HandleCommand;

		PROCEDURE Change;
		BEGIN
			IF FLockCount = 0 THEN
				onChange.Call(NIL (* par *))
			END
		END Change;

		PROCEDURE AddBasePoint(X, Y: REAL);
		BEGIN
			FBasePoints.Add(X, Y);
			Change;
		END AddBasePoint;

		PROCEDURE InsertBasePoint(Index: LONGINT; X, Y: REAL);
		BEGIN
			FBasePoints.Insert(Index, X, Y);
			Change;
		END InsertBasePoint;

		PROCEDURE DeleteBasePoint(Index: LONGINT);
		BEGIN
			FBasePoints.Remove(Index);
			Change;
		END DeleteBasePoint;

		PROCEDURE ClearBasePoints;
		BEGIN
			FBasePoints.Clear;
			Change;
		END ClearBasePoints;

		PROCEDURE GetBasePointsCount(): LONGINT;
		BEGIN
			RETURN FBasePoints.Count()
		END GetBasePointsCount;

		PROCEDURE GetBasePoint(Index: LONGINT): VCTypes.Point2f;
		BEGIN
			RETURN FBasePoints.Get(Index)
		END GetBasePoint;

		PROCEDURE SetBasePoint(Index: LONGINT; X, Y: REAL);
		VAR
			item: VCTypes.Point2f;
		BEGIN
			item := FBasePoints.Get(Index);
			IF (item.x # X) OR (item.y # Y) THEN
				FBasePoints.Set(Index, X, Y);
				Change
			END
		END SetBasePoint;

		PROCEDURE GetVerticesCount(): LONGINT;
		END GetVerticesCount;

		PROCEDURE GetVertex(Index: LONGINT): VCTypes.Point2f;
		END GetVertex;

		PROCEDURE SetVertex(Index: LONGINT; X, Y: REAL);
		END SetVertex;

		PROCEDURE BeginUpdate;
		BEGIN
			INC(FLockCount)
		END BeginUpdate;

		PROCEDURE EndUpdate;
		BEGIN
			DEC(FLockCount);
			(*FLockCount := MAX(0, FLockCount - 1);*)
			IF FLockCount = 0 THEN
				Change
			END
		END EndUpdate;

		PROCEDURE Draw*(Canvas: VCBase.LogicalCanvas);
		VAR
			i: LONGINT;
			vertex: VCTypes.Point2f;
		BEGIN
			FOR i := 0 TO GetVerticesCount() - 1 DO
				vertex := GetVertex(i);
				Canvas.DrawVertex(vertex.x, vertex.y)
			END
		END Draw;

		(*property OnChange: TNotifyEvent read FOnChange write FOnChange;*)
	END BaseVisualObject;

	VisualObjectGen* = PROCEDURE {DELEGATE} (): BaseVisualObject;

	VisualObjectItem = RECORD(Generics.Item)
		value: BaseVisualObject
	END;

	VisualObjectVector* = OBJECT(Generics.Vector)
	VAR
		array: POINTER TO ARRAY OF VisualObjectItem;

		PROCEDURE &New*;
		VAR
			pCompA, pCompB: POINTER TO VisualObjectItem;
		BEGIN
			NEW(pCompA);
			NEW(pCompB);
			NewVector(SIZEOF(VisualObjectItem), pCompA, pCompB, Compare, {})
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Compare(pA, pB: Generics.PItem): BOOLEAN;
		VAR
			adrLeft, adrRight: ADDRESS;
		BEGIN
			adrLeft := pA^(VisualObjectItem).value;
			adrRight := pB^(VisualObjectItem).value;
			RETURN adrLeft < adrRight
		END Compare;

		PROCEDURE Add*(o: BaseVisualObject): LONGINT;
		VAR
			v: VisualObjectItem;
		BEGIN
			v.value := o;
			RETURN AddInternal(v)
		END Add;

		PROCEDURE IndexOf*(o: BaseVisualObject): LONGINT;
		VAR
			v: VisualObjectItem;
		BEGIN
			v.value := o;
			RETURN IndexOfInternal(v)
		END IndexOf;

		PROCEDURE Get*(pos: LONGINT): BaseVisualObject;
		VAR
			item: VisualObjectItem;
		BEGIN
			GetInternal(pos, item);
			RETURN item.value
		END Get;

	END VisualObjectVector;

	RectVisualObject* = OBJECT(BaseVisualObject)
	VAR
		FConstructing: BOOLEAN;
		FCurrentPoint: LONGINT;
		FText: Strings.String;

		PROCEDURE &Init;
		BEGIN
			Init^;
			AddBasePoint(0, 0);
			AddBasePoint(0, 0);
			FText := NullText
		END Init;

		PROCEDURE SetText*(CONST Value: ARRAY OF CHAR);
		BEGIN
			IF FText^ # Value THEN
				FText := Strings.NewString(Value);
				Change
			END
		END SetText;

		PROCEDURE GetText*(VAR Value: ARRAY OF CHAR);
		BEGIN
			IF FText # NIL THEN
				COPY(FText^, Value)
			ELSE
				COPY("", Value)
			END
		END GetText;

		PROCEDURE HandleCommand(VAR command: Command);
		VAR
			sX1f, sY1f, sX2f, sY2f: REAL;
			sX1, sY1, sX2, sY2: LONGINT;
			Point, fp0, fp1: VCTypes.Point2f;
		BEGIN
			IF command IS CommandConstructPoint THEN
				WITH command: CommandConstructPoint DO
					IF ~FConstructing THEN
						FConstructing := TRUE;
						FCurrentPoint := 0;
					END;
					CASE FCurrentPoint OF
						0:
						BeginUpdate;
						SetBasePoint(0, command.Pos.x, command.Pos.y);
						SetBasePoint(1, command.Pos.x, command.Pos.y);
						EndUpdate;
						command.Result := TRUE
					|	1:
						SetBasePoint(1, command.Pos.x, command.Pos.y);
						FConstructing := FALSE;
						command.Result := FALSE
					ELSE
					END;
					INC(FCurrentPoint)
				END
			ELSIF command IS CommandGetCursor THEN
				WITH command: CommandGetCursor DO
					CASE command.Hit.Type OF
						HT.INSIDE: command.Cursor := CR.SIZEALL
					|	HT.VERTEX:
							IF (command.Hit.Index = 0) OR (command.Hit.Index = 2) THEN
								command.Cursor := CR.DIAG1
							ELSE
								command.Cursor := CR.DIAG2
							END
					|	HT.SIDE:
							IF (command.Hit.Index = 0) OR (command.Hit.Index = 2) THEN
								command.Cursor := CR.HORIZONTAL
							ELSE
								command.Cursor := CR.VERTICAL
							END
					ELSE
						command.Cursor := CR.DEFAULT
					END
				END
			ELSIF command IS CommandHitTest THEN
				WITH command: CommandHitTest DO
					fp0 := GetBasePoint(0);
					fp1 := GetBasePoint(1);
					command.ConvertIntf.LogToScreenPt(fp0.x, fp0.y, sX1f, sY1f);
					command.ConvertIntf.LogToScreenPt(fp1.x, fp1.y, sX2f, sY2f);
					sX1 := round(sX1f); sY1 := round(sY1f);
					sX2 := round(sX2f); sY2 := round(sY2f);
					command.Hit.Type := HT.OUTSIDE;
					IF (ABS(command.Params.Pos.x - sX1) <= command.Params.Tolerance) &
						(ABS(command.Params.Pos.y - sY1) <= command.Params.Tolerance)
					THEN
						command.Hit.Type := HT.VERTEX;
						command.Hit.Index := 0
					ELSIF (ABS(command.Params.Pos.x - sX2) <= command.Params.Tolerance) &
						(ABS(command.Params.Pos.y - sY1) <= command.Params.Tolerance)
					THEN
						command.Hit.Type := HT.VERTEX;
						command.Hit.Index := 1
					ELSIF (ABS(command.Params.Pos.x - sX2) <= command.Params.Tolerance) &
						(ABS(command.Params.Pos.y - sY2) <= command.Params.Tolerance)
					THEN
						command.Hit.Type := HT.VERTEX;
						command.Hit.Index := 2
					ELSIF (ABS(command.Params.Pos.x - sX1) <= command.Params.Tolerance) &
						(ABS(command.Params.Pos.y - sY2) <= command.Params.Tolerance)
					THEN
						command.Hit.Type := HT.VERTEX;
						command.Hit.Index := 3
					ELSIF (ABS(command.Params.Pos.x - sX1) <= command.Params.Tolerance) &
						(command.Params.Pos.y > sY1) & (command.Params.Pos.y < sY2)
					THEN
						command.Hit.Type := HT.SIDE;
						command.Hit.Index := 0
					ELSIF (ABS(command.Params.Pos.y - sY1) <= command.Params.Tolerance) &
						(command.Params.Pos.x > sX1) & (command.Params.Pos.x < sX2)
					THEN
						command.Hit.Type := HT.SIDE;
						command.Hit.Index := 1
					ELSIF (ABS(command.Params.Pos.x - sX2) <= command.Params.Tolerance) &
						(command.Params.Pos.y > sY1) & (command.Params.Pos.y < sY2)
					THEN
						command.Hit.Type := HT.SIDE;
						command.Hit.Index := 2
					ELSIF (ABS(command.Params.Pos.y - sY2) <= command.Params.Tolerance) &
						(command.Params.Pos.x > sX1) & (command.Params.Pos.x < sX2)
					THEN
						command.Hit.Type := HT.SIDE;
						command.Hit.Index := 3
					ELSIF (command.Params.Pos.x > sX1) & (command.Params.Pos.x < sX2) &
						(command.Params.Pos.y > sY1) & (command.Params.Pos.y < sY2)
					THEN
						command.Hit.Type := HT.INSIDE
					END
				END
			ELSIF command IS CommandProcessConstruct THEN
				WITH command: CommandProcessConstruct DO
					IF FConstructing THEN
						CASE FCurrentPoint OF
							0: SetVertex(0, command.Pos.x, command.Pos.y);
						|	1: SetVertex(2, command.Pos.x, command.Pos.y)
						ELSE
						END
					END
				END
			ELSIF command IS CommandSideMove THEN
				WITH command: CommandSideMove DO
					CASE command.Index OF
						0:
								Point := GetVertex(0);
								Point.x := command.NewPos.x;
								SetVertex(0, Point.x, Point.y)
					|	1:
								Point := GetVertex(0);
								Point.y := command.NewPos.y;
								SetVertex(0, Point.x, Point.y)
					|	2:
								Point := GetVertex(2);
								Point.x := command.NewPos.x;
								SetVertex(2, Point.x, Point.y)
					|	3:
								Point := GetVertex(2);
								Point.y := command.NewPos.y;
								SetVertex(2, Point.x, Point.y)
					ELSE
					END
				END
			ELSIF command IS CommandStopConstruct THEN
				command(CommandStopConstruct).Result := TRUE;
				IF FConstructing THEN
					FConstructing := FALSE;
					command(CommandStopConstruct).Result := FALSE
				END
			ELSE
				HandleCommand^(command)
			END
		END HandleCommand;

		PROCEDURE GetVerticesCount(): LONGINT;
		BEGIN
			RETURN 4
		END GetVerticesCount;

		PROCEDURE GetVertex(Index: LONGINT): VCTypes.Point2f;
		VAR
			fp: VCTypes.Point2f;
		BEGIN
			CASE Index OF
				0: RETURN GetBasePoint(0)
			|	1:
				fp.x := GetBasePoint(1).x;
				fp.y := GetBasePoint(0).y;
				RETURN fp
			|	2: RETURN GetBasePoint(1)
			|	3:
				fp.x := GetBasePoint(0).x;
				fp.y := GetBasePoint(1).y;
				RETURN fp
			ELSE
			END
		END GetVertex;

		PROCEDURE SetVertex(Index: LONGINT; X, Y: REAL);
		VAR
			fp0, fp1: VCTypes.Point2f;
		BEGIN
			fp0 := GetBasePoint(0);
			fp1 := GetBasePoint(1);
			CASE Index OF
				0:
					SetBasePoint(0, MIN(X, fp1.x), MIN(Y, fp1.y))
			|	1:
					SetBasePoint(1, MAX(X, fp0.x), fp1.y);
					SetBasePoint(0, fp0.x, MIN(Y, fp1.y))
			|	2:
					SetBasePoint(1, MAX(X, fp0.x), MAX(Y, fp0.y))
			|	3:
					SetBasePoint(0, MIN(X, fp1.x), fp0.y);
					SetBasePoint(1, fp1.x, MAX(Y, fp0.y))
			ELSE
			END
		END SetVertex;

		PROCEDURE IsBadRect(): BOOLEAN;
		VAR
			v00, v0, v1, v2, v3: VCTypes.Point2f;
		BEGIN

			v0 := GetVertex(0); v00 := v0;
			v1 := GetVertex(1);
			v2 := GetVertex(2);
			v3 := GetVertex(3);

			v0.x := v1.x - v0.x;
			v0.y := v1.y - v0.y;

			v1.x := v2.x - v1.x;
			v1.y := v2.y - v1.y;

			v2.x := v3.x - v2.x;
			v2.y := v3.y - v2.y;

			v3.x := v00.x - v3.x;
			v3.y := v00.y - v3.y;

			RETURN (ABS(v0.x * v0.x + v0.y * v0.y) < 0.1) OR
				(ABS(v1.x * v1.x + v1.y * v1.y) < 0.1) OR
				(ABS(v2.x * v2.x + v2.y * v2.y) < 0.1) OR
				(ABS(v3.x * v3.x + v3.y * v3.y) < 0.1)
		END IsBadRect;

		(*property Text: ARRAY OF CHAR read FText write SetText;*)
	END RectVisualObject;

	LineVisualObject = OBJECT(BaseVisualObject)
	VAR
		FConstructing: BOOLEAN;
		FCurrentPoint: LONGINT;

		PROCEDURE HandleCommand(VAR command: Command);
		VAR
			i: LONGINT;
			sX1f, sY1f, sX2f, sY2f: REAL;
			sX1, sY1, sX2, sY2: LONGINT;
			D: REAL;
			vertex1, vertex2: VCTypes.Point2f;
		BEGIN
			IF command IS CommandConstructPoint THEN
				WITH command: CommandConstructPoint DO
					IF ~FConstructing THEN
						FConstructing := TRUE;
						BeginUpdate;
						ClearBasePoints;
						FCurrentPoint := 0;
						AddBasePoint(command.Pos.x, command.Pos.y);
						EndUpdate
					END;
					command.Result := NotNeedToStopConstruct(FCurrentPoint + 1);
					IF ~command.Result THEN
						FConstructing := FALSE;
						RETURN
					END;
					AddBasePoint(command.Pos.x, command.Pos.y);
					INC(FCurrentPoint)
				END
			ELSIF command IS CommandGetCursor THEN
				WITH command: CommandGetCursor DO
					IF command.Hit.Type # HT.OUTSIDE THEN
						command.Cursor := CR.SIZEALL
					ELSE
						command.Cursor := CR.DEFAULT
					END
				END
			ELSIF command IS CommandHitTest THEN
				WITH command: CommandHitTest DO
					command.Hit.Type := HT.OUTSIDE;
					i := GetVerticesCount() - 1;
					WHILE i >= 0 DO
						vertex1 := GetVertex(i);
						command.ConvertIntf.LogToScreenPt(vertex1.x, vertex1.y, sX1f, sY1f);
						sX1 := round(sX1f); sY1 := round(sY1f);
						IF (ABS(command.Params.Pos.x - sX1) <= command.Params.Tolerance) &
							(ABS(command.Params.Pos.y - sY1) <= command.Params.Tolerance)
						THEN
							command.Hit.Type := HT.VERTEX;
							command.Hit.Index := i;
							RETURN
						END;
						DEC(i)
					END;
					i := GetVerticesCount() - 1;
					WHILE i >= 1 DO
						vertex1 := GetVertex(i);
						vertex2 := GetVertex(i - 1);
						command.ConvertIntf.LogToScreenPt(vertex1.x, vertex1.y, sX1f, sY1f);
						command.ConvertIntf.LogToScreenPt(vertex2.x, vertex2.y, sX2f, sY2f);
						sX1 := round(sX1f); sY1 := round(sY1f);
						sX2 := round(sX2f); sY2 := round(sY2f);
						D := LineDistance(command.Params.Pos.x, command.Params.Pos.y,
							sX1, sY1, sX2, sY2);
						IF D <= command.Params.Tolerance THEN
							command.Hit.Type := HT.INSIDE;
							command.Hit.Index := i - 1;
							RETURN
						END;
						DEC(i)
					END
				END
			ELSIF command IS CommandProcessConstruct THEN
				WITH command: CommandProcessConstruct DO
					IF FConstructing THEN
						SetBasePoint(FCurrentPoint, command.Pos.x, command.Pos.y)
					END
				END
			ELSIF command IS CommandStopConstruct THEN
				WITH command: CommandStopConstruct DO
					command.Result := TRUE;
					IF FConstructing THEN
						FConstructing := FALSE;
						DeleteBasePoint(FCurrentPoint);
						IF GetVerticesCount() < 2 THEN
							command.Result := FALSE
						END
					END
				END
			ELSE
				HandleCommand^(command)
			END
		END HandleCommand;

		PROCEDURE GetVerticesCount(): LONGINT;
		BEGIN
			RETURN GetBasePointsCount()
		END GetVerticesCount;

		PROCEDURE GetVertex(Index: LONGINT): VCTypes.Point2f;
		BEGIN
			RETURN GetBasePoint(Index)
		END GetVertex;

		PROCEDURE SetVertex(Index: LONGINT; X, Y: REAL);
		BEGIN
			SetBasePoint(Index, X, Y);
		END SetVertex;

		PROCEDURE NotNeedToStopConstruct(Count: LONGINT): BOOLEAN;
		END NotNeedToStopConstruct;

		PROCEDURE Draw(canvas: VCBase.LogicalCanvas);
		VAR
			i: LONGINT;
			pPts: VCTypes.PPoints2f;
		BEGIN
			NEW(pPts, GetVerticesCount());
			FOR i := 0 TO GetVerticesCount() - 1 DO
				pPts[i] := GetVertex(i)
			END;
			canvas.DrawPolygon(pPts, 0.5, FALSE);
			Draw^(canvas)
		END Draw;

	END LineVisualObject;

	SimpleLineBlock = OBJECT(LineVisualObject)

		PROCEDURE NotNeedToStopConstruct(Count: LONGINT): BOOLEAN;
		BEGIN
			RETURN Count < 2
		END NotNeedToStopConstruct;

	END SimpleLineBlock;

	PolyLineBlock = OBJECT(LineVisualObject)

		PROCEDURE HandleCommand(VAR command: Command);
		BEGIN
			IF command IS CommandVControl THEN
				WITH command: CommandVControl DO
					CASE command.Hit.Type OF
						HT.INSIDE:
							InsertBasePoint(command.Hit.Index + 1, command.Pos.x, command.Pos.y);
					|	HT.VERTEX:
							IF GetVerticesCount() > 2 THEN
								DeleteBasePoint(command.Hit.Index)
							END
					ELSE
					END
				END
			ELSE
				HandleCommand^(command)
			END
		END HandleCommand;

		PROCEDURE NotNeedToStopConstruct(Count: LONGINT): BOOLEAN;
		BEGIN
			RETURN TRUE
		END NotNeedToStopConstruct;

	END PolyLineBlock;

	BeginEndBlock = OBJECT(RectVisualObject)

		PROCEDURE Draw(canvas: VCBase.LogicalCanvas);
		VAR
			fp0, fp1: VCTypes.Point2f;
		BEGIN
			IF IsBadRect() THEN
				Draw^(canvas);
				RETURN
			END;
			fp0 := GetBasePoint(0);
			fp1 := GetBasePoint(1);
			canvas.DrawRoundRect(fp0.x, fp0.y, fp1.x, fp1.y, 0.5);
			canvas.DrawText(fp0.x, fp0.y, fp1.x, fp1.y, 5, FText^);
			Draw^(canvas)
		END Draw;

	END BeginEndBlock;

	InputOutputBlock = OBJECT(RectVisualObject)
	VAR
		pPts: VCTypes.PPoints2f;

		PROCEDURE &Init;
		BEGIN
			Init^;
			NEW(pPts, 4)
		END Init;

		PROCEDURE Draw(canvas: VCBase.LogicalCanvas);
		VAR
			fp0, fp1: VCTypes.Point2f;
		BEGIN
			IF IsBadRect() THEN
				Draw^(canvas);
				RETURN
			END;
			pPts[0] := GetVertex(0);
			pPts[1] := GetVertex(1);
			pPts[2] := GetVertex(2);
			pPts[3] := GetVertex(3);
			pPts[0].x := pPts[0].x + (pPts[1].x - pPts[0].x) / 6;
			pPts[2].x := pPts[2].x - (pPts[2].x - pPts[3].x) / 6;
			canvas.DrawPolygon(pPts, 0.5, TRUE);
			fp0 := GetBasePoint(0);
			fp1 := GetBasePoint(1);
			canvas.DrawText(fp0.x, fp0.y, fp1.x, fp1.y, 5, FText^);
			Draw^(canvas)
		END Draw;

	END InputOutputBlock;

	ActionBlock = OBJECT(RectVisualObject)

		PROCEDURE Draw(canvas: VCBase.LogicalCanvas);
		VAR
			fp0, fp1: VCTypes.Point2f;
		BEGIN
			IF IsBadRect() THEN
				Draw^(canvas);
				RETURN
			END;
			fp0 := GetBasePoint(0);
			fp1 := GetBasePoint(1);

			canvas.DrawRect(fp0.x, fp0.y, fp1.x, fp1.y, 0.5);

			canvas.DrawText(fp0.x, fp0.y, fp1.x, fp1.y, 5, FText^);
			Draw^(canvas)
		END Draw;

	END ActionBlock;

	ConditionBlock = OBJECT(RectVisualObject)
	VAR
		pPts: VCTypes.PPoints2f;

		PROCEDURE &Init;
		BEGIN
			Init^;
			NEW(pPts, 4)
		END Init;

		PROCEDURE Draw(canvas: VCBase.LogicalCanvas);
		VAR
			f0X, f1Y: REAL;
			fp0, fp1: VCTypes.Point2f;
		BEGIN

			IF IsBadRect() THEN
				Draw^(canvas);
				RETURN
			END;

			pPts[0] := GetVertex(0);
			pPts[1] := GetVertex(1);
			pPts[2] := GetVertex(2);
			pPts[3] := GetVertex(3);

			f0X := pPts[0].x;
			f1Y := pPts[1].y;
			pPts[0].x := f0X + (pPts[1].x - f0X) / 2;
			pPts[1].y := f1Y + (pPts[2].y - f1Y) / 2;
			pPts[2].x := f0X + (pPts[1].x - f0X) / 2;
			pPts[3].y := f1Y + (pPts[2].y - f1Y) / 2;

			canvas.DrawPolygon(pPts, 0.5, TRUE);

			fp0 := GetBasePoint(0);
			fp1 := GetBasePoint(1);

			canvas.DrawText(fp0.x, fp0.y, fp1.x, fp1.y, 5, FText^);
			Draw^(canvas)
		END Draw;

	END ConditionBlock;

	SubBlock = OBJECT(RectVisualObject)

		PROCEDURE Draw(canvas: VCBase.LogicalCanvas);
		VAR
			fp0, fp1: VCTypes.Point2f;
		BEGIN
			IF IsBadRect() THEN
				Draw^(canvas);
				RETURN
			END;
			fp0 := GetBasePoint(0);
			fp1 := GetBasePoint(1);
			canvas.DrawRect(fp0.x, fp0.y, fp1.x, fp1.y, 0.5);
			canvas.DrawLine(fp0.x + (fp1.x - fp0.x) / 10, fp0.y,
				fp0.x + (fp1.x - fp0.x) / 10, fp1.y, 0.5);
			canvas.DrawLine(fp1.x - (fp1.x - fp0.x) / 10, fp0.y,
				fp1.x - (fp1.x - fp0.x) / 10, fp1.y, 0.5);
			canvas.DrawText(fp0.x, fp0.y, fp1.x, fp1.y, 5, FText^);
			Draw^(canvas)
		END Draw;

	END SubBlock;

	TextBlock = OBJECT(RectVisualObject)

		PROCEDURE Draw(Canvas: VCBase.LogicalCanvas);
		VAR
			fp0, fp1: VCTypes.Point2f;
		BEGIN
			fp0 := GetBasePoint(0);
			fp1 := GetBasePoint(1);
			Canvas.DrawText(fp0.x, fp0.y, fp1.x, fp1.y, 5, FText^);
			Draw^(Canvas)
		END Draw;

	END TextBlock;

VAR
	BlockGenerators-: ARRAY 9 OF VisualObjectGen;
	NullText: Strings.String;

	PROCEDURE SimpleLineBlockGen*(): BaseVisualObject;
	VAR o: SimpleLineBlock;
	BEGIN NEW(o); RETURN o
	END SimpleLineBlockGen;

	PROCEDURE PolyLineBlockGen*(): BaseVisualObject;
	VAR o: PolyLineBlock;
	BEGIN NEW(o); RETURN o
	END PolyLineBlockGen;

	PROCEDURE BeginEndBlockGen*(): BaseVisualObject;
	VAR o: BeginEndBlock;
	BEGIN NEW(o); RETURN o
	END BeginEndBlockGen;

	PROCEDURE InputOutputBlockGen*(): BaseVisualObject;
	VAR o: InputOutputBlock;
	BEGIN NEW(o); RETURN o
	END InputOutputBlockGen;

	PROCEDURE ActionBlockGen*(): BaseVisualObject;
	VAR o: ActionBlock;
	BEGIN NEW(o); RETURN o
	END ActionBlockGen;

	PROCEDURE ConditionBlockGen*(): BaseVisualObject;
	VAR o: ConditionBlock;
	BEGIN NEW(o); RETURN o
	END ConditionBlockGen;

	PROCEDURE SubBlockGen*(): BaseVisualObject;
	VAR o: SubBlock;
	BEGIN NEW(o); RETURN o
	END SubBlockGen;

	PROCEDURE TextBlockGen*(): BaseVisualObject;
	VAR o: TextBlock;
	BEGIN NEW(o); RETURN o
	END TextBlockGen;

	PROCEDURE LineDistance(X, Y, X1, Y1, X2, Y2: LONGINT): REAL;
	VAR
		A1, B1, C1, A2, B2, C2, DD: LONGINT;
		D, Px, Py: REAL;

		PROCEDURE Xchg(VAR A, B: LONGINT);
		VAR
			C: LONGINT;
		BEGIN
			C := A;
			A := B;
			B := C
		END Xchg;

	BEGIN
		IF (X2 = X1) & (Y2 = Y1) THEN
			RETURN Math.sqrt((X - X1)*(X - X1) + (Y - Y1)*(Y - Y1))
		ELSE
			A1 := Y2 - Y1;
			B1 := X1 - X2;
			C1 := Y1*(X2 - X1) - X1*(Y2 - Y1);
			D := ABS(A1*X + B1*Y + C1)/Math.sqrt(A1*A1 + B1*B1);
			IF X1 > X2 THEN Xchg(X1, X2) END;
			IF Y2 > Y1 THEN Xchg(Y1, Y2) END;
			A2 := -B1;
			B2 := A1;
			C2 := B1*X - A1*Y;
			DD := A1*B2 - B1*A2;
			Px := (-C1*B2 + B1*C2)/DD;
			Py := (-A1*C2 + C1*A2)/DD;
			IF (Px >= X1) & (Px <= X2) & (Py >= Y2) & (Py <= Y1) THEN
				RETURN D
			ELSE
				RETURN MIN(Math.sqrt((X - X1)*(X - X1) + (Y - Y1)*(Y - Y1)),
					Math.sqrt((X - X2)*(X - X2) + (Y - Y2)*(Y - Y2)))
			END
		END
	END LineDistance;

	PROCEDURE round(f: REAL): LONGINT;
	BEGIN
		RETURN ENTIER(f + 0.5)
	END round;

	PROCEDURE Init;
	BEGIN
		BlockGenerators[0] := NIL;
		BlockGenerators[1] := SimpleLineBlockGen;
		BlockGenerators[2] := PolyLineBlockGen;
		BlockGenerators[3] := BeginEndBlockGen;
		BlockGenerators[4] := InputOutputBlockGen;
		BlockGenerators[5] := ActionBlockGen;
		BlockGenerators[6] := ConditionBlockGen;
		BlockGenerators[7] := SubBlockGen;
		BlockGenerators[8] := TextBlockGen;

		NullText := Strings.NewString("Text")

	END Init;

BEGIN
	Init
END VCObjects.
