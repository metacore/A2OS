MODULE WMVisualComponentSkeleton; (** AUTHOR "staubesv"; PURPOSE "Skeleton for visual components"; *)

IMPORT
	Strings, XML, WMGraphics, WMProperties, WMComponents;

TYPE

	YourComponent* = OBJECT(WMComponents.VisualComponent)
	VAR
		property- : WMProperties.Int32Property;

		(* values of properties can be cached to enabled lock-free access in code block that hold the hierarchy lock anyway *)
		propertyCached- : WMProperties.Int32Property;
		propertyCachedI : SIGNED32;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrYourComponent);
			NEW(property, NIL, StrProperty, StrPropertyDescription); properties.Add(property);
			NEW(propertyCached, NIL, StrPropertyCached, StrPropertyCachedDescription); properties.Add(propertyCached);
		END Init;

		PROCEDURE Initialize;
		BEGIN (* called by sequencer -> hierarchy is locked *)
			Initialize^;
			(* Is called by component.Reset() to, (also when put into FormWindow). Without initialization, the component will not respond to messages *)
		END Initialize;

		(* 	Call upon change of single property. If multiple properties have been changed, <property> has the value <properties>
			and RecacheProperties is called addtionally *)
		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN (* called by sequencer -> hierarchy is locked *)
			IF (property = property) THEN
				(* react to property change *)
				(*call Invalidate() if this property change has an impact on visualization*)
			ELSIF (property = propertyCached) THEN
				propertyCachedI := propertyCached.Get();
				(* further actions if required *)
				(*call Invalidate() if this property change has an impact on visualization*)
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		(* Called whenever component is resetted (also when put into FormWindow) *)
		PROCEDURE RecacheProperties;
		BEGIN (* called by sequencer -> hierarchy is locked *)
			RecacheProperties^;
			propertyCachedI := propertyCached.Get();
		END RecacheProperties;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		BEGIN (* called by sequencer -> hierarchy is locked *)
			DrawBackground^(canvas);
			(* draw the visual component by using the canvas *)
		END DrawBackground;

	END YourComponent;

VAR
	(* String constants *)
	StrYourComponent,
	StrProperty, StrPropertyDescription,
	StrPropertyCached, StrPropertyCachedDescription : Strings.String;

PROCEDURE GenYourComponent*() : XML.Element;
VAR yourComponent : YourComponent;
BEGIN
	NEW(yourComponent); RETURN yourComponent;
END GenYourComponent;

PROCEDURE InitStrings;
BEGIN
	StrYourComponent := Strings.NewString("YourComponent");
	StrProperty := Strings.NewString("Property");
	StrPropertyDescription := Strings.NewString("Description of Property");
	StrPropertyCached := Strings.NewString("PropertyCached");
	StrPropertyCachedDescription := Strings.NewString("Description of PropertyCached");
END InitStrings;

BEGIN
	InitStrings;
END WMVisualComponentSkeleton.
