MODULE OpenDocumentTransforms; (** AUTHOR "Patrick Hunziker"; PURPOSE "XSL Transformations for OpenOffice documents"; *)

IMPORT
	
	

END OpenDocumentTransforms.

example how to transform an OpenOffice Presentation into a a list of slide titles with text:

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:draw="http://openoffice.org/2000/drawing"
                xmlns:text="http://openoffice.org/2000/text"
                xmlns:presentation="http://openoffice.org/2000/presentation"
                version="1.0">

  <xsl:template match="/">
    <html><head><title>Speaker Notes</title>
    <style>
      <xsl:comment>
        p {font-size: 10pt}
        h1 {font-family: arial; font-size: 12pt; font-weight: bold}
      </xsl:comment>
    </style>
    </head>
    <body>
      <xsl:apply-templates/>
    </body>
    </html>
  </xsl:template>

  <xsl:template match="draw:page">
    <h1>slide <xsl:number/>:
    <xsl:value-of select="draw:text-box[1]/text:p[1]"/></h1>
    <xsl:apply-templates select="presentation:notes"/>
  </xsl:template>

  <xsl:template match="text:p">
    <p><xsl:apply-templates/></p>
  </xsl:template>

  <xsl:template match="text:span[@text:style-name='T1']">
    <b><xsl:apply-templates/></b>
  </xsl:template>

</xsl:stylesheet>


