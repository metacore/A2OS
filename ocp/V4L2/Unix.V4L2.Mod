MODULE V4L2; (** AUTHOR "fnecati"; PURPOSE "video4linux2 definitions and structures "; *)

IMPORT Unix;
(* NOTE: Some union structures are not translated and tested yet *)

TYPE 
	u64* = UNSIGNED64;
	s64* = SIGNED64;
	u32* = UNSIGNED32;
	s32* = SIGNED32;
	u16* = UNSIGNED16;
	u8* = CHAR;
(* ----------------- *)
(* ioctl.h *)

	(* ioctl command encoding: 32 bits total, command in lower 16 bits,
	 * size of the parameter structure in the lower 14 bits of the
	 * upper 16 bits.
	 * Encoding the size of the parameter structure in the ioctl request
	 * is useful for catching programs compiled with old versions
	 * and to avoid overwriting user space outside the user buffer area.
	 * The highest 2 bits are reserved for indicating the ``access mode''.
	 * NOTE: This limits the max parameter size to 16kB -1 !
	 *)
	
	(*
	 * The following is for compatibility across the various Linux
	 * platforms.  The generic ioctl numbering scheme doesn't really enforce
	 * a type field.  De facto, however, the top 8 bits of the lower 16
	 * bits are indeed used as a type field, so we might just as well make
	 * this explicit here.  Please be sure to use the decoding macros
	 * below from now on.
	 *)
CONST 
	IOC_NRBITS* = 8;
	IOC_TYPEBITS* = 8;
	
	(*
	 * Let any architecture override either of the following before
	 * including this file.
	 *)
	
	IOC_SIZEBITS* =	14;
	IOC_DIRBITS* =	2;
		
	IOC_NRMASK* = LSH(1, IOC_NRBITS)-1;
	IOC_TYPEMASK* = LSH(1 ,IOC_TYPEBITS)-1;
	IOC_SIZEMASK* = LSH(1, IOC_SIZEBITS)-1;
	IOC_DIRMASK* = LSH(1, IOC_DIRBITS)-1;

	IOC_NRSHIFT* = 0;
	IOC_TYPESHIFT* = IOC_NRSHIFT+IOC_NRBITS;
	IOC_SIZESHIFT* = IOC_TYPESHIFT+IOC_TYPEBITS;
	IOC_DIRSHIFT* = IOC_SIZESHIFT+IOC_SIZEBITS;
	
	(*
	 * Direction bits, which any architecture can choose to override
	 * before including this file.
	 *)
	
	IOC_NONE* = 0;
	
	IOC_WRITE* = 1;
	
	IOC_READ* = 2;


(* ----------------- *)

	(*! video2.h *)
	(*
	 * Common stuff for both V4L1 and V4L2
	 * Moved from videodev.h
	 *)
CONST 
	VIDEO_MAX_FRAME* = 32;
	VIDEO_MAX_PLANES* = 8;
	
	(* These defines are V4L1 specific and should not be used with the V4L2 API!
	   They will be removed from this header in the future. *)

	VID_TYPE_CAPTURE* = 1;	(* Can capture *)
	VID_TYPE_TUNER* = 2;	(* Can tune *)
	VID_TYPE_TELETEXT* = 4;	(* Does teletext *)
	VID_TYPE_OVERLAY* = 8;	(* Overlay onto frame buffer *)
	VID_TYPE_CHROMAKEY* = 16;	(* Overlay by chromakey *)
	VID_TYPE_CLIPPING* = 32;	(* Can clip *)
	VID_TYPE_FRAMERAM* = 64;	(* Uses the frame buffer memory *)
	VID_TYPE_SCALES* = 128;	(* Scalable *)
	VID_TYPE_MONOCHROME* = 256;	(* Monochrome only *)
	VID_TYPE_SUBCAPTURE* = 512;	(* Can capture subareas of the image *)
	VID_TYPE_MPEG_DECOxDER* = 1024;	(*! Can decode MPEG streams *)
	VID_TYPE_MPEG_ENCOxDER* = 2048;	(*! Can encode MPEG streams *)
	VID_TYPE_MJPEG_DECOxDER* = 4096;	(*! Can decode MJPEG streams *)
	VID_TYPE_MJPEG_ENCOxDER* = 8192;	(*! Can encode MJPEG streams *)
	
	(*	M I S C E L L A N E O U S  *)

	(*!	E N U M S  *)

TYPE v4l2_field* = SIGNED32; 
	CONST
		FIELD_ANY* = 0; (* driver can choose from none,
						 top, bottom, interlaced
						 depending on whatever it thinks
						 is approximate ... *)
		FIELD_NONE* = 1; (* this device has no fields ... *)
		FIELD_TOP* = 2; (* top field only *)
		FIELD_BOTTOM* =3; (* bottom field only *)
		FIELD_INTERLACED* = 4; (* both fields interlaced *)
		FIELD_SEQ_TB* = 5; (* both fields sequential into one
							 buffer, top-bottom order *)
		FIELD_SEQ_BT* = 6; (* same as above + bottom-top order *)
		FIELD_ALTERNATE* = 7; (* both fields alternating into
							 separate buffers *)
		FIELD_INTERLACED_TB* = 8; (* both fields interlaced, top field
						 first and the top field is
						 transmitted first *)
		FIELD_INTERLACED_BT* = 9; (* both fields interlaced, top field
						 first and the bottom field is
						 transmitted first *)

