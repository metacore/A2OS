MODULE StatisticsMoments; (** AUTHOR "Patrick Hunziker"; PURPOSE "basic moment computation"; *)
(** also check MatrixMoments.Mod and VolumeMoments.Mod for high accuracy computation based on cubic spline filtering *)
(*
Moments: 
Mathematically: distance-weighted integrals.
Statistical interpretations (sum, mean, SD,  etc) 
Physical interpretations, e.g.
	mass=Moment0
	center of gravity= moment1/moment0
	angular moment, etc
*)

TYPE Datatype* = REAL;
TYPE Tensor = ARRAY [?] OF Datatype;

PROCEDURE LinearMoment*(CONST data:ARRAY[*] OF Datatype; degree:SIGNED32):Datatype;
VAR m:Datatype; i:SIZE;
BEGIN
	CASE degree OF
	|0: RETURN SUM(data)
	|1: FOR i:=0 TO LEN(data,0)-1 DO m:=m+i*data[i] END;
	|2: FOR i:=0 TO LEN(data,0)-1 DO m:=m+i*i*data[i] END;
	END;
	RETURN m
END LinearMoment;

PROCEDURE PlanarMoments*(CONST data:ARRAY [*,*] OF Datatype; degree:SIGNED32; VAR mx,my:Datatype);
VAR i,y:SIZE;
	indexX,line:ARRAY[*] OF Datatype;
BEGIN
	CASE degree OF
	|0: mx:=SUM(data);my:=mx; (*?*)
	|1: 
		mx:=0; my:=0;
		NEW(indexX,LEN(data,1));
		NEW(line,LEN(data,1));
		FOR i:=0 TO LEN(indexX,0)-1 DO indexX[i]:=i END;
		FOR y:=0 TO LEN(data,0)-1 DO
			line:=data[y,*];
			mx:=mx + indexX+*line;
			my:=my + y*SUM(line);
		END;
	|2:
		mx:=0; my:=0;
		NEW(indexX,LEN(data,1));
		NEW(line,LEN(data,1));
		FOR i:=0 TO LEN(indexX,0)-1 DO indexX[i]:=i*i END;
		FOR y:=0 TO LEN(data,0)-1 DO
			line:=data[y,*];
			mx:=mx + indexX+*line;
			my:=my + y*y*SUM(line);
		END;
	END
END PlanarMoments;

PROCEDURE VolumeMoments*(CONST data:ARRAY [*,*,*] OF Datatype; degree:SIGNED32; VAR mx,my,mz:Datatype);
VAR i,y,z:SIZE;
	indexX,line:ARRAY[*] OF Datatype;
	lineSum:Datatype;
BEGIN
	CASE degree OF
	|0: mx:=SUM(data);my:=mx; mz:=mx;
	|1: 
		mx:=0; my:=0;
		NEW(indexX,LEN(data,2));
		NEW(line,LEN(data,2));
		FOR i:=0 TO LEN(indexX,0)-1 DO indexX[i]:=i END;
		FOR z:=0 TO LEN(data,0)-1 DO
			FOR y:=0 TO LEN(data,1)-1 DO
				line:=data[z,y,*];
				lineSum:=SUM(line);
				mx:=mx + indexX+*line;
				my:=my + y*lineSum;
				mz:=mz + z*lineSum;
			END;
		END;
	|2:
		mx:=0; my:=0;
		NEW(indexX,LEN(data,2));
		NEW(line,LEN(data,2));
		FOR i:=0 TO LEN(indexX,0)-1 DO indexX[i]:=i*i END;
			FOR z:=0 TO LEN(data,0)-1 DO
				FOR y:=0 TO LEN(data,1)-1 DO
				line:=data[z,y,*];
				lineSum:=SUM(line);
				mx:=mx + indexX+*line;
				my:=my + y*y*lineSum;
				mz:=mz + z*z*lineSum;
			END;
		END;
	END
END VolumeMoments;

PROCEDURE TensorMoments*(CONST data:ARRAY [*,*] OF Datatype; degree:SIGNED32; VAR m:ARRAY [*] OF Datatype);
END TensorMoments;


PROCEDURE {TEST} Test*;
VAR data: ARRAY [*,*] OF Datatype;
	mx,my:Datatype;
BEGIN
	data:=[[0,1,2],[3,4,5]];
	PlanarMoments(data,0,mx,my);
	ASSERT(mx=15);
	ASSERT(my=15);
	PlanarMoments(data,1,mx,my);
	ASSERT(mx=19);
	ASSERT(my=12);
	PlanarMoments(data,2,mx,my);
	ASSERT(mx=33);
	ASSERT(my=12);
	TRACE(ENTIER(1000*mx/15), ENTIER(1000*my/15));
END Test;


PROCEDURE {TEST}Test0*;
VAR data: ARRAY [*,*] OF Datatype;
	data3: ARRAY [*,*,*] OF Datatype;
	mx0,mx1,mx2,mx3,
	my0,my1,my2,my3,
	mz0,mz1,mz2,mz3:Datatype;
BEGIN
	data:=[[1,2,1],[1,2,1]];
	PlanarMoments(data,0,mx0,my0);
	TRACE(ENTIER(1000*mx0), ENTIER(1000*my0));
	PlanarMoments(data,1,mx1,my1);
	TRACE(ENTIER(1000*mx1/mx0), ENTIER(1000*my1/mx0));
	PlanarMoments(data,2,mx2,my2);
	TRACE(ENTIER(1000*mx2/mx0), ENTIER(1000*my2/my0));
	
	data3:=[[[0,2,1],[0,2,1]],[[0,2,1],[0,2,1]]];

	VolumeMoments(data3,0,mx0,my0,mz0);
	TRACE(ENTIER(1000*mx0), ENTIER(1000*my0), ENTIER(1000*mz0));

	VolumeMoments(data3,1,mx1,my1,mz1);
	TRACE(ENTIER(1000*mx1/mx0), ENTIER(1000*my1/mx0), ENTIER(1000*mz1/mx0));
END Test0;

END StatisticsMoments.

