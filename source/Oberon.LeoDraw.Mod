(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoDraw IN Oberon;	(** eos  **)

	(**
		Support for loading Draw files as Leonardo figures
	**)

	(*
		- no support for colored macros
	*)

	IMPORT
		Files, Objects, Oberon, Strings, Attributes, Documents, Desktops, Colors, Images, PictImages, GfxMatrix, GfxFonts, Gfx,
		Leonardo, LeoFrames, LeoTools, LeoDocs, LeoCaptions, LeoPens, LeoPaths, LeoBasic, LeoSplines;


	CONST
		GraphFileId = 0F9X; LibFileId = 0FDX; NameLen = 16;


	TYPE
		Name = ARRAY NameLen OF CHAR;

		MacroHead = POINTER TO MacroHeadDesc;
		Library = POINTER TO LibraryDesc;

		MacroHeadDesc = RECORD
			name: Name;
			shape: Leonardo.Shape;
			next: MacroHead;
		END;

		LibraryDesc = RECORD
			name: Name;
			first: MacroHead;
		END;

		Context = RECORD
			font: ARRAY 10 OF GfxFonts.Font;
			lib: ARRAY 4 OF Library;
			class: ARRAY 10, 64 OF CHAR;
		END;


	VAR
		Stroker: ARRAY 16, 6 OF LeoPens.Stroker;	(* 16 colors, 6 widths *)
		Filler: ARRAY 16, 9 OF LeoPens.Filler;	(* 16 colors, 9 patterns *)
		Pattern: ARRAY 9 OF Images.Image;
		MacroFig: Leonardo.Figure;


	PROCEDURE InitContext (VAR ctxt: Context);
		VAR i: SIGNED32;
	BEGIN
		ctxt.class[1] := "Graphics.NewLine";
		ctxt.class[2] := "Graphics.NewCaption";
		ctxt.class[3] := "Graphics.NewMacro";
		FOR i := 4 TO 9 DO ctxt.class[i] := "" END
	END InitContext;

	PROCEDURE GetColor (col: SIGNED16; VAR color: Gfx.Color);
	BEGIN
		color.r := Colors.Red[col]; color.g := Colors.Green[col]; color.b := Colors.Blue[col]
	END GetColor;

	PROCEDURE ThisLibrary (CONST name: ARRAY OF CHAR): Library;
		VAR
			lib: Library; i, j, w, h: SIGNED16; lname, fname: ARRAY 32 OF CHAR; file: Files.File; r: Files.Rider; ch: CHAR;
			ctxt: Context; shapes, top, next: Leonardo.Shape; group: LeoBasic.Group; mh: MacroHead;
	BEGIN
		lib := NIL;
		i := 0; WHILE name[i] >= "0" DO lname[i] := name[i]; INC(i) END;
		lname[i] := 0X;
		j := 0; WHILE name[j] > 0X DO fname[j] := name[j]; INC(j) END;
		IF i = j THEN
			fname[j] := "."; fname[j+1] := "L"; fname[j+2] := "i"; fname[j+3] := "b"; INC(j, 4)
		END;
		fname[j] := 0X;
		file := Files.Old(fname);
		IF file # NIL THEN
			Files.Set(r, file, 0); Files.Read(r, ch);
			IF ch = LibFileId THEN
				NEW(lib); COPY(lname, lib.name); lib.first := NIL;
				InitContext(ctxt);
				shapes := LoadElems(r, ctxt);
				WHILE shapes # NIL DO
					top := shapes;
					WHILE top.slink # NIL DO
						next := top.slink(Leonardo.Shape);
						top.up := next; next.down := top; top := next
					END;
					NEW(group); LeoBasic.InitGroup(group, shapes, top);
					Leonardo.Integrate(MacroFig, group);
					NEW(mh); mh.shape := group;
					Files.ReadInt(r, w); Files.ReadInt(r, h);
					Files.ReadString(r, mh.name);
					mh.next := lib.first; lib.first := mh;
					shapes := LoadElems(r, ctxt)
				END
			END
		END;
		RETURN lib
	END ThisLibrary;

	PROCEDURE ThisStroker (col, width: SIGNED16): LeoPens.Stroker;
		VAR color: Gfx.Color; pen: LeoPens.Stroker;
	BEGIN
		col := col MOD 16; DEC(width); IF width > 5 THEN width := 5 END;
		IF Stroker[col, width] = NIL THEN
			GetColor(col, color);
			NEW(pen); LeoPens.InitStroker(pen, color, width+1);
			Stroker[col, width] := pen
		END;
		RETURN Stroker[col, width]
	END ThisStroker;

	PROCEDURE ThisPattern (pat: SIGNED16): Images.Image;
	BEGIN
		ASSERT((1 <= pat) & (pat <= 8), 100);
		IF Pattern[pat] = NIL THEN
			NEW(Pattern[pat]); PictImages.PatternToImage(pat, Pattern[pat])
		END;
		RETURN Pattern[pat]
	END ThisPattern;

	PROCEDURE ThisFiller (col, pat: SIGNED16): LeoPens.Filler;
		VAR color: Gfx.Color; pen: LeoPens.Filler;
	BEGIN
		IF pat = 0 THEN
			RETURN NIL
		ELSE
			col := col MOD 16; IF pat > 8 THEN pat := 5 END;
			IF Filler[col, pat] = NIL THEN
				GetColor(col, color);
				NEW(pen); LeoPens.InitFiller(pen, color); pen.img := ThisPattern(pat);
				Filler[col, pat] := pen
			END;
			RETURN Filler[col, pat]
		END
	END ThisFiller;

	PROCEDURE CreateLine (x0, y0, x1, y1: FLOAT32; col, width: SIGNED16): Leonardo.Shape;
		VAR p, q: LeoPaths.Point; line: LeoPaths.Segment;
	BEGIN
		NEW(p); LeoPaths.InitPoint(p, x0, y0);
		NEW(q); LeoPaths.InitPoint(q, x1, y1);
		p.up := q; q.down := p;
		NEW(line); LeoPaths.InitPolyline(line, p, q, FALSE, ThisStroker(col, width));
		RETURN line
	END CreateLine;

	PROCEDURE CreateEllipse (xc, yc, xr, yr: FLOAT32; col, width: SIGNED16): Leonardo.Shape;
		VAR e: LeoBasic.Ellipse;
	BEGIN
		NEW(e); LeoBasic.InitEllipse(e, xc, yc, xr, yr, ThisStroker(col, width));
		RETURN e
	END CreateEllipse;

	PROCEDURE CreateRectangle (x0, y0, x1, y1: FLOAT32; col, width: SIGNED16; fill: LeoPens.Pen): Leonardo.Shape;
		VAR pen: LeoPens.Pen; forker: LeoPens.Forker; rect: LeoBasic.Rectangle;
	BEGIN
		IF fill = NIL THEN
			pen := ThisStroker(col, width)
		ELSE
			NEW(forker); LeoPens.InitForker(forker, fill, ThisStroker(col, width));
			pen := forker
		END;
		NEW(rect); LeoBasic.InitRect(rect, x0, y0, x1, y1, pen);
		RETURN rect
	END CreateRectangle;

	PROCEDURE CreateSpline (closed: BOOLEAN; CONST u, v: ARRAY OF SIGNED16; n, col, width: SIGNED16): Leonardo.Shape;
		VAR p, bot, top: LeoPaths.Point; i: SIGNED32; spline: LeoSplines.Spline;
	BEGIN
		NEW(p); LeoPaths.InitPoint(p, u[0] + 0.5, v[0] + 0.5); bot := p; top := p;
		i := 1;
		WHILE i < n DO
			NEW(p); LeoPaths.InitPoint(p, u[i] + 0.5, v[i] + 0.5);
			top.up := p; p.down := top; top := p;
			INC(i)
		END;
		NEW(spline); LeoSplines.Init(spline, bot, top, closed, ThisStroker(col, width));
		RETURN spline
	END CreateSpline;

	PROCEDURE LoadCaption (VAR ctxt: Context; VAR r: Files.Rider; x, y, col: SIGNED16): Leonardo.Shape;
		VAR fno: SIGNED8; i: SIGNED32; ch: CHAR; s: ARRAY 64 OF CHAR; color: Gfx.Color; cap: LeoCaptions.Caption;
	BEGIN
		Files.Read(r, fno); Files.Read(r, ch); i := 0;
		WHILE ch > 0DX DO
			s[i] := ch; INC(i);
			Files.Read(r, ch)
		END;
		s[i] := 0X;
		GetColor(col, color);
		NEW(cap); LeoCaptions.Init(cap, x + 0.5, y + 0.5, s, ctxt.font[fno], color);
		RETURN cap
	END LoadCaption;

	PROCEDURE LoadMacro (VAR ctxt: Context; VAR r: Files.Rider; x, y, col: SIGNED16): Leonardo.Shape;
		VAR lno: SIGNED8; name: Name; mh: MacroHead; shape: Leonardo.Shape; mat: GfxMatrix.Matrix;
	BEGIN
		Files.Read(r, lno); Files.ReadString(r, name);
		IF ctxt.lib[lno] # NIL THEN
			mh := ctxt.lib[lno].first; WHILE (mh # NIL) & (mh.name # name) DO mh := mh.next END;
			GfxMatrix.Init(mat, 1, 0, 0, 1, x, y);
			Leonardo.BeginCommand(MacroFig);
			Leonardo.Transform(MacroFig, mh.shape, mat);
			Leonardo.Clone(MacroFig, mh.shape, shape);	(* bounding boxes are correct because of committed trafo *)
			Leonardo.CancelCommand(MacroFig);
			RETURN shape
		ELSE
			NEW(shape); Leonardo.InitShape(shape, Leonardo.HandleShape);
			RETURN shape
		END
	END LoadMacro;

	PROCEDURE LoadCurve (VAR r: Files.Rider; x, y, w, h, col: SIGNED16): Leonardo.Shape;
		VAR len, kind, lw: SIGNED16; shape: Leonardo.Shape;
	BEGIN
		Files.ReadInt(r, len); Files.ReadInt(r, kind); Files.ReadInt(r, lw);
		IF kind = 0 THEN	(* up_line *)
			RETURN CreateLine(x + 0.5, y + 0.5, x + w - 0.5, y + h - 0.5, col, lw)
		ELSIF kind = 1 THEN	(* down_line *)
			RETURN CreateLine(x + 0.5, y + h - 0.5, x + w - 0.5, y + 0.5, col, lw)
		ELSIF kind = 2 THEN	(* circle *)
			w := w DIV 2;
			RETURN CreateEllipse(x + w + 0.5, y + w + 0.5, w, w, col, lw)
		ELSIF kind = 3 THEN	(* ellipse *)
			w := w DIV 2; h := h DIV 2;
			RETURN CreateEllipse(x + w + 0.5, y + h + 0.5, w, h, col, lw)
		ELSE
			NEW(shape); Leonardo.InitShape(shape, Leonardo.HandleShape);
			RETURN shape
		END
	END LoadCurve;

	PROCEDURE LoadRectangle (VAR r: Files.Rider; x, y, w, h, col: SIGNED16): Leonardo.Shape;
		VAR len: SIGNED16; width, vers: SIGNED8;
	BEGIN
		Files.ReadInt(r, len); Files.Read(r, width); Files.Read(r, vers);
		RETURN CreateRectangle(x + 0.5, y + 0.5, x + w - 0.5, y + h - 0.5, col, width, ThisFiller(col, vers))
	END LoadRectangle;

	PROCEDURE LoadSpline (VAR r: Files.Rider; x, y, col: SIGNED16): Leonardo.Shape;
		VAR len, n, i: SIGNED16; open: SIGNED8; u, v: ARRAY 21 OF SIGNED16;
	BEGIN
		Files.ReadInt(r, len);
		n := (len - 1) DIV 4;
		Files.Read(r, open);
		FOR i := 0 TO n - 1 DO Files.ReadInt(r, u[i]); INC(u[i], x) END;
		FOR i := 0 TO n - 1 DO Files.ReadInt(r, v[i]); INC(v[i], y) END;
		RETURN CreateSpline(open # 1, u, v, n, col, 1)
	END LoadSpline;

	PROCEDURE LoadShape (VAR ctxt: Context; VAR r: Files.Rider; CONST gen: ARRAY OF CHAR): Leonardo.Shape;
		VAR x, y, w, h, col: SIGNED16; shape: Leonardo.Shape;
	BEGIN
		Files.ReadInt(r, x); Files.ReadInt(r, y);
		Files.ReadInt(r, w); Files.ReadInt(r, h);
		Files.ReadInt(r, col);
		IF gen = "Graphics.NewLine" THEN
			IF w > h THEN
				RETURN CreateLine(x + 0.5, y + 0.5*h, x + w - 0.5, y + 0.5*h, col, h)
			ELSE
				RETURN CreateLine(x + 0.5*w, y + 0.5, x + 0.5*w, y + h - 0.5, col, w)
			END
		ELSIF gen = "Graphics.NewCaption" THEN
			RETURN LoadCaption(ctxt, r, x, y, col)
		ELSIF gen = "Graphics.NewMacro" THEN
			RETURN LoadMacro(ctxt, r, x, y, col)
		ELSIF gen = "Curves.New" THEN
			RETURN LoadCurve(r, x, y, w, h, col)
		ELSIF gen = "Rectangles.New" THEN
			RETURN LoadRectangle(r, x, y, w, h, col)
		ELSIF gen = "Splines.New" THEN
			RETURN LoadSpline(r, x, y, col)
		ELSE
			NEW(shape); Leonardo.InitShape(shape, Leonardo.HandleShape);
			RETURN shape
		END
	END LoadShape;

	PROCEDURE LoadElems (VAR r: Files.Rider; VAR ctxt: Context): Leonardo.Shape;
		VAR
			shapes, last, new: Leonardo.Shape; cno, k: SIGNED8; name, font, cmd: ARRAY 32 OF CHAR;
			i, j: SIGNED32; size, len: SIGNED16;
	BEGIN
		shapes := NIL; last := NIL;
		Files.Read(r, cno);
		WHILE ~r.eof & (cno >= 0) DO
			IF cno = 0 THEN
				Files.Read(r, cno); Files.Read(r, k); Files.ReadString(r, name);
				IF cno = 0 THEN
					i := 0;
					WHILE (name[i] # 0X) & (name[i] # ".") & ((name[i] < "0") OR ("9" < name[i])) DO
						font[i] := name[i]; INC(i)
					END;
					font[i] := 0X;
					IF ("0" <= name[i]) & (name[i] <= "9") THEN
						size := 0;
						REPEAT
							size := 10*size + ORD(name[i]) - ORD("0"); INC(i)
						UNTIL (name[i] < "0") OR ("9" < name[i]);
						IF name[i] = "i" THEN Strings.Append(font, "-Italic")
						ELSIF name[i] = "m" THEN Strings.Append(font, "-Medium")
						ELSIF name[i] = "b" THEN Strings.Append(font, "-Bold")
						ELSIF name[i] = "j" THEN Strings.Append(font, "-BoldItalic")
						END
					ELSE size := 10
					END;
					ctxt.font[k] := GfxFonts.OpenSize(font, size)
				ELSIF cno = 1 THEN
					ctxt.lib[k] := ThisLibrary(name)
				ELSE
					Files.ReadString(r, cmd);
					i := 0; j := 0;
					WHILE name[i] # 0X DO
						ctxt.class[k, i] := name[i]; INC(i)
					END;
					ctxt.class[k, i] := "."; INC(i);
					WHILE cmd[j] # 0X DO
						ctxt.class[k, i] := cmd[j]; INC(i); INC(j)
					END;
					ctxt.class[k, i] := 0X
				END
			ELSIF ctxt.class[cno] # "" THEN
				new := LoadShape(ctxt, r, ctxt.class[cno]);
				IF last = NIL THEN shapes := new ELSE last.slink := new END;
				last := new
			ELSE
				Files.Set(r, Files.Base(r), Files.Pos(r) + 10); Files.ReadInt(r, len);
				Files.Set(r, Files.Base(r), Files.Pos(r) + len)
			END;
			Files.Read(r, cno)
		END;
		RETURN shapes
	END LoadElems;

	PROCEDURE LoadDoc (doc: Documents.Document);
		VAR fig: Leonardo.Figure; file: Files.File; r: Files.Rider; tag: CHAR; ctxt: Context; main: LeoFrames.Frame;
	BEGIN
		fig := NIL;
		file := Files.Old(doc.name);
		IF file # NIL THEN
			Files.Set(r, file, 0);
			Files.Read(r, tag);
			IF tag = GraphFileId THEN
				NEW(MacroFig); Leonardo.InitFigure(MacroFig);
				InitContext(ctxt);
				NEW(fig); Leonardo.InitFigure(fig);
				Leonardo.Integrate(fig, LoadElems(r, ctxt));
				Leonardo.ClearSelection(fig);
				MacroFig := NIL
			END
		END;
		IF fig = NIL THEN
			doc.name := "No Draw file";
			NEW(fig); Leonardo.InitFigure(fig)
		END;
		NEW(main); LeoTools.InitFrame(main, fig);
		Documents.Init(doc, main)
	END LoadDoc;

	PROCEDURE NewDoc*;
		VAR doc: Documents.Document;
	BEGIN
		NEW(doc); LeoDocs.Init(doc); doc.Load := LoadDoc;
		Objects.NewObj := doc
	END NewDoc;

	PROCEDURE Open*;
		VAR s: Attributes.Scanner; doc: Documents.Document;
	BEGIN
		Attributes.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos); Attributes.Scan(s);
		IF s.class IN {Attributes.Name, Attributes.String} THEN
			NEW(doc); LeoDocs.Init(doc); doc.Load := LoadDoc;
			COPY(s.s, doc.name); doc.Load(doc);
			Desktops.ShowDoc(doc)
		END
	END Open;


END LeoDraw.


System.Directory *.Graph
LeoDraw.Open ^
