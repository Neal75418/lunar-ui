---@meta
-- WoW API Global Definitions for LunarUI
-- This file provides type hints for Lua language servers (EmmyLua / LuaLS)
-- It is NOT loaded by WoW — the .toc file does not include it.
---@diagnostic disable

-- Opaque stub return: typed as 'any' so the linter cannot determine truthiness.
-- Prevents false-positive "always truthy/falsy" cascading when the linter
-- evaluates function bodies instead of relying solely on @return annotations.
---@type any
local _rv = ...

--------------------------------------------------------------------------------
-- Libraries
--------------------------------------------------------------------------------
---@type any
LibStub = {}

--------------------------------------------------------------------------------
-- Frame creation & UI
--------------------------------------------------------------------------------
---@param frameType string
---@param name? string
---@param parent? any
---@param template? string
---@param id? number
---@return any
function CreateFrame(frameType, name, parent, template, id) return _rv end

---@type any
UIParent = {}
---@type any
WorldFrame = {}
---@type any
GameFontNormal = {}
---@type any
GameFontNormalSmall = {}
---@type any
GameFontHighlight = {}
---@type any
GameFontHighlightSmall = {}
---@type string
STANDARD_TEXT_FONT = ""
---@type any
BackdropTemplateMixin = {}
---@param object any
---@vararg any
---@return any
function Mixin(object, ...) return _rv end

--------------------------------------------------------------------------------
-- C_* Namespaces
--------------------------------------------------------------------------------
---@type any
C_AddOns = {}
---@type any
C_Timer = {}
---@type any
C_Container = {}
---@type any
C_Item = {}
---@type any
C_MountJournal = {}
---@type any
C_TooltipInfo = {}
---@type any
C_Minimap = {}
---@type any
C_Map = {}
---@type any
C_CVar = {}
---@type any
C_PetBattles = {}
---@type any
C_QuestLog = {}
---@type any
C_NamePlate = {}
---@type any
C_NewItems = {}

--------------------------------------------------------------------------------
-- Unit functions
--------------------------------------------------------------------------------
---@return boolean
function InCombatLockdown() return _rv end
---@param unit string
---@return boolean
function UnitExists(unit) return _rv end
---@param unit string
---@return boolean
function UnitIsDead(unit) return _rv end
---@param unit1 string
---@param unit2 string
---@return boolean
function UnitIsUnit(unit1, unit2) return _rv end
---@param unit string
---@return string, string
function UnitName(unit) return _rv end
---@param unit string
---@return string, string, number
function UnitClass(unit) return _rv end
---@param unit string
---@return number
function UnitHealth(unit) return _rv end
---@param unit string
---@return number
function UnitHealthMax(unit) return _rv end
---@param unit string
---@param powerType? number
---@return number
function UnitPower(unit, powerType) return _rv end
---@param unit string
---@param powerType? number
---@return number
function UnitPowerMax(unit, powerType) return _rv end
---@param unit string
---@return number, string
function UnitPowerType(unit) return _rv end
---@param unit string
---@return number
function UnitLevel(unit) return _rv end
---@param unit string
---@return number
function UnitEffectiveLevel(unit) return _rv end
---@param unit string
---@return boolean
function UnitIsPlayer(unit) return _rv end
---@param unit1 string
---@param unit2 string
---@return boolean
function UnitIsEnemy(unit1, unit2) return _rv end
---@param unit1 string
---@param unit2 string
---@return boolean
function UnitIsFriend(unit1, unit2) return _rv end
---@param unit1 string
---@param unit2 string
---@return number|nil
function UnitReaction(unit1, unit2) return _rv end
---@param unit string
---@return boolean
function UnitAffectingCombat(unit) return _rv end
---@param unit string
---@param otherUnit? string
---@return number
function UnitThreatSituation(unit, otherUnit) return _rv end
---@param unit string
---@return string
function UnitClassification(unit) return _rv end
---@param unit string
---@return string
function UnitCreatureType(unit) return _rv end
---@param unit string
---@return string
function UnitGUID(unit) return _rv end
---@param unit string
---@return string
function UnitGroupRolesAssigned(unit) return _rv end
---@param unit string
---@return boolean
function UnitInRaid(unit) return _rv end
---@param unit string
---@return boolean
function UnitInParty(unit) return _rv end
---@param unit string
---@return boolean
function UnitIsGhost(unit) return _rv end
---@param unit string
---@return boolean
function UnitIsConnected(unit) return _rv end
---@param unit string
---@return boolean
function UnitIsTapDenied(unit) return _rv end
---@param unit string
---@return boolean
function UnitPlayerControlled(unit) return _rv end
---@param unit string
---@return boolean
function UnitInPartyIsAI(unit) return _rv end
---@param unit string
---@return boolean
function UnitIsVisible(unit) return _rv end
---@param unit string
---@return number
function UnitHealthPercent(unit) return _rv end
---@param unit string
---@return number
function UnitPowerPercent(unit) return _rv end
---@param unit string
---@return number|nil
function UnitPhaseReason(unit) return _rv end

