(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Types IN Oberon;	(** non-portable *)     (* RC 16.1.92 / MH 30.8.93 adapted to Oberon for Windows *)

(**Module Types allow mappings between type names and types, and for exploring the type extensions at run time.
*)

IMPORT S := SYSTEM, Modules IN A2, Heaps IN A2;

TYPE
	Type* = Modules.TypeDesc;

VAR
	(*newRec: PROCEDURE(VAR p: LONGINT;  tag: LONGINT);*)

(** Returned the named (record) type from module mod. *)
PROCEDURE This* (mod: Modules.Module; name: ARRAY OF CHAR): Type;
BEGIN
	RETURN Modules.ThisType(mod,name)
END This;

(** Return the type extension level level of type t. *)
PROCEDURE BaseOf* (t: Type; level: INTEGER): Type;
BEGIN
	S.GET(S.VAL(LONGINT,t.tag) - 8 - 4*level, t);
	IF t # NIL THEN
		S.GET(S.VAL(LONGINT, t) - 4, t)
	END;
	RETURN t
END BaseOf;

(** What is the extension level of t? *)
PROCEDURE LevelOf* (t: Type): INTEGER;
BEGIN
	RETURN INTEGER(t.flags-{Modules.ProtTypeBit})
END LevelOf;

(*
PROCEDURE IsProtected*(t: Type): BOOLEAN;
BEGIN
	RETURN (t.ext0.filler[0] # 0X) OR (t.ext0.filler[1] # 0X) OR (t.ext0.filler[2] # 0X);
END IsProtected;
*)

(** What is the type of pointer based type o? *)
PROCEDURE TypeOf* (o: ANY): Type;
	VAR type: Type;
BEGIN
	S.GET(S.VAL(LONGINT, o)-4, type);
	S.GET(S.VAL(LONGINT, type)-4, type);
	RETURN type
END TypeOf;

(** Allocate a new pointer-based record variable of type t, assigning it to o. *)
PROCEDURE NewObj* (VAR o: ANY; t: Type);
	VAR otype: Type;
BEGIN
	S.GET(S.VAL(LONGINT, o) - 4, otype);	(* uses compiler hack in OPC.Parameter *)
	IF BaseOf(t, LevelOf(otype)) # otype THEN o := NIL; RETURN END ;
	Heaps.NewRec(o,S.VAL(LONGINT,t.tag),FALSE); (* ug: only allow copying of non-realtime objects *)
	(*
	newRec(S.VAL(LONGINT, o), S.VAL(LONGINT,t.tag))
	*)
END NewObj;

BEGIN
	(*S.GET(ADDRESSOF(Heaps.runtime[0]), newRec)*)
END Types.
