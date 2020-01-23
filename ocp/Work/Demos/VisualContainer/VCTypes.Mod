MODULE VCTypes; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	WMGraphics;

TYPE
	Point2i* = WMGraphics.Point2d;
	PPoints2i* = POINTER TO ARRAY OF Point2i;

	Point2f* = RECORD
		x*, y*: REAL
	END;
	PPoints2f* = POINTER TO ARRAY OF Point2f;

	Triangle2f* = ARRAY 3 OF Point2f;
	PTriangles2f* = POINTER TO ARRAY OF Triangle2f;

END VCTypes.
