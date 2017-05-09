-- Copyright © 2017 coord.cn. All rights reserved.
-- @author      QianYe(coordcn@163.com)
-- @license     MIT license

local _M = {}

-- @brief       execute handlers
-- @param       before          {array[function]}
-- @param       handlers        {array[array(function)]}
-- @param       after           {array[function]}
-- @param       req             {object}        request
-- @param       res             {object}        response
function _M.execute(before, handlers, after, req, res)
        if type(before) == "table" then
                for i = 1, #before do
                        local ret = before[i](req, res)
                        if ret == false then
                                return
                        end
                end
        end

        if type(handlers) == "table" then
                for i = 1, #handlers do
                        local handler = handlers[i]
                        for j = 1, #handler do
                                local ret = handler[j](req, res)
                                if ret == false then
                                        return
                                end
                        end
                end
        end

        if type(after) == "table" then
                for i = 1, #after do
                        local ret = after[i](req, res)
                        if ret == false then
                                return
                        end
                end
        end
end

return _M
