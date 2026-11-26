-- Zero-Knowledge Master Vault Onboarding, Unlock, Lock & Reset Modal (`src/ui/panels/vault_modal.lua`).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local responsive = env.require("ui/responsive")
	local cryptoVault = env.require("runtime/crypto_vault")
	local github = env.require("net/github")
	local util = env.require("runtime/util")

	local M = {}

	local function clampedModalSize(prefW, prefH)
		local vp = responsive.usableRect(8)
		return math.min(prefW, math.max(280, vp.width - 16)), math.min(prefH, math.max(200, vp.height - 16))
	end

	function M.openSetupModal()
		local mw, mh = clampedModalSize(446, 224)
		local card = overlay.openModal("VaultSetupModal", mw, mh)
		P.pad(card, 12, 14, 12, 14)

		P.label(card, {
			name = "VaultModalTitle",
			size = UDim2.new(1, -30, 0, 20),
			text = "🔐 Zero-Knowledge Master Vault",
			bold = true,
			textSize = 13,
			color = theme.color.tabActiveText,
			truncate = true,
			zIndex = 232,
		})
		P.button(card, {
			name = "VaultCloseBtn",
			size = UDim2.fromOffset(24, 22),
			pos = UDim2.new(1, -24, 0, 0),
			text = "✕",
			radius = 4,
			zIndex = 232,
			onClick = function() overlay.closeModal() end,
		})

		P.label(card, {
			size = UDim2.new(1, 0, 0, 54),
			pos = UDim2.fromOffset(0, 24),
			wrap = true,
			textSize = 11,
			alignY = Enum.TextYAlignment.Top,
			color = theme.color.muted,
			text = "Create a private Master Vault Key to deeply encrypt your GitHub PAT (PBKDF2-HMAC-SHA256). Even VS-RBLX cannot recover your PAT without this key. Don't want encryption? Click 'Leave Unencrypted'.",
			zIndex = 232,
		})

		local _, keyBox = P.input(card, {
			name = "VaultKeyInput",
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.fromOffset(0, 84),
			mono = true,
			placeholder = "Create Master Vault Key (4+ characters)...",
			zIndex = 232,
		})

		local errLbl = P.label(card, {
			name = "VaultStatusLabel",
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 116),
			textSize = 11,
			color = theme.color.bad,
			text = "",
			truncate = true,
			zIndex = 232,
		})

		local btnRow = P.frame(card, {
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.new(0, 0, 1, -28),
			zIndex = 232,
		})
		P.list(btnRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)

		local optOutBtn = P.button(btnRow, {
			name = "VaultOptOutBtn",
			size = UDim2.fromOffset(132, 26),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "Leave Unencrypted",
			textSize = 11,
			radius = 4,
			order = 1,
			zIndex = 233,
			onClick = function()
				cryptoVault.optOut()
				overlay.closeModal()
				overlay.toast("Left unencrypted — PATs & settings will not be encrypted", "info", 2.6)
			end,
		})
		optOutBtn.BackgroundTransparency = 0

		local createBtn = P.button(btnRow, {
			name = "VaultCreateBtn",
			size = UDim2.fromOffset(148, 26),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "🔐 Create Vault Key",
			textSize = 11,
			radius = 4,
			order = 2,
			zIndex = 233,
			onClick = function()
				local ok, err = cryptoVault.createMasterKey(keyBox.Text)
				if not ok then
					errLbl.Text = tostring(err)
					return
				end
				overlay.closeModal()
				overlay.toast("🔐 Master Vault active! Encrypted PAT saved to VSRBLX/vault.enc", "good", 3)
			end,
		})
		createBtn.BackgroundTransparency = 0
		return card
	end

	function M.openVaultModal()
		if not cryptoVault.isEncrypted() then
			return M.openSetupModal()
		end

		if not cryptoVault.isUnlocked() then
			local mw, mh = clampedModalSize(430, 206)
			local card = overlay.openModal("VaultUnlockModal", mw, mh)
			P.pad(card, 12, 14, 12, 14)

			P.label(card, {
				name = "VaultModalTitle",
				size = UDim2.new(1, -30, 0, 20),
				text = "🔒 Unlock Zero-Knowledge Master Vault",
				bold = true,
				textSize = 13,
				color = theme.color.tabActiveText,
				truncate = true,
				zIndex = 232,
			})
			P.button(card, {
				size = UDim2.fromOffset(24, 22),
				pos = UDim2.new(1, -24, 0, 0),
				text = "✕",
				radius = 4,
				zIndex = 232,
				onClick = function() overlay.closeModal() end,
			})

			P.label(card, {
				size = UDim2.new(1, 0, 0, 36),
				pos = UDim2.fromOffset(0, 24),
				wrap = true,
				textSize = 11,
				color = theme.color.muted,
				text = "Your GitHub PAT is encrypted in `VSRBLX/vault.enc`. Enter your Master Vault Key to unlock for this session.",
				zIndex = 232,
			})

			local _, unlockBox = P.input(card, {
				name = "VaultUnlockInput",
				size = UDim2.new(1, 0, 0, 28),
				pos = UDim2.fromOffset(0, 68),
				mono = true,
				placeholder = "Enter Master Vault Key...",
				zIndex = 232,
			})

			local errLbl = P.label(card, {
				name = "VaultStatusLabel",
				size = UDim2.new(1, 0, 0, 18),
				pos = UDim2.fromOffset(0, 100),
				textSize = 11,
				color = theme.color.bad,
				text = "",
				truncate = true,
				zIndex = 232,
			})

			local btnRow = P.frame(card, {
				size = UDim2.new(1, 0, 0, 28),
				pos = UDim2.new(0, 0, 1, -28),
				zIndex = 232,
			})
			P.list(btnRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)

			local resetBtn = P.button(btnRow, {
				name = "VaultResetBtn",
				size = UDim2.fromOffset(118, 26),
				bg = theme.color.inputBg,
				hoverBg = theme.color.bad,
				text = "Wipe / Reset Vault",
				textSize = 11,
				radius = 4,
				order = 1,
				zIndex = 233,
				onClick = function()
					cryptoVault.resetVault()
					overlay.closeModal()
					overlay.toast("Wiped VSRBLX/vault.enc and disabled Vault encryption", "warn", 2.8)
				end,
			})
			resetBtn.BackgroundTransparency = 0

			local unlockBtn = P.button(btnRow, {
				name = "VaultUnlockBtn",
				size = UDim2.fromOffset(124, 26),
				bg = theme.color.good,
				hoverBg = theme.color.accent,
				color = Color3.fromRGB(16, 24, 20),
				bold = true,
				text = "🔓 Unlock Vault",
				textSize = 11,
				radius = 4,
				order = 2,
				zIndex = 233,
				onClick = function()
					local ok, err = cryptoVault.unlock(unlockBox.Text)
					if not ok then
						errLbl.Text = tostring(err)
						return
					end
					overlay.closeModal()
					overlay.toast("🔓 Master Vault unlocked for this session!", "good", 2.5)
				end,
			})
			unlockBtn.BackgroundTransparency = 0
			return card
		end

		-- Unlocked Management View
		local mw, mh = clampedModalSize(446, 214)
		local card = overlay.openModal("VaultManageModal", mw, mh)
		P.pad(card, 12, 14, 12, 14)

		P.label(card, {
			name = "VaultModalTitle",
			size = UDim2.new(1, -30, 0, 20),
			text = "🔓 Master Vault Unlocked (Zero-Knowledge Active)",
			bold = true,
			textSize = 13,
			color = theme.color.good,
			truncate = true,
			zIndex = 232,
		})
		P.button(card, {
			size = UDim2.fromOffset(24, 22),
			pos = UDim2.new(1, -24, 0, 0),
			text = "✕",
			radius = 4,
			zIndex = 232,
			onClick = function() overlay.closeModal() end,
		})

		local curTok = github.token()
		local masked = (curTok ~= "") and ("Encrypted PAT stored (" .. tostring(#curTok) .. " chars)") or "No GitHub PAT stored yet"
		P.label(card, {
			size = UDim2.new(1, 0, 0, 20),
			pos = UDim2.fromOffset(0, 26),
			textSize = 11,
			color = theme.color.muted,
			text = masked .. " · Plaintext settings.json is scrubbed.",
			truncate = true,
			zIndex = 232,
		})

		local _, patBox = P.input(card, {
			name = "VaultPatInput",
			size = UDim2.new(1, -92, 0, 28),
			pos = UDim2.fromOffset(0, 54),
			mono = true,
			placeholder = "ghp_... (update encrypted GitHub PAT)",
			zIndex = 232,
		})
		local savePatBtn = P.button(card, {
			name = "VaultSavePatBtn",
			size = UDim2.fromOffset(86, 28),
			pos = UDim2.new(1, -86, 0, 54),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "Encrypt PAT",
			textSize = 11,
			radius = 4,
			zIndex = 233,
			onClick = function()
				local clean = util.trim(patBox.Text)
				local okS, err = github.setToken(clean)
				if okS == nil then
					overlay.toast(tostring(err), "bad", 2.8)
				else
					patBox.Text = ""
					overlay.toast("🔐 GitHub PAT encrypted into VSRBLX/vault.enc!", "good", 2.5)
				end
			end,
		})
		savePatBtn.BackgroundTransparency = 0

		local btnRow = P.frame(card, {
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.new(0, 0, 1, -28),
			zIndex = 232,
		})
		P.list(btnRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)

		local resetBtn = P.button(btnRow, {
			name = "VaultResetBtn",
			size = UDim2.fromOffset(122, 26),
			bg = theme.color.inputBg,
			hoverBg = theme.color.bad,
			text = "Disable & Wipe",
			textSize = 11,
			radius = 4,
			order = 1,
			zIndex = 233,
			onClick = function()
				cryptoVault.resetVault()
				overlay.closeModal()
				overlay.toast("Disabled Vault & wiped VSRBLX/vault.enc", "warn", 2.5)
			end,
		})
		resetBtn.BackgroundTransparency = 0

		local lockBtn = P.button(btnRow, {
			name = "VaultLockNowBtn",
			size = UDim2.fromOffset(118, 26),
			bg = theme.color.warn,
			hoverBg = theme.color.bad,
			color = Color3.fromRGB(20, 20, 20),
			bold = true,
			text = "🔒 Lock Vault",
			textSize = 11,
			radius = 4,
			order = 2,
			zIndex = 233,
			onClick = function()
				cryptoVault.lock()
				overlay.closeModal()
				overlay.toast("🔒 Master Vault locked (decrypted PAT wiped from RAM)", "good", 2.5)
			end,
		})
		lockBtn.BackgroundTransparency = 0
		return card
	end

	return M
end
