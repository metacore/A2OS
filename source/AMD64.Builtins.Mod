MODULE Builtins; (** AUTHOR "fof"; PURPOSE "Built-in functions for the Active Oberon Compiler"; *)
IMPORT SYSTEM;

VAR
	kernelModule-: ARRAY 32 OF ADDRESS;
	modules-: SIGNED32;

PROCEDURE InsertModule*(a: ADDRESS): BOOLEAN;
BEGIN {UNCOOPERATIVE}
	kernelModule[modules] := a;
	INC(modules);
	RETURN TRUE
END InsertModule;

(* compare strings,
	returns 0 if strings are equal,
	returns +1 if left is lexicographic greater than right,
	returns -1 if left is lexicographics smaller than right
	traps if src or destination is not 0X terminated and comparison is not finished
*)
PROCEDURE CompareString*(CONST left,right: ARRAY OF CHAR): SIGNED8;
VAR i: SIZE; res: SIGNED8; l, r: CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	i := 0; res := 0;
	LOOP
		ASSERT (i < LEN (left));
		ASSERT (i < LEN (right));
		l := left[i];
		r := right[i];
		IF (res = 0) THEN
			IF (l > r) THEN
				res := 1; EXIT
			ELSIF (l<r) THEN
				res := -1; EXIT
			ELSIF l=0X THEN
				EXIT
			END;
		END;
		INC(i);
	END;
	RETURN res
END CompareString;

(* copy string from src to dest, emits trap if not 0X terminated or destination too short *)
PROCEDURE CopyString*(VAR dest: ARRAY OF CHAR; CONST src: ARRAY OF CHAR);
VAR i: SIZE; ch :CHAR; l1, l2: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(*
	i := 0;
	REPEAT
		ch := src[i];		(* index check included *)
		dest[i] := ch;	(* index check included *)
		INC(i);
	UNTIL ch=0X;
	*)

	(*! currently implemented: old PACO semantics *)
	l1 := LEN(dest);
	l2 := LEN(src);
	IF l2 < l1 THEN l1 := l2 END;
	SYSTEM.MOVE(ADDRESSOF(src[0]),ADDRESSOF(dest[0]),l1);
	dest[l1-1] := 0X; (* this implies that COPY assumes a string *)
END CopyString;

PROCEDURE EnsureAllocatedStack*(size: SIZE);
VAR i: ADDRESS; temp: ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO size BY 4096 DO
		SYSTEM.GET(ADDRESSOF(i)-i,temp);
	END;
END EnsureAllocatedStack;

BEGIN
	(*! assumed that modules = 0, implicit call of InsertModule *)
END Builtins.


Builtins.Obw
