function [T,hP,hC] = PAI_P1_caracteristicas(I,P,C)
% Problema 1: tres tecnicas de color sobre dos regiones conocidas
% P: placa; C: muestra de carroceria
if size(I,3)~=3 || ~isequal(size(P),size(I(:,:,1)),size(C))
    error('La imagen debe ser RGB y las mascaras deben tener su mismo tamano.');
end
P=logical(P); C=logical(C)&~P;
if ~any(P(:)) || ~any(C(:)), error('Las dos regiones deben tener pixeles.'); end

% Recortar el area de trabajo sin cambiar las regiones anotadas
[y,x]=find(P|C);
ys=max(1,min(y)-1):min(size(I,1),max(y)+1);
xs=max(1,min(x)-1):min(size(I,2),max(x)+1);
I=im2double(I(ys,xs,:)); P=P(ys,xs); C=C(ys,xs);
espacios={I,rgb2hsv(I),rgb_a_hsi(I)};
nombres=["RGB";"HSV";"HSI"];
hP=nan(16,3,3); hC=hP;
medidas=nan(3,10);

for e=1:3
    X=espacios{e}; pix=reshape(X,[],3);
    A=pix(P(:),:); B=pix(C(:),:);
    mA=mean(A,1); mB=mean(B,1);
    dispersion=[NaN NaN];
    if e>1
        % H es circular; se excluyen blancos, grises y negros (S<=0.05 testeando)
        [mA(1),dispersion(1)]=tono(A);
        [mB(1),dispersion(2)]=tono(B);
    end
    diferenciaMedia=distancia_color(mA,mB,e);

    % 1. Histogramas: 16 intervalos iguales por canal.
    js=nan(1,3);
    for c=1:3
        a=A(:,c); b=B(:,c);
        if e>1 && c==1
            a=A(A(:,2)>0.05,1); b=B(B(:,2)>0.05,1);
        end
        if ~isempty(a), hP(:,c,e)=histcounts(a,linspace(0,1,17),'Normalization','probability')'; end
        if ~isempty(b), hC(:,c,e)=histcounts(b,linspace(0,1,17),'Normalization','probability')'; end
        if ~isempty(a) && ~isempty(b), js(c)=jensen_shannon(hP(:,c,e),hC(:,c,e)); end
    end
    sdP=mean(std(hP(:,:,e),1,1),'omitnan');
    sdC=mean(std(hC(:,:,e),1,1),'omitnan');

    % 2. Restas y entropia: solo RGB, donde los canales son comparables.
    difRGB=NaN; entP=NaN; entC=NaN;
    if e==1
        dA=[A(:,1)-A(:,2), A(:,2)-A(:,3)];
        dB=[B(:,1)-B(:,2), B(:,2)-B(:,3)];
        difRGB=norm(mean(dA,1)-mean(dB,1));
        entP=entropia_restas(dA); entC=entropia_restas(dB);
    end

    % 3. Grupos de vecindarios 3x3, usando medias y desviaciones locales.
    grupos=clusters_vecindarios(X,P,C,e);
    medidas(e,:)=[diferenciaMedia,mean(js,'omitnan'),sdP,sdC, ...
        dispersion,difRGB,entP,entC,grupos];
end
T=array2table(medidas,'VariableNames',{'DiferenciaMedias','DistanciaHistogramas', ...
    'DesvHistPlaca','DesvHistCarroceria','DispersionTonoPlaca','DispersionTonoCarroceria', ...
    'DiferenciaCanalesRGB','EntropiaDifRGBPlaca','EntropiaDifRGBCarroceria', ...
    'DistanciaClusters'});
T=addvars(T,nombres,'Before',1,'NewVariableNames','Espacio');
end

