MODULE srvoxels;
IMPORT srBase , srVoxel, srVoxel2, srVoxel3, srVoxel4,  srVoxel5, srLifeVox, srTexVox,
	Random,  Objects, srMath, MSpace:=srM2Space, sr3DTexture, srTree, srRotaVox;

TYPE Voxel=srBase.Voxel;
TYPE PT=srBase.PT;
TYPE COLOR=srBase.COLOR;

VAR
	block*: srBase.Voxel;

TYPE SREAL=srBase.SREAL;

TYPE marshrunner=OBJECT(srBase.V);
VAR
	i,j,k,ii,jj,kk,iii,jjj,kkk,t: SIGNED16;
	cost: SREAL;
	p,q,qq: srBase.PT;
	corridor, pillar,sky,cage,building,FLOWER, CRIMSONFLOWER, DAISY, BLOOM: MSpace.cell;
	five: MSpace.cell;
	six,sixsix, sixsixsix: MSpace.cell;
	world, mesh: srVoxel2.Bloc10;
	b3, b33: srVoxel2.Bloc3;
	r,g,b: srBase.COLOR;
	red,blue,green: SREAL;
	EARTH, SKY: srVoxel.DiffuseVox;
	serp: srVoxel3.SlantBloc;
	rand: Random.Generator;
	EMPTY: srBase.Voxel;
	cell:MSpace.cell;
	X, Y: MSpace.cell;
	neomarsh:  MSpace.cell;
	b5, b55: srVoxel2.Bloc5;
	blok: ARRAY 10 OF srVoxel2.Bloc10;
	b10,tile1, tile2, tile3, tile4: srVoxel2.Bloc10;
	whitegreenmirror: srVoxel2.Bloc10;
	WHITE: srVoxel.DiffuseVox;
	BLUE, RED: srVoxel.DiffuseVox;
	PINK, GREEN: srVoxel.DiffuseVox;
	GREY, BROWN, PURPLE, YELLOW: srVoxel.DiffuseVox;
	POLKA1, POLKA2: srVoxel.PolkaVox;
	NIGHT, TGREEN, TYELLOW, TBROWN, TORANGE, E: srVoxel.RainbowVox;
	TBLACK: srVoxel.TransparaVox;
	RDRED, RDBLUE: srVoxel.TransparaVox;
	RDYELLOW: srVoxel.TransparaVox;
	LW, LG: srVoxel.TransparaVox;
	TRED, TPURPLE: srVoxel.TransparaVox;
	TBLUE, TWHITE: srVoxel.TransparaVox;
	SERP: ARRAY 10 OF srVoxel3.Serp;
	MSPHERE: srVoxel4.MirrorSphereInVox;
	SPHERE: ARRAY 10 OF srVoxel4.SphereInVox;
	ELLIPS: srVoxel4.Ellipsoid;
	HYPE:srVoxel4.Hyperboloid;
	sphere, sphere2: srVoxel. DiffuseSphVox;
	LIFE: srLifeVox.RDVox;
	MCUBE: srVoxel.DiffuseMVox;
	MPURPLE, MGREEN: srVoxel.ColoredMVox;
	HEX: srVoxel.HexaVox;
	HEX0: srVoxel.HexaVox;
	TOWER: srVoxel3.Tower;
	TEX, STORMFRONT, APO: srTexVox.TexVox;
	RPNF, TENTACLE, ATENEY, STARSTIKA, EUROPIA,CAPTION: srTexVox.TexVox;
	BITEX: srVoxel.BiVox;
	GONSWITCH, GOFFSWITCH: srVoxel.BiVox;
	GRID: srVoxel.GridVox;
	CHEX, SWEX: srVoxel5.SwastiVox;
	vege: srVoxel3.VegeBloc;
	SPH5: srVoxel2.Bloc5;
	SLANT: srVoxel3.SlantBloc;
	cosmos, megacosmos: srVoxel2.Bloc10;
	FIVE, FIVE1,FIVE2,FIVECOSM,AXES,AX2: MSpace.cell;
	SIX: MSpace.cell;
	RPNF5, PINE, TRIGROLLARD, DANGER: sr3DTexture.image3D2;
	tree: srTree.tree;
	azure,crimson,yellow: srBase.COLOR;cp: srBase.PT;
	avatar: ARRAY 10 OF srBase.Voxel;
	av: SIGNED32;
	rota: srRotaVox.RVox;
	mrmkitty: ARRAY 77 OF srTexVox.TexVox;
	title: srBase.Name;
	frame: ARRAY 8 OF CHAR;

