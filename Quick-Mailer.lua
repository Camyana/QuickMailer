-- QuickMailer Addon
-- Quick mail consumables to alts

local addonName, addon = ...

-- Initialize addon without Ace3 dependencies
local QM = {}
_G["QuickMailer"] = QM

-- Class colors for dropdown
local CLASS_COLORS = {
    WARRIOR = {0.78, 0.61, 0.43},
    PALADIN = {0.96, 0.55, 0.73},
    HUNTER = {0.67, 0.83, 0.45},
    ROGUE = {1.00, 0.96, 0.41},
    PRIEST = {1.00, 1.00, 1.00},
    DEATHKNIGHT = {0.77, 0.12, 0.23},
    SHAMAN = {0.00, 0.44, 0.87},
    MAGE = {0.25, 0.78, 0.92},
    WARLOCK = {0.53, 0.53, 0.93},
    MONK = {0.00, 1.00, 0.59},
    DRUID = {1.00, 0.49, 0.04},
    DEMONHUNTER = {0.64, 0.19, 0.79},
    EVOKER = {0.20, 0.58, 0.50}
}

-- Default saved variables
QM.db = {
    profile = {
        trackedItems = {},
        mailSubject = "Consumables",
        characters = {} -- Format: {charName = {class = "WARRIOR", lastSeen = timestamp, realm = "RealmName"}}
    }
}

-- Item categories for quick selection
local itemCategories = {
    consumables = {
        name = "Consumables",
        items = {
            [171285] = "Lightless Silk", -- Example items
            [172230] = "Heavy Callous Hide",
            [183951] = "Vestige of Origins",
        }
    },
    reagents = {
        name = "Reagents", 
        items = {
            [171840] = "Porous Stone",
            [171841] = "Chunk o' Mammoth",
        }
    }
}

-- Event frame for handling addon events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("MAIL_SHOW")
eventFrame:RegisterEvent("MAIL_CLOSED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        QM:OnInitialize()
    elseif event == "MAIL_SHOW" then
        QM:OnMailShow()
    elseif event == "MAIL_CLOSED" then
        QM:OnMailClosed()
    elseif event == "PLAYER_LOGIN" then
        QM:OnPlayerLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        QM:OnPlayerEnteringWorld()
    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        QM:OnBagUpdate()
    end
end)

function QM:OnInitialize()
    -- Load saved variables with proper structure
    if QuickMailerDB then
        QM.db = QuickMailerDB
    else
    -- Ensure proper structure exists
        QM.db = {
            profile = {
                trackedItems = {},
                mailSubject = "Consumables",
                characters = {}
            }
        }
    end
    
    -- Ensure profile exists even if loaded data is malformed
    if not QM.db.profile then
        QM.db.profile = {
            trackedItems = {},
            mailSubject = "Consumables",
            characters = {}
        }
    end
    
    -- Ensure trackedItems exists
    if not QM.db.profile.trackedItems then
        QM.db.profile.trackedItems = {}
    end
    
    -- Ensure characters exists
    if not QM.db.profile.characters then
        QM.db.profile.characters = {}
        print("QuickMailer: Added characters tracking to existing save data")
    end
    
    -- Register slash commands
    SLASH_QM1 = "/qm"
    SLASH_QM2 = "/quickmailer"
    SlashCmdList["QM"] = function(input)
        QM:SlashCommand(input)
    end
    
    -- Create the main frame
    self:CreateMainFrame()
    
    -- Record current character (in case PLAYER_LOGIN already fired)
    self:RecordCurrentCharacter()
    
    print("QuickMailer loaded! Use /qm to open the interface.")
end

function QM:RecordCurrentCharacter()
    local playerName = UnitName("player")
    local playerClass = UnitClass("player")
    local realmName = GetRealmName()
    local timestamp = time()
    
    if playerName and playerClass and playerName ~= "Unknown" and playerName ~= "" then
        self.db.profile.characters[playerName] = {
            class = playerClass,
            lastSeen = timestamp,
            realm = realmName or "Unknown"
        }
        return true
    else
        return false
    end
end

function QM:OnPlayerLogin()
    -- Record current character
    self:RecordCurrentCharacter()
end

function QM:OnPlayerEnteringWorld()
    -- This fires after PLAYER_LOGIN and character data should be fully available
    local recorded = self:RecordCurrentCharacter()
    
    -- If we still couldn't record, try again in a moment
    if not recorded then
        C_Timer.After(1, function()
            self:RecordCurrentCharacter()
        end)
    end
end

function QM:OnBagUpdate()
    -- Only refresh if the main frame is shown and we have item buttons
    if self.mainFrame and self.mainFrame:IsShown() and self.itemButtons then
        self:RefreshQuantityInputs()
    end
end

function QM:GetSortedCharacters()
    local chars = {}
    local currentChar = UnitName("player")
    
    -- Convert to sortable array, excluding current character
    for name, data in pairs(self.db.profile.characters) do
        if name ~= currentChar then
            table.insert(chars, {
                name = name,
                class = data.class,
                lastSeen = data.lastSeen,
                realm = data.realm
            })
        end
    end
    
    -- Sort by lastSeen (most recent first)
    table.sort(chars, function(a, b)
        return a.lastSeen > b.lastSeen
    end)
    
    return chars
end

