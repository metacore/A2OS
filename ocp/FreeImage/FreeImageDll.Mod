MODULE FreeImageDll; (** AUTHOR "fnecati"; PURPOSE "FreeImage Oberon interface for UNIX and WIN Platforms"; *)

IMPORT 
	Strings, Modules, KernelLog, HostLibs;

(* Date:  21-3-2015 
Wrapper for FreeImage.dll (v3.17.0).
	http://freeimage.sourceforge.net/

 Design and implementation by
 - Floris van den Berg (flvdberg@wxs.nl)
 - Hervé Drolon (drolon@infonie.fr)

 Contributors:
 - see changes log named 'Whatsnew.txt', see header of each .h and .cpp file

 This file is part of FreeImage 3

 COVERED CODE IS PROVIDED UNDER THIS LICENSE ON AN "AS IS" BASIS, WITHOUT WARRANTY
 OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, WITHOUT LIMITATION, WARRANTIES
 THAT THE COVERED CODE IS FREE OF DEFECTS, MERCHANTABLE, FIT FOR A PARTICULAR PURPOSE
 OR NON-INFRINGING. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE COVERED
 CODE IS WITH YOU. SHOULD ANY COVERED CODE PROVE DEFECTIVE IN ANY RESPECT, YOU (NOT
 THE INITIAL DEVELOPER OR ANY OTHER CONTRIBUTOR) ASSUME THE COST OF ANY NECESSARY
 SERVICING, REPAIR OR CORRECTION. THIS DISCLAIMER OF WARRANTY CONSTITUTES AN ESSENTIAL
 PART OF THIS LICENSE. NO USE OF ANY COVERED CODE IS AUTHORIZED HEREUNDER EXCEPT UNDER
 THIS DISCLAIMER.

 Use at your own risk!
 ==========================================================

*)

(*  Handle, Memory I/O,  Zlib Compression routines are not tested , and, line conversion routines  are not translated yet. *)

CONST
 #IF UNIX THEN
	libname="libfreeimage.so.3";
#ELSIF WIN THEN
	libname="FreeImage.dll";
#ELSE
	UNIMPLEMENTED
#END
		
VAR 
	lib: HostLibs.LibHandle;
	
CONST
	
	(* Version information  *)
	MAJOR_VERSION* = 3;
	MINOR_VERSION* = 17;
	RELEASE_SERIAL* = 0;
		
	(* Indexes for byte arrays, masks and shifts for treating pixels as words
	These coincide with the order of RGBQUAD and RGBTRIPLE
	Little Endian (x86 / MS Windows, Linux) : BGR(A) order *)

	FI_RGBA_RED* = 2;
	FI_RGBA_GREEN* = 1;
	FI_RGBA_BLUE* = 0;
	FI_RGBA_ALPHA* = 3;
	FI_RGBA_RED_MASK* = 00FF0000H;
	FI_RGBA_GREEN_MASK* = 0000FF00H;
	FI_RGBA_BLUE_MASK* = 000000FFH;
	FI_RGBA_ALPHA_MASK* = 0FF000000H;
	FI_RGBA_RED_SHIFT* = 16;
	FI_RGBA_GREEN_SHIFT* = 8;
	FI_RGBA_BLUE_SHIFT* = 0;
	FI_RGBA_ALPHA_SHIFT* = 24;

	(* Little Endian (x86 / MaxOSX) : RGB(A) order *)
(*	FI_RGBA_RED* = 0;
	FI_RGBA_GREEN* = 1;
	FI_RGBA_BLUE* = 2;
	FI_RGBA_ALPHA* = 3;
	FI_RGBA_RED_MASK* = 000000FFH;
	FI_RGBA_GREEN_MASK* = 0000FF00H;
	FI_RGBA_BLUE_MASK* = 00FF0000H;
	FI_RGBA_ALPHA_MASK* = 0FF000000H;
	FI_RGBA_RED_SHIFT* = 0;
	FI_RGBA_GREEN_SHIFT* = 8;
	FI_RGBA_BLUE_SHIFT* = 16;
	FI_RGBA_ALPHA_SHIFT* = 24;
*)

	(* --------------------------------------------------------------------------
	The 16bit macros only include masks and shifts,
	since each color element is not byte aligned
	--------------------------------------------------------------------------*)

CONST
	FI16_555_RED_MASK* = 7C00H;
	FI16_555_GREEN_MASK* = 03E0H;
	FI16_555_BLUE_MASK* = 001FH;
	FI16_555_RED_SHIFT* = 10;
	FI16_555_GREEN_SHIFT* = 5;
	FI16_555_BLUE_SHIFT* = 0;
	FI16_565_RED_MASK* = 0F800H;
	FI16_565_GREEN_MASK* = 07E0H;
	FI16_565_BLUE_MASK* = 001FH;
	FI16_565_RED_SHIFT* = 11;
	FI16_565_GREEN_SHIFT* = 5;
	FI16_565_BLUE_SHIFT* = 0;

	(* ICC profile support *)
CONST
	FIICC_DEFAULT* = 0H;
	FIICC_COLOR_IS_CMYK* = 1H;

