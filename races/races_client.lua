--[[

Copyright (c) 2022, Neil J. Tan
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

--]]

local STATE_IDLE <const> = 0
local STATE_EDITING <const> = 1
local STATE_JOINING <const> = 2
local STATE_RACING <const> = 3
local raceState = STATE_IDLE -- race state

local ROLE_EDIT <const> = 1 -- edit tracks role
local ROLE_REGISTER <const> = 2 -- register races role
local ROLE_SPAWN <const> = 4 -- spawn vehicles role

local white <const> = {r = 255, g = 255, b = 255}
local red <const> = {r = 255, g = 0, b = 0}
local green <const> = {r = 0, g = 255, b = 0}
local blue <const> = {r = 0, g = 0, b = 255}
local yellow <const> = {r = 255, g = 255, b = 0}
local purple <const> = {r = 255, g = 0, b = 255}

local startFinishBlipColor <const> = 0 -- 5 - yellow
local startBlipColor <const> = 2 -- green
local finishBlipColor <const> = 0 -- white
local midBlipColor <const> = 38 -- dark blue
local registerBlipColor <const> = 83 -- purple
local racerBlipColor <const> = 2 -- green
local selectedBlipColor <const> = 1 -- red
local blipRouteColor <const> = 2 -- 18 light blue

local startFinishSprite <const> = 38 -- checkered flag
local startSprite <const> = 38 -- checkered flag
local finishSprite <const> = 38 -- checkered flag
local midSprite <const> = 1 -- numbered circle
local registerSprite <const> = 58 -- circled star
local racerSprite <const> = 1 -- circle

local finishCheckpoint <const> = 9 -- cylinder checkered flag
local midCheckpoint <const> = 42 -- cylinder with number
local plainCheckpoint <const> = 45 -- cylinder
local arrow3Checkpoint <const> = 7 -- cylinder with 3 arrows

local defaultBuyin <const> = 0 -- default race buy-in
local defaultLaps <const> = 1 -- default number of laps in a race
local defaultTimeout <const> = 300 -- default DNF timeout
local defaultDelay <const> = 10 -- default race start delay
local defaultRadius <const> = 10.0 -- default waypoint radius

local minRadius <const> = 0.5 -- minimum waypoint radius
local maxRadius <const> = 20.0 -- maximum waypoint radius

local topSide <const> = 0.45 -- top position of HUD
local leftSide <const> = 0.02 -- left position of HUD
local rightSide <const> = leftSide + 0.08 -- right position of HUD

local maxNumVisible <const> = 5 -- maximum number of waypoints visible during a race
local numVisible = maxNumVisible -- number of waypoints visible during a race - may be less than maxNumVisible

local highlightedCheckpoint = 0 -- index of highlighted checkpoint
local selectedWaypoint = 0 -- index of currently selected waypoint
local lastSelectedWaypoint = 0 -- index of last selected waypoint

local raceIndex = -1 -- index of race player has joined
local isPublicTrack = false -- flag indicating if saved track is public or not
local savedTrackName = nil -- name of saved track - nil if track not saved

local waypoints = {} -- waypoints[] = {coord = {x, y, z, r}, checkpoint, blip, sprite, color, number, name}
local startIsFinish = false -- flag indicating if start and finish are same waypoint

local numLaps = -1 -- number of laps in current race
local currentLap = -1 -- current lap

local numWaypointsPassed = -1 -- number of waypoints player has passed
local currentWaypoint = -1 -- current waypoint - for multi-lap races, actual current waypoint is currentWaypoint % #waypoints + 1
local waypointCoord = nil -- coordinates of current waypoint

local raceStart = -1 -- start time of race before delay
local raceDelay = -1 -- delay before official start of race
local countdown = -1 -- countdown before start
local drawLights = false -- draw start lights

local position = -1 -- position in race out of numRacers players
local numRacers = -1 -- number of players in race - no DNF players included
local racerBlips = {} -- blips for all racers participating in race

local lapTimeStart = -1 -- start time of current lap
local bestLapTime = -1 -- best lap time

local raceCheckpoint = nil -- race checkpoint in world

local DNFTimeout = -1 -- DNF timeout after first player finishes the race
local beginDNFTimeout = false -- flag indicating if DNF timeout should begin
local timeoutStart = -1 -- start time of DNF timeout

local restrictedHash = nil -- vehicle hash of race with restricted vehicle
local restrictedClass = nil -- restricted vehicle class

local customClassVehicleList = {} -- list of vehicles in class -1 (Custom)

local originalVehicleHash = nil -- vehicle hash of original vehicle before switching to other vehicles in random vehicle races
local rememberedVehicle = nil -- at first, no vehicles is remembered
local rememberedVehicleProps = nil -- at first, no tuning of vehicle is remembered

local startVehicle = nil -- vehicle name hash of starting vehicle used in random races
local currentVehicleHash = nil -- hash of current vehicle being driven
local currentVehicleName = nil -- name of current vehicle being driven
local bestLapVehicleName = nil -- name of vehicle in which player recorded best lap time

local randVehicles = {} -- list of random vehicles used in random vehicle races

local respawnCtrlPressed = false -- flag indicating if respawn crontrol is pressed
local respawnTime = -1 -- time when respawn control pressed
local startCoord = nil -- coordinates of vehicle once race has started

local results = {} -- results[] = {source, playerName, finishTime, bestLapTime, vehicleName}

local started = false -- flag indicating if race started

local starts = {} -- starts[playerID] = {isPublic, trackName, owner, buyin, laps, timeout, rtype, restrict, vclass, svehicle, vehicleList, blip, checkpoint} - registration points

local speedo = false -- flag indicating if speedometer is displayed
local unitom = "metric" -- current unit of measurement

local panelShown = false -- flag indicating if register, edit or support panel is shown

local roleBits = 0 -- bit flag indicating if player is permitted to create tracks, register races, and/or spawn vehicles

local aiState = nil -- table containing race info and AI driver info table

local enteringVehicle = false -- flag indicating if player is entering a vehicle

local camTransStarted = false -- flag indicating if camera transition at start of race has started

local drivingStyle = 1076625980 -- default driving style for AI

math.randomseed(GetCloudTimeAsInt())

TriggerServerEvent("races:init")

local function notifyPlayer(msg)
    TriggerEvent("chat:addMessage", {
        color = {0, 255, 0},
        multiline = true,
        args = {"[races]", msg}
    })
end

local function sendMessage(msg)
    if true == panelShown then
        SendNUIMessage({
            panel = "reply",
            message = string.gsub(msg, "\n", "<br>")
        })
    else
        notifyPlayer(msg)
    end
end

local function deleteWaypointCheckpoints()
    for i = 1, #waypoints do
        DeleteCheckpoint(waypoints[i].checkpoint)
    end
end

local function getCheckpointColor(blipColor)
    if 0 == blipColor then
        return white
    elseif 1 == blipColor then
        return red
    elseif 2 == blipColor then
        return green
    elseif 38 == blipColor then
        return blue
    elseif 5 == blipColor then
        return green
    elseif 83 == blipColor then
        return purple
    else
        return green
    end
end

local function makeCheckpoint(checkpointType, coord, nextCoord, color, alpha, num)
    local zCoord = coord.z
    if 42 == checkpointType or 45 == checkpointType then
        zCoord = zCoord - coord.r / 2.0
    else
        zCoord = zCoord + coord.r / 2.0
    end
    local checkpoint = CreateCheckpoint(checkpointType, coord.x, coord.y, zCoord, nextCoord.x, nextCoord.y, nextCoord.z, coord.r * 2.0, color.r, color.g, color.b, alpha, num)
    SetCheckpointCylinderHeight(checkpoint, 10.0, 10.0, coord.r * 2.0)
    return checkpoint
end

local function setStartToFinishCheckpoints()
    for i = 1, #waypoints do
        local color = getCheckpointColor(waypoints[i].color)
        local checkpointType = 38 == waypoints[i].sprite and finishCheckpoint or midCheckpoint
        waypoints[i].checkpoint = makeCheckpoint(checkpointType, waypoints[i].coord, waypoints[i].coord, color, 125, i - 1)
    end
end

local function deleteWaypointBlips()
    for i = 1, #waypoints do
        RemoveBlip(waypoints[i].blip)
    end
end

local function setBlipProperties(index)
    SetBlipSprite(waypoints[index].blip, waypoints[index].sprite)
    SetBlipColour(waypoints[index].blip, waypoints[index].color)
    ShowNumberOnBlip(waypoints[index].blip, waypoints[index].number)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(waypoints[index].name)
    EndTextCommandSetBlipName(waypoints[index].blip)
end

