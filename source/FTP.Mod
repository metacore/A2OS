MODULE FTP;

IMPORT
	FTPClient, Commands, Streams, Files, Texts, TextUtilities;

CONST
	BufSize = 16*1024; (* internal buffer size, used for file transfer *)

	LocalFileNotFound = -2;

VAR ftp : FTPClient.FTPClient;

PROCEDURE PutFile(ftp : FTPClient.FTPClient; local, remote : ARRAY OF CHAR; VAR res : WORD);
VAR buf: ARRAY BufSize OF CHAR; len: LONGINT;
	f : Files.File; r : Files.Reader;
	w : Streams.Writer;
BEGIN
	f := Files.Old(local);
	IF f = NIL THEN res := LocalFileNotFound; RETURN END;
	Files.OpenReader(r, f, 0);

	ftp.OpenPut(remote, w, res);
	IF res = 0 THEN
		REPEAT
			r.Bytes(buf, 0, BufSize, len); w.Bytes(buf, 0, len);
		UNTIL r.res # 0;
		w.Update;
		ftp.ClosePut(res);
	END;
END PutFile;

PROCEDURE PutText(ftp : FTPClient.FTPClient; local, remote : ARRAY OF CHAR; VAR res : WORD);
VAR w : Streams.Writer;
        text: Texts.Text;
        r: Texts.TextReader;
        ch: Texts.Char32;
        i: LONGINT;
BEGIN
        NEW(text);
        TextUtilities.LoadOberonText(text, local, res);
        IF res # 0 THEN res:= LocalFileNotFound; RETURN END;
        text.AcquireRead;
        NEW(r, text);
        ftp.OpenPut(remote, w, res);
        IF res = 0 THEN
		FOR i := 0 TO text.GetLength() - 1 DO
			r.ReadCh(ch);
			IF (ch >= 0) & (ch < 128) THEN w.Char(CHR(ch)) END;
		END;
		w.Update;
		ftp.ClosePut(res)
	END;
	text.ReleaseRead
END PutText;

PROCEDURE GetFile(ftp : FTPClient.FTPClient; remote, local : ARRAY OF CHAR; VAR res : WORD);
VAR buf: ARRAY BufSize OF CHAR; len: LONGINT;
	f : Files.File; w : Files.Writer;
	r : Streams.Reader;
BEGIN

	f := Files.New(local);
	Files.OpenWriter(w, f, 0);

	ftp.OpenGet(remote, r, res);
	IF res = 0 THEN
		REPEAT
			r.Bytes(buf, 0, BufSize, len); w.Bytes(buf, 0, len);
		UNTIL r.res # 0;
		w.Update;
		Files.Register(f);
		ftp.CloseGet(res)
	END;
END GetFile;

PROCEDURE  Open*(context : Commands.Context);
VAR
	host, user, password : ARRAY 256 OF CHAR;
	res : WORD;
BEGIN
	IF ftp # NIL THEN
		context.out.String("Already open"); context.out.Ln;
		RETURN;
	END;

	context.arg.SkipWhitespace; context.arg.String(host);
	context.arg.SkipWhitespace; context.arg.String(user);
	context.arg.SkipWhitespace; context.arg.String(password);

	context.out.String("host = "); context.out.String(host); context.out.Ln;

	context.out.String("user = "); context.out.String(user); context.out.Ln;
	context.out.String("password = "); context.out.String(password); context.out.Ln;

	NEW(ftp);
	ftp.Open(host, user, password, 21, res);
	context.out.String(ftp.msg);
	IF res = 0 THEN
		context.out.String("Connected"); context.out.Ln;
	ELSE
		ftp := NIL;
		context.out.String("Connecting failed"); context.out.Ln;
	END;
END Open;

PROCEDURE PutFiles*(context : Commands.Context);
VAR
	local, path, remote : ARRAY 256 OF CHAR;
	tok : ARRAY 8 OF CHAR;
	res : WORD;
