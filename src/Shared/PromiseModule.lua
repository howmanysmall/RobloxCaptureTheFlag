-- Promise Module
-- pobammer
-- August 4, 2020

local Promise
local PromiseModule = {}

function PromiseModule:Init()
	Promise = self.Shared.Promise
end

function PromiseModule.Child(Parent: Instance, ChildName: string, Timeout: number)
	return Promise.new(function(Resolve, Reject, OnCancel)
		local Child = Parent:FindFirstChild(ChildName)
		if Child then
			Resolve(Child)
		else
			local Destroyed
			local WasDestroyed = false
			Destroyed = Parent:GetPropertyChangedSignal("Parent"):Connect(function()
				if not Parent.Parent then
					WasDestroyed = true
					Destroyed = Destroyed:Disconnect()
					Reject()
				end
			end)

			OnCancel(function()
				WasDestroyed = true
				Destroyed = Destroyed:Disconnect()
				Reject()
			end)

			Child = Parent:WaitForChild(ChildName, Timeout)
			if WasDestroyed then
				return
			end

			Destroyed = Destroyed:Disconnect()
			if Child then
				Resolve(Child)
			else
				Reject()
			end
		end
	end)
end

return PromiseModule