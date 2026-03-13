---@meta
--[[
    Busted test framework & luassert type definitions for EmmyLua
    This file provides type annotations so EmmyLua recognizes busted globals
    and luassert assertion methods used in spec/ tests.
]]

-- Busted test framework globals

---@param name string
---@param fn fun()
function describe(name, fn) end

---@param name string
---@param fn fun()
function it(name, fn) end

---@param fn fun()
function before_each(fn) end

---@param fn fun()
function after_each(fn) end

---@param name string
function pending(name) end

-- luassert extensions on the global `assert`
-- busted replaces the built-in assert() with a callable table that has assertion methods

---@class BustedAssertHasNo
---@field errors fun(fn: fun()): any

---@class BustedAssertAre
---@field same fun(expected: any, actual: any): any
---@field equals fun(expected: any, actual: any): any

---@class BustedAssertAreNot
---@field equal fun(expected: any, actual: any): any
---@field same fun(expected: any, actual: any): any

---@class BustedAssert
---@field equals fun(expected: any, actual: any): any
---@field same fun(expected: any, actual: any): any
---@field near fun(expected: number, actual: number, tolerance: number): any
---@field is_near fun(expected: number, actual: number, tolerance: number): any
---@field is_nil fun(value: any): any
---@field is_not_nil fun(value: any): any
---@field is_true fun(value: any): any
---@field is_false fun(value: any): any
---@field is_boolean fun(value: any): any
---@field is_number fun(value: any): any
---@field is_string fun(value: any): any
---@field is_table fun(value: any): any
---@field is_function fun(value: any): any
---@field truthy fun(value: any): any
---@field is_truthy fun(value: any): any
---@field is_falsy fun(value: any): any
---@field has_no_errors fun(fn: fun()): any
---@field has_no BustedAssertHasNo
---@field are BustedAssertAre
---@field are_not BustedAssertAreNot
---@overload fun(value: any, message?: string): any

---@type BustedAssert
assert = {}
