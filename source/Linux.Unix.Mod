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
	libX11name* = "libX11.so.6";
	libpthreadname = "libpthread.so.0";

	LittleEndian* = TRUE;   (** byte order of basic types *)
	LsbIs0* = TRUE;   (** bit order of SET type *)

	PageSize* = 4096;	(* least MMU page size *)

	AlternateStackSize = 32 * 4096;

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
	rdonly* = SET32({});  rdwr* = SET32({1});  creat* = SET32({6});  trunc* = SET32({9});

	(* access modes *)
	rwrwr* = 1B4H;  rwxrwxrwx* = 1FFH;

	F_OK* = {};  X_Ok* = {0};  W_OK* = {1};  R_OK* = {2};

	SCHED_OTHER = 0;

	T_SIGRESUME = SIGUSR1;
	T_SIGSUSPEND = SIGUSR2;

	SIGHUP*		= 1;
	SIGINT*		= 2;
	SIGQUIT*	=3;
	SIGILL*		= 4;
	SIGTRAP*	= 5;
	SIGABRT*	= 6;
	SIGIOT*		= 6;
	SIGBUS*		= 7;
	SIGFPE*		= 8;
	SIGKILL*		= 9;
	SIGUSR1*	= 10;
	SIGSEGV*	= 11;
	SIGUSR2*	= 12;
	SIGPIPE*	= 13;
	SIGALRM*	= 14;
	SIGTERM*	= 15;
	SIGSTKFLT*	= 16;
	SIGCHLD*	= 17;
	SIGCONT*	= 18;
	SIGSTOP*	= 19;
	SIGTSTP*	= 20;
	SIGTTIN*		= 21;
	SIGTTOU*	= 22;
	SIGURG*		= 23;
	SIGXCPU*	= 24;
	SIGXFSZ*	= 25;
	SIGVTALRM*	= 26;
	SIGPROF*	= 27;
	SIGWINCH*	=28;
	SIGIO*		=29;
	SIGPOLL*	= SIGIO;
	SIGPWR*	= 30;
	SIGSYS*		= 31;
	SIGUNUSED = 31;

	SIG_BLOCK = 0;
	SIG_UNBLOCK=1;
	SIG_SETMASK=2;

	SA_NOCLDSTOP	= 0x00000001;
	SA_SIGINFO			= 0x00000004;
	SA_ONSTACK		= 0x08000000;
	SA_RESTART		= 0x10000000;
	SA_NODEFER		= 0x40000000;
	SA_RESETHAND	= 0x80000000;

	CLOCK_MONOTONIC* = 1;
	CLOCK_MONOTONIC_RAW* = 4;
	CLOCK_PROCESS_CPUTIME_ID* = 2;
	CLOCK_REALTIME* = 0;
	CLOCK_THREAD_CPUTIME_ID* = 3;

	PTHREAD_CANCEL_ENABLE 	= 0;
	PTHREAD_CANCEL_DISABLE	= 1;

	PTHREAD_CANCEL_ASYNCHRONOUS	= 0;
	PTHREAD_CANCEL_DEFERRED	= 1;

	PTHREAD_BARRIER_SERIAL_THREAD* = -1;

	CPUSetSize* = 128;

	(*--------------------------- Threads -------------------------------*)

TYPE
	Thread_t* = ADDRESS;
	Mutex_t* = ADDRESS;
	Condition_t* = ADDRESS;

	MutexType = ARRAY 10 OF WORD;
	MutexAttributeType = ARRAY 1 OF WORD;
	ConditionType = ARRAY 12 OF WORD;

	Key_t* = ADDRESS;

	Sigset_t= ARRAY 32 OF WORD;
	SignalTrap = PROCEDURE ( sig: LONGINT; mc: Mcontext );

	path_t*	= ARRAY OF CHAR;
	arg_t*		= ARRAY OF CHAR;
	argv_t*	= ARRAY OF arg_t;

	Sem* = RECORD reserved1-: ARRAY 4 OF ADDRESS END;
	Barrier* = RECORD reserved1-: ARRAY 3 OF ADDRESS; reserved2-: ARRAY 2 OF WORD END;

	CPUSet* = ARRAY CPUSetSize DIV (MAX (SET) - MIN (SET) + 1) OF SET;

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
	CREAD*		= {7};
	PARENB*	= {8};
	PARODD*	= {9};
	HUPCL*		= {10};
	CLOCAL*	= {11};


TYPE
	Termios* = RECORD
		iflags*, oflags*, cflags*, lflags*: SET32;
		line*: CHAR;
		cc*	: ARRAY 32 OF CHAR;
		ispeed-, ospeed-: LONGINT
	END;

	(*------------------------------------------------------------------*)


