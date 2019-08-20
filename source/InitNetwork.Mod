MODULE InitNetwork; (** AUTHOR "mvt"; PURPOSE "IP interface initialization and configuration"; *)

IMPORT Files, KernelLog, Modules, Streams, Plugins, Strings, XML, XMLObjects, XMLScanner,
		XMLParser, Network, IP, ICMP, DNSMod := DNS, DHCP, IPv4, IPv6; (* load all *)

CONST
	(** Error Codes *)
	Ok* = 0;
	NotFound* = 4001;
	NoConfigFile* = 4002;
	ConfigFileNotValid* = 4003;

	MaxNofInterfaces* = 10; (** Interface numbers vom 0 to 9 are accepted in Machine config *)


TYPE
	(* Interface and router config *)
	Config = POINTER TO RECORD
		interfaceConfigs: InterfaceConfig;
		routerConfigs: IPv6.RouterConfig;
		IPForwarding: BOOLEAN;
		EchoReply: BOOLEAN;
		PreferredProtocol: LONGINT;
		AutoNetConfigV4: BOOLEAN;
		AutoNetConfigV6: BOOLEAN;
		AutoNetConfigV6DNS: ARRAY DNSMod.MaxNofServer OF IP.Adr;
	END;


	(* A configuraton of a interface *)
	InterfaceConfig = POINTER TO RECORD
		Device: Plugins.Name;
		Protocol: LONGINT;
		Name: IP.Name;
		Domain: Strings.String;
		DHCP: BOOLEAN;
		LocalAdr: IP.Adr;
		Gateway: IP.Adr;
		Netmask: IP.Adr;
		Prefix: IP.Adr;
		DNS: ARRAY DNSMod.MaxNofServer OF IP.Adr;
		next: InterfaceConfig;
	END;

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
	hasXMLErrors: BOOLEAN;

	(* temporary variables used in module body *)
	res: WORD;


(* Error output for XML parser *)
PROCEDURE Error(pos, line, row: Streams.Position; CONST msg: ARRAY OF CHAR);
BEGIN
	KernelLog.String("Parse error in NetInit.XML at pos "); KernelLog.Int(pos, 5); KernelLog.String(" in line "); KernelLog.Int(line, 5);
	KernelLog.String(" row "); KernelLog.Int(row, 5); KernelLog.String(" - "); KernelLog.String(msg); KernelLog.Ln;
	hasXMLErrors := TRUE
END Error;


