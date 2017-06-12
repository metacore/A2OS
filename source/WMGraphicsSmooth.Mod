(**
	AUTHOR: "Alexey Morozov";
	PURPOSE: "Smooth (antialiased) graphics";
*)
MODULE WMGraphicsSmooth;

IMPORT SYSTEM, Raster, Strings, WMGraphics, WMRectangles;

CONST
	(** Line cap types *)
	CapButt* = 0; (** A flat edge is added to each end of the line;  *)
	CapRound* = 1; (** A rounded end cap is added to each end of the line; *)
	CapSquare* = 2; (** A square end cap is added to each end of the line;  *)
	CapNone* = 3; (** No use of any cap *)

TYPE

	Real* = WMGraphics.Real;

	(**
		Canvas used for smooth (antialiased) graphics
	*)
	Canvas* = OBJECT(WMGraphics.BufferCanvas)
	VAR
		lineWidth-: Real; (** line width in pixels *)
		capType-: LONGINT; (** line cap type *)

		rasterMode: Raster.Mode;
		colorMap: ARRAY 256 OF Raster.Pixel;

		halfLineWidth: Real;
		halfLineWidthBy255: Real;
		invLineWidthBy255: Real;
		halfLineWidthSqr: Real;

		PROCEDURE &New(img : Raster.Image);
		VAR firstTime: BOOLEAN;
		BEGIN
			firstTime := generator = NIL;
			New^(img);
			IF firstTime THEN (*! for cases when the same canvas is reused with another image *)
				generator := Strings.NewString("WMGraphicsSmooth.GenCanvas");
				SetLineWidth(1);
				SetLineCap(CapRound);
				SetColor(WMGraphics.Blue);

				Raster.InitMode(rasterMode,Raster.srcOverDst);
				Raster.Bind(rasterMode, Raster.PixelFormat, img.fmt);
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
			FOR i := 0 TO 255 DO Raster.SetRGBA(colorMap[i],r,g,b,a - (s*i+128) DIV 256); END;
		END SetColor;

		(**
			Set line width in pixels
		*)
		PROCEDURE SetLineWidth*(w: Real);
		BEGIN
			IF w # lineWidth THEN
				IF w < 0.1 THEN w := 0.1; END;
				lineWidth := w;
				halfLineWidth := 0.5*lineWidth;
				halfLineWidthBy255 := 255*halfLineWidth;
				invLineWidthBy255 := 255/lineWidth;
				halfLineWidthSqr := halfLineWidth*halfLineWidth;
			END;
		END SetLineWidth;

		(**
			Setup line cap type
		*)
		PROCEDURE SetLineCap*(lineCap: LONGINT);
		BEGIN
			capType := MIN(CapSquare,MAX(CapButt,lineCap));
		END SetLineCap;

		(**
			Draw an antialiased line represented by real-valued coordinates of the starting and end points
		*)
		PROCEDURE LineReal*(x0, y0, x1, y1: Real; lineColor: WMGraphics.Color; mode: LONGINT);
		BEGIN

			IF lineColor # color THEN SetColor(lineColor); END;

			(* transform local coordinates to the global coordinate system *)
			x0 := x0 + dx; y0 := y0 + dy;
			x1 := x1 + dx; y1 := y1 + dy;

			(* check whether the line crosses the canvas rectangle with account of line width and a few pixels for antialiasing *)
			IF ~ClipLineReal(limits.l-lineWidth-2,limits.t-lineWidth-2,limits.r+lineWidth+1,limits.b+lineWidth+1, x0,y0,x1,y1) THEN
				RETURN;
			END;
			IF x0 <= x1 THEN
				IF lineWidth <= 0.5 THEN
					DrawThinLine(x0,y0, x1,y1);
				ELSE
					DrawThickLine(x0,y0, x1,y1);
				END;
			ELSE
				IF lineWidth <= 0.5 THEN
					DrawThinLine(x1,y1, x0,y0);
				ELSE
					DrawThickLine(x1,y1, x0,y0);
				END;
			END;
		END LineReal;

		PROCEDURE Disk*(x0, y0: Real; radius: Real; color: WMGraphics.Color; mode: LONGINT);
		BEGIN
			IF color # SELF.color THEN SetColor(color); END;
			DrawDisk(x0,y0,radius);
		END Disk;

		PROCEDURE DrawDisk(x0, y0, radius: Real);
		VAR
			yend, w: LONGINT;
			err: Real;
			inner, outer: WMRectangles.Rectangle;
			d, radiusSqr, s: Real;

			PROCEDURE DrawLeftRight(x, y, yend: LONGINT; left: BOOLEAN);
			VAR
				xx, incx, k, m: LONGINT;
				v, v0, v1: Real;
			BEGIN
				IF left THEN incx := -1; ELSE incx := 1; END;

				v0 := x - x0; v1 := y - y0;
				err := v0*v0 + v1*v1 - radiusSqr;

				v0 := 1 + 2*incx*v0;
				v1 := 1 + 2*v1; m := 0;

				WHILE y <= yend DO
					xx := x; v := err; k := 0;
					REPEAT
						w := ENTIER(v*s);
						IF w < 0 THEN
							Raster.Put(img,xx,y,colorMap[0],rasterMode);
						ELSIF w <= 255 THEN
							Raster.Put(img,xx,y,colorMap[w],rasterMode);
						END;
						v := v + v0 + k; INC(k,2); (*v := v + 1 + 2*incx*(xx-x0);*)
						INC(xx,incx);
					UNTIL w >= 255;

					err := err + v1 + m; INC(m,2); (*err := err + 1 + 2*(y - y0);*)
					INC(y);
				END;
			END DrawLeftRight;

			PROCEDURE DrawTopBottom(x, y, xend: LONGINT; top: BOOLEAN);
			VAR
				yy, incy, k, m: LONGINT;
				v, v0, v1: Real;
			BEGIN
				IF top THEN incy := -1; ELSE incy := 1; END;

				v0 := x - x0; v1 := y - y0;
				err := v0*v0 + v1*v1 - radiusSqr;

				v0 := 1 + 2*v0;
				v1 := 1 + 2*incy*v1; k := 0;

				WHILE x <= xend DO
					yy := y; v := err; m := 0;
					REPEAT
						w := ENTIER(v*s);
						IF w < 0 THEN
							Raster.Put(img,x,yy,colorMap[0],rasterMode);
						ELSIF w <= 255 THEN
							Raster.Put(img,x,yy,colorMap[w],rasterMode);
						END;
						v := v + v1 + m; INC(m,2); (*v := v + 1 + 2*incy*(yy-y0);*)
						INC(yy,incy);
					UNTIL w >= 255;

					err := err + v0 + k; INC(k,2); (*err := err + 1 + 2*(x - x0);*)
					INC(x);
				END;
			END DrawTopBottom;

		BEGIN
			(* outer rectangle (with account of a few pixels for antialiasing) *)
			outer.l := ENTIER(x0-radius)-4;
			outer.r := ENTIER(x0+radius)+3;
			outer.t := ENTIER(y0-radius)-4;
			outer.b := ENTIER(y0+radius)+3;

			IF WMGraphics.ClipRect IN clipMode THEN WMRectangles.ClipRect(outer, clipRect);END;
			WMRectangles.ClipRect(outer, limits);
			IF ~WMRectangles.RectEmpty(outer) THEN
				(* inner rectangle *)
				d := radius*0.707106781186547; (* half of the edge of the square inside the circle *)
				inner.l := ENTIER(x0-d)+1;
				inner.r := ENTIER(x0+d)+1;
				inner.t := ENTIER(y0-d)+1;
				inner.b := ENTIER(y0+d)+1;

				(*
					Scaling factor to compute the distance from the circle multiplied by 255;
					this computation uses first order Taylor series approximation of dist(x,y) = sqrt((x-x0)*(x-x0)+(y-y0)*(y-y0)) - radius =
					sqrt(err+radius*radius) - radius ~ err/(2*radius),
					where err(x,y) = (x-x0)*(x-x0)+(y-y0)*(y-y0) - radius*radius
				*)
				s := (255/2)/radius; (* scaling factor for computing alpha map index *)
				radiusSqr := radius*radius;

				IF ~WMRectangles.RectEmpty(inner) & WMRectangles.IsContained(outer,inner) THEN
					Raster.Fill(img, inner.l, inner.t, inner.r, inner.b, colorMap[0], rasterMode); (*Fill(inner,color,WMGraphics.ModeSrcOverDst);*)
				ELSE
					WMRectangles.ClipRect(inner, outer);
					IF ~WMRectangles.RectEmpty(inner) THEN
						Raster.Fill(img, inner.l, inner.t, inner.r, inner.b, colorMap[0], rasterMode);
					END;
				END;

				IF inner.l > outer.l THEN DrawLeftRight(inner.l-1,inner.t-2,inner.b+1,TRUE); END;
				IF inner.r <= outer.r THEN DrawLeftRight(inner.r,inner.t-2,inner.b+1,FALSE); END;
				IF inner.t > outer.t THEN DrawTopBottom(inner.l,inner.t-1,inner.r-1,TRUE); END;
				IF inner.b <= outer.b THEN DrawTopBottom(inner.l,inner.b,inner.r-1,FALSE); END;
			END;

		END DrawDisk;

		PROCEDURE PutPixel(x, y: LONGINT; colorMapIndex: LONGINT);
		VAR bit: LONGINT; adr: ADDRESS;
		BEGIN
			(*
				Implements Raster.Put(img,x,y,colorMap[colorMapIndex],rasterMode);
			*)
			IF (0 > x) OR (x >= img.width) OR (0 > y) OR (y >= img.height) THEN RETURN END;
			bit := x * img.fmt.bpp; adr := img.adr + y * img.bpr + bit DIV 8; bit := bit MOD 8;
			(*Raster.Bind(rasterMode, Raster.PixelFormat, img.fmt);*)
			rasterMode.transfer(rasterMode, ADDRESSOF(colorMap[colorMapIndex]), 0, adr, bit, 1)
		END PutPixel;

		PROCEDURE PutPixelSwapped(x, y: LONGINT; colorMapIndex: LONGINT);
		VAR bit: LONGINT; adr: ADDRESS;
		BEGIN
			(*
				Implements Raster.Put(img,y,x,colorMap[colorMapIndex],rasterMode);
			*)
			IF (0 > y) OR (y >= img.width) OR (0 > x) OR (x >= img.height) THEN RETURN END;
			bit := y * img.fmt.bpp; adr := img.adr + x * img.bpr + bit DIV 8; bit := bit MOD 8;
			(*Raster.Bind(rasterMode, Raster.PixelFormat, img.fmt);*)
			rasterMode.transfer(rasterMode, ADDRESSOF(colorMap[colorMapIndex]), 0, adr, bit, 1)
		END PutPixelSwapped;

		PROCEDURE DrawThinLine(x0, y0, x1, y1: Real);
		VAR
			incx, incy, x, y, yy, xend, xendCapStart, xendCapNone, xendCapEnd: LONGINT;
			dx, dy, sdx, sdy, dc, dm, dd, d0, d1, dr0, dr1, v, v0, v1, w: Real;

			putPixel: PROCEDURE{DELEGATE}(x, y: LONGINT; colorMapIndex: LONGINT);

			PROCEDURE DrawCapNone;
			BEGIN
				WHILE x # xend DO

					dc := dm - dd; (* dc = sdist(x,y) *)

					w := ABS(dc);
					IF w <= 0 THEN putPixel(x,y,0);
					ELSIF w <= 255 THEN putPixel(x,y,ENTIER(w));
					END;

					v := dc - dx;
					w := ABS(v);
					IF w <= 255 THEN
						yy := y - incy;
						IF w <= 0 THEN putPixel(x,yy,0); ELSE putPixel(x,yy,ENTIER(w)); END;
						w := -v + dx;
						IF w <= 255 THEN
							yy := y - incy;
							IF w <= 0 THEN putPixel(x,yy,0); ELSE putPixel(x,yy,ENTIER(w)); END;
						END;
					END;

					v := dc + dx;
					w := ABS(v);
					IF w <= 255 THEN
						yy := y + incy;
						IF w <= 0 THEN putPixel(x,yy,0); ELSE putPixel(x,yy,ENTIER(w)); END;
						w := v + dx;
						IF w <= 255 THEN
							yy := y + incy;
							IF w <= 0 THEN putPixel(x,yy,0); ELSE putPixel(x,yy,ENTIER(w)); END;
						END;
					END;

					IF dm < 0 THEN
						INC(y,incy);
						dm := dm + dx;
					END;
					dm := dm - dy;
					INC(x,incx);
				END;
			END DrawCapNone;

			PROCEDURE DrawCapButt;
			BEGIN
				WHILE x # xend DO

					dc := dm - dd; (* dc = sdist(x,y) *)

					IF (d0 >= 0) & (d1 <= 0) THEN
						w := ABS(dc);
						IF w <= 0 THEN putPixel(x,y,0);
						ELSIF w <= 255 THEN putPixel(x,y,ENTIER(w));
						END;
					ELSE
						w := MAX(MAX(-d0,d1),ABS(dc));
						IF w <= 255 THEN putPixel(x,y,ENTIER(w));
						END;
					END;

					v := dc - dx;
					w := ABS(v);
					IF w <= 255 THEN
						yy := y - incy; v0 := d0 - sdy; v1 := d1 - sdy;
						w := MAX(MAX(-v0,v1),w);
						IF w <= 255 THEN
							IF w <= 0 THEN putPixel(x,yy,0);
							ELSE putPixel(x,yy,ENTIER(w));
							END;
							w := -v + dx;
							IF w <= 255 THEN
								yy := y - incy; v0 := v0 - sdy; v1 := v1 - sdy;
								w := MAX(MAX(-v0,v1),w);
								IF w <= 0 THEN putPixel(x,yy,0);
								ELSIF w <= 255 THEN putPixel(x,yy,ENTIER(w));
								END;
							END;
						END;
					END;

					v := dc + dx;
					w := ABS(v);
					IF w <= 255 THEN
						yy := y + incy; v0 := d0 + sdy; v1 := d1 + sdy;
						w := MAX(MAX(-v0,v1),w);
						IF w <= 255 THEN
							IF w <= 0 THEN putPixel(x,yy,0);
							ELSE putPixel(x,yy,ENTIER(w));
							END;
							w := v + dx;
							IF w <= 255 THEN
								yy := y + incy; v0 := v0 + sdy; v1 := v1 + sdy;
								w := MAX(MAX(-v0,v1),w);
								IF w <= 0 THEN putPixel(x,yy,0);
								ELSIF w <= 255 THEN putPixel(x,yy,ENTIER(w));
								END;
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
			END DrawCapButt;

			PROCEDURE DrawCapRound;
			VAR
				x_x0, x_x1, y_y0, y_y1: Real;
			BEGIN
				WHILE x # xend DO

					x_x0 := x - x0; x_x0 := x_x0*x_x0 - 0.01;
					x_x1 := x - x1; x_x1 := x_x1*x_x1 - 0.01;

					dc := dm - dd; (* dc = sdist(x,y) *)

					IF (d0 >= 0) & (d1 <= 0) THEN
						w := ABS(dc);
						IF w <= 0 THEN putPixel(x,y,0);
						ELSIF w <= 255 THEN putPixel(x,y,ENTIER(w));
						END;
					ELSE
						IF d0 < 0 THEN
							y_y0 := y - y0;
							w := (x_x0 + y_y0*y_y0)*(255/0.1);
						ELSE
							y_y1 := y - y1;
							w := (x_x1 + y_y1*y_y1)*(255/0.1);
						END;
						IF w <= 0 THEN putPixel(x,y,0);
						ELSIF w <= 255 THEN putPixel(x,y,ENTIER(w));
						END;
					END;

					v := dc - dx; w := ABS(v);
					IF w <= 255 THEN
						yy := y - incy; v0 := d0 - sdy; v1 := d1 - sdy;
						IF v0 < 0 THEN
							y_y0 := yy - y0; w := (x_x0 + y_y0*y_y0)*(255/0.1);
						ELSIF v1 > 0 THEN
							y_y1 := yy - y1; w := (x_x1 + y_y1*y_y1)*(255/0.1);
						END;
						IF w <= 255 THEN
							IF w <= 0 THEN putPixel(x,yy,0);
							ELSE putPixel(x,yy,ENTIER(w));
							END;
						END;
						yy := y - incy; v0 := v0 - sdy; v1 := v1 - sdy;
						w := -v + dx;
						IF w <= 255 THEN
							IF v0 < 0 THEN
								y_y0 := yy - y0; w := (x_x0 + y_y0*y_y0)*(255/0.1);
							ELSIF v1 > 0 THEN
								y_y1 := yy - y1; w := (x_x1 + y_y1*y_y1)*(255/0.1);
							END;
							IF w <= 255 THEN
								IF w <= 0 THEN putPixel(x,yy,0);
								ELSE putPixel(x,yy,ENTIER(w));
								END;
							END;
						END;
					END;

					v := dc + dx; w := ABS(v);
					IF w <= 255 THEN
						yy := y + incy; v0 := d0 + sdy; v1 := d1 + sdy;
						IF v0 < 0 THEN
							y_y0 := yy - y0; w := (x_x0 + y_y0*y_y0)*(255/0.1);
						ELSIF v1 > 0 THEN
							y_y1 := yy - y1; w := (x_x1 + y_y1*y_y1)*(255/0.1);
						END;
						IF w <= 255 THEN
							IF w <= 0 THEN putPixel(x,yy,0);
							ELSE putPixel(x,yy,ENTIER(w));
							END;
						END;
						yy := y + incy; v0 := v0 + sdy; v1 := v1 + sdy;
						w := v + dx;
						IF w <= 255 THEN
							IF v0 < 0 THEN
								y_y0 := yy - y0; w := (x_x0 + y_y0*y_y0)*(255/0.1);
							ELSIF v1 > 0 THEN
								y_y1 := yy - y1; w := (x_x1 + y_y1*y_y1)*(255/0.1);
							END;
							IF w <= 255 THEN
								IF w <= 0 THEN putPixel(x,yy,0);
								ELSE putPixel(x,yy,ENTIER(w));
								END;
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
			END DrawCapRound;

		BEGIN

			dx := x1 - x0;
			dy := y1 - y0;

			IF ABS(dy) > ABS(dx) THEN (* slope > 1 *)
				v := x0; x0 := y0; y0 := v;
				v := x1; x1 := y1; y1 := v;
				v := dx; dx := dy; dy := v;
				putPixel := PutPixelSwapped;
			ELSE
				putPixel := PutPixel;
			END;

			IF dx >= 0 THEN incx := 1; ELSE incx := -1; END;
			IF dy >= 0 THEN incy := 1; ELSE incy := -1; END;

			(* normalize ranges by the distance between the point- will be used for computing the signed distance to the line *)
			dd := InvSqrt(dx*dx + dy*dy);
			dx := dx*dd; dy := dy*dd;

			sdx := dx; sdy := dy; (* differences used for lines perpendicular to the original line *)

			(* account for the signs of the coordinate differences *)
			IF ~((dx >= 0) & (dy >= 0)) OR (((dx < 0) & (dy < 0))) THEN
				dx := -dx; dy := -dy;
			END;

			IF capType = CapButt THEN
				w := halfLineWidth+2;
				v0 := w*sdx;
				x := ENTIER(x0 - v0);
				y := ENTIER(y0 - w*sdy);

				v1 := halfLineWidth*dy; (* move along the line perpendicular to the target line and going through the point (x0,y0) *)
				xendCapStart := ENTIER(x0 + v1)+incx;
				xendCapNone := ENTIER(x1 - v1)-incx;
				xendCapEnd := ENTIER(x1 + v0);
			ELSIF capType = CapRound THEN
				w := 1.4142135623731*halfLineWidth+2; (* halfLineWidth*sqrt(2) precisely *)
				v0 := w*sdx;
				x := ENTIER(x0 - v0);
				y := ENTIER(y0 - w*sdy);

				v1 := halfLineWidth*dy; (* move along the line perpendicular to the target line and going through the point (x0,y0) *)
				xendCapStart := ENTIER(x0 + v1)+incx;
				xendCapNone := ENTIER(x1 - v1)-incx;
				xendCapEnd := ENTIER(x1 + v0);
			ELSE
				x := ENTIER(x0);
				y := ENTIER(y0);
				xendCapEnd := ENTIER(x1);
			END;

			(* scaling to avoid multiplication by 255 for computing color map index *)
			dx := dx*255;
			dy := dy*255;
			sdx := sdx*255;
			sdy := sdy*255;

			dm := dx*(y + 0.5*incy - y0) - dy*((x+incx) - x0); (* signed distance to the line at the midpoint dm = sdist(x+incx,y+0.5*incy) *)
			dd := dx*0.5*incy - dy*incx; (* offset for computing signed distance at the current point (x,y-incy) *)
			d0 := sdy*(y - y0) + sdx*(x - x0); (* signed distance to the line that goes through (x0,y0) and perpendicular to the original line (sdist0)  *)
			d1 := sdy*(y - y1) + sdx*(x - x1); (* signed distance to the line taht goes through (x1,y1) and perpendicular to the original line (sdist1) *)

			(* account for the signs of the increments *)
			IF incx < 0 THEN dy := -dy; sdx := -sdx; END;
			IF incy < 0 THEN dx := -dx; sdy := -sdy; END;

			CASE capType OF
				|CapButt:
					IF ((xendCapNone - xendCapStart)*incx > 1) & ((xendCapEnd - xendCapNone)*incx > 1) THEN
						xend := xendCapStart;
						DrawCapButt;
						xend := xendCapNone;
						DrawCapNone;
						(* compute d0 and d1 distances at the current point *)
						IF incx > 0 THEN v0 := sdx; ELSE v0 := -sdx; END;
						IF incy > 0 THEN v1 := sdy; ELSE v1 := -sdy; END;
						d0 := v1*(y - y0) + v0*(x - x0);
						d1 := v1*(y - y1) + v0*(x - x1);
					END;
					xend := xendCapEnd;
					DrawCapButt;
				|CapRound:
					IF ((xendCapNone - xendCapStart)*incx > 1) & ((xendCapEnd - xendCapNone)*incx > 1) THEN
						xend := xendCapStart;
						DrawCapRound;
						xend := xendCapNone;
						DrawCapNone;
						(* compute d0 and d1 distances at the current point *)
						IF incx > 0 THEN v0 := sdx; ELSE v0 := -sdx; END;
						IF incy > 0 THEN v1 := sdy; ELSE v1 := -sdy; END;
						d0 := v1*(y - y0) + v0*(x - x0);
						d1 := v1*(y - y1) + v0*(x - x1);
					END;
					xend := xendCapEnd;
					DrawCapRound;
			ELSE
				xend := xendCapEnd;
				DrawCapNone;
			END;
		END DrawThinLine;

		PROCEDURE DrawThickLine(x0, y0, x1, y1: Real);
		VAR
			incx, incy, x, y, yy, xend, xendCapStart, xendCapNone, xendCapEnd: LONGINT;
			dx, dy, sdx, sdy, dc, dm, dd, d0, d1, dr0, dr1, v, v0, v1, w: Real;

			putPixel: PROCEDURE{DELEGATE}(x, y: LONGINT; colorMapIndex: LONGINT);

			PROCEDURE DrawCapNone;
			BEGIN
				WHILE x # xend DO

					dc := dm - dd; (* dc = sdist(x,y) *)

					w := ABS(dc)-halfLineWidthBy255;
					IF w <= 0 THEN putPixel(x,y,0);
					ELSIF w <= 255 THEN putPixel(x,y,ENTIER(w));
					END;

					yy := y;
					v := dc - dx;
					w := ABS(v) - halfLineWidthBy255;
					WHILE w <= 255 DO
						DEC(yy,incy);
						IF w <= 0 THEN putPixel(x,yy,0);
						ELSE putPixel(x,yy,ENTIER(w));
						END;
						v := v - dx; w := -v - halfLineWidthBy255;
					END;

					yy := y;
					v := dc + dx;
					w := ABS(v) - halfLineWidthBy255;
					WHILE w <= 255 DO
						INC(yy,incy);
						IF w <= 0 THEN putPixel(x,yy,0);
						ELSE putPixel(x,yy,ENTIER(w));
						END;
						v := v + dx; w := v - halfLineWidthBy255;
					END;

					IF dm < 0 THEN
						INC(y,incy);
						dm := dm + dx;
					END;
					dm := dm - dy;
					INC(x,incx);
				END;
			END DrawCapNone;

			PROCEDURE DrawCapButt;
			BEGIN
				WHILE x # xend DO

					dc := dm - dd; (* dc = sdist(x,y) *)

					IF (d0 >= 0) & (d1 <= 0) THEN
						w := ABS(dc)-halfLineWidthBy255;
						IF w <= 0 THEN putPixel(x,y,0);
						ELSIF w <= 255 THEN putPixel(x,y,ENTIER(w));
						END;
					ELSE
						w := MAX(MAX(-d0,d1),ABS(dc)-halfLineWidthBy255);
						IF w <= 255 THEN putPixel(x,y,ENTIER(w));
						END;
					END;

					yy := y;
					v := dc - dx;
					w := ABS(v) - halfLineWidthBy255;
					IF w <= 255 THEN
						v0 := d0; v1 := d1;
						LOOP
							DEC(yy,incy); v0 := v0 - sdy; v1 := v1 - sdy;
							w := MAX(MAX(-v0,v1),w);
							IF w <= 0 THEN putPixel(x,yy,0);
							ELSIF w <= 255 THEN putPixel(x,yy,ENTIER(w));
							END;
							v := v - dx; w := -v - halfLineWidthBy255;
							IF w > 255 THEN EXIT; END;
						END;
					END;

					yy := y;
					v := dc + dx;
					w := ABS(v) - halfLineWidthBy255;
					IF w <= 255 THEN
						v0 := d0; v1 := d1;
						LOOP
							INC(yy,incy); v0 := v0 + sdy; v1 := v1 + sdy;
							w := MAX(MAX(-v0,v1),w);
							IF w <= 0 THEN putPixel(x,yy,0);
							ELSIF w <= 255 THEN putPixel(x,yy,ENTIER(w));
							END;
							v := v + dx; w := v - halfLineWidthBy255;
							IF w > 255 THEN EXIT; END;
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
			END DrawCapButt;

			PROCEDURE DrawCapRound;
			VAR
				x_x0, x_x1, y_y0, y_y1: Real;
			BEGIN
				WHILE x # xend DO

					x_x0 := x - x0; x_x0 := x_x0*x_x0 - halfLineWidthSqr;
					x_x1 := x - x1; x_x1 := x_x1*x_x1 - halfLineWidthSqr;

					dc := dm - dd; (* dc = sdist(x,y) *)

					IF (d0 >= 0) & (d1 <= 0) THEN
						w := ABS(dc)-halfLineWidthBy255;
						IF w <= 0 THEN putPixel(x,y,0);
						ELSIF w <= 255 THEN putPixel(x,y,ENTIER(w));
						END;
					ELSE
						IF d0 < 0 THEN
							y_y0 := y - y0;
							w := (x_x0 + y_y0*y_y0)*invLineWidthBy255;
						ELSE
							y_y1 := y - y1;
							w := (x_x1 + y_y1*y_y1)*invLineWidthBy255;
						END;
						IF w <= 0 THEN putPixel(x,y,0);
						ELSIF w <= 255 THEN putPixel(x,y,ENTIER(w));
						END;
					END;

					yy := y;
					v := dc - dx; v0 := d0; v1 := d1;
					w := ABS(v) - halfLineWidthBy255;
					WHILE w <= 255 DO
						DEC(yy,incy); v0 := v0 - sdy; v1 := v1 - sdy;
						IF v0 < 0 THEN
							y_y0 := yy - y0;
							w := (x_x0 + y_y0*y_y0)*invLineWidthBy255;
						ELSIF v1 > 0 THEN
							y_y1 := yy - y1;
							w := (x_x1 + y_y1*y_y1)*invLineWidthBy255;
						END;
						IF w <= 0 THEN putPixel(x,yy,0);
						ELSIF w <= 255 THEN putPixel(x,yy,ENTIER(w));
						END;
						v := v - dx; w := -v - halfLineWidthBy255;
					END;

					yy := y;
					v := dc + dx; v0 := d0; v1 := d1;
					w := ABS(v) - halfLineWidthBy255;
					WHILE w <= 255 DO
						INC(yy,incy); v0 := v0 + sdy; v1 := v1 + sdy;
						IF v0 < 0 THEN
							y_y0 := yy - y0;
							w := (x_x0 + y_y0*y_y0)*invLineWidthBy255;
						ELSIF v1 > 0 THEN
							y_y1 := yy - y1;
							w := (x_x1 + y_y1*y_y1)*invLineWidthBy255;
						END;
						IF w <= 0 THEN putPixel(x,yy,0);
						ELSIF w <= 255 THEN putPixel(x,yy,ENTIER(w));
						END;
						v := v + dx; w := v - halfLineWidthBy255;
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
			END DrawCapRound;

		BEGIN

			dx := x1 - x0;
			dy := y1 - y0;

			IF ABS(dy) > ABS(dx) THEN (* slope > 1 *)
				v := x0; x0 := y0; y0 := v;
				v := x1; x1 := y1; y1 := v;
				v := dx; dx := dy; dy := v;
				putPixel := PutPixelSwapped;
			ELSE
				putPixel := PutPixel;
			END;

			IF dx >= 0 THEN incx := 1; ELSE incx := -1; END;
			IF dy >= 0 THEN incy := 1; ELSE incy := -1; END;

			(* normalize ranges by the distance between the point- will be used for computing the signed distance to the line *)
			dd := InvSqrt(dx*dx + dy*dy);
			dx := dx*dd; dy := dy*dd;

			sdx := dx; sdy := dy; (* differences used for lines perpendicular to the original line *)

			(* account for the signs of the coordinate differences *)
			IF ~((dx >= 0) & (dy >= 0)) OR (((dx < 0) & (dy < 0))) THEN
				dx := -dx; dy := -dy;
			END;

			IF capType = CapButt THEN
				w := halfLineWidth+2;
				v0 := w*sdx;
				x := ENTIER(x0 - v0);
				y := ENTIER(y0 - w*sdy);

				v1 := halfLineWidth*dy; (* move along the line perpendicular to the target line and going through the point (x0,y0) *)
				xendCapStart := ENTIER(x0 + v1)+incx;
				xendCapNone := ENTIER(x1 - v1)-incx;
				xendCapEnd := ENTIER(x1 + v0);
			ELSIF capType = CapRound THEN
				w := 1.4142135623731*halfLineWidth+2; (* halfLineWidth*sqrt(2) precisely *)
				v0 := w*sdx;
				x := ENTIER(x0 - v0);
				y := ENTIER(y0 - w*sdy);

				v1 := halfLineWidth*dy; (* move along the line perpendicular to the target line and going through the point (x0,y0) *)
				xendCapStart := ENTIER(x0 + v1)+incx;
				xendCapNone := ENTIER(x1 - v1)-incx;
				xendCapEnd := ENTIER(x1 + v0);
			ELSE
				x := ENTIER(x0);
				y := ENTIER(y0);
				xendCapEnd := ENTIER(x1);
			END;

			(* scaling to avoid multiplication by 255 for computing color map index *)
			dx := dx*255;
			dy := dy*255;
			sdx := sdx*255;
			sdy := sdy*255;

			dm := dx*(y + 0.5*incy - y0) - dy*((x+incx) - x0); (* signed distance to the line at the midpoint dm = sdist(x+incx,y+0.5*incy) *)
			dd := dx*0.5*incy - dy*incx; (* offset for computing signed distance at the current point (x,y-incy) *)
			d0 := sdy*(y - y0) + sdx*(x - x0); (* signed distance to the line that goes through (x0,y0) and perpendicular to the original line (sdist0)  *)
			d1 := sdy*(y - y1) + sdx*(x - x1); (* signed distance to the line taht goes through (x1,y1) and perpendicular to the original line (sdist1) *)

			(* account for the signs of the increments *)
			IF incx < 0 THEN dy := -dy; sdx := -sdx; END;
			IF incy < 0 THEN dx := -dx; sdy := -sdy; END;

			CASE capType OF
				|CapButt:
					IF ((xendCapNone - xendCapStart)*incx > 1) & ((xendCapEnd - xendCapNone)*incx > 1) THEN
						xend := xendCapStart;
						DrawCapButt;
						xend := xendCapNone;
						DrawCapNone;
						(* compute d0 and d1 distances at the current point *)
						IF incx > 0 THEN v0 := sdx; ELSE v0 := -sdx; END;
						IF incy > 0 THEN v1 := sdy; ELSE v1 := -sdy; END;
						d0 := v1*(y - y0) + v0*(x - x0);
						d1 := v1*(y - y1) + v0*(x - x1);
					END;
					xend := xendCapEnd;
					DrawCapButt;
				|CapRound:
					IF ((xendCapNone - xendCapStart)*incx > 1) & ((xendCapEnd - xendCapNone)*incx > 1) THEN
						xend := xendCapStart;
						DrawCapRound;
						xend := xendCapNone;
						DrawCapNone;
						(* compute d0 and d1 distances at the current point *)
						IF incx > 0 THEN v0 := sdx; ELSE v0 := -sdx; END;
						IF incy > 0 THEN v1 := sdy; ELSE v1 := -sdy; END;
						d0 := v1*(y - y0) + v0*(x - x0);
						d1 := v1*(y - y1) + v0*(x - x1);
					END;
					xend := xendCapEnd;
					DrawCapRound;
			ELSE
				xend := xendCapEnd;
				DrawCapNone;
			END;
		END DrawThickLine;

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
	VAR y: Real;
	BEGIN
		y := SYSTEM.VAL(REAL,0x5f3759df - SYSTEM.VAL(LONGINT,x) DIV 2); (* ~4% of error *)
		RETURN y * ( 1.5E0 - y * y * (x * 0.5E0) ); (* ~0.15% of error *)
	END InvSqrt;

	(*
		Find intersection of a line with a given rectangle

		l, r, t, b: left,right,top,bottom coordinates of the rectangle
		x0, y0: starting line point
		x1, y1: end line point

		Intersection points are returned in x0, y0, x1, y1
	*)
	PROCEDURE ClipLineReal(l, t, r, b: Real; VAR x0, y0, x1, y1: Real): BOOLEAN;
	VAR
		dy, dx, x00, y00: Real;
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

SystemTools.FreeDownTo WMGraphicsSmooth ~

