MODULE Testlibusb; (** AUTHOR "fnecati"; PURPOSE "testing libusb module, LinuxAos"; *)
IMPORT libusb, StdIO, Commands, Streams;

VAR env : Commands.Context;
 	out : Streams.Writer;
 	verbose: BOOLEAN;

PROCEDURE print_endpoint_comp(ep_comp: libusb.ss_endpoint_companion_descriptor );
BEGIN
	out.String("      USB 3.0 Endpoint Companion:"); out.Ln;
	out.String("        bMaxBurst:        "); out.Int( ep_comp.bMaxBurst, 0); out.Ln;
	out.String("        bmAttributes:     "); out.Hex(ep_comp.bmAttributes, -2); out.Ln;
	out.String("        wBytesPerInterval: "); out.Int(ep_comp.wBytesPerInterval, 0); out.Ln;
	out.Update;
END print_endpoint_comp;

PROCEDURE print_endpoint(endpoint: libusb.endpoint_descriptor);
VAR i, ret: SIGNED32;
BEGIN
	out.String("      Endpoint:"); out.Ln;
	out.String("        bEndpointAddress: "); out.Hex(endpoint.bEndpointAddress, -2); out.Ln;
	out.String("        bmAttributes:     "); out.Hex(endpoint.bmAttributes, -2); out.Ln;
	out.String("        wMaxPacketSize:   "); out.Int(endpoint.wMaxPacketSize, 0); out.Ln;
	out.String("        bInterval:        "); out.Int(endpoint.bInterval, 0); out.Ln;

	out.String("        bRefresh:         "); out.Int(endpoint.bRefresh, 0); out.Ln;
	out.String("        bSynchAddress:    "); out.Int(endpoint.bSynchAddress, 0); out.Ln;
	out.Update;
(*	
	i := 0;
	WHILE i < endpoint.extra_length DO
		IF (libusb.DT_SS_ENDPOINT_COMPANION = ORD(endpoint.extra[i + 1])) THEN
			

			ret := libusb.get_ss_endpoint_companion_descriptor(NIL, endpoint, ep_comp);
			IF (libusb.SUCCESS = ret) THEN

				print_endpoint_comp(ep_comp);

				libusb.free_ss_endpoint_companion_descriptor(ep_comp);
			END;
		END;
		i := i + ORD(endpoint.extra[i]);
	END;
*)
	
END print_endpoint;

PROCEDURE print_altsetting(interface: libusb.interface_descriptor );
VAR i: SIGNED32;
BEGIN
	out.String("    Interface:");out.Ln;
	out.String("      bInterfaceNumber:   "); out.Int( interface.bInterfaceNumber, 0); out.Ln;
	out.String("      bAlternateSetting:  "); out.Int( interface.bAlternateSetting, 0);out.Ln;
	out.String("      bNumEndpoints:      "); out.Int( interface.bNumEndpoints, 0);out.Ln;
	out.String("      bInterfaceClass:    "); out.Int( interface.bInterfaceClass, 0);out.Ln;
	out.String("      bInterfaceSubClass: "); out.Int( interface.bInterfaceSubClass, 0);out.Ln;
	out.String("      bInterfaceProtocol: "); out.Int( interface.bInterfaceProtocol, 0);out.Ln;
	out.String("      iInterface:         "); out.Int( interface.iInterface, 0); out.Ln;
	out.Update;	
	i := 0;
	WHILE i < interface.bNumEndpoints DO
		 print_endpoint(interface.endpoint[i]);
		 INC(i);
	END;
	out.Update;
END print_altsetting;

PROCEDURE print_2_0_ext_cap(usb_2_0_ext_cap: libusb.usb_2_0_extension_descriptor );
BEGIN
	out.String("    USB 2.0 Extension Capabilities:");out.Ln;
	out.String("      bDevCapabilityType: "); out.Int( usb_2_0_ext_cap.bDevCapabilityType, 0); out.Ln;
	out.String("      bmAttributes:       "); out.Hex( usb_2_0_ext_cap.bmAttributes, -2); out.Ln;
	out.Update;
END print_2_0_ext_cap;

