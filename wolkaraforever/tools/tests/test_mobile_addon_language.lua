-- Add-on language behavior; no game state or gameplay automation.
local root = assert(arg[1])
local locale = "zhCN"
GetLocale = function() return locale end
local ns = {}
assert(loadfile(root .. "/Language.lua"))("WolkaraRoue", ns)
assert(ns.T("Character") == "角色", "translation before settings load must follow the game")
ns.NextLanguage() -- a pre-settings call must not invent or overwrite a save
assert(ns.db == nil)
local saved = { marker = { 42 }, layout = "standard", wheels = { { entries = { 123 } } } }
ns.db = saved
assert(ns.LanguageName() == "跟随游戏")
local expected = { Character = "角色", Bags = "背包", Spells = "技能", Quests = "任务",
    Map = "世界地图", Social = "社交", Guild = "公会", Macros = "宏", Close = "关闭",
    ["Game Settings"] = "设置选项", ["Mobile UI"] = "触屏界面", ["Log Out"] = "返回角色选择" }
for key, value in pairs(expected) do assert(ns.T(key) == value, key) end
assert(ns.T("Spells", "menu") == "法术书" and ns.T("Quests", "menu") == "任务日志")
assert(ns.T("General") == "常规" and ns.T("General", "chat") == "综合")
assert(ns.T("General", "spell") == "综合")
assert(ns.T("Instance") == "副本" and ns.T("Actions") == "操作")
-- Fixtures stand in for client-owned strings. Prefer them at lookup time, so
-- client wording changes do not require another hardcoded translation release.
CHARACTER_BUTTON = "客户端角色标签"
SPELLBOOK_ABILITIES_BUTTON = "客户端法术书标签"
QUESTLOG_BUTTON = "客户端任务日志标签"
GAMEMENU_OPTIONS = "客户端设置标签"
LOG_OUT = "客户端退出登录标签"
GENERAL = "客户端综合标签"
assert(ns.T("Character") == CHARACTER_BUTTON)
assert(ns.T("Spells", "menu") == SPELLBOOK_ABILITIES_BUTTON)
assert(ns.T("Quests", "menu") == QUESTLOG_BUTTON)
assert(ns.T("Game Settings") == GAMEMENU_OPTIONS and ns.T("Log Out") == LOG_OUT)
assert(ns.T("General", "chat") == GENERAL and ns.T("General", "spell") == GENERAL)
assert(ns.T("Spells") == "技能" and ns.T("Quests") == "任务" and ns.T("General") == "常规")
SPELLBOOK_ABILITIES_BUTTON = ""; SPELLBOOK_BUTTON = "客户端另一法术书标签"
assert(ns.T("Spells", "menu") == SPELLBOOK_BUTTON)
SPELLBOOK_ABILITIES_BUTTON = {}; SPELLBOOK_BUTTON = function() error("must not call UI globals") end
assert(ns.T("Spells", "menu") == "法术书", "non-string globals must not be called or displayed")
CHARACTER_BUTTON = ""; assert(ns.T("Character") == "角色")
CHARACTER_BUTTON = "客户端角色标签"
assert(string.format(ns.T("Preset %d"), 3) == "预设 3")
assert(string.format(ns.T("Quests (%d)  %s"), 4, "+") == "任务（4）  +")
assert(string.format(ns.T("%s[%s] %s: %s"), "", "小队", "名字", "消息") == "[小队] 名字：消息")
assert(ns.T("untranslated future key") == "untranslated future key")
assert(saved.language == nil and saved.marker[1] == 42 and saved.wheels[1].entries[1] == 123)
ns.db.language = "enUS"
assert(ns.T("Character") == "Character" and ns.LanguageName() == "English")
assert(ns.T("Spells", "menu") == "Spells" and ns.T("Quests", "menu") == "Quests")
assert(ns.T("General", "chat") == "General" and ns.T("Game Settings") == "Game Settings")
ns.db.language = "frFR"
assert(ns.T("Character") == "Personnage" and ns.LanguageName() == "Français")
ns.db.language = "zhCN"; locale = "enUS"
assert(ns.T("Character") == "角色" and ns.LanguageName() == "简体中文")
assert(ns.T("Spells", "menu") == "法术书" and ns.T("Quests", "menu") == "任务日志")
assert(ns.T("General", "chat") == "综合" and ns.T("Game Settings") == "设置选项")
ns.db.language = "auto"
for _, code in ipairs({ "enUS", "enGB", "ruRU", "zhTW" }) do
    locale = code; assert(ns.T("Character") == "Character", code)
end
locale = "esMX"; assert(ns.T("Character") == "Personaje")
locale = "deDE"; assert(ns.T("Character") == "Charakter")
CHARACTER_BUTTON, SPELLBOOK_ABILITIES_BUTTON, SPELLBOOK_BUTTON = nil, nil, nil
QUESTLOG_BUTTON, GAMEMENU_OPTIONS, LOG_OUT, GENERAL = nil, nil, nil, nil
locale = "zhCN"; ns.db.language = "bad saved value"
assert(ns.T("Character") == "角色" and ns.db.language == "bad saved value")
ns.NextLanguage(); assert(ns.db.language == "enUS")
local visited = {}
for i = 1, 6 do
    assert(not visited[ns.db.language], "language selection cycle repeats early")
    visited[ns.db.language] = true; ns.NextLanguage()
end
assert(ns.db.language == "enUS" and visited.zhCN and visited.auto)
GetLocale = nil; ns.db.language = "auto"
assert(ns.T("Character") == "Character" and ns.LanguageName() == "Follow game")
GetLocale = function() return "zhCN" end
local init
ns.Register = function(name, module) assert(name == "Bindings"); init = module.Init end
assert(loadfile(root .. "/Bindings.lua"))("WolkaraRoue", ns)
assert(BINDING_HEADER_WOLKARAMOBILE == "触屏界面")
assert(_G["BINDING_NAME_CLICK WolkaraMobileToggle2:LeftButton"] == "开关轮盘 2")
ns.db.language = "enUS"; init()
assert(BINDING_HEADER_WOLKARAMOBILE == "Mobile Interface")
assert(saved.marker[1] == 42 and saved.wheels[1].entries[1] == 123 and saved.layout == "standard")
print("mobile language: zhCN defaults, game labels, contexts, explicit choices, fallback, cycling, formats, bindings and save preservation PASS")
