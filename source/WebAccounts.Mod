MODULE WebAccounts; (** AUTHOR "Luc Blaeser"; PURPOSE "Web Accounts and Authorization Domains" *)

IMPORT WebComplex, WebStd, DynamicWebpage, PrevalenceSystem, HTTPSupport, HTTPSession, XML, XMLObjects,
	Dates, Strings, DynamicStrings, TFClasses, Configuration, KernelLog;

CONST
	(** persistent data container names for the web accounts and authorization domains *)
	WebAccountsContainerName* = "SystemWebAccounts";
	WebAuthDomainContainerName* = "SystemAuthorizationDomains";

	(** session variables names for the web users authorization information *)
	WebAccountsSessionVarUsername* = "dxp-WebAccounts-SessionVar-Username";
	WebAccountsSessionVarPassword* = "dxp-WebAccounts-SessionVar-Password";

	MinPasswordLength* = 6; (** minimal reuired password length *)

	(* prevalence system specification for the web accounts and authorization domains *)
	WebAccountsPrevSysName* = "WebAccounts";
	SnapShotFileName = "WebAccountsSnapShot.XML";
	LogFileName = "WebAccountsLog.XML";

	ConfigurationSubSectionName = "Administrators";
	ConfigurationSubSubSectionName = "AdminInfo";
	WebAccountDatagridName = "WebAccountDatagrid";
	AuthDomainDatagridName = "AuthorizationDomainDatagrid";
	ThisModuleNameStr = "WebAccounts";

	DefaultNewAccountSubmitLabel = "Submit";
	YesLabel = "Yes";
	NoLabel = "No";
	EditLabel = "Edit";
	DeleteLabel = "Delete";
	UsernameLabel = "Username: ";
	UsernameHeaderLabel = "Username";
	PasswordLabel = "Password: ";
	ConfirmPasswordLabel = "Confirm password: ";
	EmailLabel = "Email: ";
	EmailHeaderLabel = "Email";
	DefaultMessageNameLabel = "Default message name: ";
	LastLoginLabel = "Last Login: ";
	NeverLabel = "never";
	InterestedDataContainersLabel = "Interested data containers: ";
	NotAuthorizedLabel = "Not authorized";
	NameLabel = "Name: ";
	NameHeaderLabel = "Name";
	BackLabel = "Back";
	SaveLabel = "Save";
	AdminAccessDeniedLabel = "Access denied since not authorized as an administrator";
	NameAlreadyUsedLabel = "name is already used";
	NameIsMissingLabel = "name is missing";
	LoginLabel = "Login";
	SelectWebAccountLabel = "Select web account: ";
	UsernameIsMissingLabel = "Username is missing";
	UsernameIsAlreayUsedLabel = "Username is already used by someone else";
	PasswordTooShortLabel = "password too short or empty";
	PasswordDoNotAgreeLabel = "password and its confirmation did not agree";
	WebAccountIsNotPresentLabel = "the selected web account is not present";
	NoWebAccountSelectedLabel = "no web account has been selected";
	ActivatedLabel = "Activated: ";
	IsActivatedLabel = "Activated";
	NotActivatedLabel = "Not activated";
	ActivatedHeaderLabel = "Activated";

	WebAccountsContainerPrefixName = "dxp-WebAccounts-Container";