TYPE 
	FIICCPROFILE* = RECORD
		flags*: SIGNED16;	(* ! info flag *)
		size*: SIGNED32;		(* ! profile's size measured in bytes *)
		data*: ADDRESS;		(* ! points to a block of contiguous memory containing the profile *)
	END;
	
CONST
	(* I/O image format identifiers. *)
TYPE IMAGE_FORMAT* = SIGNED32;
CONST
	FIF_UNKNOWN* = -1;
	FIF_BMP* = 0;
	FIF_ICO* = 1;
	FIF_JPEG* = 2;
	FIF_JNG* = 3;
	FIF_KOALA* = 4;
	FIF_LBM* = 5;
	FIF_IFF* = FIF_LBM;
	FIF_MNG* = 6;
	FIF_PBM* = 7;
	FIF_PBMRAW* = 8;
	FIF_PCD* = 9;
	FIF_PCX* = 10;
	FIF_PGM* = 11;
	FIF_PGMRAW* = 12;
	FIF_PNG* = 13;
	FIF_PPM* = 14;
	FIF_PPMRAW* = 15;
	FIF_RAS* = 16;
	FIF_TARGA* = 17;
	FIF_TIFF* = 18;
	FIF_WBMP* = 19;
	FIF_PSD* = 20;
	FIF_CUT* = 21;
	FIF_XBM* = 22;
	FIF_XPM* = 23;
	FIF_DDS* = 24;
	FIF_GIF* = 25;
	FIF_HDR* = 26;
	FIF_FAXG3* = 27;
	FIF_SGI* = 28;
	FIF_EXR* = 29;
	FIF_J2K* = 30;
	FIF_JP2* = 31;
	FIF_PFM* = 32;
	FIF_PICT* = 33;
	
	FIF_RAW* = 34;
	FIF_WEBP* = 35;
	FIF_JXR* = 36;
	
	(* Image type used in FreeImage.*)
TYPE IMAGE_TYPE* = SIGNED32;
CONST
	FIT_UNKNOWN* = 0;	(* unknown type *)
	FIT_BITMAP* = 1;	(* standard image		: 1-, 4-, 8-, 16-, 24-, 32-bit *)
	FIT_UINT16* = 2;	(* array of unsigned short	: unsigned 16-bit *)
	FIT_INT16* = 3;		(* array of short		: signed 16-bit *)
	FIT_UINT32* = 4;	(* array of unsigned long	: unsigned 32-bit *)
	FIT_INT32* = 5;		(* array of long		: signed 32-bit *)
	FIT_FLOAT* = 6;		(* array of float		: 32-bit IEEE floating point *)
	FIT_DOUBLE* = 7;	(* array of double		: 64-bit IEEE floating point *)
	FIT_COMPLEX* = 8;	(* array of FICOMPLEX		: 2 x 64-bit IEEE  floating point *)
	FIT_RGB16* = 9;		(* 48-bit RGB image		: 3 x 16-bit *)
	FIT_RGBA16* = 10;	(* 64-bit RGBA image		: 4 x 16-bit *)
	FIT_RGBF* = 11;		(* 96-bit RGB float image	: 3 x 32-bit IEEE floating point *)
	FIT_RGBAF* = 12;	(* 128-bit RGBA float image	: 4 x 32-bit IEEE floating point *)

	(* Image color type used in FreeImage. *)
TYPE IMAGE_COLOR_TYPE* = SIGNED32;
CONST
	FIC_MINISWHITE* = 0;	(* min value is white *)
	FIC_MINISBLACK* = 1;	(* min value is black *)
	FIC_RGB* = 2;		(* RGB color model *)
	FIC_PALETTE* = 3;	(* color map indexed *)
	FIC_RGBALPHA* = 4;	(* RGB color model with alpha channel *)
	FIC_CMYK* = 5;		(* CMYK color model *)

	(* Color quantization algorithms. Constants used in FreeImage_ColorQuantize. *)
TYPE IMAGE_QUANTIZE* = SIGNED32;
CONST
	FIQ_WUQUANT* = 0;	(* Xiaolin Wu color quantization algorithm *)
	FIQ_NNQUANT* = 1;	(* NeuQuant neural-net quantization algorithm by Anthony Dekker *)
	FIQ_LFPQUANT* = 2;	(* Lossless Fast Pseudo-Quantization Algorithm by Carsten Klein *)

	(* Dithering algorithms. Constants used FreeImage_Dither. *)
TYPE IMAGE_DITHER* = SIGNED32;
CONST
	FID_FS* = 0;		(* Floyd & Steinberg error diffusion *)
	FID_BAYER4x4* = 1;	(* Bayer ordered dispersed dot dithering (order 2 dithering matrix)*)
	FID_BAYER8x8* = 2;	(* Bayer ordered dispersed dot dithering (order 3 dithering matrix)*)
	FID_CLUSTER6x6* = 3;	(* Ordered clustered dot dithering (order 3 - 6x6 matrix)*)
	FID_CLUSTER8x8* = 4;	(* Ordered clustered dot dithering (order 4 - 8x8 matrix)*)
	FID_CLUSTER16x16* = 5;  (* Ordered clustered dot dithering (order 8 - 16x16 matrix)*)
	FID_BAYER16x16* = 6;	(* Bayer ordered dispersed dot dithering (order 4 dithering matrix)*)

	(* Lossless JPEG transformations Constants used in FreeImage_JPEGTransform	*)
TYPE IMAGE_JPEG_OPERATION* = SIGNED32;
CONST
	FIJPEG_OP_NONE* = 0;		(* no transformation *)
	FIJPEG_OP_FLIP_H* = 1;		(* horizontal flip *)
	FIJPEG_OP_FLIP_V* = 2;		(* vertical flip *)
	FIJPEG_OP_TRANSPOSE* = 3;	(* transpose across UL-to-LR axis *)
	FIJPEG_OP_TRANSVERSE* = 4;	(* transpose across UR-to-LL axis *)
	FIJPEG_OP_ROTATE_90* = 5;	(* 90-degree clockwise rotation *)
	FIJPEG_OP_ROTATE_180* = 6;	(* 180-degree rotation *)
	FIJPEG_OP_ROTATE_270* = 7;	(* 270-degree clockwise (or 90 ccw) *)

	(* Tone mapping operators. Constants used in FreeImage_ToneMapping. *)
TYPE IMAGE_TMO* = SIGNED32;
CONST
	FITMO_DRAGO03* = 0;	(* Adaptive logarithmic mapping (F. Drago, 2003) *)
	FITMO_REINHARD05* = 1;	(* Dynamic range reduction inspired by photoreceptor physiology (E. Reinhard, 2005) *)
	FITMO_FATTAL02* = 2;	(* Gradient domain high dynamic range compression (R. Fattal, 2002) *)

	(* Upsampling / downsampling filters. Constants used in FreeImage_Rescale. *)
TYPE IMAGE_FILTER* = SIGNED32;
CONST
	FILTER_BOX* = 0;	(* Box, pulse, Fourier window, 1st order (constant) b-spline *)
	FILTER_BICUBIC* = 1;	(* Mitchell & Netravali's two-param cubic filter *)
	FILTER_BILINEAR* = 2;	(* Bilinear filter *)
	FILTER_BSPLINE* = 3;	(* 4th order (cubic) b-spline *)
	FILTER_CATMULLROM* = 4; (* Catmull-Rom spline, Overhauser spline *)
	FILTER_LANCZOS3* = 5;	(* Lanczos3 filter *)

	(* Color channels. Constants used in color manipulation routines. *)
TYPE IMAGE_COLOR_CHANNEL* = SIGNED32;
CONST
	FICC_RGB* = 0;		(* Use red, green and blue channels *)
	FICC_RED* = 1;		(* Use red channel *)
	FICC_GREEN* = 2;	(* Use green channel *)
	FICC_BLUE* = 3;		(* Use blue channel *)
	FICC_ALPHA* = 4;	(* Use alpha channel *)
	FICC_BLACK* = 5;	(* Use black channel *)
	FICC_REAL* = 6;		(* Complex images: use real part *)
	FICC_IMAG* = 7;		(* Complex images: use imaginary part *)
	FICC_MAG* = 8;		(* Complex images: use magnitude *)
	FICC_PHASE* = 9;	(* Complex images: use phase *)

	(* Metadata support ---------------------- *)
	(*  Tag data type information (based on TIFF specifications)
	Note: RATIONALs are the ratio of two 32-bit integer values. *)
		
TYPE IMAGE_MDTYPE* = SIGNED32;
CONST
	FIDT_NOTYPE* = 0;	(* placeholder *)
	FIDT_BYTE* = 1;		(* 8-bit unsigned integer *)
	FIDT_ASCII* = 2;	(* 8-bit bytes w/ last byte null *)
	FIDT_SHORT* = 3;	(* 16-bit unsigned integer *)
	FIDT_LONG* = 4;		(* 32-bit unsigned integer *)
	FIDT_RATIONAL* = 5;	(* 64-bit unsigned fraction *)
	FIDT_SBYTE* = 6;	(* 8-bit signed integer *)
	FIDT_UNDEFINED* = 7;	(* 8-bit untyped data *)
	FIDT_SSHORT* = 8;	(* 16-bit signed integer *)
	FIDT_SLONG* = 9;	(* 32-bit signed integer *)
	FIDT_SRATIONAL* = 10;	(* 64-bit signed fraction *)
	FIDT_FLOAT* = 11;	(* 32-bit IEEE floating point *)
	FIDT_DOUBLE* = 12;	(* 64-bit IEEE floating point *)
	FIDT_IFD* = 13;	(* 32-bit unsigned integer (offset)*)
	FIDT_PALETTE* = 14;	(* 32-bit RGBQUAD *)
	FIDT_LONG8* = 16;	(* 64-bit unsigned integer *)
	FIDT_SLONG8* = 17;	(* 64-bit signed integer *)
	FIDT_IFD8* = 18;	(* 64-bit unsigned integer (offset) *)

	(*  Metadata models supported by FreeImage *)
TYPE IMAGE_MDMODEL* = SIGNED32;
CONST
	FIMD_NODATA* = -1;
	FIMD_COMMENTS* = 0;		(* single comment or keywords *)
	FIMD_EXIF_MAIN* = 1;		(* Exif-TIFF metadata *)
	FIMD_EXIF_EXIF* = 2;		(* Exif-specific metadata *)
	FIMD_EXIF_GPS* = 3;		(* Exif GPS metadata *)
	FIMD_EXIF_MAKERNOTE* = 4;	(* Exif maker note metadata *)
	FIMD_EXIF_INTEROP* = 5;	(* Exif interoperability metadata *)
	FIMD_IPTC* = 6;		(* IPTC/NAA metadata *)
	FIMD_XMP* = 7;			(* Abobe XMP metadata *)
	FIMD_GEOTIFF* = 8;		(* GeoTIFF metadata *)
	FIMD_ANIMATION* = 9;		(* Animation metadata *)
	FIMD_CUSTOM* = 10;		(* Used to attach other metadata types to a dib *)
	FIMD_EXIF_RAW* = 11;		(* Exif metadata as a raw buffer *)

	(*  Load / Save flag constants  *)
TYPE  IMAGE_FLAGS* = SIGNED32;
CONST
	FIF_LOAD_NOPIXELS* = 8000H; (* loading: load the image header only (not supported by all plugins, default to full loading) *)

	BMP_DEFAULT* = 0;
	BMP_SAVE_RLE* = 1;
	CUT_DEFAULT* = 0;
	DDS_DEFAULT* = 0;
	EXR_DEFAULT* = 0;	(* save data as half with piz-based wavelet compression *)
	EXR_FLOAT* = 0001H;	(* save data as float instead of as half (not recommended) *)
	EXR_NONE* = 0002H;	(* save with no compression *) 
	EXR_ZIP* = 0004H;	(* save with zlib compression, in blocks of 16 scan lines *)
	EXR_PIZ* = 0008H;	(* save with piz-based wavelet compression *)
	EXR_PXR24* = 0010H;	(* save with lossy 24-bit float compression *)
	EXR_B44* = 0020H;	(* save with lossy 44% float compression - goes to 22% when combined with EXR_LC *)
	EXR_LC* = 0040H;	(* save images with one luminance and two chroma channels, rather than as RGB (lossy compression) *)
		
	FAXG3_DEFAULT* = 0;
	GIF_DEFAULT* = 0;
	GIF_LOAD256* = 1;		(*  Load the image as a 256 color image with ununsed palette entries, if it's 16 or 2 color *)
	GIF_PLAYBACK* = 2;		(* 'Play' the GIF to generate each frame (as 32bpp) instead of returning raw frame data when loading *)
	HDR_DEFAULT* = 0;
	ICO_DEFAULT* = 0;
	ICO_MAKEALPHA* = 1;		(*  convert to 32bpp and create an alpha channel from the AND-mask when loading *)
	IFF_DEFAULT* = 0;
	J2K_DEFAULT* = 0;		(* save with a 16:1 rate *)
	JP2_DEFAULT* = 0;		(* save with a 16:1 rate *)
	JPEG_DEFAULT* = 0;
	JPEG_FAST* = 1;
	JPEG_ACCURATE* = 2;
	JPEG_CMYK* = 01000H;		(*  load separated CMYK "as is" (use | to combine with other flags) *)
	JPEG_EXIFROTATE* = 0008H;	(* load and rotate according to Exif 'Orientation' tag if available *)
	JPEG_GREYSCALE* = 0010H;	(* load and convert to a 8-bit greyscale image *)
		
	JPEG_QUALITYSUPERB* = 080H;
	JPEG_QUALITYGOOD* = 0100H;
	JPEG_QUALITYNORMAL* = 0200H;
	JPEG_QUALITYAVERAGE* = 0400H;
	JPEG_QUALITYBAD* = 0800H;
	JPEG_PROGRESSIVE* = 02000H;	(*save as a progressive-JPEG (use | to combine with other flags) *)
	JPEG_SUBSAMPLING_411* = 1000H;	(* save with high 4x1 chroma subsampling (4:1:1)  *)
	JPEG_SUBSAMPLING_420* = 4000H;	(* save with medium 2x2 medium chroma subsampling (4:2:0) - default value *)
	JPEG_SUBSAMPLING_422* = 8000H;	(* save with low 2x1 chroma subsampling (4:2:2)  *)
	JPEG_SUBSAMPLING_444* = 10000H;	(* save with no chroma subsampling (4:4:4) *)
	JPEG_OPTIMIZE* = 20000H;	(* on saving, compute optimal Huffman coding tables (can reduce a few percent of file size) *)
	JPEG_BASELINE* = 40000H;	(* save basic JPEG, without metadata or any markers *)
		
	KOALA_DEFAULT* = 0;
	LBM_DEFAULT* = 0;
	MNG_DEFAULT* = 0;
	PCD_DEFAULT* = 0;
	PCD_BASE* = 1;			(* load the bitmap sized 768 x 512 *)
	PCD_BASEDIV4* = 2;		(*  load the bitmap sized 384 x 256 *)
	PCD_BASEDIV16* = 3;		(*  load the bitmap sized 192 x 128 *)
	PCX_DEFAULT* = 0;
	PFM_DEFAULT* = 0;
	PICT_DEFAULT* =  0;
	PNG_DEFAULT* = 0;
	PNG_IGNOREGAMMA* = 1;			(*  avoid gamma correction *)
	PNG_Z_BEST_SPEED* = 0001H;		(* save using ZLib level 1 compression flag (default value is 6) *)
	PNG_Z_DEFAULT_COMPRESSION* = 0006H;	(* save using ZLib level 6 compression flag (default recommended value) *)
	PNG_Z_BEST_COMPRESSION* = 0009H;	(* save using ZLib level 9 compression flag (default value is 6) *)
	PNG_Z_NO_COMPRESSION* =	0100H;		(* save without ZLib compression *)
	PNG_INTERLACED* = 0200H;		(* save using Adam7 interlacing (use | to combine with other save flags)*)		
	PNM_DEFAULT* = 0;
	PNM_SAVE_RAW* = 0;	(* If set the writer saves in RAW format (i.e. P4, P5 or P6) *)
	PNM_SAVE_ASCII* = 1;	(* If set the writer saves in ASCII format (i.e. P1, P2 or P3) *)
	PSD_DEFAULT* = 0;
	PSD_CMYK* = 1;		(* reads tags for separated CMYK (default is conversion to RGB) *)
	PSD_LAB* = 2;		(* reads tags for CIELab (default is conversion to RGB) *)
		
	RAS_DEFAULT* = 0;
	RAW_DEFAULT* = 0;	(* load the file as linear RGB 48-bit *)
	RAW_PREVIEW* = 1;	(* try to load the embedded JPEG preview with included Exif Data or default to RGB 24-bit *)
	RAW_DISPLAY* = 2;	(* load the file as RGB 24-bit *)
	RAW_HALFSIZE* = 4;	(* output a half-size color image *)
	RAW_UNPROCESSED* = 8;	(* output a FIT_UINT16 raw Bayer image *)
		
	SGI_DEFAULT* = 0;
	TARGA_DEFAULT* = 0;
	TARGA_LOAD_RGB888* = 1; (* If set the loader converts RGB555 and ARGB8888 -> RGB888. *)
	TARGA_SAVE_RLE* = 2;	(* If set, the writer saves with RLE compression *)
		
	TIFF_DEFAULT* = 0;
	TIFF_CMYK* = 00001H;		(* reads/stores tags for separated CMYK (use | to combine with compression flags) *)
	TIFF_PACKBITS* = 00100H;	(* save using PACKBITS compression *)
	TIFF_DEFLATE* = 00200H;		(* save using DEFLATE compression (a.k.a. ZLIB compression) *)
	TIFF_ADOBE_DEFLATE* = 00400H;	(* save using ADOBE DEFLATE compression *)
	TIFF_NONE* = 00800H;		(* save without any compression *)
	TIFF_CCITTFAX3* = 01000H;	(* save using CCITT Group 3 fax encoding *)
	TIFF_CCITTFAX4* = 02000H;	(* save using CCITT Group 4 fax encoding *)
	TIFF_LZW* = 04000H;		(* save using LZW compression *)
	TIFF_JPEG* = 08000H;		(* save using JPEG compression *)
	TIFF_LOGLUV* = 10000H;		(* save using LogLuv compression *)
	WBMP_DEFAULT* = 0;
	XBM_DEFAULT* = 0;
	XPM_DEFAULT* = 0;
	WEBP_DEFAULT* =	0;		(* ! save with good quality (75:1) *)
	WEBP_LOSSLESS* = 100H;		(* ! save in lossless mode *)
	JXR_DEFAULT* = 0;		(* ! save with quality 80 and no chroma subsampling (4:4:4) *)
	JXR_LOSSLESS* = 0064H;		(* ! save lossless *)
	JXR_PROGRESSIVE* = 2000H;	(* ! save as a progressive-JXR (use | to combine with other save flags) *)

(*  Background filling options ---------------------------------------------------------
	Constants used in FreeImage_FillBackground and FreeImage_EnlargeCanvas *)

	COLOR_IS_RGB_COLOR* = 0H;	(* RGBQUAD color is a RGB color (contains no valid alpha channel) *)
	COLOR_IS_RGBA_COLOR* = 1H;	(* RGBQUAD color is a RGBA color (contains a valid alpha channel) *)
	COLOR_FIND_EQUAL_COLOR* = 2H;	(* For palettized images: lookup equal RGB color from palette *)
	COLOR_ALPHA_IS_INDEX* =  4H;	(* The color's rgbReserved member (alpha) contains the palette index to be used *)
	COLOR_PALETTE_SEARCH_MASK* = (COLOR_FIND_EQUAL_COLOR  + COLOR_ALPHA_IS_INDEX);	(* No color lookup is performed *)

(* RescaleEx options ---------------------------------------------------------
 Constants used in FreeImage_RescaleEx *)

	RESCALE_DEFAULT* = 0;		(* default options; none of the following other options apply *)
	RESCALE_TRUE_COLOR* = 1;	(* for non-transparent greyscale images, convert to 24-bit if src bitdepth <= 8 (default is a 8-bit greyscale image). *)
	RESCALE_OMIT_METADATA* = 2;	(* do not copy metadata to the rescaled image *)


TYPE
	RGBQUAD* = RECORD
		rgbBlue*: CHAR;
		rgbGreen*: CHAR;
		rgbRed*: CHAR;
		rgbReserved*: CHAR
	END;

	RGBTRIPLE* = RECORD
		rgbtBlue*: CHAR;
		rgbtGreen*: CHAR;
		rgbtRed*: CHAR
	END;

	PtrBITMAPINFOHEADER* = POINTER {UNTRACED, UNSAFE} TO BITMAPINFOHEADER;
	BITMAPINFOHEADER* = RECORD 
		biSize*: SIGNED32;
		biWidth*: SIGNED32;
		biHeight*: SIGNED32;
		biPlanes*: SIGNED16;
		biBitCount*: SIGNED16;
		biCompression*: SIGNED32;
		biSizeImage*: SIGNED32;
		biXPelsPerMeter*: SIGNED32;
		biYPelsPerMeter*: SIGNED32;
		biClrUsed*: SIGNED32;
		biClrImportant*: SIGNED32;
	END;


	PtrBITMAPINFO* = POINTER {UNTRACED, UNSAFE} TO BITMAPINFO;
	BITMAPINFO* = RECORD 
		bmiHeader*: BITMAPINFOHEADER;
		bmiColors*: ARRAY  1 OF RGBQUAD;
	END;

	(* 48-bit RGB *)
	 FIRGB16* = RECORD
		red*: SIGNED16;
		green*: SIGNED16;
		blue*: SIGNED16
	END;

	(* 64-bit RGBA *)
	 FIRGBA16* = RECORD
		red*: SIGNED16;
		green*: SIGNED16;
		blue*: SIGNED16;
		alpha*: SIGNED16
	END;

	(* 96-bit RGB Float *)
	 FIRGBF* = RECORD
		red*: FLOAT32;
		green*: FLOAT32;
		blue*: FLOAT32
	END;

	(* 128-bit RGBA Float	*)
	FIRGBAF* = RECORD
		red*: FLOAT32;
		green*: FLOAT32;
		blue*: FLOAT32;
		alpha*: FLOAT32
	END;

		(* Data structure for COMPLEX32 type (complex number) *)
	FICOMPLEX* = RECORD
		r*: FLOAT64; (* real part *)
		i*: FLOAT64; (* imaginary part *)
	END;

	LUT* = ARRAY  256 OF CHAR; (* aded for compatibility to v3.10.0, GetAdjustColorsLookupTable, etc. *)

	(* ****************************** *)
	(*! used for easy accessing to pixels of various image types, see Scanline procs. ( Necati ) *)
	PtrLineRGB* = POINTER {UNTRACED, UNSAFE}TO ARRAY MAX(SIZE) OF RGBTRIPLE; (* for accessing 24 bit lines, RGB *)
	PtrLineRGBA* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF RGBQUAD; (* for accessing 32 bit lines, RGBA *)
	PtrFISINT16* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF SIGNED16; (* for 16 bit integers *)
	PtrFIINT32* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF SIGNED32; (* for 32 bit integers *)
	PtrFIFLOAT* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF FLOAT32; (* for 32 bit real *)
	PtrFIDOUBLE* = POINTER {UNTRACED, UNSAFE}TO ARRAY MAX(SIZE) OF FLOAT64; (* for 64 bit real *)

	PtrFICOMPLEX* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF FICOMPLEX; (* 2x64 bits real, Complex *)
	PtrFIRGB16* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF FIRGB16; (* for 48-bit RGB, 3x16 bits *)
	PtrFIRGBA16* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF FIRGBA16; (* 64-bit RGBA, 4x16 bits *)
	PtrFIRGBF* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF FIRGBF; (* 96-bit RGB Float, 3*32 bits *)
	PtrFIRGBAF* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF FIRGBAF; (* 128-bit RGBA Float, 4x32 bits *)

	Palette* = ARRAY 256 OF RGBQUAD;
	PtrPALETTE* = POINTER {UNTRACED, UNSAFE} TO Palette;

	(* File IO routines *)
	FHandle* =  ADDRESS;
	PSint* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF SIGNED16;
	Pint* = POINTER {UNTRACED, UNSAFE} TO ARRAY MAX(SIZE) OF SIGNED32;
	FI_ReadProc* = PROCEDURE {PlatformCC} (buffer: ADDRESS; size: SIGNED32; count: SIGNED32; handle: FHandle): SIGNED32;
	FI_WriteProc* = PROCEDURE {PlatformCC} (buffer: ADDRESS; size: SIGNED32; count: SIGNED32; handle: FHandle): SIGNED32;
	FI_SeekProc* = PROCEDURE {PlatformCC} (handle: FHandle; offset: SIGNED32; origin: SIGNED32): PSint;
	FI_TellProc* = PROCEDURE {PlatformCC} (handle: FHandle): Pint;

	
	FreeImageIO* = POINTER {UNTRACED, UNSAFE} TO RECORD
		read_proc *: FI_ReadProc; (* pointer to the function used to read data *)
		write_proc*: FI_WriteProc; (* pointer to the function used to write data *)
		seek_proc*: FI_SeekProc; (* pointer to the function used to seek *)
		tell_proc*: FI_TellProc; (* pointer to the function used to aquire the current position *)
	END;

	FIMEMORY* = POINTER {UNTRACED, UNSAFE} TO RECORD END;(* Handle to a memory I/O stream *)
	FIBITMAP* = POINTER {UNTRACED, UNSAFE} TO RECORD END; (* Handle to a FreeImage bitmap *)
	FIMULTIBITMAP* = POINTER {UNTRACED, UNSAFE} TO RECORD END; (* handle to a multibitmap *)
	FIMETADATA* = POINTER  {UNTRACED, UNSAFE} TO RECORD END; (* Handle to a metadata model *)
	FITAG* = POINTER {UNTRACED, UNSAFE} TO RECORD END; (* Handle to a FreeImage tag *)

	OutputMessageFunction* = PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; msg: POINTER  {UNSAFE} TO ARRAY 1024 OF CHAR);
	OutputMessageFunctionStdCall* = PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT;  msg: POINTER  {UNSAFE} TO ARRAY 1024 OF CHAR);
	

CONST
(* constants used in FreeImage_Seek for Origin parameter *)
	SEEK_SET* = 0;
	SEEK_CUR* = 1;
	SEEK_END* = 2;

VAR
	(* Init/Error routines -------------------------------- *)
(* is not required for dynamic linking *)
(*	Initialise- : PROCEDURE {PlatformCC} (load_local_plugins_only: BOOLEAN);
	DeInitialise-: PROCEDURE {PlatformCC}();
*)

	(* Version routines -------------------------------- *)
	getVersion-: PROCEDURE {PlatformCC}(): ADDRESS;
	getCopyrightMessage-: PROCEDURE {PlatformCC}(): ADDRESS;

	(* Message output functions -------------------------------- *)
	SetOutputMessage-: PROCEDURE {PlatformCC} (omf: OutputMessageFunction);
	SetOutputMessageStdCall-: PROCEDURE {PlatformCC} (omf: OutputMessageFunctionStdCall);

	(* Allocate/Clone/Unload routines -------------------------------- *)
	Allocate-: PROCEDURE {PlatformCC} (width, height: SIGNED32; bpp: SIGNED32; red_mask, green_mask, blue_mask: SIGNED32): FIBITMAP;
	AllocateT-: PROCEDURE {PlatformCC} (type: IMAGE_TYPE; width, height: SIGNED32; bpp: SIGNED32; red_mask, green_mask, blue_mask: SIGNED32): FIBITMAP;
	Clone-: PROCEDURE {PlatformCC}(dib: FIBITMAP): FIBITMAP;
	Unload-: PROCEDURE {PlatformCC} (dib: FIBITMAP);

	(* Header loading routines -------------------------------- *)
	HasPixels-: PROCEDURE {PlatformCC} (dib: FIBITMAP): BOOLEAN ;

	(* Load/Save routines -------------------------------- *)
	Load-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; CONST filename: ARRAY OF CHAR; flags: IMAGE_FLAGS): FIBITMAP;
	LoadU-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; CONST filename: ARRAY OF CHAR; flags: IMAGE_FLAGS): FIBITMAP;
	Save-: PROCEDURE {PlatformCC}(fif: IMAGE_FORMAT; dib: FIBITMAP; CONST filename: ARRAY OF CHAR; flags: IMAGE_FLAGS): BOOLEAN;
	SaveU-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; dib: FIBITMAP; CONST filename: ARRAY OF CHAR; flags: IMAGE_FLAGS): BOOLEAN;
	(*LoadFromHandle-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; io: FreeImageIO; hadle: SIGNED32; flags: SIGNED32): FIBITMAP;
	SaveToHandle-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; dib: FIBITMAP; io: FreeImageIO ; handle: SIGNED32;  flags: SIGNED32): BOOLEAN;
	*)


	(* Memory I/O stream routines  -------------------------------- *)

	(* NOT TESTED *)
	OpenMemory-: PROCEDURE {PlatformCC} (data: ADDRESS; size_in_bytes: SIGNED32): FIMEMORY;
	CloseMemory-: PROCEDURE {PlatformCC} (stream: FIMEMORY);
	LoadFromMemory-: PROCEDURE {PlatformCC}  (fif: IMAGE_FORMAT; stream: FIMEMORY; flags: SIGNED32): FIBITMAP;
	SaveToMemory-: PROCEDURE {PlatformCC}  (fif: IMAGE_FORMAT; dib: FIBITMAP; stream: FIMEMORY; flags: SIGNED32): BOOLEAN;
	TellMemory-: PROCEDURE {PlatformCC}  (stream: FIMEMORY): SIGNED32;
	SeekMemory-: PROCEDURE {PlatformCC}  (stream: FIMEMORY; offset: SIGNED32; origin: SIGNED32): BOOLEAN;
	AcquireMemory-: PROCEDURE {PlatformCC}  (stream: FIMEMORY;  VAR data: ADDRESS; VAR size_in_bytes: SIGNED32): BOOLEAN;
	ReadMemory-: PROCEDURE {PlatformCC}(buffer: ADDRESS; size: SIGNED32; count: SIGNED32; stream: FIMEMORY): SIGNED32;
	WriteMemory-: PROCEDURE {PlatformCC} (buffer: ADDRESS; size: SIGNED32; count: SIGNED32; stream: FIMEMORY): SIGNED32;
	LoadMultiBitmapFromMemory-: PROCEDURE {PlatformCC}  (fif: IMAGE_FORMAT; stream: FIMEMORY; flags: SIGNED32): FIMULTIBITMAP;
	SaveMultiBitmapToMemory-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; bitmap: FIMULTIBITMAP; stream: FIMEMORY; flags: SIGNED32): BOOLEAN;
	
	(* Plugin Interface -------------------------------- *)
	GetFIFCount-: PROCEDURE {PlatformCC} (): SIGNED32;
	SetPluginEnabled-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; enable: BOOLEAN): SIGNED32;
	IsPluginEnabled-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT): SIGNED32;
	GetFIFFromFormat-: PROCEDURE {PlatformCC} (CONST format: ARRAY OF CHAR): IMAGE_FORMAT;
	GetFIFFromMime-: PROCEDURE {PlatformCC} (CONST format: ARRAY OF CHAR): IMAGE_FORMAT;

	getFormatFromFIF-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT): ADDRESS;
	getFIFExtensionList-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT): ADDRESS;
	getFIFDescription-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT): ADDRESS;
	getFIFRegExpr-: PROCEDURE {PlatformCC}  (fif: IMAGE_FORMAT): ADDRESS;

	GetFIFFromFilename- : PROCEDURE {PlatformCC} (CONST fname: ARRAY OF CHAR): IMAGE_FORMAT;
	GetFIFFromFilenameU-: PROCEDURE {PlatformCC} (CONST fname: ARRAY OF CHAR): IMAGE_FORMAT;
	FIFSupportsReading-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT): BOOLEAN;
	FIFSupportsWriting-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT): BOOLEAN;
	FIFSupportsExportBPP-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; bpp: SIGNED32): BOOLEAN;
	FIFSupportsExportType-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; image_type: IMAGE_TYPE): BOOLEAN;
	FIFSupportsICCProfiles-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT): BOOLEAN;
	FIFSupportsNoPixels-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT): BOOLEAN;

	(* Multipaging interface -------------------------------- *)
	OpenMultiBitmap-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; CONST filename: ARRAY OF CHAR; create_new, read_only, keep_cache_in_memory: BOOLEAN): FIMULTIBITMAP;
	OpenMultiBitmapFromHandle-: PROCEDURE {PlatformCC}  (fif: IMAGE_FORMAT ; io: FreeImageIO; handle: SIGNED32;  flags: SIGNED32): FIMULTIBITMAP; 
	SaveMultiBitmapToHandle-: PROCEDURE {PlatformCC} (fif: IMAGE_FORMAT; bitmap: FIMULTIBITMAP; io: FreeImageIO;  handle: FHandle;  flags: SIGNED32): BOOLEAN;
	CloseMultiBitmap-: PROCEDURE {PlatformCC} (bitmap: FIMULTIBITMAP; flags: SIGNED32): BOOLEAN;
	GetPageCount-: PROCEDURE {PlatformCC}  (bitmap: FIMULTIBITMAP): SIGNED32;
	AppendPage-: PROCEDURE {PlatformCC}  (bitmap: FIMULTIBITMAP; data: FIBITMAP);
	InsertPage-: PROCEDURE {PlatformCC} (bitmap: FIMULTIBITMAP; page: SIGNED32; data: FIBITMAP);
	DeletePage-: PROCEDURE {PlatformCC}  (bitmap: FIMULTIBITMAP; page: SIGNED32);
	LockPage-: PROCEDURE {PlatformCC} (bitmap: FIMULTIBITMAP; page: SIGNED32): FIBITMAP;
	UnlockPage-: PROCEDURE {PlatformCC}  (bitmap: FIMULTIBITMAP; page: FIBITMAP; changed: BOOLEAN);
	MovePage-: PROCEDURE {PlatformCC} (bitmap: FIMULTIBITMAP; target, source: SIGNED32): BOOLEAN;
	GetLockedPageNumbers-: PROCEDURE {PlatformCC}  (bitmap: FIMULTIBITMAP; VAR pages: SIGNED32; VAR count: SIGNED32): BOOLEAN;


	(* Filetype request routines -------------------------------- *)
	GetFileType-: PROCEDURE {PlatformCC} (CONST filename: ARRAY OF CHAR; size: SIGNED32): IMAGE_FORMAT;
	GetFileTypeU-: PROCEDURE {PlatformCC} (CONST filename: ARRAY OF CHAR; size: SIGNED32): IMAGE_FORMAT;
	GetFileTypeFromHandle-: PROCEDURE {PlatformCC} (io: FreeImageIO; handle: SIGNED32; size: SIGNED32): IMAGE_FORMAT;
	GetFileTypeFromMemory-: PROCEDURE {PlatformCC} (stream: FIMEMORY; size: SIGNED32 ): IMAGE_FORMAT;
	

	(* ImageType request routine -------------------------------- *)
	GetImageType-: PROCEDURE{PlatformCC} (dib: FIBITMAP): IMAGE_TYPE;

	(* FreeImage helper routines -------------------------------- *)
	
	IsLittleEndian-: PROCEDURE {PlatformCC} (): BOOLEAN;
	LookupX11Color-: PROCEDURE {PlatformCC} (CONST szColor: ARRAY OF CHAR; VAR nRed, nGreen, nBlue: CHAR): BOOLEAN;
	LookupSVGColor-: PROCEDURE {PlatformCC} (CONST szColor: ARRAY OF CHAR; VAR nRed, nGreen, nBlue: CHAR): BOOLEAN;

	(* Pixels access routines -------------------------------- *)
	GetBits-:  PROCEDURE {PlatformCC} (dib: FIBITMAP): ADDRESS;
	GetScanLine-: PROCEDURE {PlatformCC} (dib: FIBITMAP; scanline: SIGNED32): ADDRESS;
	GetPixelColor-: PROCEDURE {PlatformCC} (dib: FIBITMAP; x, y: SIGNED32; VAR value: RGBQUAD);
	SetPixelColor-: PROCEDURE {PlatformCC} (dib: FIBITMAP; x, y: SIGNED32; CONST value: RGBQUAD);
	GetPixelIndex-: PROCEDURE {PlatformCC} (dib: FIBITMAP; x, y: SIGNED32; VAR value: CHAR): BOOLEAN;
	SetPixelIndex-: PROCEDURE {PlatformCC} (dib: FIBITMAP; x, y: SIGNED32; CONST value: CHAR): BOOLEAN;

	(* ****************************** *)
	(* utilitiy procedures for different type of image line pixels, necati *)

	GetScanLineRGB-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; scanline: SIGNED32): PtrLineRGB;
	GetScanLineRGBA-: PROCEDURE {PlatformCC} (dib: FIBITMAP; scanline: SIGNED32): PtrLineRGBA;
	GetScanLine16-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; scanline: SIGNED32):PtrFISINT16;
	GetScanLine32-: PROCEDURE {PlatformCC} (dib: FIBITMAP; scanline: SIGNED32): PtrFIINT32;
	GetScanLineFloat-: PROCEDURE {PlatformCC} (dib: FIBITMAP; scanline: SIGNED32): PtrFIFLOAT;
	GetScanLineDouble-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; scanline: SIGNED32): PtrFIDOUBLE;
	GetScanLineComplex-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; scanline: SIGNED32):PtrFICOMPLEX;
	GetScanLineFRGB16-: PROCEDURE  {PlatformCC}  (dib: FIBITMAP; scanline: SIGNED32): PtrFIRGB16;
	GetScanLineFRGBA16-: PROCEDURE {PlatformCC} (dib: FIBITMAP; scanline: SIGNED32): PtrFIRGBA16;
	GetScanLineFRGBF-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; scanline: SIGNED32): PtrFIRGBF;
	GetScanLineFRGBAF-: PROCEDURE {PlatformCC} (dib: FIBITMAP; scanline: SIGNED32): PtrFIRGBAF;

	(* DIB info routines -------------------------------- *)
	GetColorsUsed-: PROCEDURE {PlatformCC}  (dib: FIBITMAP): SIGNED32;
	GetBPP-: PROCEDURE {PlatformCC}  (dib: FIBITMAP): SIGNED32;
	GetWidth-: PROCEDURE {PlatformCC}  (dib: FIBITMAP): SIGNED32;
	GetHeight-: PROCEDURE {PlatformCC}  (dib: FIBITMAP): SIGNED32;
	GetLine-: PROCEDURE {PlatformCC}  (dib: FIBITMAP): SIGNED32;
	GetPitch-: PROCEDURE {PlatformCC}  (dib: FIBITMAP): SIGNED32;
	GetDIBSize-: PROCEDURE {PlatformCC}  (dib: FIBITMAP): SIGNED32;
	GetMemorySize-: PROCEDURE {PlatformCC} (dib: FIBITMAP): SIGNED32;
	GetPalette-: PROCEDURE {PlatformCC}  (dib: FIBITMAP): PtrPALETTE;	
	GetDotsPerMeterX-: PROCEDURE {PlatformCC} (dib: FIBITMAP): SIGNED32;
	GetDotsPerMeterY-: PROCEDURE {PlatformCC} (dib: FIBITMAP): SIGNED32;
	SetDotsPerMeterX-: PROCEDURE {PlatformCC} (dib: FIBITMAP; res: SIGNED32);
	SetDotsPerMeterY-: PROCEDURE {PlatformCC} (dib: FIBITMAP; res: SIGNED32);
	GetInfoHeader-: PROCEDURE {PlatformCC} (dib: FIBITMAP): PtrBITMAPINFOHEADER;
	GetInfo-: PROCEDURE {PlatformCC} (dib: FIBITMAP): PtrBITMAPINFO;
	GetColorType-: PROCEDURE {PlatformCC} (dib: FIBITMAP): SIGNED32;
	GetRedMask-: PROCEDURE {PlatformCC} (dib: FIBITMAP): SIGNED32;
	GetGreenMask-: PROCEDURE {PlatformCC} (dib: FIBITMAP): SIGNED32;
	GetBlueMask-: PROCEDURE {PlatformCC} (dib: FIBITMAP): SIGNED32;
	GetTransparencyCount-: PROCEDURE {PlatformCC} (dib: FIBITMAP): SIGNED32;
	GetTransparencyTable-: PROCEDURE {PlatformCC} (dib: FIBITMAP): SIGNED32;
	SetTransparent-: PROCEDURE {PlatformCC} (dib: FIBITMAP; enabled: BOOLEAN);
	SetTransparencyTable-: PROCEDURE {PlatformCC} (dib: FIBITMAP; table: ADDRESS; count: SIGNED32);
	IsTransparent-: PROCEDURE {PlatformCC} (dib: FIBITMAP): BOOLEAN;
	SetTransparentIndex-: PROCEDURE {PlatformCC} (dib:FIBITMAP; index: SIGNED32);
	GetTransparentIndex-: PROCEDURE {PlatformCC} (dib:FIBITMAP): SIGNED32;
	HasBackgroundColor-: PROCEDURE {PlatformCC} (dib: FIBITMAP): BOOLEAN;
	GetBackgroundColor-: PROCEDURE {PlatformCC} (dib: FIBITMAP; VAR bkcolor: RGBQUAD): BOOLEAN;
	SetBackgroundColor-: PROCEDURE {PlatformCC} (dib: FIBITMAP;  CONST bkcolor: RGBQUAD): BOOLEAN;
	GetThumbnail-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	SetThumbnail-: PROCEDURE  {PlatformCC} (dib: FIBITMAP;  thumbnail: FIBITMAP): BOOLEAN;
	
	(* ICC profile routines -------------------------------- *)

	GetICCProfile-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIICCPROFILE;
	CreateICCProfile-: PROCEDURE {PlatformCC} (dib: FIBITMAP; data: ADDRESS; size: SIGNED32): FIICCPROFILE;
	DestroyICCProfile-: PROCEDURE {PlatformCC} (dib: FIBITMAP);

	(* Line Conversion Routines : not translated yet -------------------------------- *)

	(*  Smart conversion routines -------------------------------- *)
	ConvertTo4Bits-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	ConvertTo8Bits-: PROCEDURE  {PlatformCC}  (dib: FIBITMAP): FIBITMAP;
	ConvertToGreyscale-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	ConvertTo16Bits555-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	ConvertTo16Bits565-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	ConvertTo24Bits-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	ConvertTo32Bits-: PROCEDURE {PlatformCC}  (dib: FIBITMAP): FIBITMAP;
	ColorQuantize-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; quantize: IMAGE_QUANTIZE): FIBITMAP;
	ColorQuantizeEx-: PROCEDURE {PlatformCC} (dib: FIBITMAP; quantize: IMAGE_QUANTIZE; PaletteSize: SIGNED32; ReserveSize: SIGNED32; ReservePalette: RGBQUAD): FIBITMAP;
	Threshold-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; T: SIGNED8): FIBITMAP;
	Dither-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; algorithm: IMAGE_DITHER): FIBITMAP;
	ConvertFromRawBits-: PROCEDURE {PlatformCC} (bits: ADDRESS; width, height, pitch: SIGNED32; bpp, red_mask, green_mask, blue_mask: SIGNED32; topdown: BOOLEAN): FIBITMAP;
	ConvertFromRawBitsEx-: PROCEDURE {PlatformCC} (copySource: BOOLEAN; bits: ADDRESS; type: IMAGE_TYPE; width, height, pitch: SIGNED32; bpp, red_mask, green_mask, blue_mask: SIGNED32;  topdown: BOOLEAN): FIBITMAP;
	ConvertToRawBits-: PROCEDURE {PlatformCC} (bits: ADDRESS; dib: FIBITMAP; pitch: SIGNED32; bpp, red_mask, green_mask, blue_mask: SIGNED32; topdown: BOOLEAN);
	ConvertToFloat-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	ConvertToRGBF-: PROCEDURE {PlatformCC}  (dib: FIBITMAP): FIBITMAP;
	ConvertToRGBAF- : PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	ConvertToUINT16-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	ConvertToRGB16-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	ConvertToRGBA16-: PROCEDURE {PlatformCC} (dib: FIBITMAP): FIBITMAP;
	ConvertToStandardType-: PROCEDURE {PlatformCC}  (src: FIBITMAP; scale_linear: BOOLEAN): FIBITMAP;
	ConvertToType-: PROCEDURE {PlatformCC}  (src: FIBITMAP; dst_type: IMAGE_TYPE; scale_linear: BOOLEAN): FIBITMAP;

	(* Tone mapping operators *)
	ToneMapping-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; tmo: IMAGE_TMO; first_param, second_param: FLOAT64): FIBITMAP;
	TmoDrago03-: PROCEDURE {PlatformCC}  (src: FIBITMAP; gamma, exposure: FLOAT64): FIBITMAP;

	TmoReinhard05-: PROCEDURE {PlatformCC}  (src: FIBITMAP; intensity, contrast: FLOAT64): FIBITMAP;
	TmoReinhard05Ex-: PROCEDURE {PlatformCC} (src: FIBITMAP; intensity, contrast, adaptation, color_correction: FLOAT64): FIBITMAP;
	TmoFattal02-: PROCEDURE {PlatformCC} (src: FIBITMAP; color_saturation,  attenuation: FLOAT64): FIBITMAP;
	
	(* ZLib interface -------------------------------- *)

	ZLibCompress-: PROCEDURE {PlatformCC} (target: ADDRESS; target_size: SIGNED32; source: ADDRESS; source_size: SIGNED32): SIGNED32;
	ZLibUncompress-: PROCEDURE {PlatformCC} (target: ADDRESS; target_size: SIGNED32; source: ADDRESS; source_size: SIGNED32): SIGNED32;
	ZLibGZip-: PROCEDURE {PlatformCC} (target: ADDRESS; target_size: SIGNED32; source: ADDRESS; source_size: SIGNED32): SIGNED32;
	ZLibGUnzip-: PROCEDURE {PlatformCC} (target: ADDRESS; target_size: SIGNED32; source: ADDRESS; source_size: SIGNED32): SIGNED32;
	ZLibCRC32-: PROCEDURE {PlatformCC} (crc: SIGNED32; source: ADDRESS; source_size: SIGNED32): SIGNED32;

	(*   Metadata routines -------------------------------- *)
	(* tag creation / destruction*)
	CreateTag- : PROCEDURE {PlatformCC} (): FITAG;
	DeleteTag-: PROCEDURE {PlatformCC} (tag: FITAG);
	CloneTag-: PROCEDURE {PlatformCC} (tag: FITAG): FITAG;

	 (* tag getters and setters *)
	getTagKey-: PROCEDURE {PlatformCC} (tag: FITAG): ADDRESS;
	getTagDescription-: PROCEDURE {PlatformCC} (tag: FITAG): ADDRESS;
	GetTagID-: PROCEDURE {PlatformCC} (tag: FITAG): SIGNED32;
	GetTagType-: PROCEDURE {PlatformCC} (tag: FITAG): IMAGE_MDTYPE;
	GetTagCount-: PROCEDURE {PlatformCC} (tag: FITAG): SIGNED32;
	GetTagLength-: PROCEDURE {PlatformCC} (tag: FITAG): SIGNED32;
	GetTagValue-: PROCEDURE {PlatformCC} (tag: FITAG): ADDRESS;
	SetTagKey-: PROCEDURE {PlatformCC} (tag: FITAG; CONST key: ARRAY OF CHAR): BOOLEAN;
	SetTagDescription-: PROCEDURE {PlatformCC} (tag: FITAG; CONST description: ARRAY OF CHAR): BOOLEAN;
	SetTagID-: PROCEDURE {PlatformCC} (tag: FITAG; id: SIGNED32): BOOLEAN;
	SetTagType-: PROCEDURE {PlatformCC} (tag: FITAG; atype: IMAGE_MDTYPE): BOOLEAN;
	SetTagCount-: PROCEDURE {PlatformCC} (tag: FITAG; count: SIGNED32): BOOLEAN;
	SetTagLength-: PROCEDURE {PlatformCC} (tag: FITAG; length: SIGNED32): BOOLEAN;
	SetTagValue-: PROCEDURE {PlatformCC} (tag: FITAG; value: ADDRESS): BOOLEAN;

	(* iterator*)
	FindFirstMetadata-: PROCEDURE {PlatformCC} (model: IMAGE_MDMODEL; dib: FIBITMAP; VAR tag: FITAG): FIMETADATA;
	FindNextMetadata-: PROCEDURE {PlatformCC} (mdhandle: FIMETADATA; VAR tag: FITAG): BOOLEAN;
	FindCloseMetadata-: PROCEDURE {PlatformCC} (mdhandle: FIMETADATA);

	 (* metadata setter and getter *)
	SetMetadata-: PROCEDURE {PlatformCC} (model: IMAGE_MDMODEL; dib: FIBITMAP; CONST key: ARRAY OF CHAR; tag: FITAG): BOOLEAN;
	GetMetadata-: PROCEDURE {PlatformCC} (model: IMAGE_MDMODEL; dib: FIBITMAP; CONST key: ARRAY OF CHAR; VAR tag: FITAG): BOOLEAN;
	SetMetadataKeyValue-: PROCEDURE {PlatformCC} (model: IMAGE_MDMODEL; dib: FIBITMAP; CONST key, value: ARRAY OF CHAR): BOOLEAN;

	(* helpers *)
	GetMetadataCount-: PROCEDURE {PlatformCC} (model: IMAGE_MDMODEL; dib: FIBITMAP): SIGNED32;
	CloneMetadata-: PROCEDURE {PlatformCC} ( dst, src: FIBITMAP): BOOLEAN;
	 (* tag to C string conversion *)
	tagToString-: PROCEDURE {PlatformCC} (model: IMAGE_MDMODEL; tag: FITAG; make: ADDRESS): ADDRESS;
	

 (*  --------------------------------------------------------------------------
	JPEG lossless transformation routines
	-------------------------------------------------------------------------- *)
	JPEGTransform-: PROCEDURE {PlatformCC} (CONST srcfile, dstfile: ARRAY OF CHAR; operation: IMAGE_JPEG_OPERATION; perfect: BOOLEAN): BOOLEAN;
	JPEGTransformU-: PROCEDURE {PlatformCC} (CONST srcfile, dstfile: ARRAY OF CHAR; operation: IMAGE_JPEG_OPERATION; perfect: BOOLEAN):  BOOLEAN;
	JPEGCrop-: PROCEDURE {PlatformCC} (CONST srcfile, dstfile: ARRAY OF CHAR; left, top, right, bottom: SIGNED32): BOOLEAN;
	JPEGCropU-: PROCEDURE {PlatformCC} (CONST srcfile, dstfile: ARRAY OF CHAR;  left,  top, right, bottom: SIGNED32): BOOLEAN;

