(*
	ActiveCells Runtime context to run Active Cells as Active Objects
	Felix Friedrich, ETH Zürich, 2015
*)
module ActiveCellsRunner;

import system,ActiveCellsRuntime, Commands, Modules,D:=Diagnostics;


const
	EnableTrace = false;

type
	Cell = object
	var
		isCellnet:boolean;
	end Cell;

	Fifo=object
	var
		data: array 8*1024 of system.byte;   
(*		inPos, outPos: longint; *)
		length: longint;  
		rdPos,numEle: longint;

		inPort: Port; outPort: Port;

		procedure &Init(outP: Port; inP: Port; length: longint);
		begin
			(*inPos := 0; outPos := 0; *)
			rdPos:=0; 
			numEle:=0;
			self.length := length; (*for some reason this is -1 usually. don't trust it!*)
			assert(length < len(data));
			inPort := inP; outPort := outP;
			inPort.SetFifo(self); outPort.SetFifo(self);
		end Init;

		procedure Put(value: longint);
		begin{EXCLUSIVE}
			halt(100);(*broken+deprecated*)
		end Put;

		procedure Get(var value: longint);
		begin{EXCLUSIVE}
			halt(100); (*broken+deprecated*)
		end Get;


		(*todo: instead of looping byte by byte, figure out how much we can safely copy over and just do that.*)
		procedure BulkPut(const value: array of system.byte);
		var i: longint;
		numCopy, writePos: longint;
		begin{EXCLUSIVE}
			(*because of the exclusive semantics, this bulk put will fill the entire buffer before any get operation has a chance to run*)
			
			i:=0;
			while i<len(value) do
				await(numEle<len(data));
				writePos:=(rdPos+numEle) mod len(data);
				
				numCopy:= len(data)-numEle;  (*total free space*)
				numCopy:= min( numCopy, len(data)- writePos);(* if free space wraps around, only copy into space from write  pointer to top*)
				numCopy :=min(numCopy,len(value)-i ); (*copy at most as much data as is left over.*)
				(*trace(i,rdPos,writePos,numCopy,numEle,len(value),len(data));*)
				
				system.move(addressof(  value[i] ) , addressof ( data[writePos] ), numCopy) ;
				numEle:=numEle+numCopy;
				i:=i+numCopy;
			end;
			
			(*
			(*confirmed working using lengths*)
			for i:=0 to len(value)-1 do
				await(numEle<len(data));
				data[(rdPos+numEle) mod len(data)]:=value[i];
				inc(numEle);
			end;*)
		
			(*
			(*old version using pointer comparision. effectively makes the buffer 1 smaller than allocated *)
			for i:=0 to len(value)-1 do  
				await((inPos+1) mod len(data) # outPos);
				data[inPos]:=value[i];
				inc(inPos); inPos := inPos mod len(data);
			end;			
			*)
			
		end BulkPut;

		procedure BulkGet(var value: array of system.byte);
		var
		
			i: longint;
			numCopy: longint;
		begin{EXCLUSIVE}
			(*because of the exclusive semantics, this bulk get will empty the entire buffer before any put operation has a chance to run*)
			
			i:=0; (*pointer into the value array of the receiver*)
			while i<len(value) do
				await(numEle>0);
				numCopy:= min(numEle, len(data)-rdPos); (*total valid data or until it wraps around*)
				numCopy:=min(numCopy,len(value)-i); (*don't copy more than there's space in the receiver*)
				(*trace(i,rdPos,numCopy,numEle,len(value),len(data));*)
				
				system.move( addressof(data[rdPos]), addressof(value[i]),numCopy);
				rdPos:=(rdPos+numCopy) mod len(data);
				numEle:=numEle-numCopy;
				i:=i+numCopy;
			end;
			
			(*(*confirmed working using lengths*)
			for i:=0 to len(value) -1 do
				await(numEle>0);
				value[i]:=data[rdPos];
				inc(rdPos);rdPos:=rdPos mod len(data);
				dec(numEle);
			end;*)
			
			(*
			(*old version using pinter comparison. effectively makes the buffer 1 smaller than allocated*)
			for i:=0 to len(value)-1 do
				await(inPos#outPos);
				value[i]:=data[outPos];
				inc(outPos);outPos:=outPos mod len(data);
			end;*)
			
		end BulkGet;

	end Fifo;

	Port= object
	var
		fifo-: Fifo;
		delegatedTo-: Port;
		inout-: set;
		
		owner: Cell;

		procedure & InitPort(inout: set; width: longint);
		begin
			fifo := nil;
			delegatedTo := nil;
			self.inout := inout;
			delegatedTo := nil;
		end InitPort;

		procedure Delegate(toPort: Port);
		begin(*{EXCLUSIVE}*)
			delegatedTo := toPort;
		end Delegate;

		procedure SetFifo(f: Fifo);
		begin(*{EXCLUSIVE}*)
			if delegatedTo # nil then
				delegatedTo.SetFifo(f)
			else
				fifo := f;
			end;
		end SetFifo;

		procedure Send(value: longint);
		begin
			(*begin{EXCLUSIVE}
				await((fifo # nil) or (delegatedTo # nil));
			end;*)
			if delegatedTo # nil then
				delegatedTo.Send(value)
			else
				(*fifo.Put(value);*)
				fifo.BulkPut(value);
			end;
		end Send;

		procedure BulkSend(const value: array of system.byte);
		begin
			(*begin{EXCLUSIVE}
				await((fifo # nil) or (delegatedTo # nil));
			end;*)
			if delegatedTo # nil then
				delegatedTo.BulkSend(value)
			else
				fifo.BulkPut(value);
			end;
		end BulkSend;

		procedure Receive(var value: longint);
		begin
			(*begin{EXCLUSIVE}
				await((fifo # nil) or (delegatedTo # nil));
			end;*)
			if delegatedTo # nil then
				delegatedTo.Receive(value)
			else
				(*fifo.Get(value);*)
				fifo.BulkGet(value);
			end;
		end Receive;

		procedure BulkReceive(var value: array of system.byte);
		begin
			(*begin{EXCLUSIVE}
				await((fifo # nil) or (delegatedTo # nil));
			end;*)
			if delegatedTo # nil then
				delegatedTo.BulkReceive(value)
			else
				fifo.BulkGet(value);
			end;
		end BulkReceive;

	end Port;

	(* generic context object that can be used by implementers of the active cells runtime *)
	Context*= object (ActiveCellsRuntime.Context)

		procedure Allocate(scope: any; var c: any; t: Modules.TypeDesc; const name: array of char; isCellnet, isEngine: boolean);
		var cel: Cell;
		begin
			if res # 0 then return; end; (*! do not do anything in case of an error *)
			new(cel); c := cel;
			cel.isCellnet := isCellnet;
			(*if scope # nil then cel.scope := scope(Cell); end;*)
		end Allocate;

		procedure AddPort*(c: any; var p: any; const name: array of char; inout: set; width: longint);
		var por: Port;
		begin
			if res # 0 then return; end; (*! do not do anything in case of an error *)
			if EnableTrace then trace(c,p,name, inout, width); end;
			new(por,inout,width); por.owner := c(Cell);
			p := por;
		end AddPort;

		procedure AddPortArray*(c: any; var ports: any; const name: array of char; inout: set; width: longint; const lens: array of longint);
		type
			Ports1d = array of any;
			Ports2d = array of Ports1d;
			Ports3d = array of Ports2d;
		var
			p1d: pointer to Ports1d;
			p2d: pointer to Ports2d;
			p3d: pointer to Ports3d;
			i0, i1, i2: longint;
		begin
			if res # 0 then return; end; (*! do not do anything in case of an error *)
			if EnableTrace then trace(name, inout, width, len(lens)); end;
			(*
				There is a slot in the respective cell that can hold a pointer to an n-dimensional array of ports.
				This slot is used for the pointer but is not directly accessible any more by the runtime.
				So, if information about the array of ports is further required, some metadata should be kept
				here. The following is the absolute minimal.
			*)
			case len(lens,0) of
				|1:
					new(p1d,lens[0]);
					for i0 := lens[0]-1 to 0 by -1 do (*! add ports in reverse order to be consistent with what the runtime does *)
						AddPort(c,p1d[i0],name,inout,width);
					end;
					ports := p1d;
				|2:
					new(p2d,lens[0],lens[1]);
					for i0 := lens[0]-1 to 0 by -1 do (*! add ports in reverse order to be consistent with what the runtime does *)
						for i1 := lens[1]-1 to 0 by -1 do
							AddPort(c,p2d[i0,i1],name,inout,width);
						end;
					end;
					ports := p2d;
				|3:
					new(p3d,lens[0],lens[1],lens[2]);
					for i0 := lens[0]-1 to 0 by -1 do (*! add ports in reverse order to be consistent with what the runtime does *)
						for i1 := lens[1]-1 to 0 by -1 do
							for i2 := lens[2]-1 to 0 by -1 do
								AddPort(c,p3d[i0,i1,i2],name,inout,width);
							end;
						end;
					end;
					ports := p3d;
			else
				halt(200);
			end;
		end AddPortArray;

		procedure AddStaticPortArray*(c: any; var ports: array of any; const name: array of char; inout: set; width: longint);
		var i: longint;
		begin
			if res # 0 then return; end; (*! do not do anything in case of an error *)
			if EnableTrace then trace(name, inout, width, len(ports)); end;
			for i := 0 to len(ports)-1 do
				AddPort(c, ports[i], name, inout, width);
			end;
		end AddStaticPortArray;

		procedure Connect*(outPort, inPort: any; depth: longint);
		var fifo: Fifo;
		begin
			if res # 0 then return; end; (*! do not do anything in case of an error *)
			if EnableTrace then trace(outPort, inPort, outPort, inPort, depth); end;
			new(fifo, outPort(Port), inPort(Port), depth);
		end Connect;

		procedure Delegate*(netPort: any; cellPort: any);
		begin
			if res # 0 then return; end; (*! do not do anything in case of an error *)
			if EnableTrace then trace(netPort, cellPort); end;
			(*! check correctness of delegation which is not 100% guaranteed by the operator ">>" *)
			if ~netPort(Port).owner.isCellnet or (cellPort(Port).owner = netPort(Port).owner) then
				res := -1;
				return;
			end;
			netPort(Port).Delegate(cellPort(Port));
		end Delegate;

		procedure Start*(c: any; proc: procedure{DELEGATE});
		var launcher: ActiveCellsRuntime.Launcher;
		begin
			if res # 0 then return; end; (*! do not do anything in case of an error *)
			if EnableTrace then trace(c, proc); end;
			if c(Cell).isCellnet then (* synchronous *)
				proc
			else
				new(launcher, self); (* asynchronous *)
				launcher.Start(proc, false);
				if launcher.error & (res = 0) then res := -1; end;
			end;
		end Start;

		procedure Send*(p: any; value: longint);
		begin
			if EnableTrace then trace(p, value); end;
			p(Port).Send(value);
		end Send;

		procedure BulkSend*(p:any; const value: array of system.byte);
		begin
			if EnableTrace then trace(p, 'bulk send'); end;
			p(Port).BulkSend(value);
		end BulkSend;

		procedure Receive*(p: any; var value: longint);
		begin
			if EnableTrace then trace(p, value); end;
			p(Port).Receive(value);
		end Receive;

		procedure BulkReceive*(p:any; var value: array of system.byte);
		begin
			if EnableTrace then trace(p, 'bulk receive'); end;
			p(Port).BulkReceive(value);
		end BulkReceive;

	end Context;


	procedure Execute*(context: Commands.Context);
	var myContext: Context; cmd: array 256 of char;
		diag: D.StreamDiagnostics;
	begin
		new(myContext);
		new(diag,context.out);
		if context.arg.GetString(cmd) then
			ActiveCellsRuntime.Execute(cmd, myContext, diag)
		end;
	end Execute;

	procedure Stop*(context: Commands.Context);
	var myContext: Context; cmd: array 256 of char;
		diag: D.StreamDiagnostics;
	begin
		new(myContext);
		new(diag,context.out);
		if context.arg.GetString(cmd) then
			(*todo*)
		end;
	end Stop;

end ActiveCellsRunner.


ActiveCellsRunner.Execute 