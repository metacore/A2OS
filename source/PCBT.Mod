(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCBT; (** AUTHOR "prk / be"; PURPOSE "Parallel Compiler: back-end common structures"; *)

IMPORT
		SYSTEM, PCM, PCT;

CONST
	(*static buffer for constants*)
	MaxConstSize = 2147483647; (* 2^31 - 1, i.e. the maximum positive SIGNED32 number *)


	(** system calls *)
	DefaultNofSysCalls* = 12;
	newrec* = 0;  newarr* = 1;  newsys* = 2;  casetable* = 3;  procaddr* = 4;
	lock* = 5;  unlock* = 6;  start* = 7;  passivate* = 8; interfacelookup* = 9;
	registerinterface* = 10; getprocedure* = 11;

	(** Fixup, last address in a fixup chain *)
	FixupSentinel* = SIGNED32(0FFFFFFFFH);
	UndefEntryNo* = -1;	(** GlobalVariable.EntryNo *)

	(** Calling Conventions *)
	OberonCC* = 1;  OberonPassivateCC* = 2;  WinAPICC* = 3; (* ejz *) CLangCC*= 4; (* fof for Linux *)

VAR
	init: BOOLEAN;

TYPE
	ConstArray* = POINTER TO ARRAY OF CHAR;

	(** ----------- Size - type related information -------------- *)

	Size* = OBJECT (PCM.Attribute)
	VAR
		size*: SIGNED32;	(** size in bytes, used for allocation*)
		align*: SIGNED32;	(** on which boundary should this type be aligned *)
		type*: SIGNED8;	(** Back-End Type *)
		signed*: BOOLEAN;
		containPtrs*: BOOLEAN;
		needsrecursion*: BOOLEAN;
	END Size;

	RecSize* = OBJECT (Size)
	VAR
		td*: GlobalVariable;
		level*: SIGNED32;
		nofMethods*, nofLocalMethods*: SIGNED32;
	END RecSize;



	(** ----------- Address - allocation related information ------- *)

	(** Fixup - offset to be patched at a later time *)
	Fixup* = POINTER TO RECORD
		offset-: SIGNED32;
		next-: Fixup
	END;

	Variable* = OBJECT (PCM.Attribute)
	VAR
		offset*: SIGNED32
	END Variable;

	GlobalVariable* = OBJECT (Variable)
		VAR
			owner-: Module;
			entryNo*: SIGNED16;	(** object-file information set by PCOF *)

			link-: Fixup;	(** occourencies of var in code *)
			next-: GlobalVariable;	(** next GVar in the list *)

		PROCEDURE AddFixup(offset: SIGNED32);
			VAR l: Fixup;
		BEGIN
			NEW(l); l.offset := offset; l.next := link; link := l
		END AddFixup;

		(** Init - Initialize structure *)

		PROCEDURE & Init*(owner: Module);
		BEGIN
			SELF.owner := owner;
			entryNo := UndefEntryNo;
			ASSERT((owner # NIL) OR (SELF = sentinel) OR (sentinel = NIL));
		END Init;
	END GlobalVariable;

	(* ug *)
	Attribute* = OBJECT(PCM.Attribute)	(* common part of Procedure and Module *)
		VAR
			codeoffset-: SIGNED32;  (* entry point relative to code base of owner*)
			beginOffset- : SIGNED32;	 (* entry point relative to code base of owner*)	(* ug *)
			endOffset- : SIGNED32;  (* offset of statement block end relative to code base *)	(* ug *)

		PROCEDURE SetBeginOffset*(offset : SIGNED32);  (* ug *)
		BEGIN
			beginOffset := offset
		END SetBeginOffset;

		PROCEDURE SetEndOffset*(offset : SIGNED32); (* ug *)
		BEGIN
			endOffset := offset
		END SetEndOffset;

	END Attribute;

	Procedure* = OBJECT (Attribute)
		VAR
			owner-: Module;
			public-: BOOLEAN;
			locsize*: SIGNED32;	(* local variables size *)
			parsize*: SIGNED32;	(* parameters size incl. self/sl, return addr and dynamic link *)
			entryNr*, fixlist*: SIGNED32;	(* set/used by PCOF *)
			next-: Procedure;	(* entrylist *)
			link-: Fixup;
			finallyOff*: SIGNED32; (* Offset of the handled region. Relative to the codeoffset. *)

		PROCEDURE AddFixup(offset: SIGNED32);
			VAR l: Fixup;
		BEGIN
			NEW(l); l.offset := offset; l.next := link; link := l
		END AddFixup;

		PROCEDURE & Init*(owner: Module;  public: BOOLEAN);
		BEGIN
			ASSERT((owner # NIL) OR init);
			SELF.owner := owner;
			SELF.public := public;
			fixlist := FixupSentinel;
			finallyOff := -1;
		END Init;

	END Procedure;

	Method* = OBJECT (Procedure)
	VAR
		mthNo*: SIGNED32
	END Method;

	Module* = OBJECT (Attribute)
		VAR
			locsize*: SIGNED32;			(** data section size*)
			constsize*: SIGNED16;			(** const section size*)
			casetablesize*: SIGNED16;  	(** length of case table within const section *) (* ug *)
			nr*: SIGNED16;

			const*: ConstArray;

			OwnProcs-: Procedure;		(** this module's procedures; terminated by psentinel *)
			ExtProcs-: Procedure;			(** external procedures used; terminated by psentinel *)

			OwnVars-: GlobalVariable;	(** this module's used variables; terminated by sentinel *)
			ExtVars-: GlobalVariable;	(** external used variables; terminated by sentinel *)

			syscalls-: POINTER TO ARRAY OF Fixup;	(** syscalls' fixup lists *)

			finallyOff*: SIGNED32; (* offset of the finally in the module init code *)

		PROCEDURE & Init*;
		BEGIN
			NEW(syscalls, NofSysCalls);
			NEW(const, 128);
			ResetLists;
			constsize := 0;
			nr := 0;
			finallyOff := -1;
		END Init;

		(** ResetLists - remove entries from OwnVars, ExtVars, OwnProcs, ExtProcs *)

		PROCEDURE ResetLists*;
			VAR i: SIGNED32;

			PROCEDURE KillPList(VAR root: Procedure);
				VAR p, q: Procedure;
			BEGIN
				p := root; root := psentinel;
				WHILE p # NIL DO
					q := p;
					p := p.next;
					q.link := NIL;
					q.next := NIL
				END;
			END KillPList;

			PROCEDURE KillVList(VAR root: GlobalVariable);
				VAR p, q: GlobalVariable;
			BEGIN
				p := root; root := sentinel;
				WHILE p # NIL DO
					q := p;
					p := p.next;
					q.entryNo := UndefEntryNo;
					q.link := NIL;
					q.next := NIL;
				END;
			END KillVList;

		BEGIN
			KillPList(OwnProcs); KillPList(ExtProcs);
			KillVList(OwnVars); KillVList(ExtVars);
			FOR i := 0 TO NofSysCalls-1 DO  syscalls[i] := NIL  END;
		END ResetLists;

		(*fof: increase constant section size - for case tables - thread safe version for PCG386*)
		PROCEDURE AddCasetable*(tablesize: SIGNED32): SIGNED32;
		VAR size,base: SIGNED32; c: ConstArray;
		BEGIN{EXCLUSIVE}
			size := constsize+tablesize*4;
			ASSERT(size < MaxConstSize);
			IF size >= LEN(const^) THEN
				INC(size,(-size) MOD 256); (* align to 255 bytes to prevent from allocating too often *)
				NEW(c, size);
				SYSTEM.MOVE(ADDRESSOF(const[0]), ADDRESSOF(c[0]), LEN(const));
				const := c
			END;
			size := constsize;
			INC(constsize,SHORT(tablesize*4));
			INC(casetablesize,SHORT(tablesize));
			RETURN size;
		END AddCasetable;

		(** NewConst - Create a new constant *)

		PROCEDURE NewConst*(VAR a: ARRAY OF SYSTEM.BYTE;  len: SIGNED32): SIGNED32;
		VAR  base: SIGNED32; c: ConstArray;
		BEGIN {EXCLUSIVE}
			ASSERT(len <= LEN(a));
			base := constsize;
			ASSERT(base+len < MaxConstSize);
			IF base+len >= LEN(const^) THEN
				NEW(c, LEN(const) + 256);
				SYSTEM.MOVE(ADDRESSOF(const[0]), ADDRESSOF(c[0]), LEN(const));
				const := c
			END;

			IF PCM.bigEndian THEN
				IF len = 8 THEN (* const is 64 bits (e.g. SIGNED64, FLOAT64)-> swap low and high 4-byte words separately *)
					PCM.SwapBytes(a, 0, 4); PCM.SwapBytes(a, 4, 4);
				ELSE
					PCM.SwapBytes(a, 0, len);
				END;
			END;

			SYSTEM.MOVE(ADDRESSOF(a[0]), ADDRESSOF(const[base]), len);
			INC(constsize, SHORT(len + (-len) MOD 4));
			RETURN base
		END NewConst;

		(** NewStringConst - Create a new string constant; used for big endian: do not change endianness
				of string constants *)

		PROCEDURE NewStringConst*(VAR a: ARRAY OF SYSTEM.BYTE;  len: SIGNED32): SIGNED32;
		VAR  base: SIGNED32; c: ConstArray;
		BEGIN {EXCLUSIVE}
			ASSERT(len <= LEN(a));
			base := constsize;
			ASSERT(base+len < MaxConstSize);
			IF base+len >= LEN(const^) THEN
				NEW(c, LEN(const) + 256);
				SYSTEM.MOVE(ADDRESSOF(const[0]), ADDRESSOF(c[0]), LEN(const));
				const := c
			END;

			SYSTEM.MOVE(ADDRESSOF(a[0]), ADDRESSOF(const[base]), len);

			INC(constsize, SHORT(len + (-len) MOD 4));
			RETURN base
		END NewStringConst;


	(** fof >> *)
	(** NewArrayConst - Create a new array constant;  *)
		PROCEDURE NewArrayConst*( VAR a: ARRAY OF CHAR;  VAR len: ARRAY OF SIGNED32;  blen: SIGNED32 ): SIGNED32;
		VAR base: SIGNED32;  c: ConstArray;  tlen, tdim: SIGNED32;  clen: SIZE; alen, tbase: SIGNED32;  dim: SIZE;
		BEGIN {EXCLUSIVE}
			base := constsize;  dim := LEN( len );  tlen := blen;  tdim := 0;
			WHILE (tdim < dim) DO tlen := tlen * len[tdim];  INC( tdim );  END;
			ASSERT ( tlen <= LEN( a ) );
			alen := tlen;
			ASSERT ( base + alen < MaxConstSize );
			clen := LEN( const^ );
			IF base + alen >= clen THEN
				NEW( c, clen + 256 + 256 * (base + alen - clen) DIV 256 );
				SYSTEM.MOVE( ADDRESSOF( const[0] ), ADDRESSOF( c[0] ), clen );  const := c;
			END;
			tbase := base;
			SYSTEM.MOVE( ADDRESSOF( a[0] ), ADDRESSOF( const[tbase] ), tlen );   (* data copy *)
			INC( constsize, SHORT( alen + (-alen) MOD 4 ) );
			RETURN base;
		END NewArrayConst;
		(** << fof  *)

		(** UseVar - insert a fixup, add to ExtVars or OwnVars *)

		PROCEDURE UseVariable*(v: GlobalVariable; offset: SIGNED32);
		BEGIN
			v.AddFixup(offset);
			IF v.next = NIL THEN
				IF v.owner = SELF THEN
					v.next := OwnVars; OwnVars := v
				ELSE
					v.next := ExtVars; ExtVars := v
				END
			END
		END UseVariable;

		(** AddOwnProc - Insert local procedure into OwnProcs list *)

		PROCEDURE AddOwnProc*(p: Procedure; codeOffset: SIGNED32);
		BEGIN (*{EXCLUSIVE}*)
			ASSERT(p.owner = context, 500);	(* must be local *)
			ASSERT((p.next = NIL), 501);			(* not inserted yet *)
			p.next := OwnProcs; OwnProcs := p;
			p.codeoffset := codeOffset
		END AddOwnProc;

		(** UseProcedure - insert a fixup entry, add to ExtProcs list (if external) *)

		PROCEDURE UseProcedure*(p: Procedure; offset: SIGNED32);
		BEGIN
			p.AddFixup(offset);
			IF (p.owner # SELF) & (p.next = NIL) THEN
				BEGIN {EXCLUSIVE}
					p.next := ExtProcs; ExtProcs := p
				END
			END
		END UseProcedure;

		(** UseSyscall - Add a syscall fixup *)

		PROCEDURE UseSyscall*(syscall, offset: SIGNED32);
			VAR l: Fixup;
		BEGIN
			NEW(l); l.offset := offset;
			BEGIN {EXCLUSIVE}
				l.next := syscalls[syscall]; syscalls[syscall] := l
			END;
		END UseSyscall;
	END Module;

	ObjFGeneratorProc* = PROCEDURE (VAR R: PCM.Rider; scope: PCT.ModScope;  VAR codeSize: SIGNED32);

VAR
	NofSysCalls-: SIGNED32;
	sentinel-: GlobalVariable;	(*last element of the VarEntries list *)
	psentinel-: Procedure;	(** last element of the OwnProcs list *)
	context*: Module;
	generate*: ObjFGeneratorProc;

(** --------------- Miscellaneous ------------------ *)

PROCEDURE SetNumberOfSyscalls*(nofsyscalls: SIGNED32);
BEGIN
	ASSERT(nofsyscalls >= DefaultNofSysCalls, 100);
	NofSysCalls := nofsyscalls
END SetNumberOfSyscalls;

(** ------------ Resource Allocation ----------------- *)

PROCEDURE AllocateTD*(size: RecSize);	(** td => record.td *)
VAR  zero: SIGNED64; ga: GlobalVariable; (* lk *)
BEGIN {EXCLUSIVE}
	IF size.td = NIL THEN
		zero := 0;
		NEW(ga, context);
		ga.offset := context.NewConst(zero, PCT.AddressSize); (* lk *)
		size.td := ga;
	END
END AllocateTD;

BEGIN
	init := TRUE;
	sentinel := NIL;
	NEW(sentinel, NIL);
	NEW(psentinel, NIL , FALSE);
	NofSysCalls := DefaultNofSysCalls;
	init := FALSE;
END PCBT.

(*
	15.11.06	ug	FixupSentinel extended to 32 bits, MaxConstSize adapted, additional information in type Procedure for GC
	18.03.02	prk	PCBT code cleanup and redesign
	11.08.01	prk	Fixup and use lists for procedures in PCBT cleaned up
	10.08.01	prk	PCBT.Procedure: imported: BOOLEAN replaced by owner: Module
	10.08.01	prk	PCBT.Module.imported removed
	09.08.01	prk	Symbol Table Loader Plugin
	06.08.01	prk	make code generator and object file generator indipendent
	29.05.01    be	syscall structures moved to backend (PCLIR & code generators)
	07.05.01	prk	Installable code generators moved to PCLIR; debug function added
	03.05.01	be	Installable code generators
	26.04.01	prk	separation of RECORD and OBJECT in the parser
*)

(**

PCBT use:

1. Procedure Entry Points
	When a procedure implemented in the compilation unit is emitted, it must register itself as an entry point using
		PCBT.context.AddOwnProc(procaddr, codeoffset)
	procaddr is added to the entries list, procaddr.codeoffset is set.



Invariants:
	mod.entries:
		- all entries have owner = mod
		- list terminated by PCBT.psentinel

	mod.ExtProcs:
		- all procs have owner # mod
		- list terminated by PCBT.psentinel
*)
