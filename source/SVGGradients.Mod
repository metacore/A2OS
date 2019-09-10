MODULE SVGGradients;

IMPORT SVG, SVGColors, XMLObjects, Raster, Gfx, Math;

(* Constants that determine the contiuity of gradients *)
CONST
	SpreadMethodPad=0;
	SpreadMethodReflect=1;
	SpreadMethodRepeat=2;

TYPE
	GradientStop=POINTER TO GradientStopDesc;
	GradientStopDesc=RECORD
		offset: SVG.Length;
		color: Raster.Pixel;
		next: GradientStop;
	END;

	Gradient*=OBJECT
		VAR first, last: GradientStop;
			gradientUnits*: SIGNED8;
			spreadMethod*: SIGNED8;
			transform*: SVG.Transform;

		PROCEDURE &New*;
		BEGIN
			NEW(transform);
			transform.SetIdentity();
		END New;

		(* Copy the other gradient *)
		PROCEDURE Copy*(other: Gradient);
		VAR current: GradientStop;
		BEGIN
			first := NIL;
			last := NIL;
			current := other.first;
			WHILE current # NIL DO
				AddStop2(current.offset, current.color);
				current := current.next;
			END;

			gradientUnits := other.gradientUnits;
			spreadMethod := other.spreadMethod;
			transform := other.transform;
		END Copy;

		(* Does this gradient have stops? *)
		PROCEDURE HasStops(): BOOLEAN;
		BEGIN
			RETURN (first#NIL);
		END HasStops;

		(* Remove all stops *)
		PROCEDURE ClearStops*;
		BEGIN
			first := NIL;
			last := NIL;
		END ClearStops;

		(* Add a stop *)
		PROCEDURE AddStop*(offset: SVG.Length; color:  SVG.Color);
		VAR r,g,b,a: SIGNED16;
			p: Raster.Pixel;
		BEGIN
			SVGColors.Split(color, r, g, b, a);
			p[0] := CHR(b);
			p[1] := CHR(g);
			p[2] := CHR(r);
			p[3] := CHR(a);
			AddStop2(offset, p);
		END AddStop;

		(* Add a stop using a different color type *)
		PROCEDURE AddStop2(offset: SVG.Length; color:  Raster.Pixel);
		BEGIN
			IF last=NIL THEN
				NEW(last);
				first := last;
			ELSE
				NEW(last.next);
				last := last.next;
			END;
			IF offset<0 THEN offset := 0 END;
			IF offset>1 THEN offset := 1 END;
			last.offset := offset;
			last.color := color;
		END AddStop2;

		(* Get the color at some offset *)
		PROCEDURE GetFromOffset(offset: SVG.Length):  Raster.Pixel;
		VAR prev, current: GradientStop;
			a: SVG.Length;
		BEGIN
			ASSERT(HasStops());

		(* Use spreadMethod to handle out-of-range offsets *)
			CASE spreadMethod OF
				SpreadMethodPad:
				| SpreadMethodReflect:
					offset := 2*(offset/2 - ENTIER(offset/2));
					IF offset>1.0 THEN offset := 2.0-offset END;
				| SpreadMethodRepeat:
					offset := offset - ENTIER(offset);
			END;

		(* Locate offset intervall *)
			prev := first;
			current := first;
			WHILE current # NIL DO
				IF current.offset >= offset THEN
					IF current.offset = prev.offset THEN RETURN current.color
					ELSE
						a := (offset-prev.offset)/(current.offset-prev.offset);
						RETURN SVGColors.BlendAndPremultiply(prev.color, current.color, a)
					END
				END;
				prev := current;
				current := current.next;
			END;
			RETURN prev.color;
		END GetFromOffset;

		(* Get the color at some point *)
		PROCEDURE GetFromPoint*(p: SVG.Coordinate): Raster.Pixel;
		BEGIN HALT(99);
		END GetFromPoint;
	END Gradient;

	LinearGradient*=OBJECT(Gradient)
		VAR p1*, p2*: SVG.Coordinate;

		(* Copy the other linear gradient *)
		PROCEDURE CopyLinear*(other: LinearGradient);
		BEGIN
			Copy(other);
			p1 := other.p1;
			p2 := other.p2;
		END CopyLinear;

		(* Get the color at some offset *)
		PROCEDURE GetFromPoint*(p: SVG.Coordinate): Raster.Pixel;
		VAR offset, len: SVG.Length;
			u, v, n: SVG.Coordinate;
		BEGIN
			u.x :=p2.x-p1.x;
			u.y :=p2.y-p1.y;
			v.x :=p.x-p1.x;
			v.y :=p.y-p1.y;
			len := Math.sqrt(SHORT(u.x*u.x+u.y*u.y));
			n.x :=u.x / len;
			n.y :=u.y / len;
			offset := (n.x*v.x+n.y*v.y)/len;
			RETURN GetFromOffset(offset);
		END GetFromPoint;
	END LinearGradient;

	RadialGradient*=OBJECT(Gradient)
		VAR center*, focal*: SVG.Coordinate;
			radius*: SVG.Length;

		(* Copy the other radial gradient *)
		PROCEDURE CopyRadial*(other: RadialGradient);
		BEGIN
			Copy(other);
			center := other.center;
			focal := other.focal;
			radius := other.radius;
		END CopyRadial;

		(* Get the color at some offset *)
		PROCEDURE GetFromPoint*(p: SVG.Coordinate): Raster.Pixel;
		VAR offset, ul2, discr, t1, t2: SVG.Length;
			u, v, u2 : SVG.Coordinate;
		BEGIN
		(* Line(focal-p), circle(center,radius) intersection *)
			u.x :=p.x-focal.x;
			u.y :=p.y-focal.y;
			v.x :=center.x-focal.x;
			v.y :=center.y-focal.y;
			u2.x:=u.x*u.x;
			u2.y:=u.y*u.y;
			ul2:= u2.x+u2.y;
			discr := 2*v.x*v.y*u.x*u.y+ul2*radius*radius-u2.y*v.x*v.x-u2.x*v.y*v.y;
			IF ul2=0 THEN
				offset := 0.0;
			ELSIF discr <= 0 THEN
				(* wrap? *)
				offset := 1.0;
			ELSE
				t1 := (v.x*u.x+v.y*u.y+Math.sqrt(SHORT(discr)))/ul2;
				t2 := (v.x*u.x+v.y*u.y-Math.sqrt(SHORT(discr)))/ul2;
				IF (t2 < t1) & (t2 >= 0) THEN
					t1 := t2;
				END;
				IF t1=0 THEN offset := 0
				ELSE offset := 1/t1
				END
			END;
			RETURN GetFromOffset(offset);
		END GetFromPoint;
	END RadialGradient;

	GradientDict*=OBJECT
		VAR gradients: XMLObjects.ArrayDict;

		PROCEDURE &New*;
		BEGIN
			NEW(gradients)
		END New;

		(* Add a gradient *)
		PROCEDURE AddGradient*(gradient: Gradient; id: SVG.String);
		BEGIN
			gradients.Add(id^, gradient)
		END AddGradient;

		(* Get a gradient with a specific id *)
		PROCEDURE GetGradient*(id: SVG.String):Gradient;
		VAR p: ANY;
		BEGIN
			p := gradients.Get(id^);
			IF p = NIL THEN RETURN NIL
			ELSE RETURN p(Gradient) END
		END GetGradient;

		(* Get a gradient in the formof a pattern *)
		PROCEDURE GetGradientAsPattern*(ctx: Gfx.Context; id: SVG.String;
			worldBBox, objectBBox: SVG.Box; userToWorldSpace: SVG.Transform; viewport: SVG.Box): Gfx.Pattern;
		VAR
			gradient: Gradient;
			img: Raster.Image;
			mode: Raster.Mode;
			x, y, minx, miny, maxx, maxy, imgWidth, imgHeight: SIGNED32;
			p, patternStart: SVG.Coordinate;
			transform: SVG.Transform;
		BEGIN
			gradient := GetGradient(id);
			IF gradient = NIL THEN
				SVG.Error("Couldn't find gradient with specified id");
				SVG.Error(id^);
				 RETURN NIL
			ELSIF ~gradient.HasStops() THEN
			(* If no stops are defined, then painting shall occur as if 'none' were specified as the paint style. *)
				 RETURN NIL
			ELSE
			(* Find transform from World Bounding Box Space to Specification Space*)
				NEW(transform);
				transform.SetIdentity();
				transform := transform.Translate(-worldBBox.x, -worldBBox.y);	(* from World Space to World Bounding Box Space *)
				transform := transform.Multiply(userToWorldSpace);	(* from User Space to World Space *)

				CASE gradient.gradientUnits OF
					SVG.UnitsUserSpaceOnUse:
					| SVG.UnitsObjectBoundingBox:
						transform:= transform.Translate(objectBBox.x, objectBBox.y);		(* from Object Bounding Box Space to User Space *)
						transform:= transform.Scale(objectBBox.width, objectBBox.height);	(* from Normalized Space to Object Bounding Box Space *)
				END;
				transform := transform.Multiply(gradient.transform);	(* additional gradientTransform *)
				transform := transform.Invert();

			(* clip to viewport *)
				patternStart.x := worldBBox.x;
				patternStart.y := worldBBox.y;
				minx := 0;
				miny := 0;
				maxx := ENTIER(worldBBox.width)+1;
				maxy := ENTIER(worldBBox.height)+1;

				IF minx<ENTIER(viewport.x-worldBBox.x) THEN minx := ENTIER(viewport.x-worldBBox.x); patternStart.x := viewport.x END;
				IF miny<ENTIER(viewport.y-worldBBox.y) THEN miny := ENTIER(viewport.y-worldBBox.y); patternStart.y := viewport.y END;
				IF maxx>ENTIER(viewport.x-worldBBox.x+viewport.width) THEN maxx := ENTIER(viewport.x-worldBBox.x+viewport.width) END;
				IF maxy>ENTIER(viewport.y-worldBBox.y+viewport.height) THEN maxy :=ENTIER( viewport.y-worldBBox.y+viewport.height) END;

				imgWidth := maxx-minx+1;
				imgHeight := maxy-miny+1;
				IF (imgWidth<=0) OR (imgHeight<=0) THEN
					imgWidth := 1;
					imgHeight := 1;
				END;

			(* Render gradient to pattern in World Bounding Box Space *)
				NEW(img);
				Raster.Create(img, imgWidth, imgHeight, Raster.BGRA8888);
				Raster.InitMode(mode, Raster.srcCopy);
				FOR y := 0 TO imgHeight-1 DO
				FOR x := 0 TO imgWidth-1 DO
					p.x := minx+x;
					p.y := miny+y;
					p := transform.Transform(p);
					Raster.Put(img, x, y, gradient.GetFromPoint(p), mode);
				END; END;
				RETURN Gfx.NewPattern(ctx, img, SHORT(patternStart.x), SHORT(patternStart.y));
			END
		END GetGradientAsPattern;
	END GradientDict;

(* Parse some spreadMethod attribute *)
PROCEDURE ParseSpreadMethod*(value: SVG.String; VAR spreadMethod: SIGNED8);
BEGIN
	IF value^ = "pad" THEN spreadMethod := SpreadMethodPad
	ELSIF value^ = "reflect" THEN spreadMethod := SpreadMethodReflect
	ELSIF value^ = "repeat" THEN spreadMethod := SpreadMethodRepeat
	ELSE
		SVG.Error("invalid gradient attribute spreadMethod");
		SVG.Error(value^)
	END
END ParseSpreadMethod;

END SVGGradients.