PROCEDURE print_ss_usb_cap(ss_usb_cap: libusb.ss_usb_device_capability_descriptor );
BEGIN
	out.String("    USB 3.0 Capabilities:");out.Ln;
	out.String("      bDevCapabilityType: ");  out.Int( ss_usb_cap.bDevCapabilityType, 0); out.Ln;
	out.String("      bmAttributes:       ");  out.Hex( ss_usb_cap.bmAttributes, -2); out.Ln;
	out.String("      wSpeedSupported:    ");  out.Int( ss_usb_cap.wSpeedSupported, 0); out.Ln;
	out.String("      bFunctionalitySupport: "); out.Int( ss_usb_cap.bFunctionalitySupport, 0); out.Ln;
	out.String("      bU1devExitLat:      "); out.Int( ss_usb_cap.bU1DevExitLat, 0); out.Ln;
	out.String("      bU2devExitLat:      "); out.Int( ss_usb_cap.bU2DevExitLat, 0); out.Ln;
	out.Update;
END print_ss_usb_cap;

PROCEDURE print_bos(handle: libusb.device_handle);
VAR
	bos: libusb.bos_descriptor;
	usb_2_0_extension: libusb.usb_2_0_extension_descriptor;
	dev_cap: libusb.ss_usb_device_capability_descriptor;
	ret: SIGNED32;
BEGIN
	ret := libusb.get_bos_descriptor(handle, bos);
	IF ret < 0 THEN out.String("bos ret<0; "); out.Ln; out.Update; RETURN END;

	out.String("  Binary Object Store (BOS):");out.Ln;
	out.String("    wTotalLength:       "); out.Int( bos.wTotalLength, 0); out.Ln;
	out.String("    bNumDeviceCaps:     "); out.Int( bos.bNumDeviceCaps, 0); out.Ln;
	out.Update;

	IF (bos.dev_capability.bDevCapabilityType = libusb.BT_USB_2_0_EXTENSION) THEN
		ret :=  libusb.get_usb_2_0_extension_descriptor(NIL, bos.dev_capability,usb_2_0_extension);
		IF ret < 0 THEN RETURN END;
		print_2_0_ext_cap(usb_2_0_extension);
		libusb.free_usb_2_0_extension_descriptor(usb_2_0_extension);
	END;

	IF (bos.dev_capability.bDevCapabilityType = libusb.BT_SS_USB_DEVICE_CAPABILITY) THEN
		ret := libusb.get_ss_usb_device_capability_descriptor(NIL, bos.dev_capability, dev_cap);
		IF ret < 0 THEN RETURN END;
		print_ss_usb_cap(dev_cap);
		libusb.free_ss_usb_device_capability_descriptor(dev_cap);
	END;

	libusb.free_bos_descriptor(bos);
END print_bos;

PROCEDURE print_interface(interface: libusb.Interface);
VAR i: SIGNED32;
BEGIN
	FOR i := 0 TO  interface.num_altsetting-1 DO
		print_altsetting(interface.altsetting[i]);
	END;
END print_interface;

PROCEDURE print_configuration(config:  libusb.config_descriptor);
VAR i: SIGNED32;
BEGIN
	out.String("  Configuration:");out.Ln;
	out.String("    wTotalLength:         "); out.Int( config.wTotalLength, 0); out.Ln;
	out.String("    bNumInterfaces:       "); out.Int( config.bNumInterfaces, 0); out.Ln;
	out.String("    bConfigurationValue:  "); out.Int( config.bConfigurationValue, 0); out.Ln;
	out.String("    iConfiguration:       "); out.Int( config.iConfiguration, 0); out.Ln;
	out.String("    bmAttributes:         "); out.Hex( config.bmAttributes, -2); out.Ln;
	out.String("    MaxPower:             "); out.Int( config.MaxPower, 0); out.Ln;
	out.Update;
	
	FOR i := 0 TO config.bNumInterfaces-1 DO
		print_interface(config.interface[i]);
	END;

END print_configuration;


PROCEDURE print_device(dev: libusb.device;  level: SIGNED32);
VAR
	desc : libusb.device_descriptor;
	config{UNTRACED}: libusb.config_descriptor;
	handle {UNTRACED}: libusb.device_handle;
	string: ARRAY 256 OF CHAR;
	ret, i: SIGNED32;
