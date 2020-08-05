-- Points Service
-- pobammer
-- August 4, 2020

local Data
local Promise

local PointsService = {Client = {}}

local AwardPointsTuple

function PointsService.PromiseAwardPoints(_, PlayerOrUserId, Amount)
	local TypeSuccess, TypeError = AwardPointsTuple(PlayerOrUserId, Amount)
	if not TypeSuccess then
		return Promise.Reject(TypeError)
	end

	local UserId = typeof(PlayerOrUserId) == "Instance" and PlayerOrUserId.UserId or PlayerOrUserId
	local PlayerData = Data.ForPlayer(UserId, false)
	return PlayerData:Get("GamePoints", 0):Then(function(GamePoints)
		GamePoints += Amount
		return PlayerData:Set("GamePoints", GamePoints):Then(function()
			local Array = table.create(3)
			Array[1], Array[2], Array[3] = UserId, Amount, GamePoints

			return PlayerData:Save("GamePoints"):ThenCall(Promise.Resolve, Array)
		end, function(Error)
			warn(string.format("Error on setting GamePoints for Player %d: %s", UserId, tostring(Error)))
		end)
	end, function(Error)
		warn(string.format("Error on getting GamePoints for Player %d: %s", UserId, tostring(Error)))
	end)
end

function PointsService:AwardPoints(PlayerOrUserId, Amount)
	local Success, DataTable = self:PromiseAwardPoints(PlayerOrUserId, Amount):Await()
	if Success then
		return table.unpack(DataTable, 1, 3)
	else
		error(tostring(DataTable), 2)
	end
end

function PointsService.Start()
end

function PointsService:Init()
	Data = self.Modules.Data
	Promise = self.Shared.Promise

	local t = self.Shared.t
	AwardPointsTuple = t.tuple(t.union(t.instanceIsA("Player"), t.intersection(t.integer, t.numberPositive)), t.integer)
end

return PointsService