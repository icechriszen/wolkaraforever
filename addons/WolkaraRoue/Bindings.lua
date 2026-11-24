-- Interface mobile : les noms des raccourcis, dans Échap > Raccourcis (une manette peut
-- ouvrir une roue avec l'un de ses boutons).
local _, ns = ...
local function Names()
    BINDING_HEADER_WOLKARAMOBILE = ns.T("Mobile Interface")
    for i = 1, 4 do
        _G["BINDING_NAME_CLICK WolkaraMobileToggle" .. i .. ":LeftButton"] =
            i == 1 and ns.T("Toggle wheel") or (ns.T("Toggle wheel ") .. i)
    end
end
Names()
-- Saved preferences are loaded after the add-on's files, before module Init.
ns.Register("Bindings", { Init = Names })
