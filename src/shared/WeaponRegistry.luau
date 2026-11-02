--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local ConfigMerge = require(script.Parent.ConfigMerge)
local ConfigValidator = require(script.Parent.ConfigValidator)
local Defaults = require(script.Parent.Defaults)
local Types = require(script.Parent.Types)

local configsFolder = script.Parent:WaitForChild("Configs")

local WeaponRegistry = {}

local configs: { [string]: Types.WeaponConfig } = {}

local function register(module: Instance)
	if not module:IsA("ModuleScript") then
		return
	end
	local overrides = (require :: any)(module) :: { [string]: any }
	for _, key in ConfigMerge.UnknownKeys(Defaults :: any, overrides) do
		warn(`Weapon '{module.Name}': unknown setting '{key}'`)
	end
	local merged = ConfigMerge.Merge(Defaults :: any, overrides)
	merged.Id = module.Name
	local errors = ConfigValidator.Validate(merged)
	if #errors > 0 then
		warn(`Weapon '{module.Name}' was not registered:\n  {table.concat(errors, "\n  ")}`)
		return
	end
	configs[module.Name] = (merged :: any) :: Types.WeaponConfig
end

for _, module in configsFolder:GetChildren() do
	register(module)
end
configsFolder.ChildAdded:Connect(register)

function WeaponRegistry.GetConfig(tool: unknown): Types.WeaponConfig?
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return nil
	end
	local weaponId = tool:GetAttribute("Weapon")
	return configs[if type(weaponId) == "string" then weaponId else tool.Name]
end

function WeaponRegistry.GetById(weaponId: string): Types.WeaponConfig?
	return configs[weaponId]
end

function WeaponRegistry.GetEquipped(character: Model): (Tool?, Types.WeaponConfig?)
	local tool = character:FindFirstChildOfClass("Tool")
	local config = WeaponRegistry.GetConfig(tool)
	if config and tool then
		return tool, config
	end
	return nil, nil
end

return WeaponRegistry
