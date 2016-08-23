MODULE Unix;   (* Josef Templ, 5.3.90	SVR4 system calls *)  (** Linux x86 version, non portable *)

(* Linux PPC version	g.f. 18.04.98	*)
(* Linux x86 version	g.f 10.11.99 	*)
(*	2000.09.19	g.f.	'Sigaltstack' added	*)
(*	2002.06.27	g.f.	TmDesc fixed,  new: Utime, Mktime *)
(*	2006.07.31	g.f.	shared memory support added *)
(*	2007.04.13	g.f.	Thread priorities added *)

IMPORT S := SYSTEM, Glue, Trace;


CONST
	Version* = "Linux";

  	libcname* = "libc.so.6";
	libmname* = "libm.so.6";
	libX11name* = "libX11.so.6";
	libXextname* = "libXext.so.6";
	libpthreadname = "libpthread.so.0";

	LittleEndian* = TRUE;   (** byte order of basic types *)
	LsbIs0* = TRUE;   (** bit order of SET type *)

	PageSize* = 4096;	(* least MMU page size *)

	stdin* = 0;  stdout* = 1;  stderr* = 2;

	(** Unix error codes:	*)
	EPERM* = 1;   (* Not super-user *)
	ENOENT* = 2;   (* No such file or directory *)
	ESRCH* = 3;   (* No such process *)
	EINTR* = 4;   (* interrupted system call *)
	EIO* = 5;   (* I/O error *)
	ENXIO* = 6;   (* No such device or address *)
	E2BIG* = 7;   (* Arg list too long *)
	ENOEXEC* = 8;   (* Exec format error *)
	EBADF* = 9;   (* Bad file number *)
	ECHILD* = 10;   (* No children *)
	EAGAIN* = 11;   (* No more processes *)
	ENOMEM* = 12;   (* Not enough core *)
	EACCES* = 13;   (* Permission denied *)
	EFAULT* = 14;   (* Bad address *)
	ENOTBLK* = 15;   (* Block device required *)
	EBUSY* = 16;   (* Mount device busy *)
	EEXIST* = 17;   (* File exists *)
	EXDEV* = 18;   (* Cross-device link *)
	ENODEV* = 19;   (* No such device *)
	ENOTDIR* = 20;   (* Not a directory *)
	EISDIR* = 21;   (* Is a directory *)
	EINVAL* = 22;   (* Invalid argument *)
	ENFILE* = 23;   (* File table overflow *)
	EMFILE* = 24;   (* Too many open files *)
	ENOTTY* = 25;   (* Inappropriate ioctl for device *)
	ETXTBSY* = 26;   (* Text file busy *)
	EFBIG* = 27;   (* File too large *)
	ENOSPC* = 28;   (* No space left on device *)
	ESPIPE* = 29;   (* Illegal seek *)
	EROFS* = 30;   (* Read only file system *)
	EMLINK* = 31;   (* Too many links *)
	EPIPE* = 32;   (* Broken pipe *)
	EDOM* = 33;   (* Math arg out of domain of func *)
	ERANGE* = 34;   (* Math result not representable *)
	ENOMSG* = 42;   (* No message of desired type *)
	EIDRM* = 43;   (* Identifier removed *)
	ECHRNG* = 44;   (* Channel number out of range *)
	EL2NSYNC* = 45;   (* Level 2 not synchronized *)
	EL3HLT* = 46;   (* Level 3 halted *)
	EL3RST* = 47;   (* Level 3 reset *)
	ELNRNG* = 48;   (* Link number out of range *)
	EUNATCH* = 49;   (* Protocol driver not attached *)
	ENOCSI* = 50;   (* No CSI structure available *)
	EL2HLT* = 51;   (* Level 2 halted *)
	EDEADLK* = 35;   (* Deadlock condition. *)
	ENOLCK* = 37;   (* No record locks available. *)

	(* open flags *)
	rdonly* = {};  rdwr* = {1};  creat* = {6};  trunc* = {9};

	(* access modes *)
	rwrwr* = {2, 4, 5, 7, 8};  rwxrwxrwx* = {0..8};
	
	F_OK* = {};  X_Ok* = {0};  W_OK* = {1};  R_OK* = {2};

	SCHED_OTHER = 0;

	T_SIGRESUME = SIGUSR1;
	T_SIGSUSPEND = SIGUSR2; 

	SIGHUP = 1;
	SIGINT = 2;
	SIGQUIT=3;
	SIGILL = 4;
	SIGTRAP = 5;
	SIGABRT = 6;
	SIGIOT = 6;
	SIGBUS = 7;
	SIGFPE = 8;
	SIGKILL = 9;
	SIGUSR1 = 10;
	SIGSEGV = 11;
	SIGUSR2 = 12;
	SIGPIPE = 13;
	SIGALRM = 14;
	SIGTERM = 15;
	SIGSTKFLT = 16;
	SIGCHLD = 17;
	SIGCONT = 18;
	SIGSTOP = 19;
	SIGTSTP = 20;
	SIGTTIN = 21;
	SIGTTOU = 22;
	SIGURG = 23;
	SIGXCPU = 24;
	SIGXFSZ = 25;
	SIGVTALRM = 26;
	SIGPROF = 27;
	SIGWINCH=28;
	SIGIO=29;
	SIGPOLL = SIGIO;
	SIGPWR = 30;
	SIGSYS = 31;
	SIGUNUSED =31;
	
	SIG_BLOCK = 0;
	SIG_UNBLOCK=1;
	SIG_SETMASK=2;
	
  PTHREAD_CANCEL_ENABLE 	= 0;
  PTHREAD_CANCEL_DISABLE	= 1;

  PTHREAD_CANCEL_ASYNCHRONOUS	=0;
  PTHREAD_CANCEL_DEFERRED	= 1;

	(*--------------------------- Threads -------------------------------*)

