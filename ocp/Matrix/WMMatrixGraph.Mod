MODULE WMMatrixGraph ;	(**  AUTHOR "Patrick Hunziker"; PURPOSE "Graph Rendering of data from matrices, lists, functions";  **)
(*a matrix is considered as a group of curves*)
IMPORT Modules, Commands, WM:=WMWindowManager, WMGraphics, WMRectangles, Strings, Models, MathL;

CONST
	Version*=1;

	(** line styles *)
	line* = 0;
	dot* = 1;

	(** dataorder: organisation/meaning of data in matrix *)
	YYYY* = 0;   (** 1D graphs *)
	XYYY* = 1;   (** first row is X, other rows are Y *)
	XYXY* = 2;   (** XY data pairwise in matrix rows *)
	XYZ* = 3;   (** mesh display with col=X, row=Y, value=Z *)
	FUNC*= 4; (** function model*)

TYPE
		Datatype*=FLOAT64;
		Matrix*=ARRAY [*,*] OF Datatype;
		RealPoint=ARRAY [*] OF Datatype;
		IntPoint=ARRAY [*] OF SIGNED32;

TYPE Point* = POINTER TO RECORD
				x,y: Datatype;
				next: Point
			END;

(* Model components *)
TYPE Model*=OBJECT(Models.Model);
		VAR minx,maxx,miny,maxy: Datatype;
		PROCEDURE Bounds(autoscaleX, autoscaleY, autoscaleZ: BOOLEAN; VAR minx,maxx,miny,maxy: Datatype);
		BEGIN
			(*evaluate here if necessary*)
			(*then report data*)
			minx:=SELF.minx; maxx:=SELF.maxx; miny:=SELF.miny; maxy:=SELF.maxy;
		END Bounds;
	END Model;

TYPE MatrixModel*= OBJECT (Model)
		VAR matrix:Matrix;
			dataorder:SIGNED32;
	END MatrixModel;

TYPE OldMatrixModel*= OBJECT (Model)
		VAR matrix:POINTER TO ARRAY OF ARRAY OF Datatype;
			dataorder:SIGNED32;
	END OldMatrixModel;

TYPE FunctionModel*= OBJECT (Model)
		PROCEDURE &Init; BEGIN minx:=0; miny:=-1; maxx:=4; maxy:=1 END Init;
		PROCEDURE Value(x:Datatype): Datatype;
		BEGIN
			RETURN MathL.sin(2*x)
		END Value;
	END FunctionModel;

TYPE PointListModel*= OBJECT(Model)
		VAR p: Point;
	END PointListModel;

(* graphical components *)
TYPE Curve= OBJECT
	VAR
		linecol*: SIGNED32;
		linestyle*: SIGNED32;
		beg*, end*: SIGNED32;
		next: Curve;
	END Curve;

TYPE Graph= OBJECT
	VAR
		model* : Models.Model;
		curves*: Curve;
		autoscaleX*, autoscaleY*,autoscaleZ*: BOOLEAN;
		X0, Y0, Z0, W, H, Z:SIGNED32;
		minx, miny, maxx, maxy, scalex,scaley :FLOAT64;
	END Graph;

