MODULE antsMessages IN Oberon;   	(** fof  **)
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

(*
	some rules:
		Commands that are possibly used in a repeated command script should give their messages in debug mode
		commands likely to be used once only should give messages in verbose mode
		commands giving an error should display usage in error mode
*)

IMPORT  Texts,EditTools, Strings,Display3,Oberon,Objects,Gadgets,Links,TextGadgets,TextGadgets0,antsPortability,Modules,
vyHostTexts,vyTextsCtl,Attributes,Documents, antsOrganizers;

CONST
	quietMode*=-2;
	errorMode*=-1;
	normalMode*=0;
	verboseMode*=1;
	debugMode*=2;
	sep= " ";
	MaxPatLen = 256;
TYPE
	writeProc= PROCEDURE(buf: Texts.Buffer);
VAR
	mode*: INTEGER; debug*: BOOLEAN;
	write: writeProc;
	w: Texts.Writer;
	sPatLen: LONGINT; lTime: LONGINT; sPat : ARRAY 256 OF CHAR;
			sDv: ARRAY 256 + 1 OF INTEGER;	(* displacement vector for search pattern *)

PROCEDURE Init(m: INTEGER): BOOLEAN;
BEGIN
	IF m > mode THEN RETURN FALSE END;
	CASE m OF
		quietMode: Texts.SetColor(w, SHORT(Display3.white));
		| errorMode: Texts.SetColor(w,SHORT( Display3.red));
		| normalMode: Texts.SetColor(w, SHORT(Display3.black));
		| verboseMode: Texts.SetColor(w, SHORT(Display3.blue));
		| debugMode: Texts.SetColor(w, 8 (* dkgreen *) );
	END;
	RETURN TRUE
END Init;

PROCEDURE writeCaret(buf: Texts.Buffer);
BEGIN
	vyHostTexts.InsertLog(buf);
END writeCaret;

PROCEDURE writeLog(buf: Texts.Buffer);
BEGIN
	Texts.Append(Oberon.Log,buf);
END writeLog;

PROCEDURE wS*(mode: INTEGER; s: ARRAY OF CHAR );
BEGIN
	IF ~Init(mode) THEN RETURN END;
	Texts.WriteString(w,s); Texts.WriteLn(w); write(w.buf);
END wS;

PROCEDURE wSB(mode: INTEGER; s: ARRAY OF CHAR; bool: BOOLEAN );
BEGIN
	IF ~Init(mode) THEN RETURN END;
	Texts.WriteString(w,s);
	IF bool THEN Texts.WriteString(w,"TRUE") ELSE Texts.WriteString(w,"FALSE") END;
	Texts.WriteLn(w); write(w.buf);
END wSB;

PROCEDURE wSS*(mode: INTEGER; s1,s2: ARRAY OF CHAR );
BEGIN
	IF ~Init(mode) THEN RETURN END;
	Texts.WriteString(w,s1) ;Texts.WriteString(w,sep); Texts.WriteString(w,s2);  Texts.WriteLn(w); write(w.buf);
END wSS;

PROCEDURE wSSS*(mode: INTEGER; s1,s2,s3: ARRAY OF CHAR );
BEGIN
	IF ~Init(mode) THEN RETURN END;
	Texts.WriteString(w,s1) ;Texts.WriteString(w,sep);Texts.WriteString(w,s2);Texts.WriteString(w,sep);Texts.WriteString(w,s3);  Texts.WriteLn(w); write(w.buf);
END wSSS;

PROCEDURE wSSSS*(mode: INTEGER; s1,s2,s3,s4: ARRAY OF CHAR );
BEGIN
	IF ~Init(mode) THEN RETURN END;
	Texts.WriteString(w,s1) ;Texts.WriteString(w,sep);Texts.WriteString(w,s2);Texts.WriteString(w,sep);Texts.WriteString(w,s3);  Texts.WriteString(w,sep);
	Texts.WriteString(w,s4);Texts.WriteLn(w); write(w.buf);
END wSSSS;


PROCEDURE wSI*(mode: INTEGER; s1: ARRAY OF CHAR; i: LONGINT);
BEGIN
	IF ~Init(mode) THEN RETURN END;
	Texts.WriteString(w,s1); Texts.WriteString(w,sep); Texts.WriteInt(w,i,0);  Texts.WriteLn(w); write(w.buf);
END wSI;

