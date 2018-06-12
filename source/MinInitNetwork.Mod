MODULE MinInitNetwork; (** AUTHOR "eb"; PURPOSE "Minimal IP interface initialization and configuration"; *)

IMPORT KernelLog, Modules, Plugins, Strings, Network, IP, ICMP, DHCP, IPv4, IPv6;

CONST
	(** Error Codes *)
	Ok* = 0;


TYPE
	(* Active object that runs DHCP on the specified interface. *)
	RunnerDHCP = OBJECT
		VAR
			int: IP.Interface;
			res: WORD;

		PROCEDURE &Constr*(int: IP.Interface);
		BEGIN
			ASSERT(int # NIL);
			SELF.int := int;
		END Constr;

	BEGIN {ACTIVE}
		DHCP.RunDHCP(int, res);
		IF res = 0 THEN
			IP.OutInterface(int);
		END;
	END RunnerDHCP;


VAR
	(* temporary variables used in module body *)
	res: WORD;


PROCEDURE Added(dev: Network.LinkDevice);
VAR
	int: IP.Interface;	 (* if autoconf = true; there are two ip interfaces (v4 & v6) *)
	runnerDHCP: RunnerDHCP;
	intv4: IPv4.Interface;
	intv6: IPv6.Interface;
	intName: IP.Name; (* if autoconf = true; there are two ip interfaces (v4 & v6) *)
	linkLocalAdr: IP.Adr;
	linkLocalPrefix: IP.Adr;

BEGIN
	KernelLog.String("InitNetwork: LinkDevice '"); KernelLog.String(dev.name); KernelLog.String("' found."); KernelLog.Ln;
	KernelLog.String("InitNetwork: LinkDevice '"); KernelLog.String(dev.name);
	KernelLog.String("': Get interface configuration. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;

	IP.preferredProtocol := IP.IPv6;
	IP.IPForwarding := FALSE;
	IP.EchoReply := TRUE;

	IF dev.name # "Loopback" THEN
		(* create an ipv4 interface (DHCP on) *)
		Strings.Concat("v4auto", dev.name, intName);
		NEW(intv4, intName, dev, res);
		int := intv4;

		IF res = IP.Ok THEN
			NEW(runnerDHCP, int);

			KernelLog.String("InitNetwork: Add interface for LinkDevice '"); KernelLog.String(dev.name);
			KernelLog.String("'. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;
		END;

		(* create a link-local IPv6 interface *)
		Strings.Concat("v6link-local", dev.name, intName);
		NEW (intv6, intName, dev, res);
		int := intv6;
		IF res = IP.Ok THEN
			int(IPv6.Interface).autoconfigurated := TRUE;

			linkLocalAdr := IP.NilAdr;
			linkLocalPrefix := IP.NilAdr;
			linkLocalPrefix.usedProtocol := IP.IPv6;

			int(IPv6.Interface).SetInterfaceID(linkLocalAdr);
			(* write link local prefix and prefix *)
			linkLocalAdr.ipv6Adr[0] := 0FEX;
			linkLocalAdr.ipv6Adr[1] := 80X;
			linkLocalPrefix.ipv6Adr[0] := 0FEX;
			linkLocalPrefix.ipv6Adr[1] := 80X;
			linkLocalPrefix.data := 64;

			int.SetAdrs(linkLocalAdr, linkLocalPrefix, IP.NilAdr, res);
			IF res = IP.Ok THEN
				KernelLog.String("InitNetwork: Add interface for LinkDevice '"); KernelLog.String(dev.name);
				KernelLog.String("'. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;
				IP.OutInterface(int);

				(* initiate Routers Solicitation for auto-address-configuration *)
				int(IPv6.Interface).createStatelessInterface := TRUE;
				int(IPv6.Interface).RouterSolicitation;
			END;
		END;
	ELSE
		(* Configure loopbackv4 *)
		intName := "Loopbackv4";
		NEW(intv4, intName, dev, res);
		int := intv4;

		IF res = IP.Ok THEN
			int.SetAdrs(IP.StrToAdr("127.0.0.1"), IP.StrToAdr("255.255.0.0"), IP.NilAdr, res);
			IF res = IP.Ok THEN
				KernelLog.String("InitNetwork: Add interface for LinkDevice '"); KernelLog.String(dev.name);
				KernelLog.String("'. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;
			END;
		END;

		(* Configure loopbackv6 *)
		intName := "Loopbackv6";
		NEW (intv6, intName, dev, res);
		int := intv6;
		IF res = IP.Ok THEN
			 int.SetAdrs(IP.StrToAdr("::1"), IP.StrToAdr("::/64"), IP.NilAdr, res);
			 IF res = IP.Ok THEN
			 	KernelLog.String("InitNetwork: Add interface for LinkDevice '"); KernelLog.String(dev.name);
				KernelLog.String("'. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;
			 END;
		END;
	END;
END Added;


(* Called for each LinkDevice that was removed from the registry. Remove the according interfaces. *)
PROCEDURE Removed(dev: Network.LinkDevice);
VAR int: IP.Interface;
BEGIN
	KernelLog.String("InitNetwork: LinkDevice '"); KernelLog.String(dev.name); KernelLog.String("' removed."); KernelLog.Ln;
	int := IP.InterfaceByDevice(dev);
	WHILE int # NIL DO
		int.Close();
		KernelLog.String("InitNetwork: IP Interface '"); KernelLog.String(int.name); KernelLog.String("' removed."); KernelLog.Ln;
		int := IP.InterfaceByDevice(dev);
	END;
END Removed;


(* Handle events of installed/removed devices *)
PROCEDURE EventHandler(event: WORD; plugin: Plugins.Plugin);
BEGIN
	IF event = Plugins.EventAdd THEN
		Added(plugin(Network.LinkDevice));
	ELSIF event = Plugins.EventRemove THEN
		Removed(plugin(Network.LinkDevice));
	ELSE
		(* unknown event *)
	END;
END EventHandler;


(* Handler for Enumerate() *)
PROCEDURE PluginHandler(plugin: Plugins.Plugin);
BEGIN
	Added(plugin(Network.LinkDevice));
END PluginHandler;


(** Initialize the IP stack and configure all IP interfaces. *)
PROCEDURE Init*;
(* init routines are called implicitly *)
END Init;

PROCEDURE Cleanup;
BEGIN
	Network.registry.RemoveEventHandler(EventHandler, res);
	ASSERT(res = Plugins.Ok);
END Cleanup;

BEGIN
	ICMP.InitDelegates();

	Network.registry.AddEventHandler(EventHandler, res);
	ASSERT(res = Plugins.Ok);

	Modules.InstallTermHandler(Cleanup);

	(* Handle all previously installed devices *)
	KernelLog.String("InitNetwork: Module initialized. Searching for installed devices..."); KernelLog.Ln;
	Network.registry.Enumerate(PluginHandler);
	KernelLog.String("InitNetwork: Finished searching for installed devices."); KernelLog.Ln;
END MinInitNetwork.

History:

	06.03.2006	Procedure Removed: Remove all interfaces associated with the device - not just the first one (staubesv)
