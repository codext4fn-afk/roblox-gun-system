--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local AngleMath = require(WeaponSystem:WaitForChild("AngleMath"))
local Rig = require(WeaponSystem:WaitForChild("Rig"))
local Settings = require(WeaponSystem:WaitForChild("Settings"))
local Types = require(WeaponSystem:WaitForChild("Types"))

local PoseReplicator = {}

type Posed = {
	pose: Types.Pose,
	solver: Types.PoseSolver,
}

local posed: { [Model]: Posed } = {}
local connection: RBXScriptConnection? = nil

local function step(deltaTime: number)
	local blend = AngleMath.ExpBlend(deltaTime, Settings.Server.PoseSmoothing)
	for character, entry in posed do
		if not character.Parent then
			posed[character] = nil
			continue
		end
		local pitch = character:GetAttribute("AimPitch")
		local targetPitch = if type(pitch) == "number" then pitch else 0
		local targetAim = if character:GetAttribute("Aiming") == true then 1 else 0
		local pose = entry.pose
		pose.pitch += (targetPitch - pose.pitch) * blend
		pose.aim += (targetAim - pose.aim) * blend
		entry.solver.Apply(character, pose)
	end
end

function PoseReplicator.Start(character: Model)
	if posed[character] then
		return
	end
	local solver = Rig.GetPoseSolver(character)
	if solver then
		posed[character] = { pose = solver.NewPose(), solver = solver }
	end
end

function PoseReplicator.Stop(character: Model)
	local entry = posed[character]
	if entry then
		posed[character] = nil
		entry.solver.Clear(character)
	end
end

function PoseReplicator.Run()
	if not connection then
		connection = RunService.PreSimulation:Connect(step)
	end
end

return PoseReplicator
