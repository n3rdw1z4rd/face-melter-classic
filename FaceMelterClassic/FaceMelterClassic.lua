local title = ...
local version = GetAddOnMetadata(title, "Version")

-- 
-- Face Melter
-- An addon by Falie, aka Drescan or Aytherine
-- Updated for TBC Classic by sbd74/havoc74
-- Let's squeeze some more DPS out of a broken spec... 
--
-- sbd:set_debug(true)

-- Our base array
FaceMelter = {}

-- Face Melter variables NOT SAVED

FaceMelter.versionNumber = version
FaceMelter.currentTarget = ""
FaceMelter.currentSpell = ""
FaceMelter.lastTarget = ""
FaceMelter.VTTarget = "" -- used for VT tracking as there's no succed on cast,
FaceMelter.npcList = {} -- {guid, name}
FaceMelter.painList = {} -- {guid, GetTime}
FaceMelter.touchList = {} -- {guid, GetTime}
FaceMelter.embraceList = {} -- {guid, GetTime}
FaceMelter.blastTime = 0
FaceMelter.deathTime = 0
FaceMelter.flayTime = 0
FaceMelter.timeSinceLastUpdate = 0
FaceMelter.blastCooldown = 8
FaceMelter.painDuration = 18
FaceMelter.shouldCheckStuff = true

FaceMelter.playerName = UnitName("player")
FaceMelter.spellHaste = GetCombatRatingBonus(20)

FaceMelter.localizedSpellNames = {
    ["VT"] = GetSpellInfo(34914),   -- Vampiric Touch
    ["SWP"] = GetSpellInfo(589),    -- Shadow Word: Pain
    ["VE"] = GetSpellInfo(15286),   -- Vampiric Embrace
    ["MB"] = GetSpellInfo(8092),    -- Mind Blast
    ["SWD"] = GetSpellInfo(32379),  -- Shadow Word: Death
    ["MF"] = GetSpellInfo(15407)    -- Mind Flay
}

FaceMelter.textureList = {
    ["VT"] = GetSpellTexture(FaceMelter.localizedSpellNames["VT"]),
    ["SWP"] = GetSpellTexture(FaceMelter.localizedSpellNames["SWP"]),
    ["VE"] = GetSpellTexture(FaceMelter.localizedSpellNames["VE"]),
    ["MB"] = GetSpellTexture(FaceMelter.localizedSpellNames["MB"]),
    ["SWD"] = GetSpellTexture(FaceMelter.localizedSpellNames["SWD"]),
    ["MF"] = GetSpellTexture(FaceMelter.localizedSpellNames["MF"]),
    ["last"] = nil,
    ["current"] = nil,
    ["next"] = nil,
    ["highlight"] = nil
}

FaceMelter.spellList = {
    ["last"] = "",
    ["current"] = "",
    ["next"] = "",
    ["third"] = ""
}

-- Our sneaky frame to watch for events ... checks FaceMelter.events[] for the function.  Passes all args.
FaceMelter.eventFrame = CreateFrame("Frame")
FaceMelter.eventFrame:SetScript("OnEvent", function(this, event, ...)
    FaceMelter.events[event](...)
end)

FaceMelter.eventFrame:RegisterEvent("ADDON_LOADED")
FaceMelter.eventFrame:RegisterEvent("PLAYER_LOGIN")

-- Define our Event Handlers here
FaceMelter.events = {}

function FaceMelter.events.PLAYER_LOGIN()
    sbd:log_debug('event: PLAYER_LOGIN')
    FaceMelter.playerName = UnitName("player")

    FaceMelter.spellHaste = GetCombatRatingBonus(20)

    sbd:log_debug_table(FaceMelter.localizedSpellNames)

    FaceMelter.textureList["VT"] = GetSpellTexture(FaceMelter.localizedSpellNames["VT"])
    FaceMelter.textureList["SWP"] = GetSpellTexture(FaceMelter.localizedSpellNames["SWP"])
    FaceMelter.textureList["VE"] = GetSpellTexture(FaceMelter.localizedSpellNames["VE"])
    FaceMelter.textureList["MB"] = GetSpellTexture(FaceMelter.localizedSpellNames["MB"])
    FaceMelter.textureList["SWD"] = GetSpellTexture(FaceMelter.localizedSpellNames["SWD"])
    FaceMelter.textureList["MF"] = GetSpellTexture(FaceMelter.localizedSpellNames["MF"])

end

function FaceMelter.events.ADDON_LOADED(addon)
    sbd:log_debug('event: ADDON_LOADED')

    if addon ~= "FaceMelterClassic" then
        return
    end
    local _, playerClass = UnitClass("player")
    if playerClass ~= "PRIEST" then
        return
    end

    -- Default saved variables
    if not facemelterdb then
        facemelterdb = {}
    end
    if facemelterdb.useVE == nil then
        facemelterdb.useVE = true
    end
    if facemelterdb.useDeath == nil then
        facemelterdb.useDeath = true
    end
    if not facemelterdb.scale then
        facemelterdb.scale = 1
    end
    if not facemelterdb.miniOptionsAlpha then
        facemelterdb.miniOptionsAlpha = 1
    end
    if not facemelterdb.healthPercent then
        facemelterdb.healthPercent = 50
    end
    if not facemelterdb.locked then
        facemelterdb.locked = false
    end
    if not facemelterdb.x then
        facemelterdb.x = 100
    end
    if not facemelterdb.y then
        facemelterdb.y = 100
    end
    if not facemelterdb.pri then
        facemelterdb.pri = {}
    end
    if not facemelterdb.pri[1] then
        facemelterdb.pri[1] = "SWP"
    end
    if not facemelterdb.pri[2] then
        facemelterdb.pri[2] = "VT"
    end
    if not facemelterdb.pri[3] then
        facemelterdb.pri[3] = "MB"
    end
    if not facemelterdb.pri[4] then
        facemelterdb.pri[4] = "SWD"
    end
    if not facemelterdb.pri[5] then
        facemelterdb.pri[5] = "VE"
    end
    if not facemelterdb.priRev then
        facemelterdb.priRev = {
            ["SWP"] = 1,
            ["VT"] = 2,
            ["MB"] = 3,
            ["SWD"] = 4,
            ["VE"] = 5
        }
    end

    -- Create GUI
    FaceMelter:CreateGUI()
    FaceMelter.displayFrame:SetScale(facemelterdb.scale)

    FaceMelter.gcdbar:Hide()
    FaceMelter.eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")

    -- Create Options Frame
    FaceMelter:CreateOptionFrame()
    if facemelterdb.locked then
        FaceMelter.displayFrame:SetScript("OnMouseDown", nil)
        FaceMelter.displayFrame:SetScript("OnMouseUp", nil)
        FaceMelter.displayFrame:SetScript("OnDragStop", nil)
        FaceMelter.displayFrame:SetBackdropColor(0, 0, 0, 0)
        FaceMelter.displayFrame:EnableMouse(false)
    else
        FaceMelter.displayFrame:SetScript("OnMouseDown", function(self)
            self:StartMoving()
        end)
        FaceMelter.displayFrame:SetScript("OnMouseUp", function(self)
            self:StopMovingOrSizing()
        end)
        FaceMelter.displayFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)
        FaceMelter.displayFrame:SetBackdropColor(0, 0, 0, .4)
        FaceMelter.displayFrame:EnableMouse(true)
    end

    -- Register for Slash Commands
    SlashCmdList["FACEMELTER"] = FaceMelter.Options
    SLASH_FACEMELTER1 = "/facemelter"
    SLASH_FACEMELTER2 = "/fm"

    -- Register for Function Events
    FaceMelter.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    FaceMelter.eventFrame:RegisterEvent("COMBAT_RATING_UPDATE") -- Monitor the all-mighty haste
    FaceMelter.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    FaceMelter.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- Left combat, clean up all enemy GUIDs
    FaceMelter.eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    FaceMelter.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    FaceMelter.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    FaceMelter.eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    FaceMelter.eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")

    sbd:log_info(title .. " v" .. version .. " loaded - use /facemelter or /fm for options.")
