MODULE UsbHidParserExt; (** AUTHOR "ottigerm"; PURPOSE "HID Items parser with error codes" *)
(**
 * Bluebottle USB HID Items Module
 *
 * This module providing item parsing outputs, it is used for debugging or tracing
 *
 * Overview:
 *
 *	Main Items		As described on page 28
 *	Global Items	As described on page 35
 *	Local Items		As described on page 39

 *
 * History:
 *
 *	29.09.2006	Version 1.0 (ottigerm)
 *)

IMPORT SYSTEM, KernelLog, UsbHidUP;

CONST
	(*enum for global item parsing*)
	ParseIDUsagePage*					=   0;
	ParseIDLogicalMinimum*			=   1;
	ParseIDLogicalMaximum	*			=   2;
	ParseIDPhysicalMinimum* 			=   3;
	ParseIDPhysicalMaximum* 			=   4;
	ParseIDUnitExponent*				=   5;
	ParseIDUnit*						=   6;
	ParseIDReportSize*					=   7;
	ParseIDReportID*					=   8;
	ParseIDReportCount*				=   9;
	ParseIDPush*						= 10;
	ParseIDPop*						= 11;


	(*enum for local item parsing*)
	ParseIDUsage*						=   0;
	ParseIDUsageMinimum*				=   1;
	ParseIDUsageMaximum*			=   2;
	ParseIDDesignatorIndex*			=   3;
	ParseIDDesignatorMinimum*		=   4;
	ParseIDDesignatorMaximum*		=   5;
	ParseIDStringIndex* 				=   7;
	ParseIDStringMinimum*				=   8;
	ParseIDStringMaximum*			=   9;
	ParseIDDelimiter*					= 10;

	(*Main state*)

	ParseIDDataConstant*				=  0;
	ParseIDArrayVariable*				=  1;
	ParseIDAbsoluteRelative*			=  2;
	ParseIDNoWrapWrap*				=  3;
	ParseIDLinearNonLinear	*			=  4;
	ParseIDPreferdStateNoPreferd*		=  5;
	ParseIDNoNullPositionNullState*	=  6;
	ParseIDNonVolatileVolatile*			=  7;
	ParseIDBitFieldBufferedByte*		=  8;

(* print out eight empty spaces
 * 	param: 	level		the number of times to print out 8 empty spaces
 *)
PROCEDURE PrintLevel(level:LONGINT);
VAR i : LONGINT;
BEGIN
	IF(level > 0) THEN
		FOR i:=0 TO (level - 1) DO
			KernelLog.String("        ");
		END;
	END;
END PrintLevel;

(* print main item
 * 	param: 	bTag		tag
 *			bSize		size to read data
 *			data		data appended to tag
 *			itemNr		number of items already parsed + 1
 *			depth		the depth's subcollection (recursively)
 *)
