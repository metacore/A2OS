MODULE Rubik; (** AUTHOR "Patrick Hunziker 2016"; PURPOSE "Rubik's cube interactive model"; *)

(* 'homogenous coordinates' (4-point, 4-vector, 4x4 matrix) are used for simplified computation of rotations and translations of geometric object *)

IMPORT Commands, VolumeRaytracer, WM:=WMWindowManager, Random, Colors;

CONST 
	(* Sequence of colors: 1. Rot, 2. Green, 3. Blue, 4. Orange , 5. Yellow , 6. White *)
	
	Identity=[[1.0,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]];
	
	RotX90*=[
	[1.0,0,0,0],
	[0,0,-1,0],
	[0,1,0,0],
	[0,0,0,1]
	];
	
	RotX270*=[
	[1.0,0,0,0],
	[0,0,1,0],
	[0,-1,0,0],
	[0,0,0,1]
	];
	
	RotX15*=[
	[1.0,0,0,0],
	[0, 0.965925826289068, -0.258819045102521,0],
	[0, 0.258819045102521, 0.965925826289068,0],
	[0,0,0,1]
	];
	
	RotXM15*=[
	[1.0,0,0,0],
	[0, 0.965925826289068, 0.258819045102521,0],
	[0, -0.258819045102521, 0.965925826289068,0],
	[0,0,0,1]
	];
	
	RotY90*=[
	[0.0,0,1,0],
	[0,1,0,0],
	[-1,0,0,0],
	[0,0,0,1]
	];
	
	RotY270*=[
	[0.0,0,-1,0],
	[0,1,0,0],
	[1,0,0,0],
	[0,0,0,1]
	];
	
	RotY15*=[
	[0.965925826289068, 0, 0.258819045102521,0],
	[0,1,0,0],
	[-0.258819045102521, 0, 0.965925826289068,0],
	[0,0,0,1]
	];
	
	RotYM15*=[
	[0.965925826289068, 0, -0.258819045102521,0],
	[0,1,0,0],
	[0.258819045102521, 0, 0.965925826289068,0],
	[0,0,0,1]
	];
	
	RotZ90*=[
	[0.0,-1,0,0],
	[1,0,0,0],
	[0,0,1,0],
	[0,0,0,1]
	];
	
	RotZ270*=[
	[0.0,1,0,0],
	[-1,0,0,0],
	[0,0,1,0],
	[0,0,0,1]
	];
	
	RotZ15*=[
	[0.965925826289068, -0.258819045102521,0, 0],
	[0.258819045102521, 0.965925826289068,0, 0],
	[0,0,1,0],
	[0,0,0,1]
	];
	
	RotZM15*=[
	[0.965925826289068, 0.258819045102521,0, 0],
	[-0.258819045102521, 0.965925826289068,0, 0],
	[0,0,1,0],
	[0,0,0,1]
	];
	

	
