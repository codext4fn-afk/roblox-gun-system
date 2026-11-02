--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Raycast = require(WeaponSystem:WaitForChild("Raycast"))
local Settings = require(WeaponSystem:WaitForChild("Settings"))
local Types = require(WeaponSystem:WaitForChild("Types"))
local WeaponAxes = require(WeaponSystem:WaitForChild("WeaponAxes"))

local EffectSettings = Settings.Effects

local Effects = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local PARKED = CFrame.new(0, -10000, 0)
local SOOT_COLOR = Color3.fromRGB(14, 12, 10)
local CORE_COLOR = Color3.fromRGB(6, 5, 4)
local FALLBACK_SURFACE = Color3.fromRGB(120, 110, 100)
local MIN_SOUND_LIFETIME = 3

type SurfaceProfile = {
	dust: number,
	chips: number,
	sparks: number,
	haze: number,
	hole: boolean,
}

type Bullet = {
	tail: Attachment,
	head: Attachment,
	beam: Beam,
	from: Vector3,
	direction: Vector3,
	distance: number,
	traveled: number,
	result: RaycastResult?,
}

type HoleLayer = {
	part: Part,
	transparency: number,
}

type Hole = {
	scorch: Part,
	soot: Decal,
	token: number,
	tweens: { Tween },
	layers: { rim: HoleLayer, inner: HoleLayer, core: HoleLayer },
	chips: { HoleLayer },
}

type Casing = {
	part: Part,
	token: number,
}

local SURFACE_PROFILES: { [string]: SurfaceProfile } = {
	Hard = { dust = 5, chips = 7, sparks = 0, haze = 1, hole = true },
	Metal = { dust = 2, chips = 2, sparks = 12, haze = 0, hole = true },
	Soft = { dust = 9, chips = 3, sparks = 0, haze = 2, hole = false },
}
local SURFACE_BY_MATERIAL: { [Enum.Material]: string } = {
	[Enum.Material.Metal] = "Metal",
	[Enum.Material.DiamondPlate] = "Metal",
	[Enum.Material.CorrodedMetal] = "Metal",
	[Enum.Material.Foil] = "Metal",
	[Enum.Material.Grass] = "Soft",
	[Enum.Material.LeafyGrass] = "Soft",
	[Enum.Material.Sand] = "Soft",
	[Enum.Material.Ground] = "Soft",
	[Enum.Material.Mud] = "Soft",
	[Enum.Material.Snow] = "Soft",
}

local rng = Random.new()
local warnedMissingMuzzle: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local fxFolder = Instance.new("Folder")
fxFolder.Name = "GunFX"
fxFolder.Parent = workspace

local function sequence(from: number, to: number): NumberSequence
	return NumberSequence.new(from, to)
end