end

function FaceMelter.events.COMBAT_LOG_EVENT_UNFILTERED(...)
    sbd:log_debug('event: COMBAT_LOG_EVENT_UNFILTERED')

    local _, event, _, _, srcName, _, _, dstGUID, dstName, _, _, _, spellName = CombatLogGetCurrentEventInfo()

    if srcName == FaceMelter.playerName then
        if event == "SPELL_CAST_START" then
            local guid = UnitGUID("target")

            if spellName == FaceMelter.localizedSpellNames["MB"] then
                FaceMelter.currentSpell = "MB"

                if (FaceMelter.textureList["highlight"]) then
                    FaceMelter.textureList["highlight"]:SetAlpha(0)
                end

                FaceMelter.npcList[guid] = UnitName("target")
                FaceMelter:PushDisplay()
            elseif spellName == FaceMelter.localizedSpellNames["VT"] then
                FaceMelter.currentSpell = "VT"

                if (FaceMelter.textureList["highlight"]) then
                    FaceMelter.textureList["highlight"]:SetAlpha(0)
                end

                FaceMelter.npcList[guid] = UnitName("target")
                FaceMelter.VTTarget = guid
                FaceMelter:PushDisplay()
            end
        elseif event == "SPELL_CAST_SUCCESS" then
            if spellName == FaceMelter.localizedSpellNames["SWP"] then
                FaceMelter.currentSpell = "SWP"

                if (FaceMelter.textureList["highlight"]) then
                    FaceMelter.textureList["highlight"]:SetAlpha(0)
                end

                FaceMelter.npcList[dstGUID] = dstName
                FaceMelter.painList[dstGUID] = GetTime()
                FaceMelter:PushDisplay()
            elseif spellName == FaceMelter.localizedSpellNames["SWD"] then
                FaceMelter.currentSpell = "SWD"

                if (FaceMelter.textureList["highlight"]) then
                    FaceMelter.textureList["highlight"]:SetAlpha(0)
                end

                FaceMelter.npcList[dstGUID] = dstName
                FaceMelter.deathTime = GetTime()
                FaceMelter:PushDisplay()
            elseif spellName == FaceMelter.localizedSpellNames["MF"] then
                FaceMelter.currentSpell = "MF"

                if (FaceMelter.textureList["highlight"]) then
                    FaceMelter.textureList["highlight"]:SetAlpha(0)
                end

                FaceMelter.npcList[dstGUID] = dstName
                FaceMelter.flayTime = GetTime()
                FaceMelter:PushDisplay()
            elseif spellName == FaceMelter.localizedSpellNames["VE"] then
                FaceMelter.currentSpell = "VE"

                if (FaceMelter.textureList["highlight"]) then
                    FaceMelter.textureList["highlight"]:SetAlpha(0)
                end

                FaceMelter.npcList[dstGUID] = dstName
                FaceMelter.embraceList[dstGUID] = GetTime()
                FaceMelter:PushDisplay()
            end
        elseif event == "SPELL_MISSED" then -- aww we get reisted, we only care if it's a debuff though
            local _, spellName = ...

            if spellName == FaceMelter.localizedSpellNames["SWP"] then
                FaceMelter.painList[dstGUID] = 0
                FaceMelter:PushDisplay()
            elseif spellName == FaceMelter.localizedSpellNames["VT"] then
                FaceMelter.touchList[dstGUID] = 0
                FaceMelter:PushDisplay()
            elseif spellName == FaceMelter.localizedSpellNames["VE"] then
                FaceMelter.embraceList[dstGUID] = 0
                FaceMelter:PushDisplay()
            end
        end
    end
end

function FaceMelter.events.COMBAT_RATING_UPDATE(unit)
    sbd:log_debug('event: COMBAT_RATING_UPDATE')

    if unit == "player" then
        FaceMelter.spellHaste = GetCombatRatingBonus(20) -- update spell haste
    end
end

function FaceMelter.events.PLAYER_TARGET_CHANGED(...)
    sbd:log_debug('event: PLAYER_TARGET_CHANGED')

    -- target changed, set last target, update current target, will be nil if no target
    if (FaceMelter.shouldCheckStuff) then
        FaceMelter:CheckStuff()
        FaceMelter.shouldCheckStuff = false
    end

    FaceMelter.lastTarget = FaceMelter.currentTarget
    FaceMelter.currentTarget = UnitGUID("target")

    if UnitName("target") == nil or UnitIsFriend("player", "target") == true or UnitHealth("target") == 0 then
        FaceMelter.displayFrame_last:Hide()
        FaceMelter.displayFrame_current:Hide()
        FaceMelter.displayFrame_next:Hide()
        FaceMelter.displayFrame_currentHighlight:Hide()
    else
        FaceMelter.displayFrame_currentHighlight:Show()
        FaceMelter.displayFrame_last:Show()
        FaceMelter.displayFrame_current:Show()
        FaceMelter.displayFrame_next:Show()
    end
    FaceMelter:DecideSpells()
