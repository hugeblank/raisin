# Raisin | Threads made easy
Raisin is a priority based coroutine manager with a few additional twists. Its name in its prototyping stage was originally 'ryzen', the joke being that it was a 'threadripper'. Obviously that name is a poor choice, so something similar was decided upon.

As is evident Raisin is designed for lua's coroutines to allow for many freedoms, such as manual prioritization, grouping, toggling, and a manual coroutine death termination amount. 

# Installation

Currently the only installation method is directly downloading the file/repo:

```wget https://raw.githubusercontent.com/hugeblank/raisin/master/raisin.lua```

Depending on how well recieved this is (as if XP) I may make it a luarocks package.

# Examples
Examples are offered at [this](https://github.com/hugeblank/raisin-demos) repository. If you have further demonstrations, or a better example of what is already provided please make a pull request, contribution is welcome!

# API Usage
A brief overview of the functionality of Raisin, for reference.

## `thread`: 

`add`: Creates a new thread using the master group
- **Parameters**
  - _function_: subject to multithread
  - _number_: execution priority
  - _[number]_: group ID | default: 0 (master)
- **Returns**
  - _number_: thread ID
  
`state`: Gets the current state of a thread
- **Parameters**
  - _number_: thread ID
  - _[number]_: group ID | default: 0 (master)
- **Returns**
  - _boolean_: execution state (false if the thread is disabled)
  
`toggle`: Toggle the state of a thread
- **Parameters**
  - _number_: thread ID
  - _[number]_: group ID | default: 0 (master)
- **Returns**
  - _boolean_: execution state
  
`setPriority`: Sets the current priority of the thread (order of execution)
- **Parameters**
  - _number_: thread ID
  - _number_: execution priority
  - _[number]_: group ID | default: 0 (master)
- **Returns**
  - _none_

`getPriority`: Gets the current priority of the thread 
- **Parameters**
  - _number_: thread ID
  - _[number]_: group ID | default: 0 (master)
- **Returns**
  - _number_: execution priority

## `group`:

`add`: Creates a new thread grouping container
- **Parameters**
  - _number_: execution priority
- **Returns**
  - _number_: group ID
  
`toggle`: Toggle the state of an entire group
- **Parameters**
  - _number_: group ID
- **Returns**
  - _boolean_: execution state

`state`: Gets the current state of a group
- **Parameters**
  - _number_: group ID
- **Returns**
  - _boolean_: execution state
  
`setPriority`: Sets the current priority of a group
- **Parameters**
  - _number_: execution priority
  - _number_: group ID
- **Returns**
  - _none_
  
`getPriority`: Gets the current priority of a group
- **Parameters**
  - _number_: group ID
- **Returns**
  - _number_: execution priority

`wrap`: Wraps an entire group so that thread based functions can easily be performed
- **Parameters**
  - _number_: group ID
- **Returns**
  - _table_: functions to perform per thread actions

## `manager`: 

`run`: Invokes execution of all threads and groups
- **Parameters**
  - _[number]_: amount of coroutines to die before execution is halted | default: 0 (ignore dead)
- **Returns**
  - _none_
