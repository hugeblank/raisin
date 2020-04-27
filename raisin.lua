--[[ Raisin by Hugeblank
    This code is my property, but I will let you use it so long as you don't redistribute this manager for
    monetary gain and leave this comment block untouched. Add/remove code as you wish. Should you decide to freely
    distribute with additional modifications, please credit yourself. :)
    
    Raisin can be found on github at:
    `https://github.com/hugeblank/raisin`

    Demonstrations of the library can also be found at:
    `https://github.com/hugeblank/raisin-demos`
]]

return {
    manager = function(listener)
        local this = {}

        local groups = {} -- instantiate the groups table

        local assert = function(condition, message, level) -- Local assert function that has a third parameter so that you can set the level of the error
            if not condition then -- If the condition is not met
                level = level or 0
                error(message, 3+level) -- Error at the level defined or 3 as the default, one level above here
            end
        end

        assert(type(listener) == "function", "Invalid argument #1 (function expected, got "..type(listener)..")", -1)

        local isgroup = function(group) -- Determine whether the object given is a thread or group
            for i = 1, #groups do
                if group == groups[i].instance then
                    return groups[i]
                end
            end
            return false
        end

        local runInternal = function(groups, dead) -- Function to execute thread management
            assert(dead == nil or type(dead) == "number", "Invalid argument #1 (number expected, got "..type(dead)..")", 1)
            if not dead or dead < 0 then
                dead = 0
            end
            local function sort(unsorted) -- TODO: Not use such a garbage sorting method
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
            local function resume(coro, event) -- Simple coroutine resume wrapper
                local suc, err = coroutine.resume(coro, table.unpack(event, 1, event.n))
                assert(suc, err, 1)
                if suc then
                    return err
                end
            end

            local halt = false -- Enabling halt function access
            this.halt = function(val) if not val then halt = not halt else halt = val and true end end

            local e = {} -- Event variable
            local origin = {}
            local totalDead = 0
            for i = 1, #groups do -- For each group
                for j = 1, #groups[i].threads do
                    origin[#origin+1] = groups[i].threads[j] -- Create a table of threads that originated before execution
                end
            end
            while true do -- Begin thread management
                local s_groups = sort(groups) -- Sort groups by priority
                for i = 1, #s_groups do -- For each group
                    local s_threads = sort(s_groups[i].threads) -- Sort threads by priority
                    if s_groups[i].enabled then -- If the group is enabled
                        for j = 1, #s_threads do -- For each sorted thread
                            local thread = s_threads[j]
                            if thread.enabled and coroutine.status(thread.coro) == "suspended" and (thread.event == nil or thread.event == e[1] or e[1] == "terminate") then
                            -- There's a lot going on here, a newline was a must.
                            -- If the group is enabled and the thread is enabled, and the thread is suspended and the target event is either nil, or equal to the event detected, or equal to terminate
                                while #thread.queue ~= 0 do -- until the queue is empty
                                    if thread.event == nil or thread.event == thread.queue[1][1] then -- If the target event is nil or equal to what's in the queue
                                        thread.event = resume(thread.coro, thread.queue[1]) -- Process the queued event
                                    end
                                    table.remove(thread.queue, 1) -- Remove that event from the queue
                                end
                                thread.event = resume(thread.coro, e) -- Process latest event
                            elseif not thread.enabled then -- OTHERWISE if the thread isn't enabled and isn't dead add the event to the thread queue
                                thread.queue[#thread.queue+1] = e
                            end
                            if coroutine.status(thread.coro) == "dead" then
                                for k = 1, #groups[i].threads do -- Search for the thread to remove
                                    if groups[i].threads[k] == thread then 
                                        for l = 1, #origin do -- Check if this thread was an original one
                                            if groups[i].threads[k] == origin[l] then
                                                table.remove(origin, l)
                                                totalDead = totalDead + 1
                                            end
                                        end
                                        table.remove(groups[i].threads, k)
                                        break
                                    end
                                end
                            end
                        end
                    else -- OTHERWISE
                        for j = 1, #s_groups[i].threads do -- Queue the event to all threads in this group
                            local thread = s_groups[i].threads[j]
                            thread.queue[#thread.queue+1] = e
                        end
                    end
                end
                if (totalDead >= dead and dead > 0) or #origin == 0 or halt then -- Check exit condition
                    this.halt = nil -- Clear access to the halt function
                    break -- Get out of the main loop
                end
                e = table.pack(listener()) -- Pull a raw event, package it immediately
            end
        end

        local interface = function(internal) -- General interface used for both groups and threads
            return {
                state = function() -- Whether the object is processing events/buffering them
                    return internal.enabled
                end,
                toggle = function(value) -- Toggle processing/buffering of events
                    internal.enabled = value or not internal.enabled
                end,
                getPriority = function() -- Get the current priority of the object
                    return internal.priority
                end,
                setPriority = function(value) -- Set the current priority of the object
                    assert(type(value) == "number", "Invalid argument #1 (number expected, got "..type(value)..")")
                    internal.priority = value
                end,
                remove = function() -- Remove the object from execution immediately
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
                    return false -- Object cannot be found
                end
            }
        end

        this.group = function(priority) -- Initialize a group
            priority = priority or 0
            local internal = {threads = {}, priority = priority, enabled = true}
            internal.instance = interface(internal)
            groups[#groups+1] = internal

            internal.instance.run = function(dead) -- Run individual group
                local res = runInternal({internal}, dead)
                return res
            end

            return internal.instance
        end

        this.thread = function(func, priority, group) -- Initialize a thread
            priority = priority or 0
            group = isgroup(group or groups[1].instance)
            assert(type(func) == "function", "Invalid argument #1 (function expected, got "..type(func)..")")
            assert(type(priority) == "number", "Invalid argument #2 (number expected, got "..type(priority)..")")
            assert(group, "Invalid argument #3 (valid group expected)")
            func = coroutine.create(func) -- Create a coroutine out of the function
            local internal = {coro = func, queue = {}, priority = priority, enabled = true, event = nil}
            internal.instance = interface(internal)
            group.threads[#group.threads+1] = internal
            return internal.instance
        end

        this.run = function(dead) -- Function to execute thread management for all groups
            return runInternal(groups, dead)
        end

        this.group() -- Add a master group
        return this -- Return the API

    end
}
