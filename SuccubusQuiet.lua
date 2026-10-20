-- Succubus Quiet 3.0
-- Two sliders:
--   Frequency (0-100%): how often the tracked sounds are audible overall.
--   Whip/Moan balance (0-100): 0 = moans only, 50 = balanced, 100 = whips only.
-- Whip and moan sound files are tracked as separate groups, so the addon
-- needs you to tell it which FileDataID is which (/sq add whip <id>).
-- Each tick every group is muted/unmuted by its own dice roll:
--   whip chance = frequency * min(1, balance / 50)
--   moan chance = frequency * min(1, (100 - balance) / 50)
-- Animations cannot be changed by addons; only sounds are affected.

local ADDON = ...
local TICK = 2 -- seconds between rolls
local GROUPS = { "whip", "moan", "other" }

-- Optional built-in FileDataIDs, e.g.  whip = { 123456, 123457 },
local DEFAULT_IDS = {
    whip = {},
    moan = {},
}

local db, ticker
local audible = {}

local function Print(msg)
    print("|cffb266ffSuccubusQuiet:|r " .. tostring(msg))
end

local function Chance(group)
    if not db.enabled then return 100 end
    local f, b = db.frequency, db.balance
    if group == "whip" then return f * math.min(1, b / 50) end
    if group == "moan" then return f * math.min(1, (100 - b) / 50) end
    return f
end

local function SetAudible(group, state)
    if audible[group] == state then return end
    audible[group] = state
    for id in pairs(db.ids[group]) do
        if state then UnmuteSoundFile(id) else MuteSoundFile(id) end
    end
end

local function Roll()
    for _, g in ipairs(GROUPS) do
        SetAudible(g, math.random() * 100 < Chance(g))
    end
end

local function Refresh()
    if ticker then ticker:Cancel(); ticker = nil end
    wipe(audible)
    local needTimer = false
    for _, g in ipairs(GROUPS) do
        local c = Chance(g)
        if c >= 100 then SetAudible(g, true)
        elseif c <= 0 then SetAudible(g, false)
        else needTimer = true end
    end
    if needTimer then
        Roll()
        ticker = C_Timer.NewTicker(TICK, Roll)
    end
end

local function Clamp(v) return math.max(0, math.min(100, math.floor(v + 0.5))) end

local function FindGroup(id)
    for _, g in ipairs(GROUPS) do if db.ids[g][id] then return g end end
end

local function AddId(group, id)
    local old = FindGroup(id)
    if old then db.ids[old][id] = nil; UnmuteSoundFile(id) end
    db.ids[group][id] = true
    Refresh()
end

local function RemoveId(id)
    local g = FindGroup(id)
    if g then db.ids[g][id] = nil end
    UnmuteSoundFile(id)
end

local function BuildSettings()
    local ok, err = pcall(function()
        local category = Settings.RegisterVerticalLayoutCategory("Succubus Quiet")

        local function AddSlider(key, label, tooltip, formatter)
            local setting = Settings.RegisterAddOnSetting(
                category, "SUCCUBUSQUIET_" .. key:upper(), key, db,
                Settings.VarType.Number, label, 100 * (key == "frequency" and 1 or 0.5))
            setting:SetValueChangedCallback(function(_, value)
                db[key] = Clamp(value); Refresh()
            end)
            local options = Settings.CreateSliderOptions(0, 100, 5)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
            Settings.CreateSlider(category, setting, options, tooltip)
        end

        AddSlider("frequency", "Overall sound frequency",
            "0% = silent, 100% = normal game behavior.",
            function(v) return v .. "%" end)
        AddSlider("balance", "Whip / moan balance",
            "0 = moans only, 50 = balanced, 100 = whips only.",
            function(v)
                if v == 50 then return "Balanced" end
                if v < 50 then return (100 - v) .. "% moan bias" end
                return v .. "% whip bias"
            end)

        Settings.RegisterAddOnCategory(category)
        SuccubusQuiet_CategoryID = category:GetID()
    end)
    if not ok then
        Print("Options panel unavailable (" .. tostring(err) .. "). Use /sq freq and /sq balance.")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")

    SuccubusQuietDB = SuccubusQuietDB or {}
    db = SuccubusQuietDB
    db.ids = db.ids or {}
    -- migrate v2 flat list (db.ids[id] = true) into the "other" group
    local migrated = {}
    for k, v in pairs(db.ids) do
        if type(k) == "number" then migrated[k] = true; db.ids[k] = nil end
    end
    for _, g in ipairs(GROUPS) do db.ids[g] = db.ids[g] or {} end
    for id in pairs(migrated) do db.ids.other[id] = true end
    for _, g in ipairs({ "whip", "moan" }) do
        for _, id in ipairs(DEFAULT_IDS[g] or {}) do db.ids[g][id] = true end
    end
    if db.enabled == nil then db.enabled = true end
    db.frequency = db.frequency or 100
    db.balance = db.balance or 50

    BuildSettings()
    Refresh()

    SLASH_SUCCUBUSQUIET1 = "/sq"
    SLASH_SUCCUBUSQUIET2 = "/succubusquiet"
    SlashCmdList["SUCCUBUSQUIET"] = function(msg)
        local cmd, a, b = strsplit(" ", strtrim(msg or ""), 3)
        cmd = (cmd or ""):lower()
        local n = tonumber(a)

        if cmd == "freq" and n then
            db.frequency = Clamp(n); Refresh(); Print("Frequency " .. db.frequency .. "%")
        elseif cmd == "balance" and n then
            db.balance = Clamp(n); Refresh()
            Print("Balance " .. db.balance .. " (0 = moans only, 100 = whips only)")
        elseif cmd == "add" and (a == "whip" or a == "moan" or a == "other") and tonumber(b) then
            AddId(a, tonumber(b)); Print("Added " .. b .. " as " .. a)
        elseif cmd == "remove" and n then
            RemoveId(n); Print("Removed " .. n)
        elseif cmd == "list" then
            for _, g in ipairs(GROUPS) do
                local ids = {}
                for id in pairs(db.ids[g]) do ids[#ids + 1] = id end
                table.sort(ids)
                Print(g .. ": " .. (#ids > 0 and table.concat(ids, ", ") or "(none)"))
            end
            Print("Frequency " .. db.frequency .. "%, balance " .. db.balance)
        elseif cmd == "on" then
            db.enabled = true; Refresh(); Print("Enabled.")
        elseif cmd == "off" then
            db.enabled = false; Refresh(); Print("Disabled (normal sounds).")
        elseif cmd == "test" and n then
            PlaySoundFile(n)
        elseif cmd == "options" and SuccubusQuiet_CategoryID then
            Settings.OpenToCategory(SuccubusQuiet_CategoryID)
        else
            Print("/sq options | freq <0-100> | balance <0-100> | add whip|moan <id> | remove <id> | list | on | off | test <id>")
        end
    end
end)
