MODULE TestYUV; (** AUTHOR ""; PURPOSE ""; *)

IMPORT WMGraphics, RF:=RasterPixelFormats, MatrixRaster, WMArrayPanel, WMStandardComponents, Raster, Strings, WMWindowManager, WMComponents;
	
PROCEDURE {TEST}Do*;
VAR rgb, yuv422: WMGraphics.Image; mode:Raster.Mode; img: WMStandardComponents.Image;win:WMComponents.FormWindow;
BEGIN
	rgb:=WMGraphics.LoadImage("Yellow_Duck.jpg",FALSE);
	NEW(img); img.SetImage(NIL,rgb);
	NEW(win, rgb.width, rgb.height, FALSE);  
	win.SetTitle(Strings.NewString("Yellow_Duck.jpg in BGRA format"));
	win.SetContent(img); 
	WMWindowManager.DefaultAddWindow(win);

	NEW(yuv422); 
	Raster.Create(yuv422, rgb.width, rgb.height, RF.YUV422);
	
	Raster.InitMode(mode, WMGraphics.ModeSrcOverDst);
	Raster.Copy(rgb,yuv422, 0,0,rgb.width, rgb.height,0,0, mode); (*implicit format change from source to destination, using Raster.Mod intrinsic functionality*)
	
	NEW(img); img.SetImage(NIL,yuv422);
	NEW(win, yuv422.width, yuv422.height, FALSE);  
	win.SetTitle(Strings.NewString("yellow duck in YUV422 format"));
	win.SetContent(img); 
	WMWindowManager.DefaultAddWindow(win);
	
	WMArrayPanel.AddWindow(MatrixRaster.ImagePlaneToArray(yuv422,0),"Y");
	WMArrayPanel.AddWindow(MatrixRaster.ImagePlaneToArray(yuv422,1),"U");
	WMArrayPanel.AddWindow(MatrixRaster.ImagePlaneToArray(yuv422,2),"V");
END Do;


END TestYUV.

Yellow_Duck.jpg
