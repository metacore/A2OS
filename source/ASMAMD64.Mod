MODULE ASMAMD64; (** AUTHOR "negelef"; PURPOSE "AMD64 instruction set repository "; *)

CONST
	maxMnemonicNameLength = 12;

	maxMnemonics = 600;
	maxInstructions = 1400;
	maxRegisters = 150;
	maxCPUs = 30;

	maxOperands* = 3;

	none* = -1;

	(* cpu options *)
	cpu8086* = 0;
	cpu186* = 1;
	cpu286* = 2;
	cpu386* = 3;
	cpu486* = 4;
	cpuPentium* = 5;
	cpuP6* = 6;
	cpuKatmai* = 7;
	cpuWillamette* = 8;
	cpuPrescott* = 9;
	cpuAMD64* = 10;

	(* options selectable with CODE {SYSTEM.....} *)
	cpuPrivileged* = 20;
	cpuProtected* = 21;
	cpuSSE* = 22;
	cpuSSE2* = 23;
	cpuSSE3* = 24;
	cpu3DNow* = 25;
	cpuMMX* = 26;
	cpuFPU* = 27;

	cpuOptions* = {cpuPrivileged .. cpuFPU};

	(* instruction options *)
	optO16* = 0;	(* default 16bit operand size *)
	optO32* = 1;	(* default 32bit operand size *)
	optO64* = 2;	(* default 64bit operand size *)
	optD64* = 3;	(* default 64bit operand size in 64bit mode *)
	optI64* = 4;		(* instruction invalid in 64bit mode *)
	optA16* = 5;	(* default 16bit address size *)
	optA32* = 6;	(* default 32bit address size *)

	optPOP* = 7;		(* an operand size override prefix must preceed the instruction *)
	optPLOCK* = 8;		(* a lock prefix must preceed the instruction *)
	optPREP* = 9;		(* a repeat prefix must preceed the instruction *)
	optPREPN* = 10;	(* a repeat prefix must preceed the instruction *)

	(* operand types *)
	AL* = 0;
	AX* = 1;
	CL* = 2;
	CR8* = 3;
	CRn* = 4;
	CS* = 5;
	DRn* = 6;
	DS* = 7;
	DX* = 8;
	EAX* = 9;
	ECX* = 10;
	ES* = 11;
	FS* = 12;
	GS* = 13;
	RAX* = 14;
	SS* = 15;
	imm16* = 16;
	imm32* = 17;
	imm64* = 18;
	imm8* = 19;
	mem* = 20;
	mem128* = 21;
	mem16* = 22;
	mem32* = 23;
	mem64* = 24;
	mem8* = 25;
	mmx* = 26;
	mmxmem32* = 27;
	mmxmem64* = 28;
	moffset16* = 29;
	moffset32* = 30;
	moffset64* = 31;
	moffset8* = 32;
	one* = 33;
	pntr1616* = 34;
	pntr1632* = 35;
	rAX* = 36;
	reg16* = 37;
	reg32* = 38;
	reg64* = 39;
	reg8* = 40;
	regmem16* = 41;
	regmem32* = 42;
	regmem64* = 43;
	regmem8* = 44;
	rel16off* = 45;
	rel32off* = 46;
	rel8off* = 47;
	segReg* = 48;
	simm16* = 49;
	simm32* = 50;
	simm8* = 51;
	st0* = 52;
	sti* = 53;
	three* = 54;
	uimm16* = 55;
	uimm32* = 56;
	uimm8* = 57;
	xmm* = 58;
	xmmmem128* = 59;
	xmmmem32* = 60;
	xmmmem64* = 61;

	(* prefixes *)
	prfOP* = 066H;
	prfADR* = 067H;
	prfCS* = 02EH;		(* ignored in 64bit mode *)
	prfDS* = 03EH;		(* ignored in 64bit mode *)
	prfES* = 026H;		(* ignored in 64bit mode *)
	prfFS* = 064H;
	prfGS* = 065H;
	prfSS* = 036H;		(* ignored in 64bit mode *)
	prfLOCK* = 0F0H;
	prfREP* = 0F3H;
	prfREPE* = 0F3H;
	prfREPZ* = 0F3H;
	prfREPNE* = 0F2H;
	prfREPNZ* = 0F2H;

	(* AMD64 instruction set, only constants actually needed are exported to save space *)
	opAAA = 0;
	opAAD = 1;
	opAAM = 2;
	opAAS = 3;
	opADC = 4;
	opADD* = 5;
	opADDPD = 6;
	opADDPS = 7;
	opADDSD* = 8;
	opADDSS* = 9;
	opADDSUBPD = 10;
	opADDSUBPS = 11;
	opAND* = 12;
	opANDNPD = 13;
	opANDNPS = 14;
	opANDPD* = 15;
	opANDPS* = 16;
	opARPL = 17;
	opBOUND = 18;
	opBSF = 19;
	opBSR = 20;
	opBSWAP = 21;
	opBT* = 22;
	opBTC = 23;
	opBTR* = 24;
	opBTS* = 25;
	opCALL* = 26;
	opCBW* = 27;
	opCDQ* = 28;
	opCDQE = 29;
	opCFLUSH = 30;
	opCLC = 31;
	opCLD* = 32;
	opCLGI = 33;
	opCLI = 34;
	opCLTS = 35;
	opCMC = 36;
	opCMOVA = 37;
	opCMOVAE = 38;
	opCMOVB = 39;
	opCMOVBE = 40;
	opCMOVC = 41;
	opCMOVE = 42;
	opCMOVG = 43;
	opCMOVGE = 44;
	opCMOVL = 45;
	opCMOVLE = 46;
	opCMOVNA = 47;
	opCMOVNAE = 48;
	opCMOVNB = 49;
	opCMOVNBE = 50;
	opCMOVNC = 51;
	opCMOVNE = 52;
	opCMOVNG = 53;
	opCMOVNGE = 54;
	opCMOVNL = 55;
	opCMOVNLE = 56;
	opCMOVNO = 57;
	opCMOVNP = 58;
	opCMOVNS = 59;
	opCMOVNZ = 60;
	opCMOVO = 61;
	opCMOVP = 62;
	opCMOVPE = 63;
	opCMOVPO = 64;
	opCMOVS = 65;
	opCMOVZ = 66;
	opCMP* = 67;
	opCMPPD = 68;
	opCMPPS = 69;
	opCMPS = 70;
	opCMPSB = 71;
	opCMPSD = 72;
	opCMPSQ = 73;
	opCMPSS = 74;
	opCMPSW = 75;
	opCMPXCHG = 76;
	opCMPXCHG16B = 77;
	opCMPXCHG8B = 78;
	opCOMISD* = 79;
	opCOMISS* = 80;
	opCPUID = 81;
	opCQO* = 82;
	opCVTDQ2PD = 83;
	opCVTDQ2PS = 84;
	opCVTPD2DQ = 85;
	opCVTPD2PI = 86;
	opCVTPD2PS = 87;
	opCVTPI2PD = 88;
	opCVTPI2PS = 89;
	opCVTPS2DQ = 90;
	opCVTPS2PD = 91;
	opCVTPS2PI = 92;
	opCVTSD2SI* = 93;
	opCVTSD2SS* = 94;
	opCVTSI2SD* = 95;
	opCVTSI2SS* = 96;
	opCVTSS2SD* = 97;
	opCVTSS2SI* = 98;
	opCVTTPD2DQ = 99;
	opCVTTPD2PI = 100;
	opCVTTPS2DQ = 101;
	opCVTTPS2PI = 102;
	opCVTTSD2SI = 103;
	opCVTTSS2SI = 104;
	opCWD* = 105;
	opCWDE = 106;
	opDAA = 107;
	opDAS = 108;
	opDEC* = 109;
	opDIV = 110;
	opDIVPD = 111;
	opDIVPS = 112;
	opDIVSD* = 113;
	opDIVSS* = 114;
	opEMMS = 115;
	opENTER* = 116;
	opF2XM1 = 117;
	opFABS = 118;
	opFADD = 119;
	opFADDP = 120;
	opFBLD = 121;
	opFBSTP = 122;
	opFCHS = 123;
	opFCLEX = 124;
	opFCMOVB = 125;
	opFCMOVBE = 126;
	opFCMOVE = 127;
	opFCMOVNB = 128;
	opFCMOVNBE = 129;
	opFCMOVNE = 130;
	opFCMOVNU = 131;
	opFCMOVU = 132;
	opFCOM = 133;
	opFCOMI = 134;
	opFCOMIP = 135;
	opFCOMP = 136;
	opFCOMPP = 137;
	opFCOS = 138;
	opFDECSTP = 139;
	opFDIV = 140;
	opFDIVP = 141;
	opFDIVR = 142;
	opFDIVRP = 143;
	opFEMMS = 144;
	opFFREE = 145;
	opFIADD = 146;
	opFICOM = 147;
	opFICOMP = 148;
	opFIDIV = 149;
	opFIDIVR = 150;
	opFILD = 151;
	opFIMUL = 152;
	opFINCSTP = 153;
	opFINIT = 154;
	opFIST = 155;
	opFISTP = 156;
	opFISTTP = 157;
	opFISUB = 158;
	opFISUBR = 159;
	opFLD = 160;
	opFLD1 = 161;
	opFLDCW = 162;
	opFLDENV = 163;
	opFLDL2E = 164;
	opFLDL2T = 165;
	opFLDLG2 = 166;
	opFLDLN2 = 167;
	opFLDPI = 168;
	opFLDZ = 169;
	opFMUL = 170;
	opFMULP = 171;
	opFNCLEX = 172;
	opFNINIT = 173;
	opFNOP = 174;
	opFNSAVE = 175;
	opFNSTCW = 176;
	opFNSTENV = 177;
	opFNSTSW = 178;
	opFPATAN = 179;
	opFPREM = 180;
	opFPREM1 = 181;
	opFPTAN = 182;
	opFRNDINT = 183;
	opFRSTOR = 184;
	opFSAVE = 185;
	opFSCALE = 186;
	opFSIN = 187;
	opFSINCOS = 188;
	opFSQRT = 189;
	opFST = 190;
	opFSTCW = 191;
	opFSTENV = 192;
	opFSTP = 193;
	opFSTSW = 194;
	opFSUB = 195;
	opFSUBP = 196;
	opFSUBR = 197;
	opFSUBRP = 198;
	opFTST = 199;
	opFUCOM = 200;
	opFUCOMI = 201;
	opFUCOMIP = 202;
	opFUCOMP = 203;
	opFUCOMPP = 204;
	opFWAIT = 205;
	opFXAM = 206;
	opFXCH = 207;
	opFXRSTOR = 208;
	opFXSAVE = 209;
	opFXTRACT = 210;
	opFYL2X = 211;
	opFYL2XP1 = 212;
	opHADDPD = 213;
	opHADDPS = 214;
	opHLT = 215;
	opHSUBPD = 216;
	opHSUBPS = 217;
	opIDIV* = 218;
	opIMUL* = 219;
	opIN* = 220;
	opINC* = 221;
	opINS = 222;
	opINSB = 223;
	opINSD = 224;
	opINSW = 225;
	opINT* = 226;
	opINT3* = 227;
	opINTO = 228;
	opINVD = 229;
	opINVLPG = 230;
	opINVLPGA = 231;
	opIRET = 232;
	opIRETD = 233;
	opIRETQ = 234;
	opJA* = 235;
	opJAE* = 236;
	opJB* = 237;
	opJBE* = 238;
	opJC* = 239;
	opJCXZ = 240;
	opJE* = 241;
	opJECXZ = 242;
	opJG* = 243;
	opJGE* = 244;
	opJL* = 245;
	opJLE* = 246;
	opJMP* = 247;
	opJNA = 248;
	opJNAE = 249;
	opJNB = 250;
	opJNBE = 251;
	opJNC* = 252;
	opJNE* = 253;
	opJNG = 254;
	opJNGE = 255;
	opJNL = 256;
	opJNLE = 257;
	opJNO = 258;
	opJNP = 259;
	opJNS = 260;
	opJNZ* = 261;
	opJO = 262;
	opJP = 263;
	opJPE = 264;
	opJPO = 265;
	opJRCXZ = 266;
	opJS = 267;
	opJZ = 268;
	opLAHF = 269;
	opLAR = 270;
	opLDDQU = 271;
	opLDMXCSR = 272;
	opLDS = 273;
	opLEA = 274;
	opLEAVE* = 275;
	opLES = 276;
	opLFENCE = 277;
	opLFS = 278;
	opLGDT = 279;
	opLGS = 280;
	opLIDT = 281;
	opLLDT = 282;
	opLMSW = 283;
	opLODS = 284;
	opLODSB = 285;
	opLODSD = 286;
	opLODSQ = 287;
	opLODSW = 288;
	opLOOP = 289;
	opLOOPE = 290;
	opLOOPNE = 291;
	opLOOPNZ = 292;
	opLOOPZ = 293;
	opLSL = 294;
	opLSS = 295;
	opLTR = 296;
	opMASKMOVDQU = 297;
	opMASKMOVQ = 298;
	opMAXPD = 299;
	opMAXPS = 300;
	opMAXSD = 301;
	opMAXSS = 302;
	opMFENCE = 303;
	opMINPD = 304;
	opMINPS = 305;
	opMINSD = 306;
	opMINSS = 307;
	opMOV* = 308;
	opMOVAPD = 309;
	opMOVAPS = 310;
	opMOVD* = 311;
	opMOVDDUP = 312;
	opMOVDQ2Q = 313;
	opMOVDQA = 314;
	opMOVDQU = 315;
	opMOVHLPS = 316;
	opMOVHPD = 317;
	opMOVHPS = 318;
	opMOVLHPS = 319;
	opMOVLPD = 320;
	opMOVLPS = 321;
	opMOVMSKPD = 322;
	opMOVMSKPS = 323;
	opMOVNTDQ = 324;
	opMOVNTI = 325;
	opMOVNTPD = 326;
	opMOVNTPS = 327;
	opMOVNTQ = 328;
	opMOVQ = 329;
	opMOVQ2DQ = 330;
	opMOVS = 331;
	opMOVSB* = 332;
	opMOVSD* = 333;
	opMOVSHDUP = 334;
	opMOVSLDUP = 335;
	opMOVSQ = 336;
	opMOVSS* = 337;
	opMOVSW = 338;
	opMOVSX* = 339;
	opMOVSXD* = 340;
	opMOVUPD = 341;
	opMOVUPS = 342;
	opMOVZX* = 343;
	opMUL* = 344;
	opMULPD = 345;
	opMULPS = 346;
	opMULSD* = 347;
	opMULSS* = 348;
	opNEG* = 349;
	opNOP* = 350;
	opNOT* = 351;
	opOR* = 352;
	opORPD = 353;
	opORPS = 354;
	opOUT* = 355;
	opOUTS = 356;
	opOUTSB = 357;
	opOUTSD = 358;
	opOUTSW = 359;
	opPACKSSDW = 360;
	opPACKSSWB = 361;
	opPACKUSWB = 362;
	opPADDB = 363;
	opPADDD = 364;
	opPADDQ = 365;
	opPADDSB = 366;
	opPADDSW = 367;
	opPADDUSB = 368;
	opPADDUSW = 369;
	opPADDW = 370;
	opPAND = 371;
	opPANDN = 372;
	opPAUSE = 373;
	opPAVGB = 374;
	opPAVGUSB = 375;
	opPAVGW = 376;
	opPCMPEQB = 377;
	opPCMPEQD = 378;
	opPCMPEQW = 379;
	opPCMPGTB = 380;
	opPCMPGTD = 381;
	opPCMPGTW = 382;
	opPEXTRW = 383;
	opPF2ID = 384;
	opPF2IW = 385;
	opPFACC = 386;
	opPFADD = 387;
	opPFCMPEQ = 388;
	opPFCMPGE = 389;
	opPFCMPGT = 390;
	opPFMAX = 391;
	opPFMIN = 392;
	opPFMUL = 393;
	opPFNACC = 394;
	opPFPNACC = 395;
	opPFRCP = 396;
	opPFRCPIT1 = 397;
	opPFRCPIT2 = 398;
	opPFRSQIT1 = 399;
	opPFRSQRT = 400;
	opPFSUB = 401;
	opPFSUBR = 402;
	opPI2FD = 403;
	opPI2FW = 404;
	opPINSRW = 405;
	opPMADDWD = 406;
	opPMAXSW = 407;
	opPMAXUB = 408;
	opPMINSW = 409;
	opPMINUB = 410;
	opPMOVMSKB = 411;
	opPMULHRW = 412;
	opPMULHUW = 413;
	opPMULHW = 414;
	opPMULLW = 415;
	opPMULUDQ = 416;
	opPOP* = 417;
	opPOPA = 418;
	opPOPAD = 419;
	opPOPAW = 420;
	opPOPF = 421;
	opPOPFD = 422;
	opPOPFQ = 423;
	opPOPFW = 424;
	opPOR = 425;
	opPREFETCH = 426;
	opPREFETCHNTA = 427;
	opPREFETCHT0 = 428;
	opPREFETCHT1 = 429;
	opPREFETCHT2 = 430;
	opPREFETCHW = 431;
	opPSADBW = 432;
	opPSHUFD = 433;
	opPSHUFHW = 434;
	opPSHUFLW = 435;
	opPSHUFW = 436;
	opPSLLD = 437;
	opPSLLDQ = 438;
	opPSLLQ = 439;
	opPSLLW = 440;
	opPSRAD = 441;
	opPSRAW = 442;
	opPSRLD = 443;
	opPSRLDQ = 444;
	opPSRLQ = 445;
	opPSRLW = 446;
	opPSUBB = 447;
	opPSUBD = 448;
	opPSUBQ = 449;
	opPSUBSB = 450;
	opPSUBSW = 451;
	opPSUBUSB = 452;
	opPSUBUSW = 453;
	opPSUBW = 454;
	opPSWAPD = 455;
	opPUNPCKHBW = 456;
	opPUNPCKHDQ = 457;
	opPUNPCKHQDQ = 458;
	opPUNPCKHWD = 459;
	opPUNPCKLBW = 460;
	opPUNPCKLDQ = 461;
	opPUNPCKLQDQ = 462;
	opPUNPCKLWD = 463;
	opPUSH* = 464;
	opPUSHA = 465;
	opPUSHAD = 466;
	opPUSHF = 467;
	opPUSHFD = 468;
	opPUSHFQ = 469;
	opPUSHFW = 470;
	opPXOR = 471;
	opRCL = 472;
	opRCPPS = 473;
	opRCPSS = 474;
	opRCR = 475;
	opRDMSR = 476;
	opRDPMC = 477;
	opRDTSC = 478;
	opRDTSCP = 479;
	opRET* = 480;
	opRETF = 481;
	opROL* = 482;
	opROR* = 483;
	opRSM = 484;
	opRSQRTPS = 485;
	opRSQRTSS = 486;
	opSAHF = 487;
	opSAL* = 488;
	opSAR* = 489;
	opSBB* = 490;
	opSCAS = 491;
	opSCASB = 492;
	opSCASD = 493;
	opSCASQ = 494;
	opSCASW = 495;
	opSETA* = 496;
	opSETAE* = 497;
	opSETB* = 498;
	opSETBE* = 499;
	opSETC* = 500;
	opSETE* = 501;
	opSETG* = 502;
	opSETGE* = 503;
	opSETL* = 504;
	opSETLE* = 505;
	opSETNA = 506;
	opSETNAE = 507;
	opSETNB = 508;
	opSETNBE = 509;
	opSETNC* = 510;
	opSETNE* = 511;
	opSETNG = 512;
	opSETNGE = 513;
	opSETNL = 514;
	opSETNLE = 515;
	opSETNO = 516;
	opSETNP = 517;
	opSETNS = 518;
	opSETNZ = 519;
	opSETO = 520;
	opSETP = 521;
	opSETPE = 522;
	opSETPO = 523;
	opSETS = 524;
	opSETZ = 525;
	opSFENCE = 526;
	opSGDT = 527;
	opSHL* = 528;
	opSHLD = 529;
	opSHR* = 530;
	opSHRD = 531;
	opSHUFPD = 532;
	opSHUFPS = 533;
	opSIDT = 534;
	opSKINIT = 535;
	opSLDT = 536;
	opSMSW = 537;
	opSQRTPD = 538;
	opSQRTPS = 539;
	opSQRTSD = 540;
	opSQRTSS = 541;
	opSTC = 542;
	opSTD* = 543;
	opSTGI = 544;
	opSTI = 545;
	opSTMXCSR = 546;
	opSTOS = 547;
	opSTOSB = 548;
	opSTOSD = 549;
	opSTOSQ = 550;
	opSTOSW = 551;
	opSTR = 552;
	opSUB* = 553;
	opSUBPD = 554;
	opSUBPS = 555;
	opSUBSD* = 556;
	opSUBSS* = 557;
	opSWAPGS = 558;
	opSYSCALL = 559;
	opSYSENTER = 560;
	opSYSEXIT = 561;
	opSYSRET = 562;
	opTEST = 563;
	opUCOMISD = 564;
	opUCOMISS = 565;
	opUD2 = 566;
	opUNPCKHPD = 567;
	opUNPCKHPS = 568;
	opUNPCKLPD = 569;
	opUNPCKLPS = 570;
	opVERR = 571;
	opVERW = 572;
	opVMLOAD = 573;
	opVMMCALL = 574;
	opVMRUN = 575;
	opVMSAVE = 576;
	opWBINVD = 577;
	opWRMSR = 578;
	opXADD = 579;
	opXCHG = 580;
	opXLAT = 581;
	opXLATB = 582;
	opXOR* = 583;
	opXORPD* = 584;
	opXORPS* = 585;

TYPE
	Name = ARRAY 20 OF CHAR;

	OperandType* = LONGINT;

	CPUOptions* = SET;

	Instruction = RECORD
		cpuoptions-: CPUOptions;	(* necessary CPU options for the instruction to be available *)
		options-: SET;	(* options for the instruction *)
		opcode-: ARRAY 9 OF CHAR;
		operands-: ARRAY maxOperands OF OperandType;
		opCount-: LONGINT;
	END;

	Mnemonic = RECORD
		name-: ARRAY maxMnemonicNameLength OF CHAR;
		firstInstr-, lastInstr-: LONGINT;
	END;

	CPUType = RECORD;
		name-: Name;
		cpuoptions-: CPUOptions;
	END;

	Register = RECORD;
		name-: Name;
		type-: OperandType;
		index-: LONGINT;
	END;

VAR
	(* repository *)
	mnemonics-: ARRAY maxMnemonics OF Mnemonic;
	mnemCount: LONGINT;

	instructions-: ARRAY maxInstructions OF Instruction;
	instrCount: LONGINT;

	registers-: ARRAY maxRegisters OF Register;
	regCount: LONGINT;

	cpus-: ARRAY maxCPUs OF CPUType;
	cpuCount: LONGINT;

(* perform a binary search for the index of the specified mnemonic *)
PROCEDURE FindMnem* (CONST mnem: ARRAY OF CHAR): LONGINT;
VAR l, r, m: LONGINT;
BEGIN
	l := 0;
	r := mnemCount;
	WHILE l # r DO
		m := (l + r) DIV 2;
		IF mnem < mnemonics[m].name THEN r := m;
		ELSIF mnem > mnemonics[m].name THEN l := m + 1;
		ELSE RETURN m;
		END
	END;
	RETURN none;
END FindMnem;

