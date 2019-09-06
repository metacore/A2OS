MODULE PCARMDecoder IN Oberon;	(** be  **)

IMPORT SYSTEM, Modules, Oberon, Files, Texts, Fonts, Out, Decoder;

VAR
	(* bigendian *)
	bigEndian: BOOLEAN;

VAR W*: Texts.Writer;
		name0, name1, branch, branchl, dfloat, mfloat, cptnf, tnf, CC, Rot, Psr, Reg, FReg, Copr, CReg: ARRAY 128 OF CHAR;
		halfword: ARRAY 16 OF CHAR;

	PROCEDURE Ch(ch: CHAR);
	BEGIN Texts.Write(W, ch)
	END Ch;

	PROCEDURE Str(s: ARRAY OF CHAR);
	BEGIN Texts.WriteString(W, s)
	END Str;

	PROCEDURE Int(i: LONGINT);
	BEGIN Texts.WriteInt(W, i, 0)
	END Int;

	PROCEDURE tab;
	BEGIN Texts.Write(W, 09X)
	END tab;

	PROCEDURE Ln;
	BEGIN Texts.WriteLn(W)
	END Ln;

	PROCEDURE FixHex(n: LONGINT);
	BEGIN
		Texts.WriteHex(W, n)
	END FixHex;

	PROCEDURE Hex(n: LONGINT);
		VAR i, j: INTEGER; s, t : ARRAY 10 OF CHAR;
	BEGIN
		i := 0;
		REPEAT
			IF n MOD 10H < 10 THEN s[i] := CHR(n MOD 10H +ORD("0")) ELSE s[i] := CHR(n MOD 10H - 10 + ORD("A")) END;
			n := n DIV 10H MOD 10000000H; INC(i);
		UNTIL n = 0;
		j := 0;
		WHILE i>0 DO DEC(i); t[j] := s[i]; INC(j) END; t[j]:="H"; t[j+1] := 0X;
		(* IF t[0]>"9" THEN Texts.Write(W,"0") END; *)
		Texts.WriteString(W, t)
	END Hex;

	PROCEDURE word(VAR n: ARRAY OF CHAR; p: LONGINT);
	BEGIN
		p := p*4;
		Texts.Write(W, n[p]); Texts.Write(W, n[p+1]); Texts.Write(W, n[p+2]);
	END word;

	PROCEDURE word2(VAR n: ARRAY OF CHAR; p : LONGINT);
	BEGIN
		p := p*4;
		Texts.Write(W, n[p]); Texts.Write(W, n[p+1]); Texts.Write(W, n[p+2]); Texts.Write(W, n[p+3]);
	END word2;

	PROCEDURE word3(VAR n : ARRAY OF CHAR; p : LONGINT);
	BEGIN
		p:=p*2;
		Texts.Write(W, n[p]); Texts.Write(W, n[p+1])
	END word3;

	PROCEDURE cond(cc: LONGINT);
	BEGIN
		cc:= cc*3;
		Texts.Write(W, CC[cc]); Texts.Write(W, CC[cc+1])
	END cond;

	PROCEDURE s;
	BEGIN Texts.Write(W, "S");
	END s;

	PROCEDURE l;
	BEGIN Texts.Write(W, "L");
	END l;

	PROCEDURE byte;
	BEGIN Texts.Write(W, "B");
	END byte;

	PROCEDURE copr(n: LONGINT);
	BEGIN
		n:= n*3;
		Texts.Write(W, Copr[n]); Texts.Write(W, Copr[n + 1]); IF (Copr[n+2] # " ") THEN Texts.Write(W, Copr[n+2]) END
	END copr;

	PROCEDURE reg(n: LONGINT);
	BEGIN
		n:= n*3;
		Texts.Write(W, Reg[n]); Texts.Write(W, Reg[n + 1]); IF (Reg[n+2] # " ") THEN Texts.Write(W, Reg[n+2]) END
	END reg;

(*
	PROCEDURE freg(n: LONGINT);
	BEGIN
		n:= n*3;
		Texts.Write(W, FReg[n]); Texts.Write(W, FReg[n + 1]); Texts.Write(W, FReg[n + 2]);
	END freg;
*)

	PROCEDURE creg(n: LONGINT);
	BEGIN
		n := n * 4;
		Texts.Write(W, CReg[n]); Texts.Write(W, CReg[n+1]); Texts.Write(W, CReg[n+2]);
		IF (CReg[n+3] # " ") THEN Texts.Write(W, CReg[n+3]) END
	END creg;

	PROCEDURE psr(s, a: LONGINT);
		VAR i: LONGINT;
	BEGIN a := (a MOD 2 + a DIV 4)*8 - 8 + s*24 ;
		IF (a >= 0) & (a<48) THEN
			FOR i:= a TO a + 7 DO
				Texts.Write(W, Psr[i])
			END
		END
	END psr;

	PROCEDURE rot(t, c: LONGINT);
		VAR n: LONGINT;
	BEGIN
		IF ODD(t) THEN (* register form*)
			DEC(t); (* t MOD 8 isn't needed, since t.3=0 *)
			Texts.Write(W, Rot[t*2]); Texts.Write(W, Rot[t*2+1]);
			Texts.Write(W, Rot[t*2+2]); Texts.Write(W, Rot[t*2+3]);
			reg(c)
		ELSE
			n := c*2 + t DIV 8;
			IF n # 0 THEN
				Texts.Write(W, Rot[(t MOD 8)*2]); Texts.Write(W, Rot[(t MOD 8)*2+1]);
				Texts.Write(W, Rot[(t MOD 8)*2+2]); Texts.Write(W, Rot[(t MOD 8)*2+3]);
				Texts.WriteInt(W, n, 0)
			ELSIF (t MOD 8) = 6 THEN (* rrx *)
				Texts.WriteString(W, "RRX");
			ELSIF ((t MOD 8) = 2) OR ( (t MOD 8) = 4) THEN (* rotate 32*)
				Texts.Write(W, Rot[(t MOD 8)*2]); Texts.Write(W, Rot[(t MOD 8)*2+1]);
				Texts.Write(W, Rot[(t MOD 8)*2+2]); Texts.Write(W, Rot[(t MOD 8)*2+3]);
				Texts.WriteInt(W, 32, 0)
			END
		END
	END rot;

	PROCEDURE imm(i, r: LONGINT);
	BEGIN Hex(ROT(i, -2*r))
	END imm;

	PROCEDURE PCRelAddr(adr, sign, ofs : LONGINT);
	BEGIN
		tab; tab; Str("( = "); Int((adr+8)+sign*ofs); Str(" (");  FixHex((adr+8)+sign*ofs); Str("H)  )");
	END PCRelAddr;

	PROCEDURE decode(adr, code: LONGINT);
		VAR cc, a, b, c, d, e, f, g, i: LONGINT; regset: SET; sign : LONGINT;
	BEGIN
		g := code MOD 10H; code := code DIV 10H;	(* split instruction *)
		f := code MOD 10H; code := code DIV 10H;
		e := code MOD 10H; code := code DIV 10H;
		d := code MOD 10H; code := code DIV 10H;
		c := code MOD 10H; code := code DIV 10H;
		b := code MOD 10H; code := code DIV 10H;
		a := code MOD 10H; code := code DIV 10H;
		cc :=  code MOD 10H;

		CASE a OF
			0..3:
				IF (f = 9) & (a = 0) THEN (*mul / mull *)
					IF ODD(b DIV 8) THEN (* mull *)
						IF ODD(b DIV 4) THEN Ch("S") ELSE Ch("U") END;
						word(name0, (b DIV 2) MOD 2 + 16 ); Ch("L");
						cond(cc); IF ODD(b) THEN s ELSE Ch(" ") END; tab; Str("  ");
						reg(c); Ch(":"); reg(d); Ch(","); reg(g); Ch(","); reg(e);
					ELSE
						word(name0, (b DIV 2) MOD 2 + 16 );
						cond(cc); IF ODD(b) THEN s ELSE Ch(" ") END; tab; tab;
						reg(c); IF ODD(b DIV 8) THEN Ch(":"); reg(d) END;
						Ch(","); reg(g); Ch(","); reg(e);
						IF ODD(b DIV 2) THEN Ch(","); reg(d) END;
					END
				ELSIF (f>9) & ODD(f) & (a<2) THEN (* ldrh/strh *)
					word(name1,(b MOD 2)+1);  word3(halfword,(f-9) DIV 2); cond(cc);
					Str("   "); tab; reg(d); Str(",[");
					reg(c); IF ~ODD(a) THEN Ch("]") END;
					IF ODD(b DIV 4) THEN (* immidiate data transfer*)
						IF (e # 0) OR (g # 0) THEN
							Ch(",");
							IF ODD(b DIV 8) THEN Ch("+"); sign:=1 ELSE Ch("-"); sign:=-1 END;
							imm(e*10H +  g, 0)
						END
					ELSE	(* reg data transfer *)
						Ch(",");
						IF ODD(b DIV 8) THEN Ch("+") ELSE Ch("-") END;
						sign:=0;
						reg(g)
					END;
					IF ODD(a) THEN Ch("]") END;
					IF ODD(b DIV 2) THEN Ch("!") END;
					IF (c=15) & (sign#0) THEN PCRelAddr(adr,sign,e*10H+g) END;
				ELSIF (f = 9) & (a=1) THEN (*single swap *)
					Str("SWP"); cond(cc); IF ODD(b DIV 4) THEN Ch("B") ELSE Ch(" ") END; tab; tab;
					reg(d); Ch(","); reg(g); Str(",["); reg(c); Ch("]");
				ELSIF (a = 1) & (((b = 2) & ~(f = 7))OR (b = 6) OR (b = 0) OR (b = 4)) OR (a = 3)&((b = 2) OR (b = 6)) THEN (* msr /mrs *)
					word(tnf, b DIV 2 MOD 2); cond(cc); Ch(" "); tab; tab;
					IF (b = 0) OR (b = 4) THEN reg(d); Ch(","); psr(b DIV 4, 9)
					ELSE psr(b DIV 4, c); Ch(",");
						IF a = 3 THEN imm(f*10H + g, e) ELSE reg(g) END
					END
				ELSIF (a = 1) & (b = 2) & (f = 7) THEN (* bkpt *)
					Str("BKPT  "); tab; tab; imm(c*1000H + d*100H + e*10H + g, 0)
				ELSE
					word(name0, b DIV 2 + a*8 MOD 10H); cond(cc); IF ODD(b) THEN s ELSE Ch(" ") END; tab; tab;
					IF (b DIV 2 + a*8 MOD 10H = 0DH) OR (b DIV 2 + a*8 MOD 10H = 0FH) THEN (* Mov, Mvn*)
						reg(d)
					ELSIF (b DIV 2 + a*8 MOD 10H >= 8H) & (b DIV 2 + a*8 MOD 10H <=  0BH) THEN (* cmp, tst*)
						reg(c)
					ELSE reg(d); Ch(","); reg(c)
					END;
					IF ODD(a DIV 2) THEN Ch(","); imm(f*10H + g, e)	(* Immidiate Data processing *)
					ELSE Ch(","); reg(g); Ch(" "); rot(f, e)	(* Data processing *)
					END
				END
			| 4..7: (*ldr, str *)
				IF (a >= 6) & ODD(f) THEN word(name1, 0)	(* undef *)
				ELSIF (a >= 4) THEN
					word(name1, (b MOD 2) + 1); cond(cc);	(*ldr, str *)
					IF ODD(b DIV 4) THEN byte ELSE Ch(" ") END;
					IF ~ODD(a) & ODD(b DIV 2) THEN (* postindex & writeback *) Ch("T") ELSE Ch(" ") END;
					Str("   "); tab;
					reg(d); Ch(",");Ch("[");
					reg(c); IF ~ODD(a) THEN Ch("]") END;
					IF (a < 6) THEN (* immidiate data transfer*)
						IF (e # 0) OR (f # 0) OR (g # 0) THEN
							Ch(",");
							IF ODD(b DIV 8) THEN Ch("+"); sign:=1 ELSE Ch("-"); sign:=-1 END;
							imm(e*100H + f*10H + g, 0)
						END;
					ELSE	(* reg data transfer *)
						Ch(",");
						IF ODD(b DIV 8) THEN Ch("+") ELSE Ch("-") END;
						sign:=0;
						reg(g); Ch(" "); rot(f, e)
					END;
					IF ODD(a) THEN Ch("]") END;
					IF ODD(a) & ODD(b DIV 2) THEN (*preindexed & writeback *) Ch("!") END;
					IF (c=15) & (sign#0) THEN PCRelAddr(adr,sign,e*100H + f*10H + g) END;
				END
			| 8, 9: (* ldm, stm *)
				word(name1, (b MOD 2) + 3);
				IF b >= 8 THEN Ch("I") ELSE Ch("D") END;
				IF ODD(a) THEN Ch("B") ELSE Ch("A") END;
				cond(cc);
				Str("   "); tab;
				reg(c); IF ODD(b DIV 2) THEN Ch("!") END; Ch(","); Ch(" ");
				Ch("{");
				regset := SET(d*1000H + e*100H + f*10H +g);
				FOR i := 0 TO 15 DO
					IF i IN regset THEN reg(i); Ch(" "); END;
				END;
				Ch("}");
				IF ODD(b DIV 4) THEN Ch("^") END
			| 0AH: word(branch, cc); Str("   "); tab; tab; (* branch *)
					imm(adr +  8 + ASH(b*10000000H + c*1000000H + d*100000H + e*10000H + f*1000H +g*100H, -6 ), 0)
			| 0BH: word2(branchl, cc); Str("  "); tab; tab; (* branch link*)
					imm(adr +  8 + ASH(b*10000000H + c*1000000H + d*100000H + e*10000H + f*1000H +g*100H, -6 ), 0)
			(*| 0CH: (* floating point push/pop*)
				word(cptnf, b MOD 2 + 2); Str("   "); tab; tab;
				freg(d); Ch(","); Ch(" "); Ch("["); f := (f*10H + g) * 4;
				IF c = 13 THEN c := 15; (*correction of pc relative index, due to emulation hacks*)
					DEC(f, 4)
				END;
				reg(c); Ch("]"); Ch(",");
				IF ODD(b DIV 8) THEN Ch("+") ELSE Ch("-") END; imm(f, 0);
			| 0DH: (* floating point ldc/stc*)
				word(cptnf, b MOD 2); Str("   "); tab; tab;
				freg(d); Ch(","); Ch(" "); Ch("["); f := (f*10H + g) * 4;
				IF c = 13 THEN c := 15; (*correction of pc relative index, due to emulation hacks*)
					DEC(f, 4)
				END;
				reg(c); Ch(",");
				IF ODD(b DIV 8) THEN Ch("+") ELSE Ch("-") END; imm(f, 0);
				Ch("]");
			| 0EH:
				IF (e = 1) & (f = 0) THEN 	(* floating operation *)
					b := b + d DIV 8 * 8; d := d MOD 8;
					word(dfloat, b ); Str("   "); tab; tab;
					IF b < 5 THEN freg(d); Ch(","); freg(c); Ch(","); freg(g)
					ELSIF b <= 10 THEN freg(d); Ch(","); freg(g)
					END
				ELSIF (e = 1) & (f =1) THEN
					word(mfloat, b ); Str("   "); tab; tab;
					IF b = 0 THEN  freg(c); Ch(","); reg(d)
					ELSIF b = 1 THEN  reg(d); Ch(","); freg(g)
					ELSIF b = 2 THEN reg(d); Ch(","); freg(g)
					ELSIF b = 3 THEN freg(c); Ch(","); reg(d)
					ELSIF b = 9 THEN freg(c); Ch(","); freg(g)
					END
				ELSE	(* mrc/ mcr *)
					word(cptnf, 2 + b MOD 2); cond(cc); Ch(" "); tab; tab;
					IF ODD(b) THEN reg(d); Ch(","); Ch("#"); imm(e, 0); Ch("-"); reg(c); Ch(","); imm(f*10H +g, 0); Ch(" ")
					ELSE Ch("#"); imm(e, 0); Ch("-"); reg(c); Ch(","); imm(f*10H +g, 0); Ch(" "); Ch(","); reg(d);
					END
				END*)
			| 0CH..0EH:
				IF ~ODD(a DIV 2) THEN (* LDC, STC *)
					word(cptnf, b MOD 2); cond(cc); IF ODD(b DIV 4) THEN l ELSE Ch(" ") END; tab; tab;
					copr(e); Ch(","); creg(d); Str(",["); reg(c);
					IF ODD(a) THEN
						Str("],");
						IF ODD(b DIV 2) THEN Ch("#"); imm(f*10H+g, 0)
						ELSE Ch("{"); Int(f*10H+g); Ch("}")
						END
					ELSE
						Str(",#"); imm(f*10H+g, 0); Ch("]"); IF ODD(b DIV 2) THEN Ch("!") END
					END
				ELSE (* CDP, MCR, MRC *)
					IF ODD(f) THEN (* MCR/MRC *)
						word(cptnf, 4 + b MOD 2); cond(cc); Ch(" "); tab; tab;
						copr(e); Ch(","); Int(b DIV 2); Ch(","); reg(d); Ch(","); creg(c); Ch(","); creg(g);
						IF (f DIV 2 # 0) THEN Ch(","); Int(f DIV 2) END;
					ELSE (* CDP *)
						word(cptnf, 6); cond(cc); Ch(" "); tab; tab;
						copr(e); Ch(","); Int(b); Ch(","); creg(d); Ch(","); creg(c); Ch(","); creg(g); Ch(","); Int(f DIV 2)
					END
				END
			| 0FH: (* SWI *)
				word(name1,7); cond(cc); Ch(" "); tab; tab; Hex(b*100000H + c*10000H + d*1000H + e*100H + f*10H +g);
		END
	END decode;

PROCEDURE Init*;
BEGIN
	Texts.OpenWriter(W);
	Texts.SetFont(W, Fonts.This("Courier10.Scn.Fnt"));
END Init;

PROCEDURE Decode*(pc, code: LONGINT; raw: BOOLEAN);
BEGIN
	IF bigEndian THEN SwapBytes(code); END;
	FixHex(pc); FixHex(code); Str("    ");
	IF raw THEN Str("DCD"); tab; FixHex(code)
	ELSE decode(pc, code)
	END;
	Ln
END Decode;

PROCEDURE DecodeManual*;
VAR S: Texts.Scanner; T: Texts.Text; beg, end, time: LONGINT;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	Texts.OpenWriter(W);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF (time # -1) THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
	END;
	IF (S.class = Texts.Int) THEN
		Str("Decoding "); FixHex(S.i); Ln;
		Decode(0, S.i, FALSE); Ln
	ELSE Str("Syntax: PCARMDecoder.DecodeManual <opcode> ~"); Ln
	END;
	Texts.Append(Oberon.Log, W.buf)
END DecodeManual;

PROCEDURE DecoderPlugin(VAR pc: LONGINT; VAR r: Files.Rider; VAR w: Texts.Writer);
VAR opcode: LONGINT;
BEGIN
	W := w;
	Files.ReadLInt(r, opcode);
	IF bigEndian THEN SwapBytes(opcode); END;
	FixHex(opcode); Str("    "); decode(pc, opcode);
	w := W;
	INC(pc, 4)
END DecoderPlugin;

PROCEDURE HeaderCallback(VAR dataSize, constSize, codeSize: LONGINT);
BEGIN
	codeSize := codeSize * 4
END HeaderCallback;

PROCEDURE DecodeRaw*; (** [base address] ("^" | filename) *)
VAR S: Texts.Scanner; w: Texts.Writer; T: Texts.Text; beg, end, time, pc, opcode: LONGINT; f: Files.File; R: Files.Rider;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	Texts.OpenWriter(w);
	pc := 0;
	IF (S.class = Texts.Int) THEN	(* optional base address *)
		pc := S.i; Texts.Scan(S)
	END;
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(T, beg, end, time);
		IF (time # -1) THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
	END;
	IF (S.class IN {Texts.Name, Texts.String}) THEN
		Texts.WriteString(w, "Decoding "); Texts.WriteString(w, S.s); Texts.WriteString(w, "; base: "); Texts.WriteHex(w, pc);
		Texts.WriteString(w, "H : ");
		f := Files.Old(S.s);
		IF (f # NIL) THEN
			Files.Set(R, f, 0);
			NEW(T); Texts.Open(T, ""); Texts.OpenWriter(W);
			Texts.SetFont(W, Fonts.This("Courier10.Scn.Fnt"));
			Files.ReadLInt(R, opcode);
			WHILE ~R.eof DO
				Decode(pc, opcode, FALSE); INC(pc, 4);
				Files.ReadLInt(R, opcode)
			END;
			Texts.WriteString(w, "done.");
			Texts.Append(T, W.buf);
			Oberon.OpenText(S.s, T, 600, 300)
		ELSE
			Texts.WriteString(w, "not found.")
		END
	ELSE
		Texts.WriteString(w, "Invalid selection.")
	END;
	Texts.WriteLn(w);
	Texts.Append(Oberon.Log, w.buf)
END DecodeRaw;

(* InstallDecoder - *)
PROCEDURE InstallDecoder*;
VAR h, d: Decoder.DecodeHandler;
BEGIN
	h := DecoderPlugin;
	(* Paco bug workaround *)
	d := Decoder.ActiveDecoder();
	IF h # d THEN
		Decoder.InstallDecoder(DecoderPlugin, ".Oba", 4);
		Decoder.InstallHeaderCallback(HeaderCallback);
		Out.String("ARM Decoder Plugin installed"); Out.Ln
	END
END InstallDecoder;

(* Remove - the TermHandler *)
PROCEDURE Remove;
VAR h, d: Decoder.DecodeHandler;
BEGIN
	h := DecoderPlugin;
	(* Paco bug workaround *)
	d := Decoder.ActiveDecoder();
	IF (d = h) THEN Decoder.InstallDecoder(NIL, "", 1) END
END Remove;

PROCEDURE Initialize;
BEGIN
	CC := "EQ NE CS CC MI PL VS VC HI LS GE LT GT LE    NV";
	name0 := "AND EOR SUB RSB ADD ADC SBC RSC TST TEQ CMP CMN OR  MOV BIC MVN MUL MLA ";
	name1 := "UDF STR LDR STM LDM B   BL  SWI";
	branch := "BEQ BNE BCS BCC BMI BPL BVS BVC BHI BLS BGE BLT BGT BLE B   BNV ";
	branchl := "BLEQBLNEBLCSBLCCBLMIBLPLBLVSBLVCBLHIBLLSBLGEBLLTBLGTBLLEBL  BLNV";
	dfloat := "ADF MUF SUF ??? DVF ??? ??? ??? MVF MNF ABF";
	mfloat := "FLT FIX UPK PCK ??? ??? ??? ??? ??? CMF";
	cptnf := "STC LDC PSH POP MCR MRC CDP ";
	tnf := "MRS MSR";
	Psr := "CPSRcnt CPSRflg CPSRall SPSRcnt SPSRflg SPSRall     ";
	Reg := "R0 R1 R2 R3 R4 R5 R6 R7 R8 R9 R10R11FP SP LR PC ";
	FReg := "F0 F1 F2 F3 F4 F5 F6 F7 F8 F9 FA FB FC FD FE FF ";
	Copr := "p0 p1 p2 p3 p4 p5 p6 p7 p8 p9 p10p11p12p13p14p15";
	CReg := "CR0 CR1 CR2 CR3 CR4 CR5 CR6 CR7 CR8 CR9 CR10CR11CR12CR13CR14CR15";
	Rot:= "LSL LSR ASR ROR ";
	halfword:="??H SBSH";
	InstallDecoder;
	Modules.InstallTermHandler(Remove)
END Initialize;

PROCEDURE SetBigEndian*;
BEGIN
	bigEndian := TRUE;
END SetBigEndian;

PROCEDURE SetLittleEndian*;
BEGIN
	bigEndian := FALSE;
END SetLittleEndian;

PROCEDURE SwapBytes(VAR code: LONGINT);
TYPE Opcode = ARRAY 4 OF CHAR;
VAR opcode: Opcode;
	tmp: CHAR;
BEGIN
	opcode := SYSTEM.VAL(Opcode, code);
	tmp := opcode[0]; opcode[0] := opcode[3]; opcode[3] := tmp;
	tmp := opcode[1]; opcode[1] := opcode[2]; opcode[2] := tmp;
	code := SYSTEM.VAL(LONGINT, opcode);
END SwapBytes;

BEGIN Initialize;
	bigEndian := FALSE;
END PCARMDecoder.


PCARMDecoder.DecodeManual 0E92D5000H ~
System.Free PCARMDecoder ~

PCARMDecoder.SetBigEndian
Decoder.Decode Relocator.Oba
