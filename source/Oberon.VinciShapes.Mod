(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE VinciShapes IN Oberon; (** portable *)	(* eos  *)

	(**
		Integration of Vinci descriptions into Leonardo
	**)

	(*
		15.05.2000 - fixed CopyShape inverting shape order (noticed by ejz)
		18.05.2000 - added name parameters, shapes.name; return shape name for "Item"
	*)

	IMPORT
		Files, Objects, Display, Texts, Oberon, Gadgets, Scheme, Ops := SchemeOps, Vinci, GfxMatrix, Gfx,
		Leonardo, LeoPens, LeoPaths;


	CONST
		bool* = 1; int* = 2; real* = 3; string* = 5; color* = 6;
		object* = 7; shape* = 8; pen* = 9; name* = 10;


	TYPE
		Parameter* = POINTER TO ParamDesc;
		ParamDesc* = RECORD
			next*: Parameter;
			name*: ARRAY 64 OF CHAR;	(* parameter name *)
			sym*: Scheme.Object;	(* parameter symbol *)
			kind*: SIGNED16;	(* parameter kind *)
			imin*, imax*: SIGNED32;	(* integer range *)
			rmin*, rmax*: FLOAT32;	(* real range *)
		END;

		Shape* = POINTER TO ShapeDesc;
		ShapeDesc* = RECORD (Leonardo.ContainerDesc)
			par*: Parameter;	(** shape parameters **)
			text*: Texts.Text;	(** source text **)
			valid*: BOOLEAN;	(** set if successfully parsed **)
			env: Scheme.Environment;	(* shape environment *)
		END;

		(** rectangular frame shapes for anchoring Vinci descriptions **)
		Frame* = POINTER TO FrameDesc;
		FrameDesc* = RECORD (Leonardo.ShapeDesc)
			w*, h*: FLOAT32;	(** frame dimensions **)
			mat*: GfxMatrix.Matrix;	(** accumulated transformations **)
		END;


	VAR
		render, drag, matrix, bbox, locate, colorSym, shapeSym, quoteSym: Scheme.Object;
		strPool: Scheme.Pool;


	(*--- Color Conversion ---*)

	PROCEDURE ColorToInt (col: Scheme.Object; VAR i: SIGNED32);
		VAR vec: Scheme.Object; r, g, b: SIGNED32; exact: BOOLEAN;
	BEGIN
		i := 15;
		IF Scheme.IsPair(col) & (Scheme.Car(col) = colorSym) THEN
			vec := Scheme.Cdr(col);
			Scheme.GetInteger(Scheme.VectorAt(vec, 0), r, exact);
			Scheme.GetInteger(Scheme.VectorAt(vec, 1), g, exact);
			Scheme.GetInteger(Scheme.VectorAt(vec, 2), b, exact);
			i := Display.RGB(r, g, b)
		END
	END ColorToInt;

	PROCEDURE IntToColor (i: SIGNED32; VAR col: Scheme.Object);
		VAR v: ARRAY 3 OF SIGNED16; vec: Scheme.Object;
	BEGIN
		Display.GetColor(i, v[0], v[1], v[2]);
		vec := Scheme.NewVector(3, Scheme.nil);
		FOR i := 0 TO 2 DO
			Scheme.SetVectorAt(vec, i, Scheme.NewInteger(v[i]))
		END;
		col := Scheme.NewPair(colorSym, vec)
	END IntToColor;


	(**--- Shapes ---**)

	PROCEDURE Evaluate (ctxt: Scheme.Context; env: Scheme.Environment; obj: Scheme.Object): Scheme.Object;
	BEGIN
		IF Scheme.IsProcedure(obj) THEN
			obj := Scheme.NewPair(Scheme.NewPair(quoteSym, Scheme.NewPair(obj, Scheme.nil)), Scheme.nil)
		END;
		RETURN Scheme.Evaluate(ctxt, env, obj)
	END Evaluate;

	PROCEDURE IsMatrix (obj: Scheme.Object): BOOLEAN;
		VAR i: SIGNED32;
	BEGIN
		IF ~Scheme.IsVector(obj) OR (Scheme.VectorLen(obj) # 6) THEN RETURN FALSE END;
		FOR i := 0 TO 5 DO
			IF ~Scheme.IsNumber(Scheme.VectorAt(obj, i)) THEN RETURN FALSE END
		END;
		RETURN TRUE
	END IsMatrix;

	PROCEDURE GetMatrix (s: Shape; VAR m: GfxMatrix.Matrix);
		VAR val, res: Scheme.Object; ctxt: Vinci.Context; i: SIGNED32; x: FLOAT64;
	BEGIN
		m := GfxMatrix.Identity;
		IF Scheme.LookupVariable(matrix, s.env, val) THEN
			NEW(ctxt); Vinci.MakeContext(ctxt, Scheme.nil, NIL);
			res := Evaluate(ctxt, s.env, val);
			IF ~ctxt.failed & IsMatrix(res) THEN
				FOR i := 0 TO 5 DO
					Scheme.GetReal(Scheme.VectorAt(res, i), x);
					m[i DIV 2, i MOD 2] := SHORT(x)
				END
			ELSE Scheme.Fail(ctxt, "matrix value expected", val)
			END;
			IF ctxt.failed THEN Vinci.ShowError END
		END
	END GetMatrix;

	PROCEDURE GetBox (s: Shape; VAR m: GfxMatrix.Matrix; VAR llx, lly, urx, ury, bw: FLOAT32);
		VAR
			val, res, obj: Scheme.Object; ctxt: Vinci.Context; len, i: SIGNED32; x: FLOAT64; b: ARRAY 5 OF FLOAT32;
			x0, y0, x1, y1: FLOAT32;
	BEGIN
		Leonardo.GetComponentsBox(s.bottom, llx, lly, urx, ury, bw);
		IF Scheme.LookupVariable(bbox, s.env, val) THEN
			NEW(ctxt); Vinci.MakeContext(ctxt, Scheme.nil, NIL);
			res := Evaluate(ctxt, s.env, val);
			IF ~ctxt.failed & Scheme.IsVector(res) THEN
				len := Scheme.VectorLen(res);
				IF (len = 4) OR (len = 5) THEN
					i := 0;
					WHILE i < len DO
						obj := Scheme.VectorAt(res, i);
						IF Scheme.IsNumber(obj) THEN Scheme.GetReal(obj, x); b[i] := SHORT(x)
						ELSE Scheme.Fail(ctxt, "number expected", obj)
						END;
						INC(i)
					END;
					IF ~ctxt.failed THEN
						GfxMatrix.ApplyToRect(m, b[0], b[1], b[2], b[3], x0, y0, x1, y1);
						IF x0 < llx THEN llx := x0 END;
						IF y0 < lly THEN lly := y0 END;
						IF x1 > urx THEN urx := x1 END;
						IF y1 > ury THEN ury := y1 END;
						IF len = 5 THEN
							GfxMatrix.ApplyToDist(m, b[4], x0);
							IF x0 > bw THEN bw := x0 END
						END
					END
				ELSE Scheme.Fail(ctxt, "illegal length of bounding box vector", res)
				END
			ELSE Scheme.Fail(ctxt, "bounding box expected", res)
			END;
			IF ctxt.failed THEN Vinci.ShowError END
		END
	END GetBox;

	PROCEDURE CalcBox (s: Shape; VAR mat: GfxMatrix.Matrix);
		VAR m: GfxMatrix.Matrix;
	BEGIN
		GetMatrix(s, m);
		GfxMatrix.Concat(m, mat, m);
		GetBox(s, m, s.llx, s.lly, s.urx, s.ury, s.bw)
	END CalcBox;

	PROCEDURE Select (s: Shape; VAR msg: Leonardo.SelectMsg);
		VAR cur: Leonardo.Shape;
	BEGIN
		IF msg.id = Leonardo.validate THEN
			Leonardo.ToComponents(s.bottom, msg);
			cur := s.bottom; WHILE (cur # NIL) & ~cur.sel DO cur := cur.up END;
			s.subsel := cur # NIL;
			IF s.subsel & ~s.sel THEN
				s.sel := TRUE;
				Leonardo.UpdateShape(msg.fig, s)
			END
		ELSE
			IF (msg.id = Leonardo.reset) & s.sel THEN
				Leonardo.UpdateShape(msg.fig, s)
			END;
			Leonardo.SelectContainer(s, msg)
		END
	END Select;

	PROCEDURE Control (s: Shape; VAR msg: Leonardo.ControlMsg);
	BEGIN
		IF msg.id = Leonardo.clone THEN
			Leonardo.ControlContainer(s, msg)
		ELSE
			Leonardo.ToComponents(s.bottom, msg)	(* ignore consume and delete messages *)
		END
	END Control;

	PROCEDURE Render (s: Shape; VAR msg: Leonardo.RenderMsg);
		VAR
			llx, lly, urx, ury, bw: FLOAT32; marked: BOOLEAN; cur: Leonardo.Shape; ctm, mat, m: GfxMatrix.Matrix;
			vc: Vinci.Context; val, res: Scheme.Object; state: Gfx.State; clip: Gfx.ClipArea; onoff: ARRAY 1 OF FLOAT32;
	BEGIN
		llx := s.llx - s.bw; lly := s.lly - s.bw; urx := s.urx + s.bw; ury := s.ury + s.bw;
		IF (llx < msg.urx) & (msg.llx < urx) & (lly < msg.ury) & (msg.lly < ury) THEN
			IF (msg.id IN {Leonardo.active, Leonardo.marksonly}) & s.sel OR (msg.id = Leonardo.marked) THEN
				Leonardo.ToComponents(s.bottom, msg)
			END;
			marked := s.marked; cur := s.bottom;
			WHILE ~marked & (cur # NIL) DO
				IF cur.marked THEN marked := TRUE END;
				cur := cur.up
			END;
			IF (msg.id IN {Leonardo.active, Leonardo.passive, Leonardo.marksonly}) OR (msg.id = Leonardo.marked) & marked THEN
				ctm := msg.ctxt.ctm;
				IF msg.id = Leonardo.marked THEN	(* dragging *)
					IF Scheme.LookupVariable(drag, s.env, val) & Scheme.IsProcedure(val) THEN
						GetMatrix(s, mat); Gfx.Concat(msg.ctxt, mat);
						NEW(vc); Vinci.MakeContext(vc, Scheme.nil, msg.ctxt);
						res := Evaluate(vc, s.env, val)
					END
				ELSE
					Gfx.Save(msg.ctxt, Gfx.attr, state);
					IF msg.id IN {Leonardo.active, Leonardo.passive} THEN
						NEW(vc); Vinci.MakeContext(vc, Scheme.nil, msg.ctxt);
						GetMatrix(s, mat); Leonardo.GetCoordSystem(s, m);
						GfxMatrix.Concat(mat, m, m);	(* m maps from render to global coordinates *)
						GfxMatrix.Concat(mat, ctm, mat);	(* mat maps from render to device coordinates *)
						GetBox(s, m, llx, lly, urx, ury, bw);
						IF Scheme.LookupVariable(render, s.env, val) & Scheme.IsProcedure(val) THEN
							clip := Gfx.GetClip(msg.ctxt);
							Gfx.ResetCTM(msg.ctxt); Gfx.Concat(msg.ctxt, msg.gsm);
							Gfx.DrawRect(msg.ctxt, llx - bw, lly - bw, urx + bw, ury + bw, {Gfx.Clip});
							Gfx.SetCTM(msg.ctxt, mat);
							res := Evaluate(vc, s.env, val);
							Gfx.SetClip(msg.ctxt, clip);
						ELSE Scheme.Fail(vc, "missing 'render' procedure", Scheme.false)
						END;
						IF vc.failed THEN
							Gfx.ResetCTM(msg.ctxt); Gfx.Concat(msg.ctxt, msg.gsm);
							IF Gfx.InPath IN msg.ctxt.mode THEN Gfx.End(msg.ctxt) END;
							Gfx.SetFillColor(msg.ctxt, Gfx.Red);
							Gfx.DrawRect(msg.ctxt, llx, lly, urx, ury, {Gfx.Fill});
							Vinci.ShowError
						END
					END;
					IF (msg.id IN {Leonardo.active, Leonardo.marksonly}) & s.sel THEN
						Gfx.ResetCTM(msg.ctxt); Gfx.Concat(msg.ctxt, msg.gsm);
						Gfx.DrawRect(msg.ctxt, llx, lly, urx, ury, {Gfx.Record});
						Gfx.ResetCTM(msg.ctxt);
						Gfx.SetStrokeColor(msg.ctxt, Gfx.DGrey); Gfx.SetLineWidth(msg.ctxt, 1);
						onoff[0] := 4;
						Gfx.SetDashPattern(msg.ctxt, onoff, onoff, 1, 0);
						Gfx.Render(msg.ctxt, {Gfx.Stroke})
					END;
					Gfx.Restore(msg.ctxt, state)
				END;
				Gfx.SetCTM(msg.ctxt, ctm)
			END
		END
	END Render;

	PROCEDURE Validate (s: Shape; VAR msg: Leonardo.ValidateMsg);
	BEGIN
		Leonardo.ToComponents(s.bottom, msg);
		IF s.marked THEN
			Leonardo.UpdateShape(msg.fig, s);
			CalcBox(s, msg.lgm);
			Leonardo.UpdateShape(msg.fig, s);
			s.marked := FALSE; s.cont.marked := TRUE
		END
	END Validate;

	PROCEDURE Locate (s: Shape; VAR msg: Leonardo.LocateMsg);
		VAR
			mres: Leonardo.Shape; val, args: Scheme.Object; mat, inv: GfxMatrix.Matrix; llx, lly, urx, ury: FLOAT32;
			vc: Vinci.Context;
	BEGIN
		IF msg.id IN {Leonardo.inside, Leonardo.project} THEN
			Leonardo.HandleContainer(s, msg)
		ELSIF (msg.id = Leonardo.overlap) & (msg.llx < s.urx) & (s.llx < msg.urx) & (msg.lly < s.ury) & (s.lly < msg.ury) THEN
			mres := msg.res; msg.res := s; s.slink := mres;
			Leonardo.ToComponents(s.bottom, msg);
			IF msg.res = s THEN
				msg.res := mres;
				IF Scheme.LookupVariable(locate, s.env, val) THEN
					IF Scheme.IsProcedure(val) THEN
						GetMatrix(s, mat); GfxMatrix.Concat(mat, msg.lgm, mat); GfxMatrix.Invert(mat, inv);
						GfxMatrix.ApplyToRect(inv, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
						args := Scheme.NewPair(Scheme.NewReal(ury), Scheme.nil);
						args := Scheme.NewPair(Scheme.NewReal(urx), args);
						args := Scheme.NewPair(Scheme.NewReal(lly), args);
						args := Scheme.NewPair(Scheme.NewReal(llx), args);
						val := Scheme.NewPair(locate, args);
						NEW(vc); Vinci.MakeContext(vc, Scheme.nil, NIL);
						val := Evaluate(vc, s.env, val)
					END;
					IF Scheme.IsBool(val) & Scheme.BoolValue(val) THEN
						s.slink := msg.res; msg.res := s
					END
				END
			ELSIF ~s.sel THEN
				msg.res := s
			END
		END
	END Locate;

	PROCEDURE UpdatePen (s: Shape; VAR msg: LeoPens.UpdateMsg);
		VAR par: Parameter; val: Scheme.Object; obj: Objects.Object;
	BEGIN
		par := s.par;
		WHILE par # NIL DO
			IF (par.kind = pen) & Scheme.LookupVariable(par.sym, s.env, val) THEN
				obj := Scheme.RefValue(val);
				IF obj = msg.pen THEN s.marked := TRUE; s.sel := TRUE
				ELSIF obj # NIL THEN obj.handle(obj, msg)
				END
			END;
			par := par.next
		END
	END UpdatePen;

	PROCEDURE HandleAttr (s: Shape; VAR msg: Objects.AttrMsg);
		VAR par: Parameter; val: Scheme.Object; exact: BOOLEAN;
	BEGIN
		IF msg.id = Objects.enum THEN
			par := s.par;
			WHILE par # NIL DO
				IF par.kind IN {bool, int, real, string, color} THEN msg.Enum(par.name) END;
				par := par.next
			END;
			Leonardo.HandleContainer(s, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "VinciShapes.NewShape"; msg.res := 0
			ELSIF msg.name = "Item" THEN
				par := s.par; WHILE (par # NIL) & (par.kind # name) DO par := par.next END;
				IF par # NIL THEN COPY(par.name, msg.s) ELSE msg.s := "Description" END;
				msg.class := Objects.String; msg.res := 0
			ELSE
				par := s.par; WHILE (par # NIL) & (par.name # msg.name) DO par := par.next END;
				IF par = NIL THEN Leonardo.HandleContainer(s, msg)
				ELSIF Scheme.LookupVariable(par.sym, s.env, val) THEN
					IF (par.kind = bool) & Scheme.IsBool(val) THEN
						msg.class := Objects.Bool; msg.b := Scheme.BoolValue(val); msg.res := 0
					ELSIF (par.kind = int) & Scheme.IsInteger(val) THEN
						msg.class := Objects.Int; Scheme.GetInteger(val, msg.i, exact); msg.res := 0
					ELSIF (par.kind = real) & Scheme.IsReal(val) THEN
						msg.class := Objects.Real; Scheme.GetReal(val, msg.y); msg.x := SHORT(msg.y); msg.res := 0
					ELSIF (par.kind = string) & Scheme.IsString(val) THEN
						msg.class := Objects.String; Scheme.GetString(val, 0, Scheme.StringLen(val), msg.s); msg.res := 0
					ELSIF par.kind = color THEN
						msg.class := Objects.Int; ColorToInt(val, msg.i); msg.res := 0
					END
				ELSE Leonardo.HandleContainer(s, msg)
				END
			END
		ELSIF msg.id = Objects.set THEN
			par := s.par; WHILE (par # NIL) & (par.name # msg.name) DO par := par.next END;
			IF par = NIL THEN
				Leonardo.HandleContainer(s, msg)
			ELSIF par.kind = bool THEN
				IF msg.class = Objects.Bool THEN
					IF msg.b THEN val := Scheme.true ELSE val := Scheme.false END;
					IF Scheme.SetVariable(par.sym, val, s.env) THEN msg.res := 0 END
				END
			ELSIF par.kind = int THEN
				IF (msg.class = Objects.Int) & (par.imin <= msg.i) & (msg.i <= par.imax) THEN
					val := Scheme.NewInteger(msg.i);
					IF Scheme.SetVariable(par.sym, val, s.env) THEN msg.res := 0 END
				END
			ELSIF par.kind = real THEN
				IF (msg.class = Objects.Real) & (par.rmin <= msg.x) & (msg.x <= par.rmax) THEN
					val := Scheme.NewReal(msg.x);
					IF Scheme.SetVariable(par.sym, val, s.env) THEN msg.res := 0 END
				END
			ELSIF par.kind = string THEN
				IF msg.class = Objects.String THEN
					val := Scheme.NewLiteral(msg.s, strPool);
					IF Scheme.SetVariable(par.sym, val, s.env) THEN msg.res := 0 END
				END
			ELSIF par.kind = color THEN
				IF msg.class = Objects.Int THEN
					IntToColor(msg.i, val);
					IF Scheme.SetVariable(par.sym, val, s.env) THEN msg.res := 0 END
				END
			END
		END
	END HandleAttr;

	PROCEDURE HandleLinks (s: Shape; VAR msg: Objects.LinkMsg);
		VAR par: Parameter; val: Scheme.Object;
	BEGIN
		IF msg.id = Objects.enum THEN
			par := s.par;
			WHILE par # NIL DO
				IF par.kind IN {object, shape, pen} THEN msg.Enum(par.name) END;
				par := par.next
			END;
			Leonardo.HandleContainer(s, msg)
		ELSIF msg.id = Objects.get THEN
			par := s.par; WHILE (par # NIL) & (par.name # msg.name) DO par := par.next END;
			IF par = NIL THEN Leonardo.HandleContainer(s, msg)
			ELSIF Scheme.LookupVariable(par.sym, s.env, val) THEN
				IF par.kind IN {object, shape, pen} THEN msg.obj := Scheme.RefValue(val); msg.res := 0 END
			ELSE Leonardo.HandleContainer(s, msg)
			END
		ELSIF msg.id = Objects.set THEN
			par := s.par; WHILE (par # NIL) & (par.name # msg.name) DO par := par.next END;
			IF par = NIL THEN
				Leonardo.HandleContainer(s, msg)
			ELSIF par.kind = object THEN
				IF Scheme.SetVariable(par.sym, Scheme.NewRef(msg.obj), s.env) THEN msg.res := 0 END
			ELSIF (par.kind = shape) & (msg.obj # NIL) & (msg.obj IS Leonardo.Shape) THEN
				IF Scheme.SetVariable(par.sym, Scheme.NewRef(msg.obj), s.env) THEN msg.res := 0 END
			ELSIF (par.kind = pen) & (msg.obj # NIL) & (msg.obj IS LeoPens.Pen) THEN
				IF Scheme.SetVariable(par.sym, Scheme.NewRef(msg.obj), s.env) THEN msg.res := 0 END
			END
		END
	END HandleLinks;

	PROCEDURE Read* (shape: Shape);
		VAR ctxt: Vinci.Context; body: Scheme.Object;
	BEGIN
		IF shape.text # NIL THEN
			NEW(ctxt); Vinci.MakeContext(ctxt, Scheme.NewTextInput(shape.text, 0), NIL);
			Vinci.Parse(ctxt, body);
			IF body = NIL THEN
				Scheme.Fail(ctxt, "shape program is empty", Scheme.false)
			ELSE
				shape.par := NIL; shape.env := Scheme.NewEnvironment(Vinci.globals);
				Scheme.DefineVariable(shapeSym, Scheme.NewRef(shape), shape.env);
				Scheme.EvaluateSequence(ctxt, shape.env, body);
				IF ~ctxt.failed THEN
					CalcBox(shape, GfxMatrix.Identity); shape.valid := TRUE
				END
			END;
			IF ctxt.failed THEN
				Vinci.ShowError; shape.valid := FALSE
			END
		END
	END Read;

	PROCEDURE CopyShape* (VAR msg: Objects.CopyMsg; from, to: Shape);
		VAR fpar, tpar: Parameter; comp: Leonardo.Shape; val: Scheme.Object; res: BOOLEAN;
	BEGIN
		Leonardo.CopyContainer(msg, from, to); comp := to.top;
		to.text := from.text; Read(to);
		IF comp # NIL THEN
			to.top := comp; comp.up.down := NIL; comp.up := NIL
		END;
		fpar := from.par; tpar := to.par; comp := to.bottom;
		WHILE fpar # NIL DO
			ASSERT((tpar # NIL) & (tpar.sym = fpar.sym) & (fpar.kind = tpar.kind));
			IF Scheme.LookupVariable(fpar.sym, from.env, val) THEN
				IF fpar.kind = shape THEN
					val := Scheme.NewRef(comp); comp := comp.up
				END;
				res := Scheme.SetVariable(tpar.sym, val, to.env)
			END;
			fpar := fpar.next; tpar := tpar.next
		END
	END CopyShape;

	PROCEDURE BindParams (s: Shape; VAR msg: Objects.ObjMsg);
		VAR par: Parameter; val: Scheme.Object; obj: Objects.Object;
	BEGIN
		par := s.par;
		WHILE par # NIL DO
			IF (par.kind IN {object, shape, pen}) & Scheme.LookupVariable(par.sym, s.env, val) THEN
				obj := Scheme.RefValue(val);
				IF obj # NIL THEN
					obj.handle(obj, msg)
				END
			END;
			par := par.next
		END
	END BindParams;

	PROCEDURE WriteParams (s: Shape; VAR r: Files.Rider);
		VAR par: Parameter; res: BOOLEAN; val: Scheme.Object; l: SIGNED32; x: FLOAT64; str: ARRAY 64 OF CHAR;
	BEGIN
		par := s.par;
		WHILE par # NIL DO
			res := Scheme.LookupVariable(par.sym, s.env, val);
			CASE par.kind OF
			| bool: Files.WriteBool(r, Scheme.BoolValue(val))
			| int: Scheme.GetInteger(val, l, res); Files.WriteNum(r, l); Files.WriteLInt(r, par.imin); Files.WriteLInt(r, par.imax)
			| real: Scheme.GetReal(val, x); Files.WriteReal(r, SHORT(x)); Files.WriteReal(r, par.rmin); Files.WriteReal(r, par.rmax)
			| string: Scheme.GetString(val, 0, Scheme.StringLen(val), str); Files.WriteString(r, str)
			| color: ColorToInt(val, l); Files.WriteLInt(r, l)
			| object, shape, pen: Gadgets.WriteRef(r, s.lib, Scheme.RefValue(val))
			| name:
			END;
			par := par.next
		END
	END WriteParams;

	PROCEDURE ReadParams (s: Shape; VAR r: Files.Rider);
		VAR
			par: Parameter; b: BOOLEAN; val: Scheme.Object; l: SIGNED32; x: FLOAT32; str: ARRAY 64 OF CHAR;
			obj: Objects.Object;
	BEGIN
		par := s.par;
		WHILE par # NIL DO
			CASE par.kind OF
			| bool: Files.ReadBool(r, b); IF b THEN val := Scheme.true ELSE val := Scheme.false END
			| int:
				Files.ReadNum(r, l); Files.ReadLInt(r, par.imin); Files.ReadLInt(r, par.imax);
				val := Scheme.NewInteger(l)
			| real:
				Files.ReadReal(r, x); Files.ReadReal(r, par.rmin); Files.ReadReal(r, par.rmax);
				val := Scheme.NewReal(x)
			| string: Files.ReadString(r, str); val := Scheme.NewLiteral(str, strPool)
			| color: Files.ReadLInt(r, l); IntToColor(l, val);
			| object: Gadgets.ReadRef(r, s.lib, obj); val := Scheme.NewRef(obj)
			| shape:
				Gadgets.ReadRef(r, s.lib, obj);
				IF (obj # NIL) & (obj IS Leonardo.Shape) THEN val := Scheme.NewRef(obj)
				ELSE b := Scheme.LookupVariable(par.sym, s.env, val)
				END
			| pen:
				Gadgets.ReadRef(r, s.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN val := Scheme.NewRef(obj)
				ELSE b := Scheme.LookupVariable(par.sym, s.env, val)
				END
			| name:
			END;
			b := Scheme.SetVariable(par.sym, val, s.env);
			par := par.next
		END
	END ReadParams;

	PROCEDURE HandleShape (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR s, copy: Shape; ver: SIGNED32; top: Leonardo.Shape;
	BEGIN
		s := obj(Shape);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.SelectMsg THEN
				Select(s, msg(Leonardo.SelectMsg))
			ELSIF msg IS Leonardo.ControlMsg THEN
				Control(s, msg(Leonardo.ControlMsg))
			ELSIF msg IS Leonardo.RenderMsg THEN
				Render(s, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.ValidateMsg THEN
				Validate(s, msg(Leonardo.ValidateMsg))
			ELSIF msg IS Leonardo.LocateMsg THEN
				Locate(s, msg(Leonardo.LocateMsg))
			ELSE
				Leonardo.HandleContainer(s, msg)
			END
		ELSIF msg IS LeoPens.UpdateMsg THEN
			UpdatePen(s, msg(LeoPens.UpdateMsg))
		ELSIF msg IS Objects.AttrMsg THEN
			HandleAttr(s, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.LinkMsg THEN
			HandleLinks(s, msg(Objects.LinkMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # s.stamp THEN
					NEW(copy); s.dlink := copy; s.stamp := msg.stamp;
					CopyShape(msg, s, copy)
				END;
				msg.obj := s.dlink
			END
		ELSIF msg IS Objects.BindMsg THEN
			Leonardo.HandleContainer(s, msg);
			BindParams(s, msg);
			s.text.handle(s.text, msg)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Leonardo.HandleContainer(s, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Gadgets.WriteRef(msg.R, s.lib, s.text);
					WriteParams(s, msg.R)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Gadgets.ReadRef(msg.R, s.lib, obj);
					IF (obj # NIL) & (obj IS Texts.Text) THEN
						top := s.top;
						s.text := obj(Texts.Text); Read(s);
						s.top := top;
						IF top # NIL THEN top.up := NIL END
					END;
					ReadParams(s, msg.R);
					CalcBox(s, GfxMatrix.Identity)
				END
			END
		ELSE
			Leonardo.HandleContainer(s, msg)
		END
	END HandleShape;

	PROCEDURE InitShape* (shape: Shape; text: Texts.Text);
	BEGIN
		Leonardo.InitContainer(shape, HandleShape, NIL, NIL);
		shape.text := text; Read(shape)
	END InitShape;

	PROCEDURE NewShape*;
		VAR s: Shape;
	BEGIN
		NEW(s); Leonardo.InitContainer(s, HandleShape, NIL, NIL);
		Objects.NewObj := s
	END NewShape;

	PROCEDURE Integrate*;
		VAR
			s: Texts.Scanner; text: Texts.Text; beg, end, time: SIGNED32; shape: Shape;
			frame: Display.Frame; u, v: SIGNED16; lm: Objects.LinkMsg; fig: Leonardo.Figure;
	BEGIN
		Texts.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(s);
		IF (s.class = Texts.Char) & (s.c = "^") THEN
			Oberon.GetSelection(text, beg, end, time);
			IF time >= 0 THEN
				Texts.OpenScanner(s, text, beg); Texts.Scan(s)
			END
		END;
		IF s.class = Texts.Name THEN
			NEW(text); Texts.Open(text, s.s);
			IF text.len # 0 THEN
				NEW(shape); InitShape(shape, text);
				IF shape.valid THEN
					Gadgets.ThisFrame(Oberon.Pointer.X, Oberon.Pointer.Y, frame, u, v);
					lm.id := Objects.get; lm.name := "Model"; lm.obj := NIL; lm.res := -1; frame.handle(frame, lm);
					IF (lm.res >= 0) & (lm.obj # NIL) & (lm.obj IS Leonardo.Figure) THEN
						fig := lm.obj(Leonardo.Figure);
						Leonardo.Integrate(fig, shape)
					END
				END
			END
		END
	END Integrate;


	(**--- Frames ---**)

	PROCEDURE CopyFrame* (VAR msg: Objects.CopyMsg; from, to: Frame);
	BEGIN
		Leonardo.CopyShape(msg, from, to);
		to.w := from.w; to.h := from.h; to.mat := from.mat
	END CopyFrame;

	PROCEDURE HandleFrame* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame, copy: Frame; mat, lgm, inv: GfxMatrix.Matrix; llx, lly, urx, ury: FLOAT32; ver: SIGNED32;
	BEGIN
		frame := obj(Frame);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.CoordMsg THEN
				WITH msg: Leonardo.CoordMsg DO
					IF msg.dest = frame THEN
						GfxMatrix.Concat(frame.mat, msg.lgm, msg.res)
					END
				END
			ELSIF msg IS Leonardo.RenderMsg THEN
				WITH msg: Leonardo.RenderMsg DO
					IF (msg.id IN {Leonardo.active, Leonardo.marksonly}) OR (msg.id = Leonardo.marked) & frame.marked THEN
						IF (frame.llx < msg.urx) & (msg.llx < frame.urx) & (frame.lly < msg.ury) & (msg.lly < frame.ury) THEN
							IF msg.id = Leonardo.marked THEN
								mat := msg.ctxt.ctm; Gfx.Concat(msg.ctxt, frame.mat);
								Gfx.DrawRect(msg.ctxt, 0, 0, frame.w, frame.h, {Gfx.Stroke});
								Gfx.SetCTM(msg.ctxt, mat)
							ELSIF (msg.id IN {Leonardo.active, Leonardo.marksonly}) & frame.sel THEN
								mat := msg.ctxt.ctm; Gfx.Concat(msg.ctxt, frame.mat);
								lgm := msg.lgm; GfxMatrix.Concat(frame.mat, lgm, msg.lgm);
								Leonardo.DrawHandles(0, 0, frame.w, frame.h, msg);
								msg.lgm := lgm; Gfx.SetCTM(msg.ctxt, mat)
							END
						END
					END
				END
			ELSIF msg IS Leonardo.ValidateMsg THEN
				WITH msg: Leonardo.ValidateMsg DO
					IF frame.marked THEN
						Leonardo.UpdateShape(msg.fig, frame);
						GfxMatrix.Concat(frame.mat, msg.lgm, mat);
						GfxMatrix.ApplyToRect(mat, 0, 0, frame.w, frame.h, frame.llx, frame.lly, frame.urx, frame.ury);
						frame.bw := 0;
						Leonardo.UpdateShape(msg.fig, frame);
						frame.marked := FALSE; frame.cont.marked := TRUE
					END
				END
			ELSIF msg IS Leonardo.LocateMsg THEN
				WITH msg: Leonardo.LocateMsg DO
					IF (msg.id = Leonardo.inside) & (msg.llx <= frame.llx) & (frame.urx <= msg.urx) & (msg.lly <= frame.lly) & (frame.ury <= msg.ury) THEN
						frame.slink := msg.res; msg.res := frame
					ELSIF (msg.id = Leonardo.overlap) & (msg.llx < frame.urx) & (frame.llx < msg.urx) & (msg.lly < frame.ury) & (frame.lly < msg.ury) THEN
						GfxMatrix.Concat(frame.mat, msg.lgm, mat); GfxMatrix.Invert(mat, inv);
						GfxMatrix.ApplyToRect(inv, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
						IF (llx < frame.w) & (0 < urx) & (lly < frame.h) & (0 < ury) THEN
							frame.slink := msg.res; msg.res := frame
						END
					END
				END
			ELSIF msg IS Leonardo.MatrixMsg THEN
				WITH msg: Leonardo.MatrixMsg DO
					IF msg.dest = frame THEN
						mat := msg.lgm; GfxMatrix.Concat(frame.mat, mat, msg.lgm);
						Leonardo.GetHandleMatrix(0, 0, frame.w, frame.h, msg);
						msg.lgm := mat
					END
				END
			ELSIF msg IS Leonardo.TransformMsg THEN
				WITH msg: Leonardo.TransformMsg DO
					IF (msg.id = Leonardo.apply) & frame.marked & (msg.stamp # frame.stamp) THEN
						frame.stamp := msg.stamp;
						GfxMatrix.Invert(msg.lgm, inv);
						GfxMatrix.Concat(frame.mat, msg.lgm, mat);
						GfxMatrix.Concat(mat, msg.mat, mat);
						GfxMatrix.Concat(mat, inv, mat);
						Leonardo.SetMatrix(msg.fig, frame, "M", mat)
					END
				END
			ELSE
				Leonardo.HandleShape(frame, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					Leonardo.HandleShape(frame, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "VinciShapes.NewFrame"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "VinciFrame"; msg.res := 0
					ELSIF msg.name = "W" THEN msg.class := Objects.Real; msg.x := frame.w; msg.res := 0
					ELSIF msg.name = "H" THEN msg.class := Objects.Real; msg.x := frame.h; msg.res := 0
					ELSIF msg.name = "M00" THEN msg.class := Objects.Real; msg.x := frame.mat[0, 0]; msg.res := 0
					ELSIF msg.name = "M01" THEN msg.class := Objects.Real; msg.x := frame.mat[0, 1]; msg.res := 0
					ELSIF msg.name = "M10" THEN msg.class := Objects.Real; msg.x := frame.mat[1, 0]; msg.res := 0
					ELSIF msg.name = "M11" THEN msg.class := Objects.Real; msg.x := frame.mat[1, 1]; msg.res := 0
					ELSIF msg.name = "M20" THEN msg.class := Objects.Real; msg.x := frame.mat[2, 0]; msg.res := 0
					ELSIF msg.name = "M21" THEN msg.class := Objects.Real; msg.x := frame.mat[2, 1]; msg.res := 0
					ELSE Leonardo.HandleShape(frame, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "W" THEN
						IF msg.class = Objects.Real THEN frame.w := msg.x; msg.res := 0 END
					ELSIF msg.name = "H" THEN
						IF msg.class = Objects.Real THEN frame.h := msg.x; msg.res := 0 END
					ELSIF msg.name = "M00" THEN
						IF msg.class = Objects.Real THEN frame.mat[0, 0] := msg.x; msg.res := 0 END
					ELSIF msg.name = "M01" THEN
						IF msg.class = Objects.Real THEN frame.mat[0, 1] := msg.x; msg.res := 0 END
					ELSIF msg.name = "M10" THEN
						IF msg.class = Objects.Real THEN frame.mat[1, 0] := msg.x; msg.res := 0 END
					ELSIF msg.name = "M11" THEN
						IF msg.class = Objects.Real THEN frame.mat[1, 1] := msg.x; msg.res := 0 END
					ELSIF msg.name = "M20" THEN
						IF msg.class = Objects.Real THEN frame.mat[2, 0] := msg.x; msg.res := 0 END
					ELSIF msg.name = "M21" THEN
						IF msg.class = Objects.Real THEN frame.mat[2, 1] := msg.x; msg.res := 0 END
					ELSE
						Leonardo.HandleShape(frame, msg)
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # frame.stamp THEN
					NEW(copy); frame.dlink := copy; frame.stamp := msg.stamp;
					CopyFrame(msg, frame, copy)
				END;
				msg.obj := frame.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Leonardo.HandleShape(frame, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.WriteReal(msg.R, frame.w); Files.WriteReal(msg.R, frame.h);
					GfxMatrix.Write(msg.R, frame.mat)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.ReadReal(msg.R, frame.w); Files.ReadReal(msg.R, frame.h);
					GfxMatrix.Read(msg.R, frame.mat);
					GfxMatrix.ApplyToRect(frame.mat, 0, 0, frame.w, frame.h, frame.llx, frame.lly, frame.urx, frame.ury)
				END
			END
		ELSE
			Leonardo.HandleShape(frame, msg)
		END
	END HandleFrame;

	PROCEDURE InitFrame* (frame: Frame; w, h: FLOAT32);
	BEGIN
		Leonardo.InitShape(frame, HandleFrame);
		frame.w := w; frame.h := h; frame.mat := GfxMatrix.Identity;
		frame.llx := 0; frame.lly := 0; frame.urx := w; frame.ury := h
	END InitFrame;

	PROCEDURE NewFrame*;
		VAR frame: Frame;
	BEGIN
		NEW(frame); InitFrame(frame, 100, 100);
		Objects.NewObj := frame
	END NewFrame;


	(*--- Shape Package ---*)

	PROCEDURE Append (vs: Shape; par: Parameter);
		VAR prev: Parameter;
	BEGIN
		IF vs.par = NIL THEN vs.par := par
		ELSE
			prev := vs.par; WHILE prev.next # NIL DO prev := prev.next END;
			prev.next := par
		END
	END Append;

	PROCEDURE NumVal (ctxt: Scheme.Context; VAR args: Scheme.Object): FLOAT32;
	BEGIN
		RETURN SHORT(Ops.NumVal(ctxt, args))
	END NumVal;

	PROCEDURE FindShape (ctxt: Scheme.Context): Shape;
		VAR val: Scheme.Object; obj: Objects.Object;
	BEGIN
		IF Scheme.LookupVariable(shapeSym, ctxt.env, val) THEN obj := Scheme.RefValue(val); RETURN obj(Shape)
		ELSE Scheme.Fail(ctxt, "illegal use of shape operator", Scheme.false); RETURN NIL
		END
	END FindShape;

	PROCEDURE ShapeArg (ctxt: Scheme.Context; VAR args: Scheme.Object): Leonardo.Shape;
		VAR obj: Objects.Object;
	BEGIN
		obj := Ops.RefVal(ctxt, args);
		IF (obj # NIL) & (obj IS Leonardo.Shape) THEN RETURN obj(Leonardo.Shape)
		ELSE Scheme.Fail(ctxt, "argument must be shape", Scheme.NewRef(obj)); RETURN NIL
		END
	END ShapeArg;

	PROCEDURE EvalFrame (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR c: Vinci.Context; w, h: FLOAT32; frame: Frame;
	BEGIN
		c := ctxt(Vinci.Context); w := NumVal(c, args); h := NumVal(c, args); Ops.CheckNull(c, args);
		NEW(frame); InitFrame(frame, w, h);
		res := Scheme.NewRef(frame)
	END EvalFrame;

	PROCEDURE EvalPoint (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR c: Vinci.Context; x, y: FLOAT32; p: LeoPaths.Point;
	BEGIN
		c := ctxt(Vinci.Context); x := NumVal(c, args); y := NumVal(c, args); Ops.CheckNull(c, args);
		NEW(p); LeoPaths.InitPoint(p, x, y);
		res := Scheme.NewRef(p)
	END EvalPoint;

	PROCEDURE EvalMatrix (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR c: Vinci.Context; s: Leonardo.Shape; m: GfxMatrix.Matrix; i: SIGNED32;
	BEGIN
		c := ctxt(Vinci.Context); s := ShapeArg(c, args); Ops.CheckNull(c, args);
		IF s # NIL THEN
			Leonardo.GetCoordSystem(s, m);
			res := Scheme.NewVector(6, Scheme.nil);
			FOR i := 0 TO 5 DO
				Scheme.SetVectorAt(res, i, Scheme.NewReal(m[i DIV 2, i MOD 2]))
			END
		END
	END EvalMatrix;

	PROCEDURE EvalComponent (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR par: Parameter; vs: Shape; obj: Scheme.Object; ref: Objects.Object; s: Leonardo.Shape; cm: Objects.CopyMsg;
	BEGIN
		NEW(par); par.kind := shape; par.name := "";
		par.sym := Scheme.StringToSymbol(Ops.StringArg(ctxt, args)); vs := FindShape(ctxt);
		IF (vs # NIL) & Scheme.LookupVariable(par.sym, vs.env, obj) & Scheme.IsReference(obj) THEN
			ref := Scheme.RefValue(obj);
			IF (ref # NIL) & (ref IS Leonardo.Shape) THEN
				s := ref(Leonardo.Shape);
				IF s.cont # NIL THEN
					Objects.Stamp(cm); cm.id := Objects.shallow; s.handle(s, cm); s := cm.obj(Leonardo.Shape)
				END;
				s.down := vs.top; vs.top := s;
				IF s.down = NIL THEN vs.bottom := s ELSE s.down.up := s END;
				s.cont := vs;
				Append(vs, par)
			ELSE Scheme.Fail(ctxt, "object is not a shape", obj)
			END
		ELSIF obj = NIL THEN Scheme.FailCode(ctxt, Scheme.errUnbound, par.sym)
		ELSE Scheme.Fail(ctxt, "unknown shape object", obj)
		END
	END EvalComponent;

	PROCEDURE EvalInteger (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR par: Parameter; obj: Scheme.Object; vs: Shape;
	BEGIN
		NEW(par); par.kind := int; par.imin := MIN(SIGNED32); par.imax := MAX(SIGNED32);
		par.sym := Scheme.StringToSymbol(Ops.StringArg(ctxt, args));
		obj := Ops.StringArg(ctxt, args); Scheme.GetString(obj, 0, Scheme.StringLen(obj), par.name);
		IF Scheme.IsPair(args) THEN par.imin := Ops.IntVal(ctxt, args) END;
		IF Scheme.IsPair(args) THEN par.imax := Ops.IntVal(ctxt, args) END;
		Ops.CheckNull(ctxt, args);
		vs := FindShape(ctxt);
		IF vs # NIL THEN
			Append(vs, par)
		END
	END EvalInteger;

	PROCEDURE EvalReal (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR par: Parameter; obj: Scheme.Object; vs: Shape;
	BEGIN
		NEW(par); par.kind := real; par.rmin := MIN(FLOAT32); par.rmax := MAX(FLOAT32);
		par.sym := Scheme.StringToSymbol(Ops.StringArg(ctxt, args));
		obj := Ops.StringArg(ctxt, args); Scheme.GetString(obj, 0, Scheme.StringLen(obj), par.name);
		IF Scheme.IsPair(args) THEN par.rmin := NumVal(ctxt, args) END;
		IF Scheme.IsPair(args) THEN par.rmax := NumVal(ctxt, args) END;
		Ops.CheckNull(ctxt, args);
		vs := FindShape(ctxt);
		IF vs # NIL THEN
			Append(vs, par)
		END
	END EvalReal;

	PROCEDURE EvalString (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR par: Parameter; obj: Scheme.Object; vs: Shape;
	BEGIN
		NEW(par); par.kind := string;
		par.sym := Scheme.StringToSymbol(Ops.StringArg(ctxt, args));
		obj := Ops.StringArg(ctxt, args); Scheme.GetString(obj, 0, Scheme.StringLen(obj), par.name);
		Ops.CheckNull(ctxt, args);
		vs := FindShape(ctxt);
		IF vs # NIL THEN
			Append(vs, par)
		END
	END EvalString;

	PROCEDURE EvalBool (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR par: Parameter; obj: Scheme.Object; vs: Shape;
	BEGIN
		NEW(par); par.kind := bool;
		par.sym := Scheme.StringToSymbol(Ops.StringArg(ctxt, args));
		obj := Ops.StringArg(ctxt, args); Scheme.GetString(obj, 0, Scheme.StringLen(obj), par.name);
		Ops.CheckNull(ctxt, args);
		vs := FindShape(ctxt);
		IF vs # NIL THEN
			Append(vs, par)
		END
	END EvalBool;

	PROCEDURE EvalColor (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR par: Parameter; obj: Scheme.Object; vs: Shape;
	BEGIN
		NEW(par); par.kind := color;
		par.sym := Scheme.StringToSymbol(Ops.StringArg(ctxt, args));
		obj := Ops.StringArg(ctxt, args); Scheme.GetString(obj, 0, Scheme.StringLen(obj), par.name);
		Ops.CheckNull(ctxt, args);
		vs := FindShape(ctxt);
		IF vs # NIL THEN
			Append(vs, par)
		END
	END EvalColor;

	PROCEDURE EvalPen (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR par: Parameter; obj: Scheme.Object; vs: Shape;
	BEGIN
		NEW(par); par.kind := pen;
		par.sym := Scheme.StringToSymbol(Ops.StringArg(ctxt, args));
		obj := Ops.StringArg(ctxt, args); Scheme.GetString(obj, 0, Scheme.StringLen(obj), par.name);
		Ops.CheckNull(ctxt, args);
		vs := FindShape(ctxt);
		IF vs # NIL THEN
			Append(vs, par)
		END
	END EvalPen;

	PROCEDURE EvalName (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR par: Parameter; obj: Scheme.Object; vs: Shape;
	BEGIN
		NEW(par); par.kind := name;
		obj := Ops.StringArg(ctxt, args);
		par.sym := Scheme.StringToSymbol(obj);
		Scheme.GetString(obj, 0, Scheme.StringLen(obj), par.name);
		Ops.CheckNull(ctxt, args);
		vs := FindShape(ctxt);
		IF vs # NIL THEN
			Append(vs, par)
		END
	END EvalName;

	PROCEDURE EvalRectInit (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR i: SIGNED32;
	BEGIN
		res := Scheme.NewVector(4, Scheme.nil);
		FOR i := 0 TO 3 DO Scheme.SetVectorAt(res, i, Ops.NumArg(ctxt, args)) END;
		Ops.CheckNull(ctxt, args)
	END EvalRectInit;

	PROCEDURE GetRectArg (ctxt: Scheme.Context; VAR args: Scheme.Object; VAR llx, lly, urx, ury: FLOAT32);
		VAR obj, elem: Scheme.Object; x: FLOAT64;
	BEGIN
		obj := Ops.Arg(ctxt, args);
		IF Scheme.IsVector(obj) & (Scheme.VectorLen(obj) = 4) THEN
			elem := Scheme.VectorAt(obj, 0);
			IF Scheme.IsNumber(elem) THEN Scheme.GetReal(elem, x); llx := SHORT(x)
			ELSE Scheme.Fail(ctxt, "rectangle element must be number", elem)
			END;
			elem := Scheme.VectorAt(obj, 1);
			IF Scheme.IsNumber(elem) THEN Scheme.GetReal(elem, x); lly := SHORT(x)
			ELSE Scheme.Fail(ctxt, "rectangle element must be number", elem)
			END;
			elem := Scheme.VectorAt(obj, 2);
			IF Scheme.IsNumber(elem) THEN Scheme.GetReal(elem, x); urx := SHORT(x)
			ELSE Scheme.Fail(ctxt, "rectangle element must be number", elem)
			END;
			elem := Scheme.VectorAt(obj, 3);
			IF Scheme.IsNumber(elem) THEN Scheme.GetReal(elem, x); ury := SHORT(x)
			ELSE Scheme.Fail(ctxt, "rectangle element must be number", elem)
			END
		ELSE Scheme.Fail(ctxt, "rectangle must be vector", obj)
		END
	END GetRectArg;

	PROCEDURE EvalRectApply (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR llx, lly, urx, ury: FLOAT32; m: GfxMatrix.Matrix;
	BEGIN
		GetRectArg(ctxt, args, llx, lly, urx, ury); Vinci.GetMatrixVal(ctxt, args, m); Ops.CheckNull(ctxt, args);
		GfxMatrix.ApplyToRect(m, llx, lly, urx, ury, llx, lly, urx, ury);
		res := Scheme.NewVector(4, Scheme.nil);
		Scheme.SetVectorAt(res, 0, Scheme.NewReal(llx));
		Scheme.SetVectorAt(res, 1, Scheme.NewReal(lly));
		Scheme.SetVectorAt(res, 2, Scheme.NewReal(urx));
		Scheme.SetVectorAt(res, 3, Scheme.NewReal(ury))
	END EvalRectApply;

	PROCEDURE EvalRectOverlap (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR llx0, lly0, urx0, ury0, llx1, lly1, urx1, ury1: FLOAT32;
	BEGIN
		GetRectArg(ctxt, args, llx0, lly0, urx0, ury0); GetRectArg(ctxt, args, llx1, lly1, urx1, ury1);
		Ops.CheckNull(ctxt, args);
		IF (llx0 < urx1) & (llx1 < urx0) & (lly0 < ury1) & (lly1 < ury0) THEN res := Scheme.true
		ELSE res := Scheme.false
		END
	END EvalRectOverlap;

	PROCEDURE EvalRectInside (ctxt: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR llx0, lly0, urx0, ury0, llx1, lly1, urx1, ury1: FLOAT32;
	BEGIN
		GetRectArg(ctxt, args, llx0, lly0, urx0, ury0); GetRectArg(ctxt, args, llx1, lly1, urx1, ury1);
		Ops.CheckNull(ctxt, args);
		IF (llx1 < llx0) & (urx0 < urx1) & (lly1 < lly0) & (ury0 < ury1) THEN res := Scheme.true
		ELSE res := Scheme.false
		END
	END EvalRectInside;

	PROCEDURE EvalRectContains (c: Scheme.Context; args: Scheme.Object; VAR res: Scheme.Object);
		VAR llx, lly, urx, ury, x, y: FLOAT32;
	BEGIN
		GetRectArg(c, args, llx, lly, urx, ury); x := SHORT(Ops.NumVal(c, args)); y := SHORT(Ops.NumVal(c, args));
		Ops.CheckNull(c, args);
		IF (llx <= x) & (x <= urx) & (lly <= y) & (y <= ury) THEN res := Scheme.true
		ELSE res := Scheme.false
		END
	END EvalRectContains;


BEGIN
	render := Scheme.NewSymbol("render"); drag := Scheme.NewSymbol("drag");
	matrix := Scheme.NewSymbol("matrix"); bbox := Scheme.NewSymbol("bbox");
	locate := Scheme.NewSymbol("locate");
	colorSym := Scheme.NewSymbol("color"); shapeSym := Scheme.NewSymbol("current-shape");
	quoteSym := Scheme.NewSymbol("quote");
	Scheme.InitPool(strPool);
	Vinci.PDef("shapes", "frame", EvalFrame); Vinci.PDef("shapes", "point", EvalPoint);
	Vinci.PDef("shapes", "matrix", EvalMatrix);
	Vinci.PDef("shapes", "component", EvalComponent);
	Vinci.PDef("shapes", "integer", EvalInteger); Vinci.PDef("shapes", "real", EvalReal);
	Vinci.PDef("shapes", "string", EvalString); Vinci.PDef("shapes", "bool", EvalBool);
	Vinci.PDef("shapes", "color", EvalColor); Vinci.PDef("shapes", "pen", EvalPen);
	Vinci.PDef("shapes", "name", EvalName);

	Vinci.PDef("rectangles", "init", EvalRectInit); Vinci.PDef("rectangles", "apply", EvalRectApply);
	Vinci.PDef("rectangles", "overlap?", EvalRectOverlap); Vinci.PDef("rectangles", "inside?", EvalRectInside);
	Vinci.PDef("rectangles", "contains?", EvalRectContains);
END VinciShapes.

VinciShapes.Integrate NGon.Shape ~