TYPE
	Thread_t* = ADDRESS;
	Mutex_t* = ADDRESS;
	MutexType = ARRAY 8 OF ADDRESS; 
	(*
	Mutex = ARRAY 8 OF ADDRESS;
	Mutex_t* = POINTER TO Mutex;
	*)
	Condition_t* = ADDRESS;
	ConditionType = ARRAY 12 OF WORD;

	Sigset_t= ARRAY 32 OF ADDRESS; 

	
CONST
	(* Thread priorities *)
	ThreadLow* = 1; ThreadNormal* = 20; ThreadHigh* = 99;	
	NumPriorities* = 99;	(* number of priority levels *)


	(*---------------------------- IP -----------------------------------*)

CONST
	(* domain *)
		AFINET* = 2;
		AFINET6* = 26;
		
		PFINET* = AFINET;
		PFINET6* = AFINET6;
		
	(* types of connection*)
		SockStream*	= 1;
		SockDGram*	= 2;
		
	(* Protocols *)
		IpProtoUDP*	= 17;
		IpProtoTCP*		=  6;

	(* setsockopt *)
		SoLSocket*		= 1;			(* socket option level *)
		SoLinger* 		= 13; 		(* linger (gracefully close the connection)*)
		SoKeepAlive*	= 9;			(* keep connection alive *)
		SoNoDelay*	= 1;			(* no delay *)

	(* ioctl *)
		FioNRead*		= 541BH;	(* something to read ? *)
		
	(* recv *)
		MsgPeek*		= 2;
		MsgDontWait*	= 40H;		(* non blocking read *)
		
	(* shutdown *)
		ShutRDWR*	= 2;

	SockAddrSizeV4*	= 16;
	SockAddrSizeV6*	= 28;

	(*----------------------- seral line, cf Unix.V24.Mod -----------------------*)
	
	FIONREAD*	= 541BH;
	TIOCMGET*		= 5415H;
	TIOCMBIS*		= 5416H;
	TIOCMBIC*		= 5417H;
	TIOCMSET*		= 5418H;
	
	(* speeds *)
	B0*	= 0;
	B50*	= 1;
	B75*	= 2; 
	B110*	= 3; 
	B134*	= 4; 
	B150*	= 5; 
	B200*	= 6; 
	B300*	= 7; 
	B600*	= 8; 
	B1200* 	= 9; 
	B1800* 	= 10; 
	B2400* 	= 11; 
	B4800* 	= 12; 
	B9600* 	= 13; 
	B19200*	= 14; 
	B38400*	= 15; 

	B57600* 	= 1001H; 
	B115200*	= 1002H; 
	B230400*	= 1003H; 



	(* tio.cflag bits *)
	CSIZE*		= {4,5};
	   CS5*		= {};
	   CS6*		= {4};
	   CS7*		= {5};
	   CS8*		= {4,5};
	CSTOPB*	= {6};
	CREAD*	= {7};
	PARENB*	= {8};
	PARODD*	= {9};
	HUPCL*		= {10};
	CLOCAL*	= {11};
	
TYPE
	Termios* = RECORD
		iflags*, oflags*, cflags*, lflags*: SET;
		line*: CHAR;
		cc*	: ARRAY 32 OF CHAR;
		ispeed-, ospeed-: LONGINT
	END;

	(*------------------------------------------------------------------*)


TYPE
	DevT* = HUGEINT;

	Status* = RECORD
				dev-		: DevT;
				unused1-	: LONGINT;
				ino-		: LONGINT;
				mode-	: LONGINT;
				nlink-		: LONGINT;
				uid-		: LONGINT;
				gid-		: LONGINT;
				rdev-		: DevT;
				unused2-	: LONGINT;
				size-		: LONGINT;
				blksize-	: LONGINT;
				blocks-	: LONGINT;
				atime-	: Timeval;
				mtime-	: Timeval;
				ctime-	: Timeval;
				unused-	: ARRAY 2 OF LONGINT;
			END;

	Timeval* = RECORD
				sec*	: LONGINT;
				usec*	: LONGINT
			END;

	TmPtr* = POINTER TO Tm;
	Tm* = RECORD
				sec*, min*, hour*, mday*, mon*, year*, wday*, yday*, isdst*: LONGINT;
				gmtoff*, tmzone*: LONGINT;
			END;

	Tms* = POINTER TO RECORD
				utime*, stime*, cutime*, cstime*: LONGINT
			END;

	Timezone* = RECORD
				minuteswest*, dsttime*: LONGINT
			END;

	Itimerval* = RECORD
				interval*, value*: Timeval
			END;


CONST
	FdSetLen* = 32;
	
TYPE
	FdSet* = ARRAY FdSetLen OF SET;


	Dirent* = POINTER TO RECORD
				ino-, off-	: LONGINT;   (* these may change to HUGEINT in future Linux releases!! *)
				reclen-	: INTEGER;
				typ-		: CHAR;
				name-	: (*array of*) CHAR;
			END;

	Stack* = RECORD
				sp*		: ADDRESS;
				flags*		: SET;
				size*		: SIZE
			END;

	Ucontext* = POINTER TO UcontextDesc;
	UcontextDesc* = RECORD
				flags-		: SET;
				link-		: ADDRESS;
				stack-	: Stack;
				mc-		: McontextDesc
			END;

	Mcontext* = POINTER TO McontextDesc;
	McontextDesc* = RECORD
				r_gs-		: LONGINT;
				r_fs-		: LONGINT;
				r_es-		: LONGINT;
				r_ds-		: LONGINT;
				r_di-		: LONGINT;
				r_si-		: LONGINT;
				r_bp-		: LONGINT;
				r_sp_ -	: LONGINT;
				r_bx-		: LONGINT;
				r_dx-		: LONGINT;
				r_cx-		: LONGINT;
				r_ax-		: LONGINT;
				r_trapno-	: LONGINT;
				r_err-		: LONGINT;
				r_pc-		: LONGINT;
				r_cs-		: LONGINT;
				r_flags-	: LONGINT;
				r_sp-		: LONGINT;		(* sp at error (signal) *)
				r_ss-		: LONGINT;
				fpc-		: ADDRESS; 	(* FPcontext *)
				oldmask-	: LONGINT;
				cr2-		: LONGINT
			END;

	FPcontext* = POINTER TO FPcontextDesc;
	FPcontextDesc* = RECORD
				(* ... *)
			END;

	PThreadAttr = RECORD
		reserved1-: ARRAY 5 OF ADDRESS;
		reserved2-: ARRAY 4 OF WORD;
	END;