end

function FaceMelter.events.PLAYER_REGEN_ENABLED(...)
    sbd:log_debug('event: PLAYER_REGEN_ENABLED')

    -- We have left combat, clean up GUIDs
    FaceMelter.npcList = {} -- {guid, name}
    FaceMelter.painList = {} -- {guid, GetTime}
    FaceMelter.touchList = {} -- {guid, GetTime}
    FaceMelter.embraceList = {} -- {guid, GetTime}
end

function FaceMelter.events.UNIT_SPELLCAST_INTERRUPTED(unitTarget, castGUID, spellID)
    sbd:log_debug('event: UNIT_SPELLCAST_INTERRUPTED')

    local spellName = FaceMelter:GetSpellName(spellID)

    if unitTarget == "player" then
        if spellName == FaceMelter.localizedSpellNames["MB"] then
            FaceMelter.blastTime = 0
        elseif spellName == FaceMelter.localizedSpellNames["VT"] and FaceMelter.touchList[UnitGUID("target")] ~= nil then
            FaceMelter.touchList[UnitGUID("target")] = 0
        end
        
        FaceMelter.currentSpell = ""
    end

    FaceMelter:DecideSpells()
end

function FaceMelter.events.UNIT_SPELLCAST_SUCCEEDED(unitTarget, castGUID, spellID)
    sbd:log_debug('event: UNIT_SPELLCAST_SUCCEEDED')

    local spellName = FaceMelter:GetSpellName(spellID)

    if unitTarget == "player" and spellName ~= FaceMelter.localizedSpellNames["MF"] then
        if spellName == FaceMelter.localizedSpellNames["MB"] then
            FaceMelter.blastTime = GetTime()
            if (FaceMelter.textureList["highlight"]) then
                FaceMelter.textureList["highlight"]:SetAlpha(1)
            end
        elseif spellName == FaceMelter.localizedSpellNames["VT"] then
            FaceMelter.touchList[FaceMelter.VTTarget] = GetTime() -- set the time for current time
            if (FaceMelter.textureList["highlight"]) then
                FaceMelter.textureList["highlight"]:SetAlpha(1)
            end
        end

        FaceMelter.currentSpell = ""
    end
end

function FaceMelter.events.UNIT_SPELLCAST_CHANNEL_STOP(unitTarget, castGUID, spellID)
    sbd:log_debug('event: UNIT_SPELLCAST_CHANNEL_STOP')

    local spellName = FaceMelter:GetSpellName(spellID)

    if unitTarget == "player" and spellName == FaceMelter.localizedSpellNames["MF"] then
        if (FaceMelter.textureList["highlight"]) then
            FaceMelter.textureList["highlight"]:SetAlpha(1)
        end
        FaceMelter.currentSpell = ""
    end
end

function FaceMelter.events.UNIT_INVENTORY_CHANGED(name)
    sbd:log_debug('event: UNIT_INVENTORY_CHANGED')

    if name == "player" then
        FaceMelter:CheckStuff()
    end
end

function FaceMelter.events.CHARACTER_POINTS_CHANGED()
    sbd:log_debug('event: CHARACTER_POINTS_CHANGED')

    FaceMelter:CheckStuff()
end

function FaceMelter.events.ACTIONBAR_UPDATE_COOLDOWN(...)
    sbd:log_debug('event: ACTIONBAR_UPDATE_COOLDOWN')

    local start, dur = GetSpellCooldown(FaceMelter.localizedSpellNames["SWP"])
    
    if FaceMelter.currentSpell == "MF" and dur > 0 then
        FaceMelter.gcdstart = start
        FaceMelter.gcdduration = 3 - (3 * FaceMelter.spellHaste * .01)
        FaceMelter.gcdbar:Show()
    else
        if dur > 0 then
            FaceMelter.gcdstart = start
            FaceMelter.gcdduration = dur
            FaceMelter.gcdbar:Show()
        end
    end
end

-- End Event Handlers

