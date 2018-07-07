(* Unix runtime support for processors *)
(* Copyright (C) Florian Negele *)

MODULE Processors;

IMPORT Unix;

(** Indicates the maximal number of logical processors that are supported by the system. *)
CONST Maximum* = MAX (SET) - MIN (SET) + 1;

(** Holds the actual number of processors in the system. *)
VAR count-: SIZE;

VAR affinityMask: SET;
VAR semaphore: Unix.Sem;
VAR barrier: Unix.Barrier;
VAR thread: ARRAY Maximum OF Unix.Thread_t;

(** Returns the unique index of the processor executing this procedure call. *)
PROCEDURE GetCurrentIndex- EXTERN "Activities.GetCurrentProcessorIndex" (): SIZE;

(** Suspends the execution of the current processor. *)
(** A suspended processor must be resumed by a call to the ResumeAnyProcessor procedure. *)
PROCEDURE SuspendCurrentProcessor-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Unix.sem_wait (ADDRESS OF semaphore) = 0);
END SuspendCurrentProcessor;

(** Resumes the execution of all suspended processors. *)
PROCEDURE ResumeAllProcessors-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Unix.sem_post (ADDRESS OF semaphore) = 0);
END ResumeAllProcessors;

(** Starts the execution of all available processors. *)
PROCEDURE StartAll-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (count > 1);
	IF Unix.pthread_barrier_wait (ADDRESS OF barrier) = Unix.PTHREAD_BARRIER_SERIAL_THREAD THEN
		ASSERT (Unix.pthread_barrier_destroy (ADDRESS OF barrier) = 0);
	END;
END StartAll;

(* Start routine for each Posix thread. *)
PROCEDURE {NORETURN} Start (arg: ADDRESS);
PROCEDURE Execute EXTERN "Activities.Execute" (procedure: PROCEDURE);
PROCEDURE Idle EXTERN "Activities.Idle";
BEGIN {UNCOOPERATIVE, UNCHECKED}
	StartAll;
	Execute (Idle);
	Unix.pthread_exit (0);
END Start;

(** Initializes the module by enumerating all available processors. *)
(** The number of concurrent threads corresponds to the number of slots in the affinity mask of the current process. *)
PROCEDURE Initialize-;
VAR self: Unix.Thread_t; mask: SET; i: SIZE; length: WORD;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	self := Unix.pthread_self ();
	ASSERT (Unix.sem_init (ADDRESS OF semaphore, 0, 0) = 0);
	ASSERT (Unix.pthread_getaffinity_np (self, SIZE OF SET, ADDRESS OF affinityMask) = 0);
	length := 0; FOR i := 0 TO Maximum - 1 DO IF i IN affinityMask THEN INC (length) END END;
	ASSERT (Unix.pthread_barrier_init (ADDRESS OF barrier, NIL, length) = 0);

	count := 0;
	FOR i := 0 TO Maximum - 1 DO
		IF i IN affinityMask THEN
			INC (count);

			IF count = 1 THEN
				thread[i] := self;
			ELSE
				ASSERT (Unix.pthread_create (ADDRESS OF thread[i], NIL, Start, NIL) = 0);
			END;

			mask := {i};
			ASSERT (Unix.pthread_setaffinity_np (thread[i], SIZE OF SET, ADDRESS OF mask) = 0);
		ELSE
			thread[i] := self;
		END;
	END;
END Initialize;

(** Terminates the module and waits for all other processors to stop their execution. *)
PROCEDURE Terminate-;
VAR self: Unix.Thread_t; i: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	self := Unix.pthread_self ();
	FOR i := 0 TO Maximum - 1 DO
		IF thread[i] # self THEN
			ASSERT (Unix.pthread_join (thread[i], NIL) = 0);
		END;
	END;
	ASSERT (Unix.sem_destroy (ADDRESS OF semaphore) = 0);
END Terminate;

END Processors.
