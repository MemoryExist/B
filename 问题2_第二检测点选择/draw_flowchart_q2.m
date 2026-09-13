function draw_flowchart_q2()
    % 生成问题二：第二检测点选择算法的完整多分支流程图

    fig = figure('Name', '问题二流程图', 'Color', 'w', 'Position', [100, 50, 1000, 950]);
    axes('Position', [0 0 1 1]);
    axis([0 1 0 1]);
    axis off;
    hold on;

    % 颜色定义
    c_blue   = [228, 240, 255] / 255;
    c_blue_e = [80, 130, 200] / 255;
    
    c_yellow   = [255, 248, 228] / 255;
    c_yellow_e = [220, 160, 80] / 255;
    
    c_red    = [255, 235, 235] / 255;
    c_red_e  = [200, 80, 80] / 255;
    
    c_green  = [235, 250, 235] / 255;
    c_green_e= [90, 160, 90] / 255;
    
    c_purple = [245, 235, 255] / 255;
    c_purple_e=[160, 100, 200]/255;
    
    c_gray_bg= [0.96 0.96 0.96];
    c_gray_edge= [0.8 0.8 0.8];

    % 添加主标题
    text(0.5, 0.96, '问题二流程图', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 22, 'FontWeight', 'bold', 'FontName', 'Microsoft YaHei', 'Color', [0.1 0.1 0.1]);

    % 背景框 1：粗评阶段
    rectangle('Position', [0.03, 0.62, 0.94, 0.24], 'Curvature', 0.02, ...
        'FaceColor', [c_gray_bg, 0.7], 'EdgeColor', c_gray_edge, 'LineStyle', '--', 'LineWidth', 1.5);
    text(0.04, 0.845, '第一阶段：极速粗筛评估 (Stage 1)', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0.4 0.4 0.4], 'FontName', 'Microsoft YaHei');

    % 背景框 2：精评阶段
    rectangle('Position', [0.03, 0.12, 0.94, 0.37], 'Curvature', 0.02, ...
        'FaceColor', [c_gray_bg, 0.7], 'EdgeColor', c_gray_edge, 'LineStyle', '--', 'LineWidth', 1.5);
    text(0.04, 0.47, '第二阶段：高精度严格评估 (Stage 2)', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0.4 0.4 0.4], 'FontName', 'Microsoft YaHei');

    % 定义节点信息: [x, y, w, h, color, edge_color, shape, text]
    nodes = {
        'N1', 0.5, 0.90, 0.35, 0.06, c_blue, c_blue_e, 'rect', '1. 构建候选区域 E 并离散采样';
        'N2', 0.5, 0.79, 0.35, 0.06, c_blue, c_blue_e, 'rect', '2. 极速打分 (线性化包围指标与下界)';
        'N2L', 0.18, 0.79, 0.24, 0.07, c_purple, c_purple_e, 'rect', '近似原理：\n泰勒展开与端点极值定理';
        'N3', 0.5, 0.68, 0.35, 0.08, c_yellow, c_yellow_e, 'diamond', '成对下界 > 淘汰阈值？\n(提前淘汰)';
        'N3R', 0.82, 0.68, 0.16, 0.06, c_red, c_red_e, 'rect', '淘汰候选点';
        'N4', 0.5, 0.55, 0.35, 0.06, c_blue, c_blue_e, 'rect', '3. 优质点起点：8方向模式搜索';
        'N5', 0.5, 0.43, 0.35, 0.06, c_blue, c_blue_e, 'rect', '4. 构造几何真实区域的内外多边形';
        'N6', 0.5, 0.33, 0.35, 0.07, c_blue, c_blue_e, 'rect', '计算 MEC (最小包围圆)\n更新全局上下界 U, L';
        'N7', 0.5, 0.20, 0.35, 0.08, c_yellow, c_yellow_e, 'diamond', '收敛： U(P) - L(P) ≤ 容差？';
        'N7L', 0.18, 0.265, 0.20, 0.06, c_purple, c_purple_e, 'rect', '二分细分测向区间';
        'N8', 0.5, 0.06, 0.40, 0.07, c_green, c_green_e, 'rect', '5. 终选：精度让步 ε 内取路程最短点 P*';
    };

    % 存储节点中心和边框，用于画箭头
    pos_map = containers.Map();

    % 绘制所有节点
    for i = 1:size(nodes, 1)
        id = nodes{i,1}; x = nodes{i,2}; y = nodes{i,3}; w = nodes{i,4}; h = nodes{i,5};
        fc = nodes{i,6}; ec = nodes{i,7}; shape = nodes{i,8}; txt = nodes{i,9};
        
        draw_node(x, y, w, h, fc, ec, shape, txt);
        pos_map(id) = [x, y, w, h];
    end

    % ================= 连线与箭头逻辑 =================
    % N1 -> N2
    draw_arrow(0.5, 0.87, 0.5, 0.82, '');
    % N2L <--> N2 (虚线表示说明)
    % N2L 的右边缘为 0.18 + 0.12 = 0.30. N2 的左边缘为 0.5 - 0.175 = 0.325
    plot([0.30, 0.325], [0.79, 0.79], 'k--', 'LineWidth', 1.5, 'Color', [0.5 0.5 0.5]);
    
    % N2 -> N3
    draw_arrow(0.5, 0.76, 0.5, 0.72, '');
    % N3 -> N3R (是)
    % N3 的右边缘为 0.5 + 0.175 = 0.675. N3R 的左边缘为 0.82 - 0.08 = 0.74
    draw_arrow(0.675, 0.68, 0.74, 0.68, '是');
    % N3 -> N4 (否)
    draw_arrow(0.5, 0.64, 0.5, 0.58, '否');
    % N4 -> N5
    draw_arrow(0.5, 0.52, 0.5, 0.46, '');
    % N5 -> N6
    draw_arrow(0.5, 0.40, 0.5, 0.365, '');
    % N6 -> N7
    draw_arrow(0.5, 0.295, 0.5, 0.24, '');
    
    % N7 -> N7L (否) 左分支与循环
    % N7 左边缘为 0.5 - 0.175 = 0.325. N7L 底部在 y=0.235, 中心 x=0.18
    plot([0.325, 0.18], [0.20, 0.20], 'Color', [0.4 0.4 0.4], 'LineWidth', 2.5);
    text(0.25, 0.215, '否', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.3 0.3 0.3], 'FontName', 'Microsoft YaHei', 'HorizontalAlignment', 'center');
    draw_arrow(0.18, 0.20, 0.18, 0.235, ''); % Arrow into N7L bottom
    
    % N7L -> N6 返回循环
    % N7L 顶部 y=0.295. N6 左边缘 x=0.325, y=0.33
    plot([0.18, 0.18], [0.295, 0.33], 'Color', [0.4 0.4 0.4], 'LineWidth', 2.5);
    draw_arrow(0.18, 0.33, 0.325, 0.33, ''); % Arrow into N6 left

    % N7 -> N8 (是)
    draw_arrow(0.5, 0.16, 0.5, 0.095, '是');

    % 保存图片
    exportgraphics(fig, '问题二_第二检测点求解流程图.png', 'Resolution', 300);
