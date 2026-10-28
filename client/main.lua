local L = Config.Locales[Config.Locale] or Config.Locales.en
local myPlayerId = PlayerId()

local pendingConfirms = {}
local confirmSeq = 0
local activeProgress = nil
local progressSeq = 0
local documentOpen = false

-- When the document card is open: mouse free for card/dragging, keyboard free for walking;
-- camera/fire/pause locked (to avoid accidental triggering).
local DOCUMENT_DISABLED_CONTROLS = {
    1, 2, 106, -- camera view + vehicle mouse steering
    24, 25, 257, 263,    -- attack / aim / melee
    140, 141, 142,       -- melee combat
    69, 70, 92, 114, -- vehicle weapon
    200, 199, 322,       -- pause / ESC
}

local function nextConfirmId()
    confirmSeq = confirmSeq + 1
    return ('nova-confirm-%s'):format(confirmSeq)
end

local function toneTitle(notifyType)
    return L.toneTitles[notifyType] or L.toneTitles.primary
end

local function normalizeNotify(message, notifyType, duration)
    if type(message) == 'table' then
        local t = message.type or notifyType or 'primary'
        return {
            title = message.title or toneTitle(t),
            message = message.message or message.text or '',
            type = t,
            duration = message.duration or duration or 4500,
        }
    end

    local t = notifyType or 'primary'
    return {
        title = toneTitle(t),
        message = tostring(message or ''),
        type = t,
        duration = duration or 4500,
    }
end

local function Notify(message, notifyType, duration)
    SendNUIMessage({
        action = 'notify',
        data = normalizeNotify(message, notifyType, duration),
    })
end

local function closeDocument()
    if not documentOpen then return end
    documentOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'document:close' })
end

local function ShowDocument(data)
    data = data or {}
    data.badge = data.badge or Config.Brand.badge
    data.kicker = data.kicker or L.documentKicker
    data.title = data.title or L.documentTitle
    data.footer = data.footer or Config.Brand.footer

    documentOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    SendNUIMessage({
        action = 'document',
        data = data,
    })

    -- Shutdown via control lock + ESC/Backspace
    CreateThread(function()
        while documentOpen do
            for i = 1, #DOCUMENT_DISABLED_CONTROLS do
                DisableControlAction(0, DOCUMENT_DISABLED_CONTROLS[i], true)
            end
            if IsDisabledControlJustReleased(0, 322) or IsDisabledControlJustReleased(0, 200)
                or IsControlJustReleased(0, 177) then
                closeDocument()
                break
            end
            Wait(0)
        end
    end)
end

local function Confirm(data, onAccept, onReject)
    data = data or {}

    local id = data.id or nextConfirmId()
    pendingConfirms[id] = {
        accept = onAccept,
        reject = onReject,
    }

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'confirm',
        data = {
            id = id,
            title = data.title or L.confirmTitle,
            message = data.message or '',
            acceptLabel = data.acceptLabel or L.accept,
            rejectLabel = data.rejectLabel or L.reject,
            timeout = data.timeout or 30000,
        },
    })

    return id
end

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000

    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end

    return HasAnimDictLoaded(dict)
end

local function disableProgressControls(disable)
    if type(disable) ~= 'table' then return end

    if disable.disableMovement then
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 36, true)
        DisableControlAction(0, 21, true)
    end

    if disable.disableCarMovement then
        DisableControlAction(0, 63, true)
        DisableControlAction(0, 64, true)
        DisableControlAction(0, 71, true)
        DisableControlAction(0, 72, true)
        DisableControlAction(0, 75, true)
    end

    if disable.disableMouse then
        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)
        DisableControlAction(0, 106, true)
    end

    if disable.disableCombat then
        DisablePlayerFiring(myPlayerId, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 37, true)
        DisableControlAction(0, 47, true)
        DisableControlAction(0, 58, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 143, true)
    end
end

local function playProgressAnimation(animation)
    if type(animation) ~= 'table' then return end

    local ped = PlayerPedId()
    local animDict = animation.animDict or animation.dict
    local anim = animation.anim or animation.name

    if animation.task then
        TaskStartScenarioInPlace(ped, animation.task, 0, true)
        return
    end

    if not animDict or not anim then return end
    if not loadAnimDict(animDict) then return end

    TaskPlayAnim(
        ped,
        animDict,
        anim,
        animation.blendIn or 3.0,
        animation.blendOut or 3.0,
        animation.duration or -1,
        animation.flags or animation.flag or 49,
        animation.playbackRate or 0,
        false,
        false,
        false
    )
end