PROCEDURE& init*;
BEGIN
	rand:=srBase.rand;
	NEW(EMPTY);
(*	Strings.Append(title,"mrmkitty0000");
	FOR i:=0 TO 76 DO
		Strings.IntToStr(i,frame);
		Strings.Append(title,frame);
		Strings.Append(title,".jpg  ");
		NEW(mrmkitty[i],title);
	END; *)
	NEW(MCUBE);
	NEW(MGREEN);
	MGREEN.SetColor(0,1/2,0,1/2);
	NEW(CHEX);
	CHEX.SetSwastiColor(0,0,0);
	CHEX.SetBackColor(1,1/3,1/3);
	NEW(SWEX);
	SWEX.SetSwastiColor(0,0,1);
	SWEX.SetBackColor(1/3,1,1/3);
	FOR i := 0 TO 9 DO NEW(blok[i]) END;
	NEW(b3);
	NEW(b33);
	NEW(b5);
	NEW(b55);
	NEW(b10); NEW(tile1); NEW(tile2); NEW(tile3);
	NEW(BLUE); NEW(GREEN); NEW(YELLOW); NEW(BROWN); NEW(RED); NEW(PURPLE);
	BLUE.SetColor(0,0,1); 	GREEN.SetColor(0,5/10,0); 	YELLOW.SetColor(1,1,0);
	BROWN.SetColor(2/3,2/3,0); 	RED.SetColor(1,0,0); 	PURPLE.SetColor(1,0,1/3);
	NEW(GREY);
	GREY.SetColor(5/6, 5/6, 5/6);
	NEW(WHITE); WHITE.SetColor(0.9,0.9,0.9);
	NEW(PINK); PINK.SetColor(1.1,1,1);
	NEW(TWHITE); 	TWHITE.SetColor(5,5,5,0);
	NEW(TBLUE); TBLUE.SetColor(0,0,3,1);
	NEW(TORANGE); TORANGE.SetColor(5,5,2,1/2);
	NEW(TGREEN); TGREEN.SetColor(0,3,0,5);
	NEW(TRED); TRED.SetColor(3,0.1,0.1, 1/5);
	NEW(TPURPLE); TPURPLE.SetColor(2,0,2,1);
	NEW(TYELLOW); TYELLOW.SetColor(1,1,0,2);
	NEW(TBROWN); TBROWN.SetColor(2/3,2/3,0,10);
	NEW(TPURPLE); TPURPLE.SetColor(1,0,1,1/3);
	NEW(TBLACK);
	TBLACK.SetColor(0,0,0,3);
	NEW(NIGHT);
	NIGHT.SetColor(1/3,1/3,1/3,0);
	NIGHT.passable:=TRUE;
	NEW(MCUBE);
	NEW(HEX);
	HEX.setVox(EMPTY);
	HEX.passable:=TRUE;
	NEW(HEX0);
	HEX0.setVox(BLUE);
	NEW(TEX,"Sarah and Octopussmall.jpg");
	TEX.transparent := FALSE;

	NEW(STORMFRONT, "diversity.gif");
	NEW(APO,"diversity.jpeg");
	NEW(BITEX);
	BITEX.set(TEX,WHITE);
	NEW(HYPE,HEX);
	HYPE.passable:=FALSE;
	NEW(RDRED); RDRED.SetColor(1,0,0,1);
	NEW(RDBLUE); RDBLUE.SetColor(0,0,1,1);
	NEW(RDYELLOW); RDYELLOW.SetColor(1/2,1/2,1/15,1);
	NEW(LW); LW.SetColor(1,1,1,1/2);
	NEW(LG); LG.SetColor(0,0,1,1/2);

	NEW(SPHERE[0], WHITE);
	SPHERE[0].setSize(5/8);
	SPHERE[0].set2(RED);
	SPHERE[0].setCenter(0.5, 0.5, 0.5);

	NEW(sphere);
	sphere.SetColor(1,1,0);
	NEW(SPHERE[1], sphere);
	SPHERE[1].setSize(3);
	SPHERE[0].setCenter(-2.5, 0.5, 0.5);

	NEW(sphere);
	sphere.SetColor(1,0,1);
	NEW(SPHERE[2], sphere);
	SPHERE[2].setSize(1/4);

	NEW(sphere);
	sphere.SetColor(1,0,1);
	NEW(SPHERE[3], sphere);
	SPHERE[3].setSize(3/4);

	NEW(sphere);
	sphere.SetColor(1,0,0);
	NEW(SPHERE[4], GREEN);
	SPHERE[4].set2(sphere);
	SPHERE[4].setSize(3/4);

	NEW(sphere);
	sphere.SetColor(0,1,1/4);
	NEW(SPHERE[5], sphere);
	SPHERE[5].setSize(5/8);

	NEW(MSPHERE);
	NEW(SPHERE[6], RED);
	SPHERE[6].setSize(9/16);

	NEW(sphere);
	sphere.SetColor(1,1/3,1);
	NEW(SPHERE[7], sphere);
	SPHERE[7].setSize(1/2);

	NEW(sphere);
	sphere.SetColor(1,1,0);
	NEW(SPHERE[8], sphere);
	SPHERE[8].setSize(1/2);


	NEW(SERP[0],  GREY, TWHITE);
	NEW(SERP[1], SPHERE[5], EMPTY);

	NEW(SERP[2],  RED, EMPTY);
	NEW(SERP[3],  RED ,BLUE);
	NEW(SERP[4],  HEX, NIL);

	NEW(MPURPLE);
	MPURPLE.SetColor(0,0,1,1/2);
	NEW(MGREEN);
	MGREEN.SetColor(1/2, 1, 1/2, 1/2);
	NEW(MSPHERE);
	MSPHERE.passable := FALSE;
	srBase.setCOLOR(r,1,0,0);
	srBase.setCOLOR(g,0,1,0);
	srBase.setCOLOR(b,0,0,1);
	NEW(neomarsh);
	TORANGE.passable:=TRUE;
	TBLUE.passable:=TRUE;
	p.x := 1/2; p.y := 1/2; p.z := 1/2;
	NEW(FLOWER);
	NEW(CRIMSONFLOWER);
	NEW(DAISY);
	NEW(BLOOM);
	srBase.setCOLOR(azure,2/3,2/3,2/3);
	srBase.setCOLOR(crimson,1/3,1/3,1/3);
	srBase.setCOLOR(yellow,1,1,0);
	FOR i:=0 TO 13000 DO
		srBase.randnormPT(q);
		qq:=q;
		q.x :=1/2 + q.x/2;
		q.y := 1/2 + q.y/2;
		q.z := 1/2 + q.z/2;
		FLOWER.stroke(q,5,qq,azure,FALSE);
		CRIMSONFLOWER.stroke(q,5,qq,crimson,FALSE);
	END;
	FOR i:=0 TO 1390 DO
		srBase.randnormPT(q);
		qq:=q;
		q.x :=1/2 + q.x/3;
		q.y := 1/2+ q.y/3;
		q.z := 1/2 + q.z/3;
		DAISY.stroke(q,5,qq,yellow,FALSE);
	END;
	FOR i:=0 TO 330 DO
		srBase.randnormPT(q);
		qq:=q;
		q.x :=rand.Uniform();
		q.y := rand.Uniform();
		q.z := rand.Uniform();
		IF ODD(i) THEN BLOOM.strokevoxel(q,5,FLOWER) ELSE BLOOM.strokevoxel(q,5,CRIMSONFLOWER) END
	END;
	NEW(LIFE);
	NEW(five);
	NEW(six);
	NEW(sixsix);
	NEW(sixsixsix);
	sixsixsix.SetColor(1/7,1/7,0,0);
	NEW(world);
	world.SetColor(0,0,1/2,0);
	NEW(serp,SPHERE[5],SPHERE[2]);
	NEW(building);
	srBase.setPT(p,1/2,1/2,0);

	NEW(AXES);
	NEW(AX2);
	AXES.SetColor(1/4,0,1/4,1/4);
	AX2.SetColor(0,1/4,0,1/4);
	srBase.setPT(p,1/2,1/2,0);
	srBase.setPT(q,1/2,1/2,1);
	AXES.linevoxel(p,q,5,BLOOM);
	AX2.linevoxel(p,q,5,FLOWER);

	srBase.setPT(p,1/2,0,1/2);
	srBase.setPT(q,1/2,1,1/2);
	AXES.linevoxel(p,q,5,RED);
	AX2.linevoxel(p,q,5,CRIMSONFLOWER);

	srBase.setPT(p,0,1/2,1/2);
	srBase.setPT(q,1,1/2,1/2);
	AXES.linevoxel(p,q,5,PURPLE);
	AX2.linevoxel(p,q,5,BLOOM);

	AXES.passable:=TRUE;
	AX2.passable:=TRUE;

	NEW(mesh);

	mesh.fill(BLOOM);
	six.fillchequer(mesh,DAISY);
	sixsix.fillchequer(EMPTY,six);
	sixsixsix.fillchequer(sixsix,EMPTY);
	five.passable:=TRUE;
	six.passable:=TRUE;	sixsix.passable:=TRUE;	sixsixsix.passable:=TRUE;

	b10.SetColor(0,0,1,0);
	b10.blox[3,3,8]:=MSPHERE;
	MSPHERE.passable:=TRUE;
	b10.blox[3,7,8]:=SERP[3];
	b10.SetColor(0,0,0,0);
