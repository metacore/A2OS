MODULE LinearFilters ;	(**  AUTHOR "Patrick Hunziker"; PURPOSE "Filter construction for Spline and Moment Processing ";  **)
IMPORT Out:=KernelLog, math:=MathL;

CONST
		(*boundaries*)
		undefined* = -1;

		finite* = 0;
		cyclicH* = 1;
		cyclicW* = 2;
		anticyclicH* = 3;
		anticyclicW* = 4;
		mirrorH* = 5;
		mirrorW* = 6;
		antimirrorH* = 7;
		antimirrorW* = 8;

			(*sampling manner*)
	Even*=0;	(* ; keep even elements when downsampling; when upsampling, existing coeffs become even elements*)
	Odd*=1;


	sqrt2=1.41421356237309504880168872420969808;(* reconstruction factor in wavelet filters *)
    	sqrt15=3.87298334620741688517927;(* reconstruction factor in Coiflet wavelet filter *)


(** Wavelet  name*)
(** Orthogonal wavelet *)
     (** Even length*)
	Haar*=00;
	BattleLemarie*=01;
	Coiflet*=02;
    Daubechies8*=03;
(** Bi-orthogonal wavelets*)
     (** Odd length *)
    Daubechies97*=29;
    Lifting53=30; (*untested*)
    BurtAdelson*=31;
	quadraticspline*=32;
	spline97*=33;
	(** Even length *)
	cubicspline*=41;
	spline610*=42;
(** Shift Orthogonal wavelets *)
	(** Hybrid Shift Orthogonal Spline Wavelets, from Unser M, Shift-Orthogonal Wavelet Bases,
	  IEEE Trans Signal Proc  1998; 46:1827 and IEEE Sig Proc Letter 1996; 3: 85 *)
	 (**Even length*)
	HybridHaarLemarie*=61;
	ShiftOrthoQuadSpline*=62;
	(** Odd length *)
	ShiftOrthoCubicSpline*=71;


