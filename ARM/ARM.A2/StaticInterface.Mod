MODULE StaticInterface; (** AUTHOR "Timothée Martiel"; PURPOSE "Static IP interface configuration"; *)

IMPORT KernelLog := Trace, Kernel, Plugins, Network, IP, IPv4;

VAR
	interface: IPv4.Interface;
	res: SIGNED32;
	local, gateway, mask: IP.Adr;
	p: Plugins.Plugin;
	(*l4header, data: ARRAY 32 OF CHAR;
	connection: TCP.Connection;*)
	t: Kernel.Timer;

BEGIN
	NEW(t);
	(*t.Sleep(10 * 1000);*)
	KernelLog.String("Creating Static Interface"); KernelLog.Ln;

	p := Network.registry.Get("XEmac");
	IF p = NIL THEN
		KernelLog.String("Could not find network device");
		KernelLog.Ln;
		HALT(100)
	ELSIF ~(p IS Network.LinkDevice) THEN
		KernelLog.String("Device found is not a link device");
		KernelLog.Ln;
		HALT(100)
	END;
	NEW(interface, "Static IPv4 Interface", p(Network.LinkDevice), res);
	IF res # IP.Ok THEN
		KernelLog.Hex(res, 0);
		KernelLog.String(" -- Error in Static IPv4 Interface creation");
		KernelLog.Ln;
		TRACE(res, p);
		HALT(100)
	END;

	local := IP.StrToAdr("10.3.34.8");
	gateway := IP.StrToAdr("10.3.34.145");
	mask := IP.StrToAdr("255.255.0.0");

	(*TRACE(local.ipv4Adr, gateway.ipv4Adr, mask.ipv4Adr);*)

	interface.SetAdrs(local, mask, gateway, res);
	IF res # IP.Ok THEN
		TRACE(res);
		KernelLog.Address(res);
		KernelLog.String(" -- Error in Static IPv4 Interface addresses");
		KernelLog.Ln;
		HALT(100)
	END;
END StaticInterface.
