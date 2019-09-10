MODULE UsbVideoDesc; (** AUTHOR "Timothée Martiel, 2015"; PURPOSE "USB Video Class standard descriptors"; *)

IMPORT SYSTEM, KernelLog, Usbdi;

CONST
	(* Video-class specific descriptor codes *)
	Device *			= 21H;
	Configuration *	= 22H;
	String *			= 23H;
	Interface *		= 24H;
	Endpoint *		= 25H;

	(* Video-class specific descriptor subtypes for VideoControl Interface *)
	VCHeader *				= 01H;
	VCInputTerminal *		= 02H;
	VCOutputTerminal *		= 03H;
	VCSelectorUnit *			= 04H;
	VCProcessingUnit *		= 05H;
	VCExtensionUnit *		= 06H;
	VCEncodingUnit *		= 07H;

	(* Video-class specific descriptor subtypes for VideoStreaming Interface *)
	VSInputHeader *				= 01H;
	VSOutputHeader *			= 02H;
	VSStillImageFrame *			= 03H;
	VSFormatUncompressed *	= 04H;
	VSFrameUncompressed *	= 05H;
	VSFormatMjpeg *			= 06H;
	VSFrameMjpeg *				= 07H;
	VSFormatMpeg2ts *			= 0AH;
	VSFormatDv *				= 0CH;
	VSColorFormat *				= 0DH;
	VSFormatFrameBased *		= 10H;
	VSFrameFrameBased *		= 11H;
	VSFormatStreamBased *		= 12H;
	VSFormatH264 *				= 13H;
	VSFrameH264 *				= 14H;
	VSFormatH264Simulcast *	= 15H;
	VSFormatVp8 *				= 16H;
	VSFrameVp8 *				= 17H;
	VSFormatVp8Simulcast *	= 18H;

	(* Video-class specific descriptor subtypes for Endpoints *)
	EGeneral *	= 01H;
	EEndpoint *	= 02H;
	EInterrupt *	= 03H;

	(*= Terminal types =*)
	(* Generic *)
	TypeVendorSpecific *				= 100H;
	TypeStreaming *						= 101H;
	(* Input *)
	TypeInVendorSpecific *				= 200H;
	TypeInCamera *						= 201H;
	TypeInMediaTransportInput *		= 202H;
	(* Output *)
	TypeOutVendorSpecific *			= 300H;
	TypeOutDisplay *					= 301H;
	TypeOutMediaTransportOutput *	= 302H;

