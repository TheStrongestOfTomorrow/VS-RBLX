-- Executor local disk filesystem facade (`readfile`, `writefile`, `listfiles`,
-- `makefolder`, `isfile`, `isfolder`, `delfile`, `delfolder`) with automatic
-- directory creation, strict path sanitisation, and transparent virtual-memory
-- fallback when running inside a vanilla Studio LocalScript.
return function(env)
	local util = env.require("runtime/util")
	local caps = env.require("runtime/caps")
	local log = env.require("runtime/log")
	local signal = env.require("runtime/signal")

	local M = {
		enabled = caps.fs,
		root = (env.info and env.info.folder) or "VSRBLX",
		changed = signal.new("fsx.changed"),
	}

	local knownFolders = {}
	local memFiles = {}
	local memFolders = { [""] = true }

	function M.isBackedByDisk()
		return M.enabled == true
	end

	function M.sanitise(path, allowEmpty)
		local original = tostring(path or "")
		if not util.validUtf8(original) then return nil, "path must contain valid UTF-8" end
		if original:match("^[\\/]") or original:match("^%a:") then
			return nil, "absolute system paths are not allowed outside executor workspace"
		end
		local clean = original:gsub("\\", "/"):gsub("^/+", ""):gsub("/+", "/"):gsub("/+$", "")
		if clean == "" then
			if allowEmpty then return "" end
			return nil, "empty path"
		end
		for _, part in ipairs(util.split(clean, "/")) do
			local device = part:upper():match("^[^%.]+") or ""
			if device == "CON" or device == "PRN" or device == "AUX" or device == "NUL"
				or device:match("^COM[1-9]$") or device:match("^LPT[1-9]$") then
				return nil, "path contains a reserved device name"
			end
			if part == ".." or part == "." then
				return nil, "path may not contain '.' or '..'"
			end
			if part:find("[%z\1-\31\127]") then
				return nil, "path contains a control character"
			end
			if part:match("[%. ]$") then
				return nil, "path segments may not end in a dot or space"
			end
			if part:find('[<>:"|%?%*]') then
				return nil, "path contains a reserved character"
			end
		end
		if #clean > 240 then return nil, "path is too long" end
		return clean
	end

	function M.resolve(path, opts)
		opts = opts or {}
		local clean, err = M.sanitise(path, true)
		if clean == nil then return nil, err end
		if opts.raw then
			return clean
		end
		local base = M.root
		if opts.scope and opts.scope ~= "" then
			base = base .. "/" .. opts.scope
		end
		if clean == "" then return base end
		return base .. "/" .. clean
	end

	function M.ensure(dir, opts)
		local full, err = M.resolve(dir, opts)
		if not full then return false, err end
		if full == "" then return true end
		local walk = ""
		for _, part in ipairs(util.split(full, "/")) do
			walk = (walk == "") and part or (walk .. "/" .. part)
			memFolders[walk] = true
			if M.enabled and caps.fn.makefolder and not knownFolders[walk] then
				local exists = false
				if caps.fn.isfolder then
					local ok, res = pcall(caps.fn.isfolder, walk)
					exists = ok and res == true
				end
				if not exists then
					pcall(caps.fn.makefolder, walk)
				end
				knownFolders[walk] = true
			end
		end
		return true
	end

	function M.exists(path, opts)
		local full = M.resolve(path, opts)
		if not full or full == "" then return false end
		if M.enabled and caps.fn.isfile then
			local ok, res = pcall(caps.fn.isfile, full)
			if ok and res == true then return true end
		end
		return memFiles[full] ~= nil
	end

	function M.isDir(path, opts)
		local full = M.resolve(path, opts)
		if not full then return false end
		if full == "" then return true end
		if M.enabled and caps.fn.isfolder then
			local ok, res = pcall(caps.fn.isfolder, full)
			if ok and res == true then return true end
		end
		return memFolders[full] == true
	end

	function M.read(path, opts)
		local full, err = M.resolve(path, opts)
		if not full or full == "" then return nil, err or "invalid path" end
		if M.enabled and caps.fn.readfile then
			local ok, content = pcall(caps.fn.readfile, full)
			if ok and type(content) == "string" then
				memFiles[full] = content
				return content
			end
			if memFiles[full] ~= nil then return memFiles[full] end
			return nil, tostring(content or "file not found")
		end
		if memFiles[full] ~= nil then
			return memFiles[full]
		end
		return nil, "file not found: " .. full
	end

	function M.write(path, content, opts)
		local full, err = M.resolve(path, opts)
		if not full or full == "" then return false, err or "invalid path" end
		local body = tostring(content or "")
		local parent = util.dirname(full)
		if parent ~= "" then
			M.ensure(parent, { raw = true })
		end
		memFiles[full] = body
		if M.enabled and caps.fn.writefile then
			local ok, writeErr = pcall(caps.fn.writefile, full, body)
			if not ok then
				log.error("fs", "writefile failed for " .. full .. ": " .. tostring(writeErr))
				return false, tostring(writeErr)
			end
		end
		M.changed:fire({ op = "write", path = full, bytes = #body })
		return true, full
	end

	function M.append(path, content, opts)
		local full, err = M.resolve(path, opts)
		if not full or full == "" then return false, err or "invalid path" end
		local parent = util.dirname(full)
		if parent ~= "" then
			M.ensure(parent, { raw = true })
		end
		local extra = tostring(content or "")
		memFiles[full] = (memFiles[full] or "") .. extra
		if M.enabled then
			if caps.fn.appendfile and M.exists(full, { raw = true }) then
				local ok, appendErr = pcall(caps.fn.appendfile, full, extra)
				if not ok then return false, tostring(appendErr) end
			elseif caps.fn.writefile then
				local ok, writeErr = pcall(caps.fn.writefile, full, memFiles[full])
				if not ok then return false, tostring(writeErr) end
			end
		end
		M.changed:fire({ op = "append", path = full, bytes = #extra })
		return true
	end

	function M.mkdir(path, opts)
		local ok, err = M.ensure(path, opts)
		if ok then
			local full = M.resolve(path, opts)
			M.changed:fire({ op = "mkdir", path = full })
		end
		return ok, err
	end

	function M.delete(path, opts)
		local full, err = M.resolve(path, opts)
		if not full or full == "" then return false, err or "invalid path" end
		memFiles[full] = nil
		if memFolders[full] then
			memFolders[full] = nil
			knownFolders[full] = nil
			local prefix = full .. "/"
			for k in pairs(memFiles) do
				if k:sub(1, #prefix) == prefix then memFiles[k] = nil end
			end
			for k in pairs(memFolders) do
				if k:sub(1, #prefix) == prefix then
					memFolders[k] = nil
					knownFolders[k] = nil
				end
			end
			if M.enabled and caps.fn.delfolder then
				pcall(caps.fn.delfolder, full)
			end
		elseif M.enabled and caps.fn.delfile then
			pcall(caps.fn.delfile, full)
		end
		M.changed:fire({ op = "delete", path = full })
		return true
	end

	-- Lists immediate children of `dir`, merging real executor `listfiles` entries
	-- with any virtual entries. Each item is `{ name, path, fullPath, isDir }`.
	function M.list(dir, opts)
		opts = opts or {}
		local full, err = M.resolve(dir or "", opts)
		if not full then return {}, err end

		local seen = {}
		local out = {}
		local prefix = (full == "") and "" or (full .. "/")

		local function record(rawEntry, forceDir, fromListfiles)
			local clean = util.normalisePath(rawEntry)
			if clean == "" or clean == full then return end
			local rel = clean
			if prefix ~= "" then
				if clean:sub(1, #prefix) == prefix then
					rel = clean:sub(#prefix + 1)
				else
					local slashPrefix = "/" .. prefix
					local foundIdx = ("/" .. clean):find(slashPrefix, 1, true)
					if foundIdx then
						rel = ("/" .. clean):sub(foundIdx + #slashPrefix)
					elseif fromListfiles and not clean:find("/", 1, true) then
						rel = clean
					else
						return
					end
				end
			end
			local head = rel:match("^([^/]+)")
			if not head or head == "" then return end
			local childFull = (prefix == "") and head or (prefix .. head)
			local isNested = rel:find("/", 1, true) ~= nil
			local dirFlag = forceDir == true or isNested or M.isDir(childFull, { raw = true })
			if seen[head] then
				if dirFlag then seen[head].isDir = true end
				return
			end
			local relFromScope = head
			local baseClean = util.normalisePath(dir or "")
			if baseClean ~= "" then
				relFromScope = baseClean .. "/" .. head
			end
			local item = {
				name = head,
				path = relFromScope,
				fullPath = childFull,
				isDir = dirFlag,
			}
			seen[head] = item
			out[#out + 1] = item
		end

		if M.enabled and caps.fn.listfiles then
			local target = (full == "") and "." or full
			if full == "" or M.isDir(full, { raw = true }) then
				local ok, list = pcall(caps.fn.listfiles, target)
				if ok and type(list) == "table" then
					for _, entry in ipairs(list) do
						local cleanEntry = tostring(entry):gsub("^%./", ""):gsub("^%.\\", "")
						record(cleanEntry, false, true)
					end
				end
			end
		end

		for k in pairs(memFiles) do record(k, false) end
		for k in pairs(memFolders) do
			if k ~= "" then record(k, true) end
		end

		table.sort(out, function(a, b)
			if a.isDir ~= b.isDir then return a.isDir end
			return a.name:lower() < b.name:lower()
		end)
		return out
	end

	-- Recursively scans a directory and returns flat list of files & folders.
	function M.walk(dir, opts, maxEntries)
		local limit = maxEntries or 1500
		local results = {}
		local function visit(sub, depth)
			if depth > 16 or #results >= limit then return end
			local items = M.list(sub, opts)
			for _, item in ipairs(items) do
				if #results >= limit then break end
				results[#results + 1] = item
				if item.isDir then
					visit(item.path, depth + 1)
				end
			end
		end
		visit(dir or "", 0)
		return results
	end

	return M
end
