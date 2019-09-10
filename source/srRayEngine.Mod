MODULE srRayEngine;
IMPORT srBase, Raster, Objects;

CONST
	X=srBase.TILESIZE;
	LX=srBase.LTILESIZE;

TYPE Tile=OBJECT
VAR
	G,H,I,J,i,j: SIGNED16;
	GO: BOOLEAN;
	large: BOOLEAN;

PROCEDURE & init*(i,j,g,h: SIGNED16; l: BOOLEAN);
BEGIN
	I:=i; J:=j; G:=g; H:=h; large:=l;
END init;

PROCEDURE go;
BEGIN{EXCLUSIVE}
     GO:=TRUE;
END go;

PROCEDURE slow;
BEGIN
	FOR i := G TO G+X-1 DO
		FOR j := H TO H+X-1 DO
			block.Shade(srBase.rays[i,j]);
			srBase.image[i,j].red := srBase.rays[i,j].r;
			srBase.image[i,j].green := srBase.rays[i,j].g;
			srBase.image[i,j].blue := srBase.rays[i,j].b;
			srBase.clampColor(srBase.image[i,j]);
		END
	END
END slow;

PROCEDURE lslow;
BEGIN
	FOR i := G TO G+LX-1 DO
		FOR j := H TO H+LX-1 DO
			block.Shade(srBase.lrays[i,j]);
			srBase.limage[i,j].red := srBase.lrays[i,j].r;
			srBase.limage[i,j].green := srBase.lrays[i,j].g;
			srBase.limage[i,j].blue := srBase.lrays[i,j].b;
			srBase.limage[i,j].alpha := srBase.lrays[i,j].ra;
			srBase.clampColor(srBase.limage[i,j]);
		END
	END
END lslow;

PROCEDURE lfast;
BEGIN
	FOR i := G TO G+LX-1 BY 2 DO
		FOR j := H TO H+LX-1 BY 2 DO
			block.Shade(srBase.lrays[i,j]);
			srBase.limage[i,j].red := srBase.lrays[i,j].r;
			srBase.limage[i,j].green := srBase.lrays[i,j].g;
			srBase.limage[i,j].blue := srBase.lrays[i,j].b;
			srBase.clampColor(srBase.limage[i,j]);
		END
	END
END lfast;

BEGIN{ACTIVE, PRIORITY(Objects.Normal)}
	REPEAT
		BEGIN{EXCLUSIVE}
			AWAIT(GO);
			GO:=FALSE;
			incTD;
		END;
		IF large THEN
			IF ~fast THEN lslow ELSE lfast END
			ELSE slow END;
	UNTIL FALSE;
END Tile;

VAR
	block: srBase.Voxel;
	image: Raster.Image;
	tiles, ltiles: ARRAY srBase.TILEi, srBase.TILEj OF Tile;
	i,j,G,H,LG,LH: SIGNED16;
	tilesdone:SIGNED16;
	mode: Raster.Mode;
	fast*: BOOLEAN;

PROCEDURE incTD;
BEGIN{EXCLUSIVE}
	INC(tilesdone);
END incTD;

PROCEDURE zeroTD;
BEGIN{EXCLUSIVE}
	tilesdone:=0;
END zeroTD;

PROCEDURE goyethreads;
VAR
	i,j: SIGNED16;
BEGIN{EXCLUSIVE}
	FOR i:= 0 TO srBase.TILEi-1  DO
		FOR j:= 0 TO srBase.TILEj-1 DO
			tiles[i,j].go;
		END
	END
END goyethreads;

PROCEDURE lgoyethreads;
VAR
	i,j: SIGNED16;
BEGIN{EXCLUSIVE}
	FOR i:= 0 TO srBase.TILEi-1  DO
		FOR j:= 0 TO srBase.TILEj-1 DO
			ltiles[i,j].go;
		END
	END
END lgoyethreads;

PROCEDURE setBlock*(b:srBase.Voxel);
BEGIN
	block := b;
END setBlock;

PROCEDURE setImage*(img: Raster.Image);
BEGIN
	image:=img
END setImage;


PROCEDURE go*;
BEGIN
	zeroTD;
	goyethreads;
	BEGIN{EXCLUSIVE}
		AWAIT(tilesdone=srBase.TILES)
	END
END go;

PROCEDURE lgo*;
BEGIN
	zeroTD;
	lgoyethreads;
	BEGIN{EXCLUSIVE}
		AWAIT(tilesdone=srBase.TILES)
	END
END lgo;

BEGIN
	FOR i:= 0 TO srBase.TILEi-1  DO
		G:=i*srBase.TILESIZE;
		LG:=i*srBase.LTILESIZE;
		FOR j:= 0 TO srBase.TILEj-1 DO
			H:=j*srBase.TILESIZE;
			LH:=j*srBase.LTILESIZE;
			NEW(tiles[i,j],i,j,G,H,FALSE);
			NEW(ltiles[i,j],i,j,LG,LH,TRUE);
		END
	END;
	Raster.InitMode(mode, Raster.srcCopy)
END srRayEngine.