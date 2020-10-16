MODULE VolumeBoundaries; 	(** AUTHOR "D. Shulga, contributions PH, 2015"; PURPOSE "Utilities for determination of volume boundary determination and application of boundary conditions"; *)

(* implements boundary conditions frequently used in engineering:
Dirichlet = 1st type BC: specify the values that a solution needs to take on along the boundary of the domain. (see wikipedia "Dirichlet boundary conditions")
Neumann BC = 2nd type BC: specify the values that the derivative of a solution is to take on the boundary of the domain.(see wikipedia "Neumann boundary conditions")
Robin boundary condition=3rd type BC: not yet implemented
Mixed boundary condition: not yet implemented
Cauchy boundary condition: not yet implemented

Robin boundary conditions are a weighted combination of Dirichlet boundary conditions and Neumann boundary conditions.
This contrasts to mixed boundary conditions, which are boundary conditions of different types specified on different subsets of the boundary.
Robin boundary conditions are also called impedance boundary conditions, from their application in electromagnetic problems,
or convective boundary conditions, from their application in heat transfer problems.

when using specific types of signal processing, e.g. spline algorithms, other boundaries are also of interest,
e.g. various types of mirror boundary conditions, cyclic boundary conditions, ...
(to be implemented)
When imposed on an ordinary or a partial differential equation, it is a specification of a linear combination of the values of a function and the values of its derivative on the boundary of the domain.


*)


IMPORT MatrixBase, MatrixUtilities, VolumeMorphology, Files, Streams;

CONST GridNotFound*=123;

