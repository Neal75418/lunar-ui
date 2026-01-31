---@meta
--[[
    EmmyLua 全域變數定義
    用於 IntelliJ IDEA / EmmyLua 插件消除 undefined global 警告
    此檔案不會被遊戲載入（不在 TOC 中）
]]

--------------------------------------------------------------------------------
-- Ace3 函式庫
--------------------------------------------------------------------------------

---@class LibStub
---@field GetLibrary fun(self: LibStub, name: string, silent?: boolean): table
---@field NewLibrary fun(self: LibStub, name: string, minor: number): table?
LibStub = {}

--------------------------------------------------------------------------------
-- 框架與 UI 基礎
--------------------------------------------------------------------------------

---@class Frame
---@field CreateTexture fun(self: Frame, name?: string, layer?: string, template?: string): Texture
---@field CreateFontString fun(self: Frame, name?: string, layer?: string, template?: string): FontString
---@field SetPoint fun(self: Frame, point: string, relativeToOrX?: Frame|string|number, relativePointOrY?: string|number, x?: number, y?: number)
---@field SetAllPoints fun(self: Frame, frame?: Frame|string)
---@field SetSize fun(self: Frame, width: number, height: number)
---@field SetWidth fun(self: Frame, width: number)
---@field SetHeight fun(self: Frame, height: number)
---@field SetAlpha fun(self: Frame, alpha: number)
---@field SetScale fun(self: Frame, scale: number)
---@field Show fun(self: Frame)
---@field Hide fun(self: Frame)
---@field IsShown fun(self: Frame): boolean
---@field IsVisible fun(self: Frame): boolean
---@field SetScript fun(self: Frame, event: string, handler: function?)
---@field GetScript fun(self: Frame, event: string): function?
---@field HookScript fun(self: Frame, event: string, handler: function)
---@field SetParent fun(self: Frame, parent: Frame|string)
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
---@field GetParent fun(self: Frame): Frame?
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

---@class ScrollFrame : Frame
---@field SetScrollChild fun(self: ScrollFrame, child: Frame)
---@field GetScrollChild fun(self: ScrollFrame): Frame?
---@field SetVerticalScroll fun(self: ScrollFrame, offset: number)
---@field GetVerticalScroll fun(self: ScrollFrame): number
---@field SetHorizontalScroll fun(self: ScrollFrame, offset: number)
---@field GetHorizontalScroll fun(self: ScrollFrame): number
---@field UpdateScrollChildRect fun(self: ScrollFrame)
---@field editBox EditBox?

---@type fun(frameType: string, name?: string, parent?: Frame|string, template?: string, id?: number): Frame
CreateFrame = nil

---@class ColorMixin
---@field r number
---@field g number
---@field b number
---@field a number?
---@field GetRGB fun(self: ColorMixin): number, number, number
---@field GetRGBA fun(self: ColorMixin): number, number, number, number
---@field SetRGB fun(self: ColorMixin, r: number, g: number, b: number)
---@field SetRGBA fun(self: ColorMixin, r: number, g: number, b: number, a: number)

---@type fun(r: number, g: number, b: number, a?: number): ColorMixin
CreateColor = nil

---@type Frame
UIParent = nil

---@type Frame
WorldFrame = nil

---@type string
STANDARD_TEXT_FONT = nil

---@type string
GameFontNormal = nil

---@type string
GameFontNormalSmall = nil

---@type string
GameFontHighlight = nil

---@type string
GameFontHighlightSmall = nil

---@class BackdropTemplateMixin
BackdropTemplateMixin = {}

---@type fun(...): table
Mixin = nil

--------------------------------------------------------------------------------
-- 鍵盤修飾鍵
--------------------------------------------------------------------------------

---@type fun(): boolean
IsShiftKeyDown = nil

---@type fun(): boolean
IsControlKeyDown = nil

---@type fun(): boolean
IsAltKeyDown = nil

---@type fun(): boolean
IsModifierKeyDown = nil

--------------------------------------------------------------------------------
-- C_API 命名空間
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

-- 舊版 API 相容（已棄用，但仍可使用）
---@type fun(name: string): boolean
IsAddOnLoaded = nil

---@type fun(name: string): boolean
LoadAddOn = nil

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

