MODULE XMLStyle;	(** Stefan Walthert  *)
(** AUTHOR "swalthert"; PURPOSE ""; *)

IMPORT
	XMLObjects, CSS2, XML, XMLComponents;

TYPE
	String= CSS2.String;

	SelectorRuleSet = RECORD
		selector: CSS2.Selector;
		ruleSet: CSS2.RuleSet;
		order: SIZE
	END;

PROCEDURE AttachStyle*(root: XML.Element; css: CSS2.StyleSheet);
VAR selRS: POINTER TO ARRAY OF SelectorRuleSet; noSel: SIZE;
	ruleSets, selectors, simpleSelectors: XMLObjects.Enumerator; ruleSet, selector, simpleSelector: ANY;
	propChanger: XMLComponents.PropertyChanger; hasDynamic: BOOLEAN;
BEGIN
	IF (root = NIL) OR (css = NIL) THEN RETURN END;
	noSel := 0;
	(* compute number of rule sets in style sheet *)
	ruleSets := css.GetRuleSets();
	WHILE ruleSets.HasMoreElements() DO
		ruleSet := ruleSets.GetNext();
		selectors := ruleSet(CSS2.RuleSet).GetSelectors();
		WHILE selectors.HasMoreElements() DO
			selector := selectors.GetNext();
			INC(noSel)
		END
	END;
	NEW(selRS, noSel);
	(* store rule sets of style sheet in array *)
	noSel := 0;
	ruleSets := css.GetRuleSets();
	WHILE ruleSets.HasMoreElements() DO
		ruleSet := ruleSets.GetNext();
		selectors := ruleSet(CSS2.RuleSet).GetSelectors();
		WHILE selectors.HasMoreElements() DO
			selector := selectors.GetNext();
			selRS[noSel].selector := selector(CSS2.Selector);
			selRS[noSel].ruleSet := ruleSet(CSS2.RuleSet);
			selRS[noSel].order := noSel;
			INC(noSel)
		END
	END;
	(* sort selRS  by specifity of selectors (selRS[].selector.GetSpecifity(a, b, c)) and their original order *)
	HeapSort(selRS^);
	(* attach style of unimportant declarations *)
	FOR noSel := 0 TO LEN(selRS) - 1 DO
		IF selRS[noSel].ruleSet.HasNotImportantDeclarations() THEN
			simpleSelectors := selRS[noSel].selector.GetSimpleSelectors();
			IF simpleSelectors.HasMoreElements() THEN
				simpleSelector := simpleSelectors.GetNext(); NEW(propChanger); hasDynamic := FALSE;
				FindMatch(root, simpleSelector(CSS2.SimpleSelector), selRS[noSel].ruleSet,
					propChanger, hasDynamic, FALSE)
			END
		END
	END;
	(* attach style of important declarations *)
	FOR noSel := 0 TO LEN(selRS) - 1 DO
		IF selRS[noSel].ruleSet.HasImportantDeclarations() THEN
			simpleSelectors := selRS[noSel].selector.GetSimpleSelectors();
			IF simpleSelectors.HasMoreElements() THEN
				simpleSelector := simpleSelectors.GetNext(); NEW(propChanger); hasDynamic := FALSE;
				FindMatch(root, simpleSelector(CSS2.SimpleSelector), selRS[noSel].ruleSet,
					propChanger, hasDynamic, TRUE)
			END
		END
	END
END AttachStyle;

