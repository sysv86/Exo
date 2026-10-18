local M = {}

local TAU, PI = math.pi * 2.0, math.pi
local FRAC_PI_2 = PI * 0.5

local function lerp(a, b, t)
    return a * (1.0 - t) + b * t
end

local hypot = math.hypot or function(x, y) return math.sqrt(x * x + y * y) end


local Cubic = {}
Cubic.__index = Cubic

local function cubic(pts)
    return setmetatable({ pts = pts }, Cubic)
end

local function straight_line(x0, y0, x1, y1)
    return cubic({
        x0, y0,
        lerp(x0, x1, 1 / 3), lerp(y0, y1, 1 / 3),
        lerp(x0, x1, 2 / 3), lerp(y0, y1, 2 / 3),
        x1, y1,
    })
end

local function circular_arc(cx, cy, x0, y0, x1, y1)
    local p0x, p0y = x0 - cx, y0 - cy
    local p1x, p1y = x1 - cx, y1 - cy
    local d0 = hypot(p0x, p0y)
    local d1 = hypot(p1x, p1y)
    if d0 < 1e-6 or d1 < 1e-6 then
        return straight_line(x0, y0, x1, y1)
    end
    local d0x, d0y = p0x / d0, p0y / d0
    local d1x, d1y = p1x / d1, p1y / d1
    local n0x, n0y = -d0y, d0x
    local n1x, n1y = -d1y, d1x
    local cos_half = d0x * d1x + d0y * d1y
    if cos_half > 0.999 then
        return straight_line(x0, y0, x1, y1)
    end
    local radius = d0
    local omc = 1.0 - cos_half
    local s = math.sqrt(2.0 * omc)
    local r = math.sqrt(math.max(0.0, 1.0 - cos_half * cos_half))
    local clockwise = (n0x * p1x + n0y * p1y) >= 0.0 and 1.0 or -1.0
    local ctl = radius * (4.0 / 3.0) * (s - r) / omc * clockwise
    return cubic({
        x0, y0,
        x0 + n0x * ctl, y0 + n0y * ctl,
        x1 - n1x * ctl, y1 - n1y * ctl,
        x1, y1,
    })
end

function Cubic:point_on_curve(t)
    local u = 1.0 - t
    local p = self.pts
    local w0 = u * u * u
    local w1 = 3.0 * t * u * u
    local w2 = 3.0 * t * t * u
    local w3 = t * t * t
    return
        p[1] * w0 + p[3] * w1 + p[5] * w2 + p[7] * w3,
        p[2] * w0 + p[4] * w1 + p[6] * w2 + p[8] * w3
end

function Cubic:bounds()
    local p = self.pts
    local min_x = math.min(p[1], p[3], p[5], p[7])
    local min_y = math.min(p[2], p[4], p[6], p[8])
    local max_x = math.max(p[1], p[3], p[5], p[7])
    local max_y = math.max(p[2], p[4], p[6], p[8])
    return min_x, min_y, max_x, max_y
end

function Cubic:transform(fn)
    local p = self.pts
    local x0, y0 = fn(p[1], p[2])
    local x1, y1 = fn(p[3], p[4])
    local x2, y2 = fn(p[5], p[6])
    local x3, y3 = fn(p[7], p[8])
    return cubic({ x0, y0, x1, y1, x2, y2, x3, y3 })
end


local RoundedCorner = {}
RoundedCorner.__index = RoundedCorner

local function rounded_corner(p0, p1, p2, rounding)
    local v01x, v01y = p0.x - p1.x, p0.y - p1.y
    local v21x, v21y = p2.x - p1.x, p2.y - p1.y
    local d01 = hypot(v01x, v01y)
    local d21 = hypot(v21x, v21y)
    if d01 > 0.0 and d21 > 0.0 then
        local d1x, d1y = v01x / d01, v01y / d01
        local d2x, d2y = v21x / d21, v21y / d21
        local cos_angle = d1x * d2x + d1y * d2y
        local sin_angle = math.sqrt(math.max(0.0, 1.0 - cos_angle * cos_angle))
        local expected_round_cut = 0.0
        if sin_angle > 1e-3 then
            expected_round_cut = rounding.radius * (cos_angle + 1.0) / sin_angle
        end
        return setmetatable({
            p0 = p0, p1 = p1, p2 = p2,
            d1 = { x = d1x, y = d1y },
            d2 = { x = d2x, y = d2y },
            corner_radius = rounding.radius,
            smoothing = rounding.smoothing,
            expected_round_cut = expected_round_cut,
        }, RoundedCorner)
    end
    return setmetatable({
        p0 = p0, p1 = p1, p2 = p2,
        d1 = { x = 0.0, y = 0.0 },
        d2 = { x = 0.0, y = 0.0 },
        corner_radius = 0.0,
        smoothing = 0.0,
        expected_round_cut = 0.0,
    }, RoundedCorner)
