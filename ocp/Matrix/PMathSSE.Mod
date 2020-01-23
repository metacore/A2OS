MODULE PMathSSE; (** AUTHOR "Patrick Hunziker"; PURPOSE "Fast functions by B-spline interpolation"; *)

IMPORT Math, PMath, Commands, Kernel,SYSTEM;

CONST invPi=1/Math.pi; halfPi=Math.pi/2;

CONST
InterpolTanhCoeff03= (* cubic interpolation coefficients for tanh sampled at integer locations -1..2; 0..3; 1..4 *)
 [[ -1.380164623260498E-001,  0.000000000000000E+000,  8.996101617813110E-001,  0.000000000000000E+000  ],
[ 1.309218853712082E-001, -4.140493571758271E-001,  4.855607748031616E-001,  7.615936994552613E-001  ],
[ 2.083162544295192E-003, -2.128370665013790E-002,  5.022772401571274E-002,  9.640269279479980E-001]];

TanhCoeff= (* cubic interpolation coefficients for tanh sampled at 10*downsampled integer locations -0.1..0.2; 0..0.3; 0.1..0.4 etc *)
[
[  -3.310987089197449E-004,   0.000000000000000E+000,   9.999903345696216E-002,   0.000000000000000E+000],
[  -3.051743599838249E-004,  -9.932961267592528E-004,   9.900573733020290E-002,   9.966793474804241E-002],
[  -2.575603427896747E-004,  -1.908819206710718E-003,   9.610362199673293E-002,   1.973752015915023E-001],
[  -1.955128870242968E-004,  -2.681500235079706E-003,   9.151330255494248E-002,   2.913124440387348E-001],
[  -1.275852027192408E-004,  -3.268038896152512E-003,   8.556376342371024E-002,   3.799487334715733E-001],
[  -6.175494142811401E-005,  -3.650794504310272E-003,   7.864493002324745E-002,   4.621168727964118E-001],
[  -3.872713425453873E-006,  -3.836059328594614E-003,   7.115807619034251E-002,   5.370492533739209E-001],
[   4.230872761166504E-005,  -3.847677468871124E-003,   6.347433939287675E-002,   6.043673975222433E-001],
[   7.589013562684035E-005,  -3.720751286036092E-003,   5.590591063796952E-002,   6.640363681738606E-001],
[   9.727188927320827E-005,  -3.493080879155422E-003,   4.869207847277799E-002,   7.162974176614208E-001],
[   1.083832494234426E-004,  -3.201265211335761E-003,   4.199773238228682E-002,   7.615936871443165E-001],
[   1.113345777116356E-004,  -2.876115463065581E-003,   3.592035170788548E-002,   8.004985375646908E-001],
[   1.084954183051193E-004,  -2.542111729930785E-003,   3.050212451488918E-002,   8.336541083872225E-001],
[   1.017196310258415E-004,  -2.216625475015353E-003,   2.574338730994312E-002,   8.617226165904860E-001],
[   9.276973890815164E-005,  -1.911466581937903E-003,   2.161529525298994E-002,   8.853510980564397E-001],
[   8.278024048752155E-005,  -1.633157365213374E-003,   1.807067130583874E-002,   9.051476964663998E-001],
[   7.262945739823827E-005,  -1.384816643750883E-003,   1.505269729687448E-002,   9.216679906475128E-001],
[   6.290021861173316E-005,  -1.166928271556094E-003,   1.250095238156750E-002,   9.354085007580345E-001],
[   5.387349417080362E-005,  -9.782276157208947E-004,   1.035579649429051E-002,   9.468054250866577E-001],
[   4.576458168975592E-005,  -8.166071332084099E-004,   8.560961745361205E-003,   9.562368674593983E-001],
[   3.861919456842638E-005,  -6.793133881392903E-004,   7.065041224013580E-003,   9.640269866532409E-001],
[   3.238177174781166E-005,  -5.634558044337892E-004,   5.822272031440575E-003,   9.704513336836835E-001],
[   2.706414187007104E-005,  -4.663104891903172E-004,   4.792505737816395E-003,   9.757425316824381E-001],
[   2.250507086367191E-005,  -3.851180635801780E-004,   3.941077185045825E-003,   9.800957910729342E-001],
[   1.868214048827407E-005,  -3.176028509891623E-004,   3.238356270476485E-003,   9.836742552652636E-001],
[   1.545992243188460E-005,  -2.615564295244881E-004,   2.659196989962835E-003,   9.866136908252389E-001],
[   1.276595729876619E-005,  -2.151766622288158E-004,   2.182463898209531E-003,   9.890267913081094E-001],
[   1.053431411144149E-005,  -1.768787903326652E-004,   1.790408445648050E-003,   9.910068445013888E-001],
[   8.670218501674856E-006,  -1.452758479983408E-004,   1.468253807317044E-003,   9.926309084708157E-001],
[   7.136941913692578E-006,  -1.192651924932422E-004,   1.203712766825461E-003,   9.939625566486361E-001],
[   5.865372619796279E-006,  -9.785436675220146E-005,   9.865932075800172E-004,   9.950541411648818E-001],
[   4.816910374353334E-006,  -8.025824889281263E-005,   8.084805919350032E-004,   9.959487453783296E-001],
[   3.954007671731761E-006,  -6.580751776986367E-005,   6.624148252724010E-004,   9.966817846317461E-001],
[   3.251896996709664E-006,  -5.394549475466837E-005,   5.426618127479430E-004,   9.972823459469203E-001],
[   2.632294474162409E-006,  -4.418980376442836E-005,   4.445265142287722E-004,   9.977743141619104E-001],
[   2.293363808538744E-006,  -3.629292034208916E-005,   3.640437901221806E-004,   9.981772831668488E-001],
[   1.373971290462490E-006,  -2.941282891652844E-005,   2.983380408636370E-004,   9.985073274004374E-001],
[   3.012774790171540E-006,  -2.529091504506695E-005,   2.436342969021156E-004,   9.987776265836749E-001],
[  -4.570176372024136E-006,  -1.625259067447831E-005,   2.020907911825704E-004,   9.989989827403225E-001],
[   2.252186056791070E-005,  -2.996311979062473E-005,   1.558750807174673E-004,   9.991802507644586E-001]
];

TanHCoeff21=
 (*  tanh, scaled * 2, shifted by 1, i.e. at [-3,-1,1,3] . Fast approximation in particular in [-1..1], and somewhat slower for algo [-2..2] *)
