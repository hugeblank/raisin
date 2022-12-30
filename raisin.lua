--[[ Raisin by Hugeblank
    This code is my property, but I will let you use it so long as you don't redistribute this manager for
    monetary gain and leave this comment block untouched. Add/remove code as you wish. Should you decide to freely
    distribute with additional modifications, please credit yourself. :)

    Raisin can be found on github at:
    `https://github.com/hugeblank/raisin`

    Demonstrations of the library can also be found at:
    `https://github.com/hugeblank/raisin-demos`
]]

local function copy(t)
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            out[k] = copy(v)
        else
            out[k] = v
        end
    end
    return out
end

local function manager(listener)
    local this = {} -- Thread/group creation and runner

    local threads = {}

    local assert = function(condition, message, level) -- Local assert function that has a third parameter so that you can set the level of the error
        if not condition then -- If the condition is not met
            level = level or 0
            error(message, 3+level) -- Error at the level defined or 3 as the default, one level above here
        end
    end

    assert(type(listener) == "function", "Invalid argument #1 (function expected, got "..type(listener)..")", -2)

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

    local function resume(thread, event) -- Simple coroutine resume wrapper
        local suc, err = coroutine.resume(thread.coro, table.unpack(event, 1, event.n))
        assert(suc, err, 2)
        if suc then
            return err
        end
    end

    local function check(thread, name)
        return thread.enabled and coroutine.status(thread.coro) == "suspended" and (thread.event == nil or thread.event == name)
        -- If the thread is enabled, and the thread is suspended and there either isn't a target event, or it's equal to the event detected
    end

    this.run = function(onDeath) -- Function to execute thread managment
        assert(type(onDeath) == "function", "Invalid argument #1 (function expected, got "..type(onDeath)..")")

        local halt = false
        local e = {} -- Event variable
        local initial = {} -- Existing thread instances before manager started, for onDeath
        for i = 1, #threads do
            initial[i] = threads[i].instance
        end

        while true do -- Begin thread management
            local s_threads = sort(threads) -- Sort threads by priority
            local total = #s_threads
            for j = 1, total do -- For each sorted thread
                local thread = s_threads[j]
                while #thread.queue ~= 0 do -- until the queue is empty
                    if check(thread, thread.queue[1][1]) then
                        thread.event = resume(thread, thread.queue[1]) -- Process the queued event
                    end
                    table.remove(thread.queue, 1) -- Remove that event from the queue
                end
                if check(thread, e[1]) then
                    thread.event = resume(thread, e) -- Process latest event
                elseif not thread.enabled then
                    -- OTHERWISE if the thread isn't enabled and the event type is allowed to be cached, add the event to the thread queue
                    if thread.filter and thread.filter[(e[1])] then
                        -- If there's a queue filter, and the event is in the filter then queue it
                        thread.queue[#thread.queue+1] = e
                    elseif not thread.filter then
                        -- If there isn't a thread filter then just queue it (backwards compat)
                        thread.queue[#thread.queue+1] = e
                    end
                end
                if coroutine.status(thread.coro) == "dead" then
                    local living = {} -- All living thread instances
                    for k = 1, #threads do -- Search for the thread to remove
                        if threads[k] == thread then
                            table.remove(threads, k)
                            j = j-1
                            break
                        end
                    end
                    for i = 1, #threads do
                        living[i] = threads[i].instance
                    end
                    local err
                    err, halt = pcall(onDeath, thread.instance, living, initial) -- Trigger user defined onDeath function to determine whether to halt execution
                    assert(err, halt, 1) -- If the onDeath function errors announce that
                    if halt then return end
                end
                total = #s_threads
            end
            e = table.pack(listener()) -- Pull a raw event, package it immediately
        end
    end

    local interface = function(coro, priority, filter) -- General interface used for both groups and threads
        priority = priority or 0
        filter = filter or {}
        if type(filter) == "string" then
            filter = {[filter] = true}
        end
        assert(type(priority) == "number", "Invalid argument #2 (number expected, got "..type(priority)..")", 1)
        assert(type(filter) == "table", "Invalid argument #3 (table or string expected, got "..type(filter)..")", 1)
        if #filter == 0 then
            filter = nil
        else
            filter = copy(filter)
            for i = 1, #filter do
                filter[(filter[i])] = true
                filter[i] = nil
            end
        end
        local internal = {
            coro = coro,
            queue = {},
            filter = filter,
            priority = priority,
            enabled = true,
            event = nil
        }
        internal.instance = {
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
            remove = function() -- Remove the object from execution
                    for i = 1, #threads do
                        if threads[i] == internal then
                            table.remove(threads, i)
                            return true
                        end
                    end
                return false -- Object cannot be found
            end
        }
        threads[#threads+1] = internal
        return internal.instance
    end

    this.thread = function(func, ...) -- Initialize a thread
        assert(type(func) == "function", "Invalid argument #1 (function expected, got "..type(func)..")")
        return interface(coroutine.create(func), ...)
    end

    this.group = function(onDeath, ...) -- Initialize a group
        assert(type(onDeath) == "function", "Invalid argument #1 (function expected, got "..type(onDeath)..")")
        local subman = manager(listener)
        local ii = interface(coroutine.create(function() subman.run(onDeath) end), ...)
        ii.run = subman.run
        ii.thread = subman.thread
        ii.group = subman.group
        return ii
    end

    this.onDeath = {-- Template thread/group death handlers
        waitForAll = function() -- Wait for all threads regardless of when added to die
            return function(_, all)
                return #all == 0
            end
        end,
        waitForN = function(n) -- Wait for n threads regardless of when added to die
            assert(type(n) == "number", "Invalid argument #1 (number expected, got "..type(n)..")")
            local amt = 0
            return function()
                amt = amt+1
                return amt >= n
            end
        end,
        waitForAllInitial = function() -- Wait for all threads created before runtime to die
            return function(dead, _, init)
                for i = 1, #init do
                    if init[i] == dead then
                        table.remove(init, i)
                    end
                end
                return #init == 0
            end
        end,
        waitForNInitial = function(n) -- Wait for n threads created before runtime to die
            assert(type(n) == "number", "Invalid argument #1 (number expected, got "..type(n)..")")
            local amt = 0
            return function(dead, _, init)
                for i = 1, #init do
                    if init[i] == dead then
                        amt = amt+1
                    end
                end
                return amt >= n
            end
        end,
        -- The following "waitForXRuntime" functions assume that runtime threads were created before any initial thread died
        waitForAllRuntime = function() -- Wait for all threads created during runtime to die
            return function(dead, all, init)
                for i = 1, #init do
                    if init[i] == dead then
                        return false
                    end
                    for j = 1, #all do
                        if all[j] == init[i] then
                            table.remove(all, j)
                        end
                    end
                end
                return #all == 0
            end
        end,
        waitForNRuntime = function(n) -- Wait for n threads created during runtime to die
            assert(type(n) == "number", "Invalid argument #1 (number expected, got "..type(n)..")")
            local amt = 0
            return function(dead, all, init)
                for i = 1, #init do
                    if init[i] == dead then
                        return false
                    end
                    for j = 1, #all do
                        if all[j] == init[i] then
                            table.remove(all, j)
                        end
                    end
                end
                amt = amt+1
                return n >= amt
            end
        end
    }

    return this -- Return the API

end

return {
    manager = manager
}
