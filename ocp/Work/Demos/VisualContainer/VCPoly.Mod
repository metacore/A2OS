MODULE VCPoly;

(** AUTHOR "Yaroslav Romanchenko (SAGE) http://sage.com.ua/";
	PURPOSE "Visual Objects Container. Polyline converter"; *)

IMPORT
	Math, VCTypes;

TYPE
	PolylineConverter* = OBJECT
	TYPE
		TrianglesUpdateHandler = PROCEDURE {DELEGATE};
	VAR
		(* Reusable buffers of polygons' points.
			Two buffers are maintained, for left and right parts.
			Left buffer also finally accumulates total polygon *)
		pPolyLeft, pPolyRight: VCTypes.PPoints2f;
		iLeft, iRight: LONGINT;

		(* Reusable buffer for triangles *)
		pTriangles2f: VCTypes.PTriangles2f;
		iTri, iLeftPrev, iRightPrev: LONGINT;

		(* Line's perpendicular vector *)
		PROCEDURE LinePerp(CONST fp1, fp2: VCTypes.Point2f; VAR vPerp: VCTypes.Point2f);
		BEGIN
			vPerp.x := -(fp2.y - fp1.y);
			vPerp.y := fp2.x - fp1.x;
			normalize(vPerp)
		END LinePerp;

		(* TrianglesUpdateHandler used when building a thriangles.
			Special cases should be handled in special way for them *)
		PROCEDURE TrianglesUpdate;
		VAR
			nL, nR, i: LONGINT;
		BEGIN
			nL := iLeft - iLeftPrev;
			nR := iRight - iRightPrev;
			(* put 2 triangles for every line segment *)
			i := 0;
			WHILE i < MIN(nL, nR) - 1 DO
				pTriangles2f[iTri][0] := pPolyRight[iRightPrev];
				pTriangles2f[iTri][1] := pPolyLeft[iLeftPrev];
				pTriangles2f[iTri][2] := pPolyLeft[iLeftPrev + 1];
				INC(iTri);
				pTriangles2f[iTri][0] := pPolyRight[iRightPrev];
				pTriangles2f[iTri][1] := pPolyLeft[iLeftPrev + 1];
				pTriangles2f[iTri][2] := pPolyRight[iRightPrev + 1];
				INC(iTri);
				INC(iLeftPrev);
				INC(iRightPrev);
				INC(i)
			END;
			(* put special triangle on joint *)
			IF nL > nR THEN
				pTriangles2f[iTri][0] := pPolyLeft[iLeftPrev];
				pTriangles2f[iTri][1] := pPolyLeft[iLeftPrev + 1];
				pTriangles2f[iTri][2] := pPolyRight[iRightPrev];
				INC(iTri);
				INC(iLeftPrev)
			ELSIF nL < nR THEN
				pTriangles2f[iTri][0] := pPolyRight[iRightPrev];
				pTriangles2f[iTri][1] := pPolyLeft[iLeftPrev];
				pTriangles2f[iTri][2] := pPolyRight[iRightPrev + 1];
				INC(iTri);
				INC(iRightPrev)
			END
		END TrianglesUpdate;

		PROCEDURE ToPolygonInternal(pPts: VCTypes.PPoints2f; fLineWidth: REAL; bClosed: BOOLEAN; hTrianglesUpdate: TrianglesUpdateHandler): BOOLEAN;

			(* Put one point to left list and 2 points to right list *)
			PROCEDURE PutSpecial(pL, pR: VCTypes.PPoints2f; VAR iL, iR: LONGINT; bReverseDir: BOOLEAN);
			VAR
				vPerp: VCTypes.Point2f;
				fCosAlpha: REAL;
			BEGIN

				pL[iL].x := pPts[i].x + vNode.x;
				pL[iL].y := pPts[i].y + vNode.y;
				INC(iL);

				(* Make perpendicular to vNode and find cos alpha to one of the lines perpendicular *)
				vPerp.x := -vNode.y;
				vPerp.y := vNode.x;
				normalize(vPerp);
				fCosAlpha := cosAlpha(vLine1Perp, vPerp);

				vPerp.x := vPerp.x * fW / fCosAlpha;
				vPerp.y := vPerp.y * fW / fCosAlpha;

				IF bReverseDir THEN
					pR[iR].x := pPts[i].x - vPerp.x;
					pR[iR].y := pPts[i].y - vPerp.y;
					INC(iR);
					pR[iR].x := pPts[i].x + vPerp.x;
					pR[iR].y := pPts[i].y + vPerp.y;
					INC(iR)
				ELSE
					pR[iR].x := pPts[i].x + vPerp.x;
					pR[iR].y := pPts[i].y + vPerp.y;
					INC(iR);
					pR[iR].x := pPts[i].x - vPerp.x;
					pR[iR].y := pPts[i].y - vPerp.y;
					INC(iR)
				END;

				IF hTrianglesUpdate # NIL THEN
					hTrianglesUpdate
				END

			END PutSpecial;

		VAR
			i: LONGINT;
			fW, fCosHalfAlpha, fCosAlphaToCorner: REAL;
			vLine1Perp, vLine2Perp, vNode, vLine, vJoint: VCTypes.Point2f;
			bSpecialCase, bSimpleJoint: BOOLEAN;

		BEGIN

			IF (bClosed & (LEN(pPts^) < 3)) OR (~bClosed & (LEN(pPts^) < 2)) THEN
				RETURN FALSE
			END;

			fW := 0.5 * fLineWidth;

			(* To estimate highest possible lengths' try to figure
				out hardest case, a star, for example, 5-vertex star
				gives 10 resulting points at the left, 6 at the right
				and 16 in total, so, 2 is highest rate for left/right
				buffer and because left buffer accumulates final result
				rate 4 for it should be used
			*)
			IF (pPolyLeft = NIL) OR (LEN(pPolyLeft^) < LEN(pPts^) * 4) THEN
				NEW(pPolyLeft, LEN(pPts^) * 4)
			END;
			IF (pPolyRight = NIL) OR (LEN(pPolyRight^) < LEN(pPts^) * 2) THEN
				NEW(pPolyRight, LEN(pPts^) * 2)
			END;

			iLeft := 0;
			iRight := 0;
			bSimpleJoint := FALSE;

			FOR i := 0 TO LEN(pPts^) - 1 DO
				bSpecialCase := FALSE;
				IF ~bClosed & (i = LEN(pPts^) - 1) THEN
					LinePerp(pPts[LEN(pPts^) - 1], pPts[LEN(pPts^) - 2], vNode)
				ELSIF ~bClosed & (i = 0) THEN
					LinePerp(pPts[1], pPts[0], vNode)
				ELSE
					IF bClosed & (i = 0) THEN
						LinePerp(pPts[i], pPts[LEN(pPts^) - 1], vLine1Perp);
						LinePerp(pPts[i + 1], pPts[i], vLine2Perp);
					ELSIF bClosed & (i = LEN(pPts^) - 1) THEN
						LinePerp(pPts[i], pPts[i - 1], vLine1Perp);
						LinePerp(pPts[0], pPts[i], vLine2Perp)
					ELSE
						LinePerp(pPts[i], pPts[i - 1], vLine1Perp);
						LinePerp(pPts[i + 1], pPts[i], vLine2Perp)
					END;
					(* Average vector *)
					vNode.x := vLine1Perp.x + vLine2Perp.x;
					vNode.y := vLine1Perp.y + vLine2Perp.y;
					normalize(vNode);
					fCosHalfAlpha := cosAlpha(vLine1Perp, vNode);
					(* Because we measure angle between perpendiculars
						the logic of finding a special case is inverted *)
					IF fCosHalfAlpha >= 0.5 THEN
						(* If fCosHalfAlpha >= 0.5 than Half Alpha is less than or equal 60 degrees *)
						bSimpleJoint := bClosed;
						vNode.x := vNode.x / fCosHalfAlpha;
						vNode.y := vNode.y / fCosHalfAlpha
					ELSE (* Half Alpha is higher than 60 degrees *)
						bSpecialCase := TRUE;
						vNode.x := vNode.x * fW / fCosHalfAlpha;
						vNode.y := vNode.y * fW / fCosHalfAlpha;
						IF bClosed THEN
							vJoint := vNode
						END;
						(* Is vNode inside corner or outside. Let's find its cos alpha to one of corner's lines *)
						IF bClosed & (i = 0) THEN
							vLine.x := pPts[LEN(pPts^) - 1].x - pPts[i].x;
							vLine.y := pPts[LEN(pPts^) - 1].y - pPts[i].y
						ELSE
							vLine.x := pPts[i - 1].x - pPts[i].x;
							vLine.y := pPts[i - 1].y - pPts[i].y
						END;
						fCosAlphaToCorner := cosAlpha(vLine, vNode);
						IF fCosAlphaToCorner < 0 THEN (* Outside. Negate vNode *)
							vNode.x := -vNode.x;
							vNode.y := -vNode.y;
							(* Put 2 points to left list and one point to right list *)
							PutSpecial(pPolyRight, pPolyLeft, iRight, iLeft, FALSE)
						ELSE (* Put one point to left list and 2 points to right list *)
							PutSpecial(pPolyLeft, pPolyRight, iLeft, iRight, TRUE)
						END
					END
				END;
				IF ~bSpecialCase THEN
					vNode.x := vNode.x * fW;
					vNode.y := vNode.y * fW;
					pPolyLeft[iLeft].x := pPts[i].x + vNode.x;
					pPolyLeft[iLeft].y := pPts[i].y + vNode.y;
					INC(iLeft);
					pPolyRight[iRight].x := pPts[i].x - vNode.x;
					pPolyRight[iRight].y := pPts[i].y - vNode.y;
					INC(iRight)
				END
			END;
			IF bClosed THEN
				IF bSimpleJoint THEN
					pPolyLeft[iLeft] := pPolyLeft[0];
					INC(iLeft);
					pPolyRight[iRight] := pPolyRight[0];
					INC(iRight)
				ELSE
					pPolyLeft[iLeft] := pPolyLeft[0];
					INC(iLeft);
					pPolyRight[iRight].x := pPts[0].x - vJoint.x;
					pPolyRight[iRight].y := pPts[0].y - vJoint.y;
					INC(iRight)
				END
			END;

			(* called for finishing triangles *)
			IF hTrianglesUpdate # NIL THEN
				hTrianglesUpdate
			END;

			RETURN TRUE

		END ToPolygonInternal;

		PROCEDURE ToPolygonF*(pPtsIn: VCTypes.PPoints2f; VAR pPtsOut: VCTypes.PPoints2f; VAR nPtsOut: LONGINT; fLineWidth: REAL; bClosed: BOOLEAN): BOOLEAN;
		VAR
			i: LONGINT;
		BEGIN
			IF ToPolygonInternal(pPtsIn, fLineWidth, bClosed, NIL) THEN
				(* Sum up result *)
				i := iRight - 1;
				WHILE i >= 0 DO
					pPolyLeft[iLeft] := pPolyRight[i];
					INC(iLeft);
					DEC(i)
				END;
				pPtsOut := pPolyLeft;
				nPtsOut := iLeft;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END ToPolygonF;

		PROCEDURE ToPolygonI*(pPtsIn: VCTypes.PPoints2f; VAR pPtsOut: VCTypes.PPoints2i; fLineWidth: REAL; bClosed: BOOLEAN): BOOLEAN;
		VAR
			i: LONGINT;
		BEGIN
			IF ToPolygonInternal(pPtsIn, fLineWidth, bClosed, NIL) THEN
				(* Sum up result *)
				i := iRight - 1;
				WHILE i >= 0 DO
					pPolyLeft[iLeft] := pPolyRight[i];
					INC(iLeft);
					DEC(i)
				END;
				NEW(pPtsOut, iLeft);
				FOR i := 0 TO iLeft - 1 DO
					pPtsOut[i].x := ENTIER(pPolyLeft[i].x + 0.5);
					pPtsOut[i].y := ENTIER(pPolyLeft[i].y + 0.5)
				END;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END ToPolygonI;

		PROCEDURE ToTrianglesF*(pPtsIn: VCTypes.PPoints2f; VAR pTriOut: VCTypes.PTriangles2f; VAR nTriOut: LONGINT; fLineWidth: REAL; bClosed: BOOLEAN): BOOLEAN;
		BEGIN
			iTri := 0;
			iLeftPrev := 0;
			iRightPrev := 0;
			IF (pTriangles2f = NIL) OR (LEN(pTriangles2f^) < LEN(pPtsIn^) * 4) THEN
				NEW(pTriangles2f, LEN(pPtsIn^) * 4)
			END;
			IF ToPolygonInternal(pPtsIn, fLineWidth, bClosed, TrianglesUpdate) THEN
				pTriOut := pTriangles2f;
				nTriOut := iTri;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END ToTrianglesF;

	END PolylineConverter;

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

	(* cos(alpha) between vectors *)
	PROCEDURE cosAlpha(CONST v1, v2: VCTypes.Point2f): REAL;
	VAR
		fDot, fModules: REAL;
	BEGIN
		(* dot product *)
		fDot := v1.x * v2.x + v1.y * v2.y;
		(* multiplication of vectors' modules *)
		fModules := Math.sqrt(v1.x * v1.x + v1.y * v1.y) *
			Math.sqrt(v2.x * v2.x + v2.y * v2.y);
		RETURN fDot / fModules
	END cosAlpha;

END VCPoly.