---@class C_MountJournal
C_MountJournal = {}

--------------------------------------------------------------------------------
-- 單位函數
--------------------------------------------------------------------------------

---@type fun(unit: string): boolean
UnitExists = nil

---@type fun(unit: string): boolean
UnitIsDead = nil

---@type fun(unit: string): boolean
UnitIsGhost = nil

---@type fun(unit1: string, unit2: string): boolean
UnitIsUnit = nil

---@type fun(unit: string): string, string
UnitName = nil

---@type fun(unit: string): string, string, number
UnitClass = nil

---@type fun(unit: string): number
UnitHealth = nil

---@type fun(unit: string): number
UnitHealthMax = nil

---@type fun(unit: string, powerType?: number): number
UnitPower = nil

---@type fun(unit: string, powerType?: number): number
UnitPowerMax = nil

---@type fun(unit: string): number, string
UnitPowerType = nil

---@type fun(unit: string): number
UnitLevel = nil

---@type fun(unit: string): number
UnitEffectiveLevel = nil

---@type fun(unit: string): number?
GetNumSpecializations = nil

---@type fun(specIndex: number): number, string, string, string, string, string, number
GetSpecializationInfo = nil

---@type fun(unitToken: string): boolean
UnitIsPlayer = nil

---@type fun(unit1: string, unit2: string): boolean
UnitIsEnemy = nil

---@type fun(unit1: string, unit2: string): boolean
UnitIsFriend = nil

---@type fun(unit1: string, unit2: string): number?
UnitReaction = nil

---@type fun(unit: string): boolean
UnitAffectingCombat = nil

---@type fun(unit: string, otherUnit?: string): number?
UnitThreatSituation = nil

---@type fun(unit: string): string
UnitClassification = nil

---@type fun(unit: string): string?
UnitCreatureType = nil

---@type fun(unit: string): string?
UnitGUID = nil

---@type fun(unit: string): string
UnitGroupRolesAssigned = nil

---@type fun(unit: string): boolean
UnitInRaid = nil

---@type fun(unit: string): boolean
UnitInParty = nil

--------------------------------------------------------------------------------
-- 群組函數
--------------------------------------------------------------------------------

---@type fun(): number
GetNumGroupMembers = nil

---@type fun(): number
GetNumSubgroupMembers = nil

---@type fun(): boolean
IsInRaid = nil

---@type fun(): boolean
IsInGroup = nil

--------------------------------------------------------------------------------
-- 快捷鍵函數
--------------------------------------------------------------------------------

---@type fun(action: string, mode?: number): string?, string?
GetBindingKey = nil

---@type fun(key: string, action?: string, mode?: number): boolean
SetBinding = nil

---@type fun(which: number)
SaveBindings = nil

---@type fun(): number
GetCurrentBindingSet = nil

--------------------------------------------------------------------------------
-- 姿態/變形函數
--------------------------------------------------------------------------------

---@type fun(): number
GetNumShapeshiftForms = nil

---@type fun(index: number): string?, string?, boolean, boolean, boolean
GetShapeshiftFormInfo = nil

---@type fun(index: number): number, number, number
GetShapeshiftFormCooldown = nil

--------------------------------------------------------------------------------
-- 一般遊戲函數
--------------------------------------------------------------------------------

---@type fun(): string
GetLocale = nil

---@type fun(): string
GetRealmName = nil

---@type fun(): number
GetTime = nil

---@type fun(): number
GetFramerate = nil

---@type fun(): number
GetScreenWidth = nil

---@type fun(): number
GetScreenHeight = nil

---@type fun(): number, number, number, number
GetNetStats = nil

---@type fun(name: string): string?
GetCVar = nil

---@type fun(name: string, value: string|number)
SetCVar = nil

---@type fun(spellID: number): string?, number?, number?, number?, number?, number?, number?
GetSpellInfo = nil

---@type fun(itemID: number|string): string?, string?, number?, number?, number?, string?, string?, number?, string?, number?, number?
GetItemInfo = nil

---@type fun(unit: string, slot: number): string?
GetInventoryItemLink = nil

---@type fun(quality: number): number, number, number, string
GetItemQualityColor = nil

---@type fun(): number
GetMoney = nil

