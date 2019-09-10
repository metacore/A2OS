(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Unix;   (* Josef Templ, 5.3.90	SVR4 system calls *)  (** Solaris x86 version, non portable *)

(* Linux PPC version	g.f. 18.04.98	*)
(* Linux x86 version	g.f 10.11.99 	*)
(* Solaris x86 version	g.f 16.11.99 	*)
(*	2000.12.17	g.f.	[C] - flag for new ompiler *)
(*	2002.06.27	g.f.	TmDesc fixed,  new: Utime, Mktime *)
(*	2006.07.31	g.f.	shared memory support added *)
(*	2007.04.13	g.f.	Thread priorities added *)
(*	2008.04.25	g.f.	Trap handling unified	*)

IMPORT S := SYSTEM, Glue, Trace;


CONST
	Version* = "Solaris";

	libcname* = "libc.so.1";
	libX11name* = "libX11.so.4";
	libpthreadname = "libpthread.so.1";

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

	(* Unix signals *)
	SIGHUP*		=  1;		(* hangup *)
	SIGINT*		=  2;		(* interrupt (rubout) *)
	SIGQUIT*	=  3;		(* quit (ASCII FS) *)
	SIGILL*		=  4;		(* illegal instruction (not reset when caught) *)
	SIGTRAP*	=  5;		(* trace trap (not reset when caught) *)
	SIGIOT*		=  6;		(* IOT instruction *)
	SIGABRT*	=  6;		(* used by abort, replace SIGIOT in the future *)
	SIGEMT*		=  7;		(* EMT instruction *)
	SIGFPE*		=  8;		(* floating point exception *)
	SIGKILL*		=  9;		(* kill (cannot be caught or ignored) *)
	SIGBUS*		= 10;		(* bus error *)
	SIGSEGV*	= 11;		(* segmentation violation *)
	SIGSYS*		= 12;		(* bad argument to system call *)
	SIGPIPE*	= 13;		(* write on a pipe with no one to read it *)
	SIGALRM*	= 14;		(* alarm clock *)
	SIGTERM	*	= 15;		(* software termination signal from kill *)
	SIGUSR1*	= 16;		(* user defined signal 1 *)
	SIGUSR2*	= 17;		(* user defined signal 2 *)
	SIGCLD*		= 18;		(* child status change *)
	SIGCHLD*	= 18;		(* child status change alias (POSIX) *)
	SIGPWR*	= 19;		(* power-fail restart *)
	SIGWINCH*	= 20;    	(* window size change *)
	SIGURG*		= 21;		(* urgent socket condition *)
	SIGPOLL*	= 22;		(* pollable event occured *)
	SIGIO*		= SIGPOLL;	(* socket I/O possible (SIGPOLL alias) *)
	SIGSTOP*	= 23;		(* stop (cannot be caught or ignored) *)
	SIGTSTP*	= 24;		(* user stop requested from tty *)
	SIGCONT*	= 25;		(* stopped process has been continued *)
	SIGTTIN*		= 26;		(* background tty read attempted *)
	SIGTTOU*	= 27;		(* background tty write attempted *)
	SIGVTALRM*= 28;		(* virtual timer expired *)
	SIGPROF*	= 29;		(* profiling timer expired *)
	SIGXCPU*	= 30;		(* exceeded cpu limit *)
	SIGXFSZ*	= 31;		(* exceeded file size limit *)
	SIGWAITING*		= 32;  		(* reserved signal no longer used by threading code *)
	SIGAIOCANCEL*	= 33;	(* reserved signal for aio cancellation *)
	SIGFREEZE*	= 34;   	(* special signal used by CPR *)
	SIGTHAW*		= 35;		(* special signal used by CPR *)
	SIGCANCEL*	= 36;  		(* reserved signal for thread cancellation *)
	SIGLOST*		= 37;		(* resource lost (eg, record-lock lost) *)
	SIGXRES*		= 38;		(* resource control exceeded *)
	SIGJVM1*		= 39;		(* reserved signal for Java Virtual Machine *)
	SIGJVM2*		= 40;		(* reserved signal for Java Virtual Machine *)


	SIG_BLOCK		= 1;
	SIG_UNBLOCK	= 2;
	SIG_SETMASK	= 3;

	SCHED_OTHER = 0;	(* scheduling policy *)

	SA_NOCLDSTOP	= 0x00020000;	(* don't send job control SIGCLD's *)
	SA_ONSTACK		= 0x00000001;
	SA_RESETHAND	= 0x00000002;
	SA_RESTART		= 0x00000004;
	SA_SIGINFO			= 0x00000008;
	SA_NODEFER		= 0x00000010;
	SA_NOCLDWAIT	= 0x00010000;	(* don't save zombie children	 *)


	PTHREAD_CANCEL_ENABLE 	= 0;
	PTHREAD_CANCEL_DISABLE	= 1;
	PTHREAD_CANCEL_ASYNCHRONOUS	= 2;
	PTHREAD_CANCEL_DEFERRED	= 0;

	PTHREAD_SCOPE_PROCESS	= 0;
	PTHREAD_SCOPE_SYSTEM		= 1;
	PTHREAD_CREATE_DETACHED	= 40H;



	(* open flags *)
	rdonly* = SET32({});  rdwr* = SET32({1});  creat* = SET32({8});  trunc* = SET32({9});

	(* access modes *)
	rwrwr* = 1B4H;  rwxrwxrwx* = 1FFH;

	F_OK* = {};  X_Ok* = {0};  W_OK* = {1};  R_OK* = {2};

	(*--------------------------- Threads -------------------------------*)

TYPE
	Thread_t* = SIGNED32;
	PthreadAttributeDesc = RECORD attr: ADDRESS END;

	Key_t* = ADDRESS;

	Mutex_t* = ADDRESS;
	MutexDesc = ARRAY 24 OF CHAR;
	MutexAttributeDesc = RECORD attr: ADDRESS END;

	Condition_t* = ADDRESS;
	ConditionDesc = ARRAY 16 OF CHAR;
	ConditionAttributeDesc = RECORD attr: ADDRESS END;

CONST
	(* Thread priorities *)
	ThreadLow* = 0; ThreadNormal* = 20; ThreadHigh* = 100;
	NumPriorities* = 101;	(* number of priority levels *)


	(*---------------------------- IP -----------------------------------*)

CONST
	(* domain *)
		AFINET* = 2;
		AFINET6* = 26;

		PFINET* = AFINET;
		PFINET6* = AFINET6;

	(* types of connection *)
		SockStream*	= 2;
		SockDGram*	= 1;

	(* protocols *)
		IpProtoUDP*	= 17;
		IpProtoTCP*	=  6;

	(* setsockopt *)
		SoLSocket*		= 0FFFFH;	(* socket option level *)
		SoLinger*		= 80H; 		(* linger (gracefully close the connection)*)
		SoKeepAlive*	= 8;			(* keep connection alive *)
		SoNoDelay*		= 1;			(* no delay *)

	(* ioctl *)
		FioNRead*		= 4004667FH;	(* something to read ? *)

	(* recv *)
		MsgPeek*		= 2;
		MsgDontWait*	= 80H;		(* non blocking read *)

	(* shutdown *)
		ShutRDWR*		= 2;

	SockAddrSizeV4*	= 16;
	SockAddrSizeV6*	= 32;

	(*---------------------------- serial line -----------------------------*)


	FIONREAD*	=  4004667FH;
	TIOCMGET*		=  0741DH;
	TIOCMSET*		=  0741AH;

	(* Speeds *)
	B0*	= 0;
	B50*	= 1;
	B75*	= 2;
	B110*	= 3;
	B134*	= 4;
	B150*	= 5;
	B200*	= 6;
	B300*	= 7;
	B600*	= 8;
	B1200*	= 9;
	B1800*	= 10;
	B2400*	= 11;
	B4800*	= 12;
	B9600*	= 13;
	B19200*	= 14;
	B38400*	= 15;

	B57600*		= 16;
	B115200*	= 18;
	B230400*	= 20;


	(* tio.cflag bits *)
	CSIZE*   	= {4,5};
	   CS5*   	= {};
	   CS6*   	= {4};
	   CS7*   	= {5};
	   CS8*   	= {4,5};
	CSTOPB*	= {6};
	CREAD*		= {7};
	PARENB*	= {8};
	PARODD*	= {9};
	HUPCL*		= {10};
	CLOCAL*	= {11};

TYPE
	Termios* = RECORD
		iflags*, oflags*, cflags*, lflags*: SET32;
		cc*: ARRAY 19 OF CHAR;
		dummy-: ARRAY 2 OF SIGNED32
	END;

	(*------------------------------------------------------------------*)

TYPE
	dev_t*		= LONGINTEGER;
	ino_t*		= LONGINTEGER;
	nlink_t*	= INTEGER;
	mode_t*	= INTEGER;
	off_t*		= LONGINTEGER;
	blksize_t*= INTEGER;
	blkcnt_t*	= LONGINTEGER;
	uid_t*		= INTEGER;
	gid_t*		= INTEGER;
	pid_t*		= INTEGER;

	Status* = RECORD
		#IF I386 THEN
				dev-		: dev_t;
				pad1		: ARRAY 3 OF INTEGER;
				ino-		: ino_t;
				mode-	: INTEGER;
				nlink-		: INTEGER;
				uid-		: INTEGER;
				gid-		: INTEGER;
				rdev-		: dev_t;
				pad2		: ARRAY 2 OF INTEGER;
				size-		: INTEGER;
				pad3		: INTEGER;
				atime-	: Timeval;
				mtime-	: Timeval;
				ctime-	: Timeval;
				blksize-	: INTEGER;
				blocks-	: INTEGER;
				fstype-	: ARRAY 16 OF CHAR;
				pad4		: ARRAY 8 OF INTEGER
		#ELSIF AMD64 THEN
				dev-		: dev_t;
				ino-		: ino_t;
				mode-	: INTEGER;
				nlink-		: INTEGER;
				uid-		: INTEGER;
				gid-		: INTEGER;
				rdev-		: dev_t;
				size-		: LONGINTEGER;
				atime-	: Timeval;
				mtime-	: Timeval;
				ctime-	: Timeval;
				blksize-	: INTEGER;
				pad0		: INTEGER;
				blocks-	: LONGINTEGER;
				fstype-	: ARRAY 16 OF CHAR
		#ELSE
			unimplemented
		#END
	END;


	Timeval* = RECORD
				sec*	: LONGINTEGER;
				usec*	: LONGINTEGER
			END;

	TmPtr* = POINTER TO Tm;
	Tm* = RECORD
				sec*, min*, hour*, mday*, mon*, year*, wday*, yday*, isdst*: SIGNED32;
				gmtoff*, tmzone*: SIGNED32;
			END;

	Tms* = RECORD
				utime*, stime*, cutime*, cstime*: SIGNED32
			END;

	Timezone* = RECORD
				minuteswest*, dsttime*: SIGNED32
			END;

	Itimerval* = RECORD
				interval*, value*: Timeval
			END;

CONST
	FdSetLen* = 32;

TYPE
	FdSet* = ARRAY FdSetLen OF SET32;

	Dirent* = POINTER TO RECORD
				ino-		: ino_t;
				off-		: off_t;
				reclen-	: SIGNED16;
				name-	: (*array of*) CHAR;
			END;

	Sigset = ARRAY 4 OF SET32;
	SignalTrap = PROCEDURE ( sig: SIGNED32; mc: Mcontext );

	Stack* = RECORD
				sp-	: ADDRESS;
				size-	: SIZE;
				flags-	: INTEGER;
			END;

	Ucontext* = POINTER TO UcontextDesc;
	UcontextDesc* = RECORD
				flags-		: LONGINTEGER;
				link-		: ADDRESS;
				sigmask-	: Sigset;
				stack-	: Stack;
			#IF AMD64 THEN
				pad: LONGINTEGER;		(* force proper alignment of 'mc' *)
			#END
				mc-		: McontextDesc;
			END;

	Mcontext* = POINTER TO McontextDesc;
	McontextDesc* = RECORD
			#IF I386 THEN
				r_gs-		: SIGNED32;
				r_fs-		: SIGNED32;
				r_es-		: SIGNED32;
				r_ds-		: SIGNED32;
				r_di-		: SIGNED32;
				r_si-		: SIGNED32;
				r_bp-		: SIGNED32;
				r_nsp-	: SIGNED32;
				r_bx-		: SIGNED32;
				r_dx-		: SIGNED32;
				r_cx-		: SIGNED32;
				r_ax-		: SIGNED32;
				r_trapno-	: SIGNED32;
				r_err-		: SIGNED32;
				r_pc-		: SIGNED32;
				r_cs-		: SIGNED32;
				r_flags-	: SIGNED32;
				r_sp-		: SIGNED32;		(* sp at error(signal) *)
				r_ss		: SIGNED32;
				fpc-		: ADDRESS;
			#ELSIF AMD64 THEN
				r_15-		: SIGNED64;
				r_14-		: SIGNED64;
				r_13-		: SIGNED64;
				r_12-		: SIGNED64;
				r_11-		: SIGNED64;
				r_10-		: SIGNED64;
				r_9-		: SIGNED64;
				r_8-		: SIGNED64;
				r_di-		: SIGNED64;
				r_si-		: SIGNED64;
				r_bp-		: SIGNED64;
				r_bx-		: SIGNED64;
				r_dx-		: SIGNED64;
				r_cx-		: SIGNED64;
				r_ax-		: SIGNED64;
				r_trapno-	: SIGNED64;
				r_err-		: SIGNED64;
				r_pc-		: SIGNED64;
				r_cs-		: SIGNED64;
				r_fl-		: SIGNED64;
				r_sp-		: SIGNED64;
				r_ss-		: SIGNED64;
				r_fs-		: SIGNED64;
				r_gs-		: SIGNED64;
				r_es-		: SIGNED64;
				r_ds-		: SIGNED64;
				r_fsbase-	: SIGNED64;
				r_gsbase-: SIGNED64
			#ELSE
				unimplemented
			#END
		END;


	Sigaction = RECORD
				sa_flags: INTEGER;
				sa_handler: ADDRESS;
				sa_mask: Sigset;
				pad1, pad2: INTEGER
			END;

	Sched_param = RECORD
		sched_priority: SIGNED32;
		unused: ARRAY 8 OF SIGNED32;
	END;


	OberonXErrorHandler* = PROCEDURE ( disp, err: ADDRESS ): SIGNED32;
	OberonXIOErrorHandler* = PROCEDURE ( disp: ADDRESS ): SIGNED32;


VAR
	handler_done: BOOLEAN;
	mainthread: Thread_t;
	thread_exit: Key_t;

	argc-: SIGNED32;  argv-: ADDRESS;  environ: ADDRESS;

	trap: SignalTrap;

	oberonXErrorHandler: OberonXErrorHandler;
	oberonXIOErrorHandler: OberonXIOErrorHandler;

	sysinfo-: RECORD
				sysname-, nodename-, release-, version-, machine-: ARRAY 65 OF CHAR;
			END;

	sigstack-: ARRAY 32*4096 OF CHAR;

	sysconf	: PROCEDURE {C} ( name: SIGNED32 ): INTEGER;

	pthread_mutex_init		: PROCEDURE {C} ( mutex: ADDRESS; mutexattr: ADDRESS ): INTEGER;
	pthread_mutex_destroy	: PROCEDURE {C} ( mutex: ADDRESS ): INTEGER;
	pthread_mutex_lock		: PROCEDURE {C} ( mutex: ADDRESS ): INTEGER;
	pthread_mutex_unlock	: PROCEDURE {C} ( mutex: ADDRESS ): INTEGER;

	pthread_mutexattr_init		: PROCEDURE {C} ( mutexattr: ADDRESS ): INTEGER;
	pthread_mutexattr_settype	: PROCEDURE {C} ( mutexattr: ADDRESS; type: INTEGER ): INTEGER;

	pthread_cond_init		: PROCEDURE {C} ( cond: ADDRESS; condAttr: ADDRESS ): INTEGER;
	pthread_cond_destroy	: PROCEDURE {C} ( cond: ADDRESS ): INTEGER;
	pthread_cond_wait		: PROCEDURE {C} ( cond: ADDRESS; mutex: ADDRESS ): INTEGER;
	pthread_cond_signal		: PROCEDURE {C} ( cond: ADDRESS ): INTEGER;

	pthread_create	: PROCEDURE {C} ( newthread: ADDRESS; attr: ADDRESS; start_routine: PROCEDURE {C} (arg: PROCEDURE):ADDRESS; arg:PROCEDURE): Thread_t;
	pthread_exit		: PROCEDURE {C} ( thr: ADDRESS );
	pthread_detach	: PROCEDURE {C} ( thr: Thread_t );
	pthread_kill		: PROCEDURE {C} ( thr: Thread_t; sigid: SIGNED32 ): SIGNED32;
	pthread_cancel	: PROCEDURE {C} ( thr: Thread_t );
	pthread_self		: PROCEDURE {C} ( ): Thread_t;

	pthread_key_create:		PROCEDURE {C} ( key: ADDRESS; destructor: PROCEDURE {C} ( param: ADDRESS ) ): INTEGER;
	pthread_setspecific:		PROCEDURE {C} ( key: Key_t; value: ADDRESS ): INTEGER;
	pthread_getspecific:		PROCEDURE {C} ( key: Key_t ): ADDRESS;

	pthread_attr_init					: PROCEDURE {C} ( attr: ADDRESS );
	pthread_attr_setscope			: PROCEDURE {C} ( attr: ADDRESS; set: INTEGER );
	pthread_attr_setdetachstate	: PROCEDURE {C} ( attr: ADDRESS; set: INTEGER );
	pthread_attr_setstacksize		: PROCEDURE {C} ( attr: ADDRESS; stackSize: SIZE );

	sched_get_priority_max		: PROCEDURE {C} ( policy: SIGNED32 ): SIGNED32;
	sched_get_priority_min		: PROCEDURE {C} ( policy: SIGNED32 ): SIGNED32;
	pthread_setschedparam		: PROCEDURE {C} ( thread: Thread_t; policy: SIGNED32; param: ADDRESS ): INTEGER;
	pthread_getschedparam		: PROCEDURE {C} ( thread: Thread_t; policy: ADDRESS; param: ADDRESS ): INTEGER;
	pthread_setcancelstate		: PROCEDURE {C} ( state: SIGNED32; oldstate: ADDRESS ): SIGNED32;
	pthread_setcanceltype		: PROCEDURE {C} ( type: SIGNED32; oldtype: ADDRESS ): SIGNED32;

	thr_suspend		: PROCEDURE {C} ( thread: Thread_t ): SIGNED32;
	thr_continue		: PROCEDURE {C} ( thread: Thread_t ): SIGNED32;

	sigaction			: PROCEDURE {C} ( signum: SIGNED32; CONST act, oldact: ADDRESS ): SIGNED32;
	sigemptyset		: PROCEDURE {C} ( set: ADDRESS );
	sigfillset			: PROCEDURE {C} ( set: ADDRESS ): SIGNED32;
	sigsuspend		: PROCEDURE {C} ( set: ADDRESS ): SIGNED32;
	sigaddset			: PROCEDURE {C} ( set: ADDRESS; signo: SIGNED32 );
	sigdelset			: PROCEDURE {C} ( set: ADDRESS; signo: SIGNED32 );
	nanosleep			: PROCEDURE {C} ( req, rem: ADDRESS ): SIGNED32;
	sigaltstack		: PROCEDURE {C} ( ss, oss: ADDRESS ): SIGNED32;
	pthread_sigmask	: PROCEDURE {C} ( how: SIGNED32; set: ADDRESS; oldset: ADDRESS ): SIGNED32;

	(*pid: return param for process id. Only set if initialized non-null. path: pointer to string denoting the executable. file_actions: modify which files are open for the new process, if NIL it inherits open files from parent process. attrp: sets process groups, scheduler, signals etc, leave NIL. argv, evp: char** to the arguments and env. variables*)
	posix_spawnp- 	: PROCEDURE {C} ( pid: ADDRESS; path: ADDRESS; file_actions: ADDRESS; attrp: ADDRESS; argv: ADDRESS ; envp: ADDRESS ): SIGNED32;
	(*more restrictive than spawnp*)
	posix_spawn- 	: PROCEDURE {C} ( pid: ADDRESS; path: ADDRESS; file_actions: ADDRESS; attrp: ADDRESS; argv: ADDRESS ; envp: ADDRESS ): SIGNED32;
	waitpid-			: PROCEDURE {C} ( pid: pid_t; status: ADDRESS; options: SIGNED32 ): pid_t;
	pipe-				: PROCEDURE {C} ( pipefd: ADDRESS ): SIGNED32; (*pipefd is assumed to be a pointer to a C array of 2 elements, after pipe creation the array will contain file descriptors for the input and output end of the pipe. returns 0 on success, or -1 on fail*)
	dup2-				: PROCEDURE {C} ( oldfd,newfd: SIGNED32 ): SIGNED32; (*overwrites file descriptor newfd with a copy of oldfd. useful for redirecting pipes.*)
	dup-				: PROCEDURE {C} ( oldfd: SIGNED32 ): SIGNED32;

	read-			: PROCEDURE {C} ( fd: SIGNED32; buf: ADDRESS; n: SIZE ): SIZE;
	write-			: PROCEDURE {C} ( fd: SIGNED32; buf: ADDRESS; n: SIZE ): SIZE;
	open-			: PROCEDURE {C} ( name: ADDRESS;  flags: SET32;  mode: mode_t ): SIGNED32;
	close-		: PROCEDURE {C} ( fd: SIGNED32 ): SIGNED32;
	lseek-		: PROCEDURE {C} ( fd: SIGNED32; offset: off_t; origin: INTEGER ): off_t;
	fsync-		: PROCEDURE {C} ( fd: SIGNED32 ): SIGNED32;
	ioctl-			: PROCEDURE {C} ( fd: SIGNED32; request: SIGNED32; arg: ADDRESS ): SIGNED32;
	unlink-		: PROCEDURE {C} ( name: ADDRESS ): SIGNED32;
	rename-		: PROCEDURE {C} ( oldname, newname: ADDRESS ): SIGNED32;
	ftruncate-		: PROCEDURE {C} ( fd: SIGNED32;  length: SIZE ): SIGNED32;
	chmod-		: PROCEDURE {C} ( name: ADDRESS;  mode: SET ): SIGNED32;
	utime-		: PROCEDURE {C} ( name: ADDRESS;  tb: ADDRESS ): SIGNED32;
	access-		: PROCEDURE {C} ( name: ADDRESS;  mode: SET ): SIGNED32;
	select-		: PROCEDURE {C} ( width: SIGNED32; rd, wr, ex: ADDRESS;  VAR timeout: Timeval ): SIGNED32;
	realpath-		: PROCEDURE {C} ( file_name: ADDRESS; resolved_name: ADDRESS ): ADDRESS;

	chdir-			: PROCEDURE {C} ( name: ADDRESS ): SIGNED32;
	mkdir-		: PROCEDURE {C} ( name: ADDRESS;  mode: mode_t ): SIGNED32;
	rmdir-			: PROCEDURE {C} ( path: ADDRESS ): SIGNED32;

	stat-			: PROCEDURE {C} ( name: ADDRESS;  VAR buf: Status ): SIGNED32;
	lstat-			: PROCEDURE {C} ( name: ADDRESS;  VAR buf: Status ): SIGNED32;
	fstat-			: PROCEDURE {C} ( fd: SIGNED32;  VAR buf: Status ): SIGNED32;

	getpid-		: PROCEDURE {C} ( ): SIGNED32;
	getuid-		: PROCEDURE {C} ( ): SIGNED32;

	malloc-		: PROCEDURE {C} ( size: SIZE ): ADDRESS;
	posix_memalign-	: PROCEDURE {C} ( VAR p: ADDRESS; alignment, size: SIZE ): SIGNED32;
	free-			: PROCEDURE {C} ( p: ADDRESS );
	mprotect-	: PROCEDURE {C} ( p: ADDRESS; len: SIZE; prot: SIGNED32 ): SIGNED32;

	alarm-		: PROCEDURE {C} ( ms: SIGNED32 ): SIGNED32;
	setitimer-		: PROCEDURE {C} ( which: SIGNED32;  VAR value, ovalue: Itimerval ): SIGNED32;
	getitimer-		: PROCEDURE {C} ( which: SIGNED32;  VAR value: Itimerval ): SIGNED32;

	gettimeofday-	: PROCEDURE {C} ( VAR tv: Timeval;  VAR tz: Timezone ): SIGNED32;
	mktime-		: PROCEDURE {C} ( VAR tm: Tm ): SIGNED32;
	localtime-	: PROCEDURE {C} ( CONST tv: Timeval ): TmPtr;
	time-			: PROCEDURE {C} ( VAR tv: Timeval ): SIGNED32;
	times-		: PROCEDURE {C} ( VAR tms: Tms ): SIGNED32;

	system-		: PROCEDURE {C} ( cmd: ADDRESS );
	uname-		: PROCEDURE {C} ( utsname: ADDRESS ): SIGNED32;

	getcwd-		: PROCEDURE {C} ( buf: ADDRESS;  len: SIZE ): ADDRESS;
	getenv-		: PROCEDURE {C} ( name: ADDRESS ): ADDRESS;

	opendir-		: PROCEDURE {C} ( name: ADDRESS ): ADDRESS;
	readdir-		: PROCEDURE {C} ( dir: ADDRESS ): Dirent;
	closedir-		: PROCEDURE {C} ( dir: ADDRESS );

	sigsetjmp-	: PROCEDURE {C} ( env: ADDRESS;  savemask: SIGNED32 ): SIGNED32;
	siglongjmp-	: PROCEDURE {C} ( env: ADDRESS;  val: SIGNED32 );

	kill-			: PROCEDURE {C} ( pid, sig: SIGNED32 ): SIGNED32;
	exit-			: PROCEDURE {C} ( status: SIGNED32 );
	perror-		: PROCEDURE {C} ( msg: ADDRESS );

	errno_location	: PROCEDURE {C} ( ): ADDRESS;

	xSetErrorHandler		: PROCEDURE {C} ( h: ADDRESS ): INTEGER;
	xSetIOErrorHandler	: PROCEDURE {C} ( h: ADDRESS ): INTEGER;

	libc-: ADDRESS;
	libp-: ADDRESS;
	libx-: ADDRESS;

	libraryPaths: ARRAY 7 OF ARRAY 32 OF CHAR;
	noPaths: SIGNED32;

	PROCEDURE ModifyContext*( cont: Mcontext;  pc, bp, sp: ADDRESS );
	BEGIN
		cont.r_pc := pc;
		cont.r_bp := bp;
		cont.r_sp := sp;
	END ModifyContext;

	PROCEDURE CopyContext*( CONST from: McontextDesc; VAR to: McontextDesc );
	BEGIN
		S.MOVE( ADDRESSOF( from ), ADDRESSOF( to ), SIZEOF( McontextDesc ) );
	END CopyContext;


	PROCEDURE Perror*( CONST msg: ARRAY OF CHAR );
	BEGIN
		perror( ADDRESSOF( msg ) )
	END Perror;

	PROCEDURE errno*(): SIGNED32;
	VAR loc: ADDRESS;
	BEGIN
		loc := errno_location();
		RETURN S.GET32( loc );
	END errno;

	PROCEDURE getnprocs* ( ): SIGNED32;
	BEGIN
		RETURN sysconf( 15 ); (* 14 for number of processors configured, 15 for number of processors online *)
	END getnprocs;


	PROCEDURE NewKey*( ): Key_t;
	VAR
		key: Key_t;
	BEGIN
		ASSERT(pthread_key_create(ADDRESSOF(key), NIL) = 0);
		RETURN key;
	END NewKey;

	PROCEDURE ReadKey* (key: Key_t): ADDRESS;
	BEGIN {UNTRACKED}
		RETURN pthread_getspecific(key);
	END ReadKey;

	PROCEDURE WriteKey* (key: Key_t; value: ADDRESS);
	BEGIN
		ASSERT(pthread_setspecific(key, value) = 0);
	END WriteKey;

	(*------------------------------------------------------------------------------------------------------*)

	VAR suspendHandler*: PROCEDURE( c: Ucontext );


	PROCEDURE {C} SigHandler( sig: SIGNED32; scp: ADDRESS; ucp: Ucontext ); (* reversed arguments !! *)
	BEGIN
		IF sig = SIGUSR1 THEN
			suspendHandler( ucp );
			handler_done := TRUE;
		ELSIF trap # NIL THEN
			trap( sig, S.VAL( Mcontext, ADDRESSOF( ucp.mc ) ) );
		ELSE
			Trace.String( "Unix.SigHandler: sig = " ); Trace.Int( sig, 0 ); Trace.Ln;  exit( -1 );
		END;
	END SigHandler;

	PROCEDURE InstallTrap* ( h: SignalTrap );
	BEGIN
		trap := h;
	END InstallTrap;


	PROCEDURE InstallHandler( sig: SIGNED32 );
	VAR
		act: Sigaction;
		mask: Sigset;
	BEGIN
		sigemptyset( ADDRESSOF( mask ) );
		act.sa_mask := mask;
		IF sig = SIGSEGV THEN (* segmentation violation *)
			act.sa_flags :=  SA_SIGINFO +  SA_ONSTACK +  SA_NODEFER;
		ELSE
			act.sa_flags :=  SA_SIGINFO + SA_NODEFER;
		END;
		act.sa_handler := ADDRESSOF( SigHandler );
		IF sigaction( sig, ADDRESSOF( act ), 0 ) # 0 THEN
			Perror( "sigaction" );
		END
	END InstallHandler;


	PROCEDURE HandleSignal*( sig: SIGNED32 );
	BEGIN
		InstallHandler( sig )
	END HandleSignal;

	(*-------------------------------------------------------------------------------------------------------------*)


	PROCEDURE ThrInitialize*( VAR low, high: SIGNED32 ): BOOLEAN;
	BEGIN
		mainthread := pthread_self();
		high := sched_get_priority_max( SCHED_OTHER );
		low := sched_get_priority_min( SCHED_OTHER );

		ASSERT( pthread_key_create( ADDRESSOF( thread_exit ), NIL ) = 0);

		RETURN TRUE;
	END ThrInitialize;



	PROCEDURE ThrResume*( thr: Thread_t );
	BEGIN {UNTRACKED}
		IGNORE thr_continue( thr );
	END ThrResume;


	PROCEDURE ThrSuspend*( thr: Thread_t; saveContext: BOOLEAN );
	BEGIN {UNTRACKED}
		IF saveContext THEN
			(*	not working in Solaris when the thread is stalled in a mutex.
				handler gets arrived but has bad side effects,
				yields traps and locks the system *)
			handler_done := FALSE;
			IGNORE pthread_kill( thr, SIGUSR1 );
			WHILE CAS( handler_done, FALSE, FALSE ) # TRUE DO  NanoSleep( 1000 )  END
		END;
		IGNORE thr_suspend( thr );
	END ThrSuspend;


	PROCEDURE SetSigaltstack;
	VAR sigstk: Stack;
	BEGIN
		sigstk.sp := ADDRESSOF( sigstack );
		sigstk.size := LEN( sigstack );
		sigstk.flags := 0;

		IF sigaltstack( ADDRESSOF( sigstk ), NIL) < 0 THEN
			Perror("sigaltstack")
		END;
	END SetSigaltstack;


	PROCEDURE {C} Starter( proc: PROCEDURE ): ADDRESS;
	VAR
		me: Thread_t;
		old, new: Sigset;
		state: ARRAY 2048 OF CHAR;

		param: Sched_param;
		r: SIGNED32;
	BEGIN
		me := pthread_self();
		SetSigaltstack();

	    	IF sigfillset( ADDRESS OF new ) < 0 THEN
			Perror("sigfillset");
		END;
		sigdelset( ADDRESSOF( new ), SIGILL );
		sigdelset( ADDRESSOF( new ), SIGTRAP );
		sigdelset( ADDRESSOF( new ), SIGFPE );
		sigdelset( ADDRESSOF( new ), SIGBUS );
		sigdelset( ADDRESSOF( new ), SIGSEGV );
		sigdelset( ADDRESSOF( new ), SIGTERM );
		sigdelset( ADDRESSOF( new ), SIGUSR1 );
		sigdelset( ADDRESSOF( new ), SIGUSR2 );
		r := pthread_sigmask( SIG_SETMASK, ADDRESSOF( new ), ADDRESSOF( old ) );
		r := pthread_setcancelstate( PTHREAD_CANCEL_ENABLE, NIL );
		r := pthread_setcanceltype( PTHREAD_CANCEL_ASYNCHRONOUS, NIL );
		param.sched_priority := 0;
		r := pthread_setschedparam( me, SCHED_OTHER, ADDRESSOF( param ) );

		ASSERT( pthread_setspecific( thread_exit, ADDRESSOF( state ) ) = 0 );
		IF sigsetjmp( ADDRESSOF( state ), 0 ) = 0 THEN proc() END;

		RETURN NIL;
	END Starter;

	PROCEDURE ThrStart*( p: PROCEDURE; stackSize: SIZE ): Thread_t;
	VAR
		attr: PthreadAttributeDesc;
		id: Thread_t;
		res: INTEGER;
	BEGIN
		pthread_attr_init( ADDRESSOF( attr ) );
		pthread_attr_setscope( ADDRESSOF( attr ), PTHREAD_SCOPE_SYSTEM);
		pthread_attr_setdetachstate( ADDRESSOF( attr ), PTHREAD_CREATE_DETACHED);
		pthread_attr_setstacksize( ADDRESSOF( attr ), stackSize);
		res := pthread_create( ADDRESSOF( id ), ADDRESSOF( attr ), Starter, p);
		RETURN id;
	END ThrStart;

	PROCEDURE ThrSleep*( ms: SIGNED32 );
	VAR
		sltime, rem: RECORD
			tv_sec: LONGINTEGER;        (* seconds *)
         		tv_nsec: LONGINTEGER;       (* nanoseconds *)
     	END;
	BEGIN
		sltime.tv_sec := ms DIV 1000;
		sltime.tv_nsec := 1000000*(ms MOD 1000);
		WHILE nanosleep( ADDRESSOF( sltime ), ADDRESSOF( rem ) ) < 0 DO
			(* check error ! *)
			sltime := rem;
		END;
	END ThrSleep;


	PROCEDURE NanoSleep*( ns: LONGINTEGER );
	VAR
		sltime, rem: RECORD
			tv_sec: LONGINTEGER;        (* seconds *)
			tv_nsec: LONGINTEGER;       (* nanoseconds *)
     	END;
	BEGIN {UNTRACKED}
		sltime.tv_sec := ns DIV 1000000000;
		sltime.tv_nsec := ns MOD 1000000000;
		WHILE nanosleep( ADDRESSOF( sltime ), ADDRESSOF( rem ) ) < 0 DO
			(* check error ! *)
			sltime := rem;
		END;
	END NanoSleep;


	PROCEDURE ThrKill*( thr: Thread_t );
	BEGIN
		IF (thr # mainthread) THEN
		    	pthread_detach( thr );
		    	IF (thr = pthread_self( )) THEN
		    		ThrExit
			ELSE
		    		pthread_cancel( thr );
		    	END
		END;
	END ThrKill;

	PROCEDURE ThrThis*( ): Thread_t;
	BEGIN
		RETURN pthread_self( );
	END ThrThis;

	PROCEDURE ThrYield*( );
	BEGIN
		ThrSleep( 1 );
	END ThrYield;

	PROCEDURE ThrExit*( );
	BEGIN
		siglongjmp( pthread_getspecific( thread_exit ), 1 )
	END ThrExit;

	PROCEDURE ThrSetPriority*( thr: Thread_t; prio: SIGNED32 );
	VAR
		param: Sched_param;
		policy, r: SIGNED32;
	BEGIN
	(*	r := pthread_getschedparam( thr, ADDRESSOF( policy ), ADDRESSOF( param ) );
		param.sched_priority := prio;
		IF pthread_setschedparam( thr, SCHED_OTHER, ADDRESSOF( param ) ) # 0 THEN
			Perror( "pthread_setschedparam" );
		END	*)
	END ThrSetPriority;

	PROCEDURE ThrGetPriority*( thr: Thread_t ):SIGNED32;
	VAR
		param: Sched_param;
		policy, r: SIGNED32;
	BEGIN
	    r := pthread_getschedparam( thr, ADDRESSOF( policy ), ADDRESSOF( param ) );
	    RETURN  param.sched_priority;
	END ThrGetPriority;


	PROCEDURE NewMtx*( ): Mutex_t;
	VAR
		mtx: Mutex_t;
	BEGIN
		mtx := malloc(SIZEOF(MutexDesc));
		ASSERT(mtx # 0);
		ASSERT(pthread_mutex_init(mtx, NIL) = 0);
		RETURN mtx;
	END NewMtx;

	PROCEDURE NewRecursiveMtx*( ): Mutex_t;
	VAR
		mtx: Mutex_t;
		attr: MutexAttributeDesc;
		r: SIGNED32;
	CONST
		PTHREAD_MUTEX_RECURSIVE = 4;
	BEGIN
		mtx := malloc( SIZEOF( MutexDesc ) );
		r := pthread_mutexattr_init( ADDRESSOF( attr ) );
		r := pthread_mutexattr_settype( ADDRESSOF( attr ), PTHREAD_MUTEX_RECURSIVE );

		ASSERT( mtx # 0 );
		ASSERT( pthread_mutex_init( mtx, ADDRESSOF( attr ) ) = 0);
		RETURN mtx;
	END NewRecursiveMtx;

	PROCEDURE MtxDestroy*( mtx: Mutex_t );
	BEGIN
		ASSERT( pthread_mutex_destroy( mtx ) = 0 );
	END MtxDestroy;

	PROCEDURE MtxLock*( mtx: Mutex_t );
	BEGIN
		ASSERT( pthread_mutex_lock( mtx ) = 0 );
	END MtxLock;

	PROCEDURE MtxUnlock*( mtx: Mutex_t );
	BEGIN
		ASSERT( pthread_mutex_unlock( mtx ) = 0 );
	END MtxUnlock;


	PROCEDURE NewCond* ( ): Condition_t;
	VAR cond: Condition_t;
	BEGIN
		cond := malloc( SIZEOF( ConditionDesc ) );
		ASSERT( cond # 0 );
		ASSERT( pthread_cond_init( cond, NIL ) = 0 );
		RETURN cond;
	END NewCond;

	PROCEDURE CondDestroy*( con: Condition_t );
	BEGIN
		ASSERT( pthread_cond_destroy( con ) = 0 );
	END CondDestroy;

	PROCEDURE CondWait*( con: Condition_t; mtx: Mutex_t );
	BEGIN
		ASSERT( pthread_cond_wait( con, mtx ) = 0 );
	END CondWait;

	PROCEDURE CondSignal*( cond: Condition_t );
	BEGIN
		ASSERT( pthread_cond_signal( cond ) = 0 );
	END CondSignal;


	(*-------------------------------------------------------------------------------------------------------------*)


	PROCEDURE {C} X11ErrorHandler( d: ADDRESS; err: ADDRESS ): INTEGER;
	VAR res: INTEGER;
	BEGIN
		IF oberonXErrorHandler # NIL THEN
			res := oberonXErrorHandler( d, err );
		END;
		RETURN 0;
	END X11ErrorHandler;

	PROCEDURE {C} X11IOErrorHandler( d: ADDRESS ): INTEGER;
	VAR res: INTEGER;
	BEGIN
		IF oberonXIOErrorHandler # NIL THEN
			res := oberonXIOErrorHandler( d );
		END;
		RETURN 0;
	END X11IOErrorHandler;

	PROCEDURE InitXErrorHandlers*( xErrorHandler: OberonXErrorHandler; xIOErrorHandler: OberonXIOErrorHandler );
	VAR res: INTEGER;
	BEGIN
		oberonXErrorHandler := xErrorHandler;
		oberonXIOErrorHandler := xIOErrorHandler;
		res := xSetErrorHandler( ADDRESSOF( X11ErrorHandler ) );
		res := xSetIOErrorHandler( ADDRESSOF( X11IOErrorHandler ) );
	END InitXErrorHandlers;


	(*-------------------------------------------------------------------------------------------------------------*)


	PROCEDURE Dlsym*( lib: ADDRESS;  CONST sym: ARRAY OF CHAR;  objAddr: ADDRESS );
	VAR val: SIGNED32;
	BEGIN
		Glue.Dlsym( lib, sym, objAddr );
		S.GET( objAddr, val );
		IF val = 0 THEN
			Trace.String( "Unix.Dlsym:  entry '" );  Trace.String( sym );  Trace.String( "' not found" );
			Trace.Ln;
		END
	END Dlsym;

	PROCEDURE Dlopen*( CONST libname: ARRAY OF CHAR;  mode: SIGNED32 ): ADDRESS;
	VAR h: ADDRESS;  i, j, k: SIGNED16;
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
			Trace.String( libname );  Trace.String( " failed" );  Trace.Ln
		END;
		RETURN h
	END Dlopen;

	PROCEDURE Dlclose*( lib: ADDRESS );
	BEGIN
		Glue.dlclose( lib )
	END Dlclose;

	PROCEDURE GetArg*( no: SIGNED32;  VAR val: ARRAY OF CHAR );
	VAR ch: CHAR;  adr: ADDRESS;  i: SIGNED32;
	BEGIN
		IF no >= argc THEN  val[0] := 0X
		ELSE
			S.GET( argv + SIZEOF(ADDRESS)*no, adr );  i := 0;
			REPEAT  S.GET( adr, ch );  val[i] := ch;  INC( adr );  INC( i );   UNTIL (ch = 0X) OR (i >= LEN( val ));
		END
	END GetArg;

	PROCEDURE GetArgval*(  CONST argName: ARRAY OF CHAR;  VAR val: ARRAY OF CHAR );
	VAR i: SIGNED16;
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
	VAR res: INTEGER;  p: SIGNED16;
		buf: ARRAY 4096 OF CHAR;

		PROCEDURE copy( VAR p: SIGNED16;  VAR dest: ARRAY OF CHAR );
		VAR i: SIGNED16;
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
	BEGIN
		argc := Glue.argc;
		argv := Glue.argv;
		environ := Glue.environ;

	#IF I386 THEN
		libraryPaths[0] := "/usr/lib";
		libraryPaths[1] := "/lib";
		libraryPaths[2] := "/usr/openwin/lib";
		noPaths := 3;
	#ELSIF AMD64 THEN
		libraryPaths[0] := "/usr/lib/64";
		libraryPaths[1] := "/lib/64";
		noPaths := 2;
	#ELSE
		unimplemented
	#END

		libc := Dlopen( libcname, 2 );
		libp := Dlopen( libpthreadname, 2 );

		Dlsym( libc, "exit",		ADDRESSOF( exit ) );
		Dlsym( libc, "sysconf", ADDRESSOF( sysconf ) );

		Dlsym( libc, "pthread_mutex_init", ADDRESSOF( pthread_mutex_init ) );
		Dlsym( libc, "pthread_mutex_destroy", ADDRESSOF( pthread_mutex_destroy ) );
		Dlsym( libc, "pthread_mutex_lock", ADDRESSOF( pthread_mutex_lock ) );
		Dlsym( libc, "pthread_mutex_unlock", ADDRESSOF( pthread_mutex_unlock ) );

		Dlsym( libp, "pthread_mutexattr_init", ADDRESSOF( pthread_mutexattr_init ) );
		Dlsym( libp, "pthread_mutexattr_settype", ADDRESSOF( pthread_mutexattr_settype ) );

		Dlsym( libc, "pthread_cond_init", ADDRESSOF( pthread_cond_init ) );
		Dlsym( libc, "pthread_cond_destroy", ADDRESSOF( pthread_cond_destroy ) );
		Dlsym( libc, "pthread_cond_wait", ADDRESSOF( pthread_cond_wait ) );
		Dlsym( libc, "pthread_cond_signal", ADDRESSOF( pthread_cond_signal ) );

		Dlsym( libp, "pthread_create", ADDRESSOF( pthread_create ) );
		Dlsym( libp, "pthread_exit", ADDRESSOF( pthread_exit ) );
		Dlsym( libp, "pthread_detach", ADDRESSOF( pthread_detach ) );
		Dlsym( libp, "pthread_cancel", ADDRESSOF( pthread_cancel ) );
		Dlsym( libp, "pthread_kill", ADDRESSOF( pthread_kill ) );

		Dlsym( libp, "pthread_key_create", ADDRESSOF( pthread_key_create ) );
		Dlsym( libp, "pthread_getspecific", ADDRESSOF( pthread_getspecific ) );
		Dlsym( libp, "pthread_setspecific", ADDRESSOF( pthread_setspecific ) );

		Dlsym( libp, "pthread_sigmask", ADDRESSOF( pthread_sigmask ) );
		Dlsym( libp, "pthread_setcancelstate", ADDRESSOF( pthread_setcancelstate ) );
		Dlsym( libp, "pthread_setcanceltype", ADDRESSOF( pthread_setcanceltype ) );
		Dlsym( libp, "pthread_attr_init", ADDRESSOF( pthread_attr_init ) );
		Dlsym( libp, "pthread_attr_setscope", ADDRESSOF( pthread_attr_setscope ) );
		Dlsym( libp, "pthread_attr_setdetachstate", ADDRESSOF( pthread_attr_setdetachstate ) );
		Dlsym( libp, "pthread_attr_setstacksize", ADDRESSOF( pthread_attr_setstacksize ) );
		Dlsym( libp, "pthread_self", ADDRESSOF( pthread_self ) );

		Dlsym( libc, "thr_suspend", ADDRESSOF( thr_suspend ) );
		Dlsym( libc, "thr_continue", ADDRESSOF( thr_continue ) );

		Dlsym( libc, "posix_spawnp",	ADDRESSOF( posix_spawnp ) );
		Dlsym( libc, "posix_spawn",	ADDRESSOF( posix_spawn ) );

		Dlsym( libc, "waitpid",	ADDRESSOF( waitpid ) );
		Dlsym( libc, "pipe",		ADDRESSOF( pipe ) );
		Dlsym( libc, "dup2",		ADDRESSOF( dup2 ) );
		Dlsym( libc, "dup",		ADDRESSOF( dup ) );

		Dlsym( libc, "sched_get_priority_max",	ADDRESSOF( sched_get_priority_max ) );
		Dlsym( libc, "sched_get_priority_min",	ADDRESSOF( sched_get_priority_min ) );
		Dlsym( libc, "pthread_setschedparam",		ADDRESSOF( pthread_setschedparam ) );
		Dlsym( libc, "pthread_getschedparam",		ADDRESSOF( pthread_getschedparam ) );
		Dlsym( libc, "sigaction",		ADDRESSOF( sigaction ) );
		Dlsym( libc, "sigemptyset",	ADDRESSOF( sigemptyset ) );
		Dlsym( libc, "sigfillset",		ADDRESSOF( sigfillset ) );
		Dlsym( libc, "sigaddset",		ADDRESSOF( sigaddset ) );
		Dlsym( libc, "sigdelset",		ADDRESSOF( sigdelset ) );
		Dlsym( libc, "nanosleep",		ADDRESSOF( nanosleep ) );
		Dlsym( libc, "sigaltstack",	ADDRESSOF( sigaltstack ) );
		Dlsym( libc, "sigsuspend",		ADDRESSOF( sigsuspend ) );


		Dlsym( libc, "read",			ADDRESSOF( read ) );
		Dlsym( libc, "write",		ADDRESSOF( write ) );
		Dlsym( libc, "open",			ADDRESSOF( open ) );
		Dlsym( libc, "close",		ADDRESSOF( close ) );
		Dlsym( libc, "lseek",		ADDRESSOF( lseek ) );
		Dlsym( libc, "fsync",		ADDRESSOF( fsync ) );
		Dlsym( libc, "ioctl",		ADDRESSOF( ioctl ) );
		Dlsym( libc, "unlink",		ADDRESSOF( unlink ) );
		Dlsym( libc, "rename",		ADDRESSOF( rename ) );
		Dlsym( libc, "ftruncate",	ADDRESSOF( ftruncate ) );
		Dlsym( libc, "chmod",		ADDRESSOF( chmod ) );
		Dlsym( libc, "utime",		ADDRESSOF( utime ) );
		Dlsym( libc, "access",		ADDRESSOF( access ) );
		Dlsym( libc, "select",		ADDRESSOF( select ) );
		Dlsym( libc, "realpath",	ADDRESSOF( realpath ) );

		Dlsym( libc, "chdir",		ADDRESSOF( chdir ) );
		Dlsym( libc, "mkdir",		ADDRESSOF( mkdir ) );
		Dlsym( libc, "rmdir",		ADDRESSOF( rmdir ) );

		Dlsym( libc, "stat",			ADDRESSOF( stat ) );
		Dlsym( libc, "lstat",		ADDRESSOF( lstat ) );
		Dlsym( libc, "fstat",		ADDRESSOF( fstat ) );

		Dlsym( libc, "getpid",		ADDRESSOF( getpid ) );
		Dlsym( libc, "getuid",		ADDRESSOF( getuid ) );

		Dlsym( libc, "alarm",		ADDRESSOF( alarm ) );
		Dlsym( libc, "setitimer",	ADDRESSOF( setitimer ) );
		Dlsym( libc, "getitimer",	ADDRESSOF( getitimer ) );

		Dlsym( libc, "gettimeofday",	ADDRESSOF( gettimeofday ) );
		Dlsym( libc, "mktime",			ADDRESSOF( mktime ) );
		Dlsym( libc, "localtime",		ADDRESSOF( localtime ) );
		Dlsym( libc, "time",				ADDRESSOF( time ) );
		Dlsym( libc, "times",			ADDRESSOF( times ) );

		Dlsym( libc, "getcwd",		ADDRESSOF( getcwd ) );
		Dlsym( libc, "getenv",		ADDRESSOF( getenv ) );

		Dlsym( libc, "opendir",		ADDRESSOF( opendir ) );
		Dlsym( libc, "readdir",		ADDRESSOF( readdir ) );
		Dlsym( libc, "closedir",	ADDRESSOF( closedir ) );

		Dlsym( libc, "sigsetjmp",		ADDRESSOF( sigsetjmp ) );
		Dlsym( libc, "siglongjmp",		ADDRESSOF( siglongjmp ) );

		Dlsym( libc, "malloc",			ADDRESSOF( malloc ) );
		Dlsym( libc, "posix_memalign",	ADDRESSOF( posix_memalign ) );
		Dlsym( libc, "free",				ADDRESSOF( free ) );
		Dlsym( libc, "mprotect",		ADDRESSOF( mprotect ) );

		Dlsym( libc, "system",	ADDRESSOF( system ) );
		Dlsym( libc, "uname",	ADDRESSOF( uname ) );

		Dlsym( libc, "kill",		ADDRESSOF( kill ) );
		Dlsym( libc, "exit",		ADDRESSOF( exit ) );
		Dlsym( libc, "perror",	ADDRESSOF( perror ) );
		Dlsym( libc, "___errno",	ADDRESSOF( errno_location ) );


		getSysinfo;

		InstallHandler( SIGUSR1 )
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
