local addonName, BunReminder = ...

local MANA_BUN_ID = 113509

local defaultValues = {
    enabled = true,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    width = 64,
    height = 64,
    showTank = true,
    showHealer = true,
    showDPS = true,
    showSpecFilters = false,
    enabledSpecs = {},
}

local function InitializeDatabase()
    BunReminderDB = BunReminderDB or {}
    BunReminder.db = BunReminderDB
    
    for field, fieldValue in pairs(defaultValues) do
        if BunReminder.db[field] == nil then
            if type(fieldValue) == "table" then
                BunReminder.db[field] = CopyTable(fieldValue)
            else
                BunReminder.db[field] = fieldValue
            end
        end
    end
end

-- Helpers
local function ManaBunInBags()
    return C_Item.GetItemCount(MANA_BUN_ID, false, false) > 0
end

local function ShouldDisplayForCurrentSpecAndRole()
    if not BunReminder.db.enabled then return false end

    if not IsResting() then return false end

    local specIndex = GetSpecialization()
    if not specIndex then return true end

    local role = GetSpecializationRole(specIndex)
    if role == "TANK" and not BunReminder.db.showTank then return false end
    if role == "HEALER" and not BunReminder.db.showHealer then return false end
    if role == "DAMAGER" and not BunReminder.db.showDPS then return false end

    local currentSpecID = GetSpecializationInfo(specIndex)
    if currentSpecID and BunReminder.db.enabledSpecs[currentSpecID] == false then
        return false
    end

    return true
end

local bunFrame = CreateFrame("Button", "BunReminderFrame", UIParent, "SecureActionButtonTemplate")
bunFrame:SetMovable(true)
bunFrame:Hide()
bunFrame.text = bunFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
bunFrame.text:SetPoint("TOP", bunFrame, "BOTTOM", 0, -2)
bunFrame.text:SetText("No Buns!")
bunFrame.text:SetTextColor(1, 0.2, 0.2)

local function UpdateFrame()
    if not BunReminder.db then return end

    if not ManaBunInBags() and ShouldDisplayForCurrentSpecAndRole() then
        local iconSize = BunReminder.db.width or 64
        bunFrame:SetSize(iconSize, iconSize)
        bunFrame:ClearAllPoints()
        bunFrame:SetPoint(
            BunReminder.db.point or "CENTER",
            UIParent,
            BunReminder.db.relativePoint or "CENTER",
            BunReminder.db.x or 0,
            BunReminder.db.y or 0
        )

        if not bunFrame.texture then
            bunFrame.texture = bunFrame:CreateTexture(nil, "BACKGROUND")
            bunFrame.texture:SetAllPoints(bunFrame)
        end

        local _, _, _, _, bunIcon = C_Item.GetItemInfoInstant(MANA_BUN_ID)
        bunFrame.texture:SetTexture(bunIcon or 134400)

        local fontPath, _, fontFlags = bunFrame.text:GetFont()
        local calculatedFontSize = math.max(10, math.floor(iconSize * 0.22))
        bunFrame.text:SetFont(fontPath, calculatedFontSize, fontFlags)

        bunFrame:Show()

        if bunFrame.animGroup and not bunFrame.animGroup:IsPlaying() then
            bunFrame.animGroup:Play()
        end
    else
        if bunFrame.animGroup and bunFrame.animGroup:IsPlaying() then
            bunFrame.animGroup:Stop()
        end
        bunFrame:Hide()
    end
end

bunFrame.animGroup = bunFrame:CreateAnimationGroup()
bunFrame.animGroup:SetLooping("REPEAT")

local animUp = bunFrame.animGroup:CreateAnimation("Translation")
animUp:SetOrder(1)
animUp:SetOffset(0, 12)
animUp:SetDuration(0.35)
animUp:SetSmoothing("OUT")

local animDown = bunFrame.animGroup:CreateAnimation("Translation")
animDown:SetOrder(2)
animDown:SetOffset(0, -12)
animDown:SetDuration(0.35)
animDown:SetSmoothing("IN")

local dragging = false

bunFrame:SetScript("OnMouseDown", function(self, button)
    if IsShiftKeyDown() and button == "LeftButton" then
        if self:IsMovable() then
            dragging = true
            if self.animGroup then self.animGroup:Pause() end
            self:StartMoving()
        end
    end
end)

bunFrame:SetScript("OnMouseUp", function(self, button)
    if dragging and button == "LeftButton" then
        dragging = false
        self:StopMovingOrSizing()

        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        BunReminder.db.point = point or "CENTER"
        BunReminder.db.relativePoint = relativePoint or "CENTER"
        BunReminder.db.x = xOfs
        BunReminder.db.y = yOfs

        if self.animGroup then self.animGroup:Play() end
        return
    end

    if button == "RightButton" and not IsShiftKeyDown() then
        PVEFrame_ShowFrame("GroupFinderFrame", "LFDParentFrame")
    end
end)

