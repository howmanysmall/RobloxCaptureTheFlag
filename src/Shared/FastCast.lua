-- Fast Cast
-- EtiTheSpirit / pobammer
-- August 6, 2020

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Signal
local TableUtil

local FastCast = {}
FastCast.__index = FastCast

local ERR_NOT_INSTANCE = "Cannot statically invoke method '%s' - It is an instance method. Call it on an instance of this class created via %s"
local ERR_INVALID_TYPE = "Invalid type for parameter '%s' (Expected %s, got %s)"

local function MandateType(value, type, paramName, nullable)
	if nullable and value == nil then
		return
	end

	assert(typeof(value) == type, ERR_INVALID_TYPE:format(paramName or "ERR_NO_PARAM_NAME", type, typeof(value)))
end

local function Cast(origin, direction, ignoreDescendantsInstance, ignoreWater)
	return Workspace:FindPartOnRay(Ray.new(origin, direction), ignoreDescendantsInstance, false, ignoreWater)
end

local function CastWithWhitelist(origin, direction, whitelist, ignoreWater)
	if not whitelist or typeof(whitelist) ~= "table" then
		error("Call in CastWhitelist failed! Whitelist table is either nil, or is not actually a table.", 0)
	end

	return Workspace:FindPartOnRayWithWhitelist(Ray.new(origin, direction), whitelist, ignoreWater)
end

local function CastWithBlacklist(origin, direction, blacklist, ignoreWater)
	if not blacklist or typeof(blacklist) ~= "table" then
		error("Call in CastBlacklist failed! Blacklist table is either nil, or is not actually a table.", 0)
	end

	return Workspace:FindPartOnRayWithIgnoreList(Ray.new(origin, direction), blacklist, false, ignoreWater)
end

local function GetPositionAtTime(time, origin, initialVelocity, acceleration)
	local force = Vector3.new(acceleration.X * time^2 / 2, acceleration.Y * time^2 / 2, acceleration.Z * time^2 / 2)
	return origin + initialVelocity * time + force
end

local function GetVelocityAtTime(time, initialVelocity, acceleration)
	return initialVelocity + acceleration * time
end

local function SimulateCast(origin, direction, velocity, castFunction, lengthChangedEvent, rayHitEvent, cosmeticBulletObject, listOrIgnoreDescendantsInstance, ignoreWater, bulletAcceleration, canPierceFunction)
	if type(velocity) == "number" then
		velocity = direction.Unit * velocity
	end

	bulletAcceleration = bulletAcceleration or Vector3.new()
	local distance = direction.Magnitude
	local normalizedDir = direction.Unit
	local upgradedDir = (normalizedDir + velocity).Unit
	local initialVelocity = upgradedDir * velocity.Magnitude

	local totalDelta = 0
	local distanceTravelled = 0
	local lastPoint = origin

	local targetEvent
	local connection
	local isRunningPierce = false

	if RunService:IsClient() then
		targetEvent = RunService.RenderStepped
	else
		targetEvent = RunService.Heartbeat
	end

	local function Fire(delta, customAt)
		totalDelta += delta
		local at = customAt or GetPositionAtTime(totalDelta, origin, initialVelocity, bulletAcceleration)
		local totalDisplacement = at - lastPoint

		local segmentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, bulletAcceleration)
		local rayDir = totalDisplacement.Unit * segmentVelocity.Magnitude * delta
		local hit, point, normal, material = castFunction(lastPoint, rayDir, listOrIgnoreDescendantsInstance, ignoreWater)

		local rayDisplacement = (point - lastPoint).Magnitude
		lengthChangedEvent:Fire(origin, lastPoint, rayDir.Unit, rayDisplacement, segmentVelocity, cosmeticBulletObject)

		if hit and hit ~= cosmeticBulletObject then
			if canPierceFunction then
				if isRunningPierce then
					error("ERROR: The latest call to canPierceFunction took too long to complete! This cast is going to suffer desyncs which WILL cause unexpected behavior and errors.")
				end

				isRunningPierce = true
			end

			if canPierceFunction == nil or (canPierceFunction ~= nil and not canPierceFunction(hit, point, normal, material, segmentVelocity)) then
				isRunningPierce = false
				connection:Disconnect()
				return rayHitEvent:Fire(hit, point, normal, material, segmentVelocity, cosmeticBulletObject)
			else
				isRunningPierce = false
	
				if castFunction == CastWithWhitelist then
					TableUtil.FastRemoveFirstValue(listOrIgnoreDescendantsInstance, hit)
				elseif castFunction == CastWithBlacklist then
					table.insert(listOrIgnoreDescendantsInstance, hit)
				else
					castFunction = CastWithBlacklist
					listOrIgnoreDescendantsInstance = listOrIgnoreDescendantsInstance:GetDescendants()
					table.insert(listOrIgnoreDescendantsInstance, hit)
				end

				Fire(0, at)
				lastPoint = point
				return
			end
		end

		lastPoint = point
		distanceTravelled += rayDisplacement

		if distanceTravelled > distance then
			connection:Disconnect()
			rayHitEvent:Fire(nil, lastPoint, nil, nil, Vector3.new(), cosmeticBulletObject)
		end
	end

	connection = targetEvent:Connect(Fire)
