--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local CharacterRig = require(script.CharacterRig)
local PoseSolverR15 = require(script.PoseSolverR15)
local PoseSolverR6 = require(script.PoseSolverR6)
local Types = require(script.Parent.Types)

local Rig = {
	CharacterRig = CharacterRig,
}

function Rig.GetPoseSolver(character: Instance?): Types.PoseSolver?
	local rig = CharacterRig.GetRig(character)
	if rig == "R15" then
		return PoseSolverR15
	elseif rig == "R6" then
		return PoseSolverR6
	end
	return nil
end

return Rig
