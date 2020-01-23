MODULE AAGraphics;	(** AUTHOR "BohdanT"; PURPOSE "Anti-aliasing drawing of graphics primitives"; *)

IMPORT SYSTEM, WMGraphics,  WMRectangles, Raster, 	WMGraphicUtilities, Math, Strings, KernelLog;

TYPE
	AlphaTbl = ARRAY 256 OF Raster.Pixel;

PROCEDURE CreateAlphaTbl(color:LONGINT;VAR alf:AlphaTbl);
VAR
	i:LONGINT;
	r,g,b,a:LONGINT;
	rxi,rxf,rmi,rmf, rdt2:LONGINT;
	gxi,gxf,gmi,gmf, gdt2:LONGINT;
	bxi,bxf,bmi,bmf, bdt2:LONGINT;
BEGIN
	WMGraphics.ColorToRGBA(color,r,g,b,a);
(*!TODO: 	take into account the alpha of incoming color*)
	rxi := 0; rxf := - 255; rmi := r DIV 255; rmf := 2 * ( r MOD 255 ); rdt2 := 2 * 255;
	gxi := 0; gxf := - 255; gmi := g DIV 255; gmf := 2 * ( g MOD 255 ); gdt2 := 2 * 255;
	bxi := 0; bxf := - 255; bmi := b DIV 255; bmf := 2 * ( b MOD 255 ); bdt2 := 2 * 255;

	FOR i:=0 TO 255 DO
		alf[i,2]:=CHR(rxi);
		alf[i,1]:=CHR(gxi);
		alf[i,0]:=CHR(bxi);
		alf[i,3]:=CHR(i);

				INC(rxi, rmi); INC(rxf, rmf);
				IF rxf > 0 THEN INC(rxi); DEC(rxf, rdt2) END;

				INC(gxi, gmi); INC(gxf, gmf);
				IF gxf > 0 THEN INC(gxi); DEC(gxf, gdt2) END;

				INC(bxi, bmi); INC(bxf, bmf);
				IF bxf > 0 THEN INC(bxi); DEC(bxf, bdt2) END;
	END;
END CreateAlphaTbl;


(**Fast Antialiased Circle*)
PROCEDURE Circle*(img: Raster.Image;CX, CY, R,cl : LONGINT);

VAR  X, Y: LONGINT;
        XChange, YChange: LONGINT;
        RadiusError: LONGINT;
        r, g, b, a: LONGINT;
        dx: LONGINT;
        rmode: Raster.Mode;
        p1, p2: Raster.Pixel;
BEGIN       
	X := R;
	Y := 0;
	XChange :=  1- 2*R; 
	YChange := 1;
	RadiusError := 0;
	WMGraphics.ColorToRGBA(cl,r,g,b,a);
	Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)
	WHILE ( X>= Y ) DO
		a:=ABS(Div(XChange,255*RadiusError));
		Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);

		IF RadiusError>=0 THEN dx:=-1 ELSE dx:=+1 END;
		Raster.Put(img, CX-X, CY+Y, p1, rmode);	Raster.Put(img, CX-X-dx, CY+Y, p2, rmode);
		Raster.Put(img, CX+X, CY+Y, p1, rmode);	Raster.Put(img, CX+X+dx, CY+Y, p2, rmode);

		Raster.Put(img, CX-X, CY-Y, p1, rmode);	Raster.Put(img, CX-X-dx, CY-Y, p2, rmode);
		Raster.Put(img, CX+X, CY-Y, p1, rmode);	Raster.Put(img, CX+X+dx, CY-Y, p2, rmode);

		Raster.Put(img, CX-Y, CY+X, p1, rmode);	Raster.Put(img, CX-Y, CY+X+dx, p2, rmode);
		Raster.Put(img, CX+Y, CY+X, p1, rmode);	Raster.Put(img, CX+Y, CY+X+dx, p2, rmode);

		Raster.Put(img, CX-Y, CY-X, p1, rmode);	Raster.Put(img, CX-Y, CY-X-dx, p2, rmode);
		Raster.Put(img, CX+Y, CY-X, p1, rmode);	Raster.Put(img, CX+Y, CY-X-dx, p2, rmode);


		INC(Y);
		INC(RadiusError, YChange);
         
		INC(YChange,2);
		IF ( 2*RadiusError + XChange > 0 ) THEN
			DEC(X);
			INC(RadiusError, XChange);
			INC(XChange,2);
		END;
	END;
(*!TODO:fixed artifact*)
(*  	Raster.SetRGBA(p2,r,g,b,127);
	Raster.Put(img, CX-X-1, CY+Y, p2, rmode);      
	Raster.Put(img, CX+X+1, CY+Y, p2, rmode);      
	Raster.Put(img, CX-X-1, CY-Y, p2, rmode);      
	Raster.Put(img, CX+X+1, CY-Y, p2, rmode);      *)
END Circle;

(**Fast Antialiased Disk*)
PROCEDURE AADisk*(img : Raster.Image; CX, CY, R,cl : LONGINT);

VAR  
	X, Y: LONGINT;
	XChange, YChange: LONGINT;
	RadiusError: LONGINT;
	r, g, b, a: LONGINT;
	dx: LONGINT;
	rmode: Raster.Mode;
	p0, p1, p2: Raster.Pixel;
BEGIN       
	X := R;
	Y := 0;
	XChange :=  1- 2*R; 
	YChange := 1;
	RadiusError := 0;
	WMGraphics.ColorToRGBA(cl,r,g,b,a);
	Raster.SetRGBA(p0,r,g,b,a);
	Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)

  WHILE ( X>= Y ) DO
(*	a:=255-ENTIER(ABS(255*RadiusError/XChange)+0.5);*)
	a:=ABS(Div(XChange,255*RadiusError));
	Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);

  	IF RadiusError>=0 THEN
  		dx:=-1;
(*  	Raster.SetRGBA(p2,0,255,0,255-a);*)(*Debug*)
	ELSE
