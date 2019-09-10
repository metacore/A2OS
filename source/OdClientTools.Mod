(* Copyright 2003, Edgar Schwarz
Authors.   Edgar Schwarz, edgar@edgarschwarz.de, (es)
Contents. Command interface for client methods in WebDAVClient.
Remarks. - For shorter commands WebDAVClientTools is abbreviated to DCT.
Remarks. - HTTP knows about requests and responses. So resHeader should be used. WebHTTP still knows
Remarks.    ReplyHeader.
*)
MODULE (*OdClientTools*) OCT;

IMPORT
	Modules, Kernel, AosIO, AosTCP, AosFS, Utilities,
	WebHTTP, OdClient,
	Log := TFLog, In, XML, XMLObjects, OdXml, OdUtil,
	Objects:=OberonObjects, Gadgets;

CONST Ok* = 0;
VAR
	log: Log.Log;

(** Get character data of an element and log parent element if the child isn't found. *)
PROCEDURE GetCharData(parent: XML.Element; childName: ARRAY OF CHAR; VAR charData: ARRAY OF CHAR;
	 log: BOOLEAN): BOOLEAN;
VAR child: XML.Element;
	info: ARRAY 128 OF CHAR;
BEGIN
	child := OdXml.FindElement(parent, childName);
	IF child = NIL THEN
		info := "OdXml.GetCharData: child element not found = "; Utilities.Append(info, childName);
		IF log THEN OdXml.LogEl(info, parent); END;
		RETURN FALSE;
	END;
	OdXml.GetCharData(child, charData);
	RETURN TRUE;
END GetCharData;

(* Get Clusterball games. *)
PROCEDURE GetCbGames*; (* from to *)
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url, target: ARRAY 128 OF CHAR;
	f: AosFS.File;
	num, from, to: SIGNED16;
BEGIN
	In.Open; In.Int(from); In.Int(to);
	IF In.Done THEN
		FOR num := from TO to DO
			GetCbGame(num);
		END;
	ELSE
		log.Enter; log.String("GetCbGames <from> <to>");  log.Exit;
	END;
END GetCbGames;

(* Get Clusterball games. *)
PROCEDURE GetCbGame * (num: SIGNED32);
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; numStr, url, target: ARRAY 128 OF CHAR;
	f: AosFS.File;
BEGIN { EXCLUSIVE } (* Perhaps EXCLUSIVE helps to avoid hanging with Configuration.DoCommands. *)
	Utilities.IntToStr(num, numStr);
	Utilities.Concat("/g.php?gid=", numStr, url); OdClient.repos.expand(url);
	Utilities.Concat("cb.", numStr, target);
	OdClient.ShowMethodUrl(WebHTTP.GetM, url);
	OdClient.Get(url, reqHeader, con, resHeader, out, res);
	OdClient.StoreResult2File(resHeader, res, con, out, target, f);
END GetCbGame;

PROCEDURE Get*;
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url, target: ARRAY 128 OF CHAR;
	f: AosFS.File;
BEGIN { EXCLUSIVE } (* Perhaps EXCLUSIVE helps to avoid hanging with Configuration.DoCommands. *)
	In.Open; In.String(url); In.Name(target);
	OdClient.repos.expand(url);
	OdClient.ShowMethodUrl(WebHTTP.GetM, url);
	OdClient.Get(url, reqHeader, con, resHeader, out, res);
	OdClient.StoreResult2File(resHeader, res, con, out, target, f);
END Get;

PROCEDURE Put*;
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; in: AosFS.Reader; i, avail: SIGNED32; url, name: ARRAY 128 OF CHAR;
	f: AosFS.File; doc: XML.Document;	lenStr: ARRAY 16 OF CHAR;
	root: XML.Element; info: ARRAY 128 OF CHAR; s: XML.String;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url); In.Name(name);
	f := AosFS.Old(name);
	IF f # NIL THEN
		OdClient.repos.expand(url);
		NEW(in, f, 0);
		WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Type", "application/octet-stream");
		Utilities.IntToStr(f.Length(), lenStr);
		WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Length", lenStr);
		OdClient.ShowMethodUrl(WebHTTP.PutM, url);
		OdClient.Put(url, reqHeader, con, resHeader, out, in, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				s := root.GetName();
				IF s^ # "D:error" THEN
					OdXml.LogDoc("OdClient.Put: Unexpected root element = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
			log.Enter; log.String("File not found: "); log.String(name);  log.Exit;
	END;
END Put;

PROCEDURE Copy*;
VAR resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; org, copy: ARRAY 128 OF CHAR;
BEGIN { EXCLUSIVE } (* Perhaps EXCLUSIVE helps to avoid hanging with Configuration.DoCommands. *)
	In.Open; In.String(org); In.String(copy);
	IF In.Done THEN
		OdClient.repos.expand(org);
		OdClient.repos.expand(copy);
		OdClient.ShowMethodUrl(WebHTTP.CopyM, org);
		OdClient.Copy(org, copy, TRUE, con, resHeader, out, res);
	ELSE
		log.Enter; log.String('Copy "<original>"  "<copy>" ');  log.Exit;
	END;
END Copy;

PROCEDURE Move*;
VAR resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; old, new: ARRAY 128 OF CHAR;
BEGIN { EXCLUSIVE } (* Perhaps EXCLUSIVE helps to avoid hanging with Configuration.DoCommands. *)
	In.Open; In.String(old); In.String(new);
	IF In.Done THEN
		OdClient.repos.expand(old);
		OdClient.repos.expand(new);
		OdClient.ShowMethodUrl(WebHTTP.MoveM, old);
		OdClient.Move(old, new, TRUE, con, resHeader, out, res);
	ELSE
		log.Enter; log.String('Move "<old>"  "<new>" ');  log.Exit;
	END;
END Move;

PROCEDURE VersionControlFreeze*; (* " url " [ " author " " description " ] *)
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url, author, desc: ARRAY 128 OF CHAR; doc: XML.Document;
	ok: BOOLEAN; props: WebHTTP.AdditionalField;
BEGIN { EXCLUSIVE }
	ok := TRUE; In.Open;
	In.String(url); ok := In.Done;
	IF ok THEN
		In.String(author);
		IF In.Done THEN
			In.String(desc); ok := In.Done;
		ELSE (* just url *)
			author := ""; desc := "";
		END;
	END;
	IF ok THEN
		OdClient.repos.expand(url);
		props := NIL;
		WebHTTP.SetAdditionalFieldValue(props, "DAV:creator-displayname", author);
		WebHTTP.SetAdditionalFieldValue(props, "DAV:comment", desc);
		OdClient.ShowMethodUrl(WebHTTP.ProppatchM, url);
		OdClient.Proppatch(url, "set", props, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out); (* Read potential body. *)
		IF resHeader.statuscode # WebHTTP.OK THEN
			log.Enter; log.String("DCT.VersionControlFreeze: Proppatch error");  log.Exit;
			RETURN
		END;
		OdClient.ShowMethodUrl(WebHTTP.VersionControlM, url);
		OdClient.VersionControlFreeze(url, reqHeader, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			OdXml.LogDoc("XML body not parsed yet", doc);
		END;
	ELSE
		log.Enter; log.String('VersionControlFreeze "<url>" [ "<author>" "<description>" ]');  log.Exit;
	END;
END VersionControlFreeze;

PROCEDURE BaselineControlFreeze*; (* " url " [ " author " " description " ] *)
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url, author, desc: ARRAY 128 OF CHAR; doc: XML.Document;
	root: XML.Element; info: ARRAY 128 OF CHAR; s: XML.String;
	ok: BOOLEAN; props: WebHTTP.AdditionalField;
BEGIN { EXCLUSIVE }
	ok := TRUE; In.Open;
	In.String(url); ok := In.Done;
	IF ok THEN
		In.String(author);
		IF In.Done THEN
			In.String(desc); ok := In.Done;
		ELSE (* just url *)
			author := ""; desc := "";
		END;
	END;
	IF ok THEN
		OdClient.repos.expand(url);
		props := NIL;
		WebHTTP.SetAdditionalFieldValue(props, "DAV:creator-displayname", author);
		WebHTTP.SetAdditionalFieldValue(props, "DAV:comment", desc);
		OdClient.ShowMethodUrl(WebHTTP.ProppatchM, url);
		OdClient.Proppatch(url, "set", props, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out); (* Read potential body. *)
		IF resHeader.statuscode # WebHTTP.OK THEN
			log.Enter; log.String("DCT.BaselineControlFreeze: Proppatch error");  log.Exit;
			RETURN
		END;
		OdClient.ShowMethodUrl(WebHTTP.BaselineControlM, url);
		OdClient.BaselineControlFreeze(url, reqHeader, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				s := root.GetName();
				IF s^ # "D:error" THEN
					OdXml.LogDoc("OdClient.BaselineControlFreeze: Unexpected root element = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
		log.Enter; log.String('BaselineControlFreeze "<url>" "<author>" "<description>"');  log.Exit;
	END;
END BaselineControlFreeze;

(* Set subbaselines to a configuration: SetSubaseline 1{ subbaseline-string }
	Data is sent as a PROPPATCH. *)
PROCEDURE SetSubbaseline * ;
BEGIN
	Subbaseline("set");
END SetSubbaseline;

(* Add subbaselines to a configuration: AddSubaseline 1{ subbaseline-string }
	Data is sent as a PROPPATCH. *)
PROCEDURE AddSubbaseline * ;
BEGIN
	Subbaseline("add");
END AddSubbaseline;

(* Remove subbaselines from a configuration: RemSubaseline 1{ subbaseline-string }
	Data is sent as a PROPPATCH. *)
PROCEDURE RemSubbaseline * ;
BEGIN
	Subbaseline("rem");
END RemSubbaseline;

(* Add subbaselines to a configuration: AddSubaseline 1{ subbaseline-string }
	Data is sent as a PROPPATCH. *)
PROCEDURE Subbaseline(mode: ARRAY OF CHAR);
VAR resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url: ARRAY 128 OF CHAR; doc: XML.Document;
	root: XML.Element; info: ARRAY 128 OF CHAR; s: XML.String;
	props: WebHTTP.AdditionalField; line: OdUtil.Line; found: BOOLEAN;
BEGIN { EXCLUSIVE }
	found := FALSE;
	In.Open;
	In.String(url);
	IF In.Done THEN
		props := NIL;
		LOOP
			In.String(line);
			IF In.Done THEN
				WebHTTP.SetAdditionalFieldValue(props, "DAV:subbaseline-set", line);
				found := TRUE;
			ELSE EXIT;
			END;
		END;
	END;
	IF found THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.ProppatchM, url);
		OdClient.Proppatch(url, mode, props, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				s := root.GetName();
				IF s^ # "D:error" THEN
					OdXml.LogDoc("OdClient.AddSubbaseline: Unexpected root element = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
		log.Enter; log.String(mode); log.String('Subbaseline 1{"<subbaseline>"}');  log.Exit;
	END;
END Subbaseline;

PROCEDURE VersionControlSelect * ;
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url, versionResource: ARRAY 128 OF CHAR; doc: XML.Document;
	root: XML.Element; info: ARRAY 128 OF CHAR; s: XML.String;
	errorList: XMLObjects.Enumerator; p: ANY; error: XML.Element; errorName: OdUtil.Line;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url); In.String(versionResource);
	IF In.Done THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.VersionControlM, url);
		OdClient.VersionControlSelect(url, versionResource, reqHeader, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			IF OdXml.IsDAVError(doc, url) THEN (* <D:error xmlns:D="DAV:">  *)
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
			ELSE
				OdXml.LogDoc("OdClient.VersionControlSelect: unexpected root element in ", doc);
			END;
		END;
	ELSE
		log.Enter; log.String('VersionControlSelect "<url>" "<versionResource">');  log.Exit;
	END;
END VersionControlSelect;

PROCEDURE BaselineControlSelect*;
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url, baselineResource: ARRAY 128 OF CHAR; doc: XML.Document;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url); In.String(baselineResource);
	IF In.Done THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.BaselineControlM, url);
		OdClient.BaselineControlSelect(url, baselineResource, reqHeader, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			OdXml.LogDoc("XML body not parsed yet", doc);
		END;
	ELSE
		log.Enter; log.String('VersionControlSelect "<url>" "<versionResource">');  log.Exit;
	END;
END BaselineControlSelect;

PROCEDURE ReportVersionTree*;
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader;
	doc: XML.Document; root, response, href, props: XML.Element; responses: XMLObjects.Enumerator; p: ANY;
	hrefStr, s1, s2, s3, s4, s5, stateStr: ARRAY 128 OF CHAR;
	versionInfo: ARRAY 256 OF CHAR;
	elName: OdUtil.Line;
BEGIN { EXCLUSIVE }
	In.Open; In.String(reqHeader.uri);
	IF In.Done THEN
		OdClient.repos.expand(reqHeader.uri);
		OdClient.ShowMethodUrl(WebHTTP.ReportM, reqHeader.uri);
		OdClient.Report1("version-tree", reqHeader, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			root := doc.GetRoot(); elName := OdXml.AbsXmlName(root.GetName());
			IF elName = "DAV:multistatus" THEN
				responses := root.GetContents();
				WHILE responses.HasMoreElements() DO
					p := responses.GetNext();
					response :=  p(XML.Element);
					href := OdXml.FindElement(response, "DAV:href"); OdXml.GetCharData(href, hrefStr);
					props := OdXml.SplitElement(response, "DAV:propstat.DAV:prop");
					IF props = NIL THEN OdXml.LogDoc("XML element 'props' not found", doc); RETURN; END;
					IF ~GetCharData(props, "DAV:version-name",             s1, TRUE) THEN RETURN; END;
					IF ~GetCharData(props, "DAV:creator-displayname", s2, TRUE) THEN RETURN; END;
					IF ~GetCharData(props, "DAV:version-time",              s3, TRUE) THEN RETURN; END;
					IF ~GetCharData(props, "DAV:comment",                    s4, TRUE) THEN RETURN; END;
					VersionInfo(s2, s3, s1, s4, versionInfo);
					log.Enter; log.String(versionInfo);  log.Exit;
				END;
			ELSE
				 OdXml.LogDoc("DAV:multistatus not found", doc);
			END;
		END
	ELSE
		log.Enter; log.String('DCTs.ReportVersionTree "<url>"');  log.Exit;
	END;
END ReportVersionTree;

PROCEDURE ReportCompareBaseline*;
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; compareBaseline: ARRAY 128 OF CHAR; doc: XML.Document;
	versions, hrefs: XMLObjects.Enumerator; p: ANY; root, version, href: XML.Element;
	hrefStr: ARRAY 128 OF CHAR; elName: OdUtil.Line;
BEGIN { EXCLUSIVE }
	In.Open; In.String(reqHeader.uri); In.String(compareBaseline);
	WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "compareBaseline", compareBaseline);
	IF In.Done THEN
		OdClient.repos.expand(reqHeader.uri); OdClient.repos.expand(compareBaseline);
		OdClient.ShowMethodUrl(WebHTTP.ReportM, reqHeader.uri);
		OdClient.Report1("compare-baseline", reqHeader, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN (* XML example  *)
			root := doc.GetRoot(); elName := OdXml.AbsXmlName(root.GetName());
			IF elName = "DAV:multistatus" THEN
				versions := root.GetContents();
				WHILE versions.HasMoreElements() DO
					p := versions.GetNext();
					version :=  p(XML.Element);
					elName := OdXml.AbsXmlName(version.GetName());
					IF elName = "DAV:added-version" THEN
						href := OdXml.FindElement(version, "DAV:href"); OdXml.GetCharData(href, hrefStr);
						log.Enter; log.String("added: "); log.String(hrefStr);  log.Exit;
					ELSIF elName = "DAV:deleted-version" THEN
						href := OdXml.FindElement(version, "DAV:href"); OdXml.GetCharData(href, hrefStr);
						log.Enter; log.String("deleted: "); log.String(hrefStr);  log.Exit;
					ELSIF elName = "DAV:changed-version" THEN
						hrefs := version.GetContents();
						WHILE hrefs.HasMoreElements() DO
							p := hrefs.GetNext();
							href :=  p(XML.Element); OdXml.GetCharData(href, hrefStr);
							log.Enter; log.String("changed: "); log.String(hrefStr);  log.Exit;
						END;
					END;
				END;
			END;
		END;
	ELSE
		log.Enter; log.String('ReportCompareBaseline "<url>" "<baseline url>"');  log.Exit;
	END;
END ReportCompareBaseline;

(*  A directory listing with one file similar to RC 2518.
P0 <?xml version="1.0" encoding="utf-8" standalone='yes'?>
<multistatus xmlns="DAV:">
	<response>
		<href>http://ketchup.inf.ethz.ch/vc1/Data.Text</href>
		<propstat>
			<prop>
				<getcontentlength>239</getcontentlength>
				<getlastmodified>16.02.03 13:47:26</getlastmodified>
				<resourcetype>resource</resourcetype>
			</prop>
			<status>HTTP/1.1 200 OK</status>
		</propstat>
	</response>
</multistatus>
e := OdXml.FindElement(e, "href"); OdXml.GetCharData(e, baseline1);
OdClientTools.Propfind ^ "/vc1/" "/dav/" "/"
 *)

PROCEDURE ResourceInfo(name, length, modified, type: ARRAY OF CHAR): ARRAY OF CHAR;
VAR info: ARRAY 256 OF CHAR;
BEGIN
	COPY(name, info); Utilities.Append(info, ' ');
	Utilities.Append(info, length); Utilities.Append(info, ' ');
	Utilities.Append(info, modified);
	RETURN info;
END ResourceInfo;

PROCEDURE VersionInfo(creator, date, version, comment: ARRAY OF CHAR; VAR info: ARRAY OF CHAR);
CONST CR = 0DX; LF = 0AX;
BEGIN
	info[0] := 0X;
	IF creator # "" THEN Utilities.Append(info, creator); END;
	IF date # "" THEN Utilities.Append(info, ' '); Utilities.Append(info, date); END;
	IF version # "" THEN Utilities.Append(info, ' '); Utilities.Append(info, version); END;
	IF comment # "" THEN Utilities.Append(info, CR); Utilities.Append(info, LF); Utilities.Append(info, comment); END;
END VersionInfo;


(* Set properties: SetProp 1{ name '='  '"'  value '"' } '~' *)
PROCEDURE SetProp * ;
BEGIN
	Proppatch("set");
END SetProp;

(* Remove properties: RemProp 1{ name } '~' } *)
PROCEDURE RemProp * ;
BEGIN
	Proppatch("remove");
END RemProp;

(* Proppatch a resource. *)
PROCEDURE Proppatch(mode: ARRAY OF CHAR);
VAR resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url: ARRAY 128 OF CHAR; doc: XML.Document;
	root: XML.Element; info: ARRAY 128 OF CHAR; s: XML.String;
	props: WebHTTP.AdditionalField; name, value: OdUtil.Line; ch: CHAR;
BEGIN { EXCLUSIVE }
	In.Open;
	props := NIL;
	In.String(url);
	IF ~In.Done THEN log.Enter; log.String("DCT.Proppatch: no URL");  log.Exit;RETURN END;
	IF mode = "set" THEN
		LOOP
			In.String(name);
			IF ~In.Done THEN EXIT END;
			In.Char(ch);
			IF ch # "=" THEN log.Enter; log.String("DCT.Proppatch: no =");  log.Exit;EXIT END;
			In.String(value);
			IF ~In.Done THEN log.Enter; log.String("DCT.Proppatch: no value");  log.Exit;EXIT END;
			WebHTTP.SetAdditionalFieldValue(props, name, value);
			log.String(name);  log.Enter; log.String(" = "); log.String(value);  log.Exit;
		END;
	ELSIF mode = "remove" THEN
		LOOP
			In.String(name);
			IF ~In.Done THEN EXIT END;
			WebHTTP.SetAdditionalFieldValue(props, name, "");
		END;
	END;
	IF props # NIL THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.ProppatchM, url);
		OdClient.Proppatch(url, mode, props, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				s := root.GetName();
				IF s^ # "D:error" THEN
					OdXml.LogDoc("OdClient.Set|RemProp: unexpected root element in ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
		log.Enter; log.String(mode); log.String('  1{"<name>"="<value>"}');  log.Exit;
	END;
END Proppatch;

(** Propfind can have a optionally a depth and property list. No property lists means no body. *)
PROCEDURE Propfind*; (* [ ("0"|"1") { ["] prop ["] } "~" ] ] *)
VAR resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url: ARRAY 128 OF CHAR;
	doc: XML.Document;
	root, response, href, prop, dataProp, property: XML.Element; s: XML.String; attr: XML.Attribute;
	responses, props, dataProps: XMLObjects.Enumerator; p: ANY;
	depth: ARRAY 16 OF CHAR;
	propertyName, dataName, line: OdUtil.Line;
	nameData, lengthData, modifiedData, commentData, authorData, timeData, versionData, versionInfo: ARRAY 256 OF CHAR;
	propertyData: ARRAY 1024 OF CHAR; propList: WebHTTP.AdditionalField;
	t : Kernel.Timer; (* Test für Entlastung des Logs. *)
	list: Objects.Object;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url);
	IF In.Done THEN
		In.String(depth);
		propList := NIL;
		IF In.Done THEN
			LOOP
				In.String(propertyName);
				IF In.Done THEN
					(*line := OdXml.AbsXmlName(Utilities.NewString(propertyName));
					WebHTTP.SetAdditionalFieldValue(propList, line, "");*)
					WebHTTP.SetAdditionalFieldValue(propList, propertyName, "");
				ELSE
					EXIT;
				END;
			END;
		ELSE
			depth := "";
		END;
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.PropfindM, url);
		OdClient.Propfind(url, depth, propList, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			root := doc.GetRoot();
			IF root # NIL THEN
				s := root.GetName();
				IF OdXml.EqualName(s, "DAV:multistatus") THEN
					OdXml.xmlns := NIL;
					OdXml.GetXmlns(root);
					responses := root.GetContents();
					NEW(t); (* Test ob damit Log entlastet wird. *)
					WHILE responses.HasMoreElements() DO
						p := responses.GetNext();
						response :=  p(XML.Element);
						IF response # NIL THEN
							OdXml.GetXmlns(response);
							nameData := ""; lengthData := ""; modifiedData := "";
							commentData := ""; authorData := ""; versionData := "";
							href := OdXml.FindElement(response, "DAV:href"); OdXml.GetCharData(href, nameData);
							prop := OdXml.SplitElement(response, "DAV:propstat.DAV:prop");
							IF prop = NIL THEN OdXml.LogDoc("XML element 'props' not found", doc); RETURN; END;
							props := prop.GetContents();
							WHILE props.HasMoreElements() DO
								p := props.GetNext();
								property :=  p(XML.Element);
								propertyName := OdXml.AbsXmlName(property.GetName());
								IF       propertyName = "DAV:getcontentlength"      THEN OdXml.GetCharData(property, lengthData);
								ELSIF propertyName = "DAV:getlastmodified"          THEN OdXml.GetCharData(property, modifiedData);
								(* TODO: resourcetype *)
								ELSIF propertyName = "DAV:comment"                    THEN OdXml.GetCharData(property, commentData);
								ELSIF propertyName = "DAV:creator-displayname" THEN OdXml.GetCharData(property, authorData);
								ELSIF propertyName = "DAV:version-time"            THEN OdXml.GetCharData(property, timeData);
								ELSIF propertyName = "DAV:checked-in"  THEN
									href := OdXml.FindElement(property, "DAV:href");
									OdXml.GetCharData(href, versionData);
									WebHTTP.SetAdditionalFieldValue(propList, propertyName, versionData);
									Utilities.Concat("checked-in ", versionData, versionData);
								ELSIF propertyName = "DAV:checked-out" THEN
									OdXml.GetCharData(property, versionData); Utilities.Concat("checked-out ", versionData, versionData)
								ELSE
									dataProps := property.GetContents(); (* Get enumerator. *)
									IF dataProps.HasMoreElements() THEN
										p := dataProps.GetNext();
										IF p IS XML.Element THEN
											dataProp := p(XML.Element);
											dataName := OdXml.AbsXmlName(dataProp.GetName());
											WebHTTP.SetAdditionalFieldValue(propList, propertyName, dataName);
										ELSE (* assume it's character data. *)
											OdXml.GetCharData(property, versionData (* reuse variable *) );
											WebHTTP.SetAdditionalFieldValue(propList, propertyName, versionData);
										END;
									END;
								END;
							END;
							(*	Directory entry information*)
							log.Enter; log.String(ResourceInfo(nameData, lengthData, modifiedData, "")); log.Exit;
							VersionInfo(authorData, timeData, versionData, commentData,  versionInfo);
							IF versionInfo # "" THEN log.Enter; log.String(versionInfo); log.Exit; END;
							t.Sleep(10); (* Test ob damit Log entlastet wird. *)
						END;
					END;
					WHILE propList # NIL DO
						OdUtil.Msg3(propList .key, ": ", propList.value);
						propList := propList.next;
					END;
					(***
					IF OdXml.showTree # NIL THEN
						OdXml.showTree(doc);
					END;
					***)
				ELSE
					 OdXml.LogDoc("DAV:multistatus not found", doc);
				END
			ELSE
				log.Enter; log.String("DCT.Propfind: doc.root not found");  log.Exit;
			END
		END
	ELSE
		log.Enter; log.String('Propfind "<url>"');  log.Exit;
	END;
END Propfind;

PROCEDURE Propparse*; (* Like propfind, but parse results to WebHTTP.AdditionalField. *)
VAR
	url: ARRAY 128 OF CHAR; depth: ARRAY 16 OF CHAR;
	propList, list: WebHTTP.AdditionalField;
	propertyName, line: OdUtil.Line;
	con : AosTCP.Connection; out : AosIO.Reader; res: INTEGER;
	resHeader: WebHTTP.ResponseHeader; doc: XML.Document;
BEGIN  { EXCLUSIVE }
	In.Open; In.String(url);
	IF In.Done THEN
		In.String(depth);
		IF In.Done THEN
			NEW(propList);
			propList := NIL;
			LOOP
				In.String(propertyName);
				IF In.Done THEN
					(*line := OdXml.AbsXmlName(Utilities.NewString(propertyName));
					WebHTTP.SetAdditionalFieldValue(propList, line, "");*)
					WebHTTP.SetAdditionalFieldValue(propList, propertyName, "")
				ELSE
					EXIT;
				END;
			END;
			IF propList.next = propList THEN propList := NIL; END;
		ELSE
			depth := ""; propList := NIL;
		END;
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.PropfindM, url);
		OdClient.Propfind(url, depth, propList, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			list := NIL; (* Use new list, because property names in input aren't expanded. *)
			(* TODO: Use two lists to get a chance to easyly see which props didn't come ? *)
			OdClient.ParseProps(doc, list);
			WHILE list # NIL DO
				OdUtil.Msg3(list .key, ": ", list.value);
				list := list.next;
			END;
		END;
	ELSE
		log.Enter; log.String('Propparse "<url>" "<depth>" 1{"<prperty name>"}');  log.Exit;
	END;
END Propparse;

PROCEDURE Checkout * ; (* <file> | <collection> *)
VAR
	resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url: ARRAY 128 OF CHAR; doc: XML.Document;
	root: XML.Element; info: ARRAY 128 OF CHAR; s: XML.String;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url);
	IF In.Done THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.CheckoutM, url);
		OdClient.Checkout(url, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				s := root.GetName();
				IF s^ # "D:error" THEN
					OdXml.LogDoc("OdClient.Checkout: Unexpected root element = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
		log.Enter; log.String('Checkout ("<file url>" | "<collection url>"');  log.Exit;
	END;
END Checkout;

(** Merge: implemented for SVN. *)
PROCEDURE Merge * ; (* (<file> | <collection>) <source> *)
VAR
	resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url, source: ARRAY 128 OF CHAR; doc: XML.Document;
	root: XML.Element; info: ARRAY 128 OF CHAR; s: XML.String;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url); In.String(source);
	IF In.Done THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.MergeM, url);
		OdClient.Merge(url, source, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				s := root.GetName();
				IF s^ # "D:error" THEN
					OdXml.LogDoc("OdClient.Merge: Unexpected root element = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
		log.Enter; log.String('Merge ("<file url>" | "<collection url>"');  log.Exit;
	END;
END Merge;

PROCEDURE Checkin * ; (* <file> | <collection>) <author> <description> *)
VAR
	resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url, author, desc: ARRAY 128 OF CHAR; doc: XML.Document;
	root, el: XML.Element; info, elData: ARRAY 128 OF CHAR; s: XML.String;
	ok: BOOLEAN; props: WebHTTP.AdditionalField;
BEGIN { EXCLUSIVE }
	ok := TRUE; In.Open;
	In.String(url); ok := In.Done;
	IF ok THEN
		In.String(author);
		IF In.Done THEN
			In.String(desc); ok := In.Done;
		ELSE (* just url *)
			author := ""; desc := "";
		END;
	END;
	IF ok THEN
		OdClient.repos.expand(url);
		(*     Check whether resource is checked-in     *)
		props := NIL;
		WebHTTP.SetAdditionalFieldValue(props, "D:checked-out", "");
		OdClient.ShowMethodUrl(WebHTTP.PropfindM, url);
		OdClient.Propfind(url, "0", props, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out); (* Read potential body. *)
		IF resHeader.statuscode # WebHTTP.MultiStatus THEN
			log.Enter; log.String("DCT.Checkin: Propfind error");  log.Exit;
			RETURN
		ELSE
			LOOP
				IF doc # NIL THEN
					el := OdXml.SplitElement(doc.GetRoot(), "DAV:response.DAV:propstat.DAV:prop.DAV:checked-out");
					IF el # NIL THEN
						OdXml.GetCharData(el, elData);
						IF elData # "" THEN EXIT; END;
					END;
				END;
				log.Enter; log.String("DCT.Checkin: resource isn't a checked out version-controlled resource");  log.Exit;
				RETURN;
			END;
		END;
		(*     Set DAV:comment and DAV:creator-displayname    *)
		props := NIL;
		WebHTTP.SetAdditionalFieldValue(props, "DAV:creator-displayname", author);
		WebHTTP.SetAdditionalFieldValue(props, "DAV:comment", desc);
		OdClient.ShowMethodUrl(WebHTTP.ProppatchM, url);
		OdClient.Proppatch(url, "set", props, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out); (* Read potential body. *)
		IF resHeader.statuscode # WebHTTP.OK THEN
			log.Enter; log.String("DCT.Checkin: Proppatch error");  log.Exit;
			RETURN
		END;
		(*    Do checkin    *)
		OdClient.ShowMethodUrl(WebHTTP.CheckinM, url);
		OdClient.Checkin(url, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				s := root.GetName();
				IF s^ # "D:error" THEN
					OdXml.LogDoc("OdClient.Checkin: Unexpected root element = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
		log.Enter; log.String('Checkin ("<file url>" | "<collection url>") "<author>" "<description>"');  log.Exit;
	END;
END Checkin;

PROCEDURE Uncheckout*;
VAR
	reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url: ARRAY 128 OF CHAR;
	doc: XML.Document;
	root: XML.Element; info: ARRAY 128 OF CHAR; rootName: OdUtil.Line;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url);
	IF In.Done THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.UncheckoutM, url);
		OdClient.Uncheckout(url, reqHeader, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				rootName := OdXml.AbsXmlName(root.GetName());
				IF rootName # "DAV:error" THEN
					OdXml.LogDoc("OdClient.Uncheckout: Unexpected root element = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
		log.Enter; log.String('Uncheckout "<url>"');  log.Exit;
	END;
END Uncheckout;

PROCEDURE Update*;
VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url, versionName: ARRAY 128 OF CHAR; doc: XML.Document;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url); In.String(versionName);
	IF In.Done THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.UpdateM, url);
		OdClient.Update(url, versionName, reqHeader, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			OdXml.LogDoc("XML body not parsed yet", doc);
		END;
	ELSE
		log.Enter; log.String('Update "<url>" ("<version number>" | "<version url")');  log.Exit;
	END;
END Update;

(*  OdClientTools.Delete OdClient.Delete WebDAVPlugin.Delete DAVDeltavBase.Delete *)
PROCEDURE Delete * ; (* <file> | <collection>) *)
VAR
	resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection;
	out : AosIO.Reader; url, author, desc: ARRAY 128 OF CHAR; doc: XML.Document;
	root: XML.Element; info: ARRAY 128 OF CHAR; elName: OdUtil.Line;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url);
	IF In.Done THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.DeleteM, url);
		OdClient.Delete(url, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				elName := OdXml.AbsXmlName(root.GetName());
				IF elName # "DAV:error" THEN
					OdXml.LogDoc("OdClientTools.Delete: Unexpected root element. Doc = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
		log.Enter; log.String('Delete ("<file url>" | "<collection url>")');  log.Exit;
	END;
END Delete;

(*  OdClientTools.Mkcol OdClient.Mkcol WebDAVPlugin.Mkcol DAVDeltavBase.Mkcol *)
PROCEDURE Mkcol * ; (* <collection>) *)
VAR
	resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection; doc: XML.Document;
	out : AosIO.Reader; url, author, desc: ARRAY 128 OF CHAR;
	root: XML.Element; info: ARRAY 128 OF CHAR; s: XML.String;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url);
	IF In.Done THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.MkcolM, url);
		OdClient.Mkcol(url, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				s := root.GetName();
				IF s^ # "D:error" THEN
					OdXml.LogDoc("OdClient.Mkcol: Unexpected root element = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
		log.Enter; log.String('Mkcol ("<file url>" | "<collection url>")');  log.Exit;
	END;
END Mkcol;

(*  OdClientTools.Mkcol OdClient.Mkcol WebDAVPlugin.Mkcol DAVDeltavBase.Mkcol *)
PROCEDURE Mkactivity * ; (* <activity url>) *)
VAR
	resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection; doc: XML.Document;
	out : AosIO.Reader; url, author, desc: ARRAY 128 OF CHAR;
	root: XML.Element; info: ARRAY 128 OF CHAR; s: XML.String;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url);
	IF In.Done THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.MkactivityM, url);
		OdClient.Mkactivity(url, con, resHeader, out, res);
		doc := OdClient.XmlResult(resHeader, res, con, out);
		IF doc # NIL THEN
			LOOP (*  *)
				root := doc.GetRoot();
				s := root.GetName();
				IF s^ # "D:error" THEN
					OdXml.LogDoc("OdClient.Mkactivity: Unexpected root element = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  url);
				info := "DAV:error = "; Utilities.Append(info, url);
				log.Enter; log.String(info);  log.Exit;
				EXIT;
			END;
		END;
	ELSE
		log.Enter; log.String('Mkactivity "<activity url>" ');  log.Exit;
	END;
END Mkactivity;

(*  OdClientTools.Options OdClient.Options WebDAVPlugin.Options DAVDeltavBase.Options *)
PROCEDURE Options * ; (* <collection> | <resource> *)
VAR
	resHeader: WebHTTP.ResponseHeader; res: INTEGER; con : AosTCP.Connection; doc: XML.Document;
	out : AosIO.Reader; url, author, desc: ARRAY 128 OF CHAR;
	root: XML.Element; info: ARRAY 128 OF CHAR; s: XML.String;
	log: Log.Log;
BEGIN { EXCLUSIVE }
	In.Open; In.String(url);
	IF In.Done THEN
		OdClient.repos.expand(url);
		OdClient.ShowMethodUrl(WebHTTP.OptionsM, url);
		OdClient.Options(url, con, resHeader, out, res);
		NEW(log, "Options Response");
		WebHTTP.LogResponseHeader(log, resHeader);
		(* No XML expected at the moment  *)
	ELSE
		log.Enter; log.String('Options ("<file url>" | "<collection url>")');  log.Exit;
	END;
END Options;


(** working with a VCC (version controlled configuration) *)
(** Put members from client to server workspace. VCC.Put "<client directory>".
The client directory will later be responsible for finding the matching vcc from OdClientVcc.Mod  *)
PROCEDURE VccPut * ;
VAR serverDir, clientDir: ARRAY 128 OF CHAR; vcc: OdClient.Vcc;
BEGIN
	In.Open; In.String(serverDir); OdClient.repos.expand(serverDir);
	In.String(clientDir);
	IF In.Done THEN
		NEW(vcc);
		vcc.put(serverDir, clientDir);
	ELSE log.Enter; log.String('DCT.VccPut "<server directory>" "<client directory>"');  log.Exit;
	END;
END VccPut;

(** Get members from server to client workspace. DCT.VccGet "<client directory>".
The client directory will later be responsible for finding the matching vcc from OdClientVcc.Mod  *)
PROCEDURE VccGet * ;
VAR serverDir, clientDir: ARRAY 128 OF CHAR; vcc: OdClient.Vcc;
BEGIN
	In.Open; In.String(serverDir); OdClient.repos.expand(serverDir);
	In.String(clientDir);
	IF In.Done THEN
		NEW(vcc);
		vcc.get(serverDir, clientDir);
	ELSE log.Enter; log.String('DCT.VccGet "<server directory>" "<client directory>"');  log.Exit;
	END;
END VccGet;

(** Checkin a VCC and it's members. VccCheckin "<server directory>" *)
PROCEDURE VccCheckin * ;
VAR serverDir, auth, desc: ARRAY 128 OF CHAR; vcc: OdClient.Vcc;
BEGIN
	In.Open; In.String(serverDir); OdClient.repos.expand(serverDir);
	IF In.Done THEN In.String(auth); END;
	IF In.Done THEN In.String(desc); END;
	IF In.Done THEN
		NEW(vcc);
		 vcc.checkin(serverDir, auth, desc);
	ELSE log.Enter; log.String('DCT.VccCheckin "<server directory>" "<author>" "<desc>"');  log.Exit;
	END;
END VccCheckin;

(** Checkout a VCC and it's members. VccCheckout "<server directory>" *)
PROCEDURE VccCheckout * ;
VAR serverDir: ARRAY 128 OF CHAR; vcc: OdClient.Vcc;
BEGIN
	In.Open; In.String(serverDir); OdClient.repos.expand(serverDir);
	IF In.Done THEN
		NEW(vcc);
		vcc.checkout(serverDir);
	ELSE log.Enter; log.String('DCT.VccCheckout "<server directory>"');  log.Exit;
	END;
END VccCheckout;

(** Uncheckout a VCC and it's members. VccUncheckout "<server directory>" *)
PROCEDURE VccUncheckout * ;
VAR  serverDir: ARRAY 128 OF CHAR; vcc: OdClient.Vcc;
BEGIN
	In.Open; In.String(serverDir); OdClient.repos.expand(serverDir);
	IF In.Done THEN
		NEW(vcc);
		vcc.uncheckout(serverDir);
	ELSE log.Enter; log.String('DCT.VccUncheckout "<server directory>"');  log.Exit;
	END;
END VccUncheckout;

BEGIN
	log := OdClient.log;
END (*OdClientTools*) OCT.
