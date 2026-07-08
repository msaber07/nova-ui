-- Replace the entire content of qb-core/client/drawtext.lua with this:

local function hideText()
    if GetResourceState('nova-ui') == 'started' then
        exports['nova-ui']:HideTextUI()
        return
    end

    SendNUIMessage({
        action = 'HIDE_TEXT',
    })
end

local function drawText(text, position)
    if GetResourceState('nova-ui') == 'started' then
        exports['nova-ui']:ShowTextUI({
            text = text,
            position = position == 'left' and 'left-center' or 'right-center'
        })
        return
    end

    if type(position) ~= 'string' then position = 'left' end

    SendNUIMessage({
        action = 'DRAW_TEXT',
        data = {
            text = text,
            position = position
        }
    })
end

local function changeText(text, position)
    if GetResourceState('nova-ui') == 'started' then
        exports['nova-ui']:ShowTextUI({
            text = text,
            position = position == 'left' and 'left-center' or 'right-center'
        })
        return
    end

    if type(position) ~= 'string' then position = 'left' end

    SendNUIMessage({
        action = 'CHANGE_TEXT',
        data = {
            text = text,
            position = position
        }
    })
end

local function keyPressed()
    CreateThread(function()
        SendNUIMessage({
            action = 'KEY_PRESSED',
        })
        Wait(500)
        hideText()
    end)
end

RegisterNetEvent('qb-core:client:DrawText', function(text, position)
    drawText(text, position)
end)

RegisterNetEvent('qb-core:client:ChangeText', function(text, position)
    changeText(text, position)
end)

RegisterNetEvent('qb-core:client:HideText', function()
    hideText()
end)

RegisterNetEvent('qb-core:client:KeyPressed', function()
    keyPressed()
end)

exports('DrawText', drawText)
exports('ChangeText', changeText)
exports('HideText', hideText)
exports('KeyPressed', keyPressed)
