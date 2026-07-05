--[[
	AzeriteUI 3.3.5 port - compatibility layer.

	Provides the modern (Wrath Classic 3.4 era) API surface that this
	codebase expects on top of the 2010-era 3.3.5 client. Loaded before
	everything else, including the libraries.
]]
local Addon, ns = ...

local _G = _G

-- Only act on the 3.3.5 client
local tocversion = select(4, GetBuildInfo())
if tocversion >= 40000 then return end

--------------------------------------------------------------
-- Flavor flags: make the addon treat 3.3.5 as Wrath Classic
--------------------------------------------------------------

if not _G.WOW_PROJECT_ID then
	_G.WOW_PROJECT_MAINLINE = 1
	_G.WOW_PROJECT_CLASSIC = 2
	_G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
	_G.WOW_PROJECT_WRATH_CLASSIC = 11
	_G.WOW_PROJECT_CATACLYSM_CLASSIC = 14
	_G.WOW_PROJECT_ID = _G.WOW_PROJECT_WRATH_CLASSIC
end

_G.LE_EXPANSION_LEVEL_CURRENT = _G.LE_EXPANSION_LEVEL_CURRENT or 2
_G.LE_EXPANSION_WRATH_OF_THE_LICH_KING = _G.LE_EXPANSION_WRATH_OF_THE_LICH_KING or 2

--------------------------------------------------------------
-- Widget metatable extensions
-- (3.3.5 frames are Lua tables with per-type metatables)
--------------------------------------------------------------

do
	local dummy = CreateFrame("Frame")

	local function extend(mt)
		if not mt.SetShown then
			mt.SetShown = function(self, show)
				if show then self:Show() else self:Hide() end
			end
		end
		if not mt.RegisterUnitEvent then
			-- no unit-filtered registration on 3.3.5; plain register,
			-- handlers filter by their unit argument anyway
			mt.RegisterUnitEvent = function(self, event, unit1, unit2)
				return self:RegisterEvent(event)
			end
		end
	end

	local function extendRegion(mt)
		if not mt.SetColorTexture and mt.SetTexture then
			mt.SetColorTexture = function(self, r, g, b, a)
				return self:SetTexture(r, g, b, a)
			end
		end
		if not mt.SetSnapToPixelGrid then
			mt.SetSnapToPixelGrid = function() end
			mt.SetTexelSnappingBias = function() end
		end
	end

	local seen = {}
	local widgetTypes = {
		"Frame", "Button", "CheckButton", "StatusBar", "Slider", "EditBox",
		"ScrollFrame", "Cooldown", "MessageFrame", "PlayerModel", "Model",
		"ScrollingMessageFrame", "SimpleHTML", "ColorSelect", "GameTooltip",
	}
	for _, wtype in ipairs(widgetTypes) do
		local ok, frame = pcall(CreateFrame, wtype)
		if ok and frame then
			local mt = getmetatable(frame)
			if mt and mt.__index and not seen[mt.__index] then
				seen[mt.__index] = true
				extend(mt.__index)
			end
		end
	end

	local tex = dummy:CreateTexture()
	local texmt = getmetatable(tex)
	if texmt and texmt.__index then
		extendRegion(texmt.__index)
	end
	local fs = dummy:CreateFontString()
	local fsmt = getmetatable(fs)
	if fsmt and fsmt.__index then
		extendRegion(fsmt.__index)
	end
end

--------------------------------------------------------------
-- Mixin utilities
--------------------------------------------------------------

if not _G.Mixin then
	_G.Mixin = function(obj, ...)
		for i = 1, select("#", ...) do
			local mixin = select(i, ...)
			for k, v in pairs(mixin) do
				obj[k] = v
			end
		end
		return obj
	end
end

if not _G.CreateFromMixins then
	_G.CreateFromMixins = function(...)
		return _G.Mixin({}, ...)
	end
end

--------------------------------------------------------------
-- C_Timer
--------------------------------------------------------------

