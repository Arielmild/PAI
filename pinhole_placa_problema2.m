% Problema 2: placa proyectada a 2, 5 y 10 m.
% Adaptado de pinhole_camera_sin_sliders.m. Largos en metros, imagen en pixeles.
% B-splines: https://www.mathworks.com/help/curvefit/spmak.html
clc;
clear;

%% 1. Parametros
plate_width = 360e-3;
plate_height = 130e-3;
focal_length = 8e-3;
pixel_size = 2e-6;
image_width = 2880;
image_height = 1860;
focal_pixels = focal_length / pixel_size;
u0 = (image_width + 1) / 2;  % Centros de pixeles en 1,...,N.
v0 = (image_height + 1) / 2;
D_list = [2, 5, 10];

% El mismo caso individual y los mismos barridos se repiten para cada D.
orientation_deg = 30;
horizontal_displacement = 1;
orientation_list = [-45, 0, 45];
displacement_list = [-2, 0, 2];
theta_list = 0:5:85; % Barrido de asimetria con desplazamiento X=0.

% Las tres figuras combinadas se exportan a PDF vectorial y PNG a 300 dpi.
output_folder = fullfile(fileparts(mfilename('fullpath')), 'figuras_problema2', 'conjuntas');

% Camara en el origen; centro de la placa a la misma altura (Y=0).
% Solo giro sobre Y: se omiten inclinacion vertical, roll y distorsion.
plate_points = [-plate_width/2, -plate_height/2, 0;
                 plate_width/2, -plate_height/2, 0;
                 plate_width/2,  plate_height/2, 0;
                -plate_width/2,  plate_height/2, 0];
has_splines = exist('spmak','file') == 2 && exist('fnval','file') == 2;
if ~has_splines
    warning('Placa:MissingToolbox', 'Falta Curve Fitting Toolbox: se dibujan solo poligonos.');
end

%% 2. Calcular una vez todos los resultados
nD = numel(D_list);
nCases = numel(orientation_list) * numel(displacement_list);
reference_images = cell(nD,1);
projections = cell(nD,nCases);
reference_data = zeros(nD,9);
sweep_data = zeros(nD*nCases,9);
reference_visibility = strings(nD,1);
sweep_visibility = strings(nD*nCases,1);
asymmetry_percent = zeros(numel(theta_list),nD);
asymmetry_left = zeros(size(asymmetry_percent));
asymmetry_right = zeros(size(asymmetry_percent));
extents = zeros(nD,2);

for j = 1:nD
    D = D_list(j);
    [~, projected] = project_plate(plate_points, orientation_deg, horizontal_displacement, D, focal_pixels, u0, v0);
    reference_images{j} = projected;
    center_u = u0 + focal_pixels * horizontal_displacement / D;
    reference_data(j,:) = [D, orientation_deg, horizontal_displacement, center_u, measure_plate(projected)];
    reference_visibility(j) = image_status(projected, image_width, image_height);
    k = 0;
    for displacement = displacement_list
        for angle = orientation_list
            k = k + 1;
            row = (j-1)*nCases + k;
            [~, projected] = project_plate(plate_points, angle, displacement, D, focal_pixels, u0, v0);
            projections{j,k} = projected;
            center_u = u0 + focal_pixels * displacement / D;
            sweep_data(row,:) = [D, angle, displacement, center_u, measure_plate(projected)];
            sweep_visibility(row) = image_status(projected, image_width, image_height);
            extents(j,:) = max(extents(j,:), max(abs(projected-[center_u,v0]),[],1));
        end
    end
    for i = 1:numel(theta_list)
        [~, projected] = project_plate(plate_points, theta_list(i), 0, D, focal_pixels, u0, v0);
        m = measure_plate(projected);
        asymmetry_left(i,j) = m(2);
        asymmetry_right(i,j) = m(3);
        asymmetry_percent(i,j) = m(5);
    end
end
names = {'distance_m','orientation_deg','displacement_m','center_u_px','width_px', ...
    'left_height_px','right_height_px','area_px2','asymmetry_percent'};
reference_results = array2table(reference_data, 'VariableNames', names);
reference_results.visibility = reference_visibility;
results = array2table(sweep_data, 'VariableNames', names);
results.visibility = sweep_visibility;
asymmetry_results = table(repelem(D_list(:),numel(theta_list)), repmat(theta_list(:),nD,1), ...
    asymmetry_left(:), asymmetry_right(:), asymmetry_percent(:), 'VariableNames', ...
    {'distance_m','orientation_deg','left_height_px','right_height_px','asymmetry_percent'});

