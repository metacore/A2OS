(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE DataErrors;   (** AUTHOR "adf, fof"; PURPOSE "For reporting runtime warnings & errors into file Error.Log"; *)

(**  Error.Log is an error log file that can be viewed with any ASCII editor, and is overwritten with each session.
	If no errors or warnings were logged, the file will be empty.  File Error.Log is automatically opened/closed whenever
	module DataErrors.Mod is loaded-into/freed-from the system.  The Error.Log file from the previous session is saved in
	file Error.Log.Bak.

	Logging of the first error message of a session produces an audible SOS beep to inform the user to check this file.
	Logging of the first warning message of a session produces just 3 beeps (instead of 9) in the SOS tone sequence.

	Errors are for catostropic events, e.g., division by zero.
	Warnings are for non-optimal events, e.g., a series did not converge. *)

IMPORT SYSTEM, Machine, Kernel, Modules, Files, Beep, NbrInt, NbrRat, NbrRe, NbrCplx;

VAR
	beepedError, beepedWarning: BOOLEAN;  F: Files.File;  W: Files.Writer;


	(***! BEGIN part from Traps, todo: simplify and adjust to needs *)
TYPE
	Variable = RECORD
		adr, type, size, n, tdadr: SIGNED32
	END;   (* variable descriptor *)
CONST
	MaxString = 64;  MaxArray = 8;  MaxCols = 70;  Sep = "  ";  SepLen = 2;

	(* Write the specified procedure name and returns parameters for use with NextVar and Variables. *)
	(* Find a procedure in the reference block.  Return index of name, or -1 if not found. *)
	PROCEDURE FindProc( refs: Modules.Bytes;  modpc: SIGNED32 ): SIGNED32;
	VAR i, m, t, proc: SIGNED32;  ch: CHAR;
	BEGIN
		proc := -1;  i := 0;  m := LEN( refs^ )(SIGNED32);  ch := refs[i];  INC( i );
		WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) DO  (* proc *)
			GetNum( refs, i, t );   (* pofs *)
			IF t > modpc THEN  (* previous procedure was the one *)
				ch := 0X (* stop search *)
			ELSE  (* ~found *)
				IF ch = 0F9X THEN
					GetNum( refs, i, t );   (* nofPars *)
					INC( i, 3 ) (* RetType, procLev, slFlag *)
				END;
				proc := i;   (* remember this position, just before the name *)
				REPEAT ch := refs[i];  INC( i ) UNTIL ch = 0X;   (* pname *)
				IF i < m THEN
					ch := refs[i];  INC( i );   (* 1X | 3X | 0F8X | 0F9X *)
					WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO  (* var *)
						ch := refs[i];  INC( i );   (* type *)
						IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
							GetNum( refs, i, t ) (* dim/tdadr *)
						END;
						GetNum( refs, i, t );   (* vofs *)
						REPEAT ch := refs[i];  INC( i ) UNTIL ch = 0X;   (* vname *)
						IF i < m THEN ch := refs[i];  INC( i ) END  (* 1X | 3X | 0F8X | 0F9X *)
					END
				END
			END
		END;
		IF (proc = -1) & (i # 0) THEN proc := i END;   (* first procedure *)
		RETURN proc
	END FindProc;

	PROCEDURE WriteProc0( mod: Modules.Module;  pc, fp: SIGNED32;  VAR refs: Modules.Bytes;  VAR refpos, base: SIGNED32 );
	VAR ch: CHAR;
	BEGIN
		refpos := -1;
		IF mod = NIL THEN
			IF pc = 0 THEN W.String( "NIL" ) ELSE W.String( "Unknown PC=" );  W.Hex( pc, 8 );  W.Char( "H" ) END;
			IF fp # -1 THEN W.String( " FP=" );  W.Hex( fp, 8 );  W.Char( "H" ) END
		ELSE
			W.String( mod.name );  DEC( pc, SIGNED32(ADDRESSOF( mod.code[0] )) );  refs := mod.refs;
			IF (refs # NIL ) & (LEN( refs ) # 0) THEN
				refpos := FindProc( refs, pc );
				IF refpos # -1 THEN
					W.Char( "." );  ch := refs[refpos];  INC( refpos );
					IF ch = "$" THEN base := SIGNED32(mod.sb) ELSE base := fp END;   (* for variables *)
					WHILE ch # 0X DO W.Char( ch );  ch := refs[refpos];  INC( refpos ) END
				END
			END;
			W.String( " pc=" );  W.Int( pc, 1 )
		END
	END WriteProc0;

(* Find procedure name and write it. *)
	PROCEDURE WriteProc( pc: SIGNED32 );
	VAR refs: Modules.Bytes;  refpos, base: SIGNED32;
	BEGIN
		WriteProc0( Modules.ThisModuleByAdr( pc ), pc, -1, refs, refpos, base )
	END WriteProc;
(* Write a simple variable value. *)

	PROCEDURE WriteSimpleVar( adr, type, tdadr: SIGNED32;  VAR col: SIGNED32 );
	VAR ch: CHAR;  sval: SIGNED8;  ival: SIGNED16;  lval: SIGNED32;
	BEGIN
		CASE type OF
		1, 3:  (* BYTE, CHAR *)
				SYSTEM.GET( adr, ch );
				IF (ch > " ") & (ch <= "~") THEN W.Char( ch );  INC( col ) ELSE W.Hex( ORD( ch ), -2 );  W.Char( "X" );  INC( col, 3 ) END
		| 2:    (* BOOLEAN *)
				SYSTEM.GET( adr, ch );
				IF ch = 0X THEN W.String( "FALSE" )
				ELSIF ch = 1X THEN W.String( "TRUE" )
				ELSE W.Int( ORD( ch ), 1 )
				END;
				INC( col, 5 )
		| 4:    (* SIGNED8 *)
				SYSTEM.GET( adr, sval );
				W.Int( sval, 1 );  INC( col, 4 )
				(*Streams.WriteString(w, " ("); Streams.WriteHex(w, sval, -3); Streams.WriteString(w, "H)")*)
		| 5:    (* SIGNED16 *)
				SYSTEM.GET( adr, ival );
				W.Int( ival, 1 );  INC( col, 5 )
				(*Streams.WriteString(w, " ("); Streams.WriteHex(w, ival, 8); Streams.WriteString(w, "H)")*)
		| 6:    (* SIGNED32 *)
				SYSTEM.GET( adr, lval );
				W.Int( lval, 1 );  INC( col, 5 );
				IF ABS( lval ) >= 10000H THEN W.String( " (" );  W.Hex( lval, 8 );  W.String( "H)" );  INC( col, 12 ) END
		| 7, 8, 13, 16, 29:  (* FLOAT32, FLOAT64, POINTER *)
				INC( col, 9 );
				IF (type = 8) OR (type = 16) THEN SYSTEM.GET( adr + 4, lval );  W.Hex( lval, 8 );  INC( col, 8 ) END;
				SYSTEM.GET( adr, lval );  W.Hex( lval, 8 );  W.Char( "H" )
		| 9:    (* SET *)
				SYSTEM.GET( adr, lval );
				W.Set( SET(lval ) );  INC( col, 8 ) (* col is guess *)
		| 22:  (* RECORD *)
				W.String( "Rec." );  W.Hex( tdadr, 8 );  W.Char( "H" );  INC( col, 13 )
		| 14:  (* PROC *)
				SYSTEM.GET( adr, lval );  WriteProc( lval );  INC( col, 25 )
		END
	END WriteSimpleVar;

(* Write a variable value.  The v parameter is a variable descriptor obtained with NextVar.  Parameter col is incremented with

		the (approximate) number of characters written. *)
	PROCEDURE WriteVar( v: Variable;  VAR col: SIGNED32 );
	VAR ch: CHAR;
	BEGIN
		IF v.type = 15 THEN
			W.Char( 22X );
			LOOP
				IF v.n = 0 THEN EXIT END;
				SYSTEM.GET( v.adr, ch );  INC( v.adr );
				IF (ch < " ") OR (ch > "~") THEN EXIT END;
				W.Char( ch );  INC( col );  DEC( v.n )
			END;
			W.Char( 22X );  INC( col, 2 );
			IF ch # 0X THEN W.Char( "!" ) END
		ELSE
			WHILE v.n > 0 DO
				WriteSimpleVar( v.adr, v.type, v.tdadr, col );  DEC( v.n );  INC( v.adr, v.size );
				IF v.n > 0 THEN W.String( ", " );  INC( col, 2 ) END
			END
		END
	END WriteVar;

(* Get a compressed refblk number. *)

	PROCEDURE GetNum( refs: Modules.Bytes;  VAR i, num: SIGNED32 );
	VAR n, s: SIGNED32;  x: CHAR;
	BEGIN
		s := 0;  n := 0;  x := refs[i];  INC( i );
		WHILE ORD( x ) >= 128 DO INC( n, ASH( ORD( x ) - 128, s ) );  INC( s, 7 );  x := refs[i];  INC( i ) END;
		num := n + ASH( ORD( x ) MOD 64 - ORD( x ) DIV 64 * 64, s )
	END GetNum;

(* Step to the next variable in the refs block.  The name parameter returns empty if no more variables are found.  The attributes

		are returned in v.  Parameter refpos is modified.  *)
	PROCEDURE NextVar( refs: Modules.Bytes;  VAR refpos: SIGNED32;  base: SIGNED32;  VAR name: ARRAY OF CHAR;  VAR v: Variable );
	VAR x: Variable;  j: SIGNED32;  ch, mode: CHAR;
	BEGIN
		name[0] := 0X;   (* empty name signals end or error *)
		IF refpos < LEN( refs^ ) - 1 THEN
			mode := refs[refpos];  INC( refpos );
			IF (mode >= 1X) & (mode <= 3X) THEN  (* var *)
				x.type := ORD( refs[refpos] );  INC( refpos );
				IF x.type > 80H THEN
					IF x.type = 83H THEN x.type := 15 ELSE DEC( x.type, 80H ) END;
					GetNum( refs, refpos, x.n )
				ELSIF (x.type = 16H) OR (x.type = 1DH) THEN GetNum( refs, refpos, x.tdadr );  x.n := 1
				ELSE
					IF x.type = 15 THEN x.n := MaxString (* best guess *) ELSE x.n := 1 END
				END;
				(* get address *)
				GetNum( refs, refpos, x.adr );
				INC( x.adr, base );   (* convert to absolute address *)
				IF x.n = 0 THEN  (* open array (only on stack, not global variable) *)
					SYSTEM.GET( x.adr + 4, x.n ) (* real LEN from stack *)
				END;
				IF mode # 1X THEN SYSTEM.GET( x.adr, x.adr ) END;   (* indirect *)
				(* get size *)
				CASE x.type OF
				1..4, 15:
						x.size := 1
				| 5:   x.size := 2
				| 6..7, 9, 13, 14, 29:
						x.size := 4
				| 8, 16:
						x.size := 8
				| 22:
						x.size := 0;
						ASSERT ( x.n <= 1 )
				ELSE x.size := -1
				END;
				IF x.size >= 0 THEN  (* ok, get name *)
					ch := refs[refpos];  INC( refpos );  j := 0;
					WHILE ch # 0X DO
						IF j < LEN( name ) - 1 THEN name[j] := ch;  INC( j ) END;   (* truncate long names *)
						ch := refs[refpos];  INC( refpos )
					END;
					name[j] := 0X;  v := x (* non-empty name *)
				END
			END
		END
	END NextVar;

(* Find the specified global variable and return its descriptor.  Returns TRUE iff the variable is found. *)
	PROCEDURE Variables( refs: Modules.Bytes;  refpos, base: SIGNED32 );
	VAR v: Variable;  j, col: SIGNED32;
		name: ARRAY 64 OF CHAR;
		etc: BOOLEAN;
	BEGIN
		LOOP
			NextVar( refs, refpos, base, name, v );
			IF name[0] = 0X THEN EXIT END;
			(* write name *)
			IF (col # 0) & (v.n > 1) & (v.type # 15) THEN  (* Ln before array (except string) *)
				W.Ln();  col := 0
			END;
			W.String( Sep );  W.String( name );  W.Char( "=" );  j := 0;
			WHILE name[j] # 0X DO INC( j ) END;
			INC( col, SepLen + 1 + j );
			(* write variable *)
			IF (v.adr >= -4) & (v.adr < 4096) THEN  (* must be NIL VAR parameter *)
				W.String( "NIL (" );  W.Hex( v.adr, 8 );  W.Char( ")" );  INC( col, 14 )
			ELSE
				etc := FALSE;
				IF v.type = 15 THEN
					IF v.n > MaxString THEN etc := TRUE;  v.n := MaxString END
				ELSE
					IF v.n > MaxArray THEN etc := TRUE;  v.n := MaxArray END
				END;
				WriteVar( v, col );   (* write value *)
				IF etc THEN W.String( "..." );  INC( col, 3 ) END
			END;
			IF col > MaxCols THEN W.Ln();  col := 0 END
		END;
		IF col # 0 THEN W.Ln() END
	END Variables;

	PROCEDURE InitVar( mod: Modules.Module;  VAR refs: Modules.Bytes;  VAR refpos, base: SIGNED32 );
	VAR ch: CHAR;
	BEGIN
		refpos := -1;
		IF mod # NIL THEN
			refs := mod.refs;  base := SIGNED32(mod.sb);
			IF (refs # NIL ) & (LEN( refs ) # 0) THEN
				refpos := FindProc( refs, 0 );
				IF refpos # -1 THEN
					ch := refs[refpos];  INC( refpos );
					WHILE ch # 0X DO ch := refs[refpos];  INC( refpos ) END
				END
			END
		END
	END InitVar;

	PROCEDURE ModuleState( mod: Modules.Module );
	VAR refpos, base: SIGNED32;  refs: Modules.Bytes;
	BEGIN
		InitVar( mod, refs, refpos, base );
		IF refpos # -1 THEN W.String( "State " );  W.String( mod.name );  W.Char( ":" );  W.Ln();  Variables( refs, refpos, base ) END
	END ModuleState;

(* Display call trackback. *)

	PROCEDURE StackTraceBack( eip, ebp: SIGNED32;  long: BOOLEAN );
	VAR count, refpos, base: SIGNED32;  m: Modules.Module;  refs: Modules.Bytes;
	CONST MaxFrames = 16;
	BEGIN
		count := 0;   (* frame count *)
		REPEAT
			m := Modules.ThisModuleByAdr( eip );
			IF (m # NIL ) OR (count = 0) THEN
				WriteProc0( m, eip, ebp, refs, refpos, base );  W.Ln();
				IF long & ((count > 0)) THEN  (* show variables *)
					IF refpos # -1 THEN Variables( refs, refpos, base ) END;
					IF (m # NIL ) & (base # m.sb) & (count = 0) THEN ModuleState( m ) END
				END;
				SYSTEM.GET( ebp + 4, eip );   (* return addr from stack *)
				SYSTEM.GET( ebp, ebp );   (* follow dynamic link *)
				INC( count )
			ELSE ebp := 0
			END
		UNTIL (ebp = 0) OR (count = MaxFrames);
		IF ebp # 0 THEN W.String( "..." ) END
	END StackTraceBack;
	(***! END part from Traps *)

(* From antsPortability *)
	PROCEDURE ErrorCaller( VAR m: Modules.Module;  VAR pc, ebp, eip: NbrInt.Integer );
	VAR i, reg: NbrInt.Integer;  timer: Kernel.Timer;
	BEGIN
		reg := SIGNED32(SYSTEM.GetFramePointer ());
		SYSTEM.GET( reg, ebp );   (* stack frame of caller *)
		SYSTEM.GET( ebp + 4, eip );   (* return address from caller *)
		m := Modules.ThisModuleByAdr( eip );
		IF m # NIL THEN pc := SIGNED32(eip - ADDRESSOF( m.code[0] )) ELSE pc := MAX( SIGNED32 ) END;
		IF ~beepedError THEN
			beepedError := TRUE;  NEW( timer );
			FOR i := 1 TO 3 DO Beep.Beep( 125 );  timer.Sleep( 100 );  Beep.Beep( 0 );  timer.Sleep( 100 ) END;
			FOR i := 1 TO 3 DO Beep.Beep( 100 );  timer.Sleep( 350 );  Beep.Beep( 0 );  timer.Sleep( 150 ) END;
			FOR i := 1 TO 3 DO Beep.Beep( 125 );  timer.Sleep( 100 );  Beep.Beep( 0 );  timer.Sleep( 100 ) END
		END
	END ErrorCaller;

	PROCEDURE WarningCaller( VAR m: Modules.Module;  VAR pc, ebp, eip: NbrInt.Integer );
	VAR reg: NbrInt.Integer;  timer: Kernel.Timer;
	BEGIN
		reg := SIGNED32(SYSTEM.GetFramePointer ());
		SYSTEM.GET( reg, ebp );   (* stack frame of caller *)
		SYSTEM.GET( ebp + 4, eip );   (* return address from caller *)
		m := Modules.ThisModuleByAdr( eip );
		IF m # NIL THEN pc := SIGNED32(eip - ADDRESSOF( m.code[0] )) ELSE pc := MAX( SIGNED32 ) END;
		IF ~beepedWarning THEN
			beepedWarning := TRUE;  NEW( timer );  Beep.Beep( 125 );  timer.Sleep( 100 );  Beep.Beep( 0 );
			timer.Sleep( 100 );  Beep.Beep( 100 );  timer.Sleep( 100 );  Beep.Beep( 0 );  timer.Sleep( 100 );
			Beep.Beep( 125 );  timer.Sleep( 100 );  Beep.Beep( 0 );  timer.Sleep( 100 )
		END
	END WarningCaller;

	PROCEDURE IdentifyProcedure( VAR m: Modules.Module;  pc: NbrInt.Integer;  VAR module, type, proc: ARRAY OF CHAR );
	VAR i: NbrInt.Integer;  ch: CHAR;  refs: Modules.Bytes;  refpos: SIGNED32;
	BEGIN
		module[0] := 0X;  type[0] := 0X;  proc[0] := 0X;
		IF m = NIL THEN
			IF pc = 0 THEN COPY( "NIL", proc ) ELSE COPY( "unknown pointer", proc ) END
		ELSE
			COPY( m.name, module );  refs := m.refs;  refpos := FindProc( refs, pc );
			IF refpos # -1 THEN
				ch := refs[refpos];  NbrInt.Inc( refpos );  i := 0;
				WHILE (ch # 0X) DO
					proc[i] := ch;  ch := refs[refpos];  NbrInt.Inc( refpos );  NbrInt.Inc( i );
					IF ch = "." THEN ch := refs[refpos];  NbrInt.Inc( refpos );  proc[i] := 0X;  COPY( proc, type );  i := 0 END
				END;
				proc[i] := 0X
			ELSE COPY( "unknown", proc )
			END
		END
	END IdentifyProcedure;

	PROCEDURE Location( module, type, proc: ARRAY OF CHAR );
	BEGIN
		IF module[0] # 0X THEN W.String( "   module: " );  W.String( module );  W.Ln END;
		IF type[0] # 0X THEN
			W.String( "      type: " );  W.String( type );  W.Ln;
			IF proc[0] # 0X THEN W.String( "         method: " );  W.String( proc );  W.Ln END
		ELSE
			IF proc[0] # 0X THEN W.String( "      procedure: " );  W.String( proc );  W.Ln END
		END
	END Location;

	PROCEDURE DetailedErrorReport( VAR m: Modules.Module;  pc: SIGNED32;  eip, ebp: SIGNED32 );
VAR refs: Modules.Bytes; refpos: SIGNED32; adr: SIGNED32;
		BEGIN
		IF m # NIL THEN
	 refs := m.refs;  refpos := FindProc( refs, pc );
					GetNum( refs, refpos, adr );
				INC( adr, SIGNED32(m.sb));   (* convert to absolute address *)
	W.Hex(adr,8);W.Ln;
		W.String( "Detailed Error Report" );  W.Ln;
		IF m# NIL THEN W.String( "Module State:" );  W.Ln;  ModuleState( m );  END;
		W.String( "Stack trace back" );  W.Ln;
		IF (eip # 0) & (ebp # 0) THEN StackTraceBack( eip, ebp, TRUE );  END;
		END;
	END DetailedErrorReport;


(** Log an error message to file Error.Log. *)
	PROCEDURE Error*( message: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: NbrInt.Integer;
		module, type, proc: ARRAY 64 OF CHAR;
		ebp, eip: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF W # NIL THEN
			ErrorCaller( m, pc, ebp, eip );  IdentifyProcedure( m, pc, module, type, proc );  W.String( "An error of:" );  W.Ln;  W.String( "   " );
			W.String( message );  W.Ln;  W.String( "occurred in:" );  W.Ln;  Location( module, type, proc );  W.Ln;
			DetailedErrorReport(m,pc,eip,ebp);
			W.Update
		END
	END Error;

(** Log an error message to file Error.Log when an error arises from a passed parameter whose value was int. *)
	PROCEDURE IntError*( int: NbrInt.Integer;  message: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: NbrInt.Integer;
		module, type, proc, string: ARRAY 64 OF CHAR;
		ebp, eip: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF W # NIL THEN
			ErrorCaller( m, pc, ebp, eip );  IdentifyProcedure( m, pc, module, type, proc );  W.String( "An ERROR occurred in:" );  W.Ln;
			Location( module, type, proc );  W.String( "The argument passed that caused this error was: " );  W.Ln;  W.String( "   " );  NbrInt.IntToString( int, string );
			W.String( string );  W.Ln;  W.String( "resulting in the following error message:" );  W.Ln;  W.String( "   " );  W.String( message );  W.Ln;  W.Ln;
			DetailedErrorReport(m,pc,eip,ebp);
			W.Update
		END
	END IntError;

(** Log an error message to file Error.Log when an error arises from a passed parameter whose value was rat. *)
	PROCEDURE RatError*( rat: NbrRat.Rational;  message: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: NbrInt.Integer;
		module, type, proc, string: ARRAY 64 OF CHAR;
		ebp, eip: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF W # NIL THEN
			ErrorCaller( m, pc, ebp, eip );  IdentifyProcedure( m, pc, module, type, proc );  W.String( "An ERROR occurred in:" );  W.Ln;
			Location( module, type, proc );  W.String( "The argument passed that caused this error was: " );  W.Ln;  W.String( "   " );  NbrRat.RatToString( rat, string );
			W.String( string );  W.Ln;  W.String( "resulting in the following error message:" );  W.Ln;  W.String( "   " );  W.String( message );  W.Ln;  W.Ln;
						DetailedErrorReport(m,pc,eip,ebp);
			W.Update
		END
	END RatError;

(** Log an error message to file Error.Log when an error arises from a passed parameter whose value was re. *)
	PROCEDURE ReError*( re: NbrRe.Real;  message: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: NbrInt.Integer;
		module, type, proc, string: ARRAY 64 OF CHAR;
		ebp, eip: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF W # NIL THEN
			ErrorCaller( m, pc, ebp, eip );  IdentifyProcedure( m, pc, module, type, proc );  W.String( "An ERROR occurred in:" );  W.Ln;
			Location( module, type, proc );  W.String( "The argument passed that caused this error was: " );  W.Ln;  W.String( "   " );  NbrRe.ReToString( re, 15, string );
			W.String( string );  W.Ln;  W.String( "resulting in the following error message:" );  W.Ln;  W.String( "   " );  W.String( message );  W.Ln;  W.Ln;
						DetailedErrorReport(m,pc,eip,ebp);
			W.Update
		END
	END ReError;

(** Log an error message to file Error.Log when an error arises from a passed parameter whose value was cplx. *)
	PROCEDURE CplxError*( cplx: NbrCplx.Complex;  message: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: NbrInt.Integer;
		module, type, proc, string: ARRAY 64 OF CHAR;
		ebp, eip: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF W # NIL THEN
			ErrorCaller( m, pc, ebp, eip );  IdentifyProcedure( m, pc, module, type, proc );  W.String( "An ERROR occurred in:" );  W.Ln;
			Location( module, type, proc );  W.String( "The argument passed that caused this error was: " );  W.Ln;  W.String( "   " );  NbrCplx.CplxToPolarString( cplx, 15, string );
			W.String( string );  W.Ln;  W.String( "resulting in the following error message:" );  W.Ln;  W.String( "   " );  W.String( message );  W.Ln;  W.Ln;
						DetailedErrorReport(m,pc,eip,ebp); W.Update
		END
	END CplxError;

(** Log a warning message to file Error.Log. *)
	PROCEDURE Warning*( message: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: NbrInt.Integer;
		module, type, proc: ARRAY 64 OF CHAR;
		ebp, eip: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF W # NIL THEN
			WarningCaller( m, pc, ebp, eip );  IdentifyProcedure( m, pc, module, type, proc );  W.String( "A WARNING of:" );  W.Ln;  W.String( "   " );
			W.String( message );  W.Ln;  W.String( "occurred in:" );  W.Ln;  Location( module, type, proc );  W.Ln;  W.Update
		END
	END Warning;

(** Log a warning message to file Error.Log when a warning arises from a passed parameter whose value was int. *)
	PROCEDURE IntWarning*( int: NbrInt.Integer;  message: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: NbrInt.Integer;
		module, type, proc, string: ARRAY 64 OF CHAR;
		ebp, eip: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF W # NIL THEN
			WarningCaller( m, pc, ebp, eip );  IdentifyProcedure( m, pc, module, type, proc );  W.String( "A WARNING occurred in:" );  W.Ln;
			Location( module, type, proc );  W.String( "The argument passed that caused this warning was: " );  W.Ln;  W.String( "   " );  NbrInt.IntToString( int, string );
			W.String( string );  W.Ln;  W.String( "resulting in the following error message:" );  W.Ln;  W.String( "   " );  W.String( message );  W.Ln;  W.Ln;  W.Update
		END
	END IntWarning;

(** Log a warning message to file Error.Log when a warning arises from a passed parameter whose value was rat. *)
	PROCEDURE RatWarning*( rat: NbrRat.Rational;  message: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: NbrInt.Integer;
		module, type, proc, string: ARRAY 64 OF CHAR;
		ebp, eip: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF W # NIL THEN
			WarningCaller( m, pc, ebp, eip );  IdentifyProcedure( m, pc, module, type, proc );  W.String( "A WARNING occurred in:" );  W.Ln;
			Location( module, type, proc );  W.String( "The argument passed that caused this warning was: " );  W.Ln;  W.String( "   " );  NbrRat.RatToString( rat, string );
			W.String( string );  W.Ln;  W.String( "resulting in the following error message:" );  W.Ln;  W.String( "   " );  W.String( message );  W.Ln;  W.Ln;  W.Update
		END
	END RatWarning;

(** Log a warning message to file Error.Log when a warning arises from a passed parameter whose value was re. *)
	PROCEDURE ReWarning*( re: NbrRe.Real;  message: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: NbrInt.Integer;
		module, type, proc, string: ARRAY 64 OF CHAR;
		ebp, eip: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF W # NIL THEN
			WarningCaller( m, pc, ebp, eip );  IdentifyProcedure( m, pc, module, type, proc );  W.String( "A WARNING occurred in:" );  W.Ln;
			Location( module, type, proc );  W.String( "The argument passed that caused this warning was: " );  W.Ln;  W.String( "   " );  NbrRe.ReToString( re, 15, string );
			W.String( string );  W.Ln;  W.String( "resulting in the following error message:" );  W.Ln;  W.String( "   " );  W.String( message );  W.Ln;  W.Ln;  W.Update
		END
	END ReWarning;

(** Log a warning message to file Error.Log when a warning arises from a passed parameter whose value was cplx. *)
	PROCEDURE CplxWarning*( cplx: NbrCplx.Complex;  message: ARRAY OF CHAR );
	VAR m: Modules.Module;  pc: NbrInt.Integer;
		module, type, proc, string: ARRAY 64 OF CHAR;
		ebp, eip: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF W # NIL THEN
			WarningCaller( m, pc, ebp, eip );  IdentifyProcedure( m, pc, module, type, proc );  W.String( "A WARNING occurred in:" );  W.Ln;
			Location( module, type, proc );  W.String( "The argument passed that caused this warning was: " );  W.Ln;  W.String( "   " );  NbrCplx.CplxToPolarString( cplx, 15, string );
			W.String( string );  W.Ln;  W.String( "resulting in the following error message:" );  W.Ln;  W.String( "   " );  W.String( message );  W.Ln;  W.Ln;  W.Update
		END
	END CplxWarning;

(** Opens the file Error.Log, saving the prior log file to Error.Log.Bak.
		Error.Log is automatically opened whenever this module is loaded into memory,
		and it only needs to be reopened manually if you had previously closed it manually. *)
	PROCEDURE Open*;
	VAR ignor: INTEGER;  backup, current: Files.FileName;
	BEGIN
		beepedError := FALSE;  beepedWarning := FALSE;  COPY( "Error.Log", current );  COPY( "Error.Log.Bak", backup );  Files.Delete( backup, ignor );
		Files.Rename( current, backup, ignor );  F := Files.New( current );  Files.OpenWriter( W, F, 0 )
	END Open;

(** Closes the file Error.Log.
		Error.Log is automatically closed whenever this module is garbage collected.
		Executing Close forces the file to close immediately. *)
	PROCEDURE Close*;
	BEGIN
		IF F # NIL THEN Files.Register( F );  W := NIL;  F := NIL END
	END Close;



BEGIN
	Open;  Modules.InstallTermHandler( Close )
END DataErrors.

DataErrors.Close ~
EditTools.OpenAscii  Error.Log ~
EditTools.OpenAscii  Error.Log.Bak ~

