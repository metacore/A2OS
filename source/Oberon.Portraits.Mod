(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Portraits IN Oberon; (*JM/ JG 26.7.94*)
IMPORT Display, Display3, Effects, Gadgets, Oberon, Objects, Skeleton;

CONST border = 4;

TYPE
  Portrait = POINTER TO PortraitDesc;
  PortraitDesc = RECORD (Gadgets.FrameDesc)
    time*: SIGNED32	(* time of selection *)
  END;

PROCEDURE SetMask (F: Display.Frame; Q: Display3.Mask);
VAR M: Display3.OverlapMsg;
BEGIN M.M := Q; M.x := 0; M.y := 0; M.F := F; M.dlink := NIL; M.res := -1;
  F.handle(F, M)
END SetMask;

PROCEDURE SetContentMask (F: Portrait);
  VAR Q: Display3.Mask;
BEGIN
  IF F.mask = NIL THEN SetMask(F.dsc, NIL)
  ELSE Display3.Copy(F.mask, Q); Q.x := 0; Q.y := 0;
    Display3.Intersect(Q, F.dsc.X, F.dsc.Y, F.dsc.W, F.dsc.H);
    Q.x := -F.dsc.X; Q.y := -(F.dsc.Y + F.dsc.H - 1); Display3.Shift(Q);
    SetMask(F.dsc, Q)
  END
END SetContentMask;

PROCEDURE ToContent (F: Portrait; x, y: SIGNED16; VAR M: Display.FrameMsg);
  VAR Mdlink, Fdlink: Objects.Object; tx, ty: SIGNED16;
BEGIN
  tx := M.x; ty := M.y;
  M.x := x; M.y := y + F.H - 1;
  Fdlink := F.dlink; Mdlink := M.dlink;
  F.dlink := M.dlink; M.dlink := F; F.dsc.handle(F.dsc, M);
  F.dlink := Fdlink; M.dlink := Mdlink;
  M.x := tx; M.y := ty
END ToContent;

PROCEDURE Modify (F: Portrait; VAR M: Display.ModifyMsg);
  VAR N: Display.ModifyMsg;
BEGIN
  N.id := Display.extend; N.F := F.dsc; N.mode := Display.state;
  N.X := border; N.Y := -M.H + 1 + border;
  N.W := M.W - 2 * border; N.H := M.H - 2 * border;
  N.dX := N.X - F.dsc.X; N.dY := N.Y - F.dsc.Y;
  N.dW := N.W - F.dsc.W; N.dH := N.H - F.dsc.H;
  N.x := 0; N.y := 0; N.res := -1; Objects.Stamp(N);
  F.dsc.handle(F.dsc, N);
  Gadgets.framehandle(F, M)
END Modify;

PROCEDURE ModifyContent (F: Portrait; VAR M: Display.ModifyMsg);
  VAR N: Display.ModifyMsg;
BEGIN
  IF M.stamp # F.stamp THEN F.stamp := M.stamp;
    N.id := Display.extend; N.F := F; N.mode := Display.display;
    N.X := F.X + M.dX; N.Y := F.Y + M.dY;
    N.W := M.W + 2 * border; N.H := M.H + 2 * border;
    N.dX := N.X - F.X; N.dY := N.Y - F.Y;
    N.dW := N.W - F.W; N.dH := N.H - F.H;
    Display.Broadcast(N)
  END
END ModifyContent;

PROCEDURE Restore (F: Portrait; Q: Display3.Mask; x, y, w, h: SIGNED16; VAR M: Display.DisplayMsg);
  VAR N: Display.DisplayMsg;

  PROCEDURE ClipAgainst (VAR x, y, w, h: SIGNED16; x1, y1, w1, h1: SIGNED16);
    VAR r, t, r1, t1: SIGNED16;
  BEGIN
    r := x + w - 1; r1 := x1 + w1 - 1; t := y + h - 1; t1 := y1 + h1 - 1;
    IF x < x1 THEN x := x1 END; IF y < y1 THEN y := y1 END;
    IF r > r1 THEN r := r1 END; IF t > t1 THEN t := t1 END;
    w := r - x + 1; h := t - y + 1;
  END ClipAgainst;

BEGIN
  Display3.Rect3D(Q, Display3.topC, Display3.bottomC, x, y, w, h, 1, Display.replace);
  Display3.Rect(Q, Display3.groupC, Display.solid, x + 1, y + 1, w - 2, h - 2, border - 2, Display.replace);
  Display3.Rect3D(Q, Display3.bottomC, Display3.topC,
    x + border - 1, y + border - 1, w - (border - 1) * 2, h - (border - 1) * 2, 1, Display.replace);
  IF M.id = Display.area THEN
    N.F := F.dsc; N.u := M.u; N.v := M.v; N.w := M.w; N.h := M.h;
    ClipAgainst(N.u, N.v, N.w, N.h, F.dsc.X, F.dsc.Y, F.dsc.W, F.dsc.H);
    DEC(N.u, border); INC(N.v, border)
  END;
  IF Gadgets.transparent IN F.dsc(Gadgets.Frame).state THEN
  	Display3.ReplConst(Q, Display3.groupC, x + border, y + border, w - 2*border, h - 2*border, Display.replace)
  END;
  N.device := M.device; N.id := M.id; N.F := F.dsc; N.dlink := M.dlink; N.res := -1;
  Objects.Stamp(N); ToContent(F, x, y, N);
  IF Gadgets.selected IN F.state THEN
    Display3.FillPattern(Q, Display3.white, Display3.selectpat, x, y, x, y, w, h,
    Display.paint)
  END
END Restore;

PROCEDURE Copy* (VAR M: Objects.CopyMsg; from, to: Portrait);
  VAR N: Objects.CopyMsg;
BEGIN
  Gadgets.CopyFrame(M, from, to);
  N.id := Objects.shallow; Objects.Stamp(N);
  from.dsc.handle(from.dsc, N); to.dsc := N.obj(Gadgets.Frame)
END Copy;

PROCEDURE Attributes (F: Portrait; VAR M: Objects.AttrMsg);
BEGIN
  IF (M.id = Objects.get) & (M.name = "Gen") THEN
    M.s := "Portraits.New"; M.class := Objects.String; M.res := 0
  ELSE Gadgets.framehandle(F, M)
  END
END Attributes;

PROCEDURE RemoveObj (obj: Display.Frame);
  VAR M: Display.ControlMsg;
BEGIN M.id := Display.remove; M.F := obj; Display.Broadcast(M)
END RemoveObj;

PROCEDURE PutObj (F: Portrait; obj: Display.Frame);
  VAR M: Display.ModifyMsg;
BEGIN
  F.dsc := obj; SetMask(F.dsc, NIL);
  M.id := Display.extend; M.mode := Display.display; M.F := F;
  M.X := F.X; M.Y := F.Y;
  M.W := F.dsc.W + border * 2; M.H := F.dsc.H + border * 2;
  M.dX := M.X - F.X; M.dY := M.Y - F.Y;
  M.dW := M.W - F.W; M.dH := M.H - F.H;
  Display.Broadcast(M)
END PutObj;

PROCEDURE TrackSelectChild (F: Portrait; VAR M: Oberon.InputMsg; child: Display.Frame);
VAR S: Display.SelectMsg; keysum: SET; C: Objects.CopyMsg;
BEGIN
	IF Gadgets.selected IN child(Gadgets.Frame).state THEN S.id := Display.reset
	ELSE S.id := Display.set
	END;
	S.F := child; S.sel := F; S.res := -1; Display.Broadcast(S);
	Gadgets.Update(child);
	keysum := {};
	REPEAT
		Effects.TrackMouse(M.keys, M.X, M.Y, Effects.Arrow); keysum := keysum + M.keys;
	UNTIL M.keys = {};
	IF (keysum = {0, 1}) & (S.id = Display.set) THEN  (* MR copy to focus *)
		Objects.Stamp(C);
		C.id := Objects.shallow; C.obj := NIL; child.handle(child, C);
		IF C.obj # NIL THEN Gadgets.Integrate(C.obj) END
	ELSE F.time := Oberon.Time()
	END;
	M.res := 0
END TrackSelectChild;

PROCEDURE Handle* (F: Objects.Object; VAR M: Objects.ObjMsg);
  VAR x, y, w, h: SIGNED16; F1: Portrait; Q: Display3.Mask; obj: Objects.Object; SM: Display.SelectMsg;
BEGIN
  WITH F: Portrait DO
    IF M IS Display.FrameMsg THEN
      WITH M: Display.FrameMsg DO
        IF (M.F = NIL) OR (M.F = F) THEN
          x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H;
          IF M IS Display.DisplayMsg THEN
            WITH M: Display.DisplayMsg DO
              IF M.device = Display.screen THEN
                IF (M.id = Display.full) OR (M.F = NIL) THEN
                  Gadgets.MakeMask(F, x, y, M.dlink, Q);
                  Restore(F, Q, x, y, w, h, M)
                ELSIF M.id = Display.area THEN
                  Gadgets.MakeMask(F, x, y, M.dlink, Q);
                  Display3.AdjustMask(Q, x + M.u, y + h - 1 + M.v, M.w, M.h);
                  Restore(F, Q, x, y, w, h, M)
                END
              ELSIF M.device = Display.printer THEN
              END
            END
          ELSIF M IS Oberon.InputMsg THEN
            WITH M: Oberon.InputMsg DO
              IF (M.id = Oberon.track) & ~(Gadgets.selected IN F.state) THEN
                IF Effects.Inside(M.X, M.Y, x + border, y + border,
                  w - 2*border, h - 2*border) THEN
                  ToContent(F, x, y, M);
                  (* If child does not respond, the container may exercise parental control
                    of mouse events. In this case, of MR key events.  *)
                  IF (M.res < 0) & (M.keys = {0}) THEN
                    TrackSelectChild(F, M, F.dsc)
                  END
                ELSE Gadgets.framehandle(F, M)
                END
              ELSE Gadgets.framehandle(F, M)
              END
            END
          ELSIF M IS Oberon.ControlMsg THEN
            WITH M: Oberon.ControlMsg DO
              ToContent(F, x, y, M);
              IF M.id = Oberon.neutralize THEN
                IF Gadgets.selected IN F.dsc(Gadgets.Frame).state THEN
                SM.id := Display.reset; SM.F := F.dsc; SM.sel := F; SM.res := -1;
                F.dsc.handle(F.dsc, SM); Gadgets.Update(F.dsc)
                END
              END
            END
          ELSIF M IS Display.ModifyMsg THEN Modify(F, M(Display.ModifyMsg))
          ELSIF M IS Display.LocateMsg THEN
            WITH M: Display.LocateMsg DO
              IF (M.loc = NIL) & Effects.Inside(M.X, M.Y, x, y, w, h) THEN
                ToContent(F, x, y, M);
                IF M.loc = NIL THEN
                  M.loc := F; M.u := M.X - x; M.v := M.Y - (y + h - 1); M.res := 0
                END
              END
            END
          ELSIF M IS Display3.OverlapMsg THEN
            WITH M: Display3.OverlapMsg DO
              F.mask := M.M; SetContentMask(F)
            END
          ELSIF M IS Display.SelectMsg THEN
            WITH M: Display.SelectMsg DO
              IF M.id = Display.get THEN
                ToContent(F, x, y, M);
                IF (F.time > M.time) & (Gadgets.selected IN F.dsc(Gadgets.Frame).state) THEN
                  M.time := F.time; M.obj := F.dsc ; M.sel := F
                END
              ELSE Gadgets.framehandle(F, M)
              END
            END
          ELSIF M.F # NIL THEN Gadgets.framehandle(F, M)
          ELSE ToContent(F, x, y, M)
          END
        ELSE (* message perhaps for content *)
          IF M IS Display3.UpdateMaskMsg THEN
            WITH M: Display3.UpdateMaskMsg DO
              IF M.F = F.dsc THEN SetContentMask(F)
              ELSE ToContent(F, M.x + F.X, M.y + F.Y, M)
              END
            END
          ELSIF M IS Display.ControlMsg THEN
            WITH M: Display.ControlMsg DO
              IF (M.id = Display.remove) & (M.F = F.dsc) THEN
                Skeleton.New; PutObj(F, Objects.NewObj(Display.Frame))
              ELSE ToContent(F, M.x + F.X, M.y + F.Y, M)
              END
            END
          ELSIF M IS Display.ModifyMsg THEN
            IF M.F = F.dsc THEN ModifyContent(F, M(Display.ModifyMsg))
            ELSE ToContent(F, M.x + F.X, M.y + F.Y, M)
            END
          ELSIF M IS Display.ConsumeMsg THEN
            WITH M: Display.ConsumeMsg DO
              IF (M.id = Display.drop) & (M.F = F.dsc) & (F.dsc IS Skeleton.Frame) THEN
                RemoveObj(M.obj(Display.Frame));
                PutObj(F, M.obj(Display.Frame));
                M.res := 0
              ELSE ToContent(F, M.x + F.X, M.y + F.Y, M)
              END
            END
          ELSE ToContent(F, M.x + F.X, M.y + F.Y, M)
          END
        END
      END
    ELSIF M IS Objects.AttrMsg THEN Attributes(F, M(Objects.AttrMsg))
    ELSIF M IS Objects.BindMsg THEN
      F.dsc.handle(F.dsc, M); Gadgets.framehandle(F, M)
    ELSIF M IS Objects.CopyMsg THEN
      WITH M: Objects.CopyMsg DO
        IF M.stamp = F.stamp THEN M.obj := F.dlink (*non-first arrival*)
        ELSE (*first arrival*)
          NEW(F1); F.stamp := M.stamp; F.dlink := F1; Copy(M, F, F1); M.obj := F1
        END
      END
    ELSIF M IS Objects.FileMsg THEN
      WITH M: Objects.FileMsg DO
        IF M.id = Objects.store THEN
          Gadgets.WriteRef(M.R, F.lib, F.dsc)
        ELSIF M.id = Objects.load THEN
          Gadgets.ReadRef(M.R, F.lib, obj);
          IF (obj # NIL) & (obj IS Gadgets.Frame) THEN F.dsc := obj(Gadgets.Frame)
          ELSE Skeleton.New; F.dsc := Objects.NewObj(Gadgets.Frame)
          END
        END;
        Gadgets.framehandle(F, M)
      END
    ELSE Gadgets.framehandle(F, M)
    END
  END
END Handle;

PROCEDURE New*;
  VAR F: Portrait;
BEGIN
  NEW(F); F.handle := Handle; F.W := 50; F.H := 50;
  Skeleton.New; F.dsc := Objects.NewObj(Display.Frame);
  Objects.NewObj := F
END New;

END Portraits.

Gadgets.Insert Portraits.New ~
