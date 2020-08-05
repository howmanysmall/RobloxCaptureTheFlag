-- Team Service
-- pobammer
-- August 4, 2020

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local ConfigurationModule
local DisplayService
local TableUtil

local TeamService = {Client = {}}

local TeamPlayers = {}
local TeamScores = {}

local RandomLib: Random

local function GetTeamFromColor(TeamColor: BrickColor): Team?
	for _, Team in ipairs(Teams:GetTeams()) do
		if Team.TeamColor == TeamColor then
			return Team
		end
	end
end

function TeamService.ClearTeamScores(): nil
	for _, Team in ipairs(Teams:GetTeams()) do
		TeamScores[Team] = 0
		DisplayService:UpdateScore(Team, 0)
	end
end

function TeamService.HasTeamWon(): Team | boolean
	for _, Team in ipairs(Teams:GetTeams()) do
		if TeamScores[Team] >= ConfigurationModule.CAPS_TO_WIN then
			return Team
		end
	end

	return false
end

function TeamService.GetWinningTeam(): Team?
	local HighestScore = 0
	local WinningTeam
	for _, Team in ipairs(Teams:GetTeams()) do
		if TeamScores[Team] > HighestScore then
			HighestScore = TeamScores[Team]
			WinningTeam = Team
		end
	end

	return WinningTeam
end

function TeamService.AreTeamsTied(): boolean
	local HighestScore = 0
	local Tied = false

	for _, Team in ipairs(Teams:GetTeams()) do
		if TeamScores[Team] == HighestScore then
			Tied = true
		elseif TeamScores[Team] > HighestScore then
			Tied = false
			HighestScore = TeamScores[Team]
		end
	end

	return Tied
end

function TeamService.AssignPlayerToTeam(_, Player: Player): nil
	local SmallestTeam
	local LowestCount = math.huge
	for Team, PlayerList in next, TeamPlayers do
		local Length = #PlayerList
		if Length < LowestCount then
			SmallestTeam = Team
			LowestCount = Length
		end
	end

	table.insert(TeamPlayers[SmallestTeam], Player)
	Player.Neutral = false
	Player.TeamColor = SmallestTeam.TeamColor
end

function TeamService.RemovePlayer(_, Player: Player): nil
	local Team = GetTeamFromColor(Player.TeamColor)
	if Team then
		local TeamTable = TeamPlayers[Team]
		if TeamTable then
			local Index = table.find(TeamTable, Player)
			if Index then
				TableUtil.FastRemove(TeamTable, Index)
			end
		end
	end
end

function TeamService:ShuffleTeams(): nil
	for _, Team in ipairs(Teams:GetTeams()) do
		TeamPlayers[Team] = {}
	end

	local CurrentPlayers = Players:GetPlayers()
	while #CurrentPlayers > 0 do
		self:AssignPlayerToTeam(table.remove(CurrentPlayers, RandomLib:NextInteger(1, #CurrentPlayers)))
	end
end

function TeamService.AddTeamScore(_, TeamColor: BrickColor, Score: number): nil
	local Team = GetTeamFromColor(TeamColor)
	if Team then
		TeamScores[Team] += Score
		DisplayService:UpdateScore(Team, TeamScores[Team])
	end
end

function TeamService.Start(): nil
	for _, Team in ipairs(Teams:GetTeams()) do
		TeamPlayers[Team] = {}
		TeamScores[Team] = 0
	end
end

function TeamService:Init(): nil
	ConfigurationModule = self.Modules.ConfigurationModule
	DisplayService = self.Services.DisplayService
	TableUtil = self.Shared.TableUtil

	RandomLib = Random.new(tick() % 1 * 1E7)
end

return TeamService