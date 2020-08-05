-- Time Service
-- pobammer
-- August 4, 2020

local Workspace = game:GetService("Workspace")
local Promise
local TimeService = {Client = {}}

local StartTime = 0
local Duration = 0

local Time: IntValue

function TimeService.StartTimer(_, Length)
	StartTime = os.clock()
	Duration = Length

	Promise.Try(function()
		repeat
			Time.Value = Duration - (os.clock() - StartTime)
			Promise.Delay(0.03):Await()
		until Time.Value <= 0

		Time.Value = 0
	end)
end

function TimeService.IsTimerDone(): boolean
	return os.clock() - StartTime >= Duration
end

function TimeService.Start()
end

function TimeService:Init()
	Promise = self.Shared.Promise
	self.Shared.PromiseModule.Child(Workspace, "MapPurgeProof", 5):Then(function(MapPurgeProof: Folder)
		Time = Instance.new("IntValue")
		Time.Name = "Time"
		Time.Parent = MapPurgeProof
	end)
end

return TimeService