(* Runtime support for Zynq *)
(* Copyright (C) Florian Negele *)

(** The Processors module represents all logical processors of the system. *)
MODULE Processors;

IMPORT SYSTEM, Counters, CPU;

(** Indicates the maximal number of logical processors that are supported by the system. *)
CONST Maximum* = 2 + CPU.Interrupts;

(** Holds the actual number of processors in the system. *)
VAR count-: SIZE;

VAR running: Counters.AlignedCounter; (* counts the number of application processors currently running *)

(** Returns the unique index of the processor executing this procedure call. *)
PROCEDURE GetCurrentIndex- EXTERN "Activities.GetCurrentProcessorIndex" (): SIZE;

(** Suspends the execution of the current processor. *)
(** A suspended processor must be resumed by a call to the Processors.ResumeAnyProcessor procedure. *)
(** @topic Scheduling *)
PROCEDURE SuspendCurrentProcessor-;
CODE
	WFE
END SuspendCurrentProcessor;

(** Resumes the execution of a single suspended processor. *)
(** @topic Scheduling *)
PROCEDURE ResumeAllProcessors-;
CODE
	SEV
END ResumeAllProcessors;

(** Starts the execution of all available processors. *)
(** @topic Scheduling *)
PROCEDURE StartAll-;
CODE
	SEV
END StartAll;

PROCEDURE {NORETURN, NOPAF} Boot;
PROCEDURE Idle EXTERN "Activities.Idle";
PROCEDURE Execute EXTERN "Activities.Execute" (procedure: PROCEDURE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Counters.Inc (running);
	SuspendCurrentProcessor;
	SuspendCurrentProcessor;
	Execute (Idle);
	Counters.Dec (running);
	CPU.Halt;
END Boot;

(** Initializes the module by enumerating all available processors. *)
(** @topic Runtime Call *)
PROCEDURE Initialize-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ResumeAllProcessors;
	REPEAT UNTIL Counters.Read (running) = 1;
	count := 2;
END Initialize;

(** Terminates the module and waits for all other processors to stop their execution. *)
(** @topic Runtime Call *)
PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	REPEAT UNTIL Counters.Read (running) = 0;
END Terminate;

END Processors.
