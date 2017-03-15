<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
	xmlns:fo="http://www.w3.org/1999/XSL/Format"
>

	<xsl:template match="/" family-font="calibri">
		<fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format">
			<fo:layout-master-set>
				<fo:simple-page-master master-name="first" page-height="210mm" page-width="297mm" margin-top="1cm" margin-bottom="0.5cm" margin-left="0.5cm" margin-right="0.5cm">
					<fo:region-body margin-top="5cm" margin-bottom="3cm" />
					<fo:region-before extent="1.0cm" />
					<fo:region-after extent="2.8cm" />
				</fo:simple-page-master>			
			</fo:layout-master-set>
			<fo:page-sequence master-reference="first" id="seq1" >
				<fo:static-content flow-name="xsl-region-before" extent="1.0cm" >
					<fo:block>
						<fo:block space-after="0.1cm" text-align="center" font-size="17pt" font-weight="bold">PLATINUM SOFTWARE</fo:block>
					</fo:block>
				</fo:static-content>
				<fo:flow flow-name="xsl-region-body" >
					<fo:block text-align="end">
						<xsl:apply-templates select="user" />
					</fo:block>
				</fo:flow>
			</fo:page-sequence>
		</fo:root>
	</xsl:template>

	<xsl:template match="user">
		<fo:block font-size="8pt">
			Username: 
			<xsl:text select="username/text()" />
		</fo:block>				
	</xsl:template>
</xsl:stylesheet>

<!-- xsltproc picking_list.xsl picking_list.xml >picking_list.fo && /opt/fop-1.1/fop picking_list.fo -pdf picking_list.pdf && evince picking_list.pdf -->
