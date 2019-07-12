(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(**
	TextPopups

	This module displays simple popup menus in TextDocs when clicking outside the text.
	The contents of the menus can be edited and are stored in the file "TextPopups.Text"

	This is an example of a menu description:

	[Mod]	<= applies for files with suffix .Mod
	Compiler.Compile *
	Compiler.Compile */s
	Compiler.Compile */f	<= commands that can be executed
	Decoder.Decode ^
	Analyzer.Analyze *
	--------------------
	<5 Recent Files>	<= include a list with the 5 recent files, you can also replace 5 by any other 	--------------------		number. These files can be opened directly by selecting the appropriate menu item
	<Procedures>	<= include a list of all procedures declared in the text file
			You can jump to the corresponding text position by selecting a menu item

	<Types>	<= include a list of all types declared in the text file
			You can jump to the corresponding text position by selecting a menu item
	[Text]	<= applies for files with suffix .Text
	TextDocs.SearchDiff /w
	--------------------
	<5 Recent Files>


	[Tool]	<= applies for files with suffix .Tool
	<5 Recent Files>

	...
*)

MODULE TextPopups IN Oberon;	(** portable *)	(* tk 6.12.95 *)

	(* some marked compiler calls are not portable - but can easily be adopted for different implementations *)

	IMPORT
		Modules, Display, Objects, OPM, OPS, ListRiders, Links, Attributes, Documents, Desktops,
		Texts, Oberon, Effects, Fonts, Display3, Gadgets, TextDocs, TextGadgets0, TextGadgets,
		Input, Views, Strings;

	CONST
		times = OPS.times; and = OPS.and; plus = OPS.plus; minus = OPS.minus;
		eql = OPS.eql; arrow = OPS.arrow; colon = OPS.colon; rparen = OPS.rparen;
		lparen = OPS.lparen; ident = OPS.ident; semicolon = OPS.semicolon;
		end = OPS.end; object = OPS.object; record = OPS.record; begin = OPS.begin;
		const = OPS.const; type = OPS.type; var = OPS.var; procedure = OPS.procedure;
		eof = OPS.eof;

		CR = 0DX;	TAB = 09X;	SPACE = " ";	LF = 0AX;
		MaxHistory = 20; MaxHeight = 250;
		PopupFileName = "TextPopups.Text";

	TYPE
		(* generic menu item *)
		MenuItem = POINTER TO MenuItemDesc;
		MenuItemDesc = RECORD	val: ARRAY 128 OF CHAR; link: MenuItem	END;

		(* oberon command *)
		CmdMenuItem = POINTER TO CmdMenuItemDesc;
		CmdMenuItemDesc = RECORD	(MenuItemDesc)	END;

		(* procedure name marker *)
		PMarkerMenuItem = POINTER TO PMarkerMenuItemDesc;
		PMarkerMenuItemDesc = RECORD	(MenuItemDesc) pos: LONGINT	END;

		(* type name marker *)
		TMarkerMenuItem = POINTER TO TMarkerMenuItemDesc;
		TMarkerMenuItemDesc = RECORD	(MenuItemDesc) pos: LONGINT	END;

		(* LaTeX section marker *)
		LMarkerMenuItem = POINTER TO LMarkerMenuItemDesc;
		LMarkerMenuItemDesc = RECORD	(MenuItemDesc) pos: LONGINT	END;

		(* file name marker *)
		FileMenuItem = POINTER TO FileMenuItemDesc;
		FileMenuItemDesc = RECORD	(MenuItemDesc)	END;

		(* list of recently opened files *)
		FileHistory = POINTER TO FileHistoryDesc;
		FileHistoryDesc = RECORD	filename: ARRAY 128 OF CHAR; link: FileHistory	END;

	VAR
		W: Texts.Writer; nofLines, width: INTEGER;
		itemList, lastItem: MenuItem; doItem: MenuItem; called: BOOLEAN;
		fileHistory: FileHistory;
		sections: ARRAY 7 OF ARRAY 14 OF CHAR;

(* execute a command *)

	PROCEDURE Call(F: TextGadgets.Frame; T: Texts.Text; x, y: INTEGER);
		VAR text: Texts.Text; R: Texts.Reader; res: INTEGER; cmd: ARRAY 64 OF CHAR;
			d: Documents.Document; C: Oberon.ControlMsg;
	BEGIN
		IF doItem=NIL THEN RETURN END;
		IF doItem IS PMarkerMenuItem THEN
			WITH doItem: PMarkerMenuItem DO
				TextDocs.SetCaret(F, T, doItem.pos)
			END
		ELSIF doItem IS TMarkerMenuItem THEN
			WITH doItem: TMarkerMenuItem DO
				TextDocs.SetCaret(F, T, doItem.pos)
			END
		ELSIF doItem IS LMarkerMenuItem THEN
			WITH doItem: LMarkerMenuItem DO
				TextDocs.SetCaret(F, T, doItem.pos)
			END
		ELSIF doItem IS CmdMenuItem THEN
			WITH doItem: CmdMenuItem DO
				NEW(text); Texts.Open(text, ""); Texts.WriteString(W, doItem.val);
				Texts.WriteLn(W); Texts.Append(text, W.buf);
				Texts.OpenReader(R, text, 0);
				res:=0; REPEAT Texts.Read(R, cmd[res]); INC(res) UNTIL cmd[res-1]<=" ";
				cmd[res-1]:=0X;
				Oberon.FadeCursor(Oberon.Pointer);
				Oberon.Pointer.X:=x; Oberon.Pointer.Y:=y;
				C.F := F; C.id := Oberon.mark; C.X := x; C.Y := y;
				Display.Broadcast(C);
				Oberon.Par.text:=text; Oberon.Par.pos:=Texts.Pos(R)-1;
				Oberon.Call(cmd, Oberon.Par, FALSE, res);
				Oberon.FadeCursor(Oberon.Pointer)
			END
		ELSIF doItem IS FileMenuItem THEN
			WITH doItem: FileMenuItem DO
				d:=Documents.Open(doItem.val); Desktops.ShowDoc(d);
			END
		END
	END Call;

	PROCEDURE Do*;
		VAR S: Texts.Scanner; p: MenuItem; i: INTEGER;
	BEGIN	called:=TRUE;
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
		IF (S.class=Texts.String) OR (S.class=Texts.Name) THEN
			p:=itemList.link;
			LOOP
				IF p=NIL THEN EXIT END;
				i:=0; WHILE (S.s[i]#0X) & (p.val[i]#0X) & (p.val[i]=S.s[i]) DO INC(i) END;
				IF  (p.val[i]="^") & (S.s[i]#"*") OR (p.val[i]=S.s[i]) THEN EXIT ELSE p:=p.link END;
			END;
			doItem:=p;
		ELSE doItem:=NIL END
	END Do;

	PROCEDURE AppendToTypeList(VAR list, last: MenuItem; CONST context, name: ARRAY OF CHAR; pos: LONGINT);
		VAR t: TMarkerMenuItem; q: MenuItem;
	BEGIN
		NEW(t); COPY(context, t.val); Strings.Append(t.val, name); t.pos := pos;
		q := list; WHILE (q.link # NIL) & (q.link.val < t.val) DO q := q.link END;
		IF q.link = NIL THEN last := t END; t.link := q.link; q.link := t;
	END AppendToTypeList;

(* build item list *)
	PROCEDURE ExtractProcTypeNames(T: Texts.Text; VAR lastProc, lastType: MenuItem);
		CONST	rec = 0; proc = 1; mod = 2;
		VAR R: Texts.Reader; isType, init: BOOLEAN; sym, prevsym: SHORTINT;
			Stack: ARRAY 16 OF SHORTINT; ST, i: LONGINT; j: SIZE;
			Context, name: ARRAY 128 OF CHAR;startP, startT, q: MenuItem; p: PMarkerMenuItem;
	BEGIN
		Texts.OpenReader(R, T, 0);
		OPM.Init({}, {}, R, Oberon.Log(*Null*)); OPS.Init; startP := lastProc; startT := lastType; isType := FALSE;
		ST := 0; Stack[ST] := mod; Context := ""; OPS.Get(sym);
		REPEAT
			IF (sym = ident) & (OPS.name = "DEFINITION") THEN
				OPS.Get(sym);
				IF sym = ident THEN
					AppendToTypeList(startT, lastType, "", OPS.name, OPM.curpos-1);
				END;
				REPEAT OPS.Get(sym) UNTIL (sym = end) OR (sym = eof);
			ELSIF sym = type THEN
				isType := TRUE; OPS.Get(sym)
			ELSIF (sym = ident) & isType THEN
				COPY(OPS.name, name); i := OPM.curpos-1;
				OPS.Get(sym);
				IF sym = times THEN OPS.Get(sym) END;
				IF (sym =  eql) THEN
					AppendToTypeList(startT, lastType, Context, name, i);
					OPS.Get(sym);
					IF sym=procedure THEN
						OPS.Get(sym);
						IF sym = lparen THEN
							WHILE (sym#rparen)&(sym#eof) DO OPS.Get(sym) END
						END
					END
				END
			ELSIF (sym = const) OR (sym = var) OR (sym = begin) THEN
				isType := FALSE;
				OPS.Get(sym)
			ELSIF (sym = record) OR (sym = object) THEN
				INC(ST); Stack[ST] := rec; Strings.Append(Context, name); Strings.AppendCh(Context, ".");
				isType := FALSE;
				OPS.Get(sym)
			ELSIF (sym = procedure) & ((prevsym # colon) & (prevsym # eql)) THEN	(*procdecl*)
				OPS.Get(sym);
				IF sym # arrow THEN	(*skip forw*)
					IF sym = lparen THEN	(*O2-method*)
						OPS.Get(sym);
						IF sym = var THEN OPS.Get(sym) END;
						IF sym = ident THEN OPS.Get(sym);
							OPS.Get(sym);	(*colon*)
							IF sym = ident THEN
								COPY(OPS.name, Context); Strings.AppendCh(Context, ".");
								OPS.Get(sym)
							END
						END
					END;
					init := sym = and;
					IF (sym=and) OR (sym=minus) OR (sym=plus) OR (sym=times) THEN OPS.Get(sym) END;	(*skip &, -, ... *)
					IF sym = ident THEN
						COPY(OPS.name, name);
						NEW(p); COPY(Context, p.val); Strings.Append(p.val, name); p.pos := OPM.curpos-1;
						q := startP; WHILE (q.link # NIL) & (q.link.val < p.val) DO q := q.link END;
						IF q.link = NIL THEN lastProc := p END; p.link := q.link; q.link := p;
						INC(ST); Stack[ST] := proc; Strings.Append(Context, name); Strings.AppendCh(Context, ".");
						isType := FALSE
					END
				END;
				OPS.Get(sym)
			ELSIF (Stack[ST] = rec)&(sym = end) OR (Stack[ST] = proc)&(prevsym=end)&(sym=ident) THEN
				isType := (Stack[ST] = rec)OR(Stack[ST-1] = rec);
				DEC(ST);
				j := Strings.Length(Context)-2;
				WHILE (j>0) & (Context[j]#".") DO DEC(j) END;
				IF j <= 0 THEN Context[0] := 0X ELSE Context[j+1] := 0X END;
				OPS.Get(sym)
			ELSIF (sym = ident) THEN
				REPEAT OPS.Get(sym) UNTIL (sym = semicolon) OR (sym = end) OR (sym = eof);
			ELSE
				prevsym := sym; OPS.Get(sym)
			END
		UNTIL sym = eof;
		OPM.Close;  OPS.Init
	END ExtractProcTypeNames;

	PROCEDURE ExtractHistory(nof: INTEGER);
		VAR h: FileHistory; q: FileMenuItem;
	BEGIN
		h:=fileHistory; WHILE (h#NIL) & (nof>0) DO
			NEW(q); COPY(h.filename, q.val); lastItem.link:=q; lastItem:=q;
			h:=h.link; DEC(nof)
		END;
	END ExtractHistory;

	(* Extract LaTeX sections *)

	PROCEDURE ExtractSections(t: Texts.Text);
	VAR r: Texts.Reader; i, j: LONGINT; q: LMarkerMenuItem; s: ARRAY 1024 OF CHAR; ch: CHAR;
	BEGIN
		Texts.OpenReader(r, t, 0); Texts.Read(r, ch);
		WHILE ~r.eot DO
			IF ch = "%" THEN	(* comment till end of line *)
				REPEAT Texts.Read(r, ch) UNTIL r.eot OR (ch = 0DX)
			ELSIF ch = "\" THEN	(* command *)
				i := 0;	(* read command *)
				LOOP
					Texts.Read(r, ch);
					IF r.eot OR (CAP(ch) < "A") OR (CAP(ch) > "Z") THEN EXIT END;
					IF i < LEN(s)-1 THEN s[i] := ch; INC(i) END
				END;
				IF i # 0 THEN	(* command found *)
					s[i] := 0X;	(* check if section command *)
					j := 0; WHILE (j # LEN(sections)) & (s # sections[j]) DO INC(j) END;
					IF (j = LEN(sections)) & (s = "title") THEN j := 0 END;	(* treat \title like \part *)
					IF j # LEN(sections) THEN	(* section command level j, get parameter *)
						IF ch = "*" THEN Texts.Read(r, ch) END;
						IF ch = "{" THEN	(* read command parameter *)
							i := 0; WHILE i # 2*j DO s[i] := " "; INC(i) END;	(* indent *)
							Texts.Read(r, ch); j := 0;	(* j counts { } nesting level *)
							WHILE ~r.eot & ((ch # "}") OR (j # 0)) & (i < LEN(s)-1) DO
								IF ch = "{" THEN INC(j)
								ELSIF ch = "}" THEN DEC(j)
								END;
								s[i] := ch; INC(i); Texts.Read(r, ch)
							END;
							s[i] := 0X;
								(* append menu item *)
							NEW(q); COPY(s, q.val); q.pos := Texts.Pos(r);
							lastItem.link := q; lastItem := q
						END
					END
				END
			ELSE	(* other character *)
				Texts.Read(r, ch)
			END
		END
	END ExtractSections;

	(* Extract BibTeX entries *)

	PROCEDURE ExtractBibtex(t: Texts.Text);
	VAR r: Texts.Reader; i, j: LONGINT; first, p: MenuItem; q: LMarkerMenuItem; s, e: ARRAY 64 OF CHAR; ch: CHAR;
	BEGIN
		first := lastItem;
		Texts.OpenReader(r, t, 0); Texts.Read(r, ch);
		WHILE ~r.eot DO
			IF ch = "%" THEN	(* comment till end of line *)
				REPEAT Texts.Read(r, ch) UNTIL r.eot OR (ch = 0DX)
			ELSIF ch = "@" THEN	(* bibtex entry *)
				i := 0;	(* read entry *)
				LOOP
					Texts.Read(r, ch);
					IF r.eot OR (CAP(ch) < "A") OR (CAP(ch) > "Z") THEN EXIT END;
					IF i < LEN(s)-1 THEN e[i] := CHR(ORD(CAP(ch))+32); INC(i) END
				END;
				IF i # 0 THEN	(* entry found *)
					e[i] := 0X;	(* check if legal entry *)
					IF e # "string" THEN
						WHILE ~r.eot & ((ch = " ") OR (ch = 0DX) OR (ch = 9X)) DO Texts.Read(r, ch) END;
						IF ch = "{" THEN	(* read parameter *)
							REPEAT Texts.Read(r, ch) UNTIL r.eot OR ((ch # " ") & (ch # 0DX) & (ch # 9X));
							i := 0; j := 0;
							WHILE ~r.eot & (ch # ",") & (ch # CR) & (i < LEN(s)-1) DO
								s[i] := ch; INC(i); Texts.Read(r, ch)
							END;
							s[i] := " "; INC(i);
							s[i] := "("; INC(i);
							WHILE e[j] # 0X DO s[i] := e[j]; INC(i); INC(j) END;
							s[i] := ")"; INC(i);
							s[i] := 0X;
							NEW(q); COPY(s, q.val); q.pos := Texts.Pos(r);
							(*sort entries*)
							p := first;
							WHILE (p.link # NIL) & (p.link.val < q.val) DO p := p.link END;
							q.link := p.link; p.link := q
							(* lastItem.link := q; lastItem := q *)
						END
					END
				END
			ELSE	(* other character *)
				Texts.Read(r, ch)
			END
		END;
		WHILE first.link # NIL DO first := first.link END;
		lastItem := first
	END ExtractBibtex;

	PROCEDURE CreateMenuItems(listR: ListRiders.Rider; T: Texts.Text; CONST ext: ARRAY OF CHAR): BOOLEAN;
		VAR p: MenuItem; w, h, dsr: INTEGER; R: Texts.Reader; cmd: CmdMenuItem; text: Texts.Text;
			s: ARRAY 128 OF CHAR; ch: CHAR; d: ListRiders.String;
			plist, tlist, plast, tlast: MenuItem; parsed: BOOLEAN;

		PROCEDURE Scan;
			VAR i: INTEGER;
		BEGIN i:=0; s[0]:=0X; Texts.Read(R, ch);
			WHILE ~R.eot & (ch#"[") & (ch#"]") & (ch#CR) & (ch#LF) DO s[i]:=ch; INC(i); Texts.Read(R, ch) END; s[i]:=0X;
		END Scan;

	BEGIN
		IF listR = NIL THEN RETURN FALSE END;
		nofLines:=0; width:=0; NEW(itemList); lastItem:=itemList;
		NEW(plist); plast := plist; NEW(tlist); tlast := tlist; parsed := FALSE;
		NEW(text); Texts.Open(text, PopupFileName); Texts.OpenReader(R, text, 0);
		LOOP
			REPEAT	Texts.Read(R, ch)	UNTIL R.eot OR (ch="[");
			IF	R.eot	THEN	RETURN FALSE	ELSE	Scan	END;
			IF	s=ext	THEN	EXIT	END;
		END;
		REPEAT
			Scan;
			IF s="" THEN (* ignore *)
			ELSIF s = "<Procedures>" THEN
				IF ~parsed THEN ExtractProcTypeNames(T, plast, tlast); parsed := TRUE END;
				IF plist.link # NIL THEN lastItem.link := plist.link; lastItem := plast END
			ELSIF s = "<Types>" THEN
				IF ~parsed THEN ExtractProcTypeNames(T, plast, tlast); parsed := TRUE END;
				IF tlist.link # NIL THEN lastItem.link := tlist.link; lastItem := tlast END
			ELSIF s = "<LaTeXSections>" THEN
				ExtractSections(T)
			ELSIF s = "<BibTeXEntries>" THEN
				ExtractBibtex(T)
			ELSIF s[0]="<" THEN (* recent files *)
				h:=1; w:=0; WHILE (s[h]#0X) & (s[h]>="0") & (s[h]<="9") DO
					w:=w*10+ORD(s[h])-ORD("0"); INC(h)
				END;
				ExtractHistory(w);
			ELSE
				NEW(cmd); lastItem.link:=cmd; lastItem:=cmd; cmd.link:=NIL; COPY(s, cmd.val);
			END
		UNTIL R.eot OR (ch="[");
		p:=itemList.link;
		WHILE p # NIL DO
			NEW(d); COPY(p.val, d.s); listR.do.Write(listR, d);
			Display3.StringSize(p.val, Fonts.Default, w, h, dsr);
			IF w+25>width THEN width:=w+25 END;
			INC(nofLines); p:=p.link
		END;
		RETURN TRUE
	END CreateMenuItems;

	PROCEDURE GetFileExtension(CONST name: ARRAY OF CHAR; VAR ext: ARRAY OF CHAR);
		VAR i, j, l: INTEGER;
	BEGIN	i:=0; l:=0;
		WHILE name[i]#0X DO
			IF name[i]="." THEN l:=i+1 END;
			INC(i)
		END;
		IF l=0 THEN l:=i END;
		j := 0; WHILE (j < LEN(ext)-1) & (name[l] # 0X) & (name[l] > " ") DO ext[j] := name[l]; INC(l); INC(j) END;
		ext[j]:=0X;
	END GetFileExtension;

	PROCEDURE NewList(F: TextGadgets.Frame; D: Documents.Document): Gadgets.Frame;
		VAR L: Gadgets.Frame; obj: Objects.Object; M: ListRiders.ConnectMsg; ext: ARRAY 12 OF CHAR;
	BEGIN
		GetFileExtension(D.name, ext);
		L := NIL;
		obj := Gadgets.CreateObject("ListModels.NewList");
		IF obj # NIL THEN
			Attributes.SetBool(obj, "Sorted", FALSE);
			M.R := NIL; obj.handle(obj, M);
			IF CreateMenuItems(M.R, F.text, ext) THEN
				IF nofLines > 0 THEN
					obj := Gadgets.CreateObject("ListGadgets.NewFrame");
					IF obj # NIL THEN
						L := obj(Gadgets.Frame);
						L.H := nofLines*Fonts.Default.height + 8;
						IF L.H > MaxHeight THEN L.H := MaxHeight END;
						IF L.H > Display.Height-50 THEN L.H := Display.Height - 50 END; L.W := width;
						Attributes.SetBool(L, "MultiSel", FALSE);
						Attributes.SetString(L, "Cmd", "TextPopups.Do '#Point'");
						Links.SetLink(L, "Model", M.R.base)
					END
				END
			END
		END;
		RETURN L
	END NewList;

	PROCEDURE CalcPlace(VAR x, y, px, py, w, h: INTEGER);
		VAR cx, cy, cw, ch: INTEGER;
	BEGIN
		cx := 10; cy := 10; cw := Display.Width - 10; ch := Display.Height - 10;
		px := x - w DIV 2; py := y - h DIV 2;
		IF px < cx THEN px := cx; END;
		IF px + w >= cx + cw THEN px := cx + cw - 1 - w; END;
		IF py < cy THEN py := cy; END;
		IF py + h >= cy + ch THEN py := cy + ch - 1 - h END;
	END CalcPlace;

	PROCEDURE Popup(F: TextGadgets.Frame; x, y: INTEGER; VAR M: Oberon.InputMsg);
		VAR block: Views.Block; of: Gadgets.Frame; R: Display3.Mask; px, py: INTEGER;
				CM: Display.ControlMsg; D: Display.DisplayMsg; O: Display3.OverlapMsg;
	BEGIN
		of:=NewList(F, M.dlink(Documents.Document));
		IF of # NIL THEN
			CalcPlace(x, y, px, py, of.W, of.H);
			Oberon.RemoveMarks(px, py, of.W, of.H);
			Views.GetBlock(px, py, of.W, of.H, M.dlink, block);
			CM.id := Display.restore; CM.F := of; CM.x := 0; CM.y := 0; CM.res := -1; CM.dlink := NIL; of.handle(of, CM);
			O.F := of; O.M := NIL; O.x := 0; O.y := 0; O.res := -1; O.dlink := NIL; of.handle(of, O);
			D.device := Display.screen; D.id := Display.full; D.F := of; D.res := -1; D.dlink := M.dlink;
			D.x := px - of.X; D.y := py - of.Y; of.handle(of, D);
			called:=FALSE;
			Gadgets.MakeMask(of, px, py, M.dlink, R);
			Input.Mouse(M.keys, M.X, M.Y);
			M.x := px - of.X; M.y := py - of.Y;
			WHILE (M.keys # {}) & (M.res < 0) DO
				of.handle(of, M);
				Input.Mouse(M.keys, M.X, M.Y);
				Oberon.DrawCursor(Oberon.Mouse, Effects.Arrow, M.X, M.Y)
			END;
			Oberon.FadeCursor(Oberon.Mouse);
			Views.RestoreBlock(block);
			IF called THEN Call(F, F.text, x, y) END;
			M.res := 0
		END
	END Popup;

(* file history *)

	PROCEDURE InsertIntoHistory(VAR D: Documents.Document);
		VAR h: FileHistory; i: INTEGER;
	BEGIN	IF D=NIL THEN RETURN END;
		h:=fileHistory; WHILE (h#NIL) & (h.filename#D.name) DO h:=h.link END;
		IF h=NIL THEN
			NEW(h); COPY(D.name, h.filename); h.link:=fileHistory; fileHistory:=h;
			i:=0; WHILE (h#NIL) & (i<MaxHistory) DO h:=h.link; INC(i) END;
			IF h#NIL THEN h.link:=NIL END;
		END
	END InsertIntoHistory;

(* doc and text handler *)

	PROCEDURE PopupHandler(F: Objects.Object; VAR M: Objects.ObjMsg);
		VAR x, y, X, Y: INTEGER; R: Texts.Reader; l: TextGadgets0.Loc; ch: CHAR; keys: SET;
	BEGIN
		WITH F: TextGadgets.Frame DO
			IF M IS Oberon.InputMsg THEN
				WITH M: Oberon.InputMsg DO
					IF M.id=Oberon.track THEN
						x := M.x + F.X; y := M.y + F.Y;
						Input.Mouse(keys, X, Y);
						IF (X-x>14) (* sliderW *) & (M.keys={1}) THEN
							F.do.LocateChar(F, x, y, X, Y, l);
							Texts.OpenReader(R, F.text, l.pos); Texts.Read(R, ch);
							IF (M.dlink IS Documents.Document) & ((R.lib = NIL) OR (R.lib IS Fonts.Font)) & ((ch = CR) OR (ch = TAB) OR (ch = SPACE) OR (ch=0X) & (l.pos>=F.text.len)) THEN
								Popup(F, X, Y, M)
							END
						END
					END
				END
			END
		END
	END PopupHandler;

	PROCEDURE Install*;
	BEGIN
		TextGadgets.popupHook:=PopupHandler; Documents.historyHook:=InsertIntoHistory
	END Install;

	PROCEDURE Remove*;
	BEGIN
		TextGadgets.popupHook:=NIL; Documents.historyHook:=NIL
	END Remove;

BEGIN
	sections[0] := "part"; sections[1] := "chapter"; sections[2] := "section"; sections[3] := "subsection";
	sections[4] := "subsubsection"; sections[5] := "paragraph"; sections[6] := "subparagraph";
	Texts.OpenWriter(W);  Modules.InstallTermHandler(Remove);
	Texts.WriteString(W, "TextPopups using ");  Texts.WriteString(W, PopupFileName);
	Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf)
END TextPopups.

System.Free TextPopups ~
TextPopups.Install
TextPopups.Remove
