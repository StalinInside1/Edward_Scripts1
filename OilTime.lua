script_name('OilTime')
script_author('Edward')

require 'lib.moonloader'
local imgui    = require 'mimgui'
local sampev   = require 'samp.events'
local inicfg   = require 'inicfg'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local COOLDOWN       = 18
local STARTUP_IGNORE = 5
local DUP_WINDOW     = 3
local DIALOG_ID      = 502
local CFG_FILE       = 'OilTime.ini'

local SIZES      = { 0.8, 1.0, 1.35 }
local SIZE_NAMES = { 'Маленький', 'Стандарт', 'Большой' }

local cfg = inicfg.load({ main = {
    x = -1, y = -1, ix = -1, iy = -1,
    auto = 1, show = 1, icon = 1, size = 2, font = 100, isize = 68
} }, CFG_FILE)

local V = imgui.ImVec2

local loadTime = os.clock()
local endTime  = 0
local active   = false
local bought   = 0
local pending  = false
local moveMode = false
local dirty, lastChange = false, 0

local show     = imgui.new.bool(tonumber(cfg.main.show) ~= 0)
local showIcon = imgui.new.bool(tonumber(cfg.main.icon) ~= 0)
local autoBool = imgui.new.bool(tonumber(cfg.main.auto) ~= 0)
local menu     = imgui.new.bool(false)
local fontPct  = imgui.new.int(math.min(160, math.max(70, tonumber(cfg.main.font) or 100)))
local sizeIdx  = math.min(3, math.max(1, tonumber(cfg.main.size) or 2))
local posX, posY = imgui.new.int(0), imgui.new.int(0)
local iconSize = imgui.new.int(math.min(140, math.max(40, tonumber(cfg.main.isize) or 68)))
local iposX, iposY = imgui.new.int(0), imgui.new.int(0)
local iconDrag = 0

local pos, ipos
local layout = { w = 300, h = 96 }
local fontSmall, fontBig

local function uiScale()
    local _, h = getScreenResolution()
    return math.min(2, math.max(0.8, h / 1080))
end

local function touch()
    dirty = true
    lastChange = os.clock()
end

local function saveConfig()
    if pos then
        cfg.main.x = math.floor(pos.x)
        cfg.main.y = math.floor(pos.y)
    end
    if ipos then
        cfg.main.ix = math.floor(ipos.x)
        cfg.main.iy = math.floor(ipos.y)
    end
    cfg.main.auto = autoBool[0] and 1 or 0
    cfg.main.show = show[0] and 1 or 0
    cfg.main.icon = showIcon[0] and 1 or 0
    cfg.main.size = sizeIdx
    cfg.main.font = fontPct[0]
    cfg.main.isize = iconSize[0]
    inicfg.save(cfg, CFG_FILE)
    dirty = false
end

local function ensurePos()
    local sw, sh = getScreenResolution()
    local ui = uiScale()
    if not pos then
        if cfg.main.x >= 0 and cfg.main.y >= 0 then
            pos = { x = cfg.main.x, y = cfg.main.y }
        else
            pos = { x = sw / 2 - 150 * ui, y = sh * 0.08 }
        end
    end
    if not ipos then
        if cfg.main.ix >= 0 and cfg.main.iy >= 0 then
            ipos = { x = cfg.main.ix, y = cfg.main.iy }
        else
            ipos = { x = 20 * ui, y = sh * 0.35 }
        end
    end
end

local function col(r, g, b, a)
    return imgui.GetColorU32Vec4(imgui.ImVec4(r / 255, g / 255, b / 255, a or 1))
end

local function vec(r, g, b, a)
    return imgui.ImVec4(r / 255, g / 255, b / 255, a or 1)
end

local function startTimer()
    if os.clock() - loadTime < STARTUP_IGNORE then return end
    if active and (endTime - os.clock()) > COOLDOWN - DUP_WINDOW then return end
    endTime = os.clock() + COOLDOWN
    active  = true
    bought  = bought + 1
end

local function isBarrelPurchase(str)
    if type(str) ~= 'string' then return false end
    return str:find('приобрели бочку', 1, true) ~= nil
        or str:find(u8:decode('приобрели бочку'), 1, true) ~= nil
end