if not _G.C_Timer then
	local TimerFrame = CreateFrame("Frame")
	local timers = {}

	TimerFrame:SetScript("OnUpdate", function(self, elapsed)
		local active = false
		for timer in pairs(timers) do
			active = true
			if not timer.cancelled then
				timer.remains = timer.remains - elapsed
				if timer.remains <= 0 then
					timer.callback(timer)
					if timer.ticker and (timer.iterations == nil or timer.iterations > 1) then
						if timer.iterations then
							timer.iterations = timer.iterations - 1
						end
						timer.remains = timer.duration
					else
						timers[timer] = nil
					end
				end
			else
				timers[timer] = nil
			end
		end
		if not active then
			self:Hide()
		end
	end)
	TimerFrame:Hide()

	local TimerMixin = {
		Cancel = function(self) self.cancelled = true end,
		IsCancelled = function(self) return self.cancelled end,
	}

	local function newTimer(duration, callback, iterations, ticker)
		local timer = { duration = duration, remains = duration, callback = callback, iterations = iterations, ticker = ticker }
		for k, v in pairs(TimerMixin) do timer[k] = v end
		timers[timer] = true
		TimerFrame:Show()
		return timer
	end

	_G.C_Timer = {
		After = function(duration, callback)
			newTimer(duration, function() callback() end)
		end,
		NewTimer = function(duration, callback)
			return newTimer(duration, callback)
		end,
		NewTicker = function(duration, callback, iterations)
			return newTimer(duration, callback, iterations, true)
		end,
	}
end

--------------------------------------------------------------
-- C_* namespaces
--------------------------------------------------------------

if not _G.C_AddOns then
	_G.C_AddOns = {
		GetAddOnMetadata = GetAddOnMetadata,
		GetNumAddOns = GetNumAddOns,
		GetAddOnInfo = GetAddOnInfo,
		IsAddOnLoaded = IsAddOnLoaded,
		LoadAddOn = LoadAddOn,
		EnableAddOn = EnableAddOn,
		DisableAddOn = DisableAddOn,
		GetAddOnEnableState = function(addon, character)
			-- modern: (name, character) returns 0/1/2
			local _, _, _, enabled, loadable = GetAddOnInfo(addon)
			return enabled and 2 or 0
		end,
	}
end

if not _G.C_CVar then
	_G.C_CVar = {
		GetCVar = GetCVar,
		SetCVar = SetCVar,
		GetCVarBool = function(name)
			local v = GetCVar(name)
			return v == "1"
		end,
		GetCVarDefault = GetCVarDefault,
	}
end

if not _G.C_Container then
	_G.C_Container = {
		GetContainerNumSlots = GetContainerNumSlots,
		GetContainerItemInfo = GetContainerItemInfo,
		GetContainerItemLink = GetContainerItemLink,
		GetContainerNumFreeSlots = GetContainerNumFreeSlots,
		-- no bag sorting on 3.3.5
		SetSortBagsRightToLeft = function() end,
		SetInsertItemsLeftToRight = function() end,
		SortBags = function() end,
		SortBankBags = function() end,
	}
end

if not _G.C_NamePlate then
	_G.C_NamePlate = {
		GetNamePlateForUnit = function() return nil end,
		GetNamePlates = function() return {} end,
	}
end

if not _G.C_UnitAuras then
	_G.C_UnitAuras = {
		GetCooldownAuraBySpellID = function() return nil end,
		GetAuraDataByAuraInstanceID = function() return nil end,
		GetPlayerAuraBySpellID = function() return nil end,
		GetBuffDataByIndex = function() return nil end,
		GetDebuffDataByIndex = function() return nil end,
		GetAuraDataByIndex = function() return nil end,
		GetAuraDataBySlot = function() return nil end,
		GetAuraSlots = function() return nil end,
	}
end

if not _G.C_Reputation then
	_G.C_Reputation = {
		IsFactionParagon = function() return false end,
		IsMajorFaction = function() return false end,
		GetFactionParagonInfo = function() return nil end,
	}
end

if not _G.C_GossipInfo then
	_G.C_GossipInfo = {
		GetFriendshipReputation = function() return nil end,
	}
end

if not _G.C_PvP then
	_G.C_PvP = {
		IsSoloShuffle = function() return false end,
		GetHonorRewardInfo = function() return nil end,
	}