[ (*[  -7.684411937092871E-002,   5.172351688091893E-002,   2.997505007763945E-002,  -9.999085887525117E-001], **)
[   5.093795695257413E-001,  -1.788088412318671E-001,  -9.711027427330875E-002,  -9.950541411648818E-001],
[  -8.995532448969045E-001,   1.349329867345357E+000,   1.073410751840181E+000,  -7.615936871443165E-001],
[   5.093795695257413E-001,  -1.349329867345357E+000,   1.073410751840181E+000,   7.615936871443165E-001],
[  -7.684411937092870E-002,   1.788088412318671E-001,  -9.711027427330875E-002,   9.950541411648818E-001]
];

LogisticCoeff= (* cubic interpolation coefficients for logistic function sampled at 10*downsampled integer locations -0.1..0.2; 0..-0.3; etc *)
[
[  -2.079873463624234E-005,  -7.401487051415874E-017,   2.499997120883747E-002,   4.999996922170131E-001],
[  -2.038390119974919E-005,  -6.239620390880104E-005,   2.493757500492860E-002,   5.249788646912143E-001],
[  -1.957645847801915E-005,  -1.235479075080486E-004,   2.475163089351174E-002,   5.498336595910343E-001],
[  -1.840152591554810E-005,  -1.822772829419951E-004,   2.444580570306171E-002,   5.744421661185601E-001],
[  -1.690967443666288E-005,  -2.374818606885653E-004,   2.402604655943114E-002,   5.986872930127642E-001],
[  -1.517673143534082E-005,  -2.882108839984429E-004,   2.350035381474414E-002,   6.224589480370701E-001],
[  -1.321679902964249E-005,  -3.337410783044839E-004,   2.287840185244121E-002,   6.456559142363805E-001],
[  -1.117708203773789E-005,  -3.733914753934114E-004,   2.217126929874331E-002,   6.681873582114877E-001],
[  -9.031243961599823E-006,  -4.069227215067177E-004,   2.139095510184326E-002,   6.899740589527995E-001],
[  -6.930947509625233E-006,  -4.340164533914431E-004,   2.055001592694517E-002,   7.109490600891748E-001],
[  -4.861269163540457E-006,  -4.548092959203372E-004,   1.966119017763339E-002,   7.310581286152188E-001],
[  -2.923998686111250E-006,  -4.693931034109587E-004,   1.873698777830209E-002,   7.502596482277683E-001],
[  -1.092095730643417E-006,  -4.781650994691629E-004,   1.778942957542190E-002,   7.685243189039735E-001],
[   5.179913085181763E-007,  -4.814413866610191E-004,   1.682982308929165E-002,   7.858344912841956E-001],
[   1.975067320378674E-006,  -4.798874127353536E-004,   1.586849428989527E-002,   8.021833909781344E-001],
[   3.220925716948797E-006,  -4.739622107742176E-004,   1.491464466638570E-002,   8.175739729226148E-001],
[   4.260769507999352E-006,  -4.642994336233712E-004,   1.397638302198804E-002,   8.320178763039432E-001],
[   5.131047741304881E-006,  -4.515171250992251E-004,   1.306056646326537E-002,   8.455342206618158E-001],
[   5.785040813230579E-006,  -4.361239818752919E-004,   1.217292535629078E-002,   8.581484010477232E-001],
[   6.284670675060229E-006,  -4.187688594356743E-004,   1.131803251497974E-002,   8.698909874629521E-001],
[   6.651375605863004E-006,  -3.999148474106045E-004,   1.049934880813353E-002,   8.807965357891711E-001],
[   6.827354321526250E-006,  -3.799607205930155E-004,   9.719473240129983E-003,   8.909026211255000E-001],
[   6.959358583059096E-006,  -3.594786576284368E-004,   8.980033861908532E-003,   9.002489609993584E-001],
[   6.916807881216856E-006,  -3.386005818794075E-004,   8.281954622400690E-003,   9.088764755622217E-001],
[   6.850973823029819E-006,  -3.178501582358125E-004,   7.625503882285542E-003,   9.168267464106240E-001],
[   6.690153242584221E-006,  -2.972972367665749E-004,   7.010356487283229E-003,   9.241412511084967E-001],
[   6.463746294549226E-006,  -2.772267770388778E-004,   6.435832473477850E-003,   9.308610005122561E-001],
[   6.236670114158073E-006,  -2.578355381550821E-004,   5.900770158283965E-003,   9.370260699549898E-001],
[   5.933364180206026E-006,  -2.391255278125894E-004,   5.403809092316219E-003,   9.426752412452326E-001],
[   5.649582337013756E-006,  -2.213254352719713E-004,   4.943358129231585E-003,   9.478458581739166E-001],
[   5.332326837494837E-006,  -2.043766882608930E-004,   4.517656005698721E-003,   9.525735404502132E-001],
[   5.015544339960937E-006,  -1.883797077484825E-004,   4.124899609689345E-003,   9.568921520944887E-001],
[   4.674128719928321E-006,  -1.733330747286738E-004,   3.763186827212263E-003,   9.608336875407694E-001],
[   4.494798711051811E-006,  -1.593106885688148E-004,   3.430543063914848E-003,   9.644282154219730E-001],
[   3.649339776621166E-006,  -1.458262924357518E-004,   3.125406082910355E-003,   9.677039425960300E-001],
[   5.409789797166778E-006,  -1.348782731057403E-004,   2.844701517368937E-003,   9.706871717262813E-001],
[  -2.551206338426709E-006,  -1.186489037142585E-004,   2.591174340549013E-003,   9.734024047603417E-001],
[   2.582656449805843E-005,  -1.263025227295386E-004,   2.346222914105289E-003,   9.758723789908382E-001],
[  -8.130791207397560E-005,  -4.882282923536334E-005,   2.171097562140461E-003,   9.781181259467120E-001],
[   3.173111740993588E-004,  -2.927465654571421E-004,   1.829528167448030E-003,   9.801590927675430E-001]
];

