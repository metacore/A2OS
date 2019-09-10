MODULE antsEdges IN Oberon; 	(** fof  **)
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




IMPORT  antsArrayObjects, antsCommands, vyBase, aM := antsMessages;

PROCEDURE MakeEdges*;
	VAR l: antsCommands.tScanList;   beta: FLOAT64;    obj, objh, objv: vyBase.Object;
	A, hor, ver: antsArrayObjects.tINTEGERObject;  x, y: SIGNED32;
	pyx, pyxm, pymx : SIGNED16;
BEGIN
	l := antsCommands.ScanFromPar("from=OBJ ver=OBJ hor=OBJ threshold=FLOAT32 # make edge Arrays from Array ");
	IF antsCommands.ExpectObjectFromKeyword(l, "from", obj) &
		antsCommands.ExpectObjectFromKeyword(l, "ver", objh) &
		antsCommands.ExpectObjectFromKeyword(l, "hor", objv) &
		antsCommands.ExpectRealFromKeyword(l, "threshold", beta) THEN
		A := obj(antsArrayObjects.tINTEGERObject);
		hor := objh(antsArrayObjects.tINTEGERObject);
		ver := objv(antsArrayObjects.tINTEGERObject);
		FOR y := 0 TO A.h - 1 DO
			FOR x := 0 TO A.w - 1 DO
				pyx := A.A[y, x];  pyxm := A.A[y, (x - 1) MOD A.w];  pymx := A.A[(y - 1) MOD A.h, x];
				IF (pyx - pyxm) * (pyx - pyxm) > beta THEN hor.A[y, x] := 1 ELSE hor.A[y, x] := 0 END;
				IF (pyx - pymx) * (pyx - pymx) > beta THEN ver.A[y, x] := 1 ELSE ver.A[y, x] := 0 END
			END
		END;
		antsArrayObjects.Refresh(hor);  antsArrayObjects.Refresh(ver)
	END
END MakeEdges;


PROCEDURE MakeDiff*;
	VAR l: antsCommands.tScanList;   obj, objh, objv: vyBase.Object; 	A, hor, ver: antsArrayObjects.tINTEGERObject;  x, y: SIGNED32;

BEGIN
	l := antsCommands.ScanFromPar("from=OBJ ver=OBJ hor=OBJ  # make ABS(diff) Arrays from Array" );
	IF
		antsCommands.ExpectObjectFromKeyword(l, "from", obj) &
		antsCommands.ExpectObjectFromKeyword(l, "ver", objh) &
		antsCommands.ExpectObjectFromKeyword(l, "hor", objv) THEN
		A := obj(antsArrayObjects.tINTEGERObject);
		hor := objh(antsArrayObjects.tINTEGERObject);
		ver := objv(antsArrayObjects.tINTEGERObject);
		FOR y := 0 TO A.h - 1 DO
			FOR x := 0 TO A.w - 1 DO
				hor.A[y, x] :=  (ABS(A.A[y, x] - A.A[y, (x - 1) MOD A.w]));
				ver.A[y, x] := (ABS(A.A[y, x] - A.A[(y - 1) MOD A.h, x]))
			END
		END;
		antsArrayObjects.Refresh(hor);  antsArrayObjects.Refresh(ver)
	END
END MakeDiff;

BEGIN aM.launch;
END antsEdges.

fofAutomatic.Do
antsArrayObjects.Copy > name Array > to  veredges ~
antsArrayObjects.Copy > name Array > to  horedges ~
antsDiscreteFields.ArrayToPict > name veredges > depth 2 ~
antsDiscreteFields.ArrayToPict > name horedges > depth 2 ~
antsViews.Show > name veredges > ver xx ~
antsViews.Show > name horedges > hor xx ~
antsEdges.MakeEdges > from Array > ver veredges > hor horedges > threshold 0.8 ~ # sqrt(gamma) / lambda
~
fofAutomatic.Do
antsArrayObjects.Copy > name Array > to  veredges ~
antsArrayObjects.Copy > name Array > to  horedges ~
antsViews.Show > name veredges > ver xx ~
antsViews.Show > name horedges > hor xx ~
antsEdges.MakeDiff > from Array > ver veredges > hor horedges ~


ants3D.MakeLineFromArray > from Array > name line > x 10 > w 10 ~

ants3D.MakeMatrixFromLayer > name matrix2 ~
ants3D.MakeMatrixFromLayer > name matrix1 ~
Voyager.Show matrix1 as Surface ~ Voyager.Show matrix2 as Surface ~