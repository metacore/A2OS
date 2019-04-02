MODULE SVGRenderer;

IMPORT SVG, SVGColors, SVGGradients, SVGFilters, SVGUtilities, XMLObjects,
	Gfx, GfxBuffer, GfxPaths, GfxImages, GfxMatrix, Math, Raster;

TYPE
	RenderTargetPool=OBJECT
		VAR list: XMLObjects.ArrayCollection; (* container for pooled render targets *)

		PROCEDURE &New*;
		BEGIN
			NEW(list)
		END New;

		(* Allocate an unused or new document *)
		PROCEDURE Alloc*(VAR doc: SVG.Document; width, height: LONGINT);
		VAR p: ANY;
		BEGIN
			IF list.GetNumberOfElements()=0 THEN
				doc := SVG.NewDocument(width, height);
			ELSE
				p := list.GetElement(list.GetNumberOfElements()-1);
				doc := p(SVG.Document);
				list.Remove(doc);
				Raster.Clear(doc);
			END
		END Alloc;

		(* Add doc to pool *)
		PROCEDURE Free*(doc: SVG.Document);
		BEGIN
			list.Add(doc)
		END Free;
	END RenderTargetPool;
	Renderer*=OBJECT
		VAR
			gradients*: SVGGradients.GradientDict; (* container of all defined gradients *)
			filters*: SVGFilters.FilterDict; (* container of all defined filters *)

			ctxt: GfxBuffer.Context; (* context of the graphics library *)
			mode: SET; (* drawing mode for the graphics library (filled, stroked, ...) *)
			rasterMode: Raster.Mode; (* mode for the raster library (srcOverDst) *)

			filterStack: SVGFilters.FilterStack; (* stack of active filters *)
			renderTarget: SVG.Document; (* current render target *)
			renderTargetPool: RenderTargetPool; (* pool of unused render targets *)

		PROCEDURE &New*;
		BEGIN
			NEW(gradients);
			NEW(filters);
			NEW(filterStack);
			NEW(renderTargetPool);

			Raster.InitMode(rasterMode, Raster.srcOverDst);
		END New;

		(* Fill target white *)
		PROCEDURE FillWhite*(state: SVG.State);
		VAR
			white: Raster.Pixel;
			copyMode: Raster.Mode;
		BEGIN
			Raster.SetRGB(white,0FFH,0FFH,0FFH);
			Raster.InitMode(copyMode, Raster.srcCopy);
			Raster.Fill(state.target, 0, 0, state.target.width, state.target.height, white, copyMode)
		END FillWhite;

		(* Prepare for rendering *)
		PROCEDURE RenderBegin(state: SVG.State; recordPathMode: BOOLEAN);
		BEGIN
			NEW(ctxt);

			IF state.style.stroke.type = SVG.PaintURI THEN state.transparencyUsed := TRUE END;
			IF state.style.fill.type = SVG.PaintURI THEN state.transparencyUsed := TRUE END;

			IF state.transparencyUsed THEN
				renderTargetPool.Alloc(renderTarget, state.target.width, state.target.height);
				GfxBuffer.Init(ctxt, renderTarget);
			ELSE
				GfxBuffer.Init(ctxt, state.target);
			END;

			IF recordPathMode THEN
				mode := {Gfx.Record};
			ELSE
				mode := {};
				SetMatrix(state.userToWorldSpace,ctxt);
			END;
		END RenderBegin;

		(* Finalize the rendering *)
		PROCEDURE RenderEnd(state: SVG.State; recordPathMode: BOOLEAN);
		VAR pattern: Gfx.Pattern;
			worldBBox, objectBBox: SVG.Box;
			minx, miny, maxx, maxy: LONGINT;
			strokeWidth: SVG.Length;
		BEGIN
			IF recordPathMode THEN
				mode:={};

			(* Calculate bounding box of path *)
				GetBBoxes(ctxt.path, state.userToWorldSpace, worldBBox, objectBBox);

			(* Calculate and set stroke width *)
				strokeWidth := state.userToWorldSpace.TransformLength(state.style.strokeWidth);
				Gfx.SetLineWidth(ctxt, SHORT(strokeWidth));

			(* Enlarge bounding box for thick strokes *)
				worldBBox.x := worldBBox.x - strokeWidth;
				worldBBox.y := worldBBox.y - strokeWidth;
				worldBBox.width := worldBBox.width + 2*strokeWidth;
				worldBBox.height := worldBBox.height + 2*strokeWidth;

			(* Set the stroke style *)
				IF state.style.stroke.type = SVG.PaintColor THEN
					Gfx.SetStrokeColor(ctxt, GetColor(state.style.stroke.color));
					mode := mode + {Gfx.Stroke}
				ELSIF state.style.stroke.type = SVG.PaintURI THEN
					pattern  := gradients.GetGradientAsPattern(ctxt, state.style.stroke.uri, worldBBox, objectBBox, state.userToWorldSpace, state.viewport);
					IF pattern#NIL THEN
						Gfx.SetFillPattern(ctxt, pattern);
						mode := mode + {Gfx.Stroke}
					END
				END;

			(* Set the fill style *)
				IF state.style.fill.type = SVG.PaintColor THEN
					Gfx.SetFillColor(ctxt, GetColor(state.style.fill.color));
					mode := mode + {Gfx.Fill}
				ELSIF state.style.fill.type = SVG.PaintURI THEN
					pattern  := gradients.GetGradientAsPattern(ctxt, state.style.fill.uri, worldBBox, objectBBox, state.userToWorldSpace, state.viewport);
					IF pattern#NIL THEN
						Gfx.SetFillPattern(ctxt, pattern);
						mode := mode + {Gfx.Fill}
					END
				END;

			(* Render the recorded path *)
				Gfx.Render(ctxt, mode)
			ELSE
			(* Can not calculate bounding box of unrecorded path -> assume it is as large as the target *)
				worldBBox.x := 0;
				worldBBox.y := 0;
				worldBBox.width := state.target.width-1;
				worldBBox.height := state.target.height-1;
			END;

			IF state.transparencyUsed THEN
				minx := ENTIER(worldBBox.x);
				miny := ENTIER(worldBBox.y);
				maxx := ENTIER(worldBBox.x+worldBBox.width)+1;
				maxy := ENTIER(worldBBox.y+worldBBox.height)+1;

				IF minx<ENTIER(state.viewport.x) THEN minx := ENTIER(state.viewport.x) END;
				IF miny<ENTIER(state.viewport.y) THEN miny := ENTIER(state.viewport.y) END;
				IF maxx>ENTIER(state.viewport.x+state.viewport.width) THEN maxx := ENTIER(state.viewport.x+state.viewport.width) END;
				IF maxy>ENTIER(state.viewport.y+state.viewport.height) THEN maxy :=ENTIER(state. viewport.y+state.viewport.height) END;

				IF (minx<=maxx) & (miny<=maxy) THEN
					Raster.Copy(renderTarget, state.target, minx, miny, maxx, maxy, minx, miny,  rasterMode)
				END;

				renderTargetPool.Free(renderTarget)
			END
		END RenderEnd;

		(* Prepare use of a filter *)
		PROCEDURE BeginFilter*(filter: SVGFilters.Filter; state: SVG.State);
		BEGIN
			filterStack.Push(filter);
			IF filter#NIL THEN
				state.Push();
				state.target := SVG.NewDocument(state.target.width, state.target.height);
			END
		END BeginFilter;

		(* Finalize use of a filter *)
		PROCEDURE EndFilter*(state: SVG.State);
		VAR filterTarget: SVG.Document;
			filter: SVGFilters.Filter;
		BEGIN
			filterStack.Pop(filter);
			IF filter#NIL THEN
				filterTarget := state.target;
				state.Pop();
				filter.Apply(filterTarget, state.target);
			END
		END EndFilter;

		(* Draw a cubic bezier curve *)
		PROCEDURE Bezier3To(current, bezier1,  bezier2: SVG.Coordinate);
		BEGIN
			Gfx.BezierTo (ctxt,
				SHORT(current.x), SHORT(current.y),
				SHORT(bezier1.x), SHORT(bezier1.y),
				SHORT(bezier2.x), SHORT(bezier2.y));
		END Bezier3To;

		(* Draw a quadrativ bezier curve *)
		PROCEDURE Bezier2To(start, bezier, end: SVG.Coordinate);
		VAR bezier1, bezier2: SVG.Coordinate;
		BEGIN
			bezier1.x := (bezier.x-start.x)*2.0/3.0+start.x;
			bezier1.y := (bezier.y-start.y)*2.0/3.0+start.y;
			bezier2.x := end.x-(end.x-bezier.x)*2.0/3.0;
			bezier2.y := end.y-(end.y-bezier.y)*2.0/3.0;
			Bezier3To(end, bezier1, bezier2);
		END Bezier2To;

		(* Draw an arc *)
		PROCEDURE ArcTo(radius, flags, start, end: SVG.Coordinate; xrot: SVG.Length);
		VAR cos, sin, rx2, ry2, tmp: SVG.Length;
			diff0, diff, center0, center, d1, d2: SVG.Coordinate;
		BEGIN
		(* Interpret out-of-range parameters *)
			IF (start.x=end.x) & (start.y=end.y) THEN RETURN END;
			IF (radius.x=0) OR (radius.y=0) THEN
				Gfx.LineTo(ctxt, SHORT(end.x), SHORT(end.y));
				RETURN
			END;
			radius.x := ABS(radius.x);
			radius.y := ABS(radius.y);
			IF flags.x#0 THEN flags.x := 1.0 END;
			IF flags.y#0 THEN flags.y := 1.0 END;

		(* Calculate center *)
			cos := Math.cos(SHORT(xrot/180.0*Math.pi));
			sin := Math.sin(SHORT(xrot/180.0*Math.pi));
			diff.x := (start.x-end.x)/2;
			diff.y := (start.y-end.y)/2;
			diff0.x := cos*diff.x+sin*diff.y;
			diff0.y := -sin*diff.x+cos*diff.y;
			tmp := diff0.x*diff0.x/(radius.x*radius.x)+diff0.y*diff0.y/(radius.y*radius.y);
			IF tmp > 1 THEN
				tmp := Math.sqrt(SHORT(tmp));
				radius.x := tmp*radius.x;
				radius.y := tmp*radius.y;
				tmp := 0;
			ELSE
				rx2 := radius.x*radius.x;
				ry2 := radius.y*radius.y;
				tmp := rx2*diff0.y*diff0.y+ry2*diff0.x*diff0.x;
				tmp := (rx2*ry2-tmp)/tmp;
				IF tmp <= 0 THEN tmp := 0 END;
				tmp := Math.sqrt(SHORT(tmp));
				IF flags.x=flags.y THEN tmp := -tmp END;
			END;
			center0.x := tmp*radius.x*diff0.y/radius.y;
			center0.y := -tmp*radius.y*diff0.x/radius.x;
			center.x := cos*center0.x-sin*center0.y+(start.x+end.x)/2;
			center.y := sin*center0.x+cos*center0.y+(start.y+end.y)/2;

		(* Calculate conjugate diameter pair *)
			d1.x := center.x+radius.x*cos;
			d1.y := center.y+radius.x*sin;
			d2.x := center.x-radius.y*sin;
			d2.y := center.y+radius.y*cos;
			IF (flags.y = 0.0) = (d1.x*d2.y-d1.y*d2.x > 0.0) THEN
				tmp := d1.x;
				d1.x := d2.x;
				d2.x := tmp;
				tmp := d1.y;
				d1.y := d2.y;
				d2.y := tmp;
			END;

		(* Draw arc *)
			Gfx.ArcTo(ctxt,
				SHORT(end.x), SHORT(end.y),
				SHORT(center.x), SHORT(center.y),
				SHORT(d1.x), SHORT(d1.y),
				SHORT(d2.x), SHORT(d2.y))
		END ArcTo;

		(* Render an image *)
		PROCEDURE RenderImage*(x, y, width, height: SVG.Length; image: SVG.Document; state: SVG.State);
		VAR filter: GfxImages.Filter;
		BEGIN
			GfxImages.InitLinearFilter(filter);
			state.userToWorldSpace := state.userToWorldSpace.Translate(-x, -y);
			state.userToWorldSpace := state.userToWorldSpace.Scale(width / image.width, height / image.height);
			x := x*image.width / width;
			y := y*image.height / height;
			state.userToWorldSpace := state.userToWorldSpace.Translate(x, y);

		(* Gfx cannot record calls to DrawImageAt *)
			RenderBegin(state, FALSE);
			Gfx.DrawImageAt(ctxt, SHORT(x), SHORT(y), image, filter);
			RenderEnd(state, FALSE);
		END RenderImage;

		(* Render a rectangle*)
		PROCEDURE RenderRect*(x, y, width, height: SVG.Length; state: SVG.State);
		BEGIN
			RenderBegin(state,TRUE);
			Gfx.DrawRect(ctxt, SHORT(x), SHORT(y), SHORT(x+width), SHORT(y+height), mode);
			RenderEnd(state, TRUE);
		END RenderRect;

		(* Render a rounded rectangle *)
		PROCEDURE RenderRoundedRect*(x, y, width, height, rx, ry: SVG.Length; state: SVG.State);
		BEGIN
			RenderBegin(state, TRUE);

			IF rx>width/2 THEN rx := width/2 END;
			IF ry>height/2 THEN ry := height/2 END;

			Gfx.Begin(ctxt, mode);
			Gfx.MoveTo(ctxt, SHORT(x+width/2), SHORT(y));
			Gfx.LineTo(ctxt, SHORT(x+width-rx), SHORT(y));
			Gfx.ArcTo(ctxt,SHORT(x+width), SHORT(y+ry),
				SHORT(x+width-rx), SHORT(y+ry),
				SHORT(x+width-rx), SHORT(y),
				SHORT(x+width), SHORT(y+ry));
			Gfx.LineTo(ctxt, SHORT(x+width), SHORT(y+height-ry));
			Gfx.ArcTo(ctxt,SHORT(x+width-rx), SHORT(y+height),
				SHORT(x+width-rx), SHORT(y+height-ry),
				SHORT(x+width), SHORT(y+height-ry),
				SHORT(x+width-rx), SHORT(y+height));
			Gfx.LineTo(ctxt, SHORT(x+rx), SHORT(y+height));
			Gfx.ArcTo(ctxt,SHORT(x), SHORT(y+height-ry),
				SHORT(x+rx), SHORT(y+height-ry),
				SHORT(x+rx), SHORT(y+height),
				SHORT(x), SHORT(y+height-ry));
			Gfx.LineTo(ctxt, SHORT(x), SHORT(y+ry));
			Gfx.ArcTo(ctxt,SHORT(x+rx), SHORT(y),
				SHORT(x+rx), SHORT(y+ry),
				SHORT(x), SHORT(y+ry),
				SHORT(x+rx), SHORT(y));
			Gfx.Close(ctxt);
			Gfx.End(ctxt);

			RenderEnd(state, TRUE);
		END RenderRoundedRect;

		(* Render a circle *)
		PROCEDURE RenderCircle*(x, y, r: SVG.Length; state: SVG.State);
		BEGIN
			RenderBegin(state, TRUE);
			Gfx.DrawCircle(ctxt, SHORT(x), SHORT(y), SHORT(r), mode);
			RenderEnd(state, TRUE);
		END RenderCircle;

		(* Render an ellipse *)
		PROCEDURE RenderEllipse*(x, y, rx, ry: SVG.Length; state: SVG.State);
		BEGIN
			RenderBegin(state, TRUE);
			Gfx.DrawEllipse(ctxt, SHORT(x), SHORT(y), SHORT(rx), SHORT(ry), mode);
			RenderEnd(state, TRUE);
		END RenderEllipse;

		(* Render a line *)
		PROCEDURE RenderLine*(x1, y1, x2, y2: SVG.Length; state: SVG.State);
		BEGIN
			RenderBegin(state, TRUE);
			Gfx.DrawLine(ctxt, SHORT(x1), SHORT(y1), SHORT(x2), SHORT(y2), mode-{Gfx.Fill, Gfx.Clip, Gfx.EvenOdd});
			RenderEnd(state, TRUE);
		END RenderLine;

		(* Render an open polyline or a closed polygon *)
		PROCEDURE RenderPoly*(points: SVG.String; closed: BOOLEAN; state: SVG.State);
		VAR i: SIZE;
			current: SVG.Coordinate;
		BEGIN
			RenderBegin(state, TRUE);
			Gfx.Begin(ctxt, mode);

			i := 0;
			SVGUtilities.SkipWhiteSpace(i, points);
			SVG.ParseCoordinate(points, i, current, FALSE);
			SVGUtilities.SkipWhiteSpace(i, points);
			Gfx.MoveTo(ctxt, SHORT(current.x), SHORT(current.y));

			WHILE points[i] # 0X DO
				SVG.ParseCoordinate(points, i, current, FALSE);
				SVGUtilities.SkipWhiteSpace(i, points);
				Gfx.LineTo(ctxt, SHORT(current.x), SHORT(current.y));
			END;
			IF closed THEN
				Gfx.Close(ctxt);
			END;
			Gfx.End(ctxt);

			RenderEnd(state, TRUE);
		END RenderPoly;

		(* Render a general path element *)
		PROCEDURE RenderPath*(d: SVG.String; state: SVG.State);
		VAR i: SIZE;
			subPathStart, current, last: SVG.Coordinate;
			relative: BOOLEAN;
			command, prevCommand: CHAR;
			arcR, arcFlags: SVG.Coordinate;
			arcAngle: SVG.Length;
			bezier1, bezier2: SVG.Coordinate;
		BEGIN
			RenderBegin(state, TRUE);
			Gfx.Begin(ctxt, mode);

			current.x := 0;
			current.y := 0;
			command := 0X;
			i := 0;
			SVGUtilities.SkipWhiteSpace(i, d);

			IF (d[i] # 'm') & (d[i] # 'M') THEN
				SVG.Error("PathData error: missing moveto")
			END;

			WHILE d[i] # 0X DO
				SVGUtilities.SkipWhiteSpace(i, d);

				prevCommand := command;
				last := current;
				IF SVGUtilities.IsAlpha(d[i]) THEN
					relative := SVGUtilities.IsLowercase(d[i]);
					command := d[i];
					INC(i);
					SVGUtilities.SkipWhiteSpace(i, d);
				END;

				CASE command OF
					'm', 'M':
						SVG.ParseCoordinate(d, i, current, relative);
						subPathStart := current;
						Gfx.MoveTo(ctxt, SHORT(current.x), SHORT(current.y));
					| 'z', 'Z':
						current := subPathStart;
						Gfx.Close(ctxt);
					| 'l', 'L':
						SVG.ParseCoordinate(d, i, current, relative);
						Gfx.LineTo(ctxt, SHORT(current.x), SHORT(current.y));
					| 'h', 'H':
						SVG.ParseCoordinate1(d, i, current.x, relative);
						Gfx.LineTo(ctxt, SHORT(current.x), SHORT(current.y));
					| 'v', 'V':
						SVG.ParseCoordinate1(d, i, current.y, relative);
						Gfx.LineTo(ctxt, SHORT(current.x), SHORT(current.y));
					| 'c', 'C':
						bezier1:=current;
						bezier2:=current;
						SVG.ParseCoordinate(d, i, bezier1, relative);
						SVG.ParseCoordinate(d, i, bezier2, relative);
						SVG.ParseCoordinate(d, i, current, relative);
						Bezier3To(current, bezier1, bezier2);
					| 's', 'S':
						CASE prevCommand OF
							's','S','c','C':
								bezier1.x:=current.x-(bezier2.x-current.x);
								bezier1.y:=current.y-(bezier2.y-current.y);
						ELSE
							bezier1:=current;
						END;
						bezier2:=current;
						SVG.ParseCoordinate(d, i, bezier2, relative);
						SVG.ParseCoordinate(d, i, current, relative);
						Bezier3To(current, bezier1, bezier2);
					| 'q', 'Q':
						bezier1:=current;
						SVG.ParseCoordinate(d, i, bezier1, relative);
						SVG.ParseCoordinate(d, i, current, relative);
						Bezier2To(last, bezier1, current);
					| 't', 'T':
						CASE prevCommand OF
							't','T','q','Q':
								bezier1.x:=current.x-(bezier1.x-current.x);
								bezier1.y:=current.y-(bezier1.y-current.y);
						ELSE
							bezier1:=current;
						END;
						SVG.ParseCoordinate(d, i, current, relative);
						Bezier2To(last, bezier1, current);
					| 'a', 'A':
						SVG.ParseCoordinate(d, i, arcR, FALSE);
						SVG.ParseCoordinate1(d, i, arcAngle, FALSE);
						SVG.ParseCoordinate(d, i, arcFlags, FALSE);
						SVG.ParseCoordinate(d, i, current, relative);
						ArcTo(arcR,arcFlags,last,current,arcAngle);
				ELSE
					SVG.Error("PathData error: unknown command");
					d[i] := 0X;
				END;
				SVGUtilities.SkipWhiteSpace(i, d)
			END;
			Gfx.End(ctxt);
			RenderEnd(state, TRUE);
		END RenderPath;

	END Renderer;

(* Convert SVG.Color to Gfx.Color *)
PROCEDURE GetColor(color: SVG.Color): Gfx.Color;
VAR c: Gfx.Color;
BEGIN
	SVGColors.Split(color, c.r, c.g, c.b, c.a);
	RETURN c
END GetColor;

(* Calculate the bounding box of a path in worldspace and in object space. Also transform the path to worldspace *)
PROCEDURE GetBBoxes(path: GfxPaths.Path; objectToWorldSpace: SVG.Transform; VAR worldBBox, objectBBox: SVG.Box);
VAR
	x1World, y1World, x2World, y2World: REAL;
	x1Object, y1Object, x2Object, y2Object: REAL;
	mat: GfxMatrix.Matrix;
BEGIN
	GfxMatrix.Init(mat, SHORT(objectToWorldSpace.a), SHORT(objectToWorldSpace.b),
		SHORT(objectToWorldSpace.c), SHORT(objectToWorldSpace.d),
		SHORT(objectToWorldSpace.e), SHORT(objectToWorldSpace.f));

	GfxPaths.GetBox(path, x1Object, y1Object, x2Object, y2Object);
	objectBBox.x:=x1Object;
	objectBBox.y:=y1Object;
	objectBBox.width :=x2Object-x1Object;
	objectBBox.height :=y2Object-y1Object;

	GfxMatrix.ApplyToRect(mat, x1Object, y1Object, x2Object, y2Object, x1World, y1World, x2World, y2World);
	worldBBox.x := x1World;
	worldBBox.y := y1World;
	worldBBox.width := x2World-x1World;
	worldBBox.height := y2World-y1World;

	GfxPaths.Apply(path, mat);
END GetBBoxes;

(* Set the matrix to transform to world space. *)
PROCEDURE SetMatrix(objectToWorldSpace: SVG.Transform; ctxt: GfxBuffer.Context);
VAR mat: GfxMatrix.Matrix;
BEGIN
	GfxMatrix.Init(mat, SHORT(objectToWorldSpace.a), SHORT(objectToWorldSpace.b),
		SHORT(objectToWorldSpace.c), SHORT(objectToWorldSpace.d),
		SHORT(objectToWorldSpace.e), SHORT(objectToWorldSpace.f));
	Gfx.SetCTM(ctxt, mat);
END SetMatrix;

END SVGRenderer.
