README ECM1 files

#ECM1:
Numb= # of 1°x1° square
Lon = Longitude [°]
Lat = Latitude [°]
Hcc = Crystalline crust (No sediment) [km]
Sed = Total sediment thickness (Sediment Model) [km]
Hc  = Total Crustal Thickness [km]
Type= Crustal Type (SOCE: Normal Ocean;MORB: Mid-Ocean Ridge;LIPS: Oceanic Large Igneous Provinces;
      COMA: Continental Margin;EXCT: Extended Crust;SHLD: Shield;ORON: Orogen;PLAT: Platform;BASN: Basin;IARC: Island Arc;COAR: Continental Arc)
DLy#= Depth of Layer# (It takes into account the sediment layer, so DLy3 should be the same value of Hc) [km]
TLy#= Thickness of Layer# (Ratio for Ocean= 1:0.1, 2:0.2, 3:0.7; Ratio for Continent= 1:0.33, 2:0.33, 3:0.34) [km]
Vp# = P-wave velocity for Ly# [km/s]
Vs# = S-wave velocity for Ly# [km/s]
Vpn = P-wave velocity of the top of the mantle [km/s]
Vsn = S-wave velocity of the top of the mantle [km/s]
Rho#= Density for Ly# following eq. 1 from Brocher, 2005. (Using P-wave velocity). [g/cm3]

#Ice&Water_ECM:
Numb= # of 1°x1° square
Lon = Longitude [°]
Lat = Latitude [°]
Water/Ice Thickness [m]
Vp_ Water/Ice = P-wave velocity [km/s]
Vs_ Water/Ice = S-wave velocity [km/s]
Rho_ Water/Ice = Density [g/cm3]
(Elastic properties following Bass, 1995; Thicknesses modified from ETOPO2022)

#Sed_ECM:
Numb= # of 1°x1° square
Lon = Longitude [°]
Lat = Latitude [°]
Sed = Total sediment thickness (Sediment Model) [m]
SedT# = Thickness of Layer# [m]
SedVp# = P-wave velocity for Ly# [km/s]
SedVs# = S-wave velocity for Ly# [km/s]
SedRho#= Density for Ly# following eq. 1 from Brocher, 2005. (Using P-wave velocity). [g/cm3]

#Hcc_ECM1:
Numb= # of 1°x1° square
Lon = Longitude [°]
Lat = Latitude [°]
Hcc = Crystalline crust (No sediment) [km]

#Hc_ECM1:
Numb= # of 1°x1° square
Lon = Longitude [°]
Lat = Latitude [°]
Hc = Total Crustal Thickness [km]
