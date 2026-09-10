function [D, V, flag, AB] = position_diameter(S, theta)
%POSITION_DIAMETER 问题1：交会定位区域直径（旋转卡壳求直径）
%   [D, V, flag, AB] = position_diameter(S, theta)
%
%   输入（两项，均为用户输入）：
%       S     - n×2 矩阵，每行是一个检测点坐标 (x,y)，单位：米
%       theta - n×1 向量，各检测点处测得的示向度（方位角，单位：度，范围 [0,360)）
%
%   输出：
%       D    - 定位区域（凸多边形）的直径，单位：米
%       V    - 定位区域顶点（逆时针排列，m×2 矩阵）
%       flag - 状态：1=区域有界（直径有效），0=区域无界（直径无意义）
%       AB   - 直径两端点（2×2 矩阵），可选输出
%
%   方法（对应问题一的解法）：
%       每个检测点 S_i 确定一个张角 2*tau 的视界楔形
%           W_i = { P : |wrap(arg(P - S_i) - theta_i)| <= tau }
%       定位区域 R = 所有楔形之交，是一个凸多边形；
%       其直径 = 凸多边形顶点对距离的最大值（旋转卡壳 O(m) 求得）。

    tau = 1;        % 测向误差界（度）
    M   = 10000;    % 裁剪用包围盒半边长（米），可自行调整

    n = size(S, 1);
    if ~(n >= 1 && size(S,2) == 2 && numel(theta) == n)
        error('输入尺寸不匹配：S 应为 n×2，theta 应为 n×1');
    end

    % ---- 0. 有界性判定（问题一：最小包围弧 > 2*tau 才有界）----
    [flag, arc] = boundedness(theta, tau);
    if ~flag
        warning('示向度最小包围弧 = %.2f° <= 2*tau = %.0f°，定位区域无界，直径无意义。', arc, 2*tau);
    end

    % ---- 1. 用包围盒初始化多边形 ----
    V = [-M -M; M -M; M M; -M M];

    % ---- 2. 逐个楔形裁剪（每个楔形 = 两条半平面 n'*P <= c）----
    for i = 1:n
        [n1, c1, n2, c2] = wedge_halfplanes(S(i,:), theta(i), tau);
        V = clip_halfplane(V, n1, c1);
        V = clip_halfplane(V, n2, c2);
        if isempty(V)
            flag = 0; D = 0; V = []; AB = []; return;
        end
    end

    % ---- 3. 取凸包（去掉共线/重复点，得到规范凸多边形）----
    V = convex_hull(V);

    % ---- 4. 旋转卡壳求直径 ----
    [D, AB] = polygon_diameter(V);

    % ---- 5. 若区域触及包围盒，说明实际无界 ----
    if flag && (max(abs(V(:))) > 0.99 * M)
        flag = 0;
        warning('区域触及包围盒边界，可能无界，直径结果不可靠。');
    end
end

%% ======================= 子函数 =======================

function [n1, c1, n2, c2] = wedge_halfplanes(S, th, tau)
% 楔形 W(S,th,tau) 的两条边界半平面  n'*P <= c
% 边界1：方向角 th-tau 的射线（外法向 n1）
% 边界2：方向角 th+tau 的射线（外法向 n2）
    a1 = (th - tau) * pi / 180;
    a2 = (th + tau) * pi / 180;
    n1 = [sin(a1), -cos(a1)];     % 边界 th-tau 的外法向
    c1 = n1 * S(:);
    n2 = [-sin(a2), cos(a2)];     % 边界 th+tau 的外法向
    c2 = n2 * S(:);
end

function P = clip_halfplane(P, n, c)
% Sutherland-Hodgman 半平面裁剪：保留 n'*p <= c
    if isempty(P), return; end
    m = size(P, 1);
    Q = zeros(0, 2);
    for i = 1:m
        j  = mod(i, m) + 1;
        pi_ = P(i, :);
        pj  = P(j, :);
        fi = n * pi_' - c;
        fj = n * pj'  - c;
        if fi <= 0
            Q(end+1, :) = pi_;                  %#ok<AGROW>
        end
        if (fi <= 0) ~= (fj <= 0)
            t = fi / (fi - fj);
            Q(end+1, :) = pi_ + t * (pj - pi_); %#ok<AGROW>
        end
    end
    P = Q;
