MODULE WebForum; (** AUTHOR "Luc Blaeser"; PURPOSE "Example implementation of a web forum" *)

IMPORT DynamicWebpage, HTTPSupport, HTTPSession, WebAccounts, WebComplex, WebStd, PrevalenceSystem,
	XML, XMLObjects, Dates, Strings;

CONST
	FeatureTrackerObjName = "FeatureTracker";
	ThisModuleNameStr = "WebForum";
	DefaultMaxPriority = 3;

	EditLabel = "Edit";
	DeleteLabel = "Delete";
	InsertSubEntryLabel = "Insert subentry";
	AuthorLabel = "Author: ";
	AuthorHeaderLabel = "Author";
	TitleTextLabel = "Title text: ";
	TitleTextHeaderLabel = "Title";
	DetailTextLabel = "Detail text: ";
	ModifiedDateLabel = "Modified date: ";
	ModifiedDateHeaderLabel = "Date";
	PriorityLabel = "Priority: ";
	PriorityHeaderLabel = "Priority";
	TypeLabel = "Type: ";
	TypeHeaderLabel = "Type";
	StatusLabel = "Status: ";
	StatusHeaderLabel = "Status";
	RemoveInterestedContainerLabel = "Remove from my interested containers";
	AddInterestedContainerLabel = "Add to my interested containers";
	DetailTextIsMissingLabel = "detail text is missing";

 TYPE
	StringList = POINTER TO ARRAY OF Strings.String;

	FeatureEntry = OBJECT(WebComplex.WebForumEntry);
		VAR
			author: Strings.String;
			titleText: Strings.String;
			detailText: Strings.String;
			modifiedDate: WebStd.PtrDateTime;
			priority: LONGINT; (* priority number *)
			type: Strings.String; (* type information like "Bug", "Feature", "Question" *)
			status: Strings.String; (* status information like "unconfirmed", "confirmed" *)

		PROCEDURE Internalize*(input: XML.Content);
		VAR container: XML.Container;
		BEGIN
			container := input(XML.Container);
			Internalize^(input); (* internalize inherited subEntries and superEntry fields *)

			(* feature element specific fields *)
			author := WebStd.InternalizeString(container, "Author");
			titleText := WebStd.InternalizeString(container, "TitleText");
			detailText := WebStd.InternalizeString(container, "DetailText");
			modifiedDate := WebStd.InternalizeDateTime(container, "ModifiedDate");
			priority := WebStd.InternalizeInteger(container, "Priority");
			type := WebStd.InternalizeString(container, "Type");
			status := WebStd.InternalizeString(container, "Status")
		END Internalize;

		PROCEDURE Externalize*() : XML.Content;
		VAR container: XML.Container;
		BEGIN
			NEW(container);

			(* append externalized inherited fields subEntries and superEntry *)
			WebStd.AppendXMLContent(container, Externalize^());

			(* feature element specific fields *)
			WebStd.ExternalizeString(author, container, "Author");
			WebStd.ExternalizeString(titleText, container, "TitleText");
			WebStd.ExternalizeString(detailText, container, "DetailText");
			WebStd.ExternalizeDateTime(modifiedDate, container, "ModifiedDate");
			WebStd.ExternalizeInteger(priority, container, "Priority");
			WebStd.ExternalizeString(type, container, "Type");
			WebStd.ExternalizeString(status, container, "Status");
			RETURN container
		END Externalize;

		PROCEDURE MakeNewEntryBold(lastLoginTime: WebStd.PtrDateTime; xmlText: XML.Container): XML.Container;
		VAR bold: XML.Element;
		BEGIN
			IF ((lastLoginTime # NIL) & (modifiedDate # NIL) & (WebStd.CompareDateTime(modifiedDate^, lastLoginTime^))) THEN
				NEW(bold); bold.SetName("b");
				WebStd.AppendXMLContent(bold, xmlText);
				RETURN bold
			ELSE
				RETURN xmlText
			END
		END MakeNewEntryBold;

		PROCEDURE TableView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : WebComplex.TableRow;
		VAR row: WebComplex.TableRow; cell: WebComplex.TableCell; xmlText: XML.Container; tracker: FeatureTracker;
			lastLoginTime: WebStd.PtrDateTime; modifDateStr: Strings.String; prioStr: ARRAY 14 OF CHAR;
		BEGIN
			(* display bold if modified since last login time *)
			IF (forum IS FeatureTracker) THEN
				tracker := forum(FeatureTracker);
				lastLoginTime := tracker.lastLoginTime;
			ELSE
				lastLoginTime := NIL
			END;

			NEW(row, 9);

			IF (author # NIL) THEN
				xmlText := MakeNewEntryBold(lastLoginTime, WebStd.CreateXMLText(author^))
			ELSE
				xmlText := WebStd.CreateXMLText(" ")
			END;
			NEW(cell, xmlText, WebComplex.WebForumNormalCell);
			row[0] := cell;

			IF (titleText # NIL) THEN
				xmlText := MakeNewEntryBold(lastLoginTime, WebStd.CreateXMLText(titleText^))
			ELSE
				xmlText := WebStd.CreateXMLText(" ")
			END;
			NEW(cell, xmlText, WebComplex.WebForumDetailViewCell);
			row[1] := cell;

			IF (modifiedDate # NIL) THEN
				modifDateStr := WebStd.DateTimeToStr(modifiedDate^);
				xmlText := MakeNewEntryBold(lastLoginTime, WebStd.CreateXMLText(modifDateStr^))
			ELSE
				xmlText := WebStd.CreateXMLText(" ")
			END;
			NEW(cell, xmlText, WebComplex.WebForumNormalCell);
			row[2] := cell;

			Strings.IntToStr(priority, prioStr);
			xmlText := MakeNewEntryBold(lastLoginTime, WebStd.CreateXMLText(prioStr));
			NEW(cell, xmlText, WebComplex.WebForumNormalCell);
			row[3] := cell;

			IF (type # NIL) THEN
				xmlText := MakeNewEntryBold(lastLoginTime, WebStd.CreateXMLText(type^))
			ELSE
				xmlText := WebStd.CreateXMLText(" ")
			END;
			NEW(cell, xmlText, WebComplex.WebForumNormalCell);
			row[4] := cell;

			IF (status # NIL) THEN
				xmlText := MakeNewEntryBold(lastLoginTime, WebStd.CreateXMLText(status^))
			ELSE
				xmlText := WebStd.CreateXMLText(" ")
			END;
			NEW(cell, xmlText, WebComplex.WebForumNormalCell);
			row[5] := cell;

			xmlText := MakeNewEntryBold(lastLoginTime, WebStd.CreateXMLText(EditLabel));
			NEW(cell, xmlText, WebComplex.WebForumEditViewCell);
			row[6] := cell;

			xmlText := MakeNewEntryBold(lastLoginTime, WebStd.CreateXMLText(DeleteLabel));
			NEW(cell, xmlText, WebComplex.WebForumDeleteCell);
			row[7] := cell;

			xmlText := MakeNewEntryBold(lastLoginTime, WebStd.CreateXMLText(InsertSubEntryLabel));
			NEW(cell, xmlText, WebComplex.WebForumSubInsertViewCell);
			row[8] := cell;

			RETURN row
		END TableView;

		PROCEDURE DetailView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR container: XML.Container; pTag: XML.Element; modifDateStr: Strings.String; prioStr: ARRAY 14 OF CHAR;
		BEGIN
			NEW(container);
			WebComplex.AddStandardDetailView(container, AuthorLabel, author);
			WebComplex.AddStandardDetailView(container, TitleTextLabel, titleText);
			WebComplex.AddMultipleLinesDetailView(container, DetailTextLabel, detailText);

			NEW(pTag); pTag.SetName("p");
			WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(ModifiedDateLabel));
			IF (modifiedDate # NIL) THEN
				modifDateStr := WebStd.DateTimeToStr(modifiedDate^);
				WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(modifDateStr^))
			END;
			container.AddContent(pTag);

			NEW(pTag); pTag.SetName("p");
			WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(PriorityLabel));
			Strings.IntToStr(priority, prioStr);
			WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(prioStr));
			container.AddContent(pTag);

			WebComplex.AddStandardDetailView(container, TypeLabel, type);
			WebComplex.AddStandardDetailView(container, StatusLabel, status);
			RETURN container
		END DetailView;

		PROCEDURE EditView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR table, tr, td, select, option: XML.Element;
			tracker: FeatureTracker; i: LONGINT; iStr: ARRAY 14 OF CHAR;
		BEGIN
			NEW(table); table.SetName("table");
			WebComplex.AddTextFieldInputRow(table, AuthorLabel, "author", author);
			WebComplex.AddTextFieldInputRow(table, TitleTextLabel, "titletext", titleText);
			WebComplex.AddTextAreaInputRow(table, DetailTextLabel, "detailtext", detailText);

			IF (forum IS FeatureTracker) THEN
				tracker := forum(FeatureTracker);

				NEW(tr); tr.SetName("tr"); table.AddContent(tr);
				NEW(td); td.SetName("td"); tr.AddContent(td);
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText(PriorityLabel));
				NEW(td); td.SetName("td"); tr.AddContent(td);
				NEW(select); select.SetName("select"); td.AddContent(select);
				select.SetAttributeValue("name", "priority");
				FOR i := 1 TO tracker.maxPrio DO
					Strings.IntToStr(i, iStr);
					NEW(option); option.SetName("option"); select.AddContent(option);
					option.SetAttributeValue("value", iStr);
					IF (i = priority) THEN
						option.SetAttributeValue("selected", "true")
					END;
					WebStd.AppendXMLContent(option, WebStd.CreateXMLText(iStr));
				END;

				IF (tracker.types # NIL) THEN
					NEW(tr); tr.SetName("tr"); table.AddContent(tr);
					NEW(td); td.SetName("td"); tr.AddContent(td);
					WebStd.AppendXMLContent(td, WebStd.CreateXMLText(TypeLabel));
					NEW(td); td.SetName("td"); tr.AddContent(td);
					NEW(select); select.SetName("select"); td.AddContent(select);
					select.SetAttributeValue("name", "type");
					AppendOptionList(select, tracker.types, type)
				END;

				IF (tracker.status # NIL) THEN
					NEW(tr); tr.SetName("tr"); table.AddContent(tr);
					NEW(td); td.SetName("td"); tr.AddContent(td);
					WebStd.AppendXMLContent(td, WebStd.CreateXMLText(StatusLabel));
					NEW(td); td.SetName("td"); tr.AddContent(td);
					NEW(select); select.SetName("select"); td.AddContent(select);
					select.SetAttributeValue("name", "status");
					AppendOptionList(select, tracker.status, status)
				END
			END;
			RETURN table
		END EditView;
	END FeatureEntry;

	(** recursive feature tracker web forum statefull active element with detail view and optional modification functionality
	 * if granted by authorization. If 'prevalenceSystem' is not specified then the standard prevalence system will be used.
	 * Omitting an access constraint means publishing the functionality to all users.
	 * 'OnlyNewEntries' indicates optionlally that only new entries since the last login have to be displayed.
	 *  'MaxPriority' specifies the heighest possible priority in the system. The default priority is 3.
	 *  'MessageTypes' specifies the domain for a message type.
	 *  'MessageStatus' specifies the domain for a message status. The first status entry is the default type for a status.
	 * usage example:
	 *  <WebComplex:WebForum id="MyForum3" containername="MyForum" prevalencesystem="..">
	 *    <OnlyNewEntries/>
	 *    <MaxPriority number="5"/>
	 *    <MessageTypes>
	 *        <Type>Bug</Type>
	 *        <Type>Feature request</Type>
	 *        <Type>Question</Type>
	 *    </MessageTypes>
	 *    <MessageStatus>
	 *       <Status>Unconfirmed</Status>
	 *       <Status>Confirmed</Status>
	 *    <MessageStatus>
	 *    <Paging size="10" nextlabel="more.." previouslabel="..back"/>
	 *    <Searching label="Search for entries:" buttonname="Search!"/>
	 *    <AccessContraint>
	 *         <Edit><WebStd:AuthorizationCheck domain=".."/></Edit>
	 *         <Insert><WebStd:AuthorizationCheck domain=".."/></Insert>
	 *         <Delete><WebStd:AuthorizationCheck domain=".."/></Delete>
	 *    </AccessConstraint>
	 *  </WebComplex:WebForum>
	 *)
	FeatureTracker* = OBJECT(WebComplex.WebForum);
		VAR
			searchText: Strings.String;
			thisContainerName: Strings.String;
			lastLoginTime: WebStd.PtrDateTime; (* # NIL if the forum has only to display new entries since lastLoginDate *)
			maxPrio: LONGINT;
			types: StringList; (* the list of different message types specified by subelement 'MessageTypes' *)
			status: StringList; (* the list of different message status codes specified by subelement 'Status' *)

		PROCEDURE &Initialize*;
		BEGIN Init(); lastLoginTime := NIL; maxPrio := DefaultMaxPriority; types := NIL; status := NIL
		END Initialize;

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR elem: XML.Element; session: HTTPSession.Session; webAccount: WebAccounts.WebAccount;
			str: Strings.String;
		BEGIN
			elem := WebStd.GetXMLSubElement(input, "OnlyNewEntries");
			lastLoginTime := NIL;
			IF (elem # NIL) THEN
				session := HTTPSession.GetSession(request);
				webAccount := WebAccounts.GetAuthWebAccountForSession(session);
				IF (webAccount # NIL) THEN
					lastLoginTime := webAccount.GetLastLoginTime()
				END
			END;

			elem := WebStd.GetXMLSubElement(input, "MaxPriority");
			IF (elem # NIL) THEN
				str := elem.GetAttributeValue("number");
				IF (str # NIL) THEN
					Strings.StrToInt(str^, maxPrio)
				END
			ELSE
				maxPrio := DefaultMaxPriority
			END;

			elem := WebStd.GetXMLSubElement(input, "MessageTypes");
			IF (elem # NIL) THEN
				types := GetStringListFromXML(elem, "Type")
			ELSE
				types := NIL
			END;

			elem := WebStd.GetXMLSubElement(input, "MessageStatus");
			IF (elem # NIL) THEN
				status := GetStringListFromXML(elem, "Status")
			ELSE
				status := NIL
			END;

			RETURN Transform^(input, request)
		END Transform;

		PROCEDURE GetStringListFromXML(elem: XML.Element; subElemName: ARRAY OF CHAR) : StringList;
		VAR subElem: XML.Element; enum: XMLObjects.Enumerator; counter: LONGINT; list: StringList;
			elemName: Strings.String; p: ANY;
		BEGIN
			enum := elem.GetContents(); counter := 0;
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				IF (p IS XML.Element) THEN
					subElem := p(XML.Element); elemName := subElem.GetName();
					IF ((elemName # NIL) & (elemName^ = subElemName)) THEN INC(counter) END
				END
			END;
			IF (counter > 0) THEN
				enum.Reset(); NEW(list, counter); counter := 0;
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext();
					IF (p IS XML.Element) THEN
						subElem := p(XML.Element); elemName := subElem.GetName();
						IF ((elemName # NIL) & (elemName^ = subElemName)) THEN
							list[counter] := WebStd.GetXMLCharContent(subElem); INC(counter)
						END
					END
				END;
				RETURN list
			ELSE
				RETURN NIL
			END
		END GetStringListFromXML;

		PROCEDURE GetAdditionalEventHandlers*() : DynamicWebpage.EventHandlerList;
		VAR list: DynamicWebpage.EventHandlerList;
		BEGIN
			NEW(list, 1);
			NEW(list[0], "SetInterested", SetInterested);
			RETURN list
		END GetAdditionalEventHandlers;

		PROCEDURE SetInterested(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		VAR session: HTTPSession.Session; webAccount: WebAccounts.WebAccount;
		BEGIN
			session := HTTPSession.GetSession(request);
			webAccount := WebAccounts.GetAuthWebAccountForSession(session);
			IF ((webAccount # NIL) & (thisContainerName # NIL)) THEN
				IF (webAccount.IsInterestedOnContainer(thisContainerName^)) THEN
					webAccount.RemoveInterestedContainer(thisContainerName^)
				ELSE
					webAccount.AddInterestedContainer(thisContainerName^)
				END
			END
		END SetInterested;

		PROCEDURE GetDefaultSearchFilter*() : WebStd.PersistentDataFilter;
		BEGIN RETURN DefaultFilter
		END GetDefaultSearchFilter;

		PROCEDURE RecursiveSearchFilter(featureEntry: FeatureEntry) : BOOLEAN;
		VAR modifDate: WebStd.PtrDateTime; list: WebStd.PersistentDataObjectList;
			subFeature: FeatureEntry; i: LONGINT;
		BEGIN
			modifDate := featureEntry.modifiedDate;
			IF (modifDate # NIL) THEN
				IF (WebStd.CompareDateTime(modifDate^, lastLoginTime^)) THEN RETURN TRUE END
			END;
			IF (featureEntry.subEntries # NIL) THEN
				list := featureEntry.subEntries.GetElementList(WebStd.DefaultPersistentDataFilter, NIL);
				IF (list # NIL) THEN
					FOR i := 0 TO LEN(list)-1 DO
						IF (list[i] IS FeatureEntry) THEN
							subFeature := list[i](FeatureEntry);
							IF (RecursiveSearchFilter(subFeature)) THEN RETURN TRUE END
						END
					END
				END
			END;
			RETURN FALSE
		END RecursiveSearchFilter;

		(* true iff the element or a subelement has been modified since last login *)
		PROCEDURE DefaultFilter(obj: WebStd.PersistentDataObject) : BOOLEAN;
		VAR featureEntry: FeatureEntry;
		BEGIN
			IF ((lastLoginTime # NIL) & (obj IS FeatureEntry)) THEN
				featureEntry := obj(FeatureEntry);
				RETURN RecursiveSearchFilter(featureEntry)
			ELSE
				RETURN TRUE
			END
		END DefaultFilter;

		PROCEDURE GetHeaderXMLContent*(persContainer: WebStd.PersistentDataContainer;
			input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR pTag, eventLink, label: XML.Element; objectId: Strings.String; container: XML.Container;
			session: HTTPSession.Session; webAccount: WebAccounts.WebAccount;
		BEGIN
			objectId := input.GetAttributeValue(DynamicWebpage.XMLAttributeObjectIdName); (* objectId # NIL *)
			thisContainerName := input.GetAttributeValue("containername");

			session := HTTPSession.GetSession(request);
			webAccount := WebAccounts.GetAuthWebAccountForSession(session);
			IF ((webAccount # NIL) & (thisContainerName # NIL)) THEN
				NEW(container);
				NEW(pTag); pTag.SetName("p");

				NEW(eventLink); eventLink.SetName("WebStd:EventLink");
				eventLink.SetAttributeValue("xmlns:WebStd", "WebStd");

				NEW(label); label.SetName("Label");
				eventLink.AddContent(label);

				eventLink.SetAttributeValue("method", "SetInterested");
				eventLink.SetAttributeValue("object", "FeatureTracker");
				eventLink.SetAttributeValue("module", ThisModuleNameStr);
				eventLink.SetAttributeValue("objectid", objectId^);
				pTag.AddContent(eventLink);

				container.AddContent(pTag);
				IF (webAccount.IsInterestedOnContainer(thisContainerName^)) THEN
					WebStd.AppendXMLContent(label, WebStd.CreateXMLText(RemoveInterestedContainerLabel));
				ELSE
					WebStd.AppendXMLContent(label, WebStd.CreateXMLText(AddInterestedContainerLabel))
				END;
				RETURN container
			ELSE
				RETURN NIL
			END
		END GetHeaderXMLContent;

		PROCEDURE InsertObject*(container: WebStd.PersistentDataContainer; superEntry: WebComplex.WebForumEntry;
			request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList;
			VAR statusMsg: XML.Content) : BOOLEAN;
			(* parameters "author", "titletext", "detailtext", "priority", "type" but not "status" *)
		VAR author, titleText, detailText, priorityStr, type: Strings.String; obj: FeatureEntry;
			subEntries: WebStd.PersistentDataContainer;
		BEGIN
			author := params.GetParameterValueByName("author");
			titleText := params.GetParameterValueByName("titletext");
			detailText := params.GetParameterValueByName("detailtext");
			priorityStr := params.GetParameterValueByName("priority");
			type := params.GetParameterValueByName("type");

			IF ((titleText # NIL) & (titleText^ # "")) THEN
				NEW(obj); obj.author := author; obj.titleText := titleText; obj.detailText := detailText;
				IF (priorityStr # NIL) THEN
					Strings.StrToInt(priorityStr^, obj.priority)
				ELSE
					obj.priority := 0
				END;
				obj.type := type;
				IF (status # NIL) THEN
					obj.status := status[0]
				ELSE
					obj.status := NIL
				END;
				NEW(obj.modifiedDate); obj.modifiedDate^ := Dates.Now();

				container.AddPersistentDataObject(obj, featureEntryDesc); (* adds it also to the prevalence system *)

				IF (superEntry # NIL) THEN
					IF (superEntry.subEntries = NIL) THEN
						NEW(subEntries);
						superEntry.BeginModification;
						superEntry.subEntries := subEntries;
						PrevalenceSystem.AddPersistentObject(subEntries, WebStd.persistentDataContainerDesc);
						(* the object must be added to the prevalence system after there is a reference from a persistent object to it
						 * otherwise it could be already collected from the garbage collection mechanism of the prevalence system *)
						superEntry.EndModification
					END;
					superEntry.subEntries.AddPersistentDataObject(obj, featureEntryDesc);
					obj.BeginModification;
					obj.superEntry := superEntry;
					obj.EndModification
				END;
				RETURN TRUE
			ELSE
				statusMsg := WebStd.CreateXMLText(DetailTextIsMissingLabel);
				RETURN FALSE
			END
		END InsertObject;

		PROCEDURE UpdateObject*(obj: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest;
			params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
			(* parameters "author", "titletext", "detailtext", "priority", "type", "status" *)
		VAR author, titleText, detailText, priorityStr, status, type: Strings.String; feature: FeatureEntry;
		BEGIN (* obj # NIL *)
			IF (obj IS FeatureEntry) THEN
				feature := obj(FeatureEntry);
				author := params.GetParameterValueByName("author");
				titleText := params.GetParameterValueByName("titletext");
				detailText := params.GetParameterValueByName("detailtext");
				priorityStr := params.GetParameterValueByName("priority");
				type := params.GetParameterValueByName("type");
				status := params.GetParameterValueByName("status");

				IF ((titleText # NIL) & (titleText^ # "")) THEN
					feature.BeginModification;
					feature.author := author; feature.titleText := titleText; feature.detailText := detailText;
					IF (priorityStr # NIL) THEN
						Strings.StrToInt(priorityStr^, feature.priority)
					ELSE
						feature.priority := 0
					END;
					feature.type := type;
					feature.status := status;
					NEW(feature.modifiedDate); feature.modifiedDate^ := Dates.Now();
					feature.EndModification;
					RETURN TRUE
				ELSE
					statusMsg := WebStd.CreateXMLText(DetailTextIsMissingLabel);
					RETURN FALSE
				END
			ELSE
				statusMsg := WebStd.CreateXMLText("object is not of type FeatureEntry");
				RETURN FALSE
			END
		END UpdateObject;

		PROCEDURE ThisObjectName*() : Strings.String;
		BEGIN RETURN WebStd.GetString(FeatureTrackerObjName)
		END ThisObjectName;

		PROCEDURE ThisModuleName*() : Strings.String;
		BEGIN RETURN WebStd.GetString(ThisModuleNameStr)
		END ThisModuleName;

		(** abstract, returns the insert view for the initialization of a new web forum entry, without submit/back-input fields
		 * and without hidden parameter for super entry in hierarchy.
		 * superEntry is the parent web forum entry in a hierachical web forum, superEntry is NIL iff it is a root entry *)
		PROCEDURE GetInsertView*(superEntry: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest): XML.Content;
		VAR table, tr, td, select, option: XML.Element; session: HTTPSession.Session;
			webAccount: WebAccounts.WebAccount; str: Strings.String; i: LONGINT; iStr: ARRAY 14 OF CHAR;
		BEGIN
			NEW(table); table.SetName("table");

			session := HTTPSession.GetSession(request);
			webAccount := WebAccounts.GetAuthWebAccountForSession(session);

			(* set users default message name if present *)
			str := NIL;
			IF (webAccount # NIL) THEN
				str := webAccount.GetDefaultMsgName()
			END;
			WebComplex.AddTextFieldInputRow(table, AuthorLabel, "author", str);
			WebComplex.AddTextFieldInputRow(table, TitleTextLabel, "titletext", NIL);
			WebComplex.AddTextAreaInputRow(table, DetailTextLabel, "detailtext", NIL);

			NEW(tr); tr.SetName("tr"); table.AddContent(tr);
			NEW(td); td.SetName("td"); tr.AddContent(td);
			WebStd.AppendXMLContent(td, WebStd.CreateXMLText(PriorityLabel));
			NEW(td); td.SetName("td"); tr.AddContent(td);
			NEW(select); select.SetName("select"); td.AddContent(select);
			select.SetAttributeValue("name", "priority");
			FOR i := 1 TO maxPrio DO
				Strings.IntToStr(i, iStr);
				NEW(option); option.SetName("option"); select.AddContent(option);
				option.SetAttributeValue("value", iStr);
				WebStd.AppendXMLContent(option, WebStd.CreateXMLText(iStr));
			END;

			IF (types # NIL) THEN
				NEW(tr); tr.SetName("tr"); table.AddContent(tr);
				NEW(td); td.SetName("td"); tr.AddContent(td);
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText(TypeLabel));
				NEW(td); td.SetName("td"); tr.AddContent(td);
				NEW(select); select.SetName("select"); td.AddContent(select);
				select.SetAttributeValue("name", "type");
				AppendOptionList(select, types, NIL)
			END;

			RETURN table
		END GetInsertView;

		PROCEDURE GetTableHeader*(request: HTTPSupport.HTTPRequest): WebComplex.HeaderRow;
		VAR row: WebComplex.HeaderRow;
		BEGIN
			NEW(row, 9);
			row[0] := WebComplex.GetHeaderCellForText(AuthorHeaderLabel, CompareAuthor);
			row[1] := WebComplex.GetHeaderCellForText(TitleTextHeaderLabel, CompareTitle);
			row[2] := WebComplex.GetHeaderCellForText(ModifiedDateHeaderLabel, CompareModifDate);
			row[3] := WebComplex.GetHeaderCellForText(PriorityHeaderLabel, ComparePriority);
			row[4] := WebComplex.GetHeaderCellForText(TypeHeaderLabel, CompareType);
			row[5] := WebComplex.GetHeaderCellForText(StatusHeaderLabel, CompareStatus);
			row[6] := WebComplex.GetHeaderCellForText(" ", NIL);
			row[7] := WebComplex.GetHeaderCellForText(" ", NIL);
			row[8] := WebComplex.GetHeaderCellForText(" ", NIL);
			RETURN row
		END GetTableHeader;

		PROCEDURE GetSearchFilter*(text: Strings.String) : WebStd.PersistentDataFilter;
		BEGIN
			IF (text # NIL) THEN
				NEW(searchText, Strings.Length(text^)+3);
				Strings.Concat("*", text^, searchText^);
				IF (Strings.Length(text^) > 0) THEN
					Strings.Append(searchText^, "*");
					Strings.LowerCase(searchText^)
				END;
				RETURN SearchFilter
			END;
			RETURN NIL
		END GetSearchFilter;

		PROCEDURE SearchFilter(obj: WebStd.PersistentDataObject) : BOOLEAN;
		VAR entry: FeatureEntry;
			PROCEDURE Matches(VAR str: ARRAY OF CHAR) : BOOLEAN;
			VAR lowStr: Strings.String;
			BEGIN
				lowStr := WebStd.GetString(str);
				Strings.LowerCase(lowStr^);
				RETURN Strings.Match(searchText^, lowStr^)
			END Matches;
		BEGIN (* searchText # NIL *)
			IF (obj IS FeatureEntry) THEN
				entry := obj(FeatureEntry);
				IF ((entry.author # NIL) & (Matches(entry.author^))) THEN
					RETURN TRUE
				END;
				IF ((entry.titleText # NIL) & (Matches(entry.titleText^))) THEN
					RETURN TRUE
				END;
				IF ((entry.detailText # NIL) & (Matches(entry.detailText^))) THEN
					RETURN TRUE
				END
			END;
			RETURN FALSE
		END SearchFilter;

		PROCEDURE CompareAuthor(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: FeatureEntry;
		BEGIN
			IF ((obj1 IS FeatureEntry) & (obj2 IS FeatureEntry)) THEN
				f1 := obj1(FeatureEntry); f2 := obj2(FeatureEntry);
				IF (f2.author = NIL) THEN
					RETURN FALSE
				ELSIF (f1.author = NIL) THEN (* f2.author # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.author^ < f2.author^
				END
			ELSE
				RETURN FALSE
			END
		END CompareAuthor;

		PROCEDURE CompareTitle(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: FeatureEntry;
		BEGIN
			IF ((obj1 IS FeatureEntry) & (obj2 IS FeatureEntry)) THEN
				f1 := obj1(FeatureEntry); f2 := obj2(FeatureEntry);
				IF (f2.titleText = NIL) THEN
					RETURN FALSE
				ELSIF (f1.titleText = NIL) THEN (* f2.titleText # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.titleText^ < f2.titleText^
				END
			ELSE
				RETURN FALSE
			END
		END CompareTitle;

		PROCEDURE CompareModifDate(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: FeatureEntry;
		BEGIN
			IF ((obj1 IS FeatureEntry) & (obj2 IS FeatureEntry)) THEN
				f1 := obj1(FeatureEntry); f2 := obj2(FeatureEntry);
				IF (f2.modifiedDate = NIL) THEN
					RETURN FALSE
				ELSIF (f1.modifiedDate = NIL) THEN (* f2.modifiedDate # NIL *)
					RETURN TRUE
				ELSE
					RETURN WebStd.CompareDateTime(f1.modifiedDate^, f2.modifiedDate^)
				END
			ELSE
				RETURN FALSE
			END
		END CompareModifDate;

		PROCEDURE ComparePriority(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: FeatureEntry;
		BEGIN
			IF ((obj1 IS FeatureEntry) & (obj2 IS FeatureEntry)) THEN
				f1 := obj1(FeatureEntry); f2 := obj2(FeatureEntry);
				RETURN f1.priority > f2.priority
			ELSE
				RETURN FALSE
			END
		END ComparePriority;

		PROCEDURE CompareType(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: FeatureEntry;
		BEGIN
			IF ((obj1 IS FeatureEntry) & (obj2 IS FeatureEntry)) THEN
				f1 := obj1(FeatureEntry); f2 := obj2(FeatureEntry);
				IF (f2.type = NIL) THEN
					RETURN FALSE
				ELSIF (f1.type = NIL) THEN (* f2.type # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.type^ < f2.type^
				END
			ELSE
				RETURN FALSE
			END
		END CompareType;

		PROCEDURE CompareStatus(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: FeatureEntry;
		BEGIN
			IF ((obj1 IS FeatureEntry) & (obj2 IS FeatureEntry)) THEN
				f1 := obj1(FeatureEntry); f2 := obj2(FeatureEntry);
				IF (f2.status = NIL) THEN
					RETURN FALSE
				ELSIF (f1.status = NIL) THEN (* f2.status # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.status^ < f2.status^
				END
			ELSE
				RETURN FALSE
			END
		END CompareStatus;
	END FeatureTracker;

	VAR
		featureEntryDesc: PrevalenceSystem.PersistentObjectDescriptor; (* descriptor for FeatureEntry *)

	(* append HTML option list to 'select'. the string equal to 'actualValue' is selected *)
	PROCEDURE AppendOptionList(select: XML.Element; list: StringList; actualValue: Strings.String);
	VAR str: Strings.String; option: XML.Element; i: LONGINT;
	BEGIN (* select # NIL & list # NIL *)
		FOR i := 0 TO LEN(list)-1 DO
			str := list[i];
			IF (str # NIL) THEN
				NEW(option); option.SetName("option"); select.AddContent(option);
				option.SetAttributeValue("value", str^);
				IF ((actualValue # NIL) & (actualValue^ = str^)) THEN
					option.SetAttributeValue("selected", "true")
				END;
				WebStd.AppendXMLContent(option, WebStd.CreateXMLText(str^));
			END
		END
	END AppendOptionList;

	PROCEDURE GetNewFeatureEntry() : PrevalenceSystem.PersistentObject;
	VAR obj: FeatureEntry;
	BEGIN NEW(obj); RETURN obj
	END GetNewFeatureEntry;

	(** used by the prevalence system *)
	PROCEDURE GetPersistentObjectDescriptors*() : PrevalenceSystem.PersistentObjectDescSet;
	VAR descSet : PrevalenceSystem.PersistentObjectDescSet;
		descs: ARRAY 1 OF PrevalenceSystem.PersistentObjectDescriptor;
	BEGIN
		descs[0] := featureEntryDesc;
		NEW(descSet, descs);
		RETURN descSet
	END GetPersistentObjectDescriptors;

	PROCEDURE CreateFeatureTrackerElement() : DynamicWebpage.ActiveElement;
	VAR obj: FeatureTracker;
	BEGIN
		NEW(obj); RETURN obj
	END CreateFeatureTrackerElement;

	PROCEDURE GetActiveElementDescriptors*() : DynamicWebpage.ActiveElementDescSet;
	VAR desc: POINTER TO ARRAY OF DynamicWebpage.ActiveElementDescriptor;
		descSet: DynamicWebpage.ActiveElementDescSet;
	BEGIN
		NEW(desc, 1);
		NEW(desc[0],  "FeatureTracker", CreateFeatureTrackerElement);
		NEW(descSet, desc^); RETURN descSet
	END GetActiveElementDescriptors;

BEGIN
	NEW(featureEntryDesc, ThisModuleNameStr, "FeatureEntry", GetNewFeatureEntry)
END WebForum.

