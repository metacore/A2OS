MODULE CSS2;	(** Stefan Walthert  *)
(** AUTHOR "swalthert"; PURPOSE ""; *)

IMPORT
	Strings, Objects := XMLObjects;

CONST
	Undefined* = 0;

TYPE
	String* = Strings.String;

	StyleSheet* = OBJECT
		VAR
			charSet: String;
			rulesets, pages, fontFaces: Objects.Collection;

		PROCEDURE & Init*;
		VAR arrColl: Objects.ArrayCollection;
		BEGIN
			NEW(arrColl); rulesets := arrColl;
			NEW(arrColl); pages := arrColl;
			NEW(arrColl); fontFaces := arrColl
		END Init;

		PROCEDURE GetCharSet*(): String;
		BEGIN
			RETURN charSet
		END GetCharSet;

		PROCEDURE SetCharSet*(VAR charSet: ARRAY OF CHAR);
		BEGIN
			SELF.charSet := NewString(charSet)
		END SetCharSet;

		PROCEDURE GetRuleSets*(): Objects.Enumerator;
		BEGIN
			RETURN rulesets.GetEnumerator()
		END GetRuleSets;

		PROCEDURE AddRuleSet*(rs: RuleSet);
		BEGIN
			rulesets.Add(rs)
		END AddRuleSet;

		PROCEDURE GetPages*(): Objects.Enumerator;
		BEGIN
			RETURN pages.GetEnumerator()
		END GetPages;

		PROCEDURE AddPage*(page: Page);
		BEGIN
			pages.Add(page)
		END AddPage;

		PROCEDURE GetFontFaces*(): Objects.Enumerator;
		BEGIN
			RETURN fontFaces.GetEnumerator()
		END GetFontFaces;

		PROCEDURE AddFontFace*(fontFace: FontFace);
		BEGIN
			fontFaces.Add(fontFace)
		END AddFontFace;

	END StyleSheet;

CONST
	(** RuleSet.media *)
	All* = 0; (**  *)
	Aural* = 1; (**  *)
	Braille* = 2; (**  *)
	Embossed* = 3; (**  *)
	Handheld* = 4; (**  *)
	Print* = 5; (**  *)
	Projection* = 6; (**  *)
	Screen* = 7; (**  *)
	TTY* = 8; (**  *)
	TV* = 9; (**  *)

