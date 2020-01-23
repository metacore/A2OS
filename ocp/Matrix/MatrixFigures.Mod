MODULE MatrixFigures ;	(**  AUTHOR "ph"; PURPOSE "plot figures into arrays";  **)
IMPORT MatrixBase, Mathe:=MathL;

TYPE Matrix=MatrixBase.Matrix;
		Datatype=MatrixBase.Datatype;
		Color=SIGNED32;
		Curve1D=PROCEDURE{DELEGATE}(x:Datatype; c:Color; penwidth:Datatype):SIGNED32;
		Curve2D=PROCEDURE{DELEGATE}(t:Datatype; VAR x,y: SIGNED32; c:Color; penwidth:Datatype);

PROCEDURE Inside(x:SIZE; lower,upper:SIZE):BOOLEAN;
BEGIN
	RETURN (x>=lower) & (x<=upper)
END Inside;



(* implementation note: matrix index order is m[y,x]*)
PROCEDURE Line*(VAR m:Matrix; x0,y0,x1,y1:SIZE; value:Datatype);
VAR i, x,y, dx,dy,min,max:SIZE; slope:Datatype;
BEGIN
	IF ~(Inside(x0,0,LEN(m,1)) & Inside(y0,0,LEN(m,0)) &Inside(x1,0,LEN(m,1)) &Inside(y1,0,LEN(m,0))) THEN RETURN END;
	IF ABS(x1-x0) >= ABS(y1-y0) THEN
		IF (x1=x0)  THEN IF Inside(y0,0,LEN(m,0)-1) & Inside(x0,0,LEN(m,1)-1) THEN m[y0,x0]:=value; END; RETURN END;
		slope:=(y1-y0) / (x1-x0);
		min:=MIN(x0,x1); max:=MAX(x0,x1);
		FOR i:=min TO max DO
			dx:=i-x0;
			dy:=ENTIER(dx * slope);
			x:=x0+dx; y:=y0+dy;
			IF Inside(y,0,LEN(m,0)-1) & Inside(x,0,LEN(m,1)-1) THEN m[y,x]:=value; END;
		END;
	ELSE
		IF (y1= y0)  THEN IF Inside(y0,0,LEN(m,0)-1) & Inside(x0,0,LEN(m,1)-1) THEN m[x0,y0]:=value; END; RETURN END;
		slope:=(x1-x0) / (y1-y0);
		min:=MIN(y0,y1); max:=MAX(y0,y1);
		FOR i:=min TO max DO
			dy:=i-y0;
			dx:=ENTIER(dy * slope);
			x:=x0+dx; y:=y0+dy;
			IF Inside(y,0,LEN(m,0)-1) & Inside(x,0,LEN(m,1)-1) THEN m[y,x]:=value; END;
		END;
	END;
END Line;

PROCEDURE Dot*(x,y:SIGNED32);
END Dot;

PROCEDURE Graph*(curve:Curve1D);
END Graph;

PROCEDURE Curve*(curve:Curve2D);
END Curve;

PROCEDURE Arc*;
END Arc;

PROCEDURE Circle*;
END Circle;

PROCEDURE Ellipse*;
END Ellipse;

PROCEDURE Rectangle*;
END Rectangle;




PROCEDURE Arrow*(VAR m:Matrix; x0,y0,x1,y1:SIGNED32; value:Datatype);
CONST pi=3.1516; headscale= 0.25;
	(*ShowZero=FALSE;*)
VAR size:SIGNED32; alpha, head: FLOAT64;
BEGIN
	alpha:=arctan2(x1-x0,y1-y0);
	size:=MAX(ABS(x1-x0), ABS(y1-y0));
	head:=size * headscale (*  + 2 *);
	(*IF ShowZero OR (x0#x1) OR (y0#y1) THEN*)
		Line(m,x0,y0,x1,y1,value);
		Line(m,x1,y1, x1 - ENTIER(0.5+head * Mathe.cos(alpha + pi/8)), y1 - ENTIER(0.5+head * Mathe.sin(alpha + pi/8)), value);
		Line(m,x1,y1, x1 - ENTIER(0.5+head * Mathe.cos(alpha - pi/8)), y1 - ENTIER(0.5+head * Mathe.sin(alpha - pi/8)), value);
	(*END;*)
END Arrow;

PROCEDURE arctan2*(x,y:Datatype):Datatype; (*arctan in range 0..2pi*)
BEGIN
	IF (x>0) & (y>=0) THEN RETURN Mathe.arctan(y/x)
	ELSIF (x>0) & (y<0) THEN RETURN Mathe.arctan(y/x)+2*Mathe.pi
	ELSIF x<0 THEN RETURN Mathe.arctan(y/x)+Mathe.pi
	ELSIF (x=0) & (y>0) THEN RETURN Mathe.pi/2
	ELSIF (x=0) & (y<0) THEN RETURN 3*Mathe.pi/2
	ELSE (*( x=0) & (y=0) *) RETURN 0 (*or RETURN NaN ?*)
	END
END arctan2;

END MatrixFigures.
fofPC.Compile \f *
