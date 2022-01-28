MODULE VolumeNavierStokes;  (** AUTHOR "Patrick Hunziker 2009-2020" ; PURPOSE "Navier Stokes  Fluid dynamis in 3D";*)

(**  
	Implements computational fluid dynamics for 3D, assuming homogenous, noncompressible (Newtonian) Fluids.
	rho= density
	nu = kinematic viscosity ( defined as:  kinematic viscosity nu =  viscosity/density = mu/rho )
	
	Chorin projection/operator splitting (wikipedia: projection method(fluid dynamics) is used. 
	
	Solving strategy: BTCS - 'backward time- centered space' interpolation to achieve numerical stability.
**)

(*for fluid dynamics constants and helper functions, see ComputationalFluids.Mod *)

(*
Physics:	
Incompressible flow of Newtonian fluids:

rho (dv/dt + v*Grad(v)) = - Grad(p) + mu * Grad(Grad(v)) + f 
i.e.
inertia = -pressure gradient + viscosity + other forces

if temperature effects are neglected, the only other equation needed is the continuity equation; 
	drho/dt + G* (rho*v) = 0
if assuming incompressibility, this simplifies to  
	Grad(v)=0
*)
(*inspiration for 2D Implementation: see "gpugems_chap38.pdf"
at "http://leri.univ-reims.fr/~nocent/doc/gpugems_chap38.pdf" or in the "Algorithms" Folder
*)

(* the implementation is special and GPU like, in that the data remain in their original spatial grid format throughout the whole computation; 
the implied sparse matrices for matrix solving are not constructed. This allows us to compute efficiently using arrays *)

(*limitations:
	currently, the individual PDEs embedded in Navier Stokes are evaluated using individual multiresolution.
	this has limitations, e.g. when applying the noncompressibility condition to the velocity field.
	it might be better, however, to look at the overall problem in an integrated multigrid fashion.

 next steps: 
	- Compressible Navier Stokes: see https://en.wikipedia.org/wiki/Derivation_of_the_Navier%E2%80%93Stokes_equations#Compressible_Newtonian_fluid
	- Particle-resolved Navier Stokes: http://www.annualreviews.org/doi/abs/10.1146/annurev-fluid-010313-141344
	- Monte Carlo Navier Stokes
	
compare thesis compressible Navier Stokes: https://www.wpi.edu/Pubs/ETD/Available/etd-0424102-132343/unrestricted/nanson.pdf
*)

IMPORT Nabla:=VolumeNabla, PDE:=VolumePDE, Objects, ComputeObjects:=MatrixComputeObjects, KernelLog, Util:=MatrixUtilities, LinearFilters, VolumeTransform;

CONST 
	BILINEAR = TRUE;  
	UseAliasInInit=TRUE;
	GravityConstant=9.81;
	
TYPE 
	Datatype* = PDE.Datatype;    
	Grid* = PDE.Grid;  
	BGrid*=PDE.VolumeBooleanMap;
	Boundary* = PDE.Boundary; 

(*	
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
			(*	tmp:=s*tmp;	
			A:=A+tmp;*)
			A:=INCMUL(s,tmp);
			(*A:=A+op(B,Nabla.centered);*)
		END compute;
	END NablaScaleIncActive;

	DiffusionActive*= OBJECT (ComputeObjects.ComputeObject) (* for operations of type "Matrix := Op(Matrix,Scalar)" ; *)
		VAR u, u1: Grid;
			nu,dt,ds,threshold: Datatype;
			minsize, diffusioniterations,smoothingiterations: INTEGER;
			diffusion:PDE.Diffusion;
			bounds:Boundary; 
		PROCEDURE &Init*(diffusion: PDE.Diffusion; CONST u: Grid; VAR u1:Grid; nu,dt,ds,threshold: Datatype; minsize, diffusioniterations, smoothingiterations: INTEGER; bounds:Boundary);
		BEGIN
			SELF.u:=ALIAS OF u; 
			SELF.u1:=ALIAS OF u1;
			SELF.diffusion:=diffusion;
			SELF.nu:=nu; SELF.dt:=dt; SELF.ds:=ds; SELF.threshold:=threshold;
			SELF.minsize:=minsize; SELF.diffusioniterations:=diffusioniterations; SELF.smoothingiterations:=smoothingiterations;
			SELF.bounds:=bounds;
			SELF.Notify:=NIL;
			wait:=FALSE; (*debug*)
			SELF.priority:=Objects.Normal; 
		END Init;
		PROCEDURE compute;	
		BEGIN
			diffusion.SolveMultigrid(u, u1, nu, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations, bounds ); 
		END compute;
	END DiffusionActive;
	
	AdvectionActive*= OBJECT (ComputeObjects.ComputeObject) 
		VAR a, a1, u, w, v: Grid;
			dt,ds,threshold: Datatype;
			mode:BOOLEAN;
			fromZ,toZ:SIZE;
		PROCEDURE &Init*( CONST a, u, v, w: Grid; VAR a1:Grid; dt, ds: Datatype; mode:BOOLEAN; fromZ:=0, toZ:=-1:SIZE);
		BEGIN
			SELF.a:=ALIAS OF a; 
			SELF.a1:=ALIAS OF a1;
			SELF.u:=ALIAS OF u; SELF.v:=ALIAS OF v; SELF.w:=ALIAS OF w; 
			SELF.dt:=dt; SELF.ds:=ds;
			SELF.mode:=mode;
			SELF.Notify:=NIL;
			wait:=FALSE; (*debug*)
			SELF.priority:=Objects.Normal; 
			SELF.fromZ:=fromZ; SELF.toZ:=toZ;
		END Init;
		PROCEDURE compute;	
		BEGIN
			PDE.Advect( a,  u, v, w, a1, dt, ds, mode, fromZ,toZ );
		END compute;
	END AdvectionActive;
*)
TYPE NavierStokes* = OBJECT
	CONST 
		NablaMethod=Nabla.centered;
		(*NablaMethod=Nabla.custom;*)
	VAR
	diffusioniterations*, poissoniterations*,smoothingiterations*:INTEGER;
	u*, v*, w*, p*, heat*, solutes*: Grid;  (* in SI units *)
	nu*, rho*,  ds*, threshold*, stabilityCriterion-: Datatype;  (* in SI units: mu[Pa*s = kg/m/s ],nu[m2/s],rho[kg/m3],ds[m],dt[s], force[ ],velocities[m/s] , pressure[kg/ms2]*)
	len: ARRAY [*] OF SIZE;
	splitZ:SIZE;
	
	temp0*:=273+25:Datatype;
	heatDiffusionCoeff*:Datatype;
	heatExpansionCoeff*:Datatype; 
	solDiffusionCoeff*:Datatype; 

	minsize*:INTEGER; 
	UseGravity*:=FALSE:BOOLEAN; 
	UseSolutes*:=FALSE: BOOLEAN;
	UseHeat*:=FALSE: BOOLEAN;
	UseBuoyancy*:=FALSE: BOOLEAN;
	UseCompressibility*:=FALSE:BOOLEAN;
	Parallel*:INTEGER;
	FlowBoundX, FlowBoundY, FlowBoundZ, PressureBound, PressureBoundPDT, HeatBounds*, SoluteBounds*: Boundary;
	(* dopplerconstraint*:VolumeDoppler.DopplerConstraint;*)
	u2, u3, v2, v3, w2, w3,  pdt-, div-,div0,tmp-, d, tmpu,tmpv,tmpw, heat0, solutes0, heat00: Grid;  
	advection:PDE.Advection;
	diffusionU,diffusionV, diffusionW, diffusionP, diffusionH, diffusionS: PDE.Diffusion;
	poisson: PDE.Poisson;
	laplace: PDE.Laplace;
	
	nablaScaleInc0, nablaScaleInc1, nablaScaleInc2: PDE.NablaScaleIncActive;
	diffusion0,diffusion1,diffusion2, diffusion3, diffusion4: PDE.DiffusionActive;
	advection0, advection1, advection2, advection3, advection4, advection00,advection11,advection22,advection33: PDE.AdvectionActive;
	
	(** 
	Initialize Navier-Stokes Solver. 
	use SI units throughout:
	u,v are velocities x and y direction
	p is pressure
	nu is kinematic viscosity (equivalent to  viscosity{mu}/density{rho} )
	rho is density
	ds is grid spacing in meters
	XXBoundYY() are procedures that apply boundary conditions to the data grids;
	   typical boundaries are
	   - initial values = u,v,p before simulation step
	   - inlet/outlet boundaries at given fluid entries into the grid
	   - no-slip boundary conditions at the wall (zero velocity in grid element nearest to the wall)
	   - no pressure gradient in direction perpendicular to the wall in grid element nearest to the wall.
	   Note that the boundary conditions are applied in a multigrid fashion, 
	   i.e. the boundary procedures should give consistent results in downsized versions of the data 
	   (e.g., a wall element positioned at 1/3 of the grid size will also be positionened at 1/3 of the downsized grid size)
	*)
	
	PROCEDURE &Init*( VAR u, v, w, p: Grid;  nu, rho, ds: Datatype;  
							FlowBoundX, FlowBoundY, FlowBoundZ, 
							PressureBound, PressureBoundPDT: Boundary; Parallel:=6:INTEGER );  
	BEGIN 
		threshold := 0.05;  (*desired accuracy; not currently used in implementation*)
		minsize:=16; (* minimum grid size for multigrid solver *)
		diffusioniterations := 20;  poissoniterations := 20 ; smoothingiterations := 8(*ws 3*); (*! to do: drive PDEs by precision, not by number of iterations *)
		
		SELF.nu:=nu; 
		SELF.rho:=rho; 
		SELF.ds:=ds;
		
		SELF.u:=ALIAS OF u; u2:=u; (*u3:=u;*)
		SELF.v:=ALIAS OF v; v2:=v; (*v3:=v;*)
		SELF.w:=ALIAS OF w; w2:=w; (*w3:=w;*)
		
		len:=LEN(u);
		
		IF p=0 THEN(*estimate initial pressure field from pressure boundaries*)
			NEW(laplace); laplace.SolveMultigrid(p, 0, 16, poissoniterations, smoothingiterations, PressureBound); 
		END;
		
		SELF.p:=ALIAS OF p;
		NEW(pdt, LEN(u) ); 
		NEW(div, LEN(u) );
		
		SELF.FlowBoundX:=FlowBoundX;
		SELF.FlowBoundY:=FlowBoundY;
		SELF.FlowBoundZ:=FlowBoundZ;
		SELF.PressureBound:=PressureBound;
		SELF.PressureBoundPDT:=PressureBoundPDT;
		SELF.Parallel:=Parallel;
		
		(*some of these are only used in single-threaded, not in parallel usage *)
		NEW(advection);
		NEW(diffusionU); 
		NEW(diffusionV);
		NEW(diffusionW);
		NEW(diffusionP);
		NEW(poisson);
	END Init;
	
	PROCEDURE InitHeat*(CONST heat, heat0:Grid; diffusionCoeff:Datatype; temp0:Datatype; boundary:Boundary);
	BEGIN
		SELF.temp0:=temp0;
		SELF.heat:=ALIAS OF heat;
		SELF.heat0:=ALIAS OF heat0;
		heatDiffusionCoeff:=diffusionCoeff;
		NEW(diffusionH);
		HeatBounds:=boundary;
		UseHeat:=TRUE;
	END InitHeat;

	PROCEDURE InitBuoyancy*();
	BEGIN
		UseBuoyancy:=TRUE;
	END InitBuoyancy;

	PROCEDURE InitCompressibility*(heatExpansionCoeff:Datatype);
	BEGIN
		SELF.heatExpansionCoeff:=heatExpansionCoeff;
		UseCompressibility:=TRUE;
	END InitCompressibility;

	
	PROCEDURE InitSolutes*(CONST sol,sol0:Grid; diffusionCoeff:Datatype; boundary:Boundary);
	BEGIN
		SELF.solutes:=ALIAS OF sol;
		SELF.solutes0:=ALIAS OF sol0;
		SELF.solDiffusionCoeff:=diffusionCoeff;
		NEW(diffusionS);
		SoluteBounds:=boundary;
		UseSolutes:=TRUE;
	END InitSolutes;
	
	
	
	(*  Navier Stokes Pseudocode:
		u = advect(u); 
		u = diffuse(u);  using diffusion equation
		u = addForces(u);
		p = computePressure(u);  using poisson equation (*projection*)
		u = subtractPressureGradient(u, p);
		i.e.	advection - diffusion - force application - projection; Solution operator S(u)= P( F( D( A(u) ) ) )
	*)
	
	(* single-threaded iteration *)
	PROCEDURE Step*( VAR fx, fy, fz: Grid;  dt: Datatype); 	(* performance question: are the constraints needed inside the multiresolution solvers or can they be used with minimal loss outside only ?*)
	 	VAR stepsize, k:Datatype; lenu3: ARRAY[*] OF SIZE;
	BEGIN 
		stabilityCriterion:=dt/ds/ds; (* i.e. the "r" in the stability discussion in https://en.wikipedia.org/wiki/Finite_difference_method*)
			(* for explicit/forward time/centered space scheme: only with  stabilityCriterion <0.5 stable . 
				For implicit/ Backward Time, Centered Space Method "BTCS", always stable*)
		stepsize:=dt/1;
		
		(* approach: decompose solution of the problem into advection - diffusion - force application - projection; Solution operator S(u)= P( F( D( A(u) ) ) )  *)
		(* 1) advection A *) (*units: 'length/time' *)
		
		PDE.Advect( u,  u, v, w, u2, dt, ds, BILINEAR );
		PDE.Advect( v,  u, v, w, v2, dt, ds, BILINEAR );
		PDE.Advect( w, u, v, w, w2, dt, ds, BILINEAR );
		
		(*advection.SkewSymmetric(u,v,w, u2,v2,w2);*)
	
		 (*  this is a better code location (than below) for 3) force application when flow is driven by a pressure field. *)
		 (* in this case, we drive the system by external pressure boundary conditions at inlet and outlet *)
		k :=dt/ds/rho;
		(*u2 := u2- k * Nabla.dx(p, NablaMethod);(* m/s*)
		v2 := v2-k * Nabla.dy(p, NablaMethod);
		w2 := w2-k* Nabla.dz(p, NablaMethod);*)
		
		d:=Nabla.dx(p, NablaMethod);
		u2:= DECMUL(k,d);(* m/s*)
		d:=Nabla.dy(p, NablaMethod);
		v2 := DECMUL(k,d);
		d:=Nabla.dz(p, NablaMethod);
		w2:=DECMUL(k,d);

		lenu3:=LEN(u3);
		IF lenu3#len THEN NEW(u3,len); NEW(v3,len); NEW (w3,len) END;

		(* 2) diffusion D *) (*result units: length/time *)(* could the boundaries above be taken out of the diffusion multigrid above at limited precision  loss ?? *)
		diffusionU.SolveMultigrid(u2, u3, nu, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations, FlowBoundX ); (*use FlowBoundX vs NIL to speedup by factor 3, but worse boundary behaviour*)
		diffusionV.SolveMultigrid(v2, v3, nu, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations, FlowBoundY ); (*use FlowBoundY NIL to speedup by factor 3*)
		diffusionW.SolveMultigrid(w2, w3, nu, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations, FlowBoundZ ); (*use FlowBoundZ NIL to speedup by factor 3*)

		
		(* 3) force application F *)
		(*may be dropped in certain cases, e.g. if system driven by flow boundary conditions, and not by pressure boundary conditions*)
		(*compute solute distribution *)
				
		IF UseHeat THEN (*noncompressible version*)
			IF UseCompressibility THEN heat00:=heat END;
			PDE.Advect(heat, u,v,w, heat0, dt, ds, BILINEAR);
			diffusionH.SolveMultigrid(heat0, heat, heatDiffusionCoeff, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations, HeatBounds ); 
			IF UseBuoyancy THEN
				fy:=heat-temp0; (* ideal gas law: deltaTemp is proportional do deltaVolume, but the latter not implemented, we use constant volume *)
				fy:=GravityConstant * rho * 1/temp0 *fy; (*upwards force || reduction in density || thermal expansion of air, see ideal gas law *)
			END;
		END;

		IF UseGravity THEN v3:=v3-dt*GravityConstant END;(*downward gravity acceleration*) 
		IF LEN(fx,0)>0 THEN u3:=INCMUL(dt,fx)(*u3:=u3+dt*fx*) END;
		IF LEN(fy,0)>0 THEN v3:=INCMUL(dt,fy)(*v3:=v3+dt*fy*) END;(*upward buoyancy*)		(*use G*deltaRho  for force *)
		IF LEN(fz,0)>0 THEN w3:=INCMUL(dt,fz)(*w3:=w3+dt*fz*) END;
		
		(* 4) projection: P *)	
		(*div := divergence( u, v, w, ds );*)
		div := divergence( u3, v3, w3, ds );
		IF UseCompressibility THEN (*idea gas law, isobaric: V~~T*)(*! TBD: Check signs !*)
			heat00:=heat-heat00;
			div := DECMUL( 1/temp0, heat00);(* div:=div + heatExpansionMap *) 
		END;(*! experimental; check ! *)
		poisson.SolveMultigrid( div, pdt, ds, threshold, minsize, poissoniterations, smoothingiterations,PressureBoundPDT); (*pdt: m2/s*)(*units: div = 1/s ; pressure: kg/ms2 oder N/m2*)
		
		(* adjust velocity field to conform to the noncompressibility requirement *) 	
		k := 1/ds;
		u := u3 - k * Nabla.dx(pdt, NablaMethod);
		v := v3 - k * Nabla.dy(pdt, NablaMethod);
		w := w3- k * Nabla.dz(pdt, NablaMethod);

