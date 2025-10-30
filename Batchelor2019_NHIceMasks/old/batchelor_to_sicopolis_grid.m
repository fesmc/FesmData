% Transform Batchelor to SICOPOLIS Grid

%Read SICOPOLIS Grid
x_sic = ncread('G:\PIK\Batchelor_etal_2018\SICOPOLIS/ice_NH-40KM.nc','xi');
y_sic = ncread('G:\PIK\Batchelor_etal_2018\SICOPOLIS/ice_NH-40KM.nc','eta');
lat = ncread('G:\PIK\Batchelor_etal_2018\SICOPOLIS/ice_NH-40KM.nc','phi');
lon = ncread('G:\PIK\Batchelor_etal_2018\SICOPOLIS/ice_NH-40KM.nc','lambda');

%Read BAtchelor Data
S = shaperead('MIS4_best_estimate.shp');



%% Transform (Lat,Lon)-->(x,y) Coordinates in Lambert Azimuthal Projection
%R = 6.371*10^6; % Earth's Radius in m
R = 6.67*10^6 %Value for Earth Radius in SICOPOLIS, R = max(x_sic)/cos(min(min(lat))*pi/180); 
for i=1:length(x_sic) %313
    for j=1:length(y_sic) %313
    latt = lat(i,j)*pi/180; %transform to Rad
    lonn = lon(i,j)*pi/180; %transform to Rad
    
    x(i,j) = R*cos(latt)*sin(lonn);
    y(i,j) = -R*cos(latt)*cos(lonn);
    
end; end

%% Transform the Shapefile into a Matrix (I need to define the x and y coordinates I want it to be)
for i=1:length(x_sic) %313
i
for j=1:length(y_sic) %313
xq = x(i,j);
yq = y(i,j);
aux(i,j) = inpolygon(xq,yq,S.X,S.Y); %aux is a logical Matrix
end; end;
%transform to Double precission Matrix
for i=1:length(x_sic) %313
for j=1:length(y_sic) %313
    if aux(i,j)==true aux1(i,j)=1;
    else aux1(i,j)=0;
    end
end; end
ice_mask = aux1;

save ice_mask_SICOPOLISgrid ice_mask x_sic y_sic


h = figure('Name','MIS4 Ice-Mask SICOPOLISgrid','NumberTitle','off','units','normalized','outerposition',[0 0 1 1]); %maximise
contourf(x_sic,y_sic,ice_mask',[0,1])
hold on; grid
axis([min(x_sic) max(x_sic) min(y_sic) max(y_sic)])
colorbar
caxis([0 1])
title('MIS4 Ice-Sheet Extension SICOPOLIS Grid')
xlabel('x')
ylabel('y')
%set(gca,'FontSize',18)
print(h,'ice_mask_SICOPOLISgrid_MIS4','-dtiff')


%Read the Land-Sea Mask from SICOPOLIS:
mask = ncread('G:\PIK\Batchelor_etal_2018\SICOPOLIS/ice_NH-40KM.nc','maske');
h1 = figure('Name','MIS4 Ice-Mask SICOPOLISgrid + Map','NumberTitle','off','units','normalized','outerposition',[0 0 1 1]); %maximise
contourf(x_sic,y_sic,ice_mask',[0,1])
hold on; grid
contour(x_sic,y_sic,mask',[1,2],'-k','LineWidth',2)
axis([min(x_sic) max(x_sic) min(y_sic) max(y_sic)])
colorbar
caxis([0 1])
title('MIS4 Ice-Sheet Extension SICOPOLIS Grid')
xlabel('x')
ylabel('y')
%set(gca,'FontSize',18)
print(h1,'ice_mask_SICOPOLISgrid_MIS4_map_final','-dtiff')


%close all
