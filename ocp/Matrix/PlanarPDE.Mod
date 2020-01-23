MODULE PlanarPDE;
 (**  AUTHOR "Patrick Hunziker, Basel; email: Patrick.Hunziker@swissnano.org";  DATE 2009-2-12 ;
 PURPOSE "implementation of partial differential equations for 2D  grids solved directly in the grid domain";
 LICENCE "free for noncommercial use, as long as  author is cited and this header is kept unchanged " **)

 (* here is the principal strategy for solving used here, exemplified with the diffusion equation:
 	 Diffusion equation du/dt = nu  *  Laplacian(u);
	computes scalar field after diffusion from viscosity and scalar field before diffusion.
	 i.e.  (I - nu deltaT Laplacian) u3 = u2 ; i.e.  Dx=x0 ; whereby operator D =   is solved using Jacobi Relaxation
	b is old field, x is new field after diffusion step; ds is grid spacing
 *)

 	(**  Such partial derivatives have been approximated based on finite difference methods to get a set of algebraic equations.
		Different schemes include:
			Euler explicit
			Leap frog
			Adamsbashforth
			Crank-nicolson
			Euler implicit
	The first three numerical schemes are explicit with different orders of accuracy.
	In explicit methods, the physical quantity is marched forward in time from point to point from the given initial condition.
	The last two numerical  schemes are implicit.

	Interpolation schemes include:
	Forward time, centered space (FTCS), e.g. applicable in explicit euler scheme
	Backward time, centered space (BTCS), e.g. applicable in implicit euler scheme
	Centered time, centered space (CTCS);
	etc
	*)


 (* to examine:: in http://en.wikipedia.org/wiki/Scale_space it is shown that the diffusion equation is
 equivalent to gaussian filtering - opening the door to an alternative fast implementation !?*)

IMPORT PlanarBase, Transform:=PlanarTransform, Util:=MatrixUtilities;

TYPE
	Datatype* = PlanarBase.Datatype;
	Grid* = ARRAY [*,*] OF Datatype;
	BooleanMap* = ARRAY [*,*] OF  BOOLEAN;
	Boundary* = PROCEDURE{DELEGATE} ( VAR data: Grid );

