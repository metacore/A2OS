(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Magnifier IN Oberon; (** portable *)	(* ejz  *)
	IMPORT SYSTEM, Modules, Display, Oberon, Effects, In, Out;

	VAR
		W, H, W2, H2, Z: SIGNED16;
		Marker, eArrow, oArrow: Oberon.Marker;
		buf, buf1, buf2: POINTER TO ARRAY OF CHAR;
		vX, vY, pix: SIGNED32;
		installed: BOOLEAN;

	PROCEDURE FlipArrow(X, Y: SIGNED32);
		VAR cx, cy, cw, ch: SIGNED16;
	BEGIN
		Display.GetClip(cx, cy, cw, ch);
		Display.SetClip(0, 0, Display.Width, Display.Height);
		Display.CopyPattern(Display.FG, Display.arrow, X, Y - 14, 2);
		Display.SetClip(cx, cy, cw, ch)
	END FlipArrow;

	PROCEDURE Rect(VAR X, Y: SIGNED16);
	BEGIN
		IF X < W2 THEN X := W2 END;
		IF X >= (Display.Width-W2) THEN X := Display.Width-W2-1 END;
		IF Y < H2 THEN Y := H2 END;
		IF Y >= (Display.Height-H2) THEN Y := Display.Height-H2-1 END;
		Display.TransferBlock(buf1^, 0, pix*W, X-W2, Y-H2, W, H, Display.get)
	END Rect;

	PROCEDURE FadeView;
	BEGIN
		IF (vX > 0) & (vY > 0) THEN
			Display.ReplConst(Display.FG, vX-1, vY-1, Z*W, 1, Display.invert);
			Display.ReplConst(Display.FG, vX-1, vY-1, 1, Z*H, Display.invert)
		ELSE
			Display.ReplConst(Display.FG, 0, Z*H, Z*W, 1, Display.invert);
			Display.ReplConst(Display.FG, Z*W, 0, 1, Z*H, Display.invert)
		END;
		Display.TransferBlock(buf^, 0, pix*Z*W, vX, vY, Z*W, Z*H, Display.set)
	END FadeView;

	PROCEDURE ShowView;
	BEGIN
		IF (vX > 0) & (vY > 0) THEN
			Display.ReplConst(Display.FG, vX-1, vY-1, Z*W, 1, Display.invert);
			Display.ReplConst(Display.FG, vX-1, vY-1, 1, Z*H, Display.invert)
		ELSE
			Display.ReplConst(Display.FG, 0, Z*H, Z*W, 1, Display.invert);
			Display.ReplConst(Display.FG, Z*W, 0, 1, Z*H, Display.invert)
		END
	END ShowView;

	PROCEDURE Draw(X, Y: SIGNED16);
		VAR i, j, m, n: SIGNED32; p: SIGNED32;
	BEGIN
		IF (X >= vX) & (X < (vX+Z*W)) & (Y >= vY) & (Y < (vY+Z*H)) THEN
			FadeView();
			IF vX = 0 THEN
				vX := Display.Width-Z*W; vY := Display.Height-Z*H
			ELSE
				vX := 0; vY := 0
			END;
			ShowView();
			Display.TransferBlock(buf^, 0, pix*Z*W, vX, vY, Z*W, Z*H, Display.get)
		END;
		i := X; j := Y; Rect(X, Y);
		FlipArrow(i, j);
		j := 0;
		WHILE j < pix*H DO
			i := 0;
			WHILE i < pix*W DO
				SYSTEM.MOVE(ADDRESSOF(buf1[j*W+i]), ADDRESSOF(p), pix);
				n := 0;
				WHILE n < pix*Z DO
					m := 0;
					WHILE m < pix*Z DO
						SYSTEM.MOVE(ADDRESSOF(p), ADDRESSOF(buf2[(Z*j+n)*Z*W + Z*i+m]), pix);
						INC(m, pix)
					END;
					INC(n, pix)
				END;
				INC(i, pix)
			END;
			INC(j, pix)
		END;
		Display.TransferBlock(buf2^, 0, pix*Z*W, vX, vY, Z*W, Z*H, Display.set)
	END Draw;

	PROCEDURE Fade(X, Y: SIGNED16);
	BEGIN
		FlipArrow(X, Y); Rect(X, Y)
	END Fade;

	PROCEDURE OK(): BOOLEAN;
	BEGIN
		IF pix = 0 THEN
			Out.String("Display module does not support TransferBlock");  Out.Ln
		END;
		RETURN pix # 0
	END OK;

	PROCEDURE GetParams(): BOOLEAN;
	BEGIN
		In.Open;
		In.Int(W);  In.Int(H);  In.Int(Z);
		IF ~In.Done THEN
			W := 32;  H := 32;  Z := 4
		END;
		W2 := W DIV 2;  H2 := H DIV 2;
		RETURN (Z*W < Display.Width) & (Z*H < Display.Height)
	END GetParams;

	PROCEDURE Zoom*;	(** width height zoomfactor *)
		VAR keys: SET; X, Y: SIGNED16;
	BEGIN
		IF installed OR ~OK() OR ~GetParams() THEN RETURN END; installed := TRUE;
		oArrow := Oberon.Arrow; eArrow := Effects.Arrow;
		NEW(buf, pix*Z*W*Z*H+4); NEW(buf1, pix*W*H+4); NEW(buf2, pix*Z*W*Z*H+4);
		vX := 0; vY := 0; ShowView();
		Display.TransferBlock(buf^, 0, pix*Z*W, vX, vY, Z*W, Z*H, Display.get);
		REPEAT Effects.TrackMouse(keys, X, Y, Marker) UNTIL keys # {};
		FadeView();
		REPEAT Effects.TrackMouse(keys, X, Y, Effects.Arrow) UNTIL keys = {};
		buf := NIL; buf1 := NIL; buf2 := NIL; installed := FALSE
	END Zoom;

	PROCEDURE Install*;	(** width height zoomfactor *)
	BEGIN
		IF installed OR ~OK() OR ~GetParams() THEN RETURN END; installed := TRUE;
		oArrow := Oberon.Arrow; eArrow := Effects.Arrow;
		NEW(buf, pix*Z*W*Z*H+4); NEW(buf1, pix*W*H+4); NEW(buf2, pix*Z*W*Z*H+4);
		vX := 0; vY := 0; ShowView();
		Display.TransferBlock(buf^, 0, pix*Z*W, vX, vY, Z*W, Z*H, Display.get);
		Oberon.Arrow := Marker; Effects.Arrow := Marker
	END Install;

	PROCEDURE Remove*;
	BEGIN
		IF ~installed OR ~OK() THEN RETURN END; installed := FALSE;
		FadeView();
		buf := NIL; buf1 := NIL; buf2 := NIL;
		Oberon.Arrow := oArrow; Effects.Arrow := eArrow
	END Remove;

	PROCEDURE Init;
	BEGIN
		pix := Display.TransferFormat(0) DIV 8; installed := FALSE;
		Marker.Draw := Draw; Marker.Fade := Fade
	END Init;

BEGIN
	Init();
	Modules.InstallTermHandler(Remove)
END Magnifier.

Magnifier.Zoom ~  Magnifier.Zoom 50 20 7 ~
Magnifier.Install ~  Magnifier.Install 50 20 7 ~
Magnifier.Remove
