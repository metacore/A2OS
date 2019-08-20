MODULE sr3DTexture;
IMPORT srBase, srVoxel, srM5Space, Raster, Graphics := WMGraphics;

TYPE PT = srBase.PT;
TYPE Name = srBase.Name;
TYPE COLOR = srBase.COLOR;

TYPE image3D*= OBJECT(srM5Space.cell);
VAR
	img: Raster.Image;
	fmt: Raster.Format;
	copy : Raster.Mode;
	p: Raster.Pixel;
	W,H, bpr,adr, i, j: SIZE;
	r,g,b: REAL;
	pixel,normal: PT;
	color: COLOR;
	green: srVoxel.GoutlineVox;
PROCEDURE & new*(n: Name);
BEGIN
	NEW(green);
	green.SetColor(0,1,0);
	srBase.setPT(normal,1,0,0);
	Raster.InitMode(copy, Raster.srcCopy);
	img :=Graphics.LoadImage(n, TRUE);
	IF img#NIL THEN
		W := img.width-2; H:= img.height-2;
		FOR i := 1 TO W DO
			FOR j := 1 TO H DO
				Raster.Get(img,i,j,p,copy);
				r := ORD(p[2])/255; g := ORD(p[1])/255; b := ORD(p[0])/255;
				srBase.setPT(pixel, i/W, j/H, b);
				srBase.setCOLOR(color,r,g,b);
				stroke(pixel,3,normal,color,FALSE);
			(*	strokevoxel(pixel,3,green); *)
			END
		END
	END
END new;
END image3D;

TYPE image3D2*= OBJECT(srM5Space.cell);
VAR
	nimg, mimg: Raster.Image;
	fmt: Raster.Format;
	copy : Raster.Mode;
	p,q: Raster.Pixel;
	W,H, bpr,adr, i, j: SIZE;
	nr,ng,nb,mr,mg,mb: REAL;
	pixel,normal: PT;
	color: COLOR;
PROCEDURE & new*(n,m: Name);
BEGIN
	Raster.InitMode(copy, Raster.srcCopy);
	nimg :=Graphics.LoadImage(n, TRUE);
	mimg :=Graphics.LoadImage(m, TRUE);
	IF (nimg#NIL) & (mimg#NIL) THEN
		IF TRUE OR (nimg.width = mimg.width) & (nimg.height = mimg.height) THEN
			W := mimg.width-2; H:= mimg.height-2;
			FOR i := 1 TO W DO
				FOR j := 1 TO H DO
					Raster.Get(nimg,i,j,p,copy);
					Raster.Get(mimg,i,j,q,copy);
					nr := ORD(p[2])/255; ng := ORD(p[1])/255; nb := ORD(p[0])/255;
					mr := ORD(q[2])/255; mg := ORD(q[1])/255; mb := ORD(q[0])/255;
					srBase.setPT(pixel, i/W, j/H, mb/50);
					srBase.setCOLOR(color,nr,ng,nb);
					stroke(pixel,3,normal,color,FALSE);
				END
			END
		END
	END
END new;
END image3D2;

END sr3DTexture.
