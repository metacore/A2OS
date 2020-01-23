MODULE ModuleTesting; (** AUTHOR "Patrick Hunziker"; PURPOSE "automated module testing of modules and procedures with {TEST} flag"; *)

IMPORT FoxSyntaxTree, FoxBasic, Strings, Modules, Compiler, Out, Files, Commands;

CONST
	(* test mode*)
	Immediate*=0;
	Repetitive*=1;
	PerModule*=10;
	PerProcedure*=11;
	ModuleTestingDB*="ModuleTesting.db";
	
	MaxString=64;
	
	Strategy*={Immediate, Repetitive};
	
TYPE	TestCall*=PROCEDURE(context:Commands.Context);

TYPE Procedure= POINTER TO RECORD 
			name: ARRAY MaxString OF CHAR; 
			next: Procedure;
		END;
		
TYPE	Module = POINTER TO RECORD
			name: ARRAY MaxString OF CHAR;
			strategy, mode: SET;
			procedures: Procedure;
			next:Module;
		END;

TYPE Registry*=OBJECT
		VAR modules: Module; 
		
		PROCEDURE Register*(mod: FoxSyntaxTree.Module);
		VAR m: Module; p:Procedure; proc: FoxSyntaxTree.Procedure; 
		BEGIN
			NEW(m); 
			FoxBasic.GetString(mod.name, m.name);
			m.strategy:=Strategy;
			m.next:=registry.modules; 
			registry.modules:=m;
			IF mod.isTest THEN 
				INCL(m.mode,PerModule);
				IF (Repetitive IN m.strategy) THEN Store(m.name, "") END;
			ELSE 
				proc:=mod.moduleScope.firstProcedure;
				WHILE proc#NIL DO
					IF proc.isTest THEN 
						INCL(m.mode, PerProcedure);
						NEW(p);
						FoxBasic.GetString(proc.name, p.name);
						IF (Repetitive IN m.strategy) THEN	Store(m.name, p.name) END;
						p.next:=m.procedures; m.procedures:=p;
					END;
					proc:=proc.nextProcedure;
				END;
			END;
			IF (Repetitive IN m.strategy) & (m.mode#{}) THEN (*store modules to be tested in DB*)
			END;
			IF Immediate IN m.strategy THEN Test(m) END;
		END Register;
		
		PROCEDURE Store(CONST mname,pname: ARRAY OF CHAR);
		VAR f:Files.File; r:Files.Reader; w:Files.Writer; found:BOOLEAN;	fullname, line:ARRAY MaxString OF CHAR;
		BEGIN
			COPY(mname,fullname); 
			IF pname#"" THEN Strings.Append(fullname,".") ; Strings.Append(fullname,pname) END;
			f:=Files.Old(ModuleTestingDB);
			Files.OpenReader(r,f,0);
			found:=FALSE;
			WHILE (r.res=Files.Ok) & ~found DO
				r.Ln(line);
				found:=Strings.Pos(fullname, line)=0;
			END;
			IF ~found THEN
				Files.OpenWriter(w,f,r.Pos());
				w.String(fullname); w.Ln; w.Update;
			END;
		END Store;
		
			(* test modules and procedures flaged with {TEST} *) (* current limitations on procedure interface, PROCEDURE X*(context:Commands.Context) *)
		PROCEDURE Test(m:Module); 
		VAR  
			freeCmd, msg,s: ARRAY MaxString OF CHAR;
			p:Procedure;	i, res:INTEGER;
			context:Commands.Context;
		BEGIN
			COPY("System.FreeDownTo ",freeCmd); Strings.Append(freeCmd, m.name); 
			IF Modules.ModuleByName(m.name)#NIL THEN 
				Commands.Call (freeCmd, {Commands.Wait}, res, msg) END;
			IF PerModule IN m.mode THEN
				TestAModule(m.name, context);
				COPY(" per module testing of module ", msg); Strings.Append(msg, m.name); Strings.Append(msg,": result="); Strings.IntToStr(context.result,s); Strings.Append(msg, s); Out.String(msg); Out.Ln; Out.Update (*load*) 
			ELSE
				COPY(" per procedure testing in module ",msg); Strings.Append(msg,m.name);Strings.Append(msg,": "); Out.String(msg); Out.Ln; Out.Update;
				p:=m.procedures;
				i:=0;
				WHILE p#NIL DO
					TestAProcedure(m.name,p.name, context);
					COPY(" procedure test of ",msg); Strings.Append(msg,m.name); Strings.Append(msg,"."); Strings.Append(msg,p.name);
					Strings.Append(msg,": result="); Strings.IntToStr(context.result,s); Strings.Append(msg,s); Out.String(msg); Out.Ln; Out.Update;
					p:=p.next;
				END;
			END;
			Commands.Call (freeCmd, {Commands.Wait}, res, msg); (* free *)
		END Test;
END Registry;

VAR registry*: Registry;

PROCEDURE TestItem*(CONST name: ARRAY OF CHAR; VAR context:Commands.Context);
VAR mname,pname:Strings.String; dotPos:SIZE;
BEGIN
	dotPos:=Strings.Pos(".",name);
	IF dotPos>0 THEN (*a procedure*)
		mname:=Strings.Substring(0,dotPos,name);
		pname:=Strings.Substring2(dotPos+1,name);
		TestAProcedure(mname^,pname^, context);
	ELSE (* a module*)
		TestAModule(name, context);
	END;
END TestItem;

PROCEDURE TestAModule(CONST mname:ARRAY OF CHAR; VAR context:Commands.Context);
VAR mod:Modules.Module; msg: ARRAY MaxString OF CHAR; res:INTEGER;
BEGIN
	IF context=NIL THEN NEW(context, NIL,NIL,NIL,NIL,SELF) END;
	context.result:=-1;
	mod:=Modules.ThisModule(mname, res, msg); 
	context.result:=res;
END TestAModule;

PROCEDURE TestAProcedure(CONST modName,procName: ARRAY OF CHAR; VAR context:Commands.Context);
VAR 
	fullname,msg:ARRAY MaxString OF CHAR;
	res:INTEGER;
BEGIN
	IF context=NIL THEN NEW(context,NIL,NIL,NIL,NIL,SELF) END; 
	context.result:=-1;
	COPY(modName, fullname); Strings.Append(fullname,"."); Strings.Append(fullname,procName);
	Commands.Activate(fullname,NIL,{Commands.Wait},res,msg);
	context.result:=res;
END TestAProcedure;

PROCEDURE TestDatabase*(context:Commands.Context);
VAR dbname: ARRAY 256 OF CHAR;
	f:Files.File;r:Files.Reader; 
	header, name: ARRAY MaxString OF CHAR;
	nSuccesses, nFailures: INTEGER;
BEGIN
	IF ~context.arg.GetString(dbname) THEN dbname:=ModuleTestingDB END;
	f:=Files.Old(dbname);
	IF f#NIL THEN
		Files.OpenReader(r,f,0);
		r.Ln(header); 
		r.Ln(name);
		WHILE r.res=Files.Ok DO
			TestItem(name,context);
			IF context.result=0 THEN INC(nSuccesses) ELSE INC(nFailures) END;
			context.out.String("testing: "); context.out.String(name); context.out.String(": ");context.out.Int(context.result,0); context.out.Ln; context.out.Update;
			r.Ln(name);
		END;
		context.out.String("Overall "); context.out.Int(nSuccesses,0); context.out.String(" out of "); context.out.Int(nSuccesses+nFailures,0); context.out.String(" tests successful."); context.out.Ln; context.out.Update;
	ELSE context.error.String("no database file found"); context.error.Ln; context.error.Update;
	END;
END TestDatabase;

PROCEDURE Test*(context:Commands.Context);
VAR name: ARRAY 256 OF CHAR;
BEGIN
	WHILE context.arg.GetString(name) DO
		TestItem(name,context);
		context.out.String("testing: "); context.out.String(name); context.out.String(": ");context.out.Int(context.result,0); context.out.Ln; context.out.Update;
	END;
END Test;

PROCEDURE Install*;
VAR f: Files.File; w:Files.Writer;
BEGIN
	NEW(registry); 
	f:=Files.Old(ModuleTestingDB);
	IF f=NIL THEN f:=Files.New(ModuleTestingDB); Files.Register(f); Files.OpenWriter(w,f,0); w.String("(* database for ModuleTesting.Mod *)"); w.Ln; w.Update; END;
	Compiler.TestModule:=registry.Register
END Install;

PROCEDURE Uninstall*;
BEGIN
	Compiler.TestModule:=NIL
END Uninstall;
(*
PROCEDURE TestACommand*;
VAR res:SIGNED32; msg:ARRAY 64 OF CHAR;
BEGIN
	Commands.Activate("M.P",NIL,{Commands.Wait},res,msg);
	Out.String("M.P: "); Out.String(msg); Out.String(":"); Out.Int(res); Out.Ln; Out.Update;
	Commands.Activate("M.P1",NIL,{Commands.Wait},res,msg);
	Out.String("M.P1: "); Out.String(msg); Out.String(":"); Out.Int(res); Out.Ln; Out.Update;
	Commands.Activate("M.P",NIL,{Commands.Wait},res,msg);
	Out.String("M.P: "); Out.String(msg); Out.String(":"); Out.Int(res); Out.Ln; Out.Update;
	Commands.Activate("M.P1",NIL,{Commands.Wait},res,msg);
	Out.String("M.P1: "); Out.String(msg); Out.String(":"); Out.Int(res); Out.Ln; Out.Update;
END TestACommand;
*)
BEGIN
	Modules.InstallTermHandler(Uninstall);
END ModuleTesting. 

System.FreeDownTo  ModuleTesting~
ModuleTesting.Install ~
ModuleTesting.Uninstall ~

(*test all modules/procedures in database*)
(*ModuleTesting.TestDatabase [dbname] ~ *)
ModuleTesting.TestDatabase ~

(*test specific procedures
ModuleTesting.Test{modulename|procedurename} ~ *)
ModuleTesting.Test
M.P1
M
M2
~

ModuleTesting.TestACommand ~
