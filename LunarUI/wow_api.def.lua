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
-- Class Definitions
--------------------------------------------------------------------------------

---@class LibStub
---@field GetLibrary fun(self: LibStub, name: string, silent?: boolean): table
---@field NewLibrary fun(self: LibStub, name: string, minor: number): table?
LibStub = {}

---@class Frame
---@field CreateTexture fun(self: Frame, name?: string, layer?: string, template?: string): Texture
---@field CreateFontString fun(self: Frame, name?: string, layer?: string, template?: string): FontString
---@field SetPoint fun(self: Frame, point: string, relativeToOrX?: Frame|string|number, relativePointOrY?: string|number, x?: number, y?: number)
---@field SetAllPoints fun(self: Frame, frame?: Frame|string)
---@field SetSize fun(self: Frame, width: number, height: number)
---@field SetWidth fun(self: Frame, width: number)
---@field SetHeight fun(self: Frame, height: number)
---@field SetAlpha fun(self: Frame, alpha: number)
---@field GetAlpha fun(self: Frame): number
---@field SetScale fun(self: Frame, scale: number)
---@field Show fun(self: Frame)
---@field Hide fun(self: Frame)
---@field IsShown fun(self: Frame): boolean
---@field IsVisible fun(self: Frame): boolean
---@field SetScript fun(self: Frame, event: string, handler: function?)
---@field GetScript fun(self: Frame, event: string): function?
---@field HookScript fun(self: Frame, event: string, handler: function)
---@field SetParent fun(self: Frame, parent: Frame|string)
---@field GetParent fun(self: Frame): Frame?
---@field SetFrameStrata fun(self: Frame, strata: string)
---@field SetFrameLevel fun(self: Frame, level: number)
---@field GetFrameLevel fun(self: Frame): number
---@field SetMovable fun(self: Frame, movable: boolean)
---@field SetClampedToScreen fun(self: Frame, clamped: boolean)
---@field EnableMouse fun(self: Frame, enable: boolean)
---@field EnableKeyboard fun(self: Frame, enable: boolean)
---@field RegisterForDrag fun(self: Frame, ...: string)
---@field StartMoving fun(self: Frame)
---@field StopMovingOrSizing fun(self: Frame)
---@field SetBackdrop fun(self: Frame, backdrop: table?)
---@field SetBackdropColor fun(self: Frame, r: number, g: number, b: number, a?: number)
---@field SetBackdropBorderColor fun(self: Frame, r: number, g: number, b: number, a?: number)
---@field GetWidth fun(self: Frame): number
---@field GetHeight fun(self: Frame): number
---@field GetSize fun(self: Frame): number, number
---@field GetPoint fun(self: Frame, index?: number): string, Frame, string, number, number
---@field GetChildren fun(self: Frame): ...
---@field GetRegions fun(self: Frame): ...
---@field GetName fun(self: Frame): string?
---@field ClearAllPoints fun(self: Frame)
---@field RegisterEvent fun(self: Frame, event: string)
---@field UnregisterEvent fun(self: Frame, event: string)
---@field UnregisterAllEvents fun(self: Frame)
---@field SetID fun(self: Frame, id: number)
---@field GetID fun(self: Frame): number
---@field GetNormalTexture fun(self: Frame): Texture?
---@field GetPushedTexture fun(self: Frame): Texture?
---@field GetHighlightTexture fun(self: Frame): Texture?
---@field GetCheckedTexture fun(self: Frame): Texture?
---@field SetFontObject fun(self: Frame, font: any)
---@field buttons table?
---@field bg Frame?
---@field id number?
---@field page number?
---@field LunarBorder Frame?

---@class Texture : Frame
---@field SetTexture fun(self: Texture, path: string|number)
---@field SetTexCoord fun(self: Texture, left: number, right: number, top: number, bottom: number)
---@field SetVertexColor fun(self: Texture, r: number, g: number, b: number, a?: number)
---@field SetBlendMode fun(self: Texture, mode: string)
---@field SetAllPoints fun(self: Texture, frame?: Frame)

---@class FontString : Frame
---@field SetText fun(self: FontString, text: string)
---@field SetTextColor fun(self: FontString, r: number, g: number, b: number, a?: number)
---@field SetFont fun(self: FontString, font: string, size: number, flags?: string)
---@field SetJustifyH fun(self: FontString, justify: string)
---@field SetJustifyV fun(self: FontString, justify: string)
---@field GetText fun(self: FontString): string
---@field SetFontObject fun(self: FontString, font: any)

