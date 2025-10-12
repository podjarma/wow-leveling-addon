-- Объявляем глобальные переменные для текущего персонажа
local playerDB, currentLevel, currentLevelStats

-- Функция для обновления ссылок на данные текущего персонажа
local function UpdatePlayerData()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local playerKey = playerName .. "-" .. realmName
    
    LevelStatDB = LevelStatDB or {}
    LevelStatDB[playerKey] = LevelStatDB[playerKey] or {}
    playerDB = LevelStatDB[playerKey]
    
    
    -- Инициализируем обязательные поля
    playerDB.statsByLevel = playerDB.statsByLevel or {}
    playerDB.currentLevel = playerDB.currentLevel or UnitLevel("player")
    playerDB.levelStartTime = playerDB.levelStartTime or GetTime()
    playerDB.framePosition = playerDB.framePosition or {}
    
    currentLevel = playerDB.currentLevel
    
    -- Инициализируем статистику текущего уровня
    if not playerDB.statsByLevel[currentLevel] then
        playerDB.statsByLevel[currentLevel] = {
            levelStartTime = playerDB.levelStartTime,
            timeSpent = 0
        }
    end
    
    currentLevelStats = playerDB.statsByLevel[currentLevel]
    
    -- ОБНОВЛЯЕМ отображение текста
    if levelText then
        levelText:SetText("Уровень: " .. currentLevel)
        timeText:SetText("Время: 00:00:00")
    end
end

-- Вызываем при старте
UpdatePlayerData()

-- Создаем фрейм для отображения времени
local statFrame = CreateFrame("Frame", nil, UIParent)
statFrame:SetSize(200, 60)

-- Восстанавливаем позицию фрейма для текущего персонажа
if playerDB.framePosition.point and playerDB.framePosition.x and playerDB.framePosition.y then
    statFrame:SetPoint(playerDB.framePosition.point, UIParent, 
                      playerDB.framePosition.relativePoint, playerDB.framePosition.x, playerDB.framePosition.y)
else
    statFrame:SetPoint("CENTER", 0, 0)
end

statFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
})
statFrame:SetBackdropColor(0, 0, 0, 0.8)

-- Текст уровня
local levelText = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
levelText:SetPoint("TOPLEFT", 10, -10)
levelText:SetText("Уровень: " .. currentLevel)
levelText:SetJustifyH("LEFT")

-- Текст времени
local timeText = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
timeText:SetPoint("TOPLEFT", levelText, "BOTTOMLEFT", 0, -5)
timeText:SetText("Время: 00:00:00")
timeText:SetJustifyH("LEFT")

-- Функция форматирования времени
local function FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Переменная для хранения времени паузы
local pauseStartTime = nil

-- Функция смены уровня
local function ChangeLevel(newLevel)
    -- Сохраняем итоговое время для текущего уровня
    local currentTime = GetTime()
    if currentLevelStats then
        -- ✅ Сохраняем общее накопленное время
        currentLevelStats.totalTimeSpent = (currentLevelStats.totalTimeSpent or 0) + (currentTime - currentLevelStats.levelStartTime)
        DEFAULT_CHAT_FRAME:AddMessage("LevelTime: Завершен уровень " .. currentLevel .. ", время: " .. FormatTime(currentLevelStats.totalTimeSpent))
    end
    
    -- Переходим на новый уровень
    playerDB.currentLevel = newLevel
    currentLevel = newLevel
    playerDB.levelStartTime = currentTime
    
    -- Инициализируем статистику нового уровня
    if not playerDB.statsByLevel[newLevel] then
        playerDB.statsByLevel[newLevel] = {
            levelStartTime = currentTime,
            totalTimeSpent = 0,  -- ✅ НАКОПЛЕННОЕ время
            timeSpent = 0
        }
        DEFAULT_CHAT_FRAME:AddMessage("LevelTime: Начат новый уровень " .. newLevel)
    else
        -- Если уровень уже был, обновляем время начала
        playerDB.statsByLevel[newLevel].levelStartTime = currentTime
        DEFAULT_CHAT_FRAME:AddMessage("LevelTime: Возврат на уровень " .. newLevel)
    end
    
    currentLevelStats = playerDB.statsByLevel[newLevel]
    UpdateStat()
end


