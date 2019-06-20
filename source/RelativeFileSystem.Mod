MODULE RelativeFileSystem ;	(**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT Files,UTF8Strings, Commands;
TYPE PathName=ARRAY 272 OF CHAR;

	FileSystem = OBJECT(Files.FileSystem)
	VAR relTo: PathName; fs: Files.FileSystem;

		PROCEDURE &InitFileSystem*( relTo: ARRAY OF CHAR; fs: Files.FileSystem);
		VAR ch: CHAR;i: SIZE; full: Files.FileName; flags: SET;
		BEGIN
			SELF.fs := fs;
			INCL(SELF.flags,Files.NeedsPrefix);
			i :=0; ch := 0X;
			WHILE(relTo[i] # 0X) DO
				ch := relTo[i];
				INC(i);
			END;
			IF (ch = "/") & (i>1)  THEN relTo[i-1] := 0X END; (* remove ending "/" *)

			IF fs.prefix # "" THEN
				RemovePrefix(relTo);
			END;

			IF fs.Has(relTo,full,flags) THEN
				COPY(full,SELF.relTo);
			ELSE (* should never happen, but as a fallback: *)
				COPY(relTo, SELF.relTo);
			END;
		END InitFileSystem;

		PROCEDURE MakeRel(CONST name: ARRAY OF CHAR; VAR new: ARRAY OF CHAR);
		BEGIN
			COPY(name,new);
			RemovePrefix(new);
			IF new[0] # "/" THEN  UTF8Strings.Concat("/",new,new); END;
			UTF8Strings.Concat(relTo,new,new);
		END MakeRel;

		PROCEDURE New0* (CONST name: ARRAY OF CHAR): Files.File;
		VAR new: PathName;
		BEGIN
			MakeRel(name,new); RETURN fs.New0(new);
		END New0;

		PROCEDURE Old0* (CONST name: ARRAY OF CHAR): Files.File;
		VAR new: PathName;
		BEGIN
			(* Out.String("Old0, called with:"); Out.String(name); Out.Ln; *)
			MakeRel(name,new);
			(* Out.String("Old0, calling with:"); Out.String(new); Out.Ln; *)
			RETURN fs.Old0(new);
		END Old0;

		PROCEDURE CreateDirectory0* (CONST name: ARRAY OF CHAR;     VAR res: WORD);
		VAR new: PathName;
		BEGIN
			MakeRel(name,new); fs.CreateDirectory0(new,res);
		END CreateDirectory0;

		PROCEDURE Delete0* (CONST name: ARRAY OF CHAR;     VAR key: LONGINT; VAR res: WORD);
		VAR new: PathName;
		BEGIN
			MakeRel(name,new); fs.Delete0(new,key,res);
		END Delete0;

		PROCEDURE Enumerate0*(CONST mask: ARRAY OF CHAR;     flags: SET;     enum: Files.Enumerator);
		VAR new: PathName;
		BEGIN
			MakeRel(mask,new);
			fs.Enumerate0(new,flags,enum);
		END Enumerate0;

		PROCEDURE FileKey* (CONST name: ARRAY OF CHAR): LONGINT;
		VAR new: PathName;
		BEGIN
			(*Out.String("FileKey, called with:"); Out.String(name); Out.Ln; *)
			MakeRel(name,new);
			(*Out.String("FileKey, calling with:"); Out.String(new); Out.Ln;*)
			RETURN fs.FileKey(new);
		END FileKey;

		PROCEDURE RemoveDirectory0* (CONST name: ARRAY OF CHAR;     force: BOOLEAN;     VAR key: LONGINT; VAR res: WORD);
		VAR new: PathName;
		BEGIN
			MakeRel(name,new);  fs.RemoveDirectory0(new,force,key,res);
		END RemoveDirectory0;

		PROCEDURE Rename0* (CONST old, new: ARRAY OF CHAR;     f: Files.File;      VAR res: WORD);
		VAR old1,new1: PathName;
		BEGIN
			MakeRel(old,old1); MakeRel(new,new1);fs.Rename0(old1,new1,f,res);
		END Rename0;

	END FileSystem;

	PROCEDURE RemovePrefix(VAR name: ARRAY OF CHAR);
	VAR i,j: SIZE;
	BEGIN
		WHILE(name[i] # 0X) & (name[i] # ":") DO
			INC(i);
		END;
		IF name[i] = ":" THEN
			j := 0; INC(i);
			WHILE(name[i] # 0X) DO
				name[j] := name[i]; INC(i);INC(j);
			END;
			name[j] := 0X;
		END;
	END RemovePrefix;

	(** NewFS - Create a new filesystem relative to a Windows path. does not protect paths higher than relTo! (xyz:/../../.. could be used) *)
	PROCEDURE NewFS*(context : Files.Parameters);
	VAR str,prefix,name, full: ARRAY 256 OF CHAR; fs: FileSystem; rel: Files.FileSystem; ft: Files.FileSystemTable; flags:SET;
	BEGIN
		IF context.arg.GetString(str) THEN
			Files.SplitName(str,prefix,name);
			IF prefix # "" THEN
				rel := Files.This(prefix);
			ELSE
				Files.GetList(ft);
				rel := ft[0];
			END;
			IF rel # NIL THEN
				IF rel.Has(str,full,flags) THEN
					NEW(fs,str,rel);
					Files.Add(fs, context.prefix);
				ELSE
					context.error.String("file system does not contain "); context.error.String(str); context.error.Ln;
				END;
			ELSE
				context.out.String("file system could not be found: "); context.out.String(str); context.out.Ln;
				context.result := Commands.CommandError;
			END;
		END;
	END NewFS;


END RelativeFileSystem.

System.Free RelativeFileSystem ~

FSTools.Mount Work RelativeFileSystem  ./ ~
FSTools.Unmount Test ~


FSTools.Mount Test RelativeFileSystem ../../../HighDim/Code ~

System.Directory src:/*
