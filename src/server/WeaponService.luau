--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Raycast = require(WeaponSystem:WaitForChild("Raycast"))
local Remotes = require(WeaponSystem:WaitForChild("Remotes"))
local Rig = require(WeaponSystem:WaitForChild("Rig"))
local Settings = require(WeaponSystem:WaitForChild("Settings"))
local Types = require(WeaponSystem:WaitForChild("Types"))
local WeaponRegistry = require(WeaponSystem:WaitForChild("WeaponRegistry"))

local DamageResolver = require(script.Parent.DamageResolver)
local PoseReplicator = require(script.Parent.PoseReplicator)
local RequestLimiter = require(script.Parent.RequestLimiter)
local ShotClock = require(script.Parent.ShotClock)
local ShotValidator = require(script.Parent.ShotValidator)
local WeaponScaler = require(script.Parent.WeaponScaler)

local CharacterRig = Rig.CharacterRig
local ServerSettings = Settings.Server

type ToolState = {
	clock: ShotClock.ShotClock,
	reloadToken: number,
}

type PlayerState = {
	desiredAiming: boolean,
	aimFlushPending: boolean,
	characterConnections: { RBXScriptConnection },
}

local WeaponService = {}

local limiter = RequestLimiter.new(ServerSettings.RequestIntervals)
local toolStates: { [Tool]: ToolState } = setmetatable({}, { __mode = "k" }) :: any
local playerStates: { [Player]: PlayerState } = {}

local function getPlayerState(player: Player): PlayerState
	local state = playerStates[player]
	if not state then
		state = { desiredAiming = false, aimFlushPending = false, characterConnections = {} }
		playerStates[player] = state
	end
	return state
end

local function getToolState(tool: Tool, config: Types.WeaponConfig): ToolState
	local state = toolStates[tool]
	if not state then
		state = { clock = ShotClock.new(config.FireInterval, ServerSettings.FireRateBurst), reloadToken = 0 }
		toolStates[tool] = state
	end
	return state
end

local function getAmmo(tool: Tool, config: Types.WeaponConfig): number
	local ammo = tool:GetAttribute("Ammo")
	return if type(ammo) == "number" then ammo else config.MagSize
end

local function getEquippedGun(player: Player, tool: unknown): (Model?, Tool?, Types.WeaponConfig?)
	local config = WeaponRegistry.GetConfig(tool)
	local character = player.Character
	if not config or not character or typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return nil, nil, nil
	end
	if tool.Parent ~= character or not CharacterRig.IsAlive(character) then
		return nil, nil, nil
	end
	return character, tool, config
end

local function getHead(character: Model): BasePart?
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function hasLineOfSight(character: Model, from: Vector3, to: Vector3): boolean
	local offset = to - from
	if offset.Magnitude < 1e-3 then
		return true
	end
	return workspace:Raycast(from, offset, Raycast.Excluding({ character })) == nil
end

local function getNearbyPlayers(shooter: Player, position: Vector3): { Player }
	local nearby = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = other ~= shooter and character and character:FindFirstChild("HumanoidRootPart")
		if
			root
			and root:IsA("BasePart")
			and (root.Position - position).Magnitude <= ServerSettings.ReplicateDistance
		then
			table.insert(nearby, other)
		end
	end
	return nearby
end

local function isAiming(player: Player, character: Model): boolean
	return character:GetAttribute("Aiming") == true or getPlayerState(player).desiredAiming
end

local function onFire(player: Player, tool: unknown, origin: unknown, aimDirection: unknown, directions: unknown)
	local character, equipped, config = getEquippedGun(player, tool)
	if not (character and equipped and config) or not isAiming(player, character) then
		return
	end
	if ShotValidator.CheckArguments(origin, aimDirection, directions, config.Pellets) then
		return
	end
	local shotOrigin = origin :: Vector3
	local aim = (aimDirection :: Vector3).Unit
	if equipped:GetAttribute("Reloading") == true then
		return
	end
	local ammo = getAmmo(equipped, config)
	if ammo <= 0 then
		return
	end
	local head = getHead(character)
	if not head or not ShotValidator.OriginWithinReach(shotOrigin, head.Position, ServerSettings.MaxOriginOffset) then
		return
	end
	if not hasLineOfSight(character, head.Position, shotOrigin) then
		return
	end
	if not getToolState(equipped, config).clock:TryConsume(os.clock()) then
		return
	end

	equipped:SetAttribute("Ammo", ammo - 1)
	local accepted = ShotValidator.FilterDirections(
		directions :: { unknown },
		aim,
		config.HipSpread + ServerSettings.SpreadTolerance
	)
	local hitPositions = DamageResolver.Resolve(player, character, config, shotOrigin, accepted)
	for _, other in getNearbyPlayers(player, shotOrigin) do
		Remotes.ReplicateShot:FireClient(other, equipped, hitPositions)
	end
end