--------------------------------------------------------------------------------
-- Group
--------------------------------------------------------------------------------
---@return number
function GetNumGroupMembers() return _rv end
---@return number
function GetNumSubgroupMembers() return _rv end
---@return boolean
function IsInRaid() return _rv end
---@return boolean
function IsInGroup() return _rv end

--------------------------------------------------------------------------------
-- Keybinding
--------------------------------------------------------------------------------
---@param command string
---@return string|nil, string|nil
function GetBindingKey(command) return _rv end
---@param key string
---@param command? string
---@return boolean
function SetBinding(key, command) return _rv end
---@param which number
function SaveBindings(which) return _rv end
---@return number
function GetCurrentBindingSet() return _rv end

--------------------------------------------------------------------------------
-- Shapeshift / Stance
--------------------------------------------------------------------------------
---@return number
function GetNumShapeshiftForms() return _rv end
---@param index number
---@return string, any, boolean, boolean
function GetShapeshiftFormInfo(index) return _rv end
---@param index number
---@return number, number, number
function GetShapeshiftFormCooldown(index) return _rv end

--------------------------------------------------------------------------------
-- Specialization
--------------------------------------------------------------------------------
---@return number|nil
function GetSpecialization() return _rv end
---@param specIndex number
---@return any, string, string, any, string
function GetSpecializationInfo(specIndex) return _rv end
---@param specIndex number
---@return string
function GetSpecializationRole(specIndex) return _rv end
---@return number
function GetNumSpecializations() return _rv end

--------------------------------------------------------------------------------
-- Power bar / Portrait
--------------------------------------------------------------------------------
---@param barID number
---@return any
function GetUnitPowerBarInfo(barID) return _rv end
---@param unit string
---@return number
function GetUnitTotalModifiedMaxHealthPercent(unit) return _rv end
---@param texture any
---@param unit string
function SetPortraitTexture(texture, unit) return _rv end
---@type any
PartyUtil = {}

--------------------------------------------------------------------------------
-- General info
--------------------------------------------------------------------------------
---@return string
function GetLocale() return _rv end
---@return string
function GetRealmName() return _rv end
---@return number
function GetTime() return _rv end
---@return number
function GetFramerate() return _rv end
---@param name string
---@return string|nil
function GetCVar(name) return _rv end
---@param name string
---@param value any
function SetCVar(name, value) return _rv end
---@return number
function GetScreenWidth() return _rv end
---@return number
function GetScreenHeight() return _rv end

--------------------------------------------------------------------------------
-- Spell / Item
--------------------------------------------------------------------------------
---@param spellID number
---@return any
function GetSpellInfo(spellID) return _rv end
---@param itemID any
---@return any
function GetItemInfo(itemID) return _rv end
---@param quality number
---@return number, number, number
function GetItemQualityColor(quality) return _rv end
---@param unit string
---@param slot number
---@return string|nil
function GetInventoryItemLink(unit, slot) return _rv end

--------------------------------------------------------------------------------
-- Container
--------------------------------------------------------------------------------
---@param bagID number
---@return number
function GetContainerNumSlots(bagID) return _rv end
---@param bagID number
---@param slot number
---@return any
function GetContainerItemInfo(bagID, slot) return _rv end
---@param bagID number
---@param slot number
---@return string|nil
function GetContainerItemLink(bagID, slot) return _rv end
---@param bagID number
---@param slot number
---@return number|nil
function GetContainerItemID(bagID, slot) return _rv end
---@param bagID number
---@param slot number
function UseContainerItem(bagID, slot) return _rv end
---@param bagID number
---@param slot number
function PickupContainerItem(bagID, slot) return _rv end

--------------------------------------------------------------------------------
-- Currency
--------------------------------------------------------------------------------
---@return number
function GetMoney() return _rv end
---@param amount number
---@return string
function GetCoinTextureString(amount) return _rv end

