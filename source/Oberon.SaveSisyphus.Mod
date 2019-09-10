(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(*
	An adaptation of Sisiphus.Mod for SaveScreen.
	Original Sisiphus.Mod [sic] by gri/jt/jm. Copied procedures are marked (*Sisiphus*)
*)

(* revision history
	1999.11.11/20:00 - bpsm - preview 1
	1999.11.12/17:44 - bpsm - preview 2
		- Spelling of Sisyphus corrected.
		- Sisyphus now remembers where he left off and continues from there.
	2000.03.31/12:17 - bpsm
		-
*)

MODULE SaveSisyphus IN Oberon;	(** portable *)
	(* bpsm 1999.11.11 from work by: gri 18.3.91 / 30.1.92 / 27.4.92 / jt/jm 7.11.95 *)

	IMPORT SYSTEM, Out, Math IN A2, Files, Display, Modules, SaveScreen;

	CONST
		versionString = "SaveSisyphus 2000.03.31/12:17 - bpsm";
		dataFileName0 = "Sisiphus.Data";	(* legacy name, misspelled *)
		dataFileName1 = "Sisyphus.Data";	(* correct spelling *)
		dataFileName2 = "Sysyphus.Data";	(* paranoia *)
		dataFileName3 = "Sysiphus.Data";	(* paranoia *)

		IStag = 753; (* icon stretch tag *)
		HSide = 31; Side = 64; (* dimensions *)
		MaxN = 16;
		frameRate = 10;
		boogieDistance = 9;	(* how far Sisiphus slides forward after every frame *)

	TYPE
		Icon = ARRAY 2 OF RECORD
			addr: ADDRESS;
			image: ARRAY Side+1 OF SET
		END;

	VAR
		N: SIGNED32; (* no. of figurs *)
		Fig: POINTER TO ARRAY MaxN OF Icon;	(* stored on heap *)
		State: SIGNED16;	(* frame number *)
		x0, y0: SIGNED16;	(* sisiphus' location *)

	(* declare state variables *)


	PROCEDURE Start;

		PROCEDURE EmptyFig;	(*Sisiphus*)
			VAR j: SIGNED16;
		BEGIN N := 1; j := 1;
			WHILE j < Side DO
				Fig[0, 0].image[j] := {};
				Fig[0, 1].image[j] := {};
				INC(j)
			END;
			Fig[0, 0].addr := Display.NewPattern(HSide, Side, Fig[0, 0].image);
			Fig[0, 1].addr := Display.NewPattern(HSide, Side, Fig[0, 1].image)
		END EmptyFig;

		PROCEDURE LoadFig; (* read portable file format *)	(*Sisiphus*)
			VAR F: Files.File; R: Files.Rider; i, j: SIGNED16;

			PROCEDURE ReadInt (VAR x: SIGNED32);
				VAR n: SIGNED32; i: SIGNED8; ch: CHAR;
			BEGIN i := 0; n := 0; Files.Read(R, ch);
				WHILE ORD(ch) >= 128 DO INC(n, ASH(ORD(ch) - 128, i)); INC(i, 7); Files.Read(R, ch) END;
				x := n + ASH(ORD(ch) MOD 64 - ORD(ch) DIV 64 * 64, i)
			END ReadInt;

			PROCEDURE ReadSet (VAR s: SET);
				VAR x: SIGNED32; i: SIGNED16;
			BEGIN ReadInt(x); s := {}; i := 0;
				WHILE i < 32 DO
					IF ODD(x) THEN INCL(s, i) END;
					x := x DIV 2; INC(i)
				END
			END ReadSet;

		BEGIN
			F := Files.Old(dataFileName1);
			IF F = NIL THEN F := Files.Old(dataFileName0) END;
			IF F = NIL THEN F := Files.Old(dataFileName2) END;
			IF F = NIL THEN F := Files.Old(dataFileName3) END;
			IF F = NIL THEN EmptyFig; RETURN END;
			Files.Set(R, F, 0); ReadInt(N);
			IF N # IStag THEN EmptyFig; RETURN END;
			ReadInt(N); i := 0;
			WHILE i < N DO j := 1;
				WHILE j <= Side DO
					ReadSet(Fig[i, 0].image[j]);
					ReadSet(Fig[i, 1].image[j]);
					Fig[i, 1].image[j] := LSH(Fig[i, 1].image[j], 1) + LSH(Fig[i, 0].image[j], -31);
					INC(j)
				END;
				Fig[i, 0].addr := Display.NewPattern(HSide, Side, Fig[i, 0].image);
				Fig[i, 1].addr := Display.NewPattern(HSide, Side, Fig[i, 1].image);
				INC(i)
			END
		END LoadFig;

		PROCEDURE HotSpot (X, Y, W, H, X0, Y0: SIGNED16);	(*Sisiphus*)
			CONST d = 6;
			VAR dx, dy: SIGNED32; r: SIGNED16;

			PROCEDURE Block (x, y, w, h, col, mode: SIGNED16);
			BEGIN
				IF x < X THEN DEC(w, X-x); x := X END;
				IF x+w > X+W THEN w := X+W-x END;
				IF w <= 0 THEN RETURN END;
				IF y < Y THEN DEC(h, Y-y); y := Y END;
				IF y+h > Y+H THEN h := Y+H-y END;
				IF h <= 0 THEN RETURN END;
				Display.ReplConst(col, x, y, w, h, mode)
			END Block;

			PROCEDURE Dot4 (x1, x2, y1, y2, col, mode: SIGNED16);
				CONST r = (d+1) DIV 2;
			BEGIN
				Block(x1-r, y1-r, 2*r+1, 2*r+1, col, mode);
				Block(x1-r, y2-r, 2*r+1, 2*r+1, col, mode);
				Block(x2-r, y1-r, 2*r+1, 2*r+1, col, mode);
				Block(x2-r, y2-r, 2*r+1, 2*r+1, col, mode)
			END Dot4;

			PROCEDURE Circle (X, Y, R, col, mode: SIGNED16);
				VAR x, y, dx, dy, d: SIGNED16;
			BEGIN
				x := R; y := 0; dx := 8*(x-1); dy := 8*y+4; d := 1 - 4*R;
				WHILE x > y DO
					Dot4(X-x-1, X+x, Y-y-1, Y+y, col, mode);
					Dot4(X-y-1, X+y, Y-x-1, Y+x, col, mode);
					INC(d, dy); INC(dy, 8); INC(y);
					IF d >= 0 THEN DEC(d, dx); DEC(dx, 8); DEC(x) END
				END;
				IF x = y THEN Dot4(X-x-1, X+x, Y-y-1, Y+y, col, mode) END
			END Circle;

		BEGIN
			IF X0-X > X+W-X0 THEN dx := X0-X ELSE dx := X+W-X0 END;
			IF Y0-Y > Y+H-Y0 THEN dy := Y0-Y ELSE dy := Y+H-Y0 END;
			r := SHORT(ENTIER(Math.sqrt(dx*dx + dy*dy)));
			WHILE r > 0 DO Circle(X0, Y0, r, Display.FG, Display.replace); DEC(r, d) END
		END HotSpot;

	BEGIN
		IF Fig = NIL THEN NEW(Fig);  LoadFig END;
		HotSpot(Display.Left, Display.Bottom, Display.Width, Display.Height, x0 + Side DIV 2, y0 + Side DIV 2);
		SaveScreen.SetFrameRate(frameRate);
	END Start;


	PROCEDURE Step;
		VAR oldX, oldY : SIGNED16;
	BEGIN
		oldX := x0; oldY := y0;
		INC(State); INC(x0,boogieDistance);
		IF State = N THEN State := 0 END;
		IF x0 + Side > Display.Left + Display.Width THEN
			x0 := Display.Left; INC(y0, Side);
			IF y0 + Side > Display.Bottom + Display.Height THEN
				y0 := Display.Bottom
			END;
		END;
		Display.ReplConst(Display.FG, oldX, oldY, Side, Side, Display.replace);
		Display.CopyPattern(Display.BG, Fig[State,0].addr, x0, y0, Display.paint);
		Display.CopyPattern(Display.BG, Fig[State,1].addr, x0 + HSide, y0, Display.paint);
	END Step;


	PROCEDURE Stop;
	END Stop;


	PROCEDURE Install*;
	BEGIN
		SaveScreen.InstallFader(Start, Step, Stop)
	END Install;


	PROCEDURE Remove;
	BEGIN
		SaveScreen.RemoveFader(Start, Step, Stop)
	END Remove;

BEGIN
	x0 := 0; y0 := 0; State := 0;
	N := 0; Fig := NIL;
	Modules.InstallTermHandler(Remove);
	Out.String(versionString); Out.Ln;
END SaveSisyphus.

SaveSisyphus.Install
System.Free SaveSisyphus ~
SaveScreen.Run