(*
	JPEGTransformFromHandle-: PROCEDURE {PlatformCC}(FreeImageIO* src_io, fi_handle src_handle, FreeImageIO* dst_io, fi_handle dst_handle; operation: IMAGE_JPEG_OPERATION; VAR left, top, right, bottom: SIGNED32; perfect: BOOLEAN): BOOLEAN;
*)
	JPEGTransformCombined-: PROCEDURE {PlatformCC} (CONST srcfile, destfile: ARRAY OF CHAR; operation: IMAGE_JPEG_OPERATION; VAR left, top, right, bottom: SIGNED32; perfect: BOOLEAN): BOOLEAN;
	JPEGTransformCombinedU-: PROCEDURE {PlatformCC} (CONST srcfile, dstfile: ARRAY OF CHAR; operation: IMAGE_JPEG_OPERATION; VAR left, top, right, bottom: SIGNED32; perfect: BOOLEAN): BOOLEAN;
	JPEGTransformCombinedFromMemory-: PROCEDURE {PlatformCC} (srcstream,  dststream: FIMEMORY; operation: IMAGE_JPEG_OPERATION; VAR left, top, right, bottom:SIGNED32; perfect: BOOLEAN): BOOLEAN;

	(* Image manipulation toolkit -------------------------------- *)
		(* rotation and flipping *)
	(*  @deprecated see FreeImage_Rotate *)
	RotateClassic-: PROCEDURE {PlatformCC} (dib: FIBITMAP; angle: FLOAT64): FIBITMAP;
	Rotate-:  PROCEDURE {PlatformCC}(dib: FIBITMAP; angle: FLOAT64; bkcolor: ADDRESS): FIBITMAP;

	RotateEx-: PROCEDURE {PlatformCC} (dib: FIBITMAP; angle: FLOAT64; x_shift, y_shift, x_origin, y_origin: FLOAT64; use_mask: BOOLEAN): FIBITMAP;
	FlipHorizontal-: PROCEDURE {PlatformCC} (dib: FIBITMAP): BOOLEAN;
	FlipVertical-: PROCEDURE {PlatformCC}(dib: FIBITMAP): BOOLEAN;

		(* upsampling / downsampling *)
	Rescale-: PROCEDURE {PlatformCC} (dib: FIBITMAP; dst_width, dst_height: SIGNED32; filter: IMAGE_FILTER): FIBITMAP;
	MakeThumbnail-:  PROCEDURE {PlatformCC} (dib: FIBITMAP; max_pixel_size: SIGNED32; convert: BOOLEAN): FIBITMAP;	
	RescaleRect-: PROCEDURE {PlatformCC} (dib: FIBITMAP; dst_width, dst_height, left, top, right, bottom: SIGNED32; filter: IMAGE_FILTER; flags: SIGNED32): FIBITMAP;

		(* color manipulation routines (point operations)*)
	AdjustCurve-: PROCEDURE {PlatformCC} (dib: FIBITMAP;  LUT: ADDRESS; (* ARRAY OF CHAR *) channel: IMAGE_COLOR_CHANNEL): BOOLEAN;
	AdjustGamma-: PROCEDURE {PlatformCC} (dib: FIBITMAP; gamma: FLOAT64): BOOLEAN;
	AdjustBrightness-: PROCEDURE {PlatformCC} (dib: FIBITMAP; percentage: FLOAT64): BOOLEAN;
	AdjustContrast-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; percentage: FLOAT64): BOOLEAN;
	Invert-: PROCEDURE {PlatformCC} (dib: FIBITMAP): BOOLEAN;
	GetHistogram-: PROCEDURE {PlatformCC} (dib: FIBITMAP; histo: ADDRESS; (* ARRAY OF SIGNED32;*)  channel: IMAGE_COLOR_CHANNEL): BOOLEAN;
	GetAdjustColorsLookupTable-: PROCEDURE {PlatformCC} (VAR LUT: Palette; brightness,  contrast,  gamma: FLOAT64; invert: BOOLEAN): SIGNED32;
	AdjustColors-: PROCEDURE {PlatformCC} (dib: FIBITMAP; brightness, contrast, gamma: FLOAT64; invert: BOOLEAN);
	ApplyColorMapping-: PROCEDURE {PlatformCC} (dib: FIBITMAP; VAR srccolors, dstcolors: Palette; count: SIGNED32;  ignore_alpha, swap: SIGNED32): SIGNED32;
	SwapColors-: PROCEDURE {PlatformCC} (dib: FIBITMAP; VAR  color_a, color_b: Palette ; ignore_alpha: BOOLEAN): SIGNED32;
	ApplyPaletteIndexMapping-: PROCEDURE {PlatformCC} (dib: FIBITMAP; VAR  srcindices,	dstindices: LUT; count: SIGNED32;swap: BOOLEAN): SIGNED32;
	SwapPaletteIndices-: PROCEDURE {PlatformCC} (dib: FIBITMAP; VAR index_a, index_b: LUT): SIGNED32;

	(* channel processing routines -------------------------------- *)
	GetChannel-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; channel: IMAGE_COLOR_CHANNEL): FIBITMAP;
	SetChannel-: PROCEDURE {PlatformCC}  (dib: FIBITMAP; dib8: FIBITMAP; channel: IMAGE_COLOR_CHANNEL): BOOLEAN;
	GetComplexChannel-: PROCEDURE {PlatformCC} (dib: FIBITMAP; channel: IMAGE_COLOR_CHANNEL): FIBITMAP;
	SetComplexChannel-: PROCEDURE {PlatformCC} (dst: FIBITMAP; src: FIBITMAP; channel: IMAGE_COLOR_CHANNEL): BOOLEAN;

	(* copy / paste / composite routines -------------------------------- *)
	Copy-: PROCEDURE {PlatformCC} (dib: FIBITMAP; left, top, right, bottom: SIGNED32): FIBITMAP;
	Paste-: PROCEDURE {PlatformCC} (dst: FIBITMAP; src: FIBITMAP; left, top, alpha: SIGNED32): BOOLEAN;
	CreateView-: PROCEDURE {PlatformCC} (dib: FIBITMAP; left, top, right, bottom: SIGNED32): FIBITMAP;
	Composite-: PROCEDURE {PlatformCC} (fg: FIBITMAP; useFileBkg: BOOLEAN; appBkColor: RGBQUAD; bg: FIBITMAP): FIBITMAP;
	PreMultiplyWithAlpha-: PROCEDURE {PlatformCC} (dib: FIBITMAP): BOOLEAN;

	(*  background filling routines -------------------------------- *)
	FillBackground-: PROCEDURE {PlatformCC} (dib: FIBITMAP ;  color: SIGNED32; options: SIGNED32): BOOLEAN;
	EnlargeCanvas-: PROCEDURE {PlatformCC} (src: FIBITMAP;   left,  top, right,  bottom: SIGNED32; color: SIGNED32;  options: SIGNED32): FIBITMAP;
	AllocateEx-: PROCEDURE {PlatformCC} (width, height, bpp: SIGNED32; color: ADDRESS;  options : SIGNED32; palette: PtrPALETTE; red_mask, green_mask, blue_mask: SIGNED32): FIBITMAP;
	AllocateExT-: PROCEDURE {PlatformCC} (type: IMAGE_TYPE;  width,  height,  bpp: SIGNED32;  color: ADDRESS; options: SIGNED32; palette: PtrPALETTE; red_mask, green_mask, blue_mask: SIGNED32): FIBITMAP;

	(* miscellaneous algorithms -------------------------------- *)
	MultigridPoissonSolver-: PROCEDURE {PlatformCC} (Laplacian: FIBITMAP; ncycle:SIGNED32): FIBITMAP;