---@class StatusBar : Frame
---@field SetStatusBarTexture fun(self: StatusBar, path: string)
---@field SetStatusBarColor fun(self: StatusBar, r: number, g: number, b: number, a?: number)
---@field SetMinMaxValues fun(self: StatusBar, min: number, max: number)
---@field SetValue fun(self: StatusBar, value: number)
---@field GetValue fun(self: StatusBar): number

---@class Button : Frame
---@field SetText fun(self: Button, text: string)
---@field GetText fun(self: Button): string
---@field SetNormalFontObject fun(self: Button, font: any)
---@field SetHighlightFontObject fun(self: Button, font: any)
---@field SetDisabledFontObject fun(self: Button, font: any)
---@field GetFontString fun(self: Button): FontString
---@field SetNormalTexture fun(self: Button, texture: string|number)
---@field SetPushedTexture fun(self: Button, texture: string|number)
---@field SetHighlightTexture fun(self: Button, texture: string|number)
---@field SetDisabledTexture fun(self: Button, texture: string|number)
---@field Click fun(self: Button)
---@field Disable fun(self: Button)
---@field Enable fun(self: Button)
---@field IsEnabled fun(self: Button): boolean

---@class EditBox : Frame
---@field SetText fun(self: EditBox, text: string)
---@field GetText fun(self: EditBox): string
---@field SetMultiLine fun(self: EditBox, multiLine: boolean)
---@field SetFont fun(self: EditBox, font: string, size: number, flags?: string)
---@field SetAutoFocus fun(self: EditBox, autoFocus: boolean)
---@field SetFocus fun(self: EditBox)
---@field ClearFocus fun(self: EditBox)
---@field HighlightText fun(self: EditBox, start?: number, stop?: number)
---@field SetMaxLetters fun(self: EditBox, maxLetters: number)
---@field SetNumeric fun(self: EditBox, numeric: boolean)
---@field SetPassword fun(self: EditBox, password: boolean)
---@field SetTextInsets fun(self: EditBox, left: number, right: number, top: number, bottom: number)
---@field SetCursorPosition fun(self: EditBox, position: number)
---@field GetCursorPosition fun(self: EditBox): number
---@field SetFontObject fun(self: EditBox, font: any)

---@class ScrollFrame : Frame
---@field SetScrollChild fun(self: ScrollFrame, child: Frame)
---@field GetScrollChild fun(self: ScrollFrame): Frame?
---@field SetVerticalScroll fun(self: ScrollFrame, offset: number)
---@field GetVerticalScroll fun(self: ScrollFrame): number
---@field SetHorizontalScroll fun(self: ScrollFrame, offset: number)
---@field GetHorizontalScroll fun(self: ScrollFrame): number
---@field UpdateScrollChildRect fun(self: ScrollFrame)
---@field editBox EditBox?

---@class ColorMixin
---@field r number
---@field g number
---@field b number
---@field a number?
---@field GetRGB fun(self: ColorMixin): number, number, number
---@field GetRGBA fun(self: ColorMixin): number, number, number, number
---@field SetRGB fun(self: ColorMixin, r: number, g: number, b: number)
---@field SetRGBA fun(self: ColorMixin, r: number, g: number, b: number, a: number)

---@class BackdropTemplateMixin
BackdropTemplateMixin = {}

---@class GameTooltip : Frame
---@field SetOwner fun(self: GameTooltip, owner: Frame, anchor?: string, x?: number, y?: number)
---@field SetUnit fun(self: GameTooltip, unit: string): boolean
---@field SetBagItem fun(self: GameTooltip, bagID: number, slot: number): boolean
---@field SetHyperlink fun(self: GameTooltip, link: string): boolean
---@field AddLine fun(self: GameTooltip, text: string, r?: number, g?: number, b?: number, wrap?: boolean)
---@field AddDoubleLine fun(self: GameTooltip, left: string, right: string, lr?: number, lg?: number, lb?: number, rr?: number, rg?: number, rb?: number)
---@field ClearLines fun(self: GameTooltip)
---@field GetUnit fun(self: GameTooltip): string?, string?