function FaceMelter:CreateGUI()
    sbd:log_debug('function: CreateGUI')

    local displayFrame = CreateFrame("Frame", "FaceMelterDisplayFrame", UIParent, "BackdropTemplate")
    displayFrame:SetFrameStrata("BACKGROUND")
    displayFrame:SetWidth(250)
    displayFrame:SetHeight(90)

    displayFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true,
        tileSize = 32
    })

    displayFrame:SetBackdropColor(0, 0, 0, .4)
    displayFrame:EnableMouse(true)
    displayFrame:SetMovable(true)
    -- displayFrame:RegisterForDrag("LeftButton")  --causes right buttont to go crazy, go figure
    displayFrame:SetClampedToScreen(true)

    displayFrame:SetScript("OnMouseDown", function(self)
        sbd:log_debug('event: displayFrame: OnMouseDown')

        self:StartMoving()
    end)

    displayFrame:SetScript("OnMouseUp", function(self)
        sbd:log_debug('event: displayFrame: OnMouseUp')

        self:StopMovingOrSizing()
    end)

    displayFrame:SetScript("OnDragStop", function(self)
        sbd:log_debug('event: displayFrame: OnDragStop')
        self:StopMovingOrSizing()
    end)

    displayFrame:SetPoint("CENTER", -200, -200)

    local displayFrame_last = CreateFrame("Frame", "$parent_last", FaceMelterDisplayFrame)
    local displayFrame_currentHighlight = CreateFrame("Frame", "$parent_currentHighlight", FaceMelterDisplayFrame)
    local displayFrame_current = CreateFrame("Frame", "$parent_current", FaceMelterDisplayFrame_currentHighlight)
    local displayFrame_next = CreateFrame("Frame", "$parent_next", FaceMelterDisplayFrame)

    displayFrame_last:SetWidth(70)
    displayFrame_current:SetWidth(70)
    displayFrame_currentHighlight:SetWidth(80)
    displayFrame_next:SetWidth(70)

    displayFrame_last:SetHeight(70)
    displayFrame_current:SetHeight(70)
    displayFrame_currentHighlight:SetHeight(80)
    displayFrame_next:SetHeight(70)

    displayFrame_last:SetPoint("TOPLEFT", 10, -10)
    displayFrame_currentHighlight:SetPoint("TOPLEFT", 85, -5)
    displayFrame_current:SetPoint("TOPLEFT", 5, -5)
    displayFrame_next:SetPoint("TOPLEFT", 170, -10)

    local t = displayFrame_last:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(nil)
    t:SetAllPoints(displayFrame_last)
    t:SetAlpha(.2)
    displayFrame_last.texture = t
    FaceMelter.textureList["last"] = t

    t = displayFrame_current:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(nil)
    t:ClearAllPoints()
    t:SetAllPoints(displayFrame_current)
    displayFrame_current.texture = t
    FaceMelter.textureList["current"] = t

    t = displayFrame_next:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(nil)
    t:SetAllPoints(displayFrame_next)
    t:SetAlpha(.5)
    displayFrame_next.texture = t
    FaceMelter.textureList["next"] = t

    t = displayFrame_currentHighlight:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(.1, .5, .1)
    t:SetAllPoints(displayFrame_currentHighlight)
    t:SetAlpha(0)
    displayFrame_currentHighlight.texture = t
    FaceMelter.textureList["highlight"] = t

    displayFrame:SetScript("OnUpdate", function(this, elapsed)
        -- sbd:log_debug('event: displayFrame: OnUpdate')

        FaceMelter:OnUpdate(elapsed)
    end)

    local cooldownFrame = CreateFrame("Cooldown", "$parent_cooldown", FaceMelterDisplayFrame_current)
    cooldownFrame:SetHeight(70)
    cooldownFrame:SetWidth(70)
    cooldownFrame:ClearAllPoints()
    cooldownFrame:SetPoint("CENTER", displayFrame_current, "CENTER", 0, 0)

    FaceMelter.displayFrame = displayFrame
    FaceMelter.displayFrame_last = displayFrame_last
    FaceMelter.displayFrame_current = displayFrame_current
    FaceMelter.displayFrame_next = displayFrame_next
    FaceMelter.displayFrame_currentHighlight = displayFrame_currentHighlight
    FaceMelter.cooldownFrame = cooldownFrame

    local gcdbar = CreateFrame('Frame', 'FaceMelterGCDBar', UIParent)
    gcdbar:SetFrameStrata('HIGH')

    gcdbar:SetScript('OnShow', function()
        sbd:log_debug('event: gcdbar: OnShow')

        FaceMelter.OnShowGCD()
    end)

    gcdbar:SetScript('OnHide', function()
        sbd:log_debug('event: gcdbar: OnHide')

        FaceMelter.OnHideGCD()
    end)

    local gcdspark = gcdbar:CreateTexture(nil, 'DIALOG')
    FaceMelter.gcdstart = 0
    FaceMelter.gcdduration = 0
    gcdbar:ClearAllPoints()
    gcdbar:SetHeight(10)
    gcdbar:SetWidth(250)
    gcdbar:SetPoint("BOTTOM", FaceMelterDisplayFrame, "TOP", 0, 0)
    gcdspark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    gcdspark:SetVertexColor(1, 1, 1)
    gcdspark:SetBlendMode('ADD')
    gcdspark:SetWidth(25)
    gcdspark:SetHeight(10)
    FaceMelter.gcdbar = gcdbar
    FaceMelter.gcdspark = gcdspark

    local displayFrame_options = CreateFrame("Frame", "$parent_options", FaceMelterDisplayFrame)
    displayFrame_options:SetWidth(70)
    displayFrame_options:SetHeight(30)
    displayFrame_options:SetPoint("BOTTOMLEFT", 0, -0)

    local VEString = displayFrame_options:CreateFontString("FaceMelter_VEString", "OVERLAY", "GameFontNormal")
    local SWDString = displayFrame_options:CreateFontString("FaceMelter_SWDString", "OVERLAY", "GameFontNormal")
    VEString:SetText("VE")
    SWDString:SetText("SW:D")

    local VECheck = CreateFrame("CheckButton", "$parent_vecb", displayFrame_options, "OptionsCheckButtonTemplate")
    local SWDCheck = CreateFrame("CheckButton", "$parent_swdcb", displayFrame_options, "OptionsCheckButtonTemplate")
    VECheck:SetWidth(14)
    VECheck:SetHeight(14)
    SWDCheck:SetWidth(14)
    SWDCheck:SetHeight(14)

    VECheck:SetScript("OnClick", function()
        sbd:log_debug('event: VECheck: OnClick')

        FaceMelter:ToggleVE()
    end)

    SWDCheck:SetScript("OnClick", function()
        sbd:log_debug('event: SWDCheck: OnClick')

        FaceMelter:ToggleDeath()
    end)

    VEString:SetPoint("BOTTOMLEFT", 16, 20)
    VECheck:SetPoint("BOTTOMLEFT", 0, 19)
    SWDString:SetPoint("BOTTOMLEFT", 16, 0)
    SWDCheck:SetPoint("BOTTOMLEFT", 0, -1)

    VECheck:SetChecked(FaceMelter:GetVE())
    SWDCheck:SetChecked(FaceMelter:GetDeath())

    FaceMelter.displayFrame_options = displayFrame_options
    FaceMelter.VECheck = VECheck
    FaceMelter.SWDCheck = SWDCheck

    FaceMelter.displayFrame_options:SetAlpha(facemelterdb.miniOptionsAlpha)
    displayFrame:Show()

end

function FaceMelter.OnHideGCD()
    sbd:log_debug('function: OnHideGCD')

    FaceMelter.gcdbar:SetScript('OnUpdate', nil)
end

function FaceMelter.OnShowGCD()
    sbd:log_debug('function: OnShowGCD')

    FaceMelter.gcdbar:SetScript('OnUpdate', function()
        -- sbd:log_debug('event: gcdbar: OnUpdate')
        FaceMelter.OnUpdateGCD()
    end)
end

