-- Signal
-- pobammer
-- August 6, 2020

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		BindableEvent = Instance.new("BindableEvent");
	}, Signal)
end

function Signal:Connect(Function)
	return self.BindableEvent.Event:Connect(function(Arguments)
		Function(Arguments())
	end)
end

function Signal:Fire(...)
	local Arguments = table.pack(...)
	self.BindableEvent:Fire(function()
		return table.unpack(Arguments, 1, Arguments.n)
	end)
end

function Signal:Wait()
	return self.BindableEvent.Event:Wait()()
end

local NULL = nil

function Signal:Destroy()
	self.BindableEvent = self.BindableEvent:Destroy()
	setmetatable(self, NULL)
end

return Signal