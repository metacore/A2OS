(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE VinciPens IN Oberon; (** portable *)	(* eos  *)

	(**
		Vinci extension for handling pen objects
	**)

	IMPORT
		Objects, Scheme, Ops := SchemeOps, Vinci, Images, Gfx, LeoPens, LeoOutliners;


	TYPE
		Object = Scheme.Object; Context = Vinci.Context;


	PROCEDURE Stroker (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR
			c: Context; col: Gfx.Color; img: Images.Image; w, limit, px, py: FLOAT32; cap: Gfx.CapStyle; join: Gfx.JoinStyle;
			str: Object; s: ARRAY 30 OF CHAR; pen: LeoPens.Stroker;
	BEGIN
		c := ctxt(Context); col := Gfx.Black; img := NIL; w := 1; limit := 5; cap := Gfx.DefaultCap; join := Gfx.DefaultJoin;
		WHILE Scheme.IsPair(args) DO
			str := Ops.StringArg(c, args);
			IF ~c.failed THEN
				Scheme.GetString(str, 0, Scheme.StringLen(str), s); s[0] := CAP(s[0]);
				IF s = "Color" THEN Vinci.GetColorVal(c, args, col)
				ELSIF s = "Pattern" THEN Vinci.GetPatternVal(c, args, img, px, py)
				ELSIF s = "Width" THEN w := SHORT(Ops.NumVal(c, args))
				ELSIF s = "Limit" THEN limit := SHORT(Ops.NumVal(c, args))
				ELSIF s = "Cap" THEN cap := Vinci.CapVal(c, args)
				ELSIF s = "Join" THEN join := Vinci.JoinVal(c, args)
				ELSE Scheme.Fail(c, "unknown stroker parameter", str)
				END
			END
		END;
		Ops.CheckNull(c, args);
		NEW(pen); LeoPens.InitStroker(pen, col, w);
		pen.img := img; pen.px := px; pen.py := py;
		pen.limit := limit; pen.capstyle := cap; pen.joinstyle := join;
		res := Scheme.NewRef(pen)
	END Stroker;

	PROCEDURE Filler (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR
			c: Context; col: Gfx.Color; img: Images.Image; eo: BOOLEAN; str: Object; s: ARRAY 30 OF CHAR; px, py: FLOAT32;
			pen: LeoPens.Filler;
	BEGIN
		c := ctxt(Context); col := Gfx.Black; img := NIL; eo := FALSE;
		WHILE Scheme.IsPair(args) DO
			str := Ops.StringArg(c, args);
			IF ~c.failed THEN
				Scheme.GetString(str, 0, Scheme.StringLen(str), s); s[0] := CAP(s[0]);
				IF s = "Color" THEN Vinci.GetColorVal(c, args, col)
				ELSIF s = "Pattern" THEN Vinci.GetPatternVal(c, args, img, px, py)
				ELSIF s = "Evenodd" THEN eo := Ops.BoolVal(c, args)
				ELSE Scheme.Fail(c, "unknown filler parameter", str)
				END
			END
		END;
		Ops.CheckNull(c, args);
		NEW(pen); LeoPens.InitFiller(pen, col);
		pen.img := img; pen.px := px; pen.py := py;
		res := Scheme.NewRef(pen)
	END Filler;

	PROCEDURE Forker (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR c: Context; lower, upper: LeoPens.Pen; str: Object; s: ARRAY 30 OF CHAR; ref: Objects.Object; pen: LeoPens.Forker;
	BEGIN
		c := ctxt(Context); lower := LeoPens.Default; upper := lower;
		WHILE Scheme.IsPair(args) DO
			str := Ops.StringArg(c, args);
			IF ~c.failed THEN
				Scheme.GetString(str, 0, Scheme.StringLen(str), s); s[0] := CAP(s[0]);
				IF s = "Lower" THEN
					ref := Ops.RefVal(c, args);
					IF (ref # NIL) & (ref IS LeoPens.Pen) THEN
						lower := ref(LeoPens.Pen)
					END
				ELSIF s = "Upper" THEN
					ref := Ops.RefVal(c, args);
					IF (ref # NIL) & (ref IS LeoPens.Pen) THEN
						upper := ref(LeoPens.Pen)
					END
				ELSE Scheme.Fail(c, "unknown forker parameter", str)
				END
			END
		END;
		Ops.CheckNull(c, args);
		NEW(pen); LeoPens.InitForker(pen, lower, upper);
		res := Scheme.NewRef(pen)
	END Forker;

	PROCEDURE Dasher (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR
			c: Context; base: LeoPens.Pen; len: SIGNED32; on, off: ARRAY Gfx.MaxDashPatSize OF FLOAT32; cont: BOOLEAN;
			str: Object; s: ARRAY 30 OF CHAR; ref: Objects.Object; pen: LeoPens.Dasher;
	BEGIN
		c := ctxt(Context); base := LeoPens.Default; len := 1; on[0] := 5; off[0] := 5; cont := FALSE;
		WHILE Scheme.IsPair(args) DO
			str := Ops.StringArg(c, args);
			IF ~c.failed THEN
				Scheme.GetString(str, 0, Scheme.StringLen(str), s); s[0] := CAP(s[0]);
				IF s = "Base" THEN
					ref := Ops.RefVal(c, args);
					IF (ref # NIL) & (ref IS LeoPens.Pen) THEN
						base := ref(LeoPens.Pen)
					END
				ELSIF s = "Pattern" THEN Vinci.GetDashVal(c, args, on, off, len)
				ELSIF s = "Continuous" THEN cont := Ops.BoolVal(c, args)
				ELSE Scheme.Fail(c, "unknown dasher parameter", str)
				END
			END
		END;
		Ops.CheckNull(c, args);
		NEW(pen); LeoPens.InitDasher(pen, base, on, off, len); pen.continuous := cont;
		res := Scheme.NewRef(pen)
	END Dasher;

	PROCEDURE Outliner (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR
			c: Context; w, limit: FLOAT32; cap: Gfx.CapStyle; join: Gfx.JoinStyle; base: LeoPens.Pen; mode: SIGNED8;
			str: Object; s: ARRAY 30 OF CHAR; ref: Objects.Object; pen: LeoOutliners.Outliner;
	BEGIN
		c := ctxt(Context); w := 1; limit := 5; cap := Gfx.DefaultCap; join := Gfx.DefaultJoin;
		base := LeoPens.Default; mode := LeoOutliners.outlined;
		WHILE Scheme.IsPair(args) DO
			str := Ops.StringArg(c, args);
			IF ~c.failed THEN
				Scheme.GetString(str, 0, Scheme.StringLen(str), s); s[0] := CAP(s[0]);
				IF s = "Width" THEN w := SHORT(Ops.NumVal(c, args))
				ELSIF s = "Limit" THEN limit := SHORT(Ops.NumVal(c, args))
				ELSIF s = "Cap" THEN cap := Vinci.CapVal(c, args)
				ELSIF s = "Join" THEN join := Vinci.JoinVal(c, args)
				ELSIF s = "Base" THEN
					ref := Ops.RefVal(c, args);
					IF (ref # NIL) & (ref IS LeoPens.Pen) THEN
						base := ref(LeoPens.Pen)
					END
				ELSIF s = "Mode" THEN mode := SHORT(SHORT(Ops.IntVal(c, args)))
				ELSE Scheme.Fail(c, "unknown stroker parameter", str)
				END
			END
		END;
		NEW(pen); LeoOutliners.InitOutliner(pen, base, w, mode);
		pen.limit := limit; pen.capstyle := cap; pen.joinstyle := join;
		res := Scheme.NewRef(pen)
	END Outliner;

	PROCEDURE Arrow (ctxt: Scheme.Context; args: Object; VAR res: Object);
		VAR
			c: Context; w, limit, len, coff, cdist: FLOAT32; cap: Gfx.CapStyle; join: Gfx.JoinStyle; base: LeoPens.Pen;
			mode, dir: SIGNED8; str: Object; s: ARRAY 30 OF CHAR; ref: Objects.Object; pen: LeoOutliners.Arrow;
	BEGIN
		c := ctxt(Context); w := 1; limit := 5; cap := Gfx.DefaultCap; join := Gfx.DefaultJoin;
		base := LeoPens.Default; mode := LeoOutliners.outlined; dir := LeoOutliners.forwards;
		len := 10; coff := 10; cdist := 10;
		WHILE Scheme.IsPair(args) DO
			str := Ops.StringArg(c, args);
			IF ~c.failed THEN
				Scheme.GetString(str, 0, Scheme.StringLen(str), s); s[0] := CAP(s[0]);
				IF s = "Width" THEN w := SHORT(Ops.NumVal(c, args))
				ELSIF s = "Limit" THEN limit := SHORT(Ops.NumVal(c, args))
				ELSIF s = "Cap" THEN cap := Vinci.CapVal(c, args)
				ELSIF s = "Join" THEN join := Vinci.JoinVal(c, args)
				ELSIF s = "Base" THEN
					ref := Ops.RefVal(c, args);
					IF (ref # NIL) & (ref IS LeoPens.Pen) THEN
						base := ref(LeoPens.Pen)
					END
				ELSIF s = "Mode" THEN mode := SHORT(SHORT(Ops.IntVal(c, args)))
				ELSIF s = "Direction" THEN dir := SHORT(SHORT(Ops.IntVal(c, args)))
				ELSIF s = "Length" THEN len := SHORT(Ops.NumVal(c, args))
				ELSIF s = "Offset" THEN coff := SHORT(Ops.NumVal(c, args))
				ELSIF s = "Distance" THEN cdist := SHORT(Ops.NumVal(c, args))
				ELSE Scheme.Fail(c, "unknown stroker parameter", str)
				END
			END
		END;
		NEW(pen); LeoOutliners.InitArrow(pen, base, dir, mode, len, coff, cdist, w);
		pen.limit := limit; pen.capstyle := cap; pen.joinstyle := join;
		res := Scheme.NewRef(pen)
	END Arrow;


BEGIN
	Vinci.PDef("pens", "stroker", Stroker); Vinci.PDef("pens", "filler", Filler);
	Vinci.PDef("pens", "forker", Forker); Vinci.PDef("pens", "dasher", Dasher);
	Vinci.PDef("pens", "outliner", Outliner); Vinci.PDef("pens", "arrow", Arrow);
END VinciPens.