PROCEDURE GetProcAddress*( lib: HostLibs.LibHandle;  CONST procName: ARRAY OF CHAR;  adr: ADDRESS );
VAR res: BOOLEAN;
BEGIN
	res := HostLibs.GetProcedure(lib, procName, adr);
	IF adr = NIL THEN
		KernelLog.String("NOT FOUND:  "); KernelLog.String(procName); KernelLog.Ln; 
	END;
END GetProcAddress;

PROCEDURE InitFunctions;
VAR res: BOOLEAN;
BEGIN
	res := HostLibs.LoadLibrary(libname, lib);

	ASSERT(res,102);

	(* Init / Error routines *)
(*	GetProcAddress(lib, "FreeImage_Initialise", ADDRESSOF( Initialise ));
	GetProcAddress(lib, "FreeImage_DeInitialise", ADDRESSOF( DeInitialise ));
*)
#IF UNIX OR (WIN & AMD64) THEN
	(* Version routines*)
	GetProcAddress(lib, "FreeImage_GetVersion", ADDRESSOF( getVersion ));
	GetProcAddress(lib, "FreeImage_GetCopyrightMessage", ADDRESSOF( getCopyrightMessage ));
	(* Message output functions *)
	GetProcAddress(lib, "FreeImage_SetOutputMessage", ADDRESSOF( SetOutputMessage ));
	GetProcAddress(lib, "FreeImage_SetOutputMessageStdCall", ADDRESSOF( SetOutputMessageStdCall ));
	
	(* Allocate / Clone / Unload routines*)
	GetProcAddress(lib, "FreeImage_Allocate", ADDRESSOF( Allocate ));
	GetProcAddress(lib, "FreeImage_AllocateT", ADDRESSOF( AllocateT ));
	GetProcAddress(lib, "FreeImage_Clone", ADDRESSOF( Clone ));
	GetProcAddress(lib, "FreeImage_Unload", ADDRESSOF( Unload ));
	
	(* Header loading routines *)
	GetProcAddress(lib, "FreeImage_HasPixels", ADDRESSOF( HasPixels ));
	
	(* Load/Save routines *)	
	GetProcAddress(lib, "FreeImage_Load", ADDRESSOF( Load ));
	GetProcAddress(lib, "FreeImage_LoadU", ADDRESSOF( LoadU ));

	GetProcAddress(lib, "FreeImage_Save", ADDRESSOF( Save ));
	GetProcAddress(lib, "FreeImage_SaveU", ADDRESSOF( SaveU ));

	(* Memory I/O stream routines *)
	GetProcAddress(lib, "FreeImage_OpenMemory", ADDRESSOF( OpenMemory));
	GetProcAddress(lib, "FreeImage_CloseMemory", ADDRESSOF( CloseMemory));
	GetProcAddress(lib, "FreeImage_LoadFromMemory", ADDRESSOF( LoadFromMemory));
	GetProcAddress(lib, "FreeImage_SaveToMemory", ADDRESSOF( SaveToMemory));
	GetProcAddress(lib, "FreeImage_TellMemory", ADDRESSOF( TellMemory));
	GetProcAddress(lib, "FreeImage_SeekMemory", ADDRESSOF( SeekMemory));
	GetProcAddress(lib, "FreeImage_AcquireMemory", ADDRESSOF( AcquireMemory));
	GetProcAddress(lib, "FreeImage_ReadMemory", ADDRESSOF( ReadMemory));
	GetProcAddress(lib, "FreeImage_WriteMemory", ADDRESSOF( WriteMemory));
	GetProcAddress(lib, "FreeImage_LoadMultiBitmapFromMemory", ADDRESSOF( LoadMultiBitmapFromMemory));
	GetProcAddress(lib, "FreeImage_SaveMultiBitmapToMemory", ADDRESSOF( SaveMultiBitmapToMemory));
	
	(* Plugin Interface *)
	GetProcAddress(lib, "FreeImage_GetFIFCount", ADDRESSOF( GetFIFCount));
	GetProcAddress(lib, "FreeImage_SetPluginEnabled", ADDRESSOF( SetPluginEnabled));
	GetProcAddress(lib, "FreeImage_IsPluginEnabled", ADDRESSOF( IsPluginEnabled));
	GetProcAddress(lib, "FreeImage_GetFIFFromFormat", ADDRESSOF( GetFIFFromFormat));
	GetProcAddress(lib, "FreeImage_GetFIFFromMime", ADDRESSOF( GetFIFFromMime));
	GetProcAddress(lib, "FreeImage_GetFormatFromFIF", ADDRESSOF( getFormatFromFIF));
	GetProcAddress(lib, "FreeImage_GetFIFExtensionList", ADDRESSOF( getFIFExtensionList));
	GetProcAddress(lib, "FreeImage_GetFIFDescription", ADDRESSOF( getFIFDescription));
	GetProcAddress(lib, "FreeImage_GetFIFRegExpr", ADDRESSOF( getFIFRegExpr));
	GetProcAddress(lib, "FreeImage_GetFIFFromFilename", ADDRESSOF( GetFIFFromFilename));
	GetProcAddress(lib, "FreeImage_GetFIFFromFilenameU", ADDRESSOF( GetFIFFromFilenameU));
	GetProcAddress(lib, "FreeImage_FIFSupportsReading", ADDRESSOF( FIFSupportsReading));
	GetProcAddress(lib, "FreeImage_FIFSupportsWriting", ADDRESSOF( FIFSupportsWriting));
	GetProcAddress(lib, "FreeImage_FIFSupportsExportBPP", ADDRESSOF( FIFSupportsExportBPP));
	GetProcAddress(lib, "FreeImage_FIFSupportsExportType", ADDRESSOF( FIFSupportsExportType));
	GetProcAddress(lib, "FreeImage_FIFSupportsICCProfiles", ADDRESSOF( FIFSupportsICCProfiles));
	GetProcAddress(lib, "FreeImage_FIFSupportsNoPixels", ADDRESSOF( FIFSupportsNoPixels));
	
	(* Multipaging interface *)
	GetProcAddress(lib, "FreeImage_OpenMultiBitmap", ADDRESSOF( OpenMultiBitmap));
	GetProcAddress(lib, "FreeImage_OpenMultiBitmapFromHandle", ADDRESSOF( OpenMultiBitmapFromHandle));
	GetProcAddress(lib, "FreeImage_SaveMultiBitmapToHandle", ADDRESSOF( SaveMultiBitmapToHandle));
	GetProcAddress(lib, "FreeImage_CloseMultiBitmap", ADDRESSOF( CloseMultiBitmap));
	GetProcAddress(lib, "FreeImage_GetPageCount", ADDRESSOF( GetPageCount));
	GetProcAddress(lib, "FreeImage_AppendPage", ADDRESSOF( AppendPage));
	GetProcAddress(lib, "FreeImage_InsertPage", ADDRESSOF( InsertPage));
	GetProcAddress(lib, "FreeImage_DeletePage", ADDRESSOF( DeletePage));
	GetProcAddress(lib, "FreeImage_LockPage", ADDRESSOF( LockPage));
	GetProcAddress(lib, "FreeImage_UnlockPage", ADDRESSOF( UnlockPage));
	GetProcAddress(lib, "FreeImage_MovePage", ADDRESSOF( MovePage));
	GetProcAddress(lib, "FreeImage_GetLockedPageNumbers", ADDRESSOF( GetLockedPageNumbers));

	(* Filetype request routines *)
	GetProcAddress(lib, "FreeImage_GetFileType", ADDRESSOF( GetFileType));
	GetProcAddress(lib, "FreeImage_GetFileTypeU", ADDRESSOF( GetFileTypeU));
	GetProcAddress(lib, "FreeImage_GetFileTypeFromMemory", ADDRESSOF( GetFileTypeFromMemory));
	GetProcAddress(lib, "FreeImage_GetFileTypeFromHandle", ADDRESSOF( GetFileTypeFromHandle));

	(* Image type request routine *)	
	GetProcAddress(lib, "FreeImage_GetImageType", ADDRESSOF( GetImageType));
	
	(* FreeImage helper routines *)
	GetProcAddress(lib, "FreeImage_IsLittleEndian", ADDRESSOF( IsLittleEndian));
	GetProcAddress(lib, "FreeImage_LookupX11Color", ADDRESSOF( LookupX11Color));
	GetProcAddress(lib, "FreeImage_LookupSVGColor", ADDRESSOF( LookupSVGColor));
		
	(* Pixel access routines *)
	GetProcAddress(lib, "FreeImage_GetBits", ADDRESSOF( GetBits));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLine));
	
	GetProcAddress(lib, "FreeImage_GetPixelIndex", ADDRESSOF( GetPixelIndex));
	GetProcAddress(lib, "FreeImage_GetPixelColor", ADDRESSOF( GetPixelColor));
	GetProcAddress(lib, "FreeImage_SetPixelIndex", ADDRESSOF( SetPixelIndex));
	GetProcAddress(lib, "FreeImage_SetPixelColor", ADDRESSOF( SetPixelColor));

	(*! --- wrapper functions, Necati. --- *)
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLineRGB));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLineRGBA));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLine16));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLine32));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLineFloat));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLineDouble));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLineComplex));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLineFRGB16));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLineFRGBA16));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLineFRGBF));
	GetProcAddress(lib, "FreeImage_GetScanLine", ADDRESSOF( GetScanLineFRGBAF));
	(* --------------------------------- *)

	(* DIB info routines *)
	GetProcAddress(lib, "FreeImage_GetColorsUsed", ADDRESSOF( GetColorsUsed));
	GetProcAddress(lib, "FreeImage_GetBPP", ADDRESSOF( GetBPP));
	GetProcAddress(lib, "FreeImage_GetWidth", ADDRESSOF( GetWidth));
	GetProcAddress(lib, "FreeImage_GetHeight", ADDRESSOF( GetHeight));
	GetProcAddress(lib, "FreeImage_GetLine", ADDRESSOF( GetLine));
	GetProcAddress(lib, "FreeImage_GetPitch", ADDRESSOF( GetPitch));
	GetProcAddress(lib, "FreeImage_GetDIBSize", ADDRESSOF( GetDIBSize));
	GetProcAddress(lib, "FreeImage_GetMemorySize", ADDRESSOF( GetMemorySize));
	GetProcAddress(lib, "FreeImage_GetPalette", ADDRESSOF( GetPalette));
	GetProcAddress(lib, "FreeImage_GetDotsPerMeterX", ADDRESSOF( GetDotsPerMeterX));
	GetProcAddress(lib, "FreeImage_GetDotsPerMeterY", ADDRESSOF( GetDotsPerMeterY));
	GetProcAddress(lib, "FreeImage_SetDotsPerMeterX", ADDRESSOF( SetDotsPerMeterX));
	GetProcAddress(lib, "FreeImage_SetDotsPerMeterY", ADDRESSOF( SetDotsPerMeterY));
	GetProcAddress(lib, "FreeImage_GetInfoHeader", ADDRESSOF( GetInfoHeader));
	GetProcAddress(lib, "FreeImage_GetInfo", ADDRESSOF( GetInfo));
	GetProcAddress(lib, "FreeImage_GetColorType", ADDRESSOF( GetColorType));
	GetProcAddress(lib, "FreeImage_GetRedMask", ADDRESSOF( GetRedMask));
	GetProcAddress(lib, "FreeImage_GetGreenMask", ADDRESSOF( GetGreenMask));
	GetProcAddress(lib, "FreeImage_GetBlueMask", ADDRESSOF( GetBlueMask));
	GetProcAddress(lib, "FreeImage_GetTransparencyCount", ADDRESSOF( GetTransparencyCount));
	GetProcAddress(lib, "FreeImage_GetTransparencyTable", ADDRESSOF( GetTransparencyTable));
	GetProcAddress(lib, "FreeImage_SetTransparent", ADDRESSOF( SetTransparent));
	GetProcAddress(lib, "FreeImage_SetTransparencyTable", ADDRESSOF( SetTransparencyTable));
	GetProcAddress(lib, "FreeImage_IsTransparent", ADDRESSOF( IsTransparent));
	GetProcAddress(lib, "FreeImage_SetTransparentIndex", ADDRESSOF( SetTransparentIndex));
	GetProcAddress(lib, "FreeImage_GetTransparentIndex", ADDRESSOF( GetTransparentIndex));
	GetProcAddress(lib, "FreeImage_HasBackgroundColor", ADDRESSOF( HasBackgroundColor));
	GetProcAddress(lib, "FreeImage_GetBackgroundColor", ADDRESSOF( GetBackgroundColor));
	GetProcAddress(lib, "FreeImage_SetBackgroundColor", ADDRESSOF( SetBackgroundColor));
	GetProcAddress(lib, "FreeImage_GetThumbnail", ADDRESSOF( GetThumbnail));
	GetProcAddress(lib, "FreeImage_SetThumbnail", ADDRESSOF( SetThumbnail));
	
	(* ICC profile routines *)
	GetProcAddress(lib, "FreeImage_GetICCProfile", ADDRESSOF( GetICCProfile));
	GetProcAddress(lib, "FreeImage_CreateICCProfile", ADDRESSOF( CreateICCProfile));
	GetProcAddress(lib, "FreeImage_DestroyICCProfile", ADDRESSOF( DestroyICCProfile));	

	(* Line conversion routines *)
	
	(*  Smart conversion routines *)
	GetProcAddress(lib, "FreeImage_ConvertTo4Bits", ADDRESSOF( ConvertTo4Bits));
	GetProcAddress(lib, "FreeImage_ConvertTo8Bits", ADDRESSOF( ConvertTo8Bits));
	GetProcAddress(lib, "FreeImage_ConvertToGreyscale", ADDRESSOF( ConvertToGreyscale));
	GetProcAddress(lib, "FreeImage_ConvertTo16Bits555", ADDRESSOF( ConvertTo16Bits555));
	GetProcAddress(lib, "FreeImage_ConvertTo16Bits565", ADDRESSOF( ConvertTo16Bits565));

	GetProcAddress(lib, "FreeImage_ConvertTo24Bits", ADDRESSOF( ConvertTo24Bits));
	GetProcAddress(lib, "FreeImage_ConvertTo32Bits", ADDRESSOF( ConvertTo32Bits));
	GetProcAddress(lib, "FreeImage_ColorQuantize", ADDRESSOF( ColorQuantize));
	GetProcAddress(lib, "FreeImage_ColorQuantizeEx", ADDRESSOF( ColorQuantizeEx));
	GetProcAddress(lib, "FreeImage_Threshold", ADDRESSOF( Threshold));

	GetProcAddress(lib, "FreeImage_Dither", ADDRESSOF( Dither));
	GetProcAddress(lib, "FreeImage_ConvertFromRawBits", ADDRESSOF( ConvertFromRawBits));
	GetProcAddress(lib, "FreeImage_ConvertFromRawBitsEx", ADDRESSOF( ConvertFromRawBitsEx));

	GetProcAddress(lib, "FreeImage_ConvertToRawBits", ADDRESSOF( ConvertToRawBits));
	GetProcAddress(lib, "FreeImage_ConvertToFloat", ADDRESSOF( ConvertToFloat));

	GetProcAddress(lib, "FreeImage_ConvertToRGBF", ADDRESSOF( ConvertToRGBF));
	GetProcAddress(lib, "FreeImage_ConvertToRGBAF", ADDRESSOF( ConvertToRGBAF));

	GetProcAddress(lib, "FreeImage_ConvertToUINT16", ADDRESSOF( ConvertToUINT16));
	GetProcAddress(lib, "FreeImage_ConvertToRGB16", ADDRESSOF( ConvertToRGB16));
	GetProcAddress(lib, "FreeImage_ConvertToRGBA16", ADDRESSOF( ConvertToRGBA16));

	GetProcAddress(lib, "FreeImage_ConvertToStandardType", ADDRESSOF( ConvertToStandardType));
	GetProcAddress(lib, "FreeImage_ConvertToType", ADDRESSOF( ConvertToType));

	(* tone mapping operators *)
	GetProcAddress(lib, "FreeImage_ToneMapping", ADDRESSOF( ToneMapping));
	GetProcAddress(lib, "FreeImage_TmoDrago03", ADDRESSOF( TmoDrago03));
	GetProcAddress(lib, "FreeImage_TmoReinhard05", ADDRESSOF( TmoReinhard05));
	GetProcAddress(lib, "FreeImage_TmoReinhard05Ex", ADDRESSOF( TmoReinhard05Ex));
	GetProcAddress(lib, "FreeImage_TmoFattal02", ADDRESSOF( TmoFattal02));
	
	(* ZLib interface *)
	GetProcAddress(lib, "FreeImage_ZLibCompress", ADDRESSOF( ZLibCompress));
	GetProcAddress(lib, "FreeImage_ZLibUncompress", ADDRESSOF( ZLibUncompress));
	GetProcAddress(lib, "FreeImage_ZLibGZip", ADDRESSOF( ZLibGZip));
	GetProcAddress(lib, "FreeImage_ZLibGUnzip", ADDRESSOF( ZLibGUnzip));
	GetProcAddress(lib, "FreeImage_ZLibCRC32", ADDRESSOF( ZLibCRC32));
	
	(* Metadata routines *)
	(* tag creation / destruction *)
	GetProcAddress(lib, "FreeImage_CreateTag", ADDRESSOF( CreateTag));
	GetProcAddress(lib, "FreeImage_DeleteTag", ADDRESSOF( DeleteTag));
	GetProcAddress(lib, "FreeImage_CloneTag", ADDRESSOF( CloneTag));
	(* tag getters and setters *)
	GetProcAddress(lib, "FreeImage_GetTagKey", ADDRESSOF( getTagKey));
	GetProcAddress(lib, "FreeImage_GetTagDescription", ADDRESSOF( getTagDescription));
	GetProcAddress(lib, "FreeImage_GetTagID", ADDRESSOF( GetTagID));
	GetProcAddress(lib, "FreeImage_GetTagType", ADDRESSOF( GetTagType));
	GetProcAddress(lib, "FreeImage_GetTagCount", ADDRESSOF( GetTagCount));
	GetProcAddress(lib, "FreeImage_GetTagLength", ADDRESSOF( GetTagLength));
	GetProcAddress(lib, "FreeImage_GetTagValue", ADDRESSOF( GetTagValue));
	GetProcAddress(lib, "FreeImage_SetTagKey", ADDRESSOF( SetTagKey));
	GetProcAddress(lib, "FreeImage_SetTagDescription", ADDRESSOF( SetTagDescription));
	GetProcAddress(lib, "FreeImage_SetTagID", ADDRESSOF( SetTagID));
	GetProcAddress(lib, "FreeImage_SetTagType", ADDRESSOF( SetTagType));
	GetProcAddress(lib, "FreeImage_SetTagCount", ADDRESSOF( SetTagCount));
	GetProcAddress(lib, "FreeImage_SetTagLength", ADDRESSOF( SetTagLength));
	GetProcAddress(lib, "FreeImage_SetTagValue", ADDRESSOF( SetTagValue));
	(* iterator *)
	GetProcAddress(lib, "FreeImage_FindFirstMetadata", ADDRESSOF( FindFirstMetadata));
	GetProcAddress(lib, "FreeImage_FindNextMetadata", ADDRESSOF( FindNextMetadata));	
	GetProcAddress(lib, "FreeImage_FindCloseMetadata", ADDRESSOF( FindCloseMetadata));

	(* metadata setter and getter *)
	GetProcAddress(lib, "FreeImage_SetMetadata", ADDRESSOF( SetMetadata));
	GetProcAddress(lib, "FreeImage_GetMetadata", ADDRESSOF( GetMetadata));
	GetProcAddress(lib, "FreeImage_SetMetadataKeyValue", ADDRESSOF( SetMetadataKeyValue));
			
	(*  helpers *)
	GetProcAddress(lib, "FreeImage_GetMetadataCount", ADDRESSOF( GetMetadataCount));	
	GetProcAddress(lib, "FreeImage_CloneMetadata", ADDRESSOF( CloneMetadata));			
	(*  tag to C string conversion *)
	GetProcAddress(lib, "FreeImage_TagToString", ADDRESSOF( tagToString));		

	(* JPEG lossless transformation routines *)
	GetProcAddress(lib, "FreeImage_JPEGTransform", ADDRESSOF( JPEGTransform));
	GetProcAddress(lib, "FreeImage_JPEGTransformU", ADDRESSOF( JPEGTransformU));	
	GetProcAddress(lib, "FreeImage_JPEGCrop", ADDRESSOF( JPEGCrop));
	GetProcAddress(lib, "FreeImage_JPEGCropU", ADDRESSOF( JPEGCropU));

	GetProcAddress(lib, "FreeImage_JPEGTransformCombined", ADDRESSOF( JPEGTransformCombined));
	GetProcAddress(lib, "FreeImage_JPEGTransformCombinedU", ADDRESSOF( JPEGTransformCombinedU));
	GetProcAddress(lib, "FreeImage_JPEGTransformCombinedFromMemory", ADDRESSOF( JPEGTransformCombinedFromMemory));	
	
	(* Image manipulation toolkit *)
	(* rotation and flipping *)
	GetProcAddress(lib, "FreeImage_RotateClassic", ADDRESSOF( RotateClassic));
	GetProcAddress(lib, "FreeImage_Rotate", ADDRESSOF( Rotate));
	GetProcAddress(lib, "FreeImage_RotateEx", ADDRESSOF( RotateEx));
	GetProcAddress(lib, "FreeImage_FlipHorizontal", ADDRESSOF( FlipHorizontal));
	GetProcAddress(lib, "FreeImage_FlipVertical", ADDRESSOF( FlipVertical));
	
	(* upsampling / downsampling *)
	GetProcAddress(lib, "FreeImage_Rescale", ADDRESSOF( Rescale));
	GetProcAddress(lib, "FreeImage_MakeThumbnail", ADDRESSOF( MakeThumbnail));
	GetProcAddress(lib, "FreeImage_RescaleRect", ADDRESSOF( RescaleRect));

	(* color manipulation routines (point operations)*)
	GetProcAddress(lib, "FreeImage_AdjustCurve", ADDRESSOF( AdjustCurve));
	GetProcAddress(lib, "FreeImage_AdjustGamma", ADDRESSOF( AdjustGamma));
	GetProcAddress(lib, "FreeImage_AdjustBrightness", ADDRESSOF( AdjustBrightness));
	GetProcAddress(lib, "FreeImage_AdjustContrast", ADDRESSOF( AdjustContrast));
	GetProcAddress(lib, "FreeImage_Invert", ADDRESSOF( Invert));
	GetProcAddress(lib, "FreeImage_GetHistogram", ADDRESSOF( GetHistogram));
	GetProcAddress(lib, "FreeImage_GetAdjustColorsLookupTable", ADDRESSOF( GetAdjustColorsLookupTable));
	GetProcAddress(lib, "FreeImage_AdjustColors", ADDRESSOF( AdjustColors));
	GetProcAddress(lib, "FreeImage_ApplyColorMapping", ADDRESSOF( ApplyColorMapping));
	GetProcAddress(lib, "FreeImage_SwapColors", ADDRESSOF( SwapColors));
	GetProcAddress(lib, "FreeImage_ApplyPaletteIndexMapping", ADDRESSOF( ApplyPaletteIndexMapping));
	GetProcAddress(lib, "FreeImage_SwapPaletteIndices", ADDRESSOF( SwapPaletteIndices));

	(* channel processing routines*)
	GetProcAddress(lib, "FreeImage_GetChannel", ADDRESSOF( GetChannel));
	GetProcAddress(lib, "FreeImage_SetChannel", ADDRESSOF( SetChannel));
	GetProcAddress(lib, "FreeImage_GetComplexChannel", ADDRESSOF( GetComplexChannel));
	GetProcAddress(lib, "FreeImage_SetComplexChannel", ADDRESSOF( SetComplexChannel));

	(* copy / paste / composite routines*)
	GetProcAddress(lib, "FreeImage_Copy", ADDRESSOF( Copy));
	GetProcAddress(lib, "FreeImage_Paste", ADDRESSOF( Paste));
	GetProcAddress(lib, "FreeImage_CreateView", ADDRESSOF( CreateView));
	GetProcAddress(lib, "FreeImage_Composite", ADDRESSOF( Composite));
	GetProcAddress(lib, "FreeImage_PreMultiplyWithAlpha", ADDRESSOF( PreMultiplyWithAlpha));

	(*  background filling routines *)
	GetProcAddress(lib, "FreeImage_FillBackground", ADDRESSOF( FillBackground));
	GetProcAddress(lib, "FreeImage_EnlargeCanvas", ADDRESSOF( EnlargeCanvas));
	GetProcAddress(lib, "FreeImage_AllocateEx", ADDRESSOF( AllocateEx));
	GetProcAddress(lib, "FreeImage_AllocateExT", ADDRESSOF( AllocateExT));

	(* miscellaneous algorithms*)
	GetProcAddress(lib, "FreeImage_MultigridPoissonSolver", ADDRESSOF( MultigridPoissonSolver));

