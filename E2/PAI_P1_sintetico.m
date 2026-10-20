function resultados = PAI_P1_sintetico()
% test tipo paint

%% 1) Camara y proyeccion: mismos parametros de Entrega 2
plate_width=0.360; plate_height=0.130;  % metros
focal_length=8e-3; pixel_size=2e-6;   % metros
W=2880; H=1860;                       % pixeles
fpx=focal_length/pixel_size;
u0=(W+1)/2; v0=(H+1)/2;
D_list=5;                 % 
orientation_deg=30;       % grados (rotacion alrededor del eje Y)
horizontal_displacement=0; % metros

%% 2) Colores; las 
tipos={ 'blanco_negro'; 'naranja_negro'; 'naranja_blanco'; ...
        'amarillo_negro'; 'verde_negro'; 'rojo_negro'; 'rojo_blanco' };
fondosPlaca=uint8([245 245 245; 230 115 20; 230 115 20; ...
                   245 210 35; 45 155 70; 190 35 40; 190 35 40]);
% Carroceria naranjo/variable, gris y oscura
coloresCarroceria=uint8([240 130 30; 105 105 105; 30 30 30]);
nombresCarroceria={'naranja';'gris';'oscura'};
colorFocos=uint8([225 225 215]);
colorExterior=uint8([20 20 20]);

body_width=2.8; body_height=0.9;
focus_width=0.60; focus_height=0.30;
focus_separation=2.0; focus_y=0.20;
entorno_width=0.90; entorno_height=0.42;

salida=fullfile(fileparts(mfilename('fullpath')),'resultados_sinteticos');
if ~isfolder(salida), mkdir(salida); end
filas=cell(0,1);

for id=1:numel(D_list)
    D=D_list(id);
    %% 3) Se proyectan exactamente los cuatro vertices de cada rectangulo
    body=proyectar(body_width,body_height,0,0,D);
    placa=proyectar(plate_width,plate_height,0,0,D);
    entorno=proyectar(entorno_width,entorno_height,0,0,D);
    focoI=proyectar(focus_width,focus_height,-focus_separation/2,focus_y,D);
    focoD=proyectar(focus_width,focus_height, focus_separation/2,focus_y,D);

    mascaraBody=mascara(body);
    mascaraPlaca=mascara(placa);
    mascaraFocos=mascara(focoI)|mascara(focoD);
    mascaraCarro=mascara(entorno)&mascaraBody&~mascaraPlaca&~mascaraFocos;
    if nnz(mascaraPlaca)<30 || nnz(mascaraCarro)<30
        warning('Distancia %.1f m sin regiones suficientes; se omite.',D);
        continue
    end

    %% 4) Repetir para las 7 etiquetas de placa y cada carroceria
    for ip=1:numel(tipos)
        for ic=1:size(coloresCarroceria,1)
            colorPlaca=fondosPlaca(ip,:);
            colorCarro=coloresCarroceria(ic,:);
            I=zeros(H,W,3,'uint8');
            for canal=1:3
                a=repmat(colorExterior(canal),H,W);
                a(mascaraBody)=colorCarro(canal);
                a(mascaraFocos)=colorFocos(canal);
                a(mascaraPlaca)=colorPlaca(canal);
                I(:,:,canal)=a;
            end

            % EXACTAMENTE las mismas dos mascaras para los 3 espacios.
            [T,hP,hC]=PAI_P1_caracteristicas(I,mascaraPlaca,mascaraCarro);
            T=addvars(T,repmat(D,3,1),repmat(string(tipos{ip}),3,1), ...
                repmat(string(nombresCarroceria{ic}),3,1), ...
                'Before',1,'NewVariableNames',{'Distancia_m','TipoPlaca','ColorCarroceria'});
            filas{end+1,1}=T; %#ok<AGROW>

            % Solo una figura de ejemplo, evitando 21 ventanas enormes.
            if id==1 && ip==1 && ic==1
                f=figure('Name','Escena pinhole - region conocida','Color','w','Visible','off','Scrollable','off');
                imshow(I); hold on;
                plot([placa(:,1);placa(1,1)],[placa(:,2);placa(1,2)],'g-','LineWidth',2);
                plot([entorno(:,1);entorno(1,1)], ...
                     [entorno(:,2);entorno(1,2)],'m--','LineWidth',2);
                title(sprintf('Pinhole, D = %g m | verde: placa | magenta: entorno',D));
                exportgraphics(f,fullfile(salida,'escena_ejemplo.png'),'Resolution',150,'Padding',12);
                close(f);
                f=PAI_P1_histogramas(hP,hC,'Escena sintetica: placa blanca, carroceria naranja');
                exportgraphics(f,fullfile(salida,'histogramas_ejemplo.png'),'Resolution',150,'Padding',12);
                close(f);
            end
        end
    end
end

if isempty(filas), error('No se generaron escenarios validos.'); end
resultados=vertcat(filas{:});
writetable(resultados,fullfile(salida,'caracteristicas_RGB_HSV_HSI.csv'));

disp(resultados(:,{'Distancia_m','TipoPlaca','ColorCarroceria','Espacio', ...
    'DistanciaHistogramas','DistanciaClusters'}));
fprintf('\nCSV y figuras guardados en: %s\n',salida);

%% Funciones geometricas locales: Entrega 2
function puntos=proyectar(ancho,alto,xc,yc,D)
    esquinas=[-ancho/2,-alto/2,0; ancho/2,-alto/2,0; ...
               ancho/2, alto/2,0;-ancho/2, alto/2,0];
    esquinas(:,1)=esquinas(:,1)+xc;
    esquinas(:,2)=esquinas(:,2)+yc;
    R=[cosd(orientation_deg),0,sind(orientation_deg); ...
       0,1,0; -sind(orientation_deg),0,cosd(orientation_deg)];
    xyz=esquinas*R.'+[horizontal_displacement,0,D];
    if any(xyz(:,3)<=0), error('Vertices detras de la camara.'); end
    puntos=[u0+fpx*xyz(:,1)./xyz(:,3),v0-fpx*xyz(:,2)./xyz(:,3)];
end
function M=mascara(vertices)
    M=poly2mask(vertices(:,1),vertices(:,2),H,W);
end
end