(*		Raster.SetRGBA(p2,255,0,0,255-a);*)(*Debug*)
		dx:=+1;
	END;
	
	Raster.Put(img, CX-X, CY+Y, p1, rmode); Raster.Put(img, CX-X-dx, CY+Y, p2, rmode);
	Raster.Put(img, CX+X, CY+Y, p1, rmode); Raster.Put(img, CX+X+dx, CY+Y, p2, rmode);
	Raster.Fill(img, CX-X, CY+Y, CX+X+1, CY+Y+1, p0, rmode);

	Raster.Put(img, CX-X, CY-Y, p1, rmode); Raster.Put(img, CX-X-dx, CY-Y, p2, rmode);
	Raster.Put(img, CX+X, CY-Y, p1, rmode); Raster.Put(img, CX+X+dx, CY-Y, p2, rmode);
	Raster.Fill(img, CX-X, CY-Y, CX+X+1, CY-Y+1, p0, rmode);

	Raster.Put(img, CX+Y, CY+X, p1, rmode); Raster.Put(img, CX+Y, CY+X+dx, p2, rmode);
	Raster.Put(img, CX-Y, CY+X, p1, rmode); Raster.Put(img, CX-Y, CY+X+dx, p2, rmode);
	Raster.Fill(img, CX-Y, CY+X, CX+Y+1, CY+X+1, p0, rmode);

	Raster.Put(img, CX-Y, CY-X, p1, rmode); Raster.Put(img, CX-Y, CY-X-dx, p2, rmode);
	Raster.Put(img, CX+Y, CY-X, p1, rmode); Raster.Put(img, CX+Y, CY-X-dx, p2, rmode);
	Raster.Fill(img, CX-Y, CY-X, CX+Y+1, CY-X+1, p0, rmode);
         INC(Y);
         INC(RadiusError, YChange);
         
         INC(YChange,2);
         IF ( 2*RadiusError + XChange > 0 ) THEN
               DEC(X);
               INC(RadiusError, XChange);
               INC(XChange,2);
        END;
      END;
	Raster.Put(img, CX-X-1, CY+Y, p2, rmode);      (*fixed artifact*)
	Raster.Put(img, CX+X+1, CY+Y, p2, rmode);      
	Raster.Put(img, CX-X-1, CY-Y, p2, rmode);      
	Raster.Put(img, CX+X+1, CY-Y, p2, rmode);      

END AADisk;

TYPE
	FillCB * = PROCEDURE{DELEGATE} (y:LONGINT):LONGINT; (*Return color*)
PROCEDURE AADiskCB*(img:Raster.Image;CX, CY, R : LONGINT;cb:FillCB);

VAR  
	X, Y: LONGINT;
	XChange, YChange: LONGINT;
	RadiusError: LONGINT;
	r, g, b, a, a1: LONGINT;
	dx, lx: LONGINT;
	rmode: Raster.Mode;
	p0, p1, p2: Raster.Pixel;
	oy: LONGINT;

BEGIN       
	X := R;
	Y := 0;
	oy:=-1;
	XChange :=  1- 2*R; 
	YChange := 1;
	RadiusError := 0;
	Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)


  WHILE ( X>=Y ) DO
	a:=ABS(Div(XChange,255*RadiusError));

  	IF RadiusError>=0 THEN
  		dx:=-1;lx:=0;
	ELSE
		dx:=+1;lx:=1;
	END;
	WMGraphics.ColorToRGBA(cb(CY+Y),r,g,b,a1);
	Raster.SetRGBA(p0,r,g,b,255); Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);
	Raster.Put(img, CX-X, CY+Y, p1, rmode);	Raster.Put(img, CX-X-dx, CY+Y, p2, rmode);
	Raster.Put(img, CX+X, CY+Y, p1, rmode);	Raster.Put(img, CX+X+dx, CY+Y, p2, rmode);
	Raster.Fill(img, CX-X+1-lx, CY+Y, CX+X+lx, CY+Y+1, p0, rmode);

	WMGraphics.ColorToRGBA(cb(CY-Y),r,g,b,a1);
	Raster.SetRGBA(p0,r,g,b,255); Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);
	Raster.Put(img, CX-X, CY-Y, p1, rmode);	Raster.Put(img, CX-X-dx, CY-Y, p2, rmode);
	Raster.Put(img, CX+X, CY-Y, p1, rmode);	Raster.Put(img, CX+X+dx, CY-Y, p2, rmode);
	Raster.Fill(img, CX-X+1-lx, CY-Y, CX+X+lx, CY-Y+1, p0, rmode);

		WMGraphics.ColorToRGBA(cb(CY+X),r,g,b,a1);
		Raster.SetRGBA(p0,r,g,b,255); Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);
		Raster.Put(img, CX+Y, CY+X+dx, p2, rmode);
		Raster.Put(img, CX-Y, CY+X+dx, p2, rmode);
		IF lx>0 THEN
			Raster.Put(img, CX-Y, CY+X, p0, rmode);
			Raster.Put(img, CX+Y, CY+X, p0, rmode);
		ELSE
			Raster.Put(img, CX-Y, CY+X, p1, rmode);	
			Raster.Put(img, CX+Y, CY+X, p1, rmode);	
		END;
		IF X#oy THEN
			Raster.Fill(img, CX-Y, CY+X, CX+Y+1, CY+X+1, p0, rmode); 
		END;

		WMGraphics.ColorToRGBA(cb(CY-X),r,g,b,a1);
		Raster.SetRGBA(p0,r,g,b,255); Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);
		Raster.Put(img, CX-Y, CY-X-dx, p2, rmode);
		Raster.Put(img, CX+Y, CY-X-dx, p2, rmode);
		IF lx>0 THEN
			Raster.Put(img, CX-Y, CY-X, p0, rmode);
			Raster.Put(img, CX+Y, CY-X, p0, rmode);	
		ELSE
			Raster.Put(img, CX-Y, CY-X, p1, rmode);
			Raster.Put(img, CX+Y, CY-X, p1, rmode);	
		END;

		IF X#oy THEN
			Raster.Fill(img, CX-Y, CY-X, CX+Y+1, CY-X+1, p0, rmode);
		END;
	oy:=X;
         INC(Y);
         INC(RadiusError, YChange);
         
         INC(YChange,2);
         IF ( 2*RadiusError + XChange > 0 ) THEN
               DEC(X);
               INC(RadiusError, XChange);
               INC(XChange,2);
        END;
      END;
    	Raster.Put(img, CX-X-1, CY+Y, p2, rmode);      (*fixed artifact*)
	Raster.Put(img, CX+X+1, CY+Y, p2, rmode);      
	Raster.Put(img, CX-X-1, CY-Y, p2, rmode);      
	Raster.Put(img, CX+X+1, CY-Y, p2, rmode);      

END AADiskCB;

VAR
	gradcolor1, gradcolor2 : LONGINT;
	gradmin, gradmax : LONGINT;
PROCEDURE GradFiller(y : LONGINT):LONGINT;
VAR
	f, dist: LONGINT;
BEGIN
	IF y>gradmin THEN
		dist := gradmax - gradmin;
		f := ENTIER(256 * (y-gradmin) / dist);
		RETURN WMGraphicUtilities.InterpolateColorLinear(gradcolor1, gradcolor2, f);
	ELSE
		RETURN gradcolor1;
	END;
END GradFiller;
VAR
	
