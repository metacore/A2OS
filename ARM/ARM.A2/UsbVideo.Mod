MODULE UsbVideo; (** AUTHOR "Timothée Martiel, 2015"; PURPOSE "USB video device driver"; *)

IMPORT SYSTEM, Commands, Modules, Objects, Kernel, Plugins, Streams, Files, Usbdi, UsbHcdi, Usb, UsbVideoDesc, KernelLog;

CONST
	(*! REMOVE AFTER DEBUG *)
	Size =120 * 160 * 2;
	(*! END REMOVE AFTER DEBUG *)


	Name			= "Video Class";
	Description	= "USB Video Class driver";
	Priority			= 10;

	ProbeLength = 48;

	(* Video-class specific request codes *)
	SetCur		= 01H;
	SetCurAll	= 11H;
	GetCur		= 81H;
	GetMin		= 82H;
	GetMax	= 83H;
	GetRes		= 84H;
	GetLen		= 85H;
	GetInfo		= 86H;
	GetDef		= 87H;
	GetCurAll	= 91H;
	GetMinAll	= 92H;
	GetMaxAll	= 93H;
	GetResAll	= 94H;
	GetDefAll	= 97H;

	(* VideoControl interface specific request codes *)
	VCVideoPowerModeCtl *	= 01H;
	VCRequestErrorCodeCtl *	= 02H;

	(* Selector Unit specific request codes *)
	SUInpueSelectCtl *	= 01H;

	(* Camera Terminal specific request codes *)
	CTScanningModeCtl *				= 01H;
	CTAeModeCtl *					= 02H;
	CTAePriorityCtl *					= 03H;
	CTExposureTimeAbsoluteCtl *	= 04H;
	CTExposureTimeRelativeCtl *		= 05H;
	CTFocusAbsoluteCtl *				= 06H;
	CTFocusRelativeCtl *				= 07H;
	CTFocusAutoCtl *					= 08H;
	CTIrisAbsoluteCtl *				= 09H;
	CTIrisRelativeCtl *					= 0AH;
	CTZoomAbsoluteCtl *				= 0BH;
	CTZoomRelativeCtl *				= 0CH;
	CTPantiltAbsoluteCtl *				= 0DH;
	CTPantiltRelativeCtl *				= 0EH;
	CTRollAbsoluteCtl *				= 0FH;
	CTRollRelativeCtl *					= 10H;
	CTPrivacyCtl *						= 11H;
	CTFocusSimpleCtl *				= 12H;
	CTWindowCtl *					= 13H;
	CTRegionOfInterestCtl *			= 14H;

	(* Processing Unit specific request codes *)
	PUBacklightCompensationCtl *			= 01H;
	PUBrightnessCtl *							= 02H;
	PUContrastCtl *							= 03H;
	PUGainCtl *								= 04H;
	PUPowerLineFrequencyCtl *				= 05H;
	PUHueCtl *								= 06H;
	PUSaturationCtl *							= 07H;
	PUSharpnessCtl *							= 08H;
	PUGammaCtl *							= 09H;
	PUWhiteBalanceTemperatureCtl *		= 0AH;
	PUWhiteBalanceTemperatureAutoCtl *	= 0BH;
	PUWhiteBalanceComponentCtl *			= 0CH;
	PUWhiteBalanceComponentAutoCtl *	= 0DH;
	PUDigitalMultiplierCtl *					= 0EH;
	PUDigitalMultiplierLimitCtl *				= 0FH;
	PUHueAutoCtl *							= 10H;
	PUAnalogVideoStandardCtl *				= 11H;
	PUAnalogLockStatusCtl *					= 12H;
	PUContrastAutoCtl *						= 13H;

	(* Encoding Unit specific request codes *)
	EnUSelectLayerCtl *			= 01H;
	EnUProfileToolsetCtl *			= 02H;
	EnUVideoResolutionCtl *		= 03H;
	EnUMinFrameIntervalCtl *		= 04H;
	EnUSliceModeCtl *			= 05H;
	EnURateControlModeCtl *	= 06H;
	EnUAverageBitrateCtl *		= 07H;
	EnUCPBSizeCtl *				= 08H;
	EnUPeakBitRateCtl *			= 09H;
	EnUQuantizationParamsCtl *	= 0AH;
	EnUSyncRefFrameCtl *		= 0BH;
	EnULTRBufferCtl *				= 0CH;
	EnULTRPictureCtl *			= 0DH;
	EnULTRValidationCtl *		= 0EH;
	EnULevelIDCLimitCtl *			= 0FH;
	EnUSeiPayloadTypeCtl *		= 10H;
	EnUQpRangeCtl *				= 11H;
	EnUPriorityCtl *				= 12H;
	EnUStartOrStopLayerCtl *		= 13H;
	EnUErrorResiliencyCtl *		= 14H;

	(* VideoStreaming Interface specific request codes *)
	VSProbeCtl *					= 1;
	VSCommitCtl *				= 2;
	VSStillProbeCtl *				= 3;
	VSStillCommitCtl *			= 4;
	VSStillImageTriggerCtl *		= 5;
	VSStreamErrorCodeCtl *		= 6;
	VSGenerateKeyFrameCtl *		= 7;
	VSUpdateFrameSegmentCtl *	= 8;
	VSSynchDelayCtl *				= 9;

	(* Request Types *)
	SetControlRequest = {5, 0};
	GetControlRequest = {7, 5, 0};
	SetStreamingRequest = {5, 1};
	GetStreamingRequest = {7, 5, 1};

	(* Request Error Codes *)
	NoError *						= 000H;
	NotReady *					= 001H;
	WrongState *					= 002H;
	Power *						= 003H;
	OutOfRange *					= 004H;
	InvalidUnit *					= 005H;
	InvalidControl *				= 006H;
	InvalidRequest *				= 007H;
	InvalidValueWithinRange *	= 008H;
	Unknown *					= 0FFH;

	(* Probe commit mechanism *)
	Negotiate * = 0;

