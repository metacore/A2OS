MODULE Wavelets; (*Patrick Hunziker, 2009. *)(* Wavelet transform - basic compute framework *)

IMPORT LinearFilters, LinearConvolve, FIR:=LinearFIRConvolveLongReal;

CONST
	sqrt2 = 1.41421356237309504880168872420969808;   (* reconstruction factor in wavelet filters *)
	sqrt15 = 3.87298334620741688517927;   (* reconstruction factor in Coiflet wavelet filter *)

	 (** Boundaries. TO DO: adapt to LinearFilters.Mod *)
	undefined*=-LinearFilters.undefined;
	default*=undefined;

	finite*=LinearFilters.finite; 	  	(*data beyond limit = zero*)

	periodicH*=LinearFilters.cyclicH;  	(* data[x] =data[x MOD LEN(data)] *)

	mirrorH*=LinearFilters.mirrorH; 		(* mirror boundaries, using border point twice; H=center at 1/2 between N and N+1 points*)

	mirrorW*=LinearFilters.mirrorW;		(* mirror boundaries, using border point once; W=center on border point N*)


	 (** Wavelet  name*)
	 (** Orthogonal wavelet *)  (** Even length*)
	Haar* = 00;
	BattleLemarie* = 01;
	Coiflet* = 02;
	Daubechies8* = 03;

	(** Bi-orthogonal wavelets*)  (** Odd length *)
	Daubechies97* = 29;
	Lifting53 = 30;   (*untested*)
	BurtAdelson* = 31;
	Quadraticspline* = 32;
	Spline97* = 33;
		 (** Even length *)
	Cubicspline* = 41;
	Spline610* = 42;

	 (** Shift Orthogonal wavelets *)  (** Hybrid Shift Orthogonal Spline Wavelets, from Unser M, Shift-Orthogonal Wavelet Bases, 	  IEEE Trans Signal Proc  1998; 46:1827 and IEEE Sig Proc Letter 1996; 3: 85 *)  (**Even length*)
	HybridHaarLemarie* = 61;
	ShiftOrthoQuadSpline* = 62;
		(** Odd length *)
	ShiftOrthoCubicSpline* = 71;

TYPE
	Datatype* = FLOAT64;
	FIRFilter* = LinearFilters.FIRFilter;
	Dataarray* = ARRAY [ * ] OF Datatype;
	FilterCoeffs* = ARRAY [ * ] OF Datatype;

	(** wavelet filter family*)
	WaveletFamily*= OBJECT
		VAR
			loAnalysis*,
			hiAnalysis*,
			loReconstruct*,
			hiReconstruct*: FIRFilter;
			defaultBoundary*:SIGNED32;
			verifiedBoundaries*:SET;
		PROCEDURE &Init*(wavelet:SIGNED32);
			BEGIN
				CreateWaveletFamily(SELF,wavelet);
			END Init;
	END WaveletFamily;