PROCEDURE DiskGrad*(img: Raster.Image; X, Y, R: LONGINT; c1, c2: LONGINT);
BEGIN
	gradmin:=Y;
	gradmax:=Y+R;
	gradcolor1:=c1;gradcolor2:=c2;
	AADiskCB(img, X, Y, R, GradFiller);
END DiskGrad;


(* Bresenham Type Algorithm For Drawing Ellipses*)
PROCEDURE Ellipse*(img: Raster.Image; CX, CY, XRadius, YRadius, cl : LONGINT);
VAR
	X, Y: LONGINT;
	XChange, YChange: LONGINT;
	EllipseError: LONGINT;
	TwoASquare, TwoBSquare : LONGINT;
	StoppingX, StoppingY   : LONGINT;
	rmode: Raster.Mode;
	p1, p2: Raster.Pixel;
	r, g, b, a, dx:LONGINT;
BEGIN       

	WMGraphics.ColorToRGBA(cl,r,g,b,a);
	Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)
	Raster.SetRGBA(p1,r,g,b,255);
	
	TwoASquare := 2*XRadius*XRadius;
	TwoBSquare := 2*YRadius*YRadius;
	X := XRadius; 
	Y := 0;
	XChange :=  YRadius*YRadius*(1-2*XRadius);
	YChange :=  XRadius*XRadius;
	EllipseError := 0;
	StoppingX := TwoBSquare*XRadius;
	StoppingY := 0;
	WHILE ( StoppingX>= StoppingY ) DO     (*1st set of points, y> 1*)
	
		a:=ABS(Div(XChange,255*EllipseError));
		Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);
	  	IF EllipseError>=0 THEN dx:=-1; ELSE dx:=+1; END;

		Raster.Put(img, CX+X, CY+Y, p1, rmode);(*point in quadrant 1*)	Raster.Put(img, CX+X+dx, CY+Y, p2, rmode);
		Raster.Put(img, CX-X, CY+Y, p1, rmode);(*point in quadrant 2*)	Raster.Put(img, CX-X-dx, CY+Y, p2, rmode);
		Raster.Put(img, CX-X, CY-Y, p1, rmode);(*point in quadrant 3*)	Raster.Put(img, CX+X+dx, CY-Y, p2, rmode);
		Raster.Put(img, CX+X, CY-Y, p1, rmode);(*point in quadrant 4*)	Raster.Put(img, CX-X-dx, CY-Y, p2, rmode);

		INC(Y);
		INC(StoppingY, TwoASquare);
		INC(EllipseError, YChange);
		INC(YChange,TwoASquare);
		IF ((2*EllipseError + XChange) > 0 ) THEN
			DEC(X);
			DEC(StoppingX, TwoBSquare);
			INC(EllipseError, XChange);
			INC(XChange,TwoBSquare)
		END
	END;
	(* 1st point set is done; start the 2nd set of points *)
	X := 0;
	Y := YRadius;
	XChange := YRadius*YRadius;
	YChange := XRadius*XRadius*(1-2*YRadius);
	EllipseError := 0;
	StoppingX := 0;
	StoppingY := TwoASquare*YRadius;
	WHILE ( StoppingX<= StoppingY ) DO  (*2nd set of points, y < 1*)

		a:=ABS(Div(YChange,255*EllipseError));
		Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);
	  	IF EllipseError>=0 THEN dx:=-1; ELSE dx:=+1; END;

		Raster.Put(img, CX+X, CY+Y, p1, rmode);(*point in quadrant 1*)	Raster.Put(img, CX+X, CY+Y+dx, p2, rmode);
		Raster.Put(img, CX-X, CY+Y, p1, rmode);(*point in quadrant 2*)	Raster.Put(img, CX-X, CY+Y+dx, p2, rmode);
		Raster.Put(img, CX-X, CY-Y, p1, rmode);(*point in quadrant 3*)	Raster.Put(img, CX-X, CY-Y-dx, p2, rmode);
		Raster.Put(img, CX+X, CY-Y, p1, rmode);(*point in quadrant 4*)	Raster.Put(img, CX+X, CY-Y-dx, p2, rmode);

		INC(X);
		INC(StoppingX, TwoBSquare);
		INC(EllipseError, XChange);
		INC(XChange,TwoBSquare);
		IF ((2*EllipseError + YChange) > 0 ) THEN
			DEC(Y);
			DEC(StoppingY, TwoASquare);
			INC(EllipseError, YChange);
			INC(YChange,TwoASquare)
		END;
	END;
END Ellipse;

PROCEDURE RoundRect*(img: Raster.Image; rect : WMRectangles.Rectangle;XRadius, YRadius, cl : LONGINT);
VAR
	X, Y: LONGINT;
	XChange, YChange: LONGINT;
	EllipseError: LONGINT;
	TwoASquare, TwoBSquare : LONGINT;
	StoppingX, StoppingY   : LONGINT;
	rmode: Raster.Mode;
	p1, p2: Raster.Pixel;
	r, g, b, a, dx:LONGINT;
	CX1, CY1, CX2, CY2: LONGINT;