---@class TooltipDataProcessor
---@field AddTooltipPostCall fun(tooltipType: number|string, callback: function)
TooltipDataProcessor = {}

---@class SpellCooldownInfo
---@field startTime number
---@field duration number
---@field isEnabled boolean
---@field modRate number

---@class SpellInfo
---@field name string
---@field iconID number
---@field originalIconID number
---@field castTime number
---@field minRange number
---@field maxRange number
---@field spellID number

---@class AuraData
---@field name string
---@field icon number
---@field applications number
---@field duration number
---@field expirationTime number
---@field sourceUnit string?
---@field isStealable boolean
---@field dispelName string?
---@field spellId number
---@field canApplyAura boolean
---@field isBossAura boolean

--------------------------------------------------------------------------------
-- C_* Namespace Class Definitions
--------------------------------------------------------------------------------

---@class C_AddOns
---@field GetAddOnMetadata fun(name: string, field: string): string?
---@field IsAddOnLoaded fun(name: string): boolean
---@field LoadAddOn fun(name: string): boolean
---@field EnableAddOn fun(name: string, character?: string)
---@field DisableAddOn fun(name: string, character?: string)
---@field GetNumAddOns fun(): number
---@field GetAddOnInfo fun(index: number|string): string, string, string, boolean, string, string, string
C_AddOns = {}

---@class C_Timer
---@field After fun(seconds: number, callback: function)
---@field NewTimer fun(seconds: number, callback: function): table
---@field NewTicker fun(seconds: number, callback: function, iterations?: number): table
C_Timer = {}

---@class C_Container
---@field GetContainerNumSlots fun(bagID: number): number
---@field GetContainerItemInfo fun(bagID: number, slot: number): table?
---@field GetContainerItemLink fun(bagID: number, slot: number): string?
---@field GetContainerItemID fun(bagID: number, slot: number): number?
---@field UseContainerItem fun(bagID: number, slot: number)
---@field PickupContainerItem fun(bagID: number, slot: number)
---@field GetContainerNumFreeSlots fun(bagID: number): number, number
C_Container = {}

---@class C_Item
---@field GetItemInfo fun(itemID: number|string): string, string, number, number, number, string, string, number, string, number, number, number, number, number, number, number, boolean
---@field GetItemQualityColor fun(quality: number): number, number, number, string
---@field GetCurrentItemLevel fun(itemLocation: table): number?
C_Item = {}

---@class C_MountJournal
C_MountJournal = {}

---@class C_TooltipInfo
---@field GetBagItem fun(bagID: number, slot: number): table
---@field GetInventoryItem fun(unit: string, slot: number): table
---@field GetUnit fun(unit: string): table
---@field GetSpellByID fun(spellID: number): table
C_TooltipInfo = {}

---@class C_Minimap
---@field GetDrawGroundTextures fun(): boolean
---@field SetDrawGroundTextures fun(draw: boolean)
C_Minimap = {}

---@class C_Map
---@field GetBestMapForUnit fun(unit: string): number?
---@field GetPlayerMapPosition fun(mapID: number, unit: string): table?
C_Map = {}

---@class C_CVar
---@field GetCVar fun(name: string): string?
---@field SetCVar fun(name: string, value: string|number)
C_CVar = {}

---@class C_PetBattles
---@field IsInBattle fun(): boolean
C_PetBattles = {}

---@class C_QuestLog
C_QuestLog = {}

---@class C_NamePlate
C_NamePlate = {}

---@class C_NewItems
---@field IsNewItem fun(bagID: number, slotID: number): boolean
---@field RemoveNewItem fun(bagID: number, slotID: number)
C_NewItems = {}

---@class C_FriendList
C_FriendList = {}

---@class C_BattleNet
C_BattleNet = {}

---@class C_GuildInfo
C_GuildInfo = {}

---@class C_DateAndTime
C_DateAndTime = {}

---@class C_SpecializationInfo
C_SpecializationInfo = {}

---@class C_SpellBook
C_SpellBook = {}

---@class C_Spell
---@field GetSpellCooldown fun(spellID: number): SpellCooldownInfo?
---@field GetSpellInfo fun(spellID: number): SpellInfo?
---@field GetSpellTexture fun(spellID: number): number?
---@field GetSpellName fun(spellID: number): string?
C_Spell = {}

