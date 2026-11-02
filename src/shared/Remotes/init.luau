--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

local function get(name: string): RemoteEvent
	local remote = script:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `Remotes.{name} must be a RemoteEvent`)
	return remote
end

return {
	Fire = get("Fire"),
	Reload = get("Reload"),
	SetAiming = get("SetAiming"),
	AimPitch = get("AimPitch"),
	ReplicateShot = get("ReplicateShot"),
	ReplicateReload = get("ReplicateReload"),
}
