--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Loader = {}

local GLOBALS = {
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	Enum = roblox.Enum,
}

local cache: { [string]: any } = {}

local function resolve(path: string): string
	if fs.isFile(path .. ".luau") then
		return path .. ".luau"
	elseif fs.isFile(path .. "/init.luau") then
		return path .. "/init.luau"
	end
	error(`no module at {path}`)
end

local function parentOf(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or path
end

local makeScript: (path: string) -> any

local function moduleRequire(target: any): any
	local path = rawget(target, "__path")
	assert(type(path) == "string", "require expects a module reference")
	return Loader.Require(path)
end

makeScript = function(path: string): any
	return setmetatable({ __path = path }, {
		__index = function(_, key: string): any
			if key == "Parent" then
				return makeScript(parentOf(path))
			end
			return makeScript(`{path}/{key}`)
		end,
	})
end

function Loader.Require(path: string): any
	local file = resolve(path)
	if cache[file] ~= nil then
		return cache[file]
	end
	local environment: { [string]: any } = table.clone(GLOBALS)
	environment.script = makeScript(path)
	environment.require = moduleRequire
	local chunk = luau.load(fs.readFile(file), {
		debugName = file,
		environment = environment :: any,
	})
	local result = chunk()
	cache[file] = if result == nil then false else result
	return result
end

Loader.Globals = GLOBALS

return Loader
