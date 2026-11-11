"""Ordering data for SB1 (copied from TB1): DigiKey part numbers, qty-1 prices, links and manufacturer datasheets.

Vendor convention follows the v0.1 board: DigiKey, cut-tape part number where one exists, qty-1 unit price
in USD. Prices and stock come from DigiKey's distributor feed (via Octopart / TrustedParts), checked
2026-10-17. Stock moves daily: recheck before ordering.

design.py still names the original parts. apply() swaps in the orderable part where the original was only
a spec ("1x8 2.54 mm header") or is out of stock at DigiKey, then fills Datasheet, Vendor Part #, Price and
Vendor Link on every symbol. Parts that are ordered with a symbol but aren't symbols themselves (module
sockets, jumper shunts) go in the symbol's "Also order" field and get their own BOM lines.
"""

PRICE_NOTE = ("DigiKey qty-1 unit prices in USD from DigiKey's feed via Octopart/TrustedParts, checked 2026-10-17 "
              "(1206/1210 passives and SB1 parts 2026-10-25; SB1 rev B and Mainboard-USB parts 2026-10-31); "
              "recheck before ordering")


def _dk(pn, price, link, ds, desc=''):
    return {'pn': pn, 'price': price, 'link': link, 'ds': ds, 'desc': desc}


YAGEO_RC = 'https://yageogroup.com/content/datasheet/asset/file/PYU-RC_GROUP_51_ROHS_L'
SULLINS_FEMALE = 'https://www.sullinscorp.com/drawings/78_P(N)PxCxxxLFBN-RC,_10492-H.pdf'
SULLINS_MALE = 'https://www.sullinscorp.com/catalogs/77_PAGE108-109_.100_MALE_HDR.pdf'
VISHAY_WSL = 'https://www.vishay.com/docs/30100/wsl.pdf'
SAMSUNG = 'https://weblib.samsungsem.com/mlcc/mlcc-ec-data-sheet.do?partNumber='
KEMET_A759 = 'https://www.mouser.com/datasheet/2/447/KEM_A4072_A759-3316694.pdf'

