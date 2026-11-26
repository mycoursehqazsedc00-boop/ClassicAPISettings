-- ClassicAPISettings: Vanilla Minimap Button
-- Strict Lua 5.0 compatible.

ClassicAPISettings = ClassicAPISettings or {}
local CAS = ClassicAPISettings

local mmBtn = nil
local isDragging = false

local function UpdateButtonPosition()
    if not mmBtn then return end
    local angle = (ClassicAPISettingsDB and ClassicAPISettingsDB.minimapAngle) or 215
    local rad = math.rad(angle)
    local x = math.cos(rad) * 80
    local y = math.sin(rad) * 80
    mmBtn:ClearAllPoints()
    mmBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function CAS.CreateMinimapButton()
    if mmBtn then return mmBtn end

    mmBtn = CreateFrame("Button", "ClassicAPISettingsMinimapButton", Minimap)
    mmBtn:SetWidth(31)
    mmBtn:SetHeight(31)
    mmBtn:SetFrameStrata("MEDIUM")
    mmBtn:SetFrameLevel(8)
    mmBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mmBtn:RegisterForDrag("LeftButton")
    mmBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = mmBtn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetWidth(20)
    bg:SetHeight(20)
    bg:SetPoint("CENTER", mmBtn, "CENTER", 0, 0)

    local icon = mmBtn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetWidth(18)
    icon:SetHeight(18)
    icon:SetPoint("CENTER", mmBtn, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = mmBtn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetPoint("TOPLEFT", mmBtn, "TOPLEFT", 0, 0)

    mmBtn:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            CAS.ToggleUI("overlaps")
        else
            CAS.ToggleUI()
        end
    end)

    mmBtn:SetScript("OnDragStart", function()
        isDragging = true
        this:SetScript("OnUpdate", function()
            if not isDragging then
                this:SetScript("OnUpdate", nil)
                return
            end
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx = cx / scale
            cy = cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            if ClassicAPISettingsDB then
                ClassicAPISettingsDB.minimapAngle = angle
            end
            UpdateButtonPosition()
        end)
    end)

    mmBtn:SetScript("OnDragStop", function()
        isDragging = false
        this:SetScript("OnUpdate", nil)
    end)

    mmBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("ClassicAPI Settings (" .. CAS.TARGET_CLASSICAPI_STRING .. "+)", 1, 0.82, 0)
        if not CAS.Mods.classicapi then
            GameTooltip:AddLine("ClassicAPI.dll not detected! Install " .. CAS.TARGET_CLASSICAPI_STRING .. "+", 1, 0.25, 0.25)
        elseif CAS.Mods.classicapiOutdated then
            GameTooltip:AddLine("Installed: " .. CAS.Mods.classicapiVersion .. " (Update to " .. CAS.TARGET_CLASSICAPI_STRING .. "+)", 1, 0.65, 0.15)
        else
            GameTooltip:AddLine("Installed: ClassicAPI " .. CAS.Mods.classicapiVersion, 0.3, 1, 0.3)
        end
        local high, warn = CAS.GetOverlapCounts()
        if high > 0 then
            GameTooltip:AddLine(high .. " HIGH overlap warning(s)!", 1, 0.25, 0.25)
        elseif warn > 0 then
            GameTooltip:AddLine(warn .. " overlap warning(s)", 1, 0.7, 0.2)
        end
        GameTooltip:AddLine("Left-Click: Open Settings", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Right-Click: Open Overlaps Tab", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Drag: Move Button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    mmBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateButtonPosition()
    return mmBtn
end

function CAS.UpdateMinimapButton()
    if not mmBtn then
        CAS.CreateMinimapButton()
    end
    if ClassicAPISettingsDB and ClassicAPISettingsDB.showMinimap == false then
        mmBtn:Hide()
    else
        UpdateButtonPosition()
        mmBtn:Show()
    end
end
