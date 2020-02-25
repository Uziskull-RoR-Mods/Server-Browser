local json = require("json")

-- yeah giant dick move here, idk why
local http = require("http/http")

local config = {
    {key = "port",      value = "11100"},
    {key = "players",   value = "4"}
}
for i = 1, 2 do
    local v = save.read(config[i].key)
    if v ~= nil then config[i].value = v end
end

local dataFields = {"ip", "port", "playercount", "maxplayers", "date"}

local gui = Sprite.load("browser_gui", "gui", 1, 0, 0)
local hostGui = Sprite.load("host_gui", "popup", 1, 0, 0)
local modsStart = Sprite.load("browser_gui_modsStart", "modsStart", 1, 0, 0)
local modsStep = Sprite.load("browser_gui_modsStep", "modsStep", 1, 0, 0)
local modsEnd = Sprite.load("browser_gui_modsEnd", "modsEnd", 1, 0, 0)
local colors = {
    light = Color.fromHex(0x8eaeb0),
    medium = Color.fromHex(0x6a7d84),
    dark = Color.fromHex(0x535c6f)
}

local server = "https://ror-server-list.000webhostapp.com/server.php"

local modVersion = modloader.getModVersion("serverBrowser")

local amHost = false

--=== useful function that saturn should include in rorml but he won't because he sucks ===--
function drawOutlineText(text, x, y, colorText, colorOutline, font, halign, valign)
    colorText = colorText or Color.WHITE
    colorOutline = colorOutline or Color.DARK_GREY
    local currColor = graphics.getColor()
    
    graphics.color(colorOutline)
    for i = -1, 1 do
        for j = -1, 1 do
            if i ~= 0 or j ~= 0 then graphics.print(text, x + i, y + j, font, halign, valign) end
        end
    end
    
    graphics.color(colorText)
    graphics.print(text, x, y, font, halign, valign)

    graphics.color(currColor)
end

-- keylog
local keylog = 0
registercallback("globalStep", function(room)
    if keylog == 0 or room:getOrigin() ~= "Vanilla" then return end
    if room:getName() == "Host" then
        -- big brain move right here
        for i = 0, 9 do
            if not (i == 0 and config[keylog].value == "") then
                if (input.checkKeyboard(tostring(i)) == input.PRESSED or input.checkKeyboard("numpad" .. i) == input.PRESSED)
                  and (keylog == 1 and config[keylog].value:len() < 8 or keylog == 2 and config[keylog].value:len() < 2) then
                    config[keylog].value = config[keylog].value .. i
                    break
                end
            end
        end
        if input.checkKeyboard("backspace") == input.PRESSED and config[keylog].value ~= "" then
            config[keylog].value = string.sub(config[keylog].value, 1, -2)
        end
    end
end)
local function enableKeylog(field)
    keylog = field
    -- special case for whatever reason
    if keylog == 1 and config[keylog].value == "0" then
        config[keylog].value = ""
    end
end
local function disableKeylog()
    local index = keylog
    keylog = 0
    return index
end