end

function H = convex_hull(P)
% 单调链凸包（返回逆时针顶点）
    if size(P, 1) <= 2, H = P; return; end
    P = unique(P, 'rows');
    P = sortrows(P, [1 2]);

    lower = zeros(0, 2);
    for i = 1:size(P, 1)
        while size(lower, 1) >= 2 && ...
              cross2(lower(end,:) - lower(end-1,:), P(i,:) - lower(end-1,:)) <= 0
            lower(end, :) = [];
        end
        lower(end+1, :) = P(i, :);             %#ok<AGROW>
    end

    upper = zeros(0, 2);
    for i = size(P, 1):-1:1
        while size(upper, 1) >= 2 && ...
              cross2(upper(end,:) - upper(end-1,:), P(i,:) - upper(end-1,:)) <= 0
            upper(end, :) = [];
        end
        upper(end+1, :) = P(i, :);             %#ok<AGROW>
    end

    H = [lower(1:end-1, :); upper(1:end-1, :)];
end

function [D, AB] = polygon_diameter(H)
%POLYGON_DIAMETER 旋转卡壳求凸多边形直径 O(m)
%   输入 H: 逆时针凸多边形顶点 (m×2)
%   输出 D: 直径（米）；AB: 直径两端点 (2×2)
%
%   原理：凸多边形上任意两点距离的最大值（直径）必由一对“对踵点”取得；
%   旋转卡壳沿凸包边推进对踵点，每步只移动 O(1)，总计 O(m)。
    m = size(H, 1);
    if m < 2
        D = 0; AB = zeros(0, 2); return;
    end
    if m == 2
        D = norm(H(1,:) - H(2,:)); AB = H; return;
    end

    D  = 0;
    AB = [H(1,:); H(1,:)];
    j  = 2;                            % 对踵点指针（1-based），从第 2 个顶点开始
    for i = 1:m
        ni = mod(i, m) + 1;            % 边 (i, ni) 的另一个端点
        % 推进 j，直到三角形 (H(i),H(ni),H(j)) 面积最大，
        % 即找到边 (i,ni) 的对踵点（面积函数在凸多边形上先增后减）
        while tri_area(H, i, ni, mod(j, m) + 1) > tri_area(H, i, ni, j)
            j = mod(j, m) + 1;
        end
        % 候选直径：边两端点 i、ni 分别到对踵点 j 的距离
        d1 = norm(H(i,:)  - H(j,:));
        if d1 > D
            D = d1; AB = [H(i,:); H(j,:)];
        end
        d2 = norm(H(ni,:) - H(j,:));
        if d2 > D
            D = d2; AB = [H(ni,:); H(j,:)];
        end
    end
end

function a = tri_area(H, i, j, k)
% 三角形 (H(i),H(j),H(k)) 面积的两倍（叉积绝对值）
    a = abs(cross2(H(j,:) - H(i,:), H(k,:) - H(i,:)));
end

function [flag, arc] = boundedness(theta, tau)
% 有界性判定：最小包围弧 > 2*tau 则定位区域有界
    th = sort(mod(theta(:), 360));
    n = numel(th);
    if n < 2
        flag = false; arc = 360; return;
    end
    gmax = 0;
    for i = 1:n
        gap = mod(th(mod(i,n)+1) - th(i), 360);
        gmax = max(gmax, gap);
    end
    if gmax == 0
        arc = 0;     % 所有示向度相同 -> 退化为单锥，无界
    else
        arc = 360 - gmax;
    end
    flag = arc > 2*tau;
end

function z = cross2(a, b)
    z = a(1)*b(2) - a(2)*b(1);
end
