(* Generic runtime support *)
(* Copyright (C) Florian Negele *)

MODULE Runtime;

IMPORT SYSTEM, BaseTypes, Trace;

TYPE TrapHandler* = PROCEDURE (number: SIZE);

VAR trapHandler*: TrapHandler;

(** This procedure aborts the program and prints the number of the trap that caused the program to fail. *)
(** The compiler calls this procedure for HALT statements or for unsatisfied ASSERT statements. *)
PROCEDURE {NORETURN} Trap- (number: SIZE);
PROCEDURE Abort EXTERN "Environment.Abort";
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF trapHandler # NIL THEN
		trapHandler (number);
	ELSE
		Trace.Red; Trace.String ("trap: "); Trace.Int (number, 0); Trace.Ln;
		Trace.Default; Trace.StackFrames (1, 8, 20 * SIZE OF ADDRESS);
	END;
	Abort;
END Trap;

(** This procedure acquires memory and returns the address to the first byte or NIL if the allocation fails. *)
(** The compiler implements all NEW statements with a call to this procedure. *)
PROCEDURE New- (size: SIZE): ADDRESS;
VAR result: ADDRESS; tries: SIZE;
PROCEDURE CollectGarbage EXTERN "GarbageCollector.Collect";
PROCEDURE Allocate (size: SIZE): ADDRESS EXTERN "Environment.Allocate" ;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR tries := 1 TO 10 DO
		result := Allocate (size);
		IF result # NIL THEN RETURN result END;
		CollectGarbage;
	END;
	RETURN NIL;
END New;

(** This procedure releases memory that was previously acquired by a call to the [[Runtime.New]] procedure. *)
(** The compiler implements DISPOSE statements on types marked as disposable with a call to this procedure. *)
PROCEDURE Dispose- (VAR pointer {UNTRACED}: BaseTypes.Pointer);
PROCEDURE Deallocate (address: ADDRESS) EXTERN "Environment.Deallocate" ;
PROCEDURE Watch (pointer {UNTRACED}: BaseTypes.Pointer) EXTERN "GarbageCollector.Watch" ;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (pointer # NIL);
	IF pointer IS BaseTypes.Object THEN pointer(BaseTypes.Object).Finalize END;
	IF (pointer IS BaseTypes.Pointer) & (pointer(BaseTypes.Pointer).nextWatched = NIL) THEN Watch (pointer(BaseTypes.Pointer));
	ELSE Deallocate (pointer) END; pointer := NIL;
END Dispose;

END Runtime.

Runtime.Obw
