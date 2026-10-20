function f = PAI_P1_histogramas(hP,hC,nombre)
% Los histogramas se calculan una sola vez en PAI_P1_caracteristicas.
f=figure('Color','w','Visible','off','Scrollable','off','Position',[80 80 1200 950]);
layout=tiledlayout(3,3,'TileSpacing','loose','Padding','loose');
canales={'R','G','B'; 'H','S','V'; 'H','S','I'};
espacios={'RGB','HSV','HSI'};
centros=((1:16)-0.5)/16;
for e=1:3
    for c=1:3
        nexttile;
        plot(centros,hP(:,c,e),'-','LineWidth',1.3); hold on;
        plot(centros,hC(:,c,e),'--','LineWidth',1.3);
        if all(isnan(hP(:,c,e))) || all(isnan(hC(:,c,e)))
            text(0.02,0.65,'H no disponible en alguna region','Units','normalized','FontSize',8);
        end
        title([espacios{e},' - ',canales{e,c}]);
        xlim([0 1]); ylim([0 1.05]); grid on;
        xlabel('Valor normalizado'); ylabel('Frecuencia relativa');
        if e==1 && c==1, legend('Placa','Carroceria','Location','best'); end
    end
end
title(layout,nombre,'Interpreter','none','FontSize',11);
end
