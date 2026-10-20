function [resumen, porImagen, porTipo] = PAI_P1_resumen_resultados(archivoCSV)
% Dos figuras comparativas y cuatro tablas a partir del CSV ya calculado.
base = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(archivoCSV)
    archivoCSV = fullfile(base,'resultados_reales','caracteristicas_RGB_HSV_HSI.csv');
end
if ~isfile(archivoCSV)
    error('No se encontro el CSV. Pase su ruta a PAI_P1_resumen_resultados(ruta).');
end
T = readtable(archivoCSV,'Delimiter',',','ReadVariableNames',true,'TextType','string');
T.Archivo = string(T.Archivo);
T.TipoPlaca = string(T.TipoPlaca);
T.Espacio = upper(strtrim(string(T.Espacio)));

espacios = ["RGB","HSV","HSI"];
archivos = unique(T.Archivo,'stable');
n = numel(archivos);
campos = ["DistanciaHistogramas","DistanciaClusters","DiferenciaMedias"];
for k = 1:numel(campos)
    if ~ismember(campos(k),string(T.Properties.VariableNames))
        error('El CSV no contiene la columna %s.',campos(k));
    end
end

% Cada foto debe tener exactamente un registro por espacio.
% M(foto,espacio,metrica): mantiene emparejadas las tres representaciones.
M = nan(n,3,3);
tipos = strings(n,1);
for i = 1:n
    idxFoto = T.Archivo==archivos(i);
    tiposFoto = unique(T.TipoPlaca(idxFoto));
    if numel(tiposFoto) ~= 1
        error('Hay tipos de placa inconsistentes para %s.',archivos(i));
    end
    tipos(i) = tiposFoto;
    for e = 1:3
        idx = find(idxFoto & T.Espacio==espacios(e));
        if numel(idx) ~= 1
            error('Debe haber una fila de %s para %s.',espacios(e),archivos(i));
        end
        for k = 1:3
            M(i,e,k) = T{idx,char(campos(k))};
        end
    end
end

salida = fullfile(base,'resumen_informe');
if ~isfolder(salida), mkdir(salida); end

%% 2. Tabla compacta: mediana e intervalo intercuartil (25%-75%)
H = resumenTres(M(:,:,1));
C = resumenTres(M(:,:,2));
D = resumenTres(M(:,:,3));
resumen = table(espacios(:),repmat(n,3,1), ...
    H(:,1),H(:,2),H(:,3),C(:,1),C(:,2),C(:,3),D(:,1), ...
    'VariableNames',{'Espacio','NImagenes','HistMediana','HistP25','HistP75', ...
                     'ClustersMediana','ClustersP25','ClustersP75','MediasMediana'});
writetable(resumen,fullfile(salida,'tabla_resumen_espacios.csv'));

%% 3. Tabla pareada: una fila por imagen (9 filas para el CSV actual)
porImagen = table(archivos,tipos, ...
    M(:,1,1),M(:,2,1),M(:,3,1), ...
    M(:,1,2),M(:,2,2),M(:,3,2), ...
    M(:,1,3),M(:,2,3),M(:,3,3), ...
    'VariableNames',{'Archivo','TipoPlaca', ...
    'Hist_RGB','Hist_HSV','Hist_HSI', ...
    'Clusters_RGB','Clusters_HSV','Clusters_HSI', ...
    'Medias_RGB','Medias_HSV','Medias_HSI'});
writetable(porImagen,fullfile(salida,'tabla_por_imagen.csv'));

%% 4. Tabla por tipo de patente; N=1 significa un caso, no una tendencia
categorias = unique(tipos,'stable');
filasTipo = strings(0,1); filasEspacio = strings(0,1);
conteos = zeros(0,1); histMed = zeros(0,1); clusMed = zeros(0,1);
for t = 1:numel(categorias)
    idx = tipos==categorias(t);
    for e = 1:3
        filasTipo(end+1,1) = categorias(t);
        filasEspacio(end+1,1) = espacios(e);
        conteos(end+1,1) = nnz(idx);
        histMed(end+1,1) = medianaValida(M(idx,e,1));
        clusMed(end+1,1) = medianaValida(M(idx,e,2));
    end
end
porTipo = table(filasTipo,filasEspacio,conteos,histMed,clusMed, ...
    'VariableNames',{'TipoPlaca','Espacio','NImagenes','HistMediana','ClustersMediana'});
writetable(porTipo,fullfile(salida,'tabla_por_tipo.csv'));

%% 5. Tabla exhaustiva de las caracteristicas realmente disponibles
columnas = string(T.Properties.VariableNames);
columnas = setdiff(columnas,["Archivo","TipoPlaca","Espacio"],'stable');
listaEsp = strings(0,1); listaMet = strings(0,1);
listaN = zeros(0,1); listaMed = zeros(0,1); listaP25 = zeros(0,1); listaP75 = zeros(0,1);
for e = 1:3
    idx = T.Espacio==espacios(e);
    for j = 1:numel(columnas)
        v = T{idx,char(columnas(j))};
        if ~isnumeric(v), continue; end
        v = v(isfinite(v));
        if isempty(v), continue; end  % Ej.: tono RGB / entropia HSV no aplican
        listaEsp(end+1,1) = espacios(e);
        listaMet(end+1,1) = columnas(j);
        listaN(end+1,1) = numel(v);
        listaMed(end+1,1) = median(v);
        listaP25(end+1,1) = percentilLineal(v,25);
        listaP75(end+1,1) = percentilLineal(v,75);
    end
