--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local AngleMath = require(WeaponSystem:WaitForChild("AngleMath"))
local HitZones = require(WeaponSystem:WaitForChild("HitZones"))
local Raycast = require(WeaponSystem:WaitForChild("Raycast"))
local Remotes = require(WeaponSystem:WaitForChild("Remotes"))
local Spread = require(WeaponSystem:WaitForChild("Spread"))
local Types = require(WeaponSystem:WaitForChild("Types"))
local WeaponAxes = require(WeaponSystem:WaitForChild("WeaponAxes"))
local WeaponRegistry = require(WeaponSystem:WaitForChild("WeaponRegistry"))

local AimPose = require(script.Parent.AimPose)
local AnimationTracks = require(script.Parent.AnimationTracks)
local Camera = require(script.Parent.Camera)
local ClientTypes = require(script.Parent.ClientTypes)
local Effects = require(script.Parent.Effects)
local FirstPersonView = require(script.Parent.FirstPersonView)
local Hud = require(script.Parent.Hud)
local Input = require(script.Parent.Input)
local Mechanics = require(script.Parent.Mechanics)
local RemoteWeapons = require(script.Parent.RemoteWeapons)
local Rigs = require(script.Parent.Rigs)
local ScopeOverlay = require(script.Parent.ScopeOverlay)

local player = Players.LocalPlayer

local WeaponController = {}

local FRAME_BIND_NAME = "GunClientFrame"
local FRAME_PRIORITY = Enum.RenderPriority.Camera.Value + 5
local ALIGN_MIN_DISTANCE = 2
local POSE_FADE = 0.15

local ADS_ATTRIBUTE = "AimingDownSights"
local SPRINTING_ATTRIBUTE = "Sprinting"
local MOVEMENT_MANAGED_ATTRIBUTE = "MovementManaged"

local rng = Random.new()
local current: ClientTypes.Equipped? = nil

local function nextNumber(): number
	return rng:NextNumber()
end

local function ownsWalkSpeed(equipped: ClientTypes.Equipped): boolean
	return not equipped.character:GetAttribute(MOVEMENT_MANAGED_ATTRIBUTE)
end

local function getAmmo(equipped: ClientTypes.Equipped): number
	local ammo = equipped.tool:GetAttribute("Ammo")
	return if type(ammo) == "number" then ammo else equipped.config.MagSize
end

local function isReloading(equipped: ClientTypes.Equipped): boolean
	return equipped.tool:GetAttribute("Reloading") == true
end

local function refreshAmmoDisplay()
	local equipped = current
	if equipped then
		Hud.SetAmmo(getAmmo(equipped), equipped.config.MagSize, isReloading(equipped))
	end
end

local function getCurrentSpread(equipped: ClientTypes.Equipped): number
	return Spread.Current(equipped.config.HipSpread, equipped.config.AimSpread, Camera.GetAimAlpha())
end

local function getAimTarget(equipped: ClientTypes.Equipped): Vector3
	local origin, direction = Camera.GetAimRay(Input.UsesScreenCenter())
	local head = equipped.character:FindFirstChild("Head")
	local depth = if head and head:IsA("BasePart") then math.max((head.Position - origin):Dot(direction), 0) else 0
	return Raycast.EndPoint(origin + direction * depth, direction, equipped.config.Range, equipped.params)
end

local function updatePoseAnimations(equipped: ClientTypes.Equipped, isAiming: boolean)
	local tracks = equipped.tracks
	local aim, hold = tracks.Aim, tracks.Hold
	if aim then
		if isAiming then
			aim:Play(POSE_FADE)
		else
			aim:Stop(POSE_FADE)
		end
	elseif hold then
		if isAiming then
			hold:Stop(POSE_FADE)
		else
			hold:Play(POSE_FADE)
		end
	end
end

local function setAiming(isAiming: boolean)
	local equipped = current
	if not equipped or equipped.aiming == isAiming then
		return
	end
	equipped.aiming = isAiming
	if not isAiming then
		equipped.triggerHeld = false
	end
	Remotes.SetAiming:FireServer(isAiming)
	Camera.SetAiming(isAiming)
	updatePoseAnimations(equipped, isAiming)
end

local function setZoom(isZooming: boolean)
	local equipped = current
	if not equipped or equipped.zooming == isZooming then
		return
	end
	equipped.zooming = isZooming
	Camera.SetZoom(isZooming)
	equipped.character:SetAttribute(ADS_ATTRIBUTE, isZooming)
	if ownsWalkSpeed(equipped) then
		equipped.humanoid.WalkSpeed = if isZooming then equipped.config.AimWalkSpeed else equipped.walkSpeed
	end
