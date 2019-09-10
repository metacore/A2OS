MODULE WMPerfMonPluginModVars; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor module variables  plugin"; *)
(**
 * History:
 *
 *	16.02.2006	First Release (staubesv)
 *)

IMPORT
	SYSTEM,
	WMPerfMonPlugins,
	Modules, Reflection, Commands, Streams, Strings;

CONST

	ModuleName = "WMPerfMonPluginModVars";

	(* Supported module variable types. MUST NOT BE CHANGED *)
	Byte= 1;
	Boolean = 2;
	Char= 3;
	Shortint = 4;
	Integer = 5;
	Longint = 6;
	Set = 9;
	Real = 7;
	Longreal = 13; (* not yet implemented *)
	Ptr = 29;

TYPE

	VariableDescriptor* = RECORD
		moduleName* : Modules.Name;
		variableName* : ARRAY 64 OF CHAR;
	END;

	VariableDescriptors* = POINTER TO ARRAY OF VariableDescriptor;

	ModVarParameter = POINTER TO RECORD (WMPerfMonPlugins.Parameter)
		vd : VariableDescriptors;
	END;

TYPE

	ModVar = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		vd : VariableDescriptors;

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		BEGIN
			ASSERT((p # NIL) & (p IS ModVarParameter) & (p(ModVarParameter).vd # NIL));
			vd := p(ModVarParameter).vd;
			p.description := "Module variables access adapter";
			p.modulename := ModuleName;
			p.autoMax := TRUE; p.minDigits := 5;
			p.datasetDescriptor := GetDatasetDescriptor(vd);
		END Init;

		PROCEDURE UpdateDataset*;
		VAR module : Modules.Module; variable : Reflection.Variable; i : SIZE; value : FLOAT64;
		BEGIN
			FOR i := 0 TO LEN(vd)-1 DO
				module := Modules.ModuleByName(vd[i].moduleName);
				IF module # NIL THEN
					IF Reflection.FindVar(module, vd[i].variableName, variable) THEN
						IF GetValueOf(variable, value) THEN
							dataset[i] := SHORT(value);
						ELSE
						END;
					ELSE
					END;
				ELSE
				END;
			END;
		END UpdateDataset;

	END ModVar;

PROCEDURE GetValueOf(v: Reflection.Variable; VAR value : FLOAT64) : BOOLEAN;
VAR short : SIGNED8; int : SIGNED16; long : SIGNED32; ch : CHAR; real : FLOAT32;
BEGIN
	IF (v.n = 1) THEN (* arrays not supported *)
		CASE v.type OF
			|Byte: SYSTEM.GET(v.adr, ch); value := ORD(ch);
			|Boolean: SYSTEM.GET(v.adr, ch); IF ch = 0X THEN value := 0; ELSE value := 1; END;
			|Char: SYSTEM.GET(v.adr, ch); value := ORD(ch);
			|Shortint: short := SYSTEM.GET8(v.adr); value := short;
			|Integer: int := SYSTEM.GET16(v.adr); value := int;
			|Longint: long := SYSTEM.GET32(v.adr); value := long;
			|Set: long := SYSTEM.GET32(v.adr); value := long;
			|Real: real := SYSTEM.GET32(v.adr); value := real;
			|Longreal:
			|Ptr: long := SYSTEM.GET32(v.adr); value := long;
		ELSE
			RETURN FALSE;
		END;
	ELSE
		RETURN FALSE;
	END;
	RETURN TRUE;
END GetValueOf;

PROCEDURE GetDatasetDescriptor(vd : VariableDescriptors) : WMPerfMonPlugins.DatasetDescriptor;
VAR ds : WMPerfMonPlugins.DatasetDescriptor; i : SIZE;
BEGIN
	ASSERT(vd # NIL);
	NEW(ds, LEN(vd));
	FOR i := 0 TO LEN(vd)-1 DO
		COPY(vd[i].variableName, ds[i].name);
	END;
	RETURN ds;
END GetDatasetDescriptor;

PROCEDURE InstallPlugin*(CONST name : WMPerfMonPlugins.Name; vd : VariableDescriptors);
VAR par : ModVarParameter; plugin : ModVar;
BEGIN
	ASSERT(vd # NIL);
	NEW(par); par.vd := vd; par.name := name;
	NEW(plugin, par);
END InstallPlugin;

PROCEDURE Add(VAR vd : VariableDescriptors; CONST moduleName, variableName : ARRAY OF CHAR);
VAR new : VariableDescriptors; i : SIZE;
BEGIN
	IF vd = NIL THEN
		NEW(vd, 1);
		COPY(moduleName, vd[0].moduleName);
		COPY(variableName, vd[0].variableName);
	ELSE
		NEW(new, LEN(vd)+1);
		i := 0; WHILE (i < LEN(vd)) DO new[i] := vd[i]; INC(i); END;
		COPY(moduleName, new[i].moduleName);
		COPY(variableName, new[i].variableName);
		vd := new;
	END;
END Add;

PROCEDURE Install*(context : Commands.Context); (** pluginname modulename.variablename  {" " modulename.variablename} ~ *)
VAR
	string : ARRAY 128 OF CHAR; pluginname : WMPerfMonPlugins.Name;
	vd : VariableDescriptors; split : Strings.StringArray;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(pluginname);
	WHILE context.arg.GetString(string) DO
		split := Strings.Split(string, ".");
		IF LEN(split) = 2 THEN
			Add(vd, split[0]^, split[1]^);
		ELSE
			ShowUsage(context.error); RETURN;
		END;
	END;
	IF vd # NIL THEN
		InstallPlugin(pluginname, vd);
		context.out.String("WMPerfMonPluginModVars: Installed plugin "); context.out.String(pluginname);
		context.out.Ln;
	ELSE
		ShowUsage(context.error);
	END;
END Install;

PROCEDURE ShowUsage(w : Streams.Writer);
BEGIN
	w.String(ModuleName); w.String(": Expected parameters: modulename.variablename"); w.Ln;
END ShowUsage;

PROCEDURE Cleanup;
BEGIN
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMPerfMonPluginModVars.

System.Free WMPerfMonPluginModVars ~

WMPerfMonPluginModVars.Install ~

WMPerfMonPluginModVars.Install Network Network.nofBuf ~

WMPerfMonPluginModVars.Install Test WMMessages.messagesAdded WMMessages.messagesDiscarded ~