function QM:CreateCharacterDropdown()
    local dropdown = CreateFrame("Frame", "QuickMailerCharDropdown", self.mainFrame)
    dropdown:SetSize(120, 20)
    -- Position to the right of the "Send to:" label
    dropdown:SetPoint("LEFT", self.charLabel, "RIGHT", 8, 0)
    
    -- Dropdown background (completely clean, no additional elements)
    local dropBg = dropdown:CreateTexture(nil, "BACKGROUND")
    dropBg:SetAllPoints()
    dropBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    
    -- Dropdown text (no additional visual elements, full width)
    local dropText = dropdown:CreateFontString(nil, "OVERLAY")
    dropText:SetPoint("LEFT", dropdown, "LEFT", 6, 0)
    dropText:SetPoint("RIGHT", dropdown, "RIGHT", -6, 0)
    dropText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    dropText:SetText("Select Character")
    dropText:SetTextColor(0.8, 0.8, 0.8, 1)
    dropText:SetJustifyH("LEFT")
    dropText:SetJustifyV("MIDDLE")
    
    dropdown.text = dropText
    dropdown.background = dropBg
    dropdown.isOpen = false
    
    -- Click handler
    dropdown:EnableMouse(true)
    dropdown:SetScript("OnMouseUp", function()
        self:ToggleCharacterDropdown(dropdown)
    end)
    
    -- Hover effects
    dropdown:SetScript("OnEnter", function()
        dropBg:SetColorTexture(0.2, 0.2, 0.2, 1)
    end)
    dropdown:SetScript("OnLeave", function()
        dropBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    end)
    
    self.characterDropdown = dropdown
    return dropdown
end

function QM:ToggleCharacterDropdown(dropdown)
    if dropdown.isOpen then
        self:HideCharacterDropdown()
    else
        self:ShowCharacterDropdown()
    end
end

function QM:ShowCharacterDropdown()
    if not self.dropdownMenu then
        self:CreateDropdownMenu()
    end
    
    local chars = self:GetSortedCharacters()
    
    self:PopulateDropdownMenu(chars)
    self.dropdownMenu:Show()
    self.characterDropdown.isOpen = true
end

function QM:HideCharacterDropdown()
    if self.dropdownMenu then
        self.dropdownMenu:Hide()
    end
    self.characterDropdown.isOpen = false
end

function QM:CreateDropdownMenu()
    local menu = CreateFrame("Frame", nil, self.mainFrame)
    menu:SetSize(120, 100)
    menu:SetPoint("TOP", self.characterDropdown, "BOTTOM", 0, -2)
    menu:SetFrameStrata("DIALOG")
    menu:Hide()
    
    -- Clean menu background (no extra visual elements)
    local menuBg = menu:CreateTexture(nil, "BACKGROUND")
    menuBg:SetAllPoints()
    menuBg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    
    -- Simple content area (no borders or extra decorations)
    local contentFrame = CreateFrame("Frame", nil, menu)
    contentFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
    contentFrame:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2)
    contentFrame:SetHeight(96)
    
    menu.contentFrame = contentFrame
    menu.menuItems = {}
    
    self.dropdownMenu = menu
    return menu
end

function QM:PopulateDropdownMenu(chars)
    local menu = self.dropdownMenu
    
    -- Clear existing items
    for _, item in ipairs(menu.menuItems) do
        item:Hide()
    end
    wipe(menu.menuItems)
    
    -- Calculate menu size based on number of characters
    local itemHeight = 20
    local padding = 4
    local numChars = #chars
    local menuHeight = math.max(30, (numChars * itemHeight) + (padding * 2))
    
    -- Resize menu to fit content
    menu:SetHeight(menuHeight)
    menu.contentFrame:SetHeight(menuHeight - (padding * 2))
    
    local yOffset = 0
    
    for _, charData in ipairs(chars) do
        local item = self:CreateDropdownMenuItem(charData, yOffset)
        table.insert(menu.menuItems, item)
        yOffset = yOffset - itemHeight
    end
end

function QM:CreateDropdownMenuItem(charData, yOffset)
    local item = CreateFrame("Button", nil, self.dropdownMenu.contentFrame)
    item:SetSize(116, 18)
    item:SetPoint("TOPLEFT", 2, yOffset)
    
    -- Item background (transparent by default)
    local itemBg = item:CreateTexture(nil, "BACKGROUND")
    itemBg:SetAllPoints()
    itemBg:SetColorTexture(0, 0, 0, 0)
    
    -- Character name with class color
    local nameText = item:CreateFontString(nil, "OVERLAY")
    nameText:SetPoint("LEFT", item, "LEFT", 6, 0)
    nameText:SetPoint("RIGHT", item, "RIGHT", -6, 0)
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    nameText:SetText(charData.name)
    nameText:SetJustifyH("LEFT")
    nameText:SetJustifyV("MIDDLE")
    
    -- Apply class color
    local classKey = string.upper(charData.class)
    local classColor = CLASS_COLORS[classKey] or {1, 1, 1}
    nameText:SetTextColor(classColor[1], classColor[2], classColor[3], 1)
    
    -- Click handler
    item:SetScript("OnClick", function()
        self:SelectCharacter(charData.name)
    end)
    
    -- Hover effects
    item:SetScript("OnEnter", function()
        itemBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    end)
    item:SetScript("OnLeave", function()
        itemBg:SetColorTexture(0, 0, 0, 0)
    end)
    
    return item
end

function QM:SelectCharacter(charName)
    -- Fill the mail recipient field
    if SendMailNameEditBox then
        SendMailNameEditBox:SetText(charName)
    end
    
    -- Update dropdown text
    if self.characterDropdown and self.characterDropdown.text then
        self.characterDropdown.text:SetText(charName)
        
        -- Apply class color to dropdown text
        local charData = self.db.profile.characters[charName]
        if charData and charData.class then
            -- Convert class to uppercase for lookup
            local classKey = string.upper(charData.class)
            local classColor = CLASS_COLORS[classKey] or {1, 1, 1}
            self.characterDropdown.text:SetTextColor(classColor[1], classColor[2], classColor[3], 1)
        else
            self.characterDropdown.text:SetTextColor(0.8, 0.8, 0.8, 1)
        end
    end
    
    -- Hide dropdown
    self:HideCharacterDropdown()
end

function QM:SlashCommand(input)
    if not input or input:trim() == "" then
        self:ToggleMainFrame()
    elseif input == "presets" then
        self:AddConsumablePresets()
    elseif input == "debug" then
        self:DebugCharacters()
    elseif input == "record" then
        self:RecordCurrentCharacter()
    elseif input == "save" then
        QuickMailerDB = QM.db
        print("QuickMailer: Forced save of current data")
    elseif input:match("^addchar ") then
        local charName = input:match("^addchar (.+)")
        self:AddTestCharacter(charName)
    else
        print("Usage: /qm - Open main interface")
        print("       /qm presets - Add common consumable presets")
        print("       /qm debug - Show character debug info")
        print("       /qm record - Manually record current character")
        print("       /qm save - Force save data immediately")
        print("       /qm addchar <name> - Add test character")
    end
