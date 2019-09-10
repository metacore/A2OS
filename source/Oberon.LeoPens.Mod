(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoPens IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo Pen Objects

		Pens offer an additional level of abstraction compared to using Gfx contexts directly. Instead of
		setting context state variables directly, clients let a pen decide which attributes have to be modified
		and/or reset. Clients therefore don't have to keep values for all context attributes either but only
		need to reference a pen object instead. In addition, pens may implement graphical effects that
		cannot be done with contexts (e.g. arrow heads) and offer a way for doing partial updates of
		paths with correct handling of dash offsets etc. Many pens use other pens for doing the
		actual rendering, effecting in complex but very flexible pen hierarchies.

		The path model used for pen objects is a refinement of the Gfx path model. Entering a subpath
		requires an additional parameter 'bdist', exiting it an additional parameter 'edist'. 'bdist' and 'edist'
		let a client enter and exit a subpath at any control point (not only the first one) without messing up
		dash offsets, etc.. This may be useful when doing partial updates of a context (and is also used for
		some less common effects such as dashed arrow heads). 'bdist' is the accumulated length of all curves
		in the subpath preceding the point of entry, whereas 'edist' is the accumulated length
		of all curves following the point of exit. The following equation should always hold:

			bdist + length(rendered subpath) + edist = length(complete subpath)

		Two boolean flags in the pen object notify a client if distances are taken into account for
		rendering subpaths ('needDist') and if the pen can deal with non-zero distances at all ('zeroDistOnly').
	**)

	IMPORT
		Files, Objects, Display, Strings, Gadgets, Colors, Images, GfxMatrix, GfxPaths, Gfx, Leonardo;


	CONST
		CacheSize = 4;	(* number of temporary paths *)


	TYPE
		DistArray* = POINTER TO ARRAY OF FLOAT32;

		Methods* = POINTER TO MethodBlock;

		(** abstract pen object for drawing on a graphical context **)
		Pen* = POINTER TO PenDesc;
		PenDesc* = RECORD (Objects.ObjDesc)
			do*: Methods;	(** pen methods **)
			ctxt*: Gfx.Context;	(** graphic context the pen is connected to **)
			destructive*: BOOLEAN;	(** if set, the path destroys the path of its context **)
			needDist*: BOOLEAN;	(** if set, rendering is dependent on distance from begin/end of subpath **)
			zeroDistOnly*: BOOLEAN;	(** if set, only zero distances generate correct results **)
		END;

		MethodBlock* = RECORD
			(** begin and finish drawing with a pen on a context **)
			begin*: PROCEDURE (pen: Pen; ctxt: Gfx.Context);
			end*: PROCEDURE (pen: Pen);

			(** enter and exit subpath **)
			enter*: PROCEDURE (pen: Pen; x, y, dxi, dyi, bdist: FLOAT32);
			exit*: PROCEDURE (pen: Pen; dxo, dyo, edist: FLOAT32);

			(** append curves to current subpath **)
			line*: PROCEDURE (pen: Pen; x, y: FLOAT32);
			arc*: PROCEDURE (pen: Pen; x, y, x0, y0, x1, y1, x2, y2: FLOAT32);
			bezier*: PROCEDURE (pen: Pen; x, y, x1, y1, x2, y2: FLOAT32);

			(** append path structure to current path **)
			render*: PROCEDURE (pen: Pen; ctxt: Gfx.Context; VAR bdist, edist: ARRAY OF FLOAT32; n: SIGNED32);
		END;

		(** pens dealing with different line widths (abstract) **)
		WidePen* = POINTER TO WidePenDesc;
		WidePenDesc* = RECORD (PenDesc)
			width*: FLOAT32;	(** pen width **)
			limit*: FLOAT32;	(** style limit as defined by Gfx **)
			capstyle*: Gfx.CapStyle;	(** line cap style to use **)
			joinstyle*: Gfx.JoinStyle;	(** line join style to use **)
		END;

		(** pen recording the visited path **)
		Recorder* = POINTER TO RecorderDesc;
		RecorderDesc* = RECORD (PenDesc)
			path*: GfxPaths.Path;	(** recorded path **)
		END;

		(** basic stroke pen **)
		Stroker* = POINTER TO StrokerDesc;
		StrokerDesc* = RECORD (WidePenDesc)
			col*: Gfx.Color;	(** stroke color **)
			img*: Images.Image;	(** stroke pattern image **)
			px*, py*: FLOAT32;	(** stroke pattern pinpoint **)
			pat: Gfx.Pattern;
		END;

		(** basic fill pen **)
		Filler* = POINTER TO FillerDesc;
		FillerDesc* = RECORD (PenDesc)
			col*: Gfx.Color;	(** fill color **)
			img*: Images.Image;	(** fill pattern image **)
			px*, py*: FLOAT32;	(** fill pattern pinpoint **)
			pat: Gfx.Pattern;
		END;

		(** pen rendering dashes using another pen **)
		Dasher* = POINTER TO DasherDesc;
		DasherDesc* = RECORD (PenDesc)
			base*: Pen;	(** pen for rendering dashes **)
			on*, off*, onbak, offbak: ARRAY Gfx.MaxDashPatSize OF FLOAT32;	(** dash pattern **)
			len*, lenbak: SIGNED32;	(** number of entries in the dash pattern **)
			phase*, phasebak: FLOAT32;	(** offset into pattern **)
			continuous*: BOOLEAN;	(** unless true, each dash is treated like an independent subpath **)
		END;

		(** pen forwarding visited path to two pens **)
		Forker* = POINTER TO ForkerDesc;
		ForkerDesc* = RECORD (PenDesc)
			lower*, upper*: Pen;	(** pens that the visited path is forwarded to **)
			bdist, edist: DistArray;	(* distance offsets for each subpath *)
			n: SIGNED32;
		END;

		(** pen update notification (called by undoable action) **)
		UpdateMsg* = RECORD (Leonardo.BroadcastMsg)
			pen*: Pen;	(** all referencing shapes and pens should update themselves upon receiving this message **)
		END;


	VAR
		Default*: Pen;	(** default pen **)
		RecorderMethods, StrokerMethods, FillerMethods, DasherMethods, ForkerMethods: Methods;
		Path: ARRAY CacheSize OF GfxPaths.Path;	(* temporary path structures *)
		PathNo: SIGNED32;	(* number of path to allocate next *)


	(**--- Distance Arrays ---**)

	PROCEDURE Append* (VAR d: DistArray; pos: SIGNED32; val: FLOAT32);
		VAR t: DistArray; i: SIGNED32;
	BEGIN
		IF d = NIL THEN
			NEW(d, (pos DIV 32 + 1) * 32)
		ELSIF LEN(d^) <= pos THEN
			NEW(t, (pos DIV 32 + 1) * 32);
			i := 0; WHILE i < LEN(d^) DO t[i] := d[i]; INC(i) END;
			d := t
		END;
		d[pos] := val
	END Append;


	(**--- Pen Updates ---**)

	(** notify all objects in all figures of update to pen **)
	PROCEDURE Update* (pen: Pen);
		VAR um: UpdateMsg;
	BEGIN
		Objects.Stamp(um); um.pen := pen; Display.Broadcast(um)
	END Update;


	(**--- Pens ---**)

	PROCEDURE Copy* (VAR msg: Objects.CopyMsg; from, to: Pen);
	BEGIN
		to.handle := from.handle; to.do := from.do; to.ctxt := NIL;
		to.destructive := from.destructive; to.needDist := from.needDist; to.zeroDistOnly := from.zeroDistOnly
	END Copy;

	PROCEDURE Handle* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen: Pen;
	BEGIN
		pen := obj(Pen);
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Border")
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Border" THEN msg.class := Objects.Real; msg.x := 0; msg.res := 0 END
				END
			END
		ELSIF msg IS Objects.BindMsg THEN
			Gadgets.BindObj(pen, msg(Objects.BindMsg).lib)
		END
	END Handle;

	PROCEDURE Begin* (pen: Pen; ctxt: Gfx.Context);
	BEGIN
		pen.ctxt := ctxt
	END Begin;

	PROCEDURE End* (pen: Pen);
	BEGIN
		pen.ctxt := NIL
	END End;

	PROCEDURE Enter* (pen: Pen; x, y, dxi, dyi, bdist: FLOAT32);
	BEGIN
		Gfx.Enter(pen.ctxt, x, y, dxi, dyi)
	END Enter;

	PROCEDURE Exit* (pen: Pen; dxo, dyo, edist: FLOAT32);
	BEGIN
		Gfx.Exit(pen.ctxt, dxo, dyo)
	END Exit;

	PROCEDURE Line* (pen: Pen; x, y: FLOAT32);
	BEGIN
		Gfx.LineTo(pen.ctxt, x, y)
	END Line;

	PROCEDURE Arc* (pen: Pen; x, y, x0, y0, x1, y1, x2, y2: FLOAT32);
	BEGIN
		Gfx.ArcTo(pen.ctxt, x, y, x0, y0, x1, y1, x2, y2)
	END Arc;

	PROCEDURE Bezier* (pen: Pen; x, y, x1, y1, x2, y2: FLOAT32);
	BEGIN
		Gfx.BezierTo(pen.ctxt, x, y, x1, y1, x2, y2)
	END Bezier;

	PROCEDURE GetTempPath* (VAR path: GfxPaths.Path);
	BEGIN
		IF PathNo = CacheSize THEN
			NEW(path)
		ELSE
			IF Path[PathNo] = NIL THEN NEW(Path[PathNo]) END;
			path := Path[PathNo];
			INC(PathNo)
		END
	END GetTempPath;

	PROCEDURE ReleaseTempPath* (path: GfxPaths.Path);
	BEGIN
		IF path = Path[PathNo-1] THEN DEC(PathNo) END
	END ReleaseTempPath;

	PROCEDURE RenderPath* (pen: Pen; ctxt: Gfx.Context; VAR bdist, edist: ARRAY OF FLOAT32; n: SIGNED32);
		VAR path: GfxPaths.Path; inv: GfxMatrix.Matrix; s: GfxPaths.Scanner; i: SIGNED32;
	BEGIN
		path := ctxt.path;
		IF pen.destructive THEN
			GetTempPath(path); GfxPaths.Copy(ctxt.path, path)
		END;
		GfxMatrix.Invert(ctxt.ctm, inv); GfxPaths.Apply(path, inv);
		pen.do.begin(pen, ctxt);
		GfxPaths.Open(s, path, 0); i := 0;
		WHILE s.elem = GfxPaths.Enter DO
			pen.do.enter(pen, s.x, s.y, s.dx, s.dy, bdist[i]);
			GfxPaths.Scan(s);
			WHILE s.elem IN {GfxPaths.Line, GfxPaths.Arc, GfxPaths.Bezier} DO
				IF s.elem = GfxPaths.Line THEN
					pen.do.line(pen, s.x, s.y)
				ELSIF s.elem = GfxPaths.Arc THEN
					pen.do.arc(pen, s.x, s.y, s.x0, s.y0, s.x1, s.y1, s.x2, s.y2)
				ELSE
					pen.do.bezier(pen, s.x, s.y, s.x1, s.y1, s.x2, s.y2)
				END;
				GfxPaths.Scan(s)
			END;
			IF s.elem = GfxPaths.Exit THEN
				pen.do.exit(pen, s.dx, s.dy, edist[i])
			END;
			INC(i)
		END;
		pen.do.end(pen);
		IF pen.destructive THEN
			ReleaseTempPath(path)
		END
	END RenderPath;


	(**--- Wide Pens ---**)

	PROCEDURE CopyWidePen* (VAR msg: Objects.CopyMsg; from, to: WidePen);
	BEGIN
		Copy(msg, from, to);
		to.width := from.width; to.capstyle := from.capstyle; to.joinstyle := from.joinstyle; to.limit := from.limit
	END CopyWidePen;

	PROCEDURE WidePenAttr* (pen: WidePen; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Width"); msg.Enum("Limit"); msg.Enum("CapStyle"); msg.Enum("JoinStyle");
			Handle(pen, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Width" THEN msg.class := Objects.Real; msg.x := pen.width; msg.res := 0
			ELSIF msg.name = "Limit" THEN msg.class := Objects.Real; msg.x := pen.limit; msg.res := 0
			ELSIF msg.name = "Border" THEN msg.class := Objects.Real; msg.x := 0.5*pen.width * pen.limit; msg.res := 0
			ELSIF msg.name = "CapStyle" THEN msg.class := Objects.Int; msg.i := pen.capstyle; msg.res := 0
			ELSIF msg.name = "JoinStyle" THEN msg.class := Objects.Int; msg.i := pen.joinstyle; msg.res := 0
			ELSE Handle(pen, msg)
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "Width" THEN
				IF msg.class = Objects.Int THEN pen.width := msg.i; msg.res := 0
				ELSIF msg.class = Objects.Real THEN pen.width := msg.x; msg.res := 0
				ELSIF msg.class = Objects.LongReal THEN pen.width := SHORT(msg.y); msg.res := 0
				END
			ELSIF msg.name = "Limit" THEN
				IF msg.class = Objects.Int THEN pen.limit := msg.i; msg.res := 0
				ELSIF msg.class = Objects.Real THEN pen.limit := msg.x; msg.res := 0
				ELSIF msg.class = Objects.LongReal THEN pen.limit := SHORT(msg.y); msg.res := 0
				END
			ELSIF msg.name = "CapStyle" THEN
				IF (msg.class = Objects.Int) & (Gfx.NoCap <= msg.i) & (msg.i <= Gfx.RoundCap) THEN
					pen.capstyle := SHORT(SHORT(msg.i)); msg.res := 0
				END
			ELSIF msg.name = "JoinStyle" THEN
				IF (msg.class = Objects.Int) & (Gfx.NoJoin <= msg.i) & (msg.i <= Gfx.RoundJoin) THEN
					pen.joinstyle := SHORT(SHORT(msg.i)); msg.res := 0
				END
			ELSE
				Handle(pen, msg)
			END
		END
	END WidePenAttr;

	PROCEDURE WriteWidePen* (pen: WidePen; VAR r: Files.Rider);
	BEGIN
		Files.WriteNum(r, 1);
		Files.WriteReal(r, pen.width); Files.WriteReal(r, pen.limit);
		Files.Write(r, pen.capstyle); Files.Write(r, pen.joinstyle)
	END WriteWidePen;

	PROCEDURE ReadWidePen* (pen: WidePen; VAR r: Files.Rider);
		VAR ver: SIGNED32;
	BEGIN
		Files.ReadNum(r, ver);
		Files.ReadReal(r, pen.width); Files.ReadReal(r, pen.limit);
		Files.Read(r, pen.capstyle); Files.Read(r, pen.joinstyle)
	END ReadWidePen;


	(**--- Recorders ---**)

	PROCEDURE HandleRecorder* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen, copy: Recorder; ver: SIGNED32;
	BEGIN
		pen := obj(Recorder);
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN msg.class := Objects.String; msg.s := "LeoPens.NewRecorder"; msg.res := 0
				ELSE Handle(pen, msg)
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # pen.stamp THEN
					NEW(copy); pen.dlink := copy; pen.stamp := msg.stamp;
					Copy(msg, pen, copy);
					copy.path := NIL
				END;
				msg.obj := pen.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver)
				END
			END
		ELSE
			Handle(pen, msg)
		END
	END HandleRecorder;

	PROCEDURE InitRecorder* (pen: Recorder);
	BEGIN
		pen.handle := HandleRecorder; pen.do := RecorderMethods;
		pen.destructive := FALSE; pen.needDist := FALSE; pen.zeroDistOnly := FALSE
	END InitRecorder;

	PROCEDURE NewRecorder*;
		VAR pen: Recorder;
	BEGIN
		NEW(pen); InitRecorder(pen);
		Objects.NewObj := pen
	END NewRecorder;

	PROCEDURE BeginRecorder (pen: Pen; ctxt: Gfx.Context);
		VAR rec: Recorder;
	BEGIN
		rec := pen(Recorder);
		Begin(rec, ctxt);
		IF rec.path = NIL THEN
			NEW(rec.path)
		END;
		GfxPaths.Clear(rec.path)
	END BeginRecorder;

	PROCEDURE EnterRecorder (pen: Pen; x, y, dxi, dyi, bdist: FLOAT32);
	BEGIN
		GfxPaths.AddEnter(pen(Recorder).path, x, y, dxi, dyi)
	END EnterRecorder;

	PROCEDURE ExitRecorder (pen: Pen; dxo, dyo, edist: FLOAT32);
	BEGIN
		GfxPaths.AddExit(pen(Recorder).path, dxo, dyo)
	END ExitRecorder;

	PROCEDURE RecordLine (pen: Pen; x, y: FLOAT32);
	BEGIN
		GfxPaths.AddLine(pen(Recorder).path, x, y)
	END RecordLine;

	PROCEDURE RecordArc (pen: Pen; x, y, x0, y0, x1, y1, x2, y2: FLOAT32);
	BEGIN
		GfxPaths.AddArc(pen(Recorder).path, x, y, x0, y0, x1, y1, x2, y2)
	END RecordArc;

	PROCEDURE RecordBezier (pen: Pen; x, y, x1, y1, x2, y2: FLOAT32);
	BEGIN
		GfxPaths.AddBezier(pen(Recorder).path, x, y, x1, y1, x2, y2)
	END RecordBezier;

	PROCEDURE RecordPath (pen: Pen; ctxt: Gfx.Context; VAR bdist, edist: ARRAY OF FLOAT32; n: SIGNED32);
	BEGIN
		GfxPaths.Copy(ctxt.path, pen(Recorder).path)
	END RecordPath;

	PROCEDURE InitRecorders;
	BEGIN
		NEW(RecorderMethods);
		RecorderMethods.begin := BeginRecorder; RecorderMethods.end := End;
		RecorderMethods.enter := EnterRecorder; RecorderMethods.exit := ExitRecorder;
		RecorderMethods.line := RecordLine; RecorderMethods.arc := RecordArc; RecorderMethods.bezier := RecordBezier;
		RecorderMethods.render := RecordPath
	END InitRecorders;


	(**--- Stroker ---**)

	PROCEDURE HandleStroker* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen, copy: Stroker; ver: SIGNED32; ch: CHAR;
	BEGIN
		pen := obj(Stroker);
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Color"); msg.Enum("Red"); msg.Enum("Green"); msg.Enum("Blue");
					msg.Enum("PinX"); msg.Enum("PinY");
					WidePenAttr(pen, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoPens.NewStroker"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Stroker"; msg.res := 0
					ELSIF msg.name = "Color" THEN
						msg.class := Objects.Int; msg.res := 0;
						msg.i := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, pen.col.r, pen.col.g, pen.col.b)
					ELSIF msg.name = "Red" THEN msg.class := Objects.Int; msg.i := pen.col.r; msg.res := 0
					ELSIF msg.name = "Green" THEN msg.class := Objects.Int; msg.i := pen.col.g; msg.res := 0
					ELSIF msg.name = "Blue" THEN msg.class := Objects.Int; msg.i := pen.col.b; msg.res := 0
					ELSIF msg.name = "PinX" THEN msg.class := Objects.Real; msg.x := pen.px; msg.res := 0
					ELSIF msg.name = "PinY" THEN msg.class := Objects.Real; msg.x := pen.py; msg.res := 0
					ELSE WidePenAttr(pen, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Color" THEN
						IF msg.class = Objects.Int THEN Display.GetColor(msg.i, pen.col.r, pen.col.g, pen.col.b); msg.res := 0 END
					ELSIF msg.name = "Red" THEN
						IF msg.class = Objects.Int THEN pen.col.r := SHORT(msg.i MOD 100H); msg.res := 0 END
					ELSIF msg.name = "Green" THEN
						IF msg.class = Objects.Int THEN pen.col.g := SHORT(msg.i MOD 100H); msg.res := 0 END
					ELSIF msg.name = "Blue" THEN
						IF msg.class = Objects.Int THEN pen.col.b := SHORT(msg.i MOD 100H); msg.res := 0 END
					ELSIF msg.name = "PinX" THEN
						IF msg.class = Objects.Int THEN pen.px := msg.i; msg.res := 0
						ELSIF msg.class = Objects.Real THEN pen.px := msg.x; msg.res := 0
						ELSIF msg.class = Objects.LongReal THEN pen.px := SHORT(msg.y); msg.res := 0
						END
					ELSIF msg.name = "PinY" THEN
						IF msg.class = Objects.Int THEN pen.py := msg.i; msg.res := 0
						ELSIF msg.class = Objects.Real THEN pen.py := msg.x; msg.res := 0
						ELSIF msg.class = Objects.LongReal THEN pen.py := SHORT(msg.y); msg.res := 0
						END
					ELSE
						WidePenAttr(pen, msg)
					END
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Image")
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Image" THEN msg.obj := pen.img; msg.res := 0 END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Image" THEN
						IF msg.obj = NIL THEN pen.img := NIL; msg.res := 0
						ELSIF msg.obj IS Images.Image THEN pen.img := msg.obj(Images.Image); msg.res := 0
						END
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # pen.stamp THEN
					NEW(copy); pen.dlink := copy; pen.stamp := msg.stamp;
					CopyWidePen(msg, pen, copy);
					copy.col := pen.col; copy.px := pen.px; copy.py := pen.py; copy.img := pen.img
				END;
				msg.obj := pen.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.Write(msg.R, CHR(pen.col.r)); Files.Write(msg.R, CHR(pen.col.g)); Files.Write(msg.R, CHR(pen.col.b));
					WriteWidePen(pen, msg.R);
					Gadgets.WriteRef(msg.R, pen.lib, pen.img);
					IF pen.img # NIL THEN
						Files.WriteReal(msg.R, pen.px); Files.WriteReal(msg.R, pen.py)
					END
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.Read(msg.R, ch); pen.col.r := ORD(ch);
					Files.Read(msg.R, ch); pen.col.g := ORD(ch);
					Files.Read(msg.R, ch); pen.col.b := ORD(ch);
					ReadWidePen(pen, msg.R);
					Gadgets.ReadRef(msg.R, pen.lib, obj);
					IF (obj # NIL) & (obj IS Images.Image) THEN
						pen.img := obj(Images.Image);
						Files.ReadReal(msg.R, pen.px); Files.ReadReal(msg.R, pen.py)
					END
				END
			END
		ELSE
			Handle(pen, msg)
		END
	END HandleStroker;

	PROCEDURE InitStroker* (pen: Stroker; col: Gfx.Color; width: FLOAT32);
	BEGIN
		pen.handle := HandleStroker; pen.do := StrokerMethods;
		pen.destructive := FALSE; pen.needDist := FALSE; pen.zeroDistOnly := FALSE;
		pen.col := col; pen.img := NIL;
		pen.width := width; pen.limit := 5; pen.capstyle := Gfx.DefaultCap; pen.joinstyle := Gfx.DefaultJoin
	END InitStroker;

	PROCEDURE NewStroker*;
		VAR pen: Stroker;
	BEGIN
		NEW(pen); InitStroker(pen, Gfx.Black, 1);
		Objects.NewObj := pen
	END NewStroker;

	PROCEDURE UseStroker (pen: Stroker; ctxt: Gfx.Context);
	BEGIN
		Gfx.SetStrokeColor(ctxt, pen.col);
		IF pen.pat = NIL THEN
			IF pen.img # NIL THEN pen.pat := Gfx.NewPattern(ctxt, pen.img, pen.px, pen.py) END
		ELSIF pen.img = NIL THEN
			pen.pat := NIL
		ELSIF (pen.img # pen.pat.img) OR (pen.px # pen.pat.px) OR (pen.py # pen.pat.py) THEN
			pen.pat := Gfx.NewPattern(ctxt, pen.img, pen.px, pen.py)
		END;
		IF pen.pat # ctxt.strokePat THEN
			Gfx.SetStrokePattern(ctxt, pen.pat)
		END;
		Gfx.SetLineWidth(ctxt, pen.width); Gfx.SetStyleLimit(ctxt, pen.limit);
		Gfx.SetCapStyle(ctxt, pen.capstyle); Gfx.SetJoinStyle(ctxt, pen.joinstyle);
	END UseStroker;

	PROCEDURE BeginStroker (pen: Pen; ctxt: Gfx.Context);
		VAR p: Stroker;
	BEGIN
		p := pen(Stroker);
		Begin(p, ctxt);
		UseStroker(p, ctxt);
		Gfx.Begin(ctxt, {Gfx.Stroke})
	END BeginStroker;

	PROCEDURE EndStroker (pen: Pen);
	BEGIN
		Gfx.End(pen.ctxt);
		End(pen)
	END EndStroker;

	PROCEDURE RenderStroker (pen: Pen; ctxt: Gfx.Context; VAR bdist, edist: ARRAY OF FLOAT32; n: SIGNED32);
		VAR p: Stroker;
	BEGIN
		p := pen(Stroker);
		UseStroker(p, ctxt);
		Gfx.Render(ctxt, {Gfx.Stroke})
	END RenderStroker;

	PROCEDURE InitStrokers;
	BEGIN
		NEW(StrokerMethods);
		StrokerMethods.begin := BeginStroker; StrokerMethods.end := EndStroker;
		StrokerMethods.enter := Enter; StrokerMethods.exit := Exit;
		StrokerMethods.line := Line; StrokerMethods.arc := Arc; StrokerMethods.bezier := Bezier;
		StrokerMethods.render := RenderStroker
	END InitStrokers;


	(**--- Fillers ---**)

	PROCEDURE HandleFiller* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen, copy: Filler; ver: SIGNED32; ch: CHAR;
	BEGIN
		pen := obj(Filler);
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Color"); msg.Enum("Red"); msg.Enum("Green"); msg.Enum("Blue");
					msg.Enum("PinX"); msg.Enum("PinY");
					Handle(pen, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoPens.NewFiller"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Filler"; msg.res := 0
					ELSIF msg.name = "Color" THEN
						msg.class := Objects.Int; msg.res := 0;
						msg.i := Colors.Match(Colors.DisplayIndex, Colors.DisplayBits, pen.col.r, pen.col.g, pen.col.b)
					ELSIF msg.name = "Red" THEN msg.class := Objects.Int; msg.i := pen.col.r; msg.res := 0
					ELSIF msg.name = "Green" THEN msg.class := Objects.Int; msg.i := pen.col.g; msg.res := 0
					ELSIF msg.name = "Blue" THEN msg.class := Objects.Int; msg.i := pen.col.b; msg.res := 0
					ELSIF msg.name = "PinX" THEN msg.class := Objects.Real; msg.x := pen.px; msg.res := 0
					ELSIF msg.name = "PinY" THEN msg.class := Objects.Real; msg.x := pen.py; msg.res := 0
					ELSE Handle(pen, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Color" THEN
						IF msg.class = Objects.Int THEN Display.GetColor(msg.i, pen.col.r, pen.col.g, pen.col.b); msg.res := 0 END
					ELSIF msg.name = "Red" THEN
						IF msg.class = Objects.Int THEN pen.col.r := SHORT(msg.i MOD 100H); msg.res := 0 END
					ELSIF msg.name = "Green" THEN
						IF msg.class = Objects.Int THEN pen.col.g := SHORT(msg.i MOD 100H); msg.res := 0 END
					ELSIF msg.name = "Blue" THEN
						IF msg.class = Objects.Int THEN pen.col.b := SHORT(msg.i MOD 100H); msg.res := 0 END
					ELSIF msg.name = "PinX" THEN
						IF msg.class = Objects.Int THEN pen.px := msg.i; msg.res := 0
						ELSIF msg.class = Objects.Real THEN pen.px := msg.x; msg.res := 0
						ELSIF msg.class = Objects.LongReal THEN pen.px := SHORT(msg.y); msg.res := 0
						END
					ELSIF msg.name = "PinY" THEN
						IF msg.class = Objects.Int THEN pen.py := msg.i; msg.res := 0
						ELSIF msg.class = Objects.Real THEN pen.py := msg.x; msg.res := 0
						ELSIF msg.class = Objects.LongReal THEN pen.py := SHORT(msg.y); msg.res := 0
						END
					ELSE
						Handle(pen, msg)
					END
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Image")
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Image" THEN msg.obj := pen.img; msg.res := 0 END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Image" THEN
						IF msg.obj = NIL THEN pen.img := NIL; msg.res := 0
						ELSIF msg.obj IS Images.Image THEN pen.img := msg.obj(Images.Image); msg.res := 0
						END
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # pen.stamp THEN
					NEW(copy); pen.dlink := copy; pen.stamp := msg.stamp;
					Copy(msg, pen, copy);
					copy.col := pen.col; copy.px := pen.px; copy.py := pen.py; copy.img := pen.img
				END;
				msg.obj := pen.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Files.Write(msg.R, CHR(pen.col.r)); Files.Write(msg.R, CHR(pen.col.g)); Files.Write(msg.R, CHR(pen.col.b));
					Gadgets.WriteRef(msg.R, pen.lib, pen.img);
					IF pen.img # NIL THEN
						Files.WriteReal(msg.R, pen.px); Files.WriteReal(msg.R, pen.py)
					END
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.Read(msg.R, ch); pen.col.r := ORD(ch);
					Files.Read(msg.R, ch); pen.col.g := ORD(ch);
					Files.Read(msg.R, ch); pen.col.b := ORD(ch);
					Gadgets.ReadRef(msg.R, pen.lib, obj);
					IF (obj # NIL) & (obj IS Images.Image) THEN
						pen.img := obj(Images.Image);
						Files.ReadReal(msg.R, pen.px); Files.ReadReal(msg.R, pen.py)
					END
				END
			END
		ELSE
			Handle(pen, msg)
		END
	END HandleFiller;

	PROCEDURE InitFiller* (pen: Filler; col: Gfx.Color);
	BEGIN
		pen.handle := HandleFiller; pen.do := FillerMethods; pen.col := col;
		pen.destructive := FALSE; pen.needDist := FALSE; pen.zeroDistOnly := TRUE
	END InitFiller;

	PROCEDURE NewFiller*;
		VAR pen: Filler;
	BEGIN
		NEW(pen); InitFiller(pen, Gfx.White);
		Objects.NewObj := pen
	END NewFiller;

	PROCEDURE UseFiller (pen: Filler; ctxt: Gfx.Context);
	BEGIN
		Gfx.SetFillColor(ctxt, pen.col);
		IF pen.pat = NIL THEN
			IF pen.img # NIL THEN pen.pat := Gfx.NewPattern(ctxt, pen.img, pen.px, pen.py) END
		ELSIF pen.img = NIL THEN
			pen.pat := NIL
		ELSIF (pen.img # pen.pat.img) OR (pen.px # pen.pat.px) OR (pen.py # pen.pat.py) THEN
			pen.pat := Gfx.NewPattern(ctxt, pen.img, pen.px, pen.py)
		END;
		IF pen.pat # ctxt.fillPat THEN
			Gfx.SetFillPattern(ctxt, pen.pat)
		END
	END UseFiller;

	PROCEDURE BeginFiller (pen: Pen; ctxt: Gfx.Context);
		VAR p: Filler;
	BEGIN
		p := pen(Filler);
		Begin(p, ctxt);
		UseFiller(p, ctxt);
		Gfx.Begin(ctxt, {Gfx.Fill})
	END BeginFiller;

	PROCEDURE EndFiller (pen: Pen);
	BEGIN
		Gfx.End(pen.ctxt);
		End(pen)
	END EndFiller;

	PROCEDURE RenderFiller (pen: Pen; ctxt: Gfx.Context; VAR bdist, edist: ARRAY OF FLOAT32; n: SIGNED32);
		VAR p: Filler;
	BEGIN
		p := pen(Filler);
		UseFiller(p, ctxt);
		Gfx.Render(ctxt, {Gfx.Fill})
	END RenderFiller;

	PROCEDURE InitFillers;
	BEGIN
		NEW(FillerMethods);
		FillerMethods.begin := BeginFiller; FillerMethods.end := EndFiller;
		FillerMethods.enter := Enter; FillerMethods.exit := Exit;
		FillerMethods.line := Line; FillerMethods.arc := Arc; FillerMethods.bezier := Bezier;
		FillerMethods.render := RenderFiller
	END InitFillers;


	(**--- Dasher ---**)

	PROCEDURE HandleDasher* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen, copy: Dasher; n, ver: SIGNED32;
	BEGIN
		pen := obj(Dasher);
		IF msg IS UpdateMsg THEN
			WITH msg: UpdateMsg DO
				IF msg.pen = pen.base THEN
					Update(pen)
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Length"); msg.Enum("Phase"); msg.Enum("Continuous");
					Handle(pen, msg)
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoPens.NewDasher"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Dasher"; msg.res := 0
					ELSIF msg.name = "Length" THEN msg.class := Objects.Int; msg.i := pen.len; msg.res := 0
					ELSIF msg.name = "Phase" THEN msg.class := Objects.Real; msg.x := pen.phase; msg.res := 0
					ELSIF msg.name = "Continuous" THEN msg.class := Objects.Bool; msg.b := pen.continuous; msg.res := 0
					ELSIF msg.name = "Border" THEN pen.base.handle(pen.base, msg)
					ELSIF (msg.name[0] = "O") & (msg.name[1] = "n") & (msg.name[3] = 0X) THEN
						n := ORD(msg.name[2]) - ORD("0");
						IF (0 <= n) & (n < Gfx.MaxDashPatSize) THEN msg.class := Objects.Real; msg.x := pen.on[n]; msg.res := 0 END
					ELSIF (msg.name[0] = "O") & (msg.name[1] = "f") & (msg.name[2] = "f") & (msg.name[4] = 0X) THEN
						n := ORD(msg.name[3]) - ORD("0");
						IF (0 <= n) & (n < Gfx.MaxDashPatSize) THEN msg.class := Objects.Real; msg.x := pen.off[n]; msg.res := 0 END
					ELSE Handle(pen, msg)
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Length" THEN
						IF (msg.class = Objects.Int) & (0 <= msg.i) & (msg.i < Gfx.MaxDashPatSize) THEN
							WHILE pen.len < msg.i DO
								pen.on[pen.len] := 0; pen.off[pen.len] := 0; INC(pen.len)
							END;
							pen.len := msg.i; msg.res := 0	(* msg.i could be < pen.len *)
						END
					ELSIF msg.name = "Phase" THEN
						IF msg.class = Objects.Int THEN pen.phase := msg.i; msg.res := 0
						ELSIF msg.class = Objects.Real THEN pen.phase := msg.x; msg.res := 0
						ELSIF msg.class = Objects.LongReal THEN pen.phase := SHORT(msg.y); msg.res := 0
						END
					ELSIF msg.name = "Continuous" THEN
						IF msg.class = Objects.Bool THEN pen.continuous := msg.b; msg.res := 0 END
					ELSIF (msg.name[0] = "O") & (msg.name[1] = "n") & (msg.name[3] = 0X) THEN
						n := ORD(msg.name[2]) - ORD("0");
						IF (0 <= n) & (n < Gfx.MaxDashPatSize) THEN
							IF msg.class = Objects.Int THEN pen.on[n] := msg.i; msg.res := 0
							ELSIF msg.class = Objects.Real THEN pen.on[n] := msg.x; msg.res := 0
							ELSIF msg.class = Objects.LongReal THEN pen.on[n] := SHORT(msg.y); msg.res := 0
							ELSIF msg.class = Objects.String THEN Strings.StrToReal(msg.s, msg.y); pen.on[n] := SHORT(msg.y); msg.res := 0
							END
						END
					ELSIF (msg.name[0] = "O") & (msg.name[1] = "f") & (msg.name[2] = "f") & (msg.name[4] = 0X) THEN
						n := ORD(msg.name[3]) - ORD("0");
						IF (0 <= n) & (n < Gfx.MaxDashPatSize) THEN
							IF msg.class = Objects.Int THEN pen.off[n] := msg.i; msg.res := 0
							ELSIF msg.class = Objects.Real THEN pen.off[n] := msg.x; msg.res := 0
							ELSIF msg.class = Objects.LongReal THEN pen.off[n] := SHORT(msg.y); msg.res := 0
							ELSIF msg.class = Objects.String THEN Strings.StrToReal(msg.s, msg.y); pen.off[n] := SHORT(msg.y); msg.res := 0
							END
						END
					ELSE
						Handle(pen, msg)
					END
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Base")
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Base" THEN msg.obj := pen.base; msg.res := 0 END
				ELSIF msg.id = Objects.set THEN
					IF (msg.name = "Base") & (msg.obj # NIL) & (msg.obj IS Pen) THEN
						pen.base := msg.obj(Pen); msg.res := 0;
						pen.destructive := ~(pen.base IS Stroker); pen.zeroDistOnly := pen.base.zeroDistOnly
					END
				END
			END
		ELSIF msg IS Objects.BindMsg THEN
			pen.base.handle(pen.base, msg);
			Handle(pen, msg)
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # pen.stamp THEN
					NEW(copy); pen.dlink := copy; pen.stamp := msg.stamp;
					Copy(msg, pen, copy);
					obj := Gadgets.CopyPtr(msg, pen.base);
					IF (obj = NIL) OR ~(obj IS Pen) THEN NewStroker; obj := Objects.NewObj END;
					copy.base := obj(Pen);
					copy.on := pen.on; copy.off := pen.off; copy.len := pen.len;
					copy.phase := pen.phase; copy.continuous := pen.continuous
				END;
				msg.obj := pen.dlink
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Gadgets.WriteRef(msg.R, pen.lib, pen.base);
					Files.WriteNum(msg.R, pen.len);
					n := 0;
					WHILE n < pen.len DO
						Files.WriteReal(msg.R, pen.on[n]); Files.WriteReal(msg.R, pen.off[n]); INC(n)
					END;
					Files.WriteReal(msg.R, pen.phase);
					Files.WriteBool(msg.R, pen.continuous)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Gadgets.ReadRef(msg.R, pen.lib, obj);
					IF (obj = NIL) OR ~(obj IS Pen) THEN NewStroker; obj := Objects.NewObj END;
					pen.base := obj(Pen);
					pen.destructive := ~(pen.base IS Stroker); pen.zeroDistOnly := pen.base.zeroDistOnly;
					Files.ReadNum(msg.R, pen.len);
					n := 0;
					WHILE n < pen.len DO
						Files.ReadReal(msg.R, pen.on[n]); Files.ReadReal(msg.R, pen.off[n]); INC(n)
					END;
					Files.ReadReal(msg.R, pen.phase);
					Files.ReadBool(msg.R, pen.continuous)
				END
			END
		ELSE
			Handle(pen, msg)
		END
	END HandleDasher;

	PROCEDURE InitDasher* (pen: Dasher; base: Pen; on, off: ARRAY OF FLOAT32; len: SIGNED32);
	BEGIN
		ASSERT(base # NIL, 100);
		pen.handle := HandleDasher; pen.do := DasherMethods;
		pen.destructive := ~(base IS Stroker); pen.needDist := TRUE; pen.zeroDistOnly := base.zeroDistOnly;
		pen.base := base; pen.len := len; pen.phase := 0; pen.continuous := FALSE;
		WHILE len > 0 DO
			DEC(len); pen.on[len] := on[len]; pen.off[len] := off[len]
		END
	END InitDasher;

	PROCEDURE NewDasher*;
		VAR pen: Dasher; on: ARRAY 1 OF FLOAT32;
	BEGIN
		NEW(pen); on[0] := 10; InitDasher(pen, Default, on, on, 1);
		Objects.NewObj := pen
	END NewDasher;

	PROCEDURE BeginDasher (pen: Pen; ctxt: Gfx.Context);
		VAR p: Dasher; n: SIGNED32;
	BEGIN
		p := pen(Dasher);
		Begin(p, ctxt);
		n := 0; p.lenbak := ctxt.dashPatLen; p.phasebak := ctxt.dashPhase;
		WHILE n < p.lenbak DO
			p.onbak[n] := ctxt.dashPatOn[n]; p.offbak[n] := ctxt.dashPatOff[n]; INC(n)
		END
	END BeginDasher;

	PROCEDURE EndDasher (pen: Pen);
		VAR p: Dasher;
	BEGIN
		p := pen(Dasher);
		Gfx.SetDashPattern(p.ctxt, p.onbak, p.offbak, p.lenbak, p.phasebak);
		End(p)
	END EndDasher;

	PROCEDURE DashSubpath (pen: Pen; bdist, edist: FLOAT32);
		VAR
			p: Dasher; ctxt: Gfx.Context; base: Pen; width, len, beg, end, next: FLOAT32; idx: SIGNED32;
			inv: GfxMatrix.Matrix; path: GfxPaths.Path; s: GfxPaths.Scanner;
	BEGIN
		p := pen(Dasher); ctxt := p.ctxt; base := p.base;
		width := ctxt.lineWidth;
		Gfx.SetLineWidth(ctxt, 0);
		len := GfxPaths.Length(ctxt.path, 1);	(* calculate complete length, including dash breaks *)
		Gfx.Outline(ctxt);	(* path is flattened at the same time *)
		IF ~GfxPaths.Empty(ctxt.path) THEN
			ctxt.cam := GfxMatrix.Identity;	(* calculate offsets in user space instead of device space *)
			Gfx.GetDashOffsets(ctxt, bdist, beg, end, next, idx);
			GfxMatrix.Invert(ctxt.ctm, inv);
			GfxPaths.Apply(ctxt.path, inv);	(* transform path back to user space *)
			GfxMatrix.ApplyToDist(inv, len, len);
			Gfx.SetDashPattern(ctxt, p.on, p.off, 0, 0);	(* empty pattern *)
			IF base.destructive THEN GetTempPath(path); GfxPaths.Copy(ctxt.path, path)
			ELSE path := ctxt.path
			END;
			GfxPaths.Open(s, path, 0);
			base.do.begin(base, ctxt);
			IF end <= bdist THEN	(* subpath starts between dashes *)
				base.do.enter(base, s.x, s.y, s.dx, s.dy, next);
				len := len - (next - bdist);
				idx := (idx+1) MOD p.len;
				beg := next; end := beg + p.on[idx]; next := end + p.off[idx]
			ELSIF p.continuous THEN
				base.do.enter(base, s.x, s.y, s.dx, s.dy, bdist);
				beg := bdist
			ELSE
				base.do.enter(base, s.x, s.y, s.dx, s.dy, bdist - beg);
				beg := bdist
			END;
			GfxPaths.Scan(s);
			WHILE s.elem # GfxPaths.Stop DO
				CASE s.elem OF
				| GfxPaths.Enter:
					IF p.continuous THEN base.do.enter(base, s.x, s.y, s.dx, s.dy, beg)
					ELSE base.do.enter(base, s.x, s.y, s.dx, s.dy, 0)
					END
				| GfxPaths.Line:
					base.do.line(base, s.x, s.y)
				| GfxPaths.Exit:
					len := len - (end - beg);
					IF len > 0 THEN	(* dash end comes before end of subpath *)
						IF p.continuous THEN base.do.exit(base, s.dx, s.dy, len + edist)
						ELSE base.do.exit(base, s.dx, s.dy, 0)
						END;
						len := len - (next - end);
						idx := (idx+1) MOD p.len;
						beg := next; end := beg + p.on[idx]; next := end + p.off[idx]
					ELSIF p.continuous THEN
						base.do.exit(base, s.dx, s.dy, edist)
					ELSE
						base.do.exit(base, s.dx, s.dy, -len)
					END
				END;
				GfxPaths.Scan(s)
			END;
			base.do.end(base);
			IF path # ctxt.path THEN
				ReleaseTempPath(path)
			END
		END;
		Gfx.SetLineWidth(ctxt, width)
	END DashSubpath;

	PROCEDURE EnterDasher (pen: Pen; x, y, dxi, dyi, bdist: FLOAT32);
		VAR p: Dasher; base: Pen; ctxt: Gfx.Context;
	BEGIN
		p := pen(Dasher); base := p.base; ctxt := p.ctxt;
		Gfx.SetDashPattern(ctxt, p.on, p.off, p.len, p.phase + bdist);
		IF base IS Stroker THEN base.do.begin(base, ctxt)	(* render directly *)
		ELSE Gfx.Begin(ctxt, {Gfx.Record})	(* record first *)
		END;
		Gfx.Enter(p.ctxt, x, y, dxi, dyi)
	END EnterDasher;

	PROCEDURE ExitDasher (pen: Pen; dxo, dyo, edist: FLOAT32);
		VAR p: Dasher; base: Pen;
	BEGIN
		p := pen(Dasher); base := p.base;
		Gfx.Exit(p.ctxt, dxo, dyo);
		IF base IS Stroker THEN
			base.do.end(base)
		ELSE
			Gfx.End(p.ctxt);
			DashSubpath(p, p.ctxt.dashPhase - p.phase, edist)
		END
	END ExitDasher;

	PROCEDURE RenderDasher (pen: Pen; ctxt: Gfx.Context; VAR bdist, edist: ARRAY OF FLOAT32; n: SIGNED32);
		VAR p: Dasher; simple: BOOLEAN; i: SIGNED32;
	BEGIN
		p := pen(Dasher); simple := p.base IS Stroker;
		IF n = 1 THEN
			BeginDasher(p, ctxt);
			Gfx.SetDashPattern(ctxt, p.on, p.off, p.len, p.phase + bdist[0]);
			IF simple THEN RenderStroker(p.base, ctxt, bdist, edist, 1)
			ELSE DashSubpath(p, bdist[0], edist[0])
			END;
			EndDasher(p)
		ELSE
			i := 1;
			WHILE simple & (i < n) DO simple := (bdist[i] = bdist[0]); INC(i) END;
			IF simple THEN	(* dash phase remains constant for all subpaths *)
				BeginDasher(p, ctxt);
				Gfx.SetDashPattern(ctxt, p.on, p.off, p.len, p.phase + bdist[0]);
				RenderStroker(p.base, ctxt, bdist, edist, n);
				EndDasher(p)
			ELSE	(* worst case: cannot use existing path, must revisit *)
				RenderPath(p, ctxt, bdist, edist, n)
			END
		END
	END RenderDasher;

	PROCEDURE InitDashers;
	BEGIN
		NEW(DasherMethods);
		DasherMethods.begin := BeginDasher; DasherMethods.end := EndDasher;
		DasherMethods.enter := EnterDasher; DasherMethods.exit := ExitDasher;
		DasherMethods.line := Line; DasherMethods.arc := Arc; DasherMethods.bezier := Bezier;
		DasherMethods.render := RenderDasher
	END InitDashers;


	(**--- Forkers ---**)

	PROCEDURE HandleForker* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen, copy: Forker; bw: FLOAT32; ver: SIGNED32;
	BEGIN
		pen := obj(Forker);
		IF msg IS UpdateMsg THEN
			WITH msg: UpdateMsg DO
				IF (msg.pen = pen.lower) OR (msg.pen = pen.upper) THEN
					Update(pen)
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF msg.id = Objects.get THEN
					IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoPens.NewForker"; msg.res := 0
					ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Forker"; msg.res := 0
					ELSIF msg.name = "Border" THEN
						pen.lower.handle(pen.lower, msg); bw := msg.x;
						pen.upper.handle(pen.upper, msg);
						IF bw > msg.x THEN msg.x := bw END
					END
				ELSE
					Handle(pen, msg)
				END
			END
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF msg.id = Objects.enum THEN
					msg.Enum("Lower"); msg.Enum("Upper")
				ELSIF msg.id = Objects.get THEN
					IF msg.name = "Lower" THEN msg.obj := pen.lower; msg.res := 0
					ELSIF msg.name = "Upper" THEN msg.obj := pen.upper; msg.res := 0
					END
				ELSIF msg.id = Objects.set THEN
					IF msg.name = "Lower" THEN
						IF (msg.obj # NIL) & (msg.obj IS Pen) THEN
							pen.lower := msg.obj(Pen); msg.res := 0;
							pen.needDist := pen.lower.needDist OR pen.upper.needDist;
							pen.zeroDistOnly := pen.lower.zeroDistOnly OR pen.upper.zeroDistOnly
						END
					ELSIF msg.name = "Upper" THEN
						IF (msg.obj # NIL) & (msg.obj IS Pen) THEN
							pen.upper := msg.obj(Pen); msg.res := 0;
							pen.needDist := pen.lower.needDist OR pen.upper.needDist;
							pen.zeroDistOnly := pen.lower.zeroDistOnly OR pen.upper.zeroDistOnly
						END
					END
				END
			END
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # pen.stamp THEN
					NEW(copy); pen.dlink := copy; pen.stamp := msg.stamp;
					Copy(msg, pen, copy);
					obj := Gadgets.CopyPtr(msg, pen.lower);
					IF (obj = NIL) OR ~(obj IS Pen) THEN NewStroker; obj := Objects.NewObj END;
					copy.lower := obj(Pen);
					obj := Gadgets.CopyPtr(msg, pen.upper);
					IF (obj = NIL) OR ~(obj IS Pen) THEN NewStroker; obj := Objects.NewObj END;
					copy.upper := obj(Pen)
				END;
				msg.obj := pen.dlink
			END
		ELSIF msg IS Objects.BindMsg THEN
			pen.lower.handle(pen.lower, msg); pen.upper.handle(pen.upper, msg);
			Handle(pen, msg)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Gadgets.WriteRef(msg.R, pen.lib, pen.lower);
					Gadgets.WriteRef(msg.R, pen.lib, pen.upper)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Gadgets.ReadRef(msg.R, pen.lib, obj);
					IF (obj = NIL) OR ~(obj IS Pen) THEN NewStroker; obj := Objects.NewObj END;
					pen.lower := obj(Pen);
					Gadgets.ReadRef(msg.R, pen.lib, obj);
					IF (obj = NIL) OR ~(obj IS Pen) THEN NewStroker; obj := Objects.NewObj END;
					pen.upper := obj(Pen);
					pen.needDist := pen.lower.needDist OR pen.upper.needDist;
					pen.zeroDistOnly := pen.lower.zeroDistOnly OR pen.upper.zeroDistOnly
				END
			END
		END
	END HandleForker;

	PROCEDURE InitForker* (pen: Forker; lower, upper: Pen);
	BEGIN
		ASSERT((lower # NIL) & (upper # NIL), 100);
		pen.handle := HandleForker; pen.do := ForkerMethods;
		pen.lower := lower; pen.upper := upper;
		pen.destructive := TRUE;
		pen.needDist := lower.needDist OR upper.needDist;
		pen.zeroDistOnly := lower.zeroDistOnly OR upper.zeroDistOnly
	END InitForker;

	PROCEDURE NewForker*;
		VAR pen: Forker;
	BEGIN
		NEW(pen); InitForker(pen, Default, Default);
		Objects.NewObj := pen
	END NewForker;

	PROCEDURE BeginForker (pen: Pen; ctxt: Gfx.Context);
	BEGIN
		Begin(pen, ctxt);
		Gfx.Begin(ctxt, {Gfx.Record});
		pen(Forker).n := 0
	END BeginForker;

	PROCEDURE ForkPath (pen: Pen; ctxt: Gfx.Context; VAR bdist, edist: ARRAY OF FLOAT32; n: SIGNED32);
		VAR p: Forker; path: GfxPaths.Path;
	BEGIN
		p := pen(Forker);
		IF p.lower.destructive THEN
			GetTempPath(path); GfxPaths.Copy(ctxt.path, path);
			p.lower.do.render(p.lower, ctxt, bdist, edist, n);
			GfxPaths.Copy(path, ctxt.path); ReleaseTempPath(path)
		ELSE
			p.lower.do.render(p.lower, ctxt, bdist, edist, n)
		END;
		p.upper.do.render(p.upper, ctxt, bdist, edist, n)
	END ForkPath;

	PROCEDURE EndForker (pen: Pen);
		VAR p: Forker;
	BEGIN
		p := pen(Forker);
		Gfx.End(p.ctxt);
		ForkPath(p, p.ctxt, p.bdist^, p.edist^, p.n);
		End(p)
	END EndForker;

	PROCEDURE EnterForker (pen: Pen; x, y, dx, dy, bdist: FLOAT32);
		VAR p: Forker;
	BEGIN
		p := pen(Forker);
		Gfx.Enter(p.ctxt, x, y, dx, dy);
		Append(p.bdist, p.n, bdist)
	END EnterForker;

	PROCEDURE ExitForker (pen: Pen; dx, dy, edist: FLOAT32);
		VAR p: Forker;
	BEGIN
		p := pen(Forker);
		Gfx.Exit(p.ctxt, dx, dy);
		Append(p.edist, p.n, edist);
		INC(p.n)
	END ExitForker;

	PROCEDURE InitForkers;
	BEGIN
		NEW(ForkerMethods);
		ForkerMethods.begin := BeginForker; ForkerMethods.end := EndForker;
		ForkerMethods.enter := EnterForker; ForkerMethods.exit := ExitForker;
		ForkerMethods.line := Line; ForkerMethods.arc := Arc; ForkerMethods.bezier := Bezier;
		ForkerMethods.render := ForkPath
	END InitForkers;


BEGIN
	InitRecorders; InitStrokers; InitFillers;
	NewStroker; Default := Objects.NewObj(Pen);
	InitDashers; InitForkers
END LeoPens.
