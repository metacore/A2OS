MODULE srThermoCell;
IMPORT srMath, srBase, Random, srM5Space, srM3Space, srVoxel, srVoxel4, srVoxel5;

CONST N=10;

TYPE atom=RECORD
	position, velocity: srBase.PT;
END;

TYPE cosm=OBJECT(srBase.Voxel);
VAR
	state: ARRAY N OF atom;
	space: srM5Space.cell;
	v: srBase.Voxel;
PROCEDURE & init*;
BEGIN
	NEW(space)
END init;
PROCEDURE setatomvox*(voxel: srBase.Voxel);
BEGIN
	v:=voxel
END setatomvox;
PROCEDURE bang;
VAR i:SIGNED16;
BEGIN
	NEW(space);
	FOR i:=0 TO N-1 DO
		randpos(state[i].position);
		randvel(state[i].velocity);
	END
END bang;
PROCEDURE tick*;
VAR i: SIGNED32;
BEGIN
	NEW(space);
	FOR i:=0 TO N-1 DO
(*		plus(state[i].position,state[i].velocity); *)

		IF  (state[i].position.x < 0.1)  THEN
			state[i].position.x:= 0.1;
			state[i].velocity.x := -state[i].velocity.x;
		ELSIF  (state[i].position.x > 0.9)  THEN
			state[i].position.x:= 0.9;
			state[i].velocity.x:= -state[i].velocity.x;
		END;
		IF  (state[i].position.y < 0.1)  THEN
			state[i].position.y:= 0.1;
			state[i].velocity.y := -state[i].velocity.y;
		ELSIF  (state[i].position.y > 0.9)  THEN
			state[i].position.y:= 0.9;
			state[i].velocity.y:= -state[i].velocity.y;
		END;
		IF  (state[i].position.z < 0.1)  THEN
			state[i].position.z:= 0.1;
			state[i].velocity.z := -state[i].velocity.z;
		ELSIF  (state[i].position.z > 0.9)  THEN
			state[i].position.z:= 0.9;
			state[i].velocity.z:= -state[i].velocity.z;
		END;
		space.strokevoxel(state[i].position,2,v);
	END;
END tick;
PROCEDURE Shade*(VAR ray: srBase.Ray);
BEGIN
	space.Shade(ray);
END Shade;
END cosm;

TYPE spectrum=OBJECT(srBase.Voxel);
VAR
	space: srM3Space.cell;
	v: srVoxel.DiffuseVox;
	frame: SIGNED32;

PROCEDURE & init*;
BEGIN
	NEW(space);
	NEW(v);
	v.SetColor(1/2,1/2,0);
	passable:=TRUE
END init;

PROCEDURE tick*;
VAR
     p: srBase.PT;
BEGIN
	INC(frame);
	IF frame>100 THEN
		NEW(space);
		frame:=0
	END;
	srBase.setPT(p,1/2,1/2,frame/200);
	space.strokevoxel(p,3,v)
END tick;


END spectrum;

VAR
	rand: Random.Generator;
	cosmos*: cosm;
	spec*:spectrum;
	SPHERE:  srVoxel4. SphereInVox;
	sphere: srVoxel. DiffuseSphVox;
	MSPHERE: srVoxel4.MirrorSphereInVox;
	D,E,F: srVoxel.TransparaVox;
	SWEX: srVoxel5.SwastiVox;

PROCEDURE randpos*(VAR pt:srBase.PT);
VAR
	r: FLOAT32;
BEGIN
	r:= 6.2834*rand.Uniform();
	pt.x := 1/2 + srMath.cos(r)/23;
	pt.y := 1/2 + srMath.sin(r)/23;
	pt.z := 1/2;
(*	pt.x := 1;
	pt.y := 8/18 + rand.Uniform()/9;
	pt.z := 8/18 + rand.Uniform()/9 ;*)
END randpos;

PROCEDURE randvel*(VAR pt:srBase.PT);
BEGIN
	pt.x := 0;
	pt.y := 0;
	pt.z := 0;
END randvel;

BEGIN
	NEW(rand);
	NEW(cosmos);
	NEW(spec);
	cosmos.register;
	cosmos.passable := TRUE;
	NEW(SWEX);
	SWEX.SetSwastiColor(0,0,1);
	SWEX.SetBackColor(1/3,1,1/3);
	NEW(sphere);
	sphere.SetColor(1,1,1);
	NEW(SPHERE, SWEX);
	SPHERE.setSize(1/2);
	NEW(MSPHERE);
	NEW(D); NEW(E); NEW(F);
	D.SetColor(0,0,1,3);
	E.SetColor(0,1,1,3);
	F.SetColor(1,1,0,3);
	cosmos.setatomvox(SPHERE);
	cosmos.bang;
END srThermoCell.