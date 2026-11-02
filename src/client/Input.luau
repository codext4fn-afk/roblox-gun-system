--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Settings = require(ReplicatedStorage:WaitForChild("WeaponSystem"):WaitForChild("Settings"))

export type Handler = (isPressed: boolean) -> ()
export type Handlers = { [Settings.ActionName]: Handler }

local Input = {}

local ACTION_PREFIX = "Gun"
local ACTIONS: { Settings.ActionName } = { "Fire", "Aim", "Reload", "SwitchShoulder" }

local GAMEPAD_INPUTS: { [Enum.UserInputType]: boolean } = {}
for index = 1, 8 do
	GAMEPAD_INPUTS[(Enum.UserInputType :: any)["Gamepad" .. index]] = true
end

local toggled: { [Settings.ActionName]: boolean } = {}

local function makeActionHandler(action: Settings.ActionName, handler: Handler)
	local touch = Settings.Touch[action]
	return function(_: string, inputState: Enum.UserInputState, inputObject: InputObject): Enum.ContextActionResult
		local isTouch = inputObject.UserInputType == Enum.UserInputType.Touch
		if isTouch and touch and touch.Toggle then
			if inputState == Enum.UserInputState.Begin then
				toggled[action] = not toggled[action]
				handler(toggled[action] == true)
			end
			return Enum.ContextActionResult.Sink
		end
		if inputState == Enum.UserInputState.Begin then
			handler(true)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			handler(false)
		end
		return Enum.ContextActionResult.Sink
	end
end

function Input.Bind(handlers: Handlers)
	Input.Unbind()
	for _, action: Settings.ActionName in ACTIONS do
		local handler = handlers[action]
		local inputs = Settings.Controls[action]
		if handler and inputs then
			local name = ACTION_PREFIX .. action
			ContextActionService:BindAction(name, makeActionHandler(action, handler), true, table.unpack(inputs))
			local touch = Settings.Touch[action]
			if touch then
				ContextActionService:SetTitle(name, touch.Title)
				ContextActionService:SetPosition(name, touch.Position)
			end
		end
	end
end

function Input.Unbind()
	for _, action: Settings.ActionName in ACTIONS do
		ContextActionService:UnbindAction(ACTION_PREFIX .. action)
	end
	table.clear(toggled)
end

function Input.IsUsingGamepad(): boolean
	return GAMEPAD_INPUTS[UserInputService:GetLastInputType()] == true
end

function Input.IsUsingTouch(): boolean
	return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

function Input.UsesScreenCenter(): boolean
	return Input.IsUsingGamepad()
		or Input.IsUsingTouch()
		or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
end

return Input
