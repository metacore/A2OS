MODULE HypercubeMoments;   (**  AUTHOR "Patrick Hunziker"; PURPOSE ""; , all rights, 2008 **)

IMPORT MatrixBase, Filters := LinearFilters, Transform := HypercubeTransform;

CONST
	dirT = 0; dirZ = 1;  dirY = 2;  dirX = 3;  skip = -1;

TYPE
	Datatype = MatrixBase.Datatype;
	Cube = ARRAY [ * , * , * ] OF Datatype;
	Hypercube = ARRAY [ * , * , * , * ] OF Datatype;

	(**
Precondition:
Postcondition:
*)
	PROCEDURE Moment*( CONST from: Hypercube;  degreeX, degreeY, degreeZ, degreeT: SIGNED32 ): Hypercube;
	VAR MomentFilter0, MomentFilter1, MomentFilter2, filter: Filters.Filter;
	BEGIN
		ASSERT( LEN( from, 0 ) > 0 );
		IF (LEN( RESULT, 0 ) # LEN( from, 0 )) OR (LEN( RESULT, 1 ) # LEN( from, 1 ))
			OR (LEN( RESULT, 2 ) # LEN( from, 2 )) OR (LEN( RESULT, 3 ) # LEN( from, 3 )) THEN
			NEW( RESULT, LEN( from, 0 ), LEN( from, 1 ), LEN( from, 2 ), LEN(from,3) )
		END;
		IF (degreeX = degreeY) & (degreeY = degreeZ) & (degreeZ = degreeT) THEN
			IF degreeX = skip THEN RETURN RESULT
			ELSE filter := Filters.CreateSplineFilter( Filters.MomentCubic0 + degreeX );
				Transform.Filter4D( from, RESULT, filter, {0, 1, 2, 3}, Transform.mirrorW );
				RETURN RESULT
			END;
		END;
		MomentFilter0 := Filters.CreateSplineFilter( Filters.MomentCubic0 );
		MomentFilter1 := Filters.CreateSplineFilter( Filters.MomentCubic1 );
		MomentFilter2 := Filters.CreateSplineFilter( Filters.MomentCubic2 );
		IF degreeX = 0 THEN Transform.Filter4D( from, RESULT, MomentFilter0, {dirX}, Transform.mirrorW )
		ELSIF degreeX = 1 THEN Transform.Filter4D( from, RESULT, MomentFilter1, {dirX}, Transform.antimirrorW )
		ELSIF degreeX = 2 THEN Transform.Filter4D( from, RESULT, MomentFilter2, {dirX}, Transform.mirrorW )
		ELSIF degreeX = skip THEN
			RESULT := from;   (*copy unchanged to result cube*)
		END;
		IF degreeY = 0 THEN Transform.Filter4D( RESULT, RESULT, MomentFilter0, {dirY}, Transform.mirrorW )
		ELSIF degreeY = 1 THEN Transform.Filter4D( RESULT, RESULT, MomentFilter1, {dirY}, Transform.antimirrorW )
		ELSIF degreeY = 2 THEN Transform.Filter4D( RESULT, RESULT, MomentFilter2, {dirY}, Transform.mirrorW )
		ELSIF degreeY = skip THEN  (*nothing*)
		END;
		IF degreeZ = 0 THEN Transform.Filter4D( RESULT, RESULT, MomentFilter0, {dirZ}, Transform.mirrorW )
		ELSIF degreeZ = 1 THEN Transform.Filter4D( RESULT, RESULT, MomentFilter1, {dirZ}, Transform.antimirrorW )
		ELSIF degreeZ = 2 THEN Transform.Filter4D( RESULT, RESULT, MomentFilter2, {dirZ}, Transform.mirrorW )
		ELSIF degreeZ = skip THEN  (*nothing*)
		END;
		IF degreeT = 0 THEN Transform.Filter4D( RESULT, RESULT, MomentFilter0, {dirT}, Transform.mirrorW )
		ELSIF degreeT = 1 THEN Transform.Filter4D( RESULT, RESULT, MomentFilter1, {dirT}, Transform.antimirrorW )
		ELSIF degreeT = 2 THEN Transform.Filter4D( RESULT, RESULT, MomentFilter2, {dirT}, Transform.mirrorW )
		ELSIF degreeT = skip THEN  (*nothing*)
		END;
		RETURN RESULT;
	END Moment;

END HypercubeMoments.

OFormatter.Format *