function lobbyUI(inst, frames)
    local instData = inst:getData()
    local mouseX, mouseY = input.getMousePos()
    local hudW, hudH = graphics.getGameResolution()
    if frames == 1 or instData.prevHudW ~= nil and instData.prevHudW ~= hudW then
        inst.x, inst.y = hudW / 2 - gui.width / 2, hudH / 2
        instData.heldX, instData.heldY = nil, nil
    end
    if instData.heldX ~= nil and instData.heldY ~= nil then
        inst.x, inst.y = mouseX - instData.heldX, mouseY - instData.heldY
    end
    
    local x1, y1, x2, y2 = inst.x + 23*16 + 10, inst.y + 16, inst.x + 29*16 + 6, inst.y + 2*16
    
    -- draw
    gui:draw(inst.x, inst.y)
    drawOutlineText("Server Browser", inst.x + 2*16, inst.y + 16, nil, nil, graphics.FONT_LARGE, nil, graphics.ALIGN_TOP)
    if mouseX >= x1 and mouseX <= x2 and mouseY >= y1 and mouseY <= y2
      and (input.checkMouse("left") == input.PRESSED or input.checkMouse("left") == input.HELD) then
        local ct = {colors.medium, colors.light, colors.dark, Color.DARK_GREY, Color.GRAY}
        
        graphics.color(ct[1])
        graphics.rectangle(
            x1,
            y1,
            (x2 - 1) - 1,
            y2 - 1
        )
        graphics.color(ct[2])
        graphics.rectangle(
            (x1) + 1,
            (y1) + 1,
            x2 - 1,
            y2 - 1
        )
        graphics.pixel(
            x2 - 1,
            y1
        )
        graphics.color(ct[3])
        graphics.rectangle(
            (x1) + 1,
            (y1) + 1,
            (x2 - 1) - 1,
            (y2 - 1) - 1
        )
        drawOutlineText("Refresh", inst.x + 26*16 + 8, inst.y + 16 + 8, ct[4], ct[5], nil, graphics.ALIGN_MIDDLE, graphics.ALIGN_CENTER)
    else
        drawOutlineText("Refresh", inst.x + 26*16 + 8, inst.y + 16 + 8, nil, nil, nil, graphics.ALIGN_MIDDLE, graphics.ALIGN_CENTER)
    end
    
    local xx, yy = 5*16 + 8, 3*16 + 8
    for i, text in ipairs({"Server IP", "Server Port", "Players", "Last Updated"}) do
        drawOutlineText(text, inst.x + xx, inst.y + yy, nil, nil, nil, graphics.ALIGN_MIDDLE, graphics.ALIGN_CENTER)
        xx = xx + 7*16
    end
    
    -- refresh
    if frames == 1 or mouseX >= x1 and mouseX <= x2 and mouseY >= y1 and mouseY <= y2 and input.checkMouse("left") == input.PRESSED then
        local response, info = http.request(server)
        if info ~= 200 then
            instData.error = response
            instData.response = nil
        else
            instData.error = nil
            instData.response = json.decode(response)
            for _, server in ipairs(instData.response) do
                server.mods = server.mods ~= nil and json.decode(server.mods) or {"No mods (Vanilla)"}
            end
        end
    -- move stuff around
    elseif mouseX >= inst.x and mouseX <= inst.x + gui.width
      and mouseY >= inst.y and mouseY <= inst.y + 40 then
        if input.checkMouse("left") == input.PRESSED then
            instData.heldX, instData.heldY = mouseX - inst.x, mouseY - inst.y
        elseif input.checkMouse("left") == input.RELEASED or input.checkMouse("left") == input.NEUTRAL then
            instData.heldX, instData.heldY = nil, nil
        end
    end
    
    graphics.color(Color.WHITE)
    if instData.error then
        graphics.print("Error getting servers: " .. instData.error, inst.x + 16*16, inst.y + 6*16 + 8)
    elseif #instData.response == 0 then
        drawOutlineText("No servers available :(", inst.x + 16*16, inst.y + 6*16 + 8, nil, nil, nil, graphics.ALIGN_MIDDLE, graphics.ALIGN_CENTER)
    else
        yy = 5*16 + 8
        for _, server in ipairs(instData.response) do
            xx = 3*16
            x1, y1, x2, y2 = inst.x + xx - 16, inst.y + yy - 8, inst.x + xx - 16 + 28*16 - 1, inst.y + yy - 8 + 16 - 1
            for _, data in ipairs(dataFields) do
                if data ~= "maxplayers" then
                    local text = server[data]
                    if data == "playercount" then
                        text = text .. "/" .. server.maxplayers
                    end
                    drawOutlineText(text, inst.x + xx, inst.y + yy, nil, nil, nil, nil, graphics.ALIGN_CENTER)
                    xx = xx + 7*16
                end
            end
            if mouseX >= x1 and mouseX <= x2 and mouseY >= y1 and mouseY <= y2 then
                graphics.color(Color.WHITE)
                graphics.alpha(0.3)
                graphics.rectangle(x1, y1, x2, y2)
                graphics.alpha(1)
                
                -- mods
                dy = modsEnd.height + modsStep.height * #server.mods + modsStart.height
                modsStart:draw(mouseX, mouseY - dy)
                drawOutlineText("Server Mods:", mouseX + 10, mouseY - dy + 7)
                dy = dy - modsStart.height
                graphics.color(Color.BLACK)
                for _, modName in ipairs(server.mods) do
                    modsStep:draw(mouseX, mouseY - dy)
                    graphics.print(modName, mouseX + 10, mouseY - dy + 2)
                    dy = dy - modsStep.height
                end
                modsEnd:draw(mouseX, mouseY - dy)
            end
            yy = yy + 16
        end
    end
    
    -- keylog
    local checked = 0
    x1, x2 = hudW / 2 - 150 + 1, hudW / 2 + 150 - 1
    for i = 1, 2 do
        dy = i == 1 and 115 or 130
        y1, y2 = hudH / 10 + dy - 8 + 1, hudH / 10 + dy + 8 - 1 - 1
        if (input.checkMouse("left") == input.PRESSED or input.checkKeyboard("enter") == input.PRESSED) and checked == 0 then
            local index = disableKeylog()
            checked = index > 0 and index or 3
            if index ~= 0 then
                local value = config[index].value == "" and 0 or tonumber(config[index].value)
                if index == 1 then
                    config[index].value = tostring(math.clamp(value, 0, 99999999))
                else
                    config[index].value = tostring(math.clamp(value, 1, 32))
                end
            end
        end
        if checked ~= i and mouseY >= y1 and mouseY <= y2 and mouseX >= x1 and mouseX <= x2 and input.checkMouse("left") == input.PRESSED then
            enableKeylog(i)
        end
        -- debug
        graphics.print(config[i].key .. ": " .. config[i].value, 5, 8*i)
    end
    -- -- debug
    -- graphics.print("keylog: " .. keylog, 5, 24)
    
    instData.prevHudW = hudW
    
    y1, y2 = hudH / 10 + 80 - 14 + 1, hudH / 10 + 80 + 14 - 1 - 1
    amHost = mouseY >= y1 and mouseY <= y2 and mouseX >= x1 and mouseX <= x2