TYPE
	dev_t*		= HUGEINT;
	ino_t*		= LONGWORD;
	nlink_t*	= LONGWORD;
	mode_t*	= WORD;
	off_t*		= LONGWORD;
	blksize_t*= LONGWORD;
	blkcnt_t*	= LONGWORD;
	uid_t*		= LONGINT;
	gid_t*		= LONGINT;
	pid_t*		= LONGINT;

	Status* = RECORD
			#IF I386 THEN
				dev-		: dev_t;
				pad1		: WORD;
				ino-		: ino_t;
				mode-	: mode_t;
				nlink-		: nlink_t;
				uid-		: LONGINT;
				gid-		: LONGINT;
				rdev-		: dev_t;
				pad2		: WORD;
				size-		: SIZE;
				blksize-	: blksize_t;
				blocks-	: blkcnt_t;
				atime-	: Timeval;
				mtime-	: Timeval;
				ctime-	: Timeval;
			#ELSIF AMD64 THEN
				dev-		: dev_t;
				ino-		: ino_t;
				nlink-		: nlink_t;
				mode-	: mode_t;
				uid-		: WORD;
				gid-		: WORD;
				pad1		: WORD;
				rdev-		: dev_t;
				size-		: SIZE;
				blksize-	: blksize_t;
				blocks-	: blkcnt_t;
				atime-	: Timeval;
				mtime-	: Timeval;
				ctime-	: Timeval;
			#ELSE
				unimplemented
			#END
				reserved	: ARRAY 3 OF LONGWORD;
		END;
	tvPtr* = POINTER {UNSAFE, UNTRACED} TO Timeval;
	Timeval* = RECORD
				sec*	: LONGWORD;
				usec*	: LONGWORD;
			END;

	TmPtr* = POINTER {UNSAFE, UNTRACED} TO Tm;
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

	Timespec* = RECORD
		tv_sec*: LONGWORD;
		tv_nsec*: LONGWORD;
	END;

CONST
	FdSetLen* = 32;

