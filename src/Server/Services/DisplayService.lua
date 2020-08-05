-- Display Service
-- pobammer
-- August 2, 2020

local DisplayService = {Client = {}}

local DISPLAY_INTERMISSION = "DisplayIntermission"
local DISPLAY_NOTIFICATION = "DisplayNotification"
local DISPLAY_TIMER_INFO = "DisplayTimerInfo"
local DISPLAY_VICTORY = "DisplayVictory"
local DISPLAY_SCORE = "DisplayScore"

function DisplayService:StartIntermission(Player)
	if Player then
		self:FireClient(DISPLAY_INTERMISSION, Player, true)
	else
		self:FireAllClients(DISPLAY_INTERMISSION, true)
	end
end

function DisplayService:StopIntermission(Player)
	if Player then
		self:FireClient(DISPLAY_INTERMISSION, Player, false)
	else
		self:FireAllClients(DISPLAY_INTERMISSION, false)
	end
end

function DisplayService:DisplayNotification(TeamColor, Message)
	self:FireAllClients(DISPLAY_NOTIFICATION, TeamColor, Message)
end

function DisplayService:UpdateTimerInfo(IsIntermission, WaitingForPlayers)
	self:FireAllClients(DISPLAY_TIMER_INFO, IsIntermission, WaitingForPlayers)
end

function DisplayService:DisplayVictory(WinningTeam)
	self:FireAllClients(DISPLAY_VICTORY, WinningTeam)
end

function DisplayService:UpdateScore(Team, Score)
	self:FireAllClients(DISPLAY_SCORE, Team, Score)
end

function DisplayService.Start()
end

function DisplayService:Init()
	self:RegisterClientEvent(DISPLAY_INTERMISSION)
	self:RegisterClientEvent(DISPLAY_NOTIFICATION)
	self:RegisterClientEvent(DISPLAY_TIMER_INFO)
	self:RegisterClientEvent(DISPLAY_VICTORY)
	self:RegisterClientEvent(DISPLAY_SCORE)
end

return DisplayService