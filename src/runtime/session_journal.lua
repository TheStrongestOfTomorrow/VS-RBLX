-- Crash-Proof Session & Unsaved Draft Auto-Recovery Journal (`src/runtime/session_journal.lua`).
-- Periodically snapshots open tabs, cursor/scroll positions, split view, and unsaved dirty/untitled
-- buffers to local disk (`VSRBLX/session_journal.json` via `writefile`) so disconnects, teleports,
-- or game reloads never lose in-progress code.
return function(env)
	local fsx = env.require("runtime/fsx")
	local util = env.require("runtime/util")
	local clock = env.require("runtime/clock")
	local log = env.require("runtime/log")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local JOURNAL_PATH = "session_journal.json"
	local MAX_DRAFT_BYTES = 180000

	local M = {
		enabled = true,
		restoring = false,
		recoveredDrafts = 0,
		lastSavedAt = nil,
	}

	function M.buildSnapshot()
		local tabsOut = {}
		for _, doc in ipairs(codeStore.tabs) do
			if not doc.isDiff and not util.startsWith(doc.id, "virtual:") then
				local entry = {
					id = doc.id,
					path = doc.path,
					title = doc.title,
					langId = doc.langId,
					untitled = doc.untitled == true,
					pinned = doc.pinned == true,
					dirty = doc.dirty == true,
					cursor = doc.view and doc.view.cursor or 1,
					scrollX = doc.view and doc.view.scrollX or 0,
					scrollY = doc.view and doc.view.scrollY or 0,
				}
				if (doc.dirty or doc.untitled) and type(doc.content) == "string" and #doc.content <= MAX_DRAFT_BYTES then
					entry.draftContent = doc.content
				end
				tabsOut[#tabsOut + 1] = entry
			end
		end

		return {
			version = 1,
			workspace = workspaceFs.activeName,
			savedAt = clock.timestamp(),
			activeId = codeStore.activeId,
			secondaryId = codeStore.secondaryId,
			splitOpen = codeStore.splitOpen == true,
			focusedPane = codeStore.focusedPane,
			tabs = tabsOut,
		}
	end

	function M.saveNow()
		if not M.enabled or M.restoring then return false end
		local snap = M.buildSnapshot()
		local encoded = util.jsonEncode(snap)
		if not encoded then return false end
		local ok = fsx.write(JOURNAL_PATH, encoded)
		if ok then
			M.lastSavedAt = snap.savedAt
		end
		return ok
	end

	local debouncedSave = clock.debounce(0.55, function()
		M.saveNow()
	end)

	function M.restore()
		local raw = fsx.read(JOURNAL_PATH)
		if type(raw) ~= "string" or raw == "" then
			return false, 0
		end
		local snap = util.jsonDecode(raw)
		if type(snap) ~= "table" or type(snap.tabs) ~= "table" or #snap.tabs == 0 then
			return false, 0
		end
		if snap.workspace and snap.workspace ~= workspaceFs.activeName then
			return false, 0
		end

		M.restoring = true
		local openedCount = 0
		local recoveredDrafts = 0
		local idRemap = {}

		for _, t in ipairs(snap.tabs) do
			if type(t) == "table" then
				local doc = nil
				if t.untitled then
					doc = codeStore.newUntitled(t.draftContent or "", t.langId or "luau")
					if doc and type(t.title) == "string" and t.title ~= "" then
						doc.title = t.title
					end
					if doc and t.draftContent and t.draftContent ~= "" then
						doc.dirty = t.dirty ~= false
						recoveredDrafts = recoveredDrafts + 1
					end
				elseif type(t.path) == "string" and t.path ~= "" and workspaceFs.exists(t.path) then
					doc = codeStore.openFile(t.path)
					if doc and t.dirty and type(t.draftContent) == "string" and t.draftContent ~= doc.content then
						doc.content = t.draftContent:gsub("\r\n", "\n")
						doc.dirty = true
						recoveredDrafts = recoveredDrafts + 1
					end
				end

				if doc then
					openedCount = openedCount + 1
					if t.id then idRemap[t.id] = doc.id end
					doc.pinned = t.pinned == true
					if t.langId then doc.langId = t.langId end
					doc.view.scrollX = tonumber(t.scrollX) or 0
					doc.view.scrollY = tonumber(t.scrollY) or 0
					codeStore.setCursor(doc.id, tonumber(t.cursor) or 1, -1)
				end
			end
		end

		if snap.splitOpen and snap.secondaryId and idRemap[snap.secondaryId] then
			codeStore.splitOpen = true
			codeStore.secondaryId = idRemap[snap.secondaryId]
		end
		if snap.activeId and idRemap[snap.activeId] then
			codeStore.activeId = idRemap[snap.activeId]
		end
		if snap.focusedPane == "secondary" and codeStore.splitOpen then
			codeStore.focusedPane = "secondary"
		end

		M.restoring = false
		M.recoveredDrafts = recoveredDrafts
		if openedCount > 0 then
			codeStore.changed:fire({ reason = "journalRestore" })
			if recoveredDrafts > 0 then
				log.info("session", string.format("Recovered %d unsaved draft(s) from session journal.", recoveredDrafts))
			end
		end
		return openedCount > 0, recoveredDrafts
	end

	function M.clear()
		fsx.delete(JOURNAL_PATH)
	end

	codeStore.changed:connect(function()
		if not M.restoring then
			debouncedSave.call()
		end
	end)
	codeStore.cursorChanged:connect(function()
		if not M.restoring then
			debouncedSave.call()
		end
	end)

	return M
end