---@type fun(copper: number): string
GetCoinTextureString = nil

---@type fun(): boolean
InCombatLockdown = nil

---@type fun(): number
GetMaxPlayerLevel = nil

---@type fun(frame: Frame, state: string, driver: string)
RegisterStateDriver = nil

---@type fun(frame: Frame, handler: function)
UnitFrame_OnEnter = nil

---@type fun(frame: Frame)
UnitFrame_OnLeave = nil

--------------------------------------------------------------------------------
-- 小地圖相關
--------------------------------------------------------------------------------

---@type fun(): string
GetMinimapZoneText = nil

---@type fun(): string?, boolean, string?
GetZonePVPInfo = nil

---@type fun(): string
GetRealZoneText = nil

---@type fun(): string
GetSubZoneText = nil

---@type Frame
Minimap = nil

---@type Frame
MinimapCluster = nil

---@type Frame
MinimapBackdrop = nil

---@type FontString
MinimapZoneText = nil

---@type Frame
MinimapZoneTextButton = nil

---@type Frame
MiniMapMailFrame = nil

---@type Texture
MiniMapMailIcon = nil

---@type Frame
GameTimeFrame = nil

---@type Frame
TimeManagerClockButton = nil

---@type Frame
MiniMapTracking = nil

---@type Frame
MiniMapTrackingButton = nil

---@type Frame
MiniMapInstanceDifficulty = nil

---@type Frame
GuildInstanceDifficulty = nil

---@type Frame
MiniMapChallengeMode = nil

---@type Frame
QueueStatusButton = nil

---@type Frame
QueueStatusFrame = nil

---@type Frame
QueueStatusMinimapButton = nil

---@type Frame
ExpansionLandingPageMinimapButton = nil

---@type Frame
AddonCompartmentFrame = nil

---@type fun(): number, number
Garrison_GetLandingPageIconSize = nil

--------------------------------------------------------------------------------
-- 動作條相關
--------------------------------------------------------------------------------

---@type Frame
StatusTrackingBarManager = nil

---@type Frame
StanceBar = nil

---@type Frame
StanceButton1 = nil

---@type Frame
PetActionBar = nil

---@type Frame
PetActionButton1 = nil

---@type Frame
MainMenuBar = nil

---@type Frame
MainMenuBarArtFrame = nil

---@type Frame
MainMenuBarArtFrameBackground = nil

---@type Frame
OverrideActionBar = nil

---@type Frame
MultiBarBottomLeft = nil

---@type Frame
MultiBarBottomRight = nil

---@type Frame
MultiBarRight = nil

---@type Frame
MultiBarLeft = nil

---@type Frame
MultiBar5 = nil

---@type Frame
MultiBar6 = nil

---@type Frame
MultiBar7 = nil

---@type Frame
MicroButtonAndBagsBar = nil

---@type Frame
BagsBar = nil

---@type Frame
CharacterBag0Slot = nil

---@type Frame
CharacterBag1Slot = nil

---@type Frame
CharacterBag2Slot = nil

---@type Frame
CharacterBag3Slot = nil

---@type Frame
MainMenuBarBackpackButton = nil

--------------------------------------------------------------------------------
-- 提示框
--------------------------------------------------------------------------------

---@class GameTooltip : Frame
---@field SetOwner fun(self: GameTooltip, owner: Frame, anchor?: string, x?: number, y?: number)
---@field SetUnit fun(self: GameTooltip, unit: string): boolean
---@field SetBagItem fun(self: GameTooltip, bagID: number, slot: number): boolean
---@field SetHyperlink fun(self: GameTooltip, link: string): boolean
---@field AddLine fun(self: GameTooltip, text: string, r?: number, g?: number, b?: number, wrap?: boolean)
---@field AddDoubleLine fun(self: GameTooltip, left: string, right: string, lr?: number, lg?: number, lb?: number, rr?: number, rg?: number, rb?: number)
---@field ClearLines fun(self: GameTooltip)
---@field GetUnit fun(self: GameTooltip): string?, string?
GameTooltip = {}

---@type GameTooltip
ItemRefTooltip = nil

---@class TooltipDataProcessor
---@field AddTooltipPostCall fun(tooltipType: number|string, callback: function)
TooltipDataProcessor = {}

