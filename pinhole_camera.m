
% https://github.com/divagarva/Image-Formation-Simulation-Using-the-Pinhole-Camera-Model-in-MATLAB/blob/main/code.m
% Barrido directo: generar imagenes y comparar solo seis medidas observadas.
clc;
clear;

%% 1. Datos observados
% u: centro horizontal de la caja envolvente; w,h: ancho y alto de esa caja.
% Todas las medidas usan las mismas unidades de imagen; el eje optico es u=0.
observed_input = [];

reference_parameters = [1, 10, 30, 0.5, 0.6, 0.3, 2];
u_reference = NaN;
if isempty(observed_input)
    [observed, u_reference, valid, reference_scene, reference_image] = ...
        project_headlights(reference_parameters);
    assert(valid, 'La escena de referencia debe estar delante de la camara.');
else
    observed = observed_input;
end
assert(isnumeric(observed) && isequal(size(observed), [1, 6]) && ...
    all(isfinite(observed)) && observed(2) > observed(1) && all(observed(3:6) > 0), ...
    'Use [u1 u2 w1 w2 h1 h2], con u1 < u2 y dimensiones positivas.');

%% 2. Rangos del barrido (independientes del ejemplo)
% La separacion entre centros se fija en 1 COMO UNIDAD, no como dato conocido.
% Distancia, desplazamiento, ancho y alto se expresan en esa unidad.
search_grid.focal_length = 0.5:0.25:2;
search_grid.vehicle_distance = 3:0.5:8;
search_grid.orientation_deg = -60:5:60;
search_grid.horizontal_displacement = -1.5:0.25:1.5;
search_grid.headlight_width = 0.20:0.05:0.40;
search_grid.headlight_height = 0.10:0.05:0.20;
tolerance = 0.02;


[results, compatible, best_match] = sweep_parameters(observed, search_grid, tolerance);
fprintf('Escenas validas: %d. Compatibles: %d.\n', height(results), height(compatible));
disp(array2table(observed, 'VariableNames', {'u1','u2','w1','w2','h1','h2'}));
fprintf('Una configuracion de menor error (largos en unidades de separacion):\n');
disp(best_match(:, {'focal_length','vehicle_distance','orientation_deg', ...
    'horizontal_displacement','headlight_width','headlight_height','u_center','relative_error'}));
center_interval = [NaN, NaN];

%% 3. Referencia geometrica y comparacion visual
faces = [1, 2, 3, 4; 5, 6, 7, 8];
figure(1); clf;
if isempty(observed_input)
    patch('Vertices', reference_scene, 'Faces', faces, ...
        'FaceColor', 'y', 'FaceAlpha', 0.5, 'EdgeColor', 'b', 'DisplayName', 'Focos');
    hold on;
    centers = [mean(reference_scene(1:4,:), 1); mean(reference_scene(5:8,:), 1)];
    midpoint = mean(centers, 1);
    plot3(0, 0, 0, 'rx', 'MarkerSize', 10, 'DisplayName', 'Camara');
    plot3(centers(:,1), centers(:,2), centers(:,3), 'b-o', 'DisplayName', 'Centros fisicos');
    plot3(midpoint(1), midpoint(2), midpoint(3), 'ko', 'MarkerFaceColor', 'k', ...
        'DisplayName', 'Punto medio fisico');
    plot3([0, midpoint(1)], [0, midpoint(2)], [0, midpoint(3)], 'k--', ...
        'DisplayName', 'Rayo de referencia');
    hold off;
    xlabel('X'); ylabel('Y'); zlabel('Z');
    title({'Escena de referencia'});
    % Caja compacta: escalas visuales independientes, sin cambiar los datos.
    grid on; axis normal; axis tight; pbaspect([1, 1, 1]); view(3);
    legend('show', 'Location', 'southoutside');
else
    axis off;
    text(0.1, 0.5, 'Datos externos: no se conoce la escena 3D verdadera.');
end

figure(2); clf; hold on;
if isempty(observed_input)
    patch('Vertices', reference_image, 'Faces', faces, ...
        'FaceColor', 'y', 'FaceAlpha', 0.3, 'EdgeColor', 'b', 'DisplayName', 'Imagen observada');
end
% Cajas usadas para medir: no se confunden con centros fisicos proyectados.
for k = 1:2
    u = observed(k); w = observed(k+2); h = observed(k+4);
    plot(u + [-w/2, w/2, w/2, -w/2, -w/2], [-h/2, -h/2, h/2, h/2, -h/2], ...
        'b:', 'HandleVisibility', 'off');
end
plot(observed(1:2), [0, 0], 'bo', 'DisplayName', 'Centros de cajas observadas');
if ~isempty(compatible)
    best_parameters = best_match{1, 1:7};
    [~, ~, ~, ~, best_image] = project_headlights(best_parameters);
    patch('Vertices', best_image, 'Faces', faces, 'FaceColor', 'none', ...
        'EdgeColor', [0, 0.6, 0], 'LineStyle', '--', 'DisplayName', 'Un candidato compatible');
    xline(best_match.u_center, 'g--', 'DisplayName', 'Centro de ese candidato');
