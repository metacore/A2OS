MODULE UsbHidErrors; (** AUTHOR "ottigerm"; PURPOSE "HID Items parser with error codes" *)
(**
 * Bluebottle USB HID Error Handling Module
 *
 * This module handles the errors when parsing usb hid items
 *
 * Overview:
 *	HID Parser Error Checking	HID Parser Error Codes, Version 1.0  01/30/98
 *
 * History:
 *
 *	17.07.2006	Version 1.0
 *)

IMPORT KernelLog;

(*THESE CONSTANTS DEFINE THE ERROR CODES PROVIDED BY THE HID PARSER*)
CONST

	(* Unknown Items *)
	UnknownItem* = 											00H;
	(* Global Items *)
	GlobalItemUsagePage* = 									04H;
	GlobalItemLogicalMinimum* = 								14H;
	GlobalItemLogicalMaximum* = 								24H;
	GlobalItemPhysicalMinimum* = 								34H;
	GlobalItemPhysicalMaximum* = 								44H;
	GlobalItemUnitExponent* = 									54H;
	GlobalItemUnit* = 											64H;
	GlobalItemReportSize* = 									74H;
	GlobalItemReportID* = 										84H;
	GlobalItemReportCount* = 									94H;
	GlobalItemPush* = 											00A4H;
	GlobalItemPop* = 											00B4H;
	GlobalItemGeneral* = 										00F4H;
	(* Local Items *)
	LocalItemUsage* = 											08H;
	LocalItemUsageMinimum* = 									18H;
	LocalItemUsageMaximum* = 								28H;
	LocalItemDesignatorIndex* = 								38H;
	LocalItemDesignatorMinimum* = 							48H;
	LocalItemDesignatorMaximum* = 							58H;
	LocalItemStringIndex* = 									78H;
	LocalItemStringMinimum* = 									88H;
	LocalItemStringMaximum* = 								98H;
	LocalItemDelimiter* = 										00A8H;
	(* Main Items *)
	MainItemInput* = 											80H;
	MainItemOutput* = 											90H;
	MainItemFeature* = 										00B0H;
	MainItemCollection* = 										00A0H;
	MainItemEndCollection* = 									00C0H;