end

function RoundedCorner:expected_cut()
    return (1.0 + self.smoothing) * self.expected_round_cut
end

function RoundedCorner:calc_smoothing(allowed_cut)
    local exp_cut = self:expected_cut()
    if allowed_cut > exp_cut then
        return self.smoothing
    elseif allowed_cut > self.expected_round_cut then
        return self.smoothing * (allowed_cut - self.expected_round_cut)
            / (exp_cut - self.expected_round_cut)
    end
    return 0.0
end

local function line_intersection(p0, d0, p1, d1)
    local n1x, n1y = -d1.y, d1.x
    local den = d0.x * n1x + d0.y * n1y
    if math.abs(den) < 1e-5 then
        return nil
    end
    local num = (p1.x - p0.x) * n1x + (p1.y - p0.y) * n1y
    if math.abs(den) < 1e-5 * math.abs(num) then
        return nil
    end
    local s = num / den
    return { x = p0.x + d0.x * s, y = p0.y + d0.y * s }
end

local function compute_flanking_curve(
    p1, p0, p2, d1, d2,
    actual_round_cut, actual_smoothing_val,
    circle_seg_inter, other_circle_seg_inter, circle_center, actual_r)
    local sdx, sdy = p0.x - p1.x, p0.y - p1.y
    local sl = hypot(sdx, sdy)
    if sl < 1e-6 then
        sdx, sdy = 0.0, 0.0
    else
        sdx, sdy = sdx / sl, sdy / sl
    end
    local curve_start = {
        x = p1.x + sdx * actual_round_cut * (1.0 + actual_smoothing_val),
        y = p1.y + sdy * actual_round_cut * (1.0 + actual_smoothing_val),
    }
    local pmx = (circle_seg_inter.x + other_circle_seg_inter.x) * 0.5
    local pmy = (circle_seg_inter.y + other_circle_seg_inter.y) * 0.5
    local px = lerp(circle_seg_inter.x, pmx, actual_smoothing_val)
    local py = lerp(circle_seg_inter.y, pmy, actual_smoothing_val)
    local pdx, pdy = px - circle_center.x, py - circle_center.y
    local pd = hypot(pdx, pdy)
    if pd < 1e-6 then
        pdx, pdy = 0.0, 0.0
    else
        pdx, pdy = pdx / pd, pdy / pd
    end
    local curve_end = {
        x = circle_center.x + pdx * actual_r,
        y = circle_center.y + pdy * actual_r,
    }
    local tanx, tany = -(curve_end.y - circle_center.y), curve_end.x - circle_center.x
    local side_dir = { x = sdx, y = sdy }
    local anchor_end = line_intersection(p0, side_dir, curve_end, { x = tanx, y = tany })
        or circle_seg_inter
    local anchor_start = {
        x = (curve_start.x + anchor_end.x * 2.0) / 3.0,
        y = (curve_start.y + anchor_end.y * 2.0) / 3.0,
    }
    return cubic({
        curve_start.x, curve_start.y,
        anchor_start.x, anchor_start.y,
        anchor_end.x, anchor_end.y,
        curve_end.x, curve_end.y,
    })
end

