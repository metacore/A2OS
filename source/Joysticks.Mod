MODULE Joysticks; (** AUTHOR "staubesv"; PURPOSE "Joystick interface"; *)
(**
 * Usage:
 *
 *	Joysticks.Show ~ displays a list of all accessible joystick instances
 *	System.Free Joysticks ~	unloads this module
 *
 * Clients:
 *	1. Get joystick object instance via Joysticks.registry.Get() or Joysticks.registry.GetAll()
 *	2. Install handler (Joystick.Register()) or poll joystick (Joystick.Poll) for data
 *	3. When receiving a JoystickDisconnectedMessage, delete reference to joystick object instance
 *
 * Implementor of joystick drivers:
 *
 *	1. Create Joystick object instance
 *	2. Assign a descriptive text to the Joystick.desc field
 *	3. Add axis and coolie hats
 *	4. Register joystick object using Joysticks.registry.Add(JoystickObjInstance, res)
 *	5. While running: Send JoystickDataMessages to joystick object instance (Joystick.Handle)
 *	6. When the joystick is disconnected, unregister it using Joysticks.registry.Remove(JoystickObjInstance)
 *
 * History:
 *
 *	28.11.2006	First release (staubesv)
 *)

IMPORT
	KernelLog, Modules, Streams, Commands, Plugins, Strings;

CONST

	Ok* = 0;
	WrongParameter* = 1;
	Error* = 2;

	DefaultName = "JOYSTICK";

	Verbose = TRUE;

	TraceRaw = 0;
	TraceCalibrationInfo = 1;

	Trace = {};

	(** Indicies of JoystickDataMessage.axis array *)
	AxisX* = 0;
	AxisY* = 1;
	AxisZ* = 2;
	AxisRx* = 3;
	AxisRy* = 4;
	AxisRz* = 5;
	Slider1* = 6;
	Slider2* = 7;
	Slider3* = 8;
	Slider4* = 9;

	(** Bits of JoystickDataMessage.buttons sets *)
	Button1* = 0;		Button2* = 1;		Button3* = 2;		Button4* = 3;
	Button5* = 4;		Button6* = 5;		Button7* = 6;		Button8* = 7;
	Button9* = 8;		Button10* = 9;		Button11* = 10;		Button12* = 11;
	Button13* = 12;		Button14* = 13;		Button15* = 14;		Button16* = 15;
	Button17* = 16;		Button18* = 17;		Button19* = 18;		Button20* = 19;
	Button21* = 20; 	Button22* = 21;		Button23* = 22;		Button24* = 23;
	Button25* = 24;		Button26* = 25;		Button27* = 26;		Button28* = 27;
	Button29* = 28;		Button30* = 29;		Button31* = 30;		Button32* = 31;

	(** Bits of JoystickData.coolieHats[...] sets *)
	HatUp* = 0;
	HatRight* = 1;
	HatDown* = 2;
	HatLeft* = 3;

	(** Range of interface values {MinAxisValue = -MaxAxisValue} *)
	MinAxisValue* = -1024;
	MaxAxisValue* = 1024;

	MaxNbrOfButtons* = 32; 	(* {0 <= MaxNbrOfButtons <= 32} *)
	MaxNbrOfAxis* = 32; 		(* {0 <= MaxNbrOfAxis <= 32} *)
	MaxNbrOfCoolieHats* = 8;	(* {0 <= MaxNbrOfCoolieHats < MAX(LONGINT)} *)

	DefaultDeadzone = 0.5; (* in percent {0 <= DefaultDeadzone <= 100} *)

	(* Error Messages *)
	ErrorAxisNotImplemented = "Axis not implemented";
	ErrorParameterOutOfRange = "Parameter out of range";
	ErrorNoValidCenterPosition = "Axis must be centerd when stopping calibration";

TYPE

	JoystickMessage* = RECORD
		id- : LONGINT; (** joystick identifier *)
	END;

	(** The joystick id has been disconnected *)
	JoystickDisconnectedMessage* = RECORD(JoystickMessage)
	END;

	(** The joystick id has been connected *)
	JoystickConnectedMessage* = RECORD(JoystickMessage);
	END;

	(** New data from joystick id *)
	JoystickDataMessage* = RECORD(JoystickMessage)
		 (** Joystick.nbrOfButtons starting at index 0 *)
		buttons* : SET;

		 (** Joystick.implementedAxis bit field indicates which axis are implemented. The range of the values is [MinAxisValue, MaxAxisValue] *)
		axis* : ARRAY MaxNbrOfAxis OF LONGINT;

		(** Joystick.nbrOfCoolieHats starting at index 0 *)
		coolieHat* : ARRAY MaxNbrOfCoolieHats OF SET;
	END;

	JoystickMessageHandler* = PROCEDURE {DELEGATE} (VAR msg : JoystickMessage);

