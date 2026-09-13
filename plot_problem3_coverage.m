%% 问题三：七点检测方案覆盖目标圆域
% 图 (a) 展示原点与六个环站的接收范围对整个目标圆域的覆盖；
% 图 (b) 展示一个 60° 扇区中的边界最不利位置。
% 运行本脚本后，会在“问题3，4论文及可视化”文件夹中导出 PNG 和 PDF。

clear; clc; close all;

R_domain = 1800;                 % 目标圆域半径/m
R_receive = 1000;                % 最小有效接收半径/m
r_a = 1200;                      % 图示取自适应环站半径的最小值
ang = linspace(0,2*pi,721);
stationAng = (0:5)*pi/3;
ringStations = r_a*[cos(stationAng);sin(stationAng)];
stations = [[0;0],ringStations];

% 颜色兼顾屏幕显示和论文打印；线型与点型使灰度打印仍可区分。
cDomain = [0.94 0.94 0.91];
cCover = [0.30 0.57 0.82];
cBoundary = [0.12 0.16 0.22];
cStation = [0.08 0.34 0.55];
cSource = [0.78 0.20 0.16];
fontName = 'Songti SC';

fig = figure('Color','w','Position',[80 80 1280 610], ...
    'Name','问题三检测点覆盖方案','ToolBar','none');
t = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

%% (a) 七个检测点的整体覆盖
ax1 = nexttile(t,1);
hold(ax1,'on');
ax1.Color = 'w';
ax1.XColor = cBoundary;
ax1.YColor = cBoundary;
ax1.GridColor = [0.70 0.72 0.75];
ax1.Toolbar.Visible = 'off';

fill(ax1,R_domain*cos(ang),R_domain*sin(ang),cDomain, ...
    'EdgeColor','none','HandleVisibility','off');

% 依次绘制七个最小接收圆；较低透明度用于显示重叠关系。
for j = 1:size(stations,2)
    xCircle = stations(1,j)+R_receive*cos(ang);
    yCircle = stations(2,j)+R_receive*sin(ang);
    fill(ax1,xCircle,yCircle,cCover,'FaceAlpha',0.075, ...
        'EdgeColor',cCover,'LineWidth',0.75, ...
        'LineStyle','--','HandleVisibility','off');
end

hTarget = plot(ax1,R_domain*cos(ang),R_domain*sin(ang), ...
    'Color',cBoundary,'LineWidth',2.0);
plot(ax1,r_a*cos(ang),r_a*sin(ang),':', ...
    'Color',[0.38 0.42 0.47],'LineWidth',1.2,'HandleVisibility','off');
hReceive = plot(ax1,stations(1,1)+R_receive*cos(ang), ...
    stations(2,1)+R_receive*sin(ang),'--','Color',cCover,'LineWidth',1.1);
hOrigin = scatter(ax1,0,0,62,'o','filled','MarkerFaceColor',cBoundary, ...
    'MarkerEdgeColor','w','LineWidth',0.8);
hRing = scatter(ax1,ringStations(1,:),ringStations(2,:),68,'s','filled', ...
    'MarkerFaceColor',cStation,'MarkerEdgeColor','w','LineWidth',0.8);

% 取扇区角平分线与目标边界的交点作为直观的边界示例。
G = R_domain*[cos(pi/6);sin(pi/6)];
dG = norm(G-ringStations(:,1));
plot(ax1,[ringStations(1,1),G(1)],[ringStations(2,1),G(2)], ...
    '-','Color',cSource,'LineWidth',1.4,'HandleVisibility','off');
hSource = scatter(ax1,G(1),G(2),84,'d','filled', ...
    'MarkerFaceColor',cSource,'MarkerEdgeColor','w','LineWidth',0.8);
text(ax1,G(1)-75,G(2)+145,'边界示例源  G^*', ...
    'FontName',fontName,'FontSize',11,'Color',cSource, ...
    'HorizontalAlignment','center');
text(ax1,1050,610,sprintf('d = %.1f m < 1000 m',dG), ...
    'FontName','Times New Roman','FontSize',11,'Color',cSource, ...
    'Rotation',30,'HorizontalAlignment','center');
text(ax1,-330,-175,'O','FontName','Times New Roman', ...
    'FontSize',11,'Color',cBoundary);
text(ax1,-2150,2050,'r_a \in [1200,1500] m（图示取 1200 m）', ...
    'FontName',fontName,'FontSize',10.5,'Color',[0.28 0.31 0.35]);

axis(ax1,'equal');
xlim(ax1,[-2250 2250]);
ylim(ax1,[-2250 2250]);
grid(ax1,'on');
box(ax1,'on');
ax1.GridAlpha = 0.13;
ax1.FontName = fontName;
ax1.FontSize = 10.5;
xlabel(ax1,'x / m','FontName',fontName,'Color',cBoundary);
ylabel(ax1,'y / m','FontName',fontName,'Color',cBoundary);
title(ax1,'(a) 原点与六个环站的联合覆盖', ...
    'FontName',fontName,'FontWeight','normal','Color',cBoundary);
lgd = legend(ax1,[hTarget,hReceive,hOrigin,hRing,hSource], ...
    {'目标圆域边界','最小接收圆边界','原点检测站','环形检测站','示例干扰源'}, ...
    'Location','southoutside','NumColumns',3,'FontName',fontName, ...
    'Box','off');
lgd.TextColor = cBoundary;
lgd.Color = 'none';

