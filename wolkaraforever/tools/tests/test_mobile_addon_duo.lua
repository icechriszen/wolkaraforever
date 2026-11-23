-- The Interface mobile add-on's two Duo arrangements - the corner skill fan (addons/WolkaraRoue/
-- Fan.lua) and the quick bar (addons/WolkaraRoue/QuickBar.lua) - run outside the game. What is
-- asserted: each one fills its own defaults, keeps every stored value inside the range the
-- settings page offers, repairs a value a hand-edited save put outside it, and reports itself
-- on only when the Duo layout is the chosen interface. The quick bar also takes the free
-- slots a save from before pages had.
--
-- usage: luajit test_mobile_addon_duo.lua <addons/WolkaraRoue>

local directory = assert(arg[1], "usage: luajit test_mobile_addon_duo.lua <addons/WolkaraRoue>")

local duo = true
local modules = {}
local ns = {}
ns.db = {}
function ns.Register(name, module) modules[name] = module; return module end
function ns.Clamp(value, low, high)
    if not value or value ~= value then return low end
    if value < low then return low elseif value > high then return high end
    return value
end
function ns.DuoLayout() return duo end
function ns.Print() end
function ns.On() end
function ns.Guard(_, fn, ...) return fn(...) end
ns.MAX_FREE, ns.MAX_SLOTS, ns.MAX_WHEELS = 8, 6, 4
ns.T = function(text) return text end