#ELSIF WIN & I386 THEN  (*! function names different *)

	(* Version routines*)
	GetProcAddress(lib, "_FreeImage_GetVersion@0", ADDRESSOF( getVersion ));
	GetProcAddress(lib, "_FreeImage_GetCopyrightMessage@0", ADDRESSOF( getCopyrightMessage ));
	(* Message output functions *)
	GetProcAddress(lib, "_FreeImage_SetOutputMessage@4", ADDRESSOF( SetOutputMessage ));
	GetProcAddress(lib, "_FreeImage_SetOutputMessageStdCall@4", ADDRESSOF( SetOutputMessageStdCall ));
	
	(* Allocate / Clone / Unload routines*)
	GetProcAddress(lib, "_FreeImage_Allocate@24", ADDRESSOF( Allocate ));
	GetProcAddress(lib, "_FreeImage_AllocateT@28", ADDRESSOF( AllocateT ));
	GetProcAddress(lib, "_FreeImage_Clone@4", ADDRESSOF( Clone ));
	GetProcAddress(lib, "_FreeImage_Unload@4", ADDRESSOF( Unload ));
	
	(* Header loading routines *)
	GetProcAddress(lib, "_FreeImage_HasPixels@4", ADDRESSOF( HasPixels ));
	
	(* Load/Save routines *)	
	GetProcAddress(lib, "_FreeImage_Load@12", ADDRESSOF( Load ));
	GetProcAddress(lib, "_FreeImage_LoadU@12", ADDRESSOF( LoadU ));
	GetProcAddress(lib, "_FreeImage_Save@16", ADDRESSOF( Save ));
	GetProcAddress(lib, "_FreeImage_SaveU@16", ADDRESSOF( SaveU ));

	(* Memory I/O stream routines *)
	GetProcAddress(lib, "_FreeImage_OpenMemory@8", ADDRESSOF( OpenMemory));
	GetProcAddress(lib, "_FreeImage_CloseMemory@4", ADDRESSOF( CloseMemory));
	GetProcAddress(lib, "_FreeImage_LoadFromMemory@12", ADDRESSOF( LoadFromMemory));
	GetProcAddress(lib, "_FreeImage_SaveToMemory@16", ADDRESSOF( SaveToMemory));
	GetProcAddress(lib, "_FreeImage_TellMemory@4", ADDRESSOF( TellMemory));
	GetProcAddress(lib, "_FreeImage_SeekMemory@12", ADDRESSOF( SeekMemory));
	GetProcAddress(lib, "_FreeImage_AcquireMemory@12", ADDRESSOF( AcquireMemory));
	GetProcAddress(lib, "_FreeImage_ReadMemory@16", ADDRESSOF( ReadMemory));
	GetProcAddress(lib, "_FreeImage_WriteMemory@16", ADDRESSOF( WriteMemory));
	GetProcAddress(lib, "_FreeImage_LoadMultiBitmapFromMemory@12", ADDRESSOF( LoadMultiBitmapFromMemory));
	GetProcAddress(lib, "_FreeImage_SaveMultiBitmapToMemory@16", ADDRESSOF( SaveMultiBitmapToMemory));
	
	(* Plugin Interface *)
	GetProcAddress(lib, "_FreeImage_GetFIFCount@0", ADDRESSOF( GetFIFCount));
	GetProcAddress(lib, "_FreeImage_SetPluginEnabled@8", ADDRESSOF( SetPluginEnabled));
	GetProcAddress(lib, "_FreeImage_IsPluginEnabled@4", ADDRESSOF( IsPluginEnabled));
	GetProcAddress(lib, "_FreeImage_GetFIFFromFormat@4", ADDRESSOF( GetFIFFromFormat));
	GetProcAddress(lib, "_FreeImage_GetFIFFromMime@4", ADDRESSOF( GetFIFFromMime));
	GetProcAddress(lib, "_FreeImage_GetFormatFromFIF@4", ADDRESSOF( getFormatFromFIF));
	GetProcAddress(lib, "_FreeImage_GetFIFExtensionList@4", ADDRESSOF( getFIFExtensionList));
	GetProcAddress(lib, "_FreeImage_GetFIFDescription@4", ADDRESSOF( getFIFDescription));
	GetProcAddress(lib, "_FreeImage_GetFIFRegExpr@4", ADDRESSOF( getFIFRegExpr));
	GetProcAddress(lib, "_FreeImage_GetFIFFromFilename@4", ADDRESSOF( GetFIFFromFilename));
	GetProcAddress(lib, "_FreeImage_GetFIFFromFilenameU@4", ADDRESSOF( GetFIFFromFilenameU));
	GetProcAddress(lib, "_FreeImage_FIFSupportsReading@4", ADDRESSOF( FIFSupportsReading));
	GetProcAddress(lib, "_FreeImage_FIFSupportsWriting@4", ADDRESSOF( FIFSupportsWriting));
	GetProcAddress(lib, "_FreeImage_FIFSupportsExportBPP@8", ADDRESSOF( FIFSupportsExportBPP));
	GetProcAddress(lib, "_FreeImage_FIFSupportsExportType@8", ADDRESSOF( FIFSupportsExportType));
	GetProcAddress(lib, "_FreeImage_FIFSupportsICCProfiles@4", ADDRESSOF( FIFSupportsICCProfiles));
	GetProcAddress(lib, "_FreeImage_FIFSupportsNoPixels@4", ADDRESSOF( FIFSupportsNoPixels));
	
	(* Multipaging interface *)
	GetProcAddress(lib, "_FreeImage_OpenMultiBitmap@24", ADDRESSOF( OpenMultiBitmap));
	GetProcAddress(lib, "_FreeImage_OpenMultiBitmapFromHandle@16", ADDRESSOF( OpenMultiBitmapFromHandle));
	GetProcAddress(lib, "_FreeImage_SaveMultiBitmapToHandle@20", ADDRESSOF( SaveMultiBitmapToHandle));
	GetProcAddress(lib, "_FreeImage_CloseMultiBitmap@8", ADDRESSOF( CloseMultiBitmap));
	GetProcAddress(lib, "_FreeImage_GetPageCount@4", ADDRESSOF( GetPageCount));
	GetProcAddress(lib, "_FreeImage_AppendPage@8", ADDRESSOF( AppendPage));
	GetProcAddress(lib, "_FreeImage_InsertPage@12", ADDRESSOF( InsertPage));
	GetProcAddress(lib, "_FreeImage_DeletePage@8", ADDRESSOF( DeletePage));
	GetProcAddress(lib, "_FreeImage_LockPage@8", ADDRESSOF( LockPage));
	GetProcAddress(lib, "_FreeImage_UnlockPage@12", ADDRESSOF( UnlockPage));
	GetProcAddress(lib, "_FreeImage_MovePage@12", ADDRESSOF( MovePage));
	GetProcAddress(lib, "_FreeImage_GetLockedPageNumbers@12", ADDRESSOF( GetLockedPageNumbers));

	(* Filetype request routines *)
	GetProcAddress(lib, "_FreeImage_GetFileType@8", ADDRESSOF( GetFileType));
	GetProcAddress(lib, "_FreeImage_GetFileTypeU@8", ADDRESSOF( GetFileTypeU));
	GetProcAddress(lib, "_FreeImage_GetFileTypeFromMemory@8", ADDRESSOF( GetFileTypeFromMemory));
	GetProcAddress(lib, "_FreeImage_GetFileTypeFromHandle@12", ADDRESSOF( GetFileTypeFromHandle));

	(* Image type request routine *)	
	GetProcAddress(lib, "_FreeImage_GetImageType@4", ADDRESSOF( GetImageType));
	
	(* FreeImage helper routines *)
	GetProcAddress(lib, "_FreeImage_IsLittleEndian@0", ADDRESSOF( IsLittleEndian));
	GetProcAddress(lib, "_FreeImage_LookupX11Color@16", ADDRESSOF( LookupX11Color));
	GetProcAddress(lib, "_FreeImage_LookupSVGColor@16", ADDRESSOF( LookupSVGColor));
		
	(* Pixel access routines *)
	GetProcAddress(lib, "_FreeImage_GetBits@4", ADDRESSOF( GetBits));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLine));
	
	GetProcAddress(lib, "_FreeImage_GetPixelIndex@16", ADDRESSOF( GetPixelIndex));
	GetProcAddress(lib, "_FreeImage_GetPixelColor@16", ADDRESSOF( GetPixelColor));
	GetProcAddress(lib, "_FreeImage_SetPixelIndex@16", ADDRESSOF( SetPixelIndex));
	GetProcAddress(lib, "_FreeImage_SetPixelColor@16", ADDRESSOF( SetPixelColor));

	(*! --- wrapper functions, Necati. --- *)
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLineRGB));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLineRGBA));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLine16));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLine32));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLineFloat));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLineDouble));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLineComplex));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLineFRGB16));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLineFRGBA16));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLineFRGBF));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLineFRGBAF));
	(* --------------------------------- *)

	(* DIB info routines *)
	GetProcAddress(lib, "_FreeImage_GetColorsUsed@4", ADDRESSOF( GetColorsUsed));
	GetProcAddress(lib, "_FreeImage_GetBPP@4", ADDRESSOF( GetBPP));
	GetProcAddress(lib, "_FreeImage_GetWidth@4", ADDRESSOF( GetWidth));
	GetProcAddress(lib, "_FreeImage_GetHeight@4", ADDRESSOF( GetHeight));
	GetProcAddress(lib, "_FreeImage_GetLine@4", ADDRESSOF( GetLine));
	GetProcAddress(lib, "_FreeImage_GetPitch@4", ADDRESSOF( GetPitch));
	GetProcAddress(lib, "_FreeImage_GetDIBSize@4", ADDRESSOF( GetDIBSize));
	GetProcAddress(lib, "_FreeImage_GetMemorySize@4", ADDRESSOF( GetMemorySize));

	GetProcAddress(lib, "_FreeImage_GetPalette@4", ADDRESSOF( GetPalette));
	GetProcAddress(lib, "_FreeImage_GetDotsPerMeterX@4", ADDRESSOF( GetDotsPerMeterX));
	GetProcAddress(lib, "_FreeImage_GetDotsPerMeterY@4", ADDRESSOF( GetDotsPerMeterY));
	GetProcAddress(lib, "_FreeImage_SetDotsPerMeterX@8", ADDRESSOF( SetDotsPerMeterX));
	GetProcAddress(lib, "_FreeImage_SetDotsPerMeterY@8", ADDRESSOF( SetDotsPerMeterY));
	GetProcAddress(lib, "_FreeImage_GetInfoHeader@4", ADDRESSOF( GetInfoHeader));
	GetProcAddress(lib, "_FreeImage_GetInfo@4", ADDRESSOF( GetInfo));
	GetProcAddress(lib, "_FreeImage_GetColorType@4", ADDRESSOF( GetColorType));
	GetProcAddress(lib, "_FreeImage_GetRedMask@4", ADDRESSOF( GetRedMask));
	GetProcAddress(lib, "_FreeImage_GetGreenMask@4", ADDRESSOF( GetGreenMask));
	GetProcAddress(lib, "_FreeImage_GetBlueMask@4", ADDRESSOF( GetBlueMask));
	GetProcAddress(lib, "_FreeImage_GetTransparencyCount@4", ADDRESSOF( GetTransparencyCount));
	GetProcAddress(lib, "_FreeImage_GetTransparencyTable@4", ADDRESSOF( GetTransparencyTable));
	GetProcAddress(lib, "_FreeImage_SetTransparent@8", ADDRESSOF( SetTransparent));
	GetProcAddress(lib, "_FreeImage_SetTransparencyTable@12", ADDRESSOF( SetTransparencyTable));
	GetProcAddress(lib, "_FreeImage_IsTransparent@4", ADDRESSOF( IsTransparent));
	GetProcAddress(lib, "_FreeImage_SetTransparentIndex@8", ADDRESSOF( SetTransparentIndex));
	GetProcAddress(lib, "_FreeImage_GetTransparentIndex@4", ADDRESSOF( GetTransparentIndex));
	GetProcAddress(lib, "_FreeImage_HasBackgroundColor@4", ADDRESSOF( HasBackgroundColor));
	GetProcAddress(lib, "_FreeImage_GetBackgroundColor@8", ADDRESSOF( GetBackgroundColor));
	GetProcAddress(lib, "_FreeImage_SetBackgroundColor@8", ADDRESSOF( SetBackgroundColor));
	GetProcAddress(lib, "_FreeImage_GetThumbnail@4", ADDRESSOF( GetThumbnail));
	GetProcAddress(lib, "_FreeImage_SetThumbnail@8", ADDRESSOF( SetThumbnail));
	
	(* ICC profile routines *)
	GetProcAddress(lib, "_FreeImage_GetICCProfile@4", ADDRESSOF( GetICCProfile));
	GetProcAddress(lib, "_FreeImage_CreateICCProfile@12", ADDRESSOF( CreateICCProfile));
	GetProcAddress(lib, "_FreeImage_DestroyICCProfile@4", ADDRESSOF( DestroyICCProfile));	

	(* Line conversion routines *)
	
	(* Smart conversion routines *)
	GetProcAddress(lib, "_FreeImage_ConvertTo4Bits@4", ADDRESSOF( ConvertTo4Bits));
	GetProcAddress(lib, "_FreeImage_ConvertTo8Bits@4", ADDRESSOF( ConvertTo8Bits));
	GetProcAddress(lib, "_FreeImage_ConvertToGreyscale@4", ADDRESSOF( ConvertToGreyscale));
	GetProcAddress(lib, "_FreeImage_ConvertTo16Bits555@4", ADDRESSOF( ConvertTo16Bits555));
	GetProcAddress(lib, "_FreeImage_ConvertTo16Bits565@4", ADDRESSOF( ConvertTo16Bits565));

	GetProcAddress(lib, "_FreeImage_ConvertTo24Bits@4", ADDRESSOF( ConvertTo24Bits));
	GetProcAddress(lib, "_FreeImage_ConvertTo32Bits@4", ADDRESSOF( ConvertTo32Bits));
	GetProcAddress(lib, "_FreeImage_ColorQuantize@8", ADDRESSOF( ColorQuantize));
	GetProcAddress(lib, "_FreeImage_ColorQuantizeEx@20", ADDRESSOF( ColorQuantizeEx));
	GetProcAddress(lib, "_FreeImage_Threshold@8", ADDRESSOF( Threshold));
	GetProcAddress(lib, "_FreeImage_Dither@8", ADDRESSOF( Dither));
	GetProcAddress(lib, "_FreeImage_ConvertFromRawBits@36", ADDRESSOF( ConvertFromRawBits));
	GetProcAddress(lib, "_FreeImage_ConvertFromRawBitsEx@44", ADDRESSOF( ConvertFromRawBitsEx));
	GetProcAddress(lib, "_FreeImage_ConvertToRawBits@32", ADDRESSOF( ConvertToRawBits));
	GetProcAddress(lib, "_FreeImage_ConvertToFloat@4", ADDRESSOF( ConvertToFloat));
	GetProcAddress(lib, "_FreeImage_ConvertToRGBF@4", ADDRESSOF( ConvertToRGBF));
	GetProcAddress(lib, "_FreeImage_ConvertToRGBAF@4", ADDRESSOF( ConvertToRGBAF));
	GetProcAddress(lib, "_FreeImage_ConvertToUINT16@4", ADDRESSOF( ConvertToUINT16));
	GetProcAddress(lib, "_FreeImage_ConvertToRGB16@4", ADDRESSOF( ConvertToRGB16));
	GetProcAddress(lib, "_FreeImage_ConvertToRGBA16@4", ADDRESSOF( ConvertToRGBA16));
	GetProcAddress(lib, "_FreeImage_ConvertToStandardType@8", ADDRESSOF( ConvertToStandardType));
	GetProcAddress(lib, "_FreeImage_ConvertToType@12", ADDRESSOF( ConvertToType));

	(* tone mapping operators *)
	GetProcAddress(lib, "_FreeImage_ToneMapping@24", ADDRESSOF( ToneMapping));
	GetProcAddress(lib, "_FreeImage_TmoDrago03@20", ADDRESSOF( TmoDrago03));
	GetProcAddress(lib, "_FreeImage_TmoReinhard05@20", ADDRESSOF( TmoReinhard05));
	GetProcAddress(lib, "_FreeImage_TmoReinhard05Ex@36", ADDRESSOF( TmoReinhard05Ex));
	GetProcAddress(lib, "_FreeImage_TmoFattal02@20", ADDRESSOF( TmoFattal02));
	
	(* ZLib interface *)
	GetProcAddress(lib, "_FreeImage_ZLibCompress@16", ADDRESSOF( ZLibCompress));
	GetProcAddress(lib, "_FreeImage_ZLibUncompress@16", ADDRESSOF( ZLibUncompress));
	GetProcAddress(lib, "_FreeImage_ZLibGZip@16", ADDRESSOF( ZLibGZip));
	GetProcAddress(lib, "_FreeImage_ZLibGUnzip@16", ADDRESSOF( ZLibGUnzip));
	GetProcAddress(lib, "_FreeImage_ZLibCRC32@12", ADDRESSOF( ZLibCRC32));
	
	(* Metadata routines *)
	(* tag creation / destruction *)
	GetProcAddress(lib, "_FreeImage_CreateTag@0", ADDRESSOF( CreateTag));
	GetProcAddress(lib, "_FreeImage_DeleteTag@4", ADDRESSOF( DeleteTag));
	GetProcAddress(lib, "_FreeImage_CloneTag@4", ADDRESSOF( CloneTag));
	(* tag getters and setters *)
	GetProcAddress(lib, "_FreeImage_GetTagKey@4", ADDRESSOF( getTagKey));
	GetProcAddress(lib, "_FreeImage_GetTagDescription@4", ADDRESSOF( getTagDescription));
	GetProcAddress(lib, "_FreeImage_GetTagID@4", ADDRESSOF( GetTagID));
	GetProcAddress(lib, "_FreeImage_GetTagType@4", ADDRESSOF( GetTagType));
	GetProcAddress(lib, "_FreeImage_GetTagCount@4", ADDRESSOF( GetTagCount));
	GetProcAddress(lib, "_FreeImage_GetTagLength@4", ADDRESSOF( GetTagLength));
	GetProcAddress(lib, "_FreeImage_GetTagValue@4", ADDRESSOF( GetTagValue));
	GetProcAddress(lib, "_FreeImage_SetTagKey@8", ADDRESSOF( SetTagKey));
	GetProcAddress(lib, "_FreeImage_SetTagDescription@8", ADDRESSOF( SetTagDescription));
	GetProcAddress(lib, "_FreeImage_SetTagID@8", ADDRESSOF( SetTagID));
	GetProcAddress(lib, "_FreeImage_SetTagType@8", ADDRESSOF( SetTagType));
	GetProcAddress(lib, "_FreeImage_SetTagCount@8", ADDRESSOF( SetTagCount));
	GetProcAddress(lib, "_FreeImage_SetTagLength@8", ADDRESSOF( SetTagLength));
	GetProcAddress(lib, "_FreeImage_SetTagValue@8", ADDRESSOF( SetTagValue));
	(* iterator *)
	GetProcAddress(lib, "_FreeImage_FindFirstMetadata@12", ADDRESSOF( FindFirstMetadata));
	GetProcAddress(lib, "_FreeImage_FindNextMetadata@8", ADDRESSOF( FindNextMetadata));	
	GetProcAddress(lib, "_FreeImage_FindCloseMetadata@4", ADDRESSOF( FindCloseMetadata));

	(* metadata setter and getter *)
	GetProcAddress(lib, "_FreeImage_SetMetadata@16", ADDRESSOF( SetMetadata));
	GetProcAddress(lib, "_FreeImage_GetMetadata@16", ADDRESSOF( GetMetadata));
	GetProcAddress(lib, "_FreeImage_SetMetadataKeyValue@16", ADDRESSOF( SetMetadataKeyValue));
				
	(*  helpers *)
	GetProcAddress(lib, "_FreeImage_GetMetadataCount@8", ADDRESSOF( GetMetadataCount));	
	GetProcAddress(lib, "_FreeImage_CloneMetadata@8", ADDRESSOF( CloneMetadata));			
	(*  tag to C string conversion *)
	GetProcAddress(lib, "_FreeImage_TagToString@12", ADDRESSOF( tagToString));		


	(* JPEG lossless transformation routines *)
	GetProcAddress(lib, "_FreeImage_JPEGTransform@16", ADDRESSOF( JPEGTransform));
	GetProcAddress(lib, "_FreeImage_JPEGTransformU@16", ADDRESSOF( JPEGTransformU));
	GetProcAddress(lib, "_FreeImage_JPEGCrop@24", ADDRESSOF( JPEGCrop));
	GetProcAddress(lib, "_FreeImage_JPEGCropU@24", ADDRESSOF( JPEGCropU));

	GetProcAddress(lib, "FreeImage_JPEGTransformCombined@32", ADDRESSOF( JPEGTransformCombined));
	GetProcAddress(lib, "FreeImage_JPEGTransformCombinedU@32", ADDRESSOF( JPEGTransformCombinedU));
	GetProcAddress(lib, "FreeImage_JPEGTransformCombinedFromMemory@32", ADDRESSOF( JPEGTransformCombinedFromMemory));

	(* Image manipulation toolkit *)
	(* rotation and flipping *)
	GetProcAddress(lib, "_FreeImage_RotateClassic@12", ADDRESSOF( RotateClassic));
	GetProcAddress(lib, "_FreeImage_Rotate@16", ADDRESSOF( Rotate));
	GetProcAddress(lib, "_FreeImage_RotateEx@48", ADDRESSOF( RotateEx));
	GetProcAddress(lib, "_FreeImage_FlipHorizontal@4", ADDRESSOF( FlipHorizontal));
	GetProcAddress(lib, "_FreeImage_FlipVertical@4", ADDRESSOF( FlipVertical));
	
	(* upsampling / downsampling *)
	GetProcAddress(lib, "_FreeImage_Rescale@16", ADDRESSOF( Rescale));
	GetProcAddress(lib, "_FreeImage_MakeThumbnail@12", ADDRESSOF( MakeThumbnail));
	GetProcAddress(lib, "_FreeImage_RescaleRect@36", ADDRESSOF( RescaleRect));

	(* color manipulation routines (point operations)*)
	GetProcAddress(lib, "_FreeImage_AdjustCurve@12", ADDRESSOF( AdjustCurve));
	GetProcAddress(lib, "_FreeImage_AdjustGamma@12", ADDRESSOF( AdjustGamma));
	GetProcAddress(lib, "_FreeImage_AdjustBrightness@12", ADDRESSOF( AdjustBrightness));
	GetProcAddress(lib, "_FreeImage_AdjustContrast@12", ADDRESSOF( AdjustContrast));
	GetProcAddress(lib, "_FreeImage_Invert@4", ADDRESSOF( Invert));
	GetProcAddress(lib, "_FreeImage_GetHistogram@12", ADDRESSOF( GetHistogram));
	GetProcAddress(lib, "_FreeImage_GetAdjustColorsLookupTable@32", ADDRESSOF( GetAdjustColorsLookupTable));
	GetProcAddress(lib, "_FreeImage_AdjustColors@32", ADDRESSOF( AdjustColors));
	GetProcAddress(lib, "_FreeImage_ApplyColorMapping@24", ADDRESSOF( ApplyColorMapping));
	GetProcAddress(lib, "_FreeImage_SwapColors@16", ADDRESSOF( SwapColors));
	GetProcAddress(lib, "_FreeImage_ApplyPaletteIndexMapping@20", ADDRESSOF( ApplyPaletteIndexMapping));
	GetProcAddress(lib, "_FreeImage_SwapPaletteIndices@12", ADDRESSOF( SwapPaletteIndices));

	(* channel processing routines*)
	GetProcAddress(lib, "_FreeImage_GetChannel@8", ADDRESSOF( GetChannel));
	GetProcAddress(lib, "_FreeImage_SetChannel@12", ADDRESSOF( SetChannel));
	GetProcAddress(lib, "_FreeImage_GetComplexChannel@8", ADDRESSOF( GetComplexChannel));
	GetProcAddress(lib, "_FreeImage_SetComplexChannel@12", ADDRESSOF( SetComplexChannel));

	(* copy / paste / composite routines*)
	GetProcAddress(lib, "_FreeImage_Copy@20", ADDRESSOF( Copy));
	GetProcAddress(lib, "_FreeImage_Paste@20", ADDRESSOF( Paste));
	GetProcAddress(lib, "_FreeImage_CreateView@20", ADDRESSOF( CreateView));
	GetProcAddress(lib, "_FreeImage_Composite@16", ADDRESSOF( Composite));
	GetProcAddress(lib, "_FreeImage_PreMultiplyWithAlpha@4", ADDRESSOF( PreMultiplyWithAlpha));

	(*  background filling routines *)
	GetProcAddress(lib, "_FreeImage_FillBackground@12", ADDRESSOF( FillBackground));
	GetProcAddress(lib, "_FreeImage_EnlargeCanvas@28", ADDRESSOF( EnlargeCanvas));
	GetProcAddress(lib, "_FreeImage_AllocateEx@36", ADDRESSOF( AllocateEx));
	GetProcAddress(lib, "_FreeImage_AllocateExT@40", ADDRESSOF( AllocateExT));

	(* miscellaneous algorithms*)
	GetProcAddress(lib, "_FreeImage_MultigridPoissonSolver@8", ADDRESSOF( MultigridPoissonSolver));