(*	NEW(rota,mesh,0.01); *)
	cp.x:=0; cp.y:=0; cp.z:=0;
	FOR i:=0 TO 4 DO FOR j:=0 TO 4 DO FOR k:=0 TO 4 DO
		t:=0;
		IF i=2 THEN INC(t) END;
		IF j=2 THEN INC(t) END;
		IF k=2 THEN INC(t) END;
		IF t<2 THEN b5.blox[i,j,k]:=WHITE ELSE b5.blox[i,j,k]:=TPURPLE END
	END END END;
	FOR i:=0 TO 4 DO FOR j:=0 TO 4 DO FOR k:=0 TO 4 DO
		t:=0;
		IF i=2 THEN INC(t) END;
		IF j=2 THEN INC(t) END;
		IF k=2 THEN INC(t) END;
		IF t<2 THEN b55.blox[i,j,k]:=b5 ELSE b55.blox[i,j,k]:=NIGHT END
	END END END;
	FOR i:=0 TO 2 DO FOR j:=0 TO 2 DO FOR k:=0 TO 2 DO
		t:=0;
		IF i=1 THEN INC(t) END;
		IF j=1 THEN INC(t) END;
		IF k=1 THEN INC(t) END;
		IF t<2 THEN b3.blox[i,j,k]:=b3 ELSE b3.blox[i,j,k]:=NIL END
	END END END;
		FOR i:=0 TO 2 DO FOR j:=0 TO 2 DO FOR k:=0 TO 2 DO
		t:=0;
		IF i=1 THEN INC(t) END;
		IF j=1 THEN INC(t) END;
		IF k=1 THEN INC(t) END;
		IF t<2 THEN b33.blox[i,j,k]:=b3 ELSE b33.blox[i,j,k]:=NIL END
	END END END;
	WHITE.passable:=FALSE;
	b3.passable:=TRUE;
	b33.passable:=TRUE;
	b5.passable:=TRUE;
	NEW(cage);
	NEW(SLANT,cage,NIL);
	NEW(SERP[0], WHITE,AXES);
	SLANT.register;

	FOR i:=1 TO 7 DO FOR j:=1 TO 7 DO FOR k:=1 TO 7 DO
		IF (i<2)OR(i>5)OR(j<2)OR(j>5)OR(k<2)OR(k>5)THEN
			srBase.setPT(p,i/8,j/8,k/8);
		NEW(b55);
		NEW(corridor);
		corridor.SetColor(0,0,0,0);
		NEW(WHITE);
		NEW(RED);
		WHITE.SetColor(1-rand.Uniform()/10,1-rand.Uniform()/10,1- rand.Uniform()/10);
		RED.SetColor(1-rand.Uniform()/10,1-rand.Uniform()/10, 1-rand.Uniform()/10);
		FOR ii:=0 TO 4 DO FOR jj:=0 TO 4 DO FOR kk:=0 TO 4 DO
			t:=0;
			IF ii=2 THEN INC(t) END;
			IF jj=2 THEN INC(t) END;
			IF kk=2 THEN INC(t) END;
			IF t<2 THEN
				NEW(b5);
				FOR iii:=0 TO 4 DO FOR jjj:=0 TO 4 DO FOR kkk:=0 TO 4 DO
					t:=0;
					IF iii=2 THEN INC(t) END;
					IF jjj=2 THEN INC(t) END;
					IF kkk=2 THEN INC(t) END;
					IF t=3 THEN  b5.blox[iii,jjj,kkk]:=AX2
					ELSIF ODD(iii+jjj+kkk) THEN b5.blox[iii,jjj,kkk]:=WHITE ELSE b5.blox[iii,jjj,kkk]:=RED
					END;
				END END END;
				b55.blox[ii,jj,kk]:=b5;
			ELSE b55.blox[ii,jj,kk]:=AX2 END
		END END END;
		b10.blox[i,j,k]:=b55;
		cage.strokevoxel(p,3,b55);
		END
	END END END;


	srBase.setPT(p,1/2,1/2,1/2);
	cage.strokevoxel(p,3,SERP[0]);
	srBase.world:=cage;
