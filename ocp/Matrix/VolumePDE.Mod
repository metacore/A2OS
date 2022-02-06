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
	
	(*number of iterations adapted to resolutio can use the 'iterationScale' variable. If >1, the number of iterations is increased at coarser resolutions*)
	(*not yet implemented: solving the equations could use 'precision achieved' (in literature: e.g. 1E-15 with limiting iterations to 100 for Krylov solver *)

	

IMPORT VolumeBase,Transform:=VolumeTransform, Util:=MatrixUtilities, Nabla:=VolumeNabla, 
	ComputeObjects:=MatrixComputeObjects, Objects, FoxArrayBase, SYSTEM;


TYPE
	Datatype* = VolumeBase.Datatype;
	Grid* = ARRAY [*,*,*] OF Datatype;
	PlanarBooleanMap* = ARRAY [*,*] OF BOOLEAN;
	VolumeBooleanMap* = ARRAY [*,*,*] OF BOOLEAN;
	Region*= VolumeBase.Region;
	Boundary* = PROCEDURE{DELEGATE} ( VAR boundary: Grid; region:=NIL:Region);

TYPE 
	Emphasis*=OBJECT (*circumscribed regions may receive more attention*)
		VAR
			region*: Region; 
			enhancement*:REAL;
			maxLayer*:=MAX(INTEGER):INTEGER;
			next*:Emphasis;
			PROCEDURE &Init*(x0,x1, y0,y1, z0,z1: REAL; enhancement:REAL);(*region relative coordinates [0..1] relative to volume dimensions*)
			BEGIN
				NEW(region);
				SELF.region.x0:=x0; SELF.region.x1:=x1; SELF.region.y0:=y0; SELF.region.y1:=y1; SELF.region.z0:=z0; SELF.region.z1:=z1;
				SELF.enhancement:=enhancement;
			END Init;
	END Emphasis;

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
	PROCEDURE Constrain0(VAR data: Grid; region:=NIL:Region); (*use "constraint" and "map" as constraints; *)
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
		childLevel:=0:INTEGER;
		iterationScale*:=3:INTEGER;(*allows tailoring of iterations at different resolution levels in multigrid *)
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;

		(*implicit solving BTCS*)
		PROCEDURE Solve*(VAR x: Grid;  threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary; emphasis:=NIL:Emphasis );   (*TO DO: check for convergence*)
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 3D shape, in contrast to the linearization used for matrix algebra*)
			alpha:= 0; beta:=6;
			JacobiSteps( null, x, temp, alpha, beta, Boundaries, iterations, emphasis );
		END Solve;

		(*implicit solving BTCS*)
		PROCEDURE SolveMultigrid*( VAR x: Grid;  threshold: Datatype;  minsize, iterations, smoothings: SIGNED32;  Boundaries: Boundary; emphasis:=NIL:Emphasis );
		BEGIN
			alpha:= 0; beta:=6;
			IF (emphasis#NIL)&(emphasis.maxLayer<childLevel) THEN emphasis:=NIL END;
			IF (LEN( x, 0 ) > 2*minsize-1) & (LEN(x,1)> 2*minsize-1) & (LEN(x,2)> 2*minsize-1) THEN
				JacobiSteps( null, x, temp, alpha, beta, Boundaries, smoothings, emphasis );  (*here reduction of Boundary checking may impact speed*)
				xsmall:=Reduce( x );
				IF child = NIL THEN NEW( child); child.iterationScale:=iterationScale; child.childLevel:=childLevel+1 END;
				child.SolveMultigrid( xsmall, threshold, minsize, iterationScale*iterations, (*??*)iterationScale*smoothings, Boundaries, emphasis );
				x:=Expand( xsmall );

				JacobiSteps( null, x, temp, alpha, beta, Boundaries, smoothings, emphasis );  (*here reduction of Boundary checking may impact speed*)
			ELSE
				Solve ( x, threshold,iterations, Boundaries, emphasis );
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

	(*For future parallelization of Poisson, see, e.g.
	https://dl.acm.org/doi/abs/10.1145/882262.882364
	using SOR instead of Jacobi, see Tingting Tang et al. / Procedia Engineering 61 (2013) 136 – 143 
	and https://www.sciencedirect.com/book/9780127730509/iterative-solution-of-large-linear-systems *)

	VAR temp, bsmall, xsmall: Grid;
		alpha, beta: Datatype;
		child: Poisson;
		childLevel:=0:INTEGER;
		iterationScale*:=3:INTEGER;(*allows tailoring of iterations in multiresolutions*)
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;

		(*implicit solving BTCS*)
		PROCEDURE Solve*(CONST b: Grid; VAR x: Grid;  ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary; emphasis:=NIL:Emphasis );   (*TO DO: check for convergence*)
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 3D shape, in contrast to the linearization used for matrix algebra*)
			alpha:= -ds*ds; beta:= 6;
			JacobiSteps( b, x, temp, alpha, beta, Boundaries, iterations, emphasis );
		END Solve;

		(*implicit solving BTCS*)
		PROCEDURE SolveMultigrid*( CONST b: Grid; VAR x: Grid;  ds, threshold: Datatype;  minsize, iterations, smoothings: SIGNED32;  Boundaries: Boundary; emphasis:=NIL:Emphasis );
		BEGIN
			alpha:= -ds*ds; beta:=6;
			IF (emphasis#NIL)&(emphasis.maxLayer<childLevel) THEN emphasis:=NIL END;
			IF (LEN( x, 0 ) > 2*minsize-1) & (LEN(x,1)> 2*minsize-1)& (LEN(x,2)> 2*minsize-1) THEN
				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings, emphasis );  (*here reduction of Boundary checking may impact speed*)

				xsmall:=Reduce( x );
				bsmall:=Reduce( b );
				IF child = NIL THEN NEW( child);child.iterationScale:=iterationScale; child.childLevel:=childLevel+1 END;
				child.SolveMultigrid( bsmall, xsmall, 2*ds, threshold, minsize, iterationScale*iterations, (*??*)iterationScale*smoothings, Boundaries, emphasis );
				x:=Expand( xsmall );

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings, emphasis );  (*here reduction of Boundary checking may impact speed*)
			ELSE
				Solve ( b, x, ds, threshold,iterations, Boundaries, emphasis );
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
		childLevel:=0:INTEGER;
		iterationScale*:=3:INTEGER;(*allows tailoring of iterations in multiresolutions*)
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;

		(*implicit Euler solving BTCS*)
		PROCEDURE Solve*( CONST b:Grid; VAR x: Grid;  nu, dt, ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary; emphasis:=NIL:Emphasis );
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 3D shape, in contrast to the linearization typically used for matrix algebra*)
			alpha:=ds * ds / (nu*dt);  beta:=6+alpha;
			JacobiSteps( b, x, temp, alpha, beta, Boundaries, iterations, emphasis );
		END Solve;

		(*implicit Euler solving BTCS*)
		PROCEDURE SolveMultigrid*( CONST b: Grid; VAR x: Grid;  nu, dt, ds, threshold: Datatype;  minsize, iterations, smoothings: SIGNED32;  Boundaries: Boundary; emphasis:=NIL:Emphasis );
		BEGIN
			alpha:=ds * ds  / (nu*dt);  beta:=6+alpha;
			IF (emphasis#NIL)&(emphasis.maxLayer<childLevel) THEN emphasis:=NIL END;
			IF (LEN( x, 0 ) > 2*minsize-1) & (LEN(x,1)> 2*minsize-1)& (LEN(x,2)> 2*minsize-1) THEN
				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings, emphasis ); (*here reduction of Boundary checking might impact speed*)

				xsmall:=Reduce( x );
				bsmall:=Reduce( b );
				IF child = NIL THEN NEW( child); child.iterationScale:=iterationScale; child.childLevel:=childLevel+1 END;
				child.SolveMultigrid( bsmall, xsmall, nu, dt, 2* ds, threshold, minsize, iterationScale*iterations,(*??*)iterationScale*smoothings, Boundaries, emphasis );
				x:=Expand( xsmall );

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings, emphasis);  (*here reduction of Boundary checking may impact speed*)
			ELSE
				Solve ( b, x, nu, dt, ds, threshold,iterations, Boundaries, emphasis );
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
		childLevel:=0:INTEGER;
		iterationScale*:=3:INTEGER;(*allows tailoring of iterations in multiresolutions*)
		reduce*,expand*: PROCEDURE( CONST g: Grid ): Grid;  (* pluggable resize operators *)

		PROCEDURE &Init*;
		BEGIN
			expand:=Expand; reduce:=Reduce;
		END Init;
 		(*explicit solving-forward time, centered space; not yet tested*)
		PROCEDURE SolveExplicit*( CONST phim1,phi0 : Grid; VAR x: Grid;  c, dt, ds: Datatype; Boundaries: Boundary; emphasis:=NIL:Emphasis); (* explicit solution Forward time, centered space-not unconditionally stable*)
		BEGIN
		(* Laplacian(A)=second derivative of x is computed directly (forward/explicit scheme), (solution not unconditionally stable).
		The data are kept in original 3D shape, in contrast to the linearization typically used for matrix algebra*)
			Stencil(phi0,temp);
			tempse:=6.0*phi0;
			temp:=temp-tempse;
			x:=2*phi0;
			x:=x-phim1;
			x:=x+ (dt*dt*c*c/ds/ds)* temp;
			IF Boundaries # NIL THEN Boundaries( x ) END;
			(*!emphasis not yet implemented here*)
		END SolveExplicit;

		(*implicit Euler solving BTCS*)
		PROCEDURE Solve*( CONST phim1,phi0 : Grid;  VAR x: Grid;  c, dt, ds, threshold: Datatype;  iterations: SIGNED32;  Boundaries: Boundary; emphasis:=NIL:Emphasis );
		BEGIN
			(* Laplacian(A)=second derivative of x is usually modeled as A*x with A containing the coefficients for discrete approximation of the laplacian,
		but here, the Laplacian computed by digital filtering takes its place; if done in the real domain, the approximation is equivalent to MatMul; if done in the
		spline domain, the laplacian can be computed exactly.
		The data are kept in original 2D shape, in contrast to the linearization typically used for matrix algebra*)
			alpha:=ds * ds / (c*c*dt*dt);  beta:=6+alpha;
			temps:=2*phi0;
			temps:=temps-phim1;
			JacobiSteps( temps, x, temp, alpha, beta, Boundaries, iterations, emphasis );
		END Solve;

			(*implicit Euler solving BTCS*)
		PROCEDURE SolveMultigrid*( CONST phim1,phi0:Grid;  VAR x: Grid;  c, dt, ds, threshold: Datatype;  minsize, iterations, smoothings: SIGNED32;  Boundaries: Boundary; emphasis:=NIL:Emphasis );
		BEGIN
			alpha:=ds * ds  / (c*c*dt*dt);  beta:=6+alpha;
			IF (emphasis#NIL)&(emphasis.maxLayer<childLevel) THEN emphasis:=NIL END;
			IF (LEN( x, 0 ) > 2*minsize-1) & (LEN(x,1)> 2*minsize-1)& (LEN(x,2)> 2*minsize-1) THEN
				tempsm:=2*phi0;
				b:=tempsm-phim1;
				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings, emphasis ); (*here reduction of Boundary checking may impact speed*)

				xsmall:=Reduce( x );
				IF child = NIL THEN NEW( child); child.iterationScale:=iterationScale; child.childLevel:=childLevel+1 END;
				child.SolveMultigrid( Reduce(phim1), Reduce(phi0), xsmall, c, dt, 2* ds, threshold, minsize, iterationScale*iterations,iterationScale*smoothings, Boundaries, emphasis );
				x:=Expand( xsmall );

				JacobiSteps( b, x, temp, alpha, beta, Boundaries, smoothings, emphasis);  (*here reduction of Boundary checking may impact speed*)
			ELSE
				Solve ( phim1, phi0, x, c, dt, ds, threshold,iterations, Boundaries, emphasis );
			END;
		END SolveMultigrid;

	END Wave;

	(*advection operator. for  backward time (implicit Euler) approach, use Advect() below. 	*)
	TYPE Advection*= OBJECT
		VAR U, G, G1, R: Nabla.VectorField;
			g, div, tmp: Grid;

			(*incompressible, scalar, simplistic, for u= velocity field, A=scalar conserved quantity*)
			(* dA/dt =-Div( A u), in the case that Nabla(u)=0 and the flow is thus solenoidal , the equation is equivalent
			     dA/dt=-u dot Grad(A); *)
			PROCEDURE Solenoidal*(CONST u,v,w:Grid; CONST A: Grid): Grid; (* returns dA/dt *) (* if applied in an explicit manner, this may converge first, but then may lead to instability/explosion *)
			BEGIN
				IF (LEN(U,0) # 3) OR (LEN(U,1) # LEN(u,0)) OR (LEN(U,2) # LEN(u,1)) OR (LEN(U,3) # LEN(u,2)) THEN (*LEN(U) # [3,LEN(u,0), LEN(u,1), LEN(u,2)]*)
					NEW(U, 3, LEN(u,0), LEN(u,1), LEN(u,2))
				END; (*to do: avoid allocation*)
				U[0]:=u; U[1]:=v; U[2]:=w;
				RESULT:=Nabla.DirectionalDerivative(A, U, Nabla.centered);
				RETURN -RESULT
			END Solenoidal;


			(* skew symmetric form for the advection operator, see https://en.wikipedia.org/wiki/Advection#Treatment_of_the_advection_operator_in_the_incompressible_Navier_Stokes_equations*)
			PROCEDURE SkewSymmetric*(CONST u,v,w:Grid; VAR u1,v1,w1:Grid); (*returns operator, to be operated on entity*)
			(*VAR  g, div: Grid;*)
			BEGIN
				IF (LEN(U,0) # 3) OR (LEN(U,1) # LEN(u,0)) OR (LEN(U,2) # LEN(u,1)) OR (LEN(U,3) # LEN(u,2)) THEN (*LEN(U) # [3,LEN(u,0), LEN(u,1), LEN(u,2)]*)
					NEW(U, 3, LEN(u,0), LEN(u,1), LEN(u,2))
				END;
				IF (DIM(g)#DIM(u)) OR (LEN(g)#LEN(u)) THEN NEW(g, LEN(u)) END;
				U[0]:=u; U[1]:=v; U[2]:=w;
				(*g:= u.*u; g:=g+v.*v; g:=g+w.*w; g:=0.5*g;*)
				g:= u.*u; 
				tmp:=v.*v; g:=g+tmp; 
				tmp:=w.*w; g:=g+tmp; 
				g:=0.5*g;
				
				G:=Nabla.Grad(g, Nabla.centered);
				R:=Nabla.Rot(U, Nabla.centered);
				G1:=Cross(R, U);
				G:=G+G1;

				IF ~Util.SameSize(div,u) THEN NEW(div, LEN(u)) END;
				div:=Nabla.Div(U, Nabla.centered);
				G1[0]:=u .* div;
				G1[1]:=v .* div;
				G1[2]:=w .* div;
				
				(*G1:=0.5 * G1; G:=G+G1;*)
				G:=INCMUL(0.5,G1);
				u1:=G[0]; (*! to do: write to u1,v1,w1 directly instead of copying*)
				v1:=G[1];
				w1:=G[2];
				
			END SkewSymmetric;
			
			(*TBD: consider Crank–Nicolson method*)  
		END Advection;

TYPE
	NablaScaleIncActive*= OBJECT (ComputeObjects.ComputeObject) (* for operations of type "Matrix := Op(Matrix,Scalar)" ; *)
		VAR A: Grid;
		B: Grid; 
		tmp:Grid;
		s: Datatype;
		op: PROCEDURE(CONST g:Grid; mode: INTEGER):Grid;
		PROCEDURE &Init*(VAR A : Grid; CONST B:Grid; VAR tmp:Grid; s: Datatype; nabla: PROCEDURE(CONST g:Grid; mode: INTEGER):Grid);
		BEGIN
			SELF.A:=ALIAS OF A; 
			SELF.B:=ALIAS OF B;
			SELF.tmp:=ALIAS OF tmp;
			SELF.s:=s;
			op:=nabla;
			SELF.Notify:=NIL;
			wait:=FALSE; (*debug*)
			SELF.priority:=Objects.Normal; 
		END Init;
		PROCEDURE compute;	
		BEGIN
			tmp:=op(B,Nabla.centered);
			A:=INCMUL(s,tmp);
			(*A:=A+op(B,Nabla.centered);*)
		END compute;
	END NablaScaleIncActive;

	DiffusionActive*= OBJECT (ComputeObjects.ComputeObject) (* for operations of type "Matrix := Op(Matrix,Scalar)" ; *)
		VAR u, u1: Grid;
			nu,dt,ds,threshold: Datatype;
			minsize, diffusioniterations,smoothingiterations: INTEGER;
			diffusion:Diffusion;
			bounds:Boundary; 
			emphasis:Emphasis;
		PROCEDURE &Init*(diffusion: Diffusion; CONST u: Grid; VAR u1:Grid; nu,dt,ds,threshold: Datatype; minsize, diffusioniterations, smoothingiterations: INTEGER; bounds:Boundary; emphasis:=NIL:Emphasis);
		BEGIN
			SELF.u:=ALIAS OF u; 
			SELF.u1:=ALIAS OF u1;
			SELF.diffusion:=diffusion;
			SELF.nu:=nu; SELF.dt:=dt; SELF.ds:=ds; SELF.threshold:=threshold;
			SELF.minsize:=minsize; SELF.diffusioniterations:=diffusioniterations; SELF.smoothingiterations:=smoothingiterations;
			SELF.bounds:=bounds;
			SELF.emphasis:=emphasis;
			SELF.Notify:=NIL;
			wait:=FALSE; (*debug*)
			SELF.priority:=Objects.Normal; 
		END Init;
		PROCEDURE compute;	
		BEGIN
			diffusion.SolveMultigrid(u, u1, nu, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations, bounds, emphasis ); 
		END compute;
	END DiffusionActive;
	
	AdvectionActive*= OBJECT (ComputeObjects.ComputeObject) 
		VAR a, a1, u, w, v: Grid;
			mask:VolumeBooleanMap;
			dt,ds,threshold: Datatype;
			mode:BOOLEAN;
			fromZ,toZ:SIZE;
		PROCEDURE &Init*( CONST a, u, v, w: Grid; VAR a1:Grid; dt, ds: Datatype; mode:BOOLEAN; CONST mask:VolumeBooleanMap; fromZ:=0, toZ:=-1:SIZE);
		BEGIN
			SELF.a:=ALIAS OF a; 
			SELF.a1:=ALIAS OF a1;
			SELF.u:=ALIAS OF u; SELF.v:=ALIAS OF v; SELF.w:=ALIAS OF w; 
			SELF.mask:=ALIAS OF mask;
			SELF.dt:=dt; SELF.ds:=ds;
			SELF.mode:=mode;
			SELF.Notify:=NIL;
			wait:=FALSE; (*debug*)
			SELF.priority:=Objects.Normal; 
			SELF.fromZ:=fromZ; SELF.toZ:=toZ;
		END Init;
		PROCEDURE compute;	
		BEGIN
			Advect( a,  u, v, w, a1, dt, ds, mode, mask, fromZ,toZ );
		END compute;
	END AdvectionActive;


	PROCEDURE Cross(CONST a,b: Nabla.VectorField): Nabla.VectorField;
	BEGIN
		IF LEN(RESULT)#LEN(a) THEN NEW(RESULT, LEN(a)) END;
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
	
		
	PROCEDURE Sum3AXAXLoop( ladr, radr, dadr: ADDRESS; linc, rinc, dinc, len: SIZE );
	VAR lval, rval,dval: FLOAT64;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval ); SYSTEM.GET(dadr,dval);  SYSTEM.PUT( dadr,dval+lval+rval);
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END Sum3AXAXLoop;

	PROCEDURE SumInc(CONST left, right: ARRAY [?] OF FLOAT64): ARRAY {UNSAFE} [?] OF FLOAT64;
	BEGIN
		FoxArrayBase.ApplyBinaryAAAOp( RESULT, left, right,
										SIZEOF( FLOAT64 ), Sum3AXAXLoop );
		RETURN RESULT
	END  SumInc;

  	PROCEDURE AllocateSame( VAR x: Grid; CONST templ: Grid ); (*allocation to size of template, with reuse if possible*)
 	BEGIN
	 	IF (LEN( x, 0 ) # LEN( templ, 0 )) OR (LEN( x, 1 ) # LEN( templ, 1 )) OR (LEN( x, 2 ) # LEN( templ, 2 ))  THEN
		 	NEW( x, LEN( templ, 0 ), LEN( templ, 1 ), LEN( templ, 2));
	 	(*ELSE 
	 		x:=0;*)
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

	PROCEDURE Stencil0( CONST x: Grid;  VAR x1: Grid); (*3D stencil for finite difference*) (* not in-place *)
	(* Performance by stride-wise memory accesses. An alternative could be the use of 3D filtering for "the Jacobi smoother". This stencil cost ~8% of overal runtime in a 256*128*138 navier stokes problem *)
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
	END Stencil0;

	PROCEDURE Stencil( CONST x: Grid;  VAR x1: Grid); (*3D stencil for finite difference*) (* not in-place *)
	(* Performance by stride-wise memory accesses. An alternative could be the use of 3D filtering for "the Jacobi smoother". This stencil cost ?% of overal runtime in a 256*128*138 navier stokes problem *)
	VAR lenx, leny, lenz: SIZE;
	BEGIN
		AllocateSame(x1,x);(*with reuse if possible*)
		lenx:=LEN( x, 2 );  leny:=LEN( x, 1 ); lenz:= LEN(x,0);
		(*3D stencil*)
		x1[..,..,1..lenx-2]:=x[..,..,2..]+x[..,..,..lenx-3]; x1[..,..,0]:=x[..,..,0]+x[..,..,1];	x1[..,..,lenx-1]:=x[..,..,lenx-1]+x[..,..,lenx-2];(*!TBD: not yet accurate at edges*)
		x1[..,1..leny-2,..]:=SumInc(x[..,2..,..],x[..,..leny-3,..]); x1[..,0,..]:=SumInc(x[..,0,..],x[..,1,..]); x1[..,leny-1,..]:=SumInc(x[..,leny-1,..],x[..,leny-2,..]);
		x1[1..lenz-2,..,..]:=SumInc(x[2..,..,..],x[..lenz-3,..,..]); x1[0,..,..]:=SumInc(x[0,..,..],x[1,..,..]); x1[lenz-1,..,..]:=SumInc(x[lenz-1,..,..],x[lenz-2,..,..]);	
	END Stencil;

	PROCEDURE StencilC( CONST x: Grid;  VAR x1: Grid); (*3D stencil for finite difference*) (* not in-place *)
	(* Performance by stride-wise memory accesses. An alternative could be the use of 3D filtering for "the Jacobi smoother". This stencil cost ?% of overal runtime in a 256*128*138 navier stokes problem *)
	VAR lenx, leny, lenz, z,y: SIZE;
	BEGIN
		AllocateSame(x1,x);(*with reuse if possible*)
		lenx:=LEN( x, 2 );  leny:=LEN( x, 1 ); lenz:= LEN(x,0);
		(*3D stencil*)
		FOR z:=1 TO LEN(x,0)-2 DO
			FOR y:=1 TO LEN(x,1)-2 DO
				x1[z,y,1..LEN(x,2)-2]:= SumInc(x[z,y,0..LEN(x,2)-3],x[z,y,2..LEN(x,2)-1]);
				x1[z,y,1..LEN(x,2)-2]:= SumInc(x[z,y-1,1..LEN(x,2)-2],x[z,y+1,1..LEN(x,2)-2]);
				x1[z,y,1..LEN(x,2)-2]:= SumInc(x[z-1,y,1..LEN(x,2)-2],x[z+1,y,1..LEN(x,2)-2]);
			END;
		END;
	END StencilC;


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
	apply the jacobi step with a 3D stencil to the whole data grid in its original 3D format, which would correspond to the diagonal in the Jacobi Matrix formulation, at once, using a stencil like approach;
	i.e., we do not need to convert the data explicitely into a sparse matrix for doing a smooting=Jacobi step *)
	(*see also description in cited gpugems paper *)
	VAR invbeta: Datatype;
	BEGIN
		invbeta:=1 / beta;
		Stencil(x,x1);
		(*Stencil333(x,x1);*)(*slow, but not allocating large temp memory*)
		IF LEN(b,0)#0 THEN (* b is 0 in case of Laplace equation*)
			x1:=INCMUL(alpha,b); 
		END;
		x:=invbeta * x1;
	END JacobiStep;

	PROCEDURE JacobiSteps( CONST b: Grid;  VAR x, x1: Grid;  alpha, beta: Datatype;  Boundaries: Boundary; iterations:SIGNED32; emphasis:=NIL:Emphasis);
		VAR i:SIGNED32; e:Emphasis; rangeX,rangeY,rangeZ:RANGE;
		
		PROCEDURE Emphasize;(*Jacobi steps on sub-region*)
		BEGIN
			e:=emphasis; 
			WHILE e#NIL DO
				rangeX:=ENTIER(e.region.x0*LEN(x,2))..ENTIER(e.region.x1*LEN(x,2)-1);
				rangeY:=ENTIER(e.region.y0*LEN(x,1))..ENTIER(e.region.y1*LEN(x,1)-1);
				rangeZ:=ENTIER(e.region.z0*LEN(x,0))..ENTIER(e.region.z1*LEN(x,0)-1);
				FOR i:=0 TO ENTIER(e.enhancement) DO
					JacobiStep(b[rangeZ,rangeY,rangeX],x[rangeZ,rangeY,rangeX],x1[rangeZ,rangeY,rangeX],alpha,beta);
					IF Boundaries # NIL THEN Boundaries( x, emphasis.region ) END;
				END;
				e:=e.next;
			END;
		END Emphasize;
		
	BEGIN
		WHILE iterations>0 DO
			IF Boundaries # NIL THEN Boundaries( x ) END;
			JacobiStep(b,x,x1,alpha,beta);
			Emphasize;(*emphasis regions can receive additional iterations*)
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


	(*line buffer alias to reduce indexing work => no apparent performance advantage on  Prestige notebook compared to below*)
(*	PROCEDURE Advect*( CONST source,  u, v, w: Grid;  VAR target: Grid;  dt, ds: Datatype; bilinear: BOOLEAN );   (* to do: other interpolation methods *)
	(*for each gridpoint in target grid, find value in source grid based on retrograd application of map u,v,w ;  u and ds are in SI units*)
	(* to do: speed up by doing it linewise or slicewise *)
	VAR x, y, z,  ox, oy, oz: SIZE;  a, b, c: Datatype;  len,lenu,lenv,lenw:ARRAY [3] OF SIZE; tmp222: ARRAY [2,2,2] OF Datatype;
		lineU,lineV,lineW,(*lineS,*)lineT:ARRAY [*] OF Datatype;
	BEGIN
		len:=LEN(source);lenu:=LEN(u); lenv:=LEN(v); lenw:=LEN(w);
		IF  LEN(target)# LEN(source) THEN NEW(target,LEN(source)) END;
		FOR z:=0 TO len[0]-1 DO
			FOR y:=0 TO len[1]-1 DO
				lineU:=u[z, y, ..];
				lineV:=v[z, y, ..];
				lineW:=w[z, y, ..];
				lineT:=target[z, y, ..];
				(*lineS:=ALIAS OF source[z, y, ..];*)
				FOR x:=0 TO len[2]-1 DO
					IF lenu = 0 THEN ox:=x ELSE
						IF bilinear THEN
							a:=x-dt/ds * lineU[x];  ox:=ENTIER( a );  a:=1-a+ox;
						ELSE (*nearest neighbour*)
							ox:=ENTIER( x-dt/ds * lineU[x]+0.5 );
						END;
						IF ox < 0 THEN ox:=0; a:=0; (* apply boundary *)
						ELSIF ox > len[2]-2 THEN ox:=len[2]-2; a:=0; (* apply boundary *)
						END;
					END;
					IF lenv = 0 THEN oy:=y ELSE
						IF bilinear THEN
							b:=y-dt/ds * lineV[x];  oy:=ENTIER( b );  b:=1-b+oy;
						ELSE (*nearest neighbour*)
							oy:=ENTIER( y-dt/ds * lineV[x]+0.5 );
						END;
						IF oy < 0 THEN oy:=0; b:=0; (* apply boundary *)
						ELSIF oy > len[1]-2 THEN oy:=len[1]-2; b:=0; (* apply boundary *)
						END;
					END;
					IF lenw = 0 THEN oz:=z ELSE
						IF bilinear THEN
							c:=z-dt/ds * lineW[x];  oz:=ENTIER( c );  c:=1-c+oz;
						ELSE (*nearest neighbour*)
							oz:=ENTIER( z-dt/ds * lineW[x]+0.5 );
						END;
						IF oz < 0 THEN oz:=0; c:=0; (* apply boundary *)
						ELSIF oz > len[0]-2 THEN oz:=len[0]-2; c:=0; (* apply boundary *)
						END;
					END;
					IF bilinear THEN
						tmp222:=Cast2x2x2(a*b*c, (1-a) * b * c,
										  a * (1-b) * c , (1-a) * (1-b) * c,
										a * b * (1-c), (1-a) * b * (1 -c),
										  a * (1-b) * (1-c), (1-a)*(1-b)*(1-c));
						lineT[x]:=tmp222 +* source[oz..oz+1,oy..oy+1,ox..ox+1];
					ELSE lineT[x]:=source[oz, oy, ox];
					END;
				END;
				target[z, y, ..]:=lineT;
			END;
		END;
	END Advect;
*)


PROCEDURE Advect*( CONST source,  u, v, w: Grid;  VAR target: Grid;  dt, ds: Datatype; bilinear: BOOLEAN; CONST mask:VolumeBooleanMap; fromZ:=0,toZ:=-1:SIZE ); (* allows splitting advection among several processes . splitToZ<splitFromZ implies no splitting*)  (* to do: other interpolation methods *)
	(*for each gridpoint in target grid, find value in source grid based on retrograd application of map u,v,w ;  u and ds are in SI units*)
	(* to do: speed up by doing it linewise or slicewise; but version above does not offer improved speed *)
	VAR x, y, z,  ox, oy, oz: SIZE;  a, b, c: Datatype;  len,lenu,lenv,lenw,lenm:ARRAY [3] OF SIZE; tmp222: ARRAY [2,2,2] OF Datatype;
		lenu0,lenv0,lenw0,lenm0:BOOLEAN;
	BEGIN
		len:=LEN(source);lenu:=LEN(u); lenv:=LEN(v); lenw:=LEN(w);lenm:=LEN(mask);
		lenu0:=lenu=0; lenv0:=lenv=0; lenw0:=lenw=0; lenm0:=lenm=0;
		IF fromZ>toZ THEN 
			fromZ:=0; toZ:=len[0]-1;
			IF  LEN(target)# LEN(source) THEN NEW(target,LEN(source)) END;
		ELSE (* no re-allocation of subarrays*)
		END;
		FOR z:=fromZ TO toZ DO
			FOR y:=0 TO len[1]-1 DO
				FOR x:=0 TO len[2]-1 DO
					IF lenm0 OR mask[z,y,x] THEN
						IF lenu0 (*lenu = 0*) THEN ox:=x ELSE
							IF bilinear THEN
								a:=x-dt/ds * u[z, y, x];  ox:=ENTIER( a );  a:=1-a+ox;
							ELSE (*nearest neighbour*)
								ox:=ENTIER( x-dt/ds * u[z, y, x]+0.5 );
							END;
							IF ox < 0 THEN ox:=0; a:=0; (* apply boundary *)
							ELSIF ox > len[2]-2 THEN ox:=len[2]-2; a:=1.0; (*a:=0;*) (* apply boundary *)
							END;
						END;
						IF lenv0 (*lenv = 0*) THEN oy:=y ELSE
							IF bilinear THEN
								b:=y-dt/ds * v[z, y, x];  oy:=ENTIER( b );  b:=1-b+oy;
							ELSE (*nearest neighbour*)
								oy:=ENTIER( y-dt/ds * v[z, y, x]+0.5 );
							END;
							IF oy < 0 THEN oy:=0; b:=0; (* apply boundary *)
							ELSIF oy > len[1]-2 THEN oy:=len[1]-2; b:=1.0; (*b:=0;*) (* apply boundary *)
							END;
						END;
						IF lenw0 (*lenw = 0*) THEN oz:=z ELSE
							IF bilinear THEN
								c:=z-dt/ds * w[z, y, x];  oz:=ENTIER( c );  c:=1-c+oz;
							ELSE (*nearest neighbour*)
								oz:=ENTIER( z-dt/ds * w[z, y, x]+0.5 );
							END;
							IF oz < 0 THEN oz:=0; c:=0; (* apply boundary *)
							ELSIF oz > len[0]-2 THEN oz:=len[0]-2; c:=1.0; (*c:=0;*) (* apply boundary *)
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
		END;
	END Advect;



(*PROCEDURE Advect*( CONST source,  u, v, w: Grid;  VAR target: Grid;  dt, ds: Datatype; bilinear: BOOLEAN; fromZ:=0,toZ:=-1:SIZE ); (* allows splitting advection among several processes . splitToZ<splitFromZ implies no splitting*)  (* to do: other interpolation methods *)
	(*for each gridpoint in target grid, find value in source grid based on retrograd application of map u,v,w ;  u and ds are in SI units*)
	(* to do: speed up by doing it linewise or slicewise; but version above does not offer improved speed *)
	VAR x, y, z,  ox, oy, oz: SIZE;   
		a, b, c: Datatype;  len,lenu,lenv,lenw:ARRAY [3] OF SIZE; tmp222: ARRAY [2,2,2] OF Datatype;
		lenu0,lenv0,lenw0:BOOLEAN;
	BEGIN
		len:=LEN(source);lenu:=LEN(u); lenv:=LEN(v); lenw:=LEN(w);
		lenu0:=lenu=0; lenv0:=lenv=0; lenw0:=lenw=0;
		IF fromZ>toZ THEN 
			fromZ:=0; toZ:=len[0]-1;
			IF ~Util.SameSize(target,source) THEN NEW(target,len) END;
		ELSE (* no re-allocation of subarrays*)
		END;
		IF bilinear THEN
			(*!TBD: on/off boundary. may not be absolutely necessary*)
			FOR z:=fromZ TO toZ DO
				FOR y:=0 TO len[1]-1 DO
					FOR x:=0 TO len[2]-1 DO
						IF ~lenu0 THEN a:=x-dt/ds * u[z, y, x]; ox:=MIN(len[2]-2,MAX(0,ENTIER( a ))); a:=1-a+ox; 
						ELSE ox:=x 
						END;
						IF ~lenv0 THEN b:=y-dt/ds * v[z, y, x]; oy:=MIN(len[1]-2,MAX(0,ENTIER( b ))); b:=1-b+oy; 
						ELSE oy:=y
						END;
						IF ~lenw0 THEN c:=z-dt/ds * w[z, y, x]; oz:=MIN(len[0]-2,MAX(0,ENTIER( c ))); c:=1-c+oz; 
						ELSE oz:=z
						END;
						tmp222:=Cast2x2x2(a*b*c, (1-a) * b * c,
										  a * (1-b) * c , (1-a) * (1-b) * c,
										a * b * (1-c), (1-a) * b * (1 -c),
										  a * (1-b) * (1-c), (1-a)*(1-b)*(1-c));
						target[z, y, x]:=tmp222 +* source[oz..oz+1,oy..oy+1,ox..ox+1];
					END;
				END;
			END;
			
			(*not on boundary*)
			(*FOR z:=fromZ TO toZ DO
				FOR y:=1 TO len[1]-2 DO
					FOR x:=1 TO len[2]-2 DO (*assume advection distance > boundary layer thickness*)
						IF lenu = 0 THEN ox:=x ELSE
							a:=x-dt/ds * u[z, y, x];  ox:=ENTIER( a );  a:=1-a+ox;
							(*IF ox < 0 THEN ox:=0; a:=0; (* apply boundary *)
							ELSIF ox > len[2]-2 THEN ox:=len[2]-2; a:=0; (* apply boundary *)
							END;*)
						END;
						IF lenv = 0 THEN oy:=y ELSE
							b:=y-dt/ds * v[z, y, x];  oy:=ENTIER( b );  b:=1-b+oy;
							(*IF oy < 0 THEN oy:=0; b:=0; (* apply boundary *)
							ELSIF oy > len[1]-2 THEN oy:=len[1]-2; b:=0; (* apply boundary *)
							END;*)
						END;
						IF lenw = 0 THEN oz:=z ELSE
							c:=z-dt/ds * w[z, y, x];  oz:=ENTIER( c );  c:=1-c+oz;
							(*IF oz < 0 THEN oz:=0; c:=0; (* apply boundary *)
							ELSIF oz > len[0]-2 THEN oz:=len[0]-2; c:=0; (* apply boundary *)
							END;*)
						END;
						tmp222:=Cast2x2x2(a*b*c, (1-a) * b * c,
										  a * (1-b) * c , (1-a) * (1-b) * c,
										a * b * (1-c), (1-a) * b * (1 -c),
										  a * (1-b) * (1-c), (1-a)*(1-b)*(1-c));
						target[z, y, x]:=tmp222 +* source[oz..oz+1,oy..oy+1,ox..ox+1];
					END;
				END;
			END;*)
		ELSE
			FOR z:=fromZ TO toZ DO
				FOR y:=0 TO len[1]-1 DO
					FOR x:=0 TO len[2]-1 DO
						IF lenu = 0 THEN ox:=x ELSE
							 (*nearest neighbour*)
							ox:=ENTIER( x-dt/ds * u[z, y, x]+0.5 );
							IF ox < 0 THEN ox:=0; a:=0; (* apply boundary *)
							ELSIF ox > len[2]-2 THEN ox:=len[2]-2; a:=0; (* apply boundary *)
							END;
						END;
						IF lenv = 0 THEN oy:=y ELSE
							oy:=ENTIER( y-dt/ds * v[z, y, x]+0.5 );
							IF oy < 0 THEN oy:=0; b:=0; (* apply boundary *)
							ELSIF oy > len[1]-2 THEN oy:=len[1]-2; b:=0; (* apply boundary *)
							END;
						END;
						IF lenw = 0 THEN oz:=z ELSE
							oz:=ENTIER( z-dt/ds * w[z, y, x]+0.5 );
							IF oz < 0 THEN oz:=0; c:=0; (* apply boundary *)
							ELSIF oz > len[0]-2 THEN oz:=len[0]-2; c:=0; (* apply boundary *)
							END;
						END;
						target[z, y, x]:=source[oz, oy, ox];
					END;
				END;
			END;
		END;
	END Advect;*)

VAR FullRange:RANGE;

PROCEDURE Test*;
VAR A,C,B,D: Grid; s:Datatype;
	map,map0:VolumeBooleanMap;
BEGIN
	NEW(A,12,12,12); A:=5;
	NEW(C,12,12,12);
	NEW(B,(LEN(A,0)+1) DIV 2, (LEN(A,1)+1) DIV 2, (LEN(A,2)+1) DIV 2);
	B:=Reduce(A);
	C:=Expand(B);
	s:=SUM(A-C);
	map:=ALIAS OF map0; (*alias of nil map*)
	HALT(101);
END Test;

END VolumePDE.

VolumePDE.Test

System.FreeDownTo VolumePDE ~

Use: See TestVolumePDE.Mod

(*reading for future inspiration and improvement:

	Neural network improvement of multigrid solvers: https://www.sciencedirect.com/science/article/pii/S0021999122000456
	
	Ocellaris solvers, including free surface computations. https://www.ocellaris.org/index.html
	
	with meshing: https://perso.uclouvain.be/paul.vandooren/publications/MelchiorLVW09.pdf

    Benedikt Klein, Florian Kummer, Markus Keil, and Martin Oberlack. An extension of the SIMPLE based discontinuous galerkin solver to unsteady incompressible flows. International Journal for Numerical Methods in Fluids, 77(10):571–589, 2015. doi:10.1002/fld.3994.

    Tormod Landet and Mikael Mortensen. On exactly incompressible DG FEM pressure splitting schemes for the Navier-Stokes equation. arXiv physics.comp-ph, 2019. arXiv:1903.11943.
*)
