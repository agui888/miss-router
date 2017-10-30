-- Copyright © 2017 coord.cn. All rights reserved.
-- @author      QianYe(coordcn@163.com)
-- @license     MIT license

local core      = require("miss-core")
local Object    = core.Object
local utils     = core.utils

local STAR      = 42
local SLASH     = 47
local COLON     = 58

local METHODS = {
    "GET",
    "POST",
    "PUT",
    "DELETE",
    "PATCH",
    "OPTIONS",
    "HEAD",
    "TRACE",
    "CONNECT",
}

local function add_star_handler(node, method, handler)
    node.starHandlersMap    = node.starHandlersMap or {}
    local handlers          = node.starHandlersMap[method] or {}
    table.insert(handlers, handler)
    node.starHandlersMap[method] = handlers
end

local function addStarHandler(node, method, handler)
    if method == "ANY" then
        for i = 1, #METHODS do
            add_star_handler(node, METHODS[i], handler)
        end
    else
        add_star_handler(node, method, handler)
    end
end

local function add_handler(node, method, handler)
    node.handlersMap    = node.handlersMap or {}
    local handlers      = node.handlersMap[method] or {}
    table.insert(handlers, handler)
    node.handlersMap[method] = handlers
end

local function addHandler(node, method, handler)
    if method == "ANY" then
        for i = 1, #METHODS do
            add_handler(node, METHODS[i], handler)
        end
    else
        add_handler(node, method, handler)
    end
end



local Router = Object:extend()

-- /logs/name/:org/members/:user
-- /logs/name/:org/*
-- /logs/*
-- /static/test/test.html
-- /
-- /*
-- /favico.ico
-- {
--      handlersMap     = {}, 
--      starHandlersMap = {},
--      staticChildren  = {},
--      paramsChildren  = {},
--      params          = {},
-- }

local DEFAULT_MAX_PATH_LENGTH = 512

-- @param   limit   {number} input path length limit
function Router:constructor(limit)
    self.limit = limit or DEFAULT_MAX_PATH_LENGTH
    self.max = 0
    self.root = {} 
end

-- @brief   add new router path and handler
-- @param   method  {string}        GET POST
-- @param   path    {string}        static first, if match static path params path will be ignored
--          /                       root
--          /logs/user/name/test    static
--          /logs/:user/:name/test  params
--          /logs/*                 group
-- @param   handler {function}      if the handler return false, stop execute handler chain
--          function(request, response)
--          end
function Router:add(method, path, handler)
    if type(method) ~= "string" then
        error("method must be string")
    end

    if type(path) ~= "string" then
        error("path must be string")
    end

    if type(handler) ~= "function" then
        error("handler must be function")
    end

    local firstChar = string.byte(path, 1)
    if firstChar ~= SLASH then
        error("first char must be /")
    end

    local node = self.root
    if path == "/" then
        addHandler(node, method, handler)
        return
    end

    local keys  = utils.split(path, "/")
    local len   = #keys
    if len > self.max then
        self.max = len
    end

    local params = {}
    local flag = false
    for i = 1, len do
        local key   = keys[i]
        local byte  = string.byte(key, 1)
        if byte == STAR then
            addStarHandler(node, method, handler)
            return
        elseif byte == COLON then
            flag = true
            local name = string.sub(key, 2)
            params[name] = i

            node.paramsChildren = node.paramsChildren or {}
            node = node.paramsChildren
            if i == len then
                addHandler(node, method, handler)
                if flag then
                    node.params = params
                end
            end
        else
            node.staticChildren         = node.staticChildren or {}
            node.staticChildren[key]    = node.staticChildren[key] or {}
            node = node.staticChildren[key]
            if i == len then
                addHandler(node, method, handler)
                if flag then
                    node.params = params
                end
            end
        end
    end
end

-- @param   method  {string}    GET POST
-- @param   path    {string}    static first, if match static path params path will be ignored
function Router:find(method, path)
    local node = self.root
    if path == "/" then
        if not node.handlersMap then
            return
        end
                
        local handlers = node.handlersMap[method]
        if not handlers then
            return
        end
        
        return { handlers }
    end

    if #path > self.limit then
        return
    end

    local keys  = utils.split(path, "/")
    local len   = #keys
    if self.max < len then
        return
    end

    local handlers = {}
    for i = 1, len do
        if node.starHandlersMap then
            local starHandlers = node.starHandlersMap[method]
            if starHandlers then
                table.insert(handlers, starHandlers)
            end
        end

        local key = keys[i]
        local temp
        if node.staticChildren then
            temp = node.staticChildren[key]
            if not temp then
                temp = node.paramsChildren
            end
        else
            temp = node.paramsChildren
        end

        if not temp then 
            return
        end

        if i == len then
            if not temp.handlersMap then
                return
            end
                    
            local func = temp.handlersMap[method]
            if not func then
                return
            end
                            
            table.insert(handlers, func)
            local params = temp.params
            if params then
                local ret = {}
                for key, i in pairs(params) do
                    ret[key] = keys[i]
                end

                return handlers, ret
            else
                return handlers
            end
        end

        node = temp
    end
end

return Router