BEGIN
	ret := libusb.get_device_descriptor(dev, desc);
	IF (ret < 0) THEN
		out.String("failed to get device descriptor");
		RETURN;
	END;

	ret := libusb.open(dev, handle);

	out.String("Dev (bus "); i := (libusb.get_bus_number(dev)); out.Int(i,0); 
	out.String(", device "); i := (libusb.get_device_address(dev)); out.Int(i, 0); 
	out.String("): ");
	
	out.Update;
	
	IF libusb.SUCCESS = ret  THEN
		IF (desc.iManufacturer) > 0 THEN
			ret := libusb.get_string_descriptor_ascii(handle, desc.iManufacturer, ADDRESSOF(string[0]), LEN(string));
			IF (ret > 0) THEN
				(* snprintf(description, sizeof(description), "%s - ", string); *)
				out.String(string); out.String(" - ");
			ELSE
				(* snprintf(description, sizeof(description), "%04X - ", desc.idVendor); *)
				out.Hex(desc.idVendor, -4); out.String(" - ");
			END;
		ELSE
			(* snprintf(description, sizeof(description), "%04X - ",	desc.idVendor); *)
			out.Hex(desc.idVendor, -4); out.String(" - ");
		END;
		
		IF ((desc.iProduct) > 0) THEN
			ret := libusb.get_string_descriptor_ascii(handle, desc.iProduct, ADDRESSOF(string[0]), LEN(string));
			IF (ret > 0) THEN
				out.String(string); out.String(" ");
			ELSE
				out.Hex(desc.idProduct, -4)
			END
		ELSE
			out.Hex(desc.idProduct, -4)
		END
	ELSE
		out.Hex(desc.idVendor, -4); out.String(" - "); out.Hex(desc.idProduct, -4);
	END;

	out.Ln; out.Update;

	IF (handle # NIL) & verbose THEN
		IF ((desc.iSerialNumber) > 0) THEN
			ret := libusb.get_string_descriptor_ascii(handle, desc.iSerialNumber, ADDRESSOF(string[0]), LEN(string));
			IF (ret > 0) THEN
				 out.String("  - Serial Number: "); out.String(string); out.Ln;
			END;
		END;
	END;

	IF (verbose) THEN
		FOR i := 0 TO (desc.bNumConfigurations)-1 DO
			ret := libusb.get_config_descriptor(dev, SHORT(SHORT(i)), config);
			IF (libusb.SUCCESS = ret)  THEN
				print_configuration(config);
				libusb.free_config_descriptor(config);
			ELSE
				out.String("  Couldn't retrieve descriptors"); out.Ln;
			END;
		END;
		
(*		out.String("desc.bcdUSB: "); out.Hex(desc.bcdUSB, 2); out.Ln; out.Update; *)
		
		IF (handle # NIL) & (desc.bcdUSB >= 0x0201) THEN
			out.String("print dev bos -1 "); out.Ln; out.Update;
			print_bos(handle);
			out.String("print dev bos -2 "); out.Ln; out.Update;
		END;
	END;

	IF handle # NIL THEN
		libusb.close(handle);
	END;
	
	out.Update;
END print_device;

PROCEDURE Do*;
VAR
	ctx : libusb.context;
	devs {UNTRACED} : libusb.DeviceList;
	version: libusb.version;
	numDevs,  res, i: SIGNED32;
BEGIN 
	out := env.out;
	
	out.String("Testlibusb.Do:"); out.Ln; out.Update;
	res := libusb.init(ctx);
	IF res < 0  THEN 
		out.String("ERROR: libusb.init res= "); out.Int(res, 0); out.Ln; out.Update;
		RETURN
	END;

	(* libusb.set_debug(ctx, 4); *)
	
	version := libusb.get_version();	
	IF version # NIL THEN
		out.String("libusb version: "); 
		out.String(" major: "); out.Int(version.major, 0);  
		out.String(", minor: "); out.Int(version.minor, 0);
		out.String(", micro: "); out.Int(version.micro, 0);	
	END;
	out.Ln; out.Update;
	
	numDevs := libusb.get_device_list(ctx, devs);
	out.String("# of devices: "); out.Int(numDevs, 0); out.Ln; out.Update;
	
	FOR i:=0 TO numDevs-1 DO
		print_device(devs[i], 0);
	END;
	
	out.String("error name for ERROR_NO_DEVICE (-4): ");
	out.String(libusb.strerror(libusb.ERROR_NO_DEVICE)^);
	out.Ln;
	
	libusb.free_device_list(devs, 1);
	libusb.exit (ctx); 

	out.Update;
END Do;

BEGIN
	env := StdIO.env;
	verbose := TRUE
END Testlibusb.

System.Free Testlibusb ~
System.Free libusb ~ 

Testlibusb.Do ~ 




























# sudo aos -x Testlibusb.Do ~ 


Compiler.Compile 
  libusb.Mod
  Testlibusb.Mod
~~