end

local function refreshAiming()
	local equipped = current
	if equipped then
		setAiming(equipped.zooming or Camera.IsFirstPerson())
	end
end

local function alignGunToCrosshair(equipped: ClientTypes.Equipped, deltaTime: number)
	local torso = equipped.character:FindFirstChild(equipped.rig.AlignTorso)
	local gunOrigin, gunDirection = nil, nil
	if torso and torso:IsA("BasePart") and equipped.aiming and Camera.IsFirstPerson() then
		gunOrigin, gunDirection = WeaponAxes.GunRay(equipped.tool)
	end
	if not (torso and torso:IsA("BasePart") and gunOrigin and gunDirection) then
		AimPose.ClearAlign(deltaTime)
		return
	end
	local screenOrigin, screenDirection = Camera.GetAimRay(true)
	local target = Raycast.EndPoint(screenOrigin, screenDirection, equipped.config.Range, equipped.params)
	local toTarget = target - gunOrigin
	if toTarget.Magnitude < ALIGN_MIN_DISTANCE then
		return
	end
	local desired = torso.CFrame:VectorToObjectSpace(toTarget.Unit)
	local actual = torso.CFrame:VectorToObjectSpace(gunDirection)
	AimPose.Align(
		AngleMath.WrapAngle(AngleMath.YawOf(desired) - AngleMath.YawOf(actual)),
		AngleMath.PitchOf(desired) - AngleMath.PitchOf(actual),
		deltaTime
	)
end

local function requestReload()
	local equipped = current
	if not equipped or isReloading(equipped) or getAmmo(equipped) >= equipped.config.MagSize then
		return
	end
	local character, tool, config = equipped.character, equipped.tool, equipped.config
	Remotes.Reload:FireServer(tool)
	Effects.PlaySound(tool, "Reload")
	equipped.rig.Reload(character, tool, config, {
		onSeated = function()
			AimPose.Kick(character, config.Magazine.SeatKick)
		end,
		chamber = getAmmo(equipped) <= 0,
		track = equipped.tracks.Reload,
		isTracked = function()
			return AimPose.IsTracked(character)
		end,
		isLocal = true,
	})
end

local function showShot(equipped: ClientTypes.Equipped, origin: Vector3, aimDirection: Vector3, directions: { Vector3 })
	local tool, config = equipped.tool, equipped.config
	local muzzle = Effects.GetMuzzlePosition(tool) or origin
	local hitSomeone, headshot = false, false
	for _, direction in directions do
		local result = Raycast.Cast(origin, direction, config.Range, equipped.params)
		Effects.Bullet(muzzle, if result then result.Position else origin + direction * config.Range, result)
		local part = result and result.Instance
		if part and part:IsA("BasePart") and HitZones.GetLivingHumanoid(part) then
			hitSomeone = true
			headshot = headshot or HitZones.Get(part) == "Head"
		end
	end
	if hitSomeone then
		Hud.Hitmarker(headshot)
	end

	Effects.MuzzleFlash(tool, aimDirection)
	if config.EjectCasings then
		Effects.EjectCasing(tool, config)
	end
	Effects.PlaySound(tool, "Fire")
	Mechanics.CycleBolt(tool, config)
	Camera.Kick(config.Recoil * config.AimRecoilMultiplier)
	Camera.Shake(config.CameraShake)
	AimPose.Kick(equipped.character, config.ArmKick)
	local fireTrack = equipped.tracks.Fire
	if fireTrack then
		fireTrack:Play(0.05)
	end
end

local function fire(equipped: ClientTypes.Equipped)
	local tool, config = equipped.tool, equipped.config
	if not equipped.aiming then
		equipped.triggerHeld = false
		return
	end
	if equipped.character:GetAttribute(SPRINTING_ATTRIBUTE) then
		return
	end
	local now = os.clock()
	if now - equipped.lastShot < config.FireInterval or isReloading(equipped) then
		return
	end
	if getAmmo(equipped) <= 0 then
		equipped.triggerHeld = false
		Effects.PlaySound(tool, "Empty")
		requestReload()
		return
	end
	local head = equipped.character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end

	equipped.lastShot = now
	if config.Mode == "Semi" then
		equipped.triggerHeld = false
	end

	local origin = head.Position
	local toTarget = getAimTarget(equipped) - origin
	local _, centerDirection = Camera.GetAimRay(true)
	local aimDirection = if toTarget.Magnitude > 1 then toTarget.Unit else centerDirection
	local directions = Spread.Pattern(aimDirection, getCurrentSpread(equipped), config.Pellets, nextNumber)

	Remotes.Fire:FireServer(tool, origin, aimDirection, directions)
	showShot(equipped, origin, aimDirection, directions)
