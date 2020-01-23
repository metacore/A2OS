MODULE PlanarTransform;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "";  **)

(*! rescaling procedures seem to have allocation/assignment problems: new? see ReduceX*)

IMPORT PlanarBase, LinearConvolve, Wavelets, Filters:=LinearFilters, MatrixBSplineInterpolation, Out := KernelLog;

TYPE
	Datatype* = PlanarBase.Datatype;  Dataarray* = ARRAY [ * ] OF Datatype;
	Rect* = ARRAY [ * , * ] OF Datatype;
	(*SplineCurve* = ARRAY [ 2 , * ] OF Datatype;  ;*)
	Cube* = ARRAY [ * , * , * ] OF Datatype;
	Signal* = ARRAY [ * ] OF Datatype;

CONST
	finite* = Filters.finite;  periodic* = Filters.cyclicH;  mirrorH* = Filters.mirrorH;  mirrorW* = Filters.mirrorW;  antimirrorH* = Filters.antimirrorH;
	antimirrorW* = Filters.antimirrorW;

	PROCEDURE toSpline2D*( CONST in: Rect;  VAR out: Rect;  splinedegree: SIGNED16;  directions: SET );  (*! to do: more adapted boundaries, depending on spline order*)
	BEGIN
		IF (LEN(out,0)=0) & (LEN(in,0)#0) THEN NEW( out, LEN(in,0),LEN(in,1)) END;
		Filter2D( in, out, Filters.CreateSplineFilter( Filters.DirectBSpline0 + splinedegree ), directions, mirrorH );
	END toSpline2D;

	PROCEDURE fromSpline2D*( CONST in: Rect;  VAR out: Rect;  splinedegree: SIGNED16;  directions: SET );
	BEGIN
		IF (LEN(out,0)=0) & (LEN(in,0)#0) THEN NEW( out, LEN(in,0),LEN(in,1)) END;
		Filter2D( in, out, Filters.CreateSplineFilter( Filters.InverseBSpline0 + splinedegree ), directions, mirrorH );
	END fromSpline2D;
	(*
	PROCEDURE toSplineCurve*( CONST in: Rect;  VAR out: Rect;  splinedegree: SIGNED16;  boundary: SIGNED32 );
	BEGIN
		IF (LEN(out,0)=0) & (LEN(in,0)#0) THEN NEW( out, LEN(in,0),LEN(in,1)) END;
		Filter2D( in, out, Filters.CreateSplineFilter( Filters.DirectBSpline0 + splinedegree ), directions, mirrorH );
	END toSplineCurve;

	PROCEDURE fromSplineCurve*( CONST in: Rect;  VAR out: Rect;  splinedegree: SIGNED16;  boundary: SIGNED32 );
	BEGIN
		IF (LEN(out,0)=0) & (LEN(in,0)#0) THEN NEW( out, LEN(in,0),LEN(in,1)) END;
		Filter2D( in, out, Filters.CreateSplineFilter( Filters.InverseBSpline0 + splinedegree ), directions, mirrorH );
	END fromSplineCurve;
*)

	PROCEDURE Filter2D*( CONST data: Rect;  VAR resdata: Rect;  filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	VAR convolver: LinearConvolve.Convolver;
	BEGIN
		IF filter = NIL THEN resdata := data;  RETURN END;
		IF (LEN(resdata,0)=0) & (LEN(data,0)#0) THEN NEW( resdata, LEN(data,0),LEN(data,1)) END;
		NEW( convolver, filter, boundary );  PlanarBase.HandleLines2D( data, resdata, directions, convolver.convolve );
	END Filter2D;

	(* possible filters: Filters.CreateSplineFilter( Filters.LeastSquareSpline0Down2 + splinedegree ) *)  (*ToDo: IN_PLACE !!*)

	PROCEDURE Reduce2D*( CONST data: Rect;  VAR resdata: Rect;  filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	VAR temp: Rect;  convolver: LinearConvolve.Convolver;
	BEGIN
		directions := directions * {0, 1};
		IF directions = {} THEN resdata:=data; RETURN END;
		IF (LEN(resdata,0)=0) & (LEN(data,0)#0) THEN NEW( resdata, (LEN(data,0)+1)DIV 2,(LEN(data,1)+1)DIV 2) END;
		IF filter = NIL THEN
			IF directions = {0} THEN resdata:= ReduceY(data)
			ELSIF directions = {1} THEN resdata:= ReduceX(data)
			ELSE resdata:= Reduce(data)
			END;
		ELSIF (directions = {0}) OR (directions = {1}) THEN NEW( convolver, filter, boundary );  PlanarBase.HandleLines2D( data, resdata, directions, convolver.convolveDown2 );
		ELSIF directions = {0, 1} THEN NEW( temp, LEN( data, 0 ), LEN( resdata, 1 ) );  Reduce2D( data, temp, filter, {1}, boundary );  Reduce2D( temp, resdata, filter, {0}, boundary );
		ELSE HALT( 100 );
		END;
	END Reduce2D;

	(* possible filters: Filters.CreateSplineFilter( Filters.LeastSquareSpline0Up2 + splinedegree ) *)  (*todo:  in-place*)

	PROCEDURE Expand2D*( CONST data: Rect;  VAR resdata: Rect;  filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	VAR temp : Rect;  convolver: LinearConvolve.Convolver;
	BEGIN
	(*to do: check sizes, check filter*)  (*check for in-place*)
		directions := directions * {0, 1};
		IF directions = {} THEN resdata:=data; RETURN END;
		IF (LEN(resdata,0)=0) & (LEN(data,0)#0) THEN NEW( resdata, LEN(data,0)* 2,LEN(data,1)*2) END;
		IF filter = NIL THEN
			IF directions = {0} THEN resdata:= ExpandY(data)
			ELSIF directions = {1} THEN resdata:= ExpandX(data)
			ELSE resdata:= Expand(data)
			END;
		ELSIF (directions = {0}) OR (directions = {1}) THEN
			NEW( convolver, filter, boundary );
			PlanarBase.HandleLines2D( data, resdata, directions, convolver.convolveUp2 );
		ELSIF directions = {0, 1} THEN
			NEW( temp, LEN( resdata, 0 ), LEN( data, 1 ) );
			Expand2D( data, temp, filter, {0}, boundary );
			Expand2D( temp, resdata, filter, {1}, boundary );
		END;
	END Expand2D;

	PROCEDURE clamp(x:SIZE; low,high:SIZE):SIZE;
	BEGIN
		(*RETURN MIN(high,MAX(x,low)); *)
		IF x<low THEN RETURN low ELSIF x>high THEN RETURN high ELSE RETURN x END;
	END clamp;

(** Resampling of input data, starting from x0,y0, in increments of dx,dy; if upscaling (dx,dy>1), then )
	Input: data: spline coefficients of "splinedegree"; allocated 'resdata' of desired size; boundary: see Filters.Mod for boundary types
	Output: resampled data in 'resdata' *)
	PROCEDURE Resample*( CONST data: Rect;  VAR resdata: Rect;  x0, y0, dx, dy: Datatype;  splinedegree, boundary: SIGNED32 );
	VAR w: Rect;  indices: ARRAY [ * ] OF SIGNED32;
		temp: Rect;  x, y, x1, x2, y1, y2: SIZE;  v: Signal;  Dx,Dy:SIGNED32; ddx,ddy:Datatype;
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

	PROCEDURE Resample2D( CONST data: Rect;  VAR resdata: Rect;  filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	END Resample2D;
*)
(*simple scaling without interpolation*)
	PROCEDURE ReduceX*( CONST g: Rect ): Rect;
	BEGIN
		IF (LEN( RESULT, 0 ) # LEN( g, 0 )) OR (LEN( RESULT, 1 ) # ((LEN( g, 1 ) + 1) DIV 2)) THEN NEW( RESULT, LEN( g, 0), (LEN( g, 1 ) + 1) DIV 2 ) END;
		RESULT[.. , ..] := g[.., .. BY 2];
		RESULT[.. , .. (LEN( g, 1 )) DIV 2 - 1] := RESULT[.. , .. (LEN( g, 1 )) DIV 2 - 1] + g[.., 1 .. BY 2];
		RESULT := 0.5 * RESULT;  (*average*)
		IF ODD( LEN( g, 1 ) ) THEN
			RESULT[.. , (LEN( g, 1 ) + 1) DIV 2 - 1] := 2 * RESULT[.. , (LEN( g, 1 ) + 1) DIV 2 - 1];   (*missing contributions to this boundary data*)
		END;
		RETURN RESULT
	END ReduceX;
(*simple scaling without interpolation*)
	PROCEDURE ExpandX*( CONST g: Rect ): Rect;
	BEGIN
		IF (LEN( g, 0 ) # LEN( RESULT, 0 )) OR (LEN( g, 1 ) # ((LEN( RESULT, 1 ) + 1) DIV 2)) THEN NEW( RESULT, LEN( g, 0 ), 2 * LEN( g, 1 ) ) END;
		RESULT[.. , .. BY 2] := g[.. , .. (LEN( RESULT, 1 ) + 1) DIV 2 - 1];
		RESULT[.. , 1.. BY 2] := g[.. , .. (LEN( RESULT, 1 ) + 0) DIV 2 - 1];
		RETURN RESULT
	END ExpandX;
(*simple scaling without interpolation*)	 (*!may need fix of dimension allocation*)
	PROCEDURE ReduceY*( CONST g: Rect ): Rect;
	BEGIN
		IF (LEN( RESULT, 0 ) # ((LEN( g, 0 ) + 1) DIV 2)) OR (LEN( RESULT, 1 ) # ((LEN( g, 1 ) + 1) DIV 2)) THEN NEW( RESULT, (LEN( g, 0 ) + 1) DIV 2, LEN( g, 1 )) END;
		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. ] := g[.. BY 2, .. BY 2];
		RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. ] := RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. ] + g[1.. BY 2, .. ];
		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. ] := 0.5 * RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. ];  (*scale*)
		IF ODD( LEN( g, 0 ) ) THEN
			RESULT[(LEN( g, 0 ) + 1) DIV 2 - 1, .. ] := 2 * RESULT[(LEN( g, 0 ) + 1) DIV 2 - 1, .. ];   (*missing contributions to this boundary data*)
		END;
		RETURN RESULT
	END ReduceY;
(*simple scaling without interpolation*)(*! may need fix for dimension allocation*)
	PROCEDURE ExpandY*( CONST g: Rect ): Rect;
	BEGIN
		IF (LEN( g, 0 ) # ((LEN( RESULT, 0 ) + 1) DIV 2)) OR (LEN( g, 1 ) # ((LEN( RESULT, 1 ) + 1) DIV 2)) THEN NEW( RESULT, 2 * LEN( g, 0 ), LEN( g, 1 ) ) END;
		RESULT[.. BY 2, ..] := g[.. (LEN( RESULT, 0 ) + 1) DIV 2 - 1, .. ];
		RESULT[1.. BY 2, ..] := g[.. (LEN( RESULT, 0 ) + 0) DIV 2 - 1, .. ];
		RETURN RESULT
	END ExpandY;

	PROCEDURE Reduce*(CONST g: Rect): Rect;  (*simple scaling without interpolation*)
	VAR newLen: ARRAY [*] OF SIZE;
	BEGIN
		newLen:= (LEN(g)+1) DIV 2;
		IF (DIM(RESULT)=0) OR (LEN(RESULT)#newLen) THEN NEW(RESULT,newLen) END;
(*		IF (LEN( RESULT, 0 ) # ((LEN( g, 0 ) + 1) DIV 2)) OR (LEN( RESULT, 1 ) # ((LEN( g, 1 ) + 1) DIV 2)) THEN NEW( RESULT, (LEN( g, 0 ) + 1) DIV 2, (LEN( g, 1 ) + 1) DIV 2 ) END;
*)		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := g[.. BY 2, .. BY 2];
		RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] + g[1.. BY 2, .. BY 2];
		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] + g[.. BY 2, 1.. BY 2];
		RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] + g[1.. BY 2, 1.. BY 2];
		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := 0.25 * RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1];
		IF ODD( LEN( g, 0 ) ) THEN
			RESULT[(LEN( g, 0 ) + 1) DIV 2 - 1, .. ] := 2 * RESULT[(LEN( g, 0 ) + 1) DIV 2 - 1, .. ];   (*missing contributions to this boundary data*)
		END;
		IF ODD( LEN( g, 1 ) ) THEN
			RESULT[.. , (LEN( g, 1 ) + 1) DIV 2 - 1] := 2 * RESULT[.. , (LEN( g, 1 ) + 1) DIV 2 - 1];   (*missing contributions to this boundary data*)
		END;
		RETURN RESULT
	END Reduce;

	PROCEDURE ReduceMax*( CONST g: Rect ): Rect;  (* scaling with MAX()*)
	BEGIN
		IF (LEN( RESULT, 0 ) # ((LEN( g, 0 ) + 1) DIV 2)) OR (LEN( RESULT, 1 ) # ((LEN( g, 1 ) + 1) DIV 2)) THEN NEW( RESULT, (LEN( g, 0 ) + 1) DIV 2, (LEN( g, 1 ) + 1) DIV 2 ) END;
		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := g[.. BY 2, .. BY 2];
		RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1] := MAX(RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 1) DIV 2 - 1], g[1.. BY 2, .. BY 2]);
		RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := MAX(RESULT[.. (LEN( g, 0 ) + 1) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1], g[.. BY 2, 1.. BY 2]);
		RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1] := MAX(RESULT[.. (LEN( g, 0 ) + 0) DIV 2 - 1, .. (LEN( g, 1 ) + 0) DIV 2 - 1], g[1.. BY 2, 1.. BY 2]);
		RETURN RESULT
	END ReduceMax;

	PROCEDURE Expand*( CONST g: Rect ): Rect;  (*simple scaling without interpolation*)
	BEGIN
		IF (LEN( g, 0 ) # ((LEN( RESULT, 0 ) + 1) DIV 2)) OR (LEN( g, 1 ) # ((LEN( RESULT, 1 ) + 1) DIV 2)) THEN NEW( RESULT, 2 * LEN( g, 0 ), 2 * LEN( g, 1 ) ) END;
		RESULT[.. BY 2, .. BY 2] := g[.. (LEN( RESULT, 0 ) + 1) DIV 2 - 1, .. (LEN( RESULT, 1 ) + 1) DIV 2 - 1];
		RESULT[1.. BY 2, .. BY 2] := g[.. (LEN( RESULT, 0 ) + 0) DIV 2 - 1, .. (LEN( RESULT, 1 ) + 1) DIV 2 - 1];
		RESULT[.. BY 2, 1.. BY 2] := g[.. (LEN( RESULT, 0 ) + 1) DIV 2 - 1, .. (LEN( RESULT, 1 ) + 0) DIV 2 - 1];
		RESULT[1.. BY 2, 1.. BY 2] := g[.. (LEN( RESULT, 0 ) + 0) DIV 2 - 1, .. (LEN( RESULT, 1 ) + 0) DIV 2 - 1];
		RETURN RESULT
	END Expand;

	PROCEDURE Mirror*(CONST m:Rect; vertical:BOOLEAN):Rect;(*! to do: ASSURE THAT m and RESULT do not conflict*)
	VAR i:SIZE; h,v:ARRAY[*] OF Datatype;
	BEGIN
		IF (LEN(RESULT,0) # LEN(m,0)) OR (LEN(RESULT,1) # LEN(m,1)) THEN (*LEN(RESULT) # LEN(m)*)
			NEW(RESULT, LEN(m,0), LEN(m,1))
		END;
		IF vertical THEN
			FOR i:=0 TO LEN(m,0)-1 DO
				h:=m[i,..];
				RESULT[i,..]:=m[LEN(m,0)-i-1,..];
				RESULT[LEN(m,0)-i-1,..]:=h;
			END;
		ELSE
			FOR i:=0 TO LEN(m,1)-1 DO
				v:=m[..,i];
				RESULT[..,i]:=m[..,LEN(m,0)-i-1];
				RESULT[..,LEN(m,0)-i-1]:=v;
			END;
		END;
		RETURN RESULT
	END Mirror;

	PROCEDURE Rotate90*(CONST m:Rect):Rect;(*clockwise*)(*! to do: ASSURE THAT m and RESULT do not conflict*)
	VAR i:SIZE;
	BEGIN
		IF (LEN(RESULT,0) # LEN(m,1)) OR (LEN(RESULT,1) # LEN(m,0)) THEN (*LEN(RESULT) # [LEN(m,1),LEN(m,0)]*)
			NEW(RESULT, LEN(m,1), LEN(m,0))
		END;
		FOR i:=0 TO LEN(m,0)-1 DO
			RESULT[..,LEN(RESULT,1)-i-1]:=m[i,..]
		END;
		RETURN RESULT
	END Rotate90;

	PROCEDURE Rotate180*(CONST m:Rect):Rect;
	VAR j,i:SIZE; x0: Datatype;
	BEGIN
		IF (LEN(RESULT,0) # LEN(m,0)) OR (LEN(RESULT,1) # LEN(m,1)) THEN (*LEN(RESULT) # LEN(m)*)
			NEW(RESULT, LEN(m,0), LEN(m,1))
		END;
		FOR j:=0 TO (LEN(m,0)+1) DIV 2-1 DO
			FOR i:=0 TO LEN(m,1) -1 DO
				x0:=m[j,i];
				RESULT[j,i]:=m[LEN(m,0)-j-1, LEN(m,1)-i-1];
				RESULT[LEN(m,0)-j-1, LEN(m,1)-i-1]:=x0;
			END;
		END;
		RETURN RESULT
	END Rotate180;

(* to do: make order of dimensions for analyse/reconstruct consistent (e.g., 1->2->3, on way back: 3->2->1 *)
	PROCEDURE Wavelet2D*( CONST data: Rect;  VAR resdata: Rect;  wavelet: Wavelets.WaveletFamily;  directions: SET;  boundary: SIGNED16;  analyze: BOOLEAN );
	VAR waveconvolver: Wavelets.WaveletConvolver;
	BEGIN
		IF wavelet = NIL THEN HALT( 100 ) END;
		NEW( waveconvolver, wavelet, boundary );
		IF analyze THEN PlanarBase.HandleLines2D( data, resdata, directions, waveconvolver.Analyze );
		ELSE PlanarBase.HandleLines2D( data, resdata, directions, waveconvolver.Reconstruct );
		END;
	END Wavelet2D;
	
	PROCEDURE {TEST} Test*;
	VAR a,b,c,d,e,f,g,j: ARRAY [*,*] OF REAL;
		h,i: ARRAY [?] OF REAL;
	BEGIN
		NEW(a,100,100);
		NEW(b, 50,100);
		NEW(c, 50,50);
		
		d:=Reduce(a);(*unallocated*)
		c:=Reduce(a);(*preallocated*)
		b[*,50..]:=Reduce(a);(*subrange*)
		
		a:=Expand(c); (*preallocated*)
		e:=Expand(c); (*unallocated*)
		NEW(f,101,101); f:=1;
		g:=Reduce(f); ASSERT(LEN(g)=[51,51], 200);
		f:=0; f:=Expand(g); ASSERT(SUM(f)=101*101, 201);
		(*h:=Reduce(a);*)(* unallocated tensor fails compilation*)
		NEW(i, LEN(d)); i:=Reduce(a); (*allocated tensor*)

		j:=ExpandY(a);
		
	END Test;

(*
	PROCEDURE Test*;
	VAR m, m1, m2,m3: Rect;  i, j, t0, t1: SIGNED32;
	BEGIN
		NEW( m, 300, 300 );  NEW( m1, 600, 600 );  NEW( m2, 600, 600 );  NEW( m3, 600, 600 );
		m := 0;  m[30..50, 30..50] := 1;

		Resample( m, m1, 0, 0, 2.5, 2.5, 0, 0 );
		Resample( m, m2, 0, 0, 2.5, 2.5, 1, 0 );
		Resample( m, m3, 0, 0, 2.5, 2.5, 3,  0);

		MatrixPictures.ShowMatrixPicture( m, TRUE );  MatrixPictures.ShowMatrixPicture( m1, TRUE );
		MatrixPictures.ShowMatrixPicture( m2, TRUE );  MatrixPictures.ShowMatrixPicture( m3, TRUE );
	END Test;
*)
END PlanarTransform.




System.Free
PlanarTransform.Test

System.FreeDownTo PlanarTransform MatrixBSplineInterpolation PlanarBase LinearConvolve MatrixFIRConvolveLongReal TestDSPTransform DSPOpticalFlow DSPWarp3D DSPTransform ~

fofPC.Compile \s *
fofPC.Compile \f *
OFormatter.Format *