PROCEDURE HeapSort(VAR selRS: ARRAY OF SelectorRuleSet);
VAR left, right: SIZE; elem: SelectorRuleSet;

	PROCEDURE Sift(left, right: SIZE);
	VAR i, j: SIZE; elem: SelectorRuleSet;

		PROCEDURE Less(VAR elem1, elem2: SelectorRuleSet): BOOLEAN;
		VAR a1, a2, b1, b2, c1, c2: LONGINT;
		BEGIN
			elem1.selector.GetSpecifity(a1, b1, c1); elem2.selector.GetSpecifity(a2, b2, c2);
			RETURN (a1 < a2) OR ((a1 = a2) & (b1 < b2)) OR ((a1 = a2) & (b1 = b2) & (c1 < c2))
					OR ((a1 = a2) & (b1 = b2) & (c1 = c2) & (elem1.order < elem2.order))
		END Less;

	BEGIN
		i := left; j := 2 * left; elem := selRS[left];
		IF (j < right) & Less(selRS[j], selRS[j + 1]) THEN INC(j) END;
		WHILE (j <= right) & Less(elem, selRS[j]) DO
			selRS[i] := selRS[j]; i := j; j := 2 * j;
			IF (j < right) & Less(selRS[j], selRS[j + 1]) THEN INC(j) END;
		END;
		selRS[i] := elem
	END Sift;

BEGIN
	left := LEN(selRS) DIV 2 + 1; right := LEN(selRS) - 1;
	WHILE left > 0 DO DEC(left); Sift(left, right) END;
	WHILE right > 0 DO
		elem := selRS[0]; selRS[0] := selRS[right]; selRS[right] := elem;
		DEC(right); Sift(left, right)
	END
END HeapSort;

PROCEDURE FindMatch(elem: XML.Element; simpleSelector: CSS2.SimpleSelector; ruleSet: CSS2.RuleSet;
		propChanger: XMLComponents.PropertyChanger; VAR hasDynamic: BOOLEAN; important: BOOLEAN);
VAR children: XMLObjects.Enumerator; child: ANY; nextSimpleSelector: CSS2.SimpleSelector; sibling: XML.Element;
	match: BOOLEAN;