local function makeEmitter(parent: Instance, properties: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.LightInfluence = 0
	emitter.EmissionDirection = Enum.NormalId.Front
	for key, value in properties do
		(emitter :: any)[key] = value
	end
	emitter.Parent = parent
	return emitter
end

local function makeFxPart(size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	return part
end

local function makeAnchor(name: string): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = workspace.Terrain
	return attachment
end

local function makeLight(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Enabled = false
	light.Parent = parent
	return light
end

local lightTokens: { [PointLight]: number } = {}

local function pulseLight(light: PointLight, duration: number)
	light.Enabled = true
	local token = (lightTokens[light] or 0) + 1
	lightTokens[light] = token
	task.delay(duration, function()
		if lightTokens[light] == token then
			light.Enabled = false
		end
	end)
end

local function lookAlong(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

local function isCharacterPart(part: Instance): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function getSurfaceColor(result: RaycastResult): Color3
	local instance = result.Instance
	if instance:IsA("Terrain") then
		local ok, color = pcall(instance.GetMaterialColor, instance, result.Material)
		return if ok then color else FALLBACK_SURFACE
	end
	return instance.Color
end

local muzzleAnchor = makeAnchor("GunFX_Muzzle")
local muzzleEmitters = {
	flash = makeEmitter(muzzleAnchor, {
		Texture = FIRE,
		Color = ColorSequence.new(EffectSettings.FlashColor),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8, 0.25), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = sequence(0, 1),
		Lifetime = NumberRange.new(0.04, 0.06),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 1,
		ZOffset = 0.3,
	}),
	cone = makeEmitter(muzzleAnchor, {
		Texture = FIRE,
		Color = ColorSequence.new(Color3.fromRGB(255, 210, 120)),
		Size = sequence(0.45, 0),
		Transparency = sequence(0.1, 1),
		Lifetime = NumberRange.new(0.03, 0.05),
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(8, 8),
		LightEmission = 1,
	}),
	smoke = makeEmitter(muzzleAnchor, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(190, 190, 190)),
		Size = sequence(0.25, 1.4),
		Transparency = sequence(0.6, 1),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(15, 15),
		Drag = 4,
		Acceleration = Vector3.new(0, 1.2, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		LightInfluence = 1,
	}),
	sparks = makeEmitter(muzzleAnchor, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.fromRGB(255, 190, 90)),
		Size = sequence(0.08, 0),
		Lifetime = NumberRange.new(0.06, 0.14),
		Speed = NumberRange.new(20, 35),
		SpreadAngle = Vector2.new(18, 18),
		Drag = 6,
		LightEmission = 1,
	}),
}
local muzzleLight = makeLight(muzzleAnchor, EffectSettings.FlashColor, 12, 4)

local impactAnchor = makeAnchor("GunFX_Impact")
local impactEmitters = {
	dust = makeEmitter(impactAnchor, {
		Texture = SMOKE,
		Size = sequence(0.15, 0.9),
		Transparency = sequence(0.3, 1),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(35, 35),
		Drag = 5,
		Acceleration = Vector3.new(0, -2, 0),
		Rotation = NumberRange.new(0, 360),
		LightInfluence = 1,
	}),
	haze = makeEmitter(impactAnchor, {
		Texture = SMOKE,
		Size = sequence(0.4, 1.8),
		Transparency = sequence(0.75, 1),
		Lifetime = NumberRange.new(1.2, 1.8),
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(25, 25),
		Drag = 2,
		Acceleration = Vector3.new(0, 0.4, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		LightInfluence = 1,
	}),
	chips = makeEmitter(impactAnchor, {
		Texture = SMOKE,
		Size = sequence(0.07, 0.03),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, -35, 0),
		LightInfluence = 1,
	}),
	flash = makeEmitter(impactAnchor, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.fromRGB(255, 225, 170)),
		Size = sequence(0.35, 0),
		Transparency = sequence(0, 1),
		Lifetime = NumberRange.new(0.04, 0.06),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 1,
		ZOffset = 0.2,
	}),
	sparks = makeEmitter(impactAnchor, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 110)),
		Size = sequence(0.07, 0),
		Lifetime = NumberRange.new(0.1, 0.25),
		Speed = NumberRange.new(15, 25),
		SpreadAngle = Vector2.new(45, 45),
		Acceleration = Vector3.new(0, -25, 0),
		LightEmission = 1,
	}),
	flesh = makeEmitter(impactAnchor, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(120, 10, 10)),
		Size = sequence(0.2, 0.6),
		Transparency = sequence(0.2, 1),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(30, 30),
		Drag = 6,
		LightInfluence = 1,
	}),
}
local impactLight = makeLight(impactAnchor, Color3.fromRGB(255, 200, 130), 4, 2)

local function makeBullet(): Bullet
	local tail = makeAnchor("GunFX_BulletTail")
	local head = makeAnchor("GunFX_BulletHead")
	local beam = Instance.new("Beam")
	beam.Attachment0 = tail
	beam.Attachment1 = head
	beam.Color = ColorSequence.new(EffectSettings.TracerColor)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.6, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	beam.Width0 = 0.02
	beam.Width1 = 0.07
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = head
	return {
		tail = tail,
		head = head,
		beam = beam,
		from = Vector3.zero,
		direction = Vector3.zAxis,
		distance = 0,
		traveled = 0,
		result = nil,
	}
