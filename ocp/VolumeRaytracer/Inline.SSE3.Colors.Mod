MODULE Colors; (** AUTHOR "ph"; PURPOSE "basic color type and operations"; *)

IMPORT SYSTEM;

TYPE Color*=ARRAY [4] OF CHAR;
	VColor*= ARRAY [4] OF CHAR;

(*
	OPERATOR ":="*(VAR l:Color; r:UNSIGNED32); 
	BEGIN
		l:=SYSTEM.VAL(Color,r)
	END ":=";

	OPERATOR ":="*(VAR l:UNSIGNED32; CONST r:Color); 
	BEGIN
		l:=SYSTEM.VAL(UNSIGNED32,r)
	END ":=";
	
	PROCEDURE Clamp(x: FLOAT32): CHAR;
	BEGIN
		IF x < 0 THEN RETURN 0X;
		ELSIF x > 255 THEN RETURN 0FFX;
		ELSE RETURN CHR(ENTIER(x))
		END;
	END Clamp;


	OPERATOR ":="*(VAR l: ARRAY [4] OF FLOAT32; CONST r: Color); 
	BEGIN
		l[0]:=ORD(r[0]);
		l[1]:=ORD(r[1]);
		l[2]:=ORD(r[2]);
		l[3]:=ORD(r[3]);
	END ":=";


	OPERATOR ":="*(VAR l: ARRAY [4] OF SIGNED16; CONST r: Color); 
	BEGIN
		l[0]:=ORD(r[0]);
		l[1]:=ORD(r[1]);
		l[2]:=ORD(r[2]);
		l[3]:=ORD(r[3]);
	END ":=";

	OPERATOR ":="*(VAR l: Color; CONST r: ARRAY [4] OF FLOAT32);
	BEGIN
		l[0]:= Clamp(r[0]);
		l[1]:= Clamp(r[1]);
		l[2]:= Clamp(r[2]);
		l[3]:= Clamp(r[3]);
	END ":=";
	
	OPERATOR ":="*(VAR l: Color; CONST i: ARRAY [4] OF SIGNED32);
	BEGIN
	l[0] := Clamp(i[0]);
	l[1] := Clamp(i[1]);
	l[2] := Clamp(i[2]);
	l[3] := Clamp(i[3]);
	END ":=";
	
	OPERATOR ".*"*(CONST color: Color; CONST factor: ARRAY [4] OF FLOAT32): Color; (*elementwise scaling*)
	VAR res : Color;
	BEGIN
		res[0]:=Clamp(ORD(color[0])*factor[0]);	
		res[1]:=Clamp(ORD(color[1])*factor[1]);
		res[2]:=Clamp(ORD(color[2])*factor[2]);
		res[3]:=Clamp(ORD(color[3])*factor[3]);
		RETURN res
	END ".*"; 

	OPERATOR "*"*(CONST factor:FLOAT32; CONST color:Color):Color;  (* BGRA, color scaling *)
	VAR res : Color;
	BEGIN
		res[0]:=Clamp(ORD(color[0])*factor);
		res[1]:=Clamp(ORD(color[1])*factor);
		res[2]:=Clamp(ORD(color[2])*factor);
		res[3]:=color[3];
		RETURN res
	END "*";

	OPERATOR "*"*(CONST left, right:Color):Color;  (* BGRA, color mixing *)
	VAR res : Color;
	BEGIN
		res[0]:=CHR((ORD(left[0])+ORD(right[0])) DIV 2); 
		res[1]:=CHR((ORD(left[1])+ORD(right[1])) DIV 2); 
		res[2]:=CHR((ORD(left[2])+ORD(right[2])) DIV 2); 
		res[3]:=CHR((ORD(left[3])+ORD(right[3])) DIV 2); 
		RETURN res
	END "*";

	OPERATOR "+"*(CONST left,right:Color):Color; (* addition swith saturation of BGR components ; A is inherited from left *)
	VAR res:Color;
	BEGIN
		res[0]:=Clamp(ORD(left[0])+ORD(right[0])); 
		res[1]:=Clamp(ORD(left[1])+ORD(right[1])); 
		res[2]:=Clamp(ORD(left[2])+ORD(right[2])); 
		res[3]:=left[3]; 
		RETURN res
	END "+";

	OPERATOR "#"*(CONST l,r:Color):BOOLEAN; 
	BEGIN
		RETURN SYSTEM.VAL(UNSIGNED32,l)#SYSTEM.VAL(UNSIGNED32,r)
	END "#";
	
	OPERATOR "="*(CONST l,r:Color):BOOLEAN; 
	BEGIN
		RETURN SYSTEM.VAL(UNSIGNED32,l)=SYSTEM.VAL(UNSIGNED32,r)
	END "=";
*)


