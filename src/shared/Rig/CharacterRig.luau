--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local Types = require(script.Parent.Parent.Types)

local CharacterRig = {}

function CharacterRig.GetHumanoid(character: Instance?): Humanoid?
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function CharacterRig.GetRig(character: Instance?): Types.RigName?
	local humanoid = CharacterRig.GetHumanoid(character)
	if not humanoid then
		return nil
	end
	return if humanoid.RigType == Enum.HumanoidRigType.R15 then "R15" else "R6"
end

function CharacterRig.IsR15(character: Instance?): boolean
	return CharacterRig.GetRig(character) == "R15"
end

function CharacterRig.IsAlive(character: Instance?): boolean
	local humanoid = CharacterRig.GetHumanoid(character)
	return humanoid ~= nil and humanoid.Health > 0
end

return CharacterRig
