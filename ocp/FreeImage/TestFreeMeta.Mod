MODULE TestFreeMeta; (** AUTHOR "fnecati"; PURPOSE "test module for freeimage' Metadata functions"; *)
(* adapted from FreeImage source distribution *)
IMPORT  
	FI := FreeImageDll, Commands, KernelLog, Strings, Streams;
	
VAR 
	out: Streams.Writer;

TYPE 
	FITAG = FI.FITAG;
	FIBITMAP = FI.FIBITMAP;
	FIMETADATA = FI.FIMETADATA;

PROCEDURE writeString(s: Strings.String);
BEGIN
	IF s # NIL THEN
		out.String(s^); 
	END;
END writeString;

PROCEDURE WriteOrd(s: Strings.String);
VAR i: SIZE;
BEGIN
	out.String("--------------------"); out.Ln;
	IF s # NIL THEN
		FOR i:=0 TO Strings.Length(s^)-1 DO
			out.Int(ORD(s[i]), 4);
		END;
		out.Ln;
	END;
	
END WriteOrd;

PROCEDURE PrintMetaData (sectionTitle: ARRAY OF CHAR; dib: FIBITMAP; model: FI.IMAGE_MDMODEL);
VAR tag: FITAG;
	mdhandle: FIMETADATA;
	xvalue, value, value1, value2: Strings.String;
	svalue: ARRAY 256 OF CHAR;
	
BEGIN
	tag := NIL; mdhandle := NIL;
	mdhandle := FI.FindFirstMetadata(model, dib, tag);
(*	out.String(sectionTitle); *)
	IF mdhandle # NIL THEN
		REPEAT
				
			(* convert the tag value to a string *)
			value := FI.TagToString(model, tag);
		(*	COPY(value^, svalue);
			out.String("tag value: "); out.String(svalue); (*writeString(xvalue);*) out.Ln; (* out.Update; *) *)
				
			(* print the tag
			note that most tags do not have a description,
			especially when the metadata specifications are not available
			*)
				
			IF FI.GetTagDescription(tag) # NIL THEN
				value1 := FI.GetTagKey(tag);
				value2 := FI.GetTagDescription(tag);
				writeString(value1); out.String(":   ");
				writeString(value); (* out.String(svalue);*)  out.String(",   ");
				writeString(value2); out.Ln;
				
			ELSE
				value1 := FI.GetTagKey(tag);
				writeString(value1); out.String(":   ");
				WriteOrd(value);
				writeString(value); (*out.String(svalue);*) out.String("   "); out.Ln;
				out.Update;
			END;
			out.Update;
			
		UNTIL ~FI.FindNextMetadata(mdhandle, tag); 
			
		FI.FindCloseMetadata(mdhandle)
	END
		
END PrintMetaData;

(* Open a image file  and show it and print the metadata it contains *)
PROCEDURE Open*(context: Commands.Context);
VAR 
	tdib: FI.FIBITMAP;
	fname: ARRAY 128 OF CHAR;
	count, w, h: SIGNED32;
	tagmake: FITAG;
	buffer: Strings.String;
	bufferstr: ARRAY 256 OF CHAR;
BEGIN
	IF ~ context.arg.GetString(fname) THEN RETURN END;
	
	tdib := FI.LoadImage(fname, 0);

	IF tdib # NIL THEN
		out.String(fname); out.String(": Image Loaded .."); out.Ln;
		out.Ln;
		out.String('wxh: '); out.Update;
		w := FI.GetWidth(tdib);
		h := FI.GetHeight(tdib);
		out.Int(w, 0);
		out.Int(h, 5); out.Ln;