TYPE
	WebAccount* = OBJECT(WebComplex.WebForumEntry);
		VAR
			username: Strings.String;
			password: Strings.String;
			email: Strings.String;
			defaultMsgName: Strings.String;
			lastLoginTime: WebStd.PtrDateTime;
			actLoginTime: WebStd.PtrDateTime;
			interestedContainers: TFClasses.List; (* List of DynamicStrings.DynamicString , the container names interested in *)
			isActivated: BOOLEAN; (* true if the web account is activated for login *)

		PROCEDURE SetLoginTimeNow*;
		BEGIN
			lastLoginTime := actLoginTime;
			NEW(actLoginTime); actLoginTime^ := Dates.Now()
		END SetLoginTimeNow;

		PROCEDURE GetUsername*() : Strings.String;
		BEGIN RETURN username
		END GetUsername;

		PROCEDURE SetUsername*(uname: ARRAY OF CHAR);
		BEGIN
			BeginModification;
			username := WebStd.GetString(uname);
			EndModification
		END SetUsername;

		(* return true if pwd aggres with the password *)
		PROCEDURE AgreesWithPassword*(pwd: ARRAY OF CHAR): BOOLEAN;
		BEGIN RETURN ((password # NIL) & (pwd = password^))
		END AgreesWithPassword;

		(* returns true if new password has been set otherwise the old password 'oldPwd' doesn't agree with the
		 * actual password or the password is too short ( < MinPasswordLength) *)
		PROCEDURE SetNewPassword*(oldPwd, newPwd: ARRAY OF CHAR) : BOOLEAN;
		BEGIN
			IF ((AgreesWithPassword(oldPwd)) & (Strings.Length(newPwd) >= MinPasswordLength)) THEN
				BeginModification;
				password := WebStd.GetString(newPwd);
				EndModification;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END SetNewPassword;

		PROCEDURE GetEmail*(): Strings.String;
		BEGIN RETURN email
		END GetEmail;

		PROCEDURE SetEmail*(mail: ARRAY OF CHAR): Strings.String;
		BEGIN
			BeginModification;
			email := WebStd.GetString(mail);
			EndModification;
			RETURN email
		END SetEmail;

		PROCEDURE GetDefaultMsgName*() : Strings.String;
		BEGIN RETURN defaultMsgName
		END GetDefaultMsgName;

		PROCEDURE SetDefaultMsgName*(msgName: ARRAY OF CHAR);
		BEGIN
			BeginModification;
			defaultMsgName := WebStd.GetString(msgName);
			EndModification
		END SetDefaultMsgName;

		PROCEDURE GetLastLoginTime*() : WebStd.PtrDateTime;
		BEGIN RETURN lastLoginTime
		END GetLastLoginTime;

		PROCEDURE IsInterestedOnContainer*(containerName: ARRAY OF CHAR) : BOOLEAN;
		VAR dynStr: DynamicStrings.DynamicString; i: SIZE; p: ANY; str: Strings.String;
		BEGIN
			IF (interestedContainers # NIL) THEN
				interestedContainers.Lock;
				FOR i := 0 TO interestedContainers.GetCount()-1 DO
					p := interestedContainers.GetItem(i); dynStr := p(DynamicStrings.DynamicString);
					str := dynStr.ToArrOfChar(); (* str # NIL *)
					IF (str^ = containerName) THEN
						interestedContainers.Unlock;
						RETURN TRUE
					END
				END;
				interestedContainers.Unlock
			END;
			RETURN FALSE
		END IsInterestedOnContainer;

		PROCEDURE AddInterestedContainer*(containerName: ARRAY OF CHAR);
		VAR dynStr: DynamicStrings.DynamicString;
		BEGIN
			NEW(dynStr); dynStr.Append(containerName);
			BeginModification;
			IF (interestedContainers = NIL) THEN NEW(interestedContainers) END;
			interestedContainers.Add(dynStr);
			EndModification
		END AddInterestedContainer;

		PROCEDURE RemoveInterestedContainer*(containerName: ARRAY OF CHAR);
		VAR dynStr, delEntry: DynamicStrings.DynamicString; i: SIZE; p: ANY; str: Strings.String;
		BEGIN
			IF (interestedContainers # NIL) THEN
				delEntry := NIL;
				interestedContainers.Lock;
				FOR i := 0 TO interestedContainers.GetCount()-1 DO
					p := interestedContainers.GetItem(i); dynStr := p(DynamicStrings.DynamicString);
					str := dynStr.ToArrOfChar(); (* str # NIL *)
					IF (str^ = containerName) THEN delEntry := dynStr END
				END;
				interestedContainers.Unlock;
				IF (delEntry # NIL) THEN
					BeginModification;
					interestedContainers.Remove(delEntry);
					EndModification
				END
			END
		END RemoveInterestedContainer;

		PROCEDURE IsActivated*() : BOOLEAN;
		BEGIN RETURN isActivated
		END IsActivated;

		PROCEDURE SetActivated*(modus: BOOLEAN);
		BEGIN
			BeginModification;
			isActivated := modus;
			EndModification
		END SetActivated;

		PROCEDURE Internalize*(input: XML.Content);
		VAR container: XML.Container; elem, subElem: XML.Element; enum: XMLObjects.Enumerator; p: ANY;
			str: Strings.String; dynStr: DynamicStrings.DynamicString;
		BEGIN
			container := input(XML.Container);
			username := WebStd.InternalizeString(container, "Username");
			password := WebStd.InternalizeString(container, "Password");
			email := WebStd.InternalizeString(container, "Email");
			defaultMsgName := WebStd.InternalizeString(container, "DefaultMsgName");
			actLoginTime := WebStd.InternalizeDateTime(container, "ActLoginTime");
			isActivated := WebStd.InternalizeBoolean(container, "Activated");

			elem := WebStd.GetXMLSubElement(container, "InterestedContainers");
			IF (elem # NIL) THEN
				NEW(interestedContainers);
				enum := elem.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext();
					IF (p IS XML.Element) THEN
						subElem := p(XML.Element);
						str := WebStd.GetXMLCharContent(subElem);
						IF (str # NIL) THEN
							NEW(dynStr); dynStr.Append(str^);
							interestedContainers.Add(dynStr)
						END
					END
				END
			ELSE
				interestedContainers := NIL
			END
		END Internalize;

		PROCEDURE Externalize*() : XML.Content;
		VAR container: XML.Container; elem, subElem: XML.Element; i: SIZE; p: ANY;
			dynStr: DynamicStrings.DynamicString; str: Strings.String;
		BEGIN
			NEW(container);
			WebStd.ExternalizeString(username, container, "Username");
			WebStd.ExternalizeString(password, container, "Password");
			WebStd.ExternalizeString(email, container, "Email");
			WebStd.ExternalizeString(defaultMsgName, container, "DefaultMsgName");
			WebStd.ExternalizeDateTime(actLoginTime, container, "ActLoginTime");
			WebStd.ExternalizeBoolean(isActivated, container, "Activated");

			IF (interestedContainers # NIL) THEN
				NEW(elem); elem.SetName("InterestedContainers"); container.AddContent(elem);
				interestedContainers.Lock;
				FOR i := 0 TO interestedContainers.GetCount()-1 DO
					p := interestedContainers.GetItem(i); dynStr := p(DynamicStrings.DynamicString);
					str := dynStr.ToArrOfChar(); (* str # NIL *)
					NEW(subElem); subElem.SetName("ContainerName"); elem.AddContent(subElem);
					WebStd.AppendXMLContent(subElem, WebStd.CreateXMLText(str^));
				END;
				interestedContainers.Unlock
			END;
			RETURN container
		END Externalize;

		PROCEDURE TableView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : WebComplex.TableRow;
		VAR row: WebComplex.TableRow;
		BEGIN
			NEW(row, 5);
			row[0] := WebComplex.GetTableCell(username, WebComplex.WebForumDetailViewCell);
			row[1] := WebComplex.GetEmailTableCell(email, WebComplex.WebForumNormalCell);
			IF (isActivated) THEN
				row[2] := WebComplex.GetTableCellForText(IsActivatedLabel, WebComplex.WebForumNormalCell)
			ELSE
				row[2] := WebComplex.GetTableCellForText(NotActivatedLabel, WebComplex.WebForumNormalCell)
			END;
			row[3] := WebComplex.GetTableCellForText(EditLabel, WebComplex.WebForumEditViewCell);
			row[4] := WebComplex.GetTableCellForText(DeleteLabel, WebComplex.WebForumDeleteCell);
			RETURN row
		END TableView;

		PROCEDURE DetailView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR container: XML.Container; pTag: XML.Element; ul, li: XML.Element; i: SIZE; p: ANY;
			dynStr: DynamicStrings.DynamicString; str, lastLoginTimeStr: Strings.String;
		BEGIN
			NEW(container);
			WebComplex.AddStandardDetailView(container, UsernameLabel, username);

			IF ((forum # NIL) & (forum IS WebAccountDatagrid)) THEN
				NEW(pTag); pTag.SetName("p");
				WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(ActivatedLabel));
				IF (isActivated) THEN
					WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(YesLabel))
				ELSE
					WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(NoLabel))
				END;
				container.AddContent(pTag)
			END;

			NEW(pTag); pTag.SetName("p");
			WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(EmailLabel));
			IF (email # NIL) THEN
				pTag.AddContent(WebComplex.GetMailtoElement(email^))
			END;
			container.AddContent(pTag);

			WebComplex.AddStandardDetailView(container, DefaultMessageNameLabel, defaultMsgName);

			NEW(pTag); pTag.SetName("p");
			WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(LastLoginLabel));
			IF (lastLoginTime # NIL) THEN
				lastLoginTimeStr := WebStd.DateTimeToStr(lastLoginTime^);
				WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(lastLoginTimeStr^))
			ELSE
				WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(NeverLabel))
			END;
			container.AddContent(pTag);

			NEW(pTag); pTag.SetName("p");
			WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(InterestedDataContainersLabel));
			container.AddContent(pTag);
			IF ((interestedContainers # NIL) & (interestedContainers.GetCount() > 0)) THEN
				NEW(ul); ul.SetName("ul"); container.AddContent(ul);
				interestedContainers.Lock;
				FOR i := 0 TO interestedContainers.GetCount()-1 DO
					p := interestedContainers.GetItem(i); dynStr := p(DynamicStrings.DynamicString);
					str := dynStr.ToArrOfChar(); (* str # NIL *)
					NEW(li); li.SetName("li"); ul.AddContent(li);
					WebStd.AppendXMLContent(li, WebStd.CreateXMLText(str^));
				END;
				interestedContainers.Unlock
			END;

			RETURN container
		END DetailView;

		PROCEDURE EditView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR table: XML.Element;
		BEGIN
			NEW(table); table.SetName("table");

			IF ((forum # NIL) & (forum IS WebAccountDatagrid)) THEN
				WebComplex.AddTextFieldInputRow(table, UsernameLabel, "username", username)
			END;
			WebComplex.AddPasswordFieldInputRow(table, PasswordLabel, "password");
			WebComplex.AddPasswordFieldInputRow(table, ConfirmPasswordLabel, "confpassword");

			IF ((forum # NIL) & (forum IS WebAccountDatagrid)) THEN
				WebStd.AppendXMLContent(table, GetActivationEditRow(isActivated))
			END;

			WebComplex.AddTextFieldInputRow(table, EmailLabel, "email", email);
			WebComplex.AddTextFieldInputRow(table, DefaultMessageNameLabel, "defaultmsgname", defaultMsgName);
			RETURN table
		END EditView;
	END WebAccount;

	(** a single web account view to allow a authorized user to inspect and modify his web account properties. Usage example:
	 * <WebAccounts:WebAccountView id="myAccountView3"/> *)
	WebAccountView* = OBJECT(DynamicWebpage.StateFullActiveElement);
		VAR
			editMode: BOOLEAN; (* true iff edit view is active *)
			webAccount: WebAccount;
			objectId: Strings.String;
			statusContent: XML.Content; (* save temporary status message of a event handler to display later *)

		PROCEDURE &Init*;
		BEGIN editMode := FALSE; webAccount := NIL; objectId := NIL
		END Init;

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR session: HTTPSession.Session; container: XML.Container;
		BEGIN
			objectId := input.GetAttributeValue(DynamicWebpage.XMLAttributeObjectIdName); (* objectId # NIL by DynamicWebPagePlugin logic *)
			session := HTTPSession.GetSession(request);
			webAccount := GetAuthWebAccountForSession(session);
			IF (webAccount #NIL) THEN
				NEW(container);
				AddStatusMessage(container);
				IF (editMode) THEN
					WebStd.AppendXMLContent(container, EditView(input, request))
				ELSE (* detail view mode *)
					WebStd.AppendXMLContent(container, DetailView(input, request))
				END;
				RETURN container
			ELSE
				RETURN WebStd.CreateXMLText(NotAuthorizedLabel)
			END
		END Transform;

		PROCEDURE EditView(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR formular, submitButton, eventButton: XML.Element;
		BEGIN (* webAccount # NIL & objectId # NIL *)
			NEW(formular); formular.SetName("WebStd:Formular");
			formular.SetAttributeValue("xmlns:WebStd", "WebStd");
			formular.SetAttributeValue("method", "UpdateEditEntry");
			formular.SetAttributeValue("object", "WebAccountView");
			formular.SetAttributeValue("module", ThisModuleNameStr);
			formular.SetAttributeValue("objectid", objectId^);

			WebStd.AppendXMLContent(formular, webAccount.EditView(NIL, request));

			submitButton := GetSubmitButton(request);
			formular.AddContent(submitButton);

			eventButton := GetInputBackButton(request);
			formular.AddContent(eventButton);

			RETURN formular
		END EditView;

		PROCEDURE DetailView(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR container: XML.Container; pTag, eventLink, label: XML.Element;
		BEGIN (* webAccount # NIL & objectId # NIL*)
			NEW(container);

			WebStd.AppendXMLContent(container, webAccount.DetailView(NIL, request));

			NEW(pTag); pTag.SetName("p"); container.AddContent(pTag);
			NEW(eventLink); eventLink.SetName("WebStd:EventLink"); pTag.AddContent(eventLink);
			eventLink.SetAttributeValue("xmlns:WebStd", "WebStd");
			eventLink.SetAttributeValue("method", "SetEditView");
			eventLink.SetAttributeValue("object", "WebAccountView");
			eventLink.SetAttributeValue("module", ThisModuleNameStr);
			eventLink.SetAttributeValue("objectid", objectId^);

			NEW(label); label.SetName("Label"); eventLink.AddContent(label);
			WebStd.AppendXMLContent(label, WebStd.CreateXMLText("Edit"));
			RETURN container
		END DetailView;

		PROCEDURE AddStatusMessage(container: XML.Container);
		BEGIN
			IF (statusContent # NIL) THEN
				WebStd.AppendXMLContent(container, statusContent);
				statusContent := NIL (* set status back *)
			END;
		END AddStatusMessage;

		PROCEDURE GetInputBackButton(request: HTTPSupport.HTTPRequest) : XML.Element;
		VAR input: XML.Element;
		BEGIN
			NEW(input); input.SetName("input");
			input.SetAttributeValue("type", "submit");
			input.SetAttributeValue("name", "backbutton");
			input.SetAttributeValue("value", BackLabel);
			RETURN input
		END GetInputBackButton;

		PROCEDURE GetSubmitButton(request: HTTPSupport.HTTPRequest) : XML.Element;
		VAR input: XML.Element;
		BEGIN
			NEW(input); input.SetName("input");
			input.SetAttributeValue("type", "submit");
			input.SetAttributeValue("name", "submitbutton");
			input.SetAttributeValue("value", SaveLabel);
			RETURN input
		END GetSubmitButton;

		PROCEDURE SetEditView(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		BEGIN
			IF (webAccount # NIL) THEN
				editMode := TRUE
			END
		END SetEditView;

		PROCEDURE UpdateEditEntry(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		VAR buttonName: Strings.String; usernameDyn, passwordDyn: DynamicStrings.DynamicString;
			session: HTTPSession.Session;
		BEGIN
			buttonName := params.GetParameterValueByName("backbutton");
			IF (buttonName # NIL) THEN
				editMode := FALSE
			ELSE
				IF (webAccount # NIL) THEN
					IF (UpdateWebAccountObject(webAccount, FALSE, FALSE, request, params, statusContent)) THEN
						(* update authorization information in session *)
						IF ((webAccount.username # NIL) & (webAccount.password # NIL)) THEN
							NEW(usernameDyn); NEW(passwordDyn);
							usernameDyn.Append(webAccount.username^); passwordDyn.Append(webAccount.password^);
							session := HTTPSession.GetSession(request);
							session.AddVariableValue(WebAccountsSessionVarUsername, usernameDyn);
							session.AddVariableValue(WebAccountsSessionVarPassword, passwordDyn)
						END;
						editMode := FALSE
						(* ELSE stay in edit view mode *)
					END
				ELSE
					statusContent := WebStd.CreateXMLText(NotAuthorizedLabel);
					editMode := FALSE
				END
			END
		END UpdateEditEntry;

    	PROCEDURE GetEventHandlers*() : DynamicWebpage.EventHandlerList;
		VAR list: DynamicWebpage.EventHandlerList;
		BEGIN
			NEW(list, 2);
			NEW(list[0], "SetEditView", SetEditView);
			NEW(list[1], "UpdateEditEntry", UpdateEditEntry);
			RETURN list
		END GetEventHandlers;
	END WebAccountView;

	(** statefull active element *)
	WebAccountDatagrid* = OBJECT(WebComplex.WebForum);
		VAR
			searchText: Strings.String;
			accountContainerName: Strings.String;

		PROCEDURE PreTransform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR session: HTTPSession.Session;
		BEGIN
			(* must check whether the session is an authorized administrator *)
			session := HTTPSession.GetSession(request);
			IF (IsSessionAuthorizedAsAdmin(session)) THEN
				(* make sure that the prevalence system is already loaded *)
				LoadPrevalenceSystem;
				accountContainerName := input.GetAttributeValue("containername");
				RETURN input
			ELSE
				RETURN WebStd.CreateXMLText(AdminAccessDeniedLabel)
			END
		END PreTransform;

		PROCEDURE InsertObject*(container: WebStd.PersistentDataContainer; superEntry: WebComplex.WebForumEntry;
			request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
			(* parameters "username", "password", "confpassword", "email", "defaultmsgname", "activated" or "accountoid"*)
		VAR activated: BOOLEAN; activatedStr: Strings.String;
		BEGIN
			activatedStr := params.GetParameterValueByName("activated");
			activated := ((activatedStr # NIL) & (activatedStr^ = "true"));
			RETURN InsertWebAccountObject(accountContainerName, container, superEntry, activated, request, params, statusMsg)
		END InsertObject;

		PROCEDURE UpdateObject*(obj: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest;
			params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
		BEGIN
			RETURN UpdateWebAccountObject(obj, TRUE, TRUE, request, params, statusMsg)
		END UpdateObject;

		(** supplemental tasks before an object 'obj' and its subentries will be deleted *)
		PROCEDURE OnDelete*(obj: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest);
		VAR account: WebAccount;
		BEGIN
			IF (obj IS WebAccount) THEN
				account := obj(WebAccount);
				DeleteFromAllDomains(account)
			END
		END OnDelete;

		PROCEDURE ThisObjectName*() : Strings.String;
		BEGIN RETURN WebStd.GetString(WebAccountDatagridName)
		END ThisObjectName;

		PROCEDURE ThisModuleName*() : Strings.String;
		BEGIN RETURN WebStd.GetString(ThisModuleNameStr)
		END ThisModuleName;

		PROCEDURE GetInsertView*(superEntry: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest): XML.Content;
		BEGIN RETURN GetWebAccountInsertView(accountContainerName, superEntry, TRUE, request)
		END GetInsertView;

		PROCEDURE GetTableHeader*(request: HTTPSupport.HTTPRequest): WebComplex.HeaderRow;
		VAR row: WebComplex.HeaderRow;
		BEGIN
			NEW(row, 5);
			row[0] := WebComplex.GetHeaderCellForText(UsernameHeaderLabel, CompareUsername);
			row[1] := WebComplex.GetHeaderCellForText(EmailHeaderLabel, CompareEmail);
			row[2] := WebComplex.GetHeaderCellForText(ActivatedHeaderLabel, CompareActivated);
			row[3] := WebComplex.GetHeaderCellForText(" ", NIL);
			row[4] := WebComplex.GetHeaderCellForText(" ", NIL);
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
		VAR entry: WebAccount;
			PROCEDURE Matches(VAR str: ARRAY OF CHAR) : BOOLEAN;
			VAR lowStr: Strings.String;
			BEGIN
				lowStr := WebStd.GetString(str);
				Strings.LowerCase(lowStr^);
				RETURN Strings.Match(searchText^, lowStr^)
			END Matches;
		BEGIN (* searchText # NIL *)
			IF (obj IS WebAccount) THEN
				entry := obj(WebAccount);
				IF ((entry.username # NIL) & (Matches(entry.username^))) THEN
					RETURN TRUE
				END;
				IF ((entry.email # NIL) & (Matches(entry.email^))) THEN
					RETURN TRUE
				END
			END;
			RETURN FALSE
		END SearchFilter;

		PROCEDURE GetDefaultOrdering*() : WebStd.PersistentDataCompare;
		BEGIN RETURN CompareUsername
		END GetDefaultOrdering;

		PROCEDURE CompareUsername(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: WebAccount;
		BEGIN
			IF ((obj1 IS WebAccount) & (obj2 IS WebAccount)) THEN
				f1 := obj1(WebAccount); f2 := obj2(WebAccount);
				IF (f2.username = NIL) THEN
					RETURN FALSE
				ELSIF (f1.username = NIL) THEN (* f2.username # NIL *)
					RETURN TRUE
				ELSE
					RETURN f1.username^ < f2.username^
				END
			ELSE
				RETURN FALSE
			END
		END CompareUsername;

		PROCEDURE CompareEmail(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: WebAccount;
		BEGIN
			IF ((obj1 IS WebAccount) & (obj2 IS WebAccount)) THEN
				f1 := obj1(WebAccount); f2 := obj2(WebAccount);
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

		PROCEDURE CompareActivated(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: WebAccount;
		BEGIN
			IF ((obj1 IS WebAccount) & (obj2 IS WebAccount)) THEN
				f1 := obj1(WebAccount); f2 := obj2(WebAccount);
				RETURN ((f1.isActivated) & (~f2.isActivated))
			ELSE
				RETURN FALSE
			END
		END CompareActivated;
	END WebAccountDatagrid;

	AuthorizationDomain* = OBJECT(WebComplex.WebForumEntry);
		VAR
			name: Strings.String;
			members: WebStd.PersistentDataContainer; (* PersistentDataContainer of WebAccount *)
			membersDgId: Strings.String; (* id of the members web account datagrid *)

		PROCEDURE &Initialize*;
		BEGIN Init; (* call super initializer *)
			membersDgId := DynamicWebpage.CreateNewObjectId(); (* membersDgId # NIL *)
		END Initialize;

		PROCEDURE GetReferrencedObjects*() : PrevalenceSystem.PersistentObjectList;
		VAR list: PrevalenceSystem.PersistentObjectList;
		BEGIN
			NEW(list, 1);
			list[0] := members;
			RETURN list
		END GetReferrencedObjects;

		PROCEDURE GetName*(): Strings.String;
		BEGIN RETURN name
		END GetName;

		(* return true iff 'account' is a member of this authorization domain *)
		PROCEDURE IsMember*(account: WebAccount) : BOOLEAN;
		BEGIN RETURN ((members # NIL) & (members.Contains(account)))
		END IsMember;

		PROCEDURE Internalize*(input: XML.Content);
		VAR container: XML.Container; elem: XML.Element; oidStr: Strings.String;
			persObj: PrevalenceSystem.PersistentObject; oidNr: LONGINT;
		BEGIN
			container := input(XML.Container);

			IF (prevSys = NIL) THEN
				HALT(9999) (* LoadPrevalence first *)
			END;

			elem := WebStd.GetXMLSubElement(container, "Members");
			members := NIL;
			IF (elem # NIL) THEN
				oidStr := WebStd.GetXMLCharContent(elem);
				IF (oidStr # NIL) THEN
					Strings.StrToInt(oidStr^, oidNr);
					persObj := prevSys.GetPersistentObject(oidNr);
					IF ((persObj # NIL) & (persObj IS WebStd.PersistentDataContainer)) THEN
						members := persObj(WebStd.PersistentDataContainer)
					ELSE
						HALT(9999)
					END
				END
			END;

			name := WebStd.InternalizeString(container, "Name")
		END Internalize;

		PROCEDURE Externalize*() : XML.Content;
		VAR container: XML.Container; elem: XML.Element; oidStr: ARRAY 14 OF CHAR;
		BEGIN
			NEW(container);
			IF (members # NIL) THEN
				NEW(elem); elem.SetName("Members");
				Strings.IntToStr(members.oid, oidStr);
				WebStd.AppendXMLContent(elem, WebStd.CreateXMLText(oidStr));
				container.AddContent(elem)
			END;
			WebStd.ExternalizeString(name, container, "Name");
			RETURN container
		END Externalize;

		PROCEDURE TableView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : WebComplex.TableRow;
		VAR row: WebComplex.TableRow;
		BEGIN
			NEW(row, 3);
			row[0] := WebComplex.GetTableCell(name, WebComplex.WebForumDetailViewCell);
			row[1] := WebComplex.GetTableCellForText(EditLabel, WebComplex.WebForumEditViewCell);
			row[2] := WebComplex.GetTableCellForText(DeleteLabel, WebComplex.WebForumDeleteCell);
			RETURN row
		END TableView;

		PROCEDURE DetailView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR container: XML.Container; table, tr, td, accountDg, paging, searching: XML.Element;
			membersName: Strings.String; authDomDg: AuthorizationDomainDatagrid;
		BEGIN
			NEW(container);
			WebComplex.AddStandardDetailView(container, NameLabel, name);

			IF (members # NIL) THEN
				membersName := members.GetName();
				IF (membersName # NIL) THEN
					NEW(table); table.SetName("table"); table.SetAttributeValue("border", "1"); container.AddContent(table);
					NEW(tr); tr.SetName("tr"); table.AddContent(tr);
					NEW(td); td.SetName("td"); tr.AddContent(td);
					(* use active element
					 *	<WebAccounts:WebAccountDatagrid id=".." containername=".." prevalencesystem=".." [reinitialize="true"]>
					 *       <Paging size="10"/>
					 *       <Searching/>
					 *    </WebAccounts:WebAccountDatagrid>
					 *)
					NEW(accountDg); accountDg.SetName("WebAccounts:WebAccountDatagrid");
					accountDg.SetAttributeValue("xmlns:WebAccounts", ThisModuleNameStr);

					accountDg.SetAttributeValue("id", membersDgId^);
					accountDg.SetAttributeValue("containername", membersName^);
					accountDg.SetAttributeValue("prevalencesystem", WebAccountsPrevSysName);
					NEW(paging); paging.SetName("Paging"); accountDg.AddContent(paging);
					paging.SetAttributeValue("size", "10");
					NEW(searching); searching.SetName("Searching"); accountDg.AddContent(searching);
					IF ((forum # NIL) & (forum IS AuthorizationDomainDatagrid)) THEN
						authDomDg := forum(AuthorizationDomainDatagrid);
						(* user could have used the back button in the browser's navigation bar, therefore reinitialize subcontainer
					 	* if detail view has just been activated *)
						IF (authDomDg.reInitializeSubContainer) THEN
							accountDg.SetAttributeValue("reinitialize", "true")
						END;
						authDomDg.reInitializeSubContainer := FALSE
					END;

					td.AddContent(accountDg)
				ELSE
					WebStd.AppendXMLContent(container, WebStd.CreateXMLText("no members container name defined."))
				END
			ELSE
				WebStd.AppendXMLContent(container, WebStd.CreateXMLText("no members container present."))
			END;

			RETURN container
		END DetailView;

		PROCEDURE EditView*(forum: WebComplex.WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR table: XML.Element;
		BEGIN
			NEW(table); table.SetName("table");
			WebComplex.AddTextFieldInputRow(table, NameLabel, "name", name);
			RETURN table
		END EditView;
	END AuthorizationDomain;

		(** statefull active element *)
	AuthorizationDomainDatagrid* = OBJECT(WebComplex.WebForum);
		VAR
			searchText: Strings.String;
			reInitializeSubContainer: BOOLEAN; (* true if the sub container of the detail view has to be reinitialized *)
			(* user could have used the back button in the browser's navigation bar *)

		PROCEDURE PreTransform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR session: HTTPSession.Session;
		BEGIN (* make sure that the prevalence system is already loaded *)
			(* must check whether the session is an authorized administrator *)
			session := HTTPSession.GetSession(request);
			IF (IsSessionAuthorizedAsAdmin(session)) THEN
				(* make sure that the prevalence system is already loaded *)
				LoadPrevalenceSystem;
				RETURN input
			ELSE
				RETURN WebStd.CreateXMLText(AdminAccessDeniedLabel)
			END
		END PreTransform;

		PROCEDURE InsertObject*(container: WebStd.PersistentDataContainer; superEntry: WebComplex.WebForumEntry;
			request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList;
			VAR statusMsg: XML.Content) : BOOLEAN;
			(* parameters "name" *)
		VAR name, containername: Strings.String; obj: AuthorizationDomain;
		BEGIN
			LoadPrevalenceSystem;
			name := params.GetParameterValueByName("name");

			IF ((name # NIL) & (name^ # "")) THEN
				(* Check whether the name is already used *)
				NEW(containername, Strings.Length(name^)+Strings.Length(WebAccountsContainerPrefixName)+1);
				Strings.Concat(WebAccountsContainerPrefixName, name^, containername^);

				IF (WebStd.FindPersistentDataContainer(prevSys, containername^) # NIL) THEN
					statusMsg := WebStd.CreateXMLText(NameAlreadyUsedLabel);
					RETURN FALSE
				END;

				NEW(obj); obj.name := name;
				container.AddPersistentDataObject(obj, authorizationDomainDesc); (* adds it also to the prevalence system *)
				obj.BeginModification;
				NEW(obj.members);
				prevSys.AddPersistentObject(obj.members, WebStd.persistentDataContainerDesc);
				obj.EndModification;

				obj.members.SetName(containername^);
				RETURN TRUE
			ELSE
				statusMsg := WebStd.CreateXMLText(NameIsMissingLabel);
				RETURN FALSE
			END
		END InsertObject;

		PROCEDURE UpdateObject*(obj: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest;
			params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
		VAR name: Strings.String; domain: AuthorizationDomain;
		BEGIN (* obj # NIL *)
			IF (obj IS AuthorizationDomain) THEN
				domain := obj(AuthorizationDomain);
				name := params.GetParameterValueByName("name");

				IF ((name # NIL) & (name^ # "")) THEN
					domain.BeginModification;
					domain.name := name;
					domain.EndModification;
					RETURN TRUE
				ELSE
					statusMsg := WebStd.CreateXMLText(NameIsMissingLabel);
					RETURN FALSE
				END
			ELSE
				statusMsg := WebStd.CreateXMLText("object is not of type AuthorizationDomain");
				RETURN FALSE
			END
		END UpdateObject;

		PROCEDURE ThisObjectName*() : Strings.String;
		BEGIN RETURN WebStd.GetString(AuthDomainDatagridName)
		END ThisObjectName;

		PROCEDURE ThisModuleName*() : Strings.String;
		BEGIN RETURN WebStd.GetString(ThisModuleNameStr)
		END ThisModuleName;

		(** abstract, returns the insert view for the initialization of a new web forum entry, without submit/back-input fields
		 * and without hidden parameter for super entry in hierarchy.
		 * superEntry is the parent web forum entry in a hierachical web forum, superEntry is NIL iff it is a root entry *)
		PROCEDURE GetInsertView*(superEntry: WebComplex.WebForumEntry; request: HTTPSupport.HTTPRequest): XML.Content;
		VAR table: XML.Element;
		BEGIN
			NEW(table); table.SetName("table");
			WebComplex.AddTextFieldInputRow(table, NameLabel, "name", NIL);
			RETURN table
		END GetInsertView;

		PROCEDURE GetTableHeader*(request: HTTPSupport.HTTPRequest): WebComplex.HeaderRow;
		VAR row: WebComplex.HeaderRow;
		BEGIN
			NEW(row, 3);
			row[0] := WebComplex.GetHeaderCellForText(NameHeaderLabel, CompareName);
			row[1] := WebComplex.GetHeaderCellForText(" ", NIL);
			row[2] := WebComplex.GetHeaderCellForText(" ", NIL);
			RETURN row
		END GetTableHeader;

		PROCEDURE OnDetailViewActivated*(entryOid: LONGINT; request: HTTPSupport.HTTPRequest);
		BEGIN reInitializeSubContainer := TRUE (* the sub container has to showed in the default mode *)
		END OnDetailViewActivated;

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
		VAR entry: AuthorizationDomain;
			PROCEDURE Matches(VAR str: ARRAY OF CHAR) : BOOLEAN;
			VAR lowStr: Strings.String;
			BEGIN
				lowStr := WebStd.GetString(str);
				Strings.LowerCase(lowStr^);
				RETURN Strings.Match(searchText^, lowStr^)
			END Matches;
		BEGIN (* searchText # NIL *)
			IF (obj IS AuthorizationDomain) THEN
				entry := obj(AuthorizationDomain);
				IF ((entry.name # NIL) & (Matches(entry.name^))) THEN
					RETURN TRUE
				END;
			END;
			RETURN FALSE
		END SearchFilter;

		PROCEDURE CompareName(obj1, obj2: WebStd.PersistentDataObject): BOOLEAN;
		VAR f1, f2: AuthorizationDomain;
		BEGIN
			IF ((obj1 IS AuthorizationDomain) & (obj2 IS AuthorizationDomain)) THEN
				f1 := obj1(AuthorizationDomain); f2 := obj2(AuthorizationDomain);
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

	END AuthorizationDomainDatagrid;

	(** authentication formular for a web account which can participate on multiple authorization domains.
	 * Use WebAccounts:AuthorizationCheck for later authorization checks.
	 * usage example:
	 * <WebAccounts:AuthenticationForm usernamelabel="MyUserName:" passwordlabel="MyPassword:"
	 *	loginbuttonlabel="Login!" failuretext="login failed"/>
	 *
	 * will transform into:
	 * <WebStd:Formular method="Check" object="AuthenticationForm" module="WebAccounts">
	 * <table>
	 *   <tr><td>MyUserName:</td><td><input type="text" name="username" size="20"/></td></tr>
	 *   <tr><td>MyPassword:</td><td><input type="password" name="password" size="20"/></td></tr>
	 *   <tr><td colspan="2"><input type="submit" name="login" value="Login!"/></td></tr>
	 * </table>
	 * </WebStd:Formular>
	 *)
	 AuthenticationForm* = OBJECT(DynamicWebpage.StateLessActiveElement);

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR userNameLabel, passwordLabel, loginButtonLabel, failureText: Strings.String;
			formular, table, tr, td, htmlInput, pTag: XML.Element; container: XML.Container;
		BEGIN
			NEW(container);

			IF (HasLoginFailed(request)) THEN
				failureText := input.GetAttributeValue("failuretext");
				IF (failureText # NIL) THEN
					NEW(pTag); pTag.SetName("p"); container.AddContent(pTag);
					WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(failureText^))
				END
			END;

			userNameLabel := input.GetAttributeValue("usernamelabel");
			passwordLabel := input.GetAttributeValue("passwordlabel");
			loginButtonLabel := input.GetAttributeValue("loginbuttonlabel");

			NEW(formular); formular.SetName("WebStd:Formular"); container.AddContent(formular);
			formular.SetAttributeValue("xmlns:WebStd", "WebStd");
			formular.SetAttributeValue("method", "Check");
			formular.SetAttributeValue("object", "AuthenticationForm");
			formular.SetAttributeValue("module", ThisModuleNameStr);

			NEW(table); table.SetName("table");
			NEW(tr); tr.SetName("tr");

			NEW(td); td.SetName("td");
			IF (userNameLabel # NIL) THEN
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText(userNameLabel^))
			ELSE
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText(UsernameLabel))
			END;
			tr.AddContent(td);

			NEW(td); td.SetName("td");
			NEW(htmlInput); htmlInput.SetName("input");
			htmlInput.SetAttributeValue("type", "text");
			htmlInput.SetAttributeValue("name", "username");
			htmlInput.SetAttributeValue("size", "20");
			td.AddContent(htmlInput); tr.AddContent(td);

			table.AddContent(tr);

			NEW(tr); tr.SetName("tr");

			NEW(td); td.SetName("td");
			IF (passwordLabel # NIL) THEN
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText(passwordLabel^))
			ELSE
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText(PasswordLabel))
			END;
			tr.AddContent(td);

			NEW(td); td.SetName("td");
			NEW(htmlInput); htmlInput.SetName("input");
			htmlInput.SetAttributeValue("type", "password");
			htmlInput.SetAttributeValue("name", "password");
			htmlInput.SetAttributeValue("size", "20");
			td.AddContent(htmlInput); tr.AddContent(td);

			table.AddContent(tr);

			NEW(tr); tr.SetName("tr");

			NEW(td); td.SetName("td");
			td.SetAttributeValue("colspan", "2");
			NEW(htmlInput); htmlInput.SetName("input");
			htmlInput.SetAttributeValue("type", "submit");
			htmlInput.SetAttributeValue("name", "login");
			IF (loginButtonLabel # NIL) THEN
				htmlInput.SetAttributeValue("value", loginButtonLabel^)
			ELSE
				htmlInput.SetAttributeValue("value", LoginLabel)
			END;
			td.AddContent(htmlInput); tr.AddContent(td);

			table.AddContent(tr);
			formular.AddContent(table);

			RETURN container
		END Transform;

		PROCEDURE Check(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
			(* parameters "username", "password" *)
		VAR username, password: Strings.String;
		BEGIN
			username := params.GetParameterValueByName("username");
			password := params.GetParameterValueByName("password");
			IF ((username # NIL) & (password # NIL)) THEN
				Login(username^, password^, request)
			END
		END Check;

		PROCEDURE HasLoginFailed(request: HTTPSupport.HTTPRequest) : BOOLEAN;
		VAR pUsername, pPassword: ANY; usernameDyn, passwordDyn: DynamicStrings.DynamicString;
			username, password: Strings.String; session: HTTPSession.Session;
		BEGIN
			session := HTTPSession.GetSession(request); (* session # NIL *)
			pUsername := session.GetVariableValue(WebAccountsSessionVarUsername);
			pPassword := session.GetVariableValue(WebAccountsSessionVarPassword);
			IF ((pUsername # NIL) & (pPassword # NIL) & (pUsername IS DynamicStrings.DynamicString) &
				(pPassword IS DynamicStrings.DynamicString)) THEN
				usernameDyn := pUsername(DynamicStrings.DynamicString);
				passwordDyn := pPassword(DynamicStrings.DynamicString);
				username := usernameDyn.ToArrOfChar(); password := passwordDyn.ToArrOfChar();
				(* username # NIL & password # NIL *)
				RETURN GetAuthorizedWebAccount(username^, password^) = NIL
			ELSE
				RETURN FALSE
			END
		END HasLoginFailed;

    	PROCEDURE GetEventHandlers*() : DynamicWebpage.EventHandlerList;
		VAR list: DynamicWebpage.EventHandlerList;
		BEGIN
			NEW(list, 1);
			NEW(list[0], "Check", Check);
			RETURN list
		END GetEventHandlers;
	END AuthenticationForm;

	(** authorization check for a specfic domain, usage example:
	 * <WebAccounts:AuthorizationCheck domain="PrivateSpace"/>
	 * or authorization check for a web account, usage example
	 * <WebAccounts:AuthorizationCheck/>
	 * If the session is authorized then the transformation result is:
	 *  <Granted/>
	 * Otherwise it will result in:
	 *  <Denied/>
	 * An administartor is always authorized for each domain *)
	AuthorizationCheck* = OBJECT (DynamicWebpage.StateLessActiveElement);
		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR domainName: Strings.String; elem: XML.Element; account: WebAccount; domain: AuthorizationDomain;
			session: HTTPSession.Session; granted: BOOLEAN;
		BEGIN
			granted := FALSE;
			domainName := input.GetAttributeValue("domain");
			session := HTTPSession.GetSession(request);
			IF (IsSessionAuthorizedAsAdmin(session)) THEN
				granted := TRUE
			ELSE (* not an administrator *)
				account := GetAuthWebAccountForSession(session);
				IF (account # NIL) THEN
					IF (domainName # NIL) THEN
						domain := GetAuthorizationDomain(domainName^);
						IF ((domain # NIL) & (domain.IsMember(account))) THEN
							granted := TRUE
						END
					ELSE
						granted := TRUE
					END
				END
			END;
			NEW(elem);
			IF (granted) THEN
				elem.SetName("Granted");
			ELSE
				elem.SetName("Denied")
			END;
			RETURN elem
		END Transform;
	END AuthorizationCheck;

	(** authorization check for administrator rights, usage example:
	 * <WebAccounts:AuthorizationAsAdminCheck/>
	 * If the session is authorized as an administrator then the transformation result is:
	 *  <Granted/>
	 * Otherwise it will result in:
	 *  <Denied/>  *)
	AuthorizationAsAdminCheck* = OBJECT (DynamicWebpage.StateLessActiveElement);
		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR elem: XML.Element; session: HTTPSession.Session;
		BEGIN
			NEW(elem);
			session := HTTPSession.GetSession(request);
			IF (IsSessionAuthorizedAsAdmin(session)) THEN
				elem.SetName("Granted")
			ELSE
				elem.SetName("Denied")
			END;
			RETURN elem
		END Transform;
	END AuthorizationAsAdminCheck;

	(** display the actual username, usage example:
	 * <WebAccounts:GetUserName/>
	 * returns NIL if not authorized *)
	GetUserName* = OBJECT (DynamicWebpage.StateLessActiveElement);
		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR session: HTTPSession.Session; pUsername: ANY; usernameDyn: DynamicStrings.DynamicString;
			username: Strings.String;
		BEGIN
			session := HTTPSession.GetSession(request);
			pUsername := session.GetVariableValue(WebAccountsSessionVarUsername);
			IF ((pUsername # NIL) & (pUsername IS DynamicStrings.DynamicString)) THEN
				usernameDyn := pUsername(DynamicStrings.DynamicString);
				username := usernameDyn.ToArrOfChar();
				(* username # NIL *)
				RETURN WebStd.CreateXMLText(username^)
			END;
			RETURN NIL
		END Transform;
	END GetUserName;

	(** display all interested containers of the standard prevalence system in a feature tracker with their new entries.
	 * Usage example:
	 *  <WebAccounts:DisplayNewInterestedEntries id="myDisplay4"/>
	 *)
	DisplayNewInterestedEntries* = OBJECT(DynamicWebpage.StateFullActiveElement);

		VAR trackerOidPrefix: Strings.String;

		PROCEDURE &Init*;
		BEGIN trackerOidPrefix := DynamicWebpage.CreateNewObjectId() (* trackerOidPrefix # NIL *)
		END Init;

		PROCEDURE GetNewEntriesForContainer(containerName: ARRAY OF CHAR) : XML.Container;
		VAR container: XML.Container; h3, tracker, onlyNewEntries, searching, accessConstraint, edit, delete, denied: XML.Element;
			oidStr: Strings.String;
		BEGIN
			(* trackerOidPrefix # NIL *)
			NEW(oidStr, Strings.Length(trackerOidPrefix^)+Strings.Length(containerName)+1);
			Strings.Concat(trackerOidPrefix^, containerName, oidStr^);

			NEW(container);

			NEW(h3); h3.SetName("h3"); container.AddContent(h3);
			WebStd.AppendXMLContent(h3, WebStd.CreateXMLText(containerName));

			NEW(tracker); tracker.SetName("WebForum:FeatureTracker");  container.AddContent(tracker);
			tracker.SetAttributeValue("xmlns:WebForum", "WebForum");
			tracker.SetAttributeValue(DynamicWebpage.XMLAttributeObjectIdName, oidStr^);
			tracker.SetAttributeValue("containername", containerName);

			NEW(onlyNewEntries); onlyNewEntries.SetName("OnlyNewEntries"); tracker.AddContent(onlyNewEntries);

			NEW(searching); searching.SetName("Searching"); searching.SetAttributeValue("label",  "Search: ");
			tracker.AddContent(searching);

			NEW(accessConstraint); accessConstraint.SetName("AccessContraint"); tracker.AddContent(accessConstraint);

			NEW(edit); edit.SetName("Edit"); accessConstraint.AddContent(edit);
			NEW(denied); denied.SetName("Denied"); edit.AddContent(denied);

			NEW(delete); delete.SetName("Delete"); accessConstraint.AddContent(delete);
			NEW(denied); denied.SetName("Denied"); delete.AddContent(denied);

			RETURN container;
		END GetNewEntriesForContainer;

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR session: HTTPSession.Session; webAccount: WebAccount; interestedList: TFClasses.List; i: SIZE;
			p: ANY; dynStr: DynamicStrings.DynamicString; contName: Strings.String; container: XML.Container;
		BEGIN
			session := HTTPSession.GetSession(request);
			webAccount := GetAuthWebAccountForSession(session);
			IF (webAccount # NIL) THEN
				interestedList := webAccount.interestedContainers;
				IF (interestedList # NIL) THEN
					NEW(container);
					interestedList.Lock;
					FOR i := 0 TO interestedList.GetCount()-1 DO
						p := interestedList.GetItem(i);
						IF (p IS DynamicStrings.DynamicString) THEN
							dynStr := p(DynamicStrings.DynamicString); contName:= dynStr.ToArrOfChar();
							WebStd.AppendXMLContent(container, GetNewEntriesForContainer(contName^))
						END
					END;
					interestedList.Unlock;
					RETURN container
				END;
			END;
			RETURN NIL
		END Transform;
	END DisplayNewInterestedEntries;

	(** Transform to 'true' if the user is an authorized administrator otherwise to 'false'. Usage example:
	 *  <WebAccounts:IsAdministrator/>
	 * Transformation result is
	 *  <WebStd:IsEqual>
	 *	<Arg1><WebAccounts:AuthorizationAsAdminCheck/></Arg1>
	 *	<Arg2><Granted/></Arg2>
	 *  </WebStd:IsEqual>
	 *)
	IsAdministrator* = OBJECT(DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR isEqual, arg1, arg2, authCheck, granted: XML.Element;
		BEGIN
			NEW(isEqual); isEqual.SetName("WebStd:IsEqual");
			isEqual.SetAttributeValue("xmlns:WebStd", "WebStd");
			NEW(arg1); arg1.SetName("Arg1"); isEqual.AddContent(arg1);
			NEW(arg2); arg2.SetName("Arg2"); isEqual.AddContent(arg2);
			NEW(authCheck); authCheck.SetName("WebAccounts:AuthorizationAsAdminCheck"); arg1.AddContent(authCheck);
			authCheck.SetAttributeValue("xmlns:WebAccounts", ThisModuleNameStr);
			NEW(granted); granted.SetName("Granted"); arg2.AddContent(granted);
			RETURN isEqual
		END Transform;
	END IsAdministrator;

	(** Transform to 'true' if the user is an authorized user in the optionally specified domain otherwise to 'false'. Usage example:
	 *  <WebAccounts:IsAuthorized domain=".."/>
	 * Transformation result is
	 *  <WebStd:IsEqual>
	 *	<Arg1><WebAccounts:AuthorizationCheck domain=".."/></Arg1>
	 *	<Arg2><Granted/></Arg2>
	 *  </WebStd:IsEqual>
	 *)
	IsAuthorized* = OBJECT(DynamicWebpage.StateLessActiveElement)
		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR isEqual, arg1, arg2, authCheck, granted: XML.Element; domainName: Strings.String;
		BEGIN
			domainName := input.GetAttributeValue("domain");
			NEW(isEqual); isEqual.SetName("WebStd:IsEqual");
			isEqual.SetAttributeValue("xmlns:WebStd", "WebStd");
			NEW(arg1); arg1.SetName("Arg1"); isEqual.AddContent(arg1);
			NEW(arg2); arg2.SetName("Arg2"); isEqual.AddContent(arg2);
			NEW(authCheck); authCheck.SetName("WebAccounts:AuthorizationCheck"); arg1.AddContent(authCheck);
			authCheck.SetAttributeValue("xmlns:WebAccounts", ThisModuleNameStr);
			IF (domainName # NIL) THEN
				authCheck.SetAttributeValue("domain", domainName^)
			END;
			NEW(granted); granted.SetName("Granted"); arg2.AddContent(granted);
			RETURN isEqual
		END Transform;
	END IsAuthorized;

	(** Formular to register for a new user account. User account must be later activated by the administrator.
	 * If user is authorized then this active element results into NIL. If the user has been registered then it also returns NIL;
	 * If the user has been successfully registered then the content of 'IfSuccessfull' will be transformed and displayed
	 * Usage example:
	 *  <WebAccounts:NewUserFormular id="MyNewUserForumlar3" submitlabel="OK">
	 *       <IfSuccessfull></IfSuccessfull>
	 *  </WebAccounts:NewUserFormular>
	 *)
	NewUserFormular* = OBJECT(DynamicWebpage.StateFullActiveElement);
		VAR
			statusMsg: XML.Content;
			isRegistered: BOOLEAN;
			ifSuccessFull: XML.Element;

		PROCEDURE &Init*;
		BEGIN statusMsg := NIL; isRegistered := FALSE
		END Init;

		PROCEDURE PreTransform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		BEGIN
			ifSuccessFull := WebStd.GetXMLSubElement(elem, "IfSuccessfull");
			elem.RemoveContent(ifSuccessFull);
			RETURN elem
		END PreTransform;

		PROCEDURE Transform*(elem: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR accountContainerName: Strings.String; formular, input: XML.Element; content: XML.Content;
			objectId, submitLabel: Strings.String; container: XML.Container; session: HTTPSession.Session;
		BEGIN
			session := HTTPSession.GetSession(request);
			NEW(container);
			IF ((~isRegistered) & (GetAuthWebAccountForSession(session) = NIL)) THEN
				objectId := elem.GetAttributeValue(DynamicWebpage.XMLAttributeObjectIdName); (* objectId # NIL by DynamicWebPagePlugin logic *)
				accountContainerName := WebStd.GetString(WebAccountsContainerName);

				WebStd.AppendXMLContent(container, statusMsg);

				NEW(formular); formular.SetName("WebStd:Formular"); container.AddContent(formular);
				formular.SetAttributeValue("xmlns:WebStd", "WebStd");
				formular.SetAttributeValue("method", "InsertNewAccount");
				formular.SetAttributeValue("object", "NewUserFormular");
				formular.SetAttributeValue("module", ThisModuleNameStr);
				formular.SetAttributeValue("objectid", objectId^);

				content := GetWebAccountInsertView(accountContainerName, NIL, FALSE, request);
				WebStd.AppendXMLContent(formular, content);

				submitLabel := elem.GetAttributeValue("submitlabel");
				IF (submitLabel # NIL) THEN
					submitLabel := WebStd.GetString(DefaultNewAccountSubmitLabel)
				END;

				NEW(input); input.SetName("input"); formular.AddContent(input);
				input.SetAttributeValue("type", "submit");
				input.SetAttributeValue("name", "submitbutton");
				input.SetAttributeValue("value", submitLabel^);

				RETURN container
			ELSE
				WebStd.CopyXMLSubContents(ifSuccessFull, container);
				RETURN container
			END
		END Transform;

		PROCEDURE InsertNewAccount(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		VAR accountContainerName, username, password: Strings.String; accountCont: WebStd.PersistentDataContainer;
			(* parameters "username", "password", "confpassword", "email", "defaultmsgname" or "accountoid"*)
		BEGIN
			LoadPrevalenceSystem;
			accountContainerName := WebStd.GetString(WebAccountsContainerName);
			accountCont := WebStd.GetPersistentDataContainer(prevSys, WebAccountsContainerName);
			username := params.GetParameterValueByName("username");
			password := params.GetParameterValueByName("password");
			IF (InsertWebAccountObject(accountContainerName, accountCont, NIL, FALSE, request, params, statusMsg)) THEN
				isRegistered := TRUE
			END
		END InsertNewAccount;

		PROCEDURE GetEventHandlers*() : DynamicWebpage.EventHandlerList;
		VAR list: DynamicWebpage.EventHandlerList;
		BEGIN
			NEW(list, 1);
			NEW(list[0], "InsertNewAccount", InsertNewAccount);
			RETURN list
		END GetEventHandlers;
	END NewUserFormular;

	AdministratorInfo = OBJECT
		VAR
			name, password: Strings.String;

		PROCEDURE &Init*(adminName, adminPwd: ARRAY OF CHAR);
		BEGIN
			name := WebStd.GetString(adminName);
			password := WebStd.GetString(adminPwd)
		END Init;
	END AdministratorInfo;

	VAR
		webAccountDesc: PrevalenceSystem.PersistentObjectDescriptor; (* descriptor for WebAccount *)
		authorizationDomainDesc: PrevalenceSystem.PersistentObjectDescriptor; (* descriptor for AuthorizationDomain *)
		administrators: TFClasses.List; (* List of AdministratorInfo *)
		prevSys: PrevalenceSystem.PrevalenceSystem;

	(** get and load the prevalence system required for WebAccounts *)
	PROCEDURE GetPrevalenceSystem*() : PrevalenceSystem.PrevalenceSystem;
	BEGIN
		LoadPrevalenceSystem;
		RETURN prevSys
	END GetPrevalenceSystem;

	(** returns true iff the session is an authorized administrator *)
	PROCEDURE IsSessionAuthorizedAsAdmin*(session: HTTPSession.Session) : BOOLEAN;
	VAR pUsername, pPassword: ANY; usernameDyn, passwordDyn: DynamicStrings.DynamicString;
		username, password: Strings.String;
	BEGIN
		pUsername := session.GetVariableValue(WebAccountsSessionVarUsername);
		pPassword := session.GetVariableValue(WebAccountsSessionVarPassword);
		IF ((pUsername # NIL) & (pPassword # NIL) & (pUsername IS DynamicStrings.DynamicString) &
			(pPassword IS DynamicStrings.DynamicString)) THEN
			usernameDyn := pUsername(DynamicStrings.DynamicString);
			passwordDyn := pPassword(DynamicStrings.DynamicString);
			username := usernameDyn.ToArrOfChar(); password := passwordDyn.ToArrOfChar();
			(* username # NIL & password # NIL *)
			RETURN IsAuthorizedAsAdmin(username^, password^)
		END;
		RETURN FALSE
	END IsSessionAuthorizedAsAdmin;

	(** returns true iff the 'username' / 'pwd' pair is an authorized administrator *)
	PROCEDURE IsAuthorizedAsAdmin*(username, password: ARRAY OF CHAR) : BOOLEAN;
	VAR i: SIZE; p: ANY; adminInfo: AdministratorInfo;
	BEGIN (* administrators # NIL *)
		administrators.Lock;
		FOR i := 0 TO administrators.GetCount()-1 DO
			p := administrators.GetItem(i); adminInfo := p(AdministratorInfo);
			(* adminInfo # NIL & adminInfo.name # NIL & adminInfo.password # NIL *)
			IF ((adminInfo.name^ = username) & (adminInfo.password^ = password)) THEN
				administrators.Unlock;
				RETURN TRUE
			END
		END;
		administrators.Unlock;
		RETURN FALSE
	END IsAuthorizedAsAdmin;

	(** return the authorized WebAcccount for a session (session # NIL). If not authorized or not activated then it returns NIL *)
	PROCEDURE GetAuthWebAccountForSession*(session: HTTPSession.Session) : WebAccount;
	VAR pUsername, pPassword: ANY; usernameDyn, passwordDyn: DynamicStrings.DynamicString;
		username, password: Strings.String; webAccount: WebAccount;
	BEGIN
		pUsername := session.GetVariableValue(WebAccountsSessionVarUsername);
		pPassword := session.GetVariableValue(WebAccountsSessionVarPassword);
		IF ((pUsername # NIL) & (pPassword # NIL) & (pUsername IS DynamicStrings.DynamicString) &
			(pPassword IS DynamicStrings.DynamicString)) THEN
			usernameDyn := pUsername(DynamicStrings.DynamicString);
			passwordDyn := pPassword(DynamicStrings.DynamicString);
			username := usernameDyn.ToArrOfChar(); password := passwordDyn.ToArrOfChar();
			(* username # NIL & password # NIL *)
			webAccount := GetAuthorizedWebAccount(username^, password^);
			IF ((webAccount # NIL) & (webAccount.isActivated)) THEN
				RETURN webAccount
			ELSE
				RETURN NIL
			END
		END;
		RETURN NIL
	END GetAuthWebAccountForSession;

	(** returns the authorized web account for 'username' / 'password' pair. If not authorized or not activated then it returns NIL *)
	PROCEDURE GetAuthorizedWebAccount*(username, password: ARRAY OF CHAR) : WebAccount;
	VAR webAccount: WebAccount;
	BEGIN
		webAccount := GetWebAccount(username);
		IF ((webAccount # NIL) & (webAccount.AgreesWithPassword(password)) & (webAccount.isActivated)) THEN
			RETURN webAccount
		END;
		RETURN NIL
	END GetAuthorizedWebAccount;

	(** get the webaccount for a specific 'username'. If no such web account is present then NIL is returned. *)
	PROCEDURE GetWebAccount*(username: ARRAY OF CHAR) : WebAccount;
	VAR persCont: WebStd.PersistentDataContainer; list: WebStd.PersistentDataObjectList; i: SIZE;
		webAccount: WebAccount;
	BEGIN
		LoadPrevalenceSystem;
		persCont := WebStd.GetPersistentDataContainer(prevSys, WebAccountsContainerName);
		(* persCont # NIL *)
		list := persCont.GetElementList(WebStd.DefaultPersistentDataFilter, NIL);
		IF (list # NIL) THEN
			FOR i := 0 TO LEN(list)-1 DO
				IF (list[i] IS WebAccount) THEN
					webAccount := list[i](WebAccount);
					IF ((webAccount.username # NIL) & (webAccount.username^ = username)) THEN
						RETURN webAccount
					END
				END
			END
		END;
		RETURN NIL
	END GetWebAccount;

	(** get the authorization domain specified with 'name'. if not present then NIL is returned. *)
	PROCEDURE GetAuthorizationDomain*(name: ARRAY OF CHAR) : AuthorizationDomain;
	VAR persCont: WebStd.PersistentDataContainer; list: WebStd.PersistentDataObjectList; i: SIZE;
		domain: AuthorizationDomain;
	BEGIN
		LoadPrevalenceSystem;
		persCont := WebStd.GetPersistentDataContainer(prevSys, WebAuthDomainContainerName);
		(* persCont # NIL *)
		list := persCont.GetElementList(WebStd.DefaultPersistentDataFilter, NIL);
		IF (list # NIL) THEN
			FOR i := 0 TO LEN(list)-1 DO
				IF (list[i] IS AuthorizationDomain) THEN
					domain := list[i](AuthorizationDomain);
					IF ((domain.name # NIL) & (domain.name^ = name)) THEN
						RETURN domain
					END
				END
			END
		END;
		RETURN NIL
	END GetAuthorizationDomain;

	(* login as username with password, set this information in the session *)
	PROCEDURE Login(username, password: ARRAY OF CHAR; request: HTTPSupport.HTTPRequest);
	VAR usernameDyn, passwordDyn: DynamicStrings.DynamicString; session: HTTPSession.Session; webAccount: WebAccount;
	BEGIN
		NEW(usernameDyn); NEW(passwordDyn);
		usernameDyn.Append(username); passwordDyn.Append(password);
		session := HTTPSession.GetSession(request);
		session.AddVariableValue(WebAccountsSessionVarUsername, usernameDyn);
		session.AddVariableValue(WebAccountsSessionVarPassword, passwordDyn);
		webAccount := GetAuthWebAccountForSession(session);
		IF (webAccount # NIL) THEN
			webAccount.SetLoginTimeNow
		END
	END Login;

	PROCEDURE GetWebAccountInsertView(accountContainerName: Strings.String;
		superEntry: WebComplex.WebForumEntry; allowActivation: BOOLEAN; request: HTTPSupport.HTTPRequest): XML.Content;
	VAR table, tr, td, select, option: XML.Element; list: WebStd.PersistentDataObjectList; i: SIZE;
		webAccount: WebAccount; oidStr: ARRAY 14 OF CHAR; accountCont: WebStd.PersistentDataContainer;
	BEGIN
		NEW(table); table.SetName("table");
		IF ((accountContainerName # NIL) & (accountContainerName^ = WebAccountsContainerName)) THEN
			WebComplex.AddTextFieldInputRow(table, UsernameLabel, "username", NIL);
			WebComplex.AddPasswordFieldInputRow(table, PasswordLabel, "password");
			WebComplex.AddPasswordFieldInputRow(table, ConfirmPasswordLabel, "confpassword");

			IF (allowActivation) THEN
				WebStd.AppendXMLContent(table, GetActivationEditRow(FALSE))
			END;

			WebComplex.AddTextFieldInputRow(table, EmailLabel, "email", NIL);
			WebComplex.AddTextFieldInputRow(table, DefaultMessageNameLabel, "defaultmsgname", NIL);
	ELSE
			NEW(tr); tr.SetName("tr"); table.AddContent(tr);
			NEW(td); td.SetName("td"); tr.AddContent(td);
			WebStd.AppendXMLContent(td, WebStd.CreateXMLText(SelectWebAccountLabel));
			NEW(td); td.SetName("td"); tr.AddContent(td);
			accountCont := WebStd.GetPersistentDataContainer(prevSys, WebAccountsContainerName);
			IF (accountCont # NIL) THEN
				list := accountCont.GetElementList(WebStd.DefaultPersistentDataFilter, NIL)
			ELSE
				list := NIL
			END;
			IF (list # NIL) THEN
				NEW(select); select.SetName("select");
				select.SetAttributeValue("name", "accountoid");
				FOR i := 0 TO LEN(list)-1 DO
					IF (list[i] IS WebAccount) THEN
						webAccount := list[i](WebAccount);
						Strings.IntToStr(webAccount.oid, oidStr);
						NEW(option); option.SetName("option"); select.AddContent(option);
						option.SetAttributeValue("value", oidStr);
						IF ((webAccount.username # NIL) & (webAccount.username^ # "")) THEN
							WebStd.AppendXMLContent(option, WebStd.CreateXMLText(webAccount.username^))
						ELSE
							WebStd.AppendXMLContent(option, WebStd.CreateXMLText(" "))
						END
					END
				END;
				td.AddContent(select);
			ELSE
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText("no web accounts present"))
			END
		END;
		RETURN table
	END GetWebAccountInsertView;

	PROCEDURE InsertWebAccountObject(accountContainerName: Strings.String; container: WebStd.PersistentDataContainer;
	superEntry: WebComplex.WebForumEntry; activated: BOOLEAN; request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList;
		VAR statusMsg: XML.Content) : BOOLEAN;
		(* parameters "username", "password", "confpassword", "email", "defaultmsgname" or "accountoid"*)
	VAR username, password, confpassword, email, defaultmsgname, accountOidStr: Strings.String; obj: WebAccount;
		accountOid: LONGINT; persObj: PrevalenceSystem.PersistentObject;
	BEGIN
		IF ((accountContainerName # NIL) & (accountContainerName^ = WebAccountsContainerName)) THEN
			username := params.GetParameterValueByName("username");
			password := params.GetParameterValueByName("password");
			confpassword := params.GetParameterValueByName("confpassword");
			email := params.GetParameterValueByName("email");
			defaultmsgname := params.GetParameterValueByName("defaultmsgname");

			IF ((username = NIL) OR (username^ = "")) THEN
				statusMsg := WebStd.CreateXMLText(UsernameIsMissingLabel);
				RETURN FALSE
			ELSIF (GetWebAccount(username^) # NIL) THEN
				statusMsg := WebStd.CreateXMLText(UsernameIsAlreayUsedLabel);
				RETURN FALSE
			ELSIF ((password = NIL) OR (confpassword = NIL) OR (Strings.Length(password^) <  MinPasswordLength)) THEN
				statusMsg := WebStd.CreateXMLText(PasswordTooShortLabel);
				RETURN FALSE
			ELSIF (password^ # confpassword^) THEN
				statusMsg := WebStd.CreateXMLText(PasswordDoNotAgreeLabel);
				RETURN FALSE
			ELSE
				NEW(obj); obj.username := username; obj.password := password; obj.email := email;
				obj.defaultMsgName := defaultmsgname; obj.isActivated := activated;
				container.AddPersistentDataObject(obj, webAccountDesc); (* adds it also to the prevalence system *)
				RETURN TRUE
			END
		ELSE
			IF (prevSys # NIL) THEN
				accountOidStr := params.GetParameterValueByName("accountoid");
				IF (accountOidStr # NIL) THEN
					Strings.StrToInt(accountOidStr^, accountOid);
					persObj := prevSys.GetPersistentObject(accountOid);
					IF ((persObj # NIL) & (persObj IS WebAccount)) THEN
						obj := persObj(WebAccount);
						container.AddPersistentDataObject(obj, webAccountDesc);
						RETURN TRUE
					ELSE
						statusMsg := WebStd.CreateXMLText(WebAccountIsNotPresentLabel);
						RETURN FALSE
					END
				ELSE
					statusMsg := WebStd.CreateXMLText(NoWebAccountSelectedLabel);
					RETURN TRUE
				END
			ELSE
				statusMsg := WebStd.CreateXMLText("prevalence system not loaded yet");
				RETURN FALSE
			END
		END
	END InsertWebAccountObject;

	(* update an web account by WebAccountView or WebAccountDatagrid active element *)
	PROCEDURE UpdateWebAccountObject(obj: WebComplex.WebForumEntry; modifyUsername, modifyActivationState: BOOLEAN;
		request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
	VAR username, password, confpassword, email, defaultmsgname, activatedStr: Strings.String;
		webAccount, otherAccount: WebAccount; activated: BOOLEAN;
	BEGIN (* obj # NIL *)
		IF (obj IS WebAccount) THEN
			webAccount := obj(WebAccount);
			username := params.GetParameterValueByName("username");
			password := params.GetParameterValueByName("password");
			confpassword := params.GetParameterValueByName("confpassword");
			email := params.GetParameterValueByName("email");
			defaultmsgname := params.GetParameterValueByName("defaultmsgname");
			activatedStr := params.GetParameterValueByName("activated");
			activated := ((activatedStr # NIL) & (activatedStr^ = "true"));

			IF (modifyUsername) THEN
				IF ((username = NIL) OR (username^ = "")) THEN
					statusMsg := WebStd.CreateXMLText(UsernameIsMissingLabel);
					RETURN FALSE
				END;
				otherAccount := GetWebAccount(username^);
				IF ((otherAccount # NIL) & (otherAccount # webAccount)) THEN
					statusMsg := WebStd.CreateXMLText(UsernameIsAlreayUsedLabel);
					RETURN FALSE
				END
			END;
			IF ((password # NIL) & (password^ # "")) THEN
				IF ((confpassword = NIL) OR (Strings.Length(password^) <  MinPasswordLength)) THEN
					statusMsg := WebStd.CreateXMLText(PasswordTooShortLabel);
					RETURN FALSE
				ELSIF (password^ # confpassword^) THEN
					statusMsg := WebStd.CreateXMLText(PasswordDoNotAgreeLabel);
					RETURN FALSE
				END
			END;
			webAccount.BeginModification;
			IF (modifyUsername) THEN
				webAccount.username := username
			END;
			IF ((password # NIL) & (password^ # "")) THEN
				webAccount.password := password;
			END;
			webAccount.email := email;
			webAccount.defaultMsgName := defaultmsgname;
			IF (modifyActivationState) THEN
				webAccount.isActivated := activated
			END;
			webAccount.EndModification;
			RETURN TRUE
		ELSE
			statusMsg := WebStd.CreateXMLText("object is not of type WebAccount");
			RETURN FALSE
		END
	END UpdateWebAccountObject;

	PROCEDURE GetActivationEditRow(isCurrentlyActivated: BOOLEAN) : XML.Content;
	VAR tr, td, select, option: XML.Element;
	BEGIN (* table # NIL *)
		NEW(tr); tr.SetName("tr");
		NEW(td); td.SetName("td"); tr.AddContent(td);
		WebStd.AppendXMLContent(td, WebStd.CreateXMLText(ActivatedLabel));
		NEW(td); td.SetName("td"); tr.AddContent(td);
		NEW(select); select.SetName("select"); td.AddContent(select);
		select.SetAttributeValue("name", "activated");
		NEW(option); option.SetName("option"); select.AddContent(option);
		option.SetAttributeValue("value", "true"); WebStd.AppendXMLContent(option, WebStd.CreateXMLText(YesLabel));
		IF (isCurrentlyActivated) THEN
			option.SetAttributeValue("selected", "true")
		END;
		NEW(option); option.SetName("option"); select.AddContent(option);
		option.SetAttributeValue("value", "false"); WebStd.AppendXMLContent(option, WebStd.CreateXMLText(NoLabel));
		IF (~isCurrentlyActivated) THEN
			option.SetAttributeValue("selected", "true")
		END;
		RETURN tr
	END GetActivationEditRow;

	(* deletes a web account in all authorization domains *)
	PROCEDURE DeleteFromAllDomains(account: WebAccount);
	VAR persCont: WebStd.PersistentDataContainer; list: WebStd.PersistentDataObjectList; i: SIZE;
		domain: AuthorizationDomain;
	BEGIN (* account # NIL *)
		LoadPrevalenceSystem;
		persCont := WebStd.GetPersistentDataContainer(prevSys, WebAuthDomainContainerName);
		(* persCont # NIL *)
		list := persCont.GetElementList(WebStd.DefaultPersistentDataFilter, NIL);
		IF (list # NIL) THEN
			FOR i := 0 TO LEN(list)-1 DO
				IF (list[i] IS AuthorizationDomain) THEN
					domain := list[i](AuthorizationDomain);
					domain.members.RemovePersistentDataObject(account)
				END
			END
		END
	END DeleteFromAllDomains;

	(* load the prevalence system for web accounts *)
	PROCEDURE LoadPrevalenceSystem;
	BEGIN
		IF (prevSys = NIL) THEN
			(* init prevalence system *)
			prevSys := PrevalenceSystem.GetPrevalenceSystem(WebAccountsPrevSysName);
			IF (prevSys = NIL) THEN
				KernelLog.String("Create new PrevanlenceSystem '"); KernelLog.String(WebAccountsPrevSysName); KernelLog.String("'.");
				KernelLog.Ln;
				NEW(prevSys, WebAccountsPrevSysName, SnapShotFileName, LogFileName);
				IF (prevSys = NIL) THEN HALT(9999) END
			END
		END
	END LoadPrevalenceSystem;

	PROCEDURE ReadWebAdministratorInfo;
	VAR elem, child, subChild: XML.Element; enum, subEnum: XMLObjects.Enumerator; p, pSub: ANY;
		childName, subChildName, adminName, adminPwd, attrName, attrValue: Strings.String;
		adminInfo: AdministratorInfo;
	BEGIN
		NEW(administrators);
		IF (Configuration.config # NIL) THEN
			elem := Configuration.config.GetRoot();
			elem := Configuration.GetNamedElement(elem, "Section", DynamicWebpage.ConfigurationSupperSectionName);
			IF (elem # NIL) THEN
				elem := Configuration.GetNamedElement(elem, "Section", ConfigurationSubSectionName);
				IF (elem # NIL) THEN
					enum := elem.GetContents();
					WHILE (enum.HasMoreElements()) DO
						p := enum.GetNext();
						IF (p IS XML.Element) THEN
							child := p(XML.Element); childName := child.GetName();
							attrName := child.GetAttributeValue("name");
							IF ((childName^ = "Section") & (attrName # NIL) & (attrName^ = ConfigurationSubSubSectionName)) THEN
								adminName := NIL; adminPwd := NIL;
								subEnum := child.GetContents();
								WHILE (subEnum.HasMoreElements()) DO
									pSub := subEnum.GetNext();
									IF (pSub IS XML.Element) THEN
										subChild := pSub(XML.Element); subChildName := subChild.GetName();
										IF (subChildName^ = "Setting") THEN
											attrName := subChild.GetAttributeValue("name");
											attrValue := subChild.GetAttributeValue("value");
											IF ((attrName # NIL) & (attrName^ = "Name") & (attrValue # NIL)) THEN
												adminName := attrValue
											ELSIF ((attrName # NIL) & (attrName^ = "Password") & (attrValue # NIL)) THEN
												adminPwd := attrValue
											END
										END
									END
								END;
								IF ((adminName # NIL) & (adminPwd # NIL)) THEN
									NEW(adminInfo, adminName^, adminPwd^);
									administrators.Add(adminInfo)
								ELSE
									KernelLog.String("WebAccounts: Missing setting with name 'Name' or 'Password' for section '");
									KernelLog.String(ConfigurationSubSubSectionName); KernelLog.String("' in Configuration.XML."); KernelLog.Ln
								END
							END
						END
					END
				ELSE
					KernelLog.String("WebAccounts: In Configuration.XML under '");
					KernelLog.String(DynamicWebpage.ConfigurationSupperSectionName); KernelLog.String("' is no section '");
					KernelLog.String(ConfigurationSubSectionName); KernelLog.String(" defined."); KernelLog.Ln
				END
			ELSE
				KernelLog.String("WebAccounts: In Configuration.XML is no section '");
				KernelLog.String(DynamicWebpage.ConfigurationSupperSectionName); KernelLog.String("' defined."); KernelLog.Ln
			END
		ELSE
			KernelLog.String("WebAccounts: Cannot open Configuration.XML"); KernelLog.Ln
		END
	END ReadWebAdministratorInfo;

	PROCEDURE GetNewWebAccount() : PrevalenceSystem.PersistentObject;
	VAR obj: WebAccount;
	BEGIN NEW(obj); RETURN obj
	END GetNewWebAccount;

	PROCEDURE GetNewAuthorizationDomain() : PrevalenceSystem.PersistentObject;
	VAR obj: AuthorizationDomain;
	BEGIN NEW(obj); RETURN obj
	END GetNewAuthorizationDomain;

	(** used by the prevalence system *)
	PROCEDURE GetPersistentObjectDescriptors*() : PrevalenceSystem.PersistentObjectDescSet;
	VAR descSet : PrevalenceSystem.PersistentObjectDescSet;
		descs: ARRAY 2 OF PrevalenceSystem.PersistentObjectDescriptor;
	BEGIN
		descs[0] := webAccountDesc;
		descs[1] := authorizationDomainDesc;
		NEW(descSet, descs);
		RETURN descSet
	END GetPersistentObjectDescriptors;

	PROCEDURE CreateWebAccountDatagridElement() : DynamicWebpage.ActiveElement;
	VAR obj: WebAccountDatagrid;
	BEGIN
		NEW(obj); RETURN obj
	END CreateWebAccountDatagridElement;

	PROCEDURE CreateAuthDomainDatagridElement() : DynamicWebpage.ActiveElement;
	VAR obj: AuthorizationDomainDatagrid;
	BEGIN
		NEW(obj); RETURN obj
	END CreateAuthDomainDatagridElement;

	PROCEDURE CreateAuthenticationFormElement() : DynamicWebpage.ActiveElement;
	VAR obj: AuthenticationForm;
	BEGIN
		NEW(obj); RETURN obj
	END CreateAuthenticationFormElement;

	PROCEDURE CreateAuthorizationCheckElement() : DynamicWebpage.ActiveElement;
	VAR obj: AuthorizationCheck;
	BEGIN
		NEW(obj); RETURN obj
	END CreateAuthorizationCheckElement;

	PROCEDURE CreateAuthAsAdminCheckElement() : DynamicWebpage.ActiveElement;
	VAR obj: AuthorizationAsAdminCheck;
	BEGIN
		NEW(obj); RETURN obj
	END CreateAuthAsAdminCheckElement;

	PROCEDURE CreateWebAccountViewElement() : DynamicWebpage.ActiveElement;
	VAR obj: WebAccountView;
	BEGIN
		NEW(obj); RETURN obj
	END CreateWebAccountViewElement;

	PROCEDURE CreateGetUserNameElement() : DynamicWebpage.ActiveElement;
	VAR obj: GetUserName;
	BEGIN
		NEW(obj); RETURN obj
	END CreateGetUserNameElement;

	PROCEDURE CreateDispNewEntriesElement() : DynamicWebpage.ActiveElement;
	VAR obj: DisplayNewInterestedEntries;
	BEGIN
		NEW(obj); RETURN obj
	END CreateDispNewEntriesElement;

	PROCEDURE CreateIsAdministratorElement() : DynamicWebpage.ActiveElement;
	VAR obj: IsAdministrator;
	BEGIN
		NEW(obj); RETURN obj
	END CreateIsAdministratorElement;

	PROCEDURE CreateIsAuthorizedElement() : DynamicWebpage.ActiveElement;
	VAR obj: IsAuthorized;
	BEGIN
		NEW(obj); RETURN obj
	END CreateIsAuthorizedElement;

	PROCEDURE CreateNewUserFormularElement() : DynamicWebpage.ActiveElement;
	VAR obj: NewUserFormular;
	BEGIN
		NEW(obj); RETURN obj
	END CreateNewUserFormularElement;

	PROCEDURE GetActiveElementDescriptors*() : DynamicWebpage.ActiveElementDescSet;
	VAR desc: POINTER TO ARRAY OF DynamicWebpage.ActiveElementDescriptor;
		descSet: DynamicWebpage.ActiveElementDescSet;
	BEGIN
		NEW(desc, 11);
		NEW(desc[0], "WebAccountDatagrid", CreateWebAccountDatagridElement);
		NEW(desc[1], "AuthorizationDomainDatagrid", CreateAuthDomainDatagridElement);
		NEW(desc[2], "AuthenticationForm", CreateAuthenticationFormElement);
		NEW(desc[3], "AuthorizationCheck", CreateAuthorizationCheckElement);
		NEW(desc[4], "AuthorizationAsAdminCheck", CreateAuthAsAdminCheckElement);
		NEW(desc[5], "WebAccountView", CreateWebAccountViewElement);
		NEW(desc[6], "GetUserName", CreateGetUserNameElement);
		NEW(desc[7], "DisplayNewInterestedEntries", CreateDispNewEntriesElement);
		NEW(desc[8], "IsAdministrator", CreateIsAdministratorElement);
		NEW(desc[9], "IsAuthorized", CreateIsAuthorizedElement);
		NEW(desc[10], "NewUserFormular", CreateNewUserFormularElement);
		NEW(descSet, desc^); RETURN descSet
	END GetActiveElementDescriptors;

BEGIN
	prevSys := NIL;
	NEW(webAccountDesc, ThisModuleNameStr, "WebAccount", GetNewWebAccount);
	NEW(authorizationDomainDesc, ThisModuleNameStr, "AuthorizationDomain", GetNewAuthorizationDomain);

	ReadWebAdministratorInfo
END WebAccounts.
