MODULE VolumePDE;
 (**  AUTHOR "Patrick Hunziker, Basel; email: Patrick.Hunziker@swissnano.org";  DATE 2009-2-12 ;
 PURPOSE "implementation of partial differential equations for 3D  grids solved directly in the grid domain";
 LICENCE "free for noncommercial use, as long as  author is cited and this header is kept unchanged " **)

(* here is the principal strategy for solving used here, exemplified with the diffusion equation:
 	 Diffusion equation du/dt = nu  *  Laplacian(u);
	computes scalar field after diffusion from viscosity and scalar field before diffusion.
	 i.e.  (I-nu deltaT Laplacian) u3 = u2 ; i.e.  Dx=x0 ; whereby operator D =   is solved using Jacobi Relaxation
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

IMPORT VolumeBase, Transform:=VolumeTransform, Util:=MatrixUtilities, Nabla:=VolumeNabla;

TYPE
	Datatype* = VolumeBase.Datatype;
	Grid* = ARRAY [*,*,*] OF Datatype;
	PlanarBooleanMap* = ARRAY [*,*] OF BOOLEAN;
	VolumeBooleanMap* = ARRAY [*,*,*] OF BOOLEAN;
	Boundary* = PROCEDURE{DELEGATE} ( VAR boundary: Grid );

TYPE
	Constraint* = OBJECT  (*untested in 3D*)(*! extend/apply also with VolumeBooleanMap*)
	VAR constraint*, smallconstraint*, c,c0: Grid;
		Constrain*: Boundary;
		map*,smallmap*, m,m0: PlanarBooleanMap;
		resized:BOOLEAN;
		len,newLen: ARRAY [*] OF SIZE;
	PROCEDURE Resize(w,h:SIZE); (*implementation limitation: binary size steps*) (*!TO DO: adapt Resize similar to MatrixPDE.Mod*)
	VAR x,y,z:SIZE;
	BEGIN
		IF  (h#LEN(constraint,1)) OR (w#LEN(constraint,2)) THEN (*no reduction along dimension 0 *)
			resized:=TRUE;
			len:=LEN(constraint);

			m:=m0; m:=map;
			c:=c0; c:=constraint;
			WHILE (LEN(smallconstraint,0)>1) & ((LEN(smallconstraint,0)#h) OR (LEN(smallconstraint,1)#w)) DO
				newLen:=LEN(c); newLen[1..2]:=(newLen[1..2]+1) DIV 2;
				NEW(smallmap, newLen);
				NEW(smallconstraint, newLen);
				FOR z:=0 TO LEN(c,0)-1 DO
					FOR y:=0 TO LEN(c,1)-1 DO
						FOR x:=0 TO LEN(c,2)-1 DO
							IF m[y,x] THEN
								smallmap[y DIV 2, x DIV 2]:= m[y,x]; (*redundant multiplicity z times *)
								smallconstraint[z, y DIV 2,x DIV 2]:= c[z,y,x]
							END; (* hack*)
						END;
					END;
				END;
				m:=m0; m:=smallmap;
				c:=c0; c:=smallconstraint;
			END;

			(*

			IF  (h#LEN(smallconstraint,1)) OR (w#LEN(smallconstraint,2))  THEN
				smallconstraint:=c0; smallconstraint:=constraint;
				smallmap:=m0; smallmap:=map;
				WHILE (LEN(smallconstraint,0)>1) & ((LEN(smallconstraint,0)#h) OR (LEN(smallconstraint,1)#w)) DO (*incomplete logic ...*)
					Transform.Reduce3D(smallconstraint,c,NIL,{1,2},Transform.mirrorH);
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
	VAR w,h,i:SIZE;
	BEGIN
		IF LEN(constraint)=0 THEN RETURN END;
		w:=LEN(data,1); h:=LEN(data,0);
		IF (~resized & ((h#LEN(constraint,0))OR(w#LEN(constraint,1)))) OR
			(resized & ((h#LEN(smallconstraint,0))OR(w#LEN(smallconstraint,1))))
		THEN
			Resize(w,h);
		END;
		FOR i:=0 TO LEN(data,0)-1 DO
			IF resized THEN
				data[i]:=Util.AssignIF(smallconstraint[i],smallmap);
			ELSE data[i]:=Util.AssignIF(constraint[i],map);
			END;
		END;
	END Constrain0;
	PROCEDURE Set*(CONST constraint:Grid; CONST map: PlanarBooleanMap);
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
	Backward time, centered space (BTCS) approach
	using initial x, and retaining data structure, i.e. without going to a sparse matrix format ..
	*)

	VAR null, temp, xsmall: Grid;
		alpha, beta: Datatype;
		child: Laplace;
		iterationScale*:=3:INTEGER;(*allows tailoring of iterations at different resolution levels in multigrid *)
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;

		(*implicit solving BTCS*)
		PROCEDURE Solve*(VAR x: Grid;  threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary );   (*TO DO: check for convergence*)
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 3D shape, in contrast to the linearization used for matrix algebra*)
			alpha:= 0; beta:=6;
			JacobiSteps( null, x, temp, alpha, beta, Boundaries, iterations );
		END Solve;

		(*implicit solving BTCS*)
		PROCEDURE SolveMultigrid*( VAR x: Grid;  threshold: Datatype;  minsize, iterations, smoothings: SIGNED32;  Boundaries: Boundary );
		BEGIN
			alpha:= 0; beta:=6;
			IF (LEN( x, 0 ) > 2*minsize-1) & (LEN(x,1)> 2*minsize-1) & (LEN(x,2)> 2*minsize-1) THEN
				JacobiSteps( null, x, temp, alpha, beta, Boundaries, smoothings );  (*here reduction of Boundary checking may impact speed*)

				xsmall:=Reduce( x );
				IF child = NIL THEN NEW( child); child.iterationScale:=iterationScale END;
				child.SolveMultigrid( xsmall, threshold, minsize, iterationScale*iterations, iterationScale*smoothings, Boundaries );
				x:=Expand( xsmall );

				JacobiSteps( null, x, temp, alpha, beta, Boundaries, smoothings );  (*here reduction of Boundary checking may impact speed*)
			ELSE
				Solve ( x, threshold,iterations, Boundaries );
			END;
		END SolveMultigrid;

	END Laplace;


TYPE
	Poisson* = OBJECT
	(** Poisson equation Laplacian(x)=b is solved using Jacobi Relaxation,
	Backward time, centered space (BTCS) approach
	using initial x, and retaining data structure, i.e. without going to a sparse matrix format .
	ds is grid spacing
	*)

	VAR temp, bsmall, xsmall: Grid;
		alpha, beta: Datatype;
		child: Poisson;
		iterationScale*:=3:INTEGER;(*allows tailoring of iterations in multiresolutions*)
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;

		(*implicit solving BTCS*)
		PROCEDURE Solve*(CONST b: Grid; VAR x: Grid;  ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary );   (*TO DO: check for convergence*)
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 3D shape, in contrast to the linearization used for matrix algebra*)
			alpha:= -ds*ds; beta:= 6;
			JacobiSteps( b, x, temp, alpha, beta, Boundaries, iterations );
		END Solve;

		(*implicit solving BTCS*)
		PROCEDURE SolveMultigrid*( CONST b: Grid; VAR x: Grid;  ds, threshold: Datatype;  minsize, iterations, smoothings: SIGNED32;  Boundaries: Boundary );
		BEGIN
			alpha:= -ds*ds; beta:=6;
			IF (LEN( x, 0 ) > 2*minsize-1) & (LEN(x,1)> 2*minsize-1)& (LEN(x,2)> 2*minsize-1) THEN
				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings );  (*here reduction of Boundary checking may impact speed*)

				xsmall:=Reduce( x );
				bsmall:=Reduce( b );
				IF child = NIL THEN NEW( child);child.iterationScale:=iterationScale END;
				child.SolveMultigrid( bsmall, xsmall, 2*ds, threshold, minsize, iterationScale*iterations, iterationScale*smoothings, Boundaries );
				x:=Expand( xsmall );

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings );  (*here reduction of Boundary checking may impact speed*)
			ELSE
				Solve ( b, x, ds, threshold,iterations, Boundaries );
			END;
		END SolveMultigrid;

	END Poisson;

TYPE
	Diffusion* = OBJECT
	(** Diffusion equation = Heat equation:  du/dt = nu  *  Laplacian(u);
	Here, we compute scalar field u(t+dt) after diffusion from viscosity and scalar field (u(t) before diffusion.
	Backward time, centered space (BTCS) approach
	 i.e.  (I-nu deltaT Laplacian) u3 = u2 ; i.e.  Dx=x0 ; whereby operator D =   is solved using Jacobi Relaxation
	x0 is old field, x is new field after diffusion step; ds is grid spacing *)

	VAR temp, xsmall, bsmall: Grid;
		alpha, beta: Datatype;
		child: Diffusion;
		iterationScale*:=3:INTEGER;(*allows tailoring of iterations in multiresolutions*)
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;

		(*implicit solving BTCS*)
		PROCEDURE Solve*( CONST b:Grid; VAR x: Grid;  nu, dt, ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary );
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 3D shape, in contrast to the linearization typically used for matrix algebra*)
			alpha:=ds * ds / (nu*dt);  beta:=6+alpha;
			JacobiSteps( b, x, temp, alpha, beta, Boundaries, iterations );
		END Solve;

		(*implicit solving BTCS*)
		PROCEDURE SolveMultigrid*( CONST b: Grid; VAR x: Grid;  nu, dt, ds, threshold: Datatype;  minsize, iterations, smoothings: SIGNED32;  Boundaries: Boundary );
		BEGIN
			alpha:=ds * ds  / (nu*dt);  beta:=6+alpha;
			IF (LEN( x, 0 ) > 2*minsize-1) & (LEN(x,1)> 2*minsize-1)& (LEN(x,2)> 2*minsize-1) THEN
				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings ); (*here reduction of Boundary checking may impact speed*)

				xsmall:=Reduce( x );
				bsmall:=Reduce( b );
				IF child = NIL THEN NEW( child); child.iterationScale:=iterationScale END;
				child.SolveMultigrid( bsmall, xsmall, nu, dt, 2* ds, threshold, minsize, iterationScale*iterations,iterationScale*smoothings, Boundaries );
				x:=Expand( xsmall );

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings);  (*here reduction of Boundary checking may impact speed*)
			ELSE
				Solve ( b, x, nu, dt, ds, threshold,iterations, Boundaries );
			END;
		END SolveMultigrid;

	END Diffusion;

TYPE
	Wave* = OBJECT (*# TO DO: wave equation needs further testing*)
	(** Wave  equation = d2u/dt2 = c2  *  Laplacian(u);
	computes scalar field u after wave travel interval dt, wave speed c and scalar field at t0.
	Backward time, centered space (BTCS) approach
	phi is old field at (t); phim1 is old field at (t-dt);, x is new field after wavepropagation step at (t+dt); ds is grid spacing *)

	VAR temp, tempse, temps, tempsm, xsmall, b: Grid;
		alpha, beta: Datatype;
		child: Wave;
		iterationScale*:=3:INTEGER;(*allows tailoring of iterations in multiresolutions*)
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;
 		(*explicit solving-forward time, centered space; not yet tested*)
		PROCEDURE SolveExplicit*( CONST phim1,phi0 : Grid; VAR x: Grid;  c, dt, ds: Datatype; Boundaries: Boundary); (* explicit solution Forward time, centered space-not unconditionally stable*)
		BEGIN
			(* Laplacian(A)=second derivative of x is computed directly (forward/explicit scheme), (solution not unconditiionally stable).
		The data are kept in original 3D shape, in contrast to the linearization typically used for matrix algebra*)
			Stencil(phi0,temp);
			tempse:=6.0*phi0;
			temp:=temp-tempse;
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
			alpha:=ds * ds / (c*c*dt*dt);  beta:=6+alpha;
			temps:=2*phi0;
			temps:=temps-phim1;
			JacobiSteps( temps, x, temp, alpha, beta, Boundaries, iterations );
		END Solve;

			(*implicit solving BTCS*)
		PROCEDURE SolveMultigrid*( CONST phim1,phi0:Grid;  VAR x: Grid;  c, dt, ds, threshold: Datatype;  minsize, iterations, smoothings: SIGNED32;  Boundaries: Boundary );
		BEGIN
			alpha:=ds * ds  / (c*c*dt*dt);  beta:=6+alpha;
			IF (LEN( x, 0 ) > 2*minsize-1) & (LEN(x,1)> 2*minsize-1)& (LEN(x,2)> 2*minsize-1) THEN
				tempsm:=2*phi0;
				b:=tempsm-phim1;
				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings ); (*here reduction of Boundary checking may impact speed*)

				xsmall:=Reduce( x );
				IF child = NIL THEN NEW( child); child.iterationScale:=iterationScale END;
				child.SolveMultigrid( Reduce(phim1), Reduce(phi0), xsmall, c, dt, 2* ds, threshold, minsize, iterationScale*iterations,iterationScale*smoothings, Boundaries );
				x:=Expand( xsmall );

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings);  (*here reduction of Boundary checking may impact speed*)
			ELSE
				Solve ( phim1, phi0, x, c, dt, ds, threshold,iterations, Boundaries );
			END;
		END SolveMultigrid;

	END Wave;

	(*advection operator. for  backward time approach, use Advect() below. 	*)
	TYPE Advection*= OBJECT
		VAR U, G, G1,G2, R: Nabla.VectorField;
			g, div: Grid;

			(*incompressible, scalar, simplistic, for u= velocity field, A=scalar conserved quantity*)
			(* dA/dt =-Div( A u), in the case that Nabla(u)=0 and the flow is thus solenoidal , the equation is equivalent
			     dA/dt=-u dot Grad(A); *)
			PROCEDURE Solenoidal*(CONST u,v,w:Grid; CONST A: Grid): Grid; (* returns dA/dt *) (* if applied in an explicit manner, this may converge first, but then may lead to instability/explosion *)
			BEGIN
				IF (LEN(U,0) # 3) OR (LEN(U,1) # LEN(u,0)) OR (LEN(U,2) # LEN(u,1)) OR (LEN(U,3) # LEN(u,2)) THEN (*LEN(U) # [3,LEN(u,0), LEN(u,1), LEN(u,2)]*)
					NEW(U, 3, LEN(u,0), LEN(u,1), LEN(u,2))
				END; (*to do: avoid allocation*)
				U[0]:=u; U[1]:=v; U[2]:=w;
				RETURN -Nabla.DirectionalDerivative(A, U, Nabla.centered);
			END Solenoidal;


			(* skew symmetric form for the advection operator, see https://en.wikipedia.org/wiki/Advection#Treatment_of_the_advection_operator_in_the_incompressible_Navier_Stokes_equations*)
			PROCEDURE SkewSymmetric*(CONST u,v,w:Grid; VAR u1,v1,w1:Grid); (*returns operator, to be operated on entity*)(*! to do: eliminate local variables/reallocations*)
			(*VAR  g, div: Grid;*)
			BEGIN
				IF (LEN(U,0) # 3) OR (LEN(U,1) # LEN(u,0)) OR (LEN(U,2) # LEN(u,1)) OR (LEN(U,3) # LEN(u,2)) THEN (*LEN(U) # [3,LEN(u,0), LEN(u,1), LEN(u,2)]*)
					NEW(U, 3, LEN(u,0), LEN(u,1), LEN(u,2))
				END;
				IF (DIM(g)#DIM(u)) OR (LEN(g)#LEN(u)) THEN NEW(g, LEN(u)) END;
				U[0]:=u; U[1]:=v; U[2]:=w;
				g:= u.*u; g:=g+v.*v; g:=g+w.*w;
				g:=0.5*g;
				G:=Nabla.Grad(g, Nabla.centered);

				R:=Nabla.Rot(U, Nabla.centered);
				G1:=Cross(R, U);
				G:=G+G1;

				IF (DIM(div)#DIM(u)) OR (LEN(div)#LEN(u)) THEN NEW(div, LEN(u)) END;
				div:=Nabla.Div(U, Nabla.centered);
				G1[0]:=u .* div;
				G1[1]:=v .* div;
				G1[2]:=w .* div;
				G1:=0.5 * G1;
				G:=G+G1;

				u1:=G[0]; (*! to do: write to u1,v1,w1 directly instead of copying*)
				v1:=G[1];
				w1:=G[2];
			END SkewSymmetric;
		END Advection;

	PROCEDURE Cross(CONST a,b: Nabla.VectorField): Nabla.VectorField;
	BEGIN
		IF LEN(RESULT)#LEN(a) THEN NEW(RESULT,LEN(a)) END;
		RESULT[0]:= a[1].*b[2]-a[2].*b[1];
		RESULT[1]:= a[2].*b[0]-a[0].*b[2];
		RESULT[2]:= a[0].*b[1]-a[1].*b[0];
		RETURN RESULT
	END Cross;

	PROCEDURE Multiply(CONST a: Nabla.VectorField; CONST b: Nabla.ScalarField): Nabla.VectorField;
	BEGIN
		IF LEN(RESULT)#LEN(a) THEN NEW(RESULT,LEN(a)) END;
		RESULT[0]:=a[0] .* b;
		RESULT[1]:=a[1] .* b;
		RESULT[2]:=a[2] .* b;
		RETURN RESULT
	END Multiply;

	PROCEDURE Dot(CONST a,b: Nabla.VectorField): Nabla.ScalarField;
	BEGIN
		IF LEN(RESULT)#LEN(b)[1..3] THEN NEW(RESULT,LEN(b)[1..3]) END;
		RESULT:=a[0] .* b[0];
		RESULT:=RESULT+a[1] .* b[1];
		RESULT:=RESULT+a[2] .* b[2];
		RETURN RESULT
	END Dot;

  	PROCEDURE AllocateSame( VAR x: Grid; CONST templ: Grid ); (*allocation to size of template, with reuse if possible*)
 	BEGIN
	 	IF (LEN( x, 0 ) # LEN( templ, 0 )) OR (LEN( x, 1 ) # LEN( templ, 1 )) OR (LEN( x, 2 ) # LEN( templ, 2 ))  THEN
		 	NEW( x, LEN( templ, 0 ), LEN( templ, 1 ), LEN( templ, 2));
	 	END;
 	END AllocateSame;

	(* TBD: use VolumeTransform.Mod or VolumeResize.Mod *)
	PROCEDURE Reduce( CONST g: Grid ): Grid;  (* there was a problem until at least 30.9.15 in the compiler with the LEN(RESULT,i), possibly leading to much allocation overhead here *)
	VAR L00,L01,L10,L11,L20,L21:SIZE;
	BEGIN
		L00:=(LEN( g, 0 )+0) DIV 2-1; L01:= (LEN( g, 0 )+1)  DIV 2-1;
		L10:=(LEN( g, 1 )+0) DIV 2-1; L11:= (LEN( g, 1 )+1)  DIV 2-1;
		L20:=(LEN( g, 2 )+0) DIV 2-1; L21:= (LEN( g, 2 )+1)  DIV 2-1;

		IF (LEN( RESULT, 0 ) # (L01+1)) OR (LEN( RESULT, 1 ) # (L11+1)) OR (LEN( RESULT, 2 ) # (L21+1)) THEN NEW( RESULT, L01+1, L11+1,L21+1 ) END;
		RESULT[.. L01,..L11,..L21]:=g[.. BY 2,..BY 2,..BY 2];
		RESULT[.. L00,..L11,..L21]:=RESULT[.. L00,..L11,..L21]+g[1.. BY 2,..BY 2,..BY 2];
		RESULT[.. L01,..L10,..L21]:=RESULT[.. L01,..L10,..L21]+g[.. BY 2, 1.. BY 2,..BY 2];
		RESULT[.. L00,..L10,..L21]:=RESULT[.. L00,..L10,..L21]+g[1.. BY 2, 1.. BY 2,..BY 2];

		RESULT[.. L01,..L11,..L20]:=RESULT[.. L01,..L11,..L20 ]+g[.. BY 2,..BY 2, 1.. BY 2];
		RESULT[.. L00,..L11,..L20]:=RESULT[.. L00,..L11,..L20]+g[1.. BY 2,..BY 2, 1.. BY 2];
		RESULT[.. L01,..L10,..L20]:=RESULT[.. L01,..L10,..L20]+g[.. BY 2, 1.. BY 2, 1.. BY 2];
		RESULT[.. L00,..L10,..L20]:=RESULT[.. L00,..L10,..L20]+g[1.. BY 2, 1.. BY 2, 1.. BY 2];

		RESULT[.. L01,..L11]:=0.125 * RESULT[.. L01,..L11];

		IF ODD( LEN( g, 0 ) ) THEN RESULT[L01,.., ..]:=2 * RESULT[L01,.., ..];   (*missing contributions to this boundary data*)	END;
		IF ODD( LEN( g, 1 ) ) THEN RESULT[.. , L11, ..]:=2 * RESULT[.. , L11 , ..];   (*missing contributions to this boundary data*)	END;
		IF ODD( LEN( g, 2 ) ) THEN RESULT[.. ,.., L21]:=2 * RESULT[.. , .., L21];   (*missing contributions to this boundary data*)END;
		RETURN RESULT
	END Reduce;

	PROCEDURE Expand( CONST g: Grid ): Grid;
	VAR L00,L01,L10,L11,L20,L21:SIZE;
	BEGIN
		L00:=(LEN( RESULT, 0 )+0) DIV 2-1; L01:= (LEN( RESULT, 0 )+1) DIV 2-1;
		L10:=(LEN( RESULT, 1 )+0) DIV 2-1; L11:= (LEN( RESULT, 1 )+1) DIV 2-1;
		L20:=(LEN( RESULT, 2 )+0) DIV 2-1; L21:= (LEN( RESULT, 2 )+1) DIV 2-1;

		IF (LEN( g, 0 ) # (L01+1)) OR (LEN( g, 1 ) # (L11+1)) OR (LEN( g, 2 ) # (L21+1))THEN NEW( RESULT, 2 * LEN( g, 0 ), 2 * LEN( g, 1 ) , 2 * LEN( g, 2) ) END;
		RESULT[.. BY 2,..BY 2,..BY 2]:=g[.. L01,..L11, ..L21];
		RESULT[1.. BY 2,..BY 2,..BY 2]:=g[.. L00,..L11, ..L21];
		RESULT[.. BY 2, 1.. BY 2,..BY 2]:=g[.. L01,..L10, ..L21];
		RESULT[1.. BY 2, 1.. BY 2,..BY 2]:=g[.. L00,..L10, ..L21];

		RESULT[.. BY 2,..BY 2, 1.. BY 2]:=g[.. L01,..L11,..L20];
		RESULT[1.. BY 2,..BY 2, 1.. BY 2]:=g[.. L00,..L11,..L20];
		RESULT[.. BY 2, 1.. BY 2, 1.. BY 2]:=g[.. L01,..L10,..L20];
		RESULT[1.. BY 2, 1.. BY 2, 1.. BY 2]:=g[.. L00,..L10,..L20];
		RETURN RESULT
	END Expand;

	PROCEDURE Stencil( CONST x: Grid;  VAR x1: Grid); (*3D stencil for finite difference*) (* not in-place *)
	VAR lenx, leny, lenz: SIZE;
	BEGIN
		AllocateSame(x1,x);(*with reuse if possible*)
		lenx:=LEN( x, 2 );  leny:=LEN( x, 1 ); lenz:= LEN(x,0);
		(*3D stencil*)
		x1[..,..,..lenx-2]:=	x[..,.., 1..];  									x1[..,.., lenx-1]:=	x[..,.., lenx-1];   (*boundary*) (* performance: no SIMD aligmnent here *)
		x1[..,.., 1..]:=			x1[..,.., 1..]+x[..,..,..lenx-2];  	x1[..,.., 0]:=			x1[..,.., 0]+x[..,.., 0];   (*boundary*) (* performance: no SIMD aligmnent here *)

		x1[..,..leny-2,..]:=	x1[..,..leny-2,..]+x[.., 1..,..];  	x1[.., leny-1,..]:=	x1[.., leny-1,..]+x[.., leny-1,..];   (*boundary*)
		x1[.., 1..,..]:=			x1[.., 1..,..]+x[..,..leny-2,..];  	x1[.., 0,..]:=			x1[.., 0,..]+x[.., 0,..];   (*boundary*)

		x1[..lenz-2,..,..]:=	x1[..lenz-2,..,..]+x[ 1..,.., ..];  	x1[ lenz- 1,..,..]:=x1[ lenz- 1,..,..]+x[lenz-1,.., ..];   (*boundary*)
		x1[ 1..,.., ..]:=			x1[ 1..,..,..]+x[..lenz-2,..,..];  	x1[ 0,.., ..]:=		x1[ 0,.. ,..]+x[ 0,.., ..];   (*boundary*)
	END Stencil;

PROCEDURE Stencil333( CONST x: Grid;  VAR x1: Grid); (*3D stencil for finite difference -not allocating temp memory, but slow, probably due to its data copy overhead ? but should move to cache... *) 
	VAR lenx, leny, lenz, zz,yy,xx: SIZE; x333: ARRAY [3,3,3] OF Datatype; rx,ry,rz:RANGE;
	BEGIN
		AllocateSame(x1,x);(*with reuse if possible*)
		lenx:=LEN( x, 2 );  leny:=LEN( x, 1 ); lenz:= LEN(x,0);
		FOR zz:=1 TO lenz-2 DO
			FOR yy:=1 TO leny-2 DO
				FOR xx:=1 TO lenx-2 DO
					rz:=zz-1..zz+1; ry:=yy-1..yy+1; rx:=xx-1..xx+1;
					x333:=x[rz,ry,rx];
					x1[zz,yy,xx]:=x333[1,1,0]	+x333[1,1,2]	+x333[1,0,1]	+x333[1,2,1]	+x333[0,1,1]	+x333[2,1,1];
				END;
			END;
		END;
		zz:=0;
		FOR yy:=1 TO leny-2 DO
			FOR xx:=1 TO lenx-2 DO
				x333[1..,..,..]:=x[zz..zz+1, yy-1..yy+1, xx-1..xx+1];
				x1[zz,yy,xx]:=x333[1,1,0]+x333[1,1,2]+x333[1,0,1]+x333[1,2,1]+x333[1,1,1]+x333[2,1,1];
			END;
		END;
		zz:=lenz-1;
		FOR yy:=1 TO leny-2 DO
			FOR xx:=1 TO lenx-2 DO
				x333[..1,..,..]:=x[zz-1..zz, yy-1..yy+1, xx-1..xx+1];
				x1[zz,yy,xx]:=x333[1,1,0]+x333[1,1,2]+x333[1,0,1]+x333[1,2,1]+x333[0,1,1]+x333[1,1,1];
			END;
		END;
		yy:=0;
		FOR zz:=1 TO lenz-2 DO
			FOR xx:=1 TO lenx-2 DO
				x333[..,1..,..]:=x[zz-1..zz+1, yy..yy+1, xx-1..xx+1];
				x1[zz,yy,xx]:=x333[1,1,0]+x333[1,1,2]+x333[1,1,1]+x333[1,2,1]+x333[0,1,1]+x333[2,1,1];
			END;
		END;
		yy:=leny-1;
		FOR zz:=1 TO lenz-2 DO
			FOR xx:=1 TO lenx-2 DO
				x333[..,..1,..]:=x[zz-1..zz+1, yy-1..yy, xx-1..xx+1];
				x1[zz,yy,xx]:=x333[1,1,0]+x333[1,1,2]+x333[1,0,1]+x333[1,1,1]+x333[0,1,1]+x333[2,1,1];
			END;
		END;
		xx:=0;
		FOR zz:=1 TO lenz-2 DO
			FOR yy:=1 TO leny-2 DO
				x333[..,..,1..]:=x[zz-1..zz+1, yy-1..yy+1, xx..xx+1];
				x1[zz,yy,xx]:=x333[1,1,1]+x333[1,1,2]+x333[1,0,1]+x333[1,2,1]+x333[0,1,1]+x333[2,1,1];
			END;
		END;
		xx:=lenx-1;
		FOR zz:=1 TO lenz-2 DO
			FOR yy:=1 TO leny-2 DO
				x333[..,..,..1]:=x[zz-1..zz+1, yy-1..yy+1, xx-1..xx];
				x1[zz,yy,xx]:=x333[1,1,0]+x333[1,1,1]+x333[1,0,1]+x333[1,2,1]+x333[0,1,1]+x333[2,1,1];
			END;
		END;
	END Stencil333;

	PROCEDURE JacobiStep*( CONST b: Grid;  VAR x, x1: Grid;  alpha, beta: Datatype);  (*key procedure for speed*)
	(*this is a key procedure for performance:
	apply the jacobi step to the whole data plane in its original format, which would correspond to the diagonal in the Jacobi Matrix formulation, at once, using a stencil like approach;
	i.e., we do not need to convert the data explicitely into a sparse matrix for doing a smooting=Jacobi step *)
	(*see also description in cited gpugems paper *)
	VAR invbeta: Datatype;
	BEGIN
		invbeta:=1 / beta;
		Stencil(x,x1);
		(*Stencil333(x,x1);*)(*slow, but not allocating large temp memory*)
		IF LEN(b,0)#0 THEN (* b is 0 in case of Laplace equation*)
			x1:=INCMUL(alpha,b); (*! but, INCMUL may not be part of FoxArrayOptimized SSE procedures => slower ??*)
		END;
		x:=invbeta * x1;

		(*ScaledStencil(x,x1,invbeta);(*DOES NOT WORK*)
		IF LEN(b,0)#0 THEN (* b is 0 in case of Laplace equation*)
			x:=INCMUL(alpha,b);
		END;
		(*x:=invbeta * x1;*)
		*)
		
(*		IF LEN(b,0)#0 THEN (* b is 0 in case of Laplace equation*)
			x1:= x1+alpha * b;
		END;
		x:=invbeta * x1;*)
		
		(*IF LEN(b,0)#0 THEN (* b is 0 in case of Laplace equation*)
			x:=alpha * b;
			x:=x+x1;
		END;
		x:=invbeta * x;*)

	END JacobiStep;

	PROCEDURE JacobiSteps( CONST b: Grid;  VAR x, x1: Grid;  alpha, beta: Datatype;  Boundaries: Boundary; iterations:SIGNED32);
	BEGIN
		WHILE iterations>0 DO
			IF Boundaries # NIL THEN Boundaries( x ) END;
			JacobiStep(b,x,x1,alpha,beta);
			DEC(iterations)
		END;
			IF Boundaries # NIL THEN Boundaries( x ) END;
	END JacobiSteps;

(*	PROCEDURE Cast2x2x2X*(a0,a1,b0,b1,c0,c1,d0,d1: FLOAT64):ARRAY [2,2,2] OF FLOAT64;
	BEGIN
		RETURN [[[a0,a1],[b0,b1]],[[c0,c1],[d0,d1]]];
	END Cast2x2x2X;
*)
	PROCEDURE -Cast2x2x2*(a0,a1,b0,b1,c0,c1,d0,d1: FLOAT64):ARRAY [2,2,2] OF FLOAT64;
	BEGIN
		RESULT[0,0,0]:=a0;
		RESULT[0,0,1]:=a1;
		RESULT[0,1,0]:=b0;
		RESULT[0,1,1]:=b1;
		RESULT[1,0,0]:=c0;
		RESULT[1,0,1]:=c1;
		RESULT[1,1,0]:=d0;
		RESULT[1,1,1]:=d1;
		RETURN RESULT
	END Cast2x2x2;

(*	PROCEDURE Cast2x2x2B*(VAR res:ARRAY [2,2,2] OF FLOAT64; a0,a1,b0,b1,c0,c1,d0,d1: FLOAT64);
	BEGIN
		res[0,0,0]:=a0;
		res[0,0,1]:=a1;
		res[0,1,0]:=b0;
		res[0,1,1]:=b1;
		res[1,0,0]:=c0;
		res[1,0,1]:=c1;
		res[1,1,0]:=d0;
		res[1,1,1]:=d1;
	END Cast2x2x2B;
*)
	PROCEDURE Advect*( CONST source,  u, v, w: Grid;  VAR target: Grid;  dt, ds: Datatype; bilinear: BOOLEAN );   (* to do: other interpolation methods *)
	(*for each gridpoint in target grid, find value in source grid based on retrograd application of map u,v,w ;  u and ds are in SI units*)
	(* to do: speed up by doing it linewise or slicewise *)
	VAR x, y, z,  ox, oy, oz: SIZE;  a, b, c: Datatype;  len,lenu,lenv,lenw:ARRAY [3] OF SIZE; tmp222: ARRAY [2,2,2] OF Datatype;
	BEGIN
		len:=LEN(source);lenu:=LEN(u); lenv:=LEN(v); lenw:=LEN(w);
		IF  LEN(target)# LEN(source) THEN NEW(target,LEN(source)) END;
		FOR z:=0 TO len[0]-1 DO
			FOR y:=0 TO len[1]-1 DO
				FOR x:=0 TO len[2]-1 DO
					IF lenu = 0 THEN ox:=x ELSE
						IF bilinear THEN
							a:=x-dt/ds * u[z, y, x];  ox:=ENTIER( a );  a:=1-a+ox;
						ELSE (*nearest neighbour*)
							ox:=ENTIER( x-dt/ds * u[z, y, x]+0.5 );
						END;
						IF ox < 0 THEN ox:=0; a:=0; (* apply boundary *)
						ELSIF ox > len[2]-2 THEN ox:=len[2]-2; a:=0; (* apply boundary *)
						END;
					END;
					IF lenv = 0 THEN oy:=y ELSE
						IF bilinear THEN
							b:=y-dt/ds * v[z, y, x];  oy:=ENTIER( b );  b:=1-b+oy;
						ELSE (*nearest neighbour*)
							oy:=ENTIER( y-dt/ds * v[z, y, x]+0.5 );
						END;
						IF oy < 0 THEN oy:=0; b:=0; (* apply boundary *)
						ELSIF oy > len[1]-2 THEN oy:=len[1]-2; b:=0; (* apply boundary *)
						END;
					END;
					IF lenw = 0 THEN oz:=z ELSE
						IF bilinear THEN
							c:=z-dt/ds * w[z, y, x];  oz:=ENTIER( c );  c:=1-c+oz;
						ELSE (*nearest neighbour*)
							oz:=ENTIER( z-dt/ds * w[z, y, x]+0.5 );
						END;
						IF oz < 0 THEN oz:=0; c:=0; (* apply boundary *)
						ELSIF oz > len[0]-2 THEN oz:=len[0]-2; c:=0; (* apply boundary *)
						END;
					END;
					IF bilinear THEN
						(*
						target[z, y, x] :=
									a * b * c * 		source[oz, oy, ox] +
									(1-a) * b * c *	source[oz, oy, ox+1] +
									a * (1-b) * c * source[oz, oy+1, ox] +
									a * b * (1-c) * source[oz+1, oy, ox] +
									(1-a) * (1-b) * c * 	source[oz, oy+1, ox+1] +
									(1-a) * b * (1 -c) * 	source[oz+1, oy, ox+1] +
									a * (1-b) * (1-c)*		source[oz+1, oy+1, ox] +
									(1-a)*(1-b)*(1-c)*	source[oz+1, oy+1, ox+1];
									*)
						(*tmp222:=[[[a*b*c, (1-a) * b * c],
										  [a * (1-b) * c ,(1-a) * (1-b) * c]],
										[[a * b * (1-c),(1-a) * b * (1 -c) ],
										  [a * (1-b) * (1-c),(1-a)*(1-b)*(1-c)]]];
						target[z, y, x]:=tmp222 +* source[oz..oz+1,oy..oy+1,ox..ox+1];*) (* slow *)

						tmp222:=Cast2x2x2(a*b*c, (1-a) * b * c,
										  a * (1-b) * c , (1-a) * (1-b) * c,
										a * b * (1-c), (1-a) * b * (1 -c),
										  a * (1-b) * (1-c), (1-a)*(1-b)*(1-c));
						target[z, y, x]:=tmp222 +* source[oz..oz+1,oy..oy+1,ox..ox+1];
						(*
						target[z, y, x] :=[[[a*b*c, (1-a) * b * c],
										  [a * (1-b) * c ,(1-a) * (1-b) * c]],
										[[a * b * (1-c),(1-a) * b * (1 -c) ],
										  [a * (1-b) * (1-c),(1-a)*(1-b)*(1-c)]]]			(*! on the fly array construction is still performance killer -> compiler !*)
										 +* source[oz..oz+1,oy..oy+1,ox..ox+1];
						*)

					ELSE target[z, y, x]:=source[oz, oy, ox];
					END;
				END;
			END;
		END;
	END Advect;

PROCEDURE Test*;
VAR A,C,B,D: Grid; s:Datatype;
BEGIN
	NEW(A,12,12,12); A:=5;
	NEW(C,12,12,12);
	NEW(B,(LEN(A,0)+1) DIV 2, (LEN(A,1)+1) DIV 2, (LEN(A,2)+1) DIV 2);
	B:=Reduce(A);
	C:=Expand(B);
	s:=SUM(A-C);
	HALT(101);
END Test;

END VolumePDE.

VolumePDE.Test

System.FreeDownTo VolumePDE ~

Use: See TestVolumePDE.Mod