(*		d:=Nabla.dx(pdt, NablaMethod);
		d:=k*d;
		u := u3 - d;
		d:=Nabla.dy(pdt, NablaMethod);
		d:=k*d;
		v := v3 - d;
		d:=Nabla.dz(pdt, NablaMethod);
		d:=k*d;
		w:=w3- d;
*)
		FlowBoundX( u );
		FlowBoundY( v );
		FlowBoundZ( w );

		IF UseSolutes THEN
			PDE.Advect(solutes, u,v,w, solutes0, dt, ds, BILINEAR);
			diffusionS.SolveMultigrid(solutes0, solutes, solDiffusionCoeff, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations,SoluteBounds ); 
		END;

		(* update pressure field *)
		k:=rho/dt ;
		(*p:= p+ k * pdt;*)(* kg/ms2 *)
		p:=INCMUL(k,pdt);
		PressureBound(p); 	
	END Step;
	
	(* 3-6-threaded version *)
	PROCEDURE StepParallel*( VAR fx, fy, fz: Grid;  dt: Datatype); (* performance question: are the constraints needed inside the multiresolution solvers or can they be used with minimal loss outside only ?*)
	 	VAR stepsize, k:Datatype;
	BEGIN 
		stabilityCriterion:=dt/ds/ds; (* i.e. the "r" in the stability discussion in https://en.wikipedia.org/wiki/Finite_difference_method*)
			(* for explicit/forward time/centered space scheme: only with  stabilityCriterion <0.5 stable . 
				For implicit/ Backward Time, Centered Space Method "BTCS", always stable*)
		stepsize:=dt/1;
		
		(* approach: decompose solution of the problem into advection - diffusion - force application - projection; Solution operator S(u)= P( F( D( A(u) ) ) )  *)
		(* 1) advection A *) (*units: 'length/time' *)
		
		IF Parallel=3 THEN (*three parallel threads*)
			NEW(advection1, v,  u, v, w, v2, dt, ds, BILINEAR );
			NEW(advection0, u,  u, v, w, u2, dt, ds, BILINEAR );
			NEW(advection2, w,  u, v, w, w2, dt, ds, BILINEAR );
		ELSIF Parallel=6 THEN	(*6 parallel threads. As advection is the speed-limiting step in some applications, this may be beneficial on multicore hardware*)(*TBD: better concept for splitting with common border*)
			splitZ:=LEN(v,0) DIV 2;
			NEW(advection1, v,  u, v, w, v2, dt, ds, BILINEAR,0,splitZ-1 ); NEW(advection11, v,  u, v, w, v2, dt, ds, BILINEAR, splitZ,LEN(v,0)-1 );
			NEW(advection0, u,  u, v, w, u2, dt, ds, BILINEAR,0,splitZ-1 ); NEW(advection00, u,  u, v, w, u2, dt, ds, BILINEAR, splitZ,LEN(u,0)-1 );
			NEW(advection2, w,  u, v, w, w2, dt, ds, BILINEAR,0,splitZ-1 ); NEW(advection22, w,  u, v, w, w2, dt, ds, BILINEAR, splitZ,LEN(w,0)-1 );
		ELSE HALT(200)
		END;
		
		IF UseHeat THEN 
			IF Parallel=1 THEN 
				NEW(advection3, heat,  u, v, w, heat0, dt, ds, BILINEAR ) 
			ELSE 
				IF ~Util.SameSize(heat,heat0) THEN NEW(heat0,LEN(heat)) END;
				splitZ:=LEN(heat,0) DIV 2;
				NEW(advection3, heat,  u, v, w, heat0, dt, ds, BILINEAR, 0, splitZ-1 ); 
				NEW(advection33, heat,  u, v, w, heat0, dt, ds, BILINEAR, splitZ, LEN(heat,0)-1 ); 
			END;
		END;

		(*
		advection.SkewSymmetric(u,v,w, u2,v2,w2); (* explodes after 40 steps when using forward/explicit*)
		k:= dt/ds;
		u:=u-k*u2;
		v:=v-k*v2;
		w:=w-k*w2;
		*)
		(*
		k:= dt/ds;
		u2:=u- k*advection.Solenoidal(u,v,w,u);	
		v2:=v-k*advection.Solenoidal(u,v,w,v);
		w2:=w-k*advection.Solenoidal(u,v,w,w);
		*)
		
		 (* 3) force application  this is a better code location (than below)+ for when flow is driven by a pressure field. *)
		 (* in this case, we drive the system by external pressure boundary conditions at inlet and outlet *)
		k :=dt/ds/rho;
		advection1.WaitReady;	IF advection11#NIL THEN advection11.WaitReady END; NEW(nablaScaleInc1, v2, p, tmpv, -k, Nabla.dy);
		advection0.WaitReady;	IF advection00#NIL THEN advection00.WaitReady END; NEW(nablaScaleInc0, u2, p, tmpu, -k, Nabla.dx); (* u2:= u2- k * Nabla.dx(p, NablaMethod);*)(* m/s *)
		advection2.WaitReady;	IF advection22#NIL THEN advection22.WaitReady END; NEW(nablaScaleInc2, w2, p, tmpw, -k, Nabla.dz);
		
		(* 2) diffusion D *) (*result units: length/time *)(* could the boundaries above be taken out of the diffusion multigrid above at limited precision  loss ?? *)
		nablaScaleInc1.WaitReady; NEW(diffusion1, diffusionV, v2, v, nu, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations, FlowBoundY ); 
		nablaScaleInc0.WaitReady; NEW(diffusion0, diffusionU, u2, u, nu, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations, FlowBoundX ); (*!? could we directly use u instead of u3 as target here ?*)
		nablaScaleInc2.WaitReady;NEW(diffusion2, diffusionW, w2, w, nu, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations, FlowBoundZ ); 

		IF UseHeat THEN (* velocity used for advection is not yet corrected for divergence here ..*)
			advection3.WaitReady; 
			IF advection33#NIL THEN advection33.WaitReady END;
			NEW(diffusion3, diffusionH, heat0, heat, heatDiffusionCoeff, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations, HeatBounds ); 			
		END;

		(* 3) force application F *)
		(*may be dropped in certain cases, e.g. if system driven by flow boundary conditions, and not by pressure boundary conditions*)
		 
		IF UseHeat THEN
			IF UseBuoyancy THEN
				diffusion3.WaitReady;
				fy:=heat-temp0; (* ideal gas law: deltaTemp is proportional do deltaVolume, but the latter not implemented, we use constant volume *)
				fy:=GravityConstant * rho * 1/temp0 *fy; (*upwards force || reduction in density || thermal expansion of air, see ideal gas law *)
			END;
		ELSIF UseBuoyancy THEN 
			HALT(200); (*TBD*)
		END;
		
		IF UseGravity THEN diffusion1.WaitReady; v:=v-dt*GravityConstant END;(*downward gravity acceleration*)		
		
		IF LEN(fx,0)>0 THEN diffusion0.WaitReady; u:=INCMUL(dt,fx) END;(*tbd: parallelize*)
		IF LEN(fy,0)>0 THEN diffusion1.WaitReady; v:=INCMUL(dt,fy) END;(*upward buoyancy*)		(*use G*deltaRho  for force *)
		IF LEN(fz,0)>0 THEN diffusion2.WaitReady; w:=INCMUL(dt,fz) END;
		diffusion0.WaitReady; diffusion2.WaitReady;
		
		(* 4) projection: P *)	
		div := divergence( u, v, w, ds );
		IF UseCompressibility THEN (*idea gas law, isobaric: V~~T*)(*! TBD: Check signs !*)
			heat00:=heat-heat00;
			div := DECMUL( 1/temp0, heat00);(* div:=div + heatExpansionMap *) (* "hotter" means that default expansion is too little => reduced div induces increased p *)
		END;(*! experimental; check ! *)
		
		poisson.SolveMultigrid( div, pdt, ds, threshold, minsize, poissoniterations, smoothingiterations,PressureBoundPDT); (*pdt: m2/s*)(*units: div = 1/s ; pressure: kg/ms2 oder N/m2*)
		
		(* adjust velocity field to conform to the noncompressibility requirement *) 		
		k:=1/ds;
		NEW(nablaScaleInc0, u, pdt, tmpu, -k, Nabla.dx);(*u := u - k * Nabla.dx(pdt, NablaMethod);*)
		NEW(nablaScaleInc1, v, pdt, tmpv, -k, Nabla.dy);
		NEW(nablaScaleInc2, w, pdt, tmpw, -k, Nabla.dz);
		
		nablaScaleInc0.WaitReady; FlowBoundX( u );
		nablaScaleInc1.WaitReady; FlowBoundY( v );
		nablaScaleInc2.WaitReady; FlowBoundZ( w );

		IF UseSolutes THEN
			diffusion1.WaitReady; diffusion0.WaitReady; diffusion2.WaitReady; 
			NEW(advection4, solutes, u,v,w, solutes0, dt, ds, BILINEAR);
			advection4.WaitReady;
			NEW(diffusion4, diffusionS, solutes0, solutes, solDiffusionCoeff, dt, ds, threshold, minsize, diffusioniterations, smoothingiterations,SoluteBounds ); 			
		END;

		(* update pressure field *)
		k:=rho/dt ;
		(*p:= p+ k * pdt;*)(* kg/ms2 *)
		p:=INCMUL(k,pdt);
		PressureBound(p); 
		
		IF UseHeat THEN diffusion3.WaitReady END;
		IF UseSolutes THEN diffusion4.WaitReady END;
	END StepParallel;	
	
	PROCEDURE divergence( CONST u, v, w: Grid; ds: Datatype ): Grid;  
	BEGIN 
		RESULT:=Nabla.dx(u, NablaMethod); 
		div0:=Nabla.dy(v, NablaMethod); RESULT := RESULT + div0; 
		div0:=Nabla.dz(w, NablaMethod); RESULT := RESULT + div0;
		RETURN ( 1/ds) * RESULT;
	END divergence;  
	
