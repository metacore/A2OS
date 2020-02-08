(* ETH Oberon, Copyright 2001-present ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(* Derived from Out IN Oberon by emptying all procedures.   
Ref. Oberon mailing list archive for 2018, August, search for "Conditional compilation" and "OutStub". *) 
MODULE OutStub IN Oberon; (** portable *)	(* based on module from "Programming in Oberon" *)

(** Null output routines for writing text into the Oberon log or another viewer. *)

(** Write character. *)
PROCEDURE Char*(ch: CHAR);
BEGIN END Char;

(** Write a string. *)
PROCEDURE String*(str: ARRAY OF CHAR);
BEGIN END String;

(** Write the integer i in n field positions. *)
PROCEDURE Int*(i, n: SIGNED32);
BEGIN END Int;

(** Write the integer i in hexadecimal with a leading space. *)
PROCEDURE Hex*(i: SIGNED32);
BEGIN END Hex;

(** Write the real x in n field positions. *)
PROCEDURE Real*(x: FLOAT32; n: SIGNED16);
BEGIN END Real;

(** Write the real x in n field positions in fixed point notation with f fraction digits. *)
PROCEDURE RealFix*(x: FLOAT32; n, f: SIGNED16);
BEGIN END RealFix;

(** Write the longreal x in n field positions. *)
PROCEDURE LongReal*(x: FLOAT64; n: SIGNED16);
BEGIN END LongReal;

(** Write the longreal x in n field positions in fixed point notation with f fraction digits. *)
PROCEDURE LongRealFix*(x: FLOAT64; n, f: SIGNED16);
BEGIN END LongRealFix;

(** Write a carriage return (CR or end-of-line). *)
PROCEDURE Ln*;
BEGIN END Ln;

(** Open a separate viewer for output. *)
PROCEDURE Open*;
BEGIN END Open;

(** Revert output to the system log. *)
PROCEDURE Close*;
BEGIN END Close;

BEGIN
END OutStub.

(** Remarks:

1. Out uses a Writer from module Texts to write output to the log. Writing output using
Out is slow because the log is updated after every procedure call. For fast and flexible
output, use module Texts.

2. Out.Open creates a new text and viewer for output.  Once this is done, output can
be sent to the system log again by executing Close.
*)
