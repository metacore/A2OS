MODULE OdAuthBase;
(* WebDAV, Copyright 2003, Edgar Schwarz.
Author.    Edgar Schwarz, edgar@edgarschwarz.de, (es)
Contents. An  object for allowing a simple version of Basic HTTP Authentication RFC 2617.
Contents. Access is controlled for collections only. Reading is allowed for all users without authentication.
Contents. For writing methods like PUT, PROPPATCH, DELETE, MKCOL, CHECKIN, ... an authentication header
Contents. is necessary.
Remarks. For user interface see WebDAVAuth.
*)
IMPORT OdUtil, WebHTTP, Strings, Files;

CONST
	DefaultHost = "webdav.ethz.ch";
	AuthDat = "FTP:/WebDAV/es.WebDAVAuth.Dat";


TYPE
(*  For basic authentication there are these basic headers:
	Challenge =  WWW-Authenticate: Basic realm="admin"
	Response = Authorization: Basic ljsldjflsdjflsdjflsdkjflsdk==
*)
Basic * = OBJECT
	VAR host * : ARRAY 64 OF CHAR;
	pathRealms * : WebHTTP.AdditionalField; (* List of paths and the realms it belongs to. *)
	realmAuths * : WebHTTP.AdditionalField; (* List of authenication strings of a realm. *)

	PROCEDURE & Init(CONST hostStr: ARRAY OF CHAR);
	BEGIN
		COPY(hostStr, host);
		pathRealms := NIL;
		realmAuths := NIL;
	END Init;

	PROCEDURE Allowed(CONST path: ARRAY OF CHAR; auth: ARRAY OF CHAR): BOOLEAN;
	VAR realms, auths: OdUtil.Lines;
	BEGIN
		IF GetAdditionalFieldVals(pathRealms, path, TRUE, realms) THEN
			(* Out.String("Allowed.Auth="); Out.String(auth); Out.Ln; *)
			Strings.Trim(auth," ");
			IF Strings.Pos("Basic ", auth) = 0 THEN
				Strings.Copy(auth, 6, Strings.Length(auth)-6, auth); (* Drop prefix *)
				WHILE realms # NIL DO
				(* Out.String("Allowed.realm="); Out.String(realms.line); Out.Ln; *)
					IF GetAdditionalFieldVals(realmAuths, realms.line, FALSE, auths) THEN
						WHILE auths # NIL DO
							(* Out.String("auth, line ="); Out.String(auth); Out.Char(","); Out.String(auths.line); Out.Ln; *)
							IF auths.line = auth THEN RETURN TRUE; END;
							auths := auths.next;
						END;
					END;
					realms := realms.next;
				END;
				RETURN FALSE;
			ELSE
				RETURN FALSE; (* An correct authentication string begins with  "Basic " *)
			END;
		ELSE
			(* Out.String("Basic: not in a realm"); Out.Ln; *)
			RETURN TRUE; (* The path isn't in a realm. So access is free. *)
		END;
	END Allowed;

	(** Challenge =  WWW-Authenticate: Basic realm="admin" *)
	PROCEDURE GetChallenge(CONST path: ARRAY OF CHAR; VAR challenges: OdUtil.Lines);
	VAR realms: OdUtil.Lines; challenge: OdUtil.Line;
	BEGIN
		NEW(realms); (* List of realms the path belongs to. *)
		NEW(challenges);
		IF GetAdditionalFieldVals(pathRealms, path, TRUE, realms) THEN
			WHILE realms # NIL DO
				Strings.Concat('Basic realm="', realms.line, challenge);
				Strings.Append(challenge, '"');
				challenges.add(challenge);
				realms := realms.next;
			END;
		ELSE
			challenges := NIL; (* The path isn't in a realm. Shouldn't happen normally. *)
		END;
	END GetChallenge;

	PROCEDURE Authorized * (VAR req: WebHTTP.RequestHeader; VAR res: WebHTTP.ResponseHeader): BOOLEAN;
	CONST PLog = FALSE;
	VAR
		path, name, authHeader: ARRAY 128 OF CHAR;
		challenges: OdUtil.Lines;
	BEGIN
		IF req.uri = "/" THEN
			(* No write access on the root itself. *)
			RETURN FALSE;
		END;
		OdUtil.unpadColl(req.uri); (* To get the parent collection of a collection. *)
		Files.SplitPath (req.uri, path, name);
		OdUtil.padColl(path);
		IF ~WebHTTP.GetAdditionalFieldValue(req.additionalFields, "Authorization", authHeader) THEN
			authHeader := "";
		END;
		IF PLog THEN
			OdUtil.Msg6("WebDAVAuthBase.Basic.Authorized: req.uri,path,authHeader =", req.uri, ":", path, ":", authHeader);
		END;
		IF Allowed(path, authHeader) THEN
			IF PLog THEN OdUtil.Msg1("WebDAVAuthBase.Basic.Authorized: TRUE"); END;
			RETURN TRUE;
		ELSE
			res.statuscode := WebHTTP.Unauthorized;
			GetChallenge(path, challenges);
			(* Just return the first of the realms. Could it be more ? *)
			ASSERT(challenges # NIL); (* If not authenticated at least one realm must exist. *)
			WebHTTP.SetAdditionalFieldValue(res.additionalFields, "WWW-Authenticate", challenges.line);
			IF PLog THEN OdUtil.Msg1("WebDAVAuthBase.Basic.Authorized: FALSE"); END;
			RETURN FALSE;
		END;
	END Authorized;

END Basic;

VAR
	encTable: ARRAY 64 OF CHAR;
	decTable: ARRAY 128 OF SIGNED16;
	defaultAuth * : Basic;
	defaultHost * : ARRAY 64 OF CHAR;

(** Additional procedures to allow a key to appear multiple times in an WebHTTP.AdditionalField.
	WebHTTP.AdditionalField    *)

(** Like WebHTTP.SetAdditionalFieldValue but adds a key value multiple times. *)
PROCEDURE AddAdditionalFieldValue * (VAR af: WebHTTP.AdditionalField; CONST fieldName, value: ARRAY OF CHAR);
VAR a: WebHTTP.AdditionalField;
BEGIN
	IF (af = NIL) THEN NEW(a); af := a
	ELSE
		a := af; WHILE a.next # NIL DO a := a.next END;
		NEW(a.next); a := a.next
	END;
	COPY(fieldName, a.key); COPY(value, a.value)
END AddAdditionalFieldValue;

(** Like WebHTTP.GetAdditionalFieldValue but returns multiple values. *)
PROCEDURE GetAdditionalFieldVals * (af: WebHTTP.AdditionalField; CONST fieldName: ARRAY OF CHAR; prefix: BOOLEAN;
	 VAR values: OdUtil.Lines) : BOOLEAN;
BEGIN
	NEW(values);
	WHILE af # NIL DO
		IF prefix THEN
			(* This allows an realm definition to be valid recursively for the whole tree.
				fieldName /a/b/c also gets a realm entry for /a/b. *)
			IF Strings.Pos(af.key, fieldName) = 0 THEN
				values.add(af.value);
			END;
		ELSE
			IF af.key = fieldName THEN
				values.add(af.value);
			END;
		END;
		af := af.next
	END;
	IF values # values.next THEN
		RETURN TRUE;
	ELSE
		values := NIL;
		RETURN FALSE
	END
END GetAdditionalFieldVals;

(** Realm management.
	pathRealms = { path realm }.	A path can belong to different realms.
	realmAuths = { realm authentication }. The list of authentication strings for the realm.
	Realm = Path {user pass}
	Realms = {realm}
*)

(* Base64 Utilities. Copied from Oberon.Base64.Mod because it's an Oberon module using Text,Files. *)

PROCEDURE InitTables;
	VAR i, max: SIGNED16;
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

(* Should be perhaps done with an AosIO.Reader, Writer. *)
PROCEDURE EncodeString * (VAR in, out:  ARRAY OF CHAR);
	VAR
		i, j, c, c0, c1, c2, l: SIGNED32;
		chars: ARRAY 3 OF CHAR;
		inPos, outPos: SIGNED32; eos: BOOLEAN;

	PROCEDURE OutCode;
	BEGIN
		IF l > 80 THEN
			out[outPos] := 0DX; INC(outPos); l := 0
		END;
		c0 :=ORD(chars[0]);
		c := ASH(c0, -2);
		out[outPos] := encTable[c]; INC(outPos); c0 := c0-ASH(c, 2);
		c1 := ORD(chars[1]);
		c := ASH(c0, 4)+ASH(c1, -4);
		out[outPos] := encTable[c]; INC(outPos); c1 := c1 MOD ASH(1, 4);
		c2 := ORD(chars[2]);
		c := ASH(c1, 2)+ASH(c2, -6);
		out[outPos] := encTable[c]; INC(outPos); c2 := c2 MOD ASH(1, 6);
		out[outPos] := encTable[c2]; INC(outPos);
		INC(l, 4)
	END OutCode;

BEGIN
	outPos := 0; inPos := 0; eos := FALSE;
	l := 0;
	chars[0] := in[inPos]; INC(inPos); i := 1;
	WHILE ~eos DO
		IF i >= 3 THEN
			OutCode(); i := 0
		END;
		chars[i] := in[inPos]; INC(inPos); INC(i);
		eos := chars[i-1] = 0X;
	END;
	DEC(i);
	IF i > 0 THEN
		j := i;
		WHILE i < 3 DO
			chars[i] := 0X; INC(i)
		END;
		OutCode();
		out[outPos] := 0X;
		IF j < 3 THEN
			j := 3-j;
			out[outPos-j] := 0X; outPos := outPos-j;
			FOR i := 1 TO j DO
				out[outPos] := "="; INC(outPos);
			END
		END
	END;
	out[outPos] := 0X;
END EncodeString;
(* End Base64 Utilities. *)

PROCEDURE GetAuth * (CONST host: ARRAY OF CHAR): Basic;
BEGIN
	RETURN defaultAuth; (* There isn't another auth object yet. *)
END GetAuth;

PROCEDURE SetBasicRealm * (host: ARRAY OF CHAR; CONST realm: ARRAY OF CHAR; path: ARRAY OF CHAR);
BEGIN
	IF host = "" THEN COPY(defaultHost, host); END;
	OdUtil.padColl(path);
	AddAdditionalFieldValue(defaultAuth.pathRealms, path, realm);
END SetBasicRealm;

PROCEDURE SetBasicAuth * (host: ARRAY OF CHAR; CONST realm, user, password: ARRAY OF CHAR);
VAR
	userPass, userPass64: ARRAY 64 OF CHAR;
BEGIN
	IF host = "" THEN COPY(defaultHost, host); END;
	Strings.Concat(user, ":", userPass); Strings.Append(userPass, password);
	EncodeString(userPass, userPass64);
	AddAdditionalFieldValue(defaultAuth.realmAuths, realm, userPass64);
END SetBasicAuth;

(* Necessary because Token will also return delimiting " and '. *)
PROCEDURE unquote(VAR str: ARRAY OF CHAR);
BEGIN
	IF (str[0] = '"') OR (str[0] = "'") THEN Strings.Copy(str, 1, Strings.Length(str)-2, str); END;
END unquote;

PROCEDURE InitAuths;
VAR f: Files.File; r: Files.Reader;
	cmd, host, realm, path, user, password: ARRAY 1024 OF CHAR;
BEGIN
	f := Files.Old(AuthDat);	(* open an existing file *)
	IF f # NIL THEN
		NEW(r, f, 0);	(* open a buffer on the file *)
		LOOP
			r.SkipWhitespace; r.Token(cmd);
			IF r.res # Files.Ok THEN EXIT END;	(* end-of-file, or other error *)
			IF cmd = "BasicRealm" THEN
				r.SkipWhitespace; r.Token(host);  IF r.res # Files.Ok THEN EXIT END; unquote(host);
				r.SkipWhitespace; r.Token(realm); IF r.res # Files.Ok THEN EXIT END; unquote(realm);
				r.SkipWhitespace; r.Token(path); IF r.res # Files.Ok THEN EXIT END; unquote(path);
				SetBasicRealm(host, realm, path);
				(*AosOut.Enter; AosOut.String(realm); AosOut.String(path); AosOut.Exit;*)
			ELSIF cmd = "BasicAuth" THEN
				r.SkipWhitespace; r.Token(host); IF r.res # Files.Ok THEN EXIT END; unquote(host);
				r.SkipWhitespace; r.Token(realm); IF r.res # Files.Ok THEN EXIT END; unquote(realm);
				r.SkipWhitespace; r.Token(user); IF r.res # Files.Ok THEN EXIT END; unquote(user);
				r.SkipWhitespace; r.Token(password); IF r.res # Files.Ok THEN EXIT END; unquote(password);
				SetBasicAuth(host, realm, user, password);
				(* AosOut.Enter; AosOut.String(realm); AosOut.String(user); AosOut.Exit; *)
			END;
		END
	END
END InitAuths;

BEGIN
	InitTables;
	defaultHost := DefaultHost;
	NEW(defaultAuth, defaultHost);
	InitAuths;
END OdAuthBase.
