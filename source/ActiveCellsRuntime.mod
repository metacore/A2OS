(** Active Cells Runtime Base Code for Variations of ActiveCellsRuntime Implementations  
	Felix Friedrich, ETH Z 2015
*)
module ActiveCellsRuntime;

import
	system, Heaps, Modules, Diagnostics, Strings, Objects, Reflection, Commands;

const
	EnableTrace* = false;

type
	(* do not inherit from this object -- not supported. This object contains hidden fields instantiated by the compiler that would be lost. *)
	Cell* = object (* must be exported for compiler *)
	var
		c: any;
	end Cell;

	Context*= object
	var
		topNet-: any; (** top-level CELLNET object specific to this runtime context *)
		finishedAssembly-: boolean; (** assigned to TRUE after the whole architecture has been assembled *)
		res*: longint; (** error code, 0 in case of success *)
		
		procedure Allocate*(scope: any; var c: any; t: Modules.TypeDesc; const name: array of char; isCellNet, isEngine: boolean);
		end Allocate;
		
		procedure AddPort*(c: any; var p: any; const name: array of char; inout: set; width: longint);
		end AddPort;
		
		procedure AddPortArray*(c: any; var ports: any; const name: array of char; inout: set; width: longint; const lens: array of longint);
		end AddPortArray;

		procedure AddStaticPortArray*(c: any; var ports: array of any; const name: array of char; inout: set; width: longint);
		end AddStaticPortArray;

		procedure AddPortIntegerProperty*(p: any; const name: array of char; value: longint);
		end AddPortIntegerProperty;

		procedure AddFlagProperty*(c: any; const name: array of char);
		end AddFlagProperty;

		procedure AddStringProperty*(c: any; const name: array of char; const value: array of char);
		end AddStringProperty;

		procedure AddIntegerProperty*(c: any; const name: array of char; value: longint);
		end AddIntegerProperty;

		procedure AddBooleanProperty*(c: any; const name: array of char; value: boolean);
		end AddBooleanProperty;

		procedure AddRealProperty*(c: any; const name: array of char; value: longreal);
		end AddRealProperty;

		procedure AddSetProperty*(c: any; const name: array of char; s: set);
		end AddSetProperty;

		procedure FinishedProperties*(var c: any);
		end FinishedProperties;

		procedure Connect*(outPort, inPort: any; depth: longint);
		end Connect;

		procedure Delegate*(netPort: any; cellPort: any);
		end Delegate;

		procedure Start*(c: any; proc: procedure{DELEGATE});
		end Start;

		procedure Send*(p: any; value: longint);
		end Send;
		
		procedure BulkSend*(p: any; const value: array of system.byte);
		end BulkSend;
		
		procedure SendNonBlocking*(p: any; value: longint): boolean;
		end SendNonBlocking;

		procedure Receive*(p: any; var value: longint);
		end Receive;
		
		procedure BulkReceive*(p: any; var value: array of system.byte);
		end BulkReceive;
		
		procedure ReceiveNonBlocking*(p: any; var value: longint): boolean;
		end ReceiveNonBlocking;
		
		(* called in Execute after the architecture is fully assembled *)
		procedure FinishedAssembly();
		begin{EXCLUSIVE}
			finishedAssembly := true;
		end FinishedAssembly;

		procedure WaitUntilFinishedAssembly();
		begin{EXCLUSIVE}
			await(finishedAssembly or (res # 0));
		end WaitUntilFinishedAssembly;
			
	end Context;
	
	Launcher* = object
	var 
		proc: procedure {DELEGATE};
		context: Context;
		finished, delayedStart: boolean;
		error-: boolean;
		
		procedure & Init*(context: Context);
		begin
			self.context := context;
			proc := nil; 
			finished := false;
		end Init;
		
		procedure Start*(p: procedure{DELEGATE}; doWait: boolean);
		begin{EXCLUSIVE}
			proc := p;
			if ~doWait then delayedStart := true; end; (* delay actual start until the whole architecture is fully assembled *)
			await(~doWait or finished);
		end Start;
		
	begin{ACTIVE}
		begin{EXCLUSIVE}
			await(proc # nil);
		end;
		if delayedStart then
			context.WaitUntilFinishedAssembly;
		end;
		if context.res = 0 then
			proc;
		end;
		begin{EXCLUSIVE}
			finished := true
		end;
		finally
		begin{EXCLUSIVE}
			if ~finished then
				error := true;
				finished := true;
			end;
		end;
	end Launcher;
	
	procedure GetContext(): Context;
	begin
		return Objects.ActiveObject()(Launcher).context;
	end GetContext;
	
	procedure AllocateOnContext(context: Context;scope: Cell; var c: Cell; tag: address; const name: array of char; isCellnet, isEngine: boolean);
	var
		a: any;
		typeInfo: Modules.TypeDesc;
		s, ac: any;
	begin

		(* allocation of cells must use the tag provided, it contains all internally stored metadata *)
		Heaps.NewRec(a, tag, false);
		system.get(tag-4,typeInfo);

		if EnableTrace then trace(scope, c, typeInfo, name, isCellnet, isEngine); end;
		
		if scope # nil then s := scope.c else s := nil end;
		if c # nil then ac := c.c else ac := nil end;

		c := a(Cell);
		context.Allocate(s, ac, typeInfo, name, isCellnet, isEngine);
		c.c := ac;
		
		if scope = nil then context.topNet := ac; end;
	end AllocateOnContext;
	

	procedure Allocate*(scope: Cell; var c: Cell; tag: address; const name: array of char; isCellnet, isEngine: boolean);
	begin
		AllocateOnContext(GetContext(), scope, c, tag, name, isCellnet, isEngine);
	end Allocate;

	procedure AddPort*(c: Cell; var p: any; const name: array of char; inout: set; width: longint);
	begin
		if EnableTrace then trace(c,p,name, inout, width); end;
		GetContext().AddPort(c.c, p, name, inout, width);
	end AddPort;

	procedure AddPortArray*(c: Cell; var ports: any; const name: array of char; inout: set; width: longint; const lens: array of longint);
	begin
		if EnableTrace then trace(name, inout, width, len(lens)); end;
		GetContext().AddPortArray(c.c, ports, name, inout, width, lens);
	end AddPortArray;

	procedure AddStaticPortArray*(c: Cell; var ports: array of any; const name: array of char; inout: set; width: longint);
	begin
		if EnableTrace then trace(name, inout, width, len(ports)); end;
		GetContext().AddStaticPortArray(c.c, ports, name, inout, width);
	end AddStaticPortArray;

	procedure AddPortIntegerProperty*(p: any; const name: array of char; value: longint);
	begin
		if EnableTrace then trace(p, name, value); end;
		GetContext().AddPortIntegerProperty(p,name,value);
	end AddPortIntegerProperty;

	procedure AddFlagProperty*(c: Cell; const name: array of char);
	begin
		if EnableTrace then trace(c, name); end;
		GetContext().AddFlagProperty(c.c, name);
	end AddFlagProperty;

	procedure AddStringProperty*(c: Cell; const name: array of char; var newValue: array of char; const value: array of char);
	begin
		if EnableTrace then trace(c, name, newValue, value); end;
		copy(value, newValue);
		GetContext().AddStringProperty(c.c, name, value);
	end AddStringProperty;

	procedure AddIntegerProperty*(c: Cell; const name: array of char; var newValue: longint; value: longint);
	begin
		if EnableTrace then trace(c, name, newValue, value); end;
		newValue := value;
		GetContext().AddIntegerProperty(c.c, name, value);
	end AddIntegerProperty;

	procedure AddBooleanProperty*(c: Cell; const name: array of char; var newValue: boolean; value: boolean);
	begin
		if EnableTrace then trace(c, name, newValue, value); end;
		newValue := value;
		GetContext().AddBooleanProperty(c.c, name, value);
	end AddBooleanProperty;

	procedure AddRealProperty*(c: Cell; const name: array of char; var newValue: longreal; value: longreal);
	begin
		if EnableTrace then trace(c, name, newValue, value, entier(value)); end;
		newValue := value;
		GetContext().AddRealProperty(c.c, name, value);
	end AddRealProperty;

	procedure AddSetProperty*(c: Cell; const name: array of char; var newValue: set; value: set);
	begin
		if EnableTrace then trace(c, name, newValue, value); end;
		newValue := value;
		GetContext().AddSetProperty(c.c, name, value);
	end AddSetProperty;

	procedure FinishedProperties*(c: Cell);
	begin
		if EnableTrace then trace(c); end;
		GetContext().FinishedProperties(c.c);
	end FinishedProperties;

	procedure Connect*(outPort, inPort: any; depth: longint);
	begin
		if EnableTrace then trace(outPort, inPort, outPort, inPort, depth); end;
		GetContext().Connect(outPort, inPort, depth);
	end Connect;

	procedure Delegate*(netPort: any; cellPort: any);
	begin
		if EnableTrace then trace(netPort, cellPort); end;
		GetContext().Delegate(netPort, cellPort);
	end Delegate;

	procedure Start*(c: Cell; proc: procedure{DELEGATE});
	begin
		if EnableTrace then trace(c, proc); end;
		GetContext().Start(c.c, proc);
	end Start;
	
	procedure Send*(p: any; value: longint);
	begin
		GetContext().Send(p, value);
	end Send;
	
	procedure BulkSend*(p: any; const value: array of system.byte);
	begin
		GetContext().BulkSend(p,value);
	end BulkSend;
	
	procedure SendNonBlocking*(p: any; value: longint): boolean;
	begin
		return GetContext().SendNonBlocking(p, value);
	end SendNonBlocking;

	procedure Receive*(p: any; var value: longint);
	begin
		GetContext().Receive(p, value);
	end Receive;
	
	procedure BulkReceive*(p: any; var value: array of system.byte);
	begin
		GetContext().BulkReceive(p,value);
	end BulkReceive;
	
	procedure ReceiveNonBlocking*(p: any; var value: longint): boolean;
	begin
		return GetContext().ReceiveNonBlocking(p, value);
	end ReceiveNonBlocking;

type
	Module = pointer to record
		next: Module;
		checked, imports: boolean;
		m: Modules.Module
	end;
		
	procedure Find(root: Module; m: Modules.Module): Module;
	begin
		while (root # nil) & (root.m # m) do root := root.next end;
		return root
	end Find;

	procedure Imports(root, m: Module; const name: array of char): boolean;
	var i: longint;
	begin
		if ~m.checked then
			if m.m.name # name then
				i := 0;
				while i # len(m.m.module) do
					if (m.m.module[i].name = name) or Imports(root, Find(root, m.m.module[i]), name) then
						m.imports := true; i := len(m.m.module)
					else
						inc(i)
					end
				end
			else
				m.imports := true
			end;
			m.checked := true
		end;
		return m.imports
	end Imports;

	(*! caution: this is not thread safe -- must be moved to Modules.Mod *)
	procedure CopyModules(): Module;
	var firstm, lastm, c: Module; m: Modules.Module;
	begin
		new(firstm); firstm.next := nil; lastm := firstm;
		m := Modules.root;
		while m # nil do
			new(c); c.checked := false; c.imports := false; c.m := m;
			c.next := nil; lastm.next := c; lastm := c;
			m := m.next
		end;
		return firstm.next
	end CopyModules;

	procedure FreeDownTo(const modulename: array of char): longint;
	var
		root, m: Module; res: longint;
		nbrOfUnloadedModules : longint;
		msg: array 32 of char;
	begin
		nbrOfUnloadedModules := 0;
		root := CopyModules();
		m := root;
		while m # nil do
			if Imports(root, m, modulename) then
				Modules.FreeModule(m.m.name, res, msg);
				if res # 0 then
					(*context.error.String(msg);*)
				else
					inc(nbrOfUnloadedModules);
				end
			end;
			m := m.next
		end;
		return nbrOfUnloadedModules;
	end FreeDownTo;
	
	(**
		Execute ActiveCells CELLNET code
		
		cellNet: name of a CELLNET type in the format "ModuleName.TypeName", e.g. TestActiveCells.TestCellNet
		context: runtime context used for executing the ActiveCells code
		diagnostics: interface for generation of diagnostic messages (see Diagnostics.Mod)
	*)
	procedure Execute*(const cellNet: array of char; context: Context; diagnostics: Diagnostics.Diagnostics);
	type
		StartProc = procedure{DELEGATE}();
		
		Starter = object
		var
			p: StartProc;
			c: Cell;

			procedure & InitStarter(proc: address; scope: Cell);
			var startProcDesc: record proc: address; selfParam: address; end;
			begin
				startProcDesc.proc := proc;
				startProcDesc.selfParam := scope;
				system.move(address of startProcDesc, address of p, 2 * size of address);
				c := scope;
			end InitStarter;

			procedure P;
			begin
				Start(c, p)
			end P;
		end Starter
				
	var
		moduleName, typeName, name: array 256 of char;
		m: Modules.Module;
		typeInfo: Modules.TypeDesc;
		i, res: longint;
		str: array 256 of char;
		scope: Cell;
		unloaded: longint;
		starter: Starter;
		launcher: Launcher;
		offset: size;
		pc: address;
	begin
		assert(context # nil);
		context.topNet := nil;
		
		i := Strings.IndexOfByte2(".",cellNet);
		if i = -1 then
			diagnostics.Error("",Diagnostics.Invalid,Diagnostics.Invalid, "CELLNET type name is malformed");
			return;
		end;

		Strings.Copy(cellNet,0,i,moduleName);
		Strings.Copy(cellNet,i+1,Strings.Length(cellNet)-Strings.Length(moduleName),typeName);

		unloaded := FreeDownTo(moduleName);
		if unloaded > 0 then
			(*param.ctx.Information("", Diagnostics.Invalid,Diagnostics.Invalid,"unloaded " & unloaded & " modules")*)
		end;
		m := Modules.ThisModule(moduleName,res,str);

		if m = nil then
			Strings.Concat('failed to load module "',moduleName,str);
			Strings.Concat(str,'"',str);
			diagnostics.Error("",Diagnostics.Invalid,-1,str);
			return;
		end;
		typeInfo := Modules.ThisType(m,typeName);
		if typeInfo = nil then
			Strings.Concat('failed to find CELLNET type "',cellNet,str);
			Strings.Concat(str,'" in module "',str);
			Strings.Concat(str,moduleName,str);
			Strings.Concat(str,'"',str);
			diagnostics.Error("",Diagnostics.Invalid,-1,str);
			return;
		end;

		copy(typeName, name);
		Strings.Append(name, ".@Body");
		trace(name);
		trace(m.refs);
		offset := Reflection.FindByName(m.refs, 0, name, true);
		if offset # 0 then
			if Reflection.GetChar(m.refs,offset) = Reflection.sfProcedure then
				Reflection.SkipSize(offset);
				Reflection.SkipString(m.refs,offset);
				pc := Reflection.GetAddress(m.refs, offset);
				trace(pc);
				
				(*assert(len(typeInfo.procedures) = 1);
				assert(typeInfo.procedures[0].name^ = "@Body");
				*)

				(* allocate the top level cellnet *)
				AllocateOnContext(context, nil,scope,typeInfo.tag,typeName,true,false);
				assert(scope # nil);
				assert(scope.c # nil);

				new(starter, pc, scope);
			end;
			new(launcher, context);
			launcher.Start(starter.P, true);
			context.FinishedAssembly;
			assert(~launcher.error);
		else 
			Reflection.Report(Commands.GetContext().out, m.refs, offset);
		end;
	end Execute;
	
	type bytearray= array of system.byte; 
	operator "<<"* (p: port out; const a: bytearray);
	begin
		if EnableTrace then trace('bulk send'); end;
		BulkSend(system.val(any,p),a);
	end "<<";
	
	
	operator "<<"* (var  a: bytearray; p: port in);
	begin
		if EnableTrace then trace('bulk rec');end;
		BulkReceive(system.val(any,p),a);
	end "<<";
	
	(*The extra functions for longint and real were introduced because right now primitive types cannot be passed as byte arrays*)
	type longintSpecial= longint; 
	operator "<<"* (p: port out; a: longintSpecial);
	begin
		if EnableTrace then trace('normal send');end;
		BulkSend(system.val(any,p),a);
	end "<<";
	
	operator "<<"* (var  a: longintSpecial; p: port in); 
	begin
		if EnableTrace then trace('normal rec');end;
		BulkReceive(system.val(any,p),a);
	end "<<";

	type realSpecial= real;
	operator "<<"* (p: port out; a: realSpecial);
	begin
		if EnableTrace then trace('normal send');end;
		BulkSend(system.val(any,p),a);
	end "<<";
	
	operator "<<"* (var  a:realSpecial; p: port in); 
	begin
		if EnableTrace then trace('normal rec');end;
		BulkReceive(system.val(any,p),a);
	end "<<";

	type Pin = port in; Pout = port out;
	
	operator ">>"* (pout: Pout; pin: Pin); 
	begin
		Connect(system.val(any, pout), system.val(any, pin), 0);
	end ">>";
	
	operator ">>"* (cellPort: Pout; netPort: Pout); 
	begin
		Delegate(system.val(any, netPort), system.val(any, cellPort));
	end ">>";
	
	operator ">>"* (netPort: Pin; cellPort: Pin); 
	begin
		Delegate(system.val(any, netPort), system.val(any, cellPort));
	end ">>";
end ActiveCellsRuntime.


SystemTools.FreeDownTo FoxSemanticChecker ~
