-- Context-aware IntelliSense autocomplete & snippet provider across all 17 languages.
return function(env)
	local languages = env.require("runtime/languages")
	local util = env.require("runtime/util")

	local M = {}

	local ROBLOX_APIS = {
		{ label = 'game:GetService("Players")', insert = 'game:GetService("Players")', kind = "method", detail = "Roblox Service" },
		{ label = 'game:GetService("RunService")', insert = 'game:GetService("RunService")', kind = "method", detail = "Roblox Service" },
		{ label = 'game:GetService("UserInputService")', insert = 'game:GetService("UserInputService")', kind = "method", detail = "Roblox Service" },
		{ label = 'game:GetService("TweenService")', insert = 'game:GetService("TweenService")', kind = "method", detail = "Roblox Service" },
		{ label = 'game:GetService("HttpService")', insert = 'game:GetService("HttpService")', kind = "method", detail = "Roblox Service" },
		{ label = 'game:GetService("ReplicatedStorage")', insert = 'game:GetService("ReplicatedStorage")', kind = "method", detail = "Roblox Service" },
		{ label = 'Instance.new("Frame")', insert = 'Instance.new("Frame")', kind = "constructor", detail = "Create Instance" },
		{ label = "UDim2.fromOffset", insert = "UDim2.fromOffset(", kind = "function", detail = "UDim2 constructor" },
		{ label = "UDim2.fromScale", insert = "UDim2.fromScale(", kind = "function", detail = "UDim2 constructor" },
		{ label = "Color3.fromRGB", insert = "Color3.fromRGB(", kind = "function", detail = "Color3 constructor" },
		{ label = "Vector2.new", insert = "Vector2.new(", kind = "function", detail = "Vector2 constructor" },
		{ label = "Vector3.new", insert = "Vector3.new(", kind = "function", detail = "Vector3 constructor" },
		{ label = "task.spawn", insert = "task.spawn(function()\n\t\nend)", kind = "function", detail = "Spawn thread" },
		{ label = "task.delay", insert = "task.delay(1, function()\n\t\nend)", kind = "function", detail = "Delayed callback" },
		{ label = "readfile", insert = 'readfile("")', kind = "executor", detail = "Executor Disk Read" },
		{ label = "writefile", insert = 'writefile("", "")', kind = "executor", detail = "Executor Disk Write" },
		{ label = "listfiles", insert = 'listfiles("")', kind = "executor", detail = "Executor List Dir" },
		{ label = "makefolder", insert = 'makefolder("")', kind = "executor", detail = "Executor Make Folder" },
		{ label = "isfile", insert = 'isfile("")', kind = "executor", detail = "Executor Check File" },
		{ label = "isfolder", insert = 'isfolder("")', kind = "executor", detail = "Executor Check Folder" },
		{ label = "request", insert = 'request({ Url = "", Method = "GET" })', kind = "executor", detail = "Executor HTTP Request" },
		{ label = "loadstring", insert = 'loadstring("")()', kind = "executor", detail = "Executor Compile Luau" },
	}

	function M.currentWord(source, cursorOffset)
		local text = tostring(source or "")
		local pos = util.clamp((tonumber(cursorOffset) or 1) - 1, 0, #text)
		if pos <= 0 then return "", 1, 0 end
		local startIdx = pos
		while startIdx >= 1 and text:sub(startIdx, startIdx):match("[%w_]") do
			startIdx = startIdx - 1
		end
		startIdx = startIdx + 1
		if startIdx > pos then return "", pos + 1, pos end
		return text:sub(startIdx, pos), startIdx, pos
	end

	function M.suggest(source, cursorOffset, langId, maxItems)
		local prefix, startIdx, endIdx = M.currentWord(source, cursorOffset)
		if #prefix < 2 then return {}, prefix, startIdx, endIdx end

		local lang = languages.get(langId)
		local lowPrefix = prefix:lower()
		local limit = maxItems or 8
		local seen = { [prefix] = true }
		local items = {}

		local function consider(label, insertText, kind, detail)
			if #items >= limit then return end
			if seen[label] then return end
			if label:lower():sub(1, #lowPrefix) == lowPrefix then
				seen[label] = true
				items[#items + 1] = {
					label = label,
					insert = insertText or label,
					kind = kind or "word",
					detail = detail or lang.name,
				}
			end
		end

		for _, snip in ipairs(lang.snippets or {}) do
			consider(snip.trigger, snip.insert, "snippet", snip.label)
		end

		if lang.id == "luau" then
			for _, api in ipairs(ROBLOX_APIS) do
				consider(api.label, api.insert, api.kind, api.detail)
			end
		end

		for word in pairs(lang.keywords or {}) do
			consider(word, word, "keyword", "keyword")
		end
		for word in pairs(lang.builtins or {}) do
			consider(word, word, "builtin", "builtin")
		end
		for word in pairs(lang.types or {}) do
			consider(word, word, "type", "type")
		end

		for token in tostring(source or ""):gmatch("[%a_][%w_]+") do
			if #token >= 3 then
				consider(token, token, "symbol", "document")
			end
		end

		table.sort(items, function(a, b)
			local rank = { snippet = 1, executor = 2, method = 3, keyword = 4, builtin = 5, type = 6, symbol = 7 }
			local ra, rb = rank[a.kind] or 9, rank[b.kind] or 9
			if ra ~= rb then return ra < rb end
			return a.label < b.label
		end)

		return items, prefix, startIdx, endIdx
	end

	return M
end