end
if isfinite(u_reference)
    xline(u_reference, 'k:', 'LineWidth', 1.5, 'DisplayName', 'Centro verdadero (referencia)');
end
hold off;
xlabel('u'); ylabel('v'); title('Imagen y medidas observadas');
grid on; axis equal; legend('show');

%% 4. Datos para descubrir relaciones
% alpha usa el centro conocido de cada escena simulada. 
shown = unique(round(linspace(1, height(results), min(6000, height(results)))));
figure(3); clf;
subplot(1,2,1);
scatter(results.height_ratio(shown), results.alpha(shown), 8, ...
    results.orientation_deg(shown), 'filled');
xlabel('h1 / h2'); ylabel('alpha'); title('h1/h2 vs. alpha');
grid on; colorbar;
subplot(1,2,2);
scatter(results.width_ratio(shown), results.alpha(shown), 8, ...
    results.horizontal_displacement(shown), 'filled');
xlabel('w1 / w2'); ylabel('alpha'); title('desplazamiento / separacion vs. alpha');
grid on; colorbar;

function [results, compatible, best_match] = sweep_parameters(observed, ranges, tolerance)
    [f, d, angle, x, w, h] = ndgrid(ranges.focal_length, ranges.vehicle_distance, ...
        ranges.orientation_deg, ranges.horizontal_displacement, ...
        ranges.headlight_width, ranges.headlight_height);
    parameters = [f(:), d(:), angle(:), x(:), w(:), h(:), ones(numel(f),1)];
    [predicted, center_u, valid] = project_headlights(parameters);
    parameters = parameters(valid,:);
    predicted = predicted(valid,:);
    center_u = center_u(valid);
    assert(~isempty(parameters), 'La malla no contiene escenas validas.');
    % Error de posiciones relativo a la separacion observada; error de cada dimension relativo a esa dimension observada
    separation = observed(2) - observed(1);
    scales = [separation, separation, observed(3:6)];
    relative_error = max(abs(predicted - observed) ./ scales, [], 2);
    height_ratio = predicted(:,5) ./ predicted(:,6);
    width_ratio = predicted(:,3) ./ predicted(:,4);
    alpha = (center_u - predicted(:,1)) ./ (predicted(:,2) - predicted(:,1));
    results = array2table([parameters, predicted, center_u, height_ratio, width_ratio, alpha, relative_error], ...
        'VariableNames', {'focal_length','vehicle_distance','orientation_deg', ...
        'horizontal_displacement','headlight_width','headlight_height','headlight_separation', ...
        'u1','u2','w1','w2','h1','h2','u_center','height_ratio','width_ratio','alpha','relative_error'});
    results.compatible = relative_error <= tolerance;
    compatible = sortrows(results(results.compatible,:), 'relative_error');
    [~, best_index] = min(relative_error);
    best_match = results(best_index,:);
end

function [observations, center_u, valid, scene_points, image_plane] = project_headlights(p)
    % Proyeccion directa de los 8 vertices; una fila de p por escena.
    % Columnas: focal, distancia, angulo, desplazamiento, ancho, alto, separacion.
    n = size(p,1);
    observations = zeros(n,6);
    valid = all(isfinite(p),2) & p(:,1)>0 & p(:,2)>0 & p(:,5)>0 & p(:,6)>0 & p(:,7)>p(:,5);
    corners = [-0.5,-0.5; 0.5,-0.5; 0.5,0.5; -0.5,0.5];
    scene_points = []; image_plane = [];
    if nargout > 3
        assert(n == 1, 'Los vertices para dibujar se solicitan para una sola escena.');
        scene_points = zeros(8,3); image_plane = zeros(8,2);
    end
    for light = 1:2
        u = zeros(n,4); v = zeros(n,4);
        for j = 1:4
            local_x = (light - 1.5) * p(:,7) + corners(j,1) * p(:,5);
            X = local_x .* cosd(p(:,3)) + p(:,4);
            Y = corners(j,2) * p(:,6);
            Z = p(:,2) - local_x .* sind(p(:,3));
            valid = valid & Z > 0;
            u(:,j) = p(:,1) .* X ./ Z;
            v(:,j) = p(:,1) .* Y ./ Z;
            if nargout > 3
                index = (light-1)*4 + j;
                scene_points(index,:) = [X, Y, Z];
                image_plane(index,:) = [u(:,j), v(:,j)];
            end
        end
        observations(:,light) = (min(u,[],2) + max(u,[],2)) / 2;
        observations(:,light+2) = max(u,[],2) - min(u,[],2);
        observations(:,light+4) = max(v,[],2) - min(v,[],2);
    end

    swapped = observations(:,1) > observations(:,2);
    observations(swapped,:) = observations(swapped,[2,1,4,3,6,5]);
    valid = valid & all(isfinite(observations),2) & ...
        observations(:,2) > observations(:,1) & all(observations(:,3:6)>0,2);
    % Proyeccion del punto medio fisico == referencia 
    center_u = p(:,1) .* p(:,4) ./ p(:,2);
end
