local mod = RegisterMod("Cube Baby Door Wrap", 1)
local game = Game()
local cubeBabyVariant = FamiliarVariant.CUBE_BABY

local OppositeDoorSlot = {
    [DoorSlot.LEFT0] = DoorSlot.RIGHT0,
    [DoorSlot.RIGHT0] = DoorSlot.LEFT0,
    [DoorSlot.UP0] = DoorSlot.DOWN0,
    [DoorSlot.DOWN0] = DoorSlot.UP0
}

local DOOR_TOUCH_RADIUS = 40
local MIN_WRAP_VELOCITY = 0.5
local ANIMATION_DURATION = 12
local SHRINK_PHASE = ANIMATION_DURATION/2
local COOLDOWN = 15
local EXIT_SPEED = 3

function mod:GetRandomAvailableDoor(room, excludeSlot)
    local availableDoors = {}
    for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door and door:IsOpen() and slot ~= excludeSlot then
            table.insert(availableDoors, slot)
        end
    end
    if #availableDoors > 0 then
        return availableDoors[math.random(1, #availableDoors)]
    end
    return nil
end

function mod:GetExitVelocity(exitDoorSlot)
    local room = game:GetRoom()
    local exitDoor = room:GetDoor(exitDoorSlot)
    if not exitDoor then return Vector.Zero end
    
    local roomCenter = room:GetCenterPos()
    return (roomCenter - exitDoor.Position):Normalized() * EXIT_SPEED
end

function mod:GetOppositeDirectionVelocity(originalVel, entrySlot, exitSlot)
    if entrySlot == DoorSlot.LEFT0 or entrySlot == DoorSlot.RIGHT0 then
        return Vector(originalVel.X > 0 and EXIT_SPEED or -EXIT_SPEED, 0)
    else
        return Vector(0, originalVel.Y > 0 and EXIT_SPEED or -EXIT_SPEED)
    end
end

function mod:OnFamiliarUpdate(fam)
    if fam.Variant ~= cubeBabyVariant then return end
    local room = game:GetRoom()
    local data = fam:GetData()

    data.wrapCooldown = data.wrapCooldown or 0
    data.animationProgress = data.animationProgress or 0
    data.wrapInfo = data.wrapInfo or {}
    data.isWrapping = data.isWrapping or false

    if data.wrapCooldown > 0 then
        data.wrapCooldown = data.wrapCooldown - 1
        return
    end

    -- Handle animation
    if data.animationProgress > 0 then
        local scale
        if data.animationProgress > SHRINK_PHASE then
            local progress = (ANIMATION_DURATION - data.animationProgress)/SHRINK_PHASE
            scale = 1 - progress * 0.7
        else
            local progress = (SHRINK_PHASE - data.animationProgress)/SHRINK_PHASE
            scale = 0.3 + progress * 0.7
        end
        
        fam.SpriteScale = Vector(scale, scale)
        
        if data.animationProgress == SHRINK_PHASE and not data.isWrapping then
            data.isWrapping = true
            local entryDoor = room:GetDoor(data.wrapInfo.doorSlot)
            local targetDoorSlot = data.wrapInfo.oppositeSlot
            local targetDoor = targetDoorSlot and room:GetDoor(targetDoorSlot)
            local useOppositeDoor = targetDoor and targetDoor:IsOpen()
            
            if not useOppositeDoor then
                -- Find random door if opposite not available
                targetDoorSlot = mod:GetRandomAvailableDoor(room, data.wrapInfo.doorSlot)
                targetDoor = targetDoorSlot and room:GetDoor(targetDoorSlot)
            end
            
            if entryDoor and targetDoor then
                if useOppositeDoor then
                    fam.Position = targetDoor.Position
                    fam.Velocity = mod:GetOppositeDirectionVelocity(data.wrapInfo.velocity, 
                        data.wrapInfo.doorSlot, targetDoorSlot)
                else
                    fam.Position = targetDoor.Position
                    fam.Velocity = mod:GetExitVelocity(targetDoorSlot)
                end
            end
        end
        
        data.animationProgress = data.animationProgress - 1
        if data.animationProgress == 0 then
            fam.SpriteScale = Vector(1, 1)
            data.wrapCooldown = COOLDOWN
            data.isWrapping = false
        end
        return
    end

    if not data.isWrapping then
        for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
            local door = room:GetDoor(slot)
            if door and door:IsOpen() then
                local dist = fam.Position:Distance(door.Position)
                if dist < DOOR_TOUCH_RADIUS and fam.Velocity:Length() >= MIN_WRAP_VELOCITY then
                    local oppositeSlot = OppositeDoorSlot[slot]
                    
                    data.wrapInfo = {
                        doorSlot = slot,
                        oppositeSlot = oppositeSlot,
                        velocity = fam.Velocity
                    }
                    
                    data.animationProgress = ANIMATION_DURATION
                    break
                end
            end
        end
    end
end

mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, mod.OnFamiliarUpdate, cubeBabyVariant)