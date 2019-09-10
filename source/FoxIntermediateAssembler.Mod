MODULE FoxIntermediateAssembler; (** AUTHOR ""; PURPOSE ""; *)

IMPORT IntermediateCode := FoxIntermediateCode, FoxAssembler, D := Debugging, Scanner := FoxScanner, Basic := FoxBasic;

CONST Trace=FoxAssembler.Trace;
TYPE
	Register* = SIGNED32; (* index for InstructionSet.registers *)
	Operand* = IntermediateCode.Operand;

	TYPE
	Assembler*= OBJECT (FoxAssembler.Assembler)

		PROCEDURE Instruction*(CONST mnemonic: ARRAY OF CHAR);
		VAR i,numberOperands,mnem: SIGNED32; pos: Basic.Position; VAR operands: ARRAY 3 OF Operand; instruction: IntermediateCode.Instruction;

			PROCEDURE ParseOperand;
			(* stub, must be overwritten by implementation *)
			VAR operand: IntermediateCode.Operand;
				result: FoxAssembler.Result;
				register1,register2:SIGNED32;
				class1, class2: IntermediateCode.RegisterClass;
				stop,memory: BOOLEAN;
			BEGIN
				stop := FALSE;
				register1 := IntermediateCode.None;
				register2 := IntermediateCode.None;
				result.type := -1;
				result.value := 0;

				IF numberOperands >= 3 THEN Error(errorPosition,"too many operands")
				ELSE
					memory := ThisSymbol(Scanner.LeftBracket);
					IF (token.symbol = Scanner.Identifier) & IntermediateCode.DenotesRegister(token.identifierString,class1,register1) THEN
						NextToken;
						stop := ~ThisSymbol(Scanner.Plus);
					END;
					IF ~stop THEN
						IF (token.symbol = Scanner.Identifier) THEN
							IF IntermediateCode.DenotesRegister(token.identifierString,class2,register2) THEN
								NextToken;
							ELSIF GetNonConstant(errorPosition,token.identifierString,result) THEN
								NextToken;
							ELSIF Expression(result,FALSE) THEN
							END;
						ELSIF Expression(result,FALSE) THEN
						END;
					END;
					IF memory & ExpectSymbol(Scanner.RightBracket) THEN
						(*
						IntermediateCode.InitMemory(operand,register1,register2,result.value);
						*)
					ELSIF register1 # -1 THEN
						(*
						IntermediateCode.InitRegister(operand,0,register1);
						*)
					ELSE
						(*
						IntermediateCode.InitImmediate(operand,result.sizeInBits,result.value);
						*)
					END;
					(*
					IF result.fixup # NIL THEN
						IntermediateCode.AddFixup(operand,result.fixup);
					END;
					*)
					operands[numberOperands] := operand;
				END;
			END ParseOperand;

		BEGIN
			IF Trace THEN
				D.String("Instruction: "); D.String(mnemonic);  D.String(" "); D.Ln;
			END;
			pos := errorPosition;
			mnem := IntermediateCode.FindMnemonic(mnemonic);
			IF mnem >= 0 THEN
				FOR i := 0 TO 2 DO IntermediateCode.InitOperand(operands[i]) END;
				numberOperands := 0;
				IF token.symbol # Scanner.Ln THEN
					REPEAT
						ParseOperand;
						INC(numberOperands);
					UNTIL error OR ~ThisSymbol(Scanner.Comma);
				END;

				IF ~error THEN
					IntermediateCode.InitInstruction(instruction, pos, SIGNED8(mnem), operands[0], operands[1], operands[2]);
					section.Emit(instruction);
					(*

					mnem,operands[0],operands[1],operands[2],section.resolved);
					*)
				END

			ELSE
				ErrorSS(pos,"unknown instruction ",mnemonic)
			END
		END Instruction;

	END Assembler;

END FoxIntermediateAssembler.

System.Free FoxInlineAssembler FoxInlineInstructionSet ~