VAR
	argc-: LONGINT;  argv-: ADDRESS;
	aargc: ADDRESS;

	sysinfo-: RECORD
				sysname-, nodename-, release-, version-, machine-: ARRAY 65 OF CHAR;
			END;
			
	sigstack-: ARRAY 32*4096 OF CHAR;

	pthread_mutex_init: PROCEDURE {C} (mutex: ADDRESS; mutexattr: ADDRESS): WORD;
	pthread_mutex_destroy: PROCEDURE {C} (mutex: ADDRESS): WORD;
	pthread_mutex_lock: PROCEDURE {C} (mutex: ADDRESS): WORD;
	pthread_mutex_unlock: PROCEDURE {C} (mutex: ADDRESS): WORD;

	pthread_cond_init: PROCEDURE {C} (cond: ADDRESS; condAttr: ADDRESS): WORD;
	pthread_cond_destroy: PROCEDURE {C} (cond: ADDRESS): WORD;
	pthread_cond_wait: PROCEDURE {C} (cond: ADDRESS; mutex: ADDRESS): WORD;
	pthread_cond_signal: PROCEDURE {C} (cond: ADDRESS): WORD; 
	
	pthread_create: PROCEDURE {C} (newthread: ADDRESS; attr: ADDRESS; start_routine: PROCEDURE {C} (arg: PROCEDURE):ADDRESS; arg:PROCEDURE): WORD;
	pthread_exit: PROCEDURE {C} (thr: ADDRESS);
	pthread_detach: PROCEDURE {C} (thr: ADDRESS);
	pthread_kill: PROCEDURE {C} (thr: ADDRESS; sigid: LONGINT);
	pthread_cancel: PROCEDURE {C} (thr: ADDRESS);

	pthread_attr_init: PROCEDURE {C} (attr: ADDRESS);
	pthread_attr_setscope: PROCEDURE {C}(attr: ADDRESS; set: WORD);
	pthread_attr_setdetachstate: PROCEDURE {C}(attr: ADDRESS; set: WORD);
	pthread_attr_setstacksize: PROCEDURE {C}(attr: ADDRESS; stackSize: SIZE);
	pthread_self: PROCEDURE {C} (): Thread_t;

	sched_get_priority_max: PROCEDURE {C} (policy: LONGINT): LONGINT;
	sched_get_priority_min: PROCEDURE {C} (policy: LONGINT): LONGINT;
	pthread_setschedparam: PROCEDURE {C} (thread: Thread_t; policy: LONGINT; param: ADDRESS): WORD;
	pthread_getschedparam: PROCEDURE {C} (thread: Thread_t; policy: LONGINT; param: ADDRESS): WORD;
	pthread_setcancelstate: PROCEDURE {C} (state: LONGINT; oldstate: ADDRESS): LONGINT;
	pthread_setcanceltype: PROCEDURE {C} (type: LONGINT; oldtype: ADDRESS): LONGINT;
	sigaction: PROCEDURE {C} (signum: LONGINT; CONST act, oldact: ADDRESS): LONGINT;
	sigemptyset: PROCEDURE {C} (set: ADDRESS);
	sigfillset: PROCEDURE {C} (set: ADDRESS): LONGINT;
	sigsuspend: PROCEDURE {C} (set: ADDRESS): LONGINT;
	sigaddset: PROCEDURE {C} (set: ADDRESS; signo: LONGINT);
	sigdelset: PROCEDURE {C} (set: ADDRESS; signo: LONGINT);
	nanosleep: PROCEDURE {C} (req, rem: ADDRESS): LONGINT;
	sigaltstack: PROCEDURE {C} (ss, oss: ADDRESS): LONGINT; 
	pthread_sigmask: PROCEDURE {C}(how: LONGINT; set: ADDRESS; oldset: ADDRESS): LONGINT;
	
	read-			: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE ): LONGINT;
	write-			: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE ): LONGINT;
	open-			: PROCEDURE {C} ( name: ADDRESS;  flags, mode: SET ): LONGINT;
	close-		: PROCEDURE {C} ( fd: LONGINT ): LONGINT;
	lseek-		: PROCEDURE {C} ( fd: LONGINT; offset, origin: SIZE ): LONGINT;
	fsync-		: PROCEDURE {C} ( fd: LONGINT ): LONGINT;
	ioctl-			: PROCEDURE {C} ( fd: LONGINT; request: LONGINT; arg: ADDRESS ): LONGINT;
	unlink-		: PROCEDURE {C} ( name: ADDRESS ): LONGINT;
	rename-		: PROCEDURE {C} ( oldname, newname: ADDRESS ): LONGINT;
	ftruncate-		: PROCEDURE {C} ( fd: LONGINT;  length: SIZE ): LONGINT;
	chmod-		: PROCEDURE {C} ( name: ADDRESS;  mode: SET ): LONGINT;
	utime-		: PROCEDURE {C} ( name: ADDRESS;  tb: ADDRESS ): LONGINT;
	access-		: PROCEDURE {C} ( name: ADDRESS;  mode: SET ): LONGINT;
	select-		: PROCEDURE {C} ( width: LONGINT; rd, wr, ex: ADDRESS;  VAR timeout: Timeval ): LONGINT;

	chdir-			: PROCEDURE {C} ( name: ADDRESS ): LONGINT;
	mkdir-		: PROCEDURE {C} ( name: ADDRESS;  mode: SET ): LONGINT;
	rmdir-			: PROCEDURE {C} ( path: ADDRESS ): LONGINT;

	stat-			: PROCEDURE {C} ( name: ADDRESS;  VAR buf: Status ): LONGINT;
	lstat-			: PROCEDURE {C} ( name: ADDRESS;  VAR buf: Status ): LONGINT;
	fstat-			: PROCEDURE {C} ( fd: LONGINT;  VAR buf: Status ): LONGINT;

	getpid-		: PROCEDURE {C} ( ): LONGINT;
	getuid-		: PROCEDURE {C} ( ): LONGINT;

	malloc-		: PROCEDURE {C} ( size: SIZE ): ADDRESS;
	posix_memalign-	: PROCEDURE {C} ( VAR p: ADDRESS;  alignment, size: SIZE ): LONGINT;
	free-			: PROCEDURE {C} ( p: ADDRESS );
	mprotect-	: PROCEDURE {C} ( p: ADDRESS; len: SIZE; prot: LONGINT ): LONGINT;

	alarm-		: PROCEDURE {C} ( ms: LONGINT ): LONGINT;
	setitimer-		: PROCEDURE {C} ( which: LONGINT;  VAR value, ovalue: Itimerval ): LONGINT;
	getitimer-		: PROCEDURE {C} ( which: LONGINT;  VAR value: Itimerval ): LONGINT;

	gettimeofday-	: PROCEDURE {C} ( VAR tv: Timeval;  VAR tz: Timezone ): LONGINT;
	mktime-			: PROCEDURE {C} ( VAR tm: Tm ): LONGINT;
	localtime-		: PROCEDURE {C} ( CONST tv: Timeval ): TmPtr;
	time-				: PROCEDURE {C} ( VAR tv: Timeval ): LONGINT;
	times-			: PROCEDURE {C} ( VAR tms: Tms ): LONGINT;

	system-		: PROCEDURE {C} ( cmd: ADDRESS );
	uname-		: PROCEDURE {C} ( utsname: ADDRESS ): LONGINT;

	getcwd-		: PROCEDURE {C} ( buf: ADDRESS;  len: SIZE ): ADDRESS;
	getenv-		: PROCEDURE {C} ( name: ADDRESS ): ADDRESS;

	opendir-		: PROCEDURE {C} ( name: ADDRESS ): ADDRESS;
	readdir-		: PROCEDURE {C} ( dir: ADDRESS ): Dirent;
	closedir-		: PROCEDURE {C} ( dir: ADDRESS );

	sigsetjmp-	: PROCEDURE {C} ( env: ADDRESS;  savemask: LONGINT ): LONGINT;
	siglongjmp-	: PROCEDURE {C} ( env: ADDRESS;  val: LONGINT );

	kill-			: PROCEDURE {C} ( pid, sig: LONGINT ): LONGINT;
	exit-			: PROCEDURE {C} ( status: LONGINT );
	perror-		: PROCEDURE {C} ( msg: ADDRESS );
	errno-			: PROCEDURE {C} ( ): LONGINT;


	libc-: LONGINT;
	libp-: LONGINT;

	libraryPaths: ARRAY 8 OF ARRAY 32 OF CHAR;
	noPaths: LONGINT;






	(*
	mtxInit: 		PROCEDURE {REALTIME, C}  ( dummy: LONGINT ): Unix.Mutex_t;
	mtxDestroy: 	PROCEDURE {REALTIME, C}  ( mtx: Unix.Mutex_t );
	mtxLock: 		PROCEDURE {REALTIME, C}  ( mtx: Unix.Mutex_t );
	mtxUnlock:	PROCEDURE {REALTIME, C}  ( mtx: Unix.Mutex_t );

	conInit: 		PROCEDURE {REALTIME, C}  ( dummy: LONGINT ): Unix.Condition_t;
	conDestroy:	PROCEDURE {REALTIME, C}  ( cond: Unix.Condition_t );
	conWait: 		PROCEDURE {REALTIME, C}  ( cond: Unix.Condition_t;  mtx: Unix.Mutex_t );
	conSignal: 	PROCEDURE {REALTIME, C}  ( cond: Unix.Condition_t );
	
	thrStart: 			PROCEDURE {REALTIME, C} ( p: PROCEDURE;  stackLen: LONGINT ): Unix.Thread_t;
	thrThis: 			PROCEDURE {REALTIME, C} ( dummy: LONGINT ): Unix.Thread_t;
	thrSleep: 			PROCEDURE {REALTIME, C} ( ms: LONGINT );
	thrYield: 			PROCEDURE {REALTIME, C} ( dummy: LONGINT );
	thrExit: 			PROCEDURE {REALTIME, C} ( dummy: LONGINT );
	thrSuspend: 		PROCEDURE {REALTIME, C} ( t: Unix.Thread_t );
	thrResume: 		PROCEDURE {REALTIME, C} ( t: Unix.Thread_t );
	thrSetPriority: 	PROCEDURE {REALTIME, C} ( t: Unix.Thread_t;  prio: LONGINT );
	thrGetPriority: 	PROCEDURE {REALTIME, C} ( t: Unix.Thread_t ): LONGINT;
	thrKill: 			PROCEDURE {REALTIME, C} ( t: Unix.Thread_t );
	*)
	
	TYPE 

	PROCEDURE MtxInit*(dummy: LONGINT): Mutex_t;
	VAR 
		mtx: Mutex_t;
	BEGIN
		mtx := malloc(SIZEOF(MutexType));
		TRACE(mtx);
		ASSERT(mtx # 0);
		ASSERT(pthread_mutex_init(mtx, NIL) = 0);
		TRACE(mtx);
		RETURN mtx;
	END MtxInit;
	
	PROCEDURE MtxDestroy*(mtx: Mutex_t);
	BEGIN
		ASSERT(pthread_mutex_destroy(mtx) = 0);
	END MtxDestroy;

	PROCEDURE MtxLock*(mtx: Mutex_t);
	BEGIN
		ASSERT(pthread_mutex_lock(mtx) = 0);
	END MtxLock;

	PROCEDURE MtxUnlock*(mtx: Mutex_t);
	BEGIN
		ASSERT(pthread_mutex_unlock(mtx) = 0);
	END MtxUnlock;
	
	PROCEDURE ConInit* (dummy: LONGINT): Condition_t;
	VAR cond: Condition_t;
	BEGIN
		cond := malloc(SIZEOF(ConditionType));
		ASSERT(cond # 0);
		ASSERT(pthread_cond_init(cond, NIL)=0);
		RETURN cond;
	END ConInit;
	
	PROCEDURE ConDestroy*(con: Condition_t);
	BEGIN
		ASSERT(pthread_cond_destroy(con) = 0);
	END ConDestroy;

	PROCEDURE ConWait*(con: Condition_t; mtx: Mutex_t);
	BEGIN
		ASSERT(pthread_cond_wait(con, mtx) = 0);
	END ConWait;

	PROCEDURE ConSignal*(cond: Condition_t);
	BEGIN
		ASSERT(pthread_cond_signal(cond) = 0);
	END ConSignal;
	
	PROCEDURE ThrThis*(dummy: LONGINT): Thread_t;
	BEGIN
		RETURN pthread_self();
	END ThrThis;

	PROCEDURE ThrYield*(dummy: LONGINT);
	BEGIN
		ThrSleep(1);
	END ThrYield;

	PROCEDURE ThrExit*(dummy: LONGINT);
	BEGIN
		pthread_exit(0);
	END ThrExit;
	
	PROCEDURE ThrSetPriority*(thr: Thread_t; prio: LONGINT);
	VAR 
		param: Sched_param;
		policy: LONGINT;
	BEGIN
	    IF pthread_getschedparam( thr, ADDRESS OF policy, ADDRESS OF param ) # 0 THEN END;
	    param.sched_priority := prio;
	    IF pthread_setschedparam( thr, SCHED_OTHER, ADDRESS OF param ) # 0 THEN
	    	Perror("pthread_setschedparam");
	    END
	END ThrSetPriority;

	PROCEDURE ThrGetPriority*(thr: Thread_t):LONGINT;
	VAR 
		param: Sched_param;
		policy: LONGINT;
	BEGIN
	    IF pthread_getschedparam( thr, ADDRESS OF policy, ADDRESS OF param ) # 0 THEN END;
	    RETURN  param.sched_priority;
	END ThrGetPriority;
	
	VAR 
		sigstk: Stack;
	
	PROCEDURE SetSigaltstack;
	BEGIN
		IF sigaltstack(ADDRESS OF sigstk, NIL) < 0 THEN
			Perror("sigaltstack")
		END;
	END SetSigaltstack;
	
	PROCEDURE {C} Starter(proc: PROCEDURE): ADDRESS;
	VAR 
		me: Thread_t;
		
		old, new: Sigset_t;

		param: Sched_param;
		res: LONGINT;

	BEGIN
	 	TRACE("starter has started (self?)");
		me := pthread_self();
		SetSigaltstack();
		
	    IF sigfillset( ADDRESS OF new ) < 0 THEN
	    	Perror("sigfillset");
	    END;
	    TRACE(new[0],new[1]);
	    sigdelset( ADDRESS OF new, SIGILL );
	    sigdelset( ADDRESS OF new, SIGTRAP );
	    sigdelset( ADDRESS OF new, SIGFPE );
	    sigdelset( ADDRESS OF new, SIGBUS );
	    sigdelset( ADDRESS OF new, SIGSEGV );
	    sigdelset( ADDRESS OF new, SIGTERM );
	    sigdelset( ADDRESS OF new, T_SIGSUSPEND );
	    
	    res := pthread_sigmask( SIG_SETMASK, ADDRESS OF new, ADDRESS OF old );
		TRACE(res);
		TRACE(4,me);
	    res := pthread_setcancelstate( PTHREAD_CANCEL_ENABLE, NIL );
	    res := pthread_setcanceltype( PTHREAD_CANCEL_ASYNCHRONOUS, NIL );
		TRACE(res);
	    param.sched_priority := 0;
	    res := pthread_setschedparam( me, SCHED_OTHER, ADDRESS OF param );
		TRACE(proc);
	    proc();

	    pthread_exit( NIL );
	    RETURN NIL;
	END Starter;
	
	PROCEDURE ThrStart*(p: PROCEDURE; stackSize: SIZE): Thread_t;
	VAR 
		attr: PThreadAttr;
		id: Thread_t;
		res,i: LONGINT;
	CONST 
		PTHREAD_SCOPE_SYSTEM = 0;
		PTHREAD_CREATE_DETACHED = 1;
	BEGIN
		pthread_attr_init(ADDRESS OF attr);
		pthread_attr_setscope(ADDRESS OF attr, PTHREAD_SCOPE_SYSTEM);
		pthread_attr_setdetachstate(ADDRESS OF attr, PTHREAD_CREATE_DETACHED);
		pthread_attr_setstacksize(ADDRESS OF attr, stackSize);
		TRACE(p);
		res := pthread_create(ADDRESS OF id, ADDRESS OF attr, Starter, p);
		RETURN id;
	END ThrStart;

	PROCEDURE ThrSleep*(ms: LONGINT);
	VAR
		sltime,rem: RECORD
			tv_sec: WORD;        (* seconds *)
            tv_nsec: WORD;       (* nanoseconds *)
         END;
	BEGIN
		sltime.tv_sec := ms DIV 1000;
		sltime.tv_nsec := 1000000*(ms MOD 1000);
		WHILE (nanosleep(ADDRESS OF sltime, ADDRESS OF rem) < 0) DO
			(* check error ! *)
			sltime := rem;
		END;
	END ThrSleep;
	
	PROCEDURE ThrKill*(thr: Thread_t);
	BEGIN
	    IF (thr # mainthread) THEN
	    	pthread_detach( thr );
	    	IF (thr = pthread_self()) THEN
	    	    pthread_exit( 0 );
			ELSE
	    	    pthread_cancel( thr );
	        END
	    END;  
    END ThrKill;
	
	


PROCEDURE {C} resume_handler(sig: LONGINT);
BEGIN
END resume_handler;

PROCEDURE ThrResume*(thr: Thread_t);
VAR n: LONGINT; res: LONGINT;
BEGIN
    res := pthread_mutex_lock( ADDRESS OF suspend_mutex );
    resume_done := 0; n := 1;
    pthread_kill( thr, T_SIGRESUME ); 
    WHILE (resume_done # 1) & (n < 50) DO ThrSleep(1); INC(n) END; 
    res := pthread_mutex_unlock( ADDRESS OF suspend_mutex );
END ThrResume;

PROCEDURE {C} suspend_handler(sig: LONGINT);
VAR block: Sigset_t; res: LONGINT;
BEGIN

    res := sigfillset( ADDRESS OF block );
    sigdelset(  ADDRESS OF block, T_SIGRESUME );
    suspend_done := 1;

    res := sigsuspend(  ADDRESS OF block ); (* await T_SIGRESUME *)

    resume_done := 1;
END suspend_handler;

PROCEDURE ThrSuspend*(thr: Thread_t);
VAR res: LONGINT;
BEGIN
    res := pthread_mutex_lock(ADDRESS OF suspend_mutex );
    suspend_done := 0;
    pthread_kill( thr, T_SIGSUSPEND );
    WHILE (suspend_done # 1) DO ThrSleep( 1 ) END;
    res := pthread_mutex_unlock( ADDRESS OF suspend_mutex );
END ThrSuspend;


TYPE
	Sigaction = RECORD
		sa_handler: ADDRESS;
		sa_mask: Sigset_t;
		sa_flags: ADDRESS;
		filler: ADDRESS;
	END;
	
	Sched_param = RECORD
		sched_priority: LONGINT;
		safety: ARRAY 8 OF ADDRESS; 
	END;
	
VAR 
	suspend_mutex: MutexType;
	mainthread: Thread_t;
	suspend_done: LONGINT;
	resume_done: LONGINT;


	sasuspend, saresume: Sigaction;

	PROCEDURE ThrInitialize*(VAR low, high: LONGINT): BOOLEAN;
	VAR
		param: Sched_param;
		BEGIN
	    (*struct sched_param param;*)
	    
		ASSERT(pthread_mutex_init( ADDRESS OF suspend_mutex, NIL ) = 0);
	    mainthread := pthread_self();
	    TRACE(mainthread);
	    high := sched_get_priority_max(SCHED_OTHER);
	    low := sched_get_priority_min(SCHED_OTHER);
	    TRACE(low, high);
	    
	    param.sched_priority := high;
		IF pthread_setschedparam( mainthread, SCHED_OTHER, ADDRESS OF param)#0 THEN
			Perror("ThrInitialize: setparam");
		END;
		
	    TRACE(ADDRESS OF sasuspend.sa_mask);

	    sigemptyset( ADDRESS OF sasuspend.sa_mask );
	    sigaddset(  ADDRESS OF sasuspend.sa_mask, T_SIGRESUME );
	    sasuspend.sa_flags := 0;
	    sasuspend.sa_handler := suspend_handler;
	    ASSERT(sigaction( T_SIGSUSPEND, ADDRESS OF sasuspend, NIL ) = 0);

	    sigemptyset( ADDRESS OF saresume.sa_mask );
	    saresume.sa_flags := 0;
	    saresume.sa_handler := resume_handler;
	    ASSERT(sigaction( T_SIGRESUME, ADDRESS OF saresume, NIL ) = 0);

	    RETURN TRUE;
	END ThrInitialize;


	PROCEDURE ModifyContext*( cont: Ucontext;  pc, bp, sp: LONGINT );
	BEGIN
		cont.mc.r_pc := pc;
		cont.mc.r_bp := bp;
		cont.mc.r_sp := sp;
	END ModifyContext;

	PROCEDURE Perror*( CONST msg: ARRAY OF CHAR );
	BEGIN
		perror( ADDRESSOF( msg ) )
	END Perror;

	PROCEDURE Dlsym*( lib: ADDRESS;  CONST sym: ARRAY OF CHAR;  objAddr: ADDRESS );
	VAR val: LONGINT;
	BEGIN
		Glue.Dlsym( lib, sym, objAddr );
		S.GET( objAddr, val );
		IF val = 0 THEN
			Trace.String( "Unix.Dlsym:  entry '" );  Trace.String( sym );  Trace.String( "' not found" );
			Trace.Ln;
			LOOP END;
		ELSE
			Trace.String( "Unix.Dlsym found " );  Trace.String( sym ); 
			Trace.Ln
		END
	END Dlsym;

	PROCEDURE Dlopen*( CONST libname: ARRAY OF CHAR;  mode: LONGINT ): ADDRESS;
	VAR h: ADDRESS;  i, j, k: INTEGER;
		p: ARRAY 256 OF CHAR;
	BEGIN
		IF libname[0] = '/' THEN  h := Glue.dlopen( ADDRESSOF( libname ), mode );
		ELSE
			i := 0;  h := 0;
			WHILE (h = 0) & (i < noPaths) DO
				COPY( libraryPaths[i], p );  j := 0;
				WHILE p[j] # 0X DO  INC( j )  END;
				p[j] := '/';  k := 0;
				REPEAT  INC( j );  p[j] := libname[k];  INC( k )  UNTIL p[j] = 0X;
				h := Glue.dlopen( ADDRESSOF( p ), mode );  INC( i )
			END
		END;
		IF h = 0 THEN
			Trace.String( "Unix.Dlopen: loading library " );
			Trace.String( libname );  Trace.String( " failed" );  Trace.Ln;
			LOOP END;
		END;
		RETURN h
	END Dlopen;

	PROCEDURE Dlclose*( lib: ADDRESS );
	BEGIN
		Glue.dlclose( lib )
	END Dlclose;

	PROCEDURE GetArg*( no: LONGINT;  VAR val: ARRAY OF CHAR );
	VAR ch: CHAR;  adr: ADDRESS;  i: LONGINT;
	BEGIN
		IF no >= argc THEN  val[0] := 0X
		ELSE
			S.GET( argv + SIZEOF(ADDRESS)*no, adr );  i := 0;
			REPEAT  S.GET( adr, ch );  val[i] := ch;  INC( adr );  INC( i );   UNTIL (ch = 0X) OR (i >= LEN( val ));
		END
	END GetArg;

	PROCEDURE GetArgval*(  CONST argName: ARRAY OF CHAR;  VAR val: ARRAY OF CHAR );
	VAR i: INTEGER;
		buf: ARRAY 40 OF CHAR;
	BEGIN
		i := 1;
		WHILE i < argc - 1 DO
			GetArg( i, buf );
			IF buf = argName THEN  GetArg( i + 1, val );  RETURN   END;
			INC( i )
		END;
		val[0] := 0X
	END GetArgval;


	PROCEDURE getSysinfo;
	VAR res: LONGINT;  p: INTEGER;
		buf: ARRAY 4096 OF CHAR;

		PROCEDURE copy( VAR p: INTEGER;  VAR dest: ARRAY OF CHAR );
		VAR i: INTEGER;
		BEGIN
			WHILE buf[p] <= ' ' DO  INC( p )  END;
			i := 0;
			REPEAT  dest[i] := buf[p];  INC( i );  INC( p )  UNTIL (buf[p - 1] = 0X) OR (i >= LEN( dest ));
			dest[i - 1] := 0X
		END copy;

	BEGIN
		FOR p := 0 TO 4096 - 1 DO  buf[p] := 0X  END;
		res := uname( ADDRESSOF( buf ) );
		p := 0;
		copy( p, sysinfo.sysname );
		copy( p, sysinfo.nodename );
		copy( p, sysinfo.release );
		copy( p, sysinfo.version );
		copy( p, sysinfo.machine );
	END getSysinfo;
	
	PROCEDURE Init;
	VAR test: ADDRESS; 
	BEGIN
		TRACE("Unix init start");
		(*
		Dlsym( 0, "argc", ADDRESSOF( aargc ) );  
		IF aargc # NIL THEN
			S.GET( aargc, argc );
		END;
		Dlsym( 0, "argv", ADDRESSOF( argv ) );
		*)

		libraryPaths[0] := "/lib/i386-linux-gnu";
		libraryPaths[1] := "/usr/lib/i386-linux-gnu";
		libraryPaths[2] := "/lib";
		libraryPaths[3] := "/usr/lib";
		noPaths := 4;

		libc := Dlopen( libcname, 2 );
		libp := Dlopen( libpthreadname, 2); 
		

		Dlsym( libc, "pthread_mutex_init", ADDRESSOF(pthread_mutex_init));
		Dlsym( libc, "pthread_mutex_destroy", ADDRESSOF(pthread_mutex_destroy));
		Dlsym( libc, "pthread_mutex_lock", ADDRESSOF(pthread_mutex_lock));
		Dlsym( libc, "pthread_mutex_unlock", ADDRESSOF(pthread_mutex_unlock));
		
		Dlsym( libc, "pthread_cond_init", ADDRESSOF(pthread_cond_init));
		Dlsym( libc, "pthread_cond_destroy", ADDRESSOF(pthread_cond_destroy));
		Dlsym( libc, "pthread_cond_wait", ADDRESSOF(pthread_cond_wait));
		Dlsym( libc, "pthread_cond_signal", ADDRESSOF(pthread_cond_signal));

		Dlsym( libp, "pthread_create", ADDRESSOF(pthread_create));
		Dlsym( libp, "pthread_exit", ADDRESSOF(pthread_exit));
		Dlsym( libp, "pthread_detach", ADDRESSOF(pthread_detach));
		Dlsym( libp, "pthread_cancel", ADDRESSOF(pthread_cancel));
		Dlsym( libp, "pthread_kill", ADDRESSOF(pthread_kill));

		Dlsym( libp, "pthread_sigmask", ADDRESSOF(pthread_sigmask));
		Dlsym( libp, "pthread_setcancelstate", ADDRESSOF(pthread_setcancelstate));
		Dlsym( libp, "pthread_setcanceltype", ADDRESSOF(pthread_setcanceltype));
		Dlsym( libp, "pthread_attr_init", ADDRESSOF(pthread_attr_init));
		Dlsym( libp, "pthread_attr_setscope", ADDRESSOF(pthread_attr_setscope));
		Dlsym( libp, "pthread_attr_setdetachstate", ADDRESSOF(pthread_attr_setdetachstate));
		Dlsym( libp, "pthread_attr_setstacksize", ADDRESSOF(pthread_attr_setstacksize));
		Dlsym( libp, "pthread_self", ADDRESSOF(pthread_self));
		
		Dlsym( libc, "sched_get_priority_max", ADDRESSOF(sched_get_priority_max));
		Dlsym( libc, "sched_get_priority_min", ADDRESSOF(sched_get_priority_min));
		Dlsym( libc, "pthread_setschedparam", ADDRESSOF(pthread_setschedparam));
		Dlsym( libc, "pthread_getschedparam", ADDRESSOF(pthread_getschedparam));
		Dlsym( libc, "sigaction", ADDRESSOF(sigaction));
		Dlsym( libc, "sigemptyset", ADDRESSOF(sigemptyset));
		Dlsym( libc, "sigfillset", ADDRESSOF(sigfillset));
		Dlsym( libc, "sigaddset", ADDRESSOF(sigaddset));
		Dlsym( libc, "sigdelset", ADDRESSOF(sigdelset));
		Dlsym( libc, "nanosleep", ADDRESSOF(nanosleep));
		Dlsym( libc, "sigaltstack", ADDRESSOF(sigaltstack));
		Dlsym( libc, "sigsuspend", ADDRESSOF(sigsuspend));
				
		(*
		Dlsym( libc, "putc", ADDRESSOF(test));
		*)
		
		Dlsym( libc, "read",		ADDRESSOF( read ) );
		Dlsym( libc, "write",	ADDRESSOF( write ) );
		Dlsym( libc, "open",		ADDRESSOF( open ) );
		Dlsym( libc, "close",	ADDRESSOF( close ) );
		Dlsym( libc, "lseek",	ADDRESSOF( lseek ) );
		Dlsym( libc, "fsync",	ADDRESSOF( fsync ) );
		Dlsym( libc, "ioctl",	ADDRESSOF( ioctl ) );
		Dlsym( libc, "unlink",	ADDRESSOF( unlink ) );
		Dlsym( libc, "rename",	ADDRESSOF( rename ) );
		Dlsym( libc, "ftruncate",	ADDRESSOF( ftruncate ) );
		Dlsym( libc, "chmod",	ADDRESSOF( chmod ) );
		Dlsym( libc, "utime",	ADDRESSOF( utime ) );
		Dlsym( libc, "access",	ADDRESSOF( access ) );
		Dlsym( libc, "select",	ADDRESSOF( select ) );

		Dlsym( libc, "chdir",	ADDRESSOF( chdir ) );
		Dlsym( libc, "mkdir",	ADDRESSOF( mkdir ) );
		Dlsym( libc, "rmdir",	ADDRESSOF( rmdir ) );

		(*
		Dlsym( libc, "stat",		ADDRESSOF( stat ) );
		Dlsym( libc, "lstat",	ADDRESSOF( lstat ) );
		Dlsym( libc, "fstat",	ADDRESSOF( fstat ) );
		*)

		Dlsym( libc, "getpid",	ADDRESSOF( getpid ) );
		Dlsym( libc, "getuid",	ADDRESSOF( getuid ) );

		Dlsym( libc, "alarm",	ADDRESSOF( alarm ) );
		Dlsym( libc, "setitimer",	ADDRESSOF( setitimer ) );
		Dlsym( libc, "getitimer",	ADDRESSOF( getitimer ) );

		Dlsym( libc, "gettimeofday", ADDRESSOF( gettimeofday ) );
		Dlsym( libc, "mktime",		ADDRESSOF( mktime ) );
		Dlsym( libc, "localtime",	ADDRESSOF( localtime ) );
		Dlsym( libc, "time",			ADDRESSOF( time ) );
		Dlsym( libc, "times",		ADDRESSOF( times ) );

		Dlsym( libc, "getcwd",		ADDRESSOF( getcwd ) );
		Dlsym( libc, "getenv",		ADDRESSOF( getenv ) );

		Dlsym( libc, "opendir",		ADDRESSOF( opendir ) );
		Dlsym( libc, "readdir",		ADDRESSOF( readdir ) );
		Dlsym( libc, "closedir",	ADDRESSOF( closedir ) );


		(*Dlsym( libp, "sigsetjmp",	ADDRESSOF( sigsetjmp ) );*)
		(*Dlsym( libc, "siglongjmp",	ADDRESSOF( siglongjmp ) );*)


		Dlsym( libc, "malloc",		ADDRESSOF( malloc ) );
		Dlsym( libc, "posix_memalign",	ADDRESSOF( posix_memalign ) );
		Dlsym( libc, "free",			ADDRESSOF( free ) );
		Dlsym( libc, "mprotect",	ADDRESSOF( mprotect ) );

		Dlsym( libc, "system",	ADDRESSOF( system ) );
		Dlsym( libc, "uname",	ADDRESSOF( uname ) );

		Dlsym( libc, "kill",		ADDRESSOF( kill ) );
		Dlsym( libc, "exit",		ADDRESSOF( exit ) );
		Dlsym( libc, "perror",	ADDRESSOF( perror ) );
		Dlsym( libc, "errno",	ADDRESSOF( errno ) );

		getSysinfo;
		
		sigstk.sp := ADDRESS OF sigstack;
		sigstk.size := LEN(sigstack);
		sigstk.flags := {};
		
		TRACE("Unix init end");
	END Init;

	PROCEDURE {INITIAL} Init0;
	BEGIN
		Init;
	END Init0;
END Unix.
