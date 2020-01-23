MODULE FFTW; (** AUTHOR "fnecati"; PURPOSE "double precision wrapper for FFTW library"; *)
IMPORT Strings, Modules, KernelLog, HostLibs;

(*! For double precision FLOAT64  type:
	real: 8 bytes (64 bit), complex: 16 bytes (128 bit )*)
	
(*
   complex array represented as (r0,i (r1,i1) (r2,i2) ... (rn-1, in-1) in arrays,
   complex matrix as rows of complex array.
  *)
 
 
CONST
#IF UNIX THEN
	libname = "libfftw3.so.3";
	libthreadname ="libfftw3_threads.so.3";
#ELSE
	libname ="libfftw3-3.dll";
#END

VAR
	dll-: HostLibs.LibHandle; (** handle to fftw library *)
#IF UNIX THEN	
	dllthread: HostLibs.LibHandle; (* for unix platform *)
#END

TYPE 
	Plan* = ADDRESS; (** FFTW planner *)
 
 (** fft direction *)
TYPE Direction* = INTEGER;
CONST
	FORWARD* = -1;
	BACKWARD* = 1;

(** documented planner flags, { 0..21} bits *)
TYPE Flags* = SET32; (* unsigned *)
CONST
	MEASURE* = {};
	DESTROY_INPUT* = {0}; 
	UNALIGNED* = {1}; 
	CONSERVE_MEMORY* = {2}; 
	EXHAUSTIVE* = {3}; (* NO_EXHAUSTIVE is default *)
	PRESERVE_INPUT* = {4}; (* cancels FFTW_DESTROY_INPUT *)
	PATIENT* = {5};  (* IMPATIENT is default *)
	ESTIMATE* = {6}; 
	WISDOM_ONLY* = {21};
	
	(** undocumented beyond-guru flags *)
	ESTIMATE_PATIENT* = {7};
	BELIEVE_PCOST* =  {8};
	NO_DFT_R2HC* =  {9};
	NO_NONTHREADED* = {10};
	NO_BUFFERING* = {11};
	NO_INDIRECT_OP* =  {12};
	ALLOW_LARGE_GENERIC* =  {13}; (* NO_LARGE_GENERIC is default *)
	NO_RANK_SPLITS* =  {14};
	NO_VRANK_SPLITS* = {15};
	NO_VRECURSE* =  {16};
	NO_SIMD* = {17};
	NO_SLOW* = {18};
	NO_FIXED_RADIX_LARGE_N* =  {19};
	ALLOW_PRUNING* =  {20};

	
(** fftw_r2r_kind_do_not_use_me *)
TYPE Kind* = INTEGER;
CONST
	R2HC* = 0;
	HC2R* = 1;
	DHT* = 2;
	REDFT00* = 3;
	REDFT01* = 4;
	REDFT10* = 5;
	REDFT11* = 6;
	RODFT00* = 7;
	RODFT01* = 8;
	RODFT10* = 9;
	RODFT11* = 10;
	
(**  fftw_iodim_do_not_use_me *)
TYPE Iodim* = RECORD
         n* , inps* , outs* : INTEGER;  (* dimension size , input stride, output stride  *)
	END;
	
VAR 

	malloc- : PROCEDURE {PlatformCC} (length: SIZE): ADDRESS;
	free- : PROCEDURE  {PlatformCC} (mem: ADDRESS);
	destroy_plan- : PROCEDURE {PlatformCC} (plan: Plan);
	cleanup- : PROCEDURE {PlatformCC} ;
	set_timelimit-: PROCEDURE {PlatformCC} (seconds: FLOAT64);

	execute-: PROCEDURE {PlatformCC}  (plan: Plan);
	
	(* new-array execute functions *)
	execute_dft-: PROCEDURE {PlatformCC} (plan: Plan; input: ADDRESS; output: ADDRESS );  
	execute_split_dft-: PROCEDURE {PlatformCC} (plan: Plan; realin, imagin: ADDRESS; realout, imagout : ADDRESS );  
	execute_dft_r2c-: PROCEDURE {PlatformCC} (plan: Plan; inputfloat: ADDRESS; outputcomplex: ADDRESS ); 
	execute_split_dft_r2c-: PROCEDURE {PlatformCC} (plan: Plan; inputfloat: ADDRESS; realout, imagout: ADDRESS ); 
	execute_dft_c2r-: PROCEDURE {PlatformCC} (plan: Plan; inputcomplex: ADDRESS; outputfloat: ADDRESS ); 
	execute_split_dft_c2r-: PROCEDURE {PlatformCC} (plan: Plan; realin, imagin: ADDRESS; floatout: ADDRESS );        
	execute_r2r-: PROCEDURE {PlatformCC} (plan: Plan; inputfloat: ADDRESS; outputfloat: ADDRESS ); 
        
	plan_dft_1d- :  PROCEDURE  {PlatformCC} (n: INTEGER; input: ADDRESS; output: ADDRESS; direction: Direction; flags: Flags): Plan;
	plan_dft_2d-: PROCEDURE {PlatformCC}  (ny, nx: INTEGER; input, output: ADDRESS; direction: Direction; flags: Flags): Plan;
	plan_dft_3d-: PROCEDURE {PlatformCC}  (nz, ny, nx: INTEGER; input, output: ADDRESS; direction: Direction; flags: Flags): Plan;
	plan_dft-: PROCEDURE {PlatformCC}  (rank: INTEGER; n: ADDRESS; input, output: ADDRESS; direction: Direction; flags: Flags): Plan;

	plan_dft_r2c_1d-: PROCEDURE {PlatformCC}  (n: INTEGER; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_r2c_2d-: PROCEDURE {PlatformCC}  (ny, nx: INTEGER; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_r2c_3d-: PROCEDURE {PlatformCC}  (nz, ny, nx: INTEGER; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_r2c-: PROCEDURE {PlatformCC}  (rank: INTEGER; n: ADDRESS; input, output: ADDRESS; flags: Flags): Plan;

	plan_dft_c2r_1d-: PROCEDURE {PlatformCC}  (n: INTEGER; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_c2r_2d-: PROCEDURE {PlatformCC}  (ny, nx: INTEGER; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_c2r_3d-: PROCEDURE {PlatformCC} (nz, ny, nx: INTEGER; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_c2r-: PROCEDURE {PlatformCC}  (rank: INTEGER; n: ADDRESS; input, output: ADDRESS; flags: Flags): Plan;

	plan_r2r_1d-: PROCEDURE {PlatformCC}  (n: INTEGER; input, output: ADDRESS; kind: Kind; flags: Flags): Plan;
	plan_r2r_2d-: PROCEDURE {PlatformCC}  (ny, nx: INTEGER; input, output: ADDRESS; kindx, kindy: Kind; flags: Flags): Plan;
	plan_r2r_3d-: PROCEDURE {PlatformCC}  (nz, ny, nx: INTEGER; input, output: ADDRESS; kindx, kindy, kindz: Kind; flags: Flags): Plan;
	plan_r2r-: PROCEDURE {PlatformCC} (rank: INTEGER; n: ADDRESS; input, output: ADDRESS; kind: ADDRESS; flags: Flags): Plan;

	(* plans for many dfts *)
	
	plan_many_dft- : PROCEDURE {PlatformCC} (rank: INTEGER; n: ADDRESS; howmany: INTEGER; input: ADDRESS; inembed: ADDRESS; istride: INTEGER; idist: INTEGER;	
                         output: ADDRESS; onembed: ADDRESS; ostride: INTEGER; odist: INTEGER; sign: Direction; flags: Flags): Plan;


	plan_many_dft_r2c- : PROCEDURE {PlatformCC} (rank: INTEGER; n: ADDRESS; howmany: INTEGER; Rin: ADDRESS; inembed: ADDRESS;  istride: INTEGER; idist: INTEGER;
                             Cout : ADDRESS; onembed: ADDRESS; ostride: INTEGER;  odist: INTEGER; flags: Flags): Plan;
   
	plan_many_dft_c2r- : PROCEDURE {PlatformCC} (rank: INTEGER; n: ADDRESS; howmany: INTEGER; Cin: ADDRESS; inembed: ADDRESS;  istride: INTEGER; idist: INTEGER;
                             Rout : ADDRESS; onembed: ADDRESS; ostride: INTEGER;  odist: INTEGER; flags: Flags): Plan;
 
	(* Guru fftw*)
	plan_guru_dft- : PROCEDURE {PlatformCC} (rank: INTEGER;  dims: ADDRESS; howmany_rank: INTEGER; howmany_dims: ADDRESS; in, out: ADDRESS;  sign: Direction; flags: Flags): Plan;
	plan_guru_split_dft- : PROCEDURE {PlatformCC} (rank: INTEGER;  dims: ADDRESS; howmany_rank: INTEGER; howmany_dims: ADDRESS; realinput, imaginput: ADDRESS; realout, imagout: ADDRESS; flags: Flags): Plan;
 
 
	(*  Guru Real-data DFTs*)
	plan_guru_dft_r2c- : PROCEDURE {PlatformCC}(rank: INTEGER; dims: ADDRESS; howmany_rank: INTEGER; howmany_dims: ADDRESS;
						          doublein: ADDRESS; complexout: ADDRESS; flags: Flags): Plan;
     
	plan_guru_split_dft_r2c- : PROCEDURE {PlatformCC}(rank: INTEGER; dims: ADDRESS; howmany_rank: INTEGER; howmany_dims: ADDRESS;
						          doublein: ADDRESS; double_ro: ADDRESS; double_io: ADDRESS; flags: Flags): Plan;
     
	plan_guru_dft_c2r- : PROCEDURE {PlatformCC}(rank: INTEGER; dims: ADDRESS; howmany_rank: INTEGER; howmany_dims: ADDRESS;
						          complexin: ADDRESS; doubleout: ADDRESS; flags: Flags): Plan;
     
	plan_guru_split_dft_c2r- : PROCEDURE {PlatformCC}( rank: INTEGER; dims: ADDRESS; howmany_rank: INTEGER; howmany_dims: ADDRESS;
						          double_ri: ADDRESS; double_ii: ADDRESS; double_out: ADDRESS; flags: Flags): Plan;

                        
	(* total flops ~ add+mul + 2*fma or add+mul + fma   if fma (fused multipy  add) suported *)
	flops-: PROCEDURE {PlatformCC} (plan: Plan; VAR add, mul, fma: FLOAT64);

	init_threads- : PROCEDURE {PlatformCC} (): INTEGER;	
	plan_with_nthreads- : PROCEDURE {PlatformCC} (n: INTEGER);
	cleanup_threads- : PROCEDURE {PlatformCC};

	print_plan- : PROCEDURE {PlatformCC} (plan: Plan);
(*	sprint_plan- :  PROCEDURE {PlatformCC} (plan: Plan): ADDRESS;*)
	
	estimate_cost- : PROCEDURE {PlatformCC} (plan: Plan): FLOAT64;
	cost- : PROCEDURE {PlatformCC} (plan: Plan): FLOAT64;

	alignment_of- : PROCEDURE {PlatformCC} (realArray: ADDRESS): INTEGER;
	xversion - : ADDRESS;
	
(*! wrappers for above procedures*)

PROCEDURE version*(): Strings.String;
BEGIN
	RETURN GetStringFromAddr(xversion);
END version;

PROCEDURE Malloc* (length: SIZE): ADDRESS;
BEGIN
	RETURN malloc(length);
END Malloc;

PROCEDURE Free* (mem: ADDRESS);
BEGIN
	free(mem);
END Free;
	
PROCEDURE Execute*(plan: Plan);
BEGIN
	execute(plan);
END Execute;

PROCEDURE ExecuteDft1din*(plan: Plan; VAR inout: ARRAY [*] OF FLOAT64);
VAR adrio: ADDRESS;
BEGIN
	adrio := ADDRESSOF(inout[0]);		
	execute_dft(plan, adrio, adrio);
END ExecuteDft1din;

PROCEDURE ExecuteDft1dinout*(plan: Plan; VAR in, out: ARRAY [*] OF FLOAT64);
VAR adri, adro: ADDRESS;
BEGIN
	adri := ADDRESSOF(in[0]); adro := ADDRESSOF(out[0]);		
	execute_dft(plan, adri, adro);
END ExecuteDft1dinout;

PROCEDURE ExecuteDftComplex1din*(plan: Plan; VAR inout: ARRAY [*] OF COMPLEX64);
VAR adrio: ADDRESS;
BEGIN
	adrio := ADDRESSOF(inout[0]); 
	execute_dft(plan, adrio, adrio);
END ExecuteDftComplex1din;

PROCEDURE ExecuteDftComplex1dinout*(plan: Plan; VAR in, out: ARRAY [*] OF COMPLEX64);
VAR adri, adro: ADDRESS;
BEGIN
	adri := ADDRESSOF(in[0]); adro := ADDRESSOF(out[0]);
	execute_dft(plan, adri, adro);
END ExecuteDftComplex1dinout;
	
PROCEDURE ExecuteDft2dinout*(plan: Plan; VAR in, out: ARRAY [*,*] OF FLOAT64);
VAR adri, adro: ADDRESS;
BEGIN		
	adri := ADDRESSOF(in[0,0]); adro := ADDRESSOF(out[0,0]);
	execute_dft(plan, adri, adro);
END ExecuteDft2dinout;

PROCEDURE ExecuteDft2din*(plan: Plan; VAR inout: ARRAY [*,*] OF FLOAT64);
VAR adrio: ADDRESS;
BEGIN
	adrio := ADDRESSOF(inout[0,0]);		
	execute_dft(plan, adrio, adrio);
END ExecuteDft2din;

PROCEDURE ExecuteDftComplex2din*(plan: Plan; VAR inout : ARRAY [*,*] OF COMPLEX64);
VAR adrio: ADDRESS;
BEGIN
	adrio := ADDRESSOF(inout[0,0]);
	execute_dft(plan, adrio, adrio);
END ExecuteDftComplex2din;

PROCEDURE ExecuteDftComplex2dinout*(plan: Plan; VAR in, out: ARRAY [*,*] OF COMPLEX64);
VAR adri, adro: ADDRESS;
BEGIN
	adri := ADDRESSOF(in[0,0]);
	adro := ADDRESSOF(out[0,0]);
	execute_dft(plan, adri, adro);
END ExecuteDftComplex2dinout;
	
PROCEDURE DestroyPlan*(plan: Plan);
BEGIN	
	destroy_plan(plan);
END DestroyPlan;

PROCEDURE Cleanup*;
BEGIN
	cleanup;
END Cleanup;

PROCEDURE SetTimeLimit*(seconds: FLOAT64);
BEGIN
	set_timelimit(seconds);
END SetTimeLimit;
		
PROCEDURE Flops* (plan: Plan; VAR add, mul, fma: FLOAT64);
BEGIN
	flops(plan, add,mul, fma);
END Flops;

(*! ====== IN PLACE TRANSFORMS ====== *)
(* 1d- in-place real transform *)
PROCEDURE PlanDft1Din*(VAR a: ARRAY [*] OF FLOAT64; dir: Direction): Plan;
VAR adr : ADDRESS;
	nx: INTEGER;
BEGIN
	adr := ADDRESSOF(a[0]);
	nx := (LEN(a, 0) DIV 2)(INTEGER);		
	RETURN plan_dft_1d(nx, adr, adr, dir, ESTIMATE);
END PlanDft1Din;

(* 1d- in-place Complex transform *)
PROCEDURE PlanDftComplex1Din*(VAR a: ARRAY [*] OF COMPLEX64; dir: Direction): Plan;
VAR adr : ADDRESS;
	nx: INTEGER;
BEGIN
	adr := ADDRESSOF(a[0]);
	nx := LEN(a, 0)(INTEGER);
	RETURN plan_dft_1d(nx, adr, adr, dir, ESTIMATE);
END PlanDftComplex1Din;
	
(* 2d- in-place real transform *)
PROCEDURE PlanDft2Din*(VAR a: ARRAY [*,*] OF FLOAT64; dir: Direction): Plan;
VAR adr: ADDRESS;
	nx, ny: INTEGER;
BEGIN
	adr := ADDRESSOF(a[0,0]);
	nx := (LEN(a, 1) DIV 2)(INTEGER);
	ny := LEN(a, 0)(INTEGER);
	RETURN plan_dft_2d(ny, nx, adr, adr, dir, ESTIMATE);
END PlanDft2Din;

(* 2d- in-place Complex transform *)
PROCEDURE PlanDftComplex2Din*(VAR a: ARRAY [*,*] OF COMPLEX64; dir: Direction): Plan;
VAR adr: ADDRESS;
	nx, ny: INTEGER;
BEGIN
	adr := ADDRESSOF(a[0,0]);
	nx := LEN(a, 1)(INTEGER);
	ny := LEN(a, 0)(INTEGER);
	RETURN plan_dft_2d(ny, nx, adr, adr, dir, ESTIMATE);
END PlanDftComplex2Din;

(* 3d- in-place real transform *)
PROCEDURE PlanDft3Din*(VAR a: ARRAY [*,*,*] OF FLOAT64; dir: Direction): Plan;
VAR adr: ADDRESS;
	nx, ny, nz: INTEGER;
BEGIN
	adr := ADDRESSOF(a[0,0,0]);
	nx := (LEN(a, 2) DIV 2)(INTEGER);
	ny := LEN(a, 1)(INTEGER);
	nz := LEN(a, 0)(INTEGER);		
	RETURN plan_dft_3d(nz, ny, nx, adr, adr, dir, ESTIMATE);
END PlanDft3Din;	

(* 3d- in-place Complex transform *)
PROCEDURE PlanDftComplex3Din*(VAR a: ARRAY [*,*,*] OF COMPLEX64; dir: Direction): Plan;
VAR adr: ADDRESS;
	nx, ny, nz: INTEGER;
BEGIN
	adr := ADDRESSOF(a[0,0,0]);
	nx := LEN(a, 2)(INTEGER);
	ny := LEN(a, 1)(INTEGER);
	nz := LEN(a, 0)(INTEGER);		
	RETURN plan_dft_3d(nz, ny, nx, adr, adr, dir, ESTIMATE);
END PlanDftComplex3Din;	

(*! ====== OUT OF PLACE TRANSFORMS ======= *)
(* 1d- out of place real transform *)
PROCEDURE PlanDft1Dinout*(VAR a, b: ARRAY [*] OF FLOAT64; dir: Direction): Plan;
VAR adr, adr1: ADDRESS;
	nx: INTEGER;
BEGIN
	ASSERT(LEN(a) = LEN(b));
	adr := ADDRESSOF(a[0]);
	adr1 := ADDRESSOF(b[0]);
	nx := (LEN(a, 0) DIV 2)(INTEGER);		
	RETURN plan_dft_1d(nx, adr, adr1, dir, ESTIMATE);
END PlanDft1Dinout;

(* 1d- out of place Complex transform *)
PROCEDURE PlanDftComplex1Dinout*(VAR a, b: ARRAY [*] OF COMPLEX64; dir: Direction): Plan;
VAR adr, adr1: ADDRESS;
	nx: INTEGER;
BEGIN
	ASSERT(LEN(a) = LEN(b));
	adr := ADDRESSOF(a[0]);
	adr1 := ADDRESSOF(b[0]);	
	nx := LEN(a, 0)(INTEGER);
	RETURN plan_dft_1d(nx, adr, adr1, dir, ESTIMATE);
END PlanDftComplex1Dinout;
	
(* 2d- out of place real transform *)
PROCEDURE PlanDft2Dinout*(VAR a, b: ARRAY [*,*] OF FLOAT64; dir: Direction): Plan;
VAR adr, adr1: ADDRESS;
	nx, ny: INTEGER;
BEGIN
	ASSERT(LEN(a,0) = LEN(b,0));
	ASSERT(LEN(a,1) = LEN(b,1));
	adr := ADDRESSOF(a[0,0]);
	adr1 := ADDRESSOF(b[0,0]);
	nx := (LEN(a, 1) DIV 2)(INTEGER);
	ny := LEN(a, 0)(INTEGER);
	RETURN plan_dft_2d(ny, nx, adr, adr1, dir, ESTIMATE);
END PlanDft2Dinout;

(* 2d- out of place Complex transform *)
PROCEDURE PlanDftComplex2Dinout*(VAR a, b: ARRAY [*,*] OF COMPLEX64; dir: Direction): Plan;
VAR adr, adr1: ADDRESS;
	  	nx, ny: INTEGER;
BEGIN
	ASSERT(LEN(a,0) = LEN(b,0));
	ASSERT(LEN(a,1) = LEN(b,1));
	adr := ADDRESSOF(a[0,0]);
	adr1 := ADDRESSOF(b[0,0]);
	nx := LEN(a, 1)(INTEGER);
	ny := LEN(a, 0)(INTEGER);
	RETURN plan_dft_2d(ny, nx , adr, adr1, dir,ESTIMATE);
END PlanDftComplex2Dinout;

(* 3d- out of place real transform *)
PROCEDURE PlanDft3Dinout*(VAR a, b: ARRAY [*,*,*] OF FLOAT64; dir: Direction): Plan;
VAR adr, adr1: ADDRESS;
	nx, ny, nz: INTEGER;
BEGIN
	ASSERT(LEN(a,0) = LEN(b,0));
	ASSERT(LEN(a,1) = LEN(b,1));
	ASSERT(LEN(a,2) = LEN(b,2));
	adr := ADDRESSOF(a[0,0,0]);
	adr1 := ADDRESSOF(b[0,0,0]);
	nx := (LEN(a, 2) DIV 2)(INTEGER);
	ny := LEN(a, 1)(INTEGER);
	nz := LEN(a, 0)(INTEGER);		
	RETURN plan_dft_3d(nz, ny, nx, adr, adr1, dir, ESTIMATE);
END PlanDft3Dinout;

(* 3d- out of place Complex transform *)
PROCEDURE PlanDftComplex3Dinout*(VAR a, b: ARRAY [*,*,*] OF COMPLEX64; dir: Direction): Plan;
VAR adr, adr1: ADDRESS;
	nx, ny, nz: INTEGER;
BEGIN
	ASSERT(LEN(a,0) = LEN(b,0));
	ASSERT(LEN(a,1) = LEN(b,1));
	ASSERT(LEN(a,2) = LEN(b,2));
	adr := ADDRESSOF(a[0,0,0]);
	adr1 := ADDRESSOF(b[0,0,0]);
	nx := LEN(a, 2)(INTEGER);
	ny := LEN(a, 1)(INTEGER);
	nz := LEN(a, 0)(INTEGER);		
	RETURN plan_dft_3d(nz, ny, nx, adr, adr1, dir, ESTIMATE);
END PlanDftComplex3Dinout;

PROCEDURE GetProcAddress*( lib: HostLibs.LibHandle;  CONST procName: ARRAY OF CHAR;  adr: ADDRESS );
VAR res: BOOLEAN;
BEGIN
	res := HostLibs.GetProcedure(lib,  procName, adr);
END GetProcAddress;

PROCEDURE Init;
VAR res: BOOLEAN;
BEGIN 
	(* load the DLL *)	
	res := HostLibs.LoadLibrary(libname, dll);
	ASSERT(res, 302);
	
#IF UNIX THEN
	res :=  HostLibs.LoadLibrary(libthreadname, dllthread);
	ASSERT(res, 303);
#END
	
	GetProcAddress(dll, "fftw_malloc", ADDRESSOF( malloc));
	GetProcAddress(dll, "fftw_free", ADDRESSOF( free ));
	GetProcAddress(dll, "fftw_destroy_plan", ADDRESSOF( destroy_plan ));				
	GetProcAddress(dll, "fftw_cleanup", ADDRESSOF( cleanup ));

	GetProcAddress(dll, "fftw_execute", ADDRESSOF( execute ));

	GetProcAddress(dll, "fftw_execute_dft", ADDRESSOF( execute_dft ));
	GetProcAddress(dll, "fftw_execute_split_dft", ADDRESSOF( execute_split_dft ));
	GetProcAddress(dll, "fftw_execute_dft_r2c", ADDRESSOF( execute_dft_r2c ));
	GetProcAddress(dll, "fftw_execute_split_dft_r2c", ADDRESSOF( execute_split_dft_r2c ));
	GetProcAddress(dll, "fftw_execute_dft_c2r", ADDRESSOF( execute_dft_c2r ));
	GetProcAddress(dll, "fftw_execute_split_dft_c2r", ADDRESSOF( execute_split_dft_c2r ));
	GetProcAddress(dll, "fftw_execute_r2r", ADDRESSOF( execute_r2r ));

	GetProcAddress(dll, "fftw_plan_dft_1d", ADDRESSOF( plan_dft_1d ));				
	GetProcAddress(dll, "fftw_plan_dft_2d", ADDRESSOF( plan_dft_2d ));
	GetProcAddress(dll, "fftw_plan_dft_3d", ADDRESSOF( plan_dft_3d ));				
	GetProcAddress(dll, "fftw_plan_dft", ADDRESSOF( plan_dft ));

	GetProcAddress(dll, "fftw_plan_dft_r2c_1d", ADDRESSOF( plan_dft_r2c_1d ));				
	GetProcAddress(dll, "fftw_plan_dft_r2c_2d", ADDRESSOF( plan_dft_r2c_2d ));
	GetProcAddress(dll, "fftw_plan_dft_r2c_3d", ADDRESSOF( plan_dft_r2c_3d ));				
	GetProcAddress(dll, "fftw_plan_dft_r2c", ADDRESSOF( plan_dft_r2c ));

	GetProcAddress(dll, "fftw_plan_dft_c2r_1d", ADDRESSOF(  plan_dft_c2r_1d ));				
	GetProcAddress(dll, "fftw_plan_dft_c2r_2d", ADDRESSOF( plan_dft_c2r_2d ));
	GetProcAddress(dll, "fftw_plan_dft_c2r_3d", ADDRESSOF( plan_dft_c2r_3d ));
	GetProcAddress(dll, "fftw_plan_dft_c2r", ADDRESSOF( plan_dft_c2r ));

	GetProcAddress(dll, "fftw_plan_r2r_1d", ADDRESSOF( plan_r2r_1d ));
	GetProcAddress(dll, "fftw_plan_r2r_2d", ADDRESSOF( plan_r2r_2d ));	
	GetProcAddress(dll, "fftw_plan_r2r_3d", ADDRESSOF( plan_r2r_3d ));
	GetProcAddress(dll, "fftw_plan_r2r", ADDRESSOF( plan_r2r ));


	GetProcAddress(dll, "fftw_plan_many_dft", ADDRESSOF( plan_many_dft ));
	GetProcAddress(dll, "fftw_plan_many_dft_r2c", ADDRESSOF( plan_many_dft_r2c ));
	GetProcAddress(dll, "fftw_plan_many_dft_c2r", ADDRESSOF( plan_many_dft_c2r ));
	
	GetProcAddress(dll, "fftw_plan_guru_dft", ADDRESSOF( plan_guru_dft ));
	GetProcAddress(dll, "fftw_plan_guru_split_dft", ADDRESSOF( plan_guru_dft ));

	GetProcAddress(dll, "fftw_plan_guru_dft_r2c", ADDRESSOF( plan_guru_dft_r2c ));
	GetProcAddress(dll, "fftw_plan_guru_split_dft_r2c", ADDRESSOF( plan_guru_split_dft_r2c ));
	GetProcAddress(dll, "fftw_plan_guru_dft_c2r", ADDRESSOF( plan_guru_dft_c2r ));
	GetProcAddress(dll, "fftw_plan_guru_split_dft_c2r", ADDRESSOF( plan_guru_split_dft_c2r ));

	
	GetProcAddress(dll, "fftw_flops", ADDRESSOF( flops ));

#IF UNIX THEN
	GetProcAddress(dllthread, "fftw_init_threads", ADDRESSOF( init_threads ));
	GetProcAddress(dllthread, "fftw_plan_with_nthreads", ADDRESSOF( plan_with_nthreads ));
	GetProcAddress(dllthread, "fftw_cleanup_threads", ADDRESSOF( cleanup_threads ));
#ELSE
	GetProcAddress(dll, "fftw_init_threads", ADDRESSOF( init_threads ));
	GetProcAddress(dll, "fftw_plan_with_nthreads", ADDRESSOF( plan_with_nthreads ));
	GetProcAddress(dll, "fftw_cleanup_threads", ADDRESSOF( cleanup_threads ));
#END

	GetProcAddress(dll, "fftw_print_plan", ADDRESSOF( print_plan ));
	(* GetProcAddress(dll, "fftw_sprint_plan", ADDRESSOF( sprint_plan )); *)

	GetProcAddress(dll, "fftw_estimate_cost", ADDRESSOF( estimate_cost ));
	GetProcAddress(dll, "fftw_cost", ADDRESSOF( cost ));

	GetProcAddress(dll, "fftw_alignment_of", ADDRESSOF( alignment_of ));
	GetProcAddress(dll, "fftw_version", ADDRESSOF( xversion ));
	

	KernelLog.String(libname); KernelLog.String(" library loaded.");  KernelLog.Ln; 
	KernelLog.String("version: "); KernelLog.String(version()^); KernelLog.Ln;
END Init;

PROCEDURE OnClose;
VAR res: BOOLEAN;
BEGIN
	cleanup;
	res := HostLibs.FreeLibrary(dll);
	KernelLog.String(libname); KernelLog.String(" library unloaded."); KernelLog.Ln; 
	
#IF UNIX THEN
		res := HostLibs.FreeLibrary(dllthread);
		KernelLog.String(libthreadname); KernelLog.String(" library unloaded."); KernelLog.Ln; 
#END;
END OnClose;

(* Get string from address  *)
(* Get string from address *)
PROCEDURE GetStringFromAddr*(adr: ADDRESS): Strings.String;
VAR s: POINTER {UNSAFE} TO ARRAY MAX(SIZE) OF CHAR;
	str: Strings.String;
	pos: SIGNED32;
BEGIN
	s := adr;
	pos := 0;
	IF adr # NIL THEN
		WHILE s[pos] # 0X DO INC(pos); END;
		NEW(str, pos + 1);
		pos := 0;
		WHILE s[pos] # 0X DO str[pos] := s[pos]; INC(pos); END;

	ELSE NEW(str, 1);
	END;
	str[pos] := 0X;
	RETURN str;
END GetStringFromAddr;
		
BEGIN
	Init;
	Modules.InstallTermHandler(OnClose)  
END FFTW.
