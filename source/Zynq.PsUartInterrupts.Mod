(**
	AUTHOR: Alexey Morozov, Timothee Martiel, HighDim GmbH, 2013-2018
	PURPOSE: interrupt handling infrastracture for Zynq PS UART driver used in A2
*)
MODULE PsUartInterrupts;

IMPORT
	Platform, Machine;

TYPE
	(** UART interrupt handler *)
	UartInterruptHandler* = PROCEDURE(param: ANY);

VAR
	intrHandler0, intrHandler1: UartInterruptHandler;
	intrHandlerParam0, intrHandlerParam1: ANY;

	PROCEDURE IntrHandlerUart0(VAR state: Machine.State);
	BEGIN
		intrHandler0(intrHandlerParam0);
	END IntrHandlerUart0;

	PROCEDURE IntrHandlerUart1(VAR state: Machine.State);
	BEGIN
		intrHandler1(intrHandlerParam1);
	END IntrHandlerUart1;

	(**
		Install a UART interrupt handler

		uart: PS UART controller ID
		interruptHandler: interrupt handler
		interruptHandlerParam: parameter to be passed to interrupt handler

		Return: FALSE in case of a wrong value of UART ID or if interruptHandler is NIL
	*)
	PROCEDURE InstallInterruptHandler*(uart: SIGNED32; interruptHandler: UartInterruptHandler; interruptHandlerParam: ANY): BOOLEAN;
	BEGIN
		IF interruptHandler = NIL THEN
			RETURN FALSE;
		END;

		CASE uart OF
			0:
				intrHandler0 := interruptHandler;
				intrHandlerParam0 := interruptHandlerParam;
				Machine.InstallHandler(IntrHandlerUart0,Platform.UartIrq[0]);
			|1:
				intrHandler1 := interruptHandler;
				intrHandlerParam1 := interruptHandlerParam;
				Machine.InstallHandler(IntrHandlerUart1,Platform.UartIrq[1]);
		ELSE
			RETURN FALSE;
		END;

		RETURN TRUE;
	END InstallInterruptHandler;

END PsUartInterrupts.
