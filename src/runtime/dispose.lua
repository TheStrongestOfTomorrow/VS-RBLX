-- Deterministic cleanup registry so unloading VS-RBLX leaves zero dangling
-- connections, threads, or GUI instances behind.
return function(_env)
	local M = { draining = false }
	local items = {}

	function M.give(resource)
		if resource == nil then return function() end end
		items[#items + 1] = resource
		return function()
			for i = #items, 1, -1 do
				if items[i] == resource then
					table.remove(items, i)
					break
				end
			end
			M.releaseOne(resource)
		end
	end

	function M.connection(conn)
		return M.give(conn)
	end

	function M.instance(inst)
		return M.give(inst)
	end

	function M.thread(co)
		return M.give(co)
	end

	function M.releaseOne(resource)
		local kind = typeof and typeof(resource) or type(resource)
		if kind == "RBXScriptConnection" then
			pcall(function() resource:Disconnect() end)
		elseif kind == "Instance" then
			pcall(function() resource:Destroy() end)
		elseif type(resource) == "thread" then
			pcall(task.cancel, resource)
		elseif type(resource) == "function" then
			pcall(resource)
		elseif type(resource) == "table" then
			if type(resource.Disconnect) == "function" then
				pcall(function() resource:Disconnect() end)
			elseif type(resource.Destroy) == "function" then
				pcall(function() resource:Destroy() end)
			elseif type(resource.destroy) == "function" then
				pcall(resource.destroy)
			elseif type(resource.cancel) == "function" then
				pcall(resource.cancel)
			end
		end
	end

	function M.drain()
		M.draining = true
		for i = #items, 1, -1 do
			local item = items[i]
			items[i] = nil
			M.releaseOne(item)
		end
		M.draining = false
	end

	M.add = M.give
	M.all = M.drain
	M.cleanupAll = M.drain

	return M
end