TYPE
	FdSet* = ARRAY FdSetLen OF SET32;


	Dirent* = POINTER {UNSAFE, UNTRACED} TO RECORD
				ino-		: ino_t;
				off-		: off_t;
				reclen-	: INTEGER;
				typ-		: CHAR;
				name-	: (*array of*) CHAR;
			END;

	Stack* = RECORD
				sp*		: ADDRESS;
				flags*		: SET;
				size*		: SIZE
			END;

	Ucontext* = POINTER {UNSAFE, UNTRACED} TO UcontextDesc;
	UcontextDesc* = RECORD
				flags-		: SET;
				link-		: ADDRESS;
				stack-	: Stack;
				mc-		: McontextDesc
			END;

	Mcontext* = POINTER{UNSAFE, UNTRACED}  TO McontextDesc;
	McontextDesc* = RECORD
			#IF I386 THEN
				r_gs-		: ADDRESS;
				r_fs-		: ADDRESS;
				r_es-		: ADDRESS;
				r_ds-		: ADDRESS;
				r_di-		: ADDRESS;
				r_si-		: ADDRESS;
				r_bp-		: ADDRESS;
				r_sp_x		: ADDRESS;
				r_bx-		: ADDRESS;
				r_dx-		: ADDRESS;
				r_cx-		: ADDRESS;
				r_ax-		: ADDRESS;
				trapno-	: LONGINT;
				err-		: LONGINT;
				r_pc-		: ADDRESS;
				r_cs-		: ADDRESS;
				flags-		: LONGINT;
				r_sp-		: ADDRESS;		(* sp at error (signal) *)
				r_ss-		: LONGINT;
				fpc-		: ADDRESS; 		(* FP context *)
				oldmask	: LONGINT;
				cr2			: LONGINT
			#ELSIF AMD64 THEN
				r_8			: HUGEINT;
  				r_9			: HUGEINT;
  				r_10		: HUGEINT;
  				r_11		: HUGEINT;
  				r_12		: HUGEINT;
  				r_13		: HUGEINT;
  				r_14		: HUGEINT;
  				r_15		: HUGEINT;
  				r_di		: HUGEINT;
  				r_si		: HUGEINT;
  				r_bp-		: ADDRESS;
  				r_bx-		: HUGEINT;
  				r_dx		: HUGEINT;
  				r_ax		: HUGEINT;
  				r_cx		: HUGEINT;
  				r_sp-		: ADDRESS;
  				r_pc-		: ADDRESS;
  				r_efl		: HUGEINT;
  				r_csgsfs	: HUGEINT;           (* Actually short cs, gs, fs, pad0.  *)
  				err-		: HUGEINT;
  				trapno-	: HUGEINT;
  				oldmask	: HUGEINT;
  				cr2			: HUGEINT;
  			#ELSE
  				unimplemented
  			#END
		END;


	PThreadAttr = RECORD
		reserved1-: ARRAY 5 OF ADDRESS;
		reserved2-: ARRAY 4 OF WORD;
	END;


	Sigaction = RECORD
		sa_handler: ADDRESS;
		(*filler1: ADDRESS;*)
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
	thread_exit: Key_t;

	argc-: LONGINT;  argv-: ADDRESS;  environ-: ADDRESS;

	sysinfo-: RECORD
		sysname-, nodename-, release-, version-, machine-: ARRAY 65 OF CHAR;
	END;

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

	pthread_create-: PROCEDURE {C} (newthread: ADDRESS; attr: ADDRESS; start_routine: ADDRESS; arg: PROCEDURE): WORD;
	pthread_detach: PROCEDURE {C} (thr: ADDRESS);
	pthread_kill: PROCEDURE {C} (thr: ADDRESS; sigid: LONGINT): LONGINT;
	pthread_cancel: PROCEDURE {C} (thr: ADDRESS);
	pthread_join-: PROCEDURE {C} (thread: Thread_t; return: ADDRESS): WORD;

	pthread_key_create	: PROCEDURE {C} ( key: ADDRESS; destructor: PROCEDURE {C} ( param: ADDRESS ) ): WORD;
	pthread_setspecific	: PROCEDURE {C} ( key: Key_t; value: ADDRESS ): WORD;
	pthread_getspecific	: PROCEDURE {C} ( key: Key_t ): ADDRESS;

	pthread_attr_init: PROCEDURE {C} (attr: ADDRESS);
	pthread_attr_destroy: PROCEDURE {C} (attr: ADDRESS);
	pthread_attr_setscope: PROCEDURE {C}(attr: ADDRESS; set: WORD);
	pthread_attr_setdetachstate: PROCEDURE {C}(attr: ADDRESS; set: WORD);
	pthread_attr_setstacksize: PROCEDURE {C}(attr: ADDRESS; stackSize: SIZE);
	pthread_attr_getstacksize: PROCEDURE {C}(attr: ADDRESS; stackSize: ADDRESS);
	pthread_getattr_np: PROCEDURE {C} (thr: ADDRESS; attr: ADDRESS);
	pthread_self-: PROCEDURE {C} (): Thread_t;

	sched_get_priority_max: PROCEDURE {C} (policy: LONGINT): LONGINT;
	sched_get_priority_min: PROCEDURE {C} (policy: LONGINT): LONGINT;
	pthread_setschedparam: PROCEDURE {C} (thread: Thread_t; policy: LONGINT; param: ADDRESS): WORD;
	pthread_getschedparam: PROCEDURE {C} (thread: Thread_t; policy: ADDRESS; param: ADDRESS): WORD;
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

	sem_init-: PROCEDURE {C} (sem: ADDRESS; pshared: WORD; value: WORD): WORD;
	sem_wait-: PROCEDURE {C} (sem: ADDRESS): WORD;
	sem_post-: PROCEDURE {C} (sem: ADDRESS): WORD;
	sem_destroy-: PROCEDURE {C} (sem: ADDRESS): WORD;

	pthread_barrier_init-: PROCEDURE {C} (barrier: ADDRESS; attr: ADDRESS; count: WORD): WORD;
	pthread_barrier_wait-: PROCEDURE {C} (barrier: ADDRESS): WORD;
	pthread_barrier_destroy-: PROCEDURE {C} (barrier: ADDRESS): WORD;

	pthread_getaffinity_np-: PROCEDURE {C} (thread: Thread_t; cpusetsize: SIZE; cpuset: ADDRESS): WORD;
	pthread_setaffinity_np-: PROCEDURE {C} (thread: Thread_t; cpusetsize: SIZE; cpuset: ADDRESS): WORD;

	(*pid: return param for process id. Only set if initialized non-null. path: pointer to string denoting the executable. file_actions: modify which files are open for the new process, if NIL it inherits open files from parent process. attrp: sets process groups, scheduler, signals etc, leave NIL. argv, evp: char** to the arguments and env. variables*)
	posix_spawnp- 	: PROCEDURE {C} (pid: ADDRESS; path: ADDRESS; file_actions: ADDRESS; attrp: ADDRESS; argv: ADDRESS ; envp: ADDRESS): LONGINT;
	(*more restrictive than spawnp*)
	posix_spawn- 	: PROCEDURE {C} (pid: ADDRESS; path: ADDRESS; file_actions: ADDRESS; attrp: ADDRESS; argv: ADDRESS ; envp: ADDRESS): LONGINT;
	waitpid-			: PROCEDURE {C} (pid: pid_t; status: ADDRESS; options: LONGINT): pid_t;
	pipe-				: PROCEDURE {C} (pipefd: ADDRESS): LONGINT; (*pipefd is assumed to be a pointer to a C array of 2 elements, after pipe creation the array will contain file descriptors for the input and output end of the pipe. returns 0 on success, or -1 on fail*)
	dup2-				: PROCEDURE {C} (oldfd,newfd: LONGINT): LONGINT; (*overwrites file descriptor newfd with a copy of oldfd. useful for redirecting pipes.*)
	dup-				: PROCEDURE {C} (oldfd: LONGINT): LONGINT;

	read-			: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE ): SIZE;
	write-			: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE ): SIZE;
	open-			: PROCEDURE {C} ( name: ADDRESS;  flags: SET32; mode: mode_t ): LONGINT;
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
	realpath-		: PROCEDURE {C} ( file_name: ADDRESS; resolved_name: ADDRESS ): ADDRESS;

	chdir-			: PROCEDURE {C} ( name: ADDRESS ): LONGINT;
	mkdir-		: PROCEDURE {C} ( name: ADDRESS;  mode: mode_t ): LONGINT;
	rmdir-			: PROCEDURE {C} ( path: ADDRESS ): LONGINT;

	xstat-			: PROCEDURE {C} ( ver: LONGINT; name: ADDRESS;  VAR buf: Status ): LONGINT;
	lxstat-		: PROCEDURE {C} ( ver: LONGINT; name: ADDRESS;  VAR buf: Status ): LONGINT;
	fxstat-		: PROCEDURE {C} ( ver: LONGINT; fd: LONGINT;  VAR buf: Status ): LONGINT;

	getpid-		: PROCEDURE {C} ( ): LONGINT;
	getuid-		: PROCEDURE {C} ( ): LONGINT;

	posix_memalign-	: PROCEDURE {C} ( VAR p: ADDRESS;  alignment, size: SIZE ): LONGINT;
	malloc-		: PROCEDURE {C} ( size: SIZE ): ADDRESS;
	free-			: PROCEDURE {C} ( p: ADDRESS );
	mprotect-	: PROCEDURE {C} ( p: ADDRESS; len: SIZE; prot: LONGINT ): LONGINT;

	alarm-		: PROCEDURE {C} ( ms: LONGINT ): LONGINT;
	setitimer-		: PROCEDURE {C} ( which: LONGINT;  VAR value, ovalue: Itimerval ): LONGINT;
	getitimer-		: PROCEDURE {C} ( which: LONGINT;  VAR value: Itimerval ): LONGINT;
	clock_gettime-	: PROCEDURE {C} (clk_id: WORD; tp: ADDRESS): WORD;
	clock_getres-	: PROCEDURE {C} (clk_id: WORD; res: ADDRESS): WORD;

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
	errno_location: PROCEDURE {C} ( ): ADDRESS;

	xSetErrorHandler: PROCEDURE {C} (h: ADDRESS): WORD;
	xSetIOErrorHandler: PROCEDURE {C} (h: ADDRESS): WORD;

	libc-: ADDRESS;
	libp-: ADDRESS;
	libx-: ADDRESS;

	libraryPaths: ARRAY 8 OF ARRAY 32 OF CHAR;
	noPaths: LONGINT;



	PROCEDURE getnprocs* (): LONGINT;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		RETURN sysconf( 0x54 ); (*0x53 for number of processors configured, 0x54 for number of processors online *)
	END getnprocs;

	PROCEDURE NewKey*( ): Key_t;
	VAR
		key: Key_t;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ASSERT(pthread_key_create(ADDRESSOF(key), NIL) = 0);
		RETURN key;
	END NewKey;

	PROCEDURE ReadKey* (key: Key_t): ADDRESS;
	BEGIN {UNCOOPERATIVE, UNCHECKED, UNTRACKED}
		RETURN pthread_getspecific(key);
	END ReadKey;

	PROCEDURE WriteKey* (key: Key_t; value: ADDRESS);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ASSERT(pthread_setspecific(key, value) = 0);
	END WriteKey;


	PROCEDURE NewMtx*( ): Mutex_t;
	VAR
		mtx: Mutex_t;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
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
		Recursive = 1;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		mtx := malloc( SIZEOF(MutexType) );
		res := pthread_mutexattr_init(ADDRESS OF attr);
		res := pthread_mutexattr_settype(ADDRESS OF attr, Recursive);

		ASSERT(mtx # 0);
		ASSERT(pthread_mutex_init(mtx, ADDRESS OF attr) = 0);
		RETURN mtx;
	END NewRecursiveMtx;



	PROCEDURE MtxDestroy*(mtx: Mutex_t);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ASSERT(pthread_mutex_destroy(mtx) = 0);
	END MtxDestroy;

	PROCEDURE MtxLock*(mtx: Mutex_t);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ASSERT(pthread_mutex_lock(mtx) = 0);
	END MtxLock;

	PROCEDURE MtxUnlock*(mtx: Mutex_t);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ASSERT(pthread_mutex_unlock(mtx) = 0);
	END MtxUnlock;

	PROCEDURE NewCond* ( ): Condition_t;
	VAR cond: Condition_t;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		cond := malloc( SIZEOF(ConditionType) );
		ASSERT(cond # 0);
		ASSERT(pthread_cond_init(cond, NIL)=0);
		RETURN cond;
	END NewCond;

	PROCEDURE CondDestroy*(con: Condition_t);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ASSERT(pthread_cond_destroy(con) = 0);
	END CondDestroy;

	PROCEDURE CondWait*(con: Condition_t; mtx: Mutex_t);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ASSERT(pthread_cond_wait(con, mtx) = 0);
	END CondWait;

	PROCEDURE CondSignal*(cond: Condition_t);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ASSERT(pthread_cond_signal(cond) = 0);
	END CondSignal;

	PROCEDURE ThrThis*(): Thread_t;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		RETURN pthread_self( );
	END ThrThis;

	PROCEDURE ThrYield*( );
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ThrSleep(1);
	END ThrYield;

	PROCEDURE ThrExit*( );
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		siglongjmp (pthread_getspecific (thread_exit), 1);
	END ThrExit;

	PROCEDURE ThrSetPriority*(thr: Thread_t; prio: LONGINT);
	VAR
		param: Sched_param;
		policy: LONGINT;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
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
	BEGIN {UNCOOPERATIVE, UNCHECKED}
	    IF pthread_getschedparam( thr, ADDRESS OF policy, ADDRESS OF param ) # 0 THEN END;
	    RETURN  param.sched_priority;
	END ThrGetPriority;

	PROCEDURE {C} Starter(proc: PROCEDURE): ADDRESS;
	VAR
		me: Thread_t;
		old, new: Sigset_t;
		param: Sched_param;
		res: WORD;
		attr: PThreadAttr;
		stack: Stack;
		size: SIZE;
		state: ARRAY 2048 OF CHAR;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		me := pthread_self();

		pthread_getattr_np(me, ADDRESS OF attr);
		pthread_attr_getstacksize (ADDRESS OF attr, ADDRESS OF size);
		pthread_attr_destroy(ADDRESS OF attr);

		stack.sp := S.GetFramePointer () - size + AlternateStackSize;
		stack.size := AlternateStackSize;
		stack.flags := {};

		IF sigaltstack(ADDRESS OF stack, NIL) # 0 THEN
			Perror("signaltstack")
		END;

		IF sigfillset( ADDRESS OF new ) < 0 THEN
			Perror("sigfillset");
		END;
		sigdelset( ADDRESS OF new, SIGILL );
		sigdelset( ADDRESS OF new, SIGTRAP );
		sigdelset( ADDRESS OF new, SIGFPE );
		sigdelset( ADDRESS OF new, SIGBUS );
		sigdelset( ADDRESS OF new, SIGSEGV );
		sigdelset( ADDRESS OF new, SIGTERM );
		sigdelset( ADDRESS OF new, T_SIGSUSPEND );

		res := pthread_sigmask( SIG_SETMASK, ADDRESS OF new, ADDRESS OF old );
		res := pthread_setcancelstate( PTHREAD_CANCEL_ENABLE, NIL );
		res := pthread_setcanceltype( PTHREAD_CANCEL_ASYNCHRONOUS, NIL );
		param.sched_priority := 0;
		res := pthread_setschedparam( me, SCHED_OTHER, ADDRESS OF param );

		ASSERT (pthread_setspecific (thread_exit, ADDRESS OF state) = 0);
		IF sigsetjmp (ADDRESS OF state, 0) = 0 THEN proc END;
		RETURN NIL;
	END Starter;

	PROCEDURE ThrStart*(p: PROCEDURE; stackSize: SIZE): Thread_t;
	VAR
		attr: PThreadAttr;
		id: Thread_t;
		res: WORD;
	CONST
		PTHREAD_SCOPE_SYSTEM = 0;
		PTHREAD_CREATE_DETACHED = 1;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		pthread_attr_init(ADDRESS OF attr);
		pthread_attr_setscope(ADDRESS OF attr, PTHREAD_SCOPE_SYSTEM);
		pthread_attr_setdetachstate(ADDRESS OF attr, PTHREAD_CREATE_DETACHED);
		(*pthread_attr_setdetachstate(ADDRESS OF attr, 0);*)
		pthread_attr_setstacksize(ADDRESS OF attr, stackSize + AlternateStackSize);
		res := pthread_create(ADDRESS OF id, ADDRESS OF attr, Starter, p);
		RETURN id;
	END ThrStart;

	PROCEDURE ThrSleep*(ms: LONGINT);
	VAR
		sltime,rem: RECORD
			tv_sec: LONGWORD;        (* seconds *)
			tv_nsec: LONGWORD;       (* nanoseconds *)
     	END;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		sltime.tv_sec := ms DIV 1000;
		sltime.tv_nsec := 1000000*(ms MOD 1000);
		WHILE (nanosleep(ADDRESS OF sltime, ADDRESS OF rem) < 0) DO
			(* check error ! *)
			sltime := rem;
		END;
	END ThrSleep;

	PROCEDURE NanoSleep(ns: LONGWORD);
	VAR
		sltime,rem: RECORD
			tv_sec: LONGWORD;        (* seconds *)
			tv_nsec: LONGWORD;       (* nanoseconds *)
     	END;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		sltime.tv_sec := ns DIV 1000000000;
		sltime.tv_nsec := ns MOD 1000000000;
		WHILE (nanosleep(ADDRESS OF sltime, ADDRESS OF rem) < 0) DO
			(* check error ! *)
			sltime := rem;
		END;
	END NanoSleep;

	PROCEDURE ThrKill*(thr: Thread_t);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		IF (thr # mainthread) THEN
	    		pthread_detach( thr );
    			IF (thr = pthread_self()) THEN
				ThrExit;
			ELSE
				pthread_cancel( thr );
			END
		END;
    END ThrKill;

	PROCEDURE {C} resume_handler( sig: LONGINT );
	BEGIN {UNCOOPERATIVE, UNCHECKED}
	END resume_handler;

	PROCEDURE ThrResume*( thr: Thread_t );
	VAR  res: WORD;
	BEGIN {UNCOOPERATIVE, UNCHECKED, UNTRACKED}
		res := pthread_mutex_lock(ADDRESS OF suspend_mutex );
		resume_done := 0;
		res := pthread_kill( thr, T_SIGRESUME );
		ASSERT(res = 0);

		WHILE (CAS(resume_done,0,0) # 1) DO NanoSleep(1000) END;
		res := pthread_mutex_unlock( ADDRESS OF suspend_mutex );
	END ThrResume;

	VAR suspendHandler*: PROCEDURE(c: Ucontext);

	PROCEDURE {C} suspend_handler(sig: LONGINT; scp: ADDRESS; ucp: ADDRESS);
	VAR block: Sigset_t; res: WORD;
	BEGIN {UNCOOPERATIVE, UNCHECKED, UNTRACKED}
		IF suspendHandler # NIL THEN suspendHandler( S.VAL( Ucontext, ucp) ) END;
		res := sigfillset( ADDRESS OF block );
		sigdelset(  ADDRESS OF block, T_SIGRESUME );
		ASSERT(CAS(suspend_done,0,1)=0);
		res := sigsuspend(  ADDRESS OF block ); (* await T_SIGRESUME *)
		ASSERT(CAS(resume_done,0,1) = 0); (*makes no difference if we do that here or in the resume handler*)
	END suspend_handler;

	PROCEDURE ThrSuspend*(thr: Thread_t; saveContext: BOOLEAN);
	VAR res: WORD;
	BEGIN {UNCOOPERATIVE, UNCHECKED, UNTRACKED}
		res := pthread_mutex_lock(ADDRESS OF suspend_mutex );
		suspend_done := 0;
		res := pthread_kill( thr, T_SIGSUSPEND );
		ASSERT(res = 0);
		WHILE (CAS(suspend_done,0,0) # 1) DO NanoSleep( 1000 ) END;
		res := pthread_mutex_unlock( ADDRESS OF suspend_mutex );
	END ThrSuspend;





	PROCEDURE ThrInitialize*( VAR low, high: LONGINT ): BOOLEAN;
	VAR
		param: Sched_param; res: WORD;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ASSERT(pthread_mutex_init( ADDRESS OF suspend_mutex, NIL ) = 0);
		mainthread := pthread_self();
		high := sched_get_priority_max(SCHED_OTHER);
		low := sched_get_priority_min(SCHED_OTHER);

		param.sched_priority := high;
		IF pthread_setschedparam( mainthread, SCHED_OTHER, ADDRESS OF param)#0 THEN
			Perror("ThrInitialize: setparam");
		END;

		res := sigfillset( ADDRESS OF sasuspend.sa_mask );
		sasuspend.sa_flags := SA_SIGINFO;
		sasuspend.sa_handler := suspend_handler;
		ASSERT(sigaction( T_SIGSUSPEND, ADDRESS OF sasuspend, NIL ) = 0);

		sigemptyset( ADDRESS OF saresume.sa_mask );
		saresume.sa_flags := 0;
		saresume.sa_handler := resume_handler;
		ASSERT(sigaction( T_SIGRESUME, ADDRESS OF saresume, NIL ) = 0);

		ASSERT (pthread_key_create (ADDRESS OF thread_exit, NIL) = 0);

		RETURN TRUE;
	END ThrInitialize;

	PROCEDURE CopyContext*(CONST from: McontextDesc; VAR to: McontextDesc);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		S.MOVE(ADDRESS OF from, ADDRESS OF to, SIZE OF McontextDesc);
	END CopyContext;


	PROCEDURE ModifyContext*( cont: Mcontext;  pc, bp, sp: ADDRESS );
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		cont.r_pc := pc;
		cont.r_bp := bp;
		cont.r_sp := sp;
	END ModifyContext;

	PROCEDURE Perror*( CONST msg: ARRAY OF CHAR );
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		perror( ADDRESSOF( msg ) )
	END Perror;

	PROCEDURE Dlsym*( lib: ADDRESS;  CONST sym: ARRAY OF CHAR;  objAddr: ADDRESS );
	VAR val: LONGINT;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		Glue.Dlsym( lib, sym, objAddr );
		S.GET( objAddr, val );
		IF val = 0 THEN
			Trace.String( "Unix.Dlsym:  entry '" );  Trace.String( sym );  Trace.String( "' not found" );
			Trace.Ln;
		(*	exit(0);	*)
		END
	END Dlsym;

	PROCEDURE Dlopen*( CONST libname: ARRAY OF CHAR;  mode: LONGINT ): ADDRESS;
	VAR h: ADDRESS;  i, j, k: INTEGER;
		p: ARRAY 256 OF CHAR;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
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
		END;
		RETURN h
	END Dlopen;

	PROCEDURE Dlclose*( lib: ADDRESS );
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		Glue.dlclose( lib )
	END Dlclose;

	PROCEDURE GetArg*( no: LONGINT;  VAR val: ARRAY OF CHAR );
	VAR ch: CHAR;  adr: ADDRESS;  i: LONGINT;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		IF no >= argc THEN  val[0] := 0X
		ELSE
			S.GET( argv + SIZEOF(ADDRESS)*no, adr );  i := 0;
			REPEAT  S.GET( adr, ch );  val[i] := ch;  INC( adr );  INC( i );   UNTIL (ch = 0X) OR (i >= LEN( val ));
		END
	END GetArg;

	PROCEDURE GetArgval*(  CONST argName: ARRAY OF CHAR;  VAR val: ARRAY OF CHAR );
	VAR i: INTEGER;
		buf: ARRAY 40 OF CHAR;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		i := 1;
		WHILE i < argc - 1 DO
			GetArg( i, buf );
			IF buf = argName THEN  GetArg( i + 1, val );  RETURN   END;
			INC( i )
		END;
		val[0] := 0X
	END GetArgval;



	PROCEDURE getSysinfo;
	VAR res: WORD;  p: INTEGER;
		buf: ARRAY 4096 OF CHAR;

		PROCEDURE copy( VAR p: INTEGER;  VAR dest: ARRAY OF CHAR );
		VAR i: INTEGER;
		BEGIN {UNCOOPERATIVE, UNCHECKED}
			WHILE buf[p] <= ' ' DO  INC( p )  END;
			i := 0;
			REPEAT  dest[i] := buf[p];  INC( i );  INC( p )  UNTIL (buf[p - 1] = 0X) OR (i >= LEN( dest ));
			dest[i - 1] := 0X
		END copy;

	BEGIN {UNCOOPERATIVE, UNCHECKED}
		FOR p := 0 TO 4096 - 1 DO  buf[p] := 0X  END;
		res := uname( ADDRESSOF( buf ) );
		p := 0;
		copy( p, sysinfo.sysname );
		copy( p, sysinfo.nodename );
		copy( p, sysinfo.release );
		copy( p, sysinfo.version );
		copy( p, sysinfo.machine );
	END getSysinfo;

	VAR trap: SignalTrap;

	PROCEDURE {C} SigHandler  ( sig: LONGINT; scp: ADDRESS; ucp: Ucontext ); (* reversed arguments !! *)
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		IF trap # NIL THEN
			trap( sig, S.VAL( Mcontext, ADDRESSOF( ucp.mc ) ) )
		ELSE
			Trace.String( "Unix.SigHandler: sig = " ); Trace.Int( sig, 0 ); Trace.Ln;  exit( -1 );
		END;
	END SigHandler;

	PROCEDURE InstallTrap* ( h: SignalTrap );
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		trap := h;
	END InstallTrap;



	PROCEDURE InstallHandler(sig: LONGINT);
	VAR
		act: Sigaction;
		mask: Sigset_t;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		sigemptyset(ADDRESS OF mask);
		act.sa_mask := mask;
		act.sa_flags :=  SA_SIGINFO +  SA_ONSTACK (* run on separate sig stack *) +  SA_NODEFER;
		act.sa_handler := ADDRESS OF SigHandler;
		IF sigaction( sig, ADDRESS OF act, 0 ) # 0 THEN
			Perror("sigaction");
		END
	END InstallHandler;

	PROCEDURE fstat*  ( fd: LONGINT;  VAR buf: Status ): LONGINT;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
	#IF AMD64 THEN
		RETURN  fxstat( 1, fd, buf );
	#ELSE
		RETURN  fxstat( 3, fd, buf );
	#END
	END fstat;

	PROCEDURE stat*  ( path: ADDRESS;  VAR buf: Status ): LONGINT;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
	#IF AMD64 THEN
		RETURN  xstat( 1, path, buf );
	#ELSE
		RETURN  xstat( 3, path, buf );
	#END
	END stat;


	PROCEDURE HandleSignal*( sig: LONGINT );
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		InstallHandler( sig )
	END HandleSignal;

	PROCEDURE errno*(): LONGINT;
	VAR loc: ADDRESS;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		loc := errno_location();
		RETURN S.GET32(loc);
	END errno;

	TYPE OberonXErrorHandler* = PROCEDURE (disp, err: ADDRESS): LONGINT;
	TYPE OberonXIOErrorHandler* = PROCEDURE (disp: ADDRESS): LONGINT;
	VAR oberonXErrorHandler: OberonXErrorHandler;
	VAR oberonXIOErrorHandler: OberonXIOErrorHandler;


	PROCEDURE {C} X11ErrorHandler(d: ADDRESS; err: ADDRESS): WORD;
	VAR res: WORD;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		IF oberonXErrorHandler # NIL THEN
			res := oberonXErrorHandler(d, err);
		END;
		RETURN 0;
	END X11ErrorHandler;

	PROCEDURE {C} X11IOErrorHandler(d: ADDRESS): WORD;
	VAR res: WORD;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		IF oberonXIOErrorHandler # NIL THEN
			res := oberonXIOErrorHandler(d);
		END;
		RETURN 0;
	END X11IOErrorHandler;

	PROCEDURE InitXErrorHandlers*(xErrorHandler: OberonXErrorHandler; xIOErrorHandler: OberonXIOErrorHandler);
	VAR res: WORD;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		oberonXErrorHandler := xErrorHandler;
		oberonXIOErrorHandler := xIOErrorHandler;
		res := xSetErrorHandler(ADDRESS OF X11ErrorHandler);
		res := xSetIOErrorHandler(ADDRESS OF X11IOErrorHandler);
	END InitXErrorHandlers;

	PROCEDURE Init;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		argc := Glue.argc;
		argv := Glue.argv;
		environ := Glue.environ;

#IF I386 THEN
		libraryPaths[0] := "/lib/i386-linux-gnu/i686/cmov";
		libraryPaths[1] := "/lib/i386-linux-gnu";
		libraryPaths[2] := "/lib32";
		libraryPaths[3] := "/lib";
		libraryPaths[4] := "/usr/lib/i386-linux-gnu";
		libraryPaths[5] := "/usr/lib32";
		libraryPaths[6] := "/usr/lib";
		noPaths := 7;
#ELSIF AMD64 THEN
		libraryPaths[0] := "/lib/x86_64-linux-gnu";
		libraryPaths[1] := "/lib64";
		libraryPaths[2] := "/lib";
		libraryPaths[3] := "/usr/lib/x86_64-linux-gnu";
		libraryPaths[4] := "/usr/lib64";
		libraryPaths[5] := "/usr/lib";
		noPaths := 6;
#ELSE
	=== error
#END

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
		Dlsym( libp, "pthread_detach", ADDRESSOF(pthread_detach) );
		Dlsym( libp, "pthread_cancel", ADDRESSOF(pthread_cancel) );
		Dlsym( libp, "pthread_kill", ADDRESSOF(pthread_kill) );
		Dlsym( libp, "pthread_join", ADDRESSOF(pthread_join) );

		Dlsym( libp, "pthread_key_create", ADDRESSOF( pthread_key_create ) );
		Dlsym( libp, "pthread_getspecific", ADDRESSOF( pthread_getspecific ) );
		Dlsym( libp, "pthread_setspecific", ADDRESSOF( pthread_setspecific ) );

		Dlsym( libp, "pthread_sigmask", ADDRESSOF(pthread_sigmask) );
		Dlsym( libp, "pthread_setcancelstate", ADDRESSOF(pthread_setcancelstate) );
		Dlsym( libp, "pthread_setcanceltype", ADDRESSOF(pthread_setcanceltype) );
		Dlsym( libp, "pthread_attr_init", ADDRESSOF(pthread_attr_init) );
		Dlsym( libp, "pthread_attr_destroy", ADDRESSOF(pthread_attr_destroy) );
		Dlsym( libp, "pthread_attr_setscope", ADDRESSOF(pthread_attr_setscope) );
		Dlsym( libp, "pthread_attr_setdetachstate", ADDRESSOF(pthread_attr_setdetachstate) );
		Dlsym( libp, "pthread_attr_setstacksize", ADDRESSOF(pthread_attr_setstacksize) );
		Dlsym( libp, "pthread_attr_getstacksize", ADDRESSOF(pthread_attr_getstacksize) );
		Dlsym( libp, "pthread_getattr_np", ADDRESSOF(pthread_getattr_np) );
		Dlsym( libp, "pthread_self", ADDRESSOF(pthread_self) );

		Dlsym( libp, "sem_init", ADDRESSOF(sem_init) );
		Dlsym( libp, "sem_wait", ADDRESSOF(sem_wait) );
		Dlsym( libp, "sem_post", ADDRESSOF(sem_post) );
		Dlsym( libp, "sem_destroy", ADDRESSOF(sem_destroy) );

		Dlsym( libp, "pthread_barrier_init", ADDRESSOF(pthread_barrier_init) );
		Dlsym( libp, "pthread_barrier_wait", ADDRESSOF(pthread_barrier_wait) );
		Dlsym( libp, "pthread_barrier_destroy", ADDRESSOF(pthread_barrier_destroy) );

		Dlsym( libp, "pthread_getaffinity_np", ADDRESSOF(pthread_getaffinity_np) );
		Dlsym( libp, "pthread_setaffinity_np", ADDRESSOF(pthread_setaffinity_np) );

		Dlsym( libc, "posix_spawnp", ADDRESSOF(posix_spawnp) );
		Dlsym( libc, "posix_spawn", ADDRESSOF(posix_spawn) );

		Dlsym( libc, "waitpid", ADDRESSOF(waitpid) );
		Dlsym( libc, "pipe", ADDRESSOF(pipe) );
		Dlsym( libc, "dup2",ADDRESSOF(dup2) );
		Dlsym( libc, "dup", ADDRESSOF(dup) );

		Dlsym( libc, "sched_get_priority_max", ADDRESSOF(sched_get_priority_max) );
		Dlsym( libc, "sched_get_priority_min", ADDRESSOF(sched_get_priority_min) );
		Dlsym( libc, "pthread_setschedparam", ADDRESSOF(pthread_setschedparam) );
		Dlsym( libc, "pthread_getschedparam", ADDRESSOF(pthread_getschedparam) );
		Dlsym( libc, "sigaction", ADDRESSOF(sigaction) );
		Dlsym( libc, "sigemptyset", ADDRESSOF(sigemptyset) );
		Dlsym( libc, "sigfillset", ADDRESSOF(sigfillset) );
		Dlsym( libc, "sigaddset", ADDRESSOF(sigaddset) );
		Dlsym( libc, "sigdelset", ADDRESSOF(sigdelset) );
		Dlsym( libc, "nanosleep", ADDRESSOF(nanosleep) );
		Dlsym( libc, "sigaltstack", ADDRESSOF(sigaltstack) );
		Dlsym( libc, "sigsuspend", ADDRESSOF(sigsuspend) );

		Dlsym( libc, "read",		ADDRESSOF( read ) );
		Dlsym( libc, "write",	ADDRESSOF( write ) );
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

		Dlsym( libc, "__xstat",		ADDRESSOF( xstat ) );
		Dlsym( libc, "__lxstat",	ADDRESSOF( lxstat ) );
		Dlsym( libc, "__fxstat",	ADDRESSOF( fxstat ) );

		Dlsym( libc, "getpid",	ADDRESSOF( getpid ) );
		Dlsym( libc, "getuid",	ADDRESSOF( getuid ) );

		Dlsym( libc, "alarm",	ADDRESSOF( alarm ) );
		Dlsym( libc, "setitimer",	ADDRESSOF( setitimer ) );
		Dlsym( libc, "getitimer",	ADDRESSOF( getitimer ) );
		Dlsym( libc, "clock_gettime", ADDRESSOF(clock_gettime) );
		Dlsym( libc, "clock_getres", ADDRESSOF(clock_getres) );

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


		Dlsym( libc, "__sigsetjmp",	ADDRESSOF( sigsetjmp ) );
		Dlsym( libc, "siglongjmp",	ADDRESSOF( siglongjmp ) );


		Dlsym( libc, "malloc",		ADDRESSOF( malloc ) );
		Dlsym( libc, "posix_memalign",	ADDRESSOF( posix_memalign ) );
		Dlsym( libc, "free",			ADDRESSOF( free ) );
		Dlsym( libc, "mprotect",	ADDRESSOF( mprotect ) );

		Dlsym( libc, "system",	ADDRESSOF( system ) );
		Dlsym( libc, "uname",	ADDRESSOF( uname ) );

		Dlsym( libc, "kill",		ADDRESSOF( kill ) );
		Dlsym( libc, "perror",	ADDRESSOF( perror ) );
		Dlsym( libc, "__errno_location",	ADDRESSOF(errno_location ) );

		getSysinfo;
	END Init;

	(* load X11 related libaries only on demand *)
	PROCEDURE LinkToX*;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		libx := Dlopen( libX11name, 2 );

		Dlsym( libx, "XSetErrorHandler", ADDRESS OF xSetErrorHandler);
		Dlsym( libx, "XSetIOErrorHandler", ADDRESS OF xSetIOErrorHandler);
	END LinkToX;


	PROCEDURE {INITIAL} Init0;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		Init;
	END Init0;
END Unix.
