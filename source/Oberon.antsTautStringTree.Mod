MODULE antsTautStringTree IN Oberon;
(* Im Prinzip ein ganz normaler Binärbaum. Die Werte in den Knoten berechnen sich als Summe der Kinder.
	Dient zur Überprüfung und zur Rekalibrierung des thresholds in antsTautString.Mod. *)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)


(**
Stefan Brandt, 2003
Alexandra Hutzenthaler, 2003
*)

IMPORT math := MathL IN A2;

TYPE
	Tree = RECORD
		root: Node;

	END;

	Node = POINTER TO NodeDesc;
	NodeDesc = RECORD
		left, right: Node;
		value: FLOAT64;
		start, ende: SIGNED32;
	END;

	PROCEDURE InitWithLength( t: Tree; n: SIGNED32;  y: ARRAY OF FLOAT64 );
	(* Initialisierung des Baumes mit festgelegter Länge.
	Die Werte in y werden als Werte in den Blättern des Baumes gespeichert.
	Rekursiv werden dann alle weiteren Werte berchnet bis zur Wurzel des Baumes. *)

	VAR this: Node;

	BEGIN
		NEW( this );  t.root := this;  Set( this, y, n, 0, n - 1 );  this := t.root;  this.value := SetValue( t.root );
	END InitWithLength;

	PROCEDURE Init*( VAR z: ARRAY OF SIGNED32;  n: SIGNED32;  y: ARRAY OF FLOAT64;  thr: FLOAT64;  squeezing: ARRAY OF CHAR );
	(* Initialisierung des Baumes. *)

	VAR t: Tree;

	BEGIN
		InitWithLength( t,n, y );  CheckThresh( t,z, thr, squeezing );
	END Init;


	PROCEDURE Set( VAR x: Node;  y: ARRAY OF FLOAT64;  n: SIGNED32;  start: SIGNED32;  ende: SIGNED32 );
	(* Setzt die Werte in den Blättern des Baumes mit den Werten in y. *)

	VAR left, right: Node;  j, k: SIGNED32;

	BEGIN
		x.start := start;  x.ende := ende;

		IF n > 1 THEN
			x.value := 0;  NEW( left );  NEW( right );  x.left := left;  x.right := right;  j := n DIV 2;  k := n MOD 2;
			Set( x.left, y, j + k, start, start + j + k - 1 );  Set( x.right, y, j, start + j + k, ende );
		ELSE x.value := y[start];  x.left := NIL;  x.right := NIL;
		END;
	END Set;

	PROCEDURE SetValue( VAR x: Node ): FLOAT64;
	(* Setzt rekursiv die Werte der Knoten des Baumes aus den Kindern. *)

	BEGIN
		IF (x.left # NIL ) THEN x.value := (SetValue( x.left ) + SetValue( x.right ));  END;

		RETURN x.value;
	END SetValue;

	PROCEDURE CheckThresh( t: Tree; VAR z: ARRAY OF SIGNED32;  thr: FLOAT64;  squeezing: ARRAY OF CHAR );
	(* Überprüft, ob der aktuelle Wert in einem Knoten bereits einen bestimmten Wert überschreitet.
	Ruft die rekursive Prozedur CheckNode auf. *)

	VAR this: Node;

	BEGIN
		NEW( this );  this := t.root;  CheckNode( z, this, thr, squeezing );
	END CheckThresh;


	PROCEDURE CheckNode( VAR z: ARRAY OF SIGNED32;  VAR x: Node;  thr: FLOAT64;  squeezing: ARRAY OF CHAR );
	(* Überprüft rekursiv, ob ein Wert in einem Knoten einen bestimmten kritischen Wert überschreitet.
	Wenn ja wird im Überprüfungsvektor z alle Blätter, die an diesem Knoten hängen mit 1 gekennzeichnet. *)

	VAR check: FLOAT64;  i, n: SIGNED32;

	BEGIN
		n := x.ende - x.start + 1;  check := ABS( x.value / math.sqrt( n ) );

		IF (x.left # NIL ) THEN
			IF (squeezing = "local") THEN
				IF (check > thr) THEN
					FOR i := x.start TO x.ende DO z[i] := 1;  END;

					x.left := NIL;  x.right := NIL;
				ELSE CheckNode( z, x.left, thr, squeezing );  CheckNode( z, x.right, thr, squeezing );
				END;
			ELSIF (squeezing = "global") THEN
				FOR i := 0 TO LEN( z ) - 1 DO z[i] := 1;  END;
			END;
		ELSE
			IF (n = 1) THEN
				IF (check > thr) THEN
					IF (squeezing = "local") THEN z[x.start] := 1;
					ELSIF (squeezing = "global") THEN
						FOR i := 0 TO LEN( z ) - 1 DO z[i] := 1;  END;
					END;
				END;
			END;
		END;
	END CheckNode;

END antsTautStringTree.



