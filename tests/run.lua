local function repo_root()
    local src = "."
    if type(arg) == "table" and type(arg[0]) == "string" and arg[0] ~= "" then
        src = arg[0]
    end
    local dir = src:match("^(.*)[/\\][^/\\]+$") or "."
    if dir == "tests" or dir:match("[/\\]tests$") then
        local parent = dir:gsub("[/\\]?tests$", "")
        if parent == "" then return "." end
        return parent
    end
    return dir
end

local root = repo_root()
package.path = root .. "/script/RhythmShapes/?.lua;" .. root .. "\\script\\RhythmShapes\\?.lua;" .. package.path

local audio = require("rs_audio")
local beat = require("rs_beat")
local grid = require("rs_grid")
local motion = require("rs_motion")
local layout = require("rs_layout")
local shape = require("rs_shape")
local preset = require("rs_preset")
local host = require("rs_host")
local figure = require("rs_figure")

local failed = 0
local passed = 0

local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        io.write("ok   " .. name .. "\n")
    else
        failed = failed + 1
        io.write("FAIL " .. name .. "\n  " .. tostring(err) .. "\n")
    end
end

local function eq(actual, expected, msg)
    if actual ~= expected then
        error((msg or "eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local function near(actual, expected, eps, msg)
    if math.abs(actual - expected) > eps then
        error((msg or "near") .. ": " .. tostring(actual) .. " vs " .. tostring(expected), 2)
    end
end

local function impulse(n, at, width, amp)
    local pcm = {}
    for i = 1, n do pcm[i] = 0 end
    for i = at, math.min(n, at + width - 1) do pcm[i] = amp end
    return pcm
end

check("version format", function()
    local text = assert(loadfile(root .. "/script/RhythmShapes/version.lua"))()
    assert(type(text) == "string")
    assert(text:match("^%d+%.%d+%.%d+$"), text)
end)

check("pcm normalize and rms", function()
    local n = audio.normalize_pcm({ 32768, -32768, 0 })
    near(n[1], 1, 1e-9)
    near(n[2], -1, 1e-9)
    near(n[3], 0, 1e-9)
    near(audio.rms({ 1, -1, 1, -1 }), 1, 1e-9)
    eq(audio.rms({}), 0)
end)

check("fourier bass bin", function()
    local bins = {}
    for i = 1, 1024 do bins[i] = 0 end
    bins[100] = 1
    local rate = 2048
    near(audio.fourier_freq(100, rate), 100, 1e-9)
    local bass = audio.band_mean(bins, rate, 20, 250, function(i, rt)
        return audio.fourier_freq(i, rt)
    end)
    assert(bass > 0, "bass energy missing")
    local mid = audio.band_mean(bins, rate, 250, 2000, function(i, rt)
        return audio.fourier_freq(i, rt)
    end)
    eq(mid, 0)
    local analyzed = audio.analyze({ pcm = {}, fourier = bins, rate = rate })
    eq(analyzed.source, "fourier")
    assert(analyzed.bass > 0)
    eq(analyzed.mid, 0)
end)

check("click fires and flat signal does not", function()
    local click = impulse(2000, 1901, 10, 1)
    local hit = beat.detect(click, 1000, { sensitivity = 60, min_interval = 0.1, weights = { bass = 0, mid = 0, high = 0 } })
    assert(hit.fired, "click should fire")
    assert(hit.peak_sample >= 1900 and hit.peak_sample <= 1920, tostring(hit.peak_sample))
    assert(hit.age < 0.12, tostring(hit.age))
    local flat = {}
    for i = 1, 2000 do flat[i] = 0.8 end
    local quiet = beat.detect(flat, 1000, { sensitivity = 80, min_interval = 0.1, weights = { bass = 100, mid = 100, high = 100 } })
    eq(quiet.fired, false)
    eq(quiet.peak_sample, nil)
end)

check("minimum interval keeps the earlier peak", function()
    local pcm = impulse(2000, 1001, 10, 1)
    for i = 1201, 1210 do pcm[i] = 1 end
    local wide = beat.detect(pcm, 1000, { sensitivity = 70, min_interval = 0.3, weights = { bass = 0, mid = 0, high = 0 } })
    assert(wide.peak_sample >= 990 and wide.peak_sample <= 1020, tostring(wide.peak_sample))
    local narrow = beat.detect(pcm, 1000, { sensitivity = 70, min_interval = 0.05, weights = { bass = 0, mid = 0, high = 0 } })
    assert(narrow.peak_sample >= 1190 and narrow.peak_sample <= 1220, tostring(narrow.peak_sample))
end)

check("bpm estimate is separate from a short click", function()
    local click = impulse(400, 301, 8, 1)
    local short = beat.detect(click, 1000, { sensitivity = 50, min_interval = 0.08 })
    eq(short.estimated_bpm, nil)
    assert(short.bpm_confidence < 0.55)
    local train = {}
    for i = 1, 4000 do train[i] = 0 end
    for t = 200, 3800, 500 do
        for i = t, t + 8 do train[i] = 1 end
    end
    local est = beat.detect(train, 1000, { sensitivity = 50, min_interval = 0.2, weights = { bass = 0, mid = 0, high = 0 } })
    assert(est.estimated_bpm, "expected a bpm estimate")
    near(est.estimated_bpm, 120, 3)
    assert(est.bpm_confidence >= 0.55)
    assert(est.fired == true or est.fired == false)
end)

check("bpm grid and tempo change", function()
    local list = {
        { tempo = 120, beat = 4, start = 0, offset = 0 },
        { tempo = 60, beat = 4, start = 4, offset = 0 },
    }
    local a = grid.query(0, list, {})
    eq(a.is_downbeat, true)
    eq(a.beat_index, 0)
    eq(a.beat_in_bar, 0)
    eq(a.source, "list")
    local b = grid.query(0.5, list, {})
    eq(b.beat_index, 1)
    eq(b.is_downbeat, false)
    eq(b.beat_in_bar, 1)
    local c = grid.query(2, list, {})
    eq(c.is_downbeat, true)
    eq(c.bar_index, 1)
    local d = grid.query(4, list, {})
    eq(d.tempo, 60)
    eq(d.beat_index, 0)
    eq(d.is_downbeat, true)
    local e = grid.query(5, list, {})
    eq(e.beat_index, 1)
    eq(e.is_downbeat, false)
    local manual = grid.query(0.5, nil, { tempo = 120, offset = 0 })
    eq(manual.source, "manual")
    eq(manual.beat_index, 1)
    local shifted = grid.query(0.5, nil, { tempo = 120, offset = 0.5 })
    eq(shifted.beat_index, 2)
    local sub = grid.query(0.25, nil, { tempo = 120, subdivision = 2 })
    near(sub.beat_phase, 0.5, 1e-9)
    near(sub.sub_phase, 0, 1e-9)
end)

check("envelope depends only on age", function()
    local a = motion.envelope(0.05, 0.2, "outQuad")
    local b = motion.envelope(0.05, 0.2, "outQuad")
    eq(a, b)
    eq(motion.envelope(0, 0.2, "linear"), 1)
    eq(motion.envelope(0.2, 0.2, "linear"), 0)
    assert(motion.envelope(0.05, 0.2, "linear") > motion.envelope(0.15, 0.2, "linear"))
    local ctx = {
        grid = grid.query(0, nil, { tempo = 120 }),
        audio = { rms = 0, bass = 0, mid = 0, high = 0 },
        beat = { age = math.huge, strength = 0 },
        decay = 0.2,
        accent = 0.5,
        stagger = 0,
    }
    local down = motion.driver("downbeat", ctx, "linear")
    assert(down > 1, tostring(down))
end)

check("layout is seeded and stays inside", function()
    local a = layout.positions("scatter", 20, 7, 640, 360, 20)
    local b = layout.positions("scatter", 20, 7, 640, 360, 20)
    local c = layout.positions("scatter", 20, 8, 640, 360, 20)
    eq(#a, 20)
    eq(a[1].x, b[1].x)
    eq(a[1].y, b[1].y)
    assert(a[1].x ~= c[1].x or a[1].y ~= c[1].y)
    for _, mode in ipairs({ "scatter", "grid", "orbit", "radial" }) do
        local pts = layout.positions(mode, 12, 3, 640, 360, 24)
        eq(#pts, 12)
        for i = 1, #pts do
            assert(pts[i].x >= -320 and pts[i].x <= 320, mode .. " x")
            assert(pts[i].y >= -180 and pts[i].y <= 180, mode .. " y")
        end
    end
end)

check("shape vertex counts", function()
    local circle = shape.build({ kind = "circle", size = 40, fill = true, outline = false, alpha = 1 })
    eq(#circle, shape.CIRCLE_SEGMENTS * 3)
    local square = shape.build({ kind = "square", size = 40, fill = true, outline = false, alpha = 1 })
    eq(#square, 12)
    local tri = shape.build({ kind = "triangle", size = 40, fill = true, outline = false, alpha = 1 })
    eq(#tri, 3)
    local poly = shape.build({ kind = "polygon", sides = 6, size = 40, fill = true, outline = false, alpha = 1 })
    eq(#poly, 18)
    local line = shape.build({ kind = "line", size = 40, line_width = 4, alpha = 1 })
    eq(#line, 6)
    local rect = shape.build({ kind = "rect", w = 80, h = 20, fill = true, outline = false, alpha = 1 })
    eq(#rect, 12)
    local both = shape.build({ kind = "square", size = 40, fill = true, outline = true, line_width = 4, alpha = 1 })
    eq(#both % 3, 0)
    assert(#both > #square)
    eq(shape.kind_for("mixed", 1), "circle")
    eq(shape.kind_for("mixed", 5), "line")
    eq(shape.kind_for("mixed", 6), "circle")
end)

check("presets expose required keys and tracks win", function()
    for id = 0, 6 do
        local p = preset.profiles[id]
        assert(p, "missing profile " .. id)
        for i = 1, #preset.required_keys do
            local key = preset.required_keys[i]
            assert(p[key] ~= nil, preset.names[id] .. " missing " .. key)
        end
    end
    local cfg = preset.apply({
        preset = 1,
        count = 10,
        size = 20,
        shape = 1,
        scale_amt = 50,
        color = 0xff0000,
    })
    eq(cfg.shape, "mixed")
    eq(cfg.count, 10)
    eq(cfg.size, 20)
    eq(cfg.scale_amt, 50)
    eq(cfg.color, 0xff0000)
    local custom = preset.apply({ preset = 0, shape = 1, layout = 1, ease = 0, count = 3 })
    eq(custom.shape, "square")
    eq(custom.layout, "grid")
    eq(custom.ease, "linear")
    local flat = preset.apply({ preset = 6, color = 0x4ec8f0, scale_amt = 80, alpha = 100 })
    eq(flat.layout, "figure")
end)

check("flat figure stays inside the frame", function()
    local sw, sh = 1920, 1080
    local parts = figure.parts(sw, sh)
    local kinds = {}
    for i = 1, #parts do
        local p = parts[i]
        kinds[p.kind] = true
        local hw = (p.w or p.size or 0) * 0.5
        local hh = (p.h or p.size or 0) * 0.5
        assert(p.x - hw >= -sw * 0.5 - 0.01, p.role or "")
        assert(p.x + hw <= sw * 0.5 + 0.01, p.role or "")
        assert(p.y - hh >= -sh * 0.5 - 0.01, p.role or "")
        assert(p.y + hh <= sh * 0.5 + 0.01, p.role or "")
    end
    assert(kinds.rect and kinds.circle and kinds.triangle, "kinds")
    local frame = host.build_frame({
        scene_time = 0.5,
        screen_w = 640,
        screen_h = 360,
        ui = {
            preset = 6,
            color = 0x112233,
            scale_amt = 0,
            alpha = 100,
            sync_mode = 1,
            bpm = 126,
            count = 4,
            size = 20,
            fill = true,
            outline = false,
        },
    })
    eq(frame.cfg.layout, "figure")
    assert(#frame.vertices >= 36, "vertices")
    local bg = frame.vertices[1]
    eq(bg[4], 0x11 / 255)
end)

check("frame is deterministic across a seek", function()
    local ui = {
        preset = 0,
        sync_mode = 1,
        bpm = 120,
        shape = 0,
        layout = 2,
        ease = 1,
        count = 8,
        size = 36,
        line_width = 3,
        alpha = 100,
        seed = 4,
        sides = 5,
        fill = true,
        outline = true,
        color = 0x66ccff,
        scale_amt = 0,
        rotate_amt = 0,
        move_amt = 0,
        decay_ms = 160,
        accent = 0,
        subdivision = 1,
        map_scale = 0,
        map_rotate = 0,
        map_move = 0,
        map_alpha = 0,
        map_color = 0,
        map_width = 0,
    }
    local function frame(time)
        return host.build_frame({
            scene_time = time,
            screen_w = 640,
            screen_h = 360,
            ui = ui,
            pcm = {},
            rate = 48000,
        })
    end
    local a = frame(1.25)
    local b = frame(1.25)
    local c = frame(3.5)
    eq(#a.vertices, #b.vertices)
    assert(#a.vertices > 0)
    eq(#a.vertices % 3, 0)
    for i = 1, #a.vertices do
        for k = 1, 7 do
            eq(a.vertices[i][k], b.vertices[i][k])
        end
        assert(a.vertices[i][1] >= -320 and a.vertices[i][1] <= 320)
        assert(a.vertices[i][2] >= -180 and a.vertices[i][2] <= 180)
    end
    local differ = false
    local n = math.min(#a.vertices, #c.vertices)
    for i = 1, n do
        if a.vertices[i][1] ~= c.vertices[i][1] or a.vertices[i][2] ~= c.vertices[i][2] then
            differ = true
            break
        end
    end
    assert(differ or #a.vertices ~= #c.vertices, "time change should move the frame")
end)

check("scene time uses frame origin", function()
    near(host.scene_time(30, 15, 30), 1.5, 1e-9)
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then
    os.exit(1)
end
