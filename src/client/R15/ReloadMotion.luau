--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local AngleMath = require(WeaponSystem:WaitForChild("AngleMath"))
local Types = require(WeaponSystem:WaitForChild("Types"))
local WeaponAxes = require(WeaponSystem:WaitForChild("WeaponAxes"))

local Effects = require(script.Parent.Parent.Effects)
local Mechanics = require(script.Parent.Parent.Mechanics)

export type Body = {
	root: CFrame,
	lowerTorso: CFrame,
	upperTorso: CFrame,
	head: CFrame,
}

export type Options = {
	onSeated: (() -> ())?,
	chamber: boolean?,
}

type Key = {
	at: number,
	palm: CFrame,
	holds: boolean,
}

type Timeline = {
	seatAt: number,
	tapAt: number?,
	rackReach: number?,
	rackOpen: number?,
	rackClose: number?,
	returnAt: number,
}

type Bolt = {
	joint: Motor6D,
	base: CFrame,
	travel: Vector3,
	palm: CFrame,
}

local ReloadMotion = {}
ReloadMotion.__index = ReloadMotion

export type ReloadMotion = typeof(setmetatable(
	{} :: {
		tool: Tool,
		config: Types.WeaponConfig,
		style: Types.ReloadStyle,
		times: Types.MagazineConfig,
		duration: number,
		progress: number,
		fired: { [string]: boolean },
		onSeated: (() -> ())?,
		tap: boolean,
		hidden: { [BasePart]: number },
		part: BasePart?,
		joint: Motor6D?,
		prop: BasePart?,
		seated: CFrame?,
		down: Vector3,
		length: number,
		palmRotation: CFrame?,
		palmOnSeated: CFrame,
		palmToMagazine: CFrame?,
		bolt: Bolt?,
		pouch: (body: Body) -> Vector3,
		line: Timeline,
	},
	ReloadMotion
))

local MAGAZINE_PALM = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.zAxis, Vector3.xAxis)
local HANDLE_PALM = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, Vector3.zAxis, -Vector3.yAxis)
local GRIP_ALONG = 0.45
local PULL_CLEAR = 0.4
local LINE_UP = 0.28
local ROCK_ANGLE = math.rad(22)
local DEFAULT_MAGAZINE_LENGTH = 0.6
local POUCHES: { [string]: (body: Body) -> Vector3 } = {
	Chest = function(body: Body): Vector3
		return body.upperTorso * Vector3.new(-0.45, -0.55, -0.75)
	end,
	Hip = function(body: Body): Vector3
		return body.lowerTorso * Vector3.new(-0.75, -0.05, -0.35)
	end,
}
local SLIDE = 0.06
local SEAT = 0.05
local TAP = 0.07
local RETURN = 0.14
local RACK_REACH, RACK_PULL, RACK_RELEASE = 0.07, 0.06, 0.03

local smoothstep = AngleMath.Smoothstep

local function wellGeometry(tool: Tool, part: BasePart?, joint: Motor6D?): (CFrame?, Vector3, number)
	local forward = WeaponAxes.ForwardAxis(tool)
	if joint and part then
		local position = joint.C0.Position
		local sideways = position - forward * position:Dot(forward)
		local down = if sideways.Magnitude > 1e-3 then sideways.Unit else -Vector3.yAxis
		local rotation, size = joint.C0.Rotation, part.Size
		local length = math.abs(rotation.RightVector:Dot(down)) * size.X
			+ math.abs(rotation.UpVector:Dot(down)) * size.Y
			+ math.abs(rotation.LookVector:Dot(down)) * size.Z
		return joint.C0, down, length
	end
	local well = WeaponAxes.GetAttachment(WeaponAxes.GetHandle(tool), "MagazineWell")
	if well then
		local authored = well:GetAttribute("MagazineLength")
		local scale = tool:GetAttribute("R15Scale")
		local length = (if type(authored) == "number" then authored else DEFAULT_MAGAZINE_LENGTH)
			* (if type(scale) == "number" then scale else 1)
		local down = -well.CFrame.UpVector
		return CFrame.new(well.Position + down * length / 2) * well.CFrame.Rotation, down, length
	end
	return nil, -Vector3.yAxis, 0
end

local function makeProp(name: string): BasePart?
	local props = WeaponSystem:FindFirstChild("Props")
	local template = props and name ~= "" and props:FindFirstChild(name)
	if not (template and template:IsA("BasePart")) then
		return nil
	end
	local prop = template:Clone()
	prop.Anchored = true
	prop.CanCollide, prop.CanQuery, prop.CanTouch = false, false, false
	prop.Transparency = 1
	prop.Parent = workspace
	return prop
end

local function shouldRack(rack: Types.RackRule, chamber: boolean?): boolean
	return rack == "Always" or (rack == "Empty" and chamber == true)
end

local function eyeRotation(tool: Tool): CFrame
	return CFrame.lookAt(Vector3.zero, WeaponAxes.ForwardAxis(tool), Vector3.yAxis).Rotation
