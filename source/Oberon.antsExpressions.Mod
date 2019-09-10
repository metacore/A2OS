MODULE antsExpressions IN Oberon;   (** non-portable / source: antsExpressions.Mod *)  (*  fof, ejz 2001 *)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)



(*
Base of this File was the Module Expressions.Mod, made by Emil Zeller
Modifications for ANTS / Voyager by Felix Friedrich
(c) Felix Friedrich, 2002
(c) Emil Zeller, 2002
*)

IMPORT SYSTEM, Modules, Reals IN A2, Strings, Texts, Oberon, OPM, OPS, OPT, OPV, TextGadgets, Input, Objects, Display, Fonts,
	Files, Gadgets, vyLongrealVec, vyRealVec, vyIntVec, vyLongintVec, Types, vyBase, vyName, antsExpressionsObjects,
	Attributes, vyHostTexts, vyPointerVec;

CONST
(* Undef* = 0; Bool* = 2; Char* = 3; SInt* = 4; Int* = 5; LInt* = 6; Real* = 7; LReal* = 8; NoTyp* = 12; *)
	(* structure forms *)
	Undef = 0;  Byte = 1;  Bool = 2;  Char = 3;  SInt = 4;  Int = 5;  LInt = 6;  Real = 7;  LReal = 8;  Set = 9;  String = 10;
	NilTyp = 11;  NoTyp = 12;  Pointer = 13;  ProcTyp = 14;  Comp = 15;  HInt = 16;

	(* composite structure forms *)
	Basic = 1;  StaticArr = 2;  SDynArr = 3;  DynArr = 4;  OpenArr = 5;  Record = 6;

	(* object modes *)
	Var = 1;  VarPar = 2;  Con = 3;  Fld = 4;  Typ = 5;  LProc = 6;  XProc = 7;  SProc = 8;  CProc = 9;  Mod = 11;  Head = 12;
	TProc = 13;  Alias = 14;
	Operator = 15;   (* used only in exp, when the list is created *)

	external = 1;  externalR = 2;

	(* sysflag *)  (* ejz *)
	notag = 1;  stdcall = 2;  cdecl = 3;  untraced = 4;

TYPE
	Value* = RECORD
		name*: OPS.String;

		class*: SIGNED8;
		b*: BOOLEAN;   (* bool var *)
		c*: CHAR;   (* char var *)
		i*: SIGNED32;   (* Sint,Int,LInt var *)
		x*: FLOAT32;   (* real var *)
		y*: FLOAT64;   (* longreal var *)
		s*: OPS.String;   (* string var *)
		ptr*: SIGNED32;   (* Pointer var , if Pointer then referenced object, if basic type class then ptr to Basic type Object *)
		p*: ANY;   (* SYSTEM.VAL(ANY,ptr) *)

		adr*: SIGNED32;   (* adress of linked object to basic type if available *)

		obj*: OPT.Object (* if resulting value found as OPT.Object otherwise = NIL *)
	END;


	(* Description of Value: (not yet implemented this way !)
	IF class IN {Bool,Char,SInt,Int,LInt,Real,LReal,Set,String,Pointer}
	& name = "" THEN is non-writable result of expression
	& name # "" THEN is writeable
	& IF obj#NIL THEN is global system variable of type module.variable
	objadr = address of obj; varadr=objadr;
	& IF obj=NIL THEN is global variable of type pointer with result type class
	IF varadr # 0 THEN
	IF class= Pointer THEN objadr is pointer to global variable
	IF class# Pointer THEN varadr is pointer to data of global var, objadr is pointer to global variable
	IF objadr = 0 THEN varadr has no pointer to global variable yet
	IF class = Undef THEN
	IF name ="" THEN is undef
	IF name #"" THEN is undef but writable to global name name
	IF class = NoTyp THEN
	is not writable
	*)

	Item = POINTER TO RECORD
		next: Item
	END;

	ValueItem = POINTER TO RECORD (Item)
		val: Value
	END;

	OpItem = POINTER TO RECORD (Item)
		op: ARRAY 8 OF CHAR
	END;

	NameItem = POINTER TO RECORD (Item)
		name: OPS.Name
	END;

	CallStack = RECORD
		code: ARRAY 128 OF CHAR;
		i, pc: SIGNED32;
		resadr, npar: SIGNED32;
		class: SIGNED8;
		obj: OPT.Object
	END;

	Stack* = RECORD
		top: Item
	END;

	PtrTable = POINTER TO ARRAY OF SIGNED32;

	StringStack = POINTER TO StringStackDesc;
	StringStackDesc = RECORD
		s: OPS.String;
		next: StringStack
	END;