end

function hostUI(inst, frames)
    -- no need to submit server if it only allows one person in
    if not amHost or config[2].value == "1" then
        inst:destroy()
        return
    end
    local instData = inst:getData()
    local mouseX, mouseY = input.getMousePos()
    local hudW, hudH = graphics.getGameResolution()
    if frames == 1 then
        instData.toggle = false
        instData.currentPlayers = 1
    end
    if frames == 1 or instData.prevHudW ~= nil and instData.prevHudW ~= hudW then
        local spr = Sprite.find("SelectMult")
        inst.x, inst.y = hudW / 2 - spr.xorigin - hostGui.width / 2, hudH / 2 - spr.yorigin - hostGui.height
        instData.heldX, instData.heldY = nil, nil
    end
    if instData.heldX ~= nil and instData.heldY ~= nil then
        inst.x, inst.y = mouseX - instData.heldX, mouseY - instData.heldY
    end
    
    -- draw
    hostGui:draw(inst.x, inst.y)
    
    local xx, yy = 10, 19
    drawOutlineText("Post server online?", inst.x + xx, inst.y + yy)
    yy = yy + 12
    for i = 1, 2 do
        local text = i == 1 and "Port: " or "Max Players: "
        graphics.color(Color.GREY)
        graphics.print(
            text,
            inst.x + xx,
            inst.y + yy
        )
        graphics.color(Color.WHITE)
        graphics.print(
            config[i].value,
            inst.x + xx + graphics.textWidth(text, graphics.FONT_DEFAULT),
            inst.y + yy
        )
        yy = yy + 10
    end
    
    xx, yy = hostGui.width / 2, yy + 12
    if not instData.error then
        local ct = {colors.light, colors.dark, colors.medium, Color.WHITE, Color.DARK_GREY}
        if mouseX >= inst.x + xx - 92 / 2 and mouseY >= inst.y + yy
          and mouseX <= inst.x + xx + 92 / 2 - 1 and mouseY <= inst.y + yy + 16 - 1
          and input.checkMouse("left") == input.PRESSED and not instData.toggle then
            ct = {colors.medium, colors.light, colors.dark, Color.DARK_GREY, Color.GRAY}
        end
        
        graphics.color(ct[1])
        graphics.rectangle(
            inst.x + xx - 92 / 2,
            inst.y + yy,
            (inst.x + xx + 92 / 2 - 1) - 1,
            inst.y + yy + 16 - 1
        )
        graphics.color(ct[2])
        graphics.rectangle(
            (inst.x + xx - 92 / 2) + 1,
            (inst.y + yy) + 1,
            inst.x + xx + 92 / 2 - 1,
            inst.y + yy + 16 - 1
        )
        graphics.pixel(
            inst.x + xx + 92 / 2 - 1,
            inst.y + yy
        )
        graphics.color(ct[3])
        graphics.rectangle(
            (inst.x + xx - 92 / 2) + 1,
            (inst.y + yy) + 1,
            (inst.x + xx + 92 / 2 - 1) - 1,
            (inst.y + yy + 16 - 1) - 1
        )
        drawOutlineText(
            "Submit",
            inst.x + xx + 3, inst.y + yy + 9,
            ct[4], ct[5],
            nil, graphics.ALIGN_MIDDLE, graphics.ALIGN_CENTER
        )
        if instData.toggle then
            graphics.color(Color.fromHex(0x1e1111))
            graphics.alpha(0.5)
            graphics.rectangle(
                inst.x + xx - 92 / 2,
                inst.y + yy,
                inst.x + xx + 92 / 2 - 1,
                inst.y + yy + 16 - 1
            )
            graphics.alpha(1)
        end
    else
        graphics.color(Color.ROR_RED)
        graphics.print(
            "Error submitting server:",
            inst.x + xx + 2, inst.y + yy,
            nil, graphics.ALIGN_MIDDLE, graphics.ALIGN_CENTER
        )
        for i, errMsg in ipairs(instData.error) do
            graphics.print(
                errMsg,
                inst.x + xx + 2, inst.y + yy + 10 * i,
                nil, graphics.ALIGN_MIDDLE, graphics.ALIGN_CENTER
            )
        end
    end
    
    -- update
    local numPlayers = #Object.find("PrePlayer"):findAll()
    if instData.toggle and numPlayers ~= instData.currentPlayers then
        instData.currentPlayers = numPlayers
        local response, info = http.request(
            server,
            json.encode({
                action = "update",
                version = modVersion,
                
                playerCount = instData.currentPlayers,
                date = os.date("!%d/%m/%y %H:%M")
            })
        )
    end
    
    -- close
    if mouseX >= inst.x + 134 and mouseX <= inst.x + 134 + 10 - 1 and mouseY >= inst.y + 3 and mouseY <= inst.y + 3 + 10
      and input.checkMouse("left") == input.PRESSED then
        inst:destroy()
        return
    -- move stuff around
    elseif mouseX >= inst.x and mouseX <= inst.x + hostGui.width
      and mouseY >= inst.y and mouseY <= inst.y + 14 then
        if input.checkMouse("left") == input.PRESSED then
            instData.heldX, instData.heldY = mouseX - inst.x, mouseY - inst.y
        elseif input.checkMouse("left") == input.RELEASED or input.checkMouse("left") == input.NEUTRAL then
            instData.heldX, instData.heldY = nil, nil
        end
    end
    -- submit
    if not instData.toggle and not instData.error
      and mouseX >= inst.x + xx - 92 / 2 and mouseY >= inst.y + yy
      and mouseX <= inst.x + xx + 92 / 2 - 1 and mouseY <= inst.y + yy + 16 - 1
      and input.checkMouse("left") == input.PRESSED then
        -- get mod list
        local modList = modloader.getMods()
        -- remove server browser from list
        for i = 1, #modList do
            if modList[i] == "serverBrowser" then
                table.remove(modList, i)
                break
            end
        end
        -- change all other names into their full names
        for i = 1, #modList do
            modList[i] = modloader.getModName(modList[i])
        end
        
        local response, info = http.request(
            server,
            json.encode({
                action = "insert",
                version = modVersion,
                
                port = config[1].value,
                playerCount = instData.currentPlayers,
                maxPlayers = config[2].value,
                date = os.date("!%d/%m/%y %H:%M"),
                mods = json.encode(modList)
            })
        )
        if info ~= 200 then
            instData.error = {"", ""}
            local i = 1
            for word in response:gmatch("[^ ]+") do
                i = (i == 2 or graphics.textWidth(instData.error[1] .. " " .. word, graphics.FONT_DEFAULT) > hostGui.width - 11) and 2 or 1
                instData.error[i] = instData.error[i] .. " " .. word
            end
        else
            instData.toggle = true
        end
    end
    
    instData.prevHudW = hudW
