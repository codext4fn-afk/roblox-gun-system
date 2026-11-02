--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

local ConfigMerge = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = deepCopy(item)
	end
	return result
end

function ConfigMerge.Merge(base: { [string]: any }, override: { [string]: any }): { [string]: any }
	local result = deepCopy(base)
	for key, value in override do
		if type(value) == "table" and type(base[key]) == "table" then
			result[key] = ConfigMerge.Merge(base[key], value)
		else
			result[key] = deepCopy(value)
		end
	end
	return result
end

function ConfigMerge.UnknownKeys(base: { [string]: any }, override: { [string]: any }, path: string?): { string }
	local unknown = {}
	for key, value in override do
		local fullKey = if path then `{path}.{key}` else key
		if base[key] == nil then
			table.insert(unknown, fullKey)
		elseif type(value) == "table" and type(base[key]) == "table" then
			for _, nested in ConfigMerge.UnknownKeys(base[key], value, fullKey) do
				table.insert(unknown, nested)
			end
		end
	end
	table.sort(unknown)
	return unknown
end

return ConfigMerge
