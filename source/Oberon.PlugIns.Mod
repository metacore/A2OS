(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE PlugIns IN Oberon; (** portable *)	(* ejz  *)
	IMPORT FileDir, Files, Objects, Display, Attributes, Links, Strings, Packages, Viewers, Views;

(**
	Base module for Oberon plugins installed from application packages (see: Packages.install).
	For concrete implementations of plugins see HTMLPlugIns.Mod (plugin for HTMLDocs) and
	Win32.NPPlugIns.Mod (plugin for Netscape).
*)

	CONST
		(** Error codes returned by getURL/postURL and state of streams. *)
		Done* = 0; NetworkErr* = 1; UserBreak* = 2; OtherError* = 3; Transfering* = -1;

	TYPE
		(** This should be long enough for any URL. *)
		URLStr* = ARRAY 1024 OF CHAR;

		StreamList = POINTER TO RECORD
			stream: Stream; url: URLStr; next: StreamList
		END;

		(** Base type for plugin objects. Concrete implementations must provide the method
			getURL to request new files. *)
		PlugIn* = POINTER TO RECORD (Objects.Object)
			V*: Display.Frame;	(** view displaing the plugin frame (= V.dsc) *)
			attrs: Attributes.Attr; gen: ARRAY 64 OF CHAR;
			getURL*: GetURLProc; postURL*: PostURLProc;	(** get and post URLs in the plugins context *)
			error*: ErrorProc;	(** display an error message, in the plugins context *)
			base*: Stream;	(** stream from which the plugin should be loaded *)
			streams: StreamList; err: BOOLEAN
		END;

		GetURLProc* = PROCEDURE (plugin: PlugIn; CONST url: ARRAY OF CHAR): LONGINT;
		PostURLProc* = PROCEDURE (plugin: PlugIn; CONST urlDest, urlSrc: ARRAY OF CHAR): LONGINT;
		ErrorProc* = PROCEDURE (plugin: PlugIn; CONST msg1, msg2: ARRAY OF CHAR);

		(** Stream objects are created by calls to getURL. When ever the state of a stream
			changes clients should be notified using Gadgets.Update(stream). *)
		Stream* = POINTER TO RECORD (Objects.Object)
			file*: FileDir.FileName;	(** file name of the local copy *)
			url*: URLStr;	(** the requested URL *)
			state*: LONGINT	(** Done, NetworkErr, UserBreak, OtherError, Transfering *)
		END;

	PROCEDURE Error(plugin: PlugIn; CONST msg1, msg2: ARRAY OF CHAR);
	BEGIN
		plugin.streams := NIL; plugin.err := TRUE;
		plugin.error(plugin, msg1, msg2)
	END Error;

	(** Display an error (for stream.state) message using the plugins error method. *)
	PROCEDURE StreamError*(plugin: PlugIn; stream: Stream);
		VAR msg: URLStr;
	BEGIN
		COPY(stream.url, msg); Strings.Append(msg, ": ");
		CASE stream.state OF
			NetworkErr: Error(plugin, msg, "network error")
			|UserBreak: Error(plugin, msg, "user break")
			|Transfering: Error(plugin, msg, "transfering")
			|Done: Error(plugin, msg, "done")
		ELSE
			Error(plugin, msg, "error")
		END
	END StreamError;

	(** Determines whether two URLs are equal. *)
	PROCEDURE SameURL*(CONST urlA, urlB: ARRAY OF CHAR): BOOLEAN;
		VAR a, b: LONGINT;
	BEGIN
(* replace this by CAPCompare with special handling for
	file urls (no file: prefix no drive letter)
==> requires some fixes in HTMLPlugIns
*)
		a := 0; WHILE urlA[a] # 0X DO INC(a) END; DEC(a);
		b := 0; WHILE urlB[b] # 0X DO INC(b) END; DEC(b);
		WHILE (a >= 0) & (b >= 0) & (CAP(urlA[a]) = CAP(urlB[b])) DO
			DEC(a); DEC(b)
		END;
		IF (a > 0) & (b > 0) THEN
			(* ../ & ./ *)
			IF (a >= 1) & (urlA[a] = ".") & (urlA[a-1] = ".") THEN
				RETURN TRUE
			ELSIF (b >= 1) & (urlB[b] = ".") & (urlB[b-1] = ".") THEN
				RETURN TRUE
			END
		ELSIF a > 0 THEN
			RETURN (urlA[a] = "/") OR (urlA[a] = ":")
		ELSIF b > 0 THEN
			RETURN (urlB[b] = "/") OR (urlB[b] = ":")
		ELSE
			RETURN TRUE
		END;
		RETURN FALSE
	END SameURL;

	(** Completes the relative URL url using plugin.base.url. *)
	PROCEDURE MakeFullURL*(plugin: PlugIn; VAR url: ARRAY OF CHAR);
		VAR full: URLStr; i, j, k: LONGINT;
	BEGIN
		IF (plugin = NIL) OR (plugin.base = NIL) OR (plugin.base.url = "") THEN
			RETURN
		END;
		i := 0;
		WHILE (url[i] # 0X) & (url[i] # ":") DO
			INC(i)
		END;
		IF (url[i] = ":") & (i <= 4) THEN
			RETURN
		ELSE
			COPY(plugin.base.url, full);
			i := 0; j := 0; k := 0;
			WHILE full[i] # 0X DO
				IF full[i] = "/" THEN k := j; j := i+1 END;
				INC(i)
			END;
			IF (url[0] = ".") & (url[1] = ".") & (url[2] = "/") THEN (* ../ *)
				i := 3; j := k
			ELSIF (url[0] = ".") & (url[1] = "/") THEN (* ./ *)
				i := 2
			ELSIF url[0] = "/" THEN
				HALT(99)
			ELSE
				i := 0
			END;
			WHILE url[i] # 0X DO
				full[j] := url[i]; INC(i); INC(j)
			END;
			full[j] := 0X;
			COPY(full, url)
		END
	END MakeFullURL;

	PROCEDURE FindStream(plugin: PlugIn; CONST url: ARRAY OF CHAR): StreamList;
		VAR streaml: StreamList;
	BEGIN
		streaml := plugin.streams;
		WHILE (streaml # NIL) & ~SameURL(streaml.url, url) DO
			streaml := streaml.next
		END;
		RETURN streaml
	END FindStream;

	PROCEDURE RemoveStream(plugin: PlugIn; CONST url: ARRAY OF CHAR);
		VAR pstreaml, streaml: StreamList;
	BEGIN
		pstreaml := NIL; streaml := plugin.streams;
		WHILE streaml # NIL DO
			IF SameURL(streaml.url, url) THEN
				IF pstreaml # NIL THEN
					pstreaml.next := streaml.next
				ELSE
					plugin.streams := streaml.next
				END
			ELSE
				pstreaml := streaml
			END;
			streaml := streaml.next
		END
	END RemoveStream;

	PROCEDURE AddURL(plugin: PlugIn; CONST url: ARRAY OF CHAR);
		VAR streaml: StreamList;
	BEGIN
		NEW(streaml); streaml.next := plugin.streams; plugin.streams := streaml;
		COPY(url, streaml.url); streaml.stream := NIL
	END AddURL;

	(** Notify the plugins installer, that the state of stream has changed. *)
	PROCEDURE UpdateStream*(plugin: PlugIn; stream: Stream);
	BEGIN
		IF stream.state = Done THEN
			IF ~plugin.err THEN
				IF Files.Old(stream.file) # NIL THEN
					ProcessStream(plugin, stream)
				ELSE
					stream.state := OtherError;
					StreamError(plugin, stream)
				END
			END
		ELSIF stream.state # Transfering THEN
			StreamError(plugin, stream)
		END
	END UpdateStream;

	(** Check if plugin has a pending request for url. *)
	PROCEDURE Requested*(plugin: PlugIn; CONST url: ARRAY OF CHAR): BOOLEAN;
	BEGIN
		RETURN FindStream(plugin, url) # NIL
	END Requested;

	(** Add a URL to the plugin installers list of required URLs. *)
	PROCEDURE RequestURL*(plugin: Objects.Object; CONST url: ARRAY OF CHAR): LONGINT;
		VAR streaml: StreamList; full: URLStr;
	BEGIN
		WITH plugin: PlugIn DO
			COPY(url, full); MakeFullURL(plugin, full);
			streaml := FindStream(plugin, full);
			IF streaml = NIL THEN
				AddURL(plugin, full);
				RETURN plugin.getURL(plugin, full)
			ELSIF (streaml.stream # NIL) & (streaml.stream.state # Transfering) THEN
				UpdateStream(plugin, streaml.stream);
				RETURN streaml.stream.state
			ELSE (* (streaml.stream = NIL) OR (streaml.stream.state = Transfering) *)
				RETURN 0
			END
		END
	END RequestURL;

	PROCEDURE ProcessStream(plugin: PlugIn; stream: Stream);
		VAR
			obj: Objects.Object; str: FileDir.FileName; streaml: StreamList;
			M: Objects.AttrMsg; res: WORD;
	BEGIN
		streaml := FindStream(plugin, stream.url);
		IF streaml # NIL THEN
			streaml.stream := stream
		ELSIF SameURL(stream.url, plugin.base.url) THEN
			AddURL(plugin, plugin.base.url);
			plugin.streams.stream := stream
		ELSE
			HALT(99)
		END;
		res := Packages.install(Files.Old(stream.file), str, plugin, RequestURL);
		IF res = 0 THEN
			IF (plugin.gen = "") & SameURL(stream.url, plugin.base.url) THEN
				Attributes.GetString(plugin, "Gen", plugin.gen);
				IF plugin.gen = "" THEN COPY(str, plugin.gen) END
			END;
			RemoveStream(plugin, stream.url);
			streaml := plugin.streams; res := 0;
			WHILE ~plugin.err & (streaml # NIL) DO
				ASSERT(streaml.stream # stream);
				IF (streaml.stream # NIL) & (streaml.stream.state = Done) THEN
					ProcessStream(plugin, streaml.stream); INC(res);
					streaml := plugin.streams
				ELSE
					streaml := streaml.next
				END
			END;
			IF ~plugin.err & (plugin.streams = NIL) & (res = 0) THEN
				M.id := Objects.get; M.name := "CreateObject"; M.b := FALSE; M.res := -1;
				plugin.handle(plugin, M);
				IF (M.res = -1) OR M.b THEN
					obj := Packages.CreateObject(plugin.gen, str);
					IF obj # NIL THEN
						Links.SetLink(plugin, "Content", obj)
					ELSE
						Error(plugin, str, "")
					END
				END
			END
		ELSIF res # 1 THEN
			Error(plugin, "Packages.Install ", str)
		END
	END ProcessStream;

	(** Default message handler for plugins. *)
	PROCEDURE Handler*(plugin: Objects.Object; VAR M: Objects.ObjMsg);
		VAR attr: Attributes.Attr; sattr: Attributes.StringAttr;
	BEGIN
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				attr := plugin(PlugIn).attrs;
				IF M.id = Objects.get THEN
					WHILE (attr # NIL) & ~Strings.CAPCompare(M.name, attr.name) DO
						attr := attr.next
					END;
					IF attr # NIL THEN
						M.class := Objects.String; COPY(attr(Attributes.StringAttr).s, M.s); M.res := 0
					END
				ELSIF M.id = Objects.set THEN
					WHILE (attr # NIL) & ~Strings.CAPCompare(M.name, attr.name) DO
						attr := attr.next
					END;
					IF attr # NIL THEN
						COPY(M.s, attr(Attributes.StringAttr).s)
					ELSE
						ASSERT(M.class = Objects.String);
						NEW(sattr); COPY(M.name, sattr.name); COPY(M.s, sattr.s);
						Attributes.InsertAttr(plugin(PlugIn).attrs, sattr.name, sattr)
					END;
					M.res := 0
				ELSIF M.id = Objects.enum THEN
					WHILE attr # NIL DO
						M.Enum(attr.name); attr := attr.next
					END;
					M.res := 0
				END
			END
		END
	END Handler;

	(** Initialize all fields of plugin to default values. *)
	PROCEDURE InitPlugIn*(plugin: PlugIn);
	BEGIN
		plugin.V := NIL;
		plugin.attrs := NIL; plugin.gen := "";
		plugin.getURL := NIL; plugin.postURL := NIL;
		plugin.error := NIL; plugin.err := FALSE;
		plugin.base := NIL; plugin.streams := NIL;
		plugin.handle := Handler
	END InitPlugIn;

	(** Default message handler for streams. *)
	PROCEDURE StreamHandler*(stream: Objects.Object; VAR M: Objects.ObjMsg);
	BEGIN
		WITH stream: Stream DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "State" THEN
							M.class := Objects.Int; M.i := stream.state; M.res := 0
						ELSIF M.name = "URL" THEN
							M.class := Objects.String; COPY(stream.url, M.s); M.res := 0
						ELSIF M.name = "File" THEN
							M.class := Objects.String; COPY(stream.file, M.s); M.res := 0
						END
					ELSIF M.id = Objects.enum THEN
						M.Enum("State"); M.Enum("URL"); M.Enum("File")
					END
				END
			END
		END
	END StreamHandler;

	(** Initialize all fields of stream to default values. *)
	PROCEDURE InitStream*(stream: Stream);
	BEGIN
		stream.file := ""; stream.url := "";
		stream.state := Transfering;
		stream.handle := StreamHandler
	END InitStream;

	(** Create a new stream for file. *)
	PROCEDURE NewFileStream*(CONST file: ARRAY OF CHAR): Stream;
		VAR F: Files.File; stream: Stream;
	BEGIN
		NEW(stream); InitStream(stream);
		COPY(file, stream.url);
		F := Files.Old(file);
		IF F # NIL THEN
			Files.GetName(F, stream.file);
			COPY(stream.file, stream.url);
			stream.state := Done
		ELSE
			stream.state := NetworkErr
		END;
		RETURN stream
	END NewFileStream;

	(** Plugin enclosing the current context. *)
	PROCEDURE CurrentPlugIn*(context: Objects.Object): PlugIn;
		VAR plugin: Objects.Object;
	BEGIN
		LOOP
			IF context = NIL THEN
				RETURN NIL
			ELSIF (context IS Viewers.Viewer) OR (context IS Views.View) THEN
				Links.GetLink(context, "PlugIn", plugin);
				IF (plugin # NIL) & (plugin IS PlugIn) THEN
					RETURN plugin(PlugIn)
				END
			END;
			context := context.dlink
		END
	END CurrentPlugIn;

END PlugIns.
