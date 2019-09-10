MODULE SVGFilters;

IMPORT SVG, SVGColors, SVGUtilities, XML, XMLObjects, Raster, Math;

(* Constants that determine the input, the blend-mode and the type of color-matrix *)
CONST
	InSourceGraphic*=0;
	InFilterElement*=1;
	BlendModeNormal=0;
	BlendModeMultiply=1;
	BlendModeScreen=2;
	BlendModeDarken=3;
	BlendModeLighten=4;
	ColorMatrixTypeMatrix=0;
	ColorMatrixTypeSaturate=1;
	ColorMatrixTypeHueRotate=2;
	ColorMatrixTypeLuminanceToAlpha=3;

TYPE
	Buffer*=SVG.Document;
	FilterWindow*=POINTER TO FilterWindowDesc;
	FilterWindowDesc*=RECORD
		x*, y*, width*, height*: SVG.Length;
		modeBlend, modeCopy: Raster.Mode;
		sourceGraphic: Buffer;
	END;
	In*=POINTER TO InDesc;
	InDesc*=RECORD
		type*: SIGNED8;
		fe*: FilterElement;
	END;
	FilterElement*=OBJECT
		VAR
			in*: In;
			x*,y*,width*,height*: SVG.Length;

		(* Apply this filter element to a new target *)
		PROCEDURE Apply*(window: FilterWindow): Buffer;
		VAR target: Buffer;
		BEGIN
			target := SVG.NewDocument(ENTIER(width),ENTIER(height));
			ApplyFilter(window, target);
			RETURN target;
		END Apply;

		(* Apply this filter element to the specifies target *)
		PROCEDURE ApplyFilter*(window: FilterWindow; target: Buffer);
		BEGIN
			HALT(99)
		END ApplyFilter;

		(* Get the buffer of the processed input *)
		PROCEDURE GetInBuffer(in: In; window: FilterWindow): Buffer;
		VAR b:Buffer; fe: FilterElement;
		BEGIN
			CASE in.type OF
				InSourceGraphic: RETURN window.sourceGraphic;
				| InFilterElement: fe:=in.fe; b:=fe.Apply(window); RETURN b;
			END
		END GetInBuffer;

		(* Get a pixel from the source buffer*)
		PROCEDURE GetInPixel(x,y, tx0,ty0: SIZE; window: FilterWindow; in: In; source: Buffer; VAR pix: Raster.Pixel);
		BEGIN
			IF in.type#InFilterElement THEN
				x:=x+tx0-ENTIER(window.x);
				y:=y+ty0-ENTIER(window.y);
			END;
			IF (0 <= x) & (x < source.width) & (0 <= y) & (y < source.height) THEN
				Raster.Get(source,x,y, pix, window.modeCopy);
			ELSE
				Raster.SetRGBA(pix,0,0,0,0)
			END
		END GetInPixel;

	END FilterElement;

	feBlend*=OBJECT(FilterElement)
		VAR
			in2*: In;
			mode*: SIGNED8;

		(* Apply this filter element *)
		PROCEDURE ApplyFilter*(window: FilterWindow; target: Buffer);
		VAR tx,ty: SIZE;
			source,source2: Buffer;
			pix,pix2: Raster.Pixel;
		BEGIN
			source := GetInBuffer(in,window);
			source2 := GetInBuffer(in2,window);
			FOR ty:=0 TO target.height-1 DO
			FOR tx:=0 TO target.width-1 DO
				GetInPixel(tx,ty, ENTIER(x),ENTIER(y), window, in,source, pix);
				GetInPixel(tx,ty, ENTIER(x),ENTIER(y), window, in2,source2, pix2);
				Blend(pix,pix2);
				Raster.Put(target, tx,ty, pix, window.modeCopy)
			END; END;
		END ApplyFilter;

		(* Blend two pixels *)
		PROCEDURE Blend(VAR a, b: Raster.Pixel);
		VAR fa, fb, ta, tb, i: SIZE;
		BEGIN
			CASE mode OF
			| BlendModeNormal:	(* (1-qa)*cb+ca *)
				fa := 255;
				fb := 255-ORD(a[3]);
				FOR i := 0 TO 2 DO
					a[i] := Raster.Clamp[200H + (fa * ORD(a[i]) + fb * ORD(b[i])) DIV 255]
				END
			| BlendModeMultiply:	(* (1-qa)*cb+(1-qb)*ca+ca*cb *)
				fb := 255-ORD(a[3]);
				FOR i := 0 TO 2 DO
					fa :=  255-ORD(b[3])+ORD(b[i]);
					a[i] := Raster.Clamp[200H + (fa * ORD(a[i]) + fb * ORD(b[i])) DIV 255]
				END
			| BlendModeScreen:	(* cb+ca-ca*cb *)
				fb := 255;
				FOR i := 0 TO 2 DO
					fa := 255-ORD(b[i]);
					a[i] := Raster.Clamp[200H + (fa * ORD(a[i]) + fb * ORD(b[i])) DIV 255]
				END
			| BlendModeDarken:	(* Min((1-qa)*cb+ca,(1-qb)*ca+cb) *)
				fa := 255-ORD(b[3]);
				fb := 255-ORD(a[3]);
				FOR i := 0 TO 2 DO
					ta := fa * ORD(a[i]) + 255 * LONG(ORD(b[i]));
					tb := 255 * LONG(ORD(a[i])) + fb * ORD(b[i]);
					IF ta<tb THEN
						a[i] := Raster.Clamp[200H + ta DIV 255]
					ELSE
						a[i] := Raster.Clamp[200H + tb DIV 255]
					END
				END
			| BlendModeLighten:	(* Max((1-qa)*cb+ca,(1-qb)*ca+cb) *)
				fa := 255-ORD(b[3]);
				fb := 255-ORD(a[3]);
				FOR i := 0 TO 2 DO
					ta := fa * ORD(a[i]) + 255 * LONG(ORD(b[i]));
					tb := 255 * LONG(ORD(a[i])) + fb * ORD(b[i]);
					IF ta>tb THEN
						a[i] := Raster.Clamp[200H + ta DIV 255]
					ELSE
						a[i] := Raster.Clamp[200H + tb DIV 255]
					END
				END
			END;

			(* 1- (1-qa)*(1-qb) *)
			fa := 255-ORD(a[3]);
			fb := 255-ORD(b[3]);
			a[3] := Raster.Clamp[200H + 255 - (fa*fb) DIV 255]
		END Blend;
	END feBlend;

	feOffset*=OBJECT(FilterElement)
		VAR
			dx*,dy*: SVG.Length;

		(* Apply this filter element *)
		PROCEDURE ApplyFilter*(window: FilterWindow; target: Buffer);
		VAR tx,ty, sx,sy: SIZE;
			source: Buffer;
			pix: Raster.Pixel;
		BEGIN
			source := GetInBuffer(in,window);
			FOR ty:=0 TO target.height-1 DO
			FOR tx:=0 TO target.width-1 DO
				sx := ENTIER(tx-dx);
				sy := ENTIER(ty-dy);
				GetInPixel(sx,sy, ENTIER(x),ENTIER(y), window, in,source, pix);
				Raster.Put(target, tx,ty, pix, window.modeCopy)
			END; END;
		END ApplyFilter;
	END feOffset;

	ColorMatrix*=RECORD
		a: ARRAY 5,4 OF FLOAT64;
	END;

	feColorMatrix*=OBJECT(FilterElement)
		VAR
			type*: SIGNED8;
			matrix*: ColorMatrix;

		(* Apply this filter element *)
		PROCEDURE ApplyFilter*(window: FilterWindow; target: Buffer);
		VAR tx,ty: SIZE;
			source: Buffer;
			pix: Raster.Pixel;
		BEGIN
			source := GetInBuffer(in,window);
			FOR ty:=0 TO target.height-1 DO
			FOR tx:=0 TO target.width-1 DO
				GetInPixel(tx,ty, ENTIER(x),ENTIER(y), window, in,source, pix);
				TransformByColorMatrix(pix,matrix);
				Raster.Put(target, tx,ty, pix, window.modeCopy)
			END; END;
		END ApplyFilter;
	END feColorMatrix;

	feGaussianBlur*=OBJECT(FilterElement)
		VAR
			stdDeviationX*, stdDeviationY*: SVG.Length;

		(* Apply this filter element *)
		PROCEDURE ApplyFilter*(window: FilterWindow; target: Buffer);
		VAR tx,ty, k: SIZE;
			source: Buffer;
			pix: Raster.Pixel;
			temp: Buffer;
			kernel: POINTER TO ARRAY OF FLOAT64;
			kernelSizeX, kernelSizeY, kernelHalfX, kernelHalfY: SIZE;
			norm, sSquared2: FLOAT64;
			sum: SVGColors.ColorSum;
		BEGIN
		(* Gaussian Kernel is seperable into a vertical part and a horizontal part. *)
		(* Prepare the buffers for both parts using the larger stdDeviation. *)
			kernelHalfX := 3*ENTIER(stdDeviationX);
			kernelHalfY := 3*ENTIER(stdDeviationY);
			kernelSizeX := 2*kernelHalfX+1;
			kernelSizeY := 2*kernelHalfY+1;
			IF stdDeviationX>stdDeviationY THEN NEW(kernel,kernelSizeX)
			ELSE NEW(kernel,kernelSizeY);
			END;

			source := GetInBuffer(in,window);
			temp := SVG.NewDocument(source.width, source.height);

		(* horizontal part *)
			sSquared2 := 2*stdDeviationX*stdDeviationX;
			norm := Math.sqrt(SHORT(sSquared2)*Math.pi);
			FOR k :=-kernelHalfX TO kernelHalfX DO
				kernel[kernelHalfX+k] := Math.exp(SHORT(-k*k/sSquared2)) / norm;
			END;

			FOR ty:=0 TO temp.height-1 DO
			FOR tx:=0 TO temp.width-1 DO
				sum[0] := 0; sum[1] := 0; sum[2] := 0; sum[3] := 0;
				FOR k:=-kernelHalfX TO kernelHalfX DO
					GetInPixel(tx+k,ty, ENTIER(x),ENTIER(y), window, in,source, pix);
					SVGColors.WeightedAdd(sum, kernel[kernelHalfX+k], pix);
				END;
				SVGColors.ColorSumToPixel(sum, pix);
				Raster.Put(temp, tx,ty, pix, window.modeCopy)
			END; END;

		(* vertical part *)
			sSquared2 := 2*stdDeviationY*stdDeviationY;
			norm := Math.sqrt(SHORT(sSquared2)*Math.pi);
			FOR k :=-kernelHalfY TO kernelHalfY DO
				kernel[kernelHalfY+k] := Math.exp(SHORT(-k*k/sSquared2)) / norm;
			END;

			FOR ty:=0 TO target.height-1 DO
			FOR tx:=0 TO target.width-1 DO
				sum[0] := 0; sum[1] := 0; sum[2] := 0; sum[3] := 0;
				FOR k:=-kernelHalfY TO kernelHalfY DO
					GetInPixel(tx,ty+k, ENTIER(x),ENTIER(y), window, in,temp, pix);
					SVGColors.WeightedAdd(sum, kernel[kernelHalfY+k], pix);
				END;
				SVGColors.ColorSumToPixel(sum, pix);
				Raster.Put(target, tx,ty, pix, window.modeCopy)
			END; END
		END ApplyFilter;
	END feGaussianBlur;

	feMerge*=OBJECT(FilterElement)
		VAR in2: XMLObjects.List;

		(* Apply this filter element *)
		PROCEDURE ApplyFilter*(window: FilterWindow; target: Buffer);
		VAR tx,ty: SIZE;
			source: Buffer;
			pix: Raster.Pixel;
			enum: XMLObjects.Enumerator;
			next: In;
			nextPtr: ANY;
		BEGIN
			IF in#NIL THEN
				source := GetInBuffer(in,window);
				FOR ty:=0 TO target.height-1 DO
				FOR tx:=0 TO target.width-1 DO
					GetInPixel(tx,ty, ENTIER(x),ENTIER(y), window, in,source, pix);
					Raster.Put(target, tx,ty, pix, window.modeCopy)
				END; END;

				IF in2#NIL THEN
					enum := in2.GetEnumerator();
					WHILE enum.HasMoreElements() DO
						nextPtr := enum.GetNext();
						next := nextPtr(In);
						source := GetInBuffer(next,window);
						FOR ty:=0 TO target.height-1 DO
						FOR tx:=0 TO target.width-1 DO
							GetInPixel(tx,ty, ENTIER(x),ENTIER(y), window, in,source, pix);
							Raster.Put(target, tx,ty, pix, window.modeBlend)
						END; END;
					END
				END
			END
		END ApplyFilter;

		(* Add a mergeNode *)
		PROCEDURE AddNode*(in: In);
		BEGIN
			IF in2=NIL THEN NEW(in2) END;
			in2.Add(in);
		END AddNode;
	END feMerge;

	feFlood*=OBJECT(FilterElement)
		VAR
			pix*: Raster.Pixel;

		(* Apply this filter element *)
		PROCEDURE ApplyFilter*(window: FilterWindow; target: Buffer);
		VAR tx,ty: SIZE;
		BEGIN
			FOR ty:=0 TO target.height-1 DO
			FOR tx:=0 TO target.width-1 DO
				Raster.Put(target, tx,ty, pix, window.modeCopy)
			END; END;
		END ApplyFilter;
	END feFlood;

	feImage*=OBJECT(FilterElement)
		VAR image*: Buffer;

		(* Apply this filter element *)
		PROCEDURE ApplyFilter*(window: FilterWindow; target: Buffer);
		VAR tx,ty, sx,sy: SIZE;
			pix: Raster.Pixel;
		BEGIN
			FOR ty:=0 TO target.height-1 DO
			FOR tx:=0 TO target.width-1 DO
				sx := ENTIER(tx*image.width/width);
				sy := ENTIER(ty*image.height/height);
				IF (sx <image.width) & (sy < image.height) THEN
					Raster.Get(image, sx,sy, pix, window.modeCopy);
				ELSE
					Raster.SetRGBA(pix,0,0,0,0)
				END;
				Raster.Put(target, tx,ty, pix, window.modeCopy)
			END; END;
		END ApplyFilter;
	END feImage;

	feTile*=OBJECT(FilterElement)

		(* Apply this filter element *)
		PROCEDURE ApplyFilter*(window: FilterWindow; target: Buffer);
		VAR tx,ty, sx,sy: SIZE;
			source: Buffer;
			pix: Raster.Pixel;
		BEGIN
			source := GetInBuffer(in,window);
			FOR ty:=0 TO target.height-1 DO
			FOR tx:=0 TO target.width-1 DO
				sx := tx MOD source.width;
				sy := ty MOD source.height;
				GetInPixel(sx,sy, ENTIER(x),ENTIER(y), window, in,source, pix);
				Raster.Put(target, tx,ty, pix, window.modeCopy)
			END; END;
		END ApplyFilter;
	END feTile;

	Filter*=OBJECT
		VAR fElements: XMLObjects.ArrayDict;
			rootElement*: FilterElement;
			window*: FilterWindow;

		PROCEDURE &New*;
		BEGIN
			NEW(fElements);
			NEW(window);
			Raster.InitMode(window.modeBlend, Raster.srcOverDst);
			Raster.InitMode(window.modeCopy, Raster.srcCopy);
		END New;

		(* Add a filter element *)
		PROCEDURE AddFilterElement*(fElement: FilterElement; id: SVG.String);
		BEGIN
			fElements.Remove(id^);
			fElements.Add(id^, fElement);
		END AddFilterElement;

		(* Get a filter element with some specified id *)
		PROCEDURE GetFilterElement*(id: SVG.String):FilterElement;
		VAR p: ANY;
		BEGIN
			p := fElements.Get(id^);
			IF p = NIL THEN RETURN NIL
			ELSE RETURN p(FilterElement) END
		END GetFilterElement;

		(* Apply this filter *)
		PROCEDURE Apply*(source, target: Buffer);
		VAR result: Buffer;
			minx, miny, maxx, maxy: SIZE;
		BEGIN
			IF rootElement#NIL THEN
				window.sourceGraphic := SVG.NewDocument(window.width,window.height);

				Raster.Copy(source, window.sourceGraphic,
					ENTIER(window.x), ENTIER(window.y), ENTIER(window.x+window.width), ENTIER(window.y+window.height),
					0, 0, window.modeCopy);

				result := rootElement.Apply(window);

				minx := ENTIER(rootElement.x);
				miny := ENTIER(rootElement.y);
				maxx := ENTIER(rootElement.x+result.width);
				maxy := ENTIER(rootElement.y+result.height);
				IF minx<0 THEN minx := 0 END;
				IF miny<0 THEN miny := 0 END;
				IF maxx>target.width THEN maxx := target.width END;
				IF maxy>target.height THEN maxy := target.height END;
				IF (minx<=maxx) & (miny<=maxy) THEN
					Raster.Copy(result, target,
						minx-ENTIER(rootElement.x), miny-ENTIER(rootElement.y), maxx-ENTIER(rootElement.x), maxy-ENTIER(rootElement.y),
						minx, miny, window.modeBlend)
				END
			ELSE
				SVG.Log("Filter has no elements");
			END
		END Apply;

	END Filter;

	FilterDict*=OBJECT
		VAR filters: XMLObjects.ArrayDict;

		PROCEDURE &New*;
		BEGIN
			NEW(filters)
		END New;

		(* Add a filter *)
		PROCEDURE AddFilter*(filter: Filter; id: SVG.String);
		BEGIN
			filters.Add(id^, filter)
		END AddFilter;

		(* Get a filter with some specified id *)
		PROCEDURE GetFilter*(id: SVG.String):Filter;
		VAR p: ANY;
		BEGIN
			p := filters.Get(id^);
			IF p = NIL THEN RETURN NIL
			ELSE RETURN p(Filter) END
		END GetFilter;
	END FilterDict;

	FilterStack*=OBJECT
		VAR
			topFilter: Filter;
			next: FilterStack;

		(* Push a new filter onto the stack *)
		PROCEDURE Push*(filter: Filter);
		VAR pushed: FilterStack;
		BEGIN
			NEW(pushed);

			pushed^ := SELF^;
			next := pushed;
			topFilter:=filter;
		END Push;

		(* Pop the top filter from the stack *)
		PROCEDURE Pop*(VAR filter: Filter);
		BEGIN
			filter := topFilter;
			SELF^ := next^;
		END Pop;
	END FilterStack;

