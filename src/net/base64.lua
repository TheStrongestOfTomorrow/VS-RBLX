-- Pure Luau Base64 encoder/decoder used for GitHub REST & Git Data API payloads.
return function(_env)
	local M = {}
	local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local DECODE_MAP = {}
	for i = 1, #ALPHABET do
		DECODE_MAP[ALPHABET:byte(i)] = i - 1
	end

	function M.encode(raw)
		local data = tostring(raw or "")
		local out = {}
		local n = #data
		for i = 1, n, 3 do
			local b1 = data:byte(i) or 0
			local b2 = data:byte(i + 1)
			local b3 = data:byte(i + 2)
			local triple = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)

			local c1 = math.floor(triple / 262144) % 64 + 1
			local c2 = math.floor(triple / 4096) % 64 + 1
			local c3 = math.floor(triple / 64) % 64 + 1
			local c4 = (triple % 64) + 1

			out[#out + 1] = ALPHABET:sub(c1, c1)
			out[#out + 1] = ALPHABET:sub(c2, c2)
			out[#out + 1] = b2 and ALPHABET:sub(c3, c3) or "="
			out[#out + 1] = b3 and ALPHABET:sub(c4, c4) or "="
		end
		return table.concat(out)
	end

	function M.decode(encoded)
		local clean = tostring(encoded or ""):gsub("[^A-Za-z0-9%+/=]", "")
		local out = {}
		local n = #clean
		for i = 1, n, 4 do
			local a = DECODE_MAP[clean:byte(i)] or 0
			local b = DECODE_MAP[clean:byte(i + 1)] or 0
			local raw3 = clean:byte(i + 2)
			local raw4 = clean:byte(i + 3)
			local c = (raw3 and raw3 ~= 61) and (DECODE_MAP[raw3] or 0) or 0
			local d = (raw4 and raw4 ~= 61) and (DECODE_MAP[raw4] or 0) or 0

			local triple = a * 262144 + b * 4096 + c * 64 + d
			out[#out + 1] = string.char(math.floor(triple / 65536) % 256)
			if raw3 and raw3 ~= 61 then
				out[#out + 1] = string.char(math.floor(triple / 256) % 256)
			end
			if raw4 and raw4 ~= 61 then
				out[#out + 1] = string.char(triple % 256)
			end
		end
		return table.concat(out)
	end

	return M
end
