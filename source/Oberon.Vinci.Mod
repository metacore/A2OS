(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Vinci IN Oberon; (** portable *)	(* eos  *)
	(**
		Interpreter for the graphical description language Vinci

		Syntax:
		Program = ["import" ident {"," ident} ";"] Seq.

		Seq = Stat {";" Stat}.
		Stat = [Const|Define|With|Save|Draw|Label|DrawStat].

		Const = "const" Assign.
		Define = "define" ident ["(" [ident {"," ident}] ")"] "as" Seq "end" ident.
		Let = "let" Assign "in" Seq "end".
		If = "if" Expr "then" Seq {"elsif" Expr "then" Seq} ["else" Seq] "end".
		Repeat = "repeat" Expr "times" Seq "end".
		For = "for" ident "=" Expr "to" Expr ["by" Expr] "do" Seq "end".
		With = "with" Assign "do" Seq "end".
		Save = ("saveclip"|"savectm") Seq "restore".
		Draw = ("stroke"|"fill"|"clip"|"record"|"draw") DrawSeq "end".
		Label = "label" Expr Locator ["rotated" Expr].
		Assign = ident "=" Expr {"," ident "=" Expr}.

		Locator = ("at"|"over"|"above"|"below"|["to" ["lower"|"upper"]] ("left"|"right") "of") Coord.
		DrawSeq = DrawStat {";" DrawStat}.
		DrawStat = [If|Repeat|For|Let|Elements|Expr].
		Elements = {"from" Coord|Enter|Line|Arc|Curve|Corner|"close"|Exit|Text}.
		Enter = "enter" Coord "at" Coord.
		Line = "to" Coord.
		Arc = "arc" Coord ["," Coord ["," Coord]] "to" Coord.	center, tang vec 1, tang vec 2
		Curve = "curve" Coord ["," Coord] "to" Coord.	control points
		Corner = "corner" Coord "," Expr "to" Coord.	corner point, radius
		Exit = "exit" Coord.
		Coord = "(" Expr "," Expr ")".
		Text = "text" Expr ["at" Coord].

		Expr = SimpleExpr [relop SimpleExpr].
		SimpleExpr = ["+"|"-"] Term {addop Term}.
		Term = Factor {mulop Factor}.
		Factor = number|string|"(" Expr ")"|Qualident|Call|"~" Factor.
		Call = Qualident "(" [Expr {"," Expr}] ")".
		Qualident = [ident "."] ident.
		relop = "="|"#"|"<"|"<="|">"|">=".
		addop = "+"|"-"|"++"|"or".
		mulop = "*"|"/"|"&"|"div"|"mod".
	**)

	(*
		18.05.2000 - fixed 'Factor' to accept another Factor after "~"
	*)

	IMPORT
		Modules, Math IN A2, MathL IN A2, Display, Objects, Texts, Oberon, Strings, Scheme, Ops := SchemeOps,
		Images, PictImages, GfxMatrix, GfxImages, GfxPaths, GfxFonts, Gfx, Leonardo, LeoPens;


	CONST
		newline = Scheme.newline;
		errdist = 10;

		invalid = 0; ident = 1; literal = 2; equal = 3; nequal = 4; less = 5; lessEq = 6; greater = 7; greaterEq = 8;
		plus = 9; concat = 10; minus = 11; mult = 12; fdiv = 13; and = 14; not = 15; dot = 16; comma = 17; lpar = 18; rpar = 19;
		semicolon = 20; eof = 21;

		inPen = Gfx.InSubpath+1; inSubpen = inPen+1;


	TYPE
		Object = Scheme.Object;

		Scanner = RECORD
			ctxt: Scheme.Context;
			ch: CHAR;
			token: SIGNED16;
			errors: SIGNED16;
			obj: Object;
			pos, prev: SIGNED32;
		END;

		Context* = POINTER TO ContextDesc;
		ContextDesc* = RECORD (Scheme.ContextDesc)
			gc*: Gfx.Context;
			pen: LeoPens.Pen;
			mode: SET;
			evenodd: BOOLEAN;
			x, y: FLOAT32;
		END;

		Package = POINTER TO RECORD
			next: Package;
			name: Object;
			env: Scheme.Environment;
		END;


	VAR
		globals*: Scheme.Environment;
		Err: Texts.Text;
		Packages: Package;
		first: Object;
		opeq, opneq, oplt, opleq, opplus, opminus, opmul, opdiv, div, mod, opquot, opand, opnot, or, opconcat,
		begin, define, if, lambda, let, quote, toinexact,
		above, as, at, below, by, const, do, else, elsif, end, in, left, lower, of, over, restore,
		right, rotated, upper, then, times,
		for, repeat, clip, draw, fill, record, stroke, endpath, enter, exit, from, to, close, arc, curve, corner,
		text, label, savectm, saveclip, with, import, qualify, module,
		strokecol, fillcol, color, strokepat, fillpat, pattern, width, dash, phase, cap, join, limit, flatness,
		font, size, evenodd, pen: Object;


	(*--- Scanner ---*)

	PROCEDURE ScanCh (VAR s: Scanner);
	BEGIN
		Scheme.ReadCh(s.ctxt.in, s.ch);
		IF ("A" <= s.ch) & (s.ch <= "Z") THEN
			s.ch := CHR(ORD(s.ch) + (ORD("a") - ORD("A")))
		END
	END ScanCh;

	PROCEDURE Scan (VAR s: Scanner);
		VAR i: SIGNED32; str: ARRAY 100 OF CHAR; r, f: FLOAT64; term: CHAR;
	BEGIN
		LOOP
			IF Scheme.Eof(s.ctxt.in) THEN s.token := eof; s.pos := Scheme.Pos(s.ctxt.in); RETURN
			ELSIF s.ch <= " " THEN ScanCh(s)
			ELSE EXIT
			END
		END;
		s.pos := Scheme.Pos(s.ctxt.in)-1;
		CASE s.ch OF
		| "a".."z", "!", ":", "$", "%", "?", "_":
			i := 0;
			LOOP
				IF i < LEN(str)-1 THEN str[i] := s.ch; INC(i) END;
				ScanCh(s);
				CASE s.ch OF "a".."z", "0".."9", "!", ":", "$", "%", "?", "_":
				ELSE EXIT
				END
			END;
			str[i] := 0X; s.token := ident; s.obj := Scheme.NewSymbol(str)
		| "`":
			i := 0;
			LOOP
				ScanCh(s);
				CASE s.ch OF "a".."z", "0".."9", "!", "$", "%", "&", "*", "/", ":", "<", "=", ">", "?", "^", "_", "~", "+", "-", ".", "@":
					IF i < LEN(str)-1 THEN str[i] := s.ch; INC(i) END
				ELSE EXIT
				END
			END;
			IF (i = 0) OR (s.ch # "`") THEN s.token := invalid
			ELSE ScanCh(s); str[i] := 0X; s.token := ident; s.obj := Scheme.NewSymbol(str)
			END
		| "0".."9":
			i := ORD(s.ch) - ORD("0"); ScanCh(s);
			WHILE ("0" <= s.ch) & (s.ch <= "9") DO
				i := 10*i + (ORD(s.ch) - ORD("0")); ScanCh(s)
			END;
			IF s.ch = "." THEN
				r := i; f := 1.0; ScanCh(s);
				WHILE ("0" <= s.ch) & (s.ch <= "9") DO
					f := f/10; r := r + f * (ORD(s.ch) - ORD("0")); ScanCh(s)
				END;
				s.token := literal; s.obj := Scheme.NewReal(r)
			ELSE
				s.token := literal; s.obj := Scheme.NewInteger(i)
			END
		| '"', "'":
			term := s.ch; Scheme.ReadCh(s.ctxt.in, s.ch); i := 0;
			WHILE s.ch # term DO
				IF Scheme.Eof(s.ctxt.in) OR (i = LEN(str)-1) THEN s.token := invalid; RETURN END;
				str[i] := s.ch; INC(i); Scheme.ReadCh(s.ctxt.in, s.ch)
			END;
			ScanCh(s); str[i] := 0X; s.token := literal; s.obj := Scheme.NewLiteral(str, s.ctxt.pool)
		| "=": ScanCh(s); s.token := equal
		| "#": ScanCh(s); s.token := nequal
		| "<": ScanCh(s); IF s.ch = "=" THEN ScanCh(s); s.token := lessEq ELSE s.token := less END
		| ">": ScanCh(s); IF s.ch = "=" THEN ScanCh(s); s.token := greaterEq ELSE s.token := greater END
		| "+": ScanCh(s); IF s.ch = "+" THEN ScanCh(s); s.token := concat ELSE s.token := plus END
		| "-":
			ScanCh(s);
			IF s.ch = "-" THEN REPEAT Scheme.ReadCh(s.ctxt.in, s.ch) UNTIL Scheme.Eof(s.ctxt.in) OR (s.ch = newline); Scan(s)
			ELSE s.token := minus
			END
		| "*": ScanCh(s); s.token := mult
		| "/": ScanCh(s); s.token := fdiv
		| "&": ScanCh(s); s.token := and
		| "~": ScanCh(s); s.token := not
		| ".": ScanCh(s); s.token := dot
		| ",": ScanCh(s); s.token := comma
		| "(": ScanCh(s); s.token := lpar
		| ")": ScanCh(s); s.token := rpar
		| ";": ScanCh(s); s.token := semicolon
		ELSE ScanCh(s); s.token := invalid
		END
	END Scan;


	(*--- Parser ---*)

	PROCEDURE Msg (VAR s: Scanner; msg: ARRAY OF CHAR);
	BEGIN
		IF s.pos >= s.prev + errdist THEN
			Scheme.WriteStr(s.ctxt.err, "  pos "); Scheme.WriteObj(s.ctxt.err, Scheme.NewInteger(s.pos));
			Scheme.Write(s.ctxt.err, " "); Scheme.WriteStr(s.ctxt.err, msg);
			INC(s.errors)
		END
	END Msg;

	PROCEDURE Str (VAR s: Scanner; str: ARRAY OF CHAR);
	BEGIN
		IF s.pos >= s.prev + errdist THEN
			Scheme.WriteStr(s.ctxt.err, str)
		END
	END Str;

	PROCEDURE Obj (VAR s: Scanner; obj: Object);
	BEGIN
		IF s.pos >= s.prev + errdist THEN
			Scheme.WriteObj(s.ctxt.err, obj)
		END
	END Obj;

	PROCEDURE Ln (VAR s: Scanner);
	BEGIN
		IF s.pos >= s.prev + errdist THEN
			Scheme.Write(s.ctxt.err, newline); Scheme.Flush(s.ctxt.err);
			s.prev := s.pos
		END
	END Ln;

	PROCEDURE Pair (car, cdr: Object): Object;
	BEGIN
		RETURN Scheme.NewPair(car, cdr)
	END Pair;

	PROCEDURE Quote (obj: Object): Object;
	BEGIN
		RETURN Pair(quote, Pair(obj, Scheme.nil))
	END Quote;

	PROCEDURE Append (VAR last: Object; obj: Object);
		VAR next: Object;
	BEGIN
		next := Pair(obj, Scheme.nil); Scheme.SetCdr(last, next); last := next
	END Append;

	PROCEDURE CheckEq (VAR s: Scanner);
	BEGIN
		IF s.token = equal THEN Scan(s) ELSE Msg(s, "'=' expected"); Ln(s) END
	END CheckEq;

	PROCEDURE CheckComma (VAR s: Scanner);
	BEGIN
		IF s.token = comma THEN Scan(s) ELSE Msg(s, "',' expected"); Ln(s) END
	END CheckComma;

	PROCEDURE CheckLPar (VAR s: Scanner);
	BEGIN
		IF s.token = lpar THEN Scan(s) ELSE Msg(s, "'(' expected"); Ln(s) END
	END CheckLPar;

	PROCEDURE CheckRPar (VAR s: Scanner);
	BEGIN
		IF s.token = rpar THEN Scan(s) ELSE Msg(s, "')' expected"); Ln(s) END
	END CheckRPar;

	PROCEDURE CheckAt (VAR s: Scanner);
	BEGIN
		IF (s.token = ident) & (s.obj = at) THEN Scan(s) ELSE Msg(s, "'at' expected"); Ln(s) END
	END CheckAt;

	PROCEDURE CheckDo (VAR s: Scanner);
	BEGIN
		IF (s.token = ident) & (s.obj = do) THEN Scan(s) ELSE Msg(s, "'do' expected"); Ln(s) END
	END CheckDo;

	PROCEDURE CheckEnd (VAR s: Scanner);
	BEGIN
		IF (s.token = ident) & (s.obj = end) THEN Scan(s) ELSE Msg(s, "'end' expected"); Ln(s) END
	END CheckEnd;

	PROCEDURE CheckTo (VAR s: Scanner);
	BEGIN
		IF (s.token = ident) & (s.obj = to) THEN Scan(s) ELSE Msg(s, "'to' expected"); Ln(s) END
	END CheckTo;

	PROCEDURE Ident (VAR s: Scanner; VAR name: Object);
	BEGIN
		IF s.token = ident THEN name := s.obj; Scan(s) ELSE Msg(s, "identifier expected"); Ln(s) END
	END Ident;

	PROCEDURE Qualident (VAR s: Scanner; VAR x: Object);
		VAR y: Object;
	BEGIN
		Ident(s, x);
		IF s.token = dot THEN
			Scan(s); Ident(s, y);
			x := Pair(qualify, Pair(Quote(x), Pair(Quote(y), Scheme.nil)))
		END
	END Qualident;

	PROCEDURE Factor (VAR s: Scanner; VAR x: Object);
		VAR last, arg: Object;
	BEGIN
		IF s.token = literal THEN x := s.obj; Scan(s)
		ELSIF s.token = lpar THEN Scan(s); Expr(s, x); CheckRPar(s)
		ELSIF s.token = ident THEN
			Qualident(s, x);
			IF s.token = lpar THEN
				x := Pair(x, Scheme.nil); last := x; Scan(s);
				IF s.token # rpar THEN
					LOOP
						Expr(s, arg); Append(last, arg);
						IF s.token # comma THEN EXIT END;
						Scan(s)
					END
				END;
				CheckRPar(s)
			END
		ELSIF s.token = not THEN Scan(s); Factor(s, x); x := Pair(opnot, Pair(x, Scheme.nil))
		ELSE Msg(s, "illegal factor"); Ln(s)
		END
	END Factor;

	PROCEDURE Term (VAR s: Scanner; VAR x: Object);
		VAR y: Object;
	BEGIN
		Factor(s, x);
		LOOP
			IF s.token = mult THEN Scan(s); Factor(s, y); x := Pair(opmul, Pair(x, Pair(y, Scheme.nil)))
			ELSIF s.token = fdiv THEN
				Scan(s); Factor(s, y);
				x := Pair(toinexact, Pair(x, Scheme.nil));
				y := Pair(toinexact, Pair(y, Scheme.nil));
				x := Pair(opdiv, Pair(x, Pair(y, Scheme.nil)))
			ELSIF s.token = and THEN Scan(s); Factor(s, y); x := Pair(opand, Pair(x, Pair(y, Scheme.nil)))
			ELSIF (s.token = ident) & (s.obj = div) THEN Scan(s); Factor(s, y); x := Pair(opquot, Pair(x, Pair(y, Scheme.nil)))
			ELSIF (s.token = ident) & (s.obj = mod) THEN Scan(s); Factor(s, y); x := Pair(mod, Pair(x, Pair(y, Scheme.nil)))
			ELSE EXIT
			END
		END
	END Term;

	PROCEDURE SimpleExpr (VAR s: Scanner; VAR x: Object);
		VAR y: Object;
	BEGIN
		IF s.token = plus THEN Scan(s); Term(s, x)
		ELSIF s.token = minus THEN Scan(s); Term(s, x); x := Pair(opminus, Pair(x, Scheme.nil))
		ELSE Term(s, x)
		END;
		LOOP
			IF s.token = plus THEN Scan(s); Term(s, y); x := Pair(opplus, Pair(x, Pair(y, Scheme.nil)))
			ELSIF s.token = minus THEN Scan(s); Term(s, y); x := Pair(opminus, Pair(x, Pair(y, Scheme.nil)))
			ELSIF s.token = concat THEN Scan(s); Term(s, y); x := Pair(opconcat, Pair(x, Pair(y, Scheme.nil)))
			ELSIF (s.token = ident) & (s.obj = or) THEN Scan(s); Term(s, y); x := Pair(or, Pair(x, Pair(y, Scheme.nil)))
			ELSE EXIT
			END
		END
	END SimpleExpr;

	PROCEDURE Expr (VAR s: Scanner; VAR x: Object);
		VAR y: Object;
	BEGIN
		SimpleExpr(s, x);
		CASE s.token OF
		| equal: Scan(s); SimpleExpr(s, y); x := Pair(opeq, Pair(x, Pair(y, Scheme.nil)))
		| nequal: Scan(s); SimpleExpr(s, y); x := Pair(opneq, Pair(x, Pair(y, Scheme.nil)))
		| less: Scan(s); SimpleExpr(s, y); x := Pair(oplt, Pair(x, Pair(y, Scheme.nil)))
		| lessEq: Scan(s); SimpleExpr(s, y); x := Pair(opleq, Pair(x, Pair(y, Scheme.nil)))
		| greater: Scan(s); SimpleExpr(s, y); x := Pair(oplt, Pair(y, Pair(x, Scheme.nil)))
		| greaterEq: Scan(s); SimpleExpr(s, y); x := Pair(opleq, Pair(y, Pair(x, Scheme.nil)))
		ELSE
		END
	END Expr;

	PROCEDURE If (VAR s: Scanner; VAR sseq: Object);
		VAR last, cond, seq, next: Object;
	BEGIN
		last := Pair(if, Scheme.nil); Append(sseq, last);
		LOOP
			Scan(s); Expr(s, cond); Append(last, cond);
			IF (s.token = ident) & (s.obj = then) THEN Scan(s)
			ELSE Msg(s, "'then' expected"); Ln(s)
			END;
			Sequence(s, seq);
			IF Scheme.Cdr(seq) = Scheme.nil THEN Append(last, Scheme.Car(seq))
			ELSE Append(last, Pair(begin, seq))
			END;
			IF (s.token # ident) OR (s.obj # elsif) THEN EXIT END;
			next := Pair(if, Scheme.nil); Append(last, next); last := next
		END;
		IF (s.token = ident) & (s.obj = else) THEN
			Scan(s); Sequence(s, seq);
			IF Scheme.Cdr(seq) = Scheme.nil THEN Append(last, Scheme.Car(seq))
			ELSE Append(last, Pair(begin, seq))
			END
		END;
		CheckEnd(s)
	END If;

	PROCEDURE Repeat (VAR s: Scanner; VAR sseq: Object);
		VAR val, seq, proc: Object;
	BEGIN
		Scan(s); Expr(s, val);
		IF (s.token = ident) & (s.obj = times) THEN Scan(s)
		ELSE Msg(s, "'times' expected"); Ln(s)
		END;
		Sequence(s, seq); CheckEnd(s);
		proc := Pair(lambda, Pair(Scheme.nil, seq));
		Append(sseq, Pair(repeat, Pair(val, Pair(proc, Scheme.nil))))
	END Repeat;

	PROCEDURE For (VAR s: Scanner; VAR sseq: Object);
		VAR var, v0, v1, step, seq, last: Object;
	BEGIN
		Scan(s); Ident(s, var); CheckEq(s); Expr(s, v0); CheckTo(s); Expr(s, v1);
		IF (s.token = ident) & (s.obj = by) THEN Scan(s); Expr(s, step)
		ELSE step := Scheme.one
		END;
		CheckDo(s); Sequence(s, seq); CheckEnd(s);
		last := Pair(for, Scheme.nil); Append(sseq, last);
		Append(last, v0); Append(last, v1); Append(last, step);
		Append(last, Pair(lambda, Pair(Pair(var, Scheme.nil), seq)))
	END For;

	PROCEDURE Let (VAR s: Scanner; VAR sseq: Object);
		VAR last, name, val, next, seq: Object;
	BEGIN
		last := Pair(let, Scheme.nil); Append(sseq, last);
		LOOP
			Scan(s); Ident(s, name); CheckEq(s); Expr(s, val);
			Append(last, Pair(Pair(name, Pair(val, Scheme.nil)), Scheme.nil));
			IF s.token # comma THEN EXIT END;
			next := Pair(let, Scheme.nil); Append(last, next); last := next
		END;
		IF (s.token = ident) & (s.obj = in) THEN Scan(s)
		ELSE Msg(s, "'in' expected"); Ln(s)
		END;
		Sequence(s, seq); Scheme.SetCdr(last, seq); CheckEnd(s)
	END Let;

	PROCEDURE Coord (VAR s: Scanner; VAR x, y: Object);
	BEGIN
		CheckLPar(s); Expr(s, x); CheckComma(s); Expr(s, y); CheckRPar(s)
	END Coord;

	PROCEDURE Text (VAR s: Scanner; VAR sseq: Object);
		VAR last, val, x, y: Object;
	BEGIN
		Scan(s); last := Pair(text, Scheme.nil); Append(sseq, last);
		Expr(s, val); Append(last, val);
		IF (s.token = ident) & (s.obj = at) THEN
			Scan(s); Coord(s, x, y); Append(last, x); Append(last, y)
		END
	END Text;

	PROCEDURE From (VAR s: Scanner; VAR sseq: Object);
		VAR x, y: Object;
	BEGIN
		Scan(s); Coord(s, x, y);
		Append(sseq, Pair(from, Pair(x, Pair(y, Scheme.nil))))
	END From;

	PROCEDURE Enter (VAR s: Scanner; VAR sseq: Object);
		VAR last, dx, dy, x, y: Object;
	BEGIN
		Scan(s); last := Pair(enter, Scheme.nil); Append(sseq, last);
		Coord(s, dx, dy); CheckAt(s); Coord(s, x, y);
		Append(last, x); Append(last, y); Append(last, dx); Append(last, dy)
	END Enter;

	PROCEDURE To (VAR s: Scanner; VAR sseq: Object);
		VAR x, y: Object;
	BEGIN
		Scan(s); Coord(s, x, y);
		Append(sseq, Pair(to, Pair(x, Pair(y, Scheme.nil))))
	END To;

	PROCEDURE Arc (VAR s: Scanner; VAR sseq: Object);
		VAR last, x, y: Object;
	BEGIN
		Scan(s); last := Pair(arc, Scheme.nil); Append(sseq, last);
		Coord(s, x, y); Append(last, x); Append(last, y);
		IF s.token = comma THEN
			Scan(s); Coord(s, x, y); Append(last, x); Append(last, y);
			IF s.token = comma THEN
				Scan(s); Coord(s, x, y); Append(last, x); Append(last, y)
			END
		END;
		CheckTo(s); Coord(s, x, y); Append(last, x); Append(last, y)
	END Arc;

	PROCEDURE Curve (VAR s: Scanner; VAR sseq: Object);
		VAR last, x, y: Object;
	BEGIN
		Scan(s); last := Pair(curve, Scheme.nil); Append(sseq, last);
		Coord(s, x, y); Append(last, x); Append(last, y);
		IF s.token = comma THEN
			Scan(s); Coord(s, x, y); Append(last, x); Append(last, y)
		END;
		CheckTo(s); Coord(s, x, y); Append(last, x); Append(last, y)
	END Curve;

	PROCEDURE Corner (VAR s: Scanner; VAR sseq: Object);
		VAR last, x, y, rad: Object;
	BEGIN
		Scan(s); last := Pair(corner, Scheme.nil); Append(sseq, last);
		Coord(s, x, y); Append(last, x); Append(last, y);
		CheckComma(s); Expr(s, rad); Append(last, rad);
		CheckTo(s); Coord(s, x, y); Append(last, x); Append(last, y)
	END Corner;

	PROCEDURE Exit (VAR s: Scanner; VAR sseq: Object);
		VAR dx, dy: Object;
	BEGIN
		Scan(s); Coord(s, dx, dy);
		Append(sseq, Pair(exit, Pair(dx, Pair(dy, Scheme.nil))))
	END Exit;

	PROCEDURE Elements (VAR s: Scanner; VAR sseq: Object);
	BEGIN
		LOOP
			IF s.token # ident THEN EXIT
			ELSIF s.obj = text THEN Text(s, sseq)
			ELSIF s.obj = from THEN From(s, sseq)
			ELSIF s.obj = enter THEN Enter(s, sseq)
			ELSIF s.obj = to THEN To(s, sseq)
			ELSIF s.obj = arc THEN Arc(s, sseq)
			ELSIF s.obj = curve THEN Curve(s, sseq)
			ELSIF s.obj = corner THEN Corner(s, sseq)
			ELSIF s.obj = exit THEN Exit(s, sseq)
			ELSIF s.obj = close THEN Scan(s); Append(sseq, Pair(close, Scheme.nil))
			ELSE EXIT
			END
		END
	END Elements;

	PROCEDURE DrawStatement (VAR s: Scanner; VAR sseq: Object);
		VAR expr: Object;
	BEGIN
		WHILE s.token = semicolon DO Scan(s) END;
		IF s.token = eof THEN
		ELSIF s.token # ident THEN Expr(s, expr); Append(sseq, expr)
		ELSIF s.obj = if THEN If(s, sseq)
		ELSIF s.obj = repeat THEN Repeat(s, sseq)
		ELSIF s.obj = for THEN For(s, sseq)
		ELSIF s.obj = let THEN Let(s, sseq)
		ELSIF (s.obj = text) OR (s.obj = from) OR (s.obj = enter) OR (s.obj = to) OR (s.obj = arc) OR (s.obj = curve) OR
			(s.obj = corner) OR (s.obj = exit) OR (s.obj = close) THEN Elements(s, sseq)
		ELSIF (s.obj # end) & (s.obj # restore) & (s.obj # elsif) & (s.obj # else) THEN Expr(s, expr); Append(sseq, expr)
		END
	END DrawStatement;

	PROCEDURE Draw (VAR s: Scanner; VAR sseq: Object);
	BEGIN
		Append(sseq, Pair(s.obj, Scheme.nil)); Scan(s);
		DrawStatement(s, sseq);
		WHILE s.token = semicolon DO
			DrawStatement(s, sseq);
		END;
		CheckEnd(s);
		Append(sseq, Pair(endpath, Scheme.nil))
	END Draw;

	PROCEDURE Label (VAR s: Scanner; VAR sseq: Object);
		VAR val, x, y, last, rot: Object; mode: SIGNED32;
	BEGIN
		Scan(s); Expr(s, val);
		IF s.token = ident THEN
			IF s.obj = at THEN Scan(s); mode := 0
			ELSIF s.obj = over THEN Scan(s); mode := 1
			ELSIF s.obj = above THEN Scan(s); mode := 2
			ELSIF s.obj = below THEN Scan(s); mode := 9
			ELSE
				IF s.obj = to THEN Scan(s) END;
				IF s.obj = lower THEN Scan(s); mode := +1
				ELSIF s.obj = upper THEN Scan(s); mode := -1
				ELSE mode := 0
				END;
				IF s.obj = left THEN Scan(s); INC(mode, 7)
				ELSIF s.obj = right THEN Scan(s); INC(mode, 4)
				ELSE Msg(s, "location specifier expected"); Ln(s)
				END;
				IF s.obj = of THEN Scan(s)
				ELSE Msg(s, "'of' expected"); Ln(s)
				END
			END
		ELSE Msg(s, "location specifier expected"); Ln(s)
		END;
		Coord(s, x, y);
		last := Pair(label, Scheme.nil); Append(sseq, last);
		Append(last, val); Append(last, Scheme.NewInteger(mode));
		Append(last, x); Append(last, y);
		IF (s.token = ident) & (s.obj = rotated) THEN
			Scan(s); Expr(s, rot); Append(last, rot)
		END
	END Label;

	PROCEDURE With (VAR s: Scanner; VAR sseq: Object);
		VAR last, name, val, seq, proc: Object;
	BEGIN
		last := Pair(with, Scheme.nil); Append(sseq, last);
		REPEAT
			Scan(s); Ident(s, name); CheckEq(s); Expr(s, val);
			Append(last, Quote(name)); Append(last, val);
		UNTIL s.token # comma;
		CheckDo(s); Sequence(s, seq); CheckEnd(s);
		proc := Pair(lambda, Pair(Scheme.nil, seq));
		Append(last, proc)
	END With;

	PROCEDURE Save (VAR s: Scanner; VAR sseq: Object);
		VAR op, seq, proc: Object;
	BEGIN
		op := s.obj; Scan(s); Sequence(s, seq);
		IF (s.token = ident) & (s.obj = restore) THEN Scan(s)
		ELSE Msg(s, "'restore' expected"); Ln(s)
		END;
		proc := Pair(lambda, Pair(Scheme.nil, seq));
		Append(sseq, Pair(op, Pair(proc, Scheme.nil)))
	END Save;

	PROCEDURE Const (VAR s: Scanner; VAR sseq: Object);
		VAR name, val: Object;
	BEGIN
		REPEAT
			Scan(s); Ident(s, name); CheckEq(s); Expr(s, val);
			Append(sseq, Pair(define, Pair(name, Pair(val, Scheme.nil))))
		UNTIL s.token # comma
	END Const;

	PROCEDURE Define (VAR s: Scanner; VAR sseq: Object);
		VAR par, procname, last, name, seq: Object;
	BEGIN
		Scan(s); par := Scheme.nil;
		Ident(s, procname);
		IF s.token = lpar THEN
			Scan(s);
			IF s.token = ident THEN
				par := Pair(s.obj, Scheme.nil); Scan(s); last := par;
				WHILE s.token = comma DO
					Scan(s); Ident(s, name); Append(last, name)
				END
			END;
			CheckRPar(s)
		END;
		IF (s.token = ident) & (s.obj = as) THEN Scan(s)
		ELSE
			Msg(s, "'as' expected"); Ln(s);
			REPEAT Scan(s) UNTIL (s.token >= semicolon) OR (s.token = ident) & ((s.obj = as) OR (s.obj = end));
			IF (s.token = ident) & (s.obj = as) THEN Scan(s) END
		END;
		Sequence(s, seq); CheckEnd(s); Ident(s, name);
		IF name # procname THEN Msg(s, "procedure name expected"); Ln(s) END;
		Append(sseq, Pair(define, Pair(Pair(name, par), seq)))
	END Define;

	PROCEDURE Statement (VAR s: Scanner; VAR seq: Object);
	BEGIN
		WHILE s.token = semicolon DO Scan(s) END;
		IF s.token = eof THEN
		ELSIF (s.obj = draw) OR (s.obj = stroke) OR (s.obj = fill) OR (s.obj = clip) OR (s.obj = record) THEN Draw(s, seq)
		ELSIF s.obj = label THEN Label(s, seq)
		ELSIF s.obj = with THEN With(s, seq)
		ELSIF (s.obj = savectm) OR (s.obj = saveclip) THEN Save(s, seq)
		ELSIF s.obj = const THEN Const(s, seq)
		ELSIF s.obj = define THEN Define(s, seq)
		ELSE DrawStatement(s, seq)
		END
	END Statement;

	PROCEDURE Sequence (VAR s: Scanner; VAR seq: Object);
		VAR old: Object;
	BEGIN
		old := Scheme.Cdr(first); Scheme.SetCdr(first, Scheme.nil); seq := first;
		Statement(s, seq);
		WHILE s.token = semicolon DO
			Statement(s, seq)
		END;
		WHILE ~((s.token >= semicolon) OR
			(s.token = ident) & ((s.obj = end) OR (s.obj = restore) OR (s.obj = elsif) OR (s.obj = else)))
		DO Scan(s)
		END;
		seq := Scheme.Cdr(first); Scheme.SetCdr(first, old)
	END Sequence;

	PROCEDURE Program (VAR s: Scanner; VAR body: Object);
		VAR prev, last, name, seq: Object;
	BEGIN
		Scan(s); body := NIL;
		IF s.token = ident THEN
			body := Scheme.NewPair(Scheme.nil, Scheme.nil); prev := body;
			IF s.obj = import THEN
				last := Pair(import, Scheme.nil); Append(prev, last);
				REPEAT
					Scan(s); Ident(s, name);
					Append(last, Quote(name))
				UNTIL s.token # comma;
				IF s.token = semicolon THEN Scan(s)
				ELSE Msg(s, "',' or ';' expected"); Ln(s); REPEAT Scan(s) UNTIL s.token >= semicolon; Scan(s)
				END
			END;
			Sequence(s, seq);
			IF seq # Scheme.nil THEN Scheme.SetCdr(prev, seq)
			ELSE Msg(s, "program is empty"); Ln(s)
			END;
			IF s.token # eof THEN Msg(s, "unexpected symbol"); Ln(s) END;
			body := Scheme.Cdr(body)
		ELSIF s.token = eof THEN
			Msg(s, "program is empty"); Ln(s)
		ELSE
			Msg(s, "program starts with incorrect symbol");
			IF s.token = literal THEN Str(s, ": "); Obj(s, s.obj) END;
			Ln(s)
		END
	END Program;

	PROCEDURE Parse* (ctxt: Scheme.Context; VAR body: Object);
		VAR s: Scanner;
	BEGIN
		s.ctxt := ctxt; s.errors := 0; s.prev := -errdist; ScanCh(s);
		Program(s, body);
		IF s.errors # 0 THEN body := NIL END
	END Parse;


	(*--- Packages ---*)

	PROCEDURE FindPackage (name: Object): Package;
		VAR pack: Package;
	BEGIN
		pack := Packages;
		WHILE (pack # NIL) & (pack.name # name) DO pack := pack.next END;
		RETURN pack
	END FindPackage;

	PROCEDURE FindSymbol (ctxt: Scheme.Context; pack: Package; name: Object): Object;
		VAR val: Object;
	BEGIN
		IF Scheme.LookupVariable(name, pack.env, val) THEN RETURN val
		ELSE Scheme.FailCode(ctxt, Scheme.errUnbound, name); RETURN Scheme.false
		END
	END FindSymbol;

	PROCEDURE ImportText (ctxt: Context; name: Object; text: Texts.Text);
		VAR in, old, seq, res, expr: Object; s: Scanner; env: Scheme.Environment; pack: Package;
	BEGIN
		in := ctxt.in; ctxt.in := Scheme.NewTextInput(text, 0);
		s.ctxt := ctxt; s.errors := 0; s.prev := -errdist; ScanCh(s); Scan(s);
		IF (s.token = ident) & (s.obj = import) THEN
			REPEAT
				Scan(s); Ident(s, name);
				Import(ctxt, name)
			UNTIL s.token # comma;
			IF s.token = semicolon THEN Scan(s)
			ELSE Msg(s, "',' or ';' expected"); Ln(s); RETURN
			END
		END;
		env := Scheme.NewEnvironment(globals);
		old := Scheme.Cdr(first);
		LOOP
			Scheme.SetCdr(first, Scheme.nil); seq := first;
			IF s.token = semicolon THEN Scan(s)
			ELSIF s.token = eof THEN EXIT
			ELSIF s.token # ident THEN Scheme.Fail(ctxt, "illegal package statement", Scheme.nil)
			ELSIF s.obj = const THEN Const(s, seq); res := Scheme.Evaluate(ctxt, env, Scheme.Car(seq))
			ELSIF s.obj = define THEN Define(s, seq); res := Scheme.Evaluate(ctxt, env, Scheme.Car(seq))
			ELSIF s.obj = module THEN Expr(s, expr); Append(seq, expr); res := Scheme.Evaluate(ctxt, env, Scheme.Car(seq))
			ELSE Scheme.Fail(ctxt, "illegal package statement", s.obj)
			END;
			IF ctxt.failed THEN EXIT END
		END;
		Scheme.SetCdr(first, old); ctxt.in := in;
		pack := FindPackage(name);
		IF ~ctxt.failed & (pack = NIL) THEN
			NEW(pack); pack.name := name; pack.env := env; pack.next := Packages; Packages := pack;
		END
	END ImportText;

	PROCEDURE ImportModule (name: Object): BOOLEAN;
		VAR pack: Package; key, Key, skey: ARRAY 32 OF CHAR; s: Texts.Scanner; mod: Modules.Module;
	BEGIN
		pack := NIL;
		Scheme.GetSymbol(name, key); COPY(key, Key); Key[0] := CAP(Key[0]);
		Oberon.OpenScanner(s, "Vinci");
		WHILE (pack = NIL) & (s.class IN {Texts.Name, Texts.String}) DO
			COPY(s.s, skey); Texts.Scan(s);
			IF (s.class = Texts.Char) & (s.c = "=") THEN
				Texts.Scan(s)
			END;
			IF s.class IN {Texts.Name, Texts.String} THEN
				IF (s.s = key) OR (s.s = Key) THEN
					mod := Modules.ThisMod(s.s); pack := FindPackage(name)
				END;
				Texts.Scan(s)
			END
		END;
		IF pack = NIL THEN
			skey := "Vinci"; Strings.Append(skey, Key);
			mod := Modules.ThisMod(skey); pack := FindPackage(name)
		END;
		RETURN pack # NIL
	END ImportModule;

	PROCEDURE Import* (ctxt: Context; name: Object);
		VAR pack: Package; file: ARRAY 64 OF CHAR; text: Texts.Text;
	BEGIN
		pack := FindPackage(name);
		IF pack = NIL THEN
			Scheme.GetSymbol(name, file); Strings.Append(file, ".Pack");
			NEW(text); Texts.Open(text, file);
			IF text.len = 0 THEN
				file[0] := CAP(file[0]); Texts.Open(text, file)
			END;
			IF (text.len # 0) THEN
				ImportText(ctxt, name, text)
			END;
			pack := FindPackage(name);
			IF (pack = NIL) & ~ImportModule(name) THEN
				Scheme.Fail(ctxt, "cannot import package", name)
			END
		END
	END Import;


	(**--- Contexts ---**)

	PROCEDURE InitContext* (ctxt: Context; in, out, err: Scheme.Object; gc: Gfx.Context);
	BEGIN
		Scheme.InitContext(ctxt, in, out, err);
		ctxt.gc := gc; ctxt.pen := LeoPens.Default
	END InitContext;

	PROCEDURE MakeContext* (ctxt: Context; in: Object; gc: Gfx.Context);
		VAR out, err: Scheme.Object;
	BEGIN
		out := Scheme.NewTextOutput(Oberon.Log);
		err := Scheme.NewTextOutput(Err);
		InitContext(ctxt, in, out, err, gc);
	END MakeContext;

	PROCEDURE ShowError*;
		VAR buf: Texts.Buffer;
	BEGIN
		IF Err.len # 0 THEN
			NEW(buf); Texts.OpenBuf(buf);
			Texts.Save(Err, 0, Err.len, buf); Texts.Append(Oberon.Log, buf);
			Texts.Open(Err, "")
		END
	END ShowError;


	(**--- Argument Checks ---**)

	PROCEDURE NumVal (ctxt: Scheme.Context; VAR args: Object): FLOAT32;
	BEGIN
		RETURN SHORT(Ops.NumVal(ctxt, args))
	END NumVal;

	PROCEDURE PenVal* (ctxt: Scheme.Context; VAR args: Object): LeoPens.Pen;
		VAR ref: Objects.Object;
	BEGIN
		ref := Ops.RefVal(ctxt, args);
		IF (ref # NIL) & (ref IS LeoPens.Pen) THEN RETURN ref(LeoPens.Pen)
		ELSE Scheme.Fail(ctxt, "argument must be pen object", Scheme.nil); RETURN LeoPens.Default
		END
	END PenVal;

	PROCEDURE GetColorVal* (ctxt: Scheme.Context; VAR args: Object; VAR col: Gfx.Color);
		VAR val, vec: Object; i: SIGNED32; exact: BOOLEAN;
	BEGIN
		val := Ops.Arg(ctxt, args);
		IF Scheme.IsPair(val) & (Scheme.Car(val) = color) THEN
			vec := Scheme.Cdr(val);
			Scheme.GetInteger(Scheme.VectorAt(vec, 0), i, exact); col.r := SHORT(i);
			Scheme.GetInteger(Scheme.VectorAt(vec, 1), i, exact); col.g := SHORT(i);
			Scheme.GetInteger(Scheme.VectorAt(vec, 2), i, exact); col.b := SHORT(i)
		ELSE Scheme.Fail(ctxt, "argument must be color value", val); col := Gfx.Black
		END
	END GetColorVal;

	PROCEDURE GetPatternVal* (ctxt: Scheme.Context; VAR args: Object; VAR img: Images.Image; VAR px, py: FLOAT32);
		VAR val, vec: Object; ref: Objects.Object; x, y: FLOAT64;
	BEGIN
		img := NIL; val := Ops.Arg(ctxt, args);
		IF Scheme.IsPair(val) & (Scheme.Car(val) = pattern) THEN
			vec := Scheme.Cdr(val);
			ref := Scheme.RefValue(Scheme.VectorAt(vec, 0));
			IF (ref # NIL) & (ref IS Images.Image) THEN img := ref(Images.Image) END;
			Scheme.GetReal(Scheme.VectorAt(vec, 1), x); px := SHORT(x);
			Scheme.GetReal(Scheme.VectorAt(vec, 2), y); py := SHORT(y)
		ELSE Scheme.Fail(ctxt, "argument must be pattern value", val)
		END
	END GetPatternVal;

	PROCEDURE GetDashVal* (ctxt: Scheme.Context; VAR args: Object; VAR on, off: ARRAY OF FLOAT32; VAR n: SIGNED32);
		VAR val, obj: Object; i, size: SIGNED32; r: FLOAT64;
	BEGIN
		val := Ops.VectorArg(ctxt, args);
		i := 0; size := Scheme.VectorLen(val);
		WHILE i < size DO
			obj := Scheme.VectorAt(val, i);
			IF Scheme.IsNumber(obj) THEN Scheme.GetReal(obj, r)
			ELSE Scheme.Fail(ctxt, "dash pattern element must be number", obj)
			END;
			IF ODD(i) THEN off[i DIV 2] := SHORT(r)
			ELSE on[i DIV 2] := SHORT(r); off[i DIV 2] := on[i]
			END;
			INC(i)
		END;
		n := (size+1) DIV 2
	END GetDashVal;

	PROCEDURE CapVal* (ctxt: Scheme.Context; VAR args: Object): Gfx.CapStyle;
		VAR str: Object; cap: Gfx.CapStyle; s: ARRAY 20 OF CHAR;
	BEGIN
		str := Ops.StringArg(ctxt, args); cap := Gfx.DefaultCap;
		IF ~ctxt.failed THEN
			Scheme.GetString(str, 0, Scheme.StringLen(str), s); s[0] := CAP(s[0]);
			IF s = "Butt" THEN cap := Gfx.ButtCap
			ELSIF s = "Round" THEN cap := Gfx.RoundCap
			ELSIF s = "Square" THEN cap := Gfx.SquareCap
			ELSIF s # "Default" THEN Scheme.Fail(ctxt, "unknown cap style", str)
			END
		END;
		RETURN cap
	END CapVal;

	PROCEDURE JoinVal* (ctxt: Scheme.Context; VAR args: Object): Gfx.JoinStyle;
		VAR str: Object; join: Gfx.JoinStyle; s: ARRAY 20 OF CHAR;
	BEGIN
		str := Ops.StringArg(ctxt, args); join := Gfx.DefaultJoin;
		IF ~ctxt.failed THEN
			Scheme.GetString(str, 0, Scheme.StringLen(str), s); s[0] := CAP(s[0]);
			IF s = "Bevel" THEN join := Gfx.BevelJoin
			ELSIF s = "Round" THEN join := Gfx.RoundJoin
			ELSIF s = "Miter" THEN join := Gfx.MiterJoin
			ELSIF s # "Default" THEN Scheme.Fail(ctxt, "unknown join style", str)
			END
		END;
		RETURN join
	END JoinVal;

	PROCEDURE GetMatrixVal* (ctxt: Scheme.Context; VAR args: Object; VAR m: GfxMatrix.Matrix);
		VAR obj, elem: Object; i: SIGNED32; x: FLOAT64;
	BEGIN
		obj := Ops.Arg(ctxt, args);
		IF Scheme.IsVector(obj) & (Scheme.VectorLen(obj) = 6) THEN
			FOR i := 0 TO 5 DO
				elem := Scheme.VectorAt(obj, i);
				IF Scheme.IsNumber(elem) THEN Scheme.GetReal(elem, x); m[i DIV 2, i MOD 2] := SHORT(x)
				ELSE Scheme.Fail(ctxt, "matrix element must be number", elem)
				END
			END
		ELSE Scheme.Fail(ctxt, "matrix must be vector", obj)
		END
	END GetMatrixVal;


	(*--- Primitive Evaluation ---*)

	PROCEDURE FailGC (ctxt: Scheme.Context);
	BEGIN
		Scheme.Fail(ctxt, "illegal operation (no graphics context)", ctxt.exp)
	END FailGC;

	PROCEDURE EvalRepeat (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR n: SIGNED32; body: Object;
	BEGIN
		n := Ops.IntVal(ctxt, args); body := Ops.ProcArg(ctxt, args); Ops.CheckNull(ctxt, args);
		IF n > 0 THEN
			REPEAT
				Scheme.Call(ctxt, body, Scheme.nil); DEC(n)
			UNTIL ctxt.failed OR (n = 0)
		END
	END EvalRepeat;

	PROCEDURE EvalFor (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR val, last, step: SIGNED32; body, arg: Object;
	BEGIN
		val := Ops.IntVal(ctxt, args); last := Ops.IntVal(ctxt, args); step := Ops.IntVal(ctxt, args);
		body := Ops.ProcArg(ctxt, args); Ops.CheckNull(ctxt, args);
		IF (step > 0) & (val <= last) OR (step < 0) & (val >= last) THEN
			arg := Pair(Scheme.NewInteger(val), Scheme.nil);
			REPEAT
				Scheme.Call(ctxt, body, arg);
				INC(val, step); Scheme.SetCar(arg, Scheme.NewInteger(val))
			UNTIL ctxt.failed OR (step > 0) & (val > last) OR (step < 0) & (val < last)
		END
	END EvalFor;

	PROCEDURE BeginPath (ctxt: Scheme.Context; args: Object; mode: SET);
		VAR c: Context;
	BEGIN
		c := ctxt(Context); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF c.mode * {Gfx.InPath, inPen} # {} THEN Scheme.Fail(c, "already within path", c.exp)
		ELSE
			IF c.evenodd THEN INCL(mode, Gfx.EvenOdd) END;
			Gfx.Begin(c.gc, mode); c.mode := c.gc.mode
		END
	END BeginPath;

	PROCEDURE EndPath (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context;
	BEGIN
		c := ctxt(Context); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF inPen IN c.mode THEN
			IF inSubpen IN c.mode THEN c.pen.do.exit(c.pen, 0, 0, 0) END;
			c.pen.do.end(c.pen)
		ELSIF Gfx.InPath IN c.mode THEN Gfx.End(c.gc)
		END;
		c.mode := {}
	END EndPath;

	PROCEDURE EvalDraw (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context;
	BEGIN
		c := ctxt(Context); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF c.mode * {Gfx.InPath, inPen} # {} THEN Scheme.Fail(c, "already within path", c.exp)
		ELSE c.pen.do.begin(c.pen, c.gc); c.mode := {inPen}
		END
	END EvalDraw;

	PROCEDURE EvalStroke (ctxt: Scheme.Context; args: Object; VAR res: Object);
	BEGIN
		BeginPath(ctxt, args, {Gfx.Stroke})
	END EvalStroke;

	PROCEDURE EvalFill (ctxt: Scheme.Context; args: Object; VAR res: Object);
	BEGIN
		BeginPath(ctxt, args, {Gfx.Fill})
	END EvalFill;

	PROCEDURE EvalClip (ctxt: Scheme.Context; args: Object; VAR res: Object);
	BEGIN
		BeginPath(ctxt, args, {Gfx.Clip})
	END EvalClip;

	PROCEDURE EvalRecord (ctxt: Scheme.Context; args: Object; VAR res: Object);
	BEGIN
		BeginPath(ctxt, args, {Gfx.Record})
	END EvalRecord;

	PROCEDURE EvalEnter (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; dx, dy: FLOAT32;
	BEGIN
		c := ctxt(Context); c.x := NumVal(c, args); c.y := NumVal(c, args);
		dx := NumVal(c, args); dy := NumVal(c, args); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF c.mode * {inPen, inSubpen} = {inPen} THEN c.pen.do.enter(c.pen, c.x, c.y, dx, dy, 0); INCL(c.mode, inSubpen)
		ELSIF Gfx.InPath IN c.mode THEN Gfx.Enter(c.gc, c.x, c.y, dx, dy)
		ELSE Scheme.Fail(c, "no open path", c.exp)
		END
	END EvalEnter;

	PROCEDURE EvalExit (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; dx, dy: FLOAT32;
	BEGIN
		c := ctxt(Context); dx := NumVal(c, args); dy := NumVal(c, args); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF inSubpen IN c.mode THEN c.pen.do.exit(c.pen, dx, dy, 0); EXCL(c.mode, inSubpen)
		ELSIF Gfx.InPath IN c.mode THEN Gfx.Exit(c.gc, dx, dy)
		ELSE Scheme.Fail(c, "no open path", c.exp)
		END
	END EvalExit;

	PROCEDURE EvalFrom (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context;
	BEGIN
		c := ctxt(Context); c.x := NumVal(c, args); c.y := NumVal(c, args); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF inPen IN c.mode THEN
			IF inSubpen IN c.mode THEN c.pen.do.exit(c.pen, 0, 0, 0) END;
			c.pen.do.enter(c.pen, c.x, c.y, 0, 0, 0); INCL(c.mode, inSubpen)
		ELSIF Gfx.InPath IN c.mode THEN Gfx.MoveTo(c.gc, c.x, c.y)
		ELSE Scheme.Fail(c, "no open path", c.exp)
		END
	END EvalFrom;

	PROCEDURE EvalTo (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context;
	BEGIN
		c := ctxt(Context); c.x := NumVal(c, args); c.y := NumVal(c, args); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF inSubpen IN c.mode THEN c.pen.do.line(c.pen, c.x, c.y)
		ELSIF Gfx.InSubpath IN c.gc.mode THEN Gfx.LineTo(c.gc, c.x, c.y)
		ELSE Scheme.Fail(c, "not within subpath", c.exp)
		END
	END EvalTo;

	PROCEDURE EvalClose (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context;
	BEGIN
		c := ctxt(Context); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF inSubpen IN c.mode THEN Scheme.Fail(c, "not within 'draw' path", c.exp)
		ELSIF Gfx.InSubpath IN c.gc.mode THEN Gfx.Close(c.gc)
		ELSE Scheme.Fail(c, "not within subpath", c.exp)
		END
	END EvalClose;

	PROCEDURE EvalArc (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; x0, y0, x, y, x1, y1, x2, y2: FLOAT32;
	BEGIN
		c := ctxt(Context); x0 := NumVal(c, args); y0 := NumVal(c, args); x := NumVal(c, args); y := NumVal(c, args);
		IF args = Scheme.nil THEN
			x1 := c.x; y1 := c.y; x2 := x; y2 := y
		ELSE
			x1 := x; y1 := y; x := NumVal(c, args); y := NumVal(c, args); x2 := x; y2 := y;
			IF args # Scheme.nil THEN
				x2 := x; y2 := y; x := NumVal(c, args); y := NumVal(c, args);
				Ops.CheckNull(c, args)
			END
		END;
		IF c.gc = NIL THEN FailGC(c)
		ELSIF inSubpen IN c.mode THEN c.pen.do.arc(c.pen, x, y, x0, y0, x1, y1, x2, y2)
		ELSIF Gfx.InSubpath IN c.gc.mode THEN Gfx.ArcTo(c.gc, x, y, x0, y0, x1, y1, x2, y2)
		ELSE Scheme.Fail(c, "not within subpath", c.exp)
		END;
		c.x := x; c.y := y
	END EvalArc;

	PROCEDURE EvalCurve (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; x1, y1, x, y, x2, y2: FLOAT32;
	BEGIN
		c := ctxt(Context); x1 := NumVal(c, args); y1 := NumVal(c, args); x := NumVal(c, args); y := NumVal(c, args);
		IF args = Scheme.nil THEN
			x2 := (1/3)*(2*x1 + x); y2 := (1/3)*(2*y1 + y); x1 := (1/3)*(2*x1 + c.x); y1 := (1/3)*(2*y1 + c.y)
		ELSE
			x2 := x; y2 := y; x := NumVal(c, args); y := NumVal(c, args); Ops.CheckNull(c, args)
		END;
		IF c.gc = NIL THEN FailGC(c)
		ELSIF inSubpen IN c.mode THEN c.pen.do.bezier(c.pen, x, y, x1, y1, x2, y2)
		ELSIF Gfx.InSubpath IN c.gc.mode THEN Gfx.BezierTo(c.gc, x, y, x1, y1, x2, y2)
		ELSE Scheme.Fail(c, "not within subpath", c.exp)
		END;
		c.x := x; c.y := y
	END EvalCurve;

	PROCEDURE EvalCorner (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; cx, cy, r, x, y, dx, dy, d, x1, y1, x2, y2: FLOAT32;
	BEGIN
		c := ctxt(Context); cx := NumVal(c, args); cy := NumVal(c, args); r := NumVal(c, args);
		x := NumVal(c, args); y := NumVal(c, args); Ops.CheckNull(c, args);
		dx := cx - c.x; dy := cy - c.y; d := Math.sqrt(dx * dx + dy * dy);
		IF d > r THEN x1 := cx - (r/d)*dx; y1 := cy - (r/d)*dy
		ELSE x1 := c.x; y1 := c.y
		END;
		dx := x - cx; dy := y - cy; d := Math.sqrt(dx * dx + dy * dy);
		IF d > r THEN x2 := cx + (r/d)*dx; y2 := cy + (r/d)*dy
		ELSE x2 := x; y2 := y
		END;
		IF c.gc = NIL THEN FailGC(c)
		ELSIF inSubpen IN c.mode THEN
			IF (x1 # c.x) & (y1 # c.y) THEN c.pen.do.line(c.pen, x1, y1) END;
			c.pen.do.arc(c.pen, x2, y2, x1 + (x2 - cx), y1 + (y2 - cy), x1, y1, x2, y2);
			IF (x2 # x) & (y2 # y) THEN c.pen.do.line(c.pen, x, y) END
		ELSIF Gfx.InSubpath IN c.gc.mode THEN
			IF (x1 # c.x) & (y1 # c.y) THEN Gfx.LineTo(c.gc, x1, y1) END;
			Gfx.ArcTo(c.gc, x2, y2, x1 + (x2 - cx), y1 + (y2 - cy), x1, y1, x2, y2);
			IF (x2 # x) & (y2 # y) THEN Gfx.LineTo(c.gc, x, y) END
		ELSE Scheme.Fail(c, "not within subpath", c.exp)
		END;
		c.x := x; c.y := y
	END EvalCorner;

	PROCEDURE EvalText (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR
			c: Context; str: Object; x, y, dx, dy: FLOAT32; s: ARRAY 256 OF CHAR; i, n: SIGNED32; dist: ARRAY 16 OF FLOAT32;
			path: GfxPaths.Path; psc: GfxPaths.Scanner;
	BEGIN
		c := ctxt(Context); str := Ops.StringArg(c, args); x := NumVal(c, args); y := NumVal(c, args); Ops.CheckNull(c, args);
		Scheme.GetString(str, 0, Scheme.StringLen(str), s);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF c.mode * {inPen, inSubpen} = {inPen} THEN
			FOR i := 0 TO 15 DO dist[i] := 0 END;
			i := 0; NEW(path);
			WHILE s[i] # 0X DO
				GfxFonts.GetOutline(c.gc.font, s[i], x, y, path);
				GfxPaths.Open(psc, path, 0); n := 0;
				WHILE psc.elem # GfxPaths.Stop DO
					IF psc.elem = GfxPaths.Enter THEN INC(n) END;
					GfxPaths.Scan(psc)
				END;
				IF n # 0 THEN
					Gfx.DrawPath(c.gc, path, {Gfx.Record});
					c.pen.do.render(c.pen, c.gc, dist, dist, n)
				END;
				GfxFonts.GetWidth(c.gc.font, s[i], dx, dy);
				x := x + dx; y := y + dy
			END
		ELSIF c.mode * {Gfx.InPath, Gfx.InSubpath} = {Gfx.InPath} THEN
			Gfx.ShowAt(c.gc, x, y, s)
		ELSE Scheme.Fail(c, "not within path or already within subpath", c.exp)
		END
	END EvalText;

	PROCEDURE EvalLabel (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; str: Object; mode: SIGNED32; x, y, phi, dx, dy: FLOAT32; ctm: GfxMatrix.Matrix; s: ARRAY 300 OF CHAR;
	BEGIN
		c := ctxt(Context); str := Ops.StringArg(c, args); mode := Ops.IntVal(c, args); x := NumVal(c, args); y := NumVal(c, args);
		IF Scheme.IsNull(args) THEN phi := 0
		ELSE phi := NumVal(c, args)
		END;
		Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c); RETURN END;
		IF phi # 0 THEN
			ctm := c.gc.ctm; Gfx.Rotate(c.gc, Math.sin(phi), Math.cos(phi))
		END;
		Scheme.GetString(str, 0, Scheme.StringLen(str), s);
		IF mode # 0 THEN
			Gfx.GetStringWidth(c.gc, s, dx, dy);
			IF mode IN {1, 2, 9} THEN x := x - 0.5*dx; y := y - 0.5*dy
			ELSIF mode IN {6, 7, 8} THEN x := x - dx; y := y - dy
			END;
			IF mode IN {1, 4, 7} THEN y := y - 0.5*(c.gc.font.ymax + c.gc.font.ymin)
			ELSIF mode IN {2, 3, 6} THEN y := y - c.gc.font.ymin
			ELSE y := y - c.gc.font.ymax
			END
		END;
		Gfx.DrawStringAt(c.gc, x, y, s);
		IF phi # 0 THEN
			Gfx.SetCTM(c.gc, ctm)
		END
	END EvalLabel;

	PROCEDURE EvalSaveCTM (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; body: Object; ctm: GfxMatrix.Matrix;
	BEGIN
		c := ctxt(Context); body := Ops.ProcArg(c, args); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF c.mode * {Gfx.InPath, inPen} = {} THEN
			ctm := c.gc.ctm;
			Scheme.Call(c, body, Scheme.nil);
			Gfx.SetCTM(c.gc, ctm)
		ELSE Scheme.Fail(c, "not allowed within path", c.exp)
		END
	END EvalSaveCTM;

	PROCEDURE EvalSaveClip (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; body: Object; clip: Gfx.ClipArea;
	BEGIN
		c := ctxt(Context); body := Ops.ProcArg(c, args); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF c.mode * {Gfx.InPath, inPen} = {} THEN
			clip := Gfx.GetClip(c.gc);
			Scheme.Call(c, body, Scheme.nil);
			Gfx.SetClip(c.gc, clip)
		ELSE Scheme.Fail(c, "not allowed within path", c.exp)
		END
	END EvalSaveClip;

	PROCEDURE EvalWith (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR
			c: Context; state: Gfx.State; eo: BOOLEAN; p: LeoPens.Pen; obj: Object; col: Gfx.Color; img: Images.Image;
			px, py: FLOAT32; on, off: ARRAY Gfx.MaxDashPatSize OF FLOAT32; n: SIGNED32; name: ARRAY 64 OF CHAR;
	BEGIN
		c := ctxt(Context);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF c.mode * {Gfx.InPath, inPen} = {} THEN
			Gfx.Save(c.gc, Gfx.attr, state); eo := c.evenodd; p := c.pen;
			obj := Ops.Arg(c, args);
			WHILE Scheme.IsSymbol(obj) DO
				IF obj = strokecol THEN GetColorVal(c, args, col); Gfx.SetStrokeColor(c.gc, col)
				ELSIF obj = fillcol THEN GetColorVal(c, args, col); Gfx.SetFillColor(c.gc, col)
				ELSIF obj = color THEN GetColorVal(c, args, col); Gfx.SetStrokeColor(c.gc, col); Gfx.SetFillColor(c.gc, col)
				ELSIF obj = strokepat THEN
					GetPatternVal(c, args, img, px, py);
					IF img = NIL THEN Gfx.SetStrokePattern(c.gc, NIL)
					ELSE Gfx.SetStrokePattern(c.gc, Gfx.NewPattern(c.gc, img, px, py))
					END
				ELSIF obj = fillpat THEN
					GetPatternVal(c, args, img, px, py);
					IF img = NIL THEN Gfx.SetFillPattern(c.gc, NIL)
					ELSE Gfx.SetFillPattern(c.gc, Gfx.NewPattern(c.gc, img, px, py))
					END
				ELSIF obj = pattern THEN
					GetPatternVal(c, args, img, px, py);
					IF img = NIL THEN Gfx.SetFillPattern(c.gc, NIL); Gfx.SetFillPattern(c.gc, NIL);
					ELSE Gfx.SetStrokePattern(c.gc, Gfx.NewPattern(c.gc, img, px, py)); Gfx.SetFillPattern(c.gc, c.gc.strokePat)
					END
				ELSIF obj = width THEN Gfx.SetLineWidth(c.gc, NumVal(c, args))
				ELSIF obj = dash THEN GetDashVal(c, args, on, off, n); Gfx.SetDashPattern(c.gc, on, off, n, c.gc.dashPhase)
				ELSIF obj = phase THEN Gfx.SetDashPattern(c.gc, c.gc.dashPatOn, c.gc.dashPatOff, c.gc.dashPatLen, NumVal(c, args))
				ELSIF obj = cap THEN Gfx.SetCapStyle(c.gc, CapVal(c, args))
				ELSIF obj = join THEN Gfx.SetJoinStyle(c.gc, JoinVal(c, args))
				ELSIF obj = limit THEN Gfx.SetStyleLimit(c.gc, NumVal(c, args))
				ELSIF obj = flatness THEN Gfx.SetFlatness(c.gc, NumVal(c, args))
				ELSIF obj = font THEN
					obj := Ops.StringArg(c, args); Scheme.GetString(obj, 0, Scheme.StringLen(obj), name);
					Gfx.SetFont(c.gc, GfxFonts.OpenSize(name, c.gc.font.ptsize))
				ELSIF obj = size THEN Gfx.SetFont(c.gc, GfxFonts.OpenSize(c.gc.font.name, SHORT(Ops.IntVal(c, args))))
				ELSIF obj = evenodd THEN c.evenodd := Ops.BoolVal(c, args)
				ELSIF obj = pen THEN c.pen := PenVal(c, args)
				ELSE Scheme.Fail(c, "unkown attribute", obj)
				END;
				obj := Ops.Arg(c, args)
			END;
			Ops.CheckNull(c, args);
			IF Scheme.IsProcedure(obj) THEN Scheme.Call(c, obj, Scheme.nil)
			ELSE Scheme.Fail(c, "argument must be procedure", obj)
			END;
			IF Gfx.InPath IN c.gc.mode THEN Gfx.End(c.gc) END;
			Gfx.Restore(c.gc, state); c.evenodd := eo; c.pen := p
		ELSE Scheme.Fail(c, "not allowed within path", c.exp)
		END
	END EvalWith;

	PROCEDURE EvalImport (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; sym: Object;
	BEGIN
		c := ctxt(Context);
		REPEAT
			sym := Ops.SymbolArg(c, args);
			IF ~c.failed THEN Import(c, sym) END
		UNTIL Scheme.IsNull(args)
	END EvalImport;

	PROCEDURE EvalQualify (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; sym: Object; pack: Package;
	BEGIN
		c := ctxt(Context); sym := Ops.SymbolArg(c, args);
		pack := FindPackage(sym);
		IF pack # NIL THEN
			sym := Ops.SymbolArg(c, args); Ops.CheckNull(c, args);
			res := FindSymbol(c, pack, sym)
		ELSE Scheme.Fail(c, "package not found", sym)
		END
	END EvalQualify;

	PROCEDURE EvalModule (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; str: Object; s: ARRAY 64 OF CHAR;
	BEGIN
		c := ctxt(Context); res := Scheme.true;
		REPEAT
			str := Ops.StringArg(c, args);
			IF ~c.failed THEN
				Scheme.GetString(str, 0, Scheme.StringLen(str), s);
				IF Modules.ThisMod(s) = NIL THEN res := Scheme.false END
			END
		UNTIL c.failed OR Scheme.IsNull(args)
	END EvalModule;


	PROCEDURE MakeMatrix (VAR m: GfxMatrix.Matrix): Object;
		VAR vec: Object; i: SIGNED32;
	BEGIN
		vec := Scheme.NewVector(6, Scheme.nil);
		FOR i := 0 TO 5 DO
			Scheme.SetVectorAt(vec, i, Scheme.NewReal(m[i DIV 2, i MOD 2]))
		END;
		RETURN vec
	END MakeMatrix;

	PROCEDURE EvalCTM (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context;
	BEGIN
		c := ctxt(Context); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSE res := MakeMatrix(c.gc.ctm)
		END
	END EvalCTM;

	PROCEDURE EvalTranslate (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; dx, dy: FLOAT32;
	BEGIN
		c := ctxt(Context); dx := NumVal(c, args);
		IF ~Scheme.IsNull(args) THEN dy := NumVal(c, args) ELSE dy := 0 END;
		Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSE Gfx.Translate(c.gc, dx, dy)
		END
	END EvalTranslate;

	PROCEDURE EvalScale (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; sx, sy, x, y: FLOAT32;
	BEGIN
		c := ctxt(Context); sx := NumVal(c, args);
		IF ~Scheme.IsNull(args) THEN sy := NumVal(c, args) ELSE sy := sx END;
		IF c.gc = NIL THEN FailGC(c)
		ELSIF Scheme.IsNull(args) THEN
			Gfx.Scale(c.gc, sx, sy)
		ELSE
			x := sy; sy := sx; y := NumVal(c, args);
			IF ~Scheme.IsNull(args) THEN sy := x; x := y; y := NumVal(c, args) END;
			Ops.CheckNull(c, args);
			Gfx.ScaleAt(c.gc, sx, sy, x, y)
		END
	END EvalScale;

	PROCEDURE EvalRotate (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; phi, x, y: FLOAT32;
	BEGIN
		c := ctxt(Context); phi := NumVal(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF Scheme.IsNull(args) THEN
			Gfx.Rotate(c.gc, Math.sin(phi), Math.cos(phi))
		ELSE
			x := NumVal(c, args); y := NumVal(c, args); Ops.CheckNull(c, args);
			Gfx.RotateAt(c.gc, Math.sin(phi), Math.cos(phi), x, y)
		END
	END EvalRotate;

	PROCEDURE EvalRad (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; deg: FLOAT32;
	BEGIN
		c := ctxt(Context); deg := NumVal(c, args); res := Scheme.NewReal(deg * MathL.pi/180.0D0)
	END EvalRad;

	PROCEDURE EvalConcat (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; m: GfxMatrix.Matrix;
	BEGIN
		c := ctxt(Context); GetMatrixVal(c, args, m); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSE Gfx.Concat(c.gc, m)
		END
	END EvalConcat;

	PROCEDURE EvalSetCTM (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; m: GfxMatrix.Matrix;
	BEGIN
		c := ctxt(Context); GetMatrixVal(c, args, m); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSE Gfx.SetCTM(c.gc, m)
		END
	END EvalSetCTM;


	PROCEDURE EvalClipRect (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; xy: ARRAY 4 OF FLOAT32; i: SIGNED32;
	BEGIN
		c := ctxt(Context); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSE
			Gfx.GetClipRect(c.gc, xy[0], xy[1], xy[2], xy[3]);
			res := Scheme.NewVector(4, Scheme.nil);
			FOR i := 0 TO 3 DO Scheme.SetVectorAt(res, i, Scheme.NewReal(xy[i])) END
		END
	END EvalClipRect;


	PROCEDURE EvalShape (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; ref: Objects.Object; s: Leonardo.Shape; rm: Leonardo.RenderMsg;
	BEGIN
		c := ctxt(Context); ref := Ops.RefVal(c, args); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF ref = NIL THEN Scheme.Fail(c, "NIL reference", Scheme.NewRef(NIL))
		ELSIF ref IS Leonardo.Shape THEN
			s := ref(Leonardo.Shape);
			rm.id := Leonardo.passive; rm.ctxt := c.gc; rm.gsm := GfxMatrix.Identity;
			rm.llx := s.llx; rm.lly := s.lly; rm.urx := s.urx; rm.ury := s.ury;
			s.handle(s, rm)
		ELSE Scheme.Fail(c, "argument must be shape", Scheme.NewRef(ref))
		END
	END EvalShape;


	PROCEDURE MakeColor (r, g, b: SIGNED32): Object;
		VAR vec: Object;
	BEGIN
		IF r < 0 THEN r := 0 ELSIF r > 255 THEN r := 255 END;
		IF g < 0 THEN g := 0 ELSIF g > 255 THEN g := 255 END;
		IF b < 0 THEN b := 0 ELSIF b > 255 THEN b := 255 END;
		vec := Scheme.NewVector(3, Scheme.nil);
		Scheme.SetVectorAt(vec, 0, Scheme.NewInteger(r));
		Scheme.SetVectorAt(vec, 1, Scheme.NewInteger(g));
		Scheme.SetVectorAt(vec, 2, Scheme.NewInteger(b));
		RETURN Pair(color, vec)
	END MakeColor;

	PROCEDURE EvalColorsRGB (c: Scheme.Context; args: Object; VAR res: Object);
		CONST max = 255.999;
		VAR r, g, b: FLOAT64;
	BEGIN
		r := NumVal(c, args); g := NumVal(c, args); b := NumVal(c, args); Ops.CheckNull(c, args);
		res := MakeColor(ENTIER(max * r), ENTIER(max * g), ENTIER(max * b))
	END EvalColorsRGB;

	PROCEDURE EvalColorsGray (c: Scheme.Context; args: Object; VAR res: Object);
		VAR g: SIGNED32;
	BEGIN
		g := ENTIER(255.999 * NumVal(c, args)); Ops.CheckNull(c, args);
		res := MakeColor(g, g, g)
	END EvalColorsGray;

	PROCEDURE EvalColorsIndex (c: Scheme.Context; args: Object; VAR res: Object);
		VAR i: SIGNED32; r, g, b: SIGNED16;
	BEGIN
		i := Ops.IntVal(c, args); Ops.CheckNull(c, args);
		Display.GetColor(i, r, g, b);
		res := MakeColor(r, g, b)
	END EvalColorsIndex;

	PROCEDURE EvalColorsRed (c: Scheme.Context; args: Object; VAR res: Object);
		VAR col: Gfx.Color;
	BEGIN
		GetColorVal(c, args, col); Ops.CheckNull(c, args);
		res := Scheme.NewReal(col.r/255)
	END EvalColorsRed;

	PROCEDURE EvalColorsGreen (c: Scheme.Context; args: Object; VAR res: Object);
		VAR col: Gfx.Color;
	BEGIN
		GetColorVal(c, args, col); Ops.CheckNull(c, args);
		res := Scheme.NewReal(col.g/255)
	END EvalColorsGreen;

	PROCEDURE EvalColorsBlue (c: Scheme.Context; args: Object; VAR res: Object);
		VAR col: Gfx.Color;
	BEGIN
		GetColorVal(c, args, col); Ops.CheckNull(c, args);
		res := Scheme.NewReal(col.b/255)
	END EvalColorsBlue;



	PROCEDURE EvalMatrixInit (c: Scheme.Context; args: Object; VAR res: Object);
		VAR i: SIGNED32;
	BEGIN
		res := Scheme.NewVector(6, Scheme.nil);
		FOR i := 0 TO 5 DO Scheme.SetVectorAt(res, i, Ops.NumArg(c, args)) END;
		Ops.CheckNull(c, args)
	END EvalMatrixInit;

	PROCEDURE EvalMatrixInvert (c: Scheme.Context; args: Object; VAR res: Object);
		VAR m: GfxMatrix.Matrix;
	BEGIN
		GetMatrixVal(c, args, m); Ops.CheckNull(c, args);
		GfxMatrix.Invert(m, m);
		res := MakeMatrix(m)
	END EvalMatrixInvert;

	PROCEDURE EvalMatrixTranslate (c: Scheme.Context; args: Object; VAR res: Object);
		VAR m: GfxMatrix.Matrix; dx, dy: FLOAT64;
	BEGIN
		GetMatrixVal(c, args, m); dx := NumVal(c, args); dy := NumVal(c, args); Ops.CheckNull(c, args);
		GfxMatrix.Translate(m, SHORT(dx), SHORT(dy), m);
		res := MakeMatrix(m)
	END EvalMatrixTranslate;

	PROCEDURE EvalMatrixScale (c: Scheme.Context; args: Object; VAR res: Object);
		VAR m: GfxMatrix.Matrix; sx, sy: FLOAT64;
	BEGIN
		GetMatrixVal(c, args, m); sx := NumVal(c, args);
		IF Scheme.IsPair(args) THEN sy := NumVal(c, args)
		ELSE sx := sy
		END;
		Ops.CheckNull(c, args);
		GfxMatrix.Scale(m, SHORT(sx), SHORT(sy), m);
		res := MakeMatrix(m)
	END EvalMatrixScale;

	PROCEDURE EvalMatrixRotate (c: Scheme.Context; args: Object; VAR res: Object);
		VAR m: GfxMatrix.Matrix; phi: FLOAT64;
	BEGIN
		GetMatrixVal(c, args, m); phi := NumVal(c, args); Ops.CheckNull(c, args);
		GfxMatrix.Rotate(m, SHORT(MathL.sin(phi)), SHORT(MathL.cos(phi)), m);
		res := MakeMatrix(m)
	END EvalMatrixRotate;

	PROCEDURE EvalMatrixConcat (c: Scheme.Context; args: Object; VAR res: Object);
		VAR m, n: GfxMatrix.Matrix;
	BEGIN
		GetMatrixVal(c, args, m);
		WHILE Scheme.IsPair(args) DO
			GetMatrixVal(c, args, n);
			GfxMatrix.Concat(m, n, m)
		END;
		Ops.CheckNull(c, args);
		res := MakeMatrix(m)
	END EvalMatrixConcat;


	PROCEDURE EvalImagesLoad (c: Scheme.Context; args: Object; VAR res: Object);
		VAR str: Object; s: ARRAY 64 OF CHAR; img: Images.Image; done: BOOLEAN;
	BEGIN
		str := Ops.StringArg(c, args); Ops.CheckNull(c, args);
		IF str # Scheme.nil THEN
			Scheme.GetString(str, 0, Scheme.StringLen(str), s);
			NEW(img); Images.Load(img, s, done);
			IF done THEN res := Scheme.NewRef(img)
			ELSE Scheme.Fail(c, "cannot load image file", str)
			END
		END
	END EvalImagesLoad;

	PROCEDURE EvalImagesPrintpattern (c: Scheme.Context; args: Object; VAR res: Object);
		VAR pat: SIGNED32; img: Images.Image;
	BEGIN
		pat := Ops.IntVal(c, args); Ops.CheckNull(c, args);
		IF (1 <= pat) & (pat <= 8) THEN NEW(img); PictImages.PatternToImage(pat, img); res := Scheme.NewRef(img)
		ELSE Scheme.Fail(c, "illegal pattern number", Scheme.NewInteger(pat))
		END
	END EvalImagesPrintpattern;

	PROCEDURE EvalImagesNewpattern (c: Scheme.Context; args: Object; VAR res: Object);
		VAR ref, x, y, vec: Object; obj: Objects.Object;
	BEGIN
		ref := Ops.RefArg(c, args); x := Ops.NumArg(c, args); y := Ops.NumArg(c, args); Ops.CheckNull(c, args);
		obj := Scheme.RefValue(ref);
		IF (obj # NIL) & (obj IS Images.Image) THEN
			vec := Scheme.NewVector(3, Scheme.nil);
			Scheme.SetVectorAt(vec, 0, ref); Scheme.SetVectorAt(vec, 1, x); Scheme.SetVectorAt(vec, 2, y);
			res := Pair(pattern, vec)
		ELSE Scheme.Fail(c, "reference argument must be image", ref)
		END
	END EvalImagesNewpattern;

	PROCEDURE EvalImagesDraw (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; ref: Objects.Object; x, y: FLOAT32;
	BEGIN
		c := ctxt(Context); ref := Ops.RefVal(c, args); x := NumVal(c, args); y := NumVal(c, args); Ops.CheckNull(c, args);
		IF c.gc = NIL THEN FailGC(c)
		ELSIF (ref # NIL) & (ref IS Images.Image) THEN
			Gfx.DrawImageAt(c.gc, x, y, ref(Images.Image), GfxImages.NoFilter)
		END
	END EvalImagesDraw;

	PROCEDURE EvalImagesCrop (c: Scheme.Context; args: Object; VAR res: Object);
		VAR ref: Objects.Object; llx, lly, urx, ury: SIGNED32; base, img: Images.Image;
	BEGIN
		ref := Ops.RefVal(c, args); llx := Ops.IntVal(c, args); lly := Ops.IntVal(c, args);
		urx := Ops.IntVal(c, args); ury := Ops.IntVal(c, args); Ops.CheckNull(c, args);
		IF (ref # NIL) & (ref IS Images.Image) THEN
			base := ref(Images.Image);
			IF (0 <= llx) & (llx < urx) & (urx <= base.width) & (0 <= lly) & (lly < ury) & (ury <= base.height) THEN
				NEW(img); Images.InitRect(img, base, SHORT(llx), SHORT(lly), SHORT(urx - llx), SHORT(ury - lly));
				res := Scheme.NewRef(img)
			ELSE Scheme.Fail(c, "illegal crop rectangle", Scheme.nil)
			END
		ELSE Scheme.Fail(c, "object is not an image", Scheme.NewRef(ref))
		END
	END EvalImagesCrop;


	(**--- Initialization ---**)

	PROCEDURE Def* (name: ARRAY OF CHAR; eval: Scheme.PrimEval);
		VAR sym: Object;
	BEGIN
		sym := Scheme.NewSymbol(name);
		Scheme.DefineVariable(sym, Scheme.NewPrimitive(sym, eval), globals)
	END Def;

	(** define package symbols **)
	PROCEDURE ODef* (p, s: ARRAY OF CHAR; obj: Object);
		VAR name: Object; pack: Package;
	BEGIN
		name := Scheme.NewSymbol(p); pack := FindPackage(name);
		IF pack = NIL THEN
			NEW(pack); pack.name := name; pack.env := Scheme.NewEnvironment(globals);
			pack.next := Packages; Packages := pack
		END;
		Scheme.DefineVariable(Scheme.NewSymbol(s), obj, pack.env)
	END ODef;

	PROCEDURE PDef* (p, s: ARRAY OF CHAR; eval: Scheme.PrimEval);
		VAR t: ARRAY 128 OF CHAR;
	BEGIN
		COPY(p, t); Strings.AppendCh(t, "."); Strings.Append(t, s);
		ODef(p, s, Scheme.NewPrimitive(Scheme.NewSymbol(t), eval))
	END PDef;

	PROCEDURE Init;
		VAR txt: Texts.Text; out, body: Object; ctxt: Scheme.Context;

		PROCEDURE sym (s: ARRAY OF CHAR; VAR obj: Object);
		BEGIN
			obj := Scheme.NewSymbol(s);
		END sym;

		PROCEDURE def (s: ARRAY OF CHAR; VAR sym: Object; eval: Scheme.PrimEval);
		BEGIN
			sym := Scheme.NewSymbol(s);
			Scheme.DefineVariable(sym, Scheme.NewPrimitive(sym, eval), globals)
		END def;

	BEGIN
		globals := Scheme.NewEnvironment(Scheme.globals);

		Scheme.DefineVariable(Scheme.NewSymbol("true"), Scheme.true, globals);
		Scheme.DefineVariable(Scheme.NewSymbol("false"), Scheme.false, globals);

		sym("=", opeq); sym("<>", opneq); sym("<", oplt); sym("<=", opleq);
		sym("+", opplus); sym("-", opminus); sym("*", opmul); sym("/", opdiv);
		sym("div", div); sym("modulo", mod); sym("quotient", opquot);
		sym("and", opand); sym("or", or); sym("not", opnot);
		sym("string-append", opconcat); sym("begin", begin); sym("define", define); sym("if", if);
		sym("lambda", lambda); sym("let", let); sym("quote", quote); sym("exact->inexact", toinexact);
		sym("above", above); sym("as", as); sym("at", at); sym("below", below); sym("by", by);
		sym("const", const); sym("do", do); sym("else", else); sym("elsif", elsif); sym("end", end);
		sym("in", in); sym("left", left); sym("lower", lower); sym("of", of); sym("over", over);
		sym("restore", restore); sym("right", right); sym("rotated", rotated);
		sym("upper", upper); sym("then", then); sym("times", times);

		sym("strokecol", strokecol); sym("fillcol", fillcol); sym("color", color);
		sym("strokepat", strokepat); sym("fillpat", fillpat); sym("pattern", pattern);
		sym("width", width); sym("dash", dash); sym("phase", phase); sym("cap", cap); sym("join", join);
		sym("limit", limit); sym("flatness", flatness); sym("font", font); sym("size", size);
		sym("evenodd", evenodd); sym("pen", pen);

		def("for", for, EvalFor); def("repeat", repeat, EvalRepeat);
		def("clip", clip, EvalClip); def("draw", draw, EvalDraw); def("fill", fill, EvalFill);
		def("record", record, EvalRecord); def("stroke", stroke, EvalStroke); def("end-path", endpath, EndPath);
		def("enter", enter, EvalEnter); def("exit", exit, EvalExit);
		def("from", from, EvalFrom); def("to", to, EvalTo); def("close", close, EvalClose);
		def("arc", arc, EvalArc); def("curve", curve, EvalCurve); def("corner", corner, EvalCorner);
		def("text", text, EvalText); def("label", label, EvalLabel);
		def("savectm", savectm, EvalSaveCTM); def("saveclip", saveclip, EvalSaveClip); def("with", with, EvalWith);
		def("import", import, EvalImport); def("qualify", qualify, EvalQualify);
		def("module", module, EvalModule);

		Def("ctm", EvalCTM); Def("translate", EvalTranslate); Def("scale", EvalScale); Def("rotate", EvalRotate);
		Def("rad", EvalRad); Def("concat", EvalConcat); Def("setctm", EvalSetCTM);

		Def("cliprect", EvalClipRect);
		Def("shape", EvalShape);

		PDef("colors", "rgb", EvalColorsRGB); PDef("colors", "gray", EvalColorsGray); PDef("colors", "index", EvalColorsIndex);
		PDef("colors", "r", EvalColorsRed); PDef("colors", "g", EvalColorsGreen); PDef("colors", "b", EvalColorsBlue);
		ODef("colors", "white", MakeColor(255, 255, 255)); ODef("colors", "black", MakeColor(0, 0, 0));
		ODef("colors", "red", MakeColor(255, 0, 0)); ODef("colors", "green", MakeColor(0, 255, 0));
		ODef("colors", "blue", MakeColor(0, 0, 255)); ODef("colors", "cyan", MakeColor(0, 255, 255));
		ODef("colors", "magenta", MakeColor(255, 0, 255)); ODef("colors", "yellow", MakeColor(255, 255, 0));

		PDef("matrix", "init", EvalMatrixInit); PDef("matrix", "invert", EvalMatrixInvert);
		PDef("matrix", "translate", EvalMatrixTranslate); PDef("matrix", "scale", EvalMatrixScale);
		PDef("matrix", "rotate", EvalMatrixRotate); PDef("matrix", "concat", EvalMatrixConcat);

		PDef("images", "load", EvalImagesLoad);
		PDef("images", "printpattern", EvalImagesPrintpattern); PDef("images", "newpattern", EvalImagesNewpattern);
		PDef("images", "draw", EvalImagesDraw); PDef("images", "crop", EvalImagesCrop);

		NEW(txt); Texts.Open(txt, "Vinci.Init");
		IF txt.len # 0 THEN
			out := Scheme.NewTextOutput(Oberon.Log);
			NEW(ctxt); Scheme.InitContext(ctxt, Scheme.NewTextInput(txt, 0), out, out);
			Parse(ctxt, body);
			IF body # NIL THEN
				Scheme.EvaluateSequence(ctxt, globals, body)
			END
		END
	END Init;


BEGIN
	NEW(Err); Texts.Open(Err, "");
	first := Pair(Scheme.nil, Scheme.nil);
	Init
END Vinci.