--------------------------------------------------------------------------------
-- 聊天框
--------------------------------------------------------------------------------

---@type Frame
ChatFrame1 = nil

---@type Frame
ChatFrame1EditBox = nil

---@type Frame
ChatFrame2 = nil

---@type Frame
ChatFrame3 = nil

---@type table
ChatTypeInfo = {}

---@type table
CHAT_FRAMES = {}

---@type number
NUM_CHAT_WINDOWS = 10

---@type fun(): Frame
FCF_GetCurrentChatFrame = nil

---@type fun(editBox: Frame)
ChatEdit_ActivateChat = nil

---@type fun(editBox: Frame)
ChatEdit_DeactivateChat = nil

--------------------------------------------------------------------------------
-- Hook 與安全函數
--------------------------------------------------------------------------------

---@type fun(table: table|string, method: string, hook: function)
hooksecurefunc = nil

---@type fun(func: function, ...: any): any
securecall = nil

---@type fun(func: function, ...: any): boolean, any
pcall = nil

---@type fun(func: function, handler: function, ...: any): boolean, any
xpcall = nil

--------------------------------------------------------------------------------
-- 表格函數
--------------------------------------------------------------------------------

---@type fun(table: table): table
wipe = nil

---@type fun(table: table, value: any, pos?: number)
tinsert = nil

---@type fun(table: table, pos?: number): any
tremove = nil

---@type fun(table: table, value: any): boolean
tContains = nil

---@type fun(table: table): table
CopyTable = nil

---@type fun(list: table, i?: number, j?: number): ...
unpack = nil

--------------------------------------------------------------------------------
-- 字串函數
--------------------------------------------------------------------------------

---@type fun(str: string, delimiter: string, pieces?: number): ...
strsplit = nil

---@type fun(str: string, chars?: string): string
strtrim = nil

---@type fun(str: string, pattern: string, init?: number): ...
strmatch = nil

---@type fun(str: string, pattern: string, init?: number, plain?: boolean): number?, number?, ...
strfind = nil

---@type fun(fmt: string, ...: any): string
format = nil

--------------------------------------------------------------------------------
-- 數學與時間
--------------------------------------------------------------------------------

---@type fun(format?: string, time?: number): string|table
date = nil

---@type fun(table?: table): number
time = nil

---@type fun(x: number): number
floor = nil

---@type fun(x: number): number
ceil = nil

---@type fun(x: number): number
abs = nil

---@type fun(...: number): number
min = nil

---@type fun(...: number): number
max = nil

---@type fun(m?: number, n?: number): number
random = nil

--------------------------------------------------------------------------------
-- Bitwise Library (LuaJIT / Classic)
--------------------------------------------------------------------------------

---@class bit
---@field band fun(a: number, b: number, ...): number
---@field bor fun(a: number, b: number, ...): number
---@field bxor fun(a: number, b: number, ...): number
---@field bnot fun(a: number): number
---@field lshift fun(a: number, b: number): number
---@field rshift fun(a: number, b: number): number
bit = {}

--------------------------------------------------------------------------------
-- 除錯與輸出
--------------------------------------------------------------------------------

---@type fun(...: any)
print = nil

---@type fun(start?: number, count?: number, thread?: thread): string
debugstack = nil

---@type fun(): function
geterrorhandler = nil

---@type fun(handler: function): function
seterrorhandler = nil

--------------------------------------------------------------------------------
-- 設定介面
--------------------------------------------------------------------------------

---@type fun(category: string|Frame)
InterfaceOptionsFrame_OpenToCategory = nil

---@class Settings
---@field OpenToCategory fun(categoryID: string)
---@field RegisterCanvasLayoutCategory fun(frame: Frame, name: string): table
---@field RegisterAddOnCategory fun(category: table)
Settings = {}

---@type Frame
SettingsPanel = nil

--------------------------------------------------------------------------------
-- 音效與彈窗
--------------------------------------------------------------------------------

---@type fun(soundKitID: number, channel?: string, forceNoDuplicates?: boolean)
PlaySound = nil

---@class SOUNDKIT
---@field IG_MAINMENU_OPTION_CHECKBOX_ON number
---@field IG_MAINMENU_OPTION_CHECKBOX_OFF number
---@field IG_CHARACTER_INFO_TAB number
SOUNDKIT = {}

