-- Original VS-RBLX mock Roblox datatype constructors for headless LuaJIT testing.
local M = {}

local function makeVec2(x, y)
	local v
	v = setmetatable({ X = tonumber(x) or 0, Y = tonumber(y) or 0 }, {
		__type = "Vector2",
		__add = function(a, b) return makeVec2(a.X + b.X, a.Y + b.Y) end,
		__sub = function(a, b) return makeVec2(a.X - b.X, a.Y - b.Y) end,
		__mul = function(a, b)
			if type(b) == "number" then return makeVec2(a.X * b, a.Y * b) end
			return makeVec2(a.X * b.X, a.Y * b.Y)
		end,
		__eq = function(a, b) return a.X == b.X and a.Y == b.Y end,
		__tostring = function(a) return string.format("%g, %g", a.X, a.Y) end,
	})
	return v
end

M.Vector2 = {
	new = makeVec2,
	zero = makeVec2(0, 0),
	one = makeVec2(1, 1),
}

local function makeVec3(x, y, z)
	return setmetatable({ X = tonumber(x) or 0, Y = tonumber(y) or 0, Z = tonumber(z) or 0 }, {
		__type = "Vector3",
		__add = function(a, b) return makeVec3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
		__sub = function(a, b) return makeVec3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
		__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end,
	})
end

M.Vector3 = {
	new = makeVec3,
	zero = makeVec3(0, 0, 0),
	one = makeVec3(1, 1, 1),
}

local function makeUDim(scale, offset)
	return setmetatable({ Scale = tonumber(scale) or 0, Offset = tonumber(offset) or 0 }, {
		__type = "UDim",
		__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end,
	})
end

M.UDim = { new = makeUDim }

local function makeUDim2(sx, ox, sy, oy)
	if type(sx) == "table" and type(ox) == "table" then
		return setmetatable({ X = sx, Y = ox }, { __type = "UDim2" })
	end
	return setmetatable({
		X = makeUDim(sx, ox),
		Y = makeUDim(sy, oy),
	}, {
		__type = "UDim2",
		__eq = function(a, b) return a.X == b.X and a.Y == b.Y end,
	})
end

M.UDim2 = {
	new = makeUDim2,
	fromScale = function(sx, sy) return makeUDim2(sx, 0, sy, 0) end,
	fromOffset = function(ox, oy) return makeUDim2(0, ox, 0, oy) end,
}

local ColorProto = { __type = "Color3" }
ColorProto.__index = ColorProto
function ColorProto:Lerp(goal, alpha)
	local t = math.max(0, math.min(1, tonumber(alpha) or 0))
	return M.Color3.new(
		self.R + (goal.R - self.R) * t,
		self.G + (goal.G - self.G) * t,
		self.B + (goal.B - self.B) * t
	)
end
function ColorProto:ToHex()
	return string.format(
		"%02x%02x%02x",
		math.floor(self.R * 255 + 0.5),
		math.floor(self.G * 255 + 0.5),
		math.floor(self.B * 255 + 0.5)
	)
end

M.Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = tonumber(r) or 0, G = tonumber(g) or 0, B = tonumber(b) or 0 }, ColorProto)
	end,
	fromRGB = function(r, g, b)
		return M.Color3.new((tonumber(r) or 0) / 255, (tonumber(g) or 0) / 255, (tonumber(b) or 0) / 255)
	end,
	fromHex = function(hex)
		local clean = tostring(hex or ""):gsub("^#", "")
		local r = tonumber(clean:sub(1, 2), 16) or 0
		local g = tonumber(clean:sub(3, 4), 16) or 0
		local b = tonumber(clean:sub(5, 6), 16) or 0
		return M.Color3.fromRGB(r, g, b)
	end,
}

M.TweenInfo = {
	new = function(time, style, dir)
		return setmetatable({ Time = time or 0.15, EasingStyle = style, EasingDirection = dir }, { __type = "TweenInfo" })
	end,
}

M.Rect = {
	new = function(a, b, c, d)
		return setmetatable({ Min = makeVec2(a, b), Max = makeVec2(c, d) }, { __type = "Rect" })
	end,
}

M.Font = {
	new = function(family, weight, style)
		return setmetatable({ Family = tostring(family or "rbxasset://fonts/families/RobotoMono.json"), Weight = weight, Style = style }, { __type = "Font" })
	end,
	fromEnum = function(enumItem)
		return setmetatable({ Family = "rbxasset://fonts/families/" .. tostring(enumItem and enumItem.Name or "GothamSSm") .. ".json" }, { __type = "Font" })
	end,
}

function M.makeEnum()
	local cache = {}
	return setmetatable({}, {
		__index = function(_, groupName)
			if not cache[groupName] then
				local items = {}
				cache[groupName] = setmetatable({}, {
					__index = function(_, itemName)
						if not items[itemName] then
							items[itemName] = setmetatable({
								Name = itemName,
								EnumType = groupName,
							}, {
								__type = "EnumItem",
								__tostring = function() return "Enum." .. groupName .. "." .. itemName end,
							})
						end
						return items[itemName]
					end,
				})
			end
			return cache[groupName]
		end,
	})
end

return M
