-- Leveling Tracker для WoW 3.3.5
-- Отслеживает статистику прокачки персонажа

-- Глобальные переменные (будут инициализированы в PLAYER_ENTERING_WORLD)
local playerName
local realmName
local playerKey
local playerDB
local currentLevel
local currentLevelStats
local lastXP
local xpBuffer = {}
local lastSystemMessageTime = 0
local sessionStartTime
local isInitialized = false
local oldLevelMaxXP = UnitXPMax("player")
local totalGainedXP = 0
local lastXpGainFlag = 0


-- Создаем фрейм для отображения времени
local statFrame = CreateFrame("Frame", nil, UIParent)
statFrame:SetSize(240, 120)
statFrame:SetPoint("CENTER", 0, 0) -- Временная позиция, будет обновлена при инициализации


statFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
})
statFrame:SetBackdropColor(0, 0, 0, 0.8)


-- Текст уровня
local levelText = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
levelText:SetPoint("TOPLEFT", 10, -10)
levelText:SetText("Уровень: ...")
levelText:SetJustifyH("LEFT")


-- Текст времени
local timeText = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
timeText:SetPoint("TOPLEFT", levelText, "BOTTOMLEFT", 0, -5)
timeText:SetText("Время: 00:00:00")
timeText:SetJustifyH("LEFT")


-- Текст убитых мобов
local mobKillText = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mobKillText:SetPoint("TOPLEFT", timeText, "BOTTOMLEFT", 0, -5)
mobKillText:SetText("Мобов: 0")
mobKillText:SetJustifyH("LEFT")


-- Текст XP за мобов
local mobXpGainText = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mobXpGainText:SetPoint("TOPLEFT", mobKillText, "BOTTOMLEFT", 0, -5)
mobXpGainText:SetText("XP мобы: 0")
mobXpGainText:SetJustifyH("LEFT")


-- Текст выполненных квестов
local questDoneText = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
questDoneText:SetPoint("TOPLEFT", mobXpGainText, "BOTTOMLEFT", 0, -5)
questDoneText:SetText("Квестов: 0")
questDoneText:SetJustifyH("LEFT")


-- Текст XP за выполненные квесты
local questXpGainText = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
questXpGainText:SetPoint("TOPLEFT", questDoneText, "BOTTOMLEFT", 0, -5)
questXpGainText:SetText("XP квесты: 0")
questXpGainText:SetJustifyH("LEFT")