TYPE
		(*to do: implement more boundary handling variants*)
	WaveletConvolver* = OBJECT
	VAR temp, tmpLo, tmpHi, tmpResLo, tmpResHi: Dataarray;
		wavelet-: WaveletFamily;
		preAn*,postLoAn*,postHiAn*,
		preLoRec*,preHiRec*,postRec* : PROCEDURE (CONST d:Dataarray):Dataarray;(*optional pre/postprocessing of data/result*)
		boundary*,shift*:SIGNED32;
		upHiCoeffs,upLoCoeffs,downHiCoeffs,downLoCoeffs:Dataarray;

		Clow,Chigh: LinearConvolve.Convolver;

		PROCEDURE &Init*(wavelet:WaveletFamily; boundary:SIGNED32);
		VAR i:SIZE;
		BEGIN
			SELF.wavelet:=wavelet;
			IF wavelet=NIL THEN RETURN END;
			IF boundary=undefined THEN SELF.boundary:=wavelet.defaultBoundary ELSE SELF.boundary:=boundary END;
			NEW(Clow,wavelet.loAnalysis,boundary);
			NEW(Chigh,wavelet.hiAnalysis,boundary);
			SELF.shift:=0; (*default even/odd element choice*)
			NEW(downHiCoeffs,LEN(wavelet.hiAnalysis.coeff,0)); FOR i:=0 TO LEN(downHiCoeffs,0)-1 DO downHiCoeffs[i]:= wavelet.hiAnalysis.coeff[i] END;
			NEW(downLoCoeffs,LEN(wavelet.loAnalysis.coeff,0)); FOR i:=0 TO LEN(downLoCoeffs,0)-1 DO downLoCoeffs[i]:= wavelet.loAnalysis.coeff[i] END;
			NEW(upHiCoeffs,LEN(wavelet.hiReconstruct.coeff,0)); FOR i:=0 TO LEN(upHiCoeffs,0)-1 DO upHiCoeffs[i]:= wavelet.hiReconstruct.coeff[i] END;
			NEW(upLoCoeffs,LEN(wavelet.loReconstruct.coeff,0)); FOR i:=0 TO LEN(upLoCoeffs,0)-1 DO upLoCoeffs[i]:= wavelet.loReconstruct.coeff[i] END;
		END Init;

		PROCEDURE Analyze*( CONST data: Dataarray; VAR resdata:Dataarray);
		VAR i, filterlen, offsetLo, offsetHi,  datalen, rawdatalen: SIZE;
		BEGIN
	(*
			Clow.convolveDown2(data, resdata[ .. LEN(data+1) DIV 2 -1]);
			Chigh.convolveDown2(data, resdata[LEN(data+1) DIV 2 ..]);
	*)

		(*Assertions;*)
			(*IF data=NIL THEN RETURN END;*)
			IF boundary IN {mirrorH,mirrorW,periodicH,finite} THEN
				filterlen := MAX( LEN( wavelet.loAnalysis.coeff,0 ), LEN( wavelet.hiAnalysis.coeff ,0) );
				datalen := LEN( data,0);
				rawdatalen := LEN( data,0) + 2 * filterlen;   (*SHORTER OVERLENGTH COULD BE IMPLEMENTED*)
				IF (LEN( temp ) # rawdatalen) THEN NEW( temp, rawdatalen );  END;
				IF (LEN( tmpLo ) # rawdatalen) THEN NEW( tmpLo, rawdatalen ) END;
				IF (LEN( tmpHi ) # rawdatalen) THEN NEW( tmpHi, rawdatalen ) END;   (*to improve: CAN USE SHORTER RESULT ARRAYS *)

				IF preAn#NIL THEN temp[filterlen..filterlen + datalen-1]:=preAn(data[..datalen-1]) (* optional preprocessing of data *)
				ELSE temp[filterlen..filterlen + datalen-1]:=data[..datalen-1]
				END;
					
				

				CASE boundary OF (*!to do: even/odd, symmetric/asymmetric filters*)
				mirrorH:
					IF TRUE (*~ODD(datalen)*) THEN
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := temp[filterlen + i];
							temp[filterlen + datalen + i] := temp[filterlen + datalen - i - 1];
						END;
					ELSE
						(* *)
					END;
				|mirrorW:
					IF TRUE (*~ODD(datalen)*) THEN
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := temp[filterlen + i+1];
							temp[filterlen + datalen + i] := temp[filterlen + datalen - i - 2];
						END;
					ELSE
						(* *)
					END;
				|periodicH:
					IF TRUE (*~ODD(datalen)*) THEN (*?untested for various lengths and symmetries of data and filters*)
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := temp[filterlen+datalen- i-1];
							temp[filterlen + datalen + i] := temp[filterlen +  i];
						END;
					ELSE

					END;
				|finite:
					IF TRUE (*~ODD(datalen)*) THEN (*?untested for various lengths and symmetries of data and filters*)
						temp[..filterlen- 1] := 0;
						temp[filterlen + datalen..] := 0;
					ELSE

					END;
				END;

				FIR.ConvolveDown2( downLoCoeffs, temp, tmpLo, shift );
				FIR.ConvolveDown2( downHiCoeffs, temp, tmpHi, shift );

				offsetLo := (filterlen - wavelet.loAnalysis.origin) DIV 2;
				offsetHi := (filterlen - wavelet.hiAnalysis.origin) DIV 2;
				IF postLoAn#NIL THEN (*optional postprocessing*)
					resdata[..(datalen + 1) DIV 2-1]:=postLoAn(tmpLo[offsetLo..offsetLo + ((datalen + 1) DIV 2)-1]); (*to do: symmetries*)
				ELSE
					resdata[..(datalen + 1) DIV 2-1]:=tmpLo[offsetLo..offsetLo + ((datalen + 1) DIV 2)-1]; (*to do: symmetries*)				
				END;
				IF postHiAn#NIL THEN
					resdata[(datalen + 1) DIV 2..(datalen + 1) DIV 2 + (datalen) DIV 2-1] := postHiAn(tmpHi[offsetHi..offsetHi +(datalen) DIV 2-1 ]);
				ELSE
					resdata[(datalen + 1) DIV 2..(datalen + 1) DIV 2 + (datalen) DIV 2-1] := tmpHi[offsetHi..offsetHi +(datalen) DIV 2-1 ];(*PH090207*)
				END;

			ELSE HALT(100); (*not yet implemented*)(*! to do: need to port other boundary conditions*)
			END;

		END Analyze;

		PROCEDURE Reconstruct*( CONST data: Dataarray; VAR resdata:Dataarray);
		VAR i,  filterlen, offsetLo, offsetHi: SIZE;
			halffilterlen, halfLen, halfLenPlus, datalen: SIZE;

		BEGIN
		(*Assertions;*)
		(*IF data=NIL THEN RETURN END;	*)  (*'data' is expected to contain an array with ((n+1) DIV 2) lowpass & (n DIV 2) highpass elements with border conditions not yet handled; *)
			IF boundary IN {mirrorH, mirrorW, periodicH, finite} THEN (*mirrorH and mirrorW not differentiated at the moment; in reconstruction, both ways need to be taken into account based on ODD (datalen) *)
				filterlen := MAX( LEN( wavelet.loReconstruct.coeff,0 ), LEN( wavelet.hiReconstruct.coeff,0 ) );
				halffilterlen := (filterlen + 1) DIV 2;
				 datalen := LEN( data,0);
				halfLen := datalen DIV 2;
				halfLenPlus := (datalen + 1) DIV 2;
				IF (LEN( tmpLo ) # halfLenPlus + 2 * halffilterlen) THEN NEW( tmpLo, halfLenPlus + 2 * halffilterlen )	END;
				IF (LEN( tmpHi ) # (halfLen + 2 * halffilterlen)) THEN NEW( tmpHi, halfLen + 2 * halffilterlen )	END;   (*to improve: CAN USE SHORTER RESULT ARRAYS *)
				IF (LEN( tmpResLo ) # datalen + 2 * filterlen) THEN NEW( tmpResLo, datalen + 2 * filterlen )	END;
				IF (LEN( tmpResHi ) # (datalen + 2 * filterlen)) THEN NEW( tmpResHi, datalen + 2 * filterlen ) END;

				IF preLoRec#NIL THEN tmpLo[halffilterlen..halffilterlen +halfLenPlus -1]:= preLoRec(data[..halfLenPlus-1])
				ELSE tmpLo[halffilterlen..halffilterlen +halfLenPlus -1]:= data[..halfLenPlus-1];
				END;
				IF preHiRec#NIL THEN tmpHi[halffilterlen..halffilterlen+halfLen-1]:= preHiRec(data[halfLenPlus..halfLenPlus+halfLen-1]);
				ELSE tmpHi[halffilterlen..halffilterlen+halfLen-1]:= data[halfLenPlus..halfLenPlus+halfLen-1];
				END;
				CASE boundary OF
				mirrorH, mirrorW:
					IF ODD( datalen ) THEN
						FOR i := 0 TO halffilterlen - 1 DO
							tmpLo[halffilterlen - i - 1] := tmpLo[halffilterlen + i];
							tmpLo[halffilterlen + halfLenPlus + i - 1] := tmpLo[halffilterlen + halfLenPlus - i - 1];   (*i.e. W symmetry*)
							tmpHi[halffilterlen - i - 1] := -tmpHi[halffilterlen + i];
							tmpHi[halffilterlen + halfLenPlus + i - 1] := -tmpHi[halffilterlen + halfLenPlus - i - 1];   (*i.e. W symmetry with the last element = zero  *)
						END;
					ELSE
						FOR i := 0 TO halffilterlen - 1 DO
							tmpLo[halffilterlen - i - 1] := tmpLo[halffilterlen + i];
							tmpLo[halffilterlen + halfLenPlus + i] := tmpLo[halffilterlen + halfLenPlus - i - 1];
							tmpHi[halffilterlen - i - 1] := -tmpHi[halffilterlen + i];
							tmpHi[halffilterlen + halfLenPlus + i] := -tmpHi[halffilterlen + halfLenPlus - i - 1];
						END;
					END;
				| periodicH: (*? ?? untested untested for various lengths and symmetries of data and filter*)
						FOR i := 0 TO halffilterlen - 1 DO
							tmpLo[halffilterlen - i - 1] := tmpLo[halffilterlen+halfLenPlus- i-1];
							tmpLo[halffilterlen + halfLenPlus + i] := tmpLo[halffilterlen + i ];
							tmpHi[halffilterlen - i - 1] := -tmpHi[halffilterlen+halfLenPlus-i-1];
							tmpHi[halffilterlen + halfLenPlus + i] := -tmpHi[halffilterlen + i];
						END;
				| finite: (*? ?? untested for various lengths and symmetries of data and filter*)
						FOR i := 0 TO halffilterlen - 1 DO
							tmpLo[halffilterlen - i - 1] := tmpLo[halffilterlen + i];
							tmpLo[halffilterlen + halfLenPlus + i] := tmpLo[halffilterlen + halfLenPlus - i - 1];
							tmpHi[halffilterlen - i - 1] := -tmpHi[halffilterlen + i];
							tmpHi[halffilterlen + halfLenPlus + i] := -tmpHi[halffilterlen + halfLenPlus - i - 1];
						END;
				ELSE HALT(100);
				END;
				FIR.ConvolveUp2( upLoCoeffs,  tmpLo,  tmpResLo, shift );
				FIR.ConvolveUp2( upHiCoeffs, tmpHi,   tmpResHi, shift );
				offsetLo := -wavelet.loReconstruct.origin;   (*(filterlen-wavelet.loReconstruct.origin) DIV 2;*)
				offsetHi := -wavelet.hiReconstruct.origin;   (*(filterlen-wavelet.hiReconstruct.origin) DIV 2;*)
				FOR i := 0 TO datalen - 1 DO
					resdata[i] :=
						tmpResLo[2 * halffilterlen + offsetLo + i] +
						tmpResHi[2 * halffilterlen + offsetHi + i]
				END;
				IF postRec#NIL THEN resdata[0..datalen]:=postRec(resdata[0..datalen]) END;
			ELSE HALT(100); (*not yet implemented*)
			END;
		END Reconstruct;

	END WaveletConvolver;



	PROCEDURE reflect( F: FIRFilter ): FIRFilter;
	(* reflect a filter by symmetric mapping, to get analysis filter from reconstruction filter in wavelet*)
	VAR res: FIRFilter;  coeff: FilterCoeffs;  i: SIZE;
	BEGIN
		NEW( coeff, LEN( F.coeff,0) );
		FOR i := 0 TO LEN( F.coeff,0) - 1 DO coeff[i] := F.coeff[LEN( coeff,0) - i - 1] END;
		res := LinearFilters.CreateFIRFilter( coeff, LEN( coeff,0) - F.origin - 1 );  RETURN res
	END reflect;

	PROCEDURE DoubleCoeff( F: FIRFilter );
	(* double coeff, to balance analysis and reconstruction filters*)
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN( F.coeff,0) - 1 DO F.coeff[i] := 2 * F.coeff[i] END;
	END DoubleCoeff;

	PROCEDURE reflectHalf( F: FIRFilter ): FIRFilter;
	(* reflect a filter by symmetric mapping, to get analysis filter from reconstruction filter in wavelet, and divide by 2 to balance*)
	VAR res: FIRFilter;  coeff: FilterCoeffs;  i: SIZE;
	BEGIN
		NEW( coeff, LEN( F.coeff,0) );
		FOR i := 0 TO LEN( F.coeff,0) - 1 DO coeff[i] := 0.5 * F.coeff[LEN( coeff,0) - i - 1] END;
		res := LinearFilters.CreateFIRFilter( coeff, LEN( coeff,0) - F.origin - 1 );  RETURN res
	END reflectHalf;

	PROCEDURE ChangeEvenSignReflect( F: FIRFilter ): FIRFilter;
	(* Change sign of even items of filter, and reflect the filter,  to get hiReconstruct filter from loReconstruct filter in wavelet*)
	VAR res: FIRFilter;  coeff: FilterCoeffs;  i: SIZE;  factor: SIGNED32;
	BEGIN
		NEW( coeff, LEN( F.coeff,0) );  factor := 1;
		FOR i := 0 TO LEN( F.coeff,0) - 1 DO coeff[i] := factor * F.coeff[LEN( coeff,0) - i - 1];  factor := -factor;  END;
		res := LinearFilters.CreateFIRFilter( coeff, LEN( coeff,0) - F.origin - 2 );  RETURN res
	END ChangeEvenSignReflect;

	PROCEDURE ChangeOddSignReflect( F: FIRFilter ): FIRFilter;
	(* Change sign of odd items of filter, and reflect the filter, to get hiAnalysis filter from loAnalysis filter in wavelet*)
	VAR res: FIRFilter;  coeff: FilterCoeffs;  i: SIZE;  factor: SIGNED32;
	BEGIN
		NEW( coeff, LEN( F.coeff,0) );  factor := -1;
		FOR i := 0 TO LEN( F.coeff,0) - 1 DO coeff[i] := factor * F.coeff[LEN( coeff,0) - i - 1];  factor := -factor;  END;
		res := LinearFilters.CreateFIRFilter( coeff, LEN( coeff,0) - F.origin - 2 );  RETURN res
	END ChangeOddSignReflect;

	PROCEDURE Swap( F: WaveletFamily );
	(* change filter, only needed for biorthogonal wavelets.*)
	VAR tempfilter: FIRFilter;  temporigin: SIZE;
	BEGIN
		NEW( tempfilter );  tempfilter := F.loReconstruct;  F.loReconstruct := F.loAnalysis;  F.loAnalysis := tempfilter;  temporigin := F.hiReconstruct.origin;  F.hiReconstruct.origin := F.hiAnalysis.origin;
		F.hiAnalysis.origin := temporigin;
	END Swap;

	PROCEDURE HalfToFull( VAR a, b: FilterCoeffs;  odd: BOOLEAN );   (*odd: b:= W symmetric, odd length filter; otherwise b:= H symmetric, ieven length bilter*)
	VAR mid, i, len: SIZE;
	BEGIN
		IF LEN( a ) = 0 THEN RETURN END;
		len := LEN( a,0);
		IF odd THEN NEW( b, 2 * len - 1 ) ELSE NEW( b, 2 * len ) END;
		IF odd THEN mid := len - 1 ELSE mid := len END;
		FOR i := 0 TO len - 1 DO b[len - i - 1] := a[i];  b[mid + i] := a[i] END;
	END HalfToFull;

	PROCEDURE SwapHalfs( VAR a: FilterCoeffs );
	VAR val: Datatype;  i, len, mid: SIZE;
	BEGIN
		mid := LEN( a,0) DIV 2;  len := LEN( a,0);
		FOR i := 0 TO mid - 1 DO val := a[i];  a[i] := a[mid - i - 1];  a[mid - i - 1] := val;  val := a[mid + i];  a[mid + i] := a[len - 1 - i];  a[len - 1 - i] := val;  END;
	END SwapHalfs;

	PROCEDURE NewWaveletFamily*( waveletname: SIGNED32):WaveletFamily;
	VAR F:WaveletFamily;
	BEGIN
		NEW(F,waveletname);
		RETURN F
	END NewWaveletFamily;

	PROCEDURE CreateWaveletFamily*( F:WaveletFamily; waveletname: SIGNED32 );
	VAR coeff: FilterCoeffs;  i: SIGNED32;
	BEGIN
		(** create 1D Wavelet filters family ,including:
			loAnalysis: analysis lowpass  filter;
			hiAnalysis:  analysis heighpass filter,
			loReconstruct: reconstruction  lowpass  filter;
			hiReconstruct:  reconstruction  highpass filters;
			verifiedBoundaries: boundary conditions which work (*i.e., perfect (or near-perfect reconstruction *)
			defaultBoundary: preferred boundary condition;
		 *)
		CASE waveletname OF
		(* Orthogonal wavelet:	 From loReconstruct filter, create hiReconstruct, loAnalysis and hiAnalysis filters *)
		Haar:  (* orthogonal,H-symmetry, but discontinuity; allows perfect reconstruction for PeriodicEven,
			         PeriodicOdd,mirrorWEven,mirrorHEven,FiniteEven Convolve,  but not for FiniteOdd,mirrorHOdd or mirrorWOdd Convolve*)
				NEW( coeff, 2 );  coeff[0] := 1;  coeff[1] := 1;
				F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 1 );
				F.hiReconstruct := ChangeEvenSignReflect( F.loReconstruct );  F.hiReconstruct.origin:=1;
				F.loAnalysis := reflectHalf( F.loReconstruct );  F.loAnalysis.origin:=0;
				F.hiAnalysis := reflectHalf( F.hiReconstruct );  F.hiAnalysis.origin:=0;
				F.defaultBoundary := mirrorH;  F.verifiedBoundaries := {finite, periodicH, mirrorH, mirrorW};   (*however, not yet working for odd boundary conditions for some reason ?? *)
		| BattleLemarie:
				NEW( coeff, 24 );   (* degree n:??*)  (** in need of repair... *)
				(* symmetric, smooth, quickly decaying, infinite support *)
				(* usable with Finite(?) or Periodic Convolvution *)
				coeff[0] := 2 * (-0.002);  coeff[1] := 2 * (-0.003);  coeff[2] := 2 * 0.006;  coeff[3] := 2 * 0.006;  coeff[4] := 2 * (-0.013);  coeff[5] := 2 * (-0.012);  coeff[6] := 2 * 0.030;  coeff[7] := 2 * 0.023;
				coeff[8] := 2 * (-0.078);  coeff[9] := 2 * (-0.035);  coeff[10] := 2 * 0.307;  coeff[11] := 2 * 0.542;  coeff[12] := 2 * 0.307;  coeff[13] := 2 * (-0.035);  coeff[14] := 2 * (-0.078);  coeff[15] := 2 * 0.023;
				coeff[16] := 2 * 0.030;  coeff[17] := 2 * (-0.012);  coeff[18] := 2 * (-0.013);  coeff[19] := 2 * 0.006;  coeff[20] := 2 * 0.006;  coeff[21] := 2 * (-0.003);  coeff[22] := 2 * (-0.002);  coeff[23] := 0.0;
				F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 11 );   (* why not 12 ? but that gives worse results... *)
				F.hiReconstruct := ChangeEvenSignReflect( F.loReconstruct );
				F.loAnalysis := reflectHalf( F.loReconstruct );  F.hiAnalysis := reflectHalf( F.hiReconstruct );
				F.defaultBoundary := periodicH;
				F.verifiedBoundaries := {periodicH};
		| Coiflet:
				NEW( coeff, 6 );
				(* updated by Daubechies upon request of Coiflet. more symmetric than Daubechies filters *)
				(* finite support, orthogonal. use Periodic Convolution, has small error D-6*)
				coeff[0] := 2 * (sqrt15 - 3) / 32;  coeff[1] := 2 * (1 - sqrt15) / 32;  coeff[2] := 2 * (6 - 2 * sqrt15) / 32;  coeff[3] := 2 * (2 * sqrt15 + 6) / 32;  coeff[4] := 2 * (sqrt15 + 13) / 32;
				coeff[5] := 2 * (9 - sqrt15) / 32;  F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 3 );  F.hiReconstruct := ChangeEvenSignReflect( F.loReconstruct );
				F.loAnalysis := reflectHalf( F.loReconstruct );  F.hiAnalysis := reflectHalf( F.hiReconstruct );  F.defaultBoundary := periodicH;  F.verifiedBoundaries := {periodicH};
		| Daubechies8:
				(* finite support, orthogonal, can use in Periodic Convolve,  have small error D-5 *)
				NEW( coeff, 8 );  coeff[0] := 0.230377813309;  coeff[1] := 0.714846570553;  coeff[2] := 0.6308807667930;  coeff[3] := -0.027983769417;  coeff[4] := -0.187034811719;
				coeff[5] := 0.030841381836;  coeff[6] := 0.032883011667;  coeff[7] := -0.010597401785;  F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 1 );
				F.hiReconstruct := ChangeEvenSignReflect( F.loReconstruct );  F.loAnalysis := reflect( F.loReconstruct );  F.hiAnalysis := reflect( F.hiReconstruct );  F.defaultBoundary := periodicH;  F.verifiedBoundaries := {};

	   	(* ??Biorthogonal wavelets:    From loReconstruct and loAnalysis filter, create hiReconstruct and hiAnalysis filters *)
		| Lifting53:  (* untested - does not correctly work with convolution. possibly needs lifting scheme. possibly wrong origins? *)
				HALT( 100 );   (*coefficients are very similar to quadraticspline, but is it really the same ?? origins here probably wrong; signs in 3-filter may be wrong ?*)
				NEW( coeff, 3 );  coeff[0] := -1 / 2;  coeff[1] := 2 / 2;  coeff[2] := -1 / 2;  F.hiAnalysis := LinearFilters.CreateFIRFilter( coeff, 1 );  F.loReconstruct := ChangeEvenSignReflect( F.hiAnalysis );
				F.loReconstruct.origin := 1;  NEW( coeff, 5 );  coeff[0] := -1 / 8;  coeff[1] := 2 / 8;  coeff[2] := 6 / 8;  coeff[3] := 2 / 8;  coeff[4] := -1 / 8;  F.loAnalysis := LinearFilters.CreateFIRFilter( coeff, 2 );
				F.hiReconstruct := ChangeOddSignReflect( F.hiAnalysis );  F.hiReconstruct.origin := 2;
		| Daubechies97:
				NEW( coeff, 7 );  coeff[0] := 0.09127176311424948;  coeff[1] := -0.05754352622849957;  coeff[2] := -0.5912717631142470;  coeff[3] := 1.115087052456994;  coeff[4] := -0.5912717631142470;
				coeff[5] := -0.05754352622849957;  coeff[6] := 0.09127176311424948;  F.hiAnalysis := LinearFilters.CreateFIRFilter( coeff, 3 );  F.loReconstruct := ChangeEvenSignReflect( F.hiAnalysis );
				F.loReconstruct.origin := 3;  NEW( coeff, 9 );  coeff[0] := 0.02674875741080976;  coeff[1] := -0.01686411844287495;  coeff[2] := -0.07822326652898785;  coeff[3] := 0.2668641184428723;
				coeff[4] := 0.6029490182363579;  coeff[5] := 0.2668641184428723;  coeff[6] := -0.07822326652898785;  coeff[7] := -0.01686411844287495;  coeff[8] := 0.02674875741080976;
				F.loAnalysis := LinearFilters.CreateFIRFilter( coeff, 4 );  F.hiReconstruct := ChangeOddSignReflect( F.loAnalysis );  F.hiAnalysis.origin := 4;  F.defaultBoundary := periodicH;  F.verifiedBoundaries := {};

			(* Bi-Orthogonal wavelets:  From loReconstruct and loAnalysis filter, create hiReconstruct and hiAnalysis filters *)
		| BurtAdelson:
				NEW( coeff, 5 );
				(*Bi-Orthogonal,W-symmetric, usable in mirrorWOdd or Periodic Convolve,  has small error D-6 *)
				coeff[0] := (-1) / 20;  coeff[1] := 5 / 20;  coeff[2] := 12 / 20;  coeff[3] := 5 / 20;  coeff[4] := (-1) / 20;
				(* coeff[5]:=0 ; *)
				F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 2 );  F.hiReconstruct := ChangeEvenSignReflect( F.loReconstruct );  F.hiReconstruct.origin := 2;  NEW( coeff, 7 );
				(* coeff[0]:=0 ; *)
				coeff[0] := (-3) / 280;  coeff[1] := (-15) / 280;  coeff[2] := 73 / 280;  coeff[3] := 170 / 280;  coeff[4] := 73 / 280;  coeff[5] := (-15) / 280;  coeff[6] := (-3) / 280;
				F.loAnalysis := LinearFilters.CreateFIRFilter( coeff, 3 );   (* 4*)
				F.hiAnalysis := ChangeOddSignReflect( F.loAnalysis );  F.hiAnalysis.origin := 3;  Swap( F );  DoubleCoeff( F.loReconstruct );  DoubleCoeff( F.hiReconstruct );  F.defaultBoundary := periodicH;
				F.verifiedBoundaries := {periodicH, mirrorW};
		| Quadraticspline:
				NEW( coeff, 5 );
				(* Bi-Orthognal,W-symmetric, allows perfect reconstruction. use mirrorWOdd or Periodic Convolve *)
				coeff[0] := (-0.125);  coeff[1] := 0.25;  coeff[2] := 0.75;  coeff[3] := 0.25;  coeff[4] := (-0.125);  F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 2 );
				F.hiReconstruct := ChangeEvenSignReflect( F.loReconstruct );  F.hiReconstruct.origin := 0;  NEW( coeff, 3 );  coeff[0] := 1 / 4;  coeff[1] := 2 / 4;  coeff[2] := 1 / 4;
				F.loAnalysis := LinearFilters.CreateFIRFilter( coeff, 1 );   (* 2 *)
				F.hiAnalysis := ChangeOddSignReflect( F.loAnalysis );
				F.hiAnalysis.origin := 3;   (*2*)
				Swap( F );  DoubleCoeff( F.loReconstruct );  DoubleCoeff( F.hiReconstruct );  F.defaultBoundary := periodicH;  F.verifiedBoundaries := {periodicH, mirrorW};
		| Cubicspline:  (* H-symmetric, biorthogonal, perfect reconstruction 	in mirrorHOdd or Periodic Convolve*)
				NEW( coeff, 4 );  coeff[0] := 1 / 8;  coeff[1] := 3 / 8;  coeff[2] := 3 / 8;  coeff[3] := 1 / 8;  F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 1 );
				F.hiReconstruct := ChangeEvenSignReflect( F.loReconstruct );  F.hiReconstruct.origin := 3;
				NEW( coeff, 8 );  coeff[0] := 3 / 64;  coeff[1] := (-9) / 64;  coeff[2] := (-7) / 64;  coeff[3] := 45 / 64;
				coeff[4] := 45 / 64;  coeff[5] := (-7) / 64;  coeff[6] := (-9) / 64;  coeff[7] := 3 / 64;
				F.loAnalysis := LinearFilters.CreateFIRFilter( coeff, 4 );   (* =3*)
				F.hiAnalysis := ChangeOddSignReflect( F.loAnalysis );
				F.hiAnalysis.origin := 2;   (* =1  *)
				Swap( F );  DoubleCoeff( F.loReconstruct );  DoubleCoeff( F.hiReconstruct );  F.defaultBoundary := periodicH;  F.verifiedBoundaries := {periodicH, 2};
		| Spline97:
				NEW( coeff, 7 );   (* from Strang/Nguyen's book "wavelets and filter banks"*)
				(* W-symmetric, smooth synthesis scale function,biorthogonal, perfect reconstruction 	in mirrorWOdd or Periodic Convolve*)
				coeff[0] := -1 / 16 / 2;   (* normalized for 'partition of unity', also below *)
				coeff[1] := 0 / 16 / 2;  coeff[2] := 9 / 16 / 2;  coeff[3] := 16 / 16 / 2;  coeff[4] := 9 / 16 / 2;  coeff[5] := 0 / 16 / 2;  coeff[6] := -1 / 16 / 2;  F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 3 );
				F.hiReconstruct := ChangeEvenSignReflect( F.loReconstruct );  F.hiReconstruct.origin := 3;  NEW( coeff, 9 );  coeff[0] := 1 / 64 * 2;  coeff[1] := 0 / 64 * 2;  coeff[2] := (-8) / 64 * 2;
				coeff[3] := 16 / 64 * 2;  coeff[4] := 46 / 64 * 2;  coeff[5] := 16 / 64 * 2;  coeff[6] := (-8) / 64 * 2;  coeff[7] := 0 / 64 * 2;  coeff[8] := 1 / 64 * 2;  F.loAnalysis := LinearFilters.CreateFIRFilter( coeff, 4 );
				F.hiAnalysis := ChangeOddSignReflect( F.loAnalysis );  F.hiAnalysis.origin := 4;  Swap( F );  F.defaultBoundary := periodicH;  F.verifiedBoundaries := {periodicH, mirrorW};
		| Spline610:  (* from Strang/Nguyen's book "wavelets and filter banks", p 217 *)	(* switching 6/10 may even be better.. see Strangs book*)
				(* H-symmetric, biorthogonal, smooth scale functions,perfect reconstruction 	in mirrorHOdd or Periodic Convolve*)
				NEW( coeff, 6 );
				coeff[0] := (-1) / 8 / 2;  coeff[1] := 1 / 8 / 2;  coeff[2] := 8 / 8 / 2;  coeff[3] := 8 / 8 / 2;  coeff[4] := 1 / 8 / 2;  coeff[5] := (-1) / 8 / 2;
				F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 2 );
				F.hiReconstruct := ChangeEvenSignReflect( F.loReconstruct );
				F.hiReconstruct.origin := 4;   (* is this correct ? should it rather be=3 ? But: no perfect recon with 3+3!*)
				NEW( coeff, 10 );  coeff[0] := 1 / 128 * 2;  coeff[1] := 1 / 128 * 2;  coeff[2] := (-8) / 128 * 2;  coeff[3] := 8 / 128 * 2;  coeff[4] := 62 / 128 * 2;  coeff[5] := 62 / 128 * 2;  coeff[6] := 8 / 128 * 2;
				coeff[7] := (-8) / 128 * 2;  coeff[8] := 1 / 128 * 2;  coeff[9] := 1 / 128 * 2;
				F.loAnalysis := LinearFilters.CreateFIRFilter( coeff, 5 );  F.hiAnalysis := ChangeOddSignReflect( F.loAnalysis );  Swap( F );
				F.defaultBoundary := periodicH;  F.verifiedBoundaries := {periodicH, mirrorH};
				(* Shift-orthogonal wavelet: *)
		| HybridHaarLemarie:
				(*Shift-orthogonal, H-symmetric. use in mirrorHEven or Periodic convolve.
           Has error less than D-2 *)
				NEW( coeff, 30 );  coeff[15] := 0.68037;  coeff[16] := 0.137963;  coeff[17] := -0.124835;  coeff[18] := -0.0207472;  coeff[19] := 0.0419821;  coeff[20] := 0.00423816;  coeff[21] := -0.0151129;
				coeff[22] := -0.00112345;  coeff[23] := 0.00570553;  coeff[24] := 0.000334821;  coeff[25] := -0.00221175;  coeff[26] := -0.000107847;  coeff[27] := 0.000873158;  coeff[28] := 0.0000364102;
				coeff[29] := -0.000349114;
				FOR i := 0 TO 14 DO
					coeff[i] := coeff[29 - i] (* symmetric *)
				END;
				F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 14 );  NEW( coeff, 2 );  coeff[0] := 0.707107;
				coeff[1] := -0.707107;   (* asymmetric  *)
				F.hiReconstruct := LinearFilters.CreateFIRFilter( coeff, 0 );  NEW( coeff, 30 );  coeff[15] := 0.735505;  coeff[16] := -0.00710868;  coeff[17] := -0.00710868;  coeff[18] := -0.0114306;
				coeff[19] := -0.0114306;  coeff[20] := 0.00611006;  coeff[21] := 0.00611006;  coeff[22] := -0.00241844;  coeff[23] := -0.00241844;  coeff[24] := 0.00087672;  coeff[25] := 0.00087672;
				coeff[26] := -0.000307468;  coeff[27] := -0.000307468;  coeff[28] := 0.0000106857;  coeff[29] := 0.0000106857;
				FOR i := 0 TO 14 DO
					coeff[i] := coeff[29 - i] (* symmetric  *)
				END;
				F.loAnalysis := LinearFilters.CreateFIRFilter( coeff, 15 );   (*=15*)
				NEW( coeff, 30 );  coeff[15] := -0.707107;  coeff[16] := 0.139234;  coeff[17] := 0.139234;  coeff[18] := -0.0352308;  coeff[19] := -0.0352308;  coeff[20] := 0.00875716;  coeff[21] := 0.00875716;
				coeff[22] := -0.00218759;  coeff[23] := -0.00218759;  coeff[24] := 0.000545397;  coeff[25] := 0.000545397;  coeff[26] := -0.000136101;  coeff[27] := -0.000136101;  coeff[28] := 0.000033947;
				coeff[29] := 0.000033947;
				FOR i := 0 TO 14 DO
					coeff[i] := coeff[29 - i] (* symmetric  *)
				END;
				FOR i := 15 TO 29 DO
					coeff[i] := -coeff[29 - i] (* asymmetric  *)  (*update*)
				END;
				F.hiAnalysis := LinearFilters.CreateFIRFilter( coeff, 15 );   (* =15 *)
				F.defaultBoundary := periodicH;  F.verifiedBoundaries := {periodicH, mirrorH};
		| ShiftOrthoQuadSpline:
				(** needs update *)
				NEW( coeff, 30 );  coeff[15] := 0.68037;

				coeff[16] := 0.137963;  coeff[17] := -0.124835;  coeff[18] := -0.0207472;  coeff[19] := 0.0419821;  coeff[20] := 0.00423816;  coeff[21] := -0.0151129;  coeff[22] := -0.00112345;
				coeff[23] := 0.00570553;  coeff[24] := 0.000334821;  coeff[25] := -0.00221175;  coeff[26] := -0.000107847;  coeff[27] := 0.000873158;  coeff[28] := 0.0000364102;  coeff[29] := -0.000349114;

				FOR i := 0 TO 14 DO
					coeff[i] := coeff[29 - i] (* symmetric  *)
				END;
				F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 14 );  NEW( coeff, 30 );  coeff[15] := 0.706862;

				coeff[16] := -0.0130307;  coeff[17] := -0.129547;  coeff[18] := 0.0019878;  coeff[19] := 0.00223624;  coeff[20] := 0.000308145;  coeff[21] := 0.000232297;  coeff[22] := 0.0000522267;
				coeff[23] := 0.0000488927;  coeff[24] := 8.69216E-06;  coeff[25] := 8.51609E-06;  coeff[26] := 1.47356E-06;  coeff[27] := 1.57089E-06;  coeff[28] := 2.52536E-07;  coeff[29] := 2.88225E-07;

				FOR i := 0 TO 14 DO
					coeff[i] := -coeff[29 - i] (* asymmetric  *)
				END;
				F.hiReconstruct := LinearFilters.CreateFIRFilter( coeff, 14 );  NEW( coeff, 30 );  coeff[15] := 0.729915;

				coeff[16] := 0.00766485;  coeff[17] := -0.0195685;  coeff[18] := -0.0112333;  coeff[19] := -0.00645937;  coeff[20] := 0.00460937;  coeff[21] := 0.00537476;  coeff[22] := -0.00215218;
				coeff[23] := -0.00225881;  coeff[24] := 0.000779012;  coeff[25] := 0.000888193;  coeff[26] := -0.000289915;  coeff[27] := -0.000323867;  coeff[28] := 0.0000102918;  coeff[29] := 0.000011698;

				FOR i := 0 TO 14 DO
					coeff[i] := coeff[29 - i] (* symmetric  *)
				END;
				F.loAnalysis := LinearFilters.CreateFIRFilter( coeff, 15 );  NEW( coeff, 30 );  coeff[15] := -0.702088;

				coeff[16] := 0.138748;  coeff[17] := 0.136703;  coeff[18] := -0.0322905;  coeff[19] := -0.0368606;  coeff[20] := 0.00809514;  coeff[21] := 0.0100018;  coeff[22] := -0.00223964;
				coeff[23] := -0.00265455;  coeff[24] := 0.000586975;  coeff[25] := 0.000716251;  coeff[26] := -0.000159667;  coeff[27] := -0.000190971;  coeff[28] := 0.0000423399;  coeff[29] := 0.0000513501;

				FOR i := 0 TO 14 DO
					coeff[i] := -coeff[29 - i] (* asymmetric  *)
				END;
				F.hiAnalysis := LinearFilters.CreateFIRFilter( coeff, 15 );  F.defaultBoundary := undefined;  F.verifiedBoundaries := {};
		| ShiftOrthoCubicSpline:
				(* W-symmetric , can use in mirrorWOdd(err D-3) or Periodic(err D-2) Convolve *)
				NEW( coeff, 41 );  coeff[20] := 1.08347;  coeff[21] := 0.613659;  coeff[22] := -0.070996;  coeff[23] := -0.155616;  coeff[24] := 0.0453692;  coeff[25] := 0.0594936;  coeff[26] := -0.024291;
				coeff[27] := -0.0254308;  coeff[28] := 0.0122829;  coeff[29] := 0.0115986;  coeff[30] := -0.00615726;  coeff[31] := -0.00549058;  coeff[32] := 0.00309248;  coeff[33] := 0.00266174;
				coeff[34] := -0.00156092;  coeff[35] := -0.00131126;  coeff[36] := 0.00079187;  coeff[37] := 0.00065353;  coeff[38] := -0.000403594;  coeff[39] := -0.000328589;  coeff[40] := 0.000206534;
				FOR i := 0 TO 19 DO
					coeff[i] := coeff[40 - i] (* center symmetric  *)
				END;
				F.loReconstruct := LinearFilters.CreateFIRFilter( coeff, 20 );  NEW( coeff, 41 );  coeff[20] := 1.15485;  coeff[21] := -0.563151;  coeff[22] := -0.0973574;  coeff[23] := 0.0753237;
				coeff[24] := 0.024683;  coeff[25] := -0.0147667;  coeff[26] := -0.00582268;  coeff[27] := 0.00323499;  coeff[28] := 0.00135813;  coeff[29] := -0.0007871;  coeff[30] := -0.00034943;
				coeff[31] := 0.00018464;  coeff[32] := 0.0000834622;  coeff[33] := -0.0000478199;  coeff[34] := -0.0000222962;  coeff[35] := 0.0000115052;  coeff[36] := 5.38729E-06;  coeff[37] := -3.07609E-06;
				coeff[38] := -1.47358E-06;  coeff[39] := 7.48299E-07;  coeff[40] := 3.57612E-07;
				FOR i := 0 TO 19 DO
					coeff[i] := coeff[40 - i] (* center symmetric  *)
				END;
				F.hiReconstruct := LinearFilters.CreateFIRFilter( coeff, 21 );  NEW( coeff, 41 );  coeff[20] := 0.582529;  coeff[21] := 0.282665;  coeff[22] := -0.0519285;  coeff[23] := -0.0395953;
				coeff[24] := 0.0123611;  coeff[25] := 0.00839683;  coeff[26] := -0.00132849;  coeff[27] := -0.00166831;  coeff[28] := -0.000919721;  coeff[29] := 0.000117659;  coeff[30] := 0.000956435;
				coeff[31] := 0.000182244;  coeff[32] := -0.000648131;  coeff[33] := -0.000167137;  coeff[34] := 0.000377941;  coeff[35] := 0.000109648;  coeff[36] := -0.000206646;  coeff[37] := -0.0000631112;
				coeff[38] := 0.000108551;  coeff[39] := 0.0000342583;  coeff[40] := -0.0000557311;
				FOR i := 0 TO 19 DO
					coeff[i] := coeff[40 - i] (* center symmetric  *)
				END;
				F.loAnalysis := LinearFilters.CreateFIRFilter( coeff, 20 );  NEW( coeff, 41 );  coeff[20] := 0.54633;  coeff[21] := -0.308251;  coeff[22] := -0.0384306;  coeff[23] := 0.0804651;  coeff[24] := 0.0227514;
				coeff[25] := -0.0313868;  coeff[26] := -0.0108077;  coeff[27] := 0.013063;  coeff[28] := 0.00476525;  coeff[29] := -0.00555301;  coeff[30] := -0.00206644;  coeff[31] := 0.00237672;
				coeff[32] := 0.000891964;  coeff[33] := -0.00102066;  coeff[34] := -0.000384402;  coeff[35] := 0.00043885;  coeff[36] := 0.00016587;  coeff[37] := -0.000188834;  coeff[38] := -0.0000713083;
				coeff[39] := 0.0000812759;  coeff[40] := 0.0000307068;
				FOR i := 0 TO 19 DO
					coeff[i] := coeff[40 - i] (* center symmetric  *)
				END;
				F.hiAnalysis := LinearFilters.CreateFIRFilter( coeff, 19 );  F.defaultBoundary := periodicH;  F.verifiedBoundaries := {periodicH, mirrorW};
		ELSE HALT( 199 );
		END;
	END CreateWaveletFamily;