TYPE
	Constraint* = OBJECT
	VAR constraint*, smallconstraint*, c,c0: Grid;
		Constrain*: Boundary;
		map*,smallmap*, m,m0: BooleanMap;
		resized:BOOLEAN;
		x,y:SIZE;
	PROCEDURE Resize(w,h:SIZE); (*implementation limitation: binary size steps*)
	BEGIN
		IF (w#LEN(constraint,1)) OR (h#LEN(constraint,0)) THEN
			resized:=TRUE;
			m:=m0; m:=map;
			c:=c0; c:=constraint;
			WHILE (LEN(smallconstraint,0)>1) & ((LEN(smallconstraint,0)>h) OR (LEN(smallconstraint,1)>w)) DO
				NEW(smallmap, (LEN(m)+1) DIV 2);
				NEW(smallconstraint, LEN(smallmap));
				FOR y:=0 TO LEN(m,0)-1 DO
					FOR x:=0 TO LEN(m,1)-1 DO
						IF m[y,x] THEN
							smallmap[y DIV 2, x DIV 2]:= TRUE;
							smallconstraint[y DIV 2,x DIV 2]:= c[y,x]
						END; (* hack*)
					END;
				END;
				m:=m0; m:=smallmap;
				c:=c0; c:=smallconstraint;
			END;
			(*
			IF (w#LEN(smallconstraint,1)) OR (h#LEN(smallconstraint,0)) THEN
				smallconstraint:=c0; smallconstraint:=constraint;
				smallmap:=m0; smallmap:=map;
				WHILE (LEN(smallconstraint,0)>1) & ((LEN(smallconstraint,0)#h) OR (LEN(smallconstraint,1)#w)) DO
					Transform.Reduce2D(smallconstraint,c,NIL,{0,1},Transform.mirrorH);
					smallconstraint:=c0; smallconstraint:=c; c:=c0;
					m:=Util.ReduceBool2(smallmap,Util.Or);
					smallmap:=m0; smallmap:=m; m:=m0;
					IF LEN(constraint,0)=2 THEN RETURN END;
				END;
			ELSE (*already done*)
			END;
			*)
		ELSE resized:=FALSE
		END;
	END Resize;
	PROCEDURE Constrain0(VAR data: Grid); (*use "constraint" and "map" as constraints; *)
	VAR w,h:SIZE;
	BEGIN
		IF LEN(constraint)=0 THEN RETURN END;
		w:=LEN(data,1); h:=LEN(data,0);
		IF (~resized & ((h#LEN(constraint,0))OR(w#LEN(constraint,1)))) OR
			(resized & ((h#LEN(smallconstraint,0))OR(w#LEN(smallconstraint,1))))
		THEN
			Resize(w,h);
		END;
		IF resized THEN data:=Util.AssignIF(smallconstraint,smallmap);
		ELSE data:=Util.AssignIF(constraint,map);
		END;
	END Constrain0;
	PROCEDURE Set*(CONST constraint:Grid; CONST map: BooleanMap);
	BEGIN
		SELF.constraint:=constraint;
		SELF.map:=map;
		resized:=FALSE;
		Constrain:=Constrain0;
	END Set;

	END Constraint;

TYPE
	Laplace* = OBJECT
	(** Laplace equation Laplacian(x)=0 is solved using Jacobi Relaxation,
	using initial x, and retaining data structure, i.e. without going to a sparse matrix format .
	ds is grid spacing
	*)

	VAR null, temp, xsmall: Grid;
		alpha, beta: Datatype;
		child: Laplace;
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;

		PROCEDURE Solve*(VAR x: Grid;  threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary );   (*TO DO: check for convergence*)
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 2D shape, in contrast to the linearization used for matrix algebra*)
			alpha:= 0; beta:=4;
			JacobiSteps( null, x, temp, alpha, beta, Boundaries, iterations );  (*here reduction of Boundary checking may impact speed*)
		END Solve;

		PROCEDURE SolveMultigrid*( VAR x: Grid;  threshold: Datatype;  minsize, iterations, smoothings: SIGNED32;  Boundaries: Boundary );
		BEGIN
			alpha:= 0; beta:=4;
			IF (LEN( x, 0 ) > minsize) & (LEN(x,1)> minsize) THEN
				JacobiSteps( null, x, temp, alpha, beta, Boundaries, smoothings );  (*here reduction of Boundary checking may impact speed*)

				xsmall := Reduce( x );
				IF child = NIL THEN NEW( child) END;
				child.SolveMultigrid( xsmall, threshold, minsize, iterations, smoothings, Boundaries );
				x := Expand( xsmall );

				JacobiSteps( null, x, temp, alpha, beta, Boundaries, smoothings );  (*here reduction of Boundary checking may impact speed*)

			ELSE
				Solve ( x, threshold,iterations, Boundaries );
			END;
		END SolveMultigrid;

	END Laplace;


TYPE
	Poisson* = OBJECT
	(** Poisson equation Laplacian(x)=b is solved using Jacobi Relaxation,
	using initial x, and retaining data structure, i.e. without going to a sparse matrix format .
	ds is grid spacing
	*)

	VAR temp, bsmall, xsmall: Grid;
		alpha, beta: Datatype;
		child: Poisson;
		smoothingsteps:SIGNED32;
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
			smoothingsteps:=5;
		END Init;


		(*
		PROCEDURE SolveDirect(CONST b: Grid; VAR x: Grid;  ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary ); ;
		BEGIN
			PlanarTransform.toSpline2D( b, temp, 3, {0,1});
			InverseLaplacianFiltering2D(temp, temp1);
			PlanarTransform.fromSpline2D(temp1, x, 3, {0,1};

			(*alternative:
			PlanarTransform.toSpline2D(b,temp, 3-2,{0,1});
			InverseLaplacianFiltering2D(temp,temp1);
			PlanarTransform.fromSpline2D(temp1, x, 3, {0,1});
			*)
		END SolveDirect;
		*)


		PROCEDURE Solve*(CONST b: Grid; VAR x: Grid;  ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary );   (*TO DO: check for convergence*)
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 2D shape, in contrast to the linearization used for matrix algebra*)
			alpha:= -ds*ds; beta:=4;
			JacobiSteps( b, x, temp, alpha, beta, Boundaries, iterations );  (*here reduction of Boundary checking may impact speed*)
		END Solve;

		PROCEDURE SolveMultigrid*( CONST b: Grid; VAR x: Grid;  ds, threshold: Datatype;  minsize, iterations: SIGNED32;  Boundaries: Boundary );
		BEGIN
			alpha:= -ds*ds; beta:=4;
			IF (LEN( x, 0 ) > minsize) & (LEN(x,1)> minsize) THEN

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothingsteps );  (*here reduction of Boundary checking may impact speed*)

				xsmall := Reduce( x );
				bsmall := Reduce( b );
				IF child = NIL THEN NEW( child) END;
				child.SolveMultigrid( bsmall, xsmall, 2*ds, threshold, minsize, iterations, Boundaries );
				x := Expand( xsmall );

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothingsteps );  (*here reduction of Boundary checking may impact speed*)

			ELSE
				Solve ( b, x, ds, threshold,iterations, Boundaries );
			END;
		END SolveMultigrid;

	END Poisson;

TYPE
	Diffusion* = OBJECT
	(** Diffusion equation du/dt = nu  *  Laplacian(u);
	computes scalar field after diffusion from viscosity and scalar field before diffusion.
	 i.e.  (I - nu deltaT Laplacian) u3 = u2 ; i.e.  Dx=x0 ; whereby operator D =   is solved using Jacobi Relaxation
	b is old field, x is new field after diffusion step; ds is grid spacing *)

	VAR temp, xsmall, bsmall: Grid;
		alpha, beta: Datatype;
		child: Diffusion;
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;

		PROCEDURE Solve*( CONST b:Grid; VAR x: Grid;  nu, dt, ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary );
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 2D shape, in contrast to the linearization typically used for matrix algebra*)
			alpha := ds * ds / (nu*dt);
			beta := 4 + alpha;
			JacobiSteps( b, x, temp, alpha, beta, Boundaries, iterations );
		END Solve;

		PROCEDURE SolveMultigrid*( CONST b: Grid; VAR x: Grid;  nu, dt, ds, threshold: Datatype;  minsize, iterations: SIGNED32;  Boundaries: Boundary );
		VAR i:SIGNED32;
		BEGIN
			alpha := ds * ds / (nu*dt);  beta := 4 + alpha;
			IF (LEN( x, 0 ) > minsize) & (LEN(x,1)> minsize) THEN
				JacobiSteps( b, x, temp, alpha, beta, Boundaries, 4 ); (*here reduction of Boundary checking may impact speed*)

				xsmall := Reduce( x );
				bsmall := Reduce( b );
				IF child = NIL THEN NEW( child) END;
				child.SolveMultigrid( bsmall, xsmall, nu, dt, 2* ds, threshold, minsize, iterations, Boundaries );
				x := Expand( xsmall );

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, 4);  (*here reduction of Boundary checking may impact speed*)
			ELSE
				Solve ( b, x, nu, dt, ds, threshold,iterations, Boundaries );
			END;
		END SolveMultigrid;

	END Diffusion;

TYPE
	Wave* = OBJECT (*# TO DO: wave equation needs further testing*)
	(** Wave  equation = d2u/dt2 = c2  *  Laplacian(u);
	computes scalar field u after wave travel interval dt, wave speed c and scalar field at t0.
	phi is old field at (t); phim1 is old field at (t-dt);, x is new field after wavepropagation step at (t+dt); ds is grid spacing *)

	VAR temp, xsmall, b: Grid;
		alpha, beta: Datatype;
		child: Wave;
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;
 		(*explicit solving - forward time, centered space;  not unconditionally stable; not yet tested*)
		PROCEDURE SolveExplicit*( CONST phim1,phi0 : Grid; VAR x: Grid;  c, dt, ds: Datatype; Boundaries: Boundary);
		BEGIN
			(* Laplacian(A)=second derivative of x is computed directly (forward/explicit scheme), (solution not unconditiionally stable).
		The data are kept in original 2D shape, in contrast to the linearization typically used for matrix algebra*)
			Stencil(phi0,temp);
			temp:=temp - 4* phi0;
			x:=2*phi0;
			x:=x-phim1;
			x:=x+ (dt*dt*c*c/ds/ds)* temp;
			IF Boundaries # NIL THEN Boundaries( x ) END;
		END SolveExplicit;

		(*implicit solving BTCS*)
		PROCEDURE Solve*( CONST phim1,phi0 : Grid;  VAR x: Grid;  c, dt, ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary );
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 2D shape, in contrast to the linearization typically used for matrix algebra*)
			alpha := ds * ds / (c*c*dt*dt);  beta := 4 + alpha;
			JacobiSteps( 2*phi0-phim1, x, temp, alpha, beta, Boundaries, iterations );
		END Solve;

			(*implicit solving BTCS*)
		PROCEDURE SolveMultigrid*( CONST phim1,phi0:Grid;  VAR x: Grid;  c, dt, ds, threshold: Datatype;  minsize, iterations, smoothings: SIGNED32;  Boundaries: Boundary );
		VAR i:SIGNED32;
		BEGIN
			alpha := ds * ds  / (c*c*dt*dt);  beta := 4 + alpha;
			IF (LEN( x, 0 ) > minsize) & (LEN(x,1)> minsize)THEN
				b:=2*phi0-phim1;
				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings ); (*here reduction of Boundary checking may impact speed*)

				xsmall := Reduce( x );
				IF child = NIL THEN NEW( child) END;
				child.SolveMultigrid( Reduce(phim1), Reduce(phi0), xsmall, c, dt, 2* ds, threshold, minsize, iterations,smoothings, Boundaries );
				x := Expand( xsmall );

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings);  (*here reduction of Boundary checking may impact speed*)
			ELSE
				Solve ( phim1, phi0, x, c, dt, ds, threshold,iterations, Boundaries );
			END;
		END SolveMultigrid;

	END Wave;


	PROCEDURE Reduce( CONST g: Grid ): Grid; (*tbd: use PlanarTransform or PlanarResize*)
	BEGIN
		IF (LEN( RESULT, 0 ) # ((LEN( g, 0 ) + 1) DIV 2)) OR (LEN( RESULT, 1 ) # ((LEN( g, 1 ) + 1) DIV 2)) THEN NEW( RESULT, (LEN( g, 0 ) + 1) DIV 2, (LEN( g, 1 ) + 1) DIV 2 ) END;
		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := g[.. BY 2, .. BY 2];
		RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] + g[1.. BY 2, .. BY 2];
		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] + g[.. BY 2, 1.. BY 2];
		RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] + g[1.. BY 2, 1.. BY 2];

		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := 0.25 * RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1];

		IF ODD( LEN( g, 0 ) ) THEN
			RESULT[(LEN( g, 0 ) + 1) DIV 2 - 1, .. ] := 2 * RESULT[(LEN( g, 0 ) + 1) DIV 2 - 1, .. ];   (*missing contributions to this boundary data*)
		END;
		IF ODD( LEN( g, 1 ) ) THEN
			RESULT[.. , (LEN( g, 1 ) + 1) DIV 2 - 1] := 2 * RESULT[.. , (LEN( g, 1 ) + 1) DIV 2 - 1];   (*missing contributions to this boundary data*)
		END;
		RETURN RESULT
	END Reduce;

	PROCEDURE Expand( CONST g: Grid ): Grid;
	BEGIN
		IF (LEN( g, 0 ) # ((LEN( RESULT, 0 ) + 1) DIV 2)) OR (LEN( g, 1 ) # ((LEN( RESULT, 1 ) + 1) DIV 2)) THEN NEW( RESULT, 2 * LEN( g, 0 ), 2 * LEN( g, 1 ) ) END;
		RESULT[.. BY 2, .. BY 2] := g[.. (LEN( RESULT, 0 ) + 1) DIV 2 - 1, .. (LEN( RESULT, 1 ) + 1) DIV 2 - 1];
		RESULT[1.. BY 2, .. BY 2] := g[.. (LEN( RESULT, 0 ) + 0) DIV 2 - 1, .. (LEN( RESULT, 1 ) + 1) DIV 2 - 1];
		RESULT[.. BY 2, 1.. BY 2] := g[.. (LEN( RESULT, 0 ) + 1) DIV 2 - 1, .. (LEN( RESULT, 1 ) + 0) DIV 2 - 1];
		RESULT[1.. BY 2, 1.. BY 2] := g[.. (LEN( RESULT, 0 ) + 0) DIV 2 - 1, .. (LEN( RESULT, 1 ) + 0) DIV 2 - 1];  RETURN RESULT
	END Expand;

	 PROCEDURE AllocateSame( VAR x: Grid; CONST templ: Grid ); (*allocation to size of template, with reuse if possible*)
 	BEGIN
	 	IF (LEN( x, 0 ) # LEN( templ, 0 )) OR (LEN( x, 1 ) # LEN( templ, 1 ))  THEN NEW( x, LEN( templ, 0 ), LEN( templ, 1 ));  END;
 	END AllocateSame;

	PROCEDURE Stencil( CONST x: Grid;  VAR x1: Grid); (*2D stencil for finite difference*) (* not in-place *) (*! to do: higher performance by digital filtering approach*)
	VAR lenx, leny: SIZE;
	BEGIN
		AllocateSame(x1,x);
		lenx := LEN( x, 1 );  leny := LEN( x, 0 );
			(*2D stencil*)
		x1[.. leny - 2, .. ] := x[1.., .. ];  					x1[leny - 1, .. ] := x1[leny - 2, .. ];   (*boundary*)
		x1[1.., .. ] := x1[1.., .. ] + x[.. leny - 2, .. ];  		x1[0, .. ] := x1[0, .. ] + x[0, .. ];   (*boundary*)
		x1[.. , .. lenx - 2] := x1[.. , .. lenx - 2] + x[.. , 1..];  x1[.. , lenx - 1] := x1[.. , lenx - 1] + x[.. , lenx - 1];   (*boundary*) (* performance: no SIMD aligmnent here *)
		x1[.. , 1..] := x1[.. , 1..] + x[.. , .. lenx - 2];  		x1[.. , 0] := x1[.. , 0] + x[.. , 0];   (*boundary*) (* performance: no SIMD aligmnent here *)
	END Stencil;

	PROCEDURE JacobiStep*( CONST b: Grid;  VAR x, x1: Grid;  alpha, beta: Datatype;  Boundaries: Boundary );  (*key procedure for speed*)
	(*this is a key procedure for performance:
	apply the jacobi step to the whole data plane in its original format, which would correspond to the diagonal in the Jacobi Matrix formulation, at once, using a stencil like approach;
	i.e., we do not need to convert the data explicitely into a sparse matrix for doing a smooting=Jacobi step *)
	(*see also description in cited gpugems paper *)
	VAR invbeta: Datatype;  lenx, leny: SIGNED32;
	BEGIN
		 invbeta := 1 / beta;
		Stencil(x,x1);
		IF LEN(b,0)#0 THEN (*else, b is zero for Laplace equation*)
			x1[.. , .. ] := x1[.. , .. ] + alpha * b[.. , .. ];
		END;
		x := invbeta * x1;
		IF Boundaries # NIL THEN Boundaries( x ) END;
	END JacobiStep;

	PROCEDURE JacobiSteps( CONST b: Grid;  VAR x, x1: Grid;  alpha, beta: Datatype;  Boundaries: Boundary; repeats:SIGNED32);
	BEGIN
		WHILE repeats>0 DO
			JacobiStep(b,x,x1,alpha,beta,Boundaries);
			DEC(repeats)
		END;
	END JacobiSteps;

	PROCEDURE Advect*( CONST source,  u, v: Grid;  VAR target: Grid;  dt, ds: Datatype; bilinear: BOOLEAN );
	(*for each gridpoint in target grid, find value in source grid based on retrograd application of map u,v . ds and dt is grid spacing in source and target *)
	(*! to do: speed up by doing it linewise or slicewise *)
	VAR x, y, ox, oy, lenx, leny: SIZE;
	a, b: Datatype;
	BEGIN
		lenx:=LEN(source,1); leny:=LEN(source,0);
		IF  LEN( target ) = 0 THEN NEW(target,leny,lenx) END;
		FOR y := 0 TO LEN( source, 0 ) - 1 DO
			FOR x := 0 TO lenx - 1 DO
				IF LEN( u ) = 0 THEN ox := x ELSE
					IF bilinear THEN
						a := x - dt/ds * u[y, x];  ox := ENTIER( a );  a := 1 - a + ox;
					ELSE (*nearest neighbour*)
						ox := ENTIER( x - dt/ds * u[y, x] + 0.5 );
					END;
					IF ox < 0 THEN ox := 0 (* apply boundary *)
					ELSIF ox > lenx - 2 THEN ox := lenx - 2 (* apply boundary *)
					END;
				END;
				IF LEN( v ) = 0 THEN oy := y ELSE
					IF bilinear THEN
						b := y - dt/ds * v[y, x];  oy := ENTIER( b );  b := 1 - b + oy;
					ELSE (*nearest neighbour*)
						oy := ENTIER( y - dt/ds * v[y, x] + 0.5 );
					END;
					IF oy < 0 THEN oy := 0 (* apply boundary *)
					ELSIF oy >leny - 2 THEN oy := leny - 2 (* apply boundary *)
					END;
				END;
				IF bilinear THEN
					target[y, x] := a * b * source[oy, ox] + a * (1 - b) * source[oy + 1, ox] + (1 - a) * b * source[oy, ox + 1] + (1 - a) * (1 - b) * source[oy + 1, ox + 1];
					(*possible improvement: see VolumePDE*)
				ELSE target[y, x] := source[oy, ox];
				END;
			END;
		END;
	END Advect;

END PlanarPDE.

OFormatter.Format *

System.FreeDownTo PlanarPDE ~
