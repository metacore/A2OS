(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE SchemeOps IN Oberon; (** portable *)	(* eos  *)

	(**
		Built-in Scheme procedures
	**)

	(*
		18.05.2000 - minor bug fixes and improvements with input/output functions
	*)

	IMPORT
		Files, Objects, Strings, Texts, Gadgets, Scheme;


	TYPE
		Context = Scheme.Context;
		Object = Scheme.Object;


	(**--- Argument Checks ---**)

	PROCEDURE CheckNull* (ctxt: Context; args: Object);
	BEGIN
		IF ~Scheme.IsNull(args) THEN Scheme.FailCode(ctxt, Scheme.errMany, args) END
	END CheckNull;

	PROCEDURE Arg* (ctxt: Context; VAR args: Object): Object;
		VAR obj: Object;
	BEGIN
		IF Scheme.IsNull(args) THEN Scheme.FailCode(ctxt, Scheme.errArg, args); RETURN Scheme.nil
		ELSE Scheme.GetPair(args, obj, args); RETURN obj
		END
	END Arg;

	PROCEDURE BoolArg* (ctxt: Context; VAR args: Object): Object;
		VAR val: Object;
	BEGIN
		val := Arg(ctxt, args);
		IF Scheme.IsBool(val) THEN RETURN val
		ELSE Scheme.Fail(ctxt, "argument must be boolean", val); RETURN Scheme.false
		END
	END BoolArg;

	PROCEDURE BoolVal* (ctxt: Scheme.Context; VAR args: Object): BOOLEAN;
	BEGIN
		RETURN Scheme.BoolValue(BoolArg(ctxt, args))
	END BoolVal;

	PROCEDURE IntArg* (ctxt: Scheme.Context; VAR args: Object): Object;
		VAR val: Object;
	BEGIN
		val := Arg(ctxt, args);
		IF Scheme.IsInteger(val) THEN RETURN val
		ELSE Scheme.Fail(ctxt, "argument must be integer", val); RETURN Scheme.zero
		END
	END IntArg;

	PROCEDURE IntVal* (ctxt: Scheme.Context; VAR args: Object): SIGNED32;
		VAR i: SIGNED32; exact: BOOLEAN;
	BEGIN
		Scheme.GetInteger(IntArg(ctxt, args), i, exact); RETURN i
	END IntVal;

	PROCEDURE NumArg* (ctxt: Scheme.Context; VAR args: Object): Object;
		VAR val: Object;
	BEGIN
		val := Arg(ctxt, args);
		IF Scheme.IsNumber(val) THEN RETURN val
		ELSE Scheme.Fail(ctxt, "argument must be number", val); RETURN Scheme.zero
		END
	END NumArg;

	PROCEDURE NumVal* (ctxt: Scheme.Context; VAR args: Object): FLOAT64;
		VAR r: FLOAT64;
	BEGIN
		Scheme.GetReal(NumArg(ctxt, args), r); RETURN r
	END NumVal;

	PROCEDURE CharArg* (ctxt: Scheme.Context; VAR args: Object): Object;
		VAR val: Object;
	BEGIN
		val := Arg(ctxt, args);
		IF Scheme.IsChar(val) THEN RETURN val
		ELSE Scheme.Fail(ctxt, "argument must be character", val); RETURN Scheme.NewChar(" ")
		END
	END CharArg;

	PROCEDURE CharVal* (ctxt: Scheme.Context; VAR args: Object): CHAR;
	BEGIN
		RETURN Scheme.CharValue(CharArg(ctxt, args))
	END CharVal;

	PROCEDURE StringArg* (ctxt: Scheme.Context; VAR args: Object): Object;
		VAR val: Object;
	BEGIN
		val := Arg(ctxt, args);
		IF Scheme.IsString(val) THEN RETURN val
		ELSE Scheme.Fail(ctxt, "argument must be string", val); RETURN Scheme.NewLiteral("", ctxt.pool)
		END
	END StringArg;

	PROCEDURE ProcArg* (ctxt: Scheme.Context; VAR args: Object): Object;
		VAR val: Object;
	BEGIN
		val := Arg(ctxt, args);
		IF Scheme.IsProcedure(val) THEN RETURN val
		ELSE
			Scheme.Fail(ctxt, "argument must be procedure", val);
			RETURN Scheme.NewProcedure(Scheme.globals, Scheme.nil, Scheme.false)
		END
	END ProcArg;

	PROCEDURE SymbolArg* (ctxt: Scheme.Context; VAR args: Object): Object;
		VAR val: Object;
	BEGIN
		val := Arg(ctxt, args);
		IF Scheme.IsSymbol(val) THEN RETURN val
		ELSE Scheme.Fail(ctxt, "argument must be string", val); RETURN Scheme.NewSymbol("error")
		END
	END SymbolArg;

	PROCEDURE VectorArg* (ctxt: Scheme.Context; VAR args: Object): Object;
		VAR val: Object;
	BEGIN
		val := Arg(ctxt, args);
		IF Scheme.IsVector(val) THEN RETURN val
		ELSE Scheme.Fail(ctxt, "argument must be vector", val); RETURN Scheme.NewVector(0, Scheme.nil)
		END
	END VectorArg;

	PROCEDURE RefArg* (ctxt: Scheme.Context; VAR args: Object): Object;
		VAR val: Object;
	BEGIN
		val := Arg(ctxt, args);
		IF Scheme.IsReference(val) THEN RETURN val
		ELSE Scheme.Fail(ctxt, "argument must be object reference", val); RETURN Scheme.NewRef(NIL)
		END
	END RefArg;

	PROCEDURE RefVal* (ctxt: Scheme.Context; VAR args: Object): Objects.Object;
	BEGIN
		RETURN Scheme.RefValue(RefArg(ctxt, args))
	END RefVal;

	PROCEDURE InputArg (ctxt: Scheme.Context; VAR args: Object): Object;
		VAR obj: Object;
	BEGIN
		obj := Arg(ctxt, args);
		IF Scheme.IsPort(obj) & Scheme.IsInput(obj) THEN RETURN obj
		ELSE Scheme.Fail(ctxt, "argument must be input port", obj); RETURN ctxt.in
		END
	END InputArg;

	PROCEDURE OutputArg (ctxt: Scheme.Context; VAR args: Object): Object;
		VAR obj: Object;
	BEGIN
		obj := Arg(ctxt, args);
		IF Scheme.IsPort(obj) & Scheme.IsOutput(obj) THEN RETURN obj
		ELSE Scheme.Fail(ctxt, "argument must be output port", obj); RETURN ctxt.out
		END
	END OutputArg;


	(*--- Type Predicates ---*)

	PROCEDURE Predicate (ctxt: Context; args: Object; VAR res: Object; check: PROCEDURE(obj: Object): BOOLEAN);
		VAR obj: Object;
	BEGIN
		obj := Arg(ctxt, args); CheckNull(ctxt, args);
		IF check(obj) THEN res := Scheme.true
		ELSE res := Scheme.false
		END
	END Predicate;

	PROCEDURE IsBoolean (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsBool)
	END IsBoolean;

	PROCEDURE IsSymbol (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsSymbol)
	END IsSymbol;

	PROCEDURE IsChar (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsChar)
	END IsChar;

	PROCEDURE IsVector (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsVector)
	END IsVector;

	PROCEDURE IsPair (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsPair)
	END IsPair;

	PROCEDURE IsNumber (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsNumber)
	END IsNumber;

	PROCEDURE IsString (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsString)
	END IsString;

	PROCEDURE IsProcedure (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsProcedure)
	END IsProcedure;

	PROCEDURE IsPort (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsPort)
	END IsPort;

	PROCEDURE IsReference (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsReference)
	END IsReference;


	(*--- Equivalence ---*)

	PROCEDURE Eqv (ctxt: Context; args: Object; VAR res: Object);
		VAR obj1, obj2: Object;
	BEGIN
		obj1 := Arg(ctxt, args); obj2 := Arg(ctxt, args); CheckNull(ctxt, args);
		IF Scheme.Eqv(obj1, obj2) THEN res := Scheme.true
		ELSE res := Scheme.false
		END
	END Eqv;

	PROCEDURE Eq (ctxt: Context; args: Object; VAR res: Object);
		VAR obj1, obj2: Object;
	BEGIN
		obj1 := Arg(ctxt, args); obj2 := Arg(ctxt, args); CheckNull(ctxt, args);
		IF Scheme.Eq(obj1, obj2) THEN res := Scheme.true
		ELSE res := Scheme.false
		END
	END Eq;


	(*--- Numbers ---*)

	PROCEDURE IsComplex (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsComplex)
	END IsComplex;

	PROCEDURE IsReal (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsReal)
	END IsReal;

	PROCEDURE IsRational (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsRational)
	END IsRational;

	PROCEDURE IsInteger (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsInteger)
	END IsInteger;

	PROCEDURE IsExact (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsExact)
	END IsExact;

	PROCEDURE IsInexact (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsInexact)
	END IsInexact;

	PROCEDURE Compare (ctxt: Context; args: Object; test: PROCEDURE (p, q: Object): BOOLEAN; VAR res: Object);
		VAR q, p: Object;
	BEGIN
		res := Scheme.true; q := NumArg(ctxt, args);
		REPEAT
			p := q; q := NumArg(ctxt, args);
			IF ~test(p, q) THEN
				res := Scheme.false
			END
		UNTIL ctxt.failed OR Scheme.IsNull(args)
	END Compare;

	PROCEDURE LessTest (p, q: Object): BOOLEAN;
	BEGIN RETURN Scheme.Compare(p, q) < 0 END LessTest;

	PROCEDURE Less (ctxt: Context; args: Object; VAR res: Object);
	BEGIN Compare(ctxt, args, LessTest, res) END Less;

	PROCEDURE LessEqTest (p, q: Object): BOOLEAN;
	BEGIN RETURN Scheme.Compare(p, q) <= 0 END LessEqTest;

	PROCEDURE LessEq (ctxt: Context; args: Object; VAR res: Object);
	BEGIN Compare(ctxt, args, LessEqTest, res) END LessEq;

	PROCEDURE GreaterTest (p, q: Object): BOOLEAN;
	BEGIN RETURN Scheme.Compare(p, q) > 0 END GreaterTest;

	PROCEDURE Greater (ctxt: Context; args: Object; VAR res: Object);
	BEGIN Compare(ctxt, args, GreaterTest, res) END Greater;

	PROCEDURE GreaterEqTest (p, q: Object): BOOLEAN;
	BEGIN RETURN Scheme.Compare(p, q) >= 0 END GreaterEqTest;

	PROCEDURE GreaterEq (ctxt: Context; args: Object; VAR res: Object);
	BEGIN Compare(ctxt, args, GreaterEqTest, res) END GreaterEq;

	PROCEDURE NumEqTest (p, q: Object): BOOLEAN;
	BEGIN RETURN Scheme.Compare(p, q) = 0 END NumEqTest;

	PROCEDURE NumEq (ctxt: Context; args: Object; VAR res: Object);
	BEGIN Compare(ctxt, args, NumEqTest, res) END NumEq;

	PROCEDURE Plus (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.zero;
		WHILE ~ctxt.failed & ~Scheme.IsNull(args) DO
			res := Scheme.Add(res, NumArg(ctxt, args))
		END
	END Plus;

	PROCEDURE Minus (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := NumArg(ctxt, args);
		IF Scheme.IsNull(args) THEN res := Scheme.Neg(res)
		ELSE
			REPEAT
				res := Scheme.Sub(res, NumArg(ctxt, args))
			UNTIL ctxt.failed OR Scheme.IsNull(args)
		END
	END Minus;

	PROCEDURE Mul (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.one;
		WHILE ~ctxt.failed & ~Scheme.IsNull(args) DO
			res := Scheme.Mul(res, NumArg(ctxt, args))
		END
	END Mul;

	PROCEDURE Div (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := NumArg(ctxt, args);
		IF Scheme.IsNull(args) THEN res := Scheme.Inv(res)
		ELSE
			REPEAT
				res := Scheme.Div(res, NumArg(ctxt, args))
			UNTIL ctxt.failed OR Scheme.IsNull(args)
		END
	END Div;

	PROCEDURE Quotient (ctxt: Context; args: Object; VAR res: Object);
		VAR n, d, q, r, m: Object;
	BEGIN
		n := NumArg(ctxt, args); d := NumArg(ctxt, args); CheckNull(ctxt, args);
		Scheme.Quotient(n, d, q, r, m); res := q
	END Quotient;

	PROCEDURE Remainder (ctxt: Context; args: Object; VAR res: Object);
		VAR n, d, q, r, m: Object;
	BEGIN
		n := NumArg(ctxt, args); d := NumArg(ctxt, args); CheckNull(ctxt, args);
		Scheme.Quotient(n, d, q, r, m); res := r
	END Remainder;

	PROCEDURE Modulo (ctxt: Context; args: Object; VAR res: Object);
		VAR n, d, q, r, m: Object;
	BEGIN
		n := NumArg(ctxt, args); d := NumArg(ctxt, args); CheckNull(ctxt, args);
		Scheme.Quotient(n, d, q, r, m); res := m
	END Modulo;

	PROCEDURE Denominator (ctxt: Context; args: Object; VAR res: Object);
		VAR n, d: SIGNED32; exact: BOOLEAN;
	BEGIN
		Scheme.GetRational(NumArg(ctxt, args), n, d, exact); CheckNull(ctxt, args);
		IF exact THEN res := Scheme.NewInteger(d)
		ELSE res := Scheme.NewReal(d)
		END
	END Denominator;

	PROCEDURE Numerator (ctxt: Context; args: Object; VAR res: Object);
		VAR n, d: SIGNED32; exact: BOOLEAN;
	BEGIN
		Scheme.GetRational(NumArg(ctxt, args), n, d, exact); CheckNull(ctxt, args);
		IF exact THEN res := Scheme.NewInteger(n)
		ELSE res := Scheme.NewReal(n)
		END
	END Numerator;

	PROCEDURE Floor (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.Floor(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END Floor;

	PROCEDURE Ceiling (ctxt: Context; args: Object; VAR res: Object);
		VAR x: Object;
	BEGIN
		x := NumArg(ctxt, args); CheckNull(ctxt, args);
		res := Scheme.Neg(Scheme.Floor(Scheme.Neg(x)))
	END Ceiling;

	PROCEDURE Truncate (ctxt: Context; args: Object; VAR res: Object);
		VAR x: Object;
	BEGIN
		x := NumArg(ctxt, args); CheckNull(ctxt, args);
		IF Scheme.Compare(x, Scheme.zero) > 0 THEN res := Scheme.Floor(x)
		ELSE res := Scheme.Neg(Scheme.Floor(Scheme.Neg(x)))
		END
	END Truncate;

	PROCEDURE Round (ctxt: Context; args: Object; VAR res: Object);
		VAR x: Object;
	BEGIN
		x := NumArg(ctxt, args); CheckNull(ctxt, args);
		res := Scheme.Floor(Scheme.Add(x, Scheme.NewRational(1, 2)))
	END Round;

	PROCEDURE Rationalize (ctxt: Context; args: Object; VAR res: Object);
		VAR x, y: Object;
	BEGIN
		x := NumArg(ctxt, args); y := NumArg(ctxt, args); CheckNull(ctxt, args);
		res := Scheme.Rationalize(x, y)
	END Rationalize;

	PROCEDURE Sqrt (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.Sqrt(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END Sqrt;

	PROCEDURE Exp (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.Exp(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END Exp;

	PROCEDURE Log (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.Ln(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END Log;

	PROCEDURE Expt (ctxt: Context; args: Object; VAR res: Object);
		VAR base, exp: Object;
	BEGIN
		base := NumArg(ctxt, args); exp := NumArg(ctxt, args); CheckNull(ctxt, args);
		res := Scheme.Expt(base, exp)
	END Expt;

	PROCEDURE Sin (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.Sin(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END Sin;

	PROCEDURE ASin (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.ASin(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END ASin;

	PROCEDURE Cos (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.Cos(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END Cos;

	PROCEDURE ACos (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.ACos(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END ACos;

	PROCEDURE Tan (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.Tan(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END Tan;

	PROCEDURE Atan (ctxt: Context; args: Object; VAR res: Object);
		VAR y: Object;
	BEGIN
		y := NumArg(ctxt, args);
		IF Scheme.IsNull(args) THEN res := Scheme.ATan(y)
		ELSE res := Scheme.ATan2(NumArg(ctxt, args), y); CheckNull(ctxt, args)
		END
	END Atan;

	PROCEDURE ExactToInexact (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.ToInexact(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END ExactToInexact;

	PROCEDURE InexactToExact (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.ToExact(NumArg(ctxt, args)); CheckNull(ctxt, args)
	END InexactToExact;

	PROCEDURE NumberToString (ctxt: Context; args: Object; VAR res: Object);
		VAR obj: Object; radix: SIGNED32;
	BEGIN
		obj := NumArg(ctxt, args); radix := 10;
		IF Scheme.IsPair(args) THEN
			radix := IntVal(ctxt, args);
			IF (radix # 2) & (radix # 8) & (radix # 10) & (radix # 16) THEN
				Scheme.Fail(ctxt, "radix must be 2, 8, 10, or 16", Scheme.NewInteger(radix))
			END
		END;
		CheckNull(ctxt, args);
		res := Scheme.NumberToString(obj, radix, ctxt.pool)
	END NumberToString;

	PROCEDURE StringToNumber (ctxt: Context; args: Object; VAR res: Object);
		VAR obj: Object; radix: SIGNED32;
	BEGIN
		obj := StringArg(ctxt, args); radix := 10;
		IF Scheme.IsPair(args) THEN
			radix := IntVal(ctxt, args);
			IF (radix # 2) & (radix # 8) & (radix # 10) & (radix # 16) THEN
				Scheme.Fail(ctxt, "radix must be 2, 8, 10, or 16", Scheme.NewInteger(radix))
			END
		END;
		CheckNull(ctxt, args);
		res := Scheme.StringToNumber(obj, radix)
	END StringToNumber;


	(*--- Pairs & Lists ---*)

	PROCEDURE Cons (ctxt: Context; args: Object; VAR res: Object);
		VAR car, cdr: Object;
	BEGIN
		car := Arg(ctxt, args); cdr := Arg(ctxt, args); CheckNull(ctxt, args);
		res := Scheme.NewPair(car, cdr)
	END Cons;

	PROCEDURE Car (ctxt: Context; args: Object; VAR res: Object);
		VAR p: Object;
	BEGIN
		p := Arg(ctxt, args); CheckNull(ctxt, args);
		IF Scheme.IsPair(p) THEN res := Scheme.Car(p)
		ELSE Scheme.Fail(ctxt, "argument must be pair", p)
		END
	END Car;

	PROCEDURE Cdr (ctxt: Context; args: Object; VAR res: Object);
		VAR p: Object;
	BEGIN
		p := Arg(ctxt, args); CheckNull(ctxt, args);
		IF Scheme.IsPair(p) THEN res := Scheme.Cdr(p)
		ELSE Scheme.Fail(ctxt, "argument must be pair", p)
		END
	END Cdr;

	PROCEDURE SetCar (ctxt: Context; args: Object; VAR res: Object);
		VAR p, obj: Object;
	BEGIN
		p := Arg(ctxt, args); obj := Arg(ctxt, args); CheckNull(ctxt, args);
		IF Scheme.IsPair(p) THEN Scheme.SetCar(p, obj)
		ELSE Scheme.Fail(ctxt, "argument must be pair", p)
		END
	END SetCar;

	PROCEDURE SetCdr (ctxt: Context; args: Object; VAR res: Object);
		VAR p, obj: Object;
	BEGIN
		p := Arg(ctxt, args); obj := Arg(ctxt, args); CheckNull(ctxt, args);
		IF Scheme.IsPair(p) THEN Scheme.SetCdr(p, obj)
		ELSE Scheme.Fail(ctxt, "argument must be pair", p)
		END
	END SetCdr;


	(*--- Symbols ---*)

	PROCEDURE SymbolToString (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.SymbolToString(SymbolArg(ctxt, args)); CheckNull(ctxt, args)
	END SymbolToString;

	PROCEDURE StringToSymbol (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.StringToSymbol(StringArg(ctxt, args)); CheckNull(ctxt, args)
	END StringToSymbol;


	(*--- Characters ---*)

	PROCEDURE CharEq (ctxt: Context; args: Object; VAR res: Object);
		VAR x, y: CHAR;
	BEGIN
		x := CharVal(ctxt, args); y := CharVal(ctxt, args); CheckNull(ctxt, args);
		IF x = y THEN res := Scheme.true ELSE res := Scheme.false END
	END CharEq;

	PROCEDURE CharLt (ctxt: Context; args: Object; VAR res: Object);
		VAR x, y: CHAR;
	BEGIN
		x := CharVal(ctxt, args); y := CharVal(ctxt, args); CheckNull(ctxt, args);
		IF x < y THEN res := Scheme.true ELSE res := Scheme.false END
	END CharLt;

	PROCEDURE CharGt (ctxt: Context; args: Object; VAR res: Object);
		VAR x, y: CHAR;
	BEGIN
		x := CharVal(ctxt, args); y := CharVal(ctxt, args); CheckNull(ctxt, args);
		IF x > y THEN res := Scheme.true ELSE res := Scheme.false END
	END CharGt;

	PROCEDURE CharLeq (ctxt: Context; args: Object; VAR res: Object);
		VAR x, y: CHAR;
	BEGIN
		x := CharVal(ctxt, args); y := CharVal(ctxt, args); CheckNull(ctxt, args);
		IF x <= y THEN res := Scheme.true ELSE res := Scheme.false END
	END CharLeq;

	PROCEDURE CharGeq (ctxt: Context; args: Object; VAR res: Object);
		VAR x, y: CHAR;
	BEGIN
		x := CharVal(ctxt, args); y := CharVal(ctxt, args); CheckNull(ctxt, args);
		IF x >= y THEN res := Scheme.true ELSE res := Scheme.false END
	END CharGeq;

	PROCEDURE CharToInt (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.NewInteger(ORD(CharVal(ctxt, args))); CheckNull(ctxt, args)
	END CharToInt;

	PROCEDURE IntToChar (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		res := Scheme.NewChar(CHR(IntVal(ctxt, args) MOD 100H)); CheckNull(ctxt, args)
	END IntToChar;


	(*--- Strings ---*)

	PROCEDURE MakeString (ctxt: Context; args: Object; VAR res: Object);
		VAR len: SIGNED32; fill: CHAR;
	BEGIN
		len := IntVal(ctxt, args); fill := 0X;
		IF Scheme.IsPair(args) THEN fill := CharVal(ctxt, args) END;
		CheckNull(ctxt, args);
		IF len < 0 THEN Scheme.Fail(ctxt, "invalid string length", Scheme.NewInteger(len))
		ELSE res := Scheme.NewString(len, fill, ctxt.pool)
		END
	END MakeString;

	PROCEDURE StringLength (ctxt: Context; args: Object; VAR res: Object);
		VAR s: Object;
	BEGIN
		s := StringArg(ctxt, args); CheckNull(ctxt, args);
		res := Scheme.NewInteger(Scheme.StringLen(s))
	END StringLength;

	PROCEDURE StringRef (ctxt: Context; args: Object; VAR res: Object);
		VAR s: Object; idx: SIGNED32; ch: ARRAY 2 OF CHAR;
	BEGIN
		s := StringArg(ctxt, args); idx := IntVal(ctxt, args); CheckNull(ctxt, args);
		IF (0 <= idx) & (idx < Scheme.StringLen(s)) THEN Scheme.GetString(s, idx, 1, ch); res := Scheme.NewChar(ch[0])
		ELSE Scheme.Fail(ctxt, "index out of range", Scheme.NewInteger(idx))
		END
	END StringRef;

	PROCEDURE StringSet (ctxt: Context; args: Object; VAR res: Object);
		VAR s: Object; idx: SIGNED32; ch: ARRAY 2 OF CHAR;
	BEGIN
		s := StringArg(ctxt, args); idx := IntVal(ctxt, args); ch[0] := CharVal(ctxt, args); CheckNull(ctxt, args);
		IF (0 <= idx) & (idx < Scheme.StringLen(s)) THEN Scheme.SetString(s, idx, 1, ch); res := s
		ELSE Scheme.Fail(ctxt, "index out of range", Scheme.NewInteger(idx))
		END
	END StringSet;


	(*--- Vectors ---*)

	PROCEDURE MakeVector (ctxt: Context; args: Object; VAR res: Object);
		VAR n: SIGNED32; fill: Object;
	BEGIN
		n := IntVal(ctxt, args);
		IF Scheme.IsPair(args) THEN fill := Arg(ctxt, args) ELSE fill := Scheme.nil END;
		CheckNull(ctxt, args);
		IF n >= 0 THEN res := Scheme.NewVector(n, fill)
		ELSE Scheme.Fail(ctxt, "illegal vector size", Scheme.NewInteger(n))
		END
	END MakeVector;

	PROCEDURE VectorLength (ctxt: Context; args: Object; VAR res: Object);
		VAR vec: Object;
	BEGIN
		vec := VectorArg(ctxt, args); CheckNull(ctxt, args);
		res := Scheme.NewInteger(Scheme.VectorLen(vec))
	END VectorLength;

	PROCEDURE VectorRef (ctxt: Context; args: Object; VAR res: Object);
		VAR vec: Object; idx: SIGNED32;
	BEGIN
		vec := VectorArg(ctxt, args); idx := IntVal(ctxt, args); CheckNull(ctxt, args);
		IF (0 <= idx) & (idx < Scheme.VectorLen(vec)) THEN res := Scheme.VectorAt(vec, idx)
		ELSE Scheme.Fail(ctxt, "index out of range", Scheme.NewInteger(idx))
		END
	END VectorRef;

	PROCEDURE VectorSet (ctxt: Context; args: Object; VAR res: Object);
		VAR vec, val: Object; idx: SIGNED32;
	BEGIN
		vec := VectorArg(ctxt, args); idx := IntVal(ctxt, args); val := Arg(ctxt, args); CheckNull(ctxt, args);
		IF (0 <= idx) & (idx < Scheme.VectorLen(vec)) THEN Scheme.SetVectorAt(vec, idx, val); res := vec
		ELSE Scheme.Fail(ctxt, "index out of range", Scheme.NewInteger(idx))
		END
	END VectorSet;


	(*--- Procedures ---*)

	PROCEDURE Apply (ctxt: Context; args: Object; VAR res: Object);
		VAR proc, obj, list, last: Object;
	BEGIN
		proc := ProcArg(ctxt, args); obj := Arg(ctxt, args);
		IF Scheme.IsNull(args) THEN
			IF Scheme.IsPair(obj) THEN list := obj
			ELSE Scheme.Fail(ctxt, "last argument to 'apply' must be list", obj)
			END
		ELSE
			list := Scheme.NewPair(obj, Scheme.nil); last := list; obj := Arg(ctxt, args);
			WHILE Scheme.IsPair(args) DO
				Scheme.SetCdr(last, Scheme.NewPair(obj, Scheme.nil)); last := Scheme.Cdr(last);
				obj := Arg(ctxt, args)
			END;
			IF Scheme.IsPair(obj) THEN Scheme.SetCdr(last, obj)
			ELSE Scheme.Fail(ctxt, "last argument to 'apply' must be list", obj)
			END;
			CheckNull(ctxt, args)
		END;
		Scheme.Call(ctxt, proc, list)
	END Apply;


	(*--- Ports ---*)

	PROCEDURE InputPort (ctxt: Context; args: Object; VAR res: Object);
		VAR obj: Object;
	BEGIN
		obj := Arg(ctxt, args); CheckNull(ctxt, args);
		IF Scheme.IsPort(obj) & Scheme.IsInput(obj) THEN res := Scheme.true
		ELSE res := Scheme.false
		END
	END InputPort;

	PROCEDURE OutputPort (ctxt: Context; args: Object; VAR res: Object);
		VAR obj: Object;
	BEGIN
		obj := Arg(ctxt, args); CheckNull(ctxt, args);
		IF Scheme.IsPort(obj) & Scheme.IsOutput(obj) THEN res := Scheme.true
		ELSE res := Scheme.false
		END
	END OutputPort;

	PROCEDURE CurrentInputPort (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		CheckNull(ctxt, args); res := ctxt.in
	END CurrentInputPort;

	PROCEDURE CurrentOutputPort (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		CheckNull(ctxt, args); res := ctxt.out
	END CurrentOutputPort;

	PROCEDURE WithInputFromFile (ctxt: Context; args: Object; VAR res: Object);
		VAR str, thunk, in: Object; name: ARRAY 64 OF CHAR; text: Texts.Text;
	BEGIN
		str := StringArg(ctxt, args); thunk := ProcArg(ctxt, args); CheckNull(ctxt, args);
		Scheme.GetString(str, 0, Scheme.StringLen(str), name);
		NEW(text); Texts.Open(text, name);
		IF text.len # 0 THEN
			in := ctxt.in; ctxt.in := Scheme.NewTextInput(text, 0);
			Scheme.Call(ctxt, thunk, Scheme.nil);
			Scheme.CloseInput(ctxt.in);
			ctxt.in := in
		ELSE Scheme.Fail(ctxt, "cannot open input file", str)
		END
	END WithInputFromFile;

	PROCEDURE WithOutputToFile (ctxt: Context; args: Object; VAR res: Object);
		VAR str, thunk, out: Object; name: ARRAY 64 OF CHAR; file: Files.File;
	BEGIN
		str := StringArg(ctxt, args); thunk := ProcArg(ctxt, args); CheckNull(ctxt, args);
		Scheme.GetString(str, 0, Scheme.StringLen(str), name);
		file := Files.New(name);
		IF file # NIL THEN
			out := ctxt.out; ctxt.out := Scheme.NewFileOutput(file);
			Scheme.Call(ctxt, thunk, Scheme.nil);
			Scheme.CloseOutput(ctxt.out);
			ctxt.out := out
		ELSE Scheme.Fail(ctxt, "cannot open output file", str)
		END
	END WithOutputToFile;

	PROCEDURE OpenInputFile (ctxt: Context; args: Object; VAR res: Object);
		VAR str: Object; name: ARRAY 64 OF CHAR; text: Texts.Text;
	BEGIN
		str := StringArg(ctxt, args); CheckNull(ctxt, args);
		Scheme.GetString(str, 0, Scheme.StringLen(str), name);
		NEW(text); Texts.Open(text, name);
		IF text.len # 0 THEN res := Scheme.NewTextInput(text, 0)
		ELSE Scheme.Fail(ctxt, "cannot open input file", str)
		END
	END OpenInputFile;

	PROCEDURE OpenOutputFile (ctxt: Context; args: Object; VAR res: Object);
		VAR str: Object; name: ARRAY 64 OF CHAR; file: Files.File;
	BEGIN
		str := StringArg(ctxt, args); CheckNull(ctxt, args);
		Scheme.GetString(str, 0, Scheme.StringLen(str), name);
		file := Files.New(name);
		IF file # NIL THEN res := Scheme.NewFileOutput(file)
		ELSE Scheme.Fail(ctxt, "cannot open input file", str)
		END
	END OpenOutputFile;

	PROCEDURE CloseInputPort (ctxt: Context; args: Object; VAR res: Object);
		VAR obj: Object;
	BEGIN
		obj := InputArg(ctxt, args); CheckNull(ctxt, args);
		Scheme.CloseInput(obj)
	END CloseInputPort;

	PROCEDURE CloseOutputPort (ctxt: Context; args: Object; VAR res: Object);
		VAR obj: Object;
	BEGIN
		obj := OutputArg(ctxt, args); CheckNull(ctxt, args);
		Scheme.CloseOutput(obj)
	END CloseOutputPort;

	PROCEDURE Read (ctxt: Context; args: Object; VAR res: Object);
		VAR in: Object;
	BEGIN
		in := ctxt.in;
		IF Scheme.IsPair(args) THEN ctxt.in := InputArg(ctxt, args) END;
		CheckNull(ctxt, args);
		res := Scheme.Read(ctxt);
		ctxt.in := in
	END Read;

	PROCEDURE ReadChar (ctxt: Context; args: Object; VAR res: Object);
		VAR in: Object; ch: CHAR;
	BEGIN
		IF Scheme.IsPair(args) THEN in := InputArg(ctxt, args)
		ELSE in := ctxt.in
		END;
		CheckNull(ctxt, args);
		Scheme.ReadCh(in, ch);
		IF Scheme.Eof(in) THEN res := Scheme.EOF
		ELSE res := Scheme.NewChar(ch)
		END
	END ReadChar;

	PROCEDURE PeekChar (ctxt: Context; args: Object; VAR res: Object);
		VAR in: Object; ch: CHAR;
	BEGIN
		IF Scheme.IsPair(args) THEN in := InputArg(ctxt, args)
		ELSE in := ctxt.in
		END;
		CheckNull(ctxt, args);
		IF Scheme.PeekCh(in, ch) THEN res := Scheme.NewChar(ch)
		ELSE res := Scheme.EOF
		END
	END PeekChar;

	PROCEDURE IsEof (ctxt: Context; args: Object; VAR res: Object);
	BEGIN
		Predicate(ctxt, args, res, Scheme.IsEof)
	END IsEof;

	PROCEDURE CharReady (ctxt: Context; args: Object; VAR res: Object);
		VAR in: Object;
	BEGIN
		IF Scheme.IsPair(args) THEN in := InputArg(ctxt, args)
		ELSE in := ctxt.in
		END;
		CheckNull(ctxt, args);
		IF Scheme.Ready(in) THEN res := Scheme.true
		ELSE res := Scheme.false
		END
	END CharReady;

	PROCEDURE Write (ctxt: Context; args: Object; VAR res: Object);
		VAR obj, out: Object;
	BEGIN
		obj := Arg(ctxt, args);
		IF Scheme.IsPair(args) THEN out := OutputArg(ctxt, args)
		ELSE out := ctxt.out
		END;
		CheckNull(ctxt, args);
		Scheme.WriteObj(out, obj)
	END Write;

	PROCEDURE WriteChar (ctxt: Context; args: Object; VAR res: Object);
		VAR ch: CHAR; out: Object;
	BEGIN
		ch := CharVal(ctxt, args);
		IF Scheme.IsPair(args) THEN out := OutputArg(ctxt, args)
		ELSE out := ctxt.out
		END;
		CheckNull(ctxt, args);
		Scheme.Write(out, ch);
		IF ch = Scheme.newline THEN
			Scheme.Flush(out)
		END
	END WriteChar;

	PROCEDURE Load (ctxt: Context; args: Object; VAR res: Object);
		VAR obj: Object; s: ARRAY 64 OF CHAR; txt: Texts.Text;
	BEGIN
		obj := StringArg(ctxt, args); CheckNull(ctxt, args);
		Scheme.GetString(obj, 0, Scheme.StringLen(obj), s);
		NEW(txt); Texts.Open(txt, s);
		IF txt.len # 0 THEN
			Scheme.Load(ctxt, Scheme.NewTextInput(txt, 0))
		END
	END Load;


	(*--- References ---*)

	PROCEDURE New (c: Context; args: Object; VAR res: Object);
		VAR str: Object; s: ARRAY 64 OF CHAR;
	BEGIN
		str := StringArg(c, args); CheckNull(c, args);
		Scheme.GetString(str, 0, Scheme.StringLen(str), s);
		res := Scheme.NewRef(Gadgets.CreateObject(s))
	END New;

	PROCEDURE LibObj (c: Context; args: Object; VAR res: Object);
		VAR str: Object; lname, oname: ARRAY 32 OF CHAR; lib: Objects.Library; obj: Objects.Object; ref: SIGNED16;
	BEGIN
		str := StringArg(c, args); Scheme.GetString(str, 0, Scheme.StringLen(str), lname);
		str := StringArg(c, args); Scheme.GetString(str, 0, Scheme.StringLen(str), oname);
		Strings.Append(lname, ".Lib");
		CheckNull(c, args);
		lib := Objects.ThisLibrary(lname); obj := NIL;
		IF lib # NIL THEN
			Objects.GetRef(lib.dict, oname, ref);
			IF ref # MIN(SIGNED16) THEN
				lib.GetObj(lib, ref, obj)
			END
		END;
		res := Scheme.NewRef(obj)
	END LibObj;

	PROCEDURE Copy (c: Context; args: Object; VAR res: Object);
		VAR obj: Objects.Object; deep: BOOLEAN; cm: Objects.CopyMsg;
	BEGIN
		obj := RefVal(c, args);
		IF Scheme.IsPair(args) THEN deep := BoolVal(c, args)
		ELSE deep := FALSE
		END;
		CheckNull(c, args);
		Objects.Stamp(cm); cm.obj := NIL;
		IF deep THEN cm.id := Objects.deep ELSE cm.id := Objects.shallow END;
		IF obj # NIL THEN obj.handle(obj, cm) END;
		res := Scheme.NewRef(cm.obj)
	END Copy;

	PROCEDURE Attr (c: Context; args: Object; VAR res: Object);
		VAR ref: Objects.Object; str: Object; am: Objects.AttrMsg;
	BEGIN
		ref := RefVal(c, args); str := StringArg(c, args); CheckNull(c, args);
		IF ref = NIL THEN res := Scheme.NewRef(NIL)
		ELSE
			am.id := Objects.get; Scheme.GetString(str, 0, Scheme.StringLen(str), am.name); am.class := Objects.Inval; am.res := -1;
			ref.handle(ref, am);
			CASE am.class OF
			| Objects.Bool: IF am.b THEN res := Scheme.true ELSE res := Scheme.false END
			| Objects.Int: res := Scheme.NewInteger(am.i)
			| Objects.Real: res := Scheme.NewReal(am.x)
			| Objects.LongReal: res := Scheme.NewReal(am.y)
			| Objects.Char: res := Scheme.NewChar(am.c)
			| Objects.String: res := Scheme.NewLiteral(am.s, c.pool)
			ELSE res := Scheme.nil
			END
		END
	END Attr;

	PROCEDURE SetAttr (c: Context; args: Object; VAR res: Object);
		VAR ref: Objects.Object; str, val: Object; am: Objects.AttrMsg; exact: BOOLEAN;
	BEGIN
		IF Scheme.IsPair(args) THEN res := Scheme.Car(args) ELSE res := Scheme.NewRef(NIL) END;
		ref := RefVal(c, args);
		IF ref = NIL THEN Scheme.Fail(c, "NIL reference", args)
		ELSE
			REPEAT
				str := StringArg(c, args); val := Arg(c, args);
				am.id := Objects.set; Scheme.GetString(str, 0, Scheme.StringLen(str), am.name); am.res := -1;
				IF Scheme.IsBool(val) THEN am.class := Objects.Bool; am.b := Scheme.BoolValue(val)
				ELSIF Scheme.IsInteger(val) THEN am.class := Objects.Int; Scheme.GetInteger(val, am.i, exact)
				ELSIF Scheme.IsReal(val) THEN
					am.class := Objects.LongReal; Scheme.GetReal(val, am.y); ref.handle(ref, am);
					am.class := Objects.Real; am.x := SHORT(am.y)
				ELSIF Scheme.IsChar(val) THEN am.class := Objects.Char; am.c := Scheme.CharValue(val)
				ELSIF Scheme.IsString(val) THEN am.class := Objects.String; Scheme.GetString(val, 0, Scheme.StringLen(val), am.s)
				ELSE
					Scheme.WriteStr(c.err, "invalid type for attribute '"); Scheme.WriteObj(c.err, str);
					Scheme.Write(c.err, "'"); Scheme.Write(c.err, Scheme.newline); Scheme.Flush(c.err);
					am.res := 0
				END;
				IF am.res < 0 THEN ref.handle(ref, am) END;
				IF am.res < 0 THEN
					Scheme.WriteStr(c.err, "cannot set attribute '"); Scheme.WriteObj(c.err, str);
					Scheme.Write(c.err, "'"); Scheme.Write(c.err, Scheme.newline); Scheme.Flush(c.err)
				END
			UNTIL c.failed OR ~Scheme.IsPair(args)
		END
	END SetAttr;

	PROCEDURE Link (c: Context; args: Object; VAR res: Object);
		VAR ref: Objects.Object; str: Object; lm: Objects.LinkMsg;
	BEGIN
		ref := RefVal(c, args); str := StringArg(c, args); CheckNull(c, args);
		IF ref = NIL THEN res := Scheme.NewRef(NIL)
		ELSE
			lm.id := Objects.get; Scheme.GetString(str, 0, Scheme.StringLen(str), lm.name); lm.res := -1;
			ref.handle(ref, lm);
			IF lm.res >= 0 THEN res := Scheme.NewRef(lm.obj)
			ELSE res := Scheme.NewRef(NIL)
			END
		END
	END Link;

	PROCEDURE SetLink (c: Context; args: Object; VAR res: Object);
		VAR ref, link: Objects.Object; str: Object; lm: Objects.LinkMsg;
	BEGIN
		IF Scheme.IsPair(args) THEN res := Scheme.Car(args) ELSE res := Scheme.NewRef(NIL) END;
		ref := RefVal(c, args);
		IF ref = NIL THEN Scheme.Fail(c, "NIL reference", args)
		ELSE
			REPEAT
				str := StringArg(c, args); link := RefVal(c, args);
				lm.id := Objects.set; Scheme.GetString(str, 0, Scheme.StringLen(str), lm.name); lm.obj := link; lm.res := -1;
				ref.handle(ref, lm);
				IF lm.res < 0 THEN
					Scheme.WriteStr(c.err, "cannot set link '"); Scheme.WriteObj(c.err, str);
					Scheme.Write(c.err, "'"); Scheme.Write(c.err, Scheme.newline); Scheme.Flush(c.err)
				END
			UNTIL c.failed OR ~Scheme.IsPair(args)
		END
	END SetLink;


	(*--- Initialization ---*)

	PROCEDURE Init;
	BEGIN
		Scheme.Def("boolean?", IsBoolean); Scheme.Def("symbol?", IsSymbol); Scheme.Def("char?", IsChar);
		Scheme.Def("vector?", IsVector); Scheme.Def("pair?", IsPair); Scheme.Def("number?", IsNumber);
		Scheme.Def("string?", IsString); Scheme.Def("procedure?", IsProcedure); Scheme.Def("port?", IsPort);
		Scheme.Def("reference?", IsReference);

		Scheme.Def("eqv?", Eqv); Scheme.Def("eq?", Eq);

		Scheme.Def("complex?", IsComplex); Scheme.Def("real?", IsReal); Scheme.Def("rational?", IsRational);
		Scheme.Def("integer?", IsInteger); Scheme.Def("exact?", IsExact); Scheme.Def("inexact?", IsInexact);
		Scheme.Def("=", NumEq); Scheme.Def("<", Less); Scheme.Def(">", Greater);
		Scheme.Def("<=", LessEq); Scheme.Def(">=", GreaterEq);
		Scheme.Def("+", Plus); Scheme.Def("-", Minus); Scheme.Def("*", Mul); Scheme.Def("/", Div);
		Scheme.Def("quotient", Quotient); Scheme.Def("remainder", Remainder); Scheme.Def("modulo", Modulo);
		Scheme.Def("numerator", Numerator); Scheme.Def("denominator", Denominator);
		Scheme.Def("floor", Floor); Scheme.Def("ceiling", Ceiling); Scheme.Def("truncate", Truncate);
		Scheme.Def("round", Round); Scheme.Def("rationalize", Rationalize);
		Scheme.Def("sqrt", Sqrt); Scheme.Def("exp", Exp); Scheme.Def("log", Log); Scheme.Def("expt", Expt);
		Scheme.Def("sin", Sin); Scheme.Def("asin", ASin); Scheme.Def("cos", Cos); Scheme.Def("acos", ACos);
		Scheme.Def("tan", Tan); Scheme.Def("atan", Atan);
		Scheme.Def("exact->inexact", ExactToInexact); Scheme.Def("inexact->exact", InexactToExact);
		Scheme.Def("number->string", NumberToString); Scheme.Def("string->number", StringToNumber);

		Scheme.Def("cons", Cons); Scheme.Def("car", Car); Scheme.Def("cdr", Cdr);
		Scheme.Def("set-car!", SetCar); Scheme.Def("set-cdr!", SetCdr);

		Scheme.Def("symbol->string", SymbolToString); Scheme.Def("string->symbol", StringToSymbol);

		Scheme.Def("char=?", CharEq); Scheme.Def("char<?", CharLt); Scheme.Def("char>?", CharGt);
		Scheme.Def("char<=?", CharLeq); Scheme.Def("char>=?", CharGeq);
		Scheme.Def("char->integer", CharToInt); Scheme.Def("integer->char", IntToChar);

		Scheme.Def("make-string", MakeString); Scheme.Def("string-length", StringLength);
		Scheme.Def("string-ref", StringRef); Scheme.Def("string-set!", StringSet);

		Scheme.Def("make-vector", MakeVector); Scheme.Def("vector-length", VectorLength);
		Scheme.Def("vector-ref", VectorRef); Scheme.Def("vector-set!", VectorSet);

		Scheme.Def("apply", Apply);

		Scheme.Def("input-port?", InputPort); Scheme.Def("output-port?", OutputPort);
		Scheme.Def("current-input-port", CurrentInputPort); Scheme.Def("current-output-port", CurrentOutputPort);
		Scheme.Def("with-input-from-file", WithInputFromFile); Scheme.Def("with-output-to-file", WithOutputToFile);
		Scheme.Def("open-input-file", OpenInputFile); Scheme.Def("open-output-file", OpenOutputFile);
		Scheme.Def("close-input-port", CloseInputPort); Scheme.Def("close-output-port", CloseOutputPort);
		Scheme.Def("read", Read); Scheme.Def("read-char", ReadChar); Scheme.Def("peek-char", PeekChar);
		Scheme.Def("eof-object?", IsEof); Scheme.Def("char-ready?", CharReady);
		Scheme.Def("write", Write); Scheme.Def("write-char", WriteChar);
		Scheme.Def("load", Load);

		Scheme.Def("new", New); Scheme.Def("libobj", LibObj); Scheme.Def("copy", Copy);
		Scheme.Def("attr", Attr); Scheme.Def("set-attr!", SetAttr); Scheme.Def("link", Link); Scheme.Def("set-link!", SetLink)
	END Init;


BEGIN
	Init
END SchemeOps.