end

function ReloadMotion.new(tool: Tool, config: Types.WeaponConfig, options: Options?): ReloadMotion
	local settings: Options = options or {}
	local magazine = config.Magazine
	local reload = config.Reload
	local joint, part = WeaponAxes.FindJoint(tool, magazine.Part)
	local seated, down, length = wellGeometry(tool, part, joint)
	local palmRotation = if seated then eyeRotation(tool) * MAGAZINE_PALM else nil
	local palmOnSeated = if seated and palmRotation
		then CFrame.new(seated.Position + down * length * GRIP_ALONG) * palmRotation
		else CFrame.identity

	local bolt: Bolt? = nil
	local boltJoint = WeaponAxes.FindJoint(tool, config.Bolt.Part)
	if boltJoint and (reload.Style == "BoltFeed" or shouldRack(reload.Rack, settings.chamber)) then
		bolt = {
			joint = boltJoint,
			base = boltJoint.C0,
			travel = -WeaponAxes.ForwardAxis(tool) * config.Bolt.Travel * 1.2,
			palm = CFrame.new(boltJoint.C0.Position - Vector3.new(0, 0, 0.12)) * (eyeRotation(tool) * HANDLE_PALM),
		}
	end

	local self = setmetatable({
		tool = tool,
		config = config,
		style = reload.Style,
		times = magazine,
		duration = config.ReloadTime,
		progress = 0,
		fired = {},
		onSeated = settings.onSeated,
		tap = reload.Tap,
		hidden = {},
		part = part,
		joint = joint,
		prop = if part then nil else makeProp(reload.Prop),
		seated = seated,
		down = down,
		length = length,
		palmRotation = palmRotation,
		palmOnSeated = palmOnSeated,
		palmToMagazine = if seated then palmOnSeated:Inverse() * seated else nil,
		bolt = bolt,
		pouch = POUCHES[reload.Pouch] or POUCHES.Chest,
		line = { seatAt = 0, returnAt = 0 },
	}, ReloadMotion)
	self:_buildTimeline()
	return self
end

function ReloadMotion._buildTimeline(self: ReloadMotion)
	local t = self.times
	local line: Timeline = { seatAt = t.In + SEAT, returnAt = 0 }
	local after = line.seatAt
	if self.tap and self.style ~= "BoltFeed" then
		line.tapAt = after + TAP
		after = after + TAP
	end
	if self.bolt and self.style ~= "BoltFeed" then
		local reach = after + RACK_REACH
		local open = reach + RACK_PULL
		local close = open + RACK_RELEASE
		line.rackReach, line.rackOpen, line.rackClose = reach, open, close
		after = close
	end
	line.returnAt = math.min(after + RETURN, 0.98)
	self.line = line
end

function ReloadMotion._fire(self: ReloadMotion, name: string, at: number?, action: () -> ())
	if at and self.progress >= at and not self.fired[name] then
		self.fired[name] = true
		action()
	end
end

function ReloadMotion._setHidden(self: ReloadMotion, part: BasePart?, hidden: boolean)
	if not part then
		return
	end
	if hidden and self.hidden[part] == nil then
		self.hidden[part] = part.Transparency
		part.Transparency = 1
	elseif not hidden and self.hidden[part] ~= nil then
		part.Transparency = self.hidden[part]
		self.hidden[part] = nil
	end
end

function ReloadMotion.Advance(self: ReloadMotion, deltaTime: number): boolean
	self.progress += deltaTime / self.duration
	local t, line, tool = self.times, self.line, self.tool
	self:_fire("out", t.Out, function()
		Effects.PlaySound(tool, "MagOut")
	end)
	self:_fire("drop", t.Drop, function()
		local part = self.part
		if part then
			Mechanics.DropMagazine(part, self.config.Magazine.DropLifetime)
			self:_setHidden(part, true)
		end
	end)
	self:_fire("grab", t.Grab, function()
		self:_setHidden(self.part, false)
		local prop = self.prop
		if prop then
			prop.Transparency = 0
		end
	end)
	self:_fire("seat", line.seatAt, function()
		Effects.PlaySound(tool, "MagIn")
		local prop = self.prop
		if prop then
			prop.Transparency = 1
		end
		local onSeated = self.onSeated
		if onSeated then
			onSeated()
		end
	end)
	return self.progress < 1
end

function ReloadMotion._boltOpen(self: ReloadMotion): number
	local p, t, line = self.progress, self.times, self.line
	if not self.bolt then
		return 0
	end
	if self.style == "BoltFeed" then
		local open = smoothstep((p - t.Out) / 0.1)
		local close = smoothstep((p - (line.seatAt + 0.08)) / 0.06)
		return open * (1 - close)
	end
	local reach, open, close = line.rackReach, line.rackOpen, line.rackClose
	if not (reach and open and close) then
		return 0
	end
	if p < reach then
		return 0
	elseif p < open then
		return smoothstep((p - reach) / (open - reach))
	end
	return 1 - smoothstep((p - open) / (close - open))
