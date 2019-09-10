(**
	AUTHOR: Alexey Morozov
	PURPOSE: Processing System (PS) interface for Xilinx ADC (XADC) on Zynq
*)
MODULE PsXAdc;

IMPORT
	SYSTEM, Platform;

CONST
	(**
		XADC configuration register definitions
	*)
	CFG_ENABLE_MASK = 0x80000000; (** Enable access from PS mask *)
	CFG_CFIFOTH_MASK = 0x00F00000; (** Command FIFO Threshold mask *)
	CFG_DFIFOTH_MASK = 0x000F0000; (** Data FIFO Threshold mask *)
	CFG_WEDGE_MASK = 0x00002000; (** Write Edge Mask *)
	CFG_REDGE_MASK = 0x00001000; (** Read Edge Mask *)
	CFG_TCKRATE_MASK = 0x00000300; (** Clock freq control *)
	CFG_IGAP_MASK = 0x0000001F; (** Idle Gap between successive commands *)

	(**
		XADC interrupt status/mask register definitions
		The definitions are same for the Interrupt Status Register and
		Interrupt Mask Register. They are defined only once.
	 *)
	INTX_ALL_MASK = 0x000003FF; (** Alarm Signals Mask  *)
	INTX_CFIFO_LTH_MASK = 0x00000200; (** CMD FIFO less than threshold *)
	INTX_DFIFO_GTH_MASK = 0x00000100; (** Data FIFO greater than threshold *)
	INTX_OT_MASK = 0x00000080; (** Over temperature Alarm Status *)
	INTX_ALM_ALL_MASK = 0x0000007F; (** Alarm Signals Mask  *)
	INTX_ALM6_MASK = 0x00000040; (** Alarm 6 Mask  *)
	INTX_ALM5_MASK = 0x00000020; (** Alarm 5 Mask  *)
	INTX_ALM4_MASK = 0x00000010; (** Alarm 4 Mask  *)
	INTX_ALM3_MASK = 0x00000008; (** Alarm 3 Mask  *)
	INTX_ALM2_MASK = 0x00000004; (** Alarm 2 Mask  *)
	INTX_ALM1_MASK = 0x00000002; (** Alarm 1 Mask  *)
	INTX_ALM0_MASK = 0x00000001; (** Alarm 0 Mask  *)

	(**
		XADC miscellaneous register definitions
	*)
	MSTS_CFIFO_LVL_MASK = 0x000F0000; (** Command FIFO Level mask *)
	MSTS_DFIFO_LVL_MASK = 0x0000F000; (** Data FIFO Level Mask  *)
	MSTS_CFIFOF_MASK = 0x00000800; (** Command FIFO Full Mask  *)
	MSTS_CFIFOE_MASK = 0x00000400; (** Command FIFO Empty Mask  *)
	MSTS_DFIFOF_MASK = 0x00000200; (** Data FIFO Full Mask  *)
	MSTS_DFIFOE_MASK = 0x00000100; (** Data FIFO Empty Mask  *)
	MSTS_OT_MASK = 0x00000080; (** Over Temperature Mask *)
	MSTS_ALM_MASK = 0x0000007F; (** Alarms Mask  *)

	(**
		XADC miscellaneous control register definitions
	*)
	MCTL_RESET_MASK = 0x00000010; (** Reset XADC *)
	MCTL_FLUSH_MASK = 0x00000001; (** Flush the FIFOs *)

	(*
		XADC internal channel registers
	 *)
	TEMP_REG =  0x00; (** On-chip Temperature Reg *)
	VCCINT_REG = 0x01; (** On-chip VCCINT Data Reg *)
	VCCAUX_REG = 0x02; (** On-chip VCCAUX Data Reg *)
	VPVN_REG = 0x03; (** ADC out of VP/VN	   *)
	VREFP_REG = 0x04; (** On-chip VREFP Data Reg *)
	VREFN_REG = 0x05; (** On-chip VREFN Data Reg *)
	VBRAM_REG = 0x06; (** On-chip VBRAM , 7 Series *)
	ADC_A_SUPPLY_CALIB_REG = 0x08; (** ADC A Supply Offset Reg *)
	ADC_A_REG_CALIB_REG = 0x09; (** ADC A Offset Data Reg *)
	ADC_A_GAINERR_CALIB_REG = 0x0A; (** ADC A Gain Error Reg  *)
	VCCPINT_REG = 0x0D; (** On-chip VCCPINT Reg, Zynq *)
	VCCPAUX_REG = 0x0E; (** On-chip VCCPAUX Reg, Zynq *)
	VCCPDRO_REG = 0x0F; (** On-chip VCCPDRO Reg, Zynq *)

	(*
		XADC external channel registers
	 *)
	AUX00_REG = 0x10; (** ADC out of VAUXP0/VAUXN0 *)
	AUX01_REG = 0x11; (** ADC out of VAUXP1/VAUXN1 *)
	AUX02_REG = 0x12; (** ADC out of VAUXP2/VAUXN2 *)
	AUX03_REG = 0x13; (** ADC out of VAUXP3/VAUXN3 *)
	AUX04_REG = 0x14; (** ADC out of VAUXP4/VAUXN4 *)
	AUX05_REG = 0x15; (** ADC out of VAUXP5/VAUXN5 *)
	AUX06_REG = 0x16; (** ADC out of VAUXP6/VAUXN6 *)
	AUX07_REG = 0x17; (** ADC out of VAUXP7/VAUXN7 *)
	AUX08_REG = 0x18; (** ADC out of VAUXP8/VAUXN8 *)
	AUX09_REG = 0x19; (** ADC out of VAUXP9/VAUXN9 *)
	AUX10_REG = 0x1A; (** ADC out of VAUXP10/VAUXN10 *)
	AUX11_REG = 0x1B; (** ADC out of VAUXP11/VAUXN11 *)
	AUX12_REG = 0x1C; (** ADC out of VAUXP12/VAUXN12 *)
	AUX13_REG = 0x1D; (** ADC out of VAUXP13/VAUXN13 *)
	AUX14_REG = 0x1E; (** ADC out of VAUXP14/VAUXN14 *)
	AUX15_REG = 0x1F; (** ADC out of VAUXP15/VAUXN15 *)

	(*
		XADC registers for maximum/minimum values of the on chip Temperature/VCCINT/VCCAUX data
	*)
	MAX_TEMP_REG = 0x20; (** Max Temperature Reg *)
	MAX_VCCINT_REG = 0x21; (** Max VCCINT Register *)
	MAX_VCCAUX_REG = 0x22; (** Max VCCAUX Register *)
	MAX_VCCBRAM_REG = 0x23; (** Max BRAM Register, 7 series *)
	MIN_TEMP_REG = 0x24; (** Min Temperature Reg *)
	MIN_VCCINT_REG = 0x25; (** Min VCCINT Register *)
	MIN_VCCAUX_REG = 0x26; (** Min VCCAUX Register *)
	MIN_VCCBRAM_REG = 0x27; (** Min BRAM Register, 7 series *)
	MAX_VCCPINT_REG = 0x28; (** Max VCCPINT Register, Zynq *)
	MAX_VCCPAUX_REG = 0x29; (** Max VCCPAUX Register, Zynq *)
	MAX_VCCPDRO_REG = 0x2A; (** Max VCCPDRO Register, Zynq *)
	MIN_VCCPINT_REG = 0x2C; (** Min VCCPINT Register, Zynq *)
	MIN_VCCPAUX_REG = 0x2D; (** Min VCCPAUX Register, Zynq *)
	MIN_VCCPDRO_REG = 0x2E; (** Min VCCPDRO Register,Zynq *)
	 (* Undefined 0x2F to 0x3E *)
	FLAG_REG = 0x3F; (** Flag Register *)

	(*
		XADC configuration registers
	 *)
	CFR0_REG =0x40; (** Configuration Register 0 *)
	CFR1_REG =0x41; (** Configuration Register 1 *)
	CFR2_REG =0x42; (** Configuration Register 2 *)

	(* Test Registers 0x43 to 0x47 *)

	(*
		XADC sequence registers
	 *)
	SEQ00_REG =0x48; (** Seq Reg 00 Adc Channel Selection *)
	SEQ01_REG =0x49; (** Seq Reg 01 Adc Channel Selection *)
	SEQ02_REG =0x4A; (** Seq Reg 02 Adc Average Enable *)
	SEQ03_REG =0x4B; (** Seq Reg 03 Adc Average Enable *)
	SEQ04_REG =0x4C; (** Seq Reg 04 Adc Input Mode Select *)
	SEQ05_REG =0x4D; (** Seq Reg 05 Adc Input Mode Select *)
	SEQ06_REG =0x4E; (** Seq Reg 06 Adc Acquisition Select *)
	SEQ07_REG =0x4F; (** Seq Reg 07 Adc Acquisition Select *)

	(*
		XADC Alarm Threshold/Limit Registers (ATR)
	 *)
	ATR_TEMP_UPPER_REG =0x50; (** Temp Upper Alarm Register *)
	ATR_VCCINT_UPPER_REG =0x51; (** VCCINT Upper Alarm Reg *)
	ATR_VCCAUX_UPPER_REG =0x52; (** VCCAUX Upper Alarm Reg *)
	ATR_OT_UPPER_REG =0x53; (** Over Temp Upper Alarm Reg *)
	ATR_TEMP_LOWER_REG =0x54; (** Temp Lower Alarm Register *)
	ATR_VCCINT_LOWER_REG =0x55; (** VCCINT Lower Alarm Reg *)
	ATR_VCCAUX_LOWER_REG =0x56; (** VCCAUX Lower Alarm Reg *)
	ATR_OT_LOWER_REG =0x57; (** Over Temp Lower Alarm Reg *)
	ATR_VBRAM_UPPER_REG =0x58; (** VBRAM Upper Alarm, 7 series *)
	ATR_VCCPINT_UPPER_REG =0x59; (** VCCPINT Upper Alarm, Zynq *)
	ATR_VCCPAUX_UPPER_REG =0x5A; (** VCCPAUX Upper Alarm, Zynq *)
	ATR_VCCPDRO_UPPER_REG =0x5B; (** VCCPDRO Upper Alarm, Zynq *)
	ATR_VBRAM_LOWER_REG =0x5C; (** VRBAM Lower Alarm, 7 Series *)
	ATR_VCCPINT_LOWER_REG =0x5D; (** VCCPINT Lower Alarm, Zynq *)
	ATR_VCCPAUX_LOWER_REG =0x5E; (** VCCPAUX Lower Alarm, Zynq *)
	ATR_VCCPDRO_LOWER_REG =0x5F; (** VCCPDRO Lower Alarm, Zynq *)

	(* Undefined 0x60 to 0x7F *)

	(**
		Configuration Register 1 (CFR1) definitions
	*)
	CFR1_SEQ_VALID_MASK = 0xF000; (** Sequence bit Mask *)
	CFR1_SEQ_SAFEMODE_MASK = 0x0000; (** Default Safe Mode *)
	CFR1_SEQ_ONEPASS_MASK = 0x1000; (** Onepass through Seq *)
	CFR1_SEQ_CONTINPASS_MASK = 0x2000; (** Continuous Cycling Seq *)
	CFR1_SEQ_SINGCHAN_MASK = 0x3000; (** Single channel - No Seq *)
	CFR1_SEQ_SIMUL_SAMPLING_MASK = 0x4000; (** Simulataneous Sampling Mask *)
	CFR1_SEQ_INDEPENDENT_MASK = 0x8000; (** Independent Mode *)
	CFR1_SEQ_SHIFT = 12; (** Sequence bit shift *)
	CFR1_ALM_VCCPDRO_MASK = 0x0800; (** Alm 6 - VCCPDRO, Zynq  *)
	CFR1_ALM_VCCPAUX_MASK = 0x0400; (** Alm 5 - VCCPAUX, Zynq *)
	CFR1_ALM_VCCPINT_MASK = 0x0200; (** Alm 4 - VCCPINT, Zynq *)
	CFR1_ALM_VBRAM_MASK = 0x0100; (** Alm 3 - VBRAM, 7 series *)
	CFR1_CAL_VALID_MASK = 0x00F0; (** Valid Calibration Mask *)
	CFR1_CAL_PS_GAIN_OFFSET_MASK = 0x0080; (** Calibration 3 -Power Supply Gain/Offset Enable *)
	CFR1_CAL_PS_OFFSET_MASK = 0x0040; (** Calibration 2 -Power Supply Offset Enable *)
	CFR1_CAL_ADC_GAIN_OFFSET_MASK = 0x0020; (** Calibration 1 -ADC Gain Offset Enable *)
	CFR1_CAL_ADC_OFFSET_MASK = 0x0010; (** Calibration 0 -ADC Offset Enable *)
	CFR1_CAL_DISABLE_MASK = 0x0000; (** No Calibration *)
	CFR1_ALM_ALL_MASK = 0x0F0F; (** Mask for all alarms *)
	CFR1_ALM_VCCAUX_MASK = 0x0008; (** Alarm 2 - VCCAUX Enable *)
	CFR1_ALM_VCCINT_MASK = 0x0004; (** Alarm 1 - VCCINT Enable *)
	CFR1_ALM_TEMP_MASK = 0x0002; (** Alarm 0 - Temperature *)
	CFR1_OT_MASK = 0x0001; (** Over Temperature Enable *)

	(**
		Configuration Register 2 (CFR2) definitions
	 *)
	CFR2_CD_VALID_MASK =	0xFF00 ; (** Clock Divisor bit Mask *)
	CFR2_CD_SHIFT = 8; (** Num of shift on division *)
	CFR2_CD_MIN = 8; (** Minimum value of divisor *)
	CFR2_CD_MAX = 255; (** Maximum value of divisor *)

	CFR2_PD_MASK = 0x0030; (** Power Down Mask *)
	CFR2_PD_XADC_MASK = 0x0030; (** Power Down XADC Mask *)
	CFR2_PD_ADC1_MASK = 0x0020; (** Power Down ADC1 Mask *)
	CFR2_PD_SHIFT = 4; (** Power Down Shift *)

	(**
		Sequence register (SEQ) definitions
	 *)
	SEQ_CH_CALIB = 0x00000001; (** ADC Calibration Channel *)
	SEQ_CH_VCCPINT = 0x00000020; (** VCCPINT, Zynq Only *)
	SEQ_CH_VCCPAUX = 0x00000040; (** VCCPAUX, Zynq Only *)
	SEQ_CH_VCCPDRO = 0x00000080; (** VCCPDRO, Zynq Only *)
	SEQ_CH_TEMP = 0x00000100; (** On Chip Temperature Channel *)
	SEQ_CH_VCCINT = 0x00000200; (** VCCINT Channel *)
	SEQ_CH_VCCAUX = 0x00000400; (** VCCAUX Channel *)
	SEQ_CH_VPVN = 0x00000800; (** VP/VN analog inputs Channel *)
	SEQ_CH_VREFP = 0x00001000; (** VREFP Channel *)
	SEQ_CH_VREFN = 0x00002000; (** VREFN Channel *)
	SEQ_CH_VBRAM = 0x00004000; (** VBRAM Channel, 7 series *)
	SEQ_CH_AUX00 = 0x00010000; (** 1st Aux Channel *)
	SEQ_CH_AUX01 = 0x00020000; (** 2nd Aux Channel *)
	SEQ_CH_AUX02 = 0x00040000; (** 3rd Aux Channel *)
	SEQ_CH_AUX03 = 0x00080000; (** 4th Aux Channel *)
	SEQ_CH_AUX04 = 0x00100000; (** 5th Aux Channel *)
	SEQ_CH_AUX05 = 0x00200000; (** 6th Aux Channel *)
	SEQ_CH_AUX06 = 0x00400000; (** 7th Aux Channel *)
	SEQ_CH_AUX07 = 0x00800000; (** 8th Aux Channel *)
	SEQ_CH_AUX08 = 0x01000000; (** 9th Aux Channel *)
	SEQ_CH_AUX09 = 0x02000000; (** 10th Aux Channel *)
	SEQ_CH_AUX10 = 0x04000000; (** 11th Aux Channel *)
	SEQ_CH_AUX11 = 0x08000000; (** 12th Aux Channel *)
	SEQ_CH_AUX12 = 0x10000000; (** 13th Aux Channel *)
	SEQ_CH_AUX13 = 0x20000000; (** 14th Aux Channel *)
	SEQ_CH_AUX14 = 0x40000000; (** 15th Aux Channel *)
	SEQ_CH_AUX15 = 0x80000000; (** 16th Aux Channel *)

	SEQ00_CH_VALID_MASK = 0x7FE1; (** Mask for the valid channels *)
	SEQ01_CH_VALID_MASK = 0xFFFF; (** Mask for the valid channels *)

	SEQ02_CH_VALID_MASK = 0x7FE0; (** Mask for the valid channels *)
	SEQ03_CH_VALID_MASK = 0xFFFF; (** Mask for the valid channels *)

	SEQ04_CH_VALID_MASK = 0x0800; (** Mask for the valid channels *)
	SEQ05_CH_VALID_MASK = 0xFFFF; (** Mask for the valid channels *)

	SEQ06_CH_VALID_MASK = 0x0800; (** Mask for the valid channels *)
	SEQ07_CH_VALID_MASK = 0xFFFF; (** Mask for the valid channels *)


	SEQ_CH_AUX_SHIFT = 16; (** Shift for the Aux Channel *)

	(**
		OT upper alarm threshold register definitions
	*)
	ATR_OT_UPPER_ENB_MASK = 0x000F; (** Mask for OT enable *)
	ATR_OT_UPPER_VAL_MASK = 0xFFF0; (** Mask for OT value *)
	ATR_OT_UPPER_VAL_SHIFT = 4; (** Shift for OT value *)
	ATR_OT_UPPER_ENB_VAL = 0x0003; (** Value for OT enable *)
	ATR_OT_UPPER_VAL_MAX = 0x0FFF; (** Max OT value *)

	(*
		JTAG DRP definitions
	*)
	JTAG_DATA_MASK = 0x0000FFFF; (* Mask for the Data *)
	JTAG_ADDR_MASK = 0x03FF0000; (* Mask for the Addr *)
	JTAG_ADDR_SHIFT = 16; (* Shift for the Addr *)
	JTAG_CMD_MASK = 0x3C000000; (* Mask for the Cmd *)
	JTAG_CMD_WRITE_MASK = 0x08000000; (* Mask for CMD Write *)
	JTAG_CMD_READ_MASK = 0x04000000; (* Mask for CMD Read *)
	JTAG_CMD_SHIFT = 26; (* Shift for the Cmd *)

	(** Unlock register definitions *)
	UNLK_REG = 0x034; (** unlock register *)
	UNLK_VALUE = 0x757BDF0D; (** unlock value *)


	(**
		ADC channels
	*)
	ChTemp* = 0; (** On Chip Temperature *)
	ChVccInt* = 1; (** VCCINT *)
	ChVccAux* = 2; (** VCCAUX *)
	ChVpVn* = 3; (** VP/VN dedicated analog inputs *)
	ChVrefP* = 4; (** VREFP *)
	ChVrefN* = 5; (** VREFN *)
	ChVccBram* = 6; (** On-chip VBRAM Data Reg, 7 series *)
	ChSupplyCalib* = 7; (** Supply Calib Data Reg *)
	ChAdcCalib* = 8; (** ADC Offset Channel Reg *)
	ChGainErrCalib* = 9; (** Gain Error Channel Reg  *)
	ChVccpInt* = 13; (** On-chip PS VCCPINT Channel , Zynq only *)
	ChVccpAux* = 14; (** On-chip PS VCCPAUX Channel , Zynq only *)
	ChVccoDdr* = 15; (** On-chip PS VCCPDRO Channel , Zynq only *)
	ChAux0* = 16; (** Channel number for 1st Aux Channel *)
	ChAux15* = 31; (** Channel number for Last Aux channel *)

	(** Channel sequencer modes *)
	SeqDefault* = 0; (** Default (safe) mode *)
	SeqSinglePass* = 1; (*** One pass through sequencer *)
	SeqContinuous* = 2; (** Continuous cycling sequencer *)
	SeqSingleChannel* = 3; (** Single channel -no sequencing *)
	SeqSimultaneous* = 4; (** Simultaneous sampling *)
	SeqIndependent* = 8; (** Independent ADC mode *)

	UnipolarMode* = 0;
	BipolarMode* = 1;

