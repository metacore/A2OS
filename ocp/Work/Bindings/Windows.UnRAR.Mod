MODULE	UnRAR;	(**	AUTHOR	"BohdanT";	PURPOSE	"";	*)
IMPORT SYSTEM,  Kernel32, Modules;
CONST
	ERarEndArchive*			=	10;
	ERarNoMemory*			=	11;
	ERarBadData*				=	12;
	ERarBadArchive*			=	13;
	ERarUnknownFormat*	=	14;
	ERarEOpen*				=	15;
	ERarECreate*				=	16;
	ERarEClose*				=	17;
	ERarERead*				=	18;
	ERarEWrite*				=	19;
	ERarSmallBuf*				=	20;
	ERarUnknown*			=	21;

	RarOMList*				=	0;
	RarOMExtract*				=	1;

	RarSkip*					=	0;
	RarTest*					=	1;
	RarExtract*					=	2;

	RarVolAsk*					=	0;
	RarVolNotify*				=	1;

	RarDllVersion*				=	3;

	UcmChangeVolume*		=	0;
	UcmProcessData*			=	1;
	UcmNeedPassword*		=	2;

TYPE
	String = ADDRESS;
	WideString = ADDRESS;

	RARHeaderData* = RECORD
		ArcName* : ARRAY 260 OF CHAR;
		FileName* : ARRAY 260 OF CHAR;
		Flags* : SET;
		PackSize* : LONGINT;
		UnpSize* : LONGINT;
		HostOS* : LONGINT;
		FileCRC* : LONGINT;
		FileTime* : LONGINT;
		UnpVer* : LONGINT;
		Method* : LONGINT;
		FileAttr* : LONGINT;
		CmtBuf* : String;
		CmtBufSize* : LONGINT;
		CmtSize* : LONGINT;
		CmtState* : LONGINT;
	END;

	RARHeaderDataEx* = RECORD
		ArcName* : ARRAY 1024 OF CHAR;
		ArcNameW* : ARRAY 1024 OF CHAR16;
		FileName* : ARRAY 1024 OF CHAR;
		FileNameW* : ARRAY 1024 OF CHAR16;
		Flags* : SET;
		PackSize* : LONGINT;
		PackSizeHigh* : LONGINT;
		UnpSize* : LONGINT;
		UnpSizeHigh* : LONGINT;
		HostOS* : LONGINT;
		FileCRC* : LONGINT;
		FileTime* : LONGINT;
		UnpVer* : LONGINT;
		Method* : LONGINT;
		FileAttr* : LONGINT;
		CmtBuf* : String;
		CmtBufSize* : LONGINT;
		CmtSize* : LONGINT;
		CmtState* : LONGINT;
		Reserved* : ARRAY 1024 OF LONGINT;
	END;

	RAROpenArchiveData* = RECORD
		ArcName* : String;
		OpenMode* : LONGINT;
		OpenResult* : LONGINT;
		CmtBuf* : String;
		CmtBufSize* : LONGINT;
		CmtSize* : LONGINT;
		CmtState* : LONGINT;
	END;

	RAROpenArchiveDataEx* = RECORD
		ArcName* : ADDRESS;
		ArcNameW* : ADDRESS;
		OpenMode* : LONGINT;
		OpenResult* : LONGINT;
		CmtBuf* : ADDRESS;
		CmtBufSize* : LONGINT;
		CmtSize* : LONGINT;
		CmtState* : LONGINT;
		Flags* : SET;
		Reserved* : ARRAY 32 OF LONGINT;
	END;
  UnRarCallback* = PROCEDURE{WINAPI} (Msg: LONGINT; UserData, P1, P2: LONGINT):LONGINT;

CONST
	unrardll = "unrar.dll";
VAR
RAROpenArchive-: PROCEDURE {WINAPI}(VAR ArchiveData: RAROpenArchiveData): LONGINT;
RAROpenArchiveEx-: PROCEDURE {WINAPI} (VAR ArchiveData: RAROpenArchiveDataEx): LONGINT;
RARCloseArchive-: PROCEDURE {WINAPI}(hArcData: LONGINT): LONGINT;
RARReadHeader-: PROCEDURE {WINAPI}(hArcData: LONGINT; VAR HeaderData: RARHeaderData): LONGINT;
RARReadHeaderEx-: PROCEDURE {WINAPI}(hArcData: LONGINT; VAR HeaderData: RARHeaderDataEx): LONGINT;
RARProcessFile-: PROCEDURE {WINAPI}(hArcData: LONGINT; Operation: LONGINT; DestPath, DestName: String): LONGINT;
RARSetCallback-: PROCEDURE {WINAPI}(hArcData: LONGINT; UnrarCallback: UnRarCallback; UserData: LONGINT);
RARSetPassword-: PROCEDURE {WINAPI}(hArcData: LONGINT; Password: String);
RARGetDllVersion-: PROCEDURE {WINAPI}(): LONGINT;
VAR
	mod:LONGINT;

PROCEDURE Cleanup;
BEGIN
	IF mod # Kernel32.NULL THEN
		IGNORE Kernel32.FreeLibrary(mod);
		mod := Kernel32.NULL
	END
END Cleanup;

PROCEDURE Init*():BOOLEAN;
BEGIN
	mod := Kernel32.LoadLibrary(unrardll);
	Kernel32.GetProcAddress(mod, "RAROpenArchive", SYSTEM.VAL(ADDRESS, RAROpenArchive));
	Kernel32.GetProcAddress(mod, "RAROpenArchiveEx", SYSTEM.VAL(ADDRESS, RAROpenArchiveEx));
	Kernel32.GetProcAddress(mod, "RARCloseArchive", SYSTEM.VAL(ADDRESS, RARCloseArchive));
	Kernel32.GetProcAddress(mod, "RARReadHeader", SYSTEM.VAL(ADDRESS, RARReadHeader));
	Kernel32.GetProcAddress(mod, "RARReadHeaderEx", SYSTEM.VAL(ADDRESS, RARReadHeaderEx));
	Kernel32.GetProcAddress(mod, "RARProcessFile", SYSTEM.VAL(ADDRESS, RARProcessFile));
	Kernel32.GetProcAddress(mod, "RARSetCallback", SYSTEM.VAL(ADDRESS, RARSetCallback));
	Kernel32.GetProcAddress(mod, "RARSetPassword", SYSTEM.VAL(ADDRESS, RARSetPassword));
	Kernel32.GetProcAddress(mod, "RARGetDllVersion", SYSTEM.VAL(ADDRESS, RARGetDllVersion));
	RETURN mod # Kernel32.NULL;
END Init;

BEGIN
	IF Init() THEN
		Modules.InstallTermHandler(Cleanup);
	END;
END	UnRAR.
