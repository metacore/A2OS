(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Dim3Base IN Oberon;	(** portable *)	(* David Ulrich Nov  95 - März 96 *)
(* This module contains not portable procedures for the Native version **)

IMPORT S := SYSTEM, Pictures;
CONST Black* = 15; White* = 0;	(** black and white of the windows color table **)
VAR
	baseAdr: ADDRESS;
	lineW, height: SIGNED32;

(** correct color table for Native version **)
PROCEDURE CheckColorTab*(VAR R, G, B: ARRAY OF SIGNED16);
	(* nothing to do *)
END CheckColorTab;

(** convert color number to Dim3 color palette **)
PROCEDURE GetRealColor*(color: SIGNED16):SIGNED16;
BEGIN
	RETURN color
END GetRealColor;

(** calculate picture addresses **)
PROCEDURE SetPicture*(P: Pictures.Picture);
BEGIN
	baseAdr := P.address;
	lineW := P.width; height := P.height;
END SetPicture;

(** get address of position X in current scanline Y of actual picture **)
PROCEDURE GetAddress*(X, Y: SIGNED16): ADDRESS;
BEGIN
	RETURN baseAdr + lineW * Y + X;
END GetAddress;

(** ReplConst in previosly set picture with mode replace, H = 1 **)
PROCEDURE ReplConst*(col, X, Y, W: SIGNED16);
VAR col4: SET32; color: CHAR; pictAdr: ADDRESS; color4: ARRAY 4 OF CHAR;
BEGIN
	color := CHR(col);
	color4[0] := color; color4[1] := color; color4[2] := color; color4[3] := color;
	col4 := S.VAL(SET32, color4);
	pictAdr := baseAdr + lineW * Y + X;
	WHILE W > 4 DO S.PUT(pictAdr, col4); DEC(W, 4); INC(pictAdr, 4) END;
	WHILE W > 0 DO S.PUT(pictAdr, color); DEC(W); INC(pictAdr) END;
END ReplConst;

END Dim3Base.