(*PROCEDURE ShowFilters*;
(** show wavelet filters in WaveletFamily *)
VAR FF: WaveletFamily;
		h,g,ih,ig:FIRFilter;
       len,i:SIGNED32;
       r:FLOAT32;
       c:CHAR;
       waveletname:SIGNED16;
   BEGIN
   Out.Ln;
		Out.String("Orthogonal wavelet:");Out.Ln;
		Out.String(" Haar=00, BattleLemarie=01, Coiflet=02, Daubechies8=03 ");Out.Ln;
		Out.String("Bi-orthogonal wavelet:");Out.Ln;
		Out.String(" BurtAdelson=31,quadraticspline=32,spline97=33,cubicspline=41,spline610=42");Out.Ln;
		Out.String("Shift Orthogonal wavelet:");Out.Ln;
		Out.String("HybridHaarLemarie=61,ShiftOrthoQuadSpline*=62");Out.Ln;
		Out.String ("ShiftOrthoCubicSpline*=71 ");		Out.Ln;
		Out.String("Please input waveletname number: ");
		Input.Read(c);
		waveletname:=ORD(c)-48;
		Out.Char(c);
		Input.Read(c);
		waveletname:=ORD(c)-48+waveletname*10;
		Out.Char(c);Out.Ln;
		FF:=CreateWaveletFamily(waveletname);
		IF FF#NIL THEN
			ih:=FF.loAnalysis;
		Out.String(" Analysis lowpass filter ih"); Out.Ln;
		FOR i:=0 TO LEN(ih.coeff)-1 DO
	       Out.Real(ih.coeff[i],13);
		END;
		Out.String("  origin="); Out.Int(ih.origin,5);Out.Ln;
		ig:=FF.hiAnalysis;
		Out.String(" Analysis highpass filter ig"); Out.Ln;
		FOR i:=0 TO LEN(ig.coeff)-1 DO
	       Out.Real(ig.coeff[i],13);
		END;
		Out.String("  origin="); Out.Int(ig.origin,5);Out.Ln;
		h:=FF.loReconstruct;
		Out.String("Reconstruct lowpass filter h"); Out.Ln;
		FOR i:=0 TO LEN(h.coeff)-1 DO
	       Out.Real(h.coeff[i],13);
		END;
		Out.String("  origin="); Out.Int(h.origin,5);Out.Ln;
		g:=FF.hiReconstruct;
		Out.String("Reconstruct highpass filter g"); Out.Ln;
		FOR i:=0 TO LEN(g.coeff)-1 DO
	       Out.Real(g.coeff[i],13);
		END;
		Out.String("  origin="); Out.Int(g.origin,5); Out.Ln;
	END;
END ShowFilters;
*)
END Wavelets.
