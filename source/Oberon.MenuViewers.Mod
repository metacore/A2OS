(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE MenuViewers IN Oberon;	(** portable *) (*JG 16.10.94, color version *)

  IMPORT Input, Objects, Display, Viewers, Oberon;

  CONST
    FullColor = 15;
    minint = MIN(SIGNED16);
    replace = Display.replace; invert = Display.invert;
    extend = Display.extend; reduce = Display.reduce;

	Modern = FALSE;
	AvoidLostViewer = FALSE;

  TYPE
    Viewer* = POINTER TO ViewerDesc;

    ViewerDesc* = RECORD
      (Viewers.ViewerDesc)
      menuH*: SIGNED16
    END;

  VAR
    LightFrame, DarkFrame: SIGNED16;

  PROCEDURE Copy (V: Viewer; VAR V1: Viewer);
    VAR Menu, Main: Display.Frame; M: Objects.CopyMsg;
  BEGIN
    Menu := V.dsc; Main := V.dsc.next;
    NEW(V1); V1^ := V^; V1.state := 0;
    M.id := Objects.shallow; Objects.Stamp(M);
    Menu.handle(Menu, M); V1.dsc := M.obj(Display.Frame);
    Main.handle(Main, M); V1.dsc.next := M.obj(Display.Frame)
  END Copy;

  PROCEDURE Draw (V: Viewers.Viewer);
  BEGIN
    Display.ReplConst(LightFrame, V.X, V.Y, 1, V.H, replace);
    Display.ReplConst(LightFrame, V.X + 1, V.Y + V.H - 1, V.W - 1, 1, replace);
    Display.ReplConst(DarkFrame, V.X + 1, V.Y, V.W - 2, 1, replace);
    Display.ReplConst(DarkFrame, V.X + V.W - 1, V.Y, 1, V.H - 1, replace)
  END Draw;

  PROCEDURE Extend (V: Viewer; newY, newH: SIGNED16);
    VAR dH: SIGNED16;
  BEGIN dH := V.Y - newY;
    IF dH > 0 THEN
      Display.ReplConst(LightFrame, V.X, newY, 1, dH, replace);
      Display.ReplConst(DarkFrame, V.X + V.W - 1, newY, 1, dH, replace);
      Display.ReplConst(DarkFrame, V.X + 1, newY, V.W - 2, 1, replace);
      IF Modern THEN Display.ReplConst(LightFrame, V.X + 1, newY + newH - 1, V.W - 1, 1, replace) END
    END
  END Extend;

  PROCEDURE Reduce (V: Viewer; newY: SIGNED16);
  BEGIN
    Display.ReplConst(DarkFrame, V.X + 1, newY, V.W - 2, 1, replace)
  END Reduce;

  PROCEDURE Grow (V: Viewer; oldH: SIGNED16);
    VAR dH: SIGNED16;
  BEGIN dH := V.H - oldH;
    IF dH > 0 THEN
      Display.ReplConst(LightFrame, V.X, V.Y + oldH, 1, dH, replace);
      Display.ReplConst(LightFrame, V.X + 1, V.Y + V.H - 1, V.W - 2, 1, replace);
      Display.ReplConst(DarkFrame, V.X + V.W - 1, V.Y + oldH, 1, dH, replace)
    END
  END Grow;

  PROCEDURE Shrink (V: Viewer; newH: SIGNED16);
  BEGIN
    Display.ReplConst(LightFrame, V.X + 1, V.Y + newH - 1, V.W - 2, 1, replace)
  END Shrink;

  PROCEDURE ModifyFrame (F: Display.Frame; id, dY, Y, H: SIGNED16);
    VAR M: Display.ModifyMsg;
  BEGIN
    M.F := F; M.id := id; M.mode := Display.display; M.dlink := NIL;
    M.X := F.X; M.Y := Y; M.W := F.W; M.H := H;
    M.dX := 0; M.dY := dY; M.dW := 0; M.dH := M.H - F.H;
    M.res := minint; M.x := 0; M.y := 0; Objects.Stamp(M);
    F.handle(F, M); F.Y := Y; F.H := H
  END ModifyFrame;

  PROCEDURE Restore (V: Viewer);
    VAR Menu, Main: Display.Frame; M: Display.ControlMsg;
  BEGIN
    Menu := V.dsc; Main := V.dsc.next;
    Oberon.RemoveMarks(V.X, V.Y, V.W, V.H);
    Draw(V);
    Menu.X := V.X + 1; Menu.Y := V.Y + V.H - 1; Menu.W := V.W - 2; Menu.H := 0;
    Main.X := V.X + 1; Main.Y := V.Y + V.H - V.menuH; Main.W := V.W - 2; Main.H := 0;
    M.F := NIL; M.id := Display.restore; M.res := -1; Objects.Stamp(M); M.dlink := NIL;
    M.x := 0; M.y := 0;
    Menu.handle(Menu, M); Main.handle(Main, M);
    IF V.H > V.menuH + 1 THEN
      IF Modern THEN
        ModifyFrame(Menu, extend, 0, V.Y + V.H - V.menuH + 1, V.menuH - 2);
        Display.ReplConst(DarkFrame, V.X + 1, V.Y + V.H - V.menuH, V.W - 2, 1, replace)
      ELSE
        ModifyFrame(Menu, extend, 0, V.Y + V.H - V.menuH, V.menuH - 1)
      END;
      ModifyFrame(Main, extend, 0, V.Y + 1, V.H - V.menuH - 1)
    ELSE ModifyFrame(Menu, extend, 0, V.Y + 1, V.H - 2)
    END
  END Restore;

  PROCEDURE ModifyViewer (V: Viewer; id, Y, H: SIGNED16);
    VAR Menu, Main: Display.Frame;
  BEGIN
    Menu := V.dsc; Main := V.dsc.next;
    IF id = extend THEN
      Oberon.RemoveMarks(V.X, Y, V.W, V.Y - Y);
      Extend(V, Y, H);
      IF H > V.menuH + 1 THEN
        IF Modern THEN
          ModifyFrame(Menu, extend, 0, Y + H - V.menuH + 1, V.menuH - 2);
          Display.ReplConst(DarkFrame, V.X + 1, Y + H - V.menuH, V.W - 2, 1, replace)
        ELSE
          ModifyFrame(Menu, extend, 0, Y + H - V.menuH, V.menuH - 1);
        END;
        ModifyFrame(Main, extend, 0, Y + 1, H - V.menuH - 1)
      ELSE ModifyFrame(Menu, extend, 0, Y + 1, H - 2)
      END
    ELSIF id = reduce THEN
      Oberon.RemoveMarks(V.X, Y, V.W, Y - V.Y);
      IF H > V.menuH + 1 THEN
        ModifyFrame(Main, reduce, 0, Y + 1, H - V.menuH - 1);
        IF Modern THEN
          ModifyFrame(Menu, reduce, 0, Y + H - V.menuH + 1, V.menuH - 2);
          Display.ReplConst(DarkFrame, V.X + 1, Y + H - V.menuH, V.W - 2, 1, replace)
        ELSE
          ModifyFrame(Menu, reduce, 0, Y + H - V.menuH, V.menuH - 1)
        END
      ELSE
        ModifyFrame(Main, reduce, 0, Y + H - V.menuH, 0);
        ModifyFrame(Menu, reduce, 0, Y + 1, H - 2)
      END;
      Reduce(V, Y)
    END
  END ModifyViewer;

  PROCEDURE Change (V: Viewer; X, Y: SIGNED16; Keys: SET);
    VAR Menu, Main: Display.Frame;
      V1: Viewers.Viewer; keysum: SET; Y0, dY, H: SIGNED16;
  BEGIN (*Keys # {}*)
    Menu := V.dsc; Main := V.dsc.next;
    Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, X, Y);
    Oberon.RemoveMarks(V.X + 1, V.Y + V.H - 1 - Menu.H, V.W - 2, Menu.H);
    Display.ReplConst(FullColor, V.X + 1, V.Y + V.H - 1 - Menu.H, V.W - 2, Menu.H, invert);
    Y0 := Y;
    keysum := Keys;
    LOOP
      Input.Mouse(Keys, X, Y);
      IF Keys = {} THEN EXIT END;
      keysum := keysum + Keys;
      Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, X, Y)
    END;
    Oberon.RemoveMarks(V.X + 1, V.Y + V.H - 1 - Menu.H, V.W - 2, Menu.H);
    Display.ReplConst(FullColor, V.X + 1, V.Y + V.H - 1 - Menu.H, V.W - 2, Menu.H, invert);
    IF ~(0 IN keysum) OR Oberon.New THEN
      IF (1 IN keysum) OR (Oberon.New & (0 IN keysum)) THEN V1 := Viewers.This(X, Y);
        IF (V1 IS Viewer) & (Y > V1.Y + V1.H - V1(Viewer).menuH) THEN
          Y := V1.Y + V1.H
        END;
        Viewers.Close(V); Viewers.Open(V, X, Y); Restore(V)
      ELSE
        IF Y > Y0 THEN (*extend*) dY := Y - Y0;
          V1 := Viewers.Next(V);
          IF V1.state > 1 THEN
            IF V1 IS Viewer THEN
              IF V1.H < V1(Viewer).menuH + 1 THEN dY := 0
                ELSIF V1.H < V1(Viewer).menuH + 1 + dY THEN dY := V1.H - V1(Viewer).menuH - 1
              END
            ELSIF V1.H < 1 + dY THEN dY := V1.H - 1
            END
          ELSIF V1.H < dY THEN dY := V1.H
          END;
          Viewers.Change(V, V.Y + V.H + dY);
          Oberon.RemoveMarks(V.X, V.Y, V.W, V.H);
          Grow(V, V.H - dY);
          IF V.H > V.menuH + 1 THEN
            IF Modern THEN
              ModifyFrame(Menu, extend, dY, V.Y + V.H - V.menuH + 1, V.menuH - 1 - 1);
              Display.ReplConst(DarkFrame, V.X + 1, V.Y + V.H - V.menuH, V.W - 2, 1, replace)
            ELSE
              ModifyFrame(Menu, extend, dY, V.Y + V.H - V.menuH, V.menuH - 1)
            END;
            ModifyFrame(Main, extend, dY, V.Y + 1, V.H - V.menuH - 1)
          ELSE (*V.H > 1*)
            ModifyFrame(Menu, extend, dY, V.Y + 1, V.H - 2);
            ModifyFrame(Main, extend, dY, V.Y + V.H - V.menuH, 0)
          END
        ELSIF Y < Y0 THEN (*reduce*) dY := Y0 - Y;
          IF V.H >= V.menuH + 2 THEN
            IF V.H < V.menuH + 2 + dY THEN dY := V.H - V.menuH - 2 END;
            Oberon.RemoveMarks(V.X, V.Y, V.W, V.H);
            H := V.H - dY;
            ModifyFrame(Main, reduce, dY, V.Y + 1, H - V.menuH - 1);
            IF Modern THEN
              ModifyFrame(Menu, reduce, dY, V.Y + H - V.menuH + 1, V.menuH - 2);
              Display.ReplConst(DarkFrame, V.X + 1, V.Y + H - V.menuH, V.W - 2, 1, replace)
            ELSE
              ModifyFrame(Menu, reduce, dY, V.Y + H - V.menuH, V.menuH - 1)
            END;
            Shrink(V, H);
            Viewers.Change(V, V.Y + H)
          END
        END
      END
    END;
    IF AvoidLostViewer & (V.Y+V.H < 20) THEN
		Viewers.Change(V, 20); Restore(V)
	END
  END Change;

  PROCEDURE Suspend (V: Viewer);
    VAR Menu, Main: Display.Frame;
  BEGIN
    Menu := V.dsc; Main := V.dsc.next;
    ModifyFrame(Main, reduce, 0, V.Y + V.H - V.menuH, 0);
    ModifyFrame(Menu, reduce, 0, V.Y + V.H - 1, 0)
  END Suspend;

  PROCEDURE Handle* (V: Objects.Object; VAR M: Objects.ObjMsg);
    VAR Menu, Main: Display.Frame; V1: Viewer;
  BEGIN
    WITH V: Viewer DO
      Menu := V.dsc; Main := V.dsc.next;
      IF M IS Oberon.InputMsg THEN
        WITH M: Oberon.InputMsg DO
          IF M.id = Oberon.track THEN
            IF M.Y < V.Y + 1 THEN Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, M.X, M.Y)
            ELSIF M.Y < V.Y + V.H - V.menuH THEN Main.handle(Main, M)
            ELSIF Oberon.New & (M.X > V.X+20) THEN Menu.handle(Menu, M)
            ELSIF ~Oberon.New & (M.Y < V.Y + V.H - V.menuH DIV 4 * 3) THEN Menu.handle(Menu, M)
            ELSIF M.Y < V.Y + V.H - 1 THEN
              IF 2 IN M.keys THEN Change(V, M.X, M.Y, M.keys)
                ELSE Menu.handle(Menu, M)
              END
            ELSE Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, M.X, M.Y)
            END
          ELSE Menu.handle(Menu, M); Main.handle(Main, M)
          END
        END
      ELSIF M IS Oberon.ControlMsg THEN
        WITH M: Oberon.ControlMsg DO
          IF M.id = Oberon.mark THEN
            IF (M.X >= V.X) & (M.X < V.X + V.W) & (M.Y >= V.Y) & (M.Y < V.Y + V.H) THEN
              Oberon.DrawCursor(Oberon.Mouse, Oberon.Arrow, M.X, M.Y);
              Oberon.DrawCursor(Oberon.Pointer, Oberon.Star, M.X, M.Y)
            END
          ELSE Menu.handle(Menu, M); Main.handle(Main, M)
          END
        END
       ELSIF M IS Display.LocateMsg THEN
         WITH M: Display.LocateMsg DO
           IF M.F = NIL THEN Menu.handle(Menu, M); Main.handle(Main, M) END
         END
       ELSIF M IS Display.ModifyMsg THEN
         WITH M: Display.ModifyMsg DO
            IF M.F = V THEN ModifyViewer(V, M.id, M.Y, M.H)
            ELSE
              IF M.F # Menu THEN Menu.handle(Menu, M) END;
              IF M.F # Main THEN Main.handle(Main, M) END
            END
         END
       ELSIF M IS Objects.CopyMsg THEN
         WITH M: Objects.CopyMsg DO Copy(V(Viewer), V1); M.obj := V1 END
       ELSIF M IS Display.ControlMsg THEN
         WITH M: Display.ControlMsg DO
           IF M.id = Display.restore THEN Restore(V)
           ELSIF M.id = Display.suspend THEN Suspend(V)
           ELSE Menu.handle(Menu, M); Main.handle(Main, M)
           END
         END
        ELSIF M IS Objects.AttrMsg THEN
        	Menu.handle(Menu, M)
      ELSE Menu.handle(Menu, M); Main.handle(Main, M)
      END
    END
  END Handle;

  PROCEDURE GetName* (V: Viewer; VAR name: ARRAY OF CHAR);
    VAR M: Objects.AttrMsg;
  BEGIN
    M.id := Objects.get; M.name := "Name"; M.s := ""; M.res := minint;
    V.dsc.handle(V.dsc, M); COPY(M.s, name)
  END GetName;

  PROCEDURE New* (Menu, Main: Display.Frame; menuH, X, Y: SIGNED16): Viewer;
    VAR V: Viewer;
  BEGIN NEW(V);
    V.handle := Handle; V.dsc := Menu; V.dsc.next := Main; V.menuH := menuH;
    Viewers.Open(V, X, Y); Restore(V);
    RETURN V
  END New;

  PROCEDURE Init;
  BEGIN
    IF Display.Depth(0) # 1 THEN
    	LightFrame := 0; IF Modern THEN DarkFrame := 12 ELSE DarkFrame := 14 END
    ELSE
    	LightFrame := 15; DarkFrame := 15
    END
  END Init;

BEGIN
  Init
END MenuViewers.