end
todas = table(listaEsp,listaMet,listaN,listaMed,listaP25,listaP75, ...
    'VariableNames',{'Espacio','Metrica','NValido','Mediana','P25','P75'});
writetable(todas,fullfile(salida,'tabla_todas_las_metricas.csv'));

%% 6. Figura principal: distribucion entre las imagenes
colores = lines(3);
f = figure('Color','w','Visible','off','Scrollable','off','Position',[80 80 1200 560]);
layout=tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
etiquetas = {'Histogramas','Vecindarios (clusters)'};
for k = 1:2
    nexttile; hold on;
    for e = 1:3
        v = M(:,e,k); v = v(isfinite(v));
        if isempty(v), continue; end
        q1 = percentilLineal(v,25); q3 = percentilLineal(v,75);
        md = median(v);
        % Puntos: cada foto. Barra gruesa: P25-P75. Raya: mediana.
        despl = linspace(-0.12,0.12,numel(v))';
        hIQR=plot([e e],[q1 q3],'-','LineWidth',8,'Color',colores(e,:));
        hMediana=plot(e+[-0.22,0.22],[md md],'k-','LineWidth',2);
        hPuntos=scatter(e+despl,v,28,colores(e,:),'filled','MarkerEdgeColor','w');
        if k==1 && e==1, claves=[hPuntos,hIQR,hMediana]; end
    end
    xlim([0.5 3.5]); ylim([0 1.05]);
    set(gca,'XTick',1:3,'XTickLabel',cellstr(espacios));
    ylabel('Distancia Jensen-Shannon (0 a 1)'); title(etiquetas{k}); grid on;
end
title(layout,sprintf('Comparacion global - %d fotografias',n));
lgd=legend(claves,{'Cada fotografia','Percentiles 25-75','Mediana'},'Orientation','horizontal');
lgd.Layout.Tile='south';
guardar_figura(f,fullfile(salida,'01_comparacion_global.png'));
guardar_figura(f,fullfile(salida,'01_comparacion_global.pdf'));
close(f);

%% 7. Figura pareada: como cambia cada metrica en cada imagen
f = figure('Color','w','Visible','off','Scrollable','off','Position',[80 80 1200 1000]);
layout=tiledlayout(3,1,'TileSpacing','loose','Padding','loose');
titulos = {'Histogramas (Jensen-Shannon)','Vecindarios (Jensen-Shannon)', ...
           'Distancia de medias (coordenadas de cada espacio)'};
for k = 1:3
    nexttile; hold on;
    for e = 1:3
        plot(1:n,M(:,e,k),'-o','Color',colores(e,:), ...
            'LineWidth',1.5,'MarkerSize',5,'DisplayName',char(espacios(e)));
    end
    xlim([0.6 n+0.4]);
    if k < 3, ylim([0 1.05]); end
    set(gca,'XTick',1:n,'XTickLabel',cellstr(archivos),'TickLabelInterpreter','none');
    ylabel('Distancia'); title(titulos{k}); grid on;
    if k==1, legend('Location','best'); end
    if k==3, xlabel('Fotografia (mismo orden en los tres graficos)'); end
end
title(layout,'Comparacion por fotografia - mismas regiones en RGB, HSV y HSI');
guardar_figura(f,fullfile(salida,'02_resultados_por_imagen.png'));
guardar_figura(f,fullfile(salida,'02_resultados_por_imagen.pdf'));
close(f);

fprintf('\nSe analizaron %d imagenes, %d registros.\n',n,height(T));
fprintf('Resultados guardados en: %s\n',salida);
fprintf('Atencion: la distancia de medias NO tiene una escala equivalente entre RGB, HSV y HSI.\n');
fprintf('Los resumenes por tipo con N=1 son descriptivos, no permiten generalizar.\n');
disp(resumen);
end

%% Funciones auxiliares sin Statistics Toolbox
function guardar_figura(f,destino)
    [~,~,extension]=fileparts(destino);
    temporal=[tempname,extension];
    if strcmpi(extension,'.pdf')
        exportgraphics(f,temporal,'ContentType','vector','Padding',12);
    else
        exportgraphics(f,temporal,'Resolution',300,'Padding',12);
    end
    movefile(temporal,destino,'f');
end

function R = resumenTres(M)
    R = nan(size(M,2),3);  % mediana, percentil 25 y percentil 75
    for c = 1:size(M,2)
        v = M(:,c); v = v(isfinite(v));
        if ~isempty(v)
            R(c,:) = [median(v),percentilLineal(v,25),percentilLineal(v,75)];
        end
    end
end

function m = medianaValida(v)
    v = v(isfinite(v));
    if isempty(v), m = NaN; else, m = median(v); end
end

function p = percentilLineal(v,porcentaje)
    v = sort(v(isfinite(v)));
    if isempty(v), p = NaN; return; end
    t = 1+(numel(v)-1)*porcentaje/100;
    a = floor(t); b = ceil(t);
    p = v(a)+(t-a)*(v(b)-v(a));
end