BEGIN       
	
	WMGraphics.ColorToRGBA(cl,r,g,b,a);
	Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)
	Raster.SetRGBA(p1,r,g,b,255);
	
	CX1:=rect.l+XRadius;CY1:=rect.t+YRadius;
	CX2:=rect.r-XRadius;CY2:=rect.b-YRadius;
	Raster.Fill(img, CX1, rect.t, CX2+1, rect.t+1, p1, rmode);
	Raster.Fill(img, CX1, rect.b, CX2+1, rect.b+1, p1, rmode);
	Raster.Fill(img, rect.l, CY1, rect.l+1, CY2+1, p1, rmode);
	Raster.Fill(img, rect.r, CY1, rect.r+1, CY2+1, p1, rmode);

	TwoASquare := 2*XRadius*XRadius;
	TwoBSquare := 2*YRadius*YRadius;
	X := XRadius; 
	Y := 0;
	XChange :=  YRadius*YRadius*(1-2*XRadius);
	YChange :=  XRadius*XRadius;
	EllipseError := 0;
	StoppingX := TwoBSquare*XRadius;
	StoppingY := 0;
	WHILE ( StoppingX>= StoppingY ) DO     (*1st set of points, y> 1*)
	
		a:=ABS(Div(XChange,255*EllipseError));
		Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);
	  	IF EllipseError>=0 THEN dx:=-1; ELSE dx:=+1; END;

		Raster.Put(img, CX2+X, CY2+Y, p1, rmode);(*point in quadrant 1*)	Raster.Put(img, CX2+X+dx, CY2+Y, p2, rmode);
		Raster.Put(img, CX1-X, CY2+Y, p1, rmode);(*point in quadrant 2*)	Raster.Put(img, CX1-X-dx, CY2+Y, p2, rmode);
		Raster.Put(img, CX1-X, CY1-Y, p1, rmode);(*point in quadrant 3*)	Raster.Put(img, CX2+X+dx, CY1-Y, p2, rmode);
		Raster.Put(img, CX2+X, CY1-Y, p1, rmode);(*point in quadrant 4*)	Raster.Put(img, CX1-X-dx, CY1-Y, p2, rmode);

		INC(Y);
		INC(StoppingY, TwoASquare);
		INC(EllipseError, YChange);
		INC(YChange,TwoASquare);
		IF ((2*EllipseError + XChange) > 0 ) THEN
			DEC(X);
			DEC(StoppingX, TwoBSquare);
			INC(EllipseError, XChange);
			INC(XChange,TwoBSquare)
		END
	END;
	(* 1st point set is done; start the 2nd set of points *)
	X := 0;
	Y := YRadius;
	XChange := YRadius*YRadius;
	YChange := XRadius*XRadius*(1-2*YRadius);
	EllipseError := 0;
	StoppingX := 0;
	StoppingY := TwoASquare*YRadius;
	WHILE ( StoppingX<= StoppingY ) DO  (*2nd set of points, y < 1*)

		a:=ABS(Div(YChange,255*EllipseError));
		Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);
	  	IF EllipseError>=0 THEN dx:=-1; ELSE dx:=+1; END;

		Raster.Put(img, CX2+X, CY2+Y, p1, rmode);(*point in quadrant 1*)	Raster.Put(img, CX2+X, CY2+Y+dx, p2, rmode);
		Raster.Put(img, CX1-X, CY2+Y, p1, rmode);(*point in quadrant 2*)	Raster.Put(img, CX1-X, CY2+Y+dx, p2, rmode);
		Raster.Put(img, CX1-X, CY1-Y, p1, rmode);(*point in quadrant 3*)	Raster.Put(img, CX1-X, CY1-Y-dx, p2, rmode);
		Raster.Put(img, CX2+X, CY1-Y, p1, rmode);(*point in quadrant 4*)	Raster.Put(img, CX2+X, CY1-Y-dx, p2, rmode);

		INC(X);
		INC(StoppingX, TwoBSquare);
		INC(EllipseError, XChange);
		INC(XChange,TwoBSquare);
		IF ((2*EllipseError + YChange) > 0 ) THEN
			DEC(Y);
			DEC(StoppingY, TwoASquare);
			INC(EllipseError, YChange);
			INC(YChange,TwoASquare)
		END;
	END;
	
END RoundRect;

PROCEDURE RoundRectFlat*(img: Raster.Image; rect : WMRectangles.Rectangle;XRadius, YRadius, cl : LONGINT);
VAR
	X, Y: LONGINT;
	XChange, YChange: LONGINT;
	EllipseError: LONGINT;
	TwoASquare, TwoBSquare : LONGINT;
	StoppingX, StoppingY   : LONGINT;
	rmode: Raster.Mode;
	p0, p1, p2: Raster.Pixel;
	r, g, b, a, dx:LONGINT;
	CX1, CY1, CX2, CY2: LONGINT;
BEGIN       
	
	WMGraphics.ColorToRGBA(cl,r,g,b,a);
	Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)
	Raster.SetRGBA(p0,r,g,b,255);
	
	CX1:=rect.l+XRadius;CY1:=rect.t+YRadius;
	CX2:=rect.r-XRadius;CY2:=rect.b-YRadius;
	TwoASquare := 2*XRadius*XRadius;
	TwoBSquare := 2*YRadius*YRadius;
	X := XRadius; 
	Y := 0;
	XChange :=  YRadius*YRadius*(1-2*XRadius);
	YChange :=  XRadius*XRadius;
	EllipseError := 0;
	StoppingX := TwoBSquare*XRadius;
	StoppingY := 0;
	WHILE ( StoppingX>= StoppingY ) DO     (*1st set of points, y> 1*)
	
		a:=ABS(Div(XChange,255*EllipseError));
		Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);
	  	IF EllipseError>=0 THEN dx:=-1; ELSE dx:=+1; END;

		Raster.Put(img, CX2+X, CY2+Y, p1, rmode);(*point in quadrant 1*)	Raster.Put(img, CX2+X+dx, CY2+Y, p2, rmode);
		Raster.Put(img, CX1-X, CY2+Y, p1, rmode);(*point in quadrant 2*)	Raster.Put(img, CX1-X-dx, CY2+Y, p2, rmode);
		Raster.Fill(img, CX1-X, CY2+Y, CX2+X+1, CY2+Y+1, p0, rmode);
		
		Raster.Put(img, CX1-X, CY1-Y, p1, rmode);(*point in quadrant 3*)	Raster.Put(img, CX2+X+dx, CY1-Y, p2, rmode);
		Raster.Put(img, CX2+X, CY1-Y, p1, rmode);(*point in quadrant 4*)	Raster.Put(img, CX1-X-dx, CY1-Y, p2, rmode);
		Raster.Fill(img, CX1-X, CY1-Y, CX2+X+1, CY1-Y+1, p0, rmode);

		INC(Y);
		INC(StoppingY, TwoASquare);
		INC(EllipseError, YChange);
		INC(YChange,TwoASquare);
		IF ((2*EllipseError + XChange) > 0 ) THEN
			DEC(X);
			DEC(StoppingX, TwoBSquare);
			INC(EllipseError, XChange);
			INC(XChange,TwoBSquare)
		END
	END;
	(* 1st point set is done; start the 2nd set of points *)
	X := 0;
	Y := YRadius;
	XChange := YRadius*YRadius;
	YChange := XRadius*XRadius*(1-2*YRadius);
	EllipseError := 0;
	StoppingX := 0;
	StoppingY := TwoASquare*YRadius;
	WHILE ( StoppingX<= StoppingY ) DO  (*2nd set of points, y < 1*)

		a:=ABS(Div(YChange,255*EllipseError));
		Raster.SetRGBA(p1,r,g,b,255-a);	Raster.SetRGBA(p2,r,g,b,a);
	  	IF EllipseError>=0 THEN dx:=-1; ELSE dx:=+1; END;

		Raster.Put(img, CX2+X, CY2+Y, p1, rmode);(*point in quadrant 1*)	Raster.Put(img, CX2+X, CY2+Y+dx, p2, rmode);
		Raster.Put(img, CX1-X, CY2+Y, p1, rmode);(*point in quadrant 2*)	Raster.Put(img, CX1-X, CY2+Y+dx, p2, rmode);
		Raster.Fill(img, CX1-X, CY2+Y, CX2+X+1, CY2+Y+1, p0, rmode);

		Raster.Put(img, CX1-X, CY1-Y, p1, rmode);(*point in quadrant 3*)	Raster.Put(img, CX1-X, CY1-Y-dx, p2, rmode);
		Raster.Put(img, CX2+X, CY1-Y, p1, rmode);(*point in quadrant 4*)	Raster.Put(img, CX2+X, CY1-Y-dx, p2, rmode);
		Raster.Fill(img, CX1-X, CY1-Y, CX2+X+1, CY1-Y+1, p0, rmode);

		INC(X);
		INC(StoppingX, TwoBSquare);
		INC(EllipseError, XChange);
		INC(XChange,TwoBSquare);
		IF ((2*EllipseError + YChange) > 0 ) THEN
			DEC(Y);
			DEC(StoppingY, TwoASquare);
			INC(EllipseError, YChange);
			INC(YChange,TwoASquare)
		END;
	END;
	Raster.Fill(img, rect.l, CY1, rect.r+1, CY2, p0, rmode);
	
