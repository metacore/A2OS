MODULE WebComplex; (** AUTHOR "Luc Blaeser"; PURPOSE "Complex Active Element Library for Dynamic Webpage Generation" *)

IMPORT DynamicWebpage, WebStd, HTTPSupport, PrevalenceSystem, XML, Strings, KernelLog;

CONST
	(** modi of a table cell of the web forum *)
	WebForumNormalCell* = 0; (** normal cell *)
	WebForumDetailViewCell* = 1; (** cell will be activated to show detail view by clicking on it *)
	WebForumEditViewCell* = 2; (** cell will be activated to show edit view by clicking on it *)
	WebForumDeleteCell* = 3; (** cell will be activated to allow deletion of a web forum entry *)
	WebForumSubInsertViewCell* = 4; (** cell will be activated to allow insert view for subentries by clicking on it *)

	(** internal state of the web forum element *)
	WebForumOverviewState = 0;
	WebForumDetailViewState = 1;
	WebForumEditViewState = 2;
	WebForumInsertViewState = 3;

	WebForumStandardBackLabel = "Back";
	WebForumStandardEmptyList = "no entries";
	WebForumStandardInsertText = "insert a new entry";
	WebForumStandardSubmitLabel = "Save";
	WebForumStdUnapplySortLabel = "unapply sorting";
	WebForumStdUnapplyFilterLabel = "unapply search filter";