local function readCefString(bs)
    raknetBitStreamResetReadPointer(bs)
    raknetBitStreamReadInt8(bs)
    local pType = raknetBitStreamReadInt8(bs)
    local str
    if pType == 17 then
        raknetBitStreamIgnoreBits(bs, 32)
        local length    = raknetBitStreamReadInt16(bs)
        local isEncoded = raknetBitStreamReadInt8(bs)
        str = (isEncoded ~= 0)
            and raknetBitStreamDecodeString(bs, length + isEncoded)
            or  raknetBitStreamReadString(bs, length)
    elseif pType == 84 then
        raknetBitStreamReadInt8(bs)
        raknetBitStreamReadInt8(bs)
        local length    = raknetBitStreamReadInt16(bs)
        local isEncoded = raknetBitStreamReadInt8(bs)
        str = (isEncoded ~= 0)
            and raknetBitStreamDecodeString(bs, length + isEncoded)
            or  raknetBitStreamReadString(bs, length)
    end
    raknetBitStreamResetReadPointer(bs)
    return str
end

function onReceivePacket(id, bs)
    if id ~= 220 then return end
    local ok, str = pcall(readCefString, bs)
    if ok and isBarrelPurchase(str) then
        startTimer()
    end
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if not autoBool[0] or id ~= DIALOG_ID then return end
    text = text or ''
    if text:find('бочк', 1, true) or text:find(u8:decode('бочк'), 1, true) then
        pending = true
        return false
    end
end

local function findFont(list)
    for _, p in ipairs(list) do
        if doesFileExist(p) then return p end
    end
end

local function applyStyle()
    local ui = uiScale()
    local st = imgui.GetStyle()
    st.WindowRounding   = 18 * ui
    st.FrameRounding    = 12 * ui
    st.GrabRounding     = 12 * ui
    st.WindowBorderSize = 0
    st.WindowPadding    = V(22 * ui, 20 * ui)
    st.FramePadding     = V(14 * ui, 12 * ui)
    st.ItemSpacing      = V(12 * ui, 14 * ui)
    st.GrabMinSize      = 34 * ui
    st.ScrollbarSize    = 20 * ui

    local c, C = st.Colors, imgui.Col
    c[C.WindowBg]         = vec(23, 23, 28, 0.97)
    c[C.Text]             = vec(235, 235, 240)
    c[C.FrameBg]          = vec(42, 42, 50)
    c[C.FrameBgHovered]   = vec(54, 54, 64)
    c[C.FrameBgActive]    = vec(66, 66, 78)
    c[C.CheckMark]        = vec(60, 208, 112)
    c[C.SliderGrab]       = vec(60, 208, 112)
    c[C.SliderGrabActive] = vec(245, 166, 35)
    c[C.Button]           = vec(48, 48, 58)
    c[C.ButtonHovered]    = vec(66, 66, 80)
    c[C.ButtonActive]     = vec(60, 208, 112)
    c[C.Separator]        = vec(60, 60, 72)
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    applyStyle()

    local atlas  = imgui.GetIO().Fonts
    local ranges = atlas:GetGlyphRangesCyrillic()
    local wd = getWorkingDirectory()

    local regular = findFont({
        wd .. '/resource/fonts/arial.ttf',
        wd .. '/resource/arial.ttf',
        '/system/fonts/Roboto-Regular.ttf',
        '/system/fonts/DroidSans.ttf',
        'C:\\Windows\\Fonts\\arial.ttf',
    })
    local bold = findFont({
        wd .. '/resource/fonts/arialbd.ttf',
        wd .. '/resource/arialbd.ttf',
        '/system/fonts/Roboto-Bold.ttf',
        'C:\\Windows\\Fonts\\arialbd.ttf',
    }) or regular

    if regular then
        fontSmall = atlas:AddFontFromFileTTF(regular, 20, nil, ranges)
        fontBig   = atlas:AddFontFromFileTTF(bold, 34, nil, ranges)
    else
        fontSmall = atlas:AddFontDefault()
        fontBig   = fontSmall
    end
end)

local function drawRing(dl, c, r, frac, color, th)
    if frac <= 0.005 then return end
    local n = math.max(2, math.floor(72 * frac))
    local a0, span = -math.pi / 2, 2 * math.pi * frac
    for i = 0, n - 1 do
        local a1 = a0 + span * (i / n)
        local a2 = a0 + span * ((i + 1) / n)
        dl:AddLine(
            V(c.x + math.cos(a1) * r, c.y + math.sin(a1) * r),
            V(c.x + math.cos(a2) * r, c.y + math.sin(a2) * r),
            color, th)
    end
end

