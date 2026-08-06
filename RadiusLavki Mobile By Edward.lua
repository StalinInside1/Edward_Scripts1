script_name("Lavka Radius")
script_author("Edward")
require "lib.moonloader"
require "lib.sampfuncs"
local imgui = require "mimgui"
local encoding = require "encoding"
encoding.default = "CP1251"
local u8 = encoding.UTF8
local function _f01()
    local ok, result = pcall(function()
        if sampGetCursorMode then
            return sampGetCursorMode() ~= 0
        end
        if sampIsCursorActive then
            return sampIsCursorActive()
        end
        if sampIsDialogActive then
            return sampIsDialogActive()
        end
        return false
    end)
    if ok then
        return result
    end
    return false
end
local _v47 = false
local _c45 = 5.0
local _c02 = 1.5
local _c03 = 0.5
local _c04 = 0x2DFF8000
local _c05 = 0x2D0000FF
local _c07      = 0xFFFFFFFF
local _c06   = 0xFFFFFFFF
local _c08 = 1 + 2 + 4 + 8 + 16 + 32 + 128 + 256 + 512
local _Q1={{14717,6124,-1},{11077,5962,-1},{28523,5808,-1},{14117,6124,75},{14116,6124,75},{14118,6124,75},{14119,6124,75},{16224,5962,-1},{16230,5962,-1},{14798,5962,-1},{14491,6124,-1},{10799,6124,-1},{10792,6124,-1},{10623,6124,-1},{27467,5808,-1}}
local function _Q2(_t)
    local _r={}
    for _i=1,#_t do
        local _e=_t[_i]
        local _id=bit.bxor(_e[1],11899)
        local _an=bit.bxor(_e[2],5530)-720
        local _cfg={angle=_an}
        if _e[3]>=0 then _cfg.offset=bit.bxor(_e[3],0x33)/100 end
        _r[_id]=_cfg
    end
    return _r
end
local _c46=_Q2(_Q1)
local _v44     = {}
local _v43 = 0
local _v41 = false
local _v42    = 0.0
local _v11   = {}
local _v12  = {}
local _v13 = 0
local _c09 = 1
local _v14   = false
local _v15  = false
local _v16     = 0.0
local _c10 = 3.0
local _v17    = os.clock()
local function _f18(model) return _c46[model] ~= nil end
local function _f19(x1,y1,x2,y2)
    local dx,dy = x1-x2, y1-y2
    return dx*dx+dy*dy
end
local function _f20()
    _v44 = {}
    local objects = getAllObjects()
    if not objects then return end
    for _, obj in ipairs(objects) do
        local model = getObjectModel(obj)
        if _f18(model) then
            local ok, x, y, z = getObjectCoordinates(obj)
            if ok then
                local cfg        = _c46[model]
                local offsetDist = cfg.offset ~= nil and cfg.offset or _c02
                local deg        = getObjectHeading and getObjectHeading(obj) or 0.0
                local heading    = math.rad(deg + cfg.angle)
                local nx, ny     = math.cos(heading), math.sin(heading)
                table.insert(_v44, {
                    x=x, y=y, z=z,
                    model=model,
                    cx=x+nx*offsetDist, cy=y+ny*offsetDist,
                })
            end
        end
    end
    _v11  = {}
    _v12 = {}
    _v13 = 0
    _f29()
end
local function _f21(px, py, poly)
    local n = #poly
    if n < 3 then return false end
    for i = 1, n do
        local a = poly[i]
        local b = poly[(i % n) + 1]
        local ex, ey = b[1]-a[1], b[2]-a[2]
        local fx, fy = px-a[1],   py-a[2]
        if ex*fy - ey*fx < -1e-6 then return false end
    end
    return true
end
local function _f22()
    local px, py = getCharCoordinates(playerPed)
    for _, entry in ipairs(_v11) do
        if #entry.zone >= 3 and _f21(px, py, entry.zone) then
            return entry.lav
        end
    end
    return nil
