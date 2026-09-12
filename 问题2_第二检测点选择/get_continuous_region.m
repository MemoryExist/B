% get_continuous_region.m
% 读取 results/out.mat，利用真实的评价函数 eval_P_bounds 在候选点附近进行密集网格采样，
% 从而找出严格满足精度容差 (U(P) <= m_hat + epsilon) 的连续可行区域，并绘制热力图。

function get_continuous_region()
    root = fileparts(mfilename('fullpath'));
    old = pwd; cleanup = onCleanup(@() cd(old));
    cd(root); addpath(genpath(root));
    
    fprintf('正在加载结果数据...\n');
    load('results/out.mat', 'out', 'cfg');
    
    P_fines = [out.fines.P];
    Q = P_fines(:, out.near_indices);
    
    % 为了让图片局部放大且好看，我们只关注最终选定点所在的那一半平面（上下对称）
    if out.P_f2(2) > 0
        Q_local = Q(:, Q(2,:) > 0);
    else
        Q_local = Q(:, Q(2,:) < 0);
    end
    
    % 定义包含该局部最优点的网格边界 (加上一定裕量，不要太大也不要太小，能够看到完整的局部边界)
    margin = 15; % 米
    min_x = min(Q_local(1,:)) - margin;
    max_x = max(Q_local(1,:)) + margin;
    min_y = min(Q_local(2,:)) - margin;
    max_y = max(Q_local(2,:)) + margin;
    
    % 生成 50x50 的高密度网格进行采样
    grid_size = 50;
    x_vec = linspace(min_x, max_x, grid_size);
    y_vec = linspace(min_y, max_y, grid_size);
    [X, Y] = meshgrid(x_vec, y_vec);
    Z_U = NaN(size(X)); % 记录上界 U(P)
    
    % 目标阈值
    threshold = out.m_hat + cfg.tau_m;
    fprintf('真实的最优上界基准 m_hat = %.4f m\n', out.m_hat);
    fprintf('寻找满足 U(P) <= %.4f m (m_hat + %.1f) 的连续区域\n', threshold, cfg.tau_m);
    
    % 为加快计算，当下界 L 超过阈值时可提前终止
    cfg.kill_threshold = threshold;
    cfg.eval_tol = cfg.tol_fine; % 必须使用精评容差，否则提前退出会导致 U(P) 虚高
    cfg.eval_budget = 400; % 需要足够大的预算让真正的好点收敛
    
    [Eb,~] = E_polygon(cfg);
    
    fprintf('开始对 %dx%d 网格进行真实包围半径的严密计算...\n', grid_size, grid_size);
    tic;
    for i = 1:numel(X)
        P_test = [X(i); Y(i)];
        if ~inpolygon(P_test(1), P_test(2), Eb(1,:), Eb(2,:))
            continue;
        end
        % 使用真实的评价函数计算
        res = eval_P_bounds(P_test, cfg);
        Z_U(i) = res.U;
    end
    t_calc = toc;
    fprintf('网格计算完成，耗时 %.2f 秒。\n', t_calc);
    
    % 绘图展示
    f = figure('Color', 'w', 'Position', [100 100 850 650], 'Visible', 'off');
    hold on;
    
    % 画出连续区域的等高线/热力填充
    % 我们主要关心 <= threshold 的区域
    levels = linspace(out.m_hat, threshold, 6);
    contourf(X, Y, Z_U, levels, 'LineStyle', 'none');
    colormap(flipud(parula)); % 颜色越深代表 U(P) 越小(越优)
    colorbar('Ticks', levels, 'TickLabels', arrayfun(@(x) sprintf('%.2f', x), levels, 'UniformOutput', false));
    
    % 画出满足阈值的确切边界 (最外层轮廓)
    [C, h] = contour(X, Y, Z_U, [threshold, threshold], 'LineColor', 'r', 'LineWidth', 2, 'DisplayName', 'Optimal Region Boundary');
    
    % 画出背景 E 区域边界作为参考
    plot(Eb(1,:), Eb(2,:), 'k.', 'MarkerSize', 2, 'DisplayName', 'Region E Boundary');
    
    % 画出原本离散搜索得到的好点
    scatter(Q(1,:), Q(2,:), 40, 'mo', 'filled', 'MarkerEdgeColor', 'w', 'DisplayName', 'Discrete Candidates');
    
    % 画出最终选定的单点
    plot(out.P_f2(1), out.P_f2(2), 'wp', 'MarkerSize', 14, 'MarkerFaceColor', 'r', 'DisplayName', 'Selected Point P');
    
    axis equal; grid on;
    % 恢复局部的 xlim 和 ylim 限制，以展示放大的局部边界区域
    xlim([min_x, max_x]); ylim([min_y, max_y]);
    xlabel('x (m)'); ylabel('y (m)');
    % 根据要求，不在图片上生成自带标题
    legend('Location', 'best');
    
    % 计算连续区域的近似面积 (由于上下对称，总面积需要乘以 2)
    dx = x_vec(2) - x_vec(1);
    dy = y_vec(2) - y_vec(1);
    area_approx = sum(Z_U(:) <= threshold) * dx * dy * 2;
    fprintf('上下两侧严格满足条件的连续可行区域总面积约为: %.2f 平方米\n', area_approx);
    
    % 保存图片
    save_path = fullfile(cfg.fig_dir, 'fig4_continuous_region_rigorous.png');
    exportgraphics(f, save_path, 'Resolution', 250, 'BackgroundColor', 'white');
    close(f);
    fprintf('已将严密的连续区域分布图保存至: %s\n', save_path);
end