VAR
	devCfg: Platform.DevCfgRegisters;
	initialized := FALSE : BOOLEAN;

	PROCEDURE Initialize*();
	VAR d: SIGNED32;
	BEGIN
		IF initialized THEN RETURN; END;

		(* Write Unlock value to Device Config Unlock register *)
		devCfg.UNLOCK := UNLK_VALUE;

		(* Enable the PS access of xadc and set FIFO thresholds *)
		d := devCfg.XADCIF_CFG;
		d := SYSTEM.VAL(SIGNED32,SYSTEM.VAL(SET,d) + SYSTEM.VAL(SET,CFG_ENABLE_MASK + CFG_CFIFOTH_MASK + CFG_DFIFOTH_MASK));
		devCfg.XADCIF_CFG := d;

		(* release xadc from reset *)
		devCfg.XADCIF_MCTL := 0;
		initialized := TRUE;
	END Initialize;

	PROCEDURE Deinitialize*();
	VAR d: SIGNED32;
	BEGIN
		IF ~initialized THEN RETURN; END;
		d := devCfg.XADCIF_CFG;
		d := SYSTEM.VAL(SIGNED32,SYSTEM.VAL(SET,d) - SYSTEM.VAL(SET,CFG_ENABLE_MASK));
		devCfg.XADCIF_CFG := d;
	END Deinitialize;

	(**
		Reset the XADC
	*)
	PROCEDURE Reset*();
	BEGIN
		(* generate the reset by control register and release from reset *)
		devCfg.XADCIF_MCTL := MCTL_RESET_MASK;
		devCfg.XADCIF_MCTL := 0;
	END Reset;

	(* read from an XADC register *)
	PROCEDURE ReadReg(regOffset: ADDRESS): SIGNED32;
	VAR d: SIGNED32;
	BEGIN
		devCfg.XADCIF_CMDFIFO := JTAG_CMD_READ_MASK + SYSTEM.MSK(LSH(regOffset,JTAG_ADDR_SHIFT),JTAG_ADDR_MASK);
		d := devCfg.XADCIF_RDFIFO; (* do a dummy read *)
		devCfg.XADCIF_CMDFIFO := d; (* do a dummy write to get the actual read *)
		d := devCfg.XADCIF_RDFIFO; (* do the actual read *)
		RETURN d;
	END ReadReg;

	(* write to an XADC register *)
	PROCEDURE WriteReg(regOffset: ADDRESS; regValue: SIGNED32);
	BEGIN
		devCfg.XADCIF_CMDFIFO := JTAG_CMD_WRITE_MASK + SYSTEM.MSK(LSH(regOffset,JTAG_ADDR_SHIFT),JTAG_ADDR_MASK) + SYSTEM.MSK(regValue,JTAG_DATA_MASK);
		(* read the read FIFO after any write since for each write one location of read FIFO gets updated *)
		regValue := devCfg.XADCIF_RDFIFO;
	END WriteReg;

	(**
		Setup ADC channel sequencer mode
	*)
	PROCEDURE SetSequencerMode*(mode: SIGNED32);
	VAR d: SIGNED32;
	BEGIN
		ASSERT(((mode >= SeqDefault) & (mode <= SeqSimultaneous)) OR (mode = SeqIndependent));
		IF ~initialized THEN Initialize; END;
		d := ReadReg(CFR1_REG);
		d := SYSTEM.MSK(d,-CFR1_SEQ_VALID_MASK-1);
		d := d + SYSTEM.MSK(LSH(mode,CFR1_SEQ_SHIFT),CFR1_SEQ_VALID_MASK);
		WriteReg(CFR1_REG,d);
	END SetSequencerMode;

	(**
		Get ADC channel sequencer mode
	*)
	PROCEDURE GetSequencerMode*(): SIGNED32;
	BEGIN
		IF ~initialized THEN Initialize; END;
		RETURN LSH(SYSTEM.MSK(ReadReg(CFR1_REG),CFR1_SEQ_VALID_MASK),-CFR1_SEQ_SHIFT);
	END GetSequencerMode;

	PROCEDURE GetAdcData*(channel: SIGNED32): SIGNED32;
	BEGIN
		ASSERT(((channel >= ChTemp) & (channel <= ChGainErrCalib)) OR ((channel >= ChVccpInt) & (channel <= ChAux15)));
		IF ~initialized THEN Initialize; END;
		RETURN ReadReg(TEMP_REG+channel);
	END GetAdcData;

	(**
		Convert raw ADC value to temperature in centigrades
	*)
	PROCEDURE RawToTemperature*(raw: SIGNED32): FLOAT32;
	BEGIN
		RETURN FLOAT32(raw)*(1.0/(65536.0*0.00198421639)) - 273.15;
	END RawToTemperature;

	(**
		Convert raw ADC value to voltage in volts
	*)
	PROCEDURE RawToVoltage*(raw: SIGNED32): FLOAT32;
	BEGIN
		RETURN FLOAT32(raw) * (3.0/65536.0);
	END RawToVoltage;

BEGIN
	devCfg := Platform.devcfg;
END PsXAdc.