(*
		(* TRAPS on Linux64 *)
		out.String('wxh: '); out.Int(FI.GetWidth(tdib), 0);
		out.Int(FI.GetHeight(tdib), 5); out.Ln;	*)
		out.Update;
	ELSE
		out.String(fname); out.String(": Image NOT Loaded .."); out.Ln(); out.Update;
		RETURN
	END;
	
	count := FI.GetMetadataCount(FI.FIMD_COMMENTS, tdib);
	IF count > 0 THEN
		out.String("FIMD_COMMENTS: "); out.Int(count, 5); out.Ln;
		PrintMetaData("Comments: ", tdib, FI.FIMD_COMMENTS)
	END;

	count := FI.GetMetadataCount(FI.FIMD_EXIF_MAIN, tdib);
	IF count > 0 THEN
		out.String("FIMD_EXIF_MAIN: "); out.Int(count, 5); out.Ln;
		PrintMetaData("Exif - advanced info: ", tdib, FI.FIMD_EXIF_MAIN)
	END;

	count := FI.GetMetadataCount(FI.FIMD_EXIF_EXIF, tdib);
	IF count > 0 THEN
		out.String("FIMD_EXIF_EXIF: "); out.Int(count, 5); out.Ln;
		PrintMetaData("Exif - advanced info", tdib, FI.FIMD_EXIF_EXIF)
	END;
		
	count := FI.GetMetadataCount(FI.FIMD_EXIF_GPS, tdib);
	IF count > 0 THEN
		out.String("FIMD_EXIF_GPS: "); out.Int(count, 5); out.Ln;
		PrintMetaData("Exif GPS: ", tdib, FI.FIMD_EXIF_GPS)
	END;

	count := FI.GetMetadataCount(FI.FIMD_EXIF_INTEROP, tdib);
	IF count > 0 THEN
		out.String("FIMD_EXIF_INTEROP: "); out.Int(count, 5); out.Ln;
		PrintMetaData("Exif interoperability: ", tdib, FI.FIMD_EXIF_INTEROP)
	END;

	count := FI.GetMetadataCount(FI.FIMD_EXIF_MAKERNOTE, tdib);
	IF count > 0 THEN
		out.String("FIMD_EXIF_MAKERNOTE: "); out.Int(count, 5); out.Ln;
		tagmake := NIL;
		bufferstr := "";
		(* Get the camera model *)
		IF FI.GetMetadata(FI.FIMD_EXIF_MAIN, tdib, "Make", tagmake) THEN
			buffer := FI.GetStringFromAddr(FI.GetTagValue(tagmake));
			Strings.Append(bufferstr, buffer^);
			out.String("bufferstr= "); out.String(bufferstr); out.Ln; 
			PrintMetaData(bufferstr, tdib, FI.FIMD_EXIF_MAKERNOTE)
		END 
	END;

	count := FI.GetMetadataCount(FI.FIMD_IPTC, tdib);
	IF count > 0 THEN
		out.String("FIMD_IPTC: "); out.Int(count, 5); out.Ln;
		PrintMetaData("IPTC/NAA: ", tdib, FI.FIMD_IPTC)
	END;

	count := FI.GetMetadataCount(FI.FIMD_GEOTIFF, tdib);
	IF count > 0 THEN
		out.String("FIMD_GEOTIFF: "); out.Int(count, 5); out.Ln;
		PrintMetaData("GEOTIFF: ", tdib, FI.FIMD_GEOTIFF)
	END;

	(* print XMP data *)

	count := FI.GetMetadataCount(FI.FIMD_XMP, tdib);
	IF count > 0 THEN
		out.String("FIMD_XMP: "); out.Int(count, 5); out.Ln;
		tagmake := NIL;
		IF FI.GetMetadata(FI.FIMD_XMP, tdib, "XMLPacket", tagmake) THEN
			IF tagmake # NIL THEN
				buffer := FI.GetStringFromAddr(FI.GetTagValue(tagmake));
				out.String(buffer^); out.Ln
			END
		END 
	END;
	FI.Unload(tdib);	
	out.String("---- Finished----"); out.Ln; 
	out.Update;
END Open;

BEGIN
	Streams.OpenWriter(out, KernelLog.Send);	
END TestFreeMeta.


TestFreeMeta.Open "D:/a2/Win64/Work/samia2.jpg"


TestFreeMeta.Open E:/WinAosSvn/WinAos/Work/test8_Bg.jpg ~

TestFreeMeta.Open DSC_7163.JPG ~


System.FreeDownTo FreeImageDll ~ 