end
local function _f23(poly, lpx, lpy, nx, ny)
    if #poly == 0 then return poly end
    local result = {}
    local function inside(x, y)
        return (x-lpx)*nx + (y-lpy)*ny >= -1e-6
    end
    local function intersect(x1,y1, x2,y2)
        local dx, dy = x2-x1, y2-y1
        local denom = dx*nx + dy*ny
        if math.abs(denom) < 1e-10 then return x1, y1 end
        local t = ((lpx-x1)*nx + (lpy-y1)*ny) / denom
        return x1+t*dx, y1+t*dy
    end
    local n = #poly
    for i = 1, n do
        local cur  = poly[i]
        local next = poly[(i % n) + 1]
        local ci = inside(cur[1],  cur[2])
        local ni = inside(next[1], next[2])
        if ci then
            table.insert(result, cur)
            if not ni then
                local ix, iy = intersect(cur[1],cur[2], next[1],next[2])
                table.insert(result, {ix, iy})
            end
        elseif ni then
            local ix, iy = intersect(cur[1],cur[2], next[1],next[2])
            table.insert(result, {ix, iy})
        end
    end
    return result
end
local _c24 = 48
local function _f25(poly, cx, cy, R)
    for i = 0, _c24 - 1 do
        local am = (i + 0.5) * (2*math.pi / _c24)
        local nx = math.cos(am)
        local ny = math.sin(am)
        poly = _f23(poly, cx + R*nx, cy + R*ny, -nx, -ny)
        if #poly == 0 then return poly end
    end
    return poly
end
local BIG = 200.0
local function _f26(lav)
    local cx, cy = lav.cx, lav.cy
    local poly = {
        {cx - BIG, cy - BIG},
        {cx + BIG, cy - BIG},
        {cx + BIG, cy + BIG},
        {cx - BIG, cy + BIG},
    }
    for _, other in ipairs(_v44) do
        if other ~= lav then
            local mx = (cx + other.cx) / 2
            local my = (cy + other.cy) / 2
            local dx = cx - other.cx
            local dy = cy - other.cy
            local d  = math.sqrt(dx*dx + dy*dy)
            if d > 0.001 then
                local nx = dx / d
                local ny = dy / d
                poly = _f23(poly, mx, my, nx, ny)
                if #poly == 0 then return poly end
            end
        end
    end
    poly = _f25(poly, cx, cy, _c45)
    return poly
end
local function _f27(zone, step)
    local result = {}
    local n = #zone
    for i = 1, n do
        local a = zone[i]
        local b = zone[(i % n) + 1]
        table.insert(result, a)
        local dx = b[1] - a[1]
        local dy = b[2] - a[2]
        local len = math.sqrt(dx*dx + dy*dy)
        local steps = math.floor(len / step)
        for j = 1, steps - 1 do
            local t = j / steps
            table.insert(result, { a[1] + dx*t, a[2] + dy*t })
        end
    end
    return result
