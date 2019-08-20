MODULE ReleaseThreadPool; (** AUTHOR "staubesv"; PURPOSE "Threadpool width job dependencies/preferences support"; *)
(**
 * STATUS: EXPERIMENTAL (don't use for production code)
 *
 * Notes:
 * 	- This is an experimental thread pool that is optimized for Release.Mod.
 *	- If you just need a thread pool (no dependencies, no priorities), don't use this one. A simple threadpool can be implemented much simpler and efficiently
 *)

IMPORT KernelLog;

CONST

	(* Worker thread states *)
	Ready = 0;
	GotWork = 5;
	Working = 8;
	Finished = 20;
	Error = 70;
	Exception = 80;
	Terminating = 99;
	Terminated = 100;

	MaxNofDependencies = 64;

	NoMoreDependencies* = -1;
	MoreDependencies = -2;

	Stats = TRUE;

TYPE

	(* Uses NoMoreDependencies as sentinel *)
	Dependencies* = ARRAY MaxNofDependencies + 1 OF SIZE;

	JobProcedure* = PROCEDURE {DELEGATE} (parameters : ANY; VAR error : BOOLEAN);

	Job = OBJECT
	VAR
		proc : JobProcedure;
		parameters : ANY;
		uid : SIZE;
		priority : SIZE;
		completed : BOOLEAN;
		dependencies : Dependencies;

		(* SortedJobList double-linked list *)
		previous, next : Job;

		(* HashTable double-linked collision list *)
		hashPrevious, hashNext : Job;

		PROCEDURE IsCompleted() : BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN completed;
		END IsCompleted;

		PROCEDURE &Init;
		VAR i : SIZE;
		BEGIN
			proc := NIL;
			parameters := NIL;

			priority := 0;
			completed := FALSE;

			FOR i := 0 TO MaxNofDependencies-1 DO
				dependencies[i] := NoMoreDependencies;
			END;
			previous := NIL; next := NIL;
			hashPrevious := NIL; hashNext := NIL;
		END Init;

	END Job;

TYPE

	Worker = OBJECT
	VAR
		job : Job;
		state : WORD;
		threadPool : ThreadPool;

		(* WorkerList fields *)
		previous, next : Worker;

		PROCEDURE SetJob(job: Job);
		BEGIN {EXCLUSIVE}
			ASSERT((job # NIL) & (job.proc # NIL));
			ASSERT((state = Ready) OR (state = Finished));
			SELF.job := job;
			state := GotWork;
		END SetJob;

		PROCEDURE SetState(state : WORD);
		BEGIN {EXCLUSIVE}
			IF (SELF.state < Terminating) OR ((SELF.state = Terminating) & (state = Terminated)) THEN
				SELF.state := state;
			END;
		END SetState;

		PROCEDURE DoJob;
		VAR trap, error : BOOLEAN;
		BEGIN
			trap := FALSE; error := FALSE;
			job.proc(job.parameters, error);
		FINALLY
			IF trap THEN SetState(Exception);
			ELSIF error THEN SetState(Error);
			ELSE
				SetState(Finished);
			END;
		END DoJob;

		PROCEDURE Terminate;
		BEGIN
			SetState(Terminating);
			BEGIN {EXCLUSIVE} AWAIT(state = Terminated); END;
		END Terminate;

		PROCEDURE &Init(threadPool : ThreadPool);
		BEGIN
			ASSERT(threadPool # NIL);
			SELF.threadPool := threadPool;
			state := Ready;
			previous := NIL; next := NIL;
		END Init;

	BEGIN {ACTIVE}
		LOOP
			BEGIN {EXCLUSIVE}
				AWAIT((state = GotWork) OR (state = Terminating));
				IF (state = GotWork) THEN
					state := Working;
				ELSE
					ASSERT(state = Terminating);
					EXIT;
				END;
			END;
			ASSERT(state = Working);
			DoJob;
			threadPool.JobDone(SELF, SELF.job);
		END;
		SetState(Terminated);
	END Worker;

TYPE

	WorkerList = OBJECT
	VAR
		head : Worker;
		nofWorkers : SIZE;

		(* Return the number of workers currently in this list *)
		PROCEDURE GetNofWorkers() : SIZE;
		BEGIN {EXCLUSIVE}
			RETURN nofWorkers;
		END GetNofWorkers;

		(* Get Worker from list and remove it. Return NIL if no worker in list *)
		PROCEDURE Get() : Worker;
		VAR worker : Worker;
		BEGIN {EXCLUSIVE}
			worker := head;
			IF (worker # NIL) THEN
				ASSERT(worker.previous = NIL);
				head := head.next;
				IF (head # NIL) THEN head.previous := NIL; END;
				worker.next := NIL;
				DEC(nofWorkers);
				ASSERT(nofWorkers >= 0);
			END;
			ASSERT((worker = NIL) OR ((worker.previous = NIL) & (worker.next = NIL)));
			RETURN worker;
		END Get;

		PROCEDURE Add(worker : Worker);
		BEGIN {EXCLUSIVE}
			ASSERT((worker # NIL) & (worker.previous = NIL) & (worker.next = NIL));
			IF (head = NIL) THEN
				head := worker;
			ELSE
				worker.next := head;
				IF (worker.next # NIL) THEN worker.next.previous := worker; END;
				head := worker;
			END;
			INC(nofWorkers);
			ASSERT((head = worker) & (head.previous = NIL));
		END Add;

		PROCEDURE &Init;
		BEGIN
			head := NIL;
			nofWorkers := 0;
		END Init;

	END WorkerList;

TYPE

	HashTable = OBJECT
	VAR
		table : POINTER TO ARRAY OF Job;
		size : SIZE;

		PROCEDURE Find(uid : SIZE) : Job;
		VAR hashValue : SIZE; job : Job;
		BEGIN
			IF Stats THEN INC(Nlookups); END;
			hashValue := uid MOD size;
			job := table[hashValue].hashNext;
			IF Stats & (job # NIL) & (job.hashNext # NIL) THEN INC(NlookupCollisions); END;
			WHILE (job # NIL) & (job.uid # uid) DO job := job.hashNext; END;
			IF Stats & (job = NIL) THEN INC(NlookupNotFound); END;
			RETURN job;
		END Find;

		PROCEDURE Add(job : Job);
		VAR hashValue : SIZE;
		BEGIN {EXCLUSIVE}
			ASSERT((job # NIL) & (job.proc # NIL) & (job.hashPrevious = NIL) & (job.hashNext = NIL));
			hashValue := job.uid MOD size;
			(* Insert at head of collision list *)
			job.hashPrevious := table[hashValue];
			job.hashNext := table[hashValue].hashNext;
			table[hashValue].hashNext := job;
			IF (job.hashNext # NIL) THEN job.hashNext.hashPrevious := job; END;
			ASSERT(job.hashPrevious # NIL);
		END Add;

		PROCEDURE Remove(job : Job);
		BEGIN {EXCLUSIVE}
			ASSERT((job # NIL) & (job.hashPrevious # NIL));
			job.hashPrevious.hashNext := job.hashNext;
			IF (job.hashNext # NIL) THEN job.hashNext.hashPrevious := job.hashPrevious; END;
			job.hashPrevious := NIL; job.hashNext := NIL;
			ASSERT((job.hashPrevious = NIL) & (job.hashNext = NIL));
		END Remove;

		PROCEDURE &Init(size : SIZE);
		VAR i : SIZE;
		BEGIN
			ASSERT(size > 0);
			SELF.size := size;
			NEW(table, size);
			FOR i := 0 TO size-1 DO
				NEW(table[i]); (* list heads *)
			END;
		END Init;

	END HashTable;

TYPE

	SortedJobList = OBJECT
	VAR
		head : Job;
		nofJobs : SIZE;

		(* 	Returns the first job in the list (highest priority) or NIL, if no jobs are ready to be executed.
			The job is removed from the list *)
		PROCEDURE Get() : Job;
		VAR job : Job;
		BEGIN {EXCLUSIVE}
			job := head.next;
			IF (job # NIL) THEN
				head.next := job.next;
				job.previous := NIL; job.next := NIL;
				IF (head.next # NIL) THEN head.next.previous := head; END;
				DEC(nofJobs);
			END;
			ASSERT(job # head);
			ASSERT((job = NIL) OR ((job.previous = NIL) & (job.next = NIL)));
			RETURN job;
		END Get;

		PROCEDURE Add(job : Job);
		VAR previous : Job;
		BEGIN {EXCLUSIVE}
			ASSERT((job # NIL) & (job.previous = NIL) & (job.next = NIL));
			previous := head;
			WHILE (previous.next # NIL) & (previous.next.priority > job.priority) DO previous := previous.next; END;
			job.next := previous.next;
			previous.next := job;
			job.previous := previous;
			IF (job.next # NIL) THEN job.next.previous := job; END;
			INC(nofJobs);
			ASSERT(job.previous # NIL);
		END Add;

		PROCEDURE Remove(job : Job);
		BEGIN {EXCLUSIVE}
			ASSERT(job # head);
			ASSERT((job # NIL) &(job.previous # NIL));
			job.previous.next := job.next;
			IF (job.next # NIL) THEN job.next.previous := job.previous; END;
			job.previous := NIL; job.next := NIL;
			DEC(nofJobs);
			ASSERT((job.previous = NIL) & (job.next = NIL));
		END Remove;

		PROCEDURE &Init;
		BEGIN
			NEW(head); (* head of list *)
			nofJobs := 0;
		END Init;

	END SortedJobList;

TYPE

	JobManager = OBJECT
	VAR
		(* hash table used for fast finding a job by its uid *)
		hashTable : HashTable;

		(* list of jobs ready to be executed *)
		readyList : SortedJobList;

		(* list of jobs waiting because of dependencies on other jobs *)
		waitingList : SortedJobList;

		PROCEDURE &Init(size : SIZE);
		BEGIN
			NEW(hashTable, size);
			NEW(readyList);
			NEW(waitingList);
		END Init;

		(* 	Returns the highest priority job that can be executed or NIL, if no job can be executed.
			The job is removed from the ready list but still kept in the hashTable since it is not yet finished (needed to check
			dependecies) *)
		PROCEDURE GetReadyJob() : Job;
		BEGIN (* concurreny allowed here *)
			RETURN readyList.Get();
		END GetReadyJob;

		PROCEDURE Add(job : Job);
		BEGIN (* concurrency allowed here *)
			ASSERT((job # NIL) & (job.proc # NIL));
			hashTable.Add(job);
			IF IsReady(job) THEN
				readyList.Add(job);
			ELSE
				waitingList.Add(job);
			END;
		END Add;

		(* 	The job has already been removed from the ready list when getting it from there. After it has been executed,
			it can be removed from the hash table as well *)
		PROCEDURE Remove(job : Job);
		BEGIN (* concurrency allowed here *)
			ASSERT(job # NIL);
			hashTable.Remove(job);
			ASSERT((job # NIL) & (job.previous = NIL) & (job.next = NIL) & (job.hashPrevious = NIL) & (job.hashNext = NIL));
		END Remove;

		(* This procedure is non-reentrant! Only called by thread pool main thread *)
		PROCEDURE ReCheckDependencies;
		VAR job, next : Job;
		BEGIN {EXCLUSIVE} (* {waitingList.Remove only called from here, waitingList.Get never called, waitingList.Add called concurrently} *)
			IF Stats THEN INC(NdependencyChecks); END;
			job := waitingList.head.next;
			WHILE (job # NIL) DO
				next := job.next;
				IF IsReady(job) THEN
					IF Stats THEN INC(NdependenciesResolved); END;
					waitingList.Remove(job);
					readyList.Add(job);
				ELSE
					IF Stats THEN INC(NdependenciesPersist); END;
				END;
				job := next;
			END;
		END ReCheckDependencies;

		(* Returns TRUE if the job is ready to be executed, FALSE if the job has to wait because of dependencies to other jobs *)
		PROCEDURE IsReady(job : Job) : BOOLEAN;
		VAR otherJob : Job; i : SIZE;
		BEGIN (* concurrency allowed here *)
			ASSERT(job # NIL);
			i := 0;
			WHILE (job.dependencies[i] # NoMoreDependencies) DO (* NoMoreDependencies used as sentinel *)
				IF job.dependencies[i] # MoreDependencies THEN (* dependecy still exists *)
					otherJob := hashTable.Find(job.dependencies[i]);
					IF (otherJob # NIL) & ~otherJob.IsCompleted() THEN
						RETURN FALSE;
					ELSE
						job.dependencies[i] := MoreDependencies; (* that one is gone *)
					END;
				END;
				INC(i);
			END;
			RETURN TRUE;
		END IsReady;

	END JobManager;

TYPE

	JobPool = OBJECT
	VAR
		head : Job;
		nextUid : SIZE;

		PROCEDURE Get() : Job;
		VAR job : Job;
		BEGIN
			BEGIN {EXCLUSIVE}
				job := head.next;
				IF (job # NIL) THEN
					head.next := job.next;
					IF Stats THEN INC(NjobPoolReused); END;
				END;
			END;
			IF (job = NIL) THEN
				NEW(job);
				job.uid := GetUID();
				IF Stats THEN INC(NjobPoolCreated); END;
			ELSE
				job.next := NIL;
			END;
			ASSERT(job # head);
			ASSERT((job # NIL) & (job.previous = NIL) & (job.next = NIL) & (job.hashPrevious = NIL) & (job.hashNext = NIL));
			RETURN job;
		END Get;

		PROCEDURE Recycle(job : Job);
		BEGIN
			ASSERT((job # NIL) & (job.previous = NIL) & (job.next = NIL) & (job.hashPrevious = NIL) & (job.hashNext = NIL));
			job.Init;
			job.uid := GetUID(); (* needs new UID !!! *)
			BEGIN {EXCLUSIVE}
				(* insert at list head *)
				job.next := head.next;
				head.next := job;
			END;
			IF Stats THEN INC(NjobPoolRecycled); END;
		END Recycle;

		PROCEDURE GetUID() : SIZE;
		BEGIN {EXCLUSIVE}
			INC(nextUid);
			ASSERT(nextUid > 0);
			RETURN nextUid;
		END GetUID;

		PROCEDURE &Init;
		BEGIN
			NEW(head); (* head of list *)
			nextUid := 0; (* UIDs start at 1 *)
		END Init;

	END JobPool;

TYPE

	ThreadPool* = OBJECT
	VAR
		(* Lists of ready  worker threads *)
		readyList : WorkerList;

		jobPool : JobPool;
		jobManager : JobManager;

		(* Contains references to all worker threads. Not change while threadpool is running. *)
		workers : POINTER TO ARRAY OF Worker;

		hadError : BOOLEAN; (* sticky *)

		jobsOnTheFly : SIZE;

		(* activity control fields *)
		doScheduling : BOOLEAN;
		alive, dead : BOOLEAN;

		PROCEDURE &Init*(nofWorkers : SIZE);
		VAR i : SIZE;
		BEGIN
			ASSERT(nofWorkers > 0);
			NEW(readyList);
			NEW(jobPool);
			NEW(jobManager, 512);
			(* create worker threads *)
			NEW(workers, nofWorkers);
			FOR i := 0 TO nofWorkers-1 DO
				NEW(workers[i], SELF);
				readyList.Add(workers[i]);
			END;
			hadError := FALSE;
			jobsOnTheFly := 0;
			doScheduling := FALSE;
			alive := TRUE; dead := FALSE;
		END Init;

		PROCEDURE CreateJob*(proc : JobProcedure; parameters : ANY; priority : SIZE; CONST dependencies : Dependencies) : SIZE;
		VAR job : Job;
		BEGIN
			ASSERT((proc # NIL) & (priority >= 0));
			job := jobPool.Get();
			job.proc := proc;
			job.parameters := parameters;
			job.priority := priority;
			job.dependencies := dependencies;
			BEGIN {EXCLUSIVE} INC(jobsOnTheFly); END;
			jobManager.Add(job); (* this also checks the dependencies *)
			(* assumption: there are more jobs than workers... delegate job assignment to active body *)
			BEGIN {EXCLUSIVE} doScheduling := TRUE; END;
			IF Stats THEN INC(NjobsCreated); END;
			RETURN job.uid;
		END CreateJob;

		PROCEDURE AwaitAllDone*;
		BEGIN {EXCLUSIVE}
			AWAIT((jobsOnTheFly = 0) OR (hadError));
		END AwaitAllDone;

		(* Called by worker threads when they finished their job *)
		PROCEDURE JobDone(worker : Worker; job : Job);
		VAR newJob : Job;
		BEGIN
			ASSERT((worker # NIL) & (job # NIL));
			IF Stats THEN INC(NjobsDone); END;
			jobManager.Remove(job);
			jobPool.Recycle(job);
			BEGIN {EXCLUSIVE} DEC(jobsOnTheFly); END;
			IF (worker.state = Exception) THEN KernelLog.String("EXCEPTION"); KernelLog.Ln; END;
			IF ~hadError & (worker.state # Error) & (worker.state # Exception) THEN
				IF (worker.state >= Terminating) THEN KernelLog.String("TERMINTATE"); KernelLog.Ln; RETURN; END;
				ASSERT(worker.state = Finished);
				jobManager.ReCheckDependencies;
				newJob := jobManager.GetReadyJob();
				IF (newJob # NIL) THEN (* keep worker busy *)
					worker.SetJob(newJob);
					IF Stats THEN INC(NjobHandoverSucceeded); END;
				ELSE
					readyList.Add(worker);
					IF Stats THEN INC(NjobHandoverFailed); END;
				END;
				IF (readyList.GetNofWorkers() > 0) THEN
					(* maybe some jobs are ready now since we re-checked the dependencies above *)
					BEGIN {EXCLUSIVE} doScheduling := TRUE; END;
				END;
			ELSE
				KernelLog.String("Threadpool had error."); KernelLog.Ln;
				BEGIN {EXCLUSIVE} hadError := TRUE; END;
				IF Stats THEN INC(NjobErrors); END;
			END;
		END JobDone;

		PROCEDURE DoScheduling;
		VAR worker : Worker; job : Job;
		BEGIN (* only call from active object body! *)
			REPEAT
				worker := NIL;
				IF (readyList.GetNofWorkers() > 0) THEN
					worker := readyList.Get();
					IF (worker # NIL) THEN (* this can happen since we don't lock the ready list over the two requests *)
						job := jobManager.GetReadyJob();
						IF (job # NIL) THEN
							IF Stats THEN INC(NjobsScheduled); END;
							worker.SetJob(job);
						ELSE
							readyList.Add(worker); (* hopefully, this rarely happens *)
						END;
					END;
				END;
			UNTIL (worker = NIL) OR (job = NIL);
		END DoScheduling;

		PROCEDURE Close*;
		VAR i : SIZE;
		BEGIN
			BEGIN {EXCLUSIVE} alive := FALSE; END;
			FOR i := 0 TO LEN(workers)-1 DO
				workers[i].Terminate;
			END;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Close;

	BEGIN {ACTIVE}
		WHILE alive DO
			BEGIN {EXCLUSIVE} AWAIT(doScheduling OR (alive = FALSE));
				doScheduling := FALSE;
			END;
			IF hadError THEN alive := FALSE; END;
			IF alive THEN
				IF Stats THEN INC(Nscheduling); END;
				DoScheduling;
			END;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END ThreadPool;

VAR
	(* Only works correctly with one single ThreadPool instance *)
	NjobsCreated-, NjobsDone-, NjobErrors-,
	NjobHandoverSucceeded-, NjobHandoverFailed-,
	NjobPoolCreated-, NjobPoolRecycled-, NjobPoolReused- ,
	NdependencyChecks-, NdependenciesResolved-, NdependenciesPersist-,
	Nscheduling-, NjobsScheduled-,
	Nlookups-, NlookupCollisions-, NlookupNotFound- : SIZE;

PROCEDURE ClearStats*;
BEGIN
	NjobsCreated := 0; NjobsDone := 0; NjobErrors := 0;
	NjobHandoverSucceeded := 0; NjobHandoverFailed := 0;
	NjobPoolCreated := 0; NjobPoolRecycled := 0; NjobPoolReused := 0;
	NdependencyChecks := 0; NdependenciesResolved := 0; NdependenciesPersist := 0;
	Nscheduling := 0; NjobsScheduled := 0;
	Nlookups := 0; NlookupCollisions := 0; NlookupNotFound := 0;
END ClearStats;

BEGIN
	ClearStats;
END ReleaseThreadPool.

System.Free ReleaseThreadPool ~

ReleaseThreadPool.ClearStats ~

System.DoCommands
	WMPerfMonPluginModVars.Install ReleaseThreadPool
		ReleaseThreadPool.NjobsCreated ReleaseThreadPool.NjobsDone ReleaseThreadPool.NjobErrors
		ReleaseThreadPool.NjobHandoverSucceeded ReleaseThreadPool.NjobHandoverFailed
		ReleaseThreadPool.Nscheduling ReleaseThreadPool.NjobsScheduled
		ReleaseThreadPool.Nlookups ReleaseThreadPool.NlookupCollisions ReleaseThreadPool.NlookupNotFound
	~
	WMPerfMonPluginModVars.Install JobPool
		ReleaseThreadPool.NjobPoolCreated ReleaseThreadPool.NjobPoolRecycled ReleaseThreadPool.NjobPoolReused
		ReleaseThreadPool.NdependencyChecks ReleaseThreadPool.NdependenciesResolved ReleaseThreadPool.NdependenciesPersist
	~
~~
