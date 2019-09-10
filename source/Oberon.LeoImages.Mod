(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE LeoImages IN Oberon; (** portable **)	(* eos  *)

	(**
		Leonardo raster images
	**)

	IMPORT
		Files, Objects, Gadgets, Images, PictImages, GfxMatrix, GfxImages, Gfx, Leonardo;


	CONST
		noFilter* = 0; linearFilter* = 1;


	TYPE
		Image* = POINTER TO ImageDesc;
		ImageDesc* = RECORD (Leonardo.ShapeDesc)
			img*: Images.Image;
			mat*: GfxMatrix.Matrix;
			quick*: BOOLEAN;
			filter*: SIGNED16;
			color*: Gfx.Color;
		END;


	VAR
		Pattern: Images.Image;


	(**--- Images ---**)

	PROCEDURE CalcBox (img: Image; CONST mat: GfxMatrix.Matrix);
		VAR m: GfxMatrix.Matrix;
	BEGIN
		GfxMatrix.Concat(img.mat, mat, m);
		GfxMatrix.ApplyToRect(m, 0, 0, img.img.width, img.img.height, img.llx, img.lly, img.urx, img.ury);
		img.bw := 0
	END CalcBox;

	PROCEDURE Validate (img: Image; VAR msg: Leonardo.ValidateMsg);
	BEGIN
		IF img.marked THEN
			Leonardo.UpdateShape(msg.fig, img);
			CalcBox(img, msg.lgm);
			Leonardo.UpdateShape(msg.fig, img);
			img.marked := FALSE; img.cont.marked := TRUE
		END
	END Validate;

	PROCEDURE Render (img: Image; VAR msg: Leonardo.RenderMsg);
		VAR ctm, lgm: GfxMatrix.Matrix; col: Gfx.Color; pat: Gfx.Pattern;
	BEGIN
		IF (img.llx < msg.urx) & (msg.llx < img.urx) & (img.lly < msg.ury) & (msg.lly < img.ury) THEN
			IF (msg.id = Leonardo.marked) & img.marked THEN
				ctm := msg.ctxt.ctm; Gfx.Concat(msg.ctxt, img.mat);
				Gfx.DrawRect(msg.ctxt, 0, 0, img.img.width, img.img.height, {Gfx.Stroke});
				Gfx.SetCTM(msg.ctxt, ctm)
			END;
			IF msg.id IN {Leonardo.active, Leonardo.passive} THEN
				ctm := msg.ctxt.ctm; Gfx.Concat(msg.ctxt, img.mat);
				IF (img.img.fmt.components = {Images.alpha}) OR img.quick THEN
					col := msg.ctxt.fillCol; Gfx.SetFillColor(msg.ctxt, img.color)
				END;
				IF img.quick THEN
					pat := msg.ctxt.fillPat; Gfx.SetFillPattern(msg.ctxt, Gfx.NewPattern(msg.ctxt, Pattern, 0, 0));
					Gfx.DrawRect(msg.ctxt, 0, 0, img.img.width, img.img.height, {Gfx.Fill});
					Gfx.SetFillPattern(msg.ctxt, pat)
				ELSIF img.filter = noFilter THEN Gfx.DrawImageAt(msg.ctxt, 0, 0, img.img, GfxImages.NoFilter)
				ELSIF img.filter = linearFilter THEN Gfx.DrawImageAt(msg.ctxt, 0, 0, img.img, GfxImages.LinearFilter)
				END;
				IF (img.img.fmt.components = {Images.alpha}) OR img.quick THEN
					Gfx.SetFillColor(msg.ctxt, col)
				END;
				Gfx.SetCTM(msg.ctxt, ctm)
			END;
			IF (msg.id IN {Leonardo.active, Leonardo.marksonly}) & img.sel THEN
				lgm := msg.lgm; GfxMatrix.Concat(img.mat, lgm, msg.lgm);
				Leonardo.DrawHandles(0, 0, img.img.width, img.img.height, msg);
				msg.lgm := lgm
			END
		END
	END Render;

	PROCEDURE Locate (img: Image; VAR msg: Leonardo.LocateMsg);
		VAR lgm, glm: GfxMatrix.Matrix; llx, lly, urx, ury: FLOAT32;
	BEGIN
		IF (msg.id = Leonardo.inside) & (msg.llx <= img.llx) & (img.urx <= msg.urx) & (msg.lly <= img.lly) & (img.ury <= msg.ury) THEN
			img.slink := msg.res; msg.res := img
		ELSIF (msg.llx < img.urx) & (img.llx < msg.urx) & (msg.lly < img.ury) & (img.lly < msg.ury) THEN
			IF msg.id = Leonardo.overlap THEN
				GfxMatrix.Concat(img.mat, msg.lgm, lgm); GfxMatrix.Invert(lgm, glm);
				GfxMatrix.ApplyToRect(glm, msg.llx, msg.lly, msg.urx, msg.ury, llx, lly, urx, ury);
				IF (0 < urx) & (llx < img.img.width) & (0 < ury) & (lly < img.img.height) THEN
					img.slink := msg.res; msg.res := img
				END
			ELSIF msg.id = Leonardo.project THEN
				lgm := msg.lgm; GfxMatrix.Concat(img.mat, lgm, msg.lgm);
				Leonardo.ProjectToHandles(img, 0, 0, img.img.width, img.img.height, msg);
				msg.lgm := lgm
			END
		END
	END Locate;

	PROCEDURE Transform (img: Image; VAR msg: Leonardo.TransformMsg);
		VAR glm, mat: GfxMatrix.Matrix;
	BEGIN
		IF (msg.id = Leonardo.apply) & img.marked & (msg.stamp # img.stamp) THEN
			img.stamp := msg.stamp;
			GfxMatrix.Invert(msg.lgm, glm);
			GfxMatrix.Concat(img.mat, msg.lgm, mat);
			GfxMatrix.Concat(mat, msg.mat, mat);
			GfxMatrix.Concat(mat, glm, mat);
			Leonardo.SetMatrix(msg.fig, img, "M", mat)
		END
	END Transform;

	PROCEDURE GetMatrix (img: Image; VAR msg: Leonardo.MatrixMsg);
		VAR lgm: GfxMatrix.Matrix;
	BEGIN
		IF msg.dest = img THEN
			lgm := msg.lgm; GfxMatrix.Concat(img.mat, msg.lgm, msg.lgm);
			Leonardo.GetHandleMatrix(0, 0, img.img.width, img.img.height, msg);
			msg.lgm := lgm
		END
	END GetMatrix;

	PROCEDURE HandleAttr (img: Image; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Filter"); msg.Enum("Quick"); msg.Enum("Red"); msg.Enum("Green"); msg.Enum("Blue");
			msg.Enum("M00"); msg.Enum("M01"); msg.Enum("M10");
			msg.Enum("M11"); msg.Enum("M20"); msg.Enum("M21");
			Leonardo.HandleShape(img, msg)
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "LeoImages.New"; msg.res := 0
			ELSIF msg.name = "Item" THEN msg.class := Objects.String; msg.s := "Image"; msg.res := 0
			ELSIF msg.name = "Filter" THEN msg.class := Objects.Int; msg.i := img.filter; msg.res := 0
			ELSIF msg.name = "Quick" THEN msg.class := Objects.Bool; msg.b := img.quick; msg.res := 0
			ELSIF msg.name = "Red" THEN msg.class := Objects.Int; msg.i := img.color.r; msg.res := 0
			ELSIF msg.name = "Green" THEN msg.class := Objects.Int; msg.i := img.color.g; msg.res := 0
			ELSIF msg.name = "Blue" THEN msg.class := Objects.Int; msg.i := img.color.b; msg.res := 0
			ELSIF msg.name = "M00" THEN msg.class := Objects.Real; msg.x := img.mat[0, 0]; msg.res := 0
			ELSIF msg.name = "M01" THEN msg.class := Objects.Real; msg.x := img.mat[0, 1]; msg.res := 0
			ELSIF msg.name = "M10" THEN msg.class := Objects.Real; msg.x := img.mat[1, 0]; msg.res := 0
			ELSIF msg.name = "M11" THEN msg.class := Objects.Real; msg.x := img.mat[1, 1]; msg.res := 0
			ELSIF msg.name = "M20" THEN msg.class := Objects.Real; msg.x := img.mat[2, 0]; msg.res := 0
			ELSIF msg.name = "M21" THEN msg.class := Objects.Real; msg.x := img.mat[2, 1]; msg.res := 0
			ELSE Leonardo.HandleShape(img, msg)
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "Filter" THEN
				IF (msg.class = Objects.Int) & (noFilter <= msg.i) & (msg.i <= linearFilter) THEN
					img.filter := SHORT(msg.i); msg.res := 0
				END
			ELSIF msg.name = "Quick" THEN
				IF msg.class = Objects.Bool THEN img.quick := msg.b; msg.res := 0 END
			ELSIF msg.name = "Red" THEN
				IF msg.class = Objects.Int THEN img.color.r := SHORT(msg.i MOD 100H); msg.res := 0 END
			ELSIF msg.name = "Green" THEN
				IF msg.class = Objects.Int THEN img.color.g := SHORT(msg.i MOD 100H); msg.res := 0 END
			ELSIF msg.name = "Blue" THEN
				IF msg.class = Objects.Int THEN img.color.b := SHORT(msg.i MOD 100H); msg.res := 0 END
			ELSIF msg.name = "M00" THEN
				IF msg.class = Objects.Real THEN img.mat[0, 0] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M01" THEN
				IF msg.class = Objects.Real THEN img.mat[0, 1] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M10" THEN
				IF msg.class = Objects.Real THEN img.mat[1, 0] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M11" THEN
				IF msg.class = Objects.Real THEN img.mat[1, 1] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M20" THEN
				IF msg.class = Objects.Real THEN img.mat[2, 0] := msg.x; msg.res := 0 END
			ELSIF msg.name = "M21" THEN
				IF msg.class = Objects.Real THEN img.mat[2, 1] := msg.x; msg.res := 0 END
			ELSE
				Leonardo.HandleShape(img, msg)
			END
		END
	END HandleAttr;

	PROCEDURE HandleLink (img: Image; VAR msg: Objects.LinkMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Model"); Leonardo.HandleShape(img, msg)
		ELSIF (msg.id = Objects.get) & (msg.name = "Model") THEN
			msg.obj := img.img; msg.res := 0
		ELSIF (msg.id = Objects.set) & (msg.name = "Model") & (msg.obj # NIL) & (msg.obj IS Images.Image) THEN
			img.img := msg.obj(Images.Image); msg.res := 0
		ELSE
			Leonardo.HandleShape(img, msg)
		END
	END HandleLink;

	PROCEDURE Copy* (VAR msg: Objects.CopyMsg; from, to: Image);
		VAR obj: Objects.Object;
	BEGIN
		Leonardo.CopyShape(msg, from, to);
		obj := Gadgets.CopyPtr(msg, from.img);
		IF (obj # NIL) & (obj IS Images.Image) THEN to.img := obj(Images.Image) END;
		to.mat := from.mat; to.filter := from.filter; to.quick := from.quick; to.color := from.color
	END Copy;

	PROCEDURE Handle* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR img, copy: Image; ver: SIGNED32; ch: CHAR;
	BEGIN
		img := obj(Image);
		IF msg IS Leonardo.ShapeMsg THEN
			IF msg IS Leonardo.ValidateMsg THEN
				Validate(img, msg(Leonardo.ValidateMsg))
			ELSIF msg IS Leonardo.RenderMsg THEN
				Render(img, msg(Leonardo.RenderMsg))
			ELSIF msg IS Leonardo.LocateMsg THEN
				Locate(img, msg(Leonardo.LocateMsg))
			ELSIF msg IS Leonardo.TransformMsg THEN
				Transform(img, msg(Leonardo.TransformMsg))
			ELSIF msg IS Leonardo.MatrixMsg THEN
				GetMatrix(img, msg(Leonardo.MatrixMsg))
			ELSE
				Leonardo.HandleShape(img, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			HandleAttr(img, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.LinkMsg THEN
			HandleLink(img, msg(Objects.LinkMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # img.stamp THEN
					NEW(copy); img.dlink := copy; img.stamp := msg.stamp;
					Copy(msg, img, copy)
				END;
				msg.obj := img.dlink
			END
		ELSIF msg IS Objects.BindMsg THEN
			img.img.handle(img.img, msg);
			Leonardo.HandleShape(img, msg)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				Leonardo.HandleShape(img, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					Gadgets.WriteRef(msg.R, img.lib, img.img);
					GfxMatrix.Write(msg.R, img.mat);
					Files.WriteInt(msg.R, img.filter);
					Files.WriteBool(msg.R, img.quick);
					Files.Write(msg.R, CHR(img.color.r)); Files.Write(msg.R, CHR(img.color.g)); Files.Write(msg.R, CHR(img.color.b))
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Gadgets.ReadRef(msg.R, img.lib, obj);
					IF (obj # NIL) & (obj IS Images.Image) THEN img.img := obj(Images.Image) END;
					GfxMatrix.Read(msg.R, img.mat);
					Files.ReadInt(msg.R, img.filter);
					Files.ReadBool(msg.R, img.quick);
					Files.Read(msg.R, ch); img.color.r := ORD(ch);
					Files.Read(msg.R, ch); img.color.g := ORD(ch);
					Files.Read(msg.R, ch); img.color.b := ORD(ch);
					CalcBox(img, GfxMatrix.Identity)
				END
			END
		ELSE Leonardo.HandleShape(img, msg)
		END
	END Handle;

	PROCEDURE Init* (img: Image; x, y: FLOAT32; obj: Images.Image);
	BEGIN
		Leonardo.InitShape(img, Handle);
		GfxMatrix.Init(img.mat, 1, 0, 0, 1, x, y);
		img.img := obj; img.filter := noFilter; img.quick := FALSE; img.color := Gfx.DGrey;
		CalcBox(img, GfxMatrix.Identity)
	END Init;

	PROCEDURE New*;
		VAR img: Image;
	BEGIN
		NEW(img); Init(img, 0, 0, Pattern);
		Objects.NewObj := img
	END New;


BEGIN
	NEW(Pattern); PictImages.PatternToImage(3, Pattern)
END LeoImages.