END RoundRectFlat;

(* draw a anti-aliased line *)
(** draw a line within the current clipping rectangle *)
PROCEDURE AALine*(img:Raster.Image; x0, y0, x1, y1 : LONGINT; color : LONGINT);
VAR t, xi, mi, xf, mf, dt2 : LONGINT;
VAR
	p : Raster.Pixel;
	r, g, b, a : LONGINT;
	rmode: Raster.Mode;

BEGIN
	WMGraphics.ColorToRGBA(color,r,g,b,a);
	Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)
	Raster.SetRGBA(p,r,g,b, a);

	IF y0 = y1 THEN (* horizontal case *)
		IF x0 > x1 THEN t := x0; x0 := x1; x1 := t END;
		Raster.Fill(img, x0, y0, x1 + 1, y0 + 1, p, rmode);

	ELSIF x0 = x1 THEN (* vertical case *)
		IF y0 > y1 THEN t := y0; y0 := y1; y1 := t END;
		Raster.Fill(img, x0, y0, x0 + 1, y1 + 1, p, rmode);
	ELSE (* general case *)
		IF ABS(y1 - y0) > ABS(x1 - x0) THEN
			IF y0 > y1 THEN t := y0; y0 := y1; y1 := t; t := x0; x0 := x1; x1 := t END;
			xi := x0; xf :=	y0 - y1; mi := (x1 - x0) DIV (y1 - y0); mf := 2 * ( (x1 - x0) MOD (y1 - y0)); dt2 := 2 * (y1 - y0);
			FOR t := y0 TO y1 DO
				a:=255*ABS(xf) DIV dt2;
				Raster.SetRGBA(p,r,g,b, a);
				Raster.Put(img, xi, t, p, rmode);
				Raster.SetRGBA(p,r,g,b, 255-a);
				Raster.Put(img, xi+1, t, p, rmode);

				INC(xi, mi); INC(xf, mf);
				IF xf > 0 THEN INC(xi); DEC(xf, dt2); END
			END
		ELSE
			IF x0 > x1 THEN t := y0; y0 := y1; y1 := t; t := x0; x0 := x1; x1 := t END;
			xi := y0; xf :=	x0 - x1; mi := (y1 - y0) DIV (x1 - x0); mf := 2 * ( (y1 - y0) MOD (x1 - x0)); dt2 := 2 * (x1 - x0);
			FOR t := x0 TO x1 DO
				a:=255*ABS(xf) DIV dt2;
				Raster.SetRGBA(p,r,g,b, a);
				Raster.Put(img, t, xi, p, rmode);
				Raster.SetRGBA(p,r,g,b, 255-a);
				Raster.Put(img, t, xi+1, p, rmode);
						
				INC(xi, mi); INC(xf, mf);
				IF xf > 0 THEN INC(xi); DEC(xf, dt2); END
			END
		END
	END
END AALine;


PROCEDURE AALineW*(img:Raster.Image; x0, y0, x1, y1:LONGINT; color:LONGINT;th:REAL);
(* plot an anti-aliased line of width th pixel *)
VAR
	err, dx, dy:REAL;
	sx, sy : LONGINT;
	e2:REAL;

	p, p1 : Raster.Pixel;
	r, g, b, a : LONGINT;
	rmode: Raster.Mode;
BEGIN
	WMGraphics.ColorToRGBA(color,r,g,b,a);
	Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)
	Raster.SetRGBA(p,r,g,b, a);
	
		dx := ABS(x1-x0); IF x0 < x1 THEN sx :=1 ELSE sx :=-1; END;
		dy := ABS(y1-y0); IF y0 < y1 THEN sy := 1 ELSE sy := -1; END;
		e2 := Math.sqrt(dx*dx+dy*dy);(* length *)

	IF  (th <= 1) OR (e2 = 0) THEN AALine(img, x0,y0, x1,y1, color); RETURN END;
	dx := dx*255/e2; dy := dy*255/e2; 
	th := 255*(th-1);(* scale values *)

	IF (dx < dy) THEN(* steep line *)
		x1 := ENTIER((e2+th/2)/dy+0.5);(* start offset *)
		err := x1*dy-th/2;(* shift error value to offset width *)
		x0 := x0-x1*sx;

		WHILE y0 # y1 DO
			x1 := x0;
			Raster.SetRGBA(p1,r,g,b,255- ENTIER(err));
			Raster.Put(img, x1, y0, p1, rmode);(* aliasing pre-pixel *)

			e2 := dy-err-th;
			WHILE	e2+dy < 255 DO
				INC(x1, sx);
				Raster.Put(img, x1, y0, p, rmode);(* pixel on the line *)
				e2:=e2+dy
			END;
			Raster.SetRGBA(p1,r,g,b,255- ENTIER(e2));
			Raster.Put(img, x1+sx, y0, p1, rmode);(* aliasing post-pixel *)
			err:=err+ dx;(* y-step *)
			IF  err > 255 THEN err:=err- dy; INC(x0, sx) END;(* x-step *) 
			INC(y0, sy);
		END;
	ELSE(* flat line *)
		y1 := ENTIER((e2+th/2)/dx+0.5);(* start offset *)
		err := y1*dx-th/2;(* shift error value to offset width *)
		y0 := y0-y1*sy;
		WHILE x0 # x1 DO 
			y1 := y0;
			Raster.SetRGBA(p1,r,g,b, 255-ENTIER(err));
			Raster.Put(img, x0, y1, p1, rmode);(* aliasing pre-pixel *)

			e2 := dx-err-th;
			WHILE e2+dx < 255 DO  
				INC(y1, sy);
				Raster.Put(img, x0, y1, p, rmode);(* pixel on the line *)
				e2:= e2+dx;
			END;
			Raster.SetRGBA(p1,r,g,b, 255-ENTIER(e2));
			Raster.Put(img, x0, y1+sy, p1, rmode);(* aliasing post-pixel *)
			err :=err + dy;(* x-step *) 
			IF err > 255 THEN err:=err-dx; INC(y0, sy); END;(* y-step *)
			INC(x0, sx);
		END;
	END;