#END
END InitFunctions;

PROCEDURE OnClose;
VAR res: BOOLEAN;
BEGIN
	res := HostLibs.FreeLibrary(lib);
	IF res THEN
		KernelLog.String(libname); KernelLog.String(" unloaded."); KernelLog.Ln;
	ELSE
		KernelLog.String(libname); KernelLog.String(" NOT unloaded."); KernelLog.Ln;		
	END;
END OnClose;
	
(* utilities  *)
(* Get string from address *)
PROCEDURE GetStringFromAddr*(adr: ADDRESS): Strings.String;
VAR s: POINTER {UNSAFE} TO ARRAY MAX(SIZE) OF CHAR;
	str: Strings.String;
	pos: SIGNED32;
BEGIN
	s := adr;
	pos := 0;
	IF adr # NIL THEN
		WHILE s[pos] # 0X DO INC(pos); END;
		NEW(str, pos + 1);
		pos := 0;
		WHILE s[pos] # 0X DO str[pos] := s[pos]; INC(pos); END;

	ELSE NEW(str, 1);
	END;
	str[pos] := 0X;
	RETURN str;
END GetStringFromAddr;

(** wrapper procedure for getVersion() *)
PROCEDURE GetVersion* (): Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getVersion();
	v := GetStringFromAddr(adr);
	RETURN v;