(* SSE *)


	OPERATOR -":="*(VAR l:Color; r:UNSIGNED32); 
	BEGIN
		l:=SYSTEM.VAL(Color,r)
	END ":=";

	OPERATOR -":="*(VAR l:UNSIGNED32; CONST r:Color); 
	BEGIN
		l:=SYSTEM.VAL(UNSIGNED32,r)
	END ":=";


	OPERATOR -":="*(VAR l: ARRAY [4] OF FLOAT32; r {REGISTER}: Color);
	VAR zero{REGISTER} : Color; res{REGISTER}: ARRAY [4] OF FLOAT32;
	BEGIN
		CODE
			XORPS zero,zero; zeros
			PUNPCKLBW r, zero; unpack each byte, unsigned, pad with zeros
			PUNPCKLWD r, zero; unpack each word, unsigned, pad with zeros
			CVTDQ2PS r, r; to 32 bit floats
			MOVUPS res, r
		END;
		l := res;
	END ":=";

	OPERATOR -":="*(VAR l: ARRAY [4] OF SIGNED16; r {REGISTER}: Color);
	VAR zero{REGISTER} : Color;
		res{REGISTER}: ARRAY [4] OF SIGNED16;
	BEGIN
		CODE
			XORPS zero,zero; zeros
			PUNPCKLBW r, zero; unpack each byte, unsigned, pad with zeros
			MOVUPS res, r
		END;
		l := res
	END ":=";

	OPERATOR -":="*(VAR l: Color; r {REGISTER}: ARRAY [4] OF FLOAT32);
	VAR res{REGISTER}: VColor;
	BEGIN
		CODE
			CVTTPS2DQ r, r; convert packet floats to packed DWord integers
			PACKSSDW r, r;
			PACKUSWB r, r;
			MOVUPS res, r
		END;
		SYSTEM.VAL(VColor,l) := res;
	END ":=";
	
	OPERATOR -":="*(VAR l: Color; r {REGISTER}: ARRAY [4] OF UNSIGNED32);
	VAR res{REGISTER}: VColor;
	BEGIN
		CODE
			PACKSSDW r, r;
			PACKUSWB r, r;
			MOVUPS res, r
		END;	
		SYSTEM.VAL(VColor,l) := res;
	END ":=";

	
	OPERATOR -".*"*(color {REGISTER}: Color; factor {REGISTER}: ARRAY [4] OF FLOAT32):  VColor;
	VAR  res{REGISTER} : VColor; zero{REGISTER}: ARRAY [4] OF FLOAT32;
	BEGIN
	CODE
			XORPS zero, zero
			PUNPCKLBW color, zero; unpack each byte, unsigned, pad with zeros
			PUNPCKLWD color, zero; unpack each word, unsigned, pad with zeros
			CVTDQ2PS color, color; to 32 bit floats
			MULPS color, factor
			CVTTPS2DQ color, color; convert packet floats to packed DWord integers
			PACKSSDW color, color;
			PACKUSWB color, color;
		END;
		RETURN res;
	END ".*"; 

	OPERATOR -"*"*(factor {REGISTER}:FLOAT32; r {REGISTER}:Color):Color;  (* BGRA, color scaling *)
	(*CONST one=[0.0,0,0,1];*)
	VAR zero {REGISTER}: Color; o{REGISTER}: ARRAY[4] OF FLOAT32;
	BEGIN
		o := [0.0,0,0,1];
		CODE
			XORPS zero,zero; zeros
			PUNPCKLBW r, zero	; unpack each byte, unsigned, pad with zeros
			PUNPCKLWD r, zero	; unpack each word, unsigned, pad with zeros
			CVTDQ2PS r, r		; to 32 bit floats
			ADDPS factor,o	; factor at position 0; 1.0 at position 3 
			SHUFPS factor, factor, 0C0H; factor to positions 0..2; keep 1.0 at pos 3
			MULPS r, factor		;scale
			CVTPS2DQ r, r; convert to integer dword
			PACKSSDW r, r; pack to word
			PACKUSWB r, r; pack to byte with saturation
		END;
		RETURN r;
	END "*";

	OPERATOR -"*"*(left{REGISTER}, right{REGISTER}:Color):Color;  (* BGRA, color mixing *)
	BEGIN
		CODE
			PAVGB left, right; average unsigned byte
		END;
		RETURN left
	END "*";

	OPERATOR -"+"*(left{REGISTER},right{REGISTER}:Color):Color; (* BGRA, light addition; keep transparency of l *)
	BEGIN
		CODE
		PSLLDQ right, 1H ; shift 1 byte to the left 
		PSRLDQ right, 1H; shift back - rightmost byte is now = zero
		PADDUSB left, right; unsigned saturating addition, bytewise; for BGR components; component A is inherited from left
		END;
		RETURN left;
	END "+";

	OPERATOR -"#"*(CONST l,r:Color):BOOLEAN; 
	BEGIN
		RETURN SYSTEM.VAL(UNSIGNED32,l)#SYSTEM.VAL(UNSIGNED32,r)
	END "#";
	
	OPERATOR -"="*(CONST l,r:Color):BOOLEAN; 
	BEGIN
		RETURN SYSTEM.VAL(UNSIGNED32,l)=SYSTEM.VAL(UNSIGNED32,r)
	END "=";