end

function QM:AddTestCharacter(charName)
    if charName and charName ~= "" then
        self.db.profile.characters[charName] = {
            class = "WARRIOR",
            lastSeen = time() - 3600, -- 1 hour ago
            realm = GetRealmName() or "TestRealm"
        }
    end
end

function QM:DebugCharacters()
    print("QuickMailer Character Debug:")
    print("Current character: " .. (UnitName("player") or "Unknown"))
    print("Total characters stored: " .. (self.db.profile.characters and #self.db.profile.characters or 0))
    
    if self.db.profile.characters then
        local count = 0
        for name, data in pairs(self.db.profile.characters) do
            count = count + 1
            print(string.format("  %s (%s) - Last seen: %s", 
                name, 
                data.class or "Unknown", 
                date("%Y-%m-%d %H:%M:%S", data.lastSeen or 0)
            ))
        end
        print("Actual character count: " .. count)
        
        -- Test sorted characters
        local sortedChars = self:GetSortedCharacters()
        print("Sorted characters (excluding current): " .. #sortedChars)
        for i, char in ipairs(sortedChars) do
            print(string.format("  %d. %s (%s)", i, char.name, char.class))
        end
    else
        print("Characters table is nil!")
    end
end

function QM:CreateMainFrame()
    -- Create completely custom frame without templates
    local frame = CreateFrame("Frame", "QuickMailerFrame", UIParent)
    frame:SetSize(280, 350)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
    -- Hide dropdown when clicking on main frame
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and QM.characterDropdown and QM.characterDropdown.isOpen then
            QM:HideCharacterDropdown()
        end
    end)
    
    self.mainFrame = frame
    
    -- Set initial position off-screen to avoid flicker
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -1000, -1000)
    
    -- Create custom background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    
    -- Create custom border
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints()
    
    -- Top border
    local topBorder = border:CreateTexture(nil, "OVERLAY")
    topBorder:SetPoint("TOPLEFT", 0, 0)
    topBorder:SetPoint("TOPRIGHT", 0, 0)
    topBorder:SetHeight(1)
    topBorder:SetColorTexture(0, 0, 0, 1)
    
    -- Bottom border
    local bottomBorder = border:CreateTexture(nil, "OVERLAY")
    bottomBorder:SetPoint("BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    bottomBorder:SetHeight(1)
    bottomBorder:SetColorTexture(0, 0, 0, 1)
    
    -- Left border
    local leftBorder = border:CreateTexture(nil, "OVERLAY")
    leftBorder:SetPoint("TOPLEFT", 0, 0)
    leftBorder:SetPoint("BOTTOMLEFT", 0, 0)
    leftBorder:SetWidth(1)
    leftBorder:SetColorTexture(0, 0, 0, 1)
    
    -- Right border
    local rightBorder = border:CreateTexture(nil, "OVERLAY")
    rightBorder:SetPoint("TOPRIGHT", 0, 0)
    rightBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    rightBorder:SetWidth(1)
    rightBorder:SetColorTexture(0, 0, 0, 1)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(18, 18)
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() frame:Hide() end)
    
    -- Close button background (transparent)
    local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints()
    closeBg:SetColorTexture(0, 0, 0, 0)
    
    -- Close button X
    local closeText = closeButton:CreateFontString(nil, "OVERLAY")
    closeText:SetAllPoints()
    closeText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    closeText:SetText("×")
    closeText:SetTextColor(1, 1, 1, 1)
    closeText:SetJustifyH("CENTER")
    closeText:SetJustifyV("MIDDLE")
    
    -- Close button hover effect (slight gray background on hover)
    closeButton:SetScript("OnEnter", function()
        closeBg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
    end)
    closeButton:SetScript("OnLeave", function()
        closeBg:SetColorTexture(0, 0, 0, 0)
    end)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    title:SetText("QuickMailer")
    title:SetTextColor(1, 1, 1, 1)
    
    -- Items label
    local itemsLabel = frame:CreateFontString(nil, "OVERLAY")
    itemsLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -35)
    itemsLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    itemsLabel:SetText("Items to Mail:")
    itemsLabel:SetTextColor(0.9, 0.9, 0.9, 1)
    
    -- Instruction text
    local instructionText = frame:CreateFontString(nil, "OVERLAY")
    instructionText:SetPoint("TOPLEFT", itemsLabel, "BOTTOMLEFT", 0, -3)
    instructionText:SetFont("Fonts\\FRIZQT__.TTF", 9)
    instructionText:SetText("(Drag items from inventory to add)")
    instructionText:SetTextColor(0.6, 0.6, 0.6, 1)
    
    -- Custom scroll area
    local scrollFrame = CreateFrame("Frame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", instructionText, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetSize(256, 180)
    
    -- Scroll area background
    local scrollBg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    scrollBg:SetAllPoints()
    scrollBg:SetColorTexture(0, 0, 0, 0.7)
    
    -- Scroll area border
    local scrollBorderTop = scrollFrame:CreateTexture(nil, "OVERLAY")
    scrollBorderTop:SetPoint("TOPLEFT", 0, 0)
    scrollBorderTop:SetPoint("TOPRIGHT", 0, 0)
    scrollBorderTop:SetHeight(1)
    scrollBorderTop:SetColorTexture(0, 0, 0, 1)
    
    local scrollBorderBottom = scrollFrame:CreateTexture(nil, "OVERLAY")
    scrollBorderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    scrollBorderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    scrollBorderBottom:SetHeight(1)
    scrollBorderBottom:SetColorTexture(0, 0, 0, 1)
    
    local scrollBorderLeft = scrollFrame:CreateTexture(nil, "OVERLAY")
    scrollBorderLeft:SetPoint("TOPLEFT", 0, 0)
    scrollBorderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    scrollBorderLeft:SetWidth(1)
    scrollBorderLeft:SetColorTexture(0, 0, 0, 1)
    
    local scrollBorderRight = scrollFrame:CreateTexture(nil, "OVERLAY")
    scrollBorderRight:SetPoint("TOPRIGHT", 0, 0)
    scrollBorderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    scrollBorderRight:SetWidth(1)
    scrollBorderRight:SetColorTexture(0, 0, 0, 1)
    
    -- Content area for items
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 4, -4)
    scrollChild:SetSize(248, 172)
    scrollChild:Show()
    
    -- Make scroll areas accept item drops
    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            -- Hide character dropdown if open
            if QM.characterDropdown and QM.characterDropdown.isOpen then
                QM:HideCharacterDropdown()
            end
            
            local cursorType, itemID = GetCursorInfo()
            if cursorType == "item" and itemID then
                local itemName = GetItemInfo(itemID)
                if itemName then
                    QM.db.profile.trackedItems[itemID] = itemName
                    QM:UpdateItemsList()
                    ClearCursor()
                end
            end
        end
    end)
    
    scrollChild:EnableMouse(true)
    scrollChild:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            -- Hide character dropdown if open
            if QM.characterDropdown and QM.characterDropdown.isOpen then
                QM:HideCharacterDropdown()
            end
            
            local cursorType, itemID = GetCursorInfo()
            if cursorType == "item" and itemID then
                local itemName = GetItemInfo(itemID)
                if itemName then
                    QM.db.profile.trackedItems[itemID] = itemName
                    QM:UpdateItemsList()
                    ClearCursor()
                end
            end
        end
    end)
    
    self.scrollFrame = scrollFrame
    self.scrollChild = scrollChild
    self.itemButtons = {}
    
    -- Custom insert button
    local insertButton = CreateFrame("Button", nil, frame)
    insertButton:SetSize(140, 20)
    insertButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
    insertButton:SetScript("OnClick", function()
        self:InsertConsumables()
    end)
    
    -- Button background
    local buttonBg = insertButton:CreateTexture(nil, "BACKGROUND")
    buttonBg:SetAllPoints()
    buttonBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Button border
    local buttonBorderTop = insertButton:CreateTexture(nil, "OVERLAY")
    buttonBorderTop:SetPoint("TOPLEFT", 0, 0)
    buttonBorderTop:SetPoint("TOPRIGHT", 0, 0)
    buttonBorderTop:SetHeight(1)
    buttonBorderTop:SetColorTexture(0, 0, 0, 1)
    
    local buttonBorderBottom = insertButton:CreateTexture(nil, "OVERLAY")
    buttonBorderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    buttonBorderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    buttonBorderBottom:SetHeight(1)
    buttonBorderBottom:SetColorTexture(0, 0, 0, 1)
    
    local buttonBorderLeft = insertButton:CreateTexture(nil, "OVERLAY")
    buttonBorderLeft:SetPoint("TOPLEFT", 0, 0)
    buttonBorderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    buttonBorderLeft:SetWidth(1)
    buttonBorderLeft:SetColorTexture(0, 0, 0, 1)
    
    local buttonBorderRight = insertButton:CreateTexture(nil, "OVERLAY")
    buttonBorderRight:SetPoint("TOPRIGHT", 0, 0)
    buttonBorderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    buttonBorderRight:SetWidth(1)
    buttonBorderRight:SetColorTexture(0, 0, 0, 1)
    
    -- Button text
    local buttonText = insertButton:CreateFontString(nil, "OVERLAY")
    buttonText:SetAllPoints()
    buttonText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    buttonText:SetText("Insert Consumables")
    buttonText:SetTextColor(1, 1, 1, 1)
    buttonText:SetJustifyH("CENTER")
    buttonText:SetJustifyV("MIDDLE")
    
    -- Button hover effects
    insertButton:SetScript("OnEnter", function()
        buttonBg:SetColorTexture(0.3, 0.3, 0.3, 1)
    end)
    insertButton:SetScript("OnLeave", function()
        buttonBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    end)
    
    self.insertButton = insertButton
    
    -- Character dropdown label
    local charLabel = frame:CreateFontString(nil, "OVERLAY")
    charLabel:SetPoint("BOTTOM", insertButton, "TOP", -80, 32)
    charLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    charLabel:SetText("Send to:")
    charLabel:SetTextColor(0.9, 0.9, 0.9, 1)
    
    -- Store label reference for dropdown positioning
    self.charLabel = charLabel
    
    -- Create character dropdown
    self:CreateCharacterDropdown()
    
    -- Status text
    local statusText = frame:CreateFontString(nil, "OVERLAY")
    statusText:SetPoint("BOTTOM", insertButton, "TOP", 0, 6)
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 9)
    statusText:SetText("Ready")
    statusText:SetTextColor(0.8, 0.8, 0.8, 1)
    self.statusText = statusText
    
    self:UpdateItemsList()
