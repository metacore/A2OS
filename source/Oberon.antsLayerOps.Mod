MODULE antsLayerOps IN Oberon;   (** fof  **)

IMPORT antsViews, antsPictureViews, antsImageViews, antsArrayImages, antsArrayPictures, antsArrayObjects,
	aM := antsMessages, vyPort, Objects, Images, Pictures;

(** initialize image from picture by copying picture contents **)
	PROCEDURE PictToImage( pict: Pictures.Picture;  img: Images.Image );
	VAR idx, max, dr, dg, db, pr, pg, pb, y, x, x0, x1: INTEGER;  default: BOOLEAN;  pal: Images.Palette;  fmt: Images.Format;  adr: LONGINT;
		pix: Images.Pixel;  r, g, b: INTEGER;
	BEGIN
		Images.Create( img, pict.width, pict.height, Images.BGRA8888 );

		(* get picture contents *)
		y := 0;
		WHILE y < pict.height DO
			x0 := 0;
			WHILE x0 < pict.width DO
				x1 := x0;  Pictures.GetRun( pict, idx, x1, y );  Pictures.GetColor( pict, idx, r, g, b );
				Images.SetRGBA( pix, r, g, b, 255 );
				FOR x := x0 TO x1 - 1 DO Images.Put( img, x, y, pix, Images.SrcCopy );  END;
				x0 := x1;
			END;
			INC( y )
		END
	END PictToImage;

	PROCEDURE Exchange*;
	VAR layer, nlayer: antsViews.tLayer;  pict: vyPort.Picture;  ai: antsArrayImages.tObject;  ilayer: antsImageViews.tLayer;
		ap: antsArrayPictures.tObject;  player: antsPictureViews.tLayer;
	BEGIN
		layer := antsViews.tempLayer;  pict := vyPort.GetFocusPicture();
		IF (layer = NIL ) THEN aM.S( "Layer IS NIL" );  RETURN END;
		IF layer IS antsPictureViews.tLayer THEN
			WITH layer: antsPictureViews.tLayer DO
				IF layer.E.A # NIL THEN
					antsArrayImages.Gen;  ai := Objects.NewObj( antsArrayImages.tObject );  antsArrayImages.Init( ai );
					antsArrayImages.FromArray( ai, layer.E.A );  antsImageViews.New;
					ilayer := Objects.NewObj( antsImageViews.tLayer );  antsImageViews.Open( ilayer, ai );
					ilayer.pal := layer.pal;  vyPort.RemoveLayer( pict, layer );  vyPort.AddLayer( pict, ilayer );
				ELSIF layer.E.pict # NIL THEN
					antsArrayImages.Gen;  ai := Objects.NewObj( antsArrayImages.tObject );  antsArrayImages.Init( ai );
					NEW( ai.img );  PictToImage( layer.E.pict, ai.img );  ai.w := layer.E.w;  ai.h := layer.E.h;  antsImageViews.New;
					ilayer := Objects.NewObj( antsImageViews.tLayer );  antsImageViews.Open( ilayer, ai );
					ilayer.pal := layer.pal;  vyPort.RemoveLayer( pict, layer );  vyPort.AddLayer( pict, ilayer );

					aM.eS( "Layer's Array is NIL" );
				END;
			END;
		ELSIF layer IS antsImageViews.tLayer THEN
			WITH layer: antsImageViews.tLayer DO
				IF layer.E.A # NIL THEN
					antsArrayPictures.Gen;  ap := Objects.NewObj( antsArrayPictures.tObject );  antsArrayPictures.Init( ap );
					antsArrayPictures.FromArray( ap, layer.E.A );  antsPictureViews.New;
					player := Objects.NewObj( antsPictureViews.tLayer );  antsPictureViews.Open( player, ap );
					player.pal := layer.pal;  vyPort.RemoveLayer( pict, layer );  vyPort.AddLayer( pict, player );
				ELSE aM.eS( "Layer's Array is NIL" );
				END;
			END;
		ELSE aM.eS( "Is not the right type layer!" );
		END;
	END Exchange;

END antsLayerOps.
System.Free antsLayerOps ~