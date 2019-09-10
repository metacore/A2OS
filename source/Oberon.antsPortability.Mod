MODULE antsPortability IN Oberon;	(** fof  **)

(* Copyright notice: x

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


(* -----bluebottle module -------*)
(* implementation of SIGNED64 is quick and dirty, only used for one demonstrational issue (antsRandom),
when MathH available use MathH instead *)

IMPORT Display,Objects,Strings,vyHost,Gadgets,antsCommandInvoker,Oberon, Modules, SYSTEM,
Attributes,ListRiders,Desktops,vyPortability,Out,Kernel,AosModules := Modules IN A2, Machine IN A2;
TYPE
	display* = ANY;
	dialog*= POINTER TO RECORD (Objects.ObjDesc)
		context*: ANY;
		cmd*: ARRAY 64 OF CHAR;
		time: SIGNED32;
		filter : ARRAY 256 OF CHAR;
	END;
	storeFileDialog* = POINTER TO RECORD (dialog)
		name*: ARRAY 256 OF CHAR;
	END;
	openFileDialog*= POINTER TO RECORD (dialog)
		name*: ARRAY 257 OF CHAR;
	END;
	Type*= vyPortability.Type;
	FileEnum*  = PROCEDURE (path, name: ARRAY OF CHAR;              time, date, size: SIGNED32;              attrs: SET);

	Hugeint*= SIGNED64;

VAR dialogtime: SIGNED32; (* to prevent from execution of old "forgotten" dialogs, we do not force the user to close open dialogs, do a warning ? *)
thed: dialog;
 PathChar*: CHAR;
 ONE* :SIGNED64;

PROCEDURE SetMousePointDisplay*;
(* do nothing, there is only one display in Native Oberon *)
END SetMousePointDisplay;

PROCEDURE GetCurrentDisplay*(): display;
BEGIN
	RETURN NIL;
END GetCurrentDisplay;

PROCEDURE SetCurrentDisplay*(d: display);
END SetCurrentDisplay;

PROCEDURE Desktop*(): display;
BEGIN
	RETURN NIL;
END Desktop;

PROCEDURE EmptyFilter*(d: dialog);
BEGIN
	d.filter := "";
END EmptyFilter;

PROCEDURE AddFilter*(d: dialog; filtername,filter: ARRAY OF CHAR);
BEGIN
	 Strings.Append(d.filter,";"); Strings.Append(d.filter,filter);
END AddFilter;

PROCEDURE FilterName(d: dialog; VAR pos: SIGNED32; VAR name: ARRAY OF CHAR ): BOOLEAN;
VAR i: SIGNED32;
BEGIN
	IF d.filter[pos] = 0X THEN RETURN FALSE END;
	i := pos;
	LOOP
		name[i-pos] := d.filter[i];
		IF (d.filter[i] = ";") THEN name[i-pos] := 0X; pos := i+1;  RETURN TRUE
		ELSIF d.filter[i] = 0X THEN pos := i; RETURN TRUE
		ELSIF i = LEN(d.filter) THEN RETURN FALSE
		END;
		INC(i);
	END;
END FilterName;


PROCEDURE InitDialog*;
VAR context,obj: Objects.Object; C: ListRiders.ConnectMsg;R: ListRiders.Rider; pos: SIGNED32; d: ListRiders.String; s: ARRAY 64 OF CHAR;
BEGIN
	IF thed = NIL THEN RETURN END;
	NEW(d);
	context := antsCommandInvoker.context;
	IF context # NIL THEN
		WITH context: Gadgets.Frame DO
			dialogtime := Oberon.Time(); thed.time := dialogtime;
			Attributes.SetInt(context,"dialogtime",dialogtime);
			obj := Gadgets.FindObj(context,"BasicButton");
			IF obj # NIL THEN
						IF thed IS openFileDialog THEN
						WITH thed: openFileDialog DO Attributes.SetString( obj, "Caption", "Open" );
						END;
					ELSIF thed IS storeFileDialog THEN
						WITH thed: storeFileDialog DO Attributes.SetString( obj, "Caption", "Store" );
						END;
					END;
				Gadgets.Update(obj);
			END;
			obj := Gadgets.FindObj(context,"Filter");
			IF obj # NIL THEN
				C.R := NIL; Objects.Stamp(C); obj.handle(obj, C);
				IF C.R # NIL THEN
					R := C.R;
					WHILE ~R.eol DO R.do.DeleteLink(NIL, R) END;
					R.do.Set(R, 0);
					pos := 0;
					WHILE (FilterName(thed,pos,s)) DO
						IF s # "" THEN
						NEW(d); COPY(s,d.s);
						R.do.Write(R, d);
						END;
					END;
					Gadgets.Update(obj);
				END;
			END;
		END;
	END;
END InitDialog;

PROCEDURE ExecuteDialog*;
VAR context,fileobj: Objects.Object; time: SIGNED32; filestring: ARRAY 256 OF CHAR; res: SIGNED16;
BEGIN
	 context := Gadgets.context;
	 Attributes.GetInt(context,"dialogtime",time);
	 IF time = dialogtime THEN
	 	fileobj := Gadgets.FindObj(context,"File");
	 	IF fileobj # NIL THEN
	 		Attributes.GetString(fileobj,"Value",filestring);
	 				IF thed IS openFileDialog THEN
					WITH thed: openFileDialog DO COPY( filestring, thed.name );
					END;
				ELSIF thed IS storeFileDialog THEN
					WITH thed: storeFileDialog DO COPY( filestring, thed.name );
					END;
				END;
	 		Desktops.CloseDoc;
	 		vyHost.CallWString(thed.cmd,"",FALSE,res);
	 	END;
	 ELSE
	 	fileobj := Gadgets.FindObj(context,"outoftime");
	 	IF fileobj # NIL THEN Attributes.SetInt(fileobj,"Color",0) END;
	 	Out.String("Sorry, this dialog is out of time"); Out.Ln;
	 END;
END ExecuteDialog;


PROCEDURE ShowDialog*(d: dialog);
VAR res: SIGNED16;
BEGIN
	thed := d;
	 vyHost.CallWString("Desktops.OpenDoc","antsFiles.Panel",FALSE,res);
END ShowDialog;

PROCEDURE FinishDialog*;
END FinishDialog;
(*
f you have a TypeDesc t returned by Modules.ThisType, the following
should be the equivalent of LevelOf (assuming MaxTags is a power of two):

SYSTEM.VAL(SIGNED32, t.flags) MOD AosModules.MaxTags

If this works, let me know so I can add it.

cheers
-- Pieter
*)



PROCEDURE TypesThis*(m: Modules.Module; name: ARRAY OF CHAR): Type;
BEGIN RETURN AosModules.ThisType(m,name)
END TypesThis;

PROCEDURE TypesTypeOf*(p: ANY): Type;
BEGIN RETURN vyPortability.TypeOf(p)
END TypesTypeOf;

PROCEDURE TypesLevelOf*(t: Type): SIGNED16;
BEGIN RETURN SHORT(SYSTEM.VAL(SIGNED32, t.flags) MOD AosModules.MaxTags)
END TypesLevelOf;

PROCEDURE TypesBaseOf*(t: Type; level: SIGNED16): Type;
(*not failsafe, but ok since is system part*)
BEGIN
	SYSTEM.GET(SYSTEM.VAL(SIGNED32,t.tag)-8 -4*level, t);
	IF t # NIL THEN
		SYSTEM.GET(SYSTEM.VAL(SIGNED32, t) - 4, t)
	END;
	RETURN t
END TypesBaseOf;

PROCEDURE GetWorkingDirectory*(VAR path: ARRAY OF CHAR);
BEGIN
	COPY("",path);
END GetWorkingDirectory;

PROCEDURE ChangeDirectory*(path: ARRAY OF CHAR; VAR done: BOOLEAN);
BEGIN done := (path = "")
END ChangeDirectory;

PROCEDURE EnumerateFiles*(indir,name: ARRAY OF CHAR; detailed: BOOLEAN; enum: FileEnum);
VAR notyetimplemented: BOOLEAN;
BEGIN notyetimplemented := TRUE; HALT(100);
END EnumerateFiles;

	PROCEDURE HIToLR*( h: SIGNED64 ): FLOAT64;
	BEGIN
		RETURN h;
		(*
		RETURN 1.0D0 * h.low + 1.0D0 * h.hi * MAX( SIGNED32 );
		*)
	END HIToLR;
	PROCEDURE LRToHI*( l: FLOAT64 ): SIGNED64;
	VAR h: SIGNED64;
	BEGIN
		RETURN ENTIER(l);
		(*
		h.hi := ENTIER( l / MAX( SIGNED32 ) );  h.low := ENTIER( l - 1.0D0 * h.hi * MAX( SIGNED32 ) + 0.5 );  RETURN h;
		*)
	END LRToHI;
	PROCEDURE LIToHI*( l: SIGNED32 ): SIGNED64;
	VAR h: SIGNED64;
	BEGIN
		RETURN l;
		(*
		h.hi := 0;  h.low := l;  RETURN h;
		*)
	END LIToHI;

PROCEDURE Modulus*(x,y: SIGNED64): SIGNED64;
VAR xr,yr,mod: FLOAT64;
BEGIN
	xr := HIToLR(x);
	yr := HIToLR(y);
	mod := xr- ENTIER(xr / yr)*yr;
	RETURN LRToHI(mod);
END Modulus;

PROCEDURE Multiply*(x,y: SIGNED64): SIGNED64;
BEGIN
	RETURN LRToHI(HIToLR(x)*HIToLR(y));
END Multiply;

PROCEDURE Add*(x,y: SIGNED64): SIGNED64;
BEGIN
	RETURN LRToHI(HIToLR(x)+HIToLR(y));
END Add;

	PROCEDURE Equal*( x, y: SIGNED64 ): BOOLEAN;
	BEGIN
		RETURN x=y;
		(*
			IF x.low # y.low THEN RETURN FALSE END;
		IF x.hi # y.hi THEN RETURN FALSE END;
		RETURN TRUE;
		*)
	END Equal;

(*
PROCEDURE Test*;
VAR l: FLOAT64; h: SIGNED64;
BEGIN
	l := 1.2345D13;
	aM.SR("l = ",l);
	h := LRToHI(l);
	aM.SISI("l.low",h.low,"l.hi",h.hi);
	l := HIToLR(h);
	aM.SR("l = ",l);
END Test;
*)

(*! use AOSModules.Module *)

PROCEDURE IdentifyCommand*(m: Modules.Module; pc: SIGNED32; VAR pname: ARRAY OF CHAR);
(* not failsafe, especially not if no command called *)
VAR codeadr,adr,maxadr,i: SIGNED32; cname: ARRAY 256 OF CHAR;
BEGIN
	COPY("",pname);
	IF (m # NIL) & (LEN(m.command)>0) THEN
	cname := ""; COPY(m.name,pname);
	i := 0; codeadr := ADDRESSOF(m.code[0]);
	maxadr := 0;
	WHILE(i<LEN(m.command))  DO
   	adr := SYSTEM.VAL(SIGNED32,m.command[i].entryAdr)-codeadr;

   	IF (adr < pc) & (adr > maxadr) THEN
   		maxadr := adr;
       	COPY(m.command[i].name,cname);
       END;
   	INC(i);
    END;
	Strings.Append(pname,"."); Strings.Append(pname,cname);
    END;
 END IdentifyCommand;


PROCEDURE IdentifyCaller*(VAR m: Modules.Module; VAR pc: SIGNED32);
(* note: proc works correct only, if caller has been a command *)
VAR ebp, eip: SIGNED32; i,adr: SIGNED32;
BEGIN
  ebp := SYSTEM.GetFramePointer();
  SYSTEM.GET(ebp, ebp);  (* stack frame of caller *)
  SYSTEM.GET(ebp+4, eip);  (* return address from caller *)
  m := AosModules.ThisModuleByAdr(eip);
  IF m # NIL THEN
    pc := eip - ADDRESSOF(m.code[0]);
  ELSE
    pc := MAX(SIGNED32);
  END;
END IdentifyCaller;

PROCEDURE FileDirSameName*(VAR a,b: ARRAY OF CHAR): BOOLEAN;
		VAR i, j: SIGNED32;
	BEGIN
		i := 0; j := 0;
		WHILE (a[i] # 0X) & (b[j] # 0X) & (CAP(a[i]) = CAP(b[j])) DO
			INC(i); INC(j)
		END;
		RETURN (a[i] = 0X) & (b[j] = 0X)
END FileDirSameName;

PROCEDURE FileDirRelFileName*(fileName: ARRAY OF CHAR; VAR relFileName: ARRAY OF CHAR);
BEGIN
	COPY(fileName,relFileName);
END FileDirRelFileName;

BEGIN PathChar := "/"; NEW(thed);  ONE := 1; Out.String("antsPortability: bluebottle version launched"); Out.Ln;
END antsPortability.
antsPortability.Test ~