VAR 
	noColor*,
	white*, transparent*, black*, 
	gray*, lightgray*, darkgray*,  
	red*, lightred*, dark*, darkred*,
	blue*, lightblue*, darkblue*,
	green*, lightgreen*, darkgreen*, 
	yellow*, lightyellow*, darkyellow*, 
	orange* :Color;


BEGIN

	noColor[0]:=CHR(255); noColor[1]:=CHR(255); noColor[2]:=CHR(255); noColor[3]:=CHR(0); 
	transparent[0]:=CHR(0); transparent[1]:=CHR(0); transparent[2]:=CHR(0); transparent[3]:=CHR(0);	
	white[0]:=CHR(255); white[1]:=CHR(255); white[2]:=CHR(255); white[3]:=CHR(255);
	black[0]:=CHR(0); black[1]:=CHR(0); black[2]:=CHR(0); black[3]:=CHR(255);
	dark[2]:=CHR(64); dark[3]:=CHR(255);	
	gray[0]:=CHR(128); gray[1]:=CHR(128); gray[2]:=CHR(128); gray[3]:=CHR(255);
	lightgray[0]:=CHR(192); lightgray[1]:=CHR(192); lightgray[2]:=CHR(192); lightgray[3]:=CHR(255);
	darkgray[0]:=CHR(96); darkgray[1]:=CHR(96); darkgray[2]:=CHR(96); darkgray[3]:=CHR(255);
	yellow[0]:=CHR(0); yellow[1]:=CHR(255); yellow[2]:=CHR(255); yellow[3]:=CHR(255);
	lightyellow[0]:=CHR(128); lightyellow[1]:=CHR(255); lightyellow[2]:=CHR(255); lightyellow[3]:=CHR(255);
	darkyellow[0]:=CHR(0); darkyellow[1]:=CHR(128); darkyellow[2]:=CHR(128); darkyellow[3]:=CHR(255);
	red[2]:=CHR(255); red[3]:=CHR(255);
	lightred[0]:=CHR(128); lightred[1]:=CHR(128); lightred[2]:=CHR(255); lightred[3]:=CHR(255);
	darkred[0]:=CHR(0); darkred[1]:=CHR(0); darkred[2]:=CHR(128); darkred[3]:=CHR(255);
	orange[0]:=CHR(0); orange[1]:=CHR(128); orange[2]:=CHR(255); orange[3]:=CHR(255); 
	blue[0]:=CHR(255); blue[3]:=CHR(255);
	lightblue[0]:=CHR(255); lightblue[1]:=CHR(128); lightblue[2]:=CHR(128); lightblue[3]:=CHR(255);
	darkblue[0]:=CHR(128); darkblue[1]:=CHR(0); darkblue[2]:=CHR(0); darkblue[3]:=CHR(255);
	green[1]:=CHR(255); green[3]:=CHR(255);
	lightgreen[0]:=CHR(128); lightgreen[1]:=CHR(255); lightgreen[2]:=CHR(128); lightgreen[3]:=CHR(255);
	darkgreen[0]:=CHR(0); darkgreen[1]:=CHR(128); darkgreen[2]:=CHR(0); darkgreen[3]:=CHR(255);
	
END Colors.

System.FreeDownTo Colors ~