local function ellipse(dl, cx, cy, rx, ry, color, fill)
    local n = 28
    for i = 0, n - 1 do
        local a1 = i / n * 2 * math.pi
        local a2 = (i + 1) / n * 2 * math.pi
        local p1 = V(cx + math.cos(a1) * rx, cy + math.sin(a1) * ry)
        local p2 = V(cx + math.cos(a2) * rx, cy + math.sin(a2) * ry)
        if fill then
            dl:AddTriangleFilled(V(cx, cy), p1, p2, color)
        else
            dl:AddLine(p1, p2, color, 1.2)
        end
    end
end

local function arc(dl, cx, cy, rx, ry, color, th)
    local n = 20
    for i = 0, n - 1 do
        local a1 = i / n * math.pi
        local a2 = (i + 1) / n * math.pi
        dl:AddLine(
            V(cx + math.cos(a1) * rx, cy + math.sin(a1) * ry),
            V(cx + math.cos(a2) * rx, cy + math.sin(a2) * ry),
            color, th)
    end
end

local function drawBarrel(dl, cx, cy, accU, accV, s)
    local hw, top, bot = 17 * s, cy - 19 * s, cy + 19 * s

    ellipse(dl, cx, bot + 6 * s, hw + 2 * s, 4 * s, col(0, 0, 0, 0.35), true)
    ellipse(dl, cx, bot, hw, 5 * s, col(40, 42, 46), true)
    dl:AddRectFilledMultiColor(V(cx - hw, top), V(cx + hw, bot),
        col(74, 76, 82), col(42, 44, 48), col(42, 44, 48), col(74, 76, 82))

    arc(dl, cx, cy - 8 * s,  hw, 3 * s, col(240, 240, 240), 1.6 * s)
    arc(dl, cx, cy + 12 * s, hw, 3 * s, col(240, 240, 240), 1.6 * s)

    if s >= 0.7 then
        imgui.SetWindowFontScale(0.62 * s)
        local ts = imgui.CalcTextSize('OIL')
        imgui.SetCursorScreenPos(V(cx - ts.x / 2, cy + 3 * s - ts.y / 2))
        imgui.TextColored(accV, 'OIL')
        imgui.SetWindowFontScale(1)
    end

    ellipse(dl, cx, top, hw, 5 * s, col(236, 236, 240), true)
    ellipse(dl, cx, top, hw, 5 * s, col(190, 190, 198), false)
    ellipse(dl, cx - 6 * s, top, 3.2 * s, 1.5 * s, col(28, 28, 32), true)
end

local function measure(font, scale, str)
    imgui.PushFont(font)
    imgui.SetWindowFontScale(scale)
    local s = imgui.CalcTextSize(str)
    imgui.PopFont()
    return s.x, s.y
end

local function put(font, scale, x, y, color, str)
    imgui.PushFont(font)
    imgui.SetWindowFontScale(scale)
    imgui.SetCursorScreenPos(V(x, y))
    imgui.TextColored(color, str)
    imgui.PopFont()
end

