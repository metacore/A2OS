MODULE LinearConvolve;

IMPORT Filters:=LinearFilters, SYSTEM, FIR:=LinearFIRConvolveLongReal,  IIR:=LinearIIRConvolveLongReal, MatrixBase;

TYPE
	Datatype=MatrixBase.Datatype;
	Dataarray* = ARRAY [*] OF Datatype;
	Rect*=ARRAY [*,*] OF Datatype;
	Cube*=ARRAY [*,*,*] OF Datatype;
	Signal* = ARRAY [*] OF Datatype;

CONST
	(*cachesize = 512 * 1024;*)
	finite* = Filters.finite;
	periodic* = Filters.cyclicH;
	mirrorH* = Filters.mirrorH;  mirrorW* = Filters.mirrorW;
	antimirrorH* = Filters.antimirrorH;   antimirrorW* = Filters.antimirrorW;
	default* = -1;

TYPE
	ConvolveProc=PROCEDURE {DELEGATE} (CONST filter, data: Dataarray; VAR result:Dataarray);
	(**Convolution f(t)*g(-t);  *)
	Convolver* = OBJECT
	VAR temp, temp2, tmpLo, tmpResLo, coeffs: Dataarray;
		gain:Datatype; (*for iir convolution*)
		filter-: Filters.Filter;
		firConvolve:ConvolveProc;
		boundary*,shift*: SIGNED32;
		tmp:SIZE;

		(** Filters need to have their coefficients already transposed g(-tau)  for good  performance  *)
		PROCEDURE &Init*(filter:Filters.Filter; boundary: SIGNED32);
		VAR i:SIZE; 
		BEGIN
			SELF.filter:=filter;
			SELF.boundary:=boundary;
			SELF.shift:=0; (*default*)
			IF filter=NIL THEN RETURN
			ELSIF filter IS Filters.FIRFilter THEN
				firConvolve:=FIR.Convolve;
				NEW(coeffs, LEN(filter(Filters.FIRFilter).coeff,0)); (*temporary, until old and new arrays are more compatible *)
				FOR i:=0 TO LEN(coeffs,0)-1 DO coeffs[i]:=filter( Filters.FIRFilter ).coeff[i] END;
			ELSIF  filter IS Filters.IIRFilter  THEN (*IIR*)
				tmp:= LEN(filter(Filters.IIRFilter).poles,0); (*tmp is debugging variable*)
				NEW(coeffs, tmp);
				FOR i:=0 TO LEN(coeffs,0)-1 DO coeffs[i]:=filter( Filters.IIRFilter).poles[i] END;
				gain:=filter( Filters.IIRFilter).gain;
			ELSE HALT(100); (* to do: replace halt statement*)
			END;
		END Init;
		
		PROCEDURE SetFIRConvolveProc*(firConvolveProc: ConvolveProc);
		BEGIN
			firConvolve:=firConvolveProc;
		END SetFIRConvolveProc;
		

		PROCEDURE convolve*( CONST  data: Dataarray; VAR out: Dataarray );  (*in-place convolution in principle possible but requires some more work on this module*)
		VAR i,  filterlen,  offset: SIZE;  datalen, rawdatalen: SIZE;
		BEGIN
		(*Assertions;*)
			IF filter=NIL THEN HALT(100)
			ELSIF filter IS Filters.FIRFilter THEN
				filterlen := LEN( filter( Filters.FIRFilter ).coeff,0);  datalen := LEN(data,0);
				rawdatalen := LEN(data,0) + 2 * filterlen;   (*SHORTER OVERLENGTH COULD BE IMPLEMENTED*)
				IF (LEN( temp ) # rawdatalen) THEN NEW( temp, rawdatalen );  END;
				IF (LEN( temp2 ) # rawdatalen) THEN NEW( temp2, rawdatalen );  END;
				IF LEN( out ) < LEN(data,0) THEN HALT(100); (*NEW( out, outlen )*) END;
					(*! NEED SETTING temp2 TO ZERO HERE ??*)


				SYSTEM.MOVE( ADDRESSOF( data[0] ), ADDRESSOF( temp[filterlen] ),
										  SIZEOF( Datatype ) * datalen ); (*!TBD: to do efficiently without SYSTEM*)
				CASE boundary OF
				finite:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := 0;  temp[filterlen + datalen + i] := 0;
						END;
				| periodic:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := temp[filterlen + datalen - i - 1];
							temp[filterlen + datalen + i] := temp[filterlen + i];
						END;
				| mirrorH:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := temp[filterlen + i];
							temp[filterlen + datalen + i] := temp[filterlen + datalen - i - 1];
						END;
				| mirrorW:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := temp[filterlen + i + 1];
							temp[filterlen + datalen + i] := temp[filterlen + datalen - i - 2];
						END;
				| antimirrorH:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := -temp[filterlen + i];
							temp[filterlen + datalen + i] := -temp[filterlen + datalen - i - 1];
						END;
				| antimirrorW:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := -temp[filterlen + i + 1];
							temp[filterlen + datalen + i] := -temp[filterlen + datalen - i - 2];
						END;
				ELSE HALT( 100 );
				END;
				(*
				HALT( this is for FLOAT32 data); LDSPConvolveSIMD.ConvolveR4_SSE( ADDRESSOF(coeffs[0])(*addrK*), ADDRESSOF(temp[0])(*addrX*), ADDRESSOF(temp2[0])(*addrY*), LEN( temp ) );
				*)
				(*LDSPConvolve386.ConvolveLR(coeffs, temp,temp2);*)
				firConvolve( coeffs, temp,  temp2 );
				offset := (filterlen - filter( Filters.FIRFilter ).origin);
				out[..datalen-1]:=temp2[offset..offset+datalen-1];
			ELSE (* IIR *)
				CASE boundary OF
				finite: IIR.ConvolveFinite(data,out,coeffs,gain);
				|periodic: IIR.ConvolvePeriodic(data,out,coeffs,gain);
				|mirrorH: IIR.ConvolveMirror(data,out,coeffs,gain);
				ELSE HALT(100); (*not yet implemented*)
				END;
			END;
		END convolve;

		(*
		PROCEDURE convPar;
		VAR i, step, filterlen:SIGNED32;
		BEGIN
			NEW(filter0, (LEN(coeffs,0)*SIZEOF(Datatype) +15 ) DIV 16)
			NEW(filter1, LEN(filter0);
			NEW(filter2, LEN(filter1);
			NEW(filter3, LEN(filter2);
			filter0[0..LEN(coeffs,0)-1]:=coeffs;	(*reverted filter order ??*)
			filter1[1..LEN(coeffs,0)]:=coeffs;
			filter2[2..LEN(coeffs,0)+1]:=coeffs;
			filter3[3..LEN(coeffs,0)+2]:=coeffs;
			filterx:=filter0+filter1+filter2+filter3;
			filterlen:=LEN(filter0);
			FOR i:=0 TO LEN(temp2)-1 BY filterlen DO
				lo:=i*filterlen;
				hi:=lo+filterlen-1;
				out[lo..hi]:= in[lo..hi] .* filterx;
				out[index..]:= in[]
			END;
		END convPar;
		*)

		PROCEDURE convolveDown2*(CONST data:Dataarray; VAR out: Dataarray );
		VAR i, outlen, filterlen, offsetLo, datalen, rawdatalen: SIZE;

		BEGIN
		(*Assertions;*)
			(*IF data=NIL THEN RETURN END;*)
			IF filter=NIL THEN HALT(100)
			ELSIF filter IS Filters.FIRFilter THEN
				filterlen := LEN( filter( Filters.FIRFilter ).coeff,0 );
				 datalen := LEN(data,0);
				outlen :=MIN(LEN(out,0), (datalen + 1) DIV 2);
				rawdatalen := LEN(data,0) + 2 * filterlen;   (*SHORTER OVERLENGTH COULD BE IMPLEMENTED*)
				IF (LEN( temp ) # rawdatalen) THEN NEW( temp, rawdatalen );  END;
				IF (LEN( tmpLo ) # rawdatalen) THEN NEW( tmpLo, rawdatalen )  END;
				temp[filterlen..datalen+filterlen-1]:=data[..datalen-1];
				CASE boundary OF
				finite:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := 0;  temp[filterlen + datalen + i] := 0;
						END;
				| periodic:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := temp[filterlen + datalen - i - 1];
							temp[filterlen + datalen + i] := temp[filterlen + i];
						END;
				| mirrorH:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := temp[filterlen + i];
							temp[filterlen + datalen + i] := temp[filterlen + datalen - i - 1];
						END;
				| mirrorW:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := temp[filterlen + i + 1];
							temp[filterlen + datalen + i] := temp[filterlen + datalen - i - 2];
						END;
				| antimirrorH:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := -temp[filterlen + i];
							temp[filterlen + datalen + i] := -temp[filterlen + datalen - i - 1];
						END;
				| antimirrorW:
						FOR i := 0 TO filterlen - 1 DO
							temp[filterlen - i - 1] := -temp[filterlen + i + 1];
							temp[filterlen + datalen + i] := -temp[filterlen + datalen - i - 2];
						END;
				ELSE HALT( 100 );
				END;
				FIR.ConvolveDown2(coeffs, temp, tmpLo, shift );
				offsetLo := (filterlen - filter( Filters.FIRFilter ).origin) DIV 2;
				out[..outlen-1]:=tmpLo[offsetLo..offsetLo+outlen-1];
			ELSE (*IIR*) HALT(100); (* ? user here the IIR_à_trous filter from DSPCWT.Mod*)
			END
		END convolveDown2;

		PROCEDURE convolveUp2*( CONST data:Dataarray; VAR out: Dataarray );   (*use even/odd*)
		VAR i,  outlen, filterlen, offsetLo,halffilterlen, halfLenPlus, datalen: SIZE;

		BEGIN
		(*Assertions;*)
		(*only limited testing; look up the code in CreaCompress...*)
		(*IF data=NIL THEN RETURN END;*)  (*'data' is expected to contain an array with ((n+1) DIV 2) lowpass & (n DIV 2) highpass elements with border conditions not yet handled; *)
			IF filter=NIL THEN HALT(100)
			ELSIF filter IS Filters.FIRFilter THEN
				filterlen := LEN( filter( Filters.FIRFilter ).coeff,0 );
				(*halffilterlen:=MAX(filter(Filters.FIRFilter).origin, filterlen-filter(Filters.FIRFilter).origin);*)

				halffilterlen := (filterlen + 1) DIV 2;
				datalen := LEN(data,0);  halfLenPlus := (datalen + 1) DIV 2;
				outlen :=  MIN(LEN(out,0), 2*datalen);

				IF	 (LEN( tmpLo ) # datalen + 2 * halffilterlen) THEN
					 NEW( tmpLo,	 datalen + 2 * halffilterlen )
				END;
				IF (	LEN( tmpResLo )#	 2 * datalen + 2 * filterlen) THEN
					NEW( tmpResLo,	 2 * datalen + 2 * filterlen (*outlen*) )
				END;

				tmpLo[halffilterlen..halffilterlen+datalen-1] := data[..datalen-1];
				CASE boundary OF
				finite:
						HALT( 100 );
				| periodic:
						HALT( 100 );
				| mirrorH:
						IF ODD( datalen ) THEN
							FOR i := 0 TO halffilterlen - 1 DO
								tmpLo[halffilterlen - i - 1] := tmpLo[halffilterlen + i];
								tmpLo[halffilterlen + datalen (*halfLenPlus*) + i - 1] :=
									tmpLo[halffilterlen + datalen (*halfLenPlus*) - i - 1];   (*i.e. W symmetry in odd data case*)
							END;
						ELSE
							FOR i := 0 TO halffilterlen - 1 DO
								tmpLo[halffilterlen - i - 1] := tmpLo[halffilterlen + i];
								tmpLo[halffilterlen + datalen (*halfLenPlus*) + i] :=
									tmpLo[halffilterlen + datalen (*halfLenPlus*) - i - 1];
							END;
						END;
				| mirrorW:
						HALT( 100 );
				| antimirrorH:
						HALT( 100 );
				| antimirrorW:
						HALT( 100 );
				ELSE HALT( 100 );
				END;
				FIR.ConvolveUp2( coeffs, tmpLo, tmpResLo, shift );
				offsetLo := -filter( Filters.FIRFilter ).origin;
				out[..outlen-1]:=tmpResLo[2 * halffilterlen + offsetLo .. 2 * halffilterlen + offsetLo + outlen-1];
			ELSE (*IIR*) HALT(100);
			END;
		END convolveUp2;

	END Convolver;

BEGIN
END LinearConvolve.

fofPC.Compile \s *
OFormatter.Format *



--------------------------------
"FIR à trous filter" from DSPCWT.Mod
	PROCEDURE firConvolveMirrorATrous( in: Data;  VAR out: Data;  filter: DSPFilters.FIRFilter;  iup: SIGNED32 );
	VAR nx, nw, i, k, k1, k2, kn, k0: SIGNED32;  yaux: FLOAT64;
	BEGIN
		IF (out = NIL ) OR (LEN( out^ ) < LEN( in^ )) THEN NEW( out, LEN( in^ ) ) END;
		nx := LEN( in^ );  nw := LEN( filter.coeff^ );  kn := 2 * nx;
		FOR k := 0 TO nx - 1 DO
			yaux := 0;
			FOR i := 0 TO nw - 1 DO
				k2 := k + iup * (i - filter.hotspot);
				IF k2 < 0 THEN k2 := -k2 - 1 END;
				IF (k2 >= nx) THEN
					k2 := k2 MOD kn;
					IF (k2 >= nx) THEN k2 := kn - k2 - 1 END;
				END;
				yaux := yaux + LONG( in[k2] ) * filter.coeff[i];
			END;
			out[k] := SHORT( yaux );
		END;
	END firConvolveMirrorATrous;



"IIR à trous" filter from DSPCWT.Mod:
	PROCEDURE iirConvolveMirrorATrous*( in: Data;  VAR out: Data;  filter: DSPFilters.IIRFilter;  iup: SIGNED32 );
	(**	Discrete recursive convolution:
				signal has infinite, periodic support  2*LEN(in)
				data [LEN(in)..2*LEN(in)-1] = mirror image of data[0..LEN(in)-1]
				kernel is given by its real poles
		Preconditions:
				input and output may use the same array *)
	CONST OneDivLn10 = 0.434294483456101D0;
		tolerance = -15.9;   (*log10(eps) *)

	VAR i, j, k, n, n2: SIGNED32;  x0, pole: FLOAT64;
		tempfilter: POINTER TO ARRAY OF FLOAT64;
	BEGIN
		ASSERT ( (in # NIL ) & (filter # NIL ) & (LEN( filter.poles^ ) > 0), 100 );
		IF (out = NIL ) OR (LEN( out ) < LEN( in )) THEN NEW( out, LEN( in^ ) ) END;   (*ASSERT(LEN(in)<=LEN(out),101);*)
		n := LEN( in );
		FOR k := 0 TO n - 1 DO out[k] := in[k] * filter.gain END;
		IF n = 1 THEN RETURN END;
		NEW( tempfilter, iup * LEN( filter.poles ) );
		FOR i := 0 TO LEN( filter.poles ) - 1 DO tempfilter[iup * i] := filter.poles[i] END;
		n2 := 2 * (LEN( in ) - 1);
		FOR i := 0 TO LEN( tempfilter ) - 1 DO  (*minor optimisation possible by using "FOR i:=0 TO LEN(tempfilter)-1 TO xx BY iup DO"*)
			pole := tempfilter[i];
			IF pole # 0 THEN
				j := ENTIER( tolerance / MathL.ln( ABS( pole ) ) * OneDivLn10 ) + 1;  k := j - n2 * (j DIV n2);  j := j - k;
				IF k < n THEN x0 := out[k]
				ELSE
					x0 := out[n2 - k];
					FOR k := n2 - k + 1 TO n - 1 DO x0 := pole * x0 + out[k] END;
				END;
				FOR k := n - 1 TO 0 BY -1 DO x0 := pole * x0 + out[k] END;
				WHILE j > 0 DO
					FOR k := 1 TO n - 1 DO x0 := pole * x0 + out[k] END;
					FOR k := n - 2 TO 0 BY -1 DO x0 := pole * x0 + out[k] END;
					j := j - n2;
				END;
				out[0] := SHORT( x0 );  x0 := out[n - 1];
				FOR k := 1 TO n - 1 DO out[k] := SHORT( out[k] + out[k - 1] * pole ) END;
				out[n - 1] := SHORT( (2 * out[n - 1] - x0) / (1 - pole * pole) );
				FOR k := n - 2 TO 0 BY -1 DO out[k] := SHORT( out[k] + out[k + 1] * pole ) END;
			END;
		END;
	END iirConvolveMirrorATrous;