END init;

PROCEDURE cylinder(target: MSpace.cell; start, end: PT;  radius: FLOAT32; t:SIGNED16; color:COLOR);
VAR
	i: SIGNED16;
	sin,cos: FLOAT32;
	p,q,normal: PT;
BEGIN
	FOR i:= 0 TO t DO
		normal.x:=srMath.sin(6.2832*i/t);
		normal.y:=srMath.cos(6.2832*i/t);
		normal.z:=0;
		sin:=radius*normal.x;
		cos:=radius*normal.y;
		p.x:= start.x+sin;
		p.y:= start.y+cos;
		p.z:=start.z;
		q.x:= end.x+sin;
		q.y:= end.y+cos;
		q.z:= end.z;
	(*	target.nline(p,q,8,normal,color,FALSE); *)
		target.linevoxel(p,q,11,WHITE);
	END
END cylinder;

PROCEDURE cameratrail(v: Voxel; a,b: PT);
BEGIN
	IF v#NIL THEN v.linevoxel(a,b,12,DAISY) END
END cameratrail;

PROCEDURE tick*;
BEGIN
(*	FOR i:=0 TO 10 DO
		srBase.randPT(p);
		cage.strokevoxel(p,4,FLOWER);
	END;
	FOR i:=0 TO 10 DO
		srBase.randPT(p);
		cage.strokevoxel(p,4,CRIMSONFLOWER);
	END;	*)
	SLANT.tick;
