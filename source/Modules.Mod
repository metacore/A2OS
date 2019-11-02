MODULE Modules;	(** AUTHOR "pjm"; PURPOSE "Modules and types"; *)

IMPORT SYSTEM, Trace, Machine, Heaps;

#IF COOP THEN
	IMPORT Activities, Environment, GarbageCollector, Processors, Queues, ExclusiveBlocks;
#END

CONST
	Ok* = 0;

	AddressSize = SIZEOF (ADDRESS);	(* architecture dependent size of addresses in bytes *)

	MaxTags* = 16;	(* in type descriptor *)

	(** type descriptor field offsets relative to root (middle) *)
	Tag0Ofs* = -AddressSize * 2;	(** first tag *)
	Mth0Ofs* = Tag0Ofs - AddressSize*MaxTags;	(** first method *)
	Ptr0Ofs* = AddressSize;	(** first pointer offset *)

	MaxObjFormats = 5;	(* maximum number of object file formats installed *)

	(** flags in TypeDesc, RoundUp(log2(MaxTags)) low bits reserved for extLevel *)
	ProtTypeBit* = Heaps.ProtTypeBit;

	None* = 0; PowerDown* = 1; Reboot* = 2;

	ClearCode = TRUE;

	DefaultContext* = "A2";
	NoLoader=3400;

	TraceBoot=FALSE;

	(* flags *)
	PreciseGC* = 0;

TYPE
	(* definitions for object-model loader support *)
	Name* = ARRAY 96 OF CHAR;

	(* the correponding name array is protected from being GCed via module's internal pointer arrray
		compiler generated!
	*)
	DynamicName* = POINTER {UNSAFE,UNTRACED} TO ARRAY 256 OF CHAR;

	Command* = RECORD
		(* Fields exported for initialization by loader/linker only! Consider read-only! *)
		name*: Name; (* name of the procedure *)
		argTdAdr*, retTdAdr* : ADDRESS; (* address of type descriptors of argument and return type, 0 if no type *)
		entryAdr* : ADDRESS; (* entry address of procedure *)
	END;

	ExportDesc* = RECORD
		fp*: SIGNED64;
		name* {UNTRACED}: DynamicName;
		adr*: ADDRESS;
		exports*: SIZE; (* number of exports referenced by ExportArray *)
		dsc* {UNTRACED}: ExportArray; (* pointer to memory containing a raw array with "exports" entries *)
	END;
	ExportArray* = POINTER {UNSAFE,UNTRACED} TO ARRAY MAX(SIZE) OF ExportDesc;

	Bytes* = POINTER TO ARRAY OF CHAR;

	TerminationHandler* = PROCEDURE;


	(* all implicit or explicit pointers in the subsequent data structures are protected with one pointer array
	*)

	TypeDesc* = POINTER  TO RECORD
		descSize-: SIZE;
		tag-: ADDRESS; (* pointer to static type descriptor, only used by linker and loader *)
		flags-: SET;
		mod- {UNTRACED}: Module;	(* hint only, because module may have been freed *)
		name-: Name;
		refsOffset-: SIZE;
	END;

	ExceptionTableEntry* = RECORD
		pcFrom*: ADDRESS;
		pcTo*: ADDRESS;
		pcHandler*: ADDRESS;
	END;

	ExceptionTable* = POINTER TO ARRAY OF ExceptionTableEntry;

	ProcedureDescPointer* = POINTER TO ProcedureDesc;
	ProcedureDesc*= RECORD
		pcFrom-, pcLimit-: ADDRESS;
		offsets- {UNTRACED}: POINTER TO ARRAY OF ADDRESS;
	END;

	ProcedureDescs* = POINTER TO ARRAY OF ProcedureDescPointer;

	Module* = OBJECT (Heaps.RootObject)	(* cf. Linker0 & Heaps.WriteType *)
		VAR
			next*: Module;	(** once a module is published, all fields are read-only *)
			name*: Name;
			refcnt*: SIZE; (* counts loaded modules that import this module *)
			sb*: ADDRESS; (* reference address between constants and local variables *)
			entry*: POINTER TO ARRAY OF ADDRESS;
			command*: POINTER TO ARRAY OF Command;
			ptrAdr*: POINTER TO ARRAY OF ADDRESS; (* traced explicitly in FindRoots *)
			typeInfo*: POINTER TO ARRAY OF TypeDesc;
			module*: POINTER TO ARRAY OF Module; (* imported modules: for reference counting *)
			procTable*: ProcedureDescs; (* information inserted by loader, sorted by pc after loading *)
			data*, code*, refs*: Bytes;
			export*: ExportDesc;
			term*: TerminationHandler;
			exTable*: ExceptionTable;
			(* internal pointer array: to protect internal data structures from being GCed *)
			internal-: POINTER TO ARRAY OF ANY;
			body*: PROCEDURE;
			flags*: SET;	 (* e.g. compilation flags *)
			crc*: SIGNED32;
			init, published: BOOLEAN;

		#IF ~COOP THEN
			PROCEDURE FindRoots*;	(* override *)
			VAR i: SIZE; ptr {UNTRACED}: ANY; false: BOOLEAN;
			VAR name: Name;
			BEGIN
				name := SELF.name;
				false := FALSE; IF false THEN BEGIN{EXCLUSIVE} END END; (* trick to make a module a protected record ... *)
				IF published THEN	(* mark global pointers *)
					FOR i := 0 TO LEN(ptrAdr) - 1 DO
						SYSTEM.GET (ptrAdr[i], ptr);
						IF ptr # NIL THEN Heaps.Mark(ptr) END
					END;
					(* all other fields are being traversed by Mark of the Garbage Collector *)
				END;
			END FindRoots;
		#END

	END Module;

	LoaderProc* = PROCEDURE (CONST name, fileName: ARRAY OF CHAR; VAR res: INTEGER;
			VAR msg: ARRAY OF CHAR): Module;	(** load an object file *)

