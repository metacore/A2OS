MODULE PlanarFFT;   (**  AUTHOR "Patrick  Hunziker"; PURPOSE "FFT operations on 2D Data";  **)

IMPORT LinearFFT, MatrixBase, PlanarMath, Commands;

CONST
	cachesize = 40000H;   (* make dynamic *)
	cachefraction = 0.3;   (* how much of cache should be used for temporary data structure. This might be a good starting point for  ATLAS like machine-adaptive optimizations *)

TYPE
	Datatype = MatrixBase.Datatype;
	OneD = ARRAY [ * ] OF Datatype;
	TwoD = ARRAY [ * , * ] OF Datatype;
	LineHandler* = PROCEDURE {DELEGATE} ( CONST lineInR, lineInI: OneD;  VAR lineOutR, lineOutI: OneD );

	PROCEDURE HandleLines( CONST dataR, dataI: TwoD;  VAR resdataR, resdataI: TwoD;  directions: SET;  linehandler: LineHandler );
	VAR templineR, templineI, templine1R, templine1I: OneD;
			rectR, rectI, resrectR, resrectI: TwoD;
			x, y, w0, w, h, j, lenX, lenY: SIZE;
	BEGIN
		lenX := LEN( dataR, 1 );
		lenY := LEN( dataR, 0 );
		IF 1 IN directions THEN  (*along x*)
			IF LEN( dataI,0 ) > 0 THEN
				FOR y := 0 TO lenY - 1 DO linehandler( dataR[y], dataI[y], resdataR[y], resdataI[y] ) END;
			ELSE  (*no imaginary input data*)
				NEW( templineI, lenX );
				FOR y := 0 TO lenY - 1 DO linehandler( dataR[y], templineI, resdataR[y], resdataI[y] ) END;
			END;
			lenX := LEN( resdataR, 1 );
		END;
		IF 0 IN directions THEN  (*additional optimization option: only cut 'rect' out of data if XY plane does not fit into cache by itself (somewhat similar for z dimension) *)
			h := lenY;
			w0 := MIN( lenX, ENTIER( cachesize * cachefraction / SIZEOF( Datatype ) / h ) );
			NEW( rectR, h, w0 );
			NEW( rectI, h, w0 );
			NEW( resrectR, lenY (*LEN( resdataR, 1 )*), w0 );
			NEW( resrectI, lenY (*LEN( resdataR, 1 )*), w0 );
			NEW( templineI, lenY );
			j := 0;
			WHILE j < lenX DO  (*work in slices of full lenY size, but limited with w to avoid cache misses *)
				w := MIN( w0, lenX - j );
				IF 1 IN directions THEN rectR[.. , .. w - 1] := resdataR[.. , j..j + w - 1];  rectI[.. , .. w - 1] := resdataI[.. , j..j + w - 1];
				ELSE rectR[.. , .. w - 1] := dataR[.. , j..j + w - 1];  rectI[.. , .. w - 1] := dataI[.. , j..j + w - 1];
				END;
				FOR x := 0 TO w - 1 DO
					templineR := rectR[.. , x];
					templineI := rectI[.. , x];
					templine1R := resrectR[.. , x];   (*HACK double data copy ! - there is a problem with the linehandler(rect[..,x], resrect[..,x]); data passing*)
					templine1I := resrectI[.. , x];
					linehandler( templineR, templineI, templine1R, templine1I );
					resrectR[.. , x] := templine1R;
					resrectI[.. , x] := templine1I;
					(*linehandler(rect[..,x], resrect[..,x]);*)
				END;
				resdataR[.. , j..j + w - 1] := resrectR[.. , .. w - 1];
				resdataI[.. , j..j + w - 1] := resrectI[.. , .. w - 1];
				INC( j, w );
			END;
			lenY := LEN( resdataR, 0 (*1*) );
		END;
	END HandleLines;

	PROCEDURE FFT*( CONST inR, inI: TwoD;  VAR outR, outI: TwoD;  directions: SET );
	BEGIN
		IF LEN( outR,0 ) = 0 THEN NEW( outR, LEN( inR, 0 ), LEN( inR, 1 ) ) END;
		IF LEN( outI,0 ) = 0 THEN NEW( outI, LEN( inR, 0 ), LEN( inR, 1 ) ) END;
		HandleLines( inR, inI, outR, outI, directions, LinearFFT.FFT )
	END FFT;

	PROCEDURE IFFT*( CONST inR, inI: TwoD;  VAR outR, outI: TwoD;  directions: SET );
	BEGIN
		IF LEN( outR,0 ) = 0 THEN NEW( outR, LEN( inR, 0 ), LEN( inR, 1 ) ) END;
		IF LEN( outI,0 ) = 0 THEN NEW( outI, LEN( inR, 0 ), LEN( inR, 1 ) ) END;
		HandleLines( inR, inI, outR, outI, directions, LinearFFT.IFFT )
	END IFFT;

	PROCEDURE PowerSpectrum*( CONST in: TwoD ): TwoD;
	VAR nil, R, I: TwoD;
	BEGIN
		IF LEN( RESULT, 0 ) = 0 THEN NEW( RESULT, LEN( in, 0 ), LEN( in, 1 ) ) END;
		FFT( in, nil, R, I, {0, 1} );
		RESULT := R .* R;
		RESULT := RESULT + I .* I;
		RETURN RESULT;
	END PowerSpectrum;

	(** deconvolution is multiplication in the Fourier domain *)
	PROCEDURE Convolution*( CONST in1, in2: TwoD;  VAR outR, outI: TwoD );
	VAR R1, I1, R2, I2, nil, tmpR, tmpI: TwoD;  lenX, lenY: SIZE;
	BEGIN
		lenX := LEN( in1, 1 );  lenY := LEN( in1, 0 );
		FFT( in1, nil, R1, I1, {0, 1} );
		FFT( in2, nil, R2, I2, {0, 1} );
		PlanarMath.ComplexMultiplication(R1,I1,R2,I2,tmpR,tmpI);
		IFFT( tmpR, tmpI, outR, outI, {0, 1} );
	END Convolution;

	(** deconvolution is division in Fourier domain:  (a+bi )/(c+di) = (ac+bd)/(c*c+d*d), i*(bc-ad)/(c*c+d*d) *)
	PROCEDURE DeConvolution*( CONST in1, in2: TwoD;  VAR outR, outI: TwoD );
	VAR R1, I1, R2, I2, nil, tmpR, tmpI: TwoD;
	BEGIN
		FFT( in1, nil, R1, I1, {0, 1} );
		FFT(in2, nil, R2, I2, {0, 1} );
		PlanarMath.ComplexDivision(R1,I1,R2,I2,tmpR,tmpI);
		IFFT( tmpR, tmpI, outR, outI, {0, 1} );
	END DeConvolution;

	(** crosscorrelation is multiplication in the Fourier domain of the complex conjugate*)
	PROCEDURE CrossCorrelation*( CONST in1, in2: TwoD;  VAR outR, outI: TwoD );
	VAR R1, I1, R2, I2, tmpR,tmpI,nil: TwoD;  lenX, lenY: SIZE;
	BEGIN
		lenX := LEN( in1, 1 );  lenY := LEN( in1, 0 );
		FFT( in1, nil, R1, I1, {0, 1} );
		FFT( in2, nil, R2, I2, {0, 1} );
		PlanarMath.ComplexMultiplication(R1,I1,R2,-I2,tmpR,tmpI);
		IFFT(tmpR,tmpI,outR,outI,{0,1});
	END CrossCorrelation;

	PROCEDURE AutoCorrelation*( CONST in: TwoD ): TwoD;
	VAR  autocorr, R,I, nil: TwoD;
	BEGIN
		IF LEN( RESULT, 0 ) = 0 THEN NEW( RESULT, LEN( in, 0 ), LEN( in, 1 ) ) END;
		FFT( in,nil,R,I, {0, 1} );
		autocorr := R.*R; autocorr:= autocorr +  I .* I ;  (* plus sign due to multiplication by complex conjugate "R,I * R,-I" *)
		IFFT( autocorr, nil, RESULT, I, {0, 1} );
		RETURN RESULT
	END AutoCorrelation;
	
			(*filter in the Fourier domain. power of 2 data required.
	filter is in frequency domain, is typically in [0.0 ... 1.0] but might have other values *)
	PROCEDURE Filter*(CONST in, filter: TwoD): TwoD;
	VAR  I, nil, R: TwoD;
	BEGIN
		IF LEN(RESULT) # LEN(in) THEN NEW( RESULT, LEN(in) ) END;
		FFT( in, nil, R, I, {0,1});
		R := R .* filter;
		I := I .* filter;
		IFFT( R, I, RESULT, nil, {0,1});
		RETURN RESULT
	END Filter; 
	
	PROCEDURE {TEST} Test*();  
	CONST TestTolerance=0.0001;
	VAR image, imageI, resR, resI, res2R, res2I, diff: MatrixBase.Matrix;
	BEGIN 
		NEW( image, 256, 256);  NEW( imageI, 256, 256);  
		image[60..63] := 1;  image[70..73] := 1;  
		FFT( image, imageI, resR, resI, {0,1});  
		IFFT( resR, resI, res2R, res2I, {0,1});  
		diff:=image-res2R;
		ASSERT(diff+*diff < TestTolerance );
	END Test;

END PlanarFFT.

System.FreeDownTo PlanarFFT ~

PlanarFFT.Test~

