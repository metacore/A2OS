MODULE XMLComponents;	(** Stefan Walthert  *)
(** AUTHOR "swalthert"; PURPOSE ""; *)

IMPORT
	Files, DynamicStrings, XMLObjects, XML, CSS2, CSS2Properties, CSS2Scanner, CSS2Parser,
	WMWindowManager, Gfx;

TYPE
	String* = XML.String;

(*	Message* = OBJECT END Message;*)

	StateMessage* = OBJECT (*Message*)
		VAR state-: BOOLEAN;

		PROCEDURE & InitStateMessage*(state: BOOLEAN);
		BEGIN
			SELF.state := state
		END InitStateMessage;

	END StateMessage;

	ValueMessage* = OBJECT (*Message*)
		VAR value*: LONGINT;
	END ValueMessage;

	MouseMessage* = OBJECT (*Message*)
		VAR
			x*, y*: LONGINT;
			keys*: SET
	END MouseMessage;

	KeyMessage* = OBJECT (*Message*)
		VAR
			ch*: CHAR;
			keySym*: LONGINT;
			flags*: SET
	END KeyMessage;

	Listener* = PROCEDURE {DELEGATE} (sender, data: ANY);

VAR
	Unassigned: Listener;

TYPE
	ListenerEntry = OBJECT
		VAR
			listener: Listener
	END ListenerEntry;

	EventDispatcher* = OBJECT
		VAR
			listeners: XMLObjects.Collection;
			sender: ANY;

		PROCEDURE & Init*(sender: ANY);
		VAR arrColl: XMLObjects.ArrayCollection;
		BEGIN
			NEW(arrColl); listeners := arrColl;
			SELF.sender := sender
		END Init;

		PROCEDURE AddListener*(listener: Listener);
		VAR entry: ListenerEntry;
		BEGIN
			NEW(entry);
			entry.listener := listener;
			listeners.Add(entry)
		END AddListener;

		PROCEDURE Dispatch*(data: ANY);
		VAR entries: XMLObjects.Enumerator; entry: ANY;
		BEGIN
			IF listeners.GetNumberOfElements() > 0 THEN
				entries := listeners.GetEnumerator();
				WHILE entries.HasMoreElements() DO
					entry := entries.GetNext();
					entry(ListenerEntry).listener(sender, data)
				END
			END
		END Dispatch;

	END EventDispatcher;

	PropChangerEntry = OBJECT
		VAR
			listenedComponent: CSS2Component;
			event: String;
			state: BOOLEAN
	END PropChangerEntry;

	PropertyChanger* = OBJECT
		VAR
			entries: XMLObjects.Collection;
			changingComponent: CSS2Component;
			changingProperties: CSS2.RuleSet;
			oldState: BOOLEAN;

		PROCEDURE & Init*;
		VAR arrColl: XMLObjects.ArrayCollection;
		BEGIN
			NEW(arrColl); entries := arrColl; NEW(arrColl);
			oldState := FALSE
		END Init;

		PROCEDURE Copy*(): PropertyChanger;
		VAR newPropChanger: PropertyChanger; enum: XMLObjects.Enumerator;
		BEGIN
			NEW(newPropChanger);
			enum := entries.GetEnumerator();
			WHILE enum.HasMoreElements() DO
				newPropChanger.entries.Add(enum.GetNext());
			END;
			newPropChanger.changingComponent := changingComponent;
			newPropChanger.changingProperties := changingProperties;
			newPropChanger.oldState := oldState;
			RETURN newPropChanger
		END Copy;

		PROCEDURE AddListenedComponent*(comp: CSS2Component; VAR event: ARRAY OF CHAR);
		VAR newPropChangerEntry: PropChangerEntry;
		BEGIN
			NEW(newPropChangerEntry);
			newPropChangerEntry.listenedComponent := comp;
			newPropChangerEntry.event := NewString(event);
			newPropChangerEntry.state := FALSE;
			entries.Add(newPropChangerEntry)
		END AddListenedComponent;

		PROCEDURE SetChangingComponent*(comp: CSS2Component; ruleSet: CSS2.RuleSet);
		VAR enum: XMLObjects.Enumerator; entry: ANY;
		BEGIN
			changingComponent := comp;
			changingProperties := ruleSet;
			enum := entries.GetEnumerator();
			WHILE enum.HasMoreElements() DO
				entry := enum.GetNext();
				entry(PropChangerEntry).listenedComponent.AddEventListener(StatusChanged, entry(PropChangerEntry).event^)
			END
		END SetChangingComponent;

		PROCEDURE StatusChanged(sender, data: ANY);
		VAR enum: XMLObjects.Enumerator; entry: ANY; found: BOOLEAN;
		BEGIN
			IF (sender # NIL) & (sender IS CSS2Component) & (data # NIL) & (data IS StateMessage) THEN
				enum := entries.GetEnumerator(); found := FALSE;
				WHILE enum.HasMoreElements() & ~found DO
					entry := enum.GetNext();
					found := entry(PropChangerEntry).listenedComponent = sender
				END;
				IF found & (entry(PropChangerEntry).state # data(StateMessage).state) THEN
					entry(PropChangerEntry).state := data(StateMessage).state;
					IF AllStatesSet() # oldState THEN ChangeProperties() END
				END
			END
		END StatusChanged;

		PROCEDURE AllStatesSet(): BOOLEAN;
		VAR enum: XMLObjects.Enumerator; propChangerEntry: ANY; state: BOOLEAN;
		BEGIN
			enum := entries.GetEnumerator(); state := TRUE;
			WHILE enum.HasMoreElements() & state DO
				propChangerEntry := enum.GetNext();
				state := propChangerEntry(PropChangerEntry).state
			END;
			RETURN state
		END AllStatesSet;

		PROCEDURE ChangeProperties;
		VAR declarations: XMLObjects.Enumerator; declaration: ANY; s: String; oldRuleSet: CSS2.RuleSet;
		BEGIN
			NEW(oldRuleSet);
			declarations := changingProperties.GetDeclarations();
			WHILE declarations.HasMoreElements() DO
				declaration := declarations.GetNext();
				s := declaration(CSS2.Declaration).GetProperty();
				oldRuleSet.AddDeclaration(changingComponent.properties.GetValue(s^));
				changingComponent.properties.SetValue(declaration(CSS2.Declaration))
			END;
			changingProperties := oldRuleSet;
			oldState := ~oldState;
			changingComponent.PropertiesChanged();
			changingComponent.Invalidate()
		END ChangeProperties;

	END PropertyChanger;

	Component* = OBJECT (XML.Element)
		VAR
			locks: LONGINT;

		PROCEDURE AddAttribute*(attribute: XML.Attribute);
		BEGIN
			ConnectAttribute(attribute);
			AddAttribute^(attribute)
		END AddAttribute;

		PROCEDURE LockUpdate*;
		BEGIN
			INC(locks)
		END LockUpdate;

		PROCEDURE UnlockUpdate*;
		BEGIN
			IF locks > 0 THEN DEC(locks) END
		END UnlockUpdate;

		PROCEDURE IsLocked*(): BOOLEAN;
		BEGIN
			RETURN locks > 0
		END IsLocked;

		PROCEDURE GetNumberOfEvents*(): LONGINT;
		BEGIN
			RETURN 0
		END GetNumberOfEvents;

		PROCEDURE GetEventName*(i: LONGINT): String;
		BEGIN
			RETURN NIL
		END GetEventName;

		PROCEDURE AddEventListener*(listener: Listener; event: ARRAY OF CHAR);
		END AddEventListener;

		PROCEDURE GetNumberOfListeners*(): LONGINT;
		BEGIN
			RETURN 0
		END GetNumberOfListeners;

		PROCEDURE GetListenerName*(i: LONGINT): String;
		BEGIN
			RETURN NIL
		END GetListenerName;

		PROCEDURE GetListener*(name: ARRAY OF CHAR): Listener;
		BEGIN
			RETURN Unassigned
		END GetListener;

		PROCEDURE Connect*;
		VAR enum: XMLObjects.Enumerator; p: ANY;
		BEGIN
			enum := GetAttributes();
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				ConnectAttribute(p(XML.Attribute))
			END;
			IF GetNumberOfContents() > 0 THEN
				enum := GetContents();
				WHILE enum.HasMoreElements() DO
					p := enum.GetNext();
					IF p IS Component THEN p(Component).Connect() END
				END
			END
		END Connect;

		PROCEDURE Finalize*;
		VAR contents: XMLObjects.Enumerator; c: ANY;
		BEGIN
			contents := GetContents();
			WHILE contents.HasMoreElements() DO
				c := contents.GetNext();
				IF c IS Component THEN c(Component).Finalize() END
			END
		END Finalize;

		PROCEDURE ConnectAttribute(attribute: XML.Attribute);
		VAR listener: Listener; s1, event: String;
		BEGIN
			s1 := attribute.GetName();
			IF s1 # NIL THEN
				listener := GetListener(s1^);
				IF listener # Unassigned THEN
					s1 := attribute.GetValue();
					event := ExtractEvent(s1^);
					RegisterListener(listener, event^, s1^, 0, DynamicStrings.StringLength(s1^))
				END
			END;
		END ConnectAttribute;

		PROCEDURE RegisterListener(listener: Listener; VAR event, path: ARRAY OF CHAR; offset, len: LONGINT);
		VAR elem: XML.Element; retComp: Component; s1, s2: String; i: LONGINT;
			contents: XMLObjects.Enumerator; content: ANY; quoteChar: CHAR; attr: XML.Attribute;

			PROCEDURE SkipWhiteSpace;
			BEGIN
				WHILE (offset < len) & ((path[offset] = 20X) OR (path[offset] = 9X)) DO INC(offset) END
			END SkipWhiteSpace;

		BEGIN
			SkipWhiteSpace();
			IF offset < len THEN
				CASE path[offset] OF
				| ':': AddEventListener(listener, event)
				| '/':
					IF offset = 0 THEN
						elem := GetRoot();
						IF elem IS Component THEN elem(Component).RegisterListener(listener, event, path, offset + 1, len) END
					ELSE
						contents := GetContents();
						WHILE (contents.HasMoreElements()) & (retComp = NIL) DO
							content := contents.GetNext();
							IF content IS Component THEN content(Component).RegisterListener(listener, event, path, offset + 1, len) END
						END
					END
				| '.':
					IF (offset + 1 < len) & (path[offset + 1] = '/') THEN
						RegisterListener(listener, event, path, offset + 1, len)
					ELSIF (offset + 2 < len) & (path[offset + 1] = '.') & (path[offset + 2] = '/') THEN
						elem := GetParent();
						IF (elem # NIL) & (elem IS Component) THEN
							elem(Component).RegisterListener(listener, event, path, offset + 2, len)
						END
					END
				| '[':
					INC(offset); SkipWhiteSpace(); NEW(s1, len - offset + 2); i := 0;
					WHILE (i < len - offset) & (path[offset + i] # '=') DO
						s1[i] := path[offset + i]; INC(i)
					END;
					s1[i + 1] := 0X; INC(offset, i + 1); SkipWhiteSpace();
					attr := GetAttribute(s1^);
					IF attr # NIL THEN
						quoteChar := path[offset]; INC(offset);
						IF (quoteChar = "'") OR (quoteChar = '"') THEN
							NEW(s1, len - offset + 2); i := 0;
							WHILE (i < len - offset) & (path[offset + i] # quoteChar) DO
								s1[i] := path[offset + i]; INC(i)
							END;
							s1[i + 1] := 0X; INC(offset, i);
							s2 := attr.GetValue();
							IF (s1^ = s2^) & (offset + 1 < len) & (path[offset + 1] = ']') THEN
								RegisterListener(listener, event, path, offset + 2, len)
							END
						END
					END
				| '#':
					INC(offset); NEW(s1, len - offset + 2); i := 0;
					WHILE (i < len - offset) & (path[offset + i] # '/') & (path[offset + 1] # '.') & (path[offset + 1] # '[')
							& (path[offset + 1] # '#') DO
						s1[i] := path[offset + i]; INC(i)
					END;
					s1[i + 1] := 0X; INC(offset, i);
					s2 := GetId();
					IF (s2 # NIL) & (s1^ = s2^) THEN RegisterListener(listener, event, path, offset, len) END
				| '*':
					IF offset + 1 < len THEN RegisterListener(listener, event, path, offset + 1, len) END
				ELSE
					NEW(s1, len - offset + 2); i := 0;
					WHILE (i < len - offset) & (path[offset + i] # '/') & (path[offset + i] # '.') & (path[offset + i] # '[')
							& (path[offset + i] # '#') & (path[offset + i] # ':')DO
						s1[i] := path[offset + i]; INC(i)
					END;
					s1[i + 1] := 0X; INC(offset, i);
					s2 := GetName();
					IF s1^ = s2^ THEN RegisterListener(listener, event, path, offset, len) END
				END
			ELSE
				AddEventListener(listener, event)
			END
		END RegisterListener;

	END Component;

	CSS2Component* = OBJECT (Component)
		VAR
			properties-: CSS2Properties.AllMediaProperties;

		PROCEDURE &Init*;
		BEGIN
			Init^();
			NEW(properties);
		END Init;

		PROCEDURE AddContent*(c: XML.Content);
		BEGIN
			IF c IS CSS2Component THEN c(CSS2Component).properties.SetParent(properties) END;
			AddContent^(c)
		END AddContent;

		PROCEDURE GetProperties*(): CSS2Properties.AllMediaProperties;
		BEGIN
			RETURN properties
		END GetProperties;

		PROCEDURE SetProperties*(p: CSS2Properties.AllMediaProperties);
		BEGIN
			properties := p
		END SetProperties;

		PROCEDURE SetProperty*(name, value: ARRAY OF CHAR);
		VAR ruleSet: CSS2.RuleSet; declarations: XMLObjects.Enumerator; declaration: ANY;
		BEGIN
			ruleSet := GenerateRuleSet(name, value);
			IF ruleSet # NIL THEN
				declarations := ruleSet.GetDeclarations();
				IF declarations.HasMoreElements() THEN
					declaration := declarations.GetNext();
					properties.SetValue(declaration(CSS2.Declaration))
				END
			END
		END SetProperty;

		PROCEDURE SetPropertyOnEvent*(name, value, event: ARRAY OF CHAR);
		VAR ruleSet: CSS2.RuleSet; propertyChanger: PropertyChanger;
		BEGIN
			ruleSet := GenerateRuleSet(name, value);
			IF ruleSet # NIL THEN
				NEW(propertyChanger);
				propertyChanger.AddListenedComponent(SELF, event);
				propertyChanger.SetChangingComponent(SELF, ruleSet)
			END
		END SetPropertyOnEvent;

		PROCEDURE GenerateRuleSet(name, value: ARRAY OF CHAR): CSS2.RuleSet;
		VAR scanner: CSS2Scanner.Scanner; parser: CSS2Parser.Parser; file: Files.File; w: Files.Writer;
			styleSheet: CSS2.StyleSheet; ruleSets: XMLObjects.Enumerator; ruleSet: ANY;
		BEGIN
			file := Files.New("");
			Files.OpenWriter(w, file, 0);
			w.Char('{');
			w.Bytes(name, 0, DynamicStrings.StringLength(name));
			w.Char(':');
			w.Bytes(value, 0, DynamicStrings.StringLength(value));
			w.Char('}');
			w.Update;
			NEW(scanner, file); NEW(parser, scanner); parser.reportError := NoReportError;
			styleSheet := parser.Parse();
			ruleSets := styleSheet.GetRuleSets();
			IF ruleSets.HasMoreElements() THEN ruleSet := ruleSets.GetNext(); RETURN ruleSet(CSS2.RuleSet)
			ELSE RETURN NIL
			END
		END GenerateRuleSet;

		PROCEDURE PropertiesChanged*;
		VAR contents: XMLObjects.Enumerator; c: ANY;
		BEGIN
			properties.ComputeValues();
			IF GetNumberOfContents() > 0 THEN
				contents := GetContents();
				WHILE contents.HasMoreElements() DO
					c := contents.GetNext();
					IF c IS CSS2Component THEN c(CSS2Component).PropertiesChanged() END
				END
			END
		END PropertiesChanged;

		PROCEDURE Invalidate*;
		END Invalidate;

	END CSS2Component;

	Box* = OBJECT
		VAR
			x*, y*, w*, h*: LONGINT;

		PROCEDURE InBox*(x, y: LONGINT): BOOLEAN;
		BEGIN
			RETURN (SELF.x <= x) & (x < SELF.x + w) & (SELF.y <= y) & (y < SELF.y + h)
		END InBox;

		PROCEDURE IsEmpty*(): BOOLEAN;
		BEGIN
			RETURN (w = 0) OR (h = 0)
		END IsEmpty;

		PROCEDURE SetBox*(box: Box);
		BEGIN
			x := box.x; y := box.y; w := box.w; h := box.h
		END SetBox;

		PROCEDURE SetRect*(x, y, w, h: LONGINT);
		BEGIN
			SELF.x := x; SELF.y := y; SELF.w := w; SELF.h := h
		END SetRect;

		PROCEDURE Intersect*(box: Box): BOOLEAN;
		BEGIN
			RETURN (x < box.x + box.w) & (box.x < x + w) & (y < box.y + box.h) & (box.y < y + h)
		END Intersect;

		PROCEDURE IntersectRect*(x, y, w, h: LONGINT): BOOLEAN;
		BEGIN
			RETURN (SELF.x < x + w) & (x < SELF.x + SELF.w) & (SELF.y < y + h) & (y < SELF.y + SELF.h)
		END IntersectRect;

		PROCEDURE Clip*(box: Box);
		BEGIN
			ClipRect(box.x, box.y, box.w, box.h)
		END Clip;

		PROCEDURE ClipRect*(x, y, w, h: LONGINT);
		VAR ur: LONGINT;
		BEGIN
			ur := MIN(SELF.x + SELF.w, x + w); SELF.x := MAX(SELF.x, x); SELF.w := MAX(0, ur - SELF.x);
			ur := MIN(SELF.y + SELF.h, y + h); SELF.y := MAX(SELF.y, y); SELF.h := MAX(0, ur - SELF.y)
		END ClipRect;

		PROCEDURE Extend*(box: Box);
		BEGIN
			ExtendRect(box.x, box.y, box.w, box.h)
		END Extend;

		PROCEDURE ExtendRect*(x, y, w, h: LONGINT);
		VAR ur: LONGINT;
		BEGIN
			ur := MAX(SELF.x + SELF.w, x + w); SELF.x := MIN(SELF.x, x); SELF.w := ur - SELF.x;
			ur := MAX(SELF.y + SELF.h, y + h); SELF.y := MIN(SELF.y, y); SELF.h := ur - SELF.y
		END ExtendRect;

	END Box;

	VisualComponent* = OBJECT (CSS2Component)
		VAR
			pointerMoveListeners, hoverListeners, activeListeners, focusListeners: EventDispatcher;
			bounds, borderBox, paddingBox, contentBox, invalidBox: Box;
			inlineBoxes, textBoxes: XMLObjects.Collection;
			pointerOwner, focusOwner: VisualComponent;
			isHovered*, hasFocus*, isActive*, isLink*, isVisited*, dragable*: BOOLEAN;
			lastMouseKeys-: SET;
			lastX-, lastY-: LONGINT;
			trueStateMsg, falseStateMsg: StateMessage;

		PROCEDURE &Init*;
		VAR vprop: CSS2Properties.VisualProperties; arrColl: XMLObjects.ArrayCollection;
		BEGIN
			Init^();
			NEW(vprop);
			properties := vprop;
			NEW(bounds); bounds.x := 0; bounds.y := 0; bounds.w := 0; bounds.h := 0;
			NEW(borderBox); NEW(paddingBox); NEW(contentBox); NEW(invalidBox);
			NEW(arrColl); textBoxes := arrColl;
			NEW(arrColl); inlineBoxes := arrColl;
			pointerOwner := SELF;
			NEW(trueStateMsg, TRUE); NEW(falseStateMsg, FALSE);
			NEW(pointerMoveListeners, SELF); NEW(hoverListeners, SELF); NEW(activeListeners, SELF); NEW(focusListeners, SELF)
		END Init;

		PROCEDURE AddContent*(c: XML.Content);
		BEGIN
			IF c IS CSS2Component THEN
				c(VisualComponent).properties.SetParent(properties);
			END;
			AddContent^(c)
		END AddContent;

		PROCEDURE SetProperties*(p: CSS2Properties.AllMediaProperties);
		BEGIN
			IF (p # NIL) & (p IS CSS2Properties.VisualProperties) THEN
				SetProperties^(p)
			END
		END SetProperties;

		PROCEDURE GetBounds*(): Box;
		VAR box: Box;
		BEGIN
			NEW(box); box.x := GetX(); box.y := GetY(); box.w := GetWidth(); box.h := GetHeight(); RETURN box
		END GetBounds;

		PROCEDURE SetBounds*(bounds: Box);
		BEGIN
			IF bounds # NIL THEN SELF.bounds.SetBox(bounds) END
		END SetBounds;

(*		PROCEDURE GetSize*(VAR w, h: LONGINT);
		BEGIN
			w := GetWidth(); h := GetHeight()
		END GetSize;

		PROCEDURE SetSize*(w, h: LONGINT);
		VAR vp: CSS2Properties.VisualProperties;
		BEGIN
			SetWidth(w); SetHeight(h);
		END SetSize;*)

		PROCEDURE GetWidth*(): LONGINT;
		BEGIN
			RETURN bounds.w
		END GetWidth;

		PROCEDURE SetWidth*(w: LONGINT);
		VAR vp: CSS2Properties.VisualProperties;
		BEGIN
			vp := properties(CSS2Properties.VisualProperties);
			vp.width.computed := w - (vp.margin.left.computed + vp.borderWidth.left.computed + vp.padding.left.computed
				+ vp.padding.right.computed + vp.borderWidth.right.computed + vp.margin.right.computed);
			ComputeWidths()
		END SetWidth;

		PROCEDURE GetHeight*(): LONGINT;
		BEGIN
			RETURN bounds.h
		END GetHeight;

		PROCEDURE SetHeight*(h: LONGINT);
		VAR vp: CSS2Properties.VisualProperties;
		BEGIN
			vp := properties(CSS2Properties.VisualProperties);
			vp.height.computed := h - (vp.margin.top.computed + vp.borderWidth.top.computed + vp.padding.top.computed
				+ vp.padding.bottom.computed + vp.borderWidth.bottom.computed + vp.margin.bottom.computed);
			ComputeHeights()
		END SetHeight;

		PROCEDURE GetX*(): LONGINT;
		BEGIN
			RETURN bounds.x
		END GetX;

		PROCEDURE SetX*(x: LONGINT);
		BEGIN
			lastX := lastX - (x - bounds.x); bounds.x := x;
			IF ~IsHit(lastX, lastY) THEN PointerUp(lastX, lastY, lastMouseKeys) END
		END SetX;

		PROCEDURE GetY*(): LONGINT;
		BEGIN
			RETURN bounds.y
		END GetY;

		PROCEDURE SetY*(y: LONGINT);
		BEGIN
			lastY := lastY - (y - bounds.y); bounds.y := y;
			IF ~IsHit(lastX, lastY) THEN PointerUp(lastX, lastY, lastMouseKeys) END
		END SetY;

		PROCEDURE GetContentBox*(): Box;
		VAR box: Box;
		BEGIN
			NEW(box); box.SetBox(contentBox); RETURN box
		END GetContentBox;

		PROCEDURE SetContentBox*(contentBox: Box);
		BEGIN
			SELF.contentBox.SetBox(contentBox)
		END SetContentBox;

		PROCEDURE GetContentWidth*(): LONGINT;
		BEGIN
			RETURN contentBox.w
		END GetContentWidth;

		PROCEDURE SetContentWidth*(w: LONGINT);
		BEGIN
			properties(CSS2Properties.VisualProperties).width.computed := w;
			ComputeWidths()
		END SetContentWidth;

		PROCEDURE GetContentHeight*(): LONGINT;
		BEGIN
			RETURN contentBox.h
		END GetContentHeight;

		PROCEDURE SetContentHeight*(h: LONGINT);
		BEGIN
			properties(CSS2Properties.VisualProperties).height.computed := h;
			ComputeHeights()
		END SetContentHeight;

		PROCEDURE GetContentX*(): LONGINT;
		BEGIN
			RETURN contentBox.x
		END GetContentX;

		PROCEDURE GetContentY*(): LONGINT;
		BEGIN
			RETURN contentBox.y
		END GetContentY;

		PROCEDURE GetBorderBox*(): Box;
		VAR box: Box;
		BEGIN
			NEW(box); box.SetBox(borderBox); RETURN box
		END GetBorderBox;

		PROCEDURE GetBorderWidth*(): LONGINT;
		BEGIN
			RETURN borderBox.w
		END GetBorderWidth;

		PROCEDURE GetBorderHeight*(): LONGINT;
		BEGIN
			RETURN borderBox.h
		END GetBorderHeight;

		PROCEDURE GetBorderX*(): LONGINT;
		BEGIN
			RETURN borderBox.x
		END GetBorderX;

		PROCEDURE GetBorderY*(): LONGINT;
		BEGIN
			RETURN borderBox.y
		END GetBorderY;

		PROCEDURE GetPaddingBox*(): Box;
		VAR box: Box;
		BEGIN
			NEW(box); box.SetBox(paddingBox); RETURN box
		END GetPaddingBox;

		PROCEDURE GetPaddingWidth*(): LONGINT;
		BEGIN
			RETURN paddingBox.w
		END GetPaddingWidth;

		PROCEDURE GetPaddingHeight*(): LONGINT;
		BEGIN
			RETURN paddingBox.h
		END GetPaddingHeight;

		PROCEDURE GetPaddingX*(): LONGINT;
		BEGIN
			RETURN paddingBox.x
		END GetPaddingX;

		PROCEDURE GetPaddingY*(): LONGINT;
		BEGIN
			RETURN paddingBox.y
		END GetPaddingY;

		PROCEDURE ComputeWidths*;
		VAR vp: CSS2Properties.VisualProperties;
		BEGIN
			vp := properties(CSS2Properties.VisualProperties);
			bounds.w := ENTIER(0.5 + vp.margin.left.computed + vp.borderWidth.left.computed + vp.padding.left.computed
				+ vp.width.computed + vp.padding.right.computed + vp.borderWidth.right.computed + vp.margin.right.computed);
			borderBox.x := ENTIER(0.5 + vp.margin.left.computed);
			borderBox.w := ENTIER(0.5 + vp.borderWidth.left.computed + vp.padding.left.computed + vp.width.computed
				+ vp.padding.right.computed + vp.borderWidth.right.computed);
			paddingBox.x := ENTIER(0.5 + vp.margin.left.computed + vp.borderWidth.left.computed);
			paddingBox.w := ENTIER(0.5 + vp.padding.left.computed + vp.width.computed + vp.padding.right.computed);
			contentBox.x := ENTIER(0.5 + vp.margin.left.computed + vp.borderWidth.left.computed + vp.padding.left.computed);
			contentBox.w := ENTIER(0.5 + vp.width.computed);
			IF ~IsHit(lastX, lastY) THEN PointerUp(lastX, lastY, lastMouseKeys) END
		END ComputeWidths;

		PROCEDURE ComputeHeights*;
		VAR vp: CSS2Properties.VisualProperties;
		BEGIN
			vp := properties(CSS2Properties.VisualProperties);
			bounds.h := ENTIER(0.5 + vp.margin.top.computed + vp.borderWidth.top.computed + vp.padding.top.computed
				+ vp.height.computed + vp.padding.bottom.computed + vp.borderWidth.bottom.computed
				+ vp.margin.bottom.computed);
			borderBox.y := ENTIER(0.5 + vp.margin.top.computed);
			borderBox.h := ENTIER(0.5 + vp.borderWidth.top.computed + vp.padding.top.computed + vp.height.computed
				+ vp.padding.bottom.computed + vp.borderWidth.bottom.computed);
			paddingBox.y := ENTIER(0.5 + vp.margin.top.computed + vp.borderWidth.top.computed);
			paddingBox.h := ENTIER(0.5 + vp.padding.top.computed + vp.height.computed + vp.padding.bottom.computed);
			contentBox.y := ENTIER(0.5 + vp.margin.top.computed + vp.borderWidth.top.computed + vp.padding.top.computed);
			contentBox.h := ENTIER(0.5 + vp.height.computed);
			IF ~IsHit(lastX, lastY) THEN PointerUp(lastX, lastY, lastMouseKeys) END
		END ComputeHeights;

		PROCEDURE GetNumberOfEvents*(): LONGINT;
		BEGIN
			RETURN GetNumberOfEvents^() + 4
		END GetNumberOfEvents;

		PROCEDURE GetEventName*(i: LONGINT): String;
		VAR s: String;
		BEGIN
			CASE i - GetNumberOfEvents^() OF
			| 0: s := NewString("hover")
			| 1: s := NewString("active")
			| 2: s := NewString("focus")
			| 3: RETURN NewString("pointer-move")
			ELSE
			END;
			RETURN s
		END GetEventName;

		PROCEDURE AddEventListener*(listener: Listener; event: ARRAY OF CHAR);
		BEGIN
			IF event = "hover" THEN hoverListeners.AddListener(listener)
			ELSIF event = "active" THEN activeListeners.AddListener(listener)
			ELSIF event = "focus" THEN focusListeners.AddListener(listener)
			ELSIF event = "pointer-move" THEN pointerMoveListeners.AddListener(listener)
			ELSE AddEventListener^(listener, event)
			END
		END AddEventListener;

		PROCEDURE UnlockUpdate*;
		BEGIN
			UnlockUpdate^();
			IF ~IsLocked() & ~invalidBox.IsEmpty() THEN
				InvalidateRange(invalidBox.x, invalidBox.y, invalidBox.w, invalidBox.h);
				invalidBox.w := 0; invalidBox.h := 0
			END
		END UnlockUpdate;

		PROCEDURE SetActive*(isActive: BOOLEAN);
		BEGIN
			IF isActive # SELF.isActive THEN
				LockUpdate();
				IF isActive THEN activeListeners.Dispatch(trueStateMsg) ELSE activeListeners.Dispatch(falseStateMsg) END;
				UnlockUpdate();
				SELF.isActive := isActive
			END
		END SetActive;

		PROCEDURE IsActive(): BOOLEAN;
		BEGIN
			RETURN isActive
		END IsActive;

		PROCEDURE SetPointer*(pointerInfo: WMWindowManager.PointerInfo);
		VAR parent: XML.Element;
		BEGIN
			parent := GetParent();
			IF (parent # NIL) & (parent IS VisualComponent) THEN
				parent(VisualComponent).SetPointer(pointerInfo)
			END
		END SetPointer;

		PROCEDURE GetPointerOwner*(): VisualComponent;
		BEGIN
			RETURN pointerOwner
		END GetPointerOwner;

		PROCEDURE IsHit*(x, y: LONGINT): BOOLEAN;
		VAR contents: XMLObjects.Enumerator; content: ANY;
		BEGIN
			IF ((properties(CSS2Properties.VisualProperties).overflow.computed = CSS2Properties.Visible) OR contentBox.InBox(x, y))
					& (properties(CSS2Properties.VisualProperties).visibility.computed = CSS2Properties.Visible) THEN
				IF GetNumberOfContents() > 0 THEN
					contents := GetContents();
					WHILE contents.HasMoreElements() DO
						content := contents.GetNext();
						IF (content IS VisualComponent)
								& content(VisualComponent).IsHit(x - content(VisualComponent).GetX(), y - content(VisualComponent).GetY())
								THEN
							RETURN TRUE
						END
					END
				END
			END;
			RETURN FALSE
		END IsHit;

		PROCEDURE PositionOwner*(x, y: LONGINT): VisualComponent;
		VAR contents: XMLObjects.Enumerator; content: ANY; po: VisualComponent;
		BEGIN
			IF (properties(CSS2Properties.VisualProperties).overflow.computed = CSS2Properties.Visible) OR contentBox.InBox(x, y) THEN
				IF GetNumberOfContents() > 0 THEN
					contents := GetContents();
					WHILE contents.HasMoreElements() DO
						content := contents.GetNext();
						IF content IS VisualComponent THEN
							WITH content: VisualComponent DO
								IF content.IsHit(x - content.GetX(), y - content.GetY()) THEN
									po := content
								END
							END
						END
					END
				END
			END;
			IF po # NIL THEN RETURN po ELSE
			RETURN SELF
			END
		END PositionOwner;

		PROCEDURE PointerLeave*;
		BEGIN
			IF (pointerOwner = SELF) THEN
				IF isActive THEN PointerUp(lastX, lastY, lastMouseKeys) END;
				IF isHovered THEN hoverListeners.Dispatch(falseStateMsg); isHovered := FALSE END
			ELSIF pointerOwner # SELF THEN
				pointerOwner.PointerLeave()
			END
		END PointerLeave;

		PROCEDURE PointerDown*(x, y: LONGINT; keys: SET);
		BEGIN
			IF dragable & (keys = {0}) THEN lastX := x; lastY := y END;
			SetActive(IsHit(x, y))
		END PointerDown;

		PROCEDURE PointerMove*(x, y: LONGINT; keys: SET);
		BEGIN
			lastX := x; lastY := y;
			LockUpdate();
			IF IsHit(x, y) THEN
				IF ~isHovered THEN
					hoverListeners.Dispatch(trueStateMsg);
					isHovered := TRUE;
					IF keys # {} THEN SetActive(TRUE) END;
					SetPointer(properties(CSS2Properties.VisualProperties).cursor.computed)
				END
			ELSE
				IF isHovered THEN
					IF keys # {} THEN
						SetActive(FALSE)
					END;
					hoverListeners.Dispatch(falseStateMsg);
					isHovered := FALSE
				END
			END;
			IF dragable & (keys = {0}) THEN
				(* to do: Move Component; Invalidate Parent *)
			END;
			pointerMoveListeners.Dispatch(NIL);
			UnlockUpdate()
		END PointerMove;

		PROCEDURE PointerUp*(x, y: LONGINT; keys: SET);
		BEGIN
			SetActive(FALSE)
		END PointerUp;

		PROCEDURE KeyPressed*(ch: CHAR; flags: SET; VAR keySym: LONGINT);
		END KeyPressed;

		PROCEDURE FocusReceived*;
		BEGIN
			focusListeners.Dispatch(trueStateMsg)
		END FocusReceived;

		PROCEDURE FocusLost*;
		BEGIN
			focusListeners.Dispatch(falseStateMsg);
			IF focusOwner # NIL THEN
				IF focusOwner # SELF THEN focusOwner.FocusLost() END;
				focusOwner := NIL
			END
		END FocusLost;

		PROCEDURE ProcessMessage*(m: ANY);
		VAR newPointerOwner: VisualComponent; kd, kdp: SHORTINT;
		BEGIN
			IF m IS MouseMessage THEN
				WITH m: MouseMessage DO
					IF m.keys = {} THEN
						(* up in case the pointer is not on the component but goes up *)
						IF lastMouseKeys # {} THEN
							IF pointerOwner = SELF THEN
								PointerUp(m.x, m.y, {})
							ELSE
								DEC(m.x, pointerOwner.GetX()); DEC(m.y, pointerOwner.GetY());
								pointerOwner.ProcessMessage(m);
							END;
							lastMouseKeys := {}	(*; RETURN*)
						ELSE
							newPointerOwner := PositionOwner(m.x, m.y);
							IF newPointerOwner # pointerOwner THEN
								pointerOwner.lastMouseKeys := m.keys;
								pointerOwner.PointerLeave(); pointerOwner := newPointerOwner END
						END
					ELSE
						(* click --> focus *)
						IF lastMouseKeys = {} THEN
							IF pointerOwner # focusOwner THEN
								IF focusOwner # NIL THEN focusOwner.FocusLost() END;
								focusOwner := pointerOwner;
								focusOwner.FocusReceived()
							END
						END
					END;
					IF pointerOwner = SELF THEN
						IF lastMouseKeys # m.keys THEN
							kd := 0;
							IF 0 IN m.keys THEN INC(kd) END;
							IF 1 IN m.keys THEN INC(kd) END;
							IF 2 IN m.keys THEN INC(kd) END;
							kdp := 0;
							IF 0 IN lastMouseKeys THEN INC(kdp) END;
							IF 1 IN lastMouseKeys THEN INC(kdp) END;
							IF 2 IN lastMouseKeys THEN INC(kdp) END;
							IF kd < kdp THEN PointerUp(m.x, m.y, m.keys)
							ELSE PointerDown(m.x, m.y, m.keys)
							END;
							lastMouseKeys := m.keys
						ELSE
							PointerMove(m.x, m.y, m.keys)
						END
					ELSE
						DEC(m.x, pointerOwner.GetX()); DEC(m.y, pointerOwner.GetY());
						pointerOwner.ProcessMessage(m)
					END
				END
			ELSIF m IS KeyMessage THEN
				WITH m: KeyMessage DO
					IF (focusOwner = SELF) OR (focusOwner = NIL) THEN
						KeyPressed(m.ch, m.flags, m.keySym)
					ELSIF (focusOwner # SELF) & (focusOwner # NIL) THEN
						IF m.keySym >= 0 THEN focusOwner.ProcessMessage(m) END
					END
				END
			END
		END ProcessMessage;

		PROCEDURE ComputeDimensions*;
		VAR contents: XMLObjects.Enumerator; content: ANY;
		BEGIN
			properties(CSS2Properties.VisualProperties).ComputeDimensions();
			contents := GetContents();
			WHILE contents.HasMoreElements() DO
				content := contents.GetNext();
				IF content IS VisualComponent THEN content(VisualComponent).ComputeDimensions() END
			END;
			ComputeWidths();
			ComputeHeights()
		END ComputeDimensions;

		PROCEDURE Format*;
		VAR contents: XMLObjects.Enumerator; content: ANY;
		BEGIN
			ComputeWidths();
			ComputeHeights();
			IF GetNumberOfContents() > 0 THEN
				contents := GetContents();
				WHILE contents.HasMoreElements() DO
					content := contents.GetNext();
					IF (content IS VisualComponent)
							& (content(VisualComponent).properties(CSS2Properties.VisualProperties).
								visibility.computed = CSS2Properties.Visible) THEN
						content(VisualComponent).Format() END
				END
			END
		END Format;

		PROCEDURE Resized*;
		VAR parent: XML.Element;
		BEGIN
			parent := GetParent();
			IF (parent # NIL) & (parent IS VisualComponent) THEN parent(VisualComponent).Resized() END;
		END Resized;

		PROCEDURE PropertiesChanged*;
		BEGIN
			PropertiesChanged^();
			IF properties(CSS2Properties.VisualProperties).dimensionChanged THEN Resized() END
		END PropertiesChanged;

		PROCEDURE InvalidateRange*(x, y, w, h: LONGINT);
		VAR parent: XML.Element;
		BEGIN
			IF IsLocked() THEN
				IF invalidBox.IsEmpty() THEN invalidBox.SetRect(x, y, w, h)
				ELSE invalidBox.ExtendRect(x, y, w, h)
				END
			ELSE
				parent := GetParent();
				IF (parent # NIL) THEN
					parent(VisualComponent).InvalidateRange(bounds.x + x, bounds.y + y, w, h)
				END
			END
		END InvalidateRange;

		PROCEDURE Invalidate*;
		BEGIN
			Invalidate^();
			InvalidateRange(0, 0, bounds.w, bounds.h)
		END Invalidate;

		PROCEDURE Draw*(ctxt: Gfx.Context);
		VAR enum: XMLObjects.Enumerator; p: ANY; state1, state2: Gfx.State; llx, lly, urx, ury: REAL;
		BEGIN
			IF properties(CSS2Properties.VisualProperties).overflow.computed = CSS2Properties.Hidden THEN
				Gfx.Save(ctxt, {Gfx.clip}, state1);
				Gfx.DrawRect(ctxt, contentBox.x, contentBox.y, contentBox.x + contentBox.w, contentBox.y + contentBox.h,
					{Gfx.Clip})
			END;
			Gfx.GetClipRect(ctxt, llx, lly, urx, ury);
			IF (0 < urx) & (llx < bounds.w) & (0 < ury) & (lly < bounds.h) & (GetNumberOfContents() > 0) THEN
				enum := GetContents();
				WHILE enum.HasMoreElements() DO
					p := enum.GetNext();
					IF p IS VisualComponent THEN
						WITH p: VisualComponent DO
							IF (p.GetX() < urx) & (llx < p.GetX() + p.GetWidth()) & (p.GetY() < ury) & (lly < p.GetY() + p.GetHeight())
									& (p.properties(CSS2Properties.VisualProperties).visibility.computed = CSS2Properties.Visible) THEN
								Gfx.Save(ctxt, {Gfx.ctm, Gfx.clip}, state2);
								Gfx.Translate(ctxt, p.GetX(), p.GetY());
								(* Gfx.DrawRect(ctxt, 0, 0, childBounds.w, childBounds.h, {Gfx.Clip}); *)
								p.Draw(ctxt);
								Gfx.Restore(ctxt, state2)
							END
						END
					END
				END
			END;
			IF properties(CSS2Properties.VisualProperties).overflow.computed = CSS2Properties.Hidden THEN
				Gfx.Restore(ctxt, state1)
			END
		END Draw;

	END VisualComponent;

	PROCEDURE NoReportError(pos, line, row: LONGINT; msg: ARRAY OF CHAR);
	END NoReportError;

	PROCEDURE NewString*(value: ARRAY OF CHAR): String;
	VAR s: String;
	BEGIN
		NEW(s, DynamicStrings.StringLength(value) + 1);
		COPY(value, s^);
		RETURN s
	END NewString;

(*	PROCEDURE DrawClipRect*(ctxt: Gfx.Context; x, y, w, h: LONGINT);
	VAR llx, lly, urx, ury: INTEGER;
	BEGIN
		IF ctxt IS GfxRaster.Context THEN
			WITH ctxt: GfxRaster.Context DO
				llx := SHORT(x + ENTIER(0.5 + ctxt.ctm[2, 0])); urx := SHORT(llx + w);
				lly := SHORT(y + ENTIER(0.5 + ctxt.ctm[2, 1])); ury := SHORT(lly + h);
				GfxRegions.ClipRect(llx, lly, urx, ury, SHORT(ENTIER(0.5 + ctxt.clipReg.llx)), SHORT(ENTIER(0.5 + ctxt.clipReg.lly)),
					SHORT(ENTIER(0.5 + ctxt.clipReg.urx)), SHORT(ENTIER(0.5 + ctxt.clipReg.ury)));
				Gfx.ResetClip(ctxt);
				GfxRegions.SetToRect(ctxt.clipReg, llx, lly, urx, ury);
				ctxt.clipState := GfxRaster.In;
			END
		ELSE
			Gfx.DrawRect(ctxt, x, y, x + w, y + h, {Gfx.Clip})
		END
	END DrawClipRect;*)

	PROCEDURE ExtractEvent(VAR string: ARRAY OF CHAR): String;
	VAR i, j, len: LONGINT; event: String;
	BEGIN
		len := DynamicStrings.StringLength(string);
		i := len - 1;
		WHILE (i >= 0) & (string[i] # ':') DO DEC(i) END; j := 0;
		IF i >= 0 THEN
			(*string[i] := 0X;*)
			NEW(event, len - i);
			FOR i := i + 1 TO len - 1 DO event[j] := string[i]; (*string[i] := 0X;*) INC(j) END
		ELSE
			NEW(event, 1)
		END;
		event[j] := 0X;
		RETURN event
	END ExtractEvent;

END XMLComponents.
