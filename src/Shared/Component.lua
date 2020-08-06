-- Component
-- Stephen Leitnick
-- July 25, 2020

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Janitor
local Signal
local TableUtil

local IS_SERVER = RunService:IsServer()
local DESCENDANT_WHITELIST = {Workspace, Players}

local Component = {}
Component.__index = Component

local ComponentsByTag = {}

local function IsDescendantOfWhitelist(Object: Instance): boolean
	for _, Whitelist in ipairs(DESCENDANT_WHITELIST) do
		if Object:IsDescendantOf(Whitelist) then
			return true
		end
	end

	return false
end

function Component.FromTag(Tag: string)
	return ComponentsByTag[Tag]
end

function Component.Auto(Folder)
	local function Setup(ModuleScript: ModuleScript)
		local Module = require(ModuleScript)
		assert(type(Module) == "table", "Expected table for component")
		assert(type(Module.Tag) == "string", "Expected .Tag property")
		Component.new(Module.Tag, Module, Module.RenderPriority)
	end

	for _, Descendant in ipairs(Folder:GetDescendants()) do
		if Descendant:IsA("ModuleScript") then
			Setup(Descendant)
		end
	end

	Folder.DescendantAdded:Connect(function(Descendant)
		if Descendant:IsA("ModuleScript") then
			Setup(Descendant)
		end
	end)
end

function Component.new(Tag, Class, RenderPriority)
	assert(type(Tag) == "string", "Argument #1 (tag) should be a string; got " .. type(Tag))
	assert(type(Class) == "table", "Argument #2 (class) should be a table; got " .. type(Class))
	assert(type(Class.new) == "function", "Class must contain a .new constructor function")
	assert(type(Class.Destroy) == "function", "Class must contain a :Destroy function")
	assert(ComponentsByTag[Tag] == nil, "Component already bound to this tag")

	local self = setmetatable({
		Added = Signal.new();
		Removed = Signal.new();

		_janitor = Janitor.new();
		_lifecycleJanitor = nil;

		_tag = Tag;
		_class = Class;
		_objects = {};
		_instancesToObjects = {};
		_hasHeartbeatUpdate = type(Class.HeartbeatUpdate) == "function";
		_hasSteppedUpdate = type(Class.SteppedUpdate) == "function";
		_hasRenderUpdate = type(Class.RenderUpdate) == "function";
		_hasInit = type(Class.Init) == "function";
		_hasDeinit = type(Class.Deinit) == "function";
		_renderPriority = RenderPriority or Enum.RenderPriority.Last.Value;
		_lifecycle = false;
		_nextId = 0;
	}, Component)

	self._lifecycleJanitor = self._janitor:Add(Janitor.new(), "Destroy")

	self._janitor:Add(CollectionService:GetInstanceAddedSignal(Tag):Connect(function(Object: Instance)
		if IsDescendantOfWhitelist(Object) then
			self:_instanceAdded(Object)
		end
	end), "Disconnect")

	self._janitor:Add(CollectionService:GetInstanceRemovedSignal(Tag):Connect(function(Object: Instance)
		self:_instanceRemoved(Object)
	end), "Disconnect")

	do
		local BindableEvent: BindableEvent = Instance.new("BindableEvent")
		for _, Object in ipairs(CollectionService:GetTagged(Tag)) do
			if IsDescendantOfWhitelist(Object) then
				local Connection = BindableEvent.Event:Connect(function()
					self:_instanceAdded(Object)
				end)

				BindableEvent:Fire()
				Connection = Connection:Disconnect()
			end
		end

		BindableEvent = BindableEvent:Destroy()
	end

	ComponentsByTag[Tag] = self
	self._janitor:Add(function()
		ComponentsByTag[Tag] = nil
	end, true)

	return self
end

function Component:_startHeartbeatUpdate()
	local all = self._objects
	self._heartbeatUpdate = self._lifecycleJanitor:Add(RunService.Heartbeat:Connect(function(dt: number)
		for _, v in ipairs(all) do
			v:HeartbeatUpdate(dt)
		end
	end), "Disconnect")
end

function Component:_startSteppedUpdate()
	local all = self._objects
	self._steppedUpdate = self._lifecycleJanitor:Add(RunService.Stepped:Connect(function(_, dt: number)
		for _, v in ipairs(all) do
			v:SteppedUpdate(dt)
		end
	end), "Disconnect")
end

function Component:_startRenderUpdate()
	local all = self._objects
	self._renderName = self._tag .. "RenderUpdate"
	RunService:BindToRenderStep(self._renderName, self._renderPriority, function(dt: number)
		for _, v in ipairs(all) do
			v:RenderUpdate(dt)
		end
	end)

	self._lifecycleJanitor:Add(function()
		RunService:UnbindFromRenderStep(self._renderName)
	end, true)
end

function Component:_startLifecycle()
	self._lifecycle = true
	if self._hasHeartbeatUpdate then
		self:_startHeartbeatUpdate()
	end

	if self._hasSteppedUpdate then
		self:_startSteppedUpdate()
	end

	if self._hasRenderUpdate then
		self:_startRenderUpdate()
	end
end

function Component:_stopLifecycle()
	self._lifecycle = false
	self._lifecycleJanitor:Cleanup()
end

function Component:_instanceAdded(Object)
	if self._instancesToObjects[Object] then
		return
	end

	if not self._lifecycle then
		self:_startLifecycle()
	end

	self._nextId += 1
	local id = self._tag .. tostring(self._nextId)
	if IS_SERVER then
		local ServerId = Instance.new("StringValue")
		ServerId.Name = "ServerId"
		ServerId.Value = id
		ServerId.Parent = Object
	end

	local obj = self._class.new(Object)
	obj.Instance = Object
	obj.Id = id
	self._instancesToObjects[Object] = obj
	table.insert(self._objects, obj)
	if self._hasInit then
		obj:Init()
	end

	self.Added:Fire(obj)
	return obj
end

function Component:_instanceRemoved(instance)
	self._instancesToObjects[instance] = nil
	for i, obj in ipairs(self._objects) do
		if obj.Instance == instance then
			if self._hasDeinit then
				obj:Deinit()
			end

			if IS_SERVER and instance:FindFirstChild("ServerId") then
				instance.ServerId:Destroy()
			end

			self.Removed:Fire(obj)
			obj:Destroy()
			obj.Destroyed = true
			TableUtil.FastRemove(self._objects, i)
			break
		end
	end

	if #self._objects == 0 and self._lifecycle then
		self:_stopLifecycle()
	end
end

function Component:GetAll()
	return TableUtil.CopyShallow(self._objects)
end

function Component:GetFromInstance(instance)
	return self._instancesToObjects[instance]
end

function Component:GetFromId(id)
	for _, v in ipairs(self._objects) do
		if v.Id == id then
			return v
		end
	end
end

function Component:Filter(filterFunc)
	return TableUtil.Filter(self._objects, filterFunc)
end

local NULL = nil

function Component:Destroy()
	self._janitor = self._janitor:Destroy()
	for Index in next, self do
		self[Index] = nil
	end

	setmetatable(self, NULL)
end

function Component:Init()
	Janitor = self.Shared.Janitor
	Signal = self.Shared.Signal
	TableUtil = self.Shared.TableUtil
end

return Component