MODULE WMPicView;	(** AUTHOR "tf"; PURPOSE "Open a window with a picture..."; *)

IMPORT
	Commands, Streams, Strings, Codecs, Raster, Files,
	WMRectangles, WMGraphics, WM := WMWindowManager;

PROCEDURE Open*(context : Commands.Context); (** filename ~ *)
VAR
	fn, name : Files.FileName;
	pw : WM.BufferWindow;
	res, w, h, x : LONGINT;
	dec : Codecs.ImageDecoder;
	rdr : Streams.Reader;
	ext : ARRAY 16 OF CHAR;
	icon : WMGraphics.Image;
	canvas : WMGraphics.BufferCanvas;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(fn);
	Strings.Trim(fn, '"');
	Strings.GetExtension(fn, name, ext);
	Strings.UpperCase(ext);
	dec := Codecs.GetImageDecoder(ext);
	IF dec = NIL THEN
		context.error.String("WMPicView: No decoder found for "); context.error.String(ext); context.error.Ln;
		RETURN
	END;
	rdr := Codecs.OpenInputStream(fn);
	IF rdr # NIL THEN
		dec.Open(rdr, res);
		IF res = 0 THEN
			dec.GetImageInfo(w, h, x, x);
			NEW(pw, w, h, TRUE);
			dec.Render(pw.img);
			NEW(icon);
			pw.SetTitle(Strings.NewString(fn));
			Raster.Create(icon, 64, 64, Raster.BGRA8888);
			NEW(canvas, icon);
			canvas.ScaleImage(pw.img,
				WMRectangles.MakeRect(0, 0, pw.img.width, pw.img.height),
				WMRectangles.MakeRect(0, 0, 64, 64),
				WMGraphics.ModeCopy, WMGraphics.ScaleBilinear);
			pw.SetIcon(icon);
			WM.DefaultAddWindow(pw);
		ELSE
			context.error.String("WMPicView: Could not open decoder for file "); context.error.String(fn); context.error.Ln;
		END;
	ELSE
		context.error.String("WMPicView: Could not open inputstream for file "); context.error.String(fn); context.error.Ln;
	END;
END Open;

PROCEDURE Convert*(context : Commands.Context);
VAR fni, fno,
	inName, outName : Files.FileName;
	res : WORD;
	dec : Codecs.ImageDecoder;
	enc : Codecs.ImageEncoder;
	img : Raster.Image;
	rdr : Streams.Reader;
	outX, inX : ARRAY 16 OF CHAR;
	f : Files.File;
	w : Files.Writer;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(fni);
	Strings.GetExtension(fni, inName, inX);
	Strings.UpperCase(inX);

	context.arg.SkipWhitespace; context.arg.String(fno);
	Strings.GetExtension(fno, outName, outX);
	Strings.UpperCase(outX);

	dec := Codecs.GetImageDecoder(inX);
	IF dec = NIL THEN
		context.error.String("No decoder found for "); context.error.String(inX); context.error.Ln;
		RETURN
	END;

	enc := Codecs.GetImageEncoder(outX);
	IF enc = NIL THEN
		context.error.String("No encoder found for "); context.error.String(outX); context.error.Ln;
		RETURN
	END;

	rdr := Codecs.OpenInputStream(fni);
	IF rdr # NIL THEN
		dec.Open(rdr, res);
		IF res = 0 THEN
			dec.GetNativeImage(img);

			f := Files.New(fno);
			Files.OpenWriter(w, f, 0);
			enc.Open(w);
			enc.WriteImage(img, res);
			IF res = 0 THEN
				Files.Register(f);
				context.out.String("Done");
			ELSE
				context.out.String("Not converted");
			END
		END
	END;
END Convert;

END WMPicView.

SystemTools.Free WMPicView ~
WMPicView.Open  	errorpos.png ~
WMPicView.Convert BluebottlePic0.png temp.gif ~