(* a small block which is part of a Rubik's cube *)
TYPE BrickInfo=RECORD
	id:SIGNED32;
	minicube: VolumeRaytracer.Shape; 
END;

TYPE Datatype*=VolumeRaytracer.Datatype;

(* a Rubik's Cube *)
TYPE Cube*= OBJECT
	VAR  blocks:ARRAY [3,3,3] OF BrickInfo;
		render*: PROCEDURE{DELEGATE} ;
		animated*, delayRender*:BOOLEAN; 
		
		PROCEDURE &Init*(w:VolumeRaytracer.World);
		VAR i,j,k,id:SIGNED32;
			transform: VolumeRaytracer.AffineTransform;
		BEGIN
			id:=0;
			FOR i:=0 TO 2 DO
				FOR j:=0 TO 2 DO
					FOR k:=0 TO 2 DO
						blocks[i,j,k].id:=id; id:=id+1; (*each mini cube has a id number *)
						
						blocks[i,j,k].minicube:=NewBrick(); 
						transform:=Move([(i-1)/8, (j-1)/8, (k-1)/8, 1]);(* each Minicube has an own starting position *)
						blocks[i,j,k].minicube.Transform(transform);
						w.Add(blocks[i,j,k].minicube); (* add Minicube to raytracer world *)
					END;
				END;
			END;
		END Init;
		
		PROCEDURE RotX*(x:SIGNED32; forward:BOOLEAN);
		VAR layer, newlayer: ARRAY [3,3] OF BrickInfo; i,j,r:SIGNED32;
		BEGIN
			layer:=blocks[x,*,*];
			IF ~animated THEN (* draw only full 90 degree rotation stage*)
				FOR i:=0 TO 2 DO
					FOR j:=0 TO 2 DO (* change the transform matrices of each minicube *)
						IF forward THEN layer[i,j].minicube.Transform(RotX90); 
						ELSE layer[i,j].minicube.Transform(RotX270); 
						END;
					END;
				END;
				IF ~delayRender THEN render END;
			ELSE 
				FOR r:=0 TO 5 DO (* animation of intermediate rotation steps*)
					FOR i:=0 TO 2 DO
						FOR j:=0 TO 2 DO (* change the transform matrices of each minicube *)
							IF forward THEN layer[i,j].minicube.Transform(RotX15); 
							ELSE layer[i,j].minicube.Transform(RotXM15); 
							END;
						END;
					END;
					Cam.renderPreview:= r # 5; 
					render;
				END;
			END;
			IF forward THEN
				newlayer[2,0]:=layer[0,0]; (* each minicube of the rotated plane has now a new position in the 3x3x3 cube *)
				newlayer[1,0]:=layer[0,1];
				newlayer[0,0]:=layer[0,2];
				newlayer[2,1]:=layer[1,0];
				newlayer[1,1]:=layer[1,1];
				newlayer[0,1]:=layer[1,2];
				newlayer[2,2]:=layer[2,0];
				newlayer[1,2]:=layer[2,1];
				newlayer[0,2]:=layer[2,2];
			ELSE 
				newlayer[0,2]:=layer[0,0]; 
				newlayer[0,1]:=layer[1,0]; 
				newlayer[0,0]:=layer[2,0]; 
				newlayer[1,2]:=layer[0,1]; 
				newlayer[1,1]:=layer[1,1]; 
				newlayer[1,0]:=layer[2,1]; 
				newlayer[2,2]:=layer[0,2]; 
				newlayer[2,1]:=layer[1,2];  
				newlayer[2,0]:=layer[2,2]; 		
			END;
			
			blocks[x,*,*]:=newlayer;	
		END RotX;
		
		PROCEDURE RotY*(y:SIGNED32; forward:BOOLEAN);
		VAR layer, newlayer: ARRAY [3,3] OF BrickInfo; i,j,r:SIGNED32;
		BEGIN
			layer:=blocks[*,y,*];
			IF ~animated THEN (* draw only full 90 degree rotation stage*)
				FOR i:=0 TO 2 DO
					FOR j:=0 TO 2 DO
						IF forward THEN layer[i,j].minicube.Transform(RotY90);
						ELSE layer[i,j].minicube.Transform(RotY270);
						END;
					END;
				END;
				IF ~delayRender THEN render END;
			ELSE 
				FOR r:=0 TO 5 DO (* animation of intermediate rotation steps*)
					FOR i:=0 TO 2 DO
						FOR j:=0 TO 2 DO (* change the transform matrices of each minicube *)
							IF forward THEN layer[i,j].minicube.Transform(RotY15);
							ELSE layer[i,j].minicube.Transform(RotYM15); 
							END;
						END;
					END;
					Cam.renderPreview:= r # 5; 
					render;
				END;
			END;
			
			IF forward THEN
				newlayer[0,2]:=layer[0,0]; 
				newlayer[0,1]:=layer[1,0]; 
				newlayer[0,0]:=layer[2,0]; 
				newlayer[1,2]:=layer[0,1]; 
				newlayer[1,1]:=layer[1,1]; 
				newlayer[1,0]:=layer[2,1]; 
				newlayer[2,2]:=layer[0,2]; 
				newlayer[2,1]:=layer[1,2];  
				newlayer[2,0]:=layer[2,2]; 		
			ELSE
				newlayer[2,0]:=layer[0,0]; 
				newlayer[1,0]:=layer[0,1]; 
				newlayer[0,0]:=layer[0,2]; 
				newlayer[2,1]:=layer[1,0]; 
				newlayer[1,1]:=layer[1,1]; 
				newlayer[0,1]:=layer[1,2]; 
				newlayer[2,2]:=layer[2,0]; 
				newlayer[1,2]:=layer[2,1]; 
				newlayer[0,2]:=layer[2,2]; 
			END;
			
			blocks[*,y,*]:=newlayer;
		END RotY;
		
		PROCEDURE RotZ*(z:SIGNED32; forward:BOOLEAN);
		VAR layer, newlayer: ARRAY [3,3] OF  BrickInfo; i,j,r:SIGNED32;
		BEGIN
			layer:=blocks[*,*,z];
			IF ~animated THEN (* draw only full 90 degree rotation stage*)
				FOR i:=0 TO 2 DO
					FOR j:=0 TO 2 DO
						IF forward THEN layer[i,j].minicube.Transform(RotZ90);
						ELSE layer[i,j].minicube.Transform(RotZ270);
						END;
					END;
				END;
				IF ~delayRender THEN render END;
			ELSE 
				FOR r:=0 TO 5 DO (* animation of intermediate rotation steps*)
					FOR i:=0 TO 2 DO
						FOR j:=0 TO 2 DO (* change the transform matrices of each minicube *)
							IF forward THEN layer[i,j].minicube.Transform(RotZ15); 
							ELSE layer[i,j].minicube.Transform(RotZM15); 
							END;
						END;
					END;
					Cam.renderPreview:= r # 5; 
					render;
				END;
			END;
			IF forward THEN
				newlayer[2,0]:=layer[0,0]; 
				newlayer[1,0]:=layer[0,1]; 
				newlayer[0,0]:=layer[0,2]; 
				newlayer[2,1]:=layer[1,0]; 
				newlayer[1,1]:=layer[1,1]; 
				newlayer[0,1]:=layer[1,2]; 
				newlayer[2,2]:=layer[2,0]; 
				newlayer[1,2]:=layer[2,1]; 
				newlayer[0,2]:=layer[2,2]; 
			ELSE
				newlayer[0,2]:=layer[0,0]; 
				newlayer[0,1]:=layer[1,0]; 
				newlayer[0,0]:=layer[2,0]; 
				newlayer[1,2]:=layer[0,1]; 
				newlayer[1,1]:=layer[1,1]; 
				newlayer[1,0]:=layer[2,1]; 
				newlayer[2,2]:=layer[0,2]; 
				newlayer[2,1]:=layer[1,2];  
				newlayer[2,0]:=layer[2,2]; 		
			END;
			
			blocks[*,*,z]:=newlayer;
		END RotZ;		
		
		PROCEDURE Rot*(axis:SIGNED32; layers:SET; steps:SIGNED32);
		VAR i,l:SIGNED32;
			rot: PROCEDURE{DELEGATE}(lay:SIGNED32; forward:BOOLEAN);
		BEGIN
			ASSERT (axis IN {0,1,2});
			(*animated:=FALSE; (*not yet implemented in loop*)*)
			delayRender:=TRUE;
			FOR l:=0 TO 2 DO 
				IF l IN layers THEN 
					 IF axis=0 THEN rot:=RotX
					 ELSIF axis=1 THEN rot:=RotY
					 ELSIF axis=2 THEN rot:=RotZ
					 END;
					 FOR i:=0 TO ABS(steps)-1 DO
					 	rot(l, steps>=0);
					 END;

				END;
			END;
			delayRender:=FALSE;
		END Rot;

		PROCEDURE GetLayer*(CONST in:ARRAY[*,*] OF BrickInfo): ARRAY [3,3] OF SIGNED32;
		VAR res: ARRAY [3,3] OF SIGNED32;i,j:SIGNED32;
		BEGIN
			FOR i:=0 TO 2 DO
				FOR j:=0 TO 2 DO
					res[i,j]:=in[i,j].id;
				END;
			END;
			RETURN res
		END GetLayer;
			
	END Cube;

PROCEDURE NewBrick():VolumeRaytracer.Brick;
VAR brick: VolumeRaytracer.Brick; 
BEGIN
	NEW(brick,0.1,0.1, 0.1); (*the lowest edge is at the zero origin of the coordinate system, the high edge at 0.1,0.1,0.1*)
	brick.Transform(Move([-0.05,-0.05,-0.05,0])); (* now, the brick is centered around the origin*) 
	brick.SetColors(Colors.red,Colors.green,Colors.blue, Colors.orange, Colors.yellow, Colors.white);
	RETURN brick
END NewBrick;

(* produce a transform matrix that describes a simple translation*)
PROCEDURE Move(CONST direction: VolumeRaytracer.Vector):VolumeRaytracer.AffineTransform;
VAR t:VolumeRaytracer.AffineTransform;
BEGIN
	t:= Identity;
	t[0..2,3]:=direction[0..2];
	RETURN t
END Move;

PROCEDURE RenderDummy;
BEGIN
END RenderDummy;


PROCEDURE Create*;
VAR mirror: VolumeRaytracer.Plane; T0: VolumeRaytracer.AffineTransform;
BEGIN
		NEW(world);
		world.DefaultLight; (* create a single white light source at the default location *)
		NEW(Win, 400,400, FALSE); (* create a display window suited for user interaction *)
		
		(* Camera *)
		NEW(Cam,world); (* camera observes a world ... *)
		Cam.SetWindow(Win); (* camera puts its image into a window *)
		Cam.CreatePreview; (* rendering is first done in a coarse fashion, then in high quality *)
		Cam.ambient:=0.6; (* diffuse light is added to the lighting of the cube (otherwise, the non-illuminated surfaces would be black) *)
		T0:=Cam.T0; T0[..,3]:=[0.2,0.2,-1,1];(*initial camera position shifted from default*)
		
		(* Rubik's cube *)
		NEW(cube,world); 
		cube.animated:=TRUE;
		cube.render:=Cam.Render; (* how the cube will draw itself when it is changed *)
		
	
		(* a mirror to see the back side *)
		NEW(mirror, [0,0,1,1],[0,1,0,1],[1,0,0,1]);
		mirror.reflective:=TRUE; 
		mirror.color:=Colors.black;
		world.Add(mirror);
	
		 (* make everything visible *)
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize}); (* the 3D display window *)
		Cam.Render; (* draw the cube*)
		world.EnumerateShapes(FALSE,FALSE, VolumeRaytracer.LogShape); 
END Create;

PROCEDURE CreateRandom*;
VAR i:SIGNED32;
BEGIN
	Create;
	cube.render:=RenderDummy;
	FOR i:=0 TO 20 DO
		cube.Rot(random.Dice(2), {random.Dice(2)},1);
	END;
	cube.render:=Cam.Render;
	cube.render();
END CreateRandom;


PROCEDURE Rotate*(context:Commands.Context);
VAR axis,layer,steps:SIGNED32;
BEGIN
	IF cube=NIL THEN Create END;
	IF context.arg.GetInteger(axis,FALSE) THEN
		IF context.arg.GetInteger(layer,FALSE) THEN
			IF context.arg.GetInteger(steps,FALSE) THEN
				cube.Rot(axis,{layer},steps);
			END;
		END;
	END;
END Rotate;


PROCEDURE RotX*(context:Commands.Context);
VAR layer:SIGNED32;
BEGIN
	IF cube=NIL THEN Create END;
	IF context.arg.GetInteger(layer,FALSE) THEN
		cube.Rot(2,{layer},1);
	END;
END RotX;

PROCEDURE RotY*(context:Commands.Context);
VAR layer:SIGNED32;
BEGIN
	IF cube=NIL THEN Create END;
	IF context.arg.GetInteger(layer,FALSE) THEN
		cube.Rot(1,{layer},1);
	END;
END RotY;

PROCEDURE RotZ*(context:Commands.Context);
VAR layer:SIGNED32;
BEGIN
	IF cube=NIL THEN Create END;
	IF context.arg.GetInteger(layer,FALSE) THEN
		cube.Rot(0,{layer},1);
	END;
END RotZ;

PROCEDURE Flower*;
BEGIN
	IF cube=NIL THEN Create END;
	cube.Rot(0,{1},1);
	cube.Rot(1,{1},1);
	cube.Rot(0,{1},-1);
	cube.Rot(1,{1},-1);
END Flower;

PROCEDURE Continuous*(context:Commands.Context);
VAR i: SIZE;
BEGIN
	IF ~context.arg.GetSize(i,FALSE) THEN i:=20 END;
	IF cube=NIL THEN Create END;
	WHILE i>0 DO
		cube.Rot(random.Dice(3),{random.Dice(3)}, 2*random.Dice(2)-1);
		DEC(i)
	END;
END Continuous;

VAR 
	cube-: Cube;
	Cam-: VolumeRaytracer.Camera;
	world-:VolumeRaytracer.World; 
	Win-:VolumeRaytracer.Window; (* if you need a non-interactive window, use: Win: WM.BufferWindow *)
	random:Random.Generator;

BEGIN
	NEW(random)
END Rubik.

Rubik.Create ~
Rubik.CreateRandom ~
Rubik.Flower~
Rubik.Render ~
Rubik.RotX 0~
Rubik.RotX 2~
Rubik.RotY 0~
Rubik.RotY 2~
Rubik.RotZ 0~
Rubik.RotZ 2~
Rubik.Rotate 0 0 3 ~
Rubik.Continuous 100~
Rubik.Continuous 1000000000~

System.Free Rubik ~
System.FreeDownTo VolumeRaytracer ~