END tick;

PROCEDURE fill5cosm;
VAR
	i, j: SIGNED32;
	theta, phi: SREAL;
	a: srBase.PT;
	sky:srBase.COLOR;
BEGIN
	NEW(FIVECOSM);
	sky.red := 1/3;
	sky.green := 1/3;
	sky.blue := 1;
(*	FIVECOSM.SetColor(1,1,0,0); *)
	FOR i := 0 TO 100 DO
		theta:=i*6.2832/100;
		FOR j := 0 TO 100 DO
			phi:=j*3.14159/100;
			a.x:=1/2 +srMath.cos(theta)*srMath.sin(phi)/12;
			a.y:=1/2 +srMath.sin(theta)*srMath.sin(phi)/12;
			a.z:= 1/2+srMath.cos(phi)/12;
			FIVECOSM.strokevoxel(a, 3, megacosmos);
		END
	END;
END fill5cosm;

PROCEDURE fillcell;
VAR
	i, j: SIGNED32;
	theta, phi: SREAL;
	a,normal: srBase.PT;
	reddishgray:srBase.COLOR;
BEGIN
	NEW(cell);
	reddishgray.red:=1;
	reddishgray.green:=1;
	reddishgray.blue:=1;
	FOR i := 0 TO 100 DO
		theta:=i*6.2832/100;
		FOR j := 0 TO 100 DO
			phi:=j*6.2832/100;
			a.x:=1/2 +srMath.cos(theta)*srMath.sin(phi)/9;
			a.y:=1/2 +srMath.sin(theta)*srMath.sin(phi)/9;
			a.z:=1/2 + srMath.cos(phi)/9;
			normal:=srMath.norm(theta,phi);
			cell.stroke(a, 3,normal,reddishgray,FALSE);

		END
	END;
