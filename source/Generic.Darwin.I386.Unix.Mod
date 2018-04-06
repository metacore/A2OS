MODULE Unix;   (* Josef Templ, 5.3.90	SVR4 system calls *)  (** Linux x86 version, non portable *)

(* Linux PPC version	g.f. 18.04.98	*)
(* Linux x86 version	g.f 10.11.99 	*)
(*	2000.09.19	g.f.	'Sigaltstack' added	*)
(*	2002.06.27	g.f.	TmDesc fixed,  new: Utime, Mktime *)
(*	2006.07.31	g.f.	shared memory support added *)
(*	2007.04.13	g.f.	Thread priorities added *)

IMPORT S := SYSTEM, Glue, Trace;


CONST
	Version* = "Darwin";

	libcname* = "libc.dylib";
	libX11name* = "libX11.dylib";
	libpthreadname = "libpthread.dylib";

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
	SCHED_FIFO = 1;
	SCHED_RR = 2;


	SIGHUP*		= 1;	(* hangup *)
	SIGINT*		= 2;	(* interrupt *)
	SIGQUIT*	= 3;	(* quit *)
	SIGILL	*		= 4;	(* illegal instruction (not reset when caught) *)
	SIGTRAP*	= 5;	(* trace trap (not reset when caught) *)
	SIGABRT*	= 6;	(* abort() *)
	SIGIOT*		= SIGABRT;	(* compatibility *)
	SIGEMT*		= 7;	(* EMT instruction *)
	SIGFPE*		= 8;	(* floating point exception *)
	SIGKILL*		= 9;	(* kill (cannot be caught or ignored) *)
	SIGBUS*		= 10;	(* bus error *)
	SIGSEGV	*	= 11;	(* segmentation violation *)
	SIGSYS*		= 12;	(* bad argument to system call *)
	SIGPIPE*	= 13;	(* write on a pipe with no one to read it *)
	SIGALRM	*	= 14;	(* alarm clock *)
	SIGTERM	*	= 15;	(* software termination signal from kill *)
	SIGURG*		= 16;	(* urgent condition on IO channel *)
	SIGSTOP*	= 17;	(* sendable stop signal not from tty *)
	SIGTSTP*	= 18;	(* stop signal from tty *)
	SIGCONT*	= 19;	(* continue a stopped process *)
	SIGCHLD*	= 20;	(* to parent on child stop or exit *)
	SIGTTIN*		= 21;	(* to readers pgrp upon background tty read *)
	SIGTTOU*	= 22;	(* like TTIN for output if (tp->t_local&LTOSTOP) *)
	SIGIO*		= 23;	(* input/output possible signal *)
	SIGXCPU*	= 24;	(* exceeded CPU time limit *)
	SIGXFSZ*	= 25;	(* exceeded file size limit *)
	SIGVTALRM*= 26;	(* virtual time alarm *)
	SIGPROF*	= 27;	(* profiling time alarm *)
	SIGWINCH*	= 28;	(* window size changes *)
	SIGINFO*	= 29;	(* information request *)
	SIGUSR1*	= 30;	(* user d signal 1 *)
	SIGUSR2*	= 31;	(* user d signal 2 *)

	SIG_BLOCK		= 1;
	SIG_UNBLOCK	= 2;
	SIG_SETMASK	= 3;
	
	SA_ONSTACK		= 0x0001;	(* take signal on signal stack *)
	SA_RESTART		= 0x0002;	(* restart system on signal return *)
	SA_RESETHAND	= 0x0004;	(* reset to SIG_DFL when taking signal *)
	SA_NOCLDSTOP	= 0x0008;	(* do not generate SIGCHLD on child stop *)
	SA_NODEFER		= 0x0010;	(* don't mask the signal we're delivering *)
	SA_NOCLDWAIT	= 0x0020;	(* don't keep zombies around *)
	SA_SIGINFO			= 0x0040;	(* signal handler with SA_SIGINFO args *)

	PTHREAD_CREATE_JOINABLE	= 1;
	PTHREAD_CREATE_DETACHED	= 2;
	
	PTHREAD_CANCEL_ENABLE 	= 1;
	PTHREAD_CANCEL_DISABLE	= 0;

	PTHREAD_CANCEL_ASYNCHRONOUS	= 0;
	PTHREAD_CANCEL_DEFERRED	= 2;
	
	PTHREAD_SCOPE_SYSTEM		= 1;
	PTHREAD_SCOPE_PROCESS	= 2;

	(*--------------------------- Threads -------------------------------*)

TYPE
	MachPort = LONGINT;
	
	Thread_t* = ADDRESS;
	Mutex_t* = ADDRESS;
	Condition_t* = ADDRESS;
	
	PThreadAttrType		= ARRAY 40 OF CHAR; 	(* 64bit: 64*)
	MutexType			= ARRAY 44 OF CHAR;	(* 64bit: 64 *)
	MutexAttributeType	= ARRAY 12 OF CHAR;	(* 64bit: 16 *)
	ConditionType		= ARRAY 28 OF CHAR;	(* 64bit: 48 *)

	Key_t* = ADDRESS;
	
	Sigset = ARRAY 4 OF CHAR;
	SignalTrap = PROCEDURE ( sig: LONGINT; mc: Mcontext );
	
	pid_t*		= LONGINT;
	path_t*	= ARRAY OF CHAR;
	arg_t*		= ARRAY OF CHAR;
	argv_t*	= ARRAY OF arg_t;
	off_t*		= HUGEINT;


CONST
	(* Thread priorities *)
	ThreadLow* = 15; ThreadNormal* = 20; ThreadHigh* = 47;	
	NumPriorities* = 33;	(* number of priority levels *)

	(*---------------------------- IP -----------------------------------*)

CONST
	(* domain *)
		AFINET*		= 2;
		AFINET6*	= 26;
		
		PFINET*		= AFINET;
		PFINET6*	= AFINET6;
		
	(* types of connection *)
		SockStream*	= 1;
		SockDGram*	= 2;
		
	(* Protocols *)
		IpProtoUDP*		= 17;
		IpProtoTCP*		= 6;

	(* setsockopt *)
		SoLSocket*		= 0FFFFH;	(* socket option level *)
		SoLinger* 		= 80H; 	(* linger (gracefully close the connection)*)
		SoKeepAlive*	= 8;		(* keep connection alive *)
		SoNoDelay*		= 1;		(* no delay *)

	(* ioctl *)
		FioNRead*		= 4004667FH;	(* something to read ? *)
		
		
	(* recv *)
		MsgPeek*		= 2;
		MsgDontWait*	= 80H;		(* non blocking read *)
		
	(* shutdown *)
		ShutRDWR*	= 2;

	SockAddrSizeV4*	= 16;
	SockAddrSizeV6*	= 28;

	
	(*-------------------seral line ---------------------------------------*)
	
	FIONREAD*	= 4004667FH;
	TIOCMGET*		= LONGINT( 4004746AH );
	TIOCMBIC*		= LONGINT( 8004746BH );
	TIOCMBIS*		= LONGINT( 8004746CH );
	TIOCMSET*		= LONGINT( 8004746DH );
	
	(* speeds *)
	B0*	= 0;
	B50*	= 50;
	B75*	= 75;
	B110*	= 110;
	B134*	= 134;
	B150*	= 150;
	B200*	= 200;
	B300*	= 300;
	B600*	= 600;
	B1200*		= 1200;
	B1800*		= 1800;
	B2400*		= 2400;
	B4800*		= 4800;
	B9600*		= 9600;
	B19200*	= 19200;
	B38400*	= 38400;

	B57600*	= 57600;
	B115200*	= 115200;
	B230400*	= 230400;


	(* tio.cflag bits *)
	CSIZE*		= {8,9};	(* character size mask *)
	   CS5*		= {};  	(* 5 bits (pseudo) *)
	   CS6*		= {8}; 	(* 6 bits *)
	   CS7*		= {9}; 	(* 7 bits *)
	   CS8*		= {8,9};	(* 8 bits *)
	CSTOPB*	= {10};	(* send 2 stop bits *)
	CREAD*	= {11};	(* enable receiver *)
	PARENB*	= {12};	(* parity enable *)
	PARODD*	= {13};	(* odd parity, else even *)
	HUPCL*		= {14};	(* hang up on last close *)
	CLOCAL*	= {15};	(* ignore modem status lines *)
	
TYPE
	Termios* = RECORD
		iflags*, oflags*, cflags*, lflags*: SET;
		cc*: ARRAY 20 OF CHAR;
		ispeed-, ospeed-: LONGINT
	END;


	(*------------------------------------------------------------------*)


TYPE
	DevT* = LONGINT;

	Status* = RECORD
				dev-		: DevT;
				ino-		: LONGINT;
				mode-	: INTEGER;
				nlink-		: INTEGER;
				uid-		: LONGINT;
				gid-		: LONGINT;
				rdev-		: DevT;
				atime-	: Timeval;
				mtime-	: Timeval;
				ctime-	: Timeval;
				size-		: LONGINT;
				size2-	: LONGINT;
				blocks-	: HUGEINT;
				blksize-	: LONGINT;
				flags-		: LONGINT;
				gen-		: LONGINT;
				lspare-	: LONGINT;
				qspare-	: ARRAY 4 OF LONGINT
			END;

	tvPtr* = POINTER TO Timeval;
	Timeval* = RECORD
				sec*		: LONGINT;
				usec*		: LONGINT
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
				ino-		: LONGINT;
				reclen-	: INTEGER;
				typ-		: SHORTINT;
				namlen-	: SHORTINT;
				name-	:  (*array of*) CHAR;
			END;
			
			

	Stack* = RECORD
				sp*		: ADDRESS;
				size*		: SIZE;
				flags*		: SET;
			END;

	Ucontext* = POINTER TO UcontextDesc;
	UcontextDesc* = RECORD
				onstack-	: LONGINT;
				sigmask-	: LONGINT;
				stack-	: Stack;
				link-		: ADDRESS;	(* Ucontext *)
				mclen-	: SIZE;
				mc-{UNTRACED}: Mcontext 
			END;

	Mcontext* = POINTER TO McontextDesc;
	McontextDesc* = RECORD
				r_trapno-		: LONGINT;
				r_err-			: LONGINT;
				r_faultvaddr-	: ADDRESS;
				r_ax-			: ADDRESS;
				r_bx-			: ADDRESS;
				r_cx-			: ADDRESS;
				r_dx-			: ADDRESS;
				r_di-			: ADDRESS;
				r_si-			: ADDRESS;
				r_bp*			: ADDRESS;
				r_sp*			: ADDRESS;
				r_ss-			: ADDRESS;
				r_flags-		: ADDRESS;
				r_pc*			: ADDRESS;
				r_cs-			: ADDRESS;
				r_ds-			: ADDRESS;
				r_es-			: ADDRESS;
				r_fs-			: ADDRESS;
				r_gs-			: ADDRESS;
				
				flavor-			: LONGINT;
				count-		: LONGINT;
				fpc-			: FPcontextDesc;
			END;

	FPcontext* = POINTER TO FPcontextDesc;
	FPcontextDesc* = RECORD
				fpsate*: ARRAY 100 OF LONGINT;
			END;

			

	Sigaction = RECORD	
		sa_handler: ADDRESS;
		sa_mask: Sigset;
		sa_flags: LONGINT;
	END;

	Sched_param = RECORD	
		sched_priority: LONGINT;
		safety: ARRAY 8 OF LONGINT;
	END;


VAR
	mainthread: Thread_t;
	handler_done: BOOLEAN;

	argc-: LONGINT;  argv-: ADDRESS;  environ-: ADDRESS;

	sysinfo-: RECORD
		sysname-, nodename-, release-, version-, machine-: ARRAY 65 OF CHAR;
	END;

	sigstack-: ARRAY 32*4096 OF CHAR;


	sysconf: PROCEDURE {C} (name: LONGINT):WORD;

	pthread_mutex_init: PROCEDURE {C} (mutex: ADDRESS; mutexattr: ADDRESS): WORD;
	pthread_mutex_destroy: PROCEDURE {C} (mutex: ADDRESS): WORD;
	pthread_mutex_lock: PROCEDURE {C} (mutex: ADDRESS): WORD;
	pthread_mutex_unlock: PROCEDURE {C} (mutex: ADDRESS): WORD;

	pthread_mutexattr_init: PROCEDURE {C} (mutexattr: ADDRESS): WORD;
	pthread_mutexattr_settype: PROCEDURE {C} (mutexattr: ADDRESS; type: WORD): WORD;

	pthread_cond_init: PROCEDURE {C} (cond: ADDRESS; condAttr: ADDRESS): WORD;
	pthread_cond_destroy: PROCEDURE {C} (cond: ADDRESS): WORD;
	pthread_cond_wait: PROCEDURE {C} (cond: ADDRESS; mutex: ADDRESS): WORD;
	pthread_cond_signal: PROCEDURE {C} (cond: ADDRESS): WORD;

	pthread_create: PROCEDURE {C} (newthread: ADDRESS; attr: ADDRESS; start_routine: PROCEDURE {C} (arg: PROCEDURE):ADDRESS; arg:PROCEDURE): WORD;
	pthread_exit: PROCEDURE {C} (thr: ADDRESS);
	pthread_detach: PROCEDURE {C} (thr: ADDRESS);
	pthread_kill: PROCEDURE {C} (thr: ADDRESS; sigid: LONGINT): LONGINT;
	pthread_cancel: PROCEDURE {C} (thr: ADDRESS);
	
	pthread_key_create	: PROCEDURE {C} ( key: ADDRESS; destructor: PROCEDURE {C} ( param: ADDRESS ) ): WORD;
	pthread_setspecific	: PROCEDURE {C} ( key: Key_t; value: ADDRESS ): WORD;
	pthread_getspecific	: PROCEDURE {C} ( key: Key_t ): ADDRESS;

	pthread_attr_init: PROCEDURE {C} (attr: ADDRESS);
	pthread_attr_setscope: PROCEDURE {C}(attr: ADDRESS; set: WORD);
	pthread_attr_setdetachstate: PROCEDURE {C}(attr: ADDRESS; set: WORD);
	pthread_attr_setstacksize: PROCEDURE {C}(attr: ADDRESS; stackSize: SIZE);
	pthread_self: PROCEDURE {C} (): Thread_t;
	
	pthread_mach_thread_np: PROCEDURE {C} ( thr: Thread_t ): MachPort;
	thread_suspend:	PROCEDURE {C} ( mthr: MachPort );
	thread_resume:	PROCEDURE {C} ( mthr: MachPort );
	sched_get_priority_max		: PROCEDURE {C} ( policy: LONGINT ): LONGINT;
	sched_get_priority_min		: PROCEDURE {C} ( policy: LONGINT ): LONGINT;
	
	pthread_setschedparam 	: PROCEDURE {C} ( thread: Thread_t; policy: LONGINT; param: ADDRESS ): LONGINT;
	pthread_getschedparam	 	: PROCEDURE {C} ( thread: Thread_t; policy: ADDRESS; param: ADDRESS ): LONGINT;
	pthread_setcancelstate		: PROCEDURE {C} ( state: LONGINT; oldstate: ADDRESS ): LONGINT;
	pthread_setcanceltype		: PROCEDURE {C} ( type: LONGINT; oldtype: ADDRESS ): LONGINT;
	pthread_sigmask 			: PROCEDURE {C} ( how: LONGINT; set: ADDRESS; oldset: ADDRESS ): LONGINT;
	
	sigaction		: PROCEDURE {C} (signum: LONGINT; CONST act, oldact: ADDRESS): LONGINT;
	sigemptyset	: PROCEDURE {C} (set: ADDRESS);
	sigfillset		: PROCEDURE {C} (set: ADDRESS): LONGINT;
	sigsuspend	: PROCEDURE {C} (set: ADDRESS): LONGINT;
	sigaddset		: PROCEDURE {C} (set: ADDRESS; signo: LONGINT);
	sigdelset		: PROCEDURE {C} (set: ADDRESS; signo: LONGINT);
	nanosleep		: PROCEDURE {C} (req, rem: ADDRESS): LONGINT;
	sigaltstack	: PROCEDURE {C} (ss, oss: ADDRESS): LONGINT;
	

	(*pid: return param for process id. Only set if initialized non-null. path: pointer to string denoting the executable. file_actions: modify which files are open for the new process, if NIL it inherits open files from parent process. attrp: sets process groups, scheduler, signals etc, leave NIL. argv, evp: char** to the arguments and env. variables*)
	posix_spawnp- 	: PROCEDURE {C}(pid: ADDRESS; path: ADDRESS; file_actions: ADDRESS; attrp: ADDRESS; argv: ADDRESS ; envp: ADDRESS): LONGINT;
	(*more restrictive than spawnp*)
	posix_spawn- 	: PROCEDURE {C} (pid: ADDRESS; path: ADDRESS; file_actions: ADDRESS; attrp: ADDRESS; argv: ADDRESS ; envp: ADDRESS): LONGINT;
	waitpid-			: PROCEDURE {C} (pid: pid_t; status: ADDRESS; options: LONGINT): pid_t;
	pipe-				: PROCEDURE {C} (pipefd: ADDRESS): LONGINT; (*pipefd is assumed to be a pointer to a C array of 2 elements, after pipe creation the array will contain file descriptors for the input and output end of the pipe. returns 0 on success, or -1 on fail*)
	dup2-				: PROCEDURE {C} (oldfd,newfd: LONGINT): LONGINT; (*overwrites file descriptor newfd with a copy of oldfd. useful for redirecting pipes.*)
	dup-				: PROCEDURE {C} (oldfd: LONGINT): LONGINT;

	read-			: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE ): SIZE;
	pread-		: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE; pos: off_t ): SIZE;
	write-			: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE ): SIZE;
	pwrite-		: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE; pos: off_t ): SIZE;
	open-			: PROCEDURE {C} ( name: ADDRESS;  flags, mode: SET ): LONGINT;
	close-		: PROCEDURE {C} ( fd: LONGINT ): LONGINT;
	lseek-		: PROCEDURE {C} ( fd: LONGINT; offset: off_t; origin: LONGINT ): off_t;
	fsync-		: PROCEDURE {C} ( fd: LONGINT ): LONGINT;
	ioctl-			: PROCEDURE {C} ( fd: LONGINT; request: LONGINT; arg: ADDRESS ): LONGINT;
	unlink-		: PROCEDURE {C} ( name: ADDRESS ): LONGINT;
	rename-		: PROCEDURE {C} ( oldname, newname: ADDRESS ): LONGINT;
	ftruncate-		: PROCEDURE {C} ( fd: LONGINT;  length: SIZE ): LONGINT;
	chmod-		: PROCEDURE {C} ( name: ADDRESS;  mode: SET ): LONGINT;
	utime-		: PROCEDURE {C} ( name: ADDRESS;  tb: ADDRESS ): LONGINT;
	access-		: PROCEDURE {C} ( name: ADDRESS;  mode: SET ): LONGINT;
	select-		: PROCEDURE {C} ( width: LONGINT; rd, wr, ex: ADDRESS;  VAR timeout: Timeval ): LONGINT;
	realpath-	: PROCEDURE {C} (file_name: ADDRESS; resolved_name: ADDRESS): ADDRESS;

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
(*	clock_gettime-	: PROCEDURE{C} (clk_id: LONGINT; tp: tvPtr): LONGINT;	*)

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
	errno_loc		: PROCEDURE {C} ( ): ADDRESS;

	xSetErrorHandler: PROCEDURE {C} (h: ADDRESS): WORD;
	xSetIOErrorHandler: PROCEDURE {C} (h: ADDRESS): WORD;

	libc-: ADDRESS;
	libp-: ADDRESS;
	libx-: ADDRESS;

	libraryPaths: ARRAY 8 OF ARRAY 32 OF CHAR;
	noPaths: LONGINT;



	PROCEDURE getnprocs* (): LONGINT;
	BEGIN
		RETURN sysconf( 0x58 ); (*0x57 for number of processors configured, 0x58 for number of processors online *)
	END getnprocs;


	PROCEDURE NewKey*( ): Key_t;
	VAR
		key: Key_t;
	BEGIN
		ASSERT(pthread_key_create(ADDRESSOF(key), NIL) = 0);
		RETURN key;
	END NewKey;
 
	PROCEDURE ReadKey* (key: Key_t): ADDRESS;
	BEGIN
		RETURN pthread_getspecific(key);
	END ReadKey;

	PROCEDURE WriteKey* (key: Key_t; value: ADDRESS);
	BEGIN
		ASSERT(pthread_setspecific(key, value) = 0);
	END WriteKey;
	
	
	PROCEDURE NewMtx*( ): Mutex_t;
	VAR
		mtx: Mutex_t;
	BEGIN
		mtx := malloc( SIZEOF(MutexType) );
		ASSERT(mtx # 0);
		ASSERT(pthread_mutex_init(mtx, NIL) = 0);
		RETURN mtx;
	END NewMtx;

	PROCEDURE NewRecursiveMtx*( ): Mutex_t;
	VAR
		mtx: Mutex_t;
		attr: MutexAttributeType;
		res: WORD;
	CONST
		Recursive = 2;
	BEGIN
		mtx := malloc( SIZEOF(MutexType) );
		res := pthread_mutexattr_init( ADDRESSOF( attr ) );
		res := pthread_mutexattr_settype( ADDRESSOF( attr ), Recursive );

		ASSERT( mtx # 0 );
		ASSERT( pthread_mutex_init( mtx, ADDRESSOF( attr ) ) = 0);
		RETURN mtx;
	END NewRecursiveMtx;



	PROCEDURE MtxDestroy*(mtx: Mutex_t);
	BEGIN
		ASSERT( pthread_mutex_destroy( mtx ) = 0 );
	END MtxDestroy;

	PROCEDURE MtxLock*(mtx: Mutex_t);
	BEGIN
		ASSERT( pthread_mutex_lock( mtx ) = 0 );
	END MtxLock;

	PROCEDURE MtxUnlock*(mtx: Mutex_t);
	BEGIN
		ASSERT( pthread_mutex_unlock( mtx ) = 0 );
	END MtxUnlock;

	PROCEDURE NewCond* ( ): Condition_t;
	VAR cond: Condition_t;
	BEGIN
		cond := malloc( SIZEOF(ConditionType) );
		ASSERT(cond # 0);
		ASSERT(pthread_cond_init(cond, NIL)=0);
		RETURN cond;
	END NewCond;

	PROCEDURE CondDestroy*(con: Condition_t);
	BEGIN
		ASSERT(pthread_cond_destroy(con) = 0);
	END CondDestroy;

	PROCEDURE CondWait*(con: Condition_t; mtx: Mutex_t);
	BEGIN
		ASSERT(pthread_cond_wait(con, mtx) = 0);
	END CondWait;

	PROCEDURE CondSignal*(cond: Condition_t);
	BEGIN
		ASSERT(pthread_cond_signal(cond) = 0);
	END CondSignal;

	PROCEDURE ThrThis*(): Thread_t;
	BEGIN
		RETURN pthread_self( );
	END ThrThis;

	PROCEDURE ThrYield*( );
	BEGIN
		ThrSleep(1);
	END ThrYield;

	PROCEDURE ThrExit*( );
	BEGIN
		pthread_exit( 0 );
	END ThrExit;

	PROCEDURE ThrSetPriority*( thr: Thread_t; prio: LONGINT );
	VAR
		param: Sched_param;
		policy, res: LONGINT;
	BEGIN
		res := pthread_getschedparam( thr, ADDRESSOF( policy ), ADDRESSOF( param ) );
		param.sched_priority := prio;
		res := pthread_setschedparam( thr, SCHED_RR, ADDRESSOF( param ) ) 
	END ThrSetPriority;

	PROCEDURE ThrGetPriority*( thr: Thread_t ): LONGINT;
	VAR
		param: Sched_param;
		policy: LONGINT;
	BEGIN
	    IF pthread_getschedparam( thr, ADDRESSOF( policy ), ADDRESSOF( param ) ) # 0 THEN END;
	    RETURN  param.sched_priority;
	END ThrGetPriority;

	VAR
		sigstk: Stack;

	PROCEDURE SetSigaltstack;
	BEGIN
		IF sigaltstack( ADDRESSOF( sigstk ), NIL ) < 0 THEN
			Perror("sigaltstack")
		END;
	END SetSigaltstack;

	PROCEDURE {C} Starter( proc: PROCEDURE ): ADDRESS;
	VAR
		me: Thread_t;
		old, new: Sigset;
		param: Sched_param;
		res: LONGINT;
	BEGIN
		me := pthread_self();
		SetSigaltstack();

		IF sigfillset( ADDRESSOF( new ) ) # 0 THEN
			Perror("sigfillset");
		END;
		sigdelset( ADDRESSOF( new ), SIGILL );
		sigdelset( ADDRESSOF( new ), SIGTRAP );
		sigdelset( ADDRESSOF( new ), SIGFPE );
		sigdelset( ADDRESSOF( new ), SIGBUS );
		sigdelset( ADDRESSOF( new ), SIGSEGV );
		sigdelset( ADDRESSOF( new ), SIGTERM );
		sigdelset( ADDRESSOF( new ), SIGUSR1 );
		res := pthread_sigmask( SIG_SETMASK, ADDRESSOF( new ), ADDRESSOF( old ) );
		
		res := pthread_setcancelstate( PTHREAD_CANCEL_ENABLE, NIL );
		res := pthread_setcanceltype( PTHREAD_CANCEL_ASYNCHRONOUS, NIL );
		param.sched_priority := 0;
		res := pthread_setschedparam( me, SCHED_RR, ADDRESSOF( param ) );
		
		proc();

		pthread_exit( NIL );
		RETURN NIL;
	END Starter;

	PROCEDURE ThrStart*( p: PROCEDURE; stackSize: SIZE ): Thread_t;
	VAR
		attr: PThreadAttrType;
		id: Thread_t;
		res: LONGINT;
	BEGIN
		pthread_attr_init( ADDRESSOF( attr ) );
		pthread_attr_setscope( ADDRESSOF( attr ), PTHREAD_SCOPE_SYSTEM );
		pthread_attr_setdetachstate( ADDRESSOF( attr ), PTHREAD_CREATE_DETACHED );
		(*pthread_attr_setdetachstate( ADDRESSOF( attr ), 0 );*)
		pthread_attr_setstacksize( ADDRESSOF( attr ), stackSize );
		res := pthread_create(ADDRESSOF( id ), ADDRESSOF( attr ), Starter, p );
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
		WHILE (nanosleep( ADDRESSOF( sltime ), ADDRESSOF( rem ) ) < 0) DO
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


	PROCEDURE ThrResume*( thr: Thread_t );
	VAR machthr: MachPort;
	BEGIN
		machthr := pthread_mach_thread_np( thr );
		thread_resume( machthr );
	END ThrResume;	

	
	PROCEDURE ThrSuspend*( thr: Thread_t; saveContext: BOOLEAN );
	VAR r: LONGINT;  machthr: MachPort;
	BEGIN
		IF saveContext THEN
			handler_done := FALSE;
			r := pthread_kill( thr, SIGUSR1 );	
			(*	not working in Solaris when the thread is stalled in a mutex.
				handler gets arrived but has bad side effects, 
				yields traps and locks the system *)
			WHILE ~handler_done DO  ThrSleep( 1 )  END;
		END;
		machthr := pthread_mach_thread_np( thr );
		thread_suspend( machthr )
	END ThrSuspend;	



	PROCEDURE ThrInitialize*( VAR low, high: LONGINT ): BOOLEAN;
	VAR
		param: Sched_param;
	BEGIN
		mainthread := pthread_self();
		high := sched_get_priority_max(SCHED_OTHER);
		low := sched_get_priority_min(SCHED_OTHER);

		param.sched_priority := high;
		IF pthread_setschedparam( mainthread, SCHED_RR, ADDRESSOF( param ) ) # 0 THEN END;

		RETURN TRUE;
	END ThrInitialize;

	PROCEDURE CopyContext*( CONST from: Mcontext; VAR to: McontextDesc );
	BEGIN
		S.MOVE( ADDRESSOF( from^ ), ADDRESSOF( to ), SIZEOF( McontextDesc ) );
	END CopyContext;


	PROCEDURE ModifyContext*( cont: Mcontext;  pc, bp, sp: ADDRESS );
	BEGIN
		cont.r_pc := pc;
		cont.r_bp := bp;
		cont.r_sp := sp;
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
		(*	exit( 999 )		*)
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
				h := Glue.dlopen( ADDRESSOF( p ), mode );  INC( i );
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

	PROCEDURE CreateSignalStack;
	BEGIN
		sigstk.sp := ADDRESSOF( sigstack );
		sigstk.size := LEN( sigstack );
		sigstk.flags := {};
	END CreateSignalStack;



	VAR trap: SignalTrap;

	PROCEDURE InstallTrap*( h: SignalTrap );
	BEGIN
		trap := h;
	END InstallTrap;
	
	
	VAR suspendHandler*: PROCEDURE( c: Ucontext );
	
	PROCEDURE {C} SigHandler( sig: LONGINT; scp: ADDRESS; ucp: Ucontext ); (* reversed arguments !! *)
	BEGIN
		IF sig = SIGUSR1 THEN
			suspendHandler( ucp );
			handler_done := TRUE;
		ELSIF trap # NIL THEN 
			trap( sig, ucp.mc );
		ELSE
			Trace.String( "Unix.SigHandler: sig = " ); Trace.Int( sig, 0 ); Trace.Ln;  exit( -1 );
		END;
	END SigHandler;


	PROCEDURE InstallHandler( sig: LONGINT );
	VAR
		act: Sigaction;
		mask: Sigset;
	BEGIN
		sigemptyset( ADDRESSOF( mask ) );
		act.sa_mask := mask;
		IF sig = SIGSEGV THEN (* segmentation violation *)
			act.sa_flags := SA_SIGINFO + SA_ONSTACK + SA_NODEFER;
		ELSE
			act.sa_flags := SA_SIGINFO + SA_NODEFER;
		END;
		act.sa_handler := ADDRESSOF( SigHandler );
		IF sigaction( sig, ADDRESSOF( act ), 0 ) # 0 THEN
			Perror("sigaction");
		END;
	END InstallHandler;

	
	PROCEDURE HandleSignal*( sig: LONGINT );
	BEGIN
		InstallHandler( sig )
	END HandleSignal;
	
	
	PROCEDURE errno*(): LONGINT;
	VAR loc: ADDRESS;
	BEGIN
		loc := errno_loc();
		RETURN S.GET32( loc );
	END errno;

	TYPE OberonXErrorHandler* = PROCEDURE (disp, err: ADDRESS): LONGINT;
	TYPE OberonXIOErrorHandler* = PROCEDURE (disp: ADDRESS): LONGINT;
	VAR oberonXErrorHandler: OberonXErrorHandler;
	VAR oberonXIOErrorHandler: OberonXIOErrorHandler;


	PROCEDURE {C} X11ErrorHandler(d: ADDRESS; err: ADDRESS): WORD;
	VAR res: LONGINT;
	BEGIN
		TRACE(d,err);
		IF oberonXErrorHandler # NIL THEN
			res := oberonXErrorHandler(d, err);
		END;
		RETURN 0;
	END X11ErrorHandler;

	PROCEDURE X11IOErrorHandler(d: ADDRESS): WORD;
	VAR res: LONGINT;
	BEGIN
		TRACE(d);
		IF oberonXIOErrorHandler # NIL THEN
			res := oberonXIOErrorHandler(d);
		END;
		RETURN 0;
	END X11IOErrorHandler;

	PROCEDURE InitXErrorHandlers*(xErrorHandler: OberonXErrorHandler; xIOErrorHandler: OberonXIOErrorHandler);
	VAR res: WORD;
	BEGIN
		oberonXErrorHandler := xErrorHandler;
		oberonXIOErrorHandler := xIOErrorHandler;
		res := xSetErrorHandler( ADDRESSOF( X11ErrorHandler ) );
		res := xSetIOErrorHandler( ADDRESSOF( X11IOErrorHandler ) );
	END InitXErrorHandlers;

	PROCEDURE Init;
	BEGIN
		argc := Glue.argc;
		argv := Glue.argv;
		environ := Glue.environ;

		libraryPaths[0] := "/usr/lib";
		libraryPaths[1] := "/usr/X11/lib";
		libraryPaths[2] := "/opt/X11/lib";
		libraryPaths[3] := "/opt/local/lib";
		noPaths := 4;

		libc := Dlopen( libcname, 2 );
		libp := Dlopen( libpthreadname, 2 ); 

		Dlsym( libc, "exit",		ADDRESSOF(exit) );
		Dlsym( libc, "sysconf", ADDRESSOF(sysconf) );

		Dlsym( libc, "pthread_mutex_init", ADDRESSOF(pthread_mutex_init) );
		Dlsym( libc, "pthread_mutex_destroy", ADDRESSOF(pthread_mutex_destroy) );
		Dlsym( libc, "pthread_mutex_lock", ADDRESSOF(pthread_mutex_lock) );
		Dlsym( libc, "pthread_mutex_unlock", ADDRESSOF(pthread_mutex_unlock) );

		Dlsym( libp, "pthread_mutexattr_init", ADDRESSOF(pthread_mutexattr_init) );
		Dlsym( libp, "pthread_mutexattr_settype", ADDRESSOF(pthread_mutexattr_settype) );


		Dlsym( libc, "pthread_cond_init", ADDRESSOF(pthread_cond_init) );
		Dlsym( libc, "pthread_cond_destroy", ADDRESSOF(pthread_cond_destroy) );
		Dlsym( libc, "pthread_cond_wait", ADDRESSOF(pthread_cond_wait) );
		Dlsym( libc, "pthread_cond_signal", ADDRESSOF(pthread_cond_signal) );

		Dlsym( libp, "pthread_create", ADDRESSOF(pthread_create) );
		Dlsym( libp, "pthread_exit", ADDRESSOF(pthread_exit) );
		Dlsym( libp, "pthread_detach", ADDRESSOF(pthread_detach) );
		Dlsym( libp, "pthread_cancel", ADDRESSOF(pthread_cancel) );
		Dlsym( libp, "pthread_kill", ADDRESSOF(pthread_kill) );
		
		Dlsym( libp, "pthread_key_create", ADDRESSOF( pthread_key_create ) );
		Dlsym( libp, "pthread_getspecific", ADDRESSOF( pthread_getspecific ) );
		Dlsym( libp, "pthread_setspecific", ADDRESSOF( pthread_setspecific ) );

		Dlsym( libp, "pthread_sigmask", ADDRESSOF(pthread_sigmask) );
		Dlsym( libp, "pthread_setcancelstate", ADDRESSOF(pthread_setcancelstate) );
		Dlsym( libp, "pthread_setcanceltype", ADDRESSOF(pthread_setcanceltype) );
		Dlsym( libp, "pthread_attr_init", ADDRESSOF(pthread_attr_init) );
		Dlsym( libp, "pthread_attr_setscope", ADDRESSOF(pthread_attr_setscope) );
		Dlsym( libp, "pthread_attr_setdetachstate", ADDRESSOF(pthread_attr_setdetachstate) );
		Dlsym( libp, "pthread_attr_setstacksize", ADDRESSOF(pthread_attr_setstacksize) );
		Dlsym( libp, "pthread_self", ADDRESSOF(pthread_self) );
		
		Dlsym( libc, "pthread_mach_thread_np", ADDRESSOF( pthread_mach_thread_np ) );
		Dlsym( libc, "thread_suspend", ADDRESSOF( thread_suspend ) );
		Dlsym( libc, "thread_resume", ADDRESSOF( thread_resume ) );

		Dlsym( libc, "posix_spawnp", ADDRESSOF(posix_spawnp) );
		Dlsym( libc, "posix_spawn", ADDRESSOF(posix_spawn) );

		Dlsym( libc, "waitpid", ADDRESSOF(waitpid) );
		Dlsym( libc, "pipe", ADDRESSOF(pipe) );
		Dlsym( libc, "dup2", ADDRESSOF(dup2) );
		Dlsym( libc, "dup", ADDRESSOF(dup) );

		Dlsym( libc, "sched_get_priority_max",	ADDRESSOF(sched_get_priority_max) );
		Dlsym( libc, "sched_get_priority_min",	ADDRESSOF(sched_get_priority_min) );
		Dlsym( libc, "pthread_setschedparam",		ADDRESSOF(pthread_setschedparam) );
		Dlsym( libc, "pthread_getschedparam",		ADDRESSOF(pthread_getschedparam) );
		Dlsym( libc, "sigaction",		ADDRESSOF(sigaction) );
		Dlsym( libc, "sigemptyset",	ADDRESSOF(sigemptyset) );
		Dlsym( libc, "sigfillset",		ADDRESSOF(sigfillset) );
		Dlsym( libc, "sigaddset",		ADDRESSOF(sigaddset) );
		Dlsym( libc, "sigdelset",		ADDRESSOF(sigdelset) );
		Dlsym( libc, "nanosleep",		ADDRESSOF(nanosleep) );
		Dlsym( libc, "sigaltstack",	ADDRESSOF(sigaltstack) );
		Dlsym( libc, "sigsuspend",		ADDRESSOF(sigsuspend) );

		Dlsym( libc, "read",		ADDRESSOF( read ) );
		Dlsym( libc, "pread",	ADDRESSOF( pread ) );
		Dlsym( libc, "write",	ADDRESSOF( write ) );
		Dlsym( libc, "pwrite",	ADDRESSOF( pwrite ) );
		Dlsym( libc, "open",		ADDRESSOF( open ) );
		Dlsym( libc, "close",	ADDRESSOF( close ) );
		Dlsym( libc, "lseek",	ADDRESSOF( lseek ) );
		Dlsym( libc, "realpath",	ADDRESSOF( realpath ) );
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

		Dlsym( libc, "stat",		ADDRESSOF( stat ) );
		Dlsym( libc, "lstat",	ADDRESSOF( lstat ) );
		Dlsym( libc, "fstat",	ADDRESSOF( fstat ) );

		Dlsym( libc, "getpid",	ADDRESSOF( getpid ) );
		Dlsym( libc, "getuid",	ADDRESSOF( getuid ) );

		Dlsym( libc, "alarm",	ADDRESSOF( alarm ) );
		Dlsym( libc, "setitimer",	ADDRESSOF( setitimer ) );
		Dlsym( libc, "getitimer",	ADDRESSOF( getitimer ) );
	(*	Dlsym( libc, "clock_gettime", ADDRESSOF( clock_gettime ) );	*)

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


		Dlsym( libc, "sigsetjmp",	ADDRESSOF( sigsetjmp ) );
		Dlsym( libc, "siglongjmp",	ADDRESSOF( siglongjmp ) );


		Dlsym( libc, "malloc",		ADDRESSOF( malloc ) );
		Dlsym( libc, "posix_memalign",	ADDRESSOF( posix_memalign ) );
		Dlsym( libc, "free",			ADDRESSOF( free ) );
		Dlsym( libc, "mprotect",	ADDRESSOF( mprotect ) );

		Dlsym( libc, "system",	ADDRESSOF( system ) );
		Dlsym( libc, "uname",	ADDRESSOF( uname ) );

		Dlsym( libc, "kill",		ADDRESSOF( kill ) );
		Dlsym( libc, "perror",	ADDRESSOF( perror ) );
		Dlsym( libc, "__error",	ADDRESSOF( errno_loc ) );

		getSysinfo;

		CreateSignalStack;
		InstallHandler( SIGUSR1 );
	END Init;

	(* load X11 related libaries only on demand *)
	PROCEDURE LinkToX*;
	BEGIN
		libx := Dlopen( libX11name, 2 );

		Dlsym( libx, "XSetErrorHandler", ADDRESSOF( xSetErrorHandler ) );
		Dlsym( libx, "XSetIOErrorHandler", ADDRESSOF( xSetIOErrorHandler ) );
	END LinkToX;


	PROCEDURE {INITIAL} Init0;
	BEGIN
		Init;
	END Init0;
END Unix.
