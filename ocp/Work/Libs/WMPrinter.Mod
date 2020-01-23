MODULE WMPrinter; (** AUTHOR "BohdanT"; PURPOSE "Simple printer Canvas"; *)

IMPORT SYSTEM, Strings, WMGraphics, Kernel32, GDI32, User32, Modules, KernelLog;

CONST
	(*PrinterState:*)
	psNoHandle* = 0; psHandleIC* =1; psHandleDC* = 2;
	(*PrinterOrientation:*)
	poPortrait* = 0; poLandscape* =1;
	winspl = "winspool.drv";
  kernel32  = "kernel32.dll";
	(* The data area passed to a system call is too small. *)
	ERROR_INSUFFICIENT_BUFFER = 122;   (* dderror *)

	(* The filename, directory name, or volume label syntax is incorrect. *)
	ERROR_INVALID_NAME = 123;


TYPE
	String = Strings.String;
	Canvas= OBJECT(WMGraphics.Canvas)
	VAR
		handle : LONGINT;
		font : LONGINT;
		dc:LONGINT;
		PROCEDURE &Init*(dc : LONGINT);
		BEGIN
			SELF.dc := dc;
		END Init;

		PROCEDURE SetWinFont(CONST name:ARRAY 32 OF CHAR; size:LONGINT);
		VAR
			lf : GDI32.LogFont;
		BEGIN
			lf.lfFaceName:=name;
			lf.lfHeight:=size;
			lf.lfItalic:=TRUE;
			lf.lfStrikeOut:=FALSE;
			lf.lfUnderline:=FALSE;
			lf.lfWidth:=0;
			lf.lfWeight:=40;
			lf.lfCharSet:=1(*DEFAULT_CHARSET*);
			lf.lfPitchAndFamily:=0(*DEFAULT_PITCH*);
			lf.lfEscapement:=0;
			font := GDI32.CreateFontIndirect(lf);
			GDI32.SelectObject(dc, font);
		END SetWinFont;
	PROCEDURE DrawString*(x, y: LONGINT; CONST text : ARRAY OF CHAR);
	VAR
		s:ARRAY 255 OF CHAR;(*!stupid*)
	BEGIN
		IF font # 0 THEN
			COPY(text,s);
			GDI32.TextOut(dc, x, y, s, Strings.Length(s));
		END
	END DrawString;

	PROCEDURE Ellipse;
	BEGIN
		GDI32.Ellipse(dc, 20,100,200,200);
	END Ellipse;

	
	END Canvas;


	PStr = POINTER{UNSAFE} TO ARRAY OF CHAR;
