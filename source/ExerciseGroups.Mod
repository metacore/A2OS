MODULE ExerciseGroups; (** AUTHOR "Luc Blaeser"; PURPOSE "Web Accounts and Authorization Domains" *)

IMPORT WebComplex, WebAccounts, WebStd, DynamicWebpage, PrevalenceSystem, HTTPSupport, HTTPSession,
	XML, XMLObjects, Strings, DynamicStrings, TFClasses, KernelLog;

CONST
	SingleGroupDatagridName = "SingleGroupDatagrid";
	AllGroupsDatagridName = "AllGroupsDatagrid";
	ThisModuleNameStr = "ExerciseGroups";

	AllGroupsContainerPrefixName = "dxp-exercisegroups-allgroups-";
	PersonGradePrefixName = "dxp-grade-";

	NextButtonLabel = "Weiter";
	BackButtonLabel = "Zurueck";
	SearchText = "Suchen: ";
	EmptyListText = "Kein Eintrag";
	InsertGroupText = "Neue Gruppe erstellen";
	SubmitButtonLabel = "Speichern";
	UnapplySortLabel = "Sortierung aufheben";
	UnapplyFilterLabel = "Alle Eintraege anzeigen";

	ExerciseName = "Uebung ";
	EditExerciseGradesLabel = "Uebungsuebersicht anschauen";
	CloseExerciseGradesLabel = "Zurueck zur Liste der Uebungsgruppenmitglieder";
	EmailToTheWholeGroup = "E-Mail an die ganze Gruppe";
	AddNewExerciseLabel = "Neue Aufgabe einfuegen";
	DeleteAnExerciseLabel = "Aufgabe loeschen";
	SendGradeNotoficationLabel = "Student benachrichtigen";
	InsertToGroupLabel = "In Uebungsgruppe eintragen";

	GradeNotificationSubject = "Geloeste Uebungen";
	GradeNotificationSalutation = "Hallo";
	GradeNotificationBodyHead = "Du hast die folgende Anzahl Punkte in den Uebungen erreicht:";
	GradeNotificationBodyTail = "Tschuess";

	MailCR = "%0D%0A";

