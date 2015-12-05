(* 
	ActiveCells Runtime context to run Active Cells as Active Objects
	Felix Friedrich, ETH Zürich, 2015
*)
module ActiveCellsRunner;

import ActiveCellsRuntime, Commands, Modules;
const
	EnableTrace = true;
	
type 
	Cell = object 
	var
		isCellnet-:boolean; 
	end Cell;
	
	Fifo=object
	var
		data: array 64 of longint;
		inPos, outPos: longint; length: longint;
		inPort: Port; outPort: Port;
		
		procedure &Init(outP: Port; inP: Port; length: longint);
		begin
			inPos := 0; outPos := 0; self.length := length;
			assert(length < len(data));
			inPort := inP; outPort := outP;
			inPort.SetFifo(self); outPort.SetFifo(self);
		end Init;
		
		procedure Put(value: longint);
		begin{EXCLUSIVE}
			await((inPos+1) mod len(data) # outPos);
			data[inPos] := value;
			inc(inPos); inPos := inPos mod len(data);
		end Put;
		
		procedure Get(var value: longint);
		begin{EXCLUSIVE}
			await(inPos # outPos);
			value := data[outPos];
			inc(outPos); outPos := outPos mod len(data);
		end Get;

	end Fifo;

	Port= object
	var
		fifo-: Fifo;
		delegatedTo-: Port;
		inout-: set;
	
		procedure & InitPort(inout: set; width: longint);
		begin
			fifo := nil; 
			delegatedTo := nil; 
			self.inout := inout;
			delegatedTo := nil;
		end InitPort;
		
		procedure Delegate(toPort: Port);
		begin{EXCLUSIVE}
			delegatedTo := toPort;
		end Delegate;
		
		procedure SetFifo(f: Fifo);
		begin{EXCLUSIVE}
			if delegatedTo # nil then
				delegatedTo.SetFifo(f)
			else
				fifo := f;
			end;
		end SetFifo
		
		procedure Send(value: longint);
		begin
			begin{EXCLUSIVE}
				await((fifo # nil) or (delegatedTo # nil));
			end;
			if delegatedTo # nil then
				delegatedTo.Send(value)
			else
				fifo.Put(value);
			end;
		end Send;
		
		procedure Receive(var value: longint);
		begin
			begin{EXCLUSIVE}
				await((fifo # nil) or (delegatedTo # nil));
			end;
			if delegatedTo # nil then	
				delegatedTo.Receive(value)
			else
				fifo.Get(value);
			end;
		end Receive;
		
	end Port;

	(* generic context object that can be used by implementers of the active cells runtime *)
	Context*= object (ActiveCellsRuntime.Context)
	
		procedure Allocate(scope: any; var c: any; t: Modules.TypeDesc; const name: array of char; isCellnet, isEngine: boolean);
		var cel: Cell;
		begin
			new(cel); c := cel;
			cel.isCellnet := isCellnet;
		end Allocate;
		
		procedure AddPort*(c: any; var p: any; const name: array of char; inout: set; width: longint);
		var por: Port;
		begin
			if EnableTrace then trace(c,p,name, inout, width); end;
			new(por,inout,width); p := por;
		end AddPort;

		procedure AddPortArray*(c: any; var ports: any; const name: array of char; inout: set; width: longint; const lens: array of longint);
		type
			Ports1d = array of any;
			Ports2d = array of Ports1d;
			Ports3d = array of Ports2d;
		var
			p: any;
			p1d: pointer to Ports1d;
			p2d: pointer to Ports2d;
			p3d: pointer to Ports3d;
			i, i0, i1, i2: longint;
		begin
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
			if EnableTrace then trace(name, inout, width, len(ports)); end;
			for i := 0 to len(ports)-1 do
				AddPort(c, ports[i], name, inout, width);
			end;
		end AddStaticPortArray;

		procedure Connect*(outPort, inPort: any; depth: longint);
		var fifo: Fifo;
		begin
			if EnableTrace then trace(outPort, inPort, outPort, inPort, depth); end;
			new(fifo, outPort(Port), inPort(Port), depth);
		end Connect;

		procedure Delegate*(netPort: any; cellPort: any);
		begin
			if EnableTrace then trace(netPort, cellPort); end;
			netPort(Port).Delegate(cellPort(Port));
		end Delegate;

		procedure Start*(c: any; proc: procedure{DELEGATE});
		var launcher: ActiveCellsRuntime.Launcher;
		begin
			if EnableTrace then trace(c, proc); end;
			if c(Cell).isCellnet then (* synchronous *)
				proc
			else
				new(launcher, self); (* asynchronous *)
				launcher.Start(proc, false);
			end;
		end Start;

		procedure Send*(p: any; value: longint);
		begin
			if EnableTrace then trace(p, value); end;
			p(Port).Send(value);
		end Send;

		procedure Receive*(p: any; var value: longint);
		begin
			if EnableTrace then trace(p, value); end;
			p(Port).Receive(value);
		end Receive;
		
	end Context;
	
	procedure Execute*(context: Commands.Context);
	var myContext: Context; cmd: array 256 of char;
	begin
		new(myContext);
		if context.arg.GetString(cmd) then
			ActiveCellsRuntime.Execute(cmd, myContext, nil)
		end;
	end Execute;

end ActiveCellsRunner.


ActiveCellsRunner.Execute 