VAR
	oldHook, thisHook: Objects.Handler;
	map: ARRAY 17 OF CHAR;
	sym: SIGNED8;  W: Texts.Writer;
	ptrTab: PtrTable;   (* pointer table *)
	nofptrs: SIGNED16;  foundSTRING: BOOLEAN;
	strings: StringStack;   (* need this chain to keep objects consistent while evaluating *)
	debug*, Note*: BOOLEAN;  enableCR*: BOOLEAN;  itnr: SIGNED32;  WLog: PROCEDURE;


	(** output routines **)

	PROCEDURE WriteTextToLog( T: Texts.Text );
	VAR R: Texts.Reader;  ch: CHAR;
	BEGIN
		Texts.OpenReader( R, T, 0 );  Texts.Read( R, ch );
		WHILE (~R.eot) DO Ch( ch );  Texts.Read( R, ch ) END;
		Ln;  WLog
	END WriteTextToLog;

	PROCEDURE WLogLog;
	BEGIN
		Texts.Append( Oberon.Log, W.buf )
	END WLogLog;

	PROCEDURE WLogToCaret;
	BEGIN
		vyHostTexts.InsertLog( W.buf )
	END WLogToCaret;

	PROCEDURE err( n: SIGNED16 );
	BEGIN
		WLog;  OPM.err( n )
	END err;

	PROCEDURE Str( s: ARRAY OF CHAR );
	BEGIN
		IF debug OR Note THEN Texts.WriteString( W, s ) END
	END Str;

	PROCEDURE Ch( ch: CHAR );
	BEGIN
		IF debug OR Note THEN Texts.Write( W, ch ) END
	END Ch;

	PROCEDURE Ln;
	BEGIN
		IF debug OR Note THEN Texts.WriteLn( W ) END
	END Ln;

	PROCEDURE Nt;
	BEGIN
		Note := ~Note
	END Nt;

	PROCEDURE WChar( ch: CHAR );
	VAR pat: Display.Pattern;  i, n, dx, x, y, w, h: SIGNED16;
		d: ARRAY 3 OF CHAR;
	BEGIN
		IF (~debug) & (~Note) THEN RETURN END;
		Fonts.GetChar( W.lib( Fonts.Font ), ch, dx, x, y, w, h, pat );
		IF h > 0 THEN Ch( ch );  Str( " (* " ) END;
		Ch( "#" );  i := 0;  n := ORD( ch );
		REPEAT d[i] := map[n MOD 10];  n := n DIV 10;  INC( i ) UNTIL n = 0;
		WHILE i > 0 DO DEC( i );  Ch( d[i] ) END;
		IF h = 0 THEN Str( " (* " ) ELSE Str( ", " ) END;
		Ch( "0" );  i := 0;  n := ORD( ch );
		REPEAT d[i] := map[n MOD 16];  n := n DIV 16;  INC( i ) UNTIL n = 0;
		WHILE i > 0 DO DEC( i );  Ch( d[i] ) END;
		Str( "X *)" )
	END WChar;

	PROCEDURE Gap;
	BEGIN
		IF debug OR Note THEN Str( "  " ) END
	END Gap;

	PROCEDURE WReal( x: FLOAT32;  n: SIGNED16 );
	BEGIN
		IF debug OR Note THEN Texts.WriteReal( W, x, n ) END
	END WReal;

	PROCEDURE WLongReal*( x: FLOAT64;  n: SIGNED16 );
	BEGIN
		IF debug OR Note THEN Texts.WriteLongReal( W, x, n ) END
	END WLongReal;

	PROCEDURE WInt( i, n: SIGNED32 );
	BEGIN
		IF debug OR Note THEN Texts.WriteInt( W, i, n ) END
	END WInt;

	PROCEDURE WClass( c: SIGNED16 );
	BEGIN
		CASE c OF
		0:     Str( "Undef" );
		| 1:   Str( "Byte" );
		| 2:   Str( "Bool" );
		| 3:   Str( "Char" );
		| 4:   Str( "SInt" );
		| 5:   Str( "Int" );
		| 6:   Str( "LInt" );
		| 7:   Str( "Real" );
		| 8:   Str( "LReal" );
		| 9:   Str( "Set" );
		| 10:
				Str( "String" );
		| 11:
				Str( "NilTyp" );
		| 12:
				Str( "NoTyp" );
		| 13:
				Str( "Pointer" );
		| 14:
				Str( "ProcTyp" );
		| 15:
				Str( "Comp" );
		| 16:
				Str( "HInt" )
		ELSE
		END
	END WClass;

	PROCEDURE WMode( c: SIGNED16 );
	BEGIN
		CASE c OF
		0:     Str( "Undef" );
		| 1:   Str( "Var" );
		| 2:   Str( "VarPar" );
		| 3:   Str( "Con" );
		| 4:   Str( "FId" );
		| 5:   Str( "Typ" );
		| 6:   Str( "LProc" );
		| 7:   Str( "XProc" );
		| 8:   Str( "SProc" );
		| 9:   Str( "CProc" );
		| 10:
				Str( "??" );
		| 11:
				Str( "Mod" );
		| 12:
				Str( "Head" );
		| 13:
				Str( "TProc" );
		| 14:
				Str( "Alias" );
		| 15:
				Str( "Operator" );
		| 16:
				Str( "??" )
		ELSE
		END
	END WMode;

	PROCEDURE WComp( c: SIGNED16 );
	BEGIN
		CASE c OF
		0:     Str( "Undef" );
		| 1:   Str( "Basic" );
		| 2:   Str( "StaticArr" );
		| 3:   Str( "SDynArr" );
		| 4:   Str( "DynArr" );
		| 5:   Str( "OpenArr" );
		| 6:   Str( "Record" )
		ELSE Str( " ?? " )
		END
	END WComp;

	PROCEDURE OutType*( p: ANY );
	VAR t: Types.Type;  level: SIGNED16;
	BEGIN
		IF p = NIL THEN Ln;  Str( "NIL" );  RETURN END;
		t := Types.TypeOf( p );  Ln;  Str( "OutType of ptr: " );  WInt( SYSTEM.VAL( SIGNED32, p ), 10 );  Str( " at adr " );  WInt( ADDRESSOF( p ), 10 );
		IF t # NIL THEN
			level := Types.LevelOf( t );
			WHILE (level >= 0) DO
				Ln;  WInt( level, 2 );  Str( " : " );  Str( "(" );
				IF t.mod # NIL THEN Str( t.mod.name );  Str( "." ) END;
				Str( t.name );  Str( ")" );
				IF level > 0 THEN t := Types.BaseOf( t, level - 1 );  level := Types.LevelOf( t ) ELSE level := -1 END
			END
		END
	END OutType;

	PROCEDURE WType*( p: ANY );
	VAR t: Types.Type;
	BEGIN
		IF p = NIL THEN Str( "(NIL POINTER)" );  RETURN END;
		t := Types.TypeOf( p );
		IF t # NIL THEN
			Str( "(" );
			IF t.mod # NIL THEN Str( t.mod.name );  Str( "." ) END;
			Str( t.name );  Str( ")" )
		ELSE Str( "NIL" )
		END
	END WType;

	PROCEDURE OutVal( VAR val: Value );
	VAR p: ANY;  ptrval: Value;
	BEGIN
		IF debug THEN Ln;  Str( "Value class: " );  WClass( val.class );  Ln END;
		CASE val.class OF
		Undef:
				Str( "Undef" )
		| Bool:
				IF val.b THEN Str( "TRUE" ) ELSE Str( "FALSE" ) END
		| Char:
				Ch( val.c )
		| SInt, Int, LInt:
				WInt( val.i, 10 )
		| Real:
				WReal( val.x, 10 )
		| LReal:
				WLongReal( val.y, 10 )
		| Pointer:
				(* p := SYSTEM.VAL(ANY, val.ptr); *)
				p := val.p;
				IF p = NIL THEN p := SYSTEM.VAL( ANY, val.ptr ) END;
				IF EvalPtrObj( p, ptrval ) THEN OutVal( ptrval )
				ELSE
					Str( "Pointer: " );  WInt( val.ptr, 10 );  Gap;
					(* ASSERT(val.p = SYSTEM.VAL(ANY,val.ptr)); *)
					IF val.i # 0 THEN Str( "!! val.i = " );  WInt( val.i, 10 ) END;
					IF debug THEN Ln;  Str( "Pointer adr: " );  WInt( val.adr, 10 ) END
				END;
				IF debug THEN OutType( p ) ELSE Str( "  " );  WType( p ) END;
		| String:
				Str( val.s );
		| NoTyp:
				Str( "NoTyp" )
		ELSE Str( "???" )
		END;
		IF debug THEN
			Ln;  Str( "name=" );  Str( val.name );
			IF val.obj # NIL THEN WObj( val.obj ) END
		END;
		WLog
	END OutVal;

	PROCEDURE Red;
	BEGIN
		Texts.SetColor( W, 1 )
	END Red;

	PROCEDURE Black;
	BEGIN
		Texts.SetColor( W, 15 )
	END Black;

	PROCEDURE Green;
	BEGIN
		Texts.SetColor( W, 8 )
	END Green;

	PROCEDURE Blue;
	BEGIN
		Texts.SetColor( W, 3 )
	END Blue;

	PROCEDURE WConst( c: OPT.Const );
	BEGIN
		Ln;  Str( "#### const " );  Ln;  Str( " intval " );  WInt( c.intval, 10 );  Ln;  Str( "intval2 " );  WInt( c.intval2, 10 );  Ln;  Str( "##" )
	END WConst;

	PROCEDURE WStruct( s: OPT.Struct );
	BEGIN
		IF s = NIL THEN RETURN END;
		Ln;  Str( "+++++Summarizing struct:" );  Ln;  Str( "form(class): " );  WClass( s.form );  Ln;  Str( "ref: " );  WInt( s.ref, 10 );  Ln;  Str( "n" );  WInt( s.n, 10 );  Ln;  Str( "comp: " );
		WComp( s.comp );  Ln;  Str( "tdadr" );  WInt( s.tdadr, 10 );  Ln;  Str( "offset" );  WInt( s.offset, 10 );  Ln;  Str( "txtpos" );  WInt( s.txtpos, 10 );
		Ln;  Str( "txtpos2" );  WInt( s.txtpos2, 10 );  Ln;  Str( "incomplete" );
		IF s.incomplete THEN Str( "TRUE" ) ELSE Str( "FALSE" ) END;
		Ln;  Str( "Size" );  WInt( s.size, 10 );  Ln;  Str( "rectest" );  WInt( s.rectest, 10 );  Ln;  Str( "++++++++" )
	END WStruct;

	PROCEDURE WObj( obj: OPT.Object );
	BEGIN
		Ln;  Str( "------------ Summarizing Object -----------" );  Ln;  Str( "Obj name: " );  Str( obj.name );  Ln;  Str( "Obj.mode: " );  WInt( obj.mode, 10 );  WMode( obj.mode );  Ln;  Str( "Obj.adr: " );
		WInt( obj.adr, 10 );  Ln;  Str( "Obj.fp:" );  WInt( obj.fp, 10 );  Ln;  Str( "Typ: ** " );  WStruct( obj.typ );  Ln;  Str( "BaseTyp**" );
		WStruct( obj.typ.BaseTyp );
		IF obj.conval # NIL THEN WConst( obj.conval ) END;
		Ln;  Str( "---------------------------------------" )
	END WObj;

	PROCEDURE Dump( S: Stack );
	VAR it: Item;  itc: SIGNED32;
	BEGIN
		Ln;  Str( "Dumping stack:" );  Ln;  Str( "************" );  it := S.top;  itc := 0;
		WHILE (it # NIL ) DO
			Ln;  Str( "Item on level " );  WInt( itc, 3 );  Str( " :: " );
			IF it IS ValueItem THEN
				WITH it: ValueItem DO Str( "Value Item :" );  OutVal( it.val );
				END;
			ELSIF it IS OpItem THEN
				WITH it: OpItem DO Str( "Op Item :" );  Str( it.op );
				END;
			ELSIF it IS NameItem THEN
				WITH it: NameItem DO Str( "NameItem :" );  Str( it.name )
				END;
			ELSE
			END;
			it := it.next;  INC( itc )
		END;
		Ln;  Str( "************" );  WLog
	END Dump;


(** parser, create stack **)

	PROCEDURE GetSym( VAR sym: SIGNED8 );
	BEGIN
		OPS.Get( sym )
	END GetSym;

	PROCEDURE NewV( VAR stack: Stack ): ValueItem;
	VAR v: ValueItem;
	BEGIN
		NEW( v );  v.val.ptr := 0;  v.val.p := NIL;  v.val.class := Undef;  v.next := stack.top;  stack.top := v;  RETURN v
	END NewV;

	PROCEDURE PushBool*( VAR stack: Stack;  b: BOOLEAN );
	VAR val: ValueItem;
	BEGIN
		val := NewV( stack );  val.val.class := Bool;  val.val.b := b
	END PushBool;

	PROCEDURE PushChar*( VAR stack: Stack;  c: CHAR );
	VAR val: ValueItem;
	BEGIN
		val := NewV( stack );  val.val.class := Char;  val.val.c := c;  val.val.s[0] := c;  val.val.s[1] := 0X
	END PushChar;

	PROCEDURE PushString*( VAR stack: Stack;  str: OPS.String );
	VAR val: ValueItem;
	BEGIN
		val := NewV( stack );  val.val.class := String;  val.val.s := str
	END PushString;

	PROCEDURE PushSInt*( VAR stack: Stack;  i: SIGNED8 );
	VAR val: ValueItem;
	BEGIN
		val := NewV( stack );  val.val.class := SInt;  val.val.i := i
	END PushSInt;

	PROCEDURE PushInt*( VAR stack: Stack;  i: SIGNED16 );
	VAR val: ValueItem;
	BEGIN
		val := NewV( stack );  val.val.class := Int;  val.val.i := i
	END PushInt;

	PROCEDURE PushLInt*( VAR stack: Stack;  i: SIGNED32 );
	VAR val: ValueItem;
	BEGIN
		val := NewV( stack );  val.val.class := LInt;  val.val.i := i
	END PushLInt;

	PROCEDURE PushReal*( VAR stack: Stack;  x: FLOAT32 );
	VAR val: ValueItem;
	BEGIN
		val := NewV( stack );  val.val.class := Real;  val.val.x := x
	END PushReal;

	PROCEDURE PushLReal*( VAR stack: Stack;  y: FLOAT64 );
	VAR val: ValueItem;
	BEGIN
		val := NewV( stack );  val.val.class := LReal;  val.val.y := y
	END PushLReal;

	PROCEDURE PushValue*( VAR stack: Stack;  VAR val: Value );
	VAR itm: ValueItem;
	BEGIN
		itm := NewV( stack );  itm.val := val
	END PushValue;

	PROCEDURE PushOp*( VAR stack: Stack;  op: ARRAY OF CHAR );
	VAR itm: OpItem;
	BEGIN
		NEW( itm );  COPY( op, itm.op );  itm.next := stack.top;  stack.top := itm
	END PushOp;

	PROCEDURE PushItem*( VAR stack: Stack;  item: ARRAY OF CHAR );
	VAR itm: NameItem;
	BEGIN
		IF (item = "NEG") OR (item = "ABS") OR (item = "ORD") OR (item = "CHR") OR (item = "ENTIER") OR (item = "SHORT") OR (item = "LONG") THEN PushOp( stack, item )
		ELSE NEW( itm );  COPY( item, itm.name );  itm.next := stack.top;  stack.top := itm
		END
	END PushItem;

	PROCEDURE Factor( VAR stack: Stack );
	VAR item: OPS.Name;
	BEGIN
		IF sym = OPS.ident THEN
			COPY( OPS.name, item );  GetSym( sym );
			WHILE sym = OPS.period DO
				GetSym( sym );  Strings.AppendCh( item, "." );
				IF sym = OPS.ident THEN Strings.Append( item, OPS.name );  GetSym( sym ) ELSE err( 40 ) END
			END;
			IF sym = OPS.lparen THEN
				Ln;  Str( "Left parent" );  GetSym( sym );  Ln;  Str( "sym: " );  WInt( sym, 10 );
				IF sym # OPS.rparen THEN Expr( stack ) END;
				Ln;  Str( "sym: " );  WInt( sym, 10 );
				WHILE sym = OPS.comma DO GetSym( sym );  Expr( stack ) END;
				IF sym # OPS.rparen THEN err( 22 ) ELSE GetSym( sym ) END
			END;
			PushItem( stack, item )
		ELSIF sym = OPS.number THEN
			IF OPS.numtyp = 1 THEN PushChar( stack, CHR( OPS.intval ) )
			ELSIF OPS.numtyp = 2 THEN PushLInt( stack, OPS.intval )
			ELSIF OPS.numtyp = 3 THEN PushReal( stack, OPS.realval )
			ELSIF OPS.numtyp = 4 THEN PushLReal( stack, OPS.lrlval )
			ELSE err( 63 )
			END;
			GetSym( sym )
		ELSIF sym = OPS.false THEN GetSym( sym );  PushBool( stack, FALSE )
		ELSIF sym = OPS.true THEN GetSym( sym );  PushBool( stack, TRUE )
		ELSIF sym = OPS.lparen THEN
			Ln;  Str( "Left paren" );  GetSym( sym );  Ln;  Str( "followed by: " );  WInt( sym, 10 );  Expr( stack );
			IF sym # OPS.rparen THEN err( 22 ) ELSE GetSym( sym ) END
		ELSIF sym = OPS.not THEN GetSym( sym );  Factor( stack )
		ELSIF sym = OPS.string THEN PushString( stack, OPS.str );  GetSym( sym )
		ELSE Ln;  Str( "unknown symbol" );  WInt( sym, 3 );  WLog;  err( 13 )
		END
	END Factor;

	PROCEDURE Term( VAR stack: Stack );
	VAR op: ARRAY 4 OF CHAR;
	BEGIN
		Factor( stack );
		WHILE (sym <= MAX( SET )) & (sym IN {OPS.times, OPS.slash, OPS.div, OPS.mod, OPS.and}) DO
			CASE sym OF
			OPS.times:
					op := "*"
			| OPS.slash:
					op := "/"
			| OPS.div:
					op := "DIV"
			| OPS.mod:
					op := "MOD"
			| OPS.and:
					op := "&"
			END;
			GetSym( sym );  Factor( stack );  PushOp( stack, op )
		END
	END Term;

	PROCEDURE SimpleExpr( VAR stack: Stack );
	VAR op: ARRAY 4 OF CHAR;
		neg: BOOLEAN;  file: BOOLEAN;
	BEGIN
		file := FALSE;
		IF sym = OPS.minus THEN neg := TRUE;  GetSym( sym )
		ELSIF sym = OPS.plus THEN neg := FALSE;  GetSym( sym )
		ELSIF sym = OPS.lss THEN
			GetSym( sym );
			IF sym = OPS.lss THEN file := TRUE;  GetSym( sym ) ELSE err( 113 ) END
		ELSE neg := FALSE
		END;
		Term( stack );
		WHILE (sym <= MAX( SET )) & (sym IN {OPS.plus, OPS.minus, OPS.or}) DO
			CASE sym OF
			OPS.plus:
					op := "+"
			| OPS.minus:
					op := "-"
			| OPS.or:
					op := "OR"
			END;
			GetSym( sym );  Term( stack );  PushOp( stack, op )
		END;
		IF neg THEN PushOp( stack, "NEG" )
		ELSIF file THEN PushOp( stack, "<<" )
		END
	END SimpleExpr;

	PROCEDURE Expr( VAR stack: Stack );
	VAR op: ARRAY 4 OF CHAR;
	BEGIN
		SimpleExpr( stack );  Ln;  Str( "Simple Expression, sym:" );  WInt( sym, 10 );
		CASE sym OF
		OPS.eql:
				op := "="
		| OPS.neq:
				op := "#"
		| OPS.lss:
				op := "<"
		| OPS.leq:
				op := "<="
		| OPS.gtr:
				op := ">"
		| OPS.geq:
				op := ">="
		| OPS.becomes:
				op := ":="
		ELSE RETURN
		END;
		GetSym( sym );
		IF (op = "<") & (sym = OPS.lss) THEN op := "<<";  GetSym( sym )
		ELSIF (op = ">") & (sym = OPS.gtr) THEN
			op := ">>";  GetSym( sym );
			IF (sym = OPS.gtr) THEN op := ">>>";  GetSym( sym ) END
		END;
		SimpleExpr( stack );  PushOp( stack, op )
	END Expr;


	(** expression evaluation **)
(** memo stack *)
	PROCEDURE StringPtr( VAR s: OPS.String ): SIGNED32;
	(* create a Pointer to String, must be hold in global objects since otherwise value cleared before proc call *)
	VAR str: StringStack;
	BEGIN
		NEW( str );  str.next := strings;  strings := str;  str.s := s;  RETURN ADDRESSOF( str.s )
	END StringPtr;

	PROCEDURE Ptr( ptr: SIGNED32 ): ANY;
	BEGIN
		RETURN SYSTEM.VAL( ANY, ptr )
	END Ptr;


(* reading text *)


	PROCEDURE AsPointer( a: Value;  VAR varadr: SIGNED32 ): ANY;
	VAR p: ANY;
	BEGIN
		p := NIL;
		IF a.class IN {SInt, Int, LInt} THEN
			p := vyLongintVec.NewLongintObject( a.i );  varadr := ADDRESSOF( p( vyLongintVec.tLONGINT ).i )
		ELSIF a.class = Real THEN p := vyRealVec.NewRealObject( a.x );  varadr := ADDRESSOF( p( vyRealVec.tREAL ).x )
		ELSIF a.class = LReal THEN
			p := vyLongrealVec.NewLongrealObject( a.y );  varadr := ADDRESSOF( p( vyLongrealVec.tLONGREAL ).x )
		ELSIF a.class = Pointer THEN
			p := vyPointerVec.NewLongintObject( a.ptr );  varadr := ADDRESSOF( p( vyPointerVec.tLONGINT ).i )
		END;
		RETURN p
	END AsPointer;

	PROCEDURE ValPointer( VAR val: Value;  p: ANY );
	BEGIN
		IF p # NIL THEN val.class := Pointer;  val.ptr := SYSTEM.VAL( SIGNED32, p );   (* val.i := val.ptr; *) val.p := p END
	END ValPointer;

	PROCEDURE EvalOp( VAR stack: Stack;  op: OpItem;  VAR val: Value );
	VAR a, b: Value;  p1, p2, res: ANY;  varadr: SIGNED32;
	BEGIN
		val.class := Undef;
		IF op.op = "+" THEN
			Eval( stack, b );  Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN
				IF b.class IN {SInt, Int, LInt} THEN val.i := a.i + b.i;  val.class := LInt
				ELSIF b.class = Real THEN val.x := a.i + b.x;  val.class := Real
				ELSIF b.class = LReal THEN val.y := a.i + b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  Ln;  Str( "AddOp Types:" );  OutType( p1 );  OutType( p2 );
					antsExpressionsObjects.AddPtr( res, p1, p2 );  Ln;  Str( "Res Type:" );  OutType( res );  ValPointer( val, res );  OutVal( val )
				END
			ELSIF a.class = Char THEN
				IF b.class = Char THEN val.s[0] := a.c;  val.s[1] := b.c;  val.s[2] := 0X;  val.class := String
				ELSIF b.class = String THEN val.s[0] := a.c;  val.s[1] := 0X;  Strings.Append( val.s, b.s );  val.class := String
				END
			ELSIF a.class = Real THEN
				IF b.class IN {SInt, Int, LInt} THEN val.x := a.x + b.i;  val.class := Real
				ELSIF b.class = Real THEN val.x := a.x + b.x;  val.class := Real
				ELSIF b.class = LReal THEN val.y := a.x + b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.AddPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = LReal THEN
				IF b.class IN {SInt, Int, LInt} THEN val.y := a.y + b.i;  val.class := LReal
				ELSIF b.class = Real THEN val.y := a.y + b.x;  val.class := LReal
				ELSIF b.class = LReal THEN val.y := a.y + b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.AddPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = String THEN
				IF b.class = String THEN val.s := a.s;  Strings.Append( val.s, b.s );  val.class := String
				ELSIF b.class = Char THEN val.s := a.s;  b.s[0] := b.c;  b.s[1] := 0X;  Strings.Append( val.s, b.s );  val.class := String
				END
			ELSIF a.class = Pointer THEN
				IF b.class = Pointer THEN
					Ln;  Str( "Add Operation on pointers .." );  p1 := a.p;  p2 := b.p;  antsExpressionsObjects.AddPtr( res, p1, p2 );  ValPointer( val, res )
				ELSE
					p1 := a.p;  p2 := AsPointer( b, varadr );
					IF p2 # NIL THEN antsExpressionsObjects.AddPtr( res, p1, p2 );  ValPointer( val, res ) END
				END
			END
		ELSIF op.op = "-" THEN
			Eval( stack, b );  Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN
				IF b.class IN {SInt, Int, LInt} THEN val.i := a.i - b.i;  val.class := LInt
				ELSIF b.class = Real THEN val.x := a.i - b.x;  val.class := Real
				ELSIF b.class = LReal THEN val.y := a.i - b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.SubPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = Real THEN
				IF b.class IN {SInt, Int, LInt} THEN val.x := a.x - b.i;  val.class := Real
				ELSIF b.class = Real THEN val.x := a.x - b.x;  val.class := Real
				ELSIF b.class = LReal THEN val.y := a.x - b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.SubPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = LReal THEN
				IF b.class IN {SInt, Int, LInt} THEN val.y := a.y - b.i;  val.class := LReal
				ELSIF b.class = Real THEN val.y := a.y - b.x;  val.class := LReal
				ELSIF b.class = LReal THEN val.y := a.y - b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.SubPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = Pointer THEN
				IF b.class = Pointer THEN
					Ln;  Str( "Add Operation on pointers .." );  p1 := a.p;  p2 := b.p;  antsExpressionsObjects.SubPtr( res, p1, p2 );  ValPointer( val, res )
				ELSE
					p1 := a.p;  p2 := AsPointer( b, varadr );
					IF p2 # NIL THEN antsExpressionsObjects.SubPtr( res, p1, p2 );  ValPointer( val, res ) END
				END
			END
		ELSIF op.op = "*" THEN
			Eval( stack, b );  Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN
				IF b.class IN {SInt, Int, LInt} THEN val.i := a.i * b.i;  val.class := LInt
				ELSIF b.class = Real THEN val.x := a.i * b.x;  val.class := Real
				ELSIF b.class = LReal THEN val.y := a.i * b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.MultPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = Real THEN
				IF b.class IN {SInt, Int, LInt} THEN val.x := a.x * b.i;  val.class := Real
				ELSIF b.class = Real THEN val.x := a.x * b.x;  val.class := Real
				ELSIF b.class = LReal THEN val.y := a.x * b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.MultPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = LReal THEN
				IF b.class IN {SInt, Int, LInt} THEN val.y := a.y * b.i;  val.class := LReal
				ELSIF b.class = Real THEN val.y := a.y * b.x;  val.class := LReal
				ELSIF b.class = LReal THEN val.y := a.y * b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.MultPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = Pointer THEN
				IF b.class = Pointer THEN
					Ln;  Str( "Add Operation on pointers .." );  p1 := a.p;  p2 := b.p;  antsExpressionsObjects.MultPtr( res, p1, p2 );
					IF res # NIL THEN ValPointer( val, res ) END
				ELSE
					p1 := a.p;  p2 := AsPointer( b, varadr );
					IF p2 # NIL THEN antsExpressionsObjects.MultPtr( res, p1, p2 );  ValPointer( val, res ) END
				END
			END
		ELSIF op.op = "/" THEN
			Eval( stack, b );  Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN
				IF b.class IN {SInt, Int, LInt} THEN val.x := a.i / b.i;  val.class := Real
				ELSIF b.class = Real THEN val.x := a.i / b.x;  val.class := Real
				ELSIF b.class = LReal THEN val.y := a.i / b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.DivPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = Real THEN
				IF b.class IN {SInt, Int, LInt} THEN val.x := a.x / b.i;  val.class := Real
				ELSIF b.class = Real THEN val.x := a.x / b.x;  val.class := Real
				ELSIF b.class = LReal THEN val.y := a.x / b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.DivPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = LReal THEN
				IF b.class IN {SInt, Int, LInt} THEN val.y := a.y / b.i;  val.class := LReal
				ELSIF b.class = Real THEN val.y := a.y / b.x;  val.class := LReal
				ELSIF b.class = LReal THEN val.y := a.y / b.y;  val.class := LReal
				ELSIF b.class = Pointer THEN
					p1 := AsPointer( a, varadr );  p2 := b.p;  antsExpressionsObjects.DivPtr( res, p1, p2 );  ValPointer( val, res )
				END
			ELSIF a.class = Pointer THEN
				IF b.class = Pointer THEN
					Ln;  Str( "Add Operation on pointers .." );  p1 := a.p;  p2 := b.p;  antsExpressionsObjects.DivPtr( res, p1, p2 );  ValPointer( val, res )
				ELSE
					p1 := a.p;  p2 := AsPointer( b, varadr );
					IF p2 # NIL THEN antsExpressionsObjects.DivPtr( res, p1, p2 );  ValPointer( val, res ) END
				END
			END
		ELSIF op.op = "MOD" THEN
			Eval( stack, b );  Eval( stack, a );
			IF (a.class IN {SInt, Int, LInt}) & (b.class IN {SInt, Int, LInt}) THEN val.i := a.i MOD b.i;  val.class := LInt END
		ELSIF op.op = "DIV" THEN
			Eval( stack, b );  Eval( stack, a );
			IF (a.class IN {SInt, Int, LInt}) & (b.class IN {SInt, Int, LInt}) THEN val.i := a.i DIV b.i;  val.class := LInt END
		ELSIF op.op = "NEG" THEN
			Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN val.i := -a.i;  val.class := LInt
			ELSIF a.class = Real THEN val.x := -a.x;  val.class := Real
			ELSIF a.class = LReal THEN val.y := -a.y;  val.class := LReal
			ELSIF a.class = Pointer THEN
				p1 := a.p;  antsExpressionsObjects.NegPtr( res, p1 );
				IF res # NIL THEN ValPointer( val, res ) END
			END
		ELSIF op.op = "ABS" THEN
			Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN val.i := ABS( a.i );  val.class := LInt
			ELSIF a.class = Real THEN val.x := ABS( a.x );  val.class := Real
			ELSIF a.class = LReal THEN val.y := ABS( a.y );  val.class := LReal
			END
		ELSIF op.op = "ENTIER" THEN
			Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN val.i := a.i;  val.class := LInt
			ELSIF a.class = Real THEN val.i := ENTIER( a.x );  val.class := LInt
			ELSIF a.class = LReal THEN val.i := ENTIER( a.y );  val.class := LInt
			END
		ELSIF op.op = "ORD" THEN
			Eval( stack, a );
			IF a.class = Char THEN val.i := ORD( a.c );  val.class := LInt
			ELSIF a.class IN {SInt, Int, LInt} THEN val.i := a.i;  val.class := LInt
			END
		ELSIF op.op = "CHR" THEN
			Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN val.c := CHR( a.i );  val.class := Char
			ELSIF a.class = Char THEN val.c := a.c;  val.class := Char
			END
		ELSIF op.op = "SHORT" THEN
			Eval( stack, a );
			IF a.class IN {SInt, Int} THEN val.i := a.i;  val.class := SInt
			ELSIF a.class = LInt THEN val.i := a.i;  val.class := Int
			ELSIF a.class = Real THEN val.x := a.x;  val.class := Real
			ELSIF a.class = LReal THEN val.x := SHORT( a.y );  val.class := Real
			END
		ELSIF op.op = "LONG" THEN
			Eval( stack, a );
			IF a.class = SInt THEN val.i := a.i;  val.class := Int
			ELSIF a.class IN {Int, LInt} THEN val.i := a.i;  val.class := LInt
			ELSIF a.class = Real THEN val.y := a.x;  val.class := LReal
			ELSIF a.class = LReal THEN val.y := a.y;  val.class := LReal
			END
		ELSIF op.op = "=" THEN
			Eval( stack, b );  Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.i = b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.i = b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.i = b.y;  val.class := Bool
				END
			ELSIF a.class = Real THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.x = b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.x = b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.x = b.y;  val.class := Bool
				END
			ELSIF a.class = LReal THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.y = b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.y = b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.y = b.y;  val.class := Bool
				END
			ELSIF (a.class = Char) & (b.class = Char) THEN val.b := a.c = b.c;  val.class := Bool
			ELSIF (a.class = Bool) & (b.class = Bool) THEN val.b := a.b = b.b;  val.class := Bool
			END
		ELSIF (op.op = "#") OR (op.op = "<>") THEN
			Eval( stack, b );  Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.i # b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.i # b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.i # b.y;  val.class := Bool
				END
			ELSIF a.class = Real THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.x # b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.x # b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.x # b.y;  val.class := Bool
				END
			ELSIF a.class = LReal THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.y # b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.y # b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.y # b.y;  val.class := Bool
				END
			ELSIF (a.class = Char) & (b.class = Char) THEN val.b := a.c # b.c;  val.class := Bool
			ELSIF (a.class = Bool) & (b.class = Bool) THEN val.b := a.b # b.b;  val.class := Bool
			END
		ELSIF op.op = "<" THEN
			Eval( stack, b );  Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.i < b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.i < b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.i < b.y;  val.class := Bool
				END
			ELSIF a.class = Real THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.x < b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.x < b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.x < b.y;  val.class := Bool
				END
			ELSIF a.class = LReal THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.y < b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.y < b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.y < b.y;  val.class := Bool
				END
			ELSIF (a.class = Char) & (b.class = Char) THEN val.b := a.c < b.c;  val.class := Bool
			END
		ELSIF op.op = "<=" THEN
			Eval( stack, b );  Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.i <= b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.i <= b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.i <= b.y;  val.class := Bool
				END
			ELSIF a.class = Real THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.x <= b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.x <= b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.x <= b.y;  val.class := Bool
				END
			ELSIF a.class = LReal THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.y <= b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.y <= b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.y <= b.y;  val.class := Bool
				END
			ELSIF (a.class = Char) & (b.class = Char) THEN val.b := a.c <= b.c;  val.class := Bool
			END
		ELSIF op.op = ">" THEN
			Eval( stack, b );  Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.i > b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.i > b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.i > b.y;  val.class := Bool
				END
			ELSIF a.class = Real THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.x > b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.x > b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.x > b.y;  val.class := Bool
				END
			ELSIF a.class = LReal THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.y > b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.y > b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.y > b.y;  val.class := Bool
				END
			ELSIF (a.class = Char) & (b.class = Char) THEN val.b := a.c > b.c;  val.class := Bool
			END
		ELSIF op.op = ">=" THEN
			Eval( stack, b );  Eval( stack, a );
			IF a.class IN {SInt, Int, LInt} THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.i >= b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.i >= b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.i >= b.y;  val.class := Bool
				END
			ELSIF a.class = Real THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.x >= b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.x >= b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.x >= b.y;  val.class := Bool
				END
			ELSIF a.class = LReal THEN
				IF b.class IN {SInt, Int, LInt} THEN val.b := a.y >= b.i;  val.class := Bool
				ELSIF b.class = Real THEN val.b := a.y >= b.x;  val.class := Bool
				ELSIF b.class = LReal THEN val.b := a.y >= b.y;  val.class := Bool
				END
			ELSIF (a.class = Char) & (b.class = Char) THEN val.b := a.c >= b.c;  val.class := Bool
			END
		ELSIF (op.op = "&") OR (op.op = "AND") THEN
			Eval( stack, b );  Eval( stack, a );
			IF (a.class = Bool) & (b.class = Bool) THEN val.b := a.b & b.b;  val.class := Bool END
		ELSIF op.op = "OR" THEN
			Eval( stack, b );  Eval( stack, a );
			IF (a.class = Bool) & (b.class = Bool) THEN val.b := a.b OR b.b;  val.class := Bool END
		ELSIF (op.op = "~") OR (op.op = "NOT") THEN
			Eval( stack, a );
			IF (a.class = Bool) & (b.class = Bool) THEN val.b := ~a.b;  val.class := Bool END
		ELSIF op.op = ":=" THEN Assign( stack, val )
		ELSIF op.op = "<<" THEN InFile( stack, val )
		ELSIF op.op = ">>" THEN OutFile( stack, val, FALSE )
		ELSIF op.op = ">>>" THEN OutFile( stack, val, TRUE )
		END;
		IF val.class = Undef THEN err( 100 ) END
	END EvalOp;

	PROCEDURE GetRefNum( mod: Modules.Module;  VAR i, num: SIGNED32 );
	VAR n, s: SIGNED32;  x: CHAR;
	BEGIN
		s := 0;  n := 0;  x := mod.refs[i];  INC( i );
		WHILE ORD( x ) >= 128 DO INC( n, ASH( ORD( x ) - 128, s ) );  INC( s, 7 );  x := mod.refs[i];  INC( i ) END;
		num := n + ASH( ORD( x ) MOD 64 - ORD( x ) DIV 64 * 64, s )
	END GetRefNum;

	PROCEDURE FindAdr( mod: Modules.Module;  obj: OPT.Object ): SIGNED32;
	VAR i, j, m, t, ofs: SIGNED32;  ch: CHAR;  found: BOOLEAN;
	BEGIN
		i := 0;  m := LEN( mod.refs^ );  ch := mod.refs[i];  INC( i );
		WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) DO  (* proc *)
			GetRefNum( mod, i, ofs );   (* pofs *)
			IF ch = 0F9X THEN
				GetRefNum( mod, i, t );   (* nofPars *)
				INC( i, 3 ) (* RetType, procLev, slFlag *)
			END;
			found := TRUE;  j := 0;
			REPEAT ch := mod.refs[i];  found := found & (ch = obj.name[j]);  INC( j );  INC( i ) UNTIL ch = 0X;   (* pname *)
			IF found THEN RETURN ADDRESSOF( mod.code[0] ) + ofs END;
			IF i < m THEN
				ch := mod.refs[i];  INC( i );   (* 1X | 3X | 0F8X | 0F9X *)
				WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO  (* var *)
					ch := mod.refs[i];  INC( i );   (* type *)
					IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
						GetRefNum( mod, i, t ) (* dim/tdadr *)
					END;
					GetRefNum( mod, i, ofs );   (* vofs *)
					found := TRUE;  j := 0;
					REPEAT ch := mod.refs[i];  found := found & (ch = obj.name[j]);  INC( j );  INC( i ) UNTIL ch = 0X;   (* vname *)
					IF found THEN RETURN mod.sb + ofs END;
					IF i < m THEN ch := mod.refs[i];  INC( i ) END  (* 1X | 3X | 0F8X | 0F9X *)
				END
			END
		END;
		RETURN 0
	END FindAdr;

	PROCEDURE FindObj( mod: Modules.Module;  name: ARRAY OF CHAR ): OPT.Object;
	VAR imp, self: OPS.Name;  obj: OPT.Object;  pos: SIGNED32;
	BEGIN
		COPY( Modules.extension, OPM.extension );  OPM.outputPath := "";  pos := OPM.curpos;
		(*	NEW(T);      Texts.Open(T, "");      Texts.OpenReader(R, T, 0);
	OPM.Init({}, R, Oberon.Log);      OPS.Init();     *)
		OPT.Init( imp );  COPY( mod.name, imp );  self := "$$";  OPT.OpenScope( 0, NIL );  OPT.Import( imp, imp, self );
		IF name # "" THEN obj := OPT.modules[1].right;  COPY( name, self ) ELSE obj := OPT.topScope;  COPY( mod.name, self ) END;
		OPT.CloseScope();

		WHILE obj # NIL DO
			IF obj.name > self THEN obj := obj.left
			ELSIF obj.name < self THEN obj := obj.right
			ELSE RETURN obj
			END
		END;
		RETURN NIL
	END FindObj;

	PROCEDURE SplitName( str: ARRAY OF CHAR;  VAR mod: Modules.Module;  VAR name: ARRAY OF CHAR );
	VAR i, j: SIGNED32;  done: BOOLEAN;
	BEGIN
		done := FALSE;  i := 0;  j := 0;
		WHILE str[i] # 0X DO
			IF (~done) & (str[i] = ".") THEN done := TRUE;  str[i] := 0X;  j := 0
			ELSIF str[i] = ":" THEN
				mod := NIL;  name[0] := 0X;  RETURN  (* to avoid filename handling of str *)
			ELSE name[j] := str[i];  INC( j )
			END;
			INC( i )
		END;
		IF j >= i THEN j := 0 END;
		name[j] := 0X;  mod := Modules.ThisMod( str );  Ln;  Str( "Splitted: " );  Str( name )
	END SplitName;

	PROCEDURE TryDefaultMods( str: ARRAY OF CHAR;  VAR mod: Modules.Module;  VAR name: ARRAY OF CHAR );
	VAR modn: ARRAY 256 OF CHAR;
	BEGIN
		modn := "antsExpressionsDefaults";  Strings.Append( modn, "." );  Strings.Append( modn, str );  SplitName( modn, mod, name );
		IF mod # NIL THEN
			IF FindObj( mod, name ) # NIL THEN RETURN END
		END;
		Ln;  Str( "trying MathL" );  WLog;  modn := "MathL";  Strings.Append( modn, "." );  Strings.Append( modn, str );  SplitName( modn, mod, name );
		IF mod # NIL THEN
			IF FindObj( mod, name ) # NIL THEN RETURN END
		END
	END TryDefaultMods;

	PROCEDURE IsTypeOf*( t: Types.Type;  ref: ARRAY OF CHAR ): BOOLEAN;
	VAR tname: ARRAY 128 OF CHAR;
		mod: Modules.Module;  thistype: Types.Type;  level: SIGNED16;
	BEGIN
		SplitName( ref, mod, tname );
		IF mod # NIL THEN
			thistype := Types.This( mod, tname );  level := Types.LevelOf( t );
			WHILE (level >= 0) DO
				IF thistype = t THEN RETURN TRUE END;
				level := level - 1;
				IF level >= 0 THEN t := Types.BaseOf( t, level ) END
			END;
			RETURN FALSE
		ELSE RETURN FALSE
		END
	END IsTypeOf;

	PROCEDURE PointerIs*( p: ANY;  ref: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		RETURN IsTypeOf( Types.TypeOf( p ), ref )
	END PointerIs;

	PROCEDURE GetObjClass( obj: OPT.Object ): SIGNED8;
	BEGIN
		WObj( obj );
		IF obj.typ.form IN {Bool, Char, SInt, Int, LInt, Real, LReal, NoTyp, Pointer, String, Comp, ProcTyp} THEN
			RETURN obj.typ.form
		ELSE RETURN Undef
		END
	END GetObjClass;

	PROCEDURE EvalConObj( obj: OPT.Object;  VAR val: Value );
	BEGIN
		val.class := GetObjClass( obj );
		CASE val.class OF
		Bool:
				val.b := obj.conval.intval # 0
		| Char:
				val.c := CHR( obj.conval.intval )
		| SInt, Int, LInt:
				val.i := obj.conval.intval
		| Real:
				val.x := SHORT( obj.conval.realval )
		| LReal:
				val.y := obj.conval.realval
		| String:
				COPY( obj.conval.ext^, val.s ) (* this is the pointer on a string *)
		ELSE val.class := Undef;  err( 63 )
		END
	END EvalConObj;

	PROCEDURE FindPtrs( typ: OPT.Struct;  adr: SIGNED32 );
	VAR fld: OPT.Object;  i, n, s: SIGNED32;  btyp: OPT.Struct;

		PROCEDURE Add( adr: SIGNED32 );
		VAR table: PtrTable;
		BEGIN
			Ln;  Str( "Adding Pointer: " );  WInt( adr, 10 );
			IF nofptrs >= LEN( ptrTab ) THEN
				NEW( table, LEN( ptrTab ) * 2 );
				FOR i := 0 TO LEN( ptrTab ) - 1 DO table[i] := ptrTab[i] END;
				ptrTab := table
			END;
			ptrTab[nofptrs] := adr;  INC( nofptrs )
		END Add;

	BEGIN
		IF typ.form = Pointer THEN
			foundSTRING := FALSE;
			IF (typ.sysflag = 0) THEN Add( adr ) END
		ELSIF typ.comp = Record THEN
			foundSTRING := FALSE;  btyp := typ.BaseTyp;
			IF btyp # NIL THEN FindPtrs( btyp, adr ) END;
			fld := typ.link;
			WHILE (fld # NIL ) & (fld.mode = Fld) DO
				IF (fld.name = OPT.HdPtrName) THEN Add( adr )
				ELSIF fld.sysflag # untraced THEN FindPtrs( fld.typ, fld.adr + adr )
				END;
				fld := fld.link
			END
		ELSIF typ.comp = StaticArr THEN
			Ln;  Str( "Is Static Array" );  btyp := typ.BaseTyp;  n := typ.n;
			WHILE btyp.comp = StaticArr DO n := btyp.n * n;  btyp := btyp.BaseTyp END;
			IF (btyp.form = Pointer) OR (btyp.comp IN {Record, DynArr}) THEN
				i := 0;  s := btyp.size;
				WHILE i < n DO FindPtrs( btyp, i * s + adr );  INC( i ) END
			END
		ELSIF typ.comp = DynArr THEN Ln;  Str( "Is Dynamic Array " );  Add( adr )
		ELSE foundSTRING := FALSE
		END
	END FindPtrs;

	PROCEDURE EvalVarObj( obj: OPT.Object;  VAR val: Value );
	VAR ch: CHAR;  i: SIGNED32;  adr: SIGNED32;
	BEGIN
		IF (obj.adr # 0) & (obj.vis IN {external, externalR}) THEN
			val.class := GetObjClass( obj );
			CASE val.class OF
			Bool:
					SYSTEM.GET( obj.adr, val.b )
			| Char:
					SYSTEM.GET( obj.adr, val.c )
			| SInt:
					val.i := SYSTEM.GET8( obj.adr )
			| Int:
					val.i := SYSTEM.GET16( obj.adr )
			| LInt:
					val.i := SYSTEM.GET32( obj.adr )
			| Real:
					SYSTEM.GET( obj.adr, val.x )
			| LReal:
					SYSTEM.GET( obj.adr, val.y )
			| Pointer:
					val.ptr := SYSTEM.GET32( obj.adr );  val.p := SYSTEM.VAL( ANY, val.ptr );   (* val.i := SYSTEM.GET32(obj.adr); *)
			| String:
					Ln;  Str( "? String in EvalVarObj ? strange !" );  WLog;  val.class := Undef;
			| Comp:
					Ln;  Str( "comp object, obj.typ.comp := " );  WInt( obj.typ.comp, 5 );  nofptrs := 0;  foundSTRING := TRUE;  FindPtrs( obj.typ, obj.adr );
					IF ~foundSTRING THEN Ln;  Str( "Sorry, can only handle strings as composite objects .." );  val.class := Undef
					ELSIF nofptrs > 0 THEN Ln;  Str( "found pointers, cannot go on, sorry ... " );  val.class := Undef
					ELSE
						Ln;  Str( "obj.adr: " );  WInt( obj.adr, 10 );  Ln;  Str( "obj.linkadr" );  WInt( obj.linkadr, 10 );  Ln;  Str( "obj.typ.n" );  WInt( obj.typ.n, 10 );  Ln;
						Str( "obj.typ.size" );  WInt( obj.typ.size, 10 );  i := 0;  adr := obj.adr;  SYSTEM.GET( adr, ch );
						WHILE ch # 0X DO val.s[i] := ch;  INC( i );  INC( adr );  SYSTEM.GET( adr, ch ) END;
						val.s[i] := 0X;  val.class := String;  val.i := obj.adr
					END
			ELSE val.class := Undef;  err( 112 )
			END
		ELSE val.class := Undef;  err( 0 )
		END
	END EvalVarObj;

	PROCEDURE PopWrVar( VAR stack: Stack;  VAR global: BOOLEAN;  VAR nil: BOOLEAN ): OPT.Object;
	VAR var: Item;  mod: Modules.Module;  item: OPS.Name;  obj: OPT.Object;  createobj: BOOLEAN;  val: Value;
	BEGIN
	(* IN: global acts as controlling parameter, TRUE means Object must be found , FALSE means create default object *)
		(* OUT: global indicates if parameter in global name-space found *)
		createobj := global;  global := FALSE;  var := stack.top;
		IF (var # NIL ) & (var IS NameItem) THEN
			Ln;  Str( "valid variable" );  stack.top := var.next;  INC( itnr );  SplitName( var( NameItem ).name, mod, item );
			IF mod = NIL THEN TryDefaultMods( var( NameItem ).name, mod, item ) END;
			IF (mod # NIL ) & (item # "") THEN
				Ln;  Str( "mod # NIL and item: " );  Str( item );  obj := FindObj( mod, item );
				IF (obj # NIL ) & (obj.mode = Var) & (obj.vis = external) THEN
					obj.adr := FindAdr( mod, obj );  Ln;  Str( "PopWrVar found addr: " );  WInt( obj.adr, 10 );  WLog;  WObj( obj );
					IF obj.adr # 0 THEN RETURN obj END
				ELSIF (obj # NIL ) THEN RETURN NIL
				END
			END;
			val.ptr := 0;  val.adr := 0;
			IF EvalGlobalObj( var( NameItem ).name, val ) OR createobj THEN  (* Named Object is global *)
				obj := OPT.NewObj();  obj.typ := OPT.NewStr( val.class, Basic );  obj.adr := val.ptr;
				IF val.class # Pointer THEN obj.linkadr := val.adr ELSE obj.linkadr := 0 END;
				COPY( var( NameItem ).name, obj.name );  global := TRUE;  RETURN obj
			END
		ELSIF var = NIL THEN nil := TRUE
		END;
		Ln;  Str( "PopWrVar reported nothing" );  RETURN NIL
	END PopWrVar;

	PROCEDURE ShortInt( VAR val: Value );
	BEGIN
		IF (val.i >= MIN( SIGNED8 )) & (val.i <= MAX( SIGNED8 )) THEN val.class := SInt
		ELSIF (val.i >= MIN( SIGNED16 )) & (val.i <= MAX( SIGNED16 )) THEN val.class := Int
		ELSE val.class := LInt
		END
	END ShortInt;

	PROCEDURE AssignObj*( this, res: Objects.Object ): BOOLEAN;
	VAR t: Types.Type;  o: OPT.Object;  a2, a1: SIGNED32;
	BEGIN
		(* if same type then copy else new object *)
		IF antsExpressionsObjects.Assign( this, res ) THEN Ln;  Str( "Assign in anteEO" );  OutType( this );  OutType( res );  RETURN TRUE END;

		IF Types.TypeOf( this ) = Types.TypeOf( res ) THEN
			Ln;  Str( "same types" );  t := Types.TypeOf( this );  OutType( t );  o := FindObj( t.mod, t.name );
			IF o # NIL THEN
				IF o.typ = NIL THEN RETURN FALSE END;
				OPT.typSize( o.typ, FALSE );  WObj( o );  a1 := ADDRESSOF( this^ );  a2 := ADDRESSOF( res^ );
				(* copy content of this^to res^, this is a dangerous operation ! *)
				SYSTEM.MOVE( a2, a1, SHORT( o.typ.size ) )
			ELSE Ln;  Str( "NOT found obj " )
			END;

			RETURN TRUE
		END;
		RETURN FALSE
	END AssignObj;

	PROCEDURE OutFile( VAR stack: Stack;  VAR res: Value;  append: BOOLEAN );
	VAR ptr1, ptr2: ANY;  file: Value;  f: Files.File;  R: Files.Rider;  len: SIGNED32;  l: Objects.Library;  M: Objects.BindMsg;
		gen: ARRAY 64 OF CHAR;
		fM: Objects.FileMsg;  n: vyName.tNameArray;  pos: SIGNED32;  varadr: SIGNED32;
	BEGIN
		Eval( stack, file );  Eval( stack, res );  Ln;  Str( "OutVal: " );  OutVal( res );  Ln;  Str( "To File" );  OutVal( file );
		IF file.class = String THEN
			IF res.class # Pointer THEN
				IF res.adr # 0 THEN res.ptr := res.adr;  res.p := Ptr( res.adr );  res.class := Pointer;  Ln;  Str( "res.adr # 0 in Outfile" );  WLog;  OutVal( res )
				ELSE
					ptr2 := AsPointer( res, varadr );
					IF ptr2 # NIL THEN res.p := ptr2;  res.ptr := SYSTEM.VAL( SIGNED32, ptr2 );  res.class := Pointer END
				END  (* IS global object *)
			END;
			IF res.class = Pointer THEN
				ptr1 := res.p;
				IF ptr1 = NIL THEN ptr1 := SYSTEM.VAL( ANY, res.ptr ) END;
				IF ptr1 IS Objects.Object THEN
					WITH ptr1: Objects.Object DO
						IF ptr1.handle = NIL THEN Nt;  Red;  Ln;  Str( "Problem: no handler" );  WLog;  Black;  Nt;  RETURN END;
						IF ~append THEN f := Files.New( file.s );  pos := 0
						ELSE
							f := Files.Old( file.s );
							IF f = NIL THEN f := Files.New( file.s );  pos := 0 ELSE pos := Files.Length( f ) END
						END;
						IF f = NIL THEN Nt;  Red;  Ln;  Str( "Cannot write to: " );  Str( file.s );  Black;  Nt;  RETURN END;
						IF pos = 0 THEN Nt;  Green;  Ln;  Str( "Created " );  Str( file.s );  Black;  Nt END;
						Files.Set( R, f, pos );  gen := "";  Attributes.GetString( ptr1, "Gen", gen );
						IF gen = "" THEN Nt;  Red;  Ln;  Str( "Handler doesn't report gen Proc" );  WLog;  Black;  Nt;  RETURN END;
						Ln;  Str( "Gen: " );  Str( gen );

						Files.WriteString( R, gen );

						pos := Files.Pos( R );

						NEW( l );  Objects.OpenLibrary( l );  Objects.Stamp( M );  M.lib := l;  ptr1.handle( ptr1, M );
						Objects.StoreLibrary( l, f, pos, len );  Files.Set( R, f, pos + len );

						Objects.Stamp( fM );  fM.id := Objects.store;  fM.R := R;  fM.len := 0;  ptr1.handle( ptr1, fM );  R := fM.R;
						IF ptr1 IS vyBase.Object THEN
							WITH ptr1: vyBase.Object DO vyName.GetObjId( ptr1, n );  Files.WriteString( R, n );  Ln;  Str( "Internal name stored as: " );  Str( n )
							END;
						ELSE Files.WriteString( R, res.name )
						END;
						Files.Register( f );  Note := TRUE;  Ln;  Str( "Wrote To File: " );  OutVal( res );  Note := FALSE;  res.class := NoTyp;  RETURN
					END;
				ELSE
				END
			END
		END;
		res.class := Undef
	END OutFile;

	PROCEDURE InFile( VAR stack: Stack;  VAR res: Value );
	VAR class: SIGNED8;  adr: SIGNED32;  ch: CHAR;  global: BOOLEAN;  ptr1: ANY;  f: Files.File;  R: Files.Rider;  file: Value;  obj: Objects.Object;
		l: Objects.Library;  len: SIGNED32;
		gen: ARRAY 64 OF CHAR;
		obj1: OPT.Object;  n: vyName.tNameArray;  fM: Objects.FileMsg;  nil: BOOLEAN;  isfirstitem: BOOLEAN;  pos: SIGNED32;
	BEGIN
		isfirstitem := (itnr = 1);  Eval( stack, file );  global := TRUE;  obj1 := PopWrVar( stack, global, nil );  Ln;  Str( "To File" );
		OutVal( file );
		IF obj1 # NIL THEN
			class := GetObjClass( obj1 );
			IF global THEN class := Pointer END;
			IF ~(class = Pointer) THEN Ln;  Str( "invalid var" );  err( 113 );  RETURN END
		ELSE
			(* IF ~nil THEN err(113); res.class := Undef; RETURN END; *)
		END;
		IF file.class = String THEN
			f := Files.Old( file.s );  Files.Set( R, f, 0 );  ch := 0X;  Files.ReadString( R, gen );
			WHILE ~R.eof DO

				Files.Read( R, ch );
				IF ch # Objects.LibBlockId THEN HALT( 200 ) END;
				pos := Files.Pos( R );  NEW( l );  Objects.OpenLibrary( l );  Ln;  Str( "Library Opened" );  WLog;  Objects.LoadLibrary( l, f, pos, len );
				Files.Set( R, f, pos + len );

				obj := Gadgets.CreateObject( gen );  obj.lib := l;
				IF (obj = NIL ) OR (obj.handle = NIL ) THEN Ln;  Str( "Invalid Object in file" );  WLog;  RETURN END;
				Objects.Stamp( fM );  fM.id := Objects.load;  fM.R := R;  fM.len := 0;  obj.handle( obj, fM );  R := fM.R;
				Files.ReadString( R, n );  Ln;  Str( "Object internal name was:" );  Str( n );  Ln;  Str( "itnr: " );  WInt( itnr, 10 );
				IF (obj1 = NIL ) & (isfirstitem) (* is no assignment and not part of expression *) THEN
					IF obj IS vyBase.Object THEN
						WITH obj: vyBase.Object DO
							IF n # "" THEN
								vyName.RegisterNamed( obj, n );  Note := TRUE;  Ln;  Green;  Str( "registered: " );  Str( n );  Str( " " );  Black;
								Note := FALSE
							ELSE Nt;  Ln;  Blue;  Str( "Unnamed Object " );  Black;  Nt
							END;
							res.class := Pointer;  res.ptr := SYSTEM.GET32( ADDRESSOF( obj ) );  res.p := SYSTEM.VAL( ANY, obj );  Nt;
							OutVal( res );  Nt
						END;
					ELSE
						IF n # "" THEN
							res.class := Pointer;  ptr1 := SYSTEM.VAL( ANY, obj );  res.p := ptr1;  res.ptr := SYSTEM.VAL( SIGNED32, ptr1 );
							res.adr := SYSTEM.VAL( SIGNED32, ptr1 );
							IF antsExpressionsObjects.AssignPointer( SYSTEM.VAL( SIGNED32, ptr1 ), 0, n ) THEN
								Note := TRUE;  Ln;  Green;  Str( "registered: " );  Str( n );  Str( " " );  Black;  Note := FALSE
							ELSE Nt;  Ln;  Red;  Str( "Could not assign Pointer to " );  Str( n );  Black;  Nt
							END
						ELSE Nt;  Ln;  Blue;  Str( "Unnamed Object " );  Black;  Nt
						END;
						Nt;  OutVal( res );  Nt
					END
				END;
				Files.ReadString( R, gen )
			END;
			Files.Close( f );  res.class := Undef;
			IF obj = NIL THEN Note := TRUE;  Ln;  Red;  Str( "No Obj loaded" );  Black;  Note := FALSE;  WLog;  RETURN END;
			ptr1 := obj;  Ln;  Str( "Found object: " );  OutType( ptr1 );  res.class := Pointer;  ptr1 := SYSTEM.VAL( ANY, obj );  res.p := ptr1;
			res.ptr := SYSTEM.VAL( SIGNED32, ptr1 );  res.adr := SYSTEM.VAL( SIGNED32, ptr1 );  adr := SYSTEM.VAL( SIGNED32, ptr1 );
			IF obj IS vyBase.Object THEN
				WITH obj: vyBase.Object DO
					IF obj1 # NIL THEN vyName.RegisterNamed( obj, obj1.name ) END
				END;
			ELSE
				IF obj1 # NIL THEN
					IF antsExpressionsObjects.AssignPointer( adr, 0, obj1.name ) THEN END
				END
			END;
			IF (isfirstitem) & (obj1 = NIL ) THEN res.class := NoTyp
			ELSIF ~EvalPtrObj( SYSTEM.VAL( ANY, res.ptr ), res ) THEN  (* res.class := NoTyp; *)
			END;
			RETURN
		END;
		res.class := Undef
	END InFile;

	PROCEDURE Assign( VAR stack: Stack;  VAR res: Value );
	VAR obj: OPT.Object;  class: SIGNED8;  i, adr: SIGNED32;  ch: CHAR;  global: BOOLEAN;  ptr1, ptr2: ANY;  nil: BOOLEAN;  varadr: SIGNED32;
	BEGIN
		Eval( stack, res );  global := TRUE;  obj := PopWrVar( stack, global, nil );  Ln;  Str( "Trying to assign: " );  OutVal( res );
		IF obj # NIL THEN
			class := GetObjClass( obj );  Ln;  Str( "Class of result: " );  WClass( res.class );  Ln;  Str( "Class of obj: " );  WClass( class );  adr := obj.adr;
			IF obj.linkadr # 0 THEN varadr := obj.linkadr ELSE varadr := 0 END;
			CASE res.class OF
			Bool:
					IF class = Bool THEN SYSTEM.PUT( obj.adr, res.b );  RETURN END
			| Char:
					IF class = Char THEN SYSTEM.PUT( obj.adr, res.c );  RETURN END
			| SInt, Int, LInt:
					IF class = LInt THEN SYSTEM.PUT( obj.adr, res.i );  RETURN
					ELSIF class = Real THEN res.x := res.i;  SYSTEM.PUT( obj.adr, res.x );  RETURN
					ELSIF class = LReal THEN res.y := res.i;  SYSTEM.PUT( obj.adr, res.y );  RETURN
					ELSIF class IN {SInt, Int} THEN
						IF res.class > class THEN ShortInt( res ) END;
						IF (class = SInt) & (res.class = SInt) THEN SYSTEM.PUT8( obj.adr, res.i );  RETURN
						ELSIF res.class <= Int THEN SYSTEM.PUT16( obj.adr, res.i );  RETURN
						END
					ELSIF (class = Pointer) OR global THEN
						IF global & antsExpressionsObjects.AssignLongint( res.i, varadr, obj.name ) THEN RETURN END
					END
			| Real:
					IF class = Real THEN SYSTEM.PUT( obj.adr, res.x );  RETURN
					ELSIF class = LReal THEN SYSTEM.PUT( obj.adr, LONG( res.x ) );  RETURN
					ELSIF (class = Pointer) OR global THEN
						IF global & antsExpressionsObjects.AssignReal( res.x, varadr, obj.name ) THEN RETURN END
						(*ELSIF global THEN
				IF antsExpressionsObjects.AssignReal(res.x, 0, obj.name) THEN RETURN END*)
					END
			| LReal:
					IF class = LReal THEN SYSTEM.PUT( obj.adr, res.y );  RETURN
					ELSIF (class = Pointer) OR (global) THEN
						IF global & antsExpressionsObjects.AssignLReal( res.y, varadr, obj.name ) THEN RETURN END
						(*	ELSIF global THEN
				IF antsExpressionsObjects.AssignReal(res.x, 0, obj.name) THEN RETURN END*)
					END
			| Pointer:
					IF global THEN class := Pointer END;
					IF class = Pointer THEN
						Ln;  Str( "Assignment class is Pointer" );
						IF ~global THEN SYSTEM.PUT32( obj.adr, res.ptr )
						ELSE
							ptr2 := SYSTEM.VAL( ANY, res.ptr );
							IF ptr2 = NIL THEN Nt;  Red;  Ln;  Str( "Cannot assign NIL Pointer !" );  Black;  Nt;  RETURN END;
							IF obj.adr # 0 THEN
								IF obj.linkadr # 0 THEN ptr1 := SYSTEM.VAL( ANY, obj.linkadr );  Ln;  Str( "Used Linkadr" )
								ELSE ptr1 := SYSTEM.VAL( ANY, obj.adr )
								END;
								Ln;  Str( "Types in Assignment" );  OutType( ptr1 );  OutType( ptr2 );
								IF ptr1 IS Objects.Object THEN
									WITH ptr1: Objects.Object DO
										IF ptr2 IS Objects.Object THEN
											WITH ptr2: Objects.Object DO
												IF ~AssignObj( ptr1, ptr2 ) THEN
													IF ptr2 IS vyBase.Object THEN
														WITH ptr2: vyBase.Object DO
															vyName.RegisterNamed( ptr2, obj.name );  Ln;  Str( "Registered new Object: " );  Str( obj.name )
														END;
													ELSE
														IF antsExpressionsObjects.AssignPointer( SYSTEM.VAL( SIGNED32, ptr2 ), 0, obj.name ) THEN
															Ln;  Str( "Assign Pointer 1" )
														ELSE Ln;  Str( "Assign Pointer 1 failed" )
														END
													END;
													Ln;  Str( "Assigned in ObjectExpressions" )
												ELSE Ln;  Str( "AssignObj worked" )
												END
											END;
										ELSE Nt;  Ln;  Str( "Assignment of NON Objects.Object impossible" );  Nt;  res.class := Undef
										END
									END;
								ELSE Nt;  Ln;  Str( "Assignment of NON Objects.Object impossible" );  Nt;  res.class := Undef
								END
							ELSE
								IF ptr2 IS vyBase.Object THEN
									WITH ptr2: vyBase.Object DO vyName.RegisterNamed( ptr2, obj.name );  Ln;  Str( "Registered new Object: " );  Str( obj.name )
									END;
								ELSE
									IF antsExpressionsObjects.AssignPointer( SYSTEM.VAL( SIGNED32, ptr2 ), 0, obj.name ) THEN Ln;  Str( "AssignPointer 2" )
									ELSE Ln;  Str( "Assign Pointer 2 failed" )
									END
								END
							END
						END;
						RETURN
					END;
			| String:
					IF class = Comp THEN
						nofptrs := 0;  foundSTRING := TRUE;  FindPtrs( obj.typ, obj.adr );
						IF ~foundSTRING THEN Ln;  Str( "Sorry, can only handle strings as composite objects .." );  res.class := Undef
						ELSIF nofptrs > 0 THEN Ln;  Str( "found pointers, cannot go on, sorry ... " );  res.class := Undef
						ELSE
							i := 0;
							WHILE (res.s[i] # 0X) DO INC( i ) END;
							IF i >= obj.typ.n THEN Ln;  Str( "String too long, exceeds size of " );  WInt( obj.typ.n, 10 )
							ELSE
								i := 0;  adr := obj.adr;  ch := res.s[i];
								WHILE ch # 0X DO SYSTEM.PUT( adr, ch );  INC( i );  INC( adr );  ch := res.s[i] END;
								SYSTEM.PUT( adr, ch );  RETURN
							END
						END
					ELSE Ln;  Str( "Obj type is not comp, assign String only to comp string vars !" );  Ln;  Str( "class: " );  WClass( class )
					END
			ELSE
			END
		ELSE Ln;  Str( "Obj is NIL" )
		END;
		Ln;  Str( "Assignment failed" );  res.class := Undef;  err( 113 )
	END Assign;

	PROCEDURE PushLIntPar( VAR call: CallStack;  val: SIGNED32 );
	BEGIN
		DEC( call.i, 5 );  Ln;  Str( "call.i: " );  WInt( call.i, 2 );
		call.code[call.i] := 068X;   (* PUSH *)
		SYSTEM.PUT32( ADDRESSOF( call.code[call.i + 1] ), val )
	END PushLIntPar;

	PROCEDURE PushStringPar( VAR call: CallStack;  VAR s: ARRAY OF CHAR;  len: SIGNED32 ): BOOLEAN;
	VAR i, slen, long: SIGNED32;  j: SIGNED16;  ord: SIGNED32;

		PROCEDURE StringSize( s: ARRAY OF CHAR ): SIGNED32;
		(* returns string size of s INCLUDING the terminator 0X *)
		VAR i, l: SIGNED32;
		BEGIN
			i := 0;  l := LEN( s ) - 1;
			WHILE (s[i] # 0X) & (i < l) DO INC( i ) END;
			RETURN i + 1
		END StringSize;

	BEGIN
		slen := StringSize( s );  Ln;  Str( "Str len: " );  WInt( slen, 10 );
		IF slen > len THEN Ln;  Str( "String too long" );  RETURN FALSE
		ELSE
			i := 0;  j := 0;  long := 0;  ord := 1;
			WHILE (i < slen) DO
				IF j < 3 THEN long := long + ord * ORD( s[i] );  ord := ord * 256;  INC( j )
				ELSE long := long + ord * ORD( s[i] );  PushLIntPar( call, long );  ord := 1;  j := 0;  long := 0
				END;
				Ln;  WInt( i, 10 );  Str( " " );  Ch( s[i] );  INC( i )
			END;
			WHILE (i < len) DO
				IF j < 3 THEN long := long + ord * ORD( 0X );  ord := ord * 256;  INC( j )
				ELSE long := long + ord * ORD( s[i] );  PushLIntPar( call, long );  ord := 1;  j := 0;  long := 0
				END;
				INC( i )
			END;
			IF j > 0 THEN PushLIntPar( call, long ) END;
			WLog;  RETURN TRUE
		END
	END PushStringPar;

	PROCEDURE PushRealPar( VAR call: CallStack;  val: FLOAT32 );
	BEGIN
		PushLIntPar( call, Reals.Int( val ) )
	END PushRealPar;

	PROCEDURE PushLRealPar( VAR call: CallStack;  val: FLOAT64 );
	VAR l, h: SIGNED32;
	BEGIN
		Reals.IntL( val, l, h );  PushLIntPar( call, h );  PushLIntPar( call, l )
	END PushLRealPar;

	PROCEDURE PopCallPar( VAR stack: Stack;  VAR call: CallStack;  fpar: OPT.Object ): BOOLEAN;
	VAR apar: Value;  obj: OPT.Object;  class: SIGNED8;
		s: ARRAY 256 OF CHAR;
		adr: SIGNED32;  global: BOOLEAN;  nil: BOOLEAN;

		PROCEDURE PopString( ): BOOLEAN;
		BEGIN
			IF fpar.typ.comp = StaticArr THEN
				IF PushStringPar( call, apar.s, fpar.typ.n ) THEN RETURN TRUE END
			ELSIF fpar.typ.comp = OpenArr THEN
				Ln;  Str( "adress of string internal:" );  WInt( ADDRESSOF( apar.s ), 10 );
				IF apar.i # 0 THEN  (* adr of object stored *)
					PushLIntPar( call, apar.i );  Ln;  Str( "apar.i = " );  WInt( apar.i, 10 )
				ELSE
				(* need a tracable consistent object to pass, using global chain strings *)
					(* NEW(str); str.next := strings;
			str.s := apar.s;
			adr := ADDRESSOF(str.s);  *)
					adr := StringPtr( apar.s );
					(* adr := ADDRESSOF(apar.s) does NOT work, loosing object !*)
					PushLIntPar( call, adr )
				END;
				PushLIntPar( call, LEN( s ) );  RETURN TRUE
			END;
			RETURN FALSE
		END PopString;

	BEGIN
		class := GetObjClass( fpar );
		IF fpar.mode = Var THEN
			Ln;  Str( " fpar.mode = Var" );  Eval( stack, apar );  Ln;  Str( " apar.class=" );  WInt( apar.class, 10 );  WClass( apar.class );
			CASE apar.class OF
			Bool:
					IF class = Bool THEN PushLIntPar( call, SYSTEM.VAL(UNSIGNED8, apar.b ) );  RETURN TRUE END
			| Char:
					IF class = Char THEN PushLIntPar( call, ORD(apar.c ) );  RETURN TRUE
					ELSIF class = Comp THEN
						Ln;  Str( "PopString on CHAR" );
						IF PopString() THEN RETURN TRUE END
					END
			| SInt, Int, LInt:
					IF class = LInt THEN PushLIntPar( call, apar.i );  RETURN TRUE
					ELSIF class = Real THEN PushRealPar( call, apar.i );  RETURN TRUE
					ELSIF class = LReal THEN PushLRealPar( call, apar.i );  RETURN TRUE
					ELSIF class IN {SInt, Int} THEN
						IF apar.class > class THEN ShortInt( apar ) END;
						IF apar.class <= class THEN PushLIntPar( call, apar.i );  RETURN TRUE END
					END
			| Real:
					IF class = Real THEN PushRealPar( call, apar.x );  RETURN TRUE
					ELSIF class = LReal THEN PushLRealPar( call, apar.x );  RETURN TRUE
					END
			| LReal:
					IF class = LReal THEN PushLRealPar( call, apar.y );  RETURN TRUE END
			| Pointer:
					IF class = Pointer THEN PushLIntPar( call, apar.ptr );   (*apar.i*) RETURN TRUE END;
			| String:
					IF class = Comp THEN
						IF PopString() THEN RETURN TRUE END
					END;
					(* Push something..  *) Ln;  Str( "Should push string here " )
			ELSE
			END
		ELSIF fpar.mode = VarPar THEN
			Ln;  Str( "VarPar" );  WLog;  global := FALSE;  obj := PopWrVar( stack, global, nil );
			IF (obj # NIL ) & (class = obj.typ.form) THEN
				IF (fpar.typ.comp = OpenArr) THEN PushLIntPar( call, obj.adr );  PushLIntPar( call, obj.typ.n );  RETURN TRUE
				ELSIF (fpar.typ.comp = StaticArr) THEN
					IF fpar.typ.n >= obj.typ.n THEN PushLIntPar( call, obj.adr );  RETURN TRUE END
				ELSE PushLIntPar( call, obj.adr );  RETURN TRUE
				END
			ELSE Ln;  Str( "obj IS NIL" );  WLog
			END
		END;
		err( 113 );  RETURN FALSE
	END PopCallPar;

	PROCEDURE PI0Prepare( VAR call: CallStack;  obj: OPT.Object );
	BEGIN
		call.class := GetObjClass( obj );  call.obj := obj;  call.i := 0;  call.pc := 0
	END PI0Prepare;

	PROCEDURE PI1Result( VAR call: CallStack );   (* POINTER *)
	BEGIN
		(* procedure return types: *)
		IF call.class = NoTyp THEN call.pc := call.i;  call.resadr := 0
		ELSIF call.class # Undef THEN call.resadr := ADDRESSOF( call.code[call.i] );  INC( call.i, 8 );  call.pc := call.i
		ELSE err( 113 );  call.class := Undef
		END
	END PI1Result;

	PROCEDURE PI2Head( VAR call: CallStack );
	BEGIN
		IF call.class = Undef THEN RETURN END;
		call.code[call.i] := 055X;  INC( call.i );   (* PUSH EBP *)
		call.code[call.i] := 08BX;  INC( call.i );   (* MOV EBP, ESP *)
		call.code[call.i] := 0ECX;  INC( call.i );  Ln;  Str( "call.i " );  WInt( call.i, 10 )
	END PI2Head;

	PROCEDURE PI3CountPars( VAR call: CallStack );
	VAR fpar, prev, next: OPT.Object;
	BEGIN
		IF call.class = Undef THEN RETURN END;
		fpar := call.obj.link;  prev := NIL;  call.npar := 0;   (* variables stored in obj.link -> link -> link .. *)
		WHILE fpar # NIL DO
			next := fpar.link;  fpar.link := prev;  Ln;  Str( "Getting class for var:" );
			IF GetObjClass( fpar ) = LReal THEN
				IF fpar.mode = VarPar THEN
					(* is pointer *) INC( call.npar, 5 )
				ELSE INC( call.npar, 10 )
				END
			ELSIF fpar.typ.comp = OpenArr THEN
				IF fpar.mode = VarPar THEN INC( call.npar, 10 );  Ln;  Str( "OpenArr acc" ) ELSE INC( call.npar, 10 ) END
			ELSIF fpar.typ.comp = StaticArr THEN
				IF fpar.mode = VarPar THEN INC( call.npar, 5 ) ELSE INC( call.npar, 5 * (fpar.typ.n DIV 4) + 5 ) END
			ELSE INC( call.npar, 5 )
			END;
			prev := fpar;  fpar := next
		END;
		fpar := prev;  call.obj.link := fpar;  INC( call.i, call.npar )
	END PI3CountPars;

	PROCEDURE PI4SetPars( VAR call: CallStack;  VAR stack: Stack );
	VAR fpar, prev, next: OPT.Object;  done: BOOLEAN;
	BEGIN
		IF call.class = Undef THEN RETURN END;
		done := TRUE;  prev := NIL;  next := NIL;  fpar := call.obj.link;  Ln;  Str( "npar: " );  WInt( call.npar, 10 );  Ln;  Str( "call.i: " );
		WInt( call.i, 10 );  WLog;
		WHILE (fpar # NIL ) & done DO
			next := fpar.link;  fpar.link := prev;  done := PopCallPar( stack, call, fpar );  prev := fpar;  fpar := next
		END;
		call.obj.link := prev;

		IF ~done THEN call.class := Undef;  Ln;  Str( "PI4SetPars failed !" );  RETURN
		END;
		INC( call.i, call.npar );  Ln;  Str( "npar: " );  WInt( call.npar, 10 );  Ln;  Str( "call.i: " );  WInt( call.i, 10 );  WLog
	END PI4SetPars;

	PROCEDURE PI5CreateCall( VAR call: CallStack );
	BEGIN
		IF call.class = Undef THEN RETURN END;
		call.code[call.i] := 0E8X;  INC( call.i );   (* CALL *)
		SYSTEM.PUT32( ADDRESSOF( call.code[call.i] ), call.obj.adr - ADDRESSOF( call.code[call.i] ) - 4 );  INC( call.i, 4 )
	END PI5CreateCall;

	PROCEDURE PI6WriteResult( VAR call: CallStack );
	BEGIN
		IF call.class = Undef THEN RETURN END;
		IF call.resadr # 0 THEN
			IF call.class IN {Bool, Char, SInt, Int, LInt, Pointer} THEN
				call.code[call.i] := 0A3X;  INC( call.i );   (* MOV resadr, EAX *)
				SYSTEM.PUT32( ADDRESSOF( call.code[call.i] ), call.resadr );  INC( call.i, 4 )
			ELSIF call.class = Real THEN
				call.code[call.i] := 0D9X;  INC( call.i );   (* FSTP SINGLE resadr *)
				call.code[call.i] := 01DX;  INC( call.i );  SYSTEM.PUT32( ADDRESSOF( call.code[call.i] ), call.resadr );  INC( call.i, 4 );
				call.code[call.i] := 09BX;  INC( call.i ) (* WAIT *)
			ELSIF call.class = LReal THEN
				call.code[call.i] := 0DDX;  INC( call.i );   (* FSTP DOUBLE resadr *)
				call.code[call.i] := 01DX;  INC( call.i );  SYSTEM.PUT32( ADDRESSOF( call.code[call.i] ), call.resadr );  INC( call.i, 4 );
				call.code[call.i] := 09BX;  INC( call.i ) (* WAIT *)
			ELSE
				Ln;  Str( "resulting class is something strange .." );  WInt( call.class, 10 );  Ln;  Str( "DANGER !" );  call.class := Undef;  RETURN;
				(*HALT(99)*)
			END
		END
	END PI6WriteResult;

	PROCEDURE PI7Call( VAR call: CallStack );
	VAR cmd: Modules.Command;
	BEGIN
		IF call.class = Undef THEN RETURN END;
		call.code[call.i] := 08BX;  INC( call.i );   (* MOV ESP, EBP *)
		call.code[call.i] := 0E5X;  INC( call.i );
		call.code[call.i] := 05DX;  INC( call.i );   (* POP EBP *)
		call.code[call.i] := 0C3X;  INC( call.i );   (* RET *)
		cmd := SYSTEM.VAL( Modules.Command, ADDRESSOF( call.code[call.pc] ) );  cmd()
	END PI7Call;

	PROCEDURE PI8Finish( VAR call: CallStack;  VAR res: Value );
	BEGIN
		IF call.resadr # 0 THEN
			call.obj.adr := call.resadr;  res.class := call.class;  Ln;  Str( "evaluating res with: " );  WClass( res.class );  EvalVarObj( call.obj, res )
		ELSIF call.class # NoTyp THEN
			res.class := Undef;  Ln();  Str( "Result type of procedure # NoTyp but no return address!" );
			(* obj.adr := resadr;      EvalVarObj(obj, res) *)  (* no result ! *)
		ELSE res.class := call.class
		END
	END PI8Finish;

	PROCEDURE EvalProcObj( VAR stack: Stack;  obj: OPT.Object;  VAR res: Value );
	VAR call: CallStack;
	BEGIN
		IF (obj.adr # 0) & (obj.vis IN {external, externalR}) THEN
			Ln;  Str( "start call" );  PI0Prepare( call, obj );
			IF call.class = Undef THEN Ln;  Str( "PI0 failed" ) END;
			PI1Result( call );
			IF call.class = Undef THEN Ln;  Str( "PI1 failed" ) END;
			PI2Head( call );
			IF call.class = Undef THEN Ln;  Str( "PI2 failed" ) END;
			PI3CountPars( call );
			IF call.class = Undef THEN Ln;  Str( "PI3 failed" ) END;
			PI4SetPars( call, stack );
			IF call.class = Undef THEN Ln;  Str( "PI4 failed" ) END;
			PI5CreateCall( call );
			IF call.class = Undef THEN Ln;  Str( "PI5 failed" ) END;
			PI6WriteResult( call );
			IF call.class = Undef THEN Ln;  Str( "PI6 failed" ) END;
			PI7Call( call );
			IF call.class = Undef THEN Ln;  Str( "PI7 failed" ) END;
			PI8Finish( call, res );
			IF call.class = Undef THEN Ln;  Str( "PI8 failed" ) END;
			Ln;  Str( "end call: " );  WClass( res.class );  RETURN
		END;
		res.class := Undef;   (* err(0) *) Ln;  Str( "No resulting type of proc!" )
	END EvalProcObj;

(*
PROCEDURE EvalProcObj (VAR stack: Stack;           obj: OPT.Object;           VAR res: Value);
VAR fpar, prev, next: OPT.Object;          call: CallStack;           resadr, npar: SIGNED32;
cmd: Modules.Command;           done: BOOLEAN;
BEGIN
IF (obj.adr # 0) & (obj.vis IN {external, externalR}) THEN
(* check for no sysflag *)
(* procedure return types: *)
call.i := 0;           call.pc := 0;           res.class := GetObjClass(obj);
IF res.class = NoTyp THEN
resadr := 0
ELSIF res.class # Undef THEN
resadr := ADDRESSOF(call.code[call.i]);           INC(call.i, 8)
ELSE
Ln();
Str("type is undef, adr: ");
WInt(ADDRESSOF(call.code[call.i]), 10);
resadr := ADDRESSOF(call.code[call.i]);           INC(call.i, 8);
Ln;          Str("DANGER");
err(113)  ;     RETURN
END;
call.pc := call.i;
Ln;     Str("call.pc ");     WInt(call.pc, 10);
call.code[call.i] := 055X;           INC(call.i);           (* PUSH EBP *)
call.code[call.i] := 08BX;           INC(call.i);           (* MOV EBP, ESP *)
call.code[call.i] := 0ECX;           INC(call.i);
(* procedure variables types *)
Ln;     Str("call.i ");     WInt(call.i, 10);

fpar := obj.link;           prev := NIL;           npar := 0;     (* variables stored in obj.link -> link -> link .. *)
WHILE fpar # NIL DO
next := fpar.link;           fpar.link := prev;
Ln;     Str("Getting class for var:");
IF GetObjClass(fpar) = LReal THEN
IF  fpar.mode = VarPar THEN
(* is pointer *)INC(npar, 5)
ELSE
INC(npar, 10)
END
ELSIF fpar.typ.comp = OpenArr THEN
IF fpar.mode = VarPar THEN
INC(npar, 10);     Ln;     Str("OpenArr acc")
ELSE
INC(npar, 10)
END
ELSIF fpar.typ.comp = StaticArr THEN
IF fpar.mode = VarPar THEN
INC(npar, 5)
ELSE
INC(npar, 5 * (fpar.typ.n DIV 4) + 5)
END
ELSE
INC(npar, 5)
END;
prev := fpar;           fpar := next
END;
fpar := prev;           prev := NIL;
INC(call.i, npar);           done := TRUE;
Ln;     Str("npar: ");     WInt(npar, 10);
Ln;     Str("call.i: ");     WInt(call.i, 10);     WLog;
WHILE (fpar # NIL) & done DO
next := fpar.link;           fpar.link := prev;
done := PopCallPar(stack, call, fpar);
prev := fpar;           fpar := next
END;
IF ~done  THEN res.class := Undef;           RETURN END;
INC(call.i, npar);
Ln;     Str("npar: ");     WInt(npar, 10);
Ln;     Str("call.i: ");     WInt(call.i, 10);     WLog;

call.code[call.i] := 0E8X;           INC(call.i);           (* CALL *)
SYSTEM.PUT32(ADDRESSOF(call.code[call.i]), obj.adr - ADDRESSOF(call.code[call.i]) - 4);           INC(call.i, 4);
IF resadr # 0 THEN
IF res.class IN {Bool, Char, SInt, Int, LInt, Pointer} THEN
call.code[call.i] := 0A3X;           INC(call.i);           (* MOV resadr, EAX *)
SYSTEM.PUT32(ADDRESSOF(call.code[call.i]), resadr);           INC(call.i, 4)
ELSIF res.class = Real THEN
call.code[call.i] := 0D9X;           INC(call.i);           (* FSTP SINGLE resadr *)
call.code[call.i] := 01DX;           INC(call.i);
SYSTEM.PUT32(ADDRESSOF(call.code[call.i]), resadr);           INC(call.i, 4);
call.code[call.i] := 09BX;           INC(call.i)  (* WAIT *)
ELSIF res.class = LReal THEN
call.code[call.i] := 0DDX;           INC(call.i);           (* FSTP DOUBLE resadr *)
call.code[call.i] := 01DX;           INC(call.i);
SYSTEM.PUT32(ADDRESSOF(call.code[call.i]), resadr);           INC(call.i, 4);
call.code[call.i] := 09BX;           INC(call.i)  (* WAIT *)
ELSE
Ln;
Str("resulting class is something strange ..");
WInt(res.class, 10);
Ln;     Str("DANGER !");     res.class := Undef;           RETURN;
(*HALT(99)*)
END
END;
call.code[call.i] := 08BX;           INC(call.i);           (* MOV ESP, EBP *)
call.code[call.i] := 0E5X;           INC(call.i);
call.code[call.i] := 05DX;           INC(call.i);           (* POP EBP *)
call.code[call.i] := 0C3X;           INC(call.i);           (* RET *)
cmd := SYSTEM.VAL(Modules.Command, ADDRESSOF(call.code[call.pc]));
cmd();
IF resadr # 0 THEN
obj.adr := resadr;           EvalVarObj(obj, res)
ELSIF res.class # NoTyp THEN
Ln();           Str("Result type of procedure # NoTyp but no return address!");
(* obj.adr := resadr;      EvalVarObj(obj, res) *)(* no result ! *)
END;
RETURN
END;
res.class := Undef;           (* err(0) *)Ln;      Str("No resulting type of proc!")
END EvalProcObj;

*)

	PROCEDURE EvalPtrObj( obj: ANY;  VAR val: Value ): BOOLEAN;
	BEGIN
		IF obj = NIL THEN val.class := Undef;  RETURN FALSE END;
		IF obj IS vyLongrealVec.tLONGREAL THEN
			WITH obj: vyLongrealVec.tLONGREAL DO
				val.class := LReal;  val.y := obj.x;  val.ptr := ADDRESSOF( obj.x );  val.p := SYSTEM.VAL( ANY, val.ptr );
				val.adr := SYSTEM.GET32( ADDRESSOF( obj ) );  RETURN TRUE
			END;
		ELSIF obj IS vyRealVec.tREAL THEN
			WITH obj: vyRealVec.tREAL DO
				val.class := Real;  val.x := obj.x;  val.ptr := ADDRESSOF( obj.x );  val.p := SYSTEM.VAL( ANY, val.ptr );
				val.adr := SYSTEM.GET32( ADDRESSOF( obj ) );  RETURN TRUE
			END;
		ELSIF obj IS vyLongintVec.tLONGINT THEN
			WITH obj: vyLongintVec.tLONGINT DO
				val.class := LInt;  val.i := obj.i;  val.ptr := ADDRESSOF( obj.i );  val.p := SYSTEM.VAL( ANY, val.ptr );
				val.adr := SYSTEM.GET32( ADDRESSOF( obj ) );  RETURN TRUE;
			END;
		ELSIF obj IS vyIntVec.tINTEGER THEN
			WITH obj: vyIntVec.tINTEGER DO
				val.class := Int;  val.i := obj.i;  val.ptr := ADDRESSOF( obj.i );  val.p := SYSTEM.VAL( ANY, val.ptr );
				val.adr := SYSTEM.GET32( ADDRESSOF( obj ) );  RETURN TRUE
			END;
		ELSE RETURN FALSE
		END
	END EvalPtrObj;

	PROCEDURE EvalGlobalObj( name: ARRAY OF CHAR;  VAR val: Value ): BOOLEAN;
	VAR obj: Objects.Object;
	BEGIN
		Ln;  Str( "Eval Global Obj:" );  Str( name );  Ln;  obj := vyName.FindObj( name );

		IF obj # NIL THEN
			IF obj IS vyLongrealVec.tLONGREAL THEN
				WITH obj: vyLongrealVec.tLONGREAL DO
					Str( "LONGREAL" );  val.class := LReal;  COPY( name, val.name );  val.y := obj.x;  val.ptr := ADDRESSOF( obj.x );
					val.p := SYSTEM.VAL( ANY, val.ptr );  val.adr := SYSTEM.GET32( ADDRESSOF( obj ) );  RETURN TRUE
				END;
			ELSIF obj IS vyRealVec.tREAL THEN
				WITH obj: vyRealVec.tREAL DO
					Str( "REAL" );  val.class := Real;  COPY( name, val.name );  val.x := obj.x;  val.ptr := ADDRESSOF( obj.x );
					val.p := SYSTEM.VAL( ANY, val.ptr );  val.adr := SYSTEM.GET32( ADDRESSOF( obj ) );  RETURN TRUE
				END;
			ELSIF obj IS vyLongintVec.tLONGINT THEN
				WITH obj: vyLongintVec.tLONGINT DO
					Str( "LONGINT" );  val.class := LInt;  COPY( name, val.name );  val.i := obj.i;  val.ptr := ADDRESSOF( obj.i );
					val.p := SYSTEM.VAL( ANY, val.ptr );  val.adr := SYSTEM.GET32( ADDRESSOF( obj ) );  RETURN TRUE;
				END;
			ELSIF obj IS vyIntVec.tINTEGER THEN
				WITH obj: vyIntVec.tINTEGER DO
					Str( "INT" );  val.class := Int;  COPY( name, val.name );  val.i := obj.i;  val.ptr := ADDRESSOF( obj.i );
					val.p := SYSTEM.VAL( ANY, val.ptr );  val.adr := SYSTEM.GET32( ADDRESSOF( obj ) );  RETURN TRUE;
				END;
			ELSIF obj IS vyPointerVec.tLONGINT THEN
				WITH obj: vyPointerVec.tLONGINT DO
					Str( "PointerVec" );
					val.class := Pointer;  COPY( name, val.name );   (* val.i := obj.i;  *)
					val.ptr := obj.i;  val.p := SYSTEM.VAL( ANY, val.i );  val.adr := SYSTEM.GET32( ADDRESSOF( obj ) );  RETURN TRUE
				END;
			ELSE
				Str( "unknown: " );  Ln;  Str( "EvalGlobalObj found obj at: " );  WInt( ADDRESSOF( obj ), 10 );  val.class := Pointer;  COPY( name, val.name );
				(*val.i :=   SYSTEM.GET32(ADDRESSOF(obj));   *)  (* = SYSTEM.VAL(SIGNED32,obj) *)
				val.adr := SYSTEM.GET32( ADDRESSOF( obj ) );
				(*val.ptr := PtrPtr(val.adr);*)
				val.ptr := val.adr;  val.p := SYSTEM.VAL( ANY, val.adr );
				(* 		testLi := val.i;
			val.adr := ADDRESSOF(testLi);
			*)
				Ln;  Str( "EvalGlobal Obj, found pointers: " );  WInt( val.i, 10 );  WInt( val.adr, 10 );
				(* Ln; OutType(SYSTEM.VAL(ANY,val.i)); Gap;  OutType(SYSTEM.VAL(ANY,val.adr));  *)
				RETURN TRUE
			END
		ELSE
			val.class := Pointer;   (* object will be created as Pointer ! *)
			Str( "NIL" );  val.adr := 0;  val.ptr := 0;  COPY( name, val.name );  RETURN FALSE
		END
	END EvalGlobalObj;

	PROCEDURE EvalName( VAR stack: Stack;  itm: NameItem;  VAR val: Value );
	VAR mod: Modules.Module;  item: OPS.Name;  obj: OPT.Object;
	BEGIN
		SplitName( itm.name, mod, item );
		IF mod = NIL THEN TryDefaultMods( itm.name, mod, item ) END;
		IF (mod # NIL ) & (item # "") THEN
			obj := FindObj( mod, item );  val.obj := obj;  COPY( item, val.name );
			(*		IF obj#NIL THEN val.objadr := FindAdr(mod,obj); val.varadr := val.objadr END;  *)
			IF obj # NIL THEN
				IF obj.mode = Con THEN Ln;  Str( "obj.mode=Con" );  EvalConObj( obj, val );  RETURN
				ELSIF obj.mode = Var THEN
					Ln;  Str( "obj.mode=Var" );  obj.adr := FindAdr( mod, obj );  Ln;  Str( "Var adr=" );  WInt( obj.adr, 10 );
					IF GetObjClass( obj ) = ProcTyp THEN Ln;  Str( "ProcTypVar" );  EvalProcObj( stack, obj, val );  RETURN

					ELSE Ln;  Str( "No ProcTypVar" );  EvalVarObj( obj, val );  RETURN
					END
				ELSIF obj.mode = XProc THEN
					Ln;  Str( "XProc , finding adr.. " );  obj.adr := FindAdr( mod, obj );  Ln;  Str( "XProc adr" );  WInt( obj.adr, 10 );  EvalProcObj( stack, obj, val );
					RETURN
				ELSE Ln;  Str( "unknown name type, mode: " );  WInt( obj.mode, 3 )
				END
			ELSE
				Ln;  Str( "obj is NIL, trying global Name " );
				IF EvalGlobalObj( itm.name, val ) THEN RETURN END
			END
		ELSE
			Ln;  Str( "mod is NIL" );
			IF EvalGlobalObj( itm.name, val ) THEN RETURN END
		END;
		Ln();  Str( "Undef in EvalName" );  val.class := Undef;  err( 4 )
	END EvalName;

	PROCEDURE Eval*( VAR stack: Stack;  VAR val: Value );
	VAR itm: Item;
	BEGIN
		itm := stack.top;
		IF itm = NIL THEN val.class := Undef;  RETURN END;
		stack.top := itm.next;  INC( itnr );
		IF itm IS ValueItem THEN Ln;  Str( "itm is ValueItem" );  val := itm( ValueItem ).val
		ELSIF itm IS OpItem THEN Ln;  Str( "itm is OpItem" );  EvalOp( stack, itm( OpItem ), val )
		ELSIF itm IS NameItem THEN Ln;  Str( "itm is NameItem " );  EvalName( stack, itm( NameItem ), val )
		ELSE Ln;  Str( "itm is Undef !" );  val.class := Undef;  HALT( 99 )
		END
	END Eval;


(** Execution *)

	PROCEDURE Init*( VAR stack: Stack );
	BEGIN
		stack.top := NIL
	END Init;

	PROCEDURE CleanUp;
	BEGIN
		strings := NIL
	END CleanUp;

	PROCEDURE Exec*( T: Texts.Text );
	VAR R: Texts.Reader;  stack: Stack;  val: Value;  t: SIGNED32;
	BEGIN
		IF ~enableCR THEN WLog := WLogLog ELSE WLog := WLogToCaret END;
		t := Oberon.Time();  Ln;  Str( "time 0: " );  WInt( Oberon.Time() - t, 10 );
		IF T # NIL THEN
			Ln;  Str( "***********************" );  Ln;  WriteTextToLog( T );  Ln;  Str( "***********************" );  Ln;  Init( stack );  Texts.OpenReader( R, T, 0 );  Ln;  Str( "time 1a: " );
			WInt( Oberon.Time() - t, 10 );  t := Oberon.Time();  OPM.Init( {}, {}, R, Oberon.Log );  Ln;  Str( "time 1b: " );
			WInt( Oberon.Time() - t, 10 );  t := Oberon.Time();  OPS.Init();  Ln;  Str( "time 2: " );  WInt( Oberon.Time() - t, 10 );
			t := Oberon.Time();  GetSym( sym );
			WHILE (sym # OPS.eof) DO
				Expr( stack );  Dump( stack );
				IF OPM.noerr THEN
					itnr := 0;  Ln;  Str( "time 3: " );  WInt( Oberon.Time() - t, 10 );  t := Oberon.Time();  Eval( stack, val );  Ln;  Str( "time 4: " );
					WInt( Oberon.Time() - t, 10 );  t := Oberon.Time();  Note := TRUE;  Ln;
					IF val.class = 0 THEN Red ELSE Green END;
					Str( ">> " );  OutVal( val );  Black;  Gap;  Note := FALSE
				ELSE Note := TRUE;  Ln;  Red;  Str( "Syntax Error" );  Black;  Note := FALSE;  WLog;  RETURN
				END;
				GetSym( sym )
			END;
			Ln;  Str( "time 5: " );  WInt( Oberon.Time() - t, 10 );  t := Oberon.Time();

			WLog
		END;
		CleanUp
	END Exec;

	PROCEDURE ExecSel*;
	VAR T: Texts.Text;
	BEGIN
		T := Oberon.MarkedText();  Exec( T )
	END ExecSel;


(** Keyboard handler **)

	PROCEDURE Key( frame: TextGadgets.Frame;  ch: CHAR;  VAR handled: BOOLEAN );
	VAR pos, pos0, pos1, beg: SIGNED32;  ch1: CHAR;  T: Texts.Text;  keys: SET;  R: Texts.Reader;  w: Texts.Writer;  res: SIGNED16;  SelT: Texts.Text;
		end, time: SIGNED32;  sc: Texts.Scanner;
		proc: ARRAY 128 OF CHAR;
		Mod: Modules.Module;  Proc: Modules.Command;  i: SIGNED32;  cmsg: Oberon.CaretMsg;
	BEGIN
		Input.KeyState( keys );  handled := TRUE;
		IF (ch = 0DX) & (0 IN keys) THEN
			Oberon.GetSelection( SelT, beg, end, time );  pos := frame.carpos.pos - 1;  pos0 := pos;
			IF (SelT # NIL ) & (SelT = frame.text) & (beg <= pos) & (end >= pos) (* only if caret in selection*) THEN
				Texts.OpenWriter( w );  Texts.OpenReader( R, frame.text, beg );  pos := beg;  pos0 := beg;
				WHILE (pos < end) DO Texts.Read( R, ch1 );  Texts.Write( w, ch1 );  INC( pos ) END
			ELSE
				Texts.OpenReader( R, frame.text, pos );  Texts.Read( R, ch1 );  DEC( pos );
				(* beginning of line:*)
				WHILE ((pos >= 0) & (ch1 # 0DX)) DO Texts.OpenReader( R, frame.text, pos );  Texts.Read( R, ch1 );  DEC( pos ) END;
				IF (ch1 # 0DX) THEN Texts.OpenReader( R, frame.text, 0 ) ELSE INC( pos ) END;
				Texts.OpenWriter( w );  pos1 := pos;
				(* until cursor: *)
				WHILE (pos < pos0) DO
					Texts.Read( R, ch1 );  Texts.Write( w, ch1 );
					(*Ch(ch1);*)
					INC( pos )
				END;
				(* until end of line: *)
				Texts.Read( R, ch1 );
				WHILE (~R.eot) & (ch1 # 0DX) DO
					Texts.Write( w, ch1 );
					(*Ch(ch1); *)
					Texts.Read( R, ch1 )
				END
			END;
			NEW( T );  Texts.Open( T, "ExpressionsXXXX" );  Texts.Append( T, w.buf );
			IF enableCR THEN
				cmsg.id := Oberon.get;  cmsg.res := -1;  Display.Broadcast( cmsg );  cmsg.id := Oberon.set;  cmsg.res := -1;
				cmsg.pos := Texts.Pos( R ) - 1;  Display.Broadcast( cmsg )
			END;

			IF pos0 # pos1 THEN
				(* check if command, if yes execute as command else execute as expression *)
				Texts.OpenScanner( sc, T, 0 );  Texts.Scan( sc );
				IF sc.class = Texts.Name THEN
					SplitName( sc.s, Mod, proc );
					Mod := NIL;   (* disable command execution *)
					IF Mod # NIL THEN
						Proc := Modules.ThisCommand( Mod, proc );
						IF Proc # NIL THEN
							Oberon.Par.text := T;  pos1 := 0;  i := 0;
							WHILE (sc.s[i] # 0X) DO INC( i );  INC( pos1 ) END;
							INC( pos1 );  Oberon.Par.pos := pos1;  Oberon.Call( sc.s, Oberon.Par, FALSE , res );
							IF res # 0 THEN Str( "calling " );  Str( sc.s );  Str( " failed" ) END
						ELSE Exec( T )
						END
					ELSE Exec( T )
					END
				ELSE Exec( T )
				END
			END;
			IF enableCR THEN handled := FALSE END;
			(*handled := FALSE *)  (* enables carriage return *)
		ELSE handled := FALSE
		END;
		RETURN
	END Key;

	PROCEDURE Handle*( F: Objects.Object;  VAR msg: Objects.ObjMsg );
	VAR frame: TextGadgets.Frame;  handled: BOOLEAN;
	BEGIN
		handled := FALSE;
		IF msg IS Oberon.InputMsg THEN
			WITH msg: Oberon.InputMsg DO
				frame := F( TextGadgets.Frame );
				IF (msg.id = Oberon.consume) & frame.car THEN
					Key( frame, msg.ch, handled );
					IF handled THEN msg.res := 0 END
				END
			END;
			IF ~handled THEN
				IF (oldHook # NIL ) THEN oldHook( F, msg ) END
			END
		END
	END Handle;

	PROCEDURE GetKeyCode*;
	VAR keys: SET;  ch: CHAR;
	BEGIN
		Str( "EditKeys.GetKeyCode  ('q' to quit)" );  WLog;
		REPEAT
			Input.Read( ch );  Ln;  Gap;  WChar( ch );  Input.KeyState( keys );
			IF 0 IN keys THEN Str( "SHIFT" )
			ELSIF 1 IN keys THEN Str( "CTRL" )
			ELSIF 2 IN keys THEN Str( "ALT" )
			END;
			WLog
		UNTIL ch = "q";
		Ln;  WLog
	END GetKeyCode;

	PROCEDURE TestAdr*( adr: SIGNED32 );
	VAR p: ANY;
	BEGIN
		Nt;
		IF adr = 0 THEN RETURN END;
		p := SYSTEM.VAL( ANY, adr );  OutType( p );  Nt
	END TestAdr;

	PROCEDURE Install*;
	BEGIN
		IF TextGadgets.macroHook # thisHook THEN oldHook := TextGadgets.macroHook END;
		TextGadgets.macroHook := Handle
	END Install;


(****************)
BEGIN
	WLog := WLogLog;  Install;  Texts.OpenWriter( W );  map := "0123456789ABCDEF";  thisHook := Handle;  Note := TRUE;  Str( "fof: antsExpressions enabled, use SHIFT+ENTER to evaluate " );  Ln;  WLog;
	Note := FALSE;  WLog;  debug := FALSE;  Note := FALSE;  enableCR := FALSE;  OPT.typSize := OPV.TypSize
END antsExpressions.


Expr = SimpleExpr [ Relation SimpleExpr ] .
ExprList = Expr { ","Expr } .
SimpleExpr =  [ "+"| "-"] Term { AddOp Term } .
Term = Factor { MulOp Factor } .
Factor = Designator [ "("[ ExprList ] ")"] | number | character | "("Expr ")"| " ~ "Factor .
Designator = [ ident "."] ident .
Relation = "="| "#"| "<"| "<="| ">"| ">=".
AddOp = "+"| "-"| OR .
MulOp = " * "| "/"| DIV | MOD | "&".
~
antsExpressions.GetKeyCode


fofAutomatic.Do
EditKeys.Install
System.Free antsExpressionsDefaults  ~
System.Free antsExpressionsObjects  ~
System.Free antsExpressions  ~
System.Free antsExpressionsTest ~
antsExpressions.Install
~

antsExpressionsTest.test := 3.0;
antsExpressionsTest.test := 3.0D0;
antsExpressionsTest.test
System.State antsExpressionsTest
antsExpressionsTest.w := antsExpressionsTest.v;

vyBase.Register(a);
a := RanV(100);