(**
	AUTHOR: "Alexey Morozov";
	PURPOSE: "Smooth (antialiased) graphics";
*)
MODULE WMGraphicsSmooth;

IMPORT SYSTEM, Raster, Strings, WMGraphics;

CONST
	(** Line cap types *)
	CapButt* = 0; (** A flat edge is added to each end of the line;  *)
	CapRound* = 1; (** A rounded end cap is added to each end of the line; *)
	CapSquare* = 2; (** A square end cap is added to each end of the line;  *)

TYPE

	(**
		Cancas used for smooth (antialiased) graphics
	*)
	Canvas* = OBJECT(WMGraphics.BufferCanvas)
	VAR
		lineWidth-: REAL; (** line width in pixels *)
		capType-: LONGINT; (** line cap type *)

		srcOverDstMode: Raster.Mode;
		pixAlphaMap: ARRAY 256 OF Raster.Pixel;

		PROCEDURE &New(img : Raster.Image);
		VAR firstTime: BOOLEAN;
		BEGIN
			firstTime := generator = NIL;
			New^(img);
			IF firstTime THEN (*! for cases when the same canvas is reused with another image *)
				generator := Strings.NewString("WMGraphicsSmooth.GenCanvas");
				SetLineWidth(1.0);
				SetLineCap(CapButt);
				SetColor(WMGraphics.Blue);

				Raster.InitMode(srcOverDstMode,Raster.srcOverDst);
			END;
		END New;

		PROCEDURE SetColor(x: WMGraphics.Color);
		VAR
			i: LONGINT;
			s: LONGINT;
			r, g, b, a: LONGINT;
		BEGIN
			SetColor^(x);
			WMGraphics.ColorToRGBA(color,r,g,b,a);
			s := (256 * a) DIV 255;
			FOR i := 0 TO 255 DO Raster.SetRGBA(pixAlphaMap[i],r,g,b,a - (s*i+128) DIV 256); END;
		END SetColor;

		(**
			Set line width in pixels
		*)
		PROCEDURE SetLineWidth*(w: REAL);
		BEGIN
			IF w < 0.5 THEN w := 0.5; END;
			lineWidth := w;
		END SetLineWidth;

		(**
			Setup line cap type
		*)
		(*! REMARK: currently onle CapButt is implemented! *)
		PROCEDURE SetLineCap*(lineCap: LONGINT);
		BEGIN
			capType := MIN(CapSquare,MAX(CapButt,lineCap));
		END SetLineCap;

		PROCEDURE Line(x0, y0, x1, y1: LONGINT; lineColor: WMGraphics.Color; mode: LONGINT);
		VAR xr0, yr0, xr1, yr1: REAL;
		BEGIN
			IF lineColor # color THEN SetColor(lineColor); END;

			(* transform local coordinates to the global coordinate system *)
			xr0 := x0 + dx; yr0 := y0 + dy;
			xr1 := x1 + dx; yr1 := y1 + dy;

			IF lineWidth = 1 THEN
				(* does the line cross the canvas rectangle? *)
				IF ~ClipLineReal(limits.l,limits.t,limits.r-1,limits.b-1, xr0,yr0,xr1,yr1) THEN RETURN; END;
				ThinSmoothLineReal(img, xr0,yr0, xr1,yr1, pixAlphaMap, srcOverDstMode);
			ELSE
				(* does the line cross the canvas rectangle with account of the line width? *)
				IF ~ClipLineReal(limits.l-lineWidth,limits.t-lineWidth,limits.r-1+lineWidth,limits.b-1+lineWidth, xr0,yr0,xr1,yr1) THEN RETURN; END;
				ThickSmoothLineReal(img, xr0,yr0, xr1,yr1, pixAlphaMap, srcOverDstMode, lineWidth);
			END;
		END Line;

		(**
			Draw an antialiased line represented by real-valued coordinates of the starting and ending points
		*)
		PROCEDURE LineReal*(x0, y0, x1, y1: REAL; lineColor: WMGraphics.Color; mode: LONGINT);
		VAR
			dx, dy, g: REAL;
			x01, y01, x02, y02: REAL;
			x11, y11, x12, y12: REAL;
			points : ARRAY 4 OF WMGraphics.Point2d;
		BEGIN

			IF lineColor # color THEN SetColor(lineColor); END;

			(* transform local coordinates to the global coordinate system *)
			x0 := x0 + dx; y0 := y0 + dy;
			x1 := x1 + dx; y1 := y1 + dy;

			IF lineWidth <= 1 THEN
				(* does the line cross the canvas rectangle? *)
				IF ~ClipLineReal(limits.l,limits.t,limits.r-1,limits.b-1, x0,y0,x1,y1) THEN RETURN; END;
				ThinSmoothLineReal(img, x0,y0, x1,y1, pixAlphaMap, srcOverDstMode);
			ELSE
				(* does the line cross the canvas rectangle with account of the line width? *)
				IF ~ClipLineReal(limits.l-lineWidth,limits.t-lineWidth,limits.r-1+lineWidth,limits.b-1+lineWidth, x0,y0,x1,y1) THEN RETURN; END;
				ThickSmoothLineReal(img, x0,y0, x1,y1, pixAlphaMap, srcOverDstMode, lineWidth);

				(*! an alternative way based on FillPolygonFlat - potentially faster than the current implementation of ThickSmoothLineReal;  *)
				(*
				dx := x1 - x0;
				dy := y1 - y0;

				g := (0.5*lineWidth) * InvSqrt(dx*dx + dy*dy);

				x01 := x0 + dy*g;
				y01 := y0 - dx*g;
				x11 := x1 + dy*g;
				y11 := y1 - dx*g;

				x02 := x01 - 2*dy*g;
				y02 := y01 + 2*dx*g;
				x12 := x11 - 2*dy*g;
				y12 := y11 + 2*dx*g;

				points[0].x := Round(x01); points[0].y := Round(y01);
				points[1].x := Round(x02); points[1].y := Round(y02);
				points[2].x := Round(x12); points[2].y := Round(y12);
				points[3].x := Round(x11); points[3].y := Round(y11);
				FillPolygonFlat(points,4,lineColor,WMGraphics.ModeCopy);

				ThinSmoothLineReal(img, x01,y01, x11,y11, pixAlphaMap, srcOverDstMode);
				ThinSmoothLineReal(img, x02,y02, x12,y12, pixAlphaMap, srcOverDstMode);

				ThinSmoothLineReal(img, x01,y01, x02,y02, pixAlphaMap, srcOverDstMode);
				ThinSmoothLineReal(img, x11,y11, x12,y12, pixAlphaMap, srcOverDstMode);
				*)
			END;
		END LineReal;

	END Canvas;

	PROCEDURE GenCanvas*(img:Raster.Image):WMGraphics.BufferCanvas; (* generator procedure *)
	VAR c:Canvas;
	BEGIN
		NEW(c,img); RETURN c (* img is NIL, needs a call of c.New(img) later on *)
	END GenCanvas;

	(**
		Fast inverse square root (1 / sqrt(x))

		Based on the "0x5f3759df" algorithm described in Wikipedia ( https://en.wikipedia.org/wiki/Fast_inverse_square_root )
	*)
	PROCEDURE InvSqrt(x: REAL): REAL;
	VAR y: REAL;
	BEGIN
		y := SYSTEM.VAL(REAL,0x5f3759df - SYSTEM.VAL(LONGINT,x) DIV 2); (* ~4% of error *)
		RETURN y * ( 1.5E0 - y * y * (x * 0.5E0) ); (* ~0.15% of error *)
	END InvSqrt;

	(**
		Draw a thin (<=1 pixel wide) antialiased line defined by starting and ending points with real coordinates

		img: raster image object
		x0, y0: starting line position
		x1, y1: ending line position
		pixAlphaMap: pixel map for 256 alpha values for a given line color
		srcOverDstMode: raster mode corresponding to source over destination transfer (use Raster.InitMode(srcOverDstMode,Raster.srcOverDst);)

		REMARK:
			In this code the signed distance function is defined as: sdist(x,y) = (dx*(y-y0) - dy*(x-x0)) / sqrt(dx*dx+dy*dy), where dx = x1-x0, dy = y1-y0

		POSSIBLE COMPILER BUG: if "CONST pixAlphaMap: ARRAY 256 OF Raster.Pixel" is replaced by "CONST pixAlphaMap: ARRAY OF Raster.Pixel" the generated code traps with an access violation!!!
	*)
	(*!TODO: optimize the code for performance; consider to use fixed point arithmetics *)
	PROCEDURE ThinSmoothLineReal(
												img: Raster.Image;
												x0, y0, x1, y1: REAL;
												CONST pixAlphaMap: ARRAY 256 OF Raster.Pixel;
												VAR srcOverDstMode: Raster.Mode
												);
	VAR
		swapped: BOOLEAN;
		a, i, incx, incy, x, y, yy, xend: LONGINT;
		dx, dy, sdx, sdy, dc, dm, dd, d0, d1, v, v0, v1, w: REAL;
		x0p, y0p, x1p: REAL;
	BEGIN

		dx := x1 - x0;
		dy := y1 - y0;

		IF dx < 0 THEN
			x0 := x0 + dx; x1 := x1 - dx;
			y0 := y0 + dy; y1 := y1 - dy;
			dx := -dx; dy := -dy;
		END;

		IF ABS(dy) > ABS(dx) THEN (* slope > 1 *)
			v := x0; x0 := y0; y0 := v;
			v := x1; x1 := y1; y1 := v;
			v := dx; dx := dy; dy := v;
			swapped := TRUE;
		END;

		IF dx >= 0 THEN incx := 1; ELSE incx := -1; END;
		IF dy >= 0 THEN incy := 1; ELSE incy := -1; END;

		(* normalize ranges by the distance between the point- will be used for computing the signed distance to the line *)
		v := InvSqrt(dx*dx + dy*dy);
		dx := dx*v; dy := dy*v;

		sdx := dx; sdy := dy; (* differences used for lines perpendicular to the original line *)

		(* account for the signs of the coordinate differences *)
		IF ~((dx >= 0) & (dy >= 0)) OR (((dx < 0) & (dy < 0))) THEN
			dx := -dx; dy := -dy;
		END;

		(* move start and end points to the left and right accordingly by 2 units along the line *)
		x0p := x0 - 2.0*sdx;
		y0p := y0 - 2.0*sdy;
		x1p := x1 + 2.0*sdx;

		x := ENTIER(x0p);
		y := ENTIER(y0p);

		dm := dx*(y + 0.5*incy - y0) - dy*((x+incx) - x0); (* signed distance at the midpoint dm = sdist(x+incx,y+0.5*incy) *)
		d0 := sdy*(y - y0) + sdx*(x - x0); (* signed distance for the line, which goes through (x0,y0) and perpendicular to the original line (sdist0)  *)
		d1 := sdy*(y - y1) + sdx*(x - x1); (* signed distance for the line, which goes through (x0,y0) and perpendicular to the original line (sdist1) *)
		dd := dx*0.5*incy - dy*incx; (* offset for computing signed distance at the current point (x,y-incy) *)

		(* account for the signs of the increments *)
		IF incx < 0 THEN dy := -dy; sdx := -sdx; END;
		IF incy < 0 THEN dx := -dx; sdy := -sdy; END;

		xend := ENTIER(x1p);
		WHILE x # xend DO

			dc := dm - dd; (* dc = sdist(x,y) *)
			w := ABS(dc);
			IF w < 1.0 THEN
				w := MAX(MAX(-d0,d1),w);
				IF w < 1.0 THEN
					IF swapped THEN Raster.Put(img,y,x,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); ELSE Raster.Put(img,x,y,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); END;
				END;
			END;

			yy := y;
			v := dc - dx; w := ABS(v);
			IF w < 1.0 THEN
				(* y - incy *)
				DEC(yy,incy); v0 := d0 - sdy; v1 := d1 - sdy;
				w := MAX(MAX(-v0,v1),w);
				IF w < 1.0 THEN
					IF swapped THEN Raster.Put(img,yy,x,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); ELSE Raster.Put(img,x,yy,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); END;
				END;
				(* y - 2*incy *)
				v := v - dx; w := ABS(v);
				IF w < 1.0 THEN
					DEC(yy,incy); v0 := v0 - sdy; v1 := v1 - sdy;
					w := MAX(MAX(-v0,v1),w);
					IF w < 1.0 THEN
						IF swapped THEN Raster.Put(img,yy,x,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); ELSE Raster.Put(img,x,yy,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); END;
					END;
				END;
			END;

			yy := y;
			v := dc + dx; w := ABS(v);
			IF w < 1.0 THEN
				(* y + incy *)
				INC(yy,incy); v0 := d0 + sdy; v1 := d1 + sdy;
				w := MAX(MAX(-v0,v1),w);
				IF w < 1.0 THEN
					IF swapped THEN Raster.Put(img,yy,x,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); ELSE Raster.Put(img,x,yy,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); END;
				END;
				(* y + 2*incy *)
				v := v + dx; w := ABS(v);
				IF w < 1.0 THEN
					INC(yy,incy); v0 := v0 + sdy; v1 := v1 + sdy;
					w := MAX(MAX(-v0,v1),w);
					IF w < 1.0 THEN
						IF swapped THEN Raster.Put(img,yy,x,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); ELSE Raster.Put(img,x,yy,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); END;
					END;
				END;
			END;

			IF dm < 0 THEN
				INC(y,incy);
				dm := dm + dx;
				d0 := d0 + sdy; d1 := d1 + sdy;
			END;
			dm := dm - dy;
			d0 := d0 + sdx; d1 := d1 + sdx;
			INC(x,incx);
		END;

	END ThinSmoothLineReal;

	(**
		Draw a thick (>1 pixel wide) antialiased line defined by starting and ending points with real coordinates

		img: raster image object
		x0, y0: starting line position
		x1, y1: ending line position
		pixAlphaMap: pixel map for 256 alpha values for a given line color
		srcOverDstMode: raster mode corresponding to source over destination transfer (use Raster.InitMode(srcOverDstMode,Raster.srcOverDst);)
		lineWidth: real-value line width

		REMARK:
			In this code the signed distance function is defined as: sdist(x,y) = (dx*(y-y0) - dy*(x-x0)) / sqrt(dx*dx+dy*dy), where dx = x1-x0, dy = y1-y0

		POSSIBLE COMPILER BUG: if "CONST pixAlphaMap: ARRAY 256 OF Raster.Pixel" is replaced by "CONST pixAlphaMap: ARRAY OF Raster.Pixel" the generated code traps with an access violation!!!
	*)
	(*!TODO: optimize the code for performance; consider to use fixed point arithmetics *)
	PROCEDURE ThickSmoothLineReal(img: Raster.Image; x0, y0, x1, y1: REAL; CONST pixAlphaMap: ARRAY 256 OF Raster.Pixel; VAR srcOverDstMode: Raster.Mode; lineWidth: REAL);
	VAR
		swapped: BOOLEAN;
		a, i, incx, incy, x, y, yy, xend: LONGINT;
		dx, dy, sdx, sdy, dc, dm, dd, d0, d1, v, v0, v1, w: REAL;
		x0p, y0p, x1p: REAL;
		halfWidth: REAL;
	BEGIN

		halfWidth := 0.5*lineWidth;

		dx := x1 - x0;
		dy := y1 - y0;

		IF dx < 0 THEN
			x0 := x0 + dx; x1 := x1 - dx;
			y0 := y0 + dy; y1 := y1 - dy;
			dx := -dx; dy := -dy;
		END;

		IF ABS(dy) > ABS(dx) THEN (* slope > 1 *)
			v := x0; x0 := y0; y0 := v;
			v := x1; x1 := y1; y1 := v;
			v := dx; dx := dy; dy := v;
			swapped := TRUE;
		END;

		IF dx >= 0 THEN incx := 1; ELSE incx := -1; END;
		IF dy >= 0 THEN incy := 1; ELSE incy := -1; END;

		(* normalize ranges by the distance between the point- will be used for computing the signed distance to the line *)
		v := InvSqrt(dx*dx + dy*dy);
		dx := dx*v; dy := dy*v;

		sdx := dx; sdy := dy; (* differences used for lines perpendicular to the original line *)

		(* account for the signs of the coordinate differences *)
		IF ~((dx >= 0) & (dy >= 0)) OR (((dx < 0) & (dy < 0))) THEN
			dx := -dx; dy := -dy;
		END;

		(* move start and end points to the left and right accordingly by 2 units along the line *)
		x0p := x0 - lineWidth*sdx;
		y0p := y0 - lineWidth*sdy;
		x1p := x1 + lineWidth*sdx;

		x := ENTIER(x0p);
		y := ENTIER(y0p);

		dm := dx*(y + 0.5*incy - y0) - dy*((x+incx) - x0); (* signed distance at the midpoint dm = sdist(x+incx,y+0.5*incy) *)
		d0 := sdy*(y - y0) + sdx*(x - x0); (* signed distance for the line, which goes through (x0,y0) and perpendicular to the original line (sdist0)  *)
		d1 := sdy*(y - y1) + sdx*(x - x1); (* signed distance for the line, which goes through (x0,y0) and perpendicular to the original line (sdist1) *)
		dd := dx*0.5*incy - dy*incx; (* offset for computing signed distance at the current point (x,y-incy) *)

		(* account for the signs of the increments *)
		IF incx < 0 THEN dy := -dy; sdx := -sdx; END;
		IF incy < 0 THEN dx := -dx; sdy := -sdy; END;

		xend := ENTIER(x1p);
		WHILE x # xend DO

			dc := dm - dd; (* dc = sdist(x,y) *)

			w := MAX(MAX(-d0,d1),ABS(dc));
			IF (d0 >= 0) & (d1 <= 0) THEN
				IF swapped THEN Raster.Put(img,y,x,pixAlphaMap[0],srcOverDstMode); ELSE Raster.Put(img,x,y,pixAlphaMap[0],srcOverDstMode); END;
			ELSIF w < 1 THEN
				IF swapped THEN Raster.Put(img,y,x,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); ELSE Raster.Put(img,x,y,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); END;
			END;

			yy := y;
			v := dc - dx; v0 := d0; v1 := d1;
			w := -v - halfWidth;
			WHILE w < 1 DO
				DEC(yy,incy); v0 := v0 - sdy; v1 := v1 - sdy;
				w := MAX(MAX(-v0,v1),w);
				IF w < 0 THEN
					IF swapped THEN Raster.Put(img,yy,x,pixAlphaMap[0],srcOverDstMode); ELSE Raster.Put(img,x,yy,pixAlphaMap[0],srcOverDstMode); END;
				ELSIF w < 1 THEN
					IF swapped THEN Raster.Put(img,yy,x,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); ELSE Raster.Put(img,x,yy,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); END;
				END;
				v := v - dx; w := -v - halfWidth;
			END;

			yy := y;
			v := dc + dx; v0 := d0; v1 := d1;
			w := v - halfWidth;
			WHILE w < 1 DO
				INC(yy,incy); v0 := v0 + sdy; v1 := v1 + sdy;
				w := MAX(MAX(-v0,v1),w);
				IF w < 0 THEN
					IF swapped THEN Raster.Put(img,yy,x,pixAlphaMap[0],srcOverDstMode); ELSE Raster.Put(img,x,yy,pixAlphaMap[0],srcOverDstMode); END;
				ELSIF w < 1 THEN
					IF swapped THEN Raster.Put(img,yy,x,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); ELSE Raster.Put(img,x,yy,pixAlphaMap[ENTIER(255*w)],srcOverDstMode); END;
				END;
				v := v + dx; w := v - halfWidth;
			END;

			IF dm < 0 THEN
				INC(y,incy);
				dm := dm + dx;
				d0 := d0 + sdy; d1 := d1 + sdy;
			END;
			dm := dm - dy;
			d0 := d0 + sdx; d1 := d1 + sdx;
			INC(x,incx);
		END;
	(*VAR
		dx, dy, ig: REAL;
		x01, y01, x02, y02: REAL;
		x11, y11, x12, y12: REAL;
	BEGIN
		dx := x1 - x0;
		dy := y1 - y0;

		ig := halfWidth * InvSqrt(dx*dx + dy*dy);

		dx := dx*ig; dy := dy*ig;

		x01 := x0 + dy;
		y01 := y0 - dx;
		x11 := x1 + dy;
		y11 := y1 - dx;

		x02 := x01 - 2*dy;
		y02 := y01 + 2*dx;
		x12 := x11 - 2*dy;
		y12 := y11 + 2*dx;

		ThinSmoothLineReal(img, x01,y01, x11,y11, pixAlphaMap, srcOverDstMode);
		ThinSmoothLineReal(img, x02,y02, x12,y12, pixAlphaMap, srcOverDstMode);

		ThinSmoothLineReal(img, x01,y01, x02,y02, pixAlphaMap, srcOverDstMode);
		ThinSmoothLineReal(img, x11,y11, x12,y12, pixAlphaMap, srcOverDstMode);*)
	END ThickSmoothLineReal;

	PROCEDURE Round(x: REAL): LONGINT;
	BEGIN
		IF x >= 0 THEN
			RETURN ENTIER(x+0.5);
		ELSE
			RETURN -ENTIER(-x+0.5);
		END;
	END Round;

	(*
		Find intersection of a line with a given rectangle

		l, r, t, b: left,right,top,bottom coordinates of the rectangle
		x0, y0: starting line point
		x1, y1: end line point

		Intersection points are returned in x0, y0, x1, y1
	*)
	PROCEDURE ClipLineReal(l, t, r, b: REAL; VAR x0, y0, x1, y1: REAL): BOOLEAN;
	VAR
		dy, dx, x00, y00: REAL;
	BEGIN

		dx := x1 - x0;
		dy := y1 - y0;

		IF dy = 0 THEN (* horizontal line *)
			IF (y0 >= t) & (y0 <= b) THEN
				IF x0 <= x1 THEN
					RETURN (x0 <= r) & (x1 >= l);
				ELSE
					RETURN (x1 <= r) & (x0 >= l);
				END;
			ELSE
				RETURN FALSE;
			END;
		ELSIF dx = 0 THEN (* vertical line *)
			IF (x0 >= l) & (x0 <= r) THEN
				IF y0 <= y1 THEN
					RETURN (y0 <= b) & (y1 >= t);
				ELSE
					RETURN (y1 <= b) & (y0 >= t);
				END;
			ELSE
				RETURN FALSE;
			END;
		ELSE

			IF x0 < x1 THEN
				IF (x0 <= r) & (x1 >= l) THEN
					IF y0 <= y1 THEN

						IF (y0 <= b) & (y1 >= t) THEN
							x00 := x0;
							y00 := y0;

							IF x0 < l THEN
								(* intersection with x = left *)
								y0 := y00 + (dy*(l-x00)) / dx; x0 := l;
								IF y0 < t THEN
									(* intersection with y = tody *)
									x0 := x00 + (dx*(t-y00)) / dy; y0 := t;
								END;
							ELSIF y0 < t THEN
								(* intersection with y = tody *)
								x0 := x00 + (dx*(t-y00)) / dy; y0 := t;
								IF x0 < l THEN
									(* intersection with x = left *)
									y0 := y00 + (dy*(l-x00)) / dx; x0 := l;
								END;
							END;


							IF x1 > r THEN
								(* intersection with x = right *)
								y1 := y00 + (dy*(r-x00)) / dx; x1 := r;
								IF y1 > b THEN
									(* intersection with y = bottom *)
									x1 := x00 + (dx*(b-y00)) / dy; y1 := b;
								END;
							ELSIF y1 > b THEN
								(* intersection with y = bottom *)
								x1 := x00 + (dx*(b-y00)) / dy; y1 := b;
								IF x1 > r THEN
								(* intersection with x = right *)
									y1 := y00 + (dy*(r-x00)) / dx; x1 := r;
								END;
							END;

							ASSERT(x0 >= l);
							ASSERT(y0 >= t);
							ASSERT(x1 <= r);
							ASSERT(y1 <= b);

						ELSE
							RETURN FALSE;
						END;

					ELSIF (y1 <= b) & (y0 >= t) THEN (* y0 > y1, dy < 0 *)

						x00 := x0;
						y00 := y0;
						dy := -dy;

						IF x0 < l THEN
							(* intersection with x = left *)
							y0 := y00 - (dy*(l-x00)) / dx; x0 := l;
							IF y0 > b THEN
								(* intersection with y = bottom *)
								x0 := x00 - (dx*(b-y00)) / dy; y0 := b;
							END;
						ELSIF y0 > b THEN
							(* intersection with y = bottom *)
							x0 := x00 - (dx*(b-y00)) / dy; y0 := b;
							IF x0 < l THEN
								(* intersection with x = left *)
								y0 := y00 - (dy*(l-x00)) / dx; x0 := l;
							END;
						END;

						IF x1 > r THEN
							(* intersection with x = right *)
							y1 := y00 - (dy*(r-x00)) / dx; x1 := r;
							IF y1 < t THEN
								(* intersection with y = tody *)
								x1 := x00 - (dx*(t-y00)) / dy; y1 := t;
							END;
						ELSIF y1 < t THEN
							(* intersection with y = tody *)
							x1 := x00 - (dx*(t-y00)) / dy; y1 := t;
							IF x1 > r THEN
								(* intersection with x = right *)
								y1 := y00 - (dy*(r-x00)) / dx; x1 := r;
							END;
						END;

						ASSERT(x0 >= l);
						ASSERT(y0 <= b);
						ASSERT(x1 <= r);
						ASSERT(y1 >= t);

					ELSE
						RETURN FALSE;
					END;
				ELSE
					RETURN FALSE;
				END;

			ELSE (* x0 >= x1 *)

				IF (x1 <= r) & (x0 >= l) THEN

					IF y0 <= y1 THEN

						IF (y0 <= b) & (y1 >= t) THEN

							x00 := x0;
							y00 := y0;
							dx := -dx;

							IF x0 > r THEN
								(* intersection with x = right *)
								y0 := y00 - (dy*(r-x00)) / dx; x0 := r;
								IF y0 < t THEN
									(* intersection with y = tody *)
									x0 := x00 - (dx*(t-y00)) / dy; y0 := t;
								END;
							ELSIF y0 < t THEN
								(* intersection with y = tody *)
								x0 := x00 - (dx*(t-y00)) / dy; y0 := t;
								IF x0 > r THEN
									(* intersection with x = right *)
									y0 := y00 - (dy*(r-x00)) / dx; x0 := r;
								END;
							END;

							IF x1 < l THEN
								(* intersection with x = left *)
								y1 := y00 - (dy*(l-x00)) / dx; x1 := l;
								IF y1 > b THEN
									(* intersection with y = bottom *)
									x1 := x00 - (dx*(b-y00)) / dy; y1 := b;
								END;
							ELSIF y1 > b THEN
								(* intersection with y = bottom *)
								x1 := x00 - (dx*(b-y00)) / dy; y1 := b;
								IF x1 < l THEN
									(* intersection with x = left *)
									y1 := y00 - (dy*(l-x00)) / dx; x1 := l;
								END;
							END;

							ASSERT(x0 <= r);
							ASSERT(y0 >= t);
							ASSERT(x1 >= l);
							ASSERT(y1 <= b);

						ELSE
							RETURN FALSE;
						END;

					ELSIF (y1 <= b) & (y0 >= t) THEN (* dy < 0, dx < 0 *)

						x00 := x0;
						y00 := y0;
						dy := -dy;
						dx := -dx;

						IF x0 > r THEN
							(* intersection with x = right *)
							y0 := y00 + (dy*(r-x00)) / dx; x0 := r;
							IF y0 > b THEN
								(* intersection with y = bottom *)
								x0 := x00 + (dx*(b-y00)) / dy; y0 := b;
							END;
						ELSIF y0 > b THEN
							(* intersection with y = bottom *)
							x0 := x00 + (dx*(b-y00)) / dy; y0 := b;
							IF x0 > r THEN
								(* intersection with x = right *)
								y0 := y00 + (dy*(r-x00)) / dx; x0 := r;
							END;
						END;

						IF x1 < l THEN
							(* intersection with x = left *)
							y1 := y00 + (dy*(l-x00)) / dx; x1 := l;
							IF y1 < t THEN
								(* intersection with y = tody *)
								x1 := x00 + (dx*(t-y00)) / dy; y1 := t;
							END;
						ELSIF y1 < t THEN
							(* intersection with y = tody *)
							x1 := x00 + (dx*(t-y00)) / dy; y1 := t;
							IF x1 < l THEN
								(* intersection with x = left *)
								y1 := y00 + (dy*(l-x00)) / dx; x1 := l;
							END;
						END;

						ASSERT(x0 <= r);
						ASSERT(y0 <= b);
						ASSERT(x1 >= l);
						ASSERT(y1 >= t);

					ELSE
						RETURN FALSE;
					END;
				ELSE
					RETURN FALSE;
				END;
			END;
		END;

		RETURN TRUE
	END ClipLineReal;

END WMGraphicsSmooth.