%% 3. Consola: caso individual, barrido y asimetria para CADA distancia
fprintf('Focal: %.0f px. Punto principal: (%.1f, %.1f) px.\n', focal_pixels, u0, v0);
fprintf('Medidas del contorno completo, antes de recortar al sensor.\n');
fprintf('Asimetria (%%) = 100*(h_der-h_izq)/h_izq.\n');
for j = 1:nD
    fprintf('\nDISTANCIA D = %g m\n',D_list(j));
    fprintf('Caso individual:\n'); disp(reference_results(j,:));
    fprintf('Barrido de orientaciones y desplazamientos:\n');
    disp(results((j-1)*nCases+(1:nCases),:));
    fprintf('Barrido de asimetria (X = 0 m):\n');
    disp(asymmetry_results((j-1)*numel(theta_list)+(1:numel(theta_list)),:));
end

%% 4. Figuras combinadas para las tres distancias
colors = lines(nD);
asymmetry_limits = [min(0,min(asymmetry_percent(:))), max(1,1.05*max(asymmetry_percent(:)))];

new_figure(4,'Casos individuales - tres distancias',[1100,1000]);
tiledlayout(nD,2,'TileSpacing','compact','Padding','compact');
for j = 1:nD
    draw_reference(reference_images{j}, D_list(j), orientation_deg, horizontal_displacement, ...
        focal_pixels, u0, v0, image_width, image_height, has_splines, reference_visibility(j));
end
export_plot(output_folder,'casos_tres_distancias');

new_figure(5,'Barridos superpuestos - tres distancias',[1100,650]);
layout = tiledlayout(numel(displacement_list),numel(orientation_list), ...
    'TileSpacing','compact','Padding','compact');
title(layout,{'Contornos completos recentrados: incluye proyecciones fuera del sensor', ...
    'Misma escala en pixeles para las tres distancias'});
limits = max(extents,[],1);
limits = limits + max(0.15*limits,[5,5]);
for k = 1:nCases
    nexttile;
    for j = 1:nD
        row = (j-1)*nCases+k;
        draw_contours(projections{j,k}-[results.center_u_px(row),v0],has_splines,colors(j,:),[0.1,0.1,0.1]);
    end
    title(sprintf('Giro %g grados; X = %g m',results.orientation_deg(k),results.displacement_m(k)));
    format_detail(limits);
end
% Claves explicitas para no repetir las etiquetas de cada contorno.
hold on; keys = gobjects(nD+double(has_splines),1);
for j = 1:nD
    keys(j) = plot(NaN,NaN,'-','Color',colors(j,:),'LineWidth',1.5,'DisplayName',sprintf('D = %g m',D_list(j)));
end
if has_splines
    keys(end) = plot(NaN,NaN,'k--','DisplayName','B-spline cuadratica uniforme');
end
lgd = legend(keys,'Location','southoutside','Orientation','horizontal'); lgd.Layout.Tile = 'south';
hold off;
export_plot(output_folder,'barridos_tres_distancias');

new_figure(6,'Asimetria - tres distancias',[800,480]); hold on;
for j = 1:nD
    plot(theta_list,asymmetry_percent(:,j),'-o','Color',colors(j,:),'DisplayName',sprintf('D = %g m',D_list(j)));
end
hold off; format_asymmetry(asymmetry_limits);
title('Asimetria de alturas segun orientacion y distancia | X = 0 m');
legend('show','Location','northwest');
export_plot(output_folder,'asimetria_tres_distancias');
fprintf('\nFiguras PDF y PNG guardadas en: %s\n',output_folder);

%% Funciones auxiliares
function [scene_points,image_plane] = project_plate(points,angle,displacement,distance,fpx,u0,v0)
    rotation = [cosd(angle),0,sind(angle); 0,1,0; -sind(angle),0,cosd(angle)];
    scene_points = points*rotation.'+[displacement,0,distance];
    assert(all(scene_points(:,3)>0),'Todos los vertices deben estar delante de la camara.');
    assert(abs(angle)<90,'Utiliza un giro entre -90 y 90 grados, sin incluir los extremos.');
    image_plane = [u0+fpx*scene_points(:,1)./scene_points(:,3), v0-fpx*scene_points(:,2)./scene_points(:,3)];