function X=rgb_a_hsi(I)
R=I(:,:,1); G=I(:,:,2); B=I(:,:,3);
intensidad=(R+G+B)/3;
S=1-min(I,[],3)./max(intensidad,eps); S(intensidad==0)=0;
den=sqrt(max(0,(R-G).^2+(R-B).*(G-B)));
H=acos(max(-1,min(1,0.5*(2*R-G-B)./max(den,eps))))/(2*pi);
H(B>G)=1-H(B>G); H(S<eps)=0;
X=cat(3,H,S,intensidad);
end

function [media,dispersion]=tono(A)
h=A(A(:,2)>0.05,1);
if isempty(h), media=NaN; dispersion=NaN; return; end
z=mean(exp(2i*pi*h));
media=mod(angle(z)/(2*pi),1); dispersion=1-abs(z);
if abs(z)<1e-12, media=NaN; end
end

function d=distancia_color(A,B,e)
delta=abs(A-B);
if e>1
    delta(:,1)=min(delta(:,1),1-delta(:,1));
    delta(A(:,2)<=0.05 | B(:,2)<=0.05 | isnan(delta(:,1)),1)=0;
end
d=sqrt(sum(delta.^2,2));
end

function js=jensen_shannon(p,q)
p=p(:)/sum(p); q=q(:)/sum(q); m=(p+q)/2;
ip=p>0; iq=q>0;
js=0.5*sum(p(ip).*log2(p(ip)./m(ip)))+0.5*sum(q(iq).*log2(q(iq)./m(iq)));
end

function H=entropia_restas(D)
H=zeros(1,2);
for c=1:2
    p=histcounts(D(:,c),linspace(-1,1,17),'Normalization','probability');
    p=p(p>0); H(c)=-sum(p.*log2(p));
end
H=mean(H);
end

function js=clusters_vecindarios(X,P,C,e)
if e>1
    % Mismo H,S: su forma circular evita separar H=0 de H=1 en k-means.
    H=X(:,:,1); S=X(:,:,2);
    X=cat(3,S.*cos(2*pi*H),S.*sin(2*pi*H),X(:,:,3));
end
F=zeros([size(P),6]); kernel=ones(3)/9;
for c=1:3
    canal=X(:,:,c); mu=conv2(canal,kernel,'same');
    F(:,:,c)=mu;
    F(:,:,c+3)=sqrt(max(0,conv2(canal.^2,kernel,'same')-mu.^2));
end
% Solo vecindarios completos dentro de cada region.
interiorP=conv2(double(P),ones(3),'same')==9;
interiorC=conv2(double(C),ones(3),'same')==9;
F=reshape(F,[],6); A=F(interiorP(:),:); B=F(interiorC(:),:);
n=min([200,size(A,1),size(B,1)]);
if n<3, js=NaN; return; end
A=A(round(linspace(1,size(A,1),n)),:);
B=B(round(linspace(1,size(B,1),n)),:);
Z=[A;B]; escala=std(Z,0,1); escala(escala<1e-6)=1;
Z=(Z-mean(Z,1))./escala;

% K-means sencillo de Chapter4: asignar grupos y recalcular centros.
centros=Z([1,n+1],:);
[~,i]=max(min(distancias(Z,centros),[],2)); centros(3,:)=Z(i,:);
for iter=1:20
    [~,grupo]=min(distancias(Z,centros),[],2);
    nuevos=centros;
    for k=1:3
        if any(grupo==k), nuevos(k,:)=mean(Z(grupo==k,:),1); end
    end
    if max(abs(nuevos-centros),[],'all')<1e-6, break; end
    centros=nuevos;
end
[~,grupo]=min(distancias(Z,centros),[],2);
p=accumarray(grupo(1:n),1,[3,1]); q=accumarray(grupo(n+1:end),1,[3,1]);
js=jensen_shannon(p,q);
end

function D=distancias(Z,centros)
D=zeros(size(Z,1),size(centros,1));
for k=1:size(centros,1), D(:,k)=sum((Z-centros(k,:)).^2,2); end
end