END AALineW;


PROCEDURE PolyLine*(img:Raster.Image; CONST points : ARRAY OF WMGraphics.Point2d; nofPoints : LONGINT; closed : BOOLEAN;	color : LONGINT);
VAR i : LONGINT;
BEGIN
	FOR i := 1 TO nofPoints - 1 DO
		AALine(img, points[i-1].x, points[i-1].y, points[i].x, points[i].y, color)
	END;
	IF closed THEN
		AALine(img, points[nofPoints-1].x, points[nofPoints-1].y, points[0].x, points[0].y, color)
	END
END PolyLine;

		
(*!!!b/a for the speed*)
PROCEDURE -Div(a,b:LONGINT):LONGINT;
CODE
	POP	EAX
	CDQ
	DB 	0F7H, 3CH, 24H ;	(*IDIV	[ESP+b]*)
	ADD	ESP, 4
END Div;

PROCEDURE BoxBlur*(img:Raster.Image; r:LONGINT; chan:SET);
(*based on http://blog.ivank.net/fastest-gaussian-blur.html*)
TYPE
	BYTE = SYSTEM.BYTE;
VAR
	bxs:POINTER TO ARRAY OF LONGINT;
	tcl:POINTER TO ARRAY OF CHAR;
	chanel:LONGINT;
	w, h :LONGINT;
	
	PROCEDURE boxesForGauss(sigma, n:LONGINT);  (*standard deviation, number of boxes*)
	VAR
		wIdeal, mIdeal : REAL;
		wl, wu, i, m :LONGINT;
	BEGIN
		wIdeal := Math.sqrt((12*sigma*sigma/n)+1);  (* Ideal averaging filter width *)
		wl := ENTIER(wIdeal); IF (wl MOD 2)=0 THEN DEC(wl) END;
		wu := wl+2;
		mIdeal := (12*sigma*sigma - n*wl*wl - 4*n*wl - 3*n)/(-4*wl - 4);
		m := ENTIER(mIdeal+0.5);
		NEW(bxs,n);
		FOR i:=0 TO m-1 DO bxs[i]:=wl; END;
		FOR i:=m TO n-1 DO bxs[i]:=wu; END;
	END boxesForGauss;
	PROCEDURE boxBlur(VAR scl, tcl:ARRAY OF BYTE; w, h, r:LONGINT);
	VAR
		i:LONGINT;
		PROCEDURE boxBlurH(VAR scl, tcl:ARRAY OF BYTE);
		VAR
			iarr:REAL;
			i, j, k, ti, fv, li, lv, ri, val:LONGINT;
		BEGIN
			iarr := 1 / (r+r+1);
			FOR i:=0 TO h-1 DO
				ti := i*(w*4)+chanel; li := ti; ri := ti+r*4;
				fv := ORD(scl[ti]); lv := ORD(scl[ti+w-4]); val := (r+1)*fv;

k:=0;		FOR  j:=0 TO r-1 DO INC(val, ORD(scl[ti+k])); INC(k,4) END;

				FOR  j:=0  TO r DO  
					INC(val, ORD(scl[ri]) - fv);INC(ri, 4);
					tcl[ti] := ENTIER(val*iarr+0.5);INC(ti, 4); 
				END;

				FOR  j:=r+1 TO w-r-1 DO  
					INC(val, ORD(scl[ri]) - ORD(scl[li])); INC(li, 4); INC(ri, 4);  
					tcl[ti] := ENTIER(val*iarr+0.5); INC(ti, 4);
				END;
				
				FOR  j:=w-r TO w-1   DO  
					INC(val, lv - ORD(scl[li]));INC(li, 4);   
					tcl[ti] := ENTIER(val*iarr+0.5); INC(ti, 4); 
				END;
			END
		END boxBlurH;
		PROCEDURE boxBlurT(VAR scl, tcl:ARRAY OF BYTE);
		VAR
			iarr:REAL;
			w4, i, j, ti, fv, li, lv, ri, val:LONGINT;
		BEGIN
			iarr := 1 / (r+r+1);
			w4:=w*4;
			FOR i:=0 TO w-1 DO
				ti := i*4+chanel; li := ti; ri := ti+r*w4;
				fv := ORD(scl[ti]); lv := ORD(scl[(ti+w4*(h-1))]); val := (r+1)*fv;
	 			FOR j:=0 TO r-1 DO INC(val,ORD(scl[ti+j*w4]));END;

				FOR j:=0 TO r DO
					INC(val, ORD(scl[ri]) - fv); 
					tcl[ti] := CHR(ENTIER(val*iarr+0.5));  
					INC(ri,w4); INC(ti, w4); 
				END;
				
				FOR j:=r+1 TO h-r-1 DO 
					INC(val, ORD(scl[ri]) - ORD(scl[li]));  
					tcl[ti] := CHR(ENTIER(val*iarr+0.5));  
					INC(li, w4); INC(ri, w4); INC(ti, w4); 
				END;

				FOR j:=h-r TO h-1 DO
					INC(val, lv - ORD(scl[li]));
					tcl[ti] := CHR(ENTIER(val*iarr+0.5));
					INC(li,w4); INC(ti, w4); 
				END;
	    END;
		END boxBlurT;

	BEGIN
		i:=chanel;
		WHILE i<LEN(scl) DO
			tcl[i] := scl[i];
			INC(i,4)
		END;
		boxBlurH(tcl, scl);
		boxBlurT(scl, tcl);
	END boxBlur;

VAR
 i:LONGINT;
BEGIN
		NEW(tcl,LEN(img.mem^));
		w:=img.width;
		h:=img.height;
		boxesForGauss(r, 3);
		FOR i:=0 TO 3 DO
			IF i IN chan THEN
				chanel:=i;
				boxBlur(img.mem^, tcl^, w, h, (bxs[0]-1) DIV 2);
				boxBlur(tcl^, img.mem^, w, h, (bxs[1]-1) DIV 2);
				boxBlur(img.mem^, tcl^, w, h, (bxs[2]-1) DIV 2);
	    END;
    END;
END BoxBlur;


TYPE
	FillPosEntry = RECORD pos,  next : LONGINT END;
	FillHeap = POINTER TO ARRAY OF FillPosEntry;

	Canvas* = OBJECT(WMGraphics.BufferCanvas)
	VAR
		(* filling *)
		fillHeap : FillHeap;
		heapSize, topHeap : LONGINT;
		height : LONGINT;
		edges : POINTER TO ARRAY OF LONGINT;
		lineWidth-: REAL; (** line width in pixels *)

		(**	Set line width in pixels		*)

		PROCEDURE SetLineWidth*(w: REAL);
		BEGIN
			IF w < 0.5 THEN w := 0.5; END;
			lineWidth := w;
		END SetLineWidth;

		PROCEDURE Line*(x0, y0, x1, y1: LONGINT; lineColor: WMGraphics.Color; mode: LONGINT);
		BEGIN
				AALineW(img, x0+dx, y0+dy, x1+dx, y1+dy, lineColor, lineWidth);
		END Line;

		PROCEDURE &New*(img : Raster.Image);
		BEGIN
			(* filling *)
			height := img.height; NEW(edges, height);
			generator := Strings.NewString("AAGraphics.GenCanvas");

			New^(img);
		END New;

		 PROCEDURE ClearHeap;
		 VAR i : LONGINT;
		 BEGIN
			topHeap := 0;
			FOR i := 0 TO height - 1 DO edges[i] := 0 END;
			IF fillHeap = NIL THEN NEW(fillHeap, 1024); heapSize := 1024 END
		 END ClearHeap;

		 PROCEDURE NewFillPos(pos : LONGINT) : LONGINT;
		 VAR newHeap : FillHeap;
			i : LONGINT;
		 BEGIN
			INC(topHeap);
			IF topHeap >= heapSize THEN (* grow heap *)
				NEW(newHeap, heapSize * 2);
				FOR i := 0 TO heapSize - 1 DO newHeap[i] := fillHeap[i] END;
				heapSize := heapSize * 2;
				fillHeap := newHeap
			END;
			fillHeap[topHeap].pos := pos;
			fillHeap[topHeap].next := 0;
			RETURN topHeap
		 END NewFillPos;

		 PROCEDURE AddIntersection(y, pos : LONGINT);
		 VAR new, cur : LONGINT;
		 BEGIN
			IF (y < 0) OR (y >= height) THEN RETURN END;
			new := NewFillPos(pos);
			IF edges[y] = 0 THEN edges[y] := new
			ELSE
				cur := edges[y];
				IF fillHeap[cur].pos > pos THEN
					fillHeap[new].next := cur;
					edges[y] := new
				ELSE
					WHILE (fillHeap[cur].next # 0) & (fillHeap[fillHeap[cur].next].pos < pos) DO cur := fillHeap[cur].next END;
					fillHeap[new].next := fillHeap[cur].next;
					fillHeap[cur].next := new
				END;
			END;
		 END AddIntersection;
(*
		PROCEDURE AddLine*(x0, y0, x1, y1 : LONGINT);
		VAR t, xi, xf, mi, mf, dt2	: LONGINT ;
		BEGIN
		KernelLog.String("****SSLine***** "); 
		KernelLog.String(" x0= "); KernelLog.Int(x0, 4); 
		KernelLog.String(" y0= "); KernelLog.Int(y0, 4); 
		KernelLog.String(" x1= "); KernelLog.Int(x1, 4); 
		KernelLog.String(" y1= "); KernelLog.Int(y1, 4); 
		KernelLog.Ln; 

			IF (y0 = y1) THEN RETURN END;
			IF y0 > y1 THEN t := y0; y0 := y1; y1 := t; t := x0; x0 := x1; x1 := t END;
			xi := x0; xf :=	y0 - y1; mi := (x1 - x0) DIV (y1 - y0); mf := 2 * ( (x1 - x0) MOD (y1 - y0)); dt2 := 2 * (y1 - y0);
			FOR t := y0 TO y1 - 1 DO
				AddIntersection(t, xi);
				KernelLog.String("y= "); KernelLog.Int(t, 4); 	KernelLog.String(" x= "); KernelLog.Int(xi, 4); 		KernelLog.Ln;

				INC(xi, mi); INC(xf, mf);
				IF xf > 0 THEN INC(xi); DEC(xf, dt2) END
			END
		END AddLine;
( *)
		PROCEDURE AddLine*(x0, y0, x1, y1 : LONGINT);
		VAR t, xi, mi, xf, mf, dt2 : LONGINT;
		VAR
			p,p1 : Raster.Pixel;
			r, g, b, a : LONGINT;
			rmode: Raster.Mode;
			i:LONGINT;
			oy:LONGINT;
			ys,fl:LONGINT;
		BEGIN
(*		KernelLog.String("****AALine***** "); 
		KernelLog.String(" x0= "); KernelLog.Int(x0, 4); 
		KernelLog.String(" y0= "); KernelLog.Int(y0, 4); 
		KernelLog.String(" x1= "); KernelLog.Int(x1, 4); 
		KernelLog.String(" y1= "); KernelLog.Int(y1, 4); 
		KernelLog.Ln; *)
			WMGraphics.ColorToRGBA(color,r,g,b,a);
			Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)
			Raster.SetRGBA(p,r,g,b, a);
	IF y0 = y1 THEN (* horizontal case *)
		Raster.SetRGBA(p,r,g,b, 127);
		Raster.SetRGBA(p1,r,g,b, 255);
		FOR t := x0-1 TO x1 DO
				Raster.Put(img, t+dx, y0-1+dy, p, rmode);
				Raster.Put(img, t+dx, y0+dy, p1, rmode);
				Raster.Put(img, t+dx, y0+1+dy, p, rmode);
		END;

		RETURN;
	ELSIF x0 = x1 THEN (* vertical case *)
		IF y0 > y1 THEN t := y0; y0 := y1; y1 := t END;
		Raster.SetRGBA(p,r,g,b, 127);
		FOR t := y0 TO y1-1 DO
				AddIntersection(t, x0);
				Raster.Put(img, x0-1+dx, t+dy, p, rmode);
				Raster.Put(img, x0+dx, t+dy, p, rmode);
		END;
	ELSE (* general case *)

				IF ABS(y1 - y0) > ABS(x1 - x0) THEN
					IF y0 > y1 THEN t := y0; y0 := y1; y1 := t; t := x0; x0 := x1; x1 := t END;
					xi := x0; xf :=	y0 - y1; mi := (x1 - x0) DIV (y1 - y0); mf := 2 * ( (x1 - x0) MOD (y1 - y0)); dt2 := 2 * (y1 - y0);
					FOR t := y0 TO y1-1 DO
						a:=255*ABS(xf) DIV dt2;
						Raster.SetRGBA(p,r,g,b, a);
						Raster.Put(img, xi-1+dx, t+dy, p, rmode);
						Raster.SetRGBA(p,r,g,b, 255-a);
						Raster.Put(img, xi+dx, t+dy, p, rmode);
						AddIntersection(t, xi);
(*						KernelLog.String("y= "); KernelLog.Int(t, 4); 	KernelLog.String(" x= "); KernelLog.Int(xi, 4); 		KernelLog.Ln;*)
						INC(xi, mi); INC(xf, mf);
						IF xf > 0 THEN INC(xi); DEC(xf, dt2); END
					END
				ELSE
					IF x0 > x1 THEN t := y0; y0 := y1; y1 := t; t := x0; x0 := x1; x1 := t END;
					xi := y0; xf :=	x0 - x1; mi := (y1 - y0) DIV (x1 - x0); mf := 2 * ( (y1 - y0) MOD (x1 - x0)); dt2 := 2 * (x1 - x0);
					oy:=xi-1;
					
					IF y0>y1 THEN ys:=y0 
									ELSE ys:=y1 END;
					
					FOR t := x0 TO x1 DO
						IF (xi#oy)&(xi#ys) THEN 
(*							KernelLog.String("y= "); KernelLog.Int(xi, 4); 	KernelLog.String(" x= "); KernelLog.Int(t, 4); 		KernelLog.Ln;*)
							AddIntersection(xi,t);
						END;
						oy:=xi;
				IF (TRUE) THEN
						a:=255*ABS(xf) DIV dt2;
				IF mi<0 THEN 
						Raster.SetRGBA(p,r,g,b, 255-a);
						Raster.Put(img, t+dx, xi+dy, p, rmode);

(*						Raster.SetRGBA(p,r,g,b, 255);
						Raster.Put(img, t+dx-1, xi+dy, p, rmode);
*)
						Raster.SetRGBA(p,r,g,b, a);
						Raster.Put(img, t+dx, xi-1+dy, p, rmode);

				ELSE
(*						Raster.SetRGBA(p,r,g,b, 255);
						Raster.Put(img, t+dx-1, xi+dy, p, rmode);
*)
						Raster.SetRGBA(p,r,g,b, a);
						Raster.Put(img, t+dx, xi+dy, p, rmode);

						Raster.SetRGBA(p,r,g,b,255- a);
						Raster.Put(img, t+dx, xi+1+dy, p, rmode);
				END;
				END;
						INC(xi, mi); INC(xf, mf);
						IF xf > 0 THEN 
							INC(xi); DEC(xf, dt2); 
						END;

					END
				END
			END		END AddLine;
			
		(*!TODO: work of anti-aliasing is bad, need optimizing*)
		PROCEDURE FillFlat(color : WMGraphics.Color; mode : LONGINT);
		VAR i, sp, cur : LONGINT;
		in : BOOLEAN;
		BEGIN
			FOR i := 0 TO height - 1 DO
				cur := edges[i];
				in := FALSE;
				WHILE cur # 0 DO
					in := ~in;
					IF in THEN sp := fillHeap[cur].pos
					ELSE Fill(WMRectangles.MakeRect(sp, i, fillHeap[cur].pos, i + 1), color, mode)
					END;
					cur := fillHeap[cur].next
				END
			END
		END FillFlat;
		(* Polygon filling *)
		(** fill a polygon given by points *)
		PROCEDURE FillPolygonFlat*(CONST points : ARRAY OF WMGraphics.Point2d; nofPoints : LONGINT; color : WMGraphics.Color; mode : LONGINT);
		VAR i : LONGINT;
		BEGIN
			SELF.color:=color;
			IF nofPoints < 3 THEN RETURN END;
			ASSERT(nofPoints <= LEN(points));
			ClearHeap;
			FOR i := 1 TO nofPoints - 1 DO AddLine(points[i - 1].x, points[i - 1].y, points[i].x, points[i].y) END;
			AddLine(points[nofPoints - 1].x, points[nofPoints - 1].y, points[0].x, points[0].y);
			FillFlat(color, mode)
		END FillPolygonFlat;
(* The DrawSolidArc function takes standard arc drawing
 arguments but the "radius" has been split into 2 different
 variables, "innerRadius" and "outerRadius".*)
 VAR
	p:ARRAY 200 OF WMGraphics.Point2d;
		PROCEDURE DrawArcFlat* (centerX, centerY, innerRadius, outerRadius:LONGINT; startAngle, arcAngle : REAL; color : LONGINT);
		VAR
		    (* How much to rotate for each point along the arc.*)
			steps:LONGINT;
			angleStep:REAL;
			angle, endAngle:REAL;
			i, j : LONGINT;

		BEGIN
			steps:=64;
			 angleStep:=arcAngle/steps;
		    (* Find the coordinates of the first point on the inner arc.*)
			p[0].x := ENTIER(centerX + Math.cos(startAngle) * innerRadius+0.5);
			p[0].y := ENTIER(centerY + Math.sin(startAngle) * innerRadius+0.5);

			(* Draw all of the other points along the inner arc.*)
			j := 1;
			FOR i:=1 TO steps DO
				angle := (startAngle + i * angleStep);
		(*		KernelLog.String(' i = '); KernelLog.Int(i, 0);  KernelLog.String(' angle = '); Strings.FloatToStr(angle, 4, 10, 0, str); KernelLog.String(str);KernelLog.Ln;*)
				p[i].x :=  ENTIER(centerX + Math.cos(angle) * innerRadius+0.5);
				p[i].y :=  ENTIER(centerY + Math.sin(angle) * innerRadius+0.5);
				INC(j);
			END;
			(*Determine the ending angle of the arc so you can
			rotate around the outer arc in the opposite direction.*)
			endAngle := startAngle + arcAngle;

		    (*Start drawing all points on the outer arc.*)
		    FOR i:=0 TO steps DO
				(* To go the opposite direction, we subtract rather than add.*)
				angle := (endAngle - i * angleStep);
		(*		KernelLog.String(' i = '); KernelLog.Int(j+i, 0);  KernelLog.String(' angle = '); Strings.FloatToStr(angle, 4, 10, 0, str); KernelLog.String(str);KernelLog.Ln;*)
				p[j+i].x :=  ENTIER(centerX + Math.cos(angle) * outerRadius+0.5);
				p[j+i].y :=  ENTIER(centerY + Math.sin(angle) * outerRadius+0.5);
				
			END;

			FillPolygonFlat(p, steps*2+2, color, WMGraphics.ModeCopy);
		END DrawArcFlat;
	END Canvas;
	
PROCEDURE GenCanvas*(img: Raster.Image): WMGraphics.BufferCanvas;
VAR c: Canvas;
BEGIN NEW(c,img); RETURN c
END GenCanvas;

END AAGraphics.
