MODULE TestDataImage; (** AUTHOR "Patrick Hunziker 2019"; PURPOSE "Example of loading using path/name mask, constructing tensors & displaying them"; *)

IMPORT Commands, Files, Streams, Strings, MatrixRaster, WMGraphics, WMTensor, WMComponents, WMMenus, WMTrees, WMStandardComponents, WMWindowManager, Rand:=Random;

CONST Random=0;
CONST NSamples=32;

VAR rand:Rand.Generator;

TYPE Procedure=PROCEDURE{DELEGATE};

TYPE StringObject=OBJECT
			VAR s:Strings.String;
		END StringObject;

TYPE	ContextMenu* = OBJECT
	VAR x,y: SIGNED32;
		w:Streams.Writer;
		name: Files.FileName;
		menu: WMTrees.Tree;
		handleItemSelected*: PROCEDURE {DELEGATE} (sender, data : ANY);

	PROCEDURE &Init*(w:Streams.Writer);
	BEGIN
		SELF.w:=w;
		NEW(menu);
		handleItemSelected:=DefaultHandleItemSelected;
	END Init;

	PROCEDURE AddItem*(CONST popupLabel: ARRAY OF CHAR; item: ANY);
	VAR node: WMTrees.TreeNode;
	BEGIN
		node := WMMenus.AddItemNode(popupLabel, menu);
		menu.Acquire;
		menu.SetNodeData(node, item);
		menu.Release;
	END AddItem;

	PROCEDURE Handle* (sender : ANY; x, y: SIGNED32);
	VAR gx,gy: SIGNED32;
	BEGIN
		SELF.x:=x; SELF.y:=y;
		sender(WMComponents.VisualComponent).ToWMCoordinates(x,y,gx,gy);
		WMMenus.Show(menu, gx, gy, handleItemSelected);
	END Handle;

	PROCEDURE DefaultHandleItemSelected*(sender, data : ANY);
	BEGIN
		IF (data # NIL) & (data IS StringObject) THEN
			w.Char('"'); w.String(name); w.String('" ');
			w.String(data(StringObject).s^); w.Int(x,0); w.Char(" "); w.Int(y,0); w.Ln; w.Update;
		END;
	END DefaultHandleItemSelected;

	END ContextMenu;

PROCEDURE GetStringObject(CONST str: ARRAY OF CHAR): ANY;
	VAR string:StringObject;
	BEGIN
		NEW(string);
		string.s:=Strings.NewString(str);
		RETURN string;
	END GetStringObject;

PROCEDURE Test*(context:Commands.Context);
VAR
	dataSetI, labelSetI: ARRAY [?] OF SIGNED16;
	nSamples: SIGNED32(*SIZE*);
	i: SIGNED32;
	time, date, size: SIGNED32;
	enum:MatrixRaster.Enumerator;
	flags: SET;
	name:Files.FileName;
	img: WMGraphics.Image;
	imgPanel: WMStandardComponents.ImagePanel;
	stackWindow: WMTensor.Window;
	window: WMComponents.FormWindow;
	contextMenu:ContextMenu;
	procedure:PROCEDURE;

BEGIN
	nSamples:=NSamples;
	NEW(contextMenu, context.out);
	contextMenu.AddItem("eye", GetStringObject("Eye "));
	contextMenu.AddItem("nose", GetStringObject("Nose "));
	contextMenu.AddItem("next Image", NIL);

	(** explore a directory path for file names fitting to a mask*)
	NEW(enum);
	enum.Open("*.jpg", flags); (* limit files examined by mask*)
	WHILE enum.HasMoreEntries() & enum.GetEntry(name, flags, time, date, size) DO
		context.out.String(name); context.out.Ln; context.out.Update;
	END;

	enum.Open("Y*.jpg", flags); (* limit extracted images by file name mask*)
	(*can skip some images without loading*)
	(*	FOR i:=0 TO 5 DO res:=enum.GetEntry(name, flags, time, date, size) END; *)

	img:=enum.GetImage(name, flags, time, date, size);

	(** showing an image as a WMComponents.VisualComponent / WMStandardComponents.ImagePanel *)
	NEW(imgPanel);
	imgPanel.SetExtContextMenuHandler(contextMenu.Handle);
	COPY(name, contextMenu.name);
	imgPanel.imgName.SetAOC(name);

	(*imgPanel.SetImage(NIL, img);*) (*could also set image directly, anonymously*)
	NEW(window, MIN(img.height,600), MIN(img.width, 600), FALSE);
	window.SetContent(imgPanel);
	WMWindowManager.AddWindow(window, 600, 200);

	(** extract a RGB stack from one ROI in one image. position in image can be predefined or random *)
	NEW(stackWindow, enum.GetRoiBGR(img, Random, Random), "[3D]scroll mouse/arrows", WMTensor.Frontal);
	stackWindow.AddWindow();

	(** extract a stack consisting of multiple randomly sampled ROIs from one image *)
	dataSetI:=enum.GetRoiStackRandom(img, nSamples, 3);
	(*produce a label data structure*)
	NEW(labelSetI, nSamples, 1, 1);
	FOR i:=0 TO LEN(labelSetI,0)-1 DO
		labelSetI[i,?]:= SHORT(rand.Dice(2));
	END;

	(** produce a scrollable window displaying 2D,3D,4D datasets *)
	NEW(stackWindow, dataSetI, "[4D]scroll mouse/arrows", WMTensor.Frontal);
	stackWindow.AddWindow();

END Test;

BEGIN
	NEW(rand);
END TestDataImage.

TestDataImage.Test ~

System.FreeDownTo MatrixRaster ~

