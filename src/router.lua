local core      = require("miss-core")
local Object    = core.object
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
        node.starHandlersMap = node.starHandlersMap or {}
        local handlers = node.starHandlersMap[method] or {}
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
        node.handlersMap = node.handlersMap or {}
        local handlers = node.handlersMap[method] or {}
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

function Router:constructor(limit)
        self.limit = limit
        self.max = 0
        self.root = {} 
end

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

        local keys = utils.split(path, "/")
        local len = #keys
        if len > self.max then
                self.max = len
        end

        local params = {}
        local flag = false
        for i = 1, len do
                local key = keys[i]
                local byte = string.byte(key, 1)
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
                        node.staticChildren = node.staticChildren or {}
                        node.staticChildren[key] = node.staticChildren[key] or {}
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

local find
find = function(node, method, keys, index, len, results)
end

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

        local keys = utils.split(path, "/")
        local len = #keys
        if self.max < len then
                return
        end

        local handlers = {}
        for i = 1, len do
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
                else
                        if node.starHandlersMap then
                                local starHandlers = node.starHandlersMap[method]
                                if starHandlers then
                                        table.insert(handlers, starHandlers)
                                end
                        end
                end

                node = temp
        end
end

return Router
