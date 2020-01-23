MODULE WMMatrixLoader; (** AUTHOR "Patrick Hunziker"; PURPOSE "Glue for transparent visualization of matrix data files"; *)

(*
Visualize Matrices in GUI Windows.
to enable direct opening from File List Window, add this to the FileHandler section in Configuration.XML:
			<Section name="mta">
				<Setting name="Open" value="WMMatrixLoader.Open"/>
			</Section>
*)

IMPORT WMWindowManager, WMGraphics, WMMatrix, WMStack, Files, Streams, Strings, Options, MatrixBase, MatrixUtilities,MatrixRaster, Codecs, Commands, WMTensor;

CONST
	(* display options *)
	MaxIntensity*=1;
	SumIntensity*=2;

PROCEDURE Load*(CONST name:Files.FileName; orientation:SIGNED32; options:Options.Options): WMWindowManager.Window;
VAR d: ARRAY [?] OF MatrixBase.Datatype;
	d2: ARRAY [*,*] OF MatrixBase.Datatype;
	dr: ARRAY [?] OF FLOAT32;
	d16: ARRAY [?] OF SIGNED16;
	d32: ARRAY[?] OF SIGNED32;
	len: ARRAY [*] OF SIZE;
	f:Files.File;
	r:Files.Reader;
	mWindow:WMMatrix.Window;
	sWindow:WMStack.Window;
	tWindow: WMTensor.Window;
	title: Files.FileName;
	i,x,y,z,xx,yy: SIZE;
	datatype, version:SIGNED32;
	max: MatrixBase.Datatype;
