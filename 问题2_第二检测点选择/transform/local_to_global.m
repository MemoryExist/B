function G = local_to_global(G_local, S1_global, bearing_rad)
%LOCAL_TO_GLOBAL 局部坐标 → 全局坐标
%   局部: S1=(0,0), 第一次实际示向度沿局部 x 轴正方向
%   S1_global: 第一检测点全局坐标(2×1); bearing_rad: 第一次实际示向度(全局方位角, rad)
%   G = S1_global + R(bearing)·G_local
c = cos(bearing_rad); s = sin(bearing_rad);
G = S1_global(:) + [c, -s; s, c] * G_local(:);
end
