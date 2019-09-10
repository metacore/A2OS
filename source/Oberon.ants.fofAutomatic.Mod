MODULE fofAutomatic IN Oberon;
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



(* module was originally based on the module Automatic.Mod by Michael Franz *)

(*
A simple macro facility for executing several commands in succession.

Position the Star Marker in this viewer (Enter on Keypad)
Compiler.Compile *

Sample Activation:
Automatic.Do
System.Directory *.Mod
System.ShowCommands System ~
Browser.ShowDef TextFrames ~
~
*)

IMPORT Texts, Oberon, antsCommands, Input, TextFrames, Display, Gadgets, Objects, Out, antsSecurity, aM := antsMessages;

TYPE

	Loop = OBJECT
	VAR
		startpos: SIGNED32;
		total: SIGNED32;
		current: SIGNED32;
		loop: Loop;

		PROCEDURE & Init( pos: SIGNED32 );
		BEGIN
			startpos := pos;
		END Init;

	END Loop;

	Task = POINTER TO TaskDesc;
	TaskDesc = RECORD (Oberon.TaskDesc)
		executorObj: Objects.Object;
		context: Objects.Object;
		curnum, num: SIGNED32;
		interactive: BOOLEAN;
		text: Texts.Text;
		pos: SIGNED32;
		curtext: Texts.Text;
		curpos: SIGNED32;
		checktime: SIGNED32;
		contextFrame: Display.Frame;
		mynext: Task
	END;

