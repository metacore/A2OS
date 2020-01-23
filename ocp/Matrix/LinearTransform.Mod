MODULE LinearTransform;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "";  **)

IMPORT PlanarBase, LinearConvolve, Wavelets, Filters:=LinearFilters, MatrixBSplineInterpolation, MatrixUtilities;

TYPE
	Datatype* = PlanarBase.Datatype;  Dataarray* = ARRAY [ * ] OF Datatype;
	Line* = ARRAY [ *  ] OF Datatype;
	Cube* = ARRAY [ * , * , * ] OF Datatype;
	Signal* = ARRAY [ * ] OF Datatype;
	Transformer=OBJECT (*!  to do: implement transformer object, also for higher dimensions *)
	(*!  to do: is this needed or is LinearConvolve sufficient ? -> move stuff to that module *)
	END Transformer;

CONST
	finite* = Filters.finite;  periodic* = Filters.cyclicH;
	mirrorH* = Filters.mirrorH;  mirrorW* = Filters.mirrorW;
	antimirrorH* = Filters.antimirrorH; antimirrorW* = Filters.antimirrorW;

	PROCEDURE toSpline*( CONST in: Line;  VAR out: Line;  splinedegree: SIGNED32 );
	BEGIN
		IF splinedegree IN {0,1} THEN out:=in; RETURN END;
		IF (LEN(out,0)=0) & (LEN(in,0)#0) THEN NEW( out, LEN(in,0)) END;
		Filter( in, out, Filters.CreateSplineFilter( Filters.DirectBSpline0 + splinedegree ), mirrorH );  (* this boundary combination does not lead to perfect reconstructino at the boundaries when combined with the same boundariies in the inverse operation *)
	END toSpline;

	PROCEDURE fromSpline*( CONST in: Line;  VAR out: Line;  splinedegree: SIGNED32);
	BEGIN
		IF splinedegree IN {0,1} THEN out:=in; RETURN END;
		IF (LEN(out,0)=0) & (LEN(in,0)#0) THEN NEW( out, LEN(in,0)) END;
		Filter( in, out, Filters.CreateSplineFilter( Filters.InverseBSpline0 + splinedegree ), mirrorH );
	END fromSpline;

	PROCEDURE Filter*( CONST data: Line;  VAR resdata: Line;  filter: Filters.Filter;  boundary: SIGNED32 );
	VAR convolver: LinearConvolve.Convolver;
	BEGIN
		IF filter = NIL THEN resdata := data;  RETURN END;
		IF (LEN(resdata,0)=0) & (LEN(data,0)#0) THEN NEW( resdata, LEN(data,0)) END;
		NEW( convolver, filter, boundary );
		convolver.convolve(data,resdata)
	END Filter;

	(* possible filters: Filters.CreateSplineFilter( Filters.LeastSquareSpline0Down2 + splinedegree ) *)  (*ToDo: IN_PLACE !!*)

	PROCEDURE Reduce*( CONST data: Line;  VAR resdata: Line;  filter: Filters.Filter;  boundary: SIGNED32 );
	VAR convolver: LinearConvolve.Convolver;
	BEGIN
		IF (LEN(resdata,0)=0) & (LEN(data,0)#0) THEN NEW( resdata, (LEN(data,0)+1)DIV 2) END;
		IF filter = NIL THEN resdata:= Reduce2(data);
		ELSE NEW( convolver, filter, boundary );  convolver.convolveDown2(data,resdata);
		END;
	END Reduce;

	(* possible filters: Filters.CreateSplineFilter( Filters.LeastSquareSpline0Up2 + splinedegree ) *)  (*todo:  in-place*)

	PROCEDURE Expand*( CONST data: Line;  VAR resdata: Line;  filter: Filters.Filter; boundary: SIGNED32 );
	VAR convolver: LinearConvolve.Convolver;
	BEGIN
	(*to do: check sizes, check filter*)  (*check for in-place*)
		IF (LEN(resdata,0)=0) & (LEN(data,0)#0) THEN NEW( resdata, LEN(data,0)* 2) END;
		IF filter = NIL THEN resdata:=Expand2(data)
		ELSE NEW( convolver, filter, boundary );  convolver.convolveUp2(data,resdata);
		END;
	END Expand;

(*
	PROCEDURE clamp(x:SIGNED32; low,high:SIGNED32):SIGNED32;
	BEGIN
		(*RETURN MIN(high,MAX(x,low)); *)
		IF x<low THEN RETURN low ELSIF x>high THEN RETURN high ELSE RETURN x END;
	END clamp;
	*)
(*!  to do: implement  resampling*)
(*
(** Resampling of input data, starting from x0,y0, in increments of dx,dy; if upscaling (dx,dy>1), then )
	Input: data: spline coefficients of "splinedegree"; allocated 'resdata' of desired size; boundary: see Filters.Mod for boundary types
	Output: resampled data in 'resdata' *)
	PROCEDURE Resample*( CONST data: Line;  VAR resdata: Line;  x0, y0, dx, dy: Datatype;  splinedegree, boundary: SIGNED32 );
	VAR w: Line;  indices: ARRAY [ * ] OF SIGNED32;
		temp: Line;  x, y: SIGNED32;  v: Signal;  x1,x2,y1,y2,Dx,Dy:SIGNED32; ddx,ddy:Datatype;
	BEGIN
		NEW( temp, LEN( data, 0 ), LEN( resdata, 1 ) );
		NEW( v, LEN( resdata, 1 ) );
		CASE splinedegree OF
		0: (* nearest neighbour *)
			FOR y:=0 TO LEN(resdata,0)-1 DO
				FOR x:=0 TO LEN(resdata,1)-1 DO
					resdata[y,x]:=data[clamp(ENTIER(0.5+y0+y/dy),0,LEN(data,0)-1), clamp(ENTIER(0.5+x0+x/dx),0,LEN(data,1)-1)]
				END;
			END;
		|1: (*linear interpolation*)
			FOR y:=0 TO LEN(resdata,0)-1 DO
				FOR x:=0 TO LEN(resdata,1)-1 DO
					Dx:=ENTIER(x/dx);
					Dy:=ENTIER(y/dy);
					ddx:=x/dx-Dx;
					ddy:=y/dy-Dy;
					y1:=clamp(ENTIER(y0+y/dy),0,LEN(data,0)-1); y2:=clamp(ENTIER(1+y0+y/dy),0,LEN(data,0)-1);
					x1:=clamp(ENTIER(x0+x/dx),0,LEN(data,1)-1); x2:=clamp(ENTIER(1+x0+x/dx),0,LEN(data,1)-1);
					resdata[y,x]:=(1-ddx)*(1-ddy)*data[y1,x1] + (1-ddx)*(ddy)*data[y2,x1] + (ddx)*(1-ddy)*data[y1,x2] + (ddx)*(ddy)*data[y2,x2];
				END;
			END;
		|3: (*cubic spline interpolation; precondition: data is in spline domain of 3rd order *)
			w := MatrixBSplineInterpolation.LineInterpolationWeights( LEN( data, 1 ), LEN( resdata, 1 ), 3, 0, (LEN( data, 1 ) - 1) / (LEN( resdata, 1 ) - 1), indices );
			FOR y := 0 TO LEN( data, 0 ) - 1 DO v := MatrixBSplineInterpolation.InterpolateLine( data[y], w, indices );  temp[y] := v;  END;
			NEW( indices, 0 );  NEW( w, 0, 0 );  NEW( v, LEN( resdata, 0 ) );
			w := MatrixBSplineInterpolation.LineInterpolationWeights( LEN( data, 0 ), LEN( resdata, 0 ), 3, 0, (LEN( data, 0 ) - 1) / (LEN( resdata, 0 ) - 1), indices );
				(*to do: offer different versions in sampling complexity*)
			FOR x := 0 TO LEN( resdata, 1 ) - 1 DO v := MatrixBSplineInterpolation.InterpolateLine( temp[.. , x], w, indices );  resdata[.. , x] := v;  END;
				(*to do: offer different versions in sampling complexity*)
		ELSE Out.String("PlanarTransform.Resample: spline degree not implemented"); Out.Ln;
		END;
	END Resample;

(*	PROCEDURE resample( CONST data: ARRAY OF Datatype;  VAR res: ARRAY OF Datatype );
	END resample;

	PROCEDURE Resample2D( CONST data: Line;  VAR resdata: Line;  filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	END Resample2D;
*)
*)
	PROCEDURE Reduce2( CONST g: Line ): Line;
	BEGIN
		IF LEN( RESULT, 0 ) # ((LEN( g, 0 ) + 1) DIV 2) THEN NEW( RESULT, (LEN( g, 0 ) + 1) DIV 2) END;
		RESULT[ .. (LEN( g, 0 ) + 1) DIV 2 - 1] := g[.. BY 2];
		RESULT[ .. (LEN( g, 0 ) + 1) DIV 2 - 1] := RESULT[ .. (LEN( g, 0) + 1) DIV 2 - 1] + g[1 .. BY 2];
		RESULT[ .. (LEN( g, 0 ) + 1) DIV 2 - 1] := 0.5 * RESULT[ .. (LEN( g, 0 ) + 1) DIV 2 - 1];  (*average*)
		IF ODD( LEN( g, 0 ) ) THEN
			RESULT[(LEN( g, 0) + 1) DIV 2 - 1] := 2 * RESULT[(LEN( g, 0 ) + 1) DIV 2 - 1];   (*missing contributions to this boundary data*)
		END;
		RETURN RESULT
	END Reduce2;

	PROCEDURE Expand2( CONST g: Line ): Line;
	BEGIN
		IF (LEN( g, 0 ) # ((LEN( RESULT, 0 ) + 1) DIV 2))  THEN NEW( RESULT, 2 * LEN( g, 0 ) ) END;
		RESULT[.. BY 2] := g[.. (LEN( RESULT, 0 ) + 1) DIV 2 - 1];
		RESULT[1.. BY 2] := g[ .. (LEN( RESULT, 0 ) + 0) DIV 2 - 1];
		RETURN RESULT
	END Expand2;

(* to do: make order of dimensions for analyse/reconstruct consistent (e.g., 1->2->3, on way back: 3->2->1 *)
	PROCEDURE Wavelet*( CONST data: Line;  VAR resdata: Line;  wavelet: Wavelets.WaveletFamily;  boundary: SIGNED16;  analyze: BOOLEAN );
	VAR waveconvolver: Wavelets.WaveletConvolver;
	BEGIN
		IF wavelet = NIL THEN HALT( 100 ) END;
		NEW( waveconvolver, wavelet, boundary );
		IF analyze THEN waveconvolver.Analyze(data,resdata);
		ELSE waveconvolver.Reconstruct(data,resdata);
		END;
	END Wavelet;

	PROCEDURE Test*;
	VAR m, m0, m1, m2,m3,m4, m5, m6, m7: Line;
	BEGIN
		m := [0,0,0,0,0,0,1,0,0,0,0,0,0];
		toSpline(m,m0,0);
		MatrixUtilities.OutVector(m0);
		toSpline(m,m1,1);
		MatrixUtilities.OutVector(m1);
		toSpline(m,m2,2);
		MatrixUtilities.OutVector(m2);
		toSpline(m,m3,3);
		MatrixUtilities.OutVector(m3);
		(* test differentiation*)
		Filter(m3, m5, Filters.CreateSplineFilter(Filters.CubicSplineDifferentiator), Filters.mirrorH);
		MatrixUtilities.OutVector(m5);
		fromSpline(m5,m4,2);
		MatrixUtilities.OutVector(m4);
		(* test laplacian *)
		Filter(m3, m6, Filters.CreateSplineFilter(Filters.CubicSplineLaplacian), Filters.mirrorH);
		MatrixUtilities.OutVector(m6);
		Filter(m1, m7, Filters.CreateSplineFilter(Filters.CubicSplineLaplacian), Filters.mirrorH);
		MatrixUtilities.OutVector(m7);
	END Test;

END LinearTransform.

SystemTools.Free LinearTransform ~
LinearTransform.Test