PROCEDURE ParseMainItem*(bTag, bSize, data, itemNr, depth: LONGINT);
VAR dataAsSet : SET;
BEGIN
	(*hack for better layout; detect the end collection bTag*)
	IF (bTag=0CH) THEN
		DEC(depth);
	END;
	PrintLevel(depth);

	dataAsSet := SYSTEM.VAL(SET, data);
	CASE bTag OF
		8H: KernelLog.String("Input (");
			IF (0 IN dataAsSet) THEN KernelLog.String("Constant, ")		ELSE KernelLog.String("Data, ")			END;
			IF (1 IN dataAsSet) THEN KernelLog.String("Variable, ")		ELSE KernelLog.String("Array, ")			END;
			IF (2 IN dataAsSet) THEN KernelLog.String("Relative, ")		ELSE KernelLog.String("Absolute, ")		END;
			IF (3 IN dataAsSet) THEN KernelLog.String("Wrap, ") 		ELSE KernelLog.String("No Wrap, ")		END;
			IF (4 IN dataAsSet) THEN KernelLog.String("Non Linear, ") 	ELSE KernelLog.String("Linear, ")			END;
			IF (5 IN dataAsSet) THEN KernelLog.String("No Preferred, ") ELSE KernelLog.String("Preferred State, ")	END;
			IF (6 IN dataAsSet) THEN KernelLog.String("Null State") 	ELSE KernelLog.String("No Null Position ")	END;
			IF (7 IN dataAsSet) THEN (*reserved*) 					ELSE (*reserved*) 						END;
			IF bSize > 1 THEN
				IF (8 IN dataAsSet) THEN KernelLog.String(", Buffered Bytes"); ELSE KernelLog.String(", Bit Field"); END;
				(*As described in USB HidDescription p.28 bits 9-31 are reserved*)
			END;
		|9H: KernelLog.String("Output(");
			IF (0 IN dataAsSet) THEN KernelLog.String("Constant, ") 	ELSE KernelLog.String("Data, ")			END;
			IF (1 IN dataAsSet) THEN KernelLog.String("Variable, ") 		ELSE KernelLog.String("Array, ") 			END;
			IF (2 IN dataAsSet) THEN KernelLog.String("Relative, ") 		ELSE KernelLog.String("Absolute, ") 		END;
			IF (3 IN dataAsSet) THEN KernelLog.String("Wrap, ") 		ELSE KernelLog.String("No Wrap, ");		END;
			IF (4 IN dataAsSet) THEN KernelLog.String("Non Linear, ") 	ELSE KernelLog.String("Linear, ")			END;
			IF (5 IN dataAsSet) THEN KernelLog.String("No Preferred, ") ELSE KernelLog.String("Preferred State, ") 	END;
			IF (6 IN dataAsSet) THEN KernelLog.String("Null State, ") 	ELSE KernelLog.String("No Null Position, ")	END;
			IF (7 IN dataAsSet) THEN KernelLog.String("Volatile") 		ELSE KernelLog.String("Non Volatile") 		END;
			IF bSize > 1 THEN
				IF (8 IN dataAsSet) THEN KernelLog.String(", Buffered Bytes") ELSE KernelLog.String(", Bit Field") END;
				(*As described in USB HidDescription p.28 bits 9-31 are reserved*)
			END;
		|0BH: KernelLog.String("Feature(");
			IF (0 IN dataAsSet) THEN KernelLog.String("Constant, ") 	ELSE KernelLog.String("Data, "); 			END;
			IF (1 IN dataAsSet) THEN KernelLog.String("Variable, ") 		ELSE KernelLog.String("Array, ") 			END;
			IF (2 IN dataAsSet) THEN KernelLog.String("Relative, ") 		ELSE KernelLog.String("Absolute, ") 		END;
			IF (3 IN dataAsSet) THEN KernelLog.String("Wrap, ") 		ELSE KernelLog.String("No Wrap, ") 		END;
			IF (4 IN dataAsSet) THEN KernelLog.String("Non Linear, ") 	ELSE KernelLog.String("Linear, ") 			END;
			IF (5 IN dataAsSet) THEN KernelLog.String("No Preferred, ")	ELSE KernelLog.String("Preferred State, ") 	END;
			IF (6 IN dataAsSet) THEN KernelLog.String("Null State, ") 	ELSE KernelLog.String("No Null Position, ") END;
			IF (7 IN dataAsSet) THEN KernelLog.String("Volatile") 		ELSE KernelLog.String("Non Volatile") 		END;
			IF bSize > 1 THEN
				IF (8 IN dataAsSet) THEN KernelLog.String(", Buffered Bytes"); ELSE KernelLog.String(", Bit Field") END;
				(*As described in USB HidDescription p.28 bits 9-31 are reserved*)
			END;
		|0AH: KernelLog.String("Collection(");
			CASE data OF
				0H: KernelLog.String("Physical");
				|1H: KernelLog.String("Application");
				|2H: KernelLog.String("Logical");
				|3H: KernelLog.String("Report");
				|4H: KernelLog.String("Named Array");
				|5H: KernelLog.String("Usage Switch");
				|6H: KernelLog.String("Usage Modifier");
				ELSE
					IF data < 8FH THEN
						KernelLog.String("RESERVED");
					ELSE
						KernelLog.String("Vendor-defined");
						(*non standard is treated as an error*)
					END;
			END;
		|0CH: KernelLog.String("End Collection(");
	ELSE
		KernelLog.String("RESERVED(");
	END;
	KernelLog.String(")");
	KernelLog.Ln;
END ParseMainItem;

