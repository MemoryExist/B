% plot_continuous_region_single.m
% 生成单侧完整最优连续区域边界视图

function plot_continuous_region_single()
    root = fileparts(mfilename('fullpath'));
    old = pwd; cleanup = onCleanup(@() cd(old));
    cd(root); addpath(genpath(root));
    
    fprintf('正在加载结果数据...\n');
    load('results/out.mat', 'out', 'cfg');
    
    threshold = out.m_hat + cfg.tau_m;
    cfg.kill_threshold = threshold;
    cfg.eval_tol = cfg.tol_fine;
    cfg.eval_budget = 400;
    
    [Eb,~] = E_polygon(cfg);
    
    % 获取局部优质点
    P_fines = [out.fines.P];
    Q = P_fines(:, out.near_indices);
    if out.P_f2(2) > 0
        Q_local = Q(:, Q(2,:) > 0);
    else
        Q_local = Q(:, Q(2,:) < 0);
    end
    
    % 设定一个足够大的搜索框，以覆盖整个单侧连续区域
    margin_search = 45; 
    min_x = min(Q_local(1,:)) - margin_search; max_x = max(Q_local(1,:)) + margin_search;
    min_y = min(Q_local(2,:)) - margin_search; max_y = max(Q_local(2,:)) + margin_search;
    
    grid_size = 100; % 高分辨率
    x_vec = linspace(min_x, max_x, grid_size);
    y_vec = linspace(min_y, max_y, grid_size);
    [X, Y] = meshgrid(x_vec, y_vec);
    Z_U = NaN(size(X));
    
    fprintf('开始高分辨率网格计算 (可能会花费数十秒)...\n');
    for i = 1:numel(X)
        P_test = [X(i); Y(i)];
        if ~inpolygon(P_test(1), P_test(2), Eb(1,:), Eb(2,:)), continue; end
        res = eval_P_bounds(P_test, cfg);
        Z_U(i) = res.U;
    end
    
    % 找到满足条件的点的真实紧凑包围盒
    [row, col] = find(Z_U <= threshold);
    if isempty(row)
        fprintf('未找到满足条件的区域，可能 margin_search 设置不合理。\n');
        return;
    end
    
    x_valid = X(Z_U <= threshold);
    y_valid = Y(Z_U <= threshold);
    
    zoom_margin = 15; % 图形留白，恰好能看到这部分全貌
    min_x_z = min(x_valid) - zoom_margin; max_x_z = max(x_valid) + zoom_margin;
    min_y_z = min(y_valid) - zoom_margin; max_y_z = max(y_valid) + zoom_margin;
    
    % ================= 绘制美观的视图 =================
    fig = figure('Name', '单侧完整连续区域视图', 'Color', 'w', 'Position', [150 150 850 650]);
    axes('Position', [0.1, 0.1, 0.72, 0.8]);
    hold on;
    
    % 使得热力图的层级分明
    levels = linspace(out.m_hat, threshold, 12);
    
    % 绘制热力图填充
    contourf(X, Y, Z_U, levels, 'LineStyle', 'none');
    colormap(flipud(parula));
    cb = colorbar;
    cb.Label.String = 'Worst-case distance bound U(P) [m]';
    cb.Label.FontSize = 12;
    cb.Position = [0.85, 0.1, 0.03, 0.8]; % 调整 colorbar 位置
    
    % 绘制完整的红色边界线 (轮廓)
    [~, h_cg] = contour(X, Y, Z_U, [threshold, threshold], 'LineColor', 'r', 'LineWidth', 2.5);
    % 为了图例能够正确显示 contour，使用一个 dummy plot
    plot(NaN, NaN, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Optimal Region Boundary (Continuous)');
    
    % 绘制可行域 E 的边界
    plot(Eb(1,:), Eb(2,:), 'k--', 'LineWidth', 1.5, 'Color', [0.4 0.4 0.4], 'DisplayName', 'Region E Boundary');
    
    % 绘制选中的最优决断点 P*
    plot(out.P_f2(1), out.P_f2(2), 'wp', 'MarkerSize', 18, 'MarkerFaceColor', 'r', 'LineWidth', 1.5, 'DisplayName', 'Selected Point P*');
    
    % 绘制所有优秀的离散候选点
    scatter(Q_local(1,:), Q_local(2,:), 40, 'mo', 'filled', 'MarkerEdgeColor', 'w', 'DisplayName', 'Discrete Candidate Points');
    
    % 美化设置
    axis equal; 
    grid on;
    set(gca, 'GridAlpha', 0.4, 'LineWidth', 1.2, 'FontSize', 12);
    xlim([min_x_z, max_x_z]); 
    ylim([min_y_z, max_y_z]);
    xlabel('x (m)', 'FontSize', 14, 'FontWeight', 'bold'); 
    ylabel('y (m)', 'FontSize', 14, 'FontWeight', 'bold');
    title('单侧完整最优连续区域分布视图', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Microsoft YaHei');
    
    legend('Location', 'northeast', 'FontSize', 11, 'AutoUpdate', 'off');
    
    if ~exist(cfg.fig_dir, 'dir')
        mkdir(cfg.fig_dir);
    end
    save_path = fullfile(cfg.fig_dir, 'fig4_continuous_region_single.png');
    exportgraphics(fig, save_path, 'Resolution', 300, 'BackgroundColor', 'white');
    
    fprintf('已将单侧完整连续区域分布图保存至: %s\n', save_path);
end
