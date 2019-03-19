MODULE antsOnTheFly IN Oberon;   	(** fof  **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)




IMPORT vyHost, vyHostTexts, Texts, Modules, (* Compiler, *)  Oberon, vyHostStrings, Files,
Objects, (* OPS,*)  aM := antsMessages,Builder,Display, antsTexts,PC,AosModules := Modules IN A2;

	VAR debug*: BOOLEAN;

TYPE
	Function1d* = PROCEDURE{DELEGATE} (x: LONGREAL): LONGREAL;
	FunctionXd* = PROCEDURE{DELEGATE} (x: ARRAY OF LONGREAL): LONGREAL;

CONST
	standardModule = "antsOnTheFlyMod.Text";

VAR
	f1d*: Function1d;    f1dName*: ARRAY 1024 OF CHAR;
	fXd*: FunctionXd;   fXdName*: ARRAY 1024 OF CHAR;
	W: Texts.Writer;

PROCEDURE Module (source: Texts.Text;   opt: ARRAY OF CHAR;    log: Texts.Text;   VAR error: BOOLEAN);
BEGIN
	(*
	OPS.Init;
	*)
	PC.CompileText(source,"",0,NIL,opt,NIL,error);
	(*
	Compiler.Module(source, "", opt, 0, log, error)
	*)
END Module;


PROCEDURE InsertArray (t: Texts.Text;    at: LONGINT;    Array: ARRAY OF CHAR);
	VAR w: Texts.Writer;
BEGIN
	Texts.OpenWriter(w);
	Texts.WriteString(w, Array);
	Texts.Insert(t, at, w.buf)
END InsertArray;

PROCEDURE Find (a: ARRAY OF CHAR;    t: Texts.Text;    VAR at: LONGINT): BOOLEAN;
	VAR b: ARRAY 32 OF CHAR;    r: Texts.Reader;     ch: CHAR;    i: LONGINT;
BEGIN
	Texts.OpenReader(r, t, at);
	WHILE ~r.eot DO
		Texts.Read(r, ch);
		FOR i := 0 TO LEN(a) - 2 DO
			b[i] := b[i + 1]
		END;
		b[LEN(a) - 2] := ch;
		b[LEN(a) - 1] := 0X;
		IF vyHostStrings.Equal(a, b) THEN
			at := Texts.Pos(r) - LEN(a) + 1;
			Texts.Delete(t, at, at + LEN(a) - 1);
			RETURN TRUE
		END
	END;
	RETURN FALSE
END Find;

PROCEDURE Replace (t: Texts.Text;    pattern: ARRAY OF CHAR;    by: ARRAY OF CHAR);
	VAR at: LONGINT;
BEGIN
	at := 0;
	WHILE Find(pattern, t, at) DO InsertArray(t, at, by) END
END Replace;

PROCEDURE Set1d* (const, function: ARRAY OF CHAR): BOOLEAN;
	VAR w: Texts.Writer;     error: BOOLEAN;    source: Texts.Reader;
	t: Texts.Text;    Log: Texts.Text;    res: INTEGER;     m: Modules.Module;    p: Modules.Command;
	r: Texts.Reader;    ch: CHAR;    omsg: Objects.ObjMsg;    counter: ARRAY 32 OF CHAR;
	ModuleName,mn: ARRAY 64 OF CHAR;    F: Files.File;    name: ARRAY 256 OF CHAR;
	text: Texts.Text;