TYPE Window*= OBJECT (WM.BufferWindow)
	VAR
		model: MatrixModel; (*! to do: drop this model and exclusively use graph.model *)
		graph: Graph;
		width,height:SIGNED32;
		projection:Matrix;
		hightclue, depthclue:BOOLEAN;
		windowposX,windowposY:SIGNED32;
		background:SIGNED32;

	PROCEDURE &Create*(width,height:SIGNED32; backgroundRGBA: SIGNED32; CONST title:ARRAY OF CHAR);
	BEGIN
		SELF.width:=width; SELF.height:=height;
		SELF.background:=backgroundRGBA;
		Init(width, height, TRUE);
		(*projection:=[[0.9, 0.1, 0],[-0.1,0.9,0.1],[0,-0.1,0.9]];  default projection *)
		hightclue:=TRUE; depthclue:=TRUE;
		SetTitle(Strings.NewString(title));
		windowposX:=100; windowposY:=100;

		NEW(graph);
		graph.X0 := width DIV 10; graph.W:= width-2*graph.X0;
		graph.Y0:= height DIV 10; graph.H:=height-2*graph.Y0;
		graph.autoscaleX:=TRUE; graph.autoscaleY:=TRUE; graph.autoscaleZ := TRUE;

		Clear;
	END Create;

	PROCEDURE Show*;
	BEGIN
		WM.ExtAddWindow(SELF, windowposX, windowposY, {WM.FlagFrame,WM.FlagClose,WM.FlagMinimize});
		(*WM.DefaultAddWindow(SELF);*)
	END Show;

	PROCEDURE Clear*;
	BEGIN
		canvas.Fill(WMGraphics.MakeRectangle(0, 0, width, height), background, WMGraphics.ModeSrcOverDst)
	END Clear;

	PROCEDURE AllocateCurves(n:SIZE);
	VAR curve:Curve; i:SIZE;
	BEGIN
		graph.curves:=NIL;
		FOR i:=0 TO n-1 DO
			NEW(curve); curve.next:=graph.curves;  graph.curves:=curve;
			curve.linecol:= SIGNED32(i * 011000000H +077FF00H-i*01100H+ 077H);
		END;
	END AllocateCurves;

	PROCEDURE SetModel(model: ANY);
	BEGIN
		IF model IS MatrixModel THEN
			SELF.model:=model(MatrixModel); (*! keeping model at a single place would be more consistent ...*)
			graph.model:=SELF.model;
			AllocateCurves(LEN(SELF.model.matrix,0))
		ELSIF model IS OldMatrixModel THEN graph.model := model(Model);
		ELSIF model IS FunctionModel THEN graph.model:= model(Model);
		ELSIF model IS PointListModel THEN	graph.model := model(Model);
		END;
	END SetModel;

	PROCEDURE Set*(CONST data:Matrix);
	BEGIN
		NEW(model); model.matrix:=data;
		graph.model:=model; (*! keeping model at a single place would be more consistent ...*)
		graph.curves:=NIL;
		AllocateCurves(LEN(SELF.model.matrix,0))
	END Set;

	PROCEDURE SetProjection*(CONST projection:  Matrix);
	BEGIN
		IF LEN(projection,0)=3 THEN SELF.projection:= projection ELSE SELF.projection:=[[1,0,0],[0,1,0],[0,0,1]] END;
	END SetProjection;

	PROCEDURE SetDataorder*(dataorder:SIGNED32);
	VAR func: FunctionModel;
	BEGIN

		IF dataorder=FUNC THEN NEW(func); graph.model:=func; AllocateCurves(1);
		ELSIF graph.model IS MatrixModel THEN graph.model(MatrixModel).dataorder:=dataorder;
		END;
	END SetDataorder;

	PROCEDURE Render*;
	VAR
		(* 2D*)
		i,j:SIZE;
		c: Curve;
		(* 3D*)
		x,y:SIZE;
		depth,col:SIGNED32;
		x0,y0,z0:FLOAT64;
		p,len:RealPoint; p0,p1: IntPoint;
		scale:FLOAT64; zscale,zrange,minz: FLOAT64;
		(*function*)
		step:Datatype;
		steps: SIGNED32;
		error: ARRAY 64 OF CHAR;
		oldp,newp:Point;
	BEGIN
		IF (graph=NIL) OR (graph.model=NIL) THEN COPY("WMMatrixGraph.Window.Render: no graph/model set",error); 	HALT(200); END;
		graph.model(Model).Bounds(graph.autoscaleX, graph.autoscaleY, graph.autoscaleZ, graph.minx, graph.maxx, graph.miny, graph.maxy);
		graph.scalex:= graph.W/(graph.maxx-graph.minx);
		graph.scaley:=graph.H/(graph.maxy-graph.miny);

		IF graph.model IS PointListModel THEN
				oldp:=graph.model(PointListModel).p;
				WHILE oldp.next#NIL DO
					newp:=oldp.next;
					canvas.Line(graph.X0+ENTIER ((oldp.x-graph.minx)*graph.scalex), height - graph.Y0 -ENTIER ((oldp.y-graph.miny)*graph.scaley),
								graph.X0+ENTIER ((newp.x-graph.minx)*graph.scalex), height-graph.Y0-ENTIER ((newp.y-graph.miny)*graph.scaley),
								c.linecol, WMGraphics.ModeSrcOverDst);
					oldp:=newp;
				END;
		ELSIF graph.model IS FunctionModel THEN
				steps:=20;
				step:=(graph.maxx-graph.minx)/steps;
				c:=graph.curves;
				FOR i:=0 TO steps-2 DO (* to do: scaling issues in x .. *)
					canvas.Line(graph.X0+ENTIER ((i*step)*graph.scalex), 	 height - graph.Y0 - ENTIER ((graph.model(FunctionModel).Value(i*step+graph.minx)-graph.miny)*graph.scaley),
								graph.X0+ENTIER (((i+1)*step)*graph.scalex), height - graph.Y0 - ENTIER ((graph.model(FunctionModel).Value((i+1)*step+graph.minx)-graph.miny)*graph.scaley),
								c.linecol, WMGraphics.ModeSrcOverDst);
				END;
		ELSIF graph.model IS MatrixModel THEN
			CASE graph.model(MatrixModel).dataorder OF
				YYYY: (*all rows contain curve Y data*)
					IF graph.autoscaleX THEN
						graph.minx:=0;
						graph.maxx:=LEN(model.matrix,1)-1;
						graph.scalex:= graph.W/(graph.maxx-graph.minx);
					END;
					IF graph.autoscaleY THEN
						graph.miny:=MIN(model.matrix);
						graph.maxy:=MAX(model.matrix);
						graph.scaley:=graph.H/(graph.maxy-graph.miny);
					END;
					c:=graph.curves;
					FOR j:=0 TO LEN(model.matrix,0)-1 DO
						FOR i:=0 TO LEN(model.matrix,1)-2 DO
							canvas.Line(ENTIER((i-graph.minx)*graph.scalex)+graph.X0, height - graph.Y0 -ENTIER ((model.matrix[j,i]-graph.miny)*graph.scaley),
										ENTIER((i-graph.minx+1)*graph.scalex)+graph.X0, height-graph.Y0-ENTIER ((model.matrix[j,i+1]-graph.miny)*graph.scaley),
										c.linecol, WMGraphics.ModeSrcOverDst);
						END;
						c:=c.next;
					END;
				| XYXY: (* a number of row pairs containing X,Y data for each point*)
					IF graph.autoscaleX THEN
						graph.minx:=MIN(model.matrix[.. BY 2]);
						graph.maxx:=MAX(model.matrix[.. BY 2]);
						graph.scalex:= graph.W/(graph.maxx-graph.minx);
					END;
					IF graph.autoscaleY THEN
						graph.miny:=MIN(model.matrix[1.. BY 2]);
						graph.maxy:=MAX(model.matrix[1.. BY 2]);
						graph.scaley:=graph.H/(graph.maxy-graph.miny);
					END;
					c:=graph.curves;
					FOR j:=0 TO LEN(model.matrix,0)-1 BY 2 DO
						FOR i:=0 TO LEN(model.matrix,1)-2 DO
							canvas.Line(graph.X0+ENTIER ((model.matrix[j,i]-graph.minx)*graph.scalex), height - graph.Y0 -ENTIER ((model.matrix[j+1,i]-graph.miny)*graph.scaley),
										graph.X0+ENTIER ((model.matrix[j,i+1]-graph.minx)*graph.scalex), height-graph.Y0-ENTIER ((model.matrix[j+1,i+1]-graph.miny)*graph.scaley),
										c.linecol, WMGraphics.ModeSrcOverDst);
						END;
						c:=c.next;
					END;
				| XYYY: (* first row are common X locations, other rows are individual curve Y values *)
					IF graph.autoscaleX THEN
						graph.minx:=MIN(model.matrix[0]);
						graph.maxx:=MAX(model.matrix[0]);
						graph.scalex:= graph.W/(graph.maxx-graph.minx);
					END;
					IF graph.autoscaleY THEN
						graph.miny:=MIN(model.matrix[1..]);
						graph.maxy:=MAX(model.matrix[1..]);
						graph.scaley:=graph.H/(graph.maxy-graph.miny);
					END;
					c:=graph.curves;
					FOR j:=1 TO LEN(model.matrix,0)-1 DO
						FOR i:=0 TO LEN(model.matrix,1)-2 DO
							canvas.Line(graph.X0+ENTIER ((model.matrix[0,i]-graph.minx)*graph.scalex), height - graph.Y0 -ENTIER ((model.matrix[j,i]-graph.miny)*graph.scaley),
										graph.X0+ENTIER ((model.matrix[0,i+1]-graph.minx)*graph.scalex), height-graph.Y0-ENTIER ((model.matrix[j,i+1]-graph.miny)*graph.scaley),
										c.linecol, WMGraphics.ModeSrcOverDst);
						END;
						c:=c.next;
					END;
				| XYZ:
					NEW(p,3); NEW(p0,3);NEW(p1,3);
					x0:=MAX(LEN(model.matrix,0),LEN(model.matrix,1)) / 2;
					y0:=x0;
					scale:= width/MAX(LEN(model.matrix,0),LEN(model.matrix,1));
					z0:=  (MAX(model.matrix)+MIN(model.matrix))/2;
					minz:=MIN(model.matrix);
					(*len:=projection * [LEN(model.matrix,0), LEN(model.matrix,1),MAX(model.matrix)]-[0,0, MIN(model.matrix)];
					zrange:= MathL.sqrt(len +* len);*)
					zrange:=MAX(model.matrix)-MIN(model.matrix);
					zscale:= height / zrange;
					FOR y:=0 TO LEN(model.matrix,0)-1 DO
						FOR x:=0 TO LEN(model.matrix,1)-1 DO
							p:= 0.85*[scale*(x-x0), scale*(y-y0), zscale*(model.matrix[y,x]-z0)]; (* to do: used p[2] for color height encoding*)
							p1 := ENTIER(projection * p + [scale*x0,scale*y0, zscale*z0]); (*project, scale, convert to pixel coordinate*)
							IF (x#0) THEN
								clamp(0,width-1,p0[0]); clamp(0,width-1,p1[0]); (* strange: points should ~fit into window, but are far off ... Out.Int(p1[2]) *)
								clamp(0,height-1,p0[2]); clamp(0,height-1,p1[2]);
								IF hightclue THEN col:=ENTIER((model.matrix[y,x]-minz)/zrange*255) ELSE col:=255 END;
								IF depthclue THEN depth:= ENTIER((width-p0[1]) * 192 / width)  +64 ELSE depth:=255 END;
								canvas.Line(p0[0],p0[2], p1[0], p1[2], (255-col)*256*256 +col*256 +depth, WMGraphics.ModeSrcOverDst);
							END;
							p0:=p1;
						END;
					END;
					FOR x:=0 TO LEN(model.matrix,1)-1 DO
						FOR y:=0 TO LEN(model.matrix,0)-1 DO
							p:= 0.85*[scale*(x-x0), scale*(y-y0), zscale*(model.matrix[y,x]-z0)];
							p1 := ENTIER(projection * p + [scale*x0,scale*y0, zscale*z0] ); (*project, convert to pixel coordinate*) (* to do: color encoding*)
							IF (y#0) THEN
								clamp(0,width-1,p0[0]); clamp(0,width-1,p1[0]);
								clamp(0,height-1,p0[2]); clamp(0,height-1,p1[2]);
								IF hightclue THEN col:=ENTIER((model.matrix[y,x]-minz)/zrange*255) ELSE col:=255 END;
								IF depthclue THEN depth:= ENTIER((width-p0[1]) * 192 / width)+64 ELSE depth:=255 END;
								canvas.Line(p0[0],p0[2], p1[0], p1[2], (255-col)*256*256 +col*256 +depth, WMGraphics.ModeSrcOverDst);
							END;
							p0:=p1;
						END;
					END;
				ELSE HALT(200);
			END;
		END;
		Invalidate(WMRectangles.MakeRect(0, 0, width, height));
	END Render;

END Window;

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

PROCEDURE RemoveAllWindows;
BEGIN
	RemoveWindows(NIL)
END RemoveAllWindows;

(* cyclic symmetry *)
PROCEDURE clamp(x0,x1:SIGNED32; VAR x:SIGNED32);
BEGIN
	x:= (x-x0) MOD (x1+1-x0) + x0;
END clamp;

(*
(*finite boundary*)
PROCEDURE clamp(x0,x1:SIGNED32; VAR x:SIGNED32);
BEGIN
	IF x<x0 THEN x:=x0
	ELSIF x>x1 THEN x:=x1
	END;
END clamp;
*)

PROCEDURE sqr(x:Datatype):Datatype;
BEGIN
	RETURN x*x
END sqr;

(*
PROCEDURE line(VAR m:Display; p0,p1:IntPoint);
VAR bx,bz,x,z,x0,z0, dx,dz, sigx,sigz,depth :SIGNED32;
BEGIN
	x0:=p0[0];	z0:=p0[2];  depth:=p0[1]; (*to do: use this for depth rendering*)
	bx := p1[0]-p0[0];
	bz := p1 [2]-p0[2];
	IF bx>=0 THEN sigx:=1 ELSE sigx:=-1 END;
	IF bz>=0 THEN sigz:=1 ELSE sigz:=-1 END;
	IF ABS(bx)>ABS(bz) THEN
		FOR dx := 0 TO ABS(bx)  DO
			x:=sigx*dx + x0;
			IF bx#0 THEN z:= dx * bz DIV bx * sigx + z0;
			ELSE z:=z0
			END;
			clamp(0,LEN(m,1)-1,x);
			clamp(0,LEN(m,0)-1,z);
			m[z,x]:=Signal;
		END;
	ELSE
		FOR dz := 0 TO ABS(bz) DO
			z:=sigz*dz + z0;
			IF bz#0 THEN x:= dz * bx DIV bz *sigz +x0;
			ELSE x:=x0
			END;
			clamp(0,LEN(m,1)-1,x);
			clamp(0,LEN(m,0)-1,z);
			m[z,x]:=Signal;
		END;
	END;
END line;
*)

PROCEDURE Render*(CONST data:Matrix; size:SIGNED32; VAR projection:  Matrix);
VAR w:Window;
BEGIN
	NEW(w,512,512,SIGNED32(0FFFFFFFFH),"Rendering");
	w.Show;
	w.SetProjection(projection);
	w.Set(data);
	w.Render;
END Render;

PROCEDURE Sample(i:SIGNED32):Matrix;
VAR data: Matrix; x,y:SIZE;
BEGIN
	NEW(data,10,20);
	FOR y:=0 TO LEN(data,0)-1 DO	(*invent sample data*)
		FOR x:=0 TO LEN(data,1)-1 DO
			CASE i OF
			0:	data[y,x]:= 30*(1 + y * (LEN(data,1)-x-1) /(LEN(data,0)*LEN(data,1)));
			|1: 	data[y,x]:= 100* (1+sqr((y/LEN(data,0)-0.5)*(x/LEN(data,1)-0.5)));
			|2: 	data[y,x]:= MathL.sin(x/4)+MathL.cos(y*x/20);
			END;
		END;
	END;
	RETURN data
END Sample;

PROCEDURE Test*;
VAR projection:Matrix;
BEGIN
	Render(Sample(2),512,projection); (*uses default projection*)
END Test;

PROCEDURE Test2*;
VAR
	w:Window;
BEGIN
	NEW(w,512,512,255,"Test2");
	w.Show;
	w.Set(Sample(2));
	w.SetDataorder(XYYY);
	w.SetProjection([[0.9,0.1,0],[-0.1,0.9,0.1],[0,-0.1,0.9]]);
	w.Render;
	(*w.Clear;
	w.SetProjection([[0.8,0.2,0],[-0.2,0.8,0.2],[0,-0.2,0.8]]);
	w.Render;*)
END Test2;

PROCEDURE Test3*;
VAR
	w:Window;
BEGIN
	NEW(w,512,512,255,"Test3");
	w.Show;
	w.SetDataorder(FUNC);
	w.Render;
END Test3;

PROCEDURE Test4*;
VAR
	w:Window; data: Matrix;
BEGIN
	NEW(w,512,512,255,"Test4");
	w.Show;
	w.Set(-Sample(1));
	w.SetDataorder(XYZ);
	w.SetProjection([[0.9,0.1,0],[-0.1,0.9,0.1],[0,-0.1,0.9]]);
	w.Render;
	w.Clear;
	w.SetProjection([[0.8,0.2,0],[-0.2,0.8,0.2],[0,-0.2,0.8]]);
	w.Render;
END Test4;

BEGIN
	Modules.InstallTermHandler(RemoveAllWindows);
END WMMatrixGraph.

WMMatrixGraph.Test
WMMatrixGraph.Test2
WMMatrixGraph.Test3
WMMatrixGraph.Test4
System.FreeDownTo  WMMatrixGraph ~

WMMatrixGraph.RemoveWindows ~ (*close and remove all matrix windows*)
WMMatrixGraph.RemoveWindows 5 ~ (* close and remove a number of matrix windows*)

fofPC.Compile \f *
