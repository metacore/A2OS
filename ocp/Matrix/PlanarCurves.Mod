MODULE PlanarCurves; (** AUTHOR "Patrick Hunziker 2004-2019"; PURPOSE "implement parametric B-spline curves [x,y]=f[t] and gradient-following snake curves"; *)

IMPORT LinearFilters, LinearConvolve, Mathe:=MathL, MatrixInterpolation, Random, Kernel, PlanarTransform, WMGraphics, WMProperties, WMFigures, Raster, Strings;

CONST DefaultDegree*=3;
		DefaultBoundary*=LinearFilters.mirrorH;
		DefaultPointsPerSegment*=8;
		DefaultStep*=0.01;
		Dimension*=2;
	
TYPE Datatype*=REAL;
	Coeff*=ARRAY[2] OF Datatype;
	Coeffs*=ARRAY [*,*] OF Datatype; (* [dimension,t]; i.e., [2,t]*)
	
TYPE DrawNodeProc*=PROCEDURE {DELEGATE}(x,y: Datatype);
TYPE DrawLineProc*=PROCEDURE {DELEGATE}(x0,y0,x1,y1: Datatype);
TYPE GradientGetterProc*=PROCEDURE {DELEGATE}(CONST points: Coeffs; VAR gradients: Coeffs); (* at pos [x,y], a gradient [dI/dx, dI/dy] is computed*)
TYPE ShowProc*=PROCEDURE {DELEGATE}(CONST points: Coeffs; CONST gradients: Coeffs);

