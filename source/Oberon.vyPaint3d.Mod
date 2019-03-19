MODULE vyPaint3d IN Oberon; 		(*vs 0.0a1 md   08.08.95 *)
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


(*		(c) Project Voyager, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
*)

(*= basic 3d graphic routines
This module 3d coordinate system defined in vyPHIGS3D offers the standard 3d display routines.
All display routines just convert the 3d coordinates and uses then the appropriate vyHostDisplay routines.*)

(*	history:
8.8.95 md 0.0a1	alpha version
8.6.95 md 0.0d2	cleaned
26.1.95 md 0.0d1	cleaned
28.11.94 md 0.0d0	created *)

(*!		up to now there are not all basic diplay routines realized (see vyHostDisplay and vyHostDisplay2d)
e.g. PaintRect/InvertString/...*)

IMPORT	vyBase, vyGraphBase, vyHostDisplay := vyGraphBase, vyPHIGS3D;

CONST
	idversion* = 	"vyPaint3d v0r0a2";
TYPE Real = vyBase.Real;
	Coordinate = vyGraphBase.Coordinate;
VAR
	pen : ARRAY 3 OF Real;

PROCEDURE SetCoordinate* (c: vyPHIGS3D.tCoordinate3d);
	(*= sets the coordinate system, the following actions refer to *)
BEGIN	vyPHIGS3D.SetCoordinate (c)
END SetCoordinate;

PROCEDURE DisplayPointToPoint* (x, y: INTEGER;  err: INTEGER;  VAR x3d, y3d, z3d: Real);
BEGIN vyPHIGS3D.DisplayPointToPoint (x, y, err, x3d, y3d, z3d) END DisplayPointToPoint;

PROCEDURE MoveTo* (x3d, y3d, z3d: Real);
BEGIN pen[0] := x3d;  pen[1] := y3d;  pen[2] := z3d END MoveTo;

PROCEDURE Line* (x3d0, y3d0, z3d0, x3d1, y3d1, z3d1: Real);
	VAR x0, y0, x1, y1: Coordinate;   error: INTEGER;
BEGIN
	vyPHIGS3D.PointToDisplayPoint (x3d0, y3d0, z3d0, error, x0, y0);
	vyPHIGS3D.PointToDisplayPoint (x3d1, y3d1, z3d1, error, x1, y1);
	vyHostDisplay.Line (x0, y0, x1, y1);
	pen[0] := x3d1;  pen[1] := y3d1;  pen[2] := z3d1
END Line;

PROCEDURE LineTo* (x3d, y3d, z3d: Real);
BEGIN	Line (pen[0], pen[1], pen[2], x3d, y3d, z3d);
	pen[0] := x3d;  pen[1] := y3d;  pen[2] := z3d
END LineTo;

PROCEDURE FrameRect* (x3d, y3d, z3d, w, h, nx, ny, nz: Real);
	(** vs 0.0d0 *)	(* md  28.11.94 10:32:07 *)
	(*! not yet implemented *)
	(*= frame the rectangle given by its location (x3d, y3d, z3d),
	its size (w, h) and its orientation (nx, ny, nz = normal vector) *)
END FrameRect;

PROCEDURE String* (x3d, y3d, z3d: Real;  f, s: ARRAY OF CHAR);
	(** vs 0.0d0 *)	(* md  28.11.94 10:35:08 *)
	VAR x, y: Coordinate;   error: INTEGER;
BEGIN	vyPHIGS3D.PointToDisplayPoint (x3d, y3d, z3d, error, x, y);
	vyHostDisplay.String (x, y, f, s)
END String;

PROCEDURE EraseString* (x3d, y3d, z3d: Real;  f, s: ARRAY OF CHAR);
	VAR x, y: Coordinate;   error: INTEGER;
BEGIN	vyPHIGS3D.PointToDisplayPoint (x3d, y3d, z3d, error, x, y);
	vyHostDisplay.EraseString (x, y, f, s)
END EraseString;

PROCEDURE InvertString* (x3d, y3d, z3d: Real;  f, s: ARRAY OF CHAR);
	VAR x, y: Coordinate;   error: INTEGER;
BEGIN	vyPHIGS3D.PointToDisplayPoint (x3d, y3d, z3d, error, x, y);
	vyHostDisplay.InvertString (x, y, f, s)
END InvertString;

PROCEDURE PaintPat* (x3d, y3d, z3d: Real;  sgn: vyHostDisplay.tSign);
	VAR x, y: Coordinate;   error: INTEGER;
BEGIN	vyPHIGS3D.PointToDisplayPoint (x3d, y3d, z3d, error, x, y);
	vyHostDisplay.PaintPat (x, y, sgn)
END PaintPat;

(* (* fof 010123: use PaintPat instead ! *)	PROCEDURE PaintColPat* (x3d, y3d, z3d: Real; col: Color; sgn: vyHostDisplay.tSign);
VAR x, y: Coordinate; error: INTEGER;
BEGIN	vyPHIGS3D.PointToDisplayPoint (x3d, y3d, z3d, error, x, y);
vyHostDisplay.PaintColPat (x, y, col, sgn);
END PaintColPat;
*)
PROCEDURE ErasePat* (x3d, y3d, z3d: Real;  sgn: vyHostDisplay.tSign);
	VAR x, y: Coordinate;  error: INTEGER;
BEGIN	vyPHIGS3D.PointToDisplayPoint (x3d, y3d, z3d, error, x, y);
	vyHostDisplay.ErasePat (x, y, sgn)
END ErasePat;

BEGIN pen[0] := 0;  pen[1] := 0;  pen[2] := 0;
END vyPaint3d.