PROCEDURE wSR*(mode: INTEGER; s: ARRAY OF CHAR; r: LONGREAL);
BEGIN
	IF ~Init(mode) THEN RETURN END;
	Texts.WriteString(w,s); Texts.WriteString(w,sep); Texts.WriteReal(w, SHORT(r), 20); Texts.WriteLn(w); write(w.buf);
END wSR;

PROCEDURE wSISI* (mode: INTEGER; s1: ARRAY OF CHAR;    i1: LONGINT;    s2: ARRAY OF CHAR;    i2: LONGINT );
BEGIN
	IF ~Init(mode) THEN RETURN END;
	Texts.WriteString(w,s1);Texts.WriteString(w,sep);  Texts.WriteInt(w,i1,0);  Texts.WriteString(w,sep);
	Texts.WriteString(w,s2);  Texts.WriteString(w,sep); Texts.WriteInt(w,i2,0);
	Texts.WriteLn(w); write(w.buf);
END wSISI;

PROCEDURE wSRSR* (mode: INTEGER; s1: ARRAY OF CHAR;    r1: LONGREAL;   s2: ARRAY OF CHAR;    r2: LONGREAL);
BEGIN
	IF ~Init(mode) THEN RETURN END;
	Texts.WriteString(w, s1);
	Texts.WriteReal(w, SHORT(r1), 20);
	Texts.WriteString(w, s2);
	Texts.WriteReal(w, SHORT(r2), 20);
	Texts.WriteLn(w);
	write(w.buf);
END wSRSR;

PROCEDURE Ln*;
BEGIN vyHostTexts.Msg(""); END Ln;

PROCEDURE Sc* (write: BOOLEAN; s: ARRAY OF CHAR);
BEGIN	IF write THEN wS(normalMode,s); END;  END Sc;

PROCEDURE S* (s: ARRAY OF CHAR);
BEGIN	wS(normalMode,s); END S;

PROCEDURE SB* (s: ARRAY OF CHAR; bool: BOOLEAN);
BEGIN wSB(normalMode,s,bool); END SB;

PROCEDURE SS* (s1, s2: ARRAY OF CHAR);
BEGIN	wSS(normalMode,s1,s2); END SS;

PROCEDURE SSS* (s1, s2,s3: ARRAY OF CHAR);
BEGIN	wSSS(normalMode,s1,s2,s3); END SSS;

PROCEDURE SSSS* (s1, s2,s3,s4: ARRAY OF CHAR);
BEGIN	wSSSS(normalMode,s1,s2,s3,s4); END SSSS;

PROCEDURE SI* (s1: ARRAY OF CHAR;    i: LONGINT);
BEGIN	wSI(normalMode,s1,i); END SI;

PROCEDURE SR* (s1: ARRAY OF CHAR;    R: LONGREAL);
BEGIN	wSR(normalMode,s1,R); END SR;

PROCEDURE SISI* (s1: ARRAY OF CHAR;    i1: LONGINT;    s2: ARRAY OF CHAR;    i2: LONGINT );
BEGIN	wSISI(normalMode,s1,i1,s2,i2); END SISI;

PROCEDURE SRSR* (s1: ARRAY OF CHAR;    r1: LONGREAL;   s2: ARRAY OF CHAR;    r2: LONGREAL);
BEGIN	wSRSR(normalMode,s1,r1,s2,r2); END SRSR;

PROCEDURE eSc* (write: BOOLEAN; s: ARRAY OF CHAR);
BEGIN	IF write THEN wS(errorMode,s); END;  END eSc;

PROCEDURE eS* (s: ARRAY OF CHAR);
BEGIN	wS(errorMode,s); END eS;

PROCEDURE eSB* (s: ARRAY OF CHAR; bool: BOOLEAN);
BEGIN wSB(errorMode,s,bool); END eSB;

PROCEDURE eSS* (s1, s2: ARRAY OF CHAR);
BEGIN	wSS(errorMode,s1,s2); END eSS;

PROCEDURE eSSS* (s1, s2,s3: ARRAY OF CHAR);
BEGIN	wSSS(errorMode,s1,s2,s3); END eSSS;

PROCEDURE eSSSS* (s1, s2,s3,s4: ARRAY OF CHAR);
BEGIN	wSSSS(errorMode,s1,s2,s3,s4); END eSSSS;

PROCEDURE eSI* (s1: ARRAY OF CHAR;    i: LONGINT);
BEGIN	wSI(errorMode,s1,i); END eSI;

