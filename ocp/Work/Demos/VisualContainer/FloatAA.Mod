MODULE FloatAA; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	Raster, WMGraphics, Strings, KernelLog;

PROCEDURE Line*(img:Raster.Image;x0,y0,x1,y1:REAL;color:LONGINT);
VAR
	l:REAL;
	dx,dy:REAL;
BEGIN
	IF ABS(x0-x1)>ABS(y0-y1) THEN
		IF x0>x1 THEN
			l:=x0;x0:=x1;x1:=l;
			l:=y0;y0:=y1;y1:=l
		END;
		dx:=1;
		dy:=(y1-y0)/ABS(x1-x0);
		WHILE x0<x1 DO
			PutPixel(img,x0,y0,color);
			x0:=x0+dx;
			y0:=y0+dy
		END
	ELSE
		IF y0>y1 THEN
			l:=x0;x0:=x1;x1:=l;
			l:=y0;y0:=y1;y1:=l;
		END;

		dy:=1;
		dx:=(x1-x0)/ABS(y1-y0);
		WHILE y0<y1 DO
			PutPixel(img,x0,y0,color);
			x0:=x0+dx;
			y0:=y0+dy
		END

	END
END Line;

PROCEDURE LineDDA*(img: Raster.Image; XH, YH, XK, YK:REAL; color:LONGINT);
VAR
	X, Y, dX, dY: REAL;
	iL: LONGINT;
BEGIN
	iL  := MAX(ABS(ENTIER(XK + 0.5) - ENTIER(XH + 0.5)),
		ABS(ENTIER(YK + 0.5) - ENTIER(YH + 0.5)));
	dX := (XK - XH) / iL; dY := (YK - YH) / iL;
	X := XH; Y := YH;
	WHILE iL > 0 DO
		PutPixel(img, X, Y, color);
		X := X + dX; Y := Y + dY;
		DEC(iL)
	END
END LineDDA;

PROCEDURE LineDDAFull*(img: Raster.Image; x0, y0, x1, y1: REAL; color: LONGINT);
TYPE
	Pixels = ARRAY 4 OF RECORD
		(* pixel was equal to pixel form buffer and already drawn *)
		dr: BOOLEAN;
		x, y: LONGINT;
		(* area *)
		a: REAL
	END;
