MODULE antsSecurity IN Oberon; 	(** fof  **)
(*
this module is mainly based on the Module Win32.Oberon.Mod, copyright by ETH recalled:

ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/

Windows specific parts: Copyright (c) 1994 - 2000 Emil J. Zeller
*)
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
(** ants,Felix Friedrich, (C) 1998-2001 *)

(** Module for procedures called in a Windows environment, Prevents from System-Halts due to lost Displays,
for consistency reasons only ONE thread at a time allowed to be run in background !
background threads must not open or close any displays !*)

(*

*)
(*----------------- non-windows module ---------------*)

IMPORT Oberon,Texts,Modules,Objects,Strings;
VAR
	allowMultipleThreads*: BOOLEAN;
	blocked*: BOOLEAN;
	w: Texts.Writer;

	PROCEDURE Assert* (asserted: BOOLEAN; fail: ARRAY OF CHAR);
	BEGIN
		IF ~asserted THEN Texts.WriteString(w,fail); Texts.WriteLn(w); Texts.Append(Oberon.Log,w.buf); ASSERT(asserted) END;
	END Assert;

	PROCEDURE Block*; (* Block + release only used for Windows *) END Block;

	PROCEDURE Release*; END Release;

	PROCEDURE Command* (P: ARRAY OF CHAR);
	BEGIN
	ASSERT(P # "");
	END Command;

	PROCEDURE Call*;
	VAR sc: Texts.Scanner; res: INTEGER;
	BEGIN
	Texts.OpenScanner(sc, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(sc);
	IF sc.class = Texts.Name THEN
		INC(Oberon.Par.pos, Strings.Length(sc.s) + 1);
		Oberon.Call(sc.s, Oberon.Par, FALSE, res)
	END
	END Call;

	PROCEDURE CheckDisplay* (halt: BOOLEAN): BOOLEAN; BEGIN RETURN TRUE END CheckDisplay;

	PROCEDURE Execute* (P: Modules.Command); BEGIN P() END Execute;

	PROCEDURE Halt* (cause: ARRAY OF CHAR);
	BEGIN Texts.WriteString(w,cause); Texts.WriteLn(w); Texts.Append(Oberon.Log,w.buf); HALT(101);
	END Halt;

	PROCEDURE Kill*; END Kill;

	PROCEDURE Stop*; END Stop;

	PROCEDURE OpenScript* (t: Texts.Text; pos, num: LONGINT; executorObj, context: Objects.Object): BOOLEAN; BEGIN RETURN FALSE END OpenScript;

	PROCEDURE SetProgress* (i: INTEGER); END SetProgress; (* for interactive visualization of progress *)

	PROCEDURE Init*; END Init;

BEGIN
	  allowMultipleThreads := FALSE; Texts.OpenWriter(w); blocked := FALSE;
END antsSecurity.

(*
;
*)

(* testing
_____________________________________________________________________________________________________________________________________________________________________________________
antsSecurity.Call antsSecurity.TestBigMatrix

System.State antsSecurity ~

ants / Freiberg3.Automatic
antsSecurity.TestLoop ~
antsSecurity.InstallTrap
System.ShowTasks ~
antsSecurity.InitSupervisor
antsSecurity.Call antsSecurity.TestTrap ~
System.ShowThreads
antsSecurity.Call System.Time ~

Is that me ?
System.ShowThreads
antsSecurity.TestTrap ~ (* traps auffangen im security task ! , verlust des executor tasks abfangen !!*)

System.ShowTasks ~

antsSecurity.Test3

antsSecurity.Init

fofAutomatic.Do
System.Time
~

fofAutomatic.Do > iter 1000 > secure
System.Time
~
antsSecurity.Init
fofAutomatic.Do
System.Time
antsMC.Forward f3Chain 1 300 ~
System.Time
antsSecurity.Call antsMC.Forward f3Chain 1 300 ~
~

antsSecurity.Kill ~ Executor ~
antsSecurity.AbortExecutor ~

antsSecurity.StopScript
antsSecurity.

antsSecurity.FindLastEvent ~
antsSecurity.Execute System.Time ~
antsSecurity.Execute Voyager.Random 200 ~
antsSecurity.Execute antsSecurity.ShowPar test ~
antsSecurity.ShowThreads ~
antsSecurity.Execute antsSecurity.Test4 ~
antsSecurity.Call ~
antsSecurity.Call antsSecurity.Test2 ~
antsSecurity.Wait


antsSecurity.TestThread
antsSecurity.EndThread

antsSecurity.OpenProgress
antsSecurity.CloseProgress

antsSecurity.Test ~
antsSecurity.Test2 ~
antsSecurity.Test4 ~

Desktops.OpenWinDoc test.Text ~
antsSecurity.Details ~

System.Free fofAutomatic antsSecurity ~

System.DeleteFiles antsSecurity.Obj ~
antsSecurity.Call
fofAutomatic.Do > crude > interactive
System.Time
~


(*
PROCEDURE Test*;
VAR ok,keys: SET; x,y: INTEGER; res: INTEGER;
BEGIN
Input.Mouse(ok,x,y); keys := ok;
WHILE(ok=keys) DO
Input.Mouse(keys,x,y);
IF ~Ok(TRUE) THEN RETURN END;
END;
END Test;

PROCEDURE Test2*;
BEGIN
SYSTEM.GET(ADDRESSOF(Exceptions.displayTrap),oldtrapper); trapName := "Cause: System Trap"; Exceptions.displayTrap := DisplayTrap; HALT(100)
END Test2;

PROCEDURE Test3*;
VAR ok,keys: SET; x,y: INTEGER;time : LONGINT;
BEGIN
HALT(99);
END Test3;

PROCEDURE Details*;
BEGIN
Exceptions.displayTrap(laste);
END Details;


(*
PROCEDURE CheckDisplay (t: Oberon.Task);
BEGIN
IF Display.cur.hWnd = 0 THEN (* Display not available*)
SYSTEM.GET(ADDRESSOF(Exceptions.displayTrap),oldtrapper);
Exceptions.displayTrap := DisplayTrap; trapName := "Cause: System Trap"; HALT(100)
END;
END CheckDisplay;

PROCEDURE Init;
VAR t: Oberon.Task;
BEGIN
NEW(t);
t.safe := FALSE;
t.handle := CheckDisplay;
Oberon.Install(t);
END Init;

*)

BEGIN
(*	Init(); *)
PROCEDURE TestTrap*;
BEGIN
HALT(100);
END TestTrap;

PROCEDURE Time*;
VAR time: LONGINT; i: LONGREAL;
BEGIN
time := Oberon.Time()+Input.TimeUnit;
WHILE Oberon.Time() < time DO
i := i+1;
END;
Out.LongReal(i,30);
Out.Int(MAX(LONGINT) DIV 2 DIV 1000,20);
END Time;

PROCEDURE Test*;
BEGIN
LOOP END;
END Test;

PROCEDURE Test2*;
BEGIN
LOOP Out.Ln; Out.Int(Oberon.Time(),20); END;
END Test2;

PROCEDURE Test3*;
BEGIN
IF executor = NIL THEN RETURN END;
END Test3;

PROCEDURE TestBM (A: ARRAY OF LONGREAL);
BEGIN
A[0] := 0;
END TestBM;

PROCEDURE TestBigMatrix*;
VAR A: POINTER TO ARRAY OF LONGREAL;
BEGIN
Out.Ln; Out.String("Calling testbigmatrix..");
NEW(A,100000);
TestBM(A^);
END TestBigMatrix;

PROCEDURE ShowPar*;
VAR sc: Texts.Reader; ch: CHAR; i: INTEGER;
BEGIN
Texts.OpenReader(sc,Oberon.Par.text,Oberon.Par.pos);
i := 0; Texts.Read(sc,ch);
WHILE (~sc.eot) & (i<40) DO
Out.Char(ch);
Texts.Read(sc,ch); INC(i);
END;
END ShowPar;

PROCEDURE p (t: Threads.Thread);
BEGIN
Out.Ln; Out.String(t.name);
END p;

PROCEDURE ShowThreads*;
BEGIN
Threads.Enumerate(p);
END ShowThreads;
*)
*)