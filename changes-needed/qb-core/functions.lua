-- Replace QBCore.Functions.Notify and QBCore.Functions.Progressbar in qb-core/client/functions.lua

-- [1] Find QBCore.Functions.Notify and replace it with:
function QBCore.Functions.Notify(text, texttype, length, icon)
    if GetResourceState('nova-ui') == 'started' then
        exports['nova-ui']:Notify(text, texttype, length)
        return
    end

    local message = {
        action = 'notify',
        type = texttype or 'primary',
        length = length or 5000,
    }

    if type(text) == 'table' then
        message.text = text.text or 'Placeholder'
        message.caption = text.caption or 'Placeholder'
    else
        message.text = text
    end

    if icon then
        message.icon = icon
    end

    SendNUIMessage(message)
end

-- [2] Find QBCore.Functions.Progressbar and replace it with:
function QBCore.Functions.Progressbar(name, label, duration, useWhileDead, canCancel, disableControls, animation, prop, propTwo, onFinish, onCancel)
    if GetResourceState('nova-ui') == 'started' then
        exports['nova-ui']:Progress({
            label = label,
            duration = duration,
            canCancel = canCancel,
            disableControls = disableControls,
            animation = animation,
        }, onFinish, onCancel)
        return
    end

    if GetResourceState('progressbar') ~= 'started' then error('progressbar needs to be started in order for QBCore.Functions.Progressbar to work') end
    exports['progressbar']:Progress({
        name = name:lower(),
        duration = duration,
        label = label,
        useWhileDead = useWhileDead,
        canCancel = canCancel,
        controlDisables = disableControls,
        animation = animation,
        prop = prop,
        propTwo = propTwo,
    }, function(cancelled)
        if not cancelled then
            if onFinish then
                onFinish()
            end
        else
            if onCancel then
                onCancel()
            end
        end
    end)
end
