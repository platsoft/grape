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
	<link rel="stylesheet" type="text/css" href="styles.css"></link>
	<div style ="width: 30%; float: left; padding-left: 20px">
	<xsl:for-each select="item">
		<ul>
			<li>
				 <a href = "#{identifier/text()}"><xsl:value-of select="tags/method/text()" /><xsl:text> </xsl:text>  <xsl:value-of select="identifier/text()"/></a>
			</li>
		</ul>
	</xsl:for-each>
	</div>
	<div class="http_calls" style = "width: 50%; float: left">
		<h1>HTTP CALLS</h1>
	<xsl:for-each select="item">
		<div>
			<h2 id = "{identifier/text()}">
			<xsl:value-of select="tags/method/text()" /><xsl:text> </xsl:text><xsl:value-of select="identifier/text()" />
			</h2>

			<p><i><xsl:value-of select="tags/desc/text()" /></i></p>
			<span style="font-size: 14px;">Filename: <xsl:value-of select="filename/text()" /></span><br />

			<xsl:if test="tags/body">
				<div>
				Request Body
				<xsl:for-each select="tags/body">
					<xsl:call-template name="body_parameters" />
				</xsl:for-each>
				</div>
			</xsl:if>
			<xsl:if test="tags/param">
				<div>
				Parameters
				<xsl:for-each select="tags/param">
					<xsl:call-template name="body_parameters" />
				</xsl:for-each>
				</div>
			</xsl:if>

			<xsl:if test="tags/returnsample">
				<div>
				Example Result
				<div class = "code-block">
				<code><pre style = "padding-left: 10px"><xsl:value-of select="tags/returnsample/text()" /></pre></code>
				</div>
				</div>
			</xsl:if>

		</div>
	</xsl:for-each>
	</div>
</xsl:template>
	
<xsl:template name="body_parameters">
	<div class = "border">
	<table border="1" class = "description-table" style = "width: 100%">
	<tr><th>Name</th><th>Type</th><th>Optional</th><th>Default</th></tr>
	<xsl:for-each select="item">
		<xsl:call-template name="body_parameter_item" />
	</xsl:for-each>
	</table>
	</div>
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
