MODULE VolumeNonLinearFilters; (** AUTHOR "Patrick Hunziker 2022"; PURPOSE "some nonlinear filters for use in volumetric data"; *)

IMPORT StatisticsBase;

TYPE 
	Datatype=FLOAT64;
	Volume=ARRAY [*,*,*] OF Datatype;
	
PROCEDURE RemoveShotNoise*(VAR v:Volume; threshold:=100:Datatype; directions:={0,1,2}:SET); (*slow implementation*)
VAR max,min,mean,sos,sosxyz,median:Datatype;
	x,y,z,x0,y0,z0,x1,y1,z1,elements:SIZE;
	v0:ARRAY [?] OF Datatype;
BEGIN
	FOR z:=0 TO LEN(v,0)-1 DO
		IF 0 IN directions THEN z0:=MAX(z-1,0); z1:=MIN(z+1,LEN(v,0)-1) ELSE z0:=z; z1:=z END;
		FOR y:=0 TO LEN(v,1)-1 DO
			IF 1 IN directions THEN y0:=MAX(y-1,0); y1:=MIN(y+1,LEN(v,1)-1) ELSE y0:=y; y1:=y END;
			FOR x:=0 TO LEN(v,2)-1 DO
				IF 2 IN directions THEN x0:=MAX(x-1,0); x1:=MIN(x+1,LEN(v,2)-1) ELSE x0:=x; x1:=x END;
				sos:=v[z0..z1,y0..y1,x0..x1]+*v[z0..z1,y0..y1,x0..x1];
				sosxyz:=v[z,y,x]*v[z,y,x];
				elements:=(z1-z0+1)*(y1-y0+1)*(x1-x0+1);
				IF sosxyz > threshold*(sos-sosxyz)/(elements-1) THEN
					v0:=ALIAS OF v[z0..z1,y0..y1,x0..x1];
					v0:=RESHAPE (v0,[elements]);
					median:=StatisticsBase.Median(v0); 
					(*TRACE("set ", ENTIER(v[z,y,x]), ENTIER(median));*)
					v[z,y,x]:=median;
				END;	
			END;
		END;
	END;
END RemoveShotNoise;

PROCEDURE {TEST} Test*;
VAR 
	r: ARRAY [4,4] OF Datatype;
	a,b:Volume;
BEGIN
	r:=[[0,1,1,3],[0,1,1,3],[0,1,1,3],[0,1,1,3]];
	a:= [r,r,r,r];
	a[1,1,1]:=-1000;
	RemoveShotNoise(a);
	(*TRACE(MIN(a),MAX(a),SUM(a));
	TRACE(MIN(b),MAX(b),SUM(b));*)
	ASSERT(MAX(a)<4);
	ASSERT(MIN(a)>=0);
END Test;



END VolumeNonLinearFilters.
