module AcStreamVideoOut; (** AUTHOR ""; PURPOSE ""; *)

import
	system, AcAxisIo;

const
	CmdSetEnabled = 0;
	CmdSetHorizActiveSize = 1;
	CmdSetHorizFrontPorch = 2;
	CmdSetHorizSyncWidth = 3;
	CmdSetHorizBackPorch = 4;
	CmdSetHorizSyncPolarity = 5;

	CmdSetVertActiveSize = 6;
	CmdSetVertFrontPorch = 7;
	CmdSetVertSyncWidth = 8;
	CmdSetVertBackPorch = 9;
	CmdSetVertSyncPolarity = 10;

type
	Controller* = record
		cfg-: AcAxisIo.Output; (** configuration port *)
		enabled-: boolean; (** TRUE if the PWM output is enabled *)
		
		pixelClock-: real; (** pixel clock in Hz *)

		horizActiveSize-: longint;
		horizFrontPorch-: longint;
		horizSyncWidth-: longint;
		horizBackPorch-: longint;
		horizSyncPolarity-: boolean;

		vertActiveSize-: longint;
		vertFrontPorch-: longint;
		vertSyncWidth-: longint;
		vertBackPorch-: longint;
		vertSyncPolarity-: boolean;
	end;

	procedure InitController*(var ctl: Controller; cfg: AcAxisIo.Output; pixelClock: real);
	begin
		ctl.cfg := cfg;
		ctl.pixelClock := pixelClock;
		Enable(ctl,false);
(*
		(* setup default video output settings *)
		SetHorizActiveSize(ctl,1024);z
		SetHorizFrontPorch(ctl,24);
		SetHorizSyncWidth(ctl,136);
		SetHorizBackPorch(ctl,160);
		SetHorizSyncPolarity(ctl,true);

		SetVertActiveSize(ctl,768);
		SetVertFrontPorch(ctl,3);
		SetVertSyncWidth(ctl,6);
		SetVertBackPorch(ctl,29);
		SetVertSyncPolarity(ctl,true);
*)
	end InitController;

	(**
		Enable/disable video output
	*)
	procedure Enable*(var ctl: Controller; enable: boolean);
	begin
		if enable then
			ctl.cfg << CmdSetEnabled + lsh(1,4);
		else
			ctl.cfg << CmdSetEnabled;
		end;
		ctl.enabled := enable;
	end Enable;

	procedure SetHorizActiveSize*(var ctl: Controller; n: longint);
	begin
		ctl.cfg << CmdSetHorizActiveSize + lsh(n-1,4);
		ctl.horizActiveSize := n;
	end SetHorizActiveSize;

	procedure SetHorizFrontPorch*(var ctl: Controller; n: longint);
	begin
		ctl.cfg << CmdSetHorizFrontPorch + lsh(n-1,4);
		ctl.horizFrontPorch := n;
	end SetHorizFrontPorch;

	procedure SetHorizSyncWidth*(var ctl: Controller; n: longint);
	begin
		ctl.cfg << CmdSetHorizSyncWidth + lsh(n-1,4);
		ctl.horizSyncWidth := n;
	end SetHorizSyncWidth;

	procedure SetHorizBackPorch*(var ctl: Controller; n: longint);
	begin
		ctl.cfg << CmdSetHorizBackPorch + lsh(n-1,4);
		ctl.horizBackPorch := n;
	end SetHorizBackPorch;

	procedure SetHorizSyncPolarity*(var ctl: Controller; polarity: boolean);
	var n: longint;
	begin
		if polarity then n := 1; else n := 0; end;
		ctl.cfg << CmdSetHorizSyncPolarity + lsh(n,4);
		ctl.horizSyncPolarity := polarity;
	end SetHorizSyncPolarity;

	procedure SetVertActiveSize*(var ctl: Controller; n: longint);
	begin
		ctl.cfg << CmdSetVertActiveSize + lsh(n-1,4);
		ctl.vertActiveSize := n;
	end SetVertActiveSize;

	procedure SetVertFrontPorch*(var ctl: Controller; n: longint);
	begin
		ctl.cfg << CmdSetVertFrontPorch + lsh(n-1,4);
		ctl.vertFrontPorch := n;
	end SetVertFrontPorch;

	procedure SetVertSyncWidth*(var ctl: Controller; n: longint);
	begin
		ctl.cfg << CmdSetVertSyncWidth + lsh(n-1,4);
		ctl.vertSyncWidth := n;
	end SetVertSyncWidth;

	procedure SetVertBackPorch*(var ctl: Controller; n: longint);
	begin
		ctl.cfg << CmdSetVertBackPorch + lsh(n-1,4);
		ctl.vertBackPorch := n;
	end SetVertBackPorch;

	procedure SetVertSyncPolarity*(var ctl: Controller; polarity: boolean);
	var n: longint;
	begin
		if polarity then n := 1; else n := 0; end;
		ctl.cfg << CmdSetVertSyncPolarity + lsh(n,4);
		ctl.vertSyncPolarity := polarity;
	end SetVertSyncPolarity;

end AcStreamVideoOut.