--------------------------------------------------------------------------------
-- Zone / Map
--------------------------------------------------------------------------------
---@return string
function GetMinimapZoneText() return _rv end
---@return string, boolean, string
function GetZonePVPInfo() return _rv end
---@return string
function GetRealZoneText() return _rv end
---@return string
function GetSubZoneText() return _rv end
---@return string
function GetMinimapShape() return _rv end

--------------------------------------------------------------------------------
-- Minimap frames
--------------------------------------------------------------------------------
---@type any
Minimap = {}
---@type any
MinimapCluster = {}
---@type any
MinimapBackdrop = {}
---@type any
MinimapZoneText = {}
---@type any
MinimapZoneTextButton = {}
---@type any
MiniMapMailFrame = {}
---@type any
MiniMapMailIcon = {}
---@type any
GameTimeFrame = {}
---@type any
TimeManagerClockButton = {}
---@type any
MiniMapTracking = {}
---@type any
MiniMapTrackingButton = {}
---@type any
MiniMapInstanceDifficulty = {}
---@type any
GuildInstanceDifficulty = {}
---@type any
MiniMapChallengeMode = {}
---@type any
QueueStatusButton = {}
---@type any
QueueStatusFrame = {}
---@type any
QueueStatusMinimapButton = {}
---@type any
ExpansionLandingPageMinimapButton = {}
---@type any
AddonCompartmentFrame = {}
---@return number, number
function Garrison_GetLandingPageIconSize() return _rv end
---@type any
MiniMapTrackingBackground = {}
---@type any
HybridMinimap = {}

--------------------------------------------------------------------------------
-- Action bar frames
--------------------------------------------------------------------------------
---@type any
StatusTrackingBarManager = {}
---@type any
StanceBar = {}
---@type any
StanceButton1 = {}
---@type any
PetActionBar = {}
---@type any
PetActionButton1 = {}
---@type any
MainMenuBar = {}
---@type any
MainMenuBarArtFrame = {}
---@type any
MainMenuBarArtFrameBackground = {}
---@type any
OverrideActionBar = {}
---@type any
MultiBarBottomLeft = {}
---@type any
MultiBarBottomRight = {}
---@type any
MultiBarRight = {}
---@type any
MultiBarLeft = {}
---@type any
MultiBar5 = {}
---@type any
MultiBar6 = {}
---@type any
MultiBar7 = {}
---@type any
MicroButtonAndBagsBar = {}
---@type any
BagsBar = {}
---@type any
CharacterBag0Slot = {}
---@type any
CharacterBag1Slot = {}
---@type any
CharacterBag2Slot = {}
---@type any
CharacterBag3Slot = {}
---@type any
MainMenuBarBackpackButton = {}
---@type any
ExtraActionBarFrame = {}
---@type any
ExtraActionButton1 = {}
---@type any
MainMenuBarManager = {}
---@type any
PossessActionBar = {}
---@type any
MainStatusTrackingBarContainer = {}
---@type any
SecondaryStatusTrackingBarContainer = {}
---@type any
ZoneAbilityFrame = {}
---@type any
MicroMenu = {}
---@type any
EncounterBar = {}
---@type any
PlayerPowerBarAlt = {}
---@type any
UIWidgetPowerBarContainerFrame = {}

--------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------
---@type any
GameTooltip = {}
---@type any
ItemRefTooltip = {}
---@type any
TooltipDataProcessor = {}

--------------------------------------------------------------------------------
-- Chat
--------------------------------------------------------------------------------
---@type any
ChatFrame1 = {}
---@type any
ChatFrame1EditBox = {}
---@type any
ChatFrame2 = {}
---@type any
ChatFrame3 = {}
---@type any
ChatTypeInfo = {}
---@type any
ChatFontNormal = {}
---@type any
CHAT_FRAMES = {}
---@type number
NUM_CHAT_WINDOWS = 0
---@return any
function FCF_GetCurrentChatFrame() return _rv end
---@param editBox any
function ChatEdit_ActivateChat(editBox) return _rv end
---@param editBox any
function ChatEdit_DeactivateChat(editBox) return _rv end
---@type any
DEFAULT_CHAT_FRAME = {}

--------------------------------------------------------------------------------
-- Secure functions
--------------------------------------------------------------------------------
---@param table any
---@param funcName string
---@param hookFunc function
function hooksecurefunc(table, funcName, hookFunc) return _rv end
---@param func function
---@vararg any
---@return any
function securecall(func, ...) return _rv end
---@param frame any
---@param attribute string
---@param values string
function RegisterStateDriver(frame, attribute, values) return _rv end
function ClearFocus() return _rv end

