local githubRepo = "msaber07/nova-ui"

Citizen.CreateThread(function()
    -- Read local version.json file
    local localFile = LoadResourceFile(GetCurrentResourceName(), 'version.json')
    if not localFile then return end
    
    local localData = json.decode(localFile)
    if not localData or not localData.version then return end
    local currentVersion = localData.version

    -- Query version file from GitHub
    PerformHttpRequest("https://raw.githubusercontent.com/" .. githubRepo .. "/main/version.json", function(statusCode, responseText, headers)
        if statusCode == 200 and responseText then
            local data = json.decode(responseText)
            if data and data.version then
                if data.version ~= currentVersion then
                    print(("^3An update is available for %s (current version: %s)^7"):format(GetCurrentResourceName(), currentVersion))
                    print(("^5https://github.com/%s/releases/tag/v%s^7"):format(githubRepo, data.version))
                end
            end
        end
    end, "GET", "", "")
end)