TYPE
	ErrorItem = POINTER TO RECORD
		itemPosition	:		LONGINT;
		errorTag* 		: 		LONGINT;
		errorSubcode*	:		LONGINT;
		next*			:		ErrorItem;
	END;

	ErrorManager* = OBJECT

	(* Print errors as described in HID Parser Error Codes, Version 1.0, 30.01.1998 *)
	PROCEDURE PrintError*(errorTag, errorSubcode:LONGINT);
	BEGIN
		CASE errorTag OF
			UnknownItem:
				CASE errorSubcode OF
					3FH:KernelLog.String("UUnknownOrReservedItem ");
					|3EH:KernelLog.String("ULongItemDefined ");
					ELSE ErrorNotFound;
				END;

		(* Global Items *)
			|GlobalItemUsagePage:
				CASE errorSubcode OF
					00H:KernelLog.String("DataFieldMustBeNonZero");
					|01H:KernelLog.String("DataFieldGreaterThan0xFFFF");
					|02H:KernelLog.String("MustBeDefPriorToAnyIOFeatItems");
					ELSE ErrorNotFound;
				END;

			|GlobalItemLogicalMinimum:
				CASE errorSubcode OF
					00H:KernelLog.String("MustBeWithinBoundsOfReportSize ");
					|01H:KernelLog.String("MustBeDefPriorToAnyIOFeatItems");
					|02H:KernelLog.String("MustEq1IfArrayFlagIsSetInMI ");
					ELSE ErrorNotFound;
				END;

			|GlobalItemLogicalMaximum:
				CASE errorSubcode OF
					00H:KernelLog.String("MustBeWithinBoundsOfReportSize ");
					|01H:KernelLog.String("MustBeDefPriorToAnyIOFeatItems");
					|02H:KernelLog.String("MustEqNODefUsagsIfArFlagSetInMI ");
					ELSE ErrorNotFound;
				END;

			|GlobalItemPhysicalMinimum:
				IF (errorSubcode=00H) THEN
					KernelLog.String("MustHaveCorrespPhysicalMax");
				ELSE
					ErrorNotFound;
				END;

			|GlobalItemPhysicalMaximum:
				IF (errorSubcode=00H) THEN
					KernelLog.String("MustHaveCorrespPhysicalMin");
				ELSE
					ErrorNotFound;
				END;

			|GlobalItemUnitExponent:
				ErrorNotFound;

			|GlobalItemUnit:
				ErrorNotFound;

			|GlobalItemReportSize:
				IF (errorSubcode=01H) THEN
					KernelLog.String("MustBeDefPriorToAnyIOFeatIt");
				ELSE
					ErrorNotFound;
				END;

			|GlobalItemReportID:
				CASE errorSubcode OF
					00H:KernelLog.String("MustBeNonZero ");
					|01H:KernelLog.String("MustBeLessOrEqual255");
					|02H:KernelLog.String("MustBeDefPriorToAnyIOFeatIt ");
					|03H:KernelLog.String("CantSpanTopLevelApplCollBounds ");
					|04H:KernelLog.String("MSCnstCantBeDefOutsATopLevColl");
					ELSE ErrorNotFound;
				END;

			|GlobalItemReportCount:
				IF (errorSubcode=00H) THEN
					KernelLog.String("MustBeNonZero");
				ELSE
					ErrorNotFound;
				END;

			|GlobalItemPush:
				CASE errorSubcode OF
					00H:KernelLog.String("MustHaveCorrespondingPop");
					|01H:KernelLog.String("DataFieldSizeMustBeZero");
					ELSE ErrorNotFound;
				END;

			|GlobalItemPop:
				CASE errorSubcode OF
					00H:KernelLog.String("MustHaveCorrespondingPush");
					|01H:KernelLog.String("DataFieldSizeMustBeZero");
					ELSE ErrorNotFound;
				END;

			|GlobalItemGeneral:
				IF(errorSubcode=00H) THEN
					KernelLog.String("GlobalItemRedundantlyDeclared");
				ELSE
					ErrorNotFound;
				END;

		(* Local Items *)
			|LocalItemUsage:
				IF (errorSubcode=00H) THEN
					KernelLog.String("MustBeDefPriorToAnyIOFeatIt ");
				ELSE
					ErrorNotFound;
				END;

			|LocalItemUsageMinimum:
				CASE errorSubcode OF
					00H:KernelLog.String("MustHaveACorrespondingUsageMax ");
					|01H:KernelLog.String("MustBeLessOrEqualToUsageMax ");
					|03H:KernelLog.String("UPOfExtUsgMinMustMatchMax ");
					ELSE ErrorNotFound;
				END;

			|LocalItemUsageMaximum:
				CASE errorSubcode OF
					00H:KernelLog.String("MustHaveACorrespondingUsageMin ");
					|01H:KernelLog.String("MustBeGreaterOrEqualToMinimum");
					|02H:KernelLog.String("UPOfExtUsgMaxMustMatchMin ");
					ELSE ErrorNotFound;
				END;

			|LocalItemDesignatorIndex:
				ErrorNotFound;

			|LocalItemDesignatorMinimum:
				CASE errorSubcode OF
					00H:KernelLog.String("MustHaveACorrespondingDesigMax ");
					|01H:KernelLog.String("MustBeLessOrEqualToMaximum ");
					ELSE ErrorNotFound;
				END;

			|LocalItemDesignatorMaximum:
				CASE errorSubcode OF
					00H:KernelLog.String("MustHaveACorrespondingDesigMin ");
					|01H:KernelLog.String("MustBeGreaterOrEqualToMinimum ");
					ELSE ErrorNotFound;
				END;

			|LocalItemStringIndex:
				ErrorNotFound;

			|LocalItemStringMinimum:
				CASE errorSubcode OF
					00H:KernelLog.String("MustHaveACorrespondingStringMax ");
					|01H:KernelLog.String("MustBeLessOrEqualToMaximum ");
					ELSE ErrorNotFound;
				END;

			|LocalItemStringMaximum:
				CASE errorSubcode OF
					00H:KernelLog.String("MustHaveACorrespondingStringMin ");
					|01H:KernelLog.String("MustBeGreaterOrEqualToMinimum ");
					ELSE ErrorNotFound;
				END;

			|LocalItemDelimiter:
				CASE errorSubcode OF
					00H:KernelLog.String("MustBeOpenOrClose");
					|01H:KernelLog.String("NoNestingOfDelimitedSets ");
					|02H:KernelLog.String("MustBeCorrespondingOpenAndClose");
					|03H:KernelLog.String("MustOnlyContUsgMinAndUsgMaxLI");
					|04H:KernelLog.String("MayNotBeDeclForTopLevelAppColl");
					ELSE ErrorNotFound;
				END;

		(* Main Items *)
			|MainItemInput:
				CASE errorSubcode OF
					00H:KernelLog.String("ReqGlobLocalItemsMustBeDef");
					|01H:KernelLog.String("CantBeContWithinDelOpADelCl");
					|02H:KernelLog.String("LogMinMaxMustBeWithinBndsOfRepS");
					|03H:KernelLog.String("LogOrPhysMaxMustBeGrThRespMin");
					ELSE ErrorNotFound;
				END;

			|MainItemOutput:
				CASE errorSubcode OF
					00H:KernelLog.String("ReqGlobLocalItemsMustBeDef");
					|01H:KernelLog.String("CantBeContWithinDelOpenADelClose");
					|02H:KernelLog.String("LogMinMaxMustBeWithinBndsOfRepS");
					|03H:KernelLog.String("LogOrPhysMaxMustBeGrThRespMin");
					ELSE ErrorNotFound;
				END;

			|MainItemFeature:
				CASE errorSubcode OF
					00H:KernelLog.String("ReqGlobLocalItemsMustBeDef");
					|01H:KernelLog.String("CantBeContWithinDelOpenADelClose");
					|02H:KernelLog.String("LogMinMaxMustBeWithinBndsOfRepS");
					|03H:KernelLog.String("LogOrPhysMaxMustBeGrThRespMin");
					ELSE ErrorNotFound;
				END;

			|MainItemCollection:
				CASE errorSubcode OF
					00H:KernelLog.String("MustHaveACorrEndColl");
					|01H:KernelLog.String("CantBeContWithinSetDelOpACl");
					|02H:KernelLog.String("AppCollCanOnlyBeDeclAtTopLev");
					ELSE ErrorNotFound;
				END;

			|MainItemEndCollection:
				CASE errorSubcode OF
					00H:KernelLog.String("MustHaveACorrespColl");
					|01H:KernelLog.String("CantBeContWithinSetDelOpenAClose");
					|02H:KernelLog.String("MSCTheFinSizOAllRepMustBeMltf8B");
					ELSE ErrorNotFound;
				END;
			ELSE
				ErrorNotFound;
		END;

	END PrintError;

	(*used, when error code not defined in PrintError(..) *)
	PROCEDURE ErrorNotFound;
	BEGIN
		KernelLog.String("unknown error");
	END ErrorNotFound;

	END ErrorManager;

	(*manages the occured errors in a linked list*)
	ErrorList*= OBJECT
	VAR
		firstErrorItem, lastErrorItem	: ErrorItem;
		hidErrorManager 			: ErrorManager;

		(* add error at the end of the linked list*)
		PROCEDURE Add*(position, errorTag, errorSubcode : LONGINT);
		BEGIN
			(*detect empty list*)
			IF(firstErrorItem=NIL) THEN
				NEW(firstErrorItem);
				lastErrorItem := firstErrorItem;
			ELSE
				(*when list is not empty*)
				NEW(lastErrorItem.next);
				lastErrorItem := lastErrorItem.next;
			END;

			lastErrorItem.itemPosition 	:= position;
			lastErrorItem.errorTag		:= errorTag;
			lastErrorItem.errorSubcode 	:= errorSubcode;
		END Add;

		(* print all errors*)
		PROCEDURE PrintAll*;
		VAR
			current : ErrorItem;
		BEGIN
			current := firstErrorItem;
			IF(firstErrorItem#NIL)THEN
				KernelLog.String("Hid parser detected following errors for this device"); KernelLog.Ln;
				KernelLog.String("Item            ErrorTag        ErrorSubcode    Description"); KernelLog.Ln;

				REPEAT
					KernelLog.Int(current.itemPosition, 4); KernelLog.String("                  "); KernelLog.Hex(current.errorTag, -2);
					KernelLog.String("                  "); KernelLog.Hex(current.errorSubcode, -2);
					KernelLog.String("                      ");hidErrorManager.PrintError(current.errorTag, current.errorSubcode);
					KernelLog.Ln;
					current := current.next;
				UNTIL (current=NIL);
			END;
		END PrintAll;

	BEGIN
		NEW(hidErrorManager);
	END ErrorList;

END UsbHidErrors.

System.Free UsbHidErrors ~