---@type fun(which: string, text_arg1?: any, text_arg2?: any, data?: any): Frame?
StaticPopup_Show = nil

---@type table<string, table>
StaticPopupDialogs = {}

---@type fun()
ReloadUI = nil

--------------------------------------------------------------------------------
-- 斜線命令
--------------------------------------------------------------------------------

---@type table<string, function>
SlashCmdList = {}

---@type string
SLASH_LUNARUI1 = nil

---@type string
SLASH_LUNARUI2 = nil

--------------------------------------------------------------------------------
-- 顏色與品質常數
--------------------------------------------------------------------------------

---@type table<string, table>
RAID_CLASS_COLORS = {}

---@type table<number, table>
ITEM_QUALITY_COLORS = {}

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

---@class Enum
Enum = {}

--------------------------------------------------------------------------------
-- 背包常數
--------------------------------------------------------------------------------

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
-- 聊天常數
--------------------------------------------------------------------------------

---@type Frame
DEFAULT_CHAT_FRAME = nil

---@type table
FACTION_BAR_COLORS = {}

--------------------------------------------------------------------------------
-- UI 元件框架
--------------------------------------------------------------------------------

---@type Frame
PlayerPowerBarAlt = nil

---@type Frame
UIWidgetPowerBarContainerFrame = nil

---@type Frame
UIWidgetBelowMinimapContainerFrame = nil

---@type Frame
UIWidgetTopCenterContainerFrame = nil

---@type Frame
UIWidgetCenterScreenContainerFrame = nil

---@type table
DebuffTypeColor = {}

--------------------------------------------------------------------------------
-- 滑鼠提示框架
--------------------------------------------------------------------------------

---@type StatusBar
GameTooltipStatusBar = nil

---@type GameTooltip
ShoppingTooltip1 = nil

---@type GameTooltip
ShoppingTooltip2 = nil

---@type GameTooltip
ItemRefShoppingTooltip1 = nil

---@type GameTooltip
ItemRefShoppingTooltip2 = nil

---@type GameTooltip
WorldMapTooltip = nil

---@type GameTooltip
WorldMapCompareTooltip1 = nil

---@type GameTooltip
WorldMapCompareTooltip2 = nil

---@type GameTooltip
SmallTextTooltip = nil

---@type Frame
EmbeddedItemTooltip = nil

---@type GameTooltip
NamePlateTooltip = nil

---@type Frame
QuestScrollFrame = nil

---@type Frame
BattlePetTooltip = nil

---@type Frame
FloatingBattlePetTooltip = nil

---@type Frame
FloatingPetBattleAbilityTooltip = nil

---@type Frame
PetBattlePrimaryUnitTooltip = nil

---@type Frame
PetBattlePrimaryAbilityTooltip = nil

---@type fun(unit: string): string?, string?
GetGuildInfo = nil

--------------------------------------------------------------------------------
-- 小地圖相關框架與函數
--------------------------------------------------------------------------------

---@type fun(): string
GetZoneText = nil

---@type fun(): number, number
GetGameTime = nil

---@class C_PvP
---@field GetZonePVPInfo fun(): string?
C_PvP = {}

---@class C_Calendar
---@field OpenCalendar fun()
---@field GetNumPendingInvites fun(): number
C_Calendar = {}

---@type Frame
MinimapBorder = nil

---@type Frame
MinimapBorderTop = nil

---@type Button
MinimapZoomIn = nil

---@type Button
MinimapZoomOut = nil

---@type Button
MinimapToggleButton = nil

---@type Button
MiniMapWorldMapButton = nil

---@type Frame
MiniMapMailBorder = nil

---@type fun()
Minimap_ZoomIn = nil

---@type fun()
Minimap_ZoomOut = nil

---@type fun(level: number, value: any, dropDownFrame: Frame, anchorName: string?, xOffset?: number, yOffset?: number)
ToggleDropDownMenu = nil

---@type Frame
MiniMapTrackingDropDown = nil

---@type fun(): boolean
HasNewMail = nil

---@type fun(): string, string, number, string, number, number, boolean, number, number, number
GetInstanceInfo = nil

