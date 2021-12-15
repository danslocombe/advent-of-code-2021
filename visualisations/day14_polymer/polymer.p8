pico-8 cartridge // http://www.pico-8.com
version 32
__lua__

function flip_curve_bottom_left(curve, xoff, yoff, width, height)
    for i,p in pairs(curve) do
        local tmp = p.x
        local x1 = xoff + width
        p.x = x1 - (p.y - yoff)
        p.y = yoff + (x1 - tmp)

    end
    return curve
end

function flip_curve_bottom_right(curve, xoff, yoff, width, height)
    for i,p in pairs(curve) do
        local old_x = p.x
        p.x = xoff + (p.y - yoff)
        p.y = yoff + (old_x - xoff)
    end
    return curve
end

function make_curve(order, xoff, yoff, width, height)
    if order == 0 then
        local w4 = width / 4
        local h4 = height / 4
        return {
            {x = xoff + w4, y = yoff + 3*h4},
            {x = xoff + w4, y = yoff + h4},
            {x = xoff + 3*w4, y = yoff + h4},
            {x = xoff + 3*w4, y = yoff + 3*h4},
        }
    end

    local ps = {}

    local sub_order = order-1

    local bottom_left = make_curve(sub_order, xoff, yoff + height/2, width / 2, height / 2)
    flip_curve_bottom_left(bottom_left, xoff, yoff + height / 2, width / 2, height / 2)

    TableConcat(ps, bottom_left)
    TableConcat(ps, make_curve(sub_order, xoff, yoff, width / 2, height / 2))
    TableConcat(ps, make_curve(sub_order, xoff + width/2, yoff, width / 2, height / 2))

    local bottom_right = make_curve(sub_order, xoff + width/2, yoff + height/2, width / 2, height / 2)
    flip_curve_bottom_right(bottom_right, xoff + width / 2, yoff + height / 2, width / 2 , height / 2)

    TableConcat(ps, bottom_right)

    return ps
end

function TableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

curves = {}
for i=0,6 do
    add(curves, make_curve(i, 0, 0, 128, 128))
end

cur_curve = {}

tt = 220

aoc_string = "nncb"

rules = {}
rules["ch"] = "b"
rules["hh"] = "n"
rules["cb"] = "h"
rules["nh"] = "c"
rules["hb"] = "c"
rules["hc"] = "b"
rules["hn"] = "c"
rules["nn"] = "c"
rules["bh"] = "h"
rules["nc"] = "b"
rules["nb"] = "b"
rules["bn"] = "b"
rules["bb"] = "n"
rules["bc"] = "b"
rules["cc"] = "n"
rules["cn"] = "c"

function apply_rules(s, rules)
    printh("applying rules to " .. s)
    s_new = ""
    for i=1,#s-1 do
        s_new = s_new..sub(s, i, i)
        rule_name = sub(s, i, i+1)
        printh("Looking up rule " .. rule_name)
        s_new = s_new..rules[rule_name]
    end

    s_new = s_new..sub(s, #s,#s)
    printh("got " ..s_new)
    return s_new
end

function _update60()
    t += 1
    cur_curve = curves[1 + flr(t/tt)]
    next_curve = curves[2 + flr(t/tt)]
    t_since_iter += 1

    if t % 120 == 0 then
        aoc_string = apply_rules(aoc_string, rules)
        t_since_iter = 0
    end
end

t = 0
t_since_iter = 0

function lerp(p0, p1, k)
    return {
        x = (1-k)*p0.x + k * (p1.x),
        y = (1-k)*p0.y + k * (p1.y),
    }
end

function get_point(t, curve)
    local f_index = (#curve-1) * t
    local index = flr(f_index)
    local lerp_t = f_index - index
    local curve_size = #curve

    if index >= curve_size then
        return curve[curve_size]
    end

    local p_prev = curve[min(index + 1, curve_size)]
    local p_next = curve[min(index + 2, curve_size)]

    return lerp(p_prev, p_next, lerp_t)
end

function _draw()
    local radius = sin(t / 30)
    --cls(0)

    for i=0,256 do
        circ(rnd(128), rnd(128), 2, 1)
    end

    local prev = nil
    --local count = 0 + flr(t/4)
    local count = #aoc_string
    local curve_size = #cur_curve
    local zz = 40

    for i=0,(count-1) do
            p0 = get_point(i / (count-1), cur_curve)
            p1 = get_point(i / (count-1), next_curve)
            local at = flr(t/tt)
            local p = lerp(p0, p1, (t/tt) - at)

        if rnd() < 0.2 then
        else
            p.x += sin((t+i)/30)

            local col = ord(aoc_string, i)
            if col == nil then
                col = 0
            end

            col += 1

            if prev != nil then
                line(prev.x, prev.y, p.x, p.y, col)
            end

            --circ(p.x, p.y, 2 + radius, 7)
            local t_local = t_since_iter + 16 * i/count
            if (t_local) < zz then
                local rr = 5 * (zz-t_local) / zz
                circ(p.x, p.y, 2*rr, col)
                circ(p.x, p.y, rr, 7)
            end
        end
            prev = p
    end

    --prev = nil
    --for i,p in pairs(curve) do
    --    if prev != nil and rnd() < 0.2 then
    --        line(prev.x, prev.y, p.x, p.y, 4)
    --    end
    --    prev = p

    --    --circ(p.x, p.y, 2 + radius, 2)
    --end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