end

local bullets: { Bullet } = {}
local activeBullets: { [Bullet]: boolean } = {}
local nextBullet = 1
for index = 1, EffectSettings.MaxBullets do
	bullets[index] = makeBullet()
end

local holes: { Hole } = {}
local nextHole = 1

local casings: { Casing } = {}
local nextCasing = 1

local function makeHoleLayer(thickness: number, transparency: number): HoleLayer
	local part = makeFxPart(Vector3.new(thickness, 1, 1), Color3.new())
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 1
	part.CFrame = PARKED
	part.Parent = fxFolder
	return { part = part, transparency = transparency }
end

local function makeHole(): Hole
	local scorch = makeFxPart(Vector3.new(0.01, 1, 1), Color3.new())
	scorch.Transparency = 1
	scorch.CFrame = PARKED
	local soot = Instance.new("Decal")
	soot.Texture = SMOKE
	soot.Color3 = SOOT_COLOR
	soot.Transparency = 1
	soot.Face = Enum.NormalId.Right
	soot.Parent = scorch
	scorch.Parent = fxFolder
	return {
		scorch = scorch,
		soot = soot,
		token = 0,
		tweens = {},
		layers = {
			rim = makeHoleLayer(0.012, 0.2),
			inner = makeHoleLayer(0.013, 0),
			core = makeHoleLayer(0.014, 0),
		},
		chips = {
			makeHoleLayer(0.011, 0.1),
			makeHoleLayer(0.011, 0.1),
			makeHoleLayer(0.011, 0.1),
		},
	}
end

local function forEachHolePart(hole: Hole, callback: (HoleLayer) -> ())
	callback(hole.layers.rim)
	callback(hole.layers.inner)
	callback(hole.layers.core)
	for _, layer in hole.chips do
		callback(layer)
	end
end

local function placeLayer(layer: HoleLayer, size: number, color: Color3, cframe: CFrame)
	layer.part.Size = Vector3.new(layer.part.Size.X, size, size)
	layer.part.Color = color
	layer.part.CFrame = cframe
	layer.part.Transparency = layer.transparency
end

local function stopHoleTweens(hole: Hole)
	for _, tween in hole.tweens do
		tween:Cancel()
	end
	table.clear(hole.tweens)
end

local function fadeHole(hole: Hole, token: number)
	local info = TweenInfo.new(EffectSettings.HoleFadeTime)
	table.insert(hole.tweens, TweenService:Create(hole.soot, info, { Transparency = 1 }))
	forEachHolePart(hole, function(layer)
		table.insert(hole.tweens, TweenService:Create(layer.part, info, { Transparency = 1 }))
	end)
	for _, tween in hole.tweens do
		tween:Play()
	end
	task.delay(EffectSettings.HoleFadeTime, function()
		if hole.token ~= token then
			return
		end
		hole.scorch.CFrame = PARKED
		forEachHolePart(hole, function(layer)
			layer.part.CFrame = PARKED
		end)
	end)
end

