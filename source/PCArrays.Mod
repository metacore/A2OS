MODULE PCArrays;   (**  AUTHOR "fof"; PURPOSE "";  **)
(*
Module to identify procedures implemented in the ArrayBase module associated to a monadic or dyadic operator <op> and types <left> (and <right>).
The procedures are identified by the operator name and types of left and right argument.
The following rules apply to procedures written in ArrayBase
1.) To each operator applying to a particular shape of the left (and possibly right) argument a name is assigned. Example:
	<array of any dimension> + <array of same dimension> ->  <array of same dimension>
	Say the name "Plus" is assigned to this "+" operator
2.) For each possible combination of base types a pattern is appended to the operator name. The default patterns are composed of the letters
	"A" for array or "S" for scalar values and "S","I","L","R","X" for the base types  shortint, integer, longint, real and longreal. In the example
	displayed above this would be "ASAS" for two shortint arrays, the name thus is
	"PlusASAS"
*)


IMPORT PCT, StringPool, PCS,  PCC (* for constants *) , PCM, Strings := UTF8Strings;

CONST
	abs = PCC.absfn;  minus = PCS.minus;  plus = PCS.plus;  times = PCS.times;
	mod = PCS.mod;  div = PCS.div;  elementproduct = PCS.elementproduct;
	elementquotient = PCS.elementquotient;  scalarproduct = PCS.scalarproduct;
	eql = PCS.eql;  neq = PCS.neq;  assign = PCS.becomes;
	transpose = PCS.transpose;  dtimes = PCS.dtimes;  copy* = 1024;  copy2*=1025;
	zerocopy* = 1026;  zerocopy2*=1027;  selfcopy*=1028; selfcopy2*=1029; incmul* = 1030; allocateTensor*=1031; incmule*=1032; decmul*=1033;

	eeql = PCS.eeql;  eneq = PCS.eneq;  elss = PCS.elss;
	eleq = PCS.eleq;  egtr = PCS.egtr;  egeq = PCS.egeq;  lss = PCS.lss;
	leq = PCS.leq;  gtr = PCS.gtr;  geq = PCS.geq;  or = PCS.or;  and = PCS.and;  not = PCS.not;
	lenfn* = 154;  (* must be consistent with constants in PCB *)
	maxfn* = 148; minfn* = 149;
	incrfn* = 176;  swapfn* = 177;  convert* = 178;
	applyaop* = 179;  sumfn* = 180;  dimfn* = 181;
	reshapefn* = 182;  incrfnA*=183; lenfnA*=184; shallowcopyfn*= 185;


	ArrayModuleName = "ArrayBase";

	anydim=MAX(SIGNED32);
	scalar = 0;   (* scalar *)
	none = -1;   (* no entry *)
	any = -2;   (* no restriction on dimension *)
	match = -3;   (* dimension matches previous dimension *)
	add = -4;   (* dimensions add, for result types i.e. in Tensor product *)

VAR
	ArrayModuleIdx-: StringPool.Index;  ArrayModule-: PCT.Module;   (* needed by PCP  to add to import list *)
	NoProc-: StringPool.Index;  modscope: PCT.ModScope;  Any: PCT.Struct;
