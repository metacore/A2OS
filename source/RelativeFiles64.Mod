MODULE RelativeFiles64;	(**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT Files := Files64,UTF8Strings;
TYPE PathName=ARRAY 272 OF CHAR;

	FileSystem = OBJECT(Files.FileSystem)
	VAR relTo: PathName; fs: Files.FileSystem;

		PROCEDURE &InitFileSystem*( relTo: ARRAY OF CHAR; fs: Files.FileSystem);
		VAR ch: CHAR;i: LONGINT;
		BEGIN
			SELF.fs := fs;
			INCL(flags,Files.NeedsPrefix);
			i :=0; ch := 0X;
			WHILE(relTo[i] # 0X) DO
				ch := relTo[i];
				INC(i);
			END;
			IF (ch = "/") & (i>1)  THEN relTo[i-1] := 0X END; (* remove ending "/" *)

			IF fs.prefix # "" THEN
				RemovePrefix(relTo);
			END;

			COPY(relTo,SELF.relTo);
		END InitFileSystem;

		PROCEDURE MakeRel(VAR name,new: ARRAY OF CHAR);
		BEGIN
			COPY(relTo,new);
			RemovePrefix(name);
			IF name[0] # "/" THEN  UTF8Strings.Append("/",new); END;
			UTF8Strings.Append(name,new);
		END MakeRel;

		PROCEDURE New0 (name: ARRAY OF CHAR): Files.File;
		VAR new: PathName;
		BEGIN
			MakeRel(name,new); RETURN fs.New0(new);
		END New0;

		PROCEDURE Old0 (name: ARRAY OF CHAR): Files.File;
		VAR new: PathName;
		BEGIN
			(* Out.String("Old0, called with:"); Out.String(name); Out.Ln; *)
			MakeRel(name,new);
			(* Out.String("Old0, calling with:"); Out.String(new); Out.Ln; *)
			RETURN fs.Old0(new);
		END Old0;

		PROCEDURE CreateDirectory0 (name: ARRAY OF CHAR;     VAR res: LONGINT);
		VAR new: PathName;
		BEGIN
			MakeRel(name,new); fs.CreateDirectory0(new,res);
		END CreateDirectory0;

		PROCEDURE Delete0 (name: ARRAY OF CHAR;     VAR key, res: LONGINT);
		VAR new: PathName;
		BEGIN
			MakeRel(name,new); fs.Delete0(new,key,res);
		END Delete0;

		PROCEDURE Enumerate0 (mask: ARRAY OF CHAR;     flags: SET;     enum: Files.Enumerator);
		VAR new: PathName;
		BEGIN
			MakeRel(mask,new); 
			fs.Enumerate0(new,flags,enum);
		END Enumerate0;

		PROCEDURE FileKey (name: ARRAY OF CHAR): LONGINT;
		VAR new: PathName;
		BEGIN
			(*Out.String("FileKey, called with:"); Out.String(name); Out.Ln; *)
			MakeRel(name,new);
			(*Out.String("FileKey, calling with:"); Out.String(new); Out.Ln;*)
			RETURN fs.FileKey(new);
		END FileKey;

		PROCEDURE RemoveDirectory0 (name: ARRAY OF CHAR;     force: BOOLEAN;     VAR key, res: LONGINT);
		VAR new: PathName;
		BEGIN
			MakeRel(name,new);  fs.RemoveDirectory0(new,force,key,res);
		END RemoveDirectory0;

		PROCEDURE Rename0 (old, new: ARRAY OF CHAR;     f: Files.File;      VAR res: LONGINT);
		VAR old1,new1: PathName;
		BEGIN
			MakeRel(old,old1); MakeRel(new,new1);fs.Rename0(old1,new1,f,res);
		END Rename0;

	END FileSystem;

	PROCEDURE RemovePrefix(VAR name: ARRAY OF CHAR);
	VAR i,j: LONGINT;
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
	VAR str,prefix,name: ARRAY 256 OF CHAR; fs: FileSystem; rel: Files.FileSystem; ft: Files.FileSystemTable;
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
				NEW(fs,str,rel);
				Files.Add(fs, context.prefix);
			ELSE
				context.out.String("file system could not be found: "); context.out.String(str); context.out.Ln;
			END;
		END;
	END NewFS;


END RelativeFiles64.

SystemTools.Free RelativeFiles64 ~

FSTools.Mount Work RelativeFiles64  ./ ~
FSTools.Unmount Test ~




System.Directory src:/*