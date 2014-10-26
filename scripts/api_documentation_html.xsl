<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns="http://www.w3.org/1999/xhtml"
                version="1.0">

<xsl:output method="html" encoding="UTF-8" omit-xml-declaration="no" standalone="yes" indent="yes"/>


<xsl:template match="/">
<html>
	<xsl:apply-templates />
</html>
</xsl:template>

<xsl:template match="http_api_call">
	<div class="http_calls">
		<h1>HTTP CALLS</h1>
	<xsl:for-each select="item">
		<div>
			<h2>
			<xsl:value-of select="tags/method/text()" /><xsl:text> </xsl:text><xsl:value-of select="identifier/text()" />
			</h2>

			<span><xsl:value-of select="tags/desc/text()" /></span><br />
			<span style="font-size: 12px;">File: <xsl:value-of select="filename/text()" /></span><br />

			<xsl:if test="tags/body">
				<div>
				Description of fields in the request body:
				<xsl:for-each select="tags/body">
					<xsl:call-template name="body_parameters" />
				</xsl:for-each>
				</div>
			</xsl:if>
			<xsl:if test="tags/param">
				<div>
				Description of parameters in the request:
				<xsl:for-each select="tags/param">
					<xsl:call-template name="body_parameters" />
				</xsl:for-each>
				</div>
			</xsl:if>

			<xsl:if test="tags/returnsample">
				<div>
				Sample return message:
				<code><pre><xsl:value-of select="tags/returnsample/text()" /></pre></code>
				</div>
			</xsl:if>

		</div>
	</xsl:for-each>
	</div>
</xsl:template>
	
<xsl:template name="body_parameters">
	<table border="1">
	<tr><td>Name</td><td>Type</td><td>Optional</td><td>Default</td></tr>
	<xsl:for-each select="item">
		<xsl:call-template name="body_parameter_item" />
	</xsl:for-each>
	</table>
</xsl:template>
<xsl:template name="body_parameter_item">
	<xsl:variable name="depth" select="count(ancestor::*) - 5"/>
	<tr>
		<td>
		
			<xsl:for-each select="(//node())[$depth >= position()]">&#x2192;</xsl:for-each>
			<xsl:value-of select="name" />
		</td>
		<td><xsl:value-of select="type" /></td>
		<td><xsl:value-of select="optional" /></td>
		<td><xsl:value-of select="default" /></td>
	</tr>
	<xsl:for-each select="item">
		<xsl:call-template name="body_parameter_item" />
	</xsl:for-each>
</xsl:template>



</xsl:stylesheet>