local function onReload(player: Player, tool: unknown)
	if not limiter:Allow(player, "Reload", os.clock()) then
		return
	end
	local character, equipped, config = getEquippedGun(player, tool)
	if not (character and equipped and config) then
		return
	end
	if equipped:GetAttribute("Reloading") == true or getAmmo(equipped, config) >= config.MagSize then
		return
	end

	local state = getToolState(equipped, config)
	state.reloadToken += 1
	local token = state.reloadToken
	equipped:SetAttribute("Reloading", true)
	local head = getHead(character)
	if head then
		for _, other in getNearbyPlayers(player, head.Position) do
			Remotes.ReplicateReload:FireClient(other, equipped)
		end
	end

	task.delay(config.ReloadTime, function()
		if state.reloadToken ~= token then
			return
		end
		if equipped.Parent == player.Character and CharacterRig.IsAlive(player.Character) then
			equipped:SetAttribute("Ammo", config.MagSize)
		end
		equipped:SetAttribute("Reloading", false)
	end)
end

local function applyDesiredAiming(player: Player)
	local character = player.Character
	if character then
		character:SetAttribute("Aiming", getPlayerState(player).desiredAiming)
	end
end

local function onSetAiming(player: Player, aiming: unknown)
	local state = getPlayerState(player)
	state.desiredAiming = aiming == true
	if limiter:Allow(player, "SetAiming", os.clock()) then
		applyDesiredAiming(player)
	elseif not state.aimFlushPending then
		state.aimFlushPending = true
		task.delay(limiter:Interval("SetAiming"), function()
			state.aimFlushPending = false
			if playerStates[player] == state then
				applyDesiredAiming(player)
			end
		end)
	end
end

local function onAimPitch(player: Player, pitch: unknown)
	local character = player.Character
	if not character or type(pitch) ~= "number" or pitch ~= pitch then
		return
	end
	if limiter:Allow(player, "AimPitch", os.clock()) then
		character:SetAttribute("AimPitch", math.clamp(pitch, -ServerSettings.MaxPitch, ServerSettings.MaxPitch))
	end
end

local function prepareTool(tool: Tool, isR15: boolean)
	local config = WeaponRegistry.GetConfig(tool)
	if not config then
		return
	end
	if isR15 then
		WeaponScaler.Apply(tool, Settings.R15.WeaponScale, Settings.R15.EyeRelief)
	end
	if tool:GetAttribute("Ammo") == nil then
		tool:SetAttribute("Ammo", config.MagSize)
		tool:SetAttribute("Reloading", false)
	end
end

local function prepareDescendant(item: Instance, isR15: boolean)
	if item:IsA("Tool") then
		prepareTool(item, isR15)
	elseif
		item:IsA("BasePart") and (item:FindFirstAncestorOfClass("Accessory") or item:FindFirstAncestorOfClass("Tool"))
	then
		item.CanQuery = false
	end
end

local function refreshPosing(character: Model)
	if WeaponRegistry.GetEquipped(character) then
		PoseReplicator.Start(character)
	else
		character:SetAttribute("Aiming", false)
		PoseReplicator.Stop(character)
	end
end

local function disconnectCharacter(state: PlayerState)
	for _, connection in state.characterConnections do
		connection:Disconnect()
	end
	table.clear(state.characterConnections)
end

local function watchCharacter(player: Player, character: Model)
	if not character.Parent then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", ServerSettings.HumanoidWait)
	if not (character.Parent and humanoid and humanoid:IsA("Humanoid")) then
		return
	end
	local state = getPlayerState(player)
	disconnectCharacter(state)
	state.desiredAiming = false
	local isR15 = CharacterRig.IsR15(character)
	local connections = state.characterConnections

	character:SetAttribute("AimPitch", 0)
	character:SetAttribute("Aiming", false)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, item in backpack:GetChildren() do
			if item:IsA("Tool") then
				prepareTool(item, isR15)
			end
		end
		table.insert(
			connections,
			backpack.ChildAdded:Connect(function(item)
				if item:IsA("Tool") then
					prepareTool(item, isR15)
				end
			end)
		)
	end
	for _, item in character:GetDescendants() do
		prepareDescendant(item, isR15)
	end
	table.insert(
		connections,
		character.DescendantAdded:Connect(function(item)
			prepareDescendant(item, isR15)
		end)
	)
	local function onToolChanged(child: Instance)
		if child:IsA("Tool") then
			refreshPosing(character)
		end
	end
	table.insert(connections, character.ChildAdded:Connect(onToolChanged))
	table.insert(connections, character.ChildRemoved:Connect(onToolChanged))
	table.insert(
		connections,
		humanoid.Died:Connect(function()
			character:SetAttribute("Aiming", false)
			PoseReplicator.Stop(character)
		end)
	)
	refreshPosing(character)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function(character)
		PoseReplicator.Stop(character)
		local state = playerStates[player]
		if state then
			disconnectCharacter(state)
		end
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end

local function forgetPlayer(player: Player)
	local state = playerStates[player]
	if state then
		disconnectCharacter(state)
		playerStates[player] = nil
	end
	limiter:Forget(player)
end

function WeaponService.Start()
	Remotes.Fire.OnServerEvent:Connect(onFire)
	Remotes.Reload.OnServerEvent:Connect(onReload)
	Remotes.SetAiming.OnServerEvent:Connect(onSetAiming)
	Remotes.AimPitch.OnServerEvent:Connect(onAimPitch)
	PoseReplicator.Run()

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(forgetPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return WeaponService