local function addBulletHole(result: RaycastResult)
	local instance = result.Instance
	if not (instance:IsA("BasePart") and instance.Anchored) then
		return
	end
	local hole = holes[nextHole] or makeHole()
	holes[nextHole] = hole
	nextHole = nextHole % EffectSettings.MaxHoles + 1
	stopHoleTweens(hole)
	hole.token += 1
	local token = hole.token

	local normal = result.Normal
	local reference = if math.abs(normal.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
	local base = CFrame.fromMatrix(result.Position, normal, normal:Cross(reference).Unit)
		* CFrame.Angles(rng:NextNumber(0, math.pi * 2), 0, 0)

	local h, s, v = getSurfaceColor(result):ToHSV()
	local size = rng:NextNumber(0.13, 0.19)

	hole.scorch.Size = Vector3.new(0.01, size * 3.4, size * 3.4)
	hole.scorch.CFrame = base * CFrame.new(0.004, 0, 0)
	hole.soot.Transparency = 0.35
	placeLayer(hole.layers.rim, size * 1.7, Color3.fromHSV(h, s * 0.8, v * 0.45), base * CFrame.new(0.008, 0, 0))
	placeLayer(hole.layers.inner, size * 1.15, Color3.fromHSV(h, s, v * 0.25), base * CFrame.new(0.011, 0, 0))
	placeLayer(hole.layers.core, size * 0.7, CORE_COLOR, base * CFrame.new(0.014, 0, 0))

	local chipColor = Color3.fromHSV(h, s * 0.6, math.clamp(v * 0.7, 0.08, 1))
	for _, chip in hole.chips do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = size * rng:NextNumber(0.8, 1.2)
		local offset = CFrame.new(0.009, math.cos(angle) * distance, math.sin(angle) * distance)
		placeLayer(chip, size * rng:NextNumber(0.25, 0.45), chipColor, base * offset)
	end

	task.delay(EffectSettings.HoleLifetime, function()
		if hole.token == token then
			fadeHole(hole, token)
		end
	end)
end

local function playImpact(result: RaycastResult)
	impactAnchor.WorldCFrame = lookAlong(result.Position, result.Normal)
	if isCharacterPart(result.Instance) then
		impactEmitters.flesh:Emit(6)
		return
	end

	local profile = SURFACE_PROFILES[SURFACE_BY_MATERIAL[result.Material] or "Hard"]
	local h, s, v = getSurfaceColor(result):ToHSV()
	local dustColor = ColorSequence.new(Color3.fromHSV(h, s * 0.6, math.clamp(v * 1.1, 0.25, 0.9)))
	impactEmitters.dust.Color = dustColor
	impactEmitters.haze.Color = dustColor
	impactEmitters.chips.Color = ColorSequence.new(Color3.fromHSV(h, s, v * 0.7))

	impactEmitters.dust:Emit(profile.dust)
	impactEmitters.haze:Emit(profile.haze)
	impactEmitters.chips:Emit(profile.chips)
	impactEmitters.sparks:Emit(profile.sparks)
	impactEmitters.flash:Emit(1)
	pulseLight(impactLight, 0.04)
	if profile.hole then
		addBulletHole(result)
	end
end

local function finishBullet(bullet: Bullet, arrived: boolean)
	bullet.beam.Enabled = false
	activeBullets[bullet] = nil
	local result = bullet.result
	bullet.result = nil
	if arrived and result then
		playImpact(result)
	end
end

RunService.PreRender:Connect(function(deltaTime: number)
	for bullet in activeBullets do
		bullet.traveled += EffectSettings.BulletSpeed * deltaTime
		local headDistance = math.min(bullet.traveled, bullet.distance)
		local tailDistance = math.max(headDistance - EffectSettings.StreakLength, 0)
		bullet.head.WorldPosition = bullet.from + bullet.direction * headDistance
		bullet.tail.WorldPosition = bullet.from + bullet.direction * tailDistance
		if bullet.traveled >= bullet.distance then
			finishBullet(bullet, true)
		end
	end
end)

function Effects.GetMuzzlePosition(tool: Tool): Vector3?
	local handle = WeaponAxes.GetHandle(tool)
	if not handle then
		return nil
	end
	local muzzle = WeaponAxes.GetAttachment(handle, "Muzzle")
	if muzzle then
		return muzzle.WorldPosition
	end
	if not warnedMissingMuzzle[tool] then
		warnedMissingMuzzle[tool] = true
		warn(`{tool.Name}: add an Attachment named 'Muzzle' in Handle at the barrel tip`)
	end
	return handle.Position
end

function Effects.MuzzleFlash(tool: Tool, direction: Vector3?)
	local position = Effects.GetMuzzlePosition(tool)
	if not position or not direction or direction.Magnitude < 1e-3 then
		return
	end
	muzzleAnchor.WorldCFrame = lookAlong(position, direction.Unit)
	muzzleEmitters.flash:Emit(2)
	muzzleEmitters.cone:Emit(3)
	muzzleEmitters.smoke:Emit(2)
	muzzleEmitters.sparks:Emit(4)
	pulseLight(muzzleLight, 0.05)
end

function Effects.Bullet(from: Vector3, to: Vector3, result: RaycastResult?)
	local offset = to - from
	local distance = offset.Magnitude
	if distance < 0.5 then
		if result then
			playImpact(result)
		end
		return
	end

	local bullet = bullets[nextBullet]
	nextBullet = nextBullet % EffectSettings.MaxBullets + 1
	if activeBullets[bullet] then
		finishBullet(bullet, false)
	end

	bullet.from = from
	bullet.direction = offset / distance
	bullet.distance = distance
	bullet.traveled = 0
	bullet.result = result
	bullet.tail.WorldPosition = from
	bullet.head.WorldPosition = from
	bullet.beam.Enabled = true
	activeBullets[bullet] = true
end

function Effects.RemoteBullet(from: Vector3, to: Vector3, shooterCharacter: Instance)
	local offset = to - from
	local result: RaycastResult? = nil
	if offset.Magnitude > 0.1 then
		result = workspace:Raycast(from, offset * 1.02, Raycast.Excluding({ shooterCharacter }))
	end
	Effects.Bullet(from, to, result)
end

local function getCasing(config: Types.WeaponConfig): Casing
	local casing = casings[nextCasing]
	if not casing then
		local part = Instance.new("Part")
		part.Material = Enum.Material.Metal
		part.Shape = Enum.PartType.Cylinder
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.4)
		part.Parent = fxFolder
		casing = { part = part, token = 0 }
		casings[nextCasing] = casing
	end
	nextCasing = nextCasing % EffectSettings.MaxCasings + 1
	casing.token += 1
	casing.part.Size = config.CasingSize
	casing.part.Color = config.CasingColor
	return casing