end

function QM:ToggleMainFrame()
    -- Ensure frame exists
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:UpdateItemsList()
        self:PositionFrameNextToMailbox()
    end
end

function QM:CreateMailboxButton()
    -- Only create the button once
    if self.mailboxButton then
        self.mailboxButton:Show()
        return
    end
    
    -- Create custom button on the mailbox frame
    local button = CreateFrame("Button", "QuickMailerMailButton", MailFrame)
    button:SetSize(90, 18)
    button:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 5, -30)
    button:SetFrameStrata("HIGH")
    
    -- Button background
    local buttonBg = button:CreateTexture(nil, "BACKGROUND")
    buttonBg:SetAllPoints()
    buttonBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    
    -- Button border
    local borderTop = button:CreateTexture(nil, "OVERLAY")
    borderTop:SetPoint("TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", 0, 0)
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(0, 0, 0, 1)
    
    local borderBottom = button:CreateTexture(nil, "OVERLAY")
    borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    borderBottom:SetHeight(1)
    borderBottom:SetColorTexture(0, 0, 0, 1)
    
    local borderLeft = button:CreateTexture(nil, "OVERLAY")
    borderLeft:SetPoint("TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    borderLeft:SetWidth(1)
    borderLeft:SetColorTexture(0, 0, 0, 1)
    
    local borderRight = button:CreateTexture(nil, "OVERLAY")
    borderRight:SetPoint("TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    borderRight:SetWidth(1)
    borderRight:SetColorTexture(0, 0, 0, 1)
    
    -- Button text
    local buttonText = button:CreateFontString(nil, "OVERLAY")
    buttonText:SetAllPoints()
    buttonText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    buttonText:SetText("QuickMailer")
    buttonText:SetTextColor(1, 1, 1, 1)
    buttonText:SetJustifyH("CENTER")
    buttonText:SetJustifyV("MIDDLE")
    
    -- Button hover effects
    button:SetScript("OnEnter", function()
        buttonBg:SetColorTexture(0.2, 0.2, 0.2, 1)
    end)
    button:SetScript("OnLeave", function()
        buttonBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    end)
    
    button:SetScript("OnClick", function()
        self:ToggleMainFrameFromMailbox()
    end)
    
    self.mailboxButton = button
end

function QM:ToggleMainFrameFromMailbox()
    -- Ensure frame exists
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        -- Position next to mailbox first
        self:PositionFrameNextToMailbox()
        self.mainFrame:Show()
        self:UpdateItemsList()
    end
end

function QM:PositionFrameNextToMailbox()
    if MailFrame and MailFrame:IsShown() then
        -- Position to the right of the mailbox with better alignment
        self.mainFrame:ClearAllPoints()
        self.mainFrame:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 10, 0)
        self.mainFrame:SetFrameStrata("HIGH")
    else
        -- Default center position if mailbox isn't open
        self.mainFrame:ClearAllPoints()
        self.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end
end

function QM:GetItemCountInInventory(itemID)
    local totalCount = 0
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo and itemInfo.itemID == itemID then
                totalCount = totalCount + (itemInfo.stackCount or 1)
            end
        end
    end
    return totalCount
end

function QM:UpdateItemsList()
    -- Ensure itemButtons table exists
    if not self.itemButtons then
        self.itemButtons = {}
    end
    
    -- Clear existing buttons
    for _, button in ipairs(self.itemButtons) do
        button:Hide()
    end
    wipe(self.itemButtons)
    
    -- Ensure we have scroll child before creating buttons
    if not self.scrollChild then
        return
    end
    
    local yOffset = 0
    
    for itemID, itemName in pairs(self.db.profile.trackedItems) do
        local button = self:CreateItemButton(itemID, itemName, yOffset)
        table.insert(self.itemButtons, button)
        yOffset = yOffset - 22  -- Clean compact spacing
    end
    
    -- Update scroll child height
    self.scrollChild:SetHeight(math.max(200, math.abs(yOffset)))
    
    -- Refresh quantity inputs when bags change
    self:RefreshQuantityInputs()
end

function QM:RefreshQuantityInputs()
    for _, button in ipairs(self.itemButtons) do
        if button.quantityInput and button.itemID then
            local maxQuantity = self:GetItemCountInInventory(button.itemID)
            local currentValue = tonumber(button.quantityInput:GetText()) or 0
            
            -- If current value is higher than available, reset to max
            if currentValue > maxQuantity then
                button.quantityInput:SetText(tostring(maxQuantity))
            end
        end
    end
end

function QM:CreateItemButton(itemID, itemName, yOffset)
    local button = CreateFrame("Button", nil, self.scrollChild)
    button:SetSize(240, 20)
    button:SetPoint("TOPLEFT", 4, yOffset)
    
    -- Clean hover background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
    bg:Hide()
    
    button:SetScript("OnEnter", function() 
        bg:Show()
    end)
    button:SetScript("OnLeave", function() 
        bg:Hide()
    end)
    
    -- Clean item icon
    local iconFrame = CreateFrame("Frame", nil, button)
    iconFrame:SetSize(16, 16)
    iconFrame:SetPoint("LEFT", 2, 0)
    
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    
    local itemTexture = GetItemIcon(itemID)
    if itemTexture then
        icon:SetTexture(itemTexture)
    end
    
    -- Clean item name text
    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", button, "RIGHT", -80, 0)
    text:SetJustifyH("LEFT")
    text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    text:SetText(itemName)
    text:SetTextColor(1, 1, 1, 1)
    
    -- Get max quantity available in inventory
    local maxQuantity = self:GetItemCountInInventory(itemID)
    
    -- Quantity input field
    local quantityInput = CreateFrame("EditBox", nil, button)
    quantityInput:SetSize(30, 16)
    quantityInput:SetPoint("RIGHT", button, "RIGHT", -50, 0)
    quantityInput:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    quantityInput:SetText(tostring(maxQuantity))
    quantityInput:SetTextColor(1, 1, 1, 1)
    quantityInput:SetJustifyH("CENTER")
    quantityInput:SetAutoFocus(false)
    quantityInput:SetNumeric(true)
    quantityInput:SetMaxLetters(4)
    
    -- Quantity input background
    local inputBg = quantityInput:CreateTexture(nil, "BACKGROUND")
    inputBg:SetAllPoints()
    inputBg:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    
    -- Quantity input border
    local inputBorderTop = quantityInput:CreateTexture(nil, "OVERLAY")
    inputBorderTop:SetPoint("TOPLEFT", 0, 0)
    inputBorderTop:SetPoint("TOPRIGHT", 0, 0)
    inputBorderTop:SetHeight(1)
    inputBorderTop:SetColorTexture(0, 0, 0, 1)
    
    local inputBorderBottom = quantityInput:CreateTexture(nil, "OVERLAY")
    inputBorderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    inputBorderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    inputBorderBottom:SetHeight(1)
    inputBorderBottom:SetColorTexture(0, 0, 0, 1)
    
    local inputBorderLeft = quantityInput:CreateTexture(nil, "OVERLAY")
    inputBorderLeft:SetPoint("TOPLEFT", 0, 0)
    inputBorderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    inputBorderLeft:SetWidth(1)
    inputBorderLeft:SetColorTexture(0, 0, 0, 1)
    
    local inputBorderRight = quantityInput:CreateTexture(nil, "OVERLAY")
    inputBorderRight:SetPoint("TOPRIGHT", 0, 0)
    inputBorderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    inputBorderRight:SetWidth(1)
    inputBorderRight:SetColorTexture(0, 0, 0, 1)
    
    -- Validation for quantity input
    quantityInput:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText()) or 0
        if value > maxQuantity then
            self:SetText(tostring(maxQuantity))
        elseif value < 0 then
            self:SetText("0")
        end
    end)
    
    -- Store the quantity input for later access
    button.quantityInput = quantityInput
    button.itemID = itemID
    
    -- Custom remove button
    local removeBtn = CreateFrame("Button", nil, button)
    removeBtn:SetSize(14, 14)
    removeBtn:SetPoint("RIGHT", -2, 0)
    removeBtn:SetScript("OnClick", function()
        self:RemoveTrackedItem(itemID)
    end)
    
    -- Remove button background
    local removeBg = removeBtn:CreateTexture(nil, "BACKGROUND")
    removeBg:SetAllPoints()
    removeBg:SetColorTexture(0.6, 0.1, 0.1, 0.6)
    
    -- Remove button X
    local removeText = removeBtn:CreateFontString(nil, "OVERLAY")
    removeText:SetAllPoints()
    removeText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    removeText:SetText("×")
    removeText:SetTextColor(1, 1, 1, 1)
    removeText:SetJustifyH("CENTER")
    removeText:SetJustifyV("MIDDLE")
    
    -- Remove button hover
    removeBtn:SetScript("OnEnter", function()
        removeBg:SetColorTexture(0.8, 0.2, 0.2, 1)
    end)
    removeBtn:SetScript("OnLeave", function()
        removeBg:SetColorTexture(0.6, 0.1, 0.1, 0.6)
    end)
    
    return button
