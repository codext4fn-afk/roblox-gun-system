--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local AnimationClipProvider = game:GetService("AnimationClipProvider")

local Settings = require(script.Parent.Settings)
local Types = require(script.Parent.Types)

local WeaponAnimations = {}

local NAMES: { Types.AnimationName } = { "Hold", "Aim", "Fire", "Reload" }
WeaponAnimations.Names = NAMES

local DRAFTS_FOLDER = "AnimationDrafts"

local resolved: { [Types.RigName]: { [string]: { [string]: string } } } = { R6 = {}, R15 = {} }

local function getDraftRoot(rig: Types.RigName): Instance?
	local drafts = script.Parent:FindFirstChild(DRAFTS_FOLDER)
	return drafts and drafts:FindFirstChild(rig)
end

local function registerDraft(parent: Instance?, name: string): string
	local draft = parent and parent:FindFirstChild(name)
	if not (draft and draft:IsA("KeyframeSequence")) then
		return ""
	end
	local ok, id = pcall(AnimationClipProvider.RegisterAnimationClip, AnimationClipProvider, draft)
	return if ok and type(id) == "string" then id else ""
end

local function resolve(rig: Types.RigName, config: Types.WeaponConfig, name: Types.AnimationName): string
	local published = config.Animations[rig][name]
	if published ~= "" then
		return published
	end
	local root = getDraftRoot(rig)
	local id = registerDraft(root and root:FindFirstChild(config.Id), name)
	if id ~= "" then
		return id
	end
	local shared = Settings.SharedAnimations[rig][name]
	if shared ~= "" then
		return shared
	end
	return registerDraft(root, name)
end

function WeaponAnimations.GetId(config: Types.WeaponConfig, rig: Types.RigName, name: Types.AnimationName): string
	local cache = resolved[rig][config.Id]
	if not cache then
		cache = {}
		resolved[rig][config.Id] = cache
	end
	local id = cache[name]
	if id == nil then
		id = resolve(rig, config, name)
		cache[name] = id
	end
	return id
end

return WeaponAnimations
