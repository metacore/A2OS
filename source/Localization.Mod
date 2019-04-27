MODULE Localization; (** AUTHOR "staubesv"; PURPOSE "Localization interface"; *)

IMPORT
	Configuration;

TYPE
	Language* = RECORD
		code* : ARRAY 3 OF CHAR; (* ISO 936-1 language code *)
	END;

	Languages* = POINTER TO ARRAY OF Language;

VAR
	currentLanguage : Language;
	preferenceList : Languages; (* {(preferenceList # NIL) & (LEN(preferenceList) >= 0) } *)

PROCEDURE GetCurrentLanguage*() : Language;
BEGIN {EXCLUSIVE}
	RETURN currentLanguage;
END GetCurrentLanguage;

PROCEDURE GetLanguagePreferences*() : Languages;
BEGIN {EXCLUSIVE}
	RETURN preferenceList;
END GetLanguagePreferences;

PROCEDURE SetLanguage*(CONST language : Language);
BEGIN {EXCLUSIVE}
	currentLanguage := language;
	preferenceList[0] := currentLanguage;
END SetLanguage;

PROCEDURE GetDefaultLanguage;
VAR
	res: WORD;
BEGIN
	Configuration.Get("Local.Language", currentLanguage.code, res);
	IF res # Configuration.Ok THEN
		currentLanguage.code := "en"
	END
END GetDefaultLanguage;

BEGIN
	GetDefaultLanguage;
	NEW(preferenceList, 1);
	preferenceList[0] := currentLanguage;
END Localization.

System.Free Localization ~