%% (b) 单个 60° 扇区的覆盖几何
ax2 = nexttile(t,2);
hold(ax2,'on');
ax2.Color = 'w';
ax2.XColor = cBoundary;
ax2.YColor = cBoundary;
ax2.GridColor = [0.70 0.72 0.75];
ax2.Toolbar.Visible = 'off';
sectorAng = linspace(0,pi/3,241);
fill(ax2,[0,R_domain*cos(sectorAng),0], ...
    [0,R_domain*sin(sectorAng),0],cDomain, ...
    'EdgeColor','none','HandleVisibility','off');

A1 = ringStations(:,1);
A2 = ringStations(:,2);
for A = [A1,A2]
    fill(ax2,A(1)+R_receive*cos(ang),A(2)+R_receive*sin(ang), ...
        cCover,'FaceAlpha',0.095,'EdgeColor',cCover, ...
        'LineStyle','--','LineWidth',1.0,'HandleVisibility','off');
end

plot(ax2,R_domain*cos(sectorAng),R_domain*sin(sectorAng), ...
    'Color',cBoundary,'LineWidth',2.0,'HandleVisibility','off');
plot(ax2,[0,R_domain],[0,0],'-','Color',cBoundary, ...
    'LineWidth',1.0,'HandleVisibility','off');
plot(ax2,[0,R_domain*cos(pi/3)],[0,R_domain*sin(pi/3)],'-', ...
    'Color',cBoundary,'LineWidth',1.0,'HandleVisibility','off');
plot(ax2,[0,G(1)],[0,G(2)],':','Color',[0.38 0.42 0.47], ...
    'LineWidth',1.2,'HandleVisibility','off');
plot(ax2,[A1(1),G(1)],[A1(2),G(2)],'-','Color',cSource, ...
    'LineWidth',1.7,'HandleVisibility','off');

scatter(ax2,0,0,62,'o','filled','MarkerFaceColor',cBoundary, ...
    'MarkerEdgeColor','w','LineWidth',0.8);
scatter(ax2,[A1(1),A2(1)],[A1(2),A2(2)],68,'s','filled', ...
    'MarkerFaceColor',cStation,'MarkerEdgeColor','w','LineWidth',0.8);
scatter(ax2,G(1),G(2),84,'d','filled','MarkerFaceColor',cSource, ...
    'MarkerEdgeColor','w','LineWidth',0.8);

% 标出边界方向与最近环站方向之间的最大夹角 30°。
arcR = 360;
arcAng = linspace(0,pi/6,80);
plot(ax2,arcR*cos(arcAng),arcR*sin(arcAng), ...
    'Color',cSource,'LineWidth',1.2,'HandleVisibility','off');
text(ax2,390*cos(pi/12),390*sin(pi/12),'30^\circ', ...
    'Interpreter','tex','FontName','Times New Roman', ...
    'FontSize',11,'Color',cSource,'HorizontalAlignment','center');

text(ax2,-70,-70,'O','FontName','Times New Roman','FontSize',11);
text(ax2,A1(1)+35,A1(2)-80,'A_1','Interpreter','tex', ...
    'FontName','Times New Roman','FontSize',11,'Color',cStation);
text(ax2,A2(1)-135,A2(2)+45,'A_2','Interpreter','tex', ...
    'FontName','Times New Roman','FontSize',11,'Color',cStation);
text(ax2,G(1)+35,G(2)+55,'G^*','Interpreter','tex', ...
    'FontName','Times New Roman','FontSize',11,'Color',cSource);
text(ax2,1110,520,sprintf('最不利边界距离\n%.1f m < 1000 m',dG), ...
    'FontName',fontName,'FontSize',11,'Color',cSource, ...
    'HorizontalAlignment','center');
text(ax2,660,-105,'r_a = 1200 m','Interpreter','tex', ...
    'FontName','Times New Roman','FontSize',11,'Color',cStation);

axis(ax2,'equal');
xlim(ax2,[-150 2000]);
ylim(ax2,[-150 1750]);
grid(ax2,'on');
box(ax2,'on');
ax2.GridAlpha = 0.13;
ax2.FontName = fontName;
ax2.FontSize = 10.5;
xlabel(ax2,'x / m','FontName',fontName,'Color',cBoundary);
ylabel(ax2,'y / m','FontName',fontName,'Color',cBoundary);
title(ax2,'(b) 单个扇区中的边界最不利位置', ...
    'FontName',fontName,'FontWeight','normal','Color',cBoundary);

title(t,'问题三检测点布设及目标圆域覆盖示意图', ...
    'FontName',fontName,'FontSize',15,'FontWeight','normal', ...
    'Color',cBoundary);

%% 导出论文用图片
rootDir = fileparts(mfilename('fullpath'));
outDir = fullfile(rootDir,'问题3，4论文及可视化');
if ~exist(outDir,'dir')
    mkdir(outDir);
end
drawnow;
% R2025a 在同一图窗连续调用两次 exportgraphics 时可能提前释放图窗，
% 因此先用 print 输出位图，再以唯一一次 exportgraphics 输出矢量 PDF。
print(fig,fullfile(outDir,'图_问题三检测点覆盖方案.png'), ...
    '-dpng','-r300');
exportgraphics(fig,fullfile(outDir,'图_问题三检测点覆盖方案.pdf'), ...
    'ContentType','vector','BackgroundColor','white');

fprintf('图片已导出至：%s\n',outDir);