local function cleanupProgress(cancelled)
    if not activeProgress then return end

    local progress = activeProgress
    activeProgress = nil

    SendNUIMessage({ action = 'progress:stop' })

    if progress.clearTasks ~= false then
        ClearPedTasks(PlayerPedId())
    end

    if cancelled then
        if progress.onCancel then progress.onCancel() end
        return
    end

    if progress.onFinish then progress.onFinish() end
end

local function Progress(data, onFinish, onCancel)
    data = data or {}
    progressSeq = progressSeq + 1

    if activeProgress then
        cleanupProgress(true)
    end

    local duration = data.duration or 5000
    local canCancel = data.canCancel
    if canCancel == nil then canCancel = true end

    activeProgress = {
        id = progressSeq,
        duration = duration,
        startedAt = GetGameTimer(),
        canCancel = canCancel,
        disableControls = data.disableControls or {},
        clearTasks = data.clearTasks,
        onFinish = onFinish or data.onFinish,
        onCancel = onCancel or data.onCancel,
    }

    playProgressAnimation(data.animation or data.anim)

    SendNUIMessage({
        action = 'progress:start',
        data = {
            label = data.label or L.progressLabel,
            duration = duration,
        },
    })

    CreateThread(function()
        local id = activeProgress and activeProgress.id

        while activeProgress and activeProgress.id == id do
            local elapsed = GetGameTimer() - activeProgress.startedAt

            disableProgressControls(activeProgress.disableControls)

            if activeProgress.canCancel and (IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200)) then
                cleanupProgress(true)
                return
            end

            if elapsed >= activeProgress.duration then
                cleanupProgress(false)
                return
            end

            Wait(0)
        end
    end)
end

RegisterNetEvent('nova-ui:client:Notify', function(message, notifyType, duration)
    Notify(message, notifyType, duration)
end)

RegisterNetEvent('nova-ui:client:ShowDocument', function(data)
    ShowDocument(data)
end)

RegisterNUICallback('confirmResult', function(data, cb)
    local id = data and data.id
    local accepted = data and data.accepted
    local pending = id and pendingConfirms[id]

    pendingConfirms[id] = nil
    SetNuiFocus(false, false)

    if pending then
        if accepted and pending.accept then
            pending.accept()
        elseif not accepted and pending.reject then
            pending.reject()
        end
    end

    cb({ ok = true })
end)

RegisterNUICallback('closeFocus', function(_, cb)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

-- Document card X button (from NUI)
RegisterNUICallback('closeDocument', function(_, cb)
    closeDocument()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if documentOpen then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)

-- â”€â”€ TextUI: persistent ipucu (Hotwire / interaction prompt) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Tek satir gosterilir, ayrica gizlenene kadar ekranda kalir. Lua tarafinda
-- 0 frame loop â€” NUI tarafinda CSS ile render edilir.
-- data: { text = '...', position = 'right-center', icon = 'K' }
local function ShowTextUI(data)
    if type(data) == 'string' then data = { text = data } end
    data = data or {}
    SendNUIMessage({
        action = 'textui:show',
        data = {
            text     = tostring(data.text or ''),
            position = data.position or 'right-center',
            icon     = data.icon or '',
        },
    })
end

local function HideTextUI()
    SendNUIMessage({ action = 'textui:hide' })
end

local function CancelProgress()
    if activeProgress then
        cleanupProgress(true)
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Resource durunca takili textUI kalmasin
    HideTextUI()
end)

-- ── Context Menu Management ──────────────────────────────────────────────
local registeredMenus = {}
local menuOpen = false

local function RegisterMenu(data)
    if not data or not data.id then return end
    registeredMenus[data.id] = data
end

local function ShowMenu(id)
    local menu = registeredMenus[id]
    if not menu then return end

    menuOpen = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'menu:show',
        data = {
            id = menu.id,
            title = menu.title,
            options = menu.options,
        }
    })

    -- Lock controls while navigating menu
    CreateThread(function()
        while menuOpen do
            for i = 1, #DOCUMENT_DISABLED_CONTROLS do
                DisableControlAction(0, DOCUMENT_DISABLED_CONTROLS[i], true)
            end
            if IsDisabledControlJustReleased(0, 322) or IsDisabledControlJustReleased(0, 200)
                or IsControlJustReleased(0, 177) then
                menuOpen = false
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'menu:hide' })
                if menu.onClose then menu.onClose() end
                break
            end
            Wait(0)
        end
    end)
end

local function HideMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'menu:hide' })
end