end

function m = measure_plate(p)
    w = max(p(:,1))-min(p(:,1));
    lh = abs(p(4,2)-p(1,2)); rh = abs(p(3,2)-p(2,2));
    a = polyarea(p(:,1),p(:,2));
    if w < 1e-8, w = 0; a = 0; end % Vista exactamente de canto.
    m = [w,lh,rh,a,100*(rh-lh)/lh];
end

function status = image_status(p,W,H)
    if all(p(:,1)>=0.5 & p(:,1)<=W+0.5 & p(:,2)>=0.5 & p(:,2)<=H+0.5)
        status = "Dentro del sensor";
    elseif max(p(:,1))<0.5 || min(p(:,1))>W+0.5 || max(p(:,2))<0.5 || min(p(:,2))>H+0.5
        status = "Fuera del sensor";
    else
        status = "Parcialmente visible";
    end
    if max(p(:,1))-min(p(:,1))<1e-8, status = status + " / de canto"; end
end

function draw_contours(vertices,has_splines,polygon_color,spline_color)
    % Una vista de canto no tiene interior: se dibuja como linea.
    if max(vertices(:,1))-min(vertices(:,1)) < 1e-8
        plot(vertices([1:4,1],1),vertices([1:4,1],2),'-','Color',polygon_color, ...
            'LineWidth',1.5,'DisplayName','Poligono (de canto)');
    else
        polygon = polyshape(vertices(:,1),vertices(:,2));
        plot(polygon,'FaceColor',polygon_color,'FaceAlpha',0.07,'EdgeColor',polygon_color, ...
            'LineWidth',1.5,'DisplayName','Poligono');
    end
    hold on;
    if has_splines
        % Duplicar controles conserva las esquinas sin repetir los nudos.
        controls = vertices([1,1,2,2,3,3,4,4,1,1],:).';
        plate_spline = spmak(0:12,controls); % Orden 3 (grado 2); nudos uniformes.
        curve = fnval(plate_spline,linspace(2,10,401));
        plot(curve(1,:),curve(2,:),'--','Color',spline_color,'LineWidth',1.1, ...
            'DisplayName','B-spline cuadratica uniforme');
    end
    axis equal; grid on; set(gca,'YDir','reverse','FontSize',10);
    xlabel('u (px)'); ylabel('v (px)');
end

function draw_reference(p,D,angle,displacement,fpx,u0,v0,W,H,has_splines,status)
    nexttile;
    draw_contours(p,has_splines,[0,0,1],[1,0,0]);
    plot(u0,v0,'kx','DisplayName','Punto principal');
    plot(u0+fpx*displacement/D,v0,'mo','DisplayName','Centro proyectado');
    xlim([0.5,W+0.5]); ylim([0.5,H+0.5]);
    title(sprintf('D = %g m | Imagen completa\n%s',D,status)); hold off;
    nexttile;
    draw_contours(p,has_splines,[0,0,1],[1,0,0]);
    plot(u0+fpx*displacement/D,v0,'mo','DisplayName','Centro proyectado');
    xlim([min(p(:,1))-15,max(p(:,1))+15]); ylim([min(p(:,2))-10,max(p(:,2))+10]);
    title(sprintf('D = %g m | Contorno completo (ampliado)\nGiro %g grados; X = %g m',D,angle,displacement));
    legend('show','Location','southoutside','FontSize',9); hold off;
end

function format_detail(limits)
    xlim([-limits(1),limits(1)]); ylim([-limits(2),limits(2)]);
    xlabel('u - u_c (px)'); ylabel('v - v_0 (px)'); hold off;
end

function format_asymmetry(limits)
    xlabel('\theta (grados)'); ylabel('Asimetria de alturas (%)'); ylim(limits);
    grid on; set(gca,'FontSize',11);
end

function new_figure(number,name,dimensions)
    figure(number); clf;
    set(gcf,'Name',name,'Color','w','Position',[80,80,dimensions]);
end

function export_plot(folder,name)
    if ~isfolder(folder), mkdir(folder); end
    exportgraphics(gcf,fullfile(folder,[name,'.pdf']),'ContentType','vector');
    exportgraphics(gcf,fullfile(folder,[name,'.png']),'Resolution',300);
end
