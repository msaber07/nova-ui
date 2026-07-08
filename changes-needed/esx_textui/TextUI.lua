Debug = ESX.GetConfig().EnableDebug
local isShowing = false
local function TextUI(message, typ)
    isShowing = true
    if GetResourceState('nova-ui') == 'started' then
        exports['nova-ui']:ShowTextUI({
            text = message,
            position = 'right-center'
        })
    else
        SendNUIMessage({
            action = "show",
            message = message and message or "ESX-TextUI",
            type = type(typ) == "string" and typ or "info",
        })
    end
end

local function HideUI()
    if not isShowing then
        return
    end
    isShowing = false
    if GetResourceState('nova-ui') == 'started' then
        exports['nova-ui']:HideTextUI()
    else
        SendNUIMessage({
            action = "hide",
        })
    end
end

exports("TextUI", TextUI)
exports("HideUI", HideUI)
ESX.SecureNetEvent("ESX:TextUI", TextUI)
ESX.SecureNetEvent("ESX:HideUI", HideUI)

if Debug then
    RegisterCommand("textui:error", function()
        ESX.TextUI("i ~r~love~s~ donuts", "error")
    end, false)

    RegisterCommand("textui:success", function()
        ESX.TextUI("i ~g~love~s~ donuts", "success")
    end, false)

    RegisterCommand("textui:info", function()
        ESX.TextUI("i ~b~love~s~ donuts", "info")
    end, false)

    RegisterCommand("textui:hide", function()
        ESX.HideUI()
    end, false)
end
