MODULE VolumeFFT;   (**  AUTHOR "Patrick  Hunziker"; PURPOSE "FFT operations on 3D Data";  **)

IMPORT LinearFFT, MatrixBase, TensorMath (*, MatrixUtilities*);

CONST
	cachesize = 40000H;   (* make dynamic *)
	cachefraction = 0.3;   (* how much of cache should be used for temporary data structure. This might be a good starting point for  ATLAS like machine-adaptive optimizations *)

TYPE
	Datatype = MatrixBase.Datatype;
	OneD = ARRAY [*] OF Datatype;
	TwoD = ARRAY [*,*] OF Datatype;
	ThreeD = ARRAY [*,*,*] OF Datatype;
	LineHandler* = PROCEDURE {DELEGATE} ( CONST lineInR, lineInI: OneD;  VAR lineOutR, lineOutI: OneD );

	PROCEDURE HandleLines( CONST dataR, dataI: ThreeD;  VAR resdataR, resdataI: ThreeD;  directions: SET;  linehandler: LineHandler );
	VAR templineR, templineI, templine1R, templine1I: OneD;
			rectR, rectI, resrectR, resrectI: TwoD;
			x, y, z, w0, w, h, j, lenX, lenY, lenZ: SIZE;
	BEGIN
		lenX := LEN( dataR, 2 );
		lenY := LEN( dataR, 1 );
		lenZ := LEN( dataR, 0 );
		IF 2 IN directions THEN  (* along x*)
			IF LEN( dataI,0 ) > 0 THEN
				FOR z := 0 TO lenZ - 1 DO
					FOR y := 0 TO lenY - 1 DO linehandler( dataR[z,y,*], dataI[z,y,*], resdataR[z,y,*], resdataI[z,y,*] ) END;
				END;
			ELSE  (*no imaginary input data*)
				NEW( templineI, lenX );
				FOR z := 0 TO lenZ - 1 DO
					FOR y := 0 TO lenY - 1 DO linehandler( dataR[z,y,*], templineI, resdataR[z,y,*], resdataI[z,y,*] ) END;
				END;
			END;
			lenX := LEN( resdataR, 1 );
		END;
		IF 1 IN directions THEN  (* along y*)
			h := lenY;
			w0 := MIN( lenX, ENTIER( cachesize * cachefraction / SIZEOF( Datatype ) / h ) );
			NEW( rectR, h, w0 );
			NEW( rectI, h, w0 );
			NEW( resrectR, h, w0 );
			NEW( resrectI, h, w0 );
			NEW( templineI, h );
			FOR z:=0 TO lenZ -1 DO
				j := 0;
				WHILE j < lenX DO  (*work in slices of full lenY size, but limited with w to avoid cache misses *)
					w := MIN( w0, lenX - j );
					IF 2 IN directions THEN rectR[.. , .. w - 1] := resdataR[z, .. , j..j + w - 1];  rectI[.. , .. w - 1] := resdataI[z, .. , j..j + w - 1];
					ELSE rectR[.. , .. w - 1] := dataR[z, .. , j..j + w - 1];  rectI[.. , .. w - 1] := dataI[z, .. , j..j + w - 1];
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
					resdataR[z, .. , j..j + w - 1] := resrectR[.. , .. w - 1];
					resdataI[z, .. , j..j + w - 1] := resrectI[.. , .. w - 1];
					INC( j, w );
				END;
				lenY := LEN( resdataR, 1 );
			END;
		END;
		IF 0 IN directions THEN  (*additional optimization option: only cut 'rect' out of data if XY plane does not fit into cache by itself (somewhat similar for z dimension) *)
			h := lenZ;
			w0 := MIN( lenX, ENTIER( cachesize * cachefraction / SIZEOF( Datatype ) / h ) );
			NEW( rectR, h, w0 );
			NEW( rectI, h, w0 );
			NEW( resrectR, h , w0 );
			NEW( resrectI, h , w0 );
			NEW( templineI, h );
			FOR y:=0 TO lenY -1 DO
				j := 0;
				WHILE j < lenX DO  (*work in slices of full lenY size, but limited with w to avoid cache misses *)
					w := MIN( w0, lenX - j );
					IF (1 IN directions) OR (2 IN directions) THEN rectR[.. , .. w - 1] := resdataR[.. , y, j..j + w - 1];  rectI[.. , .. w - 1] := resdataI[.. , y, j..j + w - 1];
					ELSE rectR[.. , .. w - 1] := dataR[ .. , y,  j..j + w - 1];  rectI[.. , .. w - 1] := dataI[ .. , y, j..j + w - 1];
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
					resdataR[ .. , y, j..j + w - 1] := resrectR[.. , .. w - 1];
					resdataI[ .. , y, j..j + w - 1] := resrectI[.. , .. w - 1];
					INC( j, w );
				END;
			END;
			lenZ := LEN( resdataR, 0 );
		END;
	END HandleLines;

	PROCEDURE FFT*( CONST inR, inI: ThreeD;  VAR outR, outI: ThreeD;  directions: SET );
	BEGIN
		IF LEN( outR,0 ) = 0 THEN NEW( outR, LEN( inR) ) END;
		IF LEN( outI,0 ) = 0 THEN NEW( outI, LEN( inR) ) END;
		HandleLines( inR, inI, outR, outI, directions, LinearFFT.FFT )
	END FFT;

	PROCEDURE IFFT*( CONST inR, inI: ThreeD;  VAR outR, outI: ThreeD;  directions: SET );
	BEGIN
		IF LEN( outR,0 ) = 0 THEN NEW( outR, LEN( inR) ) END;
		IF LEN( outI,0 ) = 0 THEN NEW( outI, LEN( inR) ) END;
		HandleLines( inR, inI, outR, outI, directions, LinearFFT.IFFT )
	END IFFT;

	PROCEDURE PowerSpectrum*( CONST in: ThreeD; directions:SET): ThreeD;
	VAR nil, R, I: ThreeD;
	BEGIN
		IF LEN( RESULT, 0 ) = 0 THEN NEW( RESULT, LEN( in ) ) END;
		FFT( in, nil, R, I, directions );
		RESULT := R .* R;
		RESULT := RESULT + I .* I;
		RETURN RESULT;
	END PowerSpectrum;

	(** deconvolution is multiplication in the Fourier domain *)
	PROCEDURE Convolution*( CONST in1, in2: ThreeD;  VAR outR, outI: ThreeD );
	VAR R1, I1, R2, I2, nil, tmpR, tmpI: ThreeD;  lenX, lenY: SIZE;
	BEGIN
		lenX := LEN( in1, 1 );  lenY := LEN( in1, 0 );
		FFT( in1, nil, R1, I1, {0, 1} );
		FFT( in2, nil, R2, I2, {0, 1} );
		TensorMath.ComplexMultiplication(R1,I1,R2,I2,tmpR,tmpI);
		IFFT( tmpR, tmpI, outR, outI, {0, 1} );
	END Convolution;

	(** deconvolution is division in Fourier domain:  (a+bi )/(c+di) = (ac+bd)/(c*c+d*d), i*(bc-ad)/(c*c+d*d) *)
	PROCEDURE DeConvolution*( CONST in1, in2: ThreeD;  VAR outR, outI: ThreeD );
	VAR R1, I1, R2, I2, nil, tmpR, tmpI: ThreeD;
	BEGIN
		FFT( in1, nil, R1, I1, {0, 1} );
		FFT(in2, nil, R2, I2, {0, 1} );
		TensorMath.ComplexDivision(R1,I1,R2,I2,tmpR,tmpI);
		IFFT( tmpR, tmpI, outR, outI, {0, 1} );
	END DeConvolution;

	(** crosscorrelation is multiplication in the Fourier domain of the complex conjugate*)
	PROCEDURE CrossCorrelation*( CONST in1, in2: ThreeD;  VAR outR, outI: ThreeD );
	VAR R1, I1, R2, I2, tmpR,tmpI,nil: ThreeD;  lenX, lenY: SIZE;
	BEGIN
		lenX := LEN( in1, 1 );  lenY := LEN( in1, 0 );
		FFT( in1, nil, R1, I1, {0, 1} );
		FFT( in2, nil, R2, I2, {0, 1} );
		TensorMath.ComplexMultiplication(R1,I1,R2,-I2,tmpR,tmpI);
		IFFT(tmpR,tmpI,outR,outI,{0,1});
	END CrossCorrelation;

	PROCEDURE AutoCorrelation*( CONST in: ThreeD ): ThreeD;
	VAR  autocorr, R,I, nil: ThreeD;
	BEGIN
		IF LEN( RESULT, 0 ) = 0 THEN NEW( RESULT, LEN( in ) ) END;
		FFT( in,nil,R,I, {0, 1} );
		autocorr := R.*R; autocorr:= autocorr +  I .* I ;  (* plus sign due to multiplication by complex conjugate "R,I * R,-I" *)
		IFFT( autocorr, nil, RESULT, I, {0, 1} );
		RETURN RESULT
	END AutoCorrelation;
	
		(*filter in the Fourier domain. power of 2 data required.
	filter is in frequency domain, is typically in [0.0 ... 1.0] but might have other values *)
	PROCEDURE Filter*(CONST in, filter: ThreeD): ThreeD;
	VAR  I, nil, R: ThreeD;
	BEGIN
		IF LEN(RESULT) # LEN(in) THEN NEW( RESULT, LEN(in) ) END;
		FFT( in, nil, R, I, {0,1,2});
		R := R .* filter;
		I := I .* filter;
		IFFT( R, I, RESULT, nil, {0,1,2});
		RETURN RESULT
	END Filter;

	(*
	PROCEDURE ComplexMultiplication(CONST R1,I1,R2,I2: ThreeD; VAR outR,outI:ThreeD);
	BEGIN
		outR := R1 .* R2;   (*(a+bi )*(c+di) = (ac-bd), i*(bc+ad) *)
		outR := outR - I1 .* I2;
		outI := I1 .* R2; outI := outI + R1 .* I2;
	END ComplexMultiplication;

	PROCEDURE ComplexDivision(CONST R1,I1,R2,I2: ThreeD; VAR outR,outI:ThreeD);
	VAR rsqr:ThreeD;
	BEGIN
		rsqr:=R2.*R2;  rsqr:= rsqr + I2 .*I2;
		outR := R1 .* R2;   outR := outR + I1 .* I2;
		outI := I1 .* R2;  outI := outI - R1 .* I2;
		outR:= outR ./ rsqr;
		outI:= outI ./ rsqr;
	END ComplexDivision;
	*)
	
	(*
	PROCEDURE Test*;
	VAR a,b,c,d, i, r: ThreeD;
	BEGIN
		NEW(r, 8,8,8);
		NEW(i, 8,8,8);
		NEW(a, 8,8,8);
		NEW(b, 8,8,8);
		r[4..6,4..6,4..6]:=1;
		FFT(r,i,a,b,{0,1,2});
		IFFT(a,b,c,d, {0,1,2});
		MatrixUtilities.Out(c); (*expected: c[4..6,4..6,4..6] = 1 *)
		MatrixUtilities.Out(r-c); (*expected = 0 *)
	END Test;
	*)
END VolumeFFT.

System.FreeDownTo VolumeFFT ~

VolumeFFT.Test ~

