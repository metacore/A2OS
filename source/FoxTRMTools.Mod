MODULE FoxTRMTools;
IMPORT Files,Commands,Options,Strings,Basic := FoxBasic, Diagnostics, BitSets,ObjectFile;

	(*! check spartan 6 code emission *)
	PROCEDURE PatchSpartan6(CONST this: ARRAY OF CHAR; VAR result: ARRAY OF CHAR; line: LONGINT);

	(*
		decode 36 bits 2 instruction big endian format
			35 ... 18				17 .. 0
			ins2_bit17 ... ins2_bit0 ins1_bit17 .. ins1_bit0

		to 2 x 18 bits instructions in the following form
			35			34			33..16					15..0
			ins2_bit17, ins2_bit16 ins1_bit17 ... inst1_bit0 ins2_bit15.. ins2_bit_0

	*)

	VAR inpos, outpos, i, bits, i1, i2, val: LONGINT;

		PROCEDURE ReadInt(): LONGINT;
		VAR c: CHAR;
		BEGIN
			c := this[inpos]; INC(inpos);
			CASE c OF
				'0' .. '9': RETURN ORD(c)- ORD('0')
				|'A'..'F': RETURN ORD(c) - ORD('A') + 10
				|'a'..'f': RETURN ORD(c) - ORD('a') + 10
			ELSE HALT(100) (* to be on the safe side *)
			END;
		END ReadInt;

		PROCEDURE WriteInt(i: LONGINT);
		VAR c: CHAR;
		BEGIN
			IF i < 0AH THEN c := CHR(i + ORD('0'))
			ELSIF i < 10H THEN c := CHR(i-10 + ORD('A'))
			ELSE HALT(100)
			END;
			result[outpos] := c; INC(outpos);
		END WriteInt;

	BEGIN
		(* decode *)
		inpos := 0; outpos := 0;
		WHILE (this[inpos] # 0X) & (this[inpos] <=" ") DO INC(inpos) END; (* skip spaces, if any *)
		i1 := 0; i2 := 0;

		IF this[inpos] # 0X THEN
			i2 := 0;
			(* upper most 16 bits of i2 *)
			FOR i := 0 TO 3 DO
				i2 := i2 * 10H + ReadInt();
			END;
			(* lower most 2 bits of i2 *)
			val := ReadInt();
			i2 := i2 * 4 + val DIV 4;
			(* upper most 2 bits of i1 *)
			i1 := val MOD 4;
			(* lower most 16 bits of i2 *)
			FOR i := 0 TO 3 DO
				i1 := i1 * 10H + ReadInt();
			END;

			(* make sure that no meaningful code is written to the "forbidden" islands *)
			ASSERT((line MOD 512 < 480) OR (line MOD 512 > 487) OR (i1 = 0) & (i2=0) OR (this = "fffffffff"));

			i := 0;
			(* upper most 2 bits of i1 and i2 *)
			WriteInt( (i2 DIV  10000H) * 4 + (i1 DIV 10000H) );
			i2 := i2 MOD 10000H; i1 := i1 MOD 10000H;
			(* remaining 16 bits of i1 *)
			bits := 10000H;
			FOR i := 0 TO 3 DO
				i1 := i1 MOD bits; bits := bits DIV 10H;
				WriteInt(i1 DIV bits);
			END;
			(* remaining 16 bits of i2 *)
			bits := 10000H;
			FOR i := 0 TO 3 DO
				i2 := i2 MOD bits; bits := bits DIV 10H;
				WriteInt(i2 DIV bits);
			END;
		END;
		result[outpos] := 0X;

	END PatchSpartan6;

	(*trm code file is split into columns. baseDiv words per line, line distributed onto numBase words.
		target --> target_base_<i>, horizontally running index <i>
	*)
	PROCEDURE SplitColumns* (CONST source,target: ARRAY OF CHAR; instructionWidth, numBase, baseDiv: LONGINT;diagnostics: Diagnostics.Diagnostics): BOOLEAN;
	VAR
		i,j,k,numReadNibbles,nibble,payloadInLeadingNibble,unCutWordLength:LONGINT;
		files: ARRAY 5 OF Files.File;
		writers: ARRAY 5 OF Files.Writer;
		currFileName: Files.FileName;
		base:  BitSets.BitSet;
		word: BitSets.BitSet;
		reader: Files.Reader;
		inputFileName: Files.FileName;
		inputFile: Files.File;
		line: ARRAY 128 OF CHAR;

	BEGIN
		(*generate multiple outupt files. horizontal split into blocks later using splitfiles*)
		FOR i:=0 TO numBase-1 DO(*create filenames*)
			(*copy name. add '.base i' to distinguish*)
			COPY(target,currFileName);
			(*Strings.Append(currFileName,"_base_");*)
			Basic.AppendNumber(currFileName, i);
			files[i]:= Files.New(currFileName);
			Files.OpenWriter(writers[i],files[i],0);
		END;

		unCutWordLength:= (numBase*36) DIV (baseDiv); (*a division of the base row may be longer than the actual word length*)
		payloadInLeadingNibble:=instructionWidth MOD 4;
		IF payloadInLeadingNibble=0 THEN payloadInLeadingNibble:=payloadInLeadingNibble+4; END;
		numReadNibbles:=instructionWidth DIV 4;
		IF payloadInLeadingNibble<4 THEN
			INC(numReadNibbles);
		END;
		COPY(source, inputFileName);
		inputFile := Files.Old(inputFileName);
		IF inputFile= NIL THEN
			diagnostics.Error(inputFileName,Diagnostics.Invalid,Diagnostics.Invalid,"could not open file");
			RETURN FALSE
		END;
		Files.OpenReader( reader,inputFile,0);
		NEW(base,numBase*36);
		NEW(word,instructionWidth);
		WHILE reader.Available()>0 DO (*assumes number of words is a multiple of baseDiv. make sure in static linker*)
			base.Zero;
			(*read a BASE line*)
			FOR k:=0 TO baseDiv-1 DO 
				(*read a word into the base*)
				word.Zero;
				j:=0;
				(*read 1 word from row into BASE bitset*)
				reader.LnEOT(line);
				(*TRACE(line);
				TRACE(payloadInLeadingNibble);
				TRACE(line[0]);*)
				(*read first nibble, removes padding*)
				nibble:=ObjectFile.CharacterToNibble(line[0]);
				j:=j+payloadInLeadingNibble;
				word.SetBits(instructionWidth-j,payloadInLeadingNibble, nibble);
				
				(*read rest*)
				FOR i:=1 TO numReadNibbles-1 DO
					(*TRACE(line[i]);*)
					nibble:=ObjectFile.CharacterToNibble(line[i]);
					j:=j+4;
					word.SetBits(instructionWidth-j,4,nibble);
				END;
				(*note there may be gaps because unCut is larger than insW*)
				BitSets.CopyBits(word,0,base,k*unCutWordLength,instructionWidth);
			END;
			FOR j:= 0 TO numBase-1 DO (*divide base into the columns*)
				(*write 36 bits to appropriate file*)	(*writing msb first*)	
				FOR k:=8 TO 0 BY -1 DO
					writers[j].Char(ObjectFile.NibbleToCharacter(base.GetBits((j)*36+k*4,4) ) );
				END;
				writers[j].Ln;
			END;
		END;
		FOR i:=0 TO numBase-1 DO
			writers[i].Update;
			Files.Register(files[i]);
		END;
		RETURN TRUE
	END SplitColumns;

	
	PROCEDURE DoSplitFiles*(CONST source, dest, extension: ARRAY OF CHAR; blocks, blockSize: LONGINT; verbose,strided,patchSpartan6: BOOLEAN; diagnostics: Diagnostics.Diagnostics): BOOLEAN;
	VAR line: LONGINT; fileName: Files.FileName; oldFile: Files.File;
		newFiles: POINTER TO ARRAY OF Files.File;
		reader: Files.Reader;
		writers: POINTER TO ARRAY OF Files.Writer;
		x: ARRAY 128 OF CHAR;
		i,fileNumber: LONGINT;
		linewidth: LONGINT;

		PROCEDURE GetFileName(index: LONGINT; VAR fileName: ARRAY OF CHAR);
		BEGIN
			COPY(dest,fileName);
			Basic.AppendNumber(fileName, index);
			Files.JoinExtension(fileName,extension,fileName);
		END GetFileName;



	BEGIN
	
		TRACE(source);
	
		COPY(source, fileName);
		oldFile := Files.Old(fileName);
		IF oldFile = NIL THEN
			diagnostics.Error(fileName,Diagnostics.Invalid,Diagnostics.Invalid,"could not open file");
			RETURN FALSE
		END;
		Files.OpenReader( reader,oldFile,0);

		NEW(newFiles, blocks);
		NEW(writers, blocks);

		FOR i := 0 TO blocks-1 DO
			GetFileName(i,fileName);
			newFiles[i] := Files.New(fileName);
			IF newFiles[i]= NIL THEN
				diagnostics.Error(fileName,Diagnostics.Invalid,Diagnostics.Invalid,"could not open file");
				RETURN FALSE
			ELSE
				Files.OpenWriter(writers[i],newFiles[i],0);
			END;
			IF verbose THEN
				diagnostics.Information(fileName,Diagnostics.Invalid,Diagnostics.Invalid,"file generated");
			END;
		END;
		(*If strided: read line by line, fill round robin into the output files*)
		line := 0;
		WHILE (line < blocks*blockSize) & (reader.Available()>0) DO
			IF strided THEN fileNumber := line MOD blocks ELSE fileNumber := line DIV blockSize END;
			reader.LnEOT(x);
			IF linewidth = 0 THEN linewidth := Strings.Length(x) END;
			IF patchSpartan6 THEN PatchSpartan6(x,x, line) END;
			writers[fileNumber].String(x); writers[fileNumber].Ln;
			INC(line);
		END;
		ASSERT((linewidth = 8) OR (linewidth =9) OR (linewidth = 0));
		WHILE line < blocks*blockSize DO
			IF strided THEN fileNumber := line MOD blocks ELSE fileNumber := line DIV blockSize END;
			FOR i := 0 TO linewidth-1 DO
				writers[fileNumber].Char("0");
			END;
			writers[fileNumber].Ln;
			INC(line);
		END;
		IF reader.Available()>0 THEN
			diagnostics.Warning(source,Diagnostics.Invalid,Diagnostics.Invalid,"source file truncated");
		END;
		FOR i := 0 TO blocks-1 DO
			writers[i].Update; Files.Register(newFiles[i])
		END;
		RETURN TRUE
	END DoSplitFiles;


	PROCEDURE SplitFiles* (context: Commands.Context);
	VAR options: Options.Options;
		sourceName, name, extension: Files.FileName;
		blocks: LONGINT;
		blockSize: LONGINT;
		strided: BOOLEAN;
		diagnostics: Diagnostics.StreamDiagnostics;
		done: BOOLEAN;
	BEGIN
		NEW (options);
		options.Add('b',"blocks",Options.Integer);
		options.Add('s',"blockSize",Options.Integer);
		options.Add('S',"strided",Options.Flag);
		options.Add(0X,"patchSpartan6", Options.Flag);

		IF ~options.Parse (context.arg, context.error) THEN context.result := Commands.CommandParseError; RETURN; END;
		IF ~options.GetInteger("blocks",blocks) THEN blocks := 1 END;
		IF ~options.GetInteger("blockSize",blockSize) THEN blockSize := 1024 END;
		strided := options.GetFlag("strided");
		NEW(diagnostics,context.out);

		done := TRUE;
		WHILE done & context.arg.GetString (name) DO
			Files.SplitExtension(name,sourceName,extension);
			done := DoSplitFiles(name, sourceName, extension, blocks, blockSize, TRUE, strided, options.GetFlag("patchSpartan6"), diagnostics);
		END;
	END SplitFiles;

	(*numBase words of 36 bits each are assembled to a base, and each base holds baseDiv words of 18 bits each.*)
	PROCEDURE SplitColumnsCmd* (context: Commands.Context);  (*todo: rename as splitColumns, fix all call sites*)
	VAR options: Options.Options;
		name: Files.FileName;
		insW,numB,baseD: LONGINT;
		diagnostics: Diagnostics.StreamDiagnostics;
		done: BOOLEAN;
		targetName: ARRAY 128 OF CHAR;
	BEGIN
		NEW (options);
		options.Add('i',"instructionWidth",Options.Integer);
		options.Add('n',"numBases",Options.Integer);
		options.Add('b',"baseDivider",Options.Integer);
		options.Add('t',"target",Options.String);

		IF ~options.Parse (context.arg, context.error) THEN context.result := Commands.CommandParseError; RETURN; END;
		IF ~options.GetInteger("instructionWidth",insW) THEN insW:= 18 END;
		IF ~options.GetInteger("numBases",numB) THEN numB:=1 END;
		IF ~options.GetInteger("baseDivider",baseD) THEN baseD:=2 END;
		IF ~options.GetString("target",targetName) THEN targetName:="default.mem" END;
		NEW(diagnostics,context.out);
		
		diagnostics.Information("target name", 0, 0, targetName);
		done:=TRUE;
		WHILE done & context.arg.GetString (name) DO
		
			diagnostics.Information("source name", 0, 0, name);
			done := SplitColumns(name,  targetName, insW, numB, baseD, diagnostics);
		END;
	END SplitColumnsCmd;


	PROCEDURE CompareFiles*(context: Commands.Context);
	VAR f1,f2,f3: Files.File; name1, name2, matrixname: Files.FileName; r1, r2: Files.Reader;  x,y: ARRAY 32 OF CHAR; i: LONGINT; line1: LONGINT;
		matrix: ARRAY 16 OF ARRAY 16 OF LONGINT; j: LONGINT; p1, p2: LONGINT; writer: Files.Writer;

		PROCEDURE Value(c: CHAR): LONGINT;
		BEGIN
			CASE c OF
				'0' .. '9': RETURN  ORD(c)- ORD('0')
				|'A'..'F': RETURN  ORD(c) - ORD('A') + 10
				|'a'..'f': RETURN  ORD(c) - ORD('a') + 10
			ELSE HALT(100) (* to be on the safe side *)
			END;

		END Value;

	BEGIN
		IF context.arg.GetString(name1) & context.arg.GetString(name2) &  context.arg.GetString(matrixname) THEN
			f1 := Files.Old(name1); f2 := Files.Old(name2); f3 := Files.New(matrixname);
			NEW(r1,f1,0); NEW(r2,f2,0); NEW(writer, f3,0);
			WHILE (r1.Available() > 0) & (r2.Available() > 0) DO
				r1.LnEOT(x);r2.LnEOT(y);

				IF (line1 MOD 512 >= 480) & (line1 MOD 512 <= 487) THEN
					p1 := (Value(x[0]) DIV 4H)*4H+Value(x[4]) MOD 4H;
					p2 := (Value(y[0]) DIV 4H)*4H+Value(y[4]) MOD 4H;
					context.out.Int(line1,1); context.out.Ln; context.out.Update;
					ASSERT(Value(x[0]) MOD 4 = Value(y[0]) MOD 4);
					ASSERT(Value(x[4]) DIV 4 = Value(y[4]) DIV 4);
					INC(matrix[p1, p2]);
				ELSE
					ASSERT(x = y);
				END;
				INC(line1);


				(*
				IF (line1 MOD 512 = 480)  THEN
					context.out.Int(line1,1); context.out.String(":");
					WHILE line1 MOD 512 < 487 DO
					r1.LnEOT(x);
					i := 0;
					WHILE (x[i] # 0X) DO
						IF i IN {0,4} THEN
						WriteBits(x[i]);
						ELSE
						context.out.Char(x[i]);
						END;
						context.out.String("|");
						INC(i);
					END;
					context.out.String(" ");
					INC(line1);
					END;

					WriteLn;
					context.out.Int(line2,1); context.out.String(":");
					WHILE line2 MOD 512 < 487 DO
					r2.LnEOT(y);
					i := 0;
					WHILE (y[i] # 0X) DO
						IF i IN {0,4} THEN
						WriteBits(y[i]);
						ELSE context.out.Char(y[i]);
						END;
						context.out.String("|");
						INC(i)
					END;
					context.out.String(" ");
					INC(line2);
					END;

					WriteLn;
					WriteLn;
				ELSE INC(line1); INC(line2);r1.LnEOT(x);r2.LnEOT(y);

				END;
				*)
			END;


			FOR i := 0 TO 15 DO
			FOR j := 0 TO 15 DO
				writer.Int(matrix[i,j],1); writer.String(" ");
				context.out.Int(matrix[i,j],1); context.out.String(" ");
			END;
				context.out.Ln;
				writer.Ln;
			END;
			writer.Update;
			Files.Register(f3);
		END;
	END CompareFiles;
	(*
	PROCEDURE SameFiles(CONST filename1, filename2: ARRAY OF CHAR): BOOLEAN;
	VAR
		file1, file2 : Files.File; reader1, reader2 : Files.Reader; ch1, ch2 : CHAR;
	BEGIN
		file1 := Files.Old(filename1);
		IF (file1# NIL) THEN
			file2 := Files.Old(filename2);
			IF (file2 # NIL) THEN
				IF (file1.Length() = file2.Length()) THEN
					NEW(reader1, file1, 0);
					NEW(reader2, file2, 0);
					REPEAT
						reader1.Char(ch1);
						reader2.Char(ch2);
					UNTIL (ch1 # ch2) OR (reader1.res # Files.Ok) OR (reader2.res # Files.Ok);

					IF (ch1 = ch2) & (reader1.res = reader2.res) & (reader1.res = Streams.EOF) THEN
						RETURN TRUE;
					ELSE
						RETURN FALSE;
					END;
				ELSE
					RETURN FALSE;
				END;
			ELSE
				RETURN FALSE;
			END;
		ELSE
			RETURN FALSE;
		END;
	END SameFiles;
	*)
	(*
	PROCEDURE DeleteFiles(CONST fileSelectionMask: ARRAY OF CHAR; context: Commands.Context; VAR res: WORD);
	VAR
		enum: Files.Enumerator;
		flags: SET;
		time, date, size: LONGINT;
		name: Files.FileName;
	BEGIN
		NEW(enum);
		enum.Open(fileSelectionMask,{});

		res := 0;
		WHILE (res = 0) & enum.GetEntry(name,flags,time,date,size) DO
			IF ~(Files.Directory IN flags) THEN
				context.out.String("deleting file "); context.out.String(name); context.out.String(" ...");
				Files.Delete(name,res);
				IF res = 0 THEN context.out.String(" Ok"); context.out.Ln; context.out.Update;
				ELSE
					context.error.String("failed to delete file "); context.error.String(name); context.error.String(", res="); context.error.Int(res,0); context.error.Ln; context.error.Update;
				END;
			END;
		END;
	END DeleteFiles;
	*)


END FoxTRMTools.

FoxTRMTools.Test ~

Compiler.Compile -b=TRM --objectFile=Intermediate --activeCells --noRuntimeChecks --activeCellsSpecification=FoxAVSP6LX75T --patchSpartan6
oc/TRM.RS232.Mod
oc/TRM.Testing.Mod
oc/TRM.Runtime.Mod
oc/TRM.TestNet.Mdf
~

Compiler.Compile -b=TRM --objectFile=Intermediate --activeCells --noRuntimeChecks --activeCellsSpecification=ML505
oc/TRM.RS232.Mod
oc/TRM.Testing.Mod
oc/TRM.Runtime.Mod
oc/TRM.TestNet.Mdf
~


FoxAVSP6LX75T.ReadSpecification TestNet ~

FoxTRMTools.BuildHardware -p="AVSP6LX75T" -f="TestNet" ~

FoxTRMTools.BuildHardware -p="ML505" -f="TestNet" ~

SystemTools.Free FoxTRMTools ~

FoxTRMTools.SplitFiles  code.mem data.mem ~
FoxTRMTools.SplitFiles  --blocks=8 --strided data.mem ~
PET.Open data.mem ~
PET.Open data0.mem ~
PET.Open data1.mem ~


FoxTRMTools.GenerateTestFile test.code ~
FoxTRMTools.GenerateTestFile --value=010H test.code ~
FoxTRMTools.GenerateTestFile --random test.code ~
FoxTRMTools.GenerateTestFile --sourceFile=binary.code test2.code ~

FoxTRMTools.SplitFiles  --blockSize=1024 --blocks=5 test.code ~

PET.Open -e test.code test2.code ~

FoxTRMTools.CompareFiles test.code test2.code matrix.txt ~



UARTPC.Open 6 ~

SystemTools.DoCommands

FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


SystemTools.Show "DONE!" ~
~




SystemTools.DoCommands

FoxTRMTools.GenerateTestFile --random --size=512 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=1 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 1024 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~

~


M = {};

file =fopen('bram.mtx')
A = fscanf(file,'%d');
fclose(file)
A = reshape(A,16,16);

M{numel(M)+1}=A;