MODULE VCBase;

(** AUTHOR "Yaroslav Romanchenko (SAGE) http://sage.com.ua/";
	PURPOSE "Visual Objects Container types"; *)

IMPORT
	Math, WMComponents, WMRectangles, WMGraphics,
	Generics, VCTypes, VCPoly

	(*, FloatAA*)
	
	;

TYPE
	Point2fItem* = RECORD(Generics.Item)
		value*: VCTypes.Point2f
	END;

	Point2fVector* = OBJECT(Generics.Vector)
	VAR
		array: POINTER TO ARRAY OF Point2fItem;

		PROCEDURE &New*;
		BEGIN
			NewVector(SIZEOF(Point2fItem), NIL, NIL, NIL, {})
		END New;

		PROCEDURE ArrayConstruct(iArraySize: LONGINT; VAR pArray: ANY; VAR addrArray: ADDRESS);
		BEGIN
			NEW(array, iArraySize); pArray := array; addrArray := ADDRESSOF(array^[0])
		END ArrayConstruct;

		PROCEDURE Add*(x, y: REAL);
		VAR
			item: Point2fItem;
			posDummy: LONGINT;
		BEGIN
			item.value.x := x;
			item.value.y := y;
			posDummy := AddInternal(item)
		END Add;

		PROCEDURE Insert*(pos: LONGINT; X, Y: REAL);
		VAR
			item: Point2fItem;
		BEGIN
			item.value.x := X;
			item.value.y := Y;
			InsertInternal(pos, item)
		END Insert;

		PROCEDURE Set*(pos: LONGINT; X, Y: REAL);
		VAR
			item: Point2fItem;
		BEGIN
			item.value.x := X;
			item.value.y := Y;
			SetInternal(pos, item)
		END Set;

		PROCEDURE Get*(pos: LONGINT): VCTypes.Point2f;
		VAR
			item: Point2fItem;
		BEGIN
			GetInternal(pos, item);
			RETURN item.value
		END Get;

	END Point2fVector;

	VisualContainerBase* = OBJECT(WMComponents.VisualComponent)

		PROCEDURE LogToScreen*(Value: REAL): REAL;
		END LogToScreen;

		PROCEDURE ScreenToLog*(Value: LONGINT): REAL;
		END ScreenToLog;

		PROCEDURE LogToScreenPt*(lX, lY: REAL; VAR sX, sY: REAL);
		END LogToScreenPt;

		PROCEDURE ScreenToLogPt*(sX, sY: LONGINT; VAR lX, lY: REAL);
		END ScreenToLogPt;

	END VisualContainerBase;

	LogicalCanvas* = OBJECT
	VAR
		FCanvas: WMGraphics.Canvas;
		FConvertIntf: VisualContainerBase;

		color: LONGINT;
		mode: LONGINT;

		polyConverter: VCPoly.PolylineConverter;

		PROCEDURE &New*(Canvas: WMGraphics.Canvas; ConvertIntf: VisualContainerBase);
		BEGIN
			FCanvas := Canvas;
			FConvertIntf := ConvertIntf;
			mode := WMGraphics.ModeCopy;
			NEW(polyConverter)
		END New;

		PROCEDURE SetColor*(cl: LONGINT);
		BEGIN
			color := cl
		END SetColor;

		PROCEDURE DrawVertex*(X, Y: REAL);
		VAR
			fp1: VCTypes.Point2f;
			p1, p2, p3, p4: VCTypes.Point2i;
		BEGIN
			FConvertIntf.LogToScreenPt(X, Y, fp1.x, fp1.y);
			p1.x := round(fp1.x) - 3;
			p1.y := round(fp1.y) - 3;
			p2.x := p1.x;
			p2.y := round(fp1.y) + 3;
			p3.x := round(fp1.x) + 3;
			p3.y := p2.y;
			p4.x := p3.x;
			p4.y := p1.y;
			FCanvas.Fill(WMRectangles.MakeRect(p1.x - 1, p1.y - 1, p3.x + 1, p3.y + 1), WMGraphics.Black, mode);
			FCanvas.Fill(WMRectangles.MakeRect(p1.x, p1.y, p3.x, p3.y), WMGraphics.White, mode);
			(*FCanvas.PolyLine([p1, p2, p3, p4], 4, TRUE, color, mode);*)
		END DrawVertex;

		(* Line's perpendicular vector *)
		PROCEDURE LinePerp(CONST fp1, fp2: VCTypes.Point2f; VAR vPerp: VCTypes.Point2f);
		BEGIN
			vPerp.x := -(fp2.y - fp1.y);
			vPerp.y := fp2.x - fp1.x;
			normalize(vPerp)
		END LinePerp;

		PROCEDURE DrawLine*(X1, Y1, X2, Y2, LineWidth: REAL);
		VAR
			fp1, fp2: VCTypes.Point2f;
			vLinePerp: VCTypes.Point2f;
			fW: REAL;
			p1, p2, p3, p4: VCTypes.Point2i;
		BEGIN
			FConvertIntf.LogToScreenPt(X1, Y1, fp1.x, fp1.y);
			FConvertIntf.LogToScreenPt(X2, Y2, fp2.x, fp2.y);

(*			fW := FConvertIntf.LogToScreen(LineWidth);
			FCanvas.SetLineWidth(ENTIER(fW + 0.5));
			FCanvas.Line(ENTIER(fp1.x + 0.5), ENTIER(fp1.y + 0.5),
				ENTIER(fp2.x + 0.5), ENTIER(fp2.y + 0.5), color, mode);  *)

			(* Half LineWidth *)
			fW := 0.5 * FConvertIntf.LogToScreen(LineWidth);

			(* Represent line as polygon bar *)

			LinePerp(fp1, fp2, vLinePerp);

			(* Multiply by half LineWidth *)
			vLinePerp.x := fW * vLinePerp.x;
			vLinePerp.y := fW * vLinePerp.y;
			(* Add *)
			p1.x := round(fp1.x + vLinePerp.x);
			p1.y := round(fp1.y + vLinePerp.y);
			p2.x := round(fp2.x + vLinePerp.x);
			p2.y := round(fp2.y + vLinePerp.y);
			(* negate vector *)
			vLinePerp.x := -vLinePerp.x;
			vLinePerp.y := -vLinePerp.y;
			(* Add *)
			p3.x := round(fp1.x + vLinePerp.x);
			p3.y := round(fp1.y + vLinePerp.y);
			p4.x := round(fp2.x + vLinePerp.x);
			p4.y := round(fp2.y + vLinePerp.y);

			FCanvas.FillPolygonFlat([p1, p2, p4, p3], 4, color, mode)

		END DrawLine;

		PROCEDURE DrawRect*(X1, Y1, X2, Y2, LineWidth: REAL);
		VAR
			fp1, fp2: VCTypes.Point2f;
			fW: REAL;
			poly: ARRAY 10 OF VCTypes.Point2i;
		BEGIN
			FConvertIntf.LogToScreenPt(X1, Y1, fp1.x, fp1.y);
			FConvertIntf.LogToScreenPt(X2, Y2, fp2.x, fp2.y);
			fW := 0.5 * FConvertIntf.LogToScreen(LineWidth);

			(*
			 Represent rectangle as following polygon strip:

				 0_________
				  \        |9
				6|\\1___2  |
				 | \    |  |
				 |  |___|3 |
				7|_________|8

			*)
			poly[0].x := round(fp1.x - fW); poly[0].y := round(fp1.y - fW);
			poly[1].x := round(fp1.x + fW); poly[1].y := round(fp1.y + fW);
			poly[2].x := round(fp2.x - fW); poly[2].y := poly[1].y;
			poly[3].x := poly[2].x; poly[3].y := round(fp2.y - fW);
			poly[4].x := poly[1].x; poly[4].y := poly[3].y;
			poly[5] := poly[1];
			poly[6] := poly[0];
			poly[7].x := poly[0].x; poly[7].y := round(fp2.y + fW);
			poly[8].x := round(fp2.x + fW); poly[8].y := poly[7].y;
			poly[9].x := poly[8].x; poly[9].y := poly[0].y;

			FCanvas.FillPolygonFlat(poly, LEN(poly), color, mode)
		END DrawRect;

		PROCEDURE DrawRoundRect*(X1, Y1, X2, Y2, LineWidth: REAL);
		(*VAR
			sX1, sY1, sX2, sY2: LONGINT;*)
		BEGIN
			(*
			FConvertIntf.LogToScreenPt(X1, Y1, sX1, sY1);
			FConvertIntf.LogToScreenPt(X2, Y2, sX2, sY2);
			*)
			(*
			FCanvas.Pen.Width := FConvertIntf.LogToScreen(LineWidth);
			FCanvas.Brush.Style := bsSolid;
			FCanvas.RoundRect(sX1, sY1, sX2, sY2, (sX2 - sX1) DIV 6, (sY2 - sY1) DIV 2);
			*)
		END DrawRoundRect;

		PROCEDURE DrawText*(X1, Y1, X2, Y2, TextHeight: REAL; Text: ARRAY OF CHAR);
		VAR
			fp1, fp2: VCTypes.Point2f;
		BEGIN
			FConvertIntf.LogToScreenPt(X1, Y1, fp1.x, fp1.y);
			FConvertIntf.LogToScreenPt(X2, Y2, fp2.x, fp2.y);
			WMGraphics.DrawStringInRect(FCanvas,
				WMRectangles.MakeRect(round(fp1.x), round(fp1.y), round(fp2.x), round(fp2.y)),
				FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, Text)
		END DrawText;

		PROCEDURE DrawPolygon*(pPts: VCTypes.PPoints2f; fLineWidth: REAL; bClosed: BOOLEAN);
		VAR
			i, j, n: LONGINT;
			pTriangles2f: VCTypes.PTriangles2f;
			tri: ARRAY 3 OF VCTypes.Point2i;
		BEGIN

			FOR i := 0 TO LEN(pPts^) - 1 DO
				FConvertIntf.LogToScreenPt(pPts[i].x, pPts[i].y, pPts[i].x, pPts[i].y)
			END;

			(*IF polyConverter.ToPolygonI(pPts, pPtsOut, FConvertIntf.LogToScreen(fLineWidth), bClosed) THEN
				FCanvas.FillPolygonFlat(pPtsOut^, LEN(pPtsOut^), color, mode)
			END*)
			IF polyConverter.ToTrianglesF(pPts, pTriangles2f, n, FConvertIntf.LogToScreen(fLineWidth), bClosed) THEN
				FOR i := 0 TO n - 1 DO
					(*FloatAA.LineDDAFull(FCanvas(WMGraphics.BufferCanvas).img,
						pTriangles2f[i][0].x, pTriangles2f[i][0].y,
						pTriangles2f[i][1].x, pTriangles2f[i][1].y, color);
					FloatAA.LineDDAFull(FCanvas(WMGraphics.BufferCanvas).img,
						pTriangles2f[i][1].x, pTriangles2f[i][1].y,
						pTriangles2f[i][2].x, pTriangles2f[i][2].y, color);
					FloatAA.LineDDAFull(FCanvas(WMGraphics.BufferCanvas).img,
						pTriangles2f[i][2].x, pTriangles2f[i][2].y,
						pTriangles2f[i][0].x, pTriangles2f[i][0].y, color);*)
					FOR j := 0 TO 2 DO
						tri[j].x := ENTIER(pTriangles2f[i][j].x + 0.5);
						tri[j].y := ENTIER(pTriangles2f[i][j].y + 0.5)
					END;
					(*FCanvas.PolyLine(tri, 3, TRUE, color, mode)*)
					FCanvas.FillPolygonFlat(tri, 3, color, mode)
				END;
			END

		END DrawPolygon;

	END LogicalCanvas;

	PROCEDURE round(f: REAL): LONGINT;
	BEGIN
		RETURN ENTIER(f + 0.5)
	END round;

	PROCEDURE normalize(VAR v: VCTypes.Point2f);
	VAR
		fLen2, fInvSqrt: REAL;
	BEGIN
		fLen2 := v.x * v.x + v.y * v.y;
		IF fLen2 > 0 THEN
			fInvSqrt := 1 / Math.sqrt(fLen2);
			v.x := v.x * fInvSqrt;
			v.y := v.y * fInvSqrt
		END
	END normalize;

BEGIN

END VCBase.
