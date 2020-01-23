MODULE RegExpParse; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "RegExp parser module"; *)

(*
// This code is in the public domain - feel free to do anything you
// wish with it.
//
// Eli Bendersky (spur4444@yahoo.com)
//
*)

IMPORT
	Strings, Commands,

	PreciseTimer,

	RegExpNFA, RegExpDFA, RegExpSubsetConstruct;

	(*

	The BNF for our simple regexes is:

	expr   ::= concat '|' expr
	         | concat

	concat ::= rep . concat
	         | rep

	rep    ::= atom '*'
	         | atom '?'
	         | atom

	atom   ::= chr
	         | '(' expr ')'

	char   ::= alphanumeric character

	*)

CONST
	NODE_TYPE_CHAR		= 1;
	NODE_TYPE_STAR		= 2;
	NODE_TYPE_QUESTION = 3;
	NODE_TYPE_ALTER		= 4;
	NODE_TYPE_CONCAT	= 5;

TYPE

	ParseNode = POINTER TO ParseNodeDesc;
	ParseNodeDesc = RECORD
		iType: SHORTINT;
		iData: LONGINT;
		left, right: ParseNode;
	END;

	String = Strings.String;

	Scanner = OBJECT
		VAR
			str: String;
			iNext: LONGINT;

		PROCEDURE &New(CONST str: ARRAY OF CHAR);
		BEGIN
			SELF.str := Preprocess(str);
			iNext := 0
		END New;

		PROCEDURE Peek(): CHAR;
		BEGIN
			IF iNext < LEN(str^) THEN
				RETURN str^[iNext]
			ELSE
				RETURN 0X
			END
		END Peek;

		PROCEDURE Pop(): CHAR;
		VAR
			c: CHAR;
		BEGIN
			c := Peek();
			IF iNext < LEN(str^) THEN
				INC(iNext)
			END;
			RETURN c
		END Pop;

		(*PROCEDURE Pos(): LONGINT;
		BEGIN
			RETURN iNext
		END Pos;*)

		PROCEDURE NeedConcat(c, cNext: CHAR): BOOLEAN;
		BEGIN
			RETURN (IsAlphaNumber(c) OR (c = ')') OR (c = '*') OR (c = '?')) &
				((cNext # 0X) & (cNext # ')') & (cNext # '|') & (cNext # '*') & (cNext # '?'))
		END NeedConcat;

		(* Generates concatenation chars ('.') where appropriate *)
		PROCEDURE Preprocess(CONST strIn: ARRAY OF CHAR): String;
		VAR
			iIn, nConcat, iOut: LONGINT;
			strOut: String;
		BEGIN
			iIn := 0;
			nConcat := 0;
			WHILE strIn[iIn] # 0X DO
				IF NeedConcat(strIn[iIn], strIn[iIn + 1]) THEN
					INC(nConcat)
				END;
				INC(iIn)
			END;
			NEW(strOut, iIn + nConcat + 1);
			iIn := 0;
			iOut := 0;
			WHILE strIn[iIn] # 0X DO
				strOut^[iOut] := strIn[iIn];
				IF NeedConcat(strIn[iIn], strIn[iIn + 1]) THEN
					INC(iOut);
					strOut^[iOut] := '.'
				END;
				INC(iOut);
				INC(iIn)
			END;
			RETURN strOut
		END Preprocess;

	END Scanner;

VAR
	scanner: Scanner;

	strInput: String;

	PROCEDURE IsAlphaNumber(c: CHAR): BOOLEAN;
	BEGIN
		RETURN ~((c = '*') OR (c = '(') OR (c = ')') OR
			(c = '|') OR (c = '?'))
	END IsAlphaNumber;

	PROCEDURE NewParseNode(iType: SHORTINT; iData: LONGINT; left, right: ParseNode): ParseNode;
	VAR
		node: ParseNode;
	BEGIN
		NEW(node);
		node.iType := iType;
		node.iData := iData;
		node.left := left;
		node.right := right;
		RETURN node
	END NewParseNode;

	(*
	char   ::= alphanumeric character
	*)
	PROCEDURE Chr(): ParseNode;
	VAR
		c: CHAR;
	BEGIN
		c := scanner.Peek();
		IF IsAlphaNumber(c) THEN
			RETURN NewParseNode(NODE_TYPE_CHAR, ORD(scanner.Pop()), NIL, NIL)
		END;
		(*     cerr 	<< "Parse error: expected alphanumeric, got "
			<<  my_scanner().peek() << " at #" << my_scanner().get_pos() << endl; *)
		HALT(100)
	END Chr;

	(*
	atom   ::= chr
	         | '(' expr ')'
	*)
	PROCEDURE Atom(): ParseNode;
	VAR
		atom: ParseNode;
		c: CHAR;
	BEGIN
		IF scanner.Peek() = '(' THEN
			c := scanner.Pop();
			atom := Expr();
			IF scanner.Pop() # ')' THEN
				(* Parse error: expected ')' *)
				HALT(100)
			END
		ELSE
			atom := Chr()
		END;
		RETURN atom
	END Atom;

	(*
	rep    ::= atom '*'
	         | atom '?'
	         | atom
	*)
	PROCEDURE Rep(): ParseNode;
	VAR
		left: ParseNode;
		c: CHAR;
	BEGIN
		left := Atom();
		IF scanner.Peek() = '*' THEN
			c := scanner.Pop();
			RETURN NewParseNode(NODE_TYPE_STAR, 0, left, NIL)
		ELSIF scanner.Peek() = '?' THEN
			c := scanner.Pop();
			RETURN NewParseNode(NODE_TYPE_QUESTION, 0, left, NIL)
		ELSE
			RETURN left
		END
	END Rep;

	(*
	concat ::= rep . concat
	         | rep
	*)
	PROCEDURE Concat(): ParseNode;
	VAR
		left: ParseNode;
		c: CHAR;
	BEGIN
		left := Rep();
		IF scanner.Peek() = '.' THEN
			c := scanner.Pop();
			RETURN NewParseNode(NODE_TYPE_CONCAT, 0, left, Concat())
		ELSE
			RETURN left
		END
	END Concat;

	(*
	expr   ::= concat '|' expr
	         | concat
	*)
	PROCEDURE Expr(): ParseNode;
	VAR
		left: ParseNode;
		c: CHAR;
	BEGIN
		left := Concat();
		IF scanner.Peek() = '|' THEN
			c := scanner.Pop();
			RETURN NewParseNode(NODE_TYPE_ALTER, 0, left, Expr())
		ELSE
			RETURN left
		END
	END Expr;

	PROCEDURE PrintTree(context: Commands.Context; tree: ParseNode; nOffset: LONGINT);
	VAR
		i: LONGINT;
	BEGIN
		IF tree # NIL THEN
			FOR i := 0 TO nOffset - 1 DO
				context.out.String(" ")
			END;
			CASE tree.iType OF
				NODE_TYPE_CHAR:	context.out.Char(CHR(tree.iData));
			|	NODE_TYPE_STAR:	context.out.Char('*');
			|	NODE_TYPE_QUESTION:	context.out.Char('?');
			|	NODE_TYPE_ALTER:	context.out.Char('|');
			|	NODE_TYPE_CONCAT:	context.out.Char('.');
			ELSE
			END;
			context.out.Ln;
			PrintTree(context, tree.left, nOffset + 4);
			PrintTree(context, tree.right, nOffset + 4)
		END
	END PrintTree;

	PROCEDURE TreeToNFA(tree: ParseNode): RegExpNFA.NFA;
	BEGIN
		IF tree # NIL THEN
			CASE tree.iType OF
				NODE_TYPE_CHAR: RETURN RegExpNFA.BuildNFABasic(RegExpNFA.NODE_TYPE_DATA, tree.iData);
			|	NODE_TYPE_STAR: RETURN RegExpNFA.BuildNFAStar(TreeToNFA(tree.left));
			|	NODE_TYPE_QUESTION: RETURN RegExpNFA.BuildNFAAlter(TreeToNFA(tree.left), RegExpNFA.BuildNFABasic(RegExpNFA.NODE_TYPE_EPS, 0));
			|	NODE_TYPE_ALTER: RETURN RegExpNFA.BuildNFAAlter(TreeToNFA(tree.left), TreeToNFA(tree.right));
			|	NODE_TYPE_CONCAT: RETURN RegExpNFA.BuildNFAConcat(TreeToNFA(tree.left), TreeToNFA(tree.right));
			ELSE
				HALT(100)
			END;
		END;
	END TreeToNFA;

	PROCEDURE Test*(context: Commands.Context);
	CONST
		TRIES_NFA = 5000;
		TRIES_DFA = 500;
		TRIES_SIM = 50000;

	VAR
		tree: ParseNode;
		nfa: RegExpNFA.NFA;
		dfa: RegExpDFA.DFA;
		iInput, iNext, iTry: LONGINT;

		t, tNFA, tDFA, tSim: HUGEINT;

	BEGIN
		context.out.Ln;

		NEW(scanner,'(1|2|3|4)*(c|d|e|f)?(a|b|g|h)*(c|d|e|f)?abbv');
		tree := Expr();

		(* NFA *)
		t := PreciseTimer.GetTicks();
		FOR iTry := 0 TO TRIES_NFA - 1 DO
			nfa := TreeToNFA(tree)
		END;
		tNFA := PreciseTimer.GetTicks() - t;

		(* Construct DFA *)
		t := PreciseTimer.GetTicks();
		FOR iTry := 0 TO TRIES_DFA - 1 DO
			dfa := RegExpSubsetConstruct.SubsetConstruct(nfa)
		END;
		tDFA := PreciseTimer.GetTicks() - t;

		(* Simulation with input string *)
		t := PreciseTimer.GetTicks();
		FOR iTry := 0 TO TRIES_SIM - 1 DO
			iInput := 0;
			WHILE (iInput < LEN(strInput^)) & (strInput^[iInput] # 0X) DO
				IF dfa.Simulate(strInput^, iInput, iNext) THEN
					WHILE iInput < iNext DO
						INC(iInput)
					END;
				ELSE
					INC(iInput)
				END
			END
		END;
		tSim := PreciseTimer.GetTicks() - t;

		context.out.String("Time for NFA: ");
		context.out.Float(PreciseTimer.GetTime(tNFA) / TRIES_NFA, 15);
		context.out.Ln;
		context.out.String("Time for DFA: ");
		context.out.Float(PreciseTimer.GetTime(tDFA) / TRIES_DFA, 15);
		context.out.Ln;
		context.out.String("Time for simulation: ");
		context.out.Float(PreciseTimer.GetTime(tSim) / TRIES_SIM, 15);
		context.out.Ln;
		context.out.String("Total time: ");
		context.out.Float(PreciseTimer.GetTime(tNFA) / TRIES_NFA +
			PreciseTimer.GetTime(tDFA) / TRIES_DFA +
			PreciseTimer.GetTime(tSim) / TRIES_SIM, 15);
		context.out.Ln;
		(* DFA stats *)
		(*context.out.String(scanner.str^);
		context.out.Ln;
		PrintTree(context, tree, 0);
		nfa.Show(context);
		dfa.Show(context);
		context.out.Ln;*)

		(* Simulation with input string *)
		iInput := 0;
		WHILE (iInput < LEN(strInput^)) & (strInput^[iInput] # 0X) DO
			IF dfa.Simulate(strInput^, iInput, iNext) THEN
				WHILE iInput < iNext DO
					context.out.Char(strInput^[iInput]);
					INC(iInput)
				END;
				context.out.Ln
			ELSE
				INC(iInput)
			END
		END;

	END Test;

BEGIN

	strInput :=
		Strings.NewString("hi2424242caaabbvssaaasnbjdwee1gtabaacabb7ghab11111dabbvaabbaabbaaabbrtaaeabbf323232dgabbv");

END RegExpParse.

RegExpParse.Test ~

Result with old Containers.Mod:
Time for NFA:   7.549685E-004
Time for DFA:   1.293657E-002
Time for simulation:   4.507090E-004
Total time:   1.414224E-002
2424242caaabbv
11111dabbv
323232dgabbv

Time for NFA:   6.436874E-004
Time for DFA:   8.012703E-003
Time for simulation:   3.137857E-004
Total time:   8.970176E-003
2424242caaabbv
11111dabbv
323232dgabbv

SystemTools.Free RegExpParse PreciseTimer RegExpSubsetConstruct
	RegExpDFA RegExpMaps RegExpNFA Generics ~