end

local inputHandlers: Input.Handlers = {
	Fire = function(isPressed: boolean)
		local equipped = current
		if equipped then
			equipped.triggerHeld = isPressed and equipped.aiming
		end
	end,
	Aim = function(isPressed: boolean)
		setZoom(isPressed)
		refreshAiming()
	end,
	Reload = function(isPressed: boolean)
		if isPressed then
			requestReload()
		end
	end,
	SwitchShoulder = function(isPressed: boolean)
		if isPressed then
			Camera.ToggleShoulder()
		end
	end,
}

local function unequip()
	local equipped = current
	if not equipped then
		return
	end
	Input.Unbind()
	setZoom(false)
	setAiming(false)
	Mechanics.Cancel(equipped.tool)
	for _, connection in equipped.connections do
		connection:Disconnect()
	end
	for _, track in equipped.tracks do
		track:Stop(POSE_FADE)
	end
	equipped.rig.Unequip(equipped)
	equipped.character:SetAttribute(ADS_ATTRIBUTE, nil)
	if equipped.humanoid.Parent and ownsWalkSpeed(equipped) then
		equipped.humanoid.WalkSpeed = equipped.walkSpeed
	end
	Camera.Disable()
	FirstPersonView.Disable()
	ScopeOverlay.Hide()
	Hud.Hide()
	current = nil
end

local function equip(tool: Tool, config: Types.WeaponConfig)
	local character = tool.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rig = Rigs.Get(character)
	if not (character and character:IsA("Model") and humanoid and rig) then
		return
	end
	unequip()

	local equipped: ClientTypes.Equipped = {
		tool = tool,
		config = config,
		character = character,
		humanoid = humanoid,
		rig = rig,
		params = Raycast.Excluding({ character }),
		tracks = AnimationTracks.Load(humanoid, config, rig.Name),
		walkSpeed = humanoid.WalkSpeed,
		lastShot = 0,
		triggerHeld = false,
		aiming = false,
		zooming = false,
		push = 0,
		connections = {
			tool:GetAttributeChangedSignal("Ammo"):Connect(refreshAmmoDisplay),
			tool:GetAttributeChangedSignal("Reloading"):Connect(refreshAmmoDisplay),
		},
	}
	current = equipped

	local hold = equipped.tracks.Hold
	if hold then
		hold:Play(POSE_FADE)
	end
	Camera.Enable(rig.ViewConfig(config), workspace.CurrentCamera.FieldOfView, tool)
	FirstPersonView.Enable(character)
	Input.Bind(inputHandlers)
	local displayName = tool:GetAttribute("DisplayName")
	Hud.Show(if type(displayName) == "string" then displayName else tool.Name)
	refreshAmmoDisplay()
end

local function onFrame(deltaTime: number)
	local equipped = current
	if not equipped then
		return
	end
	refreshAiming()
	alignGunToCrosshair(equipped, deltaTime)
	if equipped.triggerHeld then
		fire(equipped)
	end

	local isFirstPerson = Camera.IsFirstPerson()
	local camera = workspace.CurrentCamera
	FirstPersonView.Update(isFirstPerson)
	equipped.rig.LocalFrame(equipped, isFirstPerson, deltaTime)
	ScopeOverlay.Update(equipped.tool, equipped.config, if isFirstPerson then Camera.GetAimAlpha() else 0)
	AimPose.SetLocalAim(Camera.GetReadyAlpha())
	Hud.SetAim(Camera.GetAimAlpha())
	Hud.SetSpread(Spread.CrosshairGap(getCurrentSpread(equipped)))
	Hud.SetCrosshairVisible(equipped.rig.ShowCrosshair(equipped.config) and not (equipped.zooming and isFirstPerson))
	Hud.SetCrosshairPosition(
		if Input.UsesScreenCenter() then camera.ViewportSize / 2 else UserInputService:GetMouseLocation()
	)
end

local function onCharacter(character: Model)
	unequip()
	character.ChildAdded:Connect(function(child)
		local config = WeaponRegistry.GetConfig(child)
		if config and child:IsA("Tool") then
			equip(child, config)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		local equipped = current
		if equipped and child == equipped.tool then
			unequip()
		end
	end)
	local humanoid = character:WaitForChild("Humanoid")
	if humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(unequip)
	end
end

function WeaponController.Start()
	RemoteWeapons.Start()
	RunService:BindToRenderStep(FRAME_BIND_NAME, FRAME_PRIORITY, onFrame)
	AimPose.Start()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(unequip)
end

return WeaponController