function FaceMelter.OnUpdateGCD()
    -- sbd:log_debug('function: OnUpdateGCD')

    FaceMelter.gcdspark:ClearAllPoints()
    local perc = (GetTime() - FaceMelter.gcdstart) / FaceMelter.gcdduration

    if perc > 1 then
        if FaceMelter.currentSpell == "SWD" or FaceMelter.currentSpell == "SWP" or FaceMelter.currentSpell == "VE" then
            if (FaceMelter.textureList["highlight"]) then
                FaceMelter.textureList["highlight"]:SetAlpha(1)
            end
        end
        return FaceMelter.gcdbar:Hide()
    else
        FaceMelter.gcdspark:SetPoint('CENTER', FaceMelter.gcdbar, 'LEFT', 250 * perc, 0)
    end

end

function FaceMelter:OnUpdate(elapsed)
    -- sbd:log_debug('function: OnUpdate')

    FaceMelter.timeSinceLastUpdate = FaceMelter.timeSinceLastUpdate + elapsed

    if (FaceMelter.currentSpell == "MF" and FaceMelter.spellList["current"] ~= "MF" and GetTime() - FaceMelter.flayTime >
        (3 - (FaceMelter.spellHaste * .01 * 3)) * .67) then
        if (FaceMelter.textureList["highlight"]) then
            FaceMelter.textureList["highlight"]:SetAlpha(1)
        end
    end

    if (FaceMelter.timeSinceLastUpdate > (1.5 - (1.5 * FaceMelter.spellHaste * .01)) * 0.3) then
        FaceMelter:DecideSpells()
    end

end

function FaceMelter:PushDisplay()
    sbd:log_debug('function: PushDisplay')

    -- Move to the new spell to cast
    if FaceMelter.currentSpell == FaceMelter.spellList["current"] then
        FaceMelter.textureList["last"]:SetTexture(FaceMelter.textureList[FaceMelter.spellList["current"]])
        FaceMelter.textureList["current"]:SetTexture(FaceMelter.textureList[FaceMelter.spellList["next"]])
        FaceMelter.textureList["next"]:SetTexture(FaceMelter.textureList[FaceMelter.spellList["third"]])

        FaceMelter.spellList["last"] = FaceMelter.spellList["current"]
        FaceMelter.spellList["current"] = FaceMelter.spellList["next"]
        FaceMelter.spellList["next"] = FaceMelter.spellList["third"]
        FaceMelter.spellList["third"] = ""
    end

    -- DEFAULT_CHAT_FRAME:AddMessage("Shif" .. FaceMelter.spellList["last"] .. FaceMelter.spellList["current"] .. FaceMelter.spellList["next"])
    FaceMelter:DecideSpells()
end

function FaceMelter:DecideSpells()
    -- sbd:log_debug('function: DecideSpells')

    FaceMelter.timeSinceLastUpdate = 0

    if UnitName("target") == nil or UnitIsFriend("player", "target") == true or UnitHealth("target") == 0 then
        return -- ignore the dead and friendly
    end

    local firstSpell = ""
    local secondSpell = ""
    local thirdSpell = ""
    local guid = UnitGUID("target")
    local currentTime = GetTime()
    local GCD = 1.5 - (1.5 * FaceMelter.spellHaste * .01)

    if guid == nil then
        FaceMelter.textureList["last"]:SetTexture(nil)
        FaceMelter.textureList["current"]:SetTexture(nil)
        FaceMelter.textureList["next"]:SetTexture(nil)
        FaceMelter.spellList["last"] = ""
        FaceMelter.spellList["current"] = ""
        FaceMelter.spellList["next"] = ""
        FaceMelter.spellList["third"] = ""
        return
    end

    -- Check Priority spell 1 - SWP
    local painSecsElapsed = 9999
    local touchSecsElapsed = 9999

    for pri, spell in pairs(facemelterdb.pri) do

        if FaceMelter.currentSpell == spell then
            -- skip if we just cast the spell but it hasn't cleared yet
        else
            local timeUntilNext = 0
            -- set up our test subjects

            if spell == "SWP" and FaceMelter.painList[guid] ~= nil then
                timeUntilNext = FaceMelter.painDuration - (currentTime - FaceMelter.painList[guid])
            elseif spell == "VT" and FaceMelter.touchList[guid] ~= nil then
                timeUntilNext = 15 - GCD - (currentTime - FaceMelter.touchList[guid])
            elseif spell == "MB" then
                timeUntilNext = FaceMelter.blastCooldown - (currentTime - FaceMelter.blastTime)
            elseif spell == "SWD" then
                if facemelterdb.useDeath and UnitHealth("player") / UnitHealthMax("player") * 100 >=
                    facemelterdb.healthPercent then
                    timeUntilNext = 12 - (currentTime - FaceMelter.deathTime)
                else
                    timeUntilNext = 999 -- aka never
                end
            elseif spell == "VE" then
                if facemelterdb.useVE then
                    if FaceMelter.embraceList[guid] ~= nil then
                        timeUntilNext = 60 - (currentTime - FaceMelter.embraceList[guid])
                    end
                else
                    timeUntilNext = 999 -- aka never
                end
            end

            -- run our tests
            if timeUntilNext < GCD then
                if firstSpell == "" then
                    firstSpell = spell
                elseif secondSpell == "" then
                    secondSpell = spell
                elseif thirdSpell == "" then
                    thirdSpell = spell
                end
            elseif timeUntilNext < GCD * 2 then
                if secondSpell == "" then
                    secondSpell = spell
                elseif thirdSpell == "" then
                    thirdSpell = spell
                end
            elseif timeUntilNext < GCD * 3 then
                if thirdSpell == "" then
                    thirdSpell = spell
                end
            end -- test ended

        end

    end

    -- If still empty, fill in with MF unless previous global we MF'd
    if firstSpell == "" then
        firstSpell = "MF"
    end
    if secondSpell == "" and firstSpell ~= "MF" then
        secondSpell = "MF"
    end
    if thirdSpell == "" and secondSpell ~= "MF" then
        thirdSpell = "MF"
    end

    -- Update the spellList array - if we find a mismatch, report it, and update the texture
    if FaceMelter.spellList["current"] == firstSpell then
        -- yay
    else
        -- DEFAULT_CHAT_FRAME:AddMessage("Mismatch current: " .. FaceMelter.spellList["current"] .. firstSpell)
        FaceMelter.spellList["current"] = firstSpell
        FaceMelter.textureList["current"]:SetTexture(FaceMelter.textureList[FaceMelter.spellList["current"]])
    end
    if FaceMelter.spellList["next"] == secondSpell then
        -- yay
    else
        -- DEFAULT_CHAT_FRAME:AddMessage("Mismatch next: " .. FaceMelter.spellList["next"] .. secondSpell)
        FaceMelter.spellList["next"] = secondSpell
        FaceMelter.textureList["next"]:SetTexture(FaceMelter.textureList[FaceMelter.spellList["next"]])
    end
    FaceMelter.spellList["third"] = thirdSpell

    -- MF full length = 2 X GCD... SO....
    if firstSpell == "MF" and secondSpell == "MF" then
        FaceMelter.textureList["next"]:SetTexture(FaceMelter.textureList[FaceMelter.spellList["third"]])
        FaceMelter.spellList["next"] = FaceMelter.spellList["third"]
        FaceMelter.spellList["third"] = ""
    end

    if firstSpell == "MB" then
        FaceMelter.cooldownFrame:SetCooldown(FaceMelter.blastTime, FaceMelter.blastCooldown)
    elseif firstSpell == "SWD" then
        FaceMelter.cooldownFrame:SetCooldown(FaceMelter.deathTime, 12)
    end