-- A frame: anything it is asked to do answers nothing, as a stand-in, so a module's own
-- frame at load time cannot stop the suite.
local function Frame()
    local frame = {}
    function frame:GetFrameLevel() return 1 end
    function frame:CreateTexture() return Frame() end
    function frame:CreateFontString() return Frame() end
    setmetatable(frame, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
    return frame
end
CreateFrame = function() return Frame() end
UIParent = Frame()
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local function Load(file)
    assert(loadfile(directory .. "/" .. file))("WolkaraRoue", ns)
    return modules
end

Load("Fan.lua")
assert(ns.Fan, "Fan.lua registered no module")
local fan = ns.Fan.Settings()
assert(fan.enabled == true and fan.size == 56 and fan.radius == 30, "the fan's defaults are not what ships")
assert(fan.page == 1 and fan.style == "wheel" and fan.duoLayout == 2)
assert(fan.offsets[1] == 0 and fan.offsets[2] == 0, "a fresh fan starts off-centre")
assert(ns.Fan:Enabled() == true, "the fan is off in the Duo layout")
-- A save a hand edit put outside the ranges the settings page offers is brought back inside.
ns.db.fan.size, ns.db.fan.radius, ns.db.fan.page = 500, 1, 7
ns.db.fan.offsets = { 9, -3 }
fan = ns.Fan.Settings()
assert(fan.size == 80 and fan.radius == 22, "a stored fan size or radius escaped its range")
assert(fan.page == 1, "a stored page outside the two pages was kept")
assert(fan.offsets[1] == 5 and fan.offsets[2] == 0, "a stored offset escaped its range")
ns.db.fan.style = "star"
assert(ns.Fan.Settings().style == "pages", "an unknown fan style was kept")
ns.db.fan.enabled = false
assert(ns.Fan:Enabled() == false, "a fan switched off still reports itself on")
duo = false
assert(ns.Fan:Enabled() == false, "the fan is on in the Standard interface")
duo = true
-- The cursor angle is not guessed at when the game cannot give the cursor.
assert(ns.FanCursorAngle() == nil, "the fan placed itself from a cursor it does not have")

ns.db = {}
Load("QuickBar.lua")
assert(ns.Quick, "QuickBar.lua registered no module")
local quick = ns.Quick.Settings()
assert(quick.enabled == true and quick.count == 5 and quick.size == 46 and quick.page == 1)
assert(quick.open == true and quick.fiveSlots == true, "the quick bar's defaults are not what ships")
ns.db.quick.count, ns.db.quick.size, ns.db.quick.page = 99, 1, 9
quick = ns.Quick.Settings()
assert(quick.count == 5 and quick.size == 36 and quick.page == 5, "a stored quick bar value escaped its range")
-- A save from before the bar had pages: its slots become the first page, once.
ns.db.quick = { enabled = true, entries = { { kind = "spell", id = 11 }, { kind = "spell", id = 12 } } }
quick = ns.Quick.Settings()
assert(quick.pages[1][1].id == 11 and quick.pages[1][2].id == 12, "the old free slots were not taken as page one")
assert(quick.entries == nil, "the old free slots were left behind")
quick = ns.Quick.Settings()
assert(quick.pages[1][1].id == 11, "the old free slots were taken twice")
ns.db.quick.enabled = false
assert(ns.Quick:Enabled() == false, "a quick bar switched off still reports itself on")
ns.db.quick.enabled = true
duo = false
assert(ns.Quick:Enabled() == false, "the quick bar is on in the Standard interface")

print("mobile add-on Duo arrangements: the fan and the quick bar fill their defaults, keep every stored value in range, repair a hand-edited one, take a pre-pages save once, and are on only in the Duo layout: PASS")

-- ChatTab must leave the standard panel's own close action usable. Its former
-- unconditional Hide plus Show=Hide removed the only exit even with Duo off.
do
    local frames = {}
    local function Mock(name, parent)
        local f = { shown = true, hooks = {}, scripts = {}, children = {}, textValue = "" }
        function f:SetScript(event, fn) self.scripts[event] = fn end
        function f:HookScript(event, fn)
            self.hooks[event] = self.hooks[event] or {}
            table.insert(self.hooks[event], fn)
        end
        function f:Fire(event)
            if self.scripts[event] then self.scripts[event](self) end
            for _, fn in ipairs(self.hooks[event] or {}) do fn(self) end
        end
        function f:Show() if not self.shown then self.shown = true; self:Fire("OnShow") end end
        function f:Hide() if self.shown then self.shown = false; self:Fire("OnHide") end end
        function f:SetShown(value) if value then self:Show() else self:Hide() end end
        function f:IsShown() return self.shown end
        function f:GetChildren() return unpack(self.children) end
        function f:GetWidth() return 1200 end
        function f:GetHeight() return 600 end
        function f:GetFrameLevel() return 1 end
        function f:GetFrameStrata() return "DIALOG" end
        function f:SetText(text) self.textValue = text end
        function f:GetText() return self.textValue end
        setmetatable(f, { __index = function(_, key)
            if key:match("^%u") then return function() end end
        end })
        if parent then table.insert(parent.children, f) end
        if name then frames[name] = f; _G[name] = f end
        return f
    end
    CreateFrame = function(_, name, parent) return Mock(name, parent) end
    UIParent = Mock("UIParent")
    local panel = Mock("WolkaraMobileChat", UIParent)
    local ticker = Mock("WolkaraMobileChatTicker", UIParent)
    panel:Hide()
    local chat = { db = { layout = "standard", language = "zhCN", chat = { custom = true, fontSize = 16 } } }
    function chat.Register(_, module) return module end
    function chat.On() end
    function chat.UIButton(parent, text, _, _, click)
        local b = Mock(nil, parent); b.text = Mock(); b.text:SetText(text); b.back = Mock(); b.click = click; return b
    end
    function chat.Label(_, _, text) local f = Mock(); f:SetText(text or ""); return f end
    function chat.Box() return Mock() end
    GetLocale = function() return "zhCN" end
    assert(loadfile(directory .. "/Language.lua"))("WolkaraRoue", chat)
    local function Close() panel:Hide(); ticker:Show() end
    local close = chat.UIButton(panel, "X", 44, 36, Close)
    local originalShow = close.Show
    chat.Chat = { Close = Close, Open = function() panel:Show(); ticker:Hide() end }
    assert(loadfile(arg[2] or directory .. "/ChatTab.lua"))("WolkaraRoue", chat)
    chat.ChatTab:Init(); chat.ChatTab:Layout()
    assert(close:IsShown(), "Standard chat lost its close button")
    assert(close.Show == originalShow, "ChatTab replaced the close button's Show method")
    panel:Show(); close.click()
    assert(not panel:IsShown() and ticker:IsShown(), "Standard close does not restore the chat strip")
    assert(chat.db.language == "zhCN" and chat.ChatTab.button.text:GetText() == "聊天")
    chat.db.layout = "duo"; chat.ChatTab:Layout()
    assert(not close:IsShown() and chat.ChatTab.button:IsShown())
    chat.db.chatTab.enabled = false; chat.ChatTab:Layout()
    assert(close:IsShown() and not chat.ChatTab.button:IsShown(), "Disabled Duo pill must restore X")
    chat.db.chatTab.enabled = true; chat.ChatTab:Layout()
    assert(not close:IsShown())
    chat.db.layout = "standard"; chat.ChatTab:Layout()
    assert(close:IsShown() and close.Show == originalShow, "Returning to Standard did not restore X")
    panel:Show(); close.click()
    assert(not panel:IsShown() and ticker:IsShown())
    assert(chat.db.language == "zhCN" and chat.db.layout == "standard")
    print("mobile chat: Standard close/click, Duo pill gating, disabled-pill fallback, layout roundtrip, unmodified frame methods and Chinese preference: PASS")
end
