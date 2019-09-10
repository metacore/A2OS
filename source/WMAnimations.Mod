MODULE WMAnimations; (** AUTHOR "staubesv"; PURPOSE "Visual components for animations"; *)

IMPORT
	Streams, Kernel, KernelLog, Strings, Files, Codecs, Raster, WMRectangles, WMGraphics, XML, WMProperties, WMComponents;

CONST
	Ok = 0;
	NoDecoderFound = 1;
	FileNotFound = 2;
	Error = 3;

	State_Waiting = 0;
	State_Rendering = 1;
	State_Terminating = 99;
	State_Terminated = 100;

TYPE

	Animation* = OBJECT(WMComponents.VisualComponent)
	VAR
		imageName- : WMProperties.StringProperty;
		isRepeating- : WMProperties.BooleanProperty;
		scaleImage- : WMProperties.BooleanProperty;
		forceNoBg- : WMProperties.BooleanProperty;

		(* the field below are protected by the hierarchy lock *)
		sequence : Codecs.ImageSequence;
		first, current : Codecs.ImageDescriptor;
		image : Raster.Image;
		aux_canvas : WMGraphics.BufferCanvas;

		state : SIGNED32;
		timer : Kernel.Timer;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrAnimation);
			NEW(imageName, PrototypeImageName, NIL, NIL); properties.Add(imageName);
			NEW(isRepeating, PrototypeIsRepeating, NIL, NIL); properties.Add(isRepeating);
			NEW(scaleImage, PrototypeScaleImage, NIL, NIL); properties.Add(scaleImage);
			NEW(forceNoBg, PrototypeForceNoBg, NIL, NIL); properties.Add(forceNoBg);
			first := NIL; current := NIL;
			image := NIL; aux_canvas := NIL;
			state := State_Waiting;
			NEW(timer);
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			Initialize^;
			Acquire; LoadImages; Release; Invalidate;
		END Initialize;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF (property = imageName) THEN
				LoadImages; Invalidate;
			ELSIF (property = isRepeating) & isRepeating.Get() THEN
				IF (current # NIL) & ((current.previous # NIL) OR (current.next # NIL)) THEN SetState(State_Rendering); END;
			ELSIF (property = scaleImage) OR (property = forceNoBg) THEN
				Invalidate;
			ELSE
				PropertyChanged^(sender, property)
			END
		END PropertyChanged;

		PROCEDURE LoadImages;
		VAR name : Strings.String; res : INTEGER;
		BEGIN
			first := NIL; current := NIL; image := NIL;
			name := imageName.Get();
			IF (name # NIL) THEN
				OpenAnimation(name^, sequence, res); current := first;
				IF (res = Ok) THEN
					first := sequence.images; current := first;
					IF (image = NIL) OR (image.width # sequence.width) OR (image.height # sequence.height) THEN
						NEW(image);
						Raster.Create(image, sequence.width, sequence.height, Raster.BGRA8888);
						NEW(aux_canvas, image);
					END;
					aux_canvas.Fill(WMRectangles.MakeRect(0, 0, image.width, image.height), 0, WMGraphics.ModeCopy);
				ELSE
					current := NIL; image := NIL; aux_canvas := NIL;
				END;
			END;
			IF (current # NIL) THEN
				SetState(State_Rendering);
			ELSE
				SetState(State_Waiting);
			END;
			timer.Wakeup;
		END LoadImages;

		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		VAR  name : Strings.String;
		BEGIN
			DrawBackground^(canvas);
			IF (image # NIL) THEN
				IF ~scaleImage.Get() OR (image.width = bounds.GetWidth()) & (image.height = bounds.GetHeight()) THEN
					canvas.DrawImage(0, 0, image, WMGraphics.ModeSrcOverDst);
				ELSE
					canvas.ScaleImage(image, WMRectangles.MakeRect(0, 0, image.width, image.height), GetClientRect(), WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
				END;
			ELSE
				name := imageName.Get();
				IF (name # NIL) THEN
					canvas.SetColor(WMGraphics.Red);
					WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, name^);
				END;
			END
		END DrawBackground;

		PROCEDURE SetState(state : SIGNED32);
		BEGIN {EXCLUSIVE}
			IF (SELF.state < State_Terminating) OR (state = State_Terminated) THEN
				SELF.state := state;
			END;
		END SetState;

		PROCEDURE Finalize*;
		BEGIN
			Finalize^;
			SetState(State_Terminated);
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(state = State_Terminated); END;
		END Finalize;

		PROCEDURE Update;
		VAR imageDesc, p : Codecs.ImageDescriptor; delayTime : SIGNED32;
		BEGIN
			Acquire;
			IF (image = NIL) THEN Release; RETURN; END;
			imageDesc := current;
			IF (imageDesc # NIL) THEN
				IF (imageDesc.previous # NIL) THEN
					p := imageDesc.previous;
					IF (p.disposeMode = Codecs.RestoreToBackground) THEN
						IF forceNoBg.Get() THEN
							aux_canvas.Fill(WMRectangles.MakeRect(p.left, p.top, p.left + p.width, p.top + p.height), 0, WMGraphics.ModeCopy);
						ELSE
							aux_canvas.Fill(WMRectangles.MakeRect(p.left, p.top, p.left + p.width, p.top + p.height), sequence.bgColor, WMGraphics.ModeCopy);
						END;
					ELSIF (p.disposeMode = Codecs.RestoreToPrevious) THEN

					END;
				ELSE
					aux_canvas.Fill(WMRectangles.MakeRect(0, 0, sequence.width, sequence.height), 0, WMGraphics.ModeCopy);
				END;
				aux_canvas.DrawImage(imageDesc.left, imageDesc.top, imageDesc.image, WMGraphics.ModeSrcOverDst);
				IF (imageDesc.next # NIL) THEN
					current := imageDesc.next;
				ELSIF isRepeating.Get() & (first.next # NIL) THEN
					current := first;
				ELSE
					SetState(State_Waiting);
					Release;
					Invalidate;
					RETURN;
				END;
			END;
			IF (current # NIL) THEN
			(*	KernelLog.String(" delay : ");
				KernelLog.Int(current.delayTime, 0);
				KernelLog.String(", dispose: "); KernelLog.Int(current.disposeMode, 0);
				KernelLog.Ln; *)
				IF (current.delayTime > 0) THEN
					delayTime := current.delayTime;
				ELSE
					delayTime := 20; (* make sure that activity does not busy loop, assume max. 50 fps *)
				END;
			ELSE
				delayTime := 0;
			END;
			Release;
			Invalidate;
			IF (delayTime > 0) THEN timer.Sleep(delayTime); END;
		END Update;

	BEGIN {ACTIVE}
		WHILE (state < State_Terminating) DO
			BEGIN {EXCLUSIVE} AWAIT(state # State_Waiting); END;
			Update;
		END;
		SetState(State_Terminated);
	END Animation;

VAR
	PrototypeImageName : WMProperties.StringProperty;
	PrototypeIsRepeating, PrototypeScaleImage, PrototypeForceNoBg: WMProperties.BooleanProperty;

	StrAnimation : Strings.String;

PROCEDURE OpenAnimation(filename : ARRAY OF CHAR; VAR sequence : Codecs.ImageSequence; VAR res : INTEGER);
VAR
	name, extension : Files.FileName; reader : Streams.Reader;
	animationDecoder : Codecs.AnimationDecoder; imageDecoder : Codecs.ImageDecoder;
	imageDescriptor : Codecs.ImageDescriptor;
BEGIN
	Strings.Trim(filename, '"');
	Files.SplitExtension(filename, name, extension);
	Strings.UpperCase(extension);
	animationDecoder := Codecs.GetAnimationDecoder(extension);
	IF (animationDecoder # NIL) THEN
		reader := Codecs.OpenInputStream(filename);
		IF (reader # NIL) THEN
			animationDecoder.Open(reader, res);
			IF (res = Codecs.ResOk) THEN
				animationDecoder.GetImageSequence(sequence, res);
			END;
		ELSE
			res := FileNotFound;
		END;
	ELSE
		imageDecoder := Codecs.GetImageDecoder(extension);
		IF (imageDecoder # NIL) THEN
			reader := Codecs.OpenInputStream(filename);
			IF (reader # NIL) THEN
				imageDecoder.Open(reader, res);
				IF (res = Codecs.ResOk) THEN
					(* fake single frame image sequence *)
					NEW(imageDescriptor);
					imageDecoder.GetNativeImage(imageDescriptor.image);
					IF (imageDescriptor.image # NIL) THEN
						imageDescriptor.width := imageDescriptor.image.width;
						imageDescriptor.height := imageDescriptor.image.height;
						sequence.width := imageDescriptor.width;
						sequence.height := imageDescriptor.height;
						sequence.bgColor := 0;
						sequence.images := imageDescriptor;
						res := Ok;
					ELSE
						sequence.images := NIL;
						res := Error;
					END;
				END;
			ELSE
				res := FileNotFound;
			END;
		ELSE
			res := NoDecoderFound;
		END;
	END;
END OpenAnimation;

PROCEDURE GenAnimation*() : XML.Element;
VAR a : Animation;
BEGIN
	NEW(a); RETURN a;
END GenAnimation;

PROCEDURE FindAnimation*(CONST uid : ARRAY OF CHAR; component : WMComponents.Component) : Animation;
VAR c : WMComponents.Component;
BEGIN
	ASSERT(component # NIL);
	c := component.FindByUID(uid);
	IF (c # NIL) & (c IS Animation) THEN
		RETURN c (Animation);
	ELSE
		RETURN NIL;
	END;
END FindAnimation;

PROCEDURE InitPrototypes;
BEGIN
	NEW(PrototypeImageName, NIL, Strings.NewString("ImageName"), Strings.NewString("Filename of GIF image"));
	PrototypeImageName.Set(NIL);
	NEW(PrototypeIsRepeating, NIL, Strings.NewString("IsRepeating"), Strings.NewString("Restart animation when finished?"));
	PrototypeIsRepeating.Set(TRUE);
	NEW(PrototypeScaleImage, NIL, Strings.NewString("ScaleImage"), Strings.NewString("Scale images to component bounds?"));
	PrototypeScaleImage.Set(TRUE);
	NEW(PrototypeForceNoBg, NIL, Strings.NewString("ForceNoBg"), Strings.NewString("Force background color to be transparent"));
	PrototypeForceNoBg.Set(FALSE);
END InitPrototypes;

PROCEDURE InitStrings;
BEGIN
	StrAnimation := Strings.NewString("Animation");
END InitStrings;

BEGIN
	InitStrings;
	InitPrototypes;
END WMAnimations.