-- Функция обновления статистики
local function UpdateStat()
    if not currentLevelStats then 
        return 
    end
    
    local currentTime = GetTime()
    
    -- ✅ РАСЧЕТ ТОЛЬКО ТЕКУЩЕЙ СЕССИИ
    local currentSessionTime = currentTime - currentLevelStats.levelStartTime
    
    -- ✅ ОБЩЕЕ ВРЕМЯ = накопленное + текущая сессия
    local totalTime = (currentLevelStats.totalTimeSpent or 0) + currentSessionTime
    
    -- Обновляем отображение
    levelText:SetText("Уровень: " .. currentLevel)
    timeText:SetText("Время: " .. FormatTime(totalTime))
end


-- Таймер обновления
local timer = statFrame:CreateAnimationGroup()
timer:SetLooping("REPEAT")
local anim = timer:CreateAnimation()
anim:SetDuration(1)
timer:SetScript("OnLoop", UpdateStat)


-- Функции управления таймером
local function StartTimer()
    if not timer:IsPlaying() then
        timer:Play()
    end
end


local function StopTimer()
    if timer:IsPlaying() then
        timer:Stop()
    end
end


-- Функция сохранения позиции фрейма
local function SaveFramePosition()
    local point, relativeTo, relativePoint, x, y = statFrame:GetPoint()
    playerDB.framePosition = {
        point = point,
        relativeTo = "UIParent",
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end


-- Функция принудительного сохранения данных
local function ForceSaveData()
    -- Сохраняем текущее время
    if currentLevelStats then
        local currentTime = GetTime()
        currentLevelStats.timeSpent = currentTime - currentLevelStats.levelStartTime
    end
end


-- Запускаем таймер при загрузке
StartTimer()


-- Обработка событий
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        ChangeLevel(newLevel)
        ForceSaveData()
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdatePlayerData()
        
        local actualLevel = UnitLevel("player")
        if actualLevel ~= currentLevel then
            ChangeLevel(actualLevel)
        end
        
        StartTimer()
        UpdateStat()
        ForceSaveData()
        
    elseif event == "PLAYER_LEAVING_WORLD" then
        ForceSaveData()
        StopTimer()
        SaveFramePosition()
        
    elseif event == "PLAYER_LOGOUT" then
        ForceSaveData()
        StopTimer()
        SaveFramePosition()
    end
end)


-- Перемещение
statFrame:SetMovable(true)
statFrame:EnableMouse(true)
statFrame:RegisterForDrag("LeftButton")
statFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
statFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveFramePosition()
    ForceSaveData()
end)


-- Команда для принудительного сохранения
SLASH_SAVEDATA1 = "/savedata"
SlashCmdList["SAVEDATA"] = function(msg)
    ForceSaveData()
    DEFAULT_CHAT_FRAME:AddMessage("LevelTime: Данные принудительно сохранены")
end


-- Команда для просмотра истории уровней
SLASH_LEVELHISTORY1 = "/levelhistory"
SlashCmdList["LEVELHISTORY"] = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("=== История уровней для " .. UnitName("player") .. " ===")
    
    if not playerDB.statsByLevel then
        DEFAULT_CHAT_FRAME:AddMessage("Нет данных по уровням")
        return
    end
    
    local levels = {}
    for level, _ in pairs(playerDB.statsByLevel) do
        table.insert(levels, level)
    end
    table.sort(levels)
    
    for _, level in ipairs(levels) do
        local stats = playerDB.statsByLevel[level]
        if stats then
            local timeStr = FormatTime(stats.timeSpent or 0)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("Ур. %d: %s", level, timeStr))
        end
    end
end

-- Команда для просмотра всех персонажей
SLASH_SHOWALLCHARS1 = "/allchars"
SlashCmdList["SHOWALLCHARS"] = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("=== Все персонажи в базе ===")
    for playerKey, data in pairs(LevelStatDB) do
        if type(data) == "table" and data.currentLevel then
            DEFAULT_CHAT_FRAME:AddMessage(playerKey .. " - Ур. " .. data.currentLevel)
        end
    end
end


-- Принудительно показываем и обновляем
statFrame:Show()
UpdateStat()
ForceSaveData()

DEFAULT_CHAT_FRAME:AddMessage("LevelTime Timer загружен для " .. UnitName("player") .. "!")
DEFAULT_CHAT_FRAME:AddMessage("Команды: /levelhistory /savedata /allchars")
