MODULE WebCGI; (** AUTHOR "TF"; PURPOSE "HTTP plugin for CGI commands"; *)

IMPORT
	KernelLog, Strings, Commands, Streams, WebHTTP, Files, WebHTTPServer, Modules,
	HTTPSupport;

TYPE
	CGIContext* = OBJECT
	VAR request* : HTTPSupport.HTTPRequest;
		w* : Streams.Writer;
		reply* : WebHTTP.ResponseHeader;
	END CGIContext;

	CGIContextProc = PROCEDURE(context : CGIContext);

	CGIPlugin = OBJECT(WebHTTPServer.HTTPPlugin)

		PROCEDURE CanHandle*(host : WebHTTPServer.Host; VAR request : WebHTTP.RequestHeader; secure : BOOLEAN) : BOOLEAN;
		VAR path : ARRAY 1024 OF CHAR;
		BEGIN
			WebHTTP.GetPath(request.uri, path);
			RETURN MyMatch(path, "/CGI/")
		END CanHandle;

		PROCEDURE Handle*(host : WebHTTPServer.Host; VAR request : WebHTTP.RequestHeader; VAR reply : WebHTTP.ResponseHeader;
			VAR in : Streams.Reader; VAR out : Streams.Writer);
		VAR r : HTTPSupport.HTTPRequest;
			cgiContextProc : CGIContextProc;
			w : Streams.Writer; chunker : WebHTTP.ChunkedOutStream;
			context : CGIContext;
			path : ARRAY 1024 OF CHAR;

		BEGIN
			NEW(r, request, in);

			WebHTTP.GetPath(r.shortUri, path);
			cgiContextProc := FindProcedure(r.shortUri);
			IF (cgiContextProc # NIL) THEN
				NEW(context); context.w := out; context.request := r; context.reply := reply;
				cgiContextProc(context);
			ELSE
				NEW(chunker, w, out, request, reply);
				reply.statuscode := WebHTTP.NotFound;
				WebHTTP.SendResponseHeader(reply, out);
				IF (request.method = WebHTTP.GetM) THEN
					w.String("<html><head><title>404 - Not Found</title></head>");
					w.String("<body>HTTP 404 - File Not Found<hr><address>");
					w.String(WebHTTPServer.ServerVersion); w.String("</address></body></html>");
					w.Ln; w.Update;
					chunker.Close
				END
			END
		END Handle;

	END CGIPlugin;

	CGIProcInfo = POINTER TO RECORD
		name, procedure : ARRAY 128 OF CHAR;
		next : CGIProcInfo;
	END;

VAR
	cgi : CGIPlugin;
	cgiProcs : CGIProcInfo;

PROCEDURE MyMatch(VAR uri : ARRAY OF CHAR; y : ARRAY OF CHAR) : BOOLEAN;
VAR i : LONGINT;
BEGIN
	WHILE (i < LEN(uri)) & (i < LEN(y)) & (uri[i] = y[i]) &(y[i] # 0X) DO INC(i) END;
	RETURN(i < LEN(uri)) & (i < LEN(y)) & (y[i] = 0X)
END MyMatch;

PROCEDURE FindProcedure(name : ARRAY OF CHAR) : CGIContextProc;
VAR
	cur : CGIProcInfo; cgiProc : CGIContextProc;
	moduleName, procedureName : Modules.Name; msg : ARRAY 32 OF CHAR; res : WORD;
BEGIN {EXCLUSIVE}
	Strings.Delete(name, 0, 5);
	cur := cgiProcs;
	WHILE cur # NIL DO
		IF cur.name = name THEN
			Commands.Split(cur.procedure, moduleName, procedureName, res, msg);
			IF (res = Commands.Ok) THEN
				GETPROCEDURE(moduleName, procedureName, cgiProc);
				RETURN cgiProc;
			END;
		END;
		cur := cur.next
	END;
	RETURN NIL
END FindProcedure;

PROCEDURE RegisterCGI*(context : Commands.Context);
VAR c : CGIProcInfo;
BEGIN {EXCLUSIVE}
	NEW(c);
	context.arg.SkipWhitespace; context.arg.String(c.name);
	context.arg.SkipWhitespace; context.arg.String(c.procedure);
	c.next := cgiProcs; cgiProcs := c;
	StoreCGIs;
END RegisterCGI;

PROCEDURE StoreCGIs;
VAR f : Files.File;
	w : Files.Writer;
	cur : CGIProcInfo;
	res : WORD;
	n0, n1 : ARRAY 64 OF CHAR;
BEGIN
	n0 := "CGIConfig.dat"; n1 := "CGIConfig.dat.Bak";
	Files.Rename(n0, n1, res);
	f := Files.New("CGIConfig.dat");
	Files.OpenWriter(w, f, 0);
	Files.Register(f);
	cur := cgiProcs;
	WHILE cur # NIL DO
		w.Char('"'); w.String(cur.name); w.Char('"'); w.Char(09X);
		w.Char('"'); w.String(cur.procedure); w.Char('"'); w.Ln;
 		cur := cur.next
	END;
	w.Update
END StoreCGIs;

PROCEDURE LoadCGIs;
VAR f : Files.File;
	r : Files.Reader;
	c : CGIProcInfo;
BEGIN
	f := Files.Old("CGIConfig.dat");
	IF f # NIL THEN
		Files.OpenReader(r, f, 0);
		WHILE r.res = 0 DO
			NEW(c);
			r.String(c.name); r.SkipWhitespace;
			r.String(c.procedure);
			IF r.res = 0 THEN c.next := cgiProcs; cgiProcs := c END;
			r.SkipLn
		END
	END
END LoadCGIs;

PROCEDURE ListCGI*(context : Commands.Context);
VAR cur : CGIProcInfo;
BEGIN {EXCLUSIVE}
	cur := cgiProcs;
	WHILE cur # NIL DO
		context.out.String(cur.name); context.out.String("-->"); context.out.String(cur.procedure); context.out.Ln;
		cur := cur.next
	END;
END ListCGI;

PROCEDURE Install*(context : Commands.Context);
VAR hl : WebHTTPServer.HostList;
BEGIN
	IF cgi = NIL THEN
		NEW(cgi, "CGI-Support");
		hl := WebHTTPServer.FindHosts("");
		hl.host.AddPlugin(cgi);
		context.out.String("CGI support installed to default host"); context.out.Ln;
		hl := WebHTTPServer.FindHosts("*");
		WHILE (hl # NIL) DO
			hl.host.AddPlugin(cgi);
			context.out.String("CGI support installed to "); context.out.String(hl.host.name); context.out.Ln;
			hl := hl.next
		END;
	 ELSE
		context.out.String("CGI support already installed"); context.out.Ln;
	END;
END Install;

PROCEDURE Close;
VAR h : WebHTTPServer.HostList;
BEGIN
	IF cgi # NIL THEN
		h := WebHTTPServer.FindHosts("");
		h.host.RemovePlugin(cgi);

		h := WebHTTPServer.FindHosts("*");
		WHILE (h # NIL) DO
			h.host.RemovePlugin(cgi);
			h := h.next
		END;
		KernelLog.String("CGI support removed"); KernelLog.Ln;
		cgi := NIL
	END
END Close;

BEGIN
	LoadCGIs;
	Modules.InstallTermHandler(Close)
END WebCGI.

WebHTTPServerTools.Start ~\r:FAT:/httproot \l:FAT:/httproot/HTTP.Log~
WebHTTPServerTools.Stop

WebCGI.RegisterCGI RegisterRaily4 RegisterRFW.RegisterRFW4 ~
WebCGI.RegisterCGI RegisterRaily3 RegisterRFW.RegisterRFW3 ~
WebCGI.ListCGI ~
WebCGI.Install ~
SystemTools.Free RegisterRFW WebCGI ~