-- Оверлей таймера
imgui.OnFrame(function() return show[0] end, function(self)
    local sw, sh = getScreenResolution()
    local ui = uiScale()
    ensurePos()
    self.HideCursor = not moveMode

    local S  = ui * SIZES[sizeIdx]
    local F  = fontPct[0] / 100
    local ss = 0.9 * S * F
    local bs = 0.85 * S * F
    local left = endTime - os.clock()

    if not moveMode then
        pos.x = math.max(0, math.min(pos.x, sw - layout.w))
        pos.y = math.max(0, math.min(pos.y, sh - layout.h))
    end

    imgui.SetNextWindowPos(V(pos.x, pos.y),
        moveMode and imgui.Cond.FirstUseEver or imgui.Cond.Always)
    imgui.SetNextWindowSize(V(layout.w, layout.h))

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 14 * S)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V(0, 0))
    imgui.PushStyleColor(imgui.Col.WindowBg, vec(23, 23, 28, 0.92))

    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize
                + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoCollapse
                + imgui.WindowFlags.NoScrollWithMouse
    if not moveMode then
        flags = flags + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoInputs
    end

    if imgui.Begin('##OilTimeOverlay', nil, flags) then
        local p  = imgui.GetWindowPos()
        local dl = imgui.GetWindowDrawList()
        if moveMode then pos.x, pos.y = p.x, p.y end

        local lab = active and 'Следующая бочка через' or 'Бочка готова'
        local big = active and (string.format('%.1f', math.max(left, 0)) .. ' с') or 'Можно брать'
        local bl  = 'Куплено: ' .. bought
        local br  = moveMode and 'перемещение' or (autoBool[0] and 'авто' or 'ручн.')

        local w1, hs = measure(fontSmall, ss, 'Следующая бочка через')
        local w2, hb = measure(fontBig, bs, 'Можно брать')
        local w3     = measure(fontBig, bs, '88.8 с')
        local w4     = measure(fontSmall, ss, 'Куплено: 9999')
        local w5     = measure(fontSmall, ss, 'перемещение')
        local wr     = measure(fontSmall, ss, br)

        local tx = 104 * S
        local nw = tx + math.max(w1, w2, w3, w4 + 16 * S + w5) + 18 * S
        local nh = math.max(96 * S, 12 * S + hs + 2 * S + hb + 8 * S + hs + 12 * S)
        layout.w, layout.h = nw, nh

        local acc  = active and vec(245, 166, 35) or vec(60, 208, 112)
        local accU = imgui.GetColorU32Vec4(acc)
        local center = V(p.x + 52 * S, p.y + nh / 2)
        local frac = active and math.min(1, math.max(0, 1 - left / COOLDOWN)) or 1

        dl:AddRectFilled(V(p.x, p.y + 14 * S), V(p.x + 4 * S, p.y + nh - 14 * S), accU, 2)
        drawRing(dl, center, 38 * S, 1, col(50, 50, 60), 3 * S)
        drawRing(dl, center, 38 * S, frac, accU, 3 * S)
        drawBarrel(dl, center.x, center.y, accU, acc, S)

        put(fontSmall, ss, p.x + tx, p.y + 12 * S, vec(170, 170, 180), lab)
        put(fontBig, bs, p.x + tx, p.y + 12 * S + hs + 2 * S,
            active and vec(255, 255, 255) or vec(60, 208, 112), big)

        local by = p.y + nh - 12 * S - hs
        put(fontSmall, ss, p.x + tx, by, vec(120, 120, 130), bl)
        put(fontSmall, ss, p.x + nw - 18 * S - wr, by,
            moveMode and vec(245, 166, 35) or (autoBool[0] and vec(60, 208, 112) or vec(120, 120, 130)), br)

        imgui.SetWindowFontScale(1)
    end
    imgui.End()

    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
end)

imgui.OnFrame(function() return showIcon[0] end, function(self)
    local sw, sh = getScreenResolution()
    local ui = uiScale()
    ensurePos()
    local isz = iconSize[0] * ui
    local k = isz / (68 * ui)
    local left = endTime - os.clock()

    ipos.x = math.max(0, math.min(ipos.x, sw - isz))
    ipos.y = math.max(0, math.min(ipos.y, sh - isz))

    imgui.SetNextWindowPos(V(ipos.x, ipos.y), imgui.Cond.Always)
    imgui.SetNextWindowSize(V(isz, isz))

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, isz / 2)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V(0, 0))
    imgui.PushStyleColor(imgui.Col.WindowBg, vec(23, 23, 28, 0.9))

    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize
                + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoCollapse
                + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoMove

    if imgui.Begin('##OilTimeIcon', nil, flags) then
        local p  = imgui.GetWindowPos()
        local dl = imgui.GetWindowDrawList()

        local acc  = active and vec(245, 166, 35) or vec(60, 208, 112)
        local accU = imgui.GetColorU32Vec4(acc)
        local c = V(p.x + isz / 2, p.y + isz / 2)
        local frac = active and math.min(1, math.max(0, 1 - left / COOLDOWN)) or 1

        drawRing(dl, c, isz / 2 - 5 * k * ui, 1, col(50, 50, 60), 3 * k * ui)
        drawRing(dl, c, isz / 2 - 5 * k * ui, frac, accU, 3 * k * ui)
        drawBarrel(dl, c.x, c.y, accU, acc, 0.5 * k * ui)

        if not moveMode then
            imgui.SetCursorPos(V(0, 0))
            local clicked = imgui.InvisibleButton('##OilTimeIconBtn', V(isz, isz))
            if imgui.IsItemActive() then
                local d = imgui.GetIO().MouseDelta
                iconDrag = iconDrag + math.abs(d.x) + math.abs(d.y)
                if iconDrag > 12 * ui then
                    ipos.x = ipos.x + d.x
                    ipos.y = ipos.y + d.y
                    touch()
                end
            end
            if clicked then
                if iconDrag <= 12 * ui then menu[0] = not menu[0] end
                iconDrag = 0
            elseif not imgui.IsItemActive() then
                iconDrag = 0
            end
        end
    end
    imgui.End()

    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
