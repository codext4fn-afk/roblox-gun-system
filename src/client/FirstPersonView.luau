--!strict

local FirstPersonView = {}

local ARM_PARTS: { [string]: boolean } = {
	["Left Arm"] = true,
	["Right Arm"] = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
}

local character: Model? = nil
local shownParts: { BasePart } = {}
local hiddenParts: { BasePart } = {}
local hiddenDecals: { Decal } = {}
local needsRebuild = true
local connections: { RBXScriptConnection } = {}

local function rebuild(model: Model)
	table.clear(shownParts)
	table.clear(hiddenParts)
	table.clear(hiddenDecals)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local attribute = item:GetAttribute("BodyPart")
			local bodyPart = if type(attribute) == "string" then attribute else item.Name
			if ARM_PARTS[bodyPart] or item:FindFirstAncestorOfClass("Tool") then
				table.insert(shownParts, item)
			elseif bodyPart == "Head" or item:FindFirstAncestorOfClass("Accessory") then
				table.insert(hiddenParts, item)
			end
		elseif item:IsA("Decal") and item.Parent and item.Parent.Name == "Head" then
			table.insert(hiddenDecals, item)
		end
	end
	needsRebuild = false
end

local function markForRebuild()
	needsRebuild = true
end

function FirstPersonView.Enable(newCharacter: Model)
	FirstPersonView.Disable()
	character = newCharacter
	needsRebuild = true
	table.insert(connections, newCharacter.DescendantAdded:Connect(markForRebuild))
	table.insert(connections, newCharacter.DescendantRemoving:Connect(markForRebuild))
end

function FirstPersonView.Disable()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(shownParts)
	table.clear(hiddenParts)
	table.clear(hiddenDecals)
	character = nil
end

function FirstPersonView.Update(isFirstPerson: boolean)
	local model = character
	if not model or not isFirstPerson then
		return
	end
	if needsRebuild then
		rebuild(model)
	end
	for _, item in shownParts do
		item.LocalTransparencyModifier = 0
	end
	for _, item in hiddenParts do
		item.LocalTransparencyModifier = 1
	end
	for _, decal in hiddenDecals do
		decal.LocalTransparencyModifier = 1
	end
end

return FirstPersonView
