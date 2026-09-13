% 生成问题一求解流程图
% 流程：经过闭凸性和有界性限定 -> 判断其为凸多边形结构 -> 得到直径的计算公式 -> 通过向量化求解方法求出直径

% 创建一个新的图形窗口
fig = figure('Name', '问题一流程图', 'Color', 'w', 'Position', [200, 200, 500, 650]);

% 设置坐标轴范围并隐藏坐标轴
axes('Position', [0 0 1 1]);
axis([0 1 0 1]);
axis off;
hold on;

% 定义流程图的框的参数
boxWidth = 0.65;
boxHeight = 0.12;
boxX = 0.5 - boxWidth/2;
yStart = 0.78; % 第一个框的底部y坐标
yGap = 0.18;  % 框之间的垂直间距

% 定义各步骤的文本
texts = {
    '通过闭凸性和有界性限定',
    '判断其为凸多边形结构',
    '得到直径的计算公式',
    '通过向量化求解方法求出直径'
    };

% 绘制矩形和文本
for i = 1:length(texts)
    boxY = yStart - (i-1)*yGap;

    % 绘制带圆角的矩形
    rectangle('Position', [boxX, boxY, boxWidth, boxHeight], ...
        'Curvature', 0.2, ...
        'FaceColor', [0.85 0.93 1], ... % 淡蓝色
        'EdgeColor', [0.2 0.5 0.8], ... % 深蓝色边界
        'LineWidth', 1.5);

    % 添加文本
    text(0.5, boxY + boxHeight/2, texts{i}, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 14, ...
        'FontWeight', 'bold', ...
        'FontName', 'Microsoft YaHei');
end

% 绘制箭头
for i = 1:length(texts)-1
    startY = yStart - (i-1)*yGap;
    endY = yStart - i*yGap + boxHeight;

    % 绘制直线部分
    plot([0.5, 0.5], [startY, endY], 'Color', [0.2 0.5 0.8], 'LineWidth', 1.5);

    % 绘制箭头头部 (向下的实心三角形)
    headWidth = 0.02;
    headHeight = 0.03;
    fill([0.5, 0.5-headWidth, 0.5+headWidth], ...
        [endY, endY+headHeight, endY+headHeight], ...
        [0.2 0.5 0.8], 'EdgeColor', 'none');
end

% 添加标题
text(0.5, 0.96, '问题一直径求解流程图', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 16, ...
    'FontWeight', 'bold', ...
    'FontName', 'Microsoft YaHei');

hold off;

% 自动保存为高清PNG图片
exportgraphics(fig, '问题一_直径求解流程图.png', 'Resolution', 300);
