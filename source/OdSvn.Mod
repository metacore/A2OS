MODULE OdSvn;
(** $Id:$
Authors:	Edgar Schwarz, (es)
Purpose:	Basic interface to subversion using apache2 and mod_dav_svn.
TODO:	Better parse namespaces in XML replies.
TODO:	Return a att/val list in PROPFIND.
TODO:	How to add/commit a new directory.
TODO:	Add/commit multiple files with a single activity ? Can activity be reused ?
TODO:	Get a version to a workspace ? First part of commit ?
TODO:	Get version history.
TODO:	Checkout repo parent directory of path is "deeper" ?
TODO:	Waiting on connection until a timeout ? Makes thing longer perhaps. Persistent connections ?
*)
IMPORT OdClient, Log := TFLog, U := Strings, WebHTTP, Streams, XML, Files, OdUtil, OdXml,
	XMLObjects, Commands, KernelLog,
	SVNOutput, SVNAdmin, SVNUtil;

VAR
	log: Log.Log;
	encTable: ARRAY 64 OF CHAR;
	decTable: ARRAY 128 OF INTEGER;


TYPE
	SvnProps = OBJECT (* light version of SVNAdmin.EntryEntity :) *)
	VAR
		add : BOOLEAN;
		date : ARRAY 33 OF CHAR;
		author : ARRAY 50 OF CHAR;
		revision : ARRAY 10 OF CHAR;
		uuid : ARRAY 37 OF CHAR;
		checksum : ARRAY 34 OF CHAR;
	END SvnProps;

TYPE
	StringReader = OBJECT
		VAR res, pos: LONGINT; s: U.String;
		PROCEDURE &Init(s: U.String);
		BEGIN SELF.s := s; res := Streams.Ok; pos := 0; END Init;
		PROCEDURE Char(VAR ch: CHAR);
		BEGIN ch := s^[pos]; INC(pos); IF ch = 0X THEN res := Streams.EOF; END; END Char;
	END StringReader;

TYPE
	LogItem = OBJECT
	VAR
		versionName, date, addedPath, modifiedPath, comment: U.String;
		PROCEDURE &Init;
		BEGIN
			versionName := NIL;
			date:= NIL;
			addedPath := NIL;
			modifiedPath:= NIL;
			comment := NIL;
		END Init;
	END LogItem;

