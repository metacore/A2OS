MODULE srTexVox;
IMPORT srBase, Raster, Graphics := WMGraphics, Random, Math, srMath;

TYPE SREAL=srBase.SREAL;
TYPE Ray = srBase.Ray;
TYPE Voxel = srBase.Voxel;
TYPE Name = srBase.Name;

TYPE TexVox* = OBJECT(Voxel);
VAR
	img*: Raster.Image;
	fmt: Raster.Format;
	copy : Raster.Mode;
	W,H, bpr,adr: SIZE;
	transparent*: BOOLEAN;

PROCEDURE & init*(n: Name);
BEGIN
	Raster.InitMode(copy, Raster.srcCopy);
	img :=Graphics.LoadImage(n, TRUE);
	IF img#NIL THEN W := img.width-1; H:= img.height-1; END;
END init;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	p: Raster.Pixel;
	xi,yj: SIZE;
	X,Y: SREAL;
	r,g,b: SREAL;
	a, lx, ly: SREAL;
	nx, ny, nz: INTEGER;
	dot: SREAL;
	inside: BOOLEAN;
BEGIN
	IF img#NIL THEN
		CASE ray.face OF
			0: inside := TRUE
			|1: nx := -1
			|2: ny := -1
			|3: nz := -1
			|4: nx := 1
			|5: ny := 1
			|6: nz := 1
		ELSE
		END;
		IF ~inside THEN
			dot := ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z);
	(*		CASE ray.face OF
				1: lx := ray.lxyz.y; ly :=  ray.lxyz.z;
				| 2:  lx := ray.lxyz.x; ly := ray.lxyz.z;
				| 3: lx := ray.lxyz.x; ly := ray.lxyz.y;
				| 4: lx := ray.lxyz.y; ly := ray.lxyz.z;
				| 5: lx := ray.lxyz.x; ly := ray.lxyz.z;
				| 6: lx := ray.lxyz.x; ly := ray.lxyz.y;
			ELSE
			END; *)
			X:=(1-lx)*W; Y:=(1-ly)*H;
			xi:=ENTIER(X)MOD W; yj:=H - (ENTIER(Y) MOD H);
			Raster.Get(img,xi,yj,p,copy);
			a:= ORD(p[3])/255; r := ORD(p[2])/255; g := ORD(p[1])/255; b := ORD(p[0])/255;
		       ray.r := ray.r + r*ray.ra*dot;
			ray.g := ray.g + g*ray.ga *dot;
			ray.b := ray.b + b*ray.ba*dot;
			ray.ra := ray.ra-(b+g);
			ray.ga := ray.ga-(r+b);
			ray.ba := ray.ba-(r+g);
			srBase.clamp3(ray.ra,ray.ga, ray.ba);
			ray.a := (ray.ra+ray.ga+ray.ba)/3;
		(*	ray.ra := 0; ray.ga := 0; ray.ba := 0; ray.a := 0; *)
		END
	END;
END Shade;

END TexVox;

TYPE texmirrorVox* = OBJECT(TexVox);
VAR
	r, g, b, a, red, blue, green: SREAL;

PROCEDURE SetColor* (R, G, B, alpha: SREAL);
BEGIN
	red := R; green := G; blue := B;
	r := srBase.clamp(red * alpha);
	g := srBase.clamp(green * alpha);
	b := srBase.clamp(blue * alpha);
	a := srBase.clamp(alpha);
END SetColor;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	p: Raster.Pixel;
	xi,yj: SIZE;
	X,Y: SREAL;
	r,g,b: SREAL;
	dr,dg,db: SREAL;
	lx, ly: SREAL;
	nx, ny, nz: INTEGER;
	dot: SREAL;
	inside: BOOLEAN;
BEGIN
	IF img#NIL THEN
		CASE ray.face OF
			0: inside := TRUE
			|1: nx := -1
			|2: ny := -1
			|3: nz := -1
			|4: nx := 1
			|5: ny := 1
			|6: nz := 1
		ELSE
		END;
		IF ~inside THEN
			dot := ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z);
			CASE ray.face OF
				1: lx := ray.lxyz.y; ly :=  ray.lxyz.z;
				| 2:  lx := ray.lxyz.x; ly := ray.lxyz.z;
				| 3: lx := ray.lxyz.x; ly := ray.lxyz.y;
				| 4: lx := ray.lxyz.y; ly := ray.lxyz.z;
				| 5: lx := ray.lxyz.x; ly := ray.lxyz.z;
				| 6: lx := ray.lxyz.x; ly := ray.lxyz.y;
			ELSE
			END;
			X:=(1-lx)*W; Y:=(1-ly)*H;
			xi:=ENTIER(X) MOD W; yj:=ENTIER(Y) MOD H;
			Raster.Get(img,xi,yj,p,copy);
			r := ORD(p[2])/255; g := ORD(p[1])/255; b := ORD(p[0])/255;
			dr := r*ray.ra*dot;
			dg := g*ray.ga*dot;
			db := b*ray.ba*dot;
			ray.r := ray.r + dr;
			ray.g := ray.g + dg;
			ray.b := ray.b + db;
			ray.ra := ray.ra - dr;
			ray.ga := ray.ga - dg;
			ray.ba := ray.ba- db;
			ray.a := (ray.ra+ray.ga+ray.ba)/3;
			IF ray.a > 0.25 THEN
				mirror(ray)
			ELSE
				ray.a := 0
			END
		END
	END;
