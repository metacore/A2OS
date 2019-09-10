MODULE antsEffects IN Oberon;
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)




(*** Implements special effects and encapsulates a few platform dependent features, overwrites procedures from vyTracking. Do not use this Module,
use vyTracking instead.. *)

IMPORT vyRandom, vyRectangles, Display, Images,  Input, Oberon, Modules, antsPortability,vyPortability,
  vyGraphBase, vyGraphBase0,aM := antsMessages;

TYPE



	tBuffer = RECORD
		X, Y, W, H: SIGNED16;
		x, y: SIGNED16;   (* origin *)
		buf: Images.Image;
		img: Images.Image;
	END;

VAR
	copy: Images.Image;
	db: vyGraphBase.doubleBuffer;
	fb: tBuffer;

	(** Snap X, Y to the snapping grid. *)


PROCEDURE OpenBuffer (VAR buf: tBuffer;   x, y, w, h: SIGNED16);
BEGIN
	buf.x := x;   buf.y := y;
	(* opens a buffer x-50,y-50,w+100,h+100 *)
	IF (buf.W < w) OR (buf.H < h) THEN
		buf.X := x;   buf.Y := y;   buf.W := w;   buf.H := h;
		vyRectangles.RectIntersection(buf.X, buf.Y, buf.W, buf.H, 0, 0, Display.Width, Display.Height);
		NEW(buf.img);   Images.Create(buf.img, buf.W, buf.H, Images.DisplayFormat);
		NEW(buf.buf);   Images.Create(buf.buf, buf.W, buf.H, Images.DisplayFormat);
	ELSE
		buf.X := x;   buf.Y := y
	END;
	Display.TransferBlock(buf.buf.mem^, 0, buf.buf.bpr, buf.X, buf.Y, buf.W, buf.H, Display.get)
END OpenBuffer;

PROCEDURE Ants* (x, y, w, h: SIGNED16;  num: SIGNED16;  dur: SIGNED32);
	VAR xp, yp: POINTER TO ARRAY OF SIGNED16;  timee, time, i: SIGNED32;  r : FLOAT64;
	dir: POINTER TO ARRAY  OF SIGNED16;
BEGIN
	vyGraphBase.SetDisplayMode(vyGraphBase.invert);
	vyGraphBase.SetScreenCoordinate;
	vyGraphBase.UseClipMask(NIL);
	NEW(xp, num);  NEW(yp, num);  NEW(dir, num);
	FOR i := 0 TO num - 1 DO
		(*
		xp[i] := x+w DIV 2; yp[i] := y+h DIV 2;
		*)
		xp[i] := x + SHORT(ENTIER(vyRandom.Uniform() * w));
		yp[i] := y + SHORT(ENTIER(vyRandom.Uniform() * h));
		dir[i] := SHORT(ENTIER(vyRandom.Uniform() * 5));
		vyGraphBase.ReplConst(xp[i], yp[i], 3, 3);
	END;
	vyPortability.DisplayUpdate;

	dur := dur * Input.TimeUnit DIV 1000;
	time := Oberon.Time();
	timee := Oberon.Time() + dur;
	WHILE(timee > Oberon.Time()) DO
		FOR i := 0 TO num - 1 DO
			vyGraphBase.ReplConst(xp[i], yp[i], 3, 3);
			r := vyRandom.Uniform();
			IF r < 0.5 THEN
				IF dir[i] = 0 THEN r := 0.125
				ELSIF dir[i] = 1 THEN r := 0.375
				ELSIF dir[i] = 2 THEN r := 0.6
				ELSIF dir[i] = 4 THEN r := 0.9
				END
			ELSE
				r := vyRandom.Uniform()
			END;
			IF r < 0.5 THEN
				xp[i] := xp[i] + 1
			ELSE
				xp[i] := xp[i] - 1;  r := r - 0.5
			END;
			IF r < 0.25 THEN
				yp[i] := yp[i] + 1
			ELSE
				yp[i] := yp[i] - 1
			END;
			IF xp[i] > vyPortability.DisplayWidth() THEN xp[i] := SHORT(vyPortability.DisplayWidth())
			ELSIF xp[i] < 0 THEN xp[i] := 0
			END;
			IF yp[i] > vyPortability.DisplayHeight() THEN yp[i] := SHORT(vyPortability.DisplayHeight())
			ELSIF yp[i] < 0 THEN yp[i] := 0
			END;
			vyGraphBase.ReplConst(xp[i], yp[i], 3, 3)
		END;
		vyPortability.DisplayUpdate;
	END;
	FOR i := 0 TO num - 1 DO
		vyGraphBase.ReplConst(xp[i], yp[i], 3, 3)
	END;
	vyPortability.DisplayUpdate;
	vyGraphBase.SetDisplayMode(vyGraphBase.replace)
END Ants;

PROCEDURE FadeImage*(fimg,timg: Images.Image; factor: FLOAT32);
VAR pix:  Images.Pixel; y,x: SIGNED16; r,g,b,a: SIGNED16;
BEGIN
	FOR y := 0 TO fimg.height-1 DO
		FOR x := 0 TO fimg.width-1 DO
			Images.Get(fimg,x,y,pix,Images.SrcCopy);
			Images.GetRGBA(pix,r,g,b,a);
			Images.SetRGBA(pix,r,g,b,SHORT(ENTIER(a*factor+0.5)));
			Images.Put(timg,x,y,pix,Images.SrcCopy);
		END;
	END;