(**Get interface configurations from NetInit.XML for the specified device. *)
PROCEDURE GetConfig(CONST devName: ARRAY OF CHAR; VAR res:WORD): Config;
VAR
	netConfigElem: XML.Element;
	elem: XML.Element;
	elemStr: Strings.String;
	config: Config;
	interfaceConfig: InterfaceConfig;
	routerConfig: IPv6.RouterConfig;
	prefixConfig: IPv6.PrefixConfig;
	file: Files.File;
	reader: Files.Reader;
	scanner: XMLScanner.Scanner;
	parser: XMLParser.Parser;
	doc: XML.Document;
	ipv4Elem: XML.Element;
	ipv6Elem: XML.Element;
	i: LONGINT;
	interfaceElems: XMLObjects.ArrayCollection;
	routerElems: XMLObjects.ArrayCollection;
	prefixElems: XMLObjects.ArrayCollection;
	dnsElems: XMLObjects.ArrayCollection;
	intElem: XML.Element;
	routerElem: XML.Element;
	prefixElem: XML.Element;
	interfaceNbr: LONGINT;
	routerNbr: LONGINT;
	prefixNbr: LONGINT;
	attribute: XML.Attribute;
	p: ANY;


	(** Get a section with a specific name *)
	PROCEDURE GetSection(elem: XML.Element; CONST sectionName: ARRAY OF CHAR): XML.Element;
	VAR
		enum: XMLObjects.Enumerator;
		attribute: XML.Attribute;
		section: XML.Element;
		p: ANY;
		elemStr: Strings.String;

	BEGIN
		IF elem # NIL THEN
			enum := elem.GetContents();
			(* Search for elements equal "childName"  *)
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS XML.Element THEN
					elemStr := p(XML.Element).GetName();
					IF (elemStr^ = "Section") THEN
						attribute := p(XML.Element). GetAttribute("name");
						elemStr := attribute.GetValue();
						IF elemStr^ = sectionName THEN
							section := p(XML.Element);
						END;
					END;
				END;
			END;
		END;

		RETURN section;
	END GetSection;


	(** Sets a Boolean value from Setting of a section.
		If error is TRUE then hasXMLErrors is set to TRUE if child does not exist. *)
	PROCEDURE GetSettingBool(section: XML.Element; CONST settingName: ARRAY OF CHAR; error: BOOLEAN; VAR bool: BOOLEAN);
	VAR
		nameAttr: XML.Attribute;
		valueAttr: XML.Attribute;
		nameStr: Strings.String;
		valueStr: Strings.String;
		elemStr: Strings.String;
		settingFound: BOOLEAN;
		enum: XMLObjects.Enumerator;
		p: ANY;

	BEGIN
		settingFound := FALSE;

		IF section # NIL THEN
			enum := section.GetContents();
			(* Search for settings *)
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS (XML.Element) THEN
					elemStr := p(XML.Element).GetName();
					IF (elemStr^ = "Setting") THEN
						nameAttr := p(XML.Element).GetAttribute("name");
						valueAttr := p(XML.Element).GetAttribute("value");
						IF (nameAttr # NIL) & (valueAttr # NIL) THEN
							nameStr := nameAttr.GetValue();
							valueStr := valueAttr.GetValue();
							IF nameStr^ = settingName THEN
								Strings.StrToBool(valueStr^, bool);
								settingFound := TRUE;
							END;
						END;
					END;
				END;
			END;
		ELSIF error THEN
			hasXMLErrors := TRUE;
		END;

		IF ~settingFound & error THEN
			hasXMLErrors := TRUE;
		END;
	END GetSettingBool;


	(** Sets a integer value from Setting of a section.
		If error is TRUE then hasXMLErrors is set to TRUE if child does not exist. *)
	PROCEDURE GetSettingInt(section: XML.Element; CONST settingName: ARRAY OF CHAR; error: BOOLEAN; VAR int : LONGINT);
	VAR
		nameAttr: XML.Attribute;
		valueAttr: XML.Attribute;
		nameStr: Strings.String;
		valueStr: Strings.String;
		elemStr: Strings.String;
		settingFound: BOOLEAN;
		enum: XMLObjects.Enumerator;
		p: ANY;

	BEGIN
		settingFound := FALSE;

		IF section # NIL THEN
			enum := section.GetContents();
			(* Search for settings *)
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS (XML.Element) THEN
					elemStr := p(XML.Element).GetName();
					IF (elemStr^ = "Setting") THEN
						nameAttr := p(XML.Element).GetAttribute("name");
						valueAttr := p(XML.Element).GetAttribute("value");
						IF (nameAttr # NIL) & (valueAttr # NIL) THEN
							nameStr := nameAttr.GetValue();
							valueStr := valueAttr.GetValue();
							IF nameStr^ = settingName THEN
								Strings.StrToInt(valueStr^, int);
								settingFound := TRUE;
							END;
						END;
					END;
				END;
			END;
		ELSIF error THEN
			hasXMLErrors := TRUE;
		END;

		IF ~settingFound & error THEN
			hasXMLErrors := TRUE;
		END;
	END GetSettingInt;


	(** Sets a character array from Setting of a section.
		If error is TRUE then hasXMLErrors is set to TRUE if child does not exist. *)
	PROCEDURE GetSettingChars(section: XML.Element; CONST settingName: ARRAY OF CHAR; error: BOOLEAN; VAR chars: ARRAY OF CHAR);
	VAR
		nameAttr: XML.Attribute;
		valueAttr: XML.Attribute;
		nameStr: Strings.String;
		valueStr: Strings.String;
		elemStr: Strings.String;
		settingFound: BOOLEAN;
		enum: XMLObjects.Enumerator;
		p: ANY;

	BEGIN
		settingFound := FALSE;

		IF section # NIL THEN
			enum := section.GetContents();
			(* Search for settings *)
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS (XML.Element) THEN
					elemStr := p(XML.Element).GetName();
					IF (elemStr^ = "Setting") THEN
						nameAttr := p(XML.Element).GetAttribute("name");
						valueAttr := p(XML.Element).GetAttribute("value");
						IF (nameAttr # NIL) & (valueAttr # NIL) THEN
							nameStr := nameAttr.GetValue();
							valueStr := valueAttr.GetValue();
							IF nameStr^ = settingName THEN
								COPY(valueStr^, chars);
								settingFound := TRUE;
							END;
						END;
					END;
				END;
			END;
		ELSIF error THEN
			hasXMLErrors := TRUE;
		END;

		IF ~settingFound & error THEN
			hasXMLErrors := TRUE;
		END;
	END GetSettingChars;


	(** Sets a string from Setting of a section.
		If error is TRUE then hasXMLErrors is set to TRUE if child does not exist. *)
	PROCEDURE GetSettingString(section: XML.Element; CONST settingName: ARRAY OF CHAR; error: BOOLEAN; VAR string: Strings.String);
	VAR
		nameAttr: XML.Attribute;
		valueAttr: XML.Attribute;
		nameStr: Strings.String;
		valueStr: Strings.String;
		elemStr: Strings.String;
		settingFound: BOOLEAN;
		enum: XMLObjects.Enumerator;
		p: ANY;

	BEGIN
		settingFound := FALSE;

		IF section # NIL THEN
			enum := section.GetContents();
			(* Search for settings *)
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS (XML.Element) THEN
					elemStr := p(XML.Element).GetName();
					IF (elemStr^ = "Setting") THEN
						nameAttr := p(XML.Element).GetAttribute("name");
						valueAttr := p(XML.Element).GetAttribute("value");
						IF (nameAttr # NIL) & (valueAttr # NIL) THEN
							nameStr := nameAttr.GetValue();
							valueStr := valueAttr.GetValue();
							IF nameStr^ = settingName THEN
								string := valueStr;
								settingFound := TRUE;
							END;
						END;
					END;
				END;
			END;
		ELSIF error THEN
			hasXMLErrors := TRUE;
		END;

		IF ~settingFound & error THEN
			hasXMLErrors := TRUE;
		END;
	END GetSettingString;


	(** Sets an address from Setting of a section.
		If error is TRUE then hasXMLErrors is set to TRUE if child does not exist. *)
	PROCEDURE GetSettingAdr(section: XML.Element; CONST settingName: ARRAY OF CHAR; error: BOOLEAN; VAR adr: IP.Adr);
	VAR
		nameAttr: XML.Attribute;
		valueAttr: XML.Attribute;
		nameStr: Strings.String;
		valueStr: Strings.String;
		elemStr: Strings.String;
		settingFound: BOOLEAN;
		enum: XMLObjects.Enumerator;
		p: ANY;

	BEGIN
		settingFound := FALSE;

		IF section # NIL THEN
			enum := section.GetContents();
			(* Search for settings *)
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS (XML.Element) THEN
					elemStr := p(XML.Element).GetName();
					IF (elemStr^ = "Setting") THEN
						nameAttr := p(XML.Element).GetAttribute("name");
						valueAttr := p(XML.Element).GetAttribute("value");
						IF (nameAttr # NIL) & (valueAttr # NIL) THEN
							nameStr := nameAttr.GetValue();
							valueStr := valueAttr.GetValue();
							IF nameStr^ = settingName THEN
								adr := IP.StrToAdr(valueStr^);
								settingFound := TRUE;
							END;
						END;
					END;
				END;
			END;
		ELSIF error THEN
			hasXMLErrors := TRUE;
		END;

		IF ~settingFound & error THEN
			hasXMLErrors := TRUE;
		END;
	END GetSettingAdr;


	(** Get a list of settings with specific name*)
	PROCEDURE GetSettings(elem: XML.Element; CONST settingName: ARRAY OF CHAR): XMLObjects.ArrayCollection;
	VAR
		settingCol: XMLObjects.ArrayCollection;
		enum: XMLObjects.Enumerator;
		p: ANY;
		elemName: Strings.String;
		nameAttr: XML.Attribute;
		nameStr: Strings.String;

	BEGIN
		IF elem # NIL THEN
			NEW(settingCol);
			enum := elem.GetContents();
			(* Search for settings equal "childName"  *)
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS XML.Element THEN
					elemName := p(XML.Element).GetName();
					IF elemName^ = "Setting" THEN
						nameAttr := p(XML.Element).GetAttribute("name");
						IF nameAttr # NIL THEN
							nameStr := nameAttr.GetValue();
							IF nameStr^ = settingName THEN
								settingCol.Add(p(XML.Element));
							END;
						END;
					END;
				END;
			END;
		END;
		RETURN settingCol;
	END GetSettings;


	(** Get a section with a specific name *)
	PROCEDURE GetSections(elem: XML.Element; CONST sectionName: ARRAY OF CHAR): XMLObjects.ArrayCollection;
	VAR
		sectionCol: XMLObjects.ArrayCollection;
		enum: XMLObjects.Enumerator;
		p: ANY;
		elemName: Strings.String;
		nameAttr: XML.Attribute;
		nameStr: Strings.String;

	BEGIN
		IF elem # NIL THEN
			NEW(sectionCol);
			enum := elem.GetContents();
			(* Search for sections equal "childName"  *)
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS XML.Element THEN
					elemName := p(XML.Element).GetName();
					IF elemName^ = "Section" THEN
						nameAttr := p(XML.Element).GetAttribute("name");
						IF nameAttr # NIL THEN
							nameStr := nameAttr.GetValue();
							IF nameStr^ = sectionName THEN
								sectionCol.Add(p(XML.Element));
							END;
						END;
					END;
				END;
			END;
		END;
		RETURN sectionCol;
	END GetSections;


	(* Read a IPv4 Interface *)
	PROCEDURE Readv4Interface;
	BEGIN
		interfaceElems := GetSections(ipv4Elem, "Interface");
		IF interfaceElems.GetNumberOfElements() # 0 THEN
			FOR interfaceNbr := 0 TO interfaceElems.GetNumberOfElements() - 1 DO
				p := interfaceElems.GetElement(interfaceNbr);
				intElem :=p (XML.Element);
				(* init config *)
				NEW(interfaceConfig);
				(*init config *)
				FOR i := 0 TO LEN(interfaceConfig.DNS) - 1 DO
					interfaceConfig.DNS[i] := IP.NilAdr;
				END;
				interfaceConfig.Device[0] := 0X;
				interfaceConfig.Protocol := IP.IPv4;
				interfaceConfig.Name := "";
				interfaceConfig.Domain := NIL;
				interfaceConfig.DHCP := TRUE;
				interfaceConfig.LocalAdr := IP.NilAdr;
				interfaceConfig.Gateway := IP.NilAdr;
				interfaceConfig.Netmask := IP.NilAdr;
				interfaceConfig.Prefix := IP.NilAdr;

				(* Device *)
				GetSettingChars(intElem, "Device", TRUE, interfaceConfig.Device);

				(* Name *)
				GetSettingChars(intElem, "Name", TRUE, interfaceConfig.Name);

				(* Domain *)
				GetSettingString(intElem, "Domain", FALSE, interfaceConfig.Domain);

				(* DHCP *)
				GetSettingBool(intElem, "DHCP", FALSE, interfaceConfig.DHCP);

				(* LocalAdr *)
				GetSettingAdr(intElem, "LocalAdr", FALSE, interfaceConfig.LocalAdr);

				(* Gateway *)
				GetSettingAdr(intElem, "Gateway", FALSE, interfaceConfig.Gateway);

				(* Netmask *)
				GetSettingAdr(intElem, "Netmask", FALSE, interfaceConfig.Netmask);

				(* DNS *)
				dnsElems := GetSettings(intElem, "DNS");
				FOR i := 0 TO MIN(dnsElems.GetNumberOfElements(), DNSMod.MaxNofServer) - 1 DO
					p := dnsElems.GetElement(i);
					elem := p(XML.Element);
					attribute := elem.GetAttribute("value");
					IF attribute # NIL THEN
						elemStr := attribute.GetValue();
						IF elemStr # NIL THEN
							interfaceConfig.DNS[i] := IP.StrToAdr(elemStr^);
						END;
					END;
				END;

				(* IF configuration for right device save it *)
				IF (interfaceConfig # NIL) & (interfaceConfig.Device = devName) THEN
					interfaceConfig.next := config.interfaceConfigs;
					config.interfaceConfigs := interfaceConfig;
				END;
			END;
		END;
	END Readv4Interface;


	(* Read a IPv6 interface *)
	PROCEDURE Readv6Interface;
	BEGIN
		interfaceElems := GetSections(ipv6Elem, "Interface");
		IF interfaceElems.GetNumberOfElements() # 0 THEN
			FOR interfaceNbr := 0 TO interfaceElems.GetNumberOfElements() - 1 DO
				p := interfaceElems.GetElement(interfaceNbr);
				intElem :=p (XML.Element);
				(* init config *)
				NEW(interfaceConfig);
				(*init config *)
				FOR i := 0 TO LEN(interfaceConfig.DNS) - 1 DO
					interfaceConfig.DNS[i] := IP.NilAdr;
				END;
				interfaceConfig.Device[0] := 0X;
				interfaceConfig.Protocol := IP.IPv6;
				interfaceConfig.Name := "";
				interfaceConfig.Domain := NIL;
				interfaceConfig.DHCP := TRUE;
				interfaceConfig.LocalAdr := IP.NilAdr;
				interfaceConfig.Gateway := IP.NilAdr;
				interfaceConfig.Netmask := IP.NilAdr;
				interfaceConfig.Prefix := IP.NilAdr;

				(* Device *)
				GetSettingChars(intElem, "Device", TRUE, interfaceConfig.Device);

				(* Name *)
				GetSettingChars(intElem, "Name", TRUE, interfaceConfig.Name);

				(* Domain *)
				GetSettingString(intElem, "Domain", FALSE, interfaceConfig.Domain);

				(* DHCP *)
				GetSettingBool(intElem, "DHCP", FALSE, interfaceConfig.DHCP);

				(* LocalAdr *)
				GetSettingAdr(intElem, "LocalAdr", FALSE, interfaceConfig.LocalAdr);

				(*Prefix *)
				GetSettingAdr(intElem, "Prefix", FALSE, interfaceConfig.Prefix);

				(* DNS *)
				dnsElems := GetSettings(intElem, "DNS");
				FOR i := 0 TO MIN(dnsElems.GetNumberOfElements(), DNSMod.MaxNofServer) - 1 DO
					p := dnsElems.GetElement(i);
					elem := p(XML.Element);
					attribute := elem.GetAttribute("value");
					IF attribute # NIL THEN
						elemStr := attribute.GetValue();
						IF elemStr # NIL THEN
							interfaceConfig.DNS[i] := IP.StrToAdr(elemStr^);
						END;
					END;
				END;

				(* IF configuration for right device save it *)
				IF (interfaceConfig # NIL) & (interfaceConfig.Device = devName) THEN
					interfaceConfig.next := config.interfaceConfigs;
					config.interfaceConfigs := interfaceConfig;
				END;
			END;
		END;
	END Readv6Interface;


	(* Read router configurations *)
	PROCEDURE ReadRouter;
	BEGIN
		routerElems := GetSections(ipv6Elem, "Router");
		IF routerElems.GetNumberOfElements() # 0 THEN
			FOR routerNbr := 0 TO routerElems.GetNumberOfElements() - 1 DO
				p := routerElems.GetElement(routerNbr);
				routerElem :=p (XML.Element);
				(* init router config *)
				NEW(routerConfig);

				(* Set defaults *)
				routerConfig.Device := "";
				routerConfig.SendRouterAdvertisements := FALSE;
				routerConfig.ManagedAddressConfig := FALSE;
				routerConfig.OtherStatefulConfig := FALSE;
				routerConfig.LinkMTU := 0;	(* zero means don't send MTU option *)
				routerConfig.ReachableTime := 0;
				routerConfig.RetransTimer := 0;
				routerConfig.CurrentHopLimit := 0; (* unspecified *)
				routerConfig.Lifetime := 3 * 600;	(* seconds *)
				routerConfig.Prefixes := NIL;

				(* Device *)
				GetSettingChars(routerElem, "Device", TRUE, routerConfig.Device);

				(* SendRouterAdvertisement *)
				GetSettingBool(routerElem, "SendRouterAdvertisements", FALSE, routerConfig.SendRouterAdvertisements);

				(* ManagedAddressConfig *)
				GetSettingBool(routerElem, "ManagedAddressConfig", FALSE,  routerConfig.ManagedAddressConfig);

				(* OtherStatefulConfig *)
				GetSettingBool(routerElem, "OtherStatefulConfig", FALSE, routerConfig.OtherStatefulConfig);

				(* LinkMTU *)
				GetSettingInt(routerElem, "LinkMTU", FALSE, routerConfig.LinkMTU);

				(* ReachableTime *)
				GetSettingInt(routerElem, "ReachableTime", FALSE, routerConfig.ReachableTime);

				(* RetransTimer *)
				GetSettingInt(routerElem, "RetransTimer", FALSE, routerConfig.RetransTimer);

				(* Current Hop Limit *)
				GetSettingInt(routerElem, "CurrentHopLimit", FALSE, routerConfig.CurrentHopLimit);

				(* Lifetime *)
				GetSettingInt(routerElem, "Lifetime", FALSE, routerConfig.Lifetime);

				(* Parse prefixes *)
				prefixElems := GetSections(routerElem, "Prefix");
				IF prefixElems.GetNumberOfElements() # 0 THEN
					FOR prefixNbr := 0 TO prefixElems.GetNumberOfElements() - 1 DO
						p := prefixElems.GetElement(prefixNbr);
						prefixElem :=p (XML.Element);
						(* init prefix config *)
						NEW(prefixConfig);

						(* Set defaults *)
						prefixConfig.Prefix := IP.NilAdr;
						prefixConfig.IsSitePrefix := FALSE;
						prefixConfig.ValidLifetime := 2592000; (* in seconds is 30 days *)
						prefixConfig.OnLink := TRUE;
						prefixConfig.PreferredLifetime := 604800; (* in seconds is 7 days *)
						prefixConfig.Autonomous := TRUE;

						(* Prefix *)
						GetSettingAdr(prefixElem, "Prefix", TRUE, prefixConfig.Prefix);

						(* IsSitePrefix *)
						GetSettingBool(prefixElem, "IsSitePrefix", FALSE, prefixConfig.IsSitePrefix);

						(* ValidLifetime *)
						GetSettingInt(prefixElem, "ValidLifetime", FALSE, prefixConfig.ValidLifetime);

						(* OnLink *)
						GetSettingBool(prefixElem, "OnLink", FALSE, prefixConfig.OnLink);

						(* PreferredLifetime *)
						GetSettingInt(prefixElem, "PreferredLifetime", FALSE, prefixConfig.PreferredLifetime);

						(* Autonomous *)
						GetSettingBool(prefixElem, "Autonomous", FALSE, prefixConfig.Autonomous);

						prefixConfig.next := routerConfig.Prefixes;
						routerConfig.Prefixes := prefixConfig;
					END;
				END;

				(* IF configuration for right device save it *)
				IF (routerConfig # NIL) & (routerConfig.Device = devName) THEN
					routerConfig.next := config.routerConfigs;
					config.routerConfigs := routerConfig;
				END;
			END;
		END;
	END ReadRouter;


BEGIN
	(* init *)
	hasXMLErrors := FALSE;
	res := Ok;

	NEW(config);
	config.IPForwarding:= FALSE;	(* defaults *)
	config.EchoReply := TRUE;
	config.AutoNetConfigV4 := TRUE;
	config.AutoNetConfigV6 := TRUE;
	config.PreferredProtocol := IP.IPv4;

	(* Load NetInit.XML *)
	file := Files.Old("Configuration.XML");
	IF file # NIL THEN
		Files.OpenReader(reader, file, 0);
		NEW(scanner, reader);
		scanner.reportError := Error;
		NEW(parser, scanner);
		parser.reportError := Error;
		doc := parser.Parse();
		netConfigElem := doc.GetRoot();
		netConfigElem := GetSection(netConfigElem, "NetConfig");

		IF hasXMLErrors THEN
			KernelLog.String("Net configuration not loaded"); KernelLog.Ln;
			res := ConfigFileNotValid;
			RETURN NIL;
		END;

		IF devName = "Loopback" THEN
			(* Make two loopback configuration (IPv4, IPv6) *)
			NEW(interfaceConfig);
			(*init config for IPv4 *)
			FOR i := 0 TO LEN(interfaceConfig.DNS) - 1 DO
				interfaceConfig.DNS[i] := IP.NilAdr;
			END;
			COPY(devName, interfaceConfig.Device);
			interfaceConfig.Protocol := IP.IPv4;
			interfaceConfig.Name := "Loopbackv4";
			interfaceConfig.Domain := NIL;
			interfaceConfig.DHCP := FALSE;
			interfaceConfig.LocalAdr := IP.StrToAdr("127.0.0.1");
			interfaceConfig.Gateway := IP.NilAdr;
			interfaceConfig.Netmask := IP.StrToAdr("255.255.0.0");
			interfaceConfig.Prefix := IP.NilAdr;

			interfaceConfig.next := config.interfaceConfigs;
			config.interfaceConfigs := interfaceConfig;

			(* init config for IPv6 *)
			NEW (interfaceConfig);
				FOR i := 0 TO LEN(interfaceConfig.DNS) - 1 DO
				interfaceConfig.DNS[i] := IP.NilAdr;
			END;
			COPY(devName, interfaceConfig.Device);
			interfaceConfig.Protocol := IP.IPv6;
			interfaceConfig.Name := "Loopbackv6";
			interfaceConfig.Domain := NIL;
			interfaceConfig.DHCP := FALSE;
			interfaceConfig.LocalAdr := IP.StrToAdr("::1");
			interfaceConfig.Gateway := IP.NilAdr;
			interfaceConfig.Netmask := IP.NilAdr;
			interfaceConfig.Prefix := IP.NilAdr;
			interfaceConfig.Prefix.data := 64;
			interfaceConfig.Prefix.usedProtocol := IP.IPv6;

			interfaceConfig.next := config.interfaceConfigs;
			config.interfaceConfigs := interfaceConfig;
		END;

		IF netConfigElem # NIL THEN
			(* IPForwarding *)
			GetSettingBool(netConfigElem, "IPForwarding", FALSE, config.IPForwarding);

			(* EchoReply *)
			GetSettingBool(netConfigElem, "EchoReply", FALSE, config.EchoReply);

			(* Preferred protocol *)
			GetSettingInt(netConfigElem, "PreferredProtocol", FALSE, config.PreferredProtocol);

			(* IPv4 *)
			ipv4Elem := GetSection(netConfigElem, "IPv4");

			IF ipv4Elem # NIL THEN
				(* AutoNetConfig *)
				elem := GetSection(ipv4Elem, "AutoNetConfig");
				IF elem # NIL THEN
					GetSettingBool(elem, "Enabled", TRUE, config.AutoNetConfigV4);
				ELSE
					hasXMLErrors := TRUE;
				END;

				Readv4Interface;

			ELSE
				hasXMLErrors := TRUE;
			END;

			(* IPv6 *)
			ipv6Elem := GetSection(netConfigElem, "IPv6");
			IF ipv6Elem # NIL THEN
				(* AutoNetConfig *)
				elem := GetSection(ipv6Elem, "AutoNetConfig");
				IF elem # NIL THEN
					(* Enabled *)
					GetSettingBool(elem, "Enabled", TRUE, config.AutoNetConfigV6);

					(* DNS *)
					dnsElems := GetSettings(elem, "DNS");
					FOR i := 0 TO MIN(dnsElems.GetNumberOfElements(), DNSMod.MaxNofServer) - 1 DO
						p := dnsElems.GetElement(i);
						elem := p(XML.Element);
						attribute := elem.GetAttribute("value");
						IF attribute # NIL THEN
							elemStr := attribute.GetValue();
							IF elemStr # NIL THEN
								config.AutoNetConfigV6DNS[i] := IP.StrToAdr(elemStr^);
							END;
						END;
					END;
				ELSE
					hasXMLErrors := TRUE;
				END;
				Readv6Interface;
				ReadRouter;
			ELSE
				hasXMLErrors := TRUE;
			END;
		ELSE
			hasXMLErrors := TRUE;
		END;

		IF config.interfaceConfigs = NIL THEN
			(* No configuration for this device, deliver config with only IPForwarding, EchoReplay, AutoNetConfig *)
			NEW(interfaceConfig);
			(*init config *)
			FOR i := 0 TO LEN(interfaceConfig.DNS) - 1 DO
				interfaceConfig.DNS[i] := IP.NilAdr;
			END;
			interfaceConfig.Device[0] := 0X;
			interfaceConfig.Protocol := 0;
			interfaceConfig.Name := "";
			interfaceConfig.Domain := NIL;
			interfaceConfig.DHCP := TRUE;
			interfaceConfig.LocalAdr := IP.NilAdr;
			interfaceConfig.Gateway := IP.NilAdr;
			interfaceConfig.Netmask := IP.NilAdr;
			interfaceConfig.Prefix := IP.NilAdr;
			interfaceConfig.next := NIL;
			config.interfaceConfigs := interfaceConfig;
		END;
		RETURN config;
	ELSE
		KernelLog.String("Network configuration file (NetInit.XML) not found"); KernelLog.Ln;
		res := NoConfigFile;
		RETURN NIL;
	END;
	RETURN NIL;
END GetConfig;


PROCEDURE Added(dev: Network.LinkDevice);
VAR
	config: Config;
	interfaceConfigItem: InterfaceConfig;
	ipv4IntFound: BOOLEAN;
	runnerDHCP: RunnerDHCP;
	int: IP.Interface;	 (* if autoconf = true; there are two ip interfaces (v4 & v6) *)
	intv4: IPv4.Interface;
	intv6: IPv6.Interface;
	intName: IP.Name; (* if autoconf = true; there are two ip interfaces (v4 & v6) *)
	i: LONGINT;
	res: WORD;
	linkLocalAdr: IP.Adr;
	linkLocalPrefix: IP.Adr;
	routerConfigItem: IPv6.RouterConfig;

BEGIN
	KernelLog.String("InitNetwork: LinkDevice '"); KernelLog.String(dev.name); KernelLog.String("' found."); KernelLog.Ln;
	config := GetConfig(dev.name, res);
	KernelLog.String("InitNetwork: LinkDevice '"); KernelLog.String(dev.name);
	KernelLog.String("': Get interface configuration. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;

	IF res = Ok THEN
		(* auto configuration: an IPv4 interface per device *)
		ipv4IntFound := FALSE;

		IP.preferredProtocol := config.PreferredProtocol;
		IP.IPForwarding := config.IPForwarding;
		IP.EchoReply := config.EchoReply;

		interfaceConfigItem := config.interfaceConfigs;

		WHILE interfaceConfigItem # NIL DO
			(* IPv4 or IPv6 interface? *)
			CASE interfaceConfigItem.Protocol OF
				IP.IPv4:
					NEW(intv4, interfaceConfigItem.Name, dev, res);
					int := intv4;

				|IP.IPv6:
					NEW(intv6, interfaceConfigItem.Name, dev, res);
					int := intv6;

				ELSE

			END;
			IF (int # NIL) & (res = IP.Ok) THEN
				IF int IS IPv4.Interface THEN
					ipv4IntFound := TRUE;
					int.SetAdrs(interfaceConfigItem.LocalAdr, interfaceConfigItem.Netmask, interfaceConfigItem.Gateway, res);
				END;
				IF int IS IPv6.Interface THEN
					int.SetAdrs(interfaceConfigItem.LocalAdr, interfaceConfigItem.Prefix, interfaceConfigItem.Gateway, res);
				END;
				IF res = IP.Ok THEN
					FOR i := 0 TO DNSMod.MaxNofServer - 1 DO
						IF ~IP.IsNilAdr(interfaceConfigItem.DNS[i]) THEN
							int.DNSAdd(interfaceConfigItem.DNS[i]);
						END;
					END;
					i := 0;

					IF interfaceConfigItem.DHCP THEN
						NEW(runnerDHCP, int);
					END;

					KernelLog.String("InitNetwork: Add interface for LinkDevice '"); KernelLog.String(dev.name);
					KernelLog.String("'. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;
					IF (res = Ok) & ~interfaceConfigItem.DHCP THEN
					IP.OutInterface(int);
					END;
				END;
			END;

			interfaceConfigItem := interfaceConfigItem.next;
		END;

		IF config.AutoNetConfigV6 & (dev.name # "Loopback") THEN
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
					FOR i := 0 TO DNSMod.MaxNofServer - 1 DO
						IF ~IP.IsNilAdr(config.AutoNetConfigV6DNS[i]) THEN
							int.DNSAdd(config.AutoNetConfigV6DNS[i]);
						END;
					END;
					KernelLog.String("InitNetwork: Add interface for LinkDevice '"); KernelLog.String(dev.name);
					KernelLog.String("'. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;
					IP.OutInterface(int);

					(* initiate Routers Solicitation for auto-address-configuration *)
					int(IPv6.Interface).createStatelessInterface := TRUE;
					int(IPv6.Interface).RouterSolicitation;

					(* Is this device a router? *)
					routerConfigItem := config.routerConfigs;
					(* search for current device *)
					WHILE (routerConfigItem # NIL) & (routerConfigItem.Device # dev.name) DO
						routerConfigItem := routerConfigItem.next;
					END;

					IF routerConfigItem # NIL THEN
						(* found a router configuration *)
						int(IPv6.Interface).ConfigAsRouter(routerConfigItem);
					END;
				END;
			END;
		END;

		IF config.AutoNetConfigV4  & (dev.name # "Loopback") THEN
			(* create automatic IPv4 interface if there is none *)
			IF ~ipv4IntFound THEN
				(* create an ipv4 interface (DHCP on) *)
				Strings.Concat("v4auto", dev.name, intName);
				NEW(intv4, intName, dev, res);
				int := intv4;

				IF res = IP.Ok THEN
					NEW(runnerDHCP, int);

					KernelLog.String("InitNetwork: Add interface for LinkDevice '"); KernelLog.String(dev.name);
					KernelLog.String("'. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;
				END;
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
END InitNetwork.

(*
History:
01.11.2003	mvt	Created
02.05.2005	eb	Uses Configuration.XML
06.03.2006	sst	Procedure Removed: remove all interfaces that belong to the device that is removed, not just one
*)