TYPE
	BinaryVolume* = ARRAY [*,*,*] OF BOOLEAN;
	Volume* = ARRAY [*,*,*] OF MatrixBase.Datatype;
	VectorField* = ARRAY [*,*,*,*] OF MatrixBase.Datatype;
	ScalarField* = ARRAY [*,*,*] OF MatrixBase.Datatype;

	VolumeContainer* = POINTER TO RECORD
		v*, outside*: BinaryVolume;   (* volume itself *)
		N0*,N1*,N2*: SIZE; (* volume sizes *)
		nElements*: SIZE; (* count of (TRUE) elements of v *)
		outerShell*: BinaryVolume; (* outer surface of the volume*)
		innerShell*: BinaryVolume; (* inner surface of the volume*)
		vNoShell*:BinaryVolume;
		name*: ARRAY 512 OF CHAR;
	END;

	VolumeDomain* = OBJECT
	VAR
		volumes*: ARRAY [*] OF VolumeContainer;
		index*: SIZE; (* current container index *)
		rho*, dt*: MatrixBase.Datatype;
		pInlet*, pOutlet*, 
		vInlet*: MatrixBase.Datatype;
		dyeInlet*: PROCEDURE(sizeY,sizeZ,y,z: SIZE): BOOLEAN;(*!TBD: extend to 3d coordinates, include dependent code*)

		PROCEDURE &Init*(CONST names: ARRAY OF ARRAY OF CHAR; pInlet,pOutlet,rho,dt: MatrixBase.Datatype);
		VAR i:SIZE;
		BEGIN
			SELF.pInlet := pInlet;
			SELF.pOutlet:=pOutlet;
			SELF.rho := rho;
			SELF.dt := dt;
			SELF.dyeInlet:=DyeInlet; (*default dye behaviour*)
			NEW(volumes, LEN(names,0));
			FOR i:=0 TO LEN(volumes,0)-1 DO
				NEW(volumes[i]);
			END;
			FOR i:=0 TO LEN(names,0)-1 DO
				volumes[i].v := ReadBinaryVolume(names[i]);
				ComputeVolumeContainer(volumes[i]);
			END;
		END Init;

		PROCEDURE ComputeVolumeContainer(VAR vc: VolumeContainer);
		BEGIN
			vc.N0 := LEN(vc.v,0);
			vc.N1 := LEN(vc.v,1);
			vc.N2 := LEN(vc.v,2);
			IF log#NIL THEN log.String("Compute outer and inner surface ... "); log.Ln; log.Update; END;
			vc.outerShell := FindOuterSurface(vc.v);
			vc.innerShell := FindInnerSurface(vc.v);
			vc.outside := ~vc.v;
			vc.vNoShell:= vc.v & ~vc.innerShell;
			vc.nElements:=TrueCount(vc.v);
		END ComputeVolumeContainer;

		(** 	Zero gradient perpendicular to wall, by assigning the inner layer value to the outer layer
		This is not perfect for Nabla operators that take 3 elements into account	*)
		PROCEDURE ZeroBoundaryGradient*(VAR p: Volume);
		VAR
			k,N0,N1,N2: SIZE;
			vc: VolumeContainer;
		BEGIN
			N0 := LEN(p,0);
			N1 := LEN(p,1);
			N2 := LEN(p,2);
			FOR k:=0 TO LEN(volumes,0)-1 DO
				IF (N0 = volumes[k].N0) & (N1 = volumes[k].N1) & (N2 = volumes[k].N2) THEN
					index := k;
					vc := volumes[k];
					NeumannBC2(p, vc.v, vc.innerShell, vc.outerShell); (* apply zero pressure gradient on boundary *)
					RETURN;
				END;
			END;
			HALT(GridNotFound);
		END ZeroBoundaryGradient;

		PROCEDURE FlowBoundaries*(VAR field: Volume);
		VAR
			k,N0,N1,N2: SIZE;
			vc: VolumeContainer;
		BEGIN
			N0 := LEN(field,0);
			N1 := LEN(field,1);
			N2 := LEN(field,2);
			FOR k:=0 TO LEN(volumes,0)-1 DO
				IF (N0 = volumes[k].N0) & (N1 = volumes[k].N1) & (N2 = volumes[k].N2) THEN
					index := k;
					vc := volumes[k];
					(*DirichletBC(field, vc.innerShell, 0);	 (* set field to zero at inner surface *)
					DirichletBC(field, vc.outside, 0); *) (* set field to zero outside the domain *)
					DirichletBC(field, vc.vNoShell,0);
					RETURN;
				END;
			END;
			HALT(GridNotFound);
		END FlowBoundaries;

		PROCEDURE PressureBoundaries*(VAR p: Volume);
		BEGIN
			PressureBoundaries0(p);
			ZeroBoundaryGradient(p);
		END PressureBoundaries;

		(** control pressure at inlet and outlet *)
		PROCEDURE PressureBoundaries0*(VAR p: Volume);
		VAR
			k,k0,k1,N0,N1,N2: SIGNED32;
			vc: VolumeContainer;
		BEGIN
			 (*fast version. Does not lead to a disadvantage, as imposing a pressure on voxels outside the volume does not induce a flow*)
			p[..,..,0]:=pInlet;
			p[..,..,LEN(p,2)-1]:=pOutlet;
			RETURN;

			(*
			N0 := LEN(p,0);
			N1 := LEN(p,1);
			N2 := LEN(p,2);
			FOR k:=0 TO LEN(volumes,0)-1 DO
				IF (N0 = volumes[k].N0) & (N1 = volumes[k].N1) & (N2 = volumes[k].N2) THEN
					index := k;
					vc := volumes[k];
					FOR k0:=0 TO LEN(vc.v,0)-1 DO
						FOR k1:=0 TO LEN(vc.v,1)-1 DO
								IF vc.v[k0,k1,0] THEN p[k0,k1,0] := pInlet	END;
								IF vc.v[k0,k1,LEN(p,2)-1] THEN p[k0,k1,LEN(p,2)-1] := pOutlet END;
						END;
					END;
					RETURN;
				END;
			END;
			*)
			HALT(GridNotFound);
		END PressureBoundaries0;



		(*pressure changed per step:
		-on locations with external pressure boundary conditions, and in solid, no change*)
		PROCEDURE PressureBoundariesPDT*(VAR pdt: Volume);
		VAR
			k,N0,N1,N2: SIZE;
			vc: VolumeContainer;
		BEGIN
			N0 := LEN(pdt,0);
			N1 := LEN(pdt,1);
			N2 := LEN(pdt,2);

			FOR k:=0 TO LEN(volumes,0)-1 DO
				IF (N0 = volumes[k].N0) & (N1 = volumes[k].N1) & (N2 = volumes[k].N2) THEN
					index := k;
					vc := volumes[k];
					(*DirichletBC(pdt, vc.outside, 0); *) (* no pressure update outside the domain v *)
					DirichletBC(pdt, vc.v,0);
					pdt[..,..,0]:=0; (* no pressure update on inlet, as pressure there is an external boundary condition*)
					pdt[..,..,N2-1]:=0; (*no pressure update on outlet, as pressure there is an external boundary condition*)
					(*NeumannBC2(pdt, vc.v, vc.innerShell, vc.outerShell); (* outer shell mirrors inner shell. Expensive for boundary used in multigrid. *)*)
					RETURN;
				END;
			END;
			HALT(GridNotFound);
		END PressureBoundariesPDT;


		PROCEDURE SoluteBoundaries*(VAR field: Volume); (* avoid presence of solute to outside a channel. TO DO: do not suppress, but bring the material diffused outside inwards again, to avoid loss. *)
		VAR
			i,j,k,N0,N1,N2: SIZE;
			len:ARRAY[3] OF SIZE;
		BEGIN
			len:= LEN(field);
			N0 := LEN(field,0);
			N1 := LEN(field,1);
			N2 := LEN(field,2);
			FOR k:=0 TO LEN(volumes,0)-1 DO
				IF (N0 = volumes[k].N0) & (N1 = volumes[k].N1) & (N2 = volumes[k].N2) THEN
					index := k;
					 (* for triple/double helix *)
					FOR i:=0 TO len[0]-1 DO
						FOR j:=0 TO len[1]-1 DO
							IF dyeInlet(len[0], len[1], i,j) THEN
								field[i,j, 0 ]:=1; (*inlet condition*)
							ELSE
								field[i,j, 0 ]:=0;
							END;
						END;
					END;
					(*!to do: outlet condition: = black hole ?*)
					(*DirichletBC(field, volumes[k].outside, 0);*)  (* set field to zero outside the domain *)
					DirichletBC(field, volumes[k].v,0);
					ZeroBoundaryGradient(field); (* by establishing a zero solute gradient accross the wall, contents will not diffuse out *)
					RETURN;
				END;
			END;
			HALT(GridNotFound);
		END SoluteBoundaries;

		PROCEDURE SoluteBoundaries0*(VAR field: Volume); (* along Z for initialization *)
		VAR
			i,j,k,N0,N1,N2: SIZE;
		BEGIN
			N0 := LEN(field,0);
			N1 := LEN(field,1);
			N2 := LEN(field,2);
			FOR k:=0 TO LEN(volumes,0)-1 DO
				IF (N0 = volumes[k].N0) & (N1 = volumes[k].N1) & (N2 = volumes[k].N2) THEN
					index := k;
					FOR i:=0 TO LEN(field, 0)-1 DO
						FOR j:=0 TO LEN(field,1)-1 DO
							IF dyeInlet(LEN(field,0), LEN(field,1), i,j) THEN
								field[i,j, .. ]:=1; (*inlet condition*)
							ELSE
								field[i,j, .. ]:=0;
							END;
						END;
					END;
					(*DirichletBC(field, volumes[k].outside, 0);*)  (* set field to zero outside the domain *)
					DirichletBC(field, volumes[k].v,0);
					ZeroBoundaryGradient(field); (* by establishing a zero solute gradient accross the wall, contents will not diffuse out *)
					RETURN;
				END;
			END;
			HALT(GridNotFound);
		END SoluteBoundaries0;


	PROCEDURE CountElements*(CONST field: Volume):SIZE; 
		VAR
			k,N0,N1,N2: SIZE;
		BEGIN
			N0 := LEN(field,0);
			N1 := LEN(field,1);
			N2 := LEN(field,2);
			FOR k:=0 TO LEN(volumes,0)-1 DO
				IF (N0 = volumes[k].N0) & (N1 = volumes[k].N1) & (N2 = volumes[k].N2) THEN
					RETURN volumes[k].nElements;
				END;
			END;
			HALT(GridNotFound);
		END CountElements;


	END VolumeDomain;

