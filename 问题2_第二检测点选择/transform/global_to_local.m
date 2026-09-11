function G = global_to_local(G_global, S1_global, bearing_rad)
%GLOBAL_TO_LOCAL 全局坐标 → 局部坐标(local_to_global 的逆)
c = cos(bearing_rad); s = sin(bearing_rad);
G = [c, -s; s, c]' * (G_global(:) - S1_global(:));
end
