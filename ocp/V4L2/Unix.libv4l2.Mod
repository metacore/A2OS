MODULE libv4l2; (** AUTHOR "fnecati"; PURPOSE "interface library to linux libv4l2 and libv4lconvert"; *)

IMPORT KernelLog, Unix, Modules, V := V4L2, Strings;

CONST 
	libname="libv4l2.so.0";
	libname2 = "libv4lconvert.so.0";

CONST 
     (* file open mode *)	
     nonblock* = SET32({11});
VAR
	libhandle, libhandle2: ADDRESS;
	   
TYPE 
	int64_t* = SIGNED64;
	ssize_t* = SIZE;	
	
	(*! libv4l2.h *)
	(* Point this to a FILE opened for writing when you want to log error and
	   status messages to a file, when NULL errors will get send to stderr *)
	
(*	(*extern*)VAR FILE(*extern*)VAR v4l2_log_file: POINTER TO LIBV4L_PUBLIC; *)
	
	(* Just like your regular open/close/etc, except that format conversion is
	   done if necessary when capturing. That is if you (try to) set a capture
	   format which is not supported by the cam, but is supported by libv4lconvert,
	   then the try_fmt / set_fmt will succeed as if the cam supports the format
	   and on dqbuf / read the data will be converted for you and returned in
	   the request format. enum_fmt will also report support for the formats to
	   which conversion is possible.
	
	   Another difference is that you can make v4l2_read() calls even on devices
	   which do not support the regular read() method.
	
	   Note the device name passed to v4l2_open must be of a video4linux2 device,
	   if it is anything else (including a video4linux1 device), v4l2_open will
	   fail.
	
	   Note that the argument to v4l2_ioctl after the request must be a valid
	   memory address of structure of the appropriate type for the request (for
	   v4l2 requests which expect a structure address). Passing in NULL or an
	   invalid memory address will not lead to failure with errno being EFAULT,
	   as it would with a real ioctl, but will cause libv4l2 to break, and you
	   get to keep both pieces.
	*)
	
VAR	
	open-: PROCEDURE {C} (CONST file: ARRAY OF CHAR;  oflag: SET32; mode: Unix.mode_t): SIGNED32;
	close-: PROCEDURE {C} (fd: SIGNED32): SIGNED32;
	dup- : PROCEDURE{C} (fd: SIGNED32): SIGNED32;
	ioctl-: PROCEDURE {C} (fd: SIGNED32;  request: SIGNED32; adr: ADDRESS): SIGNED32;
	read-: PROCEDURE {C} (fd: SIGNED32;  buffer: ADDRESS;  n: SIZE): ssize_t;
	write-: PROCEDURE {C} (fd: SIGNED32;  buffer: ADDRESS;  n: SIZE): ssize_t;
	
	mmap- :  PROCEDURE {C} (start: ADDRESS;  length: SIZE;  prot: SIGNED32;  flags: SIGNED32; 
									fd: SIGNED32;  offset: int64_t): ADDRESS;
	munmap-: PROCEDURE {C} (start: ADDRESS;  length: SIZE):SIGNED32;
	
	
	(* Misc utility functions *)
	
	(* This function takes a value of 0 - 65535, and then scales that range to
	   the actual range of the given v4l control id, and then if the cid exists
	   and is not locked sets the cid to the scaled value.
	
	   Normally returns 0, even if the cid did not exist or was locked, returns
	   non 0 when an other error occured. *)
	set_control-: PROCEDURE {C} (fd: SIGNED32;  cid: SIGNED32;  value: SIGNED32): SIGNED32;
	
	(* This function returns a value of 0 - 65535, scaled to from the actual range
	   of the given v4l control id. When the cid does not exist, or could not be
	   accessed -1 is returned. *)
	get_control- : PROCEDURE {C} (fd: SIGNED32;  cid: SIGNED32): SIGNED32;
	
	
	(* "low level" access functions, these functions allow somewhat lower level
	   access to libv4l2 (currently there only is v4l2_fd_open here) *)
	
	(* Flags for v4l2_fd_open's v4l2_flags argument *)
	
	(* Disable all format conversion done by libv4l2, this includes the software
	   whitebalance, gamma correction, flipping, etc. libv4lconvert does. Use this
	   if you want raw frame data, but still want the additional error checks and
	   the read() emulation libv4l2 offers. *)
CONST 
	DISABLE_CONVERSION* = 001H;
	(* This flag is *OBSOLETE*, since version 0.5.98 libv4l *always* reports
	   emulated formats to ENUM_FMT, except when conversion is disabled. *)
CONST 
	ENABLE_ENUM_FMT_EMULATION* = 002H;
	
	(* v4l2_fd_open: open an already opened fd for further use through
	   v4l2lib and possibly modify libv4l2's default behavior through the
	   v4l2_flags argument.
	
	   Returns fd on success, -1 if the fd is not suitable for use through libv4l2
	   (note the fd is left open in this case). *)
VAR   
	fd_open-: PROCEDURE {C} (fd: SIGNED32;  v4l2_flags: SIGNED32): SIGNED32;;
	
	
(*! ---------------------------------- *)	

TYPE convert_data = SIGNED32;

VAR
	convert_create- : PROCEDURE {C} (fd: SIGNED32): convert_data;
	convert_destroy-: PROCEDURE  {C} (VAR data: convert_data);
	
	(* When doing flipping / rotating / video-processing, only supported
	   destination formats can be used (as flipping / rotating / video-processing
	   is not supported on other formats). This function can be used to query
	   if that is the case. *)
	convert_supported_dst_fmt_only-: PROCEDURE {C} (VAR data: convert_data): SIGNED32;
	
	(* With regards to dest_fmt just like VIDIOC_TRY_FMT, except that the try
	   format will succeed and return the requested V4L2_PIX_FMT_foo in dest_fmt if
	   the cam has a format from which v4lconvert can convert to dest_fmt.
	   The real format to which the cam should be set is returned through src_fmt
	   when not NULL.
	   Note that just like the real VIDIOC_TRY_FMT this function will change the
	   dest_fmt when not supported. This includes changing it to a supported
	   destination format when trying a native format of the camera and
	   convert_supported_dst_fmt_only() returns true. *)
	convert_try_format-: PROCEDURE {C} (VAR data: convert_data;
									VAR dest_fmt: V.v4l2_format; (* in / out *)
									VAR src_fmt: V.v4l2_format (* out *) ): SIGNED32;
	
	(* Like VIDIOC_ENUM_FMT, but the emulated formats are added at the end of the
	   list, except if flipping / processing is active for the device, then only
	   supported destination formats are listed *)
	convert_enum_fmt-: PROCEDURE {C} (VAR data: convert_data; VAR fmt: V.v4l2_fmtdesc): SIGNED32;
	
	(* Is conversion necessary or can the app use the data directly? *)
	convert_needs_conversion- : PROCEDURE {C} (VAR data: convert_data;
									CONST src_fmt: V.v4l2_format (* in *);
									CONST dest_fmt: V.v4l2_format(* in *) ): SIGNED32;
	
	(* return value of -1 on error, otherwise the amount of bytes written to dest *)
	convert_convert- : PROCEDURE {C} (data: convert_data;
									CONST src_fmt: V.v4l2_format (* in *) ;
									CONST dest_fmt: V.v4l2_format (* in *);
									src: ADDRESS;  src_size: SIGNED32;  dest: ADDRESS;  dest_size: SIGNED32): SIGNED32;
	
	(* get a string describing the last error *)
	convert_get_error_message- : PROCEDURE {C}(data: convert_data): ADDRESS; 
	
	(* Just like VIDIOC_ENUM_FRAMESIZE, except that the framesizes of emulated
	   formats can be enumerated as well. *)
	   
	convert_enum_framesizes- : PROCEDURE {C} (data: convert_data;	VAR frmsize: V.v4l2_frmsizeenum): SIGNED32;


	(* Just like VIDIOC_ENUM_FRAMEINTERVALS, except that the intervals of emulated
	   formats can be enumerated as well. *)
	convert_enum_frameintervals-: PROCEDURE{C} (data: convert_data;
									frmival: V.v4l2_frmivalenum): SIGNED32;

	(* Pass calls to query, get and set video controls to the libv4lcontrol class *)
	convert_vidioc_queryctrl-: PROCEDURE{C} (data: convert_data;	arg: ADDRESS):SIGNED32;
	convert_vidioc_g_ctrl-: PROCEDURE{C} (data: convert_data; arg: ADDRESS): SIGNED32;
	convert_vidioc_s_ctrl-: PROCEDURE{C} (data: convert_data;	arg: ADDRESS): SIGNED32;
	
	(* Is the passed in pixelformat supported as destination format? *)
	convert_supported_dst_format-: PROCEDURE{C} (pixelformat: SIGNED32(*word*)): SIGNED32; 
	
	(* Get/set the no fps libv4lconvert uses to decide if a compressed format
	   must be used as src fmt to stay within the bus bandwidth *)
	convert_get_fps-: PROCEDURE{C} (data: convert_data): SIGNED32;
	convert_set_fps-: PROCEDURE{C} (data: convert_data; fps: SIGNED32);

(*! ---------------------------------- *)

PROCEDURE Init;
BEGIN
  libhandle := Unix.Dlopen(libname, 2);
  ASSERT(libhandle # 0,102);

	  Unix.Dlsym(libhandle,  'v4l2_open', ADDRESSOF( open ));
	  Unix.Dlsym(libhandle,  'v4l2_close', ADDRESSOF( close ));	
	  Unix.Dlsym(libhandle,  'v4l2_dup', ADDRESSOF( dup ));	
	  Unix.Dlsym(libhandle,  'v4l2_ioctl', ADDRESSOF( ioctl ));	
	  Unix.Dlsym(libhandle,  'v4l2_read', ADDRESSOF( read ));
	  Unix.Dlsym(libhandle,  'v4l2_write', ADDRESSOF( write ));
	  Unix.Dlsym(libhandle,  'v4l2_mmap', ADDRESSOF( mmap ));	
	  Unix.Dlsym(libhandle,  'v4l2_munmap', ADDRESSOF( munmap ));	
	  Unix.Dlsym(libhandle,  'v4l2_set_control', ADDRESSOF( set_control ));	
	  
	  Unix.Dlsym(libhandle,  'v4l2_get_control', ADDRESSOF( get_control ));
	  Unix.Dlsym(libhandle,  'v4l2_fd_open', ADDRESSOF( fd_open ));

	(* add other function protypes if required *)
	
END Init;

PROCEDURE OnClose;
BEGIN
	IF libhandle2 # 0 THEN
		Unix.Dlclose(libhandle2);
		KernelLog.String(libname2); KernelLog.String(" unloaded."); KernelLog.Ln;
	END;

	IF libhandle # 0 THEN
		Unix.Dlclose(libhandle);
		KernelLog.String(libname); KernelLog.String(" unloaded."); KernelLog.Ln;
	END;
END OnClose;

PROCEDURE Init2;
BEGIN
  libhandle2 := Unix.Dlopen(libname2, 2);
  ASSERT(libhandle2 # 0,103);

	  Unix.Dlsym(libhandle2,  'v4lconvert_create', ADDRESSOF( convert_create ));
	  Unix.Dlsym(libhandle2,  'v4lconvert_destroy', ADDRESSOF( convert_destroy ));	
	  Unix.Dlsym(libhandle2,  'v4lconvert_supported_dst_fmt_only', ADDRESSOF( convert_supported_dst_fmt_only ));	
	  Unix.Dlsym(libhandle2,  'v4lconvert_try_format', ADDRESSOF( convert_try_format ));	
	  Unix.Dlsym(libhandle2,  'v4lconvert_enum_fmt', ADDRESSOF( convert_enum_fmt ));	
	  Unix.Dlsym(libhandle2,  'v4lconvert_needs_conversion', ADDRESSOF( convert_needs_conversion ));	
	  Unix.Dlsym(libhandle2,  'v4lconvert_convert', ADDRESSOF( convert_convert ));	
	  Unix.Dlsym(libhandle2,  'v4lconvert_get_error_message', ADDRESSOF( convert_get_error_message ));	
	  
	  Unix.Dlsym(libhandle2,  'v4lconvert_enum_framesizes', ADDRESSOF( convert_enum_framesizes ));
	  Unix.Dlsym(libhandle2,  'v4lconvert_enum_frameintervals', ADDRESSOF( convert_enum_frameintervals ));


	  Unix.Dlsym(libhandle2,  'v4lconvert_vidioc_queryctrl', ADDRESSOF( convert_vidioc_queryctrl ));
	  Unix.Dlsym(libhandle2,  'v4lconvert_vidioc_g_ctrl', ADDRESSOF( convert_vidioc_g_ctrl ));	
	  Unix.Dlsym(libhandle2,  'v4lconvert_vidioc_s_ctrl', ADDRESSOF( convert_vidioc_s_ctrl ));	
	  Unix.Dlsym(libhandle2,  'v4lconvert_supported_dst_format', ADDRESSOF( convert_supported_dst_format ));	
	  Unix.Dlsym(libhandle2,  'v4lconvert_get_fps', ADDRESSOF( convert_get_fps ));	
	Unix.Dlsym(libhandle2,  'v4lconvert_set_fps', ADDRESSOF( convert_set_fps ));	

END Init2;


(* utilities  *)
(* Get string from address  *)
PROCEDURE GetStringFromAddr*(adr: ADDRESS): Strings.String;
VAR s {UNTRACED}: POINTER {UNSAFE} TO ARRAY MAX(SIZE) OF CHAR;
	str: Strings.String;
	size, pos: SIZE;
BEGIN

	s := adr;
	pos := 0;
	IF adr # NIL THEN
		WHILE s[pos] # 0X DO
			INC(pos);
		END;
		size := pos + 1;
		NEW(str, size);
		pos := 0;
		WHILE s[pos] # 0X DO
			str[pos] := s[pos];
			INC(pos);
		END;

	ELSE NEW(str, 1);
	END;

	str[pos] := 0X;
	RETURN str;

END GetStringFromAddr;

BEGIN
	Init();
	Init2();
	Modules.InstallTermHandler(OnClose);
END libv4l2.
