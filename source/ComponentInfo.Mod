MODULE ComponentInfo; (** AUTHOR "staubesv/TF"; PURPOSE "Component Information"; *)

IMPORT
	Streams, Commands, Strings, KernelLog, XML, XMLObjects, WMWindowManager, WMProperties, WMEvents, WMComponents;

CONST
	MaxNofWindows = 100;

TYPE
	Windows = ARRAY MaxNofWindows OF WMWindowManager.Window;

	Statistics = OBJECT
	VAR
		nofComponents, nofVisualComponents, nofOtherElements, nofEventSources, nofEventListeners : LONGINT;
		nofBooleanProperties, nofInt32Properties, nofColorProperties, nofRectangleProperties,
		nofStringProperties, nofOtherProperties : LONGINT;

		PROCEDURE &Reset;
		BEGIN
			nofComponents := 0; nofVisualComponents := 0;  nofOtherElements := 0; nofEventSources := 0; nofEventListeners := 0;
			nofBooleanProperties := 0; nofInt32Properties := 0; nofColorProperties := 0; nofRectangleProperties := 0;
			nofStringProperties := 0; nofOtherProperties := 0;
		END Reset;

		PROCEDURE Add(stats : Statistics);
		BEGIN
			ASSERT(stats # NIL);
			INC(nofComponents, stats.nofComponents);
			INC(nofVisualComponents, stats.nofVisualComponents);
			INC(nofOtherElements, stats.nofOtherElements);
			INC(nofEventSources, stats.nofEventSources);
			INC(nofEventListeners, stats.nofEventListeners);
			INC(nofBooleanProperties, stats.nofBooleanProperties);
			INC(nofInt32Properties, stats.nofInt32Properties);
			INC(nofColorProperties, stats.nofColorProperties);
			INC(nofRectangleProperties, stats.nofRectangleProperties);
			INC(nofStringProperties, stats.nofStringProperties);
			INC(nofOtherProperties, stats.nofOtherProperties);
		END Add;

		PROCEDURE Show(out : Streams.Writer);
		BEGIN
			ASSERT(out # NIL);
			out.String(" elements: "); out.Int(nofComponents + nofVisualComponents + nofOtherElements, 0);  out.Ln;
			out.String("   Components: "); out.Int(nofComponents, 0); out.Ln;
			out.String("   VisualComponents: "); out.Int(nofVisualComponents, 0); out.Ln;
			out.String("   Other: "); out.Int(nofOtherElements, 0); out.Ln;
			out.String("event sources: "); out.Int(nofEventSources, 0); out.Ln;
			out.String("event listeners: "); out.Int(nofEventListeners, 0); out.Ln;
			out.String("properties: ");
			out.Int(nofBooleanProperties + nofInt32Properties + nofColorProperties + nofRectangleProperties +
				nofStringProperties + nofOtherProperties, 0);
			out.Ln;
			out.String("   Boolean: "); out.Int(nofBooleanProperties, 0); out.Ln;
			out.String("   Int32: "); out.Int(nofInt32Properties, 0); out.Ln;
			out.String("   Color: "); out.Int(nofColorProperties, 0); out.Ln;
			out.String("   Rectangle: "); out.Int(nofRectangleProperties, 0); out.Ln;
			out.String("   String: "); out.Int(nofStringProperties, 0); out.Ln;
			out.String("   Other: "); out.Int(nofOtherProperties, 0); out.Ln;
		END Show;

	END Statistics;

PROCEDURE DumpComponent*(obj : ANY; out : Streams.Writer);

	PROCEDURE DumpProperties(pl : WMProperties.PropertyList);
	VAR i : LONGINT; pa : WMProperties.PropertyArray; p :WMProperties.Property; s : Strings.String;
		st : Streams.StringWriter;
		value : ARRAY 100 OF CHAR;
	BEGIN
		pa := pl.Enumerate();
		FOR i := 0 TO LEN(pa) - 1 DO
			p := pa[i];
			IF p = NIL THEN out.String("<property is nil>"); out.Ln;
			ELSE
				out.String("Name : "); s := p.GetName(); IF s # NIL THEN out.String(s^) ELSE out.String("<NIL>") END;
				NEW(st, 100); p.ToStream(st); st.Get(value);
				out.String(" Value : "); out.String(value); IF p.GetIsDefault() THEN out.String("(default)") END;
				out.String(" Info : "); s := p.GetInfo(); IF s # NIL THEN out.String(s^) ELSE out.String("<NIL>") END;
				out.Ln
			END
		END
	END DumpProperties;

	PROCEDURE DumpEvents(el : WMEvents.EventSourceList);
	VAR i : LONGINT; ea : WMEvents.EventSourceArray; e : WMEvents.EventSource; s : Strings.String;
	BEGIN
		ea := el.Enumerate();
		FOR i := 0 TO LEN(ea) - 1 DO
			e := ea[i];
			IF e # NIL THEN
				out.String("Name : "); s := e.GetName(); IF s # NIL THEN out.String(s^) ELSE out.String("<NIL>") END;
				out.String("  ");
				out.String(" Info : "); s := e.GetInfo(); IF s # NIL THEN out.String(s^) ELSE out.String("<NIL>") END;
				out.Ln
			END;
		END;
	END DumpEvents;

	PROCEDURE DumpListeners(el : WMEvents.EventListenerList);
	VAR i : LONGINT; ea : WMEvents.EventListenerArray; e : WMEvents.EventListenerInfo; s : Strings.String;
	BEGIN
		ea := el.Enumerate();
		FOR i := 0 TO LEN(ea)- 1 DO
			e := ea[i];
			IF e # NIL THEN
				out.String("Name : "); s := e.GetName(); IF s # NIL THEN out.String(s^) ELSE out.String("<NIL>") END;
				out.String("  ");
				out.String(" Info : "); s := e.GetInfo(); IF s # NIL THEN out.String(s^) ELSE out.String("<NIL>") END;
				out.Ln
			END;
		END;
	END DumpListeners;

BEGIN
	IF (out = NIL) THEN NEW(out, KernelLog.Send, 1024); END;
	IF obj = NIL THEN
		out.String("NIL"); out.Ln
	ELSE
		IF obj IS WMComponents.Component THEN
			out.String("Properties : "); out.Ln;
			DumpProperties(obj(WMComponents.Component).properties);
			out.String("Events : "); out.Ln;
			DumpEvents(obj(WMComponents.Component).events);
			out.String("Listeners : "); out.Ln;
			DumpListeners(obj(WMComponents.Component).eventListeners);
		ELSE out.String("is not a component"); out.Ln
		END
	END
END DumpComponent;

(** Gather statistics about component incl. its subcomponents *)
PROCEDURE GatherStatistics*(component : XML.Element; stats : Statistics);

	PROCEDURE VisitElement(element : XML.Element);
	VAR
		component : WMComponents.Component;
		events : WMEvents.EventSourceArray;
		listeners : WMEvents.EventListenerArray;
		properties : WMProperties.PropertyArray;
		enum : XMLObjects.Enumerator;
		ptr : ANY;
		i : LONGINT;
	BEGIN
		ASSERT(element # NIL);
		IF (element IS WMComponents.Component) OR (element IS WMComponents.VisualComponent) THEN
			IF (element IS WMComponents.VisualComponent) THEN INC(stats.nofVisualComponents); ELSE INC(stats.nofComponents); END;
			component := element (WMComponents.Component);
			events := component.events.Enumerate();
			IF (events # NIL) THEN INC(stats.nofEventSources, LEN(events)); END;
			listeners := component.eventListeners.Enumerate();
			IF (listeners # NIL) THEN INC(stats.nofEventListeners, LEN(listeners)); END;
			properties := component.properties.Enumerate();
			IF (properties # NIL) THEN
				FOR i := 0 TO LEN(properties)-1 DO
					IF (properties[i] IS WMProperties.BooleanProperty) THEN INC(stats.nofBooleanProperties);
					ELSIF (properties[i] IS WMProperties.Int32Property) THEN INC(stats.nofInt32Properties);
					ELSIF (properties[i] IS WMProperties.ColorProperty) THEN INC(stats.nofColorProperties);
					ELSIF (properties[i] IS WMProperties.RectangleProperty) THEN INC(stats.nofRectangleProperties);
					ELSIF (properties[i] IS WMProperties.StringProperty) THEN INC(stats.nofStringProperties);
					ELSE
						INC(stats.nofOtherProperties);
					END;
				END;
			END;
		ELSE
			INC(stats.nofOtherElements);
		END;
		enum := element.GetContents();
		WHILE enum.HasMoreElements() DO
			ptr := enum.GetNext();
			IF (ptr IS XML.Element) THEN
				VisitElement(ptr (XML.Element));
			END;
		END;
	END VisitElement;

BEGIN
	ASSERT(stats # NIL);
	IF (component # NIL) THEN
		VisitElement(component);
	END;
END GatherStatistics;

PROCEDURE ShowStatistics*(context : Commands.Context); (** windowTitleMask  ~ *)
VAR
	stats, tot : Statistics;
	windows : Windows; window : WMWindowManager.Window;
	windowTitle : Strings.String;
	manager : WMWindowManager.WindowManager;
	mask : ARRAY 128 OF CHAR;
	nofWindows, nofMatches,  i : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(mask);
	FOR i := 0 TO LEN(windows)-1 DO windows[i] := NIL; END;
	nofWindows := 0;
	manager := WMWindowManager.GetDefaultManager();
	manager.lock.AcquireWrite;
	window := manager.GetFirst();
	WHILE (window # NIL) & (nofWindows < MaxNofWindows) DO
		windows[nofWindows] := window;
		INC(nofWindows);
		window := manager.GetNext(window);
	END;
	manager.lock.ReleaseWrite;
	NEW(tot); NEW(stats);
	nofMatches := 0;
	FOR i := 0 TO nofWindows - 1 DO
		windowTitle := windows[i].GetTitle();
		IF (windowTitle # NIL) THEN
			IF Strings.Match(mask, windowTitle^) THEN
				INC(nofMatches);
				context.out.String("*** Window "); context.out.String(windowTitle^); context.out.String(": ");
				IF (windows[i] IS WMComponents.FormWindow) THEN
					context.out.Ln;
					stats.Reset;
					GatherStatistics(windows[i](WMComponents.FormWindow).form, stats);
					stats.Show(context.out);
					tot.Add(stats);
				ELSE
					context.out.String("Not a FormWindow"); context.out.Ln;
				END;
			END;
		END;
	END;
	context.out.Int(nofMatches, 0); context.out.String(" matches"); context.out.Ln;
	IF (nofMatches > 1) THEN
		context.out.String("Statistics for all matches: "); context.out.Ln;
		tot.Show(context.out);
	END;
END ShowStatistics;

PROCEDURE ShowPrototypes*(context : Commands.Context);
VAR
	array : WMComponents.ListArray;
	propertyArray : WMProperties.PropertyArray;
	nofPrototypes, i, j : LONGINT;
	string : Strings.String;
BEGIN
	nofPrototypes := 0;
	context.out.String("Property Prototypes:"); context.out.Ln;
	array := WMComponents.propertyListList.Enumerate();
	IF (array # NIL) THEN
		FOR i := 0 TO LEN(array)-1 DO
			propertyArray := array[i].Enumerate();
			IF (propertyArray # NIL) THEN
				INC(nofPrototypes, LEN(propertyArray));
				FOR j := 0 TO LEN(propertyArray)-1 DO
					string := propertyArray[j].GetName();
					IF (string # NIL) THEN context.out.String(string^); ELSE context.out.String("NoName"); END;
					string := propertyArray[j].GetInfo();
					context.out.String(" (");
					IF (string # NIL) THEN context.out.String(string^); ELSE context.out.String("NoInfo"); END;
					context.out.String(")");
					context.out.Ln;
				END;
			END;
		END;
	END;
	context.out.String("Number of property prototypes: "); context.out.Int(nofPrototypes, 0); context.out.Ln;
END ShowPrototypes;


END ComponentInfo.

SystemTools.Free ComponentInfo ~

ComponentInfo.ShowStatistics * ~

ComponentInfo.ShowStatistics File* ~

ComponentInfo.ShowPrototypes ~