end

function QM:ShowAddItemDialog()
    if not self.addItemFrame then
        self:CreateAddItemDialog()
    end
    self.addItemFrame:Show()
end

function QM:CreateAddItemDialog()
    local frame = CreateFrame("Frame", "QuickMailerAddItem", UIParent, "BasicFrameTemplate")
    frame:SetSize(300, 150)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject(GameFontHighlight)
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)
    frame.title:SetText("Add Item")
    
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", frame, "TOP", 0, -40)
    instructions:SetText("Enter item ID or link an item:")
    
    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(200, 20)
    editBox:SetPoint("TOP", instructions, "BOTTOM", 0, -15)
    editBox:SetAutoFocus(true)
    
    local addBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    addBtn:SetSize(80, 25)
    addBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOM", -45, 15)
    addBtn:SetText("Add")
    
    local cancelBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    cancelBtn:SetSize(80, 25)
    cancelBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", 45, 15)
    cancelBtn:SetText("Cancel")
    
    editBox:SetScript("OnEnterPressed", function()
        addBtn:Click()
    end)
    
    addBtn:SetScript("OnClick", function()
        local input = editBox:GetText()
        self:AddItemFromInput(input)
        editBox:SetText("")
        frame:Hide()
    end)
    
    cancelBtn:SetScript("OnClick", function()
        editBox:SetText("")
        frame:Hide()
    end)
    
    self.addItemFrame = frame
