MODULE DynamicWebpage; (** AUTHOR "Luc Blaeser"; PURPOSE "Basetypes for Dynamic Webpages"; *)
	IMPORT XML, HTTPSupport, Strings;

	CONST
		(** variable names for method invocation over HTTP to handle user events, must be lower case *)
		HTTPVarCommandModule* = "dxpmodule";
		HTTPVarCommandObject* = "dxpobject";
		HTTPVarCommandMethod* = "dxpmethod";
		HTTPVarCommandObjectId* = "dxpoid";
		HTTPVarCommandParamPrefix* = "dxpparam-";

		XMLAttributeObjectIdName* = "id"; (** to specifiy the instance of a statefull active element for a session and a requested file *)
		DXPReservedObjectIdPrefix* = "-dxp-"; (** this prefix is reserved for system generated unique object id for statefull active elements *)

		DynamicWebpageExtension* = "DXP"; (** in uppercase *)
		DefaultWebpage* = "index.dxp";
		ConfigurationSupperSectionName* = "DynamicWebpages";
		ConfigurationSubSectionName* = "ActiveElementModules";
		ProcNameGetDescriptors* = "GetActiveElementDescriptors";

		(** variable names to store the actual state counter, used to detect whether the user has pressed the back or refresh
		 * button in the browser's navigation bar *)
		StateCounterVariable* = "dxpstatecounter";

	TYPE
		Parameter* = POINTER TO RECORD
			name*: Strings.String;
			value*: Strings.String
		END;

		ParameterList* = OBJECT
			VAR
				parameters*: POINTER TO ARRAY OF Parameter;

			PROCEDURE GetParameterValueByName*(CONST name: ARRAY OF CHAR): Strings.String;
			VAR par: Parameter;
			BEGIN
				par := GetParameterByName(name);
				IF (par # NIL) THEN
					RETURN par.value
				ELSE
					RETURN NIL
				END
			END GetParameterValueByName;

			PROCEDURE  GetParameterByName*(CONST name: ARRAY OF CHAR): Parameter;
			VAR i: SIZE;
			BEGIN
				IF parameters # NIL THEN
					FOR i := 0 TO LEN(parameters)-1 DO
						IF parameters[i].name^ = name THEN
							RETURN parameters[i]
						END
					END
				END;
				RETURN NIL
			END GetParameterByName;

			PROCEDURE GetCount*() : SIZE;
			BEGIN
				RETURN LEN(parameters)
			END GetCount;
		END ParameterList;

		EventHandler* = PROCEDURE {DELEGATE} (request: HTTPSupport.HTTPRequest; params: ParameterList);

		EventHandlerObject* = OBJECT
			VAR
				methodName*: ARRAY 128 OF CHAR;
				handler*: EventHandler;

			PROCEDURE &Init*(CONST name: ARRAY OF CHAR; handlerMeth: EventHandler);
			BEGIN COPY(name, methodName); handler := handlerMeth
			END Init;
		END EventHandlerObject;

		EventHandlerList* = POINTER TO ARRAY OF EventHandlerObject;

		(** abstract base class  for active web elements *)
		ActiveElement* = OBJECT
			(** abstract main transformation method, the active element occurring as descendants of 'input' are already transformed*)
			PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
			BEGIN HALT(301)
			END Transform;

			(** transformation method invoked before the active element occurring as descendanrs of 'input' will be transformed *)
			PROCEDURE PreTransform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
			BEGIN RETURN input
			END PreTransform;

			PROCEDURE GetEventHandlers*() : EventHandlerList;
			BEGIN RETURN NIL
			END GetEventHandlers;
		END ActiveElement;

		(** abstract base class for active web element which belongs to a session, i.e. is statefull *)
		StateFullActiveElement* = OBJECT (ActiveElement)
		END StateFullActiveElement;

		(** abstract base class for singleton active web element which is not assigned to a session, i.e. is stateless *)
		StateLessActiveElement* = OBJECT (ActiveElement)
		END StateLessActiveElement;

		(** a factory procedure to create instances of active elements of the module *)
		ActiveElementFactoryProc* = PROCEDURE (): ActiveElement;

		ActiveElementDescriptor* = OBJECT
			VAR
				elementName*: ARRAY 128 OF CHAR;
				factory*: ActiveElementFactoryProc;

			PROCEDURE &Init*(CONST name: ARRAY OF CHAR; factoryProc: ActiveElementFactoryProc);
			BEGIN COPY(name, elementName); factory := factoryProc
			END Init;

		END ActiveElementDescriptor;

		ActiveElementDescSet* = OBJECT
			VAR
				descriptors*: POINTER TO ARRAY OF ActiveElementDescriptor;

			PROCEDURE &Init*(CONST descs: ARRAY OF ActiveElementDescriptor);
			VAR i: SIZE;
			BEGIN
				NEW(descriptors, LEN(descs));
				FOR i := 0 TO LEN(descs)-1 DO
					descriptors[i] := descs[i]
				END
			END Init;

			PROCEDURE GetCount*() : SIZE;
			BEGIN
				RETURN LEN(descriptors^)
			END GetCount;

			PROCEDURE GetItem*(i: SIZE) : ActiveElementDescriptor;
			BEGIN
				RETURN descriptors[i]
			END GetItem;
		END ActiveElementDescSet;

		 ActiveElementDescSetFactory* = PROCEDURE() : ActiveElementDescSet;

		(** additionally there must be a procedure which gives all descriptors for the active elements in the module
			PROCEDURE GetActiveElementDescriptors*(par:ANY) : ANY;
				 no parameter; returns the descriptors of active elements (ActiveElementDescSet)
				 must be thread safe
		 *)

		 VAR idCounter: SIGNED32;

		 (** get a new unique object id for statefull active element created while the transformation process *)
		 PROCEDURE CreateNewObjectId*() : Strings.String;
		 VAR oid: Strings.String; idString: ARRAY 14 OF CHAR;
		 BEGIN
		 	NEW(oid, Strings.Length(DXPReservedObjectIdPrefix)+14);
		 	Strings.IntToStr(idCounter, idString); INC(idCounter);
		 	Strings.Concat(DXPReservedObjectIdPrefix, idString, oid^);
		 	RETURN oid
		 END CreateNewObjectId;

BEGIN
	idCounter := 0
END DynamicWebpage.

System.Free DynamicWebpage ~