end

function draw_node(x, y, w, h, fc, ec, shape, txt)
    % 画阴影
    offset = 0.005;
    if strcmp(shape, 'rect')
        rectangle('Position', [x-w/2+offset, y-h/2-offset, w, h], 'Curvature', 0.15, 'FaceColor', [0.85 0.85 0.85], 'EdgeColor', 'none');
        rectangle('Position', [x-w/2, y-h/2, w, h], 'Curvature', 0.15, 'FaceColor', fc, 'EdgeColor', ec, 'LineWidth', 2);
    elseif strcmp(shape, 'diamond')
        X = [x, x+w/2, x, x-w/2];
        Y = [y+h/2, y, y-h/2, y];
        fill(X+offset, Y-offset, [0.85 0.85 0.85], 'EdgeColor', 'none');
        fill(X, Y, fc, 'EdgeColor', ec, 'LineWidth', 2);
    end
    
    txt = strrep(txt, '\n', newline);
    % 添加文字
    text(x, y, txt, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Microsoft YaHei', 'Color', [0.1 0.1 0.1]);
end

function draw_arrow(x1, y1, x2, y2, label_txt, align)
    if nargin < 6
        align = 'center';
    end
    c = [0.4 0.4 0.4];
    plot([x1, x2], [y1, y2], 'Color', c, 'LineWidth', 2.5);
    
    % 箭头头
    vec = [x2-x1, y2-y1];
    vec = vec / norm(vec);
    perp = [-vec(2), vec(1)];
    head_len = 0.015;
    head_wid = 0.01;
    
    p1 = [x2, y2];
    p2 = [x2 - head_len*vec(1) + head_wid*perp(1), y2 - head_len*vec(2) + head_wid*perp(2)];
    p3 = [x2 - head_len*vec(1) - head_wid*perp(1), y2 - head_len*vec(2) - head_wid*perp(2)];
    fill([p1(1), p2(1), p3(1)], [p1(2), p2(2), p3(2)], c, 'EdgeColor', 'none');
    
    if ~isempty(label_txt)
        label_txt = strrep(label_txt, '\n', newline);
        xm = (x1+x2)/2; ym = (y1+y2)/2;
        if strcmp(align, 'center')
            text(xm + 0.02, ym, label_txt, 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.3 0.3 0.3], 'FontName', 'Microsoft YaHei');
        else
            text(xm, ym + 0.015, label_txt, 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.3 0.3 0.3], 'FontName', 'Microsoft YaHei', 'HorizontalAlignment', 'center');
        end
    end
end
