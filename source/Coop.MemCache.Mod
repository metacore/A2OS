(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE MemCache; (** AUTHOR "pjm"; PURPOSE "Memory cache control"; *)

IMPORT SYSTEM, Machine;

CONST
		(** cache properties *)
	UC* = 0; WC* = 1; WT* = 4; WP* = 5; WB* = 6;

(** Set the cache properties of the specified physical memory area on the current processor. {physAdr, size MOD PS = 0}  Must be called from supervisor mode. *)

PROCEDURE LocalSetCacheProperties*(physAdr: ADDRESS; size, type: SIGNED32; VAR res: INTEGER);
VAR i, n, f: SIGNED32; mask, base: SET; j, k: ADDRESS;
BEGIN
	res := 1507	(* implementation restriction - fixed entries not supported *)
END LocalSetCacheProperties;

(** Broadcast a LocalSetCacheProperties operation to all processors. *)

PROCEDURE GlobalSetCacheProperties*(physAdr: ADDRESS; size, type: SIGNED32; VAR res: INTEGER);
BEGIN
	res := 1507	(* implementation restriction - fixed entries not supported *)
END GlobalSetCacheProperties;

END MemCache.

(*
to do:
o change error codes
*)
