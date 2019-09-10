(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE HTMLPlugIns IN Oberon; (** portable *)	(* ejz  *)
	IMPORT Files, Objects, Modules, Display, Fonts, Texts, Oberon, Attributes, Links, Views, Strings, PlugIns,
		Gadgets, Documents, Desktops, HyperDocs, HTTPDocs0, HTMLDocs;

(**
	PlugIns for HTMLDocs.
*)

	TYPE
		View = POINTER TO ViewDesc;
		ViewDesc = RECORD (Views.ViewDesc)
			plugin: PlugIns.PlugIn; base: HTMLDocs.DocURL
		END;

		StreamList = POINTER TO StreamListDesc;
		StreamListDesc = RECORD
			stream: PlugIns.Stream; next: StreamList
		END;

		Notifier = POINTER TO NotifierDesc;
		NotifierDesc = RECORD (Oberon.TaskDesc)
			stream: PlugIns.Stream
		END;

	VAR
		cache: StreamList; createF: BOOLEAN;
		context: Objects.Object; rec: SIGNED32;

	PROCEDURE Error(plugin: PlugIns.PlugIn; CONST msg1, msg2: ARRAY OF CHAR);
		VAR W: Texts.Writer;
	BEGIN
		Texts.OpenWriter(W); Texts.WriteString(W, "HTMLPlugIns: ");
		Texts.WriteString(W, msg1); Texts.WriteString(W, msg2);
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
	END Error;

	PROCEDURE GetStream(plugin: PlugIns.PlugIn; url: ARRAY OF CHAR): PlugIns.Stream;
		VAR
			F: Files.File; M: HyperDocs.FetchMsg; s: HyperDocs.LinkScheme;
			stream: PlugIns.Stream; key, tkey: SIGNED32;
	BEGIN
		NEW(stream); PlugIns.InitStream(stream);
		stream.state := PlugIns.NetworkErr;
		key := HyperDocs.BuildKey(plugin.V(View).base, url);
		s := HyperDocs.LinkSchemeByKey(key);
		IF (s # NIL) & (key # HyperDocs.UndefKey) THEN
			HyperDocs.RetrieveLink(key, stream.url);
			IF s.prefix # "file" THEN
				HyperDocs.TempDocName(s.prefix, stream.file, tkey);
				F := Files.New(stream.file); Files.Set(M.R, F, 0);
				M.key := key; M.res := -1;
				s.handle(s, M);
				IF M.res = 0 THEN
					Files.Register(F); Files.GetName(F, stream.file);
					stream.state := PlugIns.Done
				END
			ELSE
				key := HyperDocs.SplitFileAdr(stream.url, stream.file, url);
				F := Files.Old(stream.file);
				IF F # NIL THEN
					Files.GetName(F, stream.file);
					stream.state := PlugIns.Done
				END
			END
		END;
		RETURN stream
	END GetStream;

	PROCEDURE DoNotify(me: Oberon.Task);
	BEGIN
		Oberon.Remove(me);
		Gadgets.Update(me(Notifier).stream)
	END DoNotify;

	PROCEDURE GetURL0(plugin: PlugIns.PlugIn; CONST url: ARRAY OF CHAR): SIGNED32;
		VAR notify: Notifier;
	BEGIN
		NEW(notify); notify.stream := GetStream(plugin, url);
		notify.handle := DoNotify; notify.safe := FALSE; notify.time := Oberon.Time();
		Oberon.Install(notify);
		RETURN notify.stream.state
	END GetURL0;

	PROCEDURE GetURL(plugin: PlugIns.PlugIn; CONST url: ARRAY OF CHAR): SIGNED32;
		VAR stream: PlugIns.Stream; sl: StreamList;
	BEGIN
		sl := cache;
		WHILE (sl # NIL) & ~PlugIns.SameURL(url, sl.stream.url) DO
			sl := sl.next
		END;
		IF sl = NIL THEN
			stream := GetStream(plugin, url);
			IF stream.state = PlugIns.Done THEN
				NEW(sl); sl.stream := stream;
				sl.next := cache; cache := sl
			END
		ELSE
			stream := sl.stream
		END;
		IF plugin.base = NIL THEN plugin.base := stream END;
		PlugIns.UpdateStream(plugin, stream);
		RETURN stream.state
	END GetURL;

	PROCEDURE FindContext(obj: Objects.Object; VAR M: Objects.ObjMsg);
	BEGIN
		context := M.dlink
	END FindContext;

	PROCEDURE FindPlugIn(V: View; VAR F: Objects.FindMsg);
		VAR M: Display.FrameMsg; handle: Objects.Handler;
	BEGIN
		INC(rec);
		IF rec <= 1 THEN
			handle := V.handle; V.handle := FindContext;
			M.F := V; Display.Broadcast(M);
			V.handle := handle;
			context.handle(context, F);
			IF (F.obj # NIL) & (F.obj IS View) THEN
				F.obj := F.obj(View).obj
			END;
			context := NIL
		END;
		DEC(rec)
	END FindPlugIn;

	PROCEDURE ViewHandler(view: Objects.Object; VAR M: Objects.ObjMsg);
	BEGIN
		WITH view: View DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.name # "Locked" THEN
						view.plugin.handle(view.plugin, M)
					END;
					IF M.res # 0 THEN
						Views.ViewHandler(view, M)
					END
				END
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF (M.id = Objects.get) & (M.name = "PlugIn") THEN
						M.obj := view.plugin; M.res := 0
					ELSE
						Views.ViewHandler(view, M)
					END
				END
			ELSIF M IS Objects.FindMsg THEN
				WITH M: Objects.FindMsg DO
					IF M.obj = NIL THEN FindPlugIn(view, M) END
				END
			ELSE
				Views.ViewHandler(view, M)
			END
		END
	END ViewHandler;

	PROCEDURE PlugInHandler(plugin: Objects.Object; VAR M: Objects.ObjMsg);
		VAR F: Display.Frame;
	BEGIN
		IF M IS Objects.LinkMsg THEN
			WITH M: Objects.LinkMsg DO
				IF (M.id = Objects.set) & (M.name = "Content") THEN
					WITH plugin: PlugIns.PlugIn DO
						plugin.getURL := GetURL0;
						F := M.obj(Display.Frame);
						Attributes.SetBool(plugin.V, "Locked", FALSE);
						plugin.V(Views.View).border := 0;
						F.X := 0; F.Y := 0;
						IF plugin.V.W > 0 THEN
							F.W := plugin.V.W
						ELSE
							plugin.V.W := F.W
						END;
						IF plugin.V.H > 0 THEN
							F.H := plugin.V.H
						ELSE
							plugin.V.H := F.H
						END;
						Links.SetLink(plugin.V, "Model", F);
						Attributes.SetBool(plugin.V, "Locked", TRUE)
					END
				ELSE
					PlugIns.Handler(plugin, M)
				END
			END
		ELSIF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF (M.id = Objects.get) & (M.name = "CreateObject") THEN
					M.class := Objects.Bool; M.b := createF; M.res := 0
				ELSE
					PlugIns.Handler(plugin, M)
				END
			END
		ELSE
			PlugIns.Handler(plugin, M)
		END
	END PlugInHandler;

	PROCEDURE InitPlugIn(plugin: PlugIns.PlugIn; V: View);
	BEGIN
		PlugIns.InitPlugIn(plugin); createF := TRUE;
		plugin.V := V; V.handle := ViewHandler;
		plugin.getURL := GetURL;
		plugin.error := Error;
		plugin.handle := PlugInHandler
	END InitPlugIn;

	PROCEDURE InitView(V: View; plugin: PlugIns.PlugIn);
	BEGIN
		Views.InitView(V);
		V.W := 0; V.H := 0;
		V.plugin := plugin;
		V.handle := ViewHandler
	END InitView;

	PROCEDURE EMBED(VAR S: HTMLDocs.Scanner; on: BOOLEAN);
		VAR V: View; plugin: PlugIns.PlugIn; url: PlugIns.URLStr; attr : ARRAY 64 OF CHAR; i: SIGNED32;
	BEGIN
		IF on THEN
			NEW(V); NEW(plugin);
			InitView(V, plugin); InitPlugIn(plugin, V);
			V.base := S.page.base;
			WHILE HTMLDocs.NextAttr(S, attr) DO
				Attributes.SetString(plugin, attr, S.value);
				IF attr = "SRC" THEN
					COPY(S.value, url)
				ELSIF attr = "WIDTH" THEN
					Strings.StrToInt(S.value, i); V.W := SHORT(i)
				ELSIF attr = "HEIGHT" THEN
					Strings.StrToInt(S.value, i); V.H := SHORT(i)
				END
			END;
			HTMLDocs.WriteObj(S.page, V);
			i := PlugIns.RequestURL(plugin, url)
		END
	END EMBED;

	PROCEDURE ClearCache;
		VAR res: SIGNED16;
	BEGIN
		WHILE cache # NIL DO
			IF ~Strings.Prefix("file", cache.stream.url) THEN
				Files.Delete(cache.stream.file, res)
			END;
			cache := cache.next
		END
	END ClearCache;

	PROCEDURE StartStop(P: HTMLDocs.Page);
	BEGIN
		ClearCache()
	END StartStop;

	PROCEDURE NewEMBED*;
		VAR e: HTMLDocs.ExtTag;
	BEGIN
		NEW(e);
		e.handle := EMBED;
		e.start := StartStop; e.stop := StartStop;
		HTMLDocs.newTag := e
	END NewEMBED;

	PROCEDURE install(VAR V: View; create: BOOLEAN): BOOLEAN;
		VAR
			url: PlugIns.URLStr; plugin: PlugIns.PlugIn; s: HyperDocs.LinkScheme;
			label: ARRAY 64 OF CHAR; port: SIGNED16; F: Files.File;
			i: SIGNED32; R: Texts.Reader; ch, end: CHAR;
	BEGIN
		Texts.OpenReader(R, Oberon.Par.text, Oberon.Par.pos);
		Texts.Read(R, ch);
		WHILE ~R.eot & ((ch <= " ") OR ~(R.lib IS Fonts.Font)) DO
			Texts.Read(R, ch)
		END;
		IF ch = '"' THEN
			Texts.Read(R, ch); end := '"'
		ELSE
			end := 0X
		END;
		i := 0;
		WHILE ~R.eot & (ch > " ") & (ch # end) & (R.lib IS Fonts.Font) DO
			url[i] := ch; INC(i); Texts.Read(R, ch)
		END;
		url[i] := 0X;
		NEW(V); NEW(plugin);
		InitView(V, plugin); InitPlugIn(plugin, V); createF := create;
		NEW(V.base); V.base.key := HyperDocs.BuildKey(NIL, url);
		s := HyperDocs.LinkSchemeByKey(V.base.key);
		COPY(s.prefix, V.base.prefix);
		HyperDocs.RetrieveLink(V.base.key, url);
		IF V.base.prefix = "http" THEN
			V.base.key := HTTPDocs0.SplitHTTPAdr(url, V.base.host, V.base.path, label, V.base.port)
		ELSIF V.base.prefix = "file" THEN
			V.base.key := HyperDocs.SplitFileAdr(url, V.base.path, label);
			F := Files.Old(V.base.path);
			IF F # NIL THEN
				Files.GetName(F, V.base.path);
				V.base.key := HyperDocs.BuildKey(NIL, url)
			END;
			V.base.host := ""; V.base.port := 0
		ELSE (* proxy *)
			HTMLDocs.SplitHostPort(url, V.base.host, V.base.port);
			V.base.key := HTTPDocs0.SplitHTTPAdr(url, V.base.host, V.base.path, label, port)
		END;
		IF V.base.key # HyperDocs.UndefKey THEN
			V.base.dockey := V.base.key;
			i := PlugIns.RequestURL(plugin, url);
			RETURN (i = 0) & (V.obj # NIL)
		END
	END install;

	(** HTMLPlugIns.Install url *)
	PROCEDURE Install*;
		VAR V: View;
	BEGIN
		IF install(V, FALSE) THEN END
	END Install;

	(** HTMLPlugIns.OpenAsDoc url *)
	PROCEDURE OpenAsDoc*;
		VAR D: Documents.Document; V: View;
	BEGIN
		IF install(V, TRUE) THEN
			IF V.obj IS Documents.Document THEN
				D := V.obj(Documents.Document)
			ELSE
				NEW(D); D.Load := NIL; D.Store := NIL; D.handle := Documents.Handler;
				D.dsc := V; D.W := V.W; D.H := V.H
			END;
			Desktops.ShowDoc(D)
		END
	END OpenAsDoc;

BEGIN
	cache := NIL; rec := 0;
	Modules.InstallTermHandler(ClearCache)
END HTMLPlugIns.

System.Set HTMLTags EMBED := HTMLPlugIns.NewEMBED ~
