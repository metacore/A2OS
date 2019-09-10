MODULE ColorModels; (** AUTHOR ""; PURPOSE ""; *)
(* ported from Oberon.ColorModels.Mod and Oberon.Colors.Mod
 - use SIGNED32 [0,255] instead of FLOAT32 [0,1] (compatible with WMGraphics.Mod)
*)

(** convert a RedGreenBlue color specification to HueSaturationValue *)
PROCEDURE RGBToHSV*(r,g,b : SIGNED32; VAR h,s,v: FLOAT32);
VAR
	m,rl,gl,bl, rr, gg, bb: FLOAT32;
BEGIN
	rr := r / 255; gg := g / 255; bb := b / 255;

	IF (gg > b) THEN	(* set v *)
		IF (rr > gg) THEN v:= rr; ELSE v:= gg; END;
	ELSE
		IF (rr > bb) THEN v:= rr; ELSE v:= bb; END;
	END;
	IF (gg < bb) THEN
		IF (rr < gg) THEN m:= rr; ELSE m:= gg; END;
	ELSE
		IF (rr < bb) THEN m:= rr; ELSE m:= bb; END;
	END;
	IF (v # 0.0) THEN s:= (v - m) / v; ELSE s:= 0.0; END;	(* set s *)
	IF (s # 0.0) THEN
		rl:= (v - rr) / (v - m);	(* distance of color from red *)
		gl:= (v - gg) / (v - m);	(* distance of color from green *)
		bl:= (v - bb) / (v - m);	(* distance of color from blue *)
		IF (v = rr) THEN IF (m = gg) THEN h:= 5.0 + bl; ELSE h:= 1.0 - gl; END; END;
		IF (v = gg) THEN
			IF (m = bb) THEN h:= 1.0 + rl; ELSE h:= 3.0 - bl; END;
		ELSIF (m = rr) THEN
			h:= 3.0 + gl;
		ELSE
			h:= 5.0 - rl;
		END;
		h:= h * 60.0;
	ELSE
		h:= 0.0;
	END;
END RGBToHSV;

(** convert a HueSaturationValue color specification to RedGreenBlue *)
PROCEDURE HSVToRGB*(h,s,v: FLOAT32; VAR rl,gl,bl: SIGNED32);
VAR
	i: SIGNED32;
	f,p1,p2,p3, r, g, b: FLOAT32;
BEGIN
	IF h = 360.0 THEN h:= 0.0; ELSE h:= h / 60.0; END;	(* convert h to be in [0,6] *)
	i:= ENTIER(h); f:= h - i;
	p1:= v * (1.0 - s); p2:= v * (1.0 - (s * f)); p3:= v * (1.0 - (s * (1.0 - f)));
	CASE i OF
	|	0: r:= v; g:= p3; b:= p1;
	|	1: r:= p2; g:= v; b:= p1;
	|	2: r:= p1; g:= v; b:= p3;
	|	3: r:= p1; g:= p2; b:= v;
	|	4: r:= p3; g:= p1; b:= v;
	|	5: r:= v; g:= p1; b:= p2;
	END;
	rl := ENTIER ( r*255 ); gl := ENTIER ( g*255 ); bl := ENTIER ( b*255 );
END HSVToRGB;

(** convert a RedGreenBlue color specification to CyanMagentaYellow *)
PROCEDURE RGBToCMY*(r,g,b: FLOAT32; VAR c,m,y: FLOAT32);
BEGIN
	c:= 1.0 - r/255; m:= 1.0 - g/255; y:= 1.0 - b/255;
END RGBToCMY;

(** convert a CyanMagentaYellow color specification to RedGreenBlue *)
PROCEDURE CMYToRGB*(c,m,y: FLOAT32; VAR r,g,b: SIGNED32);
BEGIN
	r:= ENTIER ( (1.0 - c)*255 ); g:= ENTIER ( (1.0 - m)*255 ); b:= ENTIER ( (1.0 - y)*255 );
END CMYToRGB;

(** CMYK (Cyan Magenta Yellow blacK) model **)
PROCEDURE RGBToCMYK* (rl, gl, bl: SIGNED32; VAR c, m, y, k: FLOAT32);
VAR r, g, b : FLOAT32;
BEGIN
	r := rl / 255; g := gl / 255; b := bl / 255;
	c := 1 - r; m := 1 - g; y := 1 - b;
	IF r < g THEN
		IF b < r THEN k := b
		ELSE k := r
		END
	ELSE
		IF b < g THEN k := b
		ELSE k := g
		END
	END;
	c := c - k; m := m - k; y := y - k
END RGBToCMYK;

PROCEDURE CMYKToRGB* (c, m, y, k: FLOAT32; VAR r, g, b: FLOAT32);
BEGIN
	r := 1 - (k + c); g := 1 - (k + m); b := 1 - (k + y)
END CMYKToRGB;

END ColorModels.
