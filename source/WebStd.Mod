MODULE WebStd; (** AUTHOR "Luc Blaeser"; PURPOSE "Standard Active Element Library for Dynamic Webpage Generation"*)

IMPORT DynamicWebpage, PrevalenceSystem, HTTPSupport, HTTPSession, GenericSort, XML, XMLObjects, DynamicStrings,
	Dates, Strings, TFClasses, KernelLog, WebHTTP;

CONST
	DateTimeFormat* = "dd.mm.yyyy hh:nn:ss";

	SessionContainerNamePrefix = "dxp-WebStd-sessioncontainer-";
	SessionVariableNamePrefix = "dxp-WebStd-variable-";
	SessionGuardNamePrefix = "dxp-WebStd-Guard-";
	SessionVisitorCounterPrefix = "dxp-WebStd-VisitorCounter-";

TYPE
	(** normal XHTML attribute and element names should be lowercase *)

	(** hyperlink with implicit delegation of sessionid if target is not another webserver.
	 * if href is not specified then the previously requested page is used as href .
	 * usage expamle:
	 *  <WebStd:Hyperlink href="site.dxp" target="mainview" ...>text or image</WebStd:Hyperlink> *)
	Hyperlink* = OBJECT (DynamicWebpage.StateLessActiveElement)

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR a: XML.Element; hrefString, attrName, sessionCounterStr: Strings.String; newUri: ARRAY 4096 OF CHAR;
			enum: XMLObjects.Enumerator; p: ANY; attr: XML.Attribute; content: XML.Content;
			dynStr: DynamicStrings.DynamicString; session: HTTPSession.Session;
		BEGIN
			session := HTTPSession.GetSession(request); (* session # NIL *)
			hrefString := input.GetAttributeValue("href");
			IF ((hrefString = NIL) OR (~IsExternalHyperlink(hrefString^, request.header.host))) THEN
				IF (hrefString # NIL) THEN
					COPY(hrefString^, newUri);
					IF (Strings.Pos("?", hrefString^) = -1) THEN
						Strings.Append(newUri, "?")
					ELSE
						Strings.Append(newUri, "&")
					END
				ELSE
					(* href is the previous requested page *)
					Strings.Concat(request.shortUri, "?", newUri)
				END;
				Strings.Append(newUri, HTTPSession.HTTPVarSessionIdName);
				Strings.Append(newUri, "=");
				Strings.Append(newUri, session.sessionId);

				p := session.GetVariableValue(DynamicWebpage.StateCounterVariable);
				IF ((p # NIL) & (p IS DynamicStrings.DynamicString)) THEN
					dynStr := p(DynamicStrings.DynamicString); sessionCounterStr := dynStr.ToArrOfChar(); (* sessionCounterStr # NIL *)
					Strings.Append(newUri, "&");
					Strings.Append(newUri, DynamicWebpage.StateCounterVariable);
					Strings.Append(newUri, "=");
					Strings.Append(newUri, sessionCounterStr^)
				END
			ELSE
				COPY(hrefString^, newUri)
			END;

			NEW(a); a.SetName("a"); a.SetAttributeValue("href", newUri);
			enum := input.GetAttributes();
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext(); attr := p(XML.Attribute);
				attrName := attr.GetName();
				IF ((attrName # NIL) & (attrName^ # "href") & (Strings.Pos("xmlns", attrName^) # 0)) THEN
					a.AddAttribute(attr)
				END
			END;
			enum := input.GetContents();
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext(); content := p(XML.Content);
				a.AddContent(content)
			END;

			RETURN a
		END Transform;
	END Hyperlink;

	(** returns a HTTP header field value specified by name attribute and special header properties like "#ip", "#port", "#method"
	 *     <WebStd:GetHeaderField name="referer" />
	 *)
	GetHeaderField* = OBJECT(DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR fieldName : Strings.String;
			result : ARRAY 256 OF CHAR;
		BEGIN
			fieldName := elem.GetAttributeValue("name");
			IF (fieldName # NIL) THEN
				WebHTTP.GetRequestPropertyValue(request.header, fieldName^, result);
				RETURN CreateXMLText(result)
			ELSE RETURN NIL
			END
		END Transform;
	END GetHeaderField;

	(** set a session global variable, usage example:
	 *  <WebStd:SetVariable name="myvar" value="myVal"/>
	*)
	SetVariable* = OBJECT(DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR varName, varValue, encVarName: Strings.String; session: HTTPSession.Session;
			dynVarValue, dynVarName: DynamicStrings.DynamicString;
		BEGIN (* only DynamicString can have a type guard for PTR *)
			varName := elem.GetAttributeValue("name");
			varValue := elem.GetAttributeValue("value");
			IF ((varName # NIL) & (varValue # NIL)) THEN
				NEW(dynVarValue); dynVarValue.Append(varValue^);
				NEW(dynVarName); Concat(dynVarName, SessionVariableNamePrefix);
				dynVarName.Append(varName^);
				encVarName := dynVarName.ToArrOfChar();
				session := HTTPSession.GetSession(request);
				session.AddVariableValue(encVarName^, dynVarValue)
			END;
			RETURN NIL
		END Transform;
	END SetVariable;

	(** get a session global variable, usage example:
	 *  <WebStd:GetVariable name="myvar"/>
	*)
	GetVariable* = OBJECT(DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR varName, varValue, encVarName: Strings.String; session: HTTPSession.Session;
			dynVarValue, dynVarName: DynamicStrings.DynamicString; p: ANY;
		BEGIN
			varName := elem.GetAttributeValue("name");
			IF (varName # NIL) THEN
				NEW(dynVarName); Concat(dynVarName, SessionVariableNamePrefix);
				dynVarName.Append(varName^);
				encVarName := dynVarName.ToArrOfChar();
				session := HTTPSession.GetSession(request);
				p := session.GetVariableValue(encVarName^);
				IF ((p # NIL) & (p IS DynamicStrings.DynamicString)) THEN
					dynVarValue := p(DynamicStrings.DynamicString);
					IF (dynVarValue.Length() > 0) THEN
						varValue := dynVarValue.ToArrOfChar();
						RETURN CreateXMLText(varValue^)
					END
				END
			END;
			RETURN NIL
		END Transform;
	END GetVariable;

	(** conditional element. If 'condition' contains exactly the text "true" then the 'Expression'-content is the result.
	 * If 'condition' contains exactly the text 'false' then no result will be generated and active elements apearing
	 * under the 'Expression'-element will not be transformed.
	 * The condition value could be the result of another active element like <WebStd:IsEqual>
	 * "WebStd:IsEqual". Usage example:
	 * <WebStd:Guard>
	 *    <Condition>true|false</Condition>
	 *    <Expression> .. </Expression>
	 * </WebStd:Guard>
	 *)
	Guard* = OBJECT (DynamicWebpage.StateLessActiveElement)
		(* the 'Expression' subtree is only transformed if the condition has the value 'true'. Since the condition can have
		 * further active element in its content, it can only be decided in the Transform()-method if the contents of
		 * the 'Expression'-element will be used for the transformation result.
		 * Therefore in PreTransform the 'Expression'-subtree is cut out and stored into the session using the
		 * SessionGuardNamePrefix followed by the request.shortUri to support parallel requests of the same client
		 * for different documents with if statements. The use of a state full active element would result in worse
		 * performance, since each 'Guard'-occurence would have its own instances *)
		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR conditionElem, expressionElem: XML.Element; session: HTTPSession.Session;
			dynVarName: DynamicStrings.DynamicString; varName, condText: Strings.String; p: ANY;
			outContainer: XML.Container;
		BEGIN
			session := HTTPSession.GetSession(request);

			NEW(dynVarName); Concat(dynVarName, SessionGuardNamePrefix);
			dynVarName.Append(request.shortUri);
			varName := dynVarName.ToArrOfChar();
			p := session.GetVariableValue(varName^);
			IF ((p # NIL) & (p IS XML.Element)) THEN
				expressionElem := p(XML.Element)
			ELSE
				expressionElem := NIL
			END;
			session.RemoveVariable(varName^);

			conditionElem := GetXMLSubElement(elem, "Condition");
			IF (conditionElem # NIL) THEN
				condText := GetXMLCharContent(conditionElem);
				IF ((condText # NIL) & (condText^ = "true")) THEN
					IF (expressionElem # NIL) THEN
						NEW(outContainer);
						CopyXMLSubContents(expressionElem, outContainer);
						RETURN outContainer
					ELSE
						RETURN NIL
					END
				ELSIF ((condText # NIL) & (condText^ = "false")) THEN
					RETURN NIL
				ELSE
					NEW(outContainer);
					AppendXMLContent(outContainer, CreateXMLText("WebStd:Guard: Condition value must be either 'true' or 'false' but not "));
					IF (condText # NIL) THEN AppendXMLContent(outContainer, CreateXMLText(condText^)) END;
					RETURN outContainer
				END
			ELSE
				RETURN CreateXMLText("No condition specified for WebStd:Guard.")
			END
		END Transform;

		PROCEDURE PreTransform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR expressionElem: XML.Element; session: HTTPSession.Session; dynVarName: DynamicStrings.DynamicString;
			varName: Strings.String;
		BEGIN
			session := HTTPSession.GetSession(request);
			expressionElem := GetXMLSubElement(elem, "Expression");

			NEW(dynVarName); Concat(dynVarName, SessionGuardNamePrefix);
			dynVarName.Append(request.shortUri);
			varName := dynVarName.ToArrOfChar();
			session.AddVariableValue(varName^, expressionElem);

			IF (expressionElem # NIL) THEN
				elem.RemoveContent(expressionElem)
			END;
			RETURN elem
		END PreTransform;
	END Guard;

	(** sequence over multiple requests of one page for a session. If the attribute 'circular' is set to 'true' then at the end of the
	 * sequence the sequence will be restarted. if the sequence is non circular and has reached the last state then it stays in
	 * the last state. Usage example:
	 * <WebStd:Sequence id="mySeq3" circular="true">
	 * 	<State> .. <State>
	 *	 <State> .. <State>
	 *    ..
	 * </WebStd:Sequence>
	 * the event "SetState" with parameter "pos" can be used to set the actual state position for a sequence *)
	Sequence* = OBJECT (DynamicWebpage.StateFullActiveElement)
		VAR
			stateCounter: LONGINT;

		PROCEDURE &Init*;
		BEGIN stateCounter := 0
		END Init;

		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		BEGIN RETURN elem
		END Transform;

		PROCEDURE PreTransform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR p: ANY; enum: XMLObjects.Enumerator; counter: LONGINT; state, actState: XML.Element;
			stateName: Strings.String; container: XML.Container; content: XML.Content; circularVal: Strings.String;
		BEGIN
			actState:= NIL; counter := 0;
			enum := elem.GetContents();
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				IF (p IS XML.Element) THEN
					state := p(XML.Element); stateName := state.GetName();
					IF ((stateName # NIL) & (stateName^ = "State")) THEN
						IF (stateCounter = counter) THEN
							actState := state
						END;
						INC(counter);
					END
				END
			END;

			INC(stateCounter);
			circularVal := elem.GetAttributeValue("circular");
			IF ((counter > 0) & (stateCounter >= counter)) THEN
				IF ((circularVal # NIL) & (circularVal^ = "true")) THEN
					stateCounter := stateCounter MOD counter
				ELSE
					stateCounter := counter-1
				END
			END;

			IF (actState # NIL) THEN
				NEW(container);
				enum := actState.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext(); content := p(XML.Content);
					container.AddContent(content)
				END;
				RETURN container
			ELSE (* end of the sequence was already reached *)
				RETURN NIL
			END
		END PreTransform;

		PROCEDURE SetState(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
	 		(* parameters "pos" *)
		VAR posStr: Strings.String;
	 	BEGIN
	 		posStr := params.GetParameterValueByName("pos");
	 		IF (posStr # NIL) THEN
		 		Strings.StrToInt(posStr^, stateCounter)
		 	ELSE
		 		KernelLog.String("WebStd:Sequence - event handler 'SetState' has parameter 'pos'.");
		 		KernelLog.Ln
		 	END
	 	END SetState;

    	PROCEDURE GetEventHandlers*() : DynamicWebpage.EventHandlerList;
		VAR list: DynamicWebpage.EventHandlerList;
		BEGIN
			NEW(list, 1);
			NEW(list[0], "SetState", SetState);
			RETURN list
		END GetEventHandlers;
	END Sequence;

	(** an equal comparison for two XML subforests in 'Arg1' and 'Arg2'.
	 * Returns 'true' iff the subforests are equal otherwise 'false'. Usage example:
	 *   <WebStd:IsEqual>
	 *      <Arg1></Arg1>
	 *      <Arg2></Arg2>
	 *   </WebStd:IsEqual> *)
	IsEqual* = OBJECT (DynamicWebpage.StateLessActiveElement)
		PROCEDURE Compare(arg1, arg2: XML.Content) : BOOLEAN;
		VAR chars1, chars2: XML.Chars; str1, str2: Strings.String; cref1, cref2: XML.CharReference;
			ncont1, ncont2: XML.NameContent; attr1, attr2: XML.Attribute; cont1, cont2: XML.Container;
			enum1, enum2: XMLObjects.Enumerator; p1, p2: ANY; content1, content2: XML.Content;
			elem1, elem2: XML.Element;
		BEGIN
			IF ((arg1 = NIL) OR (arg2 = NIL)) THEN
				RETURN arg1 = arg2
			ELSIF (arg1 IS XML.Chars) THEN
				IF (arg2 IS XML.Chars) THEN
					chars1 := arg1(XML.Chars); chars2 := arg2(XML.Chars);
					str1 := chars1.GetStr(); str2 := chars2.GetStr();
					IF ((str1 # NIL) & (str2 # NIL)) THEN
						RETURN str1^ = str2^
					ELSE
						RETURN str1 = str2
					END
				ELSE
					RETURN FALSE
				END
			ELSIF (arg1 IS XML.CharReference) THEN
				IF (arg2 IS XML.CharReference) THEN
					cref1 := arg1(XML.CharReference); cref2 := arg2(XML.CharReference);
					RETURN cref1.GetCode() = cref2.GetCode()
				ELSE
					RETURN FALSE
				END
			ELSIF (arg1 IS XML.NameContent) THEN
				IF (arg2 IS XML.NameContent) THEN
					ncont1 := arg1(XML.NameContent); ncont2 := arg2(XML.NameContent);
					str1 := ncont1.GetName(); str2 := ncont2.GetName();
					IF ((str1 = NIL) OR (str2 = NIL)) THEN
						IF (str1 # str2) THEN RETURN FALSE END
					ELSIF (str1^ # str2^) THEN
						RETURN FALSE
					END;
					IF (ncont1 IS XML.Attribute) THEN
						IF (ncont2 IS XML.Attribute) THEN
							attr1 := ncont1(XML.Attribute); attr2 := ncont2(XML.Attribute);
							str1 := attr1.GetValue(); str2 := attr2.GetValue();
							IF ((str1 # NIL) & (str2 # NIL)) THEN
								RETURN str1^ = str2^
							ELSE
								RETURN str1 = str2
							END
						ELSE
							RETURN FALSE
						END
					END;
					RETURN TRUE
				ELSE
					RETURN FALSE
				END
			ELSIF (arg1 IS XML.Container) THEN
				IF (arg2 IS XML.Container) THEN
					cont1 := arg1(XML.Container); cont2 := arg2(XML.Container);
					enum1 := cont1.GetContents(); enum2 := cont2.GetContents();
					WHILE ((enum1.HasMoreElements()) & (enum2.HasMoreElements())) DO
						p1 := enum1.GetNext(); p2 := enum2.GetNext();
						content1 := p1(XML.Content); content2 := p2(XML.Content);
						IF (~Compare(content1, content2)) THEN RETURN FALSE END
					END;
					IF ((enum1.HasMoreElements()) OR (enum2.HasMoreElements())) THEN RETURN FALSE END;
					IF (cont1 IS XML.Element) THEN
						IF (cont2 IS XML.Element) THEN
							elem1 := cont1(XML.Element); elem2 := cont2(XML.Element);
							str1 := elem1.GetName(); str2 := elem2.GetName();
							IF ((str1 # NIL) & (str2 # NIL)) THEN
								IF (str1^ # str2^) THEN RETURN FALSE END
							ELSE
								IF (str1 # str2) THEN RETURN FALSE END
							END;
							enum1 := elem1.GetAttributes(); enum2 := elem2.GetAttributes();
							WHILE ((enum1.HasMoreElements()) & (enum2.HasMoreElements())) DO
								p1 := enum1.GetNext(); p2 := enum2.GetNext();
								content1 := p1(XML.Content); content2 := p2(XML.Content);
								IF (~Compare(content1, content2)) THEN RETURN FALSE END
							END;
							IF ((enum1.HasMoreElements()) OR (enum2.HasMoreElements())) THEN RETURN FALSE END;
							RETURN TRUE
						ELSE
							RETURN FALSE
						END;
					END;
					RETURN TRUE
				ELSE
					RETURN FALSE
				END
			ELSE
				(* not supported *)
				RETURN FALSE
			END
		END Compare;

		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR arg1, arg2: XML.Element; enum1, enum2: XMLObjects.Enumerator; p1, p2: ANY; content1, content2: XML.Content;
		BEGIN
			arg1 := GetXMLSubElement(elem, "Arg1"); arg2 := GetXMLSubElement(elem, "Arg2");
			IF ((arg1 # NIL) & (arg2 # NIL)) THEN
				enum1 := arg1.GetContents(); enum2 := arg2.GetContents();
				WHILE ((enum1.HasMoreElements()) & (enum2.HasMoreElements())) DO
					p1 := enum1.GetNext(); p2 := enum2.GetNext();
					content1 := p1(XML.Content); content2 := p2(XML.Content);
					IF (~Compare(content1, content2)) THEN
						RETURN CreateXMLText("false")
					END
				END;
				IF ((enum1.HasMoreElements()) OR (enum2.HasMoreElements())) THEN
					RETURN CreateXMLText("false")
				END;
				RETURN CreateXMLText("true")
			ELSE
				RETURN CreateXMLText("WebStd:IsEqual: Missing 'Arg1' or 'Arg2' subelement")
			END
		END Transform;
	END IsEqual;

	(** returns 'true' if the content is 'false'. If the content is 'false' then it returns 'true'. Usage example
	 * The content could be the results of active elements like 'IsEqual'.
	 * <WebStd:Not>true|false</WebStd:Not> *)
	Not* = OBJECT(DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR str: Strings.String;
		BEGIN
			str := GetXMLCharContent(elem);
			IF ((str # NIL) & (str^ = "true")) THEN
				RETURN CreateXMLText("false")
			ELSIF ((str # NIL) & (str^ = "false")) THEN
				RETURN CreateXMLText("true")
			ELSE
				RETURN CreateXMLText("WebStd:Not - Content must be either 'true' or 'false'.")
			END
		END Transform;
	END Not;

	(** returns 'true' if both arguments 'Arg1' and 'Arg2' have content 'true'. If one of them has content 'false' the result will be
	 * 'false'. The contents could be the results of active elements like 'IsEqual'. Usage example:
	 * <WebStd:And>
	 *    <Arg1>true|false</Arg1>
	 *    <Arg2>true|false</Arg2>
	 * </WebStd:And> *)
	 And* = OBJECT(DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR arg1, arg2: XML.Element; str1, str2: Strings.String;
		BEGIN
			arg1 := GetXMLSubElement(elem, "Arg1");
			arg2 := GetXMLSubElement(elem, "Arg2");
			IF ((arg1 # NIL) & (arg2 # NIL)) THEN
				str1 := GetXMLCharContent(arg1);
				str2 := GetXMLCharContent(arg2);
				IF ((str1 # NIL) & (str1^ = "true") & (str2 # NIL) & (str2^ = "true")) THEN
					RETURN CreateXMLText("true")
				ELSIF ((str1 # NIL) & (str1^ = "true") & (str2 # NIL) & (str2^ = "false")) THEN
					RETURN CreateXMLText("false")
				ELSIF ((str1 # NIL) & (str1^ = "false") & (str2 # NIL) & (str2^ = "true")) THEN
					RETURN CreateXMLText("false")
				ELSIF ((str1 # NIL) & (str1^ = "false") & (str2 # NIL) & (str2^ = "false")) THEN
					RETURN CreateXMLText("false")
				ELSE
					RETURN CreateXMLText("WebStd:And - Content of 'Arg1' and 'Arg2' must be either 'true' or 'false'.")
				END
			ELSE
				RETURN CreateXMLText("WebStd:And - 'Arg1' or 'Arg2' subelements missing.")
			END
		END Transform;
	END And;

	(** returns 'true' if argument 'Arg1' or 'Arg2' (or both) has content 'true'. If both of them have content 'false'
	 *  the result will be 'false'. The contents could be the results of active elements like 'IsEqual'. Usage example:
	 * <WebStd:Or>
	 *    <Arg1>true|false</Arg1>
	 *    <Arg2>true|false</Arg2>
	 * </WebStd:Or> *)
	 Or* = OBJECT(DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR arg1, arg2: XML.Element; str1, str2: Strings.String;
		BEGIN
			arg1 := GetXMLSubElement(elem, "Arg1");
			arg2 := GetXMLSubElement(elem, "Arg2");
			IF ((arg1 # NIL) & (arg2 # NIL)) THEN
				str1 := GetXMLCharContent(arg1);
				str2 := GetXMLCharContent(arg2);
				IF ((str1 # NIL) & (str1^ = "false") & (str2 # NIL) & (str2^ = "false")) THEN
					RETURN CreateXMLText("false")
				ELSIF ((str1 # NIL) & (str1^ = "true") & (str2 # NIL) & (str2^ = "false")) THEN
					RETURN CreateXMLText("true")
				ELSIF ((str1 # NIL) & (str1^ = "false") & (str2 # NIL) & (str2^ = "true")) THEN
					RETURN CreateXMLText("true")
				ELSIF ((str1 # NIL) & (str1^ = "true") & (str2 # NIL) & (str2^ = "true")) THEN
					RETURN CreateXMLText("true")
				ELSE
					RETURN CreateXMLText("WebStd:Or - Content of 'Arg1' and 'Arg2' must be either 'true' or 'false'.")
				END
			ELSE
				RETURN CreateXMLText("WebStd:Or - 'Arg1' or 'Arg2' subelements missing.")
			END
		END Transform;
	END Or;

	(** returns 'true' if argument either 'Arg1' or 'Arg2' has content 'true'. If both of them have the same content 'true' or 'false'
	 *  the result will be 'false'. The contents could be the results of active elements like 'IsEqual'. Usage example:
	 * <WebStd:Xor>
	 *    <Arg1>true|false</Arg1>
	 *    <Arg2>true|false</Arg2>
	 * </WebStd:Xor> *)
	 Xor* = OBJECT(DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR arg1, arg2: XML.Element; str1, str2: Strings.String;
		BEGIN
			arg1 := GetXMLSubElement(elem, "Arg1");
			arg2 := GetXMLSubElement(elem, "Arg2");
			IF ((arg1 # NIL) & (arg2 # NIL)) THEN
				str1 := GetXMLCharContent(arg1);
				str2 := GetXMLCharContent(arg2);
				IF ((str1 # NIL) & (str1^ = "true") & (str2 # NIL) & (str2^ = "false")) THEN
					RETURN CreateXMLText("true")
				ELSIF ((str1 # NIL) & (str1^ = "false") & (str2 # NIL) & (str2^ = "true")) THEN
					RETURN CreateXMLText("true")
				ELSIF ((str1 # NIL) & (str1^ = "false") & (str2 # NIL) & (str2^ = "false")) THEN
					RETURN CreateXMLText("false")
				ELSIF ((str1 # NIL) & (str1^ = "true") & (str2 # NIL) & (str2^ = "true")) THEN
					RETURN CreateXMLText("false")
				ELSE
					RETURN CreateXMLText("WebStd:Xor - Content of 'Arg1' and 'Arg2' must be either 'true' or 'false'.")
				END
			ELSE
				RETURN CreateXMLText("WebStd:Xor - 'Arg1' or 'Arg2' subelements missing.")
			END
		END Transform;
	END Xor;

	(** a button that triggers a user event, usage example:
	 * EventButton can optionally have an attribute 'href' to specify another target page as the current one.
	 * If the target object is a statefull active element then 'objectid' has  to used to specify the instance.
	 *   <WebStd:EventButton label="ButtonLabel" method="invoke123" object="ObjABC" module="ModXYZ" objectid="myElem3">
	 *     <Param name="param1" value="val1"/>
	 *     <Param name="param2" value="val2"/>
	 *     ...
	 *  </WebStd:EventButton> *)
	EventButton* = OBJECT (DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR labelName, methodName, objectName, objectIdName, moduleName, elemName, paramName, paramValue,
			hrefString, sessionCounterStr: Strings.String; form, input, param: XML.Element; enum: XMLObjects.Enumerator;
			p: ANY; newParamName, encStr: ARRAY 128 OF CHAR; content: XML.Content; session: HTTPSession.Session;
			dynStr: DynamicStrings.DynamicString;
		BEGIN
			session := HTTPSession.GetSession(request); (* session # NIL *)

			labelName := elem.GetAttributeValue("label");
			methodName := elem.GetAttributeValue("method");
			objectName := elem.GetAttributeValue("object");
			objectIdName := elem.GetAttributeValue("objectid");
			moduleName := elem.GetAttributeValue("module");

			IF ((moduleName # NIL) & (methodName# NIL) & (objectName # NIL)) THEN

				NEW(form); form.SetName("form");
				form.SetAttributeValue("method", "POST");
				hrefString := elem.GetAttributeValue("href");
				IF (hrefString # NIL) THEN
					form.SetAttributeValue("action", hrefString^)
				ELSE
					form.SetAttributeValue("action", request.shortUri)
				END;

				NEW(input); input.SetName("input");
				input.SetAttributeValue("type", "hidden");
				input.SetAttributeValue("name", DynamicWebpage.HTTPVarCommandModule);
				input.SetAttributeValue("value", moduleName^);
				form.AddContent(input);

				NEW(input); input.SetName("input");
				input.SetAttributeValue("type", "hidden");
				input.SetAttributeValue("name", DynamicWebpage.HTTPVarCommandObject);
				input.SetAttributeValue("value", objectName^);
				form.AddContent(input);

				NEW(input); input.SetName("input");
				input.SetAttributeValue("type", "hidden");
				input.SetAttributeValue("name", DynamicWebpage.HTTPVarCommandMethod);
				input.SetAttributeValue("value", methodName^);
				form.AddContent(input);

				IF (objectIdName # NIL) THEN
					NEW(input); input.SetName("input");
					input.SetAttributeValue("type", "hidden");
					input.SetAttributeValue("name", DynamicWebpage.HTTPVarCommandObjectId);
					input.SetAttributeValue("value", objectIdName^);
					form.AddContent(input)
				END;

				enum := elem.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext();
					IF (p IS XML.Element) THEN
						param := p(XML.Element); elemName := param.GetName();
						IF ((elemName # NIL) & (elemName^ = "Param")) THEN
							paramName := param.GetAttributeValue("name");
							paramValue := param.GetAttributeValue("value");
							IF ((paramName # NIL) & (paramValue # NIL)) THEN
								HTTPSupport.HTTPEncode(paramName^, encStr);
								Strings.Concat(DynamicWebpage.HTTPVarCommandParamPrefix, encStr, newParamName);

								NEW(input); input.SetName("input");
								input.SetAttributeValue("type", "hidden");
								input.SetAttributeValue("name", newParamName);
								HTTPSupport.HTTPEncode(paramValue^, encStr);
								input.SetAttributeValue("value", encStr);
								form.AddContent(input)
							ELSE
								form.AddContent(param)
							END
						ELSE
							content := p(XML.Content); form.AddContent(content)
						END
					END
				END;

				NEW(input); input.SetName("input");
				input.SetAttributeValue("type", "hidden");
				input.SetAttributeValue("name", HTTPSession.HTTPVarSessionIdName);
				input.SetAttributeValue("value", session.sessionId);
				form.AddContent(input);

				p := session.GetVariableValue(DynamicWebpage.StateCounterVariable);
				IF ((p # NIL) & (p IS DynamicStrings.DynamicString)) THEN
					dynStr := p(DynamicStrings.DynamicString); sessionCounterStr := dynStr.ToArrOfChar(); (* sessionCounterStr # NIL *)
					NEW(input); input.SetName("input");
					input.SetAttributeValue("type", "hidden");
					input.SetAttributeValue("name", DynamicWebpage.StateCounterVariable);
					input.SetAttributeValue("value", sessionCounterStr^);
					form.AddContent(input)
				END;

				NEW(input); input.SetName("input");
				input.SetAttributeValue("type", "submit");
				IF (labelName # NIL) THEN
					input.SetAttributeValue("value", labelName^)
				END;
				form.AddContent(input);
				RETURN form
			ELSE
				RETURN CreateXMLText("Missing module, object or method name for WebStd:EventButton")
			END
		END Transform;
	END EventButton;

	(** a hyperlink that triggers a user event.
	 * EventLink can optionally have an attribute 'href' to specify another target page as the current one.
	 * If the target object is a statefull active element then 'objectid' is used to specify the instance.
	 * usage example:
	 *   <WebStd:EventLink method="invoke123" object="ObjABC" module="ModXYZ" objectId="myElem3">
	 *     <Label>text or image html code</Label>
	 *     <Param name="param1" value="val1"/>
	 *     <Param name="param2" value="val2"/>
	 *     ...
	 *  </WebStd:EventLink> *)
	EventLink* = OBJECT(DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR a: XML.Element; newUri: ARRAY 4096 OF CHAR; enum, labelEnum: XMLObjects.Enumerator;
			p, labelp: ANY; attr: XML.Attribute; content, labelContent: XML.Content;
			methodName, objectName, objectIdName, moduleName, attrName, subElemName, paramName, paramValue,
			hrefString, sessionCounterStr: Strings.String; encStr: ARRAY 128 OF CHAR; subElem: XML.Element;
			session: HTTPSession.Session; dynStr: DynamicStrings.DynamicString;
		BEGIN
			session := HTTPSession.GetSession(request);
			methodName := elem.GetAttributeValue("method");
			objectName := elem.GetAttributeValue("object");
			objectIdName := elem.GetAttributeValue("objectid");
			moduleName := elem.GetAttributeValue("module");

			IF ((moduleName # NIL) & (methodName# NIL) & (objectName # NIL)) THEN
				hrefString := elem.GetAttributeValue("href");
				IF (hrefString # NIL) THEN
					COPY(hrefString^, newUri);
					IF (Strings.Pos("?", hrefString^) = -1) THEN
						Strings.Append(newUri, "?")
					ELSE
						Strings.Append(newUri, "&")
					END
				ELSE
					Strings.Concat(request.shortUri, "?", newUri)
				END;
				Strings.Append(newUri, HTTPSession.HTTPVarSessionIdName);
				Strings.Append(newUri, "=");
				Strings.Append(newUri, session.sessionId);
				Strings.Append(newUri, "&");
				Strings.Append(newUri, DynamicWebpage.HTTPVarCommandModule);
				Strings.Append(newUri, "=");
				Strings.Append(newUri, moduleName^);
				Strings.Append(newUri, "&");
				Strings.Append(newUri, DynamicWebpage.HTTPVarCommandObject);
				Strings.Append(newUri, "=");
				Strings.Append(newUri, objectName^);
				Strings.Append(newUri, "&");
				Strings.Append(newUri, DynamicWebpage.HTTPVarCommandMethod);
				Strings.Append(newUri, "=");
				Strings.Append(newUri, methodName^);
				IF (objectIdName # NIL) THEN
					Strings.Append(newUri, "&");
					Strings.Append(newUri, DynamicWebpage.HTTPVarCommandObjectId);
					Strings.Append(newUri, "=");
					Strings.Append(newUri, objectIdName^)
				END;
				p := session.GetVariableValue(DynamicWebpage.StateCounterVariable);
				IF ((p # NIL) & (p IS DynamicStrings.DynamicString)) THEN
					dynStr := p(DynamicStrings.DynamicString); sessionCounterStr := dynStr.ToArrOfChar(); (* sessionCounterStr # NIL *)
					Strings.Append(newUri, "&");
					Strings.Append(newUri, DynamicWebpage.StateCounterVariable);
					Strings.Append(newUri, "=");
					Strings.Append(newUri, sessionCounterStr^)
				END;

				NEW(a); a.SetName("a");
				enum := elem.GetAttributes();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext(); attr := p(XML.Attribute);
					attrName := attr.GetName();
					IF ((attrName # NIL) & (attrName^ # "href") & (attrName^ # "method") & (attrName^ # "object") &
						(attrName^ # "objectid") & (attrName^ # "module") & (Strings.Pos("xmlns", attrName^) # 0)) THEN
						a.AddAttribute(attr)
					END
				END;

				enum := elem.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext(); content := p(XML.Content);
					IF (content IS XML.Element) THEN
						subElem := content(XML.Element); subElemName := subElem.GetName();
						IF (subElemName^ = "Param") THEN
							paramName := subElem.GetAttributeValue("name");
							paramValue := subElem.GetAttributeValue("value");
							IF ((paramName # NIL) & (paramValue # NIL)) THEN
								Strings.Append(newUri, "&");
								Strings.Append(newUri, DynamicWebpage.HTTPVarCommandParamPrefix);
								HTTPSupport.HTTPEncode(paramName^, encStr);
								Strings.Append(newUri, encStr);
								Strings.Append(newUri, "=");
								HTTPSupport.HTTPEncode(paramValue^, encStr);
								Strings.Append(newUri, encStr)
							END
						ELSIF ((subElemName # NIL) & (subElemName^ = "Label")) THEN
							labelEnum := subElem.GetContents();
							WHILE (labelEnum.HasMoreElements()) DO
								labelp := labelEnum.GetNext(); labelContent := labelp(XML.Content);
								a.AddContent(labelContent)
							END
						END
					END
				END;

				a.SetAttributeValue("href", newUri);
				RETURN a
			ELSE
				RETURN CreateXMLText("Missing module, object or method name for WebStd:EventLink")
			END
		END Transform;
	END EventLink;

	(** a formular that triggers a user event with parameters if submitted.
	 * transfer-method is HTTP POST.
	 * Formular can have an optionally attribute 'href' to specify another target page as the current one.
	 * If the target object is a statefull active element then 'objectid' has to used to specfiy the instance.
	 * usage example:
	 *   <WebStd:Formular method="invoke123" object="ObjABC" module="ModXYZ" objectid="myElem3">
	 *     ...
	 *     <input type="text" name="method-param1" value="val1"/>
	 *	 <textarea name="method-param3">hdsdaj</textarea>
	 *     <input type="password" name="method-param2" value="val2"/>
	 *    ...
	 *    <input type="submit" value="Submit"/>
	 *     ...
	 *  </WebStd:Formular> *)
	Formular* = OBJECT(DynamicWebpage.StateLessActiveElement)

		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR methodName, objectName, objectIdName, moduleName, attrName, hrefString, sessionCounterStr: Strings.String;
			session: HTTPSession.Session; form, input: XML.Element; enum: XMLObjects.Enumerator; p: ANY;
			content: XML.Content; attr: XML.Attribute; dynStr: DynamicStrings.DynamicString;
		BEGIN
			session := HTTPSession.GetSession(request); (* session # NIL *)
			methodName := elem.GetAttributeValue("method");
			objectName := elem.GetAttributeValue("object");
			objectIdName := elem.GetAttributeValue("objectid");
			moduleName := elem.GetAttributeValue("module");

			IF ((moduleName # NIL) & (methodName# NIL) & (objectName # NIL)) THEN

				NEW(form); form.SetName("form");
				form.SetAttributeValue("method", "post");
				hrefString := elem.GetAttributeValue("href");
				IF (hrefString # NIL) THEN
					form.SetAttributeValue("action", hrefString^)
				ELSE
					form.SetAttributeValue("action", request.shortUri)
				END;

				enum := elem.GetAttributes();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext(); attr := p(XML.Attribute);
					attrName := attr.GetName();
					IF ((attrName # NIL) & (attrName^ # "href") & (attrName^ # "method")) THEN
						form.AddAttribute(attr)
					END
				END;

				NEW(input); input.SetName("input");
				input.SetAttributeValue("type", "hidden");
				input.SetAttributeValue("name", DynamicWebpage.HTTPVarCommandModule);
				input.SetAttributeValue("value", moduleName^);
				form.AddContent(input);

				NEW(input); input.SetName("input");
				input.SetAttributeValue("type", "hidden");
				input.SetAttributeValue("name", DynamicWebpage.HTTPVarCommandObject);
				input.SetAttributeValue("value", objectName^);
				form.AddContent(input);

				NEW(input); input.SetName("input");
				input.SetAttributeValue("type", "hidden");
				input.SetAttributeValue("name", DynamicWebpage.HTTPVarCommandMethod);
				input.SetAttributeValue("value", methodName^);
				form.AddContent(input);

				IF (objectIdName # NIL) THEN
					NEW(input); input.SetName("input");
					input.SetAttributeValue("type", "hidden");
					input.SetAttributeValue("name", DynamicWebpage.HTTPVarCommandObjectId);
					input.SetAttributeValue("value", objectIdName^);
					form.AddContent(input)
				END;

				NEW(input); input.SetName("input");
				input.SetAttributeValue("type", "hidden");
				input.SetAttributeValue("name", HTTPSession.HTTPVarSessionIdName);
				input.SetAttributeValue("value", session.sessionId);
				form.AddContent(input);

				enum := elem.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext(); content := p(XML.Content);
					RenameInputAttr(content);
					form.AddContent(content)
				END;

				p := session.GetVariableValue(DynamicWebpage.StateCounterVariable);
				IF ((p # NIL) & (p IS DynamicStrings.DynamicString)) THEN
					dynStr := p(DynamicStrings.DynamicString); sessionCounterStr := dynStr.ToArrOfChar(); (* sessionCounterStr # NIL *)
					NEW(input); input.SetName("input");
					input.SetAttributeValue("type", "hidden");
					input.SetAttributeValue("name", DynamicWebpage.StateCounterVariable);
					input.SetAttributeValue("value", sessionCounterStr^);
					form.AddContent(input)
				END;

				RETURN form
			ELSE
				RETURN CreateXMLText("Missing module, object or method name for WebStd:Formular")
			END
		END Transform;

		(* rename 'name' attribute for <input>, <textarea>, <select> xhtml elements *)
		PROCEDURE RenameInputAttr(n: XML.Content);
		VAR elem: XML.Element; elemName, paramName: Strings.String; elemNameLow, newParamName, encStr: ARRAY 128 OF CHAR;
			paramNameAttr: XML.Attribute; enum: XMLObjects.Enumerator; container: XML.Container; p: ANY; content: XML.Content;
		BEGIN
			IF (n IS XML.Element) THEN
				elem := n(XML.Element); elemName := elem.GetName();
				IF (elemName # NIL) THEN
					COPY(elemName^, elemNameLow);
					Strings.LowerCase(elemNameLow);
					IF ((elemNameLow = "input") OR (elemNameLow = "textarea") OR (elemNameLow = "select")
						OR (elemNameLow = "submit")) THEN
						paramNameAttr := elem.GetAttribute("name"); (* attribute name 'name' must be lowercase *)
						IF (paramNameAttr # NIL) THEN
							paramName := paramNameAttr.GetValue();
							HTTPSupport.HTTPEncode(paramName^, encStr);
							Strings.Concat(DynamicWebpage.HTTPVarCommandParamPrefix, encStr, newParamName);
							paramNameAttr.SetValue(newParamName)
						END
					END
				END
			END;
			IF (n IS XML.Container) THEN
				container := n(XML.Container);
				enum := container.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext(); content := p(XML.Content);
					RenameInputAttr(content)
				END
			END
		END RenameInputAttr;

	END Formular;

	(** persistent data container support *)

	(** abstract web displayable persistent object *)
	PersistentDataObject *= OBJECT (PrevalenceSystem.PersistentObject)
		(** use oid instance field to identify persistent object *)
		PROCEDURE ToXML*(request: HTTPSupport.HTTPRequest) : XML.Content; (** the object specfifies its web representation *)
		BEGIN RETURN Externalize() (** use default xml serialization of the prevalence system *)
		END ToXML;
	END PersistentDataObject;

	PersistentDataObjectList* = POINTER TO ARRAY OF PersistentDataObject;

	(** has to return true iff obj is selected *)
	PersistentDataFilter* = PROCEDURE {DELEGATE} (obj: PersistentDataObject) : BOOLEAN;

	(** has to return true iff obj1 < obj2 in the order *)
	PersistentDataCompare* = PROCEDURE {DELEGATE} (obj1, obj2: PersistentDataObject): BOOLEAN;

	(** persistent data container *)
	PersistentDataContainer*= OBJECT (PersistentDataObject)
		VAR
			name: Strings.String;
			dataObjList: TFClasses.List; (* List of PersistentDataObject *)

		PROCEDURE &Create*;
		BEGIN
			Init; (* call superconstructor *)
			NEW(dataObjList);
		END Create;

		PROCEDURE GetName*() : Strings.String;
		BEGIN RETURN name
		END GetName;

		PROCEDURE SetName*(n: ARRAY OF CHAR); (** the name must be unique for all instances of PersistentDataContainer *)
		VAR oldName: Strings.String; resultList: PrevalenceSystem.PersistentObjectList;
		BEGIN
			ASSERT(LEN(n) > 0, 9999);
			BeginModification;
			oldName := name;
			NEW(name, LEN(n));
			COPY(n, name^);
			IF (registeredAt # NIL) THEN
				(* check name uniqueness contraint *)
				resultList := registeredAt.FindPersistentObjects(FilterContainerByName);
				IF (resultList # NIL) THEN
					KernelLog.String("WebStd.PersistentDataContainer: name '"); KernelLog.String(name^);
					KernelLog.String("' must be unique for all instances of PersistentDataContainer."); KernelLog.Ln;
					name := oldName; (* rollback *)
					EndModification;
					HALT(9999)
				END;
			END;
			EndModification
		END SetName;

		(** returns NIL iff not present in this container *)
		PROCEDURE GetObjectByOid*(objectId: LONGINT) : PersistentDataObject;
		VAR i: SIZE; p: ANY; obj: PersistentDataObject;
		BEGIN
			dataObjList.Lock;
			FOR i := 0 TO dataObjList.GetCount()-1 DO
				p := dataObjList.GetItem(i); obj := p(PersistentDataObject); (* obj # NIL & obj.oid # 0 since it was registered in prevalence system*)
				IF (obj.oid = objectId) THEN
					dataObjList.Unlock;
					RETURN obj
				END
			END;
			dataObjList.Unlock;
			RETURN NIL
		END GetObjectByOid;

		PROCEDURE GetCount*() : SIZE;
		BEGIN RETURN dataObjList.GetCount()
		END GetCount;

		PROCEDURE GetItem*(i: SIZE) : PersistentDataObject;
		VAR p: ANY; obj: PersistentDataObject;
		BEGIN
			IF ((i >= 0) & (i < dataObjList.GetCount())) THEN
				p := dataObjList.GetItem(i); obj := p(PersistentDataObject);
				RETURN obj
			ELSE
				RETURN NIL
			END
		END GetItem;

		(** returns a list of filtered persistent data objects entries, if filter = NIL THEN no filter is applied. persComp defines the
		  * ordering of the list and can be NIL *)
		PROCEDURE GetElementList*(filter: PersistentDataFilter; persComp: PersistentDataCompare) : PersistentDataObjectList;
		VAR i: SIZE; filteredList: TFClasses.List; persList: PersistentDataObjectList; p: ANY; obj: PersistentDataObject;
			genArray: GenericSort.GenericArray; persSorter: PersistentDataSorter;
		BEGIN
			NEW (filteredList);
			IF (filter = NIL) THEN filter := DefaultPersistentDataFilter END;
			dataObjList.Lock;
			FOR i := 0 TO dataObjList.GetCount()-1 DO
				p := dataObjList.GetItem(i); obj := p(PersistentDataObject); (* obj # NIL & obj.oid # 0 since it was registered in prevalence system*)
				IF (filter(obj)) THEN
					filteredList.Add(obj)
				END
			END;
			dataObjList.Unlock;
			IF (filteredList.GetCount() > 0) THEN
				NEW(genArray, filteredList.GetCount());
				FOR i := 0 TO filteredList.GetCount()-1 DO
					genArray[i] :=  filteredList.GetItem(i)
				END;
				IF (persComp # NIL) THEN
					NEW(persSorter, persComp);
					GenericSort.QuickSort(genArray, persSorter.GenericCompare)
				END;
				NEW(persList, LEN(genArray));
				FOR i := 0 TO LEN(genArray)-1 DO
					persList[i] := genArray[i](PersistentDataObject)
				END;
				RETURN persList
			ELSE
				RETURN NIL
			END
		END GetElementList;

		PROCEDURE AddPersistentDataObject*(obj: PersistentDataObject; desc: PrevalenceSystem.PersistentObjectDescriptor);
		BEGIN
			IF (obj # NIL) THEN
				IF (~Contains(obj)) THEN
					BeginModification;
					dataObjList.Add(obj);
					IF (registeredAt # NIL) THEN
						registeredAt.AddPersistentObject(obj, desc);
					END;
					EndModification
					(* make sure that the object is registered in the prevalence system *)
					(* the object must be added to the prevalence system after there is a reference from a persistent object to it
						 * otherwise it could be already collected from the garbage collection mechanism of the prevalence system *)
				END;
			END
		END AddPersistentDataObject;

		PROCEDURE Contains*(obj: PersistentDataObject) : BOOLEAN;
		VAR p: ANY; i: SIZE;
		BEGIN
			dataObjList.Lock;
			FOR i := 0 TO dataObjList.GetCount()-1 DO
				p := dataObjList.GetItem(i);
				IF (p = obj) THEN
					dataObjList.Unlock;
					RETURN TRUE
				END
			END;
			dataObjList.Unlock;
			RETURN FALSE
		END Contains;

		PROCEDURE RemovePersistentDataObject*(obj: PersistentDataObject);
		BEGIN
			IF (obj # NIL) THEN
				BeginModification;
				dataObjList.Remove(obj);
				(* the object will automatically and safely removed by the garbage collector of the prevalence system *)
				EndModification
			END
		END RemovePersistentDataObject;

		PROCEDURE FilterContainerByName(obj: PrevalenceSystem.PersistentObject) : BOOLEAN;
		VAR c: PersistentDataContainer; n: Strings.String;
		BEGIN
			IF ((obj IS PersistentDataContainer) & (obj # SELF)) THEN
				c := obj(PersistentDataContainer); n := c.GetName();
				IF ((n # NIL) & (n^ = name^)) THEN
					RETURN TRUE
				END
			END;
			RETURN FALSE
		END FilterContainerByName;

		PROCEDURE Externalize*() : XML.Content;
		VAR elem: XML.Element; i: SIZE; p: ANY; obj: PersistentDataObject; container: XML.Container;
			oidString: ARRAY 14 OF CHAR;
		BEGIN
			NEW(container);

			IF (name # NIL) THEN
				NEW(elem); elem.SetName("name");
				AppendXMLContent(elem, CreateXMLText(name^));
				container.AddContent(elem)
			END;

			dataObjList.Lock;
			FOR i := 0 TO dataObjList.GetCount()-1 DO
				p := dataObjList.GetItem(i); obj := p(PersistentDataObject); (* obj # NIL & obj.oid # 0 since it was registered in prevalence system*)
				Strings.IntToStr(obj.oid, oidString);
				NEW(elem); elem.SetName("elem"); elem.SetAttributeValue("ref", oidString);
				container.AddContent(elem)
			END;
			dataObjList.Unlock;
			RETURN container
		END Externalize;

		PROCEDURE Internalize*(xml: XML.Content);
		VAR container: XML.Container; elem: XML.Element; enumContainer: XMLObjects.Enumerator; p: ANY;
		BEGIN
			dataObjList.Clear; (* ! *)
			IF (xml # NIL) THEN
				IF (xml IS XML.Element) THEN
					elem := xml(XML.Element);
					InternalizeElem(elem)
				ELSE
					container := xml(XML.Container);
					enumContainer := container.GetContents();
					WHILE(enumContainer.HasMoreElements()) DO
						p := enumContainer.GetNext();
						IF (p IS XML.Element) THEN
							elem := p(XML.Element);
							InternalizeElem(elem)
						END
					END
				END
			END
		END Internalize;

		PROCEDURE InternalizeElem(elem: XML.Element);
		VAR elemLabel, refStr: Strings.String; ref: LONGINT; persObj: PrevalenceSystem.PersistentObject;
		BEGIN
			elemLabel := elem.GetName();
			IF (elemLabel^ = "name") THEN
				name := GetXMLCharContent(elem)
			ELSIF (elemLabel^ = "elem") THEN
				refStr := elem.GetAttributeValue("ref");
				IF (refStr # NIL) THEN
					Strings.StrToInt(refStr^, ref);
					IF (registeredAt # NIL) THEN
						persObj := registeredAt.GetPersistentObject(ref);
						(* this is possible because of the recovery algorithm of the prevalence system *)
						IF ((persObj # NIL) & (persObj IS PersistentDataObject)) THEN
							dataObjList.Add(persObj)
						ELSE
							HALT(9999)
						END
					ELSE
						HALT(9999) (* object must be registered in at least one prevalence system *)
					END
				END
			END
		END InternalizeElem;

		PROCEDURE GetReferrencedObjects*() : PrevalenceSystem.PersistentObjectList;
		VAR list: PrevalenceSystem.PersistentObjectList; i: SIZE; pers: PrevalenceSystem.PersistentObject; p: ANY;
		BEGIN
			IF (dataObjList.GetCount() > 0) THEN
				NEW(list, dataObjList.GetCount());
				dataObjList.Lock;
				FOR i := 0 TO dataObjList.GetCount()-1 DO
					p := dataObjList.GetItem(i); pers := p(PrevalenceSystem.PersistentObject);
					list[i] := pers
				END;
				dataObjList.Unlock;
				RETURN list
			ELSE
				RETURN NIL
			END
		END GetReferrencedObjects;

		PROCEDURE ToXML*(request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR elem: XML.Element; i: SIZE; p: ANY; obj: PersistentDataObject; container: XML.Container;
			nameText: XML.ArrayChars; oidString, posString: ARRAY 14 OF CHAR; objSer: XML.Content;
			persList: PersistentDataObjectList;
		BEGIN
			NEW(container);

			IF (name # NIL) THEN
				NEW(elem); elem.SetName("name");
				NEW(nameText); nameText.SetStr(name^);
				elem.AddContent(nameText);
				container.AddContent(elem)
			END;

			dataObjList.Lock;
			persList := GetElementList(DefaultPersistentDataFilter, NIL);
			FOR i := 0 TO dataObjList.GetCount()-1 DO
				p := dataObjList.GetItem(i); obj := p(PersistentDataObject); (* obj # NIL & obj.oid # 0 since it was registered in prevalence system*)
				Strings.IntToStr(obj.oid, oidString);
				Strings.IntToStr(i, posString);
				NEW(elem); elem.SetName("Elem");
				elem.SetAttributeValue("pos", posString);
				elem.SetAttributeValue("ref", oidString);
				(* here would be an exception handler fine *)
				objSer := obj.ToXML(request);
				AppendXMLContent(elem, objSer);
				container.AddContent(elem)
			END;
			dataObjList.Unlock;
			RETURN container
		END ToXML;
	END PersistentDataContainer;

	(* helper object to wrap the generic compare function *)
	PersistentDataSorter = OBJECT
		VAR
			comp: PersistentDataCompare;

		PROCEDURE &Init*(persComp: PersistentDataCompare);
		BEGIN (* persComp # NIL *)
			comp := persComp
		END Init;

		PROCEDURE GenericCompare(obj1, obj2: ANY): BOOLEAN;
		VAR persO1, persO2: PersistentDataObject;
		BEGIN
			persO1 := obj1(PersistentDataObject); persO2 := obj2(PersistentDataObject);
			RETURN comp(persO1, persO2)
		END GenericCompare;
	END PersistentDataSorter;

	(** a stateless data container active element which represents the access to a PersistentDataContainer
	 * of the prevalence system optionally specified. if 'prevalencesystem' is not present then the
	 * standardPrevalenceSystem will be used. The container name has to be globally unique in the corresponding
	 * prevalence system to allow global access to the persistent data container.
	 * usage example:
	 *   <WebStd:DataContainer name="Persons" prevalencesystem="standardPrevalenceSystem"/> *)
    DataContainer* = OBJECT (DynamicWebpage.StateLessActiveElement)

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR errStr: ARRAY 256 OF CHAR; persCont: PersistentDataContainer; prevSys: PrevalenceSystem.PrevalenceSystem;
			containerName, prevSysName: Strings.String;
		BEGIN
			containerName := input.GetAttributeValue("name");
			prevSysName := input.GetAttributeValue("prevalencesystem");
			IF (prevSys # NIL) THEN
				prevSys := PrevalenceSystem.GetPrevalenceSystem(prevSysName^)
			ELSE
				prevSys := PrevalenceSystem.standardPrevalenceSystem;
			END;
			IF ((containerName # NIL) & (prevSys # NIL)) THEN
				persCont := GetPersistentDataContainer(prevSys, containerName^);
				IF (persCont # NIL) THEN
					RETURN persCont.ToXML(request)
				ELSE
					COPY("WebStd:DataContainer with name '", errStr); Strings.Append(errStr, containerName^);
					Strings.Append(errStr, "' is not present in the prevalence system.");
					RETURN CreateXMLText(errStr)
				END
			ELSIF (containerName = NIL) THEN
				RETURN CreateXMLText("Missing attribute name for WebStd:DataContainer")
			ELSE
				RETURN CreateXMLText("Specified prevalence system is not present")
			END
		END Transform;
	END DataContainer;

	(** session container support *)

	(** abstract web displayable object with session bounded lifetime *)
	SessionDataObject* = OBJECT
		VAR oid*: LONGINT; (** unique object id *)

		PROCEDURE &Init*;
		BEGIN
			oid := GetNewOid()
		END Init;

		PROCEDURE ToXML*(request: HTTPSupport.HTTPRequest) : XML.Content;
		BEGIN HALT(309)
		END ToXML;
	END SessionDataObject;

	SessionDataObjectList* = POINTER TO ARRAY OF SessionDataObject;

	(** has to return true iff obj is selected *)
	SessionDataFilter* = PROCEDURE {DELEGATE} (obj: SessionDataObject) : BOOLEAN;

	(** has to return true iff obj1 < obj2 in the order *)
	SessionDataCompare* = PROCEDURE {DELEGATE} (obj1, obj2: SessionDataObject): BOOLEAN;

	(** session data container *)
	SessionDataContainer* = OBJECT (SessionDataObject)
		VAR
			name: Strings.String;
			dataObjList: TFClasses.List; (* List of SessionDataObject *)

		PROCEDURE &Create*(containerName: ARRAY OF CHAR);
		BEGIN
			NEW(dataObjList);
			NEW(name, LEN(containerName)); COPY(containerName, name^)
		END Create;

		PROCEDURE GetName*() : Strings.String;
		BEGIN RETURN name
		END GetName;

		(** returns NIL iff not present in this container *)
		PROCEDURE GetObjectByOid*(objectId: LONGINT) : SessionDataObject;
		VAR i: SIZE; p: ANY; obj: SessionDataObject;
		BEGIN
			dataObjList.Lock;
			FOR i := 0 TO dataObjList.GetCount()-1 DO
				p := dataObjList.GetItem(i); obj := p(SessionDataObject);
				IF (obj.oid = objectId) THEN
					dataObjList.Unlock;
					RETURN obj
				END
			END;
			dataObjList.Unlock;
			RETURN NIL
		END GetObjectByOid;

		PROCEDURE GetCount*() : SIZE;
		BEGIN RETURN dataObjList.GetCount()
		END GetCount;

		PROCEDURE GetItem*(i: SIZE) : SessionDataObject;
		VAR p: ANY; obj: SessionDataObject;
		BEGIN
			IF ((i >= 0) & (i < dataObjList.GetCount())) THEN
				p := dataObjList.GetItem(i); obj := p(SessionDataObject);
				RETURN obj
			ELSE
				RETURN NIL
			END
		END GetItem;

		(** returns a list of filtered session data objects entries, if filter = NIL THEN no filter is applied.  sessComp defines the
			ordering of the list and can be NIL *)
		PROCEDURE GetElementList*(filter: SessionDataFilter; sessComp: SessionDataCompare) : SessionDataObjectList;
		VAR i: SIZE; filteredList: TFClasses.List; sessList: SessionDataObjectList; p: ANY; obj: SessionDataObject;
			genArray: GenericSort.GenericArray; sessSorter: SessionDataSorter;
		BEGIN
			NEW (filteredList);
			IF (filter = NIL) THEN filter := DefaultSessionDataFilter END;
			dataObjList.Lock;
			FOR i := 0 TO dataObjList.GetCount()-1 DO
				p := dataObjList.GetItem(i); obj := p(SessionDataObject); (* obj # NIL & obj.oid # 0 since it was registered in prevalence system*)
				IF (filter(obj)) THEN
					filteredList.Add(obj)
				END
			END;
			dataObjList.Unlock;
			IF (filteredList.GetCount() > 0) THEN
				NEW(genArray, filteredList.GetCount());
				FOR i := 0 TO filteredList.GetCount()-1 DO
					genArray[i] :=  filteredList.GetItem(i)
				END;
				IF (sessComp # NIL) THEN
					NEW(sessSorter, sessComp);
					GenericSort.QuickSort(genArray, sessSorter.GenericCompare)
				END;
				NEW(sessList, LEN(genArray));
				FOR i := 0 TO LEN(genArray)-1 DO
					sessList[i] := genArray[i](SessionDataObject)
				END;
				RETURN sessList
			ELSE
				RETURN NIL
			END
		END GetElementList;

		PROCEDURE AddSessionDataObject*(obj: SessionDataObject);
		BEGIN
			IF (obj # NIL) THEN
				IF (obj.oid = 0) THEN obj.oid := GetNewOid() END; (* set unique oid if not initialized *)
				dataObjList.Add(obj)
			END
		END AddSessionDataObject;

		PROCEDURE Contains*(obj: SessionDataObject) : BOOLEAN;
		VAR p: ANY; i: SIZE;
		BEGIN
			dataObjList.Lock;
			FOR i := 0 TO dataObjList.GetCount()-1 DO
				p := dataObjList.GetItem(i);
				IF (p = obj) THEN
					dataObjList.Unlock;
					RETURN TRUE
				END
			END;
			dataObjList.Unlock;
			RETURN FALSE
		END Contains;

		PROCEDURE RemoveSessionDataObject*(obj: SessionDataObject);
		BEGIN
			IF (obj # NIL) THEN
				dataObjList.Remove(obj)
			END
		END RemoveSessionDataObject;

		PROCEDURE ToXML*(request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR elem: XML.Element; i: SIZE; p: ANY; obj: SessionDataObject; container: XML.Container;
			nameText: XML.ArrayChars; objSer: XML.Content; posString, oidString: ARRAY 14 OF CHAR;
		BEGIN
			NEW(container);

			IF (name # NIL) THEN
				NEW(elem); elem.SetName("name");
				NEW(nameText); nameText.SetStr(name^);
				elem.AddContent(nameText);
				container.AddContent(elem)
			END;

			dataObjList.Lock;
			FOR i := 0 TO dataObjList.GetCount()-1 DO
				p := dataObjList.GetItem(i); obj := p(SessionDataObject); (* obj # NIL *)
				Strings.IntToStr(obj.oid, oidString);
				Strings.IntToStr(i, posString);
				(* here would be an exception handler fine *)
				objSer := obj.ToXML(request);
				NEW(elem); elem.SetName("Elem");
				elem.SetAttributeValue("pos", posString);
				elem.SetAttributeValue("ref", oidString);
				AppendXMLContent(elem, objSer);
				container.AddContent(elem)
			END;
			dataObjList.Unlock;
			RETURN container
		END ToXML;

	END SessionDataContainer;

	(* helper object to wrap the generic compare function *)
	SessionDataSorter = OBJECT
		VAR
			comp: SessionDataCompare;

		PROCEDURE &Init*(sessComp: SessionDataCompare);
		BEGIN (* sessComp # NIL *)
			comp := sessComp
		END Init;

		PROCEDURE GenericCompare(obj1, obj2: ANY): BOOLEAN;
		VAR sessO1, sessO2: SessionDataObject;
		BEGIN
			sessO1 := obj1(SessionDataObject); sessO2 := obj2(SessionDataObject);
			RETURN comp(sessO1, sessO2)
		END GenericCompare;
	END SessionDataSorter;

	(** a session container active element which represents the access to a SessionDataContainer
	 * the name has to globally unique for a session to allow global access to the session data container for the session
	 * usage example:
	 *   <WebStd:SessionContainer name="Persons"/> *)
	SessionContainer* = OBJECT (DynamicWebpage.StateLessActiveElement)
		(* the container is stored in the session object, hence the SessionContainer can be stateless *)
		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR errStr: ARRAY 128 OF CHAR; sessionCont: SessionDataContainer; containerName: Strings.String;
			session: HTTPSession.Session;
		BEGIN
			containerName := input.GetAttributeValue("name");
			IF (containerName # NIL) THEN
				session := HTTPSession.GetSession(request);
				sessionCont := GetSessionDataContainer(session, containerName^);
				IF (sessionCont # NIL) THEN
					RETURN sessionCont.ToXML(request)
				ELSE
					COPY("WebStd:SessionContainer:  The session variable with name '", errStr);
					Strings.Append(errStr, containerName^);
					Strings.Append(errStr, "' is already used by another non session container object .");
					RETURN CreateXMLText(errStr)
				END
			ELSE
				RETURN CreateXMLText("Missing attribute name for WebStd:DataContainer")
			END
		END Transform;
	END SessionContainer;

	(** simple datagrid statefull active element with paging, usage example:
	 * <WebStd:Datagrid id="mygrid3">
	 *   <Header>...</Header>
	 *   <Data>
	 *	  <WebStd:SessionContainer name="persons"/>
	 *       or
	 *      <WebStd:DataContainer name="employees"/>
	 *       or
	 *      <Elem ..> ... </Elem>
	 *	  <Elem ..> ... </Elem>
	 *      ...
	 *   </Data>
	 *   <Footer>..</Footer>
	 *   <Paging size="10" nextlabel="more.." previouslabel="..back"/>
	 * </WebStd:Datagrid>
	 * will transform into:
	 * <table>
	 *   <tr> header-content </tr>
	 *   <tr> 1.st data element </tr>
	 *   <tr> 2.nd data element </tr>
	 *   ...
	 *   <tr> 10.th data element </tr>
	 *   <tr><td colspan=""><WebStd:EventButton label="back..." ../><WebStd:EventButton label="more.."/></td></tr>
	 *   <tr> footer content </tr>
	 * </table>
	 *)
	Datagrid* = OBJECT (DynamicWebpage.StateFullActiveElement)
		VAR
			pos: LONGINT; (* statefull instance variable: start position for paging *)

		PROCEDURE &Init*;
		BEGIN
			pos := 0
		END Init;

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR table, tr, td, tdHeader, data, header, footer, elem, paging, subElem, eventButton, eventParam: XML.Element; p, pElem: ANY;
			content: XML.Content; gridEnum, elemEnum, enum: XMLObjects.Enumerator; elemName, pagingSizeStr,
			subElemName, labelName, objectId: Strings.String; columns, pagingSize, counter, k: LONGINT;
			colString, posString: ARRAY 14 OF CHAR;
		BEGIN
			objectId := input.GetAttributeValue(DynamicWebpage.XMLAttributeObjectIdName);
			(* objectId # NIL by DynamicWebpagePlugin logic*)

			gridEnum := input.GetContents();
			WHILE (gridEnum.HasMoreElements()) DO (* faster than 4 invocations of GetXMLSubElement(input) *)
				p := gridEnum.GetNext();
				IF (p IS XML.Element) THEN
					subElem := p(XML.Element); elemName := subElem.GetName();
					IF ((subElem # NIL) & (elemName^ = "Header")) THEN
						header := subElem
					ELSIF ((subElem # NIL) & (elemName^ = "Data")) THEN
						data := subElem
					ELSIF ((subElem # NIL) & (elemName^ = "Footer")) THEN
						footer := subElem
					ELSIF ((subElem # NIL) & (elemName^ = "Paging")) THEN
						paging := subElem
					END
				END
			END;
			NEW(table); table.SetName("table");
			IF (header # NIL) THEN
				NEW(tr); tr.SetName("tr");
				NEW(tdHeader); tdHeader.SetName("td");  (* set "colspan" attribute later if the #columns is known *)
				enum := header.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext(); content := p(XML.Content);
					tdHeader.AddContent(content)
				END;
				tr.AddContent(tdHeader);
				table.AddContent(tr)
			END;
			IF (paging # NIL) THEN
				pagingSizeStr := paging.GetAttributeValue("size");
				IF (pagingSizeStr # NIL) THEN
					Strings.StrToInt(pagingSizeStr^, pagingSize)
				ELSE
					pagingSize := MAX(LONGINT)
				END
			END;

			columns := 1;
			IF (data # NIL) THEN
				counter := 0;
				elemEnum := data.GetContents();
				WHILE ((elemEnum.HasMoreElements()) & (counter < pos + pagingSize)) DO
					pElem := elemEnum.GetNext();
					IF (pElem IS XML.Element) THEN
						elem := pElem(XML.Element); elemName := elem.GetName();
						IF ((elemName # NIL) & (elemName^ = "Elem")) THEN
							IF (counter >= pos) THEN
								NEW(tr); tr.SetName("tr");
								enum := elem.GetContents();
								k := 0; (* # columns *)
								WHILE (enum.HasMoreElements()) DO
									p := enum.GetNext(); content := p(XML.Content);
									(* count columns *)
									IF (content IS XML.Element) THEN
										subElem := content(XML.Element); subElemName := subElem.GetName();
										IF ((subElemName # NIL) & (subElemName^ = "td")) THEN (* 'td' must be lowercase *)
											INC(k)
										END
									END;
									tr.AddContent(content)
								END;
								table.AddContent(tr);
								IF (k > columns) THEN columns := k END
							END;
							enum := elem.GetContents();
							IF (enum.HasMoreElements()) THEN INC(counter) END
						END
					END
				END;
				IF ((paging # NIL) & ((pos > 0) OR (elemEnum.HasMoreElements()))) THEN (* previous or next button needed *)
					NEW(tr); tr.SetName("tr");
					Strings.IntToStr(columns-1, colString);

					NEW(td); td.SetName("td");
					tr.AddContent(td);
					IF (pos > 0) THEN (* previous button *)
						labelName := paging.GetAttributeValue("previouslabel");
						Strings.IntToStr(pos-pagingSize, posString);

						NEW(eventButton); eventButton.SetName("WebStd:EventButton");
						eventButton.SetAttributeValue("xmlns:WebStd", "WebStd");
						IF (labelName # NIL) THEN
							eventButton.SetAttributeValue("label", labelName^)
						ELSE
							eventButton.SetAttributeValue("label", "back")
						END;
						eventButton.SetAttributeValue("method", "SetPos");
						eventButton.SetAttributeValue("object", "Datagrid");
						eventButton.SetAttributeValue("module", "WebStd");
						eventButton.SetAttributeValue("objectid", objectId^);

						NEW(eventParam); eventParam.SetName("Param");
						eventParam.SetAttributeValue("name", "pos");
						eventParam.SetAttributeValue("value", posString);
						eventButton.AddContent(eventParam);
						td.AddContent(eventButton)
					ELSE
						AppendXMLContent(td, CreateXMLText(" "));
					END;

					NEW(td); td.SetName("td"); td.SetAttributeValue("colspan", colString);
					tr.AddContent(td);
					IF (elemEnum.HasMoreElements()) THEN (* next button *)
						labelName := paging.GetAttributeValue("nextlabel");
						Strings.IntToStr(pos+pagingSize, posString);

						NEW(eventButton); eventButton.SetName("WebStd:EventButton");
						eventButton.SetAttributeValue("xmlns:WebStd", "WebStd");
						IF (labelName # NIL) THEN
							eventButton.SetAttributeValue("label", labelName^)
						ELSE
							eventButton.SetAttributeValue("label", "back")
						END;
						eventButton.SetAttributeValue("method", "SetPos");
						eventButton.SetAttributeValue("object", "Datagrid");
						eventButton.SetAttributeValue("module", "WebStd");
						eventButton.SetAttributeValue("objectid", objectId^);

						NEW(eventParam); eventParam.SetName("Param");
						eventParam.SetAttributeValue("name", "pos");
						eventParam.SetAttributeValue("value", posString);
						eventButton.AddContent(eventParam);
						td.AddContent(eventButton)
					ELSE
						AppendXMLContent(td, CreateXMLText(" "));
					END;
					table.AddContent(tr)
				END
			END;

			Strings.IntToStr(columns, colString);
			IF (header # NIL) THEN (* set colspan for the header row *)
				tdHeader.SetAttributeValue("colspan", colString)
			END;
			IF (footer # NIL) THEN
				NEW(tr); tr.SetName("tr");
				NEW(td); td.SetName("td"); td.SetAttributeValue("colspan", colString);
				enum := footer.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext(); content := p(XML.Content);
					td.AddContent(content)
				END;
				tr.AddContent(td);
				table.AddContent(tr)
			END;

			RETURN table
		END Transform;

		PROCEDURE SetPos(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
			(* parameters: "pos" *)
		VAR posString: Strings.String;
		BEGIN
			posString := params.GetParameterValueByName("pos");
			IF (posString # NIL) THEN
				Strings.StrToInt(posString^, pos)
			ELSE
				KernelLog.String("WebStd:Datagrid - event handler 'SetPos' has parameter 'pos'.");
				KernelLog.Ln
			END
		END SetPos;

		PROCEDURE GetEventHandlers*() : DynamicWebpage.EventHandlerList;
		VAR list: DynamicWebpage.EventHandlerList;
		BEGIN
			NEW(list, 1);
			NEW(list[0], "SetPos", SetPos);
			RETURN list
		END GetEventHandlers;

	END Datagrid;

	(** statefull active element to allow toggling between two states. The state ('Show' or 'Hide') specified by 'startWith' is
	 * the initial state. The default initial state is 'Show' if 'startWith' is not specified. Usage example
	 * <WebStd:ToggleBlock id="MyToggleBlock3" startWith="Show" showLabel="show" hideLabel="hide">
	 *   <Show>...</Show>
	 *   <Hide>...</Hide>
	 * <WebStd:ToogleBlock>
	 *)
	ToggleBlock* = OBJECT(DynamicWebpage.StateFullActiveElement)
		VAR
			isShowing: BOOLEAN; (* true iff in show state *)
			firstAccess: BOOLEAN; (* is true if the active element will be the first time transformed for its incarnation *)
		PROCEDURE &Init*;
		BEGIN isShowing := TRUE; firstAccess := TRUE
		END Init;

		PROCEDURE PreTransform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR pTag, label, eventLink, show, hide: XML.Element; container: XML.Container;
			showLabel, hideLabel, objectId, startWith: Strings.String;
		BEGIN
			IF (firstAccess) THEN
				firstAccess := FALSE;
				startWith := elem.GetAttributeValue("startWith");
				IF (startWith # NIL) THEN
					IF (startWith^ = "Hide") THEN isShowing := FALSE
					ELSIF (startWith^ # "Show") THEN
						RETURN CreateXMLText("WebStd:ToggleBlock - Attribute value for 'startWith' must be either 'Show' or 'Hide'")
					END
				END
			END;
			objectId := elem.GetAttributeValue(DynamicWebpage.XMLAttributeObjectIdName); (* objectId # NIL *)
			showLabel := elem.GetAttributeValue("showLabel");
			hideLabel := elem.GetAttributeValue("hideLabel");
			show := GetXMLSubElement(elem, "Show");
			hide := GetXMLSubElement(elem, "Hide");

			NEW(container);
			NEW(pTag); pTag.SetName("p"); container.AddContent(pTag);

			NEW(eventLink); eventLink.SetName("WebStd:EventLink");
			eventLink.SetAttributeValue("xmlns:WebStd", "WebStd");

			NEW(label); label.SetName("Label");
			eventLink.AddContent(label);
			IF (isShowing) THEN
				IF (hideLabel # NIL) THEN
					AppendXMLContent(label, CreateXMLText(hideLabel^))
				ELSE
					AppendXMLContent(label, CreateXMLText("hide"))
				END;
				eventLink.SetAttributeValue("method", "Hide");
			ELSE
				IF (showLabel # NIL) THEN
					AppendXMLContent(label, CreateXMLText(showLabel^))
				ELSE
					AppendXMLContent(label, CreateXMLText("show"))
				END;
				eventLink.SetAttributeValue("method", "Show");
			END;
			eventLink.SetAttributeValue("object", "ToggleBlock");
			eventLink.SetAttributeValue("module", "WebStd");
			eventLink.SetAttributeValue("objectid", objectId^);
			pTag.AddContent(eventLink);

			IF (isShowing) THEN
				CopyXMLSubContents(show, container)
			ELSE
				CopyXMLSubContents(hide, container)
			END;
			RETURN container
		END PreTransform;

		PROCEDURE Show(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		BEGIN isShowing := TRUE
		END Show;

		PROCEDURE Hide(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		BEGIN isShowing := FALSE
		END Hide;

		PROCEDURE GetEventHandlers*() : DynamicWebpage.EventHandlerList;
		VAR list: DynamicWebpage.EventHandlerList;
		BEGIN
			NEW(list, 2);
			NEW(list[0], "Show", Show);
			NEW(list[1], "Hide", Hide);
			RETURN list
		END GetEventHandlers;

	END ToggleBlock;

	(* persistent counter to store the visiting information *)
	PersistentCounter = OBJECT(PrevalenceSystem.PersistentObject)
		VAR
			name: Strings.String;
			counter: LONGINT;

		PROCEDURE &Initialize*;
		BEGIN
			Init; name := NIL; counter := 0
		END Initialize;

		PROCEDURE IncreaseCounter;
		BEGIN
			BeginModification;
			INC(counter);
			EndModification
		END IncreaseCounter;

		PROCEDURE Internalize*(xml: XML.Content);
		VAR container: XML.Container;
		BEGIN
			container := xml(XML.Container);
			name := InternalizeString(container, "Name");
			counter := InternalizeInteger(container, "Counter")
		END Internalize;

		PROCEDURE Externalize*() : XML.Content;
		VAR container: XML.Container;
		BEGIN
			NEW(container);
			ExternalizeString(name, container, "Name");
			ExternalizeInteger(counter, container, "Counter");
			RETURN container
		END Externalize;
	END PersistentCounter;

	(** a visitor counter uniquely specified by 'name'. Returns the number of different sessions having visited this counter.
	 * Usage example:
	 *  <WebStd:VisitorCounter name="MyVisits"/> *)
	VisitorCounter* = OBJECT(DynamicWebpage.StateLessActiveElement)

		VAR
			counterName: Strings.String;
			nameLock: BOOLEAN;

		PROCEDURE &Init*;
		BEGIN nameLock := FALSE
		END Init;

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR name: Strings.String; persCounter: PersistentCounter; numberStr: ARRAY 14 OF CHAR;
			session: HTTPSession.Session; p: ANY; dynVarName, dynVarValue: DynamicStrings.DynamicString;
			varName: Strings.String;
		BEGIN
			name := input.GetAttributeValue("name");
			IF (name # NIL) THEN
				persCounter := GetCounterByName(name^); (* persCounter # NIL *)

				NEW(dynVarName); Concat(dynVarName, SessionVisitorCounterPrefix);
				dynVarName.Append(name^);
				varName := dynVarName.ToArrOfChar(); (* varName # NIL *)

				session := HTTPSession.GetSession(request); (* session # NIL *)
				p := session.GetVariableValue(varName^);
				IF (p = NIL) THEN (* increase counter only once for each session *)
					NEW(dynVarValue); dynVarValue.Append(name^);
					session.AddVariableValue(varName^, dynVarValue);
					persCounter.IncreaseCounter
				END;
				Strings.IntToStr(persCounter.counter, numberStr);
				RETURN CreateXMLText(numberStr)
			ELSE
				RETURN CreateXMLText("WebStd:VisitorCounter - missing attribute 'name'")
			END
		END Transform;

		PROCEDURE LockName;
		BEGIN {EXCLUSIVE}
			AWAIT (~nameLock); nameLock := TRUE
		END LockName;

		PROCEDURE UnlockName;
		BEGIN {EXCLUSIVE}
			nameLock := FALSE
		END UnlockName;

		PROCEDURE FilterPersistentCounter(obj: PrevalenceSystem.PersistentObject) : BOOLEAN;
		VAR persCounter: PersistentCounter;
		BEGIN (* obj # NIL & counterName # NIL *)
			IF (obj IS PersistentCounter) THEN
				persCounter := obj(PersistentCounter);
				RETURN ((persCounter.name # NIL) & (persCounter.name^ = counterName^))
			ELSE
				RETURN FALSE
			END
		END FilterPersistentCounter;

		PROCEDURE GetCounterByName(name: ARRAY OF CHAR) : PersistentCounter;
		VAR list: PrevalenceSystem.PersistentObjectList; persCounter: PersistentCounter;
		BEGIN
			LockName;
			counterName := GetString(name); (* counterName # NIL *)
			list := PrevalenceSystem.FindPersistentObjects(FilterPersistentCounter);
			IF (list = NIL) THEN
				(* create a new persistent counter *)
				NEW(persCounter); persCounter.name := counterName;
				PrevalenceSystem.AddPersistentObjectToRootSet(persCounter, persistentCounterDesc)
			ELSE
				persCounter := list[0](PersistentCounter) (* persCounter # NIL *)
			END;
			UnlockName;
			RETURN persCounter
		END GetCounterByName;

	END VisitorCounter;

	PtrDateTime* = POINTER TO Dates.DateTime;

	VAR
		persistentDataContainerDesc*: PrevalenceSystem.PersistentObjectDescriptor; (** descriptor for PersistentDataContainer *)
		persistentCounterDesc: PrevalenceSystem.PersistentObjectDescriptor; (** descriptor for PersistentCounter *)
		tempContainerName: Strings.String;  (* used temporary for the prevalence system filter predicate FilterPersistentDataContainer *)
		qlock: BOOLEAN; (* locking for persistent object querying becuase of tempContainerName *)
		oidCounter: LONGINT; (* counter for unique oid among all SessionDataObject *)

	(** usefull XML-DOM operations *)

	(** returns the first XML subelement with name 'name' as child of 'parent' *)
	PROCEDURE GetXMLSubElement*(parent: XML.Container; name: ARRAY OF CHAR) : XML.Element;
	BEGIN
		RETURN GetXMLSubElementByIndex(parent, name, 0)
	END GetXMLSubElement;

	(** returns the number of XML subelements with name 'name' as child of 'parent' *)
	PROCEDURE NofXMLSubElements*(parent: XML.Container; name: ARRAY OF CHAR) : LONGINT;
	VAR enum: XMLObjects.Enumerator; p: ANY; elem: XML.Element; elemName: Strings.String; counter: LONGINT;
	BEGIN
		counter := 0;
		IF (parent # NIL) THEN
			enum := parent.GetContents();
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				IF (p IS XML.Element) THEN
					elem := p(XML.Element); elemName := elem.GetName();
					IF ((elemName # NIL) & (elemName^ = name)) THEN
						INC(counter)
					END
				END
			END
		END;
		RETURN counter
	END NofXMLSubElements;

	(** returns the 'index'.th XML subelement with name 'name' as child of 'parent' *)
	PROCEDURE GetXMLSubElementByIndex*(parent: XML.Container; name: ARRAY OF CHAR; index: LONGINT) : XML.Element;
	VAR enum: XMLObjects.Enumerator; p: ANY; elem: XML.Element; elemName: Strings.String; counter: LONGINT;
	BEGIN
		counter := 0;
		IF (parent # NIL) THEN
			enum := parent.GetContents();
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				IF (p IS XML.Element) THEN
					elem := p(XML.Element); elemName := elem.GetName();
					IF ((elemName # NIL) & (elemName^ = name)) THEN
						IF (index = counter) THEN RETURN elem END;
						INC(counter)
					END
				END
			END
		END;
		RETURN NIL
	END GetXMLSubElementByIndex;

	(** return first character content of an XML container *)
	PROCEDURE GetXMLCharContent*(parent: XML.Container) : Strings.String;
	VAR enum: XMLObjects.Enumerator; p: ANY; chars: XML.Chars; ent: XML.EntityRef;
		dynStr: DynamicStrings.DynamicString; text, name: Strings.String;
		decl: XML.EntityDecl; charRef: XML.CharReference; ch: ARRAY 2 OF CHAR;
	BEGIN
		IF (parent # NIL) THEN
			NEW(dynStr);
			enum := parent.GetContents();
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				IF (p IS XML.CharReference) THEN
					charRef := p(XML.CharReference);
					ch[0] := CHR(charRef.GetCode()); dynStr.Append(ch)
				ELSIF (p IS XML.Chars) THEN
					chars := p(XML.Chars);
					text := chars.GetStr();
					IF (text # NIL) THEN
						(* ! XML.Element::Write does insert a CRLF at the end of the opening element name *)
						Strings.Trim(text^, DynamicStrings.CR);
						Strings.Trim(text^, DynamicStrings.LF);
						Strings.Trim(text^, DynamicStrings.CR);
						dynStr.Append(text^)
					END
				ELSIF (p IS XML.EntityRef) THEN
					ent := p(XML.EntityRef);
					name := ent.GetName(); decl := ent.GetEntityDecl();
					IF (decl # NIL) THEN
						text := decl.GetValue();
						IF (text # NIL) THEN
							dynStr.Append(text^)
						END
					ELSIF (name # NIL) THEN
						IF (name^ = "lt") THEN
							COPY("<", ch); dynStr.Append(ch)
						ELSIF (name^ = "gt") THEN
							COPY(">", ch); dynStr.Append(ch)
						ELSIF (name^ = "amp") THEN
							COPY("&", ch); dynStr.Append(ch)
						ELSIF (name^ = "apos") THEN
							COPY("'", ch); dynStr.Append(ch)
						ELSIF (name^ = "quot") THEN
							COPY('"', ch); dynStr.Append(ch)
						ELSIF (name^ = "nbsp") THEN
							COPY(" ", ch); dynStr.Append(ch)
						ELSE
							KernelLog.String("GetXMLCharContent: Unknown XML.EntityRef with name '");
							KernelLog.String(name^); KernelLog.String("'"); KernelLog.Ln
						END
					ELSE
						KernelLog.String("GetXMLCharContent: Unknown XML.EntityRef with name NIL"); KernelLog.Ln
					END
				END
			END;
			IF (dynStr.Length() > 0) THEN
				RETURN dynStr.ToArrOfChar()
			END
		END;
		RETURN NIL
	END GetXMLCharContent;

	PROCEDURE SpecialCharacter(c: CHAR) : BOOLEAN;
	BEGIN (* ? < > & " are illegal characters *)
		RETURN (c = "?") OR (c = "<") OR (c = ">") OR (c = "&") OR (c =  '"')
	END SpecialCharacter;

	(** create an xml text as XML.ArrayChars and XML.EntityRef *)
	PROCEDURE CreateXMLText*(text: ARRAY OF CHAR) : XML.Container;
	VAR cont: XML.Container; chars: XML.ArrayChars; ent: XML.EntityRef; charRef: XML.CharReference; pos, at: LONGINT;
		dynStr: DynamicStrings.DynamicString; str: Strings.String;ch: ARRAY 6 OF CHAR;
	BEGIN
		NEW(cont);
		pos := 0;
		WHILE (pos < Strings.Length(text)) DO
			NEW(dynStr); at := 0;
			WHILE((pos < Strings.Length(text)) & (~SpecialCharacter(text[pos]))) DO
				dynStr.Put(text[pos], at); INC(pos); INC(at);
			END;
			IF (at > 0) THEN
				str := dynStr.ToArrOfChar();
				NEW(chars); chars.SetStr(str^); cont.AddContent(chars)
			END;
			WHILE ((pos < Strings.Length(text)) & (SpecialCharacter(text[pos]))) DO
				ch[0] := 0X;
				CASE text[pos] OF
					"<": NEW(ent); COPY("lt", ch); ent.SetName(ch); cont.AddContent(ent)
				|  ">": NEW(ent); COPY("gt", ch); ent.SetName(ch); cont.AddContent(ent)
				|  "&": NEW(ent); COPY("amp", ch); ent.SetName(ch); cont.AddContent(ent)
				|  '"': NEW(ent); COPY("quot", ch); ent.SetName(ch); cont.AddContent(ent)
				ELSE NEW(charRef); charRef.SetCode(ORD(text[pos])); cont.AddContent(charRef)
				END;
				INC(pos)
			END
		END;
		RETURN cont
	END CreateXMLText;

	(** create attribute value text with encoded special charcters *)
	PROCEDURE GetEncXMLAttributeText*(text: ARRAY OF CHAR): Strings.String;
	VAR i: SIZE; dynStr: DynamicStrings.DynamicString; chs: ARRAY 8 OF CHAR;
		str: Strings.String;
	BEGIN
		NEW(dynStr);
		FOR i := 0 TO Strings.Length(text)-1 DO
			CASE text[i] OF
			   "<": COPY("&lt;", chs)
			| ">": COPY("&gt;", chs)
			| "&": COPY("&amp;", chs)
			| '"': COPY("&quot;", chs)
			ELSE chs[0] := text[i]; chs[1] := 0X
			END;
			dynStr.Append(chs)
		END;
		str := dynStr.ToArrOfChar();
		RETURN str
	END GetEncXMLAttributeText;

	(** create xml text with <br/> tags for CR *)
	PROCEDURE CreateXMLTextWithBR*(text: ARRAY OF CHAR) : XML.Container;
	VAR cont: XML.Container; chars: XML.ArrayChars; ent: XML.EntityRef; charRef: XML.CharReference; pos, at: LONGINT;
		dynStr: DynamicStrings.DynamicString; str: Strings.String;ch: ARRAY 6 OF CHAR;
		br: XML.Element;
	BEGIN
		NEW(cont);
		pos := 0;
		WHILE (pos < Strings.Length(text)) DO
			NEW(dynStr); at := 0;
			WHILE((pos < Strings.Length(text)) & (~SpecialCharacter(text[pos]) & (text[pos] # CHR(13)))) DO
				IF (text[pos] # CHR(10)) THEN
					dynStr.Put(text[pos], at); INC(at)
				END;
				INC(pos);
			END;
			IF (at > 0) THEN
				str := dynStr.ToArrOfChar();
				NEW(chars); chars.SetStr(str^); cont.AddContent(chars)
			END;
			WHILE ((pos < Strings.Length(text)) & ((SpecialCharacter(text[pos]) OR (text[pos] = CHR(13)))))DO
				ch[0] := 0X;
				CASE text[pos] OF
					CHR(13): NEW(br); br.SetName("br"); cont.AddContent(br)
				|  "<": NEW(ent); COPY("lt", ch); ent.SetName(ch); cont.AddContent(ent)
				|  ">": NEW(ent); COPY("gt", ch); ent.SetName(ch); cont.AddContent(ent)
				|  "&": NEW(ent); COPY("amp", ch); ent.SetName(ch); cont.AddContent(ent)
				|  '"': NEW(ent); COPY("quot", ch); ent.SetName(ch); cont.AddContent(ent)
				ELSE NEW(charRef); charRef.SetCode(ORD(text[pos])); cont.AddContent(charRef)
				END;
				INC(pos)
			END
		END;
		RETURN cont
	END CreateXMLTextWithBR;

	(** append the content 'appendix' to 'container' by avoiding nested XML containers *)
	PROCEDURE AppendXMLContent*(container: XML.Container; appendix: XML.Content);
	VAR subCont: XML.Container; enum: XMLObjects.Enumerator; pSub: ANY; content: XML.Content;
	BEGIN
		IF (appendix # NIL) THEN
			IF ((appendix IS XML.Container) & (~(appendix IS XML.Element))) THEN (* avoid nested containers *)
				subCont := appendix(XML.Container);
				enum := subCont.GetContents();
				WHILE (enum.HasMoreElements()) DO
					pSub := enum.GetNext(); content := pSub(XML.Content);
					AppendXMLContent(container, content)
				END
			ELSE
				container.AddContent(appendix)
			END
		END
	END AppendXMLContent;

	(** copy the contents of 'from' to 'to' by avoiding nested XML containers *)
	PROCEDURE CopyXMLSubContents*(from, to: XML.Container);
	VAR enum: XMLObjects.Enumerator; pSub: ANY; content: XML.Content;
	BEGIN
		IF ((from # NIL) & (to # NIL)) THEN
			enum := from.GetContents();
			WHILE (enum.HasMoreElements()) DO
				pSub := enum.GetNext(); content := pSub(XML.Content);
				AppendXMLContent(to, content)
			END
		END
	END CopyXMLSubContents;

	PROCEDURE Concat(dynStr: DynamicStrings.DynamicString; appendix: ARRAY OF CHAR);
	VAR appStr: Strings.String;
	BEGIN
		appStr := GetString(appendix);
		dynStr.Append(appStr^)
	END Concat;

	PROCEDURE GetString*(text: ARRAY OF CHAR): Strings.String;
	VAR str: Strings.String;
	BEGIN
		NEW(str, Strings.Length(text)+1); COPY(text, str^); RETURN str
	END GetString;

	(** format 'day month year hour minute second" no check for validity *)
	PROCEDURE StrToDateTime*(str: ARRAY OF CHAR; VAR dt: Dates.DateTime);
	VAR i: SIZE;
		PROCEDURE GoToNextBlock;
		BEGIN
			WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END
		END GoToNextBlock;
	BEGIN
		i := 0;
		GoToNextBlock;
		Strings.StrToIntPos(str, dt.day, i);
		GoToNextBlock;
		Strings.StrToIntPos(str, dt.month, i);
		GoToNextBlock;
		Strings.StrToIntPos(str, dt.year, i);
		GoToNextBlock;
		Strings.StrToIntPos(str, dt.hour, i);
		GoToNextBlock;
		Strings.StrToIntPos(str, dt.minute, i);
		GoToNextBlock;
		Strings.StrToIntPos(str, dt.second, i)
	END StrToDateTime;

	(** date time to string by DateTimeFormat in CONST block *)
	PROCEDURE DateTimeToStr*(VAR dt: Dates.DateTime) : Strings.String;
	VAR dateStr: ARRAY 40 OF CHAR;
	BEGIN
		Strings.FormatDateTime(DateTimeFormat, dt, dateStr);
		RETURN GetString(dateStr)
	END DateTimeToStr;

	(** get the actual date time as a string *)
	PROCEDURE GetNowDateTimeAsStr*() : Strings.String;
	VAR dateStr: ARRAY 40 OF CHAR;
	BEGIN
		Strings.FormatDateTime(DateTimeFormat, Dates.Now(), dateStr);
		RETURN GetString(dateStr)
	END GetNowDateTimeAsStr;

	(** return true if date time 'a' is strictly earlier than 'b' *)
	PROCEDURE CompareDateTime*(VAR a, b: Dates.DateTime) : BOOLEAN;
	BEGIN
		IF (a.year # b.year) THEN RETURN a.year > b.year END;
		IF (a.month # b.month) THEN RETURN a.month > b.month END;
		IF (a.day # b.day) THEN RETURN a.day > b.day END;
		IF (a.hour # b.hour) THEN RETURN a.hour > b.hour END;
		IF (a.minute # b.minute) THEN RETURN a.minute > b.minute END;
		RETURN a.second > b.second
	END CompareDateTime;

	(** usefull operations for the internalization and externalization process *)
		(** return the internalized string in XML element named 'elementName' from 'container', result is NIL if not present *)
	PROCEDURE InternalizeString*(container: XML.Container; elementName: ARRAY OF CHAR) : Strings.String;
	VAR elem: XML.Element; str: Strings.String;
	BEGIN
		elem := GetXMLSubElement(container, elementName);
		IF (elem # NIL) THEN
			str := GetXMLCharContent(elem)
		ELSE
			str := NIL
		END;
		RETURN str
	END InternalizeString;

	(** return the internalized date time in XML element named 'elementName' from 'container', result is NIL if not present *)
	PROCEDURE InternalizeDateTime*(container: XML.Container; elementName: ARRAY OF CHAR) : PtrDateTime;
	VAR elem: XML.Element; dateTimeStr: Strings.String; dateTime: PtrDateTime;
	BEGIN
		elem := GetXMLSubElement(container, elementName);
		IF (elem # NIL) THEN
			dateTimeStr := GetXMLCharContent(elem);
			IF (dateTimeStr # NIL) THEN
				NEW(dateTime); StrToDateTime(dateTimeStr^, dateTime^)
			END
		ELSE
			dateTime := NIL
		END;
		RETURN dateTime
	END InternalizeDateTime;

	(** return the internalized LONGINT in XML element named 'elementName' from 'container', result is 0 if not present *)
	PROCEDURE InternalizeInteger*(container: XML.Container; elementName: ARRAY OF CHAR) : LONGINT;
	VAR elem: XML.Element; intStr: Strings.String; number: LONGINT;
	BEGIN
		number := 0;
		elem := GetXMLSubElement(container, elementName);
		IF (elem # NIL) THEN
			intStr := GetXMLCharContent(elem);
			IF (intStr # NIL) THEN
				Strings.StrToInt(intStr^, number)
			END
		END;
		RETURN number
	END InternalizeInteger;

	(** return the internalized BOOLEAN in XML element named 'elementName' from 'container', result is FALSE if not present *)
	PROCEDURE InternalizeBoolean*(container: XML.Container; elementName: ARRAY OF CHAR) : BOOLEAN;
	VAR elem: XML.Element; boolStr: Strings.String; boolVal: BOOLEAN;
	BEGIN
		boolVal := FALSE;
		elem := GetXMLSubElement(container, elementName);
		IF (elem # NIL) THEN
			boolStr := GetXMLCharContent(elem);
			IF ((boolStr # NIL) & (boolStr^ = "true")) THEN
				boolVal := TRUE
			END
		END;
		RETURN boolVal
	END InternalizeBoolean;

	(** externlize string 'str' to 'container' with XML element named 'elementName'. 'str' could be NIL *)
	PROCEDURE ExternalizeString*(str: Strings.String; container: XML.Container; elementName: ARRAY OF CHAR);
	VAR elem: XML.Element;
	BEGIN
		IF (str # NIL) THEN
			NEW(elem); elem.SetName(elementName);
			AppendXMLContent(elem, CreateXMLText(str^));
			container.AddContent(elem)
		END
	END ExternalizeString;

	(** externlize dateTime 'dateTime' to 'container' with XML element named 'elementName'. 'dateTime' could be NIL *)
	PROCEDURE ExternalizeDateTime*(dateTime: PtrDateTime; container: XML.Container; elementName: ARRAY OF CHAR);
	VAR elem: XML.Element; dateTimeStr: Strings.String;
	BEGIN
		IF (dateTime # NIL) THEN
			NEW(elem); elem.SetName(elementName);
			dateTimeStr := DateTimeToStr(dateTime^);
			AppendXMLContent(elem, CreateXMLText(dateTimeStr^));
			container.AddContent(elem)
		END;
	END ExternalizeDateTime;

	(** externalize LONGINT 'number' to 'container' with XML element named 'elementName'. *)
	PROCEDURE ExternalizeInteger*(number: HUGEINT; container: XML.Container; elementName: ARRAY OF CHAR);
	VAR elem: XML.Element; intStr: ARRAY 14 OF CHAR;
	BEGIN
		Strings.IntToStr(number, intStr);
		NEW(elem); elem.SetName(elementName);
		AppendXMLContent(elem, CreateXMLText(intStr));
		container.AddContent(elem);
	END ExternalizeInteger;

	(** externalize BOOLEAN 'boolVal' to 'container' with XML element named 'elementName'. *)
	PROCEDURE ExternalizeBoolean*(boolVal: BOOLEAN; container: XML.Container; elementName: ARRAY OF CHAR);
	VAR elem: XML.Element; boolStr: Strings.String;
	BEGIN
		IF (boolVal) THEN
			boolStr := GetString("true")
		ELSE
			boolStr := GetString("false")
		END;
		NEW(elem); elem.SetName(elementName);
		AppendXMLContent(elem, CreateXMLText(boolStr^));
		container.AddContent(elem);
	END ExternalizeBoolean;

	PROCEDURE DefaultPersistentDataFilter*(obj: PersistentDataObject) : BOOLEAN;
	BEGIN RETURN TRUE
	END DefaultPersistentDataFilter;

	PROCEDURE DefaultSessionDataFilter*(obj: SessionDataObject) : BOOLEAN;
	BEGIN RETURN TRUE
	END DefaultSessionDataFilter;

	(** get an existing session data container, if not present create a new one, return NIL if the session variable is
	    already used for another purpose *)
	PROCEDURE GetSessionDataContainer*(session: HTTPSession.Session; name: ARRAY OF CHAR) : SessionDataContainer;
	VAR dynVarName: DynamicStrings.DynamicString; varName: Strings.String; p: ANY;
		sessionCont: SessionDataContainer;
	BEGIN (** session # NIL *)
		NEW(dynVarName); Concat(dynVarName, SessionContainerNamePrefix);
		dynVarName.Append(name);
		varName := dynVarName.ToArrOfChar();
		p := session.GetVariableValue(varName^);
		IF ((p # NIL) & (p IS SessionDataContainer)) THEN
			sessionCont := p(SessionDataContainer);
			RETURN sessionCont
		ELSIF (p = NIL) THEN
			(* create new session container *)
			NEW(sessionCont, name);
			session.AddVariableValue(varName^, sessionCont);
			RETURN sessionCont
		END;
		KernelLog.String("WebStd:SessionDataContainer: Warning - The reserved prefix '");
		KernelLog.String(SessionContainerNamePrefix); KernelLog.String("' should not be used for session variables.");
		KernelLog.Ln;
		RETURN NIL
	END GetSessionDataContainer;

	(** find an existing session data container, if not present then return NIL, return NIL if the session variable is
	    already used for another purpose *)
	PROCEDURE FindSessionDataContainer*(session: HTTPSession.Session; name: ARRAY OF CHAR) : SessionDataContainer;
	VAR dynVarName: DynamicStrings.DynamicString; varName: Strings.String; p: ANY;
		sessionCont: SessionDataContainer;
	BEGIN (** session # NIL *)
		NEW(dynVarName); Concat(dynVarName, SessionContainerNamePrefix);
		dynVarName.Append(name);
		varName := dynVarName.ToArrOfChar();
		p := session.GetVariableValue(varName^);
		IF ((p # NIL) & (p IS SessionDataContainer)) THEN
			sessionCont := p(SessionDataContainer);
			RETURN sessionCont
		ELSIF (p = NIL) THEN
			RETURN NIL
		END;
		KernelLog.String("WebStd:SessionDataContainer: Warning - The reserved prefix '");
		KernelLog.String(SessionContainerNamePrefix); KernelLog.String("' should not be used for session variables.");
		KernelLog.Ln;
		RETURN NIL
	END FindSessionDataContainer;

	(** get an existing persistent data container, if not present create a new one. if prevSys is NIL then the
	 * standard prevalence system is used *)
	PROCEDURE GetPersistentDataContainer*(prevSys: PrevalenceSystem.PrevalenceSystem;
		name: ARRAY OF CHAR) : PersistentDataContainer;
	VAR resultList: PrevalenceSystem.PersistentObjectList; cont: PersistentDataContainer;
	BEGIN
		IF (prevSys = NIL) THEN
			prevSys := PrevalenceSystem.standardPrevalenceSystem
		END;

		QueryLock;
		tempContainerName := GetString(name);
		resultList := prevSys.FindPersistentObjects(FilterPersistentDataContainer);
		IF (resultList # NIL) THEN
			cont := resultList[0](PersistentDataContainer);
			QueryUnlock;
			RETURN cont
		END;
		(* create new persistent data container *)
		NEW(cont); prevSys.AddPersistentObjectToRootSet(cont, persistentDataContainerDesc);
		cont.SetName(name);
		QueryUnlock;
		RETURN cont
	END GetPersistentDataContainer;

	(** find an existing persistent data container, if not present then return NIL. if prevSys is NIL then the
	 * standard prevalence system is used *)
	PROCEDURE FindPersistentDataContainer*(prevSys: PrevalenceSystem.PrevalenceSystem;
		name: ARRAY OF CHAR) : PersistentDataContainer;
	VAR resultList: PrevalenceSystem.PersistentObjectList; cont: PersistentDataContainer;
	BEGIN
		IF (prevSys = NIL) THEN
			prevSys := PrevalenceSystem.standardPrevalenceSystem
		END;

		QueryLock;
		tempContainerName := GetString(name);
		resultList := prevSys.FindPersistentObjects(FilterPersistentDataContainer);
		IF (resultList # NIL) THEN
			cont := resultList[0](PersistentDataContainer);
			QueryUnlock;
			RETURN cont
		END;
		QueryUnlock;
		RETURN NIL
	END FindPersistentDataContainer;

	PROCEDURE FilterPersistentDataContainer(obj: PrevalenceSystem.PersistentObject) : BOOLEAN;
	VAR pers: PersistentDataContainer; n: Strings.String;
	BEGIN
		IF (obj IS PersistentDataContainer) THEN
			pers := obj(PersistentDataContainer);
			n := pers.GetName();
			IF ((n # NIL) & (n^ = tempContainerName^)) THEN
				RETURN TRUE
			END
		END;
		RETURN FALSE
	END FilterPersistentDataContainer;

	(* true iff href is a link to another webserver then 'host' *)
	PROCEDURE IsExternalHyperlink(href: ARRAY OF CHAR; host: ARRAY OF CHAR) : BOOLEAN;
	BEGIN
		Strings.LowerCase(href); Strings.LowerCase(host);
		IF (Strings.Pos("://", href) > 0) THEN
			RETURN ~((Strings.Pos("http://", href) = 0) & (Strings.Pos(host, href) = Strings.Length("http://")))
		ELSE
			RETURN FALSE
		END
	END IsExternalHyperlink;

	PROCEDURE QueryLock;
	BEGIN {EXCLUSIVE}
		AWAIT(~qlock);
		qlock := TRUE
	END QueryLock;

	PROCEDURE QueryUnlock;
	BEGIN {EXCLUSIVE}
		qlock := FALSE
	END QueryUnlock;

	PROCEDURE GetNewOid(): LONGINT;
	BEGIN  INC(oidCounter); RETURN oidCounter
	END GetNewOid;

	PROCEDURE CreateHyperlinkElement() : DynamicWebpage.ActiveElement;
	VAR obj: Hyperlink;
	BEGIN
		NEW(obj); RETURN obj
	END CreateHyperlinkElement;

	PROCEDURE CreateEventButtonElement() : DynamicWebpage.ActiveElement;
	VAR obj: EventButton;
	BEGIN
		NEW(obj); RETURN obj
	END CreateEventButtonElement;

	PROCEDURE CreateEventLinkElement() : DynamicWebpage.ActiveElement;
	VAR obj: EventLink;
	BEGIN
		NEW(obj); RETURN obj
	END CreateEventLinkElement;

	PROCEDURE CreateFormularElement() : DynamicWebpage.ActiveElement;
	VAR obj: Formular;
	BEGIN
		NEW(obj); RETURN obj
	END CreateFormularElement;

	PROCEDURE CreateDataContainerElement() : DynamicWebpage.ActiveElement;
	VAR obj: DataContainer;
	BEGIN
		NEW(obj); RETURN obj
	END CreateDataContainerElement;

	PROCEDURE CreateSessionContainerElement() : DynamicWebpage.ActiveElement;
	VAR obj: SessionContainer;
	BEGIN
		NEW(obj); RETURN obj
	END CreateSessionContainerElement;

	PROCEDURE CreateDatagridElement() : DynamicWebpage.ActiveElement;
	VAR obj: Datagrid;
	BEGIN
		NEW(obj); RETURN obj
	END CreateDatagridElement;

	PROCEDURE CreateGetHeaderFieldElement() : DynamicWebpage.ActiveElement;
	VAR obj: GetHeaderField;
	BEGIN
		NEW(obj); RETURN obj
	END CreateGetHeaderFieldElement;

	PROCEDURE CreateGetVariableElement() : DynamicWebpage.ActiveElement;
	VAR obj: GetVariable;
	BEGIN
		NEW(obj); RETURN obj
	END CreateGetVariableElement;

	PROCEDURE CreateSetVariableElement() : DynamicWebpage.ActiveElement;
	VAR obj: SetVariable;
	BEGIN
		NEW(obj); RETURN obj
	END CreateSetVariableElement;

	PROCEDURE CreateGuardElement() : DynamicWebpage.ActiveElement;
	VAR obj: Guard;
	BEGIN
		NEW(obj); RETURN obj
	END CreateGuardElement;

	PROCEDURE CreateSequenceElement() : DynamicWebpage.ActiveElement;
	VAR obj: Sequence;
	BEGIN
		NEW(obj); RETURN obj
	END CreateSequenceElement;

	PROCEDURE CreateIsEqualElement() : DynamicWebpage.ActiveElement;
	VAR obj: IsEqual;
	BEGIN
		NEW(obj); RETURN obj
	END CreateIsEqualElement;

	PROCEDURE CreateToggleBlockElement() : DynamicWebpage.ActiveElement;
	VAR obj: ToggleBlock;
	BEGIN
		NEW(obj); RETURN obj
	END CreateToggleBlockElement;

	PROCEDURE CreateVisitorCounterElement() : DynamicWebpage.ActiveElement;
	VAR obj: VisitorCounter;
	BEGIN
		NEW(obj); RETURN obj
	END CreateVisitorCounterElement;

	PROCEDURE CreateNotElement() : DynamicWebpage.ActiveElement;
	VAR obj: Not;
	BEGIN
		NEW(obj); RETURN obj
	END CreateNotElement;

	PROCEDURE CreateAndElement() : DynamicWebpage.ActiveElement;
	VAR obj: And;
	BEGIN
		NEW(obj); RETURN obj
	END CreateAndElement;

	PROCEDURE CreateOrElement() : DynamicWebpage.ActiveElement;
	VAR obj: Or;
	BEGIN
		NEW(obj); RETURN obj
	END CreateOrElement;

	PROCEDURE CreateXorElement() : DynamicWebpage.ActiveElement;
	VAR obj: Xor;
	BEGIN
		NEW(obj); RETURN obj
	END CreateXorElement;

	PROCEDURE GetActiveElementDescriptors*() : DynamicWebpage.ActiveElementDescSet;
	VAR desc: POINTER TO ARRAY OF DynamicWebpage.ActiveElementDescriptor;
		descSet: DynamicWebpage.ActiveElementDescSet;
	BEGIN
		NEW(desc, 19);
		NEW(desc[0], "Hyperlink", CreateHyperlinkElement);
		NEW(desc[1], "EventButton",  CreateEventButtonElement);
		NEW(desc[2], "EventLink", CreateEventLinkElement);
		NEW(desc[3], "Formular", CreateFormularElement);
		NEW(desc[4], "DataContainer", CreateDataContainerElement);
		NEW(desc[5], "SessionContainer", CreateSessionContainerElement);
		NEW(desc[6], "Datagrid", CreateDatagridElement);
		NEW(desc[7], "GetHeaderField", CreateGetHeaderFieldElement);
		NEW(desc[8], "GetVariable", CreateGetVariableElement);
		NEW(desc[9], "SetVariable", CreateSetVariableElement);
		NEW(desc[10], "Guard", CreateGuardElement);
		NEW(desc[11], "Sequence", CreateSequenceElement);
		NEW(desc[12], "IsEqual", CreateIsEqualElement);
		NEW(desc[13], "ToggleBlock", CreateToggleBlockElement);
		NEW(desc[14], "VisitorCounter", CreateVisitorCounterElement);
		NEW(desc[15], "Not", CreateNotElement);
		NEW(desc[16], "And", CreateAndElement);
		NEW(desc[17], "Or", CreateOrElement);
		NEW(desc[18], "Xor", CreateXorElement);
		NEW(descSet, desc^); RETURN descSet
	END GetActiveElementDescriptors;

	PROCEDURE GetNewPersistentDataContainer() : PrevalenceSystem.PersistentObject;
	VAR obj: PersistentDataContainer;
	BEGIN
		NEW(obj); RETURN obj
	END GetNewPersistentDataContainer;

	PROCEDURE GetNewPersistentCounter() : PrevalenceSystem.PersistentObject;
	VAR obj: PersistentCounter;
	BEGIN
		NEW(obj); RETURN obj
	END GetNewPersistentCounter;

	(** used by the prevalence system *)
	PROCEDURE GetPersistentObjectDescriptors*() : PrevalenceSystem.PersistentObjectDescSet;
	VAR descSet : PrevalenceSystem.PersistentObjectDescSet;
		descs: ARRAY 2 OF PrevalenceSystem.PersistentObjectDescriptor;
	BEGIN
		descs[0] := persistentDataContainerDesc;
		descs[1] := persistentCounterDesc;
		NEW(descSet, descs);
		RETURN descSet
	END GetPersistentObjectDescriptors;

BEGIN
	oidCounter := 0;
	NEW(persistentDataContainerDesc, "WebStd", "PersistentDataContainer", GetNewPersistentDataContainer);
	NEW(persistentCounterDesc, "WebStd", "PersistentCounter", GetNewPersistentCounter);
END WebStd.