TYPE
	Operator = SIGNED32;

	BaseTypes = POINTER TO RECORD
		left, right, res: PCT.Struct;
		idx: StringPool.Index;
		next: BaseTypes;
	END;

	OperatorEntry = OBJECT
	VAR op: Operator;
		pname: ARRAY 256 OF CHAR;
		lshape, rshape, resshape: SIGNED32;
		next: OperatorEntry;

		first, last: BaseTypes;

		(* Create new operator entry and subscribe it to the list of operators, lshape, rshape and resshape stand for the geometries of the left, right and
		result parameter.  *)
		PROCEDURE & Init*( op: Operator;  CONST name: ARRAY OF CHAR;
									    lshape, rshape, resshape: SIGNED32 );
		BEGIN
			SELF.op := op;  COPY( name, SELF.pname );  SELF.lshape := lshape;
			SELF.rshape := rshape;  SELF.resshape := resshape;
			IF firstop = NIL THEN firstop := SELF;  lastop := SELF
			ELSE lastop.next := SELF;  lastop := SELF
			END;
		END Init;

	(* enter (array) base types for this operator. Suffix is appended to pname, the result provides the expected procedure name in ArrayBase *)
		PROCEDURE Enter( left, right, res: PCT.Struct;  CONST suffix: ARRAY OF CHAR );
		VAR type: BaseTypes;
			procname: ARRAY 256 OF CHAR;
		BEGIN
			NEW( type );  type.left := left;  type.right := right;  type.res := res;
			COPY( pname, procname );  Strings.Append( suffix, procname );

			StringPool.GetIndex( procname, type.idx );
			IF first = NIL THEN first := type;  last := first
			ELSE last.next := type;  last := type;
			END;
		END Enter;

	(* create a default suffix and enter left,right, res with this suffix *)
		PROCEDURE Enter3( left, right, res: PCT.Struct );
		VAR suffix: ARRAY 32 OF CHAR;
			i: SIGNED32;

			PROCEDURE Append( c: CHAR );
			BEGIN
				suffix[i] := c;  INC( i );
			END Append;

			PROCEDURE TypeChar( t: PCT.Struct ): CHAR;
			VAR c: CHAR;
			BEGIN
				IF t = PCT.Int8 THEN c := "S"
				ELSIF t = PCT.Int16 THEN c := "I"
				ELSIF t = PCT.Int32 THEN c := "L"
				ELSIF t = PCT.Float32 THEN c := "R"
				ELSIF t = PCT.Float64 THEN c := "X"
				ELSIF t = PCT.Bool THEN c := "B"
				ELSIF t = Any THEN c := "A"
				ELSE HALT( 100 );
				END;
				RETURN c;
			END TypeChar;

		BEGIN
			IF lshape = scalar THEN Append( "S" );
			ELSIF (lshape > 0) OR (lshape = any) THEN Append( "A" );
			ELSE
				ASSERT ( lshape = none );
				left := NIL;
			END;
			IF (left # NIL ) & (lshape # none) THEN Append( TypeChar( left ) ) END;
			IF rshape = 0 THEN Append( "S" );
			ELSIF (rshape > 0) OR (rshape = any) OR (rshape = match) THEN
				Append( "A" );
			ELSE
				ASSERT ( rshape = none );
				right := NIL;
			END;
			IF (right # NIL ) & (rshape # none) THEN Append( TypeChar( right ) ) END;
			suffix[i] := 0X;  Enter( left, right, res, suffix );
		END Enter3;

	(* enter a default base type with left, right (if existing), and res of type t *)
		PROCEDURE EnterDefault( t: PCT.Struct );
		BEGIN
			Enter3( t, t, t );
		END EnterDefault;

		PROCEDURE EnterDefaultB( t: PCT.Struct );
		BEGIN
			Enter3( t, t, PCT.Bool );
		END EnterDefaultB;


	(* enter base types for most operators *)
		PROCEDURE EnterDefaults;
		BEGIN
			EnterDefault( PCT.Int8 );  EnterDefault( PCT.Int16 );
			EnterDefault( PCT.Int32 );  EnterDefault( PCT.Float32 );
			EnterDefault( PCT.Float64 );
		END EnterDefaults;

		PROCEDURE EnterDefaultsB;
		BEGIN
			EnterDefaultB( PCT.Int8 );  EnterDefaultB( PCT.Int16 );
			EnterDefaultB( PCT.Int32 );  EnterDefaultB( PCT.Float32 );
			EnterDefaultB( PCT.Float64 );
		END EnterDefaultsB;



	(* find matching basetypes record *)
		PROCEDURE Match( l, r: PCT.Struct;  VAR type: PCT.Struct ): StringPool.Index;
		VAR ldim, rdim, dim: SIGNED32;  lbase, rbase, res: PCT.Struct;  e: BaseTypes;

			PROCEDURE Max( l, r: SIGNED32 ): SIGNED32;
			BEGIN
				IF l > r THEN RETURN l ELSE RETURN r END;
			END Max;

		BEGIN
			IF l = NIL THEN ldim := none;  lbase := NIL;
			ELSIF l IS PCT.EnhArray THEN
				ldim := l( PCT.EnhArray ).dim;  lbase := PCT.ElementType( l );
			ELSIF l IS PCT.Tensor THEN
				ldim := anydim; lbase := PCT.ElementType( l );
			ELSE ldim := scalar;  lbase := l;
			END;

			IF r = NIL THEN rdim := none;  rbase := NIL;
			ELSIF r IS PCT.EnhArray THEN
				rdim := r( PCT.EnhArray ).dim;  rbase := PCT.ElementType( r )
			ELSIF r IS PCT.Tensor THEN
				rdim := anydim; rbase := PCT.ElementType( r )
			ELSE rdim := scalar;  rbase := r;
			END;

			(* check shape *)
			IF (ldim # lshape) & ((ldim = 0) OR (lshape # any)) THEN RETURN NoProc END;
			IF (rdim # rshape) & ((rdim = 0) OR (rshape # any) & ((rshape # match) OR (ldim # rdim) & (ldim#anydim) & (rdim#anydim))) THEN
				RETURN NoProc
			END;



			(* shape ok, now check base types *)
			e := first;
			WHILE (e # NIL ) &
						((e.left # lbase) & (e.left # Any) OR
						  (e.right # rbase) & (e.right # Any)) DO
				e := e.next;
			END;
			IF e = NIL THEN RETURN NoProc END;
			IF e.res = Any THEN
				IF e.left = Any THEN res := e.left
				ELSIF e.right = Any THEN res := e.right
				ELSE  res := NIL;
					(* HALT( 100 );  *)
				END;
			ELSE res := e.res;
			END;


			(* base types ok, now build return type *)
			IF resshape >= scalar THEN dim := resshape;
			ELSIF resshape = match THEN dim := Max( ldim, rdim );
			ELSIF resshape = add THEN dim := ldim + rdim;
			ELSIF resshape = any THEN ASSERT(res=NIL); (* tensor result type *)
			ELSE
				HALT( 100 );   (* should never happen *)
			END;
			IF res= NIL THEN type := NIL;
			ELSIF dim=0 THEN type := res;
			ELSIF (l#NIL) & (l IS PCT.Tensor) OR (r#NIL) & (r IS PCT.Tensor) THEN
				IF dim=0 THEN (*! fof modified: was dim<=0 (why?) *)
					type := res
				ELSE
					type := PCT.BuildTensor(res);
				END;

			ELSE
				type := PCT.BuildOpenArray( res, dim );
			END;
			RETURN e.idx;
		END Match;

	(* for debugging purposes *)
		PROCEDURE Report;
		VAR e: BaseTypes;
			str: ARRAY 256 OF CHAR;

			PROCEDURE ReportType( t: PCT.Struct );
			BEGIN
				IF t = PCT.Int8 THEN PCM.LogWStr( "int8" );
				ELSIF t = PCT.Int16 THEN PCM.LogWStr( "int16" );
				ELSIF t = PCT.Int32 THEN PCM.LogWStr( "int32" );
				ELSIF t = PCT.Float32 THEN PCM.LogWStr( "float32" );
				ELSIF t = PCT.Float64 THEN PCM.LogWStr( "float64" );
				ELSIF t = PCT.Bool THEN PCM.LogWStr( "bool" );
				ELSE PCM.LogWStr( "???" );
				END;
			END ReportType;

			PROCEDURE ReportShape( shape: SIGNED32 );
			BEGIN
				IF shape = scalar THEN PCM.LogWStr( "[scalar]" );
				ELSIF shape = any THEN PCM.LogWStr( "[any dim array]" );
				ELSIF shape = match THEN PCM.LogWStr( "[matching dim array]" );
				ELSIF shape = add THEN PCM.LogWStr( "[adding dim array]" );
				ELSIF shape > 0 THEN
					PCM.LogWStr( "[" );  PCM.LogWNum( shape );  PCM.LogWStr( " dim array]" );
				ELSE PCM.LogWStr( "???" );
				END;
			END ReportShape;

		BEGIN
			PCM.LogWStr( "Operator:" );  PCM.LogWNum( op );  PCM.LogWStr( " (" );
			PCM.LogWStr( pname );  PCM.LogWStr( ") : " );  ReportShape( lshape );
			IF rshape # none THEN PCM.LogWStr( " x " );  ReportShape( rshape );  END;
			PCM.LogWStr( "-> " );  ReportShape( resshape );  PCM.LogWLn;  e := first;
			WHILE (e # NIL ) DO
				PCM.LogWStr( "     " );  ReportType( e.left );
				IF e.right # NIL THEN PCM.LogWStr( " x " );  ReportType( e.right );  END;
				PCM.LogWStr( " -> " );  ReportType( e.res );
				StringPool.GetString( e.idx, str );  PCM.LogWStr( " (" );
				PCM.LogWStr( str );  PCM.LogWStr( ")" );  PCM.LogWLn;  e := e.next;
			END;
			PCM.LogFlush;
		END Report;

	END OperatorEntry;

VAR
	firstop, lastop: OperatorEntry;

	(* find the name of the procedure that matches the operator and arguments left and right (#NIL, if any) *)
	PROCEDURE FindArrayOp*( op: Operator;  l, r: PCT.Struct;
												   VAR type: PCT.Struct ): StringPool.Index;
	VAR e: OperatorEntry;  idx: StringPool.Index;  name: ARRAY 256 OF CHAR;
	BEGIN
		idx := NoProc;  type := NIL;

		e := firstop;
		WHILE (e # NIL ) DO
			IF e.op = op THEN

				idx := e.Match( l, r, type );
				IF idx # NoProc THEN

					StringPool.GetString(idx,name);
					(*
					PCM.LogWStr("FoundArrayOp: "); PCM.LogWStr(name); PCM.LogWLn;
					*)

				RETURN idx END;
			END;
			e := e.next;
		END;
		RETURN NoProc;
	END FindArrayOp;

(* find the procedure named idx in the ArrayBase Module *)
	PROCEDURE FindProcedure*( pos: SIGNED32;  idx: StringPool.Index ): PCT.Proc;
	VAR sym: PCT.Symbol;
	BEGIN
		BEGIN {EXCLUSIVE}
			IF ArrayModule = NIL THEN
				PCT.Import( modscope.owner, ArrayModule, ArrayModuleIdx );
				(*IF ArrayModule # NIL THEN modscope.AddModule( ArrayModuleIdx, ArrayModule, res ) END; *)
			END;
		END;
		IF ArrayModule = NIL THEN PCM.Error( 999, pos, "ArrayModule missing." );  RETURN NIL;  END;
		IF idx = NoProc THEN PCM.Error( 137, pos, "" );  RETURN NIL;  END;
		sym :=
			PCT.Find( ArrayModule.scope, ArrayModule.scope, idx, PCT.procdeclared,
						    TRUE );
		IF sym = NIL THEN PCM.Error( 999, pos, "Operator not found, check PCArrays, ArrayBase missing?" );  RETURN NIL;
		ELSE RETURN sym( PCT.Proc );
		END;
	END FindProcedure;

	PROCEDURE IsNumType( t: PCT.Struct ): BOOLEAN;
	BEGIN
		RETURN (t = PCT.Int8) OR (t = PCT.Int16) OR (t = PCT.Int32) OR
					   (t = PCT.Float32) OR (t = PCT.Float64);
	END IsNumType;

	PROCEDURE Largest*( a, b: PCT.Struct ): PCT.Struct;
	BEGIN
		IF a = b THEN RETURN a
		ELSIF ~IsNumType( a ) OR ~IsNumType( b ) THEN RETURN NIL
		END;

		IF a = PCT.Float64 THEN RETURN a;
		ELSIF a = PCT.Float32 THEN
			IF b = PCT.Float64 THEN RETURN b ELSE RETURN a;  END;
		ELSIF a = PCT.Int32 THEN
			IF (b = PCT.Float64) OR (b = PCT.Float32) THEN RETURN b ELSE RETURN a END;
		ELSIF a = PCT.Int16 THEN
			IF (b = PCT.Float64) OR (b = PCT.Float32) OR (b = PCT.Int32) THEN
				RETURN b
			ELSE RETURN a
			END;
		ELSIF a = PCT.Int8 THEN
			IF (b = PCT.Float64) OR (b = PCT.Float32) OR (b = PCT.Int32) OR
				(b = PCT.Int16) THEN
				RETURN b
			ELSE RETURN a
			END;
		ELSE HALT( 100 );
		END;
	END Largest;

	PROCEDURE Init;
	VAR op: OperatorEntry;
	BEGIN
		NEW( Any );
		(** opname, left , right , destination, is left array, is right array, is destination aray, name *)

		(* special functions: scalar x scalar -> scalar *)
		NEW( op, minfn, "Min", scalar, scalar, scalar );   (* MIN(a,b) *)
		op.Enter3( PCT.Float32, PCT.Float32, PCT.Float32 );
		op.Enter3( PCT.Float64, PCT.Float64, PCT.Float64 );
		NEW( op, maxfn, "Max", scalar, scalar, scalar );   (* MAX(a,b) *)
		op.Enter3( PCT.Float32, PCT.Float32, PCT.Float32 );
		op.Enter3( PCT.Float64, PCT.Float64, PCT.Float64 );
		(* conversions, special function: scalar is not really passed, this is a trick *)
		NEW( op, convert, "Convert", any, scalar, match );   (* implicit, SHORT(A), ENTIER(A) *)
		op.Enter( PCT.Int8, PCT.Int16, PCT.Int16, "ASAI" );
		op.Enter( PCT.Int8, PCT.Int32, PCT.Int32, "ASAL" );
		op.Enter( PCT.Int8, PCT.Float32, PCT.Float32, "ASAR" );
		op.Enter( PCT.Int8, PCT.Float64, PCT.Float64, "ASAX" );
		op.Enter( PCT.Int16, PCT.Int8, PCT.Int8, "AIAS" );
		op.Enter( PCT.Int16, PCT.Int32, PCT.Int32, "AIAL" );
		op.Enter( PCT.Int16, PCT.Float32, PCT.Float32, "AIAR" );
		op.Enter( PCT.Int16, PCT.Float64, PCT.Float64, "AIAX" );
		op.Enter( PCT.Int32, PCT.Int16, PCT.Int16, "ALAI" );
		op.Enter( PCT.Int32, PCT.Float32, PCT.Float32, "ALAR" );
		op.Enter( PCT.Int32, PCT.Float64, PCT.Float64, "ALAX" );
		op.Enter( PCT.Float32, PCT.Int32, PCT.Int32, "ARAL" );
		op.Enter( PCT.Float32, PCT.Float64, PCT.Float64, "ARAX" );
		op.Enter( PCT.Float64, PCT.Float32, PCT.Float32, "AXAR" );
		op.Enter( PCT.Float64, PCT.Int32, PCT.Int32, "AXAL" );
		(* monadic not *)
		NEW(op, not, "Not",any,none,match); (* ~A *)
		op.Enter3(PCT.Bool,PCT.Bool,PCT.Bool);
		(* monadic minus *)
		NEW( op, minus, "Minus", any, none, match );   (* -A *)
		op.EnterDefaults();
		(* ABS *)
		NEW( op, abs, "Abs", any, none, match );   (* ABS(A) *)
		op.EnterDefaults();
		(* add ARR to ARR *)
		NEW( op, plus, "Add", any, match, match );   (* A + B *)
		op.EnterDefaults();
		(* add ARR to Scalar *)
		NEW( op, plus, "Add", any, scalar, match );   (* A + b *)
		op.EnterDefaults();
		(* add Scalar to arr  *)
		NEW( op, plus, "Add", scalar, any, match );   (* a + B *)
		op.EnterDefaults();
		(* sub ARR from ARR *)
		NEW( op, minus, "Sub", any, match, match );   (* A - B *)
		op.EnterDefaults();
		(* sub scalar from ARR  *)
		NEW( op, minus, "Sub", any, scalar, match );   (* A -b *)
		op.EnterDefaults();
		(* sub ARR from Scalar  *)
		NEW( op, minus, "Sub", scalar, any, match );   (* a - B*)
		op.EnterDefaults();
		(* scalar product *)
		NEW( op, scalarproduct, "SP", any, match, scalar );   (* A +* B *)
		op.Enter3( PCT.Int8, PCT.Int8, PCT.Int32 );
		op.Enter3( PCT.Int16, PCT.Int16, PCT.Int32 );
		op.Enter3( PCT.Int32, PCT.Int32, PCT.Int32 );
		op.Enter3( PCT.Float32, PCT.Float32, PCT.Float32 );
		op.Enter3( PCT.Float64, PCT.Float64, PCT.Float64 );
		(* element-wise multiplication *)
		NEW( op, elementproduct, "EMul", any, match, match );   (* A .* B *)
		op.EnterDefaults();
		(* multiply ARR with scalar *)
		NEW( op, times, "Mul", any, scalar, match );   (* A * b *)
		op.EnterDefaults();
		(*  multiply scalar with ARR*)
		NEW( op, times, "Mul", scalar, any, match );   (* a * B *)
		op.EnterDefaults();
		(* element-wise division *)
		NEW( op, elementquotient, "EDivide", any, match, match );   (* A ./ B *)
		op.Enter3( PCT.Int8, PCT.Int8, PCT.Float32 );
		op.Enter3( PCT.Int16, PCT.Int16, PCT.Float32 );
		op.Enter3( PCT.Int32, PCT.Int32, PCT.Float32 );
		op.Enter3( PCT.Float32, PCT.Float32, PCT.Float32 );
		op.Enter3( PCT.Float64, PCT.Float64, PCT.Float64 );
		(* Array / scalar *)
		NEW( op, PCS.slash, "Divide", any, scalar, match );   (* A / b *)
		op.Enter3( PCT.Int8, PCT.Int8, PCT.Float32 );
		op.Enter3( PCT.Int16, PCT.Int16, PCT.Float32 );
		op.Enter3( PCT.Int32, PCT.Int32, PCT.Float32 );
		op.Enter3( PCT.Float32, PCT.Float32, PCT.Float32 );
		op.Enter3( PCT.Float64, PCT.Float64, PCT.Float64 );
		(* scalar / array *)
		NEW( op, PCS.slash, "Divide", scalar, any, match );   (* a / B *)
		op.Enter3( PCT.Int8, PCT.Int8, PCT.Float32 );
		op.Enter3( PCT.Int16, PCT.Int16, PCT.Float32 );
		op.Enter3( PCT.Int32, PCT.Int32, PCT.Float32 );
		op.Enter3( PCT.Float32, PCT.Float32, PCT.Float32 );
		op.Enter3( PCT.Float64, PCT.Float64, PCT.Float64 );
		(* element-wise div *)
		NEW( op, div, "EDiv", any, match, match );   (* A DIV B *)
		op.EnterDefault( PCT.Int8 );  op.EnterDefault( PCT.Int16 );
		op.EnterDefault( PCT.Int32 );
		(* Array DIV scalar *)
		NEW( op, div, "Div", any, scalar, match );   (* A DIV b *)
		op.EnterDefault( PCT.Int8 );  op.EnterDefault( PCT.Int16 );
		op.EnterDefault( PCT.Int32 );
		(* scalar DIV array *)
		NEW( op, div, "Div", scalar, any, match );   (* a DIV B *)
		op.EnterDefault( PCT.Int8 );  op.EnterDefault( PCT.Int16 );
		op.EnterDefault( PCT.Int32 );
		(* element-wise mod*)
		NEW( op, mod, "Mod", any, match, match );   (* A MOD B *)
		op.EnterDefault( PCT.Int8 );  op.EnterDefault( PCT.Int16 );
		op.EnterDefault( PCT.Int32 );
		(* Array MOD scalar *)
		NEW( op, mod, "Mod", any, scalar, match );   (* A MOD b *)
		op.EnterDefault( PCT.Int8 );  op.EnterDefault( PCT.Int16 );
		op.EnterDefault( PCT.Int32 );
		(* scalar MOD array *)
		NEW( op, mod, "Mod", scalar, any, match );   (* a MOD B *)
		op.EnterDefault( PCT.Int8 );  op.EnterDefault( PCT.Int16 );
		op.EnterDefault( PCT.Int32 );
		(* equality *)
		NEW( op, eql, "Eql", any, match, scalar );   (* A = B *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		NEW( op, eql, "Eql", any, scalar, scalar );   (* A = b *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		NEW( op, eql, "Eql", scalar, any, scalar );   (* a = B *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		NEW( op, neq, "Neq", any, match, scalar );   (* A # B *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		NEW( op, neq, "Neq", any, scalar, scalar );   (* A # b *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		NEW( op, neq, "Neq", scalar, any, scalar );   (* a # B *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		(* comparison *)
		NEW( op, lss, "Lss", any, match, scalar );   (* A < B *)
		op.EnterDefaultsB();
		NEW( op, lss, "Lss", any, scalar, scalar );   (* A < b *)
		op.EnterDefaultsB();
		NEW( op, lss, "Lss", scalar, any, scalar );   (* a < B *)
		op.EnterDefaultsB();
		NEW( op, leq, "Leq", any, match, scalar );   (* A <= B *)
		op.EnterDefaultsB();
		NEW( op, leq, "Leq", any, scalar, scalar );   (* A <= b *)
		op.EnterDefaultsB();
		NEW( op, leq, "Leq", scalar, any, scalar );   (* a <= B *)
		op.EnterDefaultsB();
		NEW( op, gtr, "Gtr", any, match, scalar );   (* A > B *)
		op.EnterDefaultsB();
		NEW( op, gtr, "Gtr", any, scalar, scalar );   (* A > b *)
		op.EnterDefaultsB();
		NEW( op, gtr, "Gtr", scalar, any, scalar );   (* a > B *)
		op.EnterDefaultsB();
		NEW( op, geq, "Geq", any, match, scalar );   (* A >= B *)
		op.EnterDefaultsB();
		NEW( op, geq, "Geq", any, scalar, scalar );   (* A >= b *)
		op.EnterDefaultsB();
		NEW( op, geq, "Geq", scalar, any, scalar );   (* a >= B *)
		op.EnterDefaultsB();

		(* elementwise equality *)
		NEW( op, eeql, "EEql", any, match, match );   (* A .= B *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		NEW( op, eeql, "EEql", any, scalar, match );   (* A .= b *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		NEW( op, eeql, "EEql", scalar, any, match );   (* a .= B *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		NEW( op, eneq, "ENeq", any, match, match );   (* A .# B *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		NEW( op, eneq, "ENeq", any, scalar, match );   (* A .# b *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();
		NEW( op, eneq, "ENeq", scalar, any, match );   (* a .# B *)
		op.EnterDefaultB( PCT.Bool );  op.EnterDefaultsB();

		(* logical operators *)
		NEW( op, or, "ElOr", any, match, match );   (* A OR B *)
		op.EnterDefaultB( PCT.Bool );
		NEW( op, or, "ElOr", any, scalar, match );   (* A OR b *)
		op.EnterDefaultB( PCT.Bool );
		NEW( op, or, "ElOr", scalar, any, match );   (* a OR B *)
		op.EnterDefaultB( PCT.Bool );

		NEW( op, and, "ElAnd", any, match, match );   (* A & B *)
		op.EnterDefaultB( PCT.Bool );
		NEW( op, and, "ElAnd", scalar, any, match );   (* A & b *)
		op.EnterDefaultB( PCT.Bool );
		NEW( op, and, "ElAnd", any, scalar, match );   (* a & B *)
		op.EnterDefaultB( PCT.Bool );

		(* elementwise comparison *)
		NEW( op, elss, "ELss", any, match, match );   (* A .< B *)
		op.EnterDefaultsB();
		NEW( op, elss, "ELss", any, scalar, match );   (* A .< b *)
		op.EnterDefaultsB();
		NEW( op, elss, "ELss", scalar, any, match );   (* a .< B *)
		op.EnterDefaultsB();
		NEW( op, eleq, "ELeq", any, match, match );   (* A .<= B *)
		op.EnterDefaultsB();
		NEW( op, eleq, "ELeq", any, scalar, match );   (* A .<= b *)
		op.EnterDefaultsB();
		NEW( op, eleq, "ELeq", scalar, any, match );   (* a .<= B *)
		op.EnterDefaultsB();
		NEW( op, egtr, "EGtr", any, match, match );   (* A .> B*)
		op.EnterDefaultsB();
		NEW( op, egtr, "EGtr", any, scalar, match );   (* A .> b *)
		op.EnterDefaultsB();
		NEW( op, egtr, "EGtr", scalar, any, match );   (* a .> B *)
		op.EnterDefaultsB();
		NEW( op, egeq, "EGeq", any, match, match );   (* A .>= B *)
		op.EnterDefaultsB();
		NEW( op, egeq, "EGeq", any, scalar, match );   (* A .>= b *)
		op.EnterDefaultsB();
		NEW( op, egeq, "EGeq", scalar, any, match );   (* a .>= B *)
		op.EnterDefaultsB();
		(* min *)
		NEW( op, minfn, "Min", any, none, scalar );   (* MIN(A) *)
		op.EnterDefaults();
		(* max *)
		NEW( op, maxfn, "Max", any, none, scalar );   (* MAX(A) *)
		op.EnterDefaults();
		(* assign number *)
		NEW( op, assign, "Assign", any, scalar, match );   (* A :=  b *)
		op.EnterDefaults();
		op.EnterDefault(PCT.Bool);
		(* matrix multiplication *)
		NEW( op, times, "MatMul", 2, 2, 2 );   (* A * B *)
		op.EnterDefaults();
		(* matrix-vector multiplication *)
		NEW( op, times, "MatVecMul", 2, 1, 1 );   (* A * V *)
		op.EnterDefaults();
		(* vector-matrix multiplication *)
		NEW( op, times, "VecMatMul", 1, 2, 1 );   (* V * A *)
		op.EnterDefaults();

		(* element-wise inc multiplication *)
		NEW( op, incmule, "EMulInc", any, match, match );   (* A .* B *)
		op.EnterDefaults();

		(* INCMUL *)
		NEW( op, incmul, "MatMulInc", 2, 2, 2 );   (* A := A + B * C *)
		op.EnterDefaults();
		(* matrix-vector  *)
		NEW( op, incmul, "MatVecMulInc", 2, 1, 1 );   (* v := v + M * w *)
		op.EnterDefaults();
		(* vector-matrix  *)
		NEW( op, incmul, "VecMatMulInc", 1, 2, 1 );   (* v := v + w * M *)
		op.EnterDefaults();

		(* array array *)
		NEW( op, incmul, "IncMul", any, scalar, match );   (* A := A+ c * B *)
		op.EnterDefaults();
		NEW( op, incmul, "IncMul", scalar, any, match );   (* A := A+ B * c *)
		op.EnterDefaults();

		(* DECMUL *)
		NEW( op, decmul, "MatMulDec", 2, 2, 2 );   (* A := A + B * C *)
		op.EnterDefaults();
		(* matrix-vector  *)
		NEW( op, decmul, "MatVecMulDec", 2, 1, 1 );   (* v := v + M * w *)
		op.EnterDefaults();
		(* vector-matrix  *)
		NEW( op, decmul, "VecMatMulDec", 1, 2, 1 );   (* v := v + w * M *)
		op.EnterDefaults();

		(* array array *)
		NEW( op, decmul, "DecMul", any, scalar, match );   (* A := A+ c * B *)
		op.EnterDefaults();
		NEW( op, decmul, "DecMul", scalar, any, match );   (* A := A+ B * c *)
		op.EnterDefaults();



		NEW( op, times, "CrossProduct", 1, 1, 1 );   (* V * V *)
		op.EnterDefaults();
		(* sum *)
		NEW( op, sumfn, "Sum", any, none, scalar );   (* SUM(A) *)
		op.EnterDefaults();
		(* transposition *)
		NEW( op, transpose, "Transpose", 2, none, 2 );   (* A` *)
		op.EnterDefaults();
		(* tensor product *)
		NEW( op, dtimes, "TensorProd", any, any, add );   (* A ** B *)
		op.EnterDefaults();
		(* copy *)
		NEW( op, copy, "CopyArray", any, scalar, match );   (* used in assignment and return *)
		op.Enter( Any, PCT.Int32, Any, "" );
		NEW(op,copy2,"CopyTensor",any,scalar,match);
		op.Enter( Any, PCT.Int32, Any, "" );
		NEW( op, zerocopy, "ZeroCopyArray", any, scalar, match );   (* used in assignment and return *)
		op.Enter( Any, PCT.Int32, Any, "" );
		NEW( op,zerocopy2,"ZeroCopyTensor",any,scalar,match);
		op.Enter( Any, PCT.Int32, Any, "" );
		NEW(op,selfcopy,"CopyArraySelf",any,scalar,match);
		op.Enter( Any, PCT.Int32, Any, "" );
		NEW(op,selfcopy,"CopyTensorSelf",any,scalar,match);
		op.Enter( Any, PCT.Int32, Any, "" );


		NEW(op,allocateTensor,"AllocateTensorX",1 (* one dimensional array as input parameter *),scalar (* elementsize *) ,any);
		op.Enter( PCT.Int32, PCT.Int32, Any, "" );
		op.Enter( PCT.Int16, PCT.Int32, Any, "" );
		op.Enter( PCT.Int8, PCT.Int32, Any, "" );


		NEW(op,lenfnA,"LenA",any,none,0);
		op.Enter(Any,Any,PCT.BuildOpenArray( PCT.Int32,1) ,"");
		NEW(op,incrfnA,"IncrA",any,none,0);
		op.Enter(Any,Any,PCT.BuildOpenArray( PCT.Int32,1),"");

		NEW(op,lenfn,"Len",any,scalar,scalar);
		op.Enter(Any,PCT.Int32,PCT.Int32,"");
		NEW(op,incrfn,"Incr",any,scalar,scalar);
		op.Enter(Any,PCT.Int32,PCT.Int32,"");

		NEW(op,reshapefn,"Reshape",any,any,0);
		op.Enter(Any,Any,PCT.BuildOpenArray( PCT.Int32,1),"");

		NEW(op,shallowcopyfn,"ShallowCopy",any,none,match);
		op.Enter(Any,Any,Any,"");
	END Init;

	PROCEDURE InitScope*( scope: PCT.ModScope );
	BEGIN
		ArrayModule := NIL;  modscope := scope;
	END InitScope;

	PROCEDURE Report*;
	VAR e: OperatorEntry;
	BEGIN
		e := firstop;
		WHILE (e # NIL ) DO e.Report;  e := e.next;  END;
	END Report;

BEGIN
	Init;  ArrayModule := NIL;  NoProc := StringPool.GetIndex1( "#NoProc#" );
	ArrayModuleIdx := StringPool.GetIndex1( ArrayModuleName );
END PCArrays.

PCArrays.Report ~