--------------------------------------------------------------------------------
-- Lua builtins / WoW extensions
--------------------------------------------------------------------------------
---@param t table
function wipe(t) return _rv end
---@param t table
---@param value any
---@param pos? number
function tinsert(t, value, pos) return _rv end
---@param t table
---@param pos? number
---@return any
function tremove(t, pos) return _rv end
---@param t table
---@param value any
---@return boolean
function tContains(t, value) return _rv end
---@param t table
---@return table
function CopyTable(t) return _rv end
---@param str string
---@param delimiter string
---@return string ...
function strsplit(delimiter, str) return _rv end
---@param str string
---@return string
function strtrim(str) return _rv end
---@param str string
---@param pattern string
---@return any
function strmatch(str, pattern) return _rv end
---@param str string
---@param pattern string
---@param init? number
---@return number|nil, number|nil
function strfind(str, pattern, init) return _rv end
---@param fmt string
---@vararg any
---@return string
function format(fmt, ...) return _rv end
---@type any
bit = {}
---@param coroutine? any
---@param start? number
---@param count? number
---@return string
function debugstack(coroutine, start, count) return _rv end
---@return function
function geterrorhandler() return _rv end
---@param func function
function seterrorhandler(func) return _rv end
---@param name string
---@param context string
---@return string
function Ambiguate(name, context) return _rv end
---@param r number
---@param g number
---@param b number
---@param a? number
---@return any
function CreateColor(r, g, b, a) return _rv end

--------------------------------------------------------------------------------
-- UI / Settings
--------------------------------------------------------------------------------
---@param category string
function InterfaceOptionsFrame_OpenToCategory(category) return _rv end
---@type any
Settings = {}
---@type any
SettingsPanel = {}
---@param soundKitID number
function PlaySound(soundKitID) return _rv end
---@param file string
function PlaySoundFile(file) return _rv end
---@type any
SOUNDKIT = {}
---@param which string
function StaticPopup_Show(which) return _rv end
---@type table
StaticPopupDialogs = {}
function ReloadUI() return _rv end
---@type table
SlashCmdList = {}
---@type string
SLASH_LUNARUI1 = ""
---@type string
SLASH_LUNARUI2 = ""
---@param frame any
---@param fadeInTime? number
---@param fadeOutTime? number
---@param flashDuration? number
---@param showWhenDone? boolean
---@param flashInHoldTime? number
---@param flashOutHoldTime? number
function UIFrameFlash(frame, fadeInTime, fadeOutTime, flashDuration, showWhenDone, flashInHoldTime, flashOutHoldTime) return _rv end
---@param cooldown any
---@param start number
---@param duration number
---@param enable? number
function CooldownFrame_Set(cooldown, start, duration, enable) return _rv end
---@type any
MerchantFrame = {}
---@type any
EditModeManagerFrame = {}
---@param name string
---@return boolean
function IsAddOnLoaded(name) return _rv end
---@param name string
function LoadAddOn(name) return _rv end

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
---@type table
RAID_CLASS_COLORS = {}
---@type table
ITEM_QUALITY_COLORS = {}
---@type table
FACTION_BAR_COLORS = {}
---@type number
LE_ITEM_QUALITY_POOR = 0
---@type number
LE_ITEM_QUALITY_COMMON = 1
---@type number
LE_ITEM_QUALITY_UNCOMMON = 2
---@type number
LE_ITEM_QUALITY_RARE = 3
---@type number
LE_ITEM_QUALITY_EPIC = 4
---@type number
LE_ITEM_QUALITY_LEGENDARY = 5
---@type number
LE_ITEM_QUALITY_ARTIFACT = 6
---@type number
LE_ITEM_QUALITY_HEIRLOOM = 7
---@type any
Enum = {}
---@type number
NUM_BAG_SLOTS = 4
---@type number
NUM_BANKBAGSLOTS = 7
---@type number
BACKPACK_CONTAINER = 0
---@type number
BANK_CONTAINER = -1
---@type number
REAGENTBANK_CONTAINER = -3

--------------------------------------------------------------------------------
-- Tooltip helpers (oUF / Nameplates)
--------------------------------------------------------------------------------
---@param tooltip any
---@param parent any
---@param anchor? string
function GameTooltip_SetDefaultAnchor(tooltip, parent, anchor) return _rv end