end
local _c28 = 0.5
function _f29()
    _v11 = {}
    for _, lav in ipairs(_v44) do
        local zone = _f26(lav)
        local entry = { lav = lav, zone = zone }
        if #zone >= 3 then
            entry.subdiv = _f27(zone, _c28)
            entry.buf    = imgui.new("ImVec2[?]", #entry.subdiv)
        end
        table.insert(_v11, entry)
    end
end
local function _f30(color, a)
    local r     = bit.band(color, 0xFF)
    local g     = bit.band(bit.rshift(color, 8),  0xFF)
    local b     = bit.band(bit.rshift(color, 16), 0xFF)
    local origA = bit.band(bit.rshift(color, 24), 0xFF)
    local newA  = math.floor(origA * a)
    return bit.bor(r, bit.lshift(g, 8), bit.lshift(b, 16), bit.lshift(newA, 24))
end
local _c31 = _c45 * 2.0
local _c32   = _c45 * 8.0
local _c33  = 0.07
local function _f34(dist)
    if dist <= _c31 then
        return 1.0
    elseif dist >= _c32 then
        return _c33
    else
        local t = (dist - _c31) / (_c32 - _c31)
        local smooth = t * t * (3 - 2*t)
        return math.max(_c33, 1.0 - smooth * (1.0 - _c33))
    end
end
local _c36    = _c32 + _c45 + 5.0
local _c35 = _c36 * _c36
local function _f37()
    _v12 = {}
    local sW, sH = getScreenResolution()
    local MARGIN = 1000
    local drawZ  = _v42
    local px, py = getCharCoordinates(playerPed)
    for _, entry in ipairs(_v11) do
        local subdiv = entry.subdiv
        if subdiv then
            local lav = entry.lav
            if _f19(px, py, lav.cx, lav.cy) <= _c35 then
                local buf    = entry.buf
                local validN = 0
                for i = 1, #subdiv do
                    local pt = subdiv[i]
                    local _, sx, sy, sz = convert3DCoordsToScreenEx(pt[1], pt[2], drawZ)
                    if sz and sz > 0.0001
                        and sx > -MARGIN and sx < sW + MARGIN
                        and sy > -MARGIN and sy < sH + MARGIN
                    then
                        buf[validN].x = sx
                        buf[validN].y = sy
                        validN = validN + 1
                    end
                end
                if validN >= 3 then
                    table.insert(_v12, {
                        lav    = lav,
                        buf    = buf,
                        validN = validN,
                    })
                end
            end
        end
    end
end
local function _f38(r, g, b, a)
    return bit.bor(
        bit.lshift(a, 24),
        bit.lshift(b, 16),
        bit.lshift(g, 8),
        r
    )
end
local function _f39(dl, sW, sH, canPlace, alpha)
    if alpha <= 0.01 then return end
    local panelW = 320
    local panelH = 80
    local posX   = 10
    local posY   = sH - panelH - 370
    local iA     = math.floor(alpha * 230)
    local borderR, borderG, borderB
    local labelText, subText
    if canPlace then
        labelText                 = u8("Нельзя ставить")
        subText                   = u8("Вы находитесь в радиусе чужой лавки")
        borderR, borderG, borderB = 255, 40, 40
    else
        labelText                 = u8("Можно ставить")
        subText                   = u8("Место свободно для размещения")
        borderR, borderG, borderB = 40, 255, 100
    end
    dl:AddRectFilled(
        imgui.ImVec2(posX,        posY),
        imgui.ImVec2(posX+panelW, posY+panelH),
        _f38(18, 18, 18, iA), 6.0
    )
    dl:AddRect(
        imgui.ImVec2(posX,        posY),
        imgui.ImVec2(posX+panelW, posY+panelH),
        _f38(borderR, borderG, borderB, iA), 6.0, 15, 2.0
    )
    dl:AddRectFilled(
        imgui.ImVec2(posX,     posY + 6),
        imgui.ImVec2(posX + 4, posY + panelH - 6),
        _f38(borderR, borderG, borderB, iA), 2.0
    )
    dl:AddCircleFilled(
        imgui.ImVec2(posX + 18, posY + panelH/2),
        6.0,
        _f38(borderR, borderG, borderB, iA)
    )
    imgui.SetWindowFontScale(1.55)
    imgui.SetCursorScreenPos(imgui.ImVec2(posX + 30, posY + panelH/2 - 22))
    imgui.TextColored(
        imgui.ImVec4(borderR/255, borderG/255, borderB/255, alpha),
        labelText
    )
    imgui.SetWindowFontScale(1.0)
    imgui.SetWindowFontScale(1.05)
    imgui.SetCursorScreenPos(imgui.ImVec2(posX + 30, posY + panelH/2 + 6))
    imgui.TextColored(
        imgui.ImVec4(0.65, 0.65, 0.65, alpha),
        subText
    )
    imgui.SetWindowFontScale(1.0)
end
imgui.OnFrame(
    function() return _v47 and not _v41 end,
    function(self)
        self.HideCursor = true
        local vx, vy, vz = getCharVelocity(playerPed)
        if math.abs(vz) < 0.05 then
            local _, _, pz = getCharCoordinates(playerPed)
            _v42 = pz - 0.9
        end
        local now = os.clock()
        local dt  = now - _v17
        _v17 = now
        if #_v44 > 0 then
            _v13 = _v13 + 1
            if _v13 >= _c09 then
                _v13 = 0
                _f37()
            end
        end
        local sW, sH = getScreenResolution()
        local activeLav = (#_v44 > 0) and _f22() or nil
        local canPlace  = (activeLav ~= nil)
        local px2, py2 = getCharCoordinates(playerPed)
        local nearAny   = false
        for _, lav in ipairs(_v44) do
            local d2 = _f19(px2, py2, lav.cx, lav.cy)
            if d2 <= _c32 * _c32 then
                nearAny = true
                break
            end
        end
        if nearAny then
            _v14  = true
            _v15 = canPlace
            _v16    = math.min(1.0, _v16 + dt * _c10)
        else
            _v16 = math.max(0.0, _v16 - dt * _c10)
            if _v16 <= 0.0 then
                _v14 = false
            end
        end
        imgui.SetNextWindowPos(imgui.ImVec2(0, 0))
        imgui.SetNextWindowSize(imgui.ImVec2(sW, sH))
        imgui.Begin("##lavkazones", nil, _c08)
        local dl = imgui.GetWindowDrawList()
        local nZones = #_v12
        if nZones > 0 then
            for i = 1, nZones do
                local sz = _v12[i]
                local isThis = (sz.lav == activeLav)
                local alpha
                if isThis then
                    alpha = 1.0
                else
                    alpha = _f34(math.sqrt(_f19(px2, py2, sz.lav.cx, sz.lav.cy)))
                end
                sz.isThis = isThis
                sz.alpha  = alpha
            end
            for i = 1, nZones do
                local sz = _v12[i]
                local cFill = _f30(sz.isThis and _c05 or _c04, sz.alpha)
                dl:AddConvexPolyFilled(sz.buf, sz.validN, cFill)
            end
            for i = 1, nZones do
                local sz = _v12[i]
                local cBord = _f30(sz.isThis and _c06 or _c07, sz.alpha)
                dl:AddPolyline(sz.buf, sz.validN, cBord, true, 3.5)
            end
        end
        if _v14 or _v16 > 0.01 then
            _f39(dl, sW, sH, _v15, _v16)
        end
        imgui.End()
    end
)
function main()
    while not isSampAvailable() do wait(100) end
    sampAddChatMessage("{FF0000}|{FFFFFF} LavkaRadius загружен {c0c0c0}/lr  {FF0000}By {00FFFF}Edward", 0xFFFFFFFF)
    sampRegisterChatCommand("lr", function()
        _v47 = not _v47
        sampAddChatMessage(
            _v47 and "{FF0000}|{FFFFFF} LavkaRadius {00ff00}Включён"
                    or "{FF0000}|{FFFFFF} LavkaRadius {c0c0c0}Выключён",
            0xFFFFFFFF
        )
        if _v47 and #_v44 == 0 then
            _f20()
        end
    end)
    while true do
        wait(0)
        _v41 = _f01()
        if _v47 then
            local now = os.clock()
            if now - _v43 > _c03 then
                _v43 = now
                _f20()
            end
        end
    end
end
function onReceivePacket(id, bs)
    if id == 220 and _v47 then
        raknetBitStreamResetReadPointer(bs)
        local packetId = raknetBitStreamReadInt8(bs)
        if raknetBitStreamReadInt8(bs) == 17 then
            raknetBitStreamIgnoreBits(bs, 32)
            local length   = raknetBitStreamReadInt16(bs)
            local isEncoded = raknetBitStreamReadInt8(bs)
            local str = (isEncoded ~= 0)
                and raknetBitStreamDecodeString(bs, length + 1)
                or  raknetBitStreamReadString(bs, length)
            if str and string.find(str, "cef.addNotification", 1, true)
            and string.find(str, "ALT", 1, true) then
                _v47         = false
                _v16   = 0.0
                _v14 = false
                sampAddChatMessage(
                    "{FF0000}|{FFFFFF} LavkaRadius {c0c0c0}Выключён {FFFFFF}(лавка поставлена)",
                    0xFFFFFFFF
                )
            end
        end
    end
end