-- Функция инициализации данных из БД
local function InitializeData()
    if isInitialized then
        return
    end
    
    -- Получаем информацию о персонаже (теперь доступна в PLAYER_ENTERING_WORLD)
    playerName = UnitName("player")
    realmName = GetRealmName()
    
    if not playerName or not realmName then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000LevelTime: Ошибка получения имени персонажа или реалма|r")
        return
    end
    
    playerKey = playerName .. "-" .. realmName
    
    -- Инициализация базы данных
    LevelStatDB = LevelStatDB or {}
    LevelStatDB[playerKey] = LevelStatDB[playerKey] or {}
    playerDB = LevelStatDB[playerKey]
    
    -- Инициализация статистики по уровням
    playerDB.statsByLevel = playerDB.statsByLevel or {}
    playerDB.currentLevel = playerDB.currentLevel or UnitLevel("player")
    playerDB.framePosition = playerDB.framePosition or {}
    
    -- Получаем текущий уровень и инициализируем его статистику
    currentLevel = playerDB.currentLevel
    currentLevelStats = playerDB.statsByLevel[currentLevel]
    
    if not currentLevelStats then
        -- Создаем новую запись для уровня
        local levelStartTime = GetTime()
        playerDB.statsByLevel[currentLevel] = {
            levelStartTime = levelStartTime,
            mobKills = 0,
            mobXpGain = 0,
            questDone = 0,
            questXpGain = 0,
            timeSpent = 0,
            lastXP = UnitXP("player"), -- Сохраняем последний XP для отслеживания изменений
            finalStats = nil -- Финальные результаты (будут заполнены при завершении уровня)
        }
        currentLevelStats = playerDB.statsByLevel[currentLevel]
    else
        -- Если уровень уже существует, ВОССТАНАВЛИВАЕМ сохраненные данные
        -- НЕ перезаписываем levelStartTime - используем сохраненное значение!
        -- Если levelStartTime отсутствует (старая версия БД), создаем новое
        if not currentLevelStats.levelStartTime then
            currentLevelStats.levelStartTime = GetTime()
        end
        -- Восстанавливаем lastXP, если он есть, иначе используем текущий
        if not currentLevelStats.lastXP then
            currentLevelStats.lastXP = UnitXP("player")
        end
    end
    
    -- Восстанавливаем сохраненное значение lastXP
    lastXP = currentLevelStats.lastXP or UnitXP("player")
        
    -- Восстанавливаем время начала сессии
    sessionStartTime = GetTime()
    
    -- Восстанавливаем позицию фрейма для текущего персонажа
    if playerDB.framePosition.point and playerDB.framePosition.x and playerDB.framePosition.y then
        statFrame:SetPoint(playerDB.framePosition.point, UIParent, 
                          playerDB.framePosition.relativePoint, playerDB.framePosition.x, playerDB.framePosition.y)
    else
        statFrame:SetPoint("CENTER", 0, 0)
    end
    
    -- Убеждаемся, что фрейм виден
    statFrame:Show()
    
    isInitialized = true
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00LevelTime: Данные загружены из БД для " .. playerKey .. "|r")
    
    -- Обновляем отображение сразу после инициализации
    UpdateStat()
end


-- Функция форматирования времени
local function FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end