BEGIN
	IF function = ""THEN f1d := NIL;    f1dName := "";   RETURN TRUE END;

	Objects.Stamp(omsg);    counter := "";
	vyHostStrings.AppendInt(ABS(omsg.stamp), 10, counter);

	IF debug THEN Log := Oberon.Log ELSE NEW(Log);    Texts.Open(Log, "antsTemp.Log") END;

	vyHost.GetNamedText(standardModule, t);
	Replace(t, "#counter#", counter);
	Replace(t, "#const#", const);
	Replace(t, "#function1d#", function);
	Replace(t, "#y1d#", "y");
	Replace(t, "#functionXd#", "");
	Replace(t, "#yXd#", "y");

	Texts.OpenReader(source, t, 0);
	Module(t, "/s",  Log, error);

	IF error THEN
		vyHost.GetNamedText(standardModule, t);
		Replace(t, "#counter#", counter);
		Replace(t, "#const#", const);
		Replace(t, "#function1d#", "");
		Replace(t, "#y1d#", function);
		Replace(t, "#functionXd#", "");
		Replace(t, "#yXd#", "y");

		Texts.OpenReader(source, t, 0);
		Module(t, "/s", Log, error)
	END;


	IF error THEN vyHostTexts.Note(vyHostTexts.cAlert, "Error in Function");
		IF debug THEN
			Texts.OpenReader(r, t, 0);    Texts.OpenWriter(w);
			WHILE ~r.eot DO
				Texts.Read(r, ch);    Texts.Write(w, ch)
			END;
			NEW(text);   Texts.Open(text, "test");
			Oberon.OpenText("debugging", text, 600, 400);
			Texts.Append(text, w.buf)
		END;
	RETURN FALSE END;

	ModuleName := "antsTemp";    vyHostStrings.Append(ModuleName, counter);
	Modules.Free(ModuleName, FALSE);
	m := Modules.ThisMod(ModuleName);
	IF m = NIL THEN vyHostTexts.NoteSS(vyHostTexts.cAlert, "Error: Module does not exist:", ModuleName);     RETURN FALSE END;
	p := Modules.ThisCommand(m, "SetFunction1d");
	IF p = NIL THEN vyHostTexts.Note(vyHostTexts.cAlert, "Error: Procedure SetFunction1d does not exist");    RETURN FALSE END;
	p;
	COPY(function, f1dName);

	COPY(ModuleName,mn);
	vyHostStrings.Append(mn, ".Obj");
	F := Files.Old(mn);
	IF F=NIL THEN
	COPY(ModuleName,mn);
	vyHostStrings.Append(mn, ".Obx");
	F := Files.Old(mn);
	END;
	IF F=NIL THEN
	COPY(ModuleName,mn);
	vyHostStrings.Append(mn, ".Obw");
	F := Files.Old(mn);
	END;
	IF F=NIL THEN
	COPY(ModuleName,mn);
	vyHostStrings.Append(mn, AosModules.extension[0]);
	F := Files.Old(mn);
	END;

	IF F # NIL THEN
		Files.GetName(F, name);
		Files.Delete(name, res);
		IF res # 0 THEN vyHostTexts.NoteSS(vyHostTexts.cAlert, "File could not be deleted: ", name) END
	ELSE
		vyHostTexts.NoteSS(vyHostTexts.cAlert, "File could not be deleted: ", ModuleName)
	END;
	RETURN TRUE
END Set1d;

PROCEDURE SetXd* (const, function: ARRAY OF CHAR): BOOLEAN;
	VAR w: Texts.Writer;     error: BOOLEAN;    source: Texts.Reader;
	t: Texts.Text;    Log: Texts.Text;    res: INTEGER;     m: Modules.Module;    p: Modules.Command;
	r: Texts.Reader;    ch: CHAR;    omsg: Objects.ObjMsg;    counter: ARRAY 32 OF CHAR;
	ModuleName,mn: ARRAY 64 OF CHAR;    F: Files.File;    name: ARRAY 256 OF CHAR;   text: Texts.Text;
