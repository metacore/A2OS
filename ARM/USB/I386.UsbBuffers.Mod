MODULE UsbBuffers; (** AUTHOR ""; PURPOSE ""; *)

TYPE
	Buffer * = ARRAY OF CHAR;
	BufferPtr * = POINTER TO Buffer;

	PROCEDURE GetDataAddress * (buffer: Buffer): ADDRESS;
	BEGIN
		RETURN ADDRESSOF(buffer[0])
	END GetDataAddress;
END UsbBuffers.
