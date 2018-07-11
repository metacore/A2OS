MODULE Gpio; (** AUTHOR "Timothée Martiel"; PURPOSE "GPIO driver"; *)

(*! TODO:
	- Interrupt configuration
*)

IMPORT Platform;

CONST
	(** Direction: Input *)
	Input *		= FALSE;
	(** Direction: Output *)
	Output *	= TRUE;

TYPE
	DataReg = POINTER {UNSAFE,UNTRACED} TO RECORD
		DATA: ARRAY 4 OF SET;
		DATA_RO: ARRAY 4 OF SET;
	END;

	BankCtrlReg = POINTER {UNSAFE,UNTRACED} TO RECORD
		DIRM, OEN, INT_MASK, INT_EN, INT_DIS, INT_STAT, INT_TYPE, INT_POLARITY, INT_ANY: SET;
	END;

VAR
	bankCtrlRegs: ARRAY 4 OF BankCtrlReg;
	dataRegs: DataReg;
	i: LONGINT;

	(** Set the direction of 'gpio' to output if 'out' is TRUE and to input otherwise. *)
	PROCEDURE SetDirection * (gpio: LONGINT; out: BOOLEAN);
	VAR
		bank, ofs: LONGINT;
	BEGIN
		GetBankOfs(gpio, bank, ofs);
		IF (bank < 0) & (ofs < 0) THEN RETURN END;

		IF out THEN
			INCL(bankCtrlRegs[bank].DIRM, ofs)
		ELSE
			EXCL(bankCtrlRegs[bank].DIRM, ofs)
		END
	END SetDirection;

	(** If 'on' enable (if 'off' disable) output for 'gpio'. 'gpio' direction must be set to output prior to this call. *)
	PROCEDURE EnableOutput * (gpio: LONGINT; on: BOOLEAN);
	VAR
		bank, ofs: LONGINT;
	BEGIN
		GetBankOfs(gpio, bank, ofs);
		IF (bank < 0) & (ofs < 0) THEN RETURN END;

		IF on THEN
			INCL(bankCtrlRegs[bank].OEN, ofs)
		ELSE
			EXCL(bankCtrlRegs[bank].OEN, ofs)
		END
	END EnableOutput;

	(** Set the data of output GPIO 'gpio' to 'data' (TRUE for high, FALSE for low). *)
	PROCEDURE SetData * (gpio: LONGINT; data: BOOLEAN);
	VAR
		bank, ofs: LONGINT;
	BEGIN
		GetBankOfs(gpio, bank, ofs);
		IF (bank < 0) & (ofs < 0) THEN RETURN END;

		IF data THEN
			INCL(dataRegs.DATA[bank], ofs)
		ELSE
			EXCL(dataRegs.DATA[bank], ofs)
		END
	END SetData;

	(** Get data of input GPIO 'gpio': TRUE for high, FALSE for low. *)
	PROCEDURE GetData * (gpio: LONGINT): BOOLEAN;
	VAR
		bank, ofs: LONGINT;
	BEGIN
		GetBankOfs(gpio, bank, ofs);
		IF (bank < 0) & (ofs < 0) THEN HALT(100) END;

		RETURN ofs IN dataRegs.DATA_RO[bank]
	END GetData;

	PROCEDURE GetBankOfs (gpio: LONGINT; VAR bank, ofs: LONGINT);
	BEGIN
		IF gpio < 54 THEN
			bank := gpio DIV 32;
			ofs := gpio MOD 32
		ELSE
			(*! TODO: implement *)
		END;
		bank := -1;
		ofs := -1
	END GetBankOfs;

BEGIN
	dataRegs := Platform.GpioData;
	FOR i := 0 TO Platform.GpioBankNb - 1 DO
		bankCtrlRegs[i] := Platform.GpioBank[i]
	END
END Gpio.
