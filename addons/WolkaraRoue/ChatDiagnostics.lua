-- Public chat UI observations only: never submit or retry. Persist only counts,
-- lengths and fixed enums, never text, names, recipients or player identifiers.
local _, ns = ...
local D = ns.Register("ChatDiagnostics", {})
ns.ChatDiagnostics = D
local record
local hooked = setmetatable({}, { __mode = "k" })
local apiHooks = {}
local STAGES = { open = true, ready = true, unavailable = true, unfocused = true,
    focus = true, blur = true, text = true, clear = true, enter = true,
    sendText = true, modernAPI = true, legacyAPI = true, echo = true,
    rendered = true, uiError = true, binding = true }
local TYPES = {}
for _, name in ipairs({ "SAY", "YELL", "EMOTE", "TEXT_EMOTE", "PARTY", "PARTY_LEADER",
    "RAID", "RAID_LEADER", "RAID_WARNING", "GUILD", "OFFICER", "WHISPER",
    "WHISPER_INFORM", "CHANNEL", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" }) do
    TYPES[name] = true
end

local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function ChatType(value)
    return Public(value) and type(value) == "string" and TYPES[value] and value or "unknown"
end
local function TextSize(text)
    if not Public(text) or type(text) ~= "string" then return -1, false end
    return #text, text:sub(1, 1) == "/"
end
local function Safe(fn, ...)
    if not record then return end
    if not pcall(fn, ...) then record.observerErrors = record.observerErrors + 1 end
end
local function Append(stage, item)
    if not record or not STAGES[stage] then return end
    record.counts[stage] = (record.counts[stage] or 0) + 1
    record.sequence = record.sequence + 1
    item = item or {}
    item.stage, item.sequence = stage, record.sequence
    -- Coalesce typing; a subsequent clear must retain the last non-empty size.
    if stage == "text" then
        record.lastTextBytes = item.bytes
        if record.events[#record.events] and record.events[#record.events].stage == stage then
            record.events[#record.events] = item
            return
        end
    end
    record.events[#record.events + 1] = item
    if #record.events > 32 then table.remove(record.events, 1) end
end
local function Snapshot(box)
    local item = {}
    item.bytes, item.command = TextSize(box.GetText and box:GetText())
    local focus = box.HasFocus and box:HasFocus()
    item.focus = Public(focus) and not not focus
    local kind = box.GetChatType and box:GetChatType()
        or (box.GetAttribute and box:GetAttribute("chatType"))
    item.chatType = ChatType(kind)
    return item
end

function D:Mark(stage, box)
    Safe(function() Append(stage, box and Snapshot(box)) end)
end
function D:Binding()
    Safe(function()
        local action = GetBindingAction and GetBindingAction("F12", true)
        local matched = Public(action) and action == "CLICK WolkaraMobileChatOpener:LeftButton"
        record.binding = not not matched
        Append("binding", { matched = not not matched })
    end)
end
function D:Attach(box)
    if not box or hooked[box] or type(box.HookScript) ~= "function" then return end
    hooked[box] = true
    for script, stage in pairs({ OnEditFocusGained = "focus", OnEditFocusLost = "blur",
        OnTextChanged = "text", OnEnterPressed = "enter" }) do
        local ok = pcall(box.HookScript, box, script, function(self)
            Safe(function()
                local item = Snapshot(self)
                local event = stage == "text" and item.bytes == 0 and "clear" or stage
                -- This post-hook may see an already cleared box on Enter.
                -- sendText and API events record the earlier text length.
                Append(event, item)
            end)
        end)
        if record then record.hooks[script] = record.hooks[script] or ok end
    end
    if type(hooksecurefunc) == "function" and type(box.SendText) == "function" then
        local ok = pcall(hooksecurefunc, box, "SendText", function(self) D:Mark("sendText", self) end)
        if record then record.hooks.sendText = record.hooks.sendText or ok end
    end
end
local function ObserveAPI(stage, text, kind)
    Safe(function()
        local bytes, command = TextSize(text)
        Append(stage, { bytes = bytes, command = command, chatType = ChatType(kind) })
    end)
end
local function AttachAvailable()
    D:Attach(DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do D:Attach(_G["ChatFrame" .. i .. "EditBox"]) end
    if type(hooksecurefunc) ~= "function" then return end
    if not apiHooks.modernAPI and C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        apiHooks.modernAPI = pcall(hooksecurefunc, C_ChatInfo, "SendChatMessage", function(text, kind)
            ObserveAPI("modernAPI", text, kind)
        end)
    end
    if not apiHooks.legacyAPI and type(SendChatMessage) == "function" then
        apiHooks.legacyAPI = pcall(hooksecurefunc, "SendChatMessage", function(text, kind)
            ObserveAPI("legacyAPI", text, kind)
        end)
    end
    record.hooks.modernAPI = not not apiHooks.modernAPI
    record.hooks.legacyAPI = not not apiHooks.legacyAPI
end
local function IsOwn(event, guid)
    if event == "CHAT_MSG_WHISPER_INFORM" then return true end
    if not Public(guid) or type(guid) ~= "string" or guid == "" then return false end
    local mine = UnitGUID and UnitGUID("player")
    return Public(mine) and type(mine) == "string" and guid == mine
end
function D:Rendered(event, guid, visible)
    Safe(function()
        if IsOwn(event, guid) then
            Append("rendered", { chatType = ChatType(event:sub(10)), visible = not not visible })
        end
    end)
end
function D:Init()
    if record then return end
    record = { schema = 1, version = "1.0.5-cn.7", sequence = 0, counts = {},
        events = {}, hooks = {}, observerErrors = 0, lastTextBytes = 0 }
    ns.db.chatDiagnostics = record
    Safe(AttachAvailable)
end
function D:Report()
    if not record then return end
    local c = record.counts
    ns.Print(ns.T("Chat trace: open=%d, text=%d, Return=%d, API=%d/%d, echo=%d, display=%d."):format(
        c.open or 0, c.text or 0, c.enter or 0, c.modernAPI or 0, c.legacyAPI or 0,
        c.echo or 0, c.rendered or 0))
    ns.Print(ns.T("Chat trace: last text bytes=%d, observer errors=%d. Saved on normal logout; no message content is recorded."):format(
        record.lastTextBytes, record.observerErrors))
end
for kind in pairs(TYPES) do
    local event = "CHAT_MSG_" .. kind
    ns.On(event, function(...)
        local guid = select(12, ...)
        Safe(function() if IsOwn(event, guid) then Append("echo", { chatType = kind }) end end)
    end)
end
ns.On("UI_ERROR_MESSAGE", function(code)
    Safe(function()
        local id = Public(code) and type(code) == "number" and code or -1
        Append("uiError", { code = id })
    end)
end)
ns.On("PLAYER_LOGIN", function() Safe(AttachAvailable) end)
ns.On("UPDATE_CHAT_WINDOWS", function() Safe(AttachAvailable) end)