--------------------------------------------------------------------------------
-- Additional Unit functions (oUF)
--------------------------------------------------------------------------------
---@param unit string
---@return string
function UnitClassBase(unit) return _rv end
---@param unit string
---@return boolean
function UnitHasVehicleUI(unit) return _rv end
---@param barID number
---@return any
function GetUnitPowerBarStringsByID(barID) return _rv end
---@param unit string
---@return number
function UnitPowerBarID(unit) return _rv end
---@param barID number
---@return any
function GetUnitPowerBarInfoByID(barID) return _rv end
---@param unit string
---@return number
function UnitSelectionType(unit) return _rv end

--------------------------------------------------------------------------------
-- Inventory / Durability
--------------------------------------------------------------------------------
---@param slot number
---@return number|nil, number|nil
function GetInventoryItemDurability(slot) return _rv end

--------------------------------------------------------------------------------
-- Equipment slot name constants
--------------------------------------------------------------------------------
---@type string
HEADSLOT = "Head"
---@type string
SHOULDERSLOT = "Shoulder"
---@type string
CHESTSLOT = "Chest"
---@type string
WAISTSLOT = "Waist"
---@type string
LEGSSLOT = "Legs"
---@type string
FEETSLOT = "Feet"
---@type string
WRISTSLOT = "Wrist"
---@type string
HANDSSLOT = "Hands"
---@type string
MAINHANDSLOT = "Main Hand"
---@type string
SECONDARYHANDSLOT = "Off Hand"

--------------------------------------------------------------------------------
-- Friends / BattleNet
--------------------------------------------------------------------------------
---@type any
C_FriendList = {}
---@return number, number
function BNGetNumFriends() return _rv end
---@type any
C_BattleNet = {}
---@param tab? number
function ToggleFriendsFrame(tab) return _rv end

--------------------------------------------------------------------------------
-- Guild
--------------------------------------------------------------------------------
---@return boolean
function IsInGuild() return _rv end
---@type any
C_GuildInfo = {}
---@return number, number, number
function GetNumGuildMembers() return _rv end
function ToggleGuildFrame() return _rv end
---@param unit string
---@return string|nil, string|nil, number|nil
function GetGuildInfo(unit) return _rv end

--------------------------------------------------------------------------------
-- Talent / Spellbook UI
--------------------------------------------------------------------------------
function ToggleTalentFrame() return _rv end
---@type any
PlayerSpellsFrame = {}
function TogglePlayerSpellsFrame() return _rv end

--------------------------------------------------------------------------------
-- Date / Time
--------------------------------------------------------------------------------
---@type any
C_DateAndTime = {}

--------------------------------------------------------------------------------
-- Network
--------------------------------------------------------------------------------
---@return number, number, number, number
function GetNetStats() return _rv end

--------------------------------------------------------------------------------
-- Additional oUF / class-specific globals
--------------------------------------------------------------------------------
---@param unit string
---@param powerType number
---@return number
function UnitPowerDisplayMod(unit, powerType) return _rv end
---@return any
function GetUnitChargedPowerPoints() return _rv end
---@return boolean
function PlayerVehicleHasComboPoints() return _rv end
---@type any
C_SpecializationInfo = {}
---@type any
C_SpellBook = {}
---@param unit string
---@return any
function UnitCastingInfo(unit) return _rv end
---@param assignment string
---@param unit string
---@return boolean
function GetPartyAssignment(assignment, unit) return _rv end
---@return number
function UnitStagger(unit) return _rv end
---@type any
MonkStaggerBar = {}
---@param slot number
---@return any
function GetTotemInfo(slot) return _rv end

--------------------------------------------------------------------------------
-- Repair
--------------------------------------------------------------------------------
---@return number, boolean
function GetRepairAllCost() return _rv end
---@return number
function GetGuildBankWithdrawMoney() return _rv end
---@param useGuildFunds? boolean
function RepairAllItems(useGuildFunds) return _rv end

--------------------------------------------------------------------------------
-- Instance / Death
--------------------------------------------------------------------------------
---@return boolean, string
function IsInInstance() return _rv end
---@param unit string
---@return boolean
function UnitIsDeadOrGhost(unit) return _rv end
---@param unit string
---@return boolean
function UnitIsFeignDeath(unit) return _rv end
function RepopMe() return _rv end

--------------------------------------------------------------------------------
-- Screenshot
--------------------------------------------------------------------------------
function Screenshot() return _rv end