END Shade;

END texmirrorVox;

TYPE scrollVox* = OBJECT(Voxel);
VAR
	img*: Raster.Image;
	fmt: Raster.Format;
	copy : Raster.Mode;
	w,h, bpr,adr: SIZE;
	transparent: BOOLEAN;
	off: INTEGER;

PROCEDURE & init*(n: Name);
BEGIN
	img :=Graphics.LoadImage(n, TRUE);
	w := img.width-1; h := img.height-1;
	Raster.InitMode(copy, Raster.srcCopy);
	register;
END init;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	p: Raster.Pixel;
	x,y: SIZE;
	r,g,b: SREAL;
	lx, ly: SREAL;
	nx, ny, nz: INTEGER;
	dot: SREAL;
	inside: BOOLEAN;
BEGIN
	IF img#NIL THEN
	CASE ray.face OF
		0: inside := TRUE
		|1: nx := -1
		|2: ny := -1
		|3: nz := -1
		|4: nx := 1
		|5: ny := 1
		|6: nz := 1
	ELSE
	END;
	IF ~inside THEN
		dot := ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z);
			CASE ray.face OF
				1: lx := ray.lxyz.y; ly :=  ray.lxyz.z;
				| 2:  lx := ray.lxyz.x; ly := ray.lxyz.z;
				| 3: lx := ray.lxyz.x; ly := ray.lxyz.y;
				| 4: lx := ray.lxyz.y; ly := ray.lxyz.z;
				| 5: lx := ray.lxyz.x; ly := ray.lxyz.z;
				| 6: lx := ray.lxyz.x; ly := ray.lxyz.y;
			ELSE
			END;
		x :=  ENTIER((1-lx)*w); y :=  ENTIER((1-ly)*h);
		x := x MOD w;
		y := y MOD h;
		Raster.Get(img,(x+off) MOD w,(y+off) MOD h,p,copy);
		r := ORD(p[2])/255; g := ORD(p[1])/255; b := ORD(p[0])/255;
		ray.r := ray.r + r*ray.ra*dot;
		ray.g := ray.g + g*ray.ga*dot;
		ray.b := ray.b + b*ray.ba*dot;
		ray.a := 0;
		END
	END
END Shade;

(*PROCEDURE tick;
BEGIN
	off := SHORT((off+1) MOD w);
END tick;*)

END scrollVox;

TYPE interfereVox* = OBJECT(Voxel);
VAR
	imgn, imgm*: Raster.Image;
	fmt: Raster.Format;
	copy : Raster.Mode;
	w,h, bpr,adr: SIZE;
	done: BOOLEAN;
	off: INTEGER;

PROCEDURE & init*(n,m: Name);
BEGIN
	imgn:=Graphics.LoadImage(n, TRUE);
	w := imgn.width-1; h := imgn.height-1;
	imgm:=Graphics.LoadImage(n, TRUE);
	w := imgm.width-1; h := imgm.height-1;
	Raster.InitMode(copy, Raster.srcCopy);
	register;
END init;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	p: Raster.Pixel;
	x,y: SIZE;
	r,g,b: SREAL;
	lx, ly: SREAL;
BEGIN
	CASE ray.face OF
		1: lx := ray.lxyz.y; ly :=  ray.lxyz.z;
		| 2:  lx := ray.lxyz.x; ly := ray.lxyz.z;
		| 3: lx := ray.lxyz.x; ly := ray.lxyz.y;
		| 4: lx := ray.lxyz.y; ly := ray.lxyz.z;
		| 5: lx := ray.lxyz.x; ly := ray.lxyz.z;
		| 6: lx := ray.lxyz.x; ly := ray.lxyz.y;
	ELSE
	END; 	x :=  ENTIER((lx)*w); y :=  ENTIER((1-ly)*h);
	IF x < 0 THEN x := 0 ELSIF x > w THEN x := w END;
	IF y < 0 THEN y := 0 ELSIF y > h THEN y := h END;
	Raster.Get(imgn,(x+off) MOD w,y,p,copy);
	r := ORD(p[2])/255; g := ORD(p[1])/255; b := ORD(p[0])/255;
	ray.r := ray.r + r ;
	ray.g := ray.g + g ;
	ray.b := ray.b + b ;
	Raster.Get(imgm,x,y,p,copy);
	r := ORD(p[0])/255; g := ORD(p[1])/255; b := ORD(p[0])/255;
	ray.r := ray.r + r ;
	ray.g := ray.g + g ;
	ray.b := ray.b + b ;
	ray.a := 0;
