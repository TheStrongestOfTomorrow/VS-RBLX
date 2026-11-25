-- VS-RBLX Editor Buffer & Tab Store: manages open tabs, split editor groups,
-- undo/redo stacks, dirty indicators, cursor/scroll view state, and executor
-- disk persistence (`writefile` / `readfile` via workspace_fs).
return function(env)
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")
	local languages = env.require("runtime/languages")
	local workspaceFs = env.require("runtime/workspace_fs")
	local log = env.require("runtime/log")

	local UNDO_LIMIT = 80
	local untitledCounter = 0

	local M = {
		tabs = {},
		byId = {},
		activeId = nil,
		secondaryId = nil,
		splitOpen = false,
		focusedPane = "primary",
		changed = signal.new("code_store.changed"),
		cursorChanged = signal.new("code_store.cursor"),
		saved = signal.new("code_store.saved"),
	}

	local autoSaveDebounced = clock.debounce(0.75, function()
		if config.get("files.autoSave", "afterDelay") ~= "afterDelay" then return end
		for _, doc in ipairs(M.tabs) do
			if doc.dirty and not doc.untitled and not doc.readOnly and not doc.isDiff then
				M.save(doc.id, { silent = true })
			end
		end
	end)

	local function computeCursorLineCol(source, offset)
		local text = tostring(source or "")
		local pos = util.clamp(tonumber(offset) or 1, 1, #text + 1)
		local line = 1
		local lastNewline = 0
		local idx = 1
		while true do
			local nl = text:find("\n", idx, true)
			if not nl or nl >= pos then break end
			line = line + 1
			lastNewline = nl
			idx = nl + 1
		end
		return line, pos - lastNewline
	end

	local function createDoc(spec)
		local path = util.normalisePath(spec.path or "")
		local id = spec.id or (path ~= "" and ("file:" .. path) or ("untitled:" .. tostring(untitledCounter)))
		local content = tostring(spec.content or ""):gsub("\r\n", "\n")
		local lang = spec.langId and languages.get(spec.langId) or languages.detect(path, content)
		return {
			id = id,
			path = path,
			title = spec.title or (path ~= "" and util.basename(path) or id),
			content = content,
			savedContent = spec.untitled and nil or content,
			langId = lang.id,
			dirty = spec.dirty == true,
			pinned = spec.pinned == true,
			untitled = spec.untitled == true,
			readOnly = spec.readOnly == true,
			isDiff = spec.isDiff == true,
			diffOld = spec.diffOld,
			diffNew = spec.diffNew,
			undoStack = {},
			redoStack = {},
			view = {
				cursor = 1,
				selection = -1,
				line = 1,
				col = 1,
				scrollX = 0,
				scrollY = 0,
			},
		}
	end

	function M.get(id)
		return id and M.byId[id] or nil
	end

	function M.active(pane)
		local targetPane = pane or M.focusedPane
		if targetPane == "secondary" and M.splitOpen and M.secondaryId then
			return M.byId[M.secondaryId]
		end
		return M.activeId and M.byId[M.activeId] or nil
	end

	function M.findByPath(relPath)
		local clean = util.normalisePath(relPath)
		return M.byId["file:" .. clean]
	end

	function M.openFile(relPath, opts)
		opts = opts or {}
		local clean = util.normalisePath(relPath)
		if clean == "" then return nil, "empty path" end
		local id = "file:" .. clean
		local doc = M.byId[id]
		if not doc then
			local content, err = workspaceFs.readFile(clean)
			if content == nil then
				if opts.createIfMissing then
					content = opts.initialContent or ""
					workspaceFs.writeFile(clean, content)
				else
					return nil, err or ("cannot read " .. clean)
				end
			end
			doc = createDoc({
				id = id,
				path = clean,
				content = content,
			})
			M.tabs[#M.tabs + 1] = doc
			M.byId[id] = doc
		elseif opts.reloadFromDisk then
			local diskText = workspaceFs.readFile(clean)
			if diskText ~= nil then
				doc.content = diskText:gsub("\r\n", "\n")
				doc.savedContent = doc.content
				doc.dirty = false
			end
		end

		if opts.pane == "secondary" then
			M.splitOpen = true
			M.secondaryId = doc.id
			M.focusedPane = "secondary"
		else
			M.activeId = doc.id
			if M.splitOpen and M.secondaryId == nil then
				M.secondaryId = doc.id
			end
		end

		if opts.line then
			M.jumpToLine(doc.id, opts.line, opts.col or 1)
		end

		M.changed:fire({ reason = "open", id = doc.id, path = doc.path })
		return doc
	end

	function M.newUntitled(initialContent, langId)
		untitledCounter = untitledCounter + 1
		local name = "Untitled-" .. tostring(untitledCounter)
		local doc = createDoc({
			id = "untitled:" .. tostring(untitledCounter),
			path = name .. ".luau",
			title = name,
			content = initialContent or "-- New Luau buffer\n",
			langId = langId or "luau",
			untitled = true,
			dirty = initialContent ~= nil and initialContent ~= "",
		})
		M.tabs[#M.tabs + 1] = doc
		M.byId[doc.id] = doc
		M.activeId = doc.id
		M.changed:fire({ reason = "new", id = doc.id })
		return doc
	end

	function M.openDiffTab(relPath, oldText, newText, label)
		local clean = util.normalisePath(relPath)
		local id = "diff:" .. clean
		local doc = M.byId[id]
		if not doc then
			doc = createDoc({
				id = id,
				path = clean,
				title = (label or (util.basename(clean) .. " (Working Tree)")),
				content = newText or "",
				readOnly = true,
				isDiff = true,
				diffOld = oldText or "",
				diffNew = newText or "",
			})
			M.tabs[#M.tabs + 1] = doc
			M.byId[id] = doc
		else
			doc.diffOld = oldText or ""
			doc.diffNew = newText or ""
			doc.content = newText or ""
		end
		M.activeId = doc.id
		M.changed:fire({ reason = "diff", id = doc.id })
		return doc
	end

	function M.openVirtualTab(id, title, content, langId, readOnly)
		local fullId = "virtual:" .. tostring(id)
		local doc = M.byId[fullId]
		if not doc then
			doc = createDoc({
				id = fullId,
				path = title,
				title = title,
				content = content or "",
				langId = langId or "luau",
				readOnly = readOnly == true,
				untitled = readOnly ~= true,
			})
			M.tabs[#M.tabs + 1] = doc
			M.byId[fullId] = doc
		else
			doc.content = tostring(content or "")
		end
		M.activeId = doc.id
		M.changed:fire({ reason = "virtual", id = doc.id })
		return doc
	end

	function M.activate(id, pane)
		local doc = M.byId[id]
		if not doc then return false end
		if pane == "secondary" then
			M.splitOpen = true
			M.secondaryId = id
			M.focusedPane = "secondary"
		else
			M.activeId = id
			M.focusedPane = "primary"
		end
		M.changed:fire({ reason = "activate", id = id })
		return true
	end

	function M.updateContent(id, newContent, opts)
		opts = opts or {}
		local doc = M.byId[id]
		if not doc or doc.readOnly then return false end
		local normalized = tostring(newContent or ""):gsub("\r\n", "\n")
		if normalized == doc.content then return false end

		if opts.recordUndo ~= false then
			doc.undoStack[#doc.undoStack + 1] = {
				content = doc.content,
				cursor = doc.view.cursor,
			}
			if #doc.undoStack > UNDO_LIMIT then
				table.remove(doc.undoStack, 1)
			end
			doc.redoStack = {}
		end

		doc.content = normalized
		doc.dirty = doc.untitled or (doc.savedContent ~= normalized)
		M.changed:fire({ reason = "edit", id = doc.id, path = doc.path })

		if doc.dirty and not doc.untitled then
			autoSaveDebounced.call()
		end
		return true
	end

	function M.undo(id)
		local doc = M.byId[id or M.activeId]
		if not doc or doc.readOnly or #doc.undoStack == 0 then return false end
		local prev = table.remove(doc.undoStack)
		doc.redoStack[#doc.redoStack + 1] = {
			content = doc.content,
			cursor = doc.view.cursor,
		}
		doc.content = prev.content
		doc.view.cursor = prev.cursor or 1
		doc.dirty = doc.untitled or (doc.savedContent ~= doc.content)
		M.changed:fire({ reason = "undo", id = doc.id })
		return true
	end

	function M.redo(id)
		local doc = M.byId[id or M.activeId]
		if not doc or doc.readOnly or #doc.redoStack == 0 then return false end
		local nxt = table.remove(doc.redoStack)
		doc.undoStack[#doc.undoStack + 1] = {
			content = doc.content,
			cursor = doc.view.cursor,
		}
		doc.content = nxt.content
		doc.view.cursor = nxt.cursor or 1
		doc.dirty = doc.untitled or (doc.savedContent ~= doc.content)
		M.changed:fire({ reason = "redo", id = doc.id })
		return true
	end

	function M.setLanguage(id, langId)
		local doc = M.byId[id or M.activeId]
		if not doc then return false end
		doc.langId = languages.get(langId).id
		M.changed:fire({ reason = "language", id = doc.id, langId = doc.langId })
		return true
	end

	function M.setCursor(id, cursorOffset, selectionStart)
		local doc = M.byId[id]
		if not doc then return end
		doc.view.cursor = math.max(1, tonumber(cursorOffset) or 1)
		doc.view.selection = tonumber(selectionStart) or -1
		doc.view.line, doc.view.col = computeCursorLineCol(doc.content, doc.view.cursor)
		M.cursorChanged:fire(doc)
	end

	function M.jumpToLine(id, targetLine, targetCol)
		local doc = M.byId[id]
		if not doc then return end
		local lines = util.lines(doc.content)
		local ln = util.clamp(tonumber(targetLine) or 1, 1, #lines)
		local offset = 1
		for i = 1, ln - 1 do
			offset = offset + #lines[i] + 1
		end
		local col = util.clamp(tonumber(targetCol) or 1, 1, #lines[ln] + 1)
		offset = offset + col - 1
		M.setCursor(id, offset, -1)
		doc.view.scrollY = math.max(0, (ln - 4) * 20)
		M.changed:fire({ reason = "jump", id = doc.id, line = ln })
	end

	function M.save(id, opts)
		opts = opts or {}
		local doc = M.byId[id or M.activeId]
		if not doc or doc.readOnly or doc.isDiff then return false, "nothing to save" end
		local targetPath = opts.saveAsPath and util.normalisePath(opts.saveAsPath) or doc.path
		if doc.untitled and not opts.saveAsPath then
			targetPath = doc.title .. "." .. (languages.get(doc.langId).extensions[1] or "luau")
		end
		local ok, res = workspaceFs.writeFile(targetPath, doc.content)
		if not ok then return false, res end

		if doc.untitled or opts.saveAsPath then
			M.byId[doc.id] = nil
			doc.path = targetPath
			doc.title = util.basename(targetPath)
			doc.id = "file:" .. targetPath
			doc.untitled = false
			doc.langId = languages.detect(targetPath, doc.content).id
			M.byId[doc.id] = doc
			M.activeId = doc.id
		end

		doc.savedContent = doc.content
		doc.dirty = false
		if not opts.silent then
			log.info("fs", "Saved to local disk: " .. targetPath .. " (" .. util.formatBytes(#doc.content) .. ")")
		end
		M.saved:fire(doc)
		M.changed:fire({ reason = "save", id = doc.id, path = doc.path })
		return true, targetPath
	end

	function M.saveAll()
		local count = 0
		for _, doc in ipairs(M.tabs) do
			if doc.dirty and not doc.readOnly and not doc.isDiff then
				local ok = M.save(doc.id, { silent = true })
				if ok then count = count + 1 end
			end
		end
		log.info("fs", string.format("Saved %d dirty file(s) to local disk.", count))
		return count
	end

	function M.close(id, opts)
		opts = opts or {}
		local doc = M.byId[id]
		if not doc then return false end
		if doc.pinned and not opts.force then return false end
		local closedIdx = 1
		for i = 1, #M.tabs do
			if M.tabs[i].id == id then
				closedIdx = i
				table.remove(M.tabs, i)
				break
			end
		end
		M.byId[id] = nil
		if M.activeId == id then
			local replacement = M.tabs[math.min(closedIdx, #M.tabs)]
			M.activeId = replacement and replacement.id or nil
		end
		if M.secondaryId == id then
			local replacement = M.tabs[math.min(closedIdx, #M.tabs)]
			M.secondaryId = replacement and replacement.id or nil
			if not M.secondaryId then M.splitOpen = false end
		end
		M.changed:fire({ reason = "close", id = id })
		return true
	end

	-- Interactive tab close: prompts Save / Don't Save / Cancel when dirty
	function M.requestClose(id)
		local doc = M.byId[id]
		if not doc then return false end
		if doc.pinned then return false end
		if doc.dirty and not doc.readOnly and not doc.isDiff and type(M.dirtyCloseHandler) == "function" then
			M.dirtyCloseHandler(doc)
			return "prompted"
		end
		return M.close(id)
	end

	function M.closeToRight(fromId)
		local foundIdx = nil
		for i = 1, #M.tabs do
			if M.tabs[i].id == fromId then
				foundIdx = i
				break
			end
		end
		if not foundIdx then return end
		for i = #M.tabs, foundIdx + 1, -1 do
			local tab = M.tabs[i]
			if not tab.pinned and not tab.dirty then
				M.byId[tab.id] = nil
				table.remove(M.tabs, i)
			end
		end
		if M.activeId and not M.byId[M.activeId] then
			M.activeId = fromId
		end
		M.changed:fire({ reason = "closeToRight", id = fromId })
	end

	function M.closeAll(opts)
		opts = opts or {}
		for i = #M.tabs, 1, -1 do
			local tab = M.tabs[i]
			if opts.force or (not tab.pinned and not tab.dirty) then
				M.byId[tab.id] = nil
				table.remove(M.tabs, i)
			end
		end
		M.activeId = M.tabs[1] and M.tabs[1].id or nil
		if M.secondaryId and not M.byId[M.secondaryId] then
			M.secondaryId = nil
			M.splitOpen = false
		end
		M.changed:fire({ reason = "closeAll" })
	end

	function M.renameOpenFile(oldPath, newPath)
		local cleanOld = util.normalisePath(oldPath)
		local cleanNew = util.normalisePath(newPath)
		local doc = M.byId["file:" .. cleanOld]
		if not doc or cleanNew == "" then return false end
		local oldId = doc.id
		local newId = "file:" .. cleanNew
		M.byId[oldId] = nil
		doc.id = newId
		doc.path = cleanNew
		doc.title = util.basename(cleanNew)
		doc.langId = languages.detect(cleanNew, doc.content).id
		M.byId[newId] = doc
		if M.activeId == oldId then M.activeId = newId end
		if M.secondaryId == oldId then M.secondaryId = newId end
		M.changed:fire({ reason = "rename", oldId = oldId, id = newId, path = cleanNew })
		return true
	end

	function M.closeOthers(keepId)
		for i = #M.tabs, 1, -1 do
			local tab = M.tabs[i]
			if tab.id ~= keepId and not tab.pinned then
				M.byId[tab.id] = nil
				table.remove(M.tabs, i)
			end
		end
		M.activeId = keepId
		M.changed:fire({ reason = "closeOthers", id = keepId })
	end

	function M.closeSaved()
		for i = #M.tabs, 1, -1 do
			local tab = M.tabs[i]
			if not tab.dirty and not tab.pinned then
				M.byId[tab.id] = nil
				table.remove(M.tabs, i)
			end
		end
		if M.activeId and not M.byId[M.activeId] then
			M.activeId = M.tabs[1] and M.tabs[1].id or nil
		end
		M.changed:fire({ reason = "closeSaved" })
	end

	function M.togglePin(id)
		local doc = M.byId[id]
		if not doc then return end
		doc.pinned = not doc.pinned
		M.changed:fire({ reason = "pin", id = id })
	end

	function M.toggleSplit()
		M.splitOpen = not M.splitOpen
		if M.splitOpen and not M.secondaryId then
			M.secondaryId = M.activeId
		end
		if not M.splitOpen then
			M.focusedPane = "primary"
		end
		M.changed:fire({ reason = "split", splitOpen = M.splitOpen })
	end

	function M.syncWithWorkspace()
		for i = #M.tabs, 1, -1 do
			local tab = M.tabs[i]
			if not tab.untitled and not tab.isDiff and not util.startsWith(tab.id, "virtual:") then
				if workspaceFs.exists(tab.path) then
					if not tab.dirty then
						local fresh = workspaceFs.readFile(tab.path)
						if fresh then
							tab.content = fresh:gsub("\r\n", "\n")
							tab.savedContent = tab.content
						end
					end
				end
			end
		end
		M.changed:fire({ reason = "workspaceSync" })
	end

	return M
end
