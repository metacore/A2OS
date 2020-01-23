MODULE LinearPDE;
 (**  AUTHOR "Patrick Hunziker, Basel; email: Patrick.Hunziker@swissnano.org";  DATE 2009-2-12 ;
 PURPOSE "implementation of partial differential equations for 2D  grids solved directly in the grid domain";
 LICENCE "free for noncommercial use, as long as  author is cited and this header is kept unchanged " **)

IMPORT MatrixBase; XXX has to be converted from 2D to 1D first

TYPE
	Datatype* = MatrixBase.Datatype;
	Grid* = ARRAY [*] OF Datatype;
	Boundary* = PROCEDURE{DELEGATE} ( VAR boundary: Grid );

TYPE
	Poisson* = OBJECT
	(** Poisson equation Laplacian(x)=b is solved using Jacobi Relaxation,
	using initial x, and retaining data structure, i.e. without going to a sparse matrix format .
	ds is grid spacing
	*)

	VAR temp, bsmall, xsmall: Grid;
		alpha, beta: Datatype;
		child: Poisson;

		PROCEDURE & Init;
		BEGIN
		END Init;
		(** ds is spacing.  *)
		PROCEDURE Solve*(CONST b: Grid; VAR x: Grid;  ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary );   (*TO DO: check for convergence*)
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 2D shape, in contrast to the linearization used for matrix algebra*)
			alpha:= -ds*ds; beta:=2;
			IF (LEN( temp, 0 ) # LEN( b, 0 )) OR (LEN( temp, 1 ) # LEN( b, 1 )) THEN NEW( temp, LEN( b, 0 ), LEN( b, 1 ) );  END;
			LOOP
				JacobiStep( b, x, temp, alpha, beta, Boundaries );  DEC( iterations );
				IF (iterations <= 0 ) (*OR ((threshold > residual))*) THEN RETURN END;
			END;
		END Solve;

		PROCEDURE SolveMultigrid*( CONST b: Grid; VAR x: Grid;  ds, threshold: Datatype;  minsize, iterations: SIGNED32;  Boundaries: Boundary );
		BEGIN
			alpha:= -ds*ds; beta:=2;
			IF (LEN( temp, 0 ) # LEN( b, 0 )) OR (LEN( temp, 1 ) # LEN( b, 1 )) THEN NEW( temp, LEN( b, 0 ), LEN( b, 1 ) );  END;
			IF (LEN( x, 0 ) > minsize) & (LEN(x,1)> minsize) THEN

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, 4 );  (*here reduction of Boundary checking may impact speed*)

				xsmall := Reduce( x );
				bsmall := Reduce( b );
				IF child = NIL THEN NEW( child) END;
				child.SolveMultigrid( bsmall, xsmall, 2*ds, threshold, minsize, iterations, Boundaries );
				x := Expand( xsmall );

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, 10 );  (*here reduction of Boundary checking may impact speed*)

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

		PROCEDURE & Init;
		BEGIN
		END Init;

		PROCEDURE Solve*( CONST b:Grid; VAR x: Grid;  nu, dt, ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary );
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 2D shape, in contrast to the linearization typically used for matrix algebra*)
			alpha := ds * ds / (nu*dt);  beta := 4 + alpha;
			IF (LEN( temp, 0 ) # LEN( b, 0 )) OR (LEN( temp, 1 ) # LEN( b, 1 )) THEN NEW( temp, LEN( b, 0 ), LEN( b, 1 ) );  END;
			LOOP
				JacobiStep( b, x, temp, alpha, beta, Boundaries );
				DEC( iterations );
				IF (iterations <= 0 ) (*OR ((threshold > residual))*) THEN RETURN END;
			END;
		END Solve;

		PROCEDURE SolveMultigrid*( CONST b: Grid; VAR x: Grid;  nu, dt, ds, threshold: Datatype;  minsize, iterations: SIGNED32;  Boundaries: Boundary );
		VAR i:SIGNED32;
		BEGIN
			alpha := ds * ds / (nu*dt);  beta := 2 + alpha;
			IF (LEN( temp, 0 ) # LEN( b, 0 )) OR (LEN( temp, 1 ) # LEN( b, 1 )) THEN NEW( temp, LEN( b, 0 ), LEN( b, 1 ) );  END;
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

	PROCEDURE Reduce( CONST g: Grid ): Grid;
	BEGIN
		IF (LEN( RETURNPARAMETER, 0 ) # ((LEN( g, 0 ) + 1) DIV 2)) OR (LEN( RETURNPARAMETER, 1 ) # ((LEN( g, 1 ) + 1) DIV 2)) THEN NEW( RETURNPARAMETER, (LEN( g, 0 ) + 1) DIV 2, (LEN( g, 1 ) + 1) DIV 2 ) END;
		RETURNPARAMETER[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := g[.. BY 2, .. BY 2];
		RETURNPARAMETER[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := RETURNPARAMETER[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] + g[1.. BY 2, .. BY 2];
		RETURNPARAMETER[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := RETURNPARAMETER[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] + g[.. BY 2, 1.. BY 2];
		RETURNPARAMETER[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := RETURNPARAMETER[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] + g[1.. BY 2, 1.. BY 2];

		RETURNPARAMETER[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := 0.25 * RETURNPARAMETER[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1];

		IF ODD( LEN( g, 0 ) ) THEN
			RETURNPARAMETER[(LEN( g, 0 ) + 1) DIV 2 - 1, .. ] := 2 * RETURNPARAMETER[(LEN( g, 0 ) + 1) DIV 2 - 1, .. ];   (*missing contributions to this boundary data*)
		END;
		IF ODD( LEN( g, 1 ) ) THEN
			RETURNPARAMETER[.. , (LEN( g, 1 ) + 1) DIV 2 - 1] := 2 * RETURNPARAMETER[.. , (LEN( g, 1 ) + 1) DIV 2 - 1];   (*missing contributions to this boundary data*)
		END;
		RETURN RETURNPARAMETER
	END Reduce;

	PROCEDURE Expand( CONST g: Grid ): Grid;
	BEGIN
		IF (LEN( g, 0 ) # ((LEN( RETURNPARAMETER, 0 ) + 1) DIV 2)) OR (LEN( g, 1 ) # ((LEN( RETURNPARAMETER, 1 ) + 1) DIV 2)) THEN NEW( RETURNPARAMETER, 2 * LEN( g, 0 ), 2 * LEN( g, 1 ) ) END;
		RETURNPARAMETER[.. BY 2, .. BY 2] := g[.. (LEN( RETURNPARAMETER, 0 ) + 1) DIV 2 - 1, .. (LEN( RETURNPARAMETER, 1 ) + 1) DIV 2 - 1];
		RETURNPARAMETER[1.. BY 2, .. BY 2] := g[.. (LEN( RETURNPARAMETER, 0 ) + 0) DIV 2 - 1, .. (LEN( RETURNPARAMETER, 1 ) + 1) DIV 2 - 1];
		RETURNPARAMETER[.. BY 2, 1.. BY 2] := g[.. (LEN( RETURNPARAMETER, 0 ) + 1) DIV 2 - 1, .. (LEN( RETURNPARAMETER, 1 ) + 0) DIV 2 - 1];
		RETURNPARAMETER[1.. BY 2, 1.. BY 2] := g[.. (LEN( RETURNPARAMETER, 0 ) + 0) DIV 2 - 1, .. (LEN( RETURNPARAMETER, 1 ) + 0) DIV 2 - 1];  RETURN RETURNPARAMETER
	END Expand;

	PROCEDURE JacobiStep( CONST b: Grid;  VAR x, x1: Grid;  alpha, beta: Datatype;  Boundaries: Boundary );  (*key procedure for speed*)
	(*this is a key procedure for performance:
	apply the jacobi step to the whole data plane in its original format, which would correspond to the diagonal in the Jacobi Matrix formulation, at once, using a stencil like approach;
	i.e., we do not need to convert the data explicitely into a sparse matrix for doing a smooting=Jacobi step *)
	(*see also description in cited gpugems paper *)
	VAR invbeta: Datatype;  lenx, leny: SIGNED32;
	BEGIN
		IF (LEN( x1, 0 ) # LEN( x, 0 )) OR (LEN( x1, 1 ) # LEN( x, 1 )) THEN NEW( x1, LEN( x, 0 ), LEN( x, 1 ) );  END;
		lenx := LEN( x, 1 );  leny := LEN( x, 0 );  invbeta := 1 / beta;
		(*2D stencil*)
		x1[.. leny - 2, .. ] := x[1.., .. ];  x1[leny - 1, .. ] := x1[leny - 2, .. ];   (*boundary*)
		x1[1.., .. ] := x1[1.., .. ] + x[.. leny - 2, .. ];  x1[0, .. ] := x1[1, .. ];   (*boundary*)
		x1[.. , .. lenx - 2] := x1[.. , .. lenx - 2] + x[.. , 1..];  x1[.. , lenx - 1] := x1[.. , lenx - 2];   (*boundary*) (* performance: no SIMD aligmnent here *)
		x1[.. , 1..] := x1[.. , 1..] + x[.. , .. lenx - 2];  x1[.. , 0] := x1[.. , 1];   (*boundary*) (* performance: no SIMD aligmnent here *)
		x1[.. , .. ] := x1[.. , .. ] + alpha * b[.. , .. ];
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
	(*for each gridpoint in target grid, find value in source grid based on retrograd application of map u,v*)
	(* to do: speed up by doing it linewise or slicewise *)
	VAR x, y, ox, oy: SIGNED32;  a, b: Datatype;
	BEGIN
		FOR y := 0 TO LEN( source, 0 ) - 1 DO
			FOR x := 0 TO LEN( source, 1 ) - 1 DO
				IF LEN( u ) = 0 THEN ox := x ELSE
					IF bilinear THEN
						a := x - dt/ds * u[y, x];  ox := ENTIER( a );  a := 1 - a + ox;
					ELSE (*nearest neighbour*)
						ox := ENTIER( x - dt/ds * u[y, x] + 0.5 );
					END;
					IF ox < 0 THEN ox := 0 (* apply boundary *)
					ELSIF ox > LEN( source, 1 ) - 2 THEN ox := LEN( source, 1 ) - 2 (* apply boundary *)
					END;
				END;
				IF LEN( v ) = 0 THEN oy := y ELSE
					IF bilinear THEN
						b := y - dt/ds * v[y, x];  oy := ENTIER( b );  b := 1 - b + oy;
					ELSE (*nearest neighbour*)
						oy := ENTIER( y - dt/ds * v[y, x] + 0.5 );
					END;
					IF oy < 0 THEN oy := 0 (* apply boundary *)
					ELSIF oy > LEN( source, 0 ) - 2 THEN oy := LEN( source, 0 ) - 2 (* apply boundary *)
					END;
				END;
				IF bilinear THEN
					target[y, x] := a * b * source[oy, ox] + a * (1 - b) * source[oy + 1, ox] + (1 - a) * b * source[oy, ox + 1] + (1 - a) * (1 - b) * source[oy + 1, ox + 1];
				ELSE target[y, x] := source[oy, ox];
				END;
			END;
		END;
	END Advect;

END LinearPDE.

OFormatter.Format *