VAR
	r, g, b, a: LONGINT;
	rmode: Raster.Mode;
	p: Raster.Pixel;

	x, y, dx, dy: REAL;
	l: LONGINT;

	(* Pixels buffer *)
	BufPx: Pixels;
	nBufPx: SHORTINT;

	PROCEDURE PutPixel;
	VAR
		ix, iy: LONGINT;
		px, py, pdx, pdy, s: REAL;
		(* Current pixels *)
		CurPx: Pixels;
		nCurPx, iCurPx: SHORTINT;
		found: BOOLEAN;
		str: ARRAY 16 OF CHAR;
	BEGIN
		px := x + 0.5; py := y + 0.5;

		(* rounded values are the center of
		 4 adjacent pixels around this center:
			(iX-1,	iY-1)	(iX,	iY-1)
			(iX-1,	iY)		(iX,	iY)					*)
		ix := ENTIER(px); iy := ENTIER(py);

		(* pdx and pdy are in range 0..1 *)
		pdx := px - ix; pdy := py - iy;

		CurPx[0].dr := FALSE; CurPx[0].x := ix - 1;	CurPx[0].y := iy - 1;	CurPx[0].a := (1 - pdx) * (1 - pdy);
		CurPx[1].dr := FALSE; CurPx[1].x := ix;			CurPx[1].y := iy - 1;	CurPx[1].a := pdx * (1 - pdy);
		CurPx[2].dr := FALSE; CurPx[2].x := ix - 1;	CurPx[2].y := iy;			CurPx[2].a := (1 - pdx) * pdy;
		CurPx[3].dr := FALSE; CurPx[3].x := ix;			CurPx[3].y := iy;			CurPx[3].a := pdx * pdy;
		nCurPx := 4;

		(* Traverse pixels buffer.
			If equal pixels found in current pixels and in
			pixels buffer, combine them and draw in other case
			simply draw pixel form pixels buffer *)
		WHILE nBufPx > 0 DO
			(* Search for equal pixel in current pixels *)
			iCurPx := 0;
			found := FALSE;
			WHILE (iCurPx < nCurPx) & ~found DO
				IF ~CurPx[iCurPx].dr &
					(CurPx[iCurPx].x = BufPx[nBufPx - 1].x) &
					(CurPx[iCurPx].y = BufPx[nBufPx - 1].y)
				THEN
					found := TRUE
				ELSE
					INC(iCurPx)
				END
			END;
			IF found THEN (* mark current pixel drawn, and combine with pixel from buffer *)
				CurPx[iCurPx].dr := TRUE;
				s := MAX(CurPx[iCurPx].a, BufPx[nBufPx - 1].a);
				IF s > 1.0 THEN
					Strings.FloatToStr(s, 0, 6, 0, str);
					Strings.TrimLeft(str, 20X);
					KernelLog.String(str);
					KernelLog.Ln;
					s := 1.0
				END;
				Raster.SetRGBA(p, r, g, b, ENTIER(s * 255))
			ELSE (* simply draw pixel from buffer *)
				ASSERT(BufPx[nBufPx - 1].a <= 1);
				Raster.SetRGBA(p, r, g, b, ENTIER(BufPx[nBufPx - 1].a * 255))
			END;
			Raster.Put(img, BufPx[nBufPx - 1].x, BufPx[nBufPx - 1].y, p, rmode);
			DEC(nBufPx)
		END;
		(* If anything present in current pixels and isn't drawn, move to buffer *)
		iCurPx := 0;
		nBufPx := 0;
		WHILE iCurPx < nCurPx DO
			IF ~CurPx[iCurPx].dr THEN
				BufPx[nBufPx] := CurPx[iCurPx];
				INC(nBufPx)
			END;
			INC(iCurPx)
		END

	END PutPixel;

BEGIN
	WMGraphics.ColorToRGBA(color, r, g, b, a);
	Raster.InitMode(rmode, Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)

	l := MAX(ABS(ENTIER(x1 + 0.5) - ENTIER(x0 + 0.5)),
		ABS(ENTIER(y1 + 0.5) - ENTIER(y0 + 0.5)));
		
	dx := (x1 - x0) / l; dy := (y1 - y0) / l;

	nBufPx := 0;
	x := x0; y := y0;
	WHILE l > 0 DO
		PutPixel;
		x := x + dx; y := y + dy;
		DEC(l)
	END;

	(* Flush pixels buffer *)
	WHILE nBufPx > 0 DO
		ASSERT(BufPx[nBufPx - 1].a <= 1);
		Raster.SetRGBA(p, r, g, b, ENTIER(BufPx[nBufPx - 1].a * 255));
		Raster.Put(img, BufPx[nBufPx - 1].x, BufPx[nBufPx - 1].y, p, rmode);
		DEC(nBufPx)
	END

END LineDDAFull;

PROCEDURE PutPixel(img: Raster.Image; x0, y0: REAL; color: LONGINT);
VAR
	r, g, b, a: LONGINT;
	rmode: Raster.Mode;
	p: Raster.Pixel;

	iX, iY: LONGINT;
	fDXL, fDXR, fDYT, fDYB: REAL;

BEGIN
	WMGraphics.ColorToRGBA(color, r, g, b, a);
	Raster.InitMode(rmode, Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)

	x0 := x0 + 0.5; y0 := y0 + 0.5;
	(* rounded values are the center of
	 4 adjacent pixels around this center:
		(iX-1,	iY-1)	(iX,	iY-1)
		(iX-1,	iY)		(iX,	iY)					*)
	iX := ENTIER(x0); iY := ENTIER(y0);

	(* fDXR, fDYB, fDXL and fDYT are in range 0..1 *)
	fDXR := x0 - iX; fDYB := y0 - iY;
	fDXL := 1 - fDXR; fDYT := 1 - fDYB;

	Raster.SetRGBA(p, r, g, b, ENTIER(fDXL * fDYT * 255));
	Raster.Put(img, iX - 1, iY - 1, p, rmode);
	Raster.SetRGBA(p, r, g, b, ENTIER(fDXR * fDYT * 255));
	Raster.Put(img, iX, iY - 1, p, rmode);
	Raster.SetRGBA(p, r, g, b, ENTIER(fDXL * fDYB * 255));
	Raster.Put(img, iX - 1, iY, p, rmode);
	Raster.SetRGBA(p, r, g, b, ENTIER(fDXR * fDYB * 255));
	Raster.Put(img, iX, iY, p, rmode);

END PutPixel;

PROCEDURE PutPixel2(img: Raster.Image; x0, y0: REAL; color: LONGINT);
VAR
	iX,iY:LONGINT;
	r,g,b,a:LONGINT;
	dx,dy:REAL;
	p : Raster.Pixel;
	rmode: Raster.Mode;
BEGIN
	WMGraphics.ColorToRGBA(color,r,g,b,a);
	Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)

	x0 := x0 + 0.5;
	y0 := y0 + 0.5;
	iX := ENTIER(x0);
	iY := ENTIER(y0);

	(*iX := ENTIER(x0 + 0.5);
	iY := ENTIER(y0 + 0.5);*)

	dx := x0 - iX; dy := y0 - iY;

	(* KernelLog.String("a00= "); KernelLog.Int(a, 0); KernelLog.Ln;*)
	Raster.SetRGBA(p,r,g,b, ENTIER(dx * dy * 255));
	Raster.Put(img, iX + 1, iY + 1, p, rmode);

	(* KernelLog.String("a10= "); KernelLog.Int(a, 0); KernelLog.Ln;*)
	Raster.SetRGBA(p,r,g,b, ENTIER((1 - dx) * dy * 255) MOD 255);
	Raster.Put(img, iX, iY + 1, p, rmode);

	(* KernelLog.String("a01= "); KernelLog.Int(a, 0); KernelLog.Ln;*)
	Raster.SetRGBA(p,r,g,b, ENTIER(dx * (1 - dy) * 255) MOD 255);
	Raster.Put(img, iX + 1, iY, p, rmode);

	(* KernelLog.String("a11= "); KernelLog.Int(a, 0); KernelLog.Ln;*)
	Raster.SetRGBA(p,r,g,b, ENTIER((1 - dx) * (1 - dy) * 255) MOD 255);
	Raster.Put(img, iX, iY, p, rmode)

END PutPixel2;

END FloatAA.




