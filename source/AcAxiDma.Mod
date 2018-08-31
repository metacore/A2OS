(** 
	AUTHOR: Alexey Morozov, HighDim GmbH, 2013-2018
	PURPOSE: ActiveCells AXI DMA component driver
*)
module AcAxiDma;

import
	Channels;

const
	CmdSetAddr = 1*2;
	CmdSetCount = 2*2;
	CmdSetBurstLen = 3*2;
	CmdSetWrapFlag = 4*2;
	CmdGetAddr = 5*2;
	CmdGetCount = 6*2;
	CmdGetPendingFlag = 7*2;

type

	Address = longint;

	Controller* = record
		cfgCmd-: port out;
		cfgData-: port out;
		status-: port in;

		dataSize-: longint; (** size of one data element in bytes *)
		addr-: Address;
		count-: Address;
		maxBurstLen-: longint;
		burstLen-: longint;
		wrap-: boolean;

		transferPending: boolean;
	end;
	
	ReadController* = record(Controller)
	end;
	
	WriteController* = record(Controller)
	end;

	procedure InitController*(var ctl: Controller; cfgCmd, cfgData: port out; status: port in; dataSize, maxBurstLen: longint);
	begin
		ctl.cfgCmd := cfgCmd;
		ctl.cfgData := cfgData;
		ctl.status := status;
		ctl.dataSize := dataSize;
		ctl.maxBurstLen := maxBurstLen;
		
		Stop(ctl);
		SetCount(ctl,0);
		SetBurstLen(ctl,maxBurstLen);
		SetWrap(ctl,false);
	end InitController;

	procedure SetAddr*(var ctl: Controller; addr: Address);
	begin
		ctl.cfgCmd << CmdSetAddr;
		ctl.cfgData << addr;
		ctl.addr := addr;
	end SetAddr;

	procedure SetCount*(var ctl: Controller; count: Address);
	begin
		ctl.cfgCmd << CmdSetCount;
		ctl.cfgData << count;
		ctl.count := count;
	end SetCount;

	procedure SetBurstLen*(var ctl: Controller; burstLen: longint);
	var d: longint;
	begin
		d := (burstLen-1) + lsh(burstLen*ctl.dataSize,4);
		ctl.cfgCmd << CmdSetBurstLen;
		ctl.cfgData << d;
		ctl.burstLen := burstLen;
	end SetBurstLen;

	procedure SetWrap*(var ctl: Controller; wrap: boolean);
	begin
		ctl.cfgCmd << CmdSetWrapFlag;
		if wrap then ctl.cfgData << 1; else ctl.cfgData << 0; end;
		ctl.wrap := wrap;
	end SetWrap;

	procedure Start*(var ctl: Controller);
	begin
		ctl.cfgCmd << 1;
		ctl.cfgData << 0;
		ctl.transferPending := true;
	end Start;

	procedure Stop*(var ctl: Controller);
	begin
		ctl.cfgCmd << 0;
		ctl.cfgData << 0;
		ctl.transferPending := false;
	end Stop;

	procedure GetCurrentAddr*(var ctl: Controller): Address;
	var addr: Address;
	begin
		ctl.cfgCmd << CmdGetAddr;
		ctl.cfgData << 0;
		addr << ctl.status;
		return addr;
	end GetCurrentAddr;

	procedure GetCurrentCount*(var ctl: Controller): Address;
	var count: Address;
	begin
		ctl.cfgCmd << CmdGetCount;
		ctl.cfgData << 0;
		count << ctl.status;
		return count;
	end GetCurrentCount;

	procedure TransferPending*(var ctl: Controller): boolean;
	var d: longint;
	begin
		if ctl.transferPending then
			ctl.cfgCmd << CmdGetPendingFlag;
			ctl.cfgData << 0;
			d << ctl.status;
			ctl.transferPending := d mod 2 = 1;
		end;
		return ctl.transferPending;
	end TransferPending;

end AcAxiDma.