end

local function BaseFireMethod(self, origin, directionWithMagnitude, velocity, cosmeticBulletObject, ignoreDescendantsInstance, ignoreWater, bulletAcceleration, list, isWhitelist, canPierceFunction)
	MandateType(origin, "Vector3", "origin")
	MandateType(directionWithMagnitude, "Vector3", "directionWithMagnitude")
	assert(typeof(velocity) == "Vector3" or typeof(velocity) == "number", string.format(ERR_INVALID_TYPE, "velocity", "Variant<Vector3, number>", typeof(velocity)))
	MandateType(cosmeticBulletObject, "Instance", "cosmeticBulletObject", true)
	MandateType(ignoreDescendantsInstance, "Instance", "ignoreDescendantsInstance", true)
	MandateType(ignoreWater, "boolean", "ignoreWater", true)
	MandateType(bulletAcceleration, "Vector3", "bulletAcceleration", true)
	MandateType(list, "table", "list", true)
	MandateType(canPierceFunction, "function", "canPierceFunction", true)

	local castFunction = Cast
	local ignoreOrList = ignoreDescendantsInstance
	if list ~= nil then
		ignoreOrList = list
		if isWhitelist then
			castFunction = CastWithWhitelist
		else
			castFunction = CastWithBlacklist
		end
	end

	SimulateCast(origin, directionWithMagnitude, velocity, castFunction, self.LengthChanged, self.RayHit, cosmeticBulletObject, ignoreOrList, ignoreWater, bulletAcceleration, canPierceFunction)
end

function FastCast.new()
	return setmetatable({
		LengthChanged = Signal.new();
		RayHit = Signal.new();
	}, FastCast)
end

function FastCast:Fire(origin, directionWithMagnitude, velocity, cosmeticBulletObject, ignoreDescendantsInstance, ignoreWater, bulletAcceleration, canPierceFunction)
	assert(getmetatable(self) == FastCast, ERR_NOT_INSTANCE:format("Fire", "FastCast.new()"))
	BaseFireMethod(self, origin, directionWithMagnitude, velocity, cosmeticBulletObject, ignoreDescendantsInstance, ignoreWater, bulletAcceleration, nil, nil, canPierceFunction)
end

function FastCast:FireWithWhitelist(origin, directionWithMagnitude, velocity, whitelist, cosmeticBulletObject, ignoreWater, bulletAcceleration, canPierceFunction)
	BaseFireMethod(self, origin, directionWithMagnitude, velocity, cosmeticBulletObject, nil, ignoreWater, bulletAcceleration, whitelist, true, canPierceFunction)
end

function FastCast:FireWithBlacklist(origin, directionWithMagnitude, velocity, blacklist, cosmeticBulletObject, ignoreWater, bulletAcceleration, canPierceFunction)
	BaseFireMethod(self, origin, directionWithMagnitude, velocity, cosmeticBulletObject, nil, ignoreWater, bulletAcceleration, blacklist, false, canPierceFunction)
end

local NULL = nil

function FastCast:Destroy()
	self.LengthChanged = self.LengthChanged:Destroy()
	self.RayHit = self.RayHit:Destroy()
	setmetatable(self, NULL)
end

function FastCast:Init()
	Signal = self.Shared.Signal
	TableUtil = self.Shared.TableUtil
end

return FastCast