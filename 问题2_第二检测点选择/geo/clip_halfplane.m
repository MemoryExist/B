function poly = clip_halfplane(poly, n, c)
%CLIP_HALFPLANE Sutherland-Hodgman 半平面裁剪: 保留 n'*x <= c 的部分
%   输入/输出 poly: 2×m 顶点列(逆时针开链); n: 2×1 法向量; c: 标量
%   空或退化(<3 顶点)返回 2×0
if size(poly, 2) < 3
    poly = zeros(2, 0);
    return;
end
m = size(poly, 2);
Q = zeros(2, m + 1);
cnt = 0;
prev = poly(:, m);
dprev = n' * prev - c;
for i = 1:m
    cur = poly(:, i);
    dcur = n' * cur - c;
    if dprev <= 0
        cnt = cnt + 1; Q(:, cnt) = prev;
        if dcur > 0
            t = dprev / (dprev - dcur);
            cnt = cnt + 1; Q(:, cnt) = prev + t * (cur - prev);
        end
    elseif dcur <= 0
        t = dprev / (dprev - dcur);
        cnt = cnt + 1; Q(:, cnt) = prev + t * (cur - prev);
    end
    prev = cur; dprev = dcur;
end
poly = Q(:, 1:cnt);
if cnt < 3
    poly = zeros(2, 0);
end
end
