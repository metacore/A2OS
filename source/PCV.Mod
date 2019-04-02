(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCV; (** AUTHOR "prk / be"; PURPOSE "Parallel Compiler: symbol allocation"; *)

IMPORT
	StringPool, KernelLog,
	PCM, PCT, PCBT, PCLIR, PCC;

CONST
	Trace = FALSE;

(*
		(*procedure parameters*)
	RecVarParSize = 8;
	VarParSize = 4;

		(* Procedure Parameter Offsets *)
	ProcOff = 8;
	ProcOffSL = 12;
*)

		(* back-end types *)
	Signed = TRUE; Unsigned = FALSE;

VAR
	ptrsize, procsize, delegsize: PCBT.Size;	(*used by TypeSize*)

	AAllocPar, AAllocParSize,	(*allocated parameters, parameters that required TypeSize*)
	AfieldAllocated: LONGINT;	(*allocating an already allocated field*)

PROCEDURE VarOffset(VAR offset, varOffset: LONGINT;  var: PCT.Variable);
VAR size: LONGINT;
BEGIN
	size := var.type.size(PCBT.Size).size;
	INC(offset, size);
	IF size >= 4 THEN  INC(offset, (-offset) MOD 4)
	ELSIF size = 2 THEN  INC(offset, (-offset) MOD 2)
	END;
	varOffset := -offset
END VarOffset;

PROCEDURE ParOffset(VAR offset, varOffset: LONGINT; type: PCT.Struct; isRef: BOOLEAN; flags: SET);  (* ug *)
VAR size: LONGINT; open: BOOLEAN;enhopen: BOOLEAN; (* fof *)
BEGIN
	IF (type IS PCT.Array) & ({PCT.WinAPIParam,PCT.CParam}*flags #{} (* fof for linux *) ) THEN DEC(type.size(PCBT.Size).size, PCLIR.CG.ParamAlign) END; (* Notag *)
	size := type.size(PCBT.Size).size;
	open := (type IS PCT.Array) & (type(PCT.Array).mode = PCT.open);
	(** fof >> *)
	enhopen := (type IS PCT.EnhArray) & (type( PCT.EnhArray ).mode = PCT.open);
	(** << fof  *)
	IF isRef & ~open THEN
       	IF type IS PCT.Record THEN (* fof start*)
          		 IF PCT.WinAPIParam IN flags THEN
               		size := PCLIR.CG.ParamAlign
          		 ELSIF PCT.CParam IN flags THEN (* fof for Linux *)
               				size := PCLIR.CG.ParamAlign
               			ELSE
               	size := PCLIR.CG.ParamAlign * 2
           		END
			(* fof end *)
       	ELSE  size := PCLIR.CG.ParamAlign
       	END
		(** fof >> *)
		ELSIF   isRef & enhopen THEN  (* VAR A: ARRAY [..] OF ... *)
			size := PCLIR.CG.ParamAlign
		(** << fof  *)
   	END;
	INC(offset, size);
	INC(offset, (-offset) MOD PCLIR.CG.ParamAlign);
	varOffset := offset
END ParOffset;

PROCEDURE FieldOffset(VAR offset: LONGINT;  size, align: LONGINT;  p: PCT.Symbol);
VAR  adr: PCBT.Variable;
BEGIN
	IF p.adr # NIL THEN
		INC(AfieldAllocated)
	ELSE
		NEW(adr); p.adr := adr;
		IF align = 4 THEN  INC(offset, (-offset) MOD 4)
		ELSIF align = 2 THEN  INC(offset, (-offset) MOD 2)
		ELSIF align # 1 THEN  HALT(99)
		END;
		adr.offset := offset
	END;
(*
;PCM.LogWLn; PCM.LogWStr("FieldOffset "); PCM.LogWStr(p.name); PCM.LogWNum(offset);
PCM.LogWNum(size); PCM.LogWNum(align);
*)
	INC(offset, size)
END FieldOffset;

PROCEDURE TypeSizeShallow(type: PCT.Struct; VAR redo: BOOLEAN);
(* fof 070917
create a type size recursively without traversing pointers in data structures.
needed to prevent deadlock in the following situation

TYPE
	A= OBJECT
	VAR b: (any Data structure containing a variable of type B)
	(example:  b: ARRAY 10 OF B )
	END A;

	B=OBJECT
	VAR a: (any Data structure containing a variable of type A)
	(example:  a: RECORD c,d,e: LONGINT; a: A; END;
	END B;

	The deadlock prevention is based on the allocation of size descriptors for a type X
	before traversing any pointers being contained (directly or indirectly) in X

	Pointers are identified by recursive traversal of types
*)

VAR  size, fsize: PCBT.Size; recsize, brecsize: PCBT.RecSize; t: PCT.Struct;
		f: PCT.Variable;
BEGIN
	IF type.size= NIL THEN
		IF type IS PCT.Basic THEN
			HALT(99);
		ELSIF type IS PCT.Pointer THEN
			NEW(size);
			size.size := ptrsize.size; size.align := 4; size.type := PCLIR.Address;
			size.containPtrs := TRUE;
			type.size := size;
			redo := TRUE; (* contains pointers, therefore recursion has to be restartet after allocation of size descriptors *)
		ELSIF type IS PCT.Record THEN
			WITH type: PCT.Record DO
				IF (PCM.GetProcessID() # type.scope.ownerID)  THEN
					type.scope.Await(PCT.structshallowallocated);
				ELSE
					NEW(recsize);  recsize.type := PCLIR.NoSize; recsize.level := 0;
					IF type.brec # NIL THEN
						TypeSizeShallow(type.brec,redo); brecsize := type.brec.size(PCBT.RecSize);
						recsize.size := brecsize.size;
						recsize.level := brecsize.level+1;
						recsize.containPtrs := brecsize.containPtrs;
						IF ~type.imported & type.brec.imported THEN PCBT.AllocateTD(brecsize) END
					END;
					f := type.scope.firstVar;
					WHILE f # NIL DO
						t := f.type;
						TypeSizeShallow(t,redo);
						fsize := t.size(PCBT.Size);
						recsize.containPtrs := recsize.containPtrs OR fsize.containPtrs;
						FieldOffset(recsize.size, fsize.size, fsize.align, f);
						f := f.nextVar
					END;
					INC(recsize.size, (-recsize.size) MOD 4);
					recsize.align := 4;
					ASSERT(type.size = NIL);
					type.size := recsize;
					PCT.StateStructShallowAllocated(type.scope);
					IF ~type.imported & ~(PCT.SystemType IN type.flags) THEN PCBT.AllocateTD(recsize) END;
				END;
			END;
		ELSIF type IS PCT.Array THEN
			WITH type: PCT.Array DO
				NEW(size); size.type := PCLIR.Address;
				IF type.mode = PCT.open THEN
					size.size := type.opendim * PCLIR.CG.ParamAlign + PCLIR.CG.ParamAlign;
					size.align := PCLIR.CG.ParamAlign;
					size.containPtrs := FALSE;
					type.size := size;
					redo := TRUE;
				ELSIF type.mode = PCT.static THEN
					TypeSizeShallow(type.base,redo);
					fsize := type.base.size(PCBT.Size);
					size.size := fsize.size * type.len;
					size.align := fsize.align;
					size.containPtrs := fsize.containPtrs;
					type.size := size;
				ELSE
					HALT(98)
				END
			END
			(** fof >> *)
		ELSIF type IS PCT.EnhArray THEN
			WITH type: PCT.EnhArray DO
				NEW( size );  size.type := PCLIR.Address;
				IF type.mode = PCT.static THEN
					TypeSize( type.base );  fsize := type.base.size( PCBT.Size );
					size.size := fsize.size * type.len;   (* data, we do not write a header for static arrays. *)
					size.align := fsize.align;  size.containPtrs := fsize.containPtrs;  type.size := size;
					PCT.SetEnhArrayInc(type,fsize.size);
				ELSIF type.mode = PCT.open THEN
					(* this size corresponds to the size of the designator, not the array itself!! *)
					size.size := type.opendim * 2 * PCT.AddressSize + PCC.Descr_LenOffs * PCT.AddressSize (* has been shifted to front *) ;
					size.align := PCT.AddressSize;  size.containPtrs := TRUE; (* the designator contains a pointer to the array ! *) type.size := size;
					TypeSize( type.base );
					redo := TRUE;
				ELSE HALT( 98 )
				END
			END;
		ELSIF type IS PCT.Tensor THEN
			WITH type: PCT.Tensor DO
				NEW( size );  type.size := size;  size.size := 4;  size.align := 4;  size.type := PCLIR.Address;  size.containPtrs := TRUE;
				TypeSize( type.base );
			END;
		(** << fof  *)
		ELSIF type IS PCT.Delegate THEN
			WITH type: PCT.Delegate DO
				IF PCT.StaticMethodsOnly IN type.flags THEN
					size := procsize
				ELSE
					size := delegsize
				END;
				type.size := size;
				ASSERT(size.size > 0, 999);
				redo := TRUE; (* may contain references to self when methods in record refer to record *)
			END
		ELSIF type = PCT.String THEN	(*skip*)
		ELSE
			PCM.LogWLn;
			PCM.LogWType(type);
			HALT(97)
		END;
		IF redo THEN type.size(PCBT.Size).needsrecursion := TRUE ELSE type.size(PCBT.Size).needsrecursion := FALSE END;
	END;
END TypeSizeShallow;


PROCEDURE TypeSize(type: PCT.Struct);
VAR  size: PCBT.Size; p: PCT.Parameter; redo: BOOLEAN;
		f: PCT.Variable;
		name, namef: ARRAY 256 OF CHAR;
BEGIN
	IF type.size = NIL THEN
		PCT.GetTypeName(type, name);
		IF Trace THEN
			PCM.LogWLn; PCM.LogWStr("PCV.TypeSize "); PCM.LogWStr(name)
		END;
		IF type IS PCT.Basic THEN
			PCT.PrintString(type.owner.name); KernelLog.Ln;
			HALT(99)
		ELSIF type IS PCT.Pointer THEN
			WITH type: PCT.Pointer DO
				NEW(size);
				size.size := ptrsize.size; size.align := 4; size.type := PCLIR.Address;
				size.containPtrs := TRUE;
				type.size := size;
				TypeSize(type.base);
			END
		ELSIF type IS PCT.Record THEN
			WITH type: PCT.Record DO
				IF (PCM.GetProcessID() # type.scope.ownerID)  THEN
					type.scope.Await(PCT.structallocated);
					ASSERT(type.size # NIL, 500)
				ELSE
					redo := FALSE; TypeSizeShallow(type,redo);
					IF redo THEN
						f := type.scope.firstVar;
						WHILE f # NIL DO
							StringPool.GetString(f.name, namef);
							TypeSize(f.type);
							f := f.nextVar
						END;
					END
				END
			END
		ELSIF type IS PCT.Array THEN
			redo := FALSE; TypeSizeShallow(type,redo);
			IF redo THEN TypeSize(type(PCT.Array).base); END
		(** fof >> *)
		ELSIF type IS PCT.EnhArray THEN
			redo := FALSE; TypeSizeShallow(type,redo);
			IF redo THEN TypeSize(type(PCT.EnhArray).base); END
		ELSIF type IS PCT.Tensor THEN
			WITH type: PCT.Tensor DO
				NEW( size );  type.size := size;  size.size := 4;  size.align := 4;  size.type := PCLIR.Address;  size.containPtrs := TRUE;
				TypeSize( type.base );
			END;
		(** << fof  *)
		ELSIF type IS PCT.Delegate THEN
			WITH type: PCT.Delegate DO
				redo := FALSE; TypeSizeShallow(type,redo);
				IF redo THEN
					p := type.scope.firstPar;
					WHILE p # NIL DO
						TypeSize(p.type);
						p := p.nextPar
					END;
					TypeSize(type.return)
				END;
			END
		ELSIF type = PCT.String THEN (*skip*)
		ELSE
			PCM.LogWLn;
			PCM.LogWType(type);
			HALT(97)
		END;
		type.size(PCBT.Size).needsrecursion := FALSE;
	ELSIF type.size(PCBT.Size).needsrecursion THEN
		type.size(PCBT.Size).needsrecursion := FALSE;
		IF type  IS PCT.Pointer THEN
			TypeSize(type(PCT.Pointer).base);
		ELSIF type IS PCT.Record THEN
			WITH type: PCT.Record DO
				f := type.scope.firstVar;
				WHILE f # NIL DO
					StringPool.GetString(f.name, namef);
					TypeSize(f.type);
					f := f.nextVar
				END;
			END;
		ELSIF type IS PCT.Array THEN
			TypeSize(type(PCT.Array).base);
		ELSIF type IS PCT.Delegate THEN
			WITH type: PCT.Delegate DO
				p := type.scope.firstPar;
				WHILE p # NIL DO
					TypeSize(p.type);
					p := p.nextPar
				END;
				TypeSize(type.return)
			END
		END;
	END;
END TypeSize;

PROCEDURE AllocateParameters(p: PCT.Proc);
VAR  adr: PCBT.Variable;  offset: LONGINT;  par: PCT.Parameter;rp: PCT.ReturnParameter;(* fof *)
BEGIN
	par := p.scope.firstPar;
	offset := 0;
	WHILE (par # NIL) DO
		INC(AAllocPar);
		IF par.type.size = NIL THEN  TypeSize(par.type); INC(AAllocParSize) END;
		ASSERT(par.type.size # NIL);	(* p.scope.parent >= allocated *)
		NEW(adr); par.adr := adr;
		ParOffset(offset, adr.offset , par.type, par.ref, par.flags);
		par := par.nextPar
	END;
(*	INC(offset, ProcOff);
	IF p.level # 0 THEN  INC(offset, ProcOffSL-ProcOff)  END; *)

	INC (offset, PCLIR.CG.ParamAlign * 2);
	IF p.level # 0 THEN  INC (offset, PCLIR.CG.ParamAlign)  END;

	par := p.scope.firstPar;
	WHILE (par # NIL) DO
		par.adr(PCBT.Variable).offset := offset - par.adr(PCBT.Variable).offset;
		par := par.nextPar
	END;
	(** fof >> *)
	rp := p.scope.returnParameter;
	IF rp #NIL THEN
		IF rp.type.size = NIL THEN TypeSize(rp.type); END;
		NEW(adr); rp.adr := adr;
		adr.offset := offset ;
	END;
	(** << fof  *)
	p.adr(PCBT.Procedure).parsize := offset;
END AllocateParameters;

PROCEDURE AllocateTypes(t: PCT.Type; v: PCT.Variable);
BEGIN
	WHILE t # NIL DO
		TypeSize(t.type); t := t.nextType
	END;
	WHILE v # NIL DO
		TypeSize(v.type); v := v.nextVar
	END;
END AllocateTypes;

PROCEDURE AllocateLocals(var: PCT.Variable; VAR size: LONGINT);
	VAR offset: LONGINT; ladr: PCBT.Variable;
BEGIN
	offset := size;
	WHILE var # NIL DO
		TypeSize(var.type);
		NEW(ladr); var.adr := ladr;
		VarOffset(offset, ladr.offset , var);
		var := var.nextVar
	END;
	INC(offset, (-offset) MOD PCLIR.CG.ParamAlign);
	size := offset;
END AllocateLocals;

PROCEDURE AllocateGlobals(var: PCT.Variable; mod: PCBT.Module; setOffset: BOOLEAN; VAR size: LONGINT);
	VAR offset: LONGINT; gadr: PCBT.GlobalVariable;
BEGIN
	offset := size;
	WHILE var # NIL DO
		TypeSize(var.type);
		NEW(gadr, mod); var.adr := gadr;
		IF setOffset THEN VarOffset(offset, gadr.offset , var) END;
		var := var.nextVar
	END;
	INC(offset, (-offset) MOD 4);
	size := offset;
END AllocateGlobals;

(** PreAllocate - called on scope creation, creates PCBT.Address struct *)

PROCEDURE PreAllocate*(context, scope: PCT.Scope);
VAR proc: PCT.Proc; adr: PCBT.Procedure; madr: PCBT.Method;
	gadr: PCBT.GlobalVariable; zero: HUGEINT; imported, visible: BOOLEAN;
	mod: PCBT.Module;
BEGIN
	IF (scope IS PCT.ProcScope) THEN
		WITH scope: PCT.ProcScope DO
			mod := scope.module.adr(PCBT.Module);
			proc := scope.ownerO;
			visible := (PCT.PublicR IN proc.vis);
			ASSERT(proc.adr = NIL);
			IF proc IS PCT.Method THEN
				NEW(madr, mod, visible);
				proc.adr := madr
			ELSE
				NEW(adr, mod, visible);
				proc.adr := adr
			END
		END
	ELSIF scope IS PCT.ModScope THEN
		WITH scope: PCT.ModScope DO
			imported := scope # context;
			NEW(mod); scope.owner.adr := mod;
			IF ~imported THEN
				(*PCM.LogWLn; PCM.LogWStr("PCV.PreAllocate: New PCBT.context");*)
				PCBT.context := mod;
				IF (scope.firstVar # NIL) & (scope.firstVar.name = PCT.SelfName) THEN
					NEW(gadr, PCBT.context); scope.firstVar.adr := gadr;
					gadr.offset := PCBT.context.NewConst(zero, PCT.AddressSize);
				END
			END
		END
	END
END PreAllocate;


(** Allocate - scope declarations (var/types) parsed *)

PROCEDURE Allocate*(context, scope: PCT.Scope; hiddenVarsOnly: BOOLEAN (* ug *));
	VAR proc: PCT.Proc; madr: PCBT.Module; globals: PCT.Variable;
BEGIN
	IF scope IS PCT.RecScope THEN
		IF ~hiddenVarsOnly THEN
			TypeSize(scope(PCT.RecScope).owner)
		END
	ELSIF scope IS PCT.ProcScope THEN
		WITH scope: PCT.ProcScope DO
			proc := scope.ownerO;
			IF hiddenVarsOnly THEN
				AllocateLocals(scope.firstHiddenVar, proc.adr(PCBT.Procedure).locsize)
			ELSE
				AllocateParameters(proc);
				AllocateTypes(scope.firstType, scope.firstVar);
				AllocateLocals(scope.firstVar, proc.adr(PCBT.Procedure).locsize)
			END
		END
	ELSIF scope IS PCT.ModScope THEN
		WITH scope: PCT.ModScope DO
			madr := scope.owner.adr(PCBT.Module);
			IF hiddenVarsOnly THEN
				AllocateGlobals(scope.firstHiddenVar, madr, context = scope, madr.locsize)
			ELSE
				AllocateTypes(scope.firstType, scope.firstVar);
				globals := scope.firstVar;
(*
				ASSERT((scope.imported) OR (globals.name = PCT.SelfName));
*)
				IF (globals # NIL) & (globals.name = PCT.SelfName) THEN globals := globals.nextVar END;
				AllocateGlobals(globals, madr, context = scope, madr.locsize)
			END
		END
	END
END Allocate;


(** PostAllocate - scope procedures parsed *)

PROCEDURE PostAllocate*(context, scope: PCT.Scope);
VAR  p: PCT.Symbol; rec: PCT.Record; recsize: PCBT.RecSize;
BEGIN
	IF scope IS PCT.RecScope THEN
		WITH scope: PCT.RecScope DO
			rec := scope.owner;
			recsize := rec.size(PCBT.RecSize);
			IF rec.brec # NIL THEN
				rec.brec.scope.Await(PCT.procdeclared);
				recsize.nofMethods := rec.brec.size(PCBT.RecSize).nofMethods
			END;
			p := scope.sorted;
			WHILE p # NIL DO
				IF p IS PCT.Method THEN
					WITH p: PCT.Method DO
						INC(recsize.nofLocalMethods);
						IF p.super = NIL THEN
							p.adr(PCBT.Method).mthNo := recsize.nofMethods;
							INC(recsize.nofMethods)
						ELSE
							p.adr(PCBT.Method).mthNo := p.super.adr(PCBT.Method).mthNo
						END
					END
				END;(*if Method*)
				p := p.sorted
			END
		END(*WITH RecScope*)
	END
END PostAllocate;

PROCEDURE BasicSize(type: PCT.Struct; size, align: LONGINT; BEsize: PCLIR.Size; signed: BOOLEAN);
VAR adr: PCBT.Size;
BEGIN
	NEW(adr); type.size := adr; adr.size := size; adr.align := align; adr.type := BEsize; adr.signed := signed;
	adr.containPtrs := type = PCT.Ptr
END BasicSize;

PROCEDURE Install*;
BEGIN
	PCT.PreAllocate := PreAllocate;
	PCT.Allocate := Allocate;
	PCT.PostAllocate := PostAllocate
END Install;

PROCEDURE SetBasicSizes*;

	PROCEDURE GetSize (size: PCLIR.Size): LONGINT;
	BEGIN
		CASE size OF
		PCLIR.Int8: RETURN 1;
		| PCLIR.Int16: RETURN 2;
		| PCLIR.Int32: RETURN 4;
		| PCLIR.Int64: RETURN 8;
		END;
	END GetSize;

	PROCEDURE GetAlign (size: PCLIR.Size): LONGINT;
	BEGIN
		CASE size OF
		PCLIR.Int8: RETURN 1;
		| PCLIR.Int16: RETURN 2;
		| PCLIR.Int32: RETURN 4;
		| PCLIR.Int64: RETURN 4;
		END;
	END GetAlign;

	PROCEDURE DeduceBasicSize (type: PCT.Struct; size: PCLIR.Size; signed: BOOLEAN);
	BEGIN
		BasicSize (type, GetSize (size), GetAlign (size), size, signed);
	END DeduceBasicSize;

BEGIN
	DeduceBasicSize (PCT.Set, PCLIR.Set, Unsigned);
	DeduceBasicSize (PCT.NilType, PCLIR.Address, Unsigned);
	DeduceBasicSize (PCT.Ptr, PCLIR.Address, Unsigned);

	(* wrapping the following assignments into a helper function does not work *)

	CASE PCLIR.Address OF
	PCLIR.Int32: PCT.Address := PCT.Int32;
	| PCLIR.Int64: PCT.Address := PCT.Int64;
	END;

	PCT.SystemAddress.type := PCT.Address;

	CASE PCLIR.Set OF
	PCLIR.Int32: PCT.SetType := PCT.Int32;
	| PCLIR.Int64: PCT.SetType := PCT.Int64;
	END;

	CASE PCLIR.SizeType OF
	PCLIR.Int32: PCT.Size := PCT.Int32;
	| PCLIR.Int64: PCT.Size := PCT.Int64;
	END;

	PCT.SystemSize.type := PCT.Size;

	procsize.size := GetSize (PCLIR.Address);
	procsize.type := PCLIR.Address;
	delegsize.size := procsize.size * 2;
	delegsize.type := procsize.type;

	ptrsize := PCT.Ptr.size(PCBT.Size);

	PCT.AddressSize := GetSize (PCLIR.Address);
	PCT.SetSize := GetSize (PCLIR.Set);
END SetBasicSizes;

BEGIN
	IF Trace THEN PCM.LogWLn; PCM.LogWStr("PCV.Trace on") END;
	BasicSize(PCT.NoType, -1, 1, PCLIR.NoSize, Unsigned);
	BasicSize(PCT.UndefType, -1, 1, PCLIR.NoSize, Unsigned);
	BasicSize(PCT.Bool, 1, 1, PCLIR.Int8, Unsigned);
	BasicSize(PCT.Byte, 1, 1, PCLIR.Int8, Unsigned);
	BasicSize(PCT.Char8, 1, 1, PCLIR.Int8, Unsigned);
	IF PCM.LocalUnicodeSupport THEN
		BasicSize(PCT.Char16, 2, 2, PCLIR.Int16, Unsigned);
		BasicSize(PCT.Char32, 4, 4, PCLIR.Int32, Unsigned);
	END;
	BasicSize(PCT.Int8, 1, 1, PCLIR.Int8, Signed);
	BasicSize(PCT.Int16, 2, 2, PCLIR.Int16, Signed);
	BasicSize(PCT.Int32, 4, 4, PCLIR.Int32, Signed);
	BasicSize(PCT.Int64, 8, 4, PCLIR.Int64, Signed);
	BasicSize(PCT.Float32, 4, 4, PCLIR.Float32, Signed);
	BasicSize(PCT.Float64, 8, 4, PCLIR.Float64, Signed);
	BasicSize(PCT.Set, 4, 4, PCLIR.Int32, Unsigned);
	BasicSize(PCT.NilType, 4, 4, PCLIR.Address, Unsigned);
	BasicSize(PCT.Ptr, 4, 4, PCLIR.Address, Unsigned);
	ptrsize := PCT.Ptr.size(PCBT.Size);
	NEW(procsize);
	procsize.size := 4; procsize.align := 4; procsize.type := PCLIR.Address; procsize.containPtrs := FALSE;
	NEW(delegsize);
	delegsize.size := 8; delegsize.align := 4; delegsize.type := PCLIR.Address; delegsize.containPtrs := TRUE;
END PCV.

(*
	18.03.02	prk	PCBT code cleanup and redesign
	22.02.02	prk	unicode support
	11.12.01	prk	problem parsing invalid WITH syntax fixed
	28.11.01	prk	explicitly install PCV, avoid depending on the import list sequence
	05.09.01	prk	CanSkipAllocation flag for record scopes
	27.08.01	prk	scope.unsorted list removed; use var, proc, const and type lists instead
	17.08.01	prk	overloading
	13.08.01	prk	fixed bug in allocation size of delegates used in a record but decalred outside
	11.08.01	prk	Fixup and use lists for procedures in PCBT cleaned up
	10.08.01	prk	PCBT.Procedure: imported: BOOLEAN replaced by owner: Module
	09.08.01	prk	Symbol Table Loader Plugin
	02.07.01	prk	access flags, new design
	27.06.01	prk	StringPool cleaned up
	14.06.01	prk	type descs for dynamic arrays of ptrs generated by the compiler
	06.06.01	prk	use string pool for object names
	17.05.01	prk	Delegates
	07.05.01	be	register sign information added in the back-end
	25.03.01	prk	limited HUGEINT implementation (as abstract type)
	22.02.01	prk	delegates
*)