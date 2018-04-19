MODULE Debugging;   (**  AUTHOR "fof"; PURPOSE "Debugging facilities";  **)

IMPORT SYSTEM, Streams, KernelLog, Files, StringPool,  Modules, Objects, Reflection, Machine, Commands, Locks, Dates, Heaps;

VAR
	DefaultLog, Log-: Streams.Writer;  f: Files.File;  lock: Locks.RWLock;

	PROCEDURE Memory*( from, tov: ADDRESS );
	VAR i: ADDRESS; val: SIZE;
	BEGIN
		Log.String( ">>>>>" );  Log.Ln;
		IF from = 0 THEN Log.String( "NIL Region" );  Log.Ln;  ELSE
			FOR i := from TO tov BY SIZEOF(ADDRESS) DO
				Log.Address( i );  Log.String( "H (" );  Log.Int( i, 0 );
				Log.String( "," );  Log.Int( i - from, 4 );  Log.String( ") " );
				SYSTEM.GET( i, val );  Log.Address( val );  Log.String( "H = " );
				Log.Int( val, 10 );  Log.Ln;
			END;
		END;
		Log.String( "<<<<<" );  Log.Ln;
		Log.Update;
	END Memory;

	PROCEDURE ViewStack( ebp, esp: ADDRESS; CONST s: ARRAY OF CHAR);
	VAR i: ADDRESS; val: LONGINT; prevBP:ADDRESS;
	CONST adrSize= SIZEOF(ADDRESS);
	BEGIN
		Log.String( ">>>>> " );  Log.String(s); Log.String (" >>>>>> "); Log.Ln;
		SYSTEM.GET(ebp,prevBP);
		IF prevBP-ebp > 1024 THEN prevBP := ebp END;
		FOR i := prevBP TO esp BY -adrSize DO
			Log.Address( i );  Log.String( "H (" );  Log.Int( i, 0 );  Log.String( "," );
			Log.Int( i - ebp, 4 );  Log.String( ") " );  SYSTEM.GET( i, val );
			Log.Address( val );  Log.String( "H = " );  Log.Int( val, 10 );
			IF (i = prevBP) & (i # ebp) THEN Log.String("  <-----  [EBP]"); END;
			IF i = ebp THEN Log.String("  <----- EBP"); END;
			IF i = ebp+adrSize THEN Log.String("  <----- EIP"); END;
			IF i = esp THEN Log.String("  <----- ESP"); END;
			Log.Ln;
		END;
		Log.String( "<<<<<" );  Log.Ln;
		Log.Update;

	END ViewStack;

	PROCEDURE Stack*(CONST s: ARRAY OF CHAR);
	VAR bp,oldbp: ADDRESS;
	BEGIN
		bp := Machine.CurrentBP();
		SYSTEM.GET(bp,oldbp);
		ViewStack(oldbp,bp+4*SIZEOF(ADDRESS),s);
	END Stack;

	PROCEDURE TraceBackThis( eip, ebp: ADDRESS; stacklow, stackhigh:ADDRESS );   (* do a stack trace back w.r.t. given instruction and frame pointers *)
	BEGIN
		Log.Ln;  Log.String( "#######################" );
		Log.Ln;  Log.String( "# Debugging.TraceBack #" );
		Log.Ln;  Log.String( "#######################" );
		Log.Ln;  Reflection.StackTraceBack( Log, eip, ebp, stacklow, stackhigh, TRUE , FALSE );
		Log.Update;
	END TraceBackThis;

	PROCEDURE TraceBack*;   (* do a stack trace back starting at the calling instruction position *)
	BEGIN
		Enter;
		TraceBackThis( Machine.CurrentPC(), Machine.CurrentBP(), Machine.CurrentSP(), Objects.GetStackBottom(Objects.CurrentProcess()) );
		Exit;
	END TraceBack;

	(* TraceBackAll implemented in SystemTools.ShowStacks *)

	PROCEDURE FileStart*(context: Commands.Context);   (* start writing to a the file Debugging.Text *)
	VAR w: Files.Writer;  filename: ARRAY 256 OF CHAR;
	BEGIN
		IF context # NIL THEN
			context.arg.String(filename);
		ELSE
			filename := ""
		END;
		IF (filename = "")  THEN filename := "Debugging.Text" END;
		KernelLog.String("filename = "); KernelLog.String(filename); KernelLog.String("<"); KernelLog.Ln;
		f := Files.New( filename );
		Files.OpenWriter( w, f, 0 );
		Log := w
	END FileStart;

	PROCEDURE FileEnd*;   (* stop writing to Debugging.Text *)
	BEGIN
		Log.Update;  Files.Register( f );  f.Update;  f := NIL;  Log := DefaultLog;
	END FileEnd;

	(* shortcut for String, usage deprecated *)
	PROCEDURE Str*( CONST name: ARRAY OF CHAR );
	BEGIN
		Log.String( name );
	END Str;

	PROCEDURE String*(CONST name: ARRAY OF CHAR);
	BEGIN
		Log.String(name);
	END String;

	PROCEDURE Address*(i: ADDRESS);
	BEGIN
		Log.Address(i);
	END Address;

	PROCEDURE Int*( i,j: LONGINT );
	BEGIN
		Log.Int( i, j );
	END Int;

	PROCEDURE Set*(set: SET);
	VAR i: LONGINT; first: BOOLEAN;
	BEGIN
		Log.String("{"); first := TRUE;
		FOR i := MIN(SET) TO MAX(SET) DO
			IF i IN set THEN
				IF first THEN first := FALSE ELSE Log.String(",") END;
				Log.Int(i,1)
			END;
		END;
		Log.String("}");
	END Set;


	PROCEDURE Float*( r: LONGREAL; len: LONGINT );
	BEGIN
		Log.Float( r, len );
	END Float;

	PROCEDURE Hex*( i: HUGEINT; j: LONGINT );
	BEGIN
		Log.Hex( i, j );
	END Hex;

	PROCEDURE HIntHex*( x: HUGEINT );
	BEGIN
		Hex( SHORT( ASH( x, -32 ) ),1 );  Hex( SHORT( x ),1 )
	END HIntHex;

	PROCEDURE Char*( c: CHAR );
	BEGIN
		Log.Char( c );
	END Char;

	PROCEDURE Update*;
	BEGIN
		Log.Update;
	END Update;

	PROCEDURE Ln*;
	BEGIN
		Log.Ln;  Update;
	END Ln;

	PROCEDURE Type*( p: ANY );   (* output the type name of object pointed to by p *)
	VAR t: Modules.TypeDesc;
	BEGIN
		IF p = NIL THEN Str( "NIL (no type)" )
		ELSE
			t := Modules.TypeOf( p );
			IF t = NIL THEN Str( "unknown" ) ELSE Str( t.mod.name );  Str( "." );  Str( t.name );  END;
		END;
	END Type;

	PROCEDURE Str0*( idx: StringPool.Index );   (* output string index as string *)
	VAR name: ARRAY 256 OF CHAR;
	BEGIN
		StringPool.GetString( idx, name );  Log.String( name );
	END Str0;

	PROCEDURE Enter*;   (* start exclusive writing *)
	VAR a: ANY;  p: Objects.Process;	dt: Dates.DateTime;
	BEGIN
		lock.AcquireWrite;  Ln;
		Str( "{ [P " );  p := Objects.CurrentProcess();  Int( p.id,1 );  Str( " " );  a := Objects.ActiveObject();  Type( a );  Str( "] " );
		dt := Dates.Now(); Int(dt.hour,0); Char(':'); Int(dt.minute,0); Char(':'); Int(dt.second,0);

	END Enter;

	PROCEDURE Exit*;   (* end exclusive writing *)
	BEGIN
		Str( "}" );  Log.Update;  lock.ReleaseWrite;
	END Exit;

	PROCEDURE Nothing;
	BEGIN
	END Nothing;

	PROCEDURE Halt*;
	BEGIN HALT (1234);
	END Halt;

	PROCEDURE DisableGC*;
	BEGIN
		Heaps.GC := Nothing;
		TRACE(Heaps.GC, "disabled"); 
	END DisableGC;

	PROCEDURE EnableGC*;
	BEGIN
		Heaps.GC := Heaps.InvokeGC;
		TRACE(Heaps.GC, "enabled"); 
	END EnableGC;

	(* useful for debugging the GC / metadata *)
	PROCEDURE ReportProcedureDescriptors*;
	VAR m: Modules.Module; i,j: LONGINT;
	BEGIN
		m := Modules.root;
		WHILE (m # NIL) DO
			TRACE(m.name); 
			IF m.procTable # NIL THEN 
				FOR i := 0 TO LEN(m.procTable)-1 DO
					(*TRACE(m.procTable[i]);*)
					Log.Address(m.procTable[i]); 
					Log.String(":"); 
					Reflection.WriteProc(Log, m.procTable[i].pcFrom); 
					Log.String(" ptrs @ ");
					FOR j := 0 TO LEN(m.procTable[i].offsets)-1 DO
						Log.Int(m.procTable[i].offsets[j],1); 
						Log.String(" "); 
					END;
					Log.Ln;
				END;
			END;
			m := m.next;
		END;
	END ReportProcedureDescriptors;

BEGIN
	Streams.OpenWriter( DefaultLog, KernelLog.Send );  Log := DefaultLog; NEW( lock );
END Debugging.

SystemTools.FreeDownTo Debugging ~
Debugging.ReportProcedureDescriptors