TYPE

	HandlerListNode = POINTER TO RECORD
		handler : JoystickMessageHandler;
		next : HandlerListNode;
	END;


	(**
	 *	Calibration mechnism:
	 *
	 *	Specified by the implementor of a joystick:
	 *
	 *	   minValue               		          centerValue                               maxValue
	 *		|-------------------------|------------------------|
	 *
	 *       whereas centerValue := minValue + ((ABS(maxValue) + ABS(minValue)) / 2);
	 *
	 *
	 *	Delivered from joystick (raw values):
	 *
	 *		   calMinValue         calCenterValue                            calMaxValue
	 *	                |--------------|-------------------------|
	 *
	 *
	 *	What we want to have:
	 *
	 *		MinAxisValue						0								MaxAxisValue
	 *		|-----------------------------|-----------------------------|
	 *
	 *
	 *	What we do...
	 *
	 *	Scaling step 1: Align center position to zero by adding -calCenterValue  to raw values
	 *
	 *		calMinValue - calCenterValue	      0				calMaxValue - calCenterValue
	 *	                                     |--------------|-------------------------|
	 *
	 *	Scaling step 2: Scale value lower/higher the center
	 *
	 *	MinAxisValue					             0					                  MaxAxisValue
	 *		|-----------------------------|------------------------------|
	 *	(calCenterValue - calMinValue) * scaleFactorLow		(calMaxValue - calCenterValue) * scaleFactorHigh
	 *)


	Axis = RECORD
		(* specified by implementor, i.e. should be values *)
		minValue, maxValue, centerValue : LONGINT;

		(* values determined by joystick calibration *)
		calMinValue, calMaxValue, calCenterValue : LONGINT;
		calCenterOffset : LONGINT;
		scaleFactorLow, scaleFactorHigh : REAL;

		(* user configuration *)
		deadzone : REAL; (* in percent *)
	END;

