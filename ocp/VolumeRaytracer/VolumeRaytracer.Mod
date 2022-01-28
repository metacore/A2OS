MODULE VolumeRaytracer; (** AUTHOR "Patrick Hunziker"; PURPOSE "Raytracer for 3D worlds with parameteric objects, interactive "; *)

(*
Constructs and renders 3D worlds populated by parametric 3D objects. 

Interact by mouse with objects in VolumeRaytracer.Window:
-rotate with left key-drag
-move with arrow keys
-select elements with right click
-zoom with mouse wheel.
*)


(* homogenous coordinates (4 coefficients) and transforms (4*4 matrix with [0,0,0,1] as last row) are used.
  coordinates are in the form [x,y,z,1], while vectors are in the form [dx,dy,dz,0].
  this allows handling	3D transforms including translations as 4x4 matrix multiplication.    *)

(* right-handed default coordinate system, with the following conventions:
	 x:away from camera; y: upwards; z: to the right*)

(*Mathematics of Rendering:
	a good review of spatial geometry is at
	http://local.wasp.uwa.edu.au/~pbourke/geometry/ http://local.wasp.uwa.edu.au/~pbourke/geometry/ *)
	(* see also http://www.geometrictools.com/Documentation/Documentation.html *)
	(* an overview of object intersection algorithms is given at http://www.realtimerendering.com/intersections.html*)
	(*a list of triangle collision detection methods is given here: http://realtimecollisiondetection.net/blog/?p=29
		and a code from moeller is at http://jgt.akpeters.com/papers/Moller97/tritri.html *)

	(* projective geometry including Pluecker coordinates: http://www.bealto.com/geo-projective_line1.html*)
	(* more optimizations are possible
		1) fast ArcCos()
		2) precomputing inner products of triangle.p0, triangle.dp, line.p0, line.dp, sphere.po
		3) high level optimizations:
	*)

(*Small Features may develop artifacts with the "shadowed" option, related to the value of "threshold" option in Camera.Render() . Adding "Fuzzy zero" to camera positions often helps by reducing colinear beams etc.*)

IMPORT Reals, Mathe:=Math, MathL, Random, Objects, Raster, Codecs, Files, Strings,Dates,
	WMGraphics, WM:=WMWindowManager, WMRectangles, KernelLog, Kernel, Commands, Streams, Modules, 
	V:=HomogenousVectors, Col:=Colors, CRC, SYSTEM; 
	(*to do: uncouple from module Raster for genericity*)

CONST
	pi=3.14159265358979323846264338327950288419716939937510;
	invpi=1/pi;
	
	Origin* = [0.0,0,0,1];
	XAxis* = [1.0,0,0,0];
	Zero4 = [0,0,0,0];

	Identity*=[[1.0,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]];
	FarPlus = [MAX(FLOAT32),MAX(FLOAT32),MAX(FLOAT32),1];
	FarMinus = [MIN(FLOAT32),MIN(FLOAT32),MIN(FLOAT32),1];
	
	alpha=-1; (* around z axis *)
	theta=0.6; (* around y axis *)
	(*threshold = 0.001; *)(*was 0.0001; can be 0.01 for some cases*)(* illumination detection *) (*? this constant is critical for artifacts on fine features. Does it need dynamic adaptation to structure size ?*)
	threshold0 = 0.001;
	(*thresholds=[threshold0,threshold0,threshold0,0];*)
	maxReflections=10; (* avoid infinitely travelling rays *)
	
	(*illumination*)
	Ambient* = 0;
	Diffuse* = 1;
	Specular* = 2;
	
	(* shading interpolators *)
	NoInterpolation*=0;
	GouraudInterpolation*=1; (*linear interpolation between edge intensities*)
	PhongInterpolation*=2; (* linear interpolation between edge normal vectors *)
	
	(* state machine*)
	waiting*=0;
	rendering*=1;
	dying*=-1;
	
TYPE
	Datatype*=FLOAT32;
	Complex*=COMPLEX32;

	Coordinate*=V.Vector;(* homogenous coordinates [x,y,z,1] *)
	Vector*=V.Vector; (* homogenous coordinates [dx,dy,dz,0] *)
	Map=ARRAY [*,*,*] OF FLOAT32; (*Map=ARRAY [*,*] OF Coordinate;*)
	SplinePatch=Map;
	
	Line0*= RECORD
			p0-,p1-:Coordinate; dp-:Vector;
		END;
	Ray0*= RECORD (Line0)
			Innerp0, Innerdp, InvInnerdp: Datatype;(* can add precomputed inner product of <p0,p0> and <dp,dp> for optimization.*)
			viewer*:Viewer;
			reflections*:SIGNED32; (* how many times has the ray been reflected or refracted *)
			refractiveIndex,
			sourceDistance*:Datatype; (*path travelled from root ray p0  to this ray's p0*)
		END;
	Plane0=RECORD
			p: Coordinate; (*a point on the plane*)
			normal:Vector;
		END;
	AffineTransform*=V.Transform;
	Box*= RECORD p0-,p1-,center-: Coordinate; radius:Datatype END; (* axis-aligned bounding box suited as easy-to-compute enclosing structure for any object*)
				(* may also code for enclosing sphere, but to do: find smaller  enclosing sphere for object instead of for box*)
	Color*= Col.Color; (*BGRA*)
	ColorA*= ARRAY 4 OF CHAR; (* for aliasing to other libs *)
	Finish*=ARRAY [4] OF Datatype; (*ambient, diffuse, phong, xx *)
	Hit*= POINTER TO RECORD (Line0)
			normal-:Vector;
			color-:Color;
			sourceDistance-:Datatype;
			next-:Hit;
	END;
	
	Grid*=Raster.Image; (*! to do: decouple from low level module Raster  *)

	 DynamicTransform*=PROCEDURE {DELEGATE}(CONST T0:AffineTransform; time:Datatype):AffineTransform;
	 
	 ShapeHandler*=PROCEDURE{DELEGATE}(shape:Shape);

	(** This is the fundamental object describing the "World" and all its "subworlds".
		It has a base transform, a linked list of object shapes, a number of cameras and light sources,
		and optionally, a child world hierarchy *)
	World*=OBJECT
		VAR
			T0, T*:AffineTransform;
			time*:Datatype; 
			child*: World;
			shapes*: Shape; (*linked list of shapes belonging to this World*)
			cutout*: VolumeShape;(*experimental - may be moved elsewhere*)
			cameras*: Camera;
			lights*: Light;
			hasReflectionsRefractions*:BOOLEAN;
			hasCompositeObjects*:BOOLEAN; (* this flag avoids rendering problems with composite objects, but makes rendering slower *)
			refractIndex*:Datatype;
			origin: Coordinate;

			Dynamic*: DynamicTransform;

			PROCEDURE &Init*;
			BEGIN
				T:=Identity; T0:=T;
				origin:=T[..,3];
				time:=0;
				Dynamic:=Dynamic0;
				hasReflectionsRefractions:=FALSE;
				hasCompositeObjects:=FALSE;
			END Init;

			PROCEDURE SetTime*(t:Datatype); (* world can move/change over time *) (* here, synchronicity problems with other pactive objects can arise*)
			VAR c:Camera; l:Light;
			BEGIN
				time:=t;
				T:=Dynamic(T0, time/10);
				origin:=T[..,3];
				c:=cameras; WHILE c#NIL DO c.SetTime; c:=c.next END; (* cameras can move/change in time *)
				l:=lights; WHILE l#NIL DO l.SetTime; l:=l.next END; (* lights can move/change in time *)
			END SetTime;

			PROCEDURE DefaultLight*;
			BEGIN
				NEW(lights);
				lights.world:=SELF;
				lights.Default;
			END DefaultLight;
			
			PROCEDURE EnumerateShapes*(hierarchical, selection: BOOLEAN; handle: ShapeHandler); (*hierarchical feature not yet implemented*)
			VAR s:Shape;
			BEGIN
				IF handle=NIL THEN RETURN END;
				s:=shapes;
				WHILE s#NIL DO
					IF ~selection OR s.selected THEN handle(s) END;
					s:=s.next;
				END;
			END EnumerateShapes;
			
			PROCEDURE Add*(Object:ANY); (* add shape/list of shapes/lights; accepts linked lists of shapes, not yet of lights; DOES NOT currently propagate world field etc to nrcz childr level*)
			VAR s:Shape;
			BEGIN (*! to be done: handle case when a shape is erroneously repeatedly added*)
				IF Object IS Shape THEN
					WITH Object: Shape DO 
						s:=Object;
						LOOP
							s.world:=SELF;
							IF s.next=NIL THEN s.next:=shapes; shapes:=Object; EXIT END;
							s:=s.next;
						END;
					END; (* prepend to list *)
				ELSIF Object IS Light THEN
					WITH Object: Light DO Object.next:=lights; lights:=Object; lights.world:=SELF END;
				END;
			END Add;
			
			PROCEDURE AddCutout*(shape:VolumeShape); (* add shape/list of shapes; accepts linked lists of shapes; DOES NOT currently propagate world field etc to nrcz childr level*)
			VAR s:Shape;
			BEGIN
				IF shape #NIL THEN
					s:=shape;
					LOOP
						s.world:=SELF;
						IF s.next=NIL THEN s.next:=cutout; cutout:=shape; EXIT END;
						s:=s.next;
					END;
				END; (* prepend to list *)
			END AddCutout;
	END World;

	Shape*=OBJECT (*! to do: objects moving in time*)
		CONST mapTransform=[[1,0,0,0],[0,1,1,1]];
		VAR 
			type*:Strings.String;
			world: World; (* parent world; not fully implemented *)
			box*: Box;  (*bounding box - for optimisations: shrinks search space for contents*)
			next*,child*, this: Shape; (*next: for linked list. child: used in container objects*)
			color*, color1*,luminescence*:Color;
			hitList*:Hit;
			coherent*:Complex;
			object*:ANY; (* can link to an object *)
			(*shapes with image mapping*)
			map: Raster.Image;			
			mapWidth, mapHeight:SIZE;			
			interpolation*: SIGNED8; 
			selected*,leaf*, (*!to do: implement properties as SET*)
			specular*,invisible*,refractive*,reflective*, (*refractive shapes act like lenses; reflective shapes act like mirrors. Invisible shapes can use as sensors etc. Invisibility is not yet fully implemented *)
			registerHits*, 	(* this allows reverted raytracing:how many "observation" rays hit a target ? e.g. useful for exploration of point spread function in optics*)
			doCoherent*,  (* allows to sum up coherent light*)
			visited *, 
			(*solid*, *)(*not hollow...*)  
			custom*: BOOLEAN;
			refractIndex*:Datatype;(* for refractive objects*)
			(*transform intersection point to map x,y coordinates *) 
			(*mapTransform: AffineTransform;  (*generic*)*)
			mode:Raster.Mode;

		PROCEDURE &Init0*;
		BEGIN
			type:=shapeType;
			box:=emptyBox;
			(*refractIndex:=1.0; *)
		END Init0;
		
		PROCEDURE Transform*(CONST t: AffineTransform); (*TO DO: implement for child shapes*)
		VAR c: Shape; b0,b1:Coordinate;
		BEGIN
			c:=child; 
			box:=emptyBox;(* minimize box at each transform to avoid box growth*)
			b0:=box.p0; b1:=box.p1; 
			WHILE c#NIL DO 
				c.Transform(t); 
				b0:=MIN(b0, c.box.p0); 
				b1:=MAX(b1, c.box.p1); 
				c:=c.next 
			END;
			b0:=b0-thresholds; (*! is + and minus inverted ??*)
			b1:=b1+thresholds; 
			InitBox(box,b0,b1);
		END Transform;
		
		PROCEDURE AddChild*(c:Shape); (*! Do not add the same child twice = implementation limitation*)
		VAR b0,b1: Coordinate;
		BEGIN
			IF ValidCoordinate(c.box.p0) & ValidCoordinate(c.box.p1) THEN 
				c.next:=child; child:=c; (*prepend*)
				b0:=MIN(box.p0, c.box.p0-thresholds); (*! is + and minus inverted ??*)
				b1:=MAX(box.p1, c.box.p1+thresholds);
				(*b0[3]:=1.0;
				b1[3]:=1.0;*)
				InitBox(box,b0,b1); 
			ELSE 
				IF log#NIL THEN log.String("Shape.AddChild: c inconsistent - not added"); 
					log.Ln; log.Update; 
				END;
			END;
		END AddChild;
		
		PROCEDURE Distance(CONST point:Coordinate);
		BEGIN
		END Distance;
		
		(* here, a group of Shapes can be handled in a multiresolution manner => significant speedup possible - 'intersect' is the major performance limiting method*)
		PROCEDURE Intersect*(CONST line:Ray0; VAR shape: Shape; VAR distance: Datatype; VAR intersection: Coordinate; VAR normal: Vector; VAR color:Color):BOOLEAN; (*method for container objects*)
		VAR found:BOOLEAN; u:Datatype; dp:Vector; 
		BEGIN
			(* check candidate status: Ray intersects with bounding sphere*)
			u := ((box.center-line.p0) +* line.dp) * line.InvInnerdp; 
			(*(*!??*)IF u<0 THEN RETURN FALSE END;*) (*! is this negative suppression OK? is only there since PH 11.10.16 *)
			dp := (box.center-line.p0) - u*line.dp; 
			IF dp+*dp > box.radius*box.radius THEN 
				RETURN FALSE 
			END; 
			
				(* check children*)
			this:=child; found:=FALSE;
			WHILE this#NIL DO
				(*! to do: add cutout here	*)
				found:=this.Intersect(line,shape, distance,intersection,normal,color) OR found;
				this:=this.next;
			END;
			(*! to do: suppress intersections at negative distances, which interfere with transparency and mirroring*)
			(*	IF registerHits & found THEN 	RegisterHit(line, distance, intersection, normal, color) END;	*)
			RETURN found;
		END Intersect;

		(* relatively fast approach to EXCLUDE intersection with ray, but not to prove it or to get parameters*)
		PROCEDURE RayIntersectCandidate(CONST ray: Ray0): BOOLEAN;
		VAR u:Datatype; dp:Vector;
		BEGIN
			IF ray.p0=box.center THEN RETURN TRUE
			ELSE
				u := ((box.center-ray.p0) +* ray.dp)* ray.InvInnerdp;
				dp := box.center-ray.p0 - u*ray.dp;
				RETURN dp+*dp <= box.radius*box.radius
			END;
		END RayIntersectCandidate;
(*
		PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN;
		BEGIN
			RETURN ABS((box.p0-plane.p) +* plane.normal) <= box.radius
		END PlaneIntersectCandidate;
*)
		PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN; (** quick check, if intersection with plane can be excluded *)
		VAR  sign: Datatype;
		BEGIN
			(* all inner products [point-on-plane => box egde; plane-normal] have same sign as long as all points are on one side of plane*)
			sign := plane.normal+* (box.p0 - plane.p);
			IF sign * (plane.normal+*(box.p1 - plane.p)) <=0 THEN RETURN TRUE
			(*
			ELSIF sign * (plane.normal+* ([box.p0[0], box.p0[1], box.p1[2], 1] - plane.p)) <=0 THEN RETURN TRUE  (* sign change implies points on both sides of plane, i.e. intersection of bounding box with plane *)
			ELSIF sign * (plane.normal+* ([box.p0[0], box.p1[1], box.p1[2], 1] - plane.p)) <=0 THEN RETURN TRUE  (*! performance of inline vector construction ?*)
			ELSIF sign * (plane.normal+* ([box.p0[0], box.p1[1], box.p0[2], 1] - plane.p)) <=0 THEN RETURN TRUE  (* optimize: consider InlineV.CastVector, but did run into a runtime error related to return type*)
			ELSIF sign * (plane.normal+* ([box.p1[0], box.p0[1], box.p0[2], 1] - plane.p)) <=0 THEN RETURN TRUE 
			ELSIF sign * (plane.normal+* ([box.p1[0], box.p0[1], box.p1[2], 1] - plane.p)) <=0 THEN RETURN TRUE 
			ELSIF sign * (plane.normal+* ([box.p1[0], box.p1[1], box.p0[2], 1] - plane.p)) <=0 THEN RETURN TRUE 
			*)
(*! TBD: has the assembled coordinate has a 0 or a 1 at the end ? Both versions seem to work equally in TestMirrorLens and  seem to same result of equation ? it should probably be a point, though*)

			ELSIF sign * (plane.normal+* (V.CastVector(box.p0[0], box.p0[1], box.p1[2], 1) - plane.p)) <=0 THEN RETURN TRUE  (* sign change implies points on both sides of plane, i.e. intersection of bounding box with plane *)
			ELSIF sign * (plane.normal+* (V.CastVector(box.p0[0], box.p1[1], box.p1[2], 1) - plane.p)) <=0 THEN RETURN TRUE  (*! performance of inline vector construction ?*)
			ELSIF sign * (plane.normal+* (V.CastVector(box.p0[0], box.p1[1], box.p0[2], 1) - plane.p)) <=0 THEN RETURN TRUE  (* optimize: consider InlineV.CastVector, but did run into a runtime error related to return type*)
			ELSIF sign * (plane.normal+* (V.CastVector(box.p1[0], box.p0[1], box.p0[2], 1) - plane.p)) <=0 THEN RETURN TRUE 
			ELSIF sign * (plane.normal+* (V.CastVector(box.p1[0], box.p0[1], box.p1[2], 1) - plane.p)) <=0 THEN RETURN TRUE 
			ELSIF sign * (plane.normal+* (V.CastVector(box.p1[0], box.p1[1], box.p0[2], 1) - plane.p)) <=0 THEN RETURN TRUE 

			ELSE RETURN FALSE;
			END;
		END PlaneIntersectCandidate;

		(** set same color to object and all its children. If child should get different color, address it directly *)
		PROCEDURE SetColor*(CONST color:Color; override:BOOLEAN);
		BEGIN
			IF (SELF.color[3]=CHR(0)) OR override THEN SELF.color:=color;  END;
			this:=child;
			WHILE this#NIL DO this.SetColor(color,override); this:=this.next END;
		END SetColor;

		PROCEDURE SetReflectiveRefractive*(reflective,refractive:BOOLEAN; propagate:BOOLEAN);
		BEGIN
			SELF.reflective:=reflective; SELF.refractive:=refractive;
			IF propagate THEN
				this:=child;
				WHILE this#NIL DO 
					this.SetReflectiveRefractive(reflective,refractive,propagate); 
					IF this.refractIndex=0 THEN this.refractIndex:=refractIndex END;
					this:=this.next 
				END;
			END;
		END SetReflectiveRefractive;

		
		PROCEDURE ColorAt(CONST p:Coordinate):Color; (* implement for maps, gradients etc, see e.g. Quadrangle.ColorAt() *)
		VAR color0:Color; col: ColorA; xy: ARRAY [2] OF SIGNED32;
		BEGIN
			IF map=NIL THEN RETURN color
			ELSE 
				xy:=ENTIER(mapTransform * p); 
				Raster.Get(map, MIN(mapWidth-1,MAX(0,xy[0])), MIN(mapHeight-1,MAX(0,xy[1])), col, mode);
				SYSTEM.VAL(SIGNED32,color0) := SYSTEM.VAL(SIGNED32,col);
				RETURN color0;
			END;
		END ColorAt;
		
		(** set color according to number of hits to object and all its children. *) (* to consider : combine triangles to square for nicer look ? some phong smoothing ?*)
		PROCEDURE SetHitColor*();
		VAR hit:Hit; i:SIGNED32;
		BEGIN
			hit:=hitList;
			i:=0;
			WHILE hit#NIL DO INC(i); hit:=hit.next; END;
			color[0]:=CHR(MIN(255, 10*i)); 
			color[1]:=0X; color[2]:=0X;
			color[3]:=CHR(255);
			IF doCoherent THEN
				
			END;
			this:=child;
			WHILE this#NIL DO 
				IF this.child=NIL THEN (*hack to combine to child triangles into rectangular patches - looks nicer...*)
					this.color:=color
				ELSE this.SetHitColor(); 
				END;
				(*this.SetHitColor;*) (* regular version using triangle coloring, looks a little strange/asymmetric*)
				 this:=this.next 
			END;
		END SetHitColor;
		
		(** set color according to number of hits to object and all its children. *)
		PROCEDURE SetHitRegistration*(register:BOOLEAN; recursive: BOOLEAN);
		BEGIN
			registerHits:=register;
			IF register THEN hitList:=NIL END; (*? reset*)
			IF recursive THEN 
				this:=child;
				WHILE this#NIL DO this.SetHitRegistration(register, recursive); this:=this.next END;
			END;
		END SetHitRegistration;
		
		PROCEDURE RegisterHit*(CONST line:Ray0; distance:Datatype; CONST intersection: Coordinate; CONST normal: Vector; CONST color:Color);
		VAR hit:Hit;
		BEGIN
			NEW(hit); hit.p0:=intersection; hit.p1:=hit.p0+line.dp; hit.dp:=line.dp; hit.normal:=normal; hit.color:=color; 
			hit.sourceDistance:=line.sourceDistance+V.Length(intersection-line.p0);
			hit.next:=hitList; hitList:=hit
		END RegisterHit;
		
		PROCEDURE Set2Colors*(CONST color,color1:Color);
		VAR i:SIGNED32;
		BEGIN
			SELF.color:=color;
			SELF.color1:=color1;
			this:=child;
			i:=1;
			WHILE this#NIL DO 
				IF leaf THEN
					IF ODD(i) THEN this.SetColor(color1,FALSE) ELSE this.SetColor(color,FALSE) END;
				ELSE this.Set2Colors(color,color1);
				END;
				INC(i);
				this:=this.next 
			END;
		END Set2Colors;
		
		PROCEDURE SetMap*(img:Raster.Image);
		BEGIN
			map:=img; 
			mapHeight:=img.height;mapWidth:=img.width;
			Raster.InitMode(mode, Raster.srcCopy);
		END SetMap;
		
	END Shape;

	ShapeList*=POINTER TO RECORD
		shape*: Shape;
		distance, relativeDistance:Datatype;
		next*: ShapeList;
	END;
	
	Dot*=OBJECT(Shape)
	VAR p0:Coordinate; 
		size*: Datatype; (* detection radius *)
		
		PROCEDURE &Init*(CONST p0:Coordinate; size:Datatype);
		BEGIN
			type:=dotType;
			SELF.p0:=p0;
			SELF.size:=size;
			InitBox(box, p0-[size,size,size,0],p0+[size,size,size,0]); 
		END Init;
		
		PROCEDURE Transform*(CONST t: AffineTransform);
		BEGIN
			p0:=t*p0;
			Transform^(t);
			InitBox(box, MIN(box.p0,p0), MAX(box.p1,p0));
		END Transform;
		
		PROCEDURE Intersect*(CONST line:Ray0; VAR shape:Shape; VAR distance: Datatype; VAR intersection: Coordinate; VAR normal: Vector; VAR color:Color):BOOLEAN; (*res: linked list of intersection points and surface normals*)
		VAR u:Datatype; dp: Coordinate;
		BEGIN
			u := ((p0-line.p0) +* line.dp)* line.InvInnerdp;
			dp :=(p0-line.p0)- u*line.dp;
			IF dp+*dp < size*size THEN(*IF V.Length(dp)<size THEN*)
				IF u<distance THEN 
					shape:=SELF; distance:=u; intersection:=p0; normal:=-line.dp (*assumption: line is normalized*); 
					color:=ColorAt(intersection);  
					RETURN TRUE
				ELSE RETURN FALSE (*intersects,but behind other structure*)
				END;
			ELSE RETURN FALSE
			END;
		END Intersect;
	END Dot;

	Line*=OBJECT(Shape) 
		VAR size*:Datatype;
			line0:Ray0;
		PROCEDURE &Init*(CONST p0,p1:Coordinate; size:Datatype);
		BEGIN
			type:=lineType;
			line0.p0:=p0; line0.p1:=p1; line0.dp:=p1-p0; 
			line0.Innerp0:=p0+*p0;
			line0.Innerdp:=line0.dp+*line0.dp; 
			line0.InvInnerdp:=1/line0.Innerdp; 
			IF Reals.IsNaN(line0.InvInnerdp) THEN line0.InvInnerdp:=0 END;
			SELF.size:=size;
			InitBox(box, MIN(p0,p1)-[size,size,size,0], MAX(p0,p1)+[size,size,size,0]); 
		END Init;
		
		PROCEDURE Transform*(CONST t: AffineTransform);
		BEGIN
			line0.p0:= t*line0.p0;
			line0.p1:=t*line0.p1;
			line0.dp:=line0.p1-line0.p0;
			Transform^(t);
			InitBox(box,MIN( MIN(box.p0,line0.p0),line0.p1), MAX(MAX(box.p1,line0.p0),line0.p1));
		END Transform;
		
		PROCEDURE Intersect*(CONST ray:Ray0; VAR shape:Shape; VAR distance: Datatype; VAR intersection: Coordinate; VAR normal: Vector; VAR color:Color):BOOLEAN; (*res: linked list of intersection points and surface normals*)
		VAR ua,ub:Datatype; d, d4321, d4343, d2121, d1321, d1343,dist: Datatype; pdiff,ldiff: Coordinate;
		BEGIN
		(*	IF line0.dp=line1.dp THEN (*? parallel *)*)
				d4321:=ray.dp+*line0.dp;
				d4343:=ray.Innerdp; (* =1 because rays that should be normalized by default*)
				d2121:=line0.Innerdp;
				pdiff:=line0.p0-ray.p0;
				d1321:=pdiff+* line0.dp;
				d1343:=pdiff+* ray.dp;
				d := d2121 * d4343 - d4321 * d4321;
				IF d=0 THEN RETURN FALSE (*!? HALT(100); *) (*do what ?  parallel lines ? coincident lines ? *)
				ELSE
					ua := ( d1343 * d4321 - d1321 * d4343) / d;
					ub := ( d1343 + d4321*ua) / d4343;
					(*IF (ua>V.Length(pdiff)) OR (ua<0) THEN RETURN FALSE END;*)
					IF (ua*ua > pdiff+*pdiff) OR (ua<0) THEN RETURN FALSE END;
					ldiff := (line0.p0 + ua*line0.dp) - (ray.p0 + ub*ray.dp);
					dist:= V.Length(ldiff);
					IF (dist<size)&(ub<distance) THEN (*can be optimized by postponing V.Length to after IF, saving SQRS somtimes*)
						shape:=SELF; distance:=dist; intersection:= ray.p0 + ub*ray.dp; distance:=ub; normal:=-ray.dp; 
						color:=ColorAt(intersection); 
						RETURN TRUE
					ELSE RETURN FALSE
					END;
				END;
			(*END;*)
		END Intersect;
	END Line;
	
	(*coordinate system display. RGB=XYZ, darker colors signal negative axis *)
	TYPE CoordinateSystem*= OBJECT (Shape)
		VAR cs: AffineTransform;
		
		(* negative length leads to axis drawing in positive AND negative directions *)
		PROCEDURE &Init*(CONST transform: AffineTransform; width, length: Datatype);
		VAR line: Line; p0,p1: Coordinate;
		BEGIN
			type:=coordinateType;
			box:=emptyBox;
			SELF.cs:=transform;
			p0:=transform[..,3];
			p1:=transform*[1.0,0,0,0]; p1:=p1*ABS(length)+transform[..,3];
			NEW(line,p0, p1, width); line.luminescence:=Col.red; AddChild(line);
			p1:=transform*[0,1.0,0,0]; p1:=p1*ABS(length)+transform[..,3];
			NEW(line,p0, p1, width); line.luminescence:=Col.green; AddChild(line);
			p1:=transform*[0,0,1.0,0]; p1:=p1*ABS(length)+transform[..,3];
			NEW(line,p0, p1 , width); line.luminescence:=Col.blue; AddChild(line);
			IF length<0 THEN
				p1:=transform*[1.0,0,0,0]; p1:=p1*length+transform[..,3];
				NEW(line,p0, p1, width); line.luminescence:=Col.darkred; AddChild(line);
				p1:=transform*[0,1.0,0,0]; p1:=p1*length+transform[..,3];
				NEW(line,p0, p1, width); line.luminescence:=Col.darkgreen; AddChild(line);
				p1:=transform*[0,0,1.0,0]; p1:=p1*length+transform[..,3];
				NEW(line,p0, p1 , width); line.luminescence:=Col.darkblue; AddChild(line);
			END;
		END Init;
	END CoordinateSystem;
	
	(*
	Curve=OBJECT(Shape)
		VAR coeff: ARRAY [*] OF Coordinate2;
			boundary:SIGNED32; (*closed=periodic; open=..*)
			interpolation: SIGNED32; (*piecewise constant, linear, spline *)
	END Curve;
	*)

	Plane*=OBJECT(Shape) 
		VAR A,B,C: Coordinate; 
			q: Coordinate; (*temp variables for efficient reuse by methods. Take care not to use temp variables in methods calling each other => side effect !*)
			E:Datatype; (* plane equation: ax+by+cz+E=0 *)
			Normal*:Vector;

		PROCEDURE &Init*(CONST A,B,C: Coordinate);
		BEGIN
			type:=planeType;
			InitGeometry(A,B,C);
			interpolation:=NoInterpolation;
			SetColor(Col.white,FALSE); (*global, is propagated to children*)
			specular:=TRUE;
		END Init;
		
		PROCEDURE InitGeometry*(CONST A,B,C: Coordinate);
		BEGIN
			SELF.A:=A; SELF.B:=B; SELF.C:=C;
			Normal:=V.Normalize((B-A)*(C-A));
			E:= - Normal +* A;
			InitBox(box, MinusInfinity, PlusInfinity); 
		END InitGeometry;
		
		PROCEDURE Transform*(CONST t: AffineTransform);
		BEGIN
			Transform^(t);
			InitGeometry(t*A, t*B, t*C);		
		END Transform;

		(*to do: separate intersect  test from rendering aspects *)
		(* for a fast alternative version not dependent on real-time cross products see http://www.softsurfer.com/Archive/algorithm_0105/algorithm_0105.htm*)
		PROCEDURE Intersect*(CONST line:Ray0; VAR shape:Shape; VAR distance: Datatype; VAR intersection: Coordinate; VAR Normal: Vector; VAR color:Color):BOOLEAN; (*res: linked list of intersection points and surface Normals*)
		VAR d,mu:Datatype; 
		BEGIN
			d:=-(line.dp+*SELF.Normal);
			IF d=0 THEN 
				RETURN FALSE (*parallel; case of parallel, but in-plane not handled..*)
			ELSE
				mu:= (SELF.Normal+*line.p0+E)/d;
				IF (mu>=distance) OR (mu<threshold (*<=0*)) THEN RETURN FALSE END; (* intersection possible, but behind other structure ; move this code down if transparency matters; is put up her for performance only*)
				q:=line.p0+mu*line.dp;
				shape:=SELF;
				distance:=mu;
				intersection:=q;
				Normal:=SELF.Normal;
				color:=ColorAt(intersection); 
				(*IF registerHits THEN RegisterHit(line,distance, intersection, Normal,color) END;*)
				RETURN TRUE
			END;
		END Intersect;
		
		PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN;
		BEGIN
			RETURN TRUE
		END PlaneIntersectCandidate;
	END Plane;

		Triangle*=OBJECT(Plane) (*! to do: two variants may exist here: a) a proper triangle; b) a triangle from a subdivided surface which may need interpolative redering (Gouraud,Phong) at additional computational cost*)
		VAR 
			Na,Nb,Nc: Vector;
		
		PROCEDURE InitGeometry*(CONST A,B,C: Coordinate);
		BEGIN
			type:=triangleType;
			InitGeometry^(A,B,C);
			InitBox(box, MIN(A,MIN(B,C)) , MAX(A, MAX(B,C)));
			Na:=Normal; Nb:=Normal; Nc:=Normal;
		END InitGeometry;
		
		PROCEDURE SetEdgeNormals(CONST Na,Nb,Nc: Vector);
		BEGIN
			IF Na[3]=NaN THEN SELF.Na:=Normal ELSE SELF.Na:=Na END; 
			IF Nb[3]=NaN THEN SELF.Nb:=Normal ELSE SELF.Nb:=Nb END;
			IF Nc[3]=NaN THEN SELF.Nc:=Normal ELSE SELF.Nc:=Nc END;
		END SetEdgeNormals;

		(*to do: separate intersect  test from rendering aspects *)
		(* for a fast alternative version not dependent on real-time cross products see http://www.softsurfer.com/Archive/algorithm_0105/algorithm_0105.htm*)
		PROCEDURE Intersect*(CONST line:Ray0; VAR shape:Shape; VAR distance: Datatype; VAR intersection: Coordinate; VAR Normal: Vector; VAR color:Color):BOOLEAN; (*res: linked list of intersection points and surface Normals*)
		VAR d,mu:Datatype; c0,c1,c2: Vector; hit:Hit; 
		BEGIN
			d:=-line.dp+*SELF.Normal;
			IF d=0 THEN RETURN FALSE (*parallel; case of parallel, but in-plane not handled..*)
			ELSE
				mu:= (SELF.Normal+*line.p0+E)/d;
				IF (mu>=distance) OR (mu<threshold (*<=0*)) THEN RETURN FALSE END; (* intersection possible, but behind other structure ; move this code down if transparency matters; is put up her for performance only*)
				q:=line.p0+mu*line.dp;	(*q:=V.MulAdd(line.p0, line.dp, mu);*)
				IF ~((q>=box.p0) & (box.p1>=q)) (*3-vector comparison*) THEN RETURN FALSE 
				ELSE
					c0:=(B-A)*(q-A);(*cross product*)
					c1:=(C-B)*(q-B);
					IF c0+*c1<0 THEN RETURN FALSE
					ELSE
						c2:=(A-C)*(q-C);
						IF c1+*c2<0 THEN RETURN FALSE
						ELSE
							shape:=SELF;
							distance:=mu;
							intersection:=q;
							Normal:=SELF.Normal;
							color:=ColorAt(intersection);  
							IF registerHits THEN RegisterHit(line,distance, intersection, Normal,color) END;
							RETURN TRUE
						END;
					END;
				END;
			END;
			(*	Most collision detection algorithms, such as OBBTree [Gottschalk96], sphere hierarchies
			[Hubbard96] and BV-trees [Klosowski97], try to minimize the number of primitive-primitive intersections that have to be computed.
			Still, a fast and reliable method for computing the primitive-primitive intersection is desired.
			Here, the concept of Moeller, cited above, may be very useful.
			fast triangle-triangle intersection: http://knight.temple.edu/~lakaemper/courses/cis350_2004/etc/moeller_triangle.pdf
			fast triangle-box intersection test: http://reference.kfupm.edu.sa/content/f/a/fast_3d_triangle_box_overlap_testing_103130.pdf
			*)
		END Intersect;
		
		PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN;
		VAR a,b,c: Datatype;
		BEGIN
			a:= plane.normal+*(A-plane.p);
			b:= plane.normal+*(B-plane.p);
			IF a*b<=0 THEN RETURN TRUE
			ELSE
				c:=plane.normal+*(C-plane.p);
				IF a*c<=0 THEN RETURN TRUE
				ELSE RETURN FALSE
				END;
			END;
		END PlaneIntersectCandidate;

		PROCEDURE IntersectTriangle (CONST T: Triangle; VAR Intersection0,Intersection1: Coordinate): BOOLEAN;
		VAR I,N: Coordinate; line: Ray0; nHits: SIGNED32; distance: Datatype; col:Color; shape:Shape;
		BEGIN
			(* naive version: in intersecting triangles, at least one side of triangle B hits triangle A,
			or at least one side of triangle A hits triangle B. Typically, there are 2 characteristic hit points.
			Question: what happens in case of coplanar triangles ?
			if more speed needed: see fast triangle-triangle intersection: http://knight.temple.edu/~lakaemper/courses/cis350_2004/etc/moeller_triangle.pdf			
			*)
		(* check if  SELF is intersected by T*)
			line.p0:=T.A; line.dp:=T.B-T.A; line.p1:=T.B;
			line.Innerp0:=line.p0(*-Origin*) +* line.p0; line.Innerdp:= line.dp +* line.dp; 
			line.InvInnerdp:=1/line.Innerdp; 
			IF Intersect(line, shape, distance, I, N, col) THEN (* line hits triangle *)
				IF (I-T.A)+* (I-T.B) <0 THEN (* and intersection point  is on line segment between T.A and T.B *)
					INC(nHits); IF nHits=1 THEN Intersection0:=I ELSE Intersection1:=I; RETURN TRUE END;
				END;
			END;

			line.p0:=T.B; line.dp:=T.C-T.B; line.p1:=T.C; 
			line.Innerp0:=(line.p0(*-Origin*)+*line.p0); line.Innerdp:= (line.dp+*line.dp); 

			line.InvInnerdp:=1/line.Innerdp;
			IF Intersect(line, shape, distance, I, N, col) THEN
				IF (I-T.B)+* (I-T.C) <0 THEN
					INC(nHits); IF nHits=1 THEN Intersection0:=I ELSE Intersection1:=I; RETURN TRUE END
				END;
			END;

			line.p0:=T.C; line.dp:=T.A-T.C; line.p1:=T.A;
			
			line.Innerp0:=line.p0(*-Origin*) +* line.p0; 
			line.Innerdp:= line.dp +* line.dp;
			line.InvInnerdp:=1/line.Innerdp;
			IF Intersect(line, shape, distance, I, N, col) THEN
				IF (I-T.C)+* (I-T.A) <0 THEN
					INC(nHits); IF nHits=1 THEN Intersection0:=I ELSE Intersection1:=I; RETURN TRUE END;
				END;
			END;

			(* check if  T is intersected by SELF*)
			line.p0:=A; line.dp:=B-A; line.p1:=T.B;
			line.Innerp0:=line.p0(*-Origin*)+*line.p0; line.Innerdp:=line.dp+*line.dp;  
			line.InvInnerdp:=1/line.Innerdp;
			IF T.Intersect(line, shape, distance, I, N, col) THEN
				IF (I-A)+*(I-B) <0 THEN (* I is between T.A and T.B *)
					INC(nHits); IF nHits=1 THEN Intersection0:=I ELSE Intersection1:=I; RETURN TRUE END;
				END;
			END;

			line.p0:=B; line.dp:=C-B; line.p1:=T.C;
			line.Innerp0:=line.p0(*-Origin*)+*line.p0; line.Innerdp:= line.dp+*line.dp;  
			line.InvInnerdp:=1/line.Innerdp;
			IF T.Intersect(line, shape, distance, I, N, col) THEN
				IF (I-B)+*(I-C) <0 THEN
					INC(nHits); IF nHits=1 THEN Intersection0:=I ELSE Intersection1:=I; RETURN TRUE END
				END;
			END;

			line.p0:=C; line.dp:=A-C; line.p1:=T.A;
			line.Innerp0:=line.p0(*-Origin*)+*line.p0;
			line.Innerdp:= line.dp+*line.dp; 
			line.InvInnerdp:=1/line.Innerdp;
			IF T.Intersect(line, shape, distance, I, N, col) THEN
				IF (I-C)+*(I-A)<0  THEN
					INC(nHits); IF nHits=1 THEN Intersection0:=I ELSE Intersection1:=I; RETURN TRUE END;
				END;
			END;
			(*IF nHits=1 THEN RETURN TRUE END; (*edge contact - how to handle ?*)*)
			RETURN FALSE
		(*a list of methods is given here: http://realtimecollisiondetection.net/blog/?p=29
		and a code from moeller is at http://jgt.akpeters.com/papers/Moller97/tritri.html *)
		END IntersectTriangle;
	END Triangle;

	Quadrangle*=OBJECT(Shape) 
		VAR A,B,C,D: Coordinate;  (* plane equation: Ax+By+Cz+E=0 ; D is assumed to be in-plane*)
			q: Coordinate; (*temp variables for efficient reuse by methods. Take care not to use temp variables in methods calling each other => side effect !*)
			E:Datatype;
			Normal*:Vector;
			hAxis,wAxis: Vector;

		PROCEDURE &Init*(CONST A,B,C,D: Coordinate);
		BEGIN
			type:=imageType;
			InitGeometry(A,B,C,D);
			interpolation:=NoInterpolation;
			SetColor(Col.white,FALSE); (*global, is propagated to children*)
			specular:=TRUE;
		END Init;
		
		PROCEDURE InitGeometry*(CONST A,B,C,D: Coordinate);
		BEGIN
			SELF.A:=A; SELF.B:=B; SELF.C:=C; SELF.D:=D;
			hAxis:=V.Normalize(D-A);
			wAxis:=V.Normalize(B-A); 
			Normal:=V.Normalize((C-A)*(D-B));
			E:= - Normal +* A;
			InitBox(box, MIN(A,MIN(B,MIN(C,D))) , MAX(A, MAX(B,MAX(C,D))));
		END InitGeometry;
		
		PROCEDURE Transform*(CONST t: AffineTransform);
		BEGIN
			InitGeometry(t*A, t*B, t*C, t*D);
			Transform^(t);
		END Transform;
		
		PROCEDURE ColorAt(CONST p:Coordinate):Color;
		VAR ix,iy:SIGNED32; color0:Color; col: ColorA;
		BEGIN
			IF map=NIL THEN RETURN color
			ELSE
				(*to do: use mapTransform instead*)
				ix:=ENTIER((q-A)+*wAxis*mapWidth);
				iy:=ENTIER((q-A)+*hAxis*mapHeight);
				Raster.Get(map, MIN(mapWidth-1,MAX(0,ix)), MIN(mapHeight-1,MAX(0,iy)), col, mode);(*!would need oblique coordinates*)
				SYSTEM.VAL(SIGNED32,color0) := SYSTEM.VAL(SIGNED32,col);
				RETURN color0
			END;
		END ColorAt;

		PROCEDURE Intersect*(CONST line:Ray0; VAR shape:Shape; VAR distance: Datatype; VAR intersection: Coordinate; VAR Normal: Vector; VAR color:Color):BOOLEAN; (*res: linked list of intersection points and surface Normals*)
		VAR d,mu:Datatype; c0,c1,c2,c3: Vector; hit:Hit; color0:Color;
		BEGIN
			d:=-line.dp+*SELF.Normal;
			IF d=0 THEN RETURN FALSE (*parallel; case of parallel, but in-plane not handled..*)
			ELSE
				mu:= (SELF.Normal+*line.p0+E)/d;
				IF (mu>=distance) OR (mu<threshold (*mu<-threshold *)(*<=0*)) THEN RETURN FALSE END; (* intersection possible, but behind other structure ; move this code down if transparency matters; is put up her for performance only*)
				q:=line.p0+mu*line.dp;
				IF ~((q>=box.p0) & (box.p1>=q)) (*3-vector comparison*) THEN RETURN FALSE 			
				ELSE
					c0:=(B-A)*(q-A);(*cross product*)
					c1:=(C-B)*(q-B);
					IF c0+*c1>=0 THEN (*same sign*)
						c2:=(D-C)*(q-C);
						IF c1+*c2>=0 THEN
							c3:=(A-D)*(q-D);
							IF c2+*c3>=0 THEN
								color0:=ColorAt(q);
								IF color0=Col.transparent THEN RETURN FALSE
								ELSE
									shape:=SELF;
									distance:=mu;
									intersection:=q;
									Normal:=SELF.Normal;
									color:=color0;
									IF registerHits THEN RegisterHit(line,distance, intersection, Normal,color) END;
									RETURN TRUE
								END;
							ELSE RETURN FALSE
							END;
						ELSE RETURN FALSE
						END;
					ELSE RETURN FALSE
					END;
				END;
			END;
		END Intersect;
		
		PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN;
		VAR a,b,c,d: Datatype;
		BEGIN
			a:= plane.normal+*(A-plane.p);
			b:= plane.normal+*(B-plane.p);
			IF a*b<=0 THEN RETURN TRUE
			ELSE
				c:=plane.normal+*(C-plane.p);
				IF a*c<=0 THEN RETURN TRUE
				ELSE
					d:=plane.normal+*(D-plane.p);
					RETURN a*d<=0
				END;
			END;
		END PlaneIntersectCandidate;
	END Quadrangle;
	
	Circle*=OBJECT(Plane)
		VAR radius*: Datatype;
		PROCEDURE &Init0*;
		BEGIN
			type:=circleType;
			HALT(100);(*unifinished implementation*)
		END Init0;
	END Circle;
	
	TYPE PlanarArray*= OBJECT(Plane)  (*! to do: Transform() *)
		VAR 
			matrix*, r*,g*,b*:ARRAY[*,*] OF FLOAT64; (*optionally, color statistics can be done*)
			max,maxR,maxG,maxB: FLOAT64;
			colorGain*:Datatype;
			useColor*:BOOLEAN;
			
		PROCEDURE &Initialize*(CONST A,B,C: Coordinate; CONST m:ARRAY[*,*] OF FLOAT64; useColor:BOOLEAN); (*! to do: call InitBox()*)
		BEGIN
			type:=planarArrayType;
			Init(A,B,C);
			box:=emptyBox;
			matrix:=m;
			SELF.useColor:=useColor;
			IF useColor THEN NEW(r, LEN(m)); NEW(g,LEN(m)); NEW(b,LEN(m)); END;
			max:=MAX(m);
			colorGain:=2;
			SetColor(Col.gray (*was transparent*),FALSE); 
		END Initialize;
		
		PROCEDURE FindIndices(CONST intersection: Coordinate; VAR Row,Column:SIGNED32);
		VAR db,dc: Datatype; ba,ca,ia: Vector;
		BEGIN 
			ba:=B-A;
			ca:=C-A;
			ia:=intersection-A;
			dc:= V.Length(ba*ia) / V.Length(ba); (*! optimize: can replace multiple Length() calls by sqared versions or postponed square roots*)
			db:=V.Length(ca*ia) / V.Length(ca);
			Column:=ENTIER(dc/V.Length(ca)*LEN(matrix,0)); 		IF ~(ba +* ia >= 0) THEN Column:=-1 END;
			Row:=  ENTIER(db/V.Length(ba)*LEN(matrix,1)); IF ~(ca +* ia >=0) THEN Row:=-1 END;
		END FindIndices;
		
		PROCEDURE Intersect*(CONST line:Ray0; VAR shape: Shape; VAR distance: Datatype; VAR intersection: Coordinate; VAR normal: Vector; VAR color:Color):BOOLEAN;
		VAR Row,Column:SIGNED32; shape1:Shape; distance1:Datatype; intersection1:Coordinate; normal1:Vector; color1,c:Color; maxC:FLOAT64;
		BEGIN
			color1:=color; distance1:=distance;
			IF Intersect^(line,shape1,distance1,intersection1,normal1,color1) THEN (* *)
				FindIndices(intersection1,Row,Column);
				IF (Row>=0)&(Row<LEN(matrix,0))&(Column>=0)&(Column<LEN(matrix,1)) THEN
					shape:=SELF; intersection:=intersection1; normal:=normal1;
					IF registerHits THEN RegisterHit(line, distance1, intersection, normal, color) 
					ELSE 
						IF useColor THEN
							IF MAX(MAX(b[Row,Column],g[Row,Column]),r[Row,Column])=0 THEN (* no change*)
							ELSE
								maxC:=MAX(maxR, MAX(maxG,maxB));
								c[0]:=CHR(ENTIER(colorGain*255*(b[Row,Column]/maxC)));
								c[1]:=CHR(ENTIER(colorGain*255*(g[Row,Column]/maxC)));
								c[2]:=CHR(ENTIER(colorGain*255*(r[Row,Column]/maxC)));
								c[3]:=CHR(255);
								color:=color+c;
							END;
						ELSIF matrix[Row,Column]=0 THEN (* no change*)
						ELSE 
							color:=color + colorGain*SHORT(matrix[Row,Column]/max) * Col.white; (* read sensor out *)
						END;
					END;
					IF TRUE (*SELF.color=transparent*) THEN distance:=MAX(Datatype); (* i.e., further hits will be tested, as ray passes through the 'transparent' sensor *)
					ELSE distance:=distance1; 
					END;
					RETURN TRUE
				ELSE RETURN FALSE
				END;
			ELSE RETURN FALSE
			END;
		END Intersect;
		
		PROCEDURE RegisterHit*(CONST line:Ray0; distance:Datatype; CONST intersection: Coordinate; CONST normal: Vector; CONST color:Color);
		VAR Row,Col:SIGNED32; val:FLOAT64; 
		BEGIN
			FindIndices(intersection,Row,Col);
			IF useColor THEN 
				val:=b[LEN(matrix,0)-Row-1,Col]+ORD(line.viewer.beamColor[0]); b[LEN(matrix,0)-Row-1,Col]:=val; maxB:=MAX(maxB, val);
				val:=g[LEN(matrix,0)-Row-1,Col]+ORD(line.viewer.beamColor[1]); g[LEN(matrix,0)-Row-1,Col]:=val; maxG:=MAX(maxG, val);
				val:=r[LEN(matrix,0)-Row-1,Col]+ORD(line.viewer.beamColor[2]); r[LEN(matrix,0)-Row-1,Col]:=val; maxR:=MAX(maxR, val);
			END;
			val:=matrix[LEN(matrix,0)-Row-1,Col] + 1 ;(* incident angle is already implicit in hit probability*) ; (*! to do: normalize according to distance from light source and  incident vector, using inner product  with (B-A)*(C-A) *)
			matrix[LEN(matrix,0)-Row-1,Col]:=val;	max:=MAX(max,val); 
		END RegisterHit;
	END PlanarArray;

	VolumeShape*=OBJECT(Shape)
		
		PROCEDURE &Init0*;
		BEGIN
			type:=volumeShapeType;
		END Init0;
		
		PROCEDURE Inside*(CONST P:Coordinate):BOOLEAN;
		VAR c: Shape;
		BEGIN
			IF ~((P>=box.p0) & (P<=box.p1)) THEN RETURN FALSE END;
			c:=child; 
			WHILE c#NIL DO 
				IF (c IS VolumeShape) & c(VolumeShape).Inside(P) THEN RETURN TRUE
				ELSE c:=c.next;
				END;
			END;
			RETURN FALSE
		END Inside;
(*
		PROCEDURE Solid*(CONST P:Coordinate; VAR found, isSolid:BOOLEAN);(*not yet handling overlaps*)
		VAR c: Shape;
		BEGIN
			IF ~((P>=box.p0) & (P<=box.p1)) THEN found:=FALSE; RETURN END;
			c:=child; 
			WHILE c#NIL DO 
				IF (c IS VolumeShape) THEN 
					c(VolumeShape).Solid(P, found, isSolid);
					IF found THEN RETURN END;
				ELSE c:=c.next;
				END;
			END;
			IF Inside(P) THEN isSolid:=solid; found:=TRUE END;
		END Solid;
*)
		
		(* produce binary dataset in cartesian grid. 'transform' describes transformation from world coordinate system to cartesian voxel coordinates  *)
		PROCEDURE CastVolume*(VAR cartesian: ARRAY [*,*,*] OF BOOLEAN; CONST transform:AffineTransform; mode:ARRAY OF CHAR);
		VAR x,y,z: SIZE; a,b:BOOLEAN;
		BEGIN
			FOR x:=0 TO LEN(cartesian,0)-1 DO
				FOR y:=0 TO LEN(cartesian,1)-1 DO
					FOR z:=0 TO LEN(cartesian,2)-1 DO
						IF mode="&" THEN cartesian[x,y,z]:=cartesian[x,y,z] & Inside(transform*V.CastVector(x,y,z,1.0));
						ELSIF mode="OR" THEN cartesian[x,y,z]:=cartesian[x,y,z] OR Inside(transform*V.CastVector(x,y,z,1.0));
						ELSIF mode="EXCL" THEN cartesian[x,y,z]:=cartesian[x,y,z] & ~Inside(transform*V.CastVector(x,y,z,1.0));
						ELSIF mode="XOR" THEN 
							a:=cartesian[x,y,z];
							b:=Inside(transform*V.CastVector(x,y,z,1.0));
							cartesian[x,y,z]:=(a & ~b) OR (b & ~a);
						ELSE cartesian[x,y,z]:=Inside(transform*V.CastVector(x,y,z,1.0));
						END;
					END;
				END;
			END;
		END CastVolume;
(*
		(* produce binary dataset in cartesian grid. 'transform' describes transformation from world coordinate system to cartesian voxel coordinates  *)
		PROCEDURE CastSolid*(VAR cartesian: ARRAY [*,*,*] OF BOOLEAN; CONST transform:AffineTransform);
		VAR x,y,z: SIZE; found:BOOLEAN;
		BEGIN
			FOR x:=0 TO LEN(cartesian,0)-1 DO
				FOR y:=0 TO LEN(cartesian,1)-1 DO
					FOR z:=0 TO LEN(cartesian,2)-1 DO
						Solid(transform*V.CastVector(x,y,z,1.0), found, cartesian[x,y,z]);
					END;
				END;
			END;
		END CastSolid;
*)		
		(*cast surfaces into cartesian volumetric dataset*)
		PROCEDURE CastSurfaces;
		BEGIN
			HALT(200);
			(* overall surface info can be collected by
				Set object to refractive and partially transparent, and activate "Shape.SetHitRegistration(TRUE,FALSE)".
				Then do the rendering. 
				At the end of the rendering,  Shape.hitList will contain a list of hits, each coming with location of hit and the normal vector at that location.
				Now fill in the data you need into a cartesian cube, similar to "VolumeShape.CastVolume()"
				(inner surfaces can be eliminated by checking if the voxel of both sides of this surface is inside the shape).
			*)
		END CastSurfaces;
	END VolumeShape;

	(*  for algorithms to triangulate shapes, see als http://en.wikipedia.org/wiki/Tessellation
	one of the fastest algorithms is at G. Leach: Improving Worst-Case Optimal Delaunay Triangulation Algorithms. June 1992*)

	(* optimized sphere-triangle collision test: http://realtimecollisiondetection.net/blog/?p=103 *)
	Sphere*=OBJECT(VolumeShape)
		VAR	p0-:Coordinate;
			radius, invradius :Datatype;
			Innerp0: Datatype; (* optimisations *)

		PROCEDURE &Init*(CONST p0: Coordinate; radius:Datatype);
		BEGIN
			type:=sphereType;
			InitGeometry(p0, radius);
			SetColor(Col.white,FALSE); (*global, is propagated to children*)
			specular:=TRUE;
		END Init;
		
		PROCEDURE InitGeometry*(CONST p0: Coordinate; radius:Datatype);
		VAR b0, b1: Coordinate;
		BEGIN
			SELF.p0:=p0; SELF.radius:=radius;
			Innerp0:=p0+*p0;
			invradius:=1/radius;
			b0:=p0-V.CastVector(radius,radius,radius,0);
			b1:=p0+V.CastVector(radius,radius,radius,0);
			InitBox(box, b0, b1) ;
			box.radius:=radius; (*bounding sphere is smaller than bounding box*)
		END InitGeometry;
		
		PROCEDURE Transform*(CONST t: AffineTransform);
		BEGIN
			p0:=t*p0;
			Transform^(t);
			InitBox(box, MIN(box.p0,p0), MAX(box.p1,p0)) ;
			box.radius:=radius+threshold; (*bounding sphere is smaller than bounding box*)
		END Transform;
		
		PROCEDURE Inside*(CONST P:Coordinate):BOOLEAN;
		BEGIN
			RETURN V.InnerSquareDiff(P,p0) <= radius*radius
		END Inside;

		PROCEDURE Intersect*(CONST line:Ray0; VAR shape: Shape; VAR distance: Datatype; VAR intersection:Coordinate; VAR Normal: Vector; VAR color:Color):BOOLEAN; (*res: linked list of intersection points and surface Normals*)
		(*for implementation, see http://local.wasp.uwa.edu.au/~pbourke/geometry/sphereline/ *) (*performance bottleneck for molecule rendering*)
		VAR	a,b,c,d,u:Datatype; hit:Hit; 
		BEGIN
			(* a := line.Innerdp*)
			b := 2* (line.dp +* (SELF.p0-line.p0)); 
			(* optional square root free admission test; similar /redundant function to what follows after d:=sqrt(d) below; *)
				IF 0.5*b > distance+radius THEN RETURN FALSE END; (*optional admission test  avoiding square root - might be useful if many spheres are hidden*)
			(*end option *)
			c := - (SELF.p0+*line.p0)*2 +  Innerp0 + line.Innerp0 - radius*radius;
			d := b*b-4*line.Innerdp*c;
			IF d<0 THEN RETURN FALSE
			(*ELSIF d=0 THEN (* tangent - might be handled separately, e.g. antialiasing*)*)
			ELSE
				 (*original version*)
				d:=Mathe.sqrt(d);(* can square root be avoided or postponed here for performance ?  *)
				u:=MIN(b + d,b - d )* 0.5* line.InvInnerdp; (* which of the 2 intersections is  nearer ?*) (*! to do: d is always positive => second option is always smaller...*)
				IF u<threshold THEN u:=MAX(b + d,b - d )* 0.5* line.InvInnerdp; END; (* in refractive objects, ray may start inside, and "nearer" intersection is retrograde ..*)
				IF (u >= distance) OR (u<=threshold) THEN (* the latter is needed to find exit site of refractive objects*) 	(*to do: implement refractive objects here *)
					RETURN FALSE (* intersects in principle, but behind other structure *)
				ELSE
					intersection:=line.p0 + u*line.dp;(*intersection:=V.MulAdd(line.p0, line.dp, u);*) (*currently no overall speedup seen of current SSE MulAdd implementation not using FMA3*)
					(*IF (world#NIL)&(world.cutout#NIL) & world.cutout.Inside(intersection) THEN RETURN FALSE END;  (*! work in progress  *)*)
					shape:=SELF;
					distance:=u;
					Normal:=invradius * (intersection-p0);
					color:=ColorAt(intersection); 
					IF registerHits THEN RegisterHit(line,distance,intersection,Normal,color) END;
					RETURN TRUE;
				END;			
			END;
			
		END Intersect;
		
		PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN;
		BEGIN
			RETURN ABS((p0-plane.p) +* plane.normal) <= radius
		END PlaneIntersectCandidate;

	END Sphere;

	Cylinder*=OBJECT(VolumeShape);
		VAR axis: Ray0; radius:Datatype;

		PROCEDURE &Init*(CONST p0,p1:Coordinate; radius: Datatype);
		BEGIN
			type:=cylinderType;
			InitGeometry(p0,p1,radius);
			SetColor(Col.white,FALSE); (*global, is propagated to children*)
			specular:=TRUE
		END Init;
		
		PROCEDURE InitGeometry*(CONST p0,p1:Coordinate; radius: Datatype);
		VAR r: Vector;
		BEGIN
			axis.p0:=p0; axis.p1:=p1; 
			axis.dp:=V.Normalize(p1-p0);
			SELF.radius:=radius;
			r:=V.CastVector(radius,radius,radius,0);
			InitBox(box,MIN(p0,p1)-r, MAX(p0,p1)+r );
		END InitGeometry;
		
		PROCEDURE Transform*(CONST t: AffineTransform); (*?to consider: radius is not transformed here => affine transfor m not consistent in all cases*)
		VAR tp0,tp1: Coordinate;
		BEGIN
			Transform^(t);
			tp0:=t*axis.p0; tp1:=t*axis.p1;
			InitGeometry(tp0, tp1, radius); 
		END Transform;
		
		PROCEDURE Inside*(CONST P:Coordinate):BOOLEAN; (*untested*)
		VAR l: Datatype; v:Vector;
		BEGIN
			v:= (P-axis.p0)* axis.dp;
			IF v+*v > radius*radius THEN RETURN FALSE
			ELSE
				l:=axis.dp +* (P-axis.p0); 
				(*RETURN (l>=0)&(l<=V.Length(axis.p1-axis.p0))*)
				
				v:=axis.p1-axis.p0; (*optimized: eliminate Length()*)
				RETURN (l>=0)&(l*l <= v+*v)
			END
		END Inside;
		
		(* strategy: use rectangular triangle equality for triangle A,B,C, where A=base of cylinder axis, C= intersection with camera beam, B= its projection on the axis;
		 AC can be described as a path from A, to the camera beam start D, plus x times the camera vector.
		 Resolving for x leads to a quadratic formula given below, with either 2, 1 or zero solutions, corresponding to line-cylinder intersection points. *) 
		PROCEDURE Intersect*(CONST line:Ray0; VAR shape:Shape; VAR distance: Datatype; VAR intersection:Coordinate; VAR Normal: Vector; VAR color:Color):BOOLEAN; (*res: linked list of intersection points and surface Normals*)
			VAR Poc: Vector;
				B0,B1,intersection0, intersection1: Coordinate;
				McMo, PocMc: Datatype;
				a,b,c,  t0,t1, invk:Datatype;
				hits: SET;
				hit:Hit;
		BEGIN
			(*IF ~RayIntersectCandidate(line) THEN RETURN FALSE END; (* use preferentially if it is negative in sufficient cases*)*)
			(*Precondition: axis.dp, line.dp is normalized *)
			McMo := axis.dp +* line.dp;
			Poc := line.p0-axis.p0;
			PocMc := Poc+* axis.dp;
			invk := 1/(1 -McMo*McMo);	
			a := 1;
			b:=  (Poc+*line.dp -PocMc*McMo)*2*invk;
			c := (Poc+*Poc - PocMc*PocMc - radius*radius ) *invk;
			IF ~ Quadratic (b,c, t0, t1)  THEN RETURN FALSE
			ELSIF MIN(t0,t1)>distance THEN RETURN FALSE
			ELSIF MAX(t0,t1)<threshold THEN RETURN FALSE
			END;
			
			intersection0 := line.p0 + t0 * line.dp;
			B0:=((intersection0- axis.p0)+* axis.dp )* axis.dp;
			IF B0+* (axis.p1-axis.p0-B0)>=0 THEN (* inside cylinder *) INCL(hits,0) END; 
			
			intersection1 := line.p0 + t1 * line.dp;
			B1:= ((intersection1-axis.p0)+* axis.dp) * axis.dp; 
			IF B1+* (axis.p1-axis.p0-B1)>=0 THEN (* inside cylinder *) INCL(hits,1) END; 
			
			IF (hits={0,1})  & (t0<distance) &(t0>threshold) & ((t0<=t1)OR(t1<threshold))	
																				THEN shape:=SELF; distance:=t0; intersection:= intersection0; Normal := V.Normalize(intersection - B0-axis.p0);color := ColorAt(intersection);
			ELSIF (hits={0,1}) & (t1<distance) &(t1>threshold) 				THEN shape:=SELF; distance:=t1; intersection:= intersection1; Normal := V.Normalize(intersection - B1-axis.p0); color := ColorAt(intersection);
			ELSIF (hits={0})   & (t0<distance) &(t0>threshold) 				THEN shape:=SELF; distance:=t0; intersection:= intersection0; Normal := V.Normalize(intersection - B0-axis.p0); color := ColorAt(intersection);
			ELSIF (hits={1})   & (t1<distance) &(t1>threshold)				THEN shape:=SELF; distance:=t1; intersection:= intersection1; Normal := V.Normalize(intersection - B1-axis.p0); color := ColorAt(intersection);
			ELSE  RETURN FALSE;
			END;
			IF registerHits THEN RegisterHit(line, distance, intersection,Normal,color) END;
			RETURN TRUE
			
		END Intersect;
		(*
		PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN;
		BEGIN
			RETURN TRUE
		END PlaneIntersectCandidate;
		*)
		(* cylinder-cylinder intersection: http://www.geometrictools.com/Documentation/IntersectionOfCylinders.pdf *)
		(* cylinder-triangle intersection: http://www.geometrictools.com/Documentation/IntersectionTriangleCylinder.pdf *)
		
	END Cylinder;
	
	(* torus: see
	http://users.wowway.com/~phkahler/torus.pdf
	http://herakles.zcu.cz/~skala/PUBL/PUBL_2013/2013_Torus-Line-Intersection.pdf
	*)
	TYPE Torus= OBJECT
	END Torus;
	
	(* Coordinates of regular tetrahedron
	    (+1, +1, +1);
	    (-1, -1, +1);
	    (-1, +1, -1);
	    (+1, -1, -1).
	*)
	Tetrahedron*=OBJECT(VolumeShape);
		VAR p0,p1,p2,p3: Coordinate;
		PROCEDURE &Init*(CONST p0,p1,p2,p3:Coordinate);
		VAR T:Triangle; 
		BEGIN
			type:=tetrahedronType;
			box:=emptyBox;
			InitGeometry(p0,p1,p2,p3);
			SetColor(Col.white,FALSE); (*global, is propagated to children*)
			NEW(T,p0,p1,p2); AddChild(T); (* can assign individual color to facets  if desired*)
			NEW(T,p1,p3,p2); AddChild(T);
			NEW(T,p3,p1,p0); AddChild(T);
			NEW(T,p2,p3,p0); AddChild(T);
		END Init;
		
		PROCEDURE InitGeometry*(CONST p0,p1,p2,p3:Coordinate);
		BEGIN
			SELF.p0:=p0; SELF.p1:=p1; SELF.p2:=p2; SELF.p3:=p3;
			InitBox(box,MIN(box.p0, MIN(p0,MIN(p1,MIN(p2,p3)))), MAX(box.p1,MAX(p0, MAX(p1, MAX(p2, p3))))); (* is adapted below in AddChild()  or Transform())*)
		END InitGeometry;
		
		PROCEDURE SetColors*(CONST c0,c1,c2,c3: Color);
		VAR c:Shape;
		BEGIN
			c:=child;
			c.SetColor(c0,TRUE); c:=c.next; c.SetColor(c1,TRUE); c:=c.next;
			c.SetColor(c2,TRUE); c:=c.next; c.SetColor(c3,TRUE); c:=c.next;
		END SetColors;
		
		PROCEDURE Transform*(CONST t: AffineTransform);
		BEGIN
			Transform^(t);
			InitGeometry(t*p0, t*p1, t*p2, t*p3); 
		END Transform;
	
		PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN;
		VAR v:Vector;
		BEGIN
			v:=V.CastVector(((p0-plane.p) +* plane.normal), ((p1-plane.p) +* plane.normal), ((p2-plane.p) +* plane.normal), ((p3-plane.p) +* plane.normal));
			(*v:= [((p0-plane.p) +* plane.normal), ((p1-plane.p) +* plane.normal), ((p2-plane.p) +* plane.normal), ((p3-plane.p) +* plane.normal)];*) (*to do: use inlined SameSign() procedure *)
			IF (v <=Zero4) OR (Zero4<=v) THEN RETURN FALSE ELSE RETURN TRUE END;
		END PlaneIntersectCandidate;
		
		PROCEDURE Inside*(CONST P:Coordinate):BOOLEAN; (* to do: optimize*)
		VAR n0, n1,n2,n3, v: Vector;
		BEGIN
			IF (P>=box.p0) & (P<=box.p1) THEN
				n0:=(p1-p0)*(p2-p0);
				n1:=(p2-p0)*(p3-p0);
				n2:=(p3-p0)*(p1-p0);
				n3:=(p3-p1)*(p2-p1);
				v:=V.CastVector((P-p0)+*n0, (P-p0)+*n1, (P-p0)+*n2, (P-p1)+*n3);
				RETURN (v <=0) OR (0<=v)
			ELSE RETURN FALSE
			END;
		END Inside;
		
	END Tetrahedron;

	(*are platonic bodies regular enough to be implemented, or do them outside basis module ?
	The following Cartesian coordinates define the vertices of an icosahedron with edge-length 2, centered at the origin:
	    (0, ±1, ±phi)
	    (±1, ±phi, 0)
	    (±phi, 0, ±1)
	where phi = (1+sqrt(5))/2 is the golden ratio.

	Icosahedron*=OBJECT(VolumeShape);
	BEGIN
	END Icosahedron;
	*)

	(*concept of Patch:
				- parent grid is organized into B-Tree of submatrices; at size 2*2, a submatrix defines child triangles
				- non-displayed nodes/triangles have coordinates [x,y,z,NaN];
				- triangulate rectangles at lowest level.
				- a ray may hit a number of facettes, so take care with the tree traversal strategy
				- leaf triangles are unaware of their neighbours, i.e. no edge normal vectors available for Phong etc
				- an optional, nondisplayd border padding, neccessary for computing edge normals in Phong shading)*)
	Patch*=OBJECT(VolumeShape);  (*not yet fully working*)
		CONST minimalSize=2;
		VAR padding:SIGNED32;
			showNormals*:BOOLEAN;

		(* triangles: optional export of child objects in 2D array. If desired, a triangle array of correct size must be allocated before NEW(patch, ......)  *)
		PROCEDURE &Init*(CONST grid: ARRAY [*,*,*] OF Datatype; padding: SIGNED32; VAR triangles: ARRAY[*,*,2] OF Triangle);
		VAR c0,c1,c2,c3,ctmp: Coordinate; du,dv,n0,n1,n2,n3,n4,n5:Vector; x,y:SIZE; patch:Patch; triangle0,triangle1: Triangle; dot:Dot;
		BEGIN	
			type:=patchType;
			InitBox(box,FarPlus,FarMinus);
			SELF.padding:=padding;
			IF (LEN(grid,0)<minimalSize+2*padding) OR (LEN(grid,1)<minimalSize+2*padding) THEN leaf:=TRUE; HALT(298);
			ELSIF (LEN(grid,0)=minimalSize+2*padding) & (LEN(grid,1)=minimalSize+2*padding)  THEN
				c0:=grid[padding,padding]; c1:=grid[padding,padding+1]; c2:=grid[padding+1,padding]; c3:=grid[padding+1,padding+1];
				IF (c0[3]=NaN) OR (c1[3]=NaN) OR (c2[3]=NaN) THEN triangle0:=NIL; (* skip inexistent triangles*)
				ELSE NEW(triangle0,c0,c1,c2) ; triangle0.specular:=FALSE;
				END;
				IF (c1[3]=NaN) OR (c2[3]=NaN) OR (c3[3]=NaN) THEN triangle1:=NIL;(* to do: subdivide square differently if only one common edge is missing*)
				ELSE NEW(triangle1,c2,c1,c3); triangle1.specular:=FALSE;
				END;
				
				IF padding>0 THEN(*padding currently needed for edge normals computation*)
			(*00*)	IF grid[padding,padding-1,3]=1 THEN du:=(grid[padding,padding+1]-grid[padding,padding-1])/2 ELSE (*scaling unnecessary, as normalized later*); 
														  du:=grid[padding,padding+1]-grid[padding,padding ]END;
			(*00*)	IF grid[padding-1,padding,3]=1 THEN dv:=(grid[padding+1,padding]-grid[padding-1,padding])/2 ELSE 
														  dv:=grid[padding+1,padding]-grid[padding,padding] END;
					IF (du=[0,0,0,0]) OR(dv=[0,0,0,0]) THEN n0:=[0,0,0,NaN] ELSE n0:=V.Normalize(du*dv) END;	
					
					
			(*01*)	IF grid[padding,padding+2,3]=1 THEN du:=(grid[padding,padding+2]-grid[padding,padding])/2; ELSE 
														du:=grid[padding,padding+1]-grid[padding,padding]; END;
			(*01*)	IF grid[padding-1,padding+1,3]=1 THEN dv:=(grid[padding+1,padding+1]-grid[padding-1,padding+1])/2; ELSE 
														dv:=grid[padding+1,padding+1]-grid[padding,padding+1];  END;
					IF (du=[0,0,0,0]) OR(dv=[0,0,0,0]) THEN n1:=[0,0,0,NaN] ELSE n1:=V.Normalize(du*dv) END;					
					
					
			(*10*)	IF grid[padding+1,padding-1,3]=1 THEN du:=(grid[padding+1,padding+1]-grid[padding+1,padding-1])/2; ELSE 
														du:=grid[padding+1,padding+1]-grid[padding+1,padding]; END;
			(*10*)	IF grid[padding+2,padding,3]=1 THEN     dv:=(grid[padding+2,padding]-grid[padding,padding])/2; ELSE 
														dv:=grid[padding+1,padding]-grid[padding,padding]; END;
					IF (du=[0,0,0,0]) OR(dv=[0,0,0,0]) THEN n2:=[0,0,0,NaN] ELSE n2:=V.Normalize(du*dv) END;
					
					
			(*11*)	IF grid[padding+1,padding+2,3]=1 THEN du:=(grid[padding+1,padding+2]-grid[padding+1,padding])/2; ELSE 
														du:=grid[padding+1,padding+1]-grid[padding+1,padding];  END;
			(*11*)	IF grid[padding+2,padding+1,3]=1 THEN dv:=(grid[padding+2,padding+1]-grid[padding,padding+1])/2;ELSE 
														dv:=grid[padding+1,padding+1]-grid[padding,padding+1]; END;
					IF (du=[0,0,0,0]) OR(dv=[0,0,0,0]) THEN n3:=[0,0,0,NaN] ELSE n3:=V.Normalize(du*dv) END;
					n4:=n1; 
					n5:=n2;
				END;
				IF triangle0#NIL THEN  
					triangle0.SetEdgeNormals(n0,n1,n2); 
					AddChild(triangle0); 
					triangle0.color:=Col.yellow;
					triangle0.interpolation:=PhongInterpolation(* NoInterpolation  *);
					
					(* set triangle edge normals  for Phong interpolation *)
					IF showNormals THEN
						ctmp:=c0+c1+c2; ctmp:=1/3*ctmp; ctmp:=ctmp+0.1*triangle0.Normal; NEW(dot,ctmp,0.01); dot.SetColor(Col.red,FALSE); AddChild(dot);
						ctmp:=c0+0.1*triangle0.Na; NEW(dot,ctmp,0.01); dot.SetColor(Col.blue,FALSE); AddChild(dot);
						ctmp:=c1+0.1*triangle0.Nb; NEW(dot,ctmp,0.01); dot.SetColor(Col.green,FALSE); AddChild(dot);
						ctmp:=c2+0.1*triangle0.Nc; NEW(dot,ctmp,0.01); dot.SetColor(Col.yellow,FALSE); AddChild(dot);
					END;
					IF LEN(triangles,0)>0 THEN triangles[padding,padding,0]:=triangle0; END; 
				END;
				IF triangle1#NIL THEN
					triangle1.SetEdgeNormals(n2,n1,n3); 
					AddChild(triangle1); 
					triangle1.interpolation:=PhongInterpolation;

					IF showNormals THEN
						ctmp:=c3+c1+c2; ctmp:=1/3*ctmp; ctmp:=ctmp+0.12*triangle1.Normal; NEW(dot,ctmp,0.008); dot.SetColor(Col.red,FALSE); AddChild(dot);
						ctmp:=c2+0.12*triangle1.Na; NEW(dot,ctmp,0.008); dot.SetColor(Col.yellow,FALSE); AddChild(dot);
						ctmp:=c1+0.12*triangle1.Nb; NEW(dot,ctmp,0.008); dot.SetColor(Col.green,FALSE); AddChild(dot);
						ctmp:=c3+0.12*triangle1.Nc; NEW(dot,ctmp,0.008); dot.SetColor(Col.gray,FALSE); AddChild(dot);
					END;
					IF LEN(triangles,0)>0 THEN triangles[padding,padding,1]:=triangle1; END;
				END;
				leaf:=TRUE;
			ELSIF LEN(grid,0)>LEN(grid,1) THEN (*split along Y *)
				y:=(LEN(grid,0)+1) DIV 2-1;
				IF LEN(triangles,0)>0 THEN
					NEW(patch, ALIAS OF grid[..y+padding, ..],padding, triangles[..y+padding, ..]); AddChild(patch);
					NEW(patch, ALIAS OF grid[y-padding.., ..],padding, triangles[y-padding.., ..]); AddChild(patch);
				ELSE
					NEW(patch, ALIAS OF grid[..y+padding, ..],padding, triangles[.., ..]); AddChild(patch);
					NEW(patch, ALIAS OF grid[y-padding.., ..],padding, triangles[.., ..]); AddChild(patch);
				END;
				leaf:=FALSE;
			ELSE (*ELSIF LEN(grid,1)>minimalSize+2*padding  THEN*)(*split along X *)
				x:=(LEN(grid,1)+1) DIV 2-1;
				IF LEN(triangles,0)>0 THEN
					NEW(patch, ALIAS OF grid[..,..x+padding],padding, triangles[..,..x+padding]); AddChild(patch);
					NEW(patch, ALIAS OF grid[..,x-padding..],padding, triangles[..,x-padding..]); AddChild(patch);
				ELSE
					NEW(patch, ALIAS OF grid[..,..x+padding],padding, triangles[..,..]); AddChild(patch);
					NEW(patch, ALIAS OF grid[..,x-padding..],padding, triangles[..,..]); AddChild(patch);
				END;
				leaf:=FALSE;
			END;
			SetColor(Col.white,FALSE); (*global, is propagated to children*)

		END Init;
		
		PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN; 
		BEGIN
			RETURN TRUE
		END PlaneIntersectCandidate;
		
		(*
		PROCEDURE GetHits;
		END GetHits;
		*)
			
	END Patch;
	
TYPE Region=OBJECT
	VAR u0,v0,u1,v1: SIZE; (* index of region boundary in parent map*)
			box: Box;	(* axis-aligned boundary box *)
			r0,r1: Region; (* binary tree of child regions *)
			leaf: Quadrangle; (* if this is a terminal leaf of size 1x1, it has a Quadrangle associated. This may change with a future implementation *)
			PROCEDURE &Init(u0, v0, u1,v1:SIZE);
			BEGIN
				SELF.u0:=u0; SELF.u1:=u1; SELF.v0:=v0; SELF.v1:=v1;
			END Init;
		END Region;

TYPE PatchB= OBJECT(VolumeShape); 
		VAR 
		map: Map;
		regions: Region;
		count:SIZE;
		log:Streams.Writer;
		
		PROCEDURE &Init(CONST map: Map; log:Streams.Writer);
		VAR mi,ma:Coordinate;
		BEGIN
			SELF.map:=map;
			SELF.log:=log;
			NEW(regions, 0, 0, LEN(map,0)-1, LEN(map,1)-1); 
			GetRegionTree(regions);
			mi:=Min(map); ma:=Max(map);
			InitBox(box, mi,ma);
			type:=patchType;
		END Init;
		
		PROCEDURE Min(CONST m: Map):Coordinate;
		VAR i,j:SIZE; min: Coordinate;
		BEGIN
			min:=MAX(FLOAT32);
			FOR i:=0 TO LEN(m,0)-1 DO
				FOR j:=0 TO LEN(m,1)-1 DO
					min:=MIN(min,map[i,j]); 
				END;
			END;
			RETURN min
		END Min;

		PROCEDURE Max (CONST m:Map):Coordinate	;
		VAR i,j:SIZE; max:Coordinate;
		BEGIN
			max:=MIN(FLOAT32);
			FOR i:=0 TO LEN(m,0)-1 DO
				FOR j:=0 TO LEN(m,1)-1 DO
					max:=MAX(max,map[i,j]); 
				END;
			END;
			RETURN max
		END Max;

		PROCEDURE GetRegionTree(region:Region);
		VAR r:Region; 
		BEGIN
			IF (region.u1-region.u0 =1)&(region.v1-region.v0=1) THEN (* ... done *) 
			ELSIF region.u1-region.u0>region.v1-region.v0 THEN
				NEW(r, region.u0, region.v0, region.u0+(region.u1-region.u0) DIV 2, region.v1); 
				r.box.p0:=Min(map[r.u0..r.u1,r.v0..r.v1]); r.box.p1:=Max(map[r.u0..r.u1,r.v0..r.v1]); GetRegionTree(r);
				region.r0:=r;
				NEW(r, region.u0+(region.u1-region.u0) DIV 2, region.v0, region.u1, region.v1);
				r.box.p0:=Min(map[r.u0..r.u1,r.v0..r.v1]); r.box.p1:=Max(map[r.u0..r.u1,r.v0..r.v1]); GetRegionTree(r);
				region.r1:=r;
			ELSIF (region.u1-region.u0<region.v1-region.v0) OR (region.v1-region.v0>1) THEN
				NEW(r, region.u0, region.v0, region.u1, region.v0+(region.v1-region.v0) DIV 2);
				r.box.p0:=Min(map[r.u0..r.u1,r.v0..r.v1]); r.box.p1:=Max(map[r.u0..r.u1,r.v0..r.v1]); GetRegionTree(r);
				region.r0:=r;
				NEW(r, region.u0, region.v0+(region.v1-region.v0) DIV 2, region.u1, region.v1);
				r.box.p0:=Min(map[r.u0..r.u1,r.v0..r.v1]); r.box.p1:=Max(map[r.u0..r.u1,r.v0..r.v1]); GetRegionTree(r);
				region.r1:=r;
			ELSE HALT(200); 
			END;
		END GetRegionTree;
		
		PROCEDURE Intersect*(CONST line:Ray0; VAR shape: Shape; VAR distance: Datatype; VAR intersection: Coordinate; VAR normal: Vector; VAR color:Color):BOOLEAN; (*method for container objects*)
		(*VAR hitRegion:Region;*)
		BEGIN
			RETURN Intersect0(line, regions, shape, (*hitRegion,*) distance, intersection,normal, color)
		END Intersect; 

		PROCEDURE Intersect0(CONST line:Ray0; r:Region; VAR shape: Shape; VAR distance: Datatype; VAR intersection: Coordinate; VAR normal: Vector; VAR color:Color):BOOLEAN; (*method for container objects*)
		VAR res0,res1:BOOLEAN;  A,B,C,D, intersection0, normal0:Coordinate; distance0:Datatype; color0:Color;
		BEGIN
			IF r.leaf=NIL THEN
				A:=map[r.u0,r.v0,..]; B:=map[r.u1,r.v0]; C:= map[r.u1,r.v1]; D:= map[r.u0,r.v1]; 
				NEW(r.leaf, A,B,C,D); r.leaf.SetColor(Col.red,TRUE);
			END;
			distance0:=distance;
			IF ~r.leaf.Intersect(line, shape, distance0, intersection0, normal0, color0) THEN 
				RETURN FALSE
			ELSE
				INC(count);
				shape:=SELF;
				(*hitRegion:=r;*)
				IF (r.r0#NIL) THEN res0:= Intersect0(line, r.r0, shape, distance, intersection, normal, color) END;
				IF (r.r1#NIL) THEN res1:= Intersect0(line, r.r1, shape, distance, intersection, normal, color) END;
				IF ~res0 & ~res1 THEN distance:=distance0; intersection:=intersection0; normal:=normal0; color:=color0 END;
				RETURN TRUE
			END;
		END Intersect0;		
	
		PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN; 
		BEGIN
			RETURN TRUE
		END PlaneIntersectCandidate;
		
	END PatchB;

	Block*=OBJECT(VolumeShape);	(* 6-sided block. each 4-angled side is composed from 2 triangles*) (* to do: reorder point enumeration so that they follow the order of axes... *)
		VAR p0,p1,p2,p3,p4,p5,p6,p7: Coordinate;
		PROCEDURE &Init*(CONST p0,p1,p2,p3, p4,p5,p6,p7:Coordinate);
		VAR T:Triangle; 
		BEGIN
			type:=blockType;
			InitGeometry(p0,p1,p2,p3, p4,p5,p6,p7);
			SetColor(Col.white,FALSE); (*global, is propagated to children*)
			NEW(T,p0,p2,p1); AddChild(T); (* can assign individual color to facets  if desired*)
			NEW(T,p2,p0,p3); AddChild(T);
			NEW(T,p1,p6,p5); AddChild(T);
			NEW(T,p6,p1,p2); AddChild(T);
			NEW(T,p3,p6,p2); AddChild(T);
			NEW(T,p6,p3,p7); AddChild(T);
			NEW(T,p5,p7,p4); AddChild(T);
			NEW(T,p7,p5,p6); AddChild(T);
			NEW(T,p7,p0,p4); AddChild(T);
			NEW(T,p0,p7,p3); AddChild(T);
			NEW(T,p0,p5,p4); AddChild(T);
			NEW(T,p5,p0,p1); AddChild(T);
		END Init;
		
		PROCEDURE InitGeometry*(CONST p0,p1,p2,p3, p4,p5,p6,p7:Coordinate);
		BEGIN
			SELF.p0:=p0; SELF.p1:=p1; SELF.p2:=p2; SELF.p3:=p3; SELF.p4:=p4; SELF.p5:=p5; SELF.p6:=p6; SELF.p7:=p7;
			InitBox(box,p0,p0); (* is adapted in AddChild(), or in Transform() *) 
		END InitGeometry;
		
		PROCEDURE SetColors*(CONST c0,c1,c2,c3,c4,c5: Color);
		VAR c:Shape;
		BEGIN
			c:=child;
			c.SetColor(c0,TRUE); c:=c.next; c.SetColor(c0,TRUE); c:=c.next;
			c.SetColor(c1,TRUE); c:=c.next; c.SetColor(c1,TRUE); c:=c.next;
			c.SetColor(c2,TRUE); c:=c.next; c.SetColor(c2,TRUE); c:=c.next;
			c.SetColor(c3,TRUE); c:=c.next; c.SetColor(c3,TRUE); c:=c.next;
			c.SetColor(c4,TRUE); c:=c.next; c.SetColor(c4,TRUE); c:=c.next;
			c.SetColor(c5,TRUE); c:=c.next; c.SetColor(c5,TRUE); c:=c.next;
		END SetColors;
		
		PROCEDURE Transform*(CONST t: AffineTransform);
		VAR b0,b1:Coordinate;
		BEGIN
			Transform^(t); (* children are transformed, box is adapted*)
			p0:=t*p0; b0:=p0; b1:=p0; 
			p1:=t*p1;
			p2:=t*p2;
			p3:=t*p3;
			p4:=t*p4; 
			p5:=t*p5; 
			p6:=t*p6; 
			p7:=t*p7; 
		END Transform;
	
	PROCEDURE PlaneIntersectCandidate(CONST plane:Plane0):BOOLEAN;
		VAR v0,v1:Vector;
		BEGIN
			v0:=V.CastVector(((p0-plane.p) +* plane.normal), ((p1-plane.p) +* plane.normal), ((p2-plane.p) +* plane.normal), ((p3-plane.p) +* plane.normal));
			v1:=V.CastVector(((p4-plane.p) +* plane.normal), ((p5-plane.p) +* plane.normal), ((p6-plane.p) +* plane.normal), ((p7-plane.p) +* plane.normal));
			IF (v0 <=Zero4)&(v1 <=Zero4) OR (Zero4<=v0)&(Zero4<=v1) THEN RETURN FALSE ELSE RETURN TRUE END;
		END PlaneIntersectCandidate;
		
	PROCEDURE Inside*(CONST P:Coordinate):BOOLEAN; (* to do: optimize*)
		BEGIN
			RETURN 
				(P>=box.p0) & 
				(P<=box.p1) &
				(* assuming p0,p1,p2,p3 in one plane and p4,p5,p6,p7 in opposite plane*)
				(InsideTetrahedron(P, p0,p1,p2,p5) OR
				InsideTetrahedron(P, p0,p5,p2,p6) OR
				
				InsideTetrahedron(P,p0,p2,p6,p3) OR
				InsideTetrahedron(P,p0,p3,p6,p7) OR
				
				InsideTetrahedron(P,p0,p4,p5,p6) OR
				InsideTetrahedron(P,p0,p4,p6,p7))
		END Inside;
		
	END Block;
	
	(* rectangular, axis-aligned block, for bricks, beams, plates etc *)
	TYPE  Brick*= OBJECT (Block);
			PROCEDURE &Initialize*(dx, dy, dz: Datatype);
			BEGIN
				Init([0,dy,dz,1], [dx,dy,dz,1], [dx,0,dz,1], [0,0,dz,1], 
					[0,dy,0,1], [dx,dy,0,1], [dx,0,0,1], [0,0,0,1]); 
				type:=brickType;
			END Initialize;	
		END Brick;
		
	(*
	TYPE Cone=..
	END Cone;
	
	TYPE Hyperboloid=..
	END Hyperboloid;
	
	TYPE Torus=..
	END Torus;
	*)

	(* for specular illumination: phong illumination is slow and nonphysical;
	  Schlick illumination is faster and physical :  http://en.wikipedia.org/wiki/Schlick%27s_approximation: R(theta) = R0 + (1 - R0)(1 - cos (theta))5  *)
	(* see also A Survey of Shading Models for Real-time Rendering Karsten Schwenk 2008 *)
	(*  see also http://en.wikipedia.org/wiki/Bidirectional_reflectance_distribution_function *)
	(* see also comparison of gourod and phong shading pseudocodes at http://www.nbb.cornell.edu/neurobio/land/OldStudentProjects/cs490-95to96/guo/report.html *)

	Light*=OBJECT
		VAR
			T0,T*:AffineTransform;
			location: Coordinate;
			Dynamic*: DynamicTransform;
			world:World;
			brightness*: Datatype;
			lightColor*: Color;
			divergent*: BOOLEAN;
			next*: Light;

		PROCEDURE Default*;
		BEGIN
			T:=[[Mathe.cos(alpha)*Mathe.cos(theta),-Mathe.sin(alpha),Mathe.sin(theta),-1],
				[Mathe.sin(alpha),Mathe.cos(alpha),0,1],
				[-Mathe.sin(theta),0,Mathe.cos(theta),1],
				[0,0,0,1]];
			T0:=T;
			location:=T[..,3];
			Dynamic:=Dynamic0;
			SetTime;
			divergent := FALSE; (* divergent is point source, nondivergent is parallel light*)
			brightness := 0.4;
			lightColor[0]:=0FFX; lightColor[1]:=0FFX; lightColor[2]:=0FFX; lightColor[3]:=0FFX;
		END Default;

		PROCEDURE SetTransform*(CONST T:AffineTransform);
		BEGIN
			T0:=T; SELF.T:=T; location:=T[..,3]
		END SetTransform;
		
		PROCEDURE SetTime;
		BEGIN
			T:=Dynamic(T0, world.time);
			location:=T[..,3]
		END SetTime;

		PROCEDURE AddLight*(CONST T:AffineTransform; CONST color:Color; brightness: Datatype; divergent: BOOLEAN);
		VAR light:Light;
		BEGIN
			NEW(light);
			light.world:=world;
			light.Dynamic:=Dynamic;
			light.T:=T; light.location:=T[..,3];
			light.lightColor:=color;  light.brightness:=brightness; 
			light.divergent:=divergent; 
			light.next:=next; next:=light; 
		END AddLight;

		PROCEDURE Diffuse*(CONST objectlocation:Coordinate; CONST surfaceNormal: Vector; CONST surfaceColor:Color; CONST surfaceFinish: Finish; VAR shine: Color);
		VAR intensity: Datatype; col: Color;
		BEGIN
			intensity :=- surfaceNormal+*V.Normalize(objectlocation-location);  (*light incidence*)
			IF intensity<0 THEN intensity := -intensity /4 END; (* faint transparency of back illuminated surfaces *)
			IF divergent THEN (* for light sources at finite distances: decay of luminosity with square of distance*)
				intensity := intensity/((objectlocation-location)+*(objectlocation-location))
			END;
			col := lightColor * surfaceColor;	(*color mixing*)
			shine := brightness * intensity  *  col;
				(*#TODO: incorporate surfaceFinish *)
				(*#TODO: more illumination types: ambient, diffuse, directional, spot, glow, reflectivemirror, refractive, ... *)
		END Diffuse;

		PROCEDURE Specular*(CONST objectlocation:Coordinate; CONST surfaceNormal, cameraray: Vector; CONST surfaceColor:Color; CONST surfaceFinish: Finish; VAR shade: Color);
		VAR H: Vector; intensity, distance: Datatype;
		BEGIN
			distance:=V.Length(objectlocation-location);
			H:= - V.Normalize(1/distance*(objectlocation-location)+cameraray); (*; 5o make it point away from surface => negate sign *)
			intensity := H+*surfaceNormal;
			intensity:= intensity * intensity * intensity * intensity * intensity ;
			IF divergent THEN (* 	for light sources at finite distances: decay of luminosity with square of distance *)
				intensity := intensity/(distance*distance)
			END; 
			IF intensity<0 THEN intensity:=-intensity/4 END;
			shade:= brightness * intensity * lightColor; (* specular light component has all color components of the light source, even on mono-colored materials *)
		END Specular;
		(*
		N is the surface normal at P,
		T and B are the primary and secondary tangents.
		L is a unit vector pointing in the direction of the light,
		V is a unit direction vector pointing towards the view position, and
		H is the unit angular bisector of them. Finally, I will
		substitute the absolute radiometric quantity L with some abstract Intensity I that takes values approximately in the range [0..1].
		Specularance = DiffuseSpecularion plus SpecularSpecularion
		whereby SpecularSpecularion = SmoothnessDependentFactor  + FresnellTerm + SpecularTerm

		PROCEDURE ShaderSchwenk;
		BEGIN
			s:=smoothness; [0..1]
			m:=metal_likeness; [0..1]
			C:=color;
			L := ;
			V:=;
			H:=Normalize (V+L);
			N:=;
			kd:=1; ks:=1; k:=0; (* parametrization in the range [0..1] *)
			C0:= C/lum(C); (* scale color by its luminance to correct for darkening ... *)
			F0 := (1 - m)1 + mC0  (*:= mC0 - m + 1;*) (* F0 is Fresnel coefficient at normal light incidence  *) (* m is metal-likeness *)
			u := cos (theta);
			Fresnel term in general:
			F := F(Inner(V,H), F0);
			simplest variant of Fresnel term:
			F := F0 + (1-F0) * power((1-u), 5); (* Fresnel Specularance as function of light incident angle *)
			Jd := C*(1-sk); (* Jd is diffuse term of surface reflection; C is color; s is smoothness [0..1], k is scaling factor [0..1] *)
			e:= 2/(1.00392-s); (* with s: [0..1] *)
			c := s*s / Inner(V,H);
			Js := c * F * Power(Inner(N,H), e);    (*Js is specular term of surface reflection*)
			(*full formula: *)
			I0 := Ii * Inner(N,L) * (ks *Js + kd *Jd); (*Ii = incident intensity at given wavelength or full spectrum*)
		END ShaderSchwenk;
		*)
	END Light;
	
	(** user interaction in window: 
		- x-dimension is away from user. 
		- left mousekey dragging => camera rotates in Y- or Z- dimension around world.origin
		- mouse wheel: displacement along X-axis
	  If no user interaction is desired, a normal WM.BufferWindow is sufficient for rendering.
		*)
	Window*=OBJECT(WM.BufferWindow) (*! Interactive version. Problem: updates are not yet consistent*)
		VAR 
			lastx,lasty:SIZE;
			viewer:Viewer;
		
		PROCEDURE &Init*(w, h : SIZE; alpha : BOOLEAN);
		BEGIN	
			Init^(w,h,alpha);
			SetTitle(Strings.NewString("interactive view"));
		END Init;
		
		PROCEDURE PointerDown(x,y:SIZE; keys:SET);
		VAR s:Shape;
		BEGIN
			lastx:=x; lasty:=y;
			(* if right mouse key, then produce context menu*)
			IF keys={2} THEN
				s:=viewer.FindShape(GetHeight()-1-y,x); 
				IF s#NIL THEN 
					s.selected:=~s.selected; 
					viewer.world.EnumerateShapes(FALSE,TRUE, LogShape); KernelLog.Ln;
					viewer.Render;
				END;	
			ELSE
				viewer.renderPreview:=TRUE; (*ineffective for ActiveCamera*)
				IF viewer.preview#NIL THEN viewer.currentview:=viewer.preview 
				ELSE viewer.currentview:=viewer.view 
				END;
			END;
		END PointerDown;
		
		PROCEDURE PointerMove(x,y:SIZE; keys:SET);
		VAR delta: SIZE;
		BEGIN
			IF keys={0} THEN
				viewer.abort:=TRUE;
				x:=x*viewer.step; 
				y:=y*viewer.step; (*changing image size in window may change returned mouse coordinate*)
				IF ABS(y-lasty)>ABS(x-lastx) THEN
					IF ABS(y-lasty)>3 THEN
						delta:=lasty-y; lasty:=y; lastx:=x;
						viewer.SetTransform(DynamicZAxisRot(viewer.T, delta/10));
						IF viewer IS ActiveCamera THEN viewer(ActiveCamera).SetState(rendering);
						ELSE viewer.Render;
						END;
					END;
				ELSIF ABS(x-lastx)>3 THEN
					delta:=x-lastx; lastx:=x; lasty:=y;
					viewer.SetTransform(DynamicYAxisRot(viewer.T, delta/10));
					IF viewer IS ActiveCamera THEN viewer(ActiveCamera).SetState(rendering);
					ELSE viewer.Render;
					END;					
				END
			END
		END PointerMove;
		
		PROCEDURE WheelMove(dz:SIZE);
		BEGIN
			viewer.abort:=TRUE;
			IF viewer IS ActiveCamera THEN 
				viewer.world.SetTime(viewer.world.time+dz DIV 10);
				viewer(ActiveCamera).frames:=1;
				viewer(ActiveCamera).SetState(rendering);
			ELSE
				viewer.SetTransform(viewer.T[..,3]+[dz/10,0,0,0]); (* translate along x-axis*)
				viewer.Render
			END;
		END WheelMove;
		
		PROCEDURE PointerUp(x,y:SIZE; keys:SET);
		BEGIN
			IF keys={2} THEN
			ELSE
				viewer.renderPreview:=FALSE;
				viewer.currentview:=viewer.view;
				IF viewer IS ActiveCamera THEN viewer(ActiveCamera).frames:=1; viewer(ActiveCamera).SetState(rendering);
				ELSE viewer.Render;
				END;
			END;
		END PointerUp;
		
		PROCEDURE KeyEvent*(ucs : SIZE; flags : SET; keySym : SIZE);
		VAR T: AffineTransform;
		BEGIN
			IF keySym = 0FF51H THEN (* Cursor Left *)
				viewer.abort:=TRUE; 
				Objects.Yield;
				T:=Translate(0,0, -V.Length(viewer.world.shapes.box.p1-viewer.world.shapes.box.p0)/10)*viewer.T; 
				viewer.SetTransform(T);
				viewer.renderPreview:=TRUE; (*ineffective for ActiveCamera*)
				IF viewer.preview#NIL THEN viewer.currentview:=viewer.preview 
				ELSE viewer.currentview:=viewer.view 
				END;
				viewer.Render;
				Objects.Yield;
				viewer.renderPreview:=FALSE; 
				viewer.currentview:=viewer.view ;
				viewer.Render;
			ELSIF keySym = 0FF53H THEN (* Cursor Right *)
				viewer.abort:=TRUE;
				Objects.Yield;
				T:=Translate(0,0,V.Length(viewer.world.shapes.box.p1-viewer.world.shapes.box.p0)/10)*viewer.T; 
				viewer.SetTransform(T);
				viewer.renderPreview:=TRUE; (*ineffective for ActiveCamera*)
				IF viewer.preview#NIL THEN viewer.currentview:=viewer.preview 
				ELSE viewer.currentview:=viewer.view 
				END;
				viewer.Render;
				Objects.Yield;
				viewer.renderPreview:=FALSE; 
				viewer.currentview:=viewer.view;
				viewer.Render;
			ELSIF keySym = 0FF54H THEN (* Cursor Down *)
				viewer.abort:=TRUE;
				Objects.Yield;
				T:=Translate(0, -V.Length(viewer.world.shapes.box.p1-viewer.world.shapes.box.p0)/10, 0)*viewer.T; 
				viewer.SetTransform(T);
				viewer.renderPreview:=TRUE; (*ineffective for ActiveCamera*)
				IF viewer.preview#NIL THEN viewer.currentview:=viewer.preview 
				ELSE viewer.currentview:=viewer.view 
				END;
				viewer.Render;
				Objects.Yield;
				viewer.renderPreview:=FALSE; 
				viewer.currentview:=viewer.view;
				viewer.Render;
			ELSIF keySym = 0FF52H THEN (* Cursor Up *)
				viewer.abort:=TRUE;
				Objects.Yield;
				T:=Translate(0, V.Length(viewer.world.shapes.box.p1-viewer.world.shapes.box.p0)/10, 0)*viewer.T; 
				viewer.SetTransform(T);
				viewer.renderPreview:=TRUE; (*ineffective for ActiveCamera*)
				IF viewer.preview#NIL THEN viewer.currentview:=viewer.preview 
				ELSE viewer.currentview:=viewer.view 
				END;
				viewer.Render;
				Objects.Yield;
				viewer.renderPreview:=FALSE; 
				viewer.currentview:=viewer.view;
				viewer.Render; 
			END;
		END KeyEvent;

	END Window;
	
	Viewer*=OBJECT (*base type of parallel projection and camera views*)
		VAR
			world*: World; (* link to parent world*)
			T0*,T*:AffineTransform;
			location:Coordinate;
			Dynamic*:DynamicTransform; (* drives change along time axis in time-varying model*)
			view*, currentview*: Raster.Image; 
			encoder: Codecs.ImageEncoder;
			tempLine: ARRAY[*] OF Color;
			preview*: WMGraphics.Image;
			win*: WM.BufferWindow;  (* wuold it make sense to convert the viewer into an component ?*)
			(*array*: ARRAY [*,*] OF Color;*)(* use to render into array , as analternative to rendering an image*)
			SetPixel*: PROCEDURE {DELEGATE}(CONST ray: Ray0;  col,row: SIZE; CONST shine: Color); (* render a target image *)
			rayHandler*: PROCEDURE {DELEGATE}(row,col:SIZE); (* allows differential handling of different regions of interest *)
			store*,renderPreview*,abort*,computeHash*: BOOLEAN;
			aspect:Datatype;
			beamColor*: Color; (*viewers can send out beams, e.g. for projector like functions *)(* to do: derive a "projector" from a viewer/camera*)
			nearest,farest: Datatype;
			step-, time-, ticks-, frame:SIGNED32;
			crc:CRC.CRC32;
			
		(* default view: look along X-axis, i.e.  look at world.origin [0,0,0,1] from camera location [-1,0,0,1] *)
		PROCEDURE &Default*; 
		BEGIN
			T:=Identity; T[..,3]:=[-1.01,0.002,0.003,1]; (*camera location and orientation, INCLUDING a minimal offset to avoid coincident line artifacts; can be reset if desired*)
			T0:=T;
			location:=T[..,3];
			SetPixel:=RasterSetPixel;
			Dynamic:=Dynamic0;
			SetTime;
			beamColor:=Col.white;
			frame:=0;
		END Default;

		PROCEDURE SetTime;
		BEGIN
			(*T:=Dynamic(T0, world.time);*)
			T:=Dynamic(T0, time);
			location:=T[..,3];
		END SetTime;

		PROCEDURE SetTransform*(CONST T0: ARRAY [?] OF Datatype);
		BEGIN
			IF DIM(T0)=2 THEN
				IF (LEN(T0,0)=4) & (LEN(T0,1)=4) THEN SELF.T0:=T0; T:=T0; END;
			ELSIF (DIM(T0)=1)&(LEN(T0,0) IN {3,4}) THEN SELF.T0[..2,3]:=T0[..2]; T:=SELF.T0 (* set displacement only *)
			END;
			location:=T[..,3];
		END SetTransform;

		PROCEDURE SetRaster*(img: Raster.Image);
		BEGIN
			 view:=img; currentview:=view; 
			 aspect:=img.width/img.height;
			 NEW(tempLine, img.width);
		END SetRaster;
		
		PROCEDURE CreatePreview*;
		BEGIN
			ASSERT(view#NIL,300);
			NEW(preview);
			Raster.Create(preview, view.width DIV 4, view.height DIV 4, view.fmt);
		END CreatePreview;
		
		(* If GUI interaction with the rendering is desired, assign VolumeRaytracer.Window here.
		If simple display is desired, assign a WMWindowManager.BufferWindow or WMWindowManager.DoubleBufferWindow.	*)
		PROCEDURE SetWindow*(win:WM.BufferWindow);
		BEGIN
			SELF.win:=win;
			SetRaster(win.img); (*view:=win.img;*)
			IF win IS Window THEN win(Window).viewer:=SELF END;
		END SetWindow;

		PROCEDURE RasterSetPixel*(CONST ray: Ray0; col,row: SIZE; CONST shine: Color);
		BEGIN
			Raster.Put(currentview,col,row, SYSTEM.VAL(ColorA,shine), SrcCopy);
		END RasterSetPixel;
		
		PROCEDURE InitRay*(row,col:SIZE; VAR ray:Ray0);
		END InitRay;

		PROCEDURE FindShape*(row,col: SIZE):Shape;
		END FindShape;

		(*
		PROCEDURE ArraySetPixel(col,row: SIZE; CONST shine: Color);
		BEGIN
			array[col,row]:= shine;
		END ArraySetPixel;
		*)
		PROCEDURE Render*;
		END Render;

		PROCEDURE EncodeFrame*(CONST type: ARRAY OF  CHAR; CONST writer: Streams.Writer);
		VAR res: SIGNED32;
		BEGIN
			SELF.encoder:=Codecs.GetImageEncoder(type);
			IF (encoder#NIL)&(writer#NIL) THEN
				encoder.Open(writer);
				encoder.WriteImage(view, res);
			END;
		END EncodeFrame;

	END Viewer;

	Camera*=OBJECT (Viewer) (* camera view*) (*to do: depth cues: brightness, haze *)
		VAR
			angle*: Datatype; (*viewing angle spanned by camera width*)
			Illumination*:SET;
			shadowed*: BOOLEAN;  (*! expensive option*)
			depthClue*:BOOLEAN;
			background*: Color;
			ambient*:Datatype;
			raycount*,lensraycount: SIGNED32;
			insideROI*: PROCEDURE {DELEGATE} (CONST p:Coordinate): BOOLEAN;
			next*: Camera;
			Normal:Vector;
			point:Coordinate;

		PROCEDURE &Initialize*(world:World);
		BEGIN
			SELF.world := world;
			next:=world.cameras; world.cameras:=SELF; (* prepend *)
			Default;
			background:=Col.dark;
			shadowed := TRUE;
			depthClue:=FALSE;
			Illumination:={Ambient, Diffuse, Specular};
			ambient:=0.1;
			angle:=0.5*pi; (*default camera = 90degrees wide angle camera *)
			raycount:=0;
			farest:=MIN(FLOAT32); nearest:=MAX(FLOAT32);
		END Initialize;

		PROCEDURE InitRay*(row,col:SIZE; VAR ray:Ray0);
		VAR v:Vector;
		BEGIN
			v:=V.CastVector(1, (angle*invpi*2)/aspect*(row-view.height/2)/view.height, (angle*invpi*2)*(col-view.width/2)/view.width,0);
			ray.dp:=V.Normalize(T* v);
			ray.p0:=location; 
			ray.p1 := ray.p0 + ray.dp;
			ray.Innerp0:=ray.p0+*ray.p0; (*precompute for performance *)
			ray.Innerdp:=1;  	ray.InvInnerdp:=1;
			ray.refractiveIndex:=1.0;
			INC(raycount);
		END InitRay;
		
		PROCEDURE FindShape*(row,col: SIZE):Shape;
		VAR this, shape1,shape:Shape; ray: Ray0;
			distance,distance0: Datatype; point: Coordinate; Normal: Vector; color:Color;
		BEGIN
			InitRay(row,col,ray);
			this :=world.shapes; shape := NIL;
			distance:=MAX(Datatype); distance0:=distance;
			WHILE this#NIL DO
				IF this.Intersect(ray, shape1, distance, point, Normal, color) THEN (* performance: may add candidate testing here *)
					IF (distance<distance0) THEN shape:=shape1; distance0:=distance; END;
				END;
				this:=this.next;
			END;
			RETURN shape;
		END FindShape;
		
		PROCEDURE RenderRay(CONST ray:Ray0; list0: ShapeList; VAR shine:Color );(*TBD: rendering of composite hierarchical shapes still has some problems, e.g. for cylinders as children of cylinders. For the moment, add them independently to the World for best results*)
		VAR 
			distance, distance00, distance0, distance1,distance2:Datatype;
			found1, illuminated:BOOLEAN;
			color, color0, color1, diffuse, specular,transparent, reflective: Color; finish:Finish;
			shape, shape0, shape1,shape2:Shape; 
			list: ShapeList;
			light:Light;
			ray0, ray1,ray2,ray3:Ray0;
			Normal0, Normal1:Vector;
			point0, point1:Coordinate;
			k:Datatype;
		BEGIN
			distance:=MAX(Datatype);
			shape:=NIL;
			list:=list0;
			ray1.viewer:=SELF; ray2.viewer:=SELF; ray3.viewer:=SELF;
			ray1.refractiveIndex:=ray.refractiveIndex; 
			ray3.refractiveIndex:=ray.refractiveIndex; 
			WHILE list#NIL  DO (*find shape nearest to the camera*)
				IF ~world.hasReflectionsRefractions & (world.cutout=NIL) & (list.distance>distance )  THEN  list:=NIL  (*in case of sorted list, far objects will not be reachable. Not valid the refractive & the reflecting case, or for cutouts*)
				ELSE 
					shape0:=shape; distance0:=distance; point0:=point; Normal0:=Normal; color0:=color;
					IF  list.shape.Intersect(ray, shape0, distance0, point0, Normal0, color0) THEN 
						IF (world.cutout=NIL) OR ~world.cutout.Inside(point0) THEN
							shape:=shape0; distance:=distance0; point:=point0; Normal:=Normal0; color:=color0;
						ELSE (*i.e. world.cutout.Inside(point0)*) 
							CreateRay(ray0, point0, point0+ray.dp); 
							ray0.reflections:=ray.reflections; 
							ray0.refractiveIndex:=shape0.refractIndex; (*!TBD: discriminate incoming versus outgoing, for refractiveIndex computation, based on direction of Normal*)
							shape0:=shape; distance00:=distance-distance0; Normal0:=Normal; color0:=color;
							IF  list.shape.Intersect(ray0, shape0, distance00, point0, Normal0, color0) & ~world.cutout.Inside(point0) THEN
								shape:=shape0; distance:=distance0+distance00; point:=point0; Normal:=Normal0; color:=color0;
							END;
						END; 
					END;	
					list:=list.next;
				END;
			END;
			IF shape#NIL THEN
				(* Phong illumination model = ambient + diffuse + specular, + luminescence *)
				IF shape.luminescence#transparent THEN shine:=shine+shape.luminescence END;
				IF Ambient IN Illumination THEN shine := shine + ambient * color END;
				
				IF FALSE (*renderPreview*) THEN
					shine:=shine+0.5*color
				ELSE 
					light:=world.lights;
					WHILE light#NIL DO (*! to do: light sources and shadow algorithm need to follow laws of refraction and reflection. Will be expensive *)
						illuminated:=TRUE;
						(*compute shadows*)
						IF shadowed THEN  (* check light ray against shadowing by any shape. Expensive. Optimizations possible ?*)
							CreateRay(ray1,light.location,point);
							(*ray1.sourceDistance:=; ray1.refractiveIndex:=;	*)
							distance2:=V.Length(light.location-point); distance1:=distance2;
							shape1:=world.shapes;
							WHILE illuminated & (shape1#NIL) DO
								found1 :=  shape1.Intersect(ray1, shape2, distance1, point1, Normal1, color1);
								illuminated := (distance2 <= distance1+threshold); (*? a smaller threshold leads to  shadowing artifacts in small features *)
								shape1:=shape1.next;
							END;
						END;

						(*compute illumination*)
						IF illuminated THEN
							IF shape.interpolation=PhongInterpolation THEN Normal:=Phong(shape,point) END;
							IF Diffuse IN Illumination THEN light.Diffuse(point, Normal,color,finish,diffuse); shine:=shine+diffuse; END;
							IF (Specular IN Illumination)&(shape.specular) THEN  light.Specular(point, Normal, ray.dp, color, finish, specular); shine := shine+ specular END;
						END;
					
						light:=light.next;
					END;
						
					IF shape.selected (*& ODD(row+col)*) THEN shine := 0.5*shine+0.5*Col.white  END;
						
					IF depthClue THEN (*!to do: should not affect luminescence and ambient illumination*)
						k:=(distance-nearest)/(farest-nearest);
						shine:= (1-k) * shine;
					END; (* does not yet work - distance is encoded in ShapeList which is not yet available here*)
					
					IF shape.refractive  & (ray.reflections<maxReflections) THEN
						INC(lensraycount);
						distance:=MAX(Datatype);	
						CreateRay(ray2,point,point+ray.dp); ray2.reflections:=ray.reflections+1; ray2.refractiveIndex:=shape.refractIndex; 
						Refract(ray2, Normal, ray.refractiveIndex, shape.refractIndex);
						ray2.sourceDistance:=ray.sourceDistance + V.Length(point-ray.p0)*ray.refractiveIndex; (* TAKE CARE: distance is normalized because we want length measured relative to wavelength, to keep track of phase *)
						RenderRay(ray2,list0,transparent); (*! to do: list0.distances are not yet correct for refracted beam => reorganize list0*)
						shine:=shine+transparent;
					END;
					IF shape.reflective &(ray.reflections<maxReflections) THEN 		
						INC(lensraycount);
						distance:=MAX(Datatype);
						CreateRay(ray3,point,point+ray.dp); ray3.reflections:=ray.reflections+1; 
						Reflect(ray3, Normal);
						ray3.sourceDistance:=ray.sourceDistance + V.Length(point-ray.p0)*ray.refractiveIndex; (* TAKE CARE: distance is normalized because we want length measured relative to wavelength, to keep track of phase *)
								(*! the normalization above might interfere with finding of objects behind this structures. probably, geometric length and refractive-index corrected length should be handled separately*)
						RenderRay(ray3,list0,reflective); (*! to do: list0.distances are not yet correct for reflected beam => reorganize list0*)
						shine:=shine+reflective
					END;
				END;
		ELSE shine:=background;
		END;
	END RenderRay;
		
	PROCEDURE Render*;  (*! to do: preview is still redundant, e.g. in searching candidate objects in each line ... *)
		VAR row,col:SIZE;
			dfar,dnear, distance:Datatype;
			shine: Color; 
			plane: Plane0;
			shape:Shape; 
			list0,list, this, this0, listpool,fullist: ShapeList;
			ray0,ray:Ray0;
			height, width:SIZE;
			beamColor0:Color;
			fileName:Files.FileName; str: ARRAY 8 OF CHAR;
			f:Files.File; w:Files.Writer;
		BEGIN
			farest:=MIN(FLOAT32); nearest:=MAX(FLOAT32);
			
			ticks:=Kernel.GetTicks();
			abort:=FALSE;
			ray.viewer:=SELF; ray0.viewer:=SELF;
			beamColor0:=beamColor;
			IF renderPreview  & (preview#NIL)THEN 
				currentview:=preview;
				step:=4 ;
				(*step:=2;*) (*! to do: this is not consistent  yet*)
			ELSE 
				currentview:=view; 
				step:=1 
			END;
			height:=currentview.height; 
			width:=currentview.width;
			(*! to do: check if reflective or refractive shapes  or with composite objects exist. Otherwise use preselection of shapes by slice testing, and by nearness ordering in list *)
			shape:=world.shapes;
			world.hasReflectionsRefractions:=FALSE;
			WHILE shape#NIL DO (*!to do: eliminate objects entirely behind camera*)
				NEW(this); this.shape:=shape; 
				this.next:=fullist; fullist:=this;
				this.distance:=V.Length(shape.box.center-location)-shape.box.radius; (*! negative distances may be handled wrongly here *)
				dnear:= this.distance; IF (dnear<nearest) THEN nearest:=dnear END;
				dfar:=this.distance+2*shape.box.radius;IF (dfar>farest) THEN farest:=dfar END;
				IF shape.reflective OR shape.refractive THEN world.hasReflectionsRefractions:=TRUE END;
				shape:=shape.next
			END;
			
			this:=fullist;
			WHILE this#NIL DO
				IF farest#nearest THEN
					this.relativeDistance:=(this.distance-nearest)/(farest-nearest);
				END;
				this:=this.next;
			END;
			
			shape:=world.shapes;
			
			IF  ~world.hasReflectionsRefractions (*& (world.cutout=NIL)*) THEN fullist:=SortList(fullist);	END; (*! how about cutouts... *)
			IF computeHash THEN NEW(crc) END;
			
			FOR row:=0 TO height-1 DO 
				IF abort THEN abort:=FALSE; RETURN END;
				(* preselection of candidate shapes for entire camera row *)
				InitRay(step*row,0,ray0); InitRay(step*row, step*width-1, ray); 
				plane:=CreatePlane(ray0.p0, ray0.p1, ray.p1);
				
				IF TRUE (*row MOD step=0 *) THEN (* i.e. further realtime-speedup option,. Used with additional MOD option below*)
					this0:=fullist; (* use distance-ordered list for selection of candidates*)
					list:=NIL;
					WHILE this0#NIL DO (* find candidate objects for hit testing of single camera scan line*)  (*! to do: refine granularity of this. An alternative would be a redundant quad-tree of objects *)
													(*! to do: handling composite objects still has problems, therefore the hack in the list building loop below *)
						IF  world.hasCompositeObjects OR (world.cutout#NIL) OR world.hasReflectionsRefractions OR  this0.shape.PlaneIntersectCandidate(plane) THEN (*! to do: reject objects outside of camera angle limits *)
							this:=listpool; 
							IF this=NIL THEN NEW(this) ELSE listpool:=this.next END;
							IF list=NIL THEN list0:=this ELSE	list.next:=this	END; 
							list:=this; list.shape:=this0.shape; list.distance:=this0.distance;
						END;
						this0:=this0.next
					END;
				END;
				
				(* render plausible candidate shapes  for each ray*)
				
				FOR col:=0 TO width-1 DO
					distance:=MAX(Datatype);
					InitRay(step*row,step*col,ray);
					IF rayHandler#NIL THEN rayHandler(row,col) END;
					
					IF TRUE THEN
						shine:=Col.black;(* *)
						RenderRay(ray,list0,shine); 
					ELSE(* i.e. further realtime-speedup option,. Used with additional MOD option above*)
						IF col MOD step=0 THEN 
							IF row MOD step=0 THEN
								shine:=Col.black;
								RenderRay(ray,list0,shine); 
								IF step#1 THEN tempLine[col]:=shine END;
							ELSE
								shine:=tempLine[col];
							END;
						END;
					END;
					SetPixel(ray, col,height-1-row, shine); (*!? is x,y mixed up ?*)
					IF computeHash THEN crc.Char(shine[0]);  crc.Char(shine[1]); crc.Char(shine[2]); crc.Char(shine[3]) END;
				END;
				listpool:=list0;
				list0:=NIL
			END;
			IF win#NIL THEN
				win.img:=currentview(WMGraphics.Image);
				win.Draw(win.canvas,win.img.width,win.img.height,0);
				win.Invalidate(WMRectangles.MakeRect(0, 0, win.img.width, win.img.height));
			END;
			IF store THEN 
				Strings.FormatDateTime("Raytrace_yymmdd.hhnnss", Dates.Now(), fileName);
				Strings.IntToStr(frame,str); Strings.Append(fileName,str); Strings.Append(fileName,".GIF");
				f:=Files.New(fileName);
				Files.OpenWriter(w,f,0);
				EncodeFrame("GIF",w);
				Files.Register(f);
			END;
			INC(frame);
			ticks:=Kernel.GetTicks()-ticks;
		END Render;
	END Camera;

	ActiveCamera*= OBJECT (Camera)
		VAR  (*time*, *) state*, frames*: SIGNED32; (* finite state machine *)

		PROCEDURE &New*(world:World);
		BEGIN
			Initialize(world);
			state:=waiting;
			frames:=1;
		END New;
		
		PROCEDURE CreatePreview*;
		BEGIN
			(* currently no preview for ActiveCamera*)
		END CreatePreview;

		PROCEDURE SetState*(state:SIGNED32);
		BEGIN {EXCLUSIVE}
			SELF.state:=state;
		END SetState;

		PROCEDURE AwaitState*(state:SIGNED32);
		BEGIN {EXCLUSIVE}
			AWAIT(SELF.state=state);
		END AwaitState;
		
		PROCEDURE SetNumberOfFrames*(frames:SIGNED32);
		BEGIN
			SELF.frames:=frames
		END SetNumberOfFrames;
		
	BEGIN {ACTIVE}
		LOOP 
			(*AwaitState(rendering);*)
			BEGIN {EXCLUSIVE} AWAIT state#waiting END;
			IF state=dying THEN EXIT END;
			FOR time:=0 TO frames-1 DO
				(*world.SetTime(time); *)(* here is a possible collision between different threads *)
				SetTime();
				(* possibly wait some period to adapt display rate*)
				Render;
			END;
			SetState(waiting);
		END;
	END ActiveCamera;

VAR 
	log:Streams.Writer;
	
	threshold*:Datatype;
	thresholds*:ARRAY [4] OF Datatype;
	
	goldenratio: Datatype;
	Invalid, PlusInfinity, MinusInfinity: Coordinate;
	NaN: Datatype;
	rand, s:Random.Sequence;
	emptyBox:Box;
	SrcCopy: Raster.Mode;
	
	shapeType, dotType, lineType,coordinateType, planeType, triangleType, quadrangleType, imageType, circleType, planarArrayType, volumeShapeType, sphereType, cylinderType, torusType, tetrahedronType, patchType, splinePatchType, blockType, brickType: Strings.String; 
 
 	LT2: AffineTransform; (*alternative light*)
 
 	
(*
	OPERATOR ":="(VAR res: Vector; x: Vector);
	BEGIN
		SYSTEM.MOVE(ADDRESS OF x[0], ADDRESS OF res[0], 16);
		(*
		CODE
			MOV RAX, [RBP + res]
			MOVUPS [RAX], x
		END;
			(*MOV RAX, [RBP + res]
			MOVUPS [RAX] , x*)
		(*y := x;
		res := y; 
		SYSTEM.MOVE(ADDRESS OF x[0], ADDRESS OF res[0], 16);
		*)
		(*res:=x[..];
		HALT(100);*)
		*)
	END ":=";
*)
 	(*
	OPERATOR -":="(VAR res: Vector; x{REGISTER}: Vector);
	BEGIN
		CODE
			MOVUPS res, x
		END;
			(*MOV RAX, [RBP + res]
			MOVUPS [RAX] , x*)
		(*y := x;
		res := y; 
		SYSTEM.MOVE(ADDRESS OF x[0], ADDRESS OF res[0], 16);
		*)
		(*res:=x[..];
		HALT(100);*)
	END ":=";
	*)
	
	
	(*
	System.FreeDownTo HomogenousVectors ~
	VolumeRaytracer.TestStatic~
	*)
	
    PROCEDURE ValidCoordinate(CONST c: Coordinate):BOOLEAN;
    BEGIN
    	 	IF c[3]#1 THEN RETURN FALSE
    	 	ELSIF (c[0]=MAX(Datatype)) OR (c[0]=MIN(Datatype)) THEN RETURN FALSE
    	 	ELSE RETURN TRUE
    	 	END;
    END ValidCoordinate;
    
    PROCEDURE SortList(l:ShapeList):ShapeList; (* bubble sort, could be replaced by faster algo for large datasets *)
    VAR sentinel, s0, s1, p0,p1,p2: ShapeList; changed:BOOLEAN;
    BEGIN
    	NEW(sentinel); sentinel.next:=l;
    	s0:=sentinel;
    	IF s0.next=NIL THEN RETURN NIL
    	ELSIF s0.next.next=NIL THEN RETURN s0.next
    	ELSE
	    changed:=FALSE;
	    WHILE s0.next.next#NIL DO
	    		s1:=s0;
	    		WHILE s1.next.next#NIL DO
	    			IF s1.next.next.distance<s1.next.distance THEN
	    				p0:=s1.next; p1:=s1.next.next; p2:=s1.next.next.next;
	    				s1.next:=p1; p1.next:=p0; p0.next:=p2;
	    				changed:=TRUE;
	    			END;
	    			s1:=s1.next;
	    		END;
	    		IF changed THEN 
	    			changed:=FALSE;
	    			IF s1.next.next=s0.next THEN s0.next:=s1.next END;
	    			IF s0=sentinel THEN sentinel.next:=s0.next END;
	    		ELSE s0:=s0.next;
	    		END;
	    END;
    	END;
    	RETURN sentinel.next
    END SortList;
    
	PROCEDURE LinePointDistance(CONST line:Line0; CONST p:Coordinate):Datatype;
	VAR u:Datatype; dp: Coordinate;
	BEGIN
		IF line.p0=p THEN RETURN 0
		ELSE
			u:= (p-line.p0)+*line.dp /V.Length(line.dp); 
			dp:=p-line.p0 - u*line.dp;
			RETURN V.Length(dp)
		END;
	END LinePointDistance;

	PROCEDURE LineLineDistance(CONST line0,line1:Line0):Datatype;
	VAR ua,ub:Datatype; d, d4321, d4343, d2121, d1321, d1343: Datatype; pdiff,ldiff: Coordinate;
	BEGIN
		IF line0.dp=line1.dp THEN
			RETURN LinePointDistance(line1,line0.p0)
		ELSE
			d4321:=line1.dp+*line0.dp;
			d4343:=line1.dp+*line1.dp; (*speedup by precomputed Innerp0, Innerdp ... *) (* is 1 for normalized line1.dp *)
			d2121:=line0.dp+*line0.dp; (* is 1 for normalized line0.dp *)
			pdiff:=line0.p0-line1.p0;
			d1321:=pdiff+* line0.dp;
			d1343:=pdiff+* line1.dp;
			d := d2121 * d4343 - d4321 * d4321;
			IF d=0 THEN 
				RETURN LinePointDistance(line0, line1.p0); (*parallel lines! coincident lines ? *)
			ELSE
				ua := ( d1343 * d4321 - d1321 * d4343) / d;
				ub := ( d1343 + d4321*ua) / d4343;
				ldiff := (line0.p0+ua*line0.dp) - (line1.p0+ub*line1.dp);
				RETURN V.Length(ldiff)
			END;
		END;
	END LineLineDistance;
	
	PROCEDURE RayPointDistance(CONST line:Ray0; CONST p:Coordinate):Datatype; (*!  to do: export link *) (*!to do - inlined version, could be replaced by faster "squared distance" operator, avoiding SQRT*)
	VAR u:Datatype; dp: Coordinate;
	BEGIN
		IF line.p0=p THEN RETURN 0
		ELSE
			u := ((p-line.p0) +* line.dp)* line.InvInnerdp; (* /line.Innerdp;*)
			dp :=(p-line.p0)- u*line.dp;
			RETURN V.Length(dp)
		END;
	END RayPointDistance;
	
	PROCEDURE RayPointSquaredDistance(CONST line:Ray0; CONST p:Coordinate):Datatype; (*!  to do: export link *) 
	VAR u:Datatype; dp: Coordinate;
	BEGIN
		IF line.p0=p THEN RETURN 0
		ELSE
			u := ((p-line.p0) +* line.dp)* line.InvInnerdp; (* /line.Innerdp;*) (*by default, last term=1, can be dropped*)
			dp :=(p-line.p0)- u*line.dp;
			RETURN dp+*dp
		END;
	END RayPointSquaredDistance;

	PROCEDURE RayRayDistance(CONST line0,line1:Ray0; VAR link:Line0):Datatype;  (*! to do: export link *)
	VAR ua,ub:Datatype; d, d4321, d4343, d2121, d1321, d1343: Datatype; pdiff,ldiff: Coordinate;
	BEGIN
		IF line0.dp=line1.dp THEN
			RETURN RayPointDistance(line1,line0.p0)
		ELSE
			d4321:=line1.dp+*line0.dp;
			d4343:=line1.Innerdp; (* line.Innerdp=1 for rays that should be normalized by default*)
			d2121:=line0.Innerdp;
			pdiff:=line0.p0-line1.p0;
			d1321:=pdiff+* line0.dp;
			d1343:=pdiff+* line1.dp;

			d := d2121 * d4343 - d4321 * d4321;
			IF d=0 THEN RETURN LinePointDistance(line0, line1.p0);  (*  parallel lines ? coincident lines ? *)
			ELSE
				ua := ( d1343 * d4321 - d1321 * d4343) / d;
				ub := ( d1343 + d4321*ua) / d4343;
				ldiff := (line0.p0 + ua*line0.dp) - (line1.p0 + ub*line1.dp);
				RETURN V.Length(ldiff)
			END;
		END;
	END RayRayDistance;

	(*
	see also ray-ray intersection:
	Ray/ray: (after Goldman, Graphics Gems; see his article for the derivation)
	Define each ray by an origin o and a normalized (unit vector) direction d. The two lines are then
		L1(t1) = o1 + d1*t1
		L2(t2) = o2 + d2*t2

		The solutions are:
		t1 = Determinant{(o2-o1),d2,d1 X d2} / ||d1 X d2||^2
		t2 = Determinant{(o2-o1),d1,d1 X d2} / ||d1 X d2||^2
		If the lines are parallel, the denominator ||d1 X d2||^2 is 0.
		If the lines do not intersect, t1 and t2 mark the points of closest approach on each line.
	*)

	(** compute interpolation weights for point P inside triangle; results shoulld give a weight~1 for points near to a given vertex should add up to  (a+b+c)=1 *) (*! not correct - not clear if appropriate*)
	PROCEDURE TriangleInterpolation(CONST P, A,B,C: Coordinate; VAR a,b,c: Datatype);
	(*VAR da,db,dc, d: Datatype; (*distances*)
		ra,rb,rc: Datatype; (* weight ratios *)
	BEGIN
		da:=V.Length(P-A); db:=V.Length(P-B); dc:=V.Length(P-C);
		d:=da+db+dc;
		ra := da/d; rb:=db/d; rc:=dc/d;
		a := 1/(1 + 1 / ra);
		b := 1/(1 + 1 / rb);
		c := 1/(1 + 1 / rc);
		*)
	END TriangleInterpolation;
	
	PROCEDURE InsideTetrahedron*(CONST P:Coordinate; CONST p0,p1,p2,p3:Coordinate):BOOLEAN; (* to do: optimize*)
		VAR n0, n1,n2,n3, v: Vector;
		BEGIN
			n0:=(p1-p0)*(p2-p0);
			n1:=(p2-p0)*(p3-p0);
			n2:=(p3-p0)*(p1-p0);
			n3:=(p3-p1)*(p2-p1);
			v:=V.CastVector((P-p0)+*n0, (P-p0)+*n1, (P-p0)+*n2, (P-p1)+*n3);
			RETURN (v <=0) OR (0<=v)
		END InsideTetrahedron;

	PROCEDURE InitBox(VAR box:Box; CONST p0,p1: Coordinate); (* defines axis-aligned bounding box *)
	BEGIN
		box.p0:=p0-thresholds;
		box.p1:=p1+thresholds;
		box.center:= 0.5*box.p0 + 0.5*box.p1;
		box.radius:=V.Length(box.p1-box.center);
	END InitBox;

	(** solve the quadratic equation x^2 + bx + c = 0 *)
	PROCEDURE Quadratic*( b, c: Datatype; VAR root0, root1: Datatype): BOOLEAN;
	VAR dis, rtdis: Datatype;
	BEGIN
		dis := b * b - 4 * c;
		IF b = 0 THEN
			IF c = 0 THEN root0:=0;
			ELSIF c < 0 THEN root0:=Mathe.sqrt(-c); root1 := -root0;
			ELSE root0:=0; root1:=0; RETURN FALSE
			END;
		ELSIF c = 0 THEN root0 := -b; root1:=-b;
		ELSIF dis >= 0 THEN
			rtdis := Mathe.sqrt( dis );
			IF b > 0 THEN root0 := (-b - rtdis) * 0.5;
			ELSE root0 := (-b + rtdis) * 0.5;
			END;
			IF root0 = 0 THEN root1 := -b;  ELSE root1 := c / root0;  END;
		ELSE root0:=0; root1:=0; RETURN FALSE;
		END;
		RETURN TRUE
	END Quadratic;

	PROCEDURE QuadraticL*( b, c: FLOAT64; VAR r0, r1: Datatype): BOOLEAN;
	VAR dis, rtdis: FLOAT64;  root0, root1: FLOAT64;
	BEGIN
		dis := b * b - 4 * c;
		IF b = 0 THEN
			IF c = 0 THEN root0:=0;
			ELSIF c < 0 THEN root0 := MathL.sqrt( -c ); root1 := -root0;
			ELSE root0:=0; root1:=0; r0:=SHORT(root0); r1:=SHORT(root1); RETURN FALSE
			END;
		ELSIF c = 0 THEN root0 := -b; root1:=-b;
		ELSIF dis >= 0 THEN
			rtdis := MathL.sqrt( dis );
			IF b > 0 THEN root0 := (-b - rtdis) * 0.5;
			ELSE root0 := (-b + rtdis) * 0.5;
			END;
			IF root0 = 0 THEN root1 := -b;  ELSE root1 := c / root0;  END;
		ELSE root0:=0; root1:=0; r0:=SHORT(root0); r1:=SHORT(root1); RETURN FALSE;
		END;
		r0:=SHORT(root0); r1:=SHORT(root1); RETURN TRUE
	END QuadraticL;

	PROCEDURE Dynamic0(CONST T0:AffineTransform; t:Datatype):AffineTransform;
		BEGIN
			RETURN T0
		END Dynamic0;

PROCEDURE Translate*( dx,dy,dz:Datatype):AffineTransform; 
		BEGIN
			RETURN [[1,0,0,dx],
			[0,1,0,dy],
			[0,0,1,dz],
			[0,0,0,1]];
	END Translate;

	PROCEDURE RotX*( t:Datatype):AffineTransform; 
		BEGIN
			RETURN [[1,0,0,0],
			[0,Mathe.cos(t), -Mathe.sin(t),0],
			[0,Mathe.sin(t), Mathe.cos(t),0],
			[0,0,0,1]];
	END RotX;
	
	PROCEDURE RotY*( t:Datatype):AffineTransform; 
	BEGIN
		RETURN [[Mathe.cos(t), 0, -Mathe.sin(t),0],
			[0,1,0,0],
			[Mathe.sin(t), 0, Mathe.cos(t),0],
			[0,0,0,1]];
	END RotY;
		
	PROCEDURE RotZ*( t:Datatype):AffineTransform; 
	BEGIN
		RETURN [[Mathe.cos(t), -Mathe.sin(t),0,0],
			[Mathe.sin(t), Mathe.cos(t),0,0],
			[0,0,1,0],
			[0,0,0,1]];
	END RotZ;

	PROCEDURE DynamicXAxisRot*(CONST T0:AffineTransform; t:Datatype):AffineTransform; (*! todo: use  t  in radian units*)
	VAR T: AffineTransform;
		BEGIN
			T:=RotX(t/10);
			RETURN T*T0
	END DynamicXAxisRot;
			
	PROCEDURE DynamicYAxisRot*(CONST T0:AffineTransform; t:Datatype):AffineTransform;
	VAR T: AffineTransform;
		BEGIN
			T:=RotY(t/10);
			RETURN T*T0
		END DynamicYAxisRot;
		
	PROCEDURE DynamicZAxisRot*(CONST T0:AffineTransform; t:Datatype):AffineTransform;
	VAR T: AffineTransform;
		BEGIN
			T:=RotZ(t/10);
			RETURN T*T0
		END DynamicZAxisRot;

	(* http://www.euclideanspace.com/maths/algebra/vectors/lookat/index.htm *)
	PROCEDURE LookAt*(CONST T: AffineTransform; CONST p: Coordinate): AffineTransform; (* choose new coordinate system with x-axis looking at a point P defined in original coordinates. Note: camera distance from target=1; may need adaptation *)
	VAR o: Coordinate; u, x, y,  z, up: Vector; distance:Datatype;
	BEGIN
		o:=T[..,3];
		up := T * [0, 1.0, 0, 0]; (* up := current y axis*)
		x := p- T[..,3]; (* x := direction from current origin to object*)
		distance:=V.Length(x);
		IF distance=0 THEN x:=[1,0,0,0]; distance:=1;
		ELSE x:=V.Normalize(x);
		END;
		z:=V.Normalize(x*up); 
		IF Reals.IsNaN(z[0]) THEN up[2]:=up[2]+0.01; z:=V.Normalize(x*up); END; (*avoid NaN, gymbal lock *)
		y:=z*x; 
		u := [0.0,0,0,1]; 
		RESULT := [x,y,z,u]; RESULT[..,3]:=o; (* keep camera-to-object distance, except it is 0 *)
		RETURN RESULT
	END LookAt;

(*
Citing /www.euclideanspace.com:
"Since the direction of the 'up' vector is not important we often use an arbitrary value like (0,1,0)
although this is questioned in this thread - here is a quote from it:
"Using a constant vector such as (0,1,0), which is the only recommendation I've ran across is no good.
You end up rotating the bank axis for no reason, and near singularity points (attitude +-90) the camera spins wildly.
My solution was using [currentRotationMatrix * (0,1,0)] as the up vector. It makes sure only the heading and attitude
are changed for the lookAt so the bank is not altered, and it has stood up very well through testing."
*)
PROCEDURE CreatePlane*(CONST p0,p1,p2: Coordinate):Plane0;
	VAR plane:Plane0;
	BEGIN
		plane.p:= p0;
		plane.normal:=V.Normalize((p1-p0)*(p2-p0)); (*cross product*)
		RETURN plane
	END CreatePlane;
	
PROCEDURE CreateRay*( VAR ray: Ray0; CONST p0,p1:Coordinate); 
BEGIN
	ray.p0:= p0; 
	ray.p1:=p1; 
	ray.dp:=(p1-p0);
	ray.dp:=V.Normalize(ray.dp);
	ray.Innerp0:= p0 +* p0; 
	ray.Innerdp:=1; ray.InvInnerdp:=1; (*is normalized*)
	ray.refractiveIndex:=0;
END CreateRay;

PROCEDURE Reflect*(VAR ray:Ray0; CONST normal: Vector); (* do not forget to change ray.p0 etc*) (*! there is still a bug*)
BEGIN
	ray.dp:= -(ray.dp+*normal * 2) * normal+ray.dp;
END Reflect;

(* note that there  is square root -free version of refraction at http://hugi.scene.org/online/hugi23/torefrac.htm *)
PROCEDURE Refract*(VAR ray: Ray0; CONST normal: Vector; index0,indexShape:Datatype); (* makes use of the fact that Normal vector always points "outward" to discriminate between incoming and outgoing ray*)
VAR ndoti,a,b,D2:Datatype;
BEGIN
	IF index0=indexShape THEN RETURN END;
	ndoti:=-(normal+*ray.dp); (*incident vector and normal vector are divergent if object hit by ray*)
	IF ndoti>=0 THEN 
		b:=index0/indexShape;
		ray.refractiveIndex:=indexShape;
	ELSE 
		b:=indexShape/index0; 
		ray.refractiveIndex:=index0;
	END;
	D2:=1-b*b*(1- ndoti*ndoti);
	IF D2>=0 THEN
		IF ndoti>=0 THEN a:=b*ndoti-Mathe.sqrt(D2)
		ELSE a:=b*ndoti + Mathe.sqrt(D2)
		END;
		ray.dp:=a*normal + b*ray.dp
	ELSE (*total internal reflection*)
		ray.dp:= 2*ndoti * normal + ray.dp
	END;
	ray.dp:=V.Normalize(ray.dp);
END Refract;
	
PROCEDURE Phong(shape:Shape; CONST p:Coordinate):Vector; (*to do: performanc/fast Phong Shading http://www.cs.unc.edu/~gb/Pubs/siggraph86.html give MUCH faster approach with ~6 FLOPS/pixel*)
VAR N1,N2,N:Vector; i,j,k,l:SIGNED32; size: ARRAY [3] OF Datatype; t:Triangle; ab,bc,ca,nnj,nnk,pa,pb,pc:Datatype;
BEGIN
	IF (shape IS Triangle) THEN t:=shape(Triangle) ELSE HALT(200) END; (* not yet implemented *)
	size:=ABS(t.box.p1[0..2]-t.box.p0[0..2]);
	
	(*indices i,j,k point to the descending size-ordered dimensions, avoid division by zero in quotient below*)
	IF size[0]>size[1] THEN i:=0; j:=1; k:=2;  ELSE i:=1; j:=0; k:=2; END;
	IF size[j]<size[2] THEN 
		k:=j; j:=2; 
		IF size[i]<size[j] THEN l:=i; i:=j; j:=l END;
	END;

	ab:=t.A[i]-t.B[i]; bc:=t.B[i]-t.C[i]; ca:= t.C[i]-t.A[i];
	pa:=p[i]-t.A[i]; pb:=p[i]-t.B[i]; pc:=p[i]-t.C[i];
	IF pb*pc > 0 THEN (* B and C on one side*)
		N1:= ABS(pb/ab)*t.Na + ABS(pa/ab)*t.Nb; (*to do: performance. by temp variables etc*)
		N2:= ABS(pc/ca)*t.Na + ABS(pa/ca)*t.Nc; 
	ELSIF pa*pc > 0 THEN (* A and C on one side*)
		N1:= ABS(pa/ab)*t.Nb + ABS(pb/ab)*t.Na; 
		N2:= ABS(pc/bc)*t.Nb + ABS(pb/bc)*t.Nc;
	ELSE (* A and B on one side *)
		N1:= ABS(pa/ca)*t.Nc + ABS(pc/ca)*t.Na; 
		N2:= ABS(pb/bc)*t.Nc + ABS(pc/bc)*t.Nb; 
	END;
	
	nnj:=N2[j]-N1[j]; 
	nnk:=N2[k]-N1[k];
	IF ABS(nnj)>ABS(nnk) THEN N:=ABS((N2[j]-p[j])/nnj)*N1 + ABS((p[j]-N1[j])/nnj)*N2; 	
	ELSIF nnk#0 THEN 		    N:=ABS((N2[k]-p[k])/nnk)*N1 + ABS((p[k]-N1[k])/nnk)*N2;
	ELSE (*N:=Invalid; *) N:=t.Normal
	END;
	N:=V.Normalize(N);
	RETURN N
END Phong;

PROCEDURE WorldFromMatrix*(CONST m:ARRAY [*,*] OF Datatype; graphWidth, graphHeight: Datatype): World;
VAR W: World;
	lenX, lenY, xi, yi, col, row: SIZE;
	x,y, scale, scaleHeight, sH, drc, maxabs: Datatype;
	T:Triangle;
BEGIN
	NEW(W);
	lenX:=LEN(m,0); lenY:=LEN(m,1);
	scale:=graphWidth/lenX;
	scaleHeight:= graphHeight/ (MAX(m)-MIN(m));
	sH := scaleHeight;
	maxabs := MAX(ABS(MAX(m)), ABS(MIN(m)));
	FOR row:=0 TO LEN(m,0)-2 DO
		FOR col := 0 TO LEN(m,1)-2 DO
			xi := - (LEN(m,0) DIV 2) +row; x:=xi*scale;
			yi := - (LEN(m,1) DIV 2) +col; y:=yi*scale;
			drc:=ABS(m[row,col])/maxabs;
			NEW(T,[x,  sH*m[row,col], y, 1], [x+scale, sH*m[row+1,col+1], y+scale, 1], [x+scale, sH*m[row+1,col], y, 1]); T.SetColor((1-drc)*Col.green + drc * Col.red,FALSE); W.Add(T);
			NEW(T,[x,  sH*m[row,col], y, 1], [x,  sH*m[row,col+1], y+scale, 1], [x+scale, sH*m[row+1,col+1], y+scale, 1]); T.SetColor((1-drc)*Col.green + drc * Col.red,FALSE); W.Add(T);
		END;
	END;
	RETURN W
END WorldFromMatrix;

PROCEDURE LogShape*(s:Shape);
BEGIN
	IF (s#NIL)&(s.type#NIL) THEN KernelLog.String(s.type^); ELSE KernelLog.String("NIL"); END;
END LogShape;

PROCEDURE TestStatic*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; S:Sphere; T:Triangle; TH: Tetrahedron; Cy: Cylinder;
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
	BEGIN
		NEW(W);
		W.DefaultLight;
		W.lights.AddLight(LT2, Col.red, 0.3, FALSE);
		NEW(Win, 512,512, FALSE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.CreatePreview;

		NEW(S,[-0.1,  0.1,-0.1,1],0.1); S.SetColor(Col.yellow,TRUE); W.Add(S);
		NEW(S,[  0.1,-0.1,-0.1,1],0.3); S.SetColor(Col.red,TRUE); W.Add(S);
		NEW(S,[  0,   -0.1,  0.1,1],0.2); S.SetColor(Col.blue,TRUE);  S.selected:=TRUE; W.Add(S); 
		NEW(T,[0, -0.3, -0.3, 1], [0, -0.3, 0.3, 1], [-0.2, 0.3, -0.3, 1]); T.SetColor(Col.blue,TRUE); W.Add(T);
		NEW(Cy,[-0.4, -0.2, 0.1, 1], [0.35, 0.1, -0.1, 1], 0.06); Cy.SetColor(Col.yellow,TRUE); W.Add(Cy);
		NEW(T,[0, 0.3, 0.3, 1], [0, 0.3, -0.3, 1], [-0.2, -0.3, 0.3, 1]);  T.SetColor(Col.green,TRUE); W.Add(T);
		NEW(TH,[0.4, -0.4, 0.1, 1], [0.4, -0.1, 0.4, 1], [-0.4, -0.1, 0.4, 1], [-0.4, -0.4, 0.1, 1]); TH.SetColor(Col.blue,TRUE); W.Add(TH);

		Cam.Render;

		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" tics."); context.out.Ln; context.out.Update;
	END TestStatic;
	
PROCEDURE TestCutout*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; S:Sphere; T:Triangle; TH: Tetrahedron; Cy: Cylinder; CC: Sphere;
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
	BEGIN
		NEW(W);
		W.DefaultLight;
		W.lights.AddLight(LT2, Col.red, 0.3, FALSE);(* additional light*) 
		NEW(Win, 512,512, FALSE);
		NEW(Cam,W);
		Cam.ambient:=0.2;
		Cam.SetWindow(Win);
		Cam.CreatePreview;

		NEW(S,[-0.1,  0.1,-0.1,1],0.1); S.SetColor(Col.yellow,TRUE); W.Add(S);
		NEW(S,[  0.1,-0.1,-0.1,1],0.3); S.SetColor(Col.red,TRUE); W.Add(S);
		NEW(S,[  0,   -0.1,  0.1,1],0.2); S.SetColor(Col.blue,TRUE);  S.selected:=TRUE; W.Add(S); 
		NEW(T,[0, -0.3, -0.3, 1], [0, -0.3, 0.3, 1], [-0.2, 0.3, -0.3, 1]); T.SetColor(Col.blue,TRUE); W.Add(T);
		NEW(Cy,[-0.4, -0.2, 0.1, 1], [0.35, 0.1, -0.1, 1], 0.06); Cy.SetColor(Col.yellow,TRUE); W.Add(Cy);
		NEW(T,[0, 0.3, 0.3, 1], [0, 0.3, -0.3, 1], [-0.2, -0.3, 0.3, 1]);  T.SetColor(Col.green,TRUE); W.Add(T);
		NEW(TH,[0.4, -0.4, 0.1, 1], [0.4, -0.1, 0.4, 1], [-0.4, -0.1, 0.4, 1], [-0.4, -0.4, 0.1, 1]); TH.SetColor(Col.blue,TRUE); W.Add(TH);
		
		NEW(CC, [0, 0.3, 0, 1],0.3); W.cutout:=CC;

		Cam.Render;

		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" tics."); context.out.Ln; context.out.Update;
	END TestCutout;

PROCEDURE TestStaticDepth*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; S:Sphere; T:Triangle; TH: Tetrahedron; Cy: Cylinder;
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
	BEGIN
		NEW(W);
		W.DefaultLight;
		W.lights.AddLight(LT2, Col.white, 1, FALSE);(* additional light*) 
		NEW(Win, 512,512, FALSE);
		NEW(Cam,W);
		Cam.depthClue:=TRUE;
		Cam.ambient:=0.2;
		Cam.SetWindow(Win);
		Cam.CreatePreview;

		NEW(S,[-0.1,  0.1,-0.1,1],0.1); S.SetColor(Col.yellow,TRUE); W.Add(S);
		NEW(S,[  0.1,-0.1,-0.1,1],0.3); S.SetColor(Col.red,TRUE); W.Add(S);
		NEW(S,[  0,   -0.1,  0.1,1],0.2); S.SetColor(Col.blue,TRUE);  W.Add(S); S.selected:=TRUE;
		NEW(T,[0, -0.3, -0.3, 1], [0, -0.3, 0.3, 1], [-0.2, 0.3, -0.3, 1]); T.SetColor(Col.blue,TRUE); W.Add(T);
		NEW(Cy,[-0.4, -0.2, 0.1, 1], [0.35, 0.1, -0.1, 1], 0.06); Cy.SetColor(Col.yellow,TRUE); W.Add(Cy);
		NEW(T,[0, 0.3, 0.3, 1], [0, 0.3, -0.3, 1], [-0.2, -0.3, 0.3, 1]);  T.SetColor(Col.green,TRUE); W.Add(T);
		NEW(TH,[0.4, -0.4, 0.1, 1], [0.4, -0.1, 0.4, 1], [-0.4, -0.1, 0.4, 1], [-0.4, -0.4, 0.1, 1]); TH.SetColor(Col.blue,TRUE); W.Add(TH);

		Cam.Render;

		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" tics."); context.out.Ln; context.out.Update;
	END TestStaticDepth;

PROCEDURE TestMirrorLens*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; S:Sphere; T:Triangle; TH: Tetrahedron; Cy: Cylinder;
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
	BEGIN
		NEW(W);
		W.DefaultLight;
		W.lights.AddLight(LT2, Col.red, 0.3, FALSE);(* additional light*) 

		NEW(Win, 512,512, FALSE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.CreatePreview;
		
		NEW(S,[-0.2,  0.2,-0.2,1],0.1); S.SetColor(Col.darkyellow,TRUE); S.refractive:=TRUE; S.refractIndex:=1.4; W.Add(S);
		NEW(S,[  0.1,-0.1,-0.1,1],0.3); S.SetColor(Col.red,TRUE); S.reflective:=TRUE; W.Add(S);
		NEW(S,[  0,   -0.2,  0.2,1],0.2); S.SetColor(Col.blue,TRUE);  S.reflective:=TRUE; W.Add(S); (*S.selected:=TRUE;*)
		NEW(T,[0, -0.3, -0.3, 1], [0, -0.3, 0.3, 1], [-0.2, 0.3, -0.3, 1]); T.SetColor(Col.blue,TRUE); W.Add(T);
		NEW(Cy,[-0.4, -0.2, 0.1, 1], [0.35, 0.1, -0.1, 1], 0.06); Cy.SetColor(Col.yellow,TRUE); Cy.reflective:=TRUE; W.Add(Cy);
		NEW(T,[0, 0.3, 0.3, 1], [0, 0.3, -0.3, 1], [-0.2, -0.3, 0.3, 1]);  T.SetColor(Col.green,TRUE); T.reflective:=TRUE; W.Add(T);
		NEW(TH,[0.4, -0.4, 0.1, 1], [0.4, -0.1, 0.4, 1], [-0.4, -0.1, 0.4, 1], [-0.4, -0.4, 0.1, 1]); TH.SetColor(Col.blue,TRUE); W.Add(TH);

		Cam.Render;

		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" tics."); context.out.Ln; context.out.Update;
	END TestMirrorLens;
	
	(* compare CRC of image rendered to GIF file with old rendering CRC, using SSE libraries for Color and Homogenous vectors *)
	(* might add CRCs for less accelerated versions or other platforms of Color and Homogenous Vectors, as there might be rounding differences *)
	PROCEDURE {TEST} Test*; 
	VAR Cam: Camera;
		W:World; S:Sphere; T:Triangle; TH: Tetrahedron; Cy: Cylinder;
		Win:Window; 
		crc:CRC.CRC32; f:Files.File; r:Files.Reader; res:SIGNED32; c:CHAR;
	BEGIN
		NEW(W);
		W.DefaultLight;
		W.lights.AddLight(LT2, Col.red, 0.3, FALSE);(* additional light*) 

		NEW(Win, 512,512, FALSE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.CreatePreview;
		
		NEW(S,[-0.2,  0.2,-0.2,1],0.1); S.SetColor(Col.darkyellow,TRUE); S.refractive:=TRUE; S.refractIndex:=1.4; W.Add(S);
		NEW(S,[  0.1,-0.1,-0.1,1],0.3); S.SetColor(Col.red,TRUE); S.reflective:=TRUE; W.Add(S);
		NEW(S,[  0,   -0.2,  0.2,1],0.2); S.SetColor(Col.blue,TRUE);  S.reflective:=TRUE; W.Add(S); (*S.selected:=TRUE;*)
		NEW(T,[0, -0.3, -0.3, 1], [0, -0.3, 0.3, 1], [-0.2, 0.3, -0.3, 1]); T.SetColor(Col.blue,TRUE); W.Add(T);
		NEW(Cy,[-0.4, -0.2, 0.1, 1], [0.35, 0.1, -0.1, 1], 0.06); Cy.SetColor(Col.yellow,TRUE); Cy.reflective:=TRUE; W.Add(Cy);
		NEW(T,[0, 0.3, 0.3, 1], [0, 0.3, -0.3, 1], [-0.2, -0.3, 0.3, 1]);  T.SetColor(Col.green,TRUE); T.reflective:=TRUE; W.Add(T);
		NEW(TH,[0.4, -0.4, 0.1, 1], [0.4, -0.1, 0.4, 1], [-0.4, -0.1, 0.4, 1], [-0.4, -0.4, 0.1, 1]); TH.SetColor(Col.blue,TRUE); W.Add(TH);

		Cam.Render;
		WMGraphics.StoreImage(Cam.view,"tmp.GIF",res);
		f:=Files.Old("tmp.GIF"); 
		Files.OpenReader(r,f,0);
		NEW(crc); r.Char(c);
		WHILE r.res=Files.Ok DO crc.Char(c); r.Char(c) END; 
		ASSERT(crc.Get()=1552235866, 201); (* was determined using same procedure earlier *)
		(*context.out.String("stored; "); context.out.String(" CRC= "); context.out.Int(crc.Get(), 8); 
		context.out.Ln; context.out.Update;*)
	END Test;


	PROCEDURE TestSphere*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; S:Sphere; 
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
	BEGIN
		NEW(W);
		W.DefaultLight;
		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.shadowed:=TRUE;

		NEW(S,[-0.1,  0.1,-0.1,1],0.1); S.SetColor(Col.yellow,TRUE); W.Add(S);
		NEW(S,[0.1,  0.1,-0.1,1],0.1); S.SetColor(Col.yellow,TRUE); S.refractive:=TRUE; S.refractIndex:=1.3; W.Add(S);
		NEW(S,[0.1, - 0.1,-0.1,1],0.1); S.SetColor(Col.yellow,TRUE);S.reflective:=TRUE; W.Add(S);
		Cam.Render;
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestSphere;
	
	PROCEDURE TestCoords*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; S:Sphere; CS:CoordinateSystem;
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
	BEGIN
		NEW(W);
		W.DefaultLight;
		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.shadowed:=TRUE;
		
		NEW(CS,Identity,0.002, -1); W.Add(CS);
		
		NEW(S,[0.0,0,0,1],0.03); S.SetColor(Col.gray,TRUE); W.Add(S);
		NEW(S,[0.2, 0,0,1],0.02); S.SetColor(Col.red,TRUE); W.Add(S);
		NEW(S,[0.0, 0.2, 0 ,1],0.06); S.SetColor(Col.green,TRUE); S.refractive:=TRUE; S.refractIndex:=1.3; W.Add(S);
		NEW(S,[0.0, 0, 0.2,1],0.04); S.SetColor(Col.blue,TRUE);S.reflective:=TRUE; W.Add(S);
		Cam.Render;
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestCoords;

	PROCEDURE TestHelix*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; S:Sphere; 
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
		i:SIGNED32;
		x ,y ,x1 ,y1 ,x2 ,y2, x3,y3 ,z :FLOAT32;
	BEGIN
		context.out.String("drawing helix"); context.out.Ln; context.out.Update;

		NEW(W);
		W.DefaultLight;
		NEW(Win, 512,256, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.shadowed:=FALSE;

		FOR i:=0 TO 500 DO
			x:=Mathe.sin(i/30); y:=Mathe.cos(i/30);
			x1:=Mathe.sin(i/30 + 0.5*pi); y1:=Mathe.cos(i/30+0.5*pi);
			x2:=Mathe.sin(i/30 + pi); y2:=Mathe.cos(i/30 + pi);
			x3:=Mathe.sin(i/30 + 1.5*pi); y3:=Mathe.cos(i/30+ 1.5*pi);
			z:=1-i/200;
			NEW(S,[x/20,y/20,z,1],0.06); S.SetColor(Col.white,TRUE); W.Add(S);
			NEW(S,[x1/20,y1/20,z,1],0.06); S.SetColor(Col.yellow,TRUE); W.Add(S);
			NEW(S,[x2/20,y2/20,z,1],0.06); S.SetColor(Col.orange,TRUE); W.Add(S);
			NEW(S,[x3/20,y3/20,z,1],0.06); S.SetColor(Col.red,TRUE); W.Add(S);
		END;
		Cam.Render;
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln;
		context.out.Update;
	END TestHelix;

	PROCEDURE TestTriangle*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; T:Triangle; 
		Win:Window;
	BEGIN
		NEW(W);
		W.DefaultLight;
		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		NEW(T,[0, 0.3, 0.3, 1], [0, 0.3, -0.3, 1], [-0.2, -0.3, 0.3, 1]);  T.SetColor(Col.green,TRUE); W.Add(T);
		Cam.Render;
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestTriangle;
	
	PROCEDURE TestQuadrangle*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; 
		Win:Window;
		Q:Quadrangle; 
	BEGIN
		NEW(W);
		W.DefaultLight;
		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.CreatePreview;
		NEW(Q,[0, 0.3, 0.3, 1], [0, 0.3, -0.3, 1], [-0.2, -0.3, -0.3, 1],[-0.2, -0.3, 0.3, 1] ); 
		Q.SetColor(Col.blue,TRUE);
		W.Add(Q);
		Cam.Render;
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestQuadrangle;
	
	PROCEDURE TestImage*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; 
		Win:Window;
		Img:Quadrangle; 
	BEGIN
		NEW(W);
		W.DefaultLight;
		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.CreatePreview;
		
		NEW(Img,[0, 0.3, 0.3, 1], [0, 0.3, -0.3, 1], [-0.2, -0.3, -0.3, 1],[-0.2, -0.3, 0.3, 1] ); 
		W.Add(Img);
		Cam.Render;
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestImage;
	
	PROCEDURE TestTransform*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; T:Triangle; 
		Win:Window;
		t:AffineTransform;
	BEGIN
		NEW(W);
		W.DefaultLight;
		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);

		NEW(T,[0, 0.2, 0.2, 1], [0, 0.2, -0.2, 1], [-0.1333, -0.2, 0.2, 1]);  T.SetColor(Col.green,TRUE); W.Add(T);
		NEW(T,[0, 0.2, 0.2, 1], [0, 0.2, -0.2, 1], [-0.1333, -0.2, 0.2, 1]);  T.SetColor(Col.blue,TRUE); W.Add(T);
		t:=[[1,  0,	0,	0],
		[0, 	0.6,	-0.6,	0],
		[0,	0.6,	 0.6,	0],
		[0,	0,	0,	1]];
		T.Transform(t);
		
		Cam.Render;
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestTransform;

PROCEDURE TestPhong*(context:Commands.Context);
	VAR Cam: Camera;
		W:World;  P:Patch; m:ARRAY [*,*,*] OF Datatype; L:Line;
		p0,p1,p2,p3:Coordinate;
		Win:Window;
		triangles:ARRAY [*,*,2] OF Triangle;
	BEGIN
		NEW(W);
		W.DefaultLight;

		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.shadowed:=FALSE;
		p0:=[0, 0, 0 , 1]; p1:=[0.3, 0,0 , 1]; p2:=[0,0.3,0,1]; p3:=[0.3,0.3,-0.3,1];
		
		NEW(m,4,4,4); m[1,1]:=p0; m[1,2]:=p1; m[2,1]:=p2; m[2,2]:=p3; (*m:=m-0.4;*)
		NEW(P,m,1,triangles); P.SetColor(Col.yellow,TRUE); W.Add(P);
		NEW(L,p0,p3,0.001); L.SetColor(Col.red,TRUE); W.Add(L);
		Cam.Render;

		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestPhong;

	PROCEDURE TestPyramid*(context:Commands.Context);
	VAR Cam: Camera;
		W:World;  TH: Tetrahedron; 
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
	BEGIN
		NEW(W);
		W.DefaultLight;
		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);

		NEW(TH,[0.4, -0.4, 0.1, 1], [0.4, -0.1, 0.4, 1], [-0.4, -0.1, 0.4, 1], [-0.4, -0.4, 0.1, 1]); TH.SetColor(Col.blue,TRUE); W.Add(TH);
		Cam.Render;
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestPyramid;

	PROCEDURE TestBlock*(context:Commands.Context);
	VAR Cam: Camera;
		W:World;  B:Block; 
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
	BEGIN
		NEW(W);
		W.DefaultLight;
		W.lights.brightness:=1.0;
		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.CreatePreview;
		Cam.ambient:=0.3;

		NEW(B,[0.2,0.2,0.2,1], [0.2,-0.2,0.2,1],  [-0.2,-0.2,0.2,1], [-0.2,0.2,0.2,1], 
				[0.2,0.2,-0.2,1], [0.2,-0.2,-0.2,1], [-0.2,-0.2,-0.2,1], [-0.2,0.2,-0.2,1]); 
		B.SetColors(Col.red, Col.green, Col.blue,  Col.orange, Col.white, Col.yellow);
		W.Add(B);

		Cam.Render;
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestBlock;
	
	PROCEDURE TestTetra*(context:Commands.Context);
	VAR Cam: Camera;
		W:World;  T: Tetrahedron; 
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
	BEGIN
		NEW(W);
		W.DefaultLight;
		W.lights.brightness:=1.0;
		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.CreatePreview;
		Cam.ambient:=0.3;

		NEW(T,[-0.2,-0.2,0.2,1], [0.2,0.2,0.2,1], 	[-0.2,0.2,-0.2,1], [0.2,-0.2,-0.2,1]); 
		T.SetColors(Col.red, Col.green, Col.blue, Col.yellow);
		W.Add(T);

		Cam.Render;
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestTetra;


	PROCEDURE TestDynamic*(context:Commands.Context);
	VAR 
		ActiveCam:ActiveCamera;
		W:World; S:Sphere; T:Triangle; TH: Tetrahedron; Cy: Cylinder;
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
	BEGIN
		NEW(W);
		W.DefaultLight;
		W.lights.AddLight(LT2, Col.red, 0.3, FALSE);(* additional light*) 

		NEW(Win, 200,200, TRUE);
		NEW(ActiveCam,W);
		ActiveCam.SetWindow(Win);
		ActiveCam.Dynamic:=DynamicYAxisRot;
		ActiveCam.shadowed:=FALSE;

		NEW(S,[-0.1,  0.1,-0.1,1],0.1); S.SetColor(Col.yellow,TRUE); W.Add(S);
		NEW(S,[  0.1,-0.1,-0.1,1],0.3); S.SetColor(Col.red,TRUE);  W.Add(S);
		NEW(S,[  0,   -0.1,  0.1,1],0.2); S.SetColor(Col.blue,TRUE);  W.Add(S); S.selected:=TRUE;
		NEW(T,[0, -0.3, -0.3, 1], [0, -0.3, 0.3, 1], [-0.2, 0.3, -0.3, 1]); T.SetColor(Col.blue,TRUE); W.Add(T);

		NEW(Cy,[-0.4, -0.2, 0.1, 1], [0.35, 0.1, -0.1, 1], 0.06); Cy.SetColor(Col.yellow,TRUE); W.Add(Cy);
		NEW(T,[0, 0.3, 0.3, 1], [0, 0.3, -0.3, 1], [-0.2, -0.3, 0.3, 1]);  T.SetColor(Col.green,TRUE); W.Add(T);
		NEW(TH,[0.4, -0.4, 0.1, 1], [0.4, -0.1, 0.4, 1], [-0.4, -0.1, 0.4, 1], [-0.4, -0.4, 0.1, 1]); TH.SetColor(Col.blue,TRUE); W.Add(TH);

		(*Cam.Render; *)  (* single threaded version *)
		ActiveCam.SetNumberOfFrames(40);
		ActiveCam.SetState(rendering); (* Active Camera in own process *)
		
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		KernelLog.Int(ActiveCam.ticks, 8); KernelLog.String(" ticks for rendering"); context.out.Ln; context.out.Update;
	END TestDynamic;

	PROCEDURE TestCylinders*(context:Commands.Context);
	VAR Cam: Camera; ActiveCam:ActiveCamera;
		W:World; Cy: Cylinder;
		Win:Window;
	BEGIN
		NEW(W);
		W.DefaultLight;

		(* additional light, in addition to implicitdefault light *)
		W.lights.AddLight(LT2, Col.red, 0.3, FALSE);

		NEW(Win, 256,256, TRUE);
		NEW(ActiveCam,W);
		ActiveCam.SetWindow(Win);
		ActiveCam.SetNumberOfFrames(40);
		ActiveCam.Dynamic:=DynamicYAxisRot;

		NEW(Cy,[-0.6, -0.2, 0.1, 1], [0.1, 0.1, -0.6, 1], 0.06); Cy.SetColor(Col.yellow,TRUE); W.Add(Cy);
		NEW(Cy,[0.4, 0.3, -0.2, 1], [-0.6, -0.2, 0.1, 1] , 0.06); Cy.SetColor(Col.green,TRUE); W.Add(Cy);
		NEW(Cy,[0.1, 0.1, -0.6, 1], [0.4, 0.3, -0.2, 1], 0.06); Cy.SetColor(Col.blue,TRUE); W.Add(Cy);

		(*Cam.Render; *)  (* single threaded version *)
		ActiveCam.SetState(rendering); (* Active Camera in own process *)

		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});

		KernelLog.Int(ActiveCam.ticks, 8); KernelLog.String(" ticks for rendering"); context.out.Ln; context.out.Update;
	END TestCylinders;

	PROCEDURE TestPlanarArray*(context:Commands.Context);
	VAR Cam: Camera;
		W:World; 
		P:PlanarArray;
		matrix:ARRAY [*,*] OF FLOAT64;
		Win:Window;
	BEGIN
		NEW(W);
		W.DefaultLight;
		NEW(Win, 512,512, TRUE);
		NEW(Cam,W);
		Cam.SetWindow(Win);

		NEW(matrix, 256,256);
		NEW(P, [0.5, -0.4,-0.4,1], [0.5,0.4,-0.4,1], [0.5, -0.4,0.4,1], matrix, FALSE);
		W.Add(P);
		
		P.SetHitRegistration(TRUE,FALSE);
		Cam.Render;
		P.SetHitRegistration(TRUE,FALSE);
		
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		(* display sensor matrix here *)
		context.out.String("rendered "); context.out.Int(Cam.raycount, 10); context.out.String(" rays in "); context.out.Int(Cam.ticks, 8); context.out.String(" ticks."); context.out.Ln; context.out.Update;
	END TestPlanarArray;

	PROCEDURE TestMatrix*(context:Commands.Context);
	VAR Cam: ActiveCamera;
		data:ARRAY [*,*] OF Datatype;
		W:World;
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
		row, col, lenX, lenY:SIGNED32;
	BEGIN
		(* test data *)
		lenX:=20;lenY:=20;
		NEW(data,lenX,lenY);
		FOR row:=0 TO lenX-1 DO
			FOR col:=0 TO lenY-1 DO
				data[row,col]:= Mathe.cos((row-lenX DIV 2)/lenX*4)*Mathe.cos((col-lenY DIV 2)/lenX*4)
			END;
		END;

		(* create a world from data*)
		W:=WorldFromMatrix(data, 0.8, 0.5);
		W.DefaultLight;
		W.SetTime(-4); (*! to do: does not  work here yet  *)

		(* create a camera for this world *)
		NEW(Cam,W);
		Cam.shadowed:=FALSE;
		Cam.SetNumberOfFrames(10);

		(* create a display window for camera *)
		NEW(Win, 400,400, TRUE);
		Cam.SetWindow(Win);
		Cam.CreatePreview;

		(* this can be used to dynamically change camera over time *)
		Cam.Dynamic:=DynamicYAxisRot;
		W.SetTime(-4);

		(*Cam.Render; *)
		Cam.SetState(rendering);

		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
	END TestMatrix;

	(* render a patch of data.
	Data are delivered in a rectangular array of coordinates, defining a square array of rectangles which in turn are subdivided in two triangles.
	A coordinate with a fourth parameter of NaN, e.g. [0,0,0,Reals.NaN(0)] is skipped from display. This allows to use patches for representation of nonrectangular data.
	 *)
	PROCEDURE TestPatch*(context:Commands.Context);
	CONST pi=3.1415926;
	VAR 
		Cam:Camera;
		data:ARRAY [*,*,*] OF Datatype; (*ARRAY [*,*] OF Coordinate*)
		world:World;
		face:Patch;
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
		row, col, lenX, lenY:SIGNED32;
		alpha:Datatype;
		triangles: ARRAY [*,*,2] OF Triangle;
	BEGIN
		(* invent some test data *)
		lenX:=20;lenY:=10;
		NEW(data,lenY,lenX,4);
		FOR row:=0 TO lenY-1 DO
			FOR col:=0 TO lenX-1 DO
				alpha:=2*pi*col/(lenX-1);
				data[row,col]:= [0.3*Mathe.sin(alpha), 0.5*row/lenY-0.2, 0.3*Mathe.cos(alpha),1]; (*circular patch*)
			END;
		END;
		(*face shaping*)
		data[lenY-1,..,0]:=0; data[lenY-1,..,2]:=0; (*front*)
		data[lenY-2,..,0]:=0.7*data[lenY-2,..,0]; data[lenY-2,..,2]:=0.7*data[lenY-2,..,2];(*front*)
		data[lenY DIV 2-1,3*(lenX DIV 4)]:=data[lenY DIV 2-1,3*(lenX DIV 4)] .* [1.2,1,1.2,1];(*nose*)
		data[lenY DIV 2,3*(lenX DIV 4)]:=data[lenY DIV 2,3*(lenX DIV 4)] .* [1.1,1,1.1,1];(*nose*)
		data[lenY DIV 2-3,3*(lenX DIV 4)]:=data[lenY DIV 2-3,3*(lenX DIV 4)] .* [0.8,1,0.8,1];(*mouth*)
		data[lenY DIV 2,3*(lenX DIV 4)+2]:=data[lenY DIV 2,3*(lenX DIV 4)+2] .* [0.8,1,0.8,1];(*eye*)
		data[lenY DIV 2,3*(lenX DIV 4)-2]:=data[lenY DIV 2,3*(lenX DIV 4)-2] .* [0.8,1,0.8,1];(*eye*)
		data[0,..,0]:=0.7*data[0,..,0]; data[0,..,2]:=0.7*data[0,..,2];(*neck*)
		
		NEW(face,data,1,triangles);(* create patch from data array. 'triangle arra' is optional for export *)
		(*face.Set2Colors(Col.yellow,Col.blue,TRUE);*)(*show triangles in alternating colors*)
		face.SetColor(Col.yellow,TRUE);
		NEW(world); world.DefaultLight; world.Add(face); (* create a world from data*)		
		NEW(Cam,world);(* create a camera for this world *)
		Cam.shadowed:=FALSE;
		NEW(Win, 400,400, TRUE); Cam.SetWindow(Win);(* create a display window for camera *)
		Cam.CreatePreview;
		Cam.Render; 
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
	END TestPatch;
	
	PROCEDURE TestReproducibility*(context:Commands.Context);
	CONST 
		ReferenceCRCSSE= -655667989; (*using SSE3.HomogenousVectors.Mod and SSE3.Colors.Mod*)
		ReferenceCRC=-1983424108 ; (*using HomogenousVectors.Mod and Colors.Mod*) (*! explore why these values differ -> rounding ?*)
	VAR Cam: Camera;
		W:World; S:Sphere; T:Triangle; TH: Tetrahedron; Cy: Cylinder;
		Win:Window; 
	BEGIN
		NEW(W);
		W.DefaultLight;
		W.lights.AddLight(LT2, Col.red, 0.3, FALSE);
		NEW(Win, 512,512, FALSE);
		NEW(Cam,W);
		Cam.SetWindow(Win);
		Cam.computeHash:=TRUE;
		
		NEW(S,[-0.2,  0.2,-0.2,1],0.1); S.SetColor(Col.darkyellow,TRUE); S.refractive:=TRUE; S.refractIndex:=1.4; W.Add(S);
		NEW(S,[  0.1,-0.1,-0.1,1],0.3); S.SetColor(Col.red,TRUE); S.reflective:=TRUE; W.Add(S);
		NEW(S,[  0,   -0.2,  0.2,1],0.2); S.SetColor(Col.blue,TRUE);  S.reflective:=TRUE; W.Add(S); (*S.selected:=TRUE;*)
		NEW(T,[0, -0.3, -0.3, 1], [0, -0.3, 0.3, 1], [-0.2, 0.3, -0.3, 1]); T.SetColor(Col.blue,TRUE); W.Add(T);
		NEW(Cy,[-0.4, -0.2, 0.1, 1], [0.35, 0.1, -0.1, 1], 0.06); Cy.SetColor(Col.yellow,TRUE); Cy.reflective:=TRUE; W.Add(Cy);
		NEW(T,[0, 0.3, 0.3, 1], [0, 0.3, -0.3, 1], [-0.2, -0.3, 0.3, 1]);  T.SetColor(Col.green,TRUE); T.reflective:=TRUE; W.Add(T);
		NEW(TH,[0.4, -0.4, 0.1, 1], [0.4, -0.1, 0.4, 1], [-0.4, -0.1, 0.4, 1], [-0.4, -0.4, 0.1, 1]); TH.SetColor(Col.blue,TRUE); W.Add(TH);

		Cam.Render;
		IF (Cam.crc.Get()=ReferenceCRC) THEN 			context.out.String("VolumeRaytracer OK, ticks= "); context.out.Int(Cam.ticks,0);
		ELSIF  (Cam.crc.Get()=ReferenceCRCSSE) THEN 	context.out.String("VolumeRaytracer  (SSE) OK, ticks= "); context.out.Int(Cam.ticks,0);
		ELSE 
			context.result := Commands.CommandError; 
			context.out.String("VolumeRaytracer Failed, CRC= "); context.out.Int(Cam.crc.Get(),0); context.out.String("; ticks= "); context.out.Int(Cam.ticks,0);
		END;
		context.out.Ln; 
		context.out.Update;
	END TestReproducibility;
	
	PROCEDURE TestPatchB*(context:Commands.Context);
	VAR 
		Cam:Camera;
		world:World;
		Win:Window; (* or, for non-interactive window: Win: WM.BufferWindow *)
		patch:PatchB; m:Map;
		i,j:SIZE; 
	BEGIN
		(* invent some test data *)
		NEW(m, 16,16,4);
		FOR i:=0 TO LEN(m,0)-1 DO
			FOR j:=0 TO LEN(m,1)-1 DO
				m[i,j,..]:=[0.1+0.3*rand.Uniform(), i/20-0.4,j/20-0.4,1.0];
			END;
		END;
		(*face shaping*)
		NEW(patch, m, context.out); 
		patch.SetColor(Col.yellow,TRUE);
		NEW(world); world.DefaultLight; 
		world.Add(patch); (* create a world from data*)		
		NEW(Cam,world);(* create a camera for this world *)
		Cam.shadowed:=FALSE;
		Cam.ambient:=0.5;
		NEW(Win, 400,400, TRUE); Cam.SetWindow(Win);(* create a display window for camera *)
		Cam.CreatePreview;
		Cam.Render; 
		WM.ExtAddWindow(Win, 128,128, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
	END TestPatchB;
	
	PROCEDURE TestInside*(context:Commands.Context);
	CONST A=[0,0,0,1];
		B=[1,0,0,1];
		C=[0,1,0,1];
		D=[0,0,1,1];
		P0=[0.1,0.1,0.1,1];
		P1=[-0.1,0.1,0.1,1];
		P2=[0.1,-0.1,0.1,1];
		P3=[0.1,0.1,-0.1,1];
	VAR t: Tetrahedron; c:Cylinder;
	BEGIN
		NEW(t,A,B,C,D);
		IF t.Inside(P0) THEN context.out.String("in ") ELSE context.out.String("out ") END;
		IF t.Inside(P1) THEN context.out.String("in ") ELSE context.out.String("out ") END;
		IF t.Inside(P2) THEN context.out.String("in ") ELSE context.out.String("out ") END;
		IF t.Inside(P3) THEN context.out.String("in ") ELSE context.out.String("out ") END;
		context.out.Ln;
		
		NEW(c,A,B,0.2);
		IF c.Inside(P0) THEN context.out.String("in ") ELSE context.out.String("out ") END;
		IF c.Inside(P1) THEN context.out.String("in ") ELSE context.out.String("out ") END;
		IF c.Inside(P2) THEN context.out.String("in ") ELSE context.out.String("out ") END;
		IF c.Inside(P3) THEN context.out.String("in ") ELSE context.out.String("out ") END;
		context.out.Ln;
	END TestInside;
	
	PROCEDURE TestLookAt*(context:Commands.Context);
	VAR x,y,z:SIGNED32; T:AffineTransform; P:Coordinate;
	BEGIN
		T:=Identity;
		IF context.arg.GetInteger(x, FALSE) THEN END;
		IF context.arg.GetInteger(y, FALSE) THEN END;
		IF context.arg.GetInteger(z, FALSE) THEN END;
		P:=[x,y,z,1.0];
		T:=LookAt(T,P);
		context.out.FloatFix(T[0,0],14,2,0); context.out.FloatFix(T[0,1],14,2,0); context.out.FloatFix(T[0,2],14,2,0); context.out.FloatFix(T[0,3],14,2,0); context.out.Ln;
		context.out.FloatFix(T[1,0],14,2,0); context.out.FloatFix(T[1,1],14,2,0); context.out.FloatFix(T[1,2],14,2,0); context.out.FloatFix(T[1,3],14,2,0); context.out.Ln;
		context.out.FloatFix(T[2,0],14,2,0); context.out.FloatFix(T[2,1],14,2,0); context.out.FloatFix(T[2,2],14,2,0); context.out.FloatFix(T[2,3],14,2,0); context.out.Ln;
		context.out.FloatFix(T[3,0],14,2,0); context.out.FloatFix(T[3,1],14,2,0); context.out.FloatFix(T[3,2],14,2,0); context.out.FloatFix(T[3,3],14,2,0); context.out.Ln;
		context.out.Ln;
	END TestLookAt;
	
	PROCEDURE FuzzyZero*():Vector;
	BEGIN
		RETURN [(s.Uniform()-0.5)/10000, (s.Uniform()-0.5)/10000, (s.Uniform()-0.5)/10000, 0]
	END FuzzyZero;
	
PROCEDURE RemoveWindows*(context:Commands.Context); 
VAR manager:WM.WindowManager; w,remove:WM.Window; i:SIGNED32;
BEGIN {EXCLUSIVE}
	IF (context=NIL) OR (~context.arg.GetInteger(i,FALSE)) THEN i:=MAX(SIGNED32) END;
	manager:=WM.GetDefaultManager();
	manager.lock.AcquireWrite;
	w:=manager.GetFirst();
	WHILE (w#NIL) & (i>0) DO
		remove:=w;
		w:=manager.GetNext(w);
		IF (remove#NIL)&(remove IS Window) THEN manager.Remove(remove); DEC(i) END;
	END;
	manager.lock.ReleaseWrite;
END RemoveWindows;
(*
	PROCEDURE -V.CastVector(a,b,c,d: FLOAT32):Vector;  (*VARIANT C: funktioniert, wenn im Modul VolumeRaytracer.Mod platziert*) 
    CODE{SYSTEM.i386, SYSTEM.SSE2}
          MOV ECX, [ESP+RESULT]
          MOVUPS XMM0, [ESP+d] ;
 		SHUFPS XMM0, XMM0, 01BH    	  ; 00 01 10 11  rearrange elements of A, because parameter passing is from right to left
          MOVUPS [ECX], XMM0 ;
          ADD  ESP, 20
    END V.CastVector;
*)
(*
PROCEDURE CastVector(CONST a,b,c,d: FLOAT32):Vector; (*inlining leads  traps in compiler*)
    BEGIN
          CODE
#IF I386 THEN
             MOVUPS v, [EBP + d] ; 32bit -- can be now made independent with Florian's conditional compilation
#ELSIF AMD64 THEN
             MOVUPS v, [RBP + d] ; 32bit -- can be now made independent with Florian's conditional compilation
#END
             SHUFPS v, v, 01BH          ; 00 01 10 11  rearrange elements of A, because parameter passing is from right to left            
          WITH
          OUT
              RETURN v (* this implicitly defines v as register for result type Vector *)
          END;
    END CastVector; *)

PROCEDURE RemoveAllWindows;
BEGIN
	RemoveWindows(NIL)
END RemoveAllWindows;

BEGIN
	Streams.OpenWriter(log, KernelLog.Send);
	NEW(rand);
	threshold:=threshold0;
	thresholds:=[threshold0,threshold0,threshold0,0];

	NEW(s);
	Raster.InitMode(SrcCopy,Raster.srcCopy);
	
	(*origin:=Origin;*)
	goldenratio :=  (1+ Mathe.sqrt(5))/2;
	
	NaN:=MAX(Datatype); (*NaN:=Reals.NaN(0);*) (* avoid NaN handling overhead ?*)
	Invalid:=[0,0,0,NaN];
	PlusInfinity:=[MAX(Datatype),MAX(Datatype),MAX(Datatype),1];
	MinusInfinity:=[MIN(Datatype),MIN(Datatype),MIN(Datatype),1];
	InitBox(emptyBox, PlusInfinity , MinusInfinity); emptyBox.radius:=0;
	
	shapeType:=Strings.NewString("Shape");
	lineType:=Strings.NewString("Line");
	coordinateType:=Strings.NewString("CoordinateSystem");
	planeType:=Strings.NewString("Plane");
	triangleType:=Strings.NewString("Triangle");
	imageType:=Strings.NewString("Image");
	circleType:=Strings.NewString("Circle");
	planarArrayType:=Strings.NewString("PlanarArray");
	volumeShapeType:=Strings.NewString("VolumeShape");
	sphereType:=Strings.NewString("Sphere");
	cylinderType:=Strings.NewString("Cylinder");
	tetrahedronType:=Strings.NewString("Tetrahedron");
	patchType:=Strings.NewString("Patch");
	splinePatchType:=Strings.NewString("SplinePatch");
	blockType:=Strings.NewString("Block");
	brickType:=Strings.NewString("Brick");
	
	(*alternative light transform*)
	LT2:=[[Mathe.cos(-alpha)*Mathe.cos(theta),-Mathe.sin(-alpha),Mathe.sin(theta),-1],
	 	    [Mathe.sin(-alpha),Mathe.cos(-alpha),0,-1],
		    [-Mathe.sin(theta),0,Mathe.cos(theta),1],
		    [0.0 ,0,0,1]];
	
	Modules.InstallTermHandler(RemoveAllWindows);
END VolumeRaytracer.

Compiler.Compile
	SSE3.Colors.Mod 
	SSE3.HomogenousVectors.Mod
	VolumeRaytracer.Mod 
	~
Compiler.Compile
	Colors.Mod (*Colors.Mod*)
	HomogenousVectors.Mod
	VolumeRaytracer.Mod 
	~
System.FreeDownTo VolumeRaytracer ~
System.FreeDownTo Colors ~
System.FreeDownTo HomogenousVectors ~

System.FreeDownTo FoxSyntaxTree~ 

VolumeRaytracer.RemoveWindows 5 ~
WMMatrix.RemoveWindows 5 ~

VolumeRaytracer.TestCoords~
VolumeRaytracer.TestDynamic~
VolumeRaytracer.TestCylinders~
VolumeRaytracer.TestStatic~
VolumeRaytracer.TestCutout~
VolumeRaytracer.TestStaticDepth~
VolumeRaytracer.TestMirrorLens~
VolumeRaytracer.StoreMirrorLens~
VolumeRaytracer.TestMatrix~
VolumeRaytracer.TestPatch~
VolumeRaytracer.TestPatchB~
VolumeRaytracer.TestPhong~
VolumeRaytracer.TestSphere ~
VolumeRaytracer.TestHelix~ 
VolumeRaytracer.TestTriangle
VolumeRaytracer.TestQuadrangle
VolumeRaytracer.TestImage
VolumeRaytracer.TestPyramid
VolumeRaytracer.TestBlock
VolumeRaytracer.TestTetra
VolumeRaytracer.TestInside
VolumeRaytracer.TestTransform
VolumeRaytracer.TestReproducibility ~
VolumeRaytracer.TestLookAt 1 0 0 ~
VolumeRaytracer.TestLookAt -1 0 0 ~
VolumeRaytracer.TestLookAt 0 1 0 ~
VolumeRaytracer.TestLookAt 0 0 1 ~ 
VolumeRaytracer.TestLookAt 1 1 1 ~
VolumeRaytracer.TestLookAt -1 -1 -1 ~

Compiler.Compile FoxIntermediateBackend.Mod ~

Compile with option --profile
FoxProfiler.Report ~
FoxProfiler.Report time ~
FoxProfiler.Report calls ~
FoxProfiler.Report name ~
FoxProfiler.Report brut ~
FoxProfiler.Report time all ~
FoxProfiler.Reset ~

FoxProfiler on low-end notebook:
---  FoxProfiler timing report ----
processes= 3
name                                                                            	calls     	time [%]          	brut [%]          	time/call 	brut/call 
VolumeRaytracer.Camera.RenderRay                                                441822	  1.267E+001[31.4]	  1.432E+002[40.3]	  2.9E-005	  3.2E-004  ????????????
VolumeRaytracer.TestMirrorLens                                                           1	  6.904E-004[ 0.0]	  8.188E+001[23.1]	  6.9E-004	  8.2E+001
VolumeRaytracer.Camera.Render                                                            1	  1.404E+000[ 3.5]	  8.187E+001[23.1]	  1.4E+000	  8.2E+001
VolumeRaytracer.Shape.Intersect                                                     875244	  5.950E+000[14.7]	  2.048E+001[ 5.8]	  6.8E-006	  2.3E-005
VolumeRaytracer.Triangle.Intersect                                                 3967638	  7.489E+000[18.5]	  8.542E+000[ 2.4]	  1.9E-006	  2.2E-006
VolumeRaytracer.Cylinder.Intersect                                                  774848	  2.970E+000[ 7.4]	  7.831E+000[ 2.2]	  3.8E-006	  1.0E-005
VolumeRaytracer.Sphere.Intersect                                                  2130186	  4.310E+000[10.7]	  5.631E+000[ 1.6]	  2.0E-006	  2.6E-006
VolumeRaytracer.Quadratic                                                           774848	  1.373E+000[ 3.4]	  1.373E+000[ 0.4]	  1.8E-006	  1.8E-006
VolumeRaytracer.CreateRay                                                           613100	  1.088E+000[ 2.7]	  1.088E+000[ 0.3]	  1.8E-006	  1.8E-006
VolumeRaytracer.Shape.ColorAt                                                      559110	  9.592E-001[ 2.4]	  9.592E-001[ 0.3]	  1.7E-006	  1.7E-006
VolumeRaytracer.Viewer.RasterSetPixel                                             262144	  5.149E-001[ 1.3]	  5.149E-001[ 0.1]	  2.0E-006	  2.0E-006
VolumeRaytracer.Camera.InitRay                                                     263168	  5.104E-001[ 1.3]	  5.104E-001[ 0.1]	  1.9E-006	  1.9E-006
VolumeRaytracer.Light.Specular                                                      222437	  4.236E-001[ 1.0]	  4.236E-001[ 0.1]	  1.9E-006	  1.9E-006
VolumeRaytracer.Light.Diffuse                                                       222437	  4.101E-001[ 1.0]	  4.101E-001[ 0.1]	  1.8E-006	  1.8E-006
VolumeRaytracer.Reflect                                                             154074	  2.685E-001[ 0.7]	  2.685E-001[ 0.1]	  1.7E-006	  1.7E-006
VolumeRaytracer.Refract                                                              25604	  4.769E-002[ 0.1]	  4.769E-002[ 0.0]	  1.9E-006	  1.9E-006
VolumeRaytracer.Window.Init                                                              1	  1.174E-002[ 0.0]	  1.174E-002[ 0.0]	  1.2E-002	  1.2E-002
VolumeRaytracer.CreatePlane                                                            512	  1.187E-003[ 0.0]	  1.187E-003[ 0.0]	  2.3E-006	  2.3E-006
VolumeRaytracer.Tetrahedron.Init                                                         1	  2.216E-005[ 0.0]	  3.090E-004[ 0.0]	  2.2E-005	  3.1E-004
VolumeRaytracer.Plane.Init                               	                                6	  3.168E-005[ 0.0]	  2.239E-004[ 0.0]	  5.3E-006	  3.7E-005
VolumeRaytracer.Triangle.InitGeometry                                                    6	  3.094E-005[ 0.0]	  1.382E-004[ 0.0]	  5.2E-006	  2.3E-005
VolumeRaytracer.Shape.AddChild                                                           4	  2.700E-005[ 0.0]	  9.146E-005[ 0.0]	  6.8E-006	  2.3E-005
VolumeRaytracer.Sphere.Init                                                              3	  1.694E-005[ 0.0]	  7.306E-005[ 0.0]	  5.6E-006	  2.4E-005
VolumeRaytracer.Shape.SetColor                                                          22	  4.486E-005[ 0.0]	  6.620E-005[ 0.0]	  2.0E-006	  3.0E-006
VolumeRaytracer.Plane.InitGeometry                                                       6	  2.106E-005[ 0.0]	  5.330E-005[ 0.0]	  3.5E-006	  8.9E-006
VolumeRaytracer.Viewer.CreatePreview                                                     1	  4.138E-005[ 0.0]	  4.138E-005[ 0.0]	  4.1E-005	  4.1E-005
VolumeRaytracer.Camera.Initialize                                                        1	  5.680E-006[ 0.0]	  3.756E-005[ 0.0]	  5.7E-006	  3.8E-005
VolumeRaytracer.InitBox                                  	                               21	  3.710E-005[ 0.0]	  3.710E-005[ 0.0]	  1.8E-006	  1.8E-006
VolumeRaytracer.World.DefaultLight                                                       1	  6.020E-006[ 0.0]	  3.236E-005[ 0.0]	  6.0E-006	  3.2E-005
VolumeRaytracer.Sphere.InitGeometry                                                     3	  1.206E-005[ 0.0]	  2.878E-005[ 0.0]	  4.0E-006	  9.6E-006
VolumeRaytracer.Viewer.Default                                                           1	  1.280E-005[ 0.0]	  2.814E-005[ 0.0]	  1.3E-005	  2.8E-005
VolumeRaytracer.Cylinder.Init                            	                                1	  5.360E-006[ 0.0]	  2.326E-005[ 0.0]	  5.4E-006	  2.3E-005
VolumeRaytracer.Light.Default                                                            1	  8.380E-006[ 0.0]	  2.256E-005[ 0.0]	  8.4E-006	  2.3E-005
VolumeRaytracer.ValidCoordinate                                                          8	  1.386E-005[ 0.0]	  1.386E-005[ 0.0]	  1.7E-006	  1.7E-006
VolumeRaytracer.World.Init                                                               1	  1.304E-005[ 0.0]	  1.304E-005[ 0.0]	  1.3E-005	  1.3E-005
VolumeRaytracer.World.Add                                                                7	  1.258E-005[ 0.0]	  1.258E-005[ 0.0]	  1.8E-006	  1.8E-006
VolumeRaytracer.Viewer.SetWindow                                                       1	  3.880E-006[ 0.0]	  1.250E-005[ 0.0]	  3.9E-006	  1.3E-005
VolumeRaytracer.Viewer.SetTime                                                           1	  5.520E-006[ 0.0]	  1.122E-005[ 0.0]	  5.5E-006	  1.1E-005
VolumeRaytracer.Light.SetTime                                                            1	  4.580E-006[ 0.0]	  1.034E-005[ 0.0]	  4.6E-006	  1.0E-005
VolumeRaytracer.Window.PointerMove                                                   2	  9.720E-006[ 0.0]	  9.720E-006[ 0.0]	  4.9E-006	  4.9E-006
VolumeRaytracer.Tetrahedron.InitGeometry                                              1	  3.700E-006[ 0.0]	  9.260E-006[ 0.0]	  3.7E-006	  9.3E-006
VolumeRaytracer.Cylinder.InitGeometry                                                    1	  3.560E-006[ 0.0]	  8.920E-006[ 0.0]	  3.6E-006	  8.9E-006
VolumeRaytracer.Light.AddLight                                                           1	  5.920E-006[ 0.0]	  5.920E-006[ 0.0]	  5.9E-006	  5.9E-006
VolumeRaytracer.Viewer.SetRaster                                                         1	  4.960E-006[ 0.0]	  4.960E-006[ 0.0]	  5.0E-006	  5.0E-006
VolumeRaytracer.Dynamic0                                                                 2	  4.000E-006[ 0.0]	  4.000E-006[ 0.0]	  2.0E-006	  2.0E-006
---------------------------
SUM                                                                               11287280	  4.0E+001	  3.5E+002	  3.57926761629E-006  3.14512402510E-005



Performance on Notebook Atom N270, 1.6 GHz:
currently,
an inlined SSE inner product of 3components of a 4Vector in a loop costs about 3.2 E-8 seconds per iteration (excluding iterator)
an empty loop costs about 5.0 E-9 seconds/iteration
Dummy procedure One():Datatype also costs 3.7E-7 seconds/call
=> performance seems largely dominated by procedure call overhead


Operator inlining: ---------------
(1) man muss den Code im Oberon-Code als CODE-Section hinschreiben. 
	Das Code-Segment darf nicht direkt verwendet werden (Compiler erkennt daran, wie geinlined wird: echtes Inlining gibt es nur mit Oberon-Code!
(2) Register werden auf expressions gemapped via IN und OUT statements.
(3) Wenn ein Register zurueckgegeben werden soll, so muss man RETURN (registername) in die OUT section schreiben.
Der Rest ist Magie.

Trick zum Ansehen des emittierten Codes im Decoder:
FSTools.CopyFiles -o (Modulname).Obw => (Modulename).Abx ~
und dann (Modulename).Abx mit Mitte-Rechts klick öffnen. 
-----------------------


Do 2 lines intersect in 3D space ?
this is actually a rather easy operation. lets look at some basic properties of lines / vectors in 3D space:

1. If two lines intersect at a single point, then there must be exactly one plane in which the two lines are co-planar. This is pretty trivial to prove, but I won't bother here, because you can google to find out that two vectors that extend from a common point define a single plane.
2. If you take the cross-product of two vectors, the resulting vector is guaranteed to be perpendicular to both lines (this is a basic property of a cross-product). If the two lines intersect, then this cross-product will be the normal vector to the plane in which both lines lie.
3. Now transform (rotate) yours space such that your z-axis becomes parallel to the normal vector of that plane.
Now, the parametric equation for a line in 3D space is this:
(x, y, z) = (xo, yo, zo) + k(xd, yd, zd)
After you have transformed your space, you will notice that the equation of each line will now be
(x, y, z) = (xo, yo, zo) + k(xd, yd, 0)
If zo is equal for both lines, then the two lines intersect. Otherwise, the two lines do not intersect.
if the intersection exists, then to solve for it, you ignore the z coordinate, and treat it like a two dimensional system:
(x, y) = (xo, yo) + k(xd, yd)
you can use the basic 2D formula y - yo = m(x - xo), or y = m(x - xo) + yo
you can calculate m = yd / xd.
which simplifies to y = mx -mxo + yo, or 0 = mx - y + (yo - mxo)
you now have two equations of the form Ax + By + C = 0.
From there, you can use Cramer's rule to find the intersection of the two lines.

It sounds kind of complicated when you read it as I have presented it, but it's actually extremely easy to write a program for, because each step is simple mathematic operation with basically no decisions involved (hence no if-structures, except at the one point where you actually need to determine if the lines intersect).
So to reiterate, the steps required are:
1. Check if lines are parallel. If yes, check if they are the same line, and then stop.
2. If not parallel, cross-multiply the direction vectors of each line.
3. Rotate your space such that z is parallel with cross-product of lines
i. dot-product of z axis (0, 0, 1) with cross-product of lines gives angle*
ii. cross-product of z axis (0, 0, 1) with cross-product of lines gives axis of rotation.
iii. rotate your lines (i.e. point and direction vector) about that axis by negative of ange determined in (i).
4. if z value of points from both lines is the different, no solution. stop.
5. otherwise, apply Cramer's rule.
6. done.

* obtaining the angle of rotation with the dot product relies on the angle being less than 90 degrees, so check if z value of normal vector is + or -, and then perform dot product and cross-product on appropriate + or - z vector.

Fast approximation or arc cosine:
Another option would be to store the coeffecients of 4 cubics in a 4x4 matrix. The cubics could be fit to acos on intervals spanning [0,1], and you could use acos(-x) = -acos(x)+pi for [-1,0]. You could also have the knots of the polynomials distributed cubically so the higher curvature near 1 would be fit to a polynomial with a smaller interval. The function that converts a point in the domain to an index could reuse the evaluation of x*x*x for the polynomial. Something like this where mat contains the polynomial coeffecients:

sgn = sign(x);
x = abs(x);
x2 = x*x;
x3 = x*x2;
t = {1, x, x2, x3};
i = floor(4*x3);
arccos = dot(mat(i), t);
return sgn * arccos - min(0, sgn * PI);

I don't know how it would compare to texture lookup, but at least no division is required as in the Pade approximation.
System.FreeDownTo FoxSyntaxTree ~ 