(**Spline names *)
	DirectBSpline0*=100;		(** B-Spline Filters of various degrees; shortest possible, symmetric, smooth, but not orthogonal *)
	DirectBSpline1*=101;		(** See also description in Unser et al: ... *)
	DirectBSpline2*=102;
	DirectBSpline3*=103;	(** cubic spline has special property of "minimal curvature" and is often a good compromise between
													smoothness and complexity *)
	DirectBSpline4*=104;
	DirectBSpline5*=105;
	DirectBSpline6*=106;
	DirectBSpline7*=107;

	InverseBSpline0*=110;
	InverseBSpline1*=111;
	InverseBSpline2*=112;
	InverseBSpline3*=113;
	InverseBSpline4*=114;
	InverseBSpline5*=115;
	InverseBSpline6*=116;
	InverseBSpline7*=117;

	(**centered splines: downsampled taps IN-BETWEEN the original sampling positions*)
	(**with these, feature location is better preserved in downsampled/upsampled versions*)
	DirectCenteredBSpline0*=120;
	InverseCenteredBSpline0*=130;
	InverseCenteredBSpline1*=131;
	InverseCenteredBSpline2*=132;

	(** Least square spline filters: *)
	(** Filtering and downsampling by 2 yields least-square spline approximation. Input: spline coefficients*)
	(** upsampling by 2 and filtering yields best approximation (least square) to original data *)
	LeastSquareSpline0Down2*=140;
	LeastSquareSpline1Down2*=141;
	LeastSquareSpline2Down2*=142;
	LeastSquareSpline3Down2*=143;
	LeastSquareSplineDown2*=143; (*same as LeastSquareSplineDown2*)
	LeastSquareSpline4Down2*=144;

	LeastSquareSpline0Up2*=150;
	LeastSquareSpline1Up2*=151;
	LeastSquareSpline2Up2*=152;
	LeastSquareSpline3Up2*=153;
	LeastSquareSplineUp2*=153;	(*same as LeastSquareSpline3Up2*)
	LeastSquareSpline4Up2*=154;


	(** Least spline filters: Centered versions: have downsampled taps IN_BETWEEN the coefficients - good to retain localisation of features*)
	(* here comes the asymmetric filter version(to be mirrored in convolve procedure)
	(**use of centered spline filters:
	reduce: convolve data with 'Down'-filter, then convolve data with Haar filter (0.5, 0.5), then downsample in the following manner:
			FOR kk:=0 TO LEN(in) DIV 2 -1 DO
				k := 2*kk;
				out[kk] := (tmp[k] + tmp[k+1])/2;
			END;
	expand: convolve data with 'Up'-filter, then convolve data with Haar [-x] filter  (0.5, 0.5),
	*)
	LeastSquareSplineCent0Down2*=160;
	LeastSquareSplineCent1Down2*=161;
	LeastSquareSplineCent2Down2*=162;
	LeastSquareSplineCent3Down2*=163;
	LeastSquareSplineCent4Down2*=164;

	LeastSquareSplineCent0Up2*=170;
	LeastSquareSplineCent1Up2*=171;
	LeastSquareSplineCent2Up2*=172;
	LeastSquareSplineCent3Up2*=173;
	LeastSquareSplineCent4Up2*=174;
*)
(** Least spline filters: Centered versions: have downsampled taps IN_BETWEEN the coefficients - good to retain localisation of features*)
	(**these filters are to be used with standard convolution procedures from LinearConvolve.Mod. They expect an array of spline coefficients *)
	LeastSquareSplineCentered0Down2*=220;
	LeastSquareSplineCentered1Down2*=221;
	LeastSquareSplineCentered2Down2*=222;
	LeastSquareSplineCentered3Down2*=223;
	LeastSquareSplineCentered4Down2*=224;

	LeastSquareSplineCentered0Up2*=230;
	LeastSquareSplineCentered1Up2*=231;
	LeastSquareSplineCentered2Up2*=232;
	LeastSquareSplineCentered3Up2*=233;
	LeastSquareSplineCentered4Up2*=234;


	(** cubic spline moment filters, see Michael Suehling et al, "Multiresolution Moment Filters", 2003; http:bigwww.epfl.ch *)
	(**  boundary conditions for moments:
		order p of mp(j+1)	boundary extension of mp(j+1) 		order k of mk(j)		boundary extension	p-k		filter symmetry of hpk
			even						mirror													even							mirror				even			symmetric
			even						mirror													odd							antimirror			odd			antisymmetric
			odd						antimirror												even							mirror				odd			antisymmetric
			odd						antimirror												odd							antimirror			even			symmetrix
	*)
	(**
		geometric meaning in 2D:
		X=m10/m00; Y:=m01/m00
		central moments
		mu20= m20-m00X2
		mu02= m02-m00Y2
		mu11= m11-m00XY
		inertia matrix
			J =   mu20  mu11
					mu11  mu02
		orientation of analysed object:
			corresponds to eigenvector corresponding to smallest eigenvalue of J ;
			can also be expressed as angle phi= 1/2 arctan (2*mu11/(mu20-mu02))
			object is mapped to ellipsoid centered at X, Y
		eccentricity of local ellipsoid
			e= ((lambda1-lambda2)/(lambda1+lambda2))2
			e= ((mu20-mu02)2+4 mu112)/(mu20+mu02)2
	 *)
	MomentCubic0*=200;	(** zero moment *)
	MomentCubic1*=201;	(** first moment *)
	MomentCubic2*=202;	(** second moment *)
	MomentCubicH0*=203;	(** transfer filters for binary moment tree*)
	MomentCubicH1*=204;
	MomentCubicH11*=205;
	MomentCubicH2*=206;
	MomentCubicH21*=207;	(** transfer filter for binary moment tree *)
	MomentCubicH22*=208; (** transfer filter for binary moment tree*)


	CubicSplineDifferentiator*=180; (** applied to cubic spline coefficients, convolution with this filter yields 1st derivative and mapping back to signal domain *)
	CubicSplineLaplacian*=181;(** applied to cubic spline coefficients, convolution with this filter yields 2nd derivative and mapping back to signal domain *)
	SplineDerivative*=182; (** Gradient operator on splines. Note that degree of spline is reduced by one when this filter is applied *)
	SplineLaplacian*=183; (** Laplacian=Second Derivative operator on splines; Note that degree of spline is reduced by two when this filter is applied '''*)
	CubicSplineDerivativeFromSignal*=184; (** applied to signal domain, implicitely transforms to cubic spline, determines derivative, and transforms back to signal domain *)
	SplineDerivativeApproximation*=185; (** similar to above, but takes into account only few coefficients. Apply to signal domain *)
	Smooth* = 300;

TYPE
		Datatype*=FLOAT64;
		Vector*= ARRAY [*] OF Datatype;
		Filter*= OBJECT
		END Filter;

		FIRFilter*= OBJECT (Filter)
			VAR
			coeff*: Vector;
			origin*:SIZE;
			PROCEDURE InitFIR*(CONST coeff:Vector; origin:SIZE); BEGIN SELF.coeff:=coeff; SELF.origin:=origin END InitFIR;
		END FIRFilter;

		IIRFilter*=OBJECT(Filter)
			VAR poles*: Vector;
			gain*: Datatype;
			PROCEDURE InitIIR*(CONST poles:Vector; gain:Datatype); BEGIN SELF.poles:=poles; SELF.gain:=gain END InitIIR;
		END IIRFilter;
(*
		Convolver*=OBJECT
			VAR temp: Vector;
			PROCEDURE &Init*(f:Filter);
			BEGIN
			END Init;

			PROCEDURE convolve*(VAR data:Vector; boundary: SIGNED32); (*phase preservation, selectable boundaries*)
			BEGIN
			END convolve;

			PROCEDURE convolveDown2;
			BEGIN
			END convolveDown2;

			PROCEDURE convolveUp2;
			BEGIN
			END convolveUp2;

			PROCEDURE convolveRaw; (*finite boundary conditions, no preservation of phase*)
			BEGIN
			END convolveRaw;

		END Convolver;

		(** wavelet filter family*)
		WaveletFamily*= OBJECT
			VAR loAnalysis*,
			hiAnalysis*,
			loReconstruct*,
			hiReconstruct*: FIRFilter;
			defaultBoundary*:SIGNED32;
			verifiedBoundaries*:SET
		END WaveletFamily;
*)
PROCEDURE CreateFIRFilter*(CONST coeff:Vector; origin:SIZE):FIRFilter;
VAR FIR:FIRFilter;
BEGIN
	NEW(FIR);
	FIR.coeff:=coeff;
	FIR.origin:=origin;
	RETURN FIR;
END CreateFIRFilter;

PROCEDURE CreateIIRFilter*(CONST poles:Vector; gain:Datatype):IIRFilter;
VAR IIR:IIRFilter;
BEGIN
	NEW(IIR); IIR.poles:=poles; IIR.gain:=gain;
	RETURN IIR;
END CreateIIRFilter;

PROCEDURE  CreateSplineFilter* (name: SIGNED32):Filter;
		(** Returns newly created spline filter; note that the result is of the basic type "Filter" and
			the user may want to check if this  IS FIRFilter or IS IIRFilter; the convolution method
			has to be chosen accordingly, and a type cast performed at procedure call of the convolution;
			e g:   IIRConvolvePeriodic(data,filter(IIRFilter));
			or: 	FIRConvolvePeriodic(data,filter(FIRFilter))
			*)
	VAR
	       i:SIZE;
	       FIR:FIRFilter;
	       IIR:IIRFilter;
	       mid:SIGNED32;
	       coeff, coeffB:Vector;
	BEGIN
		CASE name OF
			DirectBSpline0..DirectBSpline7,DirectCenteredBSpline0: NEW(IIR);
			ELSE NEW(FIR);
		END;
		CASE name OF
			| DirectBSpline0: IIR.poles:=[1]; IIR.gain:=1; RETURN IIR;
			| DirectBSpline1: IIR.poles:=[1]; IIR.gain:=1 ;RETURN IIR;
			| DirectBSpline2: NEW(IIR.poles,1); IIR.poles[0]:=2*math.sqrt(2)-3; IIR.gain:=24 - 16*sqrt2; RETURN IIR;
				(* calculation of gain??: gain:=1; FOR i:=0 TO LEN(IIR.poles^)-1 DO IIR.gain:=IIR.gain*(1-IIR.poles[i])*(1-1/IIR.poles[i])END; ??*)
			| DirectBSpline3: NEW(IIR.poles,1); IIR.poles[0]:=math.sqrt(3)-2; IIR.gain:=(24 - 16*sqrt2)*1.171291; RETURN IIR;
			| DirectBSpline4: IIR.poles:=[-0.361341, -0.0137254]; IIR.gain:=(1-IIR.poles[0])*(1-IIR.poles[1]) ; RETURN IIR;
			| DirectBSpline5: IIR.poles:=[-0.430575, 0.0430963]; IIR.gain:=(1-IIR.poles[0])*(1-IIR.poles[1]) ; RETURN IIR;
			| DirectBSpline6: IIR.poles:=[-0.48829458930304475513, -0.0816792710762375126, -0.0014141518083258177511];
					IIR.gain:=2.59897599934857781839 ; RETURN IIR;
			| DirectBSpline7: IIR.poles:=[-0.53528043079643816554, -0.1225546151923266905, -0.0091486948096082769286];
					IIR.gain:=3.02482820364418438868 ; RETURN IIR;
			| InverseBSpline0: FIR.coeff:=[1]; FIR.origin:=0 ; RETURN FIR;
			| InverseBSpline1: FIR.coeff:=[1]; FIR.origin:=0 ; RETURN FIR;
			| InverseBSpline2: FIR.coeff:=[1/8, 6/8, 1/8]; FIR.origin:=1; RETURN FIR;
			| InverseBSpline3: FIR.coeff:=[1/6, 4/6, 1/6]; FIR.origin:=1; RETURN FIR;
			| InverseBSpline4: FIR.coeff:=[1/384, 76/384, 230/384, 76/384, 1/384]; FIR.origin:=2; RETURN FIR;
			| InverseBSpline5: FIR.coeff:=[1/120, 26/120, 66/120, 26/120, 1/120]; FIR.origin:=2; RETURN FIR;
			| InverseBSpline6: FIR.coeff:=[1/46080, 722/46080, 10543/46080, 23548/46080, 10543/46080, 722/46080, 1/46080]; FIR.origin:=3; RETURN FIR;
			| InverseBSpline7: FIR.coeff:=[1/5040, 120/5040, 1191/5040, 2416/5040, 1191/5040, 120/5040, 1/5040]; FIR.origin:=3; RETURN FIR;
				(** Two-Scale Moment Filters hpk up to order p = 2 FOR cubic spline; Sühling M et al, Multiresolution Moment Filters 2003; http://bigwww.epfl.ch *)

			| InverseCenteredBSpline0:
				NEW(coeff,1); coeff[0]:=1;
				FIR:=CreateFIRFilter(coeff,0) ; RETURN FIR;
			| InverseCenteredBSpline1: NEW(coeff,2); coeff[0]:=1/2; coeff[1]:=1/2;
				FIR:=CreateFIRFilter(coeff,0) ; RETURN FIR;
			| InverseCenteredBSpline2: NEW(coeff,1); coeff[0]:=1/2; coeff[1]:=1/2;  (* is this correct ??*)
				FIR:=CreateFIRFilter(coeff,0) ; RETURN FIR;
			(*LeastSquareSplineDown: this is using FIR convolution. an alternative would be an iirconvolution, esp for higher ratio, described in M.Unser's paper"B-spline signal processing part II 1993"; there, only a few poles are necessary*)

			| LeastSquareSpline0Down2: 	(* zero order spline version*)
				NEW(coeff,1);(*least square spline downsampling coefficients; this includes both, the transform to the spline domain and the least square filter*) (* symmetric filter *)
					coeff[0]:=1;
				FIR:=CreateFIRFilter(coeff,0);
				RETURN FIR
			| LeastSquareSpline1Down2: 	(* first order spline version*)
				NEW(coeff,17);(*least square spline downsampling coefficients; this includes both, the transform to the spline domain and the least square filter*) (* symmetric filter *)
					coeff[8-0]:=0.617317; coeff[8-1]:=0.310754; coeff[8-2]:=-0.0949641; coeff[8-3]:=-0.0858654;
					coeff[8-4]:=0.0529153; coeff[8-5]:=0.0362437; coeff[8-6]:=-0.0240408; coeff[8-7]:=-0.0160987;
					coeff[8-8]:=0.0107498;
					(*mirror symmetric 2nd half*)
					coeff[8+1]:=coeff[8-1]; coeff[8+2]:=coeff[8-2]; coeff[8+3]:=coeff[8-3]; coeff[8+4]:=coeff[8-4];
					coeff[8+5]:=coeff[8-5]; coeff[8+6]:=coeff[8-6]; coeff[8+7]:=coeff[8-7]; coeff[8+8]:=coeff[8-8];
				FIR:=CreateFIRFilter(coeff,8);
				RETURN FIR
			| LeastSquareSpline2Down2: 	(* quadratic spline version*)
				NEW(coeff,31);(*least square spline downsampling coefficients; this includes both, the transform to the spline domain and the least square filter*) (* symmetric filter *)
					coeff[15-0]:=0.617317; coeff[15-1]:=0.310754; coeff[15-2]:=-0.0949641; coeff[15-3]:=-0.0858654; coeff[15-4]:=0.0529153; coeff[15-5]:=0.0362437;
					coeff[15-6]:=-0.0240408; coeff[15-7]:=-0.0160987; coeff[15-8]:=0.0107498; coeff[15-9]:=0.00718418; coeff[15-10]:=-0.00480004; coeff[15-11]:=-0.00320734;
					coeff[15-12]:=0.00214306; coeff[15-13]:=0.00143195; coeff[15-14]:=-0.0009568; coeff[15-15]:=-0.000639312;
					(*mirror symmetric 2nd half*)
					coeff[15+1]:=coeff[15-1]; coeff[15+2]:=coeff[15-2]; coeff[15+3]:=coeff[15-3]; coeff[15+4]:=coeff[15-4];
					coeff[15+5]:=coeff[15-5]; coeff[15+6]:=coeff[15-6]; coeff[15+7]:=coeff[15-7]; coeff[15+8]:=coeff[15-8];
					coeff[15+9]:=coeff[15-9]; coeff[15+10]:=coeff[15-10]; coeff[15+11]:=coeff[15-11]; coeff[15+12]:=coeff[15-12];
					coeff[15+13]:=coeff[15-13]; coeff[15+14]:=coeff[15-14]; coeff[15+15]:=coeff[15-15];
				FIR:=CreateFIRFilter(coeff,15);
				RETURN FIR
			| LeastSquareSpline3Down2: (* identical:  LeastSquareSplineDown2*) 	(*cubic version*)
				NEW(coeff,39);(*least square spline downsampling coefficients; this includes both, the transform to the spline domain and the least square filter*) (* symmetric filter *)
					coeff[19-0]:=0.596797; coeff[19-1]:=0.313287; coeff[19-2]:=-0.0827691; coeff[19-3]:=-0.0921993; coeff[19-4]:=0.0540288; coeff[19-5]:=0.0436996;
					coeff[19-6]:=-0.0302508; coeff[19-7]:=-0.0225552; coeff[19-8]:=0.0162251;	coeff[19-9]:=0.0118738; coeff[19-10]:=-0.00861788; coeff[19-11]:=-0.00627964;
					coeff[19-12]:=0.00456713; coeff[19-13]:=0.00332464; coeff[19-14]:=-0.00241916; coeff[19-15]:=-0.00176059; coeff[19-16]:=0.00128128; coeff[19-17]:=0.000932349;
					coeff[19-18]:=-0.000678643; coeff[19-19]:=-0.00049368;
					(*mirror symmetric 2nd half*)
					coeff[19+1]:=0.313287; coeff[19+2]:=-0.0827691; coeff[19+3]:=-0.0921993; coeff[19+4]:=0.0540288; coeff[19+5]:=0.0436996;
					coeff[19+6]:=-0.0302508; coeff[19+7]:=-0.0225552; coeff[19+8]:=0.0162251;	coeff[19+9]:=0.0118738; coeff[19+10]:=-0.00861788; coeff[19+11]:=-0.00627964;
					coeff[19+12]:=0.00456713; coeff[19+13]:=0.00332464; coeff[19+14]:=-0.00241916; coeff[19+15]:=-0.00176059; coeff[19+16]:=0.00128128; coeff[19+17]:=0.000932349;
					coeff[19+18]:=-0.000678643; coeff[19+19]:=-0.000493682;
				FIR:=CreateFIRFilter(coeff,19);
				RETURN FIR

			| LeastSquareSpline0Up2:
				NEW(coeff,1);(*least square spline upsampling coefficients; this includes both, the transform to the spline domain and the least square filter*) (* symmetric filter *)
					coeff[0]:=1;
				FIR:=CreateFIRFilter(coeff,0);
				RETURN FIR
			| LeastSquareSpline1Up2:
				NEW(coeff,3);(*least square spline upsampling coefficients; this includes both, the transform to the spline domain and the least square filter*) (* symmetric filter *)
					coeff[0]:=0.5; coeff[1]:=1; coeff[2]:=0.5;
					FIR:=CreateFIRFilter(coeff,1);
				RETURN FIR
			| LeastSquareSpline2Up2: 	(* quadratic spline version*)
				NEW(coeff,19);(*least square spline downsampling coefficients; this includes both, the transform to the spline domain and the least square filter*) (* symmetric filter *)
					coeff[9-0]:=1; coeff[9-1]:=0.585786; coeff[9-2]:=0; coeff[9-3]:=-0.100505;
					coeff[9-4]:=0; coeff[9-5]:=0.0172439; coeff[9-6]:=0; coeff[9-7]:=-0.00295859;
					coeff[9-8]:=0;  coeff[9-9]:=0.000507614;
					(*mirror symmetric 2nd half*)
					coeff[9+1]:=coeff[9-1]; coeff[9+2]:=coeff[9-2]; coeff[9+3]:=coeff[9-3]; coeff[9+4]:=coeff[9-4];
					coeff[9+5]:=coeff[9-5]; coeff[9+6]:=coeff[9-6]; coeff[9+7]:=coeff[9-7]; coeff[9+8]:=coeff[9-8]; coeff[9+9]:=coeff[9-9];
				FIR:=CreateFIRFilter(coeff,9);
				RETURN FIR
			| LeastSquareSpline3Up2: (* identical: LeastSquareSplineUp2*) (*cubic spline version*)
				NEW(coeff,23); (*least square spline upsampling coefficients; this includes both, the transform back from the spline domain and the reverse least square*) (*symmetric filter, every second coeff=0 except hotspot*)
					coeff[11-0]:=1; coeff[11-1]:=0.600481; coeff[11-2]:=0; coeff[11-3]:=-0.127405; coeff[11-4]:=0; coeff[11-5]:=0.034138;
					coeff[11-6]:=0; coeff[11-7]:=-0.00914725; coeff[11-8]:=0; coeff[11-9]:=0.002451; coeff[11-10]:=0; coeff[11-11]:=-0.000656743;
					(*mirror symmetric 2nd half *)
					coeff[11+1]:=0.600481; coeff[11+2]:=0; coeff[11+3]:=-0.127405; coeff[11+4]:=0; coeff[11+5]:=0.034138;
					coeff[11+6]:=0; coeff[11+7]:=-0.00914725; coeff[11+8]:=0; coeff[11+9]:=0.002451; coeff[11+10]:=0; coeff[11+11]:=-0.000656743;
				FIR:=CreateFIRFilter(coeff,11);
				RETURN FIR;
			(*
			(*Centered least square filters; make use of special procedure firConvolveCentered[Down/Up]2Even;
			ToDo: Upgrade this to symmetric filters*)
			| LeastSquareSplineCent0Up2: NEW(coeff,1); coeff[0]:=2;
				FIR:=CreateFIRFilter(coeff,0);
				RETURN FIR
			| LeastSquareSplineCent1Up2: NEW(coeff,2); coeff[0]:=1; coeff[1]:=0.5;
				FIR:=CreateFIRFilter(coeff,0);
				RETURN FIR
			| LeastSquareSplineCent2Up2: NEW(coeff,11);
				coeff[0]  :=1.20711;
				coeff[1]  :=  0.585786;
				coeff[2]  := -0.12132;
				coeff[3]  := -0.100505;
				coeff[4]  :=  0.0208153;
				coeff[5]  :=  0.0172439;
				coeff[6]  := -0.00357134;
				coeff[7]  := -0.00295859;
				coeff[8]  :=  0.000612745;
				coeff[9]  :=  0.000507614;
				coeff[10] := -0.00010513;
				FIR:=CreateFIRFilter(coeff,0);
				RETURN FIR
			|LeastSquareSplineCent3Up2: NEW(coeff,16);
				coeff[0]  :=  1.13726;
				coeff[1]  :=  0.625601;
				coeff[2]  := -0.0870191;
				coeff[3]  := -0.159256;
				coeff[4]  :=  0.0233167;
				coeff[5]  :=  0.0426725;
				coeff[6]  := -0.00624769;
				coeff[7]  := -0.0114341;
				coeff[8]  :=  0.00167406;
				coeff[9]  :=  0.00306375;
				coeff[10] := -0.000448564;
				coeff[11] := -0.000820929;
				coeff[12] :=  0.000120192;
				coeff[13] :=  0.000219967;
				coeff[14] := -0.0000322054;
				coeff[15] := -0.00005894;
				FIR:=CreateFIRFilter(coeff,0);
				RETURN FIR
			| LeastSquareSplineCent4Up2: NEW(coeff,20);
				coeff[0]  :=  1.14324;
				coeff[1]  :=  0.643609;
				coeff[2]  := -0.0937888;
				coeff[3]  := -0.194993;
				coeff[4]  :=  0.030127;
				coeff[5]  :=  0.0699433;
				coeff[6]  := -0.0108345;
				coeff[7]  := -0.0252663;
				coeff[8]  :=  0.00391424;
				coeff[9]  :=  0.00912967;
				coeff[10] := -0.00141437;
				coeff[11] := -0.00329892;
				coeff[12] :=  0.000511068;
				coeff[13] :=  0.00119204;
				coeff[14] := -0.00018467;
				coeff[15] := -0.000430732;
				coeff[16] :=  0.0000667289;
				coeff[17] :=  0.000155641;
				coeff[18] := -0.0000241119;
				coeff[19] := -0.0000562395;
				FIR:=CreateFIRFilter(coeff,0);
				RETURN FIR
				*)
			(**Centered Least Square Filters: this version is for the regular FIRConvolve.firConvDown2FiniteEven convolution procedure*)
			(* note that downsampled taps are between the samples; i.e., odd and even convolutions slightly change their meaning:
				EVEN convolution -> first downsampled coefficient between sample -0 and 0
				ODD convolution -> first downsampled coefficient between sample 0 and 1 *)
			| LeastSquareSplineCentered0Down2:
				NEW(coeff,1); coeff[0]  :=  1;
				(*apply the Haar filter*)
				NEW(coeffB,LEN(coeff,0)+1);
				coeffB[0]:=coeff[0]/2; coeffB[LEN(coeffB,0)-1]:=coeff[LEN(coeff,0)-1]/2;
				FOR i:=0 TO LEN (coeff,0)-2 DO coeffB[i+1]:=(coeff[i]+coeff[i+1])/2; END;
				FIR:=CreateFIRFilter(coeffB,LEN(coeffB,0) DIV 2-1);
				RETURN FIR
			| LeastSquareSplineCentered1Down2:	(*first order spline*)
					NEW(coeff,41);
					coeff[20-0]  := 1;
					coeff[20-1]  :=  0.333333;
					coeff[20-2]  := -0.333333;
					coeff[20-3]  := -0.111111;
					coeff[20-4]  :=  0.111111;
					coeff[20-5]  :=  0.037037;
					coeff[20-6]  := -0.037037;
					coeff[20-7]  := -0.0123457;
					coeff[20-8]  :=  0.0123457;
					coeff[20-9]  :=  0.00411523;
					coeff[20-10] := -0.00411523;
					coeff[20-11] := -0.00137174;
					coeff[20-12] :=  0.00137174;
					coeff[20-13] :=  0.000457247;
					coeff[20-14] := -0.000457247;
					coeff[20-15] := -0.000152416;
					coeff[20-16] :=  0.000152416;
					coeff[20-17] :=  0.0000508053;
					coeff[20-18] := -0.0000508053;
					coeff[20-19] := -0.0000169351;
					coeff[20-20] :=  0.0000169351;
										(*mirror symmetric 2nd half*)
					coeff[20+1]:=coeff[20-1]; coeff[20+2]:=coeff[20-2]; coeff[20+3]:=coeff[20-3]; coeff[20+4]:=coeff[20-4];
					coeff[20+5]:=coeff[20-5]; coeff[20+6]:=coeff[20-6]; coeff[20+7]:=coeff[20-7]; coeff[20+8]:=coeff[20-8];
					coeff[20+9]:=coeff[20-9]; coeff[20+10]:=coeff[20-10]; coeff[20+11]:=coeff[20-11]; coeff[20+12]:=coeff[20-12];
					coeff[20+13]:=coeff[20-13]; coeff[20+14]:=coeff[20-14]; coeff[20+15]:=coeff[20-15];
					coeff[20+16]:=coeff[20-16]; coeff[20+17]:=coeff[20-17]; coeff[20+18]:=coeff[20-18];
					coeff[20+19]:=coeff[20-19]; coeff[20+20]:=coeff[20-20];
				(*FIR:=CreateFIRFilter(coeff,20);*)

					(*apply the Haar filter*)
					NEW(coeffB,LEN(coeff,0)+1);
					coeffB[0]:=coeff[0]/2; coeffB[LEN(coeffB,0)-1]:=coeff[LEN(coeff,0)-1]/2;
					FOR i:=0 TO LEN (coeff,0)-2 DO coeffB[i+1]:=(coeff[i]+coeff[i+1])/2; END;
					FIR:=CreateFIRFilter(coeffB,LEN(coeffB,0) DIV 2-1);
				RETURN FIR
			| LeastSquareSplineCentered2Down2:	(*quadratic spline*)
				NEW(coeff,41);
					coeff[20-0]  :=  0.738417;
					coeff[20-1]  :=  0.307916;
					coeff[20-2]  := -0.171064;
					coeff[20-3]  := -0.0799199;
					coeff[20-4]  :=  0.0735791;
					coeff[20-5]  :=  0.03108;
					coeff[20-6]  := -0.0307862;
					coeff[20-7]  := -0.0128561;
					coeff[20-8]  :=  0.0128425;
					coeff[20-9]  :=  0.00535611;
					coeff[20-10] := -0.00535548;
					coeff[20-11] := -0.00223325;
					coeff[20-12] :=  0.00223322;
					coeff[20-13] :=  0.000931242;
					coeff[20-14] := -0.00093124;
					coeff[20-15] := -0.000388322;
					coeff[20-16] :=  0.000388322;
					coeff[20-17] :=  0.000161928;
					coeff[20-18] := -0.000161928;
					coeff[20-19] := -0.0000675233;
					coeff[20-20] :=  0.0000675233;
				(*mirror symmetric 2nd half*)
					coeff[20+1]:=coeff[20-1]; coeff[20+2]:=coeff[20-2]; coeff[20+3]:=coeff[20-3]; coeff[20+4]:=coeff[20-4];
					coeff[20+5]:=coeff[20-5]; coeff[20+6]:=coeff[20-6]; coeff[20+7]:=coeff[20-7]; coeff[20+8]:=coeff[20-8];
					coeff[20+9]:=coeff[20-9]; coeff[20+10]:=coeff[20-10]; coeff[20+11]:=coeff[20-11]; coeff[20+12]:=coeff[20-12];
					coeff[20+13]:=coeff[20-13]; coeff[20+14]:=coeff[20-14]; coeff[20+15]:=coeff[20-15];
					coeff[20+16]:=coeff[20-16]; coeff[20+17]:=coeff[20-17]; coeff[20+18]:=coeff[20-18];
					coeff[20+19]:=coeff[20-19]; coeff[20+20]:=coeff[20-20];
				(*FIR:=CreateFIRFilter(coeff,20);*)
					(*apply the Haar filter*)
					NEW(coeffB,LEN(coeff,0)+1);
					coeffB[0]:=coeff[0]/2; coeffB[LEN(coeffB,0)-1]:=coeff[LEN(coeff,0)-1]/2;
					FOR i:=0 TO LEN (coeff,0)-2 DO coeffB[i+1]:=(coeff[i]+coeff[i+1])/2; END;
					FIR:=CreateFIRFilter(coeffB,LEN(coeffB,0) DIV 2-1);
				RETURN FIR
			| LeastSquareSplineCentered3Down2: (*cubic spline*)
				NEW(coeff,41);
					coeff[20-0]  :=  0.708792;
					coeff[20-1]  :=  0.328616;
					coeff[20-2]  := -0.165157;
					coeff[20-3]  := -0.114448;
					coeff[20-4]  :=  0.0944036;
					coeff[20-5]  :=  0.0543881;
					coeff[20-6]  := -0.05193;
					coeff[20-7]  := -0.0284868;
					coeff[20-8]  :=  0.0281854;
					coeff[20-9]  :=  0.0152877;
					coeff[20-10]  := -0.0152508;
					coeff[20-11]  := -0.00825077;
					coeff[20-12]  :=  0.00824629;
					coeff[20-13]  :=  0.00445865;
					coeff[20-14]  := -0.0044582;
					coeff[20-15]  := -0.00241009;
					coeff[20-16]  :=  0.00241022;
					coeff[20-17]  :=  0.00130278;
					coeff[20-18]  := -0.00130313;
					coeff[20-19]  := -0.000704109;
					coeff[20-20]  :=  0.000704784;
					(*mirror symmetric 2nd half*)
					coeff[20+1]:=coeff[20-1]; coeff[20+2]:=coeff[20-2]; coeff[20+3]:=coeff[20-3]; coeff[20+4]:=coeff[20-4];
					coeff[20+5]:=coeff[20-5]; coeff[20+6]:=coeff[20-6]; coeff[20+7]:=coeff[20-7]; coeff[20+8]:=coeff[20-8];
					coeff[20+9]:=coeff[20-9]; coeff[20+10]:=coeff[20-10]; coeff[20+11]:=coeff[20-11]; coeff[20+12]:=coeff[20-12];
					coeff[20+13]:=coeff[20-13]; coeff[20+14]:=coeff[20-14]; coeff[20+15]:=coeff[20-15];
					coeff[20+16]:=coeff[20-16]; coeff[20+17]:=coeff[20-17]; coeff[20+18]:=coeff[20-18];
					coeff[20+19]:=coeff[20-19]; coeff[20+20]:=coeff[20-20];

					(*apply the Haar filter*)
					NEW(coeffB,LEN(coeff,0)+1);
					coeffB[0]:=coeff[0]/2; coeffB[LEN(coeffB,0)-1]:=coeff[LEN(coeff,0)-1]/2;
					FOR i:=0 TO LEN (coeff,0)-2 DO coeffB[i+1]:=(coeff[i]+coeff[i+1])/2; END;
					FIR:=CreateFIRFilter(coeffB,LEN(coeffB,0) DIV 2-1);
					RETURN FIR
			| LeastSquareSplineCentered4Down2: (*4th degree spline*)
				NEW(coeff,41);
					coeff[20-0]  :=  0.673072;
					coeff[20-1]  :=  0.331218;
					coeff[20-2]  := -0.139359;
					coeff[20-3]  := -0.12051;
					coeff[20-4]  :=  0.086389;
					coeff[20-5]  :=  0.0611801;
					coeff[20-6]  := -0.0542989;
					coeff[20-7]  := -0.034777;
					coeff[20-8]  :=  0.033388;
					coeff[20-9]  :=  0.0206275;
					coeff[20-10] := -0.0203475;
					coeff[20-11] := -0.0124183;
					coeff[20-12] :=  0.0123625;
					coeff[20-13] :=  0.00751369;
					coeff[20-14] := -0.00750374;
					coeff[20-15] := -0.00455348;
					coeff[20-16] :=  0.00455363;
					coeff[20-17] :=  0.00276047;
					coeff[20-18] := -0.00276406;
					coeff[20-19] := -0.00167279;
					coeff[20-20] :=  0.00167938;
						(*mirror symmetric 2nd half*)
					coeff[20+1]:=coeff[20-1]; coeff[20+2]:=coeff[20-2]; coeff[20+3]:=coeff[20-3]; coeff[20+4]:=coeff[20-4];
					coeff[20+5]:=coeff[20-5]; coeff[20+6]:=coeff[20-6]; coeff[20+7]:=coeff[20-7]; coeff[20+8]:=coeff[20-8];
					coeff[20+9]:=coeff[20-9]; coeff[20+10]:=coeff[20-10]; coeff[20+11]:=coeff[20-11]; coeff[20+12]:=coeff[20-12];
					coeff[20+13]:=coeff[20-13]; coeff[20+14]:=coeff[20-14]; coeff[20+15]:=coeff[20-15];
					coeff[20+16]:=coeff[20-16]; coeff[20+17]:=coeff[20-17]; coeff[20+18]:=coeff[20-18];
					coeff[20+19]:=coeff[20-19]; coeff[20+20]:=coeff[20-20];
				(*FIR:=CreateFIRFilter(coeff,20);*)
					(*apply the Haar filter*)
					NEW(coeffB,LEN(coeff,0)+1);
					coeffB[0]:=coeff[0]/2; coeffB[LEN(coeffB,0)-1]:=coeff[LEN(coeff,0)-1]/2;
					FOR i:=0 TO LEN (coeff,0)-2 DO coeffB[i+1]:=(coeff[i]+coeff[i+1])/2; END;
					FIR:=CreateFIRFilter(coeffB,LEN(coeffB,0) DIV 2-1);
				RETURN FIR
	(*Centered Least Square Filters: here are the symmetric ones. use the standard upsampling procedures from DSPConvolve.Mod*)

			| LeastSquareSplineCentered0Up2: (*0 order spline*)
				NEW(coeff,1); coeff[0]:=2;
				(*mirror symmetric 2nd half*)
				FOR i:=1 TO mid DO coeff[mid+i] := coeff[mid-i]; END;
				NEW(coeffB,LEN(coeff,0)+1);
				(*apply the Haar filter*)
				coeffB[0]:=coeff[0]/2; coeffB[LEN(coeffB,0)-1]:=coeff[LEN(coeff,0)-1]/2;
				FOR i:=0 TO LEN(coeff,0)-2 DO coeffB[i]:=(coeff[i]+coeff[i+1])/2; END;
				FIR:=CreateFIRFilter(coeffB,mid);
				RETURN FIR
			| LeastSquareSplineCentered1Up2: (*1 order spline*)
				NEW(coeff,3); coeff[0]:=0.5; coeff[1]:=1; coeff[2]:=0.5;
				NEW(coeffB,LEN(coeff,0)+1);
				(*apply the Haar filter*)
				coeffB[0]:=coeff[0]/2; coeffB[LEN(coeffB,0)-1]:=coeff[LEN(coeff,0)-1]/2;
				FOR i:=0 TO LEN(coeff,0)-2 DO coeffB[i]:=(coeff[i]+coeff[i+1])/2; END;
				FIR:=CreateFIRFilter(coeffB,mid);
				RETURN FIR
			| LeastSquareSplineCentered2Up2: (*2 order spline*)
				NEW(coeff,21);
					coeff[10-0]  :=1.20711;
					coeff[10-1]  :=  0.585786;
					coeff[10-2]  := -0.12132;
					coeff[10-3]  := -0.100505;
					coeff[10-4]  :=  0.0208153;
					coeff[10-5]  :=  0.0172439;
					coeff[10-6]  := -0.00357134;
					coeff[10-7]  := -0.00295859;
					coeff[10-8]  :=  0.000612745;
					coeff[10-9]  :=  0.000507614;
					coeff[10-10] := -0.00010513;
				(*mirror symmetric 2nd half*)
				mid:=10;
				FOR i:=1 TO mid DO coeff[mid+i] := coeff[mid-i]; END;
				NEW(coeffB,LEN(coeff,0)+1);
				(*apply the Haar filter*)
				coeffB[0]:=coeff[0]/2; coeffB[LEN(coeffB,0)-1]:=coeff[LEN(coeff,0)-1]/2;
				FOR i:=0 TO LEN(coeff,0)-2 DO coeffB[i]:=(coeff[i]+coeff[i+1])/2; END;
				FIR:=CreateFIRFilter(coeffB,mid);
				RETURN FIR
			|LeastSquareSplineCentered3Up2: (*cubic spline*)
					NEW(coeff,31);
					coeff[15-0]  :=  1.13726;
					coeff[15-1]  :=  0.625601;
					coeff[15-2]  := -0.0870191;
					coeff[15-3]  := -0.159256;
					coeff[15-4]  :=  0.0233167;
					coeff[15-5]  :=  0.0426725;
					coeff[15-6]  := -0.00624769;
					coeff[15-7]  := -0.0114341;
					coeff[15-8]  :=  0.00167406;
					coeff[15-9]  :=  0.00306375;
					coeff[15-10] := -0.000448564;
					coeff[15-11] := -0.000820929;
					coeff[15-12] :=  0.000120192;
					coeff[15-13] :=  0.000219967;
					coeff[15-14] := -0.0000322054;
					coeff[15-15] := -0.00005894;
					mid:=15;
					FOR i:=1 TO mid DO coeff[mid+i] := coeff[mid-i]; END;
					NEW(coeffB,LEN(coeff,0)+1);
					(*apply the Haar filter*)
					coeffB[0]:=coeff[0]/2; coeffB[LEN(coeffB,0)-1]:=coeff[LEN(coeff,0)-1]/2;
					FOR i:=0 TO LEN(coeff,0)-2 DO coeffB[i]:=(coeff[i]+coeff[i+1])/2; END;
					FIR:=CreateFIRFilter(coeffB,mid);
					RETURN FIR
			|LeastSquareSplineCentered4Up2: (*4th order spline*)
					NEW(coeff,39);
					coeff[19-0]  :=  1.14324;
					coeff[19-1]  :=  0.643609;
					coeff[19-2]  := -0.0937888;
					coeff[19-3]  := -0.194993;
					coeff[19-4]  :=  0.030127;
					coeff[19-5]  :=  0.0699433;
					coeff[19-6]  := -0.0108345;
					coeff[19-7]  := -0.0252663;
					coeff[19-8]  :=  0.00391424;
					coeff[19-9]  :=  0.00912967;
					coeff[19-10] := -0.00141437;
					coeff[19-11] := -0.00329892;
					coeff[19-12] :=  0.000511068;
					coeff[19-13] :=  0.00119204;
					coeff[19-14] := -0.00018467;
					coeff[19-15] := -0.000430732;
					coeff[19-16] :=  0.0000667289;
					coeff[19-17] :=  0.000155641;
					coeff[19-18] := -0.0000241119;
					coeff[19-19] := -0.0000562395;
					mid:=19;
					FOR i:=1 TO mid DO coeff[mid+i] := coeff[mid-i]; END;
					NEW(coeffB,LEN(coeff,0)+1);
					(*apply the Haar filter*)
					coeffB[0]:=coeff[0]/2; coeffB[LEN(coeffB,0)-1]:=coeff[LEN(coeff,0)-1]/2;
					FOR i:=0 TO LEN(coeff,0)-2 DO coeffB[i]:=(coeff[i]+coeff[i+1])/2; END;
					FIR:=CreateFIRFilter(coeffB,mid);
				RETURN FIR


			|MomentCubic0:
				FIR.coeff:=[0.000198412697292503,
							0.0238095238097662,
							0.23630952380979,
							0.479365079744588,
							0.23630952380979,
							0.0238095238097662,
							0.000198412697292503];
							FIR.origin:=3;
							RETURN FIR;
			|MomentCubic1:
				FIR.coeff:=[-0.000297619045362068,
							-0.0238095238097635,
							-0.118154761905087,
							0,
							0.118154761905087,
							0.0238095238097635,
							0.000297619045362068];
				FIR.origin:=3; RETURN FIR;
			|MomentCubic2:
				FIR.coeff:=[0.000451940030743304,
							0.0261904761907132,
							0.096726190476451,
							0.086596119929943,
							0.096726190476451,
							0.0261904761907132,
							0.000451940030743304];
				FIR.origin:=3; RETURN FIR;
			|MomentCubicH0: (* zero order moment; Sühling M et al, Multiresolution Moment Filters 2003; http://bigwww.epfl.ch *)
				FIR.coeff:=[1/8, 4/8, 6/8, 4/8, 1/8]; FIR.origin:=2; RETURN FIR;
			|MomentCubicH1: (* first order moments; Sühling M et al, Multiresolution Moment Filters 2003; http://bigwww.epfl.ch *)
				FIR.coeff:=[-1/4, -2/4, 0, 2/4 , 1/4]; FIR.origin:=2; RETURN FIR;
			|MomentCubicH11:
				FIR.coeff:=[1/8, 4/8, 6/8, 4/8, 1/8]; FIR.origin:=2; RETURN FIR;
			|MomentCubicH2:  (* second order moments; Sühling M et al, Multiresolution Moment Filters 2003; http://bigwww.epfl.ch *)
				FIR.coeff:=[1/2, 1/2, 0 , 1/2, 1/2]; FIR.origin:=2; RETURN FIR;
			|MomentCubicH21:  FIR.coeff:=[-1/2, -2/2, 0 , 2/2, 1/2]; FIR.origin:=2; RETURN FIR;
			|MomentCubicH22:   FIR.coeff:=[1/1, 4/8, 6/6, 4/8, 1/8]; FIR.origin:=2; RETURN FIR;

			| CubicSplineDifferentiator: 		(* in: cubic spline; out: quadratic spline*)
				FIR.coeff:=[1/2, 0, -1/2]; FIR.origin:=1; RETURN FIR;
			| CubicSplineLaplacian: 			(* in: cubic spline; out: linear spline, i.e. identity transformation, i.e.=signal domain *)
				FIR.coeff:=[1/6, -2/6, 1/6]; FIR.origin:=1; RETURN FIR;
			| SplineDerivative: 					(* in: spline of degree N; out: spline of degree N-1 *) (*? should be identical to CubicSplineDifferentiator*)
				FIR.coeff:=[1/2, -1/2]; FIR.origin:=1 ; RETURN FIR;
			| SplineLaplacian: 					(* in: spline of degree N; out: spline of degree N-2 *)
				FIR.coeff:=[1/6, -2/6, 1/6]; FIR.origin:=1 ; RETURN FIR;
				(*
			| CubicSplineDerivativeFromSignal: (*! resulting from a) transform to cubic spline; derivative, transform back from quadratic spline. to do - check this again ... *)
				(*! it might rather be -0.0007  0.0038 -0.0144  0.0538 -0.5760  0.0000  0.5760 -0.0538  0.0144 -0.0038  0.0007 *)
				FIR.coeff:=[-1.09186841732395E-011,
		    4.07490840863281E-011,
		   -1.52077652172073E-010,
		    5.67561524601963E-010,
		   -2.11816844623578E-009,
		    7.90511226034115E-009,
		   -2.95022805951288E-008,
		    1.10104010120174E-007,
		   -4.10913759885567E-007,
		    1.53355102942209E-006,
		   -5.72329035780281E-006,
		    2.13596104017891E-005,
		   -7.97151512493537E-005,
		     0.000297500994595626,
		     -0.00111028882713315,
		      0.00414365431393697,
		      -0.0154643284286147,
		       0.0577136594005218,
		       -0.215390309173473,
		        0.803847577293368,
		                        0,
		       -0.803847577293368,
		        0.215390309173473,
		      -0.0577136594005218,
		       0.0154643284286147,
		     -0.00414365431393697,
		      0.00111028882713315,
		    -0.000297500994595626,
		    7.97151512493537E-005,
		   -2.13596104017891E-005,
		    5.72329035780281E-006,
		   -1.53355102942209E-006,
		    4.10913759885567E-007,
			-1.10104010120174E-007,
		    2.95022805951288E-008,
		   -7.90511226034115E-009,
		    2.11816844623578E-009,
		   -5.67561524601963E-010,
		    1.52077652172073E-010,
		   -4.07490840863281E-011,
		    1.09186841732395E-011];
		    	FIR.origin:=20 ; RETURN FIR;
		    	*)
		    	(*approximates the filter above*)
		    	| SplineDerivativeApproximation: FIR.coeff:=[ 0.803847577293368,  0, -0.803847577293368]; FIR.origin:=1; RETURN FIR;

			| Smooth: FIR.coeff:=[1/4, 2/4, 1/4]; FIR.origin:=1; RETURN FIR;
			ELSE Out.String("MatrixFilters.CreateSplineFilter: unknown/unimplemented filtertype "); RETURN NIL
			END;
	END CreateSplineFilter;

	PROCEDURE CreateSheppLogan*():FIRFilter; (*highpass filter, e.g. for tomographic reconstruction. coeffs by AM; truncated to be F*)
	VAR f:FIRFilter;
	BEGIN
		NEW(f);
		f.InitFIR( [
	-0.000397446782523121,
    -0.000452091003616891,
    -0.000518878470408135,
    -0.000601695015322519,
    -0.000706115963154806,
    -0.000840371555278944,
     -0.00101702373906564,
     -0.00125602384270261,
     -0.00159062407984705,
     -0.00207965529005778,
     -0.00283543089432271,
     -0.00409505700362921,
     -0.00643436274467497,
      -0.0115808354975696,
      -0.0270202539094766,
       -0.135096183099245,
        0.405283463002798,
       -0.135096183099245,
      -0.0270202539094766,
      -0.0115808354975696,
     -0.00643436274467497,
     -0.00409505700362922,
     -0.00283543089432271,
     -0.00207965529005777,
     -0.00159062407984705,
     -0.00125602384270261,
     -0.00101702373906564,
    -0.000840371555278945,
    -0.000706115963154806,
    -0.000601695015322519,
    -0.000518878470408135,
    -0.000452091003616888,
    -0.000397446782523121], 16);
		RETURN f
	END CreateSheppLogan;

PROCEDURE CreateHann*():FIRFilter; (*coeffs by AM. truncated to be FIR*)
	VAR f:FIRFilter;
	BEGIN
		NEW(f);
		f.InitFIR( [
	-0.000401728381659076,
    -0.000451590094723833,
    -0.000526198455635865,
    -0.000600806816547893,
    -0.000719722347879124,
    -0.000838637879210356,
     -0.00104539451564863,
     -0.00125215115208691,
     -0.00166060122257524,
     -0.00206905129306357,
     -0.00306158522195873,
      -0.0040541191508539,
     -0.00765665004818991,
      -0.0112591809455259,
      -0.0562908180815969,
       0.0236775447823322,
        0.148677544782332,
       0.0236775447823322,
      -0.0562908180815969,
      -0.0112591809455259,
     -0.00765665004818991,
      -0.0040541191508539,
     -0.00306158522195873,
     -0.00206905129306357,
     -0.00166060122257524,
     -0.00125215115208691,
     -0.00104539451564863,
    -0.000838637879210357,
    -0.000719722347879124,
    -0.000600806816547893,
    -0.000526198455635865,
    -0.000451590094723833,
    -0.000401728381659076], 16);
		RETURN f
END CreateHann;


END LinearFilters.