local function setStartToFinishBlips()
    if true == startIsFinish then
        waypoints[1].sprite = startFinishSprite
        waypoints[1].color = startFinishBlipColor
        waypoints[1].number = -1
        waypoints[1].name = "Start/Finish"

        if #waypoints > 1 then
            waypoints[#waypoints].sprite = midSprite
            waypoints[#waypoints].color = midBlipColor
            waypoints[#waypoints].number = #waypoints - 1
            waypoints[#waypoints].name = "Waypoint"
        end
    else -- #waypoints should be > 1
        waypoints[1].sprite = startSprite
        waypoints[1].color = startBlipColor
        waypoints[1].number = -1
        waypoints[1].name = "Start"

        waypoints[#waypoints].sprite = finishSprite
        waypoints[#waypoints].color = finishBlipColor
        waypoints[#waypoints].number = -1
        waypoints[#waypoints].name = "Finish"
    end

    for i = 2, #waypoints - 1 do
        waypoints[i].sprite = midSprite
        waypoints[i].color = midBlipColor
        waypoints[i].number = i - 1
        waypoints[i].name = "Waypoint"
    end

    for i = 1, #waypoints do
        setBlipProperties(i)
    end
end

local function loadWaypointBlips(waypointCoords)
    deleteWaypointBlips()
    waypoints = {}

    for i = 1, #waypointCoords - 1 do
        local blip = AddBlipForCoord(waypointCoords[i].x, waypointCoords[i].y, waypointCoords[i].z)
        waypoints[i] = {coord = waypointCoords[i], checkpoint = nil, blip = blip, sprite = -1, color = -1, number = -1, name = nil}
    end

    startIsFinish =
        waypointCoords[1].x == waypointCoords[#waypointCoords].x and
        waypointCoords[1].y == waypointCoords[#waypointCoords].y and
        waypointCoords[1].z == waypointCoords[#waypointCoords].z

    if false == startIsFinish then
        local blip = AddBlipForCoord(waypointCoords[#waypointCoords].x, waypointCoords[#waypointCoords].y, waypointCoords[#waypointCoords].z)
        waypoints[#waypointCoords] = {coord = waypointCoords[#waypointCoords], checkpoint = nil, blip = blip, sprite = -1, color = -1, number = -1, name = nil}
    end

    setStartToFinishBlips()

    SetBlipRoute(waypoints[1].blip, true)
    SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
end

local function restoreBlips()
    for i = 1, #waypoints do
        SetBlipDisplay(waypoints[i].blip, 2)
    end
end

local function removeRegistrationPoint(rIndex)
    RemoveBlip(starts[rIndex].blip) -- delete registration blip
    DeleteCheckpoint(starts[rIndex].checkpoint) -- delete registration checkpoint
    starts[rIndex] = nil
end

local function drawMsg(x, y, msg, scale, justify)
    SetTextFont(4)
    SetTextScale(0, scale)
    SetTextColour(0, 255, 0, 255)
    SetTextOutline()
    SetTextJustification(justify)
    SetTextWrap(0.0, 1.0)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayText(x, y)
end

local function drawRect(x, y, w, h, r, g, b, a)
    DrawRect(x + w / 2.0, y + h / 2.0, w, h, r, g, b, a)
end

local function waypointsToCoords()
    local waypointCoords = {}
    for i = 1, #waypoints do
        waypointCoords[i] = waypoints[i].coord
    end
    if true == startIsFinish then
        waypointCoords[#waypointCoords + 1] = waypointCoords[1]
    end
    return waypointCoords
end

local function waypointsToCoordsRev()
    local waypointCoords = {}
    if true == startIsFinish then
        waypointCoords[1] = waypoints[1].coord
    end
    for i = #waypoints, 1, -1 do
        waypointCoords[#waypointCoords + 1] = waypoints[i].coord
    end
    return waypointCoords
end

local function minutesSeconds(milliseconds)
    local seconds = milliseconds / 1000.0
    local minutes = math.floor(seconds / 60.0)
    seconds = seconds - minutes * 60.0
    return minutes, seconds
end

local function putPedInVehicle(ped, vehicleHash, coord)
    coord = coord or GetEntityCoords(ped)
    local vehicle = CreateVehicle(vehicleHash, coord.x, coord.y, coord.z, GetEntityHeading(ped), true, false)
    --setVehicleProperties(vehicle, rememberedVehicleProps)
    SetModelAsNoLongerNeeded(vehicleHash)
    SetPedIntoVehicle(ped, vehicle, -1)
    return vehicle
end

local function switchVehicle(ped, vehicleHash)
    local vehicle = nil
    if vehicleHash ~= nil then
        RequestModel(vehicleHash)
        while HasModelLoaded(vehicleHash) == false do
            Citizen.Wait(0)
        end
        local pedVehicle = GetVehiclePedIsUsing(ped)
        if pedVehicle ~= 0 then
            if GetPedInVehicleSeat(pedVehicle, -1) == ped or GetVehiclePedIsEntering(ped) == pedVehicle then
                local passengers = {}
                for i = 0, GetVehicleModelNumberOfSeats(GetEntityModel(pedVehicle)) - 2 do
                    local passenger = GetPedInVehicleSeat(pedVehicle, i)
                    if passenger ~= 0 then
                        passengers[#passengers + 1] = {ped = passenger, seat = i}
                    end
                end
                local coord = GetEntityCoords(pedVehicle)
                local speed = GetEntitySpeed(ped)
                SetEntityAsMissionEntity(pedVehicle, true, true)
                DeleteVehicle(pedVehicle)
                vehicle = putPedInVehicle(ped, vehicleHash, coord)
                SetVehicleEngineOn(vehicle, true, true, false)
                SetVehicleForwardSpeed(vehicle, speed)
                for _, passenger in pairs(passengers) do
                    SetPedIntoVehicle(passenger.ped, vehicle, passenger.seat)
                end
            end
        else
            vehicle = putPedInVehicle(ped, vehicleHash, nil)
        end
    end
    return vehicle
end

local function getVehicleProperties(vehicle)
    if DoesEntityExist(vehicle) then

        local primaryColor, secondaryColor = GetVehicleColours(vehicle)
        local pearlescentColor, wheelsColor = GetVehicleExtraColours(vehicle)

        local extras = {}

        for id=0, 12 do
            if DoesExtraExist(vehicle, id) then
                local state = IsVehicleExtraTurnedOn(vehicle, id) == 1
                extras[tostring(id)] = state
            end
        end

        local props = {
            primaryColor      = primaryColor,
            secondaryColor    = secondaryColor,
            pearlescentColor  = pearlescentColor,
            wheelsColor       = wheelsColor,
            rgbcolor1         = {GetVehicleCustomPrimaryColour(vehicle)},
            rgbcolor2         = {GetVehicleCustomSecondaryColour(vehicle)},

            interiorColor     = GetVehicleInteriorColour(vehicle),
            dashboardColor    = GetVehicleDashboardColor(vehicle),
            windowTint        = GetVehicleWindowTint(vehicle),

            plate             = GetVehicleNumberPlateText(vehicle),
            plateIndex        = GetVehicleNumberPlateTextIndex(vehicle),
            wheels            = GetVehicleWheelType(vehicle),

            neonEnabled       = {
                IsVehicleNeonLightEnabled(vehicle, 0),
                IsVehicleNeonLightEnabled(vehicle, 1),
                IsVehicleNeonLightEnabled(vehicle, 2),
                IsVehicleNeonLightEnabled(vehicle, 3)
            },

            extras            = extras,

            neonColor         = table.pack(GetVehicleNeonLightsColour(vehicle)),
            xenonColor        = GetVehicleXenonLightsColour(vehicle),
            tyreSmokeColor    = table.pack(GetVehicleTyreSmokeColor(vehicle)),

            modSpoilers       = GetVehicleMod(vehicle, 0),
            modFrontBumper    = GetVehicleMod(vehicle, 1),
            modRearBumper     = GetVehicleMod(vehicle, 2),
            modSideSkirt      = GetVehicleMod(vehicle, 3),
            modExhaust        = GetVehicleMod(vehicle, 4),
            modFrame          = GetVehicleMod(vehicle, 5),
            modGrille         = GetVehicleMod(vehicle, 6),
            modHood           = GetVehicleMod(vehicle, 7),
            modFender         = GetVehicleMod(vehicle, 8),
            modRightFender    = GetVehicleMod(vehicle, 9),
            modRoof           = GetVehicleMod(vehicle, 10),

            modEngine         = GetVehicleMod(vehicle, 11),
            modBrakes         = GetVehicleMod(vehicle, 12),
            modTransmission   = GetVehicleMod(vehicle, 13),
            modHorns          = GetVehicleMod(vehicle, 14),
            modSuspension     = GetVehicleMod(vehicle, 15),
            modArmor          = GetVehicleMod(vehicle, 16),

            modUnknown17      = IsToggleModOn(vehicle, 17),
            modTurbo          = IsToggleModOn(vehicle, 18),
            modUnknown19      = IsToggleModOn(vehicle, 19),
            modSmokeEnabled   = IsToggleModOn(vehicle, 20),
            modUnknown21      = IsToggleModOn(vehicle, 21),
            modXenon          = IsToggleModOn(vehicle, 22),

            modFrontWheels        = GetVehicleMod(vehicle, 23),
            modBackWheels         = GetVehicleMod(vehicle, 24),
            modCustomFrontWheels  = GetVehicleModVariation(vehicle, 23),
            modCustomBackWheels   = GetVehicleModVariation(vehicle, 24),
            modBulletProofTires   = GetVehicleTyresCanBurst(vehicle),
            modDriftTires         = GetDriftTyresEnabled(vehicle),

            modPlateHolder    = GetVehicleMod(vehicle, 25),
            modVanityPlate    = GetVehicleMod(vehicle, 26),
            modTrimA          = GetVehicleMod(vehicle, 27),
            modOrnaments      = GetVehicleMod(vehicle, 28),
            modDashboard      = GetVehicleMod(vehicle, 29),
            modDial           = GetVehicleMod(vehicle, 30),
            modDoorSpeaker    = GetVehicleMod(vehicle, 31),
            modSeats          = GetVehicleMod(vehicle, 32),
            modSteeringWheel  = GetVehicleMod(vehicle, 33),
            modShifterLeavers = GetVehicleMod(vehicle, 34),
            modAPlate         = GetVehicleMod(vehicle, 35),
            modSpeakers       = GetVehicleMod(vehicle, 36),
            modTrunk          = GetVehicleMod(vehicle, 37),
            modHydrolic       = GetVehicleMod(vehicle, 38),
            modEngineBlock    = GetVehicleMod(vehicle, 39),
            modAirFilter      = GetVehicleMod(vehicle, 40),
            modStruts         = GetVehicleMod(vehicle, 41),
            modArchCover      = GetVehicleMod(vehicle, 42),
            modAerials        = GetVehicleMod(vehicle, 43),
            modTrimB          = GetVehicleMod(vehicle, 44),
            modTank           = GetVehicleMod(vehicle, 45),
            modWindows        = GetVehicleMod(vehicle, 46),
            modMirrors        = GetVehicleMod(vehicle, 47),
            modLiveryMod      = GetVehicleMod(vehicle, 48),
            modLightbar       = GetVehicleMod(vehicle, 49),

            modLivery         = GetVehicleLivery(vehicle),
            modRoofLivery     = GetVehicleRoofLivery(vehicle)
        }

        for k, v in pairs(props) do
            if v == false or v == -1 then
                props[k] = nil
            end
        end
        
        return props
    else
        return
    end
end

local function setVehicleProperties(vehicle, props)
    if DoesEntityExist(vehicle) then
        local primaryColor, secondaryColor = GetVehicleColours(vehicle)
        local pearlescentColor, wheelsColor = GetVehicleExtraColours(vehicle)
        SetVehicleModKit(vehicle, 0)
        SetVehicleDirtLevel(vehicle, 0.0)

        if props.primaryColor then SetVehicleColours(vehicle, props.primaryColor, secondaryColor) end
        if props.secondaryColor then SetVehicleColours(vehicle, props.primaryColor or primaryColor, props.secondaryColor) end
        if props.pearlescentColor then SetVehicleExtraColours(vehicle, props.pearlescentColor, wheelsColor) end
        if props.wheelsColor then SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescentColor, props.wheelsColor) end
        if props.rgbcolor1 then SetVehicleCustomPrimaryColour(vehicle, props.rgbcolor1[1], props.rgbcolor1[2], props.rgbcolor1[3]) end
        if props.rgbcolor2 then SetVehicleCustomSecondaryColour(vehicle, props.rgbcolor2[1], props.rgbcolor2[2], props.rgbcolor2[3]) end
        if props.interiorColor then SetVehicleInteriorColour(vehicle, props.interiorColor) end
        if props.dashboardColor then SetVehicleDashboardColor(vehicle, props.dashboardColor) end
        if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end
        if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
        if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
        if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
        SetVehicleTyresCanBurst(vehicle, props.modBulletProofTires)
        SetDriftTyresEnabled(vehicle, props.modDriftTires)
        --SetReduceDriftVehicleSuspension(vehicle, props.modDriftSuspension) HEEEEEEEEEEEEEEEEEEEEEEELP !     :D

        if props.neonEnabled then
            SetVehicleNeonLightEnabled(vehicle, 0, props.neonEnabled[1])
            SetVehicleNeonLightEnabled(vehicle, 1, props.neonEnabled[2])
            SetVehicleNeonLightEnabled(vehicle, 2, props.neonEnabled[3])
            SetVehicleNeonLightEnabled(vehicle, 3, props.neonEnabled[4])
        end

        if props.extras then
            for id,enabled in pairs(props.extras) do
                if enabled then
                    SetVehicleExtra(vehicle, tonumber(id), 0)
                else
                    SetVehicleExtra(vehicle, tonumber(id), 1)
                end
            end
        end

        if props.neonColor then SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3]) end
        if props.xenonColor then SetVehicleXenonLightsColour(vehicle, props.xenonColor) end
        if props.modSmokeEnabled then ToggleVehicleMod(vehicle, 20, true) end
        if props.tyreSmokeColor then SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3]) end
        if props.modSpoilers then SetVehicleMod(vehicle, 0, props.modSpoilers, false) end
        if props.modFrontBumper then SetVehicleMod(vehicle, 1, props.modFrontBumper, false) end
        if props.modRearBumper then SetVehicleMod(vehicle, 2, props.modRearBumper, false) end
        if props.modSideSkirt then SetVehicleMod(vehicle, 3, props.modSideSkirt, false) end
        if props.modExhaust then SetVehicleMod(vehicle, 4, props.modExhaust, false) end
        if props.modFrame then SetVehicleMod(vehicle, 5, props.modFrame, false) end
        if props.modGrille then SetVehicleMod(vehicle, 6, props.modGrille, false) end
        if props.modHood then SetVehicleMod(vehicle, 7, props.modHood, false) end
        if props.modFender then SetVehicleMod(vehicle, 8, props.modFender, false) end
        if props.modRightFender then SetVehicleMod(vehicle, 9, props.modRightFender, false) end
        if props.modRoof then SetVehicleMod(vehicle, 10, props.modRoof, false) end
        if props.modEngine then SetVehicleMod(vehicle, 11, props.modEngine, false) end
        if props.modBrakes then SetVehicleMod(vehicle, 12, props.modBrakes, false) end
        if props.modTransmission then SetVehicleMod(vehicle, 13, props.modTransmission, false) end
        if props.modHorns then SetVehicleMod(vehicle, 14, props.modHorns, false) end
        if props.modSuspension then SetVehicleMod(vehicle, 15, props.modSuspension, false) end
        if props.modArmor then SetVehicleMod(vehicle, 16, props.modArmor, false) end
        if props.modUnknown17 then ToggleVehicleMod(vehicle,  17, props.modUnknown17) end
        if props.modTurbo then ToggleVehicleMod(vehicle,  18, props.modTurbo) end
        if props.modUnknown19 then ToggleVehicleMod(vehicle,  19, props.modUnknown19) end
        if props.modUnknown21 then ToggleVehicleMod(vehicle,  21, props.modUnknown21) end
        if props.modXenon then ToggleVehicleMod(vehicle,  22, props.modXenon) end
        if props.modFrontWheels then SetVehicleMod(vehicle, 23, props.modFrontWheels, props.modCustomFrontWheels) end
        if props.modBackWheels then SetVehicleMod(vehicle, 24, props.modBackWheels, props.modCustomBackWheels) end
        if props.modPlateHolder then SetVehicleMod(vehicle, 25, props.modPlateHolder, false) end
        if props.modVanityPlate then SetVehicleMod(vehicle, 26, props.modVanityPlate, false) end
        if props.modTrimA then SetVehicleMod(vehicle, 27, props.modTrimA, false) end
        if props.modOrnaments then SetVehicleMod(vehicle, 28, props.modOrnaments, false) end
        if props.modDashboard then SetVehicleMod(vehicle, 29, props.modDashboard, false) end
        if props.modDial then SetVehicleMod(vehicle, 30, props.modDial, false) end
        if props.modDoorSpeaker then SetVehicleMod(vehicle, 31, props.modDoorSpeaker, false) end
        if props.modSeats then SetVehicleMod(vehicle, 32, props.modSeats, false) end
        if props.modSteeringWheel then SetVehicleMod(vehicle, 33, props.modSteeringWheel, false) end
        if props.modShifterLeavers then SetVehicleMod(vehicle, 34, props.modShifterLeavers, false) end
        if props.modAPlate then SetVehicleMod(vehicle, 35, props.modAPlate, false) end
        if props.modSpeakers then SetVehicleMod(vehicle, 36, props.modSpeakers, false) end
        if props.modTrunk then SetVehicleMod(vehicle, 37, props.modTrunk, false) end
        if props.modHydrolic then SetVehicleMod(vehicle, 38, props.modHydrolic, false) end
        if props.modEngineBlock then SetVehicleMod(vehicle, 39, props.modEngineBlock, false) end
        if props.modAirFilter then SetVehicleMod(vehicle, 40, props.modAirFilter, false) end
        if props.modStruts then SetVehicleMod(vehicle, 41, props.modStruts, false) end
        if props.modArchCover then SetVehicleMod(vehicle, 42, props.modArchCover, false) end
        if props.modAerials then SetVehicleMod(vehicle, 43, props.modAerials, false) end
        if props.modTrimB then SetVehicleMod(vehicle, 44, props.modTrimB, false) end
        if props.modTank then SetVehicleMod(vehicle, 45, props.modTank, false) end
        if props.modWindows then SetVehicleMod(vehicle, 46, props.modWindows, false) end
        if props.modMirrors then SetVehicleMod(vehicle, 47, props.modMirrors, false) end
        if props.modLiveryMod then SetVehicleMod(vehicle, 48, props.modLiveryMod, false) end
        if props.modLightbar then SetVehicleMod(vehicle,  49, props.modLightbar, false) end
        if props.modLivery then SetVehicleLivery(vehicle, props.modLivery) end
        if props.modRoofLivery then SetVehicleRoofLivery(vehicle, props.modRoofLivery) end

        while not IsVehicleModLoadDone(vehicle) do 
            Wait(0)
        end

    end
end

local function getPedProperties(ped)
    if DoesEntityExist(ped) then
        local props = {      
            head         = {
                GetPedDrawableVariation(ped, 0),
                GetPedTextureVariation(ped, 0),
                GetPedPaletteVariation(ped, 0)
            },
            beard        = {
                GetPedDrawableVariation(ped, 1),
                GetPedTextureVariation(ped, 1),
                GetPedPaletteVariation(ped, 1)
            },
            hair         = {
                GetPedDrawableVariation(ped, 2),
                GetPedTextureVariation(ped, 2),
                GetPedPaletteVariation(ped, 2)
            },
            upperbody    = {
                GetPedDrawableVariation(ped, 3),
                GetPedTextureVariation(ped, 3),
                GetPedPaletteVariation(ped, 3)
            },
            lowerbody    = {
                GetPedDrawableVariation(ped, 4),
                GetPedTextureVariation(ped, 4),
                GetPedPaletteVariation(ped, 4)
            },
            hands        = {
                GetPedDrawableVariation(ped, 5),
                GetPedTextureVariation(ped, 5),
                GetPedPaletteVariation(ped, 5)
            },
            shoes        = {
                GetPedDrawableVariation(ped, 6),
                GetPedTextureVariation(ped, 6),
                GetPedPaletteVariation(ped, 6)
            },
            teeth        = {
                GetPedDrawableVariation(ped, 7),
                GetPedTextureVariation(ped, 7),
                GetPedPaletteVariation(ped, 7)
            },
            accessory    = {
                GetPedDrawableVariation(ped, 8),
                GetPedTextureVariation(ped, 8),
                GetPedPaletteVariation(ped, 8)
            },
            accessory2   = {
                GetPedDrawableVariation(ped, 9),
                GetPedTextureVariation(ped, 9),
                GetPedPaletteVariation(ped, 9)
            },
            badges       = {
                GetPedDrawableVariation(ped, 10),
                GetPedTextureVariation(ped, 10),
                GetPedPaletteVariation(ped, 10)
            },
            shirtoverlay = {
                GetPedDrawableVariation(ped, 11),
                GetPedTextureVariation(ped, 11),
                GetPedPaletteVariation(ped, 11)
            },
            hats         = {
                GetPedPropIndex(ped, 0),
                GetPedPropTextureIndex(ped, 0)
            },
            glases       = {
                GetPedPropIndex(ped, 1),
                GetPedPropTextureIndex(ped, 1)
            },
            earrings     = {
                GetPedPropIndex(ped, 2),
                GetPedPropTextureIndex(ped, 2)
            },
            watches      = {
                GetPedPropIndex(ped, 6),
                GetPedPropTextureIndex(ped, 6)
            },
            bracelets    = {
                GetPedPropIndex(ped, 7),
                GetPedPropTextureIndex(ped, 7)
            }
        }
        return props
    else
        return
    end
end

local function setPedProperties(ped, props)
    if DoesEntityExist(ped) then
        SetPedComponentVariation(ped, 0, props.head[1], props.head[2], props.head[3])
        SetPedComponentVariation(ped, 1, props.beard[1], props.beard[2], props.beard[3])
        SetPedComponentVariation(ped, 2, props.hair[1], props.hair[2], props.hair[3])
        SetPedComponentVariation(ped, 3, props.upperbody[1], props.upperbody[2], props.upperbody[3])
        SetPedComponentVariation(ped, 4, props.lowerbody[1], props.lowerbody[2], props.lowerbody[3])
        SetPedComponentVariation(ped, 5, props.hands[1], props.hands[2], props.hands[3])
        SetPedComponentVariation(ped, 6, props.shoes[1], props.shoes[2], props.shoes[3])
        SetPedComponentVariation(ped, 7, props.teeth[1], props.teeth[2], props.teeth[3])
        SetPedComponentVariation(ped, 8, props.accessory[1], props.accessory[2], props.accessory[3])
        SetPedComponentVariation(ped, 9, props.accessory2[1], props.accessory2[2], props.accessory2[3])
        SetPedComponentVariation(ped, 10, props.badges[1], props.badges[2], props.badges[3])
        SetPedComponentVariation(ped, 11, props.shirtoverlay[1], props.shirtoverlay[2], props.shirtoverlay[3])
        if props.hats[1] == -1 then
            ClearPedProp(ped, 0)
        else
            SetPedPropIndex(ped, 0, props.hats[1], props.hats[2], true)
        end
        if props.glases[1] == -1 then
            ClearPedProp(ped, 1)
        else
            SetPedPropIndex(ped, 1, props.glases[1], props.glases[2], true)
        end
        if props.earrings[1] == -1 then
            ClearPedProp(ped, 2)
        else
            SetPedPropIndex(ped, 2, props.earrings[1], props.earrings[2], true)
        end
        if props.watches[1] == -1 then
            ClearPedProp(ped, 6)
        else
            SetPedPropIndex(ped, 6, props.watches[1], props.watches[2], true)
        end
        if props.bracelets[1] == -1 then
            ClearPedProp(ped, 7)
        else
            SetPedPropIndex(ped, 7, props.bracelets[1], props.bracelets[2], true)
        end
    end
end

local function getVehicleClassFromName(vehicle)
    local vclass = GetVehicleClassFromName(vehicle)
    if vclass == 0 then
        vclass = 6
        return vclass
    elseif vclass == 1 then
        vclass = 4
        return vclass
    elseif vclass == 2 then
        vclass = 7
        return vclass
    elseif vclass == 3 then
        vclass = 5
        return vclass
    elseif vclass == 4 then
        vclass = 3
        return vclass
    elseif vclass == 5 then
        vclass = 2
        return vclass
    elseif vclass == 6 then
        vclass = 1
        return vclass
    elseif vclass == 7 then
        vclass = 0
        return vclass
    elseif vclass == 8 then
        vclass = 9
        return vclass
    elseif vclass == 9 then
        vclass = 8
        return vclass
    elseif vclass == 10 then
        vclass = 16
        return vclass
    elseif vclass == 11 then
        vclass = 21
        return vclass
    elseif vclass == 12 then
        vclass = 12
        return vclass
    elseif vclass == 13 then
        vclass = 10
        return vclass
    elseif vclass == 14 then
        vclass = 20
        return vclass
    elseif vclass == 15 then
        vclass = 19
        return vclass
    elseif vclass == 16 then
        vclass = 18
        return vclass
    elseif vclass == 17 then
        vclass = 14
        return vclass
    elseif vclass == 18 then
        vclass = 13
        return vclass
    elseif vclass == 19 then
        vclass = 17
        return vclass
    elseif vclass == 20 then
        vclass = 15
        return vclass
    elseif vclass == 21 then
        vclass = 22
        return vclass
    elseif vclass == 22 then
        vclass = 11
        return vclass
    else 
        return
    end
end

local function getClassName(vclass)
    if -1 == vclass then
        return "'Custom'(-1)"
    elseif 0 == vclass then
        return "'Super'(0)"
    elseif 1 == vclass then
        return "'Sports'(1)"
    elseif 2 == vclass then
        return "'Sports Classics'(2)"
    elseif 3 == vclass then
        return "'Muscle'(3)"
    elseif 4 == vclass then
        return "'Sedans'(4)"
    elseif 5 == vclass then
        return "'Coupes'(5)"
    elseif 6 == vclass then
        return "'Compacts'(6)"
    elseif 7 == vclass then
        return "'SUVs'(7)"
    elseif 8 == vclass then
        return "'Off-road'(8)"
    elseif 9 == vclass then
        return "'Motorcycles'(9)"
    elseif 10 == vclass then
        return "'Cycles'(10)"
    elseif 11 == vclass then
        return "'Open Wheel'(11)"
    elseif 12 == vclass then
        return "'Vans'(12)"
    elseif 13 == vclass then
        return "'Emergency'(13)"
    elseif 14 == vclass then
        return "'Service'(14)"
    elseif 15 == vclass then
        return "'Commercial'(15)"
    elseif 16 == vclass then
        return "'Industrial'(16)"
    elseif 17 == vclass then
        return "'Military'(17)"
    elseif 18 == vclass then
        return "'Planes'(18)"
    elseif 19 == vclass then
        return "'Helicopters'(19)"
    elseif 20 == vclass then
        return "'Boats'(20)"
    elseif 21 == vclass then
        return "'Utility'(21)"
    elseif 22 == vclass then
        return "'Trains'(22)"
    else
        return "'Unknown'(" .. vclass .. ")"
    end
end

local function vehicleInList(vehicle, vehicleList)
    for _, vehName in pairs(vehicleList) do
        if GetEntityModel(vehicle) == GetHashKey(vehName) then
            return true
        end
    end
    return false
end

local function finishRace(time)
    TriggerServerEvent("races:finish", raceIndex, PedToNet(PlayerPedId()), nil, numWaypointsPassed, time, bestLapTime, bestLapVehicleName, nil)
    restoreBlips()
    SetBlipRoute(waypoints[1].blip, true)
    SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
    speedo = false
    if #randVehicles > 0 then
        local vehicle = switchVehicle(PlayerPedId(), originalVehicleHash)
        if vehicle ~= nil then
            setVehicleProperties(vehicle, rememberedVehicleProps)
        end
    end
    raceState = STATE_IDLE
end

local function editWaypoints(coord)
    selectedWaypoint = 0
    local minDist = maxRadius
    for index, waypoint in ipairs(waypoints) do
        local dist = #(coord - vector3(waypoint.coord.x, waypoint.coord.y, waypoint.coord.z))
        if dist < waypoint.coord.r and dist < minDist then
            minDist = dist
            selectedWaypoint = index
        end
    end

    if 0 == selectedWaypoint then -- no existing waypoint selected
        if 0 == lastSelectedWaypoint then -- no previous selected waypoint exists, add new waypoint
            local blip = AddBlipForCoord(coord.x, coord.y, coord.z)

            local coordRad = {x = coord.x, y = coord.y, z = coord.z, r = defaultRadius}
            waypoints[#waypoints + 1] = {coord = coordRad, checkpoint = nil, blip = blip, sprite = -1, color = -1, number = -1, name = nil}

            startIsFinish = 1 == #waypoints and true or false
            setStartToFinishBlips()
            deleteWaypointCheckpoints()
            setStartToFinishCheckpoints()

        else -- previous selected waypoint exists, move previous selected waypoint to new location
            waypoints[lastSelectedWaypoint].coord = {x = coord.x, y = coord.y, z = coord.z, r = waypoints[lastSelectedWaypoint].coord.r}

            SetBlipCoords(waypoints[lastSelectedWaypoint].blip, coord.x, coord.y, coord.z)

            DeleteCheckpoint(waypoints[lastSelectedWaypoint].checkpoint)
            local color = getCheckpointColor(waypoints[lastSelectedWaypoint].color)
            local checkpointType = 38 == waypoints[lastSelectedWaypoint].sprite and finishCheckpoint or midCheckpoint
            waypoints[lastSelectedWaypoint].checkpoint = makeCheckpoint(checkpointType, waypoints[lastSelectedWaypoint].coord, coord, color, 125, lastSelectedWaypoint - 1)
            SetBlipColour(waypoints[lastSelectedWaypoint].blip, waypoints[lastSelectedWaypoint].color)

            selectedWaypoint = 0
            lastSelectedWaypoint = 0
        end

        savedTrackName = nil

        SetBlipRoute(waypoints[1].blip, true)
        SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
    else -- existing waypoint selected
        if 0 == lastSelectedWaypoint then -- no previous selected waypoint exists
            SetBlipColour(waypoints[selectedWaypoint].blip, selectedBlipColor)
            local color = getCheckpointColor(selectedBlipColor)
            SetCheckpointRgba(waypoints[selectedWaypoint].checkpoint, color.r, color.g, color.b, 125)
            SetCheckpointRgba2(waypoints[selectedWaypoint].checkpoint, color.r, color.g, color.b, 125)

            lastSelectedWaypoint = selectedWaypoint
        else -- previous selected waypoint exists
            if selectedWaypoint ~= lastSelectedWaypoint then -- selected waypoint and previous selected waypoint are different
                local splitCombine = false
                local checkpointType = finishCheckpoint
                local waypointNum = 0
                if true == startIsFinish then
                    if #waypoints == selectedWaypoint and 1 == lastSelectedWaypoint then -- split start/finish waypoint
                        splitCombine = true

                        startIsFinish = false

                        waypoints[1].sprite = startSprite
                        waypoints[1].color = startBlipColor
                        waypoints[1].number = -1
                        waypoints[1].name = "Start"

                        waypoints[#waypoints].sprite = finishSprite
                        waypoints[#waypoints].color = finishBlipColor
                        waypoints[#waypoints].number = -1
                        waypoints[#waypoints].name = "Finish"
                    end
                else
                    if 1 == selectedWaypoint and #waypoints == lastSelectedWaypoint then -- combine start and finish waypoints
                        splitCombine = true

                        startIsFinish = true

                        waypoints[1].sprite = startFinishSprite
                        waypoints[1].color = startFinishBlipColor
                        waypoints[1].number = -1
                        waypoints[1].name = "Start/Finish"

                        waypoints[#waypoints].sprite = midSprite
                        waypoints[#waypoints].color = midBlipColor
                        waypoints[#waypoints].number = #waypoints - 1
                        waypoints[#waypoints].name = "Waypoint"

                        checkpointType = midCheckpoint
                        waypointNum = #waypoints - 1
                    end
                end
                if true == splitCombine then
                    setBlipProperties(1)
                    setBlipProperties(#waypoints)

                    local color = getCheckpointColor(waypoints[1].color)
                    SetCheckpointRgba(waypoints[1].checkpoint, color.r, color.g, color.b, 125)
                    SetCheckpointRgba2(waypoints[1].checkpoint, color.r, color.g, color.b, 125)

                    DeleteCheckpoint(waypoints[#waypoints].checkpoint)
                    color = getCheckpointColor(waypoints[#waypoints].color)
                    waypoints[#waypoints].checkpoint = makeCheckpoint(checkpointType, waypoints[#waypoints].coord, waypoints[#waypoints].coord, color, 125, waypointNum)

                    selectedWaypoint = 0
                    lastSelectedWaypoint = 0
                    savedTrackName = nil
                else
                    SetBlipColour(waypoints[lastSelectedWaypoint].blip, waypoints[lastSelectedWaypoint].color)
                    local color = getCheckpointColor(waypoints[lastSelectedWaypoint].color)
                    SetCheckpointRgba(waypoints[lastSelectedWaypoint].checkpoint, color.r, color.g, color.b, 125)
                    SetCheckpointRgba2(waypoints[lastSelectedWaypoint].checkpoint, color.r, color.g, color.b, 125)

                    SetBlipColour(waypoints[selectedWaypoint].blip, selectedBlipColor)
                    color = getCheckpointColor(selectedBlipColor)
                    SetCheckpointRgba(waypoints[selectedWaypoint].checkpoint, color.r, color.g, color.b, 125)
                    SetCheckpointRgba2(waypoints[selectedWaypoint].checkpoint, color.r, color.g, color.b, 125)

                    lastSelectedWaypoint = selectedWaypoint
                end
            else -- selected waypoint and previous selected waypoint are the same
                SetBlipColour(waypoints[selectedWaypoint].blip, waypoints[selectedWaypoint].color)
                local color = getCheckpointColor(waypoints[selectedWaypoint].color)
                SetCheckpointRgba(waypoints[selectedWaypoint].checkpoint, color.r, color.g, color.b, 125)
                SetCheckpointRgba2(waypoints[selectedWaypoint].checkpoint, color.r, color.g, color.b, 125)

                selectedWaypoint = 0
                lastSelectedWaypoint = 0
            end
        end
    end
end

local function removeRacerBlips()
    for _, blip in pairs(racerBlips) do
        RemoveBlip(blip)
    end
    racerBlips = {}
end

local function respawnAI(driver)
    local passengers = {}
    for i = 0, GetVehicleModelNumberOfSeats(GetEntityModel(driver.vehicle)) - 2 do
        local passenger = GetPedInVehicleSeat(driver.vehicle, i)
        if passenger ~= 0 then
            passengers[#passengers + 1] = {ped = passenger, seat = i}
        end
    end
    local currentVehicleHash = GetEntityModel(driver.vehicle)
    RequestModel(currentVehicleHash)
    while HasModelLoaded(currentVehicleHash) == false do
        Citizen.Wait(0)
    end
    SetEntityAsMissionEntity(driver.vehicle, true, true)
    DeleteVehicle(driver.vehicle)
    local coord = driver.startCoord
    if true == aiState.startIsFinish then
        if driver.currentWP > 0 then
            coord = aiState.waypointCoords[driver.currentWP]
        end
    else
        if driver.currentWP > 1 then
            coord = aiState.waypointCoords[driver.currentWP - 1]
        end
    end
    driver.vehicle = putPedInVehicle(driver.ped, currentVehicleHash, coord)
    for _, passenger in pairs(passengers) do
        SetPedIntoVehicle(passenger.ped, driver.vehicle, passenger.seat)
    end
    driver.destSet = true
end

local function request(role)
    if role ~= nil then
        local roleBit = 0
        if "edit" == role then
            roleBit = ROLE_EDIT
        elseif "register" == role then
            roleBit = ROLE_REGISTER
        elseif "spawn" == role then
            roleBit = ROLE_SPAWN
        end
        if roleBit ~= 0 then
            TriggerServerEvent("races:request", roleBit)
        else
            sendMessage("Cannot make request.  Invalid role.\n")
        end
    else
        sendMessage("Cannot make request.  Role required.\n")
    end
end

local function edit()
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
    if STATE_IDLE == raceState then
        raceState = STATE_EDITING
        SetWaypointOff()
        setStartToFinishCheckpoints()
        notifyPlayer("Editing started.\n")
        SendNUIMessage({
            panel = "edit_close"
        })
    elseif STATE_EDITING == raceState then
        raceState = STATE_IDLE
        highlightedCheckpoint = 0
        if selectedWaypoint > 0 then
            SetBlipColour(waypoints[selectedWaypoint].blip, waypoints[selectedWaypoint].color)
            selectedWaypoint = 0
        end
        lastSelectedWaypoint = 0
        deleteWaypointCheckpoints()
        notifyPlayer("Editing stopped.\n")
    else
        sendMessage("Cannot edit waypoints.  Leave race first.\n")
    end
end

local function clear()
    if STATE_IDLE == raceState then
        deleteWaypointBlips()
        waypoints = {}
        startIsFinish = false
        savedTrackName = nil
        sendMessage("Waypoints cleared.\n")
    elseif STATE_EDITING == raceState then
        highlightedCheckpoint = 0
        selectedWaypoint = 0
        lastSelectedWaypoint = 0
        deleteWaypointCheckpoints()
        deleteWaypointBlips()
        waypoints = {}
        startIsFinish = false
        savedTrackName = nil
        sendMessage("Waypoints cleared.\n")
    else
        sendMessage("Cannot clear waypoints.  Leave race first.\n")
    end
end

local function reverse()
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
    if #waypoints > 1 then
        if STATE_IDLE == raceState then
            savedTrackName = nil
            loadWaypointBlips(waypointsToCoordsRev())
            sendMessage("Waypoints reversed.\n")
        elseif STATE_EDITING == raceState then
            savedTrackName = nil
            highlightedCheckpoint = 0
            selectedWaypoint = 0
            lastSelectedWaypoint = 0
            deleteWaypointCheckpoints()
            loadWaypointBlips(waypointsToCoordsRev())
            setStartToFinishCheckpoints()
            sendMessage("Waypoints reversed.\n")
        else
            sendMessage("Cannot reverse waypoints.  Leave race first.\n")
        end
    else
        sendMessage("Cannot reverse waypoints.  Track needs to have at least 2 waypoints.\n")
    end
end

local function loadTrack(access, trackName)
    if 0 == roleBits & (ROLE_EDIT | ROLE_REGISTER) then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            if STATE_IDLE == raceState or STATE_EDITING == raceState then
                TriggerServerEvent("races:load", "pub" == access, trackName)
            else
                sendMessage("Cannot load.  Leave race first.\n")
            end
        else
            sendMessage("Cannot load.  Name required.\n")
        end
    else
        sendMessage("Cannot load.  Invalid access type.\n")
    end
end

local function saveTrack(access, trackName)
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            if #waypoints > 1 then
                TriggerServerEvent("races:save", "pub" == access, trackName, waypointsToCoords())
            else
                sendMessage("Cannot save.  Track needs to have at least 2 waypoints.\n")
            end
        else
            sendMessage("Cannot save.  Name required.\n")
        end
    else
        sendMessage("Cannot save.  Invalid access type.\n")
    end
end

local function overwriteTrack(access, trackName)
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            if #waypoints > 1 then
                TriggerServerEvent("races:overwrite", "pub" == access, trackName, waypointsToCoords())
            else
                sendMessage("Cannot overwrite.  Track needs to have at least 2 waypoints.\n")
            end
        else
            sendMessage("Cannot overwrite.  Name required.\n")
        end
    else
        sendMessage("Cannot overwrite.  Invalid access type.\n")
    end
end

local function deleteTrack(access, trackName)
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            TriggerServerEvent("races:delete", "pub" == access, trackName)
        else
            sendMessage("Cannot delete.  Name required.\n")
        end
    else
        sendMessage("Cannot delete.  Invalid access type.\n")
    end
end

local function bestLapTimes(access, trackName)
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            TriggerServerEvent("races:blt", "pub" == access, trackName)
        else
            sendMessage("Cannot list best lap times.  Name required.\n")
        end
    else
        sendMessage("Cannot list best lap times.  Invalid access type.\n")
    end
end

local function list(access)
    if "pvt" == access or "pub" == access then
        TriggerServerEvent("races:list", "pub" == access)
    else
        sendMessage("Cannot list tracks.  Invalid access type.\n")
    end
end

local function register(buyin, laps, timeout, allowAI, rtype, arg6, arg7, arg8)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    buyin = (nil == buyin or "." == buyin) and defaultBuyin or math.tointeger(tonumber(buyin))
    if buyin ~= nil and buyin >= 0 then
        laps = (nil == laps or "." == laps) and defaultLaps or math.tointeger(tonumber(laps))
        if laps ~= nil and laps > 0 then
            timeout = (nil == timeout or "." == timeout) and defaultTimeout or math.tointeger(tonumber(timeout))
            if timeout ~= nil and timeout >= 0 then
                allowAI = (nil == allowAI or "." == allowAI) and "yes" or allowAI
                if "yes" == allowAI or "no" == allowAI then
                    buyin = "yes" == allowAI and 0 or buyin
                    local registerRace = true
                    local restrict = nil
                    local filename = nil
                    local vclass = nil
                    local svehicle = nil
                    if "rest" == rtype then
                        restrict = arg6
                        if nil == restrict or IsModelInCdimage(restrict) ~= 1 or IsModelAVehicle(restrict) ~= 1 then
                            registerRace = false
                            sendMessage("Cannot register.  Invalid restricted vehicle.\n")
                        end
                    elseif "class" == rtype then
                        vclass = math.tointeger(tonumber(arg6))
                        filename = arg7
                        if nil == vclass or vclass < -1 or vclass > 22 then
                            registerRace = false
                            sendMessage("Cannot register.  Invalid vehicle class.\n")
                        elseif -1 == vclass and nil == filename then
                            registerRace = false
                            sendMessage("Cannot register.  Invalid file name.\n")
                        end
                    elseif "rand" == rtype then
                        buyin = 0
                        if "." == arg6 then
                            arg6 = nil
                        end
                        if "." == arg7 then
                            arg7 = nil
                        end
                        if "." == arg8 then
                            arg8 = nil
                        end
                        filename = arg6
                        vclass = math.tointeger(tonumber(arg7))
                        if vclass ~= nil and (vclass < 0 or vclass > 22) then
                            registerRace = false
                            sendMessage("Cannot register.  Invalid vehicle class.\n")
                        else
                            svehicle = arg8
                            if svehicle ~= nil then
                                if IsModelInCdimage(svehicle) ~= 1 or IsModelAVehicle(svehicle) ~= 1 then
                                    registerRace = false
                                    sendMessage("Cannot register.  Invalid start vehicle.\n")
                                elseif vclass ~= nil and getVehicleClassFromName(svehicle) ~= vclass then
                                    registerRace = false
                                    sendMessage("Cannot register.  Start vehicle not of indicated vehicle class.\n")
                                end
                            end
                        end
                    elseif rtype ~= nil then
                        registerRace = false
                        sendMessage("Cannot register.  Unknown race type.\n")
                    end
                    if true == registerRace then
                        if STATE_IDLE == raceState then
                            if #waypoints > 1 then
                                if laps < 2 or (laps >= 2 and true == startIsFinish) then
                                    local rdata = {rtype = rtype, restrict = restrict, filename = filename, vclass = vclass, svehicle = svehicle}
                                    local coords = waypointsToCoords()
                                    SetPedCoordsKeepVehicle(PlayerPedId(), coords[1].x, coords[1].y, coords[1].z)
                                    TriggerServerEvent("races:register", coords, isPublicTrack, savedTrackName, buyin, laps, timeout, allowAI, rdata)
                                else
                                    sendMessage("For multi-lap races, start and finish waypoints need to be the same: While editing waypoints, select finish waypoint first, then select start waypoint.  To separate start/finish waypoint, add a new waypoint or select start/finish waypoint first, then select highest numbered waypoint.\n")
                                end
                            else
                                sendMessage("Cannot register.  Track needs to have at least 2 waypoints.\n")
                            end
                        elseif STATE_EDITING == raceState then
                            sendMessage("Cannot register.  Stop editing first.\n")
                        else
                            sendMessage("Cannot register.  Leave race first.\n")
                        end
                    end
                else
                    sendMessage("Invalid AI allowed value.\n")
                end
            else
                sendMessage("Invalid DNF timeout.\n")
            end
        else
            sendMessage("Invalid number of laps.\n")
        end
    else
        sendMessage("Invalid buy-in amount.\n")
    end
end

local function unregister()
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    TriggerServerEvent("races:unregister")
end

local function startRace(delay)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    delay = math.tointeger(tonumber(delay)) or defaultDelay
    if delay ~= nil and delay >= 5 then
        if aiState ~= nil then
            for aiName, driver in pairs(aiState.drivers) do
                ClearRagdollBlockingFlags(aiState.drivers[aiName].ped, 2)
                SetEntityInvincible(aiState.drivers[aiName].ped, false)
                TaskEnterVehicle(aiState.drivers[aiName].ped, aiState.drivers[aiName].vehicle, 10000, -1, 1.0, 1, 0)
            end
            local allSpawned = true
            for _, driver in pairs(aiState.drivers) do
                if nil == driver.ped or nil == driver.vehicle then
                    allSpawned = false
                    break
                end
            end
            if true == allSpawned then
                for _, driver in pairs(aiState.drivers) do
                    RemoveMpGamerTag(driver.gamerTag)
                end
                TriggerServerEvent("races:start", delay)
            else
                sendMessage("Cannot start.  Some AI drivers not spawned.\n")
            end
        else
            TriggerServerEvent("races:start", delay)
        end
    else
        sendMessage("Cannot start.  Invalid delay.\n")
    end
end

local function spawnAIDriver(aiName, vehicleHash, pedHash, coord, heading)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return false
    end
    if aiName ~= nil then
        local pIndex = GetPlayerServerId(PlayerId())
        if starts[pIndex] ~= nil then
            if "yes" == starts[pIndex].allowAI then
                if nil == aiState then
                    aiState = {
                        numRacing = 0,
                        raceStart = -1,
                        raceDelay = -1,
                        numLaps = starts[pIndex].laps,
                        DNFTimeout = starts[pIndex].timeout * 1000,
                        beginDNFTimeout = false,
                        timeoutStart = -1,
                        rtype = starts[pIndex].rtype,
                        restrict = starts[pIndex].restrict,
                        vclass = starts[pIndex].vclass,
                        svehicle = starts[pIndex].svehicle,
                        vehicleList = starts[pIndex].vehicleList,
                        randVehicles = {},
                        waypointCoords = nil,
                        startIsFinish = false,
                        drivers = {}
                    }
                end
                if nil == aiState.drivers[aiName] then
                    local player = PlayerPedId()
                    aiState.drivers[aiName] = {
                        netID = nil,
                        raceState = STATE_JOINING,
                        startCoord = coord,
                        heading = heading,
                        destCoord = nil,
                        destSet = false,
                        vehicle = nil,
                        ped = nil,
                        started = false,
                        currentWP = -1,
                        numWaypointsPassed = 0,
                        bestLapVehicleName = nil,
                        bestLapTime = -1,
                        currentLap = 1,
                        lapTimeStart = -1,
                        enteringVehicle = false,
                        stuckCoord = vector3(coord.x, coord.y, coord.z),
                        stuckStart = -1
                    }
                    aiState.numRacing = aiState.numRacing + 1
                end
                if aiState ~= nil then
                    local driver = aiState.drivers[aiName]
                    if driver ~= nil then
                        if nil == driver.vehicle and nil == driver.ped then
                            vehicleHash = nil == vehicleHash and "t20" or vehicleHash
                            pedHash = nil == pedHash and "a_f_y_beach_01" or pedHash
                            if IsModelInCdimage(vehicleHash) == 1 and IsModelAVehicle(vehicleHash) == 1 and IsModelInCdimage(pedHash) == 1 and IsModelAPed(pedHash) == 1 then
                                local joinRace = true
                                if "rest" == aiState.rtype then
                                    if vehicleHash ~= GetHashKey(aiState.restrict) then
                                        joinRace = false
                                        notifyPlayer("Cannot join race.  AI needs to be in restricted vehicle.")
                                    end
                                elseif "class" == aiState.rtype then
                                    if aiState.vclass ~= -1 then
                                        if getVehicleClassFromName(vehicleHash) ~= aiState.vclass then
                                            joinRace = false
                                            notifyPlayer("Cannot join race.  AI needs to be in vehicle of " .. getClassName(aiState.vclass) .. " class.")
                                        end
                                    else
                                        if #aiState.vehicleList == 0 then
                                            joinRace = false
                                            notifyPlayer("Cannot join race.  No valid vehicles in vehicle list.")
                                        else
                                            local found = false
                                            local vehicleList = ""
                                            for _, vehName in pairs(aiState.vehicleList) do
                                                if vehicleHash == vehName then
                                                    found = true
                                                    break
                                                end
                                                vehicleList = vehicleList .. vehName .. ", "
                                            end
                                            if false == found then
                                                joinRace = false
                                                vehicleList = string.sub(vehicleList, 1, -3)
                                                notifyPlayer("Cannot join race.  AI needs to be in one of the following vehicles:  " .. vehicleList)
                                            end
                                        end
                                    end
                                elseif "rand" == aiState.rtype then
                                    if #aiState.vehicleList == 0 then
                                        joinRace = false
                                        notifyPlayer("Cannot join race.  No valid vehicles in vehicle list.")
                                    else
                                        if aiState.vclass ~= nil then
                                            if nil == aiState.svehicle then
                                                if getVehicleClassFromName(vehicleHash) ~= aiState.vclass then
                                                    joinRace = false
                                                    notifyPlayer("Cannot join race.  AI needs to be in vehicle of " .. getClassName(aiState.vclass) .. " class.")
                                                end
                                            end
                                        end
                                    end
                                end

                                if true == joinRace then
                                    RequestModel(vehicleHash)
                                    while HasModelLoaded(vehicleHash) == false do
                                        Citizen.Wait(0)
                                    end  
                                    driver.vehicle = CreateVehicle(vehicleHash, driver.startCoord.x, driver.startCoord.y, driver.startCoord.z, driver.heading, true, false)
                                    SetModelAsNoLongerNeeded(vehicleHash)
                                    SetVehicleEngineOn(driver.vehicle, true, true, false)
                                    SetVehRadioStation(driver.vehicle, "OFF")

                                    RequestModel(pedHash)
                                    while HasModelLoaded(pedHash) == false do
                                        Citizen.Wait(0)
                                    end
                                    driver.ped = CreatePed(PED_TYPE_CIVMALE, pedHash, driver.startCoord.x, driver.startCoord.y, driver.startCoord.z, driver.heading, true, false)
                                    SetModelAsNoLongerNeeded(pedHash)
                                    SetDriverAbility(driver.ped, 100.0)
                                    SetDriverAggressiveness(driver.ped, 0.0)
                                    SetDriverRacingModifier(driver.ped, 1.0)
                                    SetBlockingOfNonTemporaryEvents(driver.ped, true)
                                    SetPedCanBeDraggedOut(driver.ped, false)
                                    SetEntityInvincible(driver.ped, true)
                                    SetRagdollBlockingFlags(driver.ped, 2)
                                    SetPedRandomComponentVariation(driver.ped, 0)
                                    SetPedRandomProps(driver.ped)

                                    while NetworkGetEntityIsNetworked(driver.ped) == false do
                                        Citizen.Wait(0)
                                        NetworkRegisterEntityAsNetworked(driver.ped)
                                    end
                                    driver.netID = PedToNet(driver.ped)

                                    driver.bestLapVehicleName = GetLabelText(GetDisplayNameFromVehicleModel(vehicleHash))
                                    driver.gamerTag = CreateFakeMpGamerTag(driver.ped, aiName, false, false, nil, 0)
                                    SetMpGamerTagVisibility(driver.gamerTag, 0, true)

                                    driver.bestLapVehicleName = GetLabelText(GetDisplayNameFromVehicleModel(vehicleHash))

                                    TriggerServerEvent("races:join", pIndex, driver.netID, aiName)

                                    sendMessage("AI driver '" .. aiName .. "' spawned.\n")

                                    return true
                                end
                            else
                                sendMessage("Cannot spawn AI.  Invalid vehicle or ped.\n")
                            end
                        else
                            SetPedRandomComponentVariation(aiState.drivers[aiName].ped, 0)
                            ClearAllPedProps(aiState.drivers[aiName].ped)
                            SetPedRandomProps(aiState.drivers[aiName].ped)
                            sendMessage("Driver already spawned, the appearance of ped has been changed.\n")
                        end
                    else
                        sendMessage("'" .. aiName .. "' not an AI driver.\n")
                    end
                else
                    sendMessage("No AI drivers added.\n")
                end
            else
                sendMessage("AI drivers not allowed.\n")
            end
        else
            sendMessage("Race has not been registered.\n")
        end
    else
        sendMessage("Name required.\n")
    end
    return false
end

local function deleteAIDriver(aiName)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return false
    end
    local pIndex = GetPlayerServerId(PlayerId())
    if starts[pIndex] ~= nil then
        if "yes" == starts[pIndex].allowAI then
            if aiState ~= nil then
                if aiName ~= nil then
                    local driver = aiState.drivers[aiName]
                    if driver ~= nil then
                        if STATE_JOINING == driver.raceState then
                            if driver.ped ~= nil or driver.vehicle ~= nil then
                                TriggerServerEvent("races:leave", pIndex, driver.netID, aiName)
                            end
                            if driver.ped ~= nil then
                                DeletePed(driver.ped)
                            end
                            if driver.vehicle ~= nil then
                                SetEntityAsMissionEntity(driver.vehicle, true, true)
                                DeleteVehicle(driver.vehicle)
                            end
                            aiState.drivers[aiName] = nil
                            aiState.numRacing = aiState.numRacing - 1
                            sendMessage("AI driver '" .. aiName .. "' deleted.\n")
                        elseif STATE_RACING == driver.raceState then
                            sendMessage("Cannot delete AI driver.  '" .. aiName .. "' is in a race.\n")
                        else
                            sendMessage("Cannot delete AI driver.  '" .. aiName .. "' is not joined to a race.\n")
                        end
                    else
                        sendMessage("'" .. aiName .. "' not an AI driver.\n")
                    end
                else
                    for aiName, driver in pairs(aiState.drivers) do
                        if STATE_JOINING == driver.raceState then
                            if driver.ped ~= nil or driver.vehicle ~= nil then
                                TriggerServerEvent("races:leave", pIndex, driver.netID, aiName)
                            end
                            if driver.ped ~= nil then
                                DeletePed(driver.ped)
                            end
                            if driver.vehicle ~= nil then
                                SetEntityAsMissionEntity(driver.vehicle, true, true)
                                DeleteVehicle(driver.vehicle)
                            end
                            aiState.drivers[aiName] = nil
                            aiState.numRacing = aiState.numRacing - 1
                            sendMessage("AI driver '" .. aiName .. "' deleted.\n")
                        else
                            if STATE_RACING == driver.raceState then
                                sendMessage("Cannot delete AI driver.  '" .. aiName .. "' is in a race.\n")
                            else
                                sendMessage("Cannot delete AI driver.  '" .. aiName .. "' is not joined to a race.\n")
                            end
                        end
                    end
                    sendMessage("All AI drivers has been deleted.\n")
                end
                if 0 == aiState.numRacing then
                    aiState = nil
                    return true
                end
            else
                sendMessage("No AI drivers added.\n")
                return true
            end
        else
            sendMessage("AI drivers not allowed.\n")
        end
    else
        sendMessage("Race has not been registered.\n")
    end
    return false
end

local function listAIDrivers()
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    if aiState ~= nil then
        local aiNames = {}
        for aiName in pairs(aiState.drivers) do
            aiNames[#aiNames + 1] = aiName
        end
        if #aiNames > 0 then
            table.sort(aiNames)
            local msg = "AI drivers:\n"
            for _, aiName in ipairs(aiNames) do
                msg = msg .. aiName .. "\n"
            end
            sendMessage(msg)
        else
            sendMessage("No AI drivers.\n")
        end
    else
        sendMessage("No AI drivers.\n")
    end
end

local function loadGrp(access, name)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if name ~= nil then
            TriggerServerEvent("races:loadGrp", "pub" == access, name)
        else
            sendMessage("Cannot load AI group.  Name required.\n")
        end
    else
        sendMessage("Cannot load AI group.  Invalid access type.\n")
    end
end

local function saveGrp(access, name)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if name ~= nil then
            if aiState ~= nil then
                local allSpawned = true
                local group = {}
                for aiName, driver in pairs(aiState.drivers) do
                    if driver.ped ~= nil and driver.vehicle ~= nil then
                        group[aiName] = {startCoord = GetEntityCoords(driver.vehicle), heading = GetEntityHeading(driver.vehicle), vehicleHash = GetEntityModel(driver.vehicle), pedHash = GetEntityModel(driver.ped), vehicleProps = getVehicleProperties(driver.vehicle), pedProps = getPedProperties(driver.ped)}
                    else
                        allSpawned = false
                        break
                    end
                end
                if true == allSpawned then
                    TriggerServerEvent("races:saveGrp", "pub" == access, name, group)
                else
                    sendMessage("Cannot save AI group.  Some AI drivers not spawned.\n")
                end
            else
                sendMessage("Cannot save AI group.  No AI drivers added.\n")
            end
        else
            sendMessage("Cannot save AI group.  Name required.\n")
        end
    else
        sendMessage("Cannot save AI group.  Invalid access type.\n")
    end
end

local function overwriteGrp(access, name)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if name ~= nil then
            if aiState ~= nil then
                local allSpawned = true
                local group = {}
                for aiName, driver in pairs(aiState.drivers) do
                    if driver.ped ~= nil and driver.vehicle ~= nil then
                    group[aiName] = {startCoord = GetEntityCoords(driver.vehicle), heading = GetEntityHeading(driver.vehicle), vehicleHash = GetEntityModel(driver.vehicle), pedHash = GetEntityModel(driver.ped), vehicleProps = getVehicleProperties(driver.vehicle), pedProps = getPedProperties(driver.ped)}
                    else
                        allSpawned = false
                        break
                    end
                end
                if true == allSpawned then
                    TriggerServerEvent("races:overwriteGrp", "pub" == access, name, group)
                else
                    sendMessage("Cannot overwrite AI group.  Some AI drivers not spawned.\n")
                end
            else
                sendMessage("Cannot overwrite AI group.  No AI drivers added.\n")
            end
        else
            sendMessage("Cannot overwrite AI group.  Name required.\n")
        end
    else
        sendMessage("Cannot overwrite AI group.  Invalid access type.\n")
    end
end

local function deleteGrp(access, name)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if name ~= nil then
            TriggerServerEvent("races:deleteGrp", "pub" == access, name)
        else
            sendMessage("Cannot delete AI group.  Name required.\n")
        end
    else
        sendMessage("Cannot delete AI group.  Invalid access type.\n")
    end
end

local function listGrp(access)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        TriggerServerEvent("races:listGrp", "pub" == access)
    else
        sendMessage("Cannot list AI groups.  Invalid access type.\n")
    end
end

local function leave()
    local player = PlayerPedId()
    if STATE_JOINING == raceState then
        raceState = STATE_IDLE
        TriggerServerEvent("races:leave", raceIndex, PedToNet(player), nil)
        removeRacerBlips()
        sendMessage("Left race.\n")
    elseif STATE_RACING == raceState then
        if IsPedInAnyVehicle(player, false) == 1 then
            FreezeEntityPosition(GetVehiclePedIsIn(player, false), false)
        end
        RenderScriptCams(false, false, 0, true, true)
        DeleteCheckpoint(raceCheckpoint)
        finishRace(-1)
        removeRacerBlips()
        sendMessage("Left race.\n")
    else
        sendMessage("Cannot leave.  Not joined to any race.\n")
    end
end

local function rivals()
    if STATE_JOINING == raceState or STATE_RACING == raceState then
        TriggerServerEvent("races:rivals", raceIndex)
    else
        sendMessage("Cannot list competitors.  Not joined to any race.\n")
    end
end

local function respawn()
    if STATE_RACING == raceState then
        local coord = startCoord
        if true == startIsFinish then
            if currentWaypoint > 0 then
                coord = waypoints[currentWaypoint].coord
            end
        else
            if currentWaypoint > 1 then
                coord = waypoints[currentWaypoint - 1].coord
            end
        end
        local player = PlayerPedId()
        local passengers = {}
        local vehicle = GetVehiclePedIsIn(player, false)
        if vehicle ~= 0 then
            if GetPedInVehicleSeat(vehicle, -1) == player then
                for i = 0, GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2 do
                    local passenger = GetPedInVehicleSeat(vehicle, i)
                    if passenger ~= 0 then
                        passengers[#passengers + 1] = {ped = passenger, seat = i}
                    end
                end
                SetEntityAsMissionEntity(vehicle, true, true)
                DeleteVehicle(vehicle)
            end
        end
        SetEntityCoords(player, coord.x, coord.y, coord.z, false, false, false, true)
        if currentVehicleHash ~= nil then
            RequestModel(currentVehicleHash)
            while HasModelLoaded(currentVehicleHash) == false do
                Citizen.Wait(0)
            end
            vehicle = putPedInVehicle(player, currentVehicleHash, coord)
            SetEntityAsNoLongerNeeded(vehicle)
            for _, passenger in pairs(passengers) do
                SetPedIntoVehicle(passenger.ped, vehicle, passenger.seat)
            end
        end
    else
        sendMessage("Cannot respawn.  Not in a race.\n")
    end
end

local function viewResults(chatOnly)
    local msg = nil
    if #results > 0 then
        -- results[] = {source, playerName, finishTime, bestLapTime, vehicleName}
        msg = "Race results:\n"
        for pos, result in ipairs(results) do
            if -1 == result.finishTime then
                msg = msg .. "DNF - " .. result.playerName
                if result.bestLapTime >= 0 then
                    local minutes, seconds = minutesSeconds(result.bestLapTime)
                    msg = msg .. (" - best lap %02d:%05.2f using %s"):format(minutes, seconds, result.vehicleName)
                end
                msg = msg .. "\n"
            else
                local fMinutes, fSeconds = minutesSeconds(result.finishTime)
                local lMinutes, lSeconds = minutesSeconds(result.bestLapTime)
                msg = msg .. ("%d - %02d:%05.2f - %s - best lap %02d:%05.2f using %s\n"):format(pos, fMinutes, fSeconds, result.playerName, lMinutes, lSeconds, result.vehicleName)
            end
        end
    else
        msg = "No results.\n"
    end
    if true == chatOnly then
        notifyPlayer(msg)
    else
        sendMessage(msg)
    end
end

local function spawn(vehicleHash)
    if 0 == roleBits & ROLE_SPAWN then
        sendMessage("Permission required.\n")
        return
    end
    vehicleHash = vehicleHash or "t20"
    if IsModelInCdimage(vehicleHash) == 1 and IsModelAVehicle(vehicleHash) == 1 then
        RequestModel(vehicleHash)
        while HasModelLoaded(vehicleHash) == false do
            Citizen.Wait(0)
        end
        local vehicle = putPedInVehicle(PlayerPedId(), vehicleHash, nil)
        SetEntityAsNoLongerNeeded(vehicle)

        sendMessage("'" .. GetLabelText(GetDisplayNameFromVehicleModel(vehicleHash)) .. "' spawned.\n")
    else
        sendMessage("Cannot spawn vehicle.  Invalid vehicle.\n")
    end
end

local function lvehicles(vclass)
    vclass = math.tointeger(tonumber(vclass))
    if nil == vclass or (vclass >= 0 and vclass <= 22) then
        TriggerServerEvent("races:lvehicles", vclass)
    else
        sendMessage("Cannot list vehicles.  Invalid vehicle class.\n")
    end
end

local function setSpeedo(unit)
    if unit ~= nil then
        if "imperial" == unit then
            unitom = "imperial"
            sendMessage("Unit of measurement changed to Imperial.\n")
        elseif "metric" == unit then
            unitom = "metric"
            sendMessage("Unit of measurement changed to Metric.\n")
        else
            sendMessage("Invalid unit of measurement.\n")
        end
    else
        speedo = not speedo
        if true == speedo then
            sendMessage("Speedometer enabled.\n")
        else
            sendMessage("Speedometer disabled.\n")
        end
    end
end

local function viewFunds()
    TriggerServerEvent("races:funds")
end

local function saveVehicleProperties()
    local player = PlayerPedId()
    if IsPedInAnyVehicle(player, false) == 1 then
        rememberedVehicle = getVehicleProperties(GetVehiclePedIsUsing(player))
        sendMessage("The properties of the vehicle have been remembered.")
    else
        rememberedVehicle = nil
        sendMessage("You must be in a vehicle, the properties of the vehicle have been deleted from the memory.")
    end
end

local function loadVehicleProperties()
    if rememberedVehicle ~= nil then
        local player = PlayerPedId()
        if IsPedInAnyVehicle(player, false) == 1 then
            setVehicleProperties(GetVehiclePedIsUsing(PlayerPedId()), rememberedVehicle)
            sendMessage("The properties of the vehicle have been replaced with remembered.")
        else
            sendMessage("You must be in a vehicle.")
        end
    else
        sendMessage("At first you have to remember the properties of any vehicle.")
    end
end

local function changeDrivingStyle(dstyle)
    local dstyle = math.tointeger(tonumber(dstyle))
    if dstyle ~= nil and dstyle >= 0 and dstyle <= 2147483647 then
        drivingStyle = dstyle
        sendMessage("Driving style have been changed to: " .. dstyle .. ".")
    elseif dstyle == nil then
        drivingStyle = 1076625980
        sendMessage("Driving style have been changed to defaults: 1076625980.")
    else
        sendMessage("Invalid value of driving style.")
    end
end

local function showPanel(panel)
    panelShown = true
    if nil == panel or "register" == panel then
        SetNuiFocus(true, true)
        TriggerServerEvent("races:trackNames", false)
        TriggerServerEvent("races:trackNames", true)
        TriggerServerEvent("races:aiGrpNames", false)
        TriggerServerEvent("races:aiGrpNames", true)
        SendNUIMessage({
            panel = "register",
            defaultBuyin = defaultBuyin,
            defaultLaps = defaultLaps,
            defaultTimeout = defaultTimeout,
            defaultDelay = defaultDelay,
            defaultVehicle = defaultVehicle
        })
    elseif "edit" == panel then
        SetNuiFocus(true, true)
        TriggerServerEvent("races:trackNames", false)
        TriggerServerEvent("races:trackNames", true)
        SendNUIMessage({
            panel = "edit"
        })
    elseif "support" == panel then
        SetNuiFocus(true, true)
        TriggerServerEvent("races:trackNames", false)
        TriggerServerEvent("races:trackNames", true)
        SendNUIMessage({
            panel = "support"
        })
    else
        notifyPlayer("Invalid panel.\n")
        panelShown = false
    end
end

RegisterNUICallback("request", function(data)
    request(data.role)
end)

RegisterNUICallback("edit", function()
    edit()
end)

RegisterNUICallback("clear", function()
    clear()
end)

RegisterNUICallback("reverse", function()
    reverse()
end)

RegisterNUICallback("load", function(data)
    local trackName = data.trackName
    if "" == trackName then
        trackName = nil
    end
    loadTrack(data.access, trackName)
end)

RegisterNUICallback("save", function(data)
    local trackName = data.trackName
    if "" == trackName then
        trackName = nil
    end
    saveTrack(data.access, trackName)
end)

RegisterNUICallback("overwrite", function(data)
    local trackName = data.trackName
    if "" == trackName then
        trackName = nil
    end
    overwriteTrack(data.access, trackName)
end)

RegisterNUICallback("delete", function(data)
    local trackName = data.trackName
    if "" == trackName then
        trackName = nil
    end
    deleteTrack(data.access, trackName)
end)

RegisterNUICallback("blt", function(data)
    local trackName = data.trackName
    if "" == trackName then
        trackName = nil
    end
    bestLapTimes(data.access, trackName)
end)

RegisterNUICallback("list", function(data)
    list(data.access)
end)

RegisterNUICallback("register", function(data)
    local buyin = data.buyin
    if "" == buyin then
        buyin = nil
    end
    local laps = data.laps
    if "" == laps then
        laps = nil
    end
    local timeout = data.timeout
    if "" == timeout then
        timeout = nil
    end
    local allowAI = data.allowAI
    local rtype = data.rtype
    if "norm" == rtype then
        rtype = nil
    end
    local restrict = data.restrict
    if "" == restrict then
        restrict = nil
    end
    local filename = data.filename
    if "" == filename then
        filename = nil
    end
    local vclass = data.vclass
    if "-2" == vclass then
        vclass = nil
    end
    local svehicle = data.svehicle
    if "" == svehicle then
        svehicle = nil
    end
    if nil == rtype then
        register(buyin, laps, timeout, allowAI, rtype, nil, nil, nil)
    elseif "rest" == rtype then
        register(buyin, laps, timeout, allowAI, rtype, restrict, nil, nil)
    elseif "class" == rtype then
        register(buyin, laps, timeout, allowAI, rtype, vclass, filename, nil)
    elseif "rand" == rtype then
        register(buyin, laps, timeout, allowAI, rtype, filename, vclass, svehicle)
    end
end)

RegisterNUICallback("unregister", function()
    unregister()
end)

RegisterNUICallback("start", function(data)
    local delay = data.delay
    if "" == delay then
        delay = nil
    end
    startRace(delay)
end)

RegisterNUICallback("spawn_ai", function(data)
    local aiName = data.aiName
    if "" == aiName then
        aiName = nil
    end
    local player = PlayerPedId()
    local vehicle = data.vehicle
    if "" == vehicle then
        vehicle = nil
    end
    local ped = data.ped
    if "" == ped then
        ped = nil
    end
    if vehicle == nil or ped == nil then
        if vehicle == nil and ped == nil then
            spawnAIDriver(aiName, nil, nil, GetEntityCoords(player), GetEntityHeading(player))
        else if vehicle ~= nil and ped == nil then
            spawnAIDriver(aiName, GetHashKey(vehicle), nil), GetEntityCoords(player), GetEntityHeading(player))
        else
            spawnAIDriver(aiName, nil, GetHashKey(ped), GetEntityCoords(player), GetEntityHeading(player))
        end
    else
        spawnAIDriver(aiName, GetHashKey(vehicle), GetHashKey(ped), GetEntityCoords(player), GetEntityHeading(player))
    end
end)

RegisterNUICallback("delete_ai", function(data)
    local aiName = data.aiName
    if "" == aiName then
        aiName = nil
    end
    deleteAIDriver(aiName)
end)

RegisterNUICallback("list_ai", function()
    listAIDrivers()
end)

RegisterNUICallback("load_grp", function(data)
    local name = data.name
    if "" == name then
        name = nil
    end
    loadGrp(data.access, name)
end)

RegisterNUICallback("save_grp", function(data)
    local name = data.name
    if "" == name then
        name = nil
    end
    saveGrp(data.access, name)
end)

RegisterNUICallback("overwrite_grp", function(data)
    local name = data.name
    if "" == name then
        name = nil
    end
    overwriteGrp(data.access, name)
end)

RegisterNUICallback("delete_grp", function(data)
    local name = data.name
    if "" == name then
        name = nil
    end
    deleteGrp(data.access, name)
end)

RegisterNUICallback("list_grp", function(data)
    listGrp(data.access)
end)

RegisterNUICallback("leave", function()
    leave()
end)

RegisterNUICallback("rivals", function()
    rivals()
end)

RegisterNUICallback("respawn", function()
    respawn()
end)

RegisterNUICallback("results", function()
    viewResults(false)
end)

RegisterNUICallback("spawn", function(data)
    local vehicle = data.vehicle
    if "" == vehicle then
        vehicle = nil
    end
    spawn(vehicle)
end)

RegisterNUICallback("lvehicles", function(data)
    local vclass = data.vclass
    if "-1" == vclass then
        vclass = nil
    end
    lvehicles(vclass)
end)

RegisterNUICallback("speedo", function(data)
    local unit = data.unit
    if "" == unit then
        unit = nil
    end
    setSpeedo(unit)
end)

RegisterNUICallback("funds", function()
    viewFunds()
end)

RegisterNUICallback("savep", function()
    saveVehicleProperties()
end)

RegisterNUICallback("loadp", function()
    loadVehicleProperties()
end)

RegisterNUICallback("change_dstyle", function(data)
    local dstyle = data.dstyle
    if "" == dstyle then
        dstyle = nil
    end
    changeDrivingStyle(dstyle)
end)

RegisterNUICallback("show", function(data)
    local panel = data.panel
    if "register" == panel then
        panel = nil
    end
    showPanel(panel)
end)

RegisterNUICallback("close", function()
    panelShown = false
    SetNuiFocus(false, false)
end)

--[[
local function testSound(audioRef, audioName)
    PlaySoundFrontend(-1, audioName, audioRef, true)
end

local function testCheckpoint(cptype)
    local playerCoord = GetEntityCoords(PlayerPedId())
    local coord = {x = playerCoord.x, y = playerCoord.y, z = playerCoord.z, r = 5.0}
    local checkpoint = makeCheckpoint(tonumber(cptype), coord, coord, green, 125, 5)
end

RegisterNetEvent("sounds")
AddEventHandler("sounds", function(sounds)
    print("start")
    for _, sound in pairs(sounds) do
        print(sound.ref .. ":" .. sound.name)
        if
            fail == string.find(sound.name, "Loop") and
            fail == string.find(sound.name, "Background") and
            sound.name ~= "Pin_Movement" and
            sound.name ~= "WIND" and
            sound.name ~= "Trail_Custom" and
            sound.name ~= "Altitude_Warning" and
            sound.name ~= "OPENING" and
            sound.name ~= "CONTINUOUS_SLIDER" and
            sound.name ~= "SwitchWhiteWarning" and
            sound.name ~= "SwitchRedWarning" and
            sound.name ~= "ZOOM" and
            sound.name ~= "Microphone" and
            sound.ref ~= "MP_CCTV_SOUNDSET" and
            sound.ref ~= "SHORT_PLAYER_SWITCH_SOUND_SET"
        then
            testSound(sound.ref, sound.name)
        else
            print("------------" .. sound.name)
        end
        Citizen.Wait(1000)
    end
    print("done")
end)

RegisterNetEvent("vehicles")
AddEventHandler("vehicles", function(vehicleList)
    local unknown = {}
    local classes = {}
    local maxName = nil
    local maxLen = 0
    local minName = nil
    local minLen = 0
    for _, vehicle in ipairs(vehicleList) do
        if IsModelInCdimage(vehicle) ~= 1 or IsModelAVehicle(vehicle) ~= 1 then
            unknown[#unknown + 1] = vehicle
        else
            print(vehicle .. ":" .. GetVehicleModelNumberOfSeats(vehicle))
            local class = getVehicleClassFromName(vehicle)
            if nil == classes[class] then
                classes[class] = 1
            else
                classes[class] = classes[class] + 1
            end
            local name = GetLabelText(GetDisplayNameFromVehicleModel(vehicle))
            local len = string.len(name)
            if len > maxLen then
                maxName = vehicle .. ":" .. name
                maxLen = len
            elseif 0 == minLen or len < minLen then
                minName = vehicle .. ":" .. name
                minLen = len
            end
        end
    end
    local classNum = {}
    for class in pairs(classes) do
        classNum[#classNum + 1] = class
    end
    table.sort(classNum)
    for _, class in pairs(classNum) do
        print(class .. ":" .. classes[class])
    end
    TriggerServerEvent("unk", unknown)
    print(maxLen .. ":" .. maxName)
    print(minLen .. ":" .. minName)

    for vclass = 0, 22 do
        local vehicles = {}
        for _, vehicle in ipairs(vehicleList) do
            if IsModelInCdimage(vehicle) == 1 and IsModelAVehicle(vehicle) == 1 then
                if getVehicleClassFromName(vehicle) == vclass then
                    vehicles[#vehicles + 1] = vehicle
                end
            end
        end
        TriggerServerEvent("veh", vclass, vehicles)
    end
end)
--]]

RegisterCommand("race", function(_, args)
    if nil == args[1] then
        local msg = "Commands:\n"
        msg = msg .. "Required arguments are in square brackets.  Optional arguments are in parentheses.\n"
        msg = msg .. "/race - display list of available /race commands\n"
        msg = msg .. "/race request [role] - request permission to have [role] = {edit, register, spawn} role\n"
        msg = msg .. "/race edit - toggle editing track waypoints\n"
        msg = msg .. "/race clear - clear track waypoints\n"
        msg = msg .. "/race reverse - reverse order of track waypoints\n"
        msg = msg .. "\n"
        msg = msg .. "For the following **`/race`** commands, [access] = {'pvt', 'pub'} where 'pvt' operates on a private track and 'pub' operates on a public track\n"
        msg = msg .. "/race load [access] [name] - load private or public track saved as [name]\n"
        msg = msg .. "/race save [access] [name] - save new private or public track as [name]\n"
        msg = msg .. "/race overwrite [access] [name] - overwrite existing private or public track saved as [name]\n"
        msg = msg .. "/race delete [access] [name] - delete private or public track saved as [name]\n"
        msg = msg .. "/race blt [access] [name] - list 10 best lap times of private or public track saved as [name]\n"
        msg = msg .. "/race list [access] - list saved private or public tracks\n"
        msg = msg .. "\n"
        msg = msg .. "For the following '/races register' commands, (buy-in) defaults to 0, (laps) defaults to 1 lap, (DNF timeout) defaults to 300 seconds and (allow AI) = {yes, no} defaults to no\n"
        msg = msg .. "/race register (buy-in) (laps) (DNF timeout) (allow AI) - register your race with no vehicle restrictions\n"
        msg = msg .. "/race register (buy-in) (laps) (DNF timeout) (allow AI) rest [vehicle] - register your race restricted to [vehicle]\n"
        msg = msg .. "/race register (buy-in) (laps) (DNF timeout) (allow AI) class [class] (filename) - register your race restricted to vehicles of type [class]; if [class] is '-1' then use vehicles in (filename) file\n"
        msg = msg .. "/race register (buy-in) (laps) (DNF timeout) (allow AI) rand (filename) (class) (vehicle) - register your race changing vehicles randomly every lap; (filename) defaults to 'random.txt'; (class) defaults to any; (vehicle) defaults to any\n"
        msg = msg .. "\n"
        msg = msg .. "/race unregister - unregister your race\n"
        msg = msg .. "/race start (delay) - start your registered race; (delay) defaults to 10 seconds\n"
        msg = msg .. "/race ai spawn [name] (vehicle) (ped) - Spawn AI driver named [name] in (vehicle) for the (ped); (vehicle) defaults to 't20', (ped) defaults to 'a_f_y_beach_01'\n"
        msg = msg .. "/race ai delete (name) - Delete an AI driver named (name); otherwise delete all AI drivers if (name) is not specified\n"
        msg = msg .. "/race ai list - List AI driver names\n"
        msg = msg .. "\n"
        msg = msg .. "For the following **`/race ai`** commands, [access] = {'pvt', 'pub'} where 'pvt' operates on a private AI group and 'pub' operates on a public AI group\n"
        msg = msg .. "/races ai loadGrp [access] [name] - load private or public AI group saved as [name]\n"
        msg = msg .. "/races ai saveGrp [access] [name] - save new private or public AI group as [name]\n"
        msg = msg .. "/races ai overwriteGrp [access] [name] - overwrite existing private or public AI group saved as [name]\n"
        msg = msg .. "/races ai deleteGrp [access] [name] - delete private or public AI group saved as [name]\n"
        msg = msg .. "/races ai listGrp [access] - list saved private or public AI groups\n"
        msg = msg .. "\n"
        msg = msg .. "/race leave - leave a race that you joined\n"
        msg = msg .. "/race rivals - list competitors in a race that you joined\n"
        msg = msg .. "/race respawn - respawn at last waypoint\n"
        msg = msg .. "/race results - view latest race results\n"
        msg = msg .. "/race spawn (vehicle) - spawn a vehicle; (vehicle) defaults to 't20'\n"
        msg = msg .. "/race lvehicles (class) - list available vehicles of type (class); otherwise list all available vehicles if (class) is not specified\n"
        msg = msg .. "/race speedo (unit) - change unit of speed measurement to (unit) = {imp, met}; otherwise toggle display of speedometer if (unit) is not specified\n"
        msg = msg .. "/race funds - view available funds\n"
        msg = msg .. "/race savep - save the tuning of the vehicle in which the player is in memory\n"
        msg = msg .. "/race loadp - replace the current vehicle tuning with tuning from memory\n"
        msg = msg .. "/race dstyle (style number) - change the driving style of bots (number from 0 to 2147483647) https://vespura.com/fivem/drivingstyle/\n"
        msg = msg .. "/race panel (panel) - display (panel) = {edit, support} panel; otherwise display register panel if (panel) is not specified\n"
        notifyPlayer(msg)
    elseif "request" == args[1] then
        request(args[2])
    elseif "edit" == args[1] then
        edit()
    elseif "clear" == args[1] then
        clear()
    elseif "reverse" == args[1] then
        reverse()
    elseif "load" == args[1] then
        loadTrack(args[2], args[3])
    elseif "save" == args[1] then
        saveTrack(args[2], args[3])
    elseif "overwrite" == args[1] then
        overwriteTrack(args[2], args[3])
    elseif "delete" == args[1] then
        deleteTrack(args[2], args[3])
    elseif "blt" == args[1] then
        bestLapTimes(args[2], args[3])
    elseif "list" == args[1] then
        list(args[2])
    elseif "register" == args[1] then
        register(args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9])
    elseif "unregister" == args[1] then
        unregister()
    elseif "start" == args[1] then
        startRace(args[2])
    elseif "ai" == args[1] then
        if "spawn" == args[2] then
            local player = PlayerPedId()
            if args[4] == nil or args[5] == nil then
                if args[4] == nil and args[5] == nil then
                    spawnAIDriver(args[3], nil, nil, GetEntityCoords(player), GetEntityHeading(player))
                else if args[4] ~= nil and args[5] == nil then
                    spawnAIDriver(args[3], GetHashKey(args[4]), nil, GetEntityCoords(player), GetEntityHeading(player))
                else
                    spawnAIDriver(args[3], nil, GetHashKey(args[5]), GetEntityCoords(player), GetEntityHeading(player))
                end
            else
                spawnAIDriver(args[3], GetHashKey(args[4]), GetHashKey(args[5]), GetEntityCoords(player), GetEntityHeading(player))
            end
        elseif "delete" == args[2] then
            deleteAIDriver(args[3])
        elseif "list" == args[2] then
            listAIDrivers()
        elseif "loadGrp" == args[2] then
            loadGrp(args[3], args[4])
        elseif "saveGrp" == args[2] then
            saveGrp(args[3], args[4])
        elseif "overwriteGrp" == args[2] then
            overwriteGrp(args[3], args[4])
        elseif "deleteGrp" == args[2] then
            deleteGrp(args[3], args[4])
        elseif "listGrp" == args[2] then
            listGrp(args[3])
        else
            notifyPlayer("Unknown AI command.\n")
        end
    elseif "leave" == args[1] then
        leave()
    elseif "rivals" == args[1] then
        rivals()
    elseif "respawn" == args[1] then
        respawn()
    elseif "results" == args[1] then
        viewResults(true)
    elseif "spawn" == args[1] then
        spawn(args[2])
    elseif "lvehicles" == args[1] then
        lvehicles(args[2])
    elseif "speedo" == args[1] then
        setSpeedo(args[2])
    elseif "funds" == args[1] then
        viewFunds()
    elseif "savep" == args[1] then
        saveVehicleProperties()
    elseif "loadp" == args[1] then
        loadVehicleProperties()
    elseif "dstyle" == args[1] then
        changeDrivingStyle(args[2])
    elseif "panel" == args[1] then
        showPanel(args[2])
--[[
    elseif "test" == args[1] then
        if "0" == args[2] then
            TriggerEvent("races:finish", GetPlayerServerId(PlayerId()), "John Doe", (5 * 60 + 24) * 1000, (1 * 60 + 32) * 1000, "Duck")
        elseif "1" == args[2] then
            testCheckpoint(args[3])
        elseif "2" == args[2] then
            testSound(args[3], args[4])
        elseif "3" == args[2] then
            TriggerServerEvent("sounds0")
        elseif "4" == args[2] then
            TriggerServerEvent("sounds1")
        elseif "5" == args[2] then
            TriggerServerEvent("vehicles")
        end
--]]
    else
        notifyPlayer("Unknown command.\n")
    end
end)

RegisterNetEvent("races:roles")
AddEventHandler("races:roles", function(roles)
    if 0 == roles & ROLE_EDIT and STATE_EDITING == raceState then
        roleBits = roleBits | ROLE_EDIT
        edit()
    end
    roleBits = roles
end)

RegisterNetEvent("races:message")
AddEventHandler("races:message", function(msg)
    sendMessage(msg)
end)

RegisterNetEvent("races:load")
AddEventHandler("races:load", function(isPublic, trackName, waypointCoords)
    if isPublic ~= nil and trackName ~= nil and waypointCoords ~= nil then
        if STATE_IDLE == raceState then
            isPublicTrack = isPublic
            savedTrackName = trackName
            loadWaypointBlips(waypointCoords)
            sendMessage("Loaded " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
        elseif STATE_EDITING == raceState then
            isPublicTrack = isPublic
            savedTrackName = trackName
            highlightedCheckpoint = 0
            selectedWaypoint = 0
            lastSelectedWaypoint = 0
            deleteWaypointCheckpoints()
            loadWaypointBlips(waypointCoords)
            setStartToFinishCheckpoints()
            sendMessage("Loaded " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
        else
            notifyPlayer("Ignoring load event.  Currently joined to race.\n")
        end
    else
        notifyPlayer("Ignoring load event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:save")
AddEventHandler("races:save", function(isPublic, trackName)
    if isPublic ~= nil and trackName ~= nil then
        isPublicTrack = isPublic
        savedTrackName = trackName
        if true == panelShown then
            TriggerServerEvent("races:trackNames", isPublic)
        end
        sendMessage("Saved " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
    else
        notifyPlayer("Ignoring save event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:overwrite")
AddEventHandler("races:overwrite", function(isPublic, trackName)
    if isPublic ~= nil and trackName ~= nil then
        isPublicTrack = isPublic
        savedTrackName = trackName
        sendMessage("Overwrote " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
    else
        notifyPlayer("Ignoring overwrite event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:delete")
AddEventHandler("races:delete", function(isPublic)
    if true == panelShown then
        TriggerServerEvent("races:trackNames", isPublic)
    end
end)

RegisterNetEvent("races:blt")
AddEventHandler("races:blt", function(isPublic, trackName, bestLaps)
    if isPublic ~= nil and trackName ~=nil and bestLaps ~= nil then
        local msg = (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'"
        if #bestLaps > 0 then
            msg = "Best lap times for " .. msg .. ":\n"
            for pos, bestLap in ipairs(bestLaps) do
                local minutes, seconds = minutesSeconds(bestLap.bestLapTime)
                msg = msg .. ("%d - %s - %02d:%05.2f using %s\n"):format(pos, bestLap.playerName, minutes, seconds, bestLap.vehicleName)
            end
            sendMessage(msg)
        else
            sendMessage("No best lap times for " .. msg .. ".\n")
        end
    else
        notifyPlayer("Ignoring best lap times event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:register")
AddEventHandler("races:register", function(rIndex, coord, isPublic, trackName, owner, buyin, laps, timeout, allowAI, vehicleList, rdata)
    if rIndex ~= nil and coord ~= nil and isPublic ~= nil and owner ~= nil and buyin ~= nil and laps ~=nil and timeout ~= nil and allowAI ~= nil and vehicleList ~= nil and rdata ~= nil then
        local blip = AddBlipForCoord(coord.x, coord.y, coord.z) -- registration blip
        SetBlipSprite(blip, registerSprite)
        SetBlipColour(blip, registerBlipColor)
        BeginTextCommandSetBlipName("STRING")
        local msg = owner .. " (" .. buyin .. " buy-in"
        if "yes" == allowAI then
            msg = msg .. " : AI allowed"
        end
        if "rest" == rdata.rtype then
            msg = msg .. " : using '" .. rdata.restrict .. "' vehicle"
        elseif "class" == rdata.rtype then
            msg = msg .. " : using " .. getClassName(rdata.vclass) .. " vehicle class"
        elseif "rand" == rdata.rtype then
            msg = msg .. " : using random "
            if rdata.vclass ~= nil then
                msg = msg .. getClassName(rdata.vclass) .. " vehicle class"
            else
                msg = msg .. "vehicles"
            end
            if rdata.svehicle ~= nil then
                msg = msg .. " : '" .. rdata.svehicle .. "'"
            end
        end
        msg = msg .. ")"
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandSetBlipName(blip)

        coord.r = defaultRadius
        local checkpoint = makeCheckpoint(plainCheckpoint, coord, coord, purple, 125, 0) -- registration checkpoint

        for i = 1, #vehicleList do
            while true do
                if vehicleList[i] ~= nil then
                    if IsModelInCdimage(vehicleList[i]) ~= 1 or IsModelAVehicle(vehicleList[i]) ~= 1 then
                        table.remove(vehicleList, i)
                    else
                        break
                    end
                else
                    break
                end
            end
        end

        starts[rIndex] = {
            isPublic = isPublic,
            trackName = trackName,
            owner = owner,
            buyin = buyin,
            laps = laps,
            timeout = timeout,
            allowAI = allowAI,
            rtype = rdata.rtype,
            restrict = rdata.restrict,
            vclass = rdata.vclass,
            svehicle = rdata.svehicle,
            vehicleList = vehicleList,
            blip = blip,
            checkpoint = checkpoint
        }
    else
        notifyPlayer("Ignoring register event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:unregister")
AddEventHandler("races:unregister", function(rIndex)
    if rIndex ~= nil then
        if starts[rIndex] ~= nil then
            removeRegistrationPoint(rIndex)
        end
        if rIndex == raceIndex then
            if STATE_JOINING == raceState then
                raceState = STATE_IDLE
                removeRacerBlips()
                notifyPlayer("Race canceled.\n")
            elseif STATE_RACING == raceState then
                raceState = STATE_IDLE
                DeleteCheckpoint(raceCheckpoint)
                restoreBlips()
                SetBlipRoute(waypoints[1].blip, true)
                SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
                speedo = false
                removeRacerBlips()
                RenderScriptCams(false, false, 0, true, true)
                local player = PlayerPedId()
                if IsPedInAnyVehicle(player, false) == 1 then
                    FreezeEntityPosition(GetVehiclePedIsIn(player, false), false)
                end
                if #randVehicles > 0 then
                    local vehicle = switchVehicle(player, originalVehicleHash)
                    if vehicle ~= nil then
                        setVehicleProperties(vehicle, rememberedVehicleProps)
                    end
                end
                notifyPlayer("Race canceled.\n")
            end
        end
        if aiState ~= nil and GetPlayerServerId(PlayerId()) == rIndex then
            for _, driver in pairs(aiState.drivers) do
                --switchVehicle(driver.ped, originalVehicleHash)
                if driver.ped ~= nil then
                    SetEntityAsNoLongerNeeded(driver.ped)
                end
                if driver.vehicle ~= nil then
                    SetEntityAsNoLongerNeeded(driver.vehicle)
                end
            end
            aiState = nil
        end
    else
        notifyPlayer("Ignoring unregister event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:loadGrp")
AddEventHandler("races:loadGrp", function(isPublic, name, group)
    if isPublic ~= nil and name ~= nil and group ~= nil then
        local loaded = true
        if deleteAIDriver(nil) == true then
            -- group[aiName] = {startCoord = {x, y, z}, heading, vehicleHash}
            for aiName, driver in pairs(group) do
                if spawnAIDriver(aiName, driver.vehicleHash, driver.pedHash, driver.startCoord, driver.heading) == false then
                    loaded = false
                    break
                end
                setVehicleProperties(aiState.drivers[aiName].vehicle, driver.vehicleProps)
                setPedProperties(aiState.drivers[aiName].ped, driver.pedProps)
            end
        else
            loaded = false
        end
        if true == loaded then
            sendMessage("AI group '" .. name .. "' loaded.\n")
        else
            sendMessage("Could not load AI group.\n")
        end
    else
        notifyPlayer("Ignoring load AI group event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:updateGrp")
AddEventHandler("races:updateGrp", function(isPublic)
    if true == panelShown then
        TriggerServerEvent("races:aiGrpNames", isPublic)
    end
end)

RegisterNetEvent("races:lvehicles")
AddEventHandler("races:lvehicles", function(vehicleList, vclass)
    if vehicleList ~= nil then
        local msg = "Available vehicles"
        if nil == vclass then
            msg = msg .. ": "
        else
            msg = msg .. " of class " .. getClassName(vclass) .. ": "
        end
        local vehicleFound = false
        for _, vehicle in pairs(vehicleList) do
            if IsModelInCdimage(vehicle) == 1 and IsModelAVehicle(vehicle) == 1 then
                if nil == vclass or getVehicleClassFromName(vehicle) == vclass then
                    msg = msg .. vehicle .. ", "
                    vehicleFound = true
                end
            end
        end
        if false == vehicleFound then
            msg = "No vehicles in list."
        else
            msg = string.sub(msg, 1, -3)
        end
        sendMessage(msg)
    else
        notifyPlayer("Ignoring list vehicles event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:start")
AddEventHandler("races:start", function(rIndex, delay)
    if rIndex ~= nil and delay ~= nil then
        if delay >= 5 then
            local currentTime = GetGameTimer()
            -- SCENARIO:
            -- 1. player registers ai race
            -- 2. player adds ai
            -- 3. player does not join race they registered
            -- 4. player starts registered race -- receives start event
            -- player should not start in race they registered since they did not join
            if rIndex == raceIndex then
                if STATE_JOINING == raceState then
                    raceStart = currentTime
                    raceDelay = delay
                    beginDNFTimeout = false
                    timeoutStart = -1
                    started = false
                    currentVehicleHash = nil
                    currentVehicleName = "FEET"
                    position = -1
                    numWaypointsPassed = 0
                    currentLap = 1
                    bestLapTime = -1
                    bestLapVehicleName = currentVehicleName
                    countdown = 5
                    drawLights = false
                    numRacers = -1
                    results = {}
                    speedo = true
                    startCoord = GetEntityCoords(PlayerPedId())
                    camTransStarted = false

                    if startVehicle ~= nil then
                        local vehicle = switchVehicle(PlayerPedId(), startVehicle)
                        if vehicle ~= nil then
                            SetEntityAsNoLongerNeeded(vehicle)
                        end
                    end

                    numVisible = maxNumVisible < #waypoints and maxNumVisible or (#waypoints - 1)
                    for i = numVisible + 1, #waypoints do
                        SetBlipDisplay(waypoints[i].blip, 0)
                    end

                    currentWaypoint = true == startIsFinish and 0 or 1

                    waypointCoord = waypoints[1].coord
                    raceCheckpoint = makeCheckpoint(arrow3Checkpoint, waypointCoord, waypoints[2].coord, green, 125, 0)

                    SetBlipRoute(waypointCoord, true)
                    SetBlipRouteColour(waypointCoord, blipRouteColor)

                    raceState = STATE_RACING
                elseif STATE_RACING == raceState then
                    notifyPlayer("Ignoring start event.  Already in a race.\n")
                elseif STATE_EDITING == raceState then
                    notifyPlayer("Ignoring start event.  Currently editing.\n")
                else
                    notifyPlayer("Ignoring start event.  Currently idle.\n")
                end
            end

            -- SCENARIO:
            -- 1. player registers ai race
            -- 2. player adds ai
            -- 3. player joins another race
            -- 4. joined race starts -- receives start event from joined race
            -- do not trigger start event for ai's in player's registered race
            -- only trigger start event for ai's if player started their registered race
            if aiState ~= nil and GetPlayerServerId(PlayerId()) == rIndex then
                aiState.raceStart = currentTime
                aiState.raceDelay = delay
                for _, driver in pairs(aiState.drivers) do
                    if aiState.svehicle ~= nil then
                        driver.vehicle = switchVehicle(driver.ped, aiState.svehicle)
                    end
                    driver.raceState = STATE_RACING
                end
            end
        else
            notifyPlayer("Ignoring start event.  Invalid delay.\n")
        end
    else
        notifyPlayer("Ignoring start event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:hide")
AddEventHandler("races:hide", function(rIndex)
    if rIndex ~= nil then
        if starts[rIndex] ~= nil then
            removeRegistrationPoint(rIndex)
        else
            notifyPlayer("Ignoring hide event.  Race does not exist.\n")
        end
    else
        notifyPlayer("Ignoring hide event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:join")
AddEventHandler("races:join", function(rIndex, aiName, waypointCoords)
    if rIndex ~= nil and waypointCoords ~= nil then
        if starts[rIndex] ~= nil then
            if nil == aiName then
                if STATE_IDLE == raceState then
                    raceState = STATE_JOINING
                    raceIndex = rIndex
                    numLaps = starts[rIndex].laps
                    DNFTimeout = starts[rIndex].timeout * 1000
                    restrictedHash = nil
                    restrictedClass = starts[rIndex].vclass
                    customClassVehicleList = {}
                    startVehicle = starts[rIndex].svehicle
                    randVehicles = {}
                    loadWaypointBlips(waypointCoords)
                    local msg = "Joined race using "
                    if nil == starts[rIndex].trackName then
                        msg = msg .. "unsaved track "
                    else
                        msg = msg .. (true == starts[rIndex].isPublic and "publicly" or "privately") .. " saved track '" .. starts[rIndex].trackName .. "' "
                    end
                    msg = msg .. ("registered by %s : %d buy-in : %d lap(s)"):format(starts[rIndex].owner, starts[rIndex].buyin, starts[rIndex].laps)
                    if "yes" == starts[rIndex].allowAI then
                        msg = msg .. " : AI allowed"
                    end
                    if "rest" == starts[rIndex].rtype then
                        msg = msg .. " : using '" .. starts[rIndex].restrict .. "' vehicle"
                        restrictedHash = GetHashKey(starts[rIndex].restrict)
                    elseif "class" == starts[rIndex].rtype then
                        msg = msg .. " : using " .. getClassName(restrictedClass) .. " vehicle class"
                        customClassVehicleList = starts[rIndex].vehicleList
                    elseif "rand" == starts[rIndex].rtype then
                        msg = msg .. " : using random "
                        if restrictedClass ~= nil then
                            msg = msg .. getClassName(restrictedClass) .. " vehicle class"
                        else
                            msg = msg .. "vehicles"
                        end
                        if startVehicle ~= nil then
                            msg = msg .. " : '" .. startVehicle .. "'"
                        end
                        for _, vehName in pairs(starts[rIndex].vehicleList) do
                            if nil == restrictedClass or getVehicleClassFromName(vehName) == restrictedClass then
                                randVehicles[#randVehicles + 1] = vehName
                            end
                        end
                        if #randVehicles == 0 then
                            msg = msg .. " : No random vehicles loaded"
                        end
                    end
                    msg = msg .. ".\n"
                    notifyPlayer(msg)
                elseif STATE_EDITING == raceState then
                    notifyPlayer("Ignoring join event.  Currently editing.\n")
                else
                    notifyPlayer("Ignoring join event.  Already joined to a race.\n")
                end
            elseif aiState ~= nil then
                local driver = aiState.drivers[aiName]
                if driver ~= nil then
                    if nil == aiState.waypointCoords then
                        aiState.waypointCoords = waypointCoords
                        aiState.startIsFinish =
                            waypointCoords[1].x == waypointCoords[#waypointCoords].x and
                            waypointCoords[1].y == waypointCoords[#waypointCoords].y and
                            waypointCoords[1].z == waypointCoords[#waypointCoords].z
                        if true == aiState.startIsFinish then
                            aiState.waypointCoords[#aiState.waypointCoords] = nil
                        end
                    end
                    driver.destCoord = aiState.waypointCoords[1]
                    driver.destSet = true
                    driver.currentWP = true == aiState.startIsFinish and 0 or 1
                    if "rand" == aiState.rtype then
                        for _, vehName in pairs(aiState.vehicleList) do
                            if nil == aiState.vclass or getVehicleClassFromName(vehName) == aiState.vclass then
                                aiState.randVehicles[#aiState.randVehicles + 1] = vehName
                            end
                        end
                    end
                    notifyPlayer("AI driver '" .. aiName .. "' joined race.\n")
                else
                    notifyPlayer("Ignoring join event.  '" .. aiName .. "' is not a valid AI driver.\n")
                end
            else
                notifyPlayer("Ignoring join event.  No AI drivers added.\n")
            end
        else
            notifyPlayer("Ignoring join event.  Race does not exist.\n")
        end
    else
        notifyPlayer("Ignoring join event.  Invalid parameters.\n")
    end
end)

-- SCENARIO:
-- 1. player finishes a race
-- 2. receives finish events from previous race because other players/AI finished
-- 3. player joins another race
-- 4. joined race starts
-- 5. receives finish event from previous race before current race
-- if accepting finish events from previous race, DNF timeout for current race may be started
-- only accept finish events from current race
-- do not accept finish events from previous race
RegisterNetEvent("races:finish")
AddEventHandler("races:finish", function(rIndex, playerName, raceFinishTime, raceBestLapTime, raceVehicleName)
    if rIndex ~= nil and playerName ~= nil and raceFinishTime ~= nil and raceBestLapTime ~= nil and raceVehicleName ~= nil then
        if rIndex == raceIndex then
            if -1 == raceFinishTime then
                if -1 == raceBestLapTime then
                    notifyPlayer(playerName .. " did not finish.\n")
                else
                    local minutes, seconds = minutesSeconds(raceBestLapTime)
                    notifyPlayer(("%s did not finish and had a best lap time of %02d:%05.2f using %s.\n"):format(playerName, minutes, seconds, raceVehicleName))
                end
            else
                local currentTime = GetGameTimer()
                if false == beginDNFTimeout then
                    beginDNFTimeout = true
                    timeoutStart = currentTime
                end
                if aiState ~= nil and false == aiState.beginDNFTimeout then
                    aiState.beginDNFTimeout = true
                    aiState.timeoutStart = currentTime
                end

                local fMinutes, fSeconds = minutesSeconds(raceFinishTime)
                local lMinutes, lSeconds = minutesSeconds(raceBestLapTime)
                notifyPlayer(("%s finished in %02d:%05.2f and had a best lap time of %02d:%05.2f using %s.\n"):format(playerName, fMinutes, fSeconds, lMinutes, lSeconds, raceVehicleName))
            end
        end
    else
        notifyPlayer("Ignoring finish event.  Invalid parameters.\n")
    end
end)

-- SCENARIO:
-- 1. player finishes a race
-- 2. doesn't receive results event because other players/AI have not finished
-- 3. player joins another race
-- 4. joined race starts
-- 5. receives results event from previous race before current race
-- only accept results event from current race
-- do not accept results event from previous race
RegisterNetEvent("races:results")
AddEventHandler("races:results", function(rIndex, raceResults)
    if rIndex ~= nil and raceResults ~= nil then
        if rIndex == raceIndex then
            results = raceResults
            viewResults(true)
        end
    else
        notifyPlayer("Ignoring results event.  Invalid parameters.\n")
    end
end)

-- SCENARIO:
-- 1. player finishes previous race
-- 2. still receiving position events from previous race because other players/AI have not finished
-- 3. player joins another race
-- 4. joined race started
-- receiving position events from previous race and joined race
-- only accept position events from joined race
-- do not accept position events from previous race
RegisterNetEvent("races:position")
AddEventHandler("races:position", function(rIndex, pos, numR)
    if rIndex ~= nil and pos ~= nil and numR ~= nil then
        if rIndex == raceIndex then
            position = pos
            numRacers = numR
        end
    else
        notifyPlayer("Ignoring position event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:addRacerBlip")
AddEventHandler("races:addRacerBlip", function(netID)
    if racerBlips[netID] ~= nil then
        RemoveBlip(racerBlips[netID])
    end
    local ped = NetToPed(netID)
    if DoesEntityExist(ped) == 1 then
        racerBlips[netID] = AddBlipForEntity(ped)
        SetBlipSprite(racerBlips[netID], racerSprite)
        SetBlipColour(racerBlips[netID], racerBlipColor)
    end
end)

RegisterNetEvent("races:delRacerBlip")
AddEventHandler("races:delRacerBlip", function(netID)
    if racerBlips[netID] ~= nil then
        RemoveBlip(racerBlips[netID])
        racerBlips[netID] = nil
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        if STATE_RACING == raceState then
            local player = PlayerPedId()
            local distance = #(GetEntityCoords(player) - vector3(waypointCoord.x, waypointCoord.y, waypointCoord.z))
            TriggerServerEvent("races:report", raceIndex, PedToNet(player), nil, numWaypointsPassed, distance)
        end

        if aiState ~= nil then
            for aiName, driver in pairs(aiState.drivers) do
                if STATE_RACING == driver.raceState then
                    local distance = #(GetEntityCoords(driver.ped) - vector3(driver.destCoord.x, driver.destCoord.y, driver.destCoord.z))
                    TriggerServerEvent("races:report", GetPlayerServerId(PlayerId()), driver.netID, aiName, driver.numWaypointsPassed, distance)
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local player = PlayerPedId()
        local playerCoord = GetEntityCoords(player)
        if STATE_EDITING == raceState then
            local closestIndex = 0
            local minDist = maxRadius
            for index, waypoint in ipairs(waypoints) do
                local dist = #(playerCoord - vector3(waypoint.coord.x, waypoint.coord.y, waypoint.coord.z))
                if dist < waypoint.coord.r and dist < minDist then
                    minDist = dist
                    closestIndex = index
                end
            end

            if closestIndex ~= 0 then
                if highlightedCheckpoint ~= 0 and closestIndex ~= highlightedCheckpoint then
                    local color = highlightedCheckpoint == selectedWaypoint and getCheckpointColor(selectedBlipColor) or getCheckpointColor(waypoints[highlightedCheckpoint].color)
                    SetCheckpointRgba(waypoints[highlightedCheckpoint].checkpoint, color.r, color.g, color.b, 125)
                end
                local color = closestIndex == selectedWaypoint and getCheckpointColor(selectedBlipColor) or getCheckpointColor(waypoints[closestIndex].color)
                SetCheckpointRgba(waypoints[closestIndex].checkpoint, color.r, color.g, color.b, 255)
                highlightedCheckpoint = closestIndex
                drawMsg(0.50, 0.50, "Press: [Enter] key to select waypoint, [Escape] key to delete selected waypoint,", 0.7, 0)
                drawMsg(0.50, 0.55, "[Up Arrow] and [Down Arrow] keys to change their size", 0.7, 0)
            elseif highlightedCheckpoint ~= 0 then
                local color = highlightedCheckpoint == selectedWaypoint and getCheckpointColor(selectedBlipColor) or getCheckpointColor(waypoints[highlightedCheckpoint].color)
                SetCheckpointRgba(waypoints[highlightedCheckpoint].checkpoint, color.r, color.g, color.b, 125)
                highlightedCheckpoint = 0
            end

            if IsWaypointActive() == 1 then
                SetWaypointOff()
                local coord = GetBlipCoords(GetFirstBlipInfoId(8))
                for height = 1000.0, 0.0, -50.0 do
                    RequestAdditionalCollisionAtCoord(coord.x, coord.y, height)
                    Citizen.Wait(0)
                    local foundZ, groundZ = GetGroundZFor_3dCoord(coord.x, coord.y, height, true)
                    if 1 == foundZ then
                        coord = vector3(coord.x, coord.y, groundZ)
                        editWaypoints(coord)
                        break
                    end
                end
            elseif IsControlJustReleased(0, 215) == 1 then -- enter key or A button or cross button
                editWaypoints(playerCoord)
            elseif selectedWaypoint > 0 then
                if IsControlJustReleased(2, 216) == 1 then -- space key or X button or square button
                    DeleteCheckpoint(waypoints[selectedWaypoint].checkpoint)
                    RemoveBlip(waypoints[selectedWaypoint].blip)
                    table.remove(waypoints, selectedWaypoint)

                    if highlightedCheckpoint == selectedWaypoint then
                        highlightedCheckpoint = 0
                    end
                    selectedWaypoint = 0
                    lastSelectedWaypoint = 0

                    savedTrackName = nil

                    if #waypoints > 0 then
                        if 1 == #waypoints then
                            startIsFinish = true
                        end
                        setStartToFinishBlips()
                        deleteWaypointCheckpoints()
                        setStartToFinishCheckpoints()
                        SetBlipRoute(waypoints[1].blip, true)
                        SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
                    end
                elseif IsControlJustReleased(0, 187) == 1 and waypoints[selectedWaypoint].coord.r > minRadius then -- arrow down or DPAD DOWN
                    waypoints[selectedWaypoint].coord.r = waypoints[selectedWaypoint].coord.r - 0.5
                    DeleteCheckpoint(waypoints[selectedWaypoint].checkpoint)
                    local color = getCheckpointColor(selectedBlipColor)
                    local checkpointType = 38 == waypoints[selectedWaypoint].sprite and finishCheckpoint or midCheckpoint
                    waypoints[selectedWaypoint].checkpoint = makeCheckpoint(checkpointType, waypoints[selectedWaypoint].coord, waypoints[selectedWaypoint].coord, color, 125, selectedWaypoint - 1)
                    savedTrackName = nil
                elseif IsControlJustReleased(0, 188) == 1 and waypoints[selectedWaypoint].coord.r < maxRadius then -- arrow up or DPAD UP
                    waypoints[selectedWaypoint].coord.r = waypoints[selectedWaypoint].coord.r + 0.5
                    DeleteCheckpoint(waypoints[selectedWaypoint].checkpoint)
                    local color = getCheckpointColor(selectedBlipColor)
                    local checkpointType = 38 == waypoints[selectedWaypoint].sprite and finishCheckpoint or midCheckpoint
                    waypoints[selectedWaypoint].checkpoint = makeCheckpoint(checkpointType, waypoints[selectedWaypoint].coord, waypoints[selectedWaypoint].coord, color, 125, selectedWaypoint - 1)
                    savedTrackName = nil
                end
            end
        elseif STATE_RACING == raceState then
            local currentTime = GetGameTimer()
            local elapsedTime = currentTime - raceStart - raceDelay * 1000
            if elapsedTime < 0 then
                drawMsg(0.50, 0.46, "Race starting in", 0.7, 0)
                drawMsg(0.50, 0.50, ("%05.2f"):format(-elapsedTime / 1000.0), 0.7, 0)
                drawMsg(0.50, 0.54, "seconds", 0.7, 0)

                if false == camTransStarted then
                    camTransStarted = true
                    Citizen.CreateThread(function()
                        local entity = IsPedInAnyVehicle(player, false) == 1 and GetVehiclePedIsIn(player, false) or player

                        local cam0 = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                        SetCamCoord(cam0, GetOffsetFromEntityInWorldCoords(entity, 0.0, 5.0, 1.0))
                        PointCamAtEntity(cam0, entity, 0.0, 0.0, 0.0, true)

                        local cam1 = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                        SetCamCoord(cam1, GetOffsetFromEntityInWorldCoords(entity, -5.0, 0.0, 1.0))
                        PointCamAtEntity(cam1, entity, 0.0, 0.0, 0.0, true)

                        local cam2 = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                        SetCamCoord(cam2, GetOffsetFromEntityInWorldCoords(entity, 0.0, -5.0, 1.0))
                        PointCamAtEntity(cam2, entity, 0.0, 0.0, 0.0, true)

                        RenderScriptCams(true, false, 0, true, true)

                        SetCamActiveWithInterp(cam1, cam0, 1000, 0, 0)
                        Citizen.Wait(2000)

                        SetCamActiveWithInterp(cam2, cam1, 1000, 0, 0)
                        Citizen.Wait(2000)

                        RenderScriptCams(false, true, 1000, true, true)

                        SetGameplayCamRelativeRotation(GetEntityRotation(entity))
                    end)
                end

                if elapsedTime > -countdown * 1000 then
                    drawLights = true
                    countdown = countdown - 1
                    PlaySoundFrontend(-1, "MP_5_SECOND_TIMER", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    if IsPedInAnyVehicle(player, false) == 1 then
                        FreezeEntityPosition(GetVehiclePedIsIn(player, false), true)
                    end
                end

                if true == drawLights then
                    for i = 0, 4 - countdown do
                        if i == 0 then
                            drawRect(0.15, 0.1, 0.1, 0.175, 0, 200, 0, 255)
                        elseif i == 1 then
                            drawRect(0.3, 0.1, 0.1, 0.175, 100, 200, 0, 255)
                        elseif i == 2 then
                            drawRect(0.45, 0.1, 0.1, 0.175, 200, 200, 0, 255)
                        elseif i == 3 then
                            drawRect(0.6, 0.1, 0.1, 0.175, 200, 100, 0, 255)
                        elseif i == 4 then
                            drawRect(0.75, 0.1, 0.1, 0.175, 200, 0, 0, 255)
                        end
                    end
                end

            else
                local vehicle = nil
                if IsPedInAnyVehicle(player, false) == 1 then
                    vehicle = GetVehiclePedIsIn(player, false)
                    FreezeEntityPosition(vehicle, false)
                    currentVehicleHash = GetEntityModel(vehicle)
                    currentVehicleName = GetLabelText(GetDisplayNameFromVehicleModel(currentVehicleHash))
                else
                    currentVehicleName = "FEET"
                end

                if false == started then
                    started = true
                    PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)
                    bestLapVehicleName = currentVehicleName
                    lapTimeStart = currentTime
                end

                if IsControlPressed(0, 73) == 1 then -- X key or A button or cross button
                    if true == respawnCtrlPressed then
                        if currentTime - respawnTime > 1000 then
                            respawnCtrlPressed = false
                            respawn()
                        end
                    else
                        respawnCtrlPressed = true
                        respawnTime = currentTime
                    end
                else
                    respawnCtrlPressed = false
                end

                drawRect(leftSide - 0.01, topSide - 0.01, 0.21, 0.35, 0, 0, 0, 125)

                drawMsg(leftSide, topSide, "Position", 0.5, 1)
                if -1 == position then
                    drawMsg(rightSide, topSide, "-- of --", 0.5, 1)
                else
                    drawMsg(rightSide, topSide, ("%d of %d"):format(position, numRacers), 0.5, 1)
                end

                drawMsg(leftSide, topSide + 0.03, "Lap", 0.5, 1)
                drawMsg(rightSide, topSide + 0.03, ("%d of %d"):format(currentLap, numLaps), 0.5, 1)

                drawMsg(leftSide, topSide + 0.06, "Waypoint", 0.5, 1)
                if true == startIsFinish then
                    drawMsg(rightSide, topSide + 0.06, ("%d of %d"):format(currentWaypoint, #waypoints), 0.5, 1)
                else
                    drawMsg(rightSide, topSide + 0.06, ("%d of %d"):format(currentWaypoint - 1, #waypoints - 1), 0.5, 1)
                end

                local minutes, seconds = minutesSeconds(elapsedTime)
                drawMsg(leftSide, topSide + 0.09, "Total time", 0.5, 1)
                drawMsg(rightSide, topSide + 0.09, ("%02d:%05.2f"):format(minutes, seconds), 0.5, 1)

                drawMsg(leftSide, topSide + 0.12, "Vehicle", 0.5, 1)
                drawMsg(rightSide, topSide + 0.12, currentVehicleName, 0.5, 1)

                local lapTime = currentTime - lapTimeStart
                minutes, seconds = minutesSeconds(lapTime)
                drawMsg(leftSide, topSide + 0.17, "Lap time", 0.7, 1)
                drawMsg(rightSide, topSide + 0.17, ("%02d:%05.2f"):format(minutes, seconds), 0.7, 1)

                drawMsg(leftSide, topSide + 0.21, "Best lap", 0.7, 1)
                if -1 == bestLapTime then
                    drawMsg(rightSide, topSide + 0.21, "- - : - -", 0.7, 1)
                else
                    minutes, seconds = minutesSeconds(bestLapTime)
                    drawMsg(rightSide, topSide + 0.21, ("%02d:%05.2f"):format(minutes, seconds), 0.7, 1)
                end

                if true == beginDNFTimeout then
                    local milliseconds = timeoutStart + DNFTimeout - currentTime
                    if milliseconds > 0 then
                        minutes, seconds = minutesSeconds(milliseconds)
                        drawMsg(leftSide, topSide + 0.25, "DNF time", 0.7, 1)
                        drawMsg(rightSide, topSide + 0.25, ("%02d:%05.2f"):format(minutes, seconds), 0.7, 1)
                    else -- DNF
                        DeleteCheckpoint(raceCheckpoint)
                        finishRace(-1)
                    end
                end

                if STATE_RACING == raceState then
                    if #(playerCoord - vector3(waypointCoord.x, waypointCoord.y, waypointCoord.z)) < waypointCoord.r then
                        local waypointPassed = true
                        if restrictedHash ~= nil then
                            if nil == vehicle or currentVehicleHash ~= restrictedHash then
                                waypointPassed = false
                            end
                        elseif restrictedClass ~= nil then
                            if vehicle ~= nil then
                                if -1 == restrictedClass then
                                    if vehicleInList(vehicle, customClassVehicleList) == false then
                                        waypointPassed = false
                                    end
                                elseif getVehicleClassFromName(GetEntityModel(vehicle)) ~= restrictedClass then
                                    waypointPassed = false
                                end
                            else
                                waypointPassed = false
                            end
                        end

                        if true == waypointPassed then
                            DeleteCheckpoint(raceCheckpoint)
                            PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)

                            numWaypointsPassed = numWaypointsPassed + 1

                            if currentWaypoint < #waypoints then
                                currentWaypoint = currentWaypoint + 1
                            else
                                currentWaypoint = 1
                                lapTimeStart = currentTime
                                if -1 == bestLapTime or lapTime < bestLapTime then
                                    bestLapTime = lapTime
                                    bestLapVehicleName = currentVehicleName
                                end
                                if currentLap < numLaps then
                                    currentLap = currentLap + 1
                                    if #randVehicles > 0 then
                                        local randVehicle = switchVehicle(player, randVehicles[math.random(#randVehicles)])
                                        if randVehicle ~= nil then
                                            SetEntityAsNoLongerNeeded(randVehicle)
                                        end
                                        PlaySoundFrontend(-1, "CHARACTER_SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                                    end
                                else
                                    finishRace(elapsedTime)
                                end
                            end

                            if STATE_RACING == raceState then
                                local prev = currentWaypoint - 1

                                local last = currentWaypoint + numVisible - 1
                                local addLast = true

                                local curr = currentWaypoint
                                local checkpointType = -1

                                if true == startIsFinish then
                                    prev = currentWaypoint
                                    if currentLap ~= numLaps then
                                        last = last % #waypoints + 1
                                    elseif last < #waypoints then
                                        last = last + 1
                                    elseif #waypoints == last then
                                        last = 1
                                    else
                                        addLast = false
                                    end
                                    curr = curr % #waypoints + 1
                                    checkpointType = (1 == curr and numLaps == currentLap) and finishCheckpoint or arrow3Checkpoint
                                else
                                    if last > #waypoints then
                                        addLast = false
                                    end
                                    checkpointType = #waypoints == curr and finishCheckpoint or arrow3Checkpoint
                                end

                                SetBlipDisplay(waypoints[prev].blip, 0)

                                if true == addLast then
                                    SetBlipDisplay(waypoints[last].blip, 2)
                                end

                                SetBlipRoute(waypoints[curr].blip, true)
                                SetBlipRouteColour(waypoints[curr].blip, blipRouteColor)
                                waypointCoord = waypoints[curr].coord
                                local nextCoord = waypointCoord
                                if arrow3Checkpoint == checkpointType then
                                    nextCoord = curr < #waypoints and waypoints[curr + 1].coord or waypoints[1].coord
                                end
                                raceCheckpoint = makeCheckpoint(checkpointType, waypointCoord, nextCoord, green, 125, 0)
                            end
                        end
                    end
                end
            end
        elseif STATE_IDLE == raceState then
            local closestIndex = -1
            local minDist = defaultRadius
            for rIndex, start in pairs(starts) do
                local dist = #(playerCoord - GetBlipCoords(start.blip))
                if dist < minDist then
                    minDist = dist
                    closestIndex = rIndex
                end
            end
            if closestIndex ~= -1 then
                local msg = "Join race (Press [E]) using "
                if nil == starts[closestIndex].trackName then
                    msg = msg .. "unsaved track "
                else
                    msg = msg .. (true == starts[closestIndex].isPublic and "publicly" or "privately") .. " saved track '" .. starts[closestIndex].trackName .. "' "
                end
                drawMsg(0.50, 0.50, msg, 0.7, 0)
                msg = "Registered by " .. starts[closestIndex].owner
                msg = msg .. (": %d buy-in : %d lap(s)"):format(starts[closestIndex].buyin, starts[closestIndex].laps)
                if "yes" == starts[closestIndex].allowAI then
                    msg = msg .. " : AI allowed"
                end
                if "rest" == starts[closestIndex].rtype then
                    msg = msg .. " : using '" .. starts[closestIndex].restrict .. "' vehicle"
                elseif "class" == starts[closestIndex].rtype then
                    msg = msg .. " : using " .. getClassName(starts[closestIndex].vclass) .. " vehicle class"
                elseif "rand" == starts[closestIndex].rtype then
                    msg = msg .. " : using random "
                    if starts[closestIndex].vclass ~= nil then
                        msg = msg .. getClassName(starts[closestIndex].vclass) .. " vehicle class"
                    else
                        msg = msg .. "vehicles"
                    end
                    if starts[closestIndex].svehicle ~= nil then
                        msg = msg .. " : '" .. starts[closestIndex].svehicle .. "'"
                    end
                end
                drawMsg(0.50, 0.55, msg, 0.7, 0)
                if IsControlJustReleased(0, 51) == 1 then -- E key or DPAD RIGHT
                    local joinRace = true
                    local vehicle = nil
                    if IsPedInAnyVehicle(player, false) == 1 then
                        vehicle = GetVehiclePedIsIn(player, false)
                    end
                    if "rest" == starts[closestIndex].rtype then
                        if vehicle ~= nil then
                            if GetEntityModel(vehicle) ~= GetHashKey(starts[closestIndex].restrict) then
                                joinRace = false
                                notifyPlayer("Cannot join race.  Player needs to be in restricted vehicle.")
                            end
                        else
                            joinRace = false
                            notifyPlayer("Cannot join race.  Player needs to be in restricted vehicle.")
                        end
                    elseif "class" == starts[closestIndex].rtype then
                        if starts[closestIndex].vclass ~= -1 then
                            if vehicle ~= nil then
                                if getVehicleClassFromName(GetEntityModel(vehicle)) ~= starts[closestIndex].vclass then
                                    joinRace = false
                                    notifyPlayer("Cannot join race.  Player needs to be in vehicle of " .. getClassName(starts[closestIndex].vclass) .. " class.")
                                end
                            else
                                joinRace = false
                                notifyPlayer("Cannot join race.  Player needs to be in vehicle of " .. getClassName(starts[closestIndex].vclass) .. " class.")
                            end
                        else
                            if #starts[closestIndex].vehicleList == 0 then
                                joinRace = false
                                notifyPlayer("Cannot join race.  No valid vehicles in vehicle list.")
                            else
                                local vehicleList = ""
                                for _, vehName in pairs(starts[closestIndex].vehicleList) do
                                    vehicleList = vehicleList .. vehName .. ", "
                                end
                                vehicleList = string.sub(vehicleList, 1, -3)
                                if vehicle ~= nil then
                                    if vehicleInList(vehicle, starts[closestIndex].vehicleList) == false then
                                        joinRace = false
                                        notifyPlayer("Cannot join race.  Player needs to be in one of the following vehicles:  " .. vehicleList)
                                    end
                                else
                                    joinRace = false
                                    notifyPlayer("Cannot join race.  Player needs to be in one of the following vehicles:  " .. vehicleList)
                                end
                            end
                        end
                    elseif "rand" == starts[closestIndex].rtype then
                        if #starts[closestIndex].vehicleList == 0 then
                            joinRace = false
                            notifyPlayer("Cannot join race.  No valid vehicles in vehicle list.")
                        else
                            if vehicle ~= nil then
                                originalVehicleHash = GetEntityModel(vehicle)
                                rememberedVehicleProps = getVehicleProperties(vehicle)
                            else
                                originalVehicleHash = nil
                                rememberedVehicleProps = nil
                            end
                            if starts[closestIndex].vclass ~= nil then
                                if nil == starts[closestIndex].svehicle then
                                    if vehicle ~= nil then
                                        if getVehicleClassFromName(GetEntityModel(vehicle)) ~= starts[closestIndex].vclass then
                                            joinRace = false
                                            notifyPlayer("Cannot join race.  Player needs to be in vehicle of " .. getClassName(starts[closestIndex].vclass) .. " class.")
                                        end
                                    else
                                        joinRace = false
                                        notifyPlayer("Cannot join race.  Player needs to be in vehicle of " .. getClassName(starts[closestIndex].vclass) .. " class.")
                                    end
                                end
                            end
                        end
                    end
                    if true == joinRace then
                        removeRacerBlips()
                        TriggerServerEvent("races:join", closestIndex, PedToNet(player), nil)
                    end
                end
            end
        end

        if IsPedInAnyVehicle(player, true) == false then
            local vehicle = GetVehiclePedIsTryingToEnter(player)
            if DoesEntityExist(vehicle) == 1 then
                if false == enteringVehicle then
                    enteringVehicle = true
                    local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
                    if numSeats > 0 and IsVehicleSeatFree(vehicle, -1) == false then
                        for seat = -1, numSeats - 2 do
                            if IsVehicleSeatFree(vehicle, seat) == true then
                                SetPedVehicleForcedSeatUsage(player, vehicle, 0, 5)
                                break
                            end
                        end
                    end
                end
            end
        else
            enteringVehicle = false
        end

        if true == speedo then
            local speed = GetEntitySpeed(player)
            if "metric" == unitom then
                drawMsg(leftSide, topSide + 0.29, "Speed(km/h)", 0.7, 1)
                drawMsg(rightSide, topSide + 0.29, ("%05.2f"):format(speed * 3.6), 0.7, 1)
            else
                drawMsg(leftSide, topSide + 0.29, "Speed(mph)", 0.7, 1)
                drawMsg(rightSide, topSide + 0.29, ("%05.2f"):format(speed * 2.2369363), 0.7, 1)
            end
        end

        if true == panelShown then
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 18, true)
            DisableControlAction(0, 322, true)
            DisableControlAction(0, 106, true)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if aiState ~= nil then
            local currentTime = GetGameTimer()
            for aiName, driver in pairs(aiState.drivers) do
                if STATE_RACING == driver.raceState then
                    local elapsedTime = currentTime - aiState.raceStart - aiState.raceDelay * 1000
                    if elapsedTime >= 0 then
                        if false == driver.started then
                            driver.started = true
                            driver.lapTimeStart = currentTime
                        end
                        if true == aiState.beginDNFTimeout then
                            if aiState.timeoutStart + aiState.DNFTimeout - currentTime <= 0 then
                                driver.raceState = STATE_IDLE
                                TriggerServerEvent("races:finish", GetPlayerServerId(PlayerId()), driver.netID, aiName, driver.numWaypointsPassed, -1, driver.bestLapTime, driver.bestLapVehicleName, nil)
                            end
                        end
                        if IsEntityDead(driver.ped) == false and STATE_RACING == driver.raceState then
                            if IsVehicleDriveable(driver.vehicle, false) == false then
                                respawnAI(driver)
                            else
                                local coord = GetEntityCoords(driver.ped)
                                if #(coord - driver.stuckCoord) < 5.0 then
                                    if -1 == driver.stuckStart then
                                        driver.stuckStart = currentTime
                                    elseif currentTime - driver.stuckStart > 10000 then
                                        respawnAI(driver)
                                        driver.stuckStart = -1
                                    end
                                else
                                    driver.stuckCoord = coord
                                    driver.stuckStart = -1
                                end
                                if IsPedInAnyVehicle(driver.ped, true) == false then
                                    if false == driver.enteringVehicle then
                                        driver.enteringVehicle = true
                                        driver.destSet = true
                                        TaskEnterVehicle(driver.ped, driver.vehicle, 10.0, -1, 2.0, 1, 0)
                                    end
                                else
                                    driver.enteringVehicle = false
                                    if true == driver.destSet then
                                        driver.destSet = false
                                        -- TaskVehicleDriveToCoordLongrange(ped, vehicle, x, y, z, speed, driveMode, stopRange)
                                        -- driveMode: https://vespura.com/fivem/drivingstyle/
                                        -- actual speed is around speed * 2 mph
                                        -- TaskVehicleDriveToCoordLongrange(driver.ped, driver.vehicle, driver.destCoord.x, driver.destCoord.y, driver.destCoord.z, 60.0, 787004, driver.destCoord.r * 0.5)
                                        -- On public track '01' and waypoint 7, AI would miss waypoint 7, move past it, wander a long way around, then come back to waypoint 7 when using TaskVehicleDriveToCoordLongrange
                                        -- Using TaskVehicleDriveToCoord instead.  Waiting to see if there is any weird behaviour with this function.
                                        -- TaskVehicleDriveToCoord(ped, vehicle, x, y, z, speed, p6, vehicleModel, drivingMode, stopRange, p10)
                                        TaskVehicleDriveToCoord(driver.ped, driver.vehicle, driver.destCoord.x, driver.destCoord.y, driver.destCoord.z, 300.0, 1.0, GetEntityModel(driver.vehicle), drivingStyle, driver.destCoord.r * 1.0, true)
                                    else
                                        if #(GetEntityCoords(driver.ped) - vector3(driver.destCoord.x, driver.destCoord.y, driver.destCoord.z)) < driver.destCoord.r then
                                            driver.numWaypointsPassed = driver.numWaypointsPassed + 1
                                            if driver.currentWP < #aiState.waypointCoords then
                                                driver.currentWP = driver.currentWP + 1
                                            else
                                                driver.currentWP = 1
                                                local lapTime = currentTime - driver.lapTimeStart
                                                if -1 == driver.bestLapTime or lapTime < driver.bestLapTime then
                                                    driver.bestLapTime = lapTime
                                                end
                                                driver.lapTimeStart = currentTime
                                                if driver.currentLap < aiState.numLaps then
                                                    driver.currentLap = driver.currentLap + 1
                                                    if #aiState.randVehicles > 0 then
                                                        driver.vehicle = switchVehicle(driver.ped, aiState.randVehicles[math.random(#aiState.randVehicles)])
                                                    end
                                                else
                                                    driver.raceState = STATE_IDLE
                                                    TriggerServerEvent("races:finish", GetPlayerServerId(PlayerId()), driver.netID, aiName, driver.numWaypointsPassed, elapsedTime, driver.bestLapTime, driver.bestLapVehicleName, nil)
                                                end
                                            end
                                            if STATE_RACING == driver.raceState then
                                                local curr = true == startIsFinish and driver.currentWP % #aiState.waypointCoords + 1 or driver.currentWP
                                                driver.destCoord = aiState.waypointCoords[curr]
                                                driver.destSet = true
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                elseif STATE_IDLE == driver.raceState then
                    Citizen.CreateThread(function()
                        while true do
                            if GetVehicleNumberOfPassengers(driver.vehicle) == 0 then
                                Citizen.Wait(1000)
                                SetEntityAsNoLongerNeeded(driver.ped)
                                break
                            end
                            Citizen.Wait(1000)
                        end
                    end)
                    SetEntityAsNoLongerNeeded(driver.vehicle)
                    aiState.drivers[aiName] = nil
                    aiState.numRacing = aiState.numRacing - 1
                    if 0 == aiState.numRacing then
                        aiState = nil
                    end
                end
            end
        end
    end
end)