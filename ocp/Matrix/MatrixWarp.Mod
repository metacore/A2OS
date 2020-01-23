MODULE MatrixWarp;
IMPORT MatrixBase, MatrixInterpolation,Out:=KernelLog, MatrixUtilities;

TYPE
		Datatype=MatrixBase.Datatype;
		Matrix=MatrixBase.Matrix;
		Vector=MatrixBase.Vector;
		Cube=ARRAY [*,*,*] OF MatrixBase.Datatype;

(** warps a rectangle "in" according to warp maps dX,dY containing relative dislocation in pixels.
currently expects spline coefficient volume and delivers voxel values (not in spline domain) *)
PROCEDURE Warp2D*(CONST in: Matrix; VAR out:Matrix; CONST dX,dY:Matrix; splinedegree:SIGNED32); (**spline degrees currently implemented: 0-5 (0=piecewise constant, 1=piecewise linear, 2=quadratic...)*)
VAR val:Datatype; x,y,z:SIZE; lout:Vector;(* temp lines *)
BEGIN
	IF (LEN(dX)=0) OR (LEN(dY)=0) THEN HALT(100) END;
	NEW(lout,LEN(dX,1));
	FOR y:=0 TO LEN(in,0)-1 DO
		FOR x:=0 TO LEN(in,1)-1 DO
			lout[x]:=MatrixInterpolation.InterpolateSpline2D(in, x-dX[y,x], y-dY[y,x],splinedegree);
		END;
		out[y]:=lout;
	END;
END Warp2D;

(** warps a cube "in" according to warping maps dX,dY,dZ that contain the relative dislocation in pixel units.
	currently expects spline coefficient volume and delivers voxel values (not in spline domain).
	This is a 'backward' warp in that each 'out' voxel gets data from the interpolated position from the 'in' volume.
	(map corresponds to out volume).
	Precondition: Size(in)~size(out)=Size(dX)=Size(dY)=Size(dZ) *)
PROCEDURE Warp3D*(CONST in: Cube; VAR out:Cube; CONST dX,dY,dZ:Cube; splinedegree:SIGNED32); (**spline degrees currently implemented: 0-5 (0=piecewise constant, 1=piecewise linear, 2=quadratic...)*)
VAR val:Datatype; x,y,z:SIZE; dx,dy,dz:Datatype; lout:Vector;
BEGIN
	IF (LEN(dX)=0) OR (LEN(dY)=0) OR (LEN(dZ)=0) THEN HALT(100) END;
	NEW(lout,LEN(dX,2));
	FOR z:=0 TO LEN(in,0)-1 DO
		FOR y:=0 TO LEN(in,1)-1 DO
			FOR x:=0 TO LEN(in,2)-1 DO
				lout[x]:=MatrixInterpolation.InterpolateSpline3D(in, x-dX[z,y,x], y-dY[z,y,x], z-dZ[z,y,x], splinedegree);
			END;
			out[z,y]:=lout;
		END;
	END;
END Warp3D;

(** warps a cube "in" according to warping maps dX,dY,dZ that contain the relative dislocation in pixel units.
currently expects spline coefficient volume and delivers voxel values (not in spline domain).
In contrast to the procedure Warp3D above, the map /in/out volumes can have different sizes; however, map volumes must have consistent size..
More generic, but SLOW. *)
PROCEDURE Warp3Dgeneral*(CONST in: Cube; VAR out:Cube; CONST dX,dY,dZ:Cube; splinedegree:SIGNED32); (**spline degrees currently implemented: 0-5 (0=piecewise constant, 1=piecewise linear, 2=cubic...)*)
VAR val:Datatype; x,y,z:SIZE; dx,dy,dz:Datatype; lout:Vector;
		xFactor, yFactor, zFactor, xScale,yScale,zScale: FLOAT32;
BEGIN
	xFactor := LEN(in,2) / LEN(dX,2); xScale:= LEN(in,2)/LEN(out,2);
	yFactor := LEN(in,1) / LEN(dX,1); yScale:= LEN(in,1)/LEN(out,1);
	zFactor := LEN(in,0) / LEN(dX,0); zScale:= LEN(in,0)/LEN(out,0);
	NEW(lout,LEN(dX,2));
	FOR z:=0 TO LEN(in,0)-1 DO
		FOR y:=0 TO LEN(in,1)-1 DO
			FOR x:=0 TO LEN(in,2)-1 DO
				IF LEN(dX)#0 THEN dx:=MatrixInterpolation.InterpolateSpline3D(dX, x / xFactor, y / yFactor, z / zFactor, splinedegree); END;
				IF LEN(dY)#0 THEN dy:=MatrixInterpolation.InterpolateSpline3D(dY, x / xFactor, y / yFactor, z / zFactor, splinedegree); END;
				IF LEN(dZ)#0 THEN dz:=MatrixInterpolation.InterpolateSpline3D(dZ, x / xFactor, y / yFactor, z / zFactor, splinedegree); END;
				lout[x]:=MatrixInterpolation.InterpolateSpline3D(in, xScale*(x-dx), yScale*(y-dy), zScale*(z-dz), splinedegree);
			END;
			out[z,y]:=lout;
		END;
	END;
END Warp3Dgeneral;

PROCEDURE Test*;
VAR in,out,dTX,dTY,dTZ:Cube; x,y,z:SIZE;
CONST splinedegree=1;
BEGIN
	NEW(in,5,5,5);
	NEW(out,5,5,5);
	NEW(dTX,5,5,5);
	NEW(dTY,5,5,5);
	NEW(dTZ,5,5,5);

	in[..,2,..]:=1; (* paints "cross pattern" in 3D space *)
	in[2,..,..]:=1;
	in[..,..,2]:=1;

	dTX:=1;
	dTY:=1;
	dTZ:=1; (* prescribes distortion at center of cross, in pixel units example displaces part of central column in y direction*)
	Out.String("-----original data, in spline domain-----"); Out.Ln;

	FOR z:=0 TO LEN(in,0)-1 DO	(* shows original data, in spline domain *)
		MatrixUtilities.OutMatrix(in[z]);
	END;
	Out.String("---- warped data, in pixel data ------"); Out.Ln;

	Warp3Dgeneral(in,out,dTX,dTY,dTZ,splinedegree);

	FOR z:=0 TO LEN(out,0)-1 DO	(* shows resulting, warped data, in pixel domain (not spline domain) *)
		MatrixUtilities.OutMatrix(out[z]);
	END;
END Test;

BEGIN
END MatrixWarp.

MatrixWarp.Test
SystemTools.Free MatrixUnWarpEcho MatrixWarp MatrixInterpolation~
fofPC.Compile \f *
MatrixWarp.Test2 Grapes.Pict Escher.Pict Escher.Pict
MatrixWarp.Test2 Escher.Pict Escher.Pict Escher.Pict

Grapes.Pict

Escher.Pict


Grapes.Pict gewarpt mit Escher.Pict als dx und als dy displacement map


