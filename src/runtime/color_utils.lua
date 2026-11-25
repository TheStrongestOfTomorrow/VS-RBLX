-- Color parsing, HSV <-> RGB conversion, and token-preserving formatting (`src/runtime/color_utils.lua`).
-- Detects #RRGGBB, #RGB, Color3.fromRGB(...), Color3.new(...), and rgb(...)/rgba(...) on code lines.
return function(env)
	local util = env.require("runtime/util")

	local M = {}

	function M.rgbToHex(r, g, b)
		local cr = util.clamp(math.floor((tonumber(r) or 0) + 0.5), 0, 255)
		local cg = util.clamp(math.floor((tonumber(g) or 0) + 0.5), 0, 255)
		local cb = util.clamp(math.floor((tonumber(b) or 0) + 0.5), 0, 255)
		return string.format("#%02x%02x%02x", cr, cg, cb)
	end

	function M.hexToRgb(hexStr)
		local clean = tostring(hexStr or ""):gsub("^#", "")
		if #clean == 3 and clean:match("^%x%x%x$") then
			local r = tonumber(clean:sub(1, 1) .. clean:sub(1, 1), 16)
			local g = tonumber(clean:sub(2, 2) .. clean:sub(2, 2), 16)
			local b = tonumber(clean:sub(3, 3) .. clean:sub(3, 3), 16)
			return r, g, b
		elseif #clean == 6 and clean:match("^%x%x%x%x%x%x$") then
			local r = tonumber(clean:sub(1, 2), 16)
			local g = tonumber(clean:sub(3, 4), 16)
			local b = tonumber(clean:sub(5, 6), 16)
			return r, g, b
		end
		return nil
	end

	function M.rgbToHsv(r, g, b)
		local rf = util.clamp((tonumber(r) or 0) / 255, 0, 1)
		local gf = util.clamp((tonumber(g) or 0) / 255, 0, 1)
		local bf = util.clamp((tonumber(b) or 0) / 255, 0, 1)
		local maxC = math.max(rf, gf, bf)
		local minC = math.min(rf, gf, bf)
		local delta = maxC - minC

		local h = 0
		if delta > 0.00001 then
			if maxC == rf then
				h = ((gf - bf) / delta) % 6
			elseif maxC == gf then
				h = ((bf - rf) / delta) + 2
			else
				h = ((rf - gf) / delta) + 4
			end
			h = h / 6
			if h < 0 then h = h + 1 end
		end
		local s = maxC <= 0.00001 and 0 or (delta / maxC)
		return h, s, maxC
	end

	function M.hsvToRgb(h, s, v)
		local hf = ((tonumber(h) or 0) % 1) * 6
		local sf = util.clamp(tonumber(s) or 0, 0, 1)
		local vf = util.clamp(tonumber(v) or 0, 0, 1)
		local i = math.floor(hf)
		local f = hf - i
		local p = vf * (1 - sf)
		local q = vf * (1 - f * sf)
		local t = vf * (1 - (1 - f) * sf)

		local rf, gf, bf
		local sector = i % 6
		if sector == 0 then rf, gf, bf = vf, t, p
		elseif sector == 1 then rf, gf, bf = q, vf, p
		elseif sector == 2 then rf, gf, bf = p, vf, t
		elseif sector == 3 then rf, gf, bf = p, q, vf
		elseif sector == 4 then rf, gf, bf = t, p, vf
		else rf, gf, bf = vf, p, q end

		return math.floor(rf * 255 + 0.5), math.floor(gf * 255 + 0.5), math.floor(bf * 255 + 0.5)
	end

	-- Scans a single source line and returns color occurrences sorted by column
	function M.findColorsInLine(line)
		local out = {}
		if type(line) ~= "string" or line == "" then return out end
		if not (line:find("#", 1, true) or line:find("Color3", 1, true) or line:find("rgb", 1, true)) then
			return out
		end

		-- 1. Color3.fromRGB(r, g, b)
		local initPos = 1
		while true do
			local s, e, rs, gs, bs = line:find("Color3%.fromRGB%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)", initPos)
			if not s then break end
			local r = util.clamp(tonumber(rs) or 0, 0, 255)
			local g = util.clamp(tonumber(gs) or 0, 0, 255)
			local b = util.clamp(tonumber(bs) or 0, 0, 255)
			out[#out + 1] = {
				first = s,
				last = e,
				format = "color3_rgb",
				r = r,
				g = g,
				b = b,
				hex = M.rgbToHex(r, g, b),
				color3 = Color3.fromRGB(r, g, b),
			}
			initPos = e + 1
		end

		-- 2. Color3.new(rf, gf, bf)
		initPos = 1
		while true do
			local s, e, rf, gf, bf = line:find("Color3%.new%s*%(%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*%)", initPos)
			if not s then break end
			local r = util.clamp(math.floor((tonumber(rf) or 0) * 255 + 0.5), 0, 255)
			local g = util.clamp(math.floor((tonumber(gf) or 0) * 255 + 0.5), 0, 255)
			local b = util.clamp(math.floor((tonumber(bf) or 0) * 255 + 0.5), 0, 255)
			out[#out + 1] = {
				first = s,
				last = e,
				format = "color3_new",
				r = r,
				g = g,
				b = b,
				hex = M.rgbToHex(r, g, b),
				color3 = Color3.fromRGB(r, g, b),
			}
			initPos = e + 1
		end

		-- 3. rgb(r, g, b) / rgba(r, g, b, a)
		initPos = 1
		while true do
			local s, e, fnName, rs, gs, bs, alphaPart = line:find("(rgba?)%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)([^%)]*)%)", initPos)
			if not s then break end
			local prevCh = s > 1 and line:sub(s - 1, s - 1) or " "
			if not prevCh:match("[%w_]") then
				local r = util.clamp(tonumber(rs) or 0, 0, 255)
				local g = util.clamp(tonumber(gs) or 0, 0, 255)
				local b = util.clamp(tonumber(bs) or 0, 0, 255)
				out[#out + 1] = {
					first = s,
					last = e,
					format = fnName == "rgba" and "css_rgba" or "css_rgb",
					alphaTail = alphaPart or "",
					r = r,
					g = g,
					b = b,
					hex = M.rgbToHex(r, g, b),
					color3 = Color3.fromRGB(r, g, b),
				}
			end
			initPos = e + 1
		end

		-- 4. #RRGGBB and #RGB hex literals
		initPos = 1
		while true do
			local s, e, digits = line:find("#(%x+)", initPos)
			if not s then break end
			local prevCh = s > 1 and line:sub(s - 1, s - 1) or " "
			if not prevCh:match("[%w_]") and (#digits == 6 or #digits == 3) then
				local r, g, b = M.hexToRgb(digits)
				if r then
					out[#out + 1] = {
						first = s,
						last = e,
						format = digits == digits:upper() and "hex_upper" or "hex",
						r = r,
						g = g,
						b = b,
						hex = M.rgbToHex(r, g, b),
						color3 = Color3.fromRGB(r, g, b),
					}
				end
			end
			initPos = e + 1
		end

		table.sort(out, function(a, b) return a.first < b.first end)
		return out
	end

	function M.formatColor(r, g, b, formatKind, alphaTail)
		local cr = util.clamp(math.floor((tonumber(r) or 0) + 0.5), 0, 255)
		local cg = util.clamp(math.floor((tonumber(g) or 0) + 0.5), 0, 255)
		local cb = util.clamp(math.floor((tonumber(b) or 0) + 0.5), 0, 255)
		if formatKind == "color3_rgb" then
			return string.format("Color3.fromRGB(%d, %d, %d)", cr, cg, cb)
		elseif formatKind == "color3_new" then
			return string.format("Color3.new(%.3f, %.3f, %.3f)", cr / 255, cg / 255, cb / 255)
		elseif formatKind == "css_rgb" then
			return string.format("rgb(%d, %d, %d)", cr, cg, cb)
		elseif formatKind == "css_rgba" then
			local tail = (type(alphaTail) == "string" and alphaTail ~= "") and alphaTail or ", 1"
			return string.format("rgba(%d, %d, %d%s)", cr, cg, cb, tail)
		elseif formatKind == "hex_upper" then
			return M.rgbToHex(cr, cg, cb):upper()
		end
		return M.rgbToHex(cr, cg, cb)
	end

	function M.replaceColorOnLine(source, lineNum, firstCol, lastCol, newLiteral)
		local lines = util.lines(source or "")
		local target = lines[lineNum]
		if not target then return source end
		lines[lineNum] = target:sub(1, firstCol - 1) .. tostring(newLiteral) .. target:sub(lastCol + 1)
		return table.concat(lines, "\n")
	end

	return M
end