END FadeImage;

PROCEDURE FadeIn*(pict: Images.Image;  time: SIGNED32; x,y,w,h: SIGNED16);
VAR   t, time0: SIGNED32;
	fact: FLOAT32;
	cur: antsPortability.display;
BEGIN
	NEW(copy);
	Images.Create(copy, pict.width, pict.height, Images.BGRA8888);
	time := time * Input.TimeUnit DIV 1000;
	cur := antsPortability.GetCurrentDisplay();
	antsPortability.SetCurrentDisplay(antsPortability.Desktop());
	Display.ResetClip();
	vyGraphBase.UseClipMask(NIL);
	OpenBuffer(fb, x, y, w, h);
	time0 := Oberon.Time();
	t := 0;
	vyGraphBase.SetAlpha(255);
	WHILE(t < time) DO
		fact := (t+1) / time  ;
		Images.Copy(fb.buf, fb.img, 0, 0, fb.img.width, fb.img.height, 0, 0, Images.SrcCopy);   (* SrcOverDst *)
		FadeImage(pict,copy,fact);
		vyGraphBase.openDB(db, x, y,w,h,TRUE);
		vyGraphBase0.UseAsBufferBG(db,fb.img);
		vyGraphBase.StretchedImage(copy,0,0,pict.width,pict.height,x,y,w,h);
		vyGraphBase.writeDB( );
		vyPortability.DisplayUpdate;
		vyGraphBase.closeDB();
		t := Oberon.Time() - time0;
	END;
END FadeIn;

PROCEDURE Launch*(pict: Images.Image; x,y,w,h: SIGNED16);
VAR   t, time0,time: SIGNED32;
	fact: FLOAT32;
	cur: antsPortability.display;

BEGIN
	NEW(copy);
	Images.Create(copy, pict.width, pict.height, Images.BGRA8888);
	cur := antsPortability.GetCurrentDisplay();
	antsPortability.SetCurrentDisplay(antsPortability.Desktop());
	Display.ResetClip();
	vyGraphBase.UseClipMask(NIL);
	OpenBuffer(fb, x, y, w, h);
	time := 3*Input.TimeUnit DIV 2 ;
	time0 := Oberon.Time();
	t := 0;
	vyGraphBase.SetAlpha(255);
	WHILE(t < time) DO
		fact := (t+1)*(t+1) /time/ time  ;
		Images.Copy(fb.buf, fb.img, 0, 0, fb.img.width, fb.img.height, 0, 0, Images.SrcCopy);   (* SrcOverDst *)
		FadeImage(pict,copy,fact);
		vyGraphBase.openDB(db, x, y,w,h,TRUE);
		vyGraphBase0.UseAsBufferBG(db,fb.img);
		vyGraphBase.StretchedImage(copy,0,0,pict.width,pict.height,x,y,w,h);
		vyGraphBase.writeDB( );
		vyPortability.DisplayUpdate;
		vyGraphBase.closeDB();
		t := Oberon.Time() - time0;
	END;

	Images.Copy(fb.buf, fb.img, 0, 0, fb.img.width, fb.img.height, 0, 0, Images.SrcCopy);   (* SrcOverDst *)
	FadeImage(pict,copy,1);
	vyGraphBase.openDB(db, x, y,w,h,TRUE);
	vyGraphBase0.UseAsBufferBG(db,fb.img);
	vyGraphBase.StretchedImage(copy,0,0,pict.width,pict.height,x,y,w,h);
	vyGraphBase.writeDB( );
	vyPortability.DisplayUpdate;
	vyGraphBase.closeDB();

	Ants(0, 0, SHORT(vyPortability.DisplayWidth()), SHORT(vyPortability.DisplayHeight()), 1000, 1500);

	time :=  Input.TimeUnit;
	time0 := Oberon.Time();
	t := 0;
	vyGraphBase.SetAlpha(255);
	WHILE(t < time) DO
		fact := 1- (t+1) / time ;
		Images.Copy(fb.buf, fb.img, 0, 0, fb.img.width, fb.img.height, 0, 0, Images.SrcCopy);   (* SrcOverDst *)
		FadeImage(pict,copy,fact);
		vyGraphBase.openDB(db, x, y,w,h,TRUE);
		vyGraphBase0.UseAsBufferBG(db,fb.img);
		vyGraphBase.StretchedImage(copy,0,0,pict.width,pict.height,x,y,w,h);
		vyGraphBase.writeDB( );
		vyPortability.DisplayUpdate;
		vyGraphBase.closeDB();
			t := Oberon.Time() - time0;
	END;
	Images.Copy(fb.buf, fb.img, 0, 0, fb.img.width, fb.img.height, 0, 0, Images.SrcCopy);   (* SrcOverDst *)
	vyGraphBase.openDB(db, x, y,w,h,TRUE);
	vyGraphBase0.UseAsBufferBG(db,fb.img);
	vyGraphBase.writeDB( );
	vyPortability.DisplayUpdate;
	vyGraphBase.closeDB();

END Launch;



PROCEDURE Init;
VAR m: Modules.Module;
BEGIN
	 m := Modules.ThisMod("antsTracking"); (* Install ants Tracking routines *)
END Init;


BEGIN
	aM.launch; Init();
END antsEffects.

