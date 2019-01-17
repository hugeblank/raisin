local this = {}
this.group = {}
this.thread = {}
this.manager = {}

local groups = {[0] = {threads = {}, priority = 0}}

local assert = function(condition, message, level)
    if not condition then
        error(message, level)
    end
end

this.thread.add = function(func, priority, group)
    assert(type(func) == "function", "Invalid argument #1 (function expected, got "..type(func)..")", 3)
    if not priority then priority = 0 end
    if not group then group = 0 end
    assert(type(group) == "number", "Invalid argument #3 (number expected, got "..type(group)..")", 3)
    assert(groups[group], "Invalid argument #3 (group [ID: "..group.."] does not exist)", 3)
    func = coroutine.create(func)
    groups[group].threads[#groups[group].threads+1] = {coro = func, queue = {}, priority = priority, enabled = true, event = nil}
    return #groups[group].threads
end

this.thread.state = function(thread, group)
    if not group then group = 0 end
    assert(type(thread) == "number", "Invalid argument #1 (number expected, got "..type(thread)..")", 3)
    assert(type(group) == "number", "Invalid argument #2 (number expected, got "..type(group)..")", 3)
    assert(groups[group], "Invalid argument #2 (group [ID: "..group.."] does not exist)", 3)
    assert(groups[group].threads[thread], "Invalid argument #1 (thread [ID: "..thread.."] does not exist)", 3)
    return groups[group].threads[thread].enabled
end

this.thread.toggle = function(thread, group)
    if not group then group = 0 end
    assert(type(thread) == "number", "Invalid argument #1 (number expected, got "..type(thread)..")", 3)
    assert(type(group) == "number", "Invalid argument #2 (number expected, got "..type(group)..")", 3)
    assert(groups[group], "Invalid argument #2 (group [ID: "..group.."] does not exist)", 3)
    assert(groups[group].threads[thread], "Invalid argument #1 (thread [ID: "..thread.."] does not exist)", 3)
    groups[group].threads[thread].enabled = not groups[group].threads[thread].enabled
    return groups[group].threads[thread].enabled
end

this.thread.setPriority = function(thread, priority, group)
    if not group then group = 0 end
    assert(type(thread) == "number", "Invalid argument #1 (number expected, got "..type(thread)..")", 3)
    assert(type(priority) == "number", "Invalid argument #2 (number expected, got "..type(priority)..")", 3)
    assert(type(group) == "number", "Invalid argument #3 (number expected, got "..type(group)..")", 3)
    assert(groups[group], "Invalid argument #3 (group [ID: "..group.."] does not exist)", 3)
    assert(groups[group].threads[thread], "Invalid argument #1 (thread [ID: "..thread.."] does not exist)", 3)
    groups[group].threads[thread].priority = priority
end

this.thread.getPriority = function(thread, group)
    if not group then group = 0 end
    assert(type(thread) == "number", "Invalid argument #1 (number expected, got "..type(thread)..")", 3)
    assert(type(group) == "number", "Invalid argument #2 (number expected, got "..type(group)..")", 3)
    assert(groups[group], "Invalid argument #2 (group [ID: "..group.."] does not exist)", 3)
    assert(groups[group].threads[thread], "Invalid argument #1 (thread [ID: "..thread.."] does not exist)", 3)
    return groups[group].threads[thread].priority
end

this.group.add = function(priority)
    if not priority then
        priority = 1
    end
    assert(priority > 0, "Invalid argument #3 (priority should be greater than 0)")
    groups[#groups+1] = {threads = {}, priority = priority}
    return #groups
end

this.group.toggle = function(group)
    
end

this.group.wrap = function(group)
    assert(type(group) == "number", "Invalid argument #1 (number expected, got "..type(group)..")", 3)
    local threadman = {}
    return nil
end

this.manager.runAll = function()
    while true do
        local e = {os.pullEventRaw()} -- Pull a raw event
        if e[1] == "terminate" then
            printError("Terminated")
            break
        end
        local s_groups = {} -- Sort groups
        s_groups[#s_groups+1] = groups[0]
        for i = 1, #groups do
            for j = 1, #s_groups do
                if groups[i].priority < s_groups[j].priority then
                    table.insert(s_groups, j, groups[i])
                    break
                elseif j == #s_groups then
                    s_groups[#s_groups+1] = groups[i]
                end
            end
        end

        for k = 1, #s_groups do -- For each group
            local threads = s_groups[k].threads
            local s_threads = {} -- Sort the threads
            s_threads[#s_threads+1] = threads[1]
            for i = 2, #threads do
                for j = 1, #s_threads do
                    if threads[i].priority < s_threads[j].priority then
                        table.insert(s_threads, j, threads[i])
                        break
                    elseif j == #s_threads then
                        s_threads[#s_threads+1] = threads[i]
                    end
                end
            end
            -- The actual manager
            for _, thread in pairs(s_threads) do
                if thread.enabled and (thread.event == nil or thread.event == e[1] or e[1] == "terminate") then
                    local event = nil
                    for i = 1, #thread.queue do
                        if event == nil or event == thread.queue[i] then
                            local suc, err = coroutine.resume(thread.coro, unpack(thread.queue[i]))
                            if suc then
                                event = err
                            end
                            assert(suc, err, 3)
                        end
                    end
                    local suc, err = coroutine.resume(thread.coro, unpack(e))
                    if suc then
                        thread.event = err
                    end
                    assert(suc, err, 3)
                elseif not thread.enabled then
                    thread.queue[#thread.queue+1] = e
                end
            end
        end
    end
end
return this
