function cfg = config_problem2()
%CONFIG_PROBLEM2 问题二全部参数集中配置(几何参数、算法参数、计算预算)
% 默认情形: 未被目标圆域裁切的标准完整扇区 D(见 README 默认假设)
cfg.seed          = 42;      % 全局随机种子(候选点/包围圆置换)
% ---- 题目几何参数(单位: 米/度) ----
cfg.delta_deg     = 1;       % 示向度误差半角(度)
cfg.delta         = deg2rad(cfg.delta_deg);
cfg.R0            = 1000;    % 有效接收半径下界(保守)
cfg.Lmax          = 1500;    % 有效接收半径上界/标准扇区外半径
cfg.r_inner       = 5;       % 近源孔半径(距离≤5 米转入光学分支)
cfg.clear_radius  = 20;      % 光学精确定位/清除半径
cfg.speed         = 5;       % 机器狗速度(米/秒)
% ---- 目标圆域裁切(可选, 默认关闭=标准完整扇区) ----
cfg.crop_enabled  = false;   % true 时源域 D 再与目标圆相交
cfg.crop_center   = [0; 0];  % 目标圆心(局部坐标)
cfg.crop_radius   = 1800;    % 目标圆域半径
% ---- 几何近似分辨率 ----
cfg.n_arc         = 2048;    % 外圆弧内接/外切正多边形边数
cfg.n_crop        = 512;     % 裁切圆多边形边数(仅 crop_enabled 时使用)
cfg.n_hole_gon    = 24;      % 近源孔外接多边形边数
cfg.hole_margin   = 5e-4;    % 孔外接多边形半径余量(使减去的集合略大于真孔, 下界仍有效)
% ---- 最小包围圆数值容差 ----
cfg.mec_tol       = 1e-9;    % 绝对容差(米)
cfg.mec_tol_rel   = 1e-12;   % 相对容差
% ---- 固定点评价(角度区间自适应细分) ----
cfg.eta0          = deg2rad(1);   % 初始角度箱半宽
cfg.tol_coarse    = 2.0;          % 粗评上下界差目标(米)
cfg.tol_fine      = 0.1;          % 精评上下界差目标(米)
cfg.budget_coarse = 160;          % 粗评单点最大角度评价次数
cfg.budget_fine   = 900;          % 精评单点最大角度评价次数
% ---- 见证点(点对下界) ----
cfg.witness_r     = [5.01 10 20 50 100 200 350 500 600 740 750 1000 1250 1448.54 1500];
cfg.witness_ang_deg = [-1 -0.6 -0.2 0 0.2 0.6 1];
% ---- 外层搜索 ----
cfg.cand_grid     = 20;      % E 内规则网格每维点数
cfg.cand_random   = 160;     % E 内均匀随机候选点数
cfg.n_hat_top     = 20;      % 近似指标最优进入粗评的点数
cfg.n_diverse     = 12;      % 多样化补充起点数
cfg.tau_kill      = 0.0;     % 提前淘汰容差(米): L(P)>U_best+tau_kill 即淘汰
cfg.tau_m         = 1.0;     % 精度让步 τ(米): 在 F_τ 内选移动距离最短
cfg.n_search_starts = 3;     % 局部搜索起点数
cfg.ls_step0      = 48;      % 模式搜索初始步长(米)
cfg.ls_step_min   = 4;       % 模式搜索最小步长(米)
cfg.ls_shrink     = 0.5;     % 步长缩减因子
cfg.ls_max_iter   = 45;      % 单次搜索最大迭代数
cfg.start_min_sep = 60;      % 搜索起点间最小距离(米)
cfg.fine_pool     = 3.0;     % 精评池: U ≤ U_best + fine_pool 的点
% ---- 输出 ----
cfg.results_dir   = 'results';
cfg.fig_dir       = 'figures';
cfg.export_csv    = true;   % 是否导出候选表 CSV(敏感性重跑时关闭)
end