DK = {
    # ---- ICs and semiconductors
    'INA219AIDR': _dk('296-23978-1-ND', '2.25', 'https://www.digikey.com/en/products/detail/texas-instruments/INA219AIDR/1984881', 'https://www.ti.com/lit/ds/symlink/ina219.pdf'),
    'TLV62569DBVR': _dk('296-47360-1-ND', '0.28', 'https://www.digikey.com/en/products/detail/texas-instruments/TLV62569DBVR/6580119', 'https://www.ti.com/lit/ds/symlink/tlv62569.pdf'),
    'LP5907MFX-3.3/NOPB': _dk('296-38557-1-ND', '0.66', 'https://www.digikey.com/en/products/detail/texas-instruments/LP5907MFX-3-3-NOPB/3906441', 'https://www.ti.com/lit/ds/symlink/lp5907.pdf'),
    'USBLC6-2SC6': _dk('497-5235-1-ND', '0.54', 'https://www.digikey.com/en/products/detail/stmicroelectronics/USBLC6-2SC6/1040559', 'https://www.st.com/resource/en/datasheet/usblc6-2.pdf'),
    'SN74LVC1G126DBVT': _dk('296-32293-1-ND', '0.97', 'https://www.digikey.com/en/products/detail/texas-instruments/SN74LVC1G126DBVT/1591996', 'https://www.ti.com/lit/ds/symlink/sn74lvc1g126.pdf'),
    'SRV05-4.TCT': _dk('SRV05-4CT-ND', '1.81', 'https://www.digikey.com/en/products/detail/semtech-corporation/SRV05-4-TCT/1000944', 'https://semtech.my.salesforce.com/sfc/p/E0000000JelG/a/44000000MCn6/BeAzV1kgq8LEQB.FR71VkMB1v3NUxVrSyFjXw9p4pnk'),
    'SN74LVC1G04DBVR': _dk('296-11599-1-ND', '0.15', 'https://www.digikey.com/en/products/detail/texas-instruments/SN74LVC1G04DBVR/385716', 'https://www.ti.com/lit/ds/symlink/sn74lvc1g04.pdf'),
    'TPS2051CDBVT': _dk('296-29759-1-ND', '1.29', 'https://www.digikey.com/en/products/detail/texas-instruments/TPS2051CDBVT/296-29759-1-ND/2767607', 'https://www.ti.com/lit/ds/symlink/tps2051c.pdf'),
    'SC16IS752IPW,128': _dk('568-11944-1-ND', '7.92', 'https://www.digikey.com/en/products/detail/nxp-usa-inc/SC16IS752IPW-128/1158200', 'https://www.nxp.com/docs/en/data-sheet/SC16IS752_SC16IS762.pdf'),
    'AO4407A': _dk('785-1022-1-ND', '1.24', 'https://www.digikey.com/en/products/detail/alpha-omega-semiconductor-inc/AO4407A/1855794', 'https://www.aosmd.com/res/datasheets/AO4407A.pdf'),
    '2N7002LT1G': _dk('2N7002LT1GOSCT-ND', '0.25', 'https://www.digikey.com/en/products/detail/onsemi/2N7002LT1G/918297', 'https://www.onsemi.com/pdf/datasheet/2n7002l-d.pdf'),
    'AO3400A': _dk('785-1000-1-ND', '0.52', 'https://www.digikey.com/en/products/detail/alpha-omega-semiconductor-inc/AO3400A/1855942', 'https://www.aosmd.com/res/datasheets/AO3400A.pdf'),
    'SMBJ5.0A': _dk('SMBJ5.0ALFCT-ND', '0.50', 'https://www.digikey.com/en/products/detail/littelfuse-inc/SMBJ5-0A/285950', 'https://www.littelfuse.com/assetdocs/tvs-diodes-smbj-series-datasheet?assetguid=ba555e99-a12d-4f72-a0b6-86b06c67171e'),
    'LTST-C150GKT': _dk('160-1169-1-ND', '0.21', 'https://www.digikey.com/en/products/detail/liteon/LTST-C150GKT/269241', 'https://www.mouser.com/datasheet/2/239/Lite_On_LTST_C150GKT-1175255.pdf'),
    'SS34-E3/57T': _dk('SS34-E3/57TGICT-ND', '1.02', 'https://www.digikey.com/en/products/detail/vishay-general-semiconductor-diodes-division/SS34-E3-57T/1091554', 'https://www.vishay.com/docs/88751/ss32.pdf'),
    # ---- capacitors (1206; 10 uF and 22 uF in 1210; moved from 0805 on 2026-10-25)
    'CL31B104KBCNNNC': _dk('1276-1017-1-ND', '0.15', 'https://www.digikey.com/en/products/detail/samsung-electro-mechanics-america-inc/CL31B104KBCNNNC/3889103', SAMSUNG + 'CL31B104KBCNNN'),
    'C1206C103K5RACTU': _dk('399-C1206C103K5RACTUCT-ND', '0.22', 'https://www.digikey.com/en/products/detail/kemet/C1206C103K5RACTU/411509', 'https://www.yageogroup.com/content/datasheet/asset/file/KEM_C1002_X7R_SMD'),
    'CC1206KKX7R9BB105': _dk('311-1963-1-ND', '0.36', 'https://www.digikey.com/en/products/detail/yageo/CC1206KKX7R9BB105/5195865', 'https://yageogroup.com/content/datasheet/asset/file/UPY-GPHC_X7R_6_3V-TO-250V'),
    'CL31B334KBFNNNE': _dk('1276-1138-1-ND', '0.22', 'https://www.digikey.com/en/products/detail/samsung-electro-mechanics-america-inc/CL31B334KBFNNNE/3889224', SAMSUNG + 'CL31B334KBFNNN'),
    'C3216X7R1E475K160AC': _dk('445-1606-1-ND', '0.31', 'https://www.digikey.com/en/products/detail/tdk-corporation/C3216X7R1E475K160AC/634401', 'https://product.tdk.com/en/search/capacitor/ceramic/mlcc/info?part_no=C3216X7R1E475K160AC'),
    'C1206C270J5GACTU': _dk('399-C1206C270J5GACTUCT-ND', '0.27', 'https://www.digikey.com/en/products/detail/kemet/C1206C270J5GACTU/411473', 'https://www.yageogroup.com/content/datasheet/asset/file/KEM_C1003_C0G_SMD'),
    'CC1206CRNPO9BN6R8': _dk('311-4367-1-ND', '0.31', 'https://www.digikey.com/en/products/detail/yageo/CC1206CRNPO9BN6R8/8025456', 'https://yageogroup.com/download/specsheet/CC1206CRNPO9BN6R8'),
    'GRM32DR71E106KA12L': _dk('490-1867-1-ND', '0.93', 'https://www.digikey.com/en/products/detail/murata-electronics/GRM32DR71E106KA12L/587303', 'https://pim.murata.com/asset/pim4/ceramicCapacitorSMD/GRM32DR71E106KA12-01A-EN_PDF_CERAMICCAPACITORSMD'),
    'GRM32ER61E226KE15L': _dk('490-3889-1-ND', '2.21', 'https://www.digikey.com/en/products/detail/murata-electronics/GRM32ER61E226KE15L/965931', 'https://www.mouser.com/datasheet/2/281/1/GRM32ER61E226KE15_01A-1988202.pdf'),
    # ---- magnetics, protection, shunts
    'BLM41PG600SN1L': _dk('490-1058-1-ND', '0.75', 'https://www.digikey.com/en/products/detail/murata-electronics/BLM41PG600SN1L/584267', 'https://www.murata.com/products/productdata/8796739862558/ENFA0007.pdf'),
    # 220 ohm @ 100 MHz, 4 A, 20 mOhm max, 1206 (new Taiyo Yuden number for FBMH3216HM221NT, 587-3250-1-ND)
    'LSMGA321616T221NG': _dk('587-LSMGA321616T221NGCT-ND', '0.32', 'https://www.digikey.com/en/products/detail/taiyo-yuden/LSMGA321616T221NG/16671989', 'https://mm.digikey.com/Volume0/opasdata/d220001/medias/docus/5692/LSMGA321616T221NG.pdf'),
    'SRN4018-2R2M': _dk('SRN4018-2R2MCT-ND', '0.40', 'https://www.digikey.com/en/products/detail/bourns-inc/SRN4018-2R2M/SRN4018-2R2MCT-ND/3821517', 'https://www.bourns.com/docs/Product-Datasheets/SRN4018.pdf'),
    '2920L300DR': _dk('F5710CT-ND', '0.98', 'https://www.digikey.com/en/products/detail/littelfuse-inc/2920L300DR/1211341', 'https://www.littelfuse.com/assetdocs/resettable-ptcs-2920l-datasheet?assetguid=f237e8c2-1ed9-4c13-a738-dbe0738b3d2c'),
    'WSL1206R0100FEA': _dk('WSLC-.01CT-ND', '0.75', 'https://www.digikey.com/en/products/detail/vishay-dale/WSL1206R0100FEA/712486', VISHAY_WSL),
    'WSL1206R0500FEA': _dk('WSLC-.05CT-ND', '0.93', 'https://www.digikey.com/en/products/detail/vishay-dale/WSL1206R0500FEA/712495', VISHAY_WSL),
    'WSL1206R1000FEA': _dk('WSLC-.10CT-ND', '0.65', 'https://www.digikey.com/en/products/detail/vishay-dale/WSL1206R1000FEA/712501', VISHAY_WSL),
    # ---- resistors (Yageo RC series, 1206 since 2026-10-25)
    'RC1206FR-075K1L': _dk('311-5.10KFRCT-ND', '0.11', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-075K1L/731894', YAGEO_RC),
    'RC1206FR-071ML': _dk('311-1.00MFRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-071ML/731335', YAGEO_RC),
    'RC1206FR-07100KL': _dk('311-100KFRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-07100KL/731439', YAGEO_RC),
    'RC1206FR-07453KL': _dk('311-453KFRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-07453KL/731872', YAGEO_RC),
    'RC1206FR-072K2L': _dk('311-2.20KFRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-072K2L/731571', YAGEO_RC),
    'RC1206FR-074K7L': _dk('311-4.70KFRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-074K7L/731834', YAGEO_RC),
    'RC1206FR-071KL': _dk('311-1.00KFRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-071KL/731334', YAGEO_RC),
    'RC1206FR-0710KL': _dk('311-10.0KFRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-0710KL/731430', YAGEO_RC),
    'RC1206FR-07220RL': _dk('311-220FRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-07220RL/731640', YAGEO_RC),
    'RC1206FR-0733RL': _dk('311-33.0FRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-0733RL/731765', YAGEO_RC),
    'RC1206FR-0722KL': _dk('311-22.0KFRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-0722KL/731635', YAGEO_RC),
    'RC1206FR-0710RL': _dk('311-10.0FRCT-ND', '0.16', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-0710RL/731429', YAGEO_RC),
    # ---- connectors, sockets, headers, test points, shunts
    'USB4105-GF-A': _dk('2073-USB4105-GF-ACT-ND', '0.80', 'https://www.digikey.com/en/products/detail/gct/USB4105-GF-A/11198441', 'https://gct.co/download?type=PDFDrawing&name=USB4105.pdf'),
    'SM04B-SRSS-TB(LF)(SN)': _dk('455-SM04B-SRSS-TBCT-ND', '0.51', 'https://www.digikey.com/en/products/detail/jst-sales-america-inc/SM04B-SRSS-TB-LF-SN/926710', 'https://www.jst-mfg.com/product/pdf/eng/eSH.pdf'),
    'B5B-XH-A(LF)(SN)': _dk('455-B5B-XH-A-ND', '0.20', 'https://www.digikey.com/en/products/detail/jst-sales-america-inc/B5B-XH-A(LF)(SN)/1530483', 'https://www.jst-mfg.com/product/pdf/eng/eXH.pdf'),
    'B4B-XH-A(LF)(SN)': _dk('455-B4B-XH-A-ND', '0.17', 'https://www.digikey.com/en/products/detail/jst-sales-america-inc/B4B-XH-A(LF)(SN)/455-2249-ND/1651047', 'https://www.jst-mfg.com/product/pdf/eng/eXH.pdf'),
    'PPTC221LFBN-RC': _dk('S7020-ND', '1.36', 'https://www.digikey.com/en/products/result?keywords=S7020-ND', SULLINS_FEMALE, '1x22 female socket 2.54 mm'),
    'PPTC161LFBN-RC': _dk('S7014-ND', '0.93', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PPTC161LFBN-RC/810154', SULLINS_FEMALE, '1x16 female socket 2.54 mm'),
    'PPTC071LFBN-RC': _dk('S7005-ND', '0.58', 'https://www.digikey.com/en/products/result?keywords=S7005-ND', SULLINS_FEMALE),
    'PPTC061LFBN-RC': _dk('S7004-ND', '0.47', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PPTC061LFBN-RC/810145', SULLINS_FEMALE),
    'PPTC051LFBN-RC': _dk('S6103-ND', '0.44', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PPTC051LFBN-RC/807239', SULLINS_FEMALE),
    'LPPB051NFFN-RC': _dk('S9008E-05-ND', '0.93', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/LPPB051NFFN-RC/1786363', 'https://s3.amazonaws.com/catalogspreads-pdf/PAGE96-97%20.050%20FEMALE%20HDR%20ST%20RA%20SMT.pdf'),
    'GRPB051VWVN-RC': _dk('S9014E-05-ND', '0.35', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/GRPB051VWVN-RC/1786441', 'https://s3.amazonaws.com/catalogspreads-pdf/PAGE94-95%20.050%20MALE%20HDR%20ST%20RA%20SMT.pdf'),
    'NPPN042AFCN-RC': _dk('S5750-04-ND', '1.04', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/NPPN042AFCN-RC/804789', 'https://drawings-pdf.s3.amazonaws.com/10497.pdf'),
    'PPTC041LFBN-RC': _dk('S7002-ND', '0.42', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PPTC041LFBN-RC/810144', SULLINS_FEMALE),
    'MSPM-7-01': _dk('RPC2012-ND', '0.32', 'https://www.digikey.com/en/products/detail/essentra-components/MSPM-7-01/392749', '',
                     'Nylon board support, snap lock both ends, 11.13 mm between boards, 3.18 mm holes in 1.57 mm boards'),
    'PPTC081LFBN-RC': _dk('S7006-ND', '0.58', 'https://www.digikey.com/en/products/result?keywords=S7006-ND', SULLINS_FEMALE),
    'PEC02SAAN': _dk('35-PEC02SAAN-ND', '0.16', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PEC02SAAN/859155', SULLINS_MALE),
    'PEC03SAAN': _dk('35-PEC03SAAN-ND', '0.22', 'https://www.digikey.com/en/products/result?keywords=35-PEC03SAAN-ND', SULLINS_MALE),
    'PPTC051LGBN-RC': _dk('S5441-ND', '0.63', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PPTC051LGBN-RC/775899', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PPTC051LGBN-RC/775899'),   # right-angle (checked 11/01 via TrustedParts)
    'PEC05SAAN': _dk('35-PEC05SAAN-ND', '0.36', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PEC05SAAN/859158', SULLINS_MALE),
    'PEC08SAAN': _dk('35-PEC08SAAN-ND', '0.52', 'https://www.digikey.com/en/products/result?keywords=35-PEC08SAAN-ND', SULLINS_MALE),
    'PEC04DAAN': _dk('35-PEC04DAAN-ND', '0.49', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PEC04DAAN/860595', SULLINS_MALE),
    'PEC06DAAN': _dk('35-PEC06DAAN-ND', '0.67', 'https://www.digikey.com/en/products/result?keywords=35-PEC06DAAN-ND', SULLINS_MALE),
    'QPC02SXGN-RC': _dk('S9337-ND', '0.10', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/QPC02SXGN-RC/2618262', 'https://www.sullinscorp.com/drawings/284_SXGN_11510.pdf', '2-pos 2.54 mm shunt'),
    '5000': _dk('36-5000-ND', '0.35', 'https://www.digikey.com/en/products/detail/keystone-electronics/5000/255326', 'https://www.keyelco.com/userAssets/file/K75p62.pdf'),
    '5001': _dk('36-5001-ND', '0.27', 'https://www.digikey.com/en/products/detail/keystone-electronics/5001/255327', 'https://www.keyelco.com/userAssets/file/K75p62.pdf'),
    # ---- polymer caps (KEMET: Panasonic OS-CON offers don't show in DigiKey's feed)
    'A759KS477M1AAAE014': _dk('399-A759KS477M1AAAE014-ND', '0.82', 'https://www.digikey.com/en/products/result?keywords=399-A759KS477M1AAAE014-ND', KEMET_A759),
    'A758KK227M1CAAE014': _dk('399-14130-ND', '0.97', 'https://www.digikey.com/en/products/result?keywords=399-14130-ND', 'https://www.farnell.com/datasheets/3047249.pdf'),
    'A759EK107M1CAAE018': _dk('399-A759EK107M1CAAE018-ND', '0.59', 'https://www.digikey.com/en/products/result?keywords=399-A759EK107M1CAAE018-ND', KEMET_A759),
    'A759EK227M0JAAE018': _dk('399-A759EK227M0JAAE018-ND', '0.51', 'https://www.digikey.com/en/products/result?keywords=399-A759EK227M0JAAE018-ND', KEMET_A759),
    # ---- crystal
    'ATS122B': _dk('CTX905-ND', '0.66', 'https://www.digikey.com/en/products/result?keywords=CTX905-ND', 'https://www.datasheets.com/cts/ats122b'),
    # ---- SB1 (2026-10-25)
    # WCH parts aren't sold by DigiKey or Mouser; LCSC is WCH's main distributor (John is ordering there)
    'CH340C': _dk('LCSC C84681', '0.31', 'https://www.lcsc.com/product-detail/C84681.html', 'https://www.wch-ic.com/downloads/CH340DS1_PDF.html'),
    'TPS2113APWR': _dk('296-16938-1-ND', '2.96', 'https://www.digikey.com/en/products/result?keywords=296-16938-1-ND', 'https://www.ti.com/lit/ds/symlink/tps2113a.pdf'),
    'RC1206FR-07499RL': _dk('311-499FRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-07499RL/731891', YAGEO_RC),
    'RC1206FR-0727KL': _dk('311-27.0KFRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-0727KL/731679', YAGEO_RC),
    'SN74LVC1G11DBVR': _dk('296-16810-1-ND', '0.38', 'https://www.digikey.com/en/products/result?keywords=296-16810-1-ND', 'https://www.ti.com/lit/ds/symlink/sn74lvc1g11.pdf'),
    'BAT54CLT1G': _dk('BAT54CLT1GOSCT-ND', '0.14', 'https://www.digikey.com/en/products/result?keywords=BAT54CLT1GOSCT-ND', 'https://www.onsemi.com/pdf/datasheet/bat54lt1-d.pdf'),
    'SBH11-PBPC-D10-ST-BK': _dk('S9172-ND', '0.46', 'https://www.digikey.com/en/products/result?keywords=S9172-ND', 'https://www.futureelectronics.com/p/2009022', '2x10 shrouded header, keyed (same series as the 2x13 linked)'),
    # SB1 mics (2026-10-26): Adafruit breakouts plug into a 1x6 PPTC061LFBN-RC socket. Adafruit's 6049 page says the
    # ICS-43434 is discontinued and names the SPH0645 (3421, same outline and pinout) as the drop-in replacement.
    'Adafruit 6049': _dk('Adafruit 6049', '8.95', 'https://www.adafruit.com/product/6049', 'https://cdn-shop.adafruit.com/product-files/6049/6049_DS-000069-ICS-43434-v1.2.pdf', 'I2S MEMS mic breakout, ICS-43434'),
    'Adafruit 3421': _dk('Adafruit 3421', '6.95', 'https://www.adafruit.com/product/3421', 'https://learn.adafruit.com/adafruit-i2s-mems-microphone-breakout/', 'I2S MEMS mic breakout, SPH0645LM4H (fits the same socket)'),
    # ---- SB1 rev B (2026-10-31, DigiKey via TrustedParts)
    # 200528-0240 (24-way) has no qty-1 stock anywhere (9000 MOQ); the 20-way is stocked and fits the 20-wire pinout
    '200528-0200': _dk('900-2005280200CT-ND', '0.89', 'https://www.digikey.com/en/products/detail/molex/2005280200/15755866', 'https://www.molex.com/en-us/products/part-detail/2005280200',
                       '1.00 mm FFC ZIF, 20-way, back flip, ear-tab lock'),
    '24AA256UID-I/SN': _dk('24AA256UID-I/SN-ND', '1.10', 'https://www.digikey.com/en/products/detail/microchip-technology/24AA256UID-I-SN/4439784', 'https://ww1.microchip.com/downloads/en/DeviceDoc/20005202A.pdf'),
    # Bench light sensor (2026-10-31, John): Adafruit 4162 VEML7700 breakout (STEMMA QT version) on a 1x5 socket
    'Adafruit 4162': _dk('Adafruit 4162', '4.95', 'https://www.adafruit.com/product/4162', 'https://learn.adafruit.com/adafruit-veml7700', 'VEML7700 lux sensor breakout'),
    'VEML7700-TT': _dk('751-VEML7700-TTCT-ND', '1.44', 'https://www.digikey.com/en/products/detail/vishay-semiconductor-opto-division/VEML7700-TT/10817048', 'https://www.vishay.com/docs/84286/veml7700.pdf'),
    'LTST-C150KRKT': _dk('160-1405-1-ND', '0.19', 'https://www.digikey.com/en/products/detail/liteon/LTST-C150KRKT/386760', 'https://optoelectronics.liteon.com/upload/download/DS-22-99-0089/LTST-C150KRKT.pdf'),
    'RC1206FR-07100RL': _dk('311-100FRCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206FR-07100RL/731438', YAGEO_RC),
    'RC1206JR-070RL': _dk('311-0.0ERCT-ND', '0.10', 'https://www.digikey.com/en/products/detail/yageo/RC1206JR-070RL/732131', YAGEO_RC),
    'PEC04SAAN': _dk('35-PEC04SAAN-ND', '0.30', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PEC04SAAN/859157', SULLINS_MALE),
    'USB4125-GF-A': _dk('2073-USB4125-GF-ACT-ND', '0.65', 'https://www.digikey.com/en/products/detail/gct-emea-ltd/USB4125-GF-A/13547384', 'https://gct.co/files/drawings/usb4125.pdf',
                        'USB-C power-only receptacle, 6 pins, through-hole shell legs'),
    # ---- modules
    # John ordered 2026-10-18: AITRIP 2-pack ($11.99) of the red PN532 NFC module V3 (Elechouse layout)
    'PN532 NFC Module V3': _dk('Amazon B09BTH8GGJ (AITRIP 2-pack)', '6.00', 'https://www.amazon.com/dp/B09BTH8GGJ', 'https://www.elechouse.com/?p=5866'),
    'Notecarrier X': _dk('992-00153-B', '10.00', 'https://shop.blues.com/products/notecarrier-x', 'https://dev.blues.io/datasheets/notecarrier-datasheet/notecarrier-x-v1-2/'),
    # John's pick 2026-10-17: official Espressif board with the PCB antenna (N16R8 is not an Espressif ordering code).
    'ESP32-S3-DevKitC-1-N8R8': _dk('1965-ESP32-S3-DEVKITC-1-N8R8-ND', '15.00', 'https://www.digikey.com/short/mh83m8nn', 'https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32s3/esp32-s3-devkitc-1/user_guide.html'),
}

# Original part in design.py -> orderable part used instead, and why.
SUBST = {
    'SN74LVC1G126DBVR': ('SN74LVC1G126DBVT', 'TI', 'same part on a 250-piece reel; DBVR out of stock at DigiKey'),
    'TPS2051CDBVR': ('TPS2051CDBVT', 'TI', 'same part on a 250-piece reel; DBVR out of stock at DigiKey'),
    '1x8 2.54 mm header': ('PEC08SAAN', 'Sullins', ''),
    '1x5 2.54 mm header': ('PEC05SAAN', 'Sullins', ''),
    '1x3 2.54 mm header': ('PEC03SAAN', 'Sullins', ''),
    '1x4 2.54 mm header': ('PEC04SAAN', 'Sullins', ''),
    '2x6 2.54 mm header': ('PEC06DAAN', 'Sullins', ''),
    'OS-CON SEPC/SVPF family (470uF 10V, 8 mm dia, 3.5 mm pitch)': ('A759KS477M1AAAE014', 'KEMET', '470uF 10V polymer, 8 x 12 mm, 3.5 mm pitch'),
    'OS-CON SEPC/SVPF family (220uF 10V, 8 mm dia, 3.5 mm pitch)': ('A758KK227M1CAAE014', 'KEMET', '220uF 16V polymer, 8 x 8 mm, 3.5 mm pitch'),
    'OS-CON SEPC/SVPC family (100uF 10V, 6.3 mm)': ('A759EK107M1CAAE018', 'KEMET', '100uF 16V polymer, 6.3 x 8 mm, 2.5 mm pitch'),
    'OS-CON SEPC/SVPC family (220uF 6.3V, 6.3 mm); DNP until load-step tested': ('A759EK227M0JAAE018', 'KEMET', '220uF 6.3V polymer, 6.3 x 8 mm, 2.5 mm pitch; DNP until load-step tested'),
    'ECS-122.8-18-4X (or equivalent HC-49/US)': ('ATS122B', 'CTS', '12.288 MHz 18 pF HC-49/US; the ECS part is not stocked at DigiKey'),
}

# Spec-only parts that also need loose parts ordered with them: new MPN, manufacturer, [(mpn, mfr, qty)]
COMPOSITE = {
    '2x4 2.54 mm header + 4 shunts': ('PEC04DAAN', 'Sullins', [('QPC02SXGN-RC', 'Sullins', 4)]),
    '1x3 header + QPC02SXGN-RC shunt': ('PEC03SAAN', 'Sullins', [('QPC02SXGN-RC', 'Sullins', 1)]),
    'QPC02SXGN-RC (shunt) + 1x2 header': ('PEC02SAAN', 'Sullins', [('QPC02SXGN-RC', 'Sullins', 1)]),
    # LD6004 #1 on board: one socket is the line itself; the second socket and the module's pins go with it
    '2x LPPB051NFFN-RC sockets + 2x GRPB051VWVN-RC module pins': ('LPPB051NFFN-RC', 'Sullins',
                                                                  [('LPPB051NFFN-RC', 'Sullins', 1), ('GRPB051VWVN-RC', 'Sullins', 2)]),
    # SB1 rev B mics: the socket is on the board; the Adafruit breakout is ordered with it
    '1x PPTC051LFBN-RC socket + Adafruit 4162 breakout': ('PPTC051LFBN-RC', 'Sullins', [('Adafruit 4162', 'Adafruit', 1)]),
    '1x PPTC061LFBN-RC socket + Adafruit 6049 breakout': ('PPTC061LFBN-RC', 'Sullins', [('Adafruit 6049', 'Adafruit', 1)]),
    # module symbols: the module is the part, its sockets are ordered with it
    '2x PPTC221LFBN-RC sockets': ('ESP32-S3-DevKitC-1-N8R8', 'Espressif', [('PPTC221LFBN-RC', 'Sullins', 2)]),
    '2x PPTC161LFBN-RC sockets': ('Notecarrier X', 'Blues', [('PPTC161LFBN-RC', 'Sullins', 2)]),
    # NFC module: sockets for its two headers + two snap-in supports (11.13 mm, 3.18 mm holes both ends) at its corner holes
    '1x PPTC041LFBN-RC + 1x PPTC081LFBN-RC sockets + 2x MSPM-7-01 supports': (
        'PN532 NFC Module V3', 'AITRIP',
        [('PPTC041LFBN-RC', 'Sullins', 1), ('PPTC081LFBN-RC', 'Sullins', 1), ('MSPM-7-01', 'Essentra', 2)]),
}

TP_SPEC = '5000 (red) / 5001 (black)'
VALUE_FIX = {'A758KK227M1CAAE014': '220uF 16V polymer',
             'A759EK107M1CAAE018': '100uF 16V polymer'}


def _price(m):
    i = DK.get(m)
    return f"{i['pn']}, ${i['price']} ea" if i else 'not looked up'


def apply(d):
    missing = []
    for p in d.parts:
        if p.sym.power or not p.bom:
            continue
        if p.mpn in COMPOSITE:
            new, mfr, extras = COMPOSITE[p.mpn]
            p.mpn, p.mfr, p.extras = new, mfr, list(extras)
        elif p.mpn in SUBST:
            new, mfr, why = SUBST[p.mpn]
            if why:
                p.note = (p.note + ' | ' if p.note else '') + f'Replaces {p.mpn}: {why}'
            p.mpn, p.mfr = new, mfr
        elif p.mpn == TP_SPEC:
            p.mpn = '5001' if p.value == 'GND' else '5000'
            p.mfr = 'Keystone'
        if p.mpn in VALUE_FIX:
            p.value = VALUE_FIX[p.mpn]
        info = DK.get(p.mpn)
        if not info:
            missing.append((p.ref, p.mpn))
            continue
        if info['ds']:
            p.datasheet = info['ds']
        p.fields['Vendor Part #'] = info['pn']
        p.fields['Price'] = info['price']
        p.fields['Vendor Link'] = info['link']
        if p.extras:
            p.fields['Also order'] = '; '.join(f'{q}x {m} ({_price(m)})' for m, _, q in p.extras)
    if missing:
        print('vendor: no ordering data for', missing)
    return missing