(* parametric curve, with optional snake behaviour (Active contour,tracking image features)*)
TYPE Curve*=OBJECT
	VAR 
		closed*:=TRUE:BOOLEAN;
		nodes*,gradients*:Coeffs;
		width*,height*:SIZE;
		degree,boundary:INTEGER;
		random:Random.Generator;
		timer:Kernel.Timer;
		stepGradient*,stepNoise*,stepDistance*,stepCurvature*:REAL;(*assignment does not work*)
		s:ARRAY 64 OF CHAR;
		GetGradients*: GradientGetterProc;

	PROCEDURE &Init*(degree:=DefaultDegree, boundary:=DefaultBoundary: INTEGER);
	BEGIN
		NEW(random);
		NEW(timer);
		SELF.degree:=degree;
		SELF.boundary:=boundary;
		stepGradient:=0.001;(* follow intensity gradient. If positive, go towards brighter area *)
		stepNoise:=0 (*1*);(* add noise to points - jump out of local minima*)
		stepDistance:=0.03;(*point distance equalizer*)
		stepCurvature:=0.03;(*minimize local curvature. Also will slowly shrink a closed curve in the absence of a gradient - allows to avoid non-progress on flat image areas*)
	END Init;
	
	PROCEDURE SetNodes*(CONST nodes:Coeffs);
	BEGIN
		SELF.nodes:=ALIAS OF nodes;
		NEW(gradients,LEN(nodes));
	END SetNodes;
	
	PROCEDURE Length*():Datatype;
		VAR l: Datatype; 
			point, v: ARRAY [2] OF Datatype;
			i:SIZE;
		BEGIN
			point:=nodes[0..1,0];
			FOR i:=1 TO LEN(nodes,1)-1 DO
				v:=point; point:=nodes[0..1,i]; v:=point-v;
				l:=l + Mathe.sqrt(v+*v)
			END;
			IF closed THEN 
				v:= nodes[0..1,0]-point; 
				l:=l + Mathe.sqrt(v+*v)
			END;
			RETURN l;
		END Length;

	(* snake behaviour: *)
	PROCEDURE TrackGradients*;
	VAR nNodes,i:SIZE;
	BEGIN 
		nNodes:=LEN(nodes,1);
		GetGradients(nodes,gradients);
		FOR i:=0 TO nNodes-1 DO
			nodes[1,i]:=nodes[1,i]+gradients[1,i]*stepGradient + stepNoise*(random.Uniform()-0.5);
			nodes[0,i]:=nodes[0,i]+gradients[0,i]*stepGradient + stepNoise*(random.Uniform()-0.5);
			IF width#0 THEN nodes[1,i]:=MAX(MIN(nodes[1,i],width-1),0) END;(* constrain to domain *)
			IF height#0 THEN nodes[0,i]:=MAX(MIN(nodes[0,i],height-1),0) END;
		END;
	END TrackGradients;

	PROCEDURE TrackLineGradients*(CONST gradients:Coeffs; step: Datatype);(* fine-grained: use gradient at each line point*)
		BEGIN
			HALT(200);
			(*IF changed THEN ResamplePoints; changed:=FALSE END;
			points:= points + step * gradients;
			*)
			(*TBD: reconstruct coeffs and nodes from line points, e.g. by resample*)
	END TrackLineGradients; 


	PROCEDURE NormalizeIntervals*;
	VAR dx0,dx1,dy0,dy1:Datatype;
		i,nNodes,from,to:SIZE;
	BEGIN 
		nNodes:=LEN(nodes,1);
		IF closed THEN from:=0; to:=nNodes-1
		ELSE from:=1; to:=nNodes-2
		END;
		FOR i:=from TO to DO
			dx0:=nodes[1,(i-1) MOD nNodes]-nodes[1,i];
			dx1:=nodes[1,(i+1) MOD nNodes]-nodes[1,i];
			dy0:=nodes[0,(i-1) MOD nNodes]-nodes[0,i];
			dy1:=nodes[0,(i+1) MOD nNodes]-nodes[0,i];
			IF SquaredDistance(dx0,dy0)<SquaredDistance(dx1,dy1) THEN 
				nodes[1,i]:=nodes[1,i]+stepDistance*(dx1-dx0); 
				nodes[0,i]:=nodes[0,i]+stepDistance*(dy1-dy0);
			ELSE 
				nodes[1,i]:=nodes[1,i]+stepDistance*(dx0-dx1); 
				nodes[0,i]:=nodes[0,i]+stepDistance*(dy0-dy1);				
			END;
		END;
	END NormalizeIntervals;

	PROCEDURE HandleCurvature*;
	VAR dx0,dx1,dy0,dy1,dx,dy:Datatype;
		i,nNodes,from,to:SIZE;
	BEGIN 
		nNodes:=LEN(nodes,1);
		IF closed THEN from:=0; to:=nNodes-1
		ELSE from:=1; to:=nNodes-2
		END;
		FOR i:=from TO to DO
			dx0:=nodes[1,(i-1) MOD nNodes]-nodes[1,i];
			dx1:=nodes[1,(i+1) MOD nNodes]-nodes[1,i];
			dy0:=nodes[0,(i-1) MOD nNodes]-nodes[0,i];
			dy1:=nodes[0,(i+1) MOD nNodes]-nodes[0,i];
			dx:=dx0+dx1;dy:=dy0+dy1;
			nodes[1,i]:=nodes[1,i]+stepCurvature*dx; 
			nodes[0,i]:=nodes[0,i]+stepCurvature*dy;	
		END;
	END HandleCurvature;

	PROCEDURE UpsampleNodes*; (* double the number of nodes*)
	VAR newSize:SIZE; newNodes: Coeffs; node,node1:ARRAY [2] OF Datatype; i:SIZE;
	BEGIN
		IF closed THEN newSize:=LEN(nodes,1)*2 ELSE newSize:=LEN(nodes,1)*2-1 END;
		NEW(newNodes,2,newSize);
		FOR i:=0 TO LEN(newNodes,1)-1 DO
			node:=nodes[*,i DIV 2];
			IF ODD(i) THEN 
				node1:=nodes[*,((i+1) DIV 2) MOD LEN(nodes,1)];
				node:=node+node1; node:=0.5*node;
			END;
			newNodes[*,i]:=node;
		END;
		nodes:=newNodes;
	END UpsampleNodes;

	PROCEDURE BracketNodes*(minX,maxX,minY,maxY:Datatype);
	VAR max,min:Coeff; i:SIZE;
	BEGIN
		max:=[maxY,maxX];
		min:=[minY,minX];
		FOR i:=0 TO LEN(nodes,1)-1 DO
			nodes[*,i]:=MIN(nodes[*,i],max);
			nodes[*,i]:=MAX(nodes[*,i],min);
		END;
	END BracketNodes;
	
	PROCEDURE Optimize*(iterations:SIZE; show:ShowProc);
	CONST DisplayInterval=10;
	VAR i,j:SIZE;
	BEGIN
		FOR j:=0 TO iterations-1 DO
			FOR i:=0 TO iterations-1 DO
				NormalizeIntervals;
				HandleCurvature;
				GetGradients(nodes,gradients);
				TrackGradients;
				IF (show#NIL)  & (i MOD DisplayInterval=0)   THEN show(nodes,gradients); timer.Sleep(100); (*Strings.FloatToStr(Length(),8,4,0, s); TRACE(s)*) END;
			END;
		END;
	END Optimize;
	
	PROCEDURE DrawLine*(drawLine:DrawLineProc);		
	VAR i:SIZE;
	BEGIN
		FOR i:=0 TO LEN(nodes,1)-2 DO
			drawLine( nodes[0,i], nodes[1,i], nodes[0,i+1], nodes[1, i+1]); 
		END;
		IF closed THEN
			drawLine( nodes[0,LEN(nodes,1)-1], nodes[1,LEN(nodes,1)], nodes[0,0], nodes[1, 0]); 
		END;
	END DrawLine;
	
	PROCEDURE DrawNodes*(drawNode:DrawNodeProc);
	VAR i:SIZE;
	BEGIN
		FOR i:=0 TO LEN(nodes,1)-1 DO
			drawNode( nodes[0,i], nodes[1,i]); 
		END;
	END DrawNodes;
END Curve;

TYPE SplineCurve= OBJECT(Curve)(*! not yet fully ported*)
	VAR 
		coeffs, points: Coeffs;
		toFilter, fromFilter: LinearFilters.Filter;
		toConv, fromConv: LinearConvolve.Convolver;
		changed:BOOLEAN;
		pointsPerSegment: INTEGER;
		
		PROCEDURE &Init*(degree:=DefaultDegree, boundary:=DefaultBoundary: INTEGER); (* -1 is default: cubic spline, mirrorH. for perfect <-> transforms, boundary may need to be different for up vs down*)
		BEGIN
			Init(degree,boundary);
			toFilter:=LinearFilters.CreateSplineFilter( LinearFilters.DirectBSpline0 + degree );   
			fromFilter:=LinearFilters.CreateSplineFilter( LinearFilters.InverseBSpline0 + degree );
			NEW(toConv, toFilter, boundary);
			NEW(fromConv, fromFilter, boundary);
			pointsPerSegment:=DefaultPointsPerSegment;
		END Init;
		
		PROCEDURE ResamplePoints*; (* given B-spline coefficients, compute detailed points on line, e.g. for drawing*)
		BEGIN
			MatrixInterpolation.InterpolateSplineN(coeffs[0,..], points[0,..], 0, degree (*boundary - TBD*)); 
			MatrixInterpolation.InterpolateSplineN(coeffs[1,..], points[1,..], 0, degree (*boundary - TBD*)); 
			(*? alternative: could use 2-scale up/downsampling; this would be better for FollowLineGradient() below *)
		END ResamplePoints;
		
		PROCEDURE ResampleNodes*; (* resample to achieve approximately equidistant line segments between nodes *)
		VAR L, l: Datatype; i,p:INTEGER; point,v: ARRAY [2] OF Datatype;
		BEGIN
			L:=Length();
			l:=0; 
			point:=points[0..1,0];
			nodes[0..1,0]:=point;
			i:=1; p:=1;
			IF closed THEN
				WHILE i<LEN(nodes,1) DO
					v:=points[0..1,p]-point; point:=points[0..1,p];
					l:= l+ Mathe.sqrt(v+*v);
					IF l>= L * i/LEN(nodes,1) THEN nodes[0..1,i]:=point; INC(i) END;
					INC(p);
				END;
			ELSE
				WHILE i<LEN(nodes,1) DO
					v:=points[0..1,p]-point; point:=points[0..1,p];
					l:= l+ Mathe.sqrt(v+*v);
					IF l>= L * i/(LEN(nodes,1)-1) THEN nodes[0..1,i]:=point; INC(i) END;
					INC(p);
				END;
			END;
			changed:=TRUE;
		END ResampleNodes;
		
		PROCEDURE SetNodes*(CONST nodes: Coeffs); 
		BEGIN
			SetNodes^(nodes);
			IF LEN(nodes)#LEN(coeffs) THEN NEW(coeffs, LEN(nodes)) END;
			IF closed THEN
				IF LEN(points)# [2,pointsPerSegment*LEN(nodes,1)] THEN NEW(points, [2,pointsPerSegment*LEN(nodes,1)]) END;
			ELSE
				IF LEN(points)# [2,pointsPerSegment*(LEN(nodes,1)-1)+1] THEN NEW(points, [2,pointsPerSegment*(LEN(nodes,1)-1)+1]) END;
			END;
			toConv.convolve(nodes[0,*], coeffs[0,*]);
			toConv.convolve(nodes[1,*], coeffs[1,*]);
			changed:=TRUE;
		END SetNodes;

		PROCEDURE GetCoeffs*; 
		BEGIN
			IF LEN(nodes)#LEN(coeffs) THEN NEW(coeffs, LEN(nodes)) END;
			toConv.convolve(nodes[0,*], coeffs[0,*]);
			toConv.convolve(nodes[1,*], coeffs[1,*]);
			changed:=TRUE;
		END GetCoeffs;

		PROCEDURE GetPoints*; 
		BEGIN
			IF closed THEN
				IF LEN(points)# [2,pointsPerSegment*LEN(nodes,1)] THEN NEW(points, [2,pointsPerSegment*LEN(nodes,1)]) END;
			ELSE
				IF LEN(points)# [2,pointsPerSegment*(LEN(nodes,1)-1)+1] THEN NEW(points, [2,pointsPerSegment*(LEN(nodes,1)-1)+1]) END;
			END;
			ResamplePoints;
			changed:=TRUE;
		END GetPoints;

		PROCEDURE Length*():Datatype;
		VAR l: Datatype; 
			point, v: ARRAY [2] OF Datatype;
			i:SIZE;
		BEGIN
			IF changed THEN ResamplePoints; changed:=FALSE END;
			point:=points[0..1,0];
			FOR i:=1 TO LEN(points,1)-1 DO
				v:=point; point:=points[0..1,i]; v:=point-v;
				l:=l + Mathe.sqrt(v+*v)
			END;
			IF closed THEN 
				v:= points[0..1,0]-point; 
				l:=l + Mathe.sqrt(v+*v)
			END;
			RETURN l;
		END Length;
		
		PROCEDURE TrackGradients*(*(CONST gradients: Coeffs)*); (*coarse-grained: follow gradient at node location. use sign for uphill(+)/downhill*)
		BEGIN
			nodes:= nodes + stepGradient*gradients; 
			toConv.convolve(nodes[0,*], coeffs[0,*]);
			toConv.convolve(nodes[1,*], coeffs[1,*]);
			changed:=TRUE;
		END TrackGradients;

		
		PROCEDURE DrawLine*(drawLine:DrawLineProc);		
		VAR i:SIZE;
		BEGIN
			IF changed THEN	ResamplePoints; changed:=FALSE END;
			FOR i:=0 TO LEN(points,1)-2 DO
				drawLine( points[0,i], points[1,i], points[0,i+1], points[1, i+1]); (*tbd: can buffer points a lower level*)
			END;
		END DrawLine;
	END SplineCurve;
	
	TYPE Array*=OBJECT
		VAR 
			figure*:WMFigures.Figure;
			planar: ARRAY [*,*] OF REAL(*SIGNED16*);
			w,h,i: SIZE;
			
		PROCEDURE &Init*(CONST planar:ARRAY [*,*] OF REAL(*SIGNED16*); smoothings:=7:INTEGER);
		VAR sm:INTEGER;
		BEGIN
			w:=LEN(planar,1);
			h:=LEN(planar,0);
			SELF.planar:=planar;
			WHILE smoothings>0 DO
				sm:=MIN(smoothings,7); (* PlanarTransform.Mod does up to degree 7 spline smoothings (Gaussian-like) per iteration *)
				SELF.planar:=PlanarTransform.Smooth(SELF.planar,sm);
				DEC(smoothings,sm);
			END;
		END Init;
		
		PROCEDURE GetGradients*(CONST points: Coeffs; VAR gradients:Coeffs);
		CONST ds=5;
		VAR x,x0,x1,y,y0,y1:SIZE;
		BEGIN
			IF LEN(gradients)#LEN(points) THEN NEW(gradients,LEN(points)) END;
			FOR i:=0 TO LEN(points,1)-1 DO
				x:=MAX(MIN(ENTIER(points[1,i]),w-1),0); x0:=MAX(MIN(x-ds,w),0); x1:=MAX(MIN(x+ds,w-1),0);
				y:=MAX(MIN(ENTIER(points[0,i]),h-1),0); y0:=MAX(MIN(y-ds,h),0); y1:=MAX(MIN(y+ds,h-1),0);
				
				gradients[0,i]:=planar[y1,x] - planar[y0,x];
				gradients[1,i]:=planar[y,x1] - planar[y,x0];
			END;
		END GetGradients;
		
		PROCEDURE Show*(CONST nodes,gradients:Coeffs);
		VAR point:WMProperties.Property;
			p:WMGraphics.Point2d;
		BEGIN
			IF figure#NIL THEN
				FOR i:=0 TO LEN(nodes,1)-1 DO
					point:=figure.IndexedPoint(SIGNED32(i));
					IF point=NIL THEN 
						figure.AddPoint(ENTIER(nodes[1,i]+0.5), ENTIER(nodes[0,i]+0.5));
					ELSE 
						(*figure.MovePoint(point,ENTIER(nodes[1,i]+0.5), ENTIER(nodes[0,i]+0.5));*)(*something is buggy here *)
						p:=point(WMProperties.PointProperty).Get();
						p.x:=ENTIER(nodes[1,i]+0.5);
						p.y:=ENTIER(nodes[0,i]+0.5);
						point(WMProperties.PointProperty).Set(p);
					END;
				END;
				figure.Invalidate;
			END;
		END Show;
	END Array;

	TYPE Image*=OBJECT
		VAR img: WMGraphics.Image;
			w,h,i: SIZE;
			mode:Raster.Mode;
			figure*:WMFigures.Figure;
			
		PROCEDURE &Init*(img:WMGraphics.Image);
		BEGIN
			SELF.img:=img;
			w:=img.width;
			h:=img.height;
			Raster.InitMode(mode,Raster.srcCopy)
		END Init;
		
		PROCEDURE GetGradients*(CONST points: Coeffs; VAR gradients:Coeffs);
		CONST ds=5;
		VAR x,x0,x1,y,y0,y1:SIZE;
			x0Pix,x1Pix,y0Pix,y1Pix:Raster.Pixel;
		BEGIN
			IF LEN(gradients)#LEN(points) THEN NEW(gradients,LEN(points)) END;
			FOR i:=0 TO LEN(points,1)-1 DO
				x:=MAX(MIN(ENTIER(points[1,i]),w-1),0); x0:=MAX(MIN(x-ds,w),0); x1:=MAX(MIN(x+ds,w-1),0);
				y:=MAX(MIN(ENTIER(points[0,i]),h-1),0); y0:=MAX(MIN(y-ds,h),0); y1:=MAX(MIN(y+ds,h-1),0);
				
				Raster.Get (img, x, y0, y0Pix, mode);
				Raster.Get (img, x, y1, y1Pix, mode);
				Raster.Get (img, x0, y, x0Pix, mode);
				Raster.Get (img, x1, y, x1Pix, mode);

				gradients[0,i]:=ORD(y1Pix[0])+ORD(y1Pix[1])+ORD(y1Pix[2])-ORD(y0Pix[0])-ORD(y0Pix[1])-ORD(y0Pix[2]);
				gradients[1,i]:=ORD(x1Pix[0])+ORD(x1Pix[1])+ORD(x1Pix[2])-ORD(x0Pix[0])-ORD(x0Pix[1])-ORD(x0Pix[2]);
			END;
		END GetGradients;
		
	PROCEDURE Show*(CONST nodes,gradients:Coeffs);
		VAR point:WMProperties.Property;
			p:WMGraphics.Point2d;
		BEGIN
			IF figure#NIL THEN
				FOR i:=0 TO LEN(nodes,1)-1 DO
					point:=figure.IndexedPoint(SIGNED32(i));
					p:=point(WMProperties.PointProperty).Get();
					p.x:=ENTIER(nodes[1,i]+0.5);
					p.y:=ENTIER(nodes[0,i]+0.5);
					point(WMProperties.PointProperty).Set(p);
				END;
				figure.Invalidate;
			END;
		END Show;

	END Image;

	PROCEDURE SquaredDistance(dx,dy:REAL):REAL; (* root computation not needed for functionality *)
	BEGIN
		RETURN dx*dx+dy*dy;
		(*RETURN Mathe.sqrt(dx*dx+dy*dy);*)
	END SquaredDistance;
	
END PlanarCurves.


MODULE TestPlanarCurves; (** AUTHOR "Patrick Hunziker"; PURPOSE ""; *)
IMPORT WMFigures, Commands, WMGraphics, WMArrayPanel, MatrixRaster, WMComponents, WMWindowManager, StatisticsBase, Kernel,Random, PC:=PlanarCurves, PlanarTransform, PlanarNabla;

PROCEDURE Test1*(context:Commands.Context);
VAR img:WMGraphics.Image;
	image16:ARRAY [*,*] OF SIGNED16;
	planar,planar2,planar2B, planar4,planar4B,planar8,planar16,inner, innerx,innery:ARRAY [*,*] OF REAL;
	pan:WMArrayPanel.Panel;
	win: WMComponents.FormWindow;
	line:WMFigures.Spline;
	width,height, i:SIZE;
	nodes:PC.Coeffs;
	timer:Kernel.Timer;
	filename: ARRAY 256 OF CHAR;
	sm, 
	smoothings:=7:INTEGER;
	
	curve: PC.Curve;
	(*image: PC.Image;*)
	array:PC.Array;

BEGIN
	IF ~context.arg.GetString(filename) THEN filename:="Yellow_Duck.jpg" END;
	IF ~context.arg.GetInteger(smoothings,FALSE) THEN smoothings:=7 END;
	img:=WMGraphics.LoadImage(filename,FALSE); 
	width:=img.width;
	height:=img.height;
	MatrixRaster.ImageToGrayArray(img,image16);
	
	planar:=StatisticsBase.Normalize(image16);
	planar:=ABS(planar);
	planar:=planar*100;
	planar:=MAX(planar)-planar;
	
	(*planar:=image16;*)
	planar2:=PlanarTransform.Reduce(planar);
	(*planar2B:=planar2;*)
	planar4:=PlanarTransform.Reduce(planar2);
	(*planar4B:=planar4;*)
	planar8:=PlanarTransform.Reduce(planar4);
	inner:=PlanarTransform.Reduce(planar8);
	(*planar16:=PlanarTransform.Reduce(planar8);
	inner:=PlanarTransform.Reduce(planar16);*)
	
	WHILE smoothings>1 DO
		sm:=MAX(MIN(smoothings,7),2); (* PlanarTransform.Mod does up to degree 7 spline smoothings (Gaussian-like) per iteration *)
		inner:=PlanarTransform.Smooth(inner,sm);
		DEC(smoothings,sm);
	END;

	innerx:=PlanarNabla.dx(inner);
	innery:=PlanarNabla.dy(inner);
	innerx:=innerx .* innerx;
	innery:=innery .* innery;
	inner:=innerx+innery;
	
	(*planar16:=PlanarTransform.Expand(inner);
	planar16:=PlanarTransform.Smooth(planar16);
	planar8:=PlanarTransform.Expand(planar16);*)
	
	planar8:=PlanarTransform.Expand(inner);
	planar8:=PlanarTransform.Smooth(planar8);
	planar8:=PlanarTransform.Smooth(planar8);
	planar4:=PlanarTransform.Expand(planar8);
	planar4:=PlanarTransform.Smooth(planar4);
	(*planar4:=planar4+planar4B;*)
	planar2:=PlanarTransform.Expand(planar4);
	planar2:=PlanarTransform.Smooth(planar2);
	(*planar2:=planar2+planar2B;*)
	planar:=PlanarTransform.Expand(planar2);
	planar:=PlanarTransform.Smooth(planar);
	
	NEW(array,planar);
	(*NEW(image,planar);*)
	pan:= WMArrayPanel.GetPanel ((*planar+*)image16);
	
	nodes:=[[100, 100,100, 100, 100, 100, 300, 300, 600, 600, 600, 600, 600, 600, 300, 300], 
				[100, 100, 300, 300, 500, 500, 500, 500, 500, 500, 300, 300, 100, 100, 100, 100]];
	(*nodes[0,..]:=0.5*nodes[0,..]; nodes[1,..]:=nodes[1,..]+100;*)
	NEW(line); line.closed.Set(TRUE); 
	FOR i:=0 TO LEN(nodes,1)-1 DO
		line.AddPoint(ENTIER(nodes[1,i]), ENTIER(nodes[0,i]));
	END;	
	pan.AddContent(line);
	
	win:= WMArrayPanel.CreateWindow(pan,"SnakeTest");
	WMWindowManager.DefaultAddWindow(win);

	NEW(timer);
	timer.Sleep(1000);(* component is only ready after screen insertion, in a different process. Should be made deterministic.*)
	
	NEW(curve);
	curve.closed:=TRUE;
	curve.width:=width; curve.height:=height; (*optional domain constraint for curve*)
	curve.SetNodes(nodes);
	curve.UpsampleNodes;
	curve.UpsampleNodes;
	curve.GetGradients:=array.GetGradients;
	(*curve.SetArray(planar);*)
	array.figure:=line; 
	
	curve.Optimize(1000,array.Show);
END Test1;

VAR random:Random.Generator;
BEGIN
	NEW(random);
END TestPlanarCurves.

System.FreeDownTo PlanarCurves ~
TestPlanarCurves.Test1 SpermExamples3.jpg 7~
TestPlanarCurves.Test1 Yellow_Duck.jpg 0~
