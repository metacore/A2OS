MODULE SVNWebDAV; (** AUTHOR "rstoll"; *)

IMPORT
	WebHTTP, Files, Strings, Streams, Dates,
	XML, XMLObjects,KernelLog,
	SVNAdmin, SVNUtil, SVNOutput,
	OdSvn, OdXml;


	PROCEDURE Checkout* (svn : OdSvn.OdSvn; CONST pathName : ARRAY OF CHAR; CONST workName : ARRAY OF CHAR; VAR res : WORD );
	VAR
		name, err, vcc, repoUUID, bln, bc, version, workUrl : ARRAY 256 OF CHAR;
		props: WebHTTP.AdditionalField;
		ver : LONGINT; pos : SIZE;
	BEGIN
		svn.checkout := TRUE;
		res := SVNOutput.ResOK;
		Files.SplitPath ( pathName, workUrl, name );

		svn.repositoryPathLength := 999; (* we don't want a update-target in the update request *)

		IF Files.Old ( workName ) = NIL THEN
			COPY ( pathName, workUrl );
			svn.FileUpdate ( FALSE );
		ELSE
			svn.FileUpdate ( TRUE );
		END;

		svn.Propfind ( workUrl, "D:version-controlled-configuration.D:resourcetype.D2:baseline-relative-path.D2:repository-uuid", props, err );

		IF (svn.pfStatus >= 400) OR (svn.pfStatus = 0) THEN
			PrintError ( svn, res );
			RETURN;
		END;

		IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:version-controlled-configuration", vcc) THEN END;
		IF ~WebHTTP.GetAdditionalFieldValue(props, "http://subversion.tigris.org/xmlns/dav/repository-uuid", repoUUID) THEN END;

		svn.Propfind ( vcc, "D:checked-in", props, err );
		IF ~WebHTTP.GetAdditionalFieldValue ( props, "DAV:checked-in", bln ) THEN END;

		svn.Propfind ( bln, "D:baseline-collection.D:version-name", props, err );
		IF ~WebHTTP.GetAdditionalFieldValue ( props, "DAV:baseline-collection", bc ) THEN END;
		IF ~WebHTTP.GetAdditionalFieldValue ( props, "DAV:version-name", version ) THEN END;

		IF err # "" THEN
			svn.context.out.String ( err ); svn.context.out.Ln;
			RETURN;
		END;

		Strings.StrToIntPos(version, ver, pos);

		svn.UpdateReport ( pathName, vcc, workUrl, -1, ver, workName, res );
		svn.checkout := FALSE;
	END Checkout;





	(* SVN update using .svn directories *)
	PROCEDURE Update* (svn : OdSvn.OdSvn; CONST pathName : ARRAY OF CHAR; pathNameVersion : LONGINT;  CONST workName : ARRAY OF CHAR; VAR res : WORD );
	VAR
		name, err, vcc, repoUUID, bln, bc, version, workUrl : ARRAY 256 OF CHAR;
		props: WebHTTP.AdditionalField;
		ver : LONGINT; pos : SIZE;
	BEGIN
		res := SVNOutput.ResOK;
		Files.SplitPath ( pathName, workUrl, name );

		IF Files.Old ( workName ) = NIL THEN
			COPY ( pathName, workUrl );
			svn.FileUpdate ( FALSE );
		ELSE
			svn.FileUpdate ( TRUE );
		END;

		svn.traverseDummy := TRUE; (* first call *)
		SVNAdmin.Traverse ( workName, UpdateHandler, svn, FALSE, res ); (* don't read the version url from wcprops *)

		svn.Propfind ( workUrl, "D:version-controlled-configuration.D:resourcetype.D2:baseline-relative-path.D2:repository-uuid", props, err );

		IF (svn.pfStatus >= 400) OR (svn.pfStatus = 0) THEN
			PrintError ( svn, res );
			RETURN;
		END;

		IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:version-controlled-configuration", vcc) THEN END;
		IF ~WebHTTP.GetAdditionalFieldValue(props, "http://subversion.tigris.org/xmlns/dav/repository-uuid", repoUUID) THEN END;

		svn.Propfind ( vcc, "D:checked-in", props, err );
		IF ~WebHTTP.GetAdditionalFieldValue ( props, "DAV:checked-in", bln ) THEN END;

		svn.Propfind ( bln, "D:baseline-collection.D:version-name", props, err );
		IF ~WebHTTP.GetAdditionalFieldValue ( props, "DAV:baseline-collection", bc ) THEN END;
		IF ~WebHTTP.GetAdditionalFieldValue ( props, "DAV:version-name", version ) THEN END;

		IF err # "" THEN
			svn.context.out.String ( err ); svn.context.out.Ln;
			RETURN;
		END;

		Strings.StrToIntPos(version, ver, pos);

		svn.UpdateReport ( pathName, vcc, workUrl, pathNameVersion, ver, workName, res );
	END Update;

	PROCEDURE Commit* ( svn : OdSvn.OdSvn; CONST pathName, workName, message : ARRAY OF CHAR; VAR res : WORD );
	VAR
		act: OdSvn.Activity;
		uuid : Strings.String;
		name, err, vcc, bln, workUrl, wbl : ARRAY 256 OF CHAR;
		props, patch : WebHTTP.AdditionalField;
		resHeader: WebHTTP.ResponseHeader;
	BEGIN
		uuid := SVNUtil.GetUUID();
		NEW ( act, svn.client, uuid^ );
		ASSERT ( act # NIL );
		act.make;

		IF act.getUrl() = NIL THEN
			svn.pfStatus := 0;
			PrintError ( svn, res );
			RETURN;
		END;

		Files.SplitPath ( pathName, workUrl, name );

		IF Files.Old ( workName ) = NIL THEN
			COPY ( pathName, workUrl );
		END;

		svn.Propfind ( workUrl, "D:version-controlled-configuration", props, err );
		IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:version-controlled-configuration", vcc) THEN END;

		IF (svn.pfStatus >= 400) OR (svn.pfStatus = 0) THEN
			PrintError ( svn, res );
			RETURN;
		END;

		svn.Propfind ( vcc, "D:checked-in", props, err );
		IF ~WebHTTP.GetAdditionalFieldValue ( props, "DAV:checked-in", bln ) THEN END;

		svn.Checkout ( bln, resHeader, err );
		COPY ( resHeader.location, wbl );

		WebHTTP.SetAdditionalFieldValue ( patch, "log xmlns=http://subversion.tigris.org/xmlns/svn/", message );
		svn.Proppatch ( wbl, patch, err );

		svn.Propfind ( workUrl, "D:checked-in", props, err );
		IF ~WebHTTP.GetAdditionalFieldValue(props, "DAV:checked-in", svn.ver) THEN END;

		svn.Checkout ( svn.ver, resHeader, err );
		COPY ( resHeader.location, svn.wrk );

		svn.removeDir := FALSE;
		svn.countChanges := 0;
		SVNAdmin.Traverse ( workName, CommitHandler, svn, TRUE, res );

		(* don't merge if there are no modified files *)
		IF svn.countChanges > 0 THEN
			svn.Merge ( workUrl, act.getUrl(), resHeader, err );
			IF resHeader.statuscode = 200 THEN
				ParseMergeContent ( svn, workUrl, workName );
			END;
		END;

		act.delete;
	END Commit;


	PROCEDURE ParseMergeContent ( svn : OdSvn.OdSvn; CONST baseUrl, basePath : ARRAY OF CHAR );
	VAR
		root, e, e2 : XML.Element;
		enum : XMLObjects.Enumerator;
		str, md5 : Strings.String;
		p : ANY;
		xml : OdXml.OdXml;
		vcc, vurl, ver, tmp, tmp2, path, name, date : ARRAY 256 OF CHAR;
		creationdate, creator, status : ARRAY 33 OF CHAR;
		version : ARRAY 10 OF CHAR;
		len, ft,fd : LONGINT; res: WORD;
		adminDir : SVNAdmin.Entry;
		f : Files.File;
	BEGIN
		NEW ( xml );
		NEW ( adminDir, NIL );

		root := svn.resultDoc.GetRoot();
		str := root.GetName();

		IF str^ # "D:merge-response" THEN RETURN END;

		enum := root.GetContents();
		IF ~enum.HasMoreElements() THEN RETURN END;

		p := enum.GetNext();
		e := p ( XML.Element );
		str := e.GetName();
		IF str^ # "D:updated-set" THEN RETURN END;

		enum := e.GetContents();
		IF ~enum.HasMoreElements() THEN RETURN END;

		p := enum.GetNext();
		e := p ( XML.Element );
		str := e.GetName();
		IF str^ # "D:response" THEN RETURN END;

		e2 := xml.SplitElement ( e, "DAV:href" );
		ASSERT ( e2 # NIL );

		OdXml.GetCharData ( e2, vcc );

		e2 := xml.SplitElement ( e, "DAV:propstat.DAV:prop.DAV:creationdate" ); ASSERT ( e2 # NIL );
		OdXml.GetCharData ( e2, creationdate );

		e2 := xml.SplitElement ( e, "DAV:propstat.DAV:prop.DAV:version-name" ); ASSERT ( e2 # NIL );
		OdXml.GetCharData ( e2, version );

		e2 := xml.SplitElement ( e, "DAV:propstat.DAV:prop.DAV:creator-displayname" ); ASSERT ( e2 # NIL );
		OdXml.GetCharData ( e2, creator );

		len := Strings.Length ( baseUrl );
		ASSERT ( ~Strings.EndsWith ( "/", basePath ) );

		WHILE enum.HasMoreElements() DO
			p := enum.GetNext();
			IF p IS XML.Element THEN
				e := p ( XML.Element );
				str := e.GetName();

				e2 := xml.SplitElement ( e, "DAV:href" ); ASSERT ( e2 # NIL );
				OdXml.GetCharData ( e2, vurl );

				(*e2 := xml.SplitElement ( e, "DAV:propstat.DAV:prop.DAV:resourcetype.DAV:collection" );
				IF e2 = NIL THEN
					(*KernelLog.String ( "NIL collection" );*)
				ELSE
					(*KernelLog.String ( "NOT NIL collection" );*)
				END;*)

				e2 := xml.SplitElement ( e, "DAV:propstat.DAV:prop.DAV:checked-in.DAV:href" ); ASSERT ( e2 # NIL );
				OdXml.GetCharData ( e2, ver );

				e2 := xml.SplitElement ( e, "DAV:propstat.DAV:status" ); ASSERT ( e2 # NIL );
				OdXml.GetCharData ( e2, status );

				IF Strings.Match ( "HTTP/1.? 200 OK", status ) THEN
					str := Strings.Substring2 ( len, vurl );
					SVNUtil.UrlDecode ( str^, tmp2 );
					Strings.Concat ( basePath, tmp2, tmp );

					adminDir.SetPath ( tmp, res ); ASSERT ( res = SVNOutput.ResOK );
					adminDir.CreateTempfile;

					f := Files.Old ( tmp );
					IF f # NIL THEN
						Files.SplitPath ( tmp, path, name );
						IF adminDir.IsItemVersioned ( name ) THEN
							adminDir.ReadWriteLines ( 1 );
							adminDir.ReadWriteString ( version );
							adminDir.ReadWriteLines ( 2 );
							adminDir.ReadWriteString ( "" ); (* remove scheduled stuff *)
							adminDir.ReadWriteString ( creationdate );
							md5 := SVNUtil.GetChecksum ( tmp );
							adminDir.ReadWriteString ( md5^ );
							f.GetDate ( ft, fd );
							Strings.FormatDateTime ( SVNOutput.DateFormat, Dates.OberonToDateTime ( fd, ft ), date );
							adminDir.ReadWriteString ( date );
							adminDir.ReadWriteString ( version );
							adminDir.ReadWriteString ( creator );
							adminDir.ReadWriteRest;
							adminDir.WriteUpdate;

							SVNAdmin.CopyToBaseFile ( tmp );

							SVNAdmin.WriteWCPROPS ( path, name, ver );
						ELSE
							svn.context.out.String ( "ERROR: received merge request, but item is not versioned" );
							svn.context.out.Ln;
						END;
					ELSE
						adminDir.ReadWriteLines ( 3 );
						adminDir.ReadWriteString ( version );
						adminDir.ReadWriteLines ( 2 );
						adminDir.ReadWriteString ( "" ); (* remove scheduled stuff *)
						adminDir.ReadWriteLines ( 2 );
						adminDir.ReadWriteString ( creationdate ); (* correct? *)
						adminDir.ReadWriteString ( version );
						adminDir.ReadWriteString ( creator );

						(* remove schedule entries *)
						adminDir.ReadWriteToEOE;
						WHILE ~adminDir.IsEOF () DO
							adminDir.ReadWriteLines ( 1 );
							adminDir.ReadWriteLine ( tmp2 );
							IF tmp2 = "dir" THEN
								adminDir.ReadWriteEOE;
							ELSE
								adminDir.ReadWriteToEOE;
							END;
						END;
						adminDir.WriteUpdate;

						SVNAdmin.WriteWCPROPS ( tmp, "", ver );
					END;
				END;
			END;
		END;
	END ParseMergeContent;

	PROCEDURE UpdateHandler* ( CONST path : ARRAY OF CHAR; entry : SVNAdmin.EntryEntity; data : ANY ) : BOOLEAN;
	VAR
		svn : OdSvn.OdSvn;
	BEGIN
		(* TODO:
			- search for files/directories which are on a separate revision
			- search for missing resources..and restore them:
				- dirs: neuer request!
				- files: restore von base copy
		*)
(*		KernelLog.String ( "path: " );
		KernelLog.String ( path );
		KernelLog.String ( "//" );
		KernelLog.String ( entry.Name );
		KernelLog.Ln;*)

		svn := data ( OdSvn.OdSvn );

		IF svn.traverseDummy THEN
			svn.traverseDummy := FALSE;
			svn.repositoryPathLength := Strings.Length ( entry.RepositoryRoot ) - Strings.IndexOfByte ( '/', 7, entry.RepositoryRoot );
		END;

		RETURN TRUE;
	END UpdateHandler;

	PROCEDURE CommitHandler* ( CONST path : ARRAY OF CHAR; entry : SVNAdmin.EntryEntity; data : ANY ) : BOOLEAN;
	VAR
		str : Strings.String;
		err, wrk, tmp2 : ARRAY 256 OF CHAR;
		props: WebHTTP.AdditionalField;
		svn : OdSvn.OdSvn;
		res : WORD;
		resHeader: WebHTTP.ResponseHeader;
		m : SVNOutput.Message;
	BEGIN
		svn := data ( OdSvn.OdSvn );

		NEW ( str, 256 );
		str := Strings.Substring2 ( Strings.Length ( entry.RepositoryRoot ), entry.Url );
		IF str^[0] = Files.PathDelimiter THEN str := Strings.Substring2 ( 1, str^ ) END;

		IF ~svn.removeDir THEN
			svn.removeDir := TRUE;
			Strings.Truncate ( svn.wrk, Strings.Length(svn.wrk) - Strings.Length(str^) );
		END;

		Strings.Concat ( svn.wrk, str^, tmp2 );
		SVNUtil.UrlEncode ( tmp2, wrk );

		IF entry.NodeKind = "file" THEN
			Files.JoinPath ( path, entry.Name, tmp2 );

			IF entry.Schedule = "add" THEN (* DONE *)
				svn.Propfind ( wrk, "D:version-controlled-configuration.D2:repository-uuid", props, err );
				IF svn.pfStatus = 404 THEN (* 404 = not found *)
					svn.context.out.String ( "Adding " ); svn.context.out.String ( tmp2 ); svn.context.out.Ln;

					Put ( wrk, tmp2, svn, res );
					ExpectedResult ( 201, svn, wrk, tmp2, "add file" ); (* 201 = created *)
				ELSE
					svn.context.out.String ( " ERROR: " ); svn.context.out.String ( wrk ); svn.context.out.String ( " is already on the server!" ); svn.context.out.Ln;
					svn.countChanges := 0; (* abort commit *)
					RETURN FALSE;
				END;
			ELSIF entry.Schedule = "delete" THEN
				(* TODO: remove entry in entries file and all-wcprops file: there is no report packet !!!  *)
				(*IF ~entry.GlobalRemoval THEN (* file will be deleted anyway if the top directory is removed *)
					svn.context.out.String ( "Deleting " ); svn.context.out.String ( tmp2 ); svn.context.out.Ln;

					Delete ( wrk, svn, res );
					ExpectedResult ( 204, svn, wrk, tmp2, "delete file" ); (* 204 = no content *)
				END;*)
			ELSE (* DONE *)
				IF ~SVNUtil.CheckChecksum ( tmp2, entry.Checksum ) THEN
					svn.context.out.String ( "Sending " );
					svn.context.out.String ( tmp2 );
					svn.context.out.Ln;

					svn.Checkout ( entry.VersionUrl, resHeader, err );
					IF resHeader.statuscode >= 400 THEN
						NEW ( m, svn.context );
						IF resHeader.statuscode = 409 THEN
							m.Print ( SVNOutput.ResCOMMITOUTOFDATE, tmp2 );
						ELSE
							svn.context.out.String ( "HTTP error! Statuscode: " ); svn.context.out.Int ( resHeader.statuscode, 0 );
							svn.context.out.Ln;
							m.Print ( SVNOutput.ResCOMMITUNSPECIFIED, tmp2 );
						END;

						svn.countChanges := 0; (* abort commit *)
						RETURN FALSE;
					ELSE
						Put ( wrk, tmp2, svn, res );
						ExpectedResult ( 204, svn, wrk, tmp2, "add file" ); (* 204 = no content *)
					END;
				END;
			END;
		ELSE
			IF entry.Schedule = "add" THEN (* DONE *)
				svn.context.out.String ( "Adding " ); svn.context.out.String ( path ); svn.context.out.Ln;

				Mkcol ( wrk, svn, res );
				ExpectedResult ( 201, svn, wrk, tmp2, "add directory" );
			ELSIF entry.Schedule = "delete" THEN
				(* TODO: remove entry in entries file *)
				(*svn.context.out.String ( "Deleting " ); svn.context.out.String ( tmp2 ); svn.context.out.Ln;

				Delete ( wrk, svn, res );
				ExpectedResult ( 204, svn, wrk, tmp2, "delete file" ); (* 204 = no content *)
				*)
			ELSE
				(* do nothing *)
			END;
		END;

		RETURN TRUE;
	END CommitHandler;

	PROCEDURE ExpectedResult ( status : LONGINT; svn : OdSvn.OdSvn; CONST wrk, lcl, message : ARRAY OF CHAR );
	BEGIN
		IF svn.pfStatus # status THEN
			svn.context.out.String ( "ERROR: failed to " );
			svn.context.out.String ( message );
			svn.context.out.String ( ": " );
			svn.context.out.String ( lcl );
			svn.context.out.Ln;
			svn.context.out.String ( "url: " );
			svn.context.out.String ( wrk );
			svn.context.out.Ln;
		ELSE
			INC ( svn.countChanges );
		END;
	END ExpectedResult;

	PROCEDURE Mkcol* ( CONST url : ARRAY OF CHAR; svn : OdSvn.OdSvn; VAR res : WORD );
	VAR
		resHeader: WebHTTP.ResponseHeader;
		out : Streams.Reader;
	BEGIN
		svn.client.Mkcol ( url, resHeader, out, res );
		svn.pfStatus := resHeader.statuscode;
	END Mkcol;

	PROCEDURE Delete* ( CONST url : ARRAY OF CHAR; svn : OdSvn.OdSvn; VAR res : WORD );
	VAR
		resHeader: WebHTTP.ResponseHeader;
		out : Streams.Reader;
	BEGIN
		svn.client.Delete ( url, resHeader, out, res );
		svn.pfStatus := resHeader.statuscode;
	END Delete;

	(* sends 'workName' to the svn.wrk address *)
	PROCEDURE Put* ( CONST workUrl, workName: ARRAY OF CHAR; svn : OdSvn.OdSvn; VAR res : WORD );
	VAR
		f : Files.File;
		resHeader: WebHTTP.ResponseHeader;
		reqHeader: WebHTTP.RequestHeader;
		in : Files.Reader;
		out : Streams.Reader;
		lenStr: ARRAY 10 OF CHAR;
		m : SVNOutput.Message;
	BEGIN
		f := Files.Old(workName);
		IF f # NIL THEN
			Files.OpenReader ( in, f, 0 );

			WebHTTP.SetAdditionalFieldValue ( reqHeader.additionalFields, "Content-Type", "application/octet-stream" );
			Strings.IntToStr ( f.Length(), lenStr );
			WebHTTP.SetAdditionalFieldValue ( reqHeader.additionalFields, "Content-Length", lenStr );

			svn.client.Put ( workUrl, reqHeader, resHeader, out, in, res );
			svn.pfStatus := resHeader.statuscode;
		ELSE
			svn.context.out.String ( " ERROR: PUT " );

			NEW ( m, svn.context );
			m.Print ( SVNOutput.ResFILENOTFOUND, workName );
		END;
	END Put;

	PROCEDURE PrintError ( svn : OdSvn.OdSvn; VAR res : WORD );
	BEGIN
		svn.context.out.String ( "Server response: " ); svn.context.out.Int ( svn.pfStatus, 0 ); svn.context.out.Ln;
		IF svn.pfStatus = 401 THEN
			res := SVNOutput.ResNOTAUTHORIZED;
		ELSE
			res := SVNOutput.ResUNEXPECTEDSERVERRESPONSE;
		END;
	END PrintError;

END SVNWebDAV.