end

function FaceMelter:CheckStuff()
    sbd:log_debug('function: CheckStuff')

    local nameTalent, _, _, _, currentRank, _, _, _ = GetTalentInfo(3, 4)
    local painDuration = 18 + (currentRank * 3)
    local nameTalent, _, _, _, currentRank, _, _, _ = GetTalentInfo(3, 7)
    local blastCooldown = 8 - (currentRank * .5)
    
    local absCount = 0

    local absolutionArray = {
        ["HeadSlot"] = "Hood of Absolution",
        ["ShoulderSlot"] = "Shoulderpads of Absolution",
        ["ChestSlot"] = "Shroud of Absolution",
        ["WristSlot"] = "Bracers of Absolution",
        ["HandsSlot"] = "Handguards of Absolution",
        ["WaistSlot"] = "Cord of Absolution",
        ["LegsSlot"] = "Leggings of Absolution",
        ["FeetSlot"] = "Treads of Absolution"
    }

    for item, name in pairs(absolutionArray) do
        local link = GetInventoryItemLink("player", GetInventorySlotInfo(item))

        if link then
            local foundName = GetItemInfo(link)
            if foundName ~= nil and strfind(foundName, name) then
                absCount = absCount + 1
            end
        end
    end

    if absCount > 1 then
        painDuration = painDuration + 3
    end

    FaceMelter.blastCooldown = blastCooldown
    FaceMelter.painDuration = painDuration
end

function FaceMelter:GetSpellName(spellId)
    local spellName = GetSpellInfo(spellId)
    sbd:log_debug('GetSpellName:', spellId, ":", spellName)
    return spellName
end

-- Options Panel
function FaceMelter:GetVE()
    sbd:log_debug('function: GetVE')

    return facemelterdb.useVE
end

function FaceMelter:ToggleVE()
    sbd:log_debug('function: ToggleVE')

    if facemelterdb.useVE then
        facemelterdb.useVE = false
        FaceMelter.VECheck:SetChecked(false)
        FaceMelter.VECheck2:SetChecked(false)

    else
        facemelterdb.useVE = true
        FaceMelter.VECheck:SetChecked(true)
        FaceMelter.VECheck2:SetChecked(true)
    end
end

function FaceMelter:GetDeath()
    sbd:log_debug('function: GetDeath')
    return facemelterdb.useDeath
end

function FaceMelter:ToggleDeath()
    sbd:log_debug('function: ToggleDeath')

    if facemelterdb.useDeath then
        facemelterdb.useDeath = false
        FaceMelter.SWDCheck:SetChecked(false)
        FaceMelter.SWDCheck2:SetChecked(false)
    else
        facemelterdb.useDeath = true
        FaceMelter.SWDCheck:SetChecked(true)
        FaceMelter.SWDCheck2:SetChecked(true)
    end
end

function FaceMelter:GetLocked()
    sbd:log_debug('function: GetLocked')

    return facemelterdb.locked
end

function FaceMelter:GetPri(spell)
    sbd:log_debug('function: GetPri')

    return facemelterdb.priRev[spell]
end

function FaceMelter:SetPri(spell, pri)
    sbd:log_debug('function: SetPri')

    pri = math.floor(pri)

    local oldPri = facemelterdb.priRev[spell]
    local oldSpell = facemelterdb.pri[pri]

    facemelterdb.priRev[spell] = pri
    facemelterdb.priRev[oldSpell] = oldPri
    facemelterdb.pri[oldPri] = oldSpell
    facemelterdb.pri[pri] = spell
    getglobal("FaceMelterOptions_sl_" .. oldSpell):SetValue(oldPri)
    getglobal("FaceMelterOptions_sl_" .. oldSpell .. "Text"):SetText(oldPri)

end

function FaceMelter:ToggleLocked()
    sbd:log_debug('function: ToggleLocked')

    if facemelterdb.locked then
        facemelterdb.locked = false

        FaceMelter.displayFrame:SetScript("OnMouseDown", function(self)
            sbd:log_debug('displayFrame: event: OnMouseDown')

            self:StartMoving()
        end)

        FaceMelter.displayFrame:SetScript("OnMouseUp", function(self)
            sbd:log_debug('displayFrame: event: OnMouseUp')

            self:StopMovingOrSizing()
        end)

        FaceMelter.displayFrame:SetScript("OnDragStop", function(self)
            sbd:log_debug('displayFrame: event: OnDragStop')

            self:StopMovingOrSizing()
        end)

        FaceMelter.displayFrame:SetBackdropColor(0, 0, 0, .4)
        FaceMelter.displayFrame:EnableMouse(true)
    else
        facemelterdb.locked = true
        FaceMelter.displayFrame:SetScript("OnMouseDown", nil)
        FaceMelter.displayFrame:SetScript("OnMouseUp", nil)
        FaceMelter.displayFrame:SetScript("OnDragStop", nil)
        FaceMelter.displayFrame:SetBackdropColor(0, 0, 0, 0)
        FaceMelter.displayFrame:EnableMouse(false)
    end
end

function FaceMelter:GetScale()
    sbd:log_debug('function: GetScale')

    return facemelterdb.scale
end

function FaceMelter:SetScale(num)
    sbd:log_debug('function: SetScale')

    facemelterdb.scale = num
    FaceMelter.displayFrame:SetScale(facemelterdb.scale)
    FaceMelter.cooldownFrame:SetScale(facemelterdb.scale)
