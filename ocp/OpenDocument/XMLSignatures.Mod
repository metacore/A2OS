MODULE XMLSignatures; (** AUTHOR "Patrick Hunziker"; PURPOSE "XML signatures and certificates according to xmlsig-core standard"; *)
(*
http://en.wikipedia.org/wiki/XML_Signature
XML Signature (also called XMLDsig, XML-DSig, XML-Sig) defines an XML syntax for digital signatures and is defined in the W3C recommendation XML Signature Syntax and Processing. Functionally, it has much in common with PKCS#7 but is more extensible and geared towards signing XML documents. It is used by various Web technologies such as SOAP, SAML, and others.

XML signatures can be used to sign dataa resourceof any type, typically XML documents, but anything that is accessible via a URL can be signed. An XML signature used to sign a resource outside its containing XML document is called a detached signature; if it is used to sign some part of its containing document, it is called an enveloped signature; if it contains the signed data within itself it is called an enveloping signature.

An XML Signature consists of a Signature element in the http://www.w3.org/2000/09/xmldsig# namespace. The basic structure is as follows:

<Signature>
  <SignedInfo>
    <CanonicalizationMethod />
    <SignatureMethod />
    <Reference>
       <Transforms>
       <DigestMethod>
       <DigestValue>
    </Reference>
    <Reference /> etc.
  </SignedInfo>
  <SignatureValue />
  <KeyInfo />
  <Object />
</Signature>


    The SignedInfo element contains or references the signed data and specifies what algorithms are used.
    The SignatureMethod and CanonicalizationMethod elements are used by the SignatureValue element and are included in SignedInfo to protect them from tampering.
    One or more Reference elements specify the resource being signed by URI reference; and any transforms to be applied to the resource prior to signing. A transformation can be a XPath-expression that selects a defined subset of the document tree.[1]

DigestMethod specifies the hash algorithm before applying the hash.
DigestValue contains the result of applying the hash algorithm to the transformed resource(s).

    The SignatureValue element contains the Base64 encoded signature result - the signature generated with the parameters specified in the SignatureMethod element - of the SignedInfo element after applying the algorithm specified by the CanonicalizationMethod.

    KeyInfo element optionally allows the signer to provide recipients with the key that validates the signature, usually in the form of one or more X.509 digital certificates. The relying party must identify the key from context if KeyInfo is not present.

    The Object element (optional) contains the signed data if this is an enveloping signature.

Validation and Security Considerations

When validating an XML Signature, a procedure called Core Validation is followed:
    Reference Validation: Each Reference's digest is verified by retrieving the corresponding resource and applying any transforms and then the specified digest method to it. The result is compared to the recorded DigestValue; if they do not match, validation fails.
    Signature Validation: The SignedInfo element is serialized using the canonicalization method specified in CanonicalizationMethod, the key data is retrieved using KeyInfo or by other means, and the signature is verified using the method specified in SignatureMethod.

This procedure establishes whether the resources were really signed by the alleged party. However, because of the extensibility of the canonicalization and transform methods, the verifying party must also make sure that what was actually signed or digested is really what was present in the original data, in other words, that the algorithms used there can be trusted not to change the meaning of the signed data.

see also:
http://en.wikipedia.org/wiki/Canonicalization
A full summary of canonicalization changes is listed below:

    The document is encoded in UTF-8
    Line breaks normalized to #xA on input, before parsing
    Attribute values are normalized, as if by a validating processor
    Character and parsed entity references are replaced
    CDATA sections are replaced with their character content
    The XML declaration and document type declaration are removed
    Empty elements are converted to start-end tag pairs
    Whitespace outside of the document element and within start and end tags is normalized
    All whitespace in character content is retained (excluding characters removed during line feed normalization)
    Attribute value delimiters are set to quotation marks (double quotes)
    Special characters in attribute values and character content are replaced by character references
    Superfluous namespace declarations are removed from each element
    Default attributes are added to each element
    Fixup of xml:base attributes is performed
    Lexicographic order is imposed on the namespace declarations and attributes of each element


*)
IMPORT XML, Commands, CryptoHashes, Utils := CryptoUtils, CryptoBase64, RSA:=CryptoRSA, B:=CryptoBigNumbers, P:=CryptoPrimes, Files, Strings, Streams, WMDialogs;
(*
generically: http://www.w3.org/TR/xmldsig-core/

and specifically for OpenDocument  Format, Version 1.2; Part 3: Packages;Committee Specification 01;17 March 2011; chapter 5

for X509 including discussion and examplex, start with http://en.wikipedia.org/wiki/X.509

repository of sample certificates: http://www.swview.org/blog/sample-x509-certificate-collection-publicprivate-keys-java
scripts for producing X509 certificates: http://www.swview.org/jkscertgen

see also
http://www.fpml.org/spec/fpml-5-3-2-wd-2/html/confirmation/schemaDocumentation/namespaces/http_www_w3_org_2000_09_xmldsig/namespace-overview.html
http://docs.oracle.com/cd/E24191_01/common/tutorials/content_sign_message.html
 *)
 (*  
 The Signature element is the root element of an XML Signature. 
 Implementation MUST generate laxly schema valid [XML-schema] Signature elements as specified by the following schema:
 Schema Definition:

   <element name="Signature" type="ds:SignatureType"/>
   <complexType name="SignatureType">
     <sequence> 
       <element ref="ds:SignedInfo"/> 
       <element ref="ds:SignatureValue"/> 
       <element ref="ds:KeyInfo" minOccurs="0"/> 
       <element ref="ds:Object" minOccurs="0" maxOccurs="unbounded"/> 
     </sequence>  
     <attribute name="Id" type="ID" use="optional"/>
   </complexType>
   
  example:
  <dsig:Signature Id="Id-0000010b8b0415dc-0000000000000004">
  <dsig:SignedInfo>
    <dsig:CanonicalizationMethod 
          Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
    <dsig:SignatureMethod 
        Algorithm="http://www.w3.org/2000/09/xmldsig#hmac-sha1"/>
    <dsig:Reference>...</dsig:Reference>
  </dsig:SignedInfo>
  <dsig:SignatureValue>...dsig:SignatureValue>
  <dsig:KeyInfo>
    <wsse:SecurityTokenReference wsu:Id="Id-0000010b8b0415dc-0000000000000006">
      <wsse:Reference 
          URI="# Id-0000010bd2b8eca1-0000000000000017"
          ValueType="http://schemas.xmlsoap.org/ws/2005/02/sc/dk"/>
    </wsse:SecurityTokenReference>
  </dsig:KeyInfo>
</dsig:Signature>

  *)
  
 VAR
	HexDigits: ARRAY 17 OF CHAR;	(* constant *)



 
PROCEDURE Signature*(CONST id: ARRAY OF CHAR):XML.Element;
	VAR sig:XML.Element;
	BEGIN
		NEW(sig); sig.SetName("ds:Signature"); 
			sig.SetAttributeValue("xmlns:ds","http://www.w3.org/2000/09/xmldsig#");
			IF id#"" THEN sig.SetAttributeValue("Id",id); END;
		(* add <ds:SignedInfo>
		add <ds:SignatureValue>
		add <ds:KeyInfo> 0..N items
		add <ds:Object> 0..N items
		*)
		RETURN sig;
	END Signature;

(*
4.2 The SignatureValue Element

The SignatureValue element contains the actual value of the digital signature; it is always encoded using base64 [MIME]. 
While we identify two SignatureMethod algorithms, one mandatory and one optional to implement, user specified algorithms may be used as well.

   Schema Definition:

   <element name="SignatureValue" type="ds:SignatureValueType"/> 
   <complexType name="SignatureValueType">
     <simpleContent>
       <extension base="base64Binary">
         <attribute name="Id" type="ID" use="optional"/>
       </extension>
     </simpleContent>
   </complexType>

 *)
PROCEDURE SignatureValue*(CONST value: ARRAY OF CHAR):XML.Element;
	VAR val:XML.Element; 
	BEGIN
		NEW(val); val.SetName("ds:SignatureValue"); 
		val.AddContent(Chars(value));
		RETURN val;
	END SignatureValue;
(*
4.3 The SignedInfo Element

The structure of SignedInfo includes the canonicalization algorithm, a signature algorithm, and one or more references. 
The SignedInfo element may contain an optional ID attribute that will allow it to be referenced by other signatures and objects.

SignedInfo does not include explicit signature or digest properties (such as calculation time, cryptographic device serial number, etc.). 
If an application needs to associate properties with the signature or digest, it may include such information in a SignatureProperties element within an Object element.

   Schema Definition:

   <element name="SignedInfo" type="ds:SignedInfoType"/> 
   <complexType name="SignedInfoType">
     <sequence> 
       <element ref="ds:CanonicalizationMethod"/>
       <element ref="ds:SignatureMethod"/> 
       <element ref="ds:Reference" maxOccurs="unbounded"/> 
     </sequence>  
     <attribute name="Id" type="ID" use="optional"/> 
   </complexType>
   
example:
<dsig:SignedInfo>
    <dsig:CanonicalizationMethod 
          Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
    <dsig:SignatureMethod 
        Algorithm="http://www.w3.org/2000/09/xmldsig#hmac-sha1"/>
    <dsig:Reference>...</dsig:Reference>
  </dsig:SignedInfo>
*)