(*  PRINTER_INFO_5A = POINTER TO RECORD
    pPrinterName: String;
    pPortName: String;
    Attributes: LONGINT;
    DeviceNotSelectedTimeout: LONGINT;
    TransmissionRetryTimeout: LONGINT;
  END;*)
	PINFO_4A = POINTER{UNSAFE} TO _PRINTER_INFO_4A;
	_PRINTER_INFO_4A = RECORD
		pPrinterName:ADDRESS;
		pServerName: ADDRESS;
		Attributes: LONGINT;
	END;

	PrinterDefaults = POINTER TO RECORD;
		pDatatype: String;
		pDevMode: DeviceModeA;
		DesiredAccess: ADDRESS;
	END;
	PDeviceModeA = POINTER{UNSAFE} TO DeviceModeA;
	DeviceModeA* = RECORD
		dmDeviceName: ARRAY 32 OF CHAR;
		dmSpecVersion: INTEGER;
		dmDriverVersion: INTEGER;
		dmSize: INTEGER;
		dmDriverExtra: INTEGER;
		dmFields: SET;
		dmOrientation: INTEGER;
		dmPaperSize: INTEGER;
		dmPaperLength: INTEGER;
		dmPaperWidth: INTEGER;
		dmScale: INTEGER;
		dmCopies: INTEGER;
		dmDefaultSource: INTEGER;
		dmPrintQuality: INTEGER;
		dmColor: INTEGER;
		dmDuplex: INTEGER;
		dmYResolution: INTEGER;
		dmTTOption: INTEGER;
		dmCollate: INTEGER;
		dmFormName: ARRAY 32 OF CHAR;
		dmLogPixels: INTEGER;
		dmBitsPerPel: LONGINT;
		dmPelsWidth: LONGINT;
		dmPelsHeight: LONGINT;
		dmDisplayFlags: LONGINT;
		dmDisplayFrequency: LONGINT;
		dmICMMethod: LONGINT;
		dmICMIntent: LONGINT;
		dmMediaType: LONGINT;
		dmDitherType: LONGINT;
		dmICCManufacturer: LONGINT;
		dmICCModel: LONGINT;
		dmPanningWidth: LONGINT;
		dmPanningHeight: LONGINT;
	END;

	DocInfo = RECORD
    cbSize: LONGINT;
    lpszDocName: String;
    lpszOutput: String;
    lpszDatatype: String;
    fwType: LONGINT;
  END;
	
	Printer = OBJECT
	VAR
		canvas-: Canvas;
		pageNumber-: LONGINT;
		printing-, aborted-: BOOLEAN;
		orientation- : LONGINT;
		DeviceMode: LONGINT;
		DevMode : PDeviceModeA;
		driver, device, port:ARRAY 32 OF CHAR;
		title* : String;
		printerIndex : LONGINT;
		State-: LONGINT;
		DC-: LONGINT;
		PROCEDURE &Init;
		BEGIN
			
		END Init;
		
	PROCEDURE RaiseError(CONST msg:ARRAY OF CHAR);
	BEGIN
		HALT(105);
	END RaiseError;

	PROCEDURE CheckPrinting(Value: BOOLEAN);
	BEGIN
		IF printing # Value THEN
			IF Value THEN RaiseError("Printer is not currently printing")
			ELSE RaiseError('Printing in progress');END
		END;
	END CheckPrinting;



	PROCEDURE SetToDefaultPrinter*;
	VAR
		pos:LONGINT;
	PROCEDURE FetchStr(CONST from: ARRAY OF CHAR;VAR to:ARRAY OF CHAR);
	VAR
		i:LONGINT;
	BEGIN
	  WHILE from[pos] = ' ' DO INC(pos);END;
	  WHILE (from[pos] # 0X) & (from[pos] # ',') DO 
			to[i]:=from[pos];
			INC(i);INC(pos);
	  END;
	  INC(pos);
	  to[i]:=0X;
	END FetchStr;

	VAR
		i: LONGINT;
		ByteCnt, StructCnt: LONGINT;
		handle:LONGINT;
		DefaultPrinter: ARRAY 1024 OF CHAR; 
		Cur, Device: ARRAY 255 OF CHAR;
		PrinterInfo: PINFO_4A;
		buf:String;
		adr:ADDRESS;
		s:ARRAY 255 OF CHAR;
		StubDevMode:DeviceModeA;
		PROCEDURE GetName(a:ADDRESS; VAR s:ARRAY OF CHAR);
		VAR
			ch:CHAR;i:LONGINT;
		BEGIN
			i:=0;
			REPEAT
				SYSTEM.GET(a, ch);
				s[i]:=ch;
				INC(i);INC(a);
			UNTIL ch=0X;
		END GetName;
		
	BEGIN


		ByteCnt := 0;StructCnt := 0;pos:=0;

		IF ~EnumPrinters(6(*PRINTER_ENUM_CONNECTIONS, PRINTER_ENUM_LOCAL*), NIL, 4, NIL, 0, ByteCnt, StructCnt) 
			& (Kernel32.GetLastError() # ERROR_INSUFFICIENT_BUFFER) THEN
			(* With no printers installed, Win95/98 fails above with "Invalid filename".
			NT succeeds and returns a StructCnt of zero.*)
			IF Kernel32.GetLastError() = ERROR_INVALID_NAME THEN RaiseError("No Default Printer")
			ELSE RaiseError("No Default Printer");END;
		END;
	(*	PrinterInfo := AllocMem(ByteCnt);*)
		
		IF ByteCnt>0 THEN
			NEW(buf, ByteCnt);
			adr:=ADDRESSOF(buf^[0]);
			EnumPrinters(6, NIL, 4, adr, ByteCnt, ByteCnt, StructCnt);
			KernelLog.String("ByteCnt= "); KernelLog.Int(ByteCnt, 0); KernelLog.Ln;
			KernelLog.String("StructCnt= "); KernelLog.Int(StructCnt, 0); KernelLog.Ln;
			
			GetProfileString('windows', 'device', '', DefaultPrinter, LEN(DefaultPrinter) - 1);
			KernelLog.String("DefaultPrinter= "); KernelLog.String(DefaultPrinter); KernelLog.Ln; 
			FetchStr(DefaultPrinter, Device);
			FetchStr(DefaultPrinter, Cur);
			KernelLog.String("Device= "); KernelLog.String(Device); KernelLog.Ln; 
			KernelLog.String("Cur= "); KernelLog.String(Cur); KernelLog.Ln; 
			FOR i:=0 TO StructCnt-1 DO
	(*			SYSTEM.MOVE(adr,ADDRESSOF(PrinterInfo), SIZEOF(_PRINTER_INFO_4A));*)
				PrinterInfo:=adr;
				GetName(PrinterInfo.pPrinterName, s);
				KernelLog.String("------------------------ ");  KernelLog.Ln; 
				KernelLog.String("pPrinterName= "); 
				KernelLog.String("s= "); KernelLog.String(s); KernelLog.Ln;
				KernelLog.String("adr= "); KernelLog.Hex(adr, 0); KernelLog.Ln;
				INC(adr,SIZEOF(_PRINTER_INFO_4A));
			END;
			IF OpenPrinter(Device, handle, NIL) THEN
				KernelLog.String("handle= "); KernelLog.Int(handle, 0); KernelLog.Ln;
				DeviceMode:=Kernel32.GlobalAlloc(SYSTEM.VAL(SET, 66), DocumentProperties(0, handle, Device, StubDevMode, StubDevMode, 0));
				IF DeviceMode#0 THEN
					KernelLog.String("DeviceMode= "); KernelLog.Int(DeviceMode, 0); KernelLog.Ln;
					DevMode := Kernel32.GlobalLock(DeviceMode);
					IF DocumentProperties(0, handle, Device, DevMode^, DevMode^, 2(*DM_OUT_BUFFER*)) < 0 THEN
						Kernel32.GlobalUnlock(DeviceMode);
						GlobalFree(DeviceMode);
						DeviceMode := 0;
						DevMode := NIL;
					ELSE
						KernelLog.Memory(ADDRESSOF(DevMode^.dmDeviceName[0]), 32);
						KernelLog.String("DevMode^.dmSize= "); KernelLog.Int(DevMode^.dmSize, 0); KernelLog.Ln;
					END;
				END;
			END;
		END;
	END SetToDefaultPrinter;

	PROCEDURE BeginDoc*;
	VAR
	  docInfo: GDI32.DocInfo;
	BEGIN
		CheckPrinting(FALSE);
		SetState(psHandleDC);


		printing := TRUE;
		aborted := FALSE;
		pageNumber := 1;

		docInfo.cbSize := SIZEOF(DocInfo);
		IF title#NIL THEN docInfo.lpszDocName := ADDRESSOF(title[0]);
		ELSE docInfo.lpszDocName := 0; END;
	(*  SetAbortProc(DC, AbortProc);*)
		GDI32.StartDoc(DC, docInfo);

		GDI32.StartPage(DC);
	END BeginDoc;

	PROCEDURE EndDoc*;
	BEGIN
		CheckPrinting(TRUE);
		GDI32.EndPage(DC);
		IF ~aborted THEN GDI32.EndDoc(DC);END;
		printing := FALSE;
		aborted := FALSE;
		pageNumber := 0;
	END EndDoc;

	PROCEDURE NewPage*;
	BEGIN
		CheckPrinting(TRUE);
		GDI32.EndPage(DC);
		GDI32.StartPage(DC);
		INC(pageNumber);
	END NewPage;



	PROCEDURE GetPrinterIndex*(): LONGINT;
	BEGIN
	  IF  printerIndex = -1 THEN SetToDefaultPrinter; END;
	  RETURN printerIndex;
	END GetPrinterIndex;
	(** *)
	PROCEDURE SetState*(value:LONGINT);
	TYPE
  CreateHandleFunc =  PROCEDURE {WINAPI} (VAR lpszDriver, lpszDevice, lpszOuput: ARRAY   OF CHAR;  lpInitData: ANY): User32.HDC;
	VAR
		createHandleFunc: CreateHandleFunc;
	BEGIN
		IF value # State THEN
(*			reateHandleFunc := NIL;*)
			CASE value OF
				|psNoHandle:
						CheckPrinting(FALSE);
						IF canvas#NIL THEN canvas.handle := 0; END;
						GDI32.DeleteDC(DC);
						DC := 0;
(*				|psHandleIC:
					IF State # psHandleDC THEN CreateHandleFunc := CreateIC
					ELSE RETURN END;*)
				|psHandleDC:
						IF canvas # NIL THEN canvas.handle := 0;END;
						IF DC # 0 THEN GDI32.DeleteDC(DC); END;
						createHandleFunc := GDI32.CreateDC;
			END;
			IF createHandleFunc#NIL THEN
					DC := createHandleFunc(driver, DevMode^.dmDeviceName, port, DevMode);
					IF DC = 0 THEN RaiseError("InvalidPrinter"); END;
					IF canvas # NIL THEN canvas.handle := DC; END;
			END;
			State := value;
		END;

	END SetState;

	(** Set paper orientation*)
	PROCEDURE SetOrientation*(value:SHORTINT);
	VAR
		res:LONGINT;
	BEGIN
		CheckPrinting(FALSE);
		res:=GetPrinterIndex();
		IF DeviceMode = 0 THEN RaiseError("Operation not supported on selected printer"); END;
		DevMode^.dmOrientation := value+1;
	END SetOrientation;
	
	END Printer;

VAR
	EnumPrinters-: PROCEDURE {WINAPI}
	(Flags: LONGINT; Name: String; Level: LONGINT; pPrinterEnum: ADDRESS; cbBuf: LONGINT; VAR pcbNeeded, pcReturned: LONGINT): BOOLEAN;

	OpenPrinter-: PROCEDURE {WINAPI}(CONST pPrinterName: ARRAY OF CHAR; VAR phPrinter: LONGINT; pDefault: PrinterDefaults): BOOLEAN;

	DocumentProperties-: PROCEDURE {WINAPI}
	(hWnd: LONGINT; hPrinter: LONGINT; CONST pDeviceName: ARRAY OF CHAR; VAR pDevModeOutput: DeviceModeA; VAR pDevModeInput: DeviceModeA; fMode: LONGINT): LONGINT;
	(*END DocumentPropertiesA;*)
	TextOut-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nXStart, nYStart: LONGINT;  CONST lpString: ARRAY   OF CHAR;  cbString: LONGINT): Kernel32.BOOL;

	GetProfileString-: PROCEDURE {WINAPI} ( CONST lpAppName: ARRAY OF CHAR;
																			CONST lpKeyName: ARRAY OF CHAR;
																			CONST lpDefault: ARRAY OF CHAR;
																			CONST lpReturnedString: ARRAY OF CHAR;
																			nSize: LONGINT): LONGINT;

	(** The GlobalAlloc function allocates the specified number of bytes from the heap. *)
	GlobalFree-: PROCEDURE {WINAPI} (dwBytes: LONGINT ): LONGINT;

VAR
	mod1,mod2:LONGINT;

PROCEDURE Cleanup;
BEGIN
	IF mod1 # Kernel32.NULL THEN
		Kernel32.FreeLibrary(mod1); mod1 := Kernel32.NULL
	END;
	IF mod2 # Kernel32.NULL THEN
		Kernel32.FreeLibrary(mod2); mod2 := Kernel32.NULL
	END
END Cleanup;

PROCEDURE Init*():BOOLEAN;
BEGIN
	mod1 := Kernel32.LoadLibrary(winspl);
	Kernel32.GetProcAddress(mod1, "EnumPrintersA", SYSTEM.VAL(ADDRESS, EnumPrinters));
	Kernel32.GetProcAddress(mod1, "OpenPrinterA", SYSTEM.VAL(ADDRESS, OpenPrinter));
	Kernel32.GetProcAddress(mod1, "DocumentPropertiesA", SYSTEM.VAL(ADDRESS, DocumentProperties));

	mod2 := Kernel32.LoadLibrary(kernel32);
	Kernel32.GetProcAddress(mod2, "GetProfileStringA", SYSTEM.VAL(ADDRESS, GetProfileString));
	Kernel32.GetProcAddress(mod2, "GlobalFree", SYSTEM.VAL(ADDRESS, GlobalFree));

	RETURN (mod1 # Kernel32.NULL)&(mod2 # Kernel32.NULL);
END Init;

PROCEDURE Test*;
VAR
 p:Printer;
 title:String;
 c:Canvas;
BEGIN
	NEW(title,255);
	title^:="WinAos fist printed document!";
	KernelLog.String("Get Default printer: "); KernelLog.Ln; 
	NEW(p);
	p.title:=title;
	p.SetToDefaultPrinter();
	p.BeginDoc();
	NEW(c,p.DC);
	c.SetWinFont("Times New Roman",32*10);
	c.DrawString(300,300,"Hello World!");
	c.Ellipse();
	p.NewPage();
	p.NewPage();
	p.EndDoc();
END Test;


BEGIN
	IF Init() THEN
		Modules.InstallTermHandler(Cleanup);
	ELSE
		KernelLog.String("Init failed."); KernelLog.Ln; 
	END;
END WMPrinter.

WMPrinter.Test~