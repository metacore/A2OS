(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Oberon IN Oberon;	(** portable, except where noted *)

(* Aos version based on Oberon.Mod by JG et al. *)

(** Oberon system manager for dispatch of keyboard and mouse input,
scheduling of tasks, cursor handling and command execution.
*)

  IMPORT KernelLog IN A2, AosFS := Files IN A2, Commands IN A2, Fido IN A2, Kernel, Modules, Display, Input, Objects,
  	Viewers, Fonts, Texts, Files;

  CONST

    (** Message ids: *)
    defocus* = 0; neutralize* = 1; mark* = 2; (** ControlMsg*)
    consume* = 0; track* = 1; (** InputMsg*)
    get* = 0; set* = 1; reset* = 2; (** CaretMsg id, SelectMsg id*)

    GCInterval = 10000; ActVal = 2000;	(* was 100000 and 5000 *)

    Neutralise = 0A5X; SETUP = 0A4X;

  TYPE

    Painter* = PROCEDURE (x, y: SIGNED16);
	Marker* = RECORD
		Fade*, Draw*: Painter	(** Remove and draw marker. *)
	END;

	Cursor* = RECORD
	    marker*: Marker;	(** Cursor marker. *)
	    on*: BOOLEAN;	(** Is cursor shown? *)
	    X*, Y*: SIGNED16	(** Absolute cursor position. *)
	END;

    ParList* = POINTER TO ParRec;

    ParRec* = RECORD	(** Area for passing command parameters. *)
      vwr*: Viewers.Viewer;	(** Viewer in which command is executed. *)
      frame*: Display.Frame;	(** Frame of vwr from where command is executed. *)
      obj*: Objects.Object;	(** Object in vwr executing command. *)
      text*: Texts.Text;	(** Text parameter to be passed to command. *)
      pos*: SIGNED32	(** Starting position in text of parameter. *)
    END;

    ControlMsg* = RECORD (Display.FrameMsg)
      id*: SIGNED16;	(** defocus, neutralize, mark *)
      X*, Y*: SIGNED16	(** Absolute mark position. *)
    END;

    InputMsg* = RECORD (Display.FrameMsg)
      id*: SIGNED16;	(** consume, track *)
      keys*: SET;	(** Mouse buttons. *)
      X*, Y*: SIGNED16;	(** Mouse position. *)
      ch*: CHAR;	(** Character typed. *)
      fnt*: Fonts.Font;	(** Font of typed character. *)
      col*, voff*: SIGNED8	(** Color and vertical offset of typed character. *)
    END;

    CaretMsg* = RECORD (Display.FrameMsg)	(** Text caret handling. *)
      id*: SIGNED16;	(** get, set, reset *)
      car*: Display.Frame;	(** Destination frame, returned frame. *)
      text*: Texts.Text;	(** Text represented by car. *)
      pos*: SIGNED32	(** Caret position. *)
    END;

    SelectMsg* = RECORD (Display.FrameMsg)	(** Text selection handling. *)
      id*: SIGNED16;	(** get, set, reset *)
      time*: SIGNED32;	(** Time of the selection. *)
      sel*: Display.Frame;	(** Destination frame, returned frame. *)
      text*: Texts.Text;	(** Text represented by sel. *)
      beg*, end*: SIGNED32	(** Text stretch of the selection. *)
    END;

    ConsumeMsg* = RECORD (Display.FrameMsg)	(** Drag and drop control of text. *)
      text*: Texts.Text;	(** Text to be inserted. *)
      beg*, end*: SIGNED32	(** Text stretch to be inserted. *)
    END;

    RecallMsg* = RECORD (Display.FrameMsg)
    END;

    Task* = POINTER TO TaskDesc;

    Handler* = PROCEDURE (me: Task);

    TaskDesc* = RECORD
      next*: Task;	(** for internal use. *)
      time*: SIGNED32;	(** Earliest time to schedule task. *)
      safe*: BOOLEAN;	(** Don't remove from task queue when a trap occurs. *)
      handle*: Handler	(** Task handler. *)
    END;

  VAR
	Arrow*, Star*: Marker;	(** Normal Oberon arrow, and the star marker. *)
	Mouse*, Pointer*: Cursor;	(** Normal Oberon mouse, and the star pointer. *)

    Log*: Texts.Text;	(** The Oberon log. *)
    Par*: ParList;	(** Actual parameters of executed command. *)

    CurFnt*: Fonts.Font;	(** Current input font when typing. *)
    CurCol*, CurOff*: SIGNED8;	(** Current color and offset when typing. *)

	OptionChar*: CHAR;	(** Option character "/" or "\" *)
	OpenText*: PROCEDURE (title: ARRAY OF CHAR; T: Texts.Text; W, H: SIGNED16);

    CurTask: Task;
	NextTask*: Task;	(** non-portable, for internal use. *)

	New*: BOOLEAN;	(** enable new style mouse handling suitable for two-button mice *)

    DW, DH, CL, W0, H0, H1, H2, H3: SIGNED16;

    GCTask: Task; (* garbage collection task *)

    ScreenOn: BOOLEAN;
	FillerColor: SIGNED8;

	conftext: Texts.Text;
	conftime, confdate: SIGNED32;

	fido: Fido.Watchdog;

	OberonText: AosFS.FileName;

  (*clocks*)

(** Get time (t) and date (d).  day = d MOD 32, month = d DIV 32 MOD 16, year = 1900+d DIV 512,
	hour = t DIV 4096 MOD 32, minute = t DIV 64 MOD 64, second = t MOD 64 *)
     PROCEDURE GetClock* (VAR t, d: SIGNED32);
     BEGIN Kernel.GetClock(t, d)
     END GetClock;

 (** Set time (t) and date (d). *)
    PROCEDURE SetClock* (t, d: SIGNED32);
     BEGIN Kernel.SetClock(t, d)
     END SetClock;

 (** Return the number of timer ticks since Oberon startup. (See module Input for frequency) *)
    PROCEDURE Time* (): SIGNED32;
     BEGIN RETURN Input.Time()
     END Time;

  (*cursor handling*)

	  PROCEDURE FlipArrow (X, Y: SIGNED16);
	  VAR cx,cy,cw,ch: SIGNED16;
  	BEGIN
		Display.GetClip(cx, cy, cw, ch);
		Display.SetClip(0, 0, Display.Width, Display.Height);
		Display.CopyPattern(Display.FG, Display.arrow, X, Y - 14, 2);
		Display.SetClip(cx, cy, cw, ch)
  	END FlipArrow;

  	PROCEDURE FlipStar (X, Y: SIGNED16);
  	BEGIN
		  IF X < CL THEN
		  	IF X < 7 THEN X := 7 ELSIF X > DW - 8 THEN X := DW - 8 END
	  	ELSE
		  	IF X < CL + 7 THEN X := CL + 7 ELSIF X > CL + DW - 8 THEN X := CL + DW - 8 END
	  	END ;
		  IF Y < 7 THEN Y := 7 ELSIF Y > DH - 8 THEN Y := DH - 8 END;
	  	Display.CopyPattern(Display.FG, Display.star, X - 7, Y - 7, 2)
  	END FlipStar;

 (** Initialize a cursor, setting it to off, and at position 0, 0. *)
	PROCEDURE OpenCursor* (VAR c: Cursor);
  	BEGIN c.on := FALSE; c.X := 0; c.Y := 0
  	END OpenCursor;

 (** Fade cursor if visible. *)
	PROCEDURE FadeCursor* (VAR c: Cursor);
  	BEGIN IF c.on THEN c.marker.Fade(c.X, c.Y); c.on := FALSE END
  	END FadeCursor;

 (** Draw cursor c using marker m at position X, Y. *)
	PROCEDURE DrawCursor* (VAR c: Cursor; VAR m: Marker; X, Y: SIGNED16);
  	BEGIN
	  	IF c.on & ((X # c.X) OR (Y # c.Y) OR (m.Draw # c.marker.Draw)) THEN
            c.marker.Fade(c.X, c.Y); c.on := FALSE
          END;
	  	IF ~c.on THEN
            m.Draw(X, Y); c.marker := m; c.X := X; c.Y := Y; c.on := TRUE
          END
  	END DrawCursor;

(*display management*)

(** Remove the caret by broadcasting a ControlMsg into the display space.
Afterwards, no visual object should own either a caret for inserting text or objects. *)
    PROCEDURE Defocus*;
      VAR M: ControlMsg;
    BEGIN M.F := NIL; M.id := defocus; Display.Broadcast(M)
    END Defocus;

(** Fade the mouse and pointer cursors if located inside the screen area X, Y, W, H.
This is required before drawing inside the area X, Y, W, H. *)
    PROCEDURE RemoveMarks* (X, Y, W, H: SIGNED16);
    BEGIN
      IF (Mouse.X > X - 16) & (Mouse.X < X + W + 16) & (Mouse.Y > Y - 16) & (Mouse.Y < Y + H + 16) THEN
          FadeCursor(Mouse)
      END;
      IF (Pointer.X > X - 8) & (Pointer.X < X + W + 8) & (Pointer.Y > Y - 8) & (Pointer.Y < Y + H + 8) THEN
          FadeCursor(Pointer)
      END
    END RemoveMarks;

    PROCEDURE HandleFiller (V: Objects.Object; VAR M: Objects.ObjMsg);
    BEGIN
      WITH V: Viewers.Viewer DO
        IF M IS InputMsg THEN
          WITH M: InputMsg DO
            IF M.id = track THEN DrawCursor(Mouse, Arrow, M.X, M.Y) END
          END;
        ELSIF M IS ControlMsg THEN
           WITH M: ControlMsg DO
             IF M.id = mark THEN
               IF (M.X >= V.X) & (M.X < V.X + V.W) & (M.Y >= V.Y) & (M.Y < V.Y + V.H) THEN
                 FadeCursor(Mouse);
                 DrawCursor(Pointer, Star, M.X, M.Y)
               END
             END
           END
        ELSIF M IS Display.ControlMsg THEN
          WITH M: Display.ControlMsg DO
            IF (M.id = Display.restore) & (V.W > 0) & (V.H > 0) THEN
              RemoveMarks(V.X, V.Y, V.W, V.H);
              Display.ReplConst(FillerColor, V.X, V.Y, V.W, V.H, 0)
            END
          END
        ELSIF M IS Display.ModifyMsg THEN
          WITH M: Display.ModifyMsg DO
            IF (M.F = V) & (M.id = Display.extend) THEN
              RemoveMarks(V.X, M.Y, V.W, V.Y - M.Y);
              Display.ReplConst(FillerColor, V.X, M.Y, V.W, V.Y - M.Y, 0)
            END
          END
    ELSIF M IS Display.DisplayMsg THEN
      WITH M: Display.DisplayMsg DO
        IF (M.device = Display.screen) & ((M.F = V) OR (M.F = NIL)) THEN
          RemoveMarks(V.X, V.Y, V.W, V.H);
          Display.ReplConst(FillerColor, V.X, V.Y, V.W, V.H, 0)
        END
      END
        END
      END
    END HandleFiller;

(** Initialize a new display with user track width UW, system track width SW,
and height H. The display is appended to the display space starting at X position
Viewers.curW. Normally this procedure is only called once to configure the
default layout of the Oberon screen. *)
    PROCEDURE OpenDisplay* (UW, SW, H: SIGNED16);	(** non-portable *)
       VAR Filler: Viewers.Viewer;
    BEGIN
       Input.SetMouseLimits(0, 0, Viewers.curW + UW + SW, H);
       Display.ReplConst(FillerColor, Viewers.curW, 0, UW + SW, H, 0);
       IF UW # 0 THEN
         NEW(Filler); Filler.handle := HandleFiller;
         Viewers.InitTrack(UW, H, Filler) (*init user track*)
       END;
       IF SW # 0 THEN
         NEW(Filler); Filler.handle := HandleFiller;
         Viewers.InitTrack(SW, H, Filler) (*init system track*)
       END
    END OpenDisplay;

    PROCEDURE UpdateDisplay;
    VAR dcm: Display.ControlMsg;  cm: ControlMsg;
    BEGIN
    	cm.F := NIL;  cm.id := neutralize;  Display.Broadcast(cm);
    	FadeCursor(Mouse);  FadeCursor(Pointer);
    	dcm.F := NIL;  dcm.id := Display.suspend;  Display.Broadcast(dcm);
    	dcm.F := NIL;  dcm.id := Display.restore;  Display.Broadcast(dcm)
    END UpdateDisplay;

(** Returns the width in pixels of the display that contains the X coordinate. *)
    PROCEDURE DisplayWidth* (X: SIGNED16): SIGNED16;
    BEGIN RETURN DW
    END DisplayWidth;

(** Returns the height in pixels of the display that contains the X coordinate. *)
    PROCEDURE DisplayHeight* (X: SIGNED16): SIGNED16;
    BEGIN RETURN DH
    END DisplayHeight;

(** Open a new track of width W at X. *)
    PROCEDURE OpenTrack* (X, W: SIGNED16);
       VAR Filler: Viewers.Viewer;
    BEGIN
       NEW(Filler); Filler.handle := HandleFiller;
       Viewers.OpenTrack(X, W, Filler)
    END OpenTrack;

(** Get left margin of user track on display X. *)
    PROCEDURE UserTrack* (X: SIGNED16): SIGNED16;
    BEGIN RETURN X DIV DW * DW
    END UserTrack;

(** Get left margin of the system track on display X. *)
    PROCEDURE SystemTrack* (X: SIGNED16): SIGNED16;
    BEGIN RETURN X DIV DW * DW + DW DIV 8 * 5
    END SystemTrack;

    PROCEDURE UY (X: SIGNED16): SIGNED16;
      VAR fil, bot, alt, max: Display.Frame;
    BEGIN
      Viewers.Locate(X, 0, fil, bot, alt, max);
      IF fil.H >= DH DIV 8 THEN RETURN DH END;
      RETURN max.Y + max.H DIV 2
    END UY;

(** Allocate a new user viewer within the display located at DX. (X, Y)
returns the suggested position. *)
    PROCEDURE AllocateUserViewer* (DX: SIGNED16; VAR X, Y: SIGNED16);
    BEGIN
      IF Pointer.on THEN X := Pointer.X; Y := Pointer.Y
        ELSE X := DX DIV DW * DW; Y := UY(X)
      END
    END AllocateUserViewer;

    PROCEDURE SY (X: SIGNED16): SIGNED16;
      VAR fil, bot, alt, max: Display.Frame;
    BEGIN
      Viewers.Locate(X, DH, fil, bot, alt, max);
      IF fil.H >= DH DIV 8 THEN RETURN DH END;
      IF max.H >= DH - H0 THEN RETURN max.Y + H3 END;
      IF max.H >= H3 - H0 THEN RETURN max.Y + H2 END;
      IF max.H >= H2 - H0 THEN RETURN max.Y + H1 END;
      IF max # bot THEN RETURN max.Y + max.H DIV 2 END;
      IF bot.H >= H1 THEN RETURN bot.H DIV 2 END;
      RETURN alt.Y + alt.H DIV 2
    END SY;

(** Allocate a new system viewer within the display located at DX.
(X, Y) returns the suggested position. *)
    PROCEDURE AllocateSystemViewer* (DX: SIGNED16; VAR X, Y: SIGNED16);
    BEGIN
      IF Pointer.on THEN X := Pointer.X; Y := Pointer.Y
        ELSE X := DX DIV DW * DW + DW DIV 8 * 5; Y := SY(X)
      END
    END AllocateSystemViewer;

(** Returns the star-marked viewer. *)
    PROCEDURE MarkedViewer* (): Viewers.Viewer;
    BEGIN RETURN Viewers.This(Pointer.X, Pointer.Y)
    END MarkedViewer;

(** Returns the star-marked frame. *)
PROCEDURE MarkedFrame*(): Display.Frame;
	VAR L: Display.LocateMsg;
BEGIN
	L.loc := NIL; L.X := Pointer.X; L.Y := Pointer.Y; L.F := NIL;
	Display.Broadcast(L);
	RETURN L.loc
END MarkedFrame;

(** Returns the text of the star-marked frame. *)
PROCEDURE MarkedText*(): Texts.Text;
	VAR
		F, V: Display.Frame;
		L: Objects.LinkMsg;
		T: Texts.Text;
BEGIN
	T := NIL; F := MarkedFrame();
	IF F = NIL THEN
		V := MarkedViewer();
		IF (V # NIL) & (V.dsc # NIL) THEN
			F := V.dsc.next
		END
	END;
	IF F # NIL THEN
		L.id := Objects.get; L.name := "Model"; L.obj := NIL; L.res := -1;
		F.handle(F, L);
		IF (L.obj # NIL) & (L.obj IS Texts.Text) THEN
			T := L.obj(Texts.Text)
		END
	END;
	RETURN T
END MarkedText;

  (*command interpretation*)

(** Execute an Oberon command. Name should be a string of the form
"M.P", where M is the module and P is the procedure of the command.
Par is the command parameter record; it will be assigned to Oberon.Par
so that the command can pick up its parameters. The new flag indicates
if the module M should be reloaded from disk (obly possible if M is a "top"
module, i.e. it has no clients. Res indicates success (res = 0) or failure (res # 0).
Modules.resMsg contains an explanation of what went wrong when res # 0. *)
    PROCEDURE Call* (name: ARRAY OF CHAR; par: ParList; new: BOOLEAN; VAR res: SIGNED16);
      VAR Mod: Modules.Module; P: Modules.Command; i, j: SIGNED32;
    BEGIN res := 1;
      i := 0; j := 0;
      WHILE name[j] # 0X DO
        IF name[j] = "." THEN i := j END;
        INC(j)
      END;
      IF i = 0 THEN i := j; name[j+1] := 0X END;
      name[i] := 0X;
      IF new THEN
      	Modules.Free(name, FALSE);
      	IF (Modules.res = 0) OR (Modules.res = 6) THEN Mod := Modules.ThisMod(name) END
  	ELSE
  		Mod := Modules.ThisMod(name)
      END;
      IF Modules.res = 0 THEN
        INC(i); j := i;
        WHILE name[j] # 0X DO name[j - i] := name[j]; INC(j) END;
        name[j - i] := 0X;
        P := Modules.ThisCommand(Mod, name);
        IF Modules.res = 0 THEN
          Par := par;
          IF par.frame # NIL THEN
          	Par.vwr := Viewers.This(par.frame.X, par.frame.Y)
          END;
          P; res := 0;
        ELSE res := Modules.res
        END
      ELSE res := Modules.res
      END
    END Call;

(** Returns the selected stretch [beg, end[ of the current selected text T.
Time indicates the time of selection; time = -1 indicates that no text is currently selected. *)
    PROCEDURE GetSelection* (VAR text: Texts.Text; VAR beg, end, time: SIGNED32);
      VAR M: SelectMsg;
    BEGIN
        M.F := NIL; M.id := get; M.time := -1; M.text := NIL; Display.Broadcast(M);
        text := M.text; beg := M.beg; end := M.end; time := M.time
    END GetSelection;

    PROCEDURE GC (me: Task);
    BEGIN
      me.time := Input.Time() + GCInterval;
      IF fido # NIL THEN fido.Reset END;
      Kernel.GC
    END GC;

(** Install a background task. The background task is periodically activated
by calling its handler when the system has nothing else to do. *)
    PROCEDURE Install* (T: Task);
      VAR t: Task;
    BEGIN t := NextTask;
      WHILE (t.next # NextTask) & (t.next # T) DO t := t.next END;
      IF t.next # T THEN T.next := t.next; t.next := T END
    END Install;

(** Remove a background task. *)
    PROCEDURE Remove* (T: Task);
      VAR t: Task;
    BEGIN t := NextTask;
      WHILE (t.next # NextTask) & (t.next # T) DO t := t.next END;
      IF t.next = T THEN t.next := t.next.next;
        IF NextTask = T THEN NextTask := NextTask.next END
      END
    END Remove;

(** Request a garbage collection to be done. The GC will take place immediately. *)
    PROCEDURE Collect*;
    BEGIN Kernel.GC	(* independent of GC task *)
    END Collect;

(** Set the default font used when typing characters. *)
    PROCEDURE SetFont* (fnt: Fonts.Font);
    BEGIN
    	CurFnt := fnt;
		IF CurFnt = NIL THEN CurFnt := Fonts.Default END
    END SetFont;

(** Set the color of typed characters. *)
    PROCEDURE SetColor* (col: SIGNED8);
    BEGIN CurCol := col
    END SetColor;

(** Set the vertical offset of typed characters. *)
    PROCEDURE SetOffset* (voff: SIGNED8);
    BEGIN CurOff := voff
    END SetOffset;

  (* Configuration =  Group.
    Group = { Entry }.
    Entry = [ Name "=" ] Value.
    Value = Token | "{" Group "}".
    Token = any token from Texts.Scanner, where "{" and "}" must occur pairwise.
    A named group is refered to as a "section". *)

  PROCEDURE SkipGroup (VAR S: Texts.Scanner);
    VAR openBraces: SIGNED16;
  BEGIN openBraces := 1;
    REPEAT Texts.Scan(S);
      IF S.class = Texts.Char THEN
        IF S.c = "{" THEN INC(openBraces) ELSIF S.c = "}" THEN DEC(openBraces) END
      END
    UNTIL S.eot OR (openBraces = 0)
  END SkipGroup;

(** Open a scanner at a specific section of the Oberon Text.  Scans the first symbol in the section.  Returns
	S.class = Texts.Inval on error. *)

  PROCEDURE OpenScanner* (VAR S: Texts.Scanner; name: ARRAY OF CHAR);
    VAR i, j: SIGNED16; done, eos: BOOLEAN; part: ARRAY 32 OF CHAR;
    	f: Files.File;  t, d: SIGNED32;
  BEGIN
    f := Files.Old(OberonText);
    IF f = NIL THEN t := 0; d := 0 ELSE Files.GetDate(f, t, d) END;
	IF (t # conftime) OR (d # confdate) THEN
		conftime := t;  confdate := d;
		Texts.Open(conftext, OberonText)	(* possibly load other modules, because of Objects in text *)
    END;
    Texts.OpenScanner(S, conftext, 0); Texts.Scan(S); done := TRUE;
    WHILE (name[0] # 0X) & ~S.eot & done DO
      (* extract name part *) i := 0;
      WHILE (name[i] # 0X) & (name[i] # ".") DO part[i] := name[i]; INC(i) END;
      part[i] := 0X;
      IF name[i] = "." THEN INC(i) END;
      j := 0;
      WHILE name[i] # 0X DO name[j] := name[i]; INC(i); INC(j) END;
      name[j] := 0X;
      done := FALSE; eos := FALSE;
      REPEAT
        IF (S.class = Texts.Name) THEN Texts.Scan(S);
          IF ~S.eot THEN
            IF (S.class = Texts.Char) & (S.c = "=") THEN (* named entry *)
              IF S.s = part THEN Texts.Scan(S);
                IF ~S.eot & (S.class = Texts.Char) & (S.c = "{") THEN Texts.Scan(S) END;
                done := TRUE
              ELSE Texts.Scan(S);
                IF ~S.eot & (S.class = Texts.Char) & (S.c = "{") THEN SkipGroup(S) END;
                IF ~S.eot THEN Texts.Scan(S) ELSE eos := TRUE END
              END
            ELSE eos := TRUE
            END
          ELSE eos := TRUE
          END
        ELSIF (S.class = Texts.Char) & (S.c = "{") THEN (* unnamed entry *) SkipGroup(S);
          IF ~S.eot THEN Texts.Scan(S) ELSE eos := TRUE END
        ELSE eos := TRUE
        END
      UNTIL done OR eos
    END;
    IF ~done OR (conftext.len = 0) THEN S.class := Texts.Inval END
  END OpenScanner;

	PROCEDURE ResetPalette;
	VAR F: Files.File; R: Files.Rider; i, cols: SIGNED16; r, g, b: CHAR;
	BEGIN
		IF Display.Depth(0) >= 8 THEN cols := 256 ELSE cols := 16 END;
		F := Files.Old("Default.Pal");
		IF F # NIL THEN
			Files.Set(R, F, 0);
			FOR  i := 0 TO cols-1 DO
				Files.Read(R, r); Files.Read(R, g); Files.Read(R, b);
				Display.SetColor(i, ORD(r), ORD(g), ORD(b))
			END
		ELSE
			FOR i := 0 TO cols-1 DO Display.SetColor(i, 255, 255, 255) END;
			Display.SetColor(Display.FG, 0, 0, 0)
		END;
		ScreenOn := TRUE;
		IF Display.TrueColor(0) THEN UpdateDisplay END
	END ResetPalette;

    PROCEDURE Reboot;
    VAR cmd: Modules.Command;  m: Modules.Module;
	BEGIN
		m := Modules.ThisMod("System");
		IF m # NIL THEN
			cmd := Modules.ThisCommand(m, "Reboot");
			IF cmd # NIL THEN cmd END
		END
    END Reboot;

	PROCEDURE SwitchToWM;
	VAR res: INTEGER; s: ARRAY 256 OF CHAR;
	BEGIN
		OpenTrack(0, Display.Width);	(* inhibit display updates *)
		s := "";	(* remove default Oberon input device and install virtual display and input devices *)
		AosFS.AppendStr("OberonDisplay.Remove;EXPOberonDisplay.Install Oberon ", s);
		AosFS.AppendInt(Display.Width, s);
		AosFS.AppendStr("x", s);
		AosFS.AppendInt(Display.Height, s);
		Commands.Call(s, {Commands.Wait}, res, s);
		IF res = 0 THEN
			Display.SetMode(0BEH, {});	(* re-initialize display *)
			Input.Init(0BEH)	(* re-init input *)
		ELSE
			KernelLog.Enter; KernelLog.String(s); KernelLog.Exit
		END;
		Viewers.CloseTrack(0)
	END SwitchToWM;

(** Main Oberon task dispatcher. Reads the mouse position and characters
typed, informing the viewer of the display space of events using the
Display.InputMsg. The loop broadcasts a ControlMsg (id = mark) when the
marker is set. Pressing the neutralise key results in a ControlMsg (id = neutralize)
to be broadcast. All frames receiving the neutralize message should remove
selections and the caret. The Loop periodically activates background tasks and
the garbage collector, if no mouse or keyboard events are arriving. *)
   PROCEDURE Loop*;
      VAR V: Viewers.Viewer; M: InputMsg; N: ControlMsg;
       X, Y: SIGNED16; keys, shift, oldshift: SET; ch: CHAR;
       mint, cur, t: SIGNED32;  task, min: Task;
    BEGIN
      Kernel.LockOberon;
      IF (CurTask # NIL) & ~CurTask.safe THEN Remove(CurTask) END;
      Input.Mouse(keys, X, Y); oldshift := {};
      LOOP
        IF Input.Available() > 0 THEN Input.Read(ch);
          IF ch = Neutralise THEN
            N.F := NIL; N.id := neutralize; Display.Broadcast(N);
            FadeCursor(Mouse); FadeCursor(Pointer)
          ELSIF ch = SETUP THEN
            N.F := NIL; N.id := mark; N.X := X; N.Y := Y; Display.Broadcast(N)
          ELSIF ch = 0F7X THEN ResetPalette
          ELSIF ch = 0F8X THEN New := ~New; UpdateDisplay
          ELSIF ch = 0F9X THEN UpdateDisplay
          ELSIF ch = 0FEX THEN SwitchToWM
          ELSIF ch = 0FFX THEN Reboot
          ELSE
            M.F := NIL; M.id := consume; M.ch := ch; M.fnt := CurFnt; M.col := CurCol; M.voff := CurOff;
            Display.Broadcast(M);
            DEC(GCTask.time, ActVal)
          END;
          Input.Mouse(keys, X, Y)
        ELSIF keys # {} THEN M.F := NIL; M.id := track;
          REPEAT


    	   IF 31 IN keys THEN (*fof*)
                	 M.ch := 0C1X;
			ELSIF 30 IN keys THEN
				keys := keys - {30}+{31};
				 M.ch := 0C2X;
			ELSE M.ch := 0X;
			END;
             M.keys := keys; M.X := X; M.Y := Y;
            M.dlink := NIL; M.x := 0; M.y := 0;
            M.res := MIN(SIGNED16); Objects.Stamp(M);

            V := Viewers.This(M.X, M.Y); V.handle(V, M);

           (*
             IF M.res # 0 THEN (*fof*)
                M.F := NIL; M.id := consume;
				M.fnt := CurFnt; M.col := CurCol; M.voff := CurOff;
				IF M.ch # 0X THEN Display.Broadcast(M) END
			END;
			*)

            Input.Mouse(keys, X, Y);

          UNTIL (keys = {}) OR (Input.Available() # 0);
          DEC(GCTask.time, ActVal)
        ELSE (*keys = {}*)
          M.F := NIL; M.id := track; M.keys := keys; M.X := X; M.Y := Y;
          M.dlink := NIL; M.x := 0; M.y := 0;
          M.res := MIN(SIGNED16); Objects.Stamp(M);
          V := Viewers.This(X, Y); V.handle(V, M);
          Input.Mouse(keys, X, Y);
          LOOP
            Input.KeyState(shift);
            IF (keys # {}) OR (X # M.X) OR (Y # M.Y) OR (Input.Available() # 0) OR (shift # oldshift) THEN EXIT END;
            (*Kernel.Idle(0);*)
          (* find first expired task, or task that will expire soonest *)
            cur := Input.Time();
            task := NextTask;  min := NIL;  mint := MAX(SIGNED32);
            LOOP
            	t := task.time-cur;	(* time left *)
            	IF t <= 0 THEN	(* found expired task *)
            		NextTask := task; min := NIL; EXIT
            	ELSIF t < mint THEN	(* found new minimum *)
            		mint := t; min := task
            	END;
            	task := task.next;
            	IF task = NextTask THEN EXIT END	(* searched through all tasks *)
            END;
            IF min # NIL THEN
            	NextTask := min; Input.Await(mint)
            END;
            CurTask := NextTask; NextTask := CurTask.next;
            IF CurTask.time - Input.Time() <= 0 THEN
            	Display.ResetClip; CurTask.handle(CurTask)
            END;
            CurTask := NIL;
            Kernel.UnlockOberon;	(* give another object a chance to enter Oberon *)
            Kernel.LockOberon;
            Input.Mouse(keys, X, Y);
            IF ~Mouse.on THEN EXIT END	(* a task or handler switched off the mouse *)
          END;
          oldshift := shift
        END
      END
    END Loop;

	PROCEDURE Init;
	VAR s: ARRAY 8 OF CHAR;
	BEGIN
		Kernel.GetConfig("Oberon", OberonText);
		IF OberonText = "" THEN COPY ("Oberon.Text", OberonText) END;
		Kernel.GetConfig("Color", s);
		IF s[0] # "0" THEN FillerColor := 12 ELSE FillerColor := 0 END;
		Kernel.GetConfig("MB", s);
		New := (s # "3");
		Kernel.GetConfig("OberonWatch", s);
        IF s = "1" THEN NEW(fido, "Oberon", 2*GCInterval) ELSE fido := NIL END
	END Init;

BEGIN
  Init;
  OptionChar := "\"; OpenText := NIL; CurTask := NIL;
  Arrow.Fade := FlipArrow; Arrow.Draw := FlipArrow;
  Star.Fade := FlipStar; Star.Draw := FlipStar;
  OpenCursor(Mouse); OpenCursor(Pointer);

  DW := Display.Width; DH := Display.Height; CL := Display.ColLeft;
  H3 := DH - DH DIV 3;
  H2 := H3 - H3 DIV 2;
  H1 := DH DIV 5;
  H0 := DH DIV 10;

  ScreenOn := TRUE; ResetPalette;
  W0 := DW DIV 8 * 5;
  IF W0 < 400 THEN W0 := 0 END;
  OpenDisplay(W0, DW - W0, DH);
  Display.SetMode(0, {});

  NEW(GCTask);
  GCTask.handle := GC;
  GCTask.safe := TRUE;
  NextTask := GCTask;
  NextTask.next := NextTask;
  Collect;
  Fonts.Default := Fonts.This("Oberon10.Scn.Fnt");
  CurFnt := Fonts.Default;
  CurCol := Display.FG;
  CurOff := 0;

  conftime := -1; confdate := -1; NEW(conftext)
END Oberon.

(** Remarks:

1. Command execution
Execution of commands is the task of modules Module. Oberon.Call provides an
abstraction for this mechanism and also a way to pass parameters in the form of
a text to the executed command. After command execution, the global variable
Oberon.Par is a pointer to a parameter record specifying a parameter text, a
position in that text, and details what objects are involved in the commands.
The vwr field of the ParRec points to the viewer in which the command was executed.
The frame field of the ParRec points to the direct child of the vwr (the menu or the
main frame) from which the command was executed. This semantics is compatible
with older Oberon applications and is seldomly used today. The obj field of the
ParRec points to the object (normally a frame) that executed the command.
The Oberon.Par pointer is initialized before command execution to the parameter
record passed to Oberon.Call.

2. Cursors and Markers
Markers are a way to draw and undraw a shape on the display. Typically, draw
and undraw can be realized by an invert display operation. Cursors keep track of
the current position and state (visible or not) of a marker. The Mouse cursor is the
standard mouse arrow, and the Pointer cursor is the star marker placed with the
Setup key. Repeatedly calling Oberon.DrawCursor with different coordinates move a
cursor (and marker) across the display. Before drawing in a certain area of the
display, cursors should be removed with Oberon.RemoveMarks or Oberon.FadeCursor
(failingly to do so may result in the cursor leaving garbage on the display when
drawing operations are performed in its vicinity). Note that on some Oberon host
platforms (Windows, Mac, Unix) the mouse cursor is under control of the host
windowing system, and is automatically faded when required. It is recommended
to fade the cursor on these platforms anyway, as your Oberon programs will then
also work on native Oberon systems.

3. The InputMsg
The InputMsg informs the frames of the display space of the current mouse position
and character typed. It is repeatedly broadcast into the display space by the
Oberon.Loop for each input event. An InputMsg id of Oberon.consume indicates a
key was pressed. The ASCII keycode is contained in the ch field of the message
(check the description of module Input for special keycodes). The fields fnt, col and
voff give information about the requested font, color (index), and verticall offset
(in pixels). These values are copied from hidden variables in the Oberon module,
which are set with the procedures SetFont, SetColor, and SetOffset. Note that the
TextGadgets ignore these fields when typing. Instead the font, color and vertical
offset of the character immediately before the caret is used (thus the fields have
fallen out of use). A frame should only process the consume message if it has the
caret set. Afterwards the message should be invalidated by setting the message res
field to 0 or a positive value. This prevents the character being consumed by other
frames in the display space and also terminates the message broadcast.
 An InputMsg id of track indicates a mouse event. The display space normally only
 forwards this message to the frame located at position X, Y on the display. Field X, Y
 indicates the absolute mouse position (cursor hotspot) and keys the mouse button
 state (which mouse buttons are pressed). The mouse buttons are numbered 0, 1, 2
 for right, middle, and left respectively. It is typical for a frame receiving a track
 message with keys # {} to temporarily taking control of the mouse by polling (using
 module Input). As soon as all mouse buttons are released, control must be passed
 back to the Oberon loop. A frame should invalidate the track message if it took
 action on a mouse event; otherwise the enclosing frame might think that the message
 could not be handled. In some cases a child frame takes no action on an event even
 though a mouse buttton is pressed and the mouse is located inside the frame. This is
 an indication that the child frame cannot or is unwilling to process the event, and
 the parent (and forwarder of the message in the display space) should take a default
 action. Note that during a tracking operation, no background tasks can be serviced.

4. The ControlMsg
The control message manages display space wide events like removing the (one and
only) caret, pressing Neutralise (for removing the caret and the selections), and setting the
star marker with the Setup key. The id field of the control message is set to defocus,
neutralize, and mark respectively. Note that the mark variant need not be handled by
own frames; it is already processed by the Viewers. Messages of this type must never
be invalidated during their travels through the display space.

5. The CaretMsg
The CaretMsg controls the removing (id = reset), retrieving (id = get) and setting
(id = set) of the caret on a frame to frame basis. All text editor-like frames should
respond to this message. The car field of the message defines the editor frame involved
for reset and set, and returns the editor frame that has the caret for get. The text field
specifies which text is meant (or which text is returned for get). In the reset and set
cases this field is mostly redundant but is checked for correctness ANYWAY. The pos
field must be valid position in the text. The CaretMsg is always broadcast.

6. The SelectMsg
In a similar way as the CaretMsg, the SelectMsg controls the removing (id = reset),
retrieving (id = get) and setting (id = set) of the selection. In this case, the sel field
indicates the destination frame or returned frame, in a similar manner as the car
field of the CaretMsg. The SelectMsg is extended with fields for specifying/retrieving
the selection time, starting and ending position. The SelectMsg is always broadcast.

7. Background tasks
The handle procedure variable of installed background tasks are periodically called
by the Oberon loop when the Oberon system is idle (no mouse or keyboard events).
The task handlers have to be programmed in an inverted manner and should return
as quickly as possible to the loop, otherwise the user will notice delays (typically
when elapsed time is greater than 100-200ms). As tasks are activated periodically,
a badly written task can cause a cascade of traps, one for each invocation. By default,
the loop removes such a task that does not return from the task list (the safe flag
prevents the loop from such an action). The garbage collector is realized as a task.
A task can request to be invoked only at a specified time by setting the time field in
the task descriptor. The time is measured according to Oberon.Time() at tick frequency
specified by Input.TimeUnit. After each handler invocation, the task is expected to
advance the time field to the next earliest event, overwise it will never be invoked in
future. It is highly recommended to use this feature by specifying for tasks that are
only invoked every few ms. This will save network traffic when using Oberon in an
X-Window environment.

8. The Oberon Loop
The Oberon loop is called when the Oberon system starts, and never returns until
the Oberon system is left. After a trap occurs, the run-time stack is reset, and the
Oberon loop is started afresh. The Oberon loop polls the mouse and keyboard for
events that it broadcasts to the display space using messages. When no events are
happening, background tasks are activated periodically in a round-robin fashion.

9. Oberon time format:
	time = hour*4096 + minute*64 + second
	date = (year-1900)*512 + month*32 + day*32

	hour = time DIV 4096 MOD 32
	minute = time DIV 64 MOD 64
	second = time MOD 64

	year = 1900+date DIV 512
	month = date DIV 32 MOD 16
	day = date MOD 32
*)
