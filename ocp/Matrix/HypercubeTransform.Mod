MODULE HypercubeTransform;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "";  **)

IMPORT HypercubeBase, Convolutions:=LinearConvolve, Wavelets, Filters:=LinearFilters;

TYPE
	Datatype* = HypercubeBase.Datatype;
	Dataarray* = ARRAY [*] OF Datatype;
	Rect* = ARRAY [*,*] OF Datatype;
	Cube* = ARRAY [*,*,*] OF Datatype;
	Hypercube* = ARRAY [*,*,*, *] OF Datatype;
	Signal* = ARRAY [*] OF Datatype;

CONST
	finite* = Filters.finite;  periodic* = Filters.cyclicH;  mirrorH* = Filters.mirrorH;  mirrorW* = Filters.mirrorW;  antimirrorH* = Filters.antimirrorH;
	antimirrorW* = Filters.antimirrorW;


	PROCEDURE toSpline4D*( CONST in: Hypercube;  VAR out: Hypercube;  splinedegree: SIGNED16;
												 directions: SET );
	BEGIN
		Filter4D( in, out,
					    Filters.CreateSplineFilter( Filters.DirectBSpline0 + splinedegree ),
					    directions, mirrorH );
	END toSpline4D;

	PROCEDURE fromSpline4D*( CONST in: Hypercube;  VAR out: Hypercube;  splinedegree: SIGNED16;
													 directions: SET );
	BEGIN
		Filter4D( in, out,
					    Filters.CreateSplineFilter( Filters.InverseBSpline0 + splinedegree ),
					    directions, mirrorW );
	END fromSpline4D;

	PROCEDURE Filter4D*( CONST data: Hypercube;  VAR resdata: Hypercube;
										   filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	VAR linehandler: HypercubeBase.LineHandler;
		convolver: Convolutions.Convolver;
	BEGIN
		IF filter = NIL THEN resdata := data;  RETURN END;
		NEW( convolver, filter, boundary );
		HypercubeBase.HandleLines4D( data, resdata, directions, convolver.convolve );
	END Filter4D;

	(* possible filters: Filters.CreateSplineFilter( Filters.LeastSquareSpline0Down2 + splinedegree ) *)  (*ToDo: IN_PLACE !!*)
	PROCEDURE Reduce4D*( CONST data: Hypercube;  VAR resdata: Hypercube;
											  filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	VAR temp, temp2,temp3: Hypercube;  convolver: Convolutions.Convolver;
	BEGIN
		IF filter = NIL THEN HALT( 100 ) END;
		IF directions = {} THEN RETURN
		ELSIF (directions = {0}) OR (directions = {1}) OR (directions = {2}) OR (directions = {3}) THEN
			NEW( convolver, filter, boundary );
			HypercubeBase.HandleLines4D( data, resdata, directions, convolver.convolveDown2 );
		ELSIF directions = {0, 1} THEN
			NEW( temp, LEN( data, 0 ), LEN( resdata, 1 ), LEN( data, 2 ), LEN(data,3) );
			Reduce4D( data, temp, filter, {1}, boundary );
			Reduce4D( temp, resdata, filter, {0}, boundary );
		ELSIF directions = {0, 2} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( resdata, 2 ), LEN(data,3) );
			Reduce4D( data, temp, filter, {2}, boundary );
			Reduce4D( temp, resdata, filter, {0}, boundary );
		ELSIF directions = {0, 3} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(resdata,3) );
			Reduce4D( data, temp, filter, {2}, boundary );
			Reduce4D( temp, resdata, filter, {0}, boundary );
		ELSIF directions = {1, 2} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( resdata, 2 ), LEN(data,3) );
			Reduce4D( data, temp, filter, {2}, boundary );
			Reduce4D( temp, resdata, filter, {1}, boundary );
		ELSIF directions = {1, 3} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(resdata,3) );
			Reduce4D( data, temp, filter, {3}, boundary );
			Reduce4D( temp, resdata, filter, {1}, boundary );
		ELSIF directions = {2, 3} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(resdata,3) );
			Reduce4D( data, temp, filter, {3}, boundary );
			Reduce4D( temp, resdata, filter, {2}, boundary );
		ELSIF directions = {0,1,2} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( resdata, 2 ), LEN(data,3) );
			Reduce4D( data, temp, filter, {2}, boundary );
			NEW( temp2, LEN( temp, 0 ), LEN( resdata, 1 ), LEN( resdata, 2 ), LEN(data,3) );
			Reduce4D( temp, temp2, filter, {1}, boundary );
			Reduce4D( temp2, resdata, filter, {0}, boundary );
		ELSIF directions = {0,1,3} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(resdata,3) );
			Reduce4D( data, temp, filter, {3}, boundary );
			NEW( temp2, LEN( temp, 0 ), LEN( resdata, 1 ), LEN( data, 2 ), LEN(resdata,3) );
			Reduce4D( temp, temp2, filter, {1}, boundary );
			Reduce4D( temp2, resdata, filter, {0}, boundary );
		ELSIF directions = {0,2,3} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(resdata,3) );
			Reduce4D( data, temp, filter, {3}, boundary );
			NEW( temp2, LEN( temp, 0 ), LEN( data, 1 ), LEN( resdata, 2 ), LEN(resdata,3) );
			Reduce4D( temp, temp2, filter, {2}, boundary );
			Reduce4D( temp2, resdata, filter, {0}, boundary );
		ELSIF directions = {1,2,3} THEN
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN(data, 2 ), LEN(resdata,3) );
			Reduce4D( data, temp, filter, {3}, boundary );
			NEW( temp2, LEN( temp, 0 ), LEN( data, 1 ), LEN( resdata, 2 ), LEN(resdata,3) );
			Reduce4D( temp, temp2, filter, {2}, boundary );
			Reduce4D( temp2, resdata, filter, {1}, boundary );
		ELSE (*directions = {0,1,2,3} *)
			NEW( temp, LEN( data, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(resdata,3) );
			Reduce4D( data, temp, filter, {3}, boundary );
			NEW( temp2, LEN( temp, 0 ), LEN( data, 1 ), LEN( resdata, 2 ), LEN(resdata,3) );
			Reduce4D( temp, temp2, filter, {1}, boundary );
			NEW( temp3, LEN( temp, 0 ), LEN( resdata, 1 ), LEN( resdata, 2 ), LEN(resdata,3) );
			Reduce4D( temp2, temp3, filter, {1}, boundary );
			Reduce4D( temp3, resdata, filter, {0}, boundary );
		END;
	END Reduce4D;

	(* possible filters: Filters.CreateSplineFilter( Filters.LeastSquareSpline0Up2 + splinedegree ) *)  (*todo:  in-place*)
	PROCEDURE Expand4D*( CONST data: Hypercube;  VAR resdata: Hypercube;
											   filter: Filters.Filter;  directions: SET;  boundary: SIGNED16 );
	VAR temp, temp2,temp3: Hypercube;  convolver: Convolutions.Convolver;
	BEGIN
	(*to do: check sizes, check filter*)  (*check for in-place*)
		IF filter = NIL THEN HALT( 100 ) END;
		IF directions = {} THEN RETURN
		ELSIF (directions = {0}) OR (directions = {1}) OR (directions = {2}) OR (directions = {3}) THEN
			NEW( convolver, filter, boundary );
			HypercubeBase.HandleLines4D( data, resdata, directions, convolver.convolveUp2 );
		ELSIF directions = {0, 1} THEN
			NEW( temp, LEN( data, 0 ), LEN( resdata, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( data, temp, filter, {0}, boundary );
			Expand4D( temp, resdata, filter, {1}, boundary );
		ELSIF directions = {0, 2} THEN
			NEW( temp, LEN( resdata, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( data, temp, filter, {0}, boundary );
			Expand4D( temp, resdata, filter, {2}, boundary );
		ELSIF directions = {1, 2} THEN
			NEW( temp, LEN( resdata, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( data, temp, filter, {1}, boundary );
			Expand4D( temp, resdata, filter, {2}, boundary );
		ELSIF directions= {0,1,2} THEN (*directions={0,1,2}*)
			NEW( temp, LEN( resdata, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( data, temp, filter, {0}, boundary );
			NEW( temp2, LEN( resdata, 0 ), LEN( resdata, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( temp, temp2, filter, {1}, boundary );
			Expand4D( temp2, resdata, filter, {2}, boundary );
		ELSIF directions= {0,1,3} THEN (*directions={0,1,2}*)
			NEW( temp, LEN( resdata, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( data, temp, filter, {0}, boundary );
			NEW( temp2, LEN( resdata, 0 ), LEN( resdata, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( temp, temp2, filter, {1}, boundary );
			Expand4D( temp2, resdata, filter, {3}, boundary );
		ELSIF directions= {0,2,3} THEN (*directions={0,1,2}*)
			NEW( temp, LEN( resdata, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( data, temp, filter, {0}, boundary );
			NEW( temp2, LEN( resdata, 0 ), LEN( data, 1 ), LEN( resdata, 2 ), LEN(data,3) );
			Expand4D( temp, temp2, filter, {2}, boundary );
			Expand4D( temp2, resdata, filter, {3}, boundary );
		ELSIF directions= {1,2,3} THEN (*directions={0,1,2}*)
			NEW( temp, LEN( data, 0 ), LEN( resdata, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( data, temp, filter, {0}, boundary );
			NEW( temp2, LEN( data, 0 ), LEN( resdata, 1 ), LEN( resdata, 2 ), LEN(data,3) );
			Expand4D( temp, temp2, filter, {1}, boundary );
			Expand4D( temp2, resdata, filter, {2}, boundary );
		ELSE (*directions={0,1,2,3}*)
				NEW( temp, LEN( resdata, 0 ), LEN( data, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( data, temp, filter, {0}, boundary );
			NEW( temp2, LEN( resdata, 0 ), LEN( resdata, 1 ), LEN( data, 2 ), LEN(data,3) );
			Expand4D( temp, temp2, filter, {1}, boundary );
				  NEW( temp3, LEN( resdata, 0 ), LEN( resdata, 1 ), LEN( resdata, 2 ), LEN(data,3) );
			Expand4D( temp2, temp3, filter, {2}, boundary );
			Expand4D( temp3, resdata, filter, {3}, boundary );
			END;
	END Expand4D;

	PROCEDURE resample(CONST data: ARRAY OF Datatype; VAR res: ARRAY OF Datatype);
	BEGIN

	END resample;

	PROCEDURE Resample4D( CONST data: Hypercube;  VAR resdata: Hypercube;
											   filter: Filters.Filter;  directions: SET;  boundary: SIGNED16);
	BEGIN
	END Resample4D;


(* to do: make order of dimensions for analyse/reconstruct consistent (e.g., 1->2->3, on way back: 3->2->1 *)
	PROCEDURE Wavelet4D*( CONST data: Hypercube;  VAR resdata: Hypercube;
											    wavelet: Wavelets.WaveletFamily;  directions: SET;
											    boundary: SIGNED16;  analyze: BOOLEAN );
	VAR waveconvolver: Wavelets.WaveletConvolver;
	BEGIN
		IF wavelet = NIL THEN HALT( 100 ) END;
		NEW( waveconvolver, wavelet, boundary );
		IF analyze THEN
			HypercubeBase.HandleLines4D( data, resdata, directions,
														   waveconvolver.Analyze );
		ELSE
			HypercubeBase.HandleLines4D( data, resdata, directions,
														   waveconvolver.Reconstruct );
		END;
	END Wavelet4D;

	PROCEDURE Test*;
	VAR cube,cube1: Hypercube;
	BEGIN
	END Test;

END HypercubeTransform.

System.Free HypercubeMoments HypercubeNabla HypercubeTransform HypercubeBase SignalConvolve MatrixFIRConvolveLongReal TestDSPTransform DSPOpticalFlow DSPWarp4D DSPTransform ~

fofPC.Compile \s *
fofPC.Compile \f *
OFormatter.Format * 