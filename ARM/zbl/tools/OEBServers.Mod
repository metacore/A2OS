MODULE OEBServers;
(**
	AUTHOR Timothée Martiel, 05/2016
	PURPOSE Server for controlling a set of Embedded Oberon Bootloaders
*)

IMPORT
	Modules, KernelLog, Plugins, Strings,
	OEBInterfaces;

CONST
	Module = "OEBServer";

TYPE
	(**
		Abstract server interface.
		A server manages several interfaces. It reacts to entering and leaving events on all those interfaces.
	*)
	Server * = OBJECT
	VAR
		name -,								(** Server instance name *)
		type -: ARRAY 128 OF CHAR;			(** Description of the server type *)
		interfaces -: OEBInterfaces.Interface;	(** List of interfaces managed by the server *)

		(** Server event handler. Is called each time an interface triggers an event. *)
		PROCEDURE Handle * (event: SIGNED32; interface: OEBInterfaces.Interface; session: OEBInterfaces.Session);
		BEGIN
			HALT(506); (*! ABSTRACT *)
		END Handle;

		PROCEDURE & InitServer * (CONST name, type: ARRAY 128 OF CHAR);
		BEGIN
			COPY(name, SELF.name);
			COPY(type, SELF.type)
		END InitServer;

		(** Adds a new interface to be managed by the server *)
		PROCEDURE AddInterface * (interface: OEBInterfaces.Interface);
		BEGIN {EXCLUSIVE}
			IF OEBInterfaces.Trace THEN EnterTrace; KernelLog.String("Adding interface "); KernelLog.String(interface.name); ExitTrace END;
			interface.next := interfaces;
			interfaces := interface;
			interface.SetHandler(SELF.Handle)
		END AddInterface;

		(** Removes an interface from server management *)
		PROCEDURE RemoveInterface * (interface: OEBInterfaces.Interface);
		VAR
			i: OEBInterfaces.Interface;
		BEGIN {EXCLUSIVE}
			IF OEBInterfaces.Trace THEN EnterTrace; KernelLog.String("Removing interface "); KernelLog.String(interface.name); ExitTrace END;
			IF interface = interfaces THEN
				interfaces := interfaces.next;
				RETURN
			END;
			i := interfaces;
			WHILE (i # NIL) & (i.next # NIL) & (i.next # interface) DO
				i := i.next
			END;
			IF i = NIL THEN RETURN END;
			i.next := interface.next;
			RETURN
		END RemoveInterface;

		PROCEDURE GetInterface * (id: SIGNED32): OEBInterfaces.Interface;
		BEGIN {EXCLUSIVE}
		END GetInterface;

		(** Start all interfaces managed by the server *)
		PROCEDURE Start *;
		VAR
			intf: OEBInterfaces.Interface;
		BEGIN {EXCLUSIVE}
			intf := interfaces;
			WHILE intf # NIL DO intf.Start; intf := intf.next END
		END Start;

		(** Stop all interfaces managed by the server *)
		PROCEDURE Stop *;
		VAR
			intf: OEBInterfaces.Interface;
		BEGIN {EXCLUSIVE}
			intf := interfaces;
			WHILE intf # NIL DO intf.Stop; intf := intf.next END
		END Stop;

		(** Kill all interfaces managed by the server *)
		PROCEDURE Kill *;
		VAR
			intf: OEBInterfaces.Interface;
		BEGIN {EXCLUSIVE}
			intf := interfaces;
			WHILE intf # NIL DO intf.Kill; intf := intf.next END
		END Kill;

		PROCEDURE EnterTrace *;
		BEGIN
			KernelLog.Enter;
			KernelLog.String(Module);
			KernelLog.String(" ");
			KernelLog.String(name);
			KernelLog.String(" (");
			KernelLog.String(type);
			KernelLog.String(")");
			KernelLog.String(": ");
		END EnterTrace;

		PROCEDURE ExitTrace *;
		BEGIN
			KernelLog.Exit			
		END ExitTrace;
	END Server;

	Factory * = OBJECT (Plugins.Plugin)
		PROCEDURE NewServer * (CONST param: ARRAY OF CHAR): Server;
		BEGIN HALT(555) (* ABSTRACT *)
		END NewServer;
	END Factory;

VAR
	factories: Plugins.Registry;

	PROCEDURE NewServer * (CONST type, param: ARRAY OF CHAR): Server;
	VAR
		factory: Factory;
		m: Modules.Module;
		name, msg: ARRAY 128 OF CHAR;
		res: SIGNED32;
	BEGIN
		name := "OEB";
		Strings.Append(name, type);
		Strings.Append(name, "Servers");
		m := Modules.ThisModule(name, res, msg);
		IF m = NIL THEN
			COPY(type, name);
			Strings.Append(name, "Servers");
			m := Modules.ThisModule(name, res, msg);
		END;

		factory := factories.Get(type)(Factory);
		IF factory = NIL THEN RETURN NIL END;
		RETURN factory.NewServer(param)
	END NewServer;

	PROCEDURE Register * (CONST type: ARRAY OF CHAR; factory: Factory);
	VAR
		ignore: SIGNED32;
	BEGIN
		factory.SetName(type);
		factories.Add(factory, ignore)
	END Register;

	PROCEDURE Unregister * (factory: Factory);
	BEGIN
		factories.Remove(factory)
	END Unregister;

	PROCEDURE Cleanup;
	BEGIN
		Plugins.main.Remove(factories)
	END Cleanup;

BEGIN
	NEW(factories, "OEB Servers", "OEB Server Factories");
	Modules.InstallTermHandler(Cleanup)
END OEBServers.