END GetVersion;

(** wrapper procedure for getCopyrightMessage() *)
PROCEDURE GetCopyrightMessage* (): Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getCopyrightMessage();
	v := GetStringFromAddr(adr);
	RETURN v;
END GetCopyrightMessage;

(** wrapper procedure for getFormatFromFIF *)
PROCEDURE GetFormatFromFIF* (fif: IMAGE_FORMAT): Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getFormatFromFIF(fif);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetFormatFromFIF;

(** wrapper procedure for getFIFExtensionList *)
PROCEDURE GetFIFExtensionList* (fif: IMAGE_FORMAT): Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getFIFExtensionList(fif);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetFIFExtensionList;

(** wrapper procedure for getFIFDescription *)
PROCEDURE GetFIFDescription* (fif: IMAGE_FORMAT): Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getFIFDescription(fif);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetFIFDescription;

(** wrapper procedure for getFIFRegExpr *)
PROCEDURE GetFIFRegExpr* (fif: IMAGE_FORMAT): Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getFIFRegExpr(fif);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetFIFRegExpr;

(** wrapper procedure for getTagKey *)
PROCEDURE GetTagKey* (tag: FITAG): Strings.String;
VAR v: Strings.String;
	adr: ADDRESS;
BEGIN
	adr := getTagKey(tag);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetTagKey;

