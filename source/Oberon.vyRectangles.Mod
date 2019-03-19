MODULE vyRectangles IN Oberon;   	(*   gs *)
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


(*	(c) Project Voyager, StatLab Heidelberg
*)

(*= Rectangle operations (for voyagers graphic)
all objects (rectangles, points,...) in this module are mathematical objects,
i.e. we do not use the fact that the world on the screen is finite *)

(*! support the scanning of a rectangle *)
(*! base type integer may change *)
IMPORT vyGraphBase;
CONST
	idversion* = 	"vyRectangles v0r0a3";
TYPE integer = vyGraphBase.Coordinate;

PROCEDURE Min (a, b : integer): integer;
BEGIN IF a < b THEN RETURN a ELSE RETURN b END END Min;

PROCEDURE Max (a, b : integer): integer;
BEGIN IF a > b THEN RETURN a ELSE RETURN b END END Max;

PROCEDURE StandardizeRect (VAR x, y, w, h: integer);
BEGIN IF w < 0 THEN x := x + w;   w := - w END;
	IF h < 0 THEN y := y + h;   h := - h END
END StandardizeRect;

PROCEDURE InsetRect* (VAR x, y, w, h: integer;   dx, dy: integer);
BEGIN	x := x + dx;   y := y + dy;   w := w - 2 * dx;   h := h - 2 * dy 	END InsetRect;

PROCEDURE PointInRect* (px, py, X, Y, W, H: integer) : BOOLEAN;
BEGIN StandardizeRect(X, Y, W, H);  RETURN (px >= X) & (px <= X + W) & (py >= Y) & (py <= Y + H)	END PointInRect;

PROCEDURE RectInRect* (x, y, w, h, X, Y, W, H: integer): BOOLEAN;
BEGIN StandardizeRect (x, y, w, h);   StandardizeRect (X, Y, W, H);
	RETURN (x >= X) & (x + w <= X + W) & (y >= Y) & (y + h <= Y + H)
END RectInRect;

PROCEDURE RectIntersection* (VAR x, y, w, h: integer;   X, Y, W, H: integer);
	VAR x1, y1, X1, Y1: integer;
BEGIN StandardizeRect (x, y, w, h);   StandardizeRect (X, Y, W, H);
	x1 := x + w;   y1 := y + h;   X1 := X + W;   Y1 := Y + H;
	x := Max (x, X);   		y := Max (y, Y);  	x1 := Min (x1, X1);   	y1 := Min (y1, Y1);
	w := x1 - x;   h := y1 - y;
	IF w < 0 THEN w := 0;   h := 0 END;
	IF h < 0 THEN w := 0;   h := 0 END
END RectIntersection;

PROCEDURE RectUnion* (VAR x, y, w, h: integer;   X, Y, W, H: integer);
	VAR x0, y0, x1, y1: integer;
BEGIN StandardizeRect (x, y, w, h);   StandardizeRect (X, Y, W, H);
	x0 := Min (x, X);   y0 := Min (y, Y);  	x1 := Max (x + w, X + W);   y1 := Max (y + h, Y + H);
	x := x0;   y := y0;   w := x1 - x0;   h := y1 - y0
END RectUnion;

PROCEDURE EmptyIntersection* (x, y, w, h, X, Y, W, H: integer): BOOLEAN;
BEGIN StandardizeRect (x, y, w, h);   StandardizeRect (X, Y, W, H);
	RETURN (x > X + W) OR (X > x + w) OR (y > Y + H) OR (Y > y + h)
END EmptyIntersection;

END vyRectangles.