BEGIN
	IF function = ""THEN fXd := NIL;    fXdName := "";   RETURN TRUE END;

	Objects.Stamp(omsg);    counter := "";
	vyHostStrings.AppendInt(ABS(omsg.stamp), 10, counter);

	IF debug THEN Log := Oberon.Log ELSE NEW(Log);    Texts.Open(Log, "antsTemp.Log") END;

	vyHost.GetNamedText(standardModule, t);
	Replace(t, "#counter#", counter);
	Replace(t, "#const#", const);
	Replace(t, "#functionXd#", function);
	Replace(t, "#yXd#", "ret");
	Replace(t, "#function1d#", "");
	Replace(t, "#y1d#", "y");

	Texts.OpenReader(source, t, 0);
	Module(t, "/Ns",  Log, error);

	IF error THEN
		vyHost.GetNamedText(standardModule, t);
		Replace(t, "#counter#", counter);
		Replace(t, "#const#", const);
		Replace(t, "#functionXd#", "");
		Replace(t, "#yXd#", function);
		Replace(t, "#function1d#", "");
		Replace(t, "#y1d#", "y");

		Texts.OpenReader(source, t, 0);
		Module(t, "/s", Log, error)
	END;


	IF error THEN vyHostTexts.Note(vyHostTexts.cAlert, "Error in Function");
		IF debug THEN
			Texts.OpenReader(r, t, 0);    Texts.OpenWriter(w);
			WHILE ~r.eot DO
				Texts.Read(r, ch);    Texts.Write(w, ch)
			END;
			NEW(text);   Texts.Open(text, "test");
			Oberon.OpenText("debugging", text, 600, 400);
			Texts.Append(text, w.buf)
		END;
	RETURN FALSE END;

	ModuleName := "antsTemp";    vyHostStrings.Append(ModuleName, counter);
	Modules.Free(ModuleName, FALSE);
	m := Modules.ThisMod(ModuleName);
	IF m = NIL THEN vyHostTexts.NoteSS(vyHostTexts.cAlert, "Error: Module does not exist:", ModuleName);     RETURN FALSE END;
	p := Modules.ThisCommand(m, "SetFunctionXd");
	IF p = NIL THEN vyHostTexts.Note(vyHostTexts.cAlert, "Error: Procedure SetFunction1d does not exist");    RETURN FALSE END;
	p;
	COPY(function, fXdName);
	COPY(ModuleName,mn);
	vyHostStrings.Append(mn, ".Obj");
	F := Files.Old(mn);
	IF F=NIL THEN
	COPY(ModuleName,mn);
	vyHostStrings.Append(mn, ".Obx");
	F := Files.Old(mn);
	END;
	IF F=NIL THEN
	COPY(ModuleName,mn);
	vyHostStrings.Append(mn, ".Obw");
	F := Files.Old(mn);
	END;
	IF F # NIL THEN
		Files.GetName(F, name);
		Files.Delete(name, res);
		IF res # 0 THEN vyHostTexts.NoteSS(vyHostTexts.cAlert, "File could not be deleted: ", name) END
	ELSE
		vyHostTexts.NoteSS(vyHostTexts.cAlert, "File could not be deleted: ", ModuleName)
	END;
	RETURN TRUE
END SetXd;

PROCEDURE StoreF1d* (R: Files.Rider;   mapping: ARRAY OF CHAR);
BEGIN
	Files.WriteString(R, mapping)
END StoreF1d;

PROCEDURE LoadF1d* (R: Files.Rider;   VAR mapping: ARRAY OF CHAR;   VAR fxd: Function1d);
BEGIN
	Files.ReadString(R, mapping);
	IF Set1d(mapping, "") THEN
		fxd := f1d
	ELSE
		fxd := NIL
	END
END LoadF1d;

PROCEDURE StoreFXd* (R: Files.Rider;   mapping: ARRAY OF CHAR);
BEGIN
	Files.WriteString(R, mapping)
END StoreFXd;

PROCEDURE LoadFXd* (R: Files.Rider;   VAR mapping: ARRAY OF CHAR;   VAR fxd: FunctionXd);
BEGIN
	Files.ReadString(R, mapping);
	IF SetXd(mapping, "") THEN
		fxd := fXd
	ELSE
		fxd := NIL
	END
END LoadFXd;

PROCEDURE Test1d*;
	VAR r: Texts.Reader;   ch: CHAR;    Function: ARRAY 1024 OF CHAR;    i: LONGINT;