BEGIN
	IF ftp = NIL THEN
		context.out.String("not connected"); context.out.Ln;
		RETURN;
	END;

	REPEAT
		context.arg.SkipWhitespace; context.arg.String(local);

		Files.SplitPath(local, path, remote);
		context.arg.SkipWhitespace;
		IF context.arg.Peek() = "=" THEN
			context.arg.Token(tok);
			IF tok # "=>" THEN
				context.out.String("=> expected");
				RETURN;
			END;
			context.arg.SkipWhitespace; context.arg.String(remote)
		END;
		IF (local # "") & (remote # "") THEN
			PutFile(ftp, local, remote, res);
			IF res = 0 THEN context.out.String(local); context.out.String(" copied to "); context.out.String(remote); context.out.Ln
			ELSIF res = LocalFileNotFound THEN	context.out.String("Local file "); context.out.String(local); context.out.String(" not found ");  context.out.Ln
			ELSE context.out.String("upload failed on remote file "); context.out.String(remote); context.out.Ln
			END;
		END
	UNTIL context.arg.res # 0;
END PutFiles;

PROCEDURE PutTexts*(context : Commands.Context);
VAR
	local, path, remote : ARRAY 256 OF CHAR;
	tok : ARRAY 8 OF CHAR;
	res : WORD;
BEGIN
	IF ftp = NIL THEN
		context.out.String("not connected"); context.out.Ln;
		RETURN;
	END;
	REPEAT
		context.arg.SkipWhitespace; context.arg.String(local);

		Files.SplitPath(local, path, remote);
		context.arg.SkipWhitespace;
		IF context.arg.Peek() = "=" THEN
			context.arg.Token(tok);
			IF tok # "=>" THEN
				context.out.String("=> expected");
				RETURN;
			END;
			context.arg.SkipWhitespace; context.arg.String(remote);
		END;
		IF (local # "") & (remote # "") THEN
			PutText(ftp, local, remote, res);
			IF res = 0 THEN context.out.String(local); context.out.String(" copied to "); context.out.String(remote); context.out.Ln
			ELSIF res = LocalFileNotFound THEN	context.out.String("Local file "); context.out.String(local); context.out.String(" not found ");  context.out.Ln
			ELSE context.out.String("upload failed on remote file "); context.out.String(remote); context.out.Ln
			END;
		END
	UNTIL context.arg.res # 0;
END PutTexts;

PROCEDURE GetFiles*(context : Commands.Context);
VAR
	local, remote : ARRAY 256 OF CHAR;
	tok : ARRAY 8 OF CHAR;
	res : WORD;
BEGIN
	IF ftp = NIL THEN
		context.out.String("not connected"); context.out.Ln;
		RETURN;
	END;

	REPEAT
		context.arg.SkipWhitespace; context.arg.String(remote);
		COPY(remote, local);

		context.arg.SkipWhitespace;
		IF context.arg.Peek() = "=" THEN
			context.arg.Token(tok);
			IF tok # "=>" THEN
				context.out.String("=> expected");
				RETURN;
			END;
			context.arg.SkipWhitespace; context.arg.String(local);
		END;
		IF (local # "") & (remote # "") THEN
			GetFile(ftp, remote, local, res);
			IF res = 0 THEN context.out.String(remote); context.out.String(" downloaded to "); context.out.String(local); context.out.Ln
			ELSE context.out.String("download failed on remote file "); context.out.String(remote); context.out.Ln
			END;
		END
	UNTIL context.arg.res # 0;
END GetFiles;

PROCEDURE MakeDir*(context : Commands.Context);
VAR
	path : ARRAY 256 OF CHAR;
	res : WORD;
BEGIN
	IF ftp = NIL THEN
		context.out.String("not open"); context.out.Ln;
		RETURN;
	END;
	context.arg.String(path);
	ftp.MakeDir(path, res);
	IF res = 0 THEN context.out.String("Directory created."); context.out.Ln
	ELSE context.out.String("Failed creating directory."); context.out.Ln
	END;
END MakeDir;


PROCEDURE ChangeDir*(context : Commands.Context);
VAR
	path : ARRAY 256 OF CHAR;
	res : WORD;
BEGIN
	IF ftp = NIL THEN
		context.out.String("not open"); context.out.Ln;
		RETURN;
	END;
	context.arg.String(path);
	ftp.ChangeDir(path, res);
	IF res = 0 THEN context.out.String("Directory changed."); context.out.Ln
	ELSE context.out.String("Failed changing directory."); context.out.Ln
	END;

	ftp.GetCurrentDir(path, res);
	IF res = 0 THEN context.out.String("New remote dir is : "); context.out.String(path); context.out.Ln END;
END ChangeDir;

PROCEDURE Directory*(context : Commands.Context);
VAR i : LONGINT;
BEGIN
	IF ftp = NIL THEN
		context.out.String("not open"); context.out.Ln;
		RETURN;
	END;
	ftp.EnumerateDir("");
	FOR i := 0 TO ftp.nofEntries-1 DO
		context.out.String(ftp.listing[i].full); context.out.Ln;
	END;
END Directory;

PROCEDURE Close*(context : Commands.Context);
VAR res : WORD;
BEGIN
	IF ftp = NIL THEN
		context.out.String("not connected"); context.out.Ln;
		RETURN;
	END;
	ftp.Close(res);
	context.out.String("closed."); context.out.String(ftp.msg); context.out.Ln;
	ftp := NIL;
END Close;

END FTP.

FTP.Open www.ocp.inf.ethz.ch "ocp" "download"  ~
FTP.Directory ~
FTP.ChangeDir <directoryname> ~
FTP.PutFiles 	<list of filenames> ~
FTP.GetFiles <list of filenames> ~
FTP.Close ~

SystemTools.Free FTP  FTPClient ~