TYPE

	Joystick* = OBJECT(Plugins.Plugin);
	VAR
		(** Part of client interface *)
		id- : LONGINT;
		nbrOfButtons- : LONGINT;
		nbrOfCoolieHats- : LONGINT;
		nbrOfAxis- : LONGINT;
		implementedAxis- : SET;
		connected- : BOOLEAN;
		calibrationMode- : BOOLEAN;

		(* Internal fields *)
		axis : ARRAY MaxNbrOfAxis OF Axis;

		lastMessage : JoystickDataMessage;
		lastMessageRaw : JoystickDataMessage; (* in raw values *)

		listHead : HandlerListNode;

		(** Client interface *)

		(** Register a joystick message handler *)
		PROCEDURE Register*(handler : JoystickMessageHandler);
		VAR node : HandlerListNode;
		BEGIN {EXCLUSIVE}
			ASSERT(handler # NIL);
			NEW(node); node.handler := handler;
			(* insert at list head *)
			node.next := listHead.next;
			listHead.next := node;
		END Register;

		(** Unregister a joystick message handler *)
		PROCEDURE Unregister*(handler : JoystickMessageHandler);
		VAR node : HandlerListNode;
		BEGIN {EXCLUSIVE}
			ASSERT(handler # NIL);
			node := listHead;
			WHILE (node.next # NIL) & (node.next.handler # handler) DO node := node.next; END;
			IF node.next # NIL THEN
				node.next := node.next.next;
			END;
		END Unregister;

		(** Clients may poll the joystick's current state using this method *)
		PROCEDURE Poll*(VAR message : JoystickDataMessage) : BOOLEAN;
		BEGIN {EXCLUSIVE}
			message := lastMessage;
			RETURN connected;
		END Poll;

		(** Set the deadzone for all axis *)
		PROCEDURE SetGlobalDeadzone*(deadzone : REAL; VAR errorMessage : ARRAY OF CHAR; VAR res : WORD);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO MaxNbrOfAxis - 1 DO
				IF i IN implementedAxis THEN
					SetDeadzone(i, deadzone, errorMessage, res);
					IF res # Ok THEN RETURN; END;
				END;
			END;
		END SetGlobalDeadzone;

		(** Set the deadzone for the specified axis *)
		PROCEDURE SetDeadzone*(axisNbr : LONGINT; deadzone : REAL; VAR errorMessage : ARRAY OF CHAR; VAR res : WORD);
		BEGIN
			IF (axisNbr < 0) OR (axisNbr >= MaxNbrOfAxis) OR (~(axisNbr IN implementedAxis)) THEN
				errorMessage := ErrorAxisNotImplemented;
				res := WrongParameter;
			ELSIF (deadzone < 0.0) OR (deadzone > 100.0) THEN
				errorMessage := ErrorParameterOutOfRange;
				res := WrongParameter;
			ELSE
				axis[axisNbr].deadzone := deadzone;
				res := Ok;
			END;
		END SetDeadzone;

		(* Initialize minimum and maximum of raw joystick data axis values *)
		PROCEDURE StartCalibration*;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO MaxNbrOfAxis - 1 DO
				IF i IN implementedAxis THEN
					axis[i].calMinValue := MAX(LONGINT);
					axis[i].calMaxValue := MIN(LONGINT);
				END;
			END;
			calibrationMode := TRUE;
		END StartCalibration;

		(* At the time this procedure is called, the axes should be in center position *)
		PROCEDURE StopCalibration*(VAR errorMsg : ARRAY OF CHAR; VAR res : WORD);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO MaxNbrOfAxis - 1 DO
				IF i IN implementedAxis THEN
					(* Determine center position offset in raw values *)
					axis[i].calCenterValue := lastMessageRaw.axis[i];
					axis[i].calCenterOffset := -axis[i].calCenterValue;

					IF (axis[i].calMinValue >= axis[i].calCenterValue) OR (axis[i].calMaxValue <= axis[i].calCenterValue) THEN
						errorMsg := ErrorNoValidCenterPosition;
						res := Error;
						RETURN;
					END;

					axis[i].scaleFactorLow := ABS(MinAxisValue / ABS(axis[i].calCenterValue - axis[i].calMinValue));
					axis[i].scaleFactorHigh := ABS(MaxAxisValue / ABS(axis[i].calMaxValue - axis[i].calCenterValue));
				END;
			END;
			calibrationMode := FALSE;
			IF TraceCalibrationInfo IN Trace THEN
				(* Show; *) KernelLog.Ln; KernelLog.String("Calibration information: "); KernelLog.Ln; ShowAxis; KernelLog.Ln;
			END;
		END StopCalibration;

		(** Provider interface *)

		(** Broadcast joystick message to all registered handlers *)
		PROCEDURE Handle*(VAR message : JoystickMessage);
		VAR node : HandlerListNode;
		BEGIN {EXCLUSIVE}
			message.id := id;
			IF message IS JoystickDataMessage THEN
				IF TraceRaw IN Trace THEN ShowDataMessage(message (JoystickDataMessage)); END;
				lastMessageRaw := message (JoystickDataMessage);
				IF calibrationMode THEN GetCalibrationData(message(JoystickDataMessage)); END;
				ScaleRawValues(message(JoystickDataMessage));
				ApplyDeadzone(message(JoystickDataMessage));
				lastMessage := message(JoystickDataMessage);
			END;
			node := listHead;
			WHILE (node.next # NIL) DO
				node.next.handler(message);
				node := node.next;
			END;
		END Handle;

		PROCEDURE AddAxis*(index, minValue, maxValue : LONGINT);
		BEGIN
			ASSERT((index >= 0) & (index < MaxNbrOfAxis));
			ASSERT(minValue < maxValue);
			axis[index].minValue := minValue;
			axis[index].maxValue := maxValue;
			axis[index].centerValue := minValue + Round((ABS(minValue) + ABS(maxValue)) / 2);
			axis[index].deadzone := DefaultDeadzone;

			(* Assume automatic calibration *)
			axis[index].calMinValue := minValue;
			axis[index].calMaxValue := maxValue;
			axis[index].calCenterValue := axis[index].centerValue;
			axis[index].calCenterOffset := - axis[index].centerValue;

			axis[index].scaleFactorHigh := ABS(MaxAxisValue / ABS(axis[index].maxValue - axis[index].centerValue));
			axis[index].scaleFactorLow := ABS(MinAxisValue / ABS(axis[index].centerValue - axis[index].minValue));

			INCL(implementedAxis, index);
			INC(nbrOfAxis);
		END AddAxis;

		PROCEDURE AddCoolieHat*;
		BEGIN
			ASSERT(nbrOfCoolieHats < MaxNbrOfCoolieHats);
			INC(nbrOfCoolieHats);
		END AddCoolieHat;

		PROCEDURE ScaleRawValues(VAR message : JoystickDataMessage);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO MaxNbrOfAxis - 1 DO
				IF i IN implementedAxis THEN
					(* Shift raw value to center position *)
					message.axis[i] := message.axis[i] + axis[i].calCenterOffset;
					(* scale the raw values into user values [MinAxisValue, MaxAxisValue] *)
					IF message.axis[i] >= 0 THEN
						message.axis[i] := Round(axis[i].scaleFactorHigh * message.axis[i]);
					ELSE
						message.axis[i] := Round(axis[i].scaleFactorLow * message.axis[i]);
					END;
					(* make sure the user values are within the expected boundaries *)
					IF message.axis[i] < MinAxisValue THEN message.axis[i] := MinAxisValue; END;
					IF message.axis[i] > MaxAxisValue THEN message.axis[i] := MaxAxisValue; END;
				END;
			END;
		END ScaleRawValues;

		PROCEDURE ApplyDeadzone(VAR message : JoystickDataMessage);
		VAR deadzone, i : LONGINT;
		BEGIN
			FOR i := 0 TO MaxNbrOfAxis - 1 DO
				IF i IN implementedAxis THEN
					deadzone := ENTIER(axis[i].deadzone / 100 * (MaxAxisValue - MinAxisValue));
					IF (message.axis[i] <= deadzone) & (message.axis[i] >= -deadzone) THEN
						message.axis[i] := 0;
					END;
				END;
			END;
		END ApplyDeadzone;

		(* Find minimum and maximum of raw joystick data axis values *)
		PROCEDURE GetCalibrationData(VAR message : JoystickDataMessage);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO MaxNbrOfAxis - 1 DO
				IF i IN implementedAxis THEN
					IF message.axis[i] < axis[i].calMinValue THEN axis[i].calMinValue := message.axis[i]; END;
					IF message.axis[i] > axis[i].calMaxValue THEN axis[i].calMaxValue := message.axis[i]; END;
				END;
			END;
		END GetCalibrationData;

		PROCEDURE Show*(w : Streams.Writer);
		BEGIN
			w.String(name); w.String(" ("); w.String(desc); w.String("): ");
			w.Int(nbrOfButtons, 0); w.String(" buttons, ");
			w.Int(nbrOfAxis, 0); w.String(" axis");
		END Show;

		PROCEDURE ShowAxis;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO MaxNbrOfAxis - 1 DO
				IF i IN implementedAxis THEN
					ShowAxisNbr(i);
				END;
			END;
		END ShowAxis;

		PROCEDURE ShowAxisNbr(axisNbr : LONGINT);
		VAR str : ARRAY 32 OF CHAR;
		BEGIN
			KernelLog.String("Axis "); GetAxisName(axisNbr, str); KernelLog.String(str); KernelLog.String(": "); KernelLog.Ln;
			KernelLog.String("   minValue: "); KernelLog.Int(axis[axisNbr].minValue, 0);
			KernelLog.String(", maxValue: "); KernelLog.Int(axis[axisNbr].maxValue, 0);
			KernelLog.Ln;
			KernelLog.String("   calMinValue: "); KernelLog.Int(axis[axisNbr].calMinValue, 0);
			KernelLog.String(", calMaxValue: "); KernelLog.Int(axis[axisNbr].calMaxValue, 0);
			KernelLog.String(", calCenterValue: "); KernelLog.Int(axis[axisNbr].calCenterValue, 0);
			KernelLog.Ln;
			KernelLog.String("   Scale Factors: High: ");
			Strings.FloatToStr(axis[axisNbr].scaleFactorHigh, 4, 10, 0, str); KernelLog.String(str);
			KernelLog.String(", Low: ");
			Strings.FloatToStr(axis[axisNbr].scaleFactorLow, 4, 10, 0, str); KernelLog.String(str);
			KernelLog.Ln;
			KernelLog.String("   Deadzone: "); KernelLog.Int(Round(100.0 * axis[axisNbr].deadzone), 0); KernelLog.String("%");
			KernelLog.Ln;
		END ShowAxisNbr;

		PROCEDURE ShowDataMessage(msg : JoystickDataMessage);
		VAR i : LONGINT; name: ARRAY 16 OF CHAR;
		BEGIN
			KernelLog.String("Buttons: "); KernelLog.Bits(msg.buttons, 0, 32);
			KernelLog.String(", Axis: ");
			FOR i := 0 TO MaxNbrOfAxis - 1 DO
				IF i IN implementedAxis THEN
					KernelLog.String("["); GetAxisName(i, name); KernelLog.String(name); KernelLog.String(": "); KernelLog.Int(msg.axis[i], 4); KernelLog.String("] ");
				END;
			END;
			KernelLog.String(", Hats: ");
			FOR i := 0 TO nbrOfCoolieHats-1 DO
				KernelLog.String("["); KernelLog.Int(i+1, 0); KernelLog.String(": "); KernelLog.Bits(msg.coolieHat[i], 0, 4); KernelLog.String("] ");
			END;
			KernelLog.Ln;
		END ShowDataMessage;

		PROCEDURE &Init*(nbrOfButtons : LONGINT);
		VAR name, temp : ARRAY 128 OF CHAR;
		BEGIN
			ASSERT(nbrOfButtons <= MaxNbrOfButtons);
			SELF.nbrOfButtons := nbrOfButtons;
			NEW(listHead);
			id := GetId();
			name := DefaultName; Strings.IntToStr(id, temp);
			Strings.Append(name, temp);
			SetName(name);
		END Init;

	END Joystick;

VAR
	registry- : Plugins.Registry;
	nextId : LONGINT;

PROCEDURE EventHandler(event : LONGINT; plugin : Plugins.Plugin);
VAR
	joystick : Joystick;
	connectedMsg : JoystickConnectedMessage; disconnectedMsg : JoystickDisconnectedMessage;
BEGIN
	joystick := plugin (Joystick);
	IF event = Plugins.EventAdd THEN
		IF Verbose THEN KernelLog.String("Joysticks: Joystick"); KernelLog.String(" connected."); KernelLog.Ln; END;
		joystick.connected := TRUE;
		connectedMsg.id := joystick.id;
		joystick.Handle(connectedMsg);
	ELSIF event = Plugins.EventRemove THEN
		IF Verbose THEN KernelLog.String("Joysticks: Joystick "); KernelLog.String(" disconnected."); KernelLog.Ln; END;
		joystick.connected := FALSE;
		disconnectedMsg.id := joystick.id;
		joystick.Handle(disconnectedMsg);
	END;
END EventHandler;

PROCEDURE GetId() : LONGINT;
BEGIN {EXCLUSIVE}
	INC(nextId);
	RETURN nextId;
END GetId;

PROCEDURE Round(value : REAL) : LONGINT;
VAR result : LONGINT;
BEGIN
	result := ENTIER(value);
	IF ABS(value) - ENTIER(ABS(value)) >= 0.5 THEN
		IF value >= 0 THEN INC(result); ELSE DEC(result); END;
	END;
	RETURN result;
END Round;

PROCEDURE GetAxisName*(axisNbr : LONGINT; VAR name: ARRAY OF CHAR);
VAR nbr : ARRAY 16 OF CHAR;
BEGIN
	CASE axisNbr OF
		|AxisX: name := "X";
		|AxisY: name := "Y";
		|AxisZ: name := "Z";
		|AxisRx: name := "Rx";
		|AxisRy: name := "Ry";
		|AxisRz: name := "Rz";
	ELSE
		name := "Slider";
		Strings.IntToStr(axisNbr - Slider1 + 1, nbr);
		Strings.Append(name, nbr);
	END;
END GetAxisName;

PROCEDURE Show*(context : Commands.Context);
VAR table : Plugins.Table; i : LONGINT;
BEGIN
	context.out.String("Joysticks: "); context.out.Ln;
	registry.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO
			table[i](Joystick).Show(context.out); context.out.Ln;
		END;
	ELSE
		context.out.String("none"); context.out.Ln;
	END;
END Show;

PROCEDURE Init;
VAR res : WORD;
BEGIN
	registry.AddEventHandler(EventHandler, res);
	IF res # Plugins.Ok THEN
		KernelLog.String("Joysticks: Could not register event handler, res: "); KernelLog.Int(res, 0); KernelLog.Ln;
	END;
END Init;

PROCEDURE Cleanup;
BEGIN
	Plugins.main.Remove(registry);
END Cleanup;

BEGIN
	nextId := 0;
	Modules.InstallTermHandler(Cleanup);
	NEW(registry, "Joysticks", "Joysticks");
	Init;
END Joysticks.

Joysticks.Show ~

System.Free Joysticks ~
