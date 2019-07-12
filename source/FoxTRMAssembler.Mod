MODULE FoxTRMAssembler; (** AUTHOR ""; PURPOSE ""; *)

IMPORT InstructionSet := FoxTRMInstructionSet, FoxAssembler, D := Debugging, Scanner := FoxScanner, Diagnostics, Basic := FoxBasic;

CONST Trace=FoxAssembler.Trace;

TYPE
	Register* = LONGINT; (* index for InstructionSet.registers *)
	Operand* = InstructionSet.Operand;

TYPE
	Assembler*= OBJECT (FoxAssembler.Assembler)
	VAR capabilities-: SET;
		instructionSet: InstructionSet.InstructionSet;

		PROCEDURE &Init2*(diagnostics: Diagnostics.Diagnostics; capabilities: SET; instructionSet: InstructionSet.InstructionSet);
		BEGIN
			SELF.capabilities := capabilities;
			SELF.instructionSet:=instructionSet;
			Init(diagnostics);
		END Init2;

		PROCEDURE Instruction*(CONST mnemonic: ARRAY OF CHAR);
		VAR i,numberOperands,mnem: LONGINT; VAR operands: ARRAY 3 OF Operand; instruction: InstructionSet.Instruction;
			pos: Basic.Position;

			PROCEDURE ParseOperand;
			(* stub, must be overwritten by implementation *)
			VAR operand: InstructionSet.Operand;
				result: FoxAssembler.Result;
				register1,register2: SHORTINT;
				stop,memory: BOOLEAN;
			BEGIN
				stop := FALSE;
				register1 := InstructionSet.None;
				register2 := InstructionSet.None;
				result.type := -1;
				result.value := 0;

				IF numberOperands >= 2 THEN Error(errorPosition,"too many operands")
				ELSE
					memory := ThisSymbol(Scanner.LeftBracket);
					IF (token.symbol = Scanner.Identifier) & GetRegister(token.identifierString,register1) THEN
						NextToken;
						stop := ~ThisSymbol(Scanner.Plus);
					END;
					IF ~stop THEN
						IF (token.symbol = Scanner.Identifier) THEN
							IF GetRegister(token.identifierString,register2) THEN
								NextToken;
							ELSIF GetNonConstant(errorPosition,token.identifierString, result) THEN
								NextToken;
							ELSIF Expression(result,FALSE) THEN
							END;
						ELSIF Expression(result,FALSE) THEN
						END;
					END;
					IF memory & ExpectSymbol(Scanner.RightBracket) THEN
						instructionSet.InitMemory(operand,register1,LONGINT(result.value));
					ELSIF register1 # -1 THEN
						instructionSet.InitRegister(operand,register1);
					ELSE
						instructionSet.InitImmediate(operand,result.sizeInBits,LONGINT(result.value));
					END;
					IF result.fixup # NIL THEN
						instructionSet.AddFixup(operand,result.fixup);
					END;
					operands[numberOperands] := operand;
				END;
			END ParseOperand;

		BEGIN
			IF Trace THEN
				D.String("Instruction: "); D.String(mnemonic);  D.String(" "); D.Ln;
			END;
			pos := errorPosition;
			mnem := instructionSet.FindMnemonic(mnemonic);
			IF mnem >= 0 THEN
				FOR i := 0 TO 2 DO instructionSet.InitOperand(operands[i]) END;
				numberOperands := 0;
				IF token.symbol # Scanner.Ln THEN
					REPEAT
						ParseOperand;
						INC(numberOperands);
					UNTIL error OR ~ThisSymbol(Scanner.Comma);
				END;
				IF ~error THEN
					instructionSet.MakeInstruction(instruction,mnem,operands[0],operands[1]);
					IF instruction.format = InstructionSet.None THEN
						ErrorSS(pos,"operand instruction format mismatch",mnemonic);
					ELSIF instructionSet.instructionFormats[instruction.format].capabilities > capabilities THEN
						Error(pos,"instruction not supported");
					ELSE
						IF pass < FoxAssembler.MaxPasses THEN
							(* not last pass: only increment the current PC by a unit *)
							section.resolved.SetPC(section.resolved.pc + 1)
						ELSE
							instructionSet.EmitInstruction(instruction, mnem, section.resolved);
						END;
					END;
				END
			ELSE
				ErrorSS(pos,"unknown instruction ",mnemonic)
			END
		END Instruction;

		PROCEDURE GetRegister(CONST ident: ARRAY OF CHAR; VAR register: SHORTINT): BOOLEAN;
		BEGIN
			register := instructionSet.FindRegister(ident);
			RETURN register # InstructionSet.None
		END GetRegister;
	END Assembler;

END FoxTRMAssembler.

System.Free FoxTRMAssembler FoxTRMInstructionSet ~