END NavierStokes;

PROCEDURE Derivative(CONST data:Grid; directions:SET):Grid;
VAR fir:LinearFilters.Filter;
BEGIN
	IF ~Util.SameSize(data,RESULT) THEN NEW(RESULT,LEN(data)) END;
	fir:=LinearFilters.CreateSplineFilter( LinearFilters.SplineDerivativeApproximation);
	(*toSpline3D( cube, cube, 3, directions );*)
	VolumeTransform.Filter3D(data, RESULT, LinearFilters.CreateSplineFilter( LinearFilters.SplineDerivativeApproximation(*LinearFilters.CubicSplineDifferentiator*) ), directions, LinearFilters.mirrorH );
	RETURN RESULT
END Derivative;


(*PROCEDURE divergence( CONST u, v, w: Grid; ds: Datatype ): Grid;  
BEGIN 
	RESULT := 			Nabla.dx(u, NablaMethod); 
	RESULT := RESULT + Nabla.dy(v, NablaMethod); 
	RESULT := RESULT + Nabla.dz(w, NablaMethod); 
	RETURN ( 1/ds) * RESULT;
END divergence;  *)

(*
possible extensions: 
add content in additional layer
	- not influencing computation (-> visualization etc)
	- or influencing physics of fluid
add vorticity confinement
add arbitrary boundaries
add free surface flow (monitor position of surface)
*)
BEGIN
	(*Nabla.splineDerivative:=Derivative*)