-- Функция смены уровня
local function ChangeLevel(newLevel)
    if not isInitialized then
        return
    end
    
    -- Сначала обрабатываем последний опыт, который привел к повышению уровня
    local currentXP = UnitXP("player")
    local lastGainedXP = currentXP - lastXP
    
    if lastGainedXP > 0 then
        local currentTime = GetTime()
        
        -- Проверяем, было ли недавно системное сообщение о квесте
        if currentTime - lastSystemMessageTime < 2 then
            -- Это опыт от квеста
            currentLevelStats.questDone = (currentLevelStats.questDone or 0) + 1
            currentLevelStats.questXpGain = (currentLevelStats.questXpGain or 0) + lastGainedXP
        else
            -- Это опыт от моба
            currentLevelStats.mobXpGain = (currentLevelStats.mobXpGain or 0) + lastGainedXP
            currentLevelStats.mobKills = (currentLevelStats.mobKills or 0) + 1
        end
        
        -- Сохраняем изменения
        ForceSaveData()
    end
    
    -- Теперь вычисляем общий полученный опыт на текущем уровне (уже с последним опытом)
    local totalGainedXP = (currentLevelStats.mobXpGain or 0) + (currentLevelStats.questXpGain or 0)
    local oldLevelMaxXP = UnitXPMax("player") -- Получаем maxXP ДО повышения уровня
    
    -- Вычисляем избыточный опыт
    local excessXP = 0
    if totalGainedXP > oldLevelMaxXP then
        excessXP = totalGainedXP - oldLevelMaxXP
    end
    
    -- Сохраняем итоговое время для текущего уровня
    local currentTime = GetTime()
    if currentLevelStats then
        -- Обновляем timeSpent: сохраняем накопленное + время текущей сессии
        local sessionTime = currentTime - sessionStartTime
        local savedTimeSpent = currentLevelStats.timeSpent or 0
        currentLevelStats.timeSpent = savedTimeSpent + sessionTime
        
        -- Сохраняем финальные результаты для завершенного уровня
        currentLevelStats.finalStats = {
            level = currentLevel,
            totalTime = currentLevelStats.timeSpent,
            mobKills = currentLevelStats.mobKills or 0,
            mobXpGain = currentLevelStats.mobXpGain or 0,
            questDone = currentLevelStats.questDone or 0,
            questXpGain = currentLevelStats.questXpGain or 0,
            totalXP = totalGainedXP,
            maxXP = oldLevelMaxXP,
            excessXP = excessXP,
            timestamp = currentTime,
            completed = true
        }
    end
    
    -- Переходим на новый уровень
    playerDB.currentLevel = newLevel
    currentLevel = newLevel
    
    -- Сбрасываем время начала сессии для нового уровня
    sessionStartTime = currentTime
    
    -- Получаем maxXP для нового уровня
    local newLevelMaxXP = UnitXPMax("player")
    
    -- Инициализируем статистику нового уровня
    if not playerDB.statsByLevel[newLevel] then
        playerDB.statsByLevel[newLevel] = {
            mobKills = 0,
            mobXpGain = 0,
            questDone = 0,
            questXpGain = 0,
            timeSpent = 0,
            lastXP = 0,  -- Начинаем с 0 на новом уровне
            maxXP = newLevelMaxXP
        }
    else
        -- Если уровень уже был, восстанавливаем его данные
        if not playerDB.statsByLevel[newLevel].timeSpent then
            playerDB.statsByLevel[newLevel].timeSpent = 0
        end
        if not playerDB.statsByLevel[newLevel].lastXP then
            playerDB.statsByLevel[newLevel].lastXP = 0
        end
        if not playerDB.statsByLevel[newLevel].maxXP then
            playerDB.statsByLevel[newLevel].maxXP = newLevelMaxXP
        end
    end
    
    currentLevelStats = playerDB.statsByLevel[newLevel]
    
    -- Если есть избыточный опыт, добавляем его к новому уровню
    if excessXP > 0 then
        if lastXpGainFlag then
            currentLevelStats.mobXpGain = (currentLevelStats.mobXpGain or 0) + excessXP
        elseif not lastXpGainFlag then
            currentLevelStats.questXpGain = (currentLevelStats.questXpGain or 0) + excessXP
        end 
    end
    
    -- Устанавливаем начальный опыт для нового уровня
    lastXP = 0
    currentLevelStats.lastXP = 0
    
    lastSystemMessageTime = 0 -- Сбрасываем временную метку
    UpdateStat()
    ForceSaveData() -- Сохраняем изменения
end


-- Функция обновления статистики
local function UpdateStat()
    -- Показываем начальные значения, даже если данные еще не инициализированы
    if not isInitialized or not currentLevelStats or not currentLevel then
        if levelText then
            levelText:SetText("Уровень: ...")
        end
        if timeText then
            timeText:SetText("Время: 00:00:00")
        end
        if mobKillText then
            mobKillText:SetText("Мобов: 0")
        end
        if mobXpGainText then
            mobXpGainText:SetText("XP мобы: 0")
        end
        if questDoneText then
            questDoneText:SetText("Квестов: 0")
        end
        if questXpGainText then
            questXpGainText:SetText("XP квесты: 0")
        end
        return 
    end
    
    -- Вычисляем время: сохраненное время + время текущей сессии
    local currentTime = GetTime()
    local sessionTime = currentTime - (sessionStartTime or currentTime)
    local savedTimeSpent = currentLevelStats.timeSpent or 0
    local totalTimeSpent = savedTimeSpent + sessionTime
    
    -- Обновляем отображение
    if levelText then
        levelText:SetText("Уровень: " .. currentLevel)
    end
    if timeText then
        timeText:SetText("Время: " .. FormatTime(totalTimeSpent))
    end
    if mobKillText then
        mobKillText:SetText("Мобов: " .. (currentLevelStats.mobKills or 0))
    end
    if mobXpGainText then
        mobXpGainText:SetText("XP мобы: " .. (currentLevelStats.mobXpGain or 0))
    end
    if questDoneText then
        questDoneText:SetText("Квестов: " .. (currentLevelStats.questDone or 0))
    end
    if questXpGainText then
        questXpGainText:SetText("XP квесты: " .. (currentLevelStats.questXpGain or 0))
    end
