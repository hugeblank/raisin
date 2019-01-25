local this = {} -- is Raisin, the genius thread manager by hugeblank.
this.group = {} -- of code is my property, but I will let you use it so long as you don't try and redistribute
this.thread = {} -- manager for monetary gain and keep the three lines above, and one below in tact. Add/remove code as you wish, should you decide to freely distribute with additional modifications credit yourself, btw.
this.manager = {} -- can be found on github at `https://github.com/hugeblank/raisin`, and demonstrations of the program can be found here: https://github.com/hugeblank/raisin-demos

local groups = {[0] = {threads = {}, priority = 0, enabled = true}} -- instantiate the groups table, the mother of Raisin. Add the master thread in

local assert = function(condition, message, level) -- Local assert function that has a third parameter so that you can set the level of the error
    if not condition then -- If the condition is not met
        error(message, level) -- Error at the level defined
    end
end

this.thread.add = function(func, priority, group) -- Function for thread adding
    if not priority then priority = 0 end -- If there isn't a priority set it to 0
    if (not group) or 0 > group then group = 0 end -- If there isn't a group value or it's smaller than 0, assume 0
    assert(type(func) == "function", "Invalid argument #1 (function expected, got "..type(func)..")", 3) -- If the first argument wasn't a function
    assert(type(priority) == "number", "Invalid argument #2 (number expected, got "..type(priority)..")", 3) -- If the second argument wasn't a number
    assert(type(group) == "number", "Invalid argument #3 (number expected, got "..type(group)..")", 3) -- If the third argument wasn't a group
    assert(groups[group], "Invalid argument #3 (group [ID: "..group.."] does not exist)", 3) -- If the third argument was a group that doesn't exist
    func = coroutine.create(func) -- Create a coroutine out of the function
    groups[group].threads[#groups[group].threads+1] = {coro = func, queue = {}, priority = priority, enabled = true, event = nil} -- Create the thread object and add it to the group given
    return #groups[group].threads -- Return the thread ID
end

this.thread.state = function(thread, group) -- Function to get the state of a thread
    if (not group) or 0 > group then group = 0 end -- If the group isn't defined assume it's 0
    assert(type(thread) == "number", "Invalid argument #1 (number expected, got "..type(thread)..")", 3) -- If the first argument wasn't a number
    assert(type(group) == "number", "Invalid argument #2 (number expected, got "..type(group)..")", 3) -- If the second argument wasn't a number
    assert(groups[group], "Invalid argument #2 (group [ID: "..group.."] does not exist)", 3) -- If the second argument wasn't a valid group ID
    assert(groups[group].threads[thread], "Invalid argument #1 (thread [ID: "..thread.."] does not exist)", 3) -- If the first argument wasn't a valid thread ID
    return groups[group].threads[thread].enabled -- Return the state of the thread
end

this.thread.toggle = function(thread, group) -- Function to toggle the state of a thread
    if (not group) or 0 > group then group = 0 end -- If the group isn't defined assume it's 0
    assert(type(thread) == "number", "Invalid argument #1 (number expected, got "..type(thread)..")", 3) -- If the first argument wasn't a number
    assert(type(group) == "number", "Invalid argument #2 (number expected, got "..type(group)..")", 3) -- If the second argument wasn't a number
    assert(groups[group], "Invalid argument #2 (group [ID: "..group.."] does not exist)", 3) -- If the second argument wasn't a valid group ID
    assert(groups[group].threads[thread], "Invalid argument #1 (thread [ID: "..thread.."] does not exist)", 3) -- If the first argument wasn't a valid thread ID
    groups[group].threads[thread].enabled = not groups[group].threads[thread].enabled -- swap the state of the thread
    return groups[group].threads[thread].enabled -- Return the state of the thread
end

this.thread.setPriority = function(thread, priority, group) -- Function to set the priority of a thread
    if (not group) or 0 > group then group = 0 end -- If the group isn't defined assume it's 0
    assert(type(thread) == "number", "Invalid argument #1 (number expected, got "..type(thread)..")", 3) -- If the first argument wasn't a number
    assert(type(priority) == "number", "Invalid argument #2 (number expected, got "..type(priority)..")", 3) -- If the second argument wasn't a number
    assert(type(group) == "number", "Invalid argument #3 (number expected, got "..type(group)..")", 3) -- If the third argument wasn't a number
    assert(groups[group], "Invalid argument #2 (group [ID: "..group.."] does not exist)", 3) -- If the second argument wasn't a valid group ID
    assert(groups[group].threads[thread], "Invalid argument #1 (thread [ID: "..thread.."] does not exist)", 3) -- If the first argument wasn't a valid thread ID
    groups[group].threads[thread].priority = priority -- Set the priority of the thread
end

this.thread.getPriority = function(thread, group) -- Function to get the priority of a thread
    if (not group) or 0 > group then group = 0 end -- If the group isn't defined assume it's 0
    assert(type(thread) == "number", "Invalid argument #1 (number expected, got "..type(thread)..")", 3) -- If the first argument wasn't a number
    assert(type(group) == "number", "Invalid argument #2 (number expected, got "..type(group)..")", 3) -- If the second argument wasn't a number
    assert(groups[group], "Invalid argument #2 (group [ID: "..group.."] does not exist)", 3) -- If the second argument wasn't a valid group ID
    assert(groups[group].threads[thread], "Invalid argument #1 (thread [ID: "..thread.."] does not exist)", 3) -- If the first argument wasn't a valid thread ID
    return groups[group].threads[thread].priority -- Return the priority of the thread
end

this.thread.wrap = function(thread, group) -- Function to wrap a thread and get thread functions without having to provide the thread ID
    assert(type(thread) == "number", "Invalid argument #1 (number expected, got "..type(thread)..")", 3) -- If the first argument wasn't a number
    assert(type(group) == "number", "Invalid argument #2 (number expected, got "..type(group)..")", 3) --If the second argument wasn't a number
    assert(groups[group], "Invalid argument #2 (group [ID: "..group.."] does not exist)", 3) -- If the second argument wasn't a valid group ID
    assert(groups[group].threads[thread], "Invalid argument #1 (thread [ID: "..thread.."] does not exist)", 3) -- If the first argument wasn't a valid thread ID
    local wrapper = {} -- Table for inserting wrapped functions
    for k, v in pairs(this.thread) do -- For each function in the thread library
        if k ~= "wrap" and k ~= "add" then -- If the function we're attempting to wrap isn't this one, or the add function
            wrapper[k] = function(priority) -- Create a replicate function
                local stat -- Initialize a status variable
                if k == "setPriority" then -- If the function being wrapped is the 'add' or 'setPriority function'
                    stat = {pcall(v, thread, priority, group)} -- Grab the first argument from the parameter, then slap the group and thread ID on and pcall it all
                else -- OTHERWISE
                    stat = {pcall(v, thread, group)} -- slap the group and thread ID on and pcall it all
                end
                if stat[1] == false then -- If the pcall was unsuccessful
                    error(stat[2]:sub(stat[2]:find(" ")+1, -1), 2) -- Spit out the error, and remove the 'raisin.lua:1##: '
                else -- OTHERWISE
                    table.remove(stat, 1) -- Remove whether it succeeded or not
                    return unpack(stat) -- Return the information given by the function
                end
            end
        end
    end
    return wrapper -- Return the wrapped functions
end

this.group.add = function(priority) -- Function to add a group
    assert(type(priority) == "number", "Invalid argument #1 (number expected, got "..type(priority)..")", 3) -- If the first argument wasn't a number
    assert(priority > 0, "Invalid argument #1 (priority should be greater than 0)") -- If the priority is less than 0
    groups[#groups+1] = {threads = {}, priority = priority, enabled = true} -- Create the group object
    return #groups -- Return the group ID
end

this.group.toggle = function(group) -- Function to toggle the state of an entire group
    assert(type(group) == "number", "Invalid argument #1 (number expected, got "..type(group)..")", 3) -- If the first argument wasn't a number
    assert(groups[group], "Invalid argument #1 (group [ID: "..group.."] does not exist)", 3) -- If the first argument wasn't a valid group ID
    groups[group].enabled = not groups[group].enabled -- Toggle the state of the group
    return groups[group].enabled -- Return the state of the group
end

this.group.state = function(group) -- Function to get the state of an entire group
    assert(type(group) == "number", "Invalid argument #1 (number expected, got "..type(group)..")", 3) -- If the first argument wasn't a number
    assert(groups[group], "Invalid argument #1 (group [ID: "..group.."] does not exist)", 3) -- If the first argument wasn't a valid group ID
    return groups[group].enabled -- Return the state of the group
end

this.group.setPriority = function(priority, group) -- Function to set the priority of an entire group
    assert(type(priority) == "number", "Invalid argument #1 (number expected, got "..type(priority)..")", 3) -- If the first argument wasn't a number
    assert(priority > 0, "Invalid argument #1 (priority should be greater than 0)") -- If the first argument wasn't greater than 0
    assert(type(group) == "number", "Invalid argument #2 (number expected, got "..type(group)..")", 3) -- If the second argument wasn't a number
    assert(groups[group], "Invalid argument #2 (group [ID: "..group.."] does not exist)", 3) -- If the second argument wasn't a valid group ID
    groups[group].priority = priority -- Set the priority of the group
end

this.group.getPriority = function(group) -- Function to get the priority of an entire group
    assert(type(group) == "number", "Invalid argument #1 (number expected, got "..type(group)..")", 3) -- If the first argument wasn't a number
    assert(groups[group], "Invalid argument #1 (group [ID: "..group.."] does not exist)", 3) -- If the first argument wasn't a valid group ID
    return groups[group].priority -- Return the priority of the group
end

this.group.wrap = function(group) -- Function to wrap a group and get thread functions like those in the thread library
    assert(type(group) == "number", "Invalid argument #1 (number expected, got "..type(group)..")", 3) -- If the first argument wasn't a number
    assert(groups[group], "Invalid argument #1 (group [ID: "..group.."] does not exist)", 3) -- If the first argument wasn't a valid group ID
    local wrapper = {} -- Table for inserting wrapped functions
    for k, v in pairs(this.thread) do -- For each function in the thread library
        wrapper[k] = function(...) -- Create a replicate function
            local args = {...} -- Put all the arguments into a table
            local stat -- Initialize a status variable
            if k == "add" or k == "setPriority" or k == "wrap" then -- If the function being wrapped is the 'add', 'setPriority', or 'wrap' function
                stat = {pcall(v, args[1], args[2], group)} -- Grab the first 2 arguments from the parameters, then slap the group ID on and pcall it all
            else -- OTHERWISE
                stat = {pcall(v, args[1], group)} -- Grab the first argument, then slap the group ID on and pcall it all
            end
            if stat[1] == false then -- If the pcall was unsuccessful
                error(stat[2]:sub(stat[2]:find(" ")+1, -1), 2) -- Spit out the error, and remove the 'raisin.lua:1##: '
            else -- OTHERWISE
                table.remove(stat, 1) -- Remove whether it succeeded or not
                return unpack(stat) -- Return the information given by the function
            end
        end
    end
    return wrapper -- Return the wrapped functions
end

this.manager.run = function(dead) -- Function to execute thread management
    if dead ~= nil then -- If dead is something
        assert(type(dead) == "number", "Invalid argument #1 (number expected, got "..type(dead)..")", 3) -- If the first argument wasn't a number
        if dead < 0 then -- If dead is a negative number
            dead = 0 -- Set dead to 0
        end
    else -- OTHERWISE
        dead = 0 -- Set dead to 0
    end
    local cur_dead = 0 -- Set a current value for dead coroutines
    local e = {} -- Event variable
    while true do -- Begin thread managment
        local s_groups = {} -- Create table for groups, sorted by priority
        s_groups[#s_groups+1] = groups[0] -- Add group 0 first
        for i = 1, #groups do -- For each group
            for j = 1, #s_groups do -- Iterate over the sorted groups
                if groups[i].priority < s_groups[j].priority then -- If the priority of the current unsorted group is less than the value of the current sorted group
                    table.insert(s_groups, j, groups[i]) -- Insert it such that it will go before the sorted group in the sorted table
                    break -- Break out of the checking
                elseif j == #s_groups then -- OTHERWISE if this is the last iteration
                    s_groups[#s_groups+1] = groups[i] -- Tack the unsorted group onto the end of the sorted table
                end
            end
        end

        for _, group in pairs(s_groups) do -- For each group
            local threads = group.threads -- Make the current groups threads more accessible
            local s_threads = {} -- Sort threads
            if #threads > 0 then -- If there is at least one thread
                s_threads[#s_threads+1] = threads[1] -- Allocate the first thread to teh sorted table
                for i = 2, #threads do -- For each thread other than that one
                    for j = 1, #s_threads do -- Scan the sorted table
                        if threads[i].priority < s_threads[j].priority then -- If the priority of the current unsorted thread is less than the value of the current sorted thread
                            table.insert(s_threads, j, threads[i]) -- Insert it such that it will go before the sorted thread in the sorted table
                            break -- Break out of checking
                        elseif j == #s_threads then -- OTHERWISE if this is the last iteration
                            s_threads[#s_threads+1] = threads[i] -- Take the unsorted thread onto the end of the sorted table
                        end
                    end
                end
            end
            
            for _, thread in pairs(s_threads) do -- For each sorted thread
                if group.enabled and thread.enabled and coroutine.status(thread.coro) ~= "dead" and (thread.event == nil or thread.event == e[1] or e[1] == "terminate") then -- ok we're putting this on the next line, there's a lot going on here.
                -- If the group is enabled and the thread is enabled, and the thread isn't dead and the target event is either nil, or equal to the event detected, or equal to terminate
                    local event = nil -- Target event
                    while #thread.queue ~= 0 do -- until the queue is empty
                        if event == nil or event == thread.queue[1][1] then -- If the target event is nil or equal to what's in the queue
                            local suc, err = coroutine.resume(thread.coro, unpack(thread.queue[1])) -- Resume the coroutine, and give the event
                            if suc then -- If execution was successful
                                event = err -- The target event is set to the err value
                            end
                            assert(suc, err, 3) -- If the coroutine wasn't successful, error
                        end
                        table.remove(thread.queue, 1) -- Remove the event from the queue
                    end
                    local suc, err = coroutine.resume(thread.coro, unpack(e)) -- Resume the coroutine with the current event
                    if suc then -- If that was successful
                        thread.event = err -- set the event the thread desires next
                    end
                    assert(suc, err, 3) -- If it was unsuccessful throw the error
                elseif not (thread.enabled or coroutine.status(thread.coro) ~= "dead") then -- OTHERWISE if the thread isn't enabled and isn't dead add the event to the thread queue
                    thread.queue[#thread.queue+1] = e
                end
                if coroutine.status(thread.coro) == "dead" and thread.enabled ~= false then -- If the thread is dead and not disabled
                    cur_dead = cur_dead+1 -- Add one to the current dead counter
                    thread.enabled = false -- Diable the thread
                end
            end
        end
        if dead ~= 0 and cur_dead >= dead then -- If dead isn't 0 and the current dead is larger or equal to the target amount
            break -- Get out of the main loop
        end
        e = {os.pullEventRaw()} -- Pull a raw event, package it immediately
    end
end

return this -- Return the API
