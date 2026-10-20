function resultados = PAI_P1_real()
% Problema 1 con fotos y regiones conocidas en el CSV.
base=fileparts(mfilename('fullpath'));
A=readtable(fullfile(base,'datos_reales','anotaciones.csv'), ...
    'Delimiter',',','ReadVariableNames',true,'TextType','string');
salida=fullfile(base,'resultados_reales');
if ~isfolder(salida), mkdir(salida); end
filas=cell(height(A),1);

for j=1:height(A)
    I=imread(fullfile(base,'img',A.archivo(j)));
    [H,W,~]=size(I);
    p=[A.placa_x(j),A.placa_y(j),A.placa_ancho(j),A.placa_alto(j)];
    c=[A.carro_x(j),A.carro_y(j),A.carro_ancho(j),A.carro_alto(j)];
    P=rectangulo(H,W,p); C=rectangulo(H,W,c)&~P;
    [T,hP,hC]=PAI_P1_caracteristicas(I,P,C);
    filas{j}=addvars(T,repmat(A.archivo(j),3,1),repmat(A.tipo(j),3,1), ...
        'Before',1,'NewVariableNames',{'Archivo','TipoPlaca'});

    % Verificar TODAS las anotaciones, en el mismo orden del CSV.
    f=figure('Color','w','Visible','off','Scrollable','off','Position',[80 80 1000 850]);
    tiledlayout(1,1,'Padding','loose'); nexttile;
    imshow(I); hold on;
    rectangle('Position',[p(1:2)-0.5,p(3:4)],'EdgeColor','g','LineWidth',1.5);
    rectangle('Position',[c(1:2)-0.5,c(3:4)],'EdgeColor','m','LineWidth',1.5);
    title({char(A.archivo(j)),'Verde: placa | Magenta: carroceria'},'Interpreter','none','FontSize',10);
    guardar_figura(f,fullfile(salida,sprintf('%02d_regiones.png',j)));
    close(f);
    f=PAI_P1_histogramas(hP,hC,A.archivo(j));
    guardar_figura(f,fullfile(salida,sprintf('%02d_histogramas.png',j)));
    close(f);
end
resultados=vertcat(filas{:});
writetable(resultados,fullfile(salida,'caracteristicas_RGB_HSV_HSI.csv'));
PAI_P1_resumen_resultados(fullfile(salida,'caracteristicas_RGB_HSV_HSI.csv'));
disp(resultados);
fprintf('\nResultados y figuras en: %s\n',salida);
end

function guardar_figura(f,destino)
% Exportar a un PNG nuevo y luego reemplazar la figura anterior.
temporal=[tempname,'.png'];
exportgraphics(f,temporal,'Resolution',150,'Padding',12);
movefile(temporal,destino,'f');
end

function M=rectangulo(H,W,r)
% CSV: indices enteros desde (1,1), ancho y alto como cantidad de pixeles.
if any(~isfinite(r)) || any(r~=round(r)) || any(r<1) || ...
        r(1)+r(3)-1>W || r(2)+r(4)-1>H
    error('Rectangulo fuera de la imagen o coordenadas invalidas en el CSV.');
end
M=false(H,W); M(r(2):r(2)+r(4)-1,r(1):r(1)+r(3)-1)=true;
end