---@class C_UnitAuras
---@field GetBuffDataByIndex fun(unit: string, index: number, filter?: string): AuraData?
---@field GetDebuffDataByIndex fun(unit: string, index: number, filter?: string): AuraData?
---@field GetAuraDataByIndex fun(unit: string, index: number, filter: string): AuraData?
---@field GetAuraDataByAuraInstanceID fun(unit: string, auraInstanceID: number): AuraData?
C_UnitAuras = {}

---@class C_PvP
---@field GetZonePVPInfo fun(): string?
C_PvP = {}

---@class C_Calendar
---@field OpenCalendar fun()
---@field GetNumPendingInvites fun(): number
C_Calendar = {}

---@class Settings
---@field OpenToCategory fun(categoryID: string)
---@field RegisterCanvasLayoutCategory fun(frame: Frame, name: string): table
---@field RegisterAddOnCategory fun(category: table)
Settings = {}

---@class SOUNDKIT
---@field IG_MAINMENU_OPTION_CHECKBOX_ON number
---@field IG_MAINMENU_OPTION_CHECKBOX_OFF number
---@field IG_CHARACTER_INFO_TAB number
SOUNDKIT = {}

---@class Enum
Enum = {}

---@class bit
---@field band fun(a: number, b: number, ...): number
---@field bor fun(a: number, b: number, ...): number
---@field bxor fun(a: number, b: number, ...): number
---@field bnot fun(a: number): number
---@field lshift fun(a: number, b: number): number
---@field rshift fun(a: number, b: number): number
bit = {}

---@class HybridMinimap : Frame
---@field MapCanvas table
---@field CircleMask Texture
HybridMinimap = {}

--------------------------------------------------------------------------------
-- Frame creation & UI
--------------------------------------------------------------------------------
---@param frameType string
---@param name? string
---@param parent? any
---@param template? string
---@param id? number
---@return Frame
function CreateFrame(frameType, name, parent, template, id) return _rv end

---@param object any
---@vararg any
---@return any
function Mixin(object, ...) return _rv end

---@param r number
---@param g number
---@param b number
---@param a? number
---@return ColorMixin
function CreateColor(r, g, b, a) return _rv end

---@type Frame
UIParent = {}
---@type Frame
WorldFrame = {}
---@type any
GameFontNormal = {}
---@type any
GameFontNormalSmall = {}
---@type any
GameFontHighlight = {}
---@type any
GameFontHighlightSmall = {}
---@type any
ChatFontNormal = {}
---@type string
STANDARD_TEXT_FONT = ""

--------------------------------------------------------------------------------
-- Modifier keys
--------------------------------------------------------------------------------
---@return boolean
function IsShiftKeyDown() return _rv end
---@return boolean
function IsControlKeyDown() return _rv end
---@return boolean
function IsAltKeyDown() return _rv end
---@return boolean
function IsModifierKeyDown() return _rv end

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
---@return string
function UnitClassBase(unit) return _rv end
---@param unit string
---@return number
function UnitHealth(unit) return _rv end
---@param unit string
---@return number
function UnitHealthMax(unit) return _rv end
---@param unit string
---@return number
function UnitHealthPercent(unit) return _rv end
---@param unit string
---@param powerType? number
---@return number
function UnitPower(unit, powerType) return _rv end
---@param unit string
---@param powerType? number
---@return number
function UnitPowerMax(unit, powerType) return _rv end
---@param unit string
---@return number
function UnitPowerPercent(unit) return _rv end
---@param unit string
---@return number, string
function UnitPowerType(unit) return _rv end
---@param unit string
---@param powerType number
---@return number
function UnitPowerDisplayMod(unit, powerType) return _rv end
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
---@return number|nil
function UnitPhaseReason(unit) return _rv end
---@param unit string
---@return boolean
function UnitHasVehicleUI(unit) return _rv end
---@param unit string
---@return number
function UnitSelectionType(unit) return _rv end
---@param unit string
---@return boolean
function UnitIsDeadOrGhost(unit) return _rv end
---@param unit string
---@return boolean
function UnitIsFeignDeath(unit) return _rv end
---@param unit string
---@return any
function UnitCastingInfo(unit) return _rv end
---@param unit string
---@return number
function UnitStagger(unit) return _rv end
---@param unit string
---@return number
function UnitPowerBarID(unit) return _rv end
---@param unit string
---@return number
function GetUnitTotalModifiedMaxHealthPercent(unit) return _rv end

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
---@param assignment string
---@param unit string
---@return boolean
function GetPartyAssignment(assignment, unit) return _rv end
---@type any
PartyUtil = {}

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
---@param barID number
---@return any
function GetUnitPowerBarInfoByID(barID) return _rv end
---@param barID number
---@return any
function GetUnitPowerBarStringsByID(barID) return _rv end
---@return any
function GetUnitChargedPowerPoints() return _rv end
---@return boolean
function PlayerVehicleHasComboPoints() return _rv end
---@param texture any
---@param unit string
function SetPortraitTexture(texture, unit) return _rv end

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
---@return number
function GetMaxPlayerLevel() return _rv end
---@return number, number, number, number
function GetNetStats() return _rv end
---@return number, number
function GetGameTime() return _rv end

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
---@param spellID number
---@return boolean
function IsSpellKnown(spellID) return _rv end
---@param spellID number
---@return boolean
function IsPlayerSpell(spellID) return _rv end
---@param runeIndex number
---@return number, number, boolean
function GetRuneCooldown(runeIndex) return _rv end
---@param slot number
---@return any
function GetTotemInfo(slot) return _rv end

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
function GetZoneText() return _rv end
---@return string
function GetMinimapShape() return _rv end
---@return string, string, number, string, number, number, boolean, number, number, number
function GetInstanceInfo() return _rv end
---@param difficultyID number
---@return string?, string?, boolean?, boolean?, boolean?, boolean?, number?
function GetDifficultyInfo(difficultyID) return _rv end