(* cubic interpolation coefficients for logistic function sampled at 10*downsampled integer locations -4.1..-3.8; -4.0..-3.7; etc *)
SinCoeff=
[
[  -1.665283653937782E-004,   1.619075292497222E-017,   9.999988504083842E-002,   0.000000000000000E+000],
[  -1.648601021151343E-004,  -4.995850961813116E-004,   9.950029994465710E-002,   9.983335667544464E-002],
[  -1.615593275805424E-004,  -9.941654025267146E-004,   9.800654944594906E-002,   1.986692114218053E-001],
[  -1.566253246156101E-004,  -1.478843385268341E-003,   9.553354065815401E-002,   2.955200361376471E-001],
[  -1.501231544182072E-004,  -1.948719359115153E-003,   9.210597791377052E-002,   3.894181080859172E-001],
[  -1.421788982067450E-004,  -2.399088822369775E-003,   8.775816973228560E-002,   4.794252434861544E-001],
[  -1.326938122204068E-004,  -2.825625516989918E-003,   8.253345539292590E-002,   5.646421454978635E-001],
[  -1.220399053047572E-004,  -3.223706953651138E-003,   7.648412292228485E-002,   6.442172815615791E-001],
[  -1.100076366472153E-004,  -3.589826669565466E-003,   6.967058929906831E-002,   7.173556576249080E-001],
[  -9.700926126248078E-005,  -3.919849579506964E-003,   6.216091304999596E-002,   7.833264126177637E-001],
[  -8.295329181424771E-005,  -4.210877363294444E-003,   5.403018610719463E-002,   8.414704668269902E-001],
[  -6.812703127087153E-005,  -4.459737238737260E-003,   4.535957150516300E-002,   8.912068222790761E-001],
[  -5.254758732834451E-005,  -4.664118332549986E-003,   3.623571593387582E-002,   9.320385295142310E-001],
[  -3.653561367740426E-005,  -4.821761094535019E-003,   2.674983650679090E-002,   9.635575795282284E-001],
[  -2.008628784728054E-005,  -4.931367935567139E-003,   1.699670747668874E-002,   9.854491193268071E-001],
[  -3.471481149323637E-006,  -4.991626799108982E-003,   7.073712742012618E-003,   9.974943725800815E-001],
[   1.320337394641919E-005,  -5.002041242556934E-003,  -2.919955299653222E-003,   9.995729870418357E-001],
[   2.970715463538184E-005,  -4.962431120717602E-003,  -1.288442766292768E-002,   9.916641938735720E-001],
[   4.594873780434698E-005,  -4.873309656811475E-003,  -2.272016844045676E-002,   9.738470422445620E-001],
[   6.175919209261672E-005,  -4.735463443398582E-003,  -3.232894154066681E-002,   9.462995128850984E-001],
[   7.679305758371415E-005,  -4.550185867120768E-003,  -4.161459085118617E-002,   9.092968670931254E-001],
[   9.138474945416414E-005,  -4.319806694369626E-003,  -5.048458341267657E-002,   8.632088834324023E-001],
[   1.046018407110947E-004,  -4.045652446006986E-003,  -5.885004255305325E-002,   8.084958780748103E-001],
[   1.172983660427624E-004,  -3.731846923873849E-003,  -6.662754192293416E-002,   7.457047849164611E-001],
[   1.283737674717755E-004,  -3.379951825745599E-003,  -7.373934067255361E-002,   6.754626944356960E-001],
[   1.383140556787468E-004,  -2.994830523330346E-003,  -8.011412302162955E-002,   5.984717757048685E-001],
[   1.471680857854612E-004,  -2.579888356294060E-003,  -8.568884190125396E-002,   5.155011362155873E-001],
[   1.539132888310192E-004,  -2.138384098937639E-003,  -9.040711435648566E-002,   4.273795740438246E-001],
[   1.598873855855267E-004,  -1.676644232444596E-003,  -9.422214268786785E-002,   3.349879888772324E-001],
[   1.635829203750848E-004,  -1.196982075688053E-003,  -9.709576899600046E-002,   2.392490893425055E-001],
[   1.660286321660509E-004,  -7.062333145628085E-004,  -9.899898438625133E-002,   1.411199211911920E-001],
[   1.666253175811150E-004,  -2.081474180646835E-004,  -9.991336511887881E-002,   4.158073212254391E-002],
[   1.666606107140421E-004,   2.917285346786569E-004,  -9.982978400226484E-002,  -5.837415509681848E-002],
[   1.591477622087279E-004,   7.917103668207742E-004,  -9.874634510076540E-002,  -1.577455499536906E-001],
[   1.743525930766413E-004,   1.269153653446985E-003,  -9.668548108049765E-002,  -2.555410369254265E-001],
[   9.483094826922976E-005,   1.792211432676872E-003,  -9.362411599437379E-002,  -3.507830117594006E-001],
[   3.627261796276146E-004,   2.076704277484562E-003,  -8.975520028421236E-002,  -4.425200853728283E-001],
[  -6.728910136418521E-004,   3.164882816367332E-003,  -8.451361319036045E-002,  -5.298358551999285E-001],
[   3.147982361891480E-003,   1.146209775441702E-003,  -8.020252059855142E-002,  -6.118574765875636E-001],
[  -1.116022729640390E-002,   1.059015686111621E-002,  -6.846615396199357E-002,  -6.877658050487819E-001]];

TYPE Datatype=FLOAT32;

PROCEDURE Dummy (a:FLOAT32; CONST coeffs: ARRAY [4] OF FLOAT32):FLOAT32;
BEGIN
	RETURN a
END Dummy;

PROCEDURE EvalSpline (a:FLOAT32; CONST coeffs: ARRAY [4] OF FLOAT32):FLOAT32; (* problem with result when inlining in Do2, but would significantly speed up things*)
CONST ones=[1.0, 1.0, 1.0, 1.0];
BEGIN
    CODE
      SHUFPS r2, r1, 00H		; [a,a,1,1]
      SHUFPS r3, r2, 0C0H		; [a,a,a,1]
      MULPS r3, r2				; [a2,a2,a,1]
      SHUFPS r2, r1, 00CH		; [a,1,1,1]
      MULPS r3,r2				; [a3,a2,a,1] polynomial
      MULPS r3,r4   			; inner product with coeffs
      HADDPS r3,r3
      HADDPS r3,r3
      WITH
	      IN
	          r1:= ones;
	          r2:=a;
	          r3:=a;
	          r4 := coeffs;
	      OUT
	          RETURN r3;
      END;
END EvalSpline;

PROCEDURE nil(x:FLOAT32):SIGNED32;
BEGIN
	RETURN 0