(*	srBase.setPT(a,1/2,1/2,1/2);
	cell.strokevoxel(a, 2,RED);
	cell.SetColor(0,0,0,1/4);
	cell.passable := TRUE; *)
END fillcell;
PROCEDURE fillX;
VAR
	i, j,k: SIGNED32;
	a,b: SREAL;
	v: ARRAY 8 OF srBase.PT;
BEGIN
	NEW(X); NEW(Y);
	X.passable:=TRUE;
	Y.passable:=TRUE;
	a:=0.1; b:=0.9;
	srBase.setPT(v[0],a,a,a);
	srBase.setPT(v[1],a,a,b);
	srBase.setPT(v[2],a,b,a);
	srBase.setPT(v[3],a,b,b);
	srBase.setPT(v[4],b,a,a);
	srBase.setPT(v[5],b,a,b);
	srBase.setPT(v[6],b,b,a);
	srBase.setPT(v[7],b,b,b);
	srBase.setPT(p,1/2,1/2,1/2);
	FOR i := 0 TO 7 DO
		FOR j := 0 TO 7 DO
			X.linevoxel(v[i],v[j],2,cell);
		END
	END;
	FOR i := 0 TO 15 DO
		srBase.randPT(p);
		X.strokevoxel(p,1,TWHITE)
	END;
	FOR i :=0 TO 8 DO
		FOR j :=0 TO 8 DO
			FOR k :=0 TO 8 DO
				srBase.setPT(p,i/25,j/25,k/25);
		 		Y.strokevoxel(p, 2, SWEX);
		 	END
		END
	END;
END fillX;


BEGIN{ACTIVE, PRIORITY(Objects.Low)}
	REPEAT
		tick;
	UNTIL  ~srBase.worldalive;
END marshrunner;

VAR
	MARSH: marshrunner;

PROCEDURE cameratrail*(v: Voxel; a,b: PT);
BEGIN
	MARSH.cameratrail(v,a,b);
END cameratrail;

PROCEDURE trailswitch*; (*remove*)
END trailswitch;

BEGIN
	NEW(MARSH);
END srvoxels.