(* print global item
* 	param: 	bTag		tag
*			bSize		size to read data
*			data		data appended to tag
*			itemNr		number of items already parsed + 1
*			depth		the depth's subcollection (recursively)
*)
PROCEDURE ParseGlobalItem*( bTag, bSize, data, itemNr, depth: LONGINT);
VAR
BEGIN
	PrintLevel(depth);
	CASE bTag OF
		0H: KernelLog.String("Usage Page (");
			CASE data OF
				(*REFERENCE: p. 4 HID Usage Tables*)
				0H:
					KernelLog.String("Undefined");
				|1H: KernelLog.String("Generic Desktop Controls");
				|2H: KernelLog.String("Simulation Controls");
				|3H: KernelLog.String("VR Controls");
				|4H: KernelLog.String("Sport Controls ");
				|5H: KernelLog.String("Game Controls");
				|6H: KernelLog.String("Generic Device Controls");
				|7H: KernelLog.String("Keyboard/Keypad");
				|8H: KernelLog.String("LEDs");
				|9H: KernelLog.String("Button");
				|0AH: KernelLog.String("Ordinal");
				|0BH: KernelLog.String("Telephony");
				|0CH: KernelLog.String("Consumer");
				|0DH: KernelLog.String("Digitizer");
				|0EH: KernelLog.String("Reserved");
				|0FH: KernelLog.String("PID Page");
				|10H: KernelLog.String("Unicode");
				(*
				|11H: KernelLog.String("Reserved");
				|12H: KernelLog.String("Reserved");
				|13H: KernelLog.String("Reserved");
				*)
				|14H: KernelLog.String("Alphanumeric Display");
				(* from 15h tol 3fH
				|15H-3fH: KernelLog.String("Reserved")*)
				|40: KernelLog.String("Medical Instruments");
				(* from 41H tol 7fH
				|41H-7fH: KernelLog.String("Reserved")*)
				|81H: KernelLog.String("Monitor pages");
				|82H: KernelLog.String("Monitor pages");
				|83H: KernelLog.String("Monitor pages");
				|84H: KernelLog.String("Power pages");
				|85H: KernelLog.String("Power pages");
				|86H: KernelLog.String("Power pages");
				|87H: KernelLog.String("Power pages");
				(* from 88H tol 8BH
				|41H-7fH: KernelLog.String("Reserved")*)
				|8CH: KernelLog.String("Bar Code Scanner page");
				|8DH: KernelLog.String("Scale page");
				|8EH: KernelLog.String("Magnetic Stripe reading (MSR) Devices");
				|8FH: KernelLog.String("Reserved Point of Sale pages");
				ELSE
					 KernelLog.String("Reserved("); KernelLog.Int(data,0); KernelLog.String(")");
			END;
		|1H: KernelLog.String("Logical Minimum (");
			KernelLog.Int(data,0);
		|2H: KernelLog.String("Logical Maximum(");
			KernelLog.Int(data,0);
		|3H: KernelLog.String("Physical Minimum (");
			KernelLog.Int(data,0);
		|4H: KernelLog.String("Physical Maximum(");
			KernelLog.Int(data,0);
		|5H: KernelLog.String("Unit Exponent(");
			KernelLog.Int(data,0);
		|6H: KernelLog.String("Unit(");
			KernelLog.Int(data,0);
		|7H: KernelLog.String("Report Size(");
			KernelLog.Int(data,0);
		|8H: KernelLog.String("Report ID(");
			KernelLog.Int(data,0);
		|9H: KernelLog.String("Report Count (");
			KernelLog.Int(data,0);
		|10: KernelLog.String("Push(");
		|11: KernelLog.String("Pop (");
		ELSE
			KernelLog.String("Reserved(");
		END;
	KernelLog.String(")");
	KernelLog.Ln;
END ParseGlobalItem;

(*print local item
 * 	param: 	bTag		tag
 *			bSize		size to read data
 *			data		data appended to tag
 *			itemNr		number of items already parsed + 1
 *			depth		the depth's subcollection (recursively)
 *)
PROCEDURE ParseLocalItem*(bTag, bSize, data,  itemNr, depth, usagePage: LONGINT);
BEGIN
	PrintLevel(depth);
	CASE bTag OF
		0H:	IF (data DIV 10000H>0) THEN
				KernelLog.String("UsagePage("); UsbHidUP.PrintUsagePageName(data DIV 10000H); KernelLog.String(") ");
			END;
			KernelLog.String("Usage(");
			UsbHidUP.PrintUsagePage(usagePage, data);
		|1H: IF (data DIV 10000H>0) THEN
				KernelLog.String("UsagePage("); UsbHidUP.PrintUsagePageName(data DIV 10000H); KernelLog.String(") ");
			END;
			KernelLog.String("Usage Minimum(");
			KernelLog.Int(data MOD 10000H,0);
		|2H: IF (data DIV 10000H>0) THEN
				KernelLog.String("UsagePage("); UsbHidUP.PrintUsagePageName(data DIV 10000H); KernelLog.String(") ");
			END;
			KernelLog.String("Usage Maximum(");
			KernelLog.Int(data MOD 10000H,0);
		|3H: KernelLog.String("Designator Index(");
			KernelLog.Int(data,0);
		|4H: KernelLog.String("Designator Minimum(");
			KernelLog.Int(data,0);
		|5H: KernelLog.String("Designator Maximum(");
			KernelLog.Int(data,0);
		(*|6H: (*RESERVED*)*)
		|7H: KernelLog.String("String Index(");
			KernelLog.Int(data,0);
		|8H: KernelLog.String("String Minimum(");
			KernelLog.Int(data,0);
		|9H: KernelLog.String("String Maximum(");
			KernelLog.Int(data,0);
		|0AH: KernelLog.String("Delimiter(");
			CASE data OF
				0: KernelLog.String("open set)");
				|1H: KernelLog.String("close set)");
				ELSE (*NOT DEFINED*)
			END;
		ELSE KernelLog.String("RESERVED");
	END;
	KernelLog.String(")");
	KernelLog.Ln;
END ParseLocalItem;

END UsbHidParserExt.

System.Free UsbHidParserExt~