---@type fun(difficultyID: number): string?, string?, boolean?, boolean?, boolean?, boolean?, number?
GetDifficultyInfo = nil

---@type Frame
MiniMapTrackingBackground = nil

---@class HybridMinimap : Frame
---@field MapCanvas table
---@field CircleMask Texture
HybridMinimap = {}

---@type fun(): string
GetMinimapShape = nil

---@type fun(frame: Frame, mode: string)
UIFrameFlash = nil

---@type fun(file: string, channel?: string): boolean
PlaySoundFile = nil

---@type fun(name: string, context: string): string
Ambiguate = nil

--------------------------------------------------------------------------------
-- 聊天相關框架與函數
--------------------------------------------------------------------------------

---@type fun(frame: Frame): boolean
MouseIsOver = nil

---@type fun(chatType: string, r: number, g: number, b: number)
ChangeChatColor = nil

---@type fun(chatType: string, enable: boolean)
SetChatColorNameByClass = nil

---@type string
CLOSE = nil

---@type fun(event: string, filter: function)
ChatFrame_AddMessageEventFilter = nil

---@type fun(self: Frame, link: string, text: string, button: string)
ChatFrame_OnHyperlinkShow = nil

---@type Button
ChatFrameMenuButton = nil

---@type Button
ChatFrameChannelButton = nil

---@type Button
QuickJoinToastButton = nil

--------------------------------------------------------------------------------
-- 背包相關框架與函數
--------------------------------------------------------------------------------

---@type fun()
CloseAllBags = nil

---@type fun()
CloseBankFrame = nil

---@type fun(button: Button, desaturated: boolean)
SetItemButtonDesaturated = nil

---@type Frame
ContainerFrameCombinedBags = nil

---@type Frame
BankFrame = nil

---@type Frame
AccountBankPanel = nil

--------------------------------------------------------------------------------
-- 法術相關
--------------------------------------------------------------------------------

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

---@class C_Spell
---@field GetSpellCooldown fun(spellID: number): SpellCooldownInfo?
---@field GetSpellInfo fun(spellID: number): SpellInfo?
---@field GetSpellTexture fun(spellID: number): number?
---@field GetSpellName fun(spellID: number): string?
C_Spell = {}

---@type fun(spellID: number): boolean
IsSpellKnown = nil

---@type fun(spellID: number): boolean
IsPlayerSpell = nil

---@type fun(runeIndex: number): number, number, boolean
GetRuneCooldown = nil

---@type fun(): number?
GetSpecialization = nil

--------------------------------------------------------------------------------
-- 戰鬥日誌相關
--------------------------------------------------------------------------------

---@type fun(): ...
CombatLogGetCurrentEventInfo = nil

---@type fun(destFlags: number): boolean
CombatLog_Object_IsA = nil

---@type number
COMBATLOG_OBJECT_TYPE_PLAYER = nil

---@type number
COMBATLOG_OBJECT_AFFILIATION_MINE = nil

---@type number
COMBATLOG_OBJECT_REACTION_HOSTILE = nil

---@type number
COMBATLOG_OBJECT_REACTION_FRIENDLY = nil

--------------------------------------------------------------------------------
-- 光環（Buff/Debuff）相關
--------------------------------------------------------------------------------

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

---@class C_UnitAuras
---@field GetBuffDataByIndex fun(unit: string, index: number, filter?: string): AuraData?
---@field GetDebuffDataByIndex fun(unit: string, index: number, filter?: string): AuraData?
---@field GetAuraDataByIndex fun(unit: string, index: number, filter: string): AuraData?
---@field GetAuraDataByAuraInstanceID fun(unit: string, auraInstanceID: number): AuraData?
C_UnitAuras = {}

--------------------------------------------------------------------------------
-- Missing Globals
--------------------------------------------------------------------------------

---@type fun(cooldown: Frame, start: number, duration: number, enable: number, forceShowDrawEdge?: boolean, modRate?: number)
CooldownFrame_Set = nil

---@class C_NewItems
---@field IsNewItem fun(bagID: number, slotID: number): boolean
---@field RemoveNewItem fun(bagID: number, slotID: number)
C_NewItems = {}

---@type Frame
MerchantFrame = nil