BEGIN
	Texts.OpenReader(r, Oberon.Par.text, Oberon.Par.pos);
	Texts.Read(r, ch);    i := 0;
	WHILE (~r.eot) & (~(ch = "~")) DO
		Function[i] := ch;    INC(i);
		Texts.Read(r, ch)
	END;
	Function[i] := 0X;
	IF Set1d("", Function) THEN
		FOR i := 0 TO 10 DO
			vyHostTexts.MsgSRSR("x=", i / 10, "y=", f1d(i / 10))
		END
	END
END Test1d;

PROCEDURE TestXd*;
	VAR r: Texts.Reader;   ch: CHAR;    Function: ARRAY 1024 OF CHAR;    i: LONGINT;
	X: ARRAY 2 OF LONGREAL;
BEGIN
	Texts.OpenReader(r, Oberon.Par.text, Oberon.Par.pos);
	Texts.Read(r, ch);    i := 0;
	WHILE (~r.eot) & (~(ch = "~")) DO
		Function[i] := ch;    INC(i);
		Texts.Read(r, ch)
	END;
	Function[i] := 0X;
	IF SetXd("", Function) THEN
		FOR i := 0 TO 10 DO
			X[0] := i;   X[1] := - i;
			vyHostTexts.MsgSRSR("x=", X[0] , "y=", fXd(X))
		END
	END
END TestXd;

PROCEDURE MarkErrorPos(T: Texts.Text; pos: LONGINT; err: INTEGER);
VAR obj: Objects.Object;
BEGIN
	Builder.NewErrorGadget; obj := Objects.NewObj; obj(Builder.ErrorGadget).errno := err;
	Texts.WriteObj(W, obj);
	Texts.Insert(T, pos, W.buf)
END MarkErrorPos;