RegisterNUICallback('menuSelectOption', function(data, cb)
    local id = data and data.id
    local index = data and data.index
    local menu = id and registeredMenus[id]

    if menu and menu.options and menu.options[index] then
        local opt = menu.options[index]
        
        -- Reset state, but do not release focus yet. 
        -- If the event or onSelect triggers ShowMenu, menuOpen will be set to true synchronously.
        menuOpen = false
        
        if opt.onSelect then
            opt.onSelect()
        end
        if opt.event then
            if opt.server then
                TriggerServerEvent(opt.event, table.unpack(opt.args or {}))
            else
                TriggerEvent(opt.event, table.unpack(opt.args or {}))
            end
        end
    else
        menuOpen = false
    end

    -- Only release NUI focus if a new menu was NOT opened by the callbacks
    if not menuOpen then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'menu:hide' })
    end

    cb({ ok = true })
end)

RegisterNUICallback('menuCancel', function(data, cb)
    local id = data and data.id
    menuOpen = false
    SetNuiFocus(false, false)

    local menu = id and registeredMenus[id]
    if menu and menu.onClose then
        menu.onClose()
    end
    cb({ ok = true })
end)


-- ── Input Dialog Management (Thread-blocking wait-loop) ──────────────────
local activeInputResult = nil
local isInputActive = false

local function InputDialog(title, fields)
    if isInputActive then return nil end

    isInputActive = true
    activeInputResult = nil

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'input:show',
        data = {
            title = title or L.confirmTitle,
            fields = fields or {},
        }
    })

    -- Block executing thread until input submits/cancels
    while isInputActive do
        for i = 1, #DOCUMENT_DISABLED_CONTROLS do
            DisableControlAction(0, DOCUMENT_DISABLED_CONTROLS[i], true)
        end
        Wait(50)
    end

    return activeInputResult
end