(* search for the register name and return it's index *)
PROCEDURE FindReg* (CONST reg: ARRAY OF CHAR): LONGINT;
VAR i: LONGINT;
BEGIN
	FOR i := 0 TO regCount - 1 DO
		IF registers[i].name = reg THEN RETURN i END;
	END;
	RETURN none;
END FindReg;

(* search for the register name and return it's index *)
PROCEDURE FindCPU* (CONST cpu: ARRAY OF CHAR): LONGINT;
VAR i: LONGINT;
BEGIN
	FOR i := 0 TO cpuCount - 1 DO
		IF cpus[i].name = cpu THEN RETURN i END;
	END;
	RETURN none;
END FindCPU;

(* insert a new mnemonic *)
PROCEDURE Mnem (CONST name: ARRAY OF CHAR);
BEGIN
	COPY (name, mnemonics[mnemCount].name);
	mnemonics[mnemCount].firstInstr := instrCount;
	INC (mnemCount);
END Mnem;

(* insert an new instruction *)
PROCEDURE Instr (op1, op2, op3: OperandType; CONST opcode: ARRAY OF CHAR; options: SET; cpuoptions: CPUOptions);
BEGIN
	instructions[instrCount].operands[0] := op1;
	instructions[instrCount].operands[1] := op2;
	instructions[instrCount].operands[2] := op3;
	COPY (opcode, instructions[instrCount].opcode);
	instructions[instrCount].options := options;
	instructions[instrCount].cpuoptions := cpuoptions;

	IF op1 = none THEN
		instructions[instrCount].opCount := 0;
	ELSIF op2 = none THEN
		instructions[instrCount].opCount := 1;
	ELSIF op3 = none THEN
		instructions[instrCount].opCount := 2;
	ELSE
		instructions[instrCount].opCount := 3;
	END;

	INC (instrCount);
	mnemonics[mnemCount - 1].lastInstr := instrCount;
END Instr;

(* insert an new register *)
PROCEDURE Reg (CONST name: ARRAY OF CHAR; type: OperandType; index: LONGINT);
BEGIN
	COPY (name, registers[regCount].name);
	registers[regCount].type := type;
	registers[regCount].index := index;
	INC (regCount);
END Reg;

(* insert a new cpu type *)
PROCEDURE Cpu (CONST name: ARRAY OF CHAR; cpuoptions: SET);
BEGIN
	COPY (name, cpus[cpuCount].name);
	cpus[cpuCount].cpuoptions := cpuoptions;
	INC (cpuCount);
END Cpu;

(* initialize the AMD64 instruction & register set  *)
BEGIN
	mnemCount := 0; instrCount := 0;
	regCount := 0; cpuCount := 0;

	(* AMD64 instruction reference opcode snytax:
		two hex digits: A hexadecimal byte
		/digit: The ModRM byte specified only one register or memory operand
		/r: The ModRM byte specifies both a register operand and a register or memory operand
		+i: Specifies an x87 floating-point stack operand
		+o: A direct memory offset
		cb, cd, cw: Specifies a code-offset value and possibly a new code-segment register value
		ib, iw, id, iq: Specifies an immediate-operand value
		rb, rw, rd, rq: Specifies a register value that is added to the hexadecimal byte on the left
	*)

	Mnem ("AAA");	(* 0 *)
	Instr (none, none, none, "37", {optI64}, {cpu8086});	(* 0 *)

	Mnem ("AAD");	(* 1 *)
	Instr (none, none, none, "D50A", {optI64}, {cpu8086});	(* 1 *)
	Instr (simm8, none, none, "D5ib", {optI64}, {cpu8086});	(* 2 *)

	Mnem ("AAM");	(* 2 *)
	Instr (none, none, none, "D40A", {optI64}, {cpu8086});	(* 3 *)
	Instr (simm8, none, none, "D4ib", {optI64}, {cpu8086});	(* 4 *)

	Mnem ("AAS");	(* 3 *)
	Instr (none, none, none, "3F", {optI64}, {cpu8086});	(* 5 *)

	Mnem ("ADC");	(* 4 *)
	Instr (AL, imm8, none, "14ib", {}, {cpu8086});	(* 6 *)
	Instr (AX, imm16, none, "15iw", {optO16}, {cpu8086});	(* 7 *)
	Instr (EAX, imm32, none, "15id", {optO32}, {cpu386});	(* 8 *)
	Instr (RAX, imm32, none, "15id", {}, {cpuAMD64});	(* 9 *)
	Instr (regmem8, reg8, none, "10/r", {}, {cpu8086});	(* 10 *)
	Instr (regmem16, reg16, none, "11/r", {optO16}, {cpu8086});	(* 11 *)
	Instr (regmem32, reg32, none, "11/r", {optO32}, {cpu386});	(* 12 *)
	Instr (regmem64, reg64, none, "11/r", {}, {cpuAMD64});	(* 13 *)
	Instr (reg8, regmem8, none, "12/r", {}, {cpu8086});	(* 14 *)
	Instr (reg16, regmem16, none, "13/r", {optO16}, {cpu8086});	(* 15 *)
	Instr (reg32, regmem32, none, "13/r", {optO32}, {cpu386});	(* 16 *)
	Instr (reg64, regmem64, none, "13/r", {}, {cpuAMD64});	(* 17 *)
	Instr (regmem8, imm8, none, "80/2ib", {}, {cpu8086});	(* 18 *)
	Instr (regmem16, simm8, none, "83/2ib", {optO16}, {cpu8086});	(* 19 *)
	Instr (regmem16, imm16, none, "81/2iw", {optO16}, {cpu8086});	(* 20 *)
	Instr (regmem32, simm8, none, "83/2ib", {optO32}, {cpu386});	(* 21 *)
	Instr (regmem32, imm32, none, "81/2id", {optO32}, {cpu386});	(* 22 *)
	Instr (regmem64, simm8, none, "83/2ib", {}, {cpuAMD64});	(* 23 *)
	Instr (regmem64, imm32, none, "81/2id", {}, {cpuAMD64});	(* 24 *)

	Mnem ("ADD");	(* 5 *)
	Instr (AL, imm8, none, "04ib", {}, {cpu8086});	(* 25 *)
	Instr (AX, imm16, none, "05iw", {optO16}, {cpu8086});	(* 26 *)
	Instr (EAX, imm32, none, "05id", {optO32}, {cpu386});	(* 27 *)
	Instr (RAX, imm32, none, "05id", {}, {cpuAMD64});	(* 28 *)
	Instr (regmem8, reg8, none, "00/r", {}, {cpu8086});	(* 29 *)
	Instr (regmem16, reg16, none, "01/r", {optO16}, {cpu8086});	(* 30 *)
	Instr (regmem32, reg32, none, "01/r", {optO32}, {cpu386});	(* 31 *)
	Instr (regmem64, reg64, none, "01/r", {}, {cpuAMD64});	(* 32 *)
	Instr (reg8, regmem8, none, "02/r", {}, {cpu8086});	(* 33 *)
	Instr (reg16, regmem16, none, "03/r", {optO16}, {cpu8086});	(* 34 *)
	Instr (reg32, regmem32, none, "03/r", {optO32}, {cpu386});	(* 35 *)
	Instr (reg64, regmem64, none, "03/r", {}, {cpuAMD64});	(* 36 *)
	Instr (regmem8, imm8, none, "80/0ib", {}, {cpu8086});	(* 37 *)
	Instr (regmem16, simm8, none, "83/0ib", {optO16}, {cpu8086});	(* 38 *)
	Instr (regmem16, imm16, none, "81/0iw", {optO16}, {cpu8086});	(* 39 *)
	Instr (regmem32, simm8, none, "83/0ib", {optO32}, {cpu386});	(* 40 *)
	Instr (regmem32, imm32, none, "81/0id", {optO32}, {cpu386});	(* 41 *)
	Instr (regmem64, simm8, none, "83/0ib", {}, {cpuAMD64});	(* 42 *)
	Instr (regmem64, imm32, none, "81/0id", {}, {cpuAMD64});	(* 43 *)

	Mnem ("ADDPD");	(* 6 *)
	Instr (xmm, xmmmem128, none, "0F58/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 44 *)

	Mnem ("ADDPS");	(* 7 *)
	Instr (xmm, xmmmem128, none, "0F58/r", {}, {cpuKatmai, cpuSSE});	(* 45 *)

	Mnem ("ADDSD");	(* 8 *)
	Instr (xmm, xmmmem64, none, "0F58/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 46 *)

	Mnem ("ADDSS");	(* 9 *)
	Instr (xmm, xmmmem32, none, "0F58/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 47 *)

	Mnem ("ADDSUBPD");	(* 10 *)
	Instr (xmm, xmmmem128, none, "0FD0/r", {optPOP}, {cpuPrescott, cpuSSE3});	(* 48 *)

	Mnem ("ADDSUBPS");	(* 11 *)
	Instr (xmm, xmmmem128, none, "0FD0/r", {optPREPN}, {cpuPrescott, cpuSSE3});	(* 49 *)

	Mnem ("AND");	(* 12 *)
	Instr (AL, imm8, none, "24ib", {}, {cpu8086});	(* 50 *)
	Instr (AX, imm16, none, "25iw", {optO16}, {cpu8086});	(* 51 *)
	Instr (EAX, imm32, none, "25id", {optO32}, {cpu386});	(* 52 *)
	Instr (RAX, imm32, none, "25id", {}, {cpuAMD64});	(* 53 *)
	Instr (regmem8, reg8, none, "20/r", {}, {cpu8086});	(* 54 *)
	Instr (regmem16, reg16, none, "21/r", {optO16}, {cpu8086});	(* 55 *)
	Instr (regmem32, reg32, none, "21/r", {optO32}, {cpu386});	(* 56 *)
	Instr (regmem64, reg64, none, "21/r", {}, {cpuAMD64});	(* 57 *)
	Instr (reg8, regmem8, none, "22/r", {}, {cpu8086});	(* 58 *)
	Instr (reg16, regmem16, none, "23/r", {optO16}, {cpu8086});	(* 59 *)
	Instr (reg32, regmem32, none, "23/r", {optO32}, {cpu386});	(* 60 *)
	Instr (reg64, regmem64, none, "23/r", {}, {cpuAMD64});	(* 61 *)
	Instr (regmem8, imm8, none, "80/4ib", {}, {cpu8086});	(* 62 *)
	Instr (regmem16, simm8, none, "83/4ib", {optO16}, {cpu8086});	(* 63 *)
	Instr (regmem16, imm16, none, "81/4iw", {optO16}, {cpu8086});	(* 64 *)
	Instr (regmem32, simm8, none, "83/4ib", {optO32}, {cpu386});	(* 65 *)
	Instr (regmem32, imm32, none, "81/4id", {optO32}, {cpu386});	(* 66 *)
	Instr (regmem64, simm8, none, "83/4ib", {}, {cpuAMD64});	(* 67 *)
	Instr (regmem64, imm32, none, "81/4id", {}, {cpuAMD64});	(* 68 *)

	Mnem ("ANDNPD");	(* 13 *)
	Instr (xmm, xmmmem128, none, "0F55/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 69 *)

	Mnem ("ANDNPS");	(* 14 *)
	Instr (xmm, xmmmem128, none, "0F55/r", {}, {cpuKatmai, cpuSSE});	(* 70 *)

	Mnem ("ANDPD");	(* 15 *)
	Instr (xmm, xmmmem128, none, "0F54/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 71 *)

	Mnem ("ANDPS");	(* 16 *)
	Instr (xmm, xmmmem128, none, "0F54/r", {}, {cpuKatmai, cpuSSE});	(* 72 *)

	Mnem ("ARPL");	(* 17 *)
	Instr (regmem16, reg16, none, "63/r", {}, {cpu286, cpuPrivileged});	(* 73 *)

	Mnem ("BOUND");	(* 18 *)
	Instr (reg16, mem, none, "62/r", {optO16, optI64}, {cpu186});	(* 74 *)
	Instr (reg32, mem, none, "62/r", {optO32, optI64}, {cpu386});	(* 75 *)

	Mnem ("BSF");	(* 19 *)
	Instr (reg16, regmem16, none, "0FBC/r", {optO16}, {cpu386});	(* 76 *)
	Instr (reg32, regmem32, none, "0FBC/r", {optO32}, {cpu386});	(* 77 *)
	Instr (reg64, regmem64, none, "0FBC/r", {}, {cpuAMD64});	(* 78 *)

	Mnem ("BSR");	(* 20 *)
	Instr (reg16, regmem16, none, "0FBD/r", {optO16}, {cpu386});	(* 79 *)
	Instr (reg32, regmem32, none, "0FBD/r", {optO32}, {cpu386});	(* 80 *)
	Instr (reg64, regmem64, none, "0FBD/r", {}, {cpuAMD64});	(* 81 *)

	Mnem ("BSWAP");	(* 21 *)
	Instr (reg32, none, none, "0FC8rd", {optO32}, {cpu486});	(* 82 *)
	Instr (reg64, none, none, "0FC8rq", {}, {cpuAMD64});	(* 83 *)

	Mnem ("BT");	(* 22 *)
	Instr (regmem16, reg16, none, "0FA3/r", {optO16}, {cpu386});	(* 84 *)
	Instr (regmem32, reg32, none, "0FA3/r", {optO32}, {cpu386});	(* 85 *)
	Instr (regmem64, reg64, none, "0FA3/r", {}, {cpuAMD64});	(* 86 *)
	Instr (regmem16, uimm8, none, "0FBA/4ib", {optO16}, {cpu386});	(* 87 *)
	Instr (regmem32, uimm8, none, "0FBA/4ib", {optO32}, {cpu386});	(* 88 *)
	Instr (regmem64, uimm8, none, "0FBA/4ib", {}, {cpuAMD64});	(* 89 *)

	Mnem ("BTC");	(* 23 *)
	Instr (regmem16, reg16, none, "0FBB/r", {optO16}, {cpu386});	(* 90 *)
	Instr (regmem32, reg32, none, "0FBB/r", {optO32}, {cpu386});	(* 91 *)
	Instr (regmem64, reg64, none, "0FBB/r", {}, {cpuAMD64});	(* 92 *)
	Instr (regmem16, uimm8, none, "0FBA/7ib", {optO16}, {cpu386});	(* 93 *)
	Instr (regmem32, uimm8, none, "0FBA/7ib", {optO32}, {cpu386});	(* 94 *)
	Instr (regmem64, uimm8, none, "0FBA/7ib", {}, {cpuAMD64});	(* 95 *)

	Mnem ("BTR");	(* 24 *)
	Instr (regmem16, reg16, none, "0FB3/r", {optO16}, {cpu386});	(* 96 *)
	Instr (regmem32, reg32, none, "0FB3/r", {optO32}, {cpu386});	(* 97 *)
	Instr (regmem64, reg64, none, "0FB3/r", {}, {cpuAMD64});	(* 98 *)
	Instr (regmem16, uimm8, none, "0FBA/6ib", {optO16}, {cpu386});	(* 99 *)
	Instr (regmem32, uimm8, none, "0FBA/6ib", {optO32}, {cpu386});	(* 100 *)
	Instr (regmem64, uimm8, none, "0FBA/6ib", {}, {cpuAMD64});	(* 101 *)

	Mnem ("BTS");	(* 25 *)
	Instr (regmem16, reg16, none, "0FAB/r", {optO16}, {cpu386});	(* 102 *)
	Instr (regmem32, reg32, none, "0FAB/r", {optO32}, {cpu386});	(* 103 *)
	Instr (regmem64, reg64, none, "0FAB/r", {}, {cpuAMD64});	(* 104 *)
	Instr (regmem16, uimm8, none, "0FBA/5ib", {optO16}, {cpu386});	(* 105 *)
	Instr (regmem32, uimm8, none, "0FBA/5ib", {optO32}, {cpu386});	(* 106 *)
	Instr (regmem64, uimm8, none, "0FBA/5ib", {}, {cpuAMD64});	(* 107 *)

	Mnem ("CALL");	(* 26 *)
	Instr (rel16off, none, none, "E8cw", {}, {cpu8086});	(* 108 *)
	Instr (rel32off, none, none, "E8cd", {}, {cpu8086});	(* 109 *)
	Instr (regmem16, none, none, "FF/2", {optO16}, {cpu8086});	(* 110 *)
	Instr (regmem32, none, none, "FF/2", {optO32, optI64}, {cpu386});	(* 111 *)
	Instr (regmem64, none, none, "FF/2", {optD64}, {cpuAMD64});	(* 112 *)
	Instr (mem, none, none, "FF/3", {optO16, optI64}, {cpu8086});	(* 113 *)
	Instr (mem, none, none, "FF/3", {optO32, optI64}, {cpu386});	(* 114 *)
	Instr (pntr1616, none, none, "9Aiwiw", {optI64}, {cpu8086});	(* 115 *)
	Instr (pntr1632, none, none, "9Aidiw", {optI64}, {cpu386});	(* 116 *)

	Mnem ("CBW");	(* 27 *)
	Instr (none, none, none, "98", {optO16}, {cpu8086});	(* 117 *)

	Mnem ("CDQ");	(* 28 *)
	Instr (none, none, none, "99", {optO32}, {cpu386});	(* 118 *)

	Mnem ("CDQE");	(* 29 *)
	Instr (none, none, none, "98", {optO64}, {cpuAMD64});	(* 119 *)

	Mnem ("CFLUSH");	(* 30 *)
	Instr (mem8, none, none, "0FAE/7", {}, {cpuWillamette, cpuSSE2});	(* 120 *)

	Mnem ("CLC");	(* 31 *)
	Instr (none, none, none, "F8", {}, {cpu8086});	(* 121 *)

	Mnem ("CLD");	(* 32 *)
	Instr (none, none, none, "FC", {}, {cpu8086});	(* 122 *)

	Mnem ("CLGI");	(* 33 *)
	Instr (none, none, none, "0F01DD", {}, {cpuAMD64});	(* 123 *)

	Mnem ("CLI");	(* 34 *)
	Instr (none, none, none, "FA", {}, {cpu8086});	(* 124 *)

	Mnem ("CLTS");	(* 35 *)
	Instr (none, none, none, "0F06", {}, {cpu286, cpuPrivileged});	(* 125 *)

	Mnem ("CMC");	(* 36 *)
	Instr (none, none, none, "F5", {}, {cpu8086});	(* 126 *)

	Mnem ("CMOVA");	(* 37 *)
	Instr (reg16, regmem16, none, "0F47/r", {optO16}, {cpuP6});	(* 127 *)
	Instr (reg32, regmem32, none, "0F47/r", {optO32}, {cpuP6});	(* 128 *)
	Instr (reg64, regmem64, none, "0F47/r", {}, {cpuAMD64});	(* 129 *)

	Mnem ("CMOVAE");	(* 38 *)
	Instr (reg16, regmem16, none, "0F43/r", {optO16}, {cpuP6});	(* 130 *)
	Instr (reg32, regmem32, none, "0F43/r", {optO32}, {cpuP6});	(* 131 *)
	Instr (reg64, regmem64, none, "0F43/r", {}, {cpuAMD64});	(* 132 *)

	Mnem ("CMOVB");	(* 39 *)
	Instr (reg16, regmem16, none, "0F42/r", {optO16}, {cpuP6});	(* 133 *)
	Instr (reg32, regmem32, none, "0F42/r", {optO32}, {cpuP6});	(* 134 *)
	Instr (reg64, regmem64, none, "0F42/r", {}, {cpuAMD64});	(* 135 *)

	Mnem ("CMOVBE");	(* 40 *)
	Instr (reg16, regmem16, none, "0F46/r", {optO16}, {cpuP6});	(* 136 *)
	Instr (reg32, regmem32, none, "0F46/r", {optO32}, {cpuP6});	(* 137 *)
	Instr (reg64, regmem64, none, "0F46/r", {}, {cpuAMD64});	(* 138 *)

	Mnem ("CMOVC");	(* 41 *)
	Instr (reg16, regmem16, none, "0F42/r", {optO16}, {cpuP6});	(* 139 *)
	Instr (reg32, regmem32, none, "0F42/r", {optO32}, {cpuP6});	(* 140 *)
	Instr (reg64, regmem64, none, "0F42/r", {}, {cpuAMD64});	(* 141 *)

	Mnem ("CMOVE");	(* 42 *)
	Instr (reg16, regmem16, none, "0F44/r", {optO16}, {cpuP6});	(* 142 *)
	Instr (reg32, regmem32, none, "0F44/r", {optO32}, {cpuP6});	(* 143 *)
	Instr (reg64, regmem64, none, "0F44/r", {}, {cpuAMD64});	(* 144 *)

	Mnem ("CMOVG");	(* 43 *)
	Instr (reg16, regmem16, none, "0F4F/r", {optO16}, {cpuP6});	(* 145 *)
	Instr (reg32, regmem32, none, "0F4F/r", {optO32}, {cpuP6});	(* 146 *)
	Instr (reg64, regmem64, none, "0F4F/r", {}, {cpuAMD64});	(* 147 *)

	Mnem ("CMOVGE");	(* 44 *)
	Instr (reg16, regmem16, none, "0F4D/r", {optO16}, {cpuP6});	(* 148 *)
	Instr (reg32, regmem32, none, "0F4D/r", {optO32}, {cpuP6});	(* 149 *)
	Instr (reg64, regmem64, none, "0F4D/r", {}, {cpuAMD64});	(* 150 *)

	Mnem ("CMOVL");	(* 45 *)
	Instr (reg16, regmem16, none, "0F4C/r", {optO16}, {cpuP6});	(* 151 *)
	Instr (reg32, regmem32, none, "0F4C/r", {optO32}, {cpuP6});	(* 152 *)
	Instr (reg64, regmem64, none, "0F4C/r", {}, {cpuAMD64});	(* 153 *)

	Mnem ("CMOVLE");	(* 46 *)
	Instr (reg16, regmem16, none, "0F4E/r", {optO16}, {cpuP6});	(* 154 *)
	Instr (reg32, regmem32, none, "0F4E/r", {optO32}, {cpuP6});	(* 155 *)
	Instr (reg64, regmem64, none, "0F4E/r", {}, {cpuAMD64});	(* 156 *)

	Mnem ("CMOVNA");	(* 47 *)
	Instr (reg16, regmem16, none, "0F46/r", {optO16}, {cpuP6});	(* 157 *)
	Instr (reg32, regmem32, none, "0F46/r", {optO32}, {cpuP6});	(* 158 *)
	Instr (reg64, regmem64, none, "0F46/r", {}, {cpuAMD64});	(* 159 *)

	Mnem ("CMOVNAE");	(* 48 *)
	Instr (reg16, regmem16, none, "0F42/r", {optO16}, {cpuP6});	(* 160 *)
	Instr (reg32, regmem32, none, "0F42/r", {optO32}, {cpuP6});	(* 161 *)
	Instr (reg64, regmem64, none, "0F42/r", {}, {cpuAMD64});	(* 162 *)

	Mnem ("CMOVNB");	(* 49 *)
	Instr (reg16, regmem16, none, "0F43/r", {optO16}, {cpuP6});	(* 163 *)
	Instr (reg32, regmem32, none, "0F43/r", {optO32}, {cpuP6});	(* 164 *)
	Instr (reg64, regmem64, none, "0F43/r", {}, {cpuAMD64});	(* 165 *)

	Mnem ("CMOVNBE");	(* 50 *)
	Instr (reg16, regmem16, none, "0F47/r", {optO16}, {cpuP6});	(* 166 *)
	Instr (reg32, regmem32, none, "0F47/r", {optO32}, {cpuP6});	(* 167 *)
	Instr (reg64, regmem64, none, "0F47/r", {}, {cpuAMD64});	(* 168 *)

	Mnem ("CMOVNC");	(* 51 *)
	Instr (reg16, regmem16, none, "0F43/r", {optO16}, {cpuP6});	(* 169 *)
	Instr (reg32, regmem32, none, "0F43/r", {optO32}, {cpuP6});	(* 170 *)
	Instr (reg64, regmem64, none, "0F43/r", {}, {cpuAMD64});	(* 171 *)

	Mnem ("CMOVNE");	(* 52 *)
	Instr (reg16, regmem16, none, "0F45/r", {optO16}, {cpuP6});	(* 172 *)
	Instr (reg32, regmem32, none, "0F45/r", {optO32}, {cpuP6});	(* 173 *)
	Instr (reg64, regmem64, none, "0F45/r", {}, {cpuAMD64});	(* 174 *)

	Mnem ("CMOVNG");	(* 53 *)
	Instr (reg16, regmem16, none, "0F4E/r", {optO16}, {cpuP6});	(* 175 *)
	Instr (reg32, regmem32, none, "0F4E/r", {optO32}, {cpuP6});	(* 176 *)
	Instr (reg64, regmem64, none, "0F4E/r", {}, {cpuAMD64});	(* 177 *)

	Mnem ("CMOVNGE");	(* 54 *)
	Instr (reg16, regmem16, none, "0F4C/r", {optO16}, {cpuP6});	(* 178 *)
	Instr (reg32, regmem32, none, "0F4C/r", {optO32}, {cpuP6});	(* 179 *)
	Instr (reg64, regmem64, none, "0F4C/r", {}, {cpuAMD64});	(* 180 *)

	Mnem ("CMOVNL");	(* 55 *)
	Instr (reg16, regmem16, none, "0F4D/r", {optO16}, {cpuP6});	(* 181 *)
	Instr (reg32, regmem32, none, "0F4D/r", {optO32}, {cpuP6});	(* 182 *)
	Instr (reg64, regmem64, none, "0F4D/r", {}, {cpuAMD64});	(* 183 *)

	Mnem ("CMOVNLE");	(* 56 *)
	Instr (reg16, regmem16, none, "0F4F/r", {optO16}, {cpuP6});	(* 184 *)
	Instr (reg32, regmem32, none, "0F4F/r", {optO32}, {cpuP6});	(* 185 *)
	Instr (reg64, regmem64, none, "0F4F/r", {}, {cpuAMD64});	(* 186 *)

	Mnem ("CMOVNO");	(* 57 *)
	Instr (reg16, regmem16, none, "0F41/r", {optO16}, {cpuP6});	(* 187 *)
	Instr (reg32, regmem32, none, "0F41/r", {optO32}, {cpuP6});	(* 188 *)
	Instr (reg64, regmem64, none, "0F41/r", {}, {cpuAMD64});	(* 189 *)

	Mnem ("CMOVNP");	(* 58 *)
	Instr (reg16, regmem16, none, "0F4B/r", {optO16}, {cpuP6});	(* 190 *)
	Instr (reg32, regmem32, none, "0F4B/r", {optO32}, {cpuP6});	(* 191 *)
	Instr (reg64, regmem64, none, "0F4B/r", {}, {cpuAMD64});	(* 192 *)

	Mnem ("CMOVNS");	(* 59 *)
	Instr (reg16, regmem16, none, "0F49/r", {optO16}, {cpuP6});	(* 193 *)
	Instr (reg32, regmem32, none, "0F49/r", {optO32}, {cpuP6});	(* 194 *)
	Instr (reg64, regmem64, none, "0F49/r", {}, {cpuAMD64});	(* 195 *)

	Mnem ("CMOVNZ");	(* 60 *)
	Instr (reg16, regmem16, none, "0F45/r", {optO16}, {cpuP6});	(* 196 *)
	Instr (reg32, regmem32, none, "0F45/r", {optO32}, {cpuP6});	(* 197 *)
	Instr (reg64, regmem64, none, "0F45/r", {}, {cpuAMD64});	(* 198 *)

	Mnem ("CMOVO");	(* 61 *)
	Instr (reg16, regmem16, none, "0F40/r", {optO16}, {cpuP6});	(* 199 *)
	Instr (reg32, regmem32, none, "0F40/r", {optO32}, {cpuP6});	(* 200 *)
	Instr (reg64, regmem64, none, "0F40/r", {}, {cpuAMD64});	(* 201 *)

	Mnem ("CMOVP");	(* 62 *)
	Instr (reg16, regmem16, none, "0F4A/r", {optO16}, {cpuP6});	(* 202 *)
	Instr (reg32, regmem32, none, "0F4A/r", {optO32}, {cpuP6});	(* 203 *)
	Instr (reg64, regmem64, none, "0F4A/r", {}, {cpuAMD64});	(* 204 *)

	Mnem ("CMOVPE");	(* 63 *)
	Instr (reg16, regmem16, none, "0F4A/r", {optO16}, {cpuP6});	(* 205 *)
	Instr (reg32, regmem32, none, "0F4A/r", {optO32}, {cpuP6});	(* 206 *)
	Instr (reg64, regmem64, none, "0F4A/r", {}, {cpuAMD64});	(* 207 *)

	Mnem ("CMOVPO");	(* 64 *)
	Instr (reg16, regmem16, none, "0F4B/r", {optO16}, {cpuP6});	(* 208 *)
	Instr (reg32, regmem32, none, "0F4B/r", {optO32}, {cpuP6});	(* 209 *)
	Instr (reg64, regmem64, none, "0F4B/r", {}, {cpuAMD64});	(* 210 *)

	Mnem ("CMOVS");	(* 65 *)
	Instr (reg16, regmem16, none, "0F48/r", {optO16}, {cpuP6});	(* 211 *)
	Instr (reg32, regmem32, none, "0F48/r", {optO32}, {cpuP6});	(* 212 *)
	Instr (reg64, regmem64, none, "0F48/r", {}, {cpuAMD64});	(* 213 *)

	Mnem ("CMOVZ");	(* 66 *)
	Instr (reg16, regmem16, none, "0F44/r", {optO16}, {cpuP6});	(* 214 *)
	Instr (reg32, regmem32, none, "0F44/r", {optO32}, {cpuP6});	(* 215 *)
	Instr (reg64, regmem64, none, "0F44/r", {}, {cpuAMD64});	(* 216 *)

	Mnem ("CMP");	(* 67 *)
	Instr (AL, imm8, none, "3Cib", {}, {cpu8086});	(* 217 *)
	Instr (AX, imm16, none, "3Diw", {optO16}, {cpu8086});	(* 218 *)
	Instr (EAX, imm32, none, "3Did", {optO32}, {cpu386});	(* 219 *)
	Instr (RAX, imm32, none, "3Did", {}, {cpuAMD64});	(* 220 *)
	Instr (regmem8, reg8, none, "38/r", {}, {cpu8086});	(* 221 *)
	Instr (regmem16, reg16, none, "39/r", {optO16}, {cpu8086});	(* 222 *)
	Instr (regmem32, reg32, none, "39/r", {optO32}, {cpu386});	(* 223 *)
	Instr (regmem64, reg64, none, "39/r", {}, {cpuAMD64});	(* 224 *)
	Instr (reg8, regmem8, none, "3A/r", {}, {cpu8086});	(* 225 *)
	Instr (reg16, regmem16, none, "3B/r", {optO16}, {cpu8086});	(* 226 *)
	Instr (reg32, regmem32, none, "3B/r", {optO32}, {cpu386});	(* 227 *)
	Instr (reg64, regmem64, none, "3B/r", {}, {cpuAMD64});	(* 228 *)
	Instr (regmem8, imm8, none, "80/7ib", {}, {cpu8086});	(* 229 *)
	Instr (regmem16, simm8, none, "83/7ib", {optO16}, {cpu8086});	(* 230 *)
	Instr (regmem16, imm16, none, "81/7iw", {optO16}, {cpu8086});	(* 231 *)
	Instr (regmem32, simm8, none, "83/7ib", {optO32}, {cpu386});	(* 232 *)
	Instr (regmem32, imm32, none, "81/7id", {optO32}, {cpu386});	(* 233 *)
	Instr (regmem64, simm8, none, "83/7ib", {}, {cpuAMD64});	(* 234 *)
	Instr (regmem64, imm32, none, "81/7id", {}, {cpuAMD64});	(* 235 *)

	Mnem ("CMPPD");	(* 68 *)
	Instr (xmm, xmmmem128, uimm8, "0FC2/rib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 236 *)

	Mnem ("CMPPS");	(* 69 *)
	Instr (xmm, xmmmem128, uimm8, "0FC2/rib", {}, {cpuKatmai, cpuSSE});	(* 237 *)

	Mnem ("CMPS");	(* 70 *)
	Instr (mem8, mem8, none, "A6", {}, {cpu8086});	(* 238 *)
	Instr (mem16, mem16, none, "A7", {optO16}, {cpu8086});	(* 239 *)
	Instr (mem32, mem32, none, "A7", {optO32}, {cpu386});	(* 240 *)
	Instr (mem64, mem64, none, "A7", {}, {cpuAMD64});	(* 241 *)

	Mnem ("CMPSB");	(* 71 *)
	Instr (none, none, none, "A6", {}, {cpu8086});	(* 242 *)

	Mnem ("CMPSD");	(* 72 *)
	Instr (none, none, none, "A7", {optO32}, {cpu386});	(* 243 *)
	Instr (xmm, xmmmem64, uimm8, "0FC2/rib", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 244 *)

	Mnem ("CMPSQ");	(* 73 *)
	Instr (none, none, none, "A7", {optO64}, {cpuAMD64});	(* 245 *)

	Mnem ("CMPSS");	(* 74 *)
	Instr (xmm, xmmmem32, uimm8, "0FC2/rib", {optPREP}, {cpuKatmai, cpuSSE});	(* 246 *)

	Mnem ("CMPSW");	(* 75 *)
	Instr (none, none, none, "A7", {optO16}, {cpu8086});	(* 247 *)

	Mnem ("CMPXCHG");	(* 76 *)
	Instr (regmem8, reg8, none, "0FB0/r", {}, {cpuPentium});	(* 248 *)
	Instr (regmem16, reg16, none, "0FB1/r", {optO16}, {cpuPentium});	(* 249 *)
	Instr (regmem32, reg32, none, "0FB1/r", {optO32}, {cpuPentium});	(* 250 *)
	Instr (regmem64, reg64, none, "0FB1/r", {}, {cpuAMD64});	(* 251 *)

	Mnem ("CMPXCHG16B");	(* 77 *)
	Instr (mem128, none, none, "0FC7/1", {}, {cpuWillamette, cpuSSE2});	(* 252 *)

	Mnem ("CMPXCHG8B");	(* 78 *)
	Instr (mem64, none, none, "0FC7/1", {}, {cpuPentium});	(* 253 *)

	Mnem ("COMISD");	(* 79 *)
	Instr (xmm, xmmmem64, none, "0F2F/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 254 *)

	Mnem ("COMISS");	(* 80 *)
	Instr (xmm, xmmmem32, none, "0F2F/r", {}, {cpuKatmai, cpuSSE});	(* 255 *)

	Mnem ("CPUID");	(* 81 *)
	Instr (none, none, none, "0FA2", {}, {cpuPentium});	(* 256 *)

	Mnem ("CQO");	(* 82 *)
	Instr (none, none, none, "99", {optO64}, {cpuAMD64});	(* 257 *)

	Mnem ("CVTDQ2PD");	(* 83 *)
	Instr (xmm, xmmmem64, none, "0FE6/r", {optPREP}, {cpuWillamette, cpuSSE2});	(* 258 *)

	Mnem ("CVTDQ2PS");	(* 84 *)
	Instr (xmm, xmmmem128, none, "0F5B/r", {}, {cpuWillamette, cpuSSE2});	(* 259 *)

	Mnem ("CVTPD2DQ");	(* 85 *)
	Instr (xmm, xmmmem128, none, "0FE6/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 260 *)

	Mnem ("CVTPD2PI");	(* 86 *)
	Instr (mmx, xmmmem128, none, "0F2D/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 261 *)
	Instr (mmx, xmmmem128, none, "0F2D/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 262 *)
	Instr (mmx, xmmmem128, none, "0F2C/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 263 *)

	Mnem ("CVTPD2PS");	(* 87 *)
	Instr (xmm, xmmmem128, none, "0F5A/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 264 *)

	Mnem ("CVTPI2PD");	(* 88 *)
	Instr (xmm, mmxmem64, none, "0F2A/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 265 *)
	Instr (xmm, mmxmem64, none, "0F2A/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 266 *)

	Mnem ("CVTPI2PS");	(* 89 *)
	Instr (xmm, mmxmem64, none, "0F2A/r", {}, {cpuKatmai, cpuSSE});	(* 267 *)
	Instr (xmm, mmxmem64, none, "0F2A/r", {}, {cpuKatmai, cpuSSE});	(* 268 *)

	Mnem ("CVTPS2DQ");	(* 90 *)
	Instr (xmm, xmmmem128, none, "0F5B/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 269 *)

	Mnem ("CVTPS2PD");	(* 91 *)
	Instr (xmm, xmmmem64, none, "0F5A/r", {}, {cpuWillamette, cpuSSE2});	(* 270 *)

	Mnem ("CVTPS2PI");	(* 92 *)
	Instr (mmx, xmmmem64, none, "0F2D/r", {}, {cpuKatmai, cpuSSE});	(* 271 *)
	Instr (mmx, xmmmem64, none, "0F2D/r", {}, {cpuKatmai, cpuSSE});	(* 272 *)

	Mnem ("CVTSD2SI");	(* 93 *)
	Instr (reg32, xmmmem64, none, "0F2D/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 273 *)
	Instr (reg64, xmmmem64, none, "0F2D/r", {optPREPN}, {cpuAMD64, cpuSSE2});	(* 274 *)

	Mnem ("CVTSD2SS");	(* 94 *)
	Instr (xmm, xmmmem64, none, "0F5A/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 275 *)

	Mnem ("CVTSI2SD");	(* 95 *)
	Instr (xmm, regmem32, none, "0F2A/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 276 *)
	Instr (xmm, regmem64, none, "0F2A/r", {optPREPN}, {cpuAMD64, cpuSSE2});	(* 277 *)

	Mnem ("CVTSI2SS");	(* 96 *)
	Instr (xmm, regmem32, none, "0F2A/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 278 *)
	Instr (xmm, regmem64, none, "0F2A/r", {optPREP}, {cpuAMD64, cpuSSE});	(* 279 *)

	Mnem ("CVTSS2SD");	(* 97 *)
	Instr (xmm, xmmmem32, none, "0F5A/r", {optPREP}, {cpuWillamette, cpuSSE2});	(* 280 *)

	Mnem ("CVTSS2SI");	(* 98 *)
	Instr (reg32, xmmmem32, none, "0F2D/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 281 *)
	Instr (reg64, xmmmem32, none, "0F2D/r", {optPREP}, {cpuAMD64, cpuSSE});	(* 282 *)

	Mnem ("CVTTPD2DQ");	(* 99 *)
	Instr (xmm, xmmmem128, none, "0FE6/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 283 *)

	Mnem ("CVTTPD2PI");	(* 100 *)
	Instr (mmx, xmmmem128, none, "0F2C/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 284 *)

	Mnem ("CVTTPS2DQ");	(* 101 *)
	Instr (xmm, xmmmem128, none, "0F5B/r", {optPREP}, {cpuWillamette, cpuSSE2});	(* 285 *)

	Mnem ("CVTTPS2PI");	(* 102 *)
	Instr (mmx, xmmmem64, none, "0F2C/r", {}, {cpuKatmai, cpuSSE});	(* 286 *)
	Instr (mmx, xmmmem64, none, "0F2C/r", {}, {cpuKatmai, cpuSSE});	(* 287 *)

	Mnem ("CVTTSD2SI");	(* 103 *)
	Instr (reg32, xmmmem64, none, "0F2C/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 288 *)
	Instr (reg64, xmmmem64, none, "0F2C/r", {optPREPN}, {cpuAMD64, cpuSSE2});	(* 289 *)

	Mnem ("CVTTSS2SI");	(* 104 *)
	Instr (reg32, xmmmem32, none, "0F2C/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 290 *)
	Instr (reg64, xmmmem32, none, "0F2C/r", {optPREP}, {cpuAMD64, cpuSSE});	(* 291 *)

	Mnem ("CWD");	(* 105 *)
	Instr (none, none, none, "99", {optO16}, {cpu8086});	(* 292 *)

	Mnem ("CWDE");	(* 106 *)
	Instr (none, none, none, "98", {optO32}, {cpu386});	(* 293 *)

	Mnem ("DAA");	(* 107 *)
	Instr (none, none, none, "27", {optI64}, {cpu8086});	(* 294 *)

	Mnem ("DAS");	(* 108 *)
	Instr (none, none, none, "2F", {optI64}, {cpu8086});	(* 295 *)

	Mnem ("DEC");	(* 109 *)
	Instr (reg16, none, none, "48rw", {optO16, optI64}, {cpu8086});	(* 296 *)
	Instr (reg32, none, none, "48rd", {optO32, optI64}, {cpu386});	(* 297 *)
	Instr (regmem8, none, none, "FE/1", {}, {cpu8086});	(* 298 *)
	Instr (regmem16, none, none, "FF/1", {optO16}, {cpu8086});	(* 299 *)
	Instr (regmem32, none, none, "FF/1", {optO32}, {cpu386});	(* 300 *)
	Instr (regmem64, none, none, "FF/1", {}, {cpuAMD64});	(* 301 *)

	Mnem ("DIV");	(* 110 *)
	Instr (regmem8, none, none, "F6/6", {}, {cpu8086});	(* 302 *)
	Instr (regmem16, none, none, "F7/6", {optO16}, {cpu8086});	(* 303 *)
	Instr (regmem32, none, none, "F7/6", {optO32}, {cpu386});	(* 304 *)
	Instr (regmem64, none, none, "F7/6", {}, {cpuAMD64});	(* 305 *)

	Mnem ("DIVPD");	(* 111 *)
	Instr (xmm, xmmmem128, none, "0F5E/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 306 *)

	Mnem ("DIVPS");	(* 112 *)
	Instr (xmm, xmmmem128, none, "0F5E/r", {}, {cpuKatmai, cpuSSE});	(* 307 *)

	Mnem ("DIVSD");	(* 113 *)
	Instr (xmm, xmmmem64, none, "0F5E/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 308 *)

	Mnem ("DIVSS");	(* 114 *)
	Instr (xmm, xmmmem32, none, "0F5E/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 309 *)

	Mnem ("EMMS");	(* 115 *)
	Instr (none, none, none, "0F77", {}, {cpuPentium, cpuMMX});	(* 310 *)

	Mnem ("ENTER");	(* 116 *)
	Instr (uimm16, uimm8, none, "C8iwib", {}, {cpu186});	(* 311 *)

	Mnem ("F2XM1");	(* 117 *)
	Instr (none, none, none, "D9F0", {}, {cpu8086, cpuFPU});	(* 312 *)

	Mnem ("FABS");	(* 118 *)
	Instr (none, none, none, "D9E1", {}, {cpu8086, cpuFPU});	(* 313 *)

	Mnem ("FADD");	(* 119 *)
	Instr (st0, sti, none, "D8C0+i", {}, {cpu8086, cpuFPU});	(* 314 *)
	Instr (sti, st0, none, "DCC0+i", {}, {cpu8086, cpuFPU});	(* 315 *)
	Instr (mem32, none, none, "D8/0", {}, {cpu8086, cpuFPU});	(* 316 *)
	Instr (mem64, none, none, "DC/0", {}, {cpu8086, cpuFPU});	(* 317 *)

	Mnem ("FADDP");	(* 120 *)
	Instr (none, none, none, "DEC1", {}, {cpu8086, cpuFPU});	(* 318 *)
	Instr (sti, st0, none, "DEC0+i", {}, {cpu8086, cpuFPU});	(* 319 *)

	Mnem ("FBLD");	(* 121 *)
	Instr (mem, none, none, "DF/4", {}, {cpu8086, cpuFPU});	(* 320 *)

	Mnem ("FBSTP");	(* 122 *)
	Instr (mem, none, none, "DF/6", {}, {cpu8086, cpuFPU});	(* 321 *)

	Mnem ("FCHS");	(* 123 *)
	Instr (none, none, none, "D9E0", {}, {cpu8086, cpuFPU});	(* 322 *)

	Mnem ("FCLEX");	(* 124 *)
	Instr (none, none, none, "9BDBE2", {}, {cpu8086, cpuFPU});	(* 323 *)

	Mnem ("FCMOVB");	(* 125 *)
	Instr (st0, sti, none, "DAC0+i", {}, {cpuP6, cpuFPU});	(* 324 *)

	Mnem ("FCMOVBE");	(* 126 *)
	Instr (st0, sti, none, "DAD0+i", {}, {cpuP6, cpuFPU});	(* 325 *)

	Mnem ("FCMOVE");	(* 127 *)
	Instr (st0, sti, none, "DAC8+i", {}, {cpuP6, cpuFPU});	(* 326 *)

	Mnem ("FCMOVNB");	(* 128 *)
	Instr (st0, sti, none, "DBC0+i", {}, {cpuP6, cpuFPU});	(* 327 *)

	Mnem ("FCMOVNBE");	(* 129 *)
	Instr (st0, sti, none, "DBD0+i", {}, {cpuP6, cpuFPU});	(* 328 *)

	Mnem ("FCMOVNE");	(* 130 *)
	Instr (st0, sti, none, "DBC8+i", {}, {cpuP6, cpuFPU});	(* 329 *)

	Mnem ("FCMOVNU");	(* 131 *)
	Instr (st0, sti, none, "DBD8+i", {}, {cpuP6, cpuFPU});	(* 330 *)

	Mnem ("FCMOVU");	(* 132 *)
	Instr (st0, sti, none, "DAD8+i", {}, {cpuP6, cpuFPU});	(* 331 *)

	Mnem ("FCOM");	(* 133 *)
	Instr (none, none, none, "D8D1", {}, {cpu8086, cpuFPU});	(* 332 *)
	Instr (sti, none, none, "D8D0+i", {}, {cpu8086, cpuFPU});	(* 333 *)
	Instr (mem32, none, none, "D8/2", {}, {cpu8086, cpuFPU});	(* 334 *)
	Instr (mem64, none, none, "DC/2", {}, {cpu8086, cpuFPU});	(* 335 *)

	Mnem ("FCOMI");	(* 134 *)
	Instr (st0, sti, none, "DBF0+i", {}, {cpuP6, cpuFPU});	(* 336 *)

	Mnem ("FCOMIP");	(* 135 *)
	Instr (st0, sti, none, "DFF0+i", {}, {cpuP6, cpuFPU});	(* 337 *)

	Mnem ("FCOMP");	(* 136 *)
	Instr (none, none, none, "D8D9", {}, {cpu8086, cpuFPU});	(* 338 *)
	Instr (sti, none, none, "D8D8+i", {}, {cpu8086, cpuFPU});	(* 339 *)
	Instr (mem32, none, none, "D8/3", {}, {cpu8086, cpuFPU});	(* 340 *)
	Instr (mem64, none, none, "DC/3", {}, {cpu8086, cpuFPU});	(* 341 *)

	Mnem ("FCOMPP");	(* 137 *)
	Instr (none, none, none, "DED9", {}, {cpu8086, cpuFPU});	(* 342 *)

	Mnem ("FCOS");	(* 138 *)
	Instr (none, none, none, "D9FF", {}, {cpu386, cpuFPU});	(* 343 *)

	Mnem ("FDECSTP");	(* 139 *)
	Instr (none, none, none, "D9F6", {}, {cpu8086, cpuFPU});	(* 344 *)

	Mnem ("FDIV");	(* 140 *)
	Instr (st0, sti, none, "D8F0+i", {}, {cpu8086, cpuFPU});	(* 345 *)
	Instr (sti, st0, none, "DCF8+i", {}, {cpu8086, cpuFPU});	(* 346 *)
	Instr (mem32, none, none, "D8/6", {}, {cpu8086, cpuFPU});	(* 347 *)
	Instr (mem64, none, none, "DC/6", {}, {cpu8086, cpuFPU});	(* 348 *)

	Mnem ("FDIVP");	(* 141 *)
	Instr (none, none, none, "DEF9", {}, {cpu8086, cpuFPU});	(* 349 *)
	Instr (sti, st0, none, "DEF8+i", {}, {cpu8086, cpuFPU});	(* 350 *)

	Mnem ("FDIVR");	(* 142 *)
	Instr (st0, sti, none, "D8F8+i", {}, {cpu8086, cpuFPU});	(* 351 *)
	Instr (sti, st0, none, "DCF0+i", {}, {cpu8086, cpuFPU});	(* 352 *)
	Instr (mem32, none, none, "D8/7", {}, {cpu8086, cpuFPU});	(* 353 *)
	Instr (mem64, none, none, "DC/7", {}, {cpu8086, cpuFPU});	(* 354 *)

	Mnem ("FDIVRP");	(* 143 *)
	Instr (none, none, none, "DEF1", {}, {cpu8086, cpuFPU});	(* 355 *)
	Instr (sti, st0, none, "DEF0+i", {}, {cpu8086, cpuFPU});	(* 356 *)

	Mnem ("FEMMS");	(* 144 *)
	Instr (none, none, none, "0F0E", {}, {cpuPentium, cpu3DNow});	(* 357 *)

	Mnem ("FFREE");	(* 145 *)
	Instr (sti, none, none, "DDC0+i", {}, {cpu8086, cpuFPU});	(* 358 *)

	Mnem ("FIADD");	(* 146 *)
	Instr (mem16, none, none, "DE/0", {}, {cpu8086, cpuFPU});	(* 359 *)
	Instr (mem32, none, none, "DA/0", {}, {cpu8086, cpuFPU});	(* 360 *)

	Mnem ("FICOM");	(* 147 *)
	Instr (mem16, none, none, "DE/2", {}, {cpu8086, cpuFPU});	(* 361 *)
	Instr (mem32, none, none, "DA/2", {}, {cpu8086, cpuFPU});	(* 362 *)

	Mnem ("FICOMP");	(* 148 *)
	Instr (mem16, none, none, "DE/3", {}, {cpu8086, cpuFPU});	(* 363 *)
	Instr (mem32, none, none, "DA/3", {}, {cpu8086, cpuFPU});	(* 364 *)

	Mnem ("FIDIV");	(* 149 *)
	Instr (mem16, none, none, "DE/6", {}, {cpu8086, cpuFPU});	(* 365 *)
	Instr (mem32, none, none, "DA/6", {}, {cpu8086, cpuFPU});	(* 366 *)

	Mnem ("FIDIVR");	(* 150 *)
	Instr (mem16, none, none, "DE/7", {}, {cpu8086, cpuFPU});	(* 367 *)
	Instr (mem32, none, none, "DA/7", {}, {cpu8086, cpuFPU});	(* 368 *)

	Mnem ("FILD");	(* 151 *)
	Instr (mem16, none, none, "DF/0", {}, {cpu8086, cpuFPU});	(* 369 *)
	Instr (mem32, none, none, "DB/0", {}, {cpu8086, cpuFPU});	(* 370 *)
	Instr (mem64, none, none, "DF/5", {}, {cpu8086, cpuFPU});	(* 371 *)

	Mnem ("FIMUL");	(* 152 *)
	Instr (mem16, none, none, "DE/1", {}, {cpu8086, cpuFPU});	(* 372 *)
	Instr (mem32, none, none, "DA/1", {}, {cpu8086, cpuFPU});	(* 373 *)

	Mnem ("FINCSTP");	(* 153 *)
	Instr (none, none, none, "D9F7", {}, {cpu8086, cpuFPU});	(* 374 *)

	Mnem ("FINIT");	(* 154 *)
	Instr (none, none, none, "9BDBE3", {}, {cpu8086, cpuFPU});	(* 375 *)

	Mnem ("FIST");	(* 155 *)
	Instr (mem16, none, none, "DF/2", {}, {cpu8086, cpuFPU});	(* 376 *)
	Instr (mem32, none, none, "DB/2", {}, {cpu8086, cpuFPU});	(* 377 *)

	Mnem ("FISTP");	(* 156 *)
	Instr (mem16, none, none, "DF/3", {}, {cpu8086, cpuFPU});	(* 378 *)
	Instr (mem32, none, none, "DB/3", {}, {cpu8086, cpuFPU});	(* 379 *)
	Instr (mem64, none, none, "DF/7", {}, {cpu8086, cpuFPU});	(* 380 *)

	Mnem ("FISTTP");	(* 157 *)
	Instr (mem16, none, none, "DF/1", {}, {cpuPrescott, cpuFPU});	(* 381 *)
	Instr (mem32, none, none, "DB/1", {}, {cpuPrescott, cpuFPU});	(* 382 *)
	Instr (mem64, none, none, "DD/1", {}, {cpuPrescott, cpuFPU});	(* 383 *)

	Mnem ("FISUB");	(* 158 *)
	Instr (mem16, none, none, "DE/4", {}, {cpu8086, cpuFPU});	(* 384 *)
	Instr (mem32, none, none, "DA/4", {}, {cpu8086, cpuFPU});	(* 385 *)

	Mnem ("FISUBR");	(* 159 *)
	Instr (mem16, none, none, "DE/5", {}, {cpu8086, cpuFPU});	(* 386 *)
	Instr (mem32, none, none, "DA/5", {}, {cpu8086, cpuFPU});	(* 387 *)

	Mnem ("FLD");	(* 160 *)
	Instr (sti, none, none, "D9C0+i", {}, {cpu8086, cpuFPU});	(* 388 *)
	Instr (mem32, none, none, "D9/0", {}, {cpu8086, cpuFPU});	(* 389 *)
	Instr (mem64, none, none, "DD/0", {}, {cpu8086, cpuFPU});	(* 390 *)
	Instr (mem, none, none, "DB/5", {}, {cpu8086, cpuFPU});	(* 391 *)

	Mnem ("FLD1");	(* 161 *)
	Instr (none, none, none, "D9E8", {}, {cpu8086, cpuFPU});	(* 392 *)

	Mnem ("FLDCW");	(* 162 *)
	Instr (mem16, none, none, "D9/5", {}, {cpu8086, cpuFPU});	(* 393 *)

	Mnem ("FLDENV");	(* 163 *)
	Instr (mem, none, none, "D9/4", {}, {cpu8086, cpuFPU});	(* 394 *)

	Mnem ("FLDL2E");	(* 164 *)
	Instr (none, none, none, "D9EA", {}, {cpu8086, cpuFPU});	(* 395 *)

	Mnem ("FLDL2T");	(* 165 *)
	Instr (none, none, none, "D9E9", {}, {cpu8086, cpuFPU});	(* 396 *)

	Mnem ("FLDLG2");	(* 166 *)
	Instr (none, none, none, "D9EC", {}, {cpu8086, cpuFPU});	(* 397 *)

	Mnem ("FLDLN2");	(* 167 *)
	Instr (none, none, none, "D9ED", {}, {cpu8086, cpuFPU});	(* 398 *)

	Mnem ("FLDPI");	(* 168 *)
	Instr (none, none, none, "D9EB", {}, {cpu8086, cpuFPU});	(* 399 *)

	Mnem ("FLDZ");	(* 169 *)
	Instr (none, none, none, "D9EE", {}, {cpu8086, cpuFPU});	(* 400 *)

	Mnem ("FMUL");	(* 170 *)
	Instr (st0, sti, none, "D8C8+i", {}, {cpu8086, cpuFPU});	(* 401 *)
	Instr (sti, st0, none, "DCC8+i", {}, {cpu8086, cpuFPU});	(* 402 *)
	Instr (mem32, none, none, "D8/1", {}, {cpu8086, cpuFPU});	(* 403 *)
	Instr (mem64, none, none, "DC/1", {}, {cpu8086, cpuFPU});	(* 404 *)

	Mnem ("FMULP");	(* 171 *)
	Instr (none, none, none, "DEC9", {}, {cpu8086, cpuFPU});	(* 405 *)
	Instr (sti, st0, none, "DEC8+i", {}, {cpu8086, cpuFPU});	(* 406 *)

	Mnem ("FNCLEX");	(* 172 *)
	Instr (none, none, none, "DBE2", {}, {cpu8086, cpuFPU});	(* 407 *)

	Mnem ("FNINIT");	(* 173 *)
	Instr (none, none, none, "DBE3", {}, {cpu8086, cpuFPU});	(* 408 *)

	Mnem ("FNOP");	(* 174 *)
	Instr (none, none, none, "D9D0", {}, {cpu8086, cpuFPU});	(* 409 *)

	Mnem ("FNSAVE");	(* 175 *)
	Instr (mem, none, none, "DD/6", {}, {cpu8086, cpuFPU});	(* 410 *)
	Instr (mem, none, none, "DD/6", {}, {cpu8086, cpuFPU});	(* 411 *)

	Mnem ("FNSTCW");	(* 176 *)
	Instr (mem16, none, none, "D9/7", {}, {cpu8086, cpuFPU});	(* 412 *)

	Mnem ("FNSTENV");	(* 177 *)
	Instr (mem, none, none, "D9/6", {}, {cpu8086, cpuFPU});	(* 413 *)

	Mnem ("FNSTSW");	(* 178 *)
	Instr (AX, none, none, "DFE0", {}, {cpu286, cpuFPU});	(* 414 *)
	Instr (mem16, none, none, "DD/7", {}, {cpu8086, cpuFPU});	(* 415 *)

	Mnem ("FPATAN");	(* 179 *)
	Instr (none, none, none, "D9F3", {}, {cpu8086, cpuFPU});	(* 416 *)

	Mnem ("FPREM");	(* 180 *)
	Instr (none, none, none, "D9F8", {}, {cpu8086, cpuFPU});	(* 417 *)

	Mnem ("FPREM1");	(* 181 *)
	Instr (none, none, none, "D9F5", {}, {cpu386, cpuFPU});	(* 418 *)

	Mnem ("FPTAN");	(* 182 *)
	Instr (none, none, none, "D9F2", {}, {cpu8086, cpuFPU});	(* 419 *)

	Mnem ("FRNDINT");	(* 183 *)
	Instr (none, none, none, "D9FC", {}, {cpu8086, cpuFPU});	(* 420 *)

	Mnem ("FRSTOR");	(* 184 *)
	Instr (mem, none, none, "DD/4", {}, {cpu8086, cpuFPU});	(* 421 *)
	Instr (mem, none, none, "DD/4", {}, {cpu8086, cpuFPU});	(* 422 *)

	Mnem ("FSAVE");	(* 185 *)
	Instr (mem, none, none, "9BDD/6", {}, {cpu8086, cpuFPU});	(* 423 *)
	Instr (mem, none, none, "9BDD/6", {}, {cpu8086, cpuFPU});	(* 424 *)

	Mnem ("FSCALE");	(* 186 *)
	Instr (none, none, none, "D9FD", {}, {cpu8086, cpuFPU});	(* 425 *)

	Mnem ("FSIN");	(* 187 *)
	Instr (none, none, none, "D9FE", {}, {cpu386, cpuFPU});	(* 426 *)

	Mnem ("FSINCOS");	(* 188 *)
	Instr (none, none, none, "D9FB", {}, {cpu386, cpuFPU});	(* 427 *)

	Mnem ("FSQRT");	(* 189 *)
	Instr (none, none, none, "D9FA", {}, {cpu8086, cpuFPU});	(* 428 *)

	Mnem ("FST");	(* 190 *)
	Instr (sti, none, none, "DDD0+i", {}, {cpu8086, cpuFPU});	(* 429 *)
	Instr (mem32, none, none, "D9/2", {}, {cpu8086, cpuFPU});	(* 430 *)
	Instr (mem64, none, none, "DD/2", {}, {cpu8086, cpuFPU});	(* 431 *)

	Mnem ("FSTCW");	(* 191 *)
	Instr (mem16, none, none, "9BD9/7", {}, {cpu8086, cpuFPU});	(* 432 *)

	Mnem ("FSTENV");	(* 192 *)
	Instr (mem, none, none, "9BD9/6", {}, {cpu8086, cpuFPU});	(* 433 *)

	Mnem ("FSTP");	(* 193 *)
	Instr (sti, none, none, "DDD8+i", {}, {cpu8086, cpuFPU});	(* 434 *)
	Instr (mem32, none, none, "D9/3", {}, {cpu8086, cpuFPU});	(* 435 *)
	Instr (mem64, none, none, "DD/3", {}, {cpu8086, cpuFPU});	(* 436 *)
	Instr (mem, none, none, "DB/7", {}, {cpu8086, cpuFPU});	(* 437 *)

	Mnem ("FSTSW");	(* 194 *)
	Instr (AX, none, none, "9BDFE0", {}, {cpu286, cpuFPU});	(* 438 *)
	Instr (mem16, none, none, "9BDD/7", {}, {cpu8086, cpuFPU});	(* 439 *)

	Mnem ("FSUB");	(* 195 *)
	Instr (st0, sti, none, "D8E0+i", {}, {cpu8086, cpuFPU});	(* 440 *)
	Instr (sti, st0, none, "DCE8+i", {}, {cpu8086, cpuFPU});	(* 441 *)
	Instr (mem32, none, none, "D8/4", {}, {cpu8086, cpuFPU});	(* 442 *)
	Instr (mem64, none, none, "DC/4", {}, {cpu8086, cpuFPU});	(* 443 *)

	Mnem ("FSUBP");	(* 196 *)
	Instr (none, none, none, "DEE9", {}, {cpu8086, cpuFPU});	(* 444 *)
	Instr (sti, st0, none, "DEE8+i", {}, {cpu8086, cpuFPU});	(* 445 *)

	Mnem ("FSUBR");	(* 197 *)
	Instr (st0, sti, none, "D8E8+i", {}, {cpu8086, cpuFPU});	(* 446 *)
	Instr (sti, st0, none, "DCE0+i", {}, {cpu8086, cpuFPU});	(* 447 *)
	Instr (mem32, none, none, "D8/5", {}, {cpu8086, cpuFPU});	(* 448 *)
	Instr (mem64, none, none, "DC/5", {}, {cpu8086, cpuFPU});	(* 449 *)

	Mnem ("FSUBRP");	(* 198 *)
	Instr (none, none, none, "DEE1", {}, {cpu8086, cpuFPU});	(* 450 *)
	Instr (sti, st0, none, "DEE0+i", {}, {cpu8086, cpuFPU});	(* 451 *)

	Mnem ("FTST");	(* 199 *)
	Instr (none, none, none, "D9E4", {}, {cpu8086, cpuFPU});	(* 452 *)

	Mnem ("FUCOM");	(* 200 *)
	Instr (none, none, none, "DDE1", {}, {cpu386, cpuFPU});	(* 453 *)
	Instr (sti, none, none, "DDE0+i", {}, {cpu386, cpuFPU});	(* 454 *)

	Mnem ("FUCOMI");	(* 201 *)
	Instr (st0, sti, none, "DBE8+i", {}, {cpuP6, cpuFPU});	(* 455 *)

	Mnem ("FUCOMIP");	(* 202 *)
	Instr (st0, sti, none, "DFE8+i", {}, {cpuP6, cpuFPU});	(* 456 *)

	Mnem ("FUCOMP");	(* 203 *)
	Instr (none, none, none, "DDE9", {}, {cpu386, cpuFPU});	(* 457 *)
	Instr (sti, none, none, "DDE8+i", {}, {cpu386, cpuFPU});	(* 458 *)

	Mnem ("FUCOMPP");	(* 204 *)
	Instr (none, none, none, "DAE9", {}, {cpu386, cpuFPU});	(* 459 *)

	Mnem ("FWAIT");	(* 205 *)
	Instr (none, none, none, "9B", {}, {cpu8086});	(* 460 *)

	Mnem ("FXAM");	(* 206 *)
	Instr (none, none, none, "D9E5", {}, {cpu8086, cpuFPU});	(* 461 *)

	Mnem ("FXCH");	(* 207 *)
	Instr (none, none, none, "D9C9", {}, {cpu8086, cpuFPU});	(* 462 *)
	Instr (sti, none, none, "D9C8+i", {}, {cpu8086, cpuFPU});	(* 463 *)

	Mnem ("FXRSTOR");	(* 208 *)
	Instr (mem, none, none, "0FAE/1", {}, {cpuP6, cpuSSE, cpuFPU});	(* 464 *)
	Instr (mem, none, none, "0FAE/1", {}, {cpuP6, cpuSSE, cpuFPU});	(* 465 *)
	Instr (mem, none, none, "0FAE/1", {}, {cpuP6, cpuSSE, cpuFPU});	(* 466 *)

	Mnem ("FXSAVE");	(* 209 *)
	Instr (mem, none, none, "0FAE/0", {}, {cpuP6, cpuSSE, cpuFPU});	(* 467 *)
	Instr (mem, none, none, "0FAE/0", {}, {cpuP6, cpuSSE, cpuFPU});	(* 468 *)
	Instr (mem, none, none, "0FAE/0", {}, {cpuP6, cpuSSE, cpuFPU});	(* 469 *)

	Mnem ("FXTRACT");	(* 210 *)
	Instr (none, none, none, "D9F4", {}, {cpu8086, cpuFPU});	(* 470 *)

	Mnem ("FYL2X");	(* 211 *)
	Instr (none, none, none, "D9F1", {}, {cpu8086, cpuFPU});	(* 471 *)

	Mnem ("FYL2XP1");	(* 212 *)
	Instr (none, none, none, "D9F9", {}, {cpu8086, cpuFPU});	(* 472 *)

	Mnem ("HADDPD");	(* 213 *)
	Instr (xmm, xmmmem128, none, "0F7C/r", {optPOP}, {cpuPrescott, cpuSSE3});	(* 473 *)

	Mnem ("HADDPS");	(* 214 *)
	Instr (xmm, xmmmem128, none, "0F7C/r", {optPREPN}, {cpuPrescott, cpuSSE3});	(* 474 *)

	Mnem ("HLT");	(* 215 *)
	Instr (none, none, none, "F4", {}, {cpu8086, cpuPrivileged});	(* 475 *)

	Mnem ("HSUBPD");	(* 216 *)
	Instr (xmm, xmmmem128, none, "0F7D/r", {optPOP}, {cpuPrescott, cpuSSE3});	(* 476 *)

	Mnem ("HSUBPS");	(* 217 *)
	Instr (xmm, xmmmem128, none, "0F7D/r", {optPREPN}, {cpuPrescott, cpuSSE3});	(* 477 *)

	Mnem ("IDIV");	(* 218 *)
	Instr (regmem8, none, none, "F6/7", {}, {cpu8086});	(* 478 *)
	Instr (regmem16, none, none, "F7/7", {optO16}, {cpu8086});	(* 479 *)
	Instr (regmem32, none, none, "F7/7", {optO32}, {cpu386});	(* 480 *)
	Instr (regmem64, none, none, "F7/7", {}, {cpuAMD64});	(* 481 *)

	Mnem ("IMUL");	(* 219 *)
	Instr (regmem8, none, none, "F6/5", {}, {cpu8086});	(* 482 *)
	Instr (regmem16, none, none, "F7/5", {optO16}, {cpu8086});	(* 483 *)
	Instr (regmem32, none, none, "F7/5", {optO32}, {cpu386});	(* 484 *)
	Instr (regmem64, none, none, "F7/5", {}, {cpuAMD64});	(* 485 *)
	Instr (reg16, regmem16, none, "0FAF/r", {optO16}, {cpu386});	(* 486 *)
	Instr (reg32, regmem32, none, "0FAF/r", {optO32}, {cpu386});	(* 487 *)
	Instr (reg64, regmem64, none, "0FAF/r", {}, {cpuAMD64});	(* 488 *)
	Instr (reg16, regmem16, simm8, "6B/rib", {optO16}, {cpu186});	(* 489 *)
	Instr (reg16, regmem16, simm16, "69/riw", {optO16}, {cpu186});	(* 490 *)
	Instr (reg32, regmem32, simm8, "6B/rib", {optO32}, {cpu386});	(* 491 *)
	Instr (reg32, regmem32, simm32, "69/rid", {optO32}, {cpu386});	(* 492 *)
	Instr (reg64, regmem64, simm8, "6B/rib", {}, {cpuAMD64});	(* 493 *)
	Instr (reg64, regmem64, simm32, "69/rid", {}, {cpuAMD64});	(* 494 *)

	Mnem ("IN");	(* 220 *)
	Instr (AL, DX, none, "EC", {}, {cpu8086});	(* 495 *)
	Instr (AX, DX, none, "ED", {optO16}, {cpu8086});	(* 496 *)
	Instr (EAX, DX, none, "ED", {optO32}, {cpu386});	(* 497 *)
	Instr (AL, uimm8, none, "E4ib", {}, {cpu8086});	(* 498 *)
	Instr (AX, uimm8, none, "E5ib", {optO16}, {cpu8086});	(* 499 *)
	Instr (EAX, uimm8, none, "E5ib", {optO32}, {cpu386});	(* 500 *)

	Mnem ("INC");	(* 221 *)
	Instr (reg16, none, none, "40rw", {optO16, optI64}, {cpu8086});	(* 501 *)
	Instr (reg32, none, none, "40rd", {optO32, optI64}, {cpu386});	(* 502 *)
	Instr (regmem8, none, none, "FE/0", {}, {cpu8086});	(* 503 *)
	Instr (regmem16, none, none, "FF/0", {optO16}, {cpu8086});	(* 504 *)
	Instr (regmem32, none, none, "FF/0", {optO32}, {cpu386});	(* 505 *)
	Instr (regmem64, none, none, "FF/0", {}, {cpuAMD64});	(* 506 *)

	Mnem ("INS");	(* 222 *)
	Instr (mem8, DX, none, "6C", {}, {cpu186});	(* 507 *)
	Instr (mem16, DX, none, "6D", {optO16}, {cpu186});	(* 508 *)
	Instr (mem32, DX, none, "6D", {optO32}, {cpu386});	(* 509 *)

	Mnem ("INSB");	(* 223 *)
	Instr (none, none, none, "6C", {}, {cpu186});	(* 510 *)

	Mnem ("INSD");	(* 224 *)
	Instr (none, none, none, "6D", {optO32}, {cpu386});	(* 511 *)

	Mnem ("INSW");	(* 225 *)
	Instr (none, none, none, "6D", {optO16}, {cpu186});	(* 512 *)

	Mnem ("INT");	(* 226 *)
	Instr (three, none, none, "CC", {}, {cpu8086});	(* 513 *)
	Instr (uimm8, none, none, "CDib", {}, {cpu8086});	(* 514 *)

	Mnem ("INT3");	(* 227 *)
	Instr (none, none, none, "CC", {}, {cpu8086});	(* 515 *)

	Mnem ("INTO");	(* 228 *)
	Instr (none, none, none, "CE", {optI64}, {cpu8086});	(* 516 *)

	Mnem ("INVD");	(* 229 *)
	Instr (none, none, none, "0F08", {}, {cpu486, cpuPrivileged});	(* 517 *)

	Mnem ("INVLPG");	(* 230 *)
	Instr (mem8, none, none, "0F01/7", {}, {cpu486, cpuPrivileged});	(* 518 *)

	Mnem ("INVLPGA");	(* 231 *)
	Instr (rAX, ECX, none, "0F01DF", {}, {cpu386, cpuPrivileged});	(* 519 *)

	Mnem ("IRET");	(* 232 *)
	Instr (none, none, none, "CF", {optO16}, {cpu8086});	(* 520 *)

	Mnem ("IRETD");	(* 233 *)
	Instr (none, none, none, "CF", {optO32}, {cpu386});	(* 521 *)

	Mnem ("IRETQ");	(* 234 *)
	Instr (none, none, none, "CF", {optO64}, {cpuAMD64});	(* 522 *)

	Mnem ("JA");	(* 235 *)
	Instr (rel8off, none, none, "77cb", {}, {cpu8086});	(* 523 *)
	Instr (rel16off, none, none, "0F87cw", {}, {cpu386});	(* 524 *)
	Instr (rel32off, none, none, "0F87cd", {}, {cpu386});	(* 525 *)

	Mnem ("JAE");	(* 236 *)
	Instr (rel8off, none, none, "73cb", {}, {cpu8086});	(* 526 *)
	Instr (rel16off, none, none, "0F83cw", {}, {cpu386});	(* 527 *)
	Instr (rel32off, none, none, "0F83cd", {}, {cpu386});	(* 528 *)

	Mnem ("JB");	(* 237 *)
	Instr (rel8off, none, none, "72cb", {}, {cpu8086});	(* 529 *)
	Instr (rel16off, none, none, "0F82cw", {}, {cpu386});	(* 530 *)
	Instr (rel32off, none, none, "0F82cd", {}, {cpu386});	(* 531 *)

	Mnem ("JBE");	(* 238 *)
	Instr (rel8off, none, none, "76cb", {}, {cpu8086});	(* 532 *)
	Instr (rel16off, none, none, "0F86cw", {}, {cpu386});	(* 533 *)
	Instr (rel32off, none, none, "0F86cd", {}, {cpu386});	(* 534 *)

	Mnem ("JC");	(* 239 *)
	Instr (rel8off, none, none, "72cb", {}, {cpu8086});	(* 535 *)
	Instr (rel16off, none, none, "0F82cw", {}, {cpu386});	(* 536 *)
	Instr (rel32off, none, none, "0F82cd", {}, {cpu386});	(* 537 *)

	Mnem ("JCXZ");	(* 240 *)
	Instr (rel8off, none, none, "E3cb", {optA16}, {cpu8086});	(* 538 *)

	Mnem ("JE");	(* 241 *)
	Instr (rel8off, none, none, "74cb", {}, {cpu8086});	(* 539 *)
	Instr (rel16off, none, none, "0F84cw", {}, {cpu386});	(* 540 *)
	Instr (rel32off, none, none, "0F84cd", {}, {cpu386});	(* 541 *)

	Mnem ("JECXZ");	(* 242 *)
	Instr (rel8off, none, none, "E3cb", {optA32}, {cpu386});	(* 542 *)

	Mnem ("JG");	(* 243 *)
	Instr (rel8off, none, none, "7Fcb", {}, {cpu8086});	(* 543 *)
	Instr (rel16off, none, none, "0F8Fcw", {}, {cpu386});	(* 544 *)
	Instr (rel32off, none, none, "0F8Fcd", {}, {cpu386});	(* 545 *)

	Mnem ("JGE");	(* 244 *)
	Instr (rel8off, none, none, "7Dcb", {}, {cpu8086});	(* 546 *)
	Instr (rel16off, none, none, "0F8Dcw", {}, {cpu386});	(* 547 *)
	Instr (rel32off, none, none, "0F8Dcd", {}, {cpu386});	(* 548 *)

	Mnem ("JL");	(* 245 *)
	Instr (rel8off, none, none, "7Ccb", {}, {cpu8086});	(* 549 *)
	Instr (rel16off, none, none, "0F8Ccw", {}, {cpu386});	(* 550 *)
	Instr (rel32off, none, none, "0F8Ccd", {}, {cpu386});	(* 551 *)

	Mnem ("JLE");	(* 246 *)
	Instr (rel8off, none, none, "7Ecb", {}, {cpu8086});	(* 552 *)
	Instr (rel16off, none, none, "0F8Ecw", {}, {cpu386});	(* 553 *)
	Instr (rel32off, none, none, "0F8Ecd", {}, {cpu386});	(* 554 *)

	Mnem ("JMP");	(* 247 *)
	Instr (rel8off, none, none, "EBcb", {}, {cpu8086});	(* 555 *)
	Instr (rel16off, none, none, "E9cw", {}, {cpu8086});	(* 556 *)
	Instr (rel32off, none, none, "E9cd", {}, {cpu8086});	(* 557 *)
	Instr (regmem16, none, none, "FF/4", {optO16}, {cpu8086});	(* 558 *)
	Instr (regmem32, none, none, "FF/4", {optO32}, {cpu386});	(* 559 *)
	Instr (regmem64, none, none, "FF/4", {}, {cpuAMD64});	(* 560 *)
	Instr (mem, none, none, "FF/5", {optO16}, {cpu8086});	(* 561 *)
	Instr (mem, none, none, "FF/5", {optO32}, {cpu386});	(* 562 *)
	Instr (imm16, imm16, none, "EAiwiw", {optO16, optI64}, {cpu8086});	(* 563 *)
	Instr (imm16, imm32, none, "EAidiw", {optO32, optI64}, {cpu386});	(* 564 *)

	Mnem ("JNA");	(* 248 *)
	Instr (rel8off, none, none, "76cb", {}, {cpu8086});	(* 565 *)
	Instr (rel16off, none, none, "0F86cw", {}, {cpu386});	(* 566 *)
	Instr (rel32off, none, none, "0F86cd", {}, {cpu386});	(* 567 *)

	Mnem ("JNAE");	(* 249 *)
	Instr (rel8off, none, none, "72cb", {}, {cpu8086});	(* 568 *)
	Instr (rel16off, none, none, "0F82cw", {}, {cpu386});	(* 569 *)
	Instr (rel32off, none, none, "0F82cd", {}, {cpu386});	(* 570 *)

	Mnem ("JNB");	(* 250 *)
	Instr (rel8off, none, none, "73cb", {}, {cpu8086});	(* 571 *)
	Instr (rel16off, none, none, "0F83cw", {}, {cpu386});	(* 572 *)
	Instr (rel32off, none, none, "0F83cd", {}, {cpu386});	(* 573 *)

	Mnem ("JNBE");	(* 251 *)
	Instr (rel8off, none, none, "77cb", {}, {cpu8086});	(* 574 *)
	Instr (rel16off, none, none, "0F87cw", {}, {cpu386});	(* 575 *)
	Instr (rel32off, none, none, "0F87cd", {}, {cpu386});	(* 576 *)

	Mnem ("JNC");	(* 252 *)
	Instr (rel8off, none, none, "73cb", {}, {cpu8086});	(* 577 *)
	Instr (rel16off, none, none, "0F83cw", {}, {cpu386});	(* 578 *)
	Instr (rel32off, none, none, "0F83cd", {}, {cpu386});	(* 579 *)

	Mnem ("JNE");	(* 253 *)
	Instr (rel8off, none, none, "75cb", {}, {cpu8086});	(* 580 *)
	Instr (rel16off, none, none, "0F85cw", {}, {cpu386});	(* 581 *)
	Instr (rel32off, none, none, "0F85cd", {}, {cpu386});	(* 582 *)

	Mnem ("JNG");	(* 254 *)
	Instr (rel8off, none, none, "7Ecb", {}, {cpu8086});	(* 583 *)
	Instr (rel16off, none, none, "0F8Ecw", {}, {cpu386});	(* 584 *)
	Instr (rel32off, none, none, "0F8Ecd", {}, {cpu386});	(* 585 *)

	Mnem ("JNGE");	(* 255 *)
	Instr (rel8off, none, none, "7Ccb", {}, {cpu8086});	(* 586 *)
	Instr (rel16off, none, none, "0F8Ccw", {}, {cpu386});	(* 587 *)
	Instr (rel32off, none, none, "0F8Ccd", {}, {cpu386});	(* 588 *)

	Mnem ("JNL");	(* 256 *)
	Instr (rel8off, none, none, "7Dcb", {}, {cpu8086});	(* 589 *)
	Instr (rel16off, none, none, "0F8Dcw", {}, {cpu386});	(* 590 *)
	Instr (rel32off, none, none, "0F8Dcd", {}, {cpu386});	(* 591 *)

	Mnem ("JNLE");	(* 257 *)
	Instr (rel8off, none, none, "7Fcb", {}, {cpu8086});	(* 592 *)
	Instr (rel16off, none, none, "0F8Fcw", {}, {cpu386});	(* 593 *)
	Instr (rel32off, none, none, "0F8Fcd", {}, {cpu386});	(* 594 *)

	Mnem ("JNO");	(* 258 *)
	Instr (rel8off, none, none, "71cb", {}, {cpu8086});	(* 595 *)
	Instr (rel16off, none, none, "0F81cw", {}, {cpu386});	(* 596 *)
	Instr (rel32off, none, none, "0F81cd", {}, {cpu386});	(* 597 *)

	Mnem ("JNP");	(* 259 *)
	Instr (rel8off, none, none, "7Bcb", {}, {cpu8086});	(* 598 *)
	Instr (rel16off, none, none, "0F8Bcw", {}, {cpu386});	(* 599 *)
	Instr (rel32off, none, none, "0F8Bcd", {}, {cpu386});	(* 600 *)

	Mnem ("JNS");	(* 260 *)
	Instr (rel8off, none, none, "79cb", {}, {cpu8086});	(* 601 *)
	Instr (rel16off, none, none, "0F89cw", {}, {cpu386});	(* 602 *)
	Instr (rel32off, none, none, "0F89cd", {}, {cpu386});	(* 603 *)

	Mnem ("JNZ");	(* 261 *)
	Instr (rel8off, none, none, "75cb", {}, {cpu8086});	(* 604 *)
	Instr (rel16off, none, none, "0F85cw", {}, {cpu386});	(* 605 *)
	Instr (rel32off, none, none, "0F85cd", {}, {cpu386});	(* 606 *)

	Mnem ("JO");	(* 262 *)
	Instr (rel8off, none, none, "70cb", {}, {cpu8086});	(* 607 *)
	Instr (rel16off, none, none, "0F80cw", {}, {cpu386});	(* 608 *)
	Instr (rel32off, none, none, "0F80cd", {}, {cpu386});	(* 609 *)

	Mnem ("JP");	(* 263 *)
	Instr (rel8off, none, none, "7Acb", {}, {cpu8086});	(* 610 *)
	Instr (rel16off, none, none, "0F8Acw", {}, {cpu386});	(* 611 *)
	Instr (rel32off, none, none, "0F8Acd", {}, {cpu386});	(* 612 *)

	Mnem ("JPE");	(* 264 *)
	Instr (rel8off, none, none, "7Acb", {}, {cpu8086});	(* 613 *)
	Instr (rel16off, none, none, "0F8Acw", {}, {cpu386});	(* 614 *)
	Instr (rel32off, none, none, "0F8Acd", {}, {cpu386});	(* 615 *)

	Mnem ("JPO");	(* 265 *)
	Instr (rel8off, none, none, "7Bcb", {}, {cpu8086});	(* 616 *)
	Instr (rel16off, none, none, "0F8Bcw", {}, {cpu386});	(* 617 *)
	Instr (rel32off, none, none, "0F8Bcd", {}, {cpu386});	(* 618 *)

	Mnem ("JRCXZ");	(* 266 *)
	Instr (rel8off, none, none, "E3cb", {}, {cpuAMD64});	(* 619 *)

	Mnem ("JS");	(* 267 *)
	Instr (rel8off, none, none, "78cb", {}, {cpu8086});	(* 620 *)
	Instr (rel16off, none, none, "0F88cw", {}, {cpu386});	(* 621 *)
	Instr (rel32off, none, none, "0F88cd", {}, {cpu386});	(* 622 *)

	Mnem ("JZ");	(* 268 *)
	Instr (rel8off, none, none, "74cb", {}, {cpu8086});	(* 623 *)
	Instr (rel16off, none, none, "0F84cw", {}, {cpu386});	(* 624 *)
	Instr (rel32off, none, none, "0F84cd", {}, {cpu386});	(* 625 *)

	Mnem ("LAHF");	(* 269 *)
	Instr (none, none, none, "9F", {}, {cpu8086});	(* 626 *)

	Mnem ("LAR");	(* 270 *)
	Instr (reg16, regmem16, none, "0F02/r", {optO16}, {cpu286, cpuPrivileged});	(* 627 *)
	Instr (reg32, regmem16, none, "0F02/r", {optO32}, {cpu286, cpuPrivileged});	(* 628 *)
	Instr (reg64, regmem16, none, "0F02/r", {}, {cpuAMD64, cpuPrivileged});	(* 629 *)

	Mnem ("LDDQU");	(* 271 *)
	Instr (xmm, mem128, none, "0FF0/r", {optPREPN}, {cpuPrescott, cpuSSE3});	(* 630 *)

	Mnem ("LDMXCSR");	(* 272 *)
	Instr (mem32, none, none, "0FAE/2", {}, {cpuKatmai, cpuSSE});	(* 631 *)

	Mnem ("LDS");	(* 273 *)
	Instr (reg16, mem, none, "C5/r", {optO16, optI64}, {cpu8086});	(* 632 *)
	Instr (reg32, mem, none, "C5/r", {optO32, optI64}, {cpu386});	(* 633 *)

	Mnem ("LEA");	(* 274 *)
	Instr (reg16, mem, none, "8D/r", {optO16}, {cpu8086});	(* 634 *)
	Instr (reg32, mem, none, "8D/r", {optO32}, {cpu386});	(* 635 *)
	Instr (reg64, mem, none, "8D/r", {}, {cpuAMD64});	(* 636 *)

	Mnem ("LEAVE");	(* 275 *)
	Instr (none, none, none, "C9", {}, {cpu186});	(* 637 *)

	Mnem ("LES");	(* 276 *)
	Instr (reg16, mem, none, "C4/r", {optO16, optI64}, {cpu8086});	(* 638 *)
	Instr (reg32, mem, none, "C4/r", {optO32, optI64}, {cpu386});	(* 639 *)

	Mnem ("LFENCE");	(* 277 *)
	Instr (none, none, none, "0FAEE8", {}, {cpuWillamette, cpuSSE2});	(* 640 *)

	Mnem ("LFS");	(* 278 *)
	Instr (reg16, mem, none, "0FB4/r", {optO16}, {cpu386});	(* 641 *)
	Instr (reg32, mem, none, "0FB4/r", {optO32}, {cpu386});	(* 642 *)

	Mnem ("LGDT");	(* 279 *)
	Instr (mem, none, none, "0F01/2", {}, {cpu286, cpuPrivileged});	(* 643 *)
	Instr (mem, none, none, "0F01/2", {}, {cpuAMD64, cpuPrivileged});	(* 644 *)

	Mnem ("LGS");	(* 280 *)
	Instr (reg16, mem, none, "0FB5/r", {optO16}, {cpu386});	(* 645 *)
	Instr (reg32, mem, none, "0FB5/r", {optO32}, {cpu386});	(* 646 *)

	Mnem ("LIDT");	(* 281 *)
	Instr (mem, none, none, "0F01/3", {}, {cpu286, cpuPrivileged});	(* 647 *)
	Instr (mem, none, none, "0F01/3", {}, {cpuAMD64, cpuPrivileged});	(* 648 *)

	Mnem ("LLDT");	(* 282 *)
	Instr (regmem16, none, none, "0F00/2", {}, {cpu286, cpuPrivileged});	(* 649 *)

	Mnem ("LMSW");	(* 283 *)
	Instr (regmem16, none, none, "0F01/6", {}, {cpu286, cpuPrivileged});	(* 650 *)

	Mnem ("LODS");	(* 284 *)
	Instr (mem8, none, none, "AC", {}, {cpu8086});	(* 651 *)
	Instr (mem16, none, none, "AD", {optO16}, {cpu8086});	(* 652 *)
	Instr (mem32, none, none, "AD", {optO32}, {cpu386});	(* 653 *)
	Instr (mem64, none, none, "AD", {}, {cpuAMD64});	(* 654 *)

	Mnem ("LODSB");	(* 285 *)
	Instr (none, none, none, "AC", {}, {cpu8086});	(* 655 *)

	Mnem ("LODSD");	(* 286 *)
	Instr (none, none, none, "AD", {optO32}, {cpu386});	(* 656 *)

	Mnem ("LODSQ");	(* 287 *)
	Instr (none, none, none, "AD", {optO64}, {cpuAMD64});	(* 657 *)

	Mnem ("LODSW");	(* 288 *)
	Instr (none, none, none, "AD", {optO16}, {cpu8086});	(* 658 *)

	Mnem ("LOOP");	(* 289 *)
	Instr (rel8off, none, none, "E2cb", {}, {cpu8086});	(* 659 *)

	Mnem ("LOOPE");	(* 290 *)
	Instr (rel8off, none, none, "E1cb", {}, {cpu8086});	(* 660 *)

	Mnem ("LOOPNE");	(* 291 *)
	Instr (rel8off, none, none, "E0cb", {}, {cpu8086});	(* 661 *)

	Mnem ("LOOPNZ");	(* 292 *)
	Instr (rel8off, none, none, "E0cb", {}, {cpu8086});	(* 662 *)

	Mnem ("LOOPZ");	(* 293 *)
	Instr (rel8off, none, none, "E1cb", {}, {cpu8086});	(* 663 *)

	Mnem ("LSL");	(* 294 *)
	Instr (reg16, regmem16, none, "0F03/r", {}, {cpu286, cpuPrivileged});	(* 664 *)
	Instr (reg32, regmem16, none, "0F03/r", {}, {cpu286, cpuPrivileged});	(* 665 *)
	Instr (reg64, regmem16, none, "0F03/r", {}, {cpuAMD64, cpuPrivileged});	(* 666 *)

	Mnem ("LSS");	(* 295 *)
	Instr (reg16, mem, none, "0FB2/r", {optO16}, {cpu386});	(* 667 *)
	Instr (reg32, mem, none, "0FB2/r", {optO32}, {cpu386});	(* 668 *)

	Mnem ("LTR");	(* 296 *)
	Instr (regmem16, none, none, "0F00/3", {}, {cpu286, cpuPrivileged});	(* 669 *)

	Mnem ("MASKMOVDQU");	(* 297 *)
	Instr (xmm, xmm, none, "0FF7/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 670 *)

	Mnem ("MASKMOVQ");	(* 298 *)
	Instr (mmx, mmx, none, "0FF7/r", {}, {cpuKatmai, cpuMMX});	(* 671 *)

	Mnem ("MAXPD");	(* 299 *)
	Instr (xmm, xmmmem128, none, "0F5F/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 672 *)

	Mnem ("MAXPS");	(* 300 *)
	Instr (xmm, xmmmem128, none, "0F5F/r", {}, {cpuKatmai, cpuSSE});	(* 673 *)

	Mnem ("MAXSD");	(* 301 *)
	Instr (xmm, xmmmem64, none, "0F5F/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 674 *)

	Mnem ("MAXSS");	(* 302 *)
	Instr (xmm, xmmmem32, none, "0F5F/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 675 *)

	Mnem ("MFENCE");	(* 303 *)
	Instr (none, none, none, "0FAEF0", {}, {cpuWillamette, cpuSSE2});	(* 676 *)

	Mnem ("MINPD");	(* 304 *)
	Instr (xmm, xmmmem128, none, "0F5D/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 677 *)

	Mnem ("MINPS");	(* 305 *)
	Instr (xmm, xmmmem128, none, "0F5D/r", {}, {cpuKatmai, cpuSSE});	(* 678 *)

	Mnem ("MINSD");	(* 306 *)
	Instr (xmm, xmmmem64, none, "0F5D/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 679 *)

	Mnem ("MINSS");	(* 307 *)
	Instr (xmm, xmmmem32, none, "0F5D/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 680 *)

	Mnem ("MOV");	(* 308 *)
	Instr (AL, moffset8, none, "A0+o", {}, {cpu8086});	(* 681 *)
	Instr (RAX, moffset64, none, "A1+o", {}, {cpuAMD64});	(* 682 *)
	Instr (reg8, imm8, none, "B0rbib", {}, {cpu8086});	(* 683 *)
	Instr (moffset8, AL, none, "A2+o", {}, {cpu8086});	(* 684 *)
	Instr (moffset16, AX, none, "A3+o", {optO16}, {cpu8086});	(* 685 *)
	Instr (reg16, imm16, none, "B8rwiw", {optO16}, {cpu8086});	(* 686 *)
	Instr (reg32, imm32, none, "B8rdid", {optO32}, {cpu386});	(* 687 *)
	Instr (moffset32, EAX, none, "A3+o", {optO32}, {cpu386});	(* 688 *)
	Instr (moffset64, RAX, none, "A3+o", {}, {cpuAMD64});	(* 689 *)
	Instr (AX, moffset16, none, "A1+o", {optO16}, {cpu8086});	(* 690 *)
	Instr (EAX, moffset32, none, "A1+o", {optO32}, {cpu386});	(* 691 *)
	Instr (regmem16, reg16, none, "89/r", {optO16}, {cpu8086});	(* 692 *)
	Instr (regmem16, segReg, none, "8C/r", {optO16}, {cpu8086});	(* 693 *)
	Instr (regmem32, reg32, none, "89/r", {optO32}, {cpu386});	(* 694 *)
	Instr (regmem32, segReg, none, "8C/r", {optO32}, {cpu386});	(* 695 *)
	Instr (regmem64, reg64, none, "89/r", {}, {cpuAMD64});	(* 696 *)
	Instr (segReg, regmem16, none, "8E/r", {}, {cpu8086});	(* 697 *)
	Instr (regmem8, reg8, none, "88/r", {}, {cpu8086});	(* 698 *)
	Instr (regmem64, segReg, none, "8C/r", {}, {cpuAMD64});	(* 699 *)
	Instr (reg8, regmem8, none, "8A/r", {}, {cpu8086});	(* 700 *)
	Instr (reg16, regmem16, none, "8B/r", {optO16}, {cpu8086});	(* 701 *)
	Instr (reg32, regmem32, none, "8B/r", {optO32}, {cpu386});	(* 702 *)
	Instr (reg64, regmem64, none, "8B/r", {}, {cpuAMD64});	(* 703 *)
	Instr (reg32, CRn, none, "0F20/r", {}, {cpu386});	(* 704 *)
	Instr (reg32, CR8, none, "0F20/r", {optPLOCK}, {cpu386});	(* 705 *)
	Instr (reg32, DRn, none, "0F21/r", {}, {cpu386});	(* 706 *)
	Instr (reg64, CRn, none, "0F20/r", {optD64}, {cpuAMD64});	(* 707 *)
	Instr (reg64, CR8, none, "0F20/r", {optD64, optPLOCK}, {cpuAMD64});	(* 708 *)
	Instr (reg64, DRn, none, "0F21/r", {optD64}, {cpuAMD64});	(* 709 *)
	Instr (CRn, reg32, none, "0F22/r", {}, {cpu386});	(* 710 *)
	Instr (CRn, reg64, none, "0F22/r", {optD64}, {cpuAMD64});	(* 711 *)
	Instr (CR8, reg32, none, "0F22/r", {optPLOCK}, {cpu386});	(* 712 *)
	Instr (CR8, reg64, none, "0F22/r", {optD64, optPLOCK}, {cpuAMD64});	(* 713 *)
	Instr (DRn, reg32, none, "0F23/r", {}, {cpu386});	(* 714 *)
	Instr (DRn, reg64, none, "0F23/r", {optD64}, {cpuAMD64});	(* 715 *)
	Instr (regmem8, imm8, none, "C6/0ib", {}, {cpu8086});	(* 716 *)
	Instr (regmem16, imm16, none, "C7/0iw", {optO16}, {cpu8086});	(* 717 *)
	Instr (regmem32, imm32, none, "C7/0id", {optO32}, {cpu386});	(* 718 *)
	Instr (regmem64, imm32, none, "C7/0id", {}, {cpuAMD64});	(* 719 *)
	Instr (reg64, imm64, none, "B8rqiq", {}, {cpuAMD64});	(* 720 *)

	Mnem ("MOVAPD");	(* 309 *)
	Instr (xmm, xmmmem128, none, "0F28/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 721 *)
	Instr (xmmmem128, xmm, none, "0F29/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 722 *)

	Mnem ("MOVAPS");	(* 310 *)
	Instr (xmm, xmmmem128, none, "0F28/r", {}, {cpuKatmai, cpuSSE});	(* 723 *)
	Instr (xmmmem128, xmm, none, "0F29/r", {}, {cpuKatmai, cpuSSE});	(* 724 *)

	Mnem ("MOVD");	(* 311 *)
	Instr (xmm, regmem32, none, "0F6E/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 725 *)
	Instr (xmm, regmem64, none, "0F6E/r", {optPOP}, {cpuAMD64, cpuSSE2});	(* 726 *)
	Instr (regmem32, xmm, none, "0F7E/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 727 *)
	Instr (regmem64, xmm, none, "0F7E/r", {optPOP}, {cpuAMD64, cpuSSE2});	(* 728 *)
	Instr (mmx, regmem32, none, "0F6E/r", {}, {cpuPentium, cpuMMX});	(* 729 *)
	Instr (mmx, regmem64, none, "0F6E/r", {}, {cpuAMD64, cpuMMX});	(* 730 *)
	Instr (regmem32, mmx, none, "0F7E/r", {}, {cpuPentium, cpuMMX});	(* 731 *)
	Instr (regmem64, mmx, none, "0F7E/r", {}, {cpuAMD64, cpuMMX});	(* 732 *)
	Instr (xmm, regmem32, none, "0F6E/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 733 *)
	Instr (xmm, regmem64, none, "0F6E/r", {optPOP}, {cpuAMD64, cpuSSE2});	(* 734 *)
	Instr (regmem32, xmm, none, "0F7E/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 735 *)
	Instr (regmem64, xmm, none, "0F7E/r", {optPOP}, {cpuAMD64, cpuSSE2});	(* 736 *)
	Instr (mmx, regmem32, none, "0F6E/r", {}, {cpuPentium, cpuMMX});	(* 737 *)
	Instr (mmx, regmem64, none, "0F6E/r", {}, {cpuAMD64, cpuMMX});	(* 738 *)
	Instr (regmem32, mmx, none, "0F7E/r", {}, {cpuPentium, cpuMMX});	(* 739 *)
	Instr (regmem64, mmx, none, "0F7E/r", {}, {cpuAMD64, cpuMMX});	(* 740 *)

	Mnem ("MOVDDUP");	(* 312 *)
	Instr (xmm, xmmmem64, none, "0F12/r", {optPREPN}, {cpuPrescott, cpuSSE3});	(* 741 *)

	Mnem ("MOVDQ2Q");	(* 313 *)
	Instr (mmx, xmm, none, "0FD6/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 742 *)
	Instr (mmx, xmm, none, "0FD6/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 743 *)

	Mnem ("MOVDQA");	(* 314 *)
	Instr (xmm, xmmmem128, none, "0F6F/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 744 *)
	Instr (xmmmem128, xmm, none, "0F7F/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 745 *)

	Mnem ("MOVDQU");	(* 315 *)
	Instr (xmm, xmmmem128, none, "0F6F/r", {optPREP}, {cpuWillamette, cpuSSE2});	(* 746 *)
	Instr (xmmmem128, xmm, none, "0F7F/r", {optPREP}, {cpuWillamette, cpuSSE2});	(* 747 *)

	Mnem ("MOVHLPS");	(* 316 *)
	Instr (xmm, xmm, none, "0F12/r", {}, {cpuKatmai, cpuSSE});	(* 748 *)

	Mnem ("MOVHPD");	(* 317 *)
	Instr (xmm, mem64, none, "0F16/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 749 *)
	Instr (mem64, xmm, none, "0F17/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 750 *)

	Mnem ("MOVHPS");	(* 318 *)
	Instr (xmm, mem64, none, "0F16/r", {}, {cpuKatmai, cpuSSE});	(* 751 *)
	Instr (mem64, xmm, none, "0F17/r", {}, {cpuKatmai, cpuSSE});	(* 752 *)

	Mnem ("MOVLHPS");	(* 319 *)
	Instr (xmm, xmm, none, "0F16/r", {}, {cpuKatmai, cpuSSE});	(* 753 *)

	Mnem ("MOVLPD");	(* 320 *)
	Instr (xmm, mem64, none, "0F12/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 754 *)
	Instr (mem64, xmm, none, "0F13/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 755 *)

	Mnem ("MOVLPS");	(* 321 *)
	Instr (xmm, mem64, none, "0F12/r", {}, {cpuKatmai, cpuSSE});	(* 756 *)
	Instr (mem64, xmm, none, "0F13/r", {}, {cpuKatmai, cpuSSE});	(* 757 *)

	Mnem ("MOVMSKPD");	(* 322 *)
	Instr (reg32, xmm, none, "0F50/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 758 *)

	Mnem ("MOVMSKPS");	(* 323 *)
	Instr (reg32, xmm, none, "0F50/r", {}, {cpuKatmai, cpuSSE});	(* 759 *)
	Instr (reg32, xmm, none, "0F50/r", {}, {cpuKatmai, cpuSSE});	(* 760 *)

	Mnem ("MOVNTDQ");	(* 324 *)
	Instr (mem128, xmm, none, "0FE7/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 761 *)

	Mnem ("MOVNTI");	(* 325 *)
	Instr (mem32, reg32, none, "0FC3/r", {}, {cpuWillamette, cpuSSE2});	(* 762 *)
	Instr (mem64, reg64, none, "0FC3/r", {}, {cpuAMD64, cpuSSE2});	(* 763 *)

	Mnem ("MOVNTPD");	(* 326 *)
	Instr (mem128, xmm, none, "0F2B/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 764 *)

	Mnem ("MOVNTPS");	(* 327 *)
	Instr (mem128, xmm, none, "0F2B/r", {}, {cpuKatmai, cpuSSE});	(* 765 *)

	Mnem ("MOVNTQ");	(* 328 *)
	Instr (mem64, mmx, none, "0FE7/r", {}, {cpuKatmai, cpuMMX});	(* 766 *)

	Mnem ("MOVQ");	(* 329 *)
	Instr (xmm, xmmmem64, none, "0F7E/r", {optPREP}, {cpuWillamette, cpuSSE2});	(* 767 *)
	Instr (xmmmem64, xmm, none, "0FD6/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 768 *)
	Instr (mmx, mmxmem64, none, "0F6F/r", {}, {cpuPentium, cpuMMX});	(* 769 *)
	Instr (mmxmem64, mmx, none, "0F7F/r", {}, {cpuPentium, cpuMMX});	(* 770 *)

	Mnem ("MOVQ2DQ");	(* 330 *)
	Instr (xmm, mmx, none, "0FD6/r", {optPREP}, {cpuWillamette, cpuSSE2});	(* 771 *)
	Instr (xmm, mmx, none, "0FD6/r", {optPREP}, {cpuWillamette, cpuSSE2});	(* 772 *)

	Mnem ("MOVS");	(* 331 *)
	Instr (mem8, mem8, none, "A4", {}, {cpu8086});	(* 773 *)
	Instr (mem16, mem16, none, "A5", {optO16}, {cpu8086});	(* 774 *)
	Instr (mem32, mem32, none, "A5", {optO32}, {cpu386});	(* 775 *)
	Instr (mem64, mem64, none, "A5", {}, {cpuAMD64});	(* 776 *)

	Mnem ("MOVSB");	(* 332 *)
	Instr (none, none, none, "A4", {}, {cpu8086});	(* 777 *)

	Mnem ("MOVSD");	(* 333 *)
	Instr (none, none, none, "A5", {optO32}, {cpu386});	(* 778 *)
	Instr (xmm, xmmmem64, none, "0F10/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 779 *)
	Instr (xmmmem64, xmm, none, "0F11/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 780 *)

	Mnem ("MOVSHDUP");	(* 334 *)
	Instr (xmm, xmmmem128, none, "0F16/r", {optPREP}, {cpuPrescott, cpuSSE3});	(* 781 *)

	Mnem ("MOVSLDUP");	(* 335 *)
	Instr (xmm, xmmmem128, none, "0F12/r", {optPREP}, {cpuPrescott, cpuSSE3});	(* 782 *)

	Mnem ("MOVSQ");	(* 336 *)
	Instr (none, none, none, "A5", {optO64}, {cpuAMD64});	(* 783 *)

	Mnem ("MOVSS");	(* 337 *)
	Instr (xmm, xmmmem32, none, "0F10/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 784 *)
	Instr (xmmmem32, xmm, none, "0F11/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 785 *)

	Mnem ("MOVSW");	(* 338 *)
	Instr (none, none, none, "A5", {optO16}, {cpu8086});	(* 786 *)

	Mnem ("MOVSX");	(* 339 *)
	Instr (reg16, regmem8, none, "0FBE/r", {optO16}, {cpu386});	(* 787 *)
	Instr (reg32, regmem8, none, "0FBE/r", {optO32}, {cpu386});	(* 788 *)
	Instr (reg32, regmem16, none, "0FBF/r", {optO32}, {cpu386});	(* 789 *)
	Instr (reg64, regmem8, none, "0FBE/r", {}, {cpuAMD64});	(* 790 *)
	Instr (reg64, regmem16, none, "0FBF/r", {}, {cpuAMD64});	(* 791 *)

	Mnem ("MOVSXD");	(* 340 *)
	Instr (reg64, regmem32, none, "63/r", {}, {cpuAMD64});	(* 792 *)

	Mnem ("MOVUPD");	(* 341 *)
	Instr (xmm, xmmmem128, none, "0F10/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 793 *)
	Instr (xmmmem128, xmm, none, "0F11/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 794 *)

	Mnem ("MOVUPS");	(* 342 *)
	Instr (xmm, xmmmem128, none, "0F10/r", {}, {cpuKatmai, cpuSSE});	(* 795 *)
	Instr (xmmmem128, xmm, none, "0F11/r", {}, {cpuKatmai, cpuSSE});	(* 796 *)

	Mnem ("MOVZX");	(* 343 *)
	Instr (reg16, regmem8, none, "0FB6/r", {optO16}, {cpu386});	(* 797 *)
	Instr (reg32, regmem8, none, "0FB6/r", {optO32}, {cpu386});	(* 798 *)
	Instr (reg32, regmem16, none, "0FB7/r", {optO32}, {cpu386});	(* 799 *)
	Instr (reg64, regmem8, none, "0FB6/r", {}, {cpuAMD64});	(* 800 *)
	Instr (reg64, regmem16, none, "0FB7/r", {}, {cpuAMD64});	(* 801 *)

	Mnem ("MUL");	(* 344 *)
	Instr (regmem8, none, none, "F6/4", {}, {cpu8086});	(* 802 *)
	Instr (regmem16, none, none, "F7/4", {optO16}, {cpu8086});	(* 803 *)
	Instr (regmem32, none, none, "F7/4", {optO32}, {cpu386});	(* 804 *)
	Instr (regmem64, none, none, "F7/4", {}, {cpuAMD64});	(* 805 *)

	Mnem ("MULPD");	(* 345 *)
	Instr (xmm, xmmmem128, none, "0F59/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 806 *)

	Mnem ("MULPS");	(* 346 *)
	Instr (xmm, xmmmem128, none, "0F59/r", {}, {cpuKatmai, cpuSSE});	(* 807 *)

	Mnem ("MULSD");	(* 347 *)
	Instr (xmm, xmmmem64, none, "0F59/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 808 *)

	Mnem ("MULSS");	(* 348 *)
	Instr (xmm, xmmmem32, none, "0F59/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 809 *)

	Mnem ("NEG");	(* 349 *)
	Instr (regmem8, none, none, "F6/3", {}, {cpu8086});	(* 810 *)
	Instr (regmem16, none, none, "F7/3", {optO16}, {cpu8086});	(* 811 *)
	Instr (regmem32, none, none, "F7/3", {optO32}, {cpu386});	(* 812 *)
	Instr (regmem64, none, none, "F7/3", {}, {cpuAMD64});	(* 813 *)

	Mnem ("NOP");	(* 350 *)
	Instr (none, none, none, "90", {}, {cpu8086});	(* 814 *)

	Mnem ("NOT");	(* 351 *)
	Instr (regmem8, none, none, "F6/2", {}, {cpu8086});	(* 815 *)
	Instr (regmem16, none, none, "F7/2", {optO16}, {cpu8086});	(* 816 *)
	Instr (regmem32, none, none, "F7/2", {optO32}, {cpu386});	(* 817 *)
	Instr (regmem64, none, none, "F7/2", {}, {cpuAMD64});	(* 818 *)

	Mnem ("OR");	(* 352 *)
	Instr (AL, imm8, none, "0Cib", {}, {cpu8086});	(* 819 *)
	Instr (AX, imm16, none, "0Diw", {optO16}, {cpu8086});	(* 820 *)
	Instr (EAX, imm32, none, "0Did", {optO32}, {cpu386});	(* 821 *)
	Instr (RAX, imm32, none, "0Did", {}, {cpuAMD64});	(* 822 *)
	Instr (regmem8, reg8, none, "08/r", {}, {cpu8086});	(* 823 *)
	Instr (regmem16, reg16, none, "09/r", {optO16}, {cpu8086});	(* 824 *)
	Instr (regmem32, reg32, none, "09/r", {optO32}, {cpu386});	(* 825 *)
	Instr (regmem64, reg64, none, "09/r", {}, {cpuAMD64});	(* 826 *)
	Instr (reg8, regmem8, none, "0A/r", {}, {cpu8086});	(* 827 *)
	Instr (reg16, regmem16, none, "0B/r", {optO16}, {cpu8086});	(* 828 *)
	Instr (reg32, regmem32, none, "0B/r", {optO32}, {cpu386});	(* 829 *)
	Instr (reg64, regmem64, none, "0B/r", {}, {cpuAMD64});	(* 830 *)
	Instr (regmem8, imm8, none, "80/1ib", {}, {cpu8086});	(* 831 *)
	Instr (regmem16, simm8, none, "83/1ib", {optO16}, {cpu8086});	(* 832 *)
	Instr (regmem16, imm16, none, "81/1iw", {optO16}, {cpu8086});	(* 833 *)
	Instr (regmem32, simm8, none, "83/1ib", {optO32}, {cpu386});	(* 834 *)
	Instr (regmem32, imm32, none, "81/1id", {optO32}, {cpu386});	(* 835 *)
	Instr (regmem64, simm8, none, "83/1ib", {}, {cpuAMD64});	(* 836 *)
	Instr (regmem64, imm32, none, "81/1id", {}, {cpuAMD64});	(* 837 *)

	Mnem ("ORPD");	(* 353 *)
	Instr (xmm, xmmmem128, none, "0F56/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 838 *)

	Mnem ("ORPS");	(* 354 *)
	Instr (xmm, xmmmem128, none, "0F56/r", {}, {cpuKatmai, cpuSSE});	(* 839 *)

	Mnem ("OUT");	(* 355 *)
	Instr (DX, AL, none, "EE", {}, {cpu8086});	(* 840 *)
	Instr (DX, AX, none, "EF", {optO16}, {cpu8086});	(* 841 *)
	Instr (DX, EAX, none, "EF", {optO32}, {cpu386});	(* 842 *)
	Instr (uimm8, AL, none, "E6ib", {}, {cpu8086});	(* 843 *)
	Instr (uimm8, AX, none, "E7ib", {optO16}, {cpu8086});	(* 844 *)
	Instr (uimm8, EAX, none, "E7ib", {optO32}, {cpu386});	(* 845 *)

	Mnem ("OUTS");	(* 356 *)
	Instr (DX, mem8, none, "6E", {}, {cpu186});	(* 846 *)
	Instr (DX, mem16, none, "6F", {optO16}, {cpu186});	(* 847 *)
	Instr (DX, mem32, none, "6F", {optO32}, {cpu386});	(* 848 *)

	Mnem ("OUTSB");	(* 357 *)
	Instr (none, none, none, "6E", {}, {cpu186});	(* 849 *)

	Mnem ("OUTSD");	(* 358 *)
	Instr (none, none, none, "6F", {optO32}, {cpu386});	(* 850 *)

	Mnem ("OUTSW");	(* 359 *)
	Instr (none, none, none, "6F", {optO16}, {cpu186});	(* 851 *)

	Mnem ("PACKSSDW");	(* 360 *)
	Instr (xmm, xmmmem128, none, "0F6B/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 852 *)
	Instr (mmx, mmxmem64, none, "0F6B/r", {}, {cpuPentium, cpuMMX});	(* 853 *)

	Mnem ("PACKSSWB");	(* 361 *)
	Instr (xmm, xmmmem128, none, "0F63/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 854 *)
	Instr (mmx, mmxmem64, none, "0F63/r", {}, {cpuPentium, cpuMMX});	(* 855 *)

	Mnem ("PACKUSWB");	(* 362 *)
	Instr (xmm, xmmmem128, none, "0F67/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 856 *)
	Instr (mmx, mmxmem64, none, "0F67/r", {}, {cpuPentium, cpuMMX});	(* 857 *)

	Mnem ("PADDB");	(* 363 *)
	Instr (xmm, xmmmem128, none, "0FFC/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 858 *)
	Instr (mmx, mmxmem64, none, "0FFC/r", {}, {cpuPentium, cpuMMX});	(* 859 *)

	Mnem ("PADDD");	(* 364 *)
	Instr (xmm, xmmmem128, none, "0FFE/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 860 *)
	Instr (mmx, mmxmem64, none, "0FFE/r", {}, {cpuPentium, cpuMMX});	(* 861 *)

	Mnem ("PADDQ");	(* 365 *)
	Instr (xmm, xmmmem128, none, "0FD4/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 862 *)
	Instr (mmx, mmxmem64, none, "0FD4/r", {}, {cpuPentium, cpuMMX});	(* 863 *)

	Mnem ("PADDSB");	(* 366 *)
	Instr (xmm, xmmmem128, none, "0FEC/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 864 *)
	Instr (mmx, mmxmem64, none, "0FEC/r", {}, {cpuPentium, cpuMMX});	(* 865 *)

	Mnem ("PADDSW");	(* 367 *)
	Instr (xmm, xmmmem128, none, "0FED/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 866 *)
	Instr (mmx, mmxmem64, none, "0FED/r", {}, {cpuPentium, cpuMMX});	(* 867 *)

	Mnem ("PADDUSB");	(* 368 *)
	Instr (xmm, xmmmem128, none, "0FDC/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 868 *)
	Instr (mmx, mmxmem64, none, "0FDC/r", {}, {cpuPentium, cpuMMX});	(* 869 *)

	Mnem ("PADDUSW");	(* 369 *)
	Instr (xmm, xmmmem128, none, "0FDD/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 870 *)
	Instr (mmx, mmxmem64, none, "0FDD/r", {}, {cpuPentium, cpuMMX});	(* 871 *)

	Mnem ("PADDW");	(* 370 *)
	Instr (xmm, xmmmem128, none, "0FFD/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 872 *)
	Instr (mmx, mmxmem64, none, "0FFD/r", {}, {cpuPentium, cpuMMX});	(* 873 *)

	Mnem ("PAND");	(* 371 *)
	Instr (xmm, xmmmem128, none, "0FDB/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 874 *)
	Instr (mmx, mmxmem64, none, "0FDB/r", {}, {cpuPentium, cpuMMX});	(* 875 *)

	Mnem ("PANDN");	(* 372 *)
	Instr (xmm, xmmmem128, none, "0FDF/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 876 *)
	Instr (mmx, mmxmem64, none, "0FDF/r", {}, {cpuPentium, cpuMMX});	(* 877 *)

	Mnem ("PAUSE");	(* 373 *)
	Instr (none, none, none, "90", {optPREP}, {cpuWillamette, cpuSSE2});	(* 878 *)

	Mnem ("PAVGB");	(* 374 *)
	Instr (xmm, xmmmem128, none, "0FE0/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 879 *)
	Instr (mmx, mmxmem64, none, "0FE0/r", {}, {cpuKatmai, cpuMMX});	(* 880 *)

	Mnem ("PAVGUSB");	(* 375 *)
	Instr (mmx, mmxmem64, none, "0F0F/rBF", {}, {cpuPentium, cpu3DNow});	(* 881 *)

	Mnem ("PAVGW");	(* 376 *)
	Instr (xmm, xmmmem128, none, "0FE3/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 882 *)
	Instr (mmx, mmxmem64, none, "0FE3/r", {}, {cpuKatmai, cpuMMX});	(* 883 *)

	Mnem ("PCMPEQB");	(* 377 *)
	Instr (xmm, xmmmem128, none, "0F74/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 884 *)
	Instr (mmx, mmxmem64, none, "0F74/r", {}, {cpuPentium, cpuMMX});	(* 885 *)

	Mnem ("PCMPEQD");	(* 378 *)
	Instr (xmm, xmmmem128, none, "0F76/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 886 *)
	Instr (mmx, mmxmem64, none, "0F76/r", {}, {cpuPentium, cpuMMX});	(* 887 *)

	Mnem ("PCMPEQW");	(* 379 *)
	Instr (xmm, xmmmem128, none, "0F75/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 888 *)
	Instr (mmx, mmxmem64, none, "0F75/r", {}, {cpuPentium, cpuMMX});	(* 889 *)

	Mnem ("PCMPGTB");	(* 380 *)
	Instr (xmm, xmmmem128, none, "0F64/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 890 *)
	Instr (mmx, mmxmem64, none, "0F64/r", {}, {cpuPentium, cpuMMX});	(* 891 *)

	Mnem ("PCMPGTD");	(* 381 *)
	Instr (xmm, xmmmem128, none, "0F66/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 892 *)
	Instr (mmx, mmxmem64, none, "0F66/r", {}, {cpuPentium, cpuMMX});	(* 893 *)

	Mnem ("PCMPGTW");	(* 382 *)
	Instr (xmm, xmmmem128, none, "0F65/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 894 *)
	Instr (mmx, mmxmem64, none, "0F65/r", {}, {cpuPentium, cpuMMX});	(* 895 *)

	Mnem ("PEXTRW");	(* 383 *)
	Instr (reg32, xmm, uimm8, "0FC5/rib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 896 *)
	Instr (reg32, mmx, uimm8, "0FC5/rib", {}, {cpuKatmai, cpuMMX});	(* 897 *)

	Mnem ("PF2ID");	(* 384 *)
	Instr (mmx, mmxmem64, none, "0F0F/r1D", {}, {cpuPentium, cpu3DNow});	(* 898 *)

	Mnem ("PF2IW");	(* 385 *)
	Instr (mmx, mmxmem64, none, "0F0F/r1C", {}, {cpuPentium, cpu3DNow});	(* 899 *)

	Mnem ("PFACC");	(* 386 *)
	Instr (mmx, mmxmem64, none, "0F0F/rAE", {}, {cpuPentium, cpu3DNow});	(* 900 *)

	Mnem ("PFADD");	(* 387 *)
	Instr (mmx, mmxmem64, none, "0F0F/r9E", {}, {cpuPentium, cpu3DNow});	(* 901 *)

	Mnem ("PFCMPEQ");	(* 388 *)
	Instr (mmx, mmxmem64, none, "0F0F/rB0", {}, {cpuPentium, cpu3DNow});	(* 902 *)

	Mnem ("PFCMPGE");	(* 389 *)
	Instr (mmx, mmxmem64, none, "0F0F/r90", {}, {cpuPentium, cpu3DNow});	(* 903 *)

	Mnem ("PFCMPGT");	(* 390 *)
	Instr (mmx, mmxmem64, none, "0F0F/rA0", {}, {cpuPentium, cpu3DNow});	(* 904 *)

	Mnem ("PFMAX");	(* 391 *)
	Instr (mmx, mmxmem64, none, "0F0F/rA4", {}, {cpuPentium, cpu3DNow});	(* 905 *)

	Mnem ("PFMIN");	(* 392 *)
	Instr (mmx, mmxmem64, none, "0F0F/r94", {}, {cpuPentium, cpu3DNow});	(* 906 *)

	Mnem ("PFMUL");	(* 393 *)
	Instr (mmx, mmxmem64, none, "0F0F/rB4", {}, {cpuPentium, cpu3DNow});	(* 907 *)

	Mnem ("PFNACC");	(* 394 *)
	Instr (mmx, mmxmem64, none, "0F0F/r8A", {}, {cpuPentium, cpu3DNow});	(* 908 *)

	Mnem ("PFPNACC");	(* 395 *)
	Instr (mmx, mmxmem64, none, "0F0F/r8E", {}, {cpuPentium, cpu3DNow});	(* 909 *)

	Mnem ("PFRCP");	(* 396 *)
	Instr (mmx, mmxmem64, none, "0F0F/r96", {}, {cpuPentium, cpu3DNow});	(* 910 *)

	Mnem ("PFRCPIT1");	(* 397 *)
	Instr (mmx, mmxmem64, none, "0F0F/rA6", {}, {cpuPentium, cpu3DNow});	(* 911 *)

	Mnem ("PFRCPIT2");	(* 398 *)
	Instr (mmx, mmxmem64, none, "0F0F/rB6", {}, {cpuPentium, cpu3DNow});	(* 912 *)

	Mnem ("PFRSQIT1");	(* 399 *)
	Instr (mmx, mmxmem64, none, "0F0F/rA7", {}, {cpuPentium, cpu3DNow});	(* 913 *)

	Mnem ("PFRSQRT");	(* 400 *)
	Instr (mmx, mmxmem64, none, "0F0F/r97", {}, {cpuPentium, cpu3DNow});	(* 914 *)

	Mnem ("PFSUB");	(* 401 *)
	Instr (mmx, mmxmem64, none, "0F0F/r9A", {}, {cpuPentium, cpu3DNow});	(* 915 *)

	Mnem ("PFSUBR");	(* 402 *)
	Instr (mmx, mmxmem64, none, "0F0F/rAA", {}, {cpuPentium, cpu3DNow});	(* 916 *)

	Mnem ("PI2FD");	(* 403 *)
	Instr (mmx, mmxmem64, none, "0F0F/r0D", {}, {cpuPentium, cpu3DNow});	(* 917 *)

	Mnem ("PI2FW");	(* 404 *)
	Instr (mmx, mmxmem64, none, "0F0F/r0C", {}, {cpuPentium, cpu3DNow});	(* 918 *)

	Mnem ("PINSRW");	(* 405 *)
	Instr (xmm, regmem16, uimm8, "0FC4/rib", {optO16, optD64}, {cpuWillamette, cpuSSE2});	(* 919 *)
	Instr (xmm, regmem32, uimm8, "0FC4/rib", {optO32, optD64}, {cpuWillamette, cpuSSE2});	(* 920 *)
	Instr (mmx, regmem16, uimm8, "0FC4/rib", {optO16, optD64}, {cpuKatmai, cpuMMX});	(* 921 *)
	Instr (mmx, regmem32, uimm8, "0FC4/rib", {optO32, optD64}, {cpuKatmai, cpuMMX});	(* 922 *)

	Mnem ("PMADDWD");	(* 406 *)
	Instr (xmm, xmmmem128, none, "0FF5/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 923 *)
	Instr (mmx, mmxmem64, none, "0FF5/r", {}, {cpuPentium, cpuMMX});	(* 924 *)

	Mnem ("PMAXSW");	(* 407 *)
	Instr (xmm, xmmmem128, none, "0FEE/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 925 *)
	Instr (mmx, mmxmem64, none, "0FEE/r", {}, {cpuKatmai, cpuMMX});	(* 926 *)

	Mnem ("PMAXUB");	(* 408 *)
	Instr (xmm, xmmmem128, none, "0FDE/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 927 *)
	Instr (mmx, mmxmem64, none, "0FDE/r", {}, {cpuKatmai, cpuMMX});	(* 928 *)

	Mnem ("PMINSW");	(* 409 *)
	Instr (xmm, xmmmem128, none, "0FEA/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 929 *)
	Instr (mmx, mmxmem64, none, "0FEA/r", {}, {cpuKatmai, cpuMMX});	(* 930 *)

	Mnem ("PMINUB");	(* 410 *)
	Instr (xmm, xmmmem128, none, "0FDA/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 931 *)
	Instr (mmx, mmxmem64, none, "0FDA/r", {}, {cpuKatmai, cpuMMX});	(* 932 *)

	Mnem ("PMOVMSKB");	(* 411 *)
	Instr (reg32, xmm, none, "0FD7/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 933 *)
	Instr (reg32, mmx, none, "0FD7/r", {}, {cpuKatmai, cpuMMX});	(* 934 *)

	Mnem ("PMULHRW");	(* 412 *)
	Instr (mmx, mmxmem64, none, "0F0F/rB7", {}, {cpuPentium, cpu3DNow});	(* 935 *)

	Mnem ("PMULHUW");	(* 413 *)
	Instr (xmm, xmmmem128, none, "0FE4/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 936 *)
	Instr (mmx, mmxmem64, none, "0FE4/r", {}, {cpuKatmai, cpuMMX});	(* 937 *)

	Mnem ("PMULHW");	(* 414 *)
	Instr (xmm, xmmmem128, none, "0FE5/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 938 *)
	Instr (mmx, mmxmem64, none, "0FE5/r", {}, {cpuPentium, cpuMMX});	(* 939 *)

	Mnem ("PMULLW");	(* 415 *)
	Instr (xmm, xmmmem128, none, "0FD5/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 940 *)
	Instr (mmx, mmxmem64, none, "0FD5/r", {}, {cpuPentium, cpuMMX});	(* 941 *)

	Mnem ("PMULUDQ");	(* 416 *)
	Instr (xmm, xmmmem128, none, "0FF4/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 942 *)
	Instr (mmx, mmxmem64, none, "0FF4/r", {}, {cpuWillamette, cpuSSE2});	(* 943 *)

	Mnem ("POP");	(* 417 *)
	Instr (ES, none, none, "07", {optI64}, {cpu8086});	(* 944 *)
	Instr (SS, none, none, "17", {optI64}, {cpu8086});	(* 945 *)
	Instr (DS, none, none, "1F", {optI64}, {cpu8086});	(* 946 *)
	Instr (reg16, none, none, "58rw", {optO16, optD64}, {cpu8086});	(* 947 *)
	Instr (reg32, none, none, "58rd", {optO32, optD64}, {cpu386});	(* 948 *)
	Instr (reg64, none, none, "58rq", {optD64}, {cpuAMD64});	(* 949 *)
	Instr (FS, none, none, "0FA1", {optD64}, {cpu386});	(* 950 *)
	Instr (GS, none, none, "0FA9", {optD64}, {cpu386});	(* 951 *)
	Instr (regmem16, none, none, "8F/0", {optO16, optD64}, {cpu8086});	(* 952 *)
	Instr (regmem32, none, none, "8F/0", {optO32, optD64}, {cpu386});	(* 953 *)
	Instr (regmem64, none, none, "8F/0", {optD64}, {cpuAMD64});	(* 954 *)

	Mnem ("POPA");	(* 418 *)
	Instr (none, none, none, "61", {optI64}, {cpu186});	(* 955 *)

	Mnem ("POPAD");	(* 419 *)
	Instr (none, none, none, "61", {optO32, optI64}, {cpu386});	(* 956 *)

	Mnem ("POPAW");	(* 420 *)
	Instr (none, none, none, "61", {optO16, optI64}, {cpu186});	(* 957 *)

	Mnem ("POPF");	(* 421 *)
	Instr (none, none, none, "9D", {}, {cpu8086});	(* 958 *)

	Mnem ("POPFD");	(* 422 *)
	Instr (none, none, none, "9D", {optO32}, {cpu386});	(* 959 *)

	Mnem ("POPFQ");	(* 423 *)
	Instr (none, none, none, "9D", {optO64}, {cpuAMD64});	(* 960 *)

	Mnem ("POPFW");	(* 424 *)
	Instr (none, none, none, "9D", {optO16}, {cpu8086});	(* 961 *)

	Mnem ("POR");	(* 425 *)
	Instr (xmm, xmmmem128, none, "0FEB/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 962 *)
	Instr (mmx, mmxmem64, none, "0FEB/r", {}, {cpuPentium, cpuMMX});	(* 963 *)

	Mnem ("PREFETCH");	(* 426 *)
	Instr (mem8, none, none, "0F0D/0", {}, {cpuPentium, cpu3DNow});	(* 964 *)

	Mnem ("PREFETCHNTA");	(* 427 *)
	Instr (mem8, none, none, "0F18/0", {}, {cpuKatmai});	(* 965 *)

	Mnem ("PREFETCHT0");	(* 428 *)
	Instr (mem8, none, none, "0F18/1", {}, {cpuKatmai});	(* 966 *)

	Mnem ("PREFETCHT1");	(* 429 *)
	Instr (mem8, none, none, "0F18/2", {}, {cpuKatmai});	(* 967 *)

	Mnem ("PREFETCHT2");	(* 430 *)
	Instr (mem8, none, none, "0F18/3", {}, {cpuKatmai});	(* 968 *)

	Mnem ("PREFETCHW");	(* 431 *)
	Instr (mem8, none, none, "0F0D/1", {}, {cpuPentium, cpu3DNow});	(* 969 *)

	Mnem ("PSADBW");	(* 432 *)
	Instr (xmm, xmmmem128, none, "0FF6/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 970 *)
	Instr (mmx, mmxmem64, none, "0FF6/r", {}, {cpuKatmai, cpuMMX});	(* 971 *)

	Mnem ("PSHUFD");	(* 433 *)
	Instr (xmm, xmmmem128, uimm8, "0F70/rib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 972 *)

	Mnem ("PSHUFHW");	(* 434 *)
	Instr (xmm, xmmmem128, uimm8, "0F70/rib", {optPREP}, {cpuWillamette, cpuSSE2});	(* 973 *)

	Mnem ("PSHUFLW");	(* 435 *)
	Instr (xmm, xmmmem128, uimm8, "0F70/rib", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 974 *)

	Mnem ("PSHUFW");	(* 436 *)
	Instr (mmx, mmxmem64, uimm8, "0F70/rib", {}, {cpuWillamette, cpuSSE2});	(* 975 *)

	Mnem ("PSLLD");	(* 437 *)
	Instr (xmm, xmmmem128, none, "0FF2/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 976 *)
	Instr (mmx, mmxmem64, none, "0FF2/r", {}, {cpuPentium, cpuMMX});	(* 977 *)
	Instr (xmm, uimm8, none, "0F72/6ib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 978 *)
	Instr (mmx, uimm8, none, "0F72/6ib", {}, {cpuPentium, cpuMMX});	(* 979 *)

	Mnem ("PSLLDQ");	(* 438 *)
	Instr (xmm, uimm8, none, "0F73/7ib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 980 *)

	Mnem ("PSLLQ");	(* 439 *)
	Instr (xmm, xmmmem128, none, "0FF3/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 981 *)
	Instr (mmx, mmxmem64, none, "0FF3/r", {}, {cpuPentium, cpuMMX});	(* 982 *)
	Instr (xmm, uimm8, none, "0F73/6ib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 983 *)
	Instr (mmx, uimm8, none, "0F73/6ib", {}, {cpuPentium, cpuMMX});	(* 984 *)

	Mnem ("PSLLW");	(* 440 *)
	Instr (xmm, xmmmem128, none, "0FF1/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 985 *)
	Instr (mmx, mmxmem64, none, "0FF1/r", {}, {cpuPentium, cpuMMX});	(* 986 *)
	Instr (xmm, uimm8, none, "0F71/6ib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 987 *)
	Instr (mmx, uimm8, none, "0F71/6ib", {}, {cpuPentium, cpuMMX});	(* 988 *)

	Mnem ("PSRAD");	(* 441 *)
	Instr (xmm, xmmmem128, none, "0FE2/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 989 *)
	Instr (mmx, mmxmem64, none, "0FE2/r", {}, {cpuPentium, cpuMMX});	(* 990 *)
	Instr (xmm, uimm8, none, "0F72/4ib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 991 *)
	Instr (mmx, uimm8, none, "0F72/4ib", {}, {cpuPentium, cpuMMX});	(* 992 *)

	Mnem ("PSRAW");	(* 442 *)
	Instr (xmm, xmmmem128, none, "0FE1/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 993 *)
	Instr (mmx, mmxmem64, none, "0FE1/r", {}, {cpuPentium, cpuMMX});	(* 994 *)
	Instr (xmm, uimm8, none, "0F71/4ib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 995 *)
	Instr (mmx, uimm8, none, "0F71/4ib", {}, {cpuPentium, cpuMMX});	(* 996 *)

	Mnem ("PSRLD");	(* 443 *)
	Instr (xmm, xmmmem128, none, "0FD2/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 997 *)
	Instr (mmx, mmxmem64, none, "0FD2/r", {}, {cpuPentium, cpuMMX});	(* 998 *)
	Instr (xmm, uimm8, none, "0F72/2ib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 999 *)
	Instr (mmx, uimm8, none, "0F72/2ib", {}, {cpuPentium, cpuMMX});	(* 1000 *)

	Mnem ("PSRLDQ");	(* 444 *)
	Instr (xmm, uimm8, none, "0F73/3ib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1001 *)

	Mnem ("PSRLQ");	(* 445 *)
	Instr (xmm, xmmmem128, none, "0FD3/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1002 *)
	Instr (mmx, mmxmem64, none, "0FD3/r", {}, {cpuPentium, cpuMMX});	(* 1003 *)
	Instr (xmm, uimm8, none, "0F73/2ib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1004 *)
	Instr (mmx, uimm8, none, "0F73/2ib", {}, {cpuPentium, cpuMMX});	(* 1005 *)

	Mnem ("PSRLW");	(* 446 *)
	Instr (xmm, xmmmem128, none, "0FD1/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1006 *)
	Instr (mmx, mmxmem64, none, "0FD1/r", {}, {cpuPentium, cpuMMX});	(* 1007 *)
	Instr (xmm, uimm8, none, "0F71/2ib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1008 *)
	Instr (mmx, uimm8, none, "0F71/2ib", {}, {cpuPentium, cpuMMX});	(* 1009 *)

	Mnem ("PSUBB");	(* 447 *)
	Instr (xmm, xmmmem128, none, "0FF8/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1010 *)
	Instr (mmx, mmxmem64, none, "0FF8/r", {}, {cpuPentium, cpuMMX});	(* 1011 *)

	Mnem ("PSUBD");	(* 448 *)
	Instr (xmm, xmmmem128, none, "0FFA/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1012 *)
	Instr (mmx, mmxmem64, none, "0FFA/r", {}, {cpuPentium, cpuMMX});	(* 1013 *)

	Mnem ("PSUBQ");	(* 449 *)
	Instr (xmm, xmmmem128, none, "0FFB/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1014 *)
	Instr (mmx, mmxmem64, none, "0FFB/r", {}, {cpuPentium, cpuMMX});	(* 1015 *)

	Mnem ("PSUBSB");	(* 450 *)
	Instr (xmm, xmmmem128, none, "0FE8/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1016 *)
	Instr (mmx, mmxmem64, none, "0FE8/r", {}, {cpuPentium, cpuMMX});	(* 1017 *)

	Mnem ("PSUBSW");	(* 451 *)
	Instr (xmm, xmmmem128, none, "0FE9/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1018 *)
	Instr (mmx, mmxmem64, none, "0FE9/r", {}, {cpuPentium, cpuMMX});	(* 1019 *)

	Mnem ("PSUBUSB");	(* 452 *)
	Instr (xmm, xmmmem128, none, "0FD8/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1020 *)
	Instr (mmx, mmxmem64, none, "0FD8/r", {}, {cpuPentium, cpuMMX});	(* 1021 *)

	Mnem ("PSUBUSW");	(* 453 *)
	Instr (xmm, xmmmem128, none, "0FD9/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1022 *)
	Instr (mmx, mmxmem64, none, "0FD9/r", {}, {cpuPentium, cpuMMX});	(* 1023 *)

	Mnem ("PSUBW");	(* 454 *)
	Instr (xmm, xmmmem128, none, "0FF9/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1024 *)
	Instr (mmx, mmxmem64, none, "0FF9/r", {}, {cpuPentium, cpuMMX});	(* 1025 *)

	Mnem ("PSWAPD");	(* 455 *)
	Instr (mmx, mmxmem64, none, "0F0F/rBB", {}, {cpuPentium, cpu3DNow});	(* 1026 *)

	Mnem ("PUNPCKHBW");	(* 456 *)
	Instr (xmm, xmmmem128, none, "0F68/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1027 *)
	Instr (mmx, mmxmem64, none, "0F68/r", {}, {cpuPentium, cpuMMX});	(* 1028 *)

	Mnem ("PUNPCKHDQ");	(* 457 *)
	Instr (xmm, xmmmem128, none, "0F6A/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1029 *)
	Instr (mmx, mmxmem64, none, "0F6A/r", {}, {cpuPentium, cpuMMX});	(* 1030 *)

	Mnem ("PUNPCKHQDQ");	(* 458 *)
	Instr (xmm, xmmmem128, none, "0F6D/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1031 *)

	Mnem ("PUNPCKHWD");	(* 459 *)
	Instr (xmm, xmmmem128, none, "0F69/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1032 *)
	Instr (mmx, mmxmem64, none, "0F69/r", {}, {cpuPentium, cpuMMX});	(* 1033 *)

	Mnem ("PUNPCKLBW");	(* 460 *)
	Instr (xmm, xmmmem128, none, "0F60/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1034 *)
	Instr (mmx, mmxmem32, none, "0F60/r", {}, {cpuPentium, cpuMMX});	(* 1035 *)

	Mnem ("PUNPCKLDQ");	(* 461 *)
	Instr (xmm, xmmmem128, none, "0F62/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1036 *)
	Instr (mmx, mmxmem32, none, "0F62/r", {}, {cpuPentium, cpuMMX});	(* 1037 *)

	Mnem ("PUNPCKLQDQ");	(* 462 *)
	Instr (xmm, xmmmem128, none, "0F6C/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1038 *)

	Mnem ("PUNPCKLWD");	(* 463 *)
	Instr (xmm, xmmmem128, none, "0F61/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1039 *)
	Instr (mmx, mmxmem32, none, "0F61/r", {}, {cpuPentium, cpuMMX});	(* 1040 *)

	Mnem ("PUSH");	(* 464 *)
	Instr (ES, none, none, "06", {optI64}, {cpu8086});	(* 1041 *)
	Instr (CS, none, none, "0E", {optI64}, {cpu8086});	(* 1042 *)
	Instr (SS, none, none, "16", {optI64}, {cpu8086});	(* 1043 *)
	Instr (DS, none, none, "1E", {optI64}, {cpu8086});	(* 1044 *)
	Instr (reg16, none, none, "50rw", {optO16, optD64}, {cpu8086});	(* 1045 *)
	Instr (reg32, none, none, "50rd", {optO32, optD64}, {cpu386});	(* 1046 *)
	Instr (reg64, none, none, "50rq", {optD64}, {cpuAMD64});	(* 1047 *)
	Instr (FS, none, none, "0FA0", {optD64}, {cpu386});	(* 1048 *)
	Instr (GS, none, none, "0FA8", {optD64}, {cpu386});	(* 1049 *)
	Instr (imm8, none, none, "6Aib", {optD64}, {cpu186});	(* 1050 *)
	Instr (imm16, none, none, "68iw", {optO16, optD64}, {cpu186});	(* 1051 *)
	Instr (imm32, none, none, "68id", {optO32, optD64}, {cpu186});	(* 1052 *)
	Instr (imm64, none, none, "68id", {optD64}, {cpuAMD64});	(* 1053 *)
	Instr (regmem16, none, none, "FF/6", {optO16, optD64}, {cpu8086});	(* 1054 *)
	Instr (regmem32, none, none, "FF/6", {optO32, optD64}, {cpu386});	(* 1055 *)
	Instr (regmem64, none, none, "FF/6", {optD64}, {cpuAMD64});	(* 1056 *)

	Mnem ("PUSHA");	(* 465 *)
	Instr (none, none, none, "60", {optI64}, {cpu186});	(* 1057 *)

	Mnem ("PUSHAD");	(* 466 *)
	Instr (none, none, none, "60", {optO32, optI64}, {cpu386});	(* 1058 *)

	Mnem ("PUSHF");	(* 467 *)
	Instr (none, none, none, "9C", {}, {cpu8086});	(* 1059 *)

	Mnem ("PUSHFD");	(* 468 *)
	Instr (none, none, none, "9C", {optO32}, {cpu386});	(* 1060 *)

	Mnem ("PUSHFQ");	(* 469 *)
	Instr (none, none, none, "9C", {optO64}, {cpuAMD64});	(* 1061 *)

	Mnem ("PUSHFW");	(* 470 *)
	Instr (none, none, none, "9C", {optO16}, {cpu8086});	(* 1062 *)

	Mnem ("PXOR");	(* 471 *)
	Instr (xmm, xmmmem128, none, "0FEF/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1063 *)
	Instr (mmx, mmxmem64, none, "0FEF/r", {}, {cpuPentium, cpuMMX});	(* 1064 *)

	Mnem ("RCL");	(* 472 *)
	Instr (regmem8, one, none, "D0/2", {}, {cpu8086});	(* 1065 *)
	Instr (regmem8, CL, none, "D2/2", {}, {cpu8086});	(* 1066 *)
	Instr (regmem16, one, none, "D1/2", {optO16}, {cpu8086});	(* 1067 *)
	Instr (regmem16, CL, none, "D3/2", {optO16}, {cpu8086});	(* 1068 *)
	Instr (regmem32, one, none, "D1/2", {optO32}, {cpu386});	(* 1069 *)
	Instr (regmem32, CL, none, "D3/2", {optO32}, {cpu386});	(* 1070 *)
	Instr (regmem64, one, none, "D1/2", {}, {cpuAMD64});	(* 1071 *)
	Instr (regmem64, CL, none, "D3/2", {}, {cpuAMD64});	(* 1072 *)
	Instr (regmem8, uimm8, none, "C0/2ib", {}, {cpu186});	(* 1073 *)
	Instr (regmem16, uimm8, none, "C1/2ib", {optO16}, {cpu186});	(* 1074 *)
	Instr (regmem32, uimm8, none, "C1/2ib", {optO32}, {cpu386});	(* 1075 *)
	Instr (regmem64, uimm8, none, "C1/2ib", {}, {cpuAMD64});	(* 1076 *)

	Mnem ("RCPPS");	(* 473 *)
	Instr (xmm, xmmmem128, none, "0F53/r", {}, {cpuKatmai, cpuSSE});	(* 1077 *)

	Mnem ("RCPSS");	(* 474 *)
	Instr (xmm, xmmmem32, none, "0F53/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 1078 *)

	Mnem ("RCR");	(* 475 *)
	Instr (regmem8, one, none, "D0/3", {}, {cpu8086});	(* 1079 *)
	Instr (regmem8, CL, none, "D2/3", {}, {cpu8086});	(* 1080 *)
	Instr (regmem16, one, none, "D1/3", {optO16}, {cpu8086});	(* 1081 *)
	Instr (regmem16, CL, none, "D3/3", {optO16}, {cpu8086});	(* 1082 *)
	Instr (regmem32, one, none, "D1/3", {optO32}, {cpu386});	(* 1083 *)
	Instr (regmem32, CL, none, "D3/3", {optO32}, {cpu386});	(* 1084 *)
	Instr (regmem64, one, none, "D1/3", {}, {cpuAMD64});	(* 1085 *)
	Instr (regmem64, CL, none, "D3/3", {}, {cpuAMD64});	(* 1086 *)
	Instr (regmem8, uimm8, none, "C0/3ib", {}, {cpu186});	(* 1087 *)
	Instr (regmem16, uimm8, none, "C1/3ib", {optO16}, {cpu186});	(* 1088 *)
	Instr (regmem32, uimm8, none, "C1/3ib", {optO32}, {cpu386});	(* 1089 *)
	Instr (regmem64, uimm8, none, "C1/3ib", {}, {cpuAMD64});	(* 1090 *)

	Mnem ("RDMSR");	(* 476 *)
	Instr (none, none, none, "0F32", {}, {cpuPentium, cpuPrivileged});	(* 1091 *)

	Mnem ("RDPMC");	(* 477 *)
	Instr (none, none, none, "0F33", {}, {cpuP6});	(* 1092 *)

	Mnem ("RDTSC");	(* 478 *)
	Instr (none, none, none, "0F31", {}, {cpuPentium});	(* 1093 *)

	Mnem ("RDTSCP");	(* 479 *)
	Instr (none, none, none, "0F01F9", {}, {cpuPentium});	(* 1094 *)

	Mnem ("RET");	(* 480 *)
	Instr (none, none, none, "C3", {}, {cpu8086});	(* 1095 *)
	Instr (uimm16, none, none, "C2iw", {}, {cpu8086});	(* 1096 *)

	Mnem ("RETF");	(* 481 *)
	Instr (none, none, none, "CB", {}, {cpu8086});	(* 1097 *)
	Instr (uimm16, none, none, "CAiw", {}, {cpu8086});	(* 1098 *)

	Mnem ("ROL");	(* 482 *)
	Instr (regmem8, one, none, "D0/0", {}, {cpu8086});	(* 1099 *)
	Instr (regmem8, CL, none, "D2/0", {}, {cpu8086});	(* 1100 *)
	Instr (regmem16, one, none, "D1/0", {optO16}, {cpu8086});	(* 1101 *)
	Instr (regmem16, CL, none, "D3/0", {optO16}, {cpu8086});	(* 1102 *)
	Instr (regmem32, one, none, "D1/0", {optO32}, {cpu386});	(* 1103 *)
	Instr (regmem32, CL, none, "D3/0", {optO32}, {cpu386});	(* 1104 *)
	Instr (regmem64, one, none, "D1/0", {}, {cpuAMD64});	(* 1105 *)
	Instr (regmem64, CL, none, "D3/0", {}, {cpuAMD64});	(* 1106 *)
	Instr (regmem8, uimm8, none, "C0/0ib", {}, {cpu186});	(* 1107 *)
	Instr (regmem16, uimm8, none, "C1/0ib", {optO16}, {cpu186});	(* 1108 *)
	Instr (regmem32, uimm8, none, "C1/0ib", {optO32}, {cpu386});	(* 1109 *)
	Instr (regmem64, uimm8, none, "C1/0ib", {}, {cpuAMD64});	(* 1110 *)

	Mnem ("ROR");	(* 483 *)
	Instr (regmem8, one, none, "D0/1", {}, {cpu8086});	(* 1111 *)
	Instr (regmem8, CL, none, "D2/1", {}, {cpu8086});	(* 1112 *)
	Instr (regmem16, one, none, "D1/1", {optO16}, {cpu8086});	(* 1113 *)
	Instr (regmem16, CL, none, "D3/1", {optO16}, {cpu8086});	(* 1114 *)
	Instr (regmem32, one, none, "D1/1", {optO32}, {cpu386});	(* 1115 *)
	Instr (regmem32, CL, none, "D3/1", {optO32}, {cpu386});	(* 1116 *)
	Instr (regmem64, one, none, "D1/1", {}, {cpuAMD64});	(* 1117 *)
	Instr (regmem64, CL, none, "D3/1", {}, {cpuAMD64});	(* 1118 *)
	Instr (regmem8, uimm8, none, "C0/1ib", {}, {cpu186});	(* 1119 *)
	Instr (regmem16, uimm8, none, "C1/1ib", {optO16}, {cpu186});	(* 1120 *)
	Instr (regmem32, uimm8, none, "C1/1ib", {optO32}, {cpu386});	(* 1121 *)
	Instr (regmem64, uimm8, none, "C1/1ib", {}, {cpuAMD64});	(* 1122 *)

	Mnem ("RSM");	(* 484 *)
	Instr (none, none, none, "0FAA", {}, {cpuPentium});	(* 1123 *)

	Mnem ("RSQRTPS");	(* 485 *)
	Instr (xmm, xmmmem128, none, "0F52/r", {}, {cpuKatmai, cpuSSE});	(* 1124 *)

	Mnem ("RSQRTSS");	(* 486 *)
	Instr (xmm, xmmmem32, none, "0F52/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 1125 *)

	Mnem ("SAHF");	(* 487 *)
	Instr (none, none, none, "9E", {}, {cpu8086});	(* 1126 *)

	Mnem ("SAL");	(* 488 *)
	Instr (regmem8, one, none, "D0/4", {}, {cpu8086});	(* 1127 *)
	Instr (regmem8, CL, none, "D2/4", {}, {cpu8086});	(* 1128 *)
	Instr (regmem16, one, none, "D1/4", {optO16}, {cpu8086});	(* 1129 *)
	Instr (regmem16, CL, none, "D3/4", {optO16}, {cpu8086});	(* 1130 *)
	Instr (regmem32, one, none, "D1/4", {optO32}, {cpu386});	(* 1131 *)
	Instr (regmem32, CL, none, "D3/4", {optO32}, {cpu386});	(* 1132 *)
	Instr (regmem64, one, none, "D1/4", {}, {cpuAMD64});	(* 1133 *)
	Instr (regmem64, CL, none, "D3/4", {}, {cpuAMD64});	(* 1134 *)
	Instr (regmem8, uimm8, none, "C0/4ib", {}, {cpu186});	(* 1135 *)
	Instr (regmem16, uimm8, none, "C1/4ib", {optO16}, {cpu186});	(* 1136 *)
	Instr (regmem32, uimm8, none, "C1/4ib", {optO32}, {cpu386});	(* 1137 *)
	Instr (regmem64, uimm8, none, "C1/4ib", {}, {cpuAMD64});	(* 1138 *)

	Mnem ("SAR");	(* 489 *)
	Instr (regmem8, one, none, "D0/7", {}, {cpu8086});	(* 1139 *)
	Instr (regmem8, CL, none, "D2/7", {}, {cpu8086});	(* 1140 *)
	Instr (regmem16, one, none, "D1/7", {optO16}, {cpu8086});	(* 1141 *)
	Instr (regmem16, CL, none, "D3/7", {optO16}, {cpu8086});	(* 1142 *)
	Instr (regmem32, one, none, "D1/7", {optO32}, {cpu386});	(* 1143 *)
	Instr (regmem32, CL, none, "D3/7", {optO32}, {cpu386});	(* 1144 *)
	Instr (regmem64, one, none, "D1/7", {}, {cpuAMD64});	(* 1145 *)
	Instr (regmem64, CL, none, "D3/7", {}, {cpuAMD64});	(* 1146 *)
	Instr (regmem8, uimm8, none, "C0/7ib", {}, {cpu186});	(* 1147 *)
	Instr (regmem16, uimm8, none, "C1/7ib", {optO16}, {cpu186});	(* 1148 *)
	Instr (regmem32, uimm8, none, "C1/7ib", {optO32}, {cpu386});	(* 1149 *)
	Instr (regmem64, uimm8, none, "C1/7ib", {}, {cpuAMD64});	(* 1150 *)

	Mnem ("SBB");	(* 490 *)
	Instr (AL, imm8, none, "1Cib", {}, {cpu8086});	(* 1151 *)
	Instr (AX, imm16, none, "1Diw", {optO16}, {cpu8086});	(* 1152 *)
	Instr (EAX, imm32, none, "1Did", {optO32}, {cpu386});	(* 1153 *)
	Instr (RAX, imm32, none, "1Did", {}, {cpuAMD64});	(* 1154 *)
	Instr (regmem8, reg8, none, "18/r", {}, {cpu8086});	(* 1155 *)
	Instr (regmem16, reg16, none, "19/r", {optO16}, {cpu8086});	(* 1156 *)
	Instr (regmem32, reg32, none, "19/r", {optO32}, {cpu386});	(* 1157 *)
	Instr (regmem64, reg64, none, "19/r", {}, {cpuAMD64});	(* 1158 *)
	Instr (reg8, regmem8, none, "1A/r", {}, {cpu8086});	(* 1159 *)
	Instr (reg16, regmem16, none, "1B/r", {optO16}, {cpu8086});	(* 1160 *)
	Instr (reg32, regmem32, none, "1B/r", {optO32}, {cpu386});	(* 1161 *)
	Instr (reg64, regmem64, none, "1B/r", {}, {cpuAMD64});	(* 1162 *)
	Instr (regmem8, imm8, none, "80/3ib", {}, {cpu8086});	(* 1163 *)
	Instr (regmem16, simm8, none, "83/3ib", {optO16}, {cpu8086});	(* 1164 *)
	Instr (regmem16, imm16, none, "81/3iw", {optO16}, {cpu8086});	(* 1165 *)
	Instr (regmem32, simm8, none, "83/3ib", {optO32}, {cpu386});	(* 1166 *)
	Instr (regmem32, imm32, none, "81/3id", {optO32}, {cpu386});	(* 1167 *)
	Instr (regmem64, simm8, none, "83/3ib", {}, {cpuAMD64});	(* 1168 *)
	Instr (regmem64, imm32, none, "81/3id", {}, {cpuAMD64});	(* 1169 *)

	Mnem ("SCAS");	(* 491 *)
	Instr (mem8, none, none, "AE", {}, {cpu8086});	(* 1170 *)
	Instr (mem16, none, none, "AF", {optO16}, {cpu8086});	(* 1171 *)
	Instr (mem32, none, none, "AF", {optO32}, {cpu386});	(* 1172 *)
	Instr (mem64, none, none, "AF", {}, {cpuAMD64});	(* 1173 *)

	Mnem ("SCASB");	(* 492 *)
	Instr (none, none, none, "AE", {}, {cpu8086});	(* 1174 *)

	Mnem ("SCASD");	(* 493 *)
	Instr (none, none, none, "AF", {optO32}, {cpu386});	(* 1175 *)

	Mnem ("SCASQ");	(* 494 *)
	Instr (none, none, none, "AF", {optO64}, {cpuAMD64});	(* 1176 *)

	Mnem ("SCASW");	(* 495 *)
	Instr (none, none, none, "AF", {optO16}, {cpu8086});	(* 1177 *)

	Mnem ("SETA");	(* 496 *)
	Instr (regmem8, none, none, "0F97/0", {}, {cpu386});	(* 1178 *)

	Mnem ("SETAE");	(* 497 *)
	Instr (regmem8, none, none, "0F93/0", {}, {cpu386});	(* 1179 *)

	Mnem ("SETB");	(* 498 *)
	Instr (regmem8, none, none, "0F92/0", {}, {cpu386});	(* 1180 *)

	Mnem ("SETBE");	(* 499 *)
	Instr (regmem8, none, none, "0F96/0", {}, {cpu386});	(* 1181 *)

	Mnem ("SETC");	(* 500 *)
	Instr (regmem8, none, none, "0F92/0", {}, {cpu386});	(* 1182 *)

	Mnem ("SETE");	(* 501 *)
	Instr (regmem8, none, none, "0F94/0", {}, {cpu386});	(* 1183 *)

	Mnem ("SETG");	(* 502 *)
	Instr (regmem8, none, none, "0F9F/0", {}, {cpu386});	(* 1184 *)

	Mnem ("SETGE");	(* 503 *)
	Instr (regmem8, none, none, "0F9D/0", {}, {cpu386});	(* 1185 *)

	Mnem ("SETL");	(* 504 *)
	Instr (regmem8, none, none, "0F9C/0", {}, {cpu386});	(* 1186 *)

	Mnem ("SETLE");	(* 505 *)
	Instr (regmem8, none, none, "0F9E/0", {}, {cpu386});	(* 1187 *)

	Mnem ("SETNA");	(* 506 *)
	Instr (regmem8, none, none, "0F96/0", {}, {cpu386});	(* 1188 *)

	Mnem ("SETNAE");	(* 507 *)
	Instr (regmem8, none, none, "0F92/0", {}, {cpu386});	(* 1189 *)

	Mnem ("SETNB");	(* 508 *)
	Instr (regmem8, none, none, "0F93/0", {}, {cpu386});	(* 1190 *)

	Mnem ("SETNBE");	(* 509 *)
	Instr (regmem8, none, none, "0F97/0", {}, {cpu386});	(* 1191 *)

	Mnem ("SETNC");	(* 510 *)
	Instr (regmem8, none, none, "0F93/0", {}, {cpu386});	(* 1192 *)

	Mnem ("SETNE");	(* 511 *)
	Instr (regmem8, none, none, "0F95/0", {}, {cpu386});	(* 1193 *)

	Mnem ("SETNG");	(* 512 *)
	Instr (regmem8, none, none, "0F9E/0", {}, {cpu386});	(* 1194 *)

	Mnem ("SETNGE");	(* 513 *)
	Instr (regmem8, none, none, "0F9C/0", {}, {cpu386});	(* 1195 *)

	Mnem ("SETNL");	(* 514 *)
	Instr (regmem8, none, none, "0F9D/0", {}, {cpu386});	(* 1196 *)

	Mnem ("SETNLE");	(* 515 *)
	Instr (regmem8, none, none, "0F9F/0", {}, {cpu386});	(* 1197 *)

	Mnem ("SETNO");	(* 516 *)
	Instr (regmem8, none, none, "0F91/0", {}, {cpu386});	(* 1198 *)

	Mnem ("SETNP");	(* 517 *)
	Instr (regmem8, none, none, "0F9B/0", {}, {cpu386});	(* 1199 *)

	Mnem ("SETNS");	(* 518 *)
	Instr (regmem8, none, none, "0F99/0", {}, {cpu386});	(* 1200 *)

	Mnem ("SETNZ");	(* 519 *)
	Instr (regmem8, none, none, "0F95/0", {}, {cpu386});	(* 1201 *)

	Mnem ("SETO");	(* 520 *)
	Instr (regmem8, none, none, "0F90/0", {}, {cpu386});	(* 1202 *)

	Mnem ("SETP");	(* 521 *)
	Instr (regmem8, none, none, "0F9A/0", {}, {cpu386});	(* 1203 *)

	Mnem ("SETPE");	(* 522 *)
	Instr (regmem8, none, none, "0F9A/0", {}, {cpu386});	(* 1204 *)

	Mnem ("SETPO");	(* 523 *)
	Instr (regmem8, none, none, "0F9B/0", {}, {cpu386});	(* 1205 *)

	Mnem ("SETS");	(* 524 *)
	Instr (regmem8, none, none, "0F98/0", {}, {cpu386});	(* 1206 *)

	Mnem ("SETZ");	(* 525 *)
	Instr (regmem8, none, none, "0F94/0", {}, {cpu386});	(* 1207 *)

	Mnem ("SFENCE");	(* 526 *)
	Instr (none, none, none, "0FAEF8", {}, {cpuKatmai});	(* 1208 *)

	Mnem ("SGDT");	(* 527 *)
	Instr (mem, none, none, "0F01/0", {}, {cpu286, cpuPrivileged});	(* 1209 *)
	Instr (mem, none, none, "0F01/0", {}, {cpuAMD64, cpuPrivileged});	(* 1210 *)

	Mnem ("SHL");	(* 528 *)
	Instr (regmem8, one, none, "D0/4", {}, {cpu8086});	(* 1211 *)
	Instr (regmem8, CL, none, "D2/4", {}, {cpu8086});	(* 1212 *)
	Instr (regmem16, one, none, "D1/4", {optO16}, {cpu8086});	(* 1213 *)
	Instr (regmem16, CL, none, "D3/4", {optO16}, {cpu8086});	(* 1214 *)
	Instr (regmem32, one, none, "D1/4", {optO32}, {cpu386});	(* 1215 *)
	Instr (regmem32, CL, none, "D3/4", {optO32}, {cpu386});	(* 1216 *)
	Instr (regmem64, one, none, "D1/4", {}, {cpuAMD64});	(* 1217 *)
	Instr (regmem64, CL, none, "D3/4", {}, {cpuAMD64});	(* 1218 *)
	Instr (regmem8, uimm8, none, "C0/4ib", {}, {cpu186});	(* 1219 *)
	Instr (regmem16, uimm8, none, "C1/4ib", {optO16}, {cpu186});	(* 1220 *)
	Instr (regmem32, uimm8, none, "C1/4ib", {optO32}, {cpu386});	(* 1221 *)
	Instr (regmem64, uimm8, none, "C1/4ib", {}, {cpuAMD64});	(* 1222 *)

	Mnem ("SHLD");	(* 529 *)
	Instr (regmem16, reg16, CL, "0FA5/r", {optO16}, {cpu386});	(* 1223 *)
	Instr (regmem32, reg32, CL, "0FA5/r", {optO32}, {cpu386});	(* 1224 *)
	Instr (regmem64, reg64, CL, "0FA5/r", {}, {cpuAMD64});	(* 1225 *)
	Instr (regmem16, reg16, uimm8, "0FA4/rib", {optO16}, {cpu386});	(* 1226 *)
	Instr (regmem32, reg32, uimm8, "0FA4/rib", {optO32}, {cpu386});	(* 1227 *)
	Instr (regmem64, reg64, uimm8, "0FA4/rib", {}, {cpuAMD64});	(* 1228 *)

	Mnem ("SHR");	(* 530 *)
	Instr (regmem8, one, none, "D0/5", {}, {cpu8086});	(* 1229 *)
	Instr (regmem8, CL, none, "D2/5", {}, {cpu8086});	(* 1230 *)
	Instr (regmem16, one, none, "D1/5", {optO16}, {cpu8086});	(* 1231 *)
	Instr (regmem16, CL, none, "D3/5", {optO16}, {cpu8086});	(* 1232 *)
	Instr (regmem32, one, none, "D1/5", {optO32}, {cpu386});	(* 1233 *)
	Instr (regmem32, CL, none, "D3/5", {optO32}, {cpu386});	(* 1234 *)
	Instr (regmem64, one, none, "D1/5", {}, {cpuAMD64});	(* 1235 *)
	Instr (regmem64, CL, none, "D3/5", {}, {cpuAMD64});	(* 1236 *)
	Instr (regmem8, uimm8, none, "C0/5ib", {}, {cpu186});	(* 1237 *)
	Instr (regmem16, uimm8, none, "C1/5ib", {optO16}, {cpu186});	(* 1238 *)
	Instr (regmem32, uimm8, none, "C1/5ib", {optO32}, {cpu386});	(* 1239 *)
	Instr (regmem64, uimm8, none, "C1/5ib", {}, {cpuAMD64});	(* 1240 *)

	Mnem ("SHRD");	(* 531 *)
	Instr (regmem16, reg16, CL, "0FAD/r", {optO16}, {cpu386});	(* 1241 *)
	Instr (regmem32, reg32, CL, "0FAD/r", {optO32}, {cpu386});	(* 1242 *)
	Instr (regmem64, reg64, CL, "0FAD/r", {}, {cpuAMD64});	(* 1243 *)
	Instr (regmem16, reg16, uimm8, "0FAC/rib", {optO16}, {cpu386});	(* 1244 *)
	Instr (regmem32, reg32, uimm8, "0FAC/rib", {optO32}, {cpu386});	(* 1245 *)
	Instr (regmem64, reg64, uimm8, "0FAC/rib", {}, {cpuAMD64});	(* 1246 *)

	Mnem ("SHUFPD");	(* 532 *)
	Instr (xmm, xmmmem128, uimm8, "0FC6/rib", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1247 *)

	Mnem ("SHUFPS");	(* 533 *)
	Instr (xmm, xmmmem128, uimm8, "0FC6/rib", {}, {cpuKatmai, cpuSSE});	(* 1248 *)

	Mnem ("SIDT");	(* 534 *)
	Instr (mem, none, none, "0F01/1", {}, {cpu286, cpuPrivileged});	(* 1249 *)
	Instr (mem, none, none, "0F01/1", {}, {cpuAMD64, cpuPrivileged});	(* 1250 *)

	Mnem ("SKINIT");	(* 535 *)
	Instr (EAX, none, none, "0F01DE", {}, {cpuAMD64});	(* 1251 *)

	Mnem ("SLDT");	(* 536 *)
	Instr (reg16, none, none, "0F00/0", {optO16}, {cpu286});	(* 1252 *)
	Instr (reg32, none, none, "0F00/0", {optO32}, {cpu386});	(* 1253 *)
	Instr (reg64, none, none, "0F00/0", {}, {cpuAMD64});	(* 1254 *)
	Instr (mem16, none, none, "0F00/0", {}, {cpu286});	(* 1255 *)

	Mnem ("SMSW");	(* 537 *)
	Instr (reg16, none, none, "0F01/4", {optO16}, {cpu286});	(* 1256 *)
	Instr (reg32, none, none, "0F01/4", {optO32}, {cpu386});	(* 1257 *)
	Instr (reg64, none, none, "0F01/4", {}, {cpuAMD64});	(* 1258 *)
	Instr (mem16, none, none, "0F01/4", {}, {cpu286});	(* 1259 *)

	Mnem ("SQRTPD");	(* 538 *)
	Instr (xmm, xmmmem128, none, "0F51/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1260 *)

	Mnem ("SQRTPS");	(* 539 *)
	Instr (xmm, xmmmem128, none, "0F51/r", {}, {cpuKatmai, cpuSSE});	(* 1261 *)

	Mnem ("SQRTSD");	(* 540 *)
	Instr (xmm, xmmmem64, none, "0F51/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 1262 *)

	Mnem ("SQRTSS");	(* 541 *)
	Instr (xmm, xmmmem32, none, "0F51/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 1263 *)

	Mnem ("STC");	(* 542 *)
	Instr (none, none, none, "F9", {}, {cpu8086});	(* 1264 *)

	Mnem ("STD");	(* 543 *)
	Instr (none, none, none, "FD", {}, {cpu8086});	(* 1265 *)

	Mnem ("STGI");	(* 544 *)
	Instr (none, none, none, "0F01DC", {}, {cpuPentium});	(* 1266 *)

	Mnem ("STI");	(* 545 *)
	Instr (none, none, none, "FB", {}, {cpu8086});	(* 1267 *)

	Mnem ("STMXCSR");	(* 546 *)
	Instr (mem32, none, none, "0FAE/3", {}, {cpuKatmai, cpuSSE});	(* 1268 *)

	Mnem ("STOS");	(* 547 *)
	Instr (mem8, none, none, "AA", {}, {cpu8086});	(* 1269 *)
	Instr (mem16, none, none, "AB", {optO16}, {cpu8086});	(* 1270 *)
	Instr (mem32, none, none, "AB", {optO32}, {cpu386});	(* 1271 *)
	Instr (mem64, none, none, "AB", {}, {cpuAMD64});	(* 1272 *)

	Mnem ("STOSB");	(* 548 *)
	Instr (none, none, none, "AA", {}, {cpu8086});	(* 1273 *)

	Mnem ("STOSD");	(* 549 *)
	Instr (none, none, none, "AB", {optO32}, {cpu386});	(* 1274 *)

	Mnem ("STOSQ");	(* 550 *)
	Instr (none, none, none, "AB", {optO64}, {cpuAMD64});	(* 1275 *)

	Mnem ("STOSW");	(* 551 *)
	Instr (none, none, none, "AB", {optO16}, {cpu8086});	(* 1276 *)

	Mnem ("STR");	(* 552 *)
	Instr (reg16, none, none, "0F00/1", {optO16}, {cpu286, cpuProtected});	(* 1277 *)
	Instr (reg32, none, none, "0F00/1", {optO32}, {cpu386, cpuProtected});	(* 1278 *)
	Instr (reg64, none, none, "0F00/1", {}, {cpuAMD64});	(* 1279 *)
	Instr (mem16, none, none, "0F00/1", {}, {cpu286, cpuProtected});	(* 1280 *)

	Mnem ("SUB");	(* 553 *)
	Instr (AL, imm8, none, "2Cib", {}, {cpu8086});	(* 1281 *)
	Instr (AX, imm16, none, "2Diw", {optO16}, {cpu8086});	(* 1282 *)
	Instr (EAX, imm32, none, "2Did", {optO32}, {cpu386});	(* 1283 *)
	Instr (RAX, imm32, none, "2Did", {}, {cpuAMD64});	(* 1284 *)
	Instr (regmem8, reg8, none, "28/r", {}, {cpu8086});	(* 1285 *)
	Instr (regmem16, reg16, none, "29/r", {optO16}, {cpu8086});	(* 1286 *)
	Instr (regmem32, reg32, none, "29/r", {optO32}, {cpu386});	(* 1287 *)
	Instr (regmem64, reg64, none, "29/r", {}, {cpuAMD64});	(* 1288 *)
	Instr (reg8, regmem8, none, "2A/r", {}, {cpu8086});	(* 1289 *)
	Instr (reg16, regmem16, none, "2B/r", {optO16}, {cpu8086});	(* 1290 *)
	Instr (reg32, regmem32, none, "2B/r", {optO32}, {cpu386});	(* 1291 *)
	Instr (reg64, regmem64, none, "2B/r", {}, {cpuAMD64});	(* 1292 *)
	Instr (regmem8, imm8, none, "80/5ib", {}, {cpu8086});	(* 1293 *)
	Instr (regmem16, simm8, none, "83/5ib", {optO16}, {cpu8086});	(* 1294 *)
	Instr (regmem16, imm16, none, "81/5iw", {optO16}, {cpu8086});	(* 1295 *)
	Instr (regmem32, simm8, none, "83/5ib", {optO32}, {cpu386});	(* 1296 *)
	Instr (regmem32, imm32, none, "81/5id", {optO32}, {cpu386});	(* 1297 *)
	Instr (regmem64, simm8, none, "83/5ib", {}, {cpuAMD64});	(* 1298 *)
	Instr (regmem64, imm32, none, "81/5id", {}, {cpuAMD64});	(* 1299 *)

	Mnem ("SUBPD");	(* 554 *)
	Instr (xmm, xmmmem128, none, "0F5C/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1300 *)

	Mnem ("SUBPS");	(* 555 *)
	Instr (xmm, xmmmem128, none, "0F5C/r", {}, {cpuKatmai, cpuSSE});	(* 1301 *)

	Mnem ("SUBSD");	(* 556 *)
	Instr (xmm, xmmmem64, none, "0F5C/r", {optPREPN}, {cpuWillamette, cpuSSE2});	(* 1302 *)

	Mnem ("SUBSS");	(* 557 *)
	Instr (xmm, xmmmem32, none, "0F5C/r", {optPREP}, {cpuKatmai, cpuSSE});	(* 1303 *)

	Mnem ("SWAPGS");	(* 558 *)
	Instr (none, none, none, "0F01F8", {}, {cpuAMD64});	(* 1304 *)

	Mnem ("SYSCALL");	(* 559 *)
	Instr (none, none, none, "0F05", {}, {cpuP6});	(* 1305 *)

	Mnem ("SYSENTER");	(* 560 *)
	Instr (none, none, none, "0F34", {optI64}, {cpuP6});	(* 1306 *)

	Mnem ("SYSEXIT");	(* 561 *)
	Instr (none, none, none, "0F35", {optI64}, {cpuP6, cpuPrivileged});	(* 1307 *)

	Mnem ("SYSRET");	(* 562 *)
	Instr (none, none, none, "0F07", {}, {cpuP6, cpuPrivileged});	(* 1308 *)

	Mnem ("TEST");	(* 563 *)
	Instr (AL, imm8, none, "A8ib", {}, {cpu8086});	(* 1309 *)
	Instr (AX, imm16, none, "A9iw", {optO16}, {cpu8086});	(* 1310 *)
	Instr (EAX, imm32, none, "A9id", {optO32}, {cpu386});	(* 1311 *)
	Instr (RAX, imm32, none, "A9id", {}, {cpuAMD64});	(* 1312 *)
	Instr (regmem8, reg8, none, "84/r", {}, {cpu8086});	(* 1313 *)
	Instr (regmem16, reg16, none, "85/r", {optO16}, {cpu8086});	(* 1314 *)
	Instr (regmem32, reg32, none, "85/r", {optO32}, {cpu386});	(* 1315 *)
	Instr (regmem64, reg64, none, "85/r", {}, {cpuAMD64});	(* 1316 *)
	Instr (reg8, regmem8, none, "84/r", {}, {cpu8086});	(* 1317 *)
	Instr (reg16, regmem16, none, "85/r", {optO16}, {cpu8086});	(* 1318 *)
	Instr (reg32, regmem32, none, "85/r", {optO32}, {cpu386});	(* 1319 *)
	Instr (reg64, regmem64, none, "85/r", {}, {cpuAMD64});	(* 1320 *)
	Instr (regmem8, imm8, none, "F6/0ib", {}, {cpu8086});	(* 1321 *)
	Instr (regmem16, imm16, none, "F7/0iw", {optO16}, {cpu8086});	(* 1322 *)
	Instr (regmem32, imm32, none, "F7/0id", {optO32}, {cpu386});	(* 1323 *)
	Instr (regmem64, imm32, none, "F7/0id", {}, {cpuAMD64});	(* 1324 *)

	Mnem ("UCOMISD");	(* 564 *)
	Instr (xmm, xmmmem64, none, "0F2E/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1325 *)

	Mnem ("UCOMISS");	(* 565 *)
	Instr (xmm, xmmmem32, none, "0F2E/r", {}, {cpuKatmai, cpuSSE});	(* 1326 *)

	Mnem ("UD2");	(* 566 *)
	Instr (none, none, none, "0F0B", {}, {cpu286});	(* 1327 *)

	Mnem ("UNPCKHPD");	(* 567 *)
	Instr (xmm, xmmmem128, none, "0F15/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1328 *)

	Mnem ("UNPCKHPS");	(* 568 *)
	Instr (xmm, xmmmem128, none, "0F15/r", {}, {cpuKatmai, cpuSSE});	(* 1329 *)

	Mnem ("UNPCKLPD");	(* 569 *)
	Instr (xmm, xmmmem128, none, "0F14/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1330 *)

	Mnem ("UNPCKLPS");	(* 570 *)
	Instr (xmm, xmmmem128, none, "0F14/r", {}, {cpuKatmai, cpuSSE});	(* 1331 *)

	Mnem ("VERR");	(* 571 *)
	Instr (regmem16, none, none, "0F00/4", {}, {cpu286, cpuPrivileged});	(* 1332 *)

	Mnem ("VERW");	(* 572 *)
	Instr (regmem16, none, none, "0F00/5", {}, {cpu286, cpuPrivileged});	(* 1333 *)

	Mnem ("VMLOAD");	(* 573 *)
	Instr (rAX, none, none, "0F01DA", {}, {cpuAMD64});	(* 1334 *)

	Mnem ("VMMCALL");	(* 574 *)
	Instr (none, none, none, "0F01D9", {}, {cpuAMD64});	(* 1335 *)

	Mnem ("VMRUN");	(* 575 *)
	Instr (rAX, none, none, "0F01D8", {}, {cpuAMD64});	(* 1336 *)

	Mnem ("VMSAVE");	(* 576 *)
	Instr (rAX, none, none, "0F01DB", {}, {cpuAMD64});	(* 1337 *)

	Mnem ("WBINVD");	(* 577 *)
	Instr (none, none, none, "0F09", {}, {cpu486, cpuPrivileged});	(* 1338 *)

	Mnem ("WRMSR");	(* 578 *)
	Instr (none, none, none, "0F30", {}, {cpuPentium, cpuPrivileged});	(* 1339 *)

	Mnem ("XADD");	(* 579 *)
	Instr (regmem8, reg8, none, "0FC0/r", {}, {cpu486});	(* 1340 *)
	Instr (regmem16, reg16, none, "0FC1/r", {optO16}, {cpu486});	(* 1341 *)
	Instr (regmem32, reg32, none, "0FC1/r", {optO32}, {cpu486});	(* 1342 *)
	Instr (regmem64, reg64, none, "0FC1/r", {}, {cpuAMD64});	(* 1343 *)

	Mnem ("XCHG");	(* 580 *)
	Instr (AX, reg16, none, "90rw", {optO16}, {cpu8086});	(* 1344 *)
	Instr (EAX, reg32, none, "90rd", {optO32}, {cpu386});	(* 1345 *)
	Instr (RAX, reg64, none, "90rq", {}, {cpuAMD64});	(* 1346 *)
	Instr (reg16, AX, none, "90rw", {optO16}, {cpu8086});	(* 1347 *)
	Instr (reg32, EAX, none, "90rd", {optO32}, {cpu386});	(* 1348 *)
	Instr (reg64, RAX, none, "90rq", {}, {cpuAMD64});	(* 1349 *)
	Instr (reg8, regmem8, none, "86/r", {}, {cpu8086});	(* 1354 *)
	Instr (reg16, regmem16, none, "87/r", {optO16}, {cpu8086});	(* 1355 *)
	Instr (reg32, regmem32, none, "87/r", {optO32}, {cpu386});	(* 1356 *)
	Instr (reg64, regmem64, none, "87/r", {}, {cpuAMD64});	(* 1357 *)
	Instr (regmem8, reg8, none, "86/r", {}, {cpu8086});	(* 1350 *)
	Instr (regmem16, reg16, none, "87/r", {optO16}, {cpu8086});	(* 1351 *)
	Instr (regmem32, reg32, none, "87/r", {optO32}, {cpu386});	(* 1352 *)
	Instr (regmem64, reg64, none, "87/r", {}, {cpuAMD64});	(* 1353 *)

	Mnem ("XLAT");	(* 581 *)
	Instr (mem8, none, none, "D7", {}, {cpu8086});	(* 1358 *)

	Mnem ("XLATB");	(* 582 *)
	Instr (none, none, none, "D7", {}, {cpu8086});	(* 1359 *)

	Mnem ("XOR");	(* 583 *)
	Instr (AL, imm8, none, "34ib", {}, {cpu8086});	(* 1360 *)
	Instr (AX, imm16, none, "35iw", {optO16}, {cpu8086});	(* 1361 *)
	Instr (EAX, imm32, none, "35id", {optO32}, {cpu386});	(* 1362 *)
	Instr (RAX, imm32, none, "35id", {}, {cpuAMD64});	(* 1363 *)
	Instr (regmem8, reg8, none, "30/r", {}, {cpu8086});	(* 1364 *)
	Instr (regmem16, reg16, none, "31/r", {optO16}, {cpu8086});	(* 1365 *)
	Instr (regmem32, reg32, none, "31/r", {optO32}, {cpu386});	(* 1366 *)
	Instr (regmem64, reg64, none, "31/r", {}, {cpuAMD64});	(* 1367 *)
	Instr (reg8, regmem8, none, "32/r", {}, {cpu8086});	(* 1368 *)
	Instr (reg16, regmem16, none, "33/r", {optO16}, {cpu8086});	(* 1369 *)
	Instr (reg32, regmem32, none, "33/r", {optO32}, {cpu386});	(* 1370 *)
	Instr (reg64, regmem64, none, "33/r", {}, {cpuAMD64});	(* 1371 *)
	Instr (regmem8, imm8, none, "80/6ib", {}, {cpu8086});	(* 1372 *)
	Instr (regmem16, simm8, none, "83/6ib", {optO16}, {cpu8086});	(* 1373 *)
	Instr (regmem16, imm16, none, "81/6iw", {optO16}, {cpu8086});	(* 1374 *)
	Instr (regmem32, simm8, none, "83/6ib", {optO32}, {cpu386});	(* 1375 *)
	Instr (regmem32, imm32, none, "81/6id", {optO32}, {cpu386});	(* 1376 *)
	Instr (regmem64, simm8, none, "83/6ib", {}, {cpuAMD64});	(* 1377 *)
	Instr (regmem64, imm32, none, "81/6id", {}, {cpuAMD64});	(* 1378 *)

	Mnem ("XORPD");	(* 584 *)
	Instr (xmm, xmmmem128, none, "0F57/r", {optPOP}, {cpuWillamette, cpuSSE2});	(* 1379 *)

	Mnem ("XORPS");	(* 585 *)
	Instr (xmm, xmmmem128, none, "0F57/r", {}, {cpuKatmai, cpuSSE});	(* 1380 *)

	Reg ("AL", reg8, 0);
	Reg ("CL", reg8, 1);
	Reg ("DL", reg8, 2);
	Reg ("BL", reg8, 3);
	Reg ("SPL", reg8, 4);
	Reg ("BPL", reg8, 5);
	Reg ("SIL", reg8, 6);
	Reg ("DIL", reg8, 7);
	Reg ("AH", reg8, 4);
	Reg ("CH", reg8, 5);
	Reg ("DH", reg8, 6);
	Reg ("BH", reg8, 7);
	Reg ("R8B", reg8, 8);
	Reg ("R9B", reg8, 9);
	Reg ("R10B", reg8, 10);
	Reg ("R11B", reg8, 11);
	Reg ("R12B", reg8, 12);
	Reg ("R13B", reg8, 13);
	Reg ("R14B", reg8, 14);
	Reg ("R15B", reg8, 15);

	Reg ("AX", reg16, 0);
	Reg ("CX", reg16, 1);
	Reg ("DX", reg16, 2);
	Reg ("BX", reg16, 3);
	Reg ("SP", reg16, 4);
	Reg ("BP", reg16, 5);
	Reg ("SI", reg16, 6);
	Reg ("DI", reg16, 7);
	Reg ("R8W", reg16, 8);
	Reg ("R9W", reg16, 9);
	Reg ("R10W", reg16, 10);
	Reg ("R11W", reg16, 11);
	Reg ("R12W", reg16, 12);
	Reg ("R13W", reg16, 13);
	Reg ("R14W", reg16, 14);
	Reg ("R15W", reg16, 15);

	Reg ("EAX", reg32, 0);
	Reg ("ECX", reg32, 1);
	Reg ("EDX", reg32, 2);
	Reg ("EBX", reg32, 3);
	Reg ("ESP", reg32, 4);
	Reg ("EBP", reg32, 5);
	Reg ("ESI", reg32, 6);
	Reg ("EDI", reg32, 7);
	Reg ("R8D", reg32, 8);
	Reg ("R9D", reg32, 9);
	Reg ("R10D", reg32, 10);
	Reg ("R11D", reg32, 11);
	Reg ("R12D", reg32, 12);
	Reg ("R13D", reg32, 13);
	Reg ("R14D", reg32, 14);
	Reg ("R15D", reg32, 15);

	Reg ("RAX", reg64, 0);
	Reg ("RCX", reg64, 1);
	Reg ("RDX", reg64, 2);
	Reg ("RBX", reg64, 3);
	Reg ("RSP", reg64, 4);
	Reg ("RBP", reg64, 5);
	Reg ("RSI", reg64, 6);
	Reg ("RDI", reg64, 7);
	Reg ("R8", reg64, 8);
	Reg ("R9", reg64, 9);
	Reg ("R10", reg64, 10);
	Reg ("R11", reg64, 11);
	Reg ("R12", reg64, 12);
	Reg ("R13", reg64, 13);
	Reg ("R14", reg64, 14);
	Reg ("R15", reg64, 15);
	Reg ("RIP", reg64, 16);

	Reg ("ES", segReg, 0);
	Reg ("CS", segReg, 1);
	Reg ("SS", segReg, 2);
	Reg ("DS", segReg, 3);
	Reg ("FS", segReg, 4);
	Reg ("GS", segReg, 5);

	Reg ("CR0", CRn, 0);
	Reg ("CR1", CRn, 1);
	Reg ("CR2", CRn, 2);
	Reg ("CR3", CRn, 3);
	Reg ("CR4", CRn, 4);
	Reg ("CR5", CRn, 5);
	Reg ("CR6", CRn, 6);
	Reg ("CR7", CRn, 7);
	Reg ("CR8", CRn, 8);
	Reg ("CR9", CRn, 9);
	Reg ("CR10", CRn, 10);
	Reg ("CR11", CRn, 11);
	Reg ("CR12", CRn, 12);
	Reg ("CR13", CRn, 13);
	Reg ("CR14", CRn, 14);
	Reg ("CR15", CRn, 15);

	Reg ("DR0", DRn, 0);
	Reg ("DR1", DRn, 1);
	Reg ("DR2", DRn, 2);
	Reg ("DR3", DRn, 3);
	Reg ("DR4", DRn, 4);
	Reg ("DR5", DRn, 5);
	Reg ("DR6", DRn, 6);
	Reg ("DR7", DRn, 7);
	Reg ("DR8", DRn, 8);
	Reg ("DR9", DRn, 9);
	Reg ("DR10", DRn, 10);
	Reg ("DR11", DRn, 11);
	Reg ("DR12", DRn, 12);
	Reg ("DR13", DRn, 13);
	Reg ("DR14", DRn, 14);
	Reg ("DR15", DRn, 15);

	Reg ("ST0", sti, 0);
	Reg ("ST1", sti, 1);
	Reg ("ST2", sti, 2);
	Reg ("ST3", sti, 3);
	Reg ("ST4", sti, 4);
	Reg ("ST5", sti, 5);
	Reg ("ST6", sti, 6);
	Reg ("ST7", sti, 7);

	Reg ("XMM0", xmm, 0);
	Reg ("XMM1", xmm, 1);
	Reg ("XMM2", xmm, 2);
	Reg ("XMM3", xmm, 3);
	Reg ("XMM4", xmm, 4);
	Reg ("XMM5", xmm, 5);
	Reg ("XMM6", xmm, 6);
	Reg ("XMM7", xmm, 7);
	Reg ("XMM8", xmm, 8);
	Reg ("XMM9", xmm, 9);
	Reg ("XMM10", xmm, 10);
	Reg ("XMM11", xmm, 11);
	Reg ("XMM12", xmm, 12);
	Reg ("XMM13", xmm, 13);
	Reg ("XMM14", xmm, 14);
	Reg ("XMM15", xmm, 15);

	Reg ("MMX0", mmx, 0);
	Reg ("MMX1", mmx, 1);
	Reg ("MMX2", mmx, 2);
	Reg ("MMX3", mmx, 3);
	Reg ("MMX4", mmx, 4);
	Reg ("MMX5", mmx, 5);
	Reg ("MMX6", mmx, 6);
	Reg ("MMX7", mmx, 7);

	Cpu ("8086", {cpu8086});
	Cpu ("186", {cpu8086, cpu186});
	Cpu ("286", {cpu8086 .. cpu286});
	Cpu ("386", {cpu8086 .. cpu386});
	Cpu ("486", {cpu8086 .. cpu486});
	Cpu ("586", {cpu8086 .. cpuPentium});
	Cpu ("PENTIUM", {cpu8086 .. cpuPentium});
	Cpu ("686", {cpu8086 .. cpuP6});
	Cpu ("PPRO", {cpu8086 .. cpuP6});
	Cpu ("PENTIUMPRO", {cpu8086 .. cpuP6});
	Cpu ("P2", {cpu8086 .. cpuP6});
	Cpu ("P3", {cpu8086 .. cpuKatmai});
	Cpu ("KATMAI", {cpu8086 .. cpuKatmai});
	Cpu ("P4", {cpu8086 .. cpuWillamette});
	Cpu ("WILLAMETTE", {cpu8086 .. cpuWillamette});
	Cpu ("PRESCOTT", {cpu8086 .. cpuPrescott});
	Cpu ("AMD64", {cpu8086 .. cpuAMD64, cpuSSE, cpuSSE2, cpuSSE3, cpu3DNow, cpuMMX});

	Cpu ("PRIVILEGED", {cpuPrivileged});
	Cpu ("PROTECTED", {cpuProtected});
	Cpu ("SSE", {cpuSSE});
	Cpu ("SSE2", {cpuSSE2});
	Cpu ("SSE3", {cpuSSE3});
	Cpu ("3DNOW", {cpu3DNow});
	Cpu ("MMX", {cpuMMX});
	Cpu ("FPU", {cpuFPU});

END ASMAMD64.
