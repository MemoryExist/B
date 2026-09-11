function S = sensitivity(out, cfg)
%SENSITIVITY 可选实验：同一精评集合内改变精度让步，以及固定点继续提高精度。
taus = [0 1 3];
good = strcmp({out.fines.status},'converged');
S = struct();
for k=1:numel(taus)
    idx = find(good & [out.fines.U] <= out.m_hat+taus(k));
    [~,j] = min([out.fines(idx).dist]); f = out.fines(idx(j));
    S.tau(k) = struct('tau',taus(k),'x',f.P(1),'y',f.P(2),'L',f.L,'U',f.U, ...
        'dist',f.dist,'time',f.dist/cfg.speed,'count',numel(idx));
end
writetable(struct2table(S.tau),fullfile(cfg.results_dir,'sensitivity_tau.csv'));
tols = [0.5 0.1 0.05]; state = [];
for k=1:numel(tols)
    cfg.eval_tol = tols(k); cfg.eval_budget = 1200; cfg.kill_threshold = inf;
    r = eval_P_bounds(out.P_best,cfg,state);
    state = r.state;
    S.tol(k) = struct('tol',tols(k),'L',r.L,'U',r.U,'gap',r.U-r.L, ...
        'neval',r.neval,'status',r.status);
end
writetable(struct2table(S.tol),fullfile(cfg.results_dir,'sensitivity_tol.csv'));
fprintf('敏感性结果已分别写入 sensitivity_tau.csv 与 sensitivity_tol.csv。\n');
end
