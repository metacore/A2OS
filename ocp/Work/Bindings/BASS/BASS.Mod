MODULE BASS; (** AUTHOR "SAGE"; PURPOSE "BASS 2.4 A2 OS Wrapper module"; *)

IMPORT

	SYSTEM, Modules, HostLibs,

	#IF DARWIN & I386 THEN
		Strings,
	#END

	KernelLog;

VAR oalib-: HostLibs.LibHandle;

CONST

	#IF UNIX THEN
		libname			= "libbass.so";
	#ELSIF DARWIN THEN
		libname			= "libbass.dylib";
	#ELSIF WIN THEN
		#IF I386 THEN
			libname		= "bass.dll";
		#ELSIF AMD64 THEN
			libname		= "bass64.dll";
		#ELSE
			UNIMPLEMENTED
		#END
	#ELSE
		UNIMPLEMENTED
	#END

	(* API version *)
	BASSVERSION*										= 204H;
	BASSVERSIONTEXT*								= "2.4";

	(* Use these to test for error from functions that return a DWORD or QWORD *)
	DW_ERROR*												= SIGNED32(-1);
	QW_ERROR*												= SIGNED64(-1);

	(* Error codes returned by BASS_ErrorGetCode() *)
	BASS_OK	*												= 0;	(* all is OK *)
	BASS_ERROR_MEM*								= 1;	(* memory error *)
	BASS_ERROR_FILEOPEN*					= 2;	(* can't open the file *)
	BASS_ERROR_DRIVER*							= 3;	(* can't find a free sound driver *)
	BASS_ERROR_BUFLOST*						= 4;	(* the sample buffer was lost *)
	BASS_ERROR_HANDLE*							= 5;	(* invalid handle *)
	BASS_ERROR_FORMAT*							= 6;	(* unsupported sample format *)
	BASS_ERROR_POSITION*					= 7;	(* invalid position *)
	BASS_ERROR_INIT*								= 8;	(* BASS_Init has not been successfully called *)
	BASS_ERROR_START*							= 9;	(* BASS_Start has not been successfully called *)
	BASS_ERROR_ALREADY*						= 14;	(* already initialized/paused/whatever *)
	BASS_ERROR_NOCHAN*							= 18;	(* can't get a free channel *)
	BASS_ERROR_ILLTYPE*						= 19;	(* an illegal type was specified *)
	BASS_ERROR_ILLPARAM*					= 20;	(* an illegal parameter was specified *)
	BASS_ERROR_NO3D*								= 21;	(* no 3D support *)
	BASS_ERROR_NOEAX*							= 22;	(* no EAX support *)
	BASS_ERROR_DEVICE*							= 23;	(* illegal device number *)
	BASS_ERROR_NOPLAY*							= 24;	(* not playing *)
	BASS_ERROR_FREQ*								= 25;	(* illegal sample rate *)
	BASS_ERROR_NOTFILE*						= 27;	(* the stream is not a file stream *)
	BASS_ERROR_NOHW*								= 29;	(* no hardware voices available *)
	BASS_ERROR_EMPTY*							= 31;	(* the MOD music has no sequence data *)
	BASS_ERROR_NONET*							= 32;	(* no internet connection could be opened *)
	BASS_ERROR_CREATE*							= 33;	(* couldn't create the file *)
	BASS_ERROR_NOFX*								= 34;	(* effects are not available *)
	BASS_ERROR_NOTAVAIL*					= 37;	 (* requested data is not available *)
	BASS_ERROR_DECODE*						= 38;	 (* the channel is/isn't a "decoding channel" *)
	BASS_ERROR_DX*									= 39;	 (* a sufficient DirectX version is not installed *)
	BASS_ERROR_TIMEOUT*						= 40;	 (* connection timedout *)
	BASS_ERROR_FILEFORM*					= 41; 	(* unsupported file format *)
	BASS_ERROR_SPEAKER*						= 42;	 (* unavailable speaker *)
	BASS_ERROR_VERSION*						= 43;	 (* invalid BASS version (used by add-ons) *)
	BASS_ERROR_CODEC*							= 44;	 (* codec is not available/supported *)
	BASS_ERROR_ENDED*							= 45;	(* the channel/file has ended *)
	BASS_ERROR_BUSY*								= 46;	(* the device is busy *)
	BASS_ERROR_UNKNOWN*						= -1;	(* some other mystery problem *)

	(* BASS_SetConfig options *)
	BASS_CONFIG_BUFFER*						= 0;
	BASS_CONFIG_UPDATEPERIOD*			= 1;
	BASS_CONFIG_GVOL_SAMPLE*			= 4;
	BASS_CONFIG_GVOL_STREAM*			= 5;
	BASS_CONFIG_GVOL_MUSIC*				= 6;
	BASS_CONFIG_CURVE_VOL*				= 7;
	BASS_CONFIG_CURVE_PAN*				= 8;
	BASS_CONFIG_FLOATDSP*					= 9;
	BASS_CONFIG_3DALGORITHM*			= 10;
	BASS_CONFIG_NET_TIMEOUT*			= 11;
	BASS_CONFIG_NET_BUFFER*				= 12;
	BASS_CONFIG_PAUSE_NOPLAY*			= 13;
	BASS_CONFIG_NET_PREBUF*				= 15;
	BASS_CONFIG_NET_PASSIVE*			= 18;
	BASS_CONFIG_REC_BUFFER*				= 19;
	BASS_CONFIG_NET_PLAYLIST*			= 21;
	BASS_CONFIG_MUSIC_VIRTUAL*		= 22;
	BASS_CONFIG_VERIFY*						= 23;
	BASS_CONFIG_UPDATETHREADS*		= 24;
	BASS_CONFIG_DEV_BUFFER*				= 27;
	BASS_CONFIG_VISTA_TRUEPOS*		= 30;
	BASS_CONFIG_IOS_MIXAUDIO*			= 34;
	BASS_CONFIG_DEV_DEFAULT*			= 36;
	BASS_CONFIG_NET_READTIMEOUT*	= 37;
	BASS_CONFIG_VISTA_SPEAKERS*		= 38;
	BASS_CONFIG_IOS_SPEAKER*			= 39;
	BASS_CONFIG_MF_DISABLE*				= 40;
	BASS_CONFIG_HANDLES*					= 41;
	BASS_CONFIG_UNICODE*					= 42;
	BASS_CONFIG_SRC*								= 43;
	BASS_CONFIG_SRC_SAMPLE*				= 44;
	BASS_CONFIG_ASYNCFILE_BUFFER*= 45;
	BASS_CONFIG_OGG_PRESCAN*			= 47;
	BASS_CONFIG_MF_VIDEO*					= 48;
	BASS_CONFIG_AIRPLAY*					= 49;
	BASS_CONFIG_DEV_NONSTOP*			= 50;
	BASS_CONFIG_IOS_NOCATEGORY*		= 51;
	BASS_CONFIG_VERIFY_NET*				= 52;
	BASS_CONFIG_DEV_PERIOD*				= 53;
	BASS_CONFIG_FLOAT*							= 54;

	(* BASS_SetConfigPtr options *)
	BASS_CONFIG_NET_AGENT*				= 16;
	BASS_CONFIG_NET_PROXY*				= 17;

	(* BASS_Init flags *)
	BASS_DEVICE_8BITS*							= {0}		(*    1H *);	(* 8 bit *)
	BASS_DEVICE_MONO*							= {1}		(*    2H *);	(* mono *)
	BASS_DEVICE_3D*								= {2}		(*    4H *);	(* enable 3D functionality *)
	BASS_DEVICE_16BITS*						= {3}		(*    8H *);	(* limit output to 16 bit *)
	BASS_DEVICE_LATENCY*					= {8}		(*  100H *);	(* calculate device latency (BASS_INFO struct) *)
	BASS_DEVICE_CPSPEAKERS*				= {10}	(*  400H *);	(* detect speakers via Windows control panel *)
	BASS_DEVICE_SPEAKERS*					= {11}	(*  800H *);	(* force enabling of speaker assignment *)
	BASS_DEVICE_NOSPEAKER*				= {12}	(* 1000H *);	(* ignore speaker arrangement *)
	BASS_DEVICE_DMIX*							= {13}	(* 2000H *);	(* use ALSA "dmix" plugin *)
	BASS_DEVICE_FREQ*							= {14}	(* 4000H *);	(* set device sample rate *)
	BASS_DEVICE_STEREO*						= {15}	(* 8000H *);	(* limit output to stereo *)

	(* DirectSound interfaces (for use with BASS_GetDSoundObject) *)
	BASS_OBJECT_DS*								= 1;	(* IDirectSound *)
	BASS_OBJECT_DS3DL*							= 2;	(* IDirectSound3DListener *)

	(* BASS_DEVICEINFO flags *)
	BASS_DEVICE_ENABLED*					= {0};
	BASS_DEVICE_DEFAULT*					= {1};
	BASS_DEVICE_INIT*							= {2};

	BASS_DEVICE_TYPE_MASK*				= 0FF000000H;
	BASS_DEVICE_TYPE_NETWORK*			= {24}				(*  1000000H *);
	BASS_DEVICE_TYPE_SPEAKERS*		= {25}				(*  2000000H *);
	BASS_DEVICE_TYPE_LINE*				= {24,25}			(*  3000000H *);
	BASS_DEVICE_TYPE_HEADPHONES*	= {26}				(*  4000000H *);
	BASS_DEVICE_TYPE_MICROPHONE*	= {24,26}			(*  5000000H *);
	BASS_DEVICE_TYPE_HEADSET*			= {25,26}			(*  6000000H *);
	BASS_DEVICE_TYPE_HANDSET*			= {24,25,26}	(*  7000000H *);
	BASS_DEVICE_TYPE_DIGITAL*			= {27}				(*  8000000H *);
	BASS_DEVICE_TYPE_SPDIF*				= {24,27}			(*  9000000H *);
	BASS_DEVICE_TYPE_HDMI*				= {25,27}			(* 0A000000H *);
	BASS_DEVICE_TYPE_DISPLAYPORT*= {30}				(* 40000000H *);

	(* BASS_GetDeviceInfo flags *)
	BASS_DEVICES_AIRPLAY*					= {24}				(*  1000000H *);

	(* BASS_INFO flags (from DSOUND.H) *)
	DSCAPS_CONTINUOUSRATE*				= {4}		(*   10H *);	(* supports all sample rates between min/maxrate *)
	DSCAPS_EMULDRIVER*							= {5}		(*   20H *);	(* device does NOT have hardware DirectSound support *)
	DSCAPS_CERTIFIED*							= {6}		(*   40H *);	(* device driver has been certified by Microsoft *)
	DSCAPS_SECONDARYMONO*					= {8}		(*  100H *);	(* mono *)
	DSCAPS_SECONDARYSTEREO*				= {9}		(*  200H *);	(* stereo *)
	DSCAPS_SECONDARY8BIT*					= {10}	(*  400H *);	(* 8 bit *)
	DSCAPS_SECONDARY16BIT*				= {11}	(*  800H *);	(* 16 bit *)

	(* BASS_RECORDINFO flags (from DSOUND.H) *)
	DSCCAPS_EMULDRIVER*						= DSCAPS_EMULDRIVER;(* device does NOT have hardware DirectSound recording support *)
	DSCCAPS_CERTIFIED*							= DSCAPS_CERTIFIED;	(* device driver has been certified by Microsoft *)

	(* defines for formats field of BASS_RECORDINFO (from MMSYSTEM.H) *)
	WAVE_FORMAT_1M08*							= {0} 	(*   1H *);	(* 11.025 kHz, Mono,    8-bit *)
	WAVE_FORMAT_1S08*							= {1}		(*   2H *);	(* 11.025 kHz, Stereo,  8-bit *)
	WAVE_FORMAT_1M16*							= {2}		(*   4H *);	(* 11.025 kHz, Mono,   16-bit *)
	WAVE_FORMAT_1S16*							= {3}		(*   8H *);	(* 11.025 kHz, Stereo, 16-bit *)
	WAVE_FORMAT_2M08*							= {4}		(*  10H *);	(* 22.05  kHz, Mono,    8-bit *)
	WAVE_FORMAT_2S08*							= {5}		(*  20H *);	(* 22.05  kHz, Stereo,  8-bit *)
	WAVE_FORMAT_2M16*							= {6}		(*  40H *);	(* 22.05  kHz, Mono,   16-bit *)
	WAVE_FORMAT_2S16*							= {7}		(*  80H *);	(* 22.05  kHz, Stereo, 16-bit *)
	WAVE_FORMAT_4M08*							= {8}		(* 100H *);	(* 44.1   kHz, Mono,    8-bit *)
	WAVE_FORMAT_4S08*							= {9}		(* 200H *);	(* 44.1   kHz, Stereo,  8-bit *)
	WAVE_FORMAT_4M16*							= {10}	(* 400H *);	(* 44.1   kHz, Mono,   16-bit *)
	WAVE_FORMAT_4S16*							= {11}	(* 800H *);	(* 44.1   kHz, Stereo, 16-bit *)

	BASS_SAMPLE_8BITS*							= {0}			(*      1 *);	(* 8 bit *)
	BASS_SAMPLE_FLOAT*							= {8}			(*    256 *);	(* 32-bit floating-point *)
	BASS_SAMPLE_MONO*							= {1}			(*      2 *);	(* mono *)
	BASS_SAMPLE_LOOP*							= {2}			(*      4 *);	(* looped *)
	BASS_SAMPLE_3D*								= {3}			(*      8 *);	(* 3D functionality *)
	BASS_SAMPLE_SOFTWARE*					= {4}			(*     16 *);	(* not using hardware mixing *)
	BASS_SAMPLE_MUTEMAX*					= {5}			(*     32 *);	(* mute at max distance (3D only) *)
	BASS_SAMPLE_VAM*								= {6}			(*     64 *);	(* DX7 voice allocation & management *)
	BASS_SAMPLE_FX*								= {7}			(*    128 *);	(* old implementation of DX8 effects *)
	BASS_SAMPLE_OVER_VOL*					= {16}		(* 10000H *);	(* override lowest volume *)
	BASS_SAMPLE_OVER_POS*					= {17}		(* 20000H *);	(* override longest playing *)
	BASS_SAMPLE_OVER_DIST*				= {16,17}(* 30000H *);	(* override furthest from listener (3D only) *)

	BASS_STREAM_PRESCAN*					= {17}		(*  20000H *);	(* enable pin-point seeking/length (MP3/MP2/MP1) *)
	BASS_MP3_SETPOS*								= BASS_STREAM_PRESCAN;
	BASS_STREAM_AUTOFREE*					= {18}		(*  40000H *);	(* automatically free the stream when it stop/ends *)
	BASS_STREAM_RESTRATE*					= {19}		(*  80000H *);	(* restrict the download rate of internet file streams *)
	BASS_STREAM_BLOCK*							= {20}		(* 100000H *);	(* download/play internet file stream in small blocks *)
	BASS_STREAM_DECODE	*						= {21}		(* 200000H *);	(* don't play the stream, only decode (BASS_ChannelGetData) *)
	BASS_STREAM_STATUS*						= {23}		(* 800000H *);	(* give server status info (HTTP/ICY tags) in DOWNLOADPROC *)

	BASS_MUSIC_FLOAT*							= BASS_SAMPLE_FLOAT;
	BASS_MUSIC_MONO*								= BASS_SAMPLE_MONO;
	BASS_MUSIC_LOOP*								= BASS_SAMPLE_LOOP;
	BASS_MUSIC_3D*									= BASS_SAMPLE_3D;
	BASS_MUSIC_FX*									= BASS_SAMPLE_FX;
	BASS_MUSIC_AUTOFREE*					= BASS_STREAM_AUTOFREE;
	BASS_MUSIC_DECODE*							= BASS_STREAM_DECODE;
	BASS_MUSIC_PRESCAN*						= BASS_STREAM_PRESCAN;	(* calculate playback length *)
	BASS_MUSIC_CALCLEN*						= BASS_MUSIC_PRESCAN;
	BASS_MUSIC_RAMP*								= {9}			(*    200H *);	(* normal ramping *)
	BASS_MUSIC_RAMPS*							= {10}		(*    400H *);	(* sensitive ramping *)
	BASS_MUSIC_SURROUND*					= {11}		(*    800H *);	(* surround sound *)
	BASS_MUSIC_SURROUND2*					= {12}		(*   1000H *);	(* surround sound (mode 2) *)
	BASS_MUSIC_FT2PAN*							= {13}		(*   2000H *);	(* apply FastTracker 2 panning to XM files *)
	BASS_MUSIC_FT2MOD*							= {13}		(*   2000H *);	(* play .MOD as FastTracker 2 does *)
	BASS_MUSIC_PT1MOD*							= {14}		(*   4000H *);	(* play .MOD as ProTracker 1 does *)
	BASS_MUSIC_NONINTER*					= {16}		(*  10000H *);	(* non-interpolated sample mixing *)
	BASS_MUSIC_SINCINTER*					= {23}		(* 800000H *);	(* sinc interpolated sample mixing *)
	BASS_MUSIC_POSRESET*					= {15}		(*   8000H *);	(* stop all notes when moving position *)
	BASS_MUSIC_POSRESETEX*				= {22}		(* 400000H *);	(* stop all notes and reset bmp/etc when moving position *)
	BASS_MUSIC_STOPBACK*					= {19}		(*  80000H *);	(* stop the music on a backwards jump effect *)
	BASS_MUSIC_NOSAMPLE*					= {20}		(* 100000H *);	(* don't load the samples *)

	(* Speaker assignment flags *)
	BASS_SPEAKER_FRONT*						= {24}		(*  1000000H *);	(* front speakers *)
	BASS_SPEAKER_REAR*							= {25}		(*  2000000H *);	(* rear/side speakers *)
	BASS_SPEAKER_CENLFE*					= {24,25}	(*  3000000H *);	(* center & LFE speakers (5.1) *)
	BASS_SPEAKER_REAR2*						= {26}		(*  4000000H *);	(* rear center speakers (7.1) *)
	BASS_SPEAKER_LEFT*							= {28}		(* 10000000H *);	(* modifier: left *)
	BASS_SPEAKER_RIGHT*						= {29}		(* 20000000H *);	(* modifier: right *)
	BASS_SPEAKER_FRONTLEFT*				= BASS_SPEAKER_FRONT + BASS_SPEAKER_LEFT;
	BASS_SPEAKER_FRONTRIGHT*			= BASS_SPEAKER_FRONT + BASS_SPEAKER_RIGHT;
	BASS_SPEAKER_REARLEFT*				= BASS_SPEAKER_REAR + BASS_SPEAKER_LEFT;
	BASS_SPEAKER_REARRIGHT*				= BASS_SPEAKER_REAR + BASS_SPEAKER_RIGHT;
	BASS_SPEAKER_CENTER*					= BASS_SPEAKER_CENLFE + BASS_SPEAKER_LEFT;
	BASS_SPEAKER_LFE*							= BASS_SPEAKER_CENLFE + BASS_SPEAKER_RIGHT;
	BASS_SPEAKER_REAR2LEFT*				= BASS_SPEAKER_REAR2 + BASS_SPEAKER_LEFT;
	BASS_SPEAKER_REAR2RIGHT*			= BASS_SPEAKER_REAR2 + BASS_SPEAKER_RIGHT;

	BASS_ASYNCFILE*								= {30}		(* 40000000H *);
	BASS_UNICODE*									= {31}		(* 80000000H *);

	BASS_RECORD_PAUSE*							= {15}		(*     8000H *);	(* start recording paused *)

	(* DX7 voice allocation & management flags *)
	BASS_VAM_HARDWARE*							= {0}			(*  1 *);
	BASS_VAM_SOFTWARE*							= {1}			(*  2 *);
	BASS_VAM_TERM_TIME*						= {2}			(*  4 *);
	BASS_VAM_TERM_DIST*						= {3}			(*  8 *);
	BASS_VAM_TERM_PRIO	*						= {4}			(* 16 *);

	(* BASS_CHANNELINFO types *)
	BASS_CTYPE_SAMPLE*							= {0}						(*     1H *);
	BASS_CTYPE_RECORD*							= {1}						(*     2H *);
	BASS_CTYPE_STREAM*							= {16}					(* 10000H *);
	BASS_CTYPE_STREAM_OGG*				= {1,16}				(* 10002H *);
	BASS_CTYPE_STREAM_MP1*				= {0,1,16}			(* 10003H *);
	BASS_CTYPE_STREAM_MP2*				= {2,16}				(* 10004H *);
	BASS_CTYPE_STREAM_MP3*				= {0,2,16}			(* 10005H *);
	BASS_CTYPE_STREAM_AIFF*				= {1,2,16}			(* 10006H *);
	BASS_CTYPE_STREAM_WAV*				= {18}					(* 40000H *);	(* WAVE flag, LOWORD=codec *)
	BASS_CTYPE_STREAM_WAV_PCM*		= {0,16,18}		(* 50001H *);
	BASS_CTYPE_STREAM_WAV_FLOAT*	= {0,1,16,18}	(* 50003H *);
	BASS_CTYPE_MUSIC_MOD*					= {17}					(* 20000H *);
	BASS_CTYPE_MUSIC_MTM*					= {0,17}				(* 20001H *);
	BASS_CTYPE_MUSIC_S3M*					= {1,17}				(* 20002H *);
	BASS_CTYPE_MUSIC_XM*					= {0,1,17}			(* 20003H *);
	BASS_CTYPE_MUSIC_IT*		 			= {2,17}				(* 20004H *);

	(* MO3 format flag, used in combination with one of the BASS_CTYPE_MUSIC_xxx *)
	BASS_CTYPE_MUSIC_MO3*					= {8}						(*   100H *);

	(* 3D channel modes *)
	BASS_3DMODE_NORMAL*						= 0; (* normal 3D processing *)
	BASS_3DMODE_RELATIVE*					= 1; (* position is relative to the listener *)
	BASS_3DMODE_OFF*								= 2; (* no 3D processing *)

	(* software 3D mixing algorithms (used with BASS_CONFIG_3DALGORITHM) *)
	BASS_3DALG_DEFAULT*						= 0;
	BASS_3DALG_OFF*								= 1;
	BASS_3DALG_FULL*								= 2;
	BASS_3DALG_LIGHT*							= 3;

	(* EAX environments, use with BASS_SetEAXParameters *)
	EAX_ENVIRONMENT_GENERIC*					= 0;
	EAX_ENVIRONMENT_PADDEDCELL*				= 1;
	EAX_ENVIRONMENT_ROOM*							= 2;
	EAX_ENVIRONMENT_BATHROOM*					= 3;
	EAX_ENVIRONMENT_LIVINGROOM*				= 4;
	EAX_ENVIRONMENT_STONEROOM*				= 5;
	EAX_ENVIRONMENT_AUDITORIUM*				= 6;
	EAX_ENVIRONMENT_CONCERTHALL*			= 7;
	EAX_ENVIRONMENT_CAVE*							= 8;
	EAX_ENVIRONMENT_ARENA*						= 9;
	EAX_ENVIRONMENT_HANGAR*						= 10;
	EAX_ENVIRONMENT_CARPETEDHALLWAY*	= 11;
	EAX_ENVIRONMENT_HALLWAY*					= 12;
	EAX_ENVIRONMENT_STONECORRIDOR*		= 13;
	EAX_ENVIRONMENT_ALLEY*						= 14;
	EAX_ENVIRONMENT_FOREST*						= 15;
	EAX_ENVIRONMENT_CITY*							= 16;
	EAX_ENVIRONMENT_MOUNTAINS*				= 17;
	EAX_ENVIRONMENT_QUARRY*						= 18;
	EAX_ENVIRONMENT_PLAIN*						= 19;
	EAX_ENVIRONMENT_PARKINGLOT*				= 20;
	EAX_ENVIRONMENT_SEWERPIPE*				= 21;
	EAX_ENVIRONMENT_UNDERWATER*				= 22;
	EAX_ENVIRONMENT_DRUGGED*					= 23;
	EAX_ENVIRONMENT_DIZZY*						= 24;
	EAX_ENVIRONMENT_PSYCHOTIC*				= 25;
	(* total number of environments *)
	EAX_ENVIRONMENT_COUNT*						= 26;

	BASS_STREAMPROC_END*		= 80000000H; (* end of user stream flag *)

	(* BASS_StreamCreateFileUser file systems *)
	STREAMFILE_NOBUFFER*		= 0;
	STREAMFILE_BUFFER*				= 1;
	STREAMFILE_BUFFERPUSH*	= 2;

	(* BASS_StreamPutFileData options *)
	BASS_FILEDATA_END*				= 0; (* end & close the file *)

	(* BASS_StreamGetFilePosition modes *)
	BASS_FILEPOS_CURRENT*		= 0;
	BASS_FILEPOS_DECODE*		= BASS_FILEPOS_CURRENT;
	BASS_FILEPOS_DOWNLOAD*	= 1;
	BASS_FILEPOS_END*				= 2;
	BASS_FILEPOS_START*			= 3;
	BASS_FILEPOS_CONNECTED*	= 4;
	BASS_FILEPOS_BUFFER*		= 5;
	BASS_FILEPOS_SOCKET*		= 6;
	BASS_FILEPOS_ASYNCBUF*	= 7;
	BASS_FILEPOS_SIZE*				= 8;

	(* BASS_ChannelSetSync types *)
	BASS_SYNC_POS*						= {}			(*  0 *);
	BASS_SYNC_END*						= {1}			(*  2 *);
	BASS_SYNC_META*					= {2}			(*  4 *);
	BASS_SYNC_SLIDE*					= {0,2}		(*  5 *);
	BASS_SYNC_STALL*					= {1,2}		(*  6 *);
	BASS_SYNC_DOWNLOAD*			= {0,1,2}	(*  7 *);
	BASS_SYNC_FREE*					= {3}			(*  8 *);
	BASS_SYNC_SETPOS*				= {0,1,3}	(* 11 *);
	BASS_SYNC_MUSICPOS*			= {1,3}		(* 10 *);
	BASS_SYNC_MUSICINST*		= {0}			(*  1 *);
	BASS_SYNC_MUSICFX*				= {0,1}		(*  3 *);
	BASS_SYNC_OGG_CHANGE*		= {2,3}		(* 12 *);
	BASS_SYNC_MIXTIME*				= {30}		(* 40000000H *); (* flag: sync at mixtime, else at playtime *)
	BASS_SYNC_ONETIME*				= {31}		(* 80000000H *); (* flag: sync only once, else continuously *)

	(* BASS_ChannelIsActive return values *)
	BASS_ACTIVE_STOPPED* 		= 0;
	BASS_ACTIVE_PLAYING* 		= 1;
	BASS_ACTIVE_STALLED* 		= 2;
	BASS_ACTIVE_PAUSED*			= 3;

	(* Channel attributes *)
	BASS_ATTRIB_FREQ*									= 1;
	BASS_ATTRIB_VOL*										= 2;
	BASS_ATTRIB_PAN*										= 3;
	BASS_ATTRIB_EAXMIX*								= 4;
	BASS_ATTRIB_NOBUFFER*							= 5;
	BASS_ATTRIB_VBR*										= 6;
	BASS_ATTRIB_CPU*										= 7;
	BASS_ATTRIB_SRC*										= 8;
	BASS_ATTRIB_NET_RESUME*						= 9;
	BASS_ATTRIB_SCANINFO*							= 10;
	BASS_ATTRIB_NORAMP	*								= 11;
	BASS_ATTRIB_BITRATE*							= 12;
	BASS_ATTRIB_MUSIC_AMPLIFY*				= 100H;
	BASS_ATTRIB_MUSIC_PANSEP*					= 101H;
	BASS_ATTRIB_MUSIC_PSCALER*				= 102H;
	BASS_ATTRIB_MUSIC_BPM*						= 103H;
	BASS_ATTRIB_MUSIC_SPEED*					= 104H;
	BASS_ATTRIB_MUSIC_VOL_GLOBAL*			= 105H;
	BASS_ATTRIB_MUSIC_ACTIVE*					= 106H;
	BASS_ATTRIB_MUSIC_VOL_CHAN*				= 200H; (* + channel # *)
	BASS_ATTRIB_MUSIC_VOL_INST*				= 300H; (* + instrument # *)

	(* BASS_ChannelGetData flags *)
	BASS_DATA_AVAILABLE*			= {}					(* 0 *);					(* query how much data is buffered *)
	BASS_DATA_FIXED*						= {29}				(* 20000000H *);	(* flag: return 8.24 fixed-point data *)
	BASS_DATA_FLOAT*						= {30}				(* 40000000H *);	(* flag: return floating-point sample data *)
	BASS_DATA_FFT256*					= {31}				(* 80000000H *);	(* 256 sample FFT *)
	BASS_DATA_FFT512*					= {0,31}			(* 80000001H *);	(* 512 FFT *)
	BASS_DATA_FFT1024*	 				= {1,31}			(* 80000002H *);	(* 1024 FFT *)
	BASS_DATA_FFT2048*	 				= {0,1,31}		(* 80000003H *);	(* 2048 FFT *)
	BASS_DATA_FFT4096*	 				= {2,31}			(* 80000004H *);	(* 4096 FFT *)
	BASS_DATA_FFT8192*	 				= {0,2,31}		(* 80000005H *);	(* 8192 FFT *)
	BASS_DATA_FFT16384*				= {1,2,31}		(* 80000006H *);	(* 16384 FFT *)
	BASS_DATA_FFT32768*				= {0,1,2,31}	(* 80000007H *);	(* 32768 FFT *)
	BASS_DATA_FFT_INDIVIDUAL*	= {4}					(*       10H *);	(* FFT flag: FFT for each channel, else all combined *)
	BASS_DATA_FFT_NOWINDOW*		= {5}					(*       20H *);	(*	 FFT flag: no Hanning window *)
	BASS_DATA_FFT_REMOVEDC*		= {6}					(*       40H *);	(*	 FFT flag: pre-remove DC bias *)
	BASS_DATA_FFT_COMPLEX*		= {7}					(*       80H *);	(* FFT flag: return complex data *)

	(* BASS_ChannelGetLevelEx flags *)
	BASS_LEVEL_MONO*						= 1;
	BASS_LEVEL_STEREO*					= 2;
	BASS_LEVEL_RMS*						= 4;

	(* BASS_ChannelGetTags types : what's returned *)
	BASS_TAG_ID3*							= 0; (* ID3v1 tags : TAG_ID3 structure *)
	BASS_TAG_ID3V2*						= 1; (* ID3v2 tags : variable length block *)
	BASS_TAG_OGG*							= 2; (* OGG comments : series of null-terminated UTF-8 strings *)
	BASS_TAG_HTTP*							= 3; (* HTTP headers : series of null-terminated ANSI strings *)
	BASS_TAG_ICY*							= 4; (* ICY headers : series of null-terminated ANSI strings *)
	BASS_TAG_META*							= 5; (* ICY metadata : ANSI string *)
	BASS_TAG_APE*							= 6; (* APEv2 tags : series of null-terminated UTF-8 strings *)
	BASS_TAG_MP4*							= 7; (* MP4/iTunes metadata : series of null-terminated UTF-8 strings *)
	BASS_TAG_WMA*							= 8; (* WMA tags : series of null-terminated UTF-8 strings *)
	BASS_TAG_VENDOR*						= 9; (* OGG encoder : UTF-8 string *)
	BASS_TAG_LYRICS3*					= 10; (* Lyric3v2 tag : ASCII string *)
	BASS_TAG_CA_CODEC*	 				= 11;	 (* CoreAudio codec info : TAG_CA_CODEC structure *)
	BASS_TAG_MF*								= 13;	 (* Media Foundation tags : series of null-terminated UTF-8 strings *)
	BASS_TAG_WAVEFORMAT*			= 14;	 (* WAVE format : WAVEFORMATEEX structure *)
	BASS_TAG_RIFF_INFO*				= 100H; (* RIFF "INFO" tags : series of null-terminated ANSI strings *)
	BASS_TAG_RIFF_BEXT*				= 101H; (* RIFF/BWF "bext" tags : TAG_BEXT structure *)
	BASS_TAG_RIFF_CART*				= 102H; (* RIFF/BWF "cart" tags : TAG_CART structure *)
	BASS_TAG_RIFF_DISP*				= 103H; (* RIFF "DISP" text tag : ANSI string *)
	BASS_TAG_APE_BINARY*			= 1000H; (* + index #, binary APEv2 tag : TAG_APE_BINARY structure *)
	BASS_TAG_MUSIC_NAME*			= 10000H;	(* MOD music name : ANSI string *)
	BASS_TAG_MUSIC_MESSAGE*		= 10001H; (* MOD message : ANSI string *)
	BASS_TAG_MUSIC_ORDERS*		= 10002H; (* MOD order list : BYTE array of pattern numbers *)
	BASS_TAG_MUSIC_AUTH*			= 10003H; (* MOD author : UTF-8 string *)
	BASS_TAG_MUSIC_INST*			= 10100H;	(* + instrument #, MOD instrument name : ANSI string *)
	BASS_TAG_MUSIC_SAMPLE*		= 10300H; (* + sample #, MOD sample name : ANSI string *)

	(* BASS_ChannelGetLength/GetPosition/SetPosition modes *)
	BASS_POS_BYTE*							= {}			(* 0 *); 					(* byte position *)
	BASS_POS_MUSIC_ORDER*			= {0}			(* 1 *); 					(* order.row position, MAKELONG(order,row) *)
	BASS_POS_OGG*							= {0,1}		(* 3 *);					(* OGG bitstream number *)
	BASS_POS_INEXACT*					= {27}		(*  8000000H *);	(* flag: allow seeking to inexact position *)
	BASS_POS_DECODE*						= {28}		(* 10000000H *);	(* flag: get the decoding (not playing) position *)
	BASS_POS_DECODETO*					= {29}		(* 20000000H *);	(* flag: decode to the position instead of seeking *)
	BASS_POS_SCAN*							= {30}		(* 40000000H *);	(* flag: scan to the position *)

	(* BASS_RecordSetInput flags *)
	BASS_INPUT_OFF*						= {16}		(* 10000H *);
	BASS_INPUT_ON*							= {17}		(* 20000H *);

	BASS_INPUT_TYPE_MASK*					= 0FF000000H;
	BASS_INPUT_TYPE_UNDEF*				= {};
	BASS_INPUT_TYPE_DIGITAL*		 	= {24}				(*  1000000H *);
	BASS_INPUT_TYPE_LINE*					= {25}				(*  2000000H *);
	BASS_INPUT_TYPE_MIC*		 			= {24,25}			(*  3000000H *);
	BASS_INPUT_TYPE_SYNTH*				= {26}				(*  4000000H *);
	BASS_INPUT_TYPE_CD*						= {24,26}			(*  5000000H *);
	BASS_INPUT_TYPE_PHONE*				= {25,26}			(*  6000000H *);
	BASS_INPUT_TYPE_SPEAKER*			= {24,25,26}	(*  7000000H *);
	BASS_INPUT_TYPE_WAVE*					= {27}				(*  8000000H *);
	BASS_INPUT_TYPE_AUX*					= {24,27}			(*  9000000H *);
	BASS_INPUT_TYPE_ANALOG*				= {25,27}			(* 0A000000H *);

	BASS_FX_DX8_CHORUS*						= 0;
	BASS_FX_DX8_COMPRESSOR*				= 1;
	BASS_FX_DX8_DISTORTION*				= 2;
	BASS_FX_DX8_ECHO*							= 3;
	BASS_FX_DX8_FLANGER*					= 4;
	BASS_FX_DX8_GARGLE*						= 5;
	BASS_FX_DX8_I3DL2REVERB*			= 6;
	BASS_FX_DX8_PARAMEQ*					= 7;
	BASS_FX_DX8_REVERB*						= 8;

	BASS_DX8_PHASE_NEG_180*				= 0;
	BASS_DX8_PHASE_NEG_90*				= 1;
	BASS_DX8_PHASE_ZERO*					= 2;
	BASS_DX8_PHASE_90*							= 3;
	BASS_DX8_PHASE_180*						= 4;

TYPE

	DWORD* = UNSIGNED32;
	BOOL* = SIGNED32;
	QWORD = UNSIGNED64;
	Byte = CHAR;
	AnsiChar = CHAR;
	Word = INTEGER;
	PAnsiChar = ADDRESS;
	PChar = ADDRESS;
	PSingle = ADDRESS;
	HMUSIC = DWORD;		(* MOD music handle *)
	HSAMPLE = DWORD;		(* sample handle *)
	HCHANNEL = DWORD;	(* playing sample's channel handle *)
	HSTREAM* = DWORD;		(* sample stream handle *)
	HRECORD = DWORD;		(* recording handle *)
	HSYNC = DWORD;			(* synchronizer handle *)
	HDSP* = DWORD;			(* DSP handle *)
	HFX = DWORD;				(* DX8 effect handle *)
	HPLUGIN = DWORD;		(* Plugin handle *)

	(* Channel info structure *)
	BASS_CHANNELINFO* = RECORD
		freq*: DWORD;					(* default playback rate *)
		chans*: DWORD;					(* channels *)
		flags*: SET32;						(* BASS_SAMPLE/STREAM/MUSIC/SPEAKER flags *)
		ctype*: SET32;						(* type of channel *)
		origres*: DWORD;				(* original resolution *)
		plugin*: HPLUGIN;			(* plugin *)
		sample*: HSAMPLE;			(* sample *)

		#IF I386 THEN
		#ELSIF AMD64 THEN
			padding*: DWORD;
		#ELSE
			UNIMPLEMENTED
		#END

		filename*: PAnsiChar;	(* filename *)
	END;

	BASS_PLUGINFORM* = RECORD
		ctype*: DWORD;				(* channel type *)

		#IF I386 THEN
		#ELSIF AMD64 THEN
			padding*: DWORD;
		#ELSE
			UNIMPLEMENTED
		#END

		name*: PAnsiChar;		(* format description *)
		exts*: PAnsiChar;		(* file extension filter ( *.ext1;*.ext2;etc...) *)
	END;

	(* Device info structure *)
	BASS_DEVICEINFO* = RECORD
		name*: PAnsiChar;		(* description *)
		driver*: PAnsiChar;	(* driver *)
		flags*: SET32;
	END;

	BASS_INFO* = RECORD
		flags*: SET32;				(* device capabilities (DSCAPS_xxx flags) *)
		hwsize*: DWORD;		(* size of total device hardware memory *)
		hwfree*: DWORD;		(* size of free device hardware memory *)
		freesam*: DWORD;		(* number of free sample slots in the hardware *)
		free3d*: DWORD;		(* number of free 3D sample slots in the hardware *)
		minrate*: DWORD;		(* min sample rate supported by the hardware *)
		maxrate*: DWORD;		(* max sample rate supported by the hardware *)
		eax*: BOOL;				(* device supports EAX? (always FALSE if BASS_DEVICE_3D was not used) *)
		minbuf*: DWORD;		(* recommended minimum buffer length in ms (requires BASS_DEVICE_LATENCY) *)
		dsver*: DWORD;			(* DirectSound version *)
		latency*: DWORD;		(* delay (in ms) before start of playback (requires BASS_DEVICE_LATENCY) *)
		initflags*: SET32;		(*	 BASS_Init "flags" parameter *)
		speakers*: DWORD;	(* number of speakers available *)
		freq*: DWORD;			(* current output rate *)
	END;

	(* Recording device info structure *)
	BASS_RECORDINFO* = RECORD
		flags*: SET32;				(* device capabilities (DSCCAPS_xxx flags) *)
		formats*: SET32;			(* supported standard formats (WAVE_FORMAT_xxx flags) *)
		inputs*: DWORD;		(* number of inputs *)
		singlein*: BOOL;		(* only 1 input can be set at a time *)
		freq*: DWORD;			(* current input rate *)
	END;

	(* Sample info structure *)
	BASS_SAMPLE* = RECORD
		freq*: DWORD;			(* default playback rate *)
		volume*: FLOAT32;			(* default volume (0-100) *)
		pan*: FLOAT32;				(* default pan (-100=left, 0=middle, 100=right) *)
		flags*: SET32;				(* BASS_SAMPLE_xxx flags *)
		length*: DWORD;		(* length (in samples, not bytes) *)
		max*: DWORD;				(* maximum simultaneous playbacks *)
		origres*: DWORD;		(* original resolution *)
		chans*: DWORD;			(* number of channels *)
		mingap*: DWORD;		(* minimum gap (ms) between creating channels *)
		mode3d*: DWORD;		(* BASS_3DMODE_xxx mode *)
		mindist*: FLOAT32;		(* minimum distance *)
		maxdist*: FLOAT32;		(* maximum distance *)
		iangle*: DWORD;		(* angle of inside projection cone *)
		oangle*: DWORD;		(* angle of outside projection cone *)
		outvol*: FLOAT32;			(* delta-volume outside the projection cone *)
		vam*: SET32;					(* voice allocation/management flags (BASS_VAM_xxx) *)
		priority*: DWORD;	(* priority (0=lowest, $ffffffff=highest) *)
	END;

	(* PBASS_PLUGINFORMS = POINTER TO TBASS_PLUGINFORMS;
	TBASS_PLUGINFORMS = ARRAY[0..maxInt DIV sizeOf(BASS_PLUGINFORM) - 1] OF BASS_PLUGINFORM; *)
	PBASS_PLUGINFORMS* = POINTER TO ARRAY OF BASS_PLUGINFORM;
	PBASS_PLUGININFO* = POINTER TO BASS_PLUGININFO;
	BASS_PLUGININFO* = RECORD
		version*: DWORD;								(* version (same form as BASS_GetVersion) *)
		formatc*: DWORD;								(* number of formats *)
		formats*: PBASS_PLUGINFORMS;	(* the array of formats *)
	END;

	(* 3D vector (for 3D positions/velocities/orientations) *)
	BASS_3DVECTOR* = RECORD
		x*: FLOAT32;					(* +=right, -=left *)
		y*: FLOAT32;					(* +=up, -=down *)
		z*: FLOAT32;					(* +=front, -=behind *)
	END;

	(* User file stream callback functions *)
	FILECLOSEPROC* = PROCEDURE {PlatformCC} (user: ADDRESS);
	FILELENPROC* = PROCEDURE {PlatformCC} (user: ADDRESS): QWORD;
	FILEREADPROC* = PROCEDURE {PlatformCC} (buffer: ADDRESS; length: DWORD; user: ADDRESS): DWORD;
	FILESEEKPROC* = PROCEDURE {PlatformCC} (offset: QWORD; user: ADDRESS): BOOL;

	BASS_FILEPROCS* = RECORD
		close*: FILECLOSEPROC;
		length*: FILELENPROC;
		read*: FILEREADPROC;
		seek*: FILESEEKPROC;
	END;

	(* ID3v1 tag structure *)
	PTAG_ID3* = POINTER TO TAG_ID3;
	TAG_ID3* = RECORD
		id*: ARRAY 3 OF AnsiChar;
		title*: ARRAY 30 OF AnsiChar;
		artist*: ARRAY 30 OF AnsiChar;
		album*: ARRAY 30 OF AnsiChar;
		year*: ARRAY 4 OF AnsiChar;
		comment*: ARRAY 30 OF AnsiChar;
		genre*: Byte;
	END;

	(* Binary APEv2 tag structure *)
	PTAG_APE_BINARY* = POINTER TO TAG_APE_BINARY;
	TAG_APE_BINARY* = RECORD
		key*: PAnsiChar;
		data*: PAnsiChar;
		length*: DWORD;
	END;

	(* BWF "bext" tag structure *)
	PTAG_BEXT* = POINTER TO TAG_BEXT;
	TAG_BEXT* = (* PACKED *) RECORD
		Description*: ARRAY 256 OF AnsiChar;					(* description *)
		Originator*: ARRAY 32 OF AnsiChar;						(* name of the originator *)
		OriginatorReference*: ARRAY 32 OF AnsiChar;	(* reference of the originator *)
		OriginationDate*: ARRAY 10 OF AnsiChar;			(* date of creation (yyyy-mm-dd) *)
		OriginationTime*: ARRAY 8 OF AnsiChar;				(* time of creation (hh-mm-ss) *)
		TimeReference*: QWORD;												(* first sample count since midnight (little-endian) *)
		Version*: Word;																(* BWF version (little-endian) *)
		UMID*: ARRAY 64 OF Byte;											(* SMPTE UMID *)
		Reserved*: ARRAY 190 OF Byte;
		CodingHistory*: PAnsiChar(* ARRAY [0..maxInt DIV 2 - 1] OF AnsiChar *);					 (* history *)
	END;

	BASS_DX8_CHORUS* = RECORD
		fWetDryMix*: FLOAT32;
		fDepth*: FLOAT32;
		fFeedback*: FLOAT32;
		fFrequency*: FLOAT32;
		lWaveform*: DWORD;		(* 0=triangle, 1=sine *)
		fDelay*: FLOAT32;
		lPhase*: DWORD;			(* BASS_DX8_PHASE_xxx *)
	END;

	BASS_DX8_COMPRESSOR* = RECORD
		fGain*: FLOAT32;
		fAttack*: FLOAT32;
		fRelease*: FLOAT32;
		fThreshold*: FLOAT32;
		fRatio*: FLOAT32;
		fPredelay*: FLOAT32;
	END;

	BASS_DX8_DISTORTION* = RECORD
		fGain*: FLOAT32;
		fEdge*: FLOAT32;
		fPostEQCenterFrequency*: FLOAT32;
		fPostEQBandwidth*: FLOAT32;
		fPreLowpassCutoff*: FLOAT32;
	END;

	BASS_DX8_ECHO* = RECORD
		fWetDryMix*: FLOAT32;
		fFeedback*: FLOAT32;
		fLeftDelay*: FLOAT32;
		fRightDelay*: FLOAT32;
		lPanDelay*: BOOL;
	END;

	BASS_DX8_FLANGER* = RECORD
		fWetDryMix*: FLOAT32;
		fDepth*: FLOAT32;
		fFeedback*: FLOAT32;
		fFrequency*: FLOAT32;
		lWaveform*: DWORD;		(* 0=triangle, 1=sine *)
		fDelay*: FLOAT32;
		lPhase*: DWORD;			(* BASS_DX8_PHASE_xxx *)
	END;

	BASS_DX8_GARGLE* = RECORD
		dwRateHz*: DWORD;		(* Rate of modulation in hz *)
		dwWaveShape*: DWORD;(* 0=triangle, 1=square *)
	END;

	BASS_DX8_I3DL2REVERB* = RECORD
		lRoom*: SIGNED32;							(* [-10000, 0]				default: -1000 mB *)
		lRoomHF*: SIGNED32;						(* [-10000, 0]				default: 0 mB *)
		flRoomRolloffFactor*: FLOAT32;	(* [0.0, 10.0]				default: 0.0 *)
		flDecayTime*: FLOAT32;					(* [0.1, 20.0]				default: 1.49s *)
		flDecayHFRatio*: FLOAT32;			(* [0.1, 2.0]				default: 0.83 *)
		lReflections*: SIGNED32;			(* [-10000, 1000]		default: -2602 mB *)
		flReflectionsDelay*: FLOAT32;	(* [0.0, 0.3]				default: 0.007 s *)
		lReverb*: SIGNED32;						(* [-10000, 2000]		default: 200 mB *)
		flReverbDelay*: FLOAT32;				(* [0.0, 0.1]				default: 0.011 s *)
		flDiffusion*: FLOAT32;					(* [0.0, 100.0]			default: 100.0 % *)
		flDensity*: FLOAT32;						(* [0.0, 100.0]			default: 100.0 % *)
		flHFReference*: FLOAT32;				(* [20.0, 20000.0]		default: 5000.0 Hz *)
	END;

	BASS_DX8_PARAMEQ* = RECORD
		fCenter*: FLOAT32;
		fBandwidth*: FLOAT32;
		fGain*: FLOAT32;
	END;

	BASS_DX8_REVERB* = RECORD
		fInGain*: FLOAT32;							(* [-96.0,0.0]				default: 0.0 dB *)
		fReverbMix*: FLOAT32;						(* [-96.0,0.0]				default: 0.0 db *)
		fReverbTime*: FLOAT32;					(* [0.001,3000.0]		default: 1000.0 ms *)
		fHighFreqRTRatio*: FLOAT32;		(* [0.001,0.999]			default: 0.001 *)
	END;

	(* callback function types *)
	STREAMPROC* = PROCEDURE {PlatformCC} (handle: HSTREAM; buffer: ADDRESS; length: DWORD; user: ADDRESS): DWORD;
	(*		 User stream callback function. NOTE: A stream function should obviously be as
		quick as possible, other streams (and MOD musics) can't be mixed until
		it's finished.
		handle : The stream that needs writing
		buffer : Buffer to write the samples in
		length : Number of bytes to write
		user	 : The 'user' parameter value given when calling BASS_StreamCreate
		RETURN : Number of bytes written. Set the BASS_STREAMPROC_END flag to end
						 the stream. *)

VAR
	(* special STREAMPROCs *)
	STREAMPROC_DUMMY-:	ADDRESS;	(* ADDRESS(0)	"dummy" stream *)
	STREAMPROC_PUSH-:	ADDRESS; (* ADDRESS(-1)	push stream *)

TYPE
	DOWNLOADPROC* = PROCEDURE {PlatformCC} (buffer: ADDRESS; length: DWORD; user: ADDRESS);
	(*		 Internet stream download callback function.
		buffer : Buffer containing the downloaded data... NULL=end of download
		length : Number of bytes in the buffer
		user	 : The 'user' parameter value given when calling BASS_StreamCreateURL *)

	SYNCPROC* = PROCEDURE {PlatformCC} (handle: HSYNC; channel, data: DWORD; user: ADDRESS);
	(*		 Sync callback function. NOTE: a sync callback function should be very
		quick as other syncs cannot be processed until it has finished. If the
		sync is a "mixtime" sync, then other streams and MOD musics can not be
		mixed until it's finished either.
		handle : The sync that has occured
		channel: Channel that the sync occured in
		data	 : Additional data associated with the sync's occurance
		user	 : The 'user' parameter given when calling BASS_ChannelSetSync *)

	DSPPROC* = PROCEDURE {PlatformCC} (handle: HDSP; channel: DWORD; buffer: ADDRESS; length: DWORD; user: ADDRESS);
	(*		 DSP callback function. NOTE: A DSP function should obviously be as quick
		as possible... other DSP functions, streams and MOD musics can not be
		processed until it's finished.
		handle : The DSP handle
		channel: Channel that the DSP is being applied to
		buffer : Buffer to apply the DSP to
		length : Number of bytes in the buffer
		user	 : The 'user' parameter given when calling BASS_ChannelSetDSP *)

	RECORDPROC* = PROCEDURE {PlatformCC} (handle: HRECORD; buffer: ADDRESS; length: DWORD; user: ADDRESS): BOOL;
	(*		 Recording callback function.
		handle : The recording handle
		buffer : Buffer containing the recorded sample data
		length : Number of bytes
		user	 : The 'user' parameter value given when calling BASS_RecordStart
		RETURN : TRUE = continue recording, FALSE = stop *)

VAR

	(* Functions *)

	BASS_SetConfig-: PROCEDURE {PlatformCC} (option, value: DWORD): BOOL;
	BASS_GetConfig-: PROCEDURE {PlatformCC} (option: DWORD): DWORD;
	BASS_SetConfigPtr-: PROCEDURE {PlatformCC} (option: DWORD; value: ADDRESS): BOOL;
	BASS_GetConfigPtr-: PROCEDURE {PlatformCC} (option: DWORD): ADDRESS;

	BASS_GetVersion-: PROCEDURE {PlatformCC} (): DWORD;
	BASS_ErrorGetCode-: PROCEDURE {PlatformCC} (): SIGNED32;
	BASS_GetDeviceInfo-: PROCEDURE {PlatformCC} (device: DWORD; VAR info: BASS_DEVICEINFO): BOOL;

	BASS_Init-: PROCEDURE {PlatformCC} (device: SIGNED32; freq: DWORD; flags: SET32; win: ADDRESS; clsid: ADDRESS): BOOL;

	BASS_SetDevice-: PROCEDURE {PlatformCC} (device: DWORD): BOOL;
	BASS_GetDevice-: PROCEDURE {PlatformCC} (): DWORD;
	BASS_Free-: PROCEDURE {PlatformCC} (): BOOL;

	#IF WIN THEN
		BASS_GetDSoundObject-: PROCEDURE {PlatformCC} (obj: DWORD): ADDRESS;
	#END

	BASS_GetInfo-: PROCEDURE {PlatformCC} (VAR info: BASS_INFO): BOOL;
	BASS_Update-: PROCEDURE {PlatformCC} (length: DWORD): BOOL;
	BASS_GetCPU-: PROCEDURE {PlatformCC} (): FLOAT32;
	BASS_Start-: PROCEDURE {PlatformCC} (): BOOL;
	BASS_Stop-: PROCEDURE {PlatformCC} (): BOOL;
	BASS_Pause-: PROCEDURE {PlatformCC} (): BOOL;
	BASS_SetVolume-: PROCEDURE {PlatformCC} (volume: FLOAT32): BOOL;
	BASS_GetVolume-: PROCEDURE {PlatformCC} (): FLOAT32;

	BASS_PluginLoad-: PROCEDURE {PlatformCC} (filename: PChar; flags: SET32): HPLUGIN;
	BASS_PluginFree-: PROCEDURE {PlatformCC} (handle: HPLUGIN): BOOL;
	BASS_PluginGetInfo-: PROCEDURE {PlatformCC} (handle: HPLUGIN): PBASS_PLUGININFO;

	BASS_Set3DFactors-: PROCEDURE {PlatformCC} (distf, rollf, doppf: FLOAT32): BOOL;
	BASS_Get3DFactors-: PROCEDURE {PlatformCC} (VAR distf, rollf, doppf: FLOAT32): BOOL;
	BASS_Set3DPosition-: PROCEDURE {PlatformCC} (VAR pos, vel, front, top: BASS_3DVECTOR): BOOL;
	BASS_Get3DPosition-: PROCEDURE {PlatformCC} (VAR pos, vel, front, top: BASS_3DVECTOR): BOOL;
	BASS_Apply3D-: PROCEDURE {PlatformCC};

	#IF WIN THEN
		BASS_SetEAXParameters-: PROCEDURE {PlatformCC} (env: SIGNED32; vol, decay, damp: FLOAT32): BOOL;
		BASS_GetEAXParameters-: PROCEDURE {PlatformCC} (VAR env: DWORD; VAR vol, decay, damp: FLOAT32): BOOL;
	#END

	BASS_MusicLoad-: PROCEDURE {PlatformCC} (mem: BOOL; f: ADDRESS; offset: QWORD; length: DWORD; flags: SET32; freq: DWORD): HMUSIC;
	BASS_MusicFree-: PROCEDURE {PlatformCC} (handle: HMUSIC): BOOL;

	BASS_SampleLoad-: PROCEDURE {PlatformCC} (mem: BOOL; f: ADDRESS; offset: QWORD; length, max: DWORD; flags: SET32): HSAMPLE;
	BASS_SampleCreate-: PROCEDURE {PlatformCC} (length, freq, chans, max: DWORD; flags: SET32): HSAMPLE;
	BASS_SampleFree-: PROCEDURE {PlatformCC} (handle: HSAMPLE): BOOL;
	BASS_SampleSetData-: PROCEDURE {PlatformCC} (handle: HSAMPLE; buffer: ADDRESS): BOOL;
	BASS_SampleGetData-: PROCEDURE {PlatformCC} (handle: HSAMPLE; buffer: ADDRESS): BOOL;
	BASS_SampleGetInfo-: PROCEDURE {PlatformCC} (handle: HSAMPLE; VAR info: BASS_SAMPLE): BOOL;
	BASS_SampleSetInfo-: PROCEDURE {PlatformCC} (handle: HSAMPLE; VAR info: BASS_SAMPLE): BOOL;
	BASS_SampleGetChannel-: PROCEDURE {PlatformCC} (handle: HSAMPLE; onlynew: BOOL): HCHANNEL;
	BASS_SampleGetChannels-: PROCEDURE {PlatformCC} (handle: HSAMPLE; channels: ADDRESS): DWORD;
	BASS_SampleStop-: PROCEDURE {PlatformCC} (handle: HSAMPLE): BOOL;

	BASS_StreamCreate-: PROCEDURE {PlatformCC} (freq, chans: DWORD; flags: SET32; proc: ADDRESS(*STREAMPROC*); user: ADDRESS): HSTREAM;
	BASS_StreamCreateFile-: PROCEDURE {PlatformCC} (mem: BOOL; f: ADDRESS; offset, length: QWORD; flags: SET32): HSTREAM;
	BASS_StreamCreateURL-: PROCEDURE {PlatformCC} (url: PChar; offset: DWORD; flags: SET32; proc: DOWNLOADPROC; user: ADDRESS):HSTREAM;
	BASS_StreamCreateFileUser-: PROCEDURE {PlatformCC} (system, flags: SET32; VAR procs: BASS_FILEPROCS; user: ADDRESS): HSTREAM;
	BASS_StreamFree-: PROCEDURE {PlatformCC} (handle: HSTREAM): BOOL;
	BASS_StreamGetFilePosition-: PROCEDURE {PlatformCC} (handle: HSTREAM; mode: DWORD): QWORD;
	BASS_StreamPutData-: PROCEDURE {PlatformCC} (handle: HSTREAM; buffer: ADDRESS; length: DWORD): DWORD;
	BASS_StreamPutFileData-: PROCEDURE {PlatformCC} (handle: HSTREAM; buffer: ADDRESS; length: DWORD): DWORD;

	BASS_RecordGetDeviceInfo-: PROCEDURE {PlatformCC} (device: DWORD; VAR info: BASS_DEVICEINFO): BOOL;
	BASS_RecordInit-: PROCEDURE {PlatformCC} (device: SIGNED32):BOOL;
	BASS_RecordSetDevice-: PROCEDURE {PlatformCC} (device: DWORD): BOOL;
	BASS_RecordGetDevice-: PROCEDURE {PlatformCC} (): DWORD;
	BASS_RecordFree-: PROCEDURE {PlatformCC} (): BOOL;
	BASS_RecordGetInfo-: PROCEDURE {PlatformCC} (VAR info: BASS_RECORDINFO): BOOL;
	BASS_RecordGetInputName-: PROCEDURE {PlatformCC} (input: SIGNED32): PAnsiChar;
	BASS_RecordSetInput-: PROCEDURE {PlatformCC} (input: SIGNED32; flags: SET32; volume: FLOAT32): BOOL;
	BASS_RecordGetInput-: PROCEDURE {PlatformCC} (input: SIGNED32; VAR volume: FLOAT32): DWORD;
	BASS_RecordStart-: PROCEDURE {PlatformCC} (freq, chans: DWORD; flags: SET32; proc: RECORDPROC; user: ADDRESS): HRECORD;

	BASS_ChannelBytes2Seconds-: PROCEDURE {PlatformCC} (handle: DWORD; pos: QWORD): FLOAT64;
	BASS_ChannelSeconds2Bytes-: PROCEDURE {PlatformCC} (handle: DWORD; pos: FLOAT64): QWORD;
	BASS_ChannelGetDevice-: PROCEDURE {PlatformCC} (handle: DWORD): DWORD;
	BASS_ChannelSetDevice-: PROCEDURE {PlatformCC} (handle, device: DWORD): BOOL;
	BASS_ChannelIsActive-: PROCEDURE {PlatformCC} (handle: DWORD): DWORD;
	BASS_ChannelGetInfo-: PROCEDURE {PlatformCC} (handle: DWORD; VAR info: BASS_CHANNELINFO):BOOL;
	BASS_ChannelGetTags-: PROCEDURE {PlatformCC} (handle: HSTREAM; tags: DWORD): PAnsiChar;
	BASS_ChannelFlags-: PROCEDURE {PlatformCC} (handle: DWORD; flags: SET32; mask: DWORD): DWORD;
	BASS_ChannelUpdate-: PROCEDURE {PlatformCC} (handle, length: DWORD): BOOL;
	BASS_ChannelLock-: PROCEDURE {PlatformCC} (handle: DWORD; lock: BOOL): BOOL;
	BASS_ChannelPlay-: PROCEDURE {PlatformCC} (handle: DWORD; restart: BOOL): BOOL;
	BASS_ChannelStop-: PROCEDURE {PlatformCC} (handle: DWORD): BOOL;
	BASS_ChannelPause-: PROCEDURE {PlatformCC} (handle: DWORD): BOOL;

	BASS_ChannelSetAttribute-: PROCEDURE {PlatformCC} (handle, attrib: DWORD; value: FLOAT32): BOOL;
	BASS_ChannelGetAttribute-: PROCEDURE {PlatformCC} (handle, attrib: DWORD; VAR value: FLOAT32): BOOL;
	BASS_ChannelSlideAttribute-: PROCEDURE {PlatformCC} (handle, attrib: DWORD; value: FLOAT32; time: DWORD): BOOL;
	BASS_ChannelIsSliding-: PROCEDURE {PlatformCC} (handle, attrib: DWORD): BOOL;
	BASS_ChannelSetAttributeEx-: PROCEDURE {PlatformCC} (handle, attrib: DWORD; value: ADDRESS; size: DWORD): BOOL;
	BASS_ChannelGetAttributeEx-: PROCEDURE {PlatformCC} (handle, attrib: DWORD; value: ADDRESS; size: DWORD): DWORD;
	BASS_ChannelSet3DAttributes-: PROCEDURE {PlatformCC} (handle: DWORD; mode: SIGNED32; min, max: FLOAT32; iangle, oangle, outvol: SIGNED32): BOOL;
	BASS_ChannelGet3DAttributes-: PROCEDURE {PlatformCC} (handle: DWORD; VAR mode: DWORD; VAR min, max: FLOAT32; VAR iangle, oangle, outvol: DWORD): BOOL;
	BASS_ChannelSet3DPosition-: PROCEDURE {PlatformCC} (handle: DWORD; VAR pos, orient, vel: BASS_3DVECTOR): BOOL;
	BASS_ChannelGet3DPosition-: PROCEDURE {PlatformCC} (handle: DWORD; VAR pos, orient, vel: BASS_3DVECTOR): BOOL;
	BASS_ChannelGetLength-: PROCEDURE {PlatformCC} (handle, mode: DWORD): QWORD;
	BASS_ChannelSetPosition-: PROCEDURE {PlatformCC} (handle: DWORD; pos: QWORD; mode: DWORD): BOOL;
	BASS_ChannelGetPosition-: PROCEDURE {PlatformCC} (handle, mode: DWORD): QWORD;
	BASS_ChannelGetLevel-: PROCEDURE {PlatformCC} (handle: DWORD): DWORD;
	BASS_ChannelGetLevelEx-: PROCEDURE {PlatformCC} (handle: DWORD; levels: PSingle; length: FLOAT32; flags: SET32): BOOL;
	BASS_ChannelGetData-: PROCEDURE {PlatformCC} (handle: DWORD; buffer: ADDRESS; length: DWORD): DWORD;
	BASS_ChannelSetSync-: PROCEDURE {PlatformCC} (handle: DWORD; type: SET32; param: QWORD; proc: SYNCPROC; user: ADDRESS): HSYNC;
	BASS_ChannelRemoveSync-: PROCEDURE {PlatformCC} (handle: DWORD; sync: HSYNC): BOOL;
	BASS_ChannelSetDSP-: PROCEDURE {PlatformCC} (handle: DWORD; proc: DSPPROC; user: ADDRESS; priority: SIGNED32): HDSP;

	BASS_ChannelRemoveDSP-: PROCEDURE {PlatformCC} (handle: DWORD; dsp: HDSP): BOOL;
	BASS_ChannelSetLink-: PROCEDURE {PlatformCC} (handle, chan: DWORD): BOOL;
	BASS_ChannelRemoveLink-: PROCEDURE {PlatformCC} (handle, chan: DWORD): BOOL;
	BASS_ChannelSetFX-: PROCEDURE {PlatformCC} (handle, type_: DWORD; priority: SIGNED32): HFX;
	BASS_ChannelRemoveFX-: PROCEDURE {PlatformCC} (handle: DWORD; fx: HFX): BOOL;
	BASS_FXSetParameters-: PROCEDURE {PlatformCC} (handle: HFX; par: ADDRESS): BOOL;
	BASS_FXGetParameters-: PROCEDURE {PlatformCC} (handle: HFX; par: ADDRESS): BOOL;
	BASS_FXReset-: PROCEDURE {PlatformCC} (handle: HFX): BOOL;
	BASS_FXSetPriority-: PROCEDURE {PlatformCC} (handle: HFX; priority: SIGNED32): BOOL;

	PROCEDURE GetProcAddress*(lib: HostLibs.LibHandle; CONST procName: ARRAY OF CHAR; adr: ADDRESS);
	BEGIN
		(* On Mac OSX, cdecl names have a preceeding underscore if x86 native backend. *)

		#IF DARWIN & I386 THEN
			IGNORE HostLibs.GetProcedure(lib, Strings.ConcatToNew('_', procName)^, adr);
		#ELSE
			IGNORE HostLibs.GetProcedure(lib, procName, adr);
		#END

	END GetProcAddress;

	PROCEDURE BASS_SPEAKER_N*(n: DWORD): DWORD;
	BEGIN
		RETURN (*n shl 24*)ASH(n, 24);
	END BASS_SPEAKER_N;

	PROCEDURE BASS_SetEAXPreset*(env: SIGNED32): BOOL;
	BEGIN
		#IF WIN THEN
			CASE env OF
				EAX_ENVIRONMENT_GENERIC:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_GENERIC, 0.5, 1.493, 0.5);
			|	EAX_ENVIRONMENT_PADDEDCELL:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_PADDEDCELL, 0.25, 0.1, 0);
			|	EAX_ENVIRONMENT_ROOM:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_ROOM, 0.417, 0.4, 0.666);
			|	EAX_ENVIRONMENT_BATHROOM:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_BATHROOM, 0.653, 1.499, 0.166);
			|	EAX_ENVIRONMENT_LIVINGROOM:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_LIVINGROOM, 0.208, 0.478, 0);
			|	EAX_ENVIRONMENT_STONEROOM:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_STONEROOM, 0.5, 2.309, 0.888);
			|	EAX_ENVIRONMENT_AUDITORIUM:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_AUDITORIUM, 0.403, 4.279, 0.5);
			|	EAX_ENVIRONMENT_CONCERTHALL:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_CONCERTHALL, 0.5, 3.961, 0.5);
			|	EAX_ENVIRONMENT_CAVE:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_CAVE, 0.5, 2.886, 1.304);
			|	EAX_ENVIRONMENT_ARENA:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_ARENA, 0.361, 7.284, 0.332);
			|	EAX_ENVIRONMENT_HANGAR:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_HANGAR, 0.5, 10.0, 0.3);
			|	EAX_ENVIRONMENT_CARPETEDHALLWAY:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_CARPETEDHALLWAY, 0.153, 0.259, 2.0);
			|	EAX_ENVIRONMENT_HALLWAY:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_HALLWAY, 0.361, 1.493, 0);
			|	EAX_ENVIRONMENT_STONECORRIDOR:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_STONECORRIDOR, 0.444, 2.697, 0.638);
			|	EAX_ENVIRONMENT_ALLEY:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_ALLEY, 0.25, 1.752, 0.776);
			|	EAX_ENVIRONMENT_FOREST:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_FOREST, 0.111, 3.145, 0.472);
			|	EAX_ENVIRONMENT_CITY:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_CITY, 0.111, 2.767, 0.224);
			|	EAX_ENVIRONMENT_MOUNTAINS:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_MOUNTAINS, 0.194, 7.841, 0.472);
			|	EAX_ENVIRONMENT_QUARRY:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_QUARRY, 1, 1.499, 0.5);
			|	EAX_ENVIRONMENT_PLAIN:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_PLAIN, 0.097, 2.767, 0.224);
			|	EAX_ENVIRONMENT_PARKINGLOT:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_PARKINGLOT, 0.208, 1.652, 1.5);
			|	EAX_ENVIRONMENT_SEWERPIPE:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_SEWERPIPE, 0.652, 2.886, 0.25);
			|	EAX_ENVIRONMENT_UNDERWATER:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_UNDERWATER, 1, 1.499, 0);
			|	EAX_ENVIRONMENT_DRUGGED:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_DRUGGED, 0.875, 8.392, 1.388);
			|	EAX_ENVIRONMENT_DIZZY:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_DIZZY, 0.139, 17.234, 0.666);
			|	EAX_ENVIRONMENT_PSYCHOTIC:
					RETURN BASS_SetEAXParameters(EAX_ENVIRONMENT_PSYCHOTIC, 0.486, 7.563, 0.806);
			ELSE
				RETURN 0
			END
		#ELSE
			RETURN 0
		#END
	END BASS_SetEAXPreset;

	#IF WIN THEN
	#ELSE
		PROCEDURE BASS_GetDSoundObject*(obj: DWORD): ADDRESS;
		BEGIN
			RETURN NIL
		END BASS_GetDSoundObject;

		PROCEDURE BASS_SetEAXParameters*(env: SIGNED32; vol, decay, damp: REAL): BOOL;
		BEGIN
			RETURN 0
		END BASS_SetEAXParameters;

		PROCEDURE BASS_GetEAXParameters*(VAR env: DWORD; VAR vol, decay, damp: REAL): BOOL;
		BEGIN
			RETURN 0
		END BASS_GetEAXParameters;
	#END

	PROCEDURE Cleanup;
	VAR res: BOOLEAN;
	BEGIN
		res := HostLibs.FreeLibrary(oalib);
		IF res THEN
			KernelLog.String(libname); KernelLog.String(' unloaded.'); KernelLog.Ln;
		END;
	END Cleanup;

	PROCEDURE LoadFunctions;
	VAR res: BOOLEAN;
	BEGIN
		res := HostLibs.LoadLibrary(libname, oalib);
		ASSERT(oalib # NIL, 103);

		GetProcAddress( oalib, "BASS_SetConfig", ADDRESSOF( BASS_SetConfig));
		GetProcAddress( oalib, "BASS_GetConfig", ADDRESSOF( BASS_GetConfig));
		GetProcAddress( oalib, "BASS_SetConfigPtr", ADDRESSOF( BASS_SetConfigPtr));
		GetProcAddress( oalib, "BASS_GetConfigPtr", ADDRESSOF( BASS_GetConfigPtr));
		GetProcAddress( oalib, "BASS_GetVersion", ADDRESSOF( BASS_GetVersion));
		GetProcAddress( oalib, "BASS_ErrorGetCode", ADDRESSOF( BASS_ErrorGetCode));
		GetProcAddress( oalib, "BASS_GetDeviceInfo", ADDRESSOF( BASS_GetDeviceInfo));

		GetProcAddress( oalib, "BASS_Init", ADDRESSOF( BASS_Init));

		GetProcAddress( oalib, "BASS_SetDevice", ADDRESSOF( BASS_SetDevice));
		GetProcAddress( oalib, "BASS_GetDevice", ADDRESSOF( BASS_GetDevice));
		GetProcAddress( oalib, "BASS_Free", ADDRESSOF( BASS_Free));

		#IF WIN THEN
			GetProcAddress( oalib, "BASS_GetDSoundObject", ADDRESSOF( BASS_GetDSoundObject));
		#END

		GetProcAddress( oalib, "BASS_GetInfo", ADDRESSOF( BASS_GetInfo));
		GetProcAddress( oalib, "BASS_Update", ADDRESSOF( BASS_Update));
		GetProcAddress( oalib, "BASS_GetCPU", ADDRESSOF( BASS_GetCPU));
		GetProcAddress( oalib, "BASS_Start", ADDRESSOF( BASS_Start));
		GetProcAddress( oalib, "BASS_Stop", ADDRESSOF( BASS_Stop));
		GetProcAddress( oalib, "BASS_Pause", ADDRESSOF( BASS_Pause));
		GetProcAddress( oalib, "BASS_SetVolume", ADDRESSOF( BASS_SetVolume));
		GetProcAddress( oalib, "BASS_GetVolume", ADDRESSOF( BASS_GetVolume));
		GetProcAddress( oalib, "BASS_PluginLoad", ADDRESSOF( BASS_PluginLoad));
		GetProcAddress( oalib, "BASS_PluginFree", ADDRESSOF( BASS_PluginFree));
		GetProcAddress( oalib, "BASS_PluginGetInfo", ADDRESSOF( BASS_PluginGetInfo));
		GetProcAddress( oalib, "BASS_Set3DFactors", ADDRESSOF( BASS_Set3DFactors));
		GetProcAddress( oalib, "BASS_Get3DFactors", ADDRESSOF( BASS_Get3DFactors));
		GetProcAddress( oalib, "BASS_Set3DPosition", ADDRESSOF( BASS_Set3DPosition));
		GetProcAddress( oalib, "BASS_Get3DPosition", ADDRESSOF( BASS_Get3DPosition));
		GetProcAddress( oalib, "BASS_Apply3D", ADDRESSOF( BASS_Apply3D));

		#IF WIN THEN
			GetProcAddress( oalib, "BASS_SetEAXParameters", ADDRESSOF( BASS_SetEAXParameters));
			GetProcAddress( oalib, "BASS_GetEAXParameters", ADDRESSOF( BASS_GetEAXParameters));
		#END

		GetProcAddress( oalib, "BASS_MusicLoad", ADDRESSOF( BASS_MusicLoad));
		GetProcAddress( oalib, "BASS_MusicFree", ADDRESSOF( BASS_MusicFree));
		GetProcAddress( oalib, "BASS_SampleLoad", ADDRESSOF( BASS_SampleLoad));
		GetProcAddress( oalib, "BASS_SampleCreate", ADDRESSOF( BASS_SampleCreate));
		GetProcAddress( oalib, "BASS_SampleFree", ADDRESSOF( BASS_SampleFree));
		GetProcAddress( oalib, "BASS_SampleSetData", ADDRESSOF( BASS_SampleSetData));
		GetProcAddress( oalib, "BASS_SampleGetData", ADDRESSOF( BASS_SampleGetData));
		GetProcAddress( oalib, "BASS_SampleGetInfo", ADDRESSOF( BASS_SampleGetInfo));
		GetProcAddress( oalib, "BASS_SampleSetInfo", ADDRESSOF( BASS_SampleSetInfo));
		GetProcAddress( oalib, "BASS_SampleGetChannel", ADDRESSOF( BASS_SampleGetChannel));
		GetProcAddress( oalib, "BASS_SampleGetChannels", ADDRESSOF( BASS_SampleGetChannels));
		GetProcAddress( oalib, "BASS_SampleStop", ADDRESSOF( BASS_SampleStop));
		GetProcAddress( oalib, "BASS_StreamCreate", ADDRESSOF( BASS_StreamCreate));
		GetProcAddress( oalib, "BASS_StreamCreateFile", ADDRESSOF( BASS_StreamCreateFile));
		GetProcAddress( oalib, "BASS_StreamCreateURL", ADDRESSOF( BASS_StreamCreateURL));
		GetProcAddress( oalib, "BASS_StreamCreateFileUser", ADDRESSOF( BASS_StreamCreateFileUser));
		GetProcAddress( oalib, "BASS_StreamFree", ADDRESSOF( BASS_StreamFree));
		GetProcAddress( oalib, "BASS_StreamGetFilePosition", ADDRESSOF( BASS_StreamGetFilePosition));
		GetProcAddress( oalib, "BASS_StreamPutData", ADDRESSOF( BASS_StreamPutData));
		GetProcAddress( oalib, "BASS_StreamPutFileData", ADDRESSOF( BASS_StreamPutFileData));
		GetProcAddress( oalib, "BASS_RecordGetDeviceInfo", ADDRESSOF( BASS_RecordGetDeviceInfo));
		GetProcAddress( oalib, "BASS_RecordInit", ADDRESSOF( BASS_RecordInit));
		GetProcAddress( oalib, "BASS_RecordSetDevice", ADDRESSOF( BASS_RecordSetDevice));
		GetProcAddress( oalib, "BASS_RecordGetDevice", ADDRESSOF( BASS_RecordGetDevice));
		GetProcAddress( oalib, "BASS_RecordFree", ADDRESSOF( BASS_RecordFree));
		GetProcAddress( oalib, "BASS_RecordGetInfo", ADDRESSOF( BASS_RecordGetInfo));
		GetProcAddress( oalib, "BASS_RecordGetInputName", ADDRESSOF( BASS_RecordGetInputName));
		GetProcAddress( oalib, "BASS_RecordSetInput", ADDRESSOF( BASS_RecordSetInput));
		GetProcAddress( oalib, "BASS_RecordGetInput", ADDRESSOF( BASS_RecordGetInput));
		GetProcAddress( oalib, "BASS_RecordStart", ADDRESSOF( BASS_RecordStart));
		GetProcAddress( oalib, "BASS_ChannelBytes2Seconds", ADDRESSOF( BASS_ChannelBytes2Seconds));
		GetProcAddress( oalib, "BASS_ChannelSeconds2Bytes", ADDRESSOF( BASS_ChannelSeconds2Bytes));
		GetProcAddress( oalib, "BASS_ChannelGetDevice", ADDRESSOF( BASS_ChannelGetDevice));
		GetProcAddress( oalib, "BASS_ChannelSetDevice", ADDRESSOF( BASS_ChannelSetDevice));
		GetProcAddress( oalib, "BASS_ChannelIsActive", ADDRESSOF( BASS_ChannelIsActive));
		GetProcAddress( oalib, "BASS_ChannelGetInfo", ADDRESSOF( BASS_ChannelGetInfo));
		GetProcAddress( oalib, "BASS_ChannelGetTags", ADDRESSOF( BASS_ChannelGetTags));
		GetProcAddress( oalib, "BASS_ChannelFlags", ADDRESSOF( BASS_ChannelFlags));
		GetProcAddress( oalib, "BASS_ChannelUpdate", ADDRESSOF( BASS_ChannelUpdate));
		GetProcAddress( oalib, "BASS_ChannelLock", ADDRESSOF( BASS_ChannelLock));
		GetProcAddress( oalib, "BASS_ChannelPlay", ADDRESSOF( BASS_ChannelPlay));
		GetProcAddress( oalib, "BASS_ChannelStop", ADDRESSOF( BASS_ChannelStop));
		GetProcAddress( oalib, "BASS_ChannelPause", ADDRESSOF( BASS_ChannelPause));
		GetProcAddress( oalib, "BASS_ChannelSetAttribute", ADDRESSOF( BASS_ChannelSetAttribute));
		GetProcAddress( oalib, "BASS_ChannelGetAttribute", ADDRESSOF( BASS_ChannelGetAttribute));
		GetProcAddress( oalib, "BASS_ChannelSlideAttribute", ADDRESSOF( BASS_ChannelSlideAttribute));
		GetProcAddress( oalib, "BASS_ChannelIsSliding", ADDRESSOF( BASS_ChannelIsSliding));
		GetProcAddress( oalib, "BASS_ChannelSetAttributeEx", ADDRESSOF( BASS_ChannelSetAttributeEx));
		GetProcAddress( oalib, "BASS_ChannelGetAttributeEx", ADDRESSOF( BASS_ChannelGetAttributeEx));
		GetProcAddress( oalib, "BASS_ChannelSet3DAttributes", ADDRESSOF( BASS_ChannelSet3DAttributes));
		GetProcAddress( oalib, "BASS_ChannelGet3DAttributes", ADDRESSOF( BASS_ChannelGet3DAttributes));
		GetProcAddress( oalib, "BASS_ChannelSet3DPosition", ADDRESSOF( BASS_ChannelSet3DPosition));
		GetProcAddress( oalib, "BASS_ChannelGet3DPosition", ADDRESSOF( BASS_ChannelGet3DPosition));
		GetProcAddress( oalib, "BASS_ChannelGetLength", ADDRESSOF( BASS_ChannelGetLength));
		GetProcAddress( oalib, "BASS_ChannelSetPosition", ADDRESSOF( BASS_ChannelSetPosition));
		GetProcAddress( oalib, "BASS_ChannelGetPosition", ADDRESSOF( BASS_ChannelGetPosition));
		GetProcAddress( oalib, "BASS_ChannelGetLevel", ADDRESSOF( BASS_ChannelGetLevel));
		GetProcAddress( oalib, "BASS_ChannelGetLevelEx", ADDRESSOF( BASS_ChannelGetLevelEx));
		GetProcAddress( oalib, "BASS_ChannelGetData", ADDRESSOF( BASS_ChannelGetData));
		GetProcAddress( oalib, "BASS_ChannelSetSync", ADDRESSOF( BASS_ChannelSetSync));
		GetProcAddress( oalib, "BASS_ChannelRemoveSync", ADDRESSOF( BASS_ChannelRemoveSync));
		GetProcAddress( oalib, "BASS_ChannelSetDSP", ADDRESSOF( BASS_ChannelSetDSP));
		GetProcAddress( oalib, "BASS_ChannelRemoveDSP", ADDRESSOF( BASS_ChannelRemoveDSP));
		GetProcAddress( oalib, "BASS_ChannelSetLink", ADDRESSOF( BASS_ChannelSetLink));
		GetProcAddress( oalib, "BASS_ChannelRemoveLink", ADDRESSOF( BASS_ChannelRemoveLink));
		GetProcAddress( oalib, "BASS_ChannelSetFX", ADDRESSOF( BASS_ChannelSetFX));
		GetProcAddress( oalib, "BASS_ChannelRemoveFX", ADDRESSOF( BASS_ChannelRemoveFX));
		GetProcAddress( oalib, "BASS_FXSetParameters", ADDRESSOF( BASS_FXSetParameters));
		GetProcAddress( oalib, "BASS_FXGetParameters", ADDRESSOF( BASS_FXGetParameters));
		GetProcAddress( oalib, "BASS_FXReset", ADDRESSOF( BASS_FXReset));
		GetProcAddress( oalib, "BASS_FXSetPriority", ADDRESSOF( BASS_FXSetPriority));

	END LoadFunctions;

BEGIN
	STREAMPROC_DUMMY	:= SYSTEM.VAL(ADDRESS, 0);	(* ADDRESS(0)	"dummy" stream *)
	STREAMPROC_PUSH	:= SYSTEM.VAL(ADDRESS, -1); (* ADDRESS(-1)	push stream *)
	LoadFunctions;
	Modules.InstallTermHandler(Cleanup)
END BASS.

