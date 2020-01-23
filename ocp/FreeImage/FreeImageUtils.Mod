MODULE FreeImageUtils; (** AUTHOR "fnecati"; PURPOSE "utilities for FreeImage"; *)

IMPORT FI:=FreeImageDll, Raster, KernelLog, SYSTEM;

(** pixel access functions  *)
PROCEDURE GetPixel32* (dib: FI.FIBITMAP; x, y: SIGNED32; VAR pix: Raster.Pixel);
VAR color: FI.RGBQUAD;
BEGIN
	FI.GetPixelColor(dib, x, y, color);
	pix[2] := color.rgbRed;
	pix[1] := color.rgbGreen;
	pix[0] := color.rgbBlue;
	pix[3] := color.rgbReserved
END GetPixel32;

PROCEDURE PutPixel32* (dib: FI.FIBITMAP; x, y: SIGNED32; pix: Raster.Pixel);
VAR color: FI.RGBQUAD;
BEGIN
	color.rgbRed := pix[2];
	color.rgbGreen := pix[1];
	color.rgbBlue := pix[0];
	color.rgbReserved := pix[3];
	FI.SetPixelColor(dib, x, y, color)
END PutPixel32;

PROCEDURE GetPixel24* (dib: FI.FIBITMAP; x, y: SIGNED32; VAR pix: Raster.Pixel);
VAR color: FI.RGBQUAD;
BEGIN
	FI.GetPixelColor(dib, x, y, color);
	pix[2] := color.rgbRed;
	pix[1] :=color.rgbGreen;
	pix[0] := color.rgbBlue;
	pix[3] := 0FFX;
END GetPixel24;

PROCEDURE PutPixel24* (dib: FI.FIBITMAP; x, y: SIGNED32; pix: Raster.Pixel);
VAR color: FI.RGBQUAD;
BEGIN
	color.rgbRed := pix[2];
	color.rgbGreen := pix[1];
	color.rgbBlue := pix[0];
	FI.SetPixelColor(dib, x, y, color)
END PutPixel24;

(** store Raster.Image using FreeImage *)	
PROCEDURE StoreImage*(img: Raster.Image; CONST filename: ARRAY OF CHAR; VAR res: SIGNED32);
VAR dib: FI.FIBITMAP;
	bpp: SIGNED32;
	w, h, i, j: SIGNED32;
	pix: Raster.Pixel;
	mode: Raster.Mode;	
BEGIN

	IF (img # NIL) & (img.width # 0) & (img.height # 0) THEN
	(*	KernelLog.String("img.fmt.bpp= "); KernelLog.Int(img.fmt.bpp, 0); KernelLog.Ln; *)
		w := img.width(SIGNED32); h := img.height(SIGNED32);
		dib := FI.Allocate(w, h, 24, 0, 0, 0);
	
		IF dib # NIL THEN
			bpp := FI.GetBPP(dib);
	
			Raster.InitMode(mode,  Raster.srcCopy);
	
			FOR j:=0 TO h-1 DO
				FOR i :=0 TO w-1 DO
					Raster.Get(img, i, j, pix, mode);
					PutPixel24(dib, i, h-j-1, pix);			
				END;
			END;	

			IF FI.SaveImage(dib, filename, 0) THEN
				KernelLog.String(filename); KernelLog.String(" is saved"); KernelLog.Ln;
			END;
			FI.Unload(dib);
		END;	
	END;
				
END StoreImage;

(** store 32 bit Raster.Image using FreeImage *)	
PROCEDURE StoreImage2*(img: Raster.Image; CONST filename: ARRAY OF CHAR);
VAR dib: FI.FIBITMAP;
	bits: ADDRESS;
	w, h: SIGNED32;
	res1: BOOLEAN;
BEGIN

	IF (img # NIL) & (img.width # 0) & (img.height # 0) THEN
	(*	KernelLog.String("img.fmt.bpp= "); KernelLog.Int(img.fmt.bpp, 0); KernelLog.Ln; *)
		w := img.width(SIGNED32); h := img.height(SIGNED32);
		dib := FI.Allocate(w, h, 32, 0, 0, 0);
	
		IF dib # NIL THEN
			bits := FI.GetBits(dib);
			SYSTEM.MOVE(img.adr, bits, w*h*4);
			res1 := FI.FlipVertical(dib);
			IF FI.SaveImage(dib, filename, 0) THEN
				KernelLog.String(filename); KernelLog.String(" is saved"); KernelLog.Ln;
			END;
			FI.Unload(dib);
		END;	
	END;
				
END StoreImage2;

(** Load an FreeImage FIBITMAP image and convert to BGRA8888 format Raster.Image *)
PROCEDURE LoadImage*(CONST filename: ARRAY OF CHAR): Raster.Image;
VAR img: Raster.Image;
	dib, tdib: FI.FIBITMAP;
	bpp: SIGNED32;
	res: BOOLEAN;
	w, h: SIGNED32;
	bits: ADDRESS;
BEGIN
	dib := FI.LoadImage(filename, 0);
	IF dib # NIL THEN
	
		IF FI.GetBPP(dib) # 32 THEN 
			tdib := FI.ConvertTo32Bits(dib); 
			FI.Unload(dib);
			dib := tdib
		END;	
		res := FI.FlipVertical(dib);
	
		w := FI.GetWidth(dib); h := FI.GetHeight(dib);
		bpp := FI.GetBPP(dib);

		NEW(img);
		Raster.Create(img, w, h, Raster.BGRA8888); (* 32 bpp *)
	
		bits := FI.GetBits(dib);
	
		SYSTEM.MOVE(bits, img.adr, w*h*(bpp DIV 8));
		FI.Unload(dib);
	END;	
	RETURN img;
END LoadImage;

BEGIN
END FreeImageUtils.
