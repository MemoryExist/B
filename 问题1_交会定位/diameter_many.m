function D = diameter_many(V)
%DIAMETER_MANY 批量计算多个凸多边形的直径（向量化，R2016b+ 隐式扩展）
%   D = diameter_many(V)
%
%   输入 V: 1×P cell 数组，V{p} 为第 p 个多边形的顶点（m_p×2，逆时针）
%   输出 D: P×1 各多边形的直径（米）
%
%   原理：凸多边形直径 = 顶点对最大距离。
%   顶点少、多边形多时，瓶颈是逐多边形循环；本函数把所有多边形堆成三维数组，
%   用隐式扩展一次性算完所有顶点对距离，全程向量化（仅堆叠一步有循环）。

    P    = numel(V);
    mmax = max(cellfun(@(v) size(v,1), V));

    % 堆成 mmax×2×P 三维数组，缺省顶点用 NaN 填充
    X = NaN(mmax, 2, P);
    for p = 1:P
        X(1:size(V{p},1), :, p) = V{p};
    end

    % 所有顶点对 (i,j) 的坐标差：mmax×mmax×P（隐式扩展，无双重循环）
    dx = X(:,1,:) - permute(X(:,1,:), [2 1 3]);   % x_i - x_j
    dy = X(:,2,:) - permute(X(:,2,:), [2 1 3]);   % y_i - y_j
    D2 = dx.^2 + dy.^2;                           % 所有顶点对平方距离

    D2(isnan(D2)) = 0;        % NaN（补位处）置 0，不影响取最大值

    D = sqrt(max(D2, [], [1 2]));   % 1×1×P
    D = squeeze(D);                 % P×1
end
