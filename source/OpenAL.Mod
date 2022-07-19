MODULE OpenAL; (** AUTHOR "fnecati"; PURPOSE "OpenAL cross platform audio library"; *)

IMPORT SYSTEM, Modules, Strings, KernelLog, HostLibs;

VAR oalib-: HostLibs.LibHandle;

CONST
	debug = FALSE;
	
#IF UNIX THEN
	libname = "libopenal.so.1";
#ELSE
	libname = "OpenAL32.dll";
#END
	
	
TYPE
	StringArray* = Strings.StringArray;
	
	ALboolean* = BOOLEAN; (* 8-bit boolean *)
	ALchar* = CHAR;
	ALbyte* = SIGNED8;  (* signed 8-bit 2's complement integer *)
	ALubyte* = UNSIGNED8;     (* 1-byte unsigned *)
	ALshort* = SIGNED16;  (* signed 16-bit 2's complement integer *)
	ALushort* = UNSIGNED16;     (* unsigned 16-bit integer *)
	ALint* = SIGNED32;  (* signed 32-bit 2's complement intege *)
	ALuint* = UNSIGNED32;    (* unsigned 32-bit integer *)
	ALsizei* = SIGNED32;  (* non-negative 32-bit binary integer size *)
	ALenum* = SIGNED32; (* enumerated 32-bit value *)

	ALfloat* = FLOAT32; (* 32-bit IEEE754 floating-point *)
	ALdouble* = FLOAT64; (* 64-bit IEEE754 floating-point *)
	ALvoid* = ADDRESS; (* void type (for opaque pointers only) *)

	PALboolean* = ADDRESS; (* POINTER TO ARRAY OF ALboolean;*)
	PALfloat* = ADDRESS; (* POINTER TO ARRAY OF ALfloat;*)
	PALdouble* = ADDRESS; (* POINTER TO ARRAY OFALdouble;*)
	PALbyte* = ADDRESS; (* POINTER TO ARRAY OF ALbyte;*)
	PALshort* = ADDRESS; (* POINTER TO ARRAY OF ALshort;*)
	PALint* = ADDRESS; (* POINTER TO ARRAY OF ALint; *)
	PALubyte* = ADDRESS; (* POINTER TO ARRAY OF ALubyte; *)
	PALushort* = ADDRESS; (* POINTER TO ARRAY OF ALushort; *)
	PALuint* = ADDRESS; (* POINTER TO ARRAY OF ALuint; *)

CONST
	AL_INVALID* = (-1);
	AL_NONE* = 0; (* "no distance model" or "no buffer" *)
	AL_FALSE* = 0;
	AL_TRUE* = 1;


	(**
	 * Relative source.
	 * Type:    ALboolean
	 * Range:   [AL_TRUE, AL_FALSE]
	 * Default: AL_FALSE
	 *
	 * Specifies if the Source has relative coordinates.
	 *)	
	AL_SOURCE_RELATIVE* = 202H;
	
	(* Inner cone angle, in degrees.
	 * Type:    ALint, ALfloat
	 * Range:   [0 - 360]
	 * Default: 360
	 *
	 * The angle covered by the inner cone, where the source will not attenuate.
	 *)
	AL_CONE_INNER_ANGLE* = 1001H;

	(**
	 * Outer cone angle, in degrees.
	 * Range:   [0 - 360]
	 * Default: 360
	 *
	 * The angle covered by the outer cone, where the source will be fully
	 * attenuated.
	 *)	 
	AL_CONE_OUTER_ANGLE* = 1002H;

	(**
	* Source pitch.
	 * Type:    ALfloat
	 * Range:   [0.5 - 2.0]
	 * Default: 1.0
	 *
	 * A multiplier for the frequency (sample rate) of the source's buffer.
	 *)
	AL_PITCH* = 1003H;

	(**
	* Source or listener position.
	 * Type:    ALfloat[3], ALint[3]
	 * Default: {0, 0, 0}
	 *
	 * The source or listener location in three dimensional space.
	 *
	 * OpenAL, like OpenGL, uses a right handed coordinate system, where in a
	 * frontal default view X (thumb) points right, Y points up (index finger), and
	 * Z points towards the viewer/camera (middle finger).
	 *
	 * To switch from a left handed coordinate system, flip the sign on the Z
	 * coordinate.	 *)
	AL_POSITION* = 1004H;

	(**
	 * Source direction.
	 * Type:    ALfloat[3], ALint[3]
	 * Default: {0, 0, 0}
	 *
	 * Specifies the current direction in local space.
	 * A zero-length vector specifies an omni-directional source (cone is ignored).
	*)
		AL_DIRECTION* = 1005H;

	(**
	 * Source or listener velocity.
	 * Type:    ALfloat[3], ALint[3]
	 * Default: {0, 0, 0}
	 *
	 * Specifies the current velocity in local space.
	 *)
	AL_VELOCITY* = 1006H; (** Specify the current velocity in three dimensional space. *)

	(**
	* Source looping.
	 * Type:    ALboolean
	 * Range:   [AL_TRUE, AL_FALSE]
	 * Default: AL_FALSE
	 *
	 * Specifies whether source is looping.
	 *)
	AL_LOOPING* = 1007H;

	(**
	 * Source buffer.
	 * Type:  ALuint
	 * Range: any valid Buffer.
	 *
	 * Specifies the buffer to provide sound samples.
	 *)
	AL_BUFFER* = 1009H;

	(**
	 * Source or listener gain.
	 * Type:  ALfloat
	 * Range: [0.0 - ]
	 *
	 * A value of 1.0 means unattenuated. Each division by 2 equals an attenuation
	 * of about -6dB. Each multiplicaton by 2 equals an amplification of about
	 * +6dB.
	 *
	 * A value of 0.0 is meaningless with respect to a logarithmic scale; it is
	 * silent.
	 *)
	AL_GAIN* = 100AH;

	(*
	* Minimum source gain.
	 * Type:  ALfloat
	 * Range: [0.0 - 1.0]
	 *
	 * The minimum gain allowed for a source, after distance and cone attenation is
	 * applied (if applicable).
	 *)
	AL_MIN_GAIN* = 100DH;

	(**
 	* Maximum source gain.
 	* Type:  ALfloat
 	* Range: [0.0 - 1.0]
 	*
 	* The maximum gain allowed for a source, after distance and cone attenation is
 	* applied (if applicable).
	*)
	AL_MAX_GAIN* = 100EH;

	(**
	 * Listener orientation.
	 * Type: ALfloat[6]
	 * Default: {0.0, 0.0, -1.0, 0.0, 1.0, 0.0}
	 *
	 * Effectively two three dimensional vectors. The first vector is the front (or
	 * "at") and the second is the top (or "up").
	 *
	 * Both vectors are in local space.	
	  *)
	AL_ORIENTATION* = 100FH;

	(** 
	* Source state (query only).
	 * Type:  ALint
	 * Range: [AL_INITIAL, AL_PLAYING, AL_PAUSED, AL_STOPPED]	
	 *)
	AL_SOURCE_STATE* = 1010H;

	(** Source state value. *)	
	AL_INITIAL* = 1011H;
	AL_PLAYING* = 1012H;
	AL_PAUSED* = 1013H;
	AL_STOPPED* = 1014H;


	(**
	* Source Buffer Queue size (query only).
	 * Type: ALint
	 *
	 * The number of buffers queued using alSourceQueueBuffers, minus the buffers
	 * removed with alSourceUnqueueBuffers.
	  *)
	AL_BUFFERS_QUEUED* = 1015H;

	(**
	 * Source Buffer Queue processed count (query only).
	 * Type: ALint
	 *
	 * The number of queued buffers that have been fully processed, and can be
	 * removed with alSourceUnqueueBuffers.
	 *
	 * Looping sources will never fully process buffers because they will be set to
	 * play again for when the source loops.
	 *)	
	AL_BUFFERS_PROCESSED* = 1016H;

	(**
	 * Source reference distance.
	 * Type:    ALfloat
	 * Range:   [0.0 - ]
	 * Default: 1.0
	 *
	 * The distance in units that no attenuation occurs.
	 *
	 * At 0.0, no distance attenuation ever occurs on non-linear attenuation models.
	 *)
	AL_REFERENCE_DISTANCE* = 1020H;

	(*
	 * Source rolloff factor.
	 * Type:    ALfloat
	 * Range:   [0.0 - ]
	 * Default: 1.0
	 *
	 * Multiplier to exaggerate or diminish distance attenuation.
	 *
	 * At 0.0, no distance attenuation ever occurs.
	 *)
	AL_ROLLOFF_FACTOR* = 1021H;

	(**
	 * Outer cone gain.
	 * Type:    ALfloat
	 * Range:   [0.0 - 1.0]
	 * Default: 0.0
	 *
	 * The gain attenuation applied when the listener is outside of the source's
	 * outer cone.
	 *)
	AL_CONE_OUTER_GAIN* = 1022H;

	(**
	 * Source maximum distance.
	 * Type:    ALfloat
	 * Range:   [0.0 - ]
	 * Default: +inf
	 *
	 * The distance above which the source is not attenuated any further with a
	 * clamped distance model, or where attenuation reaches 0.0 gain for linear
	 * distance models with a default rolloff factor.
	 *)
	AL_MAX_DISTANCE* =1023H;

	 (*  Source buffer position, in seconds *)
	AL_SEC_OFFSET* = 1024H;
	(* Source buffer position, in sample frames *)
	AL_SAMPLE_OFFSET* = 1025H;
	(* Source buffer position, in bytes *)
	AL_BYTE_OFFSET* = 1026H;

	(**
	* Source type (query only).
	 * Type:  ALint
	 * Range: [AL_STATIC, AL_STREAMING, AL_UNDETERMINED]
	 *
	 * A Source is Static if a Buffer has been attached using AL_BUFFER.
	 *
	 * A Source is Streaming if one or more Buffers have been attached using
	 * alSourceQueueBuffers.
	 *
	 * A Source is Undetermined when it has the NULL buffer attached using
	 * AL_BUFFER.	 *)
	AL_SOURCE_TYPE* = 1027H;

	(** Source type value. *)
	AL_STATIC* = 1028H;
	AL_STREAMING* = 1029H;
	AL_UNDETERMINED* = 1030H;

	(** Buffer format specifier. *)
	AL_FORMAT_MONO8* = 1100H;
	AL_FORMAT_MONO16* = 1101H;
	AL_FORMAT_STEREO8* = 1102H;
	AL_FORMAT_STEREO16* = 1103H;

	(**
	 * Sound samples: frequency, in units of Hertz [Hz].
	 * This is the number of samples per second. Half of the
	 *  sample frequency marks the maximum significant
	 *  frequency component.
	 *)
	(** Buffer frequency (query only). *)
	AL_FREQUENCY* = 2001H;
	(** Buffer bits per sample (query only).*)
	AL_BITS* = 2002H;
	(** Buffer channel count (query only). *)
	AL_CHANNELS* = 2003H;
	(** Buffer data size (query only).*)
	AL_SIZE* = 2004H;
	
	(**
	 * Buffer state.
	 * Not for public use.
	 *)

	AL_UNUSED* = 2010H;
	AL_PENDING* = 2011H;
	AL_PROCESSED* = 2012H;

	(** Errors: No Error. *)
	AL_NO_ERROR* = AL_FALSE;

	AL_INVALID_NAME* = 0A001H; (**  Invalid name paramater passed to AL call. *)
	AL_INVALID_ENUM* = 0A002H; (**  IInvalid enum parameter passed to AL call.. *)
	AL_INVALID_VALUE* = 0A003H; (**  Invalid value parameter passed to AL call. *)
	AL_INVALID_OPERATION* = 0A004H; (**  Illegal AL call. *)
	AL_OUT_OF_MEMORY* = 0A005H; (** Not enough memory. *)

	
	AL_VENDOR* = 0B001H; (** Context strings: Vendor ID. *)
	AL_VERSION* = 0B002H; (** Context string: Version. *)
	AL_RENDERER* = 0B003H; (** Context string: Renderer ID. *)
	AL_EXTENSIONS* = 0B004H; (** Context string: Space-separated extension list. *)

	(**
	 * Doppler scale.
	 * Type:    ALfloat
	 * Range:   [0.0 - ]
	 * Default: 1.0
	 *
	 * Scale for source and listener velocities.
	 *)
 	AL_DOPPLER_FACTOR* = 0C000H; (** Doppler scale.  Default 1.0 *)

	(**
	 * Doppler velocity (deprecated).
	 *
	 * A multiplier applied to the Speed of Sound.
	 *) 	
	AL_DOPPLER_VELOCITY* = 0C001H;

	(**
	 * Speed of Sound, in units per second.
	 * Type:    ALfloat
	 * Range:   [0.0001 - ]
	 * Default: 343.3
	 *
	 * The speed at which sound waves are assumed to travel, when calculating the
	 * doppler effect.
	 *)	
	AL_SPEED_OF_SOUND* = 0C003H;   (** Speed of Sound in units per second *)


	(**
	 * Distance attenuation model.
	 * Type:    ALint
	 * Range:   [AL_NONE, AL_INVERSE_DISTANCE, AL_INVERSE_DISTANCE_CLAMPED,
	 *           AL_LINEAR_DISTANCE, AL_LINEAR_DISTANCE_CLAMPED,
	 *           AL_EXPONENT_DISTANCE, AL_EXPONENT_DISTANCE_CLAMPED]
	 * Default: AL_INVERSE_DISTANCE_CLAMPED
	 *
	 * The model by which sources attenuate with distance.
	 *
	 * None     - No distance attenuation.
	 * Inverse  - Doubling the distance halves the source gain.
	 * Linear   - Linear gain scaling between the reference and max distances.
	 * Exponent - Exponential gain dropoff.
	 *
	 * Clamped variations work like the non-clamped counterparts, except the
	 * distance calculated is clamped between the reference and max distances.
	 *)
	AL_DISTANCE_MODEL* = 0D000H;

	(** Distance model value. *)	
	AL_INVERSE_DISTANCE* = 0D001H;
	AL_INVERSE_DISTANCE_CLAMPED* = 0D002H;
	AL_LINEAR_DISTANCE* = 0D003H;
	AL_LINEAR_DISTANCE_CLAMPED* = 0D004H;
	AL_EXPONENT_DISTANCE* = 0D005H;
	AL_EXPONENT_DISTANCE_CLAMPED* = 0D006H;

(*! ********ALC API types (alc.h) ******** *)

TYPE
	ALCboolean* = ALboolean; (* 8-bit boolean *)
	ALCchar* = ALchar;	
	ALCbyte* = ALbyte;  (* signed 8-bit 2's complement integer *)
	ALCubyte* = ALubyte;     (* 1-byte unsigned *)
	ALCshort* = ALshort;  (* signed 16-bit 2's complement integer *)
	ALCushort* = ALushort;     (* unsigned 16-bit integer *)
	ALCint* = ALint;  (* signed 32-bit 2's complement intege *)
	ALCuint* = ALuint;    (* unsigned 32-bit integer *)
	ALCsizei* = ALsizei;  (* non-negative 32-bit binary integer size *)
	ALCenum* = ALenum; (* enumerated 32-bit value *)

	ALCfloat* = ALfloat; (* 32-bit IEEE754 floating-point *)
	ALCdouble* = ALdouble; (* 64-bit IEEE754 floating-point *)
	ALCvoid* = ALvoid; (* void type (for opaque pointers only) *)

	ALCcontext* = POINTER {UNTRACED, UNSAFE} TO RECORD END;
	ALCdevice* = POINTER {UNTRACED, UNSAFE} TO RECORD END;

	PALCint* = PALint; (*  POINTER TO ARRAY OF ALCint; *)
	PALCuint* = PALuint; (*  POINTER TO ARRAY OF ALCuint; *)

CONST
	ALC_INVALID* = -1;
	ALC_FALSE* = AL_FALSE;
	ALC_TRUE* = AL_TRUE;

	(** Context attribute: <int> Hz. *)
	ALC_FREQUENCY* = 1007H;
	(** Context attribute: <int> Hz. *)
	ALC_REFRESH* = 1008H;
	(** Context attribute: AL_TRUE or AL_FALSE. *)
	ALC_SYNC* = 1009H;
	(** Context attribute: <int> requested Mono (3D) Sources. *)
	ALC_MONO_SOURCES* = 1010H;
	(** Context attribute: <int> requested Stereo Sources. *)
	ALC_STEREO_SOURCES* = 1011H;

	 (** errors *)
	ALC_NO_ERROR* = ALC_FALSE;
	ALC_INVALID_DEVICE* = 0A001H; (** Invalid device handle. *)
	ALC_INVALID_CONTEXT* = 0A002H; (** Invalid context handle. *)
	ALC_INVALID_ENUM* = 0A003H; (** Invalid enum parameter passed to an ALC call. *)
	ALC_INVALID_VALUE* = 0A004H;  (* Invalid value parameter passed to an ALC call. *)
	ALC_OUT_OF_MEMORY* = 0A005H; (** Out of memory. *)


	(** Runtime ALC version. *)
	ALC_MAJOR_VERSION* = 1000H;
	ALC_MINOR_VERSION* = 1001H;
	(** Context attribute list properties. *)	
	ALC_ATTRIBUTES_SIZE* = 1002H;
	ALC_ALL_ATTRIBUTES* = 1003H;
	(** String for the default device specifier. *)
	ALC_DEFAULT_DEVICE_SPECIFIER* = 1004H;

	(**
	 * String for the given device's specifier.
	 *
	 * If device handle is NULL, it is instead a null-char separated list of
	 * strings of known device specifiers (list ends with an empty string).
	 *)
	ALC_DEVICE_SPECIFIER* = 1005H;
	(** String for space-separated list of ALC extensions. *)	
	ALC_EXTENSIONS* = 1006H;

	 (** Capture extension *)
	(**
	 * String for the given capture device's specifier.
	 *
	 * If device handle is NULL, it is instead a null-char separated list of
	 * strings of known capture device specifiers (list ends with an empty string).
	 *)	 
	ALC_CAPTURE_DEVICE_SPECIFIER* = 310H;

	(** String for the default capture device specifier. *)
	ALC_CAPTURE_DEFAULT_DEVICE_SPECIFIER* = 311H;
	(** Number of sample frames available for capture. *)
	ALC_CAPTURE_SAMPLES* = 312H;

	(** Enumerate All extension *)
	(** String for the default extended device specifier. *)
	ALC_DEFAULT_ALL_DEVICES_SPECIFIER* =1012H;
	(**
	 * String for the given extended device's specifier.
	 *
	 * If device handle is NULL, it is instead a null-char separated list of
	 * strings of known extended device specifiers (list ends with an empty string).
	 *)
	ALC_ALL_DEVICES_SPECIFIER* =1013H;


VAR

	(* Global Parameters *)
	alDistanceModel-: PROCEDURE{PlatformCC}(value : ALenum);
	alDopplerFactor-: PROCEDURE{PlatformCC}(value : ALfloat);
	alSpeedOfSound-: PROCEDURE{PlatformCC}(value : ALfloat);
	alDopplerVelocity-: PROCEDURE{PlatformCC}(value : ALfloat);
	
	(* Renderer State management *)
	alEnable-: PROCEDURE{PlatformCC}(capability : ALenum);
	alDisable -: PROCEDURE{PlatformCC}(capability : ALenum);
	alIsEnabled-: PROCEDURE{PlatformCC}(capability : ALenum) : ALboolean;
	(* alHint-: PROCEDURE{PlatformCC}(target, mode : ALenum); *)

	(* State retrieval *)
	XalGetString-: PROCEDURE{PlatformCC}(param : ALenum) : ADDRESS;
	alGetBooleanv-: PROCEDURE{PlatformCC}(param : ALenum; VAR data : ALboolean);
	alGetIntegerv-: PROCEDURE{PlatformCC}(param : ALenum; VAR data : ALint);
	alGetFloatv-: PROCEDURE{PlatformCC}(param : ALenum;  VAR data : ALfloat);
	alGetDoublev-: PROCEDURE{PlatformCC}(param : ALenum; VAR data : ALdouble);
	alGetBoolean- : PROCEDURE{PlatformCC}(param : ALenum) : ALboolean;
	alGetInteger-: PROCEDURE{PlatformCC}(param : ALenum) : ALint;
	alGetFloat-: PROCEDURE{PlatformCC}(param : ALenum) : ALfloat;
	alGetDouble-: PROCEDURE{PlatformCC}(param : ALenum) : ALdouble;
	
	(**
	* Error retrieval.
	 * Obtain the first error generated in the AL context since the last check.
	 *)
	alGetError-: PROCEDURE{PlatformCC}() : ALenum;

	(*
	 * Extension support.
	 * Query for the presence of an extension, and obtain any appropriate
	 * function pointers and enum values.
	 *)
	alIsExtensionPresent-: PROCEDURE{PlatformCC}(CONST fname : ARRAY OF CHAR) : ALboolean;
	
	XalGetProcAddress-: PROCEDURE{PlatformCC}(CONST fname : ARRAY OF CHAR): ADDRESS;
	alGetEnumValue-: PROCEDURE{PlatformCC}(CONST ename: ARRAY OF CHAR): ALenum;

	 (*  LISTENER
	Listener represents the location and orientation of the
	'user' in 3D-space.

	Properties include: -

	Gain         AL_GAIN         ALfloat
	Position     AL_POSITION     ALfloat[3]
	Velocity     AL_VELOCITY     ALfloat[3]
	Orientation  AL_ORIENTATION  ALfloat[6] (Forward then Up vectors)
	*)

	(* Set Listener parameters *)
	alListenerf-: PROCEDURE{PlatformCC}(param : ALenum; value : ALfloat);
	alListener3f-: PROCEDURE{PlatformCC}(param : ALenum; v1, v2, v3 : ALfloat);
	alListenerfv-: PROCEDURE{PlatformCC}(param : ALenum;  values : PALfloat);
	alListeneri-: PROCEDURE{PlatformCC}(param : ALenum; value : ALint);
	alListener3i-: PROCEDURE{PlatformCC}(param : ALenum; v1, v2, v3 : ALint);
	alListeneriv-: PROCEDURE{PlatformCC}(param : ALenum;  values : PALint);

	(* Get Listener parameters *)
	alGetListenerf-: PROCEDURE{PlatformCC}(param : ALenum; VAR value : ALfloat);
	alGetListener3f-: PROCEDURE{PlatformCC}(param : ALenum; VAR v1, v2,  v3 : ALfloat);
	alGetListenerfv-: PROCEDURE{PlatformCC}(param : ALenum; values : PALfloat);
	alGetListeneri-: PROCEDURE{PlatformCC}(param : ALenum; VAR value : ALint);
	alGetListener3i-: PROCEDURE{PlatformCC}(param : ALenum; VAR v1, v2, v3:  ALint);
	alGetListeneriv-: PROCEDURE{PlatformCC}(param : ALenum; values : PALint);

	(*
	SOURCE
	Sources represent individual sound objects in 3D-space.
	Sources take the PCM data provided in the specified Buffer,
	apply Source-specific modifications, and then
	submit them to be mixed according to spatial arrangement etc.

	Properties include: -

	Gain                              AL_GAIN                 ALfloat
	Min Gain                          AL_MIN_GAIN             ALfloat
	Max Gain                          AL_MAX_GAIN             ALfloat
	Position                          AL_POSITION             ALfloat[3]
	Velocity                          AL_VELOCITY             ALfloat[3]
	Direction                         AL_DIRECTION            ALfloat[3]
	Head Relative Mode                AL_SOURCE_RELATIVE      ALint (AL_TRUE or AL_FALSE)
	Reference Distance                AL_REFERENCE_DISTANCE   ALfloat
	Max Distance                      AL_MAX_DISTANCE         ALfloat
	RollOff Factor                    AL_ROLLOFF_FACTOR       ALfloat
	Inner Angle                       AL_CONE_INNER_ANGLE     ALint or ALfloat
	Outer Angle                       AL_CONE_OUTER_ANGLE     ALint or ALfloat
	Cone Outer Gain                   AL_CONE_OUTER_GAIN      ALint or ALfloat
	Pitch                             AL_PITCH                ALfloat
	Looping                           AL_LOOPING              ALint (AL_TRUE or AL_FALSE)
	MS Offset                         AL_MSEC_OFFSET          ALint or ALfloat
	Byte Offset                       AL_BYTE_OFFSET          ALint or ALfloat
	Sample Offset                     AL_SAMPLE_OFFSET        ALint or ALfloat
	Attached Buffer                   AL_BUFFER               ALint
	State (Query only)                AL_SOURCE_STATE         ALint
	Buffers Queued (Query only)       AL_BUFFERS_QUEUED       ALint
	Buffers Processed (Query only)    AL_BUFFERS_PROCESSED    ALint
	 *)


	(* Create Source objects *)
	alGenSources-: PROCEDURE{PlatformCC}(n : ALsizei; sources : PALuint);

	(* Delete Source objects *)
	alDeleteSources-: PROCEDURE{PlatformCC}(n : ALsizei; sources : PALuint);

	(* Verify a handle is a valid Source *)
	alIsSource-: PROCEDURE{PlatformCC}(id : ALuint) : ALboolean;

	(* Set Source parameters *)
	alSourcef-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; value : ALfloat);
	alSource3f-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; v1, v2, v3 : ALfloat);
	alSourcefv-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; values : PALfloat);
	(*! type check error, there is an inconsistency when using
		alSourcei ( source, AL.AL_BUFFER, buffer);
		
		so, value type is changed to ALuint.
	*)
(*	alSourcei-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; value : ALint); *)
	alSourcei-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; value : ALuint);
	alSource3i-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; v1, v2, v3 : ALint);
	alSourceiv-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; values : PALint);

	(* Get Source parameters *)
	alGetSourcef-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; VAR value : ALfloat);
	alGetSource3f-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; VAR v1, v2, v3 : ALfloat);
	alGetSourcefv-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; values : PALfloat);
	alGetSourcei-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; VAR value : ALint);
	alGetSource3i-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; VAR v1, v2, v3 : ALint);
	alGetSourceiv-: PROCEDURE{PlatformCC}(source : ALuint; param : ALenum; values : PALint);

	(* Source vector based playback calls *)

	(* Play, replay, or resume (if paused) a list of Sources *)
	alSourcePlayv-: PROCEDURE{PlatformCC}(n : ALsizei; sources : PALuint);
	(* Stop a list of Sources *)
	alSourceStopv-: PROCEDURE{PlatformCC}(n : ALsizei;  sources : PALuint);	
	(* Rewind a list of Sources *)
	alSourceRewindv-: PROCEDURE{PlatformCC}(n : ALsizei;  sources : PALuint);
	(* Pause a list of Sources *)
	alSourcePausev-: PROCEDURE{PlatformCC}(n : ALsizei;  sources : PALuint);

	(* Source based playback calls *)
	(* Play, replay, or resume a Source *)
	alSourcePlay-: PROCEDURE{PlatformCC}( source : ALuint);
	(* Stop a Source *)
	alSourceStop-: PROCEDURE{PlatformCC}(source : ALuint);
	(* Rewind a Source (set playback postiton to beginning)  *)
	alSourceRewind-: PROCEDURE{PlatformCC} (source : ALuint);
		
	(* Pause a Source *)
	alSourcePause-: PROCEDURE{PlatformCC}( source : ALuint);
	
	(*  Queue buffers onto a source  *)
	alSourceQueueBuffers-: PROCEDURE{PlatformCC}(source : ALuint; n : ALsizei; buffers : PALuint);
	alSourceUnqueueBuffers-: PROCEDURE{PlatformCC}(source : ALuint; n : ALsizei; buffers : PALuint);

	(*
	BUFFER
	Buffer objects are storage space for sample data.
	Buffers are referred to by Sources. One Buffer can be used
	by multiple Sources.

	Properties include: -

	Frequency (Query only)    AL_FREQUENCY      ALint
	Size (Query only)         AL_SIZE           ALint
	Bits (Query only)         AL_BITS           ALint
	Channels (Query only)     AL_CHANNELS       ALint
	 *)

	(* Create Buffer objects *)
	alGenBuffers-: PROCEDURE{PlatformCC}(n : ALsizei;  buffers : PALuint);
	(* Delete Buffer objects *)
	alDeleteBuffers-: PROCEDURE{PlatformCC}(n : ALsizei;  buffers : PALuint);
	(* Verify a handle is a valid Buffer *)
	alIsBuffer-: PROCEDURE{PlatformCC}(buffer : ALuint) : ALboolean;
	(* Specify the data to be copied into a buffer *)
	alBufferData-: PROCEDURE{PlatformCC}(buffer : ALuint; format : ALenum;  data: ADDRESS ;  size, freq : ALsizei);

	(* Set Buffer parameters *)
	alBufferf-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum; value : ALfloat);
	alBuffer3f-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum;  v1, v2, v3: ALfloat);
	alBufferfv-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum;  value : PALfloat);
	alBufferi-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum;  value : ALint);
	alBuffer3i-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum;  v1, v2, v3 : ALint);
	alBufferiv-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum;  value : PALint);

	(* Get Buffer parameters *)
	alGetBufferf-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum; VAR value : ALfloat);
	alGetBuffer3f-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum; VAR v1, v2, v3: ALfloat);
	alGetBufferfv-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum;  value : PALfloat);
	alGetBufferi-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum; VAR value : ALint);
	alGetBuffer3i-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum; VAR v1, v2, v3 : ALint);
	alGetBufferiv-: PROCEDURE{PlatformCC}(buffer : ALuint; param : ALenum;  value : PALint);

	(*! ALC Context Management *)
	alcCreateContext-: PROCEDURE{PlatformCC}(device : ALCdevice; attrList : PALCint) : ALCcontext;
	alcMakeContextCurrent-: PROCEDURE{PlatformCC}( context : ALCcontext) : ALCboolean;
	alcProcessContext-: PROCEDURE{PlatformCC}(context : ALCcontext);
	alcSuspendContext-: PROCEDURE{PlatformCC}(context : ALCcontext);
	alcDestroyContext-: PROCEDURE{PlatformCC}(context : ALCcontext);
	alcGetCurrentContext-: PROCEDURE{PlatformCC}() : ALCcontext;
	alcGetContextsDevice-: PROCEDURE{PlatformCC}(context : ALCcontext) : ALCdevice;

	(* Device Management *)
	alcOpenDevice-: PROCEDURE{PlatformCC}(CONST deviceName: ARRAY OF CHAR) : ALCdevice;
	alcCloseDevice-: PROCEDURE{PlatformCC}(device : ALCdevice): ALCboolean;

	 (* Error support.
	 * Obtain the most recent Context error
	 *)
	alcGetError-: PROCEDURE{PlatformCC}(device : ALCdevice) : ALCenum;

	(*
	 * Extension support.
	 * Query for the presence of an extension, and obtain any appropriate
	 * function pointers and enum values.
	 *)
	alcIsExtensionPresent- : PROCEDURE{PlatformCC}(device : ALCdevice; CONST extName : ARRAY OF CHAR) : ALCboolean;
	XalcGetProcAddress-: PROCEDURE{PlatformCC}(device : ALCdevice; CONST funcName:  ARRAY OF CHAR): ADDRESS;
	alcGetEnumValue-: PROCEDURE{PlatformCC}(device : ALCdevice; VAR enumName : ALCubyte) : ALCenum;

	(* Query functions *)
	XalcGetString-: PROCEDURE{PlatformCC}(device : ALCdevice; param : ALCenum) : ADDRESS;
	alcGetIntegerv -: PROCEDURE{PlatformCC}( device : ALCdevice; param : ALCenum; size : ALCsizei;  data : PALCint);

	(* Capture functions *)
	alcCaptureOpenDevice-:  PROCEDURE{PlatformCC}(CONST devicename: ARRAY OF CHAR; frequency: ALCuint; format: ALCenum; buffersize: ALCsizei): ALCdevice;
	alcCaptureCloseDevice-: PROCEDURE{PlatformCC}(device: ALCdevice): ALCboolean;
	alcCaptureStart-:  PROCEDURE{PlatformCC}(device: ALCdevice);
	alcCaptureStop-: PROCEDURE{PlatformCC}(device: ALCdevice);
	alcCaptureSamples-: PROCEDURE{PlatformCC}(device: ALCdevice; buffer: ALCvoid; samples: ALCsizei);
	
(** Wrapper for Unix.Dlsym *)
PROCEDURE GetProcAddress* (lib: HostLibs.LibHandle; CONST procName: ARRAY OF CHAR; adr: ADDRESS );
VAR res: BOOLEAN;
BEGIN
	res := HostLibs.GetProcedure(lib, procName, adr);
END GetProcAddress;

PROCEDURE LoadFunctions;
VAR res: BOOLEAN;
BEGIN
	res := HostLibs.LoadLibrary(libname, oalib);
	ASSERT(oalib # NIL, 103);

	(* AL *)
	GetProcAddress( oalib, "alEnable", ADDRESSOF( alEnable));
	GetProcAddress( oalib, "alDisable", ADDRESSOF( alDisable));
	GetProcAddress( oalib, "alIsEnabled", ADDRESSOF( alIsEnabled));
	GetProcAddress( oalib, "alGetBoolean", ADDRESSOF( alGetBoolean));
	GetProcAddress( oalib, "alGetInteger", ADDRESSOF( alGetInteger));
	GetProcAddress( oalib, "alGetFloat", ADDRESSOF( alGetFloat));
	GetProcAddress( oalib, "alGetDouble", ADDRESSOF( alGetDouble));
	GetProcAddress( oalib, "alGetBooleanv", ADDRESSOF( alGetBooleanv));
	GetProcAddress( oalib, "alGetIntegerv", ADDRESSOF( alGetIntegerv));
	GetProcAddress( oalib, "alGetFloatv", ADDRESSOF( alGetFloatv));
	GetProcAddress( oalib, "alGetDoublev", ADDRESSOF( alGetDoublev));
	GetProcAddress( oalib, "alGetString", ADDRESSOF( XalGetString));
	GetProcAddress( oalib, "alGetError", ADDRESSOF( alGetError));
	GetProcAddress( oalib, "alIsExtensionPresent", ADDRESSOF( alIsExtensionPresent));
	GetProcAddress( oalib, "alGetProcAddress", ADDRESSOF( XalGetProcAddress));
	GetProcAddress( oalib, "alGetEnumValue", ADDRESSOF( alGetEnumValue));

	GetProcAddress( oalib, "alListenerf", ADDRESSOF( alListenerf));
	GetProcAddress( oalib, "alListener3f", ADDRESSOF( alListener3f));
	GetProcAddress( oalib, "alListenerfv", ADDRESSOF( alListenerfv));
	GetProcAddress( oalib, "alListeneri", ADDRESSOF( alListeneri));
	GetProcAddress( oalib, "alListener3i", ADDRESSOF( alListener3i));
	GetProcAddress( oalib, "alListeneriv", ADDRESSOF( alListeneriv));

	GetProcAddress( oalib, "alGetListenerf", ADDRESSOF( alGetListenerf));
	GetProcAddress( oalib, "alGetListener3f", ADDRESSOF( alGetListener3f));
	GetProcAddress( oalib, "alGetListenerfv", ADDRESSOF( alGetListenerfv));
	GetProcAddress( oalib, "alGetListeneri", ADDRESSOF( alGetListeneri));
	GetProcAddress( oalib, "alGetListener3i", ADDRESSOF( alGetListener3i));
	GetProcAddress( oalib, "alGetListeneriv", ADDRESSOF( alGetListeneriv));

	GetProcAddress( oalib, "alGenSources", ADDRESSOF( alGenSources));
	GetProcAddress( oalib, "alDeleteSources", ADDRESSOF( alDeleteSources));
	GetProcAddress( oalib, "alIsSource", ADDRESSOF( alIsSource));
	GetProcAddress( oalib, "alSourcei", ADDRESSOF( alSourcei));

	GetProcAddress( oalib, "alSourcef", ADDRESSOF( alSourcef));
	GetProcAddress( oalib, "alSource3f", ADDRESSOF( alSource3f));
	GetProcAddress( oalib, "alSourcefv", ADDRESSOF( alSourcefv));
	GetProcAddress( oalib, "alSourcei", ADDRESSOF( alSourcei));
	GetProcAddress( oalib, "alSource3i", ADDRESSOF( alSource3i));
	GetProcAddress( oalib, "alSourceiv", ADDRESSOF( alSourceiv));

	GetProcAddress( oalib, "alGetSourcef", ADDRESSOF( alGetSourcef));
	GetProcAddress( oalib, "alGetSource3f", ADDRESSOF( alGetSource3f));
	GetProcAddress( oalib, "alGetSourcefv", ADDRESSOF( alGetSourcefv));
	GetProcAddress( oalib, "alGetSourcei", ADDRESSOF( alGetSourcei));
	GetProcAddress( oalib, "alGetSource3i", ADDRESSOF( alGetSource3i));
	GetProcAddress( oalib, "alGetSourceiv", ADDRESSOF( alGetSourceiv));

	GetProcAddress( oalib, "alSourcePlayv", ADDRESSOF( alSourcePlayv));
	GetProcAddress( oalib, "alSourcePausev", ADDRESSOF( alSourcePausev));
	GetProcAddress( oalib, "alSourceStopv", ADDRESSOF( alSourceStopv));
	GetProcAddress( oalib, "alSourceRewindv", ADDRESSOF( alSourceRewindv));
	GetProcAddress( oalib, "alSourcePlay", ADDRESSOF( alSourcePlay));
	GetProcAddress( oalib, "alSourcePause", ADDRESSOF( alSourcePause));
	GetProcAddress( oalib, "alSourceStop", ADDRESSOF( alSourceStop));
	GetProcAddress( oalib, "alSourceRewind", ADDRESSOF( alSourceRewind));

	GetProcAddress( oalib, "alGenBuffers", ADDRESSOF( alGenBuffers));
	GetProcAddress( oalib, "alDeleteBuffers", ADDRESSOF( alDeleteBuffers));
	GetProcAddress( oalib, "alIsBuffer", ADDRESSOF( alIsBuffer));
	GetProcAddress( oalib, "alBufferData", ADDRESSOF( alBufferData));

	GetProcAddress( oalib, "alBufferf", ADDRESSOF( alBufferf));
	GetProcAddress( oalib, "alBuffer3f", ADDRESSOF( alBuffer3f));
	GetProcAddress( oalib, "alBufferfv", ADDRESSOF( alBufferfv));
	GetProcAddress( oalib, "alBufferi", ADDRESSOF( alBufferi));
	GetProcAddress( oalib, "alBuffer3i", ADDRESSOF( alBuffer3i));
	GetProcAddress( oalib, "alBufferiv", ADDRESSOF( alBufferiv));

	GetProcAddress( oalib, "alGetBufferf", ADDRESSOF( alGetBufferf));
	GetProcAddress( oalib, "alGetBuffer3f", ADDRESSOF( alGetBuffer3f));
	GetProcAddress( oalib, "alGetBufferfv", ADDRESSOF( alGetBufferfv));
	GetProcAddress( oalib, "alGetBufferi", ADDRESSOF( alGetBufferi));
	GetProcAddress( oalib, "alGetBuffer3i", ADDRESSOF( alGetBuffer3i));
	GetProcAddress( oalib, "alGetBufferiv", ADDRESSOF( alGetBufferiv));

	GetProcAddress( oalib, "alSourceQueueBuffers", ADDRESSOF( alSourceQueueBuffers));
	GetProcAddress( oalib, "alSourceUnqueueBuffers", ADDRESSOF( alSourceUnqueueBuffers));
	GetProcAddress( oalib, "alDistanceModel", ADDRESSOF( alDistanceModel));
	GetProcAddress( oalib, "alDopplerFactor", ADDRESSOF( alDopplerFactor));
	GetProcAddress( oalib, "alSpeedOfSound", ADDRESSOF( alSpeedOfSound));
	GetProcAddress( oalib, "alDopplerVelocity", ADDRESSOF( alDopplerVelocity));
	
	(* ALC *)
	GetProcAddress( oalib, "alcOpenDevice", ADDRESSOF( alcOpenDevice));
	GetProcAddress( oalib, "alcCloseDevice", ADDRESSOF( alcCloseDevice));
	GetProcAddress( oalib, "alcCreateContext", ADDRESSOF( alcCreateContext));
	GetProcAddress( oalib, "alcMakeContextCurrent", ADDRESSOF( alcMakeContextCurrent));
	GetProcAddress( oalib, "alcProcessContext", ADDRESSOF( alcProcessContext));
	GetProcAddress( oalib, "alcGetCurrentContext", ADDRESSOF( alcGetCurrentContext));
	GetProcAddress( oalib, "alcGetContextsDevice", ADDRESSOF( alcGetContextsDevice));
	GetProcAddress( oalib, "alcSuspendContext", ADDRESSOF( alcSuspendContext));
	GetProcAddress( oalib, "alcDestroyContext", ADDRESSOF( alcDestroyContext));
	GetProcAddress( oalib, "alcGetError", ADDRESSOF( alcGetError));
	GetProcAddress( oalib, "alcGetString", ADDRESSOF( XalcGetString));
	GetProcAddress( oalib, "alcGetIntegerv", ADDRESSOF( alcGetIntegerv));

	GetProcAddress( oalib, "alcIsExtensionPresent", ADDRESSOF( alcIsExtensionPresent));
	GetProcAddress( oalib, "alcGetProcAddress", ADDRESSOF( XalcGetProcAddress));
	GetProcAddress( oalib, "alcGetEnumValue", ADDRESSOF( alcGetEnumValue));

	GetProcAddress( oalib, "alcCaptureOpenDevice", ADDRESSOF( alcCaptureOpenDevice));
	GetProcAddress( oalib, "alcCaptureCloseDevice", ADDRESSOF( alcCaptureCloseDevice));
	GetProcAddress( oalib, "alcCaptureStart", ADDRESSOF( alcCaptureStart));
	GetProcAddress( oalib, "alcCaptureStop", ADDRESSOF( alcCaptureStop));
	GetProcAddress( oalib, "alcCaptureSamples", ADDRESSOF( alcCaptureSamples));
END LoadFunctions;

PROCEDURE OnClose;
VAR res: BOOLEAN;
BEGIN
	res := HostLibs.FreeLibrary(oalib);
	IF res THEN
		KernelLog.String(libname); KernelLog.String(' unloaded.'); KernelLog.Ln;
	END;
END OnClose;

(* utilities, and wrappers  *)
PROCEDURE alGetProcAddress* (CONST funcName: ARRAY OF CHAR; adr: ADDRESS);
VAR adr0: ADDRESS;
BEGIN
	adr0 := XalGetProcAddress(funcName);
	SYSTEM.PUT(adr, adr0);
	IF debug THEN
		IF adr = 0  THEN KernelLog.String("alGetProcAddress: "); KernelLog.String(funcName); KernelLog.String(" NOT Found"); KernelLog.Ln; END;
	END;
END alGetProcAddress;

PROCEDURE alcGetProcAddress* (device : ALCdevice; CONST funcName: ARRAY OF CHAR; adr: ADDRESS);
VAR adr0: ADDRESS;
BEGIN
	adr0 := XalcGetProcAddress (device, funcName);
	SYSTEM.PUT(adr, adr0);
	IF debug THEN
		IF adr = 0  THEN KernelLog.String("Device alcGetProcAddress: "); KernelLog.String(funcName); KernelLog.String(" NOT Found"); KernelLog.Ln; END;
	END;
END alcGetProcAddress;

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

PROCEDURE alGetString*( name: ALenum): Strings.String;
VAR  sadr: ADDRESS;
BEGIN
	sadr := XalGetString( name);
	RETURN GetStringFromAddr(sadr);
END alGetString;

PROCEDURE alcGetString*(device: ALCdevice; name: ALCenum): Strings.String;
VAR  sadr: ADDRESS;
BEGIN
	sadr := XalcGetString(device, name);
	RETURN GetStringFromAddr(sadr);
END alcGetString;

PROCEDURE GetDevStringFromAddr*(adr: ADDRESS): Strings.String;
VAR 
	pstr : POINTER {UNSAFE} TO ARRAY MAX(SIZE) OF CHAR;
	str: Strings.String;
	pos: SIGNED32; 
BEGIN
	pstr := adr;
	pos := 0;
		WHILE pstr[pos] # 0X DO INC(pos); END;
		IF pos = 0 THEN RETURN NIL END;
		
		NEW(str, pos + 1);
		pos := 0;
		WHILE pstr[pos] # 0X DO str[pos] := pstr[pos]; 	INC(pos); END;
	str[pos] := 0X;

	RETURN str;
END GetDevStringFromAddr;


(** go through device list,  (each device terminated with a single NULL, list terminated with double NULL *)
PROCEDURE ALCGetDeviceList*(device: ALCdevice; name: ALCenum): StringArray;
VAR  
	dynstr: StringArray;
	pstr : POINTER {UNSAFE} TO ARRAY MAX(SIZE) OF CHAR;
	size: SIGNED32; 
	adr: ADDRESS;
	str : Strings.String;
BEGIN
	(* count the number of devices in the list *)

	pstr := XalcGetString(device, name);
	(* count array size *)
	IF pstr = NIL THEN RETURN NIL END;
	adr := pstr;
	str := GetDevStringFromAddr(pstr);
	WHILE (str # NIL) & (size < 10) DO		
		adr := adr + Strings.Length(str^) + 1;
		str := GetDevStringFromAddr(adr);
		INC(size)
	END;	

	NEW(dynstr, size);
	
	(* copy data *)
	size := 0;
	adr := pstr;
	str := GetDevStringFromAddr(pstr);
	WHILE (str # NIL) & (size < 10) DO
		dynstr[size] := str;	
		adr := adr + Strings.Length(str^) + 1;
		str := GetDevStringFromAddr(adr);
		INC(size)
	END;	

	RETURN dynstr;
END ALCGetDeviceList;


BEGIN
	LoadFunctions;
	Modules.InstallTermHandler(OnClose) ;
END OpenAL.