end

-- Таймер обновления (исправленная версия)
local lastUpdate = 0
statFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate >= 1 then
        UpdateStat()
        lastUpdate = 0
    end
end)


-- Функции управления таймером (для совместимости оставляем пустые функции)
local function StartTimer()
    -- Не нужно ничего делать, так как OnUpdate работает автоматически
end


local function StopTimer()
    -- Не нужно ничего делать, так как OnUpdate работает автоматически
end


-- === СОХРАНЕНИЕ ПОЗИЦИИ ===
local function SaveFramePosition()
    if not isInitialized or not playerDB then
        return
    end
    
    local point, _, relativePoint, x, y = statFrame:GetPoint()
    playerDB.framePosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end


-- Функция принудительного сохранения данных
local function ForceSaveData()
    if not isInitialized then
        return
    end
    
    -- Сохраняем текущее время
    if currentLevelStats then
        local currentTime = GetTime()
        -- Обновляем timeSpent: сохраняем накопленное + время текущей сессии
        local sessionTime = currentTime - sessionStartTime
        local savedTimeSpent = currentLevelStats.timeSpent or 0
        currentLevelStats.timeSpent = savedTimeSpent + sessionTime
        
        -- Обновляем время начала сессии, так как мы сохранили накопленное время
        sessionStartTime = currentTime
        
        currentLevelStats.lastXP = lastXP
        
        -- Сохраняем финальные результаты для текущего уровня
        currentLevelStats.finalStats = {
            level = currentLevel,
            totalTime = currentLevelStats.timeSpent,
            mobKills = currentLevelStats.mobKills or 0,
            mobXpGain = currentLevelStats.mobXpGain or 0,
            questDone = currentLevelStats.questDone or 0,
            questXpGain = currentLevelStats.questXpGain or 0,
            totalXP = (currentLevelStats.mobXpGain or 0) + (currentLevelStats.questXpGain or 0),
            timestamp = currentTime
        }
    end
    
    -- Сохраняем позицию фрейма
    SaveFramePosition()
end


-- Функция обработки опыта за мобов
local function ProcessMobXP(gainedXP)
    if not isInitialized or gainedXP <= 0 or not currentLevelStats then
        return
    end
    
    lastXpGainFlag = true
    currentLevelStats.mobXpGain = (currentLevelStats.mobXpGain or 0) + gainedXP
    currentLevelStats.mobKills = (currentLevelStats.mobKills or 0) + 1
    UpdateStat()
    ForceSaveData()
end


-- Функция обработки опыта за квесты
local function ProcessQuestXP(gainedXP)
    if not isInitialized or gainedXP <= 0 or not currentLevelStats then
        return
    end
    
    lastXpGainFlag = false
    currentLevelStats.questDone = (currentLevelStats.questDone or 0) + 1
    currentLevelStats.questXpGain = (currentLevelStats.questXpGain or 0) + gainedXP
    UpdateStat()
    ForceSaveData()
end


-- Обработка событий
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")


eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LEVEL_UP" then
        if not isInitialized then
            return
        end
        local newLevel = ...
        ChangeLevel(newLevel)
        ForceSaveData()
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Инициализируем данные из БД при входе в мир
        InitializeData()

        oldLevelMaxXP = UnitXPMax("player")
        
        if not isInitialized then
            return
        end
        
        local actualLevel = UnitLevel("player")
        if actualLevel ~= currentLevel then
            ChangeLevel(actualLevel)
        else
            -- Уровень тот же - восстанавливаем сохраненные данные
            if currentLevelStats and currentLevelStats.lastXP then
                lastXP = currentLevelStats.lastXP
            else
                lastXP = UnitXP("player")
                if currentLevelStats then
                    currentLevelStats.lastXP = lastXP
                end
            end
            -- Обновляем время начала сессии (чтобы правильно считать время)
            sessionStartTime = GetTime()
        end
        StartTimer()
        UpdateStat()
        ForceSaveData()

    elseif event == "PLAYER_LEAVING_WORLD" then
        if not isInitialized then
            return
        end
        StopTimer()
        ForceSaveData() -- Сохраняем данные перед выходом
        
    elseif event == "PLAYER_LOGOUT" then
        if not isInitialized then
            return
        end
        StopTimer()
        ForceSaveData() -- Сохраняем данные перед выходом
        
    elseif event == "PLAYER_XP_UPDATE" then
        if not isInitialized then
            return
        end
        
        local currentXP = UnitXP("player")
        local gainedXP = currentXP - lastXP
        
        -- Обрабатываем только положительный прирост опыта и только если не превышен лимит уровня
        if gainedXP > 0 then
            local currentTime = GetTime()
            
            -- Проверяем, было ли недавно системное сообщение о квесте
            if currentTime - lastSystemMessageTime < 2 then -- В течение 2 секунд
                -- Это опыт от квеста
                ProcessQuestXP(gainedXP)
            else
                -- Это опыт от моба
                ProcessMobXP(gainedXP)
            end
        end
        
        lastXP = currentXP
        
    elseif event == "CHAT_MSG_SYSTEM" then
        if not isInitialized then
            return
        end
        
        local message = select(1, ...)
        
        -- Обработка системных сообщений об опыте за квесты
        if string.find(message, "Опыт выполнения задания:") or 
           string.find(message, "Получено опыта:") or
           string.find(message, "Получено:") or
           string.find(message, "Experience gained:") then
            
            -- Устанавливаем временную метку для следующего XP_UPDATE
            lastSystemMessageTime = GetTime()
        end
        
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not isInitialized then
            return
        end
        -- Дополнительная проверка через combat log для более точного отслеживания мобов
        local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, 
              destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
        
        if subevent == "PARTY_KILL" and sourceGUID == UnitGUID("player") then
            -- Игрок убил моба
            if currentLevelStats then
                currentLevelStats.mobKills = (currentLevelStats.mobKills or 0) + 1
                UpdateStat()
                ForceSaveData()
            end
        end
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