PROCEDURE eSR* (s1: ARRAY OF CHAR;    R: LONGREAL);
BEGIN	wSR(errorMode,s1,R); END eSR;

PROCEDURE eSISI* (s1: ARRAY OF CHAR;    i1: LONGINT;    s2: ARRAY OF CHAR;    i2: LONGINT );
BEGIN	wSISI(errorMode,s1,i1,s2,i2); END eSISI;

PROCEDURE eSRSR* (s1: ARRAY OF CHAR;    r1: LONGREAL;   s2: ARRAY OF CHAR;    r2: LONGREAL);
BEGIN	wSRSR(errorMode,s1,r1,s2,r2); END eSRSR;

PROCEDURE vS* (s: ARRAY OF CHAR);
BEGIN	wS(verboseMode,s); END vS;

PROCEDURE vSB* (s: ARRAY OF CHAR; bool: BOOLEAN);
BEGIN wSB(verboseMode,s,bool); END vSB;

PROCEDURE vSc* (write: BOOLEAN; s: ARRAY OF CHAR);
BEGIN	IF write THEN wS(verboseMode,s); END;  END vSc;

PROCEDURE vSS* (s1, s2: ARRAY OF CHAR);
BEGIN	wSS(verboseMode,s1,s2); END vSS;

PROCEDURE vSSS* (s1, s2,s3: ARRAY OF CHAR);
BEGIN	wSSS(verboseMode,s1,s2,s3); END vSSS;

PROCEDURE vSSSS* (s1, s2,s3,s4: ARRAY OF CHAR);
BEGIN	wSSSS(verboseMode,s1,s2,s3,s4); END vSSSS;

PROCEDURE vSI* (s1: ARRAY OF CHAR;    i: LONGINT);
BEGIN	wSI(verboseMode,s1,i); END vSI;

PROCEDURE vSR* (s1: ARRAY OF CHAR;    R: LONGREAL);
BEGIN	wSR(verboseMode,s1,R); END vSR;

PROCEDURE vSISI* (s1: ARRAY OF CHAR;    i1: LONGINT;    s2: ARRAY OF CHAR;    i2: LONGINT );
BEGIN	wSISI(verboseMode,s1,i1,s2,i2); END vSISI;

PROCEDURE vSRSR* (s1: ARRAY OF CHAR;    r1: LONGREAL;   s2: ARRAY OF CHAR;    r2: LONGREAL);
BEGIN	wSRSR(verboseMode,s1,r1,s2,r2); END vSRSR;

PROCEDURE dSc* (write: BOOLEAN; s: ARRAY OF CHAR);
BEGIN	IF write THEN wS(debugMode,s); END;  END dSc;

PROCEDURE dS* (s: ARRAY OF CHAR);
BEGIN	wS(debugMode,s); END dS;

PROCEDURE dSB* (s: ARRAY OF CHAR; bool: BOOLEAN);
BEGIN wSB(debugMode,s,bool); END dSB;

PROCEDURE dSS* (s1, s2: ARRAY OF CHAR);
BEGIN	wSS(debugMode,s1,s2); END dSS;

PROCEDURE dSSS* (s1, s2,s3: ARRAY OF CHAR);
BEGIN	wSSS(debugMode,s1,s2,s3); END dSSS;

PROCEDURE dSSSS* (s1, s2,s3,s4: ARRAY OF CHAR);
BEGIN	wSSSS(debugMode,s1,s2,s3,s4); END dSSSS;

PROCEDURE dSI* (s1: ARRAY OF CHAR;    i: LONGINT);
BEGIN	wSI(debugMode,s1,i); END dSI;

PROCEDURE dSR* (s1: ARRAY OF CHAR;    R: LONGREAL);
BEGIN	wSR(debugMode,s1,R); END dSR;

PROCEDURE dSISI* (s1: ARRAY OF CHAR;    i1: LONGINT;    s2: ARRAY OF CHAR;    i2: LONGINT );
BEGIN	wSISI(debugMode,s1,i1,s2,i2); END dSISI;

PROCEDURE dSRSR* (s1: ARRAY OF CHAR;    r1: LONGREAL;   s2: ARRAY OF CHAR;    r2: LONGREAL);
BEGIN	wSRSR(debugMode,s1,r1,s2,r2); END dSRSR;

