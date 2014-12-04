<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:ri="http://register.regesta-imperii.de/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
    xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
    xmlns:owl ="http://www.w3.org/2002/07/owl#"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:telota="http://www.telota.de"
    xmlns:t="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="xs office table telota"
    version="2.0">
    <!-- Skript zur Konversion des Regesten-XML der Regesta Imperii in RDF
        Georg Vogeler <georg.vogeler@uni-graz.at>
        Zentrum für Informationsmodellierung - Austrian Centre for Digital Humanities, Universität Graz
        Version: 2014-12-04 -->
    <xsl:output indent="yes" method="xml" encoding="UTF-8" />
    <!-- Die beiden Variablen bestimmen den Dateinamen der TEI-Quelle für die Regestenliste und den Dateinamen des daraus erzeugten RDF. Es wird davon ausgegangen, daß die TEI-Quelle im selben Verzeichnis wie die Registerdatei liegt.  -->
    <xsl:variable name="kopfzeilen-tei">RI13_Kopfzeilen.xml</xsl:variable>
    <xsl:variable name="regesten-rdf">regesten.rdf</xsl:variable>

    <xsl:template match="/">
        <rdf:RDF>
            <!-- 
            Hinweis: die erste Zeile dient dazu, aus der TEI-Konversion der Regestenkopftabelle RDF zu machen. Das resultierende RDF muß dann für die Abarbeitung der zweiten Anweisung vorhanden sein. -->
            <xsl:choose>
                <xsl:when test="document($regesten-rdf)"><xsl:apply-templates select="//*[starts-with(name(),'Stufe')]"/></xsl:when>
                <xsl:otherwise><xsl:result-document href="{$regesten-rdf}"><rdf:RDF><xsl:apply-templates select="document($kopfzeilen-tei)//t:body/t:table[1]//t:row"/></rdf:RDF></xsl:result-document>
                    <xsl:comment><xsl:value-of select="$regesten-rdf"/> aus <xsl:value-of select="$kopfzeilen-tei"/> erzeugt. Bitte führen Sie das Skript noch einmal aus, um das Register in RDF umzuwandeln.</xsl:comment>
                </xsl:otherwise></xsl:choose>
        </rdf:RDF>
    </xsl:template>
    <!-- Template für die Umwandlung der TEI-Quelle in RDF -->
    <xsl:template match="t:row">
        <rdf:Description>
            <xsl:attribute name="rdf:about">http://www.regesta-imperii.de/id/<xsl:value-of select="t:cell[13]"/></xsl:attribute>
            <ri:hatnummer><xsl:value-of select="t:cell[8]"/></ri:hatnummer>
            <ri:in-heft><xsl:value-of select="t:cell[5]"/></ri:in-heft>
            <ri:ausgestellt-von><xsl:value-of select="t:cell[9]"/></ri:ausgestellt-von>
            <ri:ausgestellt-am><xsl:value-of select="t:cell[1]"/></ri:ausgestellt-am>
            <!-- FixMe: URIs von Abteilung und Band sind fiktiv -->
            <ri:in-Abteilung rdf:resource="http://www.regesta-imperii.de/abt/{t:cell[4]}"/>
            <ri:in-Band rdf:resource="http://www.regesta-imperii.de/bd/{t:cell[4]}-{t:cell[5]}"/>
        </rdf:Description>
    </xsl:template>
    
    <!-- 
        Hier beginnt die Umwandlung des Register-XML in RDF
    -->
    <xsl:template match="node()[starts-with(name(),'Stufe')]">
        <!-- Jeder Stufeneintrag ist eine Resource, über die Aussagen gemacht werden. -->
        <rdf:Description about="http://register.regesta-imperii.de/id/{@id}">
            <xsl:apply-templates select="Inhalt"/>
            <!-- FixMe: Listen mit Texten sind noch kompliziert: tokenize(.,';') bzw. tokenize(.,',') -->
            <xsl:apply-templates select="Inhalt/*[starts-with(name(),'Regestennummer')]"></xsl:apply-templates>
            <xsl:if test="parent::*[starts-with(name(),'Stufe')]"><skos:broader rdf:resource="http://register.regesta-imperii.de/id/{parent::*/@id}"></skos:broader></xsl:if>
        </rdf:Description>
    </xsl:template>
    <!-- 
        Der Registertext wird ri:inhalt
    -->
    <xsl:template match="Inhalt">
        <ri:inhalt><!-- FixMe: Datentyp XML       -->
            <xsl:for-each select="ancestor-or-self::*[starts-with(name(),'Stufe')]/Inhalt"><xsl:if test="position() gt 1"><xsl:text>, </xsl:text></xsl:if><xsl:apply-templates select="text()|Kursivtext"/></xsl:for-each>
        </ri:inhalt>
        <!-- FixMe: Die aufgelisteten Verweise sehen im Inhalt noch komisch aus (s.o.) -->
        <xsl:if test="text()[matches(.,' s. ')] and ref">
            <xsl:for-each select="ref|Kursivtext/ref"><skos:relatedMatch rdf:resource="http://register.regesta-imperii.de/id/{@ziel}"/></xsl:for-each>
        </xsl:if>
    </xsl:template>
    <xsl:template match="text()" priority="-2">
        <xsl:value-of select="normalize-space(.)"/>
    </xsl:template>
    <xsl:template match="Kursivtext">
        <xsl:copy-of select="."/>
    </xsl:template>
    <!-- 
        Hier die eigentlichen Regestennummern
    -->
    <xsl:template match="*[starts-with(name(),'Regestennummer')]">
        <xsl:variable name="regestennummern" select="tokenize(.,',')"/>
        <xsl:variable name="property">
            <xsl:choose>
                <xsl:when test="name()='RegestennummerFett'">receipient</xsl:when>
                <xsl:otherwise>mentioned</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:for-each select="$regestennummern">
            <xsl:if test="normalize-space(.)!=''">
                <xsl:variable name="rid">
                    <!-- CA: heft wird Null, Nummer erhält das CA davor -->
                    <xsl:choose>
                        <xsl:when test="substring-before(substring-after(.,'#'),'-')='CA'">
                            <heft><xsl:value-of select="0"/></heft>
                            <nummer><xsl:value-of select="concat('CA',substring-after(normalize-space(.),'-'))"/></nummer>
                        </xsl:when>
                        <xsl:otherwise>
                            <heft><xsl:value-of select="substring-before(substring-after(.,'#'),'-')"/></heft>
                            <nummer><xsl:value-of select="substring-after(normalize-space(.),'-')"/></nummer>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:element name="ri:{$property}">
                    <xsl:attribute name="rdf:resource" select="document($regesten-rdf)//rdf:Description[ri:in-heft=string($rid/heft) and ri:hatnummer=string($rid/nummer)]/@rdf:about"/>
                </xsl:element>
            </xsl:if>                   
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>