% 生成问题一求解流程图
% 流程：建立半平面模型 -> 求解多边形顶点 -> 转化为顶点极值问题 -> 向量化求解直径

% 创建一个新的图形窗口
fig = figure('Name', '问题一流程图', 'Color', 'w', 'Position', [200, 200, 650, 750]);

% 设置坐标轴范围并隐藏坐标轴
axes('Position', [0 0 1 1]);
axis([0 1 0 1]);
axis off;
hold on;

% 定义各步骤的文本
texts = {
    'Step 1: 建立交会区域的半平面约束模型',
    'Step 2: 证明闭凸性和有界性',
    'Step 3: 说明其有界闭凸多边形结构',
    'Step 4: 基于向量化方法高效计算直径'
    };

% 定义色彩风格 (Pastel UI)
colors = [
    228, 240, 255; % 浅蓝
    235, 250, 235; % 浅绿
    255, 240, 228; % 浅橙
    250, 235, 255; % 浅紫
    ] / 255;

edgeColors = [
    80, 130, 200;
    90, 160, 90;
    200, 130, 80;
    160, 90, 160;
    ] / 255;

% 定义流程图的框的参数
boxW = 0.8;
boxH = 0.12;
boxX = 0.5 - boxW/2;
yStart = 0.78; % 第一个框的底部y坐标
yGap = 0.18;   % 框之间的垂直间距

% 添加主标题
text(0.5, 0.95, '问题一：交会定位区域及其直径求解流程', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 20, ...
    'FontWeight', 'bold', ...
    'FontName', 'Microsoft YaHei', ...
    'Color', [0.15 0.15 0.15]);

% 绘制矩形、阴影和文本
for i = 1:length(texts)
    boxY = yStart - (i-1)*yGap;

    % 1. 绘制阴影 (偏移 0.008)
    rectangle('Position', [boxX + 0.008, boxY - 0.008, boxW, boxH], ...
        'Curvature', 0.2, ...
        'FaceColor', [0.9 0.9 0.9], ...
        'EdgeColor', 'none');

    % 2. 绘制主框
    rectangle('Position', [boxX, boxY, boxW, boxH], ...
        'Curvature', 0.2, ...
        'FaceColor', colors(i,:), ...
        'EdgeColor', edgeColors(i,:), ...
        'LineWidth', 2);

    % 3. 添加文本
    text(0.5, boxY + boxH/2, texts{i}, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 15, ...
        'FontWeight', 'bold', ...
        'FontName', 'Microsoft YaHei', ...
        'Color', [0.1 0.1 0.1]);

    % 4. 绘制向下箭头 (除了最后一个)
    if i < length(texts)
        arrX = 0.5;
        arrY_start = boxY;
        arrY_end = boxY - (yGap - boxH) + 0.01; % 留一点间隙

        % 画线
        plot([arrX, arrX], [arrY_start, arrY_end], 'Color', [0.5 0.5 0.5], 'LineWidth', 3);

        % 画箭头头部
        headW = 0.015;
        headH = 0.025;
        fill([arrX, arrX-headW, arrX+headW], ...
            [arrY_end, arrY_end+headH, arrY_end+headH], ...
            [0.5 0.5 0.5], 'EdgeColor', 'none');
    end
end

hold off;

% 自动保存为高清PNG图片
exportgraphics(fig, '问题一_直径求解流程图.png', 'Resolution', 300);