PROCEDURE usage*(cmd,s: ARRAY OF CHAR);
BEGIN
	IF s # "" THEN
	eSSS("usage:",cmd,s);
	END;
END usage;

PROCEDURE cmd*;
VAR m: Modules.Module; pc: LONGINT; name: ARRAY 256 OF CHAR;
BEGIN
	IF mode >= debugMode THEN
		antsPortability.IdentifyCaller(m,pc);
		antsPortability.IdentifyCommand(m,pc,name);
		dS(name);
	END;
END cmd;

PROCEDURE launch*;
VAR m: Modules.Module; pc: LONGINT;
BEGIN
	IF mode >= verboseMode THEN
		antsPortability.IdentifyCaller(m,pc);
		IF m # NIL THEN vSS("launching",m.name) END;
	END;
END launch;


(* Command to display a string *)
PROCEDURE Out*;
	VAR sc: Texts.Scanner;
BEGIN
	vS("antsMessages.Out");
	Texts.OpenScanner(sc,Oberon.Par.text,Oberon.Par.pos);
	Texts.Scan(sc);
	IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
		 S(sc.s)
	ELSE
		usage("antsMessages.Out","STR");
	END
END Out;

PROCEDURE Compare(str1,str2: ARRAY OF CHAR): BOOLEAN;
BEGIN
	RETURN Strings.CAPCompare(str1,str2);
END Compare;

(* Set current display Mode *)
PROCEDURE SetMode*;
VAR sc: Texts.Scanner;
BEGIN
	Texts.OpenScanner(sc,Oberon.Par.text,Oberon.Par.pos);
	Texts.Scan(sc);
	IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
		IF Compare(sc.s,"quiet") THEN mode := quietMode; wS(quietMode,"Output set to quiet. Nothing will be reported.");
		ELSIF Compare(sc.s,"errors") THEN mode := errorMode; eS("Output set to errors only Mode. Only errors will be reported.");
		ELSIF Compare(sc.s,"normal") THEN mode := normalMode; S("Output set to normal Mode. Parsinomous, only important things will be reported");
		ELSIF Compare(sc.s,"verbose") THEN mode := verboseMode; vS("Output set to verbose Mode. More details will be reported.");
		ELSIF Compare(sc.s,"debug") THEN mode := debugMode; dS("Output set to debug Mode. All details will be reported.");
		END;
	END;
END SetMode;