TYPE
	(*===== Video Class Specific Interfaces =====*)
	VideoControlDesc * = POINTER TO RECORD
		bcdUVC *: SIGNED32;
		wTotalLength *: SIGNED32;
		dwClockFrequency *: SIGNED32;
		bInCollection *: SIGNED32;
		baInterfaceNr *: POINTER TO ARRAY OF SIGNED32;
	END;

	Unit * = OBJECT
	VAR
		bUnitID *: SIGNED32;

		PROCEDURE Resolve * (CONST cache: ARRAY OF Unit);
		BEGIN HALT(210)
		END Resolve;
	END Unit;

	InputTerminalDesc * = OBJECT (Unit)
	VAR
		wTerminalType *: SIGNED32;
		bAssocTerminal *: SIGNED32;
		iTerminal *: SIGNED32;

		assocTerminal *: OutputTerminalDesc;

		PROCEDURE Resolve * (CONST cache: ARRAY OF Unit);
		BEGIN
			IF bAssocTerminal # 0 THEN
				ASSERT(cache[bAssocTerminal - 1] # NIL);
				ASSERT(cache[bAssocTerminal - 1] IS OutputTerminalDesc);
				assocTerminal := cache[bAssocTerminal - 1](OutputTerminalDesc)
				;TRACE(assocTerminal)
			END;
		END Resolve;
	END InputTerminalDesc;

	CameraTerminalDesc * = OBJECT (InputTerminalDesc)
	VAR
		wObjectiveFocalLengthMin *: SIGNED32;
		wObjectiveFocalLengthMax *: SIGNED32;
		wOcularFocalLength *: SIGNED32;
		bControlSize *: SIGNED32;
		bmControls *: SET;
	END CameraTerminalDesc;

	OutputTerminalDesc * = OBJECT (Unit)
	VAR
		wTerminalType *: SIGNED32;
		bAssocTerminal *: SIGNED32;
		bSourceID *: SIGNED32;
		iTerminal *: SIGNED32;

		assocTerminal *: InputTerminalDesc;
		source *: Unit;

		PROCEDURE Resolve * (CONST cache: ARRAY OF Unit);
		BEGIN
			IF bAssocTerminal # 0 THEN
				ASSERT(cache[bAssocTerminal - 1] # NIL);
				ASSERT(cache[bAssocTerminal - 1] IS InputTerminalDesc);
				assocTerminal := cache[bAssocTerminal - 1](InputTerminalDesc)
				;TRACE(assocTerminal)
			END;
			ASSERT(cache[bSourceID - 1] # NIL);
			source := cache[bSourceID - 1]
			;TRACE(source)
		END Resolve;
	END OutputTerminalDesc;

	SelectorUnitDesc * = OBJECT (Unit)
		(*! TODO *)
	END SelectorUnitDesc;

	ProcessingUnitDesc * = OBJECT (Unit)
	VAR
		bSourceID *: SIGNED32;
		wMaxMultiplier *: SIGNED32;
		bControlSize *: SIGNED32;
		bmControls *: SET;
		iProcessing *: SIGNED32;
		bmVideoStandards *: SET;

		source *: Unit;

		PROCEDURE Resolve * (CONST cache: ARRAY OF Unit);
		BEGIN
			ASSERT(cache[bSourceID - 1] # NIL);
			source := cache[bSourceID - 1]
			;TRACE(source)
		END Resolve;
	END ProcessingUnitDesc;

	EncodingUnitDesc * = OBJECT (Unit)
		(*! TODO *)
	END EncodingUnitDesc;

	ExtensionUnitDesc * = OBJECT (Unit)
	VAR
		guidExtensionCode *: ARRAY 16 OF CHAR;
		bNumControls *: SIGNED32;
		bNrInPins *: SIGNED32;
		baSourceID *: POINTER TO ARRAY OF SIGNED32;
		bControlSize *: SIGNED32;
		bmControls *: SET;
		iExtension *: SIGNED32;

		sources *: POINTER TO ARRAY OF Unit;

		PROCEDURE Resolve * (CONST cache: ARRAY OF Unit);
		VAR
			i: SIGNED32;
		BEGIN
			NEW(sources, bNrInPins);
			FOR i := 0 TO bNrInPins - 1 DO
				ASSERT(cache[baSourceID[i] - 1] # NIL);
				sources[i] := cache[baSourceID[i] - 1]
				;TRACE(i, sources[i])
			END
		END Resolve;
	END ExtensionUnitDesc;

	InterruptEndpointDesc * = POINTER TO RECORD
		bEndpointAddress *: SIGNED32;
		bmAttributes *: SET;
		wMaxPacketSize *: SIGNED32;
		bInterval *: SIGNED32;
	END;

	(* Base descriptor. Parsing those is done in a format-specific way. *)
	VSInputHeaderDesc * = POINTER TO RECORD
		bNumFormats *: SIGNED32;
		wTotalLength *: SIGNED32;
		bEndpointAddress *: SIGNED32;
		bmInfo *: SET;
		bTerminalLink *: SIGNED32;
		bStillCaptureMethod *: SIGNED32;
		bTriggerSupport *: SIGNED32;
		bTriggerUsage *: SIGNED32;
		bControlSize *: SIGNED32;
		bmaControls *: POINTER TO ARRAY OF SET;
	END;

	VSFormatDesc * = OBJECT
	VAR
		bFormatIndex *: SIGNED32;
		bNumFrameDescriptors *: SIGNED32;
		frames *: POINTER TO ARRAY OF VSFrameDesc;

		(** Abstract printing method for debug *)
		PROCEDURE Print *;
		BEGIN HALT(210)
		END Print;
	END VSFormatDesc;

	VSFormatUncompressedDesc * = OBJECT (VSFormatDesc)
	VAR
		guidFormat *: ARRAY 16 OF CHAR;
		bBitsPerPixel *: SIGNED32;
		bDefaultFrameIndex *: SIGNED32;
		bAspectRatioX *: SIGNED32;
		bAspectRatioY *: SIGNED32;
		bmInterlaceFlags *: SET;
		bCopyProtect *: BOOLEAN;

		PROCEDURE Print *;
		VAR
			i: SIGNED32;
		BEGIN
			KernelLog.String("= VideoStream Uncompressed Format Descriptor ="); KernelLog.Ln;
			KernelLog.String("	format idx:			"); KernelLog.Int(bFormatIndex, 0); KernelLog.Ln;
			KernelLog.String("	# frame desc:		"); KernelLog.Int(bNumFrameDescriptors, 0); KernelLog.Ln;
			KernelLog.String("	guid format:"); KernelLog.Ln;
			(*FOR i := 0 TO 15 DO KernelLog.Hex(ORD(guidFormat[i]), -2); KernelLog.String("	") END;*)
			KernelLog.Buffer(guidFormat, 0, 16);
			KernelLog.String("	bit/pixel:			"); KernelLog.Int(bBitsPerPixel, 0); KernelLog.Ln;
			KernelLog.String("	aspect ratio X:	"); KernelLog.Int(bAspectRatioX, 0); KernelLog.Ln;
			KernelLog.String("	aspect ratio Y:	"); KernelLog.Int(bAspectRatioY, 0); KernelLog.Ln;
			KernelLog.String("	interlace flags:	"); KernelLog.Set(bmInterlaceFlags); KernelLog.Ln;
			KernelLog.String("	copy protect:		"); KernelLog.Boolean(bCopyProtect); KernelLog.Ln
		END Print;
	END VSFormatUncompressedDesc;

	VSFormatMjpegDesc * = OBJECT (VSFormatDesc)
	VAR
		bmFlags *: SET;
		bDefaultFrameIndex *: SIGNED32;
		bAspectRatioX *: SIGNED32;
		bAspectRatioY *: SIGNED32;
		bmInterlaceFlags *: SET;
		bCopyProtect *: BOOLEAN;

		PROCEDURE Print *;
		BEGIN
			KernelLog.String("= VideoStream MJPEG Format Descriptor ="); KernelLog.Ln;
			KernelLog.String("	format idx:			"); KernelLog.Int(bFormatIndex, 0); KernelLog.Ln;
			KernelLog.String("	# frame desc:		"); KernelLog.Int(bNumFrameDescriptors, 0); KernelLog.Ln;
			KernelLog.String("	flags:				"); KernelLog.Set(bmFlags); KernelLog.Ln;
			KernelLog.String("	dflt fr idx:		"); KernelLog.Int(bDefaultFrameIndex, 0); KernelLog.Ln;
			KernelLog.String("	aspect ratio X:	"); KernelLog.Int(bAspectRatioX, 0); KernelLog.Ln;
			KernelLog.String("	aspect ratio Y:	"); KernelLog.Int(bAspectRatioY, 0); KernelLog.Ln;
			KernelLog.String("	interlace flags:	"); KernelLog.Set(bmInterlaceFlags); KernelLog.Ln;
			KernelLog.String("	copy protect:		"); KernelLog.Boolean(bCopyProtect); KernelLog.Ln
		END Print;
	END VSFormatMjpegDesc;

	VSFrameDesc * = OBJECT
	VAR
		bFrameIndex *: SIGNED32;
		format *: VSFormatDesc;

		PROCEDURE Print *;
		BEGIN HALT(210)
		END Print;
	END VSFrameDesc;

	VSFrameUncompressedDesc * = OBJECT (VSFrameDesc)
	VAR
		bmCapabilities *: SET;
		wWidth *: SIGNED32;
		wHeight *: SIGNED32;
		dwMinBitRate *: SIGNED32;
		dwMaxBitRate *: SIGNED32;
		dwMaxVideoFrameBufferSize *: SIGNED32;
		dwDefaultFrameInterval *: SIGNED32;
		bFrameIntervalType *: SIGNED32;

		(* If bFrameIntervalType = 0 *)
		dwMinFrameInterval *: SIGNED32;
		dwMaxFrameInterval *: SIGNED32;
		dwFrameIntervalStep *: SIGNED32;

		(* If bFramIntervalType #0 *)
		dwaFrameInterval *: POINTER TO ARRAY OF SIGNED32;

		PROCEDURE Print *;
		VAR
			i: SIGNED32;
		BEGIN
			KernelLog.String("= VideoStream Uncompressed Frame Descriptor ="); KernelLog.Ln;
			KernelLog.String("	frame index:			"); KernelLog.Int(bFrameIndex, 0); KernelLog.Ln;
			KernelLog.String("	capabilities:			"); KernelLog.Set(bmCapabilities); KernelLog.Ln;
			KernelLog.String("	width:					"); KernelLog.Int(wWidth, 0); KernelLog.Ln;
			KernelLog.String("	height:					"); KernelLog.Int(wHeight, 0); KernelLog.Ln;
			KernelLog.String("	min bit rate:			"); KernelLog.Int(dwMinBitRate, 0); KernelLog.Ln;
			KernelLog.String("	max bit rate:			"); KernelLog.Int(dwMaxBitRate, 0); KernelLog.Ln;
			KernelLog.String("	max frbuf size:		"); KernelLog.Int(dwMaxVideoFrameBufferSize, 0); KernelLog.Ln;
			KernelLog.String("	dflt fr. interval:	"); KernelLog.Int(dwDefaultFrameInterval, 0); KernelLog.Ln;
			KernelLog.String("	fr interval type:		");
			IF bFrameIntervalType = 0 THEN
				KernelLog.String("Continuous");
				KernelLog.String("	min fr interval:	"); KernelLog.Int(dwMinFrameInterval, 0); KernelLog.Ln;
				KernelLog.String("	max fr interval:	"); KernelLog.Int(dwMaxFrameInterval, 0); KernelLog.Ln;
				KernelLog.String("	fr interval step:	"); KernelLog.Int(dwFrameIntervalStep, 0); KernelLog.Ln
			ELSE
				KernelLog.Int(bFrameIntervalType, 0); KernelLog.Ln;
				KernelLog.String("	fr intervals:			");
				FOR i := 0 TO bFrameIntervalType - 1 DO
					KernelLog.Int(dwaFrameInterval[i], 0); KernelLog.String("	")
				END;
				KernelLog.Ln
			END
		END Print;
	END VSFrameUncompressedDesc;

	VSFrameMjpegDesc * = OBJECT (VSFrameDesc)
	VAR
		bmCapabilities *: SET;
		wWidth *,
		wHeight *,
		dwMinBitRate *,
		dwMaxBitRate *,
		dwMaxVideoFrameBufferSize* ,
		dwDefaultFrameInterval *,
		bFrameIntervalType *: SIGNED32;

		(* bFrameIntervalType = 0 *)
		dwMinFrameInterval *,
		dwMaxFrameInterval *,
		dwFrameIntervalStep *: SIGNED32;

		(* bFrameIntervalType # 0 *)
		dwaFrameInterval *: POINTER TO ARRAY OF SIGNED32;

		PROCEDURE Print *;
		VAR
			i: SIGNED32;
		BEGIN
			KernelLog.String("= VideoStream MJPEG Frame Descriptor ="); KernelLog.Ln;
			KernelLog.String("	frame index:			"); KernelLog.Int(bFrameIndex, 0); KernelLog.Ln;
			KernelLog.String("	capabilities:			"); KernelLog.Set(bmCapabilities); KernelLog.Ln;
			KernelLog.String("	width:					"); KernelLog.Int(wWidth, 0); KernelLog.Ln;
			KernelLog.String("	height:					"); KernelLog.Int(wHeight, 0); KernelLog.Ln;
			KernelLog.String("	min bit rate:			"); KernelLog.Int(dwMinBitRate, 0); KernelLog.Ln;
			KernelLog.String("	max bit rate:			"); KernelLog.Int(dwMaxBitRate, 0); KernelLog.Ln;
			KernelLog.String("	max frbuf size:		"); KernelLog.Int(dwMaxVideoFrameBufferSize, 0); KernelLog.Ln;
			KernelLog.String("	dflt fr. interval:	"); KernelLog.Int(dwDefaultFrameInterval, 0); KernelLog.Ln;
			KernelLog.String("	fr interval type:		");
			IF bFrameIntervalType = 0 THEN
				KernelLog.String("Continuous");
				KernelLog.String("	min fr interval:	"); KernelLog.Int(dwMinFrameInterval, 0); KernelLog.Ln;
				KernelLog.String("	max fr interval:	"); KernelLog.Int(dwMaxFrameInterval, 0); KernelLog.Ln;
				KernelLog.String("	fr interval step:	"); KernelLog.Int(dwFrameIntervalStep, 0); KernelLog.Ln
			ELSE
				KernelLog.Int(bFrameIntervalType, 0); KernelLog.Ln;
				KernelLog.String("	fr intervals:			");
				FOR i := 0 TO bFrameIntervalType - 1 DO
					KernelLog.Int(dwaFrameInterval[i], 0); KernelLog.String("	")
				END;
				KernelLog.Ln
			END
		END Print;
	END VSFrameMjpegDesc;

	StillImageDesc * = POINTER TO RECORD
		bEndpointAddress *: SIGNED32;
		bNumImageSizePattern *: SIGNED32;
		waWidth *: POINTER TO ARRAY OF SIGNED32;
		waHeight *: POINTER TO ARRAY OF SIGNED32;
		bNumCompressionPattern *: SIGNED32;
		baCompression *: POINTER TO ARRAY OF SIGNED32;
	END;

	ColorMatchingDesc * = POINTER TO RECORD
		bColorPrimaries *: SIGNED32;
		bTransferCharacteristics *: SIGNED32;
		bMatrixCoefficients *: SIGNED32;
	END;

VAR
	unitCache *: ARRAY 256 OF Unit;

	PROCEDURE ParseVideoControlDesc * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VideoControlDesc;
	VAR
		len, i, n: SIGNED32;
		vc: VideoControlDesc;
	BEGIN
		len := ORD(buffer[pos]); INC(pos);
		(* Check desc type *)
		ASSERT(ORD(buffer[pos]) = Interface); INC(pos);
		(* Chek desc subtype *)
		ASSERT(ORD(buffer[pos]) = VCHeader); INC(pos);
		NEW(vc);
		(* Check standard version *)
		vc.bcdUVC := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H;
		INC(pos, 2);
		(*ASSERT(vc.bcdUVC >= 150H);*)

		vc.wTotalLength := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H;
		INC(pos, 2); (* skip wTotalLength *)
		vc.dwClockFrequency := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H;
		INC(pos, 4); (* skip dwClockFrequency *)
		vc.bInCollection := ORD(buffer[pos]);
		INC(pos);
		NEW(vc.baInterfaceNr, vc.bInCollection);
		FOR i := 0 TO vc.bInCollection - 1 DO
			vc.baInterfaceNr[i] := ORD(buffer[pos]); INC(pos)
		END;
		RETURN vc
	END ParseVideoControlDesc;

	PROCEDURE ClearUnitCache *;
	VAR
		i: SIGNED32;
	BEGIN
		FOR i := 0 TO 255 DO
			unitCache[i] := NIL
		END;
	END ClearUnitCache;

	PROCEDURE ParseUnit * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): Unit;
	VAR
		unit: Unit;
		id, type: SIGNED32;
	BEGIN
		KernelLog.String("Unit length:	"); KernelLog.Int(ORD(buffer[pos]), 0); KernelLog.Ln;
		INC(pos);
		ASSERT(ORD(buffer[pos]) = Interface); INC(pos);
		type := ORD(buffer[pos]); INC(pos);
		id := ORD(buffer[pos]); INC(pos);
		CASE type OF
			 VCInputTerminal: unit := ParseInputTerminalDesc(buffer, pos)
			|VCOutputTerminal: unit := ParseOutputTerminalDesc(buffer, pos)
			|VCProcessingUnit: unit := ParseProcessingUnitDesc(buffer, pos)
			|VCExtensionUnit: unit := ParseExtensionUnitDesc(buffer, pos)
		ELSE
			KernelLog.String("UNSUPPORTED UNIT TYPE");
			RETURN NIL
		END;
		unit.bUnitID := id;
		RETURN unit
	END ParseUnit;

	PROCEDURE ParseInputTerminalDesc * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): InputTerminalDesc;
	VAR
		type: SIGNED32;
		it: InputTerminalDesc;
	BEGIN
		type := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		IF type = TypeInCamera THEN
			it := ParseCameraTerminalDesc(buffer, pos)
		ELSE
			NEW(it);
			it.bAssocTerminal := ORD(buffer[pos]); INC(pos);
			it.iTerminal := ORD(buffer[pos])
		END;
		it.wTerminalType := type;
		RETURN it
	END ParseInputTerminalDesc;

	PROCEDURE ParseOutputTerminalDesc * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): OutputTerminalDesc;
	VAR
		ot: OutputTerminalDesc;
	BEGIN
		NEW(ot);
		ot.wTerminalType := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		ot.bAssocTerminal := ORD(buffer[pos]); INC(pos);
		ot.bSourceID := ORD(buffer[pos]); INC(pos);
		ot.iTerminal := ORD(buffer[pos]);
		RETURN ot
	END ParseOutputTerminalDesc;

	PROCEDURE ParseCameraTerminalDesc * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): CameraTerminalDesc;
	VAR
		c: CameraTerminalDesc;
		i, ctrls: SIGNED32;
	BEGIN
		NEW(c);
		c.wObjectiveFocalLengthMin := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		c.wObjectiveFocalLengthMax := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		c.wOcularFocalLength := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		c.bControlSize := ORD(buffer[pos]); INC(pos);
		FOR i := c.bControlSize - 1 TO 0 BY -1 DO
			ctrls := ctrls * 100H;
			INC(ctrls, ORD(buffer[pos + i]))
		END;
		INC(pos, c.bControlSize);
		c.bmControls := SYSTEM.VAL(SET, ctrls);
		RETURN c
	END ParseCameraTerminalDesc;

	PROCEDURE ParseProcessingUnitDesc * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): ProcessingUnitDesc;
	VAR
		p: ProcessingUnitDesc;
		i, ctrls: SIGNED32;
	BEGIN
		NEW(p);
		TRACE(pos, LEN(buffer));
		p.bSourceID := ORD(buffer[pos]); INC(pos);
		p.wMaxMultiplier := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		p.bControlSize := ORD(buffer[pos]); INC(pos);
		TRACE(pos);
		FOR i := p.bControlSize - 1 TO 0 BY -1 DO
			ctrls := ctrls * 100H;
			INC(ctrls, ORD(buffer[pos + i]))
		END;
		INC(pos, p.bControlSize);
		p.bmControls := SYSTEM.VAL(SET, ctrls);
		TRACE(pos);

		p.iProcessing := ORD(buffer[pos]); INC(pos);
		IF pos < LEN(buffer) THEN
			p.bmVideoStandards := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos)
		ELSE
			KernelLog.String("PROCESSING UNIT IS TOO SMALL")
		END;
		RETURN p
	END ParseProcessingUnitDesc;

	PROCEDURE ParseExtensionUnitDesc * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): ExtensionUnitDesc;
	VAR
		e: ExtensionUnitDesc;
		ctrls, i: SIGNED32;
	BEGIN
		NEW(e);
		FOR i := 0 TO 15 DO
			e.guidExtensionCode[i] := buffer[pos + i]
		END;
		INC(pos, 16);
		e.bNumControls := ORD(buffer[pos]); INC(pos);
		e.bNrInPins := ORD(buffer[pos]); INC(pos);
		NEW(e.baSourceID, e.bNrInPins);
		FOR i := 0 TO e.bNrInPins - 1 DO
			e.baSourceID[i] := ORD(buffer[pos]);
			INC(pos)
		END;
		e.bControlSize := ORD(buffer[pos]); INC(pos);
		FOR i := e.bControlSize - 1 TO 0 BY -1 DO
			ctrls := ctrls * 100H;
			INC(ctrls, ORD(buffer[pos + i]))
		END;
		INC(pos, e.bControlSize);
		e.bmControls := SYSTEM.VAL(SET, ctrls);
		e.iExtension := ORD(buffer[pos]); INC(pos);
		RETURN e
	END ParseExtensionUnitDesc;

	PROCEDURE ParseEndpointDesc * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): InterruptEndpointDesc;
	VAR
		len: SIGNED32;
		d: InterruptEndpointDesc;
	BEGIN
		KernelLog.Buffer(buffer, 0, LEN(buffer));
		len := ORD(buffer[pos]);
		INC(pos);
		IF ORD(buffer[pos]) # Endpoint THEN RETURN NIL END;
		INC(pos);
		NEW(d);
		d.bEndpointAddress := ORD(buffer[pos]); INC(pos);
		d.bmAttributes := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos);
		IF len = 7 THEN
			d.wMaxPacketSize := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
			d.bInterval := ORD(buffer[pos])
		END;
		RETURN d
	END ParseEndpointDesc;

	PROCEDURE ParseVSInputHeader * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSInputHeaderDesc;
	VAR
		hdr: VSInputHeaderDesc;
		i, j, set: SIGNED32;
	BEGIN
		ASSERT(ORD(buffer[pos]) >= 13); INC(pos);
		ASSERT(ORD(buffer[pos]) = Interface); INC(pos);
		ASSERT(ORD(buffer[pos]) = VSInputHeader); INC(pos);

		NEW(hdr);
		hdr.bNumFormats := ORD(buffer[pos]); INC(pos);
		hdr.wTotalLength := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		hdr.bEndpointAddress := ORD(buffer[pos]); INC(pos);
		hdr.bmInfo := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos);
		hdr.bTerminalLink := ORD(buffer[pos]); INC(pos);
		hdr.bStillCaptureMethod := ORD(buffer[pos]); INC(pos);
		hdr.bTriggerSupport := ORD(buffer[pos]); INC(pos);
		hdr.bTriggerUsage := ORD(buffer[pos]); INC(pos);
		hdr.bControlSize := ORD(buffer[pos]); INC(pos);
		NEW(hdr.bmaControls, hdr.bNumFormats);
		FOR i := 0 TO hdr.bNumFormats - 1 DO
			set := 0;
			FOR j := hdr.bControlSize - 1 TO 0 BY -1 DO
				set := set * 100H;
				set := set + ORD(buffer[pos + j])
			END;
			hdr.bmaControls[i] := SYSTEM.VAL(SET, set);
			INC(pos, hdr.bControlSize)
		END;
		RETURN hdr
	END ParseVSInputHeader;

	PROCEDURE ParseVSFormat * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFormatDesc;
	VAR
		parser: PROCEDURE (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFormatDesc;
		format: VSFormatDesc;
		idx, num: SIGNED32;
	BEGIN
		INC(pos);
		ASSERT(ORD(buffer[pos]) = Interface); INC(pos);

		CASE ORD(buffer[pos]) OF
			 VSFormatUncompressed:
				parser := ParseVSFormatUncompressed
			|VSFormatMjpeg:
				parser := ParseVSFormatMjpeg
			|VSFormatMpeg2ts:
				parser := ParseVSFormatMpeg2ts
			|VSFormatH264:
				parser := ParseVSFormatH264
			|VSFormatVp8:
				parser := ParseVSFormatVp8
		ELSE
			KernelLog.String("Unknown Format subtype: "); KernelLog.Int(ORD(buffer[pos]), 0); KernelLog.Ln;
			RETURN NIL
		END;
		INC(pos);
		idx := ORD(buffer[pos]); INC(pos);
		num := ORD(buffer[pos]); INC(pos);

		format := parser(buffer, pos);
	 	format.bFormatIndex := idx;
	 	format.bNumFrameDescriptors := num;
		RETURN format
	END ParseVSFormat;

	PROCEDURE ParseVSFormatUncompressed (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFormatDesc;
	VAR
		f: VSFormatUncompressedDesc;
		i: SIGNED32;
	BEGIN
		NEW(f);
		FOR i := 0 TO 15 DO
			f.guidFormat[i] := buffer[pos + i]
		END;
		INC(pos, 16);
		f.bBitsPerPixel := ORD(buffer[pos]); INC(pos);
		f.bDefaultFrameIndex := ORD(buffer[pos]); INC(pos);
		f.bAspectRatioX := ORD(buffer[pos]); INC(pos);
		f.bAspectRatioY := ORD(buffer[pos]); INC(pos);
		f.bmInterlaceFlags := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos);
		f.bCopyProtect := buffer[pos] = 1X;
		RETURN f
	END ParseVSFormatUncompressed;

	PROCEDURE ParseVSFormatMjpeg (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFormatDesc;
	VAR
		f: VSFormatMjpegDesc;
	BEGIN
		NEW(f);
		f.bmFlags := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos);
		f.bDefaultFrameIndex := ORD(buffer[pos]); INC(pos);
		f.bAspectRatioX := ORD(buffer[pos]); INC(pos);
		f.bAspectRatioY := ORD(buffer[pos]); INC(pos);
		f.bmInterlaceFlags := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos);
		f.bCopyProtect := ORD(buffer[pos]) = 1; INC(pos);
		RETURN f;
	END ParseVSFormatMjpeg;

	PROCEDURE ParseVSFormatMpeg2ts (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFormatDesc;
	BEGIN
		(*! TODO *)
	END ParseVSFormatMpeg2ts;

	PROCEDURE ParseVSFormatH264 (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFormatDesc;
	BEGIN
		(*! TODO *)
	END ParseVSFormatH264;

	PROCEDURE ParseVSFormatVp8 (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFormatDesc;
	BEGIN
		(*! TODO *)
	END ParseVSFormatVp8;

	PROCEDURE ParseVSFrame * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFrameDesc;
	VAR
		parser: PROCEDURE (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFrameDesc;
		frame: VSFrameDesc;
		idx: SIGNED32;
	BEGIN
		INC(pos);
		ASSERT(ORD(buffer[pos]) = Interface); INC(pos);

		CASE ORD(buffer[pos]) OF
			 VSFrameUncompressed:
			 	parser := ParseVSFrameUncompressed
			|VSFrameMjpeg:
				parser := ParseVSFrameMjpeg
			|VSFormatMpeg2ts:
				parser := ParseVSFrameMpeg2ts
			|VSFormatH264:
				parser := ParseVSFrameH264
			|VSFormatVp8:
				parser := ParseVSFrameVp8
		ELSE
			KernelLog.String("Unknown Frame subtype: "); KernelLog.Int(ORD(buffer[pos]), 0); KernelLog.Ln;
			RETURN NIL
		END;
		INC(pos);
		idx := ORD(buffer[pos]); INC(pos);

		frame := parser(buffer, pos);
		frame.bFrameIndex := idx;
		RETURN frame
	END ParseVSFrame;

	PROCEDURE ParseVSFrameUncompressed (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFrameDesc;
	VAR
		f: VSFrameUncompressedDesc;
		i: SIGNED32;
	BEGIN
		NEW(f);
		f.bmCapabilities := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos);
		f.wWidth := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		f.wHeight := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		f.dwMinBitRate := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		f.dwMaxBitRate := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		f.dwMaxVideoFrameBufferSize := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		f.dwDefaultFrameInterval := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		f.bFrameIntervalType := ORD(buffer[pos]); INC(pos);

		IF f.bFrameIntervalType = 0 THEN
			f.dwMinFrameInterval := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
			f.dwMaxFrameInterval := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
			f.dwFrameIntervalStep := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		ELSE
			NEW(f.dwaFrameInterval, f.bFrameIntervalType);
			FOR i := 0 TO f.bFrameIntervalType - 1 DO
				f.dwaFrameInterval[i] := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
			END
		END;
		RETURN f
	END ParseVSFrameUncompressed;
	
	PROCEDURE ParseVSFrameMjpeg (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFrameDesc;
	VAR
		f: VSFrameMjpegDesc;
		i: SIGNED32;
	BEGIN
		NEW(f);
		f.bmCapabilities := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos);
		f.wWidth := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		f.wHeight := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		f.dwMinBitRate := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		f.dwMaxBitRate := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		f.dwMaxVideoFrameBufferSize := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		f.dwDefaultFrameInterval := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		f.bFrameIntervalType := ORD(buffer[pos]); INC(pos);

		IF f.bFrameIntervalType = 0 THEN
			f.dwMinFrameInterval := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
			f.dwMaxFrameInterval := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
			f.dwFrameIntervalStep := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		ELSE
			NEW(f.dwaFrameInterval, f.bFrameIntervalType);
			FOR i := 0 TO f.bFrameIntervalType - 1 DO
				f.dwaFrameInterval[i] := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
			END
		END;
		RETURN f
	END ParseVSFrameMjpeg;
	
	PROCEDURE ParseVSFrameMpeg2ts (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFrameDesc;
	BEGIN
		(*! TODO *)
	END ParseVSFrameMpeg2ts;
	
	PROCEDURE ParseVSFrameH264 (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFrameDesc;
	BEGIN
		(*! TODO *)
	END ParseVSFrameH264;
	
	PROCEDURE ParseVSFrameVp8 (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): VSFrameDesc;
	BEGIN
		(*! TODO *)
	END ParseVSFrameVp8;

	PROCEDURE ParseStillImageDesc * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): StillImageDesc;
	VAR
		s: StillImageDesc;
		i: SIGNED32;
	BEGIN
		TRACE(LEN(buffer), pos);
		ASSERT(ORD(buffer[pos]) > 10); INC(pos);
		ASSERT(ORD(buffer[pos]) = Interface); INC(pos);
		ASSERT(ORD(buffer[pos]) = VSStillImageFrame); INC(pos);

		NEW(s);
		s.bEndpointAddress := ORD(buffer[pos]); INC(pos);
		s.bNumImageSizePattern := ORD(buffer[pos]); INC(pos);
		NEW(s.waWidth, s.bNumImageSizePattern);
		NEW(s.waHeight, s.bNumImageSizePattern);
		FOR i := 0 TO s.bNumImageSizePattern - 1 DO
			s.waWidth[i] := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
			s.waHeight[i] := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2)
		END;
		TRACE(pos);
		s.bNumCompressionPattern := ORD(buffer[pos]); INC(pos);
		TRACE(pos, s.bNumCompressionPattern);
		NEW(s.baCompression, s.bNumCompressionPattern);
		FOR i := 0 TO s.bNumCompressionPattern - 1 DO
			s.baCompression[i] := ORD(buffer[pos + i]);
		END;
		RETURN s
	END ParseStillImageDesc;

	PROCEDURE ParseColorMatchingDesc * (CONST buffer: ARRAY OF CHAR; pos: SIGNED32): ColorMatchingDesc;
	VAR
		c: ColorMatchingDesc;
	BEGIN
		ASSERT(ORD(buffer[pos]) = 6); INC(pos);
		ASSERT(ORD(buffer[pos]) = Interface); INC(pos);
		ASSERT(ORD(buffer[pos]) = VSColorFormat); INC(pos);

		NEW(c);
		c.bColorPrimaries := ORD(buffer[pos]); INC(pos);
		c.bTransferCharacteristics := ORD(buffer[pos]); INC(pos);
		c.bMatrixCoefficients := ORD(buffer[pos]); INC(pos);
		RETURN c
	END ParseColorMatchingDesc;

	PROCEDURE PrintVC * (vc: VideoControlDesc);
	VAR
		i: SIGNED32;
	BEGIN
		KernelLog.String("= VideoControlDesc ="); KernelLog.Ln;
		KernelLog.String("	version:	"); KernelLog.Int(vc.bcdUVC, 0); KernelLog.Ln;
		KernelLog.String("	total len:	"); KernelLog.Int(vc.wTotalLength, 0); KernelLog.Ln;
		KernelLog.String("	clock f.:	"); KernelLog.Int(vc.dwClockFrequency, 0); KernelLog.Ln;
		KernelLog.String("	# of VS:	"); KernelLog.Int(vc.bInCollection, 0); KernelLog.Ln;
		KernelLog.String("	VSs:	");
		FOR i := 0 TO vc.bInCollection - 1 DO
			KernelLog.Int(vc.baInterfaceNr[i], 0); KernelLog.String("	")
		END;
		KernelLog.Ln
	END PrintVC;

	PROCEDURE PrintUnit * (unit: Unit);
	BEGIN
		IF unit = NIL THEN KernelLog.String("= NIL UNIT =")
		ELSIF unit IS CameraTerminalDesc THEN
			PrintCT(unit(CameraTerminalDesc))
		ELSIF unit IS InputTerminalDesc THEN
			PrintIT(unit(InputTerminalDesc))
		ELSIF unit IS OutputTerminalDesc THEN
			PrintOT(unit(OutputTerminalDesc))
		ELSIF unit IS ProcessingUnitDesc THEN
			PrintProcUnit(unit(ProcessingUnitDesc))
		ELSIF unit IS ExtensionUnitDesc THEN
			PrintExtUnit(unit(ExtensionUnitDesc))
		ELSE
			KernelLog.String("= UNKNOWN UNIT ="); KernelLog.Ln;
		END;
	END PrintUnit;

	PROCEDURE PrintIT * (i: InputTerminalDesc);
	BEGIN
		KernelLog.String("= InputTerminalDesc ="); KernelLog.Ln;
		KernelLog.String("	id:		"); KernelLog.Int(i.bUnitID, 0); KernelLog.Ln;
		KernelLog.String("	type:		"); (*KernelLog.Int(i.wTerminalType, 0); KernelLog.Ln;*)
		CASE i.wTerminalType OF
			 TypeVendorSpecific: KernelLog.String("vendor specific")
			|TypeStreaming: KernelLog.String("streaming")
			|TypeInVendorSpecific: KernelLog.String("vendor specific input")
			|TypeInCamera: KernelLog.String("camera")
			|TypeInMediaTransportInput: KernelLog.String("media transport input")
		ELSE
			KernelLog.String("uknown "); KernelLog.Int(i.wTerminalType, 0)
		END;
		KernelLog.Ln;
		KernelLog.String("	assoc:	"); KernelLog.Int(i.bAssocTerminal, 0); KernelLog.Ln;
		KernelLog.String("	str:		"); KernelLog.Int(i.iTerminal, 0); KernelLog.Ln;
	END PrintIT;

	PROCEDURE PrintCT * (c: CameraTerminalDesc);
	BEGIN
		PrintIT(c);
		KernelLog.String("	obj min focal:	"); KernelLog.Int(c.wObjectiveFocalLengthMin, 0); KernelLog.Ln;
		KernelLog.String("	obj max focal:	"); KernelLog.Int(c.wObjectiveFocalLengthMax, 0); KernelLog.Ln;
		KernelLog.String("	ocular min:		"); KernelLog.Int(c.wOcularFocalLength, 0); KernelLog.Ln;
		KernelLog.String("	ctrl len:		"); KernelLog.Int(c.bControlSize, 0); KernelLog.Ln;
		KernelLog.String("	ctrls:		"); KernelLog.Set(c.bmControls); KernelLog.Ln
	END PrintCT;

	PROCEDURE PrintOT * (o: OutputTerminalDesc);
	BEGIN
		KernelLog.String("= OutputTerminalDesc ="); KernelLog.Ln;
		KernelLog.String("	id:		"); KernelLog.Int(o.bUnitID, 0); KernelLog.Ln;
		KernelLog.String("	type:		");
		CASE o.wTerminalType OF
			 TypeVendorSpecific: KernelLog.String("vendor specific")
			|TypeStreaming: KernelLog.String("streaming")
			|TypeOutVendorSpecific: KernelLog.String("vendor specific output")
			|TypeOutDisplay: KernelLog.String("display")
			|TypeOutMediaTransportOutput: KernelLog.String("media transport output")
		ELSE
			KernelLog.String("uknown "); KernelLog.Int(o.wTerminalType, 0)
		END;
		KernelLog.Ln;
		KernelLog.String("	assoc:	"); KernelLog.Int(o.bAssocTerminal, 0); KernelLog.Ln;
		KernelLog.String("	source:	"); KernelLog.Int(o.bSourceID, 0); KernelLog.Ln;
		KernelLog.String("	str:		"); KernelLog.Int(o.iTerminal, 0); KernelLog.Ln;
	END PrintOT;

	PROCEDURE PrintProcUnit * (p: ProcessingUnitDesc);
	BEGIN
		KernelLog.String("= ProcessingUnitDesc ="); KernelLog.Ln;
		KernelLog.String("	id:			"); KernelLog.Int(p.bUnitID, 0); KernelLog.Ln;
		KernelLog.String("	src:			"); KernelLog.Int(p.bSourceID, 0); KernelLog.Ln;
		KernelLog.String("	max mult:	"); KernelLog.Int(p.wMaxMultiplier, 0); KernelLog.Ln;
		KernelLog.String("	ctrl len:	"); KernelLog.Int(p.bControlSize, 0); KernelLog.Ln;
		KernelLog.String("	ctrls:		"); KernelLog.Set(p.bmControls); KernelLog.Ln;
		KernelLog.String("	str:			"); KernelLog.Int(p.iProcessing, 0); KernelLog.Ln;
		KernelLog.String("	video stds:	"); KernelLog.Set(p.bmVideoStandards); KernelLog.Ln;
	END PrintProcUnit;

	PROCEDURE PrintExtUnit * (e: ExtensionUnitDesc);
	VAR
		i: SIGNED32;
	BEGIN
		KernelLog.String("= ExtensionUnitDesc ="); KernelLog.Ln;
		KernelLog.String("	id:			"); KernelLog.Int(e.bUnitID, 0); KernelLog.Ln;
		KernelLog.String("	ext code:	");
		FOR i := 0 TO 15 DO KernelLog.Hex(ORD(e.guidExtensionCode[i]), -2); KernelLog.String(' ') END;
		KernelLog.Ln;
		KernelLog.String("	# ctrls:		"); KernelLog.Int(e.bNumControls, 0); KernelLog.Ln;
		KernelLog.String("	# src:		"); KernelLog.Int(e.bNrInPins, 0); KernelLog.Ln;
		KernelLog.String("	srcs:			");
		FOR i := 0 TO e.bNrInPins - 1 DO
			KernelLog.Int(e.baSourceID[i], 0); KernelLog.String("	")
		END;
		KernelLog.Ln;
		KernelLog.String("	ctrl len:	"); KernelLog.Int(e.bControlSize, 0); KernelLog.Ln;
		KernelLog.String("	ctrls:		"); KernelLog.Set(e.bmControls); KernelLog.Ln;
		KernelLog.String("	str:			"); KernelLog.Int(e.iExtension, 0); KernelLog.Ln;
	END PrintExtUnit;

	PROCEDURE PrintEndpoint * (e: InterruptEndpointDesc);
	BEGIN
		KernelLog.String("= InterruptEndpointDesc ="); KernelLog.Ln;
		KernelLog.String("	address:			"); KernelLog.Int(e.bEndpointAddress, 0); KernelLog.Ln;
		KernelLog.String("	attributes:		"); KernelLog.Set(e.bmAttributes); KernelLog.Ln;
		KernelLog.String("	packet size:	"); KernelLog.Int(e.wMaxPacketSize, 0); KernelLog.Ln;
		KernelLog.String("	interval:		"); KernelLog.Int(e.bInterval, 0); KernelLog.Ln
	END PrintEndpoint;

	PROCEDURE PrintVSInputHeader * (hdr: VSInputHeaderDesc);
	VAR
		i: SIGNED32;
	BEGIN
		KernelLog.String("= VideoStreaming InputHeaderDesc ="); KernelLog.Ln;
		KernelLog.String("	# formats:					"); KernelLog.Int(hdr.bNumFormats, 0); KernelLog.Ln;
		KernelLog.String("	length:						"); KernelLog.Int(hdr.wTotalLength, 0); KernelLog.Ln;
		KernelLog.String("	ep adr:						"); KernelLog.Int(hdr.bEndpointAddress, 0); KernelLog.Ln;
		KernelLog.String("	info:							"); KernelLog.Set(hdr.bmInfo); KernelLog.Ln;
		KernelLog.String("	term. lnk:					"); KernelLog.Int(hdr.bTerminalLink, 0); KernelLog.Ln;
		KernelLog.String("	still capture method:	"); KernelLog.Int(hdr.bStillCaptureMethod, 0); KernelLog.Ln;
		KernelLog.String("	trigger support:			"); KernelLog.Int(hdr.bTriggerSupport, 0); KernelLog.Ln;
		KernelLog.String("	trigger usage:				"); KernelLog.Int(hdr.bTriggerUsage, 0); KernelLog.Ln;
		KernelLog.String("	control size:				"); KernelLog.Int(hdr.bControlSize, 0); KernelLog.Ln;
		KernelLog.String("	controls:					");
		FOR i := 0 TO hdr.bNumFormats - 1 DO KernelLog.Set(hdr.bmaControls[i]); KernelLog.String("	") END;
		KernelLog.Ln
	END PrintVSInputHeader;

	PROCEDURE PrintStillImageDesc * (s: StillImageDesc);
	VAR
		i: SIGNED32;
	BEGIN
		KernelLog.String("= VideoStreaming Still Image Descriptor ="); KernelLog.Ln;
		KernelLog.String("	endpoint adr:			"); KernelLog.Int(s.bEndpointAddress, 0); KernelLog.Ln;
		KernelLog.String("	# im size pattern:	"); KernelLog.Int(s.bNumImageSizePattern, 0); KernelLog.Ln;
		KernelLog.String("	im size patterns:		");
		FOR i := 0 TO s.bNumImageSizePattern - 1 DO
			KernelLog.Int(s.waWidth[i], 0); KernelLog.String('x'); KernelLog.Int(s.waHeight[i], 0); KernelLog.String("	");
		END;
		KernelLog.Ln;
		KernelLog.String("	# comp. pattern:		"); KernelLog.Int(s.bNumCompressionPattern, 0); KernelLog.Ln;
		KernelLog.String("	comp. patterns:	");
		FOR i := 0 TO s.bNumCompressionPattern - 1 DO
			KernelLog.Int(s.baCompression[i], 0); KernelLog.String("	")
		END;
		KernelLog.Ln
	END PrintStillImageDesc;

	PROCEDURE PrintColorMatchingDesc * (c: ColorMatchingDesc);
	BEGIN
		KernelLog.String("= VideoStreaming Color Matching Desc ="); KernelLog.Ln;
		KernelLog.String("	color primaries:	"); KernelLog.Int(c.bColorPrimaries, 0); KernelLog.Ln;
		KernelLog.String("	tranfer charac.:	"); KernelLog.Int(c.bTransferCharacteristics, 0); KernelLog.Ln;
		KernelLog.String("	matrix coefs.:	"); KernelLog.Int(c.bMatrixCoefficients, 0); KernelLog.Ln;
	END PrintColorMatchingDesc;
END UsbVideoDesc.
