-- Geometric Visual Studio Code blue ribbon icon drawn purely with Roblox Frames.
return function(env)
	local P = env.require("ui/primitives")
	local M = {}

	function M.draw(parent, size, zIndex)
		local sz = size or 18
		local z = zIndex or 5
		local holder = P.frame(parent, {
			name = "VSCodeBrand",
			size = UDim2.fromOffset(sz, sz),
			zIndex = z,
		})

		local blueMain = Color3.fromRGB(0, 122, 204)
		local blueBright = Color3.fromRGB(36, 175, 255)
		local blueDark = Color3.fromRGB(0, 95, 168)

		local rightPillar = P.frame(holder, {
			name = "RightPillar",
			size = UDim2.fromOffset(math.max(3, math.floor(sz * 0.24)), math.floor(sz * 0.84)),
			pos = UDim2.fromOffset(math.floor(sz * 0.68), math.floor(sz * 0.08)),
			bg = blueBright,
			radius = 1,
			zIndex = z + 2,
		})
		rightPillar.Active = false

		local diagDown = P.frame(holder, {
			name = "RibbonDown",
			size = UDim2.fromOffset(math.floor(sz * 0.78), math.max(2, math.floor(sz * 0.18))),
			pos = UDim2.fromOffset(math.floor(sz * 0.08), math.floor(sz * 0.42)),
			bg = blueMain,
			radius = 1,
			zIndex = z + 1,
		})
		diagDown.Rotation = 34

		local diagUp = P.frame(holder, {
			name = "RibbonUp",
			size = UDim2.fromOffset(math.floor(sz * 0.78), math.max(2, math.floor(sz * 0.18))),
			pos = UDim2.fromOffset(math.floor(sz * 0.08), math.floor(sz * 0.40)),
			bg = blueDark,
			radius = 1,
			zIndex = z,
		})
		diagUp.Rotation = -34

		return holder
	end

	return M
end