END VolumeNavierStokes.

Compiler.Compile
	Matrix/VolumeNabla.Mod
	Matrix/VolumePDE.Mod
	VolumeNavierStokes.Mod
	~

(* from wikipedia: 
viscosities of gases: 
Gas 	C[K]	T0[K]	nu[10-6 Pa s]
air 	120 	291.15 	18.27
nitrogen 	111 	300.55 	17.81
oxygen 	127 	292.25 	20.18
carbon dioxide 	240 	293.15 	14.8
carbon monoxide 	118 	288.15 	17.2
hydrogen 	72 	293.85 	8.76
ammonia 	370 	293.15 	9.82
sulfur dioxide 	416 	293.65 	12.54
helium 	79.4 	273 	19

viscosities of fluids
							viscosity[Pa.s]	viscosity[cP]
liquid nitrogen @ 77K 	1.58 * 10E-4 	0.158
acetone* 	3.06 * 10-4 	0.306
methanol* 	5.44 * 10-4 	0.544
benzene* 	6.04 * 10-4 	0.604
water 	8.94 * 10-4 	0.894
ethanol* 	1.074 * 10-3 	1.074
mercury* 	1.526 * 10-3 	1.526
nitrobenzene* 	1.863 * 10-3 	1.863
propanol* 	1.945 * 10-3 	1.945
Ethylene glycol 	1.61 * 10-2 	16.1
sulfuric acid* 	2.42 * 10-2 	24.2
olive oil 	.081 	81
glycerol 	1.5 	1500
castor oil* 	.985 	985
corn syrup* 	1.3806 	1380.6
HFO-380 	2.022 	2022
pitch 	2.3 * 10E8 	2.3 * 1011

Note that algorithm need kinematic viscosity, i.e. nu/rho !
viscosity of water at different temperatures
Temperature

[oC]	viscosity[Pa.s]
10 	1.308 * 10-3
20 	1.003 * 10-3
30 	7.978 * 10-4
40 	6.531 * 10-4
50 	5.471 * 10-4
60 	4.668 * 10-4
70 	4.044 * 10-4
80 	3.550 * 10-4
90 	3.150 * 10-4
100 	2.822 * 10-4
*)

