MODULE MatrixMoments;   (**  AUTHOR "Patrick Hunziker"; PURPOSE ""; , all rights, 2008 **)

IMPORT MatrixBase, Filters := LinearFilters, Transform := PlanarTransform;

CONST
	dirX = 1;  dirY = 0;  Skip* = -1;

TYPE
	Datatype = MatrixBase.Datatype;
	Matrix = ARRAY [ * , * ] OF Datatype;

	PROCEDURE Moment*( CONST from: Matrix;  degreeX, degreeY: SIGNED32 ): Matrix;
	VAR MomentFilter0, MomentFilter1, MomentFilter2: Filters.Filter;
	BEGIN
		ASSERT( LEN( from, 0 ) > 0 );
		IF (LEN( RESULT, 0 ) # LEN( from, 0 )) OR (LEN( RESULT, 1 ) # LEN( from, 1 )) THEN NEW( RESULT, LEN( from, 0 ), LEN( from, 1 ) ) END;
		MomentFilter0 := Filters.CreateSplineFilter( Filters.MomentCubic0 );
		MomentFilter1 := Filters.CreateSplineFilter( Filters.MomentCubic1 );
		MomentFilter2 := Filters.CreateSplineFilter( Filters.MomentCubic2 );
		IF degreeX = 0 THEN Transform.Filter2D( from, RESULT, MomentFilter0, {dirX}, Transform.mirrorW )
		ELSIF degreeX = 1 THEN Transform.Filter2D( from, RESULT, MomentFilter1, {dirX}, Transform.antimirrorW )
		ELSIF degreeX = 2 THEN Transform.Filter2D( from, RESULT, MomentFilter2, {dirX}, Transform.mirrorW )
		ELSIF degreeX = Skip THEN RESULT := from;   (*copy unchanged to result cube*)
		END;
		IF degreeY = 0 THEN Transform.Filter2D( RESULT, RESULT, MomentFilter0, {dirY}, Transform.mirrorW )
		ELSIF degreeY = 1 THEN Transform.Filter2D( RESULT, RESULT, MomentFilter1, {dirY}, Transform.antimirrorW )
		ELSIF degreeY = 2 THEN Transform.Filter2D( RESULT, RESULT, MomentFilter2, {dirY}, Transform.mirrorW )
		ELSIF degreeY = Skip THEN  (*nothing*)
		END;
		RETURN RESULT;
	END Moment;

END MatrixMoments.



OFormatter.Format *
