-- The host exports its fixed compact controls before launch. Keep it separate
-- from SavedVariables: moving a spell or changing language never erases it.
local _, ns = ...
local Layout = {}
ns.TouchLayout = Layout

function Layout.Active()
    local data = ns.HostTouchLayout
    if not data or data.version ~= 1 or (ns.DuoLayout and ns.DuoLayout()) then return false end
    for _, side in ipairs({ "left", "right" }) do
        for _, key in ipairs({ "X", "Y", "Radius", "MinX", "MaxX", "MinY", "MaxY" }) do
            local v = data[side .. key]
            if type(v) ~= "number" or v ~= v or v < 0 or v > 1 then return false end
        end
    end
    return type(data.bottom) == "number" and data.bottom >= 0 and data.bottom <= 1
end

function Layout.Stick(side, W, H)
    if not Layout.Active() then return end
    local d = ns.HostTouchLayout
    return W * d[side .. "X"], H * d[side .. "Y"], H * d[side .. "Radius"]
end

function Layout.Areas(W, H)
    if not Layout.Active() then return end
    local d, gap = ns.HostTouchLayout, 10
    return {
        { left = W * d.leftMaxX + gap, right = W * (1 - d.rightMinX) + gap,
          top = gap, bottom = H * d.bottom + gap },
        { left = gap, right = gap, top = gap,
          bottom = H * math.max(d.leftMaxY, d.rightMaxY, d.bottom) + gap },
    }
end