function RoundedCorner:get_cubics(allowed_cut0, allowed_cut1)
    local allowed_cut = math.min(allowed_cut0, allowed_cut1)
    if self.expected_round_cut < 1e-5 or allowed_cut < 1e-5 or self.corner_radius < 1e-5 then
        return { straight_line(self.p1.x, self.p1.y, self.p1.x, self.p1.y) }
    end
    local actual_round_cut = math.min(allowed_cut, self.expected_round_cut)
    local actual_smoothing0 = self:calc_smoothing(allowed_cut0)
    local actual_smoothing1 = self:calc_smoothing(allowed_cut1)
    local actual_r = self.corner_radius * actual_round_cut / self.expected_round_cut
    local center_dist = hypot(actual_r, actual_round_cut)
    local bx = (self.d1.x + self.d2.x) * 0.5
    local by = (self.d1.y + self.d2.y) * 0.5
    local bl = hypot(bx, by)
    if bl < 1e-6 then
        bx, by = 0.0, 0.0
    else
        bx, by = bx / bl, by / bl
    end
    local center = {
        x = self.p1.x + bx * center_dist,
        y = self.p1.y + by * center_dist,
    }
    local circle_inter0 = {
        x = self.p1.x + self.d1.x * actual_round_cut,
        y = self.p1.y + self.d1.y * actual_round_cut,
    }
    local circle_inter2 = {
        x = self.p1.x + self.d2.x * actual_round_cut,
        y = self.p1.y + self.d2.y * actual_round_cut,
    }
    local flanking0 = compute_flanking_curve(
        self.p1, self.p0, self.p2, self.d1, self.d2,
        actual_round_cut, actual_smoothing0,
        circle_inter0, circle_inter2, center, actual_r)
    local flanking2_rev = compute_flanking_curve(
        self.p1, self.p2, self.p0, self.d2, self.d1,
        actual_round_cut, actual_smoothing1,
        circle_inter2, circle_inter0, center, actual_r)
    local f2 = flanking2_rev.pts
    local flanking2 = cubic({ f2[7], f2[8], f2[5], f2[6], f2[3], f2[4], f2[1], f2[2] })
    local arc = circular_arc(
        center.x, center.y,
        flanking0.pts[7], flanking0.pts[8],
        flanking2.pts[1], flanking2.pts[2])
    return { flanking0, arc, flanking2 }
end


local RoundedPolygon = {}
RoundedPolygon.__index = RoundedPolygon

local function polygon(cubics, center)
    return setmetatable({ cubics = cubics, center = center or { x = 0.0, y = 0.0 } }, RoundedPolygon)
end