VAR
	diag: BOOLEAN;  mintime, maxtime, minchecktime: SIGNED32;  tempX: SIGNED16;  lastcontext: Objects.Object;  found: BOOLEAN;  tasks: Task;
	current*, stopped*, demon*: Oberon.Task;  locked*: BOOLEAN;

	PROCEDURE NextLine( text: Texts.Text;  pos: SIGNED32 ): SIGNED32;
	VAR R: Texts.Reader;  ch: CHAR;
	BEGIN
		IF pos < text.len THEN
			Texts.OpenReader( R, text, pos );  Texts.Read( R, ch );
			WHILE ~R.eot & (ch # 0DX) DO Texts.Read( R, ch ) END;
			IF R.eot THEN RETURN -1 ELSE RETURN Texts.Pos( R ) END
		ELSE RETURN -1
		END
	END NextLine;

(*
PROCEDURE Equal (r1,r2: User32.Rect): BOOLEAN;
BEGIN
IF r1.left # r2.left THEN RETURN FALSE
ELSIF r1.right # r2.right THEN RETURN FALSE
ELSIF r1.bottom # r2.bottom THEN RETURN FALSE
ELSIF r1.top # r2.top THEN RETURN FALSE
ELSE RETURN TRUE
END;
END Equal;
*)

	PROCEDURE NextCommand( VAR text: Texts.Text;  VAR pos: SIGNED32;  execute: BOOLEAN;  VAR bt: SIGNED32 );
	VAR S: Texts.Scanner;  res: SIGNED16;  time, stop: SIGNED32;
	BEGIN
		IF current = stopped THEN RETURN END;
		Oberon.Par.text := text;  Texts.OpenScanner( S, text, pos );
		Texts.Scan( S );  pos := Texts.Pos( S );   (* fof 020714 *)

		IF (S.class = Texts.Name) & (S.s = "timed") THEN
			Texts.Scan( S );
			IF S.class = Texts.Int THEN
				time := S.i;  stop := Input.Time() + time * Input.TimeUnit DIV 1000;  aM.dSI( "fofAuto: timed command:", time );  Texts.Scan( S )
			END
		ELSE stop := Input.Time();
		END;

		IF S.class = Texts.Name THEN
			IF execute THEN aM.vSS( "Auto>", S.s );  Oberon.Par.pos := Texts.Pos( S ) - 1;  Oberon.Call( S.s, Oberon.Par, FALSE , res ) END;
			IF res # 0 THEN aM.eSS( "fofAutomatic: could not call ", S.s );  END;
			pos := NextLine( text, pos - 1 );
			IF pos = -1 THEN pos := Texts.Pos( S );  text := NIL END;
			time := Input.Time();
			IF time < stop THEN bt := stop;  aM.dSISI( "bt = ", bt, "time=", time );  END;
		ELSE text := NIL
		END
	END NextCommand;

	PROCEDURE OneTimeSlice( t: Oberon.Task ): BOOLEAN;
	VAR start, stop: SIGNED32;  task: Task;
	BEGIN
		IF current = stopped THEN RETURN TRUE END;
		start := Oberon.Time();  stop := start + mintime;  task := t( Task );
		WHILE (Oberon.Time() < stop) DO
			IF current = stopped THEN RETURN TRUE END;
			IF task.curtext = NIL THEN
				INC( task.curnum );
				IF task.curnum > task.num THEN RETURN FALSE END;
				aM.vSI( "fofAutomatic: Auto run #", task.curnum );  task.curtext := task.text;  task.curpos := task.pos
			END;
			Gadgets.executorObj := task.executorObj;  Gadgets.context := task.context;
			NextCommand( task.curtext, task.curpos, TRUE , task.time );
			IF task.time > Input.Time() THEN aM.dSI( "nexttime : ", task.time );  RETURN TRUE END;
		END;
		RETURN TRUE
	END OneTimeSlice;

	PROCEDURE TempHandle( obj: Objects.Object;  VAR msg: Objects.ObjMsg );
	BEGIN
		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO found := TRUE
			END;
		ELSE
		END
	END TempHandle;

	PROCEDURE CheckOnDisplay( t: Task ): BOOLEAN;
	VAR msg: Display.DisplayMsg;  f: Display.Frame;  orighandle: Objects.Handler;
	BEGIN
		f := t.contextFrame;
		IF f = NIL THEN RETURN TRUE END;
		orighandle := f.handle;  f.handle := TempHandle;  tempX := 0;  found := FALSE;  msg.F := f;  msg.device := Display.screen;
		msg.id := Display.full;  msg.res := -1;  Display.Broadcast( msg );  f.handle := orighandle;
		IF found THEN RETURN TRUE ELSE RETURN FALSE END
	END CheckOnDisplay;

	PROCEDURE DoTask( t: Oberon.Task );
	BEGIN
		IF t.time > Input.Time() THEN RETURN END;
		current := t;
		IF current = stopped THEN RETURN END;
		IF ~OneTimeSlice( t ) THEN Oberon.Remove( t );  current := NIL;  RETURN END;
		IF current = stopped THEN RETURN END;
		WITH t: Task DO
			IF (Oberon.Time() - t.checktime) > minchecktime THEN
				t.checktime := Oberon.Time();
				IF ~CheckOnDisplay( t( Task ) ) THEN aM.eS( "Shutted down automatic task. Context lost" );  Oberon.Remove( t );  current := NIL;  RETURN END
			END
		END;
		current := NIL
	END DoTask;

	PROCEDURE Search( c: Objects.Object ): Task;
	VAR chain: Task;
	BEGIN
		chain := tasks;
		WHILE ((chain.mynext) # NIL ) DO
			IF chain.mynext.contextFrame = c THEN RETURN chain.mynext END;
			chain := chain.mynext
		END;
		RETURN NIL
	END Search;

	PROCEDURE Remove( t: Task );
	VAR chain: Task;  this: Task;
	BEGIN
		this := NIL;  chain := tasks;
		WHILE ((chain.mynext) # NIL ) DO
			IF (chain.mynext = t) OR (t = NIL ) THEN this := chain END;
			chain := chain.mynext
		END;
		IF this # NIL THEN aM.vS( "Task shut down." );  Oberon.Remove( this.mynext );  this.mynext := this.mynext.mynext END
	END Remove;

	PROCEDURE Install( t: Task );
	VAR chain: Task;
	BEGIN
		aM.dS( "fofAutomatic: Installing task" );  chain := tasks;
		WHILE (chain.mynext # NIL ) DO chain := chain.mynext END;
		chain.mynext := t;  t.time := Input.Time();  Oberon.Install( t )
	END Install;

	PROCEDURE TCopy( t: Texts.Text;  from, to: SIGNED32 ): Texts.Text;
	VAR copy: Texts.Text;  b: Texts.Buffer;
	BEGIN
		NEW( copy );  Texts.Open( copy, "temp" );  NEW( b );  Texts.OpenBuf( b );  Texts.Save( t, from, to, b );  Texts.Append( copy, b );
		RETURN copy
	END TCopy;

	PROCEDURE Do*;
	VAR l: antsCommands.tScanList;  num: SIGNED32;  pos: SIGNED32;  keys: SET;  x, y: SIGNED16;
		filename: ARRAY 128 OF CHAR;
		text: Texts.Text;  task: Task;  context: Objects.Object;  timex: SIGNED32;
	BEGIN
		IF locked THEN aM.eS( "fofAutomatic is locked, execute fofAutomatic.Unlock to release" );  RETURN END;
		NEW( task );  task.handle := DoTask;  task.safe := FALSE;  task.time := 0;  context := Gadgets.context;
		IF context # NIL THEN
			IF context IS Display.Frame THEN
				task.contextFrame := context( Display.Frame );  lastcontext := task.contextFrame;  aM.dS( "fofAutomatic: context is Display Frame" );
			END
		ELSE  (* called by a script *)
			aM.dS( "fofAutomatic: called by a script, using last context" );
			IF lastcontext # NIL THEN task.contextFrame := lastcontext( Display.Frame ) ELSE aM.dS( "last context is NIL" );  END
		END;

		l := antsCommands.ScanFromPar( "[>iter] [iter=INT] [>interactive] [>safe] [file=STR] [script=STR] [>defocus]" );
		IF ~antsCommands.FindKeyword( l, "iter" ) THEN num := 1 ELSE
			IF antsCommands.GetNumberFromKeyword( l, "iter", num ) THEN aM.dSI( "fofAutomatic: iterations=", num );  END
		END;
		task.num := num;  task.curnum := 0;  task.interactive := antsCommands.FindKeyword( l, "interactive" );
		IF task.interactive THEN
			aM.dS( "fofAutomatic: Interactive task" );  task.num := MAX( SIGNED32 );  Input.Mouse( keys, x, y );
			WHILE (keys # {}) DO Input.Mouse( keys, x, y ) END
		END;
		IF antsCommands.FindKeyword( l, "safe" ) THEN task.contextFrame := NIL END;
		IF antsCommands.FindKeyword( l, "file" ) THEN
			IF antsCommands.ExpectStringFromKeyword( l, "file", filename ) THEN
				aM.dSS( "fofAutomatic: called with file=", filename );  text := TextFrames.Text( filename );  Oberon.Par.text := text;  Oberon.Par.pos := 0;
				IF task.interactive THEN antsSecurity.Halt( "fofAutomatic: Keyword interactive not allowed with file" ) END
			END
		ELSIF antsCommands.FindKeyword( l, "script" ) THEN
			IF antsCommands.ExpectStringFromKeyword( l, "script", filename ) THEN
				aM.dSS( "fofAutomatic: using script=", filename );  text := TextFrames.Text( filename );
				ASSERT ( text # NIL );
				Oberon.Par.text := text;  Oberon.Par.pos := 0
			END
		ELSE Oberon.Par.pos := NextLine( Oberon.Par.text, Oberon.Par.pos )
		END;

		text := Oberon.Par.text;  pos := Oberon.Par.pos;  current := demon;
		WHILE (text # NIL ) DO NextCommand( text, pos, FALSE , timex ) END;
		current := NIL;  task.text := TCopy( Oberon.Par.text, Oberon.Par.pos, pos );  task.pos := 0;
		(*
	task.pos := Oberon.Par.pos;  task.text := Oberon.Par.text;
	*)
		task.curtext := NIL;  task.curnum := 0;  task.executorObj := Gadgets.executorObj;  task.context := Gadgets.context;
		(* IF task.context # NIL THEN Gadgets.Update(task.context) END; (* set up all parameters *)  *)
		IF antsCommands.FindKeyword( l, "defocus" ) THEN aM.dS( "fofAutomatic.Defocus" );  Oberon.Defocus;  END;

		IF antsCommands.FindKeyword( l, "secure" ) THEN
			aM.dS( "fofAutomatic: secure task requested" );
			IF ~antsSecurity.OpenScript( task.text, task.pos, task.num, task.executorObj, task.context ) THEN
				aM.vS( "fofAutomatic: secure task not available, currently implemented for windows only." );  Install( task );  DoTask( task )
			END;
		ELSIF antsCommands.FindKeyword( l, "wait" ) THEN  (* do it right away *)
			task.curnum := 0;  current := task;

			WHILE (task.curnum < task.num) DO
				task.curtext := task.text;  task.curpos := task.pos;  Gadgets.executorObj := task.executorObj;
				Gadgets.context := task.context;
				WHILE (task.curtext # NIL ) DO NextCommand( task.curtext, task.curpos, TRUE , task.time );  END;
				INC( task.curnum );
			END;
		ELSE
			IF task.num > 1 THEN Install( task );  DoTask( task ) ELSE Install( task );  DoTask( task ) END
		END
	END Do;

	(*
PROCEDURE Do*;
VAR S: Texts.Scanner;  res: SIGNED16;  lastpos: SIGNED32;  lasttext: Texts.Text;  l: antsCommands.tScanList;  i,num: SIGNED32;
pos: SIGNED32;  diag: BOOLEAN;  interactive: BOOLEAN;  keys: SET;  x,y: SIGNED16;  filename: ARRAY 128 OF CHAR;
text: Texts.Text;  adr: SIGNED32; orig,new: User32.Rect; disp: Displays.Display; event: Displays.Event;
BEGIN
l := antsCommands.ScanFromPar();
IF ~antsCommands.FindKeyword(l,"iter") THEN
num := 1
ELSE
IF antsCommands.GetNumberFromKeyword(l,"iter",1,num) THEN END;
END;
interactive := antsCommands.FindKeyword(l,"interactive");
IF interactive THEN antsToolbox.StartDisplayHelp("Any mouse button inside this window to stop running script."); END;
IF interactive THEN
num := MAX(SIGNED32); Input.Mouse(keys,x,y); WHILE (keys#{}) DO Input.Mouse(keys,x,y); END;
END;
IF antsCommands.FindKeyword(l,"diag") THEN diag := TRUE ELSE diag := FALSE END;
IF antsCommands.FindKeyword(l,"file") THEN
IF antsCommands.ExpectStringFromKeyword(l,"file",2,filename) THEN
text := TextFrames.Text(filename);
Oberon.Par.text := text;  Oberon.Par.pos := 0;
END;
END;
pos := Oberon.Par.pos;
adr := User32.GetWindowRect(Display.cur.hWnd,orig);
FOR i := 0 TO num-1 DO
IF Display.cur.hWnd = 0 THEN (* Display not available*) RETURN END;
adr := User32.GetWindowRect(Display.cur.hWnd,new);
IF ~Equal(new,orig) THEN
User32.GetWindowRect(Display.cur.hWnd,orig) ;
adr := User32.UpdateWindow(Display.cur.hWnd);
disp := Displays.root;
WHILE disp#NIL DO
WITH disp: Viewers.Window DO
(* check for rect intersect first ! *)
Viewers.Update(disp.viewer,FALSE);
ELSE
END;
disp := disp.link;
END;
END;
IF interactive THEN
Input.Mouse(keys,x,y);
IF keys#{} THEN antsToolbox.EndDisplayHelp();  RETURN
ELSE
event := Displays.GetEvent();
IF (event#NIL) & (event.disp # NIL) THEN Display.SetCurrent(event.disp); END;
END;

END;
Oberon.Par.pos := pos;
IF diag THEN
Texts.WriteString(W, "Auto run #");  Texts.WriteInt(W,i+1,5);  Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf);
END;
Oberon.Par.pos:=NextLine(Oberon.Par.text, Oberon.Par.pos);

DoOnce(Oberon.Par.text, Oberon.Par.pos,diag);
(*Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
Texts.Scan(S);
WHILE	S.class=Texts.Name	DO	Oberon.Par.pos:=Texts.Pos(S)-1;
IF diag THEN
Texts.WriteString(W, "Auto> ");  Texts.WriteString(W, S.s);  Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf);
END;
lastpos := Oberon.Par.pos;  lasttext := Oberon.Par.text;
Oberon.Call(S.s, Oberon.Par, FALSE, res);
Oberon.Par.pos := lastpos;  Oberon.Par.text := lasttext;
Oberon.Par.pos:=NextLine(Oberon.Par.text, Oberon.Par.pos);
IF	Oberon.Par.pos > 0	THEN	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);  Texts.Scan(S)
ELSE	S.class:=Texts.Inval	END
END
*)
END;
END Do;
*)

(* should be unused *)
	PROCEDURE Schedule*;
	VAR S: Texts.Scanner;  res: SIGNED16;  lastpos: SIGNED32;  lasttext: Texts.Text;  l: antsCommands.tScanList;  i, num: SIGNED32;  pos: SIGNED32;  diag: BOOLEAN;  keys: SET;
		x, y: SIGNED16;
		filename: ARRAY 128 OF CHAR;
		text: Texts.Text;  etime, time: SIGNED32;
	BEGIN
		l := antsCommands.ScanFromPar( "[>diag] [file=STR] " );  Input.Mouse( keys, x, y );
		WHILE (keys # {}) DO Input.Mouse( keys, x, y ) END;
		IF antsCommands.FindKeyword( l, "diag" ) THEN diag := TRUE ELSE diag := FALSE END;
		IF antsCommands.FindKeyword( l, "file" ) THEN
			IF antsCommands.ExpectStringFromKeyword( l, "file", filename ) THEN
				text := TextFrames.Text( filename );  Oberon.Par.text := text;  Oberon.Par.pos := 0
			END
		END;

		pos := Oberon.Par.pos;

		LOOP
			Input.Mouse( keys, x, y );
			IF keys # {} THEN RETURN END;
			Oberon.Par.pos := pos;  aM.dSI( "fofAutomatic:Auto run #", i + 1 );  Oberon.Par.pos := NextLine( Oberon.Par.text, Oberon.Par.pos );

			Texts.OpenScanner( S, Oberon.Par.text, Oberon.Par.pos );  Texts.Scan( S );
			IF S.class # Texts.Int THEN RETURN END;
			num := S.i;  num := num * Input.TimeUnit;
			IF num = 0 THEN num := 1 END;
			Texts.Scan( S );
			WHILE S.class = Texts.Name DO
				Oberon.Par.pos := Texts.Pos( S ) - 1;  aM.dSS( "fofAutomatic: Auto> ", S.s );  lastpos := Oberon.Par.pos;  lasttext := Oberon.Par.text;
				time := Oberon.Time();   (*Oberon.GetClock(time,date); *)
				etime := time + num;
				WHILE (time < etime) DO
					Input.Mouse( keys, x, y );
					IF keys # {} THEN RETURN END;
					Oberon.Call( S.s, Oberon.Par, FALSE , res );  Oberon.Par.pos := lastpos;  Oberon.Par.text := lasttext;
					time := Oberon.Time()
					(*
				Oberon.GetClock(time,date);
				*)
				END;
				Oberon.Par.pos := lastpos;  Oberon.Par.text := lasttext;
				Oberon.Par.pos := NextLine( Oberon.Par.text, Oberon.Par.pos );
				IF Oberon.Par.pos > 0 THEN Texts.OpenScanner( S, Oberon.Par.text, Oberon.Par.pos );  Texts.Scan( S )
				ELSE S.class := Texts.Inval
				END;
				IF S.class = Texts.Int THEN
					num := S.i;  num := num * Input.TimeUnit;
					IF num = 0 THEN num := 1 END;
					Texts.Scan( S )
				END

			END
		END
	END Schedule;

	PROCEDURE Pause*;
	VAR l: antsCommands.tScanList;  time, etime, num: FLOAT64;  keys: SET;  x, y: SIGNED16;
	BEGIN
		l := antsCommands.ScanFromPar( "[time=INT]" );
		IF antsCommands.GetRealFromKeyword( l, "time", num ) THEN
			num := num * Input.TimeUnit;  time := Oberon.Time();  etime := time + ENTIER( num );
			WHILE (time < etime) DO
				Input.Mouse( keys, x, y );
				IF keys # {} THEN RETURN END;
				time := Oberon.Time()
			END
		END

	END Pause;

	PROCEDURE DiagOn*;
	BEGIN
		diag := TRUE
	END DiagOn;

	PROCEDURE DiagOff*;
	BEGIN
		diag := FALSE
	END DiagOff;

	PROCEDURE Stop*;
	VAR context: Objects.Object;
	BEGIN
		aM.vS( "fofAutomatic.Stop" );  context := Gadgets.context;
		IF context = NIL THEN aM.eS( "no context" ) END;
		Remove( Search( context ) );  antsSecurity.Stop
	END Stop;

	PROCEDURE StopAll*;
	BEGIN
		WHILE tasks.mynext # NIL DO Remove( NIL ) END
	END StopAll;

	PROCEDURE Lock*;
	BEGIN
		locked := TRUE;
	END Lock;

	PROCEDURE Unlock*;
	BEGIN
		locked := FALSE;
	END Unlock;

BEGIN
	NEW( demon );  diag := FALSE;  mintime := ENTIER( Input.TimeUnit * 0.01 );  maxtime := ENTIER( Input.TimeUnit * 0.1 );
	minchecktime := Input.TimeUnit;  NEW( tasks );  locked := FALSE;

END fofAutomatic.

System.Free fofAutomatic ~

fofAutomatic.Do > file "fofAutomatic.Test"~


fofAutomatic.Schedule   ~
0 antsObjects.DependentToFront f1Pict  ~
0 antsMC.Init f1Chain ~
2 fofAutomatic.Do > file ants / Freiberg1.Automatic ~
0 antsObjects.DependentToFront f2Pict  ~
0 antsMC.Init f2Chain ~
2 fofAutomatic.Do > file ants / Freiberg2.Automatic ~
0 antsObjects.DependentToFront f10Pict ~
0 fofAutomatic.Do > file ants / Freiberg10.Auto1 ~
2 fofAutomatic.Do > file ants / Freiberg10.Automatic ~
~


fofAutomatic.Stop

fofAutomatic.StopAll




fofAutomatic.Do
System.Time



System.Watch
