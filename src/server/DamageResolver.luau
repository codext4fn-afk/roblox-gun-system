--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local HitZones = require(WeaponSystem:WaitForChild("HitZones"))
local Raycast = require(WeaponSystem:WaitForChild("Raycast"))
local Settings = require(WeaponSystem:WaitForChild("Settings"))
local Types = require(WeaponSystem:WaitForChild("Types"))

local DamageResolver = {}

type Hit = {
	model: Model,
	damage: number,
}

local function canDamage(shooter: Player, victimModel: Model, config: Types.WeaponConfig): boolean
	if config.FriendlyFire then
		return true
	end
	local victim = Players:GetPlayerFromCharacter(victimModel)
	if not victim or shooter.Neutral or victim.Neutral then
		return true
	end
	return victim.Team ~= shooter.Team
end

local function tagCreator(humanoid: Humanoid, shooter: Player)
	local existing = humanoid:FindFirstChild("creator")
	if existing then
		existing:Destroy()
	end
	local tag = Instance.new("ObjectValue")
	tag.Name = "creator"
	tag.Value = shooter
	tag.Parent = humanoid
	task.delay(Settings.Server.CreatorTagLifetime, function()
		if tag.Parent then
			tag:Destroy()
		end
	end)
end

function DamageResolver.Resolve(
	shooter: Player,
	character: Model,
	config: Types.WeaponConfig,
	origin: Vector3,
	directions: { Vector3 }
): { Vector3 }
	local params = Raycast.Excluding({ character })
	local hitPositions = table.create(#directions)
	local hits: { [Humanoid]: Hit } = {}

	for _, direction in directions do
		local result = Raycast.Cast(origin, direction, config.Range, params)
		table.insert(hitPositions, if result then result.Position else origin + direction * config.Range)
		local part = result and result.Instance
		if part and part:IsA("BasePart") then
			local humanoid, model = HitZones.GetLivingHumanoid(part)
			if humanoid and model then
				local hit = hits[humanoid] or { model = model, damage = 0 }
				hit.damage += config.Damage[HitZones.Get(part)]
				hits[humanoid] = hit
			end
		end
	end

	for humanoid, hit in hits do
		if canDamage(shooter, hit.model, config) then
			tagCreator(humanoid, shooter)
			humanoid:TakeDamage(hit.damage)
		end
	end

	return hitPositions
end

return DamageResolver
