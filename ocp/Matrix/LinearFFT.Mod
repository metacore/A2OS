(* inspired by fourier.pas  -  Don Cross <dcross@intersrv.com> *)
(* based on ejz  , PH 070923*)

MODULE LinearFFT;

IMPORT MatrixBase, LinearMath, Mathe:=MathL;

TYPE Datatype=MatrixBase.Datatype;
	Array = ARRAY [*] OF Datatype;

	PROCEDURE IsPowerOfTwo(x: SIZE): BOOLEAN;
	BEGIN
		WHILE (x MOD 2) = 0 DO
			x := x DIV 2
		END;
		RETURN x = 1
	END IsPowerOfTwo;

	PROCEDURE NumberOfBitsNeeded(x: SIZE): SIGNED32;
		VAR n: SIGNED32;
	BEGIN
		n := 0;
		WHILE x > 1 DO
			x := x DIV 2; INC(n)
		END;
		RETURN n
	END NumberOfBitsNeeded;

	PROCEDURE ReverseBits(x, n: SIGNED32): SIGNED32;
		VAR i, rev: SIGNED32;
	BEGIN
		rev := 0; i := 0;
		WHILE i < n DO
			rev := 2*rev + (x MOD 2);
			x := x DIV 2; INC(i)
		END;
		RETURN rev
	END ReverseBits;

	PROCEDURE Transform(fullAngle: Datatype; nSamples: SIZE; CONST realIn, imagIn: Array;  VAR  realOut, imagOut: Array); (*SSE2 would allow much faster version*)
		VAR
			angle, alpha, beta, ar, ai, tr, ti, tmp: Datatype;
			nBits, i, j, k, n, size, end: SIGNED32;
	BEGIN
		ASSERT((nSamples > 1) & IsPowerOfTwo(nSamples));
		nBits := NumberOfBitsNeeded(nSamples);
		i := 0;
		WHILE i < nSamples DO
			j := ReverseBits(i, nBits);
			realOut[j] := realIn[i];
			IF LEN(imagIn)>0 THEN imagOut[j] := imagIn[i]; END;
			INC(i)
		END;
		end := 1; size := 2;
		WHILE size <= nSamples DO
			angle := fullAngle / size;
      	  alpha := Mathe.sin(0.5 * angle);
			alpha := 2.0 * alpha * alpha;
			beta := Mathe.sin(angle);
			i := 0;
			WHILE i < nSamples DO
				ar := 1.0; ai := 0.0; (* cos(0) / sin(0) *)
				j := i; n := 0;
				WHILE n < end DO
					k := j + end;
					tr := ar*realOut[k] - ai*imagOut[k];
					ti := ar*imagOut[k] + ai*realOut[k];
					realOut[k] := realOut[j] - tr;
					imagOut[k] := imagOut[j] - ti;
					realOut[j] := realOut[j] + tr;
					imagOut[j] := imagOut[j] + ti;
					tmp := alpha*ar + beta*ai;
					ai := ai - (alpha*ai - beta*ar);
					ar := ar - tmp;
					INC(j); INC(n)
				END;
				i := i + size;
			END;
			end := size; size := size * 2
		END
	END Transform;

	PROCEDURE FFT*(CONST realIn, imagIn: Array; VAR realOut, imagOut: Array);
	BEGIN
		IF LEN(realOut,0) = 0 THEN NEW( realOut, LEN( realIn,0) ) END;
		IF LEN( imagOut ) = 0 THEN NEW( imagOut, LEN( realIn,0) ) END;
		Transform(2*Mathe.pi, LEN(realIn,0), realIn, imagIn, realOut, imagOut)
	END FFT;

	(* frequency = index / (nSamples / SamplingRate) *)
	PROCEDURE Frequency*(nSamples, index: SIGNED32; CONST realIn, imagIn: Array; VAR realOut, imagOut: Datatype);
		VAR
			beta, cos1, cos2, cos3, sin1, sin2, sin3, theta: Datatype;
			i: SIGNED32;
	BEGIN
		realOut := 0.0; imagOut := 0.0;
		theta := 2*Mathe.pi * index / nSamples;
		sin1 := Mathe.sin(-2 * theta); sin2 := Mathe.sin(-theta);
		cos1 := Mathe.cos(-2 * theta); cos2 := Mathe.cos(-theta);
		beta := 2 * cos2;
		i := 0;
		WHILE i < nSamples DO
			sin3 := beta*sin2 - sin1;
			sin1 := sin2; sin2 := sin3;
			cos3 := beta*cos2 - cos1;
			cos1 := cos2; cos2 := cos3;
			realOut := realOut + realIn[i]*cos3 - imagIn[i]*sin3;
			imagOut := imagOut + imagIn[i]*cos3 + realIn[i]*sin3;
			INC(i)
		END
	END Frequency;

	PROCEDURE IFFT*(CONST realIn, imagIn: Array; VAR realOut, imagOut: Array);
		VAR nSamples: SIZE;
	BEGIN
		nSamples:=LEN(realIn,0);
		IF LEN(realOut,0) = 0 THEN NEW( realOut, LEN(realIn,0) ) END;
		IF LEN( imagOut ) = 0 THEN NEW( imagOut, LEN(realIn,0) ) END;
		Transform(-2*Mathe.pi, nSamples, realIn, imagIn, realOut, imagOut);
		realOut[0..nSamples-1] := 1/nSamples * realOut[0..nSamples-1];
		imagOut[0..nSamples-1] := 1/nSamples * imagOut[0..nSamples-1];
	END IFFT;


	PROCEDURE PowerSpectrum*(CONST in: Array ): Array;
	VAR nil, R, I: Array;
	BEGIN
		IF LEN( RESULT ) = 0 THEN NEW( RESULT, LEN(in,0) ) END;
		FFT( in, nil, R, I );
		RESULT := R .* R;
		RESULT := RESULT + I .* I;
		RETURN RESULT;
	END PowerSpectrum;

 (** convolution is multiplication in the Fourier domain:  (a+bi )*(c+di) = (ac-bd), i*(bc+ad) *)
	PROCEDURE Convolution*( CONST in1, in2: Array;  VAR outR, outI: Array );
	VAR R1, I1, R2, I2, nil, tmpR, tmpI: Array;
	BEGIN
		FFT( in1, nil, R1, I1 );
		FFT( in2, nil, R2, I2 );
		LinearMath.ComplexMultiplication(R1,I1,R2,I2,tmpR,tmpI);
		IFFT( tmpR, tmpI, outR, outI );
	END Convolution;

	(** deconvolution is division in Fourier domain:  (a+bi )/(c+di) = (ac+bd)/(c*c+d*d), i*(bc-ad)/(c*c+d*d) *)
	PROCEDURE DeConvolution*( CONST in1, in2: Array;  VAR outR, outI: Array );
	VAR R1, I1, R2, I2, nil, tmpR, tmpI,rsqr: Array; i:SIGNED32;
	BEGIN
		FFT( in1, nil, R1, I1 );
		FFT(in2, nil, R2, I2 );
		LinearMath.ComplexDivision(R1,I1,R2,I2,tmpR,tmpI);
		IFFT( tmpR, tmpI, outR, outI );
	END DeConvolution;

	 (** crosscorrelation is multiplication in the Fourier domain of the complex conjugate*)
	PROCEDURE CrossCorrelation*( CONST in1, in2: Array;  VAR outR, outI: Array );
	VAR R1, I1, R2, I2, tmpR,tmpI,nil: Array;
	BEGIN
		FFT( in1, nil, R1, I1 );
		FFT( in2, nil, R2, I2 );
		LinearMath.ComplexMultiplication(R1,I1,R2,-I2,tmpR,tmpI);
		IFFT(tmpR,tmpI,outR,outI);
	END CrossCorrelation;

	PROCEDURE AutoCorrelation*(CONST in: Array ): Array;
	VAR  I, nil,autocorr: Array;
	BEGIN
		IF LEN( RESULT, 0 ) = 0 THEN NEW( RESULT, LEN( in,0 ) ) END;
		FFT( in, nil, autocorr, I);
		autocorr := autocorr .* autocorr; autocorr:=autocorr + I .*  I; (*plus sign because this is multiply by complex conjugate*)
		IFFT( autocorr, nil, RESULT, I);
		RETURN RESULT
	END AutoCorrelation;

	(*filter in the Fourier domain. power of 2 data required.
	filter is in frequency domain, is typically in [0.0 ... 1.0] but might have other values *)
	PROCEDURE Filter*(CONST in, filter: Array ): Array;
	VAR  I, nil, R: Array;
	BEGIN
		IF LEN( RESULT, 0 ) = 0 THEN NEW( RESULT, LEN( in,0 ) ) END;
		FFT( in, nil, R, I);
		R := R .* filter;
		I := I .* filter;
		IFFT( R, I, RESULT, nil);
		RETURN RESULT
	END Filter;

#IF TEST THEN
	TYPE Success=OBJECT END Success;
	PROCEDURE TEST*():ANY;  
	VAR image, imageI, resR, resI, res2R, res2I, res3R, res3I, diff, fft: MatrixBase.Vector;  
		success:Success;
	BEGIN 
		NEW( image, 256);  NEW( imageI, 256);  
		image[60..63] := 1;  image[70..73] := 1;  
		FFT( image, imageI, resR, resI);  
		IFFT( resR, resI, res2R, res2I);  
		diff:=image-res2R;
		IF diff+*diff < 0.0001 THEN NEW(success) END; 
		RETURN success;
	END TEST;
#END;

END LinearFFT.

System.FreeDownTo LinearFFT~
