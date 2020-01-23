MODULE VolumeTransform;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "";  **)

IMPORT VolumeBase, Convolution:=LinearConvolve, Filters:=LinearFilters, Wavelets;

TYPE
	Datatype* = VolumeBase.Datatype;
	Dataarray* = ARRAY [*] OF Datatype;
	Rect* = ARRAY [*,*] OF Datatype;
	Cube* = ARRAY [*,*,*] OF Datatype;
	Signal* = ARRAY [*] OF Datatype;

CONST
	finite* = Filters.finite;  periodic* = Filters.cyclicH;  mirrorH* = Filters.mirrorH;  mirrorW* = Filters.mirrorW;  antimirrorH* = Filters.antimirrorH;
	antimirrorW* = Filters.antimirrorW;

TYPE Transformer  = OBJECT (* allow reuse of temporary structures - important for performance *)
	END Transformer;


	PROCEDURE toSpline3D*( CONST in: Cube;  VAR out: Cube;  splinedegree: SIGNED16;
												 directions: SET );
	BEGIN
		Filter3D( in, out,
					    Filters.CreateSplineFilter( Filters.DirectBSpline0 + splinedegree ),
					    directions, mirrorH );
	END toSpline3D;

	PROCEDURE fromSpline3D*( CONST in: Cube;  VAR out: Cube;  splinedegree: SIGNED16;
													 directions: SET );
	BEGIN
		Filter3D( in, out,
					    Filters.CreateSplineFilter( Filters.InverseBSpline0 + splinedegree ),
					    directions, mirrorW );
	END fromSpline3D;

	PROCEDURE Filter3D*( CONST data: Cube;  VAR resdata: Cube;
										   filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	VAR linehandler: VolumeBase.LineHandler;
		convolver: Convolution.Convolver;
	BEGIN
		IF filter = NIL THEN resdata := data;  RETURN END;
		NEW( convolver, filter, boundary );
		VolumeBase.HandleLines3D( data, resdata, directions, convolver.convolve );
	END Filter3D;

	PROCEDURE Reduce*( CONST g: Cube ): Cube;  (*simple scaling without interpolation*)
	VAR L00,L01,L10,L11,L20,L21:SIZE;
	BEGIN
		L00:=(LEN( g, 0 ) + 0) DIV 2-1; L01:= (LEN( g, 0 ) + 1)  DIV 2-1;
		L10:=(LEN( g, 1 ) + 0) DIV 2-1; L11:= (LEN( g, 1 ) + 1)  DIV 2-1;
		L20:=(LEN( g, 2 ) + 0) DIV 2-1; L21:= (LEN( g, 2 ) + 1)  DIV 2-1;

		IF (LEN( RESULT, 0 ) # (L01+1)) OR (LEN( RESULT, 1 ) # (L11+1)) OR (LEN( RESULT, 2 ) # (L21+1)) THEN NEW( RESULT, L01+1, L11+1,L21+1 ) END;
		RESULT[.. L01, .. L11, .. L21] := g[.. BY 2, .. BY 2, .. BY 2];
		RESULT[.. L00, .. L11, .. L21] := RESULT[.. L00, .. L11, .. L21] + g[1.. BY 2, .. BY 2, .. BY 2];
		RESULT[.. L01, .. L10, .. L21] := RESULT[.. L01, .. L10, .. L21] + g[.. BY 2, 1.. BY 2, .. BY 2];
		RESULT[.. L00, .. L10, .. L21] := RESULT[.. L00, .. L10, .. L21] + g[1.. BY 2, 1.. BY 2, .. BY 2];

		RESULT[.. L01, .. L11, .. L20 ] := g[.. BY 2, .. BY 2, 1.. BY 2];
		RESULT[.. L00, .. L11, .. L20] := RESULT[.. L00, .. L11] + g[1.. BY 2, .. BY 2, 1.. BY 2];
		RESULT[.. L01, .. L10, .. L20] := RESULT[.. L01, .. L10] + g[.. BY 2, 1.. BY 2, 1.. BY 2];
		RESULT[.. L00, .. L10, .. L20] := RESULT[.. L00, .. L10] + g[1.. BY 2, 1.. BY 2, 1.. BY 2];

		RESULT[.. L01, .. L11] := 0.125 * RESULT[.. L01, .. L11];

		IF ODD( LEN( g, 0 ) ) THEN RESULT[L01, .. , ..] := 2 * RESULT[L01, .. , ..];   (*missing contributions to this boundary data*)	END;
		IF ODD( LEN( g, 1 ) ) THEN RESULT[.. , L11, ..] := 2 * RESULT[.. , L11 , ..];   (*missing contributions to this boundary data*)	END;
		IF ODD( LEN( g, 2 ) ) THEN RESULT[.. , .. , L21] := 2 * RESULT[.. , .., L21];   (*missing contributions to this boundary data*)END;
		RETURN RESULT
	END Reduce;


	(* possible filters: Filters.CreateSplineFilter( Filters.LeastSquareSpline0Down2 + splinedegree ) *)  (*ToDo: IN_PLACE !!*)
	PROCEDURE Reduce3D*( CONST data: Cube;  VAR resdata: Cube;
											  filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	VAR temp, temp2: Cube;  convolver: Convolution.Convolver;
	BEGIN
		directions := directions * {0,1,2};
		IF directions = {} THEN RETURN
		ELSIF filter = NIL THEN
			IF directions = {0,1,2} THEN resdata:=  Reduce(data);
			ELSE HALT( 100); (*to be implemented*)
			END;
		ELSIF (directions = {0}) OR (directions = {1}) OR (directions = {2}) THEN
			NEW( convolver, filter, boundary );
			VolumeBase.HandleLines3D( data, resdata, directions,
														   convolver.convolveDown2 );
		ELSIF directions = {0, 1} THEN
			NEW( temp, LEN( data, 0 ), LEN( resdata, 1 ), LEN( data, 2 ) );
			Reduce3D( data, temp, filter, {1}, boundary );
			Reduce3D( temp, resdata, filter, {0}, boundary );
		ELSIF directions = {0, 2} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( resdata, 2 ) );
			Reduce3D( data, temp, filter, {2}, boundary );
			Reduce3D( temp, resdata, filter, {0}, boundary );
		ELSIF directions = {1, 2} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( resdata, 2 ) );
			Reduce3D( data, temp, filter, {2}, boundary );
			Reduce3D( temp, resdata, filter, {1}, boundary );
		ELSE  (*directions={0,1,2}*)
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( resdata, 2 ) );
			Reduce3D( data, temp, filter, {2}, boundary );
			NEW( temp2, LEN( temp, 0 ), LEN( resdata, 1 ), LEN( resdata, 2 ) );
			Reduce3D( temp, temp2, filter, {1}, boundary );
			Reduce3D( temp2, resdata, filter, {0}, boundary );
		END;
	END Reduce3D;

	(* possible filters: Filters.CreateSplineFilter( Filters.LeastSquareSpline0Up2 + splinedegree ) *)  (*todo:  in-place*)
	PROCEDURE Expand3D*( CONST data: Cube;  VAR resdata: Cube;
											   filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	VAR temp, temp2: Cube;  convolver: Convolution.Convolver;
	BEGIN
	(*to do: check sizes, check filter*)  (*check for in-place*)
		directions := directions * {0,1,2};
		IF directions = {} THEN RETURN
		ELSIF filter = NIL THEN
			IF directions = {0,1,2} THEN resdata:=  Expand(data);
			ELSE HALT( 100); (*to be implemented*)
			END;
		ELSIF (directions = {0}) OR (directions = {1}) OR (directions = {2}) THEN
			NEW( convolver, filter, boundary );
			VolumeBase.HandleLines3D( data, resdata, directions,
														   convolver.convolveUp2 );
		ELSIF directions = {0, 1} THEN
			NEW( temp, LEN( data, 0 ), LEN( resdata, 1 ), LEN( data, 2 ) );
			Expand3D( data, temp, filter, {0}, boundary );
			Expand3D( temp, resdata, filter, {1}, boundary );
		ELSIF directions = {0, 2} THEN
			NEW( temp, LEN( resdata, 0 ), LEN( data, 1 ), LEN( data, 2 ) );
			Expand3D( data, temp, filter, {0}, boundary );
			Expand3D( temp, resdata, filter, {2}, boundary );
		ELSIF directions = {1, 2} THEN
			NEW( temp, LEN( resdata, 0 ), LEN( data, 1 ), LEN( data, 2 ) );
			Expand3D( data, temp, filter, {1}, boundary );
			Expand3D( temp, resdata, filter, {2}, boundary );
		ELSE  (*directions={0,1,2}*)
			NEW( temp, LEN( resdata, 0 ), LEN( data, 1 ), LEN( data, 2 ) );
			Expand3D( data, temp, filter, {0}, boundary );
			NEW( temp2, LEN( resdata, 0 ), LEN( resdata, 1 ), LEN( data, 2 ) );
			Expand3D( temp, temp2, filter, {1}, boundary );
			Expand3D( temp2, resdata, filter, {2}, boundary );
		END;
	END Expand3D;

	PROCEDURE Expand*( CONST g: Cube ): Cube; (*simple scaling without interpolation*)
	VAR L00,L01,L10,L11,L20,L21:SIZE;
	BEGIN
		L00:=(LEN( RESULT, 0 ) + 0) DIV 2-1; L01:= (LEN( RESULT, 0 ) + 1) DIV 2-1;
		L10:=(LEN( RESULT, 1 ) + 0) DIV 2-1; L11:= (LEN( RESULT, 1 ) + 1) DIV 2-1;
		L20:=(LEN( RESULT, 2 ) + 0) DIV 2-1; L21:= (LEN( RESULT, 2 ) + 1) DIV 2-1;

		IF (LEN( g, 0 ) # (L01+1)) OR (LEN( g, 1 ) # (L11+1)) OR (LEN( g, 2 ) # (L21+1))THEN NEW( RESULT, 2 * LEN( g, 0 ), 2 * LEN( g, 1 ) , 2 * LEN( g, 2) ) END;
		RESULT[.. BY 2, .. BY 2, .. BY 2] := g[.. L01, .. L11, ..L21];
		RESULT[1.. BY 2, .. BY 2, .. BY 2] := g[.. L00, .. L11, ..L21];
		RESULT[.. BY 2, 1.. BY 2, .. BY 2] := g[.. L01, .. L10, ..L21];
		RESULT[1.. BY 2, 1.. BY 2, .. BY 2] := g[.. L00, .. L10, ..L21];

		RESULT[.. BY 2, .. BY 2, 1.. BY 2] := g[.. L01, .. L11, .. L20];
		RESULT[1.. BY 2, .. BY 2, 1.. BY 2] := g[.. L00, .. L11, .. L20];
		RESULT[.. BY 2, 1.. BY 2, 1.. BY 2] := g[.. L01, .. L10, .. L20];
		RESULT[1.. BY 2, 1.. BY 2, 1.. BY 2] := g[.. L00, .. L10, .. L20];
		RETURN RESULT
	END Expand;

	PROCEDURE resample(CONST data: ARRAY OF Datatype; VAR res: ARRAY OF Datatype);
	BEGIN

	END resample;

	PROCEDURE Resample3D( CONST data: Cube;  VAR resdata: Cube;
											   filter: Filters.Filter;  directions: SET;  boundary: SIGNED16);
	BEGIN
	END Resample3D;

	PROCEDURE RotateDimensions*( CONST g: Cube ): Cube;
	VAR dim,dim1: ARRAY [3] OF SIZE; i:SIZE;
	BEGIN
		dim:=LEN(g); dim1[0]:=dim[1]; dim1[1]:=dim[2]; dim1[2]:=dim[0];
		IF LEN(RESULT)#dim1 THEN NEW(RESULT,dim1) END;
		FOR i:=0 TO LEN(g,0)-1 DO
			RESULT[..,..,i]:=g[i,..,..];
		END;
	END RotateDimensions;

	PROCEDURE MirrorX*( CONST g: Cube ): Cube; (*! to do: ASSURE THAT datasets do not overlap*)
	VAR i:SIZE;
	BEGIN
		IF LEN(RESULT)#LEN(g) THEN NEW(RESULT,LEN(g)) END;
		FOR i:=0 TO LEN(g,0)-1 DO
			RESULT[LEN(g,0)-1-i,..,..]:=g[i,..,..];
		END;
	END MirrorX;

	PROCEDURE MirrorY*( CONST g: Cube ): Cube; (*! to do: ASSURE THAT datasets do not overlap*)
	VAR i:SIZE;
	BEGIN
		IF LEN(RESULT)#LEN(g) THEN NEW(RESULT,LEN(g)) END;
		FOR i:=0 TO LEN(g,1)-1 DO
			RESULT[.., LEN(g,1)-1-i,..]:=g[..,i,..];
		END;
	END MirrorY;

	PROCEDURE MirrorZ*( CONST g: Cube ): Cube; (*! to do: ASSURE THAT datasets do not overlap*)
	VAR i:SIZE;
	BEGIN
		IF LEN(RESULT)#LEN(g) THEN NEW(RESULT,LEN(g)) END;
		FOR i:=0 TO LEN(g,2)-1 DO
			RESULT[..,..,LEN(g,2)-1-i]:=g[..,..,i];
		END;
	END MirrorZ;

	PROCEDURE ProjectSum*(CONST g: Cube; orientation:SIGNED32 ): Rect;
	VAR i:SIZE;
	BEGIN
		IF orientation=0 THEN
			RESULT:=g[0,..,..];
			FOR i:=1 TO LEN(g,0)-1 DO RESULT:=RESULT+g[i,..,..] END;
		ELSIF orientation=1 THEN
			RESULT:=g[..,0,..];
			FOR i:=1 TO LEN(g,1)-1 DO RESULT:=RESULT+g[..,i,..] END;
		ELSIF orientation=2 THEN
			RESULT:=g[..,..,0];
			FOR i:=1 TO LEN(g,2)-1 DO RESULT:=RESULT+g[..,..,i] END;
		END;
		RETURN RESULT
	END ProjectSum;

	PROCEDURE ProjectMax*(CONST g: Cube; orientation:SIGNED32 ): Rect;
	VAR x,y:SIZE;
	BEGIN
		IF orientation=0 THEN
			RESULT:=g[0,..,..];
			FOR x:=0 TO LEN(g,1)-1 DO
				FOR y:=0 TO LEN(g,2)-1 DO
					RESULT[x,y]:=MAX(g[..,x,y]);
				END;
			END;
		ELSIF orientation=1 THEN
			RESULT:=g[..,0,..];
			FOR x:=0 TO LEN(g,0)-1 DO
				FOR y:=0 TO LEN(g,2)-1 DO
					RESULT[x,y]:=MAX(g[x,..,y]);
				END;
			END;
		ELSIF orientation=2 THEN
			RESULT:=g[..,..,0];
			FOR x:=0 TO LEN(g,0)-1 DO
				FOR y:=0 TO LEN(g,1)-1 DO
					RESULT[x,y]:=MAX(g[x,y,..]);
				END;
			END;
		END;
		RETURN RESULT
	END ProjectMax;

	PROCEDURE Gradient*( VAR cube: Cube;  directions: SET;  exact: BOOLEAN );
	CONST delta = 2;   (*offset for approximate/fast computation*)
	BEGIN
		IF exact THEN
			toSpline3D( cube, cube, 3, directions );
			Filter3D( cube, cube, Filters.CreateSplineFilter( Filters.CubicSplineDifferentiator ), directions, mirrorH );
		ELSE
			IF 0 IN directions THEN cube[.. LEN( cube, 0 ) - 1 - delta] := ABS( cube[.. LEN( cube, 0 ) - 1 - delta] - cube[delta..LEN( cube, 0 ) - 1] );  END;
			IF 1 IN directions THEN cube[.. , .. LEN( cube, 1 ) - 1 - delta] := ABS( cube[.. , .. LEN( cube, 1 ) - 1 - delta] - cube[.. , delta..LEN( cube, 1 ) - 1] );  END;
			IF 2 IN directions THEN cube[.. , .. , .. LEN( cube, 2 ) - 1 - delta] := ABS( cube[.. , .. , .. LEN( cube, 2 ) - 1 - delta] - cube[.. , .. , delta..LEN( cube, 2 ) - 1] );  END;
		END;
	END Gradient;

	PROCEDURE Laplacian*( VAR cube: Cube;  directions: SET; exact: BOOLEAN );
	BEGIN
		IF TRUE  (*Exact*) THEN
			toSpline3D( cube, cube, 3, directions );
			Filter3D( cube, cube, Filters.CreateSplineFilter( Filters.CubicSplineLaplacian ), directions, mirrorH );
		ELSE HALT(200) (* not yet implemented *)
		END;
	END Laplacian;

(* to do: make order of dimensions for analyse/reconstruct consistent (e.g., 1->2->3, on way back: 3->2->1 *)
	PROCEDURE Wavelet3D*( CONST data: Cube;  VAR resdata: Cube;
											    wavelet: Wavelets.WaveletFamily;  directions: SET;
											    boundary: SIGNED16;  analyze: BOOLEAN );
	VAR waveconvolver: Wavelets.WaveletConvolver;
	BEGIN
		IF wavelet = NIL THEN HALT( 100 ) END;
		NEW( waveconvolver, wavelet, boundary );
		IF analyze THEN
			VolumeBase.HandleLines3D( data, resdata, directions,
														   waveconvolver.Analyze );
		ELSE
			VolumeBase.HandleLines3D( data, resdata, directions,
														   waveconvolver.Reconstruct );
		END;
	END Wavelet3D;

	PROCEDURE Test*;
	VAR cube,cube1: Cube;
	BEGIN
	END Test;

END VolumeTransform.

System.Free VolumeTransform Convolution MatrixFIRConvolveLongReal TestDSPTransform DSPOpticalFlow DSPWarp3D DSPTransform ~

fofPC.Compile \s *
fofPC.Compile \f *
OFormatter.Format *
