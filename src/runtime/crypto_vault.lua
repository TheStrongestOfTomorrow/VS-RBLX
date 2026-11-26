-- Zero-Knowledge Master Vault & Deep GitHub PAT Encryption (`src/runtime/crypto_vault.lua`).
-- Implements FIPS 180-4 SHA-256, RFC 2104 HMAC-SHA256, RFC 8018 PBKDF2-HMAC-SHA256,
-- and Authenticated Stream Encryption (SHA-256-CTR + Encrypt-then-HMAC-SHA256).
--
-- Security Model:
--   - Master Vault Key is NEVER saved to disk, `settings.json`, or `getgenv()`.
--   - Encrypted secrets live in `VSRBLX/vault.enc` (`{ v=1, iter, salt, nonce, ct, tag }`).
--   - Plaintext `github.token` in `settings.json` is scrubbed to `""` when Vault is enabled.
--   - Without the user's Master Vault Key, not even VS-RBLX itself can recover encrypted PATs.
--   - Users can explicitly opt out on first boot (`"Leave Unencrypted / Don't Want To"` -> `vault.mode = "off"`).
return function(env)
	local fsx = env.require("runtime/fsx")
	local config = env.require("runtime/config")
	local signal = env.require("runtime/signal")
	local util = env.require("runtime/util")
	local log = env.require("runtime/log")

	local VAULT_FILE = "vault.enc"
	local DEFAULT_ITERS = 2048
	local MOD32 = 4294967296

	-- Resolve 32-bit bitwise operations across Roblox Luau (`bit32` global), LuaJIT (`bit`), or pure Lua 5.1
	local b32 = (type(bit32) == "table" and bit32) or rawget(_G, "bit32")
	local ljBit = (not b32 and type(require) == "function") and (function()
		local ok, mod = pcall(require, "bit")
		return ok and mod or nil
	end)() or nil

	local band, bor, bxor, bnot, rshift, lshift

	if b32 then
		band = b32.band
		bor = b32.bor
		bxor = b32.bxor
		bnot = b32.bnot
		rshift = b32.rshift
		lshift = b32.lshift
	elseif ljBit then
		band = function(a, b) return ljBit.band(a, b) % MOD32 end
		bor = function(a, b) return ljBit.bor(a, b) % MOD32 end
		bxor = function(a, b) return ljBit.bxor(a, b) % MOD32 end
		bnot = function(a) return ljBit.bnot(a) % MOD32 end
		rshift = function(a, n) return ljBit.rshift(a % MOD32, n) % MOD32 end
		lshift = function(a, n) return ljBit.lshift(a % MOD32, n) % MOD32 end
	else
		bxor = function(a, b)
			a = a % MOD32
			b = b % MOD32
			local res = 0
			local bitVal = 1
			while a > 0 or b > 0 do
				local abit = a % 2
				local bbit = b % 2
				if abit ~= bbit then res = res + bitVal end
				a = (a - abit) / 2
				b = (b - bbit) / 2
				bitVal = bitVal * 2
			end
			return res
		end
		band = function(a, b)
			a = a % MOD32
			b = b % MOD32
			return ((a + b) - bxor(a, b)) / 2
		end
		bnot = function(a)
			return (MOD32 - 1) - (a % MOD32)
		end
		bor = function(a, b)
			return (MOD32 - 1) - band(bnot(a), bnot(b))
		end
		rshift = function(a, n)
			return math.floor((a % MOD32) / (2 ^ n))
		end
		lshift = function(a, n)
			return ((a % MOD32) * (2 ^ n)) % MOD32
		end
	end

	local function rrotate(x, n)
		x = x % MOD32
		return bor(rshift(x, n), lshift(x, 32 - n))
	end

	-- FIPS 180-4 SHA-256 Round Constants
	local K256 = {
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
		0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
		0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
		0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
		0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
		0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
		0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
	}

	local H256_INIT = {
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
		0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
	}

	local function uint32ToBytes(n)
		n = n % MOD32
		local b1 = math.floor(n / 16777216) % 256
		local b2 = math.floor(n / 65536) % 256
		local b3 = math.floor(n / 256) % 256
		local b4 = n % 256
		return string.char(b1, b2, b3, b4)
	end

	local function toHex(rawStr)
		local out = {}
		for i = 1, #rawStr do
			out[i] = string.format("%02x", rawStr:byte(i))
		end
		return table.concat(out)
	end

	local function fromHex(hexStr)
		local s = tostring(hexStr or "")
		if (#s % 2) ~= 0 or s:find("[^%x]") then return nil end
		local out = {}
		local idx = 1
		for i = 1, #s, 2 do
			out[idx] = string.char(tonumber(s:sub(i, i + 1), 16))
			idx = idx + 1
		end
		return table.concat(out)
	end

	local M = {
		changed = signal.new("vault.changed"),
	}

	-- Pure SHA-256 returning 32-byte raw binary digest
	function M.sha256Raw(msg)
		msg = tostring(msg or "")
		local len = #msg
		local bitLenHi = math.floor((len * 8) / MOD32)
		local bitLenLo = (len * 8) % MOD32

		local rem = (len + 1) % 64
		local padZeros = (rem <= 56) and (56 - rem) or (120 - rem)
		local padded = msg .. "\128" .. string.rep("\0", padZeros) .. uint32ToBytes(bitLenHi) .. uint32ToBytes(bitLenLo)

		local h0, h1, h2, h3 = H256_INIT[1], H256_INIT[2], H256_INIT[3], H256_INIT[4]
		local h4, h5, h6, h7 = H256_INIT[5], H256_INIT[6], H256_INIT[7], H256_INIT[8]
		local w = {}

		for chunkStart = 1, #padded, 64 do
			for i = 0, 15 do
				local o = chunkStart + i * 4
				local b1, b2, b3, b4 = padded:byte(o, o + 3)
				w[i + 1] = ((b1 * 16777216) + (b2 * 65536) + (b3 * 256) + b4) % MOD32
			end
			for i = 17, 64 do
				local w15 = w[i - 15]
				local s0 = bxor(bxor(rrotate(w15, 7), rrotate(w15, 18)), rshift(w15, 3))
				local w2 = w[i - 2]
				local s1 = bxor(bxor(rrotate(w2, 17), rrotate(w2, 19)), rshift(w2, 10))
				w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % MOD32
			end

			local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
			for i = 1, 64 do
				local S1 = bxor(bxor(rrotate(e, 6), rrotate(e, 11)), rrotate(e, 25))
				local ch = bxor(band(e, f), band(bnot(e), g))
				local temp1 = (h + S1 + ch + K256[i] + w[i]) % MOD32
				local S0 = bxor(bxor(rrotate(a, 2), rrotate(a, 13)), rrotate(a, 22))
				local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
				local temp2 = (S0 + maj) % MOD32

				h = g
				g = f
				f = e
				e = (d + temp1) % MOD32
				d = c
				c = b
				b = a
				a = (temp1 + temp2) % MOD32
			end

			h0 = (h0 + a) % MOD32
			h1 = (h1 + b) % MOD32
			h2 = (h2 + c) % MOD32
			h3 = (h3 + d) % MOD32
			h4 = (h4 + e) % MOD32
			h5 = (h5 + f) % MOD32
			h6 = (h6 + g) % MOD32
			h7 = (h7 + h) % MOD32
		end

		return uint32ToBytes(h0) .. uint32ToBytes(h1) .. uint32ToBytes(h2) .. uint32ToBytes(h3)
			.. uint32ToBytes(h4) .. uint32ToBytes(h5) .. uint32ToBytes(h6) .. uint32ToBytes(h7)
	end

	function M.sha256Hex(msg)
		return toHex(M.sha256Raw(msg))
	end

	local function xorStrings(a, b)
		local n = math.min(#a, #b)
		local out = {}
		for i = 1, n do
			out[i] = string.char(bxor(a:byte(i), b:byte(i)))
		end
		return table.concat(out)
	end

	-- RFC 2104 HMAC-SHA256 (returns 32-byte raw MAC)
	function M.hmacSha256Raw(key, message)
		key = tostring(key or "")
		if #key > 64 then
			key = M.sha256Raw(key)
		end
		if #key < 64 then
			key = key .. string.rep("\0", 64 - #key)
		end
		local oKeyPad = {}
		local iKeyPad = {}
		for i = 1, 64 do
			local kb = key:byte(i)
			oKeyPad[i] = string.char(bxor(kb, 0x5c))
			iKeyPad[i] = string.char(bxor(kb, 0x36))
		end
		local inner = M.sha256Raw(table.concat(iKeyPad) .. tostring(message or ""))
		return M.sha256Raw(table.concat(oKeyPad) .. inner)
	end

	-- Precompute HMAC pads once when running PBKDF2 (same exact RFC 8018 output, ~8x faster in Roblox/LuaJIT!)
	function M.pbkdf2(password, salt, iterations, dkLen)
		local iters = math.max(1, tonumber(iterations) or DEFAULT_ITERS)
		local key = tostring(password or "")
		if #key > 64 then
			key = M.sha256Raw(key)
		end
		if #key < 64 then
			key = key .. string.rep("\0", 64 - #key)
		end
		local oPadT, iPadT = {}, {}
		for i = 1, 64 do
			local kb = key:byte(i)
			oPadT[i] = string.char(bxor(kb, 0x5c))
			iPadT[i] = string.char(bxor(kb, 0x36))
		end
		local oPad = table.concat(oPadT)
		local iPad = table.concat(iPadT)
		local sha = M.sha256Raw

		local neededBlocks = math.ceil((dkLen or 64) / 32)
		local blocks = {}
		for blockIdx = 1, neededBlocks do
			local u = sha(oPad .. sha(iPad .. salt .. uint32ToBytes(blockIdx)))
			local b1, b2, b3, b4, b5, b6, b7, b8,
				b9, b10, b11, b12, b13, b14, b15, b16,
				b17, b18, b19, b20, b21, b22, b23, b24,
				b25, b26, b27, b28, b29, b30, b31, b32 = u:byte(1, 32)
			for _ = 2, iters do
				u = sha(oPad .. sha(iPad .. u))
				local u1, u2, u3, u4, u5, u6, u7, u8,
					u9, u10, u11, u12, u13, u14, u15, u16,
					u17, u18, u19, u20, u21, u22, u23, u24,
					u25, u26, u27, u28, u29, u30, u31, u32 = u:byte(1, 32)
				b1, b2, b3, b4 = bxor(b1, u1), bxor(b2, u2), bxor(b3, u3), bxor(b4, u4)
				b5, b6, b7, b8 = bxor(b5, u5), bxor(b6, u6), bxor(b7, u7), bxor(b8, u8)
				b9, b10, b11, b12 = bxor(b9, u9), bxor(b10, u10), bxor(b11, u11), bxor(b12, u12)
				b13, b14, b15, b16 = bxor(b13, u13), bxor(b14, u14), bxor(b15, u15), bxor(b16, u16)
				b17, b18, b19, b20 = bxor(b17, u17), bxor(b18, u18), bxor(b19, u19), bxor(b20, u20)
				b21, b22, b23, b24 = bxor(b21, u21), bxor(b22, u22), bxor(b23, u23), bxor(b24, u24)
				b25, b26, b27, b28 = bxor(b25, u25), bxor(b26, u26), bxor(b27, u27), bxor(b28, u28)
				b29, b30, b31, b32 = bxor(b29, u29), bxor(b30, u30), bxor(b31, u31), bxor(b32, u32)
			end
			blocks[blockIdx] = string.char(
				b1, b2, b3, b4, b5, b6, b7, b8,
				b9, b10, b11, b12, b13, b14, b15, b16,
				b17, b18, b19, b20, b21, b22, b23, b24,
				b25, b26, b27, b28, b29, b30, b31, b32
			)
		end
		return table.concat(blocks):sub(1, dkLen or 64)
	end

	-- Constant-time equality check to prevent timing side-channels
	local function constantTimeEquals(a, b)
		if type(a) ~= "string" or type(b) ~= "string" or #a ~= #b then
			return false
		end
		local diff = 0
		for i = 1, #a do
			diff = bor(diff, bxor(a:byte(i), b:byte(i)))
		end
		return diff == 0
	end

	-- Generate 16 bytes of entropy mixing HttpService GUID, os.clock, math.random, and counter
	local entropyCounter = 0
	local function randomBytes16()
		entropyCounter = entropyCounter + 1
		local guid = ""
		if env.hs and env.hs.GenerateGUID then
			local ok, g = pcall(function() return env.hs:GenerateGUID(false) end)
			if ok and type(g) == "string" then guid = g end
		end
		local seedMaterial = string.format(
			"%s|%s|%s|%d|%d",
			guid,
			tostring(os and os.clock and os.clock() or 0),
			tostring(os and os.time and os.time() or 0),
			math.random(1, 1000000000),
			entropyCounter
		)
		return M.sha256Raw(seedMaterial):sub(1, 16)
	end

	-- Counter-mode keystream via HMAC-SHA256(encKey, nonce || uint32(counter))
	local function cryptStream(encKey, nonce, inputBytes)
		local total = #inputBytes
		if total == 0 then return "" end
		local chunks = {}
		local blockNum = 0
		for offset = 1, total, 32 do
			blockNum = blockNum + 1
			local ks = M.hmacSha256Raw(encKey, nonce .. uint32ToBytes(blockNum))
			local slice = inputBytes:sub(offset, math.min(total, offset + 31))
			chunks[#chunks + 1] = xorStrings(slice, ks)
		end
		return table.concat(chunks)
	end

	-- Private Zero-Knowledge Session State (isolated inside closure upvalues!)
	local sessionEncKey = nil
	local sessionMacKey = nil
	local sessionSalt = nil
	local sessionIter = DEFAULT_ITERS
	local unlockedSecrets = nil -- table `{ ["github.token"] = "...", ... }` ONLY while unlocked

	function M.mode()
		return tostring(config.get("vault.mode", "unset") or "unset")
	end

	function M.isEncrypted()
		return M.mode() == "encrypted"
	end

	function M.isUnlocked()
		return M.isEncrypted() and (unlockedSecrets ~= nil) and (sessionEncKey ~= nil)
	end

	function M.hasVaultFile()
		local raw = fsx.read(VAULT_FILE)
		return type(raw) == "string" and raw ~= ""
	end

	function M.needsFirstBootPrompt()
		return M.mode() == "unset" and config.get("vault.promptedOnce", false) ~= true
	end
	M.shouldPromptFirstBoot = M.needsFirstBootPrompt

	function M.init()
		if M.hasVaultFile() then
			if M.mode() ~= "encrypted" then
				config.set("vault.mode", "encrypted", { quiet = true })
			end
			if config.get("github.token", "") ~= "" then
				config.set("github.token", "", { immediate = true })
			end
		end
		return M.mode()
	end

	local function writeVaultEnvelope()
		if not sessionEncKey or not sessionMacKey or not sessionSalt or not unlockedSecrets then
			return false, "Vault is locked"
		end
		local plainJson = util.jsonEncode(unlockedSecrets) or "{}"
		local nonce = randomBytes16()
		local ciphertext = cryptStream(sessionEncKey, nonce, plainJson)
		local authData = "VSRBLX-VAULT-V1|" .. sessionSalt .. "|" .. nonce .. "|" .. ciphertext
		local tag = M.hmacSha256Raw(sessionMacKey, authData)

		local envelope = util.jsonEncode({
			v = 1,
			iter = sessionIter,
			salt = toHex(sessionSalt),
			nonce = toHex(nonce),
			ct = toHex(ciphertext),
			tag = toHex(tag),
		})
		if not envelope then return false, "Failed to serialize vault envelope" end
		local ok, err = fsx.write(VAULT_FILE, envelope)
		if not ok then return false, err end
		return true
	end

	-- Opt out on first boot ("Leave It / Don't Want To") -> keeps everything unencrypted!
	function M.optOut()
		sessionEncKey = nil
		sessionMacKey = nil
		sessionSalt = nil
		unlockedSecrets = nil
		config.set("vault.mode", "off", { quiet = true })
		config.set("vault.promptedOnce", true, { immediate = true })
		log.info("vault", "User opted out of Master Vault encryption (unencrypted mode)")
		M.changed:fire("off")
		return true
	end

	-- Create a brand-new Master Vault Key and encrypt existing GitHub PAT immediately!
	function M.createMasterKey(passphrase)
		local pw = tostring(passphrase or "")
		if #pw < 4 then
			return false, "Master Vault Key must be at least 4 characters"
		end

		local salt = randomBytes16()
		local derived = M.pbkdf2(pw, salt, DEFAULT_ITERS, 64)
		sessionEncKey = derived:sub(1, 32)
		sessionMacKey = derived:sub(33, 64)
		sessionSalt = salt
		sessionIter = DEFAULT_ITERS

		-- Migrate any existing plaintext PAT and scrub it from `settings.json`!
		local existingPat = tostring(config.get("github.token", "") or "")
		unlockedSecrets = {}
		if existingPat ~= "" then
			unlockedSecrets["github.token"] = existingPat
		end

		local okW, wErr = writeVaultEnvelope()
		if not okW then
			sessionEncKey, sessionMacKey, sessionSalt, unlockedSecrets = nil, nil, nil, nil
			return false, tostring(wErr)
		end

		-- Scrub plaintext token from settings.json permanently!
		config.set("github.token", "", { quiet = true })
		config.set("vault.mode", "encrypted", { quiet = true })
		config.set("vault.promptedOnce", true, { immediate = true })
		config.saveNow()

		log.info("vault", "Created Zero-Knowledge Master Vault (`VSRBLX/vault.enc`) and scrubbed plaintext PAT")
		M.changed:fire("unlocked")
		return true
	end

	-- Unlock an existing `VSRBLX/vault.enc` using the player's Master Vault Key
	function M.unlock(passphrase)
		local pw = tostring(passphrase or "")
		if pw == "" then return false, "Enter your Master Vault Key" end

		local raw = fsx.read(VAULT_FILE)
		if not raw then return false, "Vault file `VSRBLX/vault.enc` not found" end

		local envObj = util.jsonDecode(raw)
		if type(envObj) ~= "table" or envObj.v ~= 1 then
			return false, "Corrupted or unsupported vault envelope"
		end

		local salt = fromHex(envObj.salt)
		local nonce = fromHex(envObj.nonce)
		local ct = fromHex(envObj.ct)
		local tag = fromHex(envObj.tag)
		local iters = math.max(256, math.min(20000, tonumber(envObj.iter) or DEFAULT_ITERS))
		if not salt or not nonce or not ct or not tag or #tag ~= 32 then
			return false, "Malformed cryptographic fields in `vault.enc`"
		end

		local derived = M.pbkdf2(pw, salt, iters, 64)
		local encKey = derived:sub(1, 32)
		local macKey = derived:sub(33, 64)

		local authData = "VSRBLX-VAULT-V1|" .. salt .. "|" .. nonce .. "|" .. ct
		local expectedTag = M.hmacSha256Raw(macKey, authData)
		if not constantTimeEquals(expectedTag, tag) then
			return false, "Incorrect Master Vault Key (decryption refused)"
		end

		local plainJson = cryptStream(encKey, nonce, ct)
		local secrets = util.jsonDecode(plainJson)
		if type(secrets) ~= "table" then
			return false, "Decrypted vault payload is invalid"
		end

		sessionEncKey = encKey
		sessionMacKey = macKey
		sessionSalt = salt
		sessionIter = iters
		unlockedSecrets = secrets

		-- Ensure plaintext config stays scrubbed
		if config.get("github.token", "") ~= "" then
			config.set("github.token", "", { immediate = true })
		end

		log.info("vault", "Master Vault unlocked in memory")
		M.changed:fire("unlocked")
		return true
	end

	-- Lock Vault immediately (wiping derived keys and decrypted PAT from RAM!)
	function M.lock()
		sessionEncKey = nil
		sessionMacKey = nil
		sessionSalt = nil
		unlockedSecrets = nil
		log.info("vault", "Master Vault locked (RAM secrets wiped)")
		M.changed:fire("locked")
		return true
	end

	function M.getSecret(key)
		if not M.isUnlocked() then return nil end
		return unlockedSecrets[tostring(key)]
	end

	function M.setSecret(key, val)
		if not M.isUnlocked() then
			return false, "Master Vault is locked — unlock with your Master Key first"
		end
		unlockedSecrets[tostring(key)] = val
		return writeVaultEnvelope()
	end

	-- Destructive reset if user forgot their Master Key (cannot recover encrypted PAT!)
	function M.resetVault()
		M.lock()
		pcall(function() fsx.delete(VAULT_FILE) end)
		config.set("github.token", "", { quiet = true })
		config.set("vault.mode", "off", { quiet = true })
		config.set("vault.promptedOnce", true, { immediate = true })
		config.saveNow()
		log.warn("vault", "Master Vault reset & wiped (`vault.enc` deleted)")
		M.changed:fire("off")
		return true
	end

	return M
end