PROCEDURE RemoveErrors(T: Texts.Text);
VAR first: LONGINT; F: Texts.Finder; o: Objects.Object;
BEGIN
	first := -1;
	LOOP
		Texts.OpenFinder(F, T, 0);
		IF F.eot THEN EXIT END;
		first := F.pos;
		Texts.FindObj(F, o);
		LOOP
			IF F.eot THEN EXIT END;
			IF (o # NIL) & (o IS Builder.ErrorGadget) THEN EXIT
			ELSE
				first := F.pos;
				Texts.FindObj(F, o);
			END;
		END;
		IF F.eot THEN EXIT END;
		IF (o # NIL) & (o IS Builder.ErrorGadget) THEN
			Texts.Delete(T, first, first+1)
		END
	END
END RemoveErrors;

PROCEDURE markErrors(VAR S: Texts.Scanner; errtext: Texts.Text; par: Display.Frame; offset,len: LONGINT);
VAR c, err: INTEGER; pos, beg, l, k: LONGINT; C: Oberon.CaretMsg;  warn: BOOLEAN;
	marked: ARRAY 100 OF LONGINT;
BEGIN
	IF (S.class = Texts.Name) & (S.s = "compiling") THEN
		l := S.line; REPEAT Texts.Scan(S) UNTIL (S.line # l) OR S.eot
	END;
	c := 0; beg := -1; marked[0] := 0;
	WHILE (S.class = Texts.Name) & (S.s = "pos") & (c # 100) DO
		Texts.Scan(S); pos := S.i; Texts.Scan(S);
		warn := (S.class = Texts.Name) & (S.s = "warning");
		Texts.Scan(S); err := SHORT(S.i);
		IF warn THEN err := -err END;
		l := 0;  WHILE (l # c) & (marked[l] < pos) DO INC(l) END;
		k := c;  WHILE k # l DO marked[k] := marked[k-1];  DEC(k) END;
		marked[l] := pos;
		IF (pos+l-offset >=0) & (pos+l-offset<len) THEN
		MarkErrorPos(errtext, pos + l-offset, err); INC(c);
		END;
		IF beg < 0 THEN
			beg := pos+l
		END;
		l := S.line;  REPEAT Texts.Scan(S) UNTIL S.eot OR (S.line # l)
	END;
	IF (beg > 0) & (par # NIL) THEN
		C.id := Oberon.set; C.F := par; C.car := par; C.text := errtext; C.pos := beg;
		Display.Broadcast(C)
	END
END markErrors;

PROCEDURE GetModuleName*(VAR modName: ARRAY OF CHAR);
VAR  T: Builder.Tree;
BEGIN
	Builder.AddModule(T,modName,"");
	COPY(T.list.name,modName);
END GetModuleName;


PROCEDURE CompileText*(t: Texts.Text; inModule,cmd: ARRAY OF CHAR; begpat,endpat: ARRAY OF CHAR): BOOLEAN;
VAR  buf: Texts.Buffer; T: Texts.Text; pos: LONGINT; source: Texts.Reader; fbeg: LONGINT; error: BOOLEAN;
S1: Texts.Scanner; m: Modules.Module; p: Modules.Command;name,mn: ARRAY 256 OF CHAR; F: Files.File; res: INTEGER;
BEGIN
	aM.dS("enterCompileText");
	RemoveErrors(t);
	NEW(buf); Texts.OpenBuf(buf);
	Texts.Save(t,0,t.len,buf);
	NEW(T); Texts.Open(T,inModule);
	IF ~antsTexts.ReplaceTextPart(T,begpat,endpat,buf,pos) THEN aM.eS("antsOnTheFly: Could not replace"); RETURN FALSE END;
	Texts.OpenReader(source,T,0);
	fbeg := Oberon.Log.len;
	Module(T,"\s2",Oberon.Log,error);
	(*
	OPS.Init;
	Compiler.Module(source, "", "\s2", MAX(LONGINT), Oberon.Log, error);
	*)
	IF error THEN
		Texts.OpenScanner(S1, Oberon.Log, fbeg); Texts.Scan(S1);
		(* markErrors(S1, ct, NIL,0,ct.len); *)
		markErrors(S1, t, NIL,pos,t.len);
		RETURN FALSE;
	ELSE
		GetModuleName(inModule);
		aM.dSS("modulename=",inModule);
		Modules.Free(inModule,FALSE);
		m := Modules.ThisMod(inModule);
		IF m = NIL THEN RETURN FALSE END;
		aM.dSc(m#NIL,"m exists");
		IF (m#NIL) & (cmd#"") THEN
			p := Modules.ThisCommand(m, cmd);
			IF p#NIL THEN
				aM.dSS("executing ",cmd); p
			ELSE
				aM.eSS("does not exist",cmd);
				RETURN FALSE;
			END
		END;

	COPY(inModule,mn);
	vyHostStrings.Append(mn, ".Obj");
	F := Files.Old(mn);

	IF F=NIL THEN
	COPY(inModule,mn);
	vyHostStrings.Append(mn, ".Obx");
	F := Files.Old(mn);
	END;

	IF F=NIL THEN
	COPY(inModule,mn);
	vyHostStrings.Append(mn, ".Obw");
	F := Files.Old(mn);
	END;

	IF F # NIL THEN
		Files.GetName(F, name);
		Files.Delete(name, res);
		IF res # 0 THEN vyHostTexts.NoteSS(vyHostTexts.cAlert, "File could not be deleted: ", name)
		ELSE
			aM.dSS("deleted: ",name);
		END
	ELSE
		vyHostTexts.NoteSS(vyHostTexts.cAlert, "File could not be deleted: ", inModule)
	END;

	END;
	RETURN TRUE;
END CompileText;


BEGIN aM.launch; debug := FALSE; Texts.OpenWriter(W);
END antsOnTheFly.

antsOnTheFly.Test ~
System.Free  antsTemp antsOnTheFly ~


antsOnTheFly.Test1d
IF x < 0.5 THEN y := x * x ELSE y := 0.3 END;
~
antsOnTheFly.TestXd
IF x[0] < 5 THEN y := x[1] ELSE y := sin(x[0]) END;
~