END Shade;

PROCEDURE tick*;
BEGIN
	off := INTEGER((off+1) MOD w);
END tick;

END interfereVox;

(*
NOT WORKING NOW.
TYPE mirVox *= OBJECT(Voxel);
VAR
	fmt: Raster.Format;
	w,h, bpr,adr: LONGINT;
	done: BOOLEAN;

PROCEDURE & init;
BEGIN
	w := 100;  h := 100;
END init;

PROCEDURE Shade (VAR ray: Ray);
VAR
	p: Raster.Pixel;
	x,y: LONGINT;
	red,green,blue, alpha: SREAL;
	a,b,c,lx,ly: SREAL;
BEGIN
	a := ABS(1/2 - ray.lx); b := ABS(1/2 - ray.ly); c := ABS(1/2 - ray.lz);
	IF (a > b) & (a > c ) THEN
		 lx := ray.ly; ly := ray.lz;
	ELSIF (b > a) & (b > c ) THEN
		lx := ray.lx; ly := ray.lz;
	ELSIF (c > a) & (c > b ) THEN
		lx := ray.lx; ly := ray.ly;
	END;
	x :=  ENTIER(lx*w); y :=  ENTIER(ly*h);
	IF x < 0 THEN x := (w DIV 2) ELSIF x > w THEN x := (w DIV 2) END;
	IF y < 0 THEN y := (h DIV 2) ELSIF y > h THEN y := (h DIV 2) END;
	Raster.Get(srBase.img,w-x,y,p,srBase.copy);
	red := ORD(p[2])/255; green := ORD(p[1])/255; blue := ORD(p[0])/255;
	ray.r := ray.r + red;
	ray.g := ray.g + green;
	ray.b := ray.b + blue;
	ray.a :=  0;
END Shade;

END mirVox; *)

TYPE TexSph*= OBJECT(TexVox);
VAR
	cx, cy, cz: SREAL;
	D2: SREAL;

PROCEDURE & init*(n: Name);
BEGIN
	img :=Graphics.LoadImage(n, TRUE);
	W := img.width-1; H:= img.height-1;
	Raster.InitMode(copy, Raster.srcCopy);
	D2 := 1/4;
	cx := 1/2; cy := 1/2; cz := 1/2;
END init;

PROCEDURE ctop(x,y,z: SREAL; VAR th,ph,d: SREAL);
BEGIN
	d := Math.sqrt((cx-x)*(cx-x) + (cy-y)*(cy-y) + (cz-z)*(cz-z));
	th := 6.28*srMath.sin((x-cx)/d);
	ph :=  6.28*srMath.cos((y-cy)/d);
END ctop;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	x,y,z, th,ph,r2, radius, r,g,b: SREAL;
	ax, ay, az, bx, by, bz : SREAL;
	i: INTEGER;
	p: Raster.Pixel;
	X,Y: SIZE;
BEGIN
	IF img#NIL THEN
		ax := ray.lxyz.x; ay := ray.lxyz.y; az := ray.lxyz.z;
		bx := ray.lxyz.x + ray.dxyz.x; by := ray.lxyz.y+ ray.dxyz.y; bz := ray.lxyz.z+ ray.dxyz.z;
		x := (ax+bx)/2; y := (ay+by)/2; z := (az + bz)/2;
		FOR i := 0 TO 12 DO
			r2 := (cx-x)*(cx-x) + (cy-y)*(cy-y) + (cz-z)*(cz-z);
			IF r2 < D2 THEN
				bx := x; by := y; bz := z
			ELSE
				ax := x; ay := y; az := z
			END;
			x := (ax+bx)/2; y := (ay+by)/2; z := (az + bz)/2;
		END;
		IF (r2-D2) < 0.01 THEN
			ctop(x,y,z, th, ph, radius);
			X := (ENTIER(th * 100)) MOD W;
			Y := (ENTIER(ph * 100)) MOD H;
			Raster.Get(img, X, Y, p,copy);
			r := ORD(p[2])/255; g := ORD(p[1])/255; b := ORD(p[0])/255;
			ray.r := ray.r + r*ray.a;
			ray.g := ray.g + g*ray.a;
			ray.b := ray.b + b *ray.a;
			ray.a := 0;
		END
	END;
END Shade;

END TexSph;

VAR
	rand: Random.Generator;

PROCEDURE mirror(VAR ray: Ray);
BEGIN
	CASE ray.face OF
		1: 	 ray.dxyz.x:= -ray.dxyz.x;
		|2:	ray.dxyz.y:= -ray.dxyz.y;
		|3:	ray.dxyz.z:= -ray.dxyz.z;
		|4: 	ray.dxyz.x:= -ray.dxyz.x;
		|5:	ray.dxyz.y:= -ray.dxyz.y;
		|6:	ray.dxyz.z:= -ray.dxyz.z;
	ELSE
	END;
	ray.changed := TRUE;
END mirror;


BEGIN
	rand:=srBase.rand;
END srTexVox.