end

if not _G.C_PaperDollInfo then
	_G.C_PaperDollInfo = {
		OffhandHasWeapon = function()
			local link = GetInventoryItemLink("player", 17)
			return link ~= nil
		end,
	}
end

if not _G.C_ActionBar then
	_G.C_ActionBar = {
		GetItemActionOnEquipSpellID = function() return nil end,
	}
end

if not _G.C_LevelLink then
	_G.C_LevelLink = {
		IsActionLocked = function() return false end,
	}
end

--------------------------------------------------------------
-- Modern globals missing on 3.3.5
--------------------------------------------------------------

if not _G.GetCVarBool then
	_G.GetCVarBool = function(name)
		return GetCVar(name) == "1"
	end
end

-- charges did not exist yet
if not _G.GetActionCharges then
	_G.GetActionCharges = function() return 0, 0, 0, 0, 1 end
end
if not _G.GetSpellCharges then
	_G.GetSpellCharges = function() return nil end
end

if not _G.GetSpecialization then
	_G.GetSpecialization = function() return GetActiveTalentGroup() end
end

if not _G.IsLevelAtEffectiveMaxLevel then
	_G.IsLevelAtEffectiveMaxLevel = function(level)
		return (level or UnitLevel("player")) >= (MAX_PLAYER_LEVEL or 80)
	end
end

if not _G.GetPhysicalScreenSize then
	_G.GetPhysicalScreenSize = function()
		local res
		local idx = GetCurrentResolution()
		if idx then
			res = select(idx, GetScreenResolutions())
		end
		if type(res) == "string" then
			local w, h = string.match(res, "(%d+)x(%d+)")
			if w then return tonumber(w), tonumber(h) end
		end
		return GetScreenWidth(), GetScreenHeight()
	end
end

--------------------------------------------------------------
-- Unit / group API added after 3.3.5
--------------------------------------------------------------

if not _G.ShowBossFrameWhenUninteractable then
	_G.ShowBossFrameWhenUninteractable = function() return false end
end

if not _G.UnitSelectionType then
	_G.UnitSelectionType = function() return nil end
end

if not _G.UnitGetTotalAbsorbs then
	_G.UnitGetTotalAbsorbs = function() return 0 end
	_G.UnitGetTotalHealAbsorbs = function() return 0 end
end

if not _G.UnitGetIncomingHeals then
	_G.UnitGetIncomingHeals = function() return 0 end
end

if not _G.UnitHasIncomingResurrection then
	_G.UnitHasIncomingResurrection = function() return false end
end

if not _G.UnitIsMercenary then
	_G.UnitIsMercenary = function() return false end
end

if not _G.UnitHonorLevel then
	_G.UnitHonorLevel = function() return 0 end
end

if not _G.UnitPhaseReason then
	_G.UnitPhaseReason = function(unit)
		if UnitInPhase and not UnitInPhase(unit) then
			return 1
		end
		return nil
	end
end

if not _G.GetUnitPowerBarInfo then
	_G.GetUnitPowerBarInfo = function() return nil end
end

if not _G.UnitPowerDisplayMod then
	_G.UnitPowerDisplayMod = function() return 1 end
end

if not _G.GetFriendshipReputation then
	_G.GetFriendshipReputation = function() return nil end
end

-- group APIs (4.0 renamed the whole family)
if not _G.IsInRaid then
	_G.IsInRaid = function()
		return GetNumRaidMembers() > 0
	end
end

if not _G.IsInGroup then
	_G.IsInGroup = function()
		return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
	end
end

if not _G.GetNumGroupMembers then
	_G.GetNumGroupMembers = function()
		local raid = GetNumRaidMembers()
		if raid > 0 then return raid end
		local party = GetNumPartyMembers()
		return party > 0 and (party + 1) or 0
	end
end

if not _G.GetNumSubgroupMembers then
	_G.GetNumSubgroupMembers = function()
		return GetNumPartyMembers()
	end
end