local closeButton = CreateFrame("Button", nil, statFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", statFrame, "TOPRIGHT", -5, -5)
closeButton:SetSize(32, 32)
closeButton:SetScript("OnClick", function()
    statFrame:Hide()
end)

-- Добавляем команды для управления
SLASH_LEVELTIME1 = "/lt"
SLASH_LEVELTIME2 = "/leveltime"
SlashCmdList["LEVELTIME"] = function(msg)
    if msg == "reset" then
        if not isInitialized or not playerKey then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000LevelTime: Аддон еще не инициализирован. Подождите входа в мир.|r")
            return
        end
        LevelStatDB[playerKey] = nil
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000LevelTime: Данные сброшены!|r")
        ReloadUI()
    elseif msg == "debug" then
        if not isInitialized then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000LevelTime: Аддон еще не инициализирован. Подождите входа в мир.|r")
            return
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== LevelTime Debug ===|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Текущий XP:|r " .. UnitXP("player"))
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Последний XP:|r " .. lastXP)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Уровень:|r " .. currentLevel)
        if currentLevelStats then
            local currentTime = GetTime()
            local sessionTime = currentTime - sessionStartTime
            local savedTimeSpent = currentLevelStats.timeSpent or 0
            local totalTimeSpent = savedTimeSpent + sessionTime
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Сохраненное время:|r " .. FormatTime(savedTimeSpent))
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Время сессии:|r " .. FormatTime(sessionTime))
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Общее время:|r " .. FormatTime(totalTimeSpent))
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Мобов:|r " .. currentLevelStats.mobKills)
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Квестов:|r " .. currentLevelStats.questDone)
        end
    elseif msg == "testquest" then
        if not isInitialized then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000LevelTime: Аддон еще не инициализирован. Подождите входа в мир.|r")
            return
        end
        -- Тестовая команда для проверки квестов
        if currentLevelStats then
            currentLevelStats.questDone = (currentLevelStats.questDone or 0) + 1
            currentLevelStats.questXpGain = (currentLevelStats.questXpGain or 0) + 1000
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00LevelTime: ТЕСТ - Добавлен квест!|r")
            UpdateStat()
        end
    elseif msg == "history" then
        if not isInitialized or not playerDB then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000LevelTime: Аддон еще не инициализирован. Подождите входа в мир.|r")
            return
        end
        -- Показываем историю всех завершенных уровней
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== LevelTime История уровней ===|r")
        
        local totalTime = 0
        local totalMobs = 0
        local totalMobXP = 0
        local totalQuests = 0
        local totalQuestXP = 0
        
        for level, data in pairs(playerDB.statsByLevel) do
            if data.finalStats and data.finalStats.completed then
                local stats = data.finalStats
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Уровень " .. stats.level .. ":|r")
                DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFF00Время:|r " .. FormatTime(stats.totalTime))
                DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFF00Мобов:|r " .. stats.mobKills .. " (XP: " .. stats.mobXpGain .. ")")
                DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFF00Квестов:|r " .. stats.questDone .. " (XP: " .. stats.questXpGain .. ")")
                DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFF00Всего XP:|r " .. stats.totalXP)
                
                totalTime = totalTime + stats.totalTime
                totalMobs = totalMobs + stats.mobKills
                totalMobXP = totalMobXP + stats.mobXpGain
                totalQuests = totalQuests + stats.questDone
                totalQuestXP = totalQuestXP + stats.questXpGain
            end
        end
        
        if totalTime > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== Общая статистика ===|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Всего времени:|r " .. FormatTime(totalTime))
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Всего мобов:|r " .. totalMobs .. " (XP: " .. totalMobXP .. ")")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Всего квестов:|r " .. totalQuests .. " (XP: " .. totalQuestXP .. ")")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Всего XP:|r " .. (totalMobXP + totalQuestXP))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Нет завершенных уровней для отображения|r")
        end
        if currentLevelStats then
            local currentTime = GetTime()
            local sessionTime = currentTime - sessionStartTime
            local savedTimeSpent = currentLevelStats.timeSpent or 0
            local totalTimeSpent = savedTimeSpent + sessionTime
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== LevelTime Статистика уровня " .. currentLevel .. " ===|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Время:|r " .. FormatTime(totalTimeSpent))
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Мобов:|r " .. (currentLevelStats.mobKills or 0))
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Опыт с мобов:|r " .. (currentLevelStats.mobXpGain or 0))
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Квестов:|r " .. (currentLevelStats.questDone or 0))
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Опыт с квестов:|r " .. (currentLevelStats.questXpGain or 0))
        end
    elseif msg == "brd" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00LevelTime: Максимальный опыт для текущего уровня|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00LevelTime: Убеждаемся, что UnitXPMax вообще работает: " .. oldLevelMaxXP .. "|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00LevelTime: xpTotal: " .. totalGainedXP .. "|r")
    elseif msg == "show" or msg == "hide" or msg == "" then
        -- Команда для показа/скрытия интерфейса
        if statFrame:IsShown() then
            statFrame:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00LevelTime: Интерфейс скрыт. Используйте /lt show для показа.|r")
        else
            statFrame:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00LevelTime: Интерфейс показан.|r")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00LevelTime Commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00/lt stats|r - показать статистику текущего уровня")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00/lt history|r - показать историю всех уровней")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00/lt debug|r - отладочная информация")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00/lt testquest|r - тест квестов")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00/lt reset|r - сбросить данные")
    end
end

-- Показываем фрейм и обновляем текст (данные будут загружены в PLAYER_ENTERING_WORLD)
statFrame:Show()
UpdateStat() -- Обновляем текст, чтобы он был виден сразу

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00LevelTime аддон загружен! Используйте /lt для управления.|r")