end

function Effects.EjectCasing(tool: Tool, config: Types.WeaponConfig)
	local handle = WeaponAxes.GetHandle(tool)
	if not handle then
		return
	end
	local ejection = WeaponAxes.GetAttachment(handle, "Ejection")
	local position = if ejection then ejection.WorldPosition else handle.Position
	local camera = workspace.CurrentCamera.CFrame

	local casing = getCasing(config)
	local token = casing.token
	local part = casing.part
	part.Anchored = false
	part.CanCollide = false
	part.Transparency = 0
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	part.AssemblyLinearVelocity = camera.RightVector * rng:NextNumber(9, 13)
		+ Vector3.new(0, rng:NextNumber(6, 9), 0)
		- camera.LookVector * rng:NextNumber(1, 3)
	part.AssemblyAngularVelocity =
		Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(-25, 25), rng:NextNumber(-25, 25))

	task.delay(0.08, function()
		if casing.token == token then
			part.CanCollide = true
		end
	end)
	task.delay(EffectSettings.CasingLifetime, function()
		if casing.token == token then
			part.Anchored = true
			part.Transparency = 1
			part.CFrame = PARKED
		end
	end)
end

function Effects.PlaySound(tool: Tool, name: string)
	local handle = WeaponAxes.GetHandle(tool)
	local template = handle and handle:FindFirstChild(name)
	if not (handle and template and template:IsA("Sound")) then
		return
	end
	local sound = template:Clone()
	sound.Parent = handle
	sound:Play()
	task.delay(math.max(sound.TimeLength, MIN_SOUND_LIFETIME) + 0.1, function()
		sound:Destroy()
	end)
end

return Effects
