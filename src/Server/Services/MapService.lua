-- Map Service
-- pobammer
-- August 4, 2020

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Promise

local MapService = {Client = {}}

local MapSave: Folder
local MapPurgeProof: Folder

function MapService.ClearMap()
	for _, Child in ipairs(Workspace:GetChildren()) do
		if Child:IsA("Camera") or Child:IsA("Terrain") or Child:IsA("Folder") then
			continue
		end

		Child:Destroy()
	end
end

function MapService.LoadMap()
	Promise.Try(function()
		for _, Child in ipairs(MapSave:GetChildren()) do
			Child:Clone().Parent = Workspace
		end
	end)
end

function MapService.Start()
	for _, Child in ipairs(Workspace:GetChildren()) do
		if Child:IsA("Camera") or Child:IsA("Terrain") or Child:IsA("Folder") then
			continue
		end

		local Clone = Child:Clone()
		if Clone then
			Clone.Parent = MapSave
		end
	end
end

function MapService:Init()
	Promise = self.Shared.Promise

	MapSave = Instance.new("Folder")
	MapSave.Name = "MapSave"
	MapSave.Parent = ServerStorage

	MapPurgeProof = Workspace:FindFirstChild("MapPurgeProof")
	if not MapPurgeProof then
		MapPurgeProof = Instance.new("Folder")
		MapPurgeProof.Name = "MapPurgeProof"
		MapPurgeProof.Parent = Workspace
	end
end

return MapService