local function RegisterAceSettings()
    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")

    local options = {
        name = "Bun Reminder",
        type = "group",
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = "Enable Addon",
                desc = "Show reminder icon when Mana Buns are missing.",
                get = function() return BunReminder.db.enabled end,
                set = function(_, val) BunReminder.db.enabled = val; UpdateFrame() end,
            },
            iconSize = {
                order = 2,
                type = "range",
                name = "Icon Size",
                desc = "Adjust the size of the Mana Bun icon.",
                min = 16,
                max = 128,
                step = 2,
                get = function() return BunReminder.db.width or 64 end,
                set = function(_, val) 
                    BunReminder.db.width = val
                    BunReminder.db.height = val
                    UpdateFrame()
                end,
            },
            rolesHeader = {
                order = 3,
                type = "header",
                name = "Role Filters",
            },
            showTank = {
                order = 4,
                type = "toggle",
                name = "Show for Tank",
                get = function() return BunReminder.db.showTank end,
                set = function(_, val) BunReminder.db.showTank = val; UpdateFrame() end,
            },
            showHealer = {
                order = 5,
                type = "toggle",
                name = "Show for Healer",
                get = function() return BunReminder.db.showHealer end,
                set = function(_, val) BunReminder.db.showHealer = val; UpdateFrame() end,
            },
            showDPS = {
                order = 6,
                type = "toggle",
                name = "Show for DPS",
                get = function() return BunReminder.db.showDPS end,
                set = function(_, val) BunReminder.db.showDPS = val; UpdateFrame() end,
            },
            
            ----------------------------------------------------
            -- SPEC FILTERS (EXPAND/COLLAPSE TOGGLE)
            ----------------------------------------------------
            specsHeader = {
                order = 7,
                type = "header",
                name = "Advanced Filters",
            },
            toggleSpecFilters = {
                order = 8,
                type = "toggle",
                name = "Show Individual Class Specialization Filters",
                desc = "Check this to expand detailed toggles for specific specs.",
                width = "full",
                get = function() return BunReminder.db.showSpecFilters end,
                set = function(_, val) BunReminder.db.showSpecFilters = val end,
            },
            classGroup = {
                order = 9,
                type = "group",
                name = "Class Specializations",
                inline = true,
                -- Hides all spec checkboxes unless toggleSpecFilters is checked
                hidden = function() return not BunReminder.db.showSpecFilters end,
                args = {}
            }
        },
    }

    -- Dynamically generate class sub-sections
    local orderIndex = 1
    for classID = 1, GetNumClasses() do
        local className = GetClassInfo(classID)
        local numSpecs = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID and C_SpecializationInfo.GetNumSpecializationsForClassID(classID)

        if className and numSpecs and numSpecs > 0 then
            local classArgs = {}

            for i = 1, numSpecs do
                local specID, specName = GetSpecializationInfoForClassID(classID, i)
                if specID then
                    classArgs["spec_" .. specID] = {
                        type = "toggle",
                        name = specName,
                        order = i,
                        get = function()
                            return BunReminder.db.enabledSpecs[specID] ~= false
                        end,
                        set = function(_, value)
                            BunReminder.db.enabledSpecs[specID] = value
                            UpdateFrame()
                        end,
                    }
                end
            end

            options.args.classGroup.args["class_" .. classID] = {
                type = "group",
                name = className,
                order = orderIndex,
                inline = true,
                args = classArgs
            }
            orderIndex = orderIndex + 1
        end
    end

    AceConfig:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName, "Bun Reminder")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitializeDatabase()
        RegisterAceSettings()
        UpdateFrame()
    else
        UpdateFrame()
    end
end)

SLASH_BUNREMINDER1 = "/bun"
SLASH_BUNREMINDER2 = "/bunreminder"

SlashCmdList["BUNREMINDER"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "help" then
        print("|cff00ff00[Bun Reminder]|r Commands:")
        print("  |cffffcc00/bun|r - Open options panel")
        print("  |cffffcc00/bun help|r - Show command list")
        print("  |cffffcc00/bun reset|r - Reset icon position and database to default")
        print("  |cffffcc00/bun size <number>|r - Set icon size (e.g. /bun size 64)")

    elseif cmd == "reset" then
        for k, v in pairs(defaultValues) do
            if type(v) == "table" then
                BunReminder.db[k] = CopyTable(v)
            else
                BunReminder.db[k] = v
            end
        end
        UpdateFrame()
        print("|cff00ff00[Bun Reminder]|r Settings and position have been reset.")

    elseif cmd == "size" then
        local size = tonumber(arg)
        if size and size >= 16 and size <= 128 then
            BunReminder.db.width = size
            BunReminder.db.height = size
            UpdateFrame()
            print("|cff00ff00[Bun Reminder]|r Icon size set to " .. size)
        else
            print("|cff00ff00[Bun Reminder]|r Please specify a size between 16 and 128 (e.g., /bun size 64)")
        end

    else
        LibStub("AceConfigDialog-3.0"):Open(addonName)
    end
end