TYPE
	(* wrapper integer object to use it for TFClasses.List *)
	IntObj = OBJECT
		VAR number: SIGNED32;
	END IntObj;

	(* wrapper integer list using TFClasses.List *)
	IntList = OBJECT
		VAR
			list: TFClasses.List;
			locked: BOOLEAN;

		PROCEDURE &Init*;
		BEGIN NEW(list); locked := FALSE
		END Init;

		PROCEDURE GetCount() : SIZE;
		BEGIN RETURN list.GetCount()
		END GetCount;

		(* returns 0 if item is not in the list *)
		PROCEDURE GetItem(pos: SIZE) : SIGNED32;
		VAR intObj: IntObj;
		BEGIN
			intObj := GetIntObj(pos);
			IF (intObj # NIL) THEN
				RETURN intObj.number
			ELSE
				RETURN 0
			END
		END GetItem;

		(* returns NIL if not in the list *)
		PROCEDURE GetIntObj(pos: SIZE) : IntObj;
		VAR p: ANY; intObj: IntObj;
		BEGIN
			list.Lock;
			IF ((pos >= 0) & (pos < list.GetCount()))THEN
				p := list.GetItem(pos);
				list.Unlock;
				IF (p IS IntObj) THEN
					intObj := p(IntObj);
					RETURN intObj
				END
			ELSE
				list.Unlock
			END;
			RETURN NIL
		END GetIntObj;

		PROCEDURE Exchange(pos: SIZE; newNumber: SIGNED32);
		VAR intObj: IntObj;
		BEGIN
			intObj := GetIntObj(pos);
			IF (intObj # NIL) THEN
				intObj.number := newNumber
			END;
		END Exchange;

		PROCEDURE Add(newNumber: SIGNED32);
		VAR intObj: IntObj;
		BEGIN
			Lock;
			NEW(intObj); intObj.number := newNumber;
			list.Add(intObj);
			Unlock
		END Add;

		PROCEDURE Remove(pos: SIZE);
		VAR intObj: IntObj;
		BEGIN
			Lock;
			intObj := GetIntObj(pos);
			IF (intObj # NIL) THEN
				list.Remove(intObj);
			END;
			Unlock
		END Remove;

		PROCEDURE Lock;
		BEGIN {EXCLUSIVE}
			AWAIT(~locked); locked := TRUE
		END Lock;

		PROCEDURE Unlock;
		BEGIN {EXCLUSIVE}
			locked := FALSE
		END Unlock;
	END IntList;

	Person* = OBJECT(WebComplex.WebForumEntry);
		VAR
			firstname: Strings.String;
			lastname: Strings.String;
			email: Strings.String;
			leginr: Strings.String;
			grades: IntList;

		PROCEDURE Internalize*(input: XML.Content);
		VAR container: XML.Container; elem, subElem: XML.Element; p: ANY; enum: XMLObjects.Enumerator;
			str: Strings.String; number: SIGNED32;
		BEGIN
			container := input(XML.Container);
			firstname := WebStd.InternalizeString(container, "FirstName");
			lastname := WebStd.InternalizeString(container, "LastName");
			email := WebStd.InternalizeString(container, "Email");
			leginr := WebStd.InternalizeString(container, "LegiNr");

			NEW(grades);
			elem := WebStd.GetXMLSubElement(container, "Grades");
			IF (elem # NIL) THEN
				enum := elem.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext();
					IF (p IS XML.Element) THEN
						subElem := p(XML.Element);
						str := WebStd.GetXMLCharContent(subElem);
						IF (str # NIL) THEN
							Strings.StrToInt(str^, number);
							grades.Add(number)
						END
					END
				END
			END
		END Internalize;

		PROCEDURE Externalize*() : XML.Content;
		VAR container: XML.Container; elem, subElem: XML.Element; str: ARRAY 14 OF CHAR; i: SIZE; number: SIGNED32;
		BEGIN
			NEW(container);
			WebStd.ExternalizeString(firstname, container, "FirstName");
			WebStd.ExternalizeString(lastname, container, "LastName");
			WebStd.ExternalizeString(email, container, "Email");
			WebStd.ExternalizeString(leginr, container, "LegiNr");

			IF (grades # NIL) THEN
				NEW(elem); elem.SetName("Grades"); container.AddContent(elem);
				grades.Lock;
				FOR i := 0 TO grades.GetCount()-1 DO
					number := grades.GetItem(i);
					Strings.IntToStr(number, str);
					NEW(subElem); subElem.SetName("Grade"); elem.AddContent(subElem);
					WebStd.AppendXMLContent(subElem, WebStd.CreateXMLText(str))
				END;
				grades.Unlock
			END;

			RETURN container
		END Externalize;

		PROCEDURE TableView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : WebComplex.TableRow;
		VAR row: WebComplex.TableRow;
		BEGIN
			NEW(row, 6);
			row[0] := WebComplex.GetTableCell(firstname, WebComplex.WebForumNormalCell);
			row[1] := WebComplex.GetTableCell(lastname, WebComplex.WebForumDetailViewCell);
			IF (IsAuthorizedUser(request)) THEN
				row[2] := WebComplex.GetEmailTableCell(email, WebComplex.WebForumNormalCell);
				row[3] := WebComplex.GetTableCell(leginr, WebComplex.WebForumNormalCell)
			ELSE
				row[2] := WebComplex.GetTableCellForText(" ", WebComplex.WebForumNormalCell);
				row[3] := WebComplex.GetTableCellForText(" ", WebComplex.WebForumNormalCell);
			END;
			row[4] := WebComplex.GetTableCellForText("Edit", WebComplex.WebForumEditViewCell);
			row[5] := WebComplex.GetTableCellForText("Delete", WebComplex.WebForumDeleteCell);
			RETURN row
		END TableView;

		PROCEDURE DetailView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR container: XML.Container; pTag: XML.Element;
		BEGIN
			NEW(container);

			NEW(pTag); pTag.SetName("p");
			WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText("Name: "));
			IF (firstname # NIL) THEN
				WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(firstname^))
			END;
			IF (lastname # NIL) THEN
				WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(lastname^))
			END;
			container.AddContent(pTag);

			IF (IsAuthorizedUser(request)) THEN
				NEW(pTag); pTag.SetName("p");
				WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText("Email: "));
				IF (email # NIL) THEN
					pTag.AddContent(WebComplex.GetMailtoElement(email^))
				END;
				container.AddContent(pTag);

				WebComplex.AddStandardDetailView(container, "Legi-Nr: ", leginr);

				WebStd.AppendXMLContent(container, GetGradesDetailView())
			END;

			RETURN container
		END DetailView;

		PROCEDURE GetGradesDetailView() : XML.Content;
		VAR table, tr, td: XML.Element; i: SIZE; number: SIGNED32; str: ARRAY 14 OF CHAR;
		BEGIN
			table := NIL;
			IF (grades # NIL) THEN
				grades.Lock;
				IF (grades.GetCount() > 0) THEN
					NEW(table); table.SetName("table");
					WebStd.AppendXMLContent(table, GetExerciseListHeaderRow(grades.GetCount()));

					NEW(tr); tr.SetName("tr"); table.AddContent(tr);
					FOR i := 0 TO grades.GetCount()-1 DO
						number := grades.GetItem(i); Strings.IntToStr(number, str);
						NEW(td); td.SetName("td"); tr.AddContent(td);
						WebStd.AppendXMLContent(td, WebStd.CreateXMLText(str))
					END
				END;
				grades.Unlock
			END;
			RETURN table
		END GetGradesDetailView;

		PROCEDURE EditView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR table: XML.Element;
		BEGIN
			NEW(table); table.SetName("table");
			WebComplex.AddTextFieldInputRow(table, "Vorname: ", "firstname", firstname);
			WebComplex.AddTextFieldInputRow(table, "Nachnahme: ", "lastname", lastname);
			WebComplex.AddTextFieldInputRow(table, "Email: ", "email", email);
			WebComplex.AddTextFieldInputRow(table, "Legi-Nr: ", "leginr", leginr);
			RETURN table
		END EditView;

		(* get XHTML table header row for the exercise grade list.  *)
		PROCEDURE GetExerciseListHeaderRow(nofCols: SIZE) : XML.Element;
		VAR tr, td: XML.Element; i: SIZE; iStr: ARRAY 14 OF CHAR; str: Strings.String;
		BEGIN
			IF (nofCols > 0) THEN
				NEW(tr); tr.SetName("tr");
				FOR i := 1 TO nofCols DO
					NEW(td); td.SetName("td"); tr.AddContent(td);

					Strings.IntToStr(i, iStr);
					NEW(str, Strings.Length(ExerciseName)+LEN(iStr)+1);
					COPY(ExerciseName, str^); Strings.Append(str^, iStr);

					WebStd.AppendXMLContent(td, WebStd.CreateXMLText(str^));
				END
			ELSE
				tr := NIL
			END;
			RETURN tr
	END GetExerciseListHeaderRow;
	END Person;

	(** statefull active element as webforum but with a additional subelement 'MaxEntries' which specifies the
	 * maximum number of members in a group
		<ExerciseGroups:SingleGroupDatagrid id=".." ..>
			...
			<MaxEntries>13</MaxEntries>
		</ExerciseGroups:SingleGroupDatagrid>
	*)
	SingleGroupDatagrid* = OBJECT(WebComplex.WebForum);
		VAR
			searchText: Strings.String;
			maxEntries: SIZE;

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR maxEntriesStr: Strings.String; elem: XML.Element;
		BEGIN
			elem := WebStd.GetXMLSubElement(input, "MaxEntries");
			maxEntries := MAX(SIZE);
			IF (elem # NIL) THEN
				maxEntriesStr := WebStd.GetXMLCharContent(elem);
				IF (maxEntriesStr # NIL) THEN
					Strings.StrToSize(maxEntriesStr^, maxEntries)
				END
			END;
			RETURN Transform^(input, request);
		END Transform;

		PROCEDURE GetHeaderXMLContent*(persContainer: WebStd.PersistentDataContainer; input: XML.Element;
			request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR dynStr: DynamicStrings.DynamicString; list: WebStd.PersistentDataObjectList; i: SIZE;
			str, encStr: Strings.String; person: Person; pTag, aTag: XML.Element; tempStr: ARRAY 10 OF CHAR;
		BEGIN  (* email to the whole group *)
			IF ((IsAuthorizedUser(request)) & (persContainer # NIL)) THEN
				list := persContainer.GetElementList(WebStd.DefaultPersistentDataFilter, NIL);
				IF (list # NIL)  THEN
					NEW(dynStr); COPY("mailto:", tempStr); dynStr.Append(tempStr);
					FOR i := 0 TO LEN(list)-1 DO
						IF ((list[i] #NIL) & (list[i] IS Person)) THEN
							person := list[i](Person);
							IF (person.email # NIL) THEN
								dynStr.Append(person.email^);
								IF (i < LEN(list)-1) THEN
									COPY(",", tempStr); dynStr.Append(tempStr)
								END
							END
						END
					END;
					str := dynStr.ToArrOfChar(); (* str # NIL *)
					NEW(pTag); pTag.SetName("p");
					NEW(aTag); aTag.SetName("a"); pTag.AddContent(aTag);
					encStr := WebStd.GetEncXMLAttributeText(str^); (* encStr # NIL *)
					aTag.SetAttributeValue("href", encStr^);
					WebStd.AppendXMLContent(aTag, WebStd.CreateXMLText(EmailToTheWholeGroup));
					RETURN pTag
				END
			END;
			RETURN NIL
		END GetHeaderXMLContent;

		PROCEDURE InsertObject*(container: WebStd.PersistentDataContainer; superEntry: WebComplex.WebForumEntry;
			request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
			(* parameters "firstname", "lastname", "email", "leginr"*)
		VAR firstname, lastname, email, leginr: Strings.String; obj: Person;
		BEGIN
			firstname := params.GetParameterValueByName("firstname");
			lastname := params.GetParameterValueByName("lastname");
			email := params.GetParameterValueByName("email");
			leginr := params.GetParameterValueByName("leginr");

			IF (container.GetCount() >= maxEntries) THEN
				statusMsg := WebStd.CreateXMLText(" Maxmimale Anzahl Leute pro Gruppe bereits ueberschritten.");
				RETURN FALSE
			ELSIF ((firstname = NIL) OR (firstname^ = "")) THEN
				statusMsg := WebStd.CreateXMLText(" Vorname fehlt");
				RETURN FALSE
			ELSIF ((lastname = NIL) OR (lastname^ = "")) THEN
				statusMsg := WebStd.CreateXMLText("Nachnahme fehlt");
				RETURN FALSE
			ELSIF ((email = NIL) OR (email ^ = "")) THEN
				statusMsg := WebStd.CreateXMLText("E-Mail fehlt");
				RETURN FALSE
			ELSIF ((leginr = NIL) OR (leginr ^ = "")) THEN
				statusMsg := WebStd.CreateXMLText("Legi Nummer fehlt");
				RETURN FALSE
			ELSE
				NEW(obj); obj.firstname := firstname; obj.lastname := lastname; obj.email := email; obj.leginr := leginr;
				container.AddPersistentDataObject(obj, personDesc); (* adds it also to the prevalence system *)
				RETURN TRUE
			END
		END InsertObject;

		PROCEDURE UpdateObject*(obj: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest;
			params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
		VAR firstname, lastname, email, leginr: Strings.String;  person: Person;
		BEGIN (* obj # NIL *)
			IF (obj IS Person) THEN
				person := obj(Person);
				firstname := params.GetParameterValueByName("firstname");
				lastname := params.GetParameterValueByName("lastname");
				email := params.GetParameterValueByName("email");
				leginr := params.GetParameterValueByName("leginr");

				IF ((firstname = NIL) OR (firstname^ = "")) THEN
					statusMsg := WebStd.CreateXMLText("Vornahme is missing");
					RETURN FALSE
				ELSIF ((lastname = NIL) OR (lastname^ = "")) THEN
					statusMsg := WebStd.CreateXMLText("Nachnahme fehlt");
					RETURN FALSE
				ELSIF ((email = NIL) OR (email ^ = "")) THEN
					statusMsg := WebStd.CreateXMLText("Email fehlt");
					RETURN FALSE
				ELSIF ((leginr = NIL) OR (leginr ^ = "")) THEN
					statusMsg := WebStd.CreateXMLText("Legi Nummer fehlt");
					RETURN FALSE
				END;
				person.BeginModification;
				person.firstname := firstname;
				person.lastname := lastname;
				person.email := email;
				person.leginr := leginr;
				person.EndModification;
				RETURN TRUE
			ELSE
				statusMsg := WebStd.CreateXMLText("object is not of type Person");
				RETURN FALSE
			END
		END UpdateObject;

		PROCEDURE ThisObjectName*() : Strings.String;
		BEGIN
			RETURN WebStd.GetString(SingleGroupDatagridName)
		END ThisObjectName;

		PROCEDURE ThisModuleName*() : Strings.String;
		BEGIN
			RETURN WebStd.GetString(ThisModuleNameStr)
		END ThisModuleName;

		(** returns the insert view for the initialization of a new web forum entry, without submit/back-input fields
		 * and without hidden parameter for super entry in hierarchy.
		 * superEntry is the parent web forum entry in a hierachical web forum, superEntry is NIL iff it is a root entry *)
		PROCEDURE GetInsertView*(superEntry: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest): XML.Content;
		VAR table: XML.Element;
		BEGIN
			NEW(table); table.SetName("table");
			WebComplex.AddTextFieldInputRow(table, "First name:", "firstname", NIL);
			WebComplex.AddTextFieldInputRow(table, "Last name:", "lastname", NIL);
			WebComplex.AddTextFieldInputRow(table, "Email: ", "email", NIL);
			WebComplex.AddTextFieldInputRow(table, "Legi-Nr: ", "leginr", NIL);
			RETURN table
		END GetInsertView;

		PROCEDURE GetTableHeader*(request: HTTPSupport.HTTPRequest): WebComplex.HeaderRow;
		VAR row: WebComplex.HeaderRow;
		BEGIN
			NEW(row, 6);
			row[0] := WebComplex.GetHeaderCellForText("Vorname", CompareFirstName);
			row[1] := WebComplex.GetHeaderCellForText("Nachnahme", CompareLastName);
			IF (IsAuthorizedUser(request)) THEN
				row[2] := WebComplex.GetHeaderCellForText("Email", CompareEmail);
				row[3] := WebComplex.GetHeaderCellForText("Legi Nummer", CompareLegiNr)
			ELSE
				row[2] := WebComplex.GetHeaderCellForText(" ", NIL);
				row[3] := WebComplex.GetHeaderCellForText(" ", NIL);
			END;
			row[4] := WebComplex.GetHeaderCellForText(" ", NIL);
			row[5] := WebComplex.GetHeaderCellForText(" ", NIL);
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
		VAR entry: Person;
			PROCEDURE Matches(VAR str: ARRAY OF CHAR) : BOOLEAN;
			VAR lowStr: Strings.String;
			BEGIN
				lowStr := WebStd.GetString(str);
				Strings.LowerCase(lowStr^);
				RETURN Strings.Match(searchText^, lowStr^)
			END Matches;
		BEGIN (* searchText # NIL *)
			IF (obj IS Person) THEN
				entry := obj(Person);
				IF ((entry.firstname # NIL) & (Matches(entry.firstname^))) THEN
					RETURN TRUE
				END;
				IF ((entry.lastname # NIL) & (Matches(entry.lastname^))) THEN
					RETURN TRUE
				END;
				IF ((entry.email # NIL) & (Matches(entry.email^))) THEN
					RETURN TRUE
				END;
				IF ((entry.leginr # NIL) & (Matches(entry.leginr^))) THEN
					RETURN TRUE
				END;
			END;
			RETURN FALSE
		END SearchFilter;

		PROCEDURE GetDefaultOrdering*() : WebStd.PersistentDataCompare;
		BEGIN RETURN CompareLastName
		END GetDefaultOrdering;

		PROCEDURE GetEmptyListMessage*(request: HTTPSupport.HTTPRequest) : XML.Container;
		BEGIN
			RETURN WebStd.CreateXMLText(EmptyListText);
		END GetEmptyListMessage;

		PROCEDURE GetBackButtonLabel*(request: HTTPSupport.HTTPRequest) : Strings.String;
		BEGIN RETURN WebStd.GetString(BackButtonLabel)
		END GetBackButtonLabel;

		PROCEDURE GetInsertLinkLabel*(request: HTTPSupport.HTTPRequest) : Strings.String;
		BEGIN RETURN WebStd.GetString(InsertToGroupLabel);
		END GetInsertLinkLabel;

		PROCEDURE GetSubmitButtonLabel*(request: HTTPSupport.HTTPRequest): Strings.String;
		BEGIN RETURN WebStd.GetString(SubmitButtonLabel)
		END GetSubmitButtonLabel;

		PROCEDURE GetUnapplySortLabel*(request: HTTPSupport.HTTPRequest): Strings.String;
		BEGIN RETURN WebStd.GetString(UnapplySortLabel)
		END GetUnapplySortLabel;

		PROCEDURE GetUnapplyFilterLabel*(request: HTTPSupport.HTTPRequest): Strings.String;
		BEGIN RETURN WebStd.GetString(UnapplyFilterLabel)
		END GetUnapplyFilterLabel;

		PROCEDURE CompareFirstName(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: Person;
		BEGIN
			IF ((obj1 IS Person) & (obj2 IS Person)) THEN
				f1 := obj1(Person); f2 := obj2(Person);
				IF (f2.firstname = NIL) THEN
					RETURN FALSE
				ELSIF (f1.firstname = NIL) THEN (* f2.firstname # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.firstname^ < f2.firstname^
				END
			ELSE
				RETURN FALSE
			END
		END CompareFirstName;

		PROCEDURE CompareEmail(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: Person;
		BEGIN
			IF ((obj1 IS Person) & (obj2 IS Person)) THEN
				f1 := obj1(Person); f2 := obj2(Person);
				IF (f2.email = NIL) THEN
					RETURN FALSE
				ELSIF (f1.email = NIL) THEN (* f2.email # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.email^ < f2.email^
				END
			ELSE
				RETURN FALSE
			END
		END CompareEmail;

		PROCEDURE CompareLegiNr(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: Person;
		BEGIN
			IF ((obj1 IS Person) & (obj2 IS Person)) THEN
				f1 := obj1(Person); f2 := obj2(Person);
				IF (f2.leginr = NIL) THEN
					RETURN FALSE
				ELSIF (f1.leginr = NIL) THEN (* f2.leginr # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.leginr^ < f2.leginr^
				END
			ELSE
				RETURN FALSE
			END
		END CompareLegiNr;
	END SingleGroupDatagrid;

	Group* = OBJECT(WebComplex.WebForumEntry);
		VAR
			name: Strings.String;
			assistant: Strings.String;
			date: Strings.String;
			place: Strings.String;
			info: Strings.String;
			openToJoin: BOOLEAN; (* true if public insertion to the group is possible *)
			maxPeople: SIZE; (* maximum number of group members *)
			members: WebStd.PersistentDataContainer; (* PersistentDataContainer of Person *)
			membersDgId: Strings.String; (* id of the members single group web datagrid *)
			gradesEditListId: Strings.String; (* id of the grades edit list for the members exercises *)
			toggleBlockId: Strings.String; (* id of the toggle block in the detail view *)

		PROCEDURE &Initialize*;
		BEGIN Init; (* call super initializer *)
			membersDgId := DynamicWebpage.CreateNewObjectId(); (* membersDgId # NIL *)
			gradesEditListId := DynamicWebpage.CreateNewObjectId(); (* gradesEditListId # NIL *)
			toggleBlockId := DynamicWebpage.CreateNewObjectId() (* toggleBlockId # NIL *)
		END Initialize;

		PROCEDURE Internalize*(input: XML.Content);
		VAR container: XML.Container; elem: XML.Element; oidStr: Strings.String;
			persObj: PrevalenceSystem.PersistentObject; oidNr: SIGNED32;
		BEGIN
			container := input(XML.Container);

			(* element specific fields *)

			elem := WebStd.GetXMLSubElement(container, "Members");
			members := NIL;
			IF (elem # NIL) THEN
				oidStr := WebStd.GetXMLCharContent(elem);
				IF (oidStr # NIL) THEN
					Strings.StrToInt(oidStr^, oidNr);
					persObj := PrevalenceSystem.GetPersistentObject(oidNr);
					IF ((persObj # NIL) & (persObj IS WebStd.PersistentDataContainer)) THEN
						members := persObj(WebStd.PersistentDataContainer)
					ELSE
						HALT(9999)
					END
				END
			END;
			name := WebStd.InternalizeString(container, "Name");
			info := WebStd.InternalizeString(container, "Info");
			assistant := WebStd.InternalizeString(container, "Assistant");
			date := WebStd.InternalizeString(container, "Date");
			place := WebStd.InternalizeString(container, "Place");
			openToJoin := WebStd.InternalizeBoolean(container, "Open");
			maxPeople := WebStd.InternalizeInteger(container, "MaxPeople");
		END Internalize;

		PROCEDURE Externalize*() : XML.Content;
		VAR container: XML.Container; elem: XML.Element; oidStr: ARRAY 14 OF CHAR;
		BEGIN
			NEW(container);

			(* element specific fields *)

			IF (members # NIL) THEN
				NEW(elem); elem.SetName("Members");
				Strings.IntToStr(members.oid, oidStr);
				WebStd.AppendXMLContent(elem, WebStd.CreateXMLText(oidStr));
				container.AddContent(elem)
			END;

			WebStd.ExternalizeString(name, container, "Name");
			WebStd.ExternalizeString(info, container, "Info");
			WebStd.ExternalizeString(assistant, container, "Assistant");
			WebStd.ExternalizeString(date, container, "Date");
			WebStd.ExternalizeString(place, container, "Place");
			WebStd.ExternalizeBoolean(openToJoin, container, "Open");
			WebStd.ExternalizeInteger(maxPeople, container, "MaxPeople");
			RETURN container
		END Externalize;

		PROCEDURE GetReferrencedObjects*() : PrevalenceSystem.PersistentObjectList;
		VAR list: PrevalenceSystem.PersistentObjectList;
		BEGIN
			NEW(list, 1);
			list[0] := members;
			RETURN list
		END GetReferrencedObjects;

		PROCEDURE UpdateGrade(personOid, exerciseNo, newGrade: SIGNED32);
		VAR list: WebStd.PersistentDataObjectList; person: Person; i: SIZE; oldGrade: SIGNED32;
		BEGIN
			IF (members # NIL) THEN
				list := members.GetElementList(WebStd.DefaultPersistentDataFilter, NIL);
				IF (list # NIL) THEN
					FOR i := 0 TO LEN(list)-1 DO
						IF ((list[i].oid = personOid) & (list[i] IS Person)) THEN
							person := list[i](Person);
							IF (person.grades # NIL) THEN
								oldGrade := person.grades.GetItem(exerciseNo);
								IF (oldGrade # newGrade) THEN
									person.BeginModification;
									person.grades.Exchange(exerciseNo, newGrade);
									person.EndModification
								END
							END
						END
					END
				END
			END
		END UpdateGrade;

		(* returns the number of free places as string # NIL *)
		PROCEDURE GetFreePlaces() : Strings.String;
		VAR free: SIZE; maxPeopleStr: Strings.String;
		BEGIN
			IF (members # NIL) THEN
				free := maxPeople-members.GetCount()
			ELSE
				free := maxPeople;
			END;
			NEW(maxPeopleStr, 14); Strings.IntToStr(free, maxPeopleStr^);
			RETURN maxPeopleStr
		END GetFreePlaces;

		PROCEDURE TableView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : WebComplex.TableRow;
		VAR row: WebComplex.TableRow;
		BEGIN
			NEW(row, 8);
			row[0] := WebComplex.GetTableCell(name, WebComplex.WebForumDetailViewCell);
			row[1] := WebComplex.GetTableCell(assistant, WebComplex.WebForumNormalCell);
			row[2] := WebComplex.GetTableCell(date, WebComplex.WebForumNormalCell);
			row[3] := WebComplex.GetTableCell(place, WebComplex.WebForumNormalCell);
			row[4] := WebComplex.GetTableCell(info, WebComplex.WebForumNormalCell);
			row[5] := WebComplex.GetTableCell(GetFreePlaces(), WebComplex.WebForumNormalCell);
			row[6] := WebComplex.GetTableCellForText("Aendern", WebComplex.WebForumEditViewCell);
			row[7] := WebComplex.GetTableCellForText("Loeschen", WebComplex.WebForumDeleteCell);
			RETURN row
		END TableView;

		PROCEDURE DetailView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR container: XML.Container; toggleBlock, show, hide: XML.Element;
		BEGIN
			NEW(container);
			WebComplex.AddStandardDetailView(container, "Name: ", name);
			WebComplex.AddStandardDetailView(container, "Assistent: ", assistant);
			WebComplex.AddStandardDetailView(container, "Zeit: ", date);
			WebComplex.AddStandardDetailView(container, "Ort: ", place);
			WebComplex.AddStandardDetailView(container, "Information: ", info);
			WebComplex.AddStandardDetailView(container, "Freie Plaetze: ", GetFreePlaces());

			IF ((forum # NIL) & (forum.allowEdit)) THEN
				(* use active element
				 * <WebStd:ToggleBlock id=".." startWith="Hide" showLabel="$EditExerciseGradesLabel"
				       hideLabel="$CloseExerciseGradesLabel">
				     	<Show>
				     		GetGradesEditListView(..)
				     	</Show>
				     	<Hide>
				     		GetSingleGroupDatagridView(..)
				     	</Hide>
				    </WebStd:ToggleBlock> *)
				NEW(toggleBlock); toggleBlock.SetName("WebStd:ToggleBlock"); container.AddContent(toggleBlock);
				toggleBlock.SetAttributeValue("xmlns:WebStd", "WebStd");
				toggleBlock.SetAttributeValue("id", toggleBlockId^);
				toggleBlock.SetAttributeValue("startWith", "Hide");
				toggleBlock.SetAttributeValue("showLabel", EditExerciseGradesLabel);
				toggleBlock.SetAttributeValue("hideLabel", CloseExerciseGradesLabel);
				NEW(show); show.SetName("Show"); toggleBlock.AddContent(show);
				WebStd.AppendXMLContent(show, GetGradesEditListView(forum, request));
				NEW(hide); hide.SetName("Hide"); toggleBlock.AddContent(hide);
				WebStd.AppendXMLContent(hide, GetSingleGroupDatagridView(forum, request));
			ELSE
				WebStd.AppendXMLContent(container, GetSingleGroupDatagridView(forum, request));
			END;
			RETURN container
		END DetailView;

		PROCEDURE GetGradesEditListView(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR table, tr, td, gradesEditList: XML.Element; groupOidStr: ARRAY 14 OF CHAR;
		BEGIN
			IF ((forum # NIL) & (forum.allowEdit)) THEN
				NEW(table); table.SetName("table"); table.SetAttributeValue("border", "1");
				NEW(tr); tr.SetName("tr"); table.AddContent(tr);
				NEW(td); td.SetName("td"); tr.AddContent(td);
				(* display grades edit list *)
				(* use active element
				 *	<ExerciseGroups:GradesEditList id=".." groupoid=".." prevalencesystem=".."/> *)
				 Strings.IntToStr(SELF.oid, groupOidStr);
				 NEW(gradesEditList); gradesEditList.SetName("ExerciseGroups:GradesEditList");
				 gradesEditList.SetAttributeValue("xmlns:ExerciseGroups", ThisModuleNameStr);
				 gradesEditList.SetAttributeValue("id", gradesEditListId^);
				 gradesEditList.SetAttributeValue("groupoid", groupOidStr);
				 td.AddContent(gradesEditList);
				 RETURN table
			ELSE
				RETURN NIL
			END
		END GetGradesEditListView;

		PROCEDURE GetSingleGroupDatagridView(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR table, tr, td, accountDg, searching, accessConstraint, edit, insert, delete, denied, maxEntries: XML.Element;
			membersName: Strings.String; allGroupsDg: AllGroupsDatagrid; maxPeopleStr: ARRAY 14 OF CHAR;
		BEGIN
			IF (members # NIL) THEN
				membersName := members.GetName();
				IF (membersName # NIL) THEN
					NEW(table); table.SetName("table"); table.SetAttributeValue("border", "1");
					NEW(tr); tr.SetName("tr"); table.AddContent(tr);
					NEW(td); td.SetName("td"); tr.AddContent(td);
					(* use active element
					 *	<ExerciseGroups:SingleGroupDatagrid id=".." containername=".." prevalencesystem=".." [reinitilize="true"]>
					 *       <Searching label=".."/>
					 *       <AccessConstraint>..</AccessConstraint>
					 *    </ExerciseGroups:SingleGroupDatagrid>
					 * access constraint is the same for the actual datagrid
					 *)
					NEW(accountDg); accountDg.SetName("ExerciseGroups:SingleGroupDatagrid");
					accountDg.SetAttributeValue("xmlns:ExerciseGroups", ThisModuleNameStr);
					accountDg.SetAttributeValue("id", membersDgId^);
					accountDg.SetAttributeValue("containername", membersName^);
					(*
					NEW(paging); paging.SetName("Paging"); accountDg.AddContent(paging);
					paging.SetAttributeValue("size", "10");
					paging.SetAttributeValue("nextlabel", NextButtonLabel);
					paging.SetAttributeValue("previouslabel", BackButtonLabel);
					*)
					NEW(searching); searching.SetName("Searching"); accountDg.AddContent(searching);
					searching.SetAttributeValue("label", SearchText);
					NEW(maxEntries); maxEntries.SetName("MaxEntries"); accountDg.AddContent(maxEntries);
					Strings.IntToStr(maxPeople, maxPeopleStr);
					WebStd.AppendXMLContent(maxEntries, WebStd.CreateXMLText(maxPeopleStr));
					NEW(accessConstraint); accessConstraint.SetName("AccessConstraint"); accountDg.AddContent(accessConstraint);
					insert := NIL; edit := NIL; delete := NIL;
					IF ((forum # NIL) & (forum IS AllGroupsDatagrid)) THEN
						allGroupsDg := forum(AllGroupsDatagrid);
						IF (allGroupsDg.accessConstraint # NIL) THEN
							insert := WebStd.GetXMLSubElement(allGroupsDg.accessConstraint, "Insert");
							edit := WebStd.GetXMLSubElement(allGroupsDg.accessConstraint, "Edit");
							delete := WebStd.GetXMLSubElement(allGroupsDg.accessConstraint, "Delete")
						END;
						(* user could have used the back button in the browser's navigation bar, therefore reinitialize subcontainer
					 	* if detail view has just been activated *)
						IF (allGroupsDg.reInitializeSubContainer) THEN
							accountDg.SetAttributeValue("reinitialize", "true")
						END;
						allGroupsDg.reInitializeSubContainer := FALSE
					END;
					IF (openToJoin) THEN
						(* allow public insertion to the group, delete access constraint *)
						insert := NIL
					END;
					IF ((members # NIL) & (members.GetCount() >= maxPeople)) THEN
						(* deny insertion *)
						NEW(insert); insert.SetName("Insert");
						NEW(denied); denied.SetName("Denied"); insert.AddContent(denied)
					END;
					IF (insert # NIL) THEN
						accessConstraint.AddContent(insert)
					END;
					IF (edit # NIL) THEN
						accessConstraint.AddContent(edit)
					END;
					IF (delete # NIL) THEN
						accessConstraint.AddContent(delete)
					END;
					td.AddContent(accountDg);
					RETURN table
				ELSE
					RETURN WebStd.CreateXMLText("no members container name defined.")
				END
			ELSE
				RETURN WebStd.CreateXMLText("no members container present.")
			END
		END GetSingleGroupDatagridView;

		PROCEDURE EditView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR table, tr, td, select, option: XML.Element; maxPeopleStr: Strings.String;
		BEGIN
			NEW(table); table.SetName("table");
			WebComplex.AddTextFieldInputRow(table, "Name", "name", name);
			WebComplex.AddTextFieldInputRow(table, "Assistent: ", "assistant", assistant);
			WebComplex.AddTextFieldInputRow(table, "Zeit: ", "date", date);
			WebComplex.AddTextFieldInputRow(table, "Ort: ", "place", place);
			WebComplex.AddTextFieldInputRow(table, "Information: ", "info", info);
			NEW(maxPeopleStr, 14); Strings.IntToStr(maxPeople, maxPeopleStr^);
			WebComplex.AddTextFieldInputRow(table, "Maxmimale Platze: ", "maxpeople", maxPeopleStr);

			NEW(tr); tr.SetName("tr"); table.AddContent(tr);
			NEW(td); td.SetName("td"); tr.AddContent(td);
			WebStd.AppendXMLContent(td, WebStd.CreateXMLText("Offen zum Einschreiben: "));
			NEW(td); td.SetName("td"); tr.AddContent(td);

			NEW(select); select.SetName("select"); td.AddContent(select);
			select.SetAttributeValue("name", "opentojoin");

			NEW(option); option.SetName("option"); select.AddContent(option);
			option.SetAttributeValue("value", "true");
			WebStd.AppendXMLContent(option, WebStd.CreateXMLText("Ja"));
			IF (openToJoin) THEN option.SetAttributeValue("selected", "true") END;

			NEW(option); option.SetName("option"); select.AddContent(option);
			option.SetAttributeValue("value", "false");
			WebStd.AppendXMLContent(option, WebStd.CreateXMLText("Nein"));
			IF (~openToJoin) THEN option.SetAttributeValue("selected", "true") END;

			RETURN table
		END EditView;

		(* add a new exercise for all group members and initialize their grade for this new exercise with 0 *)
		PROCEDURE AddNewExercise;
		VAR list: WebStd.PersistentDataObjectList; i: SIZE; person: Person;
		BEGIN
			IF (members # NIL) THEN
				list := members.GetElementList(WebStd.DefaultPersistentDataFilter, NIL);
				FOR i := 0 TO LEN(list)-1 DO
					IF (list[i] IS Person) THEN
						person := list[i](Person);
						person.BeginModification;
						IF (person.grades = NIL) THEN NEW(person.grades) END;
						person.grades.Add(0);
						person.EndModification
					END
				END
			END
		END AddNewExercise;

		(* delete the exercise number 'pos' for all group members *)
		PROCEDURE DeleteExercise(pos: SIZE);
		VAR list: WebStd.PersistentDataObjectList; i: SIZE; person: Person;
		BEGIN
			IF (members # NIL) THEN
				list := members.GetElementList(WebStd.DefaultPersistentDataFilter, NIL);
				FOR i := 0 TO LEN(list)-1 DO
					IF (list[i] IS Person) THEN
						person := list[i](Person);
						IF (person.grades # NIL) THEN
							person.BeginModification;
							person.grades.Remove(pos);
							person.EndModification
						END
					END
				END
			END
		END DeleteExercise;
	END Group;

	(** statefull active element *)
	AllGroupsDatagrid* = OBJECT(WebComplex.WebForum);
		VAR
			searchText: Strings.String;
			accessConstraint: XML.Element; (* used for nested datagrid *)
			reInitializeSubContainer: BOOLEAN; (* true if the subcontainer has to be reinitialized*)
			(* user could use the back button in browser's navigation bar *)

		PROCEDURE &Init*;
		BEGIN Init^; reInitializeSubContainer := FALSE
		END Init;

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		BEGIN
			(* get the access constraint for later propagation to the nested SingleGroupDatagrid *)
			accessConstraint := WebStd.GetXMLSubElement(input, "AccessConstraint");
			RETURN Transform^(input, request)
		END Transform;

		PROCEDURE InsertObject*(container: WebStd.PersistentDataContainer; superEntry: WebComplex.WebForumEntry;
			request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
			(* parameters "name", "info", "assistant", "date", "place", "maxpeople", "opentojoin" *)
		VAR name, info, assistant, date, place, maxpeople, opentojoin, containername: Strings.String; obj: Group;
		BEGIN
			name := params.GetParameterValueByName("name");
			info := params.GetParameterValueByName("info");
			assistant := params.GetParameterValueByName("assistant");
			date := params.GetParameterValueByName("date");
			place := params.GetParameterValueByName("place");
			maxpeople := params.GetParameterValueByName("maxpeople");
			opentojoin := params.GetParameterValueByName("opentojoin");

			IF ((name # NIL) & (name^ # "")) THEN
				NEW(containername, Strings.Length(name^)+Strings.Length(AllGroupsContainerPrefixName)+1);
				Strings.Concat(AllGroupsContainerPrefixName, name^, containername^);
				(* check conflict with another container *)
				IF (WebStd.FindPersistentDataContainer(PrevalenceSystem.standardPrevalenceSystem, containername^) # NIL) THEN
					statusMsg := WebStd.CreateXMLText("Gruppenname bereits verwendet");
					RETURN FALSE
				END;

				NEW(obj); obj.name := name; obj.info := info; obj.assistant := assistant; obj.date := date; obj.place := place;
				IF (maxpeople # NIL) THEN
					Strings.StrToSize(maxpeople^, obj.maxPeople)
				ELSE
					obj.maxPeople := 0
				END;
				IF ((opentojoin # NIL) & (opentojoin^ = "true")) THEN
					obj.openToJoin := TRUE
				ELSE
					obj.openToJoin := FALSE
				END;
				container.AddPersistentDataObject(obj, groupDesc); (* adds it also to the prevalence system *)
				obj.BeginModification;
				NEW(obj.members);
				PrevalenceSystem.AddPersistentObject(obj.members, WebStd.persistentDataContainerDesc);
				obj.EndModification;

				obj.members.SetName(containername^);
				RETURN TRUE
			ELSE
				statusMsg := WebStd.CreateXMLText("Name fehlt");
				RETURN FALSE
			END
		END InsertObject;

		PROCEDURE UpdateObject*(obj: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest;
			params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
			(* parameters "name", "info", "assistant", "date", "place", "maxpeople", "opentojoin" *)
		VAR name, info, assistant, date, place, maxpeople, opentojoin: Strings.String; group: Group;
		BEGIN (* obj # NIL *)
			IF (obj IS Group) THEN
				group := obj(Group);
				name := params.GetParameterValueByName("name");
				info := params.GetParameterValueByName("info");
				assistant := params.GetParameterValueByName("assistant");
				date := params.GetParameterValueByName("date");
				place := params.GetParameterValueByName("place");
				maxpeople := params.GetParameterValueByName("maxpeople");
				opentojoin := params.GetParameterValueByName("opentojoin");

				IF ((name # NIL) & (name^ # "")) THEN
					group.BeginModification;
					group.name := name; group.info := info; group.assistant := assistant; group.date := date; group.place := place;
					IF (maxpeople # NIL) THEN
						Strings.StrToSize(maxpeople^, group.maxPeople)
					ELSE
						group.maxPeople := 0
					END;
					IF ((opentojoin # NIL) & (opentojoin^ = "true")) THEN
						group.openToJoin := TRUE
					ELSE
						group.openToJoin := FALSE
					END;
					group.EndModification;
					RETURN TRUE
				ELSE
					statusMsg := WebStd.CreateXMLText("Name fehlt");
					RETURN FALSE
				END
			ELSE
				statusMsg := WebStd.CreateXMLText("object is not of type Group");
				RETURN FALSE
			END
		END UpdateObject;

		PROCEDURE ThisObjectName*() : Strings.String;
		BEGIN
			RETURN WebStd.GetString(AllGroupsDatagridName)
		END ThisObjectName;

		PROCEDURE ThisModuleName*() : Strings.String;
		BEGIN
			RETURN WebStd.GetString(ThisModuleNameStr)
		END ThisModuleName;

		(** abstract, returns the insert view for the initialization of a new web forum entry, without submit/back-input fields
		 * and without hidden parameter for super entry in hierarchy.
		 * superEntry is the parent web forum entry in a hierachical web forum, superEntry is NIL iff it is a root entry *)
		PROCEDURE GetInsertView*(superEntry: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest): XML.Content;
		VAR table, tr, td, select, option: XML.Element;
		BEGIN
			NEW(table); table.SetName("table");
			WebComplex.AddTextFieldInputRow(table, "Name: ", "name", NIL);
			WebComplex.AddTextFieldInputRow(table, "Assistent: ", "assistant", NIL);
			WebComplex.AddTextFieldInputRow(table, "Zeit: ", "date", NIL);
			WebComplex.AddTextFieldInputRow(table, "Ort: ", "place", NIL);
			WebComplex.AddTextFieldInputRow(table, "Information: ", "info", NIL);

			WebComplex.AddTextFieldInputRow(table, "Maxmimale Platze: ", "maxpeople", NIL);

			NEW(tr); tr.SetName("tr"); table.AddContent(tr);
			NEW(td); td.SetName("td"); tr.AddContent(td);
			WebStd.AppendXMLContent(td, WebStd.CreateXMLText("Offen zum Einschreiben: "));
			NEW(td); td.SetName("td"); tr.AddContent(td);

			NEW(select); select.SetName("select"); td.AddContent(select);
			select.SetAttributeValue("name", "opentojoin");

			NEW(option); option.SetName("option"); select.AddContent(option);
			option.SetAttributeValue("value", "true");
			WebStd.AppendXMLContent(option, WebStd.CreateXMLText("Ja"));

			NEW(option); option.SetName("option"); select.AddContent(option);
			option.SetAttributeValue("value", "false");
			WebStd.AppendXMLContent(option, WebStd.CreateXMLText("Nein"));

			RETURN table
		END GetInsertView;

		PROCEDURE OnDetailViewActivated*(entryOid: SIGNED32; request: HTTPSupport.HTTPRequest);
		BEGIN reInitializeSubContainer := TRUE (* the sub container has to showed in the default mode *)
		END OnDetailViewActivated;

		PROCEDURE GetTableHeader*(request: HTTPSupport.HTTPRequest): WebComplex.HeaderRow;
		VAR row: WebComplex.HeaderRow;
		BEGIN
			NEW(row, 8);
			row[0] := WebComplex.GetHeaderCellForText("Name", CompareName);
			row[1] := WebComplex.GetHeaderCellForText("Assistent", CompareAssistant);
			row[2] := WebComplex.GetHeaderCellForText("Zeit", CompareDate);
			row[3] := WebComplex.GetHeaderCellForText("Ort", ComparePlace);
			row[4] := WebComplex.GetHeaderCellForText("Information", CompareInfo);
			row[5] := WebComplex.GetHeaderCellForText("Freie Plaetze", CompareInfo);
			row[6] := WebComplex.GetHeaderCellForText(" ", NIL);
			row[7] := WebComplex.GetHeaderCellForText(" ", NIL);
			RETURN row
		END GetTableHeader;

		PROCEDURE GetEmptyListMessage*(request: HTTPSupport.HTTPRequest) : XML.Container;
		BEGIN
			RETURN WebStd.CreateXMLText(EmptyListText);
		END GetEmptyListMessage;

		PROCEDURE GetBackButtonLabel*(request: HTTPSupport.HTTPRequest) : Strings.String;
		BEGIN RETURN WebStd.GetString(BackButtonLabel)
		END GetBackButtonLabel;

		PROCEDURE GetInsertLinkLabel*(request: HTTPSupport.HTTPRequest) : Strings.String;
		BEGIN RETURN WebStd.GetString(InsertGroupText)
		END GetInsertLinkLabel;

		PROCEDURE GetSubmitButtonLabel*(request: HTTPSupport.HTTPRequest): Strings.String;
		BEGIN RETURN WebStd.GetString(SubmitButtonLabel)
		END GetSubmitButtonLabel;

		PROCEDURE GetUnapplySortLabel*(request: HTTPSupport.HTTPRequest): Strings.String;
		BEGIN RETURN WebStd.GetString(UnapplySortLabel)
		END GetUnapplySortLabel;

		PROCEDURE GetUnapplyFilterLabel*(request: HTTPSupport.HTTPRequest): Strings.String;
		BEGIN RETURN WebStd.GetString(UnapplyFilterLabel)
		END GetUnapplyFilterLabel;

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
		VAR entry: Group;
			PROCEDURE Matches(VAR str: ARRAY OF CHAR) : BOOLEAN;
			VAR lowStr: Strings.String;
			BEGIN
				lowStr := WebStd.GetString(str);
				Strings.LowerCase(lowStr^);
				RETURN Strings.Match(searchText^, lowStr^)
			END Matches;
		BEGIN (* searchText # NIL *)
			IF (obj IS Group) THEN
				entry := obj(Group);
				IF ((entry.name # NIL) & (Matches(entry.name^))) THEN
					RETURN TRUE
				END;
				IF ((entry.assistant # NIL) & (Matches(entry.assistant^))) THEN
					RETURN TRUE
				END;
				IF ((entry.date # NIL) & (Matches(entry.date^))) THEN
					RETURN TRUE
				END;
				IF ((entry.place # NIL) & (Matches(entry.place^))) THEN
					RETURN TRUE
				END;
				IF ((entry.info # NIL) & (Matches(entry.info^))) THEN
					RETURN TRUE
				END
			END;
			RETURN FALSE
		END SearchFilter;

		PROCEDURE CompareName(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: Group;
		BEGIN
			IF ((obj1 IS Group) & (obj2 IS Group)) THEN
				f1 := obj1(Group); f2 := obj2(Group);
				IF (f2.name = NIL) THEN
					RETURN FALSE
				ELSIF (f1.name = NIL) THEN (* f2.name # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.name^ < f2.name^
				END
			ELSE
				RETURN FALSE
			END
		END CompareName;

		PROCEDURE CompareAssistant(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: Group;
		BEGIN
			IF ((obj1 IS Group) & (obj2 IS Group)) THEN
				f1 := obj1(Group); f2 := obj2(Group);
				IF (f2.assistant = NIL) THEN
					RETURN FALSE
				ELSIF (f1.assistant = NIL) THEN (* f2.assistant # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.assistant^ < f2.assistant^
				END
			ELSE
				RETURN FALSE
			END
		END CompareAssistant;

		PROCEDURE CompareDate(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: Group;
		BEGIN
			IF ((obj1 IS Group) & (obj2 IS Group)) THEN
				f1 := obj1(Group); f2 := obj2(Group);
				IF (f2.date = NIL) THEN
					RETURN FALSE
				ELSIF (f1.date = NIL) THEN (* f2.date # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.date^ < f2.date^
				END
			ELSE
				RETURN  FALSE
			END
		END CompareDate;

		PROCEDURE ComparePlace(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: Group;
		BEGIN
			IF ((obj1 IS Group) & (obj2 IS Group)) THEN
				f1 := obj1(Group); f2 := obj2(Group);
				IF (f2.place = NIL) THEN
					RETURN FALSE
				ELSIF (f1.place = NIL) THEN (* f2.place # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.place^ < f2.place^
				END
			ELSE
				RETURN FALSE
			END
		END ComparePlace;

		PROCEDURE CompareInfo(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: Group;
		BEGIN
			IF ((obj1 IS Group) & (obj2 IS Group)) THEN
				f1 := obj1(Group); f2 := obj2(Group);
				IF (f2.info = NIL) THEN
					RETURN FALSE
				ELSIF (f1.info = NIL) THEN (* f2.info # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.info^ < f2.info^
				END
			ELSE
				RETURN FALSE
			END
		END CompareInfo;
	END AllGroupsDatagrid;

	(** statefull exercise grades edit list for a group
	 * <ExerciseGroups:GradesEditList id="MyGradesEditList3" groupoid=".." prevalencesystem=".."/>
	 *)
	GradesEditList* = OBJECT(DynamicWebpage.StateFullActiveElement);
		VAR
			group: Group;

		PROCEDURE &Init*;
		BEGIN group := NIL
		END Init;

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR groupOid: SIGNED32; groupOidStr, prevSysName: Strings.String; persObj: PrevalenceSystem.PersistentObject;
			prevSys: PrevalenceSystem.PrevalenceSystem;
		BEGIN
			groupOidStr := input.GetAttributeValue("groupoid");
			prevSysName := input.GetAttributeValue("prevalencesystem");
			(* get the prevalence system *)
			IF (prevSysName # NIL) THEN
				prevSys := PrevalenceSystem.GetPrevalenceSystem(prevSysName^)
			ELSE
				prevSys := PrevalenceSystem.standardPrevalenceSystem
			END;

			IF ((groupOidStr # NIL) & (prevSys # NIL)) THEN
				Strings.StrToInt(groupOidStr^, groupOid);
				persObj := prevSys.GetPersistentObject(groupOid);
				IF ((persObj # NIL) & (persObj IS Group)) THEN
					group := persObj(Group);
					RETURN TransformForGroup(input, request)
				ELSE
					RETURN WebStd.CreateXMLText("ExerciseGroups:GradesEditList - The specified 'groupoid' does not refer to a valid group")
				END
			ELSE
				RETURN WebStd.CreateXMLText("ExerciseGroups:GradesEditList - need attribute 'groupoid' and a name of a valid prevalence system");
			END
		END Transform;

		PROCEDURE TransformForGroup(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR container: XML.Container; objectId: Strings.String; formular, htmlInput, pTag, label, eventLink: XML.Element;
		BEGIN (* group # NIL *)
			objectId := input.GetAttributeValue(DynamicWebpage.XMLAttributeObjectIdName); (* objectId # NIL *)

			NEW(container);

			NEW(pTag); pTag.SetName("p"); container.AddContent(pTag);
			NEW(eventLink); eventLink.SetName("WebStd:EventLink");
			eventLink.SetAttributeValue("xmlns:WebStd", "WebStd");
			NEW(label); label.SetName("Label"); pTag.AddContent(eventLink);
			WebStd.AppendXMLContent(label, WebStd.CreateXMLText(AddNewExerciseLabel));
			eventLink.AddContent(label);
			eventLink.SetAttributeValue("method", "AddNewExercise");
			eventLink.SetAttributeValue("object", "GradesEditList");
			eventLink.SetAttributeValue("module", ThisModuleNameStr);
			eventLink.SetAttributeValue("objectid", objectId^);

			NEW(formular); formular.SetName("WebStd:Formular"); container.AddContent(formular);
			formular.SetAttributeValue("xmlns:WebStd", "WebStd");
			formular.SetAttributeValue("method", "UpdateList");
			formular.SetAttributeValue("object", "GradesEditList");
			formular.SetAttributeValue("module", ThisModuleNameStr);
			formular.SetAttributeValue("objectid", objectId^);

			WebStd.AppendXMLContent(formular, GetGradesEditView(objectId, CompareLastName));

			NEW(htmlInput); htmlInput.SetName("input"); formular.AddContent(htmlInput);
			htmlInput.SetAttributeValue("type", "submit");
			htmlInput.SetAttributeValue("name", "submitbutton");
			htmlInput.SetAttributeValue("value", SubmitButtonLabel);

			RETURN container
		END TransformForGroup;

		(* get the edit view for all grades of all exercise group members *)
		PROCEDURE GetGradesEditView(objectId: Strings.String; activeOrdering: WebStd.PersistentDataCompare) : XML.Content;
		VAR table: XML.Element; list: WebStd.PersistentDataObjectList; i, k, nofCols: SIZE; person: Person;
		BEGIN (* group # NIL *)
			IF (group.members # NIL) THEN
				nofCols := 0;
				list := group.members.GetElementList(WebStd.DefaultPersistentDataFilter, activeOrdering);
				IF (list # NIL) THEN
					(* first determine the maximum number of columns *)
					FOR i := 0 TO LEN(list)-1 DO (* list[i] # NIL *)
						IF (list[i] IS Person)  THEN
							person := list[i](Person);
							IF (person.grades # NIL) THEN
								person.grades.Lock; k := person.grades.GetCount(); person.grades.Unlock
							END;
							IF (k > nofCols) THEN nofCols := k END
						END
					END;
					IF (nofCols > 0) THEN
						NEW(table); table.SetName("table");
						table.AddContent(GetExerciseListHeaderRow(objectId, TRUE, nofCols));
						FOR i := 0 TO LEN(list)-1 DO
							IF (list[i] IS Person) THEN
								person := list[i](Person);
								table.AddContent(GetPersonGradesEditRow(nofCols, person))
							END
						END;
						RETURN table
					END
				END
			END;
			RETURN NIL
		END GetGradesEditView;

		(* get XHTML table header row for the exercise grade list. If 'allowDelete' is true then the exercise can be deleted *)
		PROCEDURE GetExerciseListHeaderRow(objectId: Strings.String; allowDelete: BOOLEAN;
			nofCols: SIZE) : XML.Element;
		VAR tr, td, eventLink, eventParam, label, br: XML.Element; i: SIZE; iStr: ARRAY 14 OF CHAR;
			str: Strings.String;
		BEGIN
			IF(nofCols > 0) THEN
				NEW(tr); tr.SetName("tr");
				NEW(td); td.SetName("td"); tr.AddContent(td);
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText("Last name"));
				NEW(td); td.SetName("td"); tr.AddContent(td);
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText("First name"));
				FOR i := 0 TO nofCols-1 DO
					NEW(td); td.SetName("td"); tr.AddContent(td);

					Strings.IntToStr(i+1, iStr);
					NEW(str, Strings.Length(ExerciseName)+LEN(iStr)+1);
					COPY(ExerciseName, str^); Strings.Append(str^, iStr);

					WebStd.AppendXMLContent(td, WebStd.CreateXMLText(str^));

					IF (allowDelete) THEN
						NEW(br); br.SetName("br"); td.AddContent(br);

						NEW(eventLink); eventLink.SetName("WebStd:EventLink"); td.AddContent(eventLink);
						eventLink.SetAttributeValue("xmlns:WebStd", "WebStd");
						NEW(label); label.SetName("Label");
						WebStd.AppendXMLContent(label, WebStd.CreateXMLText(DeleteAnExerciseLabel));
						eventLink.AddContent(label);
						eventLink.SetAttributeValue("method", "DeleteExercise");
						eventLink.SetAttributeValue("object", "GradesEditList");
						eventLink.SetAttributeValue("module", ThisModuleNameStr);
						eventLink.SetAttributeValue("objectid", objectId^);
						NEW(eventParam); eventParam.SetName("Param");
						eventParam.SetAttributeValue("name", "exerciseno");
						Strings.IntToStr(i, iStr);
						eventParam.SetAttributeValue("value", iStr);
						eventLink.AddContent(eventParam);
					END
				END;
				NEW(td); td.SetName("td"); tr.AddContent(td);
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText(" "))
			ELSE
				tr := NIL
			END;
			RETURN tr
		END GetExerciseListHeaderRow;

		(* get a edit view row for a persons exercise grades, if the person has not nofCols exercise grades then insert new ones *)
		PROCEDURE GetPersonGradesEditRow(nofCols: SIZE; person: Person) : XML.Element;
		VAR tr, td: XML.Element; number: SIGNED32; i: SIZE;
			PROCEDURE GetInputName(oid: SIGNED32; exerciseNo: SIZE) : Strings.String;
			VAR nameStr: Strings.String; oidStr, exerciseNoStr: ARRAY 14 OF CHAR;
			BEGIN
				Strings.IntToStr(oid, oidStr); Strings.IntToStr(exerciseNo, exerciseNoStr);
				NEW(nameStr, Strings.Length(PersonGradePrefixName)+2*14+1);
				Strings.Concat(PersonGradePrefixName, oidStr, nameStr^);
				Strings.Append(nameStr^, "-"); Strings.Append(nameStr^, exerciseNoStr);
				RETURN nameStr
			END GetInputName;

			PROCEDURE GetInputField(exerciseNo: SIZE; grade: SIGNED32) : XML.Element;
			VAR td, input: XML.Element; numberStr: ARRAY 14 OF CHAR; name: Strings.String;
			BEGIN
				Strings.IntToStr(grade, numberStr);
				name := GetInputName(person.oid, exerciseNo); (* name # NIL *)
				NEW(td); td.SetName("td");
				NEW(input); input.SetName("input"); td.AddContent(input);
				input.SetAttributeValue("type", "text");
				input.SetAttributeValue("size", "2");
				input.SetAttributeValue("name", name^);
				input.SetAttributeValue("value", numberStr);
				RETURN td
			END GetInputField;
		BEGIN
			IF ((person# NIL) & (person.grades # NIL) & (nofCols > 0)) THEN
				person.grades.Lock;
				NEW(tr); tr.SetName("tr");
				NEW(td); td.SetName("td"); tr.AddContent(td);
				IF (person.lastname # NIL) THEN
					WebStd.AppendXMLContent(td, WebStd.CreateXMLText(person.lastname^))
				ELSE
					WebStd.AppendXMLContent(td, WebStd.CreateXMLText(" "))
				END;
				NEW(td); td.SetName("td"); tr.AddContent(td);
				IF (person.firstname # NIL) THEN
					WebStd.AppendXMLContent(td, WebStd.CreateXMLText(person.firstname^))
				ELSE
					WebStd.AppendXMLContent(td, WebStd.CreateXMLText(" "))
				END;
				FOR i := 0 TO MIN(person.grades.GetCount(), nofCols)-1 DO
					number := person.grades.GetItem(i);
					tr.AddContent(GetInputField(i, number))
				END;
				person.grades.Unlock;
				IF (i < nofCols) THEN
					person.BeginModification;
					WHILE (i < nofCols) DO
						person.grades.Add(0);
						tr.AddContent(GetInputField(i, 0));
						INC(i)
					END;
					person.EndModification
				END;
				NEW(td); td.SetName("td"); tr.AddContent(td);
				WebStd.AppendXMLContent(td, GetNotification(person))
			END;
			RETURN tr
		END GetPersonGradesEditRow;

		PROCEDURE GetNotification(person: Person) : XML.Content;
		VAR aTag: XML.Element; dynStr: DynamicStrings.DynamicString; i: SIZE; number: SIGNED32;
			numberStr, iStr: ARRAY 14 OF CHAR; str: Strings.String;
			PROCEDURE Append(text: ARRAY OF CHAR);
			VAR str: Strings.String;
			BEGIN str := WebStd.GetString(text); dynStr.Append(str^)
			END Append;
		BEGIN (* person # NIL *)
			IF ((person.grades # NIL) & (person.grades.GetCount() > 0) & (person.email # NIL) & (person.email^ # "")) THEN
				NEW(aTag); aTag.SetName("a");
				NEW(dynStr); Append("mailto:");
				dynStr.Append(person.email^);
				Append("?subject=");
				IF ((group # NIL) & (group.name # NIL)) THEN
					dynStr.Append(group.name^)
				END;
				Append(" - "); Append(GradeNotificationSubject);
				Append("&body="); Append(GradeNotificationSalutation); Append(" ");
				IF (person.firstname # NIL) THEN
					dynStr.Append(person.firstname^)
				END;
				Append(","); Append(MailCR); Append(MailCR);
				Append(GradeNotificationBodyHead); Append(MailCR);
				person.grades.Lock;
				FOR i := 0 TO person.grades.GetCount()-1 DO
					Strings.IntToStr(i+1, iStr);
					number := person.grades.GetItem(i); Strings.IntToStr(number, numberStr);
					Append(ExerciseName); Append(" "); dynStr.Append(iStr); Append(": "); dynStr.Append(numberStr);
					Append(MailCR)
				END;
				person.grades.Unlock;
				Append(MailCR); Append(GradeNotificationBodyTail); Append(MailCR); Append(MailCR);
				IF (group.assistant # NIL) THEN
					dynStr.Append(group.assistant^); Append(MailCR)
				END;
				str := dynStr.ToArrOfChar();
				str := WebStd.GetEncXMLAttributeText(str^);
				aTag.SetAttributeValue("href", str^);
				WebStd.AppendXMLContent(aTag, WebStd.CreateXMLText(SendGradeNotoficationLabel));
				RETURN aTag
			ELSE
				RETURN WebStd.CreateXMLText(" ")
			END
		END GetNotification;

		PROCEDURE UpdateList(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		VAR tempStr, personOidStr, exerciseNoStr: Strings.String;
			i, length, sepIdx: SIZE; personOid, exerciseNo, newGrade: SIGNED32; par: DynamicWebpage.Parameter;
			(* params: the grades for all group members *)
		BEGIN
			(* if this event handler is manually invoked on this active element such that the active element was not previously
			 * processed then group=NIL and no changes are made. This guarantees that no unauthorized user can edit the grades *)
			IF ((group # NIL) & (params.parameters # NIL)) THEN
				FOR i := 0 TO LEN(params.parameters)-1 DO
					par := params.parameters[i];
					IF ((par # NIL) & (par.name # NIL) & (par.value # NIL)) THEN
						IF (Strings.Pos(PersonGradePrefixName, par.name^) = 0) THEN
							 tempStr := WebStd.GetString(par.name^);
							 Strings.Delete(tempStr^, 0, Strings.Length(PersonGradePrefixName));
							 sepIdx := Strings.Pos("-", tempStr^);
							 length := Strings.Length(tempStr^);
							 IF ((sepIdx > 0) & (sepIdx < length-1)) THEN
							 	NEW(personOidStr, sepIdx+1); Strings.Copy(tempStr^, 0, sepIdx, personOidStr^);
							 	NEW(exerciseNoStr, length-sepIdx); Strings.Copy(tempStr^, sepIdx+1, length-sepIdx-1, exerciseNoStr^);
							 	Strings.StrToInt(personOidStr^, personOid); Strings.StrToInt(exerciseNoStr^, exerciseNo);
							 	Strings.StrToInt(par.value^, newGrade);
							 	group.UpdateGrade(personOid, exerciseNo, newGrade)
							 END
						END
					END
				END
			END
		END UpdateList;

		PROCEDURE AddNewExercise(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		BEGIN
			IF (group # NIL) THEN
				group.AddNewExercise
			END
		END AddNewExercise;

		PROCEDURE DeleteExercise(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		VAR exerciseNoStr: Strings.String; exerciseNo: SIGNED32;
			(* parameters: "exerciseno" *)
		BEGIN
			exerciseNoStr := params.GetParameterValueByName("exerciseno");
			IF (exerciseNoStr # NIL) THEN
				Strings.StrToInt(exerciseNoStr^, exerciseNo);
				IF (group # NIL) THEN
					group.DeleteExercise(exerciseNo)
				END
			ELSE
				KernelLog.String("ExerciseGroups:GradesEditList - event handler 'DeleteExercise' has parameter 'exerciseno'.");
				KernelLog.Ln
			END
		END DeleteExercise;

		PROCEDURE GetEventHandlers*() : DynamicWebpage.EventHandlerList;
		VAR list: DynamicWebpage.EventHandlerList;
		BEGIN
			NEW(list, 3);
			NEW(list[0], "UpdateList", UpdateList);
			NEW(list[1], "AddNewExercise", AddNewExercise);
			NEW(list[2], "DeleteExercise", DeleteExercise);
			RETURN list
		END GetEventHandlers;
	END GradesEditList;

	(** stateless summary list for all groups of one lecture
	 * <ExerciseGroups:SummaryList containername=".." prevalencesystem=".."/>
	 *)
	SummaryList* = OBJECT(DynamicWebpage.StateLessActiveElement);
		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR containerName, prevSysName: Strings.String; persCont: WebStd.PersistentDataContainer;
			persList: WebStd.PersistentDataObjectList; i: SIZE; outputCont: XML.Container;
			entry: WebComplex.WebForumEntry; prevSys: PrevalenceSystem.PrevalenceSystem;
		BEGIN
			containerName := input.GetAttributeValue("containername");
			prevSysName := input.GetAttributeValue("prevalencesystem");
			(* get the prevalence system *)
			IF (prevSysName # NIL) THEN
				prevSys := PrevalenceSystem.GetPrevalenceSystem(prevSysName^)
			ELSE
				prevSys := PrevalenceSystem.standardPrevalenceSystem
			END;
			IF ((containerName # NIL) & (prevSys # NIL)) THEN
				persCont := WebStd.GetPersistentDataContainer(prevSys, containerName^);
				IF (persCont # NIL) THEN
					persList := persCont.GetElementList(NIL, NIL);
					IF ((persList # NIL) & (LEN(persList) > 0)) THEN
						NEW(outputCont);
						FOR i := 0 TO LEN(persList)-1 DO
							IF (persList[i] IS WebComplex.WebForumEntry) THEN (* persList[i] # NIL *)
								entry := persList[i](WebComplex.WebForumEntry);
								WebStd.AppendXMLContent(outputCont, entry.DetailView(NIL, request))
							END
						END;
						RETURN outputCont
					END
				END
			END;
			RETURN NIL
		END Transform;
	END SummaryList;

	VAR
		personDesc: PrevalenceSystem.PersistentObjectDescriptor; (* descriptor for Person *)
		groupDesc: PrevalenceSystem.PersistentObjectDescriptor; (* descriptor for Group *)

	(* returns TRUE iff request is an authorized user or an administrator *)
	PROCEDURE IsAuthorizedUser(request: HTTPSupport.HTTPRequest) : BOOLEAN;
	VAR session: HTTPSession.Session;
	BEGIN
		session := HTTPSession.GetSession(request); (* session # NIL *)
		RETURN ((WebAccounts.GetAuthWebAccountForSession(session) # NIL) OR
			WebAccounts.IsSessionAuthorizedAsAdmin(session))
	END IsAuthorizedUser;

	PROCEDURE CompareLastName(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
	VAR f1, f2: Person;
	BEGIN
		IF ((obj1 IS Person) & (obj2 IS Person)) THEN
			f1 := obj1(Person); f2 := obj2(Person);
			IF (f2.lastname = NIL) THEN
				RETURN FALSE
			ELSIF (f1.lastname = NIL) THEN (* f2.lastname # NIL *)
				RETURN TRUE
			ELSE
				RETURN f1.lastname^ < f2.lastname^
			END
		ELSE
			RETURN FALSE
		END
	END CompareLastName;

	PROCEDURE GetNewPerson() : PrevalenceSystem.PersistentObject;
	VAR obj: Person;
	BEGIN NEW(obj); RETURN obj
	END GetNewPerson;

	PROCEDURE GetNewGroup() : PrevalenceSystem.PersistentObject;
	VAR obj: Group;
	BEGIN NEW(obj); RETURN obj
	END GetNewGroup;

	(** used by the prevalence system *)
	PROCEDURE GetPersistentObjectDescriptors*() : PrevalenceSystem.PersistentObjectDescSet;
	VAR descSet : PrevalenceSystem.PersistentObjectDescSet;
		descs: ARRAY 2 OF PrevalenceSystem.PersistentObjectDescriptor;
	BEGIN
		descs[0] := personDesc;
		descs[1] := groupDesc;
		NEW(descSet, descs);
		RETURN descSet
	END GetPersistentObjectDescriptors;

	PROCEDURE CreateSingleGroupDgElement() : DynamicWebpage.ActiveElement;
	VAR obj: SingleGroupDatagrid;
	BEGIN
		NEW(obj); RETURN obj
	END CreateSingleGroupDgElement;

	PROCEDURE CreateAllGroupsDatagridElement() : DynamicWebpage.ActiveElement;
	VAR obj: AllGroupsDatagrid;
	BEGIN
		NEW(obj); RETURN obj
	END CreateAllGroupsDatagridElement;

	PROCEDURE CreateGradesEditListElement() : DynamicWebpage.ActiveElement;
	VAR obj: GradesEditList;
	BEGIN
		NEW(obj); RETURN obj
	END CreateGradesEditListElement;

	PROCEDURE CreateSummaryListElement() : DynamicWebpage.ActiveElement;
	VAR obj: SummaryList;
	BEGIN
		NEW(obj); RETURN obj
	END CreateSummaryListElement;

	PROCEDURE GetActiveElementDescriptors*() : DynamicWebpage.ActiveElementDescSet;
	VAR desc: POINTER TO ARRAY OF DynamicWebpage.ActiveElementDescriptor;
		descSet: DynamicWebpage.ActiveElementDescSet;
	BEGIN
		NEW(desc, 4);
		NEW(desc[0], "SingleGroupDatagrid", CreateSingleGroupDgElement);
		NEW(desc[1],  "AllGroupsDatagrid", CreateAllGroupsDatagridElement);
		NEW(desc[2],  "GradesEditList", CreateGradesEditListElement);
		NEW(desc[3],  "SummaryList", CreateSummaryListElement);
		NEW(descSet, desc^); RETURN descSet
	END GetActiveElementDescriptors;

BEGIN
	NEW(personDesc, ThisModuleNameStr, "Person", GetNewPerson);
	NEW(groupDesc, ThisModuleNameStr, "Group", GetNewGroup)
END ExerciseGroups.