BEGIN
	nextSimpleSelector := simpleSelector.GetNext();
	match := MatchSimpleSelector(elem, simpleSelector, propChanger, hasDynamic);
	IF (nextSimpleSelector = NIL) & match & (elem IS XMLComponents.CSS2Component) THEN
		IF hasDynamic THEN propChanger.SetChangingComponent(elem(XMLComponents.CSS2Component), ruleSet)
		ELSE AttachStyleToComponent(elem(XMLComponents.CSS2Component), ruleSet, important)
		END
	END;
	IF (nextSimpleSelector # NIL) & match THEN
		CASE nextSimpleSelector.GetCombinator() OF
		| CSS2.Sibling:
			sibling := elem.GetNextSibling();
			IF sibling # NIL THEN
				FindMatch(sibling, nextSimpleSelector, ruleSet, propChanger.Copy(), hasDynamic, important)
			END
		| CSS2.Child, CSS2.Descendant:
			children := elem.GetContents();
			IF SelectFirstChild(nextSimpleSelector) THEN
				child := children.GetNext();
				IF (child # NIL) & (child IS XML.Element) THEN
					FindMatch(child(XML.Element), nextSimpleSelector, ruleSet, propChanger.Copy(), hasDynamic, important)
				END
			ELSE
				WHILE children.HasMoreElements() DO
					child := children.GetNext();
					IF child IS XML.Element THEN
						FindMatch(child(XML.Element), nextSimpleSelector, ruleSet, propChanger.Copy(), hasDynamic, important)
					END
				END
			END
		ELSE
		END
	END;
	IF simpleSelector.GetCombinator() = CSS2.Descendant THEN
		children := elem.GetContents();
		WHILE children.HasMoreElements() DO
			child := children.GetNext();
			IF child IS XML.Element THEN
				FindMatch(child(XML.Element), simpleSelector, ruleSet, propChanger.Copy(), hasDynamic, important)
			END
		END
	END
END FindMatch;

PROCEDURE MatchSimpleSelector(elem: XML.Element; simpleSelector: CSS2.SimpleSelector;
		propChanger: XMLComponents.PropertyChanger; VAR hasDynamic: BOOLEAN): BOOLEAN;
VAR s1, s2: String; enum: XMLObjects.Enumerator; c: ANY; match: BOOLEAN;
BEGIN
	s1 := elem.GetName();
	s2 := simpleSelector.GetElementName();
	IF (s2 = NIL) OR (s2^ = "*") OR (s1^ = s2^) THEN
		enum := simpleSelector.GetSubSelectors();
		match := TRUE;
		WHILE enum.HasMoreElements() & match DO
			c := enum.GetNext();
			match := MatchSubSelector(elem, c(CSS2.SubSelector), propChanger, hasDynamic)
		END;
		RETURN match
	ELSE RETURN FALSE
	END
END MatchSimpleSelector;

PROCEDURE MatchSubSelector(elem: XML.Element; subSelector: CSS2.SubSelector;
		propChanger: XMLComponents.PropertyChanger; VAR hasDynamic: BOOLEAN): BOOLEAN;
VAR s1, s2: String; rel: SHORTINT; attribute: XML.Attribute;
BEGIN
	IF subSelector IS CSS2.Id THEN
		s1 := elem.GetId(); s2 := subSelector(CSS2.Id).GetValue();
		RETURN (s1 # NIL) & (s2 # NIL) & (s1^ = s2^)
	ELSIF subSelector IS CSS2.Class THEN
		WITH subSelector: CSS2.Class DO
			attribute := elem.GetAttribute("class");
			IF attribute # NIL THEN
				s1 := attribute.GetValue();
				s2 := subSelector.GetValue();
				RETURN s1^ = s2^
			ELSE
				RETURN FALSE
			END
		END
	ELSIF subSelector IS CSS2.Attribute THEN
		WITH subSelector: CSS2.Attribute DO
			s1 := subSelector.GetName();
			rel := subSelector.GetRelation();
			attribute := elem.GetAttribute(s1^);
			IF attribute # NIL THEN
				IF rel = CSS2.Undefined THEN
					RETURN TRUE
				ELSE
					s1 := attribute.GetValue();
					s2 := subSelector.GetValue();
					IF rel = CSS2.Equal THEN
						RETURN s1^ = s2^
					ELSIF rel = CSS2.Includes THEN	(* not implemented *)
						RETURN FALSE
					ELSIF rel = CSS2.Dashmatch THEN	(* not implemented *)
						RETURN FALSE
					END
				END
			ELSE
				RETURN FALSE
			END
		END
	ELSIF subSelector IS CSS2.Pseudo THEN
		s1 := subSelector(CSS2.Pseudo).GetType();
		IF s1 = NIL THEN
			RETURN FALSE
		ELSIF s1^ = "first-child" THEN
			RETURN TRUE
		ELSE
			IF elem IS XMLComponents.VisualComponent THEN
				hasDynamic := TRUE;
				propChanger.AddListenedComponent(elem(XMLComponents.CSS2Component), s1^);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END
	ELSE
	END
END MatchSubSelector;

PROCEDURE AttachStyleToComponent(comp: XMLComponents.CSS2Component; ruleSet: CSS2.RuleSet; important: BOOLEAN);
VAR declarations: XMLObjects.Enumerator; declaration: ANY;
BEGIN
	declarations := ruleSet.GetDeclarations();
	WHILE declarations.HasMoreElements() DO
		declaration := declarations.GetNext();
		IF declaration(CSS2.Declaration).IsImportant() = important THEN
			comp.properties.SetValue(declaration(CSS2.Declaration))
		END
	END
END AttachStyleToComponent;

PROCEDURE SelectFirstChild(simpleSelector: CSS2.SimpleSelector): BOOLEAN;
VAR subSelectors: XMLObjects.Enumerator; c: ANY; s: String;
BEGIN
	subSelectors := simpleSelector.GetSubSelectors();
	WHILE subSelectors.HasMoreElements() DO
		c := subSelectors.GetNext();
		IF (c IS CSS2.Pseudo) THEN
			s := c(CSS2.Pseudo).GetType();
			IF (s # NIL) & (s^ = "first-child") THEN RETURN TRUE END
		END
	END;
	RETURN FALSE
END SelectFirstChild;

END XMLStyle.
