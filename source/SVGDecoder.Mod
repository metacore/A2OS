MODULE SVGDecoder;

IMPORT Codecs, Streams, WMGraphics, Raster, SVGLoader, SVG, XML, XMLScanner, XMLParser;

TYPE
	SVGDecoder = OBJECT(Codecs.ImageDecoder)
		VAR
			in: Streams.Reader;
			img: Raster.Image;
			width, height: SIZE;

		(* open the decoder on a file *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : INTEGER);
		VAR
			xmlScanner: XMLScanner.Scanner;
			xmlParser: XMLParser.Parser;
			xmlDoc: XML.Document;
			xmlRoot: XML.Element;
		BEGIN
			IF in = NIL THEN SVG.Error("SVGCodec: Input Stream is NIL"); RETURN END;
			SELF.in := in;

			NEW(xmlScanner, in);
			NEW(xmlParser, xmlScanner);

			xmlDoc := xmlParser.Parse();
			IF xmlDoc = NIL THEN SVG.Error("SVGCodec: XML Doc is NIL"); RETURN END;

			xmlRoot := xmlDoc.GetRoot();
			IF xmlRoot = NIL THEN SVG.Error("SVGCodec: XML root element is NIL"); RETURN END;

			img := SVGLoader.LoadSVGEmbedded(xmlRoot);
			IF img = NIL THEN SVG.Error("SVGCodec: Image is NIL"); RETURN END;

			width := img.width;
			height := img.height;
		END Open;

		PROCEDURE GetImageInfo*(VAR width, height : SIZE; VAR format, maxProgressionLevel : SIGNED32);
		BEGIN
			width := SELF.width;
			height := SELF.height;
		END GetImageInfo;

		(** Render will read and decode the image data up to progrssionLevel.
			If the progressionLevel is lower than a previously rendered progressionLevel,
			the new level can be ignored by the decoder. If no progressionLevel is set with
			SetProgressionLevel, the level is assumed to be maxProgressionLevel of the image,
			which corresponds to best image quality.
		 *)
		PROCEDURE SetProgressionLevel*(progressionLevel: SIGNED32);
		END SetProgressionLevel;

		(* return the image in Raster format that best matches the format *)
		PROCEDURE GetNativeImage*(VAR img : Raster.Image);
		BEGIN
			img := SELF.img;
		END GetNativeImage;

		(* renders the image into the given Raster.Image at the given progressionLevel *)
		PROCEDURE Render*(img : Raster.Image);
		VAR canvas : WMGraphics.BufferCanvas;
		BEGIN
			IF SELF.img#NIL THEN
				NEW(canvas, img);
				canvas.DrawImage(0, 0, SELF.img, WMGraphics.ModeCopy);
			END
		END Render;
	END SVGDecoder;

PROCEDURE Factory*() : Codecs.ImageDecoder;
VAR p : SVGDecoder;
BEGIN
	NEW(p);
	RETURN p
END Factory;

END SVGDecoder.
