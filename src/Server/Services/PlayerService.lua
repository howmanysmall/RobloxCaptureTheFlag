-- Player Service
-- pobammer
-- August 2, 2020

local Players = game:GetService("Players")
local PointsService = game:GetService("PointsService")

local ConfigurationModule
local Data
local DisplayService
local PointsService
local Promise
local PromiseModule
local TeamService

local PlayerService = {Client = {}}

local RESET_MOUSE_ICON = "ResetMouseIcon"

local PlayersCanSpawn = false
local GameRunning = false

local function CharacterAddedFenv(Player: Player): (Model) -> nil
	return function(Character: Model): nil
		PromiseModule.Child(Character, "Humanoid", 5):Then(function(Humanoid: Humanoid)
			Humanoid.Died:Connect(function()
				Promise.Delay(ConfigurationModule.RESPAWN_TIME):Then(function()
					if GameRunning then
						Player:LoadCharacter()
					end
				end)
			end)
		end, function(Error)
			warn(string.format("Error trying to get Humanoid: %s", tostring(Error)))
		end)
	end
end

local function PlayerAdded(Player: Player): nil
	if not Player:FindFirstChild("leaderstats") then
		-- local PlayerData = Data.ForPlayer(Player.UserId)

		local Leaderstats: Folder = Instance.new("Folder")
		Leaderstats.Name = "leaderstats"

		local Captures: IntValue = Instance.new("IntValue")
		Captures.Name = "Captures"
		Captures.Value = 0
		Captures.Parent = Leaderstats

		Leaderstats.Parent = Player

		TeamService:AssignPlayerToTeam(Player)

		local CharacterAdded = CharacterAddedFenv(Player)
		if Player.Character then
			CharacterAdded(Player.Character)
		end

		Player.CharacterAdded:Connect(CharacterAdded)

		if PlayersCanSpawn then
			Player:LoadCharacter()
		else
			DisplayService:StartIntermission(Player)
		end
	end
end

local function PlayerRemoving(Player: Player): nil
	TeamService:RemovePlayer(Player)
end

function PlayerService.SetGameRunning(_, Running: boolean): nil
	GameRunning = Running
end

function PlayerService.ClearPlayerScores(): nil
	for _, Player in ipairs(Players:GetPlayers()) do
		local Leaderstats: Folder? = Player:FindFirstChild("leaderstats")
		if Leaderstats then
			local Captures: IntValue? = Leaderstats:FindFirstChild("Captures")
			if Captures then
				Captures.Value = 0
			end
		end
	end
end

function PlayerService.LoadPlayers(): nil
	for _, Player in ipairs(Players:GetPlayers()) do
		Player:LoadCharacter()
	end
end

function PlayerService.AllowPlayerSpawn(_, CanSpawn: boolean): nil
	PlayersCanSpawn = CanSpawn
end

function PlayerService:DestroyPlayers()
	for _, Player in ipairs(Players:GetPlayers()) do
		if Player.Character then
			Player.Character:Destroy()
		end

		Player.Backpack:ClearAllChildren()
	end

	self:FireAllClients(RESET_MOUSE_ICON)
end

function PlayerService.AddPlayerScore(_, Player: Player, Score: number): nil
	Player.leaderstats.Captures.Value += Score
	PointsService:PromiseAwardPoints(Player, Score):Catch(warn)
end

function PlayerService.Start(): nil
	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)
end

function PlayerService:Init(): nil
	ConfigurationModule = self.Modules.ConfigurationModule
	Data = self.Modules.Data
	DisplayService = self.Services.DisplayService
	PointsService = self.Services.PointsService
	Promise = self.Shared.Promise
	PromiseModule = self.Shared.PromiseModule
	TeamService = self.Services.TeamService

	self:RegisterClientEvent(RESET_MOUSE_ICON)
end

return PlayerService