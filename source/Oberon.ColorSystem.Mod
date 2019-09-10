(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ColorSystem IN Oberon; (*JM/ JG 10.8.94/JM 27.4.95*)

IMPORT Files, Input, Objects, Display, Texts, Oberon,
  Display3, Printer, Printer3, Strings, Gadgets, Out;

CONST middle = 1;

TYPE
  Color* = POINTER TO ColorDesc;
  ColorDesc* = RECORD (Gadgets.ObjDesc)
    col*: SIGNED16
  END;

  Frame* = POINTER TO FrameDesc;
  FrameDesc* = RECORD (Gadgets.FrameDesc)
  	col*: SIGNED16;
  END;

VAR NC, SC: SIGNED16;

  PROCEDURE HandleObj* (obj: Objects.Object; VAR M: Objects.ObjMsg);
    VAR obj1: Color; red, green, blue: SIGNED16;
  BEGIN
	WITH obj: Color DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF M.id = Objects.get THEN
					IF M.name = "Gen" THEN
                      M.class := Objects.String; COPY("ColorSystem.NewObj", M.s); M.res := 0
                    ELSIF M.name = "col" THEN M.class := Objects.Int; M.i := obj.col; M.res := 0
					ELSIF M.name = "red" THEN Display.GetColor(obj.col, red, green, blue);
                      M.class := Objects.Int; M.i := red; M.res := 0
					ELSIF M.name = "green" THEN Display.GetColor(obj.col, red, green, blue);
                      M.class := Objects.Int; M.i := green; M.res := 0
					ELSIF M.name = "blue" THEN Display.GetColor(obj.col, red, green, blue);
                      M.class := Objects.Int; M.i := blue; M.res := 0
					ELSE Gadgets.objecthandle(obj, M)
					END
				ELSIF M.id = Objects.set THEN
                    IF M.name = "col" THEN obj.col := SHORT(M.i); M.res := 0
					ELSIF M.name = "red" THEN Display.GetColor(obj.col, red, green, blue);
                      IF M.class = Objects.String THEN Strings.StrToInt(M.s, M.i) END;
                      Display.GetColor(obj.col, red, green, blue);
                      Display.SetColor(obj.col, SHORT(M.i), green, blue); M.res := 0
					ELSIF M.name = "green" THEN Display.GetColor(obj.col, red, green, blue);
                      IF M.class = Objects.String THEN Strings.StrToInt(M.s, M.i) END;
                      Display.GetColor(obj.col, red, green, blue);
                      Display.SetColor(obj.col, red, SHORT(M.i), blue); M.res := 0
					ELSIF M.name = "blue" THEN Display.GetColor(obj.col, red, green, blue);
                      IF M.class = Objects.String THEN Strings.StrToInt(M.s, M.i) END;
                      Display.GetColor(obj.col, red, green, blue);
                      Display.SetColor(obj.col, red, green, SHORT(M.i)); M.res := 0
					ELSE Gadgets.objecthandle(obj, M)
					END
				ELSIF M.id = Objects.enum THEN
					M.Enum("col"); M.Enum("red"); M.Enum("green"); M.Enum("blue");
					Gadgets.objecthandle(obj, M)
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = obj.stamp THEN M.obj := obj.dlink	(* copy msg arrives again *)
				ELSE (* first time copy message arrives *)
					NEW(obj1); obj.stamp := M.stamp; obj.dlink := obj1;
					obj1.handle := obj.handle; obj1.col := obj.col;
					M.obj := obj1
				END
			END
		ELSE Gadgets.objecthandle(obj, M)
		END
	END
END HandleObj;

PROCEDURE NewObj*;
VAR obj: Color;
BEGIN NEW(obj); obj.handle := HandleObj; obj.col := Display.FG; Objects.NewObj := obj
END NewObj;

  PROCEDURE LoadColors*;
    VAR obj: Objects.Object; M: Objects.AttrMsg;
      T: Texts.Text; S: Texts.Scanner;
      f: Files.File; R: Files.Rider;
      beg, end, time: SIGNED32;
      col: SIGNED16; red, green, blue: CHAR;
  BEGIN
    M.id := Objects.get; M.name := "Value";
    obj := Gadgets.FindObj(Gadgets.context, "PalName");
    obj.handle(obj, M);
    IF (M.id # Objects.String) OR (M.s[0] = 0X) THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN
        Texts.OpenScanner(S, T, beg); Texts.Scan(S); COPY(S.s, M.s)
      END
    END;
    f := Files.Old(M.s); Files.Set(R, f, 0);
    IF f # NIL THEN col := 0;
      REPEAT
        Files.Read(R, red); Files.Read(R, green); Files.Read(R, blue);
        Display.SetColor(col, ORD(red), ORD(green), ORD(blue));
        INC(col)
      UNTIL col = NC
    END
  END LoadColors;

  PROCEDURE StoreColors*;
    VAR obj: Objects.Object; M: Objects.AttrMsg;
      T: Texts.Text; S: Texts.Scanner;
      f: Files.File; R: Files.Rider;
      beg, end, time: SIGNED32;
      col: SIGNED16; red, green, blue: SIGNED16;
  BEGIN
    M.id := Objects.get; M.name := "Value";
    obj := Gadgets.FindObj(Gadgets.context, "PalName");
    obj.handle(obj, M);
     IF (M.class # Objects.String) OR (M.s[0] = 0X) THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN
        Texts.OpenScanner(S, T, beg); Texts.Scan(S); COPY(S.s, M.s)
      END
    END;
    IF M.s # "" THEN
      Out.String("ColorSystem.StoreColors ");
      f := Files.New(M.s); Files.Set(R, f, 0);
      IF f # NIL THEN col := 0;
        REPEAT
          Display.GetColor(col, red, green, blue);
          Files.Write(R, CHR(red));
          Files.Write(R, CHR(green));
          Files.Write(R, CHR(blue));
          INC(col)
        UNTIL col = NC
      END;
      Files.Register(f);
      Out.String(M.s); Out.Ln
    END
  END StoreColors;

PROCEDURE HandleAttributes (F: Frame; VAR M: Objects.AttrMsg);
BEGIN
  IF M.id = Objects.get THEN
    IF M.name = "Gen" THEN
      M.class := Objects.String; COPY("ColorSystem.NewFrame", M.s); M.res := 0
    ELSIF M.name = "Color" THEN
      M.class := Objects.Int; M.i := F.col; M.res := 0
    ELSIF M.name = "Cmd" THEN
      Gadgets.framehandle(F, M);
      IF M.res < 0 THEN (* no such attribute, simulate one *)
        M.class := Objects.String; M.s := ""; M.res := 0
      END
    ELSE Gadgets.framehandle(F, M)
    END
  ELSIF M.id = Objects.set THEN
    IF M.name = "Color" THEN
      IF M.class = Objects.Int THEN
        F.col := SHORT(M.i); M.res := 0
      END
    ELSE Gadgets.framehandle(F, M);
    END
  ELSIF M.id = Objects.enum THEN
    M.Enum("Color"); M.Enum("Cmd"); Gadgets.framehandle(F, M)
  END
END HandleAttributes;

PROCEDURE Restore (F: Frame; Q: Display3.Mask; x, y, w, h: SIGNED16);
  VAR model: Color; col, i, j, xcur, ycur, wfld, hfld, wmarg, hmarg: SIGNED16;
BEGIN
  model := F.obj(Color);
  Display3.ReplConst(Q, F.col, x, y, w, h, Display.replace);
  wfld := (w - (SC + 1)*2) DIV SC; wmarg := (w - SC*(wfld + 2) - 2) DIV 2;
  hfld := (h - (SC + 1)*2) DIV SC; hmarg := (h - SC*(hfld + 2) - 2) DIV 2;
  col := 0; j := 0; ycur := y + hmarg + 2;
  REPEAT i := 0; xcur := x + wmarg + 2;
    REPEAT
      Display3.ReplConst(Q, col, xcur, ycur, wfld, hfld, Display.replace); INC(col);
      INC(i); xcur := xcur + wfld + 2
    UNTIL i = SC;
    INC(j); ycur := ycur + hfld + 2
  UNTIL j = SC;
  i := model.col MOD SC; j := model.col DIV SC;
  Display3.Rect(Q, Display.FG, Display.solid,
    x + wmarg + i*(wfld + 2), y + hmarg + j*(hfld + 2), wfld + 4, hfld + 4, 2, Display.invert);
  IF Gadgets.selected IN F.state THEN
    Display3.FillPattern(Q, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint)
  END
END Restore;

PROCEDURE Print (F: Frame; VAR M: Display.DisplayMsg);
  VAR Q: Display3.Mask;

  PROCEDURE P(x: SIGNED16): SIGNED16;
  BEGIN RETURN SHORT(x * Display.Unit DIV Printer.Unit)
  END P;

BEGIN
  Gadgets.MakePrinterMask(F, M.x, M.y, M.dlink, Q);
  Printer3.ReplConst(Q, F.col, M.x, M.y, P(F.W), P(F.H), Display.replace)
END Print;

PROCEDURE Copy* (VAR M: Objects.CopyMsg; from, to: Frame);
BEGIN to.col := from.col; Gadgets.CopyFrame(M, from, to)
END Copy;

PROCEDURE SelectColor (F: Frame; VAR M: Oberon.InputMsg; Q: Display3.Mask; x, y, w, h: SIGNED16);
  VAR model: Color; keysum: SET;
    i, j, k, l, x0, y0, w0, h0, wfld, hfld, wmarg, hmarg, col, bak: SIGNED16;
BEGIN
  model := F.obj(Color); bak := model.col;
  wfld := (w - (SC + 1)*2) DIV SC; wmarg := (w - SC*(wfld + 2) - 2) DIV 2;
  hfld := (h - (SC + 1)*2) DIV SC; hmarg := (h - SC*(hfld + 2) - 2) DIV 2;
  x0 := x + wmarg; y0 := y + hmarg; w0 := wfld + 2; h0 := hfld + 2;
  keysum := M.keys;
  REPEAT
    i := (M.X - x0) DIV w0; j := (M.Y - y0) DIV h0;
    IF i < 0 THEN i := 0 ELSIF i >= SC THEN i := SC - 1 END;
    IF j < 0 THEN j := 0 ELSIF j >= SC THEN j := SC - 1 END;
    col := i + j*SC;
    IF (model.col < 0) OR (col # model.col) THEN
      Oberon.FadeCursor(Oberon.Mouse);
      IF model.col >= 0 THEN
        k := model.col MOD SC; l := model.col DIV SC;
        Display3.Rect(Q, Display.FG, Display.solid,  x0 + k*w0, y0 + l*h0, w0 + 2, h0 + 2, 2, Display.invert)
      END;
      Display3.Rect(Q, Display.FG, Display.solid, x0 + i*w0, y0 + j*h0, w0 + 2, h0 + 2, 2, Display.invert);
      model.col := col
    END;
    Oberon.DrawCursor(Oberon.Mouse, Oberon.Mouse.marker, M.X, M.Y);
    Input.Mouse(M.keys, M.X, M.Y);
    keysum := keysum + M.keys
  UNTIL M.keys = {};
  Oberon.RemoveMarks(x, y, w, h);
  IF keysum = {middle} THEN
    Gadgets.Update(model);
    Gadgets.ExecuteAttr(F, "Cmd", M.dlink, NIL, NIL)
  ELSE
    model.col := bak; Gadgets.Update(model);
    Display3.Rect(Q, Display.FG, Display.solid, x0 + i*w0, y0 + j*h0, w0 + 2, h0 + 2, 2, Display.invert);
    k := model.col MOD SC; l := model.col DIV SC;
    Display3.Rect(Q, Display.FG, Display.solid,  x0 + k*w0, y0 + l*h0, w0 + 2, h0 + 2, 2, Display.invert)
  END
END SelectColor;

PROCEDURE HandleFrame* (F: Objects.Object; VAR M: Objects.ObjMsg);
  VAR x, y, w, h: SIGNED16; F1: Frame; Q: Display3.Mask;
BEGIN
  WITH F: Frame DO
    IF M IS Display.FrameMsg THEN
      WITH M: Display.FrameMsg DO
        IF (M.F = NIL) OR (M.F = F) THEN (* message addressed to box *)
          x := M.x + F.X; y := M.y + F.Y; w := F.W; h := F.H;
          IF M IS  Display.DisplayMsg THEN
            WITH M: Display.DisplayMsg  DO
              IF M.device = Display.screen THEN
                IF (M.id = Display.full) OR (M.F = NIL) THEN
                  Gadgets.MakeMask(F, x, y, M.dlink, Q);
                  Restore(F, Q, x, y, w, h)
                ELSIF M.id = Display.area THEN
                  Gadgets.MakeMask(F, x, y, M.dlink, Q);
                  Display3.AdjustMask(Q, x + M.u, y + h - 1 + M.v, M.w, M.h);
                  Restore(F, Q, x, y, w, h)
                END
              ELSIF M.device = Display.printer THEN Print(F, M)
              END
            END
          ELSIF M IS Oberon.InputMsg THEN
            WITH M: Oberon.InputMsg DO
              IF (M.id = Oberon.track) & Gadgets.InActiveArea(F, M) & (M.keys = {middle}) THEN
                Gadgets.MakeMask(F, x, y, M.dlink, Q);
                Oberon.RemoveMarks(x, y, w, h);
                SelectColor(F, M, Q, x, y, w, h);
                M.res := 0
              ELSE Gadgets.framehandle(F, M)
              END
            END
          ELSIF M IS Oberon.ControlMsg THEN Gadgets.framehandle(F, M)
          ELSIF M IS Display.ModifyMsg THEN Gadgets.framehandle(F, M)
          ELSIF M IS Display.SelectMsg THEN Gadgets.framehandle(F, M)
          ELSIF M IS Display.ConsumeMsg THEN Gadgets.framehandle(F, M)
          ELSE Gadgets.framehandle(F, M)
          END
        END
      END
    ELSIF M IS Objects.AttrMsg THEN HandleAttributes(F, M(Objects.AttrMsg))
    ELSIF M IS Objects.FileMsg THEN
      WITH M: Objects.FileMsg DO Gadgets.framehandle(F, M) END
    ELSIF M IS Objects.CopyMsg THEN
      WITH M: Objects.CopyMsg DO
        IF M.stamp = F.stamp THEN M.obj := F.dlink (*non-first arrival*)
        ELSE (*first arrival*)
          NEW(F1); F.stamp := M.stamp; F.dlink := F1;
          Copy(M, F, F1); M.obj := F1
        END
      END
    ELSE Gadgets.framehandle(F, M)
    END
  END
END HandleFrame;

PROCEDURE NewFrame*;
VAR F: Frame;
BEGIN
  NEW(F); F.W := 50; F.H := 50; F.col := Display.FG; F.handle := HandleFrame;
  NewObj; F.obj := Objects.NewObj; Objects.NewObj := F
END NewFrame;

BEGIN
  IF Display.Depth(0) >= 8 THEN NC := 256; SC := 16
    ELSE NC := 16; SC := 4
  END
END ColorSystem.

System.Free ColorSystem ~
Gadgets.Insert ColorSystem.NewFrame ~
