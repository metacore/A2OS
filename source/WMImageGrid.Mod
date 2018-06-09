(*Author: Stephan Koster; Purpose: Components to display multiple images arranged in a grid*)
MODULE WMImageGrid;
IMPORT WMWindowManager, Graphics:=WMGraphics, Raster, Messages:=WMMessages, Rectangles:=WMRectangles;

TYPE Message=Messages.Message;
TYPE Rectangle=Rectangles.Rectangle;
TYPE Grid=ARRAY OF ARRAY OF Graphics.Image;


TYPE GridWindow* = OBJECT(WMWindowManager.Window)
	VAR
		imgs*: POINTER TO Grid;
		background*: Graphics.Image;
		canvas* : Graphics.BufferCanvas;
		canvasGen-: Graphics.CanvasGenerator;
		pointerThreshold*, 
		maxInterpolation* : LONGINT; (* allows limiting the interpolation degree on Draw *)
		hs,ws: POINTER TO ARRAY OF LONGINT;
		totalW, totalH: LONGINT;
		gap: LONGINT;		
		
		PROCEDURE &Init1*( CONST Ws, Hs: ARRAY OF LONGINT; alpha : BOOLEAN);
		VAR
			i,j: LONGINT;
			rm: Raster.Mode;
			pix: Raster.Pixel;
		BEGIN
			gap:=10;
			NEW(SELF.ws, LEN(Ws));
			NEW(SELF.hs, LEN(Hs));
			FOR i:=0 TO LEN(Ws,0)-1 DO
				ASSERT(Ws[i]>0);
				SELF.ws[i]:=Ws[i];
				totalW:=totalW+Ws[i];
			END;
			totalW:=totalW+gap*(LEN(Ws,0)-1);
			
			FOR i:=0 TO LEN(Hs,0)-1 DO
				ASSERT(Hs[i]>0);
				SELF.hs[i]:=Hs[i];
				totalH:=totalH+Hs[i];
			END;
			totalH:=totalH+gap*(LEN(Hs,0)-1);			
			
			Init(totalW, totalH, alpha); (*parent constructor*)
			
			NEW(imgs,LEN(Ws,0),LEN(Hs,0));
			FOR i:=0 TO LEN(Ws,0)-1 DO
				FOR j:=0 TO LEN(Hs,0)-1 DO
					NEW(imgs[i,j]);
					IF alpha THEN Raster.Create(imgs[i,j], Ws[i], Hs[j], Raster.BGRA8888) ELSE Raster.Create(imgs[i,j], Ws[i], Hs[j], WMWindowManager.format) END;
				END
			END;
			NEW(background);
			IF alpha THEN Raster.Create(background, totalW, totalH, Raster.BGRA8888) ELSE Raster.Create(background, totalW, totalH, WMWindowManager.format) END;
			Raster.InitMode(rm, Raster.srcOverDst);
			Raster.SetRGBA(pix, 0,0,0,255);
			Raster.Fill(background, 0,0, totalW,totalH,pix, rm);
			SetCanvasGenerator(Graphics.GenCanvas);
			pointerThreshold := 1; (* invisible pixels are treated as invisible *)
			maxInterpolation := Graphics.ScaleBilinear;
		END Init1;

		PROCEDURE SetCanvasGenerator*(canvasGen:Graphics.CanvasGenerator);
		BEGIN{EXCLUSIVE}
			SELF.canvasGen:=canvasGen; IF background # NIL THEN canvas:=canvasGen(background); END;
			IF manager # NIL THEN manager.AddVisibleDirty(SELF, bounds) END
		END SetCanvasGenerator;
		
		PROCEDURE IsHit(x, y  : LONGINT) : BOOLEAN;
		VAR w, h : LONGINT; fx, fy : REAL;
		BEGIN
			w := GetWidth(); h := GetHeight();
			IF (w > 0) & (h > 0) & ((w # totalW) OR (h # totalH)) THEN
				fx := totalW/ w;
				fy := totalH/ h;
				RETURN Graphics.IsBitmapHit(ENTIER(x * fx), ENTIER(y * fy), pointerThreshold, background)
			ELSE RETURN Graphics.IsBitmapHit(x, y, pointerThreshold, background)
			END
		END IsHit;

		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h, q : LONGINT);
		VAR 
			mode: LONGINT;
			isScaled: BOOLEAN;
			i,j: LONGINT;
			x,y: LONGINT;
			
			PROCEDURE DrawSingle(CONST  img: Graphics.Image; offX,offY: LONGINT; isScaled: BOOLEAN; mode: LONGINT);
			VAR
				wscaled,hscaled: LONGINT;
			BEGIN
				IF img # NIL THEN
				IF ~isScaled THEN				
					canvas.DrawImage(offX,offY,img, mode);
				ELSE
					offX:=offX*w DIV totalW;  (*these are not pixel perfect, but I can't think of anything better*)
					offY:=offY*h DIV totalH;
					wscaled:=img.width*w DIV totalW; (*this means if the image is not actually the size suggested by ws[i],hs[j], then it won't be blown up to fill the space.*)
					hscaled:=img.height*h DIV  totalH;
					canvas.ScaleImage(img, Rectangles.MakeRect(0, 0, img.width, img.height), Rectangles.MakeRect(offX,offY, offX+wscaled, offY+hscaled), mode, MIN(q,maxInterpolation));
				END
			END;
			END DrawSingle;
			
		BEGIN
			IF useAlpha THEN
				mode:=Graphics.ModeSrcOverDst;
			ELSE
				mode:=Graphics.ModeCopy;
			END;
			isScaled:=~((w = totalW) & (h = totalH));
		
			IF reduceQuality THEN q := 0 END;
			DrawSingle(background, 0,0, isScaled, mode);
			x:=0;
			FOR i:=0 TO LEN(imgs,0)-1 DO
				y:=0;
				FOR j:=0 TO LEN(imgs,1)-1 DO
					DrawSingle(imgs[i,j], x,y, isScaled,mode);
					y:=y+hs[j]+gap;
				END;				
				x:=x+ws[i]+gap;
			END;
			
			
			INC(timestamp);
		END Draw;

		PROCEDURE Invalidate*(rect : Rectangle);
		VAR w, h : LONGINT; fx, fy : LONGREAL;
		BEGIN
			w := GetWidth(); h := GetHeight();
			IF (w > 0) & (h > 0) & ((w # totalW) OR (h # totalH))  THEN
				fx := w / totalW; fy := h / totalH;
				rect.l := ENTIER(rect.l * fx); rect.t := ENTIER(rect.t * fy);
				rect.r := ENTIER(rect.r * fx + 0.5); rect.b := ENTIER(rect.b * fy + 0.5)
			END;
			Invalidate^(rect)
		END Invalidate;

		PROCEDURE Handle*(VAR m : Message);
		VAR w, h : LONGINT; fx, fy : REAL;
		BEGIN
			w := GetWidth(); h := GetHeight();
			IF (w > 0) & (h > 0) & ((w # totalW) OR (h # totalH)) & (m.msgType = Messages.MsgPointer) THEN
				m.x := m.x-bounds.l; m.y := m.y-bounds.t;
				fx := totalW/ w;
				fy := totalH/ h;
				m.x := ENTIER(m.x * fx); m.y := ENTIER(m.y * fy);
				m.x := m.x + bounds.l; m.y := m.y+bounds.l;
			ELSIF m.msgType = Messages.MsgInvalidate THEN
				IF m.msgSubType = Messages.MsgSubAll THEN
					Invalidate(Rectangles.MakeRect(0, 0, totalW, totalH));
				ELSE
					HALT(200)
				END;			
			ELSE 
				Handle^(m)
			END;
		END Handle;

	END GridWindow;



	PROCEDURE Test*();
	VAR
		w: GridWindow;
		Ws,Hs: ARRAY 3 OF LONGINT;
		i: LONGINT;
		rm: Raster.Mode;
		pix: Raster.Pixel;
	BEGIN
	
		FOR i:=0 TO 2 DO
			Ws[i]:=100*i+30;
			Hs[i]:=20+200*i;
		END;
		NEW(w,Ws,Hs, TRUE);
		
		
		Raster.InitMode(rm, Raster.srcOverDst);
		Raster.SetRGBA(pix, 255,0,0,255);	
		Raster.Fill(w.imgs[0,0], 0,0, Ws[0],Hs[0],pix, rm);
		Raster.SetRGBA(pix, 0,255,0,255);	
		Raster.Fill(w.imgs[1,1], 0,0, Ws[1],Hs[1],pix, rm);
		Raster.SetRGBA(pix, 0,0,255,255);	
		Raster.Fill(w.imgs[2,2], 0,0, Ws[2],Hs[2],pix, rm);
		
		WMWindowManager.DefaultAddWindow(w);
		
		
	END Test;


END WMImageGrid.


System.FreeDownTo WMImageGrid~
WMImageGrid.Test~