end)

imgui.OnFrame(function() return moveMode end, function(self)
    local sw, sh = getScreenResolution()
    local ui = uiScale()
    imgui.SetNextWindowPos(V(sw / 2, sh - 30 * ui), imgui.Cond.Always, V(0.5, 1))
    imgui.Begin('##OilTimeDone', nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse)
    imgui.SetWindowFontScale(ui)
    if imgui.Button('Готово - закрепить', V(320 * ui, 64 * ui)) then
        moveMode = false
        saveConfig()
        menu[0] = true
    end
    imgui.End()
end)

local function section(text)
    imgui.TextColored(vec(150, 150, 165), text)
end

local dragTrack, dragScrolled, dragWasDown, dragStartY, sliderHeld = false, false, false, 0, false

local function btn(label, size)
    local r = imgui.Button(label, size)
    return r and not dragScrolled
end

local function chk(label, v)
    local r = imgui.Checkbox(label, v)
    return r and not dragScrolled
end

local function sld(label, v, mn, mx, fmt)
    local r = imgui.SliderInt(label, v, mn, mx, fmt)
    if imgui.IsItemActive() then sliderHeld = true end
    return r
end

local function handleDragScroll(ui)
    local down = imgui.IsMouseDown(0)
    if not down then
        if not dragWasDown then dragScrolled = false end
        dragTrack = false
    end
    dragWasDown = down

    if sliderHeld then dragTrack = false end

    if imgui.IsMouseClicked(0) and imgui.IsWindowHovered() and not sliderHeld then
        local mp, wp, ws = imgui.GetMousePos(), imgui.GetWindowPos(), imgui.GetWindowSize()
        local sbX = wp.x + ws.x - imgui.GetStyle().ScrollbarSize - 4 * ui
        if mp.x < sbX then
            dragTrack = true
            dragScrolled = false
            dragStartY = mp.y
        end
    end

    if dragTrack and down then
        local mp = imgui.GetMousePos()
        if dragScrolled or math.abs(mp.y - dragStartY) > 10 * ui then
            dragScrolled = true
            imgui.SetScrollY(imgui.GetScrollY() - imgui.GetIO().MouseDelta.y)
        end
    end
end

local SIZE_SHORT = { 'Малый', 'Станд.', 'Большой' }

