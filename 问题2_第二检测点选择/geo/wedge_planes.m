function [n1, c1, n2, c2] = wedge_planes(P, beta, half)
%WEDGE_PLANES 楔形 W(P; beta, half) 的两条边界半平面 n'*x <= c
%   楔形 = { G : arg(G-P) ∈ [beta-half, beta+half] }(圆周意义, 前向楔形)
%   输入 beta 可为未卷绕角度(rad); sin/cos 具周期性, 自动处理 0/360° 跨越
%   边界1(方向 beta-half): sin(beta-half)*(u-x) - cos(beta-half)*(v-y) <= 0
%   边界2(方向 beta+half): -sin(beta+half)*(u-x) + cos(beta+half)*(v-y) <= 0
a1 = beta - half;
a2 = beta + half;
n1 = [ sin(a1); -cos(a1)];
n2 = [-sin(a2);  cos(a2)];
c1 = n1' * P(:);
c2 = n2' * P(:);
end