TYPE
	ProbeCommitCtl * = RECORD
		bmHint *: SET;
		bFormatIndex *,
		bFrameIndex *,
		dwFrameInterval *,
		wKeyFrameRate *,
		wPFrameRate *,
		wCompQuality *,
		wCompWindowSize *,
		wDelay *,
		dwMaxVideoFrameSize *,
		dwMaxPayloadTransferSize *,
		dwClockFrequency *: SIGNED32;
		bmFramingInfo *: SET;
		bPreferedVersion *,
		bMinVersion *,
		bMaxVersion *,
		bUsage *,
		bBitDepthLuma *: SIGNED32;
		bmSettings *: SET;
		bMaxNumberOfRefFramesPlus1 *: SIGNED32;
		bmRateControlModes *: SET;
		bmLayoutPerStream *: ARRAY 2 OF SET;
	END;

	Header = RECORD
		pt, scr: SIGNED32;
		id, eof, psb, still, error, eoh: BOOLEAN;
		ptPresent, scrPresent: BOOLEAN;
	END;

	(** USB device drivers for video functions. *)
	VideoDriver * = OBJECT (Usbdi.Driver)
	VAR
		controlPipe, interruptPipe: Usbdi.Pipe;
		controlInterface: Usbdi.InterfaceDescriptor;
		control: UsbVideoDesc.VideoControlDesc;
		topology -: POINTER TO ARRAY OF UsbVideoDesc.Unit;
		streamingDrivers: POINTER TO ARRAY OF StreamingDriver;
		status -: Usbdi.Status;
		getError: BOOLEAN;

		PROCEDURE Connect * (): BOOLEAN;
		BEGIN
			RETURN TRUE
		END Connect;

		PROCEDURE Disconnect *;
		END Disconnect;

		(* Send a control request to 'unit' (interface if unit = 0) to do a 'type' operationon the control seclector 'selector'. It uses buffer and len
		 * to do the transfer. *)
		PROCEDURE ControlRequest * (type, selector, unit: SIGNED32; VAR buffer: ARRAY OF CHAR; len: SIGNED32);
		VAR
			requestType: SET;
			request, value, index: SIGNED32;
			error: ARRAY 1 OF CHAR;
		BEGIN
			IF unit = 0 THEN
				(* Interface request *)
				KernelLog.String("Sending video interface request"); KernelLog.Ln;
				IF (selector # VCVideoPowerModeCtl) & (selector # VCRequestErrorCodeCtl) THEN
					ASSERT(unit # 0)
				END;
				value := selector * 100H;
				(*index := controlInterface.bInterfaceNumber;*)
			ELSE
				(* Unit request *)
				KernelLog.String("Sending video unit request"); KernelLog.Ln;
				IF (type = SetCurAll) OR (type >= GetCurAll) THEN
					index := unit;
				ELSE
					value := selector * 100H;
					index := unit * 100H (*+ controlInterface.bInterfaceNumber*)
				END
			END;

			request := type;
			CASE type OF
				 SetCur, SetCurAll:
				 	requestType := SetControlRequest
				|GetCur, GetMin, GetMax, GetRes, GetLen, GetInfo, GetDef,
						GetCurAll, GetMinAll, GetMaxAll, GetResAll, GetDefAll:
					requestType := GetControlRequest
			END;
			TRACE(type, selector, unit, controlInterface.bInterfaceNumber);
			TRACE(requestType, request, value, index, len);
			status := controlPipe.Request(requestType, request, value, index, len, buffer);
			IF (status = Usbdi.Stalled) & (~getError) THEN
				KernelLog.String("Transfer stalled. Trying to get more info from device"); KernelLog.Ln;
				getError := TRUE;
				ControlRequest(GetCur, VCRequestErrorCodeCtl, 0, error, 1);
				getError := FALSE;
				status := ORD(error[0])
			END
		END ControlRequest;
	END VideoDriver;

	Sample * = POINTER TO RECORD
		next *: Sample;
		data *: POINTER TO ARRAY OF CHAR;
	END;

	(** Abstract streaming driver. Handles format-specific parts of the video driver. *)
	StreamingDriver * = OBJECT (Usbdi.Driver)
	VAR
		controlDriver: VideoDriver;
		videoPipe: Usbdi.Pipe;
		inputHeader -: UsbVideoDesc.VSInputHeaderDesc;
		formats -: POINTER TO ARRAY OF UsbVideoDesc.VSFormatDesc;
		samples: Sample;
		status: SIGNED32;
		stream: BOOLEAN;
		params: POINTER TO ProbeCommitCtl;

		PROCEDURE Pause;
		(*BEGIN {EXCLUSIVE}
			stream := FALSE*)
		END Pause;

		PROCEDURE Resume;
		(*BEGIN {EXCLUSIVE}
			stream := TRUE*)
		END Resume;

		PROCEDURE Connect * (): BOOLEAN;
		BEGIN
			NEW(params);
			params.bmHint := {0};
			params.bFormatIndex := 1;
			params.bFrameIndex := 2;
			params.dwFrameInterval := 333333;
			(*params.dwMaxVideoFrameSize := 640 * 480 * 2; (* bytes *)
			params.bMaxNumberOfRefFramesPlus1 := 1;*)
			(*PrintParams(params^);*)
			sdr.NegotiateStreaming(params^, TRUE);
			PrintParams(params^);

			(* Set Interface 1 *)
			(*IF ~device(Usb.UsbDevice).SetInterface(1, 5) THEN
				KernelLog.String("Could not set interface"); KernelLog.Ln
			END;

			(*NegotiateStreaming(params^, TRUE);
			PrintParams(params^);*)

			videoPipe := device.GetPipe(inputHeader.bEndpointAddress);
			videoPipe.maxPacketSize := 800;
			videoPipe(UsbHcdi.Pipe).mult := 1;*)

			IF inputHeader.wTotalLength = 284 THEN
				(*WHILE ~Kernel.Expired(t) DO END;*)
				(*GetFrame3(Commands.GetContext());*)
				(*Resume*)
			END;

			RETURN TRUE
		END Connect;

		PROCEDURE Disconnect *;
		END Disconnect;

		PROCEDURE Probe (type: SIGNED32; set: BOOLEAN; VAR params: ARRAY 48 OF CHAR);
			VAR
				request: SIGNED32;
		BEGIN
			IF set THEN
				request := SetCur
			ELSE
				request := GetCur
			END;
			ControlRequest(request, type, params, 34);
			KernelLog.String("Probe:	"); KernelLog.Int(status, 0); KernelLog.String("	"); KernelLog.Int(controlDriver.status, 0); KernelLog.Ln
		END Probe;

		PROCEDURE Commit (type: SIGNED32; VAR params: ARRAY 48 OF CHAR);
		BEGIN
			ControlRequest(SetCur, type, params, 34(*48*));
			KernelLog.String("Commit:	"); KernelLog.Int(status, 0); KernelLog.String("	"); KernelLog.Int(controlDriver.status, 0); KernelLog.Ln
		END Commit;

		PROCEDURE NegotiateStreaming (VAR params: ProbeCommitCtl; commit: BOOLEAN);
		VAR
			probeBuf: ARRAY 48 OF CHAR;
		BEGIN
			WriteProbeCommitCtl(probeBuf, 0, params);
			Probe(VSProbeCtl, TRUE, probeBuf);
			Probe(VSProbeCtl, FALSE, probeBuf);
			(* Override max video frame size *)
			(*ReadProbeCommitCtl(probeBuf, 0, params);
			(*IF formats[params.bFormatIndex] IS UsbVideoDesc.VSFormatUncompressedDesc THEN
				(*params.dwMaxVideoFrameRate := formats[params.bFormatIndex].frames[params.bFrameIndex](*UsbVideoDesc.VSFrameUncompressed*).wWidth;
					* formats[params.bFormatIndex].frames[params.bFrameIndex](UsbVideoDesc.VSFrameUncompressed).wHeight
					* formats[params.bFormatIndex](UsbVideoDesc.VSFormatUncompressedDesc).bBitsPerPixel*)
			ELSE*)
			params.dwMaxVideoFrameSize := 120 * 160 * 2;
			(*END;*)
			WriteProbeCommitCtl(probeBuf, 0, params);*)

			IF commit THEN
				Commit(VSCommitCtl,probeBuf)
			END;
			ReadProbeCommitCtl(probeBuf, 0, params);
		END NegotiateStreaming;

		PROCEDURE NegotiateStill (VAR params: ProbeCommitCtl);
		VAR
			probeBuf: ARRAY 48 OF CHAR;
		BEGIN
			WriteProbeCommitCtl(probeBuf, 0, params);
			Probe(VSStillProbeCtl, TRUE, probeBuf);
			(*ReadProbeCommitCtl(probeBuf, 0, params);
			params.dwMaxVideoFrameSize := 120 * 160 * 2;
			WriteProbeCommitCtl(probeBuf, 0, params);*)
			Commit(VSStillCommitCtl,probeBuf);
			ReadProbeCommitCtl(probeBuf, 0, params);
		END NegotiateStill;

		(** Send a control request to the streaming interface. *)
		PROCEDURE ControlRequest * (type, selector: SIGNED32; VAR buffer: ARRAY OF CHAR; len: SIGNED32);
		VAR
			requestType: SET;
			request, value, index: SIGNED32;
			error: ARRAY 1 OF CHAR;
		BEGIN
			(* Interface request *)
			KernelLog.String("Sending video interface request"); KernelLog.Ln;
			value := selector * 100H;
			index := 1;

			request := type;
			CASE type OF
				 SetCur, SetCurAll:
				 	requestType := SetControlRequest
				|GetCur, GetMin, GetMax, GetRes, GetLen, GetInfo, GetDef,
						GetCurAll, GetMinAll, GetMaxAll, GetResAll, GetDefAll:
					requestType := GetControlRequest
			END;
			status := controlDriver.controlPipe.Request(requestType, request, value, index, len, buffer);
			IF status = Usbdi.Stalled THEN
				KernelLog.String("VS Control Transfer stalled. Trying to get more info from device"); KernelLog.Ln;
				ControlRequest(GetCur, VCRequestErrorCodeCtl, error, 1);
				status := ORD(error[0])
			END;
		END ControlRequest;

		(** Provides a stream for reading video or still images in the selected format *)
		PROCEDURE Receive * (VAR buf: ARRAY OF CHAR;  ofs, size, min: SIGNED32;  VAR len, res: SIGNED32);
		VAR
			i: SIGNED32;
		BEGIN {EXCLUSIVE}
			len := 0;
			WHILE (samples # NIL) & (len < size) DO
				FOR i := 0 TO LEN(samples.data) - 1 DO
					buf[ofs + i] := samples.data[i]
				END;
				INC(ofs, LEN(samples.data));
				INC(len, LEN(samples.data));
				samples := samples.next
			END;
			IF len < min THEN
				res := Streams.EOF
			END
		END Receive;

		PROCEDURE EnqueueSample;
		BEGIN
			HALT(210)
		END EnqueueSample;

	(*BEGIN {ACTIVE}
		LOOP
			BEGIN {EXCLUSIVE}
				AWAIT(stream)
			END;
			SkipFrame
		END;*)
	END StreamingDriver;

VAR
	dr: VideoDriver;
	sdr: StreamingDriver;
	frame: POINTER TO ARRAY OF CHAR;
	buf: ARRAY Size + 13 * 12 OF CHAR;
	headers: ARRAY 20 OF RECORD
		pos, size: SIGNED32
	END;
	t: Kernel.MilliTimer;

	PROCEDURE ReadProbeCommitCtl (CONST buffer: ARRAY OF CHAR; pos: SIGNED32; VAR ctl: ProbeCommitCtl);
	BEGIN
		ASSERT(LEN(buffer) - pos >= 48);
		ctl.bmHint := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos);
		ctl.bFormatIndex := ORD(buffer[pos]); INC(pos);
		ctl.bFrameIndex := ORD(buffer[pos]); INC(pos);
		ctl.dwFrameInterval := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		ctl.wKeyFrameRate := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		ctl.wPFrameRate := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		ctl.wCompQuality := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		ctl.wCompWindowSize := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		ctl.wDelay := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H; INC(pos, 2);
		ctl.dwMaxVideoFrameSize := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		ctl.dwMaxPayloadTransferSize := ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H; INC(pos, 4);
		ctl.bmFramingInfo := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos);
		ctl.bPreferedVersion := ORD(buffer[pos]); INC(pos);
		ctl.bMinVersion := ORD(buffer[pos]); INC(pos);
		ctl.bMaxVersion := ORD(buffer[pos]); INC(pos);
		ctl.bUsage := ORD(buffer[pos]); INC(pos);
		ctl.bBitDepthLuma := ORD(buffer[pos]); INC(pos);
		ctl.bmSettings := SYSTEM.VAL(SET, ORD(buffer[pos])); INC(pos);
		ctl.bMaxNumberOfRefFramesPlus1 := ORD(buffer[pos]); INC(pos);
		ctl.bmRateControlModes := SYSTEM.VAL(SET, ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H); INC(pos, 2);
		ctl.bmLayoutPerStream[0] := SYSTEM.VAL(SET, ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H); INC(pos, 4);
		ctl.bmLayoutPerStream[1] := SYSTEM.VAL(SET, ORD(buffer[pos]) + ORD(buffer[pos + 1]) * 100H + ORD(buffer[pos + 2]) * 10000H + ORD(buffer[pos + 3]) * 1000000H); INC(pos, 4);
	END ReadProbeCommitCtl;

	PROCEDURE WriteProbeCommitCtl (VAR buffer: ARRAY OF CHAR; pos: SIGNED32; CONST ctl: ProbeCommitCtl);
	BEGIN
		ASSERT(LEN(buffer) - pos >= 48);
		buffer[pos] := CHR(SYSTEM.VAL(SIGNED32, ctl.bmHint) MOD 100H); INC(pos);
		buffer[pos] := CHR(ctl.bFormatIndex MOD 100H); INC(pos);
		buffer[pos] := CHR(ctl.bFrameIndex MOD 100H); INC(pos);
		buffer[pos] := CHR(ctl.dwFrameInterval MOD 100H);
		buffer[pos + 1] := CHR((ctl.dwFrameInterval DIV 100H) MOD 100H);
		buffer[pos + 2] := CHR((ctl.dwFrameInterval DIV 10000H) MOD 100H);
		buffer[pos + 3] := CHR((ctl.dwFrameInterval DIV 1000000H) MOD 100H); INC(pos, 4);
		buffer[pos] := CHR(ctl.wKeyFrameRate MOD 100H);
		buffer[pos + 1] := CHR((ctl.wKeyFrameRate DIV 100H) MOD 100H); INC(pos, 2);
		buffer[pos] := CHR(ctl.wPFrameRate MOD 100H);
		buffer[pos + 1] := CHR((ctl.wPFrameRate DIV 100H) MOD 100H); INC(pos, 2);
		buffer[pos] := CHR(ctl.wCompQuality MOD 100H);
		buffer[pos + 1] := CHR((ctl.wCompQuality DIV 100H) MOD 100H); INC(pos, 2);
		buffer[pos] := CHR(ctl.wCompWindowSize MOD 100H);
		buffer[pos + 1] := CHR((ctl.wCompWindowSize DIV 100H) MOD 100H); INC(pos, 2);
		buffer[pos] := CHR(ctl.wDelay MOD 100H);
		buffer[pos + 1] := CHR((ctl.wDelay DIV 100H) MOD 100H); INC(pos, 2);
		buffer[pos] := CHR(ctl.dwMaxVideoFrameSize MOD 100H);
		buffer[pos + 1] := CHR((ctl.dwMaxVideoFrameSize DIV 100H) MOD 100H);
		buffer[pos + 2] := CHR((ctl.dwMaxVideoFrameSize DIV 10000H) MOD 100H);
		buffer[pos + 3] := CHR((ctl.dwMaxVideoFrameSize  DIV 1000000H) MOD 100H); INC(pos, 4);
		buffer[pos] := CHR(ctl.dwMaxPayloadTransferSize MOD 100H);
		buffer[pos + 1] := CHR((ctl.dwMaxPayloadTransferSize DIV 100H) MOD 100H);
		buffer[pos + 2] := CHR((ctl.dwMaxPayloadTransferSize DIV 10000H) MOD 100H);
		buffer[pos + 3] := CHR((ctl.dwMaxPayloadTransferSize  DIV 1000000H) MOD 100H); INC(pos, 4);
		buffer[pos] := CHR(SYSTEM.VAL(SIGNED32, ctl.bmFramingInfo) MOD 100H); INC(pos);
		buffer[pos] := CHR(ctl.bPreferedVersion MOD 100H); INC(pos);
		buffer[pos] := CHR(ctl.bMinVersion MOD 100H); INC(pos);
		buffer[pos] := CHR(ctl.bMaxVersion MOD 100H); INC(pos);
		buffer[pos] := CHR(ctl.bUsage MOD 100H); INC(pos);
		buffer[pos] := CHR(ctl.bBitDepthLuma MOD 100H); INC(pos);
		buffer[pos] := CHR(SYSTEM.VAL(SIGNED32, ctl.bmSettings) MOD 100H); INC(pos);
		buffer[pos] := CHR(ctl.bMaxNumberOfRefFramesPlus1 MOD 100H); INC(pos);
		buffer[pos] := CHR(SYSTEM.VAL(SIGNED32, ctl.bmRateControlModes) MOD 100H);
		buffer[pos + 1] := CHR((SYSTEM.VAL(SIGNED32, ctl.bmRateControlModes) DIV 100H) MOD 100H); INC(pos, 2);
		buffer[pos] := CHR(SYSTEM.VAL(SIGNED32, ctl.bmLayoutPerStream[0]) MOD 100H);
		buffer[pos + 1] := CHR((SYSTEM.VAL(SIGNED32, ctl.bmLayoutPerStream[0]) DIV 100H) MOD 100H);
		buffer[pos + 2] := CHR((SYSTEM.VAL(SIGNED32, ctl.bmLayoutPerStream[0]) DIV 10000H) MOD 100H);
		buffer[pos + 3] := CHR((SYSTEM.VAL(SIGNED32, ctl.bmLayoutPerStream[0]) DIV 1000000H) MOD 100H); INC(pos, 4);
		buffer[pos] := CHR(SYSTEM.VAL(SIGNED32, ctl.bmLayoutPerStream[1]) MOD 100H);
		buffer[pos + 1] := CHR((SYSTEM.VAL(SIGNED32, ctl.bmLayoutPerStream[1]) DIV 100H) MOD 100H);
		buffer[pos + 2] := CHR((SYSTEM.VAL(SIGNED32, ctl.bmLayoutPerStream[1]) DIV 10000H) MOD 100H);
		buffer[pos + 3] := CHR((SYSTEM.VAL(SIGNED32, ctl.bmLayoutPerStream[1]) DIV 1000000H) MOD 100H); INC(pos, 4);
	END WriteProbeCommitCtl;

	PROCEDURE PrintParams (CONST p: ProbeCommitCtl);
	BEGIN
		KernelLog.String("= Probe/Commit Negotiation Parameters ="); KernelLog.Ln;
		KernelLog.String("	hints:					"); KernelLog.Set(p.bmHint); KernelLog.Ln;
		KernelLog.String("	format idx:				"); KernelLog.Int(p.bFormatIndex, 0); KernelLog.Ln;
		KernelLog.String("	frame idx:				"); KernelLog.Int(p.bFrameIndex, 0); KernelLog.Ln;
		KernelLog.String("	frame interval:		"); KernelLog.Int(p.dwFrameInterval, 0); KernelLog.Ln;
		KernelLog.String("	K frame rate:			"); KernelLog.Int(p.wKeyFrameRate, 0); KernelLog.Ln;
		KernelLog.String("	P frame rate:			"); KernelLog.Int(p.wPFrameRate, 0); KernelLog.Ln;
		KernelLog.String("	comp quality:			"); KernelLog.Int(p.wCompQuality, 0); KernelLog.Ln;
		KernelLog.String("	comp window size:		"); KernelLog.Int(p.wCompWindowSize, 0); KernelLog.Ln;
		KernelLog.String("	delay:					"); KernelLog.Int(p.wDelay, 0); KernelLog.Ln;
		KernelLog.String("	max video fr size:	"); KernelLog.Int(p.dwMaxVideoFrameSize, 0); KernelLog.Ln;
		KernelLog.String("	max pld tx size:		"); KernelLog.Int(p.dwMaxPayloadTransferSize, 0); KernelLog.Ln;
		KernelLog.String("	clok frq:				"); KernelLog.Int(p.dwClockFrequency, 0); KernelLog.Ln;
		KernelLog.String("	framing info:			"); KernelLog.Set(p.bmFramingInfo); KernelLog.Ln;
		KernelLog.String("	pref'd version:		"); KernelLog.Int(p.bPreferedVersion, 0); KernelLog.Ln;
		KernelLog.String("	min version:			"); KernelLog.Int(p.bMinVersion, 0); KernelLog.Ln;
		KernelLog.String("	max version:			"); KernelLog.Int(p.bMaxVersion, 0); KernelLog.Ln;
		KernelLog.String("	usage:					"); KernelLog.Int(p.bUsage, 0); KernelLog.Ln;
		KernelLog.String("	bit depth luma:		"); KernelLog.Int(p.bBitDepthLuma, 0); KernelLog.Ln;
		KernelLog.String("	settings:				"); KernelLog.Set(p.bmSettings); KernelLog.Ln;
		KernelLog.String("	max # ref fr + 1:		"); KernelLog.Int(p.bMaxNumberOfRefFramesPlus1, 0); KernelLog.Ln;
		KernelLog.String("	rate ctl modes:		"); KernelLog.Set(p.bmRateControlModes); KernelLog.Ln;
		KernelLog.String("	layout/stream (h):	"); KernelLog.Set(p.bmLayoutPerStream[0]); KernelLog.Ln;
		KernelLog.String("	layout/stream (l):	"); KernelLog.Set(p.bmLayoutPerStream[1]); KernelLog.Ln;
	END PrintParams;

	PROCEDURE GetHeader (CONST hdr: ARRAY OF CHAR; pos: SIGNED32; VAR h: Header);
	VAR
		set: SET;
	BEGIN
		set := SYSTEM.VAL(SET, ORD(hdr[pos + 1]));
		h.id := 0 IN set;
		h.eof := 1 IN set;
		h.ptPresent := 2 IN set;
		h.scrPresent := 3 IN set;
		h.psb := 4 IN set;
		h.still := 5 IN set;
		h.error := 6 IN set;
		h.eoh := 7 IN set;

		INC(pos);

		IF h.ptPresent THEN
			h.pt := SYSTEM.GET32(ADDRESSOF(hdr[pos]));
			INC(pos, 4)
		END;
		IF h.scrPresent THEN
			h.scr := SYSTEM.GET32(ADDRESSOF(hdr[pos]));
			INC(pos, 4)
		END
	END GetHeader;

	PROCEDURE PrintHeader (CONST hdr: ARRAY OF CHAR; pos: SIGNED32; w: Streams.Writer);
	VAR
		set: SET;
	BEGIN
		IF hdr[pos] # 0CX THEN
			w.String("Header length incorrect ");
			w.Int(ORD(hdr[pos]), 0);
			w.String(" instead of 12.");
			RETURN
		END;
		set := SYSTEM.VAL(SET, ORD(hdr[pos + 1]));
		IF 0 IN set THEN
			w.String("id 1 ")
		ELSE
			w.String("id 0 ")
		END;
		IF 1 IN set THEN
			w.String("[EOF]")
		END;
		IF 2 IN set THEN
			w.String("[PT]")
		END;
		IF 3 IN set THEN
			w.String("[SCR]")
		END;
		IF 5 IN set THEN
			w.String("[Still]")
		END;
		IF 6 IN set THEN
			w.String("[ERROR]")
		END;
		IF 7 IN set THEN
			w.String("[EOH]")
		END;
		w.String(' ');
		w.Int(SYSTEM.GET32(ADDRESSOF(hdr[pos + 2])), 0)
	END PrintHeader;

	PROCEDURE Probe(dev : Usbdi.UsbDevice; id : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
	VAR
		i, j, count: SIGNED32;
		curr: Usbdi.UnknownDescriptor;
		vc: UsbVideoDesc.VideoControlDesc;
		ep: UsbVideoDesc.InterruptEndpointDesc;

		ih: UsbVideoDesc.VSInputHeaderDesc;
		vs: UsbVideoDesc.VSFormatDesc;
		vfr: UsbVideoDesc.VSFrameDesc;
		sid: UsbVideoDesc.StillImageDesc;
		cmd: UsbVideoDesc.ColorMatchingDesc;
		u: UsbVideoDesc.Unit;
		buf: ARRAY 32 OF CHAR;
		frame: POINTER TO ARRAY OF CHAR;
		params: POINTER TO ProbeCommitCtl;

	BEGIN
		(* Check if video class *)
		IF id.bInterfaceClass # 0EH THEN RETURN NIL END;

		CASE id.bInterfaceSubClass OF
			 1: (* Video control *)
			 	KernelLog.String("Found Video Control interface #"); KernelLog.Int(id.bInterfaceNumber, 0); KernelLog.String("	alt:	"); KernelLog.Int(id.bAlternateSetting, 0); KernelLog.Ln;
			 	NEW(dr);

				(* Parse video control interface descriptor *)
				IF (id.unknown # NIL) THEN
					dr.control := UsbVideoDesc.ParseVideoControlDesc(id.unknown.descriptor^, 0);
					UsbVideoDesc.PrintVC(dr.control)
				END;

				(* Parse & resolve unit descriptors *)
				(*! DIRTY TEMP HACK *)
				dr.controlPipe := dev.GetPipe(0);
				RETURN dr;
				(*! END OF DIRTY TEMP HACK *)

				UsbVideoDesc.ClearUnitCache;
				curr := id.unknown.next;
				count := 0;
				WHILE curr # NIL DO
					u := UsbVideoDesc.ParseUnit(curr.descriptor^, 0);
					IF u = NIL THEN
						KernelLog.String("ERROR: Unknown Unit"); KernelLog.Ln;
						dr := NIL;
						RETURN NIL
					END;
					UsbVideoDesc.unitCache[u.bUnitID - 1] := u;
					curr := curr.next;
					INC(count)
				END;

				FOR i := 0 TO 255 DO
					IF UsbVideoDesc.unitCache[i] # NIL THEN
						UsbVideoDesc.unitCache[i].Resolve(UsbVideoDesc.unitCache)
					END
				END;
				NEW(dr.topology, count);
				j := 0;
				FOR i := 0 TO 255 DO
					IF UsbVideoDesc.unitCache[i] # NIL THEN
						dr.topology[j] := UsbVideoDesc.unitCache[i];
						(*PrintUnit(dr.topology[j]);*)
						INC(j)
					END
				END;

				(* Create contol pipes *)
				dr.controlPipe := dev.GetPipe(0);
				KernelLog.String(":: NUM ENDPOINTS "); KernelLog.Int(id.bNumEndpoints, 0); KernelLog.Ln;
				FOR i := 0 TO id.bNumEndpoints - 1 DO
					KernelLog.String("= Endpoint "); KernelLog.Int(i, 0); KernelLog.Ln;
					KernelLog.String("	adr:				"); KernelLog.Int(id.endpoints[i].bEndpointAddress, 0); KernelLog.Ln;
					KernelLog.String("	type:				"); KernelLog.Int(id.endpoints[i].type, 0); KernelLog.Ln;
					KernelLog.String("	max pkt size:	"); KernelLog.Int(id.endpoints[i].wMaxPacketSize, 0); KernelLog.Ln;
					KernelLog.String("	mult:				"); KernelLog.Int(id.endpoints[i](Usb.EndpointDescriptor).mult, 0); KernelLog.Ln;
					KernelLog.String("	unknowns:		"); KernelLog.Boolean(id.endpoints[i].unknown = NIL); KernelLog.Ln;
				END;

				(*dr.ControlRequest(GetCur, VCRequestErrorCodeCtl, 0, buf, 1);*)
				(*dr.ControlRequest(GetCur, PUWhiteBalanceTemperatureAutoCtl, 3, buf, 1);
				KernelLog.String("Result:	"); KernelLog.Int(ORD(buf[0]), 0); KernelLog.Ln;
				KernelLog.String("Status:	"); KernelLog.Int(dr.status, 0); KernelLog.Ln;
				buf[0] := 0X;
				dr.ControlRequest(GetCur, PUWhiteBalanceTemperatureAutoCtl, 3, buf, 1);*)
				(*dr.ControlRequest(GetCur, PUBrightnessCtl, 3, buf, 2);
				KernelLog.String("Current:	"); KernelLog.Int(ORD(buf[0]) + ORD(buf[1]) * 100H, 0); KernelLog.Ln;
				KernelLog.String("Status:	"); KernelLog.Int(dr.status, 0); KernelLog.Ln;
				dr.ControlRequest(GetMin, PUBrightnessCtl, 3, buf, 2);
				KernelLog.String("Min:		"); KernelLog.Int(ORD(buf[0]) + ORD(buf[1]) * 100H, 0); KernelLog.Ln;
				KernelLog.String("Status:	"); KernelLog.Int(dr.status, 0); KernelLog.Ln;
				dr.ControlRequest(GetMax, PUBrightnessCtl, 3, buf, 2);
				KernelLog.String("Max:		"); KernelLog.Int(ORD(buf[0]) + ORD(buf[1]) * 100H, 0); KernelLog.Ln;
				KernelLog.String("Status:	"); KernelLog.Int(dr.status, 0); KernelLog.Ln;
				dr.ControlRequest(GetRes, PUBrightnessCtl, 3, buf, 2);
				KernelLog.String("Res:		"); KernelLog.Int(ORD(buf[0]) + ORD(buf[1]) * 100H, 0); KernelLog.Ln;
				KernelLog.String("Status:	"); KernelLog.Int(dr.status, 0); KernelLog.Ln;*)
				
			|2: (* Video streaming *)
				KernelLog.String("Found Video Streaming interface #"); KernelLog.Int(id.bInterfaceNumber, 0); KernelLog.String("	alt:	"); KernelLog.Int(id.bAlternateSetting, 0); KernelLog.String("	#"); KernelLog.Int(id.numAlternateInterfaces, 0); KernelLog.Ln;
				FOR i := 0 TO id.numAlternateInterfaces - 1 DO
					KernelLog.String("= Alt Iface #"); KernelLog.Int(i, 0); KernelLog.String(" ="); KernelLog.Ln;
					KernelLog.String("	id:	"); KernelLog.Int(id.alternateInterfaces[i].bInterfaceNumber, 0); KernelLog.Ln;
					KernelLog.String("	alt:	"); KernelLog.Int(id.alternateInterfaces[i].bAlternateSetting, 0); KernelLog.Ln;
					KernelLog.String("	eps:	"); KernelLog.Int(id.alternateInterfaces[i].bNumEndpoints, 0); KernelLog.Ln;
					FOR j := 0 TO id.alternateInterfaces[i].bNumEndpoints - 1 DO
						KernelLog.String("	= Endpoint "); KernelLog.Int(j, 0); KernelLog.Ln;
						KernelLog.String("		adr:				"); KernelLog.Int(id.alternateInterfaces[i].endpoints[j].bEndpointAddress, 0); KernelLog.Ln;
						KernelLog.String("		attr:				"); KernelLog.Hex(SYSTEM.VAL(SIGNED32, id.alternateInterfaces[i].endpoints[j].bmAttributes), -2); KernelLog.Ln;
						KernelLog.String("		type:				"); KernelLog.Int(id.alternateInterfaces[i].endpoints[j].type, 0); KernelLog.Ln;
						KernelLog.String("		max pkt size:	"); KernelLog.Int(id.alternateInterfaces[i].endpoints[j].wMaxPacketSize, 0); KernelLog.Ln;
						KernelLog.String("		length:			"); KernelLog.Int(id.alternateInterfaces[i].endpoints[j](Usb.EndpointDescriptor).bLength, 0); KernelLog.Ln;
						KernelLog.String("		bInterval:		"); KernelLog.Int(id.alternateInterfaces[i].endpoints[j](Usb.EndpointDescriptor).bInterval, 0); KernelLog.Ln;
						KernelLog.String("		mult:				"); KernelLog.Int(id.alternateInterfaces[i].endpoints[j](Usb.EndpointDescriptor).mult, 0); KernelLog.Ln;
						KernelLog.String("		unknowns:		"); KernelLog.Boolean(id.alternateInterfaces[i].endpoints[j].unknown = NIL); KernelLog.Ln;
					END
				END;
				NEW(sdr);
				sdr.controlDriver := dr;
				IF id.unknown # NIL THEN
					ih := UsbVideoDesc.ParseVSInputHeader(id.unknown.descriptor^, 0);
					UsbVideoDesc.PrintVSInputHeader(ih);
					sdr.inputHeader := ih
				END;
				curr := id.unknown.next;

				(* Parse all format descriptor groups *)
				FOR i := 0 TO ih.bNumFormats - 1 DO
					vs := UsbVideoDesc.ParseVSFormat(curr.descriptor^, 0);
					vs.Print;
					curr := curr.next;
					FOR j := 0 TO 	vs.bNumFrameDescriptors - 1 DO
						vfr := UsbVideoDesc.ParseVSFrame(curr.descriptor^, 0);
						vfr.Print;
						curr := curr.next
					END;
					IF ORD(curr.descriptor[2]) = UsbVideoDesc.VSStillImageFrame THEN
						sid := UsbVideoDesc.ParseStillImageDesc(curr.descriptor^, 0);
						UsbVideoDesc.PrintStillImageDesc(sid);
						curr := curr.next
					END;
					IF ORD(curr.descriptor[2]) = UsbVideoDesc.VSColorFormat THEN
						cmd := UsbVideoDesc.ParseColorMatchingDesc(curr.descriptor^, 0);
						UsbVideoDesc.PrintColorMatchingDesc(cmd);
						curr := curr.next
					END;
				END;
				IF curr # NIL THEN KernelLog.String("WARNING: There are some VS decriptors left"); KernelLog.Ln END;

				KernelLog.String(":: NUM ENDPOINTS "); KernelLog.Int(id.bNumEndpoints, 0); KernelLog.Ln;
				FOR i := 0 TO id.bNumEndpoints - 1 DO
					KernelLog.String("= Endpoint "); KernelLog.Int(i, 0); KernelLog.Ln;
					KernelLog.String("	adr:			"); KernelLog.Int(id.endpoints[i].bEndpointAddress, 0); KernelLog.Ln;
					KernelLog.String("	type:			"); KernelLog.Int(id.endpoints[i].type, 0); KernelLog.Ln;
					KernelLog.String("	max pkt size:	"); KernelLog.Int(id.endpoints[i].wMaxPacketSize, 0); KernelLog.Ln;
					KernelLog.String("	mult:			"); KernelLog.Int(id.endpoints[i](Usb.EndpointDescriptor).mult, 0); KernelLog.Ln;
					KernelLog.String("	unknowns:		"); KernelLog.Boolean(id.endpoints[i].unknown = NIL); KernelLog.Ln;
				END;
				IF dr = NIL THEN
					KernelLog.String("ERROR: No suitable Control Interface driver"); KernelLog.Ln;
					RETURN NIL
				END;

				RETURN sdr
		ELSE
			KernelLog.String("Found Unknown video interface"); KernelLog.Ln;
			RETURN NIL
		END;
		FOR i := 0 TO LEN(id.endpoints) - 1 DO
			(*KernelLog.String("endpoint "); KernelLog.Int(i, 0); KernelLog.Ln;
			KernelLog.String("	type:	"); KernelLog.Int(id.endpoints[i].type, 0); KernelLog.Ln;
			KernelLog.String("	adr:	"); KernelLog.Int(id.endpoints[i].bEndpointAddress, 0); KernelLog.Ln;*)
			curr := id.endpoints[i].unknown;
			WHILE curr # NIL DO
				ep := UsbVideoDesc.ParseEndpointDesc(curr.descriptor^, 0);
				(*PrintEndpoint(ep);*)
				(*dr.interruptPipe := dev.GetPipe(ep.bEndpointAddress);*)
				curr := curr.next
			END
		END;

		CASE id.bInterfaceProtocol OF
			 1: KernelLog.String("Video interface uses protocol 15"); KernelLog.Ln
		ELSE
			KernelLog.String("Undefined video interface protocol"); KernelLog.Ln
		END;

		(*KernelLog.String("	Device "); KernelLog.Address(SYSTEM.VAL(ADDRESS, dev)); KernelLog.Ln;
		KernelLog.String("		# of configs:	"); KernelLog.Int(LEN(dev.configurations), 0); KernelLog.Ln;
		KernelLog.String("		configurations:	");
		FOR i := 0 TO LEN(dev.configurations) - 1 DO KernelLog.Int(dev.configurations[i].bNumInterfaces, 0); KernelLog.String("	") END;
		KernelLog.Ln;

		FOR i := 0 TO dev.configurations[0].bNumInterfaces - 1 DO
			KernelLog.String("		Interface descriptor "); KernelLog.Int(dev.configurations[0].interfaces[i].bInterfaceNumber, 0); KernelLog.Ln;
			KernelLog.String("			# of endpoints:	"); KernelLog.Int(dev.configurations[0].interfaces[i].bNumEndpoints, 0); KernelLog.Ln;
			FOR j := 0 TO dev.configurations[0].interfaces[i].bNumEndpoints - 1 DO
				KernelLog.String("			endpoint "); KernelLog.Int(j, 0); KernelLog.Ln;
				KernelLog.String("				type:	"); KernelLog.Int(dev.configurations[0].interfaces[i].endpoints[j].type, 0); KernelLog.Ln;
				curr := dev.configurations[0].interfaces[i].endpoints[j].unknown;
				WHILE curr # NIL DO
					PrintUnknownDesc(4, curr);
					curr := curr.next
				END
			END
		END;
		KernelLog.String("	Interface descriptor "); KernelLog.Address(SYSTEM.VAL(ADDRESS, id)); KernelLog.Ln;
		KernelLog.String("		interface id:	"); KernelLog.Int(id.bInterfaceNumber, 0); KernelLog.Ln;
		KernelLog.String("		# of endpoints:	"); KernelLog.Int(id.bNumEndpoints, 0); KernelLog.Ln;
		KernelLog.String("		Endpoints types:	");
		FOR j := 0 TO id.bNumEndpoints - 1 DO KernelLog.Int(id.endpoints[j].type, 0); KernelLog.String("	") END;
		KernelLog.Ln;
		curr := id.unknown;
		WHILE curr # NIL DO
			PrintUnknownDesc(2, curr);
			curr := curr.next
		END;

		KernelLog.String("	Configuration's unknown descriptor: "); KernelLog.Ln;
		curr := dev.configurations[0].unknown;
		WHILE curr # NIL DO
			PrintUnknownDesc(2, curr);
			curr := curr.next
		END;

		KernelLog.String("	Configuration's IAD: "); KernelLog.Int(LEN(dev.configurations[0].iads), 0); KernelLog.Ln;
		FOR i := 0 TO LEN(dev.configurations[0].iads) - 1 DO
			KernelLog.String("		Iad # "); KernelLog.Int(i, 0); KernelLog.Ln;
			KernelLog.String("			first iface:	"); KernelLog.Int(dev.configurations[0].iads[i].bFirstInterface, 0); KernelLog.Ln;
			KernelLog.String("			# interface:	"); KernelLog.Int(dev.configurations[0].iads[i].bInterfaceCount, 0); KernelLog.Ln;
		END;*)
		RETURN NIL
	END Probe;

	PROCEDURE Cleanup *;
	BEGIN
		(* Unregister the driver at the USB driver registry *)
		KernelLog.String("Cleaning UsbVideo module"); KernelLog.Ln;
		Usbdi.drivers.Remove(Name);
	END Cleanup;

	(* Test command for video streaming transfer *)
	PROCEDURE Transfer *;
	VAR
		desc: ARRAY 9 OF CHAR;
		i, j, count, max: SIGNED32;
		size: SIGNED32;
		t: Kernel.Timer;
		f: Files.File;
		w: Files.Writer;
	BEGIN
		KernelLog.String(":: Streaming one frame"); KernelLog.Ln;

		size := 120 * 160 * 2(*params.dwMaxPayloadTransferSize*);
		max := 10;
		NEW(frame, size * max);

		count := 0;
		NEW(t);
		REPEAT
			KernelLog.String("========== TRANSMITTING PAYLOAD #"); KernelLog.Int(count, 0); KernelLog.String(" =========="); KernelLog.Ln;
			i := sdr.videoPipe.Transfer(size, size * count, frame^);
			KernelLog.String(":: Transfer finished: "); KernelLog.Int(i, 0); KernelLog.Ln;
			t.Sleep(30);
			INC(count);
		UNTIL (count >= max) OR (i > Usbdi.ShortPacket);
		(*KernelLog.String(":: Analysing Received Data"); KernelLog.Ln;
		f := Files.New("UsbFrameImage.dat");
		Files.OpenWriter(w, f, 0);
		j := 0;
		i := -1;
		WHILE j < size * max DO
			IF ORD(frame[j]) = 12 THEN
				IF i # -1 THEN 	KernelLog.String("	Length: "); KernelLog.Int(i, 0); KernelLog.Ln END;
				KernelLog.String("Found header at "); KernelLog.Int(j, 0); KernelLog.String(" "); KernelLog.Buffer(frame^, j, 12);
				PrintHeader(frame^, j);
				INC(j, 11); i := -1
			ELSIF frame[j] = 0X THEN
				(*i := -1;*)
				DEC(i)
			ELSE
				w.Char(frame[j])
			END;
			INC(j);
			INC(i)
		END;
		(*FOR i := 0 TO max * size - 1 BY 3000 DO
			IF frame[i] = 0CX THEN
				KernelLog.String(" -> Header at "); KernelLog.Int(i, 0); KernelLog.Ln;
				PrintHeader(frame^, i);
				w.Bytes(frame^, i + 12, 3000 - 12);
			END
		END;*)
		w.Update;
		Files.Register(f);
		f.Close;
		(*IF i # -1 THEN KernelLog.String("	Length: "); KernelLog.Int(i, 0); KernelLog.Ln END;*)
		KernelLog.Buffer(frame^, 0, size*max);
		KernelLog.String(":: Analysing Received Data Done"); KernelLog.Ln;*)
	END Transfer;

	(* Test command for video streaming transfer *)
	PROCEDURE TransferStill * (context: Commands.Context);
	VAR
		desc: ARRAY 9 OF CHAR;
		params: POINTER TO ProbeCommitCtl;
		frame: POINTER TO ARRAY OF CHAR;
		i, j, count, max: SIGNED32;
		size: SIGNED32;
		t: Kernel.Timer;
		f: Files.File;
		w: Files.Writer;
	BEGIN
		KernelLog.String(":: Streaming one still image"); KernelLog.Ln;

		NEW(params);
		params.bmHint := {0};
		params.bFormatIndex := 1;
		params.bFrameIndex := 2;
		params.dwFrameInterval := 333333;
		(*params.dwMaxVideoFrameSize := 640 * 480 * 2; (* bytes *)
		params.bMaxNumberOfRefFramesPlus1 := 1;*)
		(*PrintParams(params^);*)
		sdr.NegotiateStill(params^);
		PrintParams(params^);

		(* Set Interface 1 *)
		IF ~sdr.device(Usb.UsbDevice).SetInterface(1, 1) THEN
			KernelLog.String("Could not set interface"); KernelLog.Ln
		END;

		(*size := 120 * 160 * 2(*params.dwMaxPayloadTransferSize*);
		max := 1;
		NEW(frame, size * max);*)

		desc[0] := 1X;
		sdr.ControlRequest(SetCur, VSStillImageTriggerCtl, desc, 1);

		(*Transfer*)
		(*GetStillFrame(context);*)
		(*count := 0;
		NEW(t);
		REPEAT
			KernelLog.String("========== TRANSMITTING PAYLOAD #"); KernelLog.Int(count, 0); KernelLog.String(" =========="); KernelLog.Ln;
			i := sdr.videoPipe.Transfer(size, size * count, frame^);
			KernelLog.String(":: Transfer finished: "); KernelLog.Int(i, 0); KernelLog.Ln;
			t.Sleep(30);
			INC(count);
		UNTIL (count >= max) OR (i > Usbdi.ShortPacket);
		KernelLog.String(":: Analysing Received Data"); KernelLog.Ln;
		f := Files.New("UsbFrameImage.dat");
		Files.OpenWriter(w, f, 0);
		j := 0;
		i := -1;
		WHILE j < size * max DO
			IF ORD(frame[j]) = 12 THEN
				IF i # -1 THEN 	KernelLog.String("	Length: "); KernelLog.Int(i, 0); KernelLog.Ln END;
				KernelLog.String("Found header at "); KernelLog.Int(j, 0); KernelLog.String(" "); KernelLog.Buffer(frame^, j, 12);
				PrintHeader(frame^, j);
				INC(j, 11); i := -1
			ELSIF frame[j] = 0X THEN
				(*i := -1;*)
				DEC(i)
			ELSE
				w.Char(frame[j])
			END;
			INC(j);
			INC(i)
		END;
		w.Update;
		Files.Register(f);
		f.Close;
		KernelLog.Buffer(frame^, 0, size*max);
		KernelLog.String(":: Analysing Received Data Done"); KernelLog.Ln;*)
	END TransferStill;

	PROCEDURE FindHeaders * (context: Commands.Context);
	VAR
		i, j, n, l: SIGNED32;
		finished: BOOLEAN;
	BEGIN
		n := 0;
		i := 0;
		(*WHILE ORD(frame[i]) # 12 DO INC(i) END;*)
		WHILE (~finished) & (i < LEN(frame)) DO
			IF ORD(frame[i]) = 12 THEN
				(* Found header *)
				IF n < LEN(headers) THEN
					j := 0;
					WHILE (frame[i + 12 + j] # 0X) & (ORD(frame[i + 12 + j]) # 12) DO
						INC(j)
					END;
					headers[n].pos := i;
					headers[n].size := j;

					context.out.String("Header #"); context.out.Int(n, 0); context.out.Ln;
					context.out.String("	-> "); PrintHeader(frame^, i, context.out);
					context.out.String("	pos:  "); context.out.Int(i, 0); context.out.Ln;
					context.out.String("	size: "); context.out.Int(j, 0); context.out.Ln;

					INC(n);
					WHILE (i + 12 + j < LEN(frame)) & (frame[i + 12 + j] = 0X) DO INC(j) END;
					INC(i, sdr.videoPipe.maxPacketSize);
				ELSE
					context.out.Update;
					context.out(*error*).String("ERROR: Too many headers, stopping analysis");
					context.out(*error*).Ln;
					context.out(*error*).Update;
					finished := TRUE
				END
			ELSE
				context.out.Update;
				context.out(*error*).String("ERROR: Expected header");
				context.out(*error*).Ln;
				context.out(*error*).Update;
				finished := TRUE
			END;
		END;

		context.out.String("Summary"); context.out.Ln;
		context.out.String("	headers: "); context.out.Int(n, 0); context.out.Ln;
		i := 0;
		WHILE i < n DO
			INC(l, headers[i].size);
			INC(i)
		END;
		context.out.String("	total size: "); context.out.Int(l, 0); context.out.Ln;

		context.out.Update
	END FindHeaders;

	PROCEDURE Record * (context: Commands.Context);
	VAR
		i: SIGNED32;
		f: Files.File;
		w: Files.Writer;
	BEGIN
		f := Files.New("UsbFrameImage.dat");
		Files.OpenWriter(w, f, 0);
		context.arg.Int(i, FALSE);
		WHILE i # 0 DO
			IF i > 20 THEN
				context.out.String("ERROR: invalid header index ");
				context.out.Int(i, 0);
				context.out.String(". Skipping.");
				context.out.Ln
			ELSE
				w.Bytes(frame^, headers[i].pos + 12, headers[i].size)
			END;
			context.arg.Int(i, FALSE);
		END;
		w.Update;
		Files.Register(f);
		f.Close
	END Record;

	PROCEDURE Stream * (context: Commands.Context);
	VAR
		t: Kernel.MilliTimer;
	BEGIN
		LOOP
			Kernel.SetTimer(t, 33);
			GetFrame(context);
			(*FindHeaders(context);*)
			context.out.String("Data received: "); context.out.Int(sdr.videoPipe(UsbHcdi.Pipe).actLen, 0);
			context.out.String('/'); context.out.Int(120 * 160 * 2, 0);
			context.out.Ln; context.out.Update;
			REPEAT Objects.Yield UNTIL Kernel.Expired(t)
		END
	END Stream;

	PROCEDURE GetFrame * (context: Commands.Context);
	VAR
		hdr: Header;
		t: Kernel.MilliTimer;
		f: Files.File;
		w: Files.Writer;
		buf: POINTER TO ARRAY OF CHAR;
		actual, i, j, n, ofs, size, status, tx: SIGNED32;
		id, start, stop, record: BOOLEAN;
	BEGIN
		size := 640 * 480 * 2;
		NEW(frame, size);

		f := Files.New('UsbFrame.Log');
		Files.OpenWriter(w, f, 0);

		tx := sdr.videoPipe.maxPacketSize * sdr.videoPipe(UsbHcdi.Pipe).mult;
		NEW(buf, tx);
		start := TRUE;
		Kernel.SetTimer(t, 30000);
		(*sdr.Pause;*)

		REPEAT
			w.String("Elapsed: ");
			w.Int(Kernel.Elapsed(t), 5);
			w.String("	");
			status := sdr.videoPipe.Transfer(tx, 0, buf^);
			INC(i);
			actual := sdr.videoPipe(UsbHcdi.Pipe).actLen;
			IF start THEN
				id := ~hdr.id;
				start := FALSE
			END;
			IF actual > 12 THEN
				PrintHeader(buf^, 0, w);
				GetHeader(buf^, 0, hdr);
				IF id = hdr.id THEN
					IF start THEN hdr.id := id; start := FALSE END;
					w.String(" Recording ");
					w.Int(actual, 0);
					w.String(" bytes");

					j := 12;
					WHILE (j < actual) & (ofs < size) DO
						frame[ofs] := buf[j];
						INC(ofs);
						INC(j)
					END
				ELSE
					w.String(" Not recording")
				END;
				IF ~start & (hdr.id = id) & hdr.eof THEN
					stop := TRUE
				END;
			ELSIF status = Usbdi.ShortPacket THEN
				w.String("Skipping transfer: no data");
			ELSE
				w.String("TRANSFER ERROR ");
				w.Int(status, 0);
			END;
			w.Ln
		UNTIL (status > Usbdi.ShortPacket) OR (ofs = size) OR stop;
		(*sdr.Resume;*)

		w.String("recorded ");
		w.Int(ofs, 0);
		w.String(" bytes");
		w.Ln;
		w.String("missing ");
		w.Int(size - ofs, 0);
		w.String(" bytes");
		w.Ln;
		w.Update;
		Files.Register(f);
		f.Close
	END GetFrame;

	PROCEDURE GetFrame2 * (context: Commands.Context);
	VAR
		hdr: Header;
		t: Kernel.MilliTimer;
		f: Files.File;
		w: Files.Writer;
		buf: POINTER TO ARRAY OF CHAR;
		actual, i, j, n, ofs, size, status, tx: SIGNED32;
		id, start, stop, record: BOOLEAN;
	BEGIN
		size := 640 * 480 * 2;
		NEW(frame, size);

		f := Files.New('UsbFrame.Log');
		Files.OpenWriter(w, f, 0);

		tx := 2 * sdr.videoPipe.maxPacketSize * sdr.videoPipe(UsbHcdi.Pipe).mult;
		NEW(buf, tx);
		start := TRUE;
		Kernel.SetTimer(t, 30000);

		REPEAT
			w.String("Elapsed: ");
			w.Int(Kernel.Elapsed(t), 5);
			w.String("	");
			status := sdr.videoPipe.Transfer(tx, 0, buf^);
			INC(i);
			actual := sdr.videoPipe(UsbHcdi.Pipe).actLen;
			IF start THEN
				id := ~hdr.id;
				start := FALSE
			END;
			IF actual > 24 THEN
				PrintHeader(buf^, 0, w);
				GetHeader(buf^, 0, hdr);
				IF id = hdr.id THEN
					IF start THEN hdr.id := id; start := FALSE END;
					w.String(" Recording ");
					w.Int(MIN(actual, 3000), 0);
					w.String(" bytes");

					j := 12;
					WHILE (j < MIN(3000, actual)) & (ofs < size) DO
						frame[ofs] := buf[j];
						INC(ofs);
						INC(j)
					END
				ELSE
					w.String(" Not recording")
				END;
				IF ~start & (hdr.id = id) & hdr.eof THEN
					stop := TRUE
				END;

				IF actual > 3000 + 12 THEN
					w.String("	");
					PrintHeader(buf^, 3000, w);
					GetHeader(buf^, 3000, hdr);
					IF id = hdr.id THEN
						w.String(" Recording ");
						w.Int(actual - 3000, 0);
						w.String(" bytes");

						j := 12 + 3000;
						WHILE (j < actual) & (ofs < size) DO
							frame[ofs] := buf[j];
							INC(ofs);
							INC(j)
						END
					ELSE
						w.String(" Not recording")
					END;
					IF ~start & (hdr.id = id) & hdr.eof THEN
						stop := TRUE
					END
				ELSE
					w.String("Skipping transfer: no data");
				END
			ELSIF status = Usbdi.ShortPacket THEN
				w.String("Skipping transfer: no data");
			ELSE
				w.String("TRANSFER ERROR ");
				w.Int(status, 0);
			END;
			w.Ln
		UNTIL (status > Usbdi.ShortPacket) OR (ofs = size) OR stop;

		w.String("recorded ");
		w.Int(ofs, 0);
		w.String(" bytes");
		w.Ln;
		w.String("missing ");
		w.Int(size - ofs, 0);
		w.String(" bytes");
		w.Ln;
		w.Update;
		Files.Register(f);
		f.Close
	END GetFrame2;

	PROCEDURE GetFrame3 * (context: Commands.Context);
	VAR
		hdr: Header;
		t: Kernel.MilliTimer;
		f: Files.File;
		w: Files.Writer;
		actual, el, i, j, n, ofs, size, status, tx: SIGNED32;
		id, start, stop, record: BOOLEAN;
		buf: POINTER TO ARRAY OF CHAR;
	BEGIN
		(*context.out.String("Get Frame v3 starting... ");
		context.out.Update;*)
		(*NEW(frame, size);*)

		(*NEW(buf, tx);
		start := TRUE;*)
		(*Kernel.SetTimer(t, 30000);*)

		(*REPEAT
			w.String("Elapsed: ");
			w.Int(Kernel.Elapsed(t), 5);
			w.String("	");
			status := sdr.videoPipe.Transfer(tx, 0, buf^);
			INC(i);
			actual := sdr.videoPipe(UsbHcdi.Pipe).actLen;
			IF start THEN
				id := ~hdr.id;
				start := FALSE
			END;
			IF actual > 12 THEN
				PrintHeader(buf^, 0, w);
				GetHeader(buf^, 0, hdr);
				IF hdr.eof THEN
					stop := TRUE
				END;
			ELSIF status = Usbdi.ShortPacket THEN
				w.String("Skipping transfer: no data");
			ELSE
				w.String("TRANSFER ERROR ");
				w.Int(status, 0);
			END;
			w.Ln
		UNTIL stop;*)
		NEW(buf, sdr.params.dwMaxPayloadTransferSize);

		(* Set Interface 1 *)
		IF ~sdr.device(Usb.UsbDevice).SetInterface(1, 5) THEN
			KernelLog.String("Could not set interface"); KernelLog.Ln
		END;
		Kernel.SetTimer(t, 30);

		sdr.videoPipe := sdr.device.GetPipe(sdr.inputHeader.bEndpointAddress);
		sdr.videoPipe.maxPacketSize := 800;
		sdr.videoPipe(UsbHcdi.Pipe).mult := 1;

		tx := sdr.videoPipe.maxPacketSize * sdr.videoPipe(UsbHcdi.Pipe).mult;

		(*NEW(buf, 120 * 160 * 2 + 214 * 12);*)
		WHILE ~Kernel.Expired(t) DO END;
		status := sdr.videoPipe.Transfer(LEN(buf), 0, buf^);

		f := Files.New('UsbFrame.Log');
		Files.OpenWriter(w, f, 0);

		w.String("Elapsed: ");
		w.Int(el, 5);
		w.String("	");
		w.Int(status, 0);
		w.Ln;

		context.out.String("recording... ");
		context.out.Update;
		w.String("Recording");
		w.Ln;
		actual := sdr.videoPipe(UsbHcdi.Pipe).actLen;
		w.String("Transfered ");
		w.Int(actual, 0);
		w.String(" bytes.");
		w.Ln;
		i := 0;
		WHILE (i + j < actual) & (ofs < Size) DO
			GetHeader(buf^, i, hdr);
			PrintHeader(buf^, i, w);
			j := 0;
			IF buf[i] # 0X THEN
				WHILE j < tx - 12 DO
					frame[ofs] := buf[i + j];
					INC(ofs);
					INC(j)
				END
			END;
			INC(i, tx);
			w.Ln
		END;

		w.String("recorded ");
		w.Int(ofs, 0);
		w.String(" bytes");
		w.Ln;
		w.String("missing ");
		w.Int(Size - ofs, 0);
		w.String(" bytes");
		w.Ln;
		w.Update;
		Files.Register(f);
		f.Close;
		context.out.String("done");
		context.out.Ln;
		context.out.Update
	END GetFrame3;

	PROCEDURE SkipFrame;
	VAR
		hdr: Header;
		buf: POINTER TO ARRAY OF CHAR;
		actual, i, j, n, ofs, size, status, tx: SIGNED32;
		id, start, stop, record: BOOLEAN;
	BEGIN
		tx := sdr.videoPipe.maxPacketSize * sdr.videoPipe(UsbHcdi.Pipe).mult;
		NEW(buf, tx);
		start := TRUE;

		REPEAT
			status := sdr.videoPipe.Transfer(tx, 0, buf^);
			INC(i);
			actual := sdr.videoPipe(UsbHcdi.Pipe).actLen;
			IF start THEN
				id := ~hdr.id;
				start := FALSE
			END;
			IF actual > 12 THEN
				GetHeader(buf^, 0, hdr);
				IF id = hdr.id THEN
					IF start THEN hdr.id := id; start := FALSE END;
					j := 12;
					WHILE (j < actual) & (ofs < size) DO
						INC(ofs);
						INC(j)
					END
				END;
				IF ~start & (hdr.id = id) & hdr.eof THEN
					stop := TRUE
				END;
			END;
		UNTIL (status > Usbdi.ShortPacket) OR (ofs = size) OR stop;
	END SkipFrame;

	PROCEDURE GetStillFrame * (context: Commands.Context);
	VAR
		hdr: Header;
		t: Kernel.MilliTimer;
		f: Files.File;
		w: Files.Writer;
		buf: POINTER TO ARRAY OF CHAR;
		actual, i, j, n, ofs, size, status, tx: SIGNED32;
		id, start, stop, record: BOOLEAN;
	BEGIN
		size := 120 * 160 * 2;
		NEW(frame, size);

		f := Files.New('UsbFrame.Log');
		Files.OpenWriter(w, f, 0);

		tx := sdr.videoPipe.maxPacketSize * sdr.videoPipe(UsbHcdi.Pipe).mult;
		NEW(buf, tx);
		start := TRUE;
		Kernel.SetTimer(t, 30000);

		REPEAT
			w.String("Elapsed: ");
			w.Int(Kernel.Elapsed(t), 5);
			w.String("	");
			status := sdr.videoPipe.Transfer(tx, 0, buf^);
			INC(i);
			actual := sdr.videoPipe(UsbHcdi.Pipe).actLen;
			IF actual > 12 THEN
				PrintHeader(buf^, 0, w);
				GetHeader(buf^, 0, hdr);
				IF (start OR (id = hdr.id)) & hdr.still THEN
					IF start THEN hdr.id := id; start := FALSE END;
					w.String(" Recording ");
					w.Int(actual, 0);
					w.String(" bytes");

					j := 12;
					WHILE (j < actual) & (ofs < size) DO
						frame[ofs] := buf[j];
						INC(ofs);
						INC(j)
					END
				END;
				IF ~start & (hdr.id = id) & hdr.still & hdr.eof THEN
					stop := TRUE
				END;
			ELSIF status = Usbdi.ShortPacket THEN
				w.String("Skipping transfer: no data");
			ELSE
				w.String("TRANSFER ERROR ");
				w.Int(status, 0);
			END;
			w.Ln
		UNTIL (status > Usbdi.ShortPacket) OR (ofs = size) OR stop;

		w.String("recorded ");
		w.Int(ofs, 0);
		w.String(" bytes");
		w.Ln;
		w.String("missing ");
		w.Int(size - ofs, 0);
		w.String(" bytes");
		w.Ln;
		w.Update;
		Files.Register(f);
		f.Close
	END GetStillFrame;

	PROCEDURE Photo * (context: Commands.Context);
	VAR
		i: SIGNED32;
		t: Kernel.MilliTimer;
	BEGIN
		FOR i := 1 TO 60 DO
			Kernel.SetTimer(t, 33);
			GetFrame(context);
			REPEAT Objects.Yield UNTIL Kernel.Expired(t)
		END;

		TransferStill(context);
		context.out.String("CAPTURING");
		context.out.Ln;
		GetStillFrame(context)		
	END Photo;

	PROCEDURE SaveFrame * (context: Commands.Context);
	VAR
		f: Files.File;
		w: Files.Writer;
	BEGIN
		KernelLog.Buffer(frame^, 0, LEN(frame));
		context.out.String(" :: Saving frame... ");
		context.out.Update;

		f := Files.New("UsbFrameImage.dat");
		Files.OpenWriter(w, f, 0);

		w.Bytes(frame^, 0, LEN(frame));
		w.Update;

		Files.Register(f);
		f.Close;

		context.out.String("done");
		context.out.Ln;
		context.out.Update
	END SaveFrame;

BEGIN
	KernelLog.String("UsbVideo@Body"); KernelLog.Ln;
	TRACE(SIZEOF(ProbeCommitCtl), SIZEOF(SIGNED8), SIZEOF(SIGNED16), SIZEOF(SIGNED32), SIZEOF(SIGNED64));
	Modules.InstallTermHandler(Cleanup);
	Usbdi.drivers.Add(Probe, Name, Description, Priority);
	NEW(frame, Size)
END UsbVideo.

UsbVideo.Transfer ~
UsbVideo.TransferStill ~
UsbVideo.FindHeaders ~
UsbVideo.Record ~
UsbVideo.Stream ~
UsbVideo.GetFrame ~
UsbVideo.GetFrame2 ~
UsbVideo.GetFrame3 ~
UsbVideo.GetStillFrame ~
UsbVideo.SaveFrame ~

UsbVideo.Photo ~

SystemTools.List modules ~
SystemTools.Free UsbVideo UsbVideoDesc ~

UsbInfo.TraceOn Copying ~
UsbInfo.TraceNone ~