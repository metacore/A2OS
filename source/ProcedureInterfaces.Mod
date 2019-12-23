MODULE ProcedureInterfaces; (** AUTHOR "Patrick Hunziker"; PURPOSE "display procedure interfaces in real-time while editing source code" *)

(* Usage: toggle on/off in a PET window by CTRL-I *)

(* alpha version - subject to potential change/removal - request for comments *) 
(* uses the compiler's capabilities through use of the well-structured symbol files, instead of adding an own parser *)
(* in the future, this can be extended by further functionality like auto-fill-in an interface by clicking on the popup, or similar*)
IMPORT
	Texts, TextUtilities, WMEditors,WMPopups, Streams, Strings, Files,Modules, Commands,WMComponents, WMWindowManager, Options, Lists:=FoxBasic; (*Lists:=Lists(Module)*)

#IF AMD64 THEN	
	CONST Suffix=".SymWw";
#ELSIF Linux64 THEN
	CONST Suffix=".SymUu";
#END
	
CONST Trace=FALSE;

TYPE	
	Module*= POINTER TO RECORD
		name*: ARRAY 64 OF CHAR;
	END;

	Object*= POINTER TO RECORD
		name*: ARRAY 64 OF CHAR;
		path*, super*: ARRAY 256 OF CHAR;
	END;
	
	Procedure*= POINTER TO RECORD
		name*: ARRAY 1024 OF CHAR;
		path*: ARRAY 1024 OF CHAR;
		interface*: ARRAY 1024 OF CHAR;
	END;

PROCEDURE Find(list:Lists.List; CONST name: ARRAY OF CHAR; VAR pos: SIZE);
VAR found: BOOLEAN;
BEGIN
	ASSERT((pos>=0)&(pos<list.Length()),200);
	found:=FALSE;
	WHILE (pos<list.Length())& ~found DO
		found:= list.Get(pos)(Procedure).name=name;
		INC(pos);
	END;
	IF found THEN DEC(pos) END;
END Find;

PROCEDURE Greater(l,r:ANY):BOOLEAN;
BEGIN 
	RETURN l(Procedure).name>r(Procedure).name 
END Greater;

(* editor plug-in functionality for building an procedure/method interface list, and showing compatible interfaces as popups or in a text 
produces lists of modules, objects and exported procedures/methods.
currently, only SELF and first level of imported interfaces is parsed for global procedures and methods.
recursion into import-imports at higher level not yet done.
*)
TYPE InterfaceFinder*= OBJECT
	VAR mList*, pList*, oList*:Lists.List; (*list of modules, objects, procedures/methods*)
		text: Texts.Text;
		editor:WMEditors.Editor;
		tr: TextUtilities.TextReader;
		w:Streams.Writer;
		nModules: INTEGER;
		oldString:ARRAY 256 OF CHAR;
		popups:BOOLEAN;
		popup: WMPopups.Popup;
				
	PROCEDURE InitText(t:Texts.Text; levels:INTEGER);
	VAR string:ARRAY 64 OF CHAR; from: SIZE; mod:Module; 
	BEGIN
		SELF.text:=t;
		NEW(tr,t); 
		IF mList=NIL THEN NEW(mList, 16) END;		
		WHILE tr.GetString(string) & ( Strings.Pos("MODULE",string)<0) DO
			from:=tr.Pos();
		END;
		IF Strings.Pos("MODULE",string)>=0 THEN 
			IF tr.GetString(string) THEN (*parse self, if symbol file already exists*)
				NEW(mod); COPY(string,mod.name);
				Strings.TrimRight(mod.name,";");
				Strings.Append(mod.name,Suffix);
				ParseModule(mod.name,levels,FALSE);
				mList.Add(mod);
				INC(nModules);
			END;
		END; 
		ParseImports(levels);
	END InitText;
			
	PROCEDURE ParseOneImport(r:Streams.Reader; VAR s:ARRAY OF CHAR;VAR hasMore:BOOLEAN):BOOLEAN;
	VAR i:SIZE; ch:CHAR;
	BEGIN
		i:=0;
		s:="";
		WHILE (r.res=Streams.Ok)&(r.Peek()#",")&(r.Peek()#";") DO
			ch:=r.Get();
			IF ch="=" THEN i:=0 (* reset when encountering an alias, and get only right-hand side *)
			ELSIF (ch=" ") OR (ch=09X) OR (ch=0AX) OR (ch=0DX)  THEN (*skip white space*)
			ELSE
				s[i]:=ch;
				INC(i)
			END;
		END;
		s[i]:=0X;
		IF r.Peek()="," THEN hasMore:=TRUE; ch:=r.Get(); 
		ELSIF r.Peek()=";" THEN hasMore:=FALSE; ch:=r.Get(); 
		END;
		RETURN i>0;
	END ParseOneImport;
	
PROCEDURE ParseImports(levels: INTEGER);
	VAR string:ARRAY 64 OF CHAR; from: SIZE; mod:Module; i:SIZE;
		hasMore:BOOLEAN;
	BEGIN
		WHILE tr.GetString(string) & ( Strings.Pos("IMPORT",string)<0) DO
			from:=tr.Pos();
		END;
		IF tr.res#Streams.Ok THEN 
			RETURN
		ELSE
			hasMore:=TRUE;
			WHILE hasMore & ParseOneImport(tr,string,hasMore) DO
				NEW(mod);
				COPY(string,mod.name); 
				Strings.Append(mod.name, Suffix);
				ParseModule(mod.name, levels,TRUE);
				mList.Add(mod);
				INC(nModules);
			END;
			pList.Sort(Greater);
			IF Trace THEN
				w.String("number of modules parsed: "); w.Int(nModules,0); w.Ln; w.Update;	
				FOR i:=0 TO pList.Length()-1 DO
					w.String(pList.Get(i)(Procedure).name); w.Ln; w.Update;
				END;		
			END;
			RETURN
		END;
		END ParseImports;

	(* parse procedures and object methods in module*)
	PROCEDURE ParseModule(CONST mName: ARRAY OF CHAR; levels:INTEGER; exportedOnly:BOOLEAN); (*recursion for import-imports/ supertypes not yet implemented*)
	VAR 
		mod, s,s0, type: ARRAY 1024 OF CHAR;
		proc:Procedure;
		obj: Object;
		nP,pos,posStop:SIZE;
		r:Files.Reader; f:Files.File;
	BEGIN
		IF pList=NIL THEN NEW(pList,128) END;
		f:=Files.Old(mName); 
		IF f#NIL THEN
			nP:=0;
			Files.OpenReader(r,f,0);
			IGNORE r.GetString(mod); (*"MODULE "*) 
			IGNORE r.GetString(mod); (* module name*)
			pos:=Strings.Pos(";",mod); IF pos>0 THEN mod[pos]:=0X END;
			WHILE r.res=Files.Ok DO
				r.Ln(s);
				pos:=Strings.Pos("OBJECT",s);
				IF pos>0 THEN 
					IF oList=NIL THEN NEW(oList,16) END;
					NEW(obj);
					COPY(s,type); Strings.Delete(type,0,1);
					pos:=Strings.Pos("(",type);
					IF pos>0 THEN posStop:=Strings.Pos(")",type);
						COPY(Strings.Substring(pos+1,posStop-1,type)^,obj.super);
					ELSE posStop:=pos;
					END;
					posStop:=Strings.Pos("*",type); 
					IF posStop>0 THEN type[posStop]:=0X END;
					posStop:=Strings.Pos("=",type);
					IF posStop>0 THEN type[posStop]:=0X END;
					Strings.Trim(type, " ");		
					COPY(type,obj.name);
					oList.Add(obj);	
					r.Ln(s) ;
				END;
				pos:=Strings.Pos("PROCEDURE ^",s);
				IF pos>0 THEN
					NEW(proc);
					Strings.Delete(s,0,pos+12);
					COPY(s,s0);
					IF s0[1]="&" THEN Strings.Delete(s0,0,3) END;
					COPY(mod,proc.path); Strings.Append(proc.path,"."); 
					IF pos=1 THEN (*global proc*)
					ELSIF pos=2 THEN (* method*)
						Strings.Append(proc.path, type); Strings.Append(proc.path,".");
					ELSE HALT(200)
					END;
					pos:=Strings.Pos("*",s0); 
					IF (pos>0) OR ~exportedOnly THEN (*exported procedures/methods, optional nonexported*)
						IF pos>0 THEN s0[pos]:=0X 
						ELSE 
							pos:=Strings.Pos("(",s0); 
							IF pos>0 THEN s0[pos]:=0X 
							ELSE
								pos:=Strings.Pos(";",s0); 
								IF pos>0 THEN s0[pos]:=0X END;
							END;
						END;
						Strings.Append(proc.path,s0);
						COPY(s0,proc.name);
						COPY(proc.path, proc.interface); 
						pos:=Strings.Pos("(", s); 
						IF pos>0 THEN Strings.Delete(s,0,pos); Strings.Append(proc.interface,s) END;
						INC(nP);
						pList.Add(proc);
					END;
				END;
			END;
			IF Trace THEN w.String(mName);w.String(" procedures read: "); w.Int(nP,0); w.Ln; w.Update; END;
		ELSE
			w.String("Procedure Interface file not found: "); w.String(mName); w.Ln; w.Update;
		END;
	END ParseModule;
	
	PROCEDURE HandlePopup(sender,param:ANY);
	BEGIN
	END HandlePopup;
	
	PROCEDURE FindProcedure(sender,par:ANY);(* find procedure interface while keyboard intering*)
	VAR pos:SIZE;
	BEGIN
			IF editor.tv.cursor#NIL THEN 
				pos:=editor.tv.cursor.GetPosition();
				CreatePopup(pos-2);
			END;
	END FindProcedure;
	
	PROCEDURE PointerMove(x, y : SIZE; keys : SET; VAR handled : BOOLEAN); (* find procedure interface when mouse over ...*)
	VAR pos: SIZE; 
	BEGIN
		editor.tv.ViewToTextPos(x,y,pos);		
		CreatePopup(pos);
		handled:=FALSE; (* more stuff like drag/drop may follow*)
	END PointerMove;
	
	PROCEDURE CreatePopup(pos0:SIZE);
	VAR a,b,dotPos, size, x,y,gx, gy, pos, internalPos: SIZE; 
		s,s0: ARRAY 256 OF CHAR; 
		found:BOOLEAN;
	BEGIN
		internalPos := editor.tv.GetInternalPos(pos0);
		(*internalPos := pos0;*)
		editor.tv.FindCommand(internalPos, a, b);
		size:=0;
		TextUtilities.SubTextToStrAt(text, a, b-a, size, s);
		Strings.TrimLeft(s,"("); 
		pos:=Strings.Pos("(",s); 
		WHILE pos>0 DO s[pos]:=0X; pos:=Strings.Pos("(",s) END;
		pos:=Strings.Pos(";",s); 
		IF pos=0 THEN Strings.Delete(s,0,1)
		ELSIF pos>0 THEN s[pos]:=0X 
		END;
		dotPos:=Strings.Pos(".",s);
		COPY(s,s0);
		WHILE (dotPos>0) & (dotPos<Strings.Length(s0)-1) DO
			Strings.Delete(s0,0,dotPos+1);
			dotPos:=Strings.Pos(".",s0);
		END;
		pos:=0;found:=FALSE;
		IF (Strings.Length(s0)>0) THEN
			IF popup#NIL THEN popup.Close END;
			IF popups THEN NEW(popup) END;
			WHILE (pos>=0) & (pos<pList.Length()) DO
				Find(pList,s0,pos);
				IF (pos>=0)&(pos<pList.Length()) THEN 
					found:=TRUE; 
					IF popups THEN 
						popup.Add(pList.Get(pos)(Procedure).interface,HandlePopup);
					ELSE
						w.String("*** "); w.String(pList.Get(pos)(Procedure).interface); w.Ln; w.Update;
					END;
					INC(pos);
					COPY(s0,oldString);
				END;
			END;
			IF popups & editor.tv.FindScreenPos(pos0,x,y) THEN
				editor.tv.ToWMCoordinates(x,y,gx,gy);
				popup.Popup0(gx+20,gy+10,FALSE, {WMWindowManager.FlagStayOnTop, WMWindowManager.FlagHidden}) 
			ELSE	w.Update
			END;
		ELSE 
			IF popup#NIL THEN popup.Close END;
		END;
	END CreatePopup;
	 
	PROCEDURE StartPosOwner(x,y:SIZE; VAR PointerOwner:WMComponents.VisualComponent; VAR handled:BOOLEAN);
	CONST Levels=1
	VAR owner: WMComponents.VisualComponent; type:Modules.TypeDesc; i:SIZE;
	BEGIN
		owner:=PointerOwner.GetPositionOwner(x,y);
		IF (type # NIL) THEN type := Modules.TypeOf(owner); TRACE("found",type.mod.name, type.name) END;
		IF owner IS WMEditors.Editor THEN
			editor:=owner(WMEditors.Editor);
			IF editor#NIL THEN 
				editor.SetExtInterface(SELF);
				InitText(editor.text, Levels);
				editor.text.onTextChanged.Add(FindProcedure);
				editor.tv.SetExtPointerMoveHandler(PointerMove);
				editor.GetVisualComponentRoot().SetExtGetPositionOwnerHandler(NIL);
				BEGIN{EXCLUSIVE}
					IF Trace THEN
						FOR i:=0 TO mList.Length()-1 DO
							w.String(mList.Get(i)(Module).name); w.Ln; w.Update;
						END;
					END;
				END;
				handled:=TRUE;
			ELSE HALT(200) 
			END;
		ELSIF owner=PointerOwner THEN 
			handled:=FALSE;
		ELSE(*recursion*)
			StartPosOwner(x-owner.bounds.Get().l,y-owner.bounds.Get().t, owner, handled)
		END;
		PointerOwner:=owner;
	END StartPosOwner;
	
	PROCEDURE StopPosOwner(x,y:SIZE; VAR PointerOwner:WMComponents.VisualComponent; VAR handled:BOOLEAN);
	VAR owner: WMComponents.VisualComponent; type:Modules.TypeDesc;
	BEGIN
		owner:=PointerOwner.GetPositionOwner(x,y);
		IF (type # NIL) THEN type := Modules.TypeOf(owner); TRACE("found",type.mod.name, type.name) END;
		IF owner IS WMEditors.Editor THEN
			WITH owner:WMEditors.Editor DO 
				owner.text.onTextChanged.Remove (owner.extInterface(InterfaceFinder).FindProcedure);
				owner.GetVisualComponentRoot().SetExtGetPositionOwnerHandler(NIL);
				owner.tv.SetExtPointerMoveHandler(NIL);
				IF owner.extInterface(InterfaceFinder).popup#NIL THEN owner.extInterface(InterfaceFinder).popup.Close END;
				owner.SetExtInterface(NIL);
				handled:=TRUE;
			END;
		ELSIF owner=PointerOwner THEN 
			handled:=FALSE;
		ELSE(*recursion*)
			StopPosOwner(x-owner.bounds.Get().l,y-owner.bounds.Get().t, owner, handled)
		END;
		PointerOwner:=owner;
	END StopPosOwner;	
	
END InterfaceFinder;
	
PROCEDURE Install*(context:Commands.Context);
VAR o:ANY; iFinder: InterfaceFinder; options:Options.Options;
BEGIN
	o:=context.caller;
	NEW(options); 
	options.Add("l","log",Options.Flag);(*write interface to log. Default is: write interface to popup*)
	IF options.Parse(context.arg,context.error) THEN
		NEW(iFinder); 
		iFinder.w:=context.out; iFinder.popups:=~options.GetFlag("l");
		IF o IS WMComponents.FormWindow THEN o(WMComponents.FormWindow).form.SetExtGetPositionOwnerHandler(iFinder.StartPosOwner)
		ELSIF o IS WMComponents.VisualComponent THEN o(WMComponents.VisualComponent).GetVisualComponentRoot()(WMComponents.Form).SetExtGetPositionOwnerHandler(iFinder.StartPosOwner)
		END;
		context.out.String("Install procedure interface popups");context.out.Ln; context.out.Update;
	END;
END Install;

PROCEDURE UnInstall*(context:Commands.Context);
VAR o:ANY; iFinder:InterfaceFinder;
BEGIN
	o:=context.caller;
	NEW(iFinder); iFinder.w:=context.out;
	IF o IS WMComponents.FormWindow THEN o(WMComponents.FormWindow).form.SetExtGetPositionOwnerHandler(iFinder.StopPosOwner)
	ELSIF o IS WMComponents.VisualComponent THEN o(WMComponents.VisualComponent).GetVisualComponentRoot()(WMComponents.Form).SetExtGetPositionOwnerHandler(iFinder.StopPosOwner)
	END;
	context.out.String("UnInstall procedure interface popups"); context.out.Ln; context.out.Update;
END UnInstall;

END ProcedureInterfaces.

(* usage:
toggle on/off  by CTRL-I in editor

for testing purposes:
ProcedureInterfaces.Install ~
ProcedureInterfaces.UnInstall ~ 
*)

System.FreeDownTo ProcedureInterfaces ~


