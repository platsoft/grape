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
	<div class = "nav" style = "width: 100%">
	<div class = "nav" style = "width: 30%; min-height: 100%; float: left">
		<div style ="width: 80%; float: left; padding-left: 50px">
			<xsl:for-each select="item">
				<ul style = "">
					<li>
						 <a href = "#{identifier/text()}"><xsl:value-of select="tags/method/text()" /><xsl:text> </xsl:text>  <xsl:value-of select="identifier/text()"/></a>
					</li>
				</ul>
			</xsl:for-each>
		</div>
	</div>
	<div class="http_calls" style = "width:69.9%; float: left;background-color: white;">
	<div style = "padding-left: 80px; width:70%">
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
				<h3>Request Body</h3>
				<xsl:for-each select="tags/body">
					<xsl:call-template name="body_parameters" />
				</xsl:for-each>
				</div>
			</xsl:if>
			<xsl:if test="tags/param">
				<div>
				<h3>Parameters</h3>
				<xsl:for-each select="tags/param">
					<xsl:call-template name="body_parameters" />
				</xsl:for-each>
				</div>
			</xsl:if>

			<xsl:if test="tags/returnsample">
				<div>
				<h3>Example Result</h3>
				<div class = "code-block">
				<code><pre style = "padding-left: 10px"><xsl:value-of select="tags/returnsample/text()" /></pre></code>
				</div>
				</div>
			</xsl:if>

		</div>
	</xsl:for-each>
		</div>
	</div>
<br/><br/>
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
