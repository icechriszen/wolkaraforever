-- Public API fixtures only; no client/game input or network messages.
local source = assert(arg[1])
local function Fixture(legacy, rejectHooks)
    local hooks, events, output = {}, {}, {}
    local sends = 0
    local box = { value = "", focus = false, kind = "SAY", scripts = {} }
    function box:GetText() return self.value end
    function box:HasFocus() return self.focus end
    function box:GetChatType() return self.kind end
    function box:HookScript(name, callback)
        if rejectHooks then error("unsupported hook") end
        self.scripts[name] = callback
    end
    function box:Fire(name) if self.scripts[name] then self.scripts[name](self) end end
    function box:SendText() sends = sends + 1 end
    DEFAULT_CHAT_FRAME = { editBox = box }
    ChatFrame1EditBox = box
    NUM_CHAT_WINDOWS = 1
    UnitGUID = function() return "private-player-id" end
    GetBindingAction = function(key, overrides)
        assert(key == "F12" and overrides)
        return "CLICK WolkaraMobileChatOpener:LeftButton"
    end
    local secret = setmetatable({}, { __tostring = function() error("secret read") end })
    issecretvalue = function(value) return rawequal(value, secret) end
    C_ChatInfo = not legacy and { SendChatMessage = function() sends = sends + 1 end } or nil
    SendChatMessage = legacy and function() sends = sends + 1 end or nil
    hooksecurefunc = function(owner, key, callback)
        if rejectHooks then error("unsupported hook") end
        if type(owner) == "string" then owner, key, callback = _G, owner, key end
        assert(type(owner[key]) == "function")
        hooks[key] = callback
        -- Store the post-hook separately; the test, not the observer, supplies
        -- simulated callbacks. Calling a real/send stub would increment sends.
    end
    local ns = { db = { language = "zhCN", layout = "standard", skills = { 42 } } }
    ns.Register = function(_, module) return module end
    ns.On = function(name, callback) events[name] = callback end
    ns.T = function(text) return text end
    ns.Print = function(text) output[#output + 1] = text end
    assert(loadfile(source))("WolkaraRoue", ns)
    ns.ChatDiagnostics:Init()
    events.PLAYER_LOGIN()
    events.UPDATE_CHAT_WINDOWS()
    return ns, box, hooks, events, output, secret, function() return sends end
end

for _, legacy in ipairs({ false, true }) do
    local ns, box, hooks, events, output, secret, sends = Fixture(legacy)
    local d, record = ns.ChatDiagnostics, ns.db.chatDiagnostics
    assert(ns.db.language == "zhCN" and ns.db.layout == "standard" and ns.db.skills[1] == 42)
    assert(record.hooks.OnEnterPressed and record.hooks.OnTextChanged)
    assert(record.hooks[legacy and "legacyAPI" or "modernAPI"])
    assert(not record.hooks[legacy and "modernAPI" or "legacyAPI"])
    d:Binding(); assert(record.binding)
    d:Mark("open")
    box.focus = true; box:Fire("OnEditFocusGained")
    d:Mark("ready", box)
    box.value = "private 中文 message"
    box:Fire("OnTextChanged")
    local size = #box.value
    hooks.SendChatMessage(box.value, "SAY", 0, "private recipient")
    hooks.SendText(box)
    box.value = ""; box:Fire("OnTextChanged")
    box:Fire("OnEnterPressed")
    box.focus = false; box:Fire("OnEditFocusLost")
    events.CHAT_MSG_SAY("private 中文 message", "private author", nil, nil, nil, nil, nil,
        nil, nil, nil, nil, "other-player-id")
    assert(not record.counts.echo)
    events.CHAT_MSG_SAY("private 中文 message", "private author", nil, nil, nil, nil, nil,
        nil, nil, nil, nil, "private-player-id")
    d:Rendered("CHAT_MSG_SAY", "private-player-id", false)
    assert(record.events[#record.events].visible == false, "hidden tab is distinct from no echo")
    assert(record.counts.echo == 1 and record.counts.rendered == 1)
    assert(record.lastTextBytes == size and record.counts.clear == 1 and record.counts.enter == 1)
    assert(record.counts[legacy and "legacyAPI" or "modernAPI"] == 1)
    assert(record.counts.sendText == 1 and record.observerErrors == 0)
    -- No API call can still be distinguished from an Enter callback.
    box:Fire("OnEnterPressed")
    assert(record.counts.enter == 2 and record.counts[legacy and "legacyAPI" or "modernAPI"] == 1)
    events.UI_ERROR_MESSAGE(42, "private error text")
    assert(record.events[#record.events].code == 42)
    box.value = secret; box.kind = secret; box:Fire("OnTextChanged")
    assert(record.events[#record.events].bytes == -1 and record.events[#record.events].chatType == "unknown")
    events.CHAT_MSG_SAY(secret, secret, nil, nil, nil, nil, nil, nil, nil, nil, nil, secret)
    assert(record.counts.echo == 1 and record.observerErrors == 0)
    box.GetText = function() error("private read error") end
    box:Fire("OnTextChanged")
    assert(record.observerErrors == 1, "observer errors must not escape into input")
    local allowed = { ["1.0.5-cn.7"] = true, unknown = true, SAY = true }
    for key in pairs(record.counts) do allowed[key] = true end
    local function CheckPrivacy(value)
        if type(value) == "table" then
            for _, child in pairs(value) do CheckPrivacy(child) end
        elseif type(value) == "string" then
            assert(allowed[value], "diagnostics persisted a non-enum string")
        else assert(type(value) == "boolean" or type(value) == "number") end
    end
    CheckPrivacy(record)
    for _ = 1, 80 do d:Mark("open") end
    assert(#record.events == 32 and record.counts.open == 81)
    CheckPrivacy(record)
    d:Report(); assert(#output == 2 and sends() == 0, "observing/reporting must not send or retry")
    local count = record.sequence
    d:Init(); assert(ns.db.chatDiagnostics == record and record.sequence == count)
end

local ns, box, hooks, events, output, _, sends = Fixture(false, true)
assert(not ns.db.chatDiagnostics.hooks.OnTextChanged and not ns.db.chatDiagnostics.hooks.modernAPI)
ns.ChatDiagnostics:Report()
assert(sends() == 0 and #output == 2, "unsupported hooks must remain harmless and detectable")
print("chat diagnostics: modern/legacy paths, post-Enter ordering, self echo, hidden display, bounded metadata, secret values and no sends: PASS")