end

function ReloadMotion._keys(self: ReloadMotion, handle: CFrame, supportPalm: CFrame, body: Body): { Key }
	local t, line = self.times, self.line
	local keys: { Key } = { { at = 0, palm = supportPalm, holds = false } }
	local function add(at: number, palm: CFrame, holds: boolean)
		table.insert(keys, { at = at, palm = palm, holds = holds })
	end
	local seated = self.seated
	if not seated then
		add(1, supportPalm, false)
		return keys
	end
	local pouch = CFrame.new(self.pouch(body)) * (handle * (self.palmRotation or CFrame.identity)).Rotation
	local bolt = self.bolt
	local function boltHand(open: number): CFrame
		return if bolt then handle * CFrame.new(bolt.travel * open) * bolt.palm else supportPalm
	end

	local down, length = self.down, self.length
	local depth = self.config.Magazine.InsertDepth
	local forward = WeaponAxes.ForwardAxis(self.tool)
	local function onMag(distance: number, rock: number?): CFrame
		local frame = CFrame.new(down * distance) * self.palmOnSeated
		if rock and rock ~= 0 then
			local pivot = seated.Position - forward * length * 0.2
			local axis = forward:Cross(down)
			frame = CFrame.new(pivot) * CFrame.fromAxisAngle(axis.Unit, rock) * CFrame.new(-pivot) * frame
		end
		return handle * frame
	end
	local rock = if self.style == "RockIn" then ROCK_ANGLE else 0

	if self.style == "BoltFeed" then
		add(t.Out, boltHand(0), false)
		add(t.Out + 0.1, boltHand(1), false)
		add(t.Drop, pouch, false)
		add(t.Grab, pouch, true)
		add(t.In - SLIDE, onMag(length * LINE_UP), true)
		add(t.In, onMag(depth * 0.5), true)
		add(line.seatAt, onMag(0), true)
		add(line.seatAt + 0.05, boltHand(1), false)
		add(line.seatAt + 0.12, boltHand(0), false)
	else
		local own = self.part ~= nil
		add(t.Out, onMag(0), own)
		if rock ~= 0 then
			add(t.Out + SLIDE * 0.6, onMag(depth * 0.3, rock), own)
		end
		add(t.Out + SLIDE, onMag(depth, rock), own)
		add(t.Drop, onMag(depth + length * PULL_CLEAR, rock), own)
		add((t.Drop + t.Grab) / 2, pouch, false)
		add(t.Grab, pouch, true)
		add(t.In - SLIDE, onMag(depth + length * LINE_UP, rock), true)
		add(t.In, onMag(depth, rock), true)
		add(line.seatAt, onMag(0), true)
		local tapAt = line.tapAt
		if tapAt then
			add(tapAt - TAP * 0.5, onMag(length * 1.25), false)
			add(tapAt, onMag(length * 0.95), false)
		end
		local reach, open, close = line.rackReach, line.rackOpen, line.rackClose
		if reach and open and close then
			add(reach, boltHand(0), false)
			add(open, boltHand(1), false)
			add(close, boltHand(0), false)
		end
	end
	add(line.returnAt, supportPalm, false)
	add(1, supportPalm, false)
	return keys
end

function ReloadMotion.Evaluate(self: ReloadMotion, handle: CFrame, supportPalm: CFrame, body: Body): CFrame
	local keys = self:_keys(handle, supportPalm, body)
	local progress = math.clamp(self.progress, 0, 1)
	local palm, holding = keys[#keys].palm, false
	for index = 2, #keys do
		local from, to = keys[index - 1], keys[index]
		if progress <= to.at then
			local span = math.max(to.at - from.at, 1e-3)
			palm = from.palm:Lerp(to.palm, smoothstep((progress - from.at) / span))
			holding = from.holds and to.holds
			break
		end
	end
	local palmToMagazine = self.palmToMagazine
	local held = if holding and progress < self.line.seatAt and palmToMagazine then palm * palmToMagazine else nil
	local joint, seated = self.joint, self.seated
	if joint and seated then
		joint.C0 = if held then handle:Inverse() * held else seated
	end
	local prop = self.prop
	if prop and held then
		prop.CFrame = held
	end
	local bolt = self.bolt
	if bolt then
		bolt.joint.C0 = CFrame.new(bolt.travel * self:_boltOpen()) * bolt.base
	end
	return palm
end

function ReloadMotion.Finish(self: ReloadMotion)
	local joint, seated = self.joint, self.seated
	if joint and seated then
		joint.C0 = seated
	end
	local bolt = self.bolt
	if bolt then
		bolt.joint.C0 = bolt.base
	end
	for part in self.hidden do
		self:_setHidden(part, false)
	end
	local prop = self.prop
	if prop then
		prop:Destroy()
		self.prop = nil
	end
end

return ReloadMotion