function RoundedPolygon.from_vertices(vertices, center_x, center_y, per_vertex_rounding, default_rounding)
    local n = #vertices / 2
    local corners = {}
    for i = 0, n - 1 do
        local r = (per_vertex_rounding and per_vertex_rounding[i + 1]) or default_rounding
        local prev_i = (i + n - 1) % n
        local next_i = (i + 1) % n
        corners[i] = rounded_corner(
            { x = vertices[prev_i * 2 + 1], y = vertices[prev_i * 2 + 2] },
            { x = vertices[i * 2 + 1], y = vertices[i * 2 + 2] },
            { x = vertices[next_i * 2 + 1], y = vertices[next_i * 2 + 2] },
            r)
    end
    local cut_adjusts = {}
    for i = 0, n - 1 do
        local rc0 = corners[i]
        local rc1 = corners[(i + 1) % n]
        local r_req = rc0.expected_round_cut + rc1.expected_round_cut
        local s_req = rc0:expected_cut() + rc1:expected_cut()
        local next_i = (i + 1) % n
        local dx = vertices[i * 2 + 1] - vertices[next_i * 2 + 1]
        local dy = vertices[i * 2 + 2] - vertices[next_i * 2 + 2]
        local side_len = hypot(dx, dy)
        if r_req > side_len and r_req > 0.0 then
            cut_adjusts[i] = { side_len / r_req, 0.0 }
        elseif s_req > side_len and (s_req - r_req) > 0.0 then
            cut_adjusts[i] = { 1.0, (side_len - r_req) / (s_req - r_req) }
        else
            cut_adjusts[i] = { 1.0, 1.0 }
        end
    end
    local raw_cubics = {}
    local corner_cubics = {}
    for i = 0, n - 1 do
        local allowed0, allowed1 = 0.0, 0.0
        for delta = 0, 1 do
            local adj = cut_adjusts[(i + n - 1 + delta) % n]
            local rc = corners[i]
            local cut = rc.expected_round_cut * adj[1]
                + (rc:expected_cut() - rc.expected_round_cut) * adj[2]
            if delta == 0 then allowed0 = cut else allowed1 = cut end
        end
        corner_cubics[i] = corners[i]:get_cubics(allowed0, allowed1)
    end
    for i = 0, n - 1 do
        for _, c in ipairs(corner_cubics[i]) do
            raw_cubics[#raw_cubics + 1] = c
        end
        local last_c = corner_cubics[i][#corner_cubics[i]]
        local next_c = corner_cubics[(i + 1) % n][1]
        raw_cubics[#raw_cubics + 1] = straight_line(
            last_c.pts[7], last_c.pts[8], next_c.pts[1], next_c.pts[2])
    end
    local cubics = {}
    for _, c in ipairs(raw_cubics) do
        local p = c.pts
        if hypot(p[1] - p[7], p[2] - p[8]) >= 1e-5 then
            cubics[#cubics + 1] = c
        end
    end
    return polygon(cubics, { x = center_x or 0.0, y = center_y or 0.0 })
end

--- Generic regular polygon of `num_vertices` sides, optionally rounded.
function RoundedPolygon.regular(num_vertices, radius, center_x, center_y, rounding, per_vertex_rounding)
    local verts = {}
    for i = 0, num_vertices - 1 do
        local a = TAU * i / num_vertices
        verts[#verts + 1] = math.cos(a) * radius + center_x
        verts[#verts + 1] = math.sin(a) * radius + center_y
    end
    return RoundedPolygon.from_vertices(verts, center_x, center_y, per_vertex_rounding, rounding)
end

function RoundedPolygon.circle(num_vertices, radius, center_x, center_y)
    local r = radius / math.cos(PI / num_vertices)
    return RoundedPolygon.regular(num_vertices, r, center_x, center_y,
        { radius = radius, smoothing = 0.0 }, nil)
end

function RoundedPolygon.pill_star(num_vertices_per_radius, radius, inner_radius, rounding)
    local verts = {}
    local step = PI / num_vertices_per_radius
    for i = 0, num_vertices_per_radius - 1 do
        local a0 = 2.0 * step * i
        verts[#verts + 1] = math.cos(a0) * radius
        verts[#verts + 1] = math.sin(a0) * radius
        local a1 = step * (2 * i + 1)
        verts[#verts + 1] = math.cos(a1) * inner_radius
        verts[#verts + 1] = math.sin(a1) * inner_radius
    end
    return RoundedPolygon.from_vertices(verts, 0.0, 0.0, nil, rounding)
end

function RoundedPolygon.rectangle(width, height, rounding, per_vertex_rounding, center_x, center_y)
    local hw, hh = width * 0.5, height * 0.5
    local l, t = center_x - hw, center_y - hh
    local r, b = center_x + hw, center_y + hh
    return RoundedPolygon.from_vertices({ r, b, l, b, l, t, r, t },
        center_x, center_y, per_vertex_rounding, rounding)
end

function RoundedPolygon:transformed(fn)
    local cubics = {}
    for i, c in ipairs(self.cubics) do
        cubics[i] = c:transform(fn)
    end
    return polygon(cubics, (function(cx, cy) return { x = cx, y = cy } end)(fn(self.center.x, self.center.y)))
end

function RoundedPolygon:rotated(radians)
    local sn, cs = math.sin(radians), math.cos(radians)
    return self:transformed(function(x, y) return x * cs - y * sn, x * sn + y * cs end)
end

function RoundedPolygon:scaled(sx, sy)
    return self:transformed(function(x, y) return x * sx, y * sy end)
end

function RoundedPolygon:bounds()
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    for _, c in ipairs(self.cubics) do
        local a, b, c2, d = c:bounds()
        min_x = math.min(min_x, a)
        min_y = math.min(min_y, b)
        max_x = math.max(max_x, c2)
        max_y = math.max(max_y, d)
    end
    return min_x, min_y, max_x, max_y
end

function RoundedPolygon:normalized()
    local b0, b1, b2, b3 = self:bounds()
    local w = math.max(b2 - b0, 1e-5)
    local h = math.max(b3 - b1, 1e-5)
    local side = math.max(w, h)
    local ox = (side - w) * 0.5 - b0
    local oy = (side - h) * 0.5 - b1
    return self:transformed(function(x, y) return (x + ox) / side, (y + oy) / side end)
end

--- Samples 64 clockwise arc-length-parameterized points in `[-0.5, 0.5]`
--- centered at origin, starting from `-PI/2` (1:1 port of sample_contour_64).
function RoundedPolygon:sample_contour_64()
    local dense = {}
    for _, c in ipairs(self.cubics) do
        local p = c.pts
        local dx = p[7] - p[1]
        local dy = p[8] - p[2]
        local is_line = true
        if math.abs((p[3] - p[1]) * dy - (p[4] - p[2]) * dx) > 1e-4
            or math.abs((p[5] - p[1]) * dy - (p[6] - p[2]) * dx) > 1e-4 then
            is_line = false
        end
        local steps = is_line and 2 or 12
        for s = 0, steps - 1 do
            local x, y = c:point_on_curve(s / steps)
            dense[#dense + 1] = { x - 0.5, y - 0.5 }
        end
    end
    if #dense == 0 then
        return {}
    end
    local signed_area = 0.0
    for i = 1, #dense do
        local a = dense[i]
        local b = dense[(i % #dense) + 1]
        signed_area = signed_area + (a[1] * b[2] - b[1] * a[2])
    end
    if signed_area < 0.0 then
        local rev = {}
        for i = #dense, 1, -1 do
            rev[#rev + 1] = dense[i]
        end
        dense = rev
    end
    local best_i, best_diff = 1, math.huge
    for i = 1, #dense do
        local ang = math.atan(dense[i][2], dense[i][1])
        local diff = math.abs(ang - (-FRAC_PI_2))
        if diff < best_diff then
            best_i, best_diff = i, diff
        end
    end
    local rotated = {}
    for i = best_i, #dense do
        rotated[#rotated + 1] = dense[i]
    end
    for i = 1, best_i - 1 do
        rotated[#rotated + 1] = dense[i]
    end
    dense = rotated
    local n_d = #dense
    local sharp = {}
    for i = 1, n_d do
        local p_prev = dense[((i - 2 + n_d) % n_d) + 1]
        local p_curr = dense[i]
        local p_next = dense[(i % n_d) + 1]
        local v1x = p_curr[1] - p_prev[1]
        local v1y = p_curr[2] - p_prev[2]
        local v2x = p_next[1] - p_curr[1]
        local v2y = p_next[2] - p_curr[2]
        local l1 = hypot(v1x, v1y)
        local l2 = hypot(v2x, v2y)
        local is_sharp = false
        if l1 > 1e-5 and l2 > 1e-5 then
            local cos_a = (v1x * v2x + v1y * v2y) / (l1 * l2)
            is_sharp = cos_a < 0.85
        end
        sharp[i] = is_sharp
    end
    local cum = { 0.0 }
    for i = 1, n_d do
        local a = dense[i]
        local b = dense[(i % n_d) + 1]
        cum[#cum + 1] = cum[#cum] + hypot(b[1] - a[1], b[2] - a[2])
    end
    local total = math.max(cum[#cum], 1e-6)
    local step_arc = total / 64.0
    local out = {}
    local idx = 1
    for k = 0, 63 do
        local target = k * step_arc
        while idx + 1 <= #cum and cum[idx + 1] < target and idx < n_d do
            idx = idx + 1
        end
        local seg_len = (idx + 1 <= #cum) and (cum[idx + 1] - cum[idx]) or 0.0
        local t = (seg_len > 1e-6) and ((target - cum[idx]) / seg_len) or 0.0
        local i0 = ((idx - 1) % n_d) + 1
        local i1 = (idx % n_d) + 1
        if sharp[i0] and (target - cum[idx]) < step_arc * 0.55 then
            out[#out + 1] = { dense[i0][1], dense[i0][2] }
        elseif (idx + 1 <= #cum) and sharp[i1] and (cum[idx + 1] - target) <= step_arc * 0.55 then
            out[#out + 1] = { dense[i1][1], dense[i1][2] }
        else
            out[#out + 1] = { lerp(dense[i0][1], dense[i1][1], t), lerp(dense[i0][2], dense[i1][2], t) }
        end
    end
    return out
end


local UNROUNDED = { radius = 0.0, smoothing = 0.0 }

local function custom_polygon(pnr, reps, mirroring)
    local cx, cy = 0.5, 0.5
    local n = #pnr
    local pts = {}
    if mirroring then
        local angles, dists = {}, {}
        for i = 1, n do
            local dx = pnr[i].p.x - cx
            local dy = pnr[i].p.y - cy
            angles[i] = math.atan(dy, dx)
            dists[i] = hypot(dx, dy)
        end
        local r = reps * 2
        local section = TAU / r
        for it = 0, r - 1 do
            local even = (it % 2) == 0
            local base_ang = section * it
            for k = 1, n do
                local i = even and k or (n + 1 - k)
                if i > 1 or even then
                    local ang
                    if even then
                        ang = angles[i]
                    else
                        ang = section - angles[i] + 2.0 * angles[1]
                    end
                    local f = base_ang + ang
                    pts[#pts + 1] = {
                        p = { x = math.cos(f) * dists[i] + cx, y = math.sin(f) * dists[i] + cy },
                        r = pnr[i].r,
                    }
                end
            end
        end
    else
        local total = n * reps
        for i = 0, total - 1 do
            local idx = (i % n) + 1
            local rep = math.floor(i / n)
            local ang = rep * TAU / reps
            local dx = pnr[idx].p.x - cx
            local dy = pnr[idx].p.y - cy
            local sn, cs = math.sin(ang), math.cos(ang)
            pts[#pts + 1] = {
                p = { x = dx * cs - dy * sn + cx, y = dx * sn + dy * cs + cy },
                r = pnr[idx].r,
            }
        end
    end
    local verts, roundings = {}, {}
    for j, item in ipairs(pts) do
        verts[#verts + 1] = item.p.x
        verts[#verts + 1] = item.p.y
        roundings[#roundings + 1] = item.r
    end
    return RoundedPolygon.from_vertices(verts, cx, cy, roundings, UNROUNDED)
end

local function P(x, y, radius, smoothing)
    return { p = { x = x, y = y }, r = { radius = radius or 0.0, smoothing = smoothing or 0.0 } }
end


local SHAPE_BUILDERS = {
    Circle = function()
        return
        RoundedPolygon.circle(10, 0.5, 0.5, 0.5):normalized()
    end,

    Square = function()
        return
        RoundedPolygon.rectangle(1.0, 1.0, { radius = 0.3, smoothing = 0.0 }, nil, 0.5, 0.5)
        :normalized()
    end,

    Slanted = function()
        return
        custom_polygon({
        P(0.926, 0.97, 0.189, 0.811),
        P(-0.021, 0.967, 0.187, 0.057),
        },
        2,
        false)
        :normalized()
    end,

    Arch = function()
        return
        RoundedPolygon.regular(
        4,
        1.0,
        0.0,
        0.0,
        UNROUNDED,
        {
        { radius = 1.0, smoothing = 0.0 },
        { radius = 1.0, smoothing = 0.0 },
        { radius = 0.2, smoothing = 0.0 },
        { radius = 0.2, smoothing = 0.0 },
        })
        :rotated(math.rad(-135.0))
        :normalized()
    end,

    SemiCircle = function()
        return
        RoundedPolygon.rectangle(
        1.6,
        1.0,
        UNROUNDED,
        {
        { radius = 0.2, smoothing = 0.0 },
        { radius = 0.2, smoothing = 0.0 },
        { radius = 1.0, smoothing = 0.0 },
        { radius = 1.0, smoothing = 0.0 },
        },
        0.0,
        0.0)
        :normalized()
    end,

    Oval = function()
        return
        RoundedPolygon.circle(8, 1.0, 0.0, 0.0)
        :scaled(1.0, 0.64)
        :rotated(math.rad(-45.0))
        :normalized()
    end,

    Pill = function()
        return
        custom_polygon({
        P(0.961, 0.039, 0.426, 0.0),
        P(1.001, 0.428, 0.0, 0.0),
        P(1.0, 0.609, 1.0, 0.0),
        },
        2,
        true)
        :normalized()
    end,

    Triangle = function()
        return
        RoundedPolygon.regular(3, 1.0, 0.0, 0.0, { radius = 0.2, smoothing = 0.0 }, nil)
        :rotated(-FRAC_PI_2)
        :normalized()
    end,

    Arrow = function()
        return
        custom_polygon({
        P(0.5, 0.892, 0.313, 0.0),
        P(-0.216, 1.05, 0.207, 0.0),
        P(0.499, -0.16, 0.215, 1.0),
        P(1.225, 1.06, 0.211, 0.0),
        },
        1,
        false)
        :normalized()
    end,

    Fan = function()
        return
        custom_polygon({
        P(1.004, 1.0, 0.148, 0.417),
        P(0.0, 1.0, 0.151, 0.0),
        P(0.0, -0.003, 0.148, 0.0),
        P(0.978, 0.02, 0.803, 0.0),
        },
        1,
        false)
        :normalized()
    end,

    Diamond = function()
        return
        custom_polygon({
        P(0.5, 1.096, 0.151, 0.524),
        P(0.04, 0.5, 0.159, 0.0),
        },
        2,
        false)
        :normalized()
    end,

    ClamShell = function()
        return
        custom_polygon({
        P(0.171, 0.841, 0.159, 0.0),
        P(-0.02, 0.5, 0.14, 0.0),
        P(0.17, 0.159, 0.159, 0.0),
        },
        2,
        false)
        :normalized()
    end,

    Pentagon = function()
        return
        custom_polygon({
        P(0.5, -0.009, 0.172, 0.0),
        P(1.03, 0.365, 0.164, 0.0),
        P(0.828, 0.97, 0.169, 0.0),
        },
        1,
        true)
        :normalized()
    end,

    Gem = function()
        return
        custom_polygon({
        P(0.499, 1.023, 0.241, 0.778),
        P(-0.005, 0.792, 0.208, 0.0),
        P(0.073, 0.258, 0.228, 0.0),
        P(0.433, 0.0, 0.491, 0.0),
        },
        1,
        true)
        :normalized()
    end,

    Sunny = function()
        return
        RoundedPolygon.pill_star(8, 1.0, 0.8, { radius = 0.15, smoothing = 0.0 }):normalized()
    end,

    VerySunny = function()
        return
        custom_polygon({
        P(0.5, 1.08, 0.085, 0.0),
        P(0.358, 0.843, 0.085, 0.0),
        },
        8,
        false)
        :normalized()
    end,

    Cookie4Sided = function()
        return
        custom_polygon({
        P(1.237, 1.236, 0.258, 0.0),
        P(0.5, 0.918, 0.233, 0.0),
        },
        4,
        false)
        :normalized()
    end,

    Cookie6Sided = function()
        return
        custom_polygon({
        P(0.723, 0.884, 0.394, 0.0),
        P(0.5, 1.099, 0.398, 0.0),
        },
        6,
        false)
        :normalized()
    end,

    Cookie7Sided = function()
        return
        RoundedPolygon.pill_star(7, 1.0, 0.75, { radius = 0.5, smoothing = 0.0 })
        :rotated(-FRAC_PI_2)
        :normalized()
    end,

    Cookie9Sided = function()
        return
        RoundedPolygon.pill_star(9, 1.0, 0.8, { radius = 0.5, smoothing = 0.0 })
        :rotated(-FRAC_PI_2)
        :normalized()
    end,

    Cookie12Sided = function()
        return
        RoundedPolygon.pill_star(12, 1.0, 0.8, { radius = 0.5, smoothing = 0.0 })
        :rotated(-FRAC_PI_2)
        :normalized()
    end,

    Clover4Leaf = function()
        return
        custom_polygon({
        P(0.5, 0.074, 0.0, 0.0),
        P(0.725, -0.099, 0.476, 0.0),
        },
        4,
        true)
        :normalized()
    end,

    Clover8Leaf = function()
        return
        custom_polygon({
        P(0.5, 0.036, 0.0, 0.0),
        P(0.758, -0.101, 0.209, 0.0),
        },
        8,
        false)
        :normalized()
    end,

    Burst = function()
        return
        custom_polygon({
        P(0.5, -0.006, 0.006, 0.0),
        P(0.592, 0.158, 0.006, 0.0),
        },
        12,
        false)
        :normalized()
    end,

    SoftBurst = function()
        return
        custom_polygon({
        P(0.193, 0.277, 0.053, 0.0),
        P(0.176, 0.055, 0.053, 0.0),
        },
        10,
        false)
        :normalized()
    end,

    Boom = function()
        return
        custom_polygon({
        P(0.457, 0.296, 0.007, 0.0),
        P(0.5, -0.051, 0.007, 0.0),
        },
        15,
        false)
        :normalized()
    end,

    SoftBoom = function()
        return
        custom_polygon({
        P(0.733, 0.454, 0.0, 0.0),
        P(0.839, 0.437, 0.532, 0.0),
        P(0.949, 0.449, 0.439, 1.0),
        P(0.998, 0.478, 0.174, 0.0),
        },
        16,
        true)
        :normalized()
    end,

    Flower = function()
        return
        custom_polygon({
        P(0.37, 0.187, 0.0, 0.0),
        P(0.416, 0.049, 0.381, 0.0),
        P(0.479, 0.001, 0.095, 0.0),
        },
        8,
        true)
        :normalized()
    end,

    Puffy = function()
        return
        custom_polygon({
        P(0.5, 0.053, 0.0, 0.0),
        P(0.545, -0.04, 0.405, 0.0),
        P(0.67, -0.035, 0.426, 0.0),
        P(0.717, 0.066, 0.574, 0.0),
        P(0.722, 0.128, 0.0, 0.0),
        P(0.777, 0.002, 0.36, 0.0),
        P(0.914, 0.149, 0.66, 0.0),
        P(0.926, 0.289, 0.66, 0.0),
        P(0.881, 0.346, 0.0, 0.0),
        P(0.94, 0.344, 0.126, 0.0),
        P(1.003, 0.437, 0.255, 0.0),
        },
        2,
        true)
        :scaled(1.0, 0.742)
        :normalized()
    end,

    PuffyDiamond = function()
        return
        custom_polygon({
        P(0.87, 0.13, 0.146, 0.0),
        P(0.818, 0.357, 0.0, 0.0),
        P(1.0, 0.332, 0.853, 0.0),
        },
        4,
        true)
        :normalized()
    end,

    Ghostish = function()
        return
        custom_polygon({
        P(0.5, 0.0, 1.0, 0.0),
        P(1.0, 0.0, 1.0, 0.0),
        P(1.0, 1.14, 0.254, 0.106),
        P(0.575, 0.906, 0.253, 0.0),
        },
        1,
        true)
        :normalized()
    end,

    PixelCircle = function()
        return
        custom_polygon({
        P(0.5, 0.0, 0.0, 0.0),
        P(0.704, 0.0, 0.0, 0.0),
        P(0.704, 0.065, 0.0, 0.0),
        P(0.843, 0.065, 0.0, 0.0),
        P(0.843, 0.148, 0.0, 0.0),
        P(0.926, 0.148, 0.0, 0.0),
        P(0.926, 0.296, 0.0, 0.0),
        P(1.0, 0.296, 0.0, 0.0),
        },
        2,
        true)
        :normalized()
    end,

    PixelTriangle = function()
        return
        custom_polygon({
        P(0.11, 0.5, 0.0, 0.0),
        P(0.113, 0.0, 0.0, 0.0),
        P(0.287, 0.0, 0.0, 0.0),
        P(0.287, 0.087, 0.0, 0.0),
        P(0.421, 0.087, 0.0, 0.0),
        P(0.421, 0.17, 0.0, 0.0),
        P(0.56, 0.17, 0.0, 0.0),
        P(0.56, 0.265, 0.0, 0.0),
        P(0.674, 0.265, 0.0, 0.0),
        P(0.675, 0.344, 0.0, 0.0),
        P(0.789, 0.344, 0.0, 0.0),
        P(0.789, 0.439, 0.0, 0.0),
        P(0.888, 0.439, 0.0, 0.0),
        },
        1,
        true)
        :normalized()
    end,

    Bun = function()
        return
        custom_polygon({
        P(0.796, 0.5, 0.0, 0.0),
        P(0.853, 0.518, 1.0, 0.0),
        P(0.992, 0.631, 1.0, 0.0),
        P(0.968, 1.0, 1.0, 0.0),
        },
        2,
        true)
        :normalized()
    end,

    Heart = function()
        return
        custom_polygon({
        P(0.5, 0.268, 0.016, 0.0),
        P(0.792, -0.066, 0.958, 0.0),
        P(1.064, 0.276, 1.0, 0.0),
        P(0.501, 0.946, 0.129, 0.0),
        },
        1,
        true)
        :normalized()
    end,
}

M.LOADING_SEQUENCE = { "SoftBurst", "Cookie9Sided", "Pentagon", "Pill", "Sunny", "Cookie4Sided", "Oval" }

M.ALL = {
    "Circle", "Square", "Slanted", "Arch", "SemiCircle", "Oval", "Pill",
    "Triangle", "Arrow", "Fan", "Diamond", "ClamShell", "Pentagon", "Gem",
    "Sunny", "VerySunny", "Cookie4Sided", "Cookie6Sided", "Cookie7Sided",
    "Cookie9Sided", "Cookie12Sided", "Clover4Leaf", "Clover8Leaf", "Burst",
    "SoftBurst", "Boom", "SoftBoom", "Flower", "Puffy", "PuffyDiamond",
    "Ghostish", "PixelCircle", "PixelTriangle", "Bun", "Heart",
}

M.LOADING_SEQUENCE = { "SoftBurst", "Cookie9Sided", "Pentagon", "Pill", "Sunny", "Cookie4Sided", "Oval" }

local contour_cache = {}

--- 64 clockwise contour points in [-0.5, 0.5] centered at origin.
---@param shape string
---@return table
function M.contour(shape)
    if not contour_cache[shape] then
        local builder = SHAPE_BUILDERS[shape]
        if not builder then
            error("m3components.shapes: unknown shape '" .. tostring(shape) .. "'", 2)
        end
        contour_cache[shape] = builder():sample_contour_64()
    end
    return contour_cache[shape]
end

M._debug = function() return RoundedPolygon, custom_polygon, SHAPE_BUILDERS end

return M
