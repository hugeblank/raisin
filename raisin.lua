--[[ Raisin by Hugeblank
    This code is my property, but I will let you use it so long as you don't redistribute this manager for
    monetary gain and leave this comment block untouched. Add/remove code as you wish. Should you decide to freely
    distribute with additional modifications, please credit yourself. :)
    
    Raisin can be found on github at:
    `https://github.com/hugeblank/raisin`

    Demonstrations of the library can also be found at:
    `https://github.com/hugeblank/raisin-demos`
]]

local this = {}
this.manager = {} 

local groups = {} -- instantiate the groups table, the mother of Raisin.

local assert = function(condition, message, level) -- Local assert function that has a third parameter so that you can set the level of the error
    if not condition then -- If the condition is not met
        level = level or 0
        error(message, 3+level) -- Error at the level defined or 3 as the default, one level above here
    end
end

local isgroup = function(group)
    if group then
        for i = 1, #groups do
            if group == groups[i].instance then
                return groups[i]
            end
        end
    end
    return false
end

local interface = function(internal)
    return {
        state = function()
            return internal.enabled
        end,
        toggle = function(value)
            internal.enabled = value or not internal.enabled
        end,
        getPriority = function()
            return internal.priority
        end,
        setPriority = function(value)
            assert(type(value) == "number", "Invalid argument #1 (number expected, got "..type(value)..")")
            internal.priority = value
        end,
        remove = function()
                -- Scan groups
                for i = 1, #groups do
                    if groups[i] == internal then
                        table.remove(groups, i)
                        return true
                    end
                end
                -- Scan threads
                for i = 1, #groups do
                    local threads = groups[i].threads
                    for j = 1, #threads do
                        if threads[j] == internal then
                            table.remove(groups[i].threads, j)
                            return true
                        end
                    end
                end
            return false
        end
    }
end

this.group = function(priority)
    priority = priority or 0
    local internal = {threads = {}, priority = priority, enabled = true}
    internal.instance = interface(internal)
    groups[#groups+1] = internal
    return internal.instance
end

this.thread = function(func, priority, group) -- Function for thread adding
    priority = priority or 0
    assert(type(func) == "function", "Invalid argument #1 (function expected, got "..type(func)..")")
    assert(type(priority) == "number", "Invalid argument #2 (number expected, got "..type(priority)..")")
    local temp = isgroup(group)
    assert(temp or group == nil, "Invalid argument #3 (valid group expected, got "..type(group)..")")
    group = temp or groups[1]
    func = coroutine.create(func) -- Create a coroutine out of the function
    local internal = {coro = func, queue = {}, priority = priority, enabled = true, event = nil}
    internal.instance = interface(internal)
    group.threads[#group.threads+1] = internal
    return internal.instance
end

local runInternal = function(listener, groups, dead) -- Function to execute thread management
    assert(type(listener) == "function", "Invalid argument #1 (function expected, got "..type(listener)..")", 1)
    assert(dead == nil or type(dead) == "number", "Invalid argument #1 (number expected, got "..type(dead)..")", 1)
    if not dead or dead < 0 then
        dead = 0
    end
    local function sort(unsorted)
        local sorted = {}
        sorted[#sorted+1] = unsorted[1] -- Add the first item to start sorting
        for i = 2, #unsorted do -- For each item other than that one
            for j = 1, #sorted do -- Iterate over the sorted list
                if unsorted[i].priority < sorted[j].priority then -- If the priority of the current unsorted item is less than the value of the current sorted item
                    table.insert(sorted, j, unsorted[i]) -- Insert it such that it will go before the sorted item in the sorted table
                    break -- Break out of the checking
                elseif j == #sorted then -- OTHERWISE if this is the last iteration
                    sorted[#sorted+1] = unsorted[i] -- Tack the unsorted item onto the end of the sorted table
                end
            end
        end
        return sorted
    end
    local function resume(coro, event)
        local suc, err = coroutine.resume(coro, table.unpack(event))
        assert(suc, err, 1)
        if suc then
            return err    
        end
    end
    local e = {} -- Event variable
    local static, static_dead = {}, 0
    for i = 1, #groups do -- For each group
        for j = 1, #groups[i].threads do
            static[#static+1] = groups[i].threads[j]
        end
    end
    while true do -- Begin thread management
        local s_groups = sort(groups) -- Sort groups by priority
        for i = 1, #s_groups do -- For each group
            local s_threads = sort(s_groups[i].threads) -- Sort threads by priority
            if s_groups[i].enabled then -- If the group is enabled
                for j = 1, #s_threads do -- For each sorted thread
                    local thread = s_threads[j]
                    if thread.enabled and coroutine.status(thread.coro) == "suspended" and (thread.event == nil or thread.event == e[1]) then 
                    -- There's a lot going on here, a newline was a must.
                    -- If the group is enabled and the thread is enabled, and the thread is suspended and the target event is either nil, or equal to the event detected THEN
                        while #thread.queue ~= 0 do -- until the queue is empty
                            if thread.event == nil or thread.event == thread.queue[1][1] then -- If the target event is nil or equal to what's in the queue
                                thread.event = resume(thread.coro, thread.queue[1])
                            end
                            table.remove(thread.queue, 1)
                        end
                        thread.event = resume(thread.coro, e)
                    elseif not thread.enabled then -- OTHERWISE if the thread isn't enabled and isn't dead add the event to the thread queue
                        thread.queue[#thread.queue+1] = e
                    end
                    if coroutine.status(thread.coro) == "dead" then
                        for k = 1, #groups[i].threads do -- Search for the thread to remove
                            if groups[i].threads[k] == thread then
                                for l = 1, #static do
                                    if static[l] == thread then
                                        static_dead = static_dead+1
                                    end
                                end
                                table.remove(groups[i].threads, k)
                                break
                            end
                        end
                    end
                end
            else
                for j = 1, #s_groups[i].threads do
                    local thread = s_groups[i].threads[j]
                    thread.queue[#thread.queue+1] = e
                end
            end
        end
        if static_dead >= dead and dead > 0 then
            break
        end
        e = {listener()} -- Pull a raw event, package it immediately
    end
end

this.manager.runGroup = function(listener, group, dead) -- Function to execute thread management for a single group
    group = isgroup(group)
    assert(group, "Invalid argument #1 (valid group expected)")
    res = runInternal(listener, {group}, dead)
    group.enabled = false
    return res
end

this.manager.run = function(listener, dead) -- Function to execute thread management for all groups
    return runInternal(listener, groups, dead)
end

this.group() -- Add a master group
return this -- Return the API