VAR
	extension-: ARRAY MaxObjFormats, 8 OF CHAR;
	loader: ARRAY MaxObjFormats OF LoaderProc;
	numLoaders: SIZE;

	freeRoot*: Module;	(** list of freed modules (temporary) *)

	root-: Module;	(** list of modules (read-only) *)
	shutdown*: INTEGER;	(** None, Reboot, PowerDown *)
	trace: BOOLEAN;
	register: RECORD
		first {UNTRACED}, last {UNTRACED}: Module;
	END;

	(* global sorted table of all procedures , basically for GC *)
	procedureDescriptors-: ProcedureDescs;

(** Register a module loader. *)

PROCEDURE Halt(CONST reason: ARRAY OF CHAR);
BEGIN
	HALT(999);
END Halt;


PROCEDURE AddLoader*(CONST ext: ARRAY OF CHAR; proc: LoaderProc);
BEGIN
	Machine.Acquire(Machine.Modules);
	ASSERT(numLoaders < MaxObjFormats);
	loader[numLoaders] := proc;
	COPY(ext, extension[numLoaders]);
	ASSERT(ext = extension[numLoaders]);	(* no overflow *)
	INC(numLoaders);
	Machine.Release(Machine.Modules)
END AddLoader;

(** Remove a module loader. *)
PROCEDURE RemoveLoader*(CONST ext: ARRAY OF CHAR; proc: LoaderProc);
VAR i, j: SIZE;
BEGIN
	Machine.Acquire(Machine.Modules);
	i := 0;
	WHILE (i # numLoaders) & ((loader[i] # proc) OR (extension[i] # ext)) DO INC(i) END;
	IF i # numLoaders THEN
		FOR j := i TO numLoaders - 2 DO
			loader[j] := loader[j + 1]; extension[j] := extension[j + 1];
		END;
		loader[numLoaders - 1] := NIL; extension[numLoaders - 1] := "";
		DEC(numLoaders)
	END;
	Machine.Release(Machine.Modules)
END RemoveLoader;

(** Append string from to to, truncating on overflow. *)
PROCEDURE Append*(CONST from: ARRAY OF CHAR; VAR to: ARRAY OF CHAR);
VAR i, j, m: SIZE;
BEGIN
	j := 0; WHILE to[j] # 0X DO INC(j) END;
	m := LEN(to)-1;
	i := 0; WHILE (from[i] # 0X) & (j # m) DO to[j] := from[i]; INC(i); INC(j) END;
	to[j] := 0X
END Append;


(** Add a module to the pool of accessible modules, or return named module. *)
PROCEDURE Publish*(VAR m: Module; VAR new: BOOLEAN);
VAR n: Module; i: SIZE; name: Name;
BEGIN
	Machine.Acquire(Machine.Modules);
	n := root; WHILE (n # NIL) & (n.name # m.name) DO n := n.next END;
	IF n # NIL THEN	(* module with same name exists, return it and ignore new m *)
		m := n; new := FALSE
	ELSE
		IF TraceBoot OR trace THEN
			Machine.Acquire(Machine.TraceOutput);
			Trace.String("publish "); Trace.String(m.name);
			Trace.Ln;
			Machine.Release(Machine.TraceOutput);
		END;
		Unregister(m);
		m.published := TRUE;
		m.next := root; root := m;
		m.refcnt := 0;
		SortExceptionTable(m.exTable);
		SortProcedureDescs(m.procTable);

		IF m.module # NIL THEN
			FOR i := 0 TO LEN(m.module)-1 DO INC(m.module[i].refcnt) END;
		END;

		new := TRUE;
	END;
	Machine.Release(Machine.Modules);
	#IF ~COOP THEN
		IF (Heaps.GCType = Heaps.MetaDataForStackGC) & ~(PreciseGC IN m.flags) THEN
			name := m.name;
			Halt("Module does not provide metadata required by the GC.");
		END;
	#END
END Publish;

PROCEDURE Initialize*(VAR module: Module);
VAR new: BOOLEAN; import: SIZE;
BEGIN
	IF (module = NIL) THEN RETURN END;
	Publish (module, new);
	IF new THEN
		FOR import := 0 TO LEN (module.module) - 1 DO
			IF ~module.module[import].published THEN
				ASSERT(register.first # NIL);
				Initialize(module.module[import]);
			END
		END;
		IF (module.code # NIL) & (LEN(module.code) > 0)  THEN
			Machine.FlushDCacheRange(ADDRESSOF(module.code[0]), LEN(module.code));
		END;
		IF module.body # NIL THEN
			module.body
		END;
		module.init := TRUE;
	END;
END Initialize;

	VAR callagain: BOOLEAN;

	PROCEDURE Initialize0*(module: Module);
	VAR new: BOOLEAN;
	BEGIN
		(*TRACE(module.name);*)
		(* module MUST have been removed from register list and must not have been initialized yet *)
		(* ASSERT(module.next = NIL); *)
		Publish (module, new);
		callagain := FALSE;
		IF new THEN
			IF module.name = "Objects" THEN
				callagain := TRUE;
				module.init := TRUE;
			END;
			(*
			Trace.Memory(SYSTEM.VAL(ADDRESS, module), 256);
			TRACE(module, module.name, module.body);
			TRACE(module);
			TRACE(ADDRESS OF module.next);
			TRACE(ADDRESS OF module.name);
			TRACE(ADDRESS OF module.init);
			TRACE(ADDRESS OF module.published);
			TRACE(ADDRESS OF module.body);
			TRACE(ADDRESS OF module.refcnt);
			TRACE(ADDRESS OF module.sb);
			TRACE(ADDRESS OF module.entry);
			TRACE(ADDRESS OF module.command);
			TRACE(ADDRESS OF module.ptrAdr);
			TRACE(ADDRESS OF module.typeInfo);
			TRACE(ADDRESS OF module.module);
			TRACE(ADDRESS OF module.procTable);
			TRACE(ADDRESS OF module.ptrTable);
			TRACE(ADDRESS OF module.data);
			TRACE(ADDRESS OF module.code);
			TRACE(ADDRESS OF module.staticTypeDescs);
			TRACE(ADDRESS OF module.refs);
			TRACE(ADDRESS OF module.export);
			TRACE(ADDRESS OF module.term);
			TRACE(ADDRESS OF module.exTable);
			TRACE(ADDRESS OF module.noProcs);
			TRACE(ADDRESS OF module.firstProc);
			TRACE(ADDRESS OF module.maxPtrs);
			TRACE(ADDRESS OF module.crc);
			TRACE(ADDRESS OF module.body);
			*)

			IF module.body # NIL THEN module.body END;
			IF callagain THEN
				PublishRegisteredModules (* does not return on intel architecture. Returns on ARM but looses procedure stack frame: we are not allowed to refer to local variables after this *)
			ELSE
				module.init := TRUE;
			END;
		END;
	END Initialize0;

	(** Return the named module or NIL if it is not loaded yet. *)
	PROCEDURE ModuleByName*(CONST name: ARRAY OF CHAR): Module;
	VAR m: Module;
	BEGIN
		Machine.Acquire(Machine.Modules);
		m := root; WHILE (m # NIL) & (m.name # name) DO m := m.next END;
		Machine.Release(Machine.Modules);
		RETURN m
	END ModuleByName;

	PROCEDURE ByName(CONST name: ARRAY OF CHAR; VAR referenced: BOOLEAN): Module;
	VAR m: Module;
	BEGIN
		Machine.Acquire(Machine.Modules);
		referenced := FALSE;
		m := root; WHILE (m # NIL) & (m.name # name) DO m := m.next END;
		IF m = NIL THEN
			referenced := TRUE;
			m := register.first; WHILE (m#NIL) & (m.name # name) DO m := m.next END;
		END;
		Machine.Release(Machine.Modules);
		RETURN m
	END ByName;

	(* Generate a module file name. *)
	PROCEDURE GetFileName(CONST name, extension: ARRAY OF CHAR; VAR fileName: ARRAY OF CHAR);
	VAR i, j: SIZE;
	BEGIN
		i := 0; WHILE name[i] # 0X DO fileName[i] := name[i]; INC(i) END;
		j := 0; WHILE extension[j] # 0X DO fileName[i] := extension[j]; INC(i); INC(j) END;
		fileName[i] := 0X
	END GetFileName;

	(* sort procedure descriptors by firstPC in ascending order *)
	PROCEDURE SortProcedureDescs(p: ProcedureDescs);

		PROCEDURE Less(i,j: SIZE): BOOLEAN;
		BEGIN
			RETURN p[i].pcFrom < p[j].pcFrom;
		END Less;

		PROCEDURE Swap(i,j: SIZE);
		VAR tmp: ProcedureDescPointer;
		BEGIN
			tmp := p[i];
			p[i] := p[j];
			p[j] := tmp;
		END Swap;


		PROCEDURE Quick( lo, hi: SIZE);
		VAR i, j, m: SIZE;
		BEGIN
			IF lo < hi THEN
				i := lo;  j := hi;  m := (lo + hi) DIV 2;
				REPEAT
					WHILE Less( i, m ) DO  INC( i )  END;
					WHILE Less( m, j ) DO  DEC( j )  END;
					IF i <= j THEN
						IF m = i THEN  m := j
						ELSIF m = j THEN  m := i
						END;
						Swap( i, j );  INC( i );  DEC( j )
					END
				UNTIL i > j;
				Quick( lo, j);  Quick( i, hi)
			END;
		END Quick;

	BEGIN
		Quick(0, LEN(p)-1);
	END SortProcedureDescs;

	(* sort procedure descriptors by firstPC in ascending order *)
	PROCEDURE SortExceptionTable(p: ExceptionTable);

		PROCEDURE Less(i,j: SIZE): BOOLEAN;
		BEGIN
			RETURN p[i].pcFrom < p[j].pcFrom;
		END Less;

		PROCEDURE Swap(i,j: SIZE);
		VAR tmp: ExceptionTableEntry;
		BEGIN
			tmp := p[i];
			p[i] := p[j];
			p[j] := tmp;
		END Swap;

		PROCEDURE Quick( lo, hi: SIZE);
		VAR i, j, m: SIZE;
		BEGIN
			IF lo < hi THEN
				i := lo;  j := hi;  m := (lo + hi) DIV 2;
				REPEAT
					WHILE Less( i, m ) DO  INC( i )  END;
					WHILE Less( m, j ) DO  DEC( j )  END;
					IF i <= j THEN
						IF m = i THEN  m := j
						ELSIF m = j THEN  m := i
						END;
						Swap( i, j );  INC( i );  DEC( j )
					END
				UNTIL i > j;
				Quick( lo, j);  Quick( i, hi)
			END;
		END Quick;

	BEGIN
		Quick(0, LEN(p)-1);
	END SortExceptionTable;

(** Load the module if it is not already loaded. *)	(* Algorithm J. Templ, ETHZ, 1994 *)
PROCEDURE ThisModule*(CONST name: ARRAY OF CHAR; VAR res: INTEGER; VAR msg: ARRAY OF CHAR): Module;
VAR m: Module; fileName: Name; i: SIZE; registered: BOOLEAN;
BEGIN
	res := Ok; msg[0] := 0X; m := ByName(name, registered);
	IF (m#NIL) & (registered) THEN
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String(">R>"); Trace.StringLn (name);
			Machine.Release (Machine.TraceOutput);
		END;
		IF ~m.published THEN	(* no race on m.published, as update is done in Publish *)
			Initialize(m);
		END;
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String("<R<"); Trace.StringLn (name);
			Machine.Release (Machine.TraceOutput);
		END;
	ELSIF m = NIL THEN
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String(">L>"); Trace.StringLn (name);
			Machine.Release (Machine.TraceOutput);
		END;
		IF numLoaders = 0 THEN
			res := NoLoader; m := NIL;
		ELSE
			i:= 0;
			REPEAT
				GetFileName(name, extension[i], fileName);
				m := loader[i](name, fileName, res, msg);
				INC(i);
			UNTIL (m # NIL) OR (i=numLoaders);
		END;
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String("?"); Trace.StringLn (name);
			Machine.Release (Machine.TraceOutput);
		END;
		IF (m # NIL) & ~m.published THEN	(* no race on m.published, as update is done below in Publish *)
			Initialize(m);
		END;
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			IF m = NIL THEN
				Trace.String("could not load "); Trace.StringLn(name)
			ELSIF ~m.published THEN
				Trace.String("not published "); Trace.StringLn(name)
			ELSE
				Trace.String("<L<"); Trace.StringLn (name);
			END;
			Machine.Release (Machine.TraceOutput);
		END;
	END;
	RETURN m
END ThisModule;

(** Return the module that contains code address pc or NIL if not found. Can also return freed modules. Non-blocking version for reflection *)
PROCEDURE ThisModuleByAdr0*(pc: ADDRESS): Module;
VAR m: Module; found: BOOLEAN; list: SIZE;
BEGIN
	list := 0; found := FALSE;
	REPEAT
		CASE list OF
			0: m := root
			|1: m := freeRoot
		END;
		WHILE (m # NIL) & ~found DO
			found := FindProc(pc, m.procTable) # NIL;
			IF ~found THEN m := m.next END;
		END;
		INC(list)
	UNTIL found OR (list=2);
	RETURN m
END ThisModuleByAdr0;

(** Return the module that contains code address pc or NIL if not found. Can also return freed modules. *)
PROCEDURE ThisModuleByAdr*(pc: ADDRESS): Module;
VAR m: Module;
BEGIN
	Machine.Acquire(Machine.Modules);
	m := ThisModuleByAdr0(pc);
	Machine.Release(Machine.Modules);
	RETURN m
END ThisModuleByAdr;

CONST ModuleInitTimeout = SIGNED64(3000000000); (* Timeout for waiting until a module get initialized, 3 seconds for 1 GHz CPU *)

(*	Retrieve a procedure given a module name, the procedure name and some type information (kernel call) *)
PROCEDURE GetProcedure*(CONST moduleName, procedureName : ARRAY OF CHAR; argTdAdr, retTdAdr : ADDRESS; VAR entryAdr : ADDRESS);
VAR module : Module; ignoreMsg : ARRAY 32 OF CHAR; i: SIZE; res : INTEGER; t: SIGNED64;
BEGIN
	module := ThisModule(moduleName, res, ignoreMsg);
	IF (res = Ok) THEN
		(*!
			module body must have been called (see note at the end of this module);
			return NIL if the module does not get initialized within the specified timeout
		*)
		IF ~module.init THEN
			t := Machine.GetTimer();
			WHILE ~module.init & (Machine.GetTimer() - t < ModuleInitTimeout) DO END;
			IF ~module.init THEN (* timeout has expired *)
				RETURN;
			END;
		END;

		Machine.Acquire(Machine.Modules);
		i := 0; entryAdr := Heaps.NilVal;
		WHILE (entryAdr = Heaps.NilVal) & (i # LEN(module.command^)) DO
			IF (module.command[i].name = procedureName) & (module.command[i].argTdAdr = argTdAdr) & (module.command[i].retTdAdr = retTdAdr) THEN
				entryAdr := module.command[i].entryAdr;
			END;
			INC(i)
		END;
		Machine.Release(Machine.Modules);
	END;
END GetProcedure;

(** Return the named type *)
PROCEDURE ThisType*(m: Module; CONST name: ARRAY OF CHAR): TypeDesc;
VAR i: SIZE; type: TypeDesc;
BEGIN
	Machine.Acquire(Machine.Modules);
	i := 0;
	WHILE (i < LEN(m.typeInfo)) & (m.typeInfo[i].name # name) DO INC(i) END;
	IF i = LEN(m.typeInfo) THEN
		type := NIL
	ELSE
		type := m.typeInfo[i]
	END;
	Machine.Release(Machine.Modules);
	RETURN type
END ThisType;

PROCEDURE ThisTypeByAdr*(adr: ADDRESS; VAR m: Module; VAR t: TypeDesc);
BEGIN
	IF adr # 0 THEN
		Machine.Acquire(Machine.Modules);
		SYSTEM.GET (adr + Heaps.TypeDescOffset, adr);
		t := SYSTEM.VAL(TypeDesc, adr);
		m := t.mod;
		Machine.Release(Machine.Modules)
	ELSE
		m := NIL; t := NIL
	END
END ThisTypeByAdr;

(** create a new object given its type descriptor *)
PROCEDURE NewObj*(t : TypeDesc; isRealtime: BOOLEAN) : ANY;
VAR x : ANY;
BEGIN
	Heaps.NewRec(x, SYSTEM.VAL (ADDRESS, t.tag), isRealtime);
	RETURN x;
END NewObj;

(** return the type descriptor of an object *)
PROCEDURE TypeOf*(obj : ANY): TypeDesc;
VAR
	m : Module;
	t : TypeDesc;
	adr : ADDRESS;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.TypeDescOffset, adr);
	ThisTypeByAdr(adr, m, t);
	RETURN t;
END TypeOf;


(** searches for the given pc in the global ProcKeyTable, if found it returns the corresponding data element *)
PROCEDURE FindProc*(pc: ADDRESS; p: ProcedureDescs): ProcedureDescPointer;
VAR l,r,x: SIZE; isHit: BOOLEAN;
BEGIN
	IF p # NIL THEN
		l := 0; r := LEN(p)-1;
		REPEAT
			x := (l + r) DIV 2;
			IF pc < p[x].pcFrom THEN r := x - 1 ELSE l := x + 1 END;
			isHit := ((p[x].pcFrom <= pc) & (pc < p[x].pcLimit));
		UNTIL isHit OR (l > r);
		IF isHit THEN
			RETURN p[x];
		END;
	END;
	RETURN NIL;
END FindProc;

(** Install procedure to execute when module is freed or shut down. The handler can distinguish the two cases by checking Modules.shutdown. If it is None, the module is being freed, otherwise the system is being shut down or rebooted. Only one handler may be installed per module. The last handler installed is active. *)
PROCEDURE InstallTermHandler*(h: TerminationHandler);
VAR m: Module;
BEGIN
	m := ThisModuleByAdr(SYSTEM.VAL (ADDRESS, h));
	IF m # NIL THEN
		m.term := h	(* overwrite existing handler, if any *)
	END
END InstallTermHandler;

(** Free a module. The module's termination handler, if any, is called first. Then all objects that have finalizers in this module are finalized (even if they are still reachable). Then the module's data and code are invalidated. *)
PROCEDURE FreeModule*(CONST name: ARRAY OF CHAR; VAR res: INTEGER; VAR msg: ARRAY OF CHAR);
VAR p, m: Module; term: TerminationHandler; i: SIZE;
BEGIN
	m := ModuleByName(name);
	IF (m # NIL) & (m.refcnt = 0) THEN	(* will be freed below *)
		IF m.term # NIL THEN	(* call termination handler *)
			term := m.term; m.term := NIL; term	(* may trap *)
		END;
		IF m.code # NIL THEN
			Heaps.CleanupModuleFinalizers(ADDRESSOF(m.code[0]), LEN(m.code), m.name)
		END;
	END;
	res := Ok; msg[0] := 0X;
	Machine.Acquire(Machine.Modules);
	p := NIL; m := root;
	WHILE (m # NIL) & (m.name # name) DO p := m; m := m.next END;
	IF m # NIL THEN
		IF m.refcnt = 0 THEN	(* free the module *)
			FOR i := 0 TO LEN(m.module)-1 DO DEC(m.module[i].refcnt) END;
			m.init := FALSE;	(* disallow ThisCommand *)
			Append("?", m.name);
			(* move module to free list *)
			IF p = NIL THEN root := root.next ELSE p.next := m.next END;
			m.next := freeRoot; freeRoot := m;
			(* clear global pointers and code *)
			IF m.ptrAdr # NIL THEN
				FOR i := 0 TO LEN(m.ptrAdr)-1 DO SYSTEM.PUT (m.ptrAdr[i], NIL) END;
			END;
			IF ClearCode & (m.code # NIL) THEN
				FOR i := 0 TO LEN(m.code)-1 DO m.code[i] := 0CCX END
			END;
			(* remove references to module data *)
			m.published := FALSE;
			m.entry := NIL; m.command := NIL; m.ptrAdr := NIL;
			(* do not clear m.type or m.module, as old heap block tags might reference type descs indirectly. *) (* m.staticTypeDescs, m.typeInfo ??? *)
			(* do not clear m.data or m.code, as they are used in ThisModuleByAdr (for debugging). *)
			(* do not clear m.refs, as they are used in Traps (for debugging). *)
			m.export.dsc := NIL; m.exTable := NIL;
		ELSE
			res := 1901;	(* can not free module in use *)
			COPY(name, msg); Append(" reference count not zero", msg)
		END
	ELSE
		res := 1902;	(* module not found *)
		COPY(name, msg); Append(" not found", msg)
	END;
	Machine.Release(Machine.Modules)
END FreeModule;

(** Shut down all modules by calling their termination handlers and then call Machine.Shutdown. *)
PROCEDURE Shutdown*(code: INTEGER);
VAR m: Module; term: TerminationHandler;
BEGIN
	IF code # None THEN
		LOOP
			Machine.Acquire(Machine.Modules);
			m := root; WHILE (m # NIL) & (m.term = NIL) DO m := m.next END;
			IF m # NIL THEN term := m.term; m.term := NIL END; (* finalizer only called once *)
			Machine.Release(Machine.Modules);
			IF m = NIL THEN EXIT END;
			IF TraceBoot OR trace THEN
				Machine.Acquire (Machine.TraceOutput);
				Trace.String("TermHandler "); Trace.StringLn (m.name);
				Machine.Release (Machine.TraceOutput);
			END;
			term	(* if this causes exception or hangs, another shutdown call will retry *)
		END;
		(* clean up finalizers *)
		m := root;
		WHILE m # NIL DO
			IF (m.code # NIL) & (LEN(m.code)>0) THEN
				Heaps.CleanupModuleFinalizers(ADDRESSOF(m.code[0]), LEN(m.code), m.name)
			END;
			m := m.next
		END;
		IF TraceBoot OR trace THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.StringLn ("Modules.Shutdown finished");
			Machine.Release (Machine.TraceOutput);
		END;
		Machine.Shutdown(code = Reboot)	(* does not return *)
	END
END Shutdown;

(* Is this PC handled in the corresponding module. deep = scan the whole stack. *)
PROCEDURE IsExceptionHandled*(VAR pc, fp: ADDRESS; deep: BOOLEAN): BOOLEAN;
VAR
	handler: ADDRESS;
BEGIN
	IF deep THEN
		handler := GetExceptionHandler(pc);
		IF handler # -1 THEN (* Handler in the current PAF *)
			RETURN TRUE
		ELSE
			WHILE (fp # 0) & (handler = -1) DO
				SYSTEM.GET (fp + 4, pc);
				pc := pc - 1; 	(* CALL instruction, machine dependant!!! *)
				handler := GetExceptionHandler(pc);
				SYSTEM.GET (fp, fp) (* Unwind PAF *)
			END;
			IF handler = -1 THEN RETURN FALSE 	ELSE pc := handler; RETURN TRUE END
		END
	ELSE
		RETURN GetExceptionHandler(pc) # -1
	END
END IsExceptionHandled;

(* Is this PC handled in the corresponding module. If the PC is handled the PC of the
	handler is return else -1 is return. There is no problem concurrently accessing this
	procedure, there is only reading work. *)
PROCEDURE GetExceptionHandler*(pc: ADDRESS): ADDRESS;
VAR
	m: Module;

	PROCEDURE BinSearch(exTable: ExceptionTable; key: ADDRESS): ADDRESS;
	VAR
		x, l, r: SIZE;
	BEGIN
		l := 0; r:=LEN(exTable) - 1;
		REPEAT
			x := (l + r) DIV 2;
			IF key < exTable[x].pcFrom THEN r := x - 1 ELSE l := x + 1 END;
		UNTIL ((key >= exTable[x].pcFrom) & (key < exTable[x].pcTo) ) OR (l > r);

		IF (key >= exTable[x].pcFrom) & (key < exTable[x].pcTo) THEN
			RETURN exTable[x].pcHandler;
		ELSE
			RETURN -1;
		END
	END BinSearch;

BEGIN
	m := ThisModuleByAdr(pc);
	IF (m # NIL) & (m.exTable # NIL) & (LEN(m.exTable) > 0) THEN
		RETURN BinSearch(m.exTable, pc);
	END;
	RETURN -1;
END GetExceptionHandler;

(** fof: to make custom solutions to the race process, described below, possible. This is not a solution to the generic problem !! *)
PROCEDURE Initialized*(m: Module): BOOLEAN;
BEGIN
	RETURN m.init;
END Initialized;

PROCEDURE Register- (module {UNTRACED}: Module);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(*TRACE(module.name);*)
	IF register.first = NIL THEN
		register.first := module;
	ELSE
		SYSTEM.PUT (ADDRESS OF register.last.next, module); (* transitively unsafe access via register.last *)
	END;
	register.last := module;
END Register;

PROCEDURE Unregister(m: Module);
VAR prev: Module;
BEGIN
	ASSERT(m#NIL);
	IF register.first = NIL THEN RETURN
	ELSIF m = register.first THEN
		register.first := m.next;
		IF register.first = NIL THEN register.last := NIL END;
	ELSE
		prev := register.first;
		WHILE (prev.next # NIL) & (prev.next # m) DO
			prev := prev.next;
		END;
		IF prev.next = m THEN
			prev.next := prev.next.next;
			IF prev.next = NIL THEN register.last := prev END;
		 END;
	END;
	m.next := NIL;
END Unregister;

PROCEDURE PublishRegisteredModules;
VAR m {UNTRACED}, prev {UNTRACED}, cur {UNTRACED}: Module; import: SIZE;
BEGIN
	#IF COOP THEN
		Activities.Call (Activities.Idle);
	#END
	WHILE register.first # NIL DO
		m := register.first;
		(*
			register.first := m.next;
			m.next := NIL;
		*)
		IF m.module # NIL THEN
			FOR import := 0 TO LEN (m.module) - 1 DO
				IF ~m.module[import].published THEN
					ASSERT(register.first # NIL);
					(*prev := NIL;
					cur := register.first;
					WHILE (cur # NIL) & (cur # m.module[import]) DO
						prev := cur;
						cur := cur.next
					END;
					(*ASSERT(cur = m.module[import]);*)
					ASSERT(cur = m.module[import]);
					IF prev = NIL THEN
						register.first := cur.next
					ELSE
						prev.next := cur.next;
					END;
					cur.next := NIL;
					*)
					Initialize0 (m.module[import]);
				END
			END;
		END;
		Initialize0 (m);
	END;
END PublishRegisteredModules;

#IF COOP THEN

PROCEDURE FinalizeModules;
VAR module {UNTRACED}: Module;
PROCEDURE Finalize  (module {UNTRACED}: Module) EXTERN "BaseTypes.Object.Finalize";
BEGIN {UNCOOPERATIVE, UNCHECKED}
	module := root;
	WHILE module # NIL DO
		Finalize (module);
		module := module.next;
	END;
END FinalizeModules;

PROCEDURE {CLOSING} Main;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	SYSTEM.SetActivity (NIL);
	SYSTEM.SetFramePointer (NIL);
	Environment.Initialize;
	GarbageCollector.Initialize;
	Processors.Initialize;
	Activities.Execute (PublishRegisteredModules);
	Processors.Terminate;
	FinalizeModules;
	Activities.Terminate;
	Queues.Terminate;
	Environment.Terminate;
	GarbageCollector.Terminate;
	Environment.Exit (Environment.status);
END Main;

#ELSE

(* procedure that will be called last in a linked kernel *)
PROCEDURE {CLOSING} Main-;
PROCEDURE ExitA2 () EXTERN "Objects.ExitA2";
BEGIN
	(*Machine.Init;*)
	IF TraceBoot THEN
		Trace.String("publish registered modules"); Trace.Ln;
	END;
	PublishRegisteredModules;
#IF SHAREDLIB THEN
	ExitA2; (*! at this point the DLL loading thread exits the A2 (returns from Kernel32.EntryPoint/DllMain) *)
#ELSE
	(* a standard A2 kernel does not reach this point, but for standalone executables this is required *)
	Machine.Shutdown(FALSE);
#END;
END Main;

#END

PROCEDURE Init;
VAR
	s: ARRAY 4 OF CHAR;
BEGIN
	(* root and initBlock are initialized by the linker *)
	shutdown := None;
	numLoaders := 0;
	freeRoot := NIL;
	Machine.GetConfig("TraceModules", s);
	trace := (s[0] = "1");
END Init;

BEGIN
	Init;
END Modules.