imgui.OnFrame(function() return menu[0] and not moveMode end, function(self)
    local sw, sh = getScreenResolution()
    local ui = uiScale()
    ensurePos()
    local W = math.min(1180 * ui, sw * 0.97)
    local BH = 52 * ui

    imgui.SetNextWindowPos(V(sw / 2, sh / 2), imgui.Cond.Appearing, V(0.5, 0.5))
    imgui.SetNextWindowSizeConstraints(V(W, 0), V(W, sh * 0.98))

    if imgui.Begin('##OilTimeMenu', nil,
        imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoMove) then
        imgui.SetWindowFontScale(ui)
        sliderHeld = false

        local winW = imgui.GetWindowWidth()
        local pad  = imgui.GetStyle().WindowPadding
        local sp   = imgui.GetStyle().ItemSpacing.x

        imgui.PushFont(fontBig)
        imgui.TextColored(vec(245, 166, 35), 'OilTime')
        imgui.PopFont()
        imgui.TextColored(vec(120, 120, 130), 'Таймер покупки бочек нефти')

        local xs = 56 * ui
        local afterHeader = imgui.GetCursorPos()
        imgui.SetCursorPos(V(winW - pad.x - xs, pad.y - 4 * ui))
        imgui.PushStyleColor(imgui.Col.Button, vec(150, 45, 45))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, vec(190, 60, 60))
        imgui.PushStyleColor(imgui.Col.ButtonActive, vec(220, 70, 70))
        if btn('X##OilTimeClose', V(xs, xs)) then
            menu[0] = false
            saveConfig()
        end
        imgui.PopStyleColor(3)
        imgui.SetCursorPos(afterHeader)
        imgui.Separator()

        imgui.Columns(3, '##OilTimeCols', false)

        local aw = imgui.GetContentRegionAvail().x
        if chk('Показывать таймер', show) then touch() end
        if chk('Иконка на экране', showIcon) then touch() end
        if chk('Автопокупка бочки', autoBool) then
            if not autoBool[0] then pending = false end
            touch()
        end
        imgui.Separator()

        section('Размер окна')
        local bw = (aw - 2 * sp) / 3
        for i = 1, 3 do
            if i > 1 then imgui.SameLine() end
            local sel = sizeIdx == i
            if sel then imgui.PushStyleColor(imgui.Col.Button, vec(40, 160, 90)) end
            if btn(SIZE_SHORT[i] .. '##sz' .. i, V(bw, BH)) then
                sizeIdx = i
                touch()
            end
            if sel then imgui.PopStyleColor() end
        end

        section('Размер шрифта')
        imgui.PushItemWidth(-1)
        if sld('##font', fontPct, 70, 160, '%d%%') then touch() end
        imgui.PopItemWidth()

        imgui.NextColumn()
        section('Позиция таймера')
        posX[0], posY[0] = math.floor(pos.x), math.floor(pos.y)
        imgui.PushItemWidth(-1)
        if sld('##px', posX, 0, sw, 'X: %d') then pos.x = posX[0]; touch() end
        if sld('##py', posY, 0, sh, 'Y: %d') then pos.y = posY[0]; touch() end
        imgui.PopItemWidth()
        if btn('Двигать таймер', V(-1, BH)) then
            show[0] = true
            moveMode = true
            menu[0] = false
        end
        if btn('Сбросить позицию', V(-1, BH)) then
            pos = { x = sw / 2 - 150 * ui, y = sh * 0.08 }
            touch()
        end

        imgui.NextColumn()
        section('Кнопка меню (иконку можно таскать)')
        imgui.PushItemWidth(-1)
        if sld('##isz', iconSize, 40, 140, 'Размер: %d') then touch() end
        iposX[0], iposY[0] = math.floor(ipos.x), math.floor(ipos.y)
        if sld('##ipx', iposX, 0, sw, 'X: %d') then ipos.x = iposX[0]; touch() end
        if sld('##ipy', iposY, 0, sh, 'Y: %d') then ipos.y = iposY[0]; touch() end
        imgui.PopItemWidth()
        if btn('Сбросить кнопку', V(-1, BH)) then
            ipos = { x = 20 * ui, y = sh * 0.35 }
            iconSize[0] = 68
            touch()
        end

        imgui.Columns(1)
        imgui.Separator()

        local fw = imgui.GetContentRegionAvail().x
        local hw = (fw - sp) / 2
        if btn('Обнулить счётчик', V(hw, BH)) then bought = 0 end
        imgui.SameLine()
        if btn('Закрыть', V(hw, BH)) then
            menu[0] = false
            saveConfig()
        end

        handleDragScroll(ui)
        imgui.SetWindowFontScale(1)
    end
    imgui.End()
end)

function onScriptTerminate(scr, quitGame)
    if scr == thisScript() then saveConfig() end
end

function main()
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand('oiltime', function()
        menu[0] = not menu[0]
    end)

    sampRegisterChatCommand('oilmove', function()
        show[0] = true
        moveMode = true
        menu[0] = false
    end)

    sampRegisterChatCommand('oilauto', function()
        autoBool[0] = not autoBool[0]
        if not autoBool[0] then pending = false end
        touch()
        sampAddChatMessage(u8:decode('{FF0000}|{FFFF00} OilTime {FFFFFF}автопокупка '
            .. (autoBool[0] and '{00FF00}ВКЛ' or '{FF0000}ВЫКЛ')), -1)
    end)

    sampAddChatMessage(u8:decode('{FF0000}|{FFFF00} OilTime {FFFFFF}загружен  {c0c0c0}/oiltime {FFFFFF}- открыть меню'), -1)
    sampAddChatMessage(u8:decode('{FF0000}|{FFFF00} OilTime {FFFFFF}команда  {c0c0c0}/oilmove {FFFFFF}- переместить таймер'), -1)
    sampAddChatMessage(u8:decode('{FF0000}|{FFFF00} OilTime {FFFFFF}команда  {c0c0c0}/oilauto {FFFFFF}- вкл/выкл автопокупку {FF0000}By {00FFFF}Edward'), -1)

    while true do
        wait(30)
        if active and os.clock() >= endTime then
            active = false
        end
        if pending and autoBool[0] and not active then
            pending = false
            sampSendDialogResponse(DIALOG_ID, 1, -1, '')
        end
        if dirty and os.clock() - lastChange > 1 then
            saveConfig()
        end
    end
end
