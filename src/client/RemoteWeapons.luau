--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Remotes = require(WeaponSystem:WaitForChild("Remotes"))
local WeaponAxes = require(WeaponSystem:WaitForChild("WeaponAxes"))
local WeaponRegistry = require(WeaponSystem:WaitForChild("WeaponRegistry"))

local AimPose = require(script.Parent.AimPose)
local Effects = require(script.Parent.Effects)
local Mechanics = require(script.Parent.Mechanics)
local Rigs = require(script.Parent.Rigs)

local RemoteWeapons = {}

local function getShooter(tool: unknown): (Tool?, Model?)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return nil, nil
	end
	local shooter = tool.Parent
	if shooter and shooter:IsA("Model") then
		return tool, shooter
	end
	return nil, nil
end

local function onRemoteShot(rawTool: unknown, hitPositions: unknown)
	local tool, shooter = getShooter(rawTool)
	local config = WeaponRegistry.GetConfig(tool)
	if not (tool and shooter and config) or not WeaponAxes.GetHandle(tool) or type(hitPositions) ~= "table" then
		return
	end
	local muzzle = Effects.GetMuzzlePosition(tool)
	if not muzzle then
		return
	end
	local positions = hitPositions :: { unknown }
	for _, position in positions do
		if typeof(position) == "Vector3" then
			Effects.RemoteBullet(muzzle, position, shooter)
		end
	end
	local firstHit = positions[1]
	if typeof(firstHit) == "Vector3" then
		Effects.MuzzleFlash(tool, firstHit - muzzle)
	end
	Mechanics.CycleBolt(tool, config)
	AimPose.Kick(shooter, config.ArmKick)
	Effects.PlaySound(tool, "Fire")
end

local function onRemoteReload(rawTool: unknown)
	local tool, shooter = getShooter(rawTool)
	local config = WeaponRegistry.GetConfig(tool)
	local rig = Rigs.Get(shooter)
	if not (tool and shooter and config and rig) then
		return
	end
	Effects.PlaySound(tool, "Reload")
	rig.Reload(shooter, tool, config, {
		onSeated = function()
			AimPose.Kick(shooter, config.Magazine.SeatKick)
		end,
		chamber = false,
		track = nil,
		isTracked = function()
			return AimPose.IsTracked(shooter)
		end,
		isLocal = false,
	})
end

function RemoteWeapons.Start()
	Remotes.ReplicateShot.OnClientEvent:Connect(onRemoteShot)
	Remotes.ReplicateReload.OnClientEvent:Connect(onRemoteReload)
end

return RemoteWeapons