TYPE  v4l2_buf_type* = SIGNED32; 
	CONST 
		BUF_TYPE_VIDEO_CAPTURE* = 1;
		BUF_TYPE_VIDEO_OUTPUT* = 2;
		BUF_TYPE_VIDEO_OVERLAY* = 3;
		BUF_TYPE_VBI_CAPTURE* = 4;
		BUF_TYPE_VBI_OUTPUT* = 5;
		BUF_TYPE_SLICED_VBI_CAPTURE* = 6;
		BUF_TYPE_SLICED_VBI_OUTPUT* = 7;
		(* #if 1 *)
		(* Experimental *)
		BUF_TYPE_VIDEO_OUTPUT_OVERLAY* = 8;
		(* #endif*)
		BUF_TYPE_PRIVATE* = 080H;
						 
TYPE v4l2_tuner_type* = SIGNED32;
	CONST 
		TUNER_RADIO* = 1;
		TUNER_ANALOG_TV* = 2;
		TUNER_DIGITAL_TV* = 3;
	
TYPE v4l2_memory* = SIGNED32;
	CONST 
		MEMORY_MMAP* = 1; 
		MEMORY_USERPTR* = 2; 
		MEMORY_OVERLAY* = 3; 
	
	(* see also http://vektor.theorem.ca/graphics/ycbcr/ *)
TYPE v4l2_colorspace* = SIGNED32 ;
	CONST 
		 (* ITU-R 601 -- broadcast NTSC/PAL *)
		COLORSPACE_SMPTE170M* = 1;
		
		 (* 1125-Line (US) HDTV *)
		COLORSPACE_SMPTE240M* = 2; 
		
		 (* HD and modern captures. *)
		COLORSPACE_REC709* = 3; 
		
		 (* broken BT878 extents (601, luma range 16-253 instead of 16-235) *)
		COLORSPACE_BT878* = 4; 
		
		 (* These should be useful.  Assume 601 extents. *)
		COLORSPACE_470_SYSTEM_M* = 5;
		COLORSPACE_470_SYSTEM_BG* = 6;
		
		 (* I know there will be cameras that send this.  So, this is
		* unspecified chromaticities and full 0-255 on each of the
		* Y'CbCr components
		*)
		COLORSPACE_JPEG* = 7;
		
		 (* For RGB colourspaces, this is probably a good start. *)
		COLORSPACE_SRGB* = 8;

TYPE v4l2_priority* = SIGNED32;;
	CONST 
		PRIORITY_UNSET* = 0;
		PRIORITY_BACKGROUND* = 1;
		PRIORITY_INTERACTIVE* = 2;
		PRIORITY_RECORD* = 3;
		 PRIORITY_DEFAULT* = PRIORITY_INTERACTIVE;

	TYPE v4l2_rect* = RECORD 
		left* : s32;
		top* : s32;
		width* : u32;
		height* : u32;
	END;

	TYPE v4l2_fract* = RECORD 
		numerator* : u32;
		denominator* : u32;
	END;
	
	(*!	D R I V E R   C A P A B I L I T I E S  *)
TYPE v4l2_capability *  = RECORD
		driver* : ARRAY 16 OF u8;	(* i.e. "bttv" *)
		card* : ARRAY 32 OF u8;	(* i.e. "Hauppauge WinTV" *)
		bus_info* : ARRAY 32 OF u8;	(* "PCI:" + pci_name(pci_dev) *)
		version* : u32;        (* should use KERNEL_VERSION() *)
		capabilities* : SET32; (*! u32; *)	(* Device capabilities *)
		reserved* : ARRAY 4 OF u32;
	END;
	
	 (* Values for 'capabilities' field *)
 CONST 
	 CAP_VIDEO_CAPTURE* = 0;  (* Is a video capture device *)
	 CAP_VIDEO_OUTPUT* = 1;  (* Is a video output device *)
	 CAP_VIDEO_OVERLAY* = 2;  (* Can do video overlay *)
	 CAP_VBI_CAPTURE* = 4;  (* Is a raw VBI capture device *)
	 CAP_VBI_OUTPUT* = 5;  (* Is a raw VBI output device *)
	 CAP_SLICED_VBI_CAPTURE* = 6;  (* Is a sliced VBI capture device *)
	 CAP_SLICED_VBI_OUTPUT* = 7;  (* Is a sliced VBI output device *)
	 CAP_RDS_CAPTURE* = 8;  (* RDS data capture *)
	 CAP_VIDEO_OUTPUT_OVERLAY* = 9;  (* Can do video output overlay *)
	 CAP_HW_FREQ_SEEK* = 10;  (* Can do hardware frequency seek  *)
	 CAP_RDS_OUTPUT* =11;  (* Is an RDS encoder *)

	 CAP_TUNER* = 16;  (* has a tuner *)
	 CAP_AUDIO* = 17;  (* has audio support *)
	 CAP_RADIO* = 18;  (* is a radio device *)
	 CAP_MODULATOR* = 19;  (* has a modulator *)

	 CAP_READWRITE* = 24;  (* read/write systemcalls *)
	 CAP_ASYNCIO* = 25;  (* async I/O *)
	 CAP_STREAMING* = 26;  (* streaming I/O ioctls *)

	(*!	V I D E O   I M A G E   F O R M A T  *)
	TYPE v4l2_pix_format* = RECORD 
		width* : u32;
		height* : u32;
		pixelformat* : u32;
		field* : v4l2_field;
		bytesperline* : u32;	(* for padding, zero if unused *)
		sizeimage* : u32;
		colorspace* : v4l2_colorspace;
		priv* : u32;		(* private data, depends on pixelformat *)
		flags*: u32;
		encoding*: u32; (* union *)
		quantisation* : u32;
		xfer_func*: u32;
	END;
	
	(*!	F O R M A T   E N U M E R A T I O N  *)
	TYPE v4l2_fmtdesc* = RECORD 
		index* : u32;             (* Format number      *)
		type* : v4l2_buf_type;              (* buffer type        *)
		flags* : SET32; (*! u32 *)
		description* : ARRAY 32 OF u8;   (* Description string *)
		pixelformat* : u32;       (* Format fourcc      *)
		reserved* : ARRAY 4 OF u32;
	END;
	
CONST 
	FMT_FLAG_COMPRESSED* = 0;
	FMT_FLAG_EMULATED* = 1;
	
(*! #if 1 *)

	(* Experimental Frame Size and frame rate enumeration *)
	
	(*!	F R A M E   S I Z E   E N U M E R A T I O N *)
TYPE v4l2_frmsizetypes* = SIGNED32;
CONST 
		FRMSIZE_TYPE_DISCRETE* = 1;
		FRMSIZE_TYPE_CONTINUOUS* = 2;
		FRMSIZE_TYPE_STEPWISE* = 3;
	
TYPE v4l2_frmsize_discrete* = RECORD 
		width* : u32;		(* Frame width [pixel] *)
		height* : u32;		(* Frame height [pixel] *)
	END;

TYPE v4l2_frmsize_stepwise* = RECORD 
		min_width* : u32;	(* Minimum frame width [pixel] *)
		max_width* : u32;	(* Maximum frame width [pixel] *)
		step_width* : u32;	(* Frame width step size [pixel] *)
		min_height* : u32;	(* Minimum frame height [pixel] *)
		max_height* : u32;	(* Maximum frame height [pixel] *)
		step_height* : u32;	(* Frame height step size [pixel] *)
	END;

TYPE Frame24* =  ARRAY 24 OF CHAR; (* discrete or stepwise: SIZEOF (v4l2_frmsize_stepwise) or  SIZEOF(v4l2_frmsize_discrete) *)	
TYPE v4l2_frmsizeenum* = RECORD 
		index* : u32;		(* Frame size number *)
		pixel_format* : u32;	(* Pixel format *)
		type* : u32;		(* Frame size type the device supports. *)
				
		frame* : Frame24;	(* Frame size *)
(*		union: type cast frame according to type; ex:  discrete := SYSTEM.VAL( v4l2_frmsize_discrete, frame)
                discrete: v4l2_frmsize_discrete; (* 8 bytes *)
			stepwise: v4l2_frmsize_stepwise; (* 24 bytes *)
*)
		reserved*: ARRAY 2 OF u32; 			(* Reserved space for future use *)
	END;
	
	(*
	 *	F R A M E   R A T E   E N U M E R A T I O N
	 *)
	TYPE v4l2_frmivaltypes* = SIGNED32 ;
	CONST 
		FRMIVAL_TYPE_DISCRETE* = 1;
		FRMIVAL_TYPE_CONTINUOUS* = 2;
		FRMIVAL_TYPE_STEPWISE* = 3;
	
	
	TYPE v4l2_frmival_stepwise* = RECORD 
		min*: v4l2_fract;		(* Minimum frame interval [s] *)
		max*: v4l2_fract;		(* Maximum frame interval [s] *)
		step*: v4l2_fract;		(* Frame interval step size [s] *)
	END;
	
	TYPE v4l2_frmivalenum* = RECORD 
		index*: u32;		(* Frame format index *)
		pixel_format*: u32;	(* Pixel format *)
		width*: u32;		(* Frame width *)
		height*: u32;		(* Frame height *)
		type*: u32;		(* Frame interval type the device supports. *)
		
		frame* : Frame24; (* Frame interval *)
		(* union: type cast frame according to type; ex:  discrete := SYSTEM.VAL(v4l2_fract, frame)
			discrete: v4l2_fract;
			stepwise: v4l2_frmival_stepwise;
		*)
		
		reserved*: ARRAY 2 OF u32; 	(* Reserved space for future use *)
	END;;

(*! #endif *)
	
	(*!	T I M E C O D E *)
	TYPE v4l2_timecode* = RECORD 
		type* : u32;
		flags* : SET32; (*! u32; *)
		frames* : u8;
		seconds* : u8;
		minutes* : u8;
		hours* : u8;
		userbits* : ARRAY 4 OF u8;
	END;
	
	(*  Type  *)
	CONST 
	 TC_TYPE_24FPS* = 1;
	 TC_TYPE_25FPS* = 2;
	 TC_TYPE_30FPS* = 3;
	 TC_TYPE_50FPS* = 4;
	 TC_TYPE_60FPS* = 5;
	
	(*  Flags  *)
	 TC_FLAG_DROPFRAME* = {0}; (* "drop-frame" mode *)
	 TC_FLAG_COLORFRAME* = {1};
	 TC_USERBITS_field* = {2,3};
	 TC_USERBITS_USERDEFINED* = {};
	 TC_USERBITS_8BITCHARS* = {3};
	(* The above is based on SMPTE timecodes *)


	TYPE v4l2_jpegcompression* = RECORD 
		quality*: SIGNED16;
		
		APPn*: SIGNED16;              (* Number of APP segment to be written,  must be 0..15 *)
		APP_len*: SIGNED16;           (* Length of data in JPEG APPn segment *)
		APP_data*: ARRAY 60 OF CHAR;      (* Data in the JPEG APPn segment. *)
		
		COM_len*: SIGNED16;           (* Length of data in JPEG COM segment *)
		COM_data*: ARRAY 60 OF CHAR;      (* Data in JPEG COM segment *)
		
		jpeg_markers* : u32;     (* Which markers should go into the JPEG
		* output. Unless you exactly know what
		* you do, leave them untouched.
		* Inluding less markers will make the
		* resulting code smaller, but there will
		* be fewer applications which can read it.
		* The presence of the APP and COM marker
		* is influenced by APP_len and COM_len
		* ONLY, not by this property! *)
	END;
		
	CONST 
		JPEG_MARKER_DHT* = 8;
		(* Define Huffman Tables *)
		JPEG_MARKER_DQT* = 16;    (* Define Quantization Tables *)
		JPEG_MARKER_DRI* = 32;    (* Define Restart Interval *)
		JPEG_MARKER_COM* = 64;    (* Comment segment *)
		JPEG_MARKER_APP* = 128;    (* App segment, driver will allways use APP0 *)
						
	(*!	M E M O R Y - M A P P I N G   B U F F E R S  *)
	
	TYPE v4l2_requestbuffers* = RECORD 
		count* : u32;
		type* : v4l2_buf_type;
		memory* : v4l2_memory;
		reserved* : ARRAY 2 OF u32;
	END;
	
	union8* =ARRAY 8 OF CHAR; (* u32 + insigned long *)
	
	TYPE v4l2_buffer* = RECORD 
		index* : u32;
		type* : v4l2_buf_type;
		bytesused* : u32;
		flags* : SET32; (*!u32 *)
		field* : v4l2_field;
		timestamp* : Unix.Itimerval;
		timecode* : v4l2_timecode;
		sequence* : u32;
		
		(* memory location *)
		memory* : v4l2_memory;
	
	(*	TYPE union526* = RECORD 
			CASE union:SIGNED16 OF 
			1 : (offset: u32);
			2 : (userptr: SIGNED32);
		END; *) 
		m* : ADDRESS;  (*union8 *)
		 length* : u32; 
		input* : u32; 
		reserved* : u32; 
	END ;
	
	(*  Flags for 'flags' field *)
CONST BUF_FLAG_MAPPED* = 0;  (* Buffer is mapped (flag) *)
	 BUF_FLAG_QUEUED* = 1;	(* Buffer is queued for processing *)
	 BUF_FLAG_DONE* = 2;	(* Buffer is ready *)
	 BUF_FLAG_KEYFRAME* = 3;	(* Image is a keyframe (I-frame) *)
	 BUF_FLAG_PFRAME* = 4;	(* Image is a P-frame *)
	 BUF_FLAG_BFRAME* = 5;	(* Image is a B-frame *)
	(* Buffer is ready, but the data contained within is corrupted. *)
	 BUF_FLAG_ERROR* = 6;
	 BUF_FLAG_TIMECxODE* = 8;	(*! timecode field is valid *)
	 BUF_FLAG_INPUT* = 9;  (* input field is valid *)
	
	(*!	O V E R L A Y   P R E V I E W *)
	
	TYPE v4l2_framebuffer* = RECORD 
		capability* : SET32; (*! u32 *)
		flags* : SET32; (*! u32 *)
		(* FIXME* : in theory we should pass something like PCI device + memory
		* region + offset instead of some physical address *)
		base* : ADDRESS; (* pointer, address *)
		fmt* : RECORD
					width* : u32;
					height* : u32;
					pixelformat* : u32;
					field* : v4l2_field;
					bytesperline* : u32;	(* for padding, zero if unused *)
					sizeimage* : u32;
					colorspace* : v4l2_colorspace;
					priv* : u32;		(* private data, depends on pixelformat *)	
		           END;
		END;
	
	(*  Flags for the 'capability' field. Read only *)
CONST 
	FBUF_CAP_EXTERNOVERLAY* = 0;
	 FBUF_CAP_CHROMAKEY* = 1;
	 FBUF_CAP_LIST_CLIPPING* = 2;
	 FBUF_CAP_BITMAP_CLIPPING* = 3;
	 FBUF_CAP_LOCAL_ALPHA* = 4;
	 FBUF_CAP_GLOBAL_ALPHA* = 5;
	 FBUF_CAP_LOCAL_INV_ALPHA* = 6;
	 FBUF_CAP_SRC_CHROMAKEY* = 7;
	(*  Flags for the 'flags' field. *)
	 FBUF_FLAG_PRIMARY* = 0;
	 FBUF_FLAG_OVERLAY* = 1;
	 FBUF_FLAG_CHROMAKEY* = 2;
	 FBUF_FLAG_LOCAL_ALPHA* = 3;
	 FBUF_FLAG_GLOBAL_ALPHA* = 4;
	 FBUF_FLAG_LOCAL_INV_ALPHA* = 5;
	 FBUF_FLAG_SRC_CHROMAKEY* = 6;
	
	
	TYPE v4l2_Pclip* = POINTER {UNTRACED, UNSAFE} TO v4l2_clip;
	TYPE v4l2_clip* = RECORD 
		c* : v4l2_rect;
		next* : v4l2_Pclip;
	END;
	
	TYPE v4l2_window* = RECORD 
		w* : v4l2_rect;
		field* : v4l2_field;
		chromakey* : u32;
		clips* : v4l2_Pclip;
		clipcount* : u32;
		bitmap* : ADDRESS; (* address *)
		global_alpha* : u8;
	END;
	
	(*!	C A P T U R E   P A R A M E T E R S *)
TYPE v4l2_captureparm* = RECORD 
		capability* : u32;	  (*  Supported modes *)
		capturemode* : u32;	  (*  Current mode *)
		timeperframe* : v4l2_fract;  (*  Time per frame in .1us units *)
		extendedmode* : u32;  (*  Driver-specific extensions *)
		readbuffers* : u32;   (*  # of buffers for read *)
		reserved* : ARRAY 4 OF u32;
	END;
	
	(*  Flags for 'capability' and 'capturemode' fields *)
CONST MODE_HIGHQUALITY* = 00001H;	(*  High quality imaging mode *)
	 CAP_TIMEPERFRAME* = 01000H;	(*  timeperframe field is supported *)
	
	TYPE v4l2_outputparm* = RECORD 
		capability* : u32;	 (*  Supported modes *)
		outputmode* : u32;	 (*  Current mode *)
		timeperframe* : v4l2_fract; (*  Time per frame in seconds *)
		extendedmode* : u32; (*  Driver-specific extensions *)
		writebuffers* : u32; (*  # of buffers for write *)
		reserved* : ARRAY 4 OF u32;
	END;
	
	(*!	I N P U T   I M A G E   C R O P P I N G  *)
	TYPE v4l2_cropcap* = RECORD 
		type* : v4l2_buf_type;
		bounds* : v4l2_rect;
		defrect* : v4l2_rect;
		pixelaspect* : v4l2_fract;
	END;
	
	TYPE v4l2_crop* = RECORD 
		type* : v4l2_buf_type;
		c* : v4l2_rect;
	END;
	
	(*!   A N A L O G   V I D E O   S T A N D A R D *)
	
	TYPE v4l2_std_id* = u64;
	
	(* one bit for each *)
	CONST STD_PAL_B* = v4l2_std_id(000000001H);
	 STD_PAL_B1* = v4l2_std_id(000000002H);
	 STD_PAL_G* = v4l2_std_id(000000004H);
	 STD_PAL_H* = v4l2_std_id(000000008H);
	 STD_PAL_I* = v4l2_std_id(000000010H);
	 STD_PAL_D* = v4l2_std_id(000000020H);
	 STD_PAL_D1* = v4l2_std_id(000000040H);
	 STD_PAL_K* = v4l2_std_id(000000080H);
	
	 STD_PAL_M* = v4l2_std_id(000000100H);
	 STD_PAL_N* = v4l2_std_id(000000200H);
	 STD_PAL_Nc* = v4l2_std_id(000000400H);
	 STD_PAL_60* = v4l2_std_id(000000800H);
	
	 STD_NTSC_M* = v4l2_std_id(000001000H);
	 STD_NTSC_M_JP* = v4l2_std_id(000002000H);
	 STD_NTSC_443* = v4l2_std_id(000004000H);
	 STD_NTSC_M_KR* = v4l2_std_id(000008000H);
	
	 STD_SECAM_B* = v4l2_std_id(000010000H);
	 STD_SECAM_D* = v4l2_std_id(000020000H);
	 STD_SECAM_G* = v4l2_std_id(000040000H);
	 STD_SECAM_H* = v4l2_std_id(000080000H);
	 STD_SECAM_K* = v4l2_std_id(000100000H);
	 STD_SECAM_K1* = v4l2_std_id(000200000H);
	 STD_SECAM_L* = v4l2_std_id(000400000H);
	 STD_SECAM_LC* = v4l2_std_id(000800000H);
	
	(* ATSC/HDTV *)
	 STD_ATSC_8_VSB* = v4l2_std_id(001000000H);
	 STD_ATSC_16_VSB* = v4l2_std_id(002000000H);
	
	(* FIXME:
	   Although std_id is 64 bits, there is an issue on PPC32 architecture that
	   makes switch(u64) to break. So, there's a hack on v4l2-common.c rounding
	   this value to 32 bits.
	   As, currently, the max value is for STD_ATSC_16_VSB (30 bits wide),
	   it should work fine. However, if needed to add more than two standards,
	   v4l2-common.c should be fixed.
	 *)
	
	(* some merged standards *)
	 STD_MN* = STD_PAL_M + STD_PAL_N + STD_PAL_Nc + STD_NTSC;
	 STD_B* = STD_PAL_B + STD_PAL_B1 + STD_SECAM_B;
	 STD_GH* = STD_PAL_G + STD_PAL_H + STD_SECAM_G + STD_SECAM_H;
	 STD_DK* = STD_PAL_DK + STD_SECAM_DK;
	
	(* some common needed stuff *)
	 STD_PAL_BG* = STD_PAL_B + STD_PAL_B1 + STD_PAL_G;
	 STD_PAL_DK* = STD_PAL_D + STD_PAL_D1 + STD_PAL_K;
	 STD_PAL* = STD_PAL_BG + STD_PAL_DK + STD_PAL_H + STD_PAL_I;
	 STD_NTSC* = STD_NTSC_M + STD_NTSC_M_JP + STD_NTSC_M_KR;
	 STD_SECAM_DK* = STD_SECAM_D + STD_SECAM_K + STD_SECAM_K1;
	 STD_SECAM* = STD_SECAM_B + STD_SECAM_G + STD_SECAM_H + STD_SECAM_DK + STD_SECAM_L + STD_SECAM_LC;
	
	 STD_525_60* = STD_PAL_M + STD_PAL_60 + STD_NTSC + STD_NTSC_443;
	 STD_625_50* = STD_PAL + STD_PAL_N + STD_PAL_Nc + STD_SECAM;
	 STD_ATSC* = STD_ATSC_8_VSB + STD_ATSC_16_VSB;
	
	 STD_UNKNOWN* = 0;
	 STD_ALL* = STD_525_60 + STD_625_50;

	TYPE v4l2_standard* = RECORD 
		index* : u32;
		id* : v4l2_std_id;
		name* : ARRAY 24 OF u8;
		frameperiod* : v4l2_fract; (* Frames, not fields *)
		framelines* : u32;
		reserved* : ARRAY 4 OF u32;
	END;
	
	(*! V I D E O	T I M I N G S	D V	P R E S E T  *)
	TYPE v4l2_dv_preset* = RECORD 
		preset* : u32;
		reserved* : ARRAY 4 OF u32;
	END;
	
	(*! D V	P R E S E T S	E N U M E R A T I O N	 *)
	TYPE v4l2_dv_enum_preset* = RECORD 
		index* : u32;
		preset* : u32;
		name* : ARRAY 32 OF u8; (* Name of the preset timing *)
		width* : u32;
		height* : u32;
		reserved* : ARRAY 4 OF u32;
	END;
	
	(*  D V	P R E S E T	V A L U E S *)
	CONST DV_INVALID* = 0;
	 DV_480P59_94* = 1; (* BT.1362 *)
	 DV_576P50* = 2; (* BT.1362 *)
	 DV_720P24* = 3; (* SMPTE 296M *)
	 DV_720P25* = 4; (* SMPTE 296M *)
	 DV_720P30* = 5; (* SMPTE 296M *)
	 DV_720P50* = 6; (* SMPTE 296M *)
	 DV_720P59_94* = 7; (* SMPTE 274M *)
	 DV_720P60* = 8; (* SMPTE 274M/296M *)
	 DV_1080I29_97* = 9; (* BT.1120/ SMPTE 274M *)
	 DV_1080I30* = 10; (* BT.1120/ SMPTE 274M *)
	 DV_1080I25* = 11; (* BT.1120 *)
	 DV_1080I50* = 12; (* SMPTE 296M *)
	 DV_1080I60* = 13; (* SMPTE 296M *)
	 DV_1080P24* = 14; (* SMPTE 296M *)
	 DV_1080P25* = 15; (* SMPTE 296M *)
	 DV_1080P30* = 16; (* SMPTE 296M *)
	 DV_1080P50* = 17; (* BT.1120 *)
	 DV_1080P60* = 18; (* BT.1120 *)
	
	(*	D V 	B T	T I M I N G S *)
	
	(* BT.656/BT.1120 timing data *)
	TYPE v4l2_bt_timings* = RECORD 
		width* : u32;		(* width in pixels *)
		height* : u32;		(* height in lines *)
		interlaced* : u32;	(* Interlaced or progressive *)
		polarities* : u32;	(* Positive or negative polarity *)
		pixelclock* : u64;	(* Pixel clock in HZ. Ex. 74.25MHz->74250000 *)
		hfrontporch* : u32;	(* Horizpontal front porch in pixels *)
		hsync* : u32;		(* Horizontal Sync length in pixels *)
		hbackporch* : u32;	(* Horizontal back porch in pixels *)
		vfrontporch* : u32;	(* Vertical front porch in pixels *)
		vsync* : u32;		(* Vertical Sync length in lines *)
		vbackporch* : u32;	(* Vertical back porch in lines *)
		il_vfrontporch* : u32;	(* Vertical front porch for bottom field of
		* interlaced field formats
		*)
		il_vsync* : u32;	(* Vertical sync length for bottom field of
		* interlaced field formats
		*)
		il_vbackporch* : u32;	(* Vertical back porch for bottom field of
		* interlaced field formats
		*)
		reserved* : ARRAY 16 OF u32;
	END;

	(* Interlaced or progressive format *)
CONST 
	DV_PROGRESSIVE* = 0;
	DV_INTERLACED* = 1;
	
	(* Polarities. If bit is not set, it is assumed to be negative polarity *)
	DV_VSYNC_POS_POL* = 000000001H;
	DV_HSYNC_POS_POL* = 000000002H;
	

	(*!!!!!! DV timings *)
	TYPE Data47* = ARRAY 47 OF u32;
	TYPE v4l2_dv_timings* = RECORD 
		type*: u32;
	(*	
		union: type cast data according to type, ex: bt := SYSTEM.VAL(v4l2_bt_timings, data)
		bt: v4l2_bt_timings;
		reserved: ARRAY 32 OF u32;
		*)
		data*: Data47;
	END;
	
	(* Values for the type field *)
	CONST DV_BT_656_1120* = 0;	(* BT.656/1120 timing type *)

	(*!	V I D E O   I N P U T S *)
TYPE v4l2_input* = RECORD 
		index* : u32;		(*  Which input *)
		name* : ARRAY 32 OF u8;		(*  Label *)
		type* : u32;		(*  Type of input *)
		audioset* : u32;		(*  Associated audios (bitfield) *)
		tuner* : u32;             (*  Associated tuner *)
		std* : v4l2_std_id;
		status* : SET32; (*! u32 *)
		capabilities* : SET32; (*!  u32 *)
		reserved* : ARRAY 3 OF u32;
	END;

(*  Values for the 'type' field *)
CONST 
	INPUT_TYPE_TUNER* = 1;
	 INPUT_TYPE_CAMERA* = 2;

	(* field 'status' - general *)
	 IN_ST_NO_POWER* = 0;  (* Attached device is off *)
	 IN_ST_NO_SIGNAL* = 1;
	 IN_ST_NO_COLOR* = 2;
	
	(* field 'status' - sensor orientation *)
	(* If sensor is mounted upside down set both bits *)
	 IN_ST_HFLIP* = 4; (* Frames are flipped horizontally *)
	 IN_ST_VFLIP* = 5; (* Frames are flipped vertically *)
	
	(* field 'status' - analog *)
	 IN_ST_NO_H_LOCK* = 8;  (* No horizontal sync lock *)
	 IN_ST_COLOR_KILL* = 9;  (* Color killer is active *)
	
	(* field 'status' - digital *)
	 IN_ST_NO_SYNC* = 16;  (* No synchronization lock *)
	 IN_ST_NO_EQU* = 17;  (* No equalizer lock *)
	 IN_ST_NO_CARRIER* = 8;  (* Carrier recovery failed *)
	
	(* field 'status' - VCR and set-top box *)
	 IN_ST_MACROVISION* = 24;  (* Macrovision detected *)
	 IN_ST_NO_ACCESS* = 25;  (* Conditional access denied *)
	 IN_ST_VTR* = 26;  (* VTR time constant *)
	
	(* capabilities flags *)
	 IN_CAP_PRESETS* = 0; (* Supports S_DV_PRESET *)
	 IN_CAP_CUSTOM_TIMINGS* = 1; (* Supports S_DV_TIMINGS *)
	 IN_CAP_STD* =2; (* Supports S_STD *)

	(*!  V I D E O   O U T P U T S  *)
	TYPE v4l2_output* = RECORD 
		index* : u32;		(*  Which output *)
		name* : ARRAY 32 OF u8;		(*  Label *)
		type* : u32;		(*  Type of output *)
		audioset* : u32;		(*  Associated audios (bitfield) *)
		modulator* : u32;         (*  Associated modulator *)
		std* : v4l2_std_id;
		capabilities* : SET32; (*!  u32 *)
		reserved* : ARRAY 3 OF u32;
	END;
	
	(*  Values for the 'type' field *)
CONST OUTPUT_TYPE_MODULATOR* = 1;
	 OUTPUT_TYPE_ANALOG* = 2;
	 OUTPUT_TYPE_ANALOGVGAOVERLAY* = 3;
	
	(* capabilities flags *)
	 OUT_CAP_PRESETS* = 0; (* Supports S_DV_PRESET *)
	 OUT_CAP_CUSTOM_TIMINGS* = 1; (* Supports S_DV_TIMINGS *)
	 OUT_CAP_STD* = 2; (* Supports S_STD *)

	(*!	C O N T R O L S *)
	
CONST
	CTRL_MAX_DIMS* = 4;
	
	TYPE v4l2_control* = RECORD 
		id* : u32;
		value* : s32;
	END;
	
	TYPE v4l2_ext_control* = RECORD 
		id* : u32;
		size* : u32;
		reserved2* : ARRAY 1 OF u32;
		data*: s64;  
	(*	TYPE union909* = RECORD 
			CASE union:SIGNED16 OF 
			1 : (value: s32);
			2 : (value64: s64);
			3 : (string: ARRAY OF CHAR);
		END;
	*)
	END;

TYPE v4l2_ext_controls* = RECORD 
		ctrl_class* : u32;
		count* : u32;
		error_idx* : u32;
		reserved* : ARRAY 2 OF u32;
		controls* : POINTER {UNTRACED, UNSAFE} TO v4l2_ext_control;
	END;
	
	(*  Values for ctrl_class field *)
CONST 
	CTRL_CLASS_USER* = 000980000H;	(* Old-style 'user' controls *)
	 CTRL_CLASS_MPEG* = 000990000H;	(* MPEG-compression controls *)
	 CTRL_CLASS_CAMERA* = 0009A0000H;	(* Camera class controls *)
	 CTRL_CLASS_FM_TX* = 0009B0000H;	(* FM Modulator control class *)

	 CTRL_ID_MASK* = 00FFFFFFFH;

(*	 
	(*# todo be converted  *)
	CTRL_ID_MASK      	  (0x0fffffff)
	CTRL_ID2CLASS(id)    ((id) & 0x0fff0000UL)
	CTRL_DRIVER_PRIV(id) (((id) & 0xffff) >= 0x1000)
*)	

	TYPE v4l2_ctrl_type* = SIGNED32;
	CONST 
		CTRL_TYPE_INTEGER* = 1;
		CTRL_TYPE_BOOLEAN* = 2;
		CTRL_TYPE_MENU* = 3;
		CTRL_TYPE_BUTTON* = 4;
		CTRL_TYPE_INTEGER64* = 5;
		CTRL_TYPE_CTRL_CLASS* = 6;
		CTRL_TYPE_STRING* = 7;
		CTRL_TYPE_BITMASK* = 8;
	
	(*  Used in the VIDIOC_QUERYCTRL ioctl for querying controls *)
	TYPE v4l2_queryctrl* = RECORD 
		id* : u32;
		type* : v4l2_ctrl_type;
		name* : ARRAY 32 OF u8;	(* Whatever *)
		minimum* : s32;	(* Note signedness *)
		maximum* : s32;
		step* : s32;
		default_value* : s32;
		flags* : SET32; (*! u32; *)
		reserved* : ARRAY 2 OF u32;
	END;

	(*  Used in the VIDIOC_QUERY_EXT_CTRL ioctl for querying extended controls *)
	TYPE v4l2_query_ext_ctrl* = RECORD
		id*: u32;
		type*: u32;
		name*: ARRAY 32 OF CHAR;
		minimum*: s64;
		maximum*: s64;
		step*: u64;
		default_value*: s64;
		flags*: SET32;
		elem_size*: u32;
		elems*: u32;
		nr_of_dims*:u32;
		dims*: ARRAY CTRL_MAX_DIMS OF u32;
		reserved* : ARRAY 32 OF u32;
	END;
	
	(*  Used in the VIDIOC_QUERYMENU ioctl for querying menu items *)
	TYPE v4l2_querymenu* = RECORD 
		id* : u32;
		index* : u32;
		name* : ARRAY 32 OF u8;	(* Whatever or value *)
		reserved* : u32;
	END;
	
	(*  Control flags  *)
CONST 
	CTRL_FLAG_DISABLED* = 0;
	 CTRL_FLAG_GRABBED* = 1;
	 CTRL_FLAG_READ_ONLY* = 2;
	 CTRL_FLAG_UPDATE* = 3;
	 CTRL_FLAG_INACTIVE* = 4;
	 CTRL_FLAG_SLIDER* = 5;
	 CTRL_FLAG_WRITE_ONLY* = 6;
	
	(*  Query flag, to be ORed with the control ID *)
	 CTRL_FLAG_NEXT_CTRL* = 31;
	
	(*  User-class control IDs defined by V4L2 *)
	 CID_BASE* = CTRL_CLASS_USER + 0900H;
	 CID_USER_BASE* = CID_BASE;
	(*  IDs reserved for driver specific controls *)
	 CID_PRIVATE_BASE* = 008000000H;
	
	 CID_USER_CLASS* = CTRL_CLASS_USER + 1;
	 CID_BRIGHTNESS* = CID_BASE+0;
	 CID_CONTRAST* = CID_BASE+1;
	 CID_SATURATION* = CID_BASE+2;
	 CID_HUE* = CID_BASE+3;
	 CID_AUDIO_VOLUME* = CID_BASE+5;
	 CID_AUDIO_BALANCE* = CID_BASE+6;
	 CID_AUDIO_BASS* = CID_BASE+7;
	 CID_AUDIO_TREBLE* = CID_BASE+8;
	 CID_AUDIO_MUTE* = CID_BASE+9;
	 CID_AUDIO_LOUDNESS* = CID_BASE+10;
	 CID_BLACK_LEVEL* = CID_BASE+11; (* Deprecated *)
	 CID_AUTO_WHITE_BALANCE* = CID_BASE+12;
	 CID_DO_WHITE_BALANCE* = CID_BASE+13;
	 CID_RED_BALANCE* = CID_BASE+14;
	 CID_BLUE_BALANCE* = CID_BASE+15;
	 CID_GAMMA* = CID_BASE+16;
	 CID_WHITENESS* = CID_GAMMA; (* Deprecated *)
	 CID_EXPOSURE* = CID_BASE+17;
	 CID_AUTOGAIN* = CID_BASE+18;
	 CID_GAIN* = CID_BASE+19;
	 CID_HFLIP* = CID_BASE+20;
	 CID_VFLIP* = CID_BASE+21;
	
	(* Deprecated; use CID_PAN_RESET and CID_TILT_RESET *)
	 CID_HCENTER* = CID_BASE+22;
	 CID_VCENTER* = CID_BASE+23;
	
	 CID_POWER_LINE_FREQUENCY* = CID_BASE+24;
	 
	TYPE v4l2_power_line_frequency* = SIGNED32;
	CONST 
		CID_POWER_LINE_FREQUENCY_DISABLED* = 0;
		CID_POWER_LINE_FREQUENCY_50HZ* = 1;
		CID_POWER_LINE_FREQUENCY_60HZ* = 2;
		CID_POWER_LINE_FREQUENCY_AUTO* = 3;
		
	 CID_HUE_AUTO* = CID_BASE+25;
	 CID_WHITE_BALANCE_TEMPERATURE* = CID_BASE+26;
	 CID_SHARPNESS* = CID_BASE+27;
	 CID_BACKLIGHT_COMPENSATION* = CID_BASE+28;
	 CID_CHROMA_AGC* = CID_BASE+29;
	 CID_COLOR_KILLER* = CID_BASE+30;
	 CID_COLORFX* = CID_BASE+31;
	 
	TYPE v4l2_colorfx* = SIGNED32;
	CONST 
		COLORFX_NONE* = 0;
		COLORFX_BW* = 1;
		COLORFX_SEPIA* = 2;
		COLORFX_NEGATIVE* = 3;
		COLORFX_EMBOSS* = 4;
		COLORFX_SKETCH* = 5;
		COLORFX_SKY_BLUE* = 6;
		COLORFX_GRASS_GREEN* = 7;
		COLORFX_SKIN_WHITEN* = 8;
		COLORFX_VIVID* = 9;
	
	
	 CID_AUTOBRIGHTNESS* = CID_BASE+32;
	 CID_BAND_STOP_FILTER* = CID_BASE+33;
	
	 CID_ROTATE* = CID_BASE+34;
	 CID_BG_COLOR* = CID_BASE+35;
	
	 CID_CHROMA_GAIN* = CID_BASE+36;
	
	 CID_ILLUMINATORS_1* = CID_BASE+37;
	 CID_ILLUMINATORS_2* = CID_BASE+38;
	
	(* last CID + 1 *)
	 CID_LASTP1* = CID_BASE+39;
	
	(*  MPEG-class control IDs defined by V4L2 *)
	 CID_MPEG_BASE* = CTRL_CLASS_MPEG + 0900H;
	 CID_MPEG_CLASS* = CTRL_CLASS_MPEG + 1;
	(*! check above enumeration constants  *)
	
	(*  MPEG streams *)
	 CID_MPEG_STREAM_TYPE* = CID_MPEG_BASE+0;
	TYPE v4l2_mpeg_stream_type* = SIGNED32;
	CONST 
		MPEG_STREAM_TYPE_MPEG2_PS* = 0;(* MPEG-2 program stream *)
		MPEG_STREAM_TYPE_MPEG2_TS* = 1;(* MPEG-2 transport stream *)
		MPEG_STREAM_TYPE_MPEG1_SS* = 2;(* MPEG-1 system stream *)
		MPEG_STREAM_TYPE_MPEG2_DVD* = 3; (* MPEG-2 DVD-compatible stream *)
		MPEG_STREAM_TYPE_MPEG1_VCD* = 4;(* MPEG-1 VCD-compatible stream *)
		MPEG_STREAM_TYPE_MPEG2_SVCD* = 5;(* MPEG-2 SVCD-compatible stream *)
	
		CID_MPEG_STREAM_PID_PMT* = CID_MPEG_BASE+1;
		CID_MPEG_STREAM_PID_AUDIO* = CID_MPEG_BASE+2;
		CID_MPEG_STREAM_PID_VIDEO* = CID_MPEG_BASE+3;
		CID_MPEG_STREAM_PID_PCR* = CID_MPEG_BASE+4;
		CID_MPEG_STREAM_PES_ID_AUDIO* = CID_MPEG_BASE+5;
		CID_MPEG_STREAM_PES_ID_VIDEO* = CID_MPEG_BASE+6;
		CID_MPEG_STREAM_VBI_FMT* = CID_MPEG_BASE+7;
	
	TYPE v4l2_mpeg_stream_vbi_fmt* = SIGNED32;
	CONST 
		MPEG_STREAM_VBI_FMT_NONE* = 0;   (* No VBI in the MPEG stream *)
		MPEG_STREAM_VBI_FMT_IVTV* = 1;   (* VBI in private packets, IVTV format *)
	
	
	(*  MPEG audio *)
	CONST CID_MPEG_AUDIO_SAMPLING_FREQ* = CID_MPEG_BASE+100;
	TYPE v4l2_mpeg_audio_sampling_freq* = SIGNED32;
	CONST 
		MPEG_AUDIO_SAMPLING_FREQ_44100* = 0;
		MPEG_AUDIO_SAMPLING_FREQ_48000* = 1;
		MPEG_AUDIO_SAMPLING_FREQ_32000* = 2;
	
	CONST CID_MPEG_AUDIO_ENCODING* = CID_MPEG_BASE+101;
	TYPE v4l2_mpeg_audio_encoding* = SIGNED32;
	CONST 
		MPEG_AUDIO_ENCODING_LAYER_1* = 0;
		MPEG_AUDIO_ENCODING_LAYER_2* = 1;
		MPEG_AUDIO_ENCODING_LAYER_3* = 2;
		MPEG_AUDIO_ENCODING_AAC* = 3;
		MPEG_AUDIO_ENCODING_AC3* = 4;
	
	CONST CID_MPEG_AUDIO_L1_BITRATE* = CID_MPEG_BASE+102;
	TYPE v4l2_mpeg_audio_l1_bitrate* = SIGNED32;
	CONST 
		MPEG_AUDIO_L1_BITRATE_32K* = 0;
		MPEG_AUDIO_L1_BITRATE_64K* = 1;
		MPEG_AUDIO_L1_BITRATE_96K* = 2;
		MPEG_AUDIO_L1_BITRATE_128K* = 3;
		MPEG_AUDIO_L1_BITRATE_160K* = 4;
		MPEG_AUDIO_L1_BITRATE_192K* = 5;
		MPEG_AUDIO_L1_BITRATE_224K* = 6;
		MPEG_AUDIO_L1_BITRATE_256K* = 7;
		MPEG_AUDIO_L1_BITRATE_288K* = 8;
		MPEG_AUDIO_L1_BITRATE_320K* = 9;
		MPEG_AUDIO_L1_BITRATE_352K* = 10;
		MPEG_AUDIO_L1_BITRATE_384K* = 11;
		MPEG_AUDIO_L1_BITRATE_416K* = 12;
		MPEG_AUDIO_L1_BITRATE_448K* = 13;
	
	CONST CID_MPEG_AUDIO_L2_BITRATE* = CID_MPEG_BASE+103;
	TYPE v4l2_mpeg_audio_l2_bitrate* = SIGNED32;
	CONST 
		MPEG_AUDIO_L2_BITRATE_32K* = 0;
		MPEG_AUDIO_L2_BITRATE_48K* = 1;
		MPEG_AUDIO_L2_BITRATE_56K* = 2;
		MPEG_AUDIO_L2_BITRATE_64K* = 3;
		MPEG_AUDIO_L2_BITRATE_80K* = 4;
		MPEG_AUDIO_L2_BITRATE_96K* = 5;
		 MPEG_AUDIO_L2_BITRATE_112K* = 6;
		MPEG_AUDIO_L2_BITRATE_128K* = 7;
		MPEG_AUDIO_L2_BITRATE_160K* = 8;
		MPEG_AUDIO_L2_BITRATE_192K* = 9;
		MPEG_AUDIO_L2_BITRATE_224K* = 10;
		MPEG_AUDIO_L2_BITRATE_256K* = 11;
		MPEG_AUDIO_L2_BITRATE_320K* = 12;
		MPEG_AUDIO_L2_BITRATE_384K* = 13;
	
	CONST CID_MPEG_AUDIO_L3_BITRATE* = CID_MPEG_BASE+104;
	TYPE v4l2_mpeg_audio_l3_bitrate* = SIGNED32;
	CONST 
		MPEG_AUDIO_L3_BITRATE_32K* = 0;
		MPEG_AUDIO_L3_BITRATE_40K* = 1;
		MPEG_AUDIO_L3_BITRATE_48K* = 2;
		MPEG_AUDIO_L3_BITRATE_56K* = 3;
		MPEG_AUDIO_L3_BITRATE_64K* = 4;
		MPEG_AUDIO_L3_BITRATE_80K* = 5;
		MPEG_AUDIO_L3_BITRATE_96K* = 6;
		MPEG_AUDIO_L3_BITRATE_112K* = 7;
		MPEG_AUDIO_L3_BITRATE_128K* = 8;
		MPEG_AUDIO_L3_BITRATE_160K* = 9;
		MPEG_AUDIO_L3_BITRATE_192K* = 10;
		MPEG_AUDIO_L3_BITRATE_224K* = 11;
		MPEG_AUDIO_L3_BITRATE_256K* = 12;
		MPEG_AUDIO_L3_BITRATE_320K* = 13;
	
	CONST CID_MPEG_AUDIO_MODE* = CID_MPEG_BASE+105;
	TYPE v4l2_mpeg_audio_mode* = SIGNED32;
	CONST 
		MPEG_AUDIO_MODE_STEREO* = 0;
		MPEG_AUDIO_MODE_JOINT_STEREO* = 1;
		MPEG_AUDIO_MODE_DUAL* = 2;
		MPEG_AUDIO_MODE_MONO* = 3;
	
	CONST CID_MPEG_AUDIO_MODE_EXTENSION* = CID_MPEG_BASE+106;
	TYPE v4l2_mpeg_audio_mode_extension* = SIGNED32;
	CONST 
		MPEG_AUDIO_MODE_EXTENSION_BOUND_4* = 0;
		MPEG_AUDIO_MODE_EXTENSION_BOUND_8* = 1;
		MPEG_AUDIO_MODE_EXTENSION_BOUND_12* = 2;
		MPEG_AUDIO_MODE_EXTENSION_BOUND_16* = 3;
	
	CONST CID_MPEG_AUDIO_EMPHASIS* = CID_MPEG_BASE+107;
	TYPE v4l2_mpeg_audio_emphasis* = SIGNED32;
	CONST 
		MPEG_AUDIO_EMPHASIS_NONE* = 0;
		MPEG_AUDIO_EMPHASIS_50_DIV_15_uS* = 1;
		MPEG_AUDIO_EMPHASIS_CCITT_J17* = 2;
	
	CONST CID_MPEG_AUDIO_CRC* = CID_MPEG_BASE+108;
	TYPE v4l2_mpeg_audio_crc* = SIGNED32;
	CONST 
		MPEG_AUDIO_CRC_NONE* = 0;
		MPEG_AUDIO_CRC_CRC16* = 1;
	
	CONST CID_MPEG_AUDIO_MUTE* = CID_MPEG_BASE+109;
	CONST CID_MPEG_AUDIO_AAC_BITRATE* = CID_MPEG_BASE+110;
	CONST CID_MPEG_AUDIO_AC3_BITRATE* = CID_MPEG_BASE+111;
	TYPE v4l2_mpeg_audio_ac3_bitrate* = SIGNED32;
	CONST 
		MPEG_AUDIO_AC3_BITRATE_32K* = 0;
		MPEG_AUDIO_AC3_BITRATE_40K* = 1;
		MPEG_AUDIO_AC3_BITRATE_48K* = 2;
		MPEG_AUDIO_AC3_BITRATE_56K* = 3;
		MPEG_AUDIO_AC3_BITRATE_64K* = 4;
		MPEG_AUDIO_AC3_BITRATE_80K* = 5;
		MPEG_AUDIO_AC3_BITRATE_96K* = 6;
		MPEG_AUDIO_AC3_BITRATE_112K* = 7;
		MPEG_AUDIO_AC3_BITRATE_128K* = 8;
		MPEG_AUDIO_AC3_BITRATE_160K* = 9;
		MPEG_AUDIO_AC3_BITRATE_192K* = 10;
		MPEG_AUDIO_AC3_BITRATE_224K* = 11;
		MPEG_AUDIO_AC3_BITRATE_256K* = 12;
		MPEG_AUDIO_AC3_BITRATE_320K* = 13;
		MPEG_AUDIO_AC3_BITRATE_384K* = 14;
		MPEG_AUDIO_AC3_BITRATE_448K* = 15;
		MPEG_AUDIO_AC3_BITRATE_512K* = 16;
		MPEG_AUDIO_AC3_BITRATE_576K* = 17;
		MPEG_AUDIO_AC3_BITRATE_640K* = 18;
	
	
	(*  MPEG video *)
	CONST CID_MPEG_VIDEO_ENCODING* = CID_MPEG_BASE+200;
	TYPE v4l2_mpeg_video_encoding* = SIGNED32;
	CONST 
		MPEG_VIDEO_ENCODING_MPEG_1* = 0;
		MPEG_VIDEO_ENCODING_MPEG_2* = 1;
		MPEG_VIDEO_ENCODING_MPEG_4_AVC* = 2;	
		CID_MPEG_VIDEO_ASPECT* = CID_MPEG_BASE+201;
		
	TYPE v4l2_mpeg_video_aspect* = SIGNED32;
	CONST 
		MPEG_VIDEO_ASPECT_1x1* = 0;
		MPEG_VIDEO_ASPECT_4x3* = 1;
		MPEG_VIDEO_ASPECT_16x9* = 2;
		MPEG_VIDEO_ASPECT_221x100* = 3;
	
	 	CID_MPEG_VIDEO_B_FRAMES* = CID_MPEG_BASE+202;
	 	CID_MPEG_VIDEO_GOP_SIZE* = CID_MPEG_BASE+203;
	 	CID_MPEG_VIDEO_GOP_CLOSURE* = CID_MPEG_BASE+204;
	 	CID_MPEG_VIDEO_PULLDOWN* = CID_MPEG_BASE+205;
	 	CID_MPEG_VIDEO_BITRATE_MODE* = CID_MPEG_BASE+206;
	 	
	TYPE v4l2_mpeg_video_bitrate_mode* = SIGNED32;
	CONST 
		MPEG_VIDEO_BITRATE_MODE_VBR* = 0;
		MPEG_VIDEO_BITRATE_MODE_CBR* = 1;
	
		CID_MPEG_VIDEO_BITRATE* = CID_MPEG_BASE+207;
		CID_MPEG_VIDEO_BITRATE_PEAK* = CID_MPEG_BASE+208;
		CID_MPEG_VIDEO_TEMPORAL_DECIMATION* = CID_MPEG_BASE+209;
		CID_MPEG_VIDEO_MUTE* = CID_MPEG_BASE+210;
		CID_MPEG_VIDEO_MUTE_YUV* = CID_MPEG_BASE+211;
	
		(*  MPEG-class control IDs specific to the CX2341x driver as defined by V4L2 *)
		CID_MPEG_CX2341X_BASE* = CTRL_CLASS_MPEG + 01000H;
		CID_MPEG_CX2341X_VIDEO_SPATIAL_FILTER_MODE* = CID_MPEG_CX2341X_BASE+0;
		
	TYPE v4l2_mpeg_cx2341x_video_spatial_filter_mode* = SIGNED32;
	CONST 
		MPEG_CX2341X_VIDEO_SPATIAL_FILTER_MODE_MANUAL* = 0;
		MPEG_CX2341X_VIDEO_SPATIAL_FILTER_MODE_AUTO* = 1;
	
	 	CID_MPEG_CX2341X_VIDEO_SPATIAL_FILTER* = CID_MPEG_CX2341X_BASE+1;
	 	CID_MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE* = CID_MPEG_CX2341X_BASE+2;
	 	
	TYPE v4l2_mpeg_cx2341x_video_luma_spatial_filter_type* = SIGNED32;
	CONST 
		MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE_OFF* = 0;
		MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE_1D_HOR* = 1;
		MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE_1D_VERT* = 2;
		MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE_2D_HV_SEPARABLE* = 3;
		MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE_2D_SYM_NON_SEPARABLE* = 4;
	
		CID_MPEG_CX2341X_VIDEO_CHROMA_SPATIAL_FILTER_TYPE* = CID_MPEG_CX2341X_BASE+3;
		
	TYPE v4l2_mpeg_cx2341x_video_chroma_spatial_filter_type* = SIGNED32;
	CONST 
		MPEG_CX2341X_VIDEO_CHROMA_SPATIAL_FILTER_TYPE_OFF* = 0;
		MPEG_CX2341X_VIDEO_CHROMA_SPATIAL_FILTER_TYPE_1D_HOR* = 1;
	
		CID_MPEG_CX2341X_VIDEO_TEMPORAL_FILTER_MODE* = CID_MPEG_CX2341X_BASE+4;
		
	TYPE v4l2_mpeg_cx2341x_video_temporal_filter_mode* = SIGNED32;
	CONST 
		MPEG_CX2341X_VIDEO_TEMPORAL_FILTER_MODE_MANUAL* = 0;
		MPEG_CX2341X_VIDEO_TEMPORAL_FILTER_MODE_AUTO* = 1;
	
	 	CID_MPEG_CX2341X_VIDEO_TEMPORAL_FILTER* = CID_MPEG_CX2341X_BASE+5;
	 	CID_MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE* = CID_MPEG_CX2341X_BASE+6;
	 	
	TYPE v4l2_mpeg_cx2341x_video_median_filter_type* = SIGNED32;
	CONST 
		MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE_OFF* = 0;
		MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE_HOR* = 1;
		MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE_VERT* = 2;
		MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE_HOR_VERT* = 3;
		MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE_DIAG* = 4;
	
	 	CID_MPEG_CX2341X_VIDEO_LUMA_MEDIAN_FILTER_BOTTOM* = CID_MPEG_CX2341X_BASE+7;
	 	CID_MPEG_CX2341X_VIDEO_LUMA_MEDIAN_FILTER_TOP* = CID_MPEG_CX2341X_BASE+8;
	 	CID_MPEG_CX2341X_VIDEO_CHROMA_MEDIAN_FILTER_BOTTOM* = CID_MPEG_CX2341X_BASE+9;
	 	CID_MPEG_CX2341X_VIDEO_CHROMA_MEDIAN_FILTER_TOP* = CID_MPEG_CX2341X_BASE+10;
	 	CID_MPEG_CX2341X_STREAM_INSERT_NAV_PACKETS* = CID_MPEG_CX2341X_BASE+11;
	
		(*  Camera class control IDs *)
		CID_CAMERA_CLASS_BASE* = CTRL_CLASS_CAMERA + 0900H;
		CID_CAMERA_CLASS* = CTRL_CLASS_CAMERA + 1;
	
		CID_EXPOSURE_AUTO* = CID_CAMERA_CLASS_BASE+1;
		
	TYPE v4l2_exposure_auto_type* = SIGNED32 ;
	CONST 
		EXPOSURE_AUTO* = 0;
		EXPOSURE_MANUAL* = 1;
		EXPOSURE_SHUTTER_PRIORITY* = 2;
		EXPOSURE_APERTURE_PRIORITY* = 3;
		
	 	CID_EXPOSURE_ABSOLUTE* = CID_CAMERA_CLASS_BASE+2;
	
	 	CID_EXPOSURE_AUTO_PRIORITY* = CID_CAMERA_CLASS_BASE+3;
	
	 	CID_PAN_RELATIVE* = CID_CAMERA_CLASS_BASE+4;
	 	CID_TILT_RELATIVE* = CID_CAMERA_CLASS_BASE+5;
	 	CID_PAN_RESET* = CID_CAMERA_CLASS_BASE+6;
	 	CID_TILT_RESET* = CID_CAMERA_CLASS_BASE+7;
	
	 	CID_PAN_ABSOLUTE* = CID_CAMERA_CLASS_BASE+8;
	 	CID_TILT_ABSOLUTE* = CID_CAMERA_CLASS_BASE+9;
	
	 	CID_FOCUS_ABSOLUTE* = CID_CAMERA_CLASS_BASE+10;
	 	CID_FOCUS_RELATIVE* = CID_CAMERA_CLASS_BASE+11;
	 	CID_FOCUS_AUTO* = CID_CAMERA_CLASS_BASE+12;
	
	 	CID_ZOOM_ABSOLUTE* = CID_CAMERA_CLASS_BASE+13;
	 	CID_ZOOM_RELATIVE* = CID_CAMERA_CLASS_BASE+14;
	 	CID_ZOOM_CONTINUOUS* = CID_CAMERA_CLASS_BASE+15;
	
	 	CID_PRIVACY* = CID_CAMERA_CLASS_BASE+16;
	
	 	CID_IRIS_ABSOLUTE* = CID_CAMERA_CLASS_BASE+17;
	 	CID_IRIS_RELATIVE* = CID_CAMERA_CLASS_BASE+18;
	
		(* FM Modulator class control IDs *)
		CID_FM_TX_CLASS_BASE* = CTRL_CLASS_FM_TX + 0900H;
		CID_FM_TX_CLASS* = CTRL_CLASS_FM_TX + 1;
	
		CID_RDS_TX_DEVIATION* = CID_FM_TX_CLASS_BASE + 1;
		CID_RDS_TX_PI* = CID_FM_TX_CLASS_BASE + 2;
		CID_RDS_TX_PTY* = CID_FM_TX_CLASS_BASE + 3;
		CID_RDS_TX_PS_NAME* = CID_FM_TX_CLASS_BASE + 5;
		CID_RDS_TX_RADIO_TEXT* = CID_FM_TX_CLASS_BASE + 6;
	
		CID_AUDIO_LIMITER_ENABLED* = CID_FM_TX_CLASS_BASE + 64;
		CID_AUDIO_LIMITER_RELEASE_TIME* = CID_FM_TX_CLASS_BASE + 65;
		CID_AUDIO_LIMITER_DEVIATION* = CID_FM_TX_CLASS_BASE + 66;
	
		CID_AUDIO_COMPRESSION_ENABLED* = CID_FM_TX_CLASS_BASE + 80;
		CID_AUDIO_COMPRESSION_GAIN* = CID_FM_TX_CLASS_BASE + 81;
		CID_AUDIO_COMPRESSION_THRESHOLD* = CID_FM_TX_CLASS_BASE + 82;
		CID_AUDIO_COMPRESSION_ATTACK_TIME* = CID_FM_TX_CLASS_BASE + 83;
		CID_AUDIO_COMPRESSION_RELEASE_TIME* = CID_FM_TX_CLASS_BASE + 84;
	
		CID_PILOT_TONE_ENABLED* = CID_FM_TX_CLASS_BASE + 96;
		CID_PILOT_TONE_DEVIATION* = CID_FM_TX_CLASS_BASE + 97;
		CID_PILOT_TONE_FREQUENCY* = CID_FM_TX_CLASS_BASE + 98;
	
		CID_TUNE_PREEMPHASIS* = CID_FM_TX_CLASS_BASE + 112;
		
	TYPE v4l2_preemphasis* = SIGNED32;
	CONST 
		PREEMPHASIS_DISABLED* = 0;
		PREEMPHASIS_50_uS* = 1;
		PREEMPHASIS_75_uS* = 2;
	
		CID_TUNE_POWER_LEVEL* = CID_FM_TX_CLASS_BASE + 113;
		CID_TUNE_ANTENNA_CAPACITOR* = CID_FM_TX_CLASS_BASE + 114;
	
	(*!	T U N I N G *)
	TYPE v4l2_tuner* = RECORD 
		index* : u32;
		name* : ARRAY 32 OF u8;
		type* : v4l2_tuner_type;
		capability* : SET32; (*! u32; *)
		rangelow* : u32;
		rangehigh* : u32;
		rxsubchans* : SET32; (*! u32 *)
		audmode* : u32;
		signal* : s32;
		afc* : s32;
		reserved* : ARRAY 4 OF u32;
	END;
	
	TYPE v4l2_modulator* = RECORD 
		index* : u32;
		name* : ARRAY 32 OF u8;
		capability* : SET32; (*! u32; *)
		rangelow* : u32;
		rangehigh* : u32;
		txsubchans* : u32;
		reserved* : ARRAY 4 OF u32;
	END;
	
	(*  Flags for the 'capability' field *)
	CONST 
		TUNER_CAP_LOW* = 0;
		TUNER_CAP_NORM* = 1;
		TUNER_CAP_STEREO* = 4;
		TUNER_CAP_LANG2* = 5;
		TUNER_CAP_SAP* = 5;
		TUNER_CAP_LANG1* = 6;
		TUNER_CAP_RDS* = 7;
		TUNER_CAP_RDS_BLOCK_IO* = 8;
		TUNER_CAP_RDS_CONTROLS* = 9;
	
		(*  Flags for the 'rxsubchans' field *)
		TUNER_SUB_MONO* = 0;
		TUNER_SUB_STEREO* = 1;
		TUNER_SUB_LANG2* = 2;
		TUNER_SUB_SAP* = 2;
		TUNER_SUB_LANG1* = 3;
		TUNER_SUB_RDS* = 4;
	
		(*  Values for the 'audmode' field *)
		TUNER_MODE_MONO* = 00000H;
		TUNER_MODE_STEREO* = 00001H;
		TUNER_MODE_LANG2* = 00002H;
		TUNER_MODE_SAP* = 00002H;
		TUNER_MODE_LANG1* = 00003H;
		TUNER_MODE_LANG1_LANG2* = 00004H;
	
	TYPE v4l2_frequency* = RECORD 
		tuner* : u32;
		type* : v4l2_tuner_type;
		frequency* : u32;
		reserved* : ARRAY 8 OF u32;
	END;
	
	TYPE v4l2_hw_freq_seek* = RECORD 
		tuner* : u32;
		type* : v4l2_tuner_type;
		seek_upward* : u32;
		wrap_around* : u32;
		spacing* : u32;
		reserved* : ARRAY 7 OF u32;
	END;
	
	(*!	R D S *)
	
	TYPE v4l2_rds_data* = RECORD 
		lsb* : u8;
		msb* : u8;
		block* : u8;
	END;

	CONST 
		RDS_BLOCK_MSK* = 07H;
		RDS_BLOCK_A* = 0;
		RDS_BLOCK_B* = 1;
		RDS_BLOCK_C* = 2;
		RDS_BLOCK_D* = 3;
		RDS_BLOCK_C_ALT* = 4;
		RDS_BLOCK_INVALID* = 7;

		RDS_BLOCK_CORRECTED* = 040X;
		RDS_BLOCK_ERROR* = 080X;

	(*!	A U D I O  *)
TYPE v4l2_audio* = RECORD 
		index* : u32;
		name* : ARRAY 32 OF u8;
		capability* : SET32; (*!u32; *)
		mode* : u32;
		reserved* : ARRAY 2 OF u32;
	END;
	
	(*  Flags for the 'capability' field *)
	CONST  
		AUDCAP_STEREO* = 0;
	 	AUDCAP_AVL* = 1;
	 
	 (*  Flags for the 'mode' field *)
	AUDMODE_AVL* = 000001H;
	
	TYPE v4l2_audioout* = RECORD 
		index* : u32;
		name* : ARRAY 32 OF u8;
		capability* : SET32; (*! u32 *)
		mode* : u32;
		reserved* : ARRAY 2 OF u32;
	END;
	
	(*!
		M P E G   S E R V I C E S
	
		NOTE: EXPERIMENTAL API
	*)
	(*!  #if 1 *)
	
 CONST 
	ENC_IDX_FRAME_I* = 0;
	ENC_IDX_FRAME_P* = 1;
	ENC_IDX_FRAME_B* = 2;
	ENC_IDX_FRAME_MASK* = 0FH;
	
	TYPE v4l2_enc_idx_entry* = RECORD 
		offset* : u64;
		pts* : u64;
		length* : u32;
		flags* : SET32; (*! u32 *)
		reserved* : ARRAY 2 OF u32;
	END;
	
	CONST ENC_IDX_ENTRIES* = 64;
	TYPE v4l2_enc_idx* = RECORD 
		entries* : u32;
		entries_cap* : u32;
		reserved* : ARRAY 4 OF u32;
		entry* : ARRAY ENC_IDX_ENTRIES OF v4l2_enc_idx_entry;
	END;
	
	
CONST 
	ENC_CMD_START* = 0;
	 ENC_CMD_STOP* = 1;
	 ENC_CMD_PAUSE* = 2;
	 ENC_CMD_RESUME* = 3;
	
	(* Flags for ENC_CMD_STOP *)
	CONST ENC_CMD_STOP_AT_GOP_END* = 0;
	
	TYPE DataRaw*=RECORD data*: ARRAY 8 OF u32; END;
	TYPE v4l2_encoder_cmd* = RECORD 
		cmd* : u32;
		flags* : SET32; (*! u32 *)
		raw*: DataRaw;
				(*
				union:
				data* : ARRAY 8 OF u32;
				*)
	END;

	(*! #endif *)
	
	
	(*!
	 *	D A T A   S E R V I C E S   ( V B I )
	 *
	 *	Data services API by Michael Schime
	 *)
	
	(* Raw VBI *)
	TYPE v4l2_vbi_format* = RECORD 
		sampling_rate* : u32;		(* in 1 Hz *)
		offset* : u32;
		samples_per_line* : u32;
		sample_format* : u32;		(* PIX_FMT_* *)
		start* : ARRAY 2 OF s32;
		count* : ARRAY 2 OF u32;
		flags* : SET32; (* u32 *)			(* VBI_* *)
		reserved* : ARRAY 2 OF u32;		(* must be zero *)
	END;
	
	(*!  VBI flags  *)
	
	
	CONST VBI_UNSYNC* = 0;
	CONST VBI_INTERLACED* = 1;
	
	(* Sliced VBI
	 *
	 *    This implements is a proposal V4L2 API to allow SLICED VBI
	 * required for some hardware encoders. It should change without
	 * notice in the definitive implementation.
	 *)
	
	TYPE 
	Array24*=ARRAY 24 OF u16;
	v4l2_sliced_vbi_format* = RECORD 
		service_set*: u16;
		(* service_lines[0][...] specifies lines 0-23 (1-23 used) of the first field
		service_lines[1][...] specifies lines 0-23 (1-23 used) of the second field
		(equals frame lines 313-336 for 625 line video
		standards, 263-286 for 525 line standards) *)
		service_lines*: ARRAY 2  OF Array24;
		io_size*: u32;
		reserved*: ARRAY 2 OF u32;            (* must be zero *)
	END;
	
	(* Teletext World System Teletext
	   (WST), defined on ITU-R BT.653-2 *)
	CONST 
		SLICED_TELETEXT_B* = 00001H;
		(* Video Program System, defined on ETS 300 231*)
		SLICED_VPS* = 00400H;
		(* Closed Caption, defined on EIA-608 *)
		SLICED_CAPTION_525* = 01000H;
		(* Wide Screen System, defined on ITU-R BT1119.1 *)
		SLICED_WSS_625* = 04000H;
	
		SLICED_VBI_525* = SLICED_CAPTION_525;
		SLICED_VBI_625* = SLICED_TELETEXT_B + SLICED_VPS + SLICED_WSS_625;
	
	TYPE v4l2_sliced_vbi_cap* = RECORD 
		service_set*: u16;
		(* service_lines[0][...] specifies lines 0-23 (1-23 used) of the first field
		service_lines[1][...] specifies lines 0-23 (1-23 used) of the second field
		(equals frame lines 313-336 for 625 line video
		standards, 263-286 for 525 line standards) *)
		service_lines*: ARRAY 2, 24 OF u16;
		type*: v4l2_buf_type;
		reserved*: ARRAY 3 OF u32;    (* must be 0 *)
	END;
	
	TYPE v4l2_sliced_vbi_data* = RECORD 
		id*: u32;
		field*: u32;          (* 0: first field, 1: second field *)
		line*: u32;           (* 1-23 *)
		reserved*: u32;       (* must be 0 *)
		data*: ARRAY 48 OF u8;
	END;
	
	(*
	 * Sliced VBI data inserted into MPEG Streams
	 *)
	
	(*
	 * MPEG_STREAM_VBI_FMT_IVTV:
	 *
	 * Structure of payload contained in an MPEG 2 Private Stream 1 PES Packet in an
	 * MPEG-2 Program Pack that contains MPEG_STREAM_VBI_FMT_IVTV Sliced VBI
	 * data
	 *
	 * Note, the MPEG-2 Program Pack and Private Stream 1 PES packet header
	 * definitions are not included here.  See the MPEG-2 specifications for details
	 * on these headers.
	 *)
	
	(* Line type IDs *)
	CONST 
		MPEG_VBI_IVTV_TELETEXT_B* = 1;
		MPEG_VBI_IVTV_CAPTION_525* = 4;
		MPEG_VBI_IVTV_WSS_625* = 5;
		MPEG_VBI_IVTV_VPS* = 7;
	
	TYPE v4l2_mpeg_vbi_itv0_line* = RECORD 
		id*: u8;	(* One of MPEG_VBI_IVTV_* above *)
		data*: ARRAY 42 OF u8;	(* Sliced VBI data for the line *)
	END;

(*	TYPE v4l2_mpeg_vbi_itv0* = RECORD 
		linemask: ARRAY 2 OF __le32; (* Bitmasks of VBI service lines present *)
		line: ARRAY 35 OF v4l2_mpeg_vbi_itv0_line;
	END;
*)	
	TYPE v4l2_mpeg_vbi_ITV0* = RECORD 
		line*: ARRAY 36 OF v4l2_mpeg_vbi_itv0_line;
	END;

	CONST MPEG_VBI_IVTV_MAGIC0* = 'itv0';
		MPEG_VBI_IVTV_MAGIC1* = 'ITV0';
(*	
	TYPE v4l2_mpeg_vbi_fmt_ivtv* = RECORD 
		magic: ARRAY 4 OF u8;
		TYPE * = RECORD 
			CASE union:SIGNED16 OF 
			itv0: v4l2_mpeg_vbi_itv0;
			ITV0: v4l2_mpeg_vbi_ITV0;
		END;
	END v4l2_mpeg_vbi_fmt_ivtv;
	
	*)
	

	(*!	A G G R E G A T E   S T R U C T U R E S *)


(**
 * struct v4l2_plane_pix_format - additional, per-plane format definition
 * @sizeimage:		maximum size in bytes required for data, for which
 *			this plane will be used
 * @bytesperline:	distance in bytes between the leftmost pixels in two
 *			adjacent lines
 *)
TYPE v4l2_plane_pix_format* = RECORD
			sizeimage*: u32;
			bytesperline*: u16;
			reserved*: ARRAY 7 OF u16;
		END;

(**
  * struct v4l2_pix_format_mplane - multiplanar format definition
 * @width:		image width in pixels
 * @height:		image height in pixels
 * @pixelformat:	little endian four character code (fourcc)
 * @field:		enum v4l2_field; field order (for interlaced video)
 * @colorspace:		enum v4l2_colorspace; supplemental to pixelformat
 * @plane_fmt:		per-plane information
 * @num_planes:		number of planes for this format
 * @flags:		format flags (V4L2_PIX_FMT_FLAG_*
 * @ycbcr_enc:		enum v4l2_ycbcr_encoding, Y'CbCr encoding
 * @quantization:	enum v4l2_quantization, colorspace quantization
 * @xfer_func:		enum v4l
 *)
 
TYPE v4l2_pix_format_mplane* = RECORD
			width*: u32;
			height*: u32;
			pixelformat* : u32;
			field*: v4l2_field;
			colorspace*: v4l2_colorspace;
			plane_fmt*: ARRAY VIDEO_MAX_PLANES OF v4l2_plane_pix_format;			
			num_planes* : u8;
			flags*: u8;
			union*: u8; (* ycbcr_enc,  hsv_enc;*)
			quantization*: u8;
			xfer_func*: u8;		
			reserved* : ARRAY 7 OF u8;
	END;


	(* Stream data format *)
	TYPE 
			D200* =  ARRAY  200 OF u8;  (*! CHECK SIZE   *) 
	          
		(*! NOTE: sizeof v4l2_format is 204 bytes on 32 bit os
	        208 bytes on 64 bit os
	        *)
	TYPE v4l2_format* = RECORD 
		type*: LONGINTEGER;
		
	(*	
			union: type cast fmt according to type; ex:  pix := SYSTEM.VAL(v4l2_pix_format, fmt)
			pix* : v4l2_pix_format; (* BUF_TYPE_VIDEO_CAPTURE *)
			pix_mp* : v4l2_pix_format_mplane; (* BUF_TYPE_VIDEO_CAPTURE_MPLANE *)
			win* : v4l2_window;     (* BUF_TYPE_VIDEO_OVERLAY *)
			vbi* : v4l2_vbi_format;     (* BUF_TYPE_VBI_CAPTURE *)
			sliced* : v4l2_sliced_vbi_format;  (* BUF_TYPE_SLICED_VBI_CAPTURE *)
			
			raw_data* : ARRAY 200 OF u8;                   (* user-defined *)

	*)	
		(*x {FICTIVE=4}: SIGNED32;*)
		 fmt* : D200;

	END;
	
	
	(*	Stream type-dependent parameters  *)
	TYPE v4l2_streamparm* = RECORD 
		type* : v4l2_buf_type;
	(*	 
		union: type cast parm according to type; ex:  capture := SYSTEM.VAL( v4l2_captureparm, parm)
			capture* : v4l2_captureparm;
			output* : v4l2_outputparm;
			raw_data* : ARRAY 200 OF u8;  (* user-defined *)
	*)
		parm*: D200;
	
	END;
	
	(*!	E V E N T S  *)
	
	CONST 
		EVENT_ALL* = 0;
		EVENT_VSYNC* = 1;
		EVENT_EOS* = 2;
		EVENT_PRIVATE_START* = 008000000H;
	
	(* Payload for EVENT_VSYNC *)
	TYPE v4l2_event_vsync* = RECORD 
		(* Can be FIELD_ANY, _NONE, _TOP or _BOTTOM *)
		field* : SIGNED32; (* address *)
	END;

	TYPE Data64* = ARRAY 64 OF CHAR;
	TYPE v4l2_event* = RECORD 
		type* : u32;
(*
		union: type cast u according to type; ex:  vsync := SYSTEM.VAL( v4l2_event_vsync, u)
		vsync:  v4l2_event_vsync;
		data: ARRAY 64 OF u8;
*)		
		u* : Data64; 

		pending* : u32; 
		sequence * : u32; 
		(*! timestamp: timespec; *)   (*! <------ neded timespec structure definition *)
		reserved* : ARRAY 9 OF u32; 
	END;
	
	TYPE v4l2_event_subscription* = RECORD 
		type* : u32;
		reserved* : ARRAY 7 OF u32;
	END;
	
	(*!
	 *	A D V A N C E D   D E B U G G I N G
	 *	NOTE: EXPERIMENTAL API, NEVER RELY ON THIS IN APPLICATIONS!
	 *	FOR DEBUGGING, TESTING AND INTERNAL USE ONLY! *)
	
	
	(* VIDIOC_DBG_G_REGISTER and VIDIOC_DBG_S_REGISTER *)
	
	CONST 
		CHIP_MATCH_HOST* = 0;  (* Match against chip ID on host (0 for the host) *)
		CHIP_MATCH_I2C_DRIVER* = 1;  (* Match against I2C driver name *)
		CHIP_MATCH_I2C_ADDR* = 2;  (* Match against I2C 7-bit address *)
		CHIP_MATCH_AC97* = 3;  (* Match against anciliary AC97 chip *)
	
	TYPE Data32* = ARRAY 32 OF CHAR;
	TYPE v4l2_dbg_match* = RECORD 
		type*: u32; (* Match type *)
		 (* Match this chip, meaning determined by type *)
		(* union:  type cast data according to type; ex:  addr := SYSTEM.VAL( u32, data) 
			1 : (addr: u32);
			| 2 : (name: ARRAY 32 OF CHAR);

		*)
		data*: Data32;
	END ;
	
	TYPE v4l2_dbg_register* = RECORD 
		match*: v4l2_dbg_match;
		size*: u32;	(* register size in bytes *)
		reg*: u64;
		val*: u64;
	END;
	 (* VIDIOC_DBG_G_CHIP_IDENT *)
	TYPE v4l2_dbg_chip_ident* = RECORD 
		match*: v4l2_dbg_match;
		ident*: u32;       (* chip identifier as specified in <media/v4l2-chip-ident.h> *)
		revision*: u32;    (* chip revision, chip specific *)
	END;


(*!	I O C T L   C O D E S   F O R   V I D E O   D E V I C E S *)
VAR

	VIDIOC_QUERYCAP -,   
	VIDIOC_RESERVED -,   
	VIDIOC_ENUM_FMT-, 
	VIDIOC_G_FMT -,   
	VIDIOC_S_FMT -,   
	VIDIOC_REQBUFS -,   
	VIDIOC_QUERYBUF -,   
	VIDIOC_G_FBUF -,   
	VIDIOC_S_FBUF -,   
	VIDIOC_OVERLAY -,   
	VIDIOC_QBUF -,   
	VIDIOC_DQBUF -,  
	VIDIOC_STREAMON -,   
	VIDIOC_STREAMOFF -,   
	VIDIOC_G_PARM -,   
	VIDIOC_S_PARM -,   
	VIDIOC_G_STD -,   
	VIDIOC_S_STD -,   
	VIDIOC_ENUMSTD -,   
	VIDIOC_ENUMINPUT -,   
	VIDIOC_G_CTRL -,   
	VIDIOC_S_CTRL -,   
	VIDIOC_G_TUNER -,   
	VIDIOC_S_TUNER -,   
	VIDIOC_G_AUDIO -,   
	VIDIOC_S_AUDIO -,   
	VIDIOC_QUERYCTRL -,   
	VIDIOC_QUERYMENU -,   
	VIDIOC_G_INPUT -,   
	VIDIOC_S_INPUT -,  
	VIDIOC_G_OUTPUT -,   
	VIDIOC_S_OUTPUT -,   
	VIDIOC_ENUMOUTPUT -,   
	VIDIOC_G_AUDOUT -,   
	VIDIOC_S_AUDOUT -,   
	VIDIOC_G_MODULATOR -,   
	VIDIOC_S_MODULATOR -,   
	VIDIOC_G_FREQUENCY -,   
	VIDIOC_S_FREQUENCY -,  
	VIDIOC_CROPCAP -,   
	VIDIOC_G_CROP -,   
	VIDIOC_S_CROP -,   
	VIDIOC_G_JPEGCOMP -,   
	VIDIOC_S_JPEGCOMP -,   
	VIDIOC_QUERYSTD -,   
	VIDIOC_TRY_FMT -,   
	VIDIOC_ENUMAUDIO -,   
	VIDIOC_ENUMAUDOUT -,   
	VIDIOC_G_PRIORITY -,   
	VIDIOC_S_PRIORITY -,   
	VIDIOC_G_SLICED_VBI_CAP -,   
	VIDIOC_LOG_STATUS -,   
	VIDIOC_G_EXT_CTRLS -,   
	VIDIOC_S_EXT_CTRLS -,   
	VIDIOC_TRY_EXT_CTRLS -,   
	(* #if 1 *)
	VIDIOC_ENUM_FRAMESIZES -,   
	VIDIOC_ENUM_FRAMEINTERVALS -,   
	VIDIOC_G_ENC_INDEX -,   
	VIDIOC_ENCOxDER_CMD -,   (*! ??? *)
	VIDIOC_TRY_ENCOxDER_CMD -,   (*! ?? *)
	(* #endif *)
	
	(* #if 1 *)
	(* Experimental, meant for debugging, testing and internal use.
	Only implemented if CONFIG_VIDEO_ADV_DEBUG is defined.
	You must be root to use these ioctls. Never use these in applications! *)

	VIDIOC_DBG_S_REGISTER -,   
	VIDIOC_DBG_G_REGISTER -,   

	(* Experimental, meant for debugging, testing and internal use.
	Never use this ioctl in applications! *)
	VIDIOC_DBG_G_CHIP_IDENT -,   
	(* #endif *)

	VIDIOC_S_HW_FREQ_SEEK -,   
	VIDIOC_ENUM_DV_PRESETS -,   
	VIDIOC_S_DV_PRESET -,   
	VIDIOC_G_DV_PRESET -,   
	VIDIOC_QUERY_DV_PRESET -,   
	VIDIOC_S_DV_TIMINGS -,   
	VIDIOC_G_DV_TIMINGS -,   
	VIDIOC_DQEVENT -,   
	VIDIOC_SUBSCRIBE_EVENT -,   
	VIDIOC_UNSUBSCRIBE_EVENT - : SIGNED32;   


(*!  Pixel format FOURCC  depth  Description  *)
VAR
	(* RGB formats *)
	PIX_FMT_RGB332 - ,  
	PIX_FMT_RGB444 - , 
	PIX_FMT_RGB555 - ,
	PIX_FMT_RGB565 - , 
	PIX_FMT_RGB555X - , 
	PIX_FMT_RGB565X - , 
	PIX_FMT_BGR666 - , 
	PIX_FMT_BGR24 - , 
	PIX_FMT_RGB24 - , 
	PIX_FMT_BGR32 - , 
	PIX_FMT_RGB32 - , 

	(* Grey formats *)
	PIX_FMT_GREY - , 
	PIX_FMT_Y4 - , 
	PIX_FMT_Y6 - ,
	PIX_FMT_Y10 - , 
	PIX_FMT_Y16 - , 

	(* Palette formats *)
	PIX_FMT_PAL8 - , 

	(* Luminance+Chrominance formats *)
	PIX_FMT_YVU410 - , 
	PIX_FMT_YVU420 - , 
	PIX_FMT_YUYV - , 
	PIX_FMT_YYUV - , 
	PIX_FMT_YVYU - , 
	PIX_FMT_UYVY - , 
	PIX_FMT_VYUY - , 
	PIX_FMT_YUV422P - , 
	PIX_FMT_YUV411P - , 
	PIX_FMT_Y41P - , 
	PIX_FMT_YUV444 - , 
	PIX_FMT_YUV555 - , 
	PIX_FMT_YUV565 - , 
	PIX_FMT_YUV32 - , 
	PIX_FMT_YUV410 - , 
	PIX_FMT_YUV420 - , 
	PIX_FMT_HI240 - , 
	PIX_FMT_HM12 - , 
	
	(* two planes -- one Y, one Cr + Cb interleaved  *)
	PIX_FMT_NV12 - , 
	PIX_FMT_NV21 - , 
	PIX_FMT_NV16 - , 
	PIX_FMT_NV61 - , 
	
	(* Bayer formats - see http://www.siliconimaging.com/RGB%20Bayer.htm *)
	PIX_FMT_SBGGR8 - , 
	PIX_FMT_SGBRG8 - , 
	PIX_FMT_SGRBG8 - , 
	PIX_FMT_SRGGB8 - , 
	PIX_FMT_SBGGR10 - , 
	PIX_FMT_SGBRG10 - , 
	PIX_FMT_SGRBG10 - , 
	PIX_FMT_SRGGB10 - , 
	(* 10bit raw bayer DPCM compressed to 8 bits *)
	PIX_FMT_SGRBG10DPCM8 - , 
	(*
	* 10bit raw bayer, expanded to 16 bits
	* xxxxrrrrrrrrrrxxxxgggggggggg xxxxggggggggggxxxxbbbbbbbbbb...
	*)
	PIX_FMT_SBGGR16 - , 
	
	(* compressed formats *)
	PIX_FMT_MJPEG - , 
	PIX_FMT_JPEG - , 
	PIX_FMT_DV - , 
	PIX_FMT_MPEG - , 
	
	(*  Vendor-specific formats   *)
	PIX_FMT_CPIA1 - , 
	PIX_FMT_WNVA - , 
	PIX_FMT_SN9C10X - , 
	PIX_FMT_SN9C20X_I420 - , 
	PIX_FMT_PWC1 - , 
	PIX_FMT_PWC2 - , 
	PIX_FMT_ET61X251 - , 
	PIX_FMT_SPCA501 - , 
	PIX_FMT_SPCA505 - , 
	PIX_FMT_SPCA508 - , 
	PIX_FMT_SPCA561 - , 
	PIX_FMT_PAC207 - , 
	PIX_FMT_MR97310A - , 
	PIX_FMT_SN9C2028 - , 
	PIX_FMT_SQ905C - , 
	PIX_FMT_PJPG - , 
	PIX_FMT_OV511 - , 
	PIX_FMT_OV518 - , 
	PIX_FMT_STV0680 - , 
	PIX_FMT_TM6000 - , 
	PIX_FMT_CIT_YYVYUY - , 
	PIX_FMT_KONICA420 - : SIGNED32; 

(* Four-character-code (FOURCC) *)
PROCEDURE fourcc* (a, b, c, d: CHAR): SIGNED32;
BEGIN
	 RETURN ORD(d) * 1000000H + ORD(c) * 10000H + ORD(b) * 100H + ORD(a);
END fourcc;

PROCEDURE IOC (dir, type, nr, size: SIGNED32): SIGNED32;
BEGIN
	RETURN LSH(dir, IOC_DIRSHIFT) +
	LSH(type, IOC_TYPESHIFT) +
	LSH( nr, IOC_NRSHIFT) +
	LSH( size, IOC_SIZESHIFT);
END IOC;

	
(*!	Initialize I O C T L   C O D E S   F O R   V I D E O   D E V I C E S *)
 PROCEDURE InitCTLS();
 BEGIN

	VIDIOC_QUERYCAP := IOC(IOC_READ, ORD('V'),  0, SIZEOF(v4l2_capability));
	VIDIOC_RESERVED := IOC(IOC_NONE, ORD('V'),  1, 0);

	VIDIOC_ENUM_FMT := IOC( IOC_READ + IOC_WRITE, ORD('V'),  2, SIZEOF(v4l2_fmtdesc));
	(*! check size of v4l2_format *)
	VIDIOC_G_FMT := IOC(IOC_READ + IOC_WRITE, ORD('V'),  4, SIZEOF(v4l2_format));  
	VIDIOC_S_FMT := IOC(IOC_READ + IOC_WRITE, ORD('V'),  5,  SIZEOF(v4l2_format));
	VIDIOC_REQBUFS := IOC(IOC_READ + IOC_WRITE, ORD('V'),  8, SIZEOF(v4l2_requestbuffers));
	VIDIOC_QUERYBUF := IOC(IOC_READ + IOC_WRITE, ORD('V'),  9, SIZEOF(v4l2_buffer));
	VIDIOC_G_FBUF := IOC(IOC_READ, ORD('V'), 10, SIZEOF(v4l2_framebuffer));
	VIDIOC_S_FBUF := IOC(IOC_WRITE, ORD('V'), 11, SIZEOF(v4l2_framebuffer));
	VIDIOC_OVERLAY := IOC(IOC_WRITE, ORD('V'), 14, SIZEOF(SIGNED32)); (* int *)
	VIDIOC_QBUF := IOC(IOC_READ + IOC_WRITE, ORD('V'), 15, SIZEOF(v4l2_buffer));
	VIDIOC_DQBUF := IOC(IOC_READ + IOC_WRITE, ORD('V'), 17, SIZEOF(v4l2_buffer));
	VIDIOC_STREAMON := IOC(IOC_WRITE, ORD('V'), 18, SIZEOF(SIGNED32));
	VIDIOC_STREAMOFF := IOC(IOC_WRITE, ORD('V'), 19, SIZEOF(SIGNED32));
	VIDIOC_G_PARM := IOC(IOC_READ + IOC_WRITE, ORD('V'), 21, SIZEOF(v4l2_streamparm));
	VIDIOC_S_PARM := IOC(IOC_READ + IOC_WRITE, ORD('V'), 22, SIZEOF(v4l2_streamparm));
	VIDIOC_G_STD := IOC(IOC_READ, ORD('V'), 23, SIZEOF(v4l2_std_id));
	VIDIOC_S_STD := IOC(IOC_WRITE, ORD('V'), 24, SIZEOF(v4l2_std_id));

	VIDIOC_ENUMSTD := IOC(IOC_READ + IOC_WRITE, ORD('V'), 25, SIZEOF( v4l2_standard));
	VIDIOC_ENUMINPUT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 26, SIZEOF( v4l2_input));
	VIDIOC_G_CTRL := IOC(IOC_READ + IOC_WRITE, ORD('V'), 27, SIZEOF( v4l2_control));
	VIDIOC_S_CTRL := IOC(IOC_READ + IOC_WRITE, ORD('V'), 28, SIZEOF( v4l2_control));
	VIDIOC_G_TUNER := IOC(IOC_READ + IOC_WRITE, ORD('V'), 29, SIZEOF( v4l2_tuner));
	VIDIOC_S_TUNER := IOC(IOC_WRITE, ORD('V'), 30, SIZEOF( v4l2_tuner));

	VIDIOC_G_AUDIO := IOC(IOC_READ, ORD('V'), 33, SIZEOF(v4l2_audio));
	VIDIOC_S_AUDIO := IOC(IOC_WRITE, ORD('V'), 34, SIZEOF(v4l2_audio));

	VIDIOC_QUERYCTRL := IOC(IOC_READ + IOC_WRITE, ORD('V'), 36, SIZEOF( v4l2_queryctrl));
	VIDIOC_QUERYMENU := IOC(IOC_READ + IOC_WRITE, ORD('V'), 37, SIZEOF( v4l2_querymenu));
	VIDIOC_G_INPUT := IOC(IOC_READ, ORD('V'), 38, SIZEOF(u32));
	VIDIOC_S_INPUT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 39, SIZEOF(u32));
	VIDIOC_G_OUTPUT := IOC(IOC_READ, ORD('V'), 46, SIZEOF(u32));
	VIDIOC_S_OUTPUT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 47, SIZEOF(u32));

	VIDIOC_ENUMOUTPUT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 48, SIZEOF( v4l2_output));
	VIDIOC_G_AUDOUT := IOC(IOC_READ, ORD('V'), 49, SIZEOF( v4l2_audioout));
	VIDIOC_S_AUDOUT := IOC(IOC_WRITE, ORD('V'), 50, SIZEOF( v4l2_audioout));
	VIDIOC_G_MODULATOR := IOC(IOC_READ + IOC_WRITE, ORD('V'), 54, SIZEOF( v4l2_modulator));
	VIDIOC_S_MODULATOR := IOC(IOC_WRITE, ORD('V'), 55, SIZEOF( v4l2_modulator));
	 
	 
	VIDIOC_G_FREQUENCY := IOC(IOC_READ + IOC_WRITE, ORD('V'), 56, SIZEOF(v4l2_frequency));
	VIDIOC_S_FREQUENCY := IOC(IOC_WRITE, ORD('V'), 57, SIZEOF(v4l2_frequency));
	VIDIOC_CROPCAP := IOC(IOC_READ + IOC_WRITE, ORD('V'), 58, SIZEOF(v4l2_cropcap));
	VIDIOC_G_CROP := IOC(IOC_READ + IOC_WRITE, ORD('V'), 59, SIZEOF(v4l2_crop));
	
	VIDIOC_S_CROP := IOC(IOC_WRITE, ORD('V'), 60, SIZEOF(v4l2_crop));

	VIDIOC_G_JPEGCOMP := IOC(IOC_READ, ORD('V'), 61, SIZEOF( v4l2_jpegcompression));
	VIDIOC_S_JPEGCOMP := IOC(IOC_WRITE, ORD('V'), 62, SIZEOF( v4l2_jpegcompression));
	VIDIOC_QUERYSTD := IOC(IOC_READ, ORD('V'), 63, SIZEOF(v4l2_std_id));
	VIDIOC_TRY_FMT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 64, SIZEOF( v4l2_format));
	VIDIOC_ENUMAUDIO := IOC(IOC_READ + IOC_WRITE, ORD('V'), 65, SIZEOF( v4l2_audio));
	VIDIOC_ENUMAUDOUT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 66, SIZEOF( v4l2_audioout));
	VIDIOC_G_PRIORITY := IOC(IOC_READ, ORD('V'), 67, SIZEOF(v4l2_priority));
	VIDIOC_S_PRIORITY := IOC(IOC_WRITE, ORD('V'), 68, SIZEOF(v4l2_priority));
	VIDIOC_G_SLICED_VBI_CAP := IOC(IOC_READ + IOC_WRITE, ORD('V'), 69, SIZEOF( v4l2_sliced_vbi_cap));
	VIDIOC_LOG_STATUS := IOC(IOC_NONE, ORD('V'), 70, 0); 
	VIDIOC_G_EXT_CTRLS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 71, SIZEOF( v4l2_ext_controls));
	VIDIOC_S_EXT_CTRLS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 72, SIZEOF( v4l2_ext_controls));
	VIDIOC_TRY_EXT_CTRLS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 73, SIZEOF( v4l2_ext_controls));
	(* #if 1 *)
	VIDIOC_ENUM_FRAMESIZES := IOC(IOC_READ + IOC_WRITE, ORD('V'), 74, SIZEOF( v4l2_frmsizeenum));
	VIDIOC_ENUM_FRAMEINTERVALS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 75, SIZEOF( v4l2_frmivalenum));
	VIDIOC_G_ENC_INDEX := IOC(IOC_READ, ORD('V'), 76, SIZEOF( v4l2_enc_idx));
	VIDIOC_ENCOxDER_CMD := IOC(IOC_READ + IOC_WRITE, ORD('V'), 77, SIZEOF( v4l2_encoder_cmd));
	VIDIOC_TRY_ENCOxDER_CMD := IOC(IOC_READ + IOC_WRITE, ORD('V'), 78, SIZEOF( v4l2_encoder_cmd));
	(* #endif *)

	(* #if 1 *)
	(* Experimental, meant for debugging, testing and internal use.
	Only implemented if CONFIG_VIDEO_ADV_DEBUG is defined.
	You must be root to use these ioctls. Never use these in applications! *)
	VIDIOC_DBG_S_REGISTER := IOC(IOC_WRITE, ORD('V'), 79, SIZEOF( v4l2_dbg_register));
	VIDIOC_DBG_G_REGISTER := IOC(IOC_READ + IOC_WRITE, ORD('V'), 80, SIZEOF( v4l2_dbg_register));

	(* Experimental, meant for debugging, testing and internal use.
	Never use this ioctl in applications! *)
	VIDIOC_DBG_G_CHIP_IDENT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 81, SIZEOF( v4l2_dbg_chip_ident));
	(* #endif *)

	VIDIOC_S_HW_FREQ_SEEK := IOC(IOC_WRITE, ORD('V'), 82, SIZEOF( v4l2_hw_freq_seek));
	VIDIOC_ENUM_DV_PRESETS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 83, SIZEOF( v4l2_dv_enum_preset));
	VIDIOC_S_DV_PRESET := IOC(IOC_READ + IOC_WRITE, ORD('V'), 84, SIZEOF( v4l2_dv_preset));
	VIDIOC_G_DV_PRESET := IOC(IOC_READ + IOC_WRITE, ORD('V'), 85, SIZEOF( v4l2_dv_preset));
	VIDIOC_QUERY_DV_PRESET := IOC(IOC_READ, ORD('V'),  86, SIZEOF( v4l2_dv_preset));
	VIDIOC_S_DV_TIMINGS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 87, SIZEOF( v4l2_dv_timings));
	VIDIOC_G_DV_TIMINGS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 88, SIZEOF( v4l2_dv_timings));
	VIDIOC_DQEVENT := IOC(IOC_READ, ORD('V'), 89, SIZEOF( v4l2_event));
	VIDIOC_SUBSCRIBE_EVENT := IOC(IOC_WRITE, ORD('V'), 90, SIZEOF( v4l2_event_subscription));
	VIDIOC_UNSUBSCRIBE_EVENT := IOC(IOC_WRITE, ORD('V'), 91, SIZEOF( v4l2_event_subscription));

(*	 BASE_VIDIOC_PRIVATE := 192; *)		(* 192-255 are private *)

	(* -----     Pixel format   FOURCC  depth  Description ------ *)

	(* RGB formats *)
	PIX_FMT_RGB332 := fourcc('R', 'G', 'B', '1'); (*  8  RGB-3-3-2     *)
	PIX_FMT_RGB444 := fourcc('R', '4', '4', '4'); (* 16  xxxxrrrr ggggbbbb *)
	PIX_FMT_RGB555 := fourcc('R', 'G', 'B', 'O'); (* 16  RGB-5-5-5     *)
	PIX_FMT_RGB565 := fourcc('R', 'G', 'B', 'P'); (* 16  RGB-5-6-5     *)
	PIX_FMT_RGB555X := fourcc('R', 'G', 'B', 'Q'); (* 16  RGB-5-5-5 BE  *)
	PIX_FMT_RGB565X := fourcc('R', 'G', 'B', 'R'); (* 16  RGB-5-6-5 BE  *)
	PIX_FMT_BGR666 := fourcc('B', 'G', 'R', 'H'); (* 18  BGR-6-6-6	  *)
	PIX_FMT_BGR24 := fourcc('B', 'G', 'R', '3'); (* 24  BGR-8-8-8     *)
	PIX_FMT_RGB24 := fourcc('R', 'G', 'B', '3'); (* 24  RGB-8-8-8     *)
	PIX_FMT_BGR32 := fourcc('B', 'G', 'R', '4'); (* 32  BGR-8-8-8-8   *)
	PIX_FMT_RGB32 := fourcc('R', 'G', 'B', '4'); (* 32  RGB-8-8-8-8   *)

	(* Grey formats *)
	PIX_FMT_GREY := fourcc('G', 'R', 'E', 'Y'); (*  8  Greyscale     *)
	PIX_FMT_Y4 := fourcc('Y', '0', '4', ' '); (*  4  Greyscale     *)
	PIX_FMT_Y6 := fourcc('Y', '0', '6', ' '); (*  6  Greyscale     *)
	PIX_FMT_Y10 := fourcc('Y', '1', '0', ' '); (* 10  Greyscale     *)
	PIX_FMT_Y16 := fourcc('Y', '1', '6', ' '); (* 16  Greyscale     *)

	(* Palette formats *)
	PIX_FMT_PAL8 := fourcc('P', 'A', 'L', '8'); (*  8  8-bit palette *)

	(* Luminance+Chrominance formats *)
	PIX_FMT_YVU410 := fourcc('Y', 'V', 'U', '9'); (*  9  YVU 4:1:0     *)
	PIX_FMT_YVU420 := fourcc('Y', 'V', '1', '2'); (* 12  YVU 4:2:0     *)
	PIX_FMT_YUYV := fourcc('Y', 'U', 'Y', 'V'); (* 16  YUV 4:2:2     *)
	PIX_FMT_YYUV := fourcc('Y', 'Y', 'U', 'V'); (* 16  YUV 4:2:2     *)
	PIX_FMT_YVYU := fourcc('Y', 'V', 'Y', 'U'); (* 16 YVU 4:2:2 *)
	PIX_FMT_UYVY := fourcc('U', 'Y', 'V', 'Y'); (* 16  YUV 4:2:2     *)
	PIX_FMT_VYUY := fourcc('V', 'Y', 'U', 'Y'); (* 16  YUV 4:2:2     *)
	PIX_FMT_YUV422P := fourcc('4', '2', '2', 'P'); (* 16  YVU422 planar *)
	PIX_FMT_YUV411P := fourcc('4', '1', '1', 'P'); (* 16  YVU411 planar *)
	PIX_FMT_Y41P := fourcc('Y', '4', '1', 'P'); (* 12  YUV 4:1:1     *)
	PIX_FMT_YUV444 := fourcc('Y', '4', '4', '4'); (* 16  xxxxyyyy uuuuvvvv *)
	PIX_FMT_YUV555 := fourcc('Y', 'U', 'V', 'O'); (* 16  YUV-5-5-5     *)
	PIX_FMT_YUV565 := fourcc('Y', 'U', 'V', 'P'); (* 16  YUV-5-6-5     *)
	PIX_FMT_YUV32 := fourcc('Y', 'U', 'V', '4'); (* 32  YUV-8-8-8-8   *)
	PIX_FMT_YUV410 := fourcc('Y', 'U', 'V', '9'); (*  9  YUV 4:1:0     *)
	PIX_FMT_YUV420 := fourcc('Y', 'U', '1', '2'); (* 12  YUV 4:2:0     *)
	PIX_FMT_HI240 := fourcc('H', 'I', '2', '4'); (*  8  8-bit color   *)
	PIX_FMT_HM12 := fourcc('H', 'M', '1', '2'); (*  8  YUV 4:2:0 16x16 macroblocks *)

	(* two planes -- one Y, one Cr + Cb interleaved  *)
	PIX_FMT_NV12 := fourcc('N', 'V', '1', '2'); (* 12  Y/CbCr 4:2:0  *)
	PIX_FMT_NV21 := fourcc('N', 'V', '2', '1'); (* 12  Y/CrCb 4:2:0  *)
	PIX_FMT_NV16 := fourcc('N', 'V', '1', '6'); (* 16  Y/CbCr 4:2:2  *)
	PIX_FMT_NV61 := fourcc('N', 'V', '6', '1'); (* 16  Y/CrCb 4:2:2  *)
	
	(* Bayer formats - see http://www.siliconimaging.com/RGB%20Bayer.htm *)
	PIX_FMT_SBGGR8 := fourcc('B', 'A', '8', '1'); (*  8  BGBG.. GRGR.. *)
	PIX_FMT_SGBRG8 := fourcc('G', 'B', 'R', 'G'); (*  8  GBGB.. RGRG.. *)
	PIX_FMT_SGRBG8 := fourcc('G', 'R', 'B', 'G'); (*  8  GRGR.. BGBG.. *)
	PIX_FMT_SRGGB8 := fourcc('R', 'G', 'G', 'B'); (*  8  RGRG.. GBGB.. *)
	PIX_FMT_SBGGR10 := fourcc('B', 'G', '1', '0'); (* 10  BGBG.. GRGR.. *)
	PIX_FMT_SGBRG10 := fourcc('G', 'B', '1', '0'); (* 10  GBGB.. RGRG.. *)
	PIX_FMT_SGRBG10 := fourcc('B', 'A', '1', '0'); (* 10  GRGR.. BGBG.. *)
	PIX_FMT_SRGGB10 := fourcc('R', 'G', '1', '0'); (* 10  RGRG.. GBGB.. *)
	(* 10bit raw bayer DPCM compressed to 8 bits *)
	PIX_FMT_SGRBG10DPCM8 := fourcc('B', 'D', '1', '0');
	(*
	 10bit raw bayer, expanded to 16 bits
	 xxxxrrrrrrrrrrxxxxgggggggggg xxxxggggggggggxxxxbbbbbbbbbb...
	*)
	PIX_FMT_SBGGR16 := fourcc('B', 'Y', 'R', '2'); (* 16  BGBG.. GRGR.. *)
	
	(* compressed formats *)
	PIX_FMT_MJPEG := fourcc('M', 'J', 'P', 'G'); (* Motion-JPEG   *)
	PIX_FMT_JPEG := fourcc('J', 'P', 'E', 'G'); (* JFIF JPEG     *)
	PIX_FMT_DV := fourcc('d', 'v', 's', 'd'); (* 1394          *)
	PIX_FMT_MPEG := fourcc('M', 'P', 'E', 'G'); (* MPEG-1/2/4    *)

	(*  Vendor-specific formats   *)
	PIX_FMT_CPIA1 := fourcc('C', 'P', 'I', 'A'); (* cpia1 YUV *)
	PIX_FMT_WNVA := fourcc('W', 'N', 'V', 'A'); (* Winnov hw compress *)
	PIX_FMT_SN9C10X := fourcc('S', '9', '1', '0'); (* SN9C10x compression *)
	PIX_FMT_SN9C20X_I420 := fourcc('S', '9', '2', '0'); (* SN9C20x YUV 4:2:0 *)
	PIX_FMT_PWC1 := fourcc('P', 'W', 'C', '1'); (* pwc older webcam *)
	PIX_FMT_PWC2 := fourcc('P', 'W', 'C', '2'); (* pwc newer webcam *)
	PIX_FMT_ET61X251 := fourcc('E', '6', '2', '5'); (* ET61X251 compression *)
	PIX_FMT_SPCA501 := fourcc('S', '5', '0', '1'); (* YUYV per line *)
	PIX_FMT_SPCA505 := fourcc('S', '5', '0', '5'); (* YYUV per line *)
	PIX_FMT_SPCA508 := fourcc('S', '5', '0', '8'); (* YUVY per line *)
	PIX_FMT_SPCA561 := fourcc('S', '5', '6', '1'); (* compressed GBRG bayer *)
	PIX_FMT_PAC207 := fourcc('P', '2', '0', '7'); (* compressed BGGR bayer *)
	PIX_FMT_MR97310A := fourcc('M', '3', '1', '0'); (* compressed BGGR bayer *)
	PIX_FMT_SN9C2028 := fourcc('S', 'O', 'N', 'X'); (* compressed GBRG bayer *)
	PIX_FMT_SQ905C := fourcc('9', '0', '5', 'C'); (* compressed RGGB bayer *)
	PIX_FMT_PJPG := fourcc('P', 'J', 'P', 'G'); (* Pixart 73xx JPEG *)
	PIX_FMT_OV511 := fourcc('O', '5', '1', '1'); (* ov511 JPEG *)
	PIX_FMT_OV518 := fourcc('O', '5', '1', '8'); (* ov518 JPEG *)
	PIX_FMT_STV0680 := fourcc('S', '6', '8', '0'); (* stv0680 bayer *)
	PIX_FMT_TM6000 := fourcc('T', 'M', '6', '0'); (* tm5600/tm60x0 *)
	PIX_FMT_CIT_YYVYUY := fourcc('C', 'I', 'T', 'V'); (* one line of Y then 1 line of VYUY *)
	PIX_FMT_KONICA420 := fourcc('K', 'O', 'N', 'I'); (* YUV420 planar in blocks of 256 pixels *)
END InitCTLS;

	
BEGIN	
	InitCTLS();
END V4L2.


System.Free V4L2 ~ 