end

function QM:AddItemFromInput(input)
    local itemID, itemName
    
    -- Check if it's an item link
    if input:match("|c%x+|Hitem:") then
        itemID = tonumber(input:match("item:(%d+)"))
        itemName = input:match("%[(.-)%]")
    else
        -- Try to parse as item ID
        itemID = tonumber(input)
        if itemID then
            itemName = GetItemInfo(itemID)
        end
    end
    
    if itemID and itemName then
        self.db.profile.trackedItems[itemID] = itemName
        self:UpdateItemsList()
    end
end

function QM:RemoveTrackedItem(itemID)
    local itemName = self.db.profile.trackedItems[itemID]
    self.db.profile.trackedItems[itemID] = nil
    self:UpdateItemsList()
end

function QM:ClearAllItems()
    wipe(self.db.profile.trackedItems)
    self:UpdateItemsList()
end

function QM:InsertConsumables()
    if not MailFrame or not MailFrame:IsShown() then
        print("Please open the mailbox first!")
        return
    end
    
    -- Clear current mail
    for i = 1, ATTACHMENTS_MAX_SEND do
        ClickSendMailItemButton(i, true) -- Remove any existing attachments
    end
    
    -- Set subject
    SendMailSubjectEditBox:SetText(self.db.profile.mailSubject)
    
    -- Auto-fill recipient from dropdown selection
    if self.characterDropdown and self.characterDropdown.text then
        local selectedChar = self.characterDropdown.text:GetText()
        if selectedChar and selectedChar ~= "Select Character" and SendMailNameEditBox then
            SendMailNameEditBox:SetText(selectedChar)
        end
    end
    
    -- Get desired quantities from input fields
    local desiredQuantities = {}
    for _, button in ipairs(self.itemButtons) do
        if button.quantityInput and button.itemID then
            local quantity = tonumber(button.quantityInput:GetText()) or 0
            if quantity > 0 then
                desiredQuantities[button.itemID] = quantity
            end
        end
    end
    
    -- Start the preparation phase
    self:PrepareItemsForMail(desiredQuantities)
end

