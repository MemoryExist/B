function plot_problem2(cfg, out)
%PLOT_PROBLEM2 三张结果图；复用已有评价，不重复扫描角度。
[Db,~] = D_region(cfg);
[Eb,~] = E_polygon(cfg);
f = figure('Visible','off','Color','w','Position',[50 50 1000 560]);
hold on;
if cfg.crop_enabled
    [~,Dout] = source_polygons(cfg);
    fill(Dout(1,:),Dout(2,:),[0.85 0.93 1],'EdgeColor','none','DisplayName','D (outer display)');
else
    fill(Db(1,:),Db(2,:),[0.85 0.93 1],'EdgeColor','none','DisplayName','D');
end
plot(Eb(1,:),Eb(2,:),'k.','MarkerSize',3,'DisplayName','Boundary of E');
scatter(out.Pcand(1,:),out.Pcand(2,:),9,[0.7 0.7 0.7],'filled','DisplayName','Coarse candidates');
P = [out.fines.P];
scatter(P(1,:),P(2,:),25,[0.2 0.45 0.8],'filled','DisplayName','Refined candidates');
Q = P(:,out.near_indices);
scatter(Q(1,:),Q(2,:),65,[0.85 0.35 0.2],'LineWidth',1.1,'DisplayName','Within accuracy allowance');
plot(out.P_best(1),out.P_best(2),'rp','MarkerSize',14,'MarkerFaceColor','r','DisplayName','Smallest upper bound');
plot(out.P_f2(1),out.P_f2(2),'md','MarkerSize',10,'LineWidth',1.8,'DisplayName','Selected P');
plot(0,0,'ks','MarkerFaceColor','k','DisplayName','First station');
axis equal; grid on; xlabel('x (m)'); ylabel('y (m)');
title('Two-stage selection of the second station');
legend('Location','eastoutside','FontSize',9);
save_figure(f,fullfile(cfg.fig_dir,'fig1_overview.png'));

% 只放大定位区域。外近似包围圆覆盖真实区域，内近似圆不能作此保证。
P = out.P_f2; b = out.representative_beta;
[inner,~] = build_J_region(P,b,cfg.delta,'inner',cfg);
[outer,~] = build_J_region(P,b,cfg.delta,'outer',cfg);
r = out.representative_radius; c = out.representative_center;
f = figure('Visible','off','Color','w','Position',[50 50 760 570]); hold on;
for k=1:numel(inner)
    K = inner{k}; fill(K(1,:),K(2,:),[0.78 0.9 1],'EdgeColor','none','HandleVisibility','off');
end
plot(nan,nan,'s','MarkerFaceColor',[0.78 0.9 1],'Color',[0.78 0.9 1],'DisplayName','Inner approximation');
for k=1:numel(outer)
    K = outer{k}; closed = [1:size(K,2),1];
    plot(K(1,closed),K(2,closed),'k-','LineWidth',1,'HandleVisibility','off');
end
plot(nan,nan,'k-','DisplayName','Outer approximation');
t = linspace(0,2*pi,300);
plot(c(1)+r*cos(t),c(2)+r*sin(t),'r-','LineWidth',1.5,'DisplayName','Covering circle of outer region');
plot(c(1),c(2),'r+','MarkerSize',12,'LineWidth',1.5,'DisplayName','Circle center');
axis equal; grid on; xlabel('x (m)'); ylabel('y (m)');
xlim(c(1)+[-1 1]*max(1,1.15*r)); ylim(c(2)+[-1 1]*max(1,1.15*r));
title(sprintf('Representative observation: beta = %.3f deg, covering radius = %.3f m', ...
    mod(rad2deg(b),360),r),'FontSize',11);
legend('Location','southoutside','FontSize',9);
save_figure(f,fullfile(cfg.fig_dir,'fig2_worst_region.png'));

r = out.cache(point_key(out.P_best));
f = figure('Visible','off','Color','w','Position',[50 50 900 380]);
tiledlayout(1,2,'TileSpacing','compact');
nexttile; stairs(r.log.n,r.log.U,'r-','LineWidth',1.4); hold on;
stairs(r.log.n,r.log.L,'b-','LineWidth',1.4); grid on;
xlabel('Circle evaluations'); ylabel('Radius (m)'); legend('Upper bound','Lower bound');
title('Bounds at the best refined candidate');
nexttile; semilogy(r.log.n,max(r.log.U-r.log.L,eps),'k-','LineWidth',1.4); hold on;
yline(cfg.tol_fine,'r--'); grid on; xlabel('Circle evaluations'); ylabel('U - L (m)');
title(sprintf('Final interval width: %.4f m',r.U-r.L));
save_figure(f,fullfile(cfg.fig_dir,'fig3_convergence.png'));
end

function save_figure(f,path)
% 固定论文配色，避免继承 MATLAB 桌面的深色主题。
set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k', ...
    'GridColor',[0.65 0.65 0.65],'MinorGridColor',[0.8 0.8 0.8],'FontName','Arial');
set(findall(f,'Type','text'),'Color','k');
set(findall(f,'Type','legend'),'Color','w','TextColor','k','EdgeColor',[0.7 0.7 0.7]);
exportgraphics(f,path,'Resolution',180,'BackgroundColor','white'); close(f);
end