VAR log*: Streams.Writer;

PROCEDURE Sqr(a:FLOAT64):FLOAT64;
BEGIN
	RETURN a*a
END Sqr;


PROCEDURE DyeInlet(sizeZ,sizeY,z,y: SIZE): BOOLEAN;
CONST radius=0.055 * 2.8;
BEGIN
	RETURN Sqr(y-sizeY/2) + Sqr(z - sizeZ/2) < Sqr(radius*sizeY) (*? >= ?*)
END DyeInlet;

PROCEDURE ReadBinaryVolume*(CONST filename: ARRAY OF CHAR): BinaryVolume;
VAR
	file: Files.File;
	fr: Files.Reader;
BEGIN
	file := Files.Old(filename);
	ASSERT(file # NIL);
	Files.OpenReader(fr, file, 0);
	RETURN MatrixUtilities.LoadLR(fr) .> 0;
END ReadBinaryVolume;

PROCEDURE FindOuterSurface*(CONST domain: BinaryVolume): BinaryVolume;
BEGIN
	RETURN VolumeMorphology.BinarySimpleDilation(domain,{})  & ~domain;
END FindOuterSurface;

PROCEDURE FindInnerSurface*(CONST domain: BinaryVolume): BinaryVolume;
BEGIN
	RETURN domain & ~VolumeMorphology.BinarySimpleErosion(domain,{}) ;
END FindInnerSurface;

(**
	Applies Neumann Boundary Condition for scalar field
	p: Scalar Field
	volume: BinaryVolume
	mode: choose the mode to assign values to the boundary
		1: MAX(neighbours); ('innerSurface' is not used here)
		2: Average(nonzero neighbours)
*)
PROCEDURE NeumannBC*(VAR p: ScalarField; CONST volume, innerSurface, outerSurface: BinaryVolume; mode: SIGNED32);
BEGIN
	CASE mode OF
	1: NeumannBC1(p,volume,innerSurface, outerSurface);
	|2: NeumannBC2(p,volume, innerSurface,outerSurface);
	ELSE HALT(200)
	END;
END NeumannBC;

PROCEDURE NeumannBC1(VAR p: ScalarField; CONST volume, innerSurface, outerSurface: BinaryVolume);
VAR
	k0,k1,k2: SIZE;
	tmp: ScalarField; (* as a local variable, tmp is always allocated again => move to object*)
	e:  MatrixBase.Datatype;
BEGIN
	tmp := p;
	(* set values outside of domain to min(datatype) *)
	FOR k0:=0 TO LEN(volume,0)-1 DO
		FOR k1:=0 TO LEN(volume,1)-1 DO
			FOR k2:=0 TO LEN(volume,2)-1 DO
				IF ~volume[k0,k1,k2] THEN
					p[k0,k1,k2] := MIN(MatrixBase.Datatype);
				END;
			END;
		END;
	END;
	p := VolumeMorphology.SimpleDilation(p,{});		(* as a side effect, this will also change p inside the domain, which is not desirable, and thus has be reconstructed from tmp*)

	(*DirichletBC(p, ~outerSurface, 0);*)
	DirichletBC(p, outerSurface,0);
	e := SUM(p)/TrueCount(outerSurface);

	(*DirichletBC(tmp, ~volume, 0);*)	 (* keep tmp values only inside the volume *)
	DirichletBC(tmp, volume, 0); 
	p := tmp + p;

	(*DirichletBC(p, ~(volume OR outerSurface), e);*)
	DirichletBC(p, volume OR outerSurface, e); 
END NeumannBC1;

(**
	Applies Neumann Boundary Condition for scalar field
	p: Scalar Field
	volume: BinaryVolume
*)
PROCEDURE NeumannBC2(VAR p: ScalarField; CONST volume, innerSurface, outerSurface: BinaryVolume);
VAR
	k0,k1,k2, kk0,kk1,kk2,count: SIZE;
	q: MatrixBase.Datatype;
BEGIN
	FOR k0:=1 TO LEN(outerSurface,0)-2 DO
		FOR k1:=1 TO LEN(outerSurface,1)-2 DO
			FOR k2:=1 TO LEN(outerSurface,2)-2 DO
				IF outerSurface[k0,k1,k2] THEN
					q:=0; count:=0;
					FOR kk0:=k0-1 TO k0+1 DO (* same as above, but faster *)
						FOR kk1:=k1-1 TO k1+1 DO
							FOR kk2:=k2-1 TO k2+1 DO
								IF innerSurface[kk0,kk1,kk2] THEN INC(count); q:=q+p[kk0,kk1,kk2] END;
							END;
						END;
					END;
					p[k0,k1,k2] := q/count; (* outer layer becomes average of nearby inner layer elements*)
				END;
			END;
		END;
	END;
END NeumannBC2;

PROCEDURE ForAll2(CONST x: ARRAY [?] OF MatrixBase.Datatype; CONST y: ARRAY [?] OF BOOLEAN; func: PROCEDURE{DELEGATE}(v: MatrixBase.Datatype; w:BOOLEAN): MatrixBase.Datatype): ARRAY [?] OF MatrixBase.Datatype;
VAR i: SIZE;
BEGIN
	IF DIM(x) = 1 THEN (* last level of recursion *)
		FOR i := 0 TO LEN(x,0)-1 DO
			RESULT[i] := func(x[i],y[i]);
		END;
	ELSE
		FOR i := 0 TO LEN(x,0)-1 DO
			RESULT[i,?] := ForAll2(x[i,?],y[i,?],func);
		END;
	END;
	RETURN RESULT;
END ForAll2;

(**
	Sets values of scalar field "u" to "u0" in points defined by "volume" : u(~volume) := u0;
*)

(* "volume" indicates TRUE=>values are kept; FALSE=> values are replaced by u0 *)
PROCEDURE DirichletBC*(VAR u: ScalarField; CONST volume: BinaryVolume; u0: MatrixBase.Datatype);
VAR
	k0,k1,k2: SIZE;
	len,lenVol: ARRAY [3] OF SIZE;
	vol: ARRAY[?] OF BOOLEAN;
	uu: ARRAY[?] OF MatrixBase.Datatype;
BEGIN
	len:=LEN(u);
	lenVol:=LEN(volume);
	ASSERT(lenVol=len,200);
	IF u0=0 THEN
		u:= u .* volume; (* apply boolean map, setting "FALSE" locations to zero *)
	ELSE 
		FOR k0:=0 TO len[0]-1 DO
			FOR k1:=0 TO len[1]-1 DO
				FOR k2:=0 TO len[2]-1 DO
					IF ~volume[k0,k1,k2] THEN u[k0,k1,k2] := u0 END;(* otherwise, keep original values *)
				END;
			END;
		END;
	END;
	(*
	uu:=AliasOfReshape(u,[len[0]*len[1]*len[2]]);
	vol:=AliasOfReshapeB(volume,[len[0]*len[1]*len[2]]);
	FOR k0:=0 TO len[0]*len[1]*len[2]-1 DO
		IF ~vol[k0] THEN uu[k0] := u0 END;		
	END;
	*)
END DirichletBC;

(**
Number of nonzero elements in binary volume
s: binary volume
*)
PROCEDURE TrueCount*(CONST s: BinaryVolume): SIZE;
VAR
	k0,k1,k2,n: SIZE;
BEGIN
	n := 0;
	FOR k0:=0 TO LEN(s,0)-1 DO
		FOR k1:=0 TO LEN(s,1)-1 DO
			FOR k2:=0 TO LEN(s,2)-1 DO
				IF s[k0,k1,k2] THEN INC(n);
				END;
			END;
		END;
	END;
	RETURN n;
END TrueCount;

(*non-allocating*)
PROCEDURE AliasOfReshape(CONST x: ARRAY [?] OF FLOAT64; CONST newSize: ARRAY [*] OF SIZE): ARRAY [?] OF FLOAT64;
BEGIN
	RESULT := ALIAS OF x;
	RESULT := RESHAPE(RESULT,newSize);
	RETURN RESULT;
END AliasOfReshape;

PROCEDURE AliasOfReshapeB(CONST x: ARRAY [?] OF BOOLEAN; CONST newSize: ARRAY [*] OF SIZE): ARRAY [?] OF BOOLEAN;
BEGIN
	RESULT := ALIAS OF x;
	RESULT := RESHAPE(RESULT,newSize);
	RETURN RESULT;
END AliasOfReshapeB;

END VolumeBoundaries.


System.FreeDownTo VolumeBoundaries ~