function QM:PrepareItemsForMail(desiredQuantities)
    -- First, analyze what we need to split
    local preparationPlan = {}
    local foundItems = {}
    
    for itemID, quantity in pairs(desiredQuantities) do
        local stacks = self:FindAllStacksForItem(itemID)
        local totalAvailable = 0
        
        for _, stackInfo in ipairs(stacks) do
            totalAvailable = totalAvailable + stackInfo.count
        end
        
        if totalAvailable > 0 then
            local quantityToTake = math.min(quantity, totalAvailable)
            foundItems[itemID] = quantityToTake
            
            -- Plan how to get this quantity
            local remainingNeeded = quantityToTake
            for _, stackInfo in ipairs(stacks) do
                if remainingNeeded <= 0 then break end
                
                local takeFromStack = math.min(remainingNeeded, stackInfo.count)
                table.insert(preparationPlan, {
                    itemID = itemID,
                    bag = stackInfo.bag,
                    slot = stackInfo.slot,
                    stackSize = stackInfo.count,
                    takeAmount = takeFromStack,
                    needsSplit = (takeFromStack < stackInfo.count)
                })
                remainingNeeded = remainingNeeded - takeFromStack
            end
        end
    end
    
    if #preparationPlan == 0 then
        self.statusText:SetText("No tracked items found")
        self.statusText:SetTextColor(0.6, 0.6, 0.6, 1)
        return
    end
    
    -- Now execute the preparation plan
    self:ExecutePreparationPlan(preparationPlan, 1, foundItems)
end