end
local hostHandler = nil
registercallback("globalRoomStart", function(room)
    if room:getOrigin() ~= "Vanilla" then return end
    if room:getName() == "Host" then
        amHost = false
        graphics.bindDepth(-10, lobbyUI)
    elseif room:getName() == "SelectMult" then
        if amHost then
            hostHandler = graphics.bindDepth(-10, hostUI)
        end
    end
end)

registercallback("globalRoomEnd", function(room)
    if room == nil then return end -- unsure why this is happening at the start of the game, but eh sure
    if room:getOrigin() ~= "Vanilla" then return end
    if room:getName() == "Host" then
        disableKeylog()
        for i = 1, 2 do
            local value = config[i].value == "" and 0 or tonumber(config[i].value)
            if i == 1 then
                config[i].value = tostring(math.clamp(value, 0, 99999999))
            else
                config[i].value = tostring(math.clamp(value, 1, 32))
            end
            save.write(config[i].key, config[i].value)
        end
    elseif room:getName() == "SelectMult" then
        if hostHandler ~= nil and hostHandler:isValid() then
            local handlerData = hostHandler:getData()
            if handlerData.toggle and not handlerData.error then
                local response, info = http.request(
                    server,
                    json.encode({
                        action = "delete",
                        version = modVersion
                    })
                )
            end
            hostHandler:destroy()
            hostHandler = nil
        end
    end
end)