(* Parse some in attribute of a filter element *)
PROCEDURE ParseIn*(value: SVG.String; VAR in: SIGNED8);
BEGIN
	IF value^ = "SourceGraphic" THEN in := InSourceGraphic
	ELSE
		in := InFilterElement
	END
END ParseIn;

(* Parse the blendMode attribute of some feBlend element *)
PROCEDURE ParseBlendMode*(value: SVG.String; VAR mode: SIGNED8);
BEGIN
	IF value^ = "normal" THEN mode := BlendModeNormal
	ELSIF value^ = "multiply" THEN mode := BlendModeMultiply
	ELSIF value^ = "screen" THEN mode := BlendModeScreen
	ELSIF value^ = "darken" THEN mode := BlendModeDarken
	ELSIF value^ = "lighten" THEN mode := BlendModeLighten
	ELSE
		SVG.Error("mode attribute feBlend must be 'normal', 'multiply', 'screen', 'darken'  or 'lighten'");
		mode := BlendModeNormal
	END
END ParseBlendMode;

(* Parse some type attribute of some feColorMatrix element *)
PROCEDURE ParseColorMatrixType*(value: XML.String; VAR type: SIGNED8);
BEGIN
	IF value^ = "matrix" THEN type := ColorMatrixTypeMatrix
	ELSIF value^ = "saturate" THEN type := ColorMatrixTypeSaturate
	ELSIF value^ = "hueRotate" THEN type := ColorMatrixTypeHueRotate
	ELSIF value^ = "luminanceToAlpha" THEN type := ColorMatrixTypeLuminanceToAlpha
	ELSE
		SVG.Error("type attribute feColorMatrix must be 'matrix', 'saturate', 'hueRotate' or 'luminanceToAlpha'");
		type := ColorMatrixTypeMatrix
	END
END ParseColorMatrixType;

(* Parse some values attribute of some feColorMatrix element *)
PROCEDURE ParseColorMatrixValues*(values: XML.String; type: SIGNED8; VAR matrix: ColorMatrix):BOOLEAN;
VAR pos: SIZE; i,j: SIZE;
	angle, s,c: FLOAT64;
BEGIN
	(* Init to the zero matrix *)
	FOR i := 0 TO 4 DO
	FOR j := 0 TO 3 DO
		matrix.a[i,j] := 0;
	END; END;

	IF type=ColorMatrixTypeLuminanceToAlpha THEN
		(* In this case the 'values' attribute is not applicable as the matrix is predefined: *)
		matrix.a[0,3] := 0.2125;
		matrix.a[1,3] := 0.7154;
		matrix.a[2,3] := 0.0721;
		RETURN TRUE
	END;

	(* Otherwise the default is the identity matrix *)
	matrix.a[0,0] := 1;
	matrix.a[1,1] := 1;
	matrix.a[2,2] := 1;
	matrix.a[3,3] := 1;
	IF values=NIL THEN RETURN TRUE END;

	pos :=0;
	CASE type OF
	| ColorMatrixTypeMatrix:
		FOR j := 0 TO 3 DO
		FOR i := 0 TO 4 DO
			SVGUtilities.SkipCommaWhiteSpace(pos, values);
			SVGUtilities.StrToFloatPos(values^, matrix.a[i,j], pos);
		END;END;
		RETURN TRUE
	| ColorMatrixTypeSaturate:
		SVGUtilities.SkipCommaWhiteSpace(pos, values);
		SVGUtilities.StrToFloatPos(values^, s, pos);
		matrix.a[0,0] := 0.213+0.787*s; matrix.a[1,0] := 0.715-0.715*s; matrix.a[2,0] := 0.072-0.072*s;
		matrix.a[0,1] := 0.213-0.213*s; matrix.a[1,1] := 0.715+0.285*s; matrix.a[2,1] := 0.072-0.072*s;
		matrix.a[0,2] := 0.213-0.213*s; matrix.a[1,2] := 0.715-0.715*s; matrix.a[2,2] := 0.072+0.928*s;
		RETURN TRUE
	| ColorMatrixTypeHueRotate:
		SVGUtilities.SkipCommaWhiteSpace(pos, values);
		SVGUtilities.StrToFloatPos(values^, angle, pos);
		s := Math.sin(-SHORT(angle)/180.0*Math.pi);
		c := Math.cos(-SHORT(angle)/180.0*Math.pi);
		matrix.a[0,0] := 0.213+0.787*c-0.213*s; matrix.a[1,0] := 0.715-0.715*c-0.715*s; matrix.a[2,0] := 0.072-0.072*c+0.928*s;
		matrix.a[0,1] := 0.213-0.213*c+0.143*s; matrix.a[1,1] := 0.715+0.285*c+0.140*s; matrix.a[2,1] := 0.072-0.072*c-0.283*s;
		matrix.a[0,2] := 0.213-0.213*c-0.787*s; matrix.a[1,2] := 0.715-0.715*c+0.715*s; matrix.a[2,2] := 0.072+0.928*c+0.072*s;
		RETURN TRUE
	END;
	RETURN FALSE
END ParseColorMatrixValues;

(* Transform a pixel by a matrix *)
PROCEDURE TransformByColorMatrix(VAR pix: Raster.Pixel; VAR matrix: ColorMatrix);
VAR p, result: ARRAY 4 OF FLOAT64;
BEGIN
	p[0] := ORD(pix[0])/255.0;
	p[1] := ORD(pix[1])/255.0;
	p[2] := ORD(pix[2])/255.0;
	p[3] := ORD(pix[3])/255.0;
	result[0] := matrix.a[0,0]*p[0] + matrix.a[1,0]*p[1] + matrix.a[2,0]*p[2] + matrix.a[3,0]*p[3] + matrix.a[4,0];
	result[1] := matrix.a[0,1]*p[0] + matrix.a[1,1]*p[1] + matrix.a[2,1]*p[2] + matrix.a[3,1]*p[3] + matrix.a[4,1];
	result[2] := matrix.a[0,2]*p[0] + matrix.a[1,2]*p[1] + matrix.a[2,2]*p[2] + matrix.a[3,2]*p[3] + matrix.a[4,2];
	result[3] := matrix.a[0,3]*p[0] + matrix.a[1,3]*p[1] + matrix.a[2,3]*p[2] + matrix.a[3,3]*p[3] + matrix.a[4,3];
	pix[0] := Raster.Clamp[200H+ENTIER(result[0]*255)];
	pix[1] := Raster.Clamp[200H+ENTIER(result[1]*255)];
	pix[2] := Raster.Clamp[200H+ENTIER(result[2]*255)];
	pix[3] := Raster.Clamp[200H+ENTIER(result[3]*255)];
END TransformByColorMatrix;

END SVGFilters.