TYPE
	RuleSet* = OBJECT
		VAR
			selectors, declarations: Objects.Collection;
			hasImportantDeclarations, hasNotImportantDeclarations: BOOLEAN;
			media: SET;

		PROCEDURE & Init*;
		VAR arrColl: Objects.ArrayCollection;
		BEGIN
			NEW(arrColl); selectors := arrColl;
			NEW(arrColl); declarations := arrColl;
			INCL(media, All);
			hasImportantDeclarations := FALSE; hasNotImportantDeclarations := FALSE
		END Init;

		PROCEDURE GetMedia*(): SET;
		BEGIN
			RETURN media
		END GetMedia;

		PROCEDURE IsMediumSupported*(medium: SIGNED8): BOOLEAN;
		BEGIN
			RETURN medium IN media
		END IsMediumSupported;

		PROCEDURE AddMedium*(medium: SIGNED8);
		BEGIN
			IF medium IN {All, Aural, Braille, Embossed, Handheld, Print, Projection, Screen, TTY, TV} THEN
				IF medium # All THEN EXCL(media, All) END;
				media := media + {medium}
			END
		END AddMedium;

		PROCEDURE SetMedia*(media: SET);
		BEGIN
			SELF.media := media
		END SetMedia;

		PROCEDURE GetSelectors*(): Objects.Enumerator;
		BEGIN
			RETURN selectors.GetEnumerator()
		END GetSelectors;

		PROCEDURE AddSelector*(selector: Selector);
		BEGIN
			selectors.Add(selector)
		END AddSelector;

		PROCEDURE GetDeclarations*(): Objects.Enumerator;
		BEGIN
			RETURN declarations.GetEnumerator();
		END GetDeclarations;

		PROCEDURE AddDeclaration*(declaration: Declaration);
		BEGIN
			IF declaration.IsImportant() THEN
				hasImportantDeclarations := TRUE
			ELSE
				hasNotImportantDeclarations := TRUE
			END;
			declarations.Add(declaration)
		END AddDeclaration;

		PROCEDURE HasImportantDeclarations*(): BOOLEAN;
		BEGIN
			RETURN hasImportantDeclarations
		END HasImportantDeclarations;

		PROCEDURE HasNotImportantDeclarations*(): BOOLEAN;
		BEGIN
			RETURN hasNotImportantDeclarations
		END HasNotImportantDeclarations;

	END RuleSet;

	Selector* = OBJECT
		VAR
			a, b, c: SIGNED32;
			simpleSelectors: Objects.Collection;
			lastSimpleSel: SimpleSelector;

		PROCEDURE & Init*;
		VAR arrColl: Objects.ArrayCollection;
		BEGIN
			a := 0; b := 0; c := 0;
			NEW(arrColl); simpleSelectors := arrColl
		END Init;

		PROCEDURE GetSpecifity*(VAR a, b, c: SIGNED32);
		BEGIN
			a := SELF.a; b := SELF.b; c := SELF.c
		END GetSpecifity;

		PROCEDURE GetSimpleSelectors*(): Objects.Enumerator;
		BEGIN
			RETURN simpleSelectors.GetEnumerator()
		END GetSimpleSelectors;

		PROCEDURE AddSimpleSelector*(simpleSelector: SimpleSelector);
		VAR s: String; enum: Objects.Enumerator; p: ANY;
		BEGIN
			s := simpleSelector.GetElementName();
			IF (s # NIL) & (s^ # "*") THEN INC(c) END;
			enum := simpleSelector.GetSubSelectors();
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS Id THEN
					INC(a)
				ELSE
					INC(b)
				END
			END;
			IF lastSimpleSel # NIL THEN lastSimpleSel.next := simpleSelector END;
			lastSimpleSel := simpleSelector;
			simpleSelectors.Add(simpleSelector)
		END AddSimpleSelector;

	END Selector;

CONST
	(** SimpleSelector.combinator *)
	Descendant* = 1;	(** ' ' *)
	Child* = 2;	(** '>' *)
	Sibling* = 3;	(** '+' *)

TYPE
	SimpleSelector* = OBJECT
		VAR
			next: SimpleSelector;
			combinator: SIGNED8;
			elementName: String;
			subSelectors: Objects.Collection;

		PROCEDURE & Init*;
		VAR arrColl: Objects.ArrayCollection;
		BEGIN
			combinator := Undefined;
			NEW(arrColl); subSelectors := arrColl
		END Init;

		PROCEDURE GetNext*(): SimpleSelector;
		BEGIN
			RETURN next
		END GetNext;

		PROCEDURE GetCombinator*(): SIGNED8;
		BEGIN
			RETURN combinator
		END GetCombinator;

		PROCEDURE SetCombinator*(combinator: SIGNED8);
		BEGIN
			IF combinator IN {Descendant, Child, Sibling} THEN
				SELF.combinator := combinator
			END
		END SetCombinator;

		PROCEDURE GetElementName*(): String;
		BEGIN
			RETURN elementName
		END GetElementName;

		PROCEDURE SetElementName*(VAR elementName: ARRAY OF CHAR);
		BEGIN
			SELF.elementName := NewString(elementName)
		END SetElementName;

		PROCEDURE GetSubSelectors*(): Objects.Enumerator;
		BEGIN
			RETURN subSelectors.GetEnumerator()
		END GetSubSelectors;

		PROCEDURE AddSubSelector*(subSelector: SubSelector);
		BEGIN
			subSelectors.Add(subSelector)
		END AddSubSelector;

	END SimpleSelector;

	SubSelector* = OBJECT
	END SubSelector;

	Id* = OBJECT (SubSelector)
		VAR value: String;

		PROCEDURE GetValue*(): String;
		BEGIN
			RETURN value
		END GetValue;

		PROCEDURE SetValue*(VAR value: ARRAY OF CHAR);
		BEGIN
			SELF.value := NewString(value)
		END SetValue;

	END Id;

	Class* = OBJECT (SubSelector)
		VAR value: String;

		PROCEDURE GetValue*(): String;
		BEGIN
			RETURN value
		END GetValue;

		PROCEDURE SetValue*(VAR value: ARRAY OF CHAR);
		BEGIN
			SELF.value := NewString(value)
		END SetValue;

	END Class;

CONST
	(** Attribute.relation *)
	Equal* = 1;	(** '=' *)
	Includes* = 2;	(** '~=' *)
	Dashmatch* = 3;	(** '|=' *)

TYPE
	Attribute* = OBJECT (SubSelector)
		VAR
			name, value: String;
			relation: SIGNED8;

		PROCEDURE & Init*;
		BEGIN
			relation := Undefined
		END Init;

		PROCEDURE GetName*(): String;
		BEGIN
			RETURN name
		END GetName;

		PROCEDURE SetName*(VAR name: ARRAY OF CHAR);
		BEGIN
			SELF.name := NewString(name)
		END SetName;

		PROCEDURE GetRelation*(): SIGNED8;
		BEGIN
			RETURN relation
		END GetRelation;

		PROCEDURE SetRelation*(relation: SIGNED8);
		BEGIN
			IF relation IN {Equal, Includes, Dashmatch} THEN
				SELF.relation := relation
			END
		END SetRelation;

		PROCEDURE GetValue*(): String;
		BEGIN
			RETURN value
		END GetValue;

		PROCEDURE SetValue*(VAR value: ARRAY OF CHAR);
		BEGIN
			SELF.value := NewString(value)
		END SetValue;

	END Attribute;

	Pseudo* = OBJECT (SubSelector)
		VAR
			isLanguage: BOOLEAN;
			type: String;

		PROCEDURE GetType*(): String;
		BEGIN
			IF ~isLanguage THEN RETURN type ELSE RETURN NIL END
		END GetType;

		PROCEDURE SetType*(VAR type: ARRAY OF CHAR);
		BEGIN
			SELF.type := NewString(type);
			isLanguage := FALSE
		END SetType;

		PROCEDURE GetLanguage*(): String;
		BEGIN
			IF isLanguage THEN RETURN type ELSE RETURN NIL END
		END GetLanguage;

		PROCEDURE IsLanguage*(): BOOLEAN;
		BEGIN
			RETURN isLanguage
		END IsLanguage;

		PROCEDURE SetLanguage*(VAR language: ARRAY OF CHAR);
		BEGIN
			type := NewString(language);
			SELF.isLanguage := TRUE
		END SetLanguage;

	END Pseudo;

	Declaration* = OBJECT
		VAR
			property: String;
			expr: Objects.Collection;
			important: BOOLEAN;

		PROCEDURE & Init*;
		VAR arrColl: Objects.ArrayCollection;
		BEGIN
			NEW(arrColl); expr := arrColl;
			important := FALSE
		END Init;

		PROCEDURE GetProperty*(): String;
		BEGIN
			RETURN property
		END GetProperty;

		PROCEDURE SetProperty*(VAR property: ARRAY OF CHAR);
		BEGIN
			SELF.property := NewString(property)
		END SetProperty;

		PROCEDURE GetTerms*(): Objects.Enumerator;
		BEGIN
			RETURN expr.GetEnumerator()
		END GetTerms;

		PROCEDURE AddTerm*(term: Term);
		BEGIN
			expr.Add(term)
		END AddTerm;

		PROCEDURE RemoveTerm*(term: Term);
		BEGIN
			expr.Remove(term)
		END RemoveTerm;

		PROCEDURE IsImportant*(): BOOLEAN;
		BEGIN
			RETURN important
		END IsImportant;

		PROCEDURE SetImportant*(important: BOOLEAN);
		BEGIN
			SELF.important := important
		END SetImportant;

	END Declaration;

CONST
	(** Term.operator *)
	Slash* = 1;
	Comma* = 2;

	(** Term.unaryOperator *)
	Minus* = -1;	(** '-' *)
	Plus* = 1;	(** '+' *)

	(** Term.type *)
	IntNumber* = 1;	(** [0-9]+ *)
	RealNumber* = 2;	(** [0-9]*'.'[0-9]+ *)
	Percent* = 3;	(** {real}'%' / 100, {integer}'%' / 100 *)
	IntDimension* = 4;	(** {integer}{unit} *)
	RealDimension* = 5;	(** {real}{unit} *)
	Function* = 6;	(** {ident}'('term')' *)
	StringVal* = 7;	(** '"'chars'"' | "'"chars"'" *)
	StringIdent* = 8;	(** chars *)
	URI* = 9;	(** 'url('{string}')' | 'url('url')' *)
	Color* = 10;	(** '#'RGB | '#'RRGGBB | 'rgb('{number}'% ,' {number}'% ,' {number}'%)'
			| 'rgb('{integer}',' {integer}',' {integer}'%)'	(without transparancy)
			or '#'ARGB | '#'AARRGGBB | 'rgba('{number}'% ,' {number}'% ,' {number}'% ,' {number}'%)'
			| 'rgba('{integer}',' {integer}',' {integer}'%,' {integer}'%)'	(with transparancy) (integer: 0 - 255) *)
	Ident* = 11;	(** Ident type: GetIntVal() *)
	UnicodeRange* = 12;	(**  *)

	(** Term.unit *)
	(** relative length units *)
	em* = 1;	(** the 'font-size' of the relevant font *)
	ex* = 2;	(** the 'x-height' of the relevant font *)
	px* = 3;	(** pixels, relative to the viewing device *)
	(** absolute length units *)
	in* = 4;	(** inches -- 1 inch is equal to 2.54 centimeters *)
	cm* = 5;	(** centimeters *)
	mm* = 6;	(** millimeters *)
	pt* = 7;	(** points -- the points used by CSS2 are equal to 1/72th of an inch *)
	pc* = 8;	(** picas -- 1 pica is equal to 12 points *)
	(** angle units *)
	deg* = 9;	(** degrees *)
	grad* = 10;	(** grads *)
	rad* = 11;	(** radians *)
	(** time units *)
	ms* = 12;	(** milliseconds *)
	s* = 13;	(** seconds *)
	(** frequency units *)
	Hz* = 14;	(** Hertz *)
	kHz* = 15;	(** kilo Hertz *)

TYPE
	Term* = OBJECT
		VAR
			operator, unaryOperator: SIGNED8;
			type: SIGNED8;
			intVal: SIGNED32;
			realVal: FLOAT64;
			stringVal: String;
			unit: SIGNED8;
			expr: Objects.Collection;	(* if term is a function *)

		PROCEDURE & Init*;
		BEGIN
			operator := Undefined; unaryOperator := Plus; type := Undefined; unit := Undefined;
			intVal := 0; realVal := 0.0
		END Init;

(*		PROCEDURE Copy*(VAR to: Term);
		VAR terms: Objects.Enumerator; p: ANY; t: Term;
		BEGIN
			IF to = NIL THEN NEW(to) END;
			to.operator := operator;
			to.unaryOperator := unaryOperator;
			to.type := type;
			to.intVal := intVal;
			to.realVal := realVal;
			IF stringVal # NIL THEN to.stringVal := NewString(stringVal) END;
			to.unit := unit;
			IF expr # NIL THEN
				NEW(to.expr);
				terms := GetTerms();
				WHILE terms.HasMoreElements() DO
					p := terms.GetNext();
					p(Term).Copy(t);
					to.AddTerm(t)
				END
			END
		END Copy;*)

		PROCEDURE GetOperator*(): SIGNED8;
		BEGIN
			RETURN operator
		END GetOperator;

		PROCEDURE SetOperator*(operator: SIGNED8);
		BEGIN
			IF (operator = Slash) OR (operator = Comma) THEN
				SELF.operator := operator
			END
		END SetOperator;

		PROCEDURE GetUnaryOperator*(): SIGNED8;
		BEGIN
			RETURN unaryOperator
		END GetUnaryOperator;

		PROCEDURE SetUnaryOperator*(unaryOperator: SIGNED8);
		BEGIN
			IF (unaryOperator = Minus) OR (unaryOperator = Plus) THEN
				SELF.unaryOperator := unaryOperator
			END
		END SetUnaryOperator;

		PROCEDURE GetType*(): SIGNED8;
		BEGIN
			RETURN type
		END GetType;

		PROCEDURE SetType*(type: SIGNED8);
		BEGIN
			CASE type OF
			| IntNumber, Color, Ident: realVal := 0.0; stringVal := NIL; unit := Undefined; expr := NIL
			| RealNumber: intVal := 0; stringVal := NIL; unit := Undefined; expr := NIL
			| Percent: realVal := 0.0; stringVal := NIL; unit := Undefined; expr := NIL
			| IntDimension: realVal := 0.0; stringVal := NIL; expr := NIL
			| RealDimension: intVal := 0; stringVal := NIL; expr := NIL
			| Function: intVal := 0; realVal := 0.0; unit := Undefined
			| StringVal, StringIdent, URI: intVal := 0; realVal := 0.0; unit := Undefined; expr := NIL
			| UnicodeRange: intVal := 0; realVal := 0.0; stringVal := NIL; unit := Undefined; expr := NIL
			ELSE RETURN
			END;
			SELF.type := type
		END SetType;

		PROCEDURE GetIntVal*(): SIGNED32;
		BEGIN
			RETURN intVal
		END GetIntVal;

		PROCEDURE SetIntVal*(intVal: SIGNED32);
		BEGIN
			SELF.intVal := intVal
		END SetIntVal;

		PROCEDURE GetRealVal*(): FLOAT64;
		BEGIN
			RETURN realVal
		END GetRealVal;

		PROCEDURE SetRealVal*(realVal: FLOAT64);
		BEGIN
			SELF.realVal := realVal
		END SetRealVal;

		PROCEDURE GetStringVal*(): String;
		BEGIN
			RETURN stringVal
		END GetStringVal;

		PROCEDURE SetStringVal*(VAR stringVal: ARRAY OF CHAR);
		BEGIN
			SELF.stringVal := NewString(stringVal)
		END SetStringVal;

		PROCEDURE IsStringIdent*(ident: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			RETURN (type = StringIdent) & (stringVal # NIL) & (stringVal^ = ident)
		END IsStringIdent;

		PROCEDURE IsIdent*(ident: SIGNED32): BOOLEAN;
		BEGIN
			RETURN (type = Ident) & (intVal = ident)
		END IsIdent;

		PROCEDURE GetUnit*(): SIGNED8;
		BEGIN
			RETURN unit
		END GetUnit;

		PROCEDURE SetUnit*(unit: SIGNED8);
		BEGIN
			IF unit IN {em, ex, px, in, cm, mm, pt, pc, deg, grad, rad, ms, s, Hz, kHz} THEN
				SELF.unit := unit
			END
		END SetUnit;

		PROCEDURE IsLength*(): BOOLEAN;
		BEGIN
			RETURN (type IN {IntDimension, RealDimension}) & (unit IN {em, ex, px, in, cm, mm, pt, pc})
		END IsLength;

		PROCEDURE IsAngle*(): BOOLEAN;
		BEGIN
			RETURN (type IN {IntDimension, RealDimension}) & (unit IN {deg, grad, rad})
		END IsAngle;

		PROCEDURE IsTime*(): BOOLEAN;
		BEGIN
			RETURN (type IN {IntDimension, RealDimension}) & (unit IN {ms, s})
		END IsTime;

		PROCEDURE IsFrequency*(): BOOLEAN;
		BEGIN
			RETURN (type IN {IntDimension, RealDimension}) & (unit IN {Hz, kHz})
		END IsFrequency;

		PROCEDURE GetColor*(VAR r, g, b, a: CHAR);
		BEGIN
			IntToRGBA(intVal, r, g, b, a)
		END GetColor;

		PROCEDURE SetColor*(r, g, b, a: CHAR);
		BEGIN
			RGBAToInt(r, g, b, a, intVal)
		END SetColor;

		PROCEDURE GetTerms*(): Objects.Enumerator;
		BEGIN
			RETURN expr.GetEnumerator()
		END GetTerms;

		PROCEDURE AddTerm*(term: Term);
		VAR arrColl: Objects.ArrayCollection;
		BEGIN
			IF expr = NIL THEN NEW(arrColl); expr := arrColl END;
			expr.Add(term)
		END AddTerm;

	END Term;

CONST
	(** Page.pseudoPage *)
	Left* = 1;	(** ':left' *)
	Right* = 2;	(** ':right' *)
	First* = 3;	(** ':first' *)

TYPE
	Page* = OBJECT
	VAR
		selector: String;
		pseudoPage: SIGNED8;
		declarations: Objects.Collection;

		PROCEDURE & Init*;
		VAR arrColl: Objects.ArrayCollection;
		BEGIN
			pseudoPage := Undefined;
			NEW(arrColl); declarations := arrColl
		END Init;

		PROCEDURE GetSelector*(): String;
		BEGIN
			RETURN selector
		END GetSelector;

		PROCEDURE SetSelector*(VAR selector: ARRAY OF CHAR);
		BEGIN
			SELF.selector := NewString(selector)
		END SetSelector;

		PROCEDURE GetPseudoPage*(): SIGNED8;
		BEGIN
			RETURN pseudoPage
		END GetPseudoPage;

		PROCEDURE SetPseudoPage*(pseudoPage: SIGNED8);
		BEGIN
			IF pseudoPage IN {Left, Right, First} THEN
				SELF.pseudoPage := pseudoPage
			END
		END SetPseudoPage;

		PROCEDURE GetDeclarations*(): Objects.Enumerator;
		BEGIN
			RETURN declarations.GetEnumerator()
		END GetDeclarations;

		PROCEDURE AddDeclaration*(declaration: Declaration);
		BEGIN
			declarations.Add(declaration)
		END AddDeclaration;

	END Page;

	FontFace* = OBJECT
		VAR declarations: Objects.Collection;

		PROCEDURE & Init*;
		VAR arrColl: Objects.ArrayCollection;
		BEGIN
			NEW(arrColl); declarations := arrColl
		END Init;

		PROCEDURE GetDeclarations*(): Objects.Enumerator;
		BEGIN
			RETURN declarations.GetEnumerator()
		END GetDeclarations;

		PROCEDURE AddDeclaration*(declaration: Declaration);
		BEGIN
			declarations.Add(declaration)
		END AddDeclaration;

	END FontFace;

	PROCEDURE IntToRGBA*(color: SIGNED32; VAR r, g, b, a: CHAR);
	BEGIN
			a := CHR(color DIV 1000000H);
			r := CHR(color DIV 10000H MOD 100H);
			g := CHR(color DIV 100H MOD 100H);
			b := CHR(color MOD 100H)
	END IntToRGBA;

	PROCEDURE RGBAToInt*(r, g, b, a: CHAR; VAR color: SIGNED32);
	BEGIN
		color := ASH(ORD(a), 24) + ASH(ORD(r), 16) + ASH(ORD(g), 8) + ORD(b)
	END RGBAToInt;

	PROCEDURE NewString(VAR value: ARRAY OF CHAR): String;
	VAR s: String;
	BEGIN
		NEW(s, Strings.Length(value) + 1);
		COPY(value, s^);
		RETURN s
	END NewString;

END CSS2.