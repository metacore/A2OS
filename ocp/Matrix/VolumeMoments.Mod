MODULE VolumeMoments;   (**  AUTHOR "Patrick Hunziker"; PURPOSE ""; , all rights, 2008 **)

IMPORT MatrixBase, Filters := LinearFilters, Transform := VolumeTransform;

CONST
	dirZ = 0;  dirY = 1;  dirX = 2;  skip = -1;

TYPE
	Datatype = MatrixBase.Datatype;  Cube = ARRAY [ * , * , * ] OF Datatype;

	(**
Precondition:
Postcondition:
*)
	PROCEDURE Moment*( CONST from: Cube;  degreeX, degreeY, degreeZ: SIGNED32 ): Cube;
	VAR MomentFilter0, MomentFilter1, MomentFilter2, filter: Filters.Filter;
	BEGIN
		ASSERT( LEN( from, 0 ) > 0 );
		IF (LEN( RESULT, 0 ) # LEN( from, 0 )) OR (LEN( RESULT, 1 ) # LEN( from, 1 )) OR (LEN( RESULT, 2 ) # LEN( from, 2 )) THEN
			 NEW( RESULT, LEN( from, 0 ), LEN( from, 1 ), LEN( from, 2 ) )
		END;
		IF (degreeX = degreeY) & (degreeY = degreeZ) THEN
			IF degreeX = skip THEN RETURN RESULT
			ELSE filter := Filters.CreateSplineFilter( Filters.MomentCubic0 + degreeX );  Transform.Filter3D( from, RESULT, filter, {0, 1, 2}, Transform.mirrorW );  RETURN RESULT
			END;
		END;
		MomentFilter0 := Filters.CreateSplineFilter( Filters.MomentCubic0 );  MomentFilter1 := Filters.CreateSplineFilter( Filters.MomentCubic1 );
		MomentFilter2 := Filters.CreateSplineFilter( Filters.MomentCubic2 );
		IF degreeX = 0 THEN Transform.Filter3D( from, RESULT, MomentFilter0, {dirX}, Transform.mirrorW )
		ELSIF degreeX = 1 THEN Transform.Filter3D( from, RESULT, MomentFilter1, {dirX}, Transform.antimirrorW )
		ELSIF degreeX = 2 THEN Transform.Filter3D( from, RESULT, MomentFilter2, {dirX}, Transform.mirrorW )
		ELSIF degreeX = skip THEN
			RESULT := from;   (*copy unchanged to result cube*)
		END;
		IF degreeY = 0 THEN Transform.Filter3D( RESULT, RESULT, MomentFilter0, {dirY}, Transform.mirrorW )
		ELSIF degreeY = 1 THEN Transform.Filter3D( RESULT, RESULT, MomentFilter1, {dirY}, Transform.antimirrorW )
		ELSIF degreeY = 2 THEN Transform.Filter3D( RESULT, RESULT, MomentFilter2, {dirY}, Transform.mirrorW )
		ELSIF degreeY = skip THEN  (*nothing*)
		END;
		IF degreeZ = 0 THEN Transform.Filter3D( RESULT, RESULT, MomentFilter0, {dirZ}, Transform.mirrorW )
		ELSIF degreeZ = 1 THEN Transform.Filter3D( RESULT, RESULT, MomentFilter1, {dirZ}, Transform.antimirrorW )
		ELSIF degreeZ = 2 THEN Transform.Filter3D( RESULT, RESULT, MomentFilter2, {dirZ}, Transform.mirrorW )
		ELSIF degreeZ = skip THEN  (*nothing*)
		END;
		RETURN RESULT;
	END Moment;

END VolumeMoments.

OFormatter.Format *