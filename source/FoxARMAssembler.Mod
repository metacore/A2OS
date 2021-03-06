MODULE FoxARMAssembler; (** AUTHOR ""; PURPOSE ""; *)

IMPORT InstructionSet := FoxARMInstructionSet, FoxAssembler,  (*D := Debugging,*) Scanner := FoxScanner, Diagnostics, Strings, Basic := FoxBasic;

CONST Trace = FoxAssembler.Trace;

TYPE
	Assembler* = OBJECT(FoxAssembler.Assembler)
	VAR
		PROCEDURE & Init2*(diagnostics: Diagnostics.Diagnostics);
		BEGIN Init(diagnostics)
		END Init2;

		(** parse a register name **)
		PROCEDURE GetRegister*(VAR registerNumber: SIGNED32): BOOLEAN;
		VAR
			result: BOOLEAN;
		BEGIN
			registerNumber := InstructionSet.None;
			result := FALSE;
			IF token.symbol = Scanner.Identifier THEN
				registerNumber := InstructionSet.RegisterNumberFromName(token.identifierString);
				IF registerNumber # InstructionSet.None THEN
					result := TRUE;
					NextToken
				END
			END;
			RETURN result
		END GetRegister;

		PROCEDURE GetRegisterList(VAR registerList: SET): BOOLEAN;
		VAR num: SIGNED32;
		BEGIN
			registerList := {};
			IF token.symbol = Scanner.LeftBrace THEN
				REPEAT
					NextToken;
					IF GetRegister(num) THEN
						IF (num > 16) THEN
							Error(errorPosition, "invalid register in list (not yet implemented)")
						END;
						INCL(registerList, num);
					END;
				UNTIL token.symbol # Scanner.Comma;
				IF token.symbol # Scanner.RightBrace THEN
					Error(errorPosition, "'}' expected.")
				ELSE
					NextToken;
					RETURN TRUE
				END;
			END;
			RETURN FALSE;
		END GetRegisterList;

		(** parse a special register name, along with fields **)
		PROCEDURE GetSpecialRegisterWithFields(VAR registerNumber: SIGNED32; VAR fields: SET): BOOLEAN;
		VAR
			result: BOOLEAN;
			i: SIZE;
			strings: Strings.StringArray;
		BEGIN
			result := FALSE;
			registerNumber := InstructionSet.None;
			fields := {};

			IF token.symbol = Scanner.Identifier THEN
				strings := Strings.Split(token.identifierString, '_'); (* split the identifier at the underscore symbol *)
				IF LEN(strings) = 2 THEN
					IF (strings[0]^ = "CPSR") OR (strings[0]^ = "SPSR") THEN
						IF strings[0]^ = "CPSR" THEN registerNumber := InstructionSet.CPSR
						ELSE registerNumber := InstructionSet.SPSR
						END;
						IF strings[1]^ # "" THEN
							FOR i := 0 TO LEN(strings[1]) - 1 DO
								CASE strings[1][i] OF
								| 'f': INCL(fields, InstructionSet.fieldF)
								| 's': INCL(fields, InstructionSet.fieldS)
								| 'x': INCL(fields, InstructionSet.fieldX)
								| 'c': INCL(fields, InstructionSet.fieldC)
								ELSE
								END
							END;
							result := TRUE;
							NextToken
						END
					END
				END
			END;
			RETURN result
		END GetSpecialRegisterWithFields;

		(** parse a shift mode name **)
		PROCEDURE GetShiftMode*(VAR shiftModeNumber: SIGNED32): BOOLEAN;
		VAR
			result: BOOLEAN;
		BEGIN
			shiftModeNumber := InstructionSet.None;
			result := FALSE;
			IF token.symbol = Scanner.Identifier THEN
				shiftModeNumber := InstructionSet.ShiftModeNumberFromName(token.identifierString);
				IF shiftModeNumber # InstructionSet.None THEN
					result := TRUE;
					NextToken
				END
			END;
			RETURN result
		END GetShiftMode;

		(** parse a coprocessor name **)
		PROCEDURE GetCoprocessor*(VAR coprocessorNumber: SIGNED32): BOOLEAN;
		VAR
			result: BOOLEAN;
		BEGIN
			coprocessorNumber := InstructionSet.None;
			result := FALSE;

			IF token.symbol = Scanner.Identifier THEN
				coprocessorNumber := InstructionSet.CoprocessorNumberFromName(token.identifierString);
				IF coprocessorNumber # InstructionSet.None THEN
					result := TRUE;
					NextToken
				END
			END;

			RETURN result
		END GetCoprocessor;

		(* parse coprocessor opcode *)
		PROCEDURE GetCoprocessorOpcode*(VAR coprocessorOpcode: SIGNED32): BOOLEAN;
		VAR
			result: BOOLEAN;
		BEGIN
			IF (token.symbol = Scanner.Number) & (token.numberType = Scanner.Integer) & (token.integer >= 0) & (token.integer <= 7) THEN
				coprocessorOpcode := SIGNED32(token.integer);
				result := TRUE;
				NextToken
			ELSE
				coprocessorOpcode := InstructionSet.None;
				result := FALSE
			END;
			RETURN result
		END GetCoprocessorOpcode;

		(** parse any expression that evaluates to a constant value **)
		PROCEDURE GetPlainValue*(VAR value: SIGNED32): BOOLEAN;
		VAR
			assemblerResult: FoxAssembler.Result;
			result: BOOLEAN;
		BEGIN
			IF Expression(assemblerResult, FALSE) & ((assemblerResult.type = FoxAssembler.ConstantInteger) OR (assemblerResult.type = FoxAssembler.Offset)) THEN
				value := SIGNED32(assemblerResult.value);
				result := TRUE
			ELSE
				value := 0;
				result := FALSE
			END;
			RETURN result
		END GetPlainValue;

		(** parse an ARM immediate value
			i.e., the '#'-sign followed by any expression that evaluates to a constant value
		**)
		PROCEDURE GetImmediateValue*(VAR immediateValue: SIGNED32): BOOLEAN;
		BEGIN RETURN ThisSymbol(Scanner.Unequal) & GetPlainValue(immediateValue)
		END GetImmediateValue;

		PROCEDURE Instruction*(CONST mnemonic: ARRAY OF CHAR);
		VAR
			instruction: InstructionSet.Instruction;
			operands: ARRAY InstructionSet.MaxOperands OF InstructionSet.Operand;
			position: Basic.Position;
			opCode, condition, i, operandNumber: SIGNED32;
			flags: SET;
			newOperandExpected: BOOLEAN;
			result: FoxAssembler.Result;

			(** parse an operand
				- note that a subsequent comma is consumed as well
				- 'newOperandExpected' indicates if any more operands are expected
			**)
			PROCEDURE ParseOperand;
			VAR
				operand: InstructionSet.Operand;
				indexingMode, fields: SET;
				registerNumber, offsetRegisterNumber, shiftModeNumber, shiftRegisterNumber, shiftImmediateValue, offsetImmediateValue, value: SIGNED32;
				position: Basic.Position;
				isImmediateOffset, bracketIsOpen: BOOLEAN;
				registerList: SET;
			BEGIN
				newOperandExpected := FALSE;
				position := errorPosition;
				IF operandNumber >= InstructionSet.MaxOperands THEN
					Error(position, "too many operands")
				ELSE
					InstructionSet.InitOperand(operand);
					IF ThisSymbol(Scanner.LeftBracket) THEN
						bracketIsOpen := TRUE;
						(* memory operand *)
						indexingMode := {};
						IF GetRegister(registerNumber) THEN
							IF ThisSymbol(Scanner.RightBracket) THEN
								bracketIsOpen := FALSE;
								(* post indexing *)
								INCL(indexingMode, InstructionSet.PostIndexed)
							END;
							IF ExpectSymbol(Scanner.Comma) THEN
								IF GetImmediateValue(offsetImmediateValue) THEN
									(* immediate offset memory operand *)
									isImmediateOffset := TRUE;
									IF ABS(offsetImmediateValue) < InstructionSet.Bits12 THEN
										IF offsetImmediateValue >= 0 THEN
											INCL(indexingMode, InstructionSet.Increment)
										ELSE
											INCL(indexingMode, InstructionSet.Decrement)
										END;
										offsetImmediateValue := ABS(offsetImmediateValue)
									ELSE
										Error(errorPosition, "immediate offset is out of range")
									END
								ELSE
									(* register offset memory operand *)
									isImmediateOffset := FALSE;

									(* parse sign *)
									IF ThisSymbol(Scanner.Plus) THEN
										INCL(indexingMode, InstructionSet.Increment)
									ELSIF ThisSymbol(Scanner.Minus) THEN
										INCL(indexingMode, InstructionSet.Decrement)
									ELSE
										Error(errorPosition, "plus or minus sign expected")
									END;

									IF ~error THEN
										(* parse offset register *)
										IF GetRegister(offsetRegisterNumber) THEN
											shiftModeNumber := InstructionSet.None;
											shiftImmediateValue := 0;
											(* parse optional shift *)
											IF GetShiftMode(shiftModeNumber) THEN
												IF GetImmediateValue(shiftImmediateValue) THEN
													IF shiftImmediateValue >= InstructionSet.Bits5 THEN
														Error(errorPosition, "immediate shift amount is out of range")
													END
												ELSE
													Error(errorPosition, "immediate shift amount expected")
												END
											END
										ELSE
											Error(errorPosition, "register expected")
										END
									END
								END
							END;

							IF bracketIsOpen THEN
								IF ExpectSymbol(Scanner.RightBracket) THEN
									IF ThisSymbol(Scanner.ExclamationMark) THEN
										(* preindexing *)
										INCL(indexingMode, InstructionSet.PreIndexed)
									END
								END
							END
						ELSIF GetPlainValue(offsetImmediateValue) THEN
							(* pc label of the form [labelName], translated to [PC, #labelName - $ - 8] *)
							registerNumber := InstructionSet.PC;
							isImmediateOffset := TRUE;
							DEC(offsetImmediateValue, 8);
							DEC(offsetImmediateValue, code.pc(SIGNED32));
							IF ABS(offsetImmediateValue) < InstructionSet.Bits12 THEN
								IF offsetImmediateValue >= 0 THEN
									INCL(indexingMode, InstructionSet.Increment)
								ELSE
									INCL(indexingMode, InstructionSet.Decrement)
								END;
								offsetImmediateValue := ABS(offsetImmediateValue)
							ELSE
								Error(errorPosition, "immediate offset is out of range")
							END;
							IF ExpectSymbol(Scanner.RightBracket) THEN
							END;
						ELSE
							Error(errorPosition, "register expected")
						END;

						IF ~error THEN
							IF isImmediateOffset THEN
								InstructionSet.InitImmediateOffsetMemory(operand, registerNumber, offsetImmediateValue, indexingMode)
							ELSE
								InstructionSet.InitRegisterOffsetMemory(operand, registerNumber, offsetRegisterNumber, shiftModeNumber, shiftImmediateValue, indexingMode);
							END
						END

					ELSIF GetSpecialRegisterWithFields(registerNumber, fields) THEN
						ASSERT((registerNumber = InstructionSet.CPSR) OR (registerNumber = InstructionSet.SPSR));
						InstructionSet.InitRegisterWithFields(operand, registerNumber, fields);

					ELSIF GetRegister(registerNumber) THEN
						(* register *)
						shiftModeNumber := InstructionSet.None; (* defaults *)
						shiftRegisterNumber := InstructionSet.None;
						shiftImmediateValue := 0;

						IF ThisSymbol(Scanner.ExclamationMark) THEN
							INCL(flags, InstructionSet.flagBaseRegisterUpdate);
						END;
						IF ThisSymbol(Scanner.Comma) THEN
							(* parse shift mode *)
							IF GetShiftMode(shiftModeNumber) THEN
								IF shiftModeNumber # InstructionSet.shiftRRX THEN (* RRX shift amount is always 1 *)
									(* parse shift amount *)
									IF ~GetRegister(shiftRegisterNumber) & ~GetImmediateValue(shiftImmediateValue) THEN
										Error(position, "invalid shift amount")
									END
								END
							ELSE
								newOperandExpected := TRUE
							END
						END;
						IF ~error THEN
							InstructionSet.InitRegister(operand, registerNumber, shiftModeNumber, shiftRegisterNumber, shiftImmediateValue)
						END
					ELSIF GetRegisterList(registerList) THEN
						InstructionSet.InitRegisterList(operand, InstructionSet.R0, registerList);
						IF ThisSymbol(Scanner.Arrow) THEN
							INCL(flags, InstructionSet.flagUserMode);
						END;

					ELSIF GetCoprocessor(value) THEN
						(* coprocessor name *)
						InstructionSet.InitCoprocessor(operand, value)

					ELSIF GetCoprocessorOpcode(value) THEN (* integer constant in the range 0 .. 7 *)
						(* coprocessor opcode *)
						InstructionSet.InitOpcode(operand, value)

					ELSIF GetImmediateValue(value) THEN (* expression that evaluates to constant value starting with '#' *)
						(* ARM immediate value *)
						InstructionSet.InitImmediate(operand, value)

					ELSIF GetNonConstant(errorPosition,token.identifierString, result) THEN
						InstructionSet.InitImmediate(operand,SIGNED32(result.value));
						IF result.fixup # NIL THEN
							InstructionSet.AddFixup(operand,result.fixup);
						END;
						NextToken;
					ELSIF GetPlainValue(value) THEN (* expression that evaluates to constant value *)
						(* resolved label name *)
						InstructionSet.InitImmediate(operand, value)

					ELSE
						Error(position, "invalid operand")
					END;

					IF ThisSymbol(Scanner.ExclamationMark) THEN
						INCL(flags, InstructionSet.flagBaseRegisterUpdate);
					END;

					IF ~newOperandExpected THEN newOperandExpected := ThisSymbol(Scanner.Comma) END; (* a comma means that there is one more operand *)

					operands[operandNumber] := operand;

				END
			END ParseOperand;

		BEGIN
			(*
			IF Trace THEN D.String("Instruction: "); D.String(mnemonic);  D.String(" "); D.Ln END;
			*)

			position := errorPosition;
			IF InstructionSet.FindMnemonic(mnemonic, opCode, condition, flags) THEN

				(*IF Trace THEN
					D.String("    opCode="); D.Int(opCode, 0); D.Ln;
					D.String("    condition="); D.Int(condition, 0); D.Ln;
					D.String("    flags="); D.Set(flags); D.Ln;
				END;*)

				FOR i := 0 TO InstructionSet.MaxOperands - 1 DO
					InstructionSet.InitOperand(operands[i])
				END;

				operandNumber := 0;
				IF token.symbol # Scanner.Ln THEN
					REPEAT
						ParseOperand;

						INC(operandNumber);
					UNTIL error OR ~newOperandExpected;
				END;

				IF ~error THEN
					IF ~InstructionSet.MakeInstruction(instruction, opCode, condition, flags, operands) THEN
						ErrorSS(position, "wrong instruction format: ", mnemonic);
					ELSE
						IF pass < FoxAssembler.MaxPasses THEN
							(* not last pass: only increment the current PC by 4 units *)
							section.resolved.SetPC(section.resolved.pc + 4)
						ELSE
							(* last pass: emit the instruction *)
							IF ~InstructionSet.EmitInstruction(instruction, section.resolved) THEN
								ErrorSS(position, "wrong instruction format (encoding failed): ", mnemonic);
							END;
						END
					END
				END
			ELSE
				ErrorSS(position, "unknown mnemonic: ", mnemonic)
			END
		END Instruction;

	END Assembler;

END FoxARMAssembler.

System.FreeDownTo  FoxARMInstructionSet ~
Alwazs
