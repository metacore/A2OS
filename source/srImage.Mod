MODULE srImage;
IMPORT  srBase;

CONST W=srBase.W;
CONST H=srBase.H;
TYPE SREAL=srBase.SREAL;
TYPE Image= srBase.IMAGE;

PROCEDURE filterbilinear*(VAR img:  Image);
VAR
	i,j:SIGNED32;
	lr,lg,lb,r,g,b: SREAL;
BEGIN
	FOR i:= 0 TO W-1 DO
		lr:= img[i,0].red; lg:= img[i,0].green; lb:= img[i,0].blue;
		FOR j:= 1 TO H-1 DO
			r:= (img[i,j].red+lr)/2; g:= (img[i,j].green+lg)/2; b:= (img[i,j].blue+lb)/2;
			lr:= img[i,j].red; lg:= img[i,j].green; lb:= img[i,j].blue;
			img[i,j].red:=r; img[i,j].green:=g; img[i,j].blue:=b
		END
	END;
	FOR j:= 0 TO H-1 DO
		lr:=img[i,0].red; lg:= img[i,0].green; lb:= img[i,0].blue;
		FOR i:= 1 TO W-1 DO
			r:= (img[i,j].red+lr)/2; g:= (img[i,j].green+lg)/2; b:= (img[i,j].blue+lb)/2;
			lr:= img[i,j].red; lg:= img[i,j].green; lb:= img[i,j].blue;
			img[i,j].red:=r; img[i,j].green:=g; img[i,j].blue:=b
		END
	END;
END filterbilinear;

END srImage.
