MODULE TestRAR; (** AUTHOR "BohdanT"; PURPOSE "UnRar.Dll example"; *)

IMPORT SYSTEM, UnRAR, Strings, WMDialogs, KernelLog;
TYPE
	Mode = ENUM Extract, Test, Print END;
	String = Strings.String;
PROCEDURE TestVer*;
BEGIN
	KernelLog.String("Rar version= "); KernelLog.Int(UnRAR.RARGetDllVersion(), 0); KernelLog.Ln;
END TestVer;

PROCEDURE{WINAPI} CallbackProc (msg: LONGINT; UserData, P1, P2: LONGINT) :LONGINT;
VAR
  i: LONGINT;
BEGIN
  CASE msg OF
	|UnRAR.UcmChangeVolume:
		IF (P2 = UnRAR.RarVolAsk) THEN
			KernelLog.String("Insert disk with "); KernelLog.String(SYSTEM.VAL(String,P1)^);KernelLog.String(" and press ''Enter'' or enter ''Q'' to exit "); KernelLog.Ln; 
(*!TODO: Query*)
		END;
	|UnRAR.UcmNeedPassword:
(*!TODO:
        Write(CR, 'Please enter the password for this archive: ');
        Readln(S);
        C := PAnsiChar(S);
        Move(pointer(C)^, pointer(p1)^, AnsiStrings.StrLen(C) + 1);*)
	|UnRAR.UcmProcessData:
	      IF (UserData # 0) & (SYSTEM.GET32(UserData)=2) THEN
			FOR i := 0 TO P2 - 1 DO
				KernelLog.Char(CHR(SYSTEM.GET8(P1+i)));
			END;
		END;
	ELSE
	END;
	RETURN 0;
END CallbackProc;

PROCEDURE ExtractArchive*(ArcName: Strings.String; mode: Mode);
VAR
	hArcData: LONGINT;
	RHCode, PFCode: LONGINT;
	CmtBuf: String;
	HeaderData: UnRAR.RARHeaderData;
  
	OpenArchiveData:  UnRAR.RAROpenArchiveDataEx;
	Operation: LONGINT;
BEGIN
	NEW(CmtBuf, 16384);
	OpenArchiveData.ArcName := ADDRESSOF(ArcName[0]);
	OpenArchiveData.CmtBuf := ADDRESSOF(CmtBuf[0]);

	OpenArchiveData.CmtBufSize := LEN(CmtBuf);
	OpenArchiveData.OpenMode := UnRAR.RarOMExtract;
	hArcData := UnRAR.RAROpenArchiveEx(OpenArchiveData);

	IF (OpenArchiveData.OpenResult # 0) THEN
		OutOpenArchiveError(OpenArchiveData.OpenResult, ArcName);
		RETURN;
	END;

(*  ShowArcInfo(OpenArchiveData.Flags, ArcName);*)

  IF OpenArchiveData.CmtState = 1 THEN ShowComment(CmtBuf); END;
	
	UnRAR.RARSetCallback (hArcData, CallbackProc, LONGINT(mode));

	HeaderData.CmtBuf := NIL;

	LOOP
		RHCode := UnRAR.RARReadHeader(hArcData, HeaderData);
		IF RHCode # 0 THEN EXIT END;
		CASE mode OF
			|Mode.Extract: KernelLog.String("Extracting "); 
			|Mode.Test:KernelLog.String("Testing ");
			|Mode.Print:KernelLog.String("Printing ");
		END;
		KernelLog.String(HeaderData.FileName);
		
		IF mode = Mode.Extract THEN
			Operation := UnRAR.RarExtract;
		ELSE
			Operation := UnRAR.RarTest;
		END;
		PFCode := UnRAR.RARProcessFile(hArcData, Operation, NIL, NIL);

		IF PFCode = 0 THEN
			KernelLog.String(' Ok');KernelLog.Ln;
		ELSE
			OutProcessFileError(PFCode);
			EXIT;
		END;
	END;

	IF RHCode = UnRAR.ERarBadData THEN
		KernelLog.String("File header broken");  KernelLog.Ln; 
    END;

	UnRAR.RARCloseArchive(hArcData);
END ExtractArchive;


PROCEDURE ListArchive*(CONST ArcName: Strings.String);
VAR
  hArcData: LONGINT;
  RHCode, PFCode: LONGINT;
  CmtBuf: String;
  HeaderData: UnRAR.RARHeaderDataEx;
  OpenArchiveData: UnRAR.RAROpenArchiveDataEx;
BEGIN
	NEW(CmtBuf, 16384);
	OpenArchiveData.ArcName := ADDRESSOF(ArcName[0]);
	OpenArchiveData.CmtBuf := ADDRESSOF(CmtBuf[0]);
	OpenArchiveData.CmtBufSize := LEN(CmtBuf);
	OpenArchiveData.OpenMode := UnRAR.RarOMList;
	hArcData := UnRAR.RAROpenArchiveEx(OpenArchiveData);

	IF OpenArchiveData.OpenResult # 0 THEN 
		OutOpenArchiveError(OpenArchiveData.OpenResult, ArcName);
		RETURN;
	END;


 	ShowArcInfo(OpenArchiveData.Flags, ArcName);

 	IF OpenArchiveData.CmtState = 1 THEN ShowComment(CmtBuf); END;

 	UnRAR.RARSetCallback (hArcData, CallbackProc, 0);

 	HeaderData.CmtBuf := CmtBuf;
 	HeaderData.CmtBufSize := LEN(CmtBuf);
	KernelLog.String("Size"09X09X09X09X"File");KernelLog.Ln;
	KernelLog.String("------------------------------------");KernelLog.Ln;
	LOOP
		RHCode := UnRAR.RARReadHeaderEx(hArcData, HeaderData);
		IF RHCode # 0 THEN EXIT END;
		KernelLog.Int(HeaderData.UnpSize + HeaderData.UnpSizeHigh * 4294967296,16);
		KernelLog.Char(09X);KernelLog.Char(09X);
		KernelLog.String(HeaderData.FileName);
		KernelLog.Ln;
		IF HeaderData.CmtState = 1 THEN ShowComment(CmtBuf); END;
		PFCode:= UnRAR.RARProcessFile(hArcData, UnRAR.RarSkip, NIL, NIL);
		IF PFCode # 0 THEN
			OutProcessFileError(PFCode);
			EXIT
		END;
	END;

	IF RHCode = UnRAR.ERarBadData THEN  KernelLog.String("File header broken");KernelLog.Ln; END;

	UnRAR.RARCloseArchive(hArcData);
END ListArchive;


PROCEDURE ShowComment(CmtBuf: String);
BEGIN
  KernelLog.String("Comment:");KernelLog.Ln;
  KernelLog.String(CmtBuf^); KernelLog.Ln;
END ShowComment;

PROCEDURE ShowArcInfo(Flags: SET; ArcName: String);
	PROCEDURE  CheckFlag(s: ARRAY OF CHAR; FlagBit: LONGINT);
	BEGIN
		KernelLog.Char(09X); KernelLog.String(s);
		IF FlagBit IN Flags THEN KernelLog.String("[X]") ELSE KernelLog.String("[ ]"); END;
		KernelLog.Ln;
	END CheckFlag;
BEGIN
	KernelLog.String("Archive ");KernelLog.String(ArcName^); KernelLog.Ln; 
	CheckFlag('Volume:', 0);
	CheckFlag('Comment:', 1);
	CheckFlag('Locked:', 2);
	CheckFlag('Solid:', 3);
	CheckFlag('New naming:', 4); 
	CheckFlag('Authenticity:', 5);
	CheckFlag('Recovery:', 6);
	CheckFlag('Encr.headers:', 7);
	CheckFlag('First volume:', 8);
	KernelLog.String("---------------------------");KernelLog.Ln; 
END ShowArcInfo;

PROCEDURE Help*;
BEGIN
	KernelLog.String("UNRDLL.   This is a simple example of UNRAR.DLL usage");KernelLog.Ln;
	KernelLog.String("Syntax:");KernelLog.Ln;
	KernelLog.String("UNRDLL X <Archive>     extract archive contents");KernelLog.Ln;
	KernelLog.String("UNRDLL T <Archive>     test archive contents");KernelLog.Ln;
	KernelLog.String("UNRDLL P <Archive>     print archive contents to stdout");KernelLog.Ln;
	KernelLog.String("UNRDLL L <Archive>     view archive contents");KernelLog.Ln;
END Help;

PROCEDURE OutOpenArchiveError(Error: LONGINT; ArcName: String);
BEGIN
	CASE Error OF
		|UnRAR.ERarNoMemory: 	KernelLog.String("Not enough memory");
		|UnRAR.ERarEOpen:		KernelLog.String("Cannot open "); KernelLog.String(ArcName^);
		|UnRAR.ERarBadArchive:	KernelLog.String( ArcName^); KernelLog.String(" is not RAR archive");
		|UnRAR.ERarBadData:   	KernelLog.String( ArcName^); KernelLog.String(": archive header broken");
	ELSE
		(*ERAR_UNKNOWN: *)
		KernelLog.String("Unknown error");
	END;
	KernelLog.Ln;
END OutOpenArchiveError;

PROCEDURE OutProcessFileError(Error: LONGINT);
BEGIN
	CASE Error OF
		|UnRAR.ERarUnknownFormat:KernelLog.String(" Unknown archive format");
		|UnRAR.ERarBadArchive:KernelLog.String(" Bad volume");
		|UnRAR.ERarECreate:KernelLog.String(" File create error");
		|UnRAR.ERarEOpen:KernelLog.String(" 	Volume open error");
		|UnRAR.ERarEClose:KernelLog.String(" File close error");
		|UnRAR.ERarERead:KernelLog.String(" Read error");
		|UnRAR.ERarEWrite:KernelLog.String(" Write error");
		|UnRAR.ERarBadData:KernelLog.String(" CRC error");
	ELSE
		(*ERarUnknown:*)
		KernelLog.String(" Unknown error");
	END;
END OutProcessFileError;
PROCEDURE Test*;
VAR
	s:String;
BEGIN
	NEW(s,80);
	s^:="real.rar";
	ListArchive(s);

END Test;
PROCEDURE Test2*;
VAR
	s:String;
BEGIN
	NEW(s,80);
	s^:="real.rar";
	ExtractArchive(s,Mode.Extract);

END Test2;
	
BEGIN
END TestRAR.TestVer~
PC.Compile TestRAR.Mod~
TestRAR.Test~
TestRAR.Test2~
WMDebugger.Open TestRAR.Mod~