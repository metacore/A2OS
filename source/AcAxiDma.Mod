(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2013-2018
	PURPOSE: ActiveCells AXI DMA component driver
*)
MODULE AcAxiDma;

IMPORT
	Channels;

CONST
	CmdSetAddr = 1*2;
	CmdSetCount = 2*2;
	CmdSetBurstLen = 3*2;
	CmdSetWrapFlag = 4*2;
	CmdGetAddr = 5*2;
	CmdGetCount = 6*2;
	CmdGetPendingFlag = 7*2;

TYPE

	Address* = LONGINT;
	Size* = LONGINT;

	(**
		ActiveCells AXI DMA component controller
	*)
	Controller* = OBJECT
	VAR
		cfgCmd: PORT OUT;
		cfgData: PORT OUT;
		status: PORT IN;

		dataSize-: WORD; (** size of one data element in bytes *)
		addr-: Address; (** DMA transfer starting address *)
		count-: Size; (** DMA transfer size in number of elements *)
		maxBurstLen-: WORD; (** maximal burst length in number of elements *)
		burstLen-: WORD; (** current burst length in number of elements *)
		wrap-: BOOLEAN; (** TRUE in case of a recurrent transfer *)

		PROCEDURE &InitController*(cfgCmdOut, cfgDataOut: PORT OUT; statusInp: PORT IN; dataSize, maxBurstLen: WORD);
		BEGIN
			ASSERT(dataSize > 0);
			ASSERT(maxBurstLen > 0);

			cfgCmd := cfgCmdOut;
			cfgData := cfgDataOut;
			status := statusInp;
			SELF.dataSize := dataSize;
			SELF.maxBurstLen := maxBurstLen;

			Stop;
			SetCount(0);
			SetBurstLen(maxBurstLen);
			SetWrap(FALSE);
		END InitController;

		PROCEDURE SetAddr*(startAddr: Address);
		BEGIN{EXCLUSIVE}
			cfgCmd << CmdSetAddr;
			cfgData << startAddr;
			addr := startAddr;
		END SetAddr;

		PROCEDURE SetCount*(transferCount: Size);
		BEGIN{EXCLUSIVE}
			cfgCmd << CmdSetCount;
			cfgData << transferCount;
			count := transferCount;
		END SetCount;

		PROCEDURE SetBurstLen*(len: WORD);
		VAR d: LONGINT;
		BEGIN{EXCLUSIVE}
			d := (burstLen-1) + LSH(LONGINT(burstLen)*dataSize,4);
			cfgCmd << CmdSetBurstLen;
			cfgData << d;
			burstLen := len;
		END SetBurstLen;

		PROCEDURE SetWrap*(enableWrap: BOOLEAN);
		BEGIN{EXCLUSIVE}
			cfgCmd << CmdSetWrapFlag;
			IF enableWrap THEN cfgData << 1; ELSE cfgData << 0; END;
			wrap := enableWrap;
		END SetWrap;

		PROCEDURE Start*();
		BEGIN{EXCLUSIVE}
			IF SELF IS WriteController THEN
				cfgCmd << 0;
			ELSE
				cfgCmd << 1;
			END;
			cfgData << 1;
		END Start;

		PROCEDURE Stop*();
		BEGIN{EXCLUSIVE}
			cfgCmd << 0;
			cfgData << 0;
		END Stop;

		PROCEDURE GetCurrentAddr*(): Address;
		VAR addr: Address;
		BEGIN{EXCLUSIVE}
			cfgCmd << CmdGetAddr;
			cfgData << 0;
			addr << status;
			RETURN addr;
		END GetCurrentAddr;

		PROCEDURE GetCurrentCount*(): Address;
		VAR count: Address;
		BEGIN{EXCLUSIVE}
			cfgCmd << CmdGetCount;
			cfgData << 0;
			count << status;
			RETURN count;
		END GetCurrentCount;

		PROCEDURE IsTransferPending*(): BOOLEAN;
		VAR d: LONGINT;
		BEGIN{EXCLUSIVE}
			cfgCmd << CmdGetPendingFlag;
			cfgData << 0;
			d << status;
			RETURN (d MOD 2) = 1;
		END IsTransferPending;

	END Controller;

	ReadController* = OBJECT(Controller)
	END ReadController;

	WriteController* = OBJECT(Controller)
	END WriteController;

END AcAxiDma.
