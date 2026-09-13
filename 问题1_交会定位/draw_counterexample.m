% draw_counterexample.m
% 绘制等边三角形反例：以三角形直径为直径的圆无法覆盖该三角形，而最小覆盖圆的半径更大。
% 生成无标题的图像。

function draw_counterexample()
    root = fileparts(mfilename('fullpath'));
    cd(root);
    
    % 等边三角形顶点，边长 D = 1
    D = 1;
    % 顶点
    V1 = [0; 0];
    V2 = [D; 0];
    V3 = [D/2; D*sqrt(3)/2];
    
    % 最小覆盖圆 (外接圆)
    % 中心 C
    C = [D/2; D*sqrt(3)/6];
    % 半径 R_MEC = D/sqrt(3)
    R_MEC = D/sqrt(3);
    
    % 直径为 D 的圆（设圆心也为C，这样最能覆盖更多的点）
    R_D = D/2;
    
    f = figure('Color', 'w', 'Position', [200, 200, 600, 600], 'Visible', 'off');
    hold on;
    axis equal;
    
    % 画等边三角形
    fill([V1(1), V2(1), V3(1)], [V1(2), V2(2), V3(2)], [0.9 0.9 0.9], 'EdgeColor', 'k', 'LineWidth', 1.5, 'DisplayName', '等边三角形区域 K');
    
    % 画最小覆盖圆
    theta = linspace(0, 2*pi, 200);
    plot(C(1) + R_MEC*cos(theta), C(2) + R_MEC*sin(theta), 'b-', 'LineWidth', 2, 'DisplayName', '最小覆盖圆 (半径 D/\surd3)');
    
    % 画直径为 D 的圆
    plot(C(1) + R_D*cos(theta), C(2) + R_D*sin(theta), 'r--', 'LineWidth', 2, 'DisplayName', '直径为 D 的圆 (半径 D/2)');
    
    % 画出三角形的顶点
    plot([V1(1), V2(1), V3(1)], [V1(2), V2(2), V3(2)], 'k.', 'MarkerSize', 15, 'HandleVisibility', 'off');
    
    % 标注中心点
    plot(C(1), C(2), 'k+', 'MarkerSize', 8, 'HandleVisibility', 'off');
    
    % 图例和坐标系设置
    legend('Location', 'southoutside', 'FontSize', 12);
    axis off;
    
    % 保存图像
    save_path = fullfile(root, 'counterexample_triangle.png');
    exportgraphics(f, save_path, 'Resolution', 300, 'BackgroundColor', 'white');
    close(f);
    fprintf('反例图像已保存至: %s\n', save_path);
end
