MODULE LinearFIRConvolveLongReal;	(** Patrick Hunziker & dk(assembler)   **)
(** implements basic FIR convolutions for convolve, convolve+downsample, convolve+upsample *)

IMPORT LinearFilters;

PROCEDURE Convolve*(CONST filter:ARRAY[*]  OF FLOAT64; CONST data:ARRAY [*] OF FLOAT64; VAR result:ARRAY [*] OF FLOAT64);
VAR d,filterlen,reslen:SIZE;
BEGIN
	filterlen:=LEN(filter,0);
	IF LEN(data,0)<LEN(result,0) THEN reslen:=LEN(data,0) ELSE reslen:=LEN(result,0) END;
	FOR d:= 0 TO reslen-filterlen DO
		result[d]:= data[d..d+filterlen-1] +* filter;
	END;
END Convolve;

PROCEDURE ConvolveDown2*(CONST filter:ARRAY[*]  OF FLOAT64;  CONST data:ARRAY [*] OF FLOAT64;VAR result:ARRAY [*] OF FLOAT64; shift:SIZE);
VAR d,filterlen,datalen,resPos:SIZE;
BEGIN
	ASSERT(shift IN {0,1},200); (* this is used for even/odd algorithm variants *)
	IF LEN(result,0) < LEN(data,0) DIV 2 THEN datalen:=2* LEN(result,0) ELSE datalen:= LEN(data,0) END;
	filterlen:=LEN(filter,0);
	result:=0;
	FOR d:= shift TO datalen-filterlen-1(*??-1*) BY 2 DO
		resPos:=d DIV 2 ;	(* downsampling *)
		result[resPos]:= data[d..d+filterlen-1] +* filter;
	END;
END ConvolveDown2;

PROCEDURE ConvolveUp2_scalar(CONST filter:ARRAY[*]  OF FLOAT64; CONST data: ARRAY [*] OF FLOAT64;VAR result:ARRAY [*] OF FLOAT64; shift:SIZE);
	(** upsampling by 2 and convolution with filter; admissible types should include all basic Oberon number types *)
VAR f,d,filterlen,reslen,filterstart:SIZE;
BEGIN
	ASSERT(shift IN {0,1},200); (* this is used for even/odd algorithm variants *)
	(* in simpler, slow variant, upsampling (shifted by shift) into a temp array is followed by standard FIRConvolve*)
	IF LEN(result,0) < 2 * LEN(data,0) THEN reslen:=LEN(result,0) ELSE reslen:=2*LEN(data,0) END;
	filterlen:=LEN(filter,0);
	FOR d:= 0 TO reslen-filterlen DO
		result[d]:=0;
		IF ODD(d+shift) THEN filterstart:=1 ELSE filterstart:=0 END;
		FOR f:=filterstart TO filterlen-1 BY 2 DO
			result[d]:=data[(d+f ) DIV 2 ]*filter[f] + result[d]
		END;
		(*write as matrix expression.. *)
	END;
END ConvolveUp2_scalar;

(* rewritten as array math, not fully tested *)
PROCEDURE ConvolveUp2*(CONST filter:ARRAY[*]  OF FLOAT64; CONST data: ARRAY [*] OF FLOAT64;VAR result:ARRAY [*] OF FLOAT64; shift:SIZE);
	(** upsampling by 2 and convolution with filter; admissible types should include all basic Oberon number types *)
VAR d,filterlen,reslen,filterstart:SIZE;
BEGIN
	ASSERT(shift IN {0,1},200); (* this is used for even/odd algorithm variants *)
	(* in simpler, slow variant, upsampling (shifted by shift) into a temp array is followed by standard FIRConvolve*)
	IF LEN(result,0) < 2 * LEN(data,0) THEN reslen:=LEN(result,0) ELSE reslen:=2*LEN(data,0) END;
	filterlen:=LEN(filter,0);
	FOR d:= 0 TO reslen-filterlen DO
		result[d]:=0;
		IF ODD(d+shift) THEN filterstart:=1 ELSE filterstart:=0 END;
		result[d]:=data[(d+filterstart) DIV 2..(d+filterlen-1) DIV 2 ] +* filter[filterstart..filterlen-1 BY 2] 
	END;
END ConvolveUp2;

PROCEDURE {TEST} Test*;
VAR a,b,c,d: ARRAY [*] OF FLOAT64;
	down,up: LinearFilters.Filter;
BEGIN
	a:=[0,1,2,3,4,5,6,7,6,5,4,3,2,1,0,1,2,3,4,5,6,7,6,5,4,3,2,1,0,1,2,3,4,5,6,7,6,5,4,3,2,1,0,1,2,3,4,5,6,7,6,5,4,3,2,1,0,1,2,3,4,5,6,7,6,5,4,3,2,1,0,1,2,3,4,5,6,7,6,5,4,3,2,1,0];
	NEW(b,LEN(a));
	NEW(c,LEN(a));
	NEW(d,LEN(a));
	
	down:=LinearFilters.CreateSplineFilter(142); (*down*)
	up:=LinearFilters.CreateSplineFilter(152); (*up*)
	ConvolveDown2(down(LinearFilters.FIRFilter).coeff,a,b,0);
	ConvolveUp2(up(LinearFilters.FIRFilter).coeff,b,c,0);
	ConvolveUp2_scalar(up(LinearFilters.FIRFilter).coeff,b,d,0);
	ASSERT(c=d);
END Test;

END LinearFIRConvolveLongReal.

LinearFIRConvolveLongReal.Test ~

System.FreeDownTo LinearFIRConvolveLongReal ~
Decoder.Decode FIRConvolveReal~

------------------------
System.Log output:


Builder.Compile *
fofPC.Compile \s *