TYPE
	 (** abstract web forum support *)

	 TableCell* = OBJECT
	 VAR
	 	content*: XML.Content;
	 	modus*: LONGINT; (** WebForumNormalCell, WebForumDetailViewCell, WebForumEditViewCell,
	 										   WebForumDeleteCell, WebForumSubInsertViewCell *)

	 	PROCEDURE &Init*(cellContent: XML.Content; cellModus: LONGINT);
	 	BEGIN content := cellContent; modus := cellModus
	 	END Init;
	 END TableCell;

	 HeaderCell* = OBJECT
	 VAR
	 	content*: XML.Content;
	 	compareFunction*: WebStd.PersistentDataCompare;

	 	PROCEDURE &Init*(cellContent: XML.Content; compFunc: WebStd.PersistentDataCompare);
	 	BEGIN
	 		content := cellContent; compareFunction := compFunc
	 	END Init;
	 END HeaderCell;

	 TableRow* = POINTER TO ARRAY OF TableCell;
	 HeaderRow* = POINTER TO ARRAY OF HeaderCell;

	 (** abstract hierarchical web forum entry *)
	 WebForumEntry* = OBJECT (WebStd.PersistentDataObject)
	 	VAR
	 		subEntries*: WebStd.PersistentDataContainer; (* PersistentDataContainer of WebForumEntry *)
	 		superEntry*: WebForumEntry;

		(** override, methods Internalize/Externlaize , this methods persist subEntries and superEntry fields *)
	    PROCEDURE Internalize*(input: XML.Content);
	    VAR container: XML.Container; elem: XML.Element; oidStr: Strings.String;
			persObj: PrevalenceSystem.PersistentObject; oidNr: LONGINT;
	    BEGIN
	    	container := input(XML.Container);

			elem := WebStd.GetXMLSubElement(container, "SubEntries");
			subEntries := NIL;
			IF (elem # NIL) THEN
				oidStr := WebStd.GetXMLCharContent(elem);
				IF (oidStr # NIL) THEN
					Strings.StrToInt(oidStr^, oidNr);
					persObj := PrevalenceSystem.GetPersistentObject(oidNr);
					IF ((persObj # NIL) & (persObj IS WebStd.PersistentDataContainer)) THEN
						subEntries := persObj(WebStd.PersistentDataContainer)
					ELSE
						HALT(9999)
					END
				END
			END;

			elem := WebStd.GetXMLSubElement(container, "SuperEntry");
			superEntry := NIL;
			IF (elem # NIL) THEN
				oidStr := WebStd.GetXMLCharContent(elem);
				IF (oidStr # NIL) THEN
					Strings.StrToInt(oidStr^, oidNr);
					persObj := PrevalenceSystem.GetPersistentObject(oidNr);
					IF ((persObj # NIL) & (persObj IS WebForumEntry)) THEN
						superEntry := persObj(WebForumEntry)
					ELSE
						HALT(9999)
					END
				END
			END
	    END Internalize;

	    PROCEDURE Externalize*() : XML.Content;
	    VAR container: XML.Container; elem: XML.Element; oidStr: ARRAY 14 OF CHAR;
	    BEGIN
	    	NEW(container);
	    	IF (subEntries # NIL) THEN
				NEW(elem); elem.SetName("SubEntries");
				Strings.IntToStr(subEntries.oid, oidStr);
				WebStd.AppendXMLContent(elem, WebStd.CreateXMLText(oidStr));
				container.AddContent(elem)
			END;

			IF (superEntry # NIL) THEN
				NEW(elem); elem.SetName("SuperEntry");
				Strings.IntToStr(superEntry.oid, oidStr);
				WebStd.AppendXMLContent(elem, WebStd.CreateXMLText(oidStr));
				container.AddContent(elem)
			END;
			RETURN container
		END Externalize;

		PROCEDURE &Init*;
		BEGIN subEntries := NIL; superEntry := NIL (* subEntries is initialized to NIL for better performance if no hierarchy is used *)
		END Init;

		PROCEDURE GetReferrencedObjects*() : PrevalenceSystem.PersistentObjectList;
		VAR list: PrevalenceSystem.PersistentObjectList; count, pos: LONGINT;
		BEGIN
			count := 0;
			IF (subEntries # NIL) THEN INC(count) END;
			IF (superEntry # NIL) THEN INC(count) END;
			IF (count > 0) THEN
				NEW(list, count); pos := 0;
				IF (subEntries # NIL) THEN list[pos] := subEntries; INC(pos) END;
				IF (superEntry # NIL) THEN list[pos] := superEntry; INC(pos) END;
				RETURN list
			ELSE
				RETURN NIL
			END
		END GetReferrencedObjects;

		(** returns the table row view for the entry, forum could be NIL if not invoked by a WebForum *)
		PROCEDURE TableView*(forum: WebForum; request: HTTPSupport.HTTPRequest) : TableRow;
		BEGIN HALT(309)
		END TableView;

		(** detail view of the entry *)
		PROCEDURE DetailView*(forum: WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		BEGIN HALT(309);
		END DetailView;

		(** editing view of the entry, input fields without enclosing 'form' tag and submit/back button *)
		PROCEDURE EditView*(forum: WebForum; request: HTTPSupport.HTTPRequest) : XML.Content;
		BEGIN HALT(309);
		END EditView;

		PROCEDURE ToXML*(request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR container: XML.Container; td: XML.Element;
		BEGIN
			IF (superEntry = NIL) THEN
				NEW(container);
				NEW(td); td.SetName("td"); container.AddContent(td);
				RecursiveToXML(0, request, td, SELF);
				RETURN container
			ELSE
				RETURN NIL
			END
		END ToXML;

		PROCEDURE RecursiveToXML(depth: LONGINT; request: HTTPSupport.HTTPRequest;
			container: XML.Container; entry: WebForumEntry);
		VAR indent: Strings.String; row: TableRow; td, tr: XML.Element; i: SIZE; content: XML.Content;
			list: WebStd.PersistentDataObjectList; subEntry: WebForumEntry;
		BEGIN
			row := entry.TableView(NIL, request);
			IF (row # NIL) THEN
				NEW(tr); tr.SetName("tr");
				container.AddContent(tr);
				FOR i := 0 TO LEN(row)-1 DO
					IF ((row[i] # NIL) & (row[i].modus # WebForumEditViewCell) & (row[i].modus # WebForumDeleteCell)
					 & (row[i].modus # WebForumSubInsertViewCell)) THEN
						content := row[i].content;
						NEW(td); td.SetName("td");
						IF ((i = 0) & (depth > 0)) THEN (* insert indent *)
							NEW(indent, depth+1);
							FOR i := 0 TO depth DO
								indent[i] := "-";
							END; indent[depth] := 0X;
							WebStd.AppendXMLContent(td, WebStd.CreateXMLText(indent^))
						END;
						WebStd.AppendXMLContent(td, content);
						tr.AddContent(td)
					END
				END
			END;
			IF (entry.subEntries # NIL) THEN
				list := entry.subEntries.GetElementList(WebStd.DefaultPersistentDataFilter, NIL);
				IF (list # NIL) THEN
					FOR i := 0 TO LEN(list)-1 DO
						IF (list[i] IS WebForumEntry) THEN
							subEntry := list[i](WebForumEntry);
							RecursiveToXML(depth+1, request, container, subEntry)
						END
					END
				END
			END
		END RecursiveToXML;

	 END WebForumEntry;

	(** abstract generic web forum statefull active element with detail view and optional modification functionality if granted by authorization.
	 * If 'prevalenceSystem' is not specified then the standard prevalence system will be used.
	 * Omitting an access constraint means publishing the functionality to all users.
	 * The attribute 'reinitialize' optionally specifies whether the active element should be reinitialized, i.e. the overview state
	 * is activated, the list position is set back and the default ordering and filter functions are applied.
	 * usage example:
	 *  <WebComplex:WebForum id="MyForum3" containername="MyForum" prevalencesystem=".." reinitialize="true">
	 *    <Paging size="10" nextlabel="more.." previouslabel="..back"/>
	 *    <Searching label="Search for entries:" buttonname="Search!"/>
	 *    <AccessContraint>
	 *         <Edit><WebStd:AuthorizationCheck domain=".."/></Edit>
	 *         <Insert><WebStd:AuthorizationCheck domain=".."/></Insert>
	 *         <Delete><WebStd:AuthorizationCheck domain=".."/></Delete>
	 *    </AccessConstraint>
	 *  </WebComplex:WebForum>
	 *)
	WebForum* = OBJECT (DynamicWebpage.StateFullActiveElement);
		VAR
			allowEdit*, allowInsert*, allowDelete*: BOOLEAN; (** true iff access right is granted *)
			state: LONGINT; (* WebForumOverviewState, WebForumDetailViewState, WebForumEditViewState,
											WebForumInsertViewState *)
			pos: LONGINT; (* position of the overview table *)
			containerName: Strings.String;
			objectId: Strings.String; (* id of this statefull active element *)
			entryOid: LONGINT; (* oid of the web forum entry selected to view or modify *)
			statusContent: XML.Content; (* save temporary status message of a event handler to display later *)
			superEntryOid: LONGINT; (* oid of the hierachical parent web forum for which a subentry has to be inserted,
				0 if it has no super entry *)
			compareFunct: WebStd.PersistentDataCompare; (* active comparation function *)
			isOrderingApplied: BOOLEAN; (* true iff no default ordering is applied *)
			filterFunct: WebStd.PersistentDataFilter; (* active search filter *)
			isFilterApplied: BOOLEAN; (* true iff no default filter is applied *)
			prevSys: PrevalenceSystem.PrevalenceSystem;

		PROCEDURE &Init*;
		BEGIN
			ReInitialize
		END Init;

		PROCEDURE ReInitialize*;
		BEGIN
			state := WebForumOverviewState; pos := 0;
			allowEdit := FALSE; allowInsert := FALSE; allowDelete := FALSE;
			compareFunct := GetDefaultOrdering();
			filterFunct := GetDefaultSearchFilter();
			isOrderingApplied := FALSE; isFilterApplied := FALSE
		END ReInitialize;

		PROCEDURE RootEntryFilter(obj: WebStd.PersistentDataObject) : BOOLEAN;
		VAR entry: WebForumEntry;
		BEGIN
			IF (obj IS WebForumEntry) THEN
				entry := obj(WebForumEntry);
				IF (entry.superEntry = NIL) THEN
					RETURN TRUE
				END
			END;
			RETURN FALSE
		END RootEntryFilter;

		PROCEDURE Transform*(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR persCont: WebStd.PersistentDataContainer; prevSysName, reInitStr: Strings.String;
		BEGIN
			reInitStr := input.GetAttributeValue("reinitialize");
			IF ((reInitStr # NIL) & (reInitStr^ = "true")) THEN
				ReInitialize
			END;

			containerName := input.GetAttributeValue("containername");
			prevSysName := input.GetAttributeValue("prevalencesystem");
			objectId := input.GetAttributeValue(DynamicWebpage.XMLAttributeObjectIdName); (* objectId # NIL *)

			(* get the prevalence system *)
			IF (prevSysName # NIL) THEN
				prevSys := PrevalenceSystem.GetPrevalenceSystem(prevSysName^)
			ELSE
				prevSys := PrevalenceSystem.standardPrevalenceSystem
			END;

			(* determine the access rights *)
			allowEdit := IsAccessGranted(input, "Edit");
			allowInsert := IsAccessGranted(input, "Insert");
			allowDelete := IsAccessGranted(input, "Delete");

			IF ((containerName # NIL) & (prevSys # NIL)) THEN
				persCont := WebStd.GetPersistentDataContainer(prevSys, containerName^);
				IF (persCont # NIL) THEN
					IF (state = WebForumOverviewState) THEN
						RETURN GetMainOverview(persCont, input, request)
					ELSIF (state = WebForumDetailViewState) THEN
						RETURN GetMainDetailView(persCont, input, request)
					ELSIF (state = WebForumEditViewState) THEN
						RETURN GetMainEditView(persCont, input, request)
					ELSIF (state = WebForumInsertViewState) THEN
						RETURN GetMainInsertView(persCont, input, request)
					ELSE
						RETURN WebStd.CreateXMLText("WebComplex:WebForum: invalid state")
					END
				ELSE
					RETURN WebStd.CreateXMLText("WebComplex:WebForum: unable to create a persistent data container.")
				END
			ELSIF (containerName = NIL) THEN
				RETURN WebStd.CreateXMLText("Missing attribute 'containername' for a subclass of WebComplex:WebForum.")
			ELSE
				RETURN WebStd.CreateXMLText("The specified prevalence system for a subclass of WebComplex:WebForum is not present.")
			END
		END Transform;

		PROCEDURE GetMainOverview(persCont: WebStd.PersistentDataContainer; input: XML.Element;
				request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR table, tr, td, paging, eventButton, eventLink, eventParam, label, pTag, searching: XML.Element;
			content: XML.Content; pagingSizeStr, labelName, buttonLabelName, moduleName, objectName: Strings.String;
			pagingSize: LONGINT; index, listPos, columns, k, l: SIZE; persObjList: WebStd.PersistentDataObjectList;
			persObj: WebStd.PersistentDataObject; entryObj: WebForumEntry;  colString, posString, tableNoStr: ARRAY 14 OF CHAR;
			headerRow: HeaderRow; headerCell: HeaderCell; container: XML.Container;
		BEGIN (* persCont # NIL & objectId # NIL *)
			(* don't use datagrid for a heigher scalability, need not to materialize all entries for each datagrid view *)
			(* transform result pattern:
				<p>
					Search formular
				</p>
				<p>
					<WebStd:EventLink ..>
						<Label>insert a new entry label</Label>
					</WebStd:EventLink>
				</p>
				<table>
					<tr>GetTableHeader()</tr>
					entries
					<tr><td colspan=""><WebStd:EventButton label="back..." ../><WebStd:EventButton label="more.." ../></td></tr>
				</table>
			*)

			persObjList := persCont.GetElementList(RootEntryFilter, compareFunct);
			moduleName := ThisModuleName();
			objectName := ThisObjectName();

			NEW(container);

			WebStd.AppendXMLContent(container, GetHeaderXMLContent(persCont, input, request));

			AddStatusMessage(container);

			IF (allowInsert) THEN
				NEW(pTag); pTag.SetName("p");

				NEW(eventLink); eventLink.SetName("WebStd:EventLink");
				eventLink.SetAttributeValue("xmlns:WebStd", "WebStd");

				NEW(label); label.SetName("Label");
				labelName := GetInsertLinkLabel(request); (* labelName # NIL *)
				WebStd.AppendXMLContent(label, WebStd.CreateXMLText(labelName^));
				eventLink.AddContent(label);

				eventLink.SetAttributeValue("method", "SetInsertView");
				eventLink.SetAttributeValue("object", objectName^);
				eventLink.SetAttributeValue("module", moduleName^);
				eventLink.SetAttributeValue("objectid", objectId^);
				pTag.AddContent(eventLink);

				container.AddContent(pTag)
			END;

			(* moduleName # NIL & objectName # NIL *)
			index := 0;
			IF (persObjList # NIL) THEN
				NEW(pTag); pTag.SetName("p");
				container.AddContent(pTag);
				IF ((filterFunct = NIL) OR (~isFilterApplied)) THEN
					searching := WebStd.GetXMLSubElement(input, "Searching");
					IF (searching # NIL) THEN
						labelName := searching.GetAttributeValue("label");
						buttonLabelName := searching.GetAttributeValue("buttonname");
						WebStd.AppendXMLContent(pTag, GetSearchFormular(labelName, buttonLabelName));
					END
				ELSE
					NEW(eventLink); eventLink.SetName("WebStd:EventLink");
					eventLink.SetAttributeValue("xmlns:WebStd", "WebStd");

					NEW(label); label.SetName("Label");
					labelName := GetUnapplyFilterLabel(request); (* labelName # NIL *)
					WebStd.AppendXMLContent(label, WebStd.CreateXMLText(labelName^));
					eventLink.AddContent(label);

					eventLink.SetAttributeValue("method", "SetSearchFilter");
					eventLink.SetAttributeValue("object", objectName^);
					eventLink.SetAttributeValue("module", moduleName^);
					eventLink.SetAttributeValue("objectid", objectId^);
					pTag.AddContent(eventLink);
				END;
				IF (isOrderingApplied) THEN
					NEW(eventLink); eventLink.SetName("WebStd:EventLink");
					eventLink.SetAttributeValue("xmlns:WebStd", "WebStd");

					NEW(label); label.SetName("Label");
					labelName := GetUnapplySortLabel(request); (* labelName # NIL *)
					WebStd.AppendXMLContent(label, WebStd.CreateXMLText(labelName^));
					eventLink.AddContent(label);

					eventLink.SetAttributeValue("method", "SetOrdering");
					eventLink.SetAttributeValue("object", objectName^);
					eventLink.SetAttributeValue("module", moduleName^);
					eventLink.SetAttributeValue("objectid", objectId^);
					pTag.AddContent(eventLink);
				END;

				NEW(table); table.SetName("table");

				(* header row *)
				headerRow := GetTableHeader(request);
				IF (headerRow # NIL) THEN
					NEW(tr); tr.SetName("tr");
					FOR k := 0 TO LEN(headerRow)-1 DO
						headerCell := headerRow[k];
						IF (headerCell # NIL) THEN
							NEW(td); td.SetName("td");
							IF (headerCell.compareFunction # NIL) THEN
								Strings.IntToStr(k, tableNoStr);
								NEW(eventLink); eventLink.SetName("WebStd:EventLink");
								eventLink.SetAttributeValue("xmlns:WebStd", "WebStd");

								NEW(label); label.SetName("Label");
								WebStd.AppendXMLContent(label, headerCell.content);
								eventLink.AddContent(label);

								eventLink.SetAttributeValue("method", "SetOrdering");
								eventLink.SetAttributeValue("object", objectName^);
								eventLink.SetAttributeValue("module", moduleName^);
								eventLink.SetAttributeValue("objectid", objectId^);

								NEW(eventParam); eventParam.SetName("Param");
								eventParam.SetAttributeValue("name", "tableno");
								eventParam.SetAttributeValue("value", tableNoStr);
								eventLink.AddContent(eventParam);

								td.AddContent(eventLink)
							ELSE
								WebStd.AppendXMLContent(td, headerCell.content);
							END;
							tr.AddContent(td)
						END
					END;
					table.AddContent(tr)
				END;

				paging := WebStd.GetXMLSubElement(input, "Paging");
				IF (paging # NIL) THEN
					pagingSizeStr := paging.GetAttributeValue("size");
					IF (pagingSizeStr # NIL) THEN
						Strings.StrToInt(pagingSizeStr^, pagingSize)
					END
				ELSE
					pagingSize := MAX(LONGINT)
				END;

				(* data rows *)
				columns := 0;
				index := 0; listPos := 0;
				WHILE ((listPos < LEN(persObjList)) & (index < pos + pagingSize)) DO
					persObj := persObjList[listPos];
					IF ((filterFunct = NIL) OR (filterFunct(persObj))) THEN
						IF (index >= pos) THEN
							IF (persObj IS WebForumEntry) THEN
								entryObj := persObj(WebForumEntry);
								(* recursive view *)
								l := RecursiveEntryOverview(0, table, entryObj, request, moduleName, objectName);
								IF (l > columns) THEN columns := l END;
							ELSE
								(* incompatible container element *)
								NEW(td); td.SetName("td");
								WebStd.AppendXMLContent(td,  WebStd.CreateXMLText("Object is not of type WebForumEntry"));
								tr.AddContent(td);
								table.AddContent(tr)
							END;
						END;
						INC(index)
					END;
					INC(listPos)
				END;
				IF ((paging # NIL) & ((pos > 0) OR (listPos < LEN(persObjList)))) THEN (* previous or next button needed *)
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
						eventButton.SetAttributeValue("object", objectName^);
						eventButton.SetAttributeValue("module", moduleName^);
						eventButton.SetAttributeValue("objectid", objectId^);

						NEW(eventParam); eventParam.SetName("Param");
						eventParam.SetAttributeValue("name", "pos");
						eventParam.SetAttributeValue("value", posString);
						eventButton.AddContent(eventParam);
						td.AddContent(eventButton)
					ELSE
						WebStd.AppendXMLContent(td, WebStd.CreateXMLText(" "))
					END;
					NEW(td); td.SetName("td"); td.SetAttributeValue("colspan", colString);
					tr.AddContent(td);
					IF (listPos < LEN(persObjList)) THEN (* next button *)
						labelName := paging.GetAttributeValue("nextlabel");
						Strings.IntToStr(pos+pagingSize, posString);

						NEW(eventButton); eventButton.SetName("WebStd:EventButton");
						eventButton.SetAttributeValue("xmlns:WebStd", "WebStd");
						IF (labelName # NIL) THEN
							eventButton.SetAttributeValue("label", labelName^)
						ELSE
							eventButton.SetAttributeValue("label", "next")
						END;
						eventButton.SetAttributeValue("method", "SetPos");
						eventButton.SetAttributeValue("object", objectName^);
						eventButton.SetAttributeValue("module", moduleName^);
						eventButton.SetAttributeValue("objectid", objectId^);

						NEW(eventParam); eventParam.SetName("Param");
						eventParam.SetAttributeValue("name", "pos");
						eventParam.SetAttributeValue("value", posString);
						eventButton.AddContent(eventParam);
						td.AddContent(eventButton)
					ELSE
						WebStd.AppendXMLContent(td, WebStd.CreateXMLText(" "))
					END;
					table.AddContent(tr)
				END;
				IF (index > 0) THEN
					container.AddContent(table)
				(* ELSE the list is empty *)
				END
			END;
			IF (index = 0) THEN
				content := GetEmptyListMessage(request);
				WebStd.AppendXMLContent(container, content)
			END;
			RETURN container
		END GetMainOverview;

		(* displays 'entryObj' in table under depth 'depth' in the hierarchical view.
		 * returns the number of columns in the entry *)
		PROCEDURE RecursiveEntryOverview(depth: LONGINT; table: XML.Element; entryObj: WebForumEntry;
			request: HTTPSupport.HTTPRequest; moduleName, objectName: Strings.String) : SIZE;
		VAR row: TableRow; cell: TableCell; columns, k, l, i: SIZE; tr, td, eventLink, eventParam, label: XML.Element;
			oidString: ARRAY 14 OF CHAR; list: WebStd.PersistentDataObjectList; subEntry: WebForumEntry;
		BEGIN
			row := entryObj.TableView(SELF, request);
			columns := 0;
			IF (row # NIL) THEN
				columns := LEN(row);

				NEW(tr); tr.SetName("tr");
				FOR k := 0 TO LEN(row)-1 DO
					cell := row[k];
					IF (cell # NIL) THEN
					NEW(td); td.SetName("td");
					IF ((k = 0) & (depth > 0)) THEN (* insert indent *)
						WebStd.AppendXMLContent(td, GetIndent(depth, request))
					END;
					IF ((cell.modus = WebForumDetailViewCell) OR (allowEdit & (cell.modus = WebForumEditViewCell)) OR
						(allowDelete & (cell.modus = WebForumDeleteCell)) OR
						(allowInsert & (cell.modus = WebForumSubInsertViewCell))) THEN
						(* <WebStd:EventLink method=".." module=".." object=".." objectid="..">
						 *     <Label> cell.content </Label>
						 *     <Param name="oid" value=".."/>
						 * </WebStd:EventLink> *)
						Strings.IntToStr(entryObj.oid, oidString);

						NEW(eventLink); eventLink.SetName("WebStd:EventLink");
						eventLink.SetAttributeValue("xmlns:WebStd", "WebStd");

						NEW(label); label.SetName("Label");
						WebStd.AppendXMLContent(label, cell.content);
						eventLink.AddContent(label);

						IF (cell.modus = WebForumDetailViewCell) THEN
							eventLink.SetAttributeValue("method", "SetDetailView")
						ELSIF (cell.modus = WebForumEditViewCell) THEN
							eventLink.SetAttributeValue("method", "SetEditView")
						ELSIF (cell.modus = WebForumDeleteCell) THEN
							eventLink.SetAttributeValue("method", "DeleteEntry")
						ELSE (* cell.modus = WebForumSubInsertViewCell *)
							eventLink.SetAttributeValue("method", "SetInsertView");
						END;

						eventLink.SetAttributeValue("object", objectName^);
						eventLink.SetAttributeValue("module", moduleName^);
						eventLink.SetAttributeValue("objectid", objectId^);

						NEW(eventParam); eventParam.SetName("Param");
						eventParam.SetAttributeValue("name", "oid");
						eventParam.SetAttributeValue("value", oidString);
						eventLink.AddContent(eventParam);
						td.AddContent(eventLink)
					ELSIF (cell.modus = WebForumNormalCell) THEN
						WebStd.AppendXMLContent(td, cell.content);
					ELSE
						(* display empty cell *)
						WebStd.AppendXMLContent(td, WebStd.CreateXMLText(" "));
					END;
						tr.AddContent(td)
					END
				END;
				table.AddContent(tr)
			END;
			IF (entryObj.subEntries # NIL) THEN
				list := entryObj.subEntries.GetElementList(WebStd.DefaultPersistentDataFilter, compareFunct);
				IF (list # NIL) THEN
					FOR i := 0 TO LEN(list)-1 DO
						IF (list[i] IS WebForumEntry) THEN
							subEntry := list[i](WebForumEntry);
							l := RecursiveEntryOverview(depth+1, table, subEntry, request, moduleName, objectName);
							IF (l > columns) THEN columns := l END
						END
					END
				END
			END;
			RETURN columns
		END RecursiveEntryOverview;

		PROCEDURE GetSearchFormular(labelName, buttonName: Strings.String) : XML.Content;
		VAR table, tr, td, htmlInput, formular: XML.Element;
			moduleName, objectName: Strings.String;
		BEGIN
			moduleName := ThisModuleName();
			objectName := ThisObjectName();

			NEW(table); table.SetName("table");
			NEW(tr); tr.SetName("tr");
			table.AddContent(tr);
			NEW(td); td.SetName("td");
			tr.AddContent(td);
			IF (labelName # NIL) THEN
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText(labelName^))
			ELSE
				WebStd.AppendXMLContent(td, WebStd.CreateXMLText("Search: "))
			END;
			NEW(td); td.SetName("td");
			tr.AddContent(td);

			NEW(formular); formular.SetName("WebStd:Formular");
			formular.SetAttributeValue("xmlns:WebStd", "WebStd");
			formular.SetAttributeValue("method", "SetSearchFilter");
			formular.SetAttributeValue("object", objectName^);
			formular.SetAttributeValue("module", moduleName^);
			formular.SetAttributeValue("objectid", objectId^);

			NEW(htmlInput); htmlInput.SetName("input");
			htmlInput.SetAttributeValue("type", "text");
			htmlInput.SetAttributeValue("size", "40");
			htmlInput.SetAttributeValue("name", "text");
			formular.AddContent(htmlInput);

			NEW(htmlInput); htmlInput.SetName("input");
			htmlInput.SetAttributeValue("type", "submit");
			htmlInput.SetAttributeValue("name", "searchsubmit");
			IF (buttonName # NIL) THEN
				htmlInput.SetAttributeValue("value", buttonName^)
			ELSE
				htmlInput.SetAttributeValue("value", "Go")
			END;
			formular.AddContent(htmlInput);

			td.AddContent(formular);

			RETURN table
		END GetSearchFormular;

		PROCEDURE AddStatusMessage(container: XML.Container);
		BEGIN
			IF (statusContent # NIL) THEN
				WebStd.AppendXMLContent(container, statusContent);
				statusContent := NIL (* set status back *)
			END;
		END AddStatusMessage;

		PROCEDURE GetMainDetailView(persCont: WebStd.PersistentDataContainer; input: XML.Element;
				request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR persObj: WebStd.PersistentDataObject; container: XML.Container; list: WebStd.PersistentDataObjectList;
			moduleName, objectName: Strings.String; entryObj, subEntry: WebForumEntry; content: XML.Content;
			eventButton, table, tr, td: XML.Element; l, i: SIZE; row: HeaderRow; cell: HeaderCell;
		BEGIN (* persCont # NIL & objectId # NIL *)
			persObj := persCont.GetObjectByOid(entryOid);
			moduleName := ThisModuleName();
			objectName := ThisObjectName();

			NEW(container);
			IF ((persObj # NIL) & (persObj IS WebForumEntry)) THEN
				entryObj := persObj(WebForumEntry);
				content := entryObj.DetailView(SELF, request);
				WebStd.AppendXMLContent(container, content);

				(* insert subentries *)
				IF (entryObj.subEntries # NIL) THEN
				list := entryObj.subEntries.GetElementList(WebStd.DefaultPersistentDataFilter, compareFunct);
					IF (list # NIL) THEN
						NEW(table); table.SetName("table");
						row := GetTableHeader(request);
						IF (row # NIL) THEN
							NEW(tr); tr.SetName("tr");
							FOR i := 0 TO LEN(row)-1 DO
								cell := row[i];
								IF (cell # NIL) THEN
									NEW(td); td.SetName("td");
									WebStd.AppendXMLContent(td, cell.content);
									tr.AddContent(td)
								END
							END;
							table.AddContent(tr)
						END;
						FOR i := 0 TO LEN(list)-1 DO
							IF (list[i] IS WebForumEntry) THEN
								subEntry := list[i](WebForumEntry);
								l := RecursiveEntryOverview(1, table, subEntry, request, moduleName, objectName);
							END
						END;
						container.AddContent(table)
					END
				END;

				(* insert back button *)
				eventButton := GetBackButton(input, request);
				container.AddContent(eventButton)
			ELSE
				WebStd.AppendXMLContent(container, WebStd.CreateXMLText("object is not present"));
			END;
			RETURN container
		END GetMainDetailView;

		PROCEDURE GetMainEditView(persCont: WebStd.PersistentDataContainer; input: XML.Element;
				request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR persObj: WebStd.PersistentDataObject; container: XML.Container; entryObj: WebForumEntry;
			content: XML.Content; eventButton, submitButton, formular, htmlInput: XML.Element;
			moduleName, objectName: Strings.String; oidString: ARRAY 14 OF CHAR;
		BEGIN (* persCont # NIL & objectId # NIL *)
			moduleName := ThisModuleName();
			objectName := ThisObjectName();
			persObj := persCont.GetObjectByOid(entryOid);

			NEW(container);
			AddStatusMessage(container);

			IF (allowEdit) THEN
				IF ((persObj # NIL) & (persObj IS WebForumEntry)) THEN
					entryObj := persObj(WebForumEntry);
					Strings.IntToStr(entryObj.oid, oidString);

					NEW(formular); formular.SetName("WebStd:Formular");
					formular.SetAttributeValue("xmlns:WebStd", "WebStd");
					formular.SetAttributeValue("method", "UpdateEditEntry");
					formular.SetAttributeValue("object", objectName^);
					formular.SetAttributeValue("module", moduleName^);
					formular.SetAttributeValue("objectid", objectId^);

					NEW(htmlInput); htmlInput.SetName("input");
					htmlInput.SetAttributeValue("type", "hidden");
					htmlInput.SetAttributeValue("name", "oid");
					htmlInput.SetAttributeValue("value", oidString);
					formular.AddContent(htmlInput);

					content := entryObj.EditView(SELF, request);
					WebStd.AppendXMLContent(formular, content);

					submitButton := GetSubmitButton(request);
					formular.AddContent(submitButton);

					eventButton := GetInputBackButton(request);
					formular.AddContent(eventButton);

					container.AddContent(formular)
				ELSE
					WebStd.AppendXMLContent(container, WebStd.CreateXMLText("object is not present"))
				END
			ELSE
				WebStd.AppendXMLContent(container, WebStd.CreateXMLText("Access forbidden."))
			END;
			RETURN container
		END GetMainEditView;

		PROCEDURE GetMainInsertView(persCont: WebStd.PersistentDataContainer; input: XML.Element;
				request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR container: XML.Container; content: XML.Content; eventButton, submitButton, formular : XML.Element;
			moduleName, objectName: Strings.String; superEntry: WebForumEntry; persObj: WebStd.PersistentDataObject;
		BEGIN (* persCont # NIL & objectId # NIL *)
			moduleName := ThisModuleName();
			objectName := ThisObjectName();

			NEW(container);
			AddStatusMessage(container);

			IF (allowInsert) THEN
				superEntry := NIL;
				IF (superEntryOid # 0) THEN
					persObj := persCont.GetObjectByOid(superEntryOid);
					IF ((persObj # NIL) & (persObj IS WebForumEntry)) THEN
						superEntry := persObj(WebForumEntry)
					END
				END;

				NEW(formular); formular.SetName("WebStd:Formular");
				formular.SetAttributeValue("xmlns:WebStd", "WebStd");
				formular.SetAttributeValue("method", "InsertEditEntry");
				formular.SetAttributeValue("object", objectName^);
				formular.SetAttributeValue("module", moduleName^);
				formular.SetAttributeValue("objectid", objectId^);

				content := GetInsertView(superEntry, request);
				WebStd.AppendXMLContent(formular, content);

				submitButton := GetSubmitButton(request);
				formular.AddContent(submitButton);

				eventButton := GetInputBackButton(request);
				formular.AddContent(eventButton);

				container.AddContent(formular)
			ELSE
				WebStd.AppendXMLContent(container, WebStd.CreateXMLText("Access forbidden."))
			END;
			RETURN container
		END GetMainInsertView;

		(* true iff access granted for type "Edit", "Delete" or "Insert" *)
		PROCEDURE IsAccessGranted(input: XML.Element; type: ARRAY OF CHAR) : BOOLEAN;
		VAR granted: BOOLEAN; accessConstraint, typeElem, grantedElem: XML.Element;
		BEGIN
			granted := TRUE;
			accessConstraint := WebStd.GetXMLSubElement(input, "AccessConstraint");
			IF (accessConstraint # NIL) THEN
				typeElem := WebStd.GetXMLSubElement(accessConstraint, type);
				IF (typeElem # NIL) THEN
					grantedElem := WebStd.GetXMLSubElement(typeElem, "Granted");
					IF (grantedElem # NIL) THEN
						granted := TRUE
					ELSE
						granted := FALSE
					END
				END
			END;
			RETURN granted
		END IsAccessGranted;

		PROCEDURE GetBackButton(input: XML.Element; request: HTTPSupport.HTTPRequest) : XML.Element;
		VAR eventButton: XML.Element; labelName: Strings.String;
			moduleName, objectName: Strings.String;
		BEGIN
			moduleName := ThisModuleName();
			objectName := ThisObjectName();
			labelName := GetBackButtonLabel(request); (* labelName # NIL *)
			NEW(eventButton); eventButton.SetName("WebStd:EventButton");
			eventButton.SetAttributeValue("xmlns:WebStd", "WebStd");
			eventButton.SetAttributeValue("label", labelName^);
			eventButton.SetAttributeValue("method", "SetOverview");
			eventButton.SetAttributeValue("object", objectName^);
			eventButton.SetAttributeValue("module", moduleName^);
			eventButton.SetAttributeValue("objectid", objectId^);
			RETURN eventButton
		END GetBackButton;

		PROCEDURE GetInputBackButton(request: HTTPSupport.HTTPRequest) : XML.Element;
		VAR input: XML.Element; labelName: Strings.String;
		BEGIN
			labelName := GetBackButtonLabel(request); (* labelName # NIL *)
			NEW(input); input.SetName("input");
			input.SetAttributeValue("type", "submit");
			input.SetAttributeValue("name", "backbutton");
			input.SetAttributeValue("value", labelName^);
			RETURN input
		END GetInputBackButton;

		PROCEDURE GetSubmitButton(request: HTTPSupport.HTTPRequest) : XML.Element;
		VAR input: XML.Element; labelName: Strings.String;
		BEGIN
			labelName := GetSubmitButtonLabel(request); (* labelName # NIL *)
			NEW(input); input.SetName("input");
			input.SetAttributeValue("type", "submit");
			input.SetAttributeValue("name", "submitbutton");
			input.SetAttributeValue("value", labelName^);
			RETURN input
		END GetSubmitButton;

		PROCEDURE SetPos(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
			(* parameters: "pos" *)
		VAR posString: Strings.String;
		BEGIN
			state := WebForumOverviewState; (* user could have pushed the back button in the browsers navigation bar *)
			posString := params.GetParameterValueByName("pos");
			IF (posString # NIL) THEN
				Strings.StrToInt(posString^, pos);
				OnPositionChanged(pos, request)
			ELSE
				KernelLog.String("WebComplex:WebForum - event handler 'SetPos' has parameter 'pos'.");
				KernelLog.Ln
			END
		END SetPos;

		PROCEDURE SetDetailView(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
			(* parameters: "oid" *)
		VAR oidString: Strings.String;
		BEGIN
			oidString := params.GetParameterValueByName("oid");
			IF (oidString # NIL) THEN
				state := WebForumDetailViewState;
				Strings.StrToInt(oidString^, entryOid);
				OnDetailViewActivated(entryOid, request);
			ELSE
				KernelLog.String("WebComplex:WebForum - event handler 'SetDetailView' has parameter 'oid'.");
				KernelLog.Ln
			END
		END SetDetailView;

		PROCEDURE SetInsertView(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		 (* params can have parameter 'oid' with oid of the superentry in case that a subentry insertion view is needed *)
		VAR parentStr: Strings.String;
		BEGIN
			IF (allowInsert) THEN
				parentStr := params.GetParameterValueByName("oid");
				IF (parentStr # NIL) THEN
					Strings.StrToInt(parentStr^, superEntryOid);
					OnInsertViewActivated(superEntryOid, request)
				ELSE
					superEntryOid := 0
				END;
				state := WebForumInsertViewState
			END
		END SetInsertView;

		PROCEDURE SetEditView(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
			(* parameters: "oid" *)
		VAR oidString: Strings.String;
		BEGIN
			oidString := params.GetParameterValueByName("oid");
			IF (allowEdit & (oidString # NIL)) THEN
				state := WebForumEditViewState;
				Strings.StrToInt(oidString^, entryOid);
				OnEditViewActivated(entryOid, request)
			ELSIF (oidString # NIL) THEN
				KernelLog.String("WebComplex:WebForum - event handler 'SetEditView' has parameter 'oid'.");
				KernelLog.Ln
			END
		END SetEditView;

		PROCEDURE SetOrdering(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
			(* parameters: ["tableno"] *)
		VAR tableNoString: Strings.String; tableNo: LONGINT; headerRow: HeaderRow;
		BEGIN
			state := WebForumOverviewState; (* user could have pushed the back button in the browsers navigation bar *)
			tableNoString := params.GetParameterValueByName("tableno");
			IF (tableNoString # NIL) THEN
				Strings.StrToInt(tableNoString^, tableNo);
				headerRow := GetTableHeader(request);
				IF ((headerRow # NIL) & (tableNo >= 0) & (tableNo < LEN(headerRow))) THEN
					compareFunct := headerRow[tableNo].compareFunction;
					isOrderingApplied := TRUE; pos := 0
				END
			ELSE
				compareFunct := GetDefaultOrdering(); isOrderingApplied := FALSE; pos := 0
			END
		END SetOrdering;

		PROCEDURE SetSearchFilter(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
			(* parameters: ["text"] *)
		VAR text: Strings.String;
		BEGIN
			state := WebForumOverviewState; (* user could have pushed the back button in the browsers navigation bar *)
			text := params.GetParameterValueByName("text");
			IF (text # NIL) THEN
				filterFunct := GetSearchFilter(text);
				isFilterApplied := TRUE
			ELSE
				filterFunct := GetDefaultSearchFilter();
				isFilterApplied := FALSE
			END;
			pos := 0
		END SetSearchFilter;

		PROCEDURE DeleteEntry(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
			(* parameters: "oid" *)
		VAR oidString: Strings.String; oid: LONGINT; persObj: WebStd.PersistentDataObject;
			persCont: WebStd.PersistentDataContainer; entry: WebForumEntry;
		BEGIN
			state := WebForumOverviewState; (* user could have pushed the back button in the browsers navigation bar *)
			oidString := params.GetParameterValueByName("oid");
			IF (allowDelete & (oidString # NIL)) THEN
				Strings.StrToInt(oidString^, oid);
				IF (containerName # NIL) THEN
					persCont := WebStd.GetPersistentDataContainer(prevSys, containerName^);
					IF (persCont # NIL) THEN
						persObj := persCont.GetObjectByOid(oid);
						IF ((persObj # NIL) & (persObj IS WebForumEntry)) THEN
							entry := persObj(WebForumEntry);
							OnDelete(entry, request);
							(* Delete entry and all its descandants in the hierarchy *)
							IF (entry.superEntry # NIL) THEN
								IF (entry.superEntry.subEntries # NIL) THEN
									entry.superEntry.subEntries.RemovePersistentDataObject(entry)
								END
							END;
							DeleteRecursiveEntry(persCont, entry)
						ELSE
							statusContent := WebStd.CreateXMLText("object is not present");
						END
					ELSE
						statusContent := WebStd.CreateXMLText("container is not present");
					END
				(* ELSE containername attribute missing for WebComplex:WebForum *)
				END
			ELSE
				KernelLog.String("WebComplex:WebForum - event handler 'DeleteEntry' has parameter 'oid'.");
				KernelLog.Ln
			END
		END DeleteEntry;

		PROCEDURE DeleteRecursiveEntry(persCont: WebStd.PersistentDataContainer; entry: WebForumEntry);
		VAR list: WebStd.PersistentDataObjectList; i: SIZE; subEntry: WebForumEntry;
		BEGIN (* persCont # NIL & entry # NIL *)
			persCont.RemovePersistentDataObject(entry);
			(* object will be freed by garbage collecting mechanism of the prevalence system *)
			IF (entry.subEntries # NIL) THEN
				list := entry.subEntries.GetElementList(WebStd.DefaultPersistentDataFilter, NIL);
				IF (list # NIL) THEN
					FOR i := 0 TO LEN(list)-1 DO
						IF (list[i] IS WebForumEntry) THEN
							subEntry := list[i](WebForumEntry);
							DeleteRecursiveEntry(persCont, subEntry)
						END
					END
				END;
				entry.BeginModification;
				entry.subEntries := NIL;
				entry.EndModification
			END
		END DeleteRecursiveEntry;

		PROCEDURE SetOverview(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
			(* parameters: none *)
		BEGIN
			state := WebForumOverviewState;
			OnSetOverview(request)
		END SetOverview;

		PROCEDURE UpdateEditEntry(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
			(* parameters: "oid" et alia *)
		VAR oid: LONGINT; oidString, buttonName: Strings.String; persObj: WebStd.PersistentDataObject;
			obj: WebForumEntry; persCont: WebStd.PersistentDataContainer;
		BEGIN
			buttonName := params.GetParameterValueByName("backbutton");
			IF (buttonName # NIL) THEN
				SetOverview(request, params)
			ELSE
				oidString := params.GetParameterValueByName("oid");
				IF (allowEdit & (oidString # NIL)) THEN
					Strings.StrToInt(oidString^, oid);
					IF (containerName # NIL) THEN
						persCont := WebStd.GetPersistentDataContainer(prevSys, containerName^);
						IF (persCont # NIL) THEN
							persObj := persCont.GetObjectByOid(oid);
							IF ((persObj # NIL) & (persObj IS WebForumEntry)) THEN
								obj := persObj(WebForumEntry);
								IF (UpdateObject(obj, request, params, statusContent)) THEN
									state := WebForumOverviewState
								(* ELSE stay in WebForumEditState and statusContent is set *)
								END
							ELSE
								statusContent := WebStd.CreateXMLText("object is not present");
								state := WebForumOverviewState
							END
						(* ELSE containername attribute missing for WebComplex:WebForum *)
						END
					ELSE
						statusContent := WebStd.CreateXMLText("container is not present");
						state := WebForumOverviewState
					END
				ELSIF (oidString # NIL) THEN
					KernelLog.String("WebComplex:WebForum - event handler 'UpdateEditEntry' has parameter 'oid'.");
					KernelLog.Ln;
					state := WebForumOverviewState
				END
			END
		END UpdateEditEntry;

		PROCEDURE InsertEditEntry(request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList);
		(* parameters: alia and optionaly "superentryoid"*)
		VAR persCont: WebStd.PersistentDataContainer; buttonName: Strings.String;
			persObj: WebStd.PersistentDataObject; superEntry: WebForumEntry;
		BEGIN
			buttonName := params.GetParameterValueByName("backbutton");
			IF (buttonName # NIL) THEN
				SetOverview(request, params)
			ELSE
				IF (allowInsert) THEN
					IF (containerName # NIL) THEN
						persCont := WebStd.GetPersistentDataContainer(prevSys, containerName^);
						IF (persCont # NIL) THEN
							superEntry := NIL;
							IF (superEntryOid > 0) THEN
								persObj := persCont.GetObjectByOid(superEntryOid);
								IF ((persObj # NIL) & (persObj IS WebForumEntry)) THEN
									superEntry := persObj(WebForumEntry)
								END
							END;

							IF (InsertObject(persCont, superEntry, request, params, statusContent)) THEN
								state := WebForumOverviewState
							(* ELSE stay in WebForumInsertState and statusContent is set *)
							END;
						(* ELSE containername attribute missing for WebComplex:WebForum *)
						END
					ELSE
						statusContent := WebStd.CreateXMLText("container is not present");
						state := WebForumOverviewState
					END;
				ELSE
					state := WebForumOverviewState
				END
			END
		END InsertEditEntry;

		PROCEDURE GetEventHandlers*() : DynamicWebpage.EventHandlerList;
		VAR list, addList: DynamicWebpage.EventHandlerList; listLength, addListCount, i: SIZE
		BEGIN
			addList := GetAdditionalEventHandlers();
			IF (addList # NIL) THEN
				addListCount := LEN(addList)
			ELSE
				addListCount := 0
			END;

			listLength := 10;
			NEW(list, listLength+ addListCount);

			NEW(list[0], "SetPos", SetPos);
			NEW(list[1], "SetDetailView", SetDetailView);
			NEW(list[2], "SetEditView", SetEditView);
			NEW(list[3], "DeleteEntry", DeleteEntry);
			NEW(list[4], "SetOverview", SetOverview);
			NEW(list[5], "UpdateEditEntry", UpdateEditEntry);
			NEW(list[6], "SetInsertView", SetInsertView);
			NEW(list[7], "InsertEditEntry", InsertEditEntry);
			NEW(list[8], "SetOrdering", SetOrdering);
			NEW(list[9], "SetSearchFilter", SetSearchFilter);
			IF (addList # NIL) THEN
				FOR i := 0 TO LEN(addList)-1 DO
					list[listLength+i] := addList[i]
				END
			END;
			RETURN list
		END GetEventHandlers;

		(** override, get additional handler list *)
		PROCEDURE GetAdditionalEventHandlers*() : DynamicWebpage.EventHandlerList;
		BEGIN RETURN NIL
		END GetAdditionalEventHandlers;

		(** override, additional header xml content *)
		PROCEDURE GetHeaderXMLContent*(container: WebStd.PersistentDataContainer; input: XML.Element;
			request: HTTPSupport.HTTPRequest) : XML.Content;
		BEGIN RETURN NIL
		END GetHeaderXMLContent;

		(** abstract InsertObject is used to create and initialize a new web forum and insert to 'container'.
		 * 'superEntry' is the parent web forum entry in the hierarchy, 'superEntry' is NIL if it has no parent.
		 * Access rights have already been granted. (obj # NIL)
		 * return true iff object has successfully been inserted, otherwise false and
		 * use statusMsg parameter to write an status message
		 *)
		PROCEDURE InsertObject*(container: WebStd.PersistentDataContainer; superEntry: WebForumEntry;
			request: HTTPSupport.HTTPRequest; params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
		BEGIN HALT (309)
		END InsertObject;

		(** abstract UpdateObject is used to set the values of a existing web forum entry 'obj'.
		 * Access rights have already been granted. (obj # NIL)
		 * return true iff object has successfully been updated, otherwise false and
		 * use statusMsg parameter to write an status message. *)
		PROCEDURE UpdateObject*(obj: WebForumEntry; request: HTTPSupport.HTTPRequest;
			params: DynamicWebpage.ParameterList; VAR statusMsg: XML.Content) : BOOLEAN;
		BEGIN HALT (309)
		END UpdateObject;

		(** override, supplemental tasks if the position is changed to 'pos' *)
		PROCEDURE OnPositionChanged*(pos: LONGINT; request: HTTPSupport.HTTPRequest);
		(* do nothing *)
		END OnPositionChanged;

		(** override, supplemental tasks if the insert view for an object with super entry with oid 'superENtryOid' is activated *)
		PROCEDURE OnInsertViewActivated*(superEntryOid: LONGINT; request: HTTPSupport.HTTPRequest);
		(* do nothing *)
		END OnInsertViewActivated;

		(** override, supplemental tasks if the edit view of object with oid 'entryOid' is activated *)
		PROCEDURE OnEditViewActivated*(entryOid: LONGINT; request: HTTPSupport.HTTPRequest);
		(* do nothing *)
		END OnEditViewActivated;

		(** override, supplemental tasks if the overview state is set *)
		PROCEDURE OnSetOverview*(request: HTTPSupport.HTTPRequest);
		(* do nothing *)
		END OnSetOverview;

		(** override, supplemental tasks if the detail view of object with oid 'entryOid' is activated *)
		PROCEDURE OnDetailViewActivated*(entryOid: LONGINT; request: HTTPSupport.HTTPRequest);
		(* do nothing *)
		END OnDetailViewActivated;

		(** override, supplemental tasks before an object 'obj' and its subentries will be deleted *)
		PROCEDURE OnDelete*(obj: WebForumEntry; request: HTTPSupport.HTTPRequest);
		(* do nothing *)
		END OnDelete;

		(** abstract, returns the object name # NIL *)
		PROCEDURE ThisObjectName*() : Strings.String;
		BEGIN HALT(309)
		END ThisObjectName;

		(** abstract, returns the module name # NIL *)
		PROCEDURE ThisModuleName*() : Strings.String;
		BEGIN HALT(309)
		END ThisModuleName;

		(** abstract, returns the insert view for the initialization of a new web forum entry, without submit/back-input fields
		 * superEntry is the parent web forum entry in a hierachical web forum, superEntry is NIL iff it is a root entry *)
		PROCEDURE GetInsertView*(superEntry: WebForumEntry; request: HTTPSupport.HTTPRequest): XML.Content;
		BEGIN HALT(309)
		END GetInsertView;

		(** override, returns the header for the overview table, could be NIL if no header row is desired *)
		PROCEDURE GetTableHeader*(request: HTTPSupport.HTTPRequest): HeaderRow;
		BEGIN RETURN NIL
		END GetTableHeader;

		(** override, returns the indent for subentries of depth 'depth' in the recusrive table view *)
		PROCEDURE GetIndent*(depth: LONGINT; request: HTTPSupport.HTTPRequest) : XML.Content;
		VAR container: XML.Container; ch: ARRAY 5 OF CHAR; nbsp: XML.EntityRef; i: LONGINT;
		BEGIN
			IF (depth > 0) THEN
				NEW(container);
				FOR i := 0 TO 2*(depth-1) DO
					NEW(nbsp); COPY("nbsp", ch); nbsp.SetName(ch);
					container.AddContent(nbsp);
				END;
				WebStd.AppendXMLContent(container, WebStd.CreateXMLText("-> "));
				RETURN container
			END;
			RETURN NIL
		END GetIndent;

		(** override, get the default ordering of the table view *)
		PROCEDURE GetDefaultOrdering*() : WebStd.PersistentDataCompare;
		BEGIN RETURN NIL
		END GetDefaultOrdering;

		(** override, get the default search filter of the table view *)
		PROCEDURE GetDefaultSearchFilter*() : WebStd.PersistentDataFilter;
		BEGIN RETURN NIL
		END GetDefaultSearchFilter;

		(** override, return the the data filter for the search text, NIL means there is no search filter defined *)
		PROCEDURE GetSearchFilter*(text: Strings.String) : WebStd.PersistentDataFilter;
		BEGIN RETURN NIL
		END GetSearchFilter;

		(** override, returns the xml message if there are no entries in the web forum # NIL *)
		PROCEDURE GetEmptyListMessage*(request: HTTPSupport.HTTPRequest) : XML.Container;
		BEGIN
			RETURN WebStd.CreateXMLText(WebForumStandardEmptyList);
		END GetEmptyListMessage;

		(** override, returns back to overview button label # NIL *)
		PROCEDURE GetBackButtonLabel*(request: HTTPSupport.HTTPRequest) : Strings.String;
		BEGIN RETURN WebStd.GetString(WebForumStandardBackLabel)
		END GetBackButtonLabel;

		(** override, returns label text for insert entry link # NIL *)
		PROCEDURE GetInsertLinkLabel*(request: HTTPSupport.HTTPRequest) : Strings.String;
		BEGIN RETURN WebStd.GetString(WebForumStandardInsertText)
		END GetInsertLinkLabel;

		(** override, returns label for submit button for edit and insert # NIL *)
		PROCEDURE GetSubmitButtonLabel*(request: HTTPSupport.HTTPRequest): Strings.String;
		BEGIN RETURN WebStd.GetString(WebForumStandardSubmitLabel)
		END GetSubmitButtonLabel;

		(** override, returns label for unapplying the sorting # NIL *)
		PROCEDURE GetUnapplySortLabel*(request: HTTPSupport.HTTPRequest): Strings.String;
		BEGIN RETURN WebStd.GetString(WebForumStdUnapplySortLabel)
		END GetUnapplySortLabel;

		(** override, returns label for unapllying search filter # NIL *)
		PROCEDURE GetUnapplyFilterLabel*(request: HTTPSupport.HTTPRequest): Strings.String;
		BEGIN RETURN WebStd.GetString(WebForumStdUnapplyFilterLabel)
		END GetUnapplyFilterLabel;
	END WebForum;

	(** usefull standard procedures for webforums *)

	(** create a table cell for string 'str' and 'modus'. 'str' could be NIL *)
	PROCEDURE GetTableCell*(str: Strings.String; modus: LONGINT) : TableCell;
	VAR cell: TableCell; xmlText: XML.Container;
	BEGIN
		IF (str # NIL) THEN
			xmlText := WebStd.CreateXMLText(str^)
		ELSE
			xmlText := WebStd.CreateXMLText(" ")
		END;
		NEW(cell, xmlText, modus);
		RETURN cell
	END GetTableCell;

	(** create a table cell activated for email to 'str' and having 'modus' as mode. 'str' could be NIL *)
	PROCEDURE GetEmailTableCell*(str: Strings.String; modus: LONGINT) : TableCell;
	VAR cell: TableCell; xmlText: XML.Container;
	BEGIN
		IF (str # NIL) THEN
			NEW(cell, GetMailtoElement(str^), modus)
		ELSE
			xmlText := WebStd.CreateXMLText(" ");
			NEW(cell, xmlText, modus)
		END;
		RETURN cell
	END GetEmailTableCell;

	(** create a table cell for 'text' and 'modus' *)
	PROCEDURE GetTableCellForText*(text: ARRAY OF CHAR; modus: LONGINT) : TableCell;
	VAR cell: TableCell; xmlText: XML.Container;
	BEGIN
		xmlText := WebStd.CreateXMLText(text);
		NEW(cell, xmlText, modus);
		RETURN cell
	END GetTableCellForText;

	(** create a table header cell for 'text' and compare function 'compareFunct' *)
	PROCEDURE GetHeaderCellForText*(text: ARRAY OF CHAR; compareFunct: WebStd.PersistentDataCompare) : HeaderCell;
	VAR cell: HeaderCell; xmlText: XML.Container;
	BEGIN
		xmlText := WebStd.CreateXMLText(text);
		NEW(cell, xmlText, compareFunct);
		RETURN cell
	END GetHeaderCellForText;

	(** return a email XHTML element for the mail adress 'mailAdr'. returns NIL if 'mailAdr = "" *)
	PROCEDURE GetMailtoElement*(mailAdr: ARRAY OF CHAR) : XML.Element;
	VAR mailtoStr: Strings.String; a: XML.Element;
	BEGIN
		IF (mailAdr # "") THEN
			NEW(mailtoStr, Strings.Length(mailAdr)+10);
			Strings.Concat("mailto:", mailAdr, mailtoStr^);
			NEW(a); a.SetName("a");
			a.SetAttributeValue("href", mailtoStr^);
			WebStd.AppendXMLContent(a, WebStd.CreateXMLText(mailAdr));
			RETURN a
		ELSE
			RETURN NIL
		END
	END GetMailtoElement;

	(** append standard detail view XHTML code for a string 'str'. 'str' could be NIL *)
	PROCEDURE AddStandardDetailView*(container: XML.Container; name: ARRAY OF CHAR; str: Strings.String);
	VAR pTag: XML.Element;
	BEGIN
		NEW(pTag); pTag.SetName("p");
		WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(name));
		IF (str # NIL) THEN
			WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(str^))
		END;
		container.AddContent(pTag)
	END AddStandardDetailView;

	(** append a text with multiple lines view XHTML code for a string 'str'. 'str' could be NIL *)
	PROCEDURE AddMultipleLinesDetailView*(container: XML.Container; name: ARRAY OF CHAR; str: Strings.String);
	VAR pTag: XML.Element;
	BEGIN
		NEW(pTag); pTag.SetName("p");
		WebStd.AppendXMLContent(pTag, WebStd.CreateXMLText(name));
		IF (str # NIL) THEN
			WebStd.AppendXMLContent(pTag, WebStd.CreateXMLTextWithBR(str^))
		END;
		container.AddContent(pTag);
	END AddMultipleLinesDetailView;

	(** append standard input row view in XHTML code to 'table'  with a label 'label' and a parameter name 'paramName'
	 * 'str' is the initial value.'str' could be NIL *)
	PROCEDURE AddTextFieldInputRow*(table: XML.Container; label, paramName: ARRAY OF CHAR;
		str: Strings.String);
	VAR tr, td, input: XML.Element; encText: Strings.String;
	BEGIN
		NEW(tr); tr.SetName("tr"); table.AddContent(tr);
		NEW(td); td.SetName("td"); tr.AddContent(td);
		WebStd.AppendXMLContent(td, WebStd.CreateXMLText(label));
		NEW(td); td.SetName("td"); tr.AddContent(td);
		NEW(input); input.SetName("input");
		input.SetAttributeValue("type", "text");
		input.SetAttributeValue("size", "40");
		input.SetAttributeValue("name", paramName);
		IF (str # NIL) THEN
			encText := WebStd.GetEncXMLAttributeText(str^);
			input.SetAttributeValue("value", encText^)
		END;
		td.AddContent(input)
	END AddTextFieldInputRow;

	(** append password input row view in XHTML code to 'table' with a label 'label' and a parameter name 'paramName' *)
	PROCEDURE AddPasswordFieldInputRow*(table: XML.Container; label, paramName: ARRAY OF CHAR);
	VAR tr, td, input: XML.Element;
	BEGIN
		NEW(tr); tr.SetName("tr"); table.AddContent(tr);
		NEW(td); td.SetName("td"); tr.AddContent(td);
		WebStd.AppendXMLContent(td, WebStd.CreateXMLText(label));
		NEW(td); td.SetName("td"); tr.AddContent(td);
		NEW(input); input.SetName("input");
		input.SetAttributeValue("type", "password");
		input.SetAttributeValue("size", "40");
		input.SetAttributeValue("name", paramName);
		td.AddContent(input)
	END AddPasswordFieldInputRow;

	(** append textarea input row in XHTML code to 'table' with a label 'label' and a parameter name 'paramName'
	 * 'str' is the initial value.'str' could be NIL *)
	PROCEDURE AddTextAreaInputRow*(table: XML.Container; label, paramName: ARRAY OF CHAR;
		str: Strings.String);
	VAR tr, td, textarea: XML.Element;
	BEGIN
		NEW(tr); tr.SetName("tr"); table.AddContent(tr);
		NEW(td); td.SetName("td"); tr.AddContent(td);
		WebStd.AppendXMLContent(td, WebStd.CreateXMLText(label));
		NEW(td); td.SetName("td"); tr.AddContent(td);
		NEW(textarea); textarea.SetName("textarea");
		textarea.SetAttributeValue("rows", "4");
		textarea.SetAttributeValue("cols", "40");
		textarea.SetAttributeValue("name", paramName);
		IF ((str # NIL) & (str^  # "")) THEN
			WebStd.AppendXMLContent(textarea, WebStd.CreateXMLText(str^))
		ELSE (* must insert &nbsp; to ensure that no empty textarea-tag is displyed *)
			WebStd.AppendXMLContent(textarea, WebStd.CreateXMLText(" "))
		END;
		td.AddContent(textarea);
	END AddTextAreaInputRow;
END WebComplex.
