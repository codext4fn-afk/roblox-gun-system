--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rig = require(ReplicatedStorage:WaitForChild("WeaponSystem"):WaitForChild("Rig"))

local ClientTypes = require(script.Parent.ClientTypes)
local R15 = require(script.R15)
local R6 = require(script.R6)

local Rigs = {}

function Rigs.Get(character: Instance?): ClientTypes.ClientRig?
	local rig = Rig.CharacterRig.GetRig(character)
	if rig == "R15" then
		return R15
	elseif rig == "R6" then
		return R6
	end
	return nil
end

return Rigs