if not _G.UnitIsGroupLeader then
	_G.UnitIsGroupLeader = function(unit)
		unit = unit or "player"
		if GetNumRaidMembers() > 0 then
			local name = UnitName(unit)
			for i = 1, GetNumRaidMembers() do
				local rname, rank = GetRaidRosterInfo(i)
				if rname == name then
					return rank == 2
				end
			end
			return false
		end
		if UnitIsUnit(unit, "player") then
			return IsPartyLeader() and true or false
		end
		local leader = GetPartyLeaderIndex()
		return leader and leader > 0 and UnitIsUnit(unit, "party" .. leader) or false
	end
end

if not _G.UnitIsGroupAssistant then
	_G.UnitIsGroupAssistant = function(unit)
		unit = unit or "player"
		if GetNumRaidMembers() > 0 then
			local name = UnitName(unit)
			for i = 1, GetNumRaidMembers() do
				local rname, rank = GetRaidRosterInfo(i)
				if rname == name then
					return rank == 1
				end
			end
		end
		return false
	end
end

-- 3.3.5 returns (isTank, isHealer, isDamage); modern returns a role string
do
	local _UnitGroupRolesAssigned = UnitGroupRolesAssigned
	if _UnitGroupRolesAssigned then
		_G.UnitGroupRolesAssigned = function(unit)
			local isTank, isHealer, isDamage = _UnitGroupRolesAssigned(unit)
			if type(isTank) == "string" then
				-- already modern signature somehow, pass through
				return isTank
			end
			if isTank then return "TANK" end
			if isHealer then return "HEALER" end
			if isDamage then return "DAMAGER" end
			return "NONE"
		end
	else
		_G.UnitGroupRolesAssigned = function() return "NONE" end
	end
end

--------------------------------------------------------------
-- UnitAura family: drop the 3.3.5 "rank" second return so the
-- modern signature (name, icon, count, ...) lines up
--------------------------------------------------------------

do
	local _UnitAura, _UnitBuff, _UnitDebuff = UnitAura, UnitBuff, UnitDebuff

	-- detect: on 3.3.5 the second return is the rank string ("Rank 2" or "")
	-- on modern clients it is the icon (a texture path/number).
	-- 3.3.5 is anything below 40000, which we already know we are on.

	_G.UnitAura = function(unit, index, filter)
		local name, _, icon, count, dtype, duration, expires, caster, stealable, consolidate, spellId = _UnitAura(unit, index, filter)
		return name, icon, count, dtype, duration, expires, caster, stealable, nil, spellId, false, false
	end

	_G.UnitBuff = function(unit, index, filter)
		local name, _, icon, count, dtype, duration, expires, caster, stealable, consolidate, spellId = _UnitBuff(unit, index, filter)
		return name, icon, count, dtype, duration, expires, caster, stealable, nil, spellId, false, false
	end

	_G.UnitDebuff = function(unit, index, filter)
		local name, _, icon, count, dtype, duration, expires, caster, stealable, consolidate, spellId = _UnitDebuff(unit, index, filter)
		return name, icon, count, dtype, duration, expires, caster, stealable, nil, spellId, false, false
	end
end

--------------------------------------------------------------
-- CombatLogGetCurrentEventInfo: capture CLEU args as they fire
-- and re-serve them in the modern parameter order
--------------------------------------------------------------

if not _G.CombatLogGetCurrentEventInfo then
	local current = {}
	local cleu = CreateFrame("Frame")
	cleu:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	cleu:SetScript("OnEvent", function(self, event,
			timestamp, subevent, srcGUID, srcName, srcFlags,
			dstGUID, dstName, dstFlags, ...)
		current[1] = timestamp
		current[2] = subevent
		current[3] = false     -- hideCaster (modern)
		current[4] = srcGUID
		current[5] = srcName
		current[6] = srcFlags
		current[7] = 0         -- sourceRaidFlags (modern)
		current[8] = dstGUID
		current[9] = dstName
		current[10] = dstFlags
		current[11] = 0        -- destRaidFlags (modern)
		local n = select("#", ...)
		for i = 1, n do
			current[11 + i] = select(i, ...)
		end
		current.n = 11 + n
	end)

	_G.CombatLogGetCurrentEventInfo = function()
		return unpack(current, 1, current.n or 11)
	end
end
