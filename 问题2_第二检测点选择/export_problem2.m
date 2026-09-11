function export_problem2(out, cfg)
%EXPORT_PROBLEM2 CSV 与 LaTeX 共用本次输出，避免论文手抄旧数据。
selected = out.fines(out.selected_index);
items = {'m_hat_m';'P_best_x';'P_best_y';'f1_best_L_m';'f1_best_U_m';'f1_best_gap_m'; ...
    'worst_beta_deg';'P_f2_x';'P_f2_y';'f2_L_m';'f2_U_m';'f2_dist_m';'f2_time_s'; ...
    'tau_m';'n_candidates';'n_fine';'n_eval_calls';'n_cache_hits';'n_pruned'; ...
    'n_pair_pruned';'n_budget_returns';'t_search_s';'t_total_s'};
numbers = [out.m_hat;out.P_best;out.f1_best_L;out.f1_best_U;out.f1_best_gap; ...
    out.worst_beta_best;out.P_f2;selected.L;selected.U;out.f2_dist;out.f2_time; ...
    out.tau;size(out.Pcand,2);numel(out.fines);out.stats.n_eval_calls; ...
    out.stats.n_cache_hits;out.stats.n_pruned;out.stats.n_pair_pruned; ...
    out.stats.n_budget;out.t_total;out.t_run];
writetable(table(items,numbers,'VariableNames',{'item','value'}), ...
    fullfile(cfg.results_dir,'final_summary.csv'));
F = out.fines; P = [F.P];
T = table(P(1,:)',P(2,:)',[F.L]',[F.U]',[F.gap]',[F.dist]',{F.status}', ...
    [F.neval]','VariableNames',{'x','y','L','U','gap','dist','status','neval'});
writetable(T,fullfile(cfg.results_dir,'fine_points.csv'));
path = fullfile(cfg.results_dir,'problem2_numbers.tex');
fid = fopen(path,'w','n','UTF-8');
assert(fid >= 0,'无法写入论文数据文件。'); closer = onCleanup(@() fclose(fid));
fprintf(fid,'%% 自动生成：请运行 main_problem2 更新，不手动修改此文件。\n');
names = {'Delta','Lmax','Inner','Receive','Optical','Speed','Tau','CoarseTol','FineTol', ...
    'ArcN','HoleN','Candidates','FineCount','Calls','SearchTime','RunTime', ...
    'BestL','BestU','SelectedL','SelectedU','SelectedX','SelectedY','SelectedDist','SelectedTime'};
vals = [cfg.delta_deg,cfg.Lmax,cfg.r_inner,cfg.R0,cfg.clear_radius,cfg.speed,cfg.tau_m, ...
    cfg.tol_coarse,cfg.tol_fine,cfg.n_arc,cfg.n_hole_gon,size(out.Pcand,2),numel(F), ...
    out.stats.n_eval_calls,out.t_total,out.t_run,out.f1_best_L,out.f1_best_U, ...
    selected.L,selected.U,out.P_f2',out.f2_dist,out.f2_time];
for k=1:numel(names)
    value = regexprep(sprintf('%.3f',vals(k)),'\.?0+$','');
    fprintf(fid,'\\newcommand{\\Q%s}{%s}\n',names{k},value);
end
fprintf(fid,'\\newcommand{\\QResultRows}{%%\n');
labels = {'近似指标最小的候选点','精评上界最小的候选点','兼顾路程的选择'};
P = [out.P_hat,out.P_best,out.P_f2];
lower = [out.hat_res.L,out.f1_best_L,selected.L];
upper = [out.hat_res.U,out.f1_best_U,selected.U];
for k=1:3
    fprintf(fid,'%s & $(%.2f,\\,%.2f)$ & $[%.3f,\\,%.3f]$ & %.2f \\\\\n', ...
        labels{k},P(:,k),lower(k),upper(k),norm(P(:,k)));
end
fprintf(fid,'}\n');
fprintf(fid,'\\newcommand{\\QNearCandidateRows}{%%\n');
near_fines = out.fines(out.near_indices);
for i = 1:numel(near_fines)
    p = near_fines(i);
    if out.near_indices(i) == out.selected_index
        mark = ' (最佳推荐)';
    else
        mark = '';
    end
    fprintf(fid,'候选点 %d%s & $(%.2f,\\,%.2f)$ & $[%.3f,\\,%.3f]$ & %.2f \\\\\n', ...
        i, mark, p.P(1), p.P(2), p.L, p.U, p.dist);
end
fprintf(fid,'}\n');

% =========================================================================
% 向控制台输出“较好观测点形成的区域”及选出的“最佳点”，供后续问题使用
% =========================================================================
fprintf('\n=================================================================\n');
fprintf('【问题2：较好观测点区域及最佳点推荐 (供后续问题3/4使用)】\n');
fprintf('根据精评结果，在允许精度让步 (tau = %.2fm) 范围内的较好观测点有 %d 个：\n', cfg.tau_m, numel(out.near_indices));

% 打印在这个区域内的所有较好点
near_fines = out.fines(out.near_indices);
for i = 1:numel(near_fines)
    p = near_fines(i);
    if i == out.selected_index
        fprintf(' => [最佳推荐/路程最短] 点位: (%7.2f, %7.2f) | 最坏误差半径: [%.2f, %.2f]m | 距起点: %.2fm\n', ...
            p.P(1), p.P(2), p.L, p.U, p.dist);
    else
        fprintf('    - [较好候选点]       点位: (%7.2f, %7.2f) | 最坏误差半径: [%.2f, %.2f]m | 距起点: %.2fm\n', ...
            p.P(1), p.P(2), p.L, p.U, p.dist);
    end
end
fprintf('注：您可以将上述【最佳推荐】点的坐标，或其它【较好候选点】的坐标，\n');
fprintf('    直接复制到后续问题 (如问题3或4) 的路径规划或策略代码中作为第二观测点。\n');
fprintf('=================================================================\n');

end
