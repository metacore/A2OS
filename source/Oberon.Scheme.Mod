(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Scheme IN Oberon; (** portable *)	(* eos  *)

	(**
		Scheme Engine
	**)

	(*
		18.05.2000 - fixed port objects not having type

		to do:
		- quasiquotation
		- numbers
			- better I/O, especially output
			- complex and bignum numbers
			- make more robust
		- custom memory management
			- Object is SIGNED32 combining type and address
			- custom GC
		- continuations: copy contents of stack
		- macro support; replace derived expressions by library syntax
		- read only flags for symbol->string and string literals
	*)

	IMPORT
		MathL IN A2, Files, Modules, Reals IN A2, Objects, Texts, Oberon, Strings;


	CONST
		null* = 0; bool* = 1; char* = 2; string* = 3; number* = 4; reference* = 5; symbol* = 6;
		pair* = 7; vector* = 8; procedure* = 9; port* = 10; eofobj* = 11;

		newline* = 0DX;

		errEval* = 1; errUnbound* = 2; errArg* = 3; errVar* = 5; errOp* = 6; errMany* = 7;
		errFormal* = 8;

		fixnum = 1; rational = 2; flonum = 3;	(* number subtypes *)
		primitive = 5; compound = 6;	(* procedure subtypes *)
		input = 8; output = 9;	(* port subtypes *)

		maxPoolSize = 1000H; stackBlock = 100H; dirSize = 128; envSize = 32;

		invalid = 0; ident = 1; boolean = 2; character = 3; literal = 4; intnum = 5; ratnum = 6;
		realnum = 7; complexnum = 8; dot = 9; lpar = 10; rpar = 11; lvec = 12; quote = 13; quasiquote = 14;
		unquote = 15; unquotelist = 16; eof = 17;


	TYPE
		Context* = POINTER TO ContextDesc;

		(** abstract scheme objects (pointer-based implementation not to be relied on) **)
		Object* = POINTER TO ObjDesc;
		ObjDesc = RECORD
			type: SIGNED8;	(* object type *)
			sub: SIGNED8;	(* subtype *)
			dsc, next: Object;	(* optimization for pairs *)
		END;

		(** primitive procedure callback **)
		PrimEval* = PROCEDURE (ctxt: Context; args: Object; VAR res: Object);

		Evaluator = PROCEDURE (ctxt: Context);
		Buffer = POINTER TO ARRAY OF CHAR;

		Stretch = RECORD
			pos, len: SIGNED32;
			buf: Buffer;
		END;

		(** string memory pools **)
		Pool* = RECORD
			avail, pos: SIGNED32;
			buf: Buffer;
		END;

		Symbol = POINTER TO RECORD (ObjDesc)
			stretch: Stretch;
			hash: SIGNED32;
			link: Symbol;
		END;

		Binding = POINTER TO RECORD
			next: Binding;
			sym: Symbol;
			value: Object;
		END;

		(** environments for binding symbols to values **)
		Environment* = POINTER TO RECORD
			outer: Environment;
			chain: ARRAY envSize OF Binding
		END;

		Bool = POINTER TO RECORD (ObjDesc)
			b: BOOLEAN;
		END;

		Char = POINTER TO RECORD (ObjDesc)
			ch: CHAR;
		END;

		String = POINTER TO RECORD (ObjDesc)
			stretch: Stretch;
		END;

		Fixnum = POINTER TO RECORD (ObjDesc)
			int: SIGNED32;
		END;

		Flonum = POINTER TO RECORD (ObjDesc)
			real: FLOAT64;
		END;

		Rational = POINTER TO RECORD (ObjDesc)
			num, denom: SIGNED32;
		END;

		Reference = POINTER TO RECORD (ObjDesc)
			obj: Objects.Object;
		END;

		Vector = POINTER TO RECORD (ObjDesc)
			size: SIGNED32;
			elem: POINTER TO ARRAY OF Object;
		END;

		Primitive = POINTER TO RECORD (ObjDesc)
			sym: Symbol;
			eval: PrimEval;
		END;

		Procedure = POINTER TO RECORD (ObjDesc)
			env: Environment;
			body: Object;
			par: Object;
		END;

		Input = POINTER TO InputDesc;
		InputDesc = RECORD (ObjDesc)
			open, ready, eof: BOOLEAN;
			read: PROCEDURE (port: Input; VAR ch: CHAR);
			unread: PROCEDURE (port: Input);
			getpos: PROCEDURE (port: Input): SIGNED32;
		END;

		FileInput = POINTER TO RECORD (InputDesc)
			r: Files.Rider;
		END;

		TextInput = POINTER TO RECORD (InputDesc)
			r: Texts.Reader;
			text: Texts.Text;
		END;

		StringInput = POINTER TO RECORD (InputDesc)
			pos: SIGNED32;
			ps: POINTER TO ARRAY OF CHAR;
		END;

		Output = POINTER TO OutputDesc;
		OutputDesc = RECORD (ObjDesc)
			open: BOOLEAN;
			write: PROCEDURE (port: Output; ch: CHAR);
			close, flush: PROCEDURE (port: Output);
		END;

		FileOutput = POINTER TO RECORD (OutputDesc)
			r: Files.Rider;
		END;

		TextOutput = POINTER TO RECORD (OutputDesc)
			text: Texts.Text;
		END;

		ObjectElems = POINTER TO ARRAY OF Object;
		EvalElems = POINTER TO ARRAY OF Evaluator;
		EnvElems = POINTER TO ARRAY OF Environment;

		Stack = RECORD
			obj: RECORD
				size, top: SIGNED32;
				elem: ObjectElems
			END;
			eval: RECORD
				size, top: SIGNED32;
				elem: EvalElems
			END;
			env: RECORD
				size, top: SIGNED32;
				elem: EnvElems
			END
		END;

		Token = RECORD
			pos: SIGNED32;
			kind: SIGNED16;
			bool: BOOLEAN;
			char: CHAR;
			num, denom: SIGNED32;
			real: FLOAT64;
			s: ARRAY 100H OF CHAR;
		END;

		ContextDesc* = RECORD
			failed*: BOOLEAN;	(** set if evaluation error occurred **)
			in*, out*, err*: Object;	(** standard ports **)
			pool*: Pool;	(** string pool **)
			env*: Environment;	(** evaluation environment **)
			exp*: Object;	(** currently evaluated expression (operator) **)
			res, unev, args: Object;
			eval, cont: Evaluator;
			stack: Stack;
		END;


	VAR
		globals*: Environment;	(** global environment with predefined operators **)
		zero*, one*, inf*, ninf*, nan*, nil*, false*, true*, EOF*: Object;	(** standard objects **)
		symPool: Pool;
		symTab: ARRAY dirSize OF Symbol;	(* symbol hash table *)
		quoteSym, quasiquoteSym, unquoteSym, unquotelistSym,
		setSym, defineSym, lambdaSym, ifSym, beginSym, letSym,
		condSym, caseSym, elseSym, andSym, orSym, letXSym,
		letrecSym, unassignedSym, doSym, delaySym: Object;
		OutText: TextOutput;
		OutW: Texts.Writer;


	(**--- Stretches & Pools ---**)

	PROCEDURE InitPool* (VAR pool: Pool);
	BEGIN
		pool.avail := 0
	END InitPool;

	PROCEDURE AllocStretch (len: SIGNED32; VAR pool: Pool; VAR str: Stretch);
		VAR buf: Buffer; pos: SIGNED32;
	BEGIN
		IF len > maxPoolSize DIV 2 THEN	(* allocate in separate buffer *)
			NEW(buf, len); pos := 0
		ELSE
			IF pool.avail < len THEN
				NEW(pool.buf, maxPoolSize); pool.avail := maxPoolSize; pool.pos := 0
			END;
			buf := pool.buf; pos := pool.pos;
			INC(pool.pos, len); DEC(pool.avail, len)
		END;
		str.buf := buf; str.pos := pos; str.len := len
	END AllocStretch;

	PROCEDURE MakeStretch (VAR s: ARRAY OF CHAR; VAR pool: Pool; VAR str: Stretch);
		VAR len, n: SIGNED32;
	BEGIN
		len := 0; WHILE s[len] # 0X DO INC(len) END;
		AllocStretch(len, pool, str);
		n := 0; WHILE n < len DO str.buf[str.pos + n] := s[n]; INC(n) END
	END MakeStretch;

	PROCEDURE GetStretch (VAR str: Stretch; pos, len: SIZE; VAR s: ARRAY OF CHAR);
		VAR buf: Buffer; n: SIZE;
	BEGIN
		IF len >= LEN(s) THEN len := LEN(s)-1 END;
		buf := str.buf; pos := str.pos + pos; n := 0;
		WHILE n < len DO s[n] := buf[pos + n]; INC(n) END;
		s[n] := 0X
	END GetStretch;

	PROCEDURE SetStretch (VAR str: Stretch; pos, len: SIGNED32; VAR s: ARRAY OF CHAR);
		VAR buf: Buffer; n: SIZE;
	BEGIN
		buf := str.buf; pos := str.pos + pos; n := 0;
		WHILE n < len DO buf[pos + n] := s[n]; INC(n) END
	END SetStretch;

	PROCEDURE StretchEquals (VAR str: Stretch; VAR s: ARRAY OF CHAR): BOOLEAN;
		VAR n: SIZE;
	BEGIN
		n := 0;
		LOOP
			IF n = str.len THEN RETURN s[n] = 0X END;
			IF s[n] # str.buf[str.pos + n] THEN RETURN FALSE END;
			INC(n)
		END
	END StretchEquals;


	(**--- Null ---**)

	(* clients should use predefined nil object *)
	PROCEDURE NewNull (): Object;
		VAR nil: Object;
	BEGIN
		NEW(nil); nil.type := null; RETURN nil
	END NewNull;

	PROCEDURE IsNull* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = null
	END IsNull;


	(**--- Booleans ---**)

	(* clients should use predefined true and false objects *)
	PROCEDURE NewBool (val: BOOLEAN): Object;
		VAR b: Bool;
	BEGIN
		NEW(b); b.type := bool; b.b := val; RETURN b
	END NewBool;

	PROCEDURE IsBool* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = bool
	END IsBool;

	PROCEDURE BoolValue* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj(Bool).b
	END BoolValue;


	(**--- Characters ---**)

	PROCEDURE NewChar* (val: CHAR): Object;
		VAR ch: Char;
	BEGIN
		NEW(ch); ch.type := char; ch.ch := val; RETURN ch
	END NewChar;

	PROCEDURE IsChar* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = char
	END IsChar;

	PROCEDURE CharValue* (obj: Object): CHAR;
	BEGIN
		RETURN obj(Char).ch
	END CharValue;


	(**--- Strings ---**)

	PROCEDURE NewLiteral* (val: ARRAY OF CHAR; VAR pool: Pool): Object;
		VAR str: String;
	BEGIN
		NEW(str); str.type := string; MakeStretch(val, pool, str.stretch); RETURN str
	END NewLiteral;

	PROCEDURE NewString* (len: SIGNED32; fill: CHAR; VAR pool: Pool): Object;
		VAR str: String; n, pos: SIGNED32; buf: Buffer;
	BEGIN
		NEW(str); str.type := string; AllocStretch(len, pool, str.stretch);
		n := 0; buf := str.stretch.buf; pos := str.stretch.pos;
		WHILE n < len DO buf[pos + n] := fill; INC(n) END;
		RETURN str
	END NewString;

	PROCEDURE IsString* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = string
	END IsString;

	PROCEDURE StringLen* (obj: Object): SIGNED32;
	BEGIN
		RETURN obj(String).stretch.len
	END StringLen;

	PROCEDURE GetString* (obj: Object; pos, len: SIGNED32; VAR s: ARRAY OF CHAR);
	BEGIN
		GetStretch(obj(String).stretch, pos, len, s)
	END GetString;

	PROCEDURE SetString* (obj: Object; pos, len: SIGNED32; s: ARRAY OF CHAR);
	BEGIN
		SetStretch(obj(String).stretch, pos, len, s)
	END SetString;

	PROCEDURE CopyString* (src, dst: Object; spos, len, dpos: SIGNED32);
		VAR s, d: String; buf: ARRAY 256 OF CHAR;
	BEGIN
		s := src(String); d := dst(String);
		WHILE len > 0 DO
			GetStretch(s.stretch, spos, len, buf);
			SetStretch(d.stretch, dpos, len, buf);
			INC(spos, 255); INC(dpos, 255); DEC(len, 255)
		END
	END CopyString;


	(**--- Numbers ---**)

	PROCEDURE GCD (a, b: SIGNED32): SIGNED32;
		VAR t: SIGNED32;
	BEGIN
		IF b > a THEN t := b; b := a; a := t END;
		WHILE b > 1 DO t := b; b := a MOD b; a := t END;
		IF b = 0 THEN RETURN a
		ELSE RETURN 1
		END
	END GCD;

	PROCEDURE NewInteger* (val: SIGNED32): Object;
		VAR fix: Fixnum;
	BEGIN
		NEW(fix); fix.type := number; fix.sub := fixnum; fix.int := val; RETURN fix
	END NewInteger;

	PROCEDURE NewRational* (num, denom: SIGNED32): Object;
		VAR gcd: SIGNED32; rat: Rational;
	BEGIN
		IF denom < 0 THEN num := -num; denom := -denom END;
		gcd := GCD(ABS(num), denom);
		IF gcd = 0 THEN RETURN nan
		ELSIF denom = gcd THEN RETURN NewInteger(num DIV gcd)
		ELSIF denom # 0 THEN NEW(rat); rat.type := number; rat.sub := rational; rat.num := num DIV gcd; rat.denom := denom DIV gcd; RETURN rat
		ELSIF num > 0 THEN RETURN inf
		ELSE RETURN ninf
		END
	END NewRational;

	PROCEDURE NewReal* (val: FLOAT64): Object;
		VAR flo: Flonum;
	BEGIN
		NEW(flo); flo.type := number; flo.sub := flonum; flo.real := val; RETURN flo
	END NewReal;


	PROCEDURE ToExact* (obj: Object): Object;
		VAR r: FLOAT64; h, l, exp: SIGNED32;
	BEGIN
		IF obj.sub IN {fixnum, rational} THEN RETURN obj
		ELSE r := obj(Flonum).real
		END;
		Reals.NaNCodeL(r, h, l);
		IF (h # -1) OR (l # -1) THEN
			RETURN obj
		END;
		Reals.IntL(r, h, l);	(* assume IEEE double precision format *)
		exp := ASH(h, -20) MOD 800H;
		IF exp = 0 THEN h := ASH(h MOD 100000H, 11) + ASH(l, -21) MOD 800H	(* 0.f * 2^(-1022) *)
		ELSE h := 40000000H + ASH(h MOD 100000H, 10) + ASH(l, -22) MOD 400H	(* 1.f * 2^(exp-1023) *)
		END;
		exp := exp-1023;
		IF exp >= 31 THEN RETURN false	(* too large for SIGNED32 *)
		ELSIF exp <= -31 THEN RETURN zero	(* underflow *)
		END;
		WHILE exp <= 0 DO h := h DIV 2; INC(exp) END;
		IF r < 0 THEN h := -h END;
		RETURN NewRational(h, ASH(1, 30-exp))
	END ToExact;

	PROCEDURE ToInexact* (obj: Object): Object;
		VAR rat: Rational;
	BEGIN
		IF obj.sub = fixnum THEN RETURN NewReal(obj(Fixnum).int)
		ELSIF obj.sub = rational THEN
			rat := obj(Rational);
			IF rat.denom # 0 THEN RETURN NewReal(1.0D0 * rat.num/rat.denom)
			ELSIF rat.num > 0 THEN RETURN inf
			ELSE RETURN ninf
			END
		ELSE RETURN obj
		END
	END ToInexact;


	PROCEDURE GetInteger* (obj: Object; VAR val: SIGNED32; VAR exact: BOOLEAN);
		VAR rat: Rational; r: FLOAT64;
	BEGIN
		IF obj.sub = fixnum THEN
			val := obj(Fixnum).int; exact := TRUE
		ELSIF obj.sub = rational THEN
			rat := obj(Rational); val := rat.num DIV rat.denom; exact := FALSE;
			IF rat.num MOD rat.denom >= rat.denom DIV 2 THEN INC(val) END
		ELSE
			r := obj(Flonum).real+0.5; exact := FALSE;
			IF r < MIN(SIGNED32) THEN val := MIN(SIGNED32)
			ELSIF r > MAX(SIGNED32) THEN val := MAX(SIGNED32)
			ELSE val := ENTIER(r)
			END
		END
	END GetInteger;

	PROCEDURE GetRational* (obj: Object; VAR num, denom: SIGNED32; VAR exact: BOOLEAN);
		VAR rat: Rational;
	BEGIN
		exact := obj.sub IN {fixnum, rational};
		obj := ToExact(obj);
		IF obj.sub = fixnum THEN num := obj(Fixnum).int; denom := 1
		ELSIF obj.sub = rational THEN rat := obj(Rational); num := rat.num; denom := rat.denom
		ELSE
			denom := 0;
			IF obj = inf THEN num := 1
			ELSIF obj = ninf THEN num := -1
			ELSE num := 0
			END
		END
	END GetRational;

	PROCEDURE GetReal* (obj: Object; VAR val: FLOAT64);
		VAR rat: Rational;
	BEGIN
		IF obj.sub = fixnum THEN val := obj(Fixnum).int
		ELSIF obj.sub = rational THEN rat := obj(Rational); val := rat.num; val := val/rat.denom
		ELSE val := obj(Flonum).real
		END
	END GetReal;


	PROCEDURE IsNumber* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = number
	END IsNumber;

	PROCEDURE IsComplex* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = number
	END IsComplex;

	PROCEDURE IsReal* (obj: Object): BOOLEAN;
	BEGIN
		RETURN (fixnum <= obj.sub) & (obj.sub <= flonum)
	END IsReal;

	PROCEDURE IsRational* (obj: Object): BOOLEAN;
	BEGIN
		RETURN (fixnum <= obj.sub) & (obj.sub <= rational)
	END IsRational;

	PROCEDURE IsInteger* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.sub = fixnum
	END IsInteger;

	PROCEDURE IsExact* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.sub IN {fixnum, rational}
	END IsExact;

	PROCEDURE IsInexact* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.sub = flonum
	END IsInexact;


	PROCEDURE Compare* (obj1, obj2: Object): SIGNED32;
		VAR n1, d1, n2, d2, t1, t2: SIGNED32; r: Rational; p1, p2: FLOAT64;
	BEGIN
		IF obj1 = obj2 THEN RETURN 0
		ELSIF IsInexact(obj1) OR IsInexact(obj2) THEN
			obj1 := ToInexact(obj1); obj2 := ToInexact(obj2);
			IF obj1(Flonum).real < obj2(Flonum).real THEN RETURN -1
			ELSIF obj1(Flonum).real > obj2(Flonum).real THEN RETURN 1
			ELSE RETURN 0
			END
		ELSIF IsInteger(obj1) & IsInteger(obj2) THEN
			IF obj1(Fixnum).int < obj2(Fixnum).int THEN RETURN -1
			ELSIF obj1(Fixnum).int > obj2(Fixnum).int THEN RETURN 1
			ELSE RETURN 0
			END
		ELSE
			IF IsInteger(obj1) THEN n1 := obj1(Fixnum).int; d1 := 1
			ELSE r := obj1(Rational); n1 := r.num; d1 := r.denom
			END;
			IF IsInteger(obj2) THEN n2 := obj2(Fixnum).int; d2 := 1
			ELSE r := obj2(Rational); n2 := r.num; d2 := r.denom
			END;
			t1 := n1 DIV d1; t2 := n2 DIV d2;
			IF t1 < t2 THEN RETURN -1
			ELSIF t1 > t2 THEN RETURN 1
			END;
			p1 := n1; p1 := p1 * d2; p2 := n2; p2 := p2 * d1;
			IF p1 < p2 THEN RETURN -1
			ELSIF p1 > p2 THEN RETURN 1
			ELSE RETURN 0
			END
		END
	END Compare;

	PROCEDURE Add* (obj1, obj2: Object): Object;
		VAR n1, n2, d1, d2, gcd: SIGNED32; r: Rational; x1, x2: FLOAT64;
	BEGIN
		IF obj1 = zero THEN RETURN obj2
		ELSIF obj2 = zero THEN RETURN obj1
		ELSIF IsInexact(obj1) THEN obj2 := ToInexact(obj2); RETURN NewReal(obj1(Flonum).real + obj2(Flonum).real)
		ELSIF IsInexact(obj2) THEN obj1 := ToInexact(obj1); RETURN NewReal(obj1(Flonum).real + obj2(Flonum).real)
		ELSIF IsInteger(obj1) & IsInteger(obj2) THEN
			n1 := obj1(Fixnum).int; n2 := obj2(Fixnum).int;
			IF (n2 > 0) & (MAX(SIGNED32) - n2 < n1) THEN RETURN inf
			ELSIF (n2 < 0) & (MIN(SIGNED32) - n2 > n1) THEN RETURN ninf
			ELSE RETURN NewInteger(n1 + n2)
			END
		ELSIF IsInteger(obj1) THEN
			r := obj2(Rational); n2 := r.num; d2 := r.denom; n1 := obj1(Fixnum).int;
			IF (n2 >= 0) & ((MAX(SIGNED32) - n2) DIV d2 < n1) THEN x2 := n2; RETURN NewReal(x2/d2 + n1)
			ELSIF (n2 < 0) & ((MIN(SIGNED32) - n2) DIV d2 > n1) THEN x2 := n2; RETURN NewReal(x2/d2 + n1)
			ELSE RETURN NewRational(n1 * d2 + n2, d2)
			END
		ELSIF IsInteger(obj2) THEN
			r := obj1(Rational); n1 := r.num; d1 := r.denom; n2 := obj2(Fixnum).int;
			IF (n1 >= 0) & ((MAX(SIGNED32) - n1) DIV d1 < n2) THEN x1 := n1; RETURN NewReal(x1/d1 + n2)
			ELSIF (n1 < 0) & ((MIN(SIGNED32) - n1) DIV d1 > n2) THEN x1 := n1; RETURN NewReal(x1/d1 + n2)
			ELSE RETURN NewRational(n2 * d1 + n1, d1)
			END
		ELSE
			r := obj1(Rational); n1 := r.num; d1 := r.denom;
			r := obj2(Rational); n2 := r.num; d2 := r.denom;
			gcd := GCD(d1, d2); d1 := d1 DIV gcd; d2 := d2 DIV gcd;
			IF (MAX(SIGNED32) DIV d1 > gcd * d2) & (MAX(SIGNED32) DIV ABS(n1) > d2) & (MAX(SIGNED32) DIV ABS(n2) > d1) THEN
				n1 := n1 * d2; n2 := n2 * d1;
				IF (n1 >= 0) & (MAX(SIGNED32) - n1 > n2) OR (n1 < 0) & (MIN(SIGNED32) - n1 < n2) THEN
					RETURN NewRational(n1 + n2, gcd * d1 * d2)
				END
			END;
			x1 := n1; x2 := n2;
			RETURN NewReal((x1/d1 + x2/d2)/gcd)
		END
	END Add;

	PROCEDURE Neg* (obj: Object): Object;
		VAR r: Rational;
	BEGIN
		IF obj = zero THEN RETURN zero
		ELSIF IsInexact(obj) THEN RETURN NewReal(-obj(Flonum).real)
		ELSIF IsInteger(obj) THEN RETURN NewInteger(-obj(Fixnum).int)	(* int = MAX(SIGNED32)? *)
		ELSE r := obj(Rational); RETURN NewRational(-r.num, r.denom)	(* num = MAX(SIGNED32)? *)
		END
	END Neg;

	PROCEDURE Sub* (obj1, obj2: Object): Object;
		VAR n1, n2, d1, d2, gcd: SIGNED32; r: Rational; x1, x2: FLOAT64;
	BEGIN
		IF obj1 = zero THEN RETURN Neg(obj2)
		ELSIF obj2 = zero THEN RETURN obj1
		ELSIF IsInexact(obj1) THEN obj2 := ToInexact(obj2); RETURN NewReal(obj1(Flonum).real - obj2(Flonum).real)
		ELSIF IsInexact(obj2) THEN obj1 := ToInexact(obj1); RETURN NewReal(obj1(Flonum).real - obj2(Flonum).real)
		ELSIF IsInteger(obj1) & IsInteger(obj2) THEN
			n1 := obj1(Fixnum).int; n2 := obj2(Fixnum).int;
			IF (n2 < 0) & (MAX(SIGNED32) + n2 < n1) THEN RETURN inf
			ELSIF (n2 > 0) & (MIN(SIGNED32) + n2 > n1) THEN RETURN ninf
			ELSE RETURN NewInteger(n1 - n2)
			END
		ELSIF IsInteger(obj1) THEN
			r := obj2(Rational); n2 := r.num; d2 := r.denom; n1 := obj1(Fixnum).int;
			IF (n2 <= 0) & ((MAX(SIGNED32) + n2) DIV d2 < n1) THEN x2 := n2; RETURN NewReal(x2/d2 + n1)
			ELSIF (n2 > 0) & ((MIN(SIGNED32) + n2) DIV d2 > n1) THEN x2 := n2; RETURN NewReal(x2/d2 + n1)
			ELSE RETURN NewRational(n1 * d2 - n2, d2)
			END
		ELSIF IsInteger(obj2) THEN
			r := obj1(Rational); n1 := r.num; d1 := r.denom; n2 := obj2(Fixnum).int;
			IF (n1 <= 0) & ((MAX(SIGNED32) + n1) DIV d1 < n2) THEN x1 := n1; RETURN NewReal(x1/d1 + n2)
			ELSIF (n1 > 0) & ((MIN(SIGNED32) + n1) DIV d1 > n2) THEN x1 := n1; RETURN NewReal(x1/d1 + n2)
			ELSE RETURN NewRational(n2 * d1 - n1, d1)
			END
		ELSE
			r := obj1(Rational); n1 := r.num; d1 := r.denom;
			r := obj2(Rational); n2 := r.num; d2 := r.denom;
			gcd := GCD(d1, d2); d1 := d1 DIV gcd; d2 := d2 DIV gcd;
			IF (MAX(SIGNED32) DIV d1 > gcd * d2) & (MAX(SIGNED32) DIV ABS(n1) > d2) & (MAX(SIGNED32) DIV ABS(n2) > d1) THEN
				n1 := n1 * d2; n2 := n2 * d1;
				IF (n1 <= 0) & (MAX(SIGNED32) + n1 > n2) OR (n1 > 0) & (MIN(SIGNED32) + n1 < n2) THEN
					RETURN NewRational(n1 - n2, gcd * d1 * d2)
				END
			END;
			x1 := n1; x2 := n2;
			RETURN NewReal((x1/d1 - x2/d2)/gcd)
		END
	END Sub;

	PROCEDURE Mul * (obj1, obj2: Object): Object;
		VAR n1, n2, d1, d2, gcd: SIGNED32; r: Rational; x1, x2: FLOAT64;
	BEGIN
		IF (obj1 = zero) OR (obj2 = zero) THEN RETURN zero
		ELSIF obj1 = one THEN RETURN obj2
		ELSIF obj2 = one THEN RETURN obj1
		ELSIF IsInexact(obj1) THEN obj2 := ToInexact(obj2); RETURN NewReal(obj1(Flonum).real * obj2(Flonum).real)
		ELSIF IsInexact(obj2) THEN obj1 := ToInexact(obj1); RETURN NewReal(obj1(Flonum).real * obj2(Flonum).real)
		ELSIF IsInteger(obj1) & IsInteger(obj2) THEN
			n1 := obj1(Fixnum).int; n2 := obj2(Fixnum).int;
			IF (n1 = 0) OR (n2 = 0) THEN RETURN zero
			ELSIF MAX(SIGNED32) DIV ABS(n1) < ABS(n2) THEN x1 := n1; RETURN NewReal(x1 * n2)
			ELSE RETURN NewInteger(n1 * n2)
			END
		ELSIF IsInteger(obj1) THEN
			r := obj2(Rational); n2 := r.num; d2 := r.denom; n1 := obj1(Fixnum).int;
			gcd := GCD(d2, ABS(n1));
			IF gcd # 1 THEN n1 := n1 DIV gcd; d2 := d2 DIV gcd END;
			IF n1 = 0 THEN RETURN zero
			ELSIF MAX(SIGNED32) DIV ABS(n1) < ABS(n2) THEN x2 := n2; RETURN NewReal(x2/d2 * n1)
			ELSE RETURN NewRational(n1 * n2, d2)
			END
		ELSIF IsInteger(obj2) THEN
			r := obj1(Rational); n1 := r.num; d1 := r.denom; n2 := obj2(Fixnum).int;
			gcd := GCD(d1, ABS(n2));
			IF gcd # 1 THEN n2 := n2 DIV gcd; d1 := d1 DIV gcd END;
			IF n2 = 0 THEN RETURN zero
			ELSIF MAX(SIGNED32) DIV ABS(n2) < ABS(n1) THEN x1 := n1; RETURN NewReal(x1/d1 * n2)
			ELSE RETURN NewRational(n2 * n1, d1)
			END
		ELSE
			r := obj1(Rational); n1 := r.num; d1 := r.denom;
			r := obj2(Rational); n2 := r.num; d2 := r.denom;
			gcd := GCD(d1, ABS(n2));
			IF gcd # 1 THEN n2 := n2 DIV gcd; d1 := d1 DIV gcd END;
			gcd := GCD(d2, ABS(n1));
			IF gcd # 1 THEN n1 := n1 DIV gcd; d2 := d2 DIV gcd END;
			IF (MAX(SIGNED32) DIV d1 < d2) OR (MAX(SIGNED32) DIV ABS(n1) < ABS(n2)) THEN
				x1 := n1; x2 := n2; RETURN NewReal(x1/n1 * x2/n2)
			ELSE
				RETURN NewRational(n1 * n2, d1 * d2)
			END
		END
	END Mul;

	PROCEDURE Inv* (obj: Object): Object;
		VAR r: Rational;
	BEGIN
		IF obj = one THEN RETURN one
		ELSIF IsInexact(obj) THEN RETURN NewReal(1.0D0/obj(Flonum).real)
		ELSIF IsInteger(obj) THEN RETURN NewRational(1, obj(Fixnum).int)
		ELSE r := obj(Rational); RETURN NewRational(r.denom, r.num)
		END
	END Inv;

	PROCEDURE Div * (obj1, obj2: Object): Object;
		VAR n1, n2, d1, d2, gcd: SIGNED32; r: Rational; x1, x2: FLOAT64;
	BEGIN
		IF obj1 = one THEN RETURN Inv(obj2)
		ELSIF obj2 = one THEN RETURN obj1
		ELSIF IsInexact(obj1) THEN obj2 := ToInexact(obj2); RETURN NewReal(obj1(Flonum).real/obj2(Flonum).real)
		ELSIF IsInexact(obj2) THEN obj1 := ToInexact(obj1); RETURN NewReal(obj1(Flonum).real/obj2(Flonum).real)
		ELSIF IsInteger(obj1) & IsInteger(obj2) THEN RETURN NewRational(obj1(Fixnum).int, obj2(Fixnum).int)
		ELSIF IsInteger(obj1) THEN
			n1 := obj1(Fixnum).int; r := obj2(Rational); n2 := r.num; d2 := r.denom;
			IF MAX(SIGNED32) DIV ABS(n1) < d2 THEN x1 := n1; RETURN NewReal(x1 * d2/n2)
			ELSE RETURN NewRational(n1 * d2, n2)
			END
		ELSIF IsInteger(obj2) THEN
			n2 := obj2(Fixnum).int; r := obj1(Rational); n1 := r.num; d1 := r.denom;
			gcd := GCD(n1, n2);
			IF gcd # 1 THEN n1 := n1 DIV gcd; n2 := n2 DIV gcd END;
			IF MAX(SIGNED32) DIV ABS(n2) < d1 THEN x1 := n1; RETURN NewReal((x1/d1)/n2)
			ELSE RETURN NewRational(n1, d1 * n2)
			END
		ELSE
			r := obj1(Rational); n1 := r.num; d1 := r.denom;
			r := obj2(Rational); n2 := r.num; d2 := r.denom;
			IF (MAX(SIGNED32) DIV d1 < ABS(n2)) OR (MAX(SIGNED32) DIV d2 < ABS(n1)) THEN
				x1 := n1; x2 := n2; RETURN NewReal((x1 * d2)/(x2 * d1))
			ELSE
				RETURN NewRational(n1 * d2, d1 * n2)
			END
		END
	END Div;

	PROCEDURE Quotient* (obj1, obj2: Object; VAR q, r, m: Object);
		VAR n1, n2, iq, ir, im: SIGNED32; ex1, ex2: BOOLEAN;
	BEGIN
		GetInteger(obj1, n1, ex1); GetInteger(obj2, n2, ex2);
		IF n2 > 0 THEN
			IF n1 >= 0 THEN iq := n1 DIV n2; ir := n1 MOD n2; im := ir
			ELSE iq := -((-n1) DIV n2); ir := -((-n1) MOD n2); im := n1 MOD n2
			END
		ELSIF n2 < 0 THEN
			IF n1 >= 0 THEN iq := -(n1 DIV (-n2)); ir := n1 MOD (-n2); im := -((-n1) MOD (-n2))
			ELSE iq := (-n1) DIV (-n2); ir := -((-n1) MOD (-n2)); im := ir
			END
		ELSE iq := 0; ir := 0; im := 0
		END;
		IF ex1 & ex2 THEN q := NewInteger(iq); r := NewInteger(ir); m := NewInteger(im)
		ELSE q := NewReal(iq); r := NewReal(ir); m := NewReal(im)
		END
	END Quotient;

	PROCEDURE Sqrt* (obj: Object): Object;
		VAR x: FLOAT64; res, exres: Object;
	BEGIN
		GetReal(obj, x);
		IF x < 0.0D0 THEN RETURN nan END;
		res := NewReal(MathL.sqrt(x));
		IF IsExact(obj) THEN
			exres := ToExact(res);
			IF Compare(Mul(exres, exres), obj) = 0 THEN
				RETURN exres
			END
		END;
		RETURN res
	END Sqrt;

	PROCEDURE Exp* (obj: Object): Object;
		VAR x: FLOAT64;
	BEGIN
		GetReal(obj, x);
		IF (x = 0.0D0) & (obj.sub = fixnum) THEN RETURN one
		ELSE RETURN NewReal(MathL.exp(x))
		END
	END Exp;

	PROCEDURE Ln* (obj: Object): Object;
		VAR x: FLOAT64;
	BEGIN
		GetReal(obj, x);
		IF x < 0.0D0 THEN RETURN nan
		ELSIF x = 0.0D0 THEN RETURN ninf
		ELSE RETURN NewReal(MathL.ln(x))
		END
	END Ln;

	PROCEDURE Expt* (base, power: Object): Object;
		VAR x, y, res: FLOAT64;
	BEGIN
		GetReal(base, x);
		IF x < 0.0D0 THEN RETURN nan
		ELSE
			GetReal(power, y);
			res := MathL.exp(y * MathL.ln(x));
			IF (base.sub = fixnum) & (power.sub = fixnum) & (res <= MAX(SIGNED32)) THEN
				RETURN NewInteger(ENTIER(res + 0.5))
			ELSE
				RETURN NewReal(res)
			END
		END
	END Expt;

	PROCEDURE Sin* (obj: Object): Object;
		VAR x: FLOAT64;
	BEGIN
		GetReal(obj, x); RETURN NewReal(MathL.sin(x))
	END Sin;

	PROCEDURE ASin* (obj: Object): Object;
		VAR x: FLOAT64;
	BEGIN
		GetReal(obj, x);
		IF ABS(x) > 1.0D0 THEN RETURN nan
		ELSIF x = 0.0D0 THEN RETURN NewReal(0.0D0)
		ELSIF x = 1.0D0 THEN RETURN NewReal(0.5D0*MathL.pi)
		ELSIF x = -1.0D0 THEN RETURN NewReal(1.5D0*MathL.pi)
		ELSE RETURN NewReal(MathL.arctan(x/MathL.sqrt(1.0D0-x*x)))
		END
	END ASin;

	PROCEDURE Cos* (obj: Object): Object;
		VAR x: FLOAT64;
	BEGIN
		GetReal(obj, x); RETURN NewReal(MathL.cos(x))
	END Cos;

	PROCEDURE ACos* (obj: Object): Object;
		VAR x: FLOAT64;
	BEGIN
		GetReal(obj, x);
		IF ABS(x) > 1.0D0 THEN RETURN nan
		ELSIF x = 0.0D0 THEN RETURN NewReal(0.5D0*MathL.pi)
		ELSIF x = 1.0D0 THEN RETURN NewReal(0.0D0)
		ELSIF x = -1.0D0 THEN RETURN NewReal(MathL.pi)
		ELSE RETURN NewReal(2.0D0 * MathL.arctan(MathL.sqrt((1.0D0-x)/(1.0D0+x))))
		END
	END ACos;

	PROCEDURE Tan* (obj: Object): Object;
		VAR x, y: FLOAT64;
	BEGIN
		GetReal(obj, x);
		y := MathL.cos(x);
		IF y = 0.0D0 THEN
			y := MathL.sin(x);
			IF y > 0.0D0 THEN RETURN inf
			ELSE RETURN ninf
			END
		END;
		RETURN NewReal(MathL.sin(x)/y)
	END Tan;

	PROCEDURE ATan* (obj: Object): Object;
		VAR x: FLOAT64;
	BEGIN
		GetReal(obj, x); RETURN NewReal(MathL.arctan(x))
	END ATan;

	PROCEDURE ATan2* (obj1, obj2: Object): Object;
		VAR x, y, phi: FLOAT64;
	BEGIN
		GetReal(obj1, x); GetReal(obj2, y);
		IF (ABS(x) < 1.0D0) & (ABS(y) >= ABS(x * MAX(FLOAT64))) THEN	(* y/x would overflow *)
			IF y >= 0.0D0 THEN phi := MathL.pi/2.0D0
			ELSE phi := -MathL.pi/2.0D0
			END
		ELSIF x > 0.0D0 THEN	(* 1st or 4th quadrant *)
			phi := MathL.arctan(y/x)
		ELSIF x < 0.0D0 THEN	(* 2nd or 3rd quadrant *)
			phi := MathL.arctan(y/x) + MathL.pi
		END;
		RETURN NewReal(phi)
	END ATan2;

	PROCEDURE Floor* (obj: Object): Object;
		VAR rat: Rational;
	BEGIN
		IF obj.sub = fixnum THEN RETURN obj
		ELSIF obj.sub = rational THEN
			rat := obj(Rational);
			IF rat.denom = 0 THEN RETURN obj
			ELSE RETURN NewInteger(rat.num DIV rat.denom)
			END
		ELSE RETURN NewReal(ENTIER(obj(Flonum).real))
		END
	END Floor;

	PROCEDURE Rationalize* (x, eps: Object): Object;
		VAR min, max: Object;

		PROCEDURE simplest (bot, top: Object): Object;
			VAR fb, ft, n, d: Object;
		BEGIN
			fb := Floor(bot);
			IF Compare(bot, fb) <= 0 THEN RETURN fb END;	(* bot is integer *)
			ft := Floor(top);
			IF Compare(fb, ft) = 0 THEN
				n := Inv(Sub(top, ft)); d := Inv(Sub(bot, fb));
				RETURN Add(fb, Inv(simplest(n, d)))
			ELSE
				RETURN Add(fb, one)
			END
		END simplest;

	BEGIN
		(*
			tends to return inexact results even for exact arguments since the computation of interval boundaries
			may overflow the valid range of numerator and denominator of rational numbers
		*)
		(* use Alan Bawden's algorithm (like everybody else) *)
		IF Compare(eps, zero) < 0 THEN min := Add(x, eps); max := Sub(x, eps)
		ELSE min := Sub(x, eps); max := Add(x, eps)
		END;
		IF Compare(min, max) = 0 THEN RETURN min
		ELSIF Compare(min, zero) > 0 THEN RETURN simplest(min, max)
		ELSIF Compare(max, zero) < 0 THEN RETURN Neg(simplest(Neg(max), Neg(min)))
		ELSE RETURN zero
		END
	END Rationalize;


	(**--- References ---**)

	PROCEDURE NewRef* (refobj: Objects.Object): Object;
		VAR ref: Reference;
	BEGIN
		NEW(ref); ref.type := reference; ref.obj := refobj; RETURN ref
	END NewRef;

	PROCEDURE IsReference* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = reference
	END IsReference;

	PROCEDURE RefValue* (obj: Object): Objects.Object;
	BEGIN
		RETURN obj(Reference).obj
	END RefValue;


	(**--- Symbols ---**)

	PROCEDURE HashCode (VAR s: ARRAY OF CHAR): SIGNED32;
		CONST a0 = 31415; b = 27183; m = ASH(1, 16) - 15;
		VAR n, a, h: SIGNED32;
	BEGIN
		(* taken from Sedgewick; a * m < MAX(SIGNED32); no overflow checks (a*b!) *)
		n := 0; a := a0; h := 0;
		WHILE s[n] # 0X DO
			h := (a * h + LONG(ORD(s[n]))) MOD m;
			INC(n); a := a * b
		END;
		RETURN h
	END HashCode;

	PROCEDURE NewSymbol* (name: ARRAY OF CHAR): Object;
		VAR hash, idx: SIGNED32; sym: Symbol;
	BEGIN
		hash := HashCode(name); idx := hash MOD dirSize; sym := symTab[idx];
		WHILE sym # NIL DO
			IF StretchEquals(sym.stretch, name) THEN RETURN sym END;
			sym := sym.link
		END;
		NEW(sym); sym.type := symbol; MakeStretch(name, symPool, sym.stretch); sym.hash := hash;
		sym.link := symTab[idx]; symTab[idx] := sym;
		RETURN sym
	END NewSymbol;

	PROCEDURE IsSymbol* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = symbol
	END IsSymbol;

	PROCEDURE GetSymbol* (obj: Object; VAR s: ARRAY OF CHAR);
		VAR sym: Symbol;
	BEGIN
		sym := obj(Symbol); GetStretch(sym.stretch, 0, sym.stretch.len, s)
	END GetSymbol;


	(**--- Pairs ---**)

	PROCEDURE NewPair* (car, cdr: Object): Object;
		VAR p: Object;
	BEGIN
		NEW(p); p.type := pair; p.dsc := car; p.next := cdr; RETURN p
	END NewPair;

	PROCEDURE IsPair* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = pair
	END IsPair;

	PROCEDURE GetPair* (obj: Object; VAR car, cdr: Object);
	BEGIN
		ASSERT(obj.type = pair, 100);
		car := obj.dsc; cdr := obj.next
	END GetPair;

	PROCEDURE Car* (obj: Object): Object;
	BEGIN
		ASSERT(obj.type = pair, 100);
		RETURN obj.dsc
	END Car;

	PROCEDURE SetCar* (p, obj: Object);
	BEGIN
		ASSERT(p.type = pair, 100);
		p.dsc := obj
	END SetCar;

	PROCEDURE Cdr* (obj: Object): Object;
	BEGIN
		ASSERT(obj.type = pair, 100);
		RETURN obj.next
	END Cdr;

	PROCEDURE SetCdr* (p, obj: Object);
	BEGIN
		ASSERT(p.type = pair, 100);
		p.next := obj
	END SetCdr;


	(**--- Vectors ---**)

	PROCEDURE NewVector* (size: SIGNED32; fill: Object): Object;
		VAR vec: Vector; n: SIGNED32;
	BEGIN
		NEW(vec); vec.type := vector; vec.size := size;
		IF size # 0 THEN NEW(vec.elem, size) END;
		n := 0; WHILE n < size DO vec.elem[n] := fill; INC(n) END;
		RETURN vec
	END NewVector;

	PROCEDURE IsVector* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = vector
	END IsVector;

	PROCEDURE VectorLen* (obj: Object): SIGNED32;
	BEGIN
		RETURN obj(Vector).size
	END VectorLen;

	PROCEDURE VectorAt* (obj: Object; idx: SIGNED32): Object;
	BEGIN
		RETURN obj(Vector).elem[idx]
	END VectorAt;

	PROCEDURE SetVectorAt* (obj: Object; idx: SIGNED32; val: Object);
	BEGIN
		obj(Vector).elem[idx] := val
	END SetVectorAt;


	(**--- Procedures ---**)

	PROCEDURE NewPrimitive* (sym: Object; eval: PrimEval): Object;
		VAR prim: Primitive;
	BEGIN
		NEW(prim); prim.type := procedure; prim.sub := primitive;
		prim.sym := sym(Symbol); prim.eval := eval; RETURN prim
	END NewPrimitive;

	PROCEDURE NewProcedure* (env: Environment; par, body: Object): Object;
		VAR proc: Procedure;
	BEGIN
		NEW(proc); proc.type := procedure; proc.sub := compound;
		proc.env := env; proc.par := par; proc.body := body; RETURN proc
	END NewProcedure;

	PROCEDURE IsProcedure* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = procedure
	END IsProcedure;


	(**--- Ports ---**)

	(* clients should use EOF *)
	PROCEDURE NewEof (): Object;
		VAR obj: Object;
	BEGIN
		NEW(obj); obj.type := eofobj; RETURN obj
	END NewEof;

	PROCEDURE IsEof* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = eofobj
	END IsEof;

	PROCEDURE IsPort* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.type = port
	END IsPort;

	PROCEDURE IsInput* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.sub = input
	END IsInput;

	PROCEDURE IsOpenInput* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj(Input).open
	END IsOpenInput;

	PROCEDURE Eof* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj(Input).eof
	END Eof;

	PROCEDURE Ready* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj(Input).ready
	END Ready;

	PROCEDURE ReadCh* (obj: Object; VAR ch: CHAR);
		VAR ip: Input;
	BEGIN
		ip := obj(Input); ip.read(ip, ch)
	END ReadCh;

	PROCEDURE PeekCh* (obj: Object; VAR ch: CHAR): BOOLEAN;
		VAR ip: Input;
	BEGIN
		ip := obj(Input); ip.read(ip, ch);
		IF ip.eof THEN ip.eof := FALSE; RETURN FALSE
		ELSE ip.unread(ip)
		END
	END PeekCh;

	PROCEDURE Unread* (obj: Object);
		VAR ip: Input;
	BEGIN
		ip := obj(Input); ip.unread(ip)
	END Unread;

	PROCEDURE Pos* (obj: Object): SIGNED32;
		VAR ip: Input;
	BEGIN
		ip := obj(Input); RETURN ip.getpos(ip)
	END Pos;

	PROCEDURE CloseInput* (obj: Object);
	BEGIN
		obj(Input).open := FALSE
	END CloseInput;

	PROCEDURE ReadFile (ip: Input; VAR ch: CHAR);
		VAR fip: FileInput;
	BEGIN
		fip := ip(FileInput); Files.Read(fip.r, ch); fip.eof := fip.r.eof
	END ReadFile;

	PROCEDURE UnreadFile (ip: Input);
		VAR fip: FileInput;
	BEGIN
		fip := ip(FileInput); Files.Set(fip.r, Files.Base(fip.r), Files.Pos(fip.r)-1)
	END UnreadFile;

	PROCEDURE FilePos (ip: Input): SIGNED32;
	BEGIN
		RETURN Files.Pos(ip(FileInput).r)
	END FilePos;

	PROCEDURE NewFileInput* (file: Files.File): Object;
		VAR fip: FileInput;
	BEGIN
		NEW(fip); fip.type := port; fip.sub := input;
		fip.open := TRUE; fip.ready := TRUE; fip.eof := FALSE;
		fip.read := ReadFile; fip.unread := UnreadFile; fip.getpos := FilePos;
		Files.Set(fip.r, file, 0);
		RETURN fip
	END NewFileInput;

	PROCEDURE ReadText (ip: Input; VAR ch: CHAR);
		VAR tip: TextInput;
	BEGIN
		tip := ip(TextInput); Texts.Read(tip.r, ch); tip.eof := tip.r.eot
	END ReadText;

	PROCEDURE UnreadText (ip: Input);
		VAR tip: TextInput;
	BEGIN
		tip := ip(TextInput); Texts.OpenReader(tip.r, tip.text, Texts.Pos(tip.r)-1)
	END UnreadText;

	PROCEDURE TextPos (ip: Input): SIGNED32;
	BEGIN
		RETURN Texts.Pos(ip(TextInput).r)
	END TextPos;

	PROCEDURE NewTextInput* (text: Texts.Text; pos: SIGNED32): Object;
		VAR tip: TextInput;
	BEGIN
		NEW(tip); tip.type := port; tip.sub := input; tip.open := TRUE; tip.ready := TRUE; tip.eof := FALSE;
		tip.read := ReadText; tip.unread := UnreadText; tip.getpos := TextPos; tip.text := text;
		Texts.OpenReader(tip.r, text, pos);
		RETURN tip
	END NewTextInput;

	PROCEDURE ReadString (ip: Input; VAR ch: CHAR);
		VAR sip: StringInput;
	BEGIN
		sip := ip(StringInput); ch := sip.ps[sip.pos];
		IF ch = 0X THEN sip.eof := TRUE
		ELSE INC(sip.pos)
		END
	END ReadString;

	PROCEDURE UnreadString (ip: Input);
	BEGIN
		DEC(ip(StringInput).pos)
	END UnreadString;

	PROCEDURE StringPos (ip: Input): SIGNED32;
	BEGIN
		RETURN ip(StringInput).pos
	END StringPos;

	PROCEDURE NewStringInput* (s: ARRAY OF CHAR): Object;
		VAR sip: StringInput;
	BEGIN
		NEW(sip); sip.type := port; sip.sub := input;
		sip.open := TRUE; sip.ready := TRUE; sip.eof := FALSE;
		sip.read := ReadString; sip.unread := UnreadString; sip.getpos := StringPos;
		sip.pos := 0; NEW(sip.ps, LEN(s)); COPY(s, sip.ps^);
		RETURN sip
	END NewStringInput;


	PROCEDURE IsOutput* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj.sub = output
	END IsOutput;

	PROCEDURE IsOpenOutput* (obj: Object): BOOLEAN;
	BEGIN
		RETURN obj(Output).open
	END IsOpenOutput;

	PROCEDURE Write* (obj: Object; ch: CHAR);
		VAR op: Output;
	BEGIN
		op := obj(Output); op.write(op, ch)
	END Write;

	PROCEDURE WriteStr* (obj: Object; s: ARRAY OF CHAR);
		VAR op: Output; i: SIGNED32;
	BEGIN
		op := obj(Output);
		i := 0; WHILE s[i] # 0X DO op.write(op, s[i]); INC(i) END;
	END WriteStr;

	PROCEDURE Flush* (obj: Object);
		VAR op: Output;
	BEGIN
		op := obj(Output); op.flush(op)
	END Flush;

	PROCEDURE CloseOutput* (obj: Object);
		VAR op: Output;
	BEGIN
		op := obj(Output); op.close(op); op.open := FALSE
	END CloseOutput;

	PROCEDURE WriteFile (op: Output; ch: CHAR);
	BEGIN
		Files.Write(op(FileOutput).r, ch)
	END WriteFile;

	PROCEDURE FlushFile (op: Output);
	BEGIN
		Files.Close(Files.Base(op(FileOutput).r))
	END FlushFile;

	PROCEDURE CloseFile (op: Output);
	BEGIN
		Files.Register(Files.Base(op(FileOutput).r))
	END CloseFile;

	PROCEDURE NewFileOutput* (file: Files.File): Object;
		VAR fop: FileOutput;
	BEGIN
		NEW(fop); fop.type := port; fop.sub := output;
		fop.open := TRUE; fop.write := WriteFile; fop.flush := FlushFile; fop.close := CloseFile;
		Files.Set(fop.r, file, 0);
		RETURN fop
	END NewFileOutput;

	PROCEDURE WriteText (op: Output; ch: CHAR);
	BEGIN
		IF OutText # op THEN
			IF OutText # NIL THEN OutText.flush(OutText) END;
			OutText := op(TextOutput)
		END;
		Texts.Write(OutW, ch)
	END WriteText;

	PROCEDURE FlushText (op: Output);
	BEGIN
		Texts.Append(op(TextOutput).text, OutW.buf)
	END FlushText;

	PROCEDURE NewTextOutput* (text: Texts.Text): Object;
		VAR top: TextOutput;
	BEGIN
		NEW(top); top.type := port; top.sub := output;
		top.open := TRUE; top.write := WriteText; top.flush := FlushText; top.close := FlushText;
		top.text := text;
		RETURN top
	END NewTextOutput;


	PROCEDURE WriteObj* (out, obj: Object);
		VAR op: Output; c: CHAR; n, len, l, m: SIGNED32; s: ARRAY 100 OF CHAR;

		PROCEDURE ch (c: CHAR);
		BEGIN
			op.write(op, c)
		END ch;

		PROCEDURE str (s: ARRAY OF CHAR);
			VAR n: SIGNED32;
		BEGIN
			n := 0; WHILE s[n] # 0X DO op.write(op, s[n]); INC(n) END
		END str;

	BEGIN
		op := out(Output);
		IF obj = NIL THEN str("#@"); RETURN END;
		CASE obj.type OF
		| null: str("()")
		| bool: IF BoolValue(obj) THEN str("#t") ELSE str("#f") END
		| char:
			c := CharValue(obj);
			IF c = " " THEN str("#\space")
			ELSIF c = newline THEN str("#\newline")
			ELSE str("#\"); ch(c)
			END
		| string:
			ch('"'); n := 0; len := StringLen(obj);
			WHILE len > 0 DO
				GetStretch(obj(String).stretch, n, len, s);
				IF len < LEN(s) THEN l := len ELSE l := LEN(s)-1 END;
				m := 0;
				WHILE m < l DO
					IF s[m] < " " THEN
						str("\#")
					ELSE
						IF (s[m] = '"') OR (s[m] = '\') THEN ch('\') END;
						ch(s[m])
					END;
					INC(m)
				END;
				INC(n, m); DEC(len, m)
			END;
			ch('"')
		| number:
			IF obj.sub = fixnum THEN
				Strings.IntToStr(obj(Fixnum).int, s); str(s)
			ELSIF obj.sub = rational THEN
				Strings.IntToStr(obj(Rational).num, s); str(s); ch('/');
				Strings.IntToStr(obj(Rational).denom, s); str(s)
			ELSE
				Strings.RealToFixStr(obj(Flonum).real, s, 20, 10, 0); str(s)
			END
		| reference:
			str("##reference")
		| symbol:
			n := 0; len := obj(Symbol).stretch.len;
			WHILE len > 0 DO
				GetStretch(obj(Symbol).stretch, n, len, s); str(s); INC(n, LEN(s)-1); DEC(len, LEN(s)-1)
			END
		| pair:
			ch('(');
			LOOP
				WriteObj(out, obj.dsc); obj := obj.next;
				IF obj.type # pair THEN EXIT
				ELSE ch(' ')
				END
			END;
			IF obj.type # null THEN
				str(" . "); WriteObj(out, obj)
			END;
			ch(')')
		| vector:
			str("#("); len := VectorLen(obj);
			IF len > 0 THEN
				WriteObj(out, VectorAt(obj, n)); n := 1;
				WHILE n < len DO
					ch(' '); WriteObj(out, VectorAt(obj, n)); INC(n)
				END
			END;
			ch(')')
		| procedure:
			IF obj.sub = primitive THEN
				str("##"); WriteObj(out, obj(Primitive).sym)
			ELSE
				str("##procedure")
			END
		| port:
			str("##port")
		| eofobj:
			str("##eof")
		ELSE str("##?")
		END
	END WriteObj;


	(**--- Equivalence ---**)

	PROCEDURE Eqv* (obj1, obj2: Object): BOOLEAN;
	BEGIN
		IF obj1 = obj2 THEN RETURN TRUE
		ELSIF obj1.type # obj2.type THEN RETURN FALSE
		END;
		CASE obj1.type OF
		| bool: RETURN obj1(Bool).b = obj2(Bool).b
		| number: RETURN (IsExact(obj1) = IsExact(obj2)) & (Compare(obj1, obj2) = 0)
		| char: RETURN obj1(Char).ch = obj2(Char).ch
		| null: RETURN TRUE
		ELSE RETURN FALSE
		END
	END Eqv;

	PROCEDURE Eq* (obj1, obj2: Object): BOOLEAN;
	BEGIN
		RETURN obj1 = obj2
	END Eq;


	(*--- Stacks ---*)

	PROCEDURE InitStack (VAR stack: Stack);
	BEGIN
		stack.obj.size := 0; stack.obj.top := 0; stack.obj.elem := NIL;
		stack.eval.size := 0; stack.eval.top := 0; stack.eval.elem := NIL;
		stack.env.size := 0; stack.env.top := 0; stack.env.elem := NIL
	END InitStack;

	PROCEDURE PushObj (VAR stack: Stack; obj: Object);
		VAR elem: ObjectElems; n: SIGNED32;
	BEGIN
		IF stack.obj.top = stack.obj.size THEN
			INC(stack.obj.size, stackBlock);
			NEW(elem, stack.obj.size); n := 0;
			WHILE n < stack.obj.top DO
				elem[n] := stack.obj.elem[n]; INC(n)
			END;
			stack.obj.elem := elem
		END;
		stack.obj.elem[stack.obj.top] := obj; INC(stack.obj.top)
	END PushObj;

	PROCEDURE PushEnv (VAR stack: Stack; env: Environment);
		VAR elem: EnvElems; n: SIGNED32;
	BEGIN
		IF stack.env.top = stack.env.size THEN
			INC(stack.env.size, stackBlock);
			NEW(elem, stack.env.size); n := 0;
			WHILE n < stack.env.top DO
				elem[n] := stack.env.elem[n]; INC(n)
			END;
			stack.env.elem := elem
		END;
		stack.env.elem[stack.env.top] := env; INC(stack.env.top)
	END PushEnv;

	PROCEDURE PushEval (VAR stack: Stack; eval: Evaluator);
		VAR elem: EvalElems; n: SIGNED32;
	BEGIN
		IF stack.eval.top = stack.eval.size THEN
			INC(stack.eval.size, stackBlock);
			NEW(elem, stack.eval.size); n := 0;
			WHILE n < stack.eval.top DO
				elem[n] := stack.eval.elem[n]; INC(n)
			END;
			stack.eval.elem := elem
		END;
		stack.eval.elem[stack.eval.top] := eval; INC(stack.eval.top)
	END PushEval;

	PROCEDURE PopObj (VAR stack: Stack; VAR obj: Object);
	BEGIN
		DEC(stack.obj.top); obj := stack.obj.elem[stack.obj.top]
	END PopObj;

	PROCEDURE PopEnv (VAR stack: Stack; VAR env: Environment);
	BEGIN
		DEC(stack.env.top); env := stack.env.elem[stack.env.top]
	END PopEnv;

	PROCEDURE PopEval (VAR stack: Stack; VAR eval: Evaluator);
	BEGIN
		DEC(stack.eval.top); eval := stack.eval.elem[stack.eval.top]
	END PopEval;


	(**--- Contexts & Errors ---**)

	PROCEDURE InitContext* (ctxt: Context; in, out, err: Object);
	BEGIN
		InitPool(ctxt.pool); InitStack(ctxt.stack);
		ctxt.in := in; ctxt.out := out; ctxt.err := err;
		ctxt.failed := FALSE
	END InitContext;

	PROCEDURE Fail* (ctxt: Context; msg: ARRAY OF CHAR; obj: Object);
	BEGIN
		IF ~ctxt.failed THEN
			ctxt.failed := TRUE;
			WriteStr(ctxt.err, "Scheme execution error - "); WriteStr(ctxt.err, msg); Write(ctxt.err, newline);
			IF obj # NIL THEN
				WriteStr(ctxt.err, "  obj = "); WriteObj(ctxt.err, obj); Write(ctxt.err, newline)
			END;
			WriteStr(ctxt.err, "  exp = "); WriteObj(ctxt.err, ctxt.exp); Write(ctxt.err, newline);
			WriteStr(ctxt.err, "  args = "); WriteObj(ctxt.err, ctxt.args); Write(ctxt.err, newline);
			Flush(ctxt.err)
		END
	END Fail;

	PROCEDURE FailCode* (ctxt: Context; code: SIGNED16; obj: Object);
	BEGIN
		CASE code OF
		| errEval: Fail(ctxt, "cannot evaluate object", obj)
		| errUnbound: Fail(ctxt, "unbound variable", obj)
		| errArg: Fail(ctxt, "not enough (valid) arguments", obj)
		| errVar: Fail(ctxt, "argument must be variable", obj)
		| errOp: Fail(ctxt, "cannot apply operator", obj)
		| errMany: Fail(ctxt, "too many arguments", obj)
		| errFormal: Fail(ctxt, "invalid formal parameter", obj)
		ELSE Fail(ctxt, "unknown error", obj)
		END
	END FailCode;


	(**--- Environments ---**)

	PROCEDURE NewEnvironment* (outer: Environment): Environment;
		VAR env: Environment;
	BEGIN
		NEW(env); env.outer := outer; RETURN env
	END NewEnvironment;

	PROCEDURE Extend* (outer: Environment; par, arg: Object; ctxt: Context): Environment;
		VAR env: Environment; dsc: Object; bind: Binding; idx: SIGNED32;
	BEGIN
		env := NewEnvironment(outer);
		WHILE par.type = pair DO
			dsc := par.dsc;
			IF arg.type # pair THEN FailCode(ctxt, errArg, arg); bind := NIL
			ELSIF dsc.type = symbol THEN NEW(bind); bind.sym := dsc(Symbol); bind.value := arg.dsc; arg := arg.next
			ELSE FailCode(ctxt, errFormal, dsc); bind := NIL
			END;
			IF bind # NIL THEN
				idx := bind.sym.hash MOD envSize;
				bind.next := env.chain[idx]; env.chain[idx] := bind
			END;
			par := par.next
		END;
		IF par.type = symbol THEN
			NEW(bind); bind.sym := par(Symbol); bind.value := arg;
			idx := bind.sym.hash MOD envSize;
			bind.next := env.chain[idx]; env.chain[idx] := bind
		ELSIF par.type # null THEN FailCode(ctxt, errFormal, par)
		ELSIF arg.type # null THEN FailCode(ctxt, errMany, arg)
		END;
		RETURN env
	END Extend;

	PROCEDURE DefineVariable* (var, val: Object; env: Environment);
		VAR sym: Symbol; idx: SIGNED32; bind: Binding;
	BEGIN
		sym := var(Symbol);
		idx := sym.hash MOD envSize; bind := env.chain[idx];
		WHILE bind # NIL DO
			IF bind.sym = sym THEN
				bind.value := val; RETURN
			END;
			bind := bind.next
		END;
		NEW(bind); bind.sym := sym; bind.value := val;
		bind.next := env.chain[idx]; env.chain[idx] := bind
	END DefineVariable;

	PROCEDURE FindBinding (sym: Symbol; env: Environment): Binding;
		VAR bind: Binding;
	BEGIN
		WHILE env # NIL DO
			bind := env.chain[sym.hash MOD envSize];
			WHILE bind # NIL DO
				IF bind.sym = sym THEN
					RETURN bind
				END;
				bind := bind.next
			END;
			env := env.outer
		END;
		RETURN NIL
	END FindBinding;

	PROCEDURE LookupVariable* (var: Object; env: Environment; VAR val: Object): BOOLEAN;
		VAR bind: Binding;
	BEGIN
		bind := FindBinding(var(Symbol), env);
		IF bind = NIL THEN RETURN FALSE
		ELSE val := bind.value; RETURN TRUE
		END
	END LookupVariable;

	PROCEDURE SetVariable* (var, val: Object; env: Environment): BOOLEAN;
		VAR bind: Binding;
	BEGIN
		bind := FindBinding(var(Symbol), env);
		IF bind = NIL THEN RETURN FALSE
		ELSE bind.value := val; RETURN TRUE
		END
	END SetVariable;

	PROCEDURE WriteEnv* (out: Object; env: Environment);
		VAR i: SIGNED32; b: Binding;
	BEGIN
		WriteStr(out, "environment"); Write(out, newline);
		FOR i := 0 TO envSize-1 DO
			b := env.chain[i];
			WHILE b # NIL DO
				WriteStr(out, "> "); WriteObj(out, b.sym); WriteStr(out, " = "); WriteObj(out, b.value); Write(out, newline); b := b.next
			END
		END
	END WriteEnv;


	(*--- Derived Expressions ---*)

	PROCEDURE CondToIf (ctxt: Context; exp: Object; VAR res: Object);
		VAR cond, seq: Object;
	BEGIN
		IF exp.type = null THEN res := false
		ELSIF exp.type # pair THEN FailCode(ctxt, errArg, exp)
		ELSE
			cond := exp.dsc;
			IF cond.type # pair THEN FailCode(ctxt, errArg, cond)
			ELSE
				seq := cond.next;
				IF seq.type = null THEN
				ELSIF seq.type # pair THEN FailCode(ctxt, errArg, seq)
				ELSIF seq.next.type = null THEN seq := seq.dsc
				ELSE seq := NewPair(beginSym, seq)
				END;
				IF cond.dsc = elseSym THEN
					IF exp.next.type # null THEN Fail(ctxt, "illegal 'else' (must be last clause)", cond)
					ELSE res := seq
					END
				ELSE
					CondToIf(ctxt, exp.next, res);
					res := NewPair(ifSym, NewPair(cond.dsc, NewPair(seq, NewPair(res, nil))))
				END
			END
		END
	END CondToIf;

	PROCEDURE CaseToIf (ctxt: Context; exp: Object; VAR res: Object);
		VAR key, atom, case, var: Object;

		PROCEDURE caseToIf (key, clauses: Object; VAR res: Object);
			VAR clause, quote, memv, seq: Object;
		BEGIN
			clause := clauses.dsc;
			IF clause.dsc = elseSym THEN
				res := NewPair(beginSym, clause.next)
			ELSIF clause.dsc.type # pair THEN
				FailCode(ctxt, errArg, clause.dsc)
			ELSE
				quote := NewPair(quoteSym, NewPair(clause.dsc, nil));
				memv := NewPair(NewSymbol("memv"), NewPair(key, NewPair(quote, nil)));
				seq := NewPair(beginSym, clause.next);
				IF clauses.next.type = null THEN
					res := NewPair(ifSym, NewPair(memv, NewPair(seq, nil)))
				ELSIF clauses.next.type # pair THEN
					FailCode(ctxt, errArg, clauses.next)
				ELSE
					caseToIf(key, clauses.next, res);
					res := NewPair(ifSym, NewPair(memv, NewPair(seq, NewPair(res, nil))))
				END
			END
		END caseToIf;

	BEGIN
		IF exp.type = null THEN res := false
		ELSIF exp.type # pair THEN FailCode(ctxt, errArg, exp)
		ELSE
			key := exp.dsc; exp := exp.next;
			IF key.type = pair THEN
				atom := NewSymbol("atom-key");
				case := NewPair(caseSym, NewPair(atom, exp));
				var := NewPair(NewPair(atom, NewPair(key, nil)), nil);
				res := NewPair(letSym, NewPair(var, NewPair(case, nil)))
			ELSIF exp.type # pair THEN FailCode(ctxt, errArg, exp)
			ELSE
				caseToIf(key, exp, res)
			END
		END
	END CaseToIf;

	PROCEDURE AndToIf (ctxt: Context; exp: Object; VAR res: Object);
		VAR cond: Object;
	BEGIN
		IF exp.type = null THEN res := true
		ELSIF exp.type # pair THEN FailCode(ctxt, errArg, exp)
		ELSE
			cond := exp.dsc; exp := exp.next;
			IF exp.type = null THEN res := cond
			ELSIF exp.type # pair THEN FailCode(ctxt, errArg, exp)
			ELSE AndToIf(ctxt, exp, res); res := NewPair(ifSym, NewPair(cond, NewPair(res, nil)))
			END
		END
	END AndToIf;

	PROCEDURE OrToIf (ctxt: Context; exp: Object; VAR res: Object);
		VAR cond, or, if: Object;
	BEGIN
		IF exp.type = null THEN res := false
		ELSIF exp.type # pair THEN FailCode(ctxt, errArg, exp)
		ELSE
			cond := exp.dsc; exp := exp.next;
			IF exp.type = null THEN res := cond
			ELSIF exp.type # pair THEN FailCode(ctxt, errArg, exp)
			ELSE
				OrToIf(ctxt, exp, res);
				or := NewSymbol("or-cond");
				if := NewPair(ifSym, NewPair(or, NewPair(or, NewPair(res, nil))));
				res := NewPair(letSym, NewPair(NewPair(NewPair(or, NewPair(cond, nil)), nil), NewPair(if, nil)))
			END
		END
	END OrToIf;

	PROCEDURE Append (VAR list: Object; obj: Object);
		VAR l: Object;
	BEGIN
		IF list.type = null THEN list := NewPair(obj, nil)
		ELSE l := list; WHILE l.next.type = pair DO l := l.next END; l.next := NewPair(obj, nil)
		END
	END Append;

	PROCEDURE LetToLambda (ctxt: Context; exp: Object; VAR res: Object);
		VAR obj, tag, par, val, tmp: Object;
	BEGIN
		IF exp.type # pair THEN FailCode(ctxt, errArg, exp)
		ELSE
			obj := exp.dsc; exp := exp.next; tag := nil;
			IF ~(obj.type IN {pair, null}) THEN
				tag := obj; obj := exp.dsc; exp := exp.next
			END;
			IF exp.type # pair THEN FailCode(ctxt, errArg, exp)
			ELSE
				par := nil; val := nil;
				WHILE ~ctxt.failed & (obj.type # null) DO
					IF obj.type # pair THEN FailCode(ctxt, errArg, obj)
					ELSIF obj.dsc.type # pair THEN FailCode(ctxt, errArg, obj.dsc)
					ELSIF obj.dsc.next.type # pair THEN FailCode(ctxt, errArg, obj.dsc.next)
					ELSE
						Append(par, obj.dsc.dsc); Append(val, obj.dsc.next.dsc);
						obj := obj.next
					END
				END;
				IF tag = nil THEN
					res := NewPair(NewPair(lambdaSym, NewPair(par, exp)), val)
				ELSE
					tmp := NewPair(NewPair(tag, NewPair(NewPair(lambdaSym, NewPair(par, exp)), nil)), nil);
					res := NewPair(NewPair(letrecSym, NewPair(tmp, NewPair(tag, nil))), val)
				END
			END
		END
	END LetToLambda;

	PROCEDURE LetXToLet (ctxt: Context; exp: Object; VAR res: Object);
		VAR obj, body, arg, p: Object;
	BEGIN
		IF exp.type # pair THEN FailCode(ctxt, errArg, exp)
		ELSE
			obj := exp.dsc; body := exp.next;
			IF body.type # pair THEN FailCode(ctxt, errArg, body)
			ELSE
				arg := NewPair(nil, nil); res := NewPair(letSym, arg);
				WHILE ~ctxt.failed & (obj.type # null) DO
					IF obj.type # pair THEN FailCode(ctxt, errArg, obj)
					ELSE
						arg.dsc := NewPair(obj.dsc, nil);
						p := NewPair(nil, nil); arg.next := NewPair(NewPair(letSym, p), nil); arg := p;
						obj := obj.next
					END
				END;
				SetCdr(arg, body)
			END
		END
	END LetXToLet;

	PROCEDURE LetrecToLet (ctxt: Context; exp: Object; VAR res: Object);
		VAR obj, body, unassigned, arg, set, quote, sym, inner: Object; tmp: ARRAY 3 OF CHAR; n: SIGNED32;
	BEGIN
		IF exp.type # pair THEN FailCode(ctxt, errArg, exp)
		ELSE
			obj := exp.dsc; body := exp.next;
			IF body.type # pair THEN FailCode(ctxt, errArg, body)
			ELSE
				unassigned := nil; arg := nil; set := nil; tmp := "; "; n := 0;
				quote := NewPair(quoteSym, NewPair(unassignedSym, nil));
				WHILE ~ctxt.failed & (obj.type # null) DO
					IF obj.type # pair THEN FailCode(ctxt, errArg, obj)
					ELSIF obj.dsc.type # pair THEN FailCode(ctxt, errArg, obj.dsc)
					ELSE
						Append(unassigned, NewPair(obj.dsc.dsc, NewPair(quote, nil)));
						tmp[1] := CHR(ORD("0") + n); INC(n); sym := NewSymbol(tmp);
						Append(arg, NewPair(sym, obj.dsc.next));
						Append(set, NewPair(setSym, NewPair(obj.dsc.dsc, NewPair(sym, nil))));
						obj := obj.next
					END
				END;
				inner := NewPair(letSym, NewPair(arg, set));
				res := NewPair(letSym, NewPair(unassigned, NewPair(inner, body)))
			END
		END
	END LetrecToLet;

	PROCEDURE BeginToLambda (ctxt: Context; exp: Object; VAR res: Object);
	BEGIN
		IF exp.type # pair THEN FailCode(ctxt, errArg, exp)
		ELSIF exp.next.type = null THEN res := exp.dsc
		ELSE res := NewPair(NewPair(lambdaSym, NewPair(nil, exp)), nil)
		END
	END BeginToLambda;

	PROCEDURE DoToLetrec (ctxt: Context; exp: Object; VAR res: Object);
		VAR obj, par, step, init, loop, p, var, else, test: Object;
	BEGIN
		IF exp.type # pair THEN FailCode(ctxt, errArg, exp)
		ELSE
			obj := exp.dsc; exp := exp.next;
			IF exp.type # pair THEN FailCode(ctxt, errArg, exp)
			ELSE
				par := nil; step := nil; init := nil; loop := NewSymbol(";loop");
				WHILE ~ctxt.failed & (obj.type # null) DO
					IF obj.type # pair THEN FailCode(ctxt, errArg, obj)
					ELSIF obj.dsc.type # pair THEN FailCode(ctxt, errArg, obj.dsc)
					ELSE
						p := obj.dsc; var := p.dsc; Append(par, var); p := p.next;
						IF p.type # pair THEN FailCode(ctxt, errArg, p)
						ELSIF p.next.type = null THEN Append(step, var); Append(init, p.dsc)	(* no step *)
						ELSIF p.next.type # pair THEN FailCode(ctxt, errArg, p.next)
						ELSE Append(step, p.next.dsc); Append(init, p.dsc)
						END;
						obj := obj.next
					END
				END;
				IF exp.dsc.type # pair THEN FailCode(ctxt, errArg, exp.dsc)
				ELSE
					else := NewPair(beginSym, exp.next); p := else;
					WHILE p.next.type = pair DO p := p.next END;
					IF p.next.type = null THEN p.next := NewPair(NewPair(loop, step), nil)
					ELSE FailCode(ctxt, errArg, p.next)
					END;
					test := NewPair(ifSym, NewPair(exp.dsc.dsc, NewPair(NewPair(beginSym, exp.dsc.next), NewPair(else, nil))));
					res := NewPair(loop, NewPair(NewPair(lambdaSym, NewPair(par, NewPair(test, nil))), nil));
					res := NewPair(letrecSym, NewPair(NewPair(res, nil), NewPair(NewPair(loop, init), nil)))
				END
			END
		END
	END DoToLetrec;

	PROCEDURE DelayToPromise (ctxt: Context; exp: Object; VAR res: Object);
	BEGIN
		IF exp.type # pair THEN FailCode(ctxt, errArg, exp)
		ELSE res := NewPair(NewSymbol("make-promise"), NewPair(NewPair(lambdaSym, NewPair(nil, exp)), nil))
		END
	END DelayToPromise;


	(**--- Evaluation ---**)

	PROCEDURE EvalIf (ctxt: Context);
		VAR p: Object;
	BEGIN
		PopEval(ctxt.stack, ctxt.cont); PopEnv(ctxt.stack, ctxt.env); PopObj(ctxt.stack, p);
		IF (ctxt.res.type # bool) OR ctxt.res(Bool).b THEN ctxt.exp := p.dsc; ctxt.eval := EvalDispatch
		ELSIF p.next.type = null THEN ctxt.res := false; ctxt.eval := ctxt.cont
		ELSIF p.next.type # pair THEN FailCode(ctxt, errArg, p.next)
		ELSE ctxt.exp := p.next.dsc; ctxt.eval := EvalDispatch
		END
	END EvalIf;

	PROCEDURE EvalAssignment (ctxt: Context);
		VAR env: Environment; var: Object;
	BEGIN
		PopEval(ctxt.stack, ctxt.eval); PopEnv(ctxt.stack, env); PopObj(ctxt.stack, var);
		IF ~SetVariable(var, ctxt.res, env) THEN FailCode(ctxt, errUnbound, var) END;
		ctxt.res := true
	END EvalAssignment;

	PROCEDURE EvalDefinition (ctxt: Context);
		VAR env: Environment; var: Object;
	BEGIN
		PopEval(ctxt.stack, ctxt.eval); PopEnv(ctxt.stack, env); PopObj(ctxt.stack, var);
		DefineVariable(var, ctxt.res, env);
		ctxt.res := true
	END EvalDefinition;

	PROCEDURE EvalContinueSeq (ctxt: Context);
	BEGIN
		PopEnv(ctxt.stack, ctxt.env); PopObj(ctxt.stack, ctxt.unev); ctxt.eval := EvalSequence
	END EvalContinueSeq;

	PROCEDURE EvalSequence (ctxt: Context);
		VAR unev: Object;
	BEGIN
		unev := ctxt.unev; ctxt.exp := unev.dsc; ctxt.eval := EvalDispatch;
		IF unev.next.type = null THEN ctxt.unev := NIL; PopEval(ctxt.stack, ctxt.cont)	(* allow tail-recursion *)
		ELSIF unev.next.type # pair THEN FailCode(ctxt, errArg, unev.next)
		ELSE
			PushObj(ctxt.stack, unev.next); PushEnv(ctxt.stack, ctxt.env);
			ctxt.cont := EvalContinueSeq
		END
	END EvalSequence;

	PROCEDURE EvalApply (ctxt: Context);
		VAR proc: Procedure;
	BEGIN
		IF ctxt.res.type # procedure THEN FailCode(ctxt, errOp, ctxt.res)
		ELSIF ctxt.res.sub = primitive THEN
			ctxt.exp := ctxt.res; ctxt.exp(Primitive).eval(ctxt, ctxt.args, ctxt.res); ctxt.args := nil;
			PopEval(ctxt.stack, ctxt.eval)
		ELSE
			proc := ctxt.res(Procedure);
			ctxt.env := Extend(proc.env, proc.par, ctxt.args, ctxt); ctxt.args := nil;
			ctxt.unev := proc.body; ctxt.eval := EvalSequence
		END
	END EvalApply;

	PROCEDURE AppendArg (ctxt: Context);
		VAR p: Object;
	BEGIN
		p := NewPair(ctxt.res, nil);
		IF ctxt.args = nil THEN p.next := p
		ELSE p.next := ctxt.args.next; ctxt.args.next := p
		END;
		ctxt.args := p
	END AppendArg;

	PROCEDURE EvalLastArg (ctxt: Context);
		VAR last: Object;
	BEGIN
		PopObj(ctxt.stack, ctxt.args); AppendArg(ctxt);
		last := ctxt.args; ctxt.args := last.next; last.next := nil;	(* break cycle *)
		PopObj(ctxt.stack, ctxt.res);
		ctxt.eval := EvalApply
	END EvalLastArg;

	PROCEDURE EvalNonListArg (ctxt: Context);
		VAR last: Object;
	BEGIN
		PopObj(ctxt.stack, ctxt.args);
		IF ctxt.args = nil THEN ctxt.args := ctxt.res
		ELSE last := ctxt.args; ctxt.args := last.next; last.next := ctxt.res
		END;
		PopObj(ctxt.stack, ctxt.res);
		ctxt.eval := EvalApply
	END EvalNonListArg;

	PROCEDURE EvalAddArg (ctxt: Context);
	BEGIN
		PopObj(ctxt.stack, ctxt.unev); PopEnv(ctxt.stack, ctxt.env); PopObj(ctxt.stack, ctxt.args);
		AppendArg(ctxt);
		ctxt.eval := EvalNextArg
	END EvalAddArg;

	PROCEDURE EvalNextArg (ctxt: Context);
	BEGIN
		PushObj(ctxt.stack, ctxt.args); ctxt.args := nil;
		IF ctxt.unev.type = pair THEN
			ctxt.exp := ctxt.unev.dsc;
			IF ctxt.unev.next.type = null THEN ctxt.unev := NIL; ctxt.cont := EvalLastArg
			ELSE PushEnv(ctxt.stack, ctxt.env); PushObj(ctxt.stack, ctxt.unev.next); ctxt.cont := EvalAddArg
			END
		ELSE
			ctxt.exp := ctxt.unev; ctxt.cont := EvalNonListArg
		END;
		ctxt.eval := EvalDispatch
	END EvalNextArg;

	PROCEDURE EvalArgs (ctxt: Context);
	BEGIN
		PopObj(ctxt.stack, ctxt.unev); PopEnv(ctxt.stack, ctxt.env);
		IF ctxt.unev.type = null THEN ctxt.eval := EvalApply
		ELSIF ctxt.unev.type # pair THEN FailCode(ctxt, errArg, ctxt.unev)
		ELSE PushObj(ctxt.stack, ctxt.res); ctxt.eval := EvalNextArg
		END
	END EvalArgs;

	PROCEDURE EvalDispatch (ctxt: Context);
		VAR p, dsc, next: Object;
	BEGIN
		CASE ctxt.exp.type OF
		| bool..reference:
			ctxt.res := ctxt.exp; ctxt.eval := ctxt.cont
		| symbol:
			IF ~LookupVariable(ctxt.exp, ctxt.env, ctxt.res) THEN FailCode(ctxt, errUnbound, ctxt.exp) END;
			ctxt.eval := ctxt.cont
		| pair:
			p := ctxt.exp; dsc := p.dsc; next := p.next;
			IF dsc.type = symbol THEN
				IF dsc = quoteSym THEN
					IF next.type # pair THEN FailCode(ctxt, errArg, next)
					ELSIF next.next.type # null THEN FailCode(ctxt, errArg, next.next)
					ELSE ctxt.res := next.dsc; ctxt.eval := ctxt.cont
					END
				ELSIF dsc = lambdaSym THEN
					IF next.type # pair THEN FailCode(ctxt, errArg, next)
					ELSIF next.next.type # pair THEN FailCode(ctxt, errArg, next.next)
					ELSE ctxt.res := NewProcedure(ctxt.env, next.dsc, next.next); ctxt.eval := ctxt.cont
					END
				ELSIF dsc = ifSym THEN
					IF next.type # pair THEN FailCode(ctxt, errArg, next)
					ELSIF next.next.type # pair THEN FailCode(ctxt, errArg, next.next)
					ELSE
						PushObj(ctxt.stack, next.next); PushEnv(ctxt.stack, ctxt.env); PushEval(ctxt.stack, ctxt.cont);
						ctxt.exp := next.dsc; ctxt.cont := EvalIf
					END
				ELSIF dsc = setSym THEN
					IF next.type # pair THEN FailCode(ctxt, errArg, next)
					ELSIF next.dsc.type # symbol THEN FailCode(ctxt, errVar, next.dsc)
					ELSE
						PushObj(ctxt.stack, next.dsc); next := next.next;
						IF next.type # pair THEN FailCode(ctxt, errArg, next)
						ELSIF next.next.type # null THEN FailCode(ctxt, errArg, next.next)
						ELSE
							PushEnv(ctxt.stack, ctxt.env); PushEval(ctxt.stack, ctxt.cont);
							ctxt.exp := next.dsc; ctxt.cont := EvalAssignment
						END
					END
				ELSIF dsc= defineSym THEN
					IF next.type # pair THEN FailCode(ctxt, errArg, next)
					ELSE
						dsc := next.dsc; next := next.next;
						IF next.type # pair THEN FailCode(ctxt, errArg, next)
						ELSIF dsc.type = symbol THEN	(* (define symbol value) *)
							IF next.next.type # null THEN FailCode(ctxt, errArg, next.next)
							ELSE
								PushObj(ctxt.stack, dsc); PushEnv(ctxt.stack, ctxt.env); PushEval(ctxt.stack, ctxt.cont);
								ctxt.exp := next.dsc; ctxt.cont := EvalDefinition
							END
						ELSIF (dsc.type = pair) & (dsc.dsc.type = symbol) THEN	(* (define (symbol par ..) body *)
							DefineVariable(dsc.dsc, NewProcedure(ctxt.env, dsc.next, next), ctxt.env);
							ctxt.eval := ctxt.cont; ctxt.res := true
						ELSE FailCode(ctxt, errVar, dsc.dsc)
						END
					END
				ELSIF dsc = condSym THEN
					CondToIf(ctxt, next, ctxt.exp)
				ELSIF dsc = caseSym THEN
					CaseToIf(ctxt, next, ctxt.exp)
				ELSIF dsc = andSym THEN
					AndToIf(ctxt, next, ctxt.exp)
				ELSIF dsc = orSym THEN
					OrToIf(ctxt, next, ctxt.exp)
				ELSIF dsc = letSym THEN
					LetToLambda(ctxt, next, ctxt.exp)
				ELSIF dsc = letXSym THEN
					LetXToLet(ctxt, next, ctxt.exp)
				ELSIF dsc = letrecSym THEN
					LetrecToLet(ctxt, next, ctxt.exp)
				ELSIF dsc = beginSym THEN
					BeginToLambda(ctxt, next, ctxt.exp)
				ELSIF dsc = doSym THEN
					DoToLetrec(ctxt, next, ctxt.exp)
				ELSIF dsc = delaySym THEN
					DelayToPromise(ctxt, next, ctxt.exp)
				ELSE	(* application *)
					PushEval(ctxt.stack, ctxt.cont);
					IF ~LookupVariable(dsc, ctxt.env, ctxt.res) THEN FailCode(ctxt, errUnbound, dsc) END;
					IF next.type = null THEN ctxt.eval := EvalApply
					ELSE PushObj(ctxt.stack, ctxt.res); ctxt.unev := next; ctxt.eval := EvalNextArg
					END
				END
			ELSE	(* application *)
				PushEval(ctxt.stack, ctxt.cont); PushEnv(ctxt.stack, ctxt.env); PushObj(ctxt.stack, next);
				ctxt.exp := dsc; ctxt.cont := EvalArgs
			END
		ELSE
			FailCode(ctxt, errEval, ctxt.exp)
		END
	END EvalDispatch;

	(** evaluate expression in given environment **)
	PROCEDURE Evaluate* (ctxt: Context; env: Environment; exp: Object): Object;
	BEGIN
		ctxt.env := env; ctxt.failed := FALSE;
		ctxt.cont := NIL; ctxt.exp := exp; ctxt.res := nil; ctxt.unev := NIL; ctxt.args := nil; ctxt.eval := EvalDispatch;
		REPEAT ctxt.eval(ctxt) UNTIL (ctxt.eval = NIL) OR ctxt.failed;
		RETURN ctxt.res
	END Evaluate;

	(** evaluate list of statements in given environment **)
	PROCEDURE EvaluateSequence* (ctxt: Context; env: Environment; seq: Object);
	BEGIN
		ctxt.env := env; ctxt.failed := FALSE;
		ctxt.cont := NIL; ctxt.unev := seq; ctxt.res := nil; ctxt.args := nil;
		PushEval(ctxt.stack, NIL); ctxt.eval := EvalSequence;
		REPEAT ctxt.eval(ctxt) UNTIL (ctxt.eval = NIL) OR ctxt.failed
	END EvaluateSequence;

	(** evaluate procedure with given arguments in current environment **)
	PROCEDURE Call* (ctxt: Context; proc, args: Object);
		VAR cont: Evaluator;
	BEGIN
		IF ~ctxt.failed THEN
			cont := ctxt.cont; PushEval(ctxt.stack, NIL);
			ctxt.res := proc; ctxt.args := args; ctxt.eval := EvalApply;
			REPEAT ctxt.eval(ctxt) UNTIL (ctxt.eval = NIL) OR ctxt.failed;
			ctxt.cont := cont
		END
	END Call;


	(*--- Scanner ---*)

	PROCEDURE ScanCh (in: Object; VAR ch: CHAR);
	BEGIN
		ReadCh(in, ch);
		IF ("A" <= ch) & (ch <= "Z") THEN
			ch := CHR(ORD(ch) + ORD("a") - ORD("A"))
		END
	END ScanCh;

	PROCEDURE ScanNumber (in: Object; VAR ch: CHAR; radix: SIGNED32; VAR t: Token);
		VAR part, state, sign, i, d: SIGNED32; polar, exact: BOOLEAN; r, f, imag: FLOAT64;

		PROCEDURE derationalize (n, d: SIGNED32): FLOAT64;
		BEGIN
			IF d = 0 THEN t.kind := invalid; RETURN 0
			ELSE RETURN n/d
			END
		END derationalize;

	BEGIN
		t.kind := -1; part := 0; polar := TRUE; state := 0;
		REPEAT
			CASE ch OF
			| "#":
				IF state = 0 THEN exact := TRUE; state := 5
				ELSIF state = 5 THEN
					ScanCh(in, ch);
					IF ch = "e" THEN exact := TRUE
					ELSIF ch = "i" THEN exact := FALSE
					ELSIF ch = "b" THEN radix := 2
					ELSIF ch = "o" THEN radix := 8
					ELSIF ch = "d" THEN radix := 10
					ELSIF ch = "x" THEN radix := 16
					ELSE t.kind := invalid
					END;
					ScanCh(in, ch)
				ELSIF state = 8 THEN exact := FALSE; state := 9
				ELSIF state = 11 THEN exact := FALSE; state := 12
				ELSIF state = 14 THEN state := 15
				ELSIF state IN {9, 12} THEN
					IF sign * i > MAX(SIGNED32) DIV radix THEN t.kind := invalid
					ELSE i := radix * i
					END;
					ScanCh(in, ch)
				ELSIF state IN {13, 15} THEN ScanCh(in, ch)
				ELSE t.kind := invalid
				END
			| "+", "-":
				IF ch = "+" THEN sign := 1 ELSE sign := -1 END;
				IF state = 0 THEN polar := FALSE; state := 4
				ELSIF state = 5 THEN polar := FALSE; state := 6
				ELSIF state = 16 THEN i := 0; state := 17
				ELSIF state = 19 THEN state := 6
				ELSIF part = 1 THEN t.kind := invalid
				ELSIF state IN {8, 9} THEN t.real := i; part := 1; polar := FALSE; state := 6
				ELSIF state IN {11, 12} THEN t.real := derationalize(t.num, i); part := 1; polar := FALSE; state := 6
				ELSIF state IN {13, 14, 15} THEN t.real := r; part := 1; polar := FALSE; state := 6
				ELSIF state = 18 THEN t.real := r * Reals.Ten(i); part := 1; polar := FALSE; state := 6
				ELSE t.kind := invalid
				END;
				ScanCh(in, ch)
			| ".":
				exact := FALSE;
				IF state IN {0..2} THEN INC(state)
				ELSIF state = 4 THEN radix := 10; state := 7
				ELSIF state IN {5, 6} THEN state := 7
				ELSIF (state = 8) & (radix = 10) THEN r := i; f := 1.0; state := 14
				ELSIF (state = 9) & (radix = 10) THEN r := i; state := 13
				ELSIF state = 19 THEN sign := 1; state := 7
				ELSE t.kind := invalid
				END;
				ScanCh(in, ch)
			| "/":
				IF state IN {8, 9} THEN t.num := i; state := 10
				ELSE t.kind := invalid
				END;
				ScanCh(in, ch)
			| "@":
				polar := TRUE;
				IF part = 1 THEN t.kind := invalid
				ELSIF state IN {8, 9} THEN part := 1; t.real := i; state := 19
				ELSIF state IN {11, 12} THEN part := 1; t.real := derationalize(t.num, i); state := 19
				ELSIF state IN {13, 14, 15} THEN part := 1; t.real := r; state := 19
				ELSIF state = 18 THEN part := 1; t.real := r * Reals.Ten(i); state := 19
				ELSE t.kind := invalid
				END
			| "0".."9":
				IF state = 0 THEN exact := TRUE; sign := 1; i := 0; state := 8
				ELSIF state = 1 THEN radix := 10; sign := 1; r := 0.0; f := 1.0; state := 14
				ELSIF state = 4 THEN exact := TRUE; i := 0; state := 8
				ELSIF state IN {5, 19} THEN sign := 1; i := 0; state := 8
				ELSIF state = 6 THEN i := 0; state := 8
				ELSIF (state = 7) & (radix = 10) THEN r := 0.0; f := 1.0; state := 14
				ELSIF state IN {8, 11, 18} THEN
					d := ORD(ch) - ORD("0");
					IF d >= radix THEN t.kind := invalid
					ELSIF sign * i > (MAX(SIGNED32) - d) DIV radix THEN t.kind := invalid
					ELSE i := radix * i + sign * d
					END;
					ScanCh(in, ch)
				ELSIF state = 10 THEN sign := 1; i := 0; state := 11
				ELSIF state = 14 THEN
					d := ORD(ch) - ORD("0");
					f := f/10; r := r + sign * d * f;
					ScanCh(in, ch)
				ELSIF state = 16 THEN sign := 1; i := 0; state := 18
				ELSIF state = 17 THEN i := 0; state := 18
				ELSE t.kind := invalid
				END
			| "a".."c":
				IF state IN {5, 19} THEN sign := 1; i := 0; state := 8
				ELSIF state = 6 THEN i := 0; state := 8
				ELSIF (state IN {8, 11}) & (radix = 16) THEN
					d := ORD(ch) - (ORD("a") - 10);
					IF sign * i > (MAX(SIGNED32) - d) DIV 16 THEN t.kind := invalid
					ELSE i := 16 * i + sign * d
					END;
					ScanCh(in, ch)
				ELSIF (state = 10) & (radix = 16) THEN i := 0; state := 11
				ELSE t.kind := invalid
				END
			| "d".."f":
				IF (state IN {5, 19}) & (radix = 16) THEN sign := 1; i := 0; state := 8
				ELSIF (state = 6) & (radix = 16) THEN i := 0; state := 8
				ELSIF (state IN {8, 11}) & (radix = 16) THEN
					d := ORD(ch) - (ORD("a") - 10);
					IF sign * i > (MAX(SIGNED32) - d) DIV 16 THEN t.kind := invalid
					ELSE i := 16 * i + sign * d
					END;
					ScanCh(in, ch)
				ELSIF (state IN {8, 9}) & (radix = 10) THEN exact := FALSE; r := i; state := 16; ScanCh(in, ch)
				ELSIF (state = 10) & (radix = 16) THEN i := 0; state := 11
				ELSIF (state IN {13, 14, 15}) & (radix = 10) THEN i := 0; state := 16; ScanCh(in, ch)
				ELSE t.kind := invalid
				END
			| "l", "s":
				IF (state IN {8, 9}) & (radix = 10) THEN exact := FALSE; r := i; state := 16
				ELSIF (state IN {13, 14, 15}) & (radix = 10) THEN i := 0; state := 16
				ELSE t.kind := invalid
				END;
				ScanCh(in, ch)
			| "i":
				IF polar THEN t.kind := invalid
				ELSIF state = 4 THEN imag := sign
				ELSIF state IN {8, 9} THEN imag := sign * i
				ELSIF state IN {11, 12} THEN imag := derationalize(t.num, i)
				ELSIF state IN {13, 14, 15} THEN imag := r
				ELSIF state = 18 THEN imag := r * Reals.Ten(i)
				ELSE t.kind := invalid
				END;
				IF part = 0 THEN t.real := 0.0 END;
				ScanCh(in, ch); state := 20
			| 0X.." ", "(", ")", '"', ";":
				IF part = 0 THEN
					IF state = 1 THEN t.kind := dot
					ELSIF state = 3 THEN t.kind := ident; t.s := "..."
					ELSIF (state = 4) & (sign > 0) THEN t.kind := ident; t.s := "+"
					ELSIF (state = 4) & (sign < 0) THEN t.kind := ident; t.s := "-"
					ELSIF (state = 8) & exact THEN t.kind := intnum; t.num := i
					ELSIF state IN {8, 9} THEN t.kind := realnum; t.real := i
					ELSIF (state = 11) & exact THEN t.kind := ratnum; t.denom := i
					ELSIF state IN {11, 12} THEN t.kind := realnum; t.real := derationalize(t.num, i)
					ELSIF state IN {13, 14, 15} THEN t.kind := realnum; t.real := r
					ELSIF state = 18 THEN t.kind := realnum; t.real := r * Reals.Ten(i)
					ELSIF state = 20 THEN t.kind := complexnum
					ELSE t.kind := invalid
					END
				ELSIF polar THEN
					t.kind := complexnum;
					IF state IN {8, 9} THEN (*makepolar(t.real, i)*)
					ELSIF state IN {11, 12} THEN (*makepolar(t.real, derationalize(t.num, i))*)
					ELSIF state IN {13, 14, 15} THEN (*makepolar(t.real, r)*)
					ELSIF state = 18 THEN (*makepolar(t.real, r * Reals.Ten(ln10 * i))*)
					ELSE t.kind := invalid
					END
				ELSIF state = 20 THEN t.kind := complexnum
				ELSE t.kind := invalid
				END
			ELSE
				t.kind := invalid
			END
		UNTIL t.kind >= 0;
		WHILE ~(Eof(in) OR (ch <= " ") OR (ch = "(") OR (ch = ")") OR (ch = '"') OR (ch = ";")) DO
			ScanCh(in, ch)
		END;
		Unread(in)
	END ScanNumber;

	PROCEDURE Scan (in: Object; VAR t: Token);
		VAR ch: CHAR; i: SIGNED32;
	BEGIN
		ScanCh(in, ch);
		LOOP
			IF Eof(in) THEN t.kind := eof; t.pos := Pos(in); RETURN
			ELSIF ch <= " " THEN ScanCh(in, ch)
			ELSIF ch = ";" THEN REPEAT ReadCh(in, ch) UNTIL Eof(in) OR (ch = newline)
			ELSE EXIT
			END
		END;
		t.pos := Pos(in)-1;
		CASE ch OF
		| "a".."z", "!", "$", "%", "&", "*", "/", ":", "<", "=", ">", "?", "^", "_", "~":
			i := 0;
			LOOP
				IF i < LEN(t.s)-1 THEN t.s[i] := ch; INC(i) END;
				ScanCh(in, ch);
				CASE ch OF "a".."z", "0".."9", "!", "$", "%", "&", "*", "/", ":", "<", "=", ">", "?", "^", "_", "~", "+", "-", ".", "@":
				ELSE EXIT
				END
			END;
			t.s[i] := 0X; t.kind := ident;
			Unread(in)
		| "0".."9", ".", "+", "-":
			ScanNumber(in, ch, 10, t)
		| "#":
			ScanCh(in, ch);
			IF Eof(in) THEN t.kind := invalid
			ELSIF ch = "~" THEN t.kind := eof
			ELSIF ch = "t" THEN t.kind := boolean; t.bool := TRUE
			ELSIF ch = "f" THEN t.kind := boolean; t.bool := FALSE
			ELSIF ch = "\" THEN
				t.kind := character; ReadCh(in, t.char);
				IF ("A" <= CAP(t.char)) & (CAP(t.char) <= "Z") THEN
					t.s[0] := t.char;
					IF ("A" <= t.char) & (t.char <= "Z") THEN t.s[0] := CHR(ORD(t.char) + ORD("a") - ORD("A")) END;
					ScanCh(in, ch); i := 1;
					WHILE ("a" <= ch) & (ch <= "z") DO t.s[i] := ch; INC(i); ScanCh(in, ch) END;
					t.s[i] := 0X;
					IF t.s = "space" THEN t.char := " "
					ELSIF t.s = "newline" THEN t.char := newline
					ELSIF i # 1 THEN t.kind := invalid
					END;
					Unread(in)
				END
			ELSIF ch = "(" THEN t.kind := lvec
			ELSE Unread(in); ch := "#"; ScanNumber(in, ch, 10, t)
			END
		| '"':
			ReadCh(in, ch); i := 0; t.kind := literal;
			WHILE ch # '"' DO
				IF ch = "\" THEN ReadCh(in, ch) END;
				IF Eof(in) OR (i = LEN(t.s)-1) THEN t.kind := invalid
				ELSE t.s[i] := ch; INC(i)
				END;
				ReadCh(in, ch)
			END;
			t.s[i] := 0X
		| "(": t.kind := lpar
		| ")": t.kind := rpar
		| "'": t.kind := quote
		| "`": t.kind := quasiquote
		| ",":
			ScanCh(in, ch);
			IF ch = "@" THEN t.kind := unquotelist
			ELSE t.kind := unquote; Unread(in)
			END
		ELSE t.kind := invalid
		END
	END Scan;


	(**--- Parser ---**)

	PROCEDURE ReadObj (ctxt: Context; VAR token: Token; VAR obj: Object): BOOLEAN;
		VAR n: SIGNED32; stack: Stack; tok: Token; vec, list, last: Object;
	BEGIN
		Scan(ctxt.in, token);
		CASE token.kind OF
		| invalid: RETURN FALSE
		| ident: obj := NewSymbol(token.s)
		| boolean: IF token.bool THEN obj := true ELSE obj := false END
		| character: obj := NewChar(token.char)
		| literal: obj := NewLiteral(token.s, ctxt.pool)
		| intnum: obj := NewInteger(token.num)
		| ratnum: obj := NewRational(token.num, token.denom)
		| realnum: obj := NewReal(token.real)
		| complexnum: RETURN FALSE
		| lvec:
			n := 0; InitStack(stack);
			WHILE ReadObj(ctxt, tok, obj) & ~IsEof(obj) DO
				PushObj(stack, obj); INC(n)
			END;
			IF tok.kind # rpar THEN token.pos := tok.pos; RETURN FALSE END;
			vec := NewVector(n, nil);
			WHILE n > 0 DO
				DEC(n); PopObj(stack, obj);
				SetVectorAt(vec, n, obj)
			END;
			obj := vec
		| lpar:
			IF ~ReadObj(ctxt, tok, obj) THEN
				IF tok.kind = rpar THEN obj := nil
				ELSE token.pos := tok.pos; RETURN FALSE
				END
			ELSIF IsEof(obj) THEN token.pos := tok.pos; RETURN FALSE
			ELSE
				list := NewPair(nil, nil); last := list;
				LOOP
					SetCar(last, obj);
					IF ReadObj(ctxt, tok, obj) THEN
						IF IsEof(obj) THEN token.pos := tok.pos; RETURN FALSE
						ELSE SetCdr(last, NewPair(nil, nil)); last := Cdr(last)
						END
					ELSIF tok.kind = rpar THEN
						EXIT
					ELSIF tok.kind = dot THEN
						IF ~ReadObj(ctxt, tok, obj) THEN token.pos := tok.pos; RETURN FALSE
						ELSIF IsEof(obj) THEN token.pos := tok.pos; RETURN FALSE
						END;
						SetCdr(last, obj);
						IF ReadObj(ctxt, tok, obj) OR (tok.kind # rpar) THEN token.pos := tok.pos; RETURN FALSE END;
						EXIT
					ELSE
						token.pos := tok.pos; RETURN FALSE
					END
				END;
				obj := list
			END
		| quote:
			IF ~ReadObj(ctxt, tok, obj) THEN token.pos := tok.pos; RETURN FALSE END;
			obj := NewPair(quoteSym, NewPair(obj, nil))
		| quasiquote:
			IF ~ReadObj(ctxt, tok, obj) THEN token.pos := tok.pos; RETURN FALSE END;
			obj := NewPair(quasiquoteSym, NewPair(obj, nil))
		| unquote:
			IF ~ReadObj(ctxt, tok, obj) THEN token.pos := tok.pos; RETURN FALSE END;
			obj := NewPair(unquoteSym, NewPair(obj, nil))
		| unquotelist:
			IF ~ReadObj(ctxt, tok, obj) THEN token.pos := tok.pos; RETURN FALSE END;
			obj := NewPair(unquotelistSym, NewPair(obj, nil))
		| eof:
			obj := EOF
		ELSE
			RETURN FALSE
		END;
		ASSERT(obj # NIL, 120);
		RETURN TRUE
	END ReadObj;

	PROCEDURE Read* (ctxt: Context): Object;
		VAR token: Token; obj: Object; s: ARRAY 12 OF CHAR;
	BEGIN
		IF ReadObj(ctxt, token, obj) THEN RETURN obj
		ELSE
			WriteStr(ctxt.err, "  pos "); Strings.IntToStr(token.pos, s); WriteStr(ctxt.err, s);
			WriteStr(ctxt.err, " syntax error"); Write(ctxt.err, newline); Flush(ctxt.err);
			ctxt.failed := TRUE; RETURN EOF
		END
	END Read;

	PROCEDURE Load* (ctxt: Context; from: Object);
		VAR in: Object; env: Environment; token: Token; obj: Object;
	BEGIN
		in := ctxt.in; env := ctxt.env; ctxt.in := from;
		WHILE ReadObj(ctxt, token, obj) & ~IsEof(obj) DO
			obj := Evaluate(ctxt, ctxt.env, obj)
		END;
		ctxt.env := env; ctxt.in := in
	END Load;


	(**--- Conversions ---**)

	PROCEDURE NumberToString* (obj: Object; radix: SIGNED32; VAR pool: Pool): Object;
		VAR i: SIGNED32; buf: ARRAY 400 OF CHAR;

		PROCEDURE str (s: ARRAY OF CHAR);
			VAR j: SIGNED32;
		BEGIN
			WHILE s[j] # 0X DO buf[i] := s[j]; INC(i); INC(j) END
		END str;

		PROCEDURE int (x: SIGNED32);
			VAR j: SIGNED32; d: ARRAY 32 OF SIGNED16;
		BEGIN
			IF x = MIN(SIGNED32) THEN
				IF radix = 2 THEN str("-10000000000000000000000000000000")
				ELSIF radix = 8 THEN str("-20000000000")
				ELSIF radix = 16 THEN str("-80000000")
				ELSE str("-2147483648")
				END
			ELSE
				IF x < 0 THEN x := -x; buf[i] := "-"; INC(i) END;
				j := 0;
				REPEAT
					d[j] := SHORT(x MOD radix); x := x DIV radix; INC(j)
				UNTIL x = 0;
				REPEAT
					DEC(j);
					IF d[j] < 10 THEN buf[i] := CHR(d[j] + ORD("0"))
					ELSE buf[i] := CHR(d[j] - 10 + ORD("a"))
					END;
					INC(i)
				UNTIL j = 0
			END
		END int;

	BEGIN
		i := 0;
		IF obj.sub = fixnum THEN
			int(obj(Fixnum).int); buf[i] := 0X
		ELSIF obj.sub = rational THEN
			int(obj(Rational).num); buf[i] := "/"; INC(i);
			int(obj(Rational).denom); buf[i] := 0X
		ELSE
			(* replace this by better algo *)
			Strings.RealToFixStr(obj(Flonum).real, buf, 20, 10, 0)
		END;
		RETURN NewLiteral(buf, pool)
	END NumberToString;

	PROCEDURE StringToNumber* (obj: Object; radix: SIGNED32): Object;
		VAR buf: ARRAY 400 OF CHAR; in: Object; ch: CHAR; t: Token;
	BEGIN
		GetString(obj, 0, StringLen(obj), buf);
		in := NewStringInput(buf);
		REPEAT
			ScanCh(in, ch)
		UNTIL ch > " ";
		ScanNumber(in, ch, radix, t);
		IF t.kind = intnum THEN obj := NewInteger(t.num)
		ELSIF t.kind = ratnum THEN obj := NewRational(t.num, t.denom)
		ELSIF t.kind = realnum THEN obj := NewReal(t.real)
		ELSE obj := false
		END;
		RETURN obj
	END StringToNumber;

	PROCEDURE SymbolToString* (obj: Object): Object;
		VAR str: String;
	BEGIN
		NEW(str); str.type := string; str.stretch := obj(Symbol).stretch; RETURN str
	END SymbolToString;

	PROCEDURE StringToSymbol* (obj: Object): Object;
		VAR str: Stretch; s: ARRAY 256 OF CHAR; ps: POINTER TO ARRAY OF CHAR;
	BEGIN
		str := obj(String).stretch;
		IF str.len < LEN(s) THEN GetStretch(str, 0, str.len, s); RETURN NewSymbol(s)
		ELSE NEW(ps, str.len+1); GetStretch(str, 0, str.len+1, ps^); RETURN NewSymbol(ps^)
		END
	END StringToSymbol;


	(**--- Execution ---**)

	PROCEDURE Execute*;
		VAR text: Texts.Text; pos, end, time: SIGNED32; s: Texts.Scanner; in, out, obj, res: Object; ctxt: Context; env: Environment;
	BEGIN
		text := Oberon.Par.text; pos := Oberon.Par.pos;
		Texts.OpenScanner(s, text, pos); Texts.Scan(s);
		IF (s.class = Texts.Char) & (s.c = "*") THEN
			text := Oberon.MarkedText(); pos := 0
		ELSIF (s.class = Texts.Char) & (s.c = "@") THEN
			Oberon.GetSelection(text, pos, end, time)
		ELSIF (s.class = Texts.Char) & (s.c = "^") THEN
			Oberon.GetSelection(text, pos, end, time);
			Texts.OpenScanner(s, text, pos); Texts.Scan(s);
			IF s.class = Texts.Name THEN NEW(text); Texts.Open(text, s.s); pos := 0
			ELSE text := NIL
			END
		END;
		IF (text # NIL) & (text.len > pos) THEN
			in := NewTextInput(text, pos); out := NewTextOutput(Oberon.Log);
			NEW(ctxt); InitContext(ctxt, in, out, out);
			env := Extend(globals, nil, nil, ctxt);
			REPEAT
				obj := Read(ctxt);
				IF ~IsEof(obj) THEN
					res := Evaluate(ctxt, env, obj)
				END
			UNTIL IsEof(obj);
			IF ~ctxt.failed THEN
				WriteObj(out, res); Write(out, newline); Flush(out)
			END
		END
	END Execute;


	(**--- Initialization ---**)

	PROCEDURE InitSymbols;
	BEGIN
		InitPool(symPool);
		quoteSym := NewSymbol("quote"); setSym := NewSymbol("set!"); defineSym := NewSymbol("define");
		ifSym := NewSymbol("if"); lambdaSym := NewSymbol("lambda"); beginSym := NewSymbol("begin");
		letSym := NewSymbol("let"); quasiquoteSym := NewSymbol("quasiquote");
		unquoteSym := NewSymbol("unquote"); unquotelistSym := NewSymbol("unquote-splicing");
		condSym := NewSymbol("cond"); caseSym := NewSymbol("case"); elseSym := NewSymbol("else");
		andSym := NewSymbol("and"); orSym := NewSymbol("or");
		letXSym := NewSymbol("let*"); letrecSym := NewSymbol("letrec"); unassignedSym := NewSymbol("*unassigned*");
		doSym := NewSymbol("do"); delaySym := NewSymbol("delay")
	END InitSymbols;

	PROCEDURE InitGlobals;
		VAR txt: Texts.Text; out: Object; ctxt: Context;
	BEGIN
		globals := NewEnvironment(NIL);
		NEW(txt); Texts.Open(txt, "Scheme.Init");
		IF txt.len # 0 THEN
			out := NewTextOutput(Oberon.Log);
			NEW(ctxt); InitContext(ctxt, nil, out, out); ctxt.env := globals;
			Load(ctxt, NewTextInput(txt, 0))
		ELSE
			Texts.WriteString(OutW, "cannot load library definitions from 'Scheme.Init'");
			Texts.WriteLn(OutW); Texts.Append(Oberon.Log, OutW.buf)
		END
	END InitGlobals;

	PROCEDURE Def* (name: ARRAY OF CHAR; eval: PrimEval);
		VAR sym: Object;
	BEGIN
		sym := NewSymbol(name);
		DefineVariable(sym, NewPrimitive(sym, eval), globals)
	END Def;


BEGIN
	OutText := NIL; Texts.OpenWriter(OutW);
	InitSymbols;
	zero := NewInteger(0); one := NewInteger(1);
	inf := NewReal(Reals.NaNL(0, 0)); ninf := NewReal(-Reals.NaNL(0, 0)); nan := NewReal(Reals.NaNL(1, 1));
	nil := NewNull(); false := NewBool(FALSE); true := NewBool(TRUE);
	EOF := NewEof();
	InitGlobals;
	IF Modules.ThisMod("SchemeOps") = NIL THEN
		Texts.WriteString(OutW, "cannot load builtin Scheme operators");
		Texts.WriteLn(OutW); Texts.Append(Oberon.Log, OutW.buf)
	END
END Scheme.

System.Free SchemeOps Scheme ~
Scheme.Execute (+ 2 3)#~
