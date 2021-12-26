<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="html" encoding="utf-8"/>
   <xsl:template match="/">
      <html>
         <body>
            <h1>Drivers</h1>
            <h2>PCI / device specific</h2>
            <table border="1">
               <tr bgcolor="#9acd32">
                  <th>Vendor name</th>
                  <th>Vendor Id</th>
                  <th>Device name</th>
                  <th>Device Id</th>
                  <th>Driver install command</th>
               </tr>
               <xsl:for-each select="/Drivers/PCI/deviceSpecific/vendor">
                  <xsl:for-each select="./device">
                     <tr>
                        <td>
                           <xsl:value-of select="../@name" />
                        </td>
                        <td>
                           <xsl:value-of select="../@id" />
                        </td>
                        <td>
                           <xsl:value-of select="@name" />
                        </td>
                        <td>
                           <xsl:value-of select="@id" />
                        </td>
                        <td>
                           <xsl:value-of select="." />
                        </td>
                     </tr>
                  </xsl:for-each>
               </xsl:for-each>
            </table>
            <h2>PCI / class specific</h2>
            <table border="1">
               <tr bgcolor="#9acd32">
                  <th>Class name</th>
                  <th>Class number</th>
                  <th>Subclass name</th>
                  <th>Subclass number</th>
                  <th>Protocol name</th>
                  <th>Protocol number</th>
                  <th>Driver install command</th>
               </tr>
               <xsl:for-each select="/Drivers/PCI/classSpecific/class">
                  <xsl:for-each select="./subclass">
                     <xsl:choose>
                        <xsl:when test="./protocol">
                           <xsl:for-each select="./protocol">
                              <tr>
                                 <td>
                                    <xsl:value-of select="../../@name" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="../../@nbr" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="../@name" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="../@nbr" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="@name" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="@nbr" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="." />
                                 </td>
                              </tr>
                           </xsl:for-each>
                        </xsl:when>
                        <xsl:otherwise>
                           <td>
                              <xsl:value-of select="../@name" />
                           </td>
                           <td>
                              <xsl:value-of select="../@nbr" />
                           </td>
                           <td>
                              <xsl:value-of select="@name" />
                           </td>
                           <td>
                              <xsl:value-of select="@nbr" />
                           </td>
                           <td />
                           <td />
                           <td />
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:for-each>
               </xsl:for-each>
            </table>
            <h2>USB / device specific</h2>
            <table border="1">
               <tr bgcolor="#9acd32">
                  <th>Vendor name</th>
                  <th>Vendor Id</th>
                  <th>Device name</th>
                  <th>Device Id</th>
                  <th>Driver install command</th>
               </tr>
               <xsl:for-each select="/Drivers/USB/deviceSpecific/vendor">
                  <xsl:for-each select="./device">
                     <tr>
                        <td>
                           <xsl:value-of select="../@name" />
                        </td>
                        <td>
                           <xsl:value-of select="../@id" />
                        </td>
                        <td>
                           <xsl:value-of select="@name" />
                        </td>
                        <td>
                           <xsl:value-of select="@id" />
                        </td>
                        <td>
                           <xsl:value-of select="." />
                        </td>
                     </tr>
                  </xsl:for-each>
               </xsl:for-each>
            </table>
         </body>
      </html>
      <h2>USB / class specific</h2>
      <table border="1">
         <tr bgcolor="#9acd32">
            <th>Class name</th>
            <th>Class number</th>
            <th>Subclass name</th>
            <th>Subclass number</th>
            <th>Protocol name</th>
            <th>Protocol number</th>
            <th>Driver install command</th>
         </tr>
         <xsl:for-each select="/Drivers/USB/classSpecific/class">
            <xsl:choose>
               <xsl:when test="./subclass">
                  <xsl:for-each select="./subclass">
                     <xsl:choose>
                        <xsl:when test="./protocol">
                           <xsl:for-each select="./protocol">
                              <tr>
                                 <td>
                                    <xsl:value-of select="../../@name" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="../../@nbr" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="../@name" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="../@nbr" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="@name" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="@nbr" />
                                 </td>
                                 <td>
                                    <xsl:value-of select="." />
                                 </td>
                              </tr>
                           </xsl:for-each>
                        </xsl:when>
                        <xsl:otherwise>
                           <tr>
                              <td>
                                 <xsl:value-of select="../@name" />
                              </td>
                              <td>
                                 <xsl:value-of select="../@nbr" />
                              </td>
                              <td>
                                 <xsl:value-of select="@name" />
                              </td>
                              <td>
                                 <xsl:value-of select="@nbr" />
                              </td>
                              <td />
                              <td />
                              <td />
                           </tr>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:for-each>
               </xsl:when>
               <xsl:otherwise>
                  <tr>
                     <td>
                        <xsl:value-of select="@name" />
                     </td>
                     <td>
                        <xsl:value-of select="@nbr" />
                     </td>
                     <td />
                     <td />
                     <td />
                     <td />
                     <td />
                  </tr>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </table>
   </xsl:template>
</xsl:stylesheet>