TYPE
	Activity* = OBJECT
	VAR url: U.String;
		statuscode*: LONGINT;
		log: Log.Log;
		client : OdClient.OdClient;

		PROCEDURE &Init*( c : OdClient.OdClient; CONST name: ARRAY OF CHAR);
		VAR urlPath: ARRAY 128 OF CHAR;
			repos : OdClient.Repos;
		BEGIN
			client := c;
			log := OdClient.log;
			repos := client.GetRepos();
			Files.JoinPath(repos.path, "!svn/act/", urlPath);
			repos.expand(urlPath);
			url := U.ConcatToNew(urlPath, name);
		END Init;

		PROCEDURE make*;
		VAR
			resHeader: WebHTTP.ResponseHeader; doc: XML.Document;
			out : Streams.Reader; res: WORD;
		BEGIN
			OdClient.ShowMethodUrl(WebHTTP.MkactivityM, url^);
			client.Mkactivity(url^, resHeader, out, res);
			doc := client.XmlResult(resHeader, res, out);
			statuscode := resHeader.statuscode;
			IF resHeader.statuscode # 201 THEN
				log.Enter; log.String("SvnDeltaV.Get: mkactivity error. Statuscode="); log.Int(resHeader.statuscode, 4);  log.Exit;
				url := NIL; (* Show that there was a problem. *)
			END;
		END make;

		PROCEDURE getUrl* () : U.String;
		BEGIN
			RETURN url;
		END getUrl;

		PROCEDURE delete*;
		VAR resHeader: WebHTTP.ResponseHeader; doc: XML.Document;
			out : Streams.Reader; res: WORD;
		BEGIN
			ASSERT ( url # NIL );

			OdClient.ShowMethodUrl(WebHTTP.DeleteM, url^);
			client.Delete(url^, resHeader, out, res);
			doc := client.XmlResult(resHeader, res, out);
			IF resHeader.statuscode # 204 THEN
				log.Enter; log.String("SvnDeltaV.Get: delete error. Statuscode="); log.Int(resHeader.statuscode, 4);  log.Exit;
			END;
		END delete;
	END Activity;

TYPE
UpdateReq* = OBJECT(XML.Document);
	PROCEDURE &InitUpdateReq*( client : OdClient.OdClient; svn : OdSvn; CONST pathName: ARRAY OF CHAR; headVersion, version: LONGINT ); (* Revision numbers: e.g. 18 *)
	VAR el1, el2: XML.Element; ac: XML.ArrayChars;
		path,name: ARRAY 256 OF CHAR;
		versionStr: ARRAY 32 OF CHAR;
		repos : OdClient.Repos;
	BEGIN Init();
		repos := client.GetRepos();

		IF svn.useSvn & ( svn.repositoryPathLength >= U.Length( pathName )) THEN
			svn.useUpdateTarget := FALSE;
			COPY ( pathName, path );
		ELSE
			svn.useUpdateTarget := TRUE;
			Files.SplitPath(pathName, path, name);
		END;

		NEW(el1); el1.SetName("S:update-report"); SELF.AddContent(el1);
		el1.SetAttributeValue("send-all", "true"); el1.SetAttributeValue("xmlns:S", "svn:");
		repos.expand(path);
		NEW(el2); el2.SetName("S:src-path"); el1.AddContent(el2);
		NEW(ac); ac.SetStr(path); el2.AddContent(ac);
		NEW(el2); el2.SetName("S:target-revision"); el1.AddContent(el2);
		U.IntToStr(version, versionStr);
		NEW(ac); ac.SetStr(versionStr); el2.AddContent(ac);

		IF svn.useUpdateTarget THEN
			NEW(el2); el2.SetName("S:update-target"); el1.AddContent(el2);
		END;
		NEW(ac); ac.SetStr(name); el2.AddContent(ac);


		NEW(el2); el2.SetName("S:entry");
		el1.AddContent(el2);
		IF headVersion = -1 THEN
			(* use versionStr from before *)
			el2.SetAttributeValue("start-empty", "true");
		ELSE
			U.IntToStr(headVersion, versionStr);
		END;
		el2.SetAttributeValue("rev", versionStr);

	END InitUpdateReq;
END UpdateReq;

LogReq = OBJECT(XML.Document);
(* <S:log-report xmlns:S="svn:">
		<S:start-revision>18</S:start-revision>
		<S:end-revision>1</S:end-revision>
		<S:discover-changed-paths/>
		<S:path></S:path>
	</S:log-report>  *)
	PROCEDURE &InitLogReq(start, end: LONGINT); (* Revision numbers: e.g. 18, 1 *)
	VAR el1, el2: XML.Element; ac: XML.ArrayChars;
		startStr, endStr: ARRAY 32 OF CHAR;
	BEGIN Init();
		NEW(el1); el1.SetName("S:log-report"); el1.SetAttributeValue("xmlns:S", "svn:"); SELF.AddContent(el1);
		NEW(el2); el2.SetName("S:start-revision"); el1.AddContent(el2);
		U.IntToStr(start, startStr);
		NEW(ac); ac.SetStr(startStr); el2.AddContent(ac);
		NEW(el2); el2.SetName("S:end-revision"); el1.AddContent(el2);
		U.IntToStr(end, endStr);
		NEW(ac); ac.SetStr(endStr); el2.AddContent(ac);
		NEW(el2); el2.SetName("S:discover-changed-paths"); el1.AddContent(el2);
		NEW(el2); el2.SetName("S:path"); el1.AddContent(el2);
	END InitLogReq;
END LogReq;



TYPE
	OdSvn* = OBJECT
	VAR
		useSvn : BOOLEAN;
		globalVersion : LONGINT;
		svnFileUpdate : BOOLEAN;
		traverseDummy*, useUpdateTarget*, checkout* : BOOLEAN;

		client* : OdClient.OdClient;
		xml : OdXml.OdXml;

		wrk*, ver*, errorMsg, repositoryURL* : ARRAY 256 OF CHAR; (* wrk URL of PROPFIND/PATCH *)
		pfStatus* : LONGINT;
		countChanges* : LONGINT;
		repositoryPathLength* : SIZE;
		removeDir*, svnUpdated* : BOOLEAN;
		resultDoc* : XML.Document;
		nextVersion* : ARRAY 10 OF CHAR;
		context* : Commands.Context;

	PROCEDURE &Init*;
	BEGIN
		NEW ( xml );
		NEW ( client, xml );
		(* Default repository. *)

		useSvn := FALSE;
		globalVersion := 0;
		client.server := "svn";
		checkout := FALSE;
	END Init;



	PROCEDURE Get(CONST url: ARRAY OF CHAR; VAR f: Files.File);
	VAR reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader;
		res: WORD;
		out : Streams.Reader;
	BEGIN
		OdClient.ShowMethodUrl(WebHTTP.GetM, url);
		client.Get(url, reqHeader, resHeader, out, res);
		OdClient.StoreResult2File(resHeader, res, out, "", f);
	END Get;


	(* TODO: get the property stuff from XML. *)
	PROCEDURE ParseUpdate(doc: XML.Document; VAR txDelta: Files.File);
	VAR wtr: Files.Writer; s: XML.String;
		root, txdelta: XML.Element;
		elPath: ARRAY 256 OF CHAR;
		strRdr: StringReader;
		str : U.String;
	BEGIN
		NEW ( str, 4096 );
		root := doc.GetRoot();
		IF root # NIL THEN
			s := root.GetName();
			IF xml.EqualName(s, "S:update-report") THEN
				xml.xmlns := NIL;
				xml.GetXmlns(root);
				elPath := "svn:open-directory.svn:open-file.svn:txdelta";
				txdelta := xml.SplitElement(root, elPath);
				IF txdelta # NIL THEN
					log.Enter; log.String("XML.Element found: "); log.String(elPath); log.Exit;
					NEW(strRdr, OdXml.GetCharString(txdelta));
					txDelta := Files.New("");
					NEW(wtr, txDelta, 0);
					IF DecodeIO(strRdr, wtr) THEN
						wtr.Update();
						log.Enter; log.String("txdelta decoded"); log.Exit;
					ELSE
						log.Enter; log.String("txdelta error on decoding"); log.Exit;
						txDelta := NIL;
					END;
				ELSE
					log.Enter; log.String("XML.Element not found: "); log.String(elPath); log.Exit;
				END;
			ELSE
				log.Enter; log.String("SvnDeltaV.ParseUpdate unexpected root name:" );  log.String(s^); log.Exit;
				xml.LogDoc("DAV:update-report not found", doc);
			END;
		ELSE
			log.Enter; log.String("SvnDeltaV.ParseUpdate: doc.root not found");  log.Exit;
		END;
		log.Enter; log.String( "" );  log.Exit;
	END ParseUpdate;




	PROCEDURE DecodeIO(in: StringReader; out: Streams.Writer): BOOLEAN;
	VAR
		codes: ARRAY 4 OF INTEGER;
		i: INTEGER;
		ch: CHAR;
		ok, end: BOOLEAN;
	BEGIN
		ok := TRUE; end := FALSE;
		in.Char(ch);
		REPEAT
			i := 0;
			WHILE (in.res = Streams.Ok) & ok & (i < 4) DO
				WHILE (in.res = Streams.Ok) & (ch <= " ") DO
					in.Char(ch)
				END;
				codes[i] := decTable[ORD(ch)];
				ok := codes[i] >= 0; INC(i);
				IF ok THEN
					in.Char(ch)
				END
			END;
			IF i > 0 THEN
				IF ok THEN
					out.Char(CHR(ASH(codes[0], 2)+ASH(codes[1], -4)));
					out.Char(CHR(ASH(codes[1], 4)+ASH(codes[2], -2)));
					out.Char(CHR(ASH(codes[2], 6)+codes[3]))
				ELSIF ch = "=" THEN
					ok := TRUE; end := TRUE; DEC(i);
					IF i = 2 THEN
						out.Char(CHR(ASH(codes[0], 2)+ASH(codes[1], -4)))
					ELSIF i = 3 THEN
						out.Char(CHR(ASH(codes[0], 2)+ASH(codes[1], -4)));
						out.Char(CHR(ASH(codes[1], 4)+ASH(codes[2], -2)))
					ELSIF i # 0 THEN
						ok := FALSE
					END
				ELSIF i = 4 THEN
					ok := TRUE; end := TRUE;
					out.Char(CHR(ASH(codes[0], 2)+ASH(codes[1], -4)));
					out.Char(CHR(ASH(codes[1], 4)+ASH(codes[2], -2)));
					out.Char(CHR(ASH(codes[2], 6)+codes[3]))
				ELSIF i = 1 THEN
					ok := TRUE; end := TRUE
				END
			ELSE
				end := TRUE
			END
		UNTIL (in.res # Streams.Ok) OR end;
		RETURN ok
	END DecodeIO;

	(* Will create a new target using svn vcdiff data. Start with reading delta information. *)
	PROCEDURE TxDelta(txDelta: Files.File; CONST workUrl, targetName: ARRAY OF CHAR );
	CONST
		PLog = FALSE;
		Is = 0; (* Copy from source. *)
		It = 1; (* Copy from target. *)
		Id = 2; (* Copy from data. *)
		BufLen = 1024;
	VAR source, delta, deltaData, targetR, from: Files.Reader; targetW: Files.Writer;
		buf: ARRAY BufLen OF CHAR;
		(* View variables. *)
		svo, (* Source view offset.  *)
		svl,  (* Source view length *)
		tvl,  (* Target view length  *)
		il,	(* Instruction length.   *)
		dl,   (* Data length.           *)
		(* Support variables. *)
		co, cl, (* Copy offset, length. *)
		n: LONGINT;
		tvo, (* Target view offset. *)
		istart: Files.Position;
		read: SIZE;
		iord, op: INTEGER; ch: CHAR;
		sourceF, targetF: Files.File;
	BEGIN
		log.Enter;
		log.Ln; log.Ln;
		log.String( "--- TXDELTA ---" );
		log.Ln;
		log.Exit;
		(* Prepare targetFile. *)
		targetF := Files.New(targetName);	(* create a new file (not visible yet) *)
		IF targetF # NIL THEN
			NEW(targetW, targetF, 0);
			NEW(targetR, targetF, 0);
		ELSE
			log.Enter; log.String("SvnDeltaV.TxDelta: Files.New targetF=NIL");  log.Exit;
			RETURN;
		END;
		(* Read sourcefile from workUrl (checked out by Subversion). *)

		IF useSvn THEN
			sourceF := Files.Old ( workUrl );
			ASSERT ( sourceF # NIL );
		ELSE
			Get(workUrl, sourceF);
		END;

		IF sourceF # NIL THEN
			NEW(source, sourceF, 0);
		ELSE
			log.Enter; log.String("SvnDeltaV.TxDelta: Get workUrl sourceF=NIL");  log.Exit;
			RETURN;
		END;

		(* Apply delta. *)
		NEW(delta, txDelta, 0);
		delta.RawLInt(svo); (* Skip header. *)
		LOOP
			RawNum(delta, svo);
			IF delta.res # Streams.Ok THEN
				log.Enter; log.String("SvnDeltaV.TxDelta: delta.res = "); log.Int(delta.res, 4);  log.Exit;
				EXIT;
			END;
			(*log.Enter; log.String("svo = "); log.Int(svo, 8);  log.Exit;*)
			RawNum(delta, svl); IF PLog THEN log.Enter; log.String("svl = "); log.Int(svl, 8); log.Exit; END;
			RawNum(delta, tvl); IF PLog THEN log.Enter; log.String("tvl = "); log.Int(tvl, 8); log.Exit; END;
			RawNum(delta, il);  IF PLog THEN log.Enter;  log.String("il = ");  log.Int(il, 8);    log.Exit;END;
			RawNum(delta, dl); IF PLog THEN log.Enter; log.String("dl = ");  log.Int(dl, 8);   log.Exit;END;
			istart := delta.Pos();
			NEW(deltaData, txDelta, istart+il);
			(* Read instructions *)
			tvo := targetW.Pos();
			WHILE delta.Pos() < istart+il DO
				(*log.Enter; log.Int(delta.Pos(), 8); log.Int(istart, 8); log.Int(il, 8);  log.Exit;*)
				iord := ORD(delta.Get());
				op := iord DIV 64;
				IF iord MOD 64 >  0 THEN cl := iord MOD 64; ELSE RawNum(delta, cl); END;
				CASE op OF
					Is, It: (* From target or source. *)
						RawNum(delta, co);
						IF PLog THEN log.Enter; log.Int(op, 8); log.Int(cl, 8); log.Int(co, 8);  log.Exit; END;
						IF op = Is THEN NEW(from , sourceF, svo+co);
						ELSIF op = It THEN NEW(from, targetF, tvo+co);
						END;
						WHILE cl > BufLen DO
							from.Bytes(buf, 0, BufLen, read);
							targetW.Bytes(buf, 0, read);
							DEC(cl, BufLen);
						END;
						from.Bytes(buf, 0, cl, read);
						targetW.Bytes(buf, 0, read);
					| Id: (* Data from txdelta. *)
						IF PLog THEN log.Enter; log.Int(op, 8); log.Int(cl, 8); log.Exit; END;
						FOR n := 1 TO cl DO
							ch := deltaData.Get();
							targetW.Char(ch);
						END;
					ELSE
				END;
			END;
			(* Skip data block to get to next view. *)
			FOR n := 1 TO dl DO
				ch := delta.Get();
			END;
		END;
		targetW.Update();
		Files.Register(targetF);
	END TxDelta;


	(* Hide profind stuff in a procedure.  *)
	PROCEDURE Propfind*(url : ARRAY OF CHAR; CONST properties: ARRAY OF CHAR; VAR props: WebHTTP.AdditionalField; VAR err: ARRAY OF CHAR);
	VAR splitter: OdXml.StringSplitter;
		name: ARRAY 64 OF CHAR;
		resHeader: WebHTTP.ResponseHeader; doc: XML.Document;
		out : Streams.Reader; res: WORD;
		list: WebHTTP.AdditionalField;
		repos : OdClient.Repos;
	BEGIN
		repos := client.GetRepos();
		(* Check for error state. *)
		IF err # "" THEN
			log.Enter; log.String(err);  log.Exit;
			RETURN;
		END;
		(* Patch url. *)
		IF U.Pos("http://", url) # 0 THEN repos.expand(url); END;
		OdClient.ShowMethodUrl(WebHTTP.PropfindM, url);
		(* Make list of properties. *)
		props := NIL;
		NEW(splitter, properties);
		WHILE splitter.Next('.', name) DO
			WebHTTP.SetAdditionalFieldValue(props, name, "");
		END;
		client.Propfind(url, "0", props, resHeader, out, res);
		pfStatus := resHeader.statuscode;
		IF pfStatus = 0 THEN RETURN END;

		log.Enter; log.String("SvnDeltaV.Propfind. Statuscode="); log.Int(resHeader.statuscode, 4);  log.Exit;
		doc := client.XmlResult(resHeader, res, out);
		IF doc # NIL THEN
			props := NIL; (* Use new list, because property names in input aren't expanded. *)
			(* TODO: Use two lists to get a chance to easyly see which props didn't come ? *)
			client.ParseProps(doc, props);
			list := props;
			WHILE list # NIL DO
				OdUtil.Msg3(list.key, ": ", list.value);
				list := list.next;
			END;
		ELSE
			COPY("SvnDeltaV.Propfind: err no result doc", err);
		END;
		log.Enter; log.String( "" ); log.Exit;
	END Propfind;


	(** Get SVN version history.
	 SvnVersion1.Text SvnVersion2.Text *)
	PROCEDURE Versions* ( context: Commands.Context );
	VAR url, err, vcc, ci, bc, pathName, path, name: ARRAY 256 OF CHAR;
		props: WebHTTP.AdditionalField;
		start, end: LONGINT;
	BEGIN
		log.Enter; log.String( "" );  log.Exit;
		log.Enter; log.String( "" );  log.Exit;
		log.Enter; log.String( "***** VERSIONS *****" );  log.Exit;
		log.Enter; log.String( "" );  log.Exit;

		context.arg.SkipWhitespace; context.arg.String( url);
		context.arg.SkipWhitespace; context.arg.Int( start, FALSE );
		context.arg.SkipWhitespace; context.arg.Int( end, FALSE );
		IF context.arg.res = Commands.Ok THEN
			Propfind(url, "D:version-controlled-configuration", props, err);
			IF err = "" THEN
				IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:version-controlled-configuration", vcc) THEN END;
				Propfind(vcc, "D:checked-in", props, err);
				IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:checked-in", ci) THEN END;
				Propfind(ci, "D:baseline-collection", props, err);
				IF WebHTTP.GetAdditionalFieldValue(props, "DAV:baseline-collection", bc) THEN
					IF start = 0 THEN (* Use head revision. *)
						(*log.Enter; log.String("bc="); log.String(bc); log.Exit;*)
						Files.SplitPath(bc, pathName, name); (* "remove" trailing '/' of baseline collection. *)
						Files.SplitPath(pathName, path, name); (* HEAD revision is last segment. *)
						(*log.Enter; log.String("Head="); log.String(name); log.Exit;*)
						U.StrToInt(name, start);
					END;
				END;
				LogReport(url, bc, start, end);
			ELSE
				log.Enter; log.String( "Propfind Error: " ); log.String( err ); log.Ln; log.Exit;
			END;
		ELSE
			log.Enter; log.String('SvnDeltaV.Versions "<url>" <start revision> <end revision>');  log.Exit;
		END;
	END Versions;





	PROCEDURE UseSvn* ( b : BOOLEAN );
	BEGIN
		useSvn := b;
	END UseSvn;

	PROCEDURE FileUpdate* ( b : BOOLEAN );
	BEGIN
		svnFileUpdate := b;
	END FileUpdate;

	(* Subversion update report.
	REPORT /repos/!svn/vcc/default HTTP/1.1
	Host: 192.168.178.66
	<S:update-report send-all="true" xmlns:S="svn:">
		<S:src-path>http://192.168.178.66/repos/svn1</S:src-path>
		<S:target-revision>19</S:target-revision>
		<S:update-target>Add0.Text</S:update-target>
		<S:entry rev="24" ></S:entry> For get without diff: target-revision = entry rev and start-empty="true"
	</S:update-report>
	HTTP/1.1 200 OK *)

	(* There must be already a version (e.g. the newest which can be checked out) to make a delta on it for an older. *)
	PROCEDURE UpdateReport*(pathName, vcc: ARRAY OF CHAR; CONST workUrl: ARRAY OF CHAR;
		headVersion, version: LONGINT; CONST workName: ARRAY OF CHAR; VAR res : WORD );
	VAR resBody: XML.Document;
		reqBody: UpdateReq;
		resHeader: WebHTTP.ResponseHeader;
		out : Streams.Reader; res2 : WORD;
		txDelta: Files.File;
		repos : OdClient.Repos;
	BEGIN
		repos := client.GetRepos();
		globalVersion := version;

		NEW(reqBody, client, SELF, pathName, headVersion, version );
		repos.expand(vcc);
		repos.expand(pathName);
		OdClient.ShowMethodUrl(WebHTTP.ReportM, vcc);
		client.Report(vcc, "", reqBody, resHeader, out, res2);
		log.Enter; log.String("SvnDeltaV.UpdateReport. Statuscode="); log.Int(resHeader.statuscode, 4);  log.Exit;

		IF res = OdClient.Ok THEN (* don't execute XmlResult if there is an error *)
			resBody := client.XmlResult(resHeader, res, out); (* Read potential body. *)
			IF resBody # NIL THEN
				IF useSvn THEN
					svnUpdated := FALSE;
					SvnParseUpdate( resBody, workUrl, workName, res );
				ELSE
					ParseUpdate(resBody, txDelta);
					IF txDelta # NIL THEN
						TxDelta(txDelta, workUrl, workName);
					ELSE
						log.Enter; log.String("SvnDeltaV.UpdateReport: err = "); log.String("no txdelta file");  log.Exit;
					END;
				END;
			ELSE
				log.Enter; log.String("SvnDeltaV.UpdateReport: err = "); log.String("no result doc");  log.Exit;
			END;
		ELSE
			log.Enter; log.String( "Report Error: http error #" ); log.Int( res, 5 ); log.Ln; log.Exit;
		END;
		log.Enter; log.String( "" );  log.Exit;
	END UpdateReport;


	(* Update to a local workspace. Temporary HEAD checked out in subversion workspace.*)
	PROCEDURE Update* ( context: Commands.Context ); (* <pathname> <version number> <workname>
	Get "/repos/svn1/Svn.Text 30 Svn13.txt ~
	Checked out version: /repos/!svn/wrk/1/svn1/Neu.txt *)
	VAR
		pathName, path, collUrl, name, workName, workUrl, vcc, ver, err: ARRAY 256 OF CHAR;
		resHeader: WebHTTP.ResponseHeader;
		version,headVersion: LONGINT; pos: SIZE; res: WORD;
		props: WebHTTP.AdditionalField;
		act: Activity;
	BEGIN
		log.Enter; log.String( "" );  log.Exit;
		log.Enter; log.String( "" );  log.Exit;
		log.Enter; log.String( "***** UPDATE *****" );  log.Exit;
		log.Enter; log.String( "" );  log.Exit;

		context.arg.SkipWhitespace; context.arg.String( pathName );
		context.arg.SkipWhitespace; context.arg.Int( version, FALSE );
		context.arg.SkipWhitespace; context.arg.String( workName );

		IF context.arg.res = Commands.Ok THEN
			err := ""; res := 0;
			NEW(act, client, "1"); act.make();
			  IF act.url = NIL THEN RETURN; END;
			(* Get collection HEAD *)
			Files.SplitPath(pathName, path, name);
			CollHead(path, collUrl);
			log.Enter; log.String("CollUrl = ");  log.String(collUrl); log.Exit;
			(* Get resource HEAD *)
			Propfind(pathName, "D:checked-in", props, err);
			IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:checked-in", ver) THEN END;
			Checkout(ver, resHeader, err);
			COPY(resHeader.location, workUrl);
			log.Enter; log.String("workUrl = ");  log.String(workUrl); log.Exit;
			(* Find header version to request the correct difference *)
			U.Delete(ver, 0, U.Length("/repos/!svn/ver/"));
			U.StrToIntPos(ver, headVersion, pos);
			log.Enter; log.String("headVersion = ");  log.Int(headVersion, 5); log.Exit;
			(* Get update record *)
			Propfind(pathName, "D:version-controlled-configuration", props, err);
			IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:version-controlled-configuration", vcc) THEN END;
			UpdateReport(pathName, vcc, workUrl, headVersion, version, workName, res);
			(* Cleanup/close Subversion workspace. *)
			act.delete();
		ELSE
			log.Enter; log.String("SvnDeltaV.Update: parameter error.");  log.Exit;
		END;
		log.Enter; log.String( "" );  log.Exit;
	END Update;






	(** Parse subversion log-report.
	<S:log-report xmlns:S="svn:">
	<?xml version="1.0" encoding="utf-8"?>
	<S:log-report xmlns:S="svn:" xmlns:D="DAV:">
	<S:log-item>
		<D:version-name>18</D:version-name>
		<S:date>2006-09-23T13:12:38.375000Z</S:date>
		<S:added-path>/svn1/Svn.Text</S:added-path>
	</S:log-item>
	<S:log-item> *)
	PROCEDURE ParseVersions(url: ARRAY OF CHAR; doc: XML.Document;  VAR versions: OdUtil.Dict);
	VAR
		root, item, versionName, comment, path: XML.Element;
		items: XMLObjects.Enumerator;
		p: ANY; s: XML.String;
		dataChars, versionChars, pathData: ARRAY 256 OF CHAR; (* Change to str^ to avoid big array ? *)
		logItem: LogItem;
		repos : OdClient.Repos;
	BEGIN
		repos := client.GetRepos();
		root := doc.GetRoot();
		IF root # NIL THEN
			U.Delete(url, 0, U.Length(repos.path)); (* Make it simple for now. *)
			(*log.Enter; log.String("url=");  log.String(url); log.Exit;*)
			s := root.GetName();
			IF xml.EqualName(s, "S:log-report") THEN
				xml.xmlns := NIL;
				xml.GetXmlns(root);
				items := root.GetContents();
				WHILE items.HasMoreElements() DO
					p := items.GetNext();
					item :=  p(XML.Element);
					IF item # NIL THEN
						xml.GetXmlns(item);
						NEW(logItem);
						path  := xml.FindElement(item, "svn:added-path");
						IF path # NIL THEN
							OdXml.GetCharData(path, pathData);
							logItem.addedPath := U.NewString(pathData);
							(*log.Enter; log.String("svn:added-path = ");  log.String(pathData); log.Exit;*)
						ELSE
							path  := xml.FindElement(item, "svn:modified-path");
							IF path # NIL THEN
								OdXml.GetCharData(path, pathData);
								logItem.modifiedPath := U.NewString(pathData);
								(*log.Enter; log.String("svn:modified-path = ");  log.String(pathData); log.Exit;*)
							END;
						END;
						IF path # NIL THEN
							(*log.Enter; log.String("svn:*-path = ");  log.String(pathData); log.Exit;*)
							IF pathData = url THEN
								IF versions = NIL THEN NEW(versions); END;
								versionName  := xml.FindElement(item, "DAV:version-name");
								IF versionName # NIL THEN
									OdXml.GetCharData(versionName, versionChars);
									logItem.versionName := U.NewString(versionChars);
									(* log.Enter; log.String("DAV:version-name = ");  log.String(versionChars); log.Exit; *)
								END;
								comment := xml.FindElement(item, "DAV:comment");
								IF comment # NIL THEN
									OdXml.GetCharData(comment, dataChars);
									logItem.comment := U.NewString(dataChars);
									(* log.Enter; log.String("DAV:comment = ");  log.String(dataChars); log.Exit; *)
								END;
								versions.set(versionChars, logItem);
							END;
						END;
					END;
				END;
			ELSE
				log.Enter; log.String("SvnDeltaV.ParseVersions unexpected root name:" );  log.String(s^); log.Exit;
				xml.LogDoc("S:log-report not found", doc);
			END
		ELSE
			log.Enter; log.String("SvnDeltaV.ParseVersions: doc.root not found");  log.Exit;
		END
	END ParseVersions;

	(*
	REPORT /repos/!svn/bc/18
	Host: 192.168.178.23
	User-Agent: SVN/1.2.3 (r15833) neon/0.24.7
	Connection: TE
	TE: trailers
	Content-Length: 161
	Content-Type: text/xml

	<S:log-report xmlns:S="svn:">
	<?xml version="1.0" encoding="utf-8"?>
	<S:log-report xmlns:S="svn:" xmlns:D="DAV:">
	<S:log-item>
		<D:version-name>18</D:version-name>
		<S:date>2006-09-23T13:12:38.375000Z</S:date>
		<S:added-path>/svn1/Svn.Text</S:added-path>
	</S:log-item>
	<S:log-item>

	*)
	PROCEDURE LogReport(CONST url:ARRAY OF CHAR; bc: ARRAY OF CHAR; start, end: LONGINT);
	VAR resBody: XML.Document;
		reqBody: LogReq;
		resHeader: WebHTTP.ResponseHeader;
		out : Streams.Reader; res : WORD;
		versions: OdUtil.Dict; logItem: LogItem;
		repos : OdClient.Repos;
	BEGIN
		repos := client.GetRepos();
		NEW(reqBody, start, end);
		repos.expand(bc);
		OdClient.ShowMethodUrl(WebHTTP.ReportM, bc);
		client.Report(bc, "", reqBody, resHeader, out, res);
		(*log.Enter; log.String("SvnDeltaV.LogReport. Statuscode="); log.Int(resHeader.statuscode, 4);  log.Exit;*)
		resBody := client.XmlResult(resHeader, res, out); (* Read potential body. *)
		IF resBody # NIL THEN
			OdUtil.Msg3("url", ": ", url);
			versions := NIL;
			ParseVersions(url, resBody, versions);
			WHILE versions # NIL DO
				logItem := versions.value(LogItem);
				IF logItem.comment # NIL THEN
					OdUtil.Msg3(versions.key, ": ", logItem.comment^);
				ELSE
					OdUtil.Msg3(versions.key, ": ", "no comment");
				END;
				versions := versions.next;
			END;
		ELSE
			log.Enter; log.String("SvnDeltaV.LogReport: err = "); log.String("no result doc");  log.Exit;
		END;
	END LogReport;


	(** Automatically do a commit afterwards.
	Etherreal trace  Manual stuff from es.Win32.WebDAV.Tool
	*)
	PROCEDURE Add* ( context: Commands.Context );
	(*CONST
		Repo = "/repos";
		ActivityName = "1"; (* Default for now. Make it a timestamp or tag ? *)
		SvnBase = "/repos/!svn";
		SvnWrk = "/repos/!svn/wrk";*)
	VAR
		pathName, path, name, collUrl, resUrl, repoWorkName, workName,
		vcc, ci, s1, s2, err: ARRAY 256 OF CHAR;
		act: Activity;
		logText: ARRAY 256 OF CHAR; lenStr: ARRAY 16 OF CHAR;
		resHeader: WebHTTP.ResponseHeader; doc: XML.Document;
		reqHeader: WebHTTP.RequestHeader;
		in: Files.Reader; out : Streams.Reader; res: WORD;
		props: WebHTTP.AdditionalField;
		root: XML.Element; s: XML.String;
		f: Files.File;
		repos : OdClient.Repos;
	BEGIN
		log.Enter; log.String( "" );  log.Exit;
		log.Enter; log.String( "" );  log.Exit;
		log.Enter; log.String( "***** ADD *****" );  log.Exit;
		log.Enter; log.String( "" );  log.Exit;

		repos := client.GetRepos();

		context.arg.SkipWhitespace; context.arg.String( pathName );
		context.arg.SkipWhitespace; context.arg.String( workName );
		context.arg.SkipWhitespace; context.arg.String( logText );
		IF context.arg.res = Commands.Ok THEN
			(* create a fixed activity (For now) /repos/!svn/act/1" *)
			NEW(act, client, "1"); act.make();
			   IF act.url = NIL THEN RETURN; END;
			(* DCT.Propfind "/repos/svn1" "0" "D:version-controlled-configuration" ~ /repos/!svn/vcc/default *)
			Files.SplitPath(pathName, path, name);
			COPY(path, collUrl);
			repos.expand(collUrl);
			Propfind(collUrl, "D:version-controlled-configuration", props, err);
			IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:version-controlled-configuration", vcc) THEN END;
			(**        Checkout the version controlled configuration.       **)
			(* DCT.Propfind "/repos/!svn/vcc/default" "0" "D:checked-in" ~ /repos/!svn/bln/13 *)
			Propfind(vcc, "D:checked-in", props, err);
			IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:checked-in", ci) THEN END;
			(* DCT.Checkout "/repos/!svn/bln/13" ~ Location = /repos/!svn/wbl/1/13 has been created. *)
			repos.expand(ci);
			OdClient.ShowMethodUrl(WebHTTP.CheckoutM, ci);
			client.Checkout(ci, resHeader, out, res);
			log.Enter; log.String("SvnDeltaV.Get: checkout. Statuscode="); log.Int(resHeader.statuscode, 4);  log.Exit;
			doc := client.XmlResult(resHeader, res, out);
			IF doc # NIL THEN
				LOOP
					root := doc.GetRoot();
					s := root.GetName();
					IF s^ # "D:error" THEN
						xml.LogDoc("OdClient.Checkout: Unexpected root element = ", doc);
						EXIT;
					END;
					OdXml.GetCharData(root,  s1);
					s2 := "DAV:error = "; U.Append(s1, s2);
					log.Enter; log.String(s2);  log.Exit;
					EXIT;
				END;
			END;
			log.Enter; log.String("resHeader.location="); log.String(resHeader.location); log.Ln;  log.Exit;
			(* DCT.SetProp "/repos/!svn/wbl/1/13" log="Das ist ein Log" ~ *)
			COPY(resHeader.location, resUrl);
			props := NIL;
			WebHTTP.SetAdditionalFieldValue(props, 'log xmlns=http://subversion.tigris.org/xmlns/svn/' , logText);
			OdClient.ShowMethodUrl(WebHTTP.ProppatchM, resUrl);
			client.Proppatch(resUrl, "set", props, resHeader, out, res);
			doc := client.XmlResult(resHeader, res, out);
			IF doc # NIL THEN
				LOOP
					root := doc.GetRoot();
					s := root.GetName();
					IF s^ # "D:error" THEN
						xml.LogDoc("OdClient.Set|RemProp: unexpected root element in ", doc);
						EXIT;
					END;
					OdXml.GetCharData(root,  resUrl);
					err := "DAV:error = "; U.Append(err, resUrl);
					log.Enter; log.String(err);  log.Exit;
					EXIT;
				END;
			END;
			(**                                    Checkout the target collection.                                       **)
			(* DCT.Propfind "/repos/svn1" "0" "D:checked-in"~ /repos/!svn/ver/13/svn1 *)
			(* collUrl prepared before *)
			Propfind(collUrl, "D:checked-in", props, err);
			IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:checked-in", ci) THEN END;
			(* DCT.Checkout "/repos/!svn/ver/13/svn1" ~  Checked-out res /repos/!svn/wrk/1/svn1 created *)
			repos.expand(ci);
			OdClient.ShowMethodUrl(WebHTTP.CheckoutM, ci);
			client.Checkout(ci, resHeader, out, res);
			log.Enter; log.String("SvnDeltaV.Get: checkout. Statuscode="); log.Int(resHeader.statuscode, 4);  log.Exit;
			doc := client.XmlResult(resHeader, res, out);
			IF doc # NIL THEN
				LOOP
					root := doc.GetRoot();
					s := root.GetName();
					IF s^ # "D:error" THEN
						xml.LogDoc("OdClient.Checkout: Unexpected root element = ", doc);
						EXIT;
					END;
					OdXml.GetCharData(root,  s1);
					s2 := "DAV:error = "; U.Append(s1, s2);
					log.Enter; log.String(s2);  log.Exit;
					EXIT;
				END;
			END;
			(* DCT.Put "/repos/!svn/wrk/1/svn1/Neu.txt" Neu.txt ~ *)
			Files.JoinPath(resHeader.location, name, repoWorkName);
			f := Files.Old(workName);
			IF f # NIL THEN
				NEW(in, f, 0);
				WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Type", "application/octet-stream");
				U.IntToStr(f.Length(), lenStr);
				WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Length", lenStr);
				OdClient.ShowMethodUrl(WebHTTP.PutM, repoWorkName);
				client.Put(repoWorkName, reqHeader, resHeader, out, in, res);
				doc := client.XmlResult(resHeader, res, out);
				IF doc # NIL THEN
					LOOP (*  *)
						root := doc.GetRoot();
						s := root.GetName();
						IF s^ # "D:error" THEN
							xml.LogDoc("OdClient.Put: Unexpected root element = ", doc);
							EXIT;
						END;
						OdXml.GetCharData(root,  s1);
						s2:= "DAV:error = "; U.Append(s2, s1);
						log.Enter; log.String(s2);  log.Exit;
						EXIT;
					END;
				END;
			ELSE
				log.Enter; log.String("File not found: "); log.String(workName);  log.Exit;
			END;
			Merge(path, act.url, resHeader, err);
			act.delete();
		ELSE
			log.Enter; log.String("SvnDeltaV.Get: parameter error.");  log.Exit;
		END;
	END Add;

	(** Commit a new version to a svn repository.
	Etherreal trace  Manual stuff from es.Win32.WebDAV.Tool
	*)
	PROCEDURE Commit* ( context: Commands.Context );(* <pathname>  <workname> "log>"
	Commit "/repos/svn1/Neu.txt" Neu13.txt "This is the final version." ~ pathname with repository path.
	Checked out version: /repos/!svn/wrk/1/svn1/Neu.txt *)
	(*CONST
		Repo = "/repos";
		SvnBase = "/repos/!svn";
		SvnWrk = "/repos/!svn/wrk";*)
	VAR
		pathName, path, name, collUrl, workName, repoWorkName,
		ver, s1, s2, err: ARRAY 265 OF CHAR;
		act: Activity;
		logText: ARRAY 256 OF CHAR;
		lenStr: ARRAY 32 OF CHAR;
		resHeader: WebHTTP.ResponseHeader; doc: XML.Document;
		reqHeader: WebHTTP.RequestHeader;
		out : Streams.Reader; res: WORD;
		props: WebHTTP.AdditionalField;
		root: XML.Element; s: XML.String;
		f: Files.File; in: Files.Reader;
	BEGIN
		log.Enter; log.String( "" );  log.Exit;
		log.Enter; log.String( "" );  log.Exit;
		log.Enter; log.String( "***** COMMIT *****" );  log.Exit;
		log.Enter; log.String( "" );  log.Exit;

		context.arg.SkipWhitespace; context.arg.String( pathName );
		context.arg.SkipWhitespace; context.arg.String( workName );
		context.arg.SkipWhitespace; context.arg.String( logText );
		IF context.arg.res = Commands.Ok THEN
			NEW(act, client, "1"); act.make();
			   IF act.url = NIL THEN RETURN; END;
			Files.SplitPath(pathName, path, name);
			CollHead(path, collUrl);
			props := NIL;
			WebHTTP.SetAdditionalFieldValue(props, 'log xmlns=http://subversion.tigris.org/xmlns/svn/' , logText);
			Proppatch(collUrl, props, err);
			(* This will get the newest version. NO other versions seems to be allowed for checkout here by Subversion. *)
			Propfind(pathName, "D:checked-in", props, err);
			IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:checked-in", ver) THEN END;
			(* DCT.Checkout "/repos/!svn/ver/13/svn1/Neu.txt" ~  Checked-out res /repos/!svn/wrk/1/svn1/Neu.txt created *)
			Checkout(ver, resHeader, err);
			(* DCT.Put "/repos/!svn/wrk/1/svn1/Neu.txt" Neu.txt ~ *)
			COPY(resHeader.location, repoWorkName);
			f := Files.Old(workName);
			IF f # NIL THEN
				NEW(in, f, 0);
				WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Type", "application/octet-stream");
				U.IntToStr(f.Length(), lenStr);
				WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Length", lenStr);
				OdClient.ShowMethodUrl(WebHTTP.PutM, repoWorkName);
				client.Put(repoWorkName, reqHeader, resHeader, out, in, res);
				doc := client.XmlResult(resHeader, res, out);
				IF doc # NIL THEN
					LOOP
						root := doc.GetRoot();
						s := root.GetName();
						IF s^ # "D:error" THEN
							xml.LogDoc("OdClient.Put: Unexpected root element = ", doc);
							EXIT;
						END;
						OdXml.GetCharData(root,  s1);
						s2:= "DAV:error = "; U.Append(s2, s1);
						log.Enter; log.String(s2);  log.Exit;
						EXIT;
					END;
				END;
			ELSE
				log.Enter; log.String("File not found: "); log.String(workName);  log.Exit;
			END;
			Merge(path, act.url, resHeader, err);
			act.delete();
		ELSE
			log.Enter; log.String("SvnDeltaV.Commit: parameter error.");  log.Exit;
		END;
		log.Enter; log.String( "" );  log.Exit;
	END Commit;

	(* Create a checked out HEAD working collection URL (add+commit) *)
	PROCEDURE CollHead(CONST path: ARRAY OF CHAR; VAR resUrl: ARRAY OF CHAR);
	VAR props: WebHTTP.AdditionalField;
		vcc, bln, err: ARRAY 265 OF CHAR;
		resHeader: WebHTTP.ResponseHeader;
	BEGIN
			Propfind(path, "D:version-controlled-configuration", props, err);
			IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:version-controlled-configuration", vcc) THEN END;
			(* DCT.Propfind "/repos/!svn/vcc/default" "0" "D:checked-in" ~ /repos/!svn/bln/13 *)
			Propfind(vcc, "D:checked-in", props, err);
			IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:checked-in", bln) THEN END;
			(* DCT.Checkout "/repos/!svn/bln/13" ~ /repos/!svn/wbl/1/13 has been created. *)
			Checkout(bln, resHeader, err);
			COPY(resHeader.location, resUrl);
	END CollHead;

	(* Hide checkout stuff in a procedure.  *)
	PROCEDURE Checkout*(url: ARRAY OF CHAR; VAR resHeader: WebHTTP.ResponseHeader; CONST err: ARRAY OF CHAR);
	VAR doc: XML.Document;
		out : Streams.Reader; res: WORD;
		root: XML.Element; s: U.String;
		s1, s2: ARRAY 256 OF CHAR;
		repos : OdClient.Repos;
	BEGIN
		(* Check for error state. *)
		IF err # "" THEN RETURN; END;
		repos := client.GetRepos();
		(* Patch url. *)
		IF U.Pos("http://", url) # 0 THEN repos.expand(url); END;
		OdClient.ShowMethodUrl(WebHTTP.CheckoutM, url);
		client.Checkout(url, resHeader, out, res);
		log.Enter; log.String("SvnDeltaV.Checkout. Statuscode="); log.Int(resHeader.statuscode, 4);  log.Exit;
		doc := client.XmlResult(resHeader, res, out);
		IF doc # NIL THEN
			LOOP
				root := doc.GetRoot();
				s := root.GetName();
				IF s^ # "D:error" THEN
					xml.LogDoc("OdClient.Checkout: Unexpected root element = ", doc);
					EXIT;
				END;
				OdXml.GetCharData(root,  s1);
				s2 := "DAV:error = "; U.Append(s1, s2);
				log.Enter; log.String(s2);  log.Exit;
				EXIT;
			END;
		END;
		log.Enter; log.String( "" );  log.Exit;
	END Checkout;

	PROCEDURE Proppatch*(url: ARRAY OF CHAR; VAR props: WebHTTP.AdditionalField;  CONST err: ARRAY OF CHAR);
	VAR resHeader: WebHTTP.ResponseHeader;
		doc: XML.Document;
		out : Streams.Reader; res: WORD;
		root: XML.Element; s: U.String;
		s1: ARRAY 256 OF CHAR;
		repos : OdClient.Repos;
	BEGIN
		(* Check for error state. *)
		IF err # "" THEN RETURN; END;
		repos := client.GetRepos();
		(* Patch url. *)
		IF U.Pos("http://", url) # 0 THEN repos.expand(url); END;
		OdClient.ShowMethodUrl(WebHTTP.ProppatchM, url);
		client.Proppatch(url, "set", props, resHeader, out, res);
		doc := client.XmlResult(resHeader, res, out);
		IF doc # NIL THEN
			IF useSvn THEN
				props := NIL;
				client.ParseProps(doc, props);
			ELSE
				LOOP
					root := doc.GetRoot();
					s := root.GetName();
					IF s^ # "D:error" THEN
						xml.LogDoc("OdClient.Set|RemProp: unexpected root element in ", doc);
						EXIT;
					END;
					OdXml.GetCharData(root,  url);
					s1 := "DAV:error = "; U.Append(s1, url);
					log.Enter; log.String(s1);  log.Exit;
					EXIT;
				END;
			END;
		END;
		log.Enter; log.String( "" );  log.Exit;
	END Proppatch;

	(* Hide merge stuff.  *)
	PROCEDURE Merge*(url: ARRAY OF CHAR; actUrl: U.String; VAR resHeader: WebHTTP.ResponseHeader; CONST err: ARRAY OF CHAR);
	VAR doc: XML.Document;
		out : Streams.Reader; res: WORD;
		root: XML.Element; s: U.String;
		s1, s2: ARRAY 265 OF CHAR;
		repos : OdClient.Repos;
	BEGIN
		(* Check for error state. *)
		IF err # "" THEN RETURN; END;
		repos := client.GetRepos();
		(* Patch url. *)
		IF U.Pos("http://", url) # 0 THEN repos.expand(url); END;
		OdClient.ShowMethodUrl(WebHTTP.MergeM, url);
		client.Merge(url, actUrl^, resHeader, out, res);
		doc := client.XmlResult(resHeader, res, out);
		IF doc # NIL THEN
			IF useSvn THEN
				resultDoc := doc;
			ELSE
				LOOP (*  *)
					root := doc.GetRoot();
					s := root.GetName();
					IF s^ # "D:error" THEN
						xml.LogDoc("OdClient.Merge: Unexpected root element = ", doc);
						EXIT;
					END;
					OdXml.GetCharData(root,  s1);
					s2 := "DAV:error = "; U.Append(s2, s1);
					log.Enter; log.String(s2);  log.Exit;
					EXIT;
				END;
			END;
		END;
		log.Enter; log.String( "" );  log.Exit;
	END Merge;

	PROCEDURE SvnWrite ( parent : XML.Element; CONST path, filename, version : ARRAY OF CHAR; added : BOOLEAN; VAR res : WORD );
	VAR
		enum: XMLObjects.Enumerator;
		p: ANY;
		e, e2: XML.Element;
		s, attr, rev : XML.String;
		c : XMLObjects.Enumerator;
		ar : XML.ArrayChars;
		path2, src, dest, tmp : ARRAY 256 OF CHAR;
		checkedin : ARRAY 256 OF CHAR;
		writeProps, overwrite : BOOLEAN;
		props : SvnProps;
		strRdr : StringReader;
		wtr: Files.Writer;
		f : Files.File;
		res2 : WORD;
		str : U.String;
		data : SVNAdmin.EntryEntity;
		w : Files.Writer;
		searcher : SVNUtil.FSItemSearch;
	BEGIN
		IF parent = NIL THEN RETURN END;

		NEW ( props );
		props.add := added;
		writeProps := FALSE;

		enum := parent.GetContents();
		WHILE enum.HasMoreElements() DO
			IF res # 0 THEN RETURN END;

			p := enum.GetNext();
			IF p IS XML.Element THEN
				e := p(XML.Element); s := e.GetName();
				IF s # NIL THEN
					IF xml.EqualName ( s, "svn:open-directory" ) OR xml.EqualName ( s, "svn:add-directory" ) THEN
						attr := e.GetAttributeValue ( "name" );
						IF attr # NIL THEN
							Files.JoinPath ( path, attr^, path2 );
						ELSE
							COPY ( path, path2 );
						END;

						IF writeProps THEN
							writeProps := FALSE;
							SvnWritePROPS ( path, filename, props );
						END;

						added := xml.EqualName ( s, "svn:add-directory" );
						IF added THEN
							NEW ( searcher );
							searcher.Open ( path2, {Files.Directory} );
							IF searcher.Exists () THEN
								res := SVNOutput.ResADDDIRECTORYEXISTS;
								COPY ( path2, errorMsg );
								RETURN;
							END;

							(* create directory and add it in the entries file *)
							Files.CreateDirectory ( path2, res2 ); ASSERT ( res2 = 0 );
							SVNAdmin.CreateDirectory ( path2 );

							context.out.String ( "A " ); context.out.String ( path2 ); context.out.Ln;

							COPY ( attr^, data.Name );
							data.NodeKind := "dir";

							Files.JoinPath ( path, ".svn/entries", tmp );
							f := Files.Old ( tmp );
							ASSERT ( f # NIL );

							SVNAdmin.RemoveFileAttribute2 ( tmp, f );

							Files.OpenWriter ( w, f, f.Length() );
							SVNAdmin.Write ( w, data );

							SVNAdmin.SetFileAttribute2 ( tmp, f );

							svnUpdated := TRUE;
						END;

						SvnWrite ( e, path2, "", "0", added, res );

					ELSIF xml.EqualName ( s, "svn:open-file" ) OR xml.EqualName ( s, "svn:add-file" ) THEN
						attr := e.GetAttributeValue ( "name" );
						ASSERT ( attr # NIL );

						IF writeProps THEN
							writeProps := FALSE;
							SvnWritePROPS ( path, filename, props );
						END;

						added := xml.EqualName ( s, "svn:add-file" );

						IF added THEN
							Files.JoinPath ( path, ".svn/text-base", src );
							Files.JoinPath ( src, attr^, src );
							U.Append ( src, ".svn-base" );

							f := Files.New ( src );
							Files.Register ( f );

							NEW ( rev, 2 );
							rev^ := "0";
						ELSE
							rev := e.GetAttributeValue ( "rev" );
							ASSERT ( rev # NIL );
						END;

						SvnWrite ( e, path, attr^, rev^, added, res );

					ELSIF xml.EqualName ( s, "DAV:checked-in" ) THEN (* DONE *)
						e2 := xml.SplitElement ( e, "DAV:href" );
						ASSERT ( e2 # NIL );

						OdXml.GetCharData(e2, checkedin);

						SVNAdmin.WriteWCPROPS ( path, filename, checkedin );

					ELSIF xml.EqualName ( s, "svn:set-prop" ) THEN (* DONE *)
						attr := e.GetAttributeValue ( "name" );
						ASSERT ( attr # NIL );

						c := e.GetContents();
						p := c.GetNext();
						ASSERT ( p IS XML.ArrayChars );

						ar := p (XML.ArrayChars);
						s := ar.GetStr();
						ASSERT ( s # NIL );

						writeProps := TRUE;

						IF attr^ = "svn:entry:committed-date" THEN
							COPY ( s^, props.date );
						ELSIF attr^ = "svn:entry:last-author" THEN
							COPY ( s^, props.author );
						ELSIF attr^ = "svn:entry:uuid" THEN
							COPY ( s^, props.uuid );
						ELSIF attr^ = "svn:entry:committed-rev" THEN
							COPY ( s^, props.revision );
						END;

					ELSIF xml.EqualName ( s, "svn:txdelta" ) THEN
						c := e.GetContents();
						p := c.GetNext();
						ASSERT ( p IS XML.ArrayChars );

						ar := p (XML.ArrayChars);
						NEW(strRdr, ar.GetStr() );

						f := Files.New("");
						NEW(wtr, f, 0);
						IF DecodeIO(strRdr, wtr) THEN
							wtr.Update();

							Files.JoinPath ( path, ".svn/text-base", src );
							Files.JoinPath ( src, filename, src );
							U.Append ( src, ".svn-base" );

							Files.JoinPath ( path, filename, dest );

							IF Files.Old ( dest ) # NIL THEN
								IF props.add THEN
									COPY ( dest, errorMsg );
									res := SVNOutput.ResUPDATEFILEALREADYEXISTS;
									RETURN;
								END;

								IF ~SVNAdmin.CheckChecksum ( src ) THEN
									KernelLog.String ( "checksum of file: " );
									KernelLog.String ( src );
									str := SVNUtil.GetChecksum ( src );
									KernelLog.String ( " was '" ); KernelLog.String ( str^ ); KernelLog.String ( "' expected '" );
									str := SVNAdmin.ReadChecksum ( src );
									KernelLog.String ( str^ ); KernelLog.String ( "'." ); KernelLog.Ln;

									COPY ( src, errorMsg );
									(*errorMsg := "";*)
									res := SVNOutput.ResCHECKSUMMISMATCH;
									RETURN;
								END;

								IF ~SVNAdmin.CheckChecksum ( dest ) THEN (* local modifications *)
									(* TODO try to merge new changes *)
									context.out.String ( "C " ); context.out.String ( dest ); context.out.Ln;

									(* prev revision *)
									U.Concat ( dest, ".r", tmp );
									U.Concat ( tmp, version, tmp ); (* TODO get version from entriesfile *)
									overwrite := FALSE;
									Files.CopyFile ( src, tmp, overwrite, res2 );

									(* mine revision *)
									U.Concat ( dest, ".mine", tmp );
									overwrite := FALSE;
									Files.CopyFile ( dest, tmp, overwrite, res2 );

									(* next revision *)
									U.Append ( dest, ".r" );
									U.Append ( dest, props.revision );
								ELSE
									context.out.String ( "U " );
									context.out.String ( dest ); context.out.Ln;
								END;
							ELSE
								ASSERT ( props.add );

								context.out.String ( "A " );
								context.out.String ( dest ); context.out.Ln;
							END;

							SVNAdmin.RemoveFileAttribute ( src );

							svnUpdated := TRUE;

							TxDelta ( f, src, dest );

							(* update the svn-base file *)
							overwrite := TRUE;
							Files.CopyFile ( dest, src, overwrite, res2 );

							SVNAdmin.SetFileAttribute ( src );
						ELSE
							log.Enter; log.String("txdelta error on decoding"); log.Exit;
						END;

					ELSIF xml.EqualName ( s, "svn:prop" ) THEN (* DONE *)
						e2 := xml.FindElement ( e, "http://subversion.tigris.org/xmlns/dav/md5-checksum" );
						IF e2 # NIL THEN
							OdXml.GetCharData(e2, props.checksum);
						END;
					END;
				END;
			END
		END;

		IF writeProps THEN
			writeProps := FALSE;
			SvnWritePROPS ( path, filename, props );
		END;
	END SvnWrite;

	PROCEDURE SvnParseUpdate(doc: XML.Document; CONST workUrl, workName : ARRAY OF CHAR; VAR res : WORD );
	VAR
		s : XML.String;
		root, e : XML.Element;
		elPath: ARRAY 256 OF CHAR;
		str : U.String;
		m : SVNOutput.Message;
	BEGIN
		NEW ( str, 256 );

		root := doc.GetRoot();
		IF root # NIL THEN
			s := root.GetName();
			IF xml.EqualName( s, "S:update-report") THEN
				xml.xmlns := NIL;
				xml.GetXmlns(root);

				IF useUpdateTarget THEN
					Files.SplitPath ( workName, elPath, str^ );
				ELSE
					COPY ( workName, elPath );
				END;

				e := xml.SplitElement ( root, "svn:target-revision" );
				ASSERT ( e # NIL );
				str := e.GetAttributeValue ( "rev" );
				COPY ( str^, nextVersion );

				SvnWrite ( root, elPath, "", "0", FALSE, res );

				NEW ( m, context );
				m.Print ( res, errorMsg ); (* print now with the specific errorMsg *)
				res := 0;
			ELSE
				log.Enter; log.String("SvnDeltaV.ParseUpdate unexpected root name:" );  log.String(s^); log.Exit;
				xml.LogDoc("DAV:update-report not found", doc);
			END;
		ELSE
			log.Enter; log.String("SvnDeltaV.ParseUpdate: doc.root not found");  log.Exit;
		END;
		log.Enter; log.String( "" );  log.Exit;
	END SvnParseUpdate;



	(* TODO REFACTOR: SVNAdmin *)
	PROCEDURE SvnWritePROPS ( CONST path, filename : ARRAY OF CHAR; props : SvnProps );
	VAR
		tmp,fstr,fstr2 : ARRAY 256 OF CHAR;
		i: LONGINT; res: WORD;
		len: SIZE;
		fr, fw : Files.File;
		r : Files.Reader;
		w : Files.Writer;
		overwrite, nextFileEntry : BOOLEAN;
		adminEntry : SVNAdmin.Entry;
		data : SVNAdmin.EntryEntity;
		start: ARRAY 2 OF CHAR;
	BEGIN
		Files.JoinPath ( path, ".svn/entries", fstr );

		(*IF (filename = "") & props.add THEN*)
		IF (filename = "") & ~SVNUtil.FileExists ( fstr ) THEN
			IF ~checkout THEN
				(* get base and repository URL from parent .svn directory *)
				Files.SplitPath ( path, tmp, fstr2 );
				NEW ( adminEntry, NIL );
				adminEntry.SetPath ( tmp, res );
				adminEntry.ReadData ( res ); ASSERT ( res = SVNOutput.ResOK );
				adminEntry.GetUrl ( data.Url );
				Files.JoinPath ( data.Url, fstr2, data.Url );
				adminEntry.GetRepo ( data.RepositoryRoot );
			ELSE
				checkout := FALSE;
				COPY ( repositoryURL, data.Url );
				COPY ( repositoryURL, data.RepositoryRoot );
			END;


			(* add a new directory *)
			data.Revision := globalVersion;
			COPY ( props.date, data.LastChangedDate );
			U.StrToInt ( props.revision, data.LastChangedRevision );
			COPY ( props.author, data.LastChangedAuthor );
			COPY ( props.uuid, data.RepositoryUUID );

			fw := Files.New ( fstr );
			ASSERT ( fw # NIL );

			Files.OpenWriter ( w, fw, 0 );
			SVNAdmin.Write ( w, data );
			Files.Register ( fw );
		ELSE
			ASSERT ( ~( ( filename = "") & props.add) ); (* check old IF condition *)

			Files.JoinPath ( path, ".svn/tmp/od-entries", fstr2 );

			(* SVNAdmin.CreateTempFile *)
			(*overwrite := TRUE;
			Files.CopyFile ( fstr, fstr2, overwrite, res );
			ASSERT ( res = Files.Ok );

			fw := Files.Old ( fstr2 );
			ASSERT ( fw # NIL );*)

			IF SVNUtil.FileExists ( fstr2 ) THEN
				Files.Delete ( fstr2, res );
				ASSERT ( res = Files.Ok );
			END;
			fw := Files.New ( fstr2 );

			SVNAdmin.RemoveFileAttribute2 ( fstr2, fw );

			fr := Files.Old ( fstr );
			ASSERT ( fr # NIL );

			Files.OpenWriter ( w, fw, 0 );
			Files.OpenReader ( r, fr, 0 );

			IF filename = "" THEN
				(* we have a directory...add: committed-date (10), committed-rev (11), last-author (12), uuid (27) *)

				FOR i := 1 TO 3 DO
					r.Ln ( tmp );
					ASSERT ( r.res = Files.Ok );
					w.String ( tmp ); w.Char ( 0AX );
				END;

				w.Int ( globalVersion, 0 ); w.Char ( 0AX ); r.SkipLn;

				FOR i := 5 TO 9 DO
					r.Ln ( tmp );
					ASSERT ( r.res = Files.Ok );
					w.String ( tmp ); w.Char ( 0AX );
				END;

				w.String ( props.date ); w.Char ( 0AX ); r.SkipLn;
				w.String ( props.revision ); w.Char ( 0AX ); r.SkipLn;
				w.String ( props.author ); w.Char ( 0AX ); r.SkipLn;

				FOR i := 13 TO 26 DO
					r.Ln ( tmp );
					ASSERT ( r.res = Files.Ok );
					w.String ( tmp ); w.Char ( 0AX );
				END;

				w.String ( props.uuid ); w.Char ( 0AX ); r.SkipLn;
			ELSE
				(* we have a file... add: checksum (9), committed-date (10), committed-rev (11), last-author (12) *)
				nextFileEntry := FALSE;
				LOOP
					r.Ln ( tmp );

					IF r.res = Files.Ok THEN
						w.String ( tmp ); w.Char ( 0AX );

						IF nextFileEntry & (tmp = filename) THEN
							FOR i := 1 TO 6 DO
								r.Ln ( tmp );
								ASSERT ( r.res = Files.Ok );
								(* if we update a single file to a specific revision, we need to add the revision to line 4 *)
								IF (i = 2) & svnFileUpdate THEN w.String ( props.revision ) ELSE w.String ( tmp ) END;
								w.Char ( 0AX );
							END;

							w.String ( props.checksum ); w.Char ( 0AX ); r.SkipLn;
							w.String ( props.date ); w.Char ( 0AX ); r.SkipLn;
							w.String ( props.revision ); w.Char ( 0AX ); r.SkipLn;
							w.String ( props.author ); w.Char ( 0AX ); r.SkipLn;

							EXIT;
						END;
					ELSE
						(* didn't find the file..add a new entry *)
						COPY ( filename, data.Name );
						COPY ( props.checksum, data.Checksum );
						COPY ( props.date, data.LastChangedDate );
						COPY ( props.author, data.LastChangedAuthor );
						data.NodeKind := "file";
						U.StrToInt ( props.revision, data.LastChangedRevision );

						SVNAdmin.Write ( w, data );

						EXIT;
					END;
					start[0] := CHR(12); start[1] := 0X;
					nextFileEntry := U.StartsWith ( start, 0, tmp );
				END;
			END;

			(* copy the rest *)
			REPEAT
				r.Bytes ( tmp, 0, LEN(tmp), len );
				w.Bytes ( tmp, 0, len );
			UNTIL len < LEN(tmp);

			w.Update;

			SVNAdmin.RemoveFileAttribute2 ( fstr, fr );
			Files.Register ( fw );


			overwrite := TRUE;
			Files.CopyFile ( fstr2, fstr, overwrite, res );
			ASSERT ( res = Files.Ok );

			SVNAdmin.SetFileAttribute2 ( fstr, fr );
		END;

		SVNAdmin.SetFileAttribute ( fstr );
	END SvnWritePROPS;




END OdSvn;

	PROCEDURE InitTables;
		VAR i, max: INTEGER;
	BEGIN
		max := ORD("Z")-ORD("A");
		FOR i := 0 TO max DO
			encTable[i] := CHR(i+ORD("A"))
		END;
		INC(max);
		FOR i := max TO max+ORD("z")-ORD("a") DO
			encTable[i] := CHR(i-max+ORD("a"))
		END;
		max := max+ORD("z")-ORD("a")+1;
		FOR i := max TO max+ORD("9")-ORD("0") DO
			encTable[i] := CHR(i-max+ORD("0"))
		END;
		encTable[62] := "+";
		encTable[63] := "/";
		FOR i := 0 TO 127 DO
			decTable[i] := -1
		END;
		FOR i := 0 TO 63 DO
			decTable[ORD(encTable[i])] := i
		END
	END InitTables;



	(***            SVN Fragments.           ***)
















PROCEDURE RawNum(VAR delta: Files.Reader; VAR li: LONGINT);
VAR ch: CHAR;
BEGIN
	li := 0;
	REPEAT
		ch := delta.Get();
		li := 128 * li + (ORD(ch) MOD 128);
	UNTIL ch < 80X;
END RawNum;


BEGIN
	InitTables;
	log := OdClient.log;
END OdSvn.
