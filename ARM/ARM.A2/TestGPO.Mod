module TestGpo;
import SYSTEM, Trace;

const
	AxiBaseAddr0  = address(07F000000H); (* base address of first AXI interface *)
	ChanOffset  = 256*4; (* channel offset in bytes *)
	InpValidOffset = 0; (* offset for accessing input valid flag of a channel *)
	OutReadyOffset = 4; (* offset for accessing output ready flag of a channel *)
	DataOffset = 8; (* offset for accessing channel data *)
	
	Chan0Addr = AxiBaseAddr0 + 0*ChanOffset; 
	Chan1Addr = AxiBaseAddr0 + 1*ChanOffset;
	
	GpoPortAddr = Chan0Addr;
	
var
	i: longint; inp: longint;
begin
	loop
		for i := 0 to 255 do
		Trace.String("gpo"); Trace.Int(i,1); 
		SYSTEM.GET(GpoPortAddr + 4, inp); 
		SYSTEM.PUT(GpoPortAddr,i);
		end;
	end;
end TestGpo.

Controller = cell{Arch="TRM",CodeMemorySize=4096,DataMemorySize=2048}
	(
		input: port in;
		output: port out;

		ioCfgOut: port out;
		ioCfgInp: port in;

		timerCmdOut: port out;
		timerInp: port in
	)