--------------------------------------------------------------------------------
-- Minimap frames
--------------------------------------------------------------------------------
---@type Frame
Minimap = {}
---@type Frame
MinimapCluster = {}
---@type Frame
MinimapBackdrop = {}
---@type FontString
MinimapZoneText = {}
---@type Frame
MinimapZoneTextButton = {}
---@type Frame
MiniMapMailFrame = {}
---@type Texture
MiniMapMailIcon = {}
---@type Frame
GameTimeFrame = {}
---@type Frame
TimeManagerClockButton = {}
---@type Frame
MiniMapTracking = {}
---@type Frame
MiniMapTrackingButton = {}
---@type Frame
MiniMapTrackingBackground = {}
---@type Frame
MiniMapInstanceDifficulty = {}
---@type Frame
GuildInstanceDifficulty = {}
---@type Frame
MiniMapChallengeMode = {}
---@type Frame
QueueStatusButton = {}
---@type Frame
QueueStatusFrame = {}
---@type Frame
QueueStatusMinimapButton = {}
---@type Frame
ExpansionLandingPageMinimapButton = {}
---@type Frame
AddonCompartmentFrame = {}
---@type Frame
MinimapBorder = {}
---@type Frame
MinimapBorderTop = {}
---@type Button
MinimapZoomIn = {}
---@type Button
MinimapZoomOut = {}
---@type Button
MinimapToggleButton = {}
---@type Button
MiniMapWorldMapButton = {}
---@type Frame
MiniMapMailBorder = {}
---@type Frame
MiniMapTrackingDropDown = {}
---@return number, number
function Garrison_GetLandingPageIconSize() return _rv end
function Minimap_ZoomIn() return _rv end
function Minimap_ZoomOut() return _rv end
---@return boolean
function HasNewMail() return _rv end

--------------------------------------------------------------------------------
-- Action bar frames
--------------------------------------------------------------------------------
---@type Frame
StatusTrackingBarManager = {}
---@type Frame
StanceBar = {}
---@type Frame
StanceButton1 = {}
---@type Frame
PetActionBar = {}
---@type Frame
PetActionButton1 = {}
---@type Frame
MainMenuBar = {}
---@type Frame
MainMenuBarArtFrame = {}
---@type Frame
MainMenuBarArtFrameBackground = {}
---@type Frame
OverrideActionBar = {}
---@type Frame
MultiBarBottomLeft = {}
---@type Frame
MultiBarBottomRight = {}
---@type Frame
MultiBarRight = {}
---@type Frame
MultiBarLeft = {}
---@type Frame
MultiBar5 = {}
---@type Frame
MultiBar6 = {}
---@type Frame
MultiBar7 = {}
---@type Frame
MicroButtonAndBagsBar = {}
---@type Frame
BagsBar = {}
---@type Frame
CharacterBag0Slot = {}
---@type Frame
CharacterBag1Slot = {}
---@type Frame
CharacterBag2Slot = {}
---@type Frame
CharacterBag3Slot = {}
---@type Frame
MainMenuBarBackpackButton = {}
---@type Frame
ExtraActionBarFrame = {}
---@type Frame
ExtraActionButton1 = {}
---@type Frame
MainMenuBarManager = {}
---@type Frame
PossessActionBar = {}
---@type Frame
MainStatusTrackingBarContainer = {}
---@type Frame
SecondaryStatusTrackingBarContainer = {}
---@type Frame
ZoneAbilityFrame = {}
---@type Frame
MicroMenu = {}
---@type Frame
EncounterBar = {}
---@type Frame
PlayerPowerBarAlt = {}
---@type Frame
UIWidgetPowerBarContainerFrame = {}

--------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------
---@type GameTooltip
GameTooltip = {}
---@type GameTooltip
ItemRefTooltip = {}
---@type StatusBar
GameTooltipStatusBar = {}
---@type GameTooltip
ShoppingTooltip1 = {}
---@type GameTooltip
ShoppingTooltip2 = {}
---@type GameTooltip
ItemRefShoppingTooltip1 = {}
---@type GameTooltip
ItemRefShoppingTooltip2 = {}
---@type GameTooltip
WorldMapTooltip = {}
---@type GameTooltip
WorldMapCompareTooltip1 = {}
---@type GameTooltip
WorldMapCompareTooltip2 = {}
---@type GameTooltip
SmallTextTooltip = {}
---@type Frame
EmbeddedItemTooltip = {}
---@type GameTooltip
NamePlateTooltip = {}
---@type Frame
BattlePetTooltip = {}
---@type Frame
FloatingBattlePetTooltip = {}
---@type Frame
FloatingPetBattleAbilityTooltip = {}
---@type Frame
PetBattlePrimaryUnitTooltip = {}
---@type Frame
PetBattlePrimaryAbilityTooltip = {}
---@param tooltip any
---@param parent any
---@param anchor? string
function GameTooltip_SetDefaultAnchor(tooltip, parent, anchor) return _rv end

--------------------------------------------------------------------------------
-- Chat
--------------------------------------------------------------------------------
---@type Frame
ChatFrame1 = {}
---@type Frame
ChatFrame1EditBox = {}
---@type Frame
ChatFrame2 = {}
---@type Frame
ChatFrame3 = {}
---@type table
ChatTypeInfo = {}
---@type table
CHAT_FRAMES = {}
---@type number
NUM_CHAT_WINDOWS = 0
---@type Frame
DEFAULT_CHAT_FRAME = {}
---@type Button
ChatFrameMenuButton = {}
---@type Button
ChatFrameChannelButton = {}
---@type Button
QuickJoinToastButton = {}
---@return any
function FCF_GetCurrentChatFrame() return _rv end
---@param editBox any
function ChatEdit_ActivateChat(editBox) return _rv end
---@param editBox any
function ChatEdit_DeactivateChat(editBox) return _rv end
---@param event string
---@param filter function
function ChatFrame_AddMessageEventFilter(event, filter) return _rv end
---@param self Frame
---@param link string
---@param text string
---@param button string
function ChatFrame_OnHyperlinkShow(self, link, text, button) return _rv end
---@param chatType string
---@param r number
---@param g number
---@param b number
function ChangeChatColor(chatType, r, g, b) return _rv end
---@param chatType string
---@param enable boolean
function SetChatColorNameByClass(chatType, enable) return _rv end
---@param frame any
---@return boolean
function MouseIsOver(frame) return _rv end

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
-- UnitFrame helpers
--------------------------------------------------------------------------------
---@param frame Frame
---@param handler function
function UnitFrame_OnEnter(frame, handler) return _rv end
---@param frame Frame
function UnitFrame_OnLeave(frame) return _rv end

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
---@param list table
---@param i? number
---@param j? number
---@return ...
function unpack(list, i, j) return _rv end
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
---@vararg any
function print(...) return _rv end
---@param func function
---@vararg any
---@return boolean, any
function pcall(func, ...) return _rv end
---@param func function
---@param handler function
---@vararg any
---@return boolean, any
function xpcall(func, handler, ...) return _rv end

--------------------------------------------------------------------------------
-- Math / Time builtins
--------------------------------------------------------------------------------
---@param x number
---@return number
function floor(x) return _rv end
---@param x number
---@return number
function ceil(x) return _rv end
---@param x number
---@return number
function abs(x) return _rv end
---@vararg number
---@return number
function min(...) return _rv end
---@vararg number
---@return number
function max(...) return _rv end
---@param m? number
---@param n? number
---@return number
function random(m, n) return _rv end
---@param format? string
---@param time? number
---@return string|table
function date(format, time) return _rv end
---@param table? table
---@return number
function time(table) return _rv end

--------------------------------------------------------------------------------
-- UI / Settings
--------------------------------------------------------------------------------
---@param category string
function InterfaceOptionsFrame_OpenToCategory(category) return _rv end
---@type Frame
SettingsPanel = {}
---@param soundKitID number
function PlaySound(soundKitID) return _rv end
---@param file string
function PlaySoundFile(file) return _rv end
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
---@type Frame
MerchantFrame = {}
---@type Frame
EditModeManagerFrame = {}
---@param name string
---@return boolean
function IsAddOnLoaded(name) return _rv end
---@param name string
function LoadAddOn(name) return _rv end
---@param level number
---@param value any
---@param dropDownFrame Frame
---@param anchorName? string
---@param xOffset? number
---@param yOffset? number
function ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset) return _rv end

--------------------------------------------------------------------------------
-- UI Widget frames
--------------------------------------------------------------------------------
---@type Frame
UIWidgetBelowMinimapContainerFrame = {}
---@type Frame
UIWidgetTopCenterContainerFrame = {}
---@type Frame
UIWidgetCenterScreenContainerFrame = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
---@type table
RAID_CLASS_COLORS = {}
---@type table
ITEM_QUALITY_COLORS = {}
---@type table
FACTION_BAR_COLORS = {}
---@type table
DebuffTypeColor = {}
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
---@type string
CLOSE = ""

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
-- Combat log
--------------------------------------------------------------------------------
---@return ...
function CombatLogGetCurrentEventInfo() return _rv end
---@param destFlags number
---@return boolean
function CombatLog_Object_IsA(destFlags) return _rv end
---@type number
COMBATLOG_OBJECT_TYPE_PLAYER = 0
---@type number
COMBATLOG_OBJECT_AFFILIATION_MINE = 0
---@type number
COMBATLOG_OBJECT_REACTION_HOSTILE = 0
---@type number
COMBATLOG_OBJECT_REACTION_FRIENDLY = 0

--------------------------------------------------------------------------------
-- Bags / Bank frames
--------------------------------------------------------------------------------
function CloseAllBags() return _rv end
function CloseBankFrame() return _rv end
---@param button Button
---@param desaturated boolean
function SetItemButtonDesaturated(button, desaturated) return _rv end
---@type Frame
ContainerFrameCombinedBags = {}
---@type Frame
BankFrame = {}
---@type Frame
AccountBankPanel = {}
---@type Frame
QuestScrollFrame = {}

--------------------------------------------------------------------------------
-- Friends / BattleNet
--------------------------------------------------------------------------------
---@return number, number
function BNGetNumFriends() return _rv end
---@param tab? number
function ToggleFriendsFrame(tab) return _rv end

--------------------------------------------------------------------------------
-- Guild
--------------------------------------------------------------------------------
---@return boolean
function IsInGuild() return _rv end
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
---@type Frame
PlayerSpellsFrame = {}
function TogglePlayerSpellsFrame() return _rv end

--------------------------------------------------------------------------------
-- Instance / Death
--------------------------------------------------------------------------------
---@return boolean, string
function IsInInstance() return _rv end
function RepopMe() return _rv end

--------------------------------------------------------------------------------
-- Inventory / Durability
--------------------------------------------------------------------------------
---@param slot number
---@return number|nil, number|nil
function GetInventoryItemDurability(slot) return _rv end

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
-- Monk
--------------------------------------------------------------------------------
---@type Frame
MonkStaggerBar = {}

--------------------------------------------------------------------------------
-- Screenshot
--------------------------------------------------------------------------------
function Screenshot() return _rv end
