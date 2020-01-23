MODULE ImageLabeler; (** AUTHOR "Patrick Hunziker 2019"; PURPOSE "Interactively loading files, defining labels, storing them as file"; *)

IMPORT Commands, Files, Streams, Strings, Options, Raster, Rand:=Random, MatrixRaster,
			WMGraphics, WMRasterScale, WMRectangles, WMTensor, WMComponents, WMMenus, WMTrees, WMStandardComponents, WMWindowManager,
			MLDataStreams, MediaPlayer;

CONST Random=MatrixRaster.Random;
		 Tab=09X;

VAR 	rand:Rand.Generator;
		globalContextMenu*:ContextMenu;
		source:MLDataStreams.Source;
		log:Streams.Writer;
		player: MediaPlayer.Player;

TYPE StringObject=OBJECT
			VAR
				s:Strings.String;
				id:SIZE;
		END StringObject;

TYPE Command=OBJECT
			VAR s:Strings.String;
		END Command;

TYPE Location=POINTER TO RECORD
		x,y, w,h: SIZE;
		id:SIZE;
		s:Strings.String;
		next:Location;
	END;

TYPE	ContextMenu* = OBJECT
	VAR x,y, nItems: SIZE;
		w:Streams.Writer;
		name: Files.FileName;
		menu: WMTrees.Tree;
		nextImage, stop: PROCEDURE{DELEGATE}();
		locations:Location; (*list of locations, is per image*)

	PROCEDURE &Init*(w:Streams.Writer);
	BEGIN
		SELF.w:=w;
		NEW(menu);
		nItems:=0;
	END Init;

	PROCEDURE AddItem*(CONST popupLabel: ARRAY OF CHAR; item: ANY);
	VAR node: WMTrees.TreeNode;
	BEGIN
		node := WMMenus.AddItemNode(popupLabel, menu);
		IF (item#NIL) & (item IS StringObject) THEN item(StringObject).id:=nItems; INC(nItems) END;
		menu.Acquire;
		menu.SetNodeData(node, item);
		menu.Release;
	END AddItem;

	PROCEDURE ResetLocations;
	BEGIN
		locations:=NIL;
	END ResetLocations;

	PROCEDURE Handle* (sender : ANY; x, y: SIZE);
	VAR gx,gy: SIZE;
	BEGIN
		SELF.x:=x; SELF.y:=y;
		sender(WMComponents.VisualComponent).ToWMCoordinates(x,y,gx,gy);
		WMMenus.Show(menu, gx, gy, HandleItemSelected);
	END Handle;

	PROCEDURE PointerDownHandler* (x, y: SIZE; keys:SET);
	VAR gx,gy: SIZE;
	BEGIN
		SELF.x:=x; SELF.y:=y;
		WMMenus.Show(menu, x, y, HandleItemSelected);
	END PointerDownHandler;


	PROCEDURE HandleItemSelected*(sender, data : ANY);
	VAR l:Location;
	BEGIN
		IF data # NIL THEN
			IF data IS StringObject THEN
				NEW(l); l.s:=data(StringObject).s; l.x:=x; l.y:=y; l.id:=data(StringObject).id; l.next:=locations; locations:=l;
				w.String(l.s^); w.Char(Tab); w.Int(l.id,0); w.Char(Tab); w.Int(l.x,0); w.Char(Tab); w.Int(l.y,0);
				w.Ln; w.Update;
			ELSIF data IS Command THEN
				IF data(Command).s^ = "Stop" THEN stop();
				ELSIF data(Command).s^ = "NextImage" THEN	nextImage();
				END;
			END;
		END;
	END HandleItemSelected;

	END ContextMenu;

PROCEDURE Distance2(dx,dy: SIZE):SIZE; (*squared distance*)
BEGIN
	RETURN dx*dx+dy*dy
END Distance2;

PROCEDURE NewStringObject(CONST str: ARRAY OF CHAR): ANY;
	VAR string:StringObject;
	BEGIN
		NEW(string);
		string.s:=Strings.NewString(str);
		RETURN string;
	END NewStringObject;

PROCEDURE NewCommand(CONST str: ARRAY OF CHAR): ANY;
	VAR command:Command;
	BEGIN
		NEW(command);
		command.s:=Strings.NewString(str);
		RETURN command;
	END NewCommand;

TYPE Labeler*=OBJECT
	CONST ScaledSize=512;
			RoiSize=128;
			NSamples=64;
			threshold3=100;
	VAR
		dataSetI, labelSetI: ARRAY [?] OF SIGNED16;
		positions: ARRAY [*,*] OF SIZE;
		nSamples: SIZE;
		i,j,k, x,y: SIZE;
		time, date: SIGNED32; 
		size: Files.Size;
		enum:MatrixRaster.Enumerator;
		flags: SET;
		name, mask:Files.FileName;
		dataWriter:Streams.Writer;
		img: WMGraphics.Image;
		imgPanel: WMStandardComponents.ImagePanel;
		(*imgPanel: WMStandardComponents.Image;*)
		stackWindow, oldStackWindow, labelWindow: WMTensor.Window;
		window: WMComponents.FormWindow;
		contextMenu:ContextMenu;
		w:Streams.Writer;
		dead, hasNewImage, hit, scaling, success:BOOLEAN;
		minWidth,minHeight:SIZE;
		l:Location;
		dx,dy: SIZE;
		threshold2:SIGNED32; (*squared threshold*)
		scale:FLOAT64;

	PROCEDURE &Init*(CONST mask: ARRAY OF CHAR; w, dataWriter: Streams.Writer; scaling:BOOLEAN);
	VAR debugNSamples:SIZE;
	BEGIN
		SELF.w:=w;
		SELF.dataWriter:=dataWriter;
		SELF.scaling:=scaling;
		COPY(mask,SELF.mask);
		minWidth:=RoiSize; minHeight:=RoiSize;
		nSamples:=NSamples;
		dead:=FALSE;
		success:=TRUE;

		contextMenu:=globalContextMenu;
		contextMenu.w:=w;
		contextMenu.nextImage:=NextImage;
		contextMenu.stop:=Finish;

		NEW(enum); enum.SetRoiSize(RoiSize,RoiSize,1); enum.Open(mask, flags); (* can limit extracted images by file name mask*)
		(*	FOR i:=0 TO 5 DO res:=enum.GetEntry(name, flags, time, date, size) END; *)(*can skip some images without loading*)
		threshold2:=(RoiSize DIV 4)*(RoiSize DIV 4);

		debugNSamples:=nSamples;
		NEW(positions,nSamples,2);
		positions[*,*]:=Random;
		scale:=1.0;

		NEW(source); 
		source.datatype:=MLDataStreams.Integer;
		source.InitWrite(dataWriter);
	END Init;

	PROCEDURE NextImage*();
	VAR originalImg:WMGraphics.Image; bounds, bounds1: WMRectangles.Rectangle;

	BEGIN
		originalImg:=enum.GetImage(name, flags, time, date, size);
		BEGIN {EXCLUSIVE} hasNewImage:=(originalImg#NIL) & (originalImg.width>=minWidth) & (originalImg.height>=minHeight); dead:=~hasNewImage  END;
		IF hasNewImage THEN
			IF scaling THEN
				scale:=ScaledSize/MAX(originalImg.width,originalImg.height);
				NEW(img); Raster.Create(img, ENTIER(scale*originalImg.width), ENTIER(scale*originalImg.height), Raster.BGRA8888);
				bounds.l:=0; bounds.t:=0; bounds.r:=originalImg.width; bounds.b:=originalImg.height;
				bounds1.l:=0; bounds1.t:=0; bounds1.r:=img.width; bounds1.b:=img.height;
				WMRasterScale.Scale(originalImg,bounds ,img, bounds1, bounds1, WMRasterScale.ModeCopy, WMRasterScale.ScaleBox);
			ELSE
				img:=originalImg;
			END;
			w.String("'"); w.String(name); w.String("'"); w.Char(Tab);
			w.Int(originalImg.width,0);w.Char(Tab); w.Int(originalImg.height,0);w.Char(Tab);
			w.Int(img.width,0);w.Char(Tab); w.Int(img.height,0); w.Ln; w.Update;
		END;
	END NextImage;

	PROCEDURE Finish*;
	BEGIN{EXCLUSIVE}
		dead:=TRUE
	END Finish;

BEGIN
	(** explore a directory path for file names fitting to a mask*)
	(* NEW(enum); enum.Open(mask, flags);
	WHILE enum.HasMoreEntries() & enum.GetEntry(name, flags, time, date, size) DO
		w.String(name); w.Ln; w.Update;
	END; *)

	NextImage();
	LOOP
		IF (window#NIL)&(window.GetManager()#NIL) THEN window.GetManager().Remove(window) END;
		IF (oldStackWindow#NIL)&(oldStackWindow.GetManager()#NIL) THEN oldStackWindow.GetManager().Remove(oldStackWindow) END;

		(** showing an image as a WMComponents.VisualComponent / WMStandardComponents.ImagePanel *)
		COPY(name, contextMenu.name);
		NEW(imgPanel);
		imgPanel.SetExtContextMenuHandler(contextMenu.Handle);
		(*imgPanel.imgName.SetAOC(name);*)(* named loading does not fit well to rescaling ..*)
		imgPanel.SetImage(NIL, img); (*can also set image directly, anonymously*)

		NEW(window, img.width, img.height, FALSE);
		window.SetContent(imgPanel);
		window.SetTitle(Strings.NewString(name));
		WMWindowManager.AddWindow(window, 600, 200);

		IF FALSE THEN (*random locations*)
			(** extract a stack consisting of multiple randomly sampled ROIs from one image *)
			positions[*,*]:=Random;
			(** produce a scrollable window displaying 2D,3D,4D datasets *)
			(*dataSetI:=enum.GetRoiStackRandom(img, nSamples, 3, positions);(*BGR, 4D data *)
			NEW(stackWindow, dataSetI, "[4D]scroll mouse/arrows", WMTensor.Frontal);*)
			dataSetI:=enum.GetRoiStackRandom(img, nSamples, 1, positions);(*Gray, 3D data*)
			oldStackWindow:=stackWindow;
			NEW(stackWindow, dataSetI, "[3D]scroll mouse/arrows", WMTensor.Frontal);
			stackWindow.AddWindow();

			hasNewImage:=FALSE;
			BEGIN{EXCLUSIVE} AWAIT(dead OR hasNewImage) END;
			IF dead THEN EXIT END;
			IF (labelWindow#NIL)&(labelWindow.GetManager()#NIL) THEN labelWindow.GetManager().Remove(labelWindow) END;

			(** example for producing a label data structure *)
			NEW(labelSetI, nSamples, 1, MAX(contextMenu.nItems, 10));(*! COMPILER PROBLEM - NEW does reuse but not reset content ?? *)
			labelSetI:=0;
			FOR i:=0 TO LEN(labelSetI,0)-1 DO
				l:=contextMenu.locations;
				hit:=FALSE;
				WHILE l#NIL DO
					dx:=l.x-positions[i,0]-RoiSize DIV 2;
					dy:=l.y-positions[i,1]-RoiSize DIV 2;
					(*log.Int(i,10); log.String(": "); log.Int(dx,10); log.Int(dy,10); log.String(" "); log.Ln;*)
					IF Distance2( dx, dy) < threshold2 THEN
						hit:=TRUE;
						labelSetI[i,0,l.id]:=1;
					END;
					l:=l.next;
				END;
				(*log.Update;*)
			END;
		ELSE (*a centered image for each label, rest is random*)
		
			NEW(dataSetI, nSamples, 1, RoiSize, RoiSize);
			dataSetI:=0; (*?*)
			NEW(labelSetI, nSamples, 1, MAX(contextMenu.nItems, 10));(*! COMPILER PROBLEM - NEW does reuse but not reset content ?? *)
			labelSetI:=0;
			j:=0;
			l:=contextMenu.locations;
			WHILE (l#NIL) & (j<nSamples) DO
				x:=l.x-RoiSize DIV 2;
				y:=l.y-RoiSize DIV 2;
				IF (x>=0) & (y>=0) & (x+RoiSize <= img.width) & (y+RoiSize <= img.height) THEN
					positions[j,0]:=x;
					positions[j,1]:=y;
					dataSetI[j,0,?]:= enum.GetRoiGray(img, positions[j,0],positions[j,1]);
					labelSetI[j,0,l.id]:=1;
					INC(j);
				END;
				l:=l.next;
			END;
			k:=0;
			WHILE (j < nSamples) & (k <10*nSamples) DO (* fill up but not endlessly *)
				x:=rand.Dice(SIGNED32(img.width)-RoiSize);
				y:=rand.Dice(SIGNED32(img.height)-RoiSize);
				hit:=FALSE;
				l:=contextMenu.locations;
				WHILE l#NIL DO
					hit:=hit OR (Distance2( l.x-x-RoiSize DIV 2, l.y-y- RoiSize DIV 2) < threshold3);
					l:=l.next;
				END;
				IF ~hit THEN (* only non-hits here *)
					positions[j,0]:=x;
					positions[j,1]:=y;
					dataSetI[j,0,?]:= enum.GetRoiGray(img, positions[j,0],positions[j,1]);
					labelSetI[j,0, LEN(labelSetI,2)-1]:=1;
					INC(j);
				END;
				INC(k);
			END;
		END;
		NEW(labelWindow, labelSetI, "labels", WMTensor.Frontal);
		labelWindow.AddWindow();

		success:= source.AddMinibatch(dataSetI,labelSetI);

		hasNewImage:=FALSE;
		BEGIN{EXCLUSIVE} AWAIT(dead OR hasNewImage) END;
		IF dead THEN EXIT END;
		IF (labelWindow#NIL)&(labelWindow.GetManager()#NIL) THEN labelWindow.GetManager().Remove(labelWindow) END;

		contextMenu.ResetLocations;
		scale:=1.0;

		IF ~success THEN EXIT END;
	END;
	(*
	IF dataWriter#NIL THEN
		source.Store(dataWriter);
		log.String("dataFile written "); log.Int(dataWriter.Pos(),0); log.Ln; log.Update;
	END;
	*)
	(*source.Report(log);*)
END Labeler;

TYPE MovieLabeler*= OBJECT
	VAR 
		msg : ARRAY 256 OF CHAR; 
		res : INTEGER;
		contextMenu:ContextMenu;
	PROCEDURE &Init*(filename: Files.FileName);
	BEGIN
		NEW(player);
		contextMenu:=globalContextMenu;
		contextMenu.nextImage:=player.Step;
		contextMenu.stop:=player.Stop;
		player.Open(filename, msg, res);
		IF res=Streams.Ok THEN 
			player.SetState(MediaPlayer.Stepping);
		END;
		player.pointerDownHandler:=contextMenu.PointerDownHandler;
	END Init;
	
	END MovieLabeler;


(*open a labeler object for labeling list of images, according to file name mask.
Can use the default or an interactively prepared label list contained in a popup menu.
optionally stores a list of fn,label,id,coord to result file *)
PROCEDURE Open*(context:Commands.Context);
VAR labeler: Labeler; 
	movieLabeler: MovieLabeler;
	options: Options.Options;
	f:Files.File; s,mask:Files.FileName; fw, dataFileWriter:Files.Writer; w:Streams.Writer;
BEGIN
	log:=context.out;
	NEW(options);
	options.Add("f","resultFile",Options.String);
	options.Add("d","dataFile",Options.String);
	options.Add("m","mask",Options.String);
	options.Add("t","threshold",Options.Integer); (* distance of image center from label that is still considered a hit *)
	options.Add("s","scaling",Options.Flag); (* scale image to manageable size *)
	options.Add("n","nSamples", Options.Integer); 
	options.Add("p","player", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		IF options.GetString("resultFile", s) THEN
			f:=Files.New(s); Files.Register(f); Files.OpenWriter(fw,f,0); w:=fw;
			context.out.String("writing result file: "); context.out.String(s); context.out.Ln; context.out.Update;
		ELSE w:=context.out
		END;
		IF ~options.GetString("dataFile", s) THEN COPY("Labeler.MtA", s) END;
		f:=Files.New(s); Files.Register(f); Files.OpenWriter(dataFileWriter,f,0);
		context.out.String("writing data file: "); context.out.String(s); context.out.Ln; context.out.Update;

		IF options.GetString("mask",mask) THEN
			context.out.String("file mask: "); context.out.String(mask); context.out.Ln; context.out.Update;
		ELSE mask:="*"
		END;
		IF options.GetFlag("player") THEN
			NEW(movieLabeler, mask);(*! TBD *)
		ELSE
			NEW(labeler,mask, w, dataFileWriter, options.GetFlag("scaling"));
		END;
		IF options.GetInteger("threshold",labeler.threshold2) THEN END; (*? labeler active object has already started, this may come late*)
	ELSE HALT(201);
	END;
END Open;

(*create context menu with label-name pairs for popup menu. <sourceFile, labelName, id, coordinates, Ln>  will be written to tab-separated text stream including their mouse click coordinates*)
PROCEDURE NewMenu*(context:Commands.Context);
VAR label,string:ARRAY 256 OF CHAR;
BEGIN
	NEW(globalContextMenu, context.out);
	WHILE context.arg.GetString(label) & context.arg.GetString(string) DO
		globalContextMenu.AddItem(label, NewStringObject(string));
	END;
	globalContextMenu.AddItem("------", NIL);
	globalContextMenu.AddItem("nextImage", NewCommand("NextImage"));
	globalContextMenu.AddItem("stop", NewCommand("Stop"));
	context.out.String("context menu read"); context.out.Ln; context.out.Update;
END NewMenu;

BEGIN
	NEW(rand);
	NEW(globalContextMenu, NIL);
		globalContextMenu.AddItem("0", NewStringObject("0"));
		globalContextMenu.AddItem("1", NewStringObject("1"));
		globalContextMenu.AddItem("2", NewStringObject("2"));
		globalContextMenu.AddItem("3", NewStringObject("3"));
		globalContextMenu.AddItem("----", NIL);
		globalContextMenu.AddItem("nextImage", NewCommand("NextImage"));
		globalContextMenu.AddItem("stop", NewCommand("Stop"));
END ImageLabeler.

(*create label-name pairs for popup menu. It is sometimes useful to have the first label=0=nothing. *)
ImageLabeler.NewMenu
	nothing Nothing
	mouth Mouth
	nose	Nose
	eye	Eye
	ear	Ear
	chin	Chin
 ~
ImageLabeler.NewMenu
	nothing Nothing
	head SpermHead
	tail	SpermTail
	background Background
	artifact	Artifact
 ~


ImageLabeler.Open -m="*.jpg" -f=Labeler1.txt ~
ImageLabeler.Open -m="C:/Program Files (x86)/A2/HighDim/Code/EyeTracker/EyeDB_Internet/*.jpg" -f=Eyes.txt -d=Eyes_3D.MtA --scaling ~
ImageLabeler.Open -p -m="HIGHDIM:/Data/Sperm/IMSI1.wmv" -f=Eyes.txt -d=Eyes_3D.MtA ~
ImageLabeler.Open -m="C:/Program Files (x86)/A2/HighDim/Data/Sperm/IMSI1_100Frames_BMP/*.bmp" -f=SpermIMSI1.txt -d=Sperm_3DIMSI1.MtA --scaling ~
ImageLabeler.Open -m="C:/Program Files (x86)/A2/HighDim/Data/Sperm/IMSI1_100Frames_BMP/*.bmp" -f=SpermIMSI1.txt -d=Sperm_3DIMSI1.MtA  ~
System.CollectGarbage ~
System.Free ImageLabeler ~
System.FreeDownTo MatrixBase~
System.FreeDownTo WMTensor~