(** wrapper procedure for getTagDescription *)
PROCEDURE GetTagDescription* (tag: FITAG): Strings.String;
VAR v: Strings.String;
	adr: ADDRESS;
BEGIN
	adr := getTagDescription(tag);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetTagDescription;

(** wrapper procedure for tagToString *)
PROCEDURE TagToString* (model: IMAGE_MDMODEL; tag: FITAG): Strings.String;
VAR v: Strings.String;
	adr: ADDRESS;
BEGIN
	adr := tagToString(model, tag, NIL);
	v := GetStringFromAddr(adr);
	RETURN v;
END TagToString;

(** Utilitiy functions, load file fname as FIBITMAP with flags *)
PROCEDURE LoadImage* (CONST fname: ARRAY OF CHAR; flags: IMAGE_FLAGS): FIBITMAP;
VAR
	type: IMAGE_FORMAT;
	tdib: FIBITMAP;
BEGIN
	type := GetFileType(fname, 0);

	IF type = FIF_UNKNOWN THEN
		KernelLog.String("Unkonwn Format: "); KernelLog.String(fname); 
		KernelLog.Int(type, 5); KernelLog.Ln; 
		type := GetFIFFromFilename(fname)
	END;

	IF (type # FIF_UNKNOWN) & FIFSupportsReading(type) THEN
		(* KernelLog.Int(type, 0); KernelLog.String(" Supported reading: "); KernelLog.Ln; *)
		tdib := Load(type, fname, flags);
		RETURN tdib
	ELSE
		RETURN NIL
	END
END LoadImage;

(** save FITMAP image to a file named fname *)
PROCEDURE SaveImage* (dib: FIBITMAP; CONST fname: ARRAY OF CHAR; flags: IMAGE_FLAGS): BOOLEAN;
VAR
	cansave, success: BOOLEAN;
	fif: IMAGE_FORMAT;
	type: IMAGE_TYPE;
	bpp: SIGNED32;
BEGIN
	success := FALSE;
	fif := GetFIFFromFilename(fname);
	IF fif # FIF_UNKNOWN THEN
		type := GetImageType(dib);
		IF type = FIT_BITMAP THEN
			bpp := GetBPP(dib);
			cansave := FIFSupportsWriting(fif) & FIFSupportsExportBPP(fif, bpp)
		ELSE
			cansave := FIFSupportsExportType(fif, type)
		END;
		IF cansave THEN
			success := Save(fif, dib, fname, flags)
		END
	END;
	RETURN success
END SaveImage;

(* called by FreeImage when error occurs *)
PROCEDURE {PlatformCC} MyOutputMessageFunction(fif: IMAGE_FORMAT; msg: POINTER {UNSAFE} TO ARRAY 1024 OF CHAR);
BEGIN	
	IF msg # NIL THEN
		KernelLog.String("FreeImage ERROR: ");
		KernelLog.String(msg^);
		KernelLog.String(", FIF_FORMAT= "); KernelLog.Int(fif, 0);
		KernelLog.Ln; 
	END;	
END MyOutputMessageFunction;
		
BEGIN
	InitFunctions();
	Modules.InstallTermHandler(OnClose);
	SetOutputMessageStdCall(MyOutputMessageFunction);	
END FreeImageDll.
