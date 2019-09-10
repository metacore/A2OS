(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Traps;  (** AUTHOR "G.F."; PURPOSE "Exception Trap and symbolic debugging"; *)

(* 2000.02.06	g.f.	UnixOberon release 2.3.6d	*)
(* 2006.07.09	g.f.	UnixAos version	*)

IMPORT S := SYSTEM, Unix, Objects, Machine, Streams, Modules, Reflection,
		TrapWriters, Commands, StdIO;

CONST
	AddrSize = SIZEOF( ADDRESS );
	MaxRecursion = 2;
TYPE

	ExceptionHandler = RECORD  pc, fp, sp: ADDRESS  END;

VAR

	trapHandlingLevel: SIGNED32;

	trace: BOOLEAN;

	unix: Commands.Context;
	trapMutex: Unix.Mutex_t;

	PROCEDURE LockTrap;
	BEGIN
		Unix.MtxLock( trapMutex );
	END LockTrap;

	PROCEDURE UnlockTrap;
	BEGIN
		trapHandlingLevel := 0;
		Unix.MtxUnlock( trapMutex )
	END UnlockTrap;

	PROCEDURE Append( VAR ar: ARRAY OF CHAR;  CONST this: ARRAY OF CHAR );
	VAR i, j: SIGNED32;
	BEGIN
		i := 0;  j := 0;
		WHILE ar[i] # 0X DO  INC( i )  END;
		WHILE (i < LEN( ar ) - 1) & (this[j] # 0X) DO  ar[i] := this[j];  INC( i );  INC( j )  END;
		ar[i] := 0X
	END Append;


	PROCEDURE TimeTag( w: Streams.Writer );
	VAR
		tv: Unix.Timeval;  tz: Unix.Timezone;  t: Unix.TmPtr;  ret: SIGNED32;

		PROCEDURE Int( i: SIGNED32 );
		BEGIN
			IF i < 10 THEN  w.Char( '0' )  END;
			w.Int( i, 0 )
		END Int;

	BEGIN
		ret := Unix.gettimeofday( tv, tz );
		t := Unix.localtime( tv );
		w.Int( 1900 + t.year, 4 );  w.Char( '/' );  Int( t.mon + 1 );  w.Char( '/' );  Int( t.mday );
		w.String( "  " );  Int( t.hour );  w.Char( ':' );  Int( t.min );  w.Ln;
	END TimeTag;



	PROCEDURE FinishTrap( w: Streams.Writer;  p: Objects.Process );
	VAR tag: ADDRESS;  td: Modules.TypeDesc;  name: ARRAY 72 OF CHAR;
	BEGIN
		w.Char( 2X );   (* end of trap text *)
		w.Update;

		TrapWriters.Trapped;

		IF p.obj = NIL THEN	(* the main thread is not associated with any object *)
			Unix.exit( -1 )
		ELSE
			S.GET( S.VAL( ADDRESS, p.obj ) - AddrSize, tag );
			S.GET( tag - AddrSize, td );
			IF td.mod # NIL THEN
				COPY( td.mod.name, name );  Append( name,  "." );  Append( name, td.name );
				IF name = "Oberon-System.OberonRunner" THEN  UnlockOberon  END
			END
		END;


	END FinishTrap;

	PROCEDURE Register(w: Streams.Writer; CONST name: ARRAY OF CHAR; value: ADDRESS);
	BEGIN
		w.String(name); w.String(" = "); w.Address(value); w.String(" ");
	END Register;

	PROCEDURE Registers( CONST mc: Unix.Mcontext; w: Streams.Writer );
	BEGIN
		Register(w,"SP",mc.r_sp);
		Register(w,"FP",mc.r_bp);
		Register(w,"PC",mc.r_pc);
		w.Ln;
		w.Ln;
		#IF I386 THEN
			Register(w,"EAX",mc.r_ax);
			Register(w,"EBX",mc.r_bx);
			Register(w,"ECX",mc.r_cx);
			Register(w,"EDX",mc.r_dx);
			w.Ln;
			Register(w,"ESI",mc.r_si);
			Register(w,"EDI",mc.r_di);
			w.Ln;
		#ELSIF AMD64 THEN
			Register(w,"RAX",mc.r_ax);
			Register(w,"RBX",mc.r_bx);
			Register(w,"RCX",mc.r_cx);
			Register(w,"RDX",mc.r_dx);
			w.Ln;
			Register(w,"RSI",mc.r_si);
			Register(w,"RDI",mc.r_di);
			Register(w,"R8",mc.r_8);
			Register(w,"R9",mc.r_9);
			w.Ln;
			Register(w,"R10",mc.r_10);
			Register(w,"R11",mc.r_11);
			Register(w,"R12",mc.r_12);
			Register(w,"R13",mc.r_13);
			w.Ln;
			Register(w,"R14",mc.r_14);
			Register(w,"R15",mc.r_15);
			w.Ln;
		#ELSE
			unimplemented
		#END
	END Registers;


	PROCEDURE Trap( sig: SIGNED32;  mc: Unix.Mcontext);
	VAR
		pc, sp, bp: ADDRESS;
		trapno: SIGNED32;
		process: Objects.Process;
		handler: ExceptionHandler;
		w: Streams.Writer;
	BEGIN
		IF sig IN {1, 2, 14, 15} (* SIGHUP, SIGINT, SIGALRM, SIGTERM *) THEN
			(* ignore *) RETURN
		END;

		LockTrap;

		INC( trapHandlingLevel );
		IF trapHandlingLevel > MaxRecursion THEN
			UnlockTrap;
			Objects.Terminate
		END;

		w := TrapWriters.GetWriter();
		w.Char( 1X );   (* begin of trap text *)

		w.Ln;
		w.String( Machine.version ); w.String( "   " );  TimeTag( w );  w.Ln;
		IF trapHandlingLevel = 1 THEN
			w.String( "Trap " );
		ELSE
			w.String( "[Recursive Trap] " );
		END;
		CASE sig OF
		| 1:		w.String( "1 (Hangup signal)" );
		| 2:  	w.String( "2 (User interrupt)" );
		| 3:		w.String( "3 (Quit signal)" );
		| 4:  	w.String( "4 (Illegal instruction)" );
		| 5:   	w.String( "5." );
				S.GET( mc.r_sp, trapno );  w.Int( trapno, 0 );
				CASE trapno OF
				| 1:		w.String( "  (WITH guard failed)" )
				| 2:		w.String( "  (CASE invalid)" )
				| 3:		w.String( "  (RETURN missing)" )
				| 5:		w.String( "  (implicit type guard failed)" )
				| 6:		w.String( "  (type guard failed)" )
				| 7:		w.String( "  (index out of range)" )
				| 8:		w.String( "  (ASSERT failed)" )
				| 9:		w.String( "  (array dimension error)" )
				|12:	w.String( "  (division error)" )
				ELSE
					IF trapno >= 30 THEN  w.String( "  (programmed HALT)" )
					ELSE  w.String( "  (unknown exception)" )
					END
				END;
		| Unix.SIGBUS:  w.Int( sig, 0 );  w.String( " (Bus Error)" )
		| Unix.SIGFPE:  w.Int( sig, 0 );  w.String( " (Arithmetic exception)" );
		| 11:	w.String( "11 (Segmentation violation)" )
		| 13:	w.String( "13 (Broken pipe)" )
		| 14:	w.String( "14 (Alarm signal)" )
		ELSE
			w.String( "(Signal " );  w.Int( sig, 0 );  w.Char( ')' );
		END;
		w.Ln; w.Ln;
		Registers( mc, w );
		w.Ln;

		process := Objects.CurrentProcess( );
		sp := mc.r_sp;  pc := mc.r_pc;  bp := mc.r_bp;
		IF pc = 0 THEN
			(* assume call of procedure variable with value NIL *)
			S.GET( sp, pc );   (* get return address on top of stack *)
		END;

		IF (sig = 5) & (trapno = 3) THEN DEC (pc) END;

		IF process # NIL THEN
			Reflection.StackTraceBack( w, pc, bp, sp, Objects.GetStackBottom( process ), TRUE, FALSE );
			SearchExceptionHandler( process, mc, handler );
		ELSE
			(* avoid recusive trap in case of faulty module Objects *)
			Reflection.StackTraceBack( w, pc, bp, sp, sp+512, TRUE, FALSE );
			END;
		w.Ln; w.Ln;
		w.String("----------------------------------------------------"); w.Ln;

		FinishTrap( w, process);

		UnlockTrap;

		IF handler.pc # 0 THEN
			w.Ln;
			w.String( "### program continues with exception handler ###" );   w.Ln;

			Unix.ModifyContext( mc, handler.pc, handler.fp, handler.sp );
			RETURN  (*! to exception handler !! *)
		END;

		Objects.ExitTrap;
	END Trap;


	PROCEDURE UnlockOberon;
	CONST OberonKernel = "Oberon-Kernel";
	VAR c: PROCEDURE;
	BEGIN
		IF Modules.ModuleByName( OberonKernel ) # NIL THEN
			GETPROCEDURE( OberonKernel, "UnlockOberon", c );
			IF c # NIL THEN  c  END
		END;
	END UnlockOberon;

	PROCEDURE SearchExceptionHandler( process: Objects.Process;  mc: Unix.Mcontext;  VAR handler: ExceptionHandler );
	VAR entry, fp, sp, pc: ADDRESS;
	BEGIN
		handler.pc := 0;  (* no handler *)
		pc := mc.r_pc;  fp := mc.r_bp;  sp := mc.r_sp;
		IF pc = 0 THEN
			(* assume call of procedure variable with value NIL *)
			S.GET( sp, pc );   (* get return address on top of stack *)
		END;
		entry := Modules.GetExceptionHandler( pc );
		WHILE (entry = -1) & (fp <= process.stackBottom) & (fp#0) & (fp MOD SIZEOF(ADDRESS)=0) DO
			S.GET( fp + AddrSize, pc );
			pc := pc - 1;   (*  CALL instruction, machine dependent!!! *)
			entry := Modules.GetExceptionHandler( pc );
			sp := fp;   (* Save the old framepointer into the stack pointer *)
			S.GET( fp, fp ) (* Unwind PAF *)
		END;
		IF entry # -1 THEN
			handler.pc := entry;  handler.fp := fp;  handler.sp := sp
		END
	END SearchExceptionHandler;


BEGIN
	trapMutex := Unix.NewRecursiveMtx( );
	trace := FALSE;
	Unix.InstallTrap( Trap );
	Unix.HandleSignal( Unix.SIGILL ); (* illegal instruction *)
	Unix.HandleSignal( Unix.SIGTRAP ); (* exception *)
	Unix.HandleSignal( Unix.SIGBUS ); (* bus error *)
	Unix.HandleSignal( Unix.SIGFPE ); (* erroneous arithmetics *)
	Unix.HandleSignal( Unix.SIGSEGV ); (* segmentation fault *)
	unix := StdIO.env
END Traps.