END nil;
(*
PROCEDURE -Truncate1(x:FLOAT32):SIGNED32; (*fast rounding - not working yet*)
CODE{SYSTEM.i386, SYSTEM.SSE3, SYSTEM.FPU}
	FISTTP [ESP+x]
	ADD ESP,4
END Truncate1;

(*fast float-to-int conversions: see "Fast Floating Point To Integer Conversions by Michael Stoner,Intel  2012, discussing FISTP, FISTTP, and CVTTSS2SI"*)
PROCEDURE -Truncate0(x:FLOAT32):SIGNED32; (*fast rounding towards zero*)
CODE{SYSTEM.i386, SYSTEM.SSE3, SYSTEM.FPU}
        CVTTSS2SI EAX, [ESP+x] ; convert single precision floating point to scalar DWORD
        ADD ESP, 4
END Truncate0;

PROCEDURE Truncate*(x:FLOAT32):SIGNED32;
BEGIN
	RETURN Truncate0(x)
END Truncate;

*)
(*
	PROCEDURE -fastExp(x:FLOAT64):FLOAT64; (*approximation, relatively fast, inline, see https://codingforspeed.com/using-faster-exponential-approximation/ *)
	BEGIN
		x:=1+ 1.0D0/1024 * x;
		x:=x*x; x:=x*x; x:=x*x; x:=x*x;
		x:=x*x; x:=x*x; x:=x*x; x:=x*x;
		x:=x*x;
		RETURN x*x
	END fastExp;
*)
	(*cubic B-spline approximation of tanh *)
PROCEDURE tanhFast* (t: Datatype): Datatype; (* somewhat faster than tanh(), less accurate *)
VAR sign:SIGNED32;
BEGIN
	CASE ENTIER(t) OF
	|-3: RETURN -EvalSpline(-t-2, InterpolTanhCoeff03[2])
	|-2: RETURN -EvalSpline(-t-1, InterpolTanhCoeff03[1])
	|-1: RETURN -EvalSpline(-t, InterpolTanhCoeff03[0])
	| 0: RETURN EvalSpline(t, InterpolTanhCoeff03[0])
	| 1: RETURN EvalSpline(t-1, InterpolTanhCoeff03[1])
	| 2: RETURN EvalSpline(t-2, InterpolTanhCoeff03[2])
	ELSE RETURN PMath.tanh(t)
	END;
END tanhFast;

	(*cubic B-spline approximation of tanh *)
PROCEDURE tanhFast1* (t: Datatype): Datatype; (* somewhat faster than tanh(), less accurate *)
VAR sign:SIGNED32; et:SIGNED32;
BEGIN
	IF ABS(t)<=1 THEN RETURN EvalSpline(0.5*(t+1), TanHCoeff21[1]);
	ELSIF ABS(t)>PMath.expNegligible THEN (* FLOAT32: 8.31776618958E+000  ; FLOAT64:  1.83684002848E+001*)
		IF t>0 THEN RETURN 1.0
		ELSE RETURN -1.0
		END;
	ELSE RETURN PMath.tanh(t)
	END;
END tanhFast1;

PROCEDURE tanh* (x: Datatype): Datatype; (* 60% less time than PMath.tanh*)
VAR t:Datatype;
BEGIN
	t:=10*x;
	CASE ENTIER(t) OF (*speedup by eliminating slow ENTIER. Truncate0 faster in loop, but not faster here. needs change in lookup indices because of truncation towards zero*)
	|-40: RETURN -EvalSpline(-t-39, TanhCoeff[39])
	|-39: RETURN -EvalSpline(-t-38, TanhCoeff[38])
	|-38: RETURN -EvalSpline(-t-37, TanhCoeff[37])
	|-37: RETURN -EvalSpline(-t-36, TanhCoeff[36])
	|-36: RETURN -EvalSpline(-t-35, TanhCoeff[35])
	|-35: RETURN -EvalSpline(-t-34, TanhCoeff[34])
	|-34: RETURN -EvalSpline(-t-33, TanhCoeff[33])
	|-33: RETURN -EvalSpline(-t-32, TanhCoeff[32])
	|-32: RETURN -EvalSpline(-t-31, TanhCoeff[31])
	|-31: RETURN -EvalSpline(-t-30, TanhCoeff[30])
	|-30: RETURN -EvalSpline(-t-29, TanhCoeff[29])
	|-29: RETURN -EvalSpline(-t-28, TanhCoeff[28])
	|-28: RETURN -EvalSpline(-t-27, TanhCoeff[27])
	|-27: RETURN -EvalSpline(-t-26, TanhCoeff[26])
	|-26: RETURN -EvalSpline(-t-25, TanhCoeff[25])
	|-25: RETURN -EvalSpline(-t-24, TanhCoeff[24])
	|-24: RETURN -EvalSpline(-t-23, TanhCoeff[23])
	|-23: RETURN -EvalSpline(-t-22, TanhCoeff[22])
	|-22: RETURN -EvalSpline(-t-21, TanhCoeff[21])
	|-21: RETURN -EvalSpline(-t-20, TanhCoeff[20])
	|-20: RETURN -EvalSpline(-t-19, TanhCoeff[19])
	|-19: RETURN -EvalSpline(-t-18, TanhCoeff[18])
	|-18: RETURN -EvalSpline(-t-17, TanhCoeff[17])
	|-17: RETURN -EvalSpline(-t-16, TanhCoeff[16])
	|-16: RETURN -EvalSpline(-t-15, TanhCoeff[15])
	|-15: RETURN -EvalSpline(-t-14, TanhCoeff[14])
	|-14: RETURN -EvalSpline(-t-13, TanhCoeff[13])
	|-13: RETURN -EvalSpline(-t-12, TanhCoeff[12])
	|-12: RETURN -EvalSpline(-t-11, TanhCoeff[11])
	|-11: RETURN -EvalSpline(-t-10, TanhCoeff[10])
	|-10: RETURN -EvalSpline(-t-9, TanhCoeff[9])
	|-9: RETURN -EvalSpline(-t-8, TanhCoeff[8])
	|-8: RETURN -EvalSpline(-t-7, TanhCoeff[7])
	|-7: RETURN -EvalSpline(-t-6, TanhCoeff[6])
	|-6: RETURN -EvalSpline(-t-5, TanhCoeff[5])
	|-5: RETURN -EvalSpline(-t-4, TanhCoeff[4])
	|-4: RETURN -EvalSpline(-t-3, TanhCoeff[3])
	|-3: RETURN -EvalSpline(-t-2, TanhCoeff[2])
	|-2: RETURN -EvalSpline(-t-1, TanhCoeff[1])
	|-1: RETURN -EvalSpline(-t, TanhCoeff[0])
	| 0: RETURN EvalSpline(t, TanhCoeff[0])
	| 1: RETURN EvalSpline(t-1, TanhCoeff[1])
	| 2: RETURN EvalSpline(t-2, TanhCoeff[2])
	| 3: RETURN EvalSpline(t-3, TanhCoeff[3])
	| 4: RETURN EvalSpline(t-4, TanhCoeff[4])
	| 5: RETURN EvalSpline(t-5, TanhCoeff[5])
	| 6: RETURN EvalSpline(t-6, TanhCoeff[6])
	| 7: RETURN EvalSpline(t-7, TanhCoeff[7])
	| 8: RETURN EvalSpline(t-8, TanhCoeff[8])
	| 9: RETURN EvalSpline(t-9, TanhCoeff[9])
	| 10: RETURN EvalSpline(t-10, TanhCoeff[10])
	| 11: RETURN EvalSpline(t-11, TanhCoeff[11])
	| 12: RETURN EvalSpline(t-12, TanhCoeff[12])
	| 13: RETURN EvalSpline(t-13, TanhCoeff[13])
	| 14: RETURN EvalSpline(t-14, TanhCoeff[14])
	| 15: RETURN EvalSpline(t-15, TanhCoeff[15])
	| 16: RETURN EvalSpline(t-16, TanhCoeff[16])
	| 17: RETURN EvalSpline(t-17, TanhCoeff[17])
	| 18: RETURN EvalSpline(t-18, TanhCoeff[18])
	| 19: RETURN EvalSpline(t-19, TanhCoeff[19])
	| 20: RETURN EvalSpline(t-20, TanhCoeff[20])
	| 21: RETURN EvalSpline(t-21, TanhCoeff[21])
	| 22: RETURN EvalSpline(t-22, TanhCoeff[22])
	| 23: RETURN EvalSpline(t-23, TanhCoeff[23])
	| 24: RETURN EvalSpline(t-24, TanhCoeff[24])
	| 25: RETURN EvalSpline(t-25, TanhCoeff[25])
	| 26: RETURN EvalSpline(t-26, TanhCoeff[26])
	| 27: RETURN EvalSpline(t-27, TanhCoeff[27])
	| 28: RETURN EvalSpline(t-28, TanhCoeff[28])
	| 29: RETURN EvalSpline(t-29, TanhCoeff[29])
	| 30: RETURN EvalSpline(t-30, TanhCoeff[30])
	| 31: RETURN EvalSpline(t-31, TanhCoeff[31])
	| 32: RETURN EvalSpline(t-32, TanhCoeff[32])
	| 33: RETURN EvalSpline(t-33, TanhCoeff[33])
	| 34: RETURN EvalSpline(t-34, TanhCoeff[34])
	| 35: RETURN EvalSpline(t-35, TanhCoeff[35])
	| 36: RETURN EvalSpline(t-36, TanhCoeff[36])
	| 37: RETURN EvalSpline(t-37, TanhCoeff[37])
	| 38: RETURN EvalSpline(t-38, TanhCoeff[38])
	| 39: RETURN EvalSpline(t-39, TanhCoeff[39])
	ELSE RETURN PMath.tanh(x)
	END;
END tanh;

(*
PROCEDURE tanh1 (x: Datatype): Datatype; (* somewhat slower than tanh() *)
VAR t:Datatype; i:SIGNED32;
BEGIN
	t:=10*x;
	i:=ABS(Truncate0(t));
	IF i>39 THEN RETURN PMath.tanh(x)
	ELSIF t>=0 THEN RETURN EvalSpline(t-i, TanhCoeff[i])
	ELSE RETURN -EvalSpline(-t-i, TanhCoeff[i])
	END;
END tanh1;
*)
PROCEDURE logisticL*(x:FLOAT64):FLOAT64; (*! improve - remove double function call*)
BEGIN
	RETURN logistic0(SHORT(x))
END logisticL;

PROCEDURE logistic* (x: Datatype): Datatype;
BEGIN
	RETURN logistic0(x)
END logistic;

PROCEDURE logistic0 (x: Datatype): Datatype; (* 60% less time than PMath.tanh*) (*inlining leads to changed result for parameters<-4, >4 for unknown reasons*)
VAR t:Datatype;
BEGIN
	t:=10*x;
	CASE ENTIER(t) OF (*speedup by eliminating slow ENTIER. Truncate0 faster in loop, but not faster here. needs change in lookup indices because of truncation towards zero*)
	|-40: RETURN 1-EvalSpline(-t-39, LogisticCoeff[39])
	|-39: RETURN 1-EvalSpline(-t-38, LogisticCoeff[38])
	|-38: RETURN 1-EvalSpline(-t-37, LogisticCoeff[37])
	|-37: RETURN 1-EvalSpline(-t-36, LogisticCoeff[36])
	|-36: RETURN 1-EvalSpline(-t-35, LogisticCoeff[35])
	|-35: RETURN 1-EvalSpline(-t-34, LogisticCoeff[34])
	|-34: RETURN 1-EvalSpline(-t-33, LogisticCoeff[33])
	|-33: RETURN 1-EvalSpline(-t-32, LogisticCoeff[32])
	|-32: RETURN 1-EvalSpline(-t-31, LogisticCoeff[31])
	|-31: RETURN 1-EvalSpline(-t-30, LogisticCoeff[30])
	|-30: RETURN 1-EvalSpline(-t-29, LogisticCoeff[29])
	|-29: RETURN 1-EvalSpline(-t-28, LogisticCoeff[28])
	|-28: RETURN 1-EvalSpline(-t-27, LogisticCoeff[27])
	|-27: RETURN 1-EvalSpline(-t-26, LogisticCoeff[26])
	|-26: RETURN 1-EvalSpline(-t-25, LogisticCoeff[25])
	|-25: RETURN 1-EvalSpline(-t-24, LogisticCoeff[24])
	|-24: RETURN 1-EvalSpline(-t-23, LogisticCoeff[23])
	|-23: RETURN 1-EvalSpline(-t-22, LogisticCoeff[22])
	|-22: RETURN 1-EvalSpline(-t-21, LogisticCoeff[21])
	|-21: RETURN 1-EvalSpline(-t-20, LogisticCoeff[20])
	|-20: RETURN 1-EvalSpline(-t-19, LogisticCoeff[19])
	|-19: RETURN 1-EvalSpline(-t-18, LogisticCoeff[18])
	|-18: RETURN 1-EvalSpline(-t-17, LogisticCoeff[17])
	|-17: RETURN 1-EvalSpline(-t-16, LogisticCoeff[16])
	|-16: RETURN 1-EvalSpline(-t-15, LogisticCoeff[15])
	|-15: RETURN 1-EvalSpline(-t-14, LogisticCoeff[14])
	|-14: RETURN 1-EvalSpline(-t-13, LogisticCoeff[13])
	|-13: RETURN 1-EvalSpline(-t-12, LogisticCoeff[12])
	|-12: RETURN 1-EvalSpline(-t-11, LogisticCoeff[11])
	|-11: RETURN 1-EvalSpline(-t-10, LogisticCoeff[10])
	|-10: RETURN 1-EvalSpline(-t-9, LogisticCoeff[9])
	|-9: RETURN 1-EvalSpline(-t-8, LogisticCoeff[8])
	|-8: RETURN 1-EvalSpline(-t-7, LogisticCoeff[7])
	|-7: RETURN 1-EvalSpline(-t-6, LogisticCoeff[6])
	|-6: RETURN 1-EvalSpline(-t-5, LogisticCoeff[5])
	|-5: RETURN 1-EvalSpline(-t-4, LogisticCoeff[4])
	|-4: RETURN 1-EvalSpline(-t-3, LogisticCoeff[3])
	|-3: RETURN 1-EvalSpline(-t-2, LogisticCoeff[2])
	|-2: RETURN 1-EvalSpline(-t-1, LogisticCoeff[1])
	|-1: RETURN 1-EvalSpline(-t, LogisticCoeff[0])
	| 0: RETURN EvalSpline(t, LogisticCoeff[0])
	| 1: RETURN EvalSpline(t-1, LogisticCoeff[1])
	| 2: RETURN EvalSpline(t-2, LogisticCoeff[2])
	| 3: RETURN EvalSpline(t-3, LogisticCoeff[3])
	| 4: RETURN EvalSpline(t-4, LogisticCoeff[4])
	| 5: RETURN EvalSpline(t-5, LogisticCoeff[5])
	| 6: RETURN EvalSpline(t-6, LogisticCoeff[6])
	| 7: RETURN EvalSpline(t-7, LogisticCoeff[7])
	| 8: RETURN EvalSpline(t-8, LogisticCoeff[8])
	| 9: RETURN EvalSpline(t-9, LogisticCoeff[9])
	| 10: RETURN EvalSpline(t-10, LogisticCoeff[10])
	| 11: RETURN EvalSpline(t-11, LogisticCoeff[11])
	| 12: RETURN EvalSpline(t-12, LogisticCoeff[12])
	| 13: RETURN EvalSpline(t-13, LogisticCoeff[13])
	| 14: RETURN EvalSpline(t-14, LogisticCoeff[14])
	| 15: RETURN EvalSpline(t-15, LogisticCoeff[15])
	| 16: RETURN EvalSpline(t-16, LogisticCoeff[16])
	| 17: RETURN EvalSpline(t-17, LogisticCoeff[17])
	| 18: RETURN EvalSpline(t-18, LogisticCoeff[18])
	| 19: RETURN EvalSpline(t-19, LogisticCoeff[19])
	| 20: RETURN EvalSpline(t-20, LogisticCoeff[20])
	| 21: RETURN EvalSpline(t-21, LogisticCoeff[21])
	| 22: RETURN EvalSpline(t-22, LogisticCoeff[22])
	| 23: RETURN EvalSpline(t-23, LogisticCoeff[23])
	| 24: RETURN EvalSpline(t-24, LogisticCoeff[24])
	| 25: RETURN EvalSpline(t-25, LogisticCoeff[25])
	| 26: RETURN EvalSpline(t-26, LogisticCoeff[26])
	| 27: RETURN EvalSpline(t-27, LogisticCoeff[27])
	| 28: RETURN EvalSpline(t-28, LogisticCoeff[28])
	| 29: RETURN EvalSpline(t-29, LogisticCoeff[29])
	| 30: RETURN EvalSpline(t-30, LogisticCoeff[30])
	| 31: RETURN EvalSpline(t-31, LogisticCoeff[31])
	| 32: RETURN EvalSpline(t-32, LogisticCoeff[32])
	| 33: RETURN EvalSpline(t-33, LogisticCoeff[33])
	| 34: RETURN EvalSpline(t-34, LogisticCoeff[34])
	| 35: RETURN EvalSpline(t-35, LogisticCoeff[35])
	| 36: RETURN EvalSpline(t-36, LogisticCoeff[36])
	| 37: RETURN EvalSpline(t-37, LogisticCoeff[37])
	| 38: RETURN EvalSpline(t-38, LogisticCoeff[38])
	| 39: RETURN EvalSpline(t-39, LogisticCoeff[39])
	ELSE RETURN PMath.logistic(x)
	END;
END logistic0;


PROCEDURE sin0 (x: Datatype): Datatype; (*somewhat faster when inlined, but then may trap??*)(*if noninlined, ~30% faster than Math.sin() *)
VAR t:Datatype; i:SIGNED32;
BEGIN
	IF (x>Math.pi) THEN
		i := ENTIER( x * invPi );
		x:=x- i*Math.pi;
		IF ODD(i) THEN x:=-x END;
	ELSIF (x<-Math.pi) THEN
		i := ENTIER( -x * invPi );
		x:=x+ i*Math.pi;
		IF ODD(i) THEN x:=-x END;
	END;
	t:=10*x;
	CASE ENTIER(t) OF (*speed up by eliminating ENTIER*)
	|-40: RETURN -EvalSpline(-t-39, SinCoeff[39])
	|-39: RETURN -EvalSpline(-t-38, SinCoeff[38])
	|-38: RETURN -EvalSpline(-t-37, SinCoeff[37])
	|-37: RETURN -EvalSpline(-t-36, SinCoeff[36])
	|-36: RETURN -EvalSpline(-t-35, SinCoeff[35])
	|-35: RETURN -EvalSpline(-t-34, SinCoeff[34])
	|-34: RETURN -EvalSpline(-t-33, SinCoeff[33])
	|-33: RETURN -EvalSpline(-t-32, SinCoeff[32])
	|-32: RETURN -EvalSpline(-t-31, SinCoeff[31])
	|-31: RETURN -EvalSpline(-t-30, SinCoeff[30])
	|-30: RETURN -EvalSpline(-t-29, SinCoeff[29])
	|-29: RETURN -EvalSpline(-t-28, SinCoeff[28])
	|-28: RETURN -EvalSpline(-t-27, SinCoeff[27])
	|-27: RETURN -EvalSpline(-t-26, SinCoeff[26])
	|-26: RETURN -EvalSpline(-t-25, SinCoeff[25])
	|-25: RETURN -EvalSpline(-t-24, SinCoeff[24])
	|-24: RETURN -EvalSpline(-t-23, SinCoeff[23])
	|-23: RETURN -EvalSpline(-t-22, SinCoeff[22])
	|-22: RETURN -EvalSpline(-t-21, SinCoeff[21])
	|-21: RETURN -EvalSpline(-t-20, SinCoeff[20])
	|-20: RETURN -EvalSpline(-t-19, SinCoeff[19])
	|-19: RETURN -EvalSpline(-t-18, SinCoeff[18])
	|-18: RETURN -EvalSpline(-t-17, SinCoeff[17])
	|-17: RETURN -EvalSpline(-t-16, SinCoeff[16])
	|-16: RETURN -EvalSpline(-t-15, SinCoeff[15])
	|-15: RETURN -EvalSpline(-t-14, SinCoeff[14])
	|-14: RETURN -EvalSpline(-t-13, SinCoeff[13])
	|-13: RETURN -EvalSpline(-t-12, SinCoeff[12])
	|-12: RETURN -EvalSpline(-t-11, SinCoeff[11])
	|-11: RETURN -EvalSpline(-t-10, SinCoeff[10])
	|-10: RETURN -EvalSpline(-t-9, SinCoeff[9])
	|-9: RETURN -EvalSpline(-t-8, SinCoeff[8])
	|-8: RETURN -EvalSpline(-t-7, SinCoeff[7])
	|-7: RETURN -EvalSpline(-t-6, SinCoeff[6])
	|-6: RETURN -EvalSpline(-t-5, SinCoeff[5])
	|-5: RETURN -EvalSpline(-t-4, SinCoeff[4])
	|-4: RETURN -EvalSpline(-t-3, SinCoeff[3])
	|-3: RETURN -EvalSpline(-t-2, SinCoeff[2])
	|-2: RETURN -EvalSpline(-t-1, SinCoeff[1])
	|-1: RETURN -EvalSpline(-t, SinCoeff[0])
	| 0: RETURN EvalSpline(t, SinCoeff[0])
	| 1: RETURN EvalSpline(t-1, SinCoeff[1])
	| 2: RETURN EvalSpline(t-2, SinCoeff[2])
	| 3: RETURN EvalSpline(t-3, SinCoeff[3])
	| 4: RETURN EvalSpline(t-4, SinCoeff[4])
	| 5: RETURN EvalSpline(t-5, SinCoeff[5])
	| 6: RETURN EvalSpline(t-6, SinCoeff[6])
	| 7: RETURN EvalSpline(t-7, SinCoeff[7])
	| 8: RETURN EvalSpline(t-8, SinCoeff[8])
	| 9: RETURN EvalSpline(t-9, SinCoeff[9])
	| 10: RETURN EvalSpline(t-10, SinCoeff[10])
	| 11: RETURN EvalSpline(t-11, SinCoeff[11])
	| 12: RETURN EvalSpline(t-12, SinCoeff[12])
	| 13: RETURN EvalSpline(t-13, SinCoeff[13])
	| 14: RETURN EvalSpline(t-14, SinCoeff[14])
	| 15: RETURN EvalSpline(t-15, SinCoeff[15])
	| 16: RETURN EvalSpline(t-16, SinCoeff[16])
	| 17: RETURN EvalSpline(t-17, SinCoeff[17])
	| 18: RETURN EvalSpline(t-18, SinCoeff[18])
	| 19: RETURN EvalSpline(t-19, SinCoeff[19])
	| 20: RETURN EvalSpline(t-20, SinCoeff[20])
	| 21: RETURN EvalSpline(t-21, SinCoeff[21])
	| 22: RETURN EvalSpline(t-22, SinCoeff[22])
	| 23: RETURN EvalSpline(t-23, SinCoeff[23])
	| 24: RETURN EvalSpline(t-24, SinCoeff[24])
	| 25: RETURN EvalSpline(t-25, SinCoeff[25])
	| 26: RETURN EvalSpline(t-26, SinCoeff[26])
	| 27: RETURN EvalSpline(t-27, SinCoeff[27])
	| 28: RETURN EvalSpline(t-28, SinCoeff[28])
	| 29: RETURN EvalSpline(t-29, SinCoeff[29])
	| 30: RETURN EvalSpline(t-30, SinCoeff[30])
	| 31: RETURN EvalSpline(t-31, SinCoeff[31])
	| 32: RETURN EvalSpline(t-32, SinCoeff[32])
	| 33: RETURN EvalSpline(t-33, SinCoeff[33])
	| 34: RETURN EvalSpline(t-34, SinCoeff[34])
	| 35: RETURN EvalSpline(t-35, SinCoeff[35])
	| 36: RETURN EvalSpline(t-36, SinCoeff[36])
	| 37: RETURN EvalSpline(t-37, SinCoeff[37])
	| 38: RETURN EvalSpline(t-38, SinCoeff[38])
	| 39: RETURN EvalSpline(t-39, SinCoeff[39])
	END;
END sin0;

PROCEDURE sin* (x: Datatype): Datatype;
BEGIN
	RETURN sin0(x);
END sin;

PROCEDURE cos*(x: Datatype): Datatype; (*~15%faster than Math.cos(). could be 15 % accelerated when directly implemented like sin() *)
BEGIN
	RETURN sin0(x+halfPi)
END cos;



PROCEDURE fastExp(x:FLOAT32):FLOAT32; (*  approximation. decreasingly accurate for increasing x, and only faster than standard if inlined,  see https://codingforspeed.com/using-faster-exponential-approximation/ *)
	BEGIN
		IF x<2 THEN
			x:=1+ 1.0E0/1024 * x; (*/1024/1024;  *) (*will increase accuracy for higher x *)
			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x;
			(*
			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x;

			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x; x:=x*x; x:=x*x;
			x:=x*x; x:=x*x;
			*)
			RETURN x
		ELSE
			RETURN Math.exp(x)
		END;
	END fastExp;


PROCEDURE -fastExp2(x:FLOAT64):FLOAT64; (*  approximation. decreasingly accurate for increasing x, and only faster than standard if inlined,  see https://codingforspeed.com/using-faster-exponential-approximation/ *)
CONST onePlus=1.0/1024; one=1.0;
BEGIN
    CODE
    		MULSS r1,r2
    		ADDPS r1,r3
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
      WITH
	      IN
	          r1:=onePlus;
	          r2:=x;
	          r3:=one;
	      OUT
	          RETURN r1;
      END;
	END fastExp2;

	PROCEDURE -scaledELU*(x:FLOAT64):FLOAT64;
	CONST alpha=1.67326324235; lambda=1.050700987;
			onePlus=1.0/1024; one=1.0;
	BEGIN
	CODE
    		MULSS r1,r2
    		ADDPS r1,r3
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1
    		MULSS r1,r1

    		SUBSS r1,r2
    		MULSS r1,r4
    		MULSS r1,r5

      WITH
	      IN
	          r1:=onePlus;
	          r2:=x;
	          r3:=one;
	          r4:=alpha;
	          r5:=lambda;
	      OUT
	          RETURN r1;
      END;
	END scaledELU;

	PROCEDURE ScaledELU*(x:FLOAT64):FLOAT64;
	CONST lambda=1.050700987;
	BEGIN
		IF x>0 THEN RETURN lambda*x
		ELSE RETURN scaledELU(x)
		END;
	END ScaledELU;
	(*
	CONST alpha=1.67326324235; lambda=1.050700987; (*constants valid for data with mean=0 and variance=1, see Klambauer, 2017, appendix *)
BEGIN
	IF x>0 THEN RETURN lambda * x
	ELSE
		(*RETURN lambda * (alpha*Mathe.exp(x)-alpha)*)
		RETURN lambda * (alpha*PMathSSE.fastExp2(x)-alpha)
*)
(*(*
fast ENTIER:
Well this is great and all but what can we do using non-SSE4.1 instructions? You can always use the standard C math.h floor(), ceil() and your own flavor of round() but if you want to do some intensive and fast vector math in your game, SSE is your savior. If you do a search on Google, something like sse floor, youll probably get a lot of wrong algorithms. Most of them wont work for negative integer values, flooring -10 to -11 for instance. So I took some time to figure out an algorithm using only SSE3 instructions.
inline __m128 _mm_floor_ps2(const __m128& x){
    __m128i v0 = _mm_setzero_si128();
    __m128i v1 = _mm_cmpeq_epi32(v0,v0);
    __m128i ji = _mm_srli_epi32( v1, 25);
    __m128 j = *(__m128*)&_mm_slli_epi32( ji, 23); //create vector 1.0f
    __m128i i = _mm_cvttps_epi32(x);
    __m128 fi = _mm_cvtepi32_ps(i);
    __m128 igx = _mm_cmpgt_ps(fi, x);
    j = _mm_and_ps(igx, j);
    return _mm_sub_ps(fi, j);
*)

PROCEDURE Do*(context:Commands.Context);
VAR i,j,k, t0,t1,t2,t3,t4,t5: SIGNED32; x,y:FLOAT32;
BEGIN
	IF context.arg.GetInteger(i,FALSE) THEN END;

	t0:=Kernel.GetTicks();
	FOR j:=1 TO i-1 DO	y:=nil(0) END;
	t1:=Kernel.GetTicks();

	FOR j:=1 TO i-1 DO	(*k:=ENTIER(x);*)  y:=tanh(0)	END;
	t2:=Kernel.GetTicks();

	FOR j:=1 TO i-1 DO	(*k:=Truncate(x);*)  y:=PMath.tanh(0) END;
	t3:=Kernel.GetTicks();

	FOR j:=1 TO i-1 DO	(*k:=Truncate0(x);*)  y:=tanhFast(0) END;
	t4:=Kernel.GetTicks();

	FOR j:=1 TO i-1 DO	(*k:=Truncate1(x);*) y:=EvalSpline(0, TanhCoeff[0])  END;
	t5:=Kernel.GetTicks();

	FOR i:=-10 TO 10 DO
		(*context.out.Float(i/2,14); context.out.Float(PMath.logistic(i/2),24); context.out.Float(logistic(i/2),24);context.out.Float(logistic(i/2)-PMath.logistic(i/2),24);   context.out.Ln;	*)
		context.out.Float(i/2,14); context.out.Float(tanh(i/2),24); context.out.Float(PMath.tanh(i/2),24);context.out.Float(tanhFast(i/2),24);context.out.Float(tanhFast(i/2)-PMath.tanh(i/2),24); context.out.Float(tanh(i/2)-PMath.tanh(i/2),24);   context.out.Ln;

	END;

	context.out.Int(t1-t0,6);
	context.out.Int(t2-t1,6);
	context.out.Int(t3-t2,6);
	context.out.Int(t4-t3,6);
	context.out.Int(t5-t4,6);
	context.out.Update;
END Do;

PROCEDURE Do2*(context:Commands.Context);
VAR i,j,t0,t1,t2,t3,t4: SIGNED32; x,y:FLOAT32;
BEGIN
	FOR i:=-10 TO 10 DO
		x:=i/2;
		(*context.out.Float(PMath.tanh(x),24);
		x:=0.5+x/2;
		context.out.Float(EvalSpline(x, TanHCoeff21[1]), 24);*)

		context.out.Float(PMath.logisticL(x),24);
		context.out.Float(logistic(x),24);
		context.out.Float(PMath.logisticL(x) -logistic(x),24);
		context.out.Ln;
	END;
	(*i:=Truncate(2.5);*)
	i:=2;
	context.out.Int(i,10); context.out.Ln;
	IF context.arg.GetInteger(i,FALSE) THEN END;
	t0:=Kernel.GetTicks();
	WHILE i>0 DO
		(*y:=Dummy(x,TanHCoeff21[1]);*)
		(*y:=ENTIER(x);*) (* a single call to ENTIER is 1/4 of the runtime of this loop, including EvalSpline !*)
		(*y:=Truncate(x);*)
		(*y:=EvalSpline(0.5*(x+1), TanHCoeff21[1]);*)
		y:=logistic(x);
		(*y:=1-y*y;*)
		DEC(i);
	END;

	t1:=Kernel.GetTicks();
	context.out.Int(t1-t0,0); context.out.Ln;
	context.out.Update;
END Do2;

PROCEDURE Do3(x:FLOAT32);
VAR y:SIGNED32;
BEGIN
	y:=ENTIER(x)
END Do3;

PROCEDURE Do4*(context:Commands.Context);
VAR i:SIGNED32;
BEGIN
	context.out.Float(PMath.expNegligible,20);
	context.out.Float(PMath.expNegligibleL,20);
	context.out.Ln;
	FOR i:=-5 TO 5 DO
		context.out.Float(i/4,12);
		context.out.Float(ENTIER(i/4),12);
		(*
		context.out.Float(Truncate((i/4)),12);
		context.out.Float(Truncate0((i/4)),12);
		context.out.Float(Truncate1((i/4)),12);
		*)
		context.out.Ln;
	END;
END Do4;

PROCEDURE TestTanh*(context:Commands.Context);
VAR x:FLOAT64; i:SIGNED32;
BEGIN
	FOR i:=-200 TO 200-1 DO
		context.out.Float(tanh(i/20),20); context.out.Ln; context.out.Update;
	END;
END TestTanh;


END PMathSSE.

PMathSSE.Do  10000000~
PMathSSE.Do2 10000000~
PMathSSE.Do4~

PMathSSE.TestTanh ~

SystemTools.FreeDownTo PMathSSE ~
