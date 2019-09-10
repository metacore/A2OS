MODULE TestLocks;	(* pjm *)

(* Test module for Locks. *)

IMPORT SYSTEM, Machine, KernelLog;

(* Display locking state. *)

PROCEDURE ShowState(msg: ARRAY OF CHAR);
VAR id: SIGNED32; ints: BOOLEAN;
BEGIN
	ints := Machine.InterruptsEnabled();
	KernelLog.String(msg); KernelLog.String(": ");
	id := Machine.ID();
	KernelLog.String("Processor "); KernelLog.Int(id, 1);
	KernelLog.String(", interrupts are ");
	IF ints THEN KernelLog.String("on") ELSE KernelLog.String("off") END;
	KernelLog.Ln
END ShowState;

(** Acquire and release a single lock. *)

PROCEDURE Single*;
BEGIN
	Machine.Acquire(Machine.KernelLog);
	ShowState("Single");
	Machine.Release(Machine.KernelLog);
END Single;

(** Same as Single, but switch on interrupts. *)

PROCEDURE SingleInt*;
BEGIN
	Machine.Acquire(Machine.KernelLog);
	Machine.Sti();	(* nested lock in write will switch off interrupts again *)
	ShowState("SingleInt1");
	ShowState("SingleInt2");
	Machine.Release(Machine.KernelLog);
END SingleInt;

(** Hold a lock for a long time, to test interrupt interaction. *)

PROCEDURE Long*;
VAR i: SIGNED32;
BEGIN
	Machine.Acquire(Machine.KernelLog);
	FOR i := 0 TO 100000000 DO END;
	ShowState("Long");
	Machine.Release(Machine.KernelLog);
END Long;

(** Same as Long, but switch on interrupts. *)

PROCEDURE LongInt*;
VAR i: SIGNED32;
BEGIN
	Machine.Acquire(Machine.KernelLog);
	Machine.Sti;
	FOR i := 0 TO 100000000 DO END;
	Machine.Cli;
	ShowState("LongInt");
	Machine.Release(Machine.KernelLog);
END LongInt;

(** Acquire and release all locks. *)

PROCEDURE All*;
BEGIN
	Machine.AcquireAll;
	(*ShowState("All");*)
	Machine.ReleaseAll
END All;

(** Attempt to acquire a lock recursively (allowed in old model). *)

PROCEDURE Recursive*;
BEGIN
	Machine.Acquire(Machine.KernelLog);
	Machine.Acquire(Machine.KernelLog);
	ShowState("Recursive");
	Machine.Release(Machine.KernelLog);
	Machine.Release(Machine.KernelLog);
END Recursive;

(** Acquire a lock out of order (not allowed). *)

PROCEDURE OutOfOrder*;
BEGIN
	Machine.Acquire(Machine.TraceOutput);
	Machine.Acquire(Machine.KernelLog);
	ShowState("OutOfOrder");
	Machine.Release(Machine.KernelLog);
	Machine.Release(Machine.TraceOutput)
END OutOfOrder;

(*
(** Acquire special lock. *)

PROCEDURE Special*;
BEGIN
	Machine.Cli();
	ShowState("Special1");
	Machine.AcquireSpecial(Machine.KernelLog);
	ShowState("Special2");
	Machine.Release(Machine.KernelLog);
	ShowState("Special3");
	Machine.Sti
END Special;
*)

END TestLocks.

System.OpenKernelLog

TestLocks.Single
TestLocks.SingleInt	(should trap if StrongChecks are on)
TestLocks.Long	(runs for a few seconds)
TestLocks.LongInt
TestLocks.All
TestLocks.Recursive	(should trap or hang)
TestLocks.OutOfOrder	(should trap or hang)
TestLocks.Special