PROCEDURE SignedInfo*(CONST canonicAlgo, signatureAlgo: ARRAY OF CHAR): XML.Element;
VAR si, can, meth: XML.Element;
BEGIN
	NEW(si); si.SetName("ds:SignedInfo");
	NEW(can); can.SetName("ds:CanonicalizationMethod"); si.AddContent(can);
	can.SetAttributeValue("Algorithm", canonicAlgo); 
	NEW(meth); meth.SetName("ds:SignatureMethod"); si.AddContent(meth);
	meth.SetAttributeValue("Algorithm", signatureAlgo);
	(*add <ds:Reference> 1..N items here*)
	RETURN si
END SignedInfo;



(*
4.3.2 The SignatureMethod Element

SignatureMethod is a required element that specifies the algorithm used for signature generation and validation. This algorithm identifies all cryptographic functions involved in the signature operation (e.g. hashing, public key algorithms, MACs, padding, etc.). This element uses the general structure here for algorithms described in section 6.1: Algorithm Identifiers and Implementation Requirements. While there is a single identifier, that identifier may specify a format containing multiple distinct signature values.

   Schema Definition:

   <element name="SignatureMethod" type="ds:SignatureMethodType"/>
   <complexType name="SignatureMethodType" mixed="true">
     <sequence>
       <element name="HMACOutputLength" minOccurs="0" type="ds:HMACOutputLengthType"/>
       <any namespace="##other" minOccurs="0" maxOccurs="unbounded"/>
       <!-- (0,unbounded) elements from (1,1) external namespace -->
      </sequence>
    <attribute name="Algorithm" type="anyURI" use="required"/> 
   </complexType>

*)
PROCEDURE SignatureMethod*(CONST algo: ARRAY OF CHAR):XML.Element;
VAR sm: XML.Element;
BEGIN
	ASSERT (algo#"");
	NEW(sm); sm.SetName("ds:SignatureMethod"); sm.SetAttributeValue("Algorithm", algo); (*can accept child elements*)
	RETURN sm;
END SignatureMethod;

(*
4.3.3 The Reference Element

Reference is an element that may occur one or more times. It specifies a digest algorithm and digest value, and optionally an identifier of the object being signed, the type of the object, and/or a list of transforms to be applied prior to digesting. The identification (URI) and transforms describe how the digested content (i.e., the input to the digest method) was created. The Type attribute facilitates the processing of referenced data. For example, while this specification makes no requirements over external data, an application may wish to signal that the referent is a Manifest. An optional ID attribute permits a Reference to be referenced from elsewhere.

   Schema Definition:

   <element name="Reference" type="ds:ReferenceType"/>
   <complexType name="ReferenceType">
     <sequence> 
       <element ref="ds:Transforms" minOccurs="0"/> 
       <element ref="ds:DigestMethod"/> 
       <element ref="ds:DigestValue"/> 
     </sequence>
     <attribute name="Id" type="ID" use="optional"/> 
     <attribute name="URI" type="anyURI" use="optional"/> 
     <attribute name="Type" type="anyURI" use="optional"/> 
   </complexType>

<ds:Reference URI=''>
      <ds:Transforms>
       <dsig:XPath xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
                   xmlns:m='http://example.org/ws'>
       //soap:Body/m:SomeElement
       </dsig:XPath>
       <ds:Transform Algorithm='http://www.w3.org/2001/10/xml-exc-c14n#'>
        <c14n:InclusiveNamespaces 
              xmlns:c14n='http://www.w3.org/2001/10/xml-exc-c14n#'
              PrefixList='soap wsu test' />
       </ds:Transform>
      </ds:Transforms>
      <ds:DigestMethod Algorithm='http://www.w3.org/2000/09/xmldsig#sha1' />
      <ds:DigestValue>VEPKwzfPGOxh2OUpoK0bcl58jtU=</ds:DigestValue>
     </ds:Reference>
*)

PROCEDURE Reference*(CONST URI, digestmethod, digestvalue: ARRAY OF CHAR):XML.Element;
VAR ref, meth, val: XML.Element;
BEGIN
	ASSERT((digestmethod#"") & (digestvalue#""));
	NEW(ref); ref.SetName("ds:Reference"); 
	(* IF type#"" THEN ref.SetAttributeValue("Type",type) END; *)
	(*  add optional Transform *)
	IF digestmethod#"" THEN NEW(meth); meth.SetName("ds:DigestMethod"); meth.SetAttributeValue("Algorithm",digestmethod); ref.AddContent(meth); END; (* meth can accept child elements *)
	IF digestvalue#"" THEN NEW(val); val.SetName("ds:DigestValue"); val.AddContent(Chars(digestvalue)); ref.AddContent(val); END;
	IF URI#"" THEN ref.SetAttributeValue("URI", URI) END;
	RETURN ref;
END Reference;


(*
4.3.3.5 The DigestMethod Element

DigestMethod is a required element that identifies the digest algorithm to be applied to the signed object. This element uses the general structure here for algorithms specified in Algorithm Identifiers and Implementation Requirements (section 6.1).

If the result of the URI dereference and application of Transforms is an XPath node-set (or sufficiently functional replacement implemented by the application) then it must be converted as described in the Reference Processing Model (section  4.3.3.2). If the result of URI dereference and application of transforms is an octet stream, then no conversion occurs (comments might be present if the Canonical XML with Comments was specified in the Transforms). The digest algorithm is applied to the data octets of the resulting octet stream.

   Schema Definition:

   <element name="DigestMethod" type="ds:DigestMethodType"/>
   <complexType name="DigestMethodType" mixed="true"> 
     <sequence>
       <any namespace="##other" processContents="lax" minOccurs="0" maxOccurs="unbounded"/>
     </sequence>    
     <attribute name="Algorithm" type="anyURI" use="required"/> 
   </complexType>

*)

(*
4.3.3.6 The DigestValue Element

DigestValue is an element that contains the encoded value of the digest. The digest is always encoded using base64 [MIME].

   Schema Definition:

   <element name="DigestValue" type="ds:DigestValueType"/>
   <simpleType name="DigestValueType">
     <restriction base="base64Binary"/>
   </simpleType>
*)



(*
4.4 The KeyInfo Element
KeyInfo is an optional element that enables the recipient(s) to obtain the key needed to validate the signature. 
*)
PROCEDURE KeyInfo*(CONST keyname: ARRAY OF CHAR): XML.Element;
VAR info, name: XML.Element; 
BEGIN
	NEW(info); info.SetName("ds:KeyInfo");
		IF keyname#"" THEN NEW(name); name.SetName("ds:KeyName"); info.AddContent(name); 	name.AddContent(Chars(keyname));	END;
	(* max contain <X509Data>*)
	RETURN info
END KeyInfo;
(*
The following list summarizes the KeyInfo types that are allocated an identifier in the &dsig; namespace; 
these can be used within the RetrievalMethod Type attribute to describe a remote KeyInfo structure.

    http://www.w3.org/2000/09/xmldsig#DSAKeyValue
    http://www.w3.org/2000/09/xmldsig#RSAKeyValue
    http://www.w3.org/2000/09/xmldsig#X509Data
    http://www.w3.org/2000/09/xmldsig#PGPData
    http://www.w3.org/2000/09/xmldsig#SPKIData
    http://www.w3.org/2000/09/xmldsig#MgmtData

*)
(*
4.4.1 The KeyName Element

The KeyName element contains a string value (in which white space is significant) which may be used by the signer to communicate a key identifier to the recipient. Typically, KeyName contains an identifier related to the key pair used to sign the message, but it may contain other protocol-related information that indirectly identifies a key pair. (Common uses of KeyName include simple string names for keys, a key index, a distinguished name (DN), an email address, etc.)

   Schema Definition:

   <element name="KeyName" type="string"/>
   
4.4.2 The KeyValue Element

The KeyValue element contains a single public key that may be useful in validating the signature. Structured formats for defining DSA (REQUIRED) and RSA (RECOMMENDED) public keys are defined in Signature Algorithms (section 6.4). The KeyValue element may include externally defined public keys values represented as PCDATA or element types from an external namespace.

   Schema Definition:

   <element name="KeyValue" type="ds:KeyValueType"/> 
   <complexType name="KeyValueType" mixed="true">
    <choice>
      <element ref="ds:DSAKeyValue"/>
      <element ref="ds:RSAKeyValue"/>
      <any namespace="##other" processContents="lax"/>
    </choice>
   </complexType>

4.4.2.2 The RSAKeyValue Element

Identifier
    Type="http://www.w3.org/2000/09/xmldsig#RSAKeyValue"
    (this can be used within a RetrievalMethod or Reference element to identify the referent's type)

RSA key values have two fields: Modulus and Exponent.

   <RSAKeyValue>
     <Modulus>xA7SEU+e0yQH5rm9kbCDN9o3aPIo7HbP7tX6WOocLZAtNfyxSZDU16ksL6W
      jubafOqNEpcwR3RdFsT7bCqnXPBe5ELh5u4VEy19MzxkXRgrMvavzyBpVRgBUwUlV
      5foK5hhmbktQhyNdy/6LpQRhDUDsTvK+g9Ucj47es9AQJ3U=
     </Modulus>
     <Exponent>AQAB</Exponent>
   </RSAKeyValue>

4.4.4 The X509Data Element

Identifier
    Type="http://www.w3.org/2000/09/xmldsig#X509Data "
    (this can be used within a RetrievalMethod or Reference element to identify the referent's type)

An X509Data element within KeyInfo contains one or more identifiers of keys or X509 certificates (or certificates' identifiers or a revocation list). The content of X509Data is:
simple example:

<dsig:X509Data>
   <dsig:X509SubjectName>CN=Sample,C=IE...</dsig:X509SubjectName>
   <dsig:X509Certificate>
       MIIEZDCCA0yg
       ....
       RNp9aKD1fEQgJ
   </dsig:X509Certificate>
  </dsig:X509Data>

etc etc see there...


4.4.5 The PGPData Element

Identifier
    Type="http://www.w3.org/2000/09/xmldsig#PGPData "
    (this can be used within a RetrievalMethod or Reference element to identify the referent's type)

The PGPData element within KeyInfo is used to convey information related to PGP public key pairs and signatures on such keys. The PGPKeyID's value is a base64Binary sequence containing a standard PGP public key identifier as defined in [PGP, section 11.2]. The PGPKeyPacket contains a base64-encoded Key Material Packet as defined in [PGP, section 5.5]. These children element types can be complemented/extended by siblings from an external namespace within PGPData, or PGPData can be replaced all together with an alternative PGP XML structure as a child of KeyInfo. PGPData must contain one PGPKeyID and/or one PGPKeyPacket and 0 or more elements from an external namespace.

   Schema Definition:

   <element name="PGPData" type="ds:PGPDataType"/> 
   <complexType name="PGPDataType"> 
     <choice>
       <sequence>
         <element name="PGPKeyID" type="base64Binary"/> 
         <element name="PGPKeyPacket" type="base64Binary" minOccurs="0"/> 
         <any namespace="##other" processContents="lax" minOccurs="0"
          maxOccurs="unbounded"/>
       </sequence>
       <sequence>
         <element name="PGPKeyPacket" type="base64Binary"/> 
         <any namespace="##other" processContents="lax" minOccurs="0"
          maxOccurs="unbounded"/>
       </sequence>
     </choice>
   </complexType>

4.4.6 The SPKIData Element

Identifier
    Type="http://www.w3.org/2000/09/xmldsig#SPKIData "
    (this can be used within a RetrievalMethod or Reference element to identify the referent's type)

The SPKIData element within KeyInfo is used to convey information related to SPKI public key pairs, certificates and other SPKI data. SPKISexp is the base64 encoding of a SPKI canonical S-expression. SPKIData must have at least one SPKISexp; SPKISexp can be complemented/extended by siblings from an external namespace within SPKIData, or SPKIData can be entirely replaced with an alternative SPKI XML structure as a child of KeyInfo.

   Schema Definition:

   <element name="SPKIData" type="ds:SPKIDataType"/> 
   <complexType name="SPKIDataType">
     <sequence maxOccurs="unbounded">
       <element name="SPKISexp" type="base64Binary"/>
       <any namespace="##other" processContents="lax" minOccurs="0"/>
     </sequence>
   </complexType>

*)

PROCEDURE Chars*(CONST s: ARRAY OF CHAR):XML.ArrayChars;
VAR chars: XML.ArrayChars;
BEGIN
	NEW(chars); chars.SetStr(s); 
	RETURN chars;
END Chars;

(*
 <dsig:KeyInfo>
  <dsig:X509Data>
   <dsig:X509SubjectName>CN=Sample...</dsig:X509SubjectName>
   <dsig:X509Certificate>
       MIIEZDCCA0yg
       ....
       RNp9aKD1fEQgJ
   </dsig:X509Certificate>
  </dsig:X509Data>
 </dsig:KeyInfo>

<dsig:X509SubjectName>
   CN=Sample,OU=R&amp;D,O=Company Ltd.,L=Dublin 4,ST=Dublin,C=IE
</dsig:X509SubjectName>
*)

PROCEDURE X509Data*(CONST name, cert: ARRAY OF CHAR):XML.Element;
VAR data, subject, certificate: XML.Element;
BEGIN
	NEW(data); data.SetName("ds:X509Data"); 
	IF name#"" THEN NEW(subject); subject.SetName("ds:X509SubjectName"); subject.AddContent(Chars(name)); data.AddContent(subject); END;
	NEW(certificate); certificate.SetName("ds:X509Certificate"); certificate.AddContent(Chars(cert)); data.AddContent(certificate);
	RETURN data;
END X509Data;

PROCEDURE X509IssuerSerial*(CONST issuer, serial: ARRAY OF CHAR): XML.Element;
VAR IsSe, iss, ser: XML.Element;
BEGIN
	NEW(IsSe); IsSe.SetName("ds:X509IssuerSerial");
	NEW(iss); iss.SetName("ds:X509IssuerName"); iss.AddContent(Chars(issuer)); IsSe.AddContent(iss);
	NEW(ser); ser.SetName("ds:X509SerialNumber"); ser.AddContent(Chars(serial)); IsSe.AddContent(ser);
	RETURN IsSe
END X509IssuerSerial;

(*! to be done*)
(* OpenDocument 1.2: 
The signing time should be recorded using one or more of the following approaches:
1. An <ds:Object > element containing a <ds:SignatureProperty> element with:
a. An Id attribute with a value containing a unique identifier.
b. A Target attribute corresponding to the Id attribute of the <ds:Signature> element.
c. A <date> element from the namespace "http://purl.org/dc/elements/1.1/" containing the UTC time as [xmlschema-2] dateTime value.
2. A <xades:SigningTime> element as specified in [XAdES] section 7.2.1.
*)

PROCEDURE Object():XML.Element;
VAR obj:XML.Element;
BEGIN
	NEW(obj); obj.SetName("ds:Object");
	RETURN obj
END Object;

	PROCEDURE CreateRSAKeys*(context:Commands.Context);
	CONST	Size = 1024;
	VAR
		pub, priv: RSA.Key;
		p, q, e, signature: B.BigNumber;
		digest, str: ARRAY 64 OF CHAR;
		PrivateKeyFile, PublicKeyFile, keyname, passphrase: ARRAY 256 OF CHAR;
		res:BOOLEAN;
		f:Files.File; w: Files.Writer; r:Files.Reader;
		ignore:LONGINT;
	BEGIN
		res:=context.arg.GetString(keyname);
		res:=res & context.arg.GetString(passphrase);
		IF res THEN
		
		context.out.String( "generating RSA Keys" ); context.out.Ln;
		p := P.NewPrime( Size DIV 2, FALSE );
		context.out.String("p = "); B.Print( p ); context.out.Ln;

		q := P.NewPrime( Size DIV 2, FALSE );
		context.out.String("q = "); B.Print( q ); context.out.Ln;
		B.AssignInt( e, 3 );

		RSA.MakeKeys( p, q, e, keyname, pub, priv );
		COPY(keyname, PrivateKeyFile);
		Strings.Append(PrivateKeyFile,".PrivRSA");
		f:=Files.New(PrivateKeyFile);
		Files.OpenWriter(w,f,0);
		RSA.StorePrivateKey( w, priv, passphrase ); w.Update;
		Files.Register(f);
		
		COPY(keyname, PublicKeyFile);
		Strings.Append(PublicKeyFile,".PubRSA");
		f:=Files.New(PublicKeyFile);
		Files.OpenWriter(w,f,0);
		RSA.StorePublicKey( w, pub ); w.Update;
		Files.Register(f);
		
		f := Files.Old( PrivateKeyFile ); Files.OpenReader( r, f, 0 );
		ignore := WMDialogs.QueryPassword( "enter passphrase", passphrase );
		priv := RSA.LoadPrivateKey( r, passphrase );
		IF priv = NIL THEN context.out.String( "wrong passphrase" ); context.out.Ln;  RETURN END;

		f := Files.Old( PublicKeyFile ); Files.OpenReader( r, f, 0 );
		r.SkipWhitespace; r.String( str );
		IF str = "ssh-rsa" THEN
			pub := RSA.LoadPublicKey( r )
		END;
		
		digest := "This is a test text";
		signature :=  priv.Sign( digest, 32 );
		IF signature # NIL THEN
			IF pub.Verify( digest, 32, signature ) THEN
				context.out.String( "sign : verify  ok" ); context.out.Ln;
			ELSE
				context.out.String( "sign : verify failed" ); context.out.Ln;
			END
		ELSE
			context.out.String( "error: wrong passphrase for private key" ); context.out.Ln
		END;
		END;
	END CreateRSAKeys;



PROCEDURE Test*(context:Commands.Context);
VAR sig, si, sv, ki: XML.Element;
BEGIN
	sig:=Signature("ID0001");
	
	si:=SignedInfo("http://www.w3.org/2001/10/xml-exc-c14n#", "http://www.w3.org/2000/09/xmldsig#hmac-sha1");  (*canonicAlgo, signatureAlgo*)
	si.AddContent(Reference("/content.XML", 'http://www.w3.org/2000/09/xmldsig#sha1', "VEPKwzfPGOxh2OUpoK0bcl58jtU=")); (* URI, digestmethod, digestvalue *)
	sig.AddContent(si);
	
	sv:=SignatureValue("KG4NUHBP123XHR459dw==");
	sig.AddContent(sv);
	
	ki:=KeyInfo("");
	ki.AddContent(X509Data("CN=Sample,OU=R&amp;D,O=Company Ltd.,L=Dublin 4,ST=Dublin,C=IE", "MIIEZDCCA0ygRNp9aKD1fEQgJ"));
	sig.AddContent(ki); 
	
	sig.Write(context.out, NIL, 0);
	context.out.Update;
END Test;

PROCEDURE FileSignature*(r:Streams.Reader; hash:CryptoHashes.Hash; privatekey: RSA.Key; VAR hash64, signature64: ARRAY OF CHAR);
VAR 	hashed: ARRAY 80 OF CHAR;
	temp: ARRAY 1024 OF CHAR;
	signature: B.BigNumber;
	len:LONGINT;
BEGIN
	hash.Initialize;
	WHILE r.res=Streams.Ok DO
		r.Bytes(temp,0,1024, len);
		hash.Update(temp,0,len);
	END;
	hash.GetHash(hashed,0);
	CryptoBase64.Encode(hashed, hash.size, hash64);
	signature :=  privatekey.Sign( hash64, SHORT(Strings.Length(hash64 )));
	B.GetBinaryValue(signature, temp,0); 
	CryptoBase64.Encode(temp, 4*signature.len, signature64); 
END FileSignature;

PROCEDURE TestFileSignature*(context:Commands.Context);
VAR hash64, sig64, keyfilename, datafilename, passphrase: ARRAY 1024 OF CHAR;
	priv: RSA.Key;
	res:BOOLEAN;
	f:Files.File; r: Files.Reader;
	ignore:LONGINT;
BEGIN		
	res:=context.arg.GetString(datafilename);
	res:=res & context.arg.GetString(keyfilename);
	IF ~res THEN RETURN END;
	
	f:=Files.Old(keyfilename);
	IF f=NIL THEN RETURN END;
	Files.OpenReader(r,f,0);
	ignore := WMDialogs.QueryPassword( "enter passphrase", passphrase );
	priv := RSA.LoadPrivateKey( r, passphrase );
	IF priv = NIL THEN context.out.String( "wrong passphrase" ); context.out.Ln;  RETURN END;
	
	f:=Files.Old(datafilename);
	IF f=NIL THEN RETURN END;
	Files.OpenReader(r,f,0);
	
	FileSignature(r, CryptoHashes.NewHash( "CryptoSHA1" ), priv, hash64, sig64);
	context.out.String("hash64: "); context.out.String(hash64); context.out.Ln;
	context.out.String("sig64: "); context.out.String(sig64); context.out.Ln;
	context.out.Update;	
END TestFileSignature;


PROCEDURE TestSimpleFile*(context:Commands.Context);
VAR sig, si, sv, ki: XML.Element;
	hash: CryptoHashes.Hash;
	temp, base64,sig64: ARRAY 1024 OF CHAR;
	str, hashed: ARRAY 128 OF CHAR;
	res:BOOLEAN;
	passphrase,datafilename, filename, PrivateKeyFile, PublicKeyFile: ARRAY 256 OF CHAR;
	f: Files.File; r:Files.Reader;
	ignore, len:LONGINT;
	priv, pub: RSA.Key;
	signature: B.BigNumber;
	BEGIN
		res:=context.arg.GetString(datafilename);
		IF ~res THEN RETURN END;
		f:=Files.Old(datafilename);
		Files.OpenReader(r,f,0);
		
		res:=context.arg.GetString(filename);
		IF ~res THEN RETURN END;
		
		hash := CryptoHashes.NewHash( "CryptoSHA1" );
		hash.Initialize;
		
		WHILE r.res=Files.Ok DO
			r.Bytes(temp,0,1024, len);
			hash.Update(temp,0,len);
		END;
		hash.GetHash(hashed,0);
		
		context.out.Ln; context.out.String( "************************************" );
		context.out.Ln; context.out.String( "Checking: " ); context.out.String( hash.name );
		context.out.Ln; context.out.String( "Computed Hash:" ); 
		CryptoBase64.Encode(hashed, hash.size, base64);context.out.String( base64 ); context.out.Ln;
		
		COPY(filename, PrivateKeyFile); Strings.Append(PrivateKeyFile,".PrivRSA");
		f := Files.Old( PrivateKeyFile ); Files.OpenReader( r, f, 0 );
		ignore := WMDialogs.QueryPassword( "enter passphrase", passphrase );
		priv := RSA.LoadPrivateKey( r, passphrase );
		IF priv = NIL THEN context.out.String( "wrong passphrase" ); context.out.Ln;  RETURN END;
		
		(*signature :=  priv.Sign( base64, SHORT(Strings.Length(base64 )));*) (*! it is unclear, if signature is applied to base64 encoded hash or to original binary hash. Both approaches work if done consistently*)
		signature :=  priv.Sign( hashed, SHORT(hash.size));
		
		(*signature to base64*)
		B.GetBinaryValue(signature, temp,0); 
		CryptoBase64.Encode(temp, 4*signature.len, sig64); context.out.String( sig64 ); context.out.Ln;
		
		(*base64 to signature*)
		ignore:=CryptoBase64.Decode(sig64, temp);
		B.AssignBin(signature,temp, 0, 4*signature.len);
		
		(* check signature *)
		COPY(filename, PublicKeyFile); Strings.Append(PublicKeyFile,".PubRSA");
		f := Files.Old( PublicKeyFile ); Files.OpenReader( r, f, 0 );
		r.SkipWhitespace; r.String( str );
		IF str = "ssh-rsa" THEN
			pub := RSA.LoadPublicKey( r )
		END;
		
		(*IF pub.Verify( base64,  32, signature) THEN context.out.String( "success"); *)
		IF pub.Verify( hashed,  SHORT(hash.size), signature) THEN context.out.String( "success"); 
		ELSE context.out.String( "failure");
		END;
		context.out.Ln; 		
		context.out.Update;

	sig:=Signature("ID0001");
	
	si:=SignedInfo("http://www.w3.org/2001/10/xml-exc-c14n#", "http://www.w3.org/2000/09/xmldsig#rsa-sha1");  (*canonicAlgo, signatureAlgo*)
	si.AddContent(Reference(filename, 'http://www.w3.org/2000/09/xmldsig#sha1', base64)); (* URI, digestmethod, digestvalue *)
	(*si.AddContent(Reference("/content.XML", 'http://www.w3.org/2000/09/xmldsig#sha1', "VEPKwzfPGOxh2OUpoK0bcl58jtU="));*) (* URI, digestmethod, digestvalue *)
	sig.AddContent(si);
	
	sv:=SignatureValue(sig64);
	sig.AddContent(sv);
	
	sig.Write(context.out, NIL, 0);


END TestSimpleFile;

	
END XMLSignatures.

XMLSignatures.Test ~
XMLSignatures.TestSimpleFile Signature.txt TestKeys~
XMLSignatures.TestFileSignature Signature.txt TestKeys.PrivRSA~
XMLSignatures.CreateRSAKeys TestKeys "pass phrase"~

SystemTools.FreeDownTo XMLSignatures ~


---------------------------------tutorial from oracle: -----------------
http://docs.oracle.com/cd/E24191_01/common/tutorials/content_sign_message.html
XML Signature Generation
Contents

    Overview
    Signing Key
    What to Sign
    Where to Place Signature
    Additional
    Algorithm Suite
    Options

Overview

The Enterprise Gateway can sign both SOAP and non-SOAP XML messages. Attachments to the message can also be signed. The resultant XML Signature is inserted into the message for consumption by a downstream Web Service. At the Web Service, the signature can be used to authenticate the message sender and/or verify the integrity of the message.

Enter a name for the filter in the Name field. The Signature and Advanced top-level tabs contain the following tabs, which can be used to configure various aspects of the generated XML Signature.
Signing Key

It is possible to use either a symmetric or an asymmetric key to sign the message content. Select the appropriate radio button and configure the fields on the corresponding tab.

Asymmetric Key

With an asymmetric signature, the signatory's private key (from a public-private key pair) is used to sign the message. The corresponding public key is then used to verify the signature. The following fields are available for configuration on this tab:

Key in Store:
To use a signing key from the Certificate Store, check the Key in Store radio button and then click the Signing Key button. Select a certificate that has the required signing key associated with it. The signing key can also be stored on a HSM (Hardware Security Module). Please refer to the Certificate Store help page for more information on storing signing keys.

The Distinguished Name of the selected certificate will appear in the X509SubjectName element of the XML Signature as follows:

		
	

      
<dsig:X509SubjectName>
   CN=Sample,OU=R&amp;D,O=Company Ltd.,L=Dublin 4,ST=Dublin,C=IE
</dsig:X509SubjectName>
      

	
		

Key in Message Attribute:
Alternatively, the signing key may have already have been used by another filter and stored in a message attribute. In order to reuse this key, you can select the Key in Message Attribute radio button and enter the name of the attribute in the field provided.

Symmetric Key

With a symmetric signature, the same key is used to sign and verify the message. Typically the client generates the symmetric key and uses it to sign the message. The key must then be transmitted to the recipient so that they can verify the signature. It would be unsafe to transmit an unprotected key along with the message so it is usually encrypted (or wrapped) with the recipient's public key. The key can then be decrypted with the recipient's private key and can then be used to verify the signature. The following configuration options are available on this screen:

Generate Symmetric Key:
Select this option if you want this filter to generate a symmetric key.

Symmetric Key in Message Attribute:
Alternatively, if you have already generated a symmetric key using a different filter (e.g. an Encryption filter) and stored it in a message attribute, you can select this radio button and enter the name of the message attribute in the field provided.

Include Encrypted Symmetric Key in Message:
As described earlier, the symmetric key is typically encrypted for the recipient and included in the message. However, it is possible that the initiator and recipient of the transaction have agreed on a symmetric key using some out-of-bounds mechanism. In this case, it is not necessary to include the key in the message. However, the default option is to include the encrypted symmetric key in the message. The <KeyInfo> section of the Signature will point to the <EncryptedKey>.

Encrypt with Key in Store:
Select this option to encrypt the symmetric key with a public key from the Certificate Store. Click the Signing Key button and then select the certificate that contains the public key of the recipient. By encrypting the symmetric key with this public key, you are ensuring that only the recipient that has access to the corresponding private key will be able to decrypt the encrypted symmetric key.

Encrypt with Key in Message Attribute:
You can also use a key stored in a message attribute to encrypt (or wrap) the symmetric key. Select this radio button and enter the name of the message attribute that contains the public key you want to use to encrypt the symmetric key with.

Use Derived Key:
A <wssc:DerivedKeyToken> token can be used to derive a symmetric key from the original symmetric key held in and <enc:EncryptedKey>. The derived symmetric key is then used to actually sign the message, as opposed to the original symmetric key. It must be derived again during the verification process using the parameters in the <wssc:DerivedKeyToken>. One of these parameters is the symmetric key held in <enc:EncryptedKey>. The following example shows the use of a derived key:

		
	

<enc:EncryptedKey Id="Id-0000010b8b0415dc-0000000000000000">
  <enc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#rsa-1_5"/>
  <dsig:KeyInfo>
       ...
  </dsig:KeyInfo>
  <enc:CipherData>
</enc:EncryptedKey>

<wssc:DerivedKeyToken wsu:Id="Id-0000010bd2b8eca1-0000000000000017" 
      Algorithm="http://schemas.xmlsoap.org/ws/2005/02/sc/dk/p_sha1">
  <wsse:SecurityTokenReference wsu:Id="Id-0000010bd2b8ed5d-0000000000000018">
    <wsse:Reference URI="#Id Id-0000010b8b0415dc-0000000000000000" 
    ValueType="..../oasis-wss-soap-message-security-1.1#EncryptedKey"/>
  </wsse:SecurityTokenReference>
  <wssc:Generation>0</wssc:Generation>
  <wssc:Length>32</wssc:Length>
  <wssc:Label>WS-SecureConverstaionWS-SecureConverstaion</wssc:Label>
  <wssc:Nonce>h9TTWKRylCOz87+mc1/7Pg==</wssc:Nonce>
</wssc:DerivedKeyToken>
       
<dsig:Signature Id="Id-0000010b8b0415dc-0000000000000004">
  <dsig:SignedInfo>
    <dsig:CanonicalizationMethod 
          Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
    <dsig:SignatureMethod 
        Algorithm="http://www.w3.org/2000/09/xmldsig#hmac-sha1"/>
    <dsig:Reference>...</dsig:Reference>
  </dsig:SignedInfo>
  <dsig:SignatureValue>...dsig:SignatureValue>
  <dsig:KeyInfo>
    <wsse:SecurityTokenReference wsu:Id="Id-0000010b8b0415dc-0000000000000006">
      <wsse:Reference 
          URI="# Id-0000010bd2b8eca1-0000000000000017"
          ValueType="http://schemas.xmlsoap.org/ws/2005/02/sc/dk"/>
    </wsse:SecurityTokenReference>
  </dsig:KeyInfo>
</dsig:Signature>
      

	
		

Symmetric Key Length:
This option allows the user to specify the length of the key to use when performing symmetric key signatures. It is important to realize that the longer the key, the stronger the encryption.

Key Info

This tab configures how the <KeyInfo> block of the generated XML Signature will appear. Configure the following fields on this tab:

Do Not Include KeyInfo Section:
This option allows you to omit all information about the signatory's certificate from the signature. In other words, the KeyInfo element is omitted from the signature. This is useful where a downstream Web Service uses an alternative method of authenticating the signatory, and wishes to use the signature for the sole purpose of verifying the integrity of the message. In such cases, adding certificate information to the message may be regarded as an unnecessary overhead.

Include Certificate:
This is the default option which places the signatory's certificate inside the XML Signature itself. The following example, shows an example of an XML Signature which has been created using this option:

		
	

<dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" id="Sample">
  ...
 <dsig:KeyInfo>
  <dsig:X509Data>
   <dsig:X509SubjectName>CN=Sample...</dsig:X509SubjectName>
   <dsig:X509Certificate>
       MIIEZDCCA0yg
       ....
       RNp9aKD1fEQgJ
   </dsig:X509Certificate>
  </dsig:X509Data>
 </dsig:KeyInfo>
</dsig:Signature>
      

	
		

Expand Public Key:
The details of the signatory's public key are inserted into a KeyValue block. The KeyValue block is only inserted when this option is checked.

		
	

<dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" id="Sample">
   ...
 <dsig:KeyInfo>
  <dsig:X509Data>
   <dsig:X509SubjectName>CN=Sample...</dsig:X509SubjectName>
   <dsig:X509Certificate>
      MIIE ....... EQgJ
   </dsig:X509Certificate>
  </dsig:X509Data>
  <dsig:KeyValue>
   <dsig:RSAKeyValue>
    <dsig:Modulus>
       AMfb2tT53GmMiD
       ...
       NmrNht7iy18=
    </dsig:Modulus>
    <dsig:Exponent>AQAB</dsig:Exponent>
   </dsig:RSAKeyValue>
  </dsig:KeyValue>
 </dsig:KeyInfo>
</dsig:Signature>
      

	
		

Include Distinguished Name:
If this checkbox is checked, the Distinguished Name of the signatory's X.509 certificate will be inserted in an <X509SubjectName> element as shown in the following example:

		
	

<dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" id="Sample">
  ...
 <dsig:KeyInfo>
  <dsig:X509Data>
   <dsig:X509SubjectName>CN=Sample,C=IE...</dsig:X509SubjectName>
   <dsig:X509Certificate>
       MIIEZDCCA0yg
       ....
       RNp9aKD1fEQgJ
   </dsig:X509Certificate>
  </dsig:X509Data>
 </dsig:KeyInfo>
</dsig:Signature>
      

	
		

Include Key Name:
This option allows you insert a key identifier, or KeyName, to allow the recipient to identify the signatory. 
Enter an appropriate value for the KeyName in the Value field. 
Typical values include Distinguished Names (DName) from X.509 certificates, key IDs, or email addresses. 
Specify whether the specified value is a Text value of a Distinguished name attribute by checking the appropriate radio button.

		
	

<dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" id="Sample">
   ...
 <dsig:KeyInfo>
  <dsig:KeyName>test@oracle.com</dsig:KeyName>
 </dsig:KeyInfo>
</dsig:Signature>
      

	
		

Put Certificate in an Attachment:
The Enterprise Gateway supports SOAP messages with attachments. By selecting this option, you can save the signatory's certificate to the file specified in the input field. This file can then be sent along with the SOAP message as a SOAP attachment.

From previous examples, it is clear that the user's certificate is usually placed inside a KeyInfo element. However, in this example, the certificate is actually contained within an attachment, and not within the XML Signature itself. Clearly, we need a way to reference the certificate from the XML Signature, so that validating applications can process the signature correctly. This is the role of the SecuriyTokenReference block.

The SecurityTokenReference block provides a generic way for applications to retrieve security tokens in cases where these tokens are not contained within the SOAP message. The name of the security token is specified in the URI attribute of the Reference element.

		
	

<dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" id="Sample">
   ...
 <dsig:KeyInfo>
  <wsse:SecurityTokenReference xmlns:wsse="http://schemas.xmlsoap.org/ws/...">
   <wsse:Reference URI="c:\myCertificate.txt"/>
  </wsse:SecurityTokenReference>
 </dsig:KeyInfo>
</dsig:Signature>
      

	
		

When the message is actually sent, the certificate attachment will be given a "Content-Id" corresponding to the URI attribute of the Reference element. The following example shows what the complete multipart MIME SOAP message looks like as it is sent over the wire. It should help illustrate how the Reference element actually refers to the "Content-ID" of the attachment:

		
	

POST /adoWebSvc.asmx HTTP/1.0
Content-Length: 3790
User-Agent: Enterprise Gateway
Accept-Language: en
Content-Type: multipart/related; type="text/xml";
              boundary="----=Multipart-SOAP-boundary"

------=Multipart-SOAP-boundary
Content-Id: soap-envelope
Content-Type: text/xml; charset="utf-8";
SOAPAction=getQuote

<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
   ...
 <dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" id="Sample">
    ...
  <dsig:KeyInfo>
   <ws:SecurityTokenReference xmlns:ws="http://schemas.xmlsoap.org/ws/...">
    <ws:Reference URI="c:\myCertificate.txt"/>
   </ws:SecurityTokenReference>
  </dsig:KeyInfo>
 </dsig:Signature>
    ...
</s:Envelope>

------=Multipart-SOAP-boundary
Content-Id: c:\myCertificate.txt
Content-Type: text/plain; charset="US-ASCII"

MIIEZDCCA0ygAwIBAgIBAzANBgkqhki
....
7uFveG0eL0zBwZ5qwLRNp9aKD1fEQgJ
------=Multipart-SOAP-boundary-
      

	
		

Security Token Reference:
A <wsse:SecurityTokenReference> element can be used to point to the security token used in the generation of the signature. Select this option if you wish to use this element. The type of the reference must be selected from the Reference Type dropdown.

The <wsse:SecurityTokenReference>, (within the <dsig:KeyInfo>), may contain a <wsse:Embedded> security token. Alternatively, the <wsse:SecurityTokenReference>, (within the <dsig:KeyInfo>), may refer to a certificate via a <dsig:X509Data>. Select the appropriate button, Embed or Refer, depending on whether you want to use an embedded security token or a referred one.

You can make sure to include a <BinarySecurityToken> (BST) that contains the certificate used to wrap the symmetric key in the message by selecting the Include BinarySecurityToken option. The BST will be inserted into the WS-Security header regardless of the type of Security Token Reference selected from the dropdown.

It is important to note that when using the "Kerberos Token Profile" standard and the Enterprise Gateway is acting as the initiator of a secure transaction, it can use Kerberos session keys to sign a message. The KeyInfo must be configured to use a Security Token Reference with a ValueType of "GSS_Kerberosv5_AP_REQ". In this case, the Kerberos token is contained within a <BinarySecurityToken> within the message.

If the Enterprise Gateway is acting as the recipient of a secure transaction, it can also use the Kerberos session keys to sign the message returned to the client. However, in this case, the KeyInfo must be configured to use a Security Token Reference with ValueType of "Kerberosv5_APREQSHA1". When this ValueType is selected, the Kerberos token is not contained within the message. The Security Token Reference contains a SHA1 digest of the original Kerberos token received from the client, which identifies the session keys to the client.

Note that when using the "WS-Trust for SPENGO" standard, the Kerberos session keys are not used directly to sign messages since a security context with an associated symmetric key is negotiated. This symmetric key is shared by both client and service and can be used to sign messages on both sides.
What to Sign

This tab is used to identify parts of the message that must be signed. Each signed part will be referenced from within the generated XML Signature.

It is possible to use any combination of Node Locations, XPaths, XPath Predicates, and the nodes contained in a Message Attribute to specify what must be signed. Please refer to the Locate XML Nodes filter for more information on how to use these node selectors.

It is important to consider the mechanisms available for referencing signed elements from within an XML Signature. With WSU IDs, an ID attribute is inserted into the root element of the nodeset that is to be signed. The XML Signature then references this ID to indicate to verifiers of the Signature the nodes that were signed. The use of WSU IDs is the default option since they are WS-I compliant.

Alternatively, a generic ID attribute (that is not bound to the WSU namespace) can be used to dereference the data. The ID attribute is inserted into the top-level element of the nodeset that is to be signed. The generated XML Signature can then reference this ID to indicate what nodes were signed.

When XPath transforms are used, an XPath expression that points to the root node of the nodeset that is signed will be inserted into the XML Signature. When attempting to verify the Signature, this XPath expression must be run on the message to retrieve the signed content.

Use WSU IDs:
Select this option to reference the signed data using a wsu:Id attribute. In this case, a wsu:Id attribute is inserted into the root node of the nodeset that is signed. This id is then referenced in the generated XML Signature as an indication of what nodes were signed. The following example shows the correlation:

		
	

<soap:Envelope xmlns:soap="...">
  <soap:Header>
  <wsse:Security xmlns:wsse="...">
    <dsig:Signature xmlns:dsig="..." Id="Id-00000112e2c98df8-0000000000000004">
      <dsig:SignedInfo>
        <dsig:CanonicalizationMethod 
            Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
        <dsig:SignatureMethod 
            Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha1"/>
        <dsig:Reference URI="#Id-00000112e2c98df8-0000000000000003">
          <dsig:Transforms>
            <dsig:Transform 
                Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
          </dsig:Transforms>
          <dsig:DigestMethod 
              Algorithm="http://www.w3.org/2000/09/xmldsig#sha1"/>
          <dsig:DigestValue>xChPoiWJJrrPZkbXN8FPB8S4U7w=</dsig:DigestValue>
        </dsig:Reference>
      </dsig:SignedInfo>
      <dsig:SignatureValue>KG4N .... /9dw==</dsig:SignatureValue>
      <dsig:KeyInfo Id="Id-00000112e2c98df8-0000000000000005">
        <dsig:X509Data>
          <dsig:X509Certificate>
            MIID ... ZiBQ==
          </dsig:X509Certificate>
        </dsig:X509Data>
      </dsig:KeyInfo>
    </dsig:Signature>
  </wsse:Security>
  </soap:Header>
   <soap:Body xmlns:wsu="..." wsu:Id="Id-00000112e2c98df8-0000000000000003">
  <vs:getProductInfo xmlns:vs="http://ww.oracle.com">
   <vs:Name>Enterprise Gateway</vs:Name>
   <vs:Version>11.1.1.5.0</vs:Version>
  </vs:getProductInfo>
 </s:Body>
</s:Envelope>
      

	
		

In the above example, a wsu:Id attribute has been inserted into the <soap:Body> element. This wsu:Id attribute is then referenced by the URI attribute of the <dsig:Reference> element in the actual Signature.

When the Signature is being verified, the value of the URI attribute can be used to locate the nodes that have been signed.

Use IDs:
Select this option in order to use generic IDs (that are not bound to the WSU namespace) to dereference the signed data. Under this schema, the URI attribute of the <Reference> points at an ID attribute, which is inserted into the top-level node of the nodeset that is signed. Take a look at the following example, noting how the ID specified in the Signature matches the ID attribute that has been inserted into the <Body> element, indicating that the Signature applies to the entire contents of the SOAP Body.

		
	

<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" 
                Id="Id-0000011a101b167c-0000000000000013">
      <dsig:SignedInfo>
        <dsig:CanonicalizationMethod 
            Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
        <dsig:SignatureMethod 
            Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha1"/>
        <dsig:Reference URI="#Id-0000011a101b167c-0000000000000012">
          <dsig:Transforms>
            <dsig:Transform 
                Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
          </dsig:Transforms>
          <dsig:DigestMethod 
              Algorithm="http://www.w3.org/2000/09/xmldsig#sha1"/>
          <dsig:DigestValue>JCy0JoyhVZYzmrLrl92nxfr1+zQ=</dsig:DigestValue>
        </dsig:Reference>
      </dsig:SignedInfo>
      <dsig:SignatureValue>......<dsig:SignatureValue>
      <dsig:KeyInfo Id="Id-0000011a101b167c-0000000000000014">
        <dsig:X509Data>
          <dsig:X509Certificate>......</dsig:X509Certificate>
        </dsig:X509Data>
      </dsig:KeyInfo>
    </dsig:Signature>
  </soap:Header>
 <soap:Body Id="Id-0000011a101b167c-0000000000000012">
  <product version="11.1.1.5.0">
    <name>Enterprise Gateway</name>
    <company>Oracle</company>
    <description>SOA Security and Management</description>
  </product>
 </soap:Body>
</soap:Envelope>  
      

	
		

Use SAML IDs for SAML Elements:
This option is only relevant if a SAML assertion is required to be signed. If this option is checked and the signature is to cover a SAML assertion, an AssertionID attribute will be inserted into a SAML version 1.1 assertion, or an ID attribute will be inserted into a SAML version 2.0 assertion. The value of this attribute will then be referenced from within a <Reference> block of the XML Signature.
Where to Place Signature

Append Signature to Root or SOAP Header:
If the message is a SOAP message, the signature will be inserted into the SOAP Header element when this radio button is selected. The XML Signature will be inserted as an immediate child of the SOAP Header element. The following example shows a skeleton SOAP message which has been signed using this option:

		
	

<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
 <s:Header>
  <ws:Security xmlns:ws="http://schemas.xmlsoap.org/..." s:actor="test">
   <dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/..." id="Sample">
     ...
   </dsig:Signature>
  </ws:Security>
 </s:Header>
 <s:Body>
  ...
 </s:Body>
</s:Envelope>
      

	
		

If, on the other hand, the message is just plain XML, the signature will be inserted as an immediate child of the root element of the XML message. The following example shows a non-SOAP XML message which has been signed using this option:

		
	

<PurchaseOrder>
 <dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/xmldsig#" id="Sample">
  ...
 </dsig:Signature>

 <Items>
 ...
 </Items>
</PurchaseOrder>
      

	
		

Place in WS-Security Element for SOAP Actor/Role:
By selecting this option, the XML Signature will be inserted into the WS-Security element identified by the specified SOAP actor or role. A SOAP actor/role is simply a way of distinguishing a particular WS-Security block from others which may be present in the message. Actors belong to the SOAP 1.1 specification, but were replaced in SOAP 1.2 by roles. Conceptually, however, they are identical.

Enter the name of the SOAP actor or role of the WS-Security block in the dropdown. The following SOAP message contains an XML Signature within a WS-Security block identified by the "test" actor:

		
	

<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
 <s:Header>
  <ws:Security xmlns:ws="http://schemas.xmlsoap.org/..." s:actor="test">
   <dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/..." id="Sample">
       ...
   </dsig:Signature>
  </ws:Security>
 </s:Header>
 <s:Body>
  ...
 </s:Body>
</s:Envelope>
      

	
		

Use XPath Location:
This option is useful in cases where the signature must be inserted into a non-SOAP XML message. In such cases, it is possible to insert the signature into a location pointed to by an XPath expression. Select or add an XPath expression in the field provided, and then specify whether the Enterprise Gateway should insert the signature before the location to which the XPath expression points, or append it to this location.
Additional

The Additional tab allows you to select additional elements from the message that are to be signed. It is also possible to insert a WS-Security Timestamp into the XML Signature, if necessary.

Additional Elements to Sign:
The options here allow you to select other parts of the message that you may wish to sign.

    Sign KeyInfo Element of Signature:
    The <KeyInfo> block of the XML Signature can be signed to prevent people cut-and-pasting a different <KeyInfo> block into the message, which may point to some other key material, for example.
    Sign Timestamp:
    As stated earlier, timestamps are used to prevent replay attacks. However, to guarantee the end-to-end integrity of the timestamp, it is necessary to sign it. Note that this option is only enabled when you have elected to insert a Timestamp into the message using the relevant fields on the Timestamp Options panel below.
    Sign Attachments:
    In addition to signing some or all of the contents of the SOAP message, it is also possible to sign attachments to the SOAP message. To sign all attachments, check the Include Attachments checkbox.
    A signed attachment is referenced in an XML Signature using the Content-Id or cid of the attachment. The URI attribute of the Reference element corresponds to this Content-Id. The following example shows how an XML Signature refers to a sample attachment. It shows the wire format of the message and its attachment as they are sent to the destination Web Service. Multiple attachments will result in successive Reference elements.

		
	

POST /myAttachments HTTP/1.0
Content-Length: 1000
User-Agent: Enterprise Gateway
Accept-Language: en
Content-Type: multipart/related; type="text/xml";
              boundary="----=Multipart-SOAP-boundary"

------=Multipart-SOAP-boundary
Content-Id: soap-envelope
SOAPAction: none
Content-Type: text/xml; charset="utf-8"

<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
 <s:Header>
  <dsig:Signature id="Sample" xmlns:dsig="http://www.w3.org/2000/09/xmldsig#">
   <dsig:SignedInfo>
    <dsig:CanonicalizationMethod 
        Algorithm="http://www.w3.org/2001/10/xml-exc-c14n"/>
    <dsig:SignatureMethod 
        Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha1"/>
    <dsig:Reference URI="cid:moredata.txt">...</dsig:Reference>
   </dsig:SignedInfo>
  </dsig:Signature>
 </s:Header>
 <s:Body>
    ...
 </s:Body>
</s:Envelope>

------=Multipart-SOAP-boundary
Content-Id: moredata.txt
Content-Type: text/plain; charset="UTF-8"

Some more data.
------=Multipart-SOAP-boundary--
      

	
		

Transform:
This dropdown is only available when you have selected the Sign Attachments box above. It determines the transform used to reference the signed attachments.

Timestamp Options:
It is possible to insert a timestamp into the message to indicate when exactly the signature was generated. 
Consumers of the signature can then validate the signature to ensure that it is not of date.

The following options are available:

    No Timestamp:
    No timestamp will be inserted into the signature.
    Embed in WSSE Security:
    The "wsu:Timestamp" will be inserted into a "wsse:Security" block. The Security block is identified by the SOAP actor/role specified on the Signature tab.
    Embed in Signature Property:
    The "wsu:Timestamp" will be placed inside a signature property element in the "dsig:Signature".

The Expires In fields allow the user to optionally specify the "wsu:Expires" for the "wsu:Timestamp". If all fields are left at "0", no "wsu:Expires" element will be placed inside the "wsu:Timestamp".

The following examples shows a "wsu:Timestamp" that has been inserted into a "wsse:Security" block:

		
	

<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
 <s:Header>
   <wsse:Security>
     <wsu:Timestamp wsu:Id="Id-0000011294a0311e-000000000000003d">
      <wsu:Created>2007-05-16T11:22:45Z</wsu:Created>
      <wsu:Expires>2007-05-23T11:22:45Z</wsu:Expires>
    </wsu:Timestamp>  
    <dsig:Signature ...>
    ...
    </dsig:Signature ...>
   </wsse:Security>
 </s:Header>
 <s:Body>
    ...
 </s:Body>
</s:Envelope>
      

	
		

Algorithm Suite

The fields on this tab determine the combination of cryptographic algorithms and ciphers that are used to sign the message parts.

Algorithm Suite:
WS-Security Policy defines a number of algorithm suites that group together a number of cryptographic algorithms. For example, a given algorithm suite will use specific algorithms for asymmetric signing, symmetric signing, asymmetric key wrap, and so on. Therefore, by specifying an algorithm suite, you are effectively selecting a whole suite of cryptographic algorithms to use.

If you want to use a particular WS-Security Policy algorithm suite, you can select it here. The Signature Method, Key Wrap Algorithm, and Digest Method fields will then be automatically populated with the corresponding algorithms for that suite.

Signature Method:
The Signature Method field allows you to configure the method used to generate the signature. Various strengths of the HMAC-SHA1 algorithms are available from the dropdown.

Key Wrap Algorithm:
Select the algorithm to use to wrap (i.e. encrypt) the symmetric signing key. This option need only be configured when you are using a symmetric key to sign the message.

Digest Algorithm:
Select the digest algorithm to you to produce a cryptographic hash of the signed data.
Options

Advanced Options:
This section allows you to configure various advanced options on the generated XML Signature. The following fields can be configured on this tab:

WS-Security Options:
WSSE 1.1 defines a <SignatureConfirmation> element that can be used as proof that a particular XML Signature was processed. A recipient and verifier of an XML Signature must generate a <SignatureConfirmation> element for each piece of data that was signed (i.e. for each <Reference> in the XML Signature). A <SignatureConfirmation> element contains the hash of the signed data and must be signed by the recipient before returning it in the response to the initiator (i.e. the original signatory of the data).

When the initiator receives the <SignatureConfirmation> elements in the response, it compares the hash with the hash of the data that it produced initially. If the hashes match, the initiator knows that the recipient has processed the same signature.

Select the Initiator option here if the Enterprise Gateway is the initiator as outlined in the scenario above. The Enterprise Gateway will keep a record of the signed data and will compare it to the contents of the <SignatureConfirmation> elements returned from the recipient in the response message.

Alternatively, if the Enterprise Gateway is acting as the recipient in this transaction, you can select the Responder radio button to instruct the Enterprise Gateway to generate the <SignatureConfirmation> elements and return them to the inititor. The signature confirmations will be added to the WS-Security header.

Layout Type:
Select the WS-Security Policy layout type that you want the XML Signature and any generated tokens to adhere to. This includes elements such as <Signature>, <BinarySecurityToken>, and <EncryptedKey>, which can all be generated as part of the signing process.

Fail if No Nodes to Sign:
Check this option if you want the filter to fail if it cannot find any nodes to sign as configured on the What to Sign tab.

Add Inclusive Namespaces for Exclusive Canonicalization:
It is possible to include information about the namespaces (and their associated prefixes) of signed elements in the signature itself. This ensures that namespaces that are in the same scope as the signed element, but not directly or "visibly" used by this element, are included in the signature. This ensures that the signature can be validated as a standalone entity outside of the context of the message from which it was extracted.

It is also worth pointing out that the WS-I specification only permits the use of exclusive canonicalization in an XML Signature. The <InclusiveNamespaces> element is an attempt to take advantage of some of the behavior of inclusive canonicalization, while maintaining the simplicity of exclusive canonicalization.

A PrefixList attribute is used to list the prefixes of in-scope, but not visibly used elements and attributes. The following example shows how the PrefixList attribute is used in practice:

		
	

<soap:Envelope xmlns:soap='http://schemas.xmlsoap.org/soap/envelope'>
 <soap:Header>
  <wsse:Security xmlns:wsse='http://docs.oasis-open.org/...' 
                 xmlns:wsu='http://docs.oasis-open.org/...'>
   <wsse:BinarySecurityToken wsu:Id='SomeCert' 
                             ValueType="http://docs.oasis-open.org/...">
   lui+Jy4WYKGJW5xM3aHnLxOpGVIpzSg4V486hHFe7sH
   </wsse:BinarySecurityToken>
   <ds:Signature xmlns:ds='http://www.w3.org/2000/09/xmldsig#'>
    <ds:SignedInfo>
     <ds:CanonicalizationMethod 
         Algorithm='http://www.w3.org/2001/10/xml-exc-c14n#'>
      <c14n:InclusiveNamespaces 
          xmlns:c14n='http://www.w3.org/2001/10/xml-exc-c14n#'
          PrefixList='wsse wsu soap' />
     </ds:CanonicalizationMethod>
     <ds:SignatureMethod 
          Algorithm='http://www.w3.org/2000/09/xmldsig#rsa-sha1'/>
     <ds:Reference URI=''>
      <ds:Transforms>
       <dsig:XPath xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
                   xmlns:m='http://example.org/ws'>
       //soap:Body/m:SomeElement
       </dsig:XPath>
       <ds:Transform Algorithm='http://www.w3.org/2001/10/xml-exc-c14n#'>
        <c14n:InclusiveNamespaces 
              xmlns:c14n='http://www.w3.org/2001/10/xml-exc-c14n#'
              PrefixList='soap wsu test' />
       </ds:Transform>
      </ds:Transforms>
      <ds:DigestMethod Algorithm='http://www.w3.org/2000/09/xmldsig#sha1' />
      <ds:DigestValue>VEPKwzfPGOxh2OUpoK0bcl58jtU=</ds:DigestValue>
     </ds:Reference>
    </ds:SignedInfo>
    <ds:SignatureValue>+diIuEyDpV7qxVoUOkb5rj61+Zs=</ds:SignatureValue>
    <ds:KeyInfo>
     <wsse:SecurityTokenReference>
      <wsse:Reference URI='#SomeCert' />
     </wsse:SecurityTokenReference>
    </ds:KeyInfo>
   </ds:Signature>
  </wsse:Security>
 </soap:Header>
 <soap:Body xmlns:wsu='http://docs.oasis-open.org/...' 
            xmlns:test='http://www.test.com' wsu:Id='TheBody'>
  <m:SomeElement xmlns:m='http://example.org/ws' attr1='test:fdwfde' />
 </soap:Body>
</soap:Envelope>
      

		

Indent:
Select this method to ensure that the generated signature is properly indented.

Create Enveloped Signature:
By selecting this option, an enveloped XML Signature is generated. The following skeleton signed SOAP message shows the enveloped signature

		
	

<ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#" id="Sample">
 <ds:SignedInfo>
  <ds:Reference URI="">
   <ds:Transforms>
    <ds:Transform 
        Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
   </ds:Transforms>
  </ds:Reference>
 </ds:SignedInfo>
</ds:Signature>
      

	
		

This indicates to the application validating the signature that the signature itself should not be included in the signed data. In other words, to validate the signature, the application must first strip out the signature. This is necessary in cases where the entire SOAP envelope has been signed, and the resulting signature has been inserted into the SOAP header. In this case, the signature is over a nodeset which has been altered (i.e. the Signature has been inserted), and so the signature will break.

Insert CarriedKeyName for EncryptedKey:
Check this option to include a <CarriedKeyName< element in the <EncryptedKey> block that is generated when using a symmetric signing key.
=====================Valid X509 Certificate: ===================
This is an example of a decoded X.509 certificate for www.freesoft.org, generated with OpenSSLthe actual certificate is about 1 kB in size. It was issued by Thawte (since acquired by VeriSign), 
as stated in the Issuer field. Its subject contains many personal details, but the most important part is usually the common name (CN), as this is the part that must match the host being authenticated. 
Also included is an RSA public key (modulus and public exponent), followed by the signature, computed by taking a MD5 hash of the first part of the certificate and 
signing it (applying the encryption operation) using Thawte's RSA private key.


Certificate:
   Data:
       Version: 1 (0x0)
       Serial Number: 7829 (0x1e95)
       Signature Algorithm: md5WithRSAEncryption
       Issuer: C=ZA, ST=Western Cape, L=Cape Town, O=Thawte Consulting cc,
               OU=Certification Services Division,
               CN=Thawte Server CA/emailAddress=server-certs@thawte.com
       Validity   
           Not Before: Jul  9 16:04:02 1998 GMT
           Not After : Jul  9 16:04:02 1999 GMT
       Subject: C=US, ST=Maryland, L=Pasadena, O=Brent Baccala,
                OU=FreeSoft, CN=www.freesoft.org/emailAddress=baccala@freesoft.org
       Subject Public Key Info:
           Public Key Algorithm: rsaEncryption
           RSA Public Key: (1024 bit)
               Modulus (1024 bit):
                   00:b4:31:98:0a:c4:bc:62:c1:88:aa:dc:b0:c8:bb:
                   33:35:19:d5:0c:64:b9:3d:41:b2:96:fc:f3:31:e1:
                   66:36:d0:8e:56:12:44:ba:75:eb:e8:1c:9c:5b:66:
                   70:33:52:14:c9:ec:4f:91:51:70:39:de:53:85:17:
                   16:94:6e:ee:f4:d5:6f:d5:ca:b3:47:5e:1b:0c:7b:
                   c5:cc:2b:6b:c1:90:c3:16:31:0d:bf:7a:c7:47:77:
                   8f:a0:21:c7:4c:d0:16:65:00:c1:0f:d7:b8:80:e3:
                   d2:75:6b:c1:ea:9e:5c:5c:ea:7d:c1:a1:10:bc:b8:
                   e8:35:1c:9e:27:52:7e:41:8f
               Exponent: 65537 (0x10001)
   Signature Algorithm: md5WithRSAEncryption
       93:5f:8f:5f:c5:af:bf:0a:ab:a5:6d:fb:24:5f:b6:59:5d:9d:
       92:2e:4a:1b:8b:ac:7d:99:17:5d:cd:19:f6:ad:ef:63:2f:92:
       ab:2f:4b:cf:0a:13:90:ee:2c:0e:43:03:be:f6:ea:8e:9c:67:
       d0:a2:40:03:f7:ef:6a:15:09:79:a9:46:ed:b7:16:1b:41:72:
       0d:19:aa:ad:dd:9a:df:ab:97:50:65:f5:5e:85:a6:ef:19:d1:
       5a:de:9d:ea:63:cd:cb:cc:6d:5d:01:85:b5:6d:c8:f3:d9:f7:
       8f:0e:fc:ba:1f:34:e9:96:6e:6c:cf:f2:ef:9b:bf:de:b5:22:
       68:9f


=================================
