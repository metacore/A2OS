MODULE WMBuilderTransformer; (** AUTHOR "staubesv"; PURPOSE "Transform XML description of component composite into runnable code"; *)

IMPORT
	KernelLog,
	Modules, Streams, Commands, Options, Strings, Files, XML, XMLObjects, Repositories, UTF8Strings, Texts, TextUtilities,
	WMRectangles, WMGraphics, WMProperties, WMComponents;

CONST

	TAB = 09X;

	VariableDeclarationIndent = 2;
	CreateFormIndent = 3;
	HandlersWiringIndent = 3;
	HandlersIndent = 2;

	DefaultBaseName = "TemplateMultiInstanceBase.txt";
	DefaultSkeletonName = "TemplateMultiInstance.txt";

	FileSuffixBase = "Base";
	FileExtension = ".Mod";

TYPE
	Identifier = ARRAY 64 OF CHAR;

	ComponentIdentifier = RECORD
		name : Identifier;
		component : ANY;
	END;

	IdentifierArray = POINTER TO ARRAY OF ComponentIdentifier;

	VariableDeclaration = OBJECT
	VAR
		moduleName, typeName : Modules.Name;
		identifiers : IdentifierArray;
		nofIdentifiers : LONGINT;

		next : VariableDeclaration;

		PROCEDURE &Init(CONST moduleName, typeName : Modules.Name);
		BEGIN
			SELF.moduleName := moduleName;
			SELF.typeName := typeName;
			NEW(identifiers, 8);
			nofIdentifiers := 0;
			next := NIL;
		END Init;

		PROCEDURE AddIdentifier(CONST ident : Identifier);
		BEGIN
			IF (nofIdentifiers >= LEN(identifiers)) THEN Resize; END;
			identifiers[nofIdentifiers].name := ident;
			INC(nofIdentifiers);
		END AddIdentifier;

		PROCEDURE ToStream(w : Streams.Writer);
		VAR i : LONGINT;
		BEGIN
			Indent(w, VariableDeclarationIndent);
			FOR i := 0 TO nofIdentifiers - 1 DO
				w.String(identifiers[i].name); w.String("-");
				IF (i # nofIdentifiers - 1) THEN w.String(", "); END;
			END;
			w.String(" : "); w.String(moduleName); w.String("."); w.String(typeName); w.String(";");
			w.Char(CHR(Texts.NewLineChar));
		END ToStream;

		PROCEDURE Resize;
		VAR newArray : IdentifierArray; i : LONGINT;
		BEGIN
			NEW(newArray, 2 * LEN(identifiers));
			FOR i := 0 TO LEN(identifiers)-1 DO
				newArray[i] := identifiers[i];
			END;
			identifiers := newArray;
		END Resize;

	END VariableDeclaration;

TYPE

	VariableDeclarations = OBJECT
	VAR
		variables : VariableDeclaration;

		PROCEDURE &Init;
		BEGIN
			variables := NIL;
		END Init;

		PROCEDURE Add(CONST identifier : Identifier; CONST moduleName, typeName : Modules.Name; component : ANY);
		VAR vd : VariableDeclaration;
		BEGIN
			vd := FindByType(moduleName, typeName);
			IF (vd = NIL) THEN
				NEW(vd, moduleName, typeName);
				vd.next := variables;
				variables := vd;
			END;
			vd.AddIdentifier(identifier);
		END Add;

		PROCEDURE FindByType(CONST moduleName, typeName : Modules.Name) : VariableDeclaration;
		VAR vd : VariableDeclaration;
		BEGIN
			vd := variables;
			WHILE (vd # NIL) & ((vd.moduleName # moduleName) OR (vd.typeName # typeName)) DO vd := vd.next; END;
			RETURN vd;
		END FindByType;

		PROCEDURE ToStream(w : Streams.Writer);
		VAR v : VariableDeclaration;
		BEGIN
			IF (variables # NIL) THEN
				v := variables;
				WHILE (v # NIL) DO
					v.ToStream(w);
					v := v.next;
				END;
			END;
		END ToStream;

	END VariableDeclarations;

TYPE

	ImportList = OBJECT
	VAR
		imports : ARRAY 128 OF Modules.Name;
		nofImports : LONGINT;

		PROCEDURE &Init;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(imports)-1 DO imports[i] := ""; END;
			nofImports := 0;
		END Init;

		PROCEDURE IndexOf(CONST import : Modules.Name) : LONGINT;
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE (i < nofImports) & (imports[i] # import) DO INC(i); END;
			IF (i >= nofImports) THEN i := -1; END;
			RETURN i;
		END IndexOf;

		PROCEDURE Add(CONST moduleName : Modules.Name);
		BEGIN
			IF IndexOf(moduleName) = -1 THEN
				imports[nofImports] := moduleName;
				INC(nofImports);
			END;
		END Add;

		PROCEDURE ToStream(w : Streams.Writer);
		VAR i : LONGINT;
		BEGIN
			ASSERT(w # NIL);
			FOR i := 0 TO nofImports - 1 DO
				w.String(", "); w.String(imports[i]);
			END;
		END ToStream;

	END ImportList;
TYPE

	Names = OBJECT
	VAR
		names : IdentifierArray;
		nofNames : LONGINT;

		PROCEDURE &Init;
		BEGIN
			NEW(names, 128);
			nofNames := 0;
		END Init;

		PROCEDURE Add(CONST name : ARRAY OF CHAR; component : ANY);
		BEGIN
			IF (nofNames >= LEN(names)) THEN Resize; END;
			COPY(name, names[nofNames].name);
			names[nofNames].component := component;
			INC(nofNames);
		END Add;

		PROCEDURE IndexOf(CONST identifier : ARRAY OF CHAR) : LONGINT;
		VAR index : LONGINT;
		BEGIN
			index := 0;
			WHILE (index < nofNames) & (names[index].name # identifier) DO INC(index); END;
			IF (index >= nofNames) THEN
				index := -1;
			END;
			RETURN index;
		END IndexOf;

		PROCEDURE GetNameOf(component : ANY; VAR name : ARRAY OF CHAR);
		VAR index : LONGINT;
		BEGIN
			IF (component # NIL) THEN
				index := 0;
				WHILE (index < nofNames) & (names[index].component # component) DO INC(index); END;
				IF (index < nofNames) THEN
					COPY(names[index].name, name);
				ELSE
					name := "NotFound";
				END;
			ELSE
				name := "NoName";
			END;
		END GetNameOf;

		PROCEDURE GenerateIdentifier(caption : ARRAY OF CHAR; CONST moduleName,  typeName : ARRAY OF CHAR; component : ANY) : Identifier;
		VAR
			temp, suffixStr, identifier : Identifier; suffix : LONGINT;

			PROCEDURE AppendInteger(VAR string : ARRAY OF CHAR; integer : LONGINT);
			VAR nbr : ARRAY 8 OF CHAR;
			BEGIN
				Strings.IntToStr(integer, nbr);
				Strings.Append(string, nbr);
			END AppendInteger;

			PROCEDURE IsAlpha(ch : CHAR) : BOOLEAN;
			BEGIN
				RETURN (('a' <= ch) & (ch <= 'z')) OR (('A' <= ch) & (ch <= 'Z'));
			END IsAlpha;

			PROCEDURE IsNum(ch : CHAR) : BOOLEAN;
			BEGIN
				RETURN ('0' <= ch) & (ch <= '9');
			END IsNum;

			PROCEDURE RemoveReservedCharacters(VAR string : ARRAY OF CHAR);
			VAR i, j: LONGINT;
			BEGIN
				i := 0; j := 0;
				WHILE (i < LEN(string)) & (string[i] # 0X) DO
					IF IsAlpha(string[i]) OR ((j > 0) & IsNum(string[i]) OR (string[i] = "_") OR (string[i] = "-")) THEN
						string[j] := string[i]; INC(j);
					END;
					INC(i);
				END;
				string[j] := 0X;
			END RemoveReservedCharacters;

		BEGIN
			RemoveReservedCharacters(caption);
			IF (caption # "") THEN
				COPY(caption, identifier);
				TypeToSuffix(moduleName, typeName, suffixStr);
				Strings.Append(identifier, suffixStr);
			ELSIF (typeName # "") THEN
				COPY(typeName, identifier);
			ELSE
				identifier := "unknown";
			END;
			identifier[0] := Strings.LOW(identifier[0]);
			IF IndexOf(identifier) >= 0 THEN
				suffix := 0;
				REPEAT
					COPY(identifier, temp);
					AppendInteger(temp, suffix);
					INC(suffix);
				UNTIL IndexOf(temp) < 0;
				COPY(temp, identifier);
			END;
			Add(identifier, component);
			RETURN identifier;
		END GenerateIdentifier;

		PROCEDURE Resize;
		VAR newArray : IdentifierArray; i : LONGINT;
		BEGIN
			NEW(newArray, 2 * LEN(names));
			FOR i := 0 TO LEN(names)-1 DO
				newArray[i] := names[i];
			END;
			names := newArray;
		END Resize;

	END Names;

TYPE

	Transformer = OBJECT
	VAR
		names : Names;
		declarations : VariableDeclarations;
		importList : ImportList;

		(* sections to be inserted into template *)
		variableDecl : Strings.Buffer;
		variableDeclWriter : Streams.Writer;
		createForm : Strings.Buffer;
		createFormWriter : Streams.Writer;
		handlersWiring : Strings.Buffer;
		handlersWiringWriter : Streams.Writer;
		handlers : Strings.Buffer;
		handlersWriter : Streams.Writer;
		imports : Strings.Buffer;
		importsWriter : Streams.Writer;

		createFormReturnIdent : Identifier;

		PROCEDURE &Init;
		BEGIN
			NEW(names);
			NEW(declarations);
			NEW(importList);
			NEW(variableDecl, 1024); variableDeclWriter := variableDecl.GetWriter();
			NEW(createForm, 1024); createFormWriter := createForm.GetWriter();
			NEW(handlersWiring, 1024); handlersWiringWriter := handlersWiring.GetWriter();
			NEW(handlers, 1024); handlersWriter := handlers.GetWriter();
			NEW(imports, 1024); importsWriter := imports.GetWriter();
		END Init;

		PROCEDURE Transform(component, parent : WMComponents.Component;  VAR res : WORD);
		VAR
			thisIdent : Identifier;
			enum : XMLObjects.Enumerator;
			ptr : ANY;

			PROCEDURE WriteHandlersDeclaration(component : WMComponents.Component) : BOOLEAN;
			VAR w : Streams.Writer; identifier : Identifier; typeString : ARRAY 128 OF CHAR; written : BOOLEAN;
			BEGIN
				ASSERT(component # NIL);
				w := handlersWiringWriter;
				names.GetNameOf(component, identifier);
				written := FALSE;
				GetTypeAsString(component, typeString);
				IF (typeString = "WMStandardComponents.Button") THEN
					written := TRUE;
					Indent(w, HandlersWiringIndent);
					w.String(identifier); w.String("."); w.String("onClick.Add(");
					w.String("Handle");
					identifier[0] := Strings.UP(identifier[0]);
					w.String(identifier);
					w.String(");");
					w.Char(CHR(Texts.NewLineChar));
				END;
				RETURN written;
			END WriteHandlersDeclaration;

			PROCEDURE WriteHandlers(component : WMComponents.Component);
			VAR w : Streams.Writer; identifier : Identifier;
			BEGIN
				ASSERT(component # NIL);
				IF WriteHandlersDeclaration(component) THEN
					w := handlersWriter;
					Indent(w, HandlersIndent);
					names.GetNameOf(component, identifier);
					identifier[0] := Strings.UP(identifier[0]);
					w.String("PROCEDURE Handle"); w.String(identifier); w.String("(sender, data : ANY);"); w.Char(CHR(Texts.NewLineChar));
					Indent(w, HandlersIndent); w.String("BEGIN"); w.Char(CHR(Texts.NewLineChar));
					Indent(w, HandlersIndent + 1); w.Char(CHR(Texts.NewLineChar));
					Indent(w, HandlersIndent); w.String("END "); w.String("Handle"); w.String(identifier); w.String(";"); w.Char(CHR(Texts.NewLineChar));
					w.Char(CHR(Texts.NewLineChar));
				END;
			END WriteHandlers;

			PROCEDURE WriteProperties(w : Streams.Writer; CONST identifier : Identifier; component : WMComponents.Component);
			VAR
				pa : WMProperties.PropertyArray; name : Strings.String;  i : LONGINT;
				pname : ARRAY 64 OF CHAR;
				helper : Streams.StringWriter;

				PROCEDURE WriteStringProperty(property : WMProperties.Property);
				BEGIN
					w.String('.SetAOC("'); property.ToStream(w); w.String('");');
				END WriteStringProperty;

				PROCEDURE WriteColorProperty(property : WMProperties.Property);
				VAR color : ARRAY 64 OF CHAR;
				BEGIN
					helper.Reset;
					property.ToStream(helper);
					helper.Get(color);
					w.String(".Set(");
					IF (("a" <= color[0]) & (color[0] <= "z")) OR (("A" <= color[0]) & (color[0] <= "Z")) THEN w.String("0"); END;
					w.String(color);
					w.String("H);");
				END WriteColorProperty;

				PROCEDURE WriteBooleanProperty(property : WMProperties.Property);
				VAR value : ARRAY 8 OF CHAR;
				BEGIN
					helper.Reset;
					property.ToStream(helper);
					helper.Get(value);
					Strings.UpperCase(value);
					w.String(".Set("); w.String(value); w.String(");");
				END WriteBooleanProperty;

				PROCEDURE WriteReferenceProperty(property : WMProperties.Property);
				BEGIN
					w.String('.SetAsString("'); property.ToStream(w); w.String('");');
				END WriteReferenceProperty;

				PROCEDURE WriteFontProperty(property : WMProperties.Property);
				VAR f : WMGraphics.Font;
				BEGIN
					f := property(WMProperties.FontProperty).Get();
					w.String('.SetFont("'); w.String(f.name); w.String('", '); w.Int(f.size, 0); w.String(", "); w.Set(f.style);
					w.String(");");
				END WriteFontProperty;

				PROCEDURE WriteRectangleProperty(property : WMProperties.Property);
				VAR r : WMRectangles.Rectangle;
				BEGIN
					r := property(WMProperties.RectangleProperty).Get();
					importList.Add("WMRectangles");
					w.String(".Set(WMRectangles.MakeRect(");
					w.Int(r.l, 0); w.String(", "); w.Int(r.t, 0); w.String(", ");
					w.Int(r.r, 0); w.String(", "); w.Int(r.b, 0); w.String("));");
				END WriteRectangleProperty;

				PROCEDURE WriteAlignmentAndBounds(CONST identifier : Identifier; vc : WMComponents.VisualComponent; forceBounds : BOOLEAN);
				VAR alignment : LONGINT; r : WMRectangles.Rectangle;
				BEGIN
					alignment := vc.alignment.Get();
					IF ~vc.alignment.GetIsDefault() THEN
						Indent(w, CreateFormIndent); w.String(identifier); w.String(".alignment.Set("); AlignmentToStream(alignment, w); w.String(");");
						w.Char(CHR(Texts.NewLineChar));
					END;
					IF forceBounds OR (~vc.bounds.GetIsDefault() & (alignment # WMComponents.AlignClient)) THEN
						Indent(w, CreateFormIndent); w.String(identifier); w.String(".bounds");
						IF (alignment = WMComponents.AlignLeft) OR (alignment = WMComponents.AlignRight) THEN
							w.String(".SetWidth("); w.Int(vc.bounds.GetWidth(), 0);
						ELSIF (alignment = WMComponents.AlignTop) OR (alignment = WMComponents.AlignBottom) THEN
							w.String(".SetHeight("); w.Int(vc.bounds.GetHeight(), 0);
						ELSE
							w.String(".Set(WMRectangles.MakeRect(");
							importList.Add("WMRectangles");
							r := vc.bounds.Get();
							w.Int(r.l, 0); w.String(", "); w.Int(r.t, 0); w.String(", ");
							w.Int(r.r, 0); w.String(", "); w.Int(r.b, 0); w.String(")");
						END;
						w.String(");");
						w.Char(CHR(Texts.NewLineChar));
					END;
				END WriteAlignmentAndBounds;

			BEGIN
				ASSERT(w # NIL);
				ASSERT(component # NIL);
				IF (component IS WMComponents.VisualComponent) THEN
					WriteAlignmentAndBounds(identifier, component(WMComponents.VisualComponent), identifier = createFormReturnIdent);
				END;
				pa := component.properties.Enumerate();
				IF (pa # NIL) THEN
					NEW(helper, 1024);
					FOR i := 0 TO LEN(pa) - 1 DO
						IF ~pa[i].GetIsDefault() & (pa[i].GetName() # NIL) THEN
							name := pa[i].GetName();
							IF (name^ # "Alignment") & (name^ # "Bounds") THEN
								Indent(w, CreateFormIndent);
								GetPropertyNameAsString(pa[i], pname);
								w.String(identifier); w.String("."); w.String(pname);
								IF (pa[i] IS WMProperties.StringProperty) THEN WriteStringProperty(pa[i]);
								ELSIF (pa[i] IS WMProperties.ColorProperty) THEN WriteColorProperty(pa[i]);
								ELSIF (pa[i] IS WMProperties.BooleanProperty) THEN WriteBooleanProperty(pa[i]);
								ELSIF (pa[i] IS WMProperties.ReferenceProperty) THEN WriteReferenceProperty(pa[i]);
								ELSIF (pa[i] IS WMProperties.FontProperty) THEN WriteFontProperty(pa[i]);
								ELSIF (pa[i] IS WMProperties.RectangleProperty) THEN WriteRectangleProperty(pa[i]);
								ELSE
									w.String(".Set("); pa[i].ToStream(w); w.String(");");
								END;
								w.Char(CHR(Texts.NewLineChar));
							END;
						END;
					END;
				END;
				w.Char(CHR(Texts.NewLineChar));
			END WriteProperties;

			PROCEDURE WriteCreateForm(CONST identifier : Identifier; component, parent : WMComponents.Component);
			VAR w : Streams.Writer; parentIdent : Identifier; p : ANY;
			BEGIN
				ASSERT(component # NIL);
				w := createFormWriter;
				Indent(w, CreateFormIndent); w.String("NEW("); w.String(identifier); w.String(");"); w.Char(CHR(Texts.NewLineChar));
				IF (parent # NIL) THEN
					WHILE (parent # NIL) & (parent IS WMComponents.Component) & (parent(WMComponents.Component).internal) DO
						p := parent.GetParent();
						IF (p # NIL) & (p IS WMComponents.Component) THEN parent := p (WMComponents.Component); ELSE parent := NIL; END;
					END;
					IF (parent # NIL) THEN
						names.GetNameOf(parent, parentIdent);
						Indent(w, CreateFormIndent); w.String(parentIdent); w.String("."); w.String("AddContent(");
						w.String(identifier); w.String(");"); w.Char(CHR(Texts.NewLineChar));
					END;
				ELSE
					createFormReturnIdent := identifier;
				END;
				WriteProperties(w, identifier, component);
			END WriteCreateForm;

			PROCEDURE ProcessComponent(component, parent : WMComponents.Component; VAR ident : Identifier);
			VAR td : Modules.TypeDesc; identifier, caption : Identifier; moduleName : Modules.Name;
			BEGIN
				ASSERT(component # NIL);
				IF ~component(WMComponents.Component).internal THEN
					td := Modules.TypeOf(component);
					IF (td # NIL) THEN
						IF (td.mod # NIL) THEN
							COPY(td.mod.name, moduleName);
						ELSE
							moduleName := "";
						END;
						caption := "";
						IF ~component(WMComponents.Component).properties.GetPropertyValue("Caption", caption) THEN caption := ""; END;
						identifier := names.GenerateIdentifier(caption, moduleName, td.name, component);
						ident := identifier;
						(* generate code *)
						IF (moduleName # "") THEN importList.Add(moduleName); END;
						declarations.Add(identifier, moduleName, td.name, component);
						WriteCreateForm(identifier, component, parent);
						WriteHandlers(component);
					ELSE
						KernelLog.String("Warning: No type descriptor for component object found!"); KernelLog.Ln;
					END;
				END;
			END ProcessComponent;

		BEGIN
			ASSERT(component # NIL);
			ProcessComponent(component, parent, thisIdent);
			enum := component.GetContents();
			WHILE enum.HasMoreElements() DO
				ptr := enum.GetNext();
				IF (ptr # NIL) & (ptr IS WMComponents.Component) THEN
					Transform(ptr(WMComponents.Component), component, res);
				END;
			END;
		END Transform;

		PROCEDURE GenerateCode(CONST targetName, templateName, skeletonName,  moduleName : ARRAY OF CHAR; VAR res : WORD);
		VAR base, skeleton : Texts.Text; format : LONGINT; fileName : Files.FileName;
		BEGIN
			NEW(base); TextUtilities.LoadAuto(base, templateName, format, res);
			IF (res = 0) THEN
				NEW(skeleton);  TextUtilities.LoadAuto(skeleton, skeletonName, format, res);
				IF (res = 0) THEN
					Indent(createFormWriter, CreateFormIndent);
					createFormWriter.String("RETURN "); createFormWriter.String(createFormReturnIdent); createFormWriter.String(";");
					COPY(moduleName, fileName); Strings.Append(fileName, FileSuffixBase);
					ApplyBase(base, fileName, res);
					IF (res = 0) THEN
						COPY(targetName, fileName); Strings.Append(fileName, FileSuffixBase); Strings.Append(fileName, FileExtension);
						TextUtilities.StoreOberonText(base, fileName, res);
						IF (res = 0) THEN
							ApplySkeleton(skeleton, moduleName, res);
							IF (res = 0) THEN
								COPY(targetName, fileName); Strings.Append(fileName, FileExtension);
								TextUtilities.StoreOberonText(skeleton, fileName, res);
							END;
						END;
					END;
				END;
			END;
		END GenerateCode;

		PROCEDURE ApplyBase(text : Texts.Text;  CONST moduleName : ARRAY OF CHAR; VAR res : WORD);
		VAR error : BOOLEAN;
		BEGIN
			ASSERT(text # NIL);
			ReplaceString("[MODULENAME]", moduleName, text, error);
			importList.ToStream(importsWriter);
			Replace("[IMPORTS]", imports, text, error);
			declarations.ToStream(variableDeclWriter);
			Replace("[VARIABLES]", variableDecl, text, error);
			Replace("[CREATEFORM]", createForm, text, error);
		END ApplyBase;

		PROCEDURE ApplySkeleton(text : Texts.Text;  CONST moduleName : ARRAY OF CHAR; VAR res : WORD);
		VAR error : BOOLEAN; name : ARRAY 64 OF CHAR;
		BEGIN
			ASSERT(text # NIL);
			ReplaceString("[MODULENAME]", moduleName, text, error);
			COPY(moduleName, name); Strings.Append(name, FileSuffixBase);
			ReplaceString("[BASEMODULENAME]", name, text, error);
			Replace("[HANDLERSWIRING]", handlersWiring, text, error);
			Replace("[HANDLERS]", handlers, text, error);
		END ApplySkeleton;

	END Transformer;

PROCEDURE GetUCS32String(string : Strings.String) : Texts.PUCS32String;
VAR ucsString : Texts.PUCS32String; idx : LONGINT;
BEGIN
	ucsString := NIL;
	IF (string # NIL) & (Strings.Length(string^) > 0) THEN
		NEW(ucsString, 5 * Strings.Length(string^));
		idx := 0; UTF8Strings.UTF8toUnicode(string^, ucsString^, idx);
	END;
	RETURN ucsString;
END GetUCS32String;

PROCEDURE Replace(CONST pattern : ARRAY OF CHAR; by : Strings.Buffer; text : Texts.Text; VAR error : BOOLEAN);
VAR string : Strings.String; ucsPattern, ucsString : Texts.PUCS32String; nofReplacements, idx : LONGINT;
BEGIN
	ASSERT(Strings.Length(pattern) > 2); (* [...] *)
	ASSERT(by # NIL);
	ASSERT(text # NIL);
	error := FALSE;
	string := by.GetString();
	ucsString := GetUCS32String(string);
	IF (ucsString = NIL) THEN NEW(ucsString, 1); ucsString[0] := 0; END;
	NEW(ucsPattern, 5 * Strings.Length(pattern));
	idx := 0; UTF8Strings.UTF8toUnicode(pattern, ucsPattern^, idx);
	TextUtilities.Replace(ucsPattern^, ucsString^, text, nofReplacements);
	error := (nofReplacements # 1);
END Replace;

PROCEDURE ReplaceString(CONST string, by : ARRAY OF CHAR; text : Texts.Text; VAR error : BOOLEAN);
VAR nofReplacements, idx : LONGINT; ucsString, ucsBy : Texts.PUCS32String;
BEGIN
	ASSERT(Strings.Length(string) > 2);
	ASSERT(Strings.Length(by) > 0);
	ASSERT(text # NIL);
	nofReplacements := 0;
	NEW(ucsString, 6 * Strings.Length(string));
	NEW(ucsBy, 6 * Strings.Length(by));
	idx := 0; UTF8Strings.UTF8toUnicode(string, ucsString^, idx);
	idx := 0; UTF8Strings.UTF8toUnicode(by, ucsBy^, idx);
	TextUtilities.Replace(ucsString^, ucsBy^, text, nofReplacements);
	error := nofReplacements # 1;
END ReplaceString;

PROCEDURE AlignmentToStream(alignment : LONGINT; w : Streams.Writer);
BEGIN
	CASE alignment OF
		|WMComponents.AlignNone: w.String("WMComponents.AlignNone");
		|WMComponents.AlignLeft: w.String("WMComponents.AlignLeft");
		|WMComponents.AlignTop: w.String("WMComponents.AlignTop");
		|WMComponents.AlignRight: w.String("WMComponents.AlignRight");
		|WMComponents.AlignBottom: w.String("WMComponents.AlignBottom");
		|WMComponents.AlignClient: w.String("WMComponents.AlignClient");
	ELSE
		w.Int(alignment, 0);
	END;
END AlignmentToStream;

PROCEDURE GetPropertyNameAsString(property : WMProperties.Property; VAR value : ARRAY OF CHAR);
VAR string : Strings.String;
BEGIN
	ASSERT(property # NIL);
	value := "";
	string := property.GetName();
	IF (string # NIL) THEN
		(* WMComponents.Component *)
		IF (string^ = "ID") THEN value := "id";
		ELSIF (string^ = "UID") THEN value := "uid";
		(* WMStandardComponents.Button *)
		ELSIF (string^ = "BgLeftDefault") THEN value := "imgDefaultNameLeft";
		ELSIF (string^ = "BgRightDefault") THEN value := "imgDefaultNameRight";
		ELSIF (string^ = "BgMiddleDefault") THEN value := "imgDefaultNameMiddle";
		ELSIF (string^ = "BgLeftHover") THEN value := "imgHoverNameLeft";
		ELSIF (string^ = "BgRightHover") THEN value := "imgHoverNameRight";
		ELSIF (string^ = "BgMiddleHover") THEN value := "imgHoverNameMiddle";
		ELSIF (string^ = "BgLeftPressed") THEN value := "imgPressedNameLeft";
		ELSIF (string^ = "BgRightPressed") THEN value := "imgPressedNameRight";
		ELSIF (string^ = "BgMiddlePressed") THEN value := "imgPressedNameMiddle";
		ELSIF (string^ = "BgTopDefault") THEN value := "imgDefaultNameTop";
		ELSIF (string^ = "BgBottomDefault") THEN value := "imgDefaultNameBottom";
		ELSIF (string^ = "BgTopHover") THEN value := "imgHoverNameTop";
		ELSIF (string^ = "BgBottomHover") THEN value := "imgHoverNameBottom";
		ELSIF (string^ = "BgTopPressed") THEN value := "imgPressedNameTop";
		ELSIF (string^ = "BgBottomPressed") THEN value := "imgPressedNameBottom";
		ELSE
			COPY(string^, value);
			value[0] := Strings.LOW(value[0]);
		END;
	END;
END GetPropertyNameAsString;

PROCEDURE Indent(writer : Streams.Writer; level : LONGINT);
BEGIN
	WHILE (level > 0) DO writer.Char(TAB); DEC(level); END;
END Indent;

PROCEDURE TypeToSuffix(CONST moduleName, typeName : ARRAY OF CHAR; VAR suffix : ARRAY OF CHAR);
BEGIN
	suffix := "";
	IF (moduleName = "WMStandardComponents") THEN
		IF (typeName = "Button") THEN
			suffix := "Btn";
		END;
	END;
END TypeToSuffix;

PROCEDURE GetTypeAsString(component : Repositories.Component; VAR typeString : ARRAY OF CHAR);
VAR td : Modules.TypeDesc;
BEGIN
	ASSERT(component # NIL);
	typeString := "";
	td := Modules.TypeOf(component);
	IF (td # NIL) THEN
		IF (td.mod # NIL) THEN
			COPY(td.mod.name, typeString);
			Strings.Append(typeString, ".");
		END;
		Strings.Append(typeString, td.name);
	END;
END GetTypeAsString;

PROCEDURE TransformComponent*(component : WMComponents.Component; CONST base, skeleton, fileName, moduleName : ARRAY OF CHAR; VAR res : WORD);
VAR transformer : Transformer;
BEGIN
	ASSERT(component # NIL);
	NEW(transformer);
	transformer.Transform(component(WMComponents.Component), NIL, res);
	IF (res = 0) THEN
		transformer.GenerateCode(fileName, base, skeleton, moduleName, res);
	END;
END TransformComponent;

PROCEDURE Transform*(context : Commands.Context); (** [Options] componentName moduleName  ~ *)
VAR
	options : Options.Options;
	componentName, baseName, skeletonName, moduleName, fileName : Files.FileName;
	content : XML.Content; component : Repositories.Component;
	res : WORD;
BEGIN
	NEW(options);
	options.Add("b", "base", Options.String);
	options.Add("f", "filename", Options.String);
	options.Add("s", "skeleton", Options.String);
	IF options.Parse(context.arg, context.error) THEN
		context.arg.SkipWhitespace; context.arg.String(componentName);
		context.arg.SkipWhitespace; context.arg.String(moduleName);
		IF ~options.GetString("base", baseName) THEN COPY(DefaultBaseName, baseName); END;
		IF ~options.GetString("skeleton", skeletonName) THEN COPY(DefaultSkeletonName, skeletonName); END;
		IF ~options.GetString("filename", fileName) THEN
			COPY(moduleName, fileName);
		END;
		IF Strings.ContainsChar(componentName, ".", FALSE) THEN
			content := WMComponents.Load(componentName);
			IF (content # NIL) & (content IS WMComponents.Component) THEN
				TransformComponent(content(WMComponents.Component), baseName, skeletonName, fileName, moduleName, res);
				IF (res = 0) THEN
					context.out.String(componentName); context.out.String(" written to "); context.out.String(fileName); context.out.String(FileExtension);
					context.out.String(" and "); context.out.String(fileName); context.out.String(FileSuffixBase); context.out.String(FileExtension);
					context.out.Ln;
				ELSE
					context.error.String("Transformation failed, res = "); context.error.Int(res, 0); context.error.Ln;
				END;
			ELSE
				context.error.String("Could not load component from file "); context.error.String(componentName);
				context.error.Ln;
			END;
		ELSE
			Repositories.GetComponentByString(componentName, component, res);
			IF (res = Repositories.Ok) THEN
				IF (component IS WMComponents.Component) THEN
					TransformComponent(component(WMComponents.Component), baseName, skeletonName, fileName, moduleName, res);
					IF (res = 0) THEN
						context.out.String(componentName); context.out.String(" written to "); context.out.String(fileName); context.out.String(FileExtension);
						context.out.String(" and "); context.out.String(fileName); context.out.String(FileSuffixBase); context.out.String(FileExtension);
						context.out.Ln;
					ELSE
						context.error.String("Transformation failed, res = "); context.error.Int(res, 0); context.error.Ln;
					END;
				ELSE
					context.error.String("Component type mismatch"); context.error.Ln;
				END;
			ELSE
				context.error.String("Could not load component "); context.error.String(componentName);
				context.error.String(", res: "); context.error.Int(res, 0); context.error.Ln;
			END;
		END;
	END;
END Transform;

END WMBuilderTransformer.

WMBuilderTransformer.Transform Test:TestFont:0  TestMod TestMod.Mod ~

WMBuilderTransformer.Transform Testxxx2:Mixer Test ~

WMBuilderTransformer.Transform Demo.wm Test ~

System.Free WMBuilderTransformer ~

WMBuilderTransformer.Test ~
