-- Optional compatibility bridge to Project UAI's documented public client handle.
-- This adapter never manages its updater, pins a revision, or auto-loads code.
return function(env)
	local caps = env.require("runtime/caps")

	local M = {
		url = "https://raw.githubusercontent.com/Project-Ptolemy/ProjectUAI/main/dist/uai.lua",
		minimumSdk = "1.1.0",
	}

	local function globalUai()
		local getter = caps.fn and caps.fn.getgenv
		if type(getter) ~= "function" then return nil end
		local ok, globals = pcall(getter)
		if not ok or type(globals) ~= "table" then return nil end
		local okValue, handle = pcall(function() return globals.UAI end)
		return okValue and handle or nil
	end

	local function versionAtLeast(actual, minimum)
		local function parts(value)
			local major, minor, patch = tostring(value or ""):match("^(%d+)%.(%d+)%.(%d+)")
			if not major then return nil end
			return { tonumber(major), tonumber(minor), tonumber(patch) }
		end
		local a, b = parts(actual), parts(minimum)
		if not a or not b then return false end
		for i = 1, 3 do
			if a[i] ~= b[i] then return a[i] > b[i] end
		end
		return true
	end

	function M.inspect(handle)
		handle = handle or globalUai()
		if type(handle) ~= "table" then
			return { compatible = false, status = "not_running", reason = "Project UAI is not detected in the executor environment." }
		end
		local build = tostring(handle.build or "unknown")
		local version = tostring(handle.version or "unknown")
		if handle.alive ~= true then
			return { compatible = false, status = "stopped", version = version, build = build, reason = "The detected Project UAI client is not alive." }
		end
		local sdk = handle.sdk
		local features = type(sdk) == "table" and sdk.features or nil
		local ok = type(sdk) == "table"
			and versionAtLeast(sdk.version, M.minimumSdk)
			and type(features) == "table"
			and features.requests == true
			and features.resourceScopes == true
			and type(sdk.createScope) == "function"
			and type(sdk.request) == "function"
			and type(handle.show) == "function"
			and type(handle.sessions) == "table"
			and type(handle.sessions.open) == "function"
		if not ok then
			return {
				compatible = false,
				status = "incompatible",
				version = version,
				build = build,
				sdkVersion = type(sdk) == "table" and tostring(sdk.version or "unknown") or "missing",
				reason = "Required documented UAI SDK 1.1.0+ request, resource-scope, session, or navigation capability is unavailable. No replacement or updater action was attempted.",
			}
		end
		return {
			compatible = true,
			status = "compatible",
			version = version,
			build = build,
			sdkVersion = tostring(sdk.version),
			handle = handle,
		}
	end

	function M.open()
		local state = M.inspect()
		local handle = state.handle
		if state.status == "incompatible" or state.status == "stopped" then return false, state.reason, state end
		if state.status == "not_running" then
			local loader = caps.fn and caps.fn.loadstring
			local httpGet = caps.fn and caps.fn.httpGet
			if type(loader) ~= "function" or type(httpGet) ~= "function" then
				return false, "This host lacks HTTP download or Luau compilation needed to run the official Project UAI loader.", state
			end
			local okFetch, source = pcall(httpGet, M.url)
			if not okFetch or type(source) ~= "string" or source == "" then
				return false, "Could not fetch the official Project UAI distribution. No local fallback was used.", state
			end
			local okCompile, chunk, compileErr = pcall(loader, source, "@ProjectUAI/main/dist/uai.lua")
			if not okCompile or type(chunk) ~= "function" then
				return false, "The current Project UAI distribution could not be compiled: " .. tostring(compileErr or chunk), state
			end
			local okStart, result = pcall(chunk, {
				ui = false,
				reuse = true,
				prompt = "Host integration: VS-RBLX is an independently maintained Roblox workbench. No VS-RBLX file or permission scope is transferred by this integration. Respect the UAI permission controls and explain any executor-wide access clearly.",
			})
			if not okStart then return false, "Project UAI failed during startup: " .. tostring(result), state end
			handle = type(result) == "table" and result or globalUai()
			state = M.inspect(handle)
			if not state.compatible then return false, state.reason or "Project UAI did not expose the required public SDK.", state end
		end

		local okShow, showResult, showReason = pcall(handle.show, "chat")
		if not okShow then return false, "Project UAI navigation failed safely: " .. tostring(showResult), state end
		if showResult == false or (type(showResult) == "table" and (showResult.ok == false or showResult.admitted == false)) then
			local reason = type(showResult) == "table" and (showResult.reason or showResult.error) or showReason
			return false, tostring(reason or "Project UAI did not admit the request; complete its setup/unlock in its own UI."), state
		end
		return true, "Opened Project UAI " .. tostring(state.version) .. " (SDK " .. tostring(state.sdkVersion) .. "). UAI remains responsible for its own updates.", state
	end

	return M
end