BEGIN
	f:=Files.Old(name);
	IF f#NIL THEN
		Files.OpenReader(r,f,0);
		MatrixUtilities.ParseHeader(r,version, datatype,len);
		NEW(d,len);
		CASE datatype OF
		MatrixUtilities.DatatypeUInt8: NEW(d16,len); MatrixUtilities.ReadUInt8(r,d16); d:=d16;
		| MatrixUtilities.DatatypeLInt: NEW(d32,len); MatrixUtilities.ReadLInt(r,d32); d:=d32;
		| MatrixUtilities.DatatypeR : NEW(d, len); MatrixUtilities.ReadR(r,dr); d:=dr;
		| MatrixUtilities.DatatypeLR : NEW(d, len); MatrixUtilities.ReadLR(r,d);
		ELSE HALT(200);
		END;
		IF DIM(d)=2 THEN
			NEW(mWindow, d, name);
			mWindow.AddWindow;
			RETURN mWindow;
		ELSIF DIM(d)=1 THEN
			NEW(d2,1,LEN(d,0));
			d2[0,?]:=d[?];
			NEW(mWindow, d2, name);
			mWindow.AddWindow;
			RETURN mWindow;
		ELSIF DIM(d)=3 THEN
			IF (options#NIL)&options.GetFlag("max") THEN
				IF orientation=0 THEN
					IF options.GetFlag("oblique") THEN
						NEW(d2,LEN(d,1)+LEN(d,0), LEN(d,2)+LEN(d,0));
						d2[..LEN(d,1)-1, ..LEN(d,2)-1]:=d[0,..,..];
						FOR y:=0 TO LEN(d2,0)-1 DO
							FOR x:=0 TO LEN(d2,1)-1 DO
								max:=0;
								FOR z:=0 TO LEN(d,0)-1 DO
									yy:=y-z; xx:=x-z;
									IF (yy>0) & (xx>0) & (yy<LEN(d,1)) & (xx<LEN(d,2)) THEN
										max:=MAX(max, d[z,yy,xx]);
									END;
								END;
								d2[y, x ]:=max; (*! tbd for oblique*)
							END;
						END;

					ELSE
						d2:=d[0,..,..];
						FOR y:=0 TO LEN(d,1)-1 DO
							FOR x:=0 TO LEN(d,2)-1 DO
								d2[y,x]:=MAX(d[..,y,x]);
							END;
						END;
					END;
				ELSIF orientation=1 THEN
					d2:=d[..,0,..];
					FOR x:=0 TO LEN(d,0)-1 DO
						FOR y:=0 TO LEN(d,2)-1 DO
							d2[x,y]:=MAX(d[x,..,y]);
						END;
					END;
				ELSIF orientation=2 THEN
					d2:=d[..,..,0];
					FOR x:=0 TO LEN(d,0)-1 DO
						FOR y:=0 TO LEN(d,1)-1 DO
							d2[x,y]:=MAX(d[x,y,..]);
						END;
					END;
				END;
				title:="Max "; Strings.Append(title,name);
				NEW(mWindow, d2, title);
				mWindow.AddWindow;
				RETURN mWindow;
			ELSIF (options#NIL)&options.GetFlag("sum") THEN
				IF orientation=0 THEN
					IF options.GetFlag("oblique") THEN
						NEW(d2,LEN(d,1)+LEN(d,0), LEN(d,2)+LEN(d,0));
						d2[..LEN(d,1)-1, ..LEN(d,2)-1]:=d[0,..,..];
						FOR i:=1 TO LEN(d,0)-1 DO
							d2[	i..i+LEN(d,1)-1, i..i+LEN(d,2)-1]:=d2[	i..i+LEN(d,1)-1, i..i+LEN(d,2)-1]+d[i,..,..];
						END;
					ELSE
						d2:=d[0,..,..];
						FOR i:=1 TO LEN(d,0)-1 DO
							d2:=d2+d[i,..,..];
						END;
					END;
				ELSIF orientation=1 THEN
					d2:=d[..,0,..];
					FOR i:=1 TO LEN(d,1)-1 DO d2:=d2+d[..,i,..] END;
				ELSIF orientation=2 THEN
					d2:=d[..,..,0];
					FOR i:=1 TO LEN(d,2)-1 DO d2:=d2+d[..,..,i] END;
				END;
				title:="Sum "; Strings.Append(title,name);
				NEW(mWindow, d2, title);
				mWindow.AddWindow;
				RETURN mWindow;
			ELSE
				NEW(sWindow, d, name,orientation);
				sWindow.AddWindow;
				RETURN sWindow;
			END;
		ELSIF DIM(d)=4 THEN
			NEW(tWindow, d, name,0);
			tWindow.AddWindow;
			RETURN tWindow;
		ELSE RETURN NIL
		END;
	ELSE RETURN NIL
	END;
END Load;

PROCEDURE Open*(context:Commands.Context);
VAR name: Files.FileName; w:WMWindowManager.Window; orientation:SIGNED32;
VAR options : Options.Options;
BEGIN
	NEW(options);
	options.Add("m", "max", Options.Flag);
	options.Add("s", "sum", Options.Flag);
	options.Add("o", "oblique", Options.Flag);
	IF (context#NIL) & options.Parse(context.arg, context.error) & context.arg.GetString(name) THEN
		IF ~context.arg.GetInteger(orientation ,FALSE) THEN orientation:=0 END;
		w:=Load(name, orientation,options);
	END;
END Open;

PROCEDURE Import*(fileName: Files.FileName):ARRAY [?] OF SIGNED16; (** filename ~ *)
VAR
	name : Files.FileName;
	pw : WMWindowManager.BufferWindow;
	res, x : INTEGER;
	w, h : SIZE;
	dec : Codecs.ImageDecoder;
	rdr : Streams.Reader;
	ext : ARRAY 16 OF CHAR;
	icon : WMGraphics.Image;
	canvas : WMGraphics.BufferCanvas;
	errStr: ARRAY 128 OF CHAR;
	result: ARRAY [?] OF SIGNED16;
	err: ARRAY [1,10,10] OF SIGNED16;
BEGIN
	Strings.GetExtension(fileName, name, ext);
	Strings.UpperCase(ext);
	dec := Codecs.GetImageDecoder(ext);
	IF dec = NIL THEN
		COPY("WMMatrixLoader.Import: No decoder found for ",errStr);
		RETURN err
	END;
	rdr := Codecs.OpenInputStream(fileName);
	IF rdr # NIL THEN
		dec.Open(rdr, res);
		IF res = 0 THEN
			dec.GetImageInfo(w, h, x, x);
			NEW(pw, w, h, TRUE);
			dec.Render(pw.img);
			MatrixRaster.ImageToArray(pw.img, result);
			RETURN result;
		ELSE
			COPY("WMMatrixLoader.Import: Could not open decoder for file ",errStr);
		END;
	ELSE
		COPY("WMMatrixLoader.Import: Could not open inputstream for file ",errStr);
	END;
	RETURN err
END Import;

PROCEDURE Do*(context:Commands.Context);
VAR fn: Files.FileName;
	data: ARRAY [?] OF SIGNED16;
	i:SIZE;
	window:WMMatrix.Window;
BEGIN
	IF context.arg.GetString(fn) THEN
		data:=Import(fn);
		FOR i:=0 TO DIM(data)-1 DO
			context.out.Int(LEN(data,i),6);
		END;
		context.out.Ln; context.out.Update;
		IF DIM(data)=3 THEN
			FOR i:=0 TO DIM(data)-1 DO
				NEW(window, data[i,..,..], "");
				window.AddWindow;
			END;
		END;
	END;
END Do;


END WMMatrixLoader.

WMMatrixLoader.Open A.MtA ~ (* matrix example *)
WMMatrixLoader.Open -s BraidVolume16.MtA ~ (* sum projection, volume example *)
WMMatrixLoader.Open -m BraidVolume16.MtA 0 ~ (* max projection, volume example *)
WMMatrixLoader.Open -m BraidVolume16.MtA 1 ~ (* max projection, volume example *)
WMMatrixLoader.Open -m BraidVolume16.MtA 2 ~ (* max projection, volume example *)
WMMatrixLoader.Open -m -o BraidVolume64.MtA 0 ~ (* max projection, volume example *)
WMMatrixLoader.Open -s -o BraidVolume64.MtA 0 ~ (* max projection, volume example *)



WMMatrixLoader.Open BraidVolume16.MtA 1~ (* volume example *)
WMMatrixLoader.Open BraidVolume16.MtA 2~ (* volume example *)

WMMatrixLoader.Do SchwarzeDame.png~

SystemTools.FreeDownTo WMMatrixLoader ~