(**exchange a Text by Log = System.Log *)
PROCEDURE SetLog*;
VAR  o,text: Objects.Object; sc: Texts.Scanner; pos: LONGINT;
BEGIN
	Texts.OpenScanner(sc,Oberon.Par.text,Oberon.Par.pos);
	Texts.Scan(sc);
	IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
	o := Gadgets.FindObj(Gadgets.context,sc.s);
	ELSE o := Gadgets.context
	END;
	IF o # NIL THEN
		Links.GetLink(o,"Model",text);
		IF (text # NIL) & (text IS Texts.Text) THEN
			vS("antsMessages: changing text to Log");
			Links.SetLink(o,"Model",Oberon.Log);
			IF o IS TextGadgets.Frame THEN
				INCL(o(TextGadgets.Frame).state0, TextGadgets0.autoscroll);
				pos := TextGadgets0.LinesUp(Oberon.Log,Oberon.Log.len,1);
				dS("scrolling up");
				TextGadgets0.ScrollTo(o(TextGadgets.Frame),pos);
				S("This is a view of the System.Log text.");
				S("This text document shows the results of commands, computations and");
				S("displays general information about the current status.");
				S("Error messages are displayed here.");
				S("You may close this window. It can be re-opened");
				S("with the 'Log' button on the startup panels.");
			END;
		ELSE
			eSS("antsMessages: Tried to replace Text, but has no Text-Model ",sc.s);
		END;
	ELSE
	 	eSS("antsMessages: Tried to replace Text, but cannot find ",sc.s);
	END;
END SetLog;

PROCEDURE ToEnd*;
	VAR  o,text: Objects.Object; sc: Texts.Scanner; pos: LONGINT;
BEGIN
	Texts.OpenScanner(sc,Oberon.Par.text,Oberon.Par.pos);
	Texts.Scan(sc);
	IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
	o := Gadgets.FindObj(Gadgets.context,sc.s);
	ELSE o := Gadgets.context
	END;
	IF (o # NIL) & (o IS TextGadgets.Frame) THEN
		Links.GetLink(o,"Model",text);
		IF (text # NIL ) & (text IS Texts.Text) THEN
			WITH text: Texts.Text DO
				pos := TextGadgets0.LinesUp(text,text.len,1);
				TextGadgets0.ScrollTo(o(TextGadgets.Frame),pos);
			END;
		END;
	END;
END ToEnd;


PROCEDURE Lines(F: TextGadgets.Frame;lines: LONGINT);
VAR pos: LONGINT; text: Objects.Object; line: INTEGER; R: Texts.Reader; ch: CHAR;
BEGIN
	Links.GetLink(F,"Model",text);
	IF (text # NIL ) & (text IS Texts.Text) THEN
		WITH text: Texts.Text DO
			pos := F.org;

			IF lines > 0 THEN
			Texts.OpenReader(R,text,pos);
			line := 0;
			WHILE(line < lines) & (~R.eot) DO
				Texts.Read(R,ch);
				IF ch = Strings.CR THEN INC(line) END;
			END;
			pos:= Texts.Pos(R);
			IF ~R.eot THEN
				TextGadgets0.ScrollTo(F,pos);
			END;
			ELSE
				lines := -lines;
				pos := TextGadgets0.LinesUp(text,pos,SHORT(lines));
				TextGadgets0.ScrollTo(F,pos);
			END;
		END
	END;
END Lines;


PROCEDURE Down*;
	VAR  o: Objects.Object; sc: Texts.Scanner; num: LONGINT;
BEGIN
	Texts.OpenScanner(sc,Oberon.Par.text,Oberon.Par.pos);
	Texts.Scan(sc);
	IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
	ELSE o := Gadgets.context
	END;
	o := Gadgets.FindObj(Gadgets.context,sc.s);
		Texts.Scan(sc); IF (sc.class = Texts.Int) THEN
			num := sc.i
		ELSIF (sc.class= Texts.Name) & (sc.s = "page") THEN
			num := TextGadgets0.LinesOf(o(TextGadgets.Frame)) DIV 2; IF num < 5 THEN num := 5 END;
		ELSE num := 3
		END;
		IF (o # NIL) & (o IS TextGadgets.Frame) THEN
			Lines(o(TextGadgets.Frame),num);
		END;
END Down;

PROCEDURE Up*;
	VAR  o: Objects.Object; sc: Texts.Scanner;num: LONGINT;
BEGIN
	Texts.OpenScanner(sc,Oberon.Par.text,Oberon.Par.pos);
	Texts.Scan(sc);
	IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
	o := Gadgets.FindObj(Gadgets.context,sc.s);
		ELSE o := Gadgets.context
	END;

	IF (o # NIL) & (o IS TextGadgets.Frame) THEN
		Texts.Scan(sc);
			IF (sc.class = Texts.Int) THEN num := sc.i
			ELSIF (sc.class= Texts.Name) & (sc.s = "page") THEN
				num := TextGadgets0.LinesOf(o(TextGadgets.Frame)) DIV 2; IF num < 5 THEN num := 5 END;
			ELSE num := 3 END;
		Lines(o(TextGadgets.Frame),-num);
	END;
END Up;

PROCEDURE UpUp*;
VAR  o,text: Objects.Object; sc: Texts.Scanner;
BEGIN
	Texts.OpenScanner(sc,Oberon.Par.text,Oberon.Par.pos);
	Texts.Scan(sc);
	IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
	o := Gadgets.FindObj(Gadgets.context,sc.s);
	ELSE o := Gadgets.context
	END;
	IF (o # NIL) & (o IS TextGadgets.Frame) THEN
		Links.GetLink(o,"Model",text);
		IF (text # NIL) & (text IS Texts.Text) THEN
			TextGadgets0.ScrollTo(o(TextGadgets.Frame),0);
		END;
	END;
END UpUp;


 PROCEDURE DownDown*;
VAR  o,text: Objects.Object; sc: Texts.Scanner;
BEGIN
	Texts.OpenScanner(sc,Oberon.Par.text,Oberon.Par.pos);
	Texts.Scan(sc);
	IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
	o := Gadgets.FindObj(Gadgets.context,sc.s);
	ELSE o := Gadgets.context
	END;
	IF (o # NIL) & (o IS TextGadgets.Frame) THEN
		Links.GetLink(o,"Model",text);
		IF (text # NIL) & (text IS Texts.Text) THEN
			TextGadgets0.ScrollTo(o(TextGadgets.Frame),text(Texts.Text).len);
			Lines(o(TextGadgets.Frame),-5);
		END;
	END;
END DownDown;

PROCEDURE ReplaceSuffix (VAR name: ARRAY OF CHAR; suffix: ARRAY OF CHAR);  (* replace suffix by stdsuffix will be appended *)
	VAR i,start,pos: LONGINT;
BEGIN
	i := 0;start := 0; pos := LEN(name)-1;
	WHILE(name[i] # 0X) DO
		IF name[i] = antsPortability.PathChar THEN start := i END;
		INC(i);
	END;
	i := start;
	WHILE(name[i] # 0X) DO
		IF name[i] = "."THEN pos := i; END;   INC(i)
	END;
	name[pos] := 0X;
	Strings.Append(name, ".");  Strings.Append(name, suffix)
END ReplaceSuffix;

PROCEDURE OpenText*;
VAR  o,text: Objects.Object; sc: Texts.Scanner;name: ARRAY 256 OF CHAR; obj: Objects.Object;
M: Objects.CopyMsg;
BEGIN
	obj := Gadgets.context;
	WHILE (obj # NIL) & ~(obj IS Documents.Document) DO obj := obj.dlink END;
	IF obj # NIL THEN COPY(obj(Documents.Document).name,name); ReplaceSuffix(name,"Text");
	ELSE name := "OpenedText.Text"
	END;

	Texts.OpenScanner(sc,Oberon.Par.text,Oberon.Par.pos);
	Texts.Scan(sc);
	IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
	o := Gadgets.FindObj(Gadgets.context,sc.s);
	ELSE o := Gadgets.context
	END;
	IF (o # NIL) & (o IS TextGadgets.Frame) THEN
		Links.GetLink(o,"Model",text);
		IF (text # NIL) & (text IS Texts.Text) THEN
				IF ~debug THEN
				M.id := Objects.deep;
				M.obj := NIL;
				text.handle(text,M);
				IF M.obj # NIL THEN text := M.obj END;
				EditTools.ChangeCol(text(Texts.Text),0,text(Texts.Text).len,0,15);
				END;
				Oberon.OpenText(name,text(Texts.Text),600,800);
		END;
	END;
END OpenText;

PROCEDURE IncSize*;
VAR  o,text: Objects.Object; sc: Texts.Scanner;
BEGIN
	Texts.OpenScanner(sc,Oberon.Par.text,Oberon.Par.pos);
	Texts.Scan(sc);
	IF (sc.class = Texts.String) OR (sc.class = Texts.Name) THEN
	o := Gadgets.FindObj(Gadgets.context,sc.s);  Texts.Scan(sc);
	ELSE o := Gadgets.context
	END;
	IF (o # NIL) & (o IS TextGadgets.Frame) THEN
		Links.GetLink(o,"Model",text);
		IF (text # NIL) & (text IS Texts.Text) & (sc.class = Texts.Int) THEN
			EditTools.IncFontSize(text(Texts.Text),0,text(Texts.Text).len,SHORT(sc.i));
		END;
	END;
END IncSize;

PROCEDURE SetPrio*;
VAR sc: Texts.Scanner;
BEGIN
	Texts.OpenScanner(sc, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(sc);
	IF sc.class = Texts.Name THEN
		IF sc.s = "ToLog" THEN write := writeLog; S("antsMessages:Writing output to System Log (this text) only, caret (=cursor) has no priority");
		ELSIF sc.s= "ToCaret" THEN S("antsMessages:Writing to caret (=cursor), if any, writing to log-text if no caret set");  vyTextsCtl.CaretHasPriority; write := writeCaret;
		END
	END;
END SetPrio;

PROCEDURE SetOutput*;
VAR S: Texts.Scanner;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(S);
	IF S.class = Texts.Name THEN
		IF S.s = "SysLog" THEN vyTextsCtl.DeleteOutput ;
		ELSIF S.s= "SelectText" THEN vyTextsCtl.NewOutput;
		END
	END;
END SetOutput;


PROCEDURE ClearLog*;
BEGIN
	Texts.Delete(Oberon.Log,0,Oberon.Log.len);
END ClearLog;

(* -- search engine by uh *)


	PROCEDURE CalcDispVec(time: LONGINT);
		VAR i, j, d: INTEGER;
	BEGIN
		lTime := time;
		i := 1; d := 1;	(* calculate displacement vector *)
		WHILE i <= sPatLen DO
			j := 0; WHILE (j + d < sPatLen) & (sPat[j] = sPat[j + d]) DO INC(j) END;
			WHILE i <= j + d DO sDv[i] := d; INC(i) END;
			INC(d)
		END
	END CalcDispVec;

	PROCEDURE SPatFound(text: Texts.Text; VAR pos:LONGINT): BOOLEAN;
	(* searches the next position for the search pattern sPat begining at position pos *)
	(* in the text text; resturns result accordingly *)
		VAR R: Texts.Reader;	l: LONGINT;	i: INTEGER;	ch: CHAR;
	BEGIN
		IF sPatLen > 0 THEN
			Texts.OpenReader(R, text, pos); Texts.Read(R, ch); INC(pos);
			l := text.len; i := 0;
			WHILE (i # sPatLen) & (pos <= l) DO
				IF ch = sPat[i] THEN
					INC(i); IF i < sPatLen THEN Texts.Read(R, ch); INC(pos) END
				ELSIF i = 0 THEN Texts.Read(R, ch); INC(pos)
				ELSE DEC(i, sDv[i])
				END
			END;
		ELSE i := -1
		END;
		RETURN i = sPatLen	(* pattern found *)
	END SPatFound;

	PROCEDURE search(VAR S: Attributes.Scanner; tF: TextGadgets.Frame);
		VAR R: Texts.Reader; text: Texts.Text; pos, beg, end, time: LONGINT; i: INTEGER;
	BEGIN
		IF S.class IN {Attributes.Name, Attributes.String} THEN
			COPY(S.s, sPat); sPatLen := S.len; CalcDispVec(Oberon.Time())	(* calculate displacement vector *)
		ELSE
			text := NIL; Oberon.GetSelection(text, beg, end, time);
			IF (text # NIL) & (time - lTime > 0) THEN	(* set search pattern *)
				Texts.OpenReader(R, text, beg);
				i := 0; pos := beg;
				REPEAT Texts.Read(R, sPat[i]); INC(i); INC(pos) UNTIL (i = MaxPatLen) OR (pos = end);
				sPatLen := i; CalcDispVec(time)	(* calculate displacement vector *)
			END
		END;
		IF tF.car THEN pos := tF.carpos.pos ELSE pos := 0 END;
		IF SPatFound(tF.text, pos) THEN
			TextGadgets0.ScrollTo(tF,pos-Strings.Length(sPat));
		END
	END search;

	(** Same as Edit.Search. Also can be used in the form: TextDocs.Search "string" to search for the
		specified string in the current or marked document. *)
	PROCEDURE Search*; (* [ [ "*" ] "string" ] *)
		VAR tF: TextGadgets.Frame;  S: Attributes.Scanner;
	BEGIN
		Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Attributes.Scan(S);
		IF( Gadgets.context # NIL) &( Gadgets.context IS TextGadgets.Frame ) THEN
			tF :=  Gadgets.context(TextGadgets.Frame);
			search(S, tF)
		ELSIF Gadgets.context IS TextGadgets.Frame THEN
			search(S, Gadgets.context(TextGadgets.Frame))
		END
	END Search;

(* compatibility ... *)

PROCEDURE OpenHelp*;  (* should be part of a Toolbox or Organizers, needed in many buttons, do not remove from here !!! *)
BEGIN
antsOrganizers.OpenHelp
END OpenHelp;

PROCEDURE ViewObjectCopy*; (* should be part of a Toolbox or Organizers, needed in many buttons, do not remove from here !!! *)
BEGIN
antsOrganizers.ViewObjectCopy
END ViewObjectCopy;

PROCEDURE ToggleVisibility*; (* needed here for consistency reasons *)
BEGIN
	antsOrganizers.ToggleVisibility
END ToggleVisibility;

PROCEDURE IncPanelTextSizes*;
BEGIN
	antsOrganizers.IncPanelTextSizes
END IncPanelTextSizes;


BEGIN
	Texts.OpenWriter(w); write := writeLog;
	debug := FALSE;
END antsMessages.

antsMessages.Out "teststring"
antsMessages.SetLog "testtext" ~

antsMessages.Test
Desktops.OpenWinDoc antsLog.Panel

antsMessages.SetMode debug ~

antsCommandInvoker.DebugMode ~
antsCommandInvoker.NormalMode ~