function QM:FindAllStacksForItem(itemID)
    local stacks = {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo and itemInfo.itemID == itemID then
                table.insert(stacks, {
                    bag = bag,
                    slot = slot,
                    count = itemInfo.stackCount or 1
                })
            end
        end
    end
    return stacks
end

function QM:ExecutePreparationPlan(preparationPlan, planIndex, foundItems)
    if planIndex > #preparationPlan then
        -- All preparations done, now collect the prepared items
        C_Timer.After(0.05, function()
            self:CollectPreparedItems(foundItems)
        end)
        return
    end
    
    local plan = preparationPlan[planIndex]
    
    if plan.needsSplit then
        -- Split the stack
        ClearCursor()
        C_Container.SplitContainerItem(plan.bag, plan.slot, plan.takeAmount)
        
        -- Wait for split, then drop the split items somewhere safe (back in bags)
        C_Timer.After(0.05, function()
            local cursorType = GetCursorInfo()
            if cursorType == "item" then
                -- Find an empty bag slot to place the split items
                local emptyBag, emptySlot = self:FindEmptyBagSlot()
                if emptyBag then
                    C_Container.PickupContainerItem(emptyBag, emptySlot)
                else
                    ClearCursor()
                end
            end
            
            -- Continue with next item after a short delay
            C_Timer.After(0.05, function()
                self:ExecutePreparationPlan(preparationPlan, planIndex + 1, foundItems)
            end)
        end)
    else
        -- Don't need to split, just note this stack for collection
        
        -- Continue immediately to next item
        C_Timer.After(0.05, function()
            self:ExecutePreparationPlan(preparationPlan, planIndex + 1, foundItems)
        end)
    end
end

function QM:FindEmptyBagSlot()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if not itemInfo then -- Empty slot
                return bag, slot
            end
        end
    end
    return nil, nil
end

function QM:CollectPreparedItems(foundItems)
    -- Convert to ordered list for sequential processing
    local itemList = {}
    for itemID, quantity in pairs(foundItems) do
        table.insert(itemList, {itemID = itemID, quantity = quantity})
    end
    
    -- Start collecting items sequentially
    self:CollectItemsSequentially(itemList, 1, 1, {})
end

function QM:CollectItemsSequentially(itemList, itemIndex, attachmentSlot, results)
    if itemIndex > #itemList or attachmentSlot > ATTACHMENTS_MAX_SEND then
        -- All done, finish up
        self:FinishInsertConsumables(results)
        return
    end
    
    local item = itemList[itemIndex]
    
    -- Start collecting this item, each stack goes to a new slot
    self:CollectItemQuantityAsync(item.itemID, item.quantity, attachmentSlot, function(collected, nextSlot)
        if collected > 0 then
            results[item.itemID] = collected
            -- Continue with next item using the next available slot
            C_Timer.After(0.05, function()
                self:CollectItemsSequentially(itemList, itemIndex + 1, nextSlot, results)
            end)
        else
            -- No items collected, move to next item using same slot
            C_Timer.After(0.05, function()
                self:CollectItemsSequentially(itemList, itemIndex + 1, attachmentSlot, results)
            end)
        end
    end)
end

function QM:CollectItemQuantityAsync(itemID, quantity, attachmentSlot, callback)
    -- Find all stacks for this item
    local stacks = {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo and itemInfo.itemID == itemID then
                table.insert(stacks, {
                    bag = bag,
                    slot = slot,
                    count = itemInfo.stackCount or 1
                })
            end
        end
    end
    
    if #stacks == 0 then
        callback(0, attachmentSlot)
        return
    end
    
    -- Start collecting stacks, each stack goes to a new attachment slot
    self:CollectStacksToSlots(stacks, 1, quantity, attachmentSlot, 0, callback)
end

function QM:CollectStacksToSlots(stacks, stackIndex, remainingNeeded, currentSlot, totalCollected, callback)
    if stackIndex > #stacks or remainingNeeded <= 0 or currentSlot > ATTACHMENTS_MAX_SEND then
        -- Done collecting, return total collected and next available slot
        callback(totalCollected, currentSlot)
        return
    end
    
    local stack = stacks[stackIndex]
    local takeAmount = math.min(remainingNeeded, stack.count)
    
    -- Clear cursor and pick up the stack
    ClearCursor()
    C_Container.PickupContainerItem(stack.bag, stack.slot)
    
    -- Wait a moment then attach to mail
    C_Timer.After(0.05, function()
        local cursorType = GetCursorInfo()
        if cursorType == "item" then
            -- Check if slot is empty
            local currentLink = GetSendMailItemLink(currentSlot)
            
            -- Click the attachment slot to attach the entire stack
            ClickSendMailItemButton(currentSlot)
            
            -- Wait and verify the attachment worked
            C_Timer.After(0.05, function()
                local newLink = GetSendMailItemLink(currentSlot)
                if newLink then
                    -- Track what we actually attached
                    totalCollected = totalCollected + takeAmount
                    remainingNeeded = remainingNeeded - takeAmount
                    
                    -- Move to next slot for next stack and continue
                    C_Timer.After(0.05, function()
                        self:CollectStacksToSlots(stacks, stackIndex + 1, remainingNeeded, currentSlot + 1, totalCollected, callback)
                    end)
                else
                    -- Skip this stack and try next one in same slot
                    C_Timer.After(0.05, function()
                        self:CollectStacksToSlots(stacks, stackIndex + 1, remainingNeeded, currentSlot, totalCollected, callback)
                    end)
                end
            end)
        else
            -- Skip this stack and continue
            C_Timer.After(0.05, function()
                self:CollectStacksToSlots(stacks, stackIndex + 1, remainingNeeded, currentSlot, totalCollected, callback)
            end)
        end
    end)
end

function QM:CollectStacksSequentially(stacks, stackIndex, remainingNeeded, attachmentSlot, totalCollected, callback)
    if stackIndex > #stacks or remainingNeeded <= 0 then
        -- Done collecting, return the total we collected
        callback(totalCollected)
        return
    end
    
    local stack = stacks[stackIndex]
    local takeAmount = math.min(remainingNeeded, stack.count)
    
    -- Clear cursor and pick up the stack
    ClearCursor()
    C_Container.PickupContainerItem(stack.bag, stack.slot)
    
    -- Wait a moment then attach to mail
    C_Timer.After(0.05, function()
        local cursorType = GetCursorInfo()
        if cursorType == "item" then
            -- Before attaching, check what's currently in the slot
            local currentLink = GetSendMailItemLink(attachmentSlot)
            local currentCount = 0
            
            -- Click the attachment slot - first item goes in, subsequent items should combine
            ClickSendMailItemButton(attachmentSlot)
            
            -- Wait and verify the attachment worked
            C_Timer.After(0.05, function()
                local newLink = GetSendMailItemLink(attachmentSlot)
                if newLink then
                    -- Since we can't get reliable counts from the API, track manually
                    local actualTaken = takeAmount -- Use the theoretical amount we tried to attach
                    totalCollected = totalCollected + actualTaken
                    remainingNeeded = remainingNeeded - actualTaken
                else
                    -- Skip this stack if attachment failed
                    local actualTaken = 0
                end
                
                -- Wait a bit before next stack to ensure proper combining
                C_Timer.After(0.05, function()
                    -- If we still need more items, continue with next stack
                    if remainingNeeded > 0 and stackIndex < #stacks then
                        self:CollectStacksSequentially(stacks, stackIndex + 1, remainingNeeded, attachmentSlot, totalCollected, callback)
                    else
                        -- We have enough or no more stacks, do final verification
                        C_Timer.After(0.05, function()
                            local finalLink = GetSendMailItemLink(attachmentSlot)
                            if finalLink then
                                callback(totalCollected)
                            else
                                callback(0)
                            end
                        end)
                    end
                end)
            end)
        else
            -- Skip this stack and continue
            C_Timer.After(0.05, function()
                self:CollectStacksSequentially(stacks, stackIndex + 1, remainingNeeded, attachmentSlot, totalCollected, callback)
            end)
        end
    end)
end

function QM:FinishInsertConsumables(foundItems)
    local totalItemTypes = 0
    local totalItems = 0
    local totalStacks = 0
    
    -- Count items and estimate stacks
    for itemID, count in pairs(foundItems) do
        totalItemTypes = totalItemTypes + 1
        totalItems = totalItems + count
        
        -- Estimate number of stacks (assuming ~200 per stack for most items)
        local estimatedStackSize = 200 -- Most items stack to 200
        totalStacks = totalStacks + math.ceil(count / estimatedStackSize)
    end
    
    -- Update status
    if totalItemTypes > 0 then
        self.statusText:SetText(string.format("Attached %d items (%d stacks)", totalItems, totalStacks))
        self.statusText:SetTextColor(1, 1, 1, 1) -- Clean white for success
    else
        self.statusText:SetText("No tracked items found")
        self.statusText:SetTextColor(0.6, 0.6, 0.6, 1) -- Gray for no items
    end
end

function QM:OnMailShow()
    -- Create or show the mailbox button when mailbox opens
    self:CreateMailboxButton()
    
    -- Enable insert button when mail is open
    if self.insertButton then
        self.insertButton:Enable()
    end
    
    -- Hide character dropdown when mail opens
    if self.characterDropdown and self.characterDropdown.isOpen then
        self:HideCharacterDropdown()
    end
end

function QM:OnMailClosed()
    -- Hide the frame when mailbox closes
    if self.mainFrame and self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    end
    
    -- Hide the mailbox button when mailbox closes
    if self.mailboxButton then
        self.mailboxButton:Hide()
    end
    
    -- Reset status when mail closes
    if self.statusText then
        self.statusText:SetText("Ready")
        self.statusText:SetTextColor(0.8, 0.8, 0.8, 1) -- Reset to light gray
    end
end

function QM:AddConsumablePresets()
    local presets = {
        -- Common consumables and reagents (update item IDs for current expansion)
        [183951] = "Vestige of Origins",      -- Shadowlands crafting reagent
        [171285] = "Lightless Silk",          -- Shadowlands cloth
        [172230] = "Heavy Callous Hide",      -- Shadowlands leather
        [171840] = "Porous Stone",            -- Shadowlands mining
        [171841] = "Chunk o' Mammoth",        -- Shadowlands mining
        [190396] = "Serevite Ore",            -- Dragonflight ore
        [193050] = "Tattered Wildercloth",    -- Dragonflight cloth
        [198048] = "Titan Training Matrix I", -- Dragonflight consumable
        -- Add more current expansion items here
    }
    
    local addedCount = 0
    for itemID, itemName in pairs(presets) do
        if not self.db.profile.trackedItems[itemID] then
            self.db.profile.trackedItems[itemID] = itemName
            addedCount = addedCount + 1
        end
    end
    
    self:UpdateItemsList()
    if addedCount > 0 then
        print(string.format("Added %d consumable presets!", addedCount))
    else
        print("All presets already added!")
    end
end

-- Save variables on logout
local function SaveVariables()
    QuickMailerDB = QM.db
end

local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:SetScript("OnEvent", SaveVariables)