RegisterNUICallback('inputSubmit', function(data, cb)
    activeInputResult = data and data.results
    isInputActive = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNUICallback('inputCancel', function(_, cb)
    activeInputResult = nil
    isInputActive = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)


-- ── Skill Check Management (Thread-blocking wait-loop) ───────────────────
local skillcheckResult = false
local isSkillcheckActive = false

local KEY_CONTROLS = {
    ['E'] = {38, 51}, -- E key (INPUT_PICKUP / INPUT_CONTEXT)
    ['R'] = {45},     -- R key (INPUT_RELOAD)
    ['Q'] = {44},     -- Q key (INPUT_COVER)
    ['F'] = {23},     -- F key (INPUT_ENTER)
    ['G'] = {47},     -- G key (INPUT_DETONATE)
    ['SPACE'] = {22}, -- SPACE key (INPUT_JUMP)
}

local function SkillCheck(difficulty, keys)
    if isSkillcheckActive then return false end

    -- Determine stages (either a single difficulty or a list of stages)
    local stages = {}
    if type(difficulty) == 'table' and (type(difficulty[1]) == 'string' or type(difficulty[1]) == 'table') then
        stages = difficulty
    else
        stages = { difficulty }
    end

    local finalResult = true

    for i = 1, #stages do
        local stageDiff = stages[i]
        
        isSkillcheckActive = true
        skillcheckResult = false

        local speed = 2.5
        local zoneSize = 45

        if type(stageDiff) == 'table' then
            speed = stageDiff.speed or speed
            zoneSize = stageDiff.zoneSize or zoneSize
        elseif stageDiff == 'easy' then
            speed = 2.0
            zoneSize = 50
        elseif stageDiff == 'medium' then
            speed = 3.0
            zoneSize = 35
        elseif stageDiff == 'hard' then
            speed = 4.2
            zoneSize = 20
        end

        local key = 'E'
        if type(keys) == 'table' then
            key = keys[math.random(#keys)]
        elseif type(keys) == 'string' then
            key = keys
        end
        key = key:upper()

        SendNUIMessage({
            action = 'skillcheck:start',
            data = {
                speed = speed,
                zoneSize = zoneSize,
                key = key,
                stage = i,
                total = #stages,
            }
        })

        -- Listen to keypresses on the client side
        local checkThreadActive = true
        CreateThread(function()
            local controls = KEY_CONTROLS[key] or {38, 51}
            
            while isSkillcheckActive and checkThreadActive do
                -- Disable standard combat actions so player doesn't shoot or punch while lockpicking
                DisablePlayerFiring(myPlayerId, true)
                DisableControlAction(0, 24, true) -- Attack
                DisableControlAction(0, 25, true) -- Aim
                DisableControlAction(0, 37, true) -- Weapon Wheel
                DisableControlAction(0, 140, true) -- Melee
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
                DisableControlAction(0, 200, true) -- Pause Menu

                -- Check if any of the mapped controls for the key is pressed
                for _, control in ipairs(controls) do
                    if IsDisabledControlJustPressed(0, control) then
                        SendNUIMessage({ action = 'skillcheck:keyPress' })
                        break
                    end
                end
                
                Wait(0)
            end
        end)

        -- Wait loop (blocks thread until NUI callback resolves result)
        while isSkillcheckActive do
            Wait(30)
        end
        
        checkThreadActive = false -- terminate keypress thread

        -- If this stage failed, terminate whole sequence and return false
        if not skillcheckResult then
            finalResult = false
            break
        end

        -- If there are more stages, wait a short break before starting the next one
        if i < #stages then
            Wait(450)
        end
    end

    return finalResult
end

RegisterNUICallback('skillcheckResult', function(data, cb)
    skillcheckResult = data and data.success
    isSkillcheckActive = false
    cb({ ok = true })
end)


-- No event hijack of QBCore, ESX, ox_lib, or okokNotify.
-- Those resources already draw their own UI. A second listener stacks a second
-- card. Redirects are a few lines the server owner pastes into their own file.
-- See README, Optional integration. This resource ships none of their code.


-- ── Exports ──────────────────────────────────────────────────────────────
exports('Notify', Notify)
exports('ShowDocument', ShowDocument)
exports('Confirm', Confirm)
exports('Progress', Progress)
exports('CancelProgress', CancelProgress)
exports('ShowTextUI', ShowTextUI)
exports('HideTextUI', HideTextUI)

-- New Exports
exports('RegisterMenu', RegisterMenu)
exports('ShowMenu', ShowMenu)
exports('HideMenu', HideMenu)
exports('InputDialog', InputDialog)
exports('SkillCheck', SkillCheck)

-- Force Release Focus Command (Emergency debug command)
RegisterCommand('releasefocus', function()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'document:close' })
    SendNUIMessage({ action = 'menu:hide' })
    SendNUIMessage({ action = 'input:hide' })
    isInputActive = false
    isSkillcheckActive = false
    menuOpen = false
    documentOpen = false
    print("[Nova UI] Emergency NUI focus release triggered.")
end, false)


-- ── Test Commands (only when Config.Debug is true) ───────────────────────
if Config.Debug then
RegisterCommand('testmenu', function()
    -- Register Main Menu
    RegisterMenu({
        id = 'test_menu_cmd',
        title = 'Nova UI Test Menu',
        options = {
            { label = 'Option One', desc = 'This is a description text', icon = '1', event = 'nova-ui:client:testEvent', args = { 'Option 1 Selected' } },
            { label = 'Option Two', desc = 'Another action description', icon = '2', event = 'nova-ui:client:testEvent', args = { 'Option 2 Selected' } },
            { label = 'Submenu Option', desc = 'Indicates submenu navigation', icon = 'S', arrow = true, event = 'nova-ui:client:openSubmenu' }
        }
    })

    -- Register Submenu
    RegisterMenu({
        id = 'test_submenu_cmd',
        title = 'Submenu Option',
        options = {
            { label = 'Sub Option 1', desc = 'Submenu item description', icon = 'A', event = 'nova-ui:client:testEvent', args = { 'Sub option 1 selected' } },
            { label = 'Back', desc = 'Go back to main menu', icon = 'B', event = 'nova-ui:client:openMainMenu' }
        }
    })

    ShowMenu('test_menu_cmd')
end, false)

AddEventHandler('nova-ui:client:openSubmenu', function()
    ShowMenu('test_submenu_cmd')
end)

AddEventHandler('nova-ui:client:openMainMenu', function()
    ShowMenu('test_menu_cmd')
end)

AddEventHandler('nova-ui:client:testEvent', function(msg)
    Notify({
        type = 'success',
        message = tostring(msg),
        duration = 3000
    })
end)

RegisterCommand('testinput', function()
    CreateThread(function()
        local data = InputDialog('Test Input Form', {
            { type = 'text', label = 'Full Name', placeholder = 'Enter name...', required = true },
            { type = 'number', label = 'Age', placeholder = 'Enter age...' },
            { type = 'checkbox', label = 'Terms', description = 'I accept terms and conditions' }
        })
        if data then
            Notify({
                type = 'info',
                title = 'FORM SUBMITTED',
                message = ('Name: %s | Age: %s | Terms: %s'):format(data[1] or 'N/A', data[2] or 'N/A', tostring(data[3])),
                duration = 6000
            })
        else
            Notify({
                type = 'error',
                message = 'Form input cancelled by player',
                duration = 3000
            })
        end
    end)
end, false)

RegisterCommand('testskill', function()
    CreateThread(function()
        Notify({ type = 'primary', message = 'Get ready for Skill Check (3 Stages)...', duration = 2000 })
        Wait(2000)
        
        local success = SkillCheck({'easy', 'medium', 'hard'}, 'E')
        if success then
            Notify({ type = 'success', message = 'You succeeded all lockpick stages!', duration = 3000 })
        else
            Notify({ type = 'error', message = 'You failed the lockpick!', duration = 3000 })
        end
    end)
end, false)
end
