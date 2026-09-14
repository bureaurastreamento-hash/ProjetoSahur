--!strict
--[[
	RateLimiter
	Token bucket por jogador, usado pelo servidor para throttle de remotes.
	  local limiter = RateLimiter.new(10, 1) -- até 10 chamadas por 1 segundo
	  if not limiter:Allow(player) then return end
	Chamadas acima do limite são descartadas silenciosamente (contadas em .dropped).
]]

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable({} :: {
	capacity: number,
	refillPerSecond: number,
	buckets: { [Player]: { tokens: number, last: number } },
	dropped: number,
}, RateLimiter))

function RateLimiter.new(maxCalls: number, perSeconds: number): RateLimiter
	local self = setmetatable({
		capacity = maxCalls,
		refillPerSecond = maxCalls / perSeconds,
		buckets = {},
		dropped = 0,
	}, RateLimiter)
	Players.PlayerRemoving:Connect(function(player)
		self.buckets[player] = nil
	end)
	return self
end

function RateLimiter.Allow(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self.buckets[player]
	if not bucket then
		bucket = { tokens = self.capacity, last = now }
		self.buckets[player] = bucket
	end
	bucket.tokens = math.min(self.capacity, bucket.tokens + (now - bucket.last) * self.refillPerSecond)
	bucket.last = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	self.dropped += 1
	return false
end

return RateLimiter
