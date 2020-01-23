MODULE BASS; (** AUTHOR "SAGE"; PURPOSE "BASS 2.4 A2 OS Wrapper module"; *)

IMPORT
	SYSTEM, KernelLog, Kernel32, Modules, Codecs, Streams;

CONST

	(* API version *)
	BASSVERSION*										= 204H;
	BASSVERSIONTEXT*								= "2.4";

	(* Use these to test for error from functions that return a DWORD or QWORD *)
	DW_ERROR*												= LONGINT(-1);
	QW_ERROR*												= HUGEINT(-1);

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
	BASS_ERROR_DECODE*							= 38;	 (* the channel is/isn't a "decoding channel" *)
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

	DWORD = LONGINT;
	BOOL* = LONGINT;
	QWORD = HUGEINT;
	Byte = CHAR;
	AnsiChar = CHAR;
	Word = INTEGER;
	PAnsiChar = ADDRESS;
	PChar = ADDRESS;
	PGUID = ADDRESS;
	PSingle = ADDRESS;
	HWND = LONGINT;
	HMUSIC = LONGINT;		(* MOD music handle *)
	HSAMPLE = LONGINT;		(* sample handle *)
	HCHANNEL = LONGINT;	(* playing sample's channel handle *)
	HSTREAM = LONGINT;		(* sample stream handle *)
	HRECORD = LONGINT;		(* recording handle *)
	HSYNC = LONGINT;			(* synchronizer handle *)
	HDSP = LONGINT;			(* DSP handle *)
	HFX = LONGINT;				(* DX8 effect handle *)
	HPLUGIN = LONGINT;		(* Plugin handle *)

	(* Channel info structure *)
	BASS_CHANNELINFO* = RECORD
		freq*: DWORD;					(* default playback rate *)
		chans*: DWORD;					(* channels *)
		flags*: SET;						(* BASS_SAMPLE/STREAM/MUSIC/SPEAKER flags *)
		ctype*: SET;						(* type of channel *)
		origres*: DWORD;				(* original resolution *)
		plugin*: HPLUGIN;			(* plugin *)
		sample*: HSAMPLE;			(* sample *)
#IF I386 THEN
#ELSIF AMD64 THEN
		padding*: DWORD;
#ELSE
		unimplemented
#END
		filename*: PAnsiChar;	(* filename *)
	END;

	BASS_PLUGINFORM* = RECORD
		ctype*: DWORD;				(* channel type *)
#IF I386 THEN
#ELSIF AMD64 THEN
		padding*: DWORD;
#ELSE
		unimplemented
#END
		name*: PAnsiChar;		(* format description *)
		exts*: PAnsiChar;		(* file extension filter ( *.ext1;*.ext2;etc...) *)
	END;

	(* Device info structure *)
	BASS_DEVICEINFO* = RECORD
		name*: PAnsiChar;		(* description *)
		driver*: PAnsiChar;	(* driver *)
		flags*: SET;
	END;

	BASS_INFO* = RECORD
		flags*: SET;				(* device capabilities (DSCAPS_xxx flags) *)
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
		initflags*: SET;		(*	 BASS_Init "flags" parameter *)
		speakers*: DWORD;	(* number of speakers available *)
		freq*: DWORD;			(* current output rate *)
	END;

	(* Recording device info structure *)
	BASS_RECORDINFO* = RECORD
		flags*: SET;				(* device capabilities (DSCCAPS_xxx flags) *)
		formats*: SET;			(* supported standard formats (WAVE_FORMAT_xxx flags) *)
		inputs*: DWORD;		(* number of inputs *)
		singlein*: BOOL;		(* only 1 input can be set at a time *)
		freq*: DWORD;			(* current input rate *)
	END;

	(* Sample info structure *)
	BASS_SAMPLE* = RECORD
		freq*: DWORD;			(* default playback rate *)
		volume*: REAL;			(* default volume (0-100) *)
		pan*: REAL;				(* default pan (-100=left, 0=middle, 100=right) *)
		flags*: SET;				(* BASS_SAMPLE_xxx flags *)
		length*: DWORD;		(* length (in samples, not bytes) *)
		max*: DWORD;				(* maximum simultaneous playbacks *)
		origres*: DWORD;		(* original resolution *)
		chans*: DWORD;			(* number of channels *)
		mingap*: DWORD;		(* minimum gap (ms) between creating channels *)
		mode3d*: DWORD;		(* BASS_3DMODE_xxx mode *)
		mindist*: REAL;		(* minimum distance *)
		maxdist*: REAL;		(* maximum distance *)
		iangle*: DWORD;		(* angle of inside projection cone *)
		oangle*: DWORD;		(* angle of outside projection cone *)
		outvol*: REAL;			(* delta-volume outside the projection cone *)
		vam*: SET;					(* voice allocation/management flags (BASS_VAM_xxx) *)
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
		x*: REAL;					(* +=right, -=left *)
		y*: REAL;					(* +=up, -=down *)
		z*: REAL;					(* +=front, -=behind *)
	END;

	(* User file stream callback functions *)
	FILECLOSEPROC* = PROCEDURE {WINAPI} (user: ADDRESS);
	FILELENPROC* = PROCEDURE {WINAPI} (user: ADDRESS): QWORD;
	FILEREADPROC* = PROCEDURE {WINAPI} (buffer: ADDRESS; length: DWORD; user: ADDRESS): DWORD;
	FILESEEKPROC* = PROCEDURE {WINAPI} (offset: QWORD; user: ADDRESS): BOOL;

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
		fWetDryMix*: REAL;
		fDepth*: REAL;
		fFeedback*: REAL;
		fFrequency*: REAL;
		lWaveform*: DWORD;		(* 0=triangle, 1=sine *)
		fDelay*: REAL;
		lPhase*: DWORD;			(* BASS_DX8_PHASE_xxx *)
	END;

	BASS_DX8_COMPRESSOR* = RECORD
		fGain*: REAL;
		fAttack*: REAL;
		fRelease*: REAL;
		fThreshold*: REAL;
		fRatio*: REAL;
		fPredelay*: REAL;
	END;

	BASS_DX8_DISTORTION* = RECORD
		fGain*: REAL;
		fEdge*: REAL;
		fPostEQCenterFrequency*: REAL;
		fPostEQBandwidth*: REAL;
		fPreLowpassCutoff*: REAL;
	END;

	BASS_DX8_ECHO* = RECORD
		fWetDryMix*: REAL;
		fFeedback*: REAL;
		fLeftDelay*: REAL;
		fRightDelay*: REAL;
		lPanDelay*: BOOL;
	END;

	BASS_DX8_FLANGER* = RECORD
		fWetDryMix*: REAL;
		fDepth*: REAL;
		fFeedback*: REAL;
		fFrequency*: REAL;
		lWaveform*: DWORD;		(* 0=triangle, 1=sine *)
		fDelay*: REAL;
		lPhase*: DWORD;			(* BASS_DX8_PHASE_xxx *)
	END;

	BASS_DX8_GARGLE* = RECORD
		dwRateHz*: DWORD;		(* Rate of modulation in hz *)
		dwWaveShape*: DWORD;(* 0=triangle, 1=square *)
	END;

	BASS_DX8_I3DL2REVERB* = RECORD
		lRoom*: LONGINT;							(* [-10000, 0]				default: -1000 mB *)
		lRoomHF*: LONGINT;						(* [-10000, 0]				default: 0 mB *)
		flRoomRolloffFactor*: REAL;	(* [0.0, 10.0]				default: 0.0 *)
		flDecayTime*: REAL;					(* [0.1, 20.0]				default: 1.49s *)
		flDecayHFRatio*: REAL;			(* [0.1, 2.0]				default: 0.83 *)
		lReflections*: LONGINT;			(* [-10000, 1000]		default: -2602 mB *)
		flReflectionsDelay*: REAL;	(* [0.0, 0.3]				default: 0.007 s *)
		lReverb*: LONGINT;						(* [-10000, 2000]		default: 200 mB *)
		flReverbDelay*: REAL;				(* [0.0, 0.1]				default: 0.011 s *)
		flDiffusion*: REAL;					(* [0.0, 100.0]			default: 100.0 % *)
		flDensity*: REAL;						(* [0.0, 100.0]			default: 100.0 % *)
		flHFReference*: REAL;				(* [20.0, 20000.0]		default: 5000.0 Hz *)
	END;

	BASS_DX8_PARAMEQ* = RECORD
		fCenter*: REAL;
		fBandwidth*: REAL;
		fGain*: REAL;
	END;

	BASS_DX8_REVERB* = RECORD
		fInGain*: REAL;							(* [-96.0,0.0]				default: 0.0 dB *)
		fReverbMix*: REAL;						(* [-96.0,0.0]				default: 0.0 db *)
		fReverbTime*: REAL;					(* [0.001,3000.0]		default: 1000.0 ms *)
		fHighFreqRTRatio*: REAL;		(* [0.001,0.999]			default: 0.001 *)
	END;

	(* callback function types *)
	STREAMPROC* = PROCEDURE {WINAPI} (handle: HSTREAM; buffer: ADDRESS; length: DWORD; user: ADDRESS): DWORD;
	(*		 User stream callback function. NOTE: A stream function should obviously be as
		quick as possible, other streams (and MOD musics) can't be mixed until
		it's finished.
		handle : The stream that needs writing
		buffer : Buffer to write the samples in
		length : Number of bytes to write
		user	 : The 'user' parameter value given when calling BASS_StreamCreate
		RETURN : Number of bytes written. Set the BASS_STREAMPROC_END flag to end
						 the stream.
 *)

VAR
	(* special STREAMPROCs *)
	STREAMPROC_DUMMY-:	ADDRESS;	(* ADDRESS(0)	"dummy" stream *)
	STREAMPROC_PUSH-:	ADDRESS; (* ADDRESS(-1)	push stream *)

TYPE
	DOWNLOADPROC* = PROCEDURE {WINAPI} (buffer: ADDRESS; length: DWORD; user: ADDRESS);
	(*		 Internet stream download callback function.
		buffer : Buffer containing the downloaded data... NULL=end of download
		length : Number of bytes in the buffer
		user	 : The 'user' parameter value given when calling BASS_StreamCreateURL
 *)

	SYNCPROC* = PROCEDURE {WINAPI} (handle: HSYNC; channel, data: DWORD; user: ADDRESS);
	(*		 Sync callback function. NOTE: a sync callback function should be very
		quick as other syncs cannot be processed until it has finished. If the
		sync is a "mixtime" sync, then other streams and MOD musics can not be
		mixed until it's finished either.
		handle : The sync that has occured
		channel: Channel that the sync occured in
		data	 : Additional data associated with the sync's occurance
		user	 : The 'user' parameter given when calling BASS_ChannelSetSync
 *)

	DSPPROC* = PROCEDURE {WINAPI} (handle: HDSP; channel: DWORD; buffer: ADDRESS; length: DWORD; user: ADDRESS);
	(*		 DSP callback function. NOTE: A DSP function should obviously be as quick
		as possible... other DSP functions, streams and MOD musics can not be
		processed until it's finished.
		handle : The DSP handle
		channel: Channel that the DSP is being applied to
		buffer : Buffer to apply the DSP to
		length : Number of bytes in the buffer
		user	 : The 'user' parameter given when calling BASS_ChannelSetDSP
 *)

	RECORDPROC* = PROCEDURE {WINAPI} (handle: HRECORD; buffer: ADDRESS; length: DWORD; user: ADDRESS): BOOL;
	(*		 Recording callback function.
		handle : The recording handle
		buffer : Buffer containing the recorded sample data
		length : Number of bytes
		user	 : The 'user' parameter value given when calling BASS_RecordStart
		RETURN : TRUE = continue recording, FALSE = stop
 *)

VAR

	(* Functions *)

	BASS_SetConfig-: PROCEDURE {WINAPI} (option, value: DWORD): BOOL;
	BASS_GetConfig-: PROCEDURE {WINAPI} (option: DWORD): DWORD;
	BASS_SetConfigPtr-: PROCEDURE {WINAPI} (option: DWORD; value: ADDRESS): BOOL;
	BASS_GetConfigPtr-: PROCEDURE {WINAPI} (option: DWORD): ADDRESS;

	BASS_GetVersion-: PROCEDURE {WINAPI} (): DWORD;
	BASS_ErrorGetCode-: PROCEDURE {WINAPI} (): LONGINT;
	BASS_GetDeviceInfo-: PROCEDURE {WINAPI} (device: DWORD; VAR info: BASS_DEVICEINFO): BOOL;

	BASS_Init-: PROCEDURE {WINAPI} (device: LONGINT; freq: DWORD; flags: SET; win: HWND; clsid: PGUID): BOOL;

	BASS_SetDevice-: PROCEDURE {WINAPI} (device: DWORD): BOOL;
	BASS_GetDevice-: PROCEDURE {WINAPI} (): DWORD;
	BASS_Free-: PROCEDURE {WINAPI} (): BOOL;

	BASS_GetDSoundObject-: PROCEDURE {WINAPI} (obj: DWORD): ADDRESS;

	BASS_GetInfo-: PROCEDURE {WINAPI} (VAR info: BASS_INFO): BOOL;
	BASS_Update-: PROCEDURE {WINAPI} (length: DWORD): BOOL;
	BASS_GetCPU-: PROCEDURE {WINAPI} (): REAL;
	BASS_Start-: PROCEDURE {WINAPI} (): BOOL;
	BASS_Stop-: PROCEDURE {WINAPI} (): BOOL;
	BASS_Pause-: PROCEDURE {WINAPI} (): BOOL;
	BASS_SetVolume-: PROCEDURE {WINAPI} (volume: REAL): BOOL;
	BASS_GetVolume-: PROCEDURE {WINAPI} (): REAL;

	BASS_PluginLoad-: PROCEDURE {WINAPI} (filename: PChar; flags: SET): HPLUGIN;
	BASS_PluginFree-: PROCEDURE {WINAPI} (handle: HPLUGIN): BOOL;
	BASS_PluginGetInfo-: PROCEDURE {WINAPI} (handle: HPLUGIN): PBASS_PLUGININFO;

	BASS_Set3DFactors-: PROCEDURE {WINAPI} (distf, rollf, doppf: REAL): BOOL;
	BASS_Get3DFactors-: PROCEDURE {WINAPI} (VAR distf, rollf, doppf: REAL): BOOL;
	BASS_Set3DPosition-: PROCEDURE {WINAPI} (VAR pos, vel, front, top: BASS_3DVECTOR): BOOL;
	BASS_Get3DPosition-: PROCEDURE {WINAPI} (VAR pos, vel, front, top: BASS_3DVECTOR): BOOL;
	BASS_Apply3D-: PROCEDURE {WINAPI};

	BASS_SetEAXParameters-: PROCEDURE {WINAPI} (env: LONGINT; vol, decay, damp: REAL): BOOL;
	BASS_GetEAXParameters-: PROCEDURE {WINAPI} (VAR env: DWORD; VAR vol, decay, damp: REAL): BOOL;

	BASS_MusicLoad-: PROCEDURE {WINAPI} (mem: BOOL; f: ADDRESS; offset: QWORD; length: DWORD; flags: SET; freq: DWORD): HMUSIC;
	BASS_MusicFree-: PROCEDURE {WINAPI} (handle: HMUSIC): BOOL;

	BASS_SampleLoad-: PROCEDURE {WINAPI} (mem: BOOL; f: ADDRESS; offset: QWORD; length, max: DWORD; flags: SET): HSAMPLE;
	BASS_SampleCreate-: PROCEDURE {WINAPI} (length, freq, chans, max: DWORD; flags: SET): HSAMPLE;
	BASS_SampleFree-: PROCEDURE {WINAPI} (handle: HSAMPLE): BOOL;
	BASS_SampleSetData-: PROCEDURE {WINAPI} (handle: HSAMPLE; buffer: ADDRESS): BOOL;
	BASS_SampleGetData-: PROCEDURE {WINAPI} (handle: HSAMPLE; buffer: ADDRESS): BOOL;
	BASS_SampleGetInfo-: PROCEDURE {WINAPI} (handle: HSAMPLE; VAR info: BASS_SAMPLE): BOOL;
	BASS_SampleSetInfo-: PROCEDURE {WINAPI} (handle: HSAMPLE; VAR info: BASS_SAMPLE): BOOL;
	BASS_SampleGetChannel-: PROCEDURE {WINAPI} (handle: HSAMPLE; onlynew: BOOL): HCHANNEL;
	BASS_SampleGetChannels-: PROCEDURE {WINAPI} (handle: HSAMPLE; channels: ADDRESS): DWORD;
	BASS_SampleStop-: PROCEDURE {WINAPI} (handle: HSAMPLE): BOOL;

	BASS_StreamCreate-: PROCEDURE {WINAPI} (freq, chans: DWORD; flags: SET; proc: STREAMPROC; user: ADDRESS): HSTREAM;
	BASS_StreamCreateFile-: PROCEDURE {WINAPI} (mem: BOOL; f: ADDRESS; offset, length: QWORD; flags: SET): HSTREAM;
	BASS_StreamCreateURL-: PROCEDURE {WINAPI} (url: PChar; offset: DWORD; flags: SET; proc: DOWNLOADPROC; user: ADDRESS):HSTREAM;
	BASS_StreamCreateFileUser-: PROCEDURE {WINAPI} (system, flags: SET; VAR procs: BASS_FILEPROCS; user: ADDRESS): HSTREAM;
	BASS_StreamFree-: PROCEDURE {WINAPI} (handle: HSTREAM): BOOL;
	BASS_StreamGetFilePosition-: PROCEDURE {WINAPI} (handle: HSTREAM; mode: DWORD): QWORD;
	BASS_StreamPutData-: PROCEDURE {WINAPI} (handle: HSTREAM; buffer: ADDRESS; length: DWORD): DWORD;
	BASS_StreamPutFileData-: PROCEDURE {WINAPI} (handle: HSTREAM; buffer: ADDRESS; length: DWORD): DWORD;

	BASS_RecordGetDeviceInfo-: PROCEDURE {WINAPI} (device: DWORD; VAR info: BASS_DEVICEINFO): BOOL;
	BASS_RecordInit-: PROCEDURE {WINAPI} (device: LONGINT):BOOL;
	BASS_RecordSetDevice-: PROCEDURE {WINAPI} (device: DWORD): BOOL;
	BASS_RecordGetDevice-: PROCEDURE {WINAPI} (): DWORD;
	BASS_RecordFree-: PROCEDURE {WINAPI} (): BOOL;
	BASS_RecordGetInfo-: PROCEDURE {WINAPI} (VAR info: BASS_RECORDINFO): BOOL;
	BASS_RecordGetInputName-: PROCEDURE {WINAPI} (input: LONGINT): PAnsiChar;
	BASS_RecordSetInput-: PROCEDURE {WINAPI} (input: LONGINT; flags: SET; volume: REAL): BOOL;
	BASS_RecordGetInput-: PROCEDURE {WINAPI} (input: LONGINT; VAR volume: REAL): DWORD;
	BASS_RecordStart-: PROCEDURE {WINAPI} (freq, chans: DWORD; flags: SET; proc: RECORDPROC; user: ADDRESS): HRECORD;

	BASS_ChannelBytes2Seconds-: PROCEDURE {WINAPI} (handle: DWORD; pos: QWORD): LONGREAL;
	BASS_ChannelSeconds2Bytes-: PROCEDURE {WINAPI} (handle: DWORD; pos: LONGREAL): QWORD;
	BASS_ChannelGetDevice-: PROCEDURE {WINAPI} (handle: DWORD): DWORD;
	BASS_ChannelSetDevice-: PROCEDURE {WINAPI} (handle, device: DWORD): BOOL;
	BASS_ChannelIsActive-: PROCEDURE {WINAPI} (handle: DWORD): DWORD;
	BASS_ChannelGetInfo-: PROCEDURE {WINAPI} (handle: DWORD; VAR info: BASS_CHANNELINFO):BOOL;
	BASS_ChannelGetTags-: PROCEDURE {WINAPI} (handle: HSTREAM; tags: DWORD): PAnsiChar;
	BASS_ChannelFlags-: PROCEDURE {WINAPI} (handle: DWORD; flags: SET; mask: DWORD): DWORD;
	BASS_ChannelUpdate-: PROCEDURE {WINAPI} (handle, length: DWORD): BOOL;
	BASS_ChannelLock-: PROCEDURE {WINAPI} (handle: DWORD; lock: BOOL): BOOL;
	BASS_ChannelPlay-: PROCEDURE {WINAPI} (handle: DWORD; restart: BOOL): BOOL;
	BASS_ChannelStop-: PROCEDURE {WINAPI} (handle: DWORD): BOOL;
	BASS_ChannelPause-: PROCEDURE {WINAPI} (handle: DWORD): BOOL;

	BASS_ChannelSetAttribute-: PROCEDURE {WINAPI} (handle, attrib: DWORD; value: REAL): BOOL;
	BASS_ChannelGetAttribute-: PROCEDURE {WINAPI} (handle, attrib: DWORD; VAR value: REAL): BOOL;
	BASS_ChannelSlideAttribute-: PROCEDURE {WINAPI} (handle, attrib: DWORD; value: REAL; time: DWORD): BOOL;
	BASS_ChannelIsSliding-: PROCEDURE {WINAPI} (handle, attrib: DWORD): BOOL;
	BASS_ChannelSetAttributeEx-: PROCEDURE {WINAPI} (handle, attrib: DWORD; value: ADDRESS; size: DWORD): BOOL;
	BASS_ChannelGetAttributeEx-: PROCEDURE {WINAPI} (handle, attrib: DWORD; value: ADDRESS; size: DWORD): DWORD;
	BASS_ChannelSet3DAttributes-: PROCEDURE {WINAPI} (handle: DWORD; mode: LONGINT; min, max: REAL; iangle, oangle, outvol: LONGINT): BOOL;
	BASS_ChannelGet3DAttributes-: PROCEDURE {WINAPI} (handle: DWORD; VAR mode: DWORD; VAR min, max: REAL; VAR iangle, oangle, outvol: DWORD): BOOL;
	BASS_ChannelSet3DPosition-: PROCEDURE {WINAPI} (handle: DWORD; VAR pos, orient, vel: BASS_3DVECTOR): BOOL;
	BASS_ChannelGet3DPosition-: PROCEDURE {WINAPI} (handle: DWORD; VAR pos, orient, vel: BASS_3DVECTOR): BOOL;
	BASS_ChannelGetLength-: PROCEDURE {WINAPI} (handle, mode: DWORD): QWORD;
	BASS_ChannelSetPosition-: PROCEDURE {WINAPI} (handle: DWORD; pos: QWORD; mode: DWORD): BOOL;
	BASS_ChannelGetPosition-: PROCEDURE {WINAPI} (handle, mode: DWORD): QWORD;
	BASS_ChannelGetLevel-: PROCEDURE {WINAPI} (handle: DWORD): DWORD;
	BASS_ChannelGetLevelEx-: PROCEDURE {WINAPI} (handle: DWORD; levels: PSingle; length: REAL; flags: SET): BOOL;
	BASS_ChannelGetData-: PROCEDURE {WINAPI} (handle: DWORD; buffer: ADDRESS; length: DWORD): DWORD;
	BASS_ChannelSetSync-: PROCEDURE {WINAPI} (handle: DWORD; type: SET; param: QWORD; proc: SYNCPROC; user: ADDRESS): HSYNC;
	BASS_ChannelRemoveSync-: PROCEDURE {WINAPI} (handle: DWORD; sync: HSYNC): BOOL;
	BASS_ChannelSetDSP-: PROCEDURE {WINAPI} (handle: DWORD; proc: DSPPROC; user: ADDRESS; priority: LONGINT): HDSP;

	BASS_ChannelRemoveDSP-: PROCEDURE {WINAPI} (handle: DWORD; dsp: HDSP): BOOL;
	BASS_ChannelSetLink-: PROCEDURE {WINAPI} (handle, chan: DWORD): BOOL;
	BASS_ChannelRemoveLink-: PROCEDURE {WINAPI} (handle, chan: DWORD): BOOL;
	BASS_ChannelSetFX-: PROCEDURE {WINAPI} (handle, type_: DWORD; priority: LONGINT): HFX;
	BASS_ChannelRemoveFX-: PROCEDURE {WINAPI} (handle: DWORD; fx: HFX): BOOL;
	BASS_FXSetParameters-: PROCEDURE {WINAPI} (handle: HFX; par: ADDRESS): BOOL;
	BASS_FXGetParameters-: PROCEDURE {WINAPI} (handle: HFX; par: ADDRESS): BOOL;
	BASS_FXReset-: PROCEDURE {WINAPI} (handle: HFX): BOOL;
	BASS_FXSetPriority-: PROCEDURE {WINAPI} (handle: HFX; priority: LONGINT): BOOL;

	lib: Kernel32.HMODULE;

CONST
	bassdll		= "bass.dll";

PROCEDURE BASS_SPEAKER_N*(n: DWORD): DWORD;
BEGIN
	RETURN (*n shl 24*)ASH(n, 24);
END BASS_SPEAKER_N;

PROCEDURE BASS_SetEAXPreset*(env: LONGINT): BOOL;
BEGIN
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
END BASS_SetEAXPreset;

PROCEDURE Cleanup;
BEGIN
	IF lib # Kernel32.NULL THEN
		IGNORE Kernel32.FreeLibrary(lib);
		lib := Kernel32.NULL
	END
END Cleanup;

PROCEDURE Init;
VAR
	sFullPath: ARRAY 257 OF CHAR;
	r: Streams.Reader;
BEGIN

	r := Codecs.OpenInputStream(bassdll);
	ASSERT(r # NIL);
	(* Get full path *)
	r(Codecs.FileInputStream).f.GetName(sFullPath);
	KernelLog.String(sFullPath);

	lib := Kernel32.LoadLibrary(sFullPath);
	ASSERT(lib # Kernel32.NULL);

	Kernel32.GetProcAddress(lib, "BASS_SetConfig", SYSTEM.VAL(ADDRESS, BASS_SetConfig));
	Kernel32.GetProcAddress(lib, "BASS_GetConfig", SYSTEM.VAL(ADDRESS, BASS_GetConfig));
	Kernel32.GetProcAddress(lib, "BASS_SetConfigPtr", SYSTEM.VAL(ADDRESS, BASS_SetConfigPtr));
	Kernel32.GetProcAddress(lib, "BASS_GetConfigPtr", SYSTEM.VAL(ADDRESS, BASS_GetConfigPtr));
	Kernel32.GetProcAddress(lib, "BASS_GetVersion", SYSTEM.VAL(ADDRESS, BASS_GetVersion));
	Kernel32.GetProcAddress(lib, "BASS_ErrorGetCode", SYSTEM.VAL(ADDRESS, BASS_ErrorGetCode));
	Kernel32.GetProcAddress(lib, "BASS_GetDeviceInfo", SYSTEM.VAL(ADDRESS, BASS_GetDeviceInfo));

	Kernel32.GetProcAddress(lib, "BASS_Init", SYSTEM.VAL(ADDRESS, BASS_Init));

	Kernel32.GetProcAddress(lib, "BASS_SetDevice", SYSTEM.VAL(ADDRESS, BASS_SetDevice));
	Kernel32.GetProcAddress(lib, "BASS_GetDevice", SYSTEM.VAL(ADDRESS, BASS_GetDevice));
	Kernel32.GetProcAddress(lib, "BASS_Free", SYSTEM.VAL(ADDRESS, BASS_Free));

	Kernel32.GetProcAddress(lib, "BASS_GetDSoundObject", SYSTEM.VAL(ADDRESS, BASS_GetDSoundObject));

	Kernel32.GetProcAddress(lib, "BASS_GetInfo", SYSTEM.VAL(ADDRESS, BASS_GetInfo));
	Kernel32.GetProcAddress(lib, "BASS_Update", SYSTEM.VAL(ADDRESS, BASS_Update));
	Kernel32.GetProcAddress(lib, "BASS_GetCPU", SYSTEM.VAL(ADDRESS, BASS_GetCPU));
	Kernel32.GetProcAddress(lib, "BASS_Start", SYSTEM.VAL(ADDRESS, BASS_Start));
	Kernel32.GetProcAddress(lib, "BASS_Stop", SYSTEM.VAL(ADDRESS, BASS_Stop));
	Kernel32.GetProcAddress(lib, "BASS_Pause", SYSTEM.VAL(ADDRESS, BASS_Pause));
	Kernel32.GetProcAddress(lib, "BASS_SetVolume", SYSTEM.VAL(ADDRESS, BASS_SetVolume));
	Kernel32.GetProcAddress(lib, "BASS_GetVolume", SYSTEM.VAL(ADDRESS, BASS_GetVolume));
	Kernel32.GetProcAddress(lib, "BASS_PluginLoad", SYSTEM.VAL(ADDRESS, BASS_PluginLoad));
	Kernel32.GetProcAddress(lib, "BASS_PluginFree", SYSTEM.VAL(ADDRESS, BASS_PluginFree));
	Kernel32.GetProcAddress(lib, "BASS_PluginGetInfo", SYSTEM.VAL(ADDRESS, BASS_PluginGetInfo));
	Kernel32.GetProcAddress(lib, "BASS_Set3DFactors", SYSTEM.VAL(ADDRESS, BASS_Set3DFactors));
	Kernel32.GetProcAddress(lib, "BASS_Get3DFactors", SYSTEM.VAL(ADDRESS, BASS_Get3DFactors));
	Kernel32.GetProcAddress(lib, "BASS_Set3DPosition", SYSTEM.VAL(ADDRESS, BASS_Set3DPosition));
	Kernel32.GetProcAddress(lib, "BASS_Get3DPosition", SYSTEM.VAL(ADDRESS, BASS_Get3DPosition));
	Kernel32.GetProcAddress(lib, "BASS_Apply3D", SYSTEM.VAL(ADDRESS, BASS_Apply3D));

	Kernel32.GetProcAddress(lib, "BASS_SetEAXParameters", SYSTEM.VAL(ADDRESS, BASS_SetEAXParameters));
	Kernel32.GetProcAddress(lib, "BASS_GetEAXParameters", SYSTEM.VAL(ADDRESS, BASS_GetEAXParameters));

	Kernel32.GetProcAddress(lib, "BASS_MusicLoad", SYSTEM.VAL(ADDRESS, BASS_MusicLoad));
	Kernel32.GetProcAddress(lib, "BASS_MusicFree", SYSTEM.VAL(ADDRESS, BASS_MusicFree));
	Kernel32.GetProcAddress(lib, "BASS_SampleLoad", SYSTEM.VAL(ADDRESS, BASS_SampleLoad));
	Kernel32.GetProcAddress(lib, "BASS_SampleCreate", SYSTEM.VAL(ADDRESS, BASS_SampleCreate));
	Kernel32.GetProcAddress(lib, "BASS_SampleFree", SYSTEM.VAL(ADDRESS, BASS_SampleFree));
	Kernel32.GetProcAddress(lib, "BASS_SampleSetData", SYSTEM.VAL(ADDRESS, BASS_SampleSetData));
	Kernel32.GetProcAddress(lib, "BASS_SampleGetData", SYSTEM.VAL(ADDRESS, BASS_SampleGetData));
	Kernel32.GetProcAddress(lib, "BASS_SampleGetInfo", SYSTEM.VAL(ADDRESS, BASS_SampleGetInfo));
	Kernel32.GetProcAddress(lib, "BASS_SampleSetInfo", SYSTEM.VAL(ADDRESS, BASS_SampleSetInfo));
	Kernel32.GetProcAddress(lib, "BASS_SampleGetChannel", SYSTEM.VAL(ADDRESS, BASS_SampleGetChannel));
	Kernel32.GetProcAddress(lib, "BASS_SampleGetChannels", SYSTEM.VAL(ADDRESS, BASS_SampleGetChannels));
	Kernel32.GetProcAddress(lib, "BASS_SampleStop", SYSTEM.VAL(ADDRESS, BASS_SampleStop));
	Kernel32.GetProcAddress(lib, "BASS_StreamCreate", SYSTEM.VAL(ADDRESS, BASS_StreamCreate));
	Kernel32.GetProcAddress(lib, "BASS_StreamCreateFile", SYSTEM.VAL(ADDRESS, BASS_StreamCreateFile));
	Kernel32.GetProcAddress(lib, "BASS_StreamCreateURL", SYSTEM.VAL(ADDRESS, BASS_StreamCreateURL));
	Kernel32.GetProcAddress(lib, "BASS_StreamCreateFileUser", SYSTEM.VAL(ADDRESS, BASS_StreamCreateFileUser));
	Kernel32.GetProcAddress(lib, "BASS_StreamFree", SYSTEM.VAL(ADDRESS, BASS_StreamFree));
	Kernel32.GetProcAddress(lib, "BASS_StreamGetFilePosition", SYSTEM.VAL(ADDRESS, BASS_StreamGetFilePosition));
	Kernel32.GetProcAddress(lib, "BASS_StreamPutData", SYSTEM.VAL(ADDRESS, BASS_StreamPutData));
	Kernel32.GetProcAddress(lib, "BASS_StreamPutFileData", SYSTEM.VAL(ADDRESS, BASS_StreamPutFileData));
	Kernel32.GetProcAddress(lib, "BASS_RecordGetDeviceInfo", SYSTEM.VAL(ADDRESS, BASS_RecordGetDeviceInfo));
	Kernel32.GetProcAddress(lib, "BASS_RecordInit", SYSTEM.VAL(ADDRESS, BASS_RecordInit));
	Kernel32.GetProcAddress(lib, "BASS_RecordSetDevice", SYSTEM.VAL(ADDRESS, BASS_RecordSetDevice));
	Kernel32.GetProcAddress(lib, "BASS_RecordGetDevice", SYSTEM.VAL(ADDRESS, BASS_RecordGetDevice));
	Kernel32.GetProcAddress(lib, "BASS_RecordFree", SYSTEM.VAL(ADDRESS, BASS_RecordFree));
	Kernel32.GetProcAddress(lib, "BASS_RecordGetInfo", SYSTEM.VAL(ADDRESS, BASS_RecordGetInfo));
	Kernel32.GetProcAddress(lib, "BASS_RecordGetInputName", SYSTEM.VAL(ADDRESS, BASS_RecordGetInputName));
	Kernel32.GetProcAddress(lib, "BASS_RecordSetInput", SYSTEM.VAL(ADDRESS, BASS_RecordSetInput));
	Kernel32.GetProcAddress(lib, "BASS_RecordGetInput", SYSTEM.VAL(ADDRESS, BASS_RecordGetInput));
	Kernel32.GetProcAddress(lib, "BASS_RecordStart", SYSTEM.VAL(ADDRESS, BASS_RecordStart));
	Kernel32.GetProcAddress(lib, "BASS_ChannelBytes2Seconds", SYSTEM.VAL(ADDRESS, BASS_ChannelBytes2Seconds));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSeconds2Bytes", SYSTEM.VAL(ADDRESS, BASS_ChannelSeconds2Bytes));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGetDevice", SYSTEM.VAL(ADDRESS, BASS_ChannelGetDevice));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSetDevice", SYSTEM.VAL(ADDRESS, BASS_ChannelSetDevice));
	Kernel32.GetProcAddress(lib, "BASS_ChannelIsActive", SYSTEM.VAL(ADDRESS, BASS_ChannelIsActive));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGetInfo", SYSTEM.VAL(ADDRESS, BASS_ChannelGetInfo));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGetTags", SYSTEM.VAL(ADDRESS, BASS_ChannelGetTags));
	Kernel32.GetProcAddress(lib, "BASS_ChannelFlags", SYSTEM.VAL(ADDRESS, BASS_ChannelFlags));
	Kernel32.GetProcAddress(lib, "BASS_ChannelUpdate", SYSTEM.VAL(ADDRESS, BASS_ChannelUpdate));
	Kernel32.GetProcAddress(lib, "BASS_ChannelLock", SYSTEM.VAL(ADDRESS, BASS_ChannelLock));
	Kernel32.GetProcAddress(lib, "BASS_ChannelPlay", SYSTEM.VAL(ADDRESS, BASS_ChannelPlay));
	Kernel32.GetProcAddress(lib, "BASS_ChannelStop", SYSTEM.VAL(ADDRESS, BASS_ChannelStop));
	Kernel32.GetProcAddress(lib, "BASS_ChannelPause", SYSTEM.VAL(ADDRESS, BASS_ChannelPause));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSetAttribute", SYSTEM.VAL(ADDRESS, BASS_ChannelSetAttribute));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGetAttribute", SYSTEM.VAL(ADDRESS, BASS_ChannelGetAttribute));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSlideAttribute", SYSTEM.VAL(ADDRESS, BASS_ChannelSlideAttribute));
	Kernel32.GetProcAddress(lib, "BASS_ChannelIsSliding", SYSTEM.VAL(ADDRESS, BASS_ChannelIsSliding));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSetAttributeEx", SYSTEM.VAL(ADDRESS, BASS_ChannelSetAttributeEx));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGetAttributeEx", SYSTEM.VAL(ADDRESS, BASS_ChannelGetAttributeEx));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSet3DAttributes", SYSTEM.VAL(ADDRESS, BASS_ChannelSet3DAttributes));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGet3DAttributes", SYSTEM.VAL(ADDRESS, BASS_ChannelGet3DAttributes));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSet3DPosition", SYSTEM.VAL(ADDRESS, BASS_ChannelSet3DPosition));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGet3DPosition", SYSTEM.VAL(ADDRESS, BASS_ChannelGet3DPosition));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGetLength", SYSTEM.VAL(ADDRESS, BASS_ChannelGetLength));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSetPosition", SYSTEM.VAL(ADDRESS, BASS_ChannelSetPosition));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGetPosition", SYSTEM.VAL(ADDRESS, BASS_ChannelGetPosition));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGetLevel", SYSTEM.VAL(ADDRESS, BASS_ChannelGetLevel));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGetLevelEx", SYSTEM.VAL(ADDRESS, BASS_ChannelGetLevelEx));
	Kernel32.GetProcAddress(lib, "BASS_ChannelGetData", SYSTEM.VAL(ADDRESS, BASS_ChannelGetData));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSetSync", SYSTEM.VAL(ADDRESS, BASS_ChannelSetSync));
	Kernel32.GetProcAddress(lib, "BASS_ChannelRemoveSync", SYSTEM.VAL(ADDRESS, BASS_ChannelRemoveSync));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSetDSP", SYSTEM.VAL(ADDRESS, BASS_ChannelSetDSP));
	Kernel32.GetProcAddress(lib, "BASS_ChannelRemoveDSP", SYSTEM.VAL(ADDRESS, BASS_ChannelRemoveDSP));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSetLink", SYSTEM.VAL(ADDRESS, BASS_ChannelSetLink));
	Kernel32.GetProcAddress(lib, "BASS_ChannelRemoveLink", SYSTEM.VAL(ADDRESS, BASS_ChannelRemoveLink));
	Kernel32.GetProcAddress(lib, "BASS_ChannelSetFX", SYSTEM.VAL(ADDRESS, BASS_ChannelSetFX));
	Kernel32.GetProcAddress(lib, "BASS_ChannelRemoveFX", SYSTEM.VAL(ADDRESS, BASS_ChannelRemoveFX));
	Kernel32.GetProcAddress(lib, "BASS_FXSetParameters", SYSTEM.VAL(ADDRESS, BASS_FXSetParameters));
	Kernel32.GetProcAddress(lib, "BASS_FXGetParameters", SYSTEM.VAL(ADDRESS, BASS_FXGetParameters));
	Kernel32.GetProcAddress(lib, "BASS_FXReset", SYSTEM.VAL(ADDRESS, BASS_FXReset));
	Kernel32.GetProcAddress(lib, "BASS_FXSetPriority", SYSTEM.VAL(ADDRESS, BASS_FXSetPriority));

	Modules.InstallTermHandler(Cleanup)
END Init;

BEGIN
	STREAMPROC_DUMMY	:= SYSTEM.VAL(ADDRESS, 0);	(* ADDRESS(0)	"dummy" stream *)
	STREAMPROC_PUSH	:= SYSTEM.VAL(ADDRESS, -1); (* ADDRESS(-1)	push stream *)
	Init;
END BASS.

