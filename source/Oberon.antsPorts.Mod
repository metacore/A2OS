MODULE antsPorts IN Oberon ;	(**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT vyBase,vyName,vyTypes,vyPort, vyLinePlot, antsPointPlot, vyScatter1, vyHistogram, vyDisplay2d, aM := antsMessages, antsCommands;

TYPE

PortLink = OBJECT (vyBase.Object)
VAR
	pict: vyPort.Picture;
END PortLink;

	(*für anzeigen der PSNR Vec*)
	PROCEDURE ShowVec*;
	VAR layer: vyPort.tLayer; lineplot: vyLinePlot.tLayer; pointplot: antsPointPlot.tLayer; histogram: vyHistogram.tLayer; scatter: vyScatter1.tLayer;  vec, obj: vyBase.Object;
		pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  min, max: FLOAT64;  minY, maxY: FLOAT64;  nans: SIGNED32;
		port,as: ARRAY 256 OF CHAR;
		portlink: PortLink;
	BEGIN
		antsCommands.InitScan( "port=NAME vec=OBJECT as=NAME [>forcenew]" );
		IF antsCommands.ExpectName( "port", port ) &  antsCommands.ExpectObject( "vec", vec )  & antsCommands.ExpectName("as",as) THEN
			WITH vec: vyBase.tVector DO
					IF as="lines"  THEN NEW( lineplot );  vyLinePlot.Open(lineplot,vec,0,0,NIL,NIL,0); layer := lineplot;
					ELSIF as="points" THEN NEW(pointplot); antsPointPlot.Open(pointplot,vec);  layer := pointplot;
					ELSIF as="scatter" THEN NEW(scatter); vyScatter1.Init(scatter,vec);  layer := scatter;
					ELSIF as="histogram" THEN NEW(histogram); vyHistogram.Init(histogram,vec);  layer := histogram;
					ELSE aM.eS("Specify as=lines or as=points"); RETURN;
					END;

					IF ~antsCommands.Find( "forcenew" ) THEN
						obj := vyName.FindObj( port );
						IF obj # NIL THEN
							WITH obj: PortLink DO pict := obj.pict;
							END;
						END;
					END;
					IF (pict = NIL ) THEN
						NEW( portlink );  vyName.RegisterNamed( portlink, port );  vyTypes.VGetMinMax( layer.x, min, max, nans );

						IF min < -100000 THEN min := -100000 END;
						IF max > 100000 THEN max := 100000 END;

						IF max = min THEN min := min - 0.5;  max := min + 1
						END;

						aM.SRSR( "min=", min, "max=", max );

						NEW( c );  vyDisplay2d.OpenC2d( c, 0, min, vyBase.Len(vec,0), max);
						pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  portlink.pict := pict;
					END;
					vyPort.AddLayer( pict, layer );  vyPort.SetFocusPicture( pict );

				END;
			END;
	END ShowVec;
END antsPorts.

antsExpressions.Install
myVec := RanV(100);




antsPorts.ShowVec myPort myVec lines ~
antsPorts.ShowVec myPort myVec points ~
antsPorts.ShowVec myPort myVec histogram ~
antsPorts.ShowVec myPort myVec scatter ~