end

function FaceMelter:GetHealthPercent()
    sbd:log_debug('function: GetHealthPercent')

    return facemelterdb.healthPercent
end

function FaceMelter:SetHealthPercent(num)
    sbd:log_debug('function: SetHealthPercent')

    facemelterdb.healthPercent = num
end

function FaceMelter:SetMiniAlpha(num)
    sbd:log_debug('function: SetMiniAlpha')

    facemelterdb.miniOptionsAlpha = num
    FaceMelter.displayFrame_options:SetAlpha(num)
    if num == 0 then
        FaceMelter.displayFrame_options:Hide()
    else
        FaceMelter.displayFrame_options:Show()
    end
end

function FaceMelter:CreateOptionFrame()
    sbd:log_debug('function: CreateOptionFrame')

    local panel = CreateFrame("FRAME", "FaceMelterOptions")
    panel.name = "Face Melter Classic"
    local fstring1 = panel:CreateFontString("FaceMelterOptions_string1", "OVERLAY", "GameFontNormal")
    local fstring2 = panel:CreateFontString("FaceMelterOptions_string2", "OVERLAY", "GameFontNormal")
    local fstring3 = panel:CreateFontString("FaceMelterOptions_string3", "OVERLAY", "GameFontNormal")
    local fstring4 = panel:CreateFontString("FaceMelterOptions_string4", "OVERLAY", "GameFontNormal")
    local fstring5 = panel:CreateFontString("FaceMelterOptions_string4", "OVERLAY", "GameFontNormal")
    fstring1:SetText("Lock")
    fstring2:SetText("Include Vampiric Embrace ")
    fstring3:SetText("Include Shadow Word: Death ")
    fstring4:SetText("Health Percent for SW:D Cutoff")
    fstring5:SetText("GUI Scale")
    fstring1:SetPoint("TOPLEFT", 10, -10)
    fstring2:SetPoint("TOPLEFT", 10, -40)
    fstring3:SetPoint("TOPLEFT", 10, -70)
    fstring4:SetPoint("TOPLEFT", 10, -100)
    fstring5:SetPoint("TOPLEFT", 10, -130)

    local checkbox1 = CreateFrame("CheckButton", "$parent_cb1", panel, "OptionsCheckButtonTemplate")
    local checkbox2 = CreateFrame("CheckButton", "$parent_cb2", panel, "OptionsCheckButtonTemplate")
    local checkbox3 = CreateFrame("CheckButton", "$parent_cb3", panel, "OptionsCheckButtonTemplate")
    checkbox1:SetWidth(18)
    checkbox1:SetHeight(18)
    checkbox2:SetWidth(18)
    checkbox2:SetHeight(18)
    checkbox3:SetWidth(18)
    checkbox3:SetHeight(18)

    checkbox1:SetScript("OnClick", function()
        sbd:log_debug('checkbox1: event: Onclick')

        FaceMelter:ToggleLocked()
    end)

    checkbox2:SetScript("OnClick", function()
        sbd:log_debug('checkbox2: event: Onclick')

        FaceMelter:ToggleVE()
    end)

    checkbox3:SetScript("OnClick", function()
        sbd:log_debug('checkbox3: event: Onclick')

        FaceMelter:ToggleDeath()
    end)

    checkbox1:SetPoint("TOPRIGHT", -10, -10)
    checkbox2:SetPoint("TOPRIGHT", -10, -40)
    checkbox3:SetPoint("TOPRIGHT", -10, -70)
    checkbox1:SetChecked(FaceMelter:GetLocked())
    checkbox2:SetChecked(FaceMelter:GetVE())
    checkbox3:SetChecked(FaceMelter:GetDeath())

    FaceMelter.VECheck2 = checkbox2
    FaceMelter.SWDCheck2 = checkbox3

    local slider1 = CreateFrame("Slider", "$parent_sl1", panel, "OptionsSliderTemplate")
    local slider2 = CreateFrame("Slider", "$parent_sl2", panel, "OptionsSliderTemplate")
    slider1:SetMinMaxValues(0, 100)
    slider2:SetMinMaxValues(.5, 1.5)
    slider1:SetValue(FaceMelter:GetHealthPercent())
    slider2:SetValue(FaceMelter:GetScale())
    slider1:SetValueStep(1)
    slider2:SetValueStep(.05)

    slider1:SetScript("OnValueChanged", function(self)
        sbd:log_debug('slider1: event: OnValueChanged')

        FaceMelter:SetHealthPercent(self:GetValue())
        getglobal(self:GetName() .. "Text"):SetText(self:GetValue())
    end)

    slider2:SetScript("OnValueChanged", function(self)
        sbd:log_debug('slider2: event: OnValueChanged')

        FaceMelter:SetScale(self:GetValue())
        getglobal(self:GetName() .. "Text"):SetText(self:GetValue())
    end)

    getglobal(slider1:GetName() .. "Low"):SetText("1")
    getglobal(slider1:GetName() .. "High"):SetText("100")
    getglobal(slider1:GetName() .. "Text"):SetText(FaceMelter:GetHealthPercent())
    getglobal(slider2:GetName() .. "Low"):SetText("0.5")
    getglobal(slider2:GetName() .. "High"):SetText("1.5")
    getglobal(slider2:GetName() .. "Text"):SetText(FaceMelter:GetScale())
    slider1:SetPoint("TOPRIGHT", -10, -100)
    slider2:SetPoint("TOPRIGHT", -10, -130)

    local fstring6 = panel:CreateFontString("FaceMelterOptions_string6", "OVERLAY", "GameFontNormal")
    local fstring7 = panel:CreateFontString("FaceMelterOptions_string7", "OVERLAY", "GameFontNormal")
    local fstring8 = panel:CreateFontString("FaceMelterOptions_string8", "OVERLAY", "GameFontNormal")
    local fstring9 = panel:CreateFontString("FaceMelterOptions_string9", "OVERLAY", "GameFontNormal")
    local fstring10 = panel:CreateFontString("FaceMelterOptions_string10", "OVERLAY", "GameFontNormal")
    local fstring6a = panel:CreateFontString("FaceMelterOptions_string6a", "OVERLAY", "GameFontNormal")
    fstring6a:SetText("Priority List: 1 is first, 5 is last.")
    fstring6:SetText("SW: Pain")
    fstring7:SetText(FaceMelter.localizedSpellNames["VT"])
    fstring8:SetText(FaceMelter.localizedSpellNames["MB"])
    fstring9:SetText("SW: Death")
    fstring10:SetText("Vampric Embrace")
    fstring6a:SetPoint("TOPLEFT", 10, -160)
    fstring6:SetPoint("TOPLEFT", 10, -190)
    fstring7:SetPoint("TOPLEFT", 10, -220)
    fstring8:SetPoint("TOPLEFT", 10, -250)
    fstring9:SetPoint("TOPLEFT", 10, -280)
    fstring10:SetPoint("TOPLEFT", 10, -310)

    local slider3 = CreateFrame("Slider", "FaceMelterOptions_sl_SWP", panel, "OptionsSliderTemplate")
    local slider4 = CreateFrame("Slider", "FaceMelterOptions_sl_VT", panel, "OptionsSliderTemplate")
    local slider5 = CreateFrame("Slider", "FaceMelterOptions_sl_MB", panel, "OptionsSliderTemplate")
    local slider6 = CreateFrame("Slider", "FaceMelterOptions_sl_SWD", panel, "OptionsSliderTemplate")
    local slider7 = CreateFrame("Slider", "FaceMelterOptions_sl_VE", panel, "OptionsSliderTemplate")
    slider3:SetMinMaxValues(1, 5)
    slider4:SetMinMaxValues(1, 5)
    slider5:SetMinMaxValues(1, 5)
    slider6:SetMinMaxValues(1, 5)
    slider7:SetMinMaxValues(1, 5)
    slider3:SetValueStep(1)
    slider4:SetValueStep(1)
    slider5:SetValueStep(1)
    slider6:SetValueStep(1)
    slider7:SetValueStep(1)
    slider3:SetValue(FaceMelter:GetPri("SWP"))
    slider4:SetValue(FaceMelter:GetPri("VT"))
    slider5:SetValue(FaceMelter:GetPri("MB"))
    slider6:SetValue(FaceMelter:GetPri("SWD"))
    slider7:SetValue(FaceMelter:GetPri("VE"))
    getglobal(slider3:GetName() .. "Low"):SetText("1")
    getglobal(slider3:GetName() .. "High"):SetText("5")
    getglobal(slider3:GetName() .. "Text"):SetText(FaceMelter:GetPri("SWP"))
    getglobal(slider4:GetName() .. "Low"):SetText("1")
    getglobal(slider4:GetName() .. "High"):SetText("5")
    getglobal(slider4:GetName() .. "Text"):SetText(FaceMelter:GetPri("VT"))
    getglobal(slider5:GetName() .. "Low"):SetText("1")
    getglobal(slider5:GetName() .. "High"):SetText("5")
    getglobal(slider5:GetName() .. "Text"):SetText(FaceMelter:GetPri("MB"))
    getglobal(slider6:GetName() .. "Low"):SetText("1")
    getglobal(slider6:GetName() .. "High"):SetText("5")
    getglobal(slider6:GetName() .. "Text"):SetText(FaceMelter:GetPri("SWD"))
    getglobal(slider7:GetName() .. "Low"):SetText("1")
    getglobal(slider7:GetName() .. "High"):SetText("5")
    getglobal(slider7:GetName() .. "Text"):SetText(FaceMelter:GetPri("VE"))
    slider3:SetPoint("TOPRIGHT", -10, -190)
    slider4:SetPoint("TOPRIGHT", -10, -220)
    slider5:SetPoint("TOPRIGHT", -10, -250)
    slider6:SetPoint("TOPRIGHT", -10, -280)
    slider7:SetPoint("TOPRIGHT", -10, -310)

    slider3:SetScript("OnValueChanged", function(self)
        sbd:log_debug('slider3: event: OnValueChanged')

        FaceMelter:SetPri("SWP", self:GetValue())
        getglobal(self:GetName() .. "Text"):SetText(self:GetValue())
    end)

    slider4:SetScript("OnValueChanged", function(self)
        sbd:log_debug('slider4: event: OnValueChanged')

        FaceMelter:SetPri("VT", self:GetValue())
        getglobal(self:GetName() .. "Text"):SetText(self:GetValue())
    end)

    slider5:SetScript("OnValueChanged", function(self)
        sbd:log_debug('slider5: event: OnValueChanged')

        FaceMelter:SetPri("MB", self:GetValue())
        getglobal(self:GetName() .. "Text"):SetText(self:GetValue())
    end)

    slider6:SetScript("OnValueChanged", function(self)
        sbd:log_debug('slider6: event: OnValueChanged')

        FaceMelter:SetPri("SWD", self:GetValue())
        getglobal(self:GetName() .. "Text"):SetText(self:GetValue())
    end)

    slider7:SetScript("OnValueChanged", function(self)
        sbd:log_debug('slider7: event: OnValueChanged')

        FaceMelter:SetPri("VE", self:GetValue())
        getglobal(self:GetName() .. "Text"):SetText(self:GetValue())
    end)

    local fstringMO = panel:CreateFontString("FaceMelterOptions_stringMO", "OVERLAY", "GameFontNormal")
    fstringMO:SetText("Mini Options Alpha")
    fstringMO:SetPoint("TOPLEFT", 10, -340)

    local sliderMO = CreateFrame("Slider", "$parent_sMO", panel, "OptionsSliderTemplate")
    sliderMO:SetMinMaxValues(0, 1)
    sliderMO:SetValue(facemelterdb.miniOptionsAlpha)
    sliderMO:SetValueStep(.05)
    sliderMO:SetScript("OnValueChanged", function(self)
        sbd:log_debug('sliderMO: event: OnValueChanged')

        FaceMelter:SetMiniAlpha(self:GetValue())
        getglobal(self:GetName() .. "Text"):SetText(self:GetValue())
    end)
    getglobal(sliderMO:GetName() .. "Low"):SetText("0")
    getglobal(sliderMO:GetName() .. "High"):SetText("1")
    getglobal(sliderMO:GetName() .. "Text"):SetText(facemelterdb.miniOptionsAlpha)
    sliderMO:SetPoint("TOPRIGHT", -10, -340)

    InterfaceOptions_AddCategory(panel)
end

-- Slash Command
function FaceMelter.Options()
    sbd:log_debug('function: Options')
    InterfaceOptionsFrame_OpenToCategory(getglobal("FaceMelterOptions"))
end

