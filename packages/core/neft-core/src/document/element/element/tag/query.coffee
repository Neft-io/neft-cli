'use strict'

utils = require '../../../../util'
{SignalsEmitter} = require '../../../../signal'
eventLoop = require '../../../../event-loop'
assert = require '../../../../assert'

Tag = Text = null

DEFAULT_PRIORITY = 0
ELEMENTS_PRIORITY = 1
ATTRS_PRIORITY = 100

test = (node, funcs, index, targetFunc, targetCtx, single) ->
    while index < funcs.length
        func = funcs[index]

        if func.isIterator
            return func node, funcs, index + 3, targetFunc, targetCtx, single
        else
            data1 = funcs[index + 1]
            data2 = funcs[index + 2]
            unless func(node, data1, data2)
                return false

        index += 3

    targetFunc.call targetCtx, node
    true

anyDescendant = (node, funcs, index, targetFunc, targetCtx, single) ->
    for child in node.children
        if not (child instanceof Tag) or child.name isnt 'blank'
            if test(child, funcs, index, targetFunc, targetCtx, single)
                if single
                    return true

        if child instanceof Tag
            if anyDescendant(child, funcs, index, targetFunc, targetCtx, single)
                if single
                    return true
    false
anyDescendant.isIterator = true
anyDescendant.priority = DEFAULT_PRIORITY
anyDescendant.toString = -> 'anyDescendant'

directParent = (node, funcs, index, targetFunc, targetCtx, single) ->
    if parent = node._parent
        if test(parent, funcs, index, targetFunc, targetCtx, single)
            return true
        if parent.name is 'blank'
            return directParent parent, funcs, index, targetFunc, targetCtx, single
    false
directParent.isIterator = true
directParent.priority = DEFAULT_PRIORITY
directParent.toString = -> 'directParent'

anyChild = (node, funcs, index, targetFunc, targetCtx, single) ->
    for child in node.children
        if child instanceof Tag and child.name is 'blank'
            if anyChild(child, funcs, index, targetFunc, targetCtx, single)
                if single
                    return true
        else
            if test(child, funcs, index, targetFunc, targetCtx, single)
                if single
                    return true
    false
anyChild.isIterator = true
anyChild.priority = DEFAULT_PRIORITY
anyChild.toString = -> 'anyChild'

anyParent = (node, funcs, index, targetFunc, targetCtx, single) ->
    if parent = node._parent
        if test(parent, funcs, index, targetFunc, targetCtx, single)
            return true
        else
            return anyParent(parent, funcs, index, targetFunc, targetCtx, single)
    false
anyParent.isIterator = true
anyParent.priority = DEFAULT_PRIORITY
anyParent.toString = -> 'anyParent'

byName = (node, data1) ->
    if node instanceof Tag
        node.name is data1
    else if data1 is '#text' and node instanceof Text
        true
byName.isIterator = false
byName.priority = ELEMENTS_PRIORITY
byName.toString = -> 'byName'

byInstance = (node, data1) ->
    node instanceof data1
byInstance.isIterator = false
byInstance.priority = DEFAULT_PRIORITY
byInstance.toString = -> 'byInstance'

byTag = (node, data1) ->
    node is data1
byTag.isIterator = false
byTag.priority = DEFAULT_PRIORITY
byTag.toString = -> 'byTag'

byProp = (node, data1) ->
    if node instanceof Tag
        node.props[data1] isnt undefined
    else
        false
byProp.isIterator = false
byProp.priority = ATTRS_PRIORITY
byProp.toString = -> 'byProp'

byPropValue = (node, data1, data2) ->
    if node instanceof Tag
        `node.props[data1] == data2`
    else
        false
byPropValue.isIterator = false
byPropValue.priority = ATTRS_PRIORITY
byPropValue.toString = -> 'byPropValue'

byPropStartsWithValue = (node, data1, data2) ->
    if node instanceof Tag
        prop = node.props[data1]
        if typeof prop is 'string'
            return prop.indexOf(data2) is 0
    false
byPropStartsWithValue.isIterator = false
byPropStartsWithValue.priority = ATTRS_PRIORITY
byPropStartsWithValue.toString = -> 'byPropStartsWithValue'

byPropEndsWithValue = (node, data1, data2) ->
    if node instanceof Tag
        prop = node.props[data1]
        if typeof prop is 'string'
            return prop.indexOf(data2, prop.length - data2.length) > -1
    false
byPropEndsWithValue.isIterator = false
byPropEndsWithValue.priority = ATTRS_PRIORITY
byPropEndsWithValue.toString = -> 'byPropEndsWithValue'

byPropContainsValue = (node, data1, data2) ->
    if node instanceof Tag
        prop = node.props[data1]
        if typeof prop is 'string'
            return prop.indexOf(data2) > -1
    false
byPropContainsValue.isIterator = false
byPropContainsValue.priority = ATTRS_PRIORITY
byPropContainsValue.toString = -> 'byPropContainsValue'

byPropTestsValue = (node, data1, data2) ->
    if node instanceof Tag
        prop = node.props[data1]
        if typeof prop is 'string'
            return data2.test(prop)
    false
byPropTestsValue.isIterator = false
byPropTestsValue.priority = ATTRS_PRIORITY
byPropTestsValue.toString = -> 'byPropTestsValue'

TYPE = /^#?[a-zA-Z0-9|\-:_]+/
DEEP = /^([ ]*)>([ ]*)|^([ ]+)/
ATTR_SEARCH = /^\[([^\]]+?)\]/
ATTR_VALUE_SEARCH = /^\[([^=]+?)=([^\]]+?)\]/
ATTR_CLASS_SEARCH = /^\.([a-zA-Z0-9|\-_]+)/

STARTS_WITH = /\^$/
ENDS_WITH = /\$$/
CONTAINS = /\*$/
TRIM_ATTR_VALUE = /(?:'|")?([^'"]*)/

ATTR_VALUES =
    __proto__: null
    'true': true
    'false': false
    'null': null
    'undefined': undefined

i = 0
OPTS_QUERY_BY_PARENTS = 1<<(i++)
OPTS_REVERSED = 1<<(i++)
OPTS_ADD_ANCHOR = 1<<(i++)

MAX_QUERIES_CACHE_LENGTH = 2000
QUERIES_CACHE_OVERFLOW_REDUCTION = 100
queriesCache = []
queriesCacheLengths = []
getQueries = (selector, opts=0) ->
    reversed = !!(opts & OPTS_REVERSED)

    # get from the cache
    if r = queriesCache[opts]?[selector]
        return r

    distantTagFunc = if reversed then anyParent else anyDescendant
    closeTagFunc = if reversed then directParent else anyChild
    arrFunc = if reversed then 'unshift' else 'push'
    reversedArrFunc = if reversed then 'push' else 'unshift'

    funcs = []
    queries = [funcs]
    sel = selector.trim()
    while sel.length
        if sel[0] is '*'
            sel = sel.slice 1
            funcs[arrFunc] byInstance, Tag, null
        else if sel[0] is '&'
            sel = sel.slice 1
            unless opts & OPTS_QUERY_BY_PARENTS
                funcs[arrFunc] byTag, null, null
        else if exec = TYPE.exec(sel)
            sel = sel.slice exec[0].length
            name = exec[0]
            funcs[arrFunc] byName, name, null
        else if exec = ATTR_VALUE_SEARCH.exec(sel)
            sel = sel.slice exec[0].length
            [_, name, val] = exec
            if val of ATTR_VALUES
                val = ATTR_VALUES[val]
            else
                val = TRIM_ATTR_VALUE.exec(val)[1]

            if STARTS_WITH.test(name)
                func = byPropStartsWithValue
            else if ENDS_WITH.test(name)
                func = byPropEndsWithValue
            else if CONTAINS.test(name)
                func = byPropContainsValue
            else
                func = byPropValue

            if func isnt byPropValue
                name = name.slice 0, -1

            funcs[arrFunc] func, name, val
        else if exec = ATTR_SEARCH.exec(sel)
            sel = sel.slice exec[0].length
            funcs[arrFunc] byProp, exec[1], null
        else if exec = ATTR_CLASS_SEARCH.exec(sel)
            sel = sel.slice exec[0].length
            funcs[arrFunc] byPropTestsValue, 'class', new RegExp("(?:^| )#{exec[1]}(?:$| )")
        else if exec = DEEP.exec(sel)
            sel = sel.slice exec[0].length
            deep = exec[0].trim()
            if deep is ''
                funcs[arrFunc] distantTagFunc, null, null
            else if deep is '>'
                funcs[arrFunc] closeTagFunc, null, null
        else if sel[0] is ','
            funcs = []
            queries.push funcs
            sel = sel.slice 1
            sel = sel.trim()
        else
            throw new Error "queryAll: unexpected selector '#{sel}' in '#{selector}'"

    # set iterator
    for funcs in queries
        firstFunc = if reversed and not (opts & OPTS_QUERY_BY_PARENTS)
            funcs[funcs.length-3]
        else
            funcs[0]
        if firstFunc is byTag
            continue

        if opts & OPTS_QUERY_BY_PARENTS and not firstFunc?.isIterator
            funcs[arrFunc] distantTagFunc, null, null
        else if reversed and not firstFunc?.isIterator
            funcs[reversedArrFunc] distantTagFunc, null, null
        else if not reversed and not firstFunc?.isIterator
            funcs[reversedArrFunc] distantTagFunc, null, null

        if opts & OPTS_ADD_ANCHOR
            funcs[reversedArrFunc] byTag, null, null

    # save to the cache
    unless cache = queriesCache[opts]
        cache = queriesCache[opts] = {}
        queriesCacheLengths[opts] = 0
    cache[selector] = queries

    # clean cache if needed
    if (queriesCacheLengths[opts] += 1) > MAX_QUERIES_CACHE_LENGTH
        removed = 0
        for key of cache
            delete cache[key]
            removed += 1
            if removed >= QUERIES_CACHE_OVERFLOW_REDUCTION
                break
        queriesCacheLengths[opts] -= removed

    queries

class Watcher extends SignalsEmitter
    NOP = ->

    lastUid = 0
    pool = []

    @create = (node, queries, watchElements) ->
        if pool.length
            watcher = pool.pop()
            watcher.node = node
            watcher.queries = queries
            watcher.watchElements = watchElements
            watcher.forceUpdate = true
        else
            watcher = new Watcher node, queries, watchElements

        nodeWatchers = node._watchers ?= []
        nodeWatchers.push watcher

        watcher

    constructor: (node, queries, watchElements) ->
        super()
        @forceUpdate = true
        @node = node
        @queries = queries
        @watchElements = watchElements
        @uid = (lastUid++) + ''
        @nodes = []
        @nodesToAdd = []
        @nodesToRemove = []
        @nodesWillChange = false
        Object.seal @

    SignalsEmitter.createSignal @, 'onAdd'
    SignalsEmitter.createSignal @, 'onRemove'

    test: (tag) ->
        for funcs in @queries
            funcs[funcs.length - 2] = @node # set byTag anchor data1
            if test(tag, funcs, 0, NOP, null, true)
                return true
        false

    disconnect: ->
        assert.ok @node
        {uid, node, nodes, nodesToAdd, nodesToRemove} = @

        utils.remove node._watchers, @

        while node = nodesToAdd.pop()
            delete node._inWatchers[uid]

        while node = nodesToRemove.pop()
            @emit 'onRemove', node

        while node = nodes.pop()
            delete node._inWatchers[uid]
            @emit 'onRemove', node

        @onAdd.disconnectAll()
        @onRemove.disconnectAll()

        @node = @queries = null
        pool.push @
        return

module.exports = (Element, _Tag) ->
    Tag = _Tag
    Text = Element.Text

    getSelectorCommandsLength: module.exports.getSelectorCommandsLength

    queryAll: queryAll = (selector, target = [], targetCtx = target, opts = 0) ->
        assert.isString selector
        assert.notLengthOf selector, 0
        unless typeof target is 'function'
            assert.isArray target

        queries = getQueries selector, opts
        func = if Array.isArray(target) then target.push else target

        for funcs in queries
            funcs[0] @, funcs, 3, func, targetCtx, false

        if Array.isArray(target)
            target

    queryAllParents: (selector, target = [], targetCtx = target) ->
        unless typeof target is 'function'
            assert.isArray target
        func = if Array.isArray(target) then target.push else target
        opts = OPTS_REVERSED | OPTS_QUERY_BY_PARENTS

        onNode = (node) ->
            func.call targetCtx, node
            queryAll.call node, selector, onNode, null, opts
            return

        queryAll.call @, selector, onNode, null, opts

        if Array.isArray(target)
            target

    query: query = do ->
        result = null
        resultFunc = (arg) ->
            result = arg

        (selector, opts = 0) ->
            assert.isString selector
            assert.notLengthOf selector, 0

            queries = getQueries selector, opts
            for funcs in queries
                if funcs[0](@, funcs, 3, resultFunc, null, true)
                    return result

            null

    queryParents: (selector) ->
        query.call @, selector, OPTS_REVERSED | OPTS_QUERY_BY_PARENTS

    watch: (selector, watchElements) ->
        assert.isString selector
        assert.notLengthOf selector, 0
        assert.isArray watchElements if watchElements?

        queries = getQueries selector, OPTS_REVERSED | OPTS_ADD_ANCHOR
        watcher = Watcher.create @, queries, watchElements
        checkWatchersDeeply @
        watcher

    checkWatchersDeeply: checkWatchersDeeply = do ->
        pending = false
        masterNodes = []
        watchersToUpdate = []
        updateWatchersQueue = []

        i = 0
        CHECK_WATCHERS_THIS = 1 << i++
        CHECK_WATCHERS_CHILDREN = 1 << i++
        CHECK_WATCHERS_IS_MASTER_NODE = 1 << i++

        invalidateWatcher = (watcher) ->
            unless watcher.nodesWillChange
                watchersToUpdate.push watcher
                watcher.nodesWillChange = true
            return

        isChildOf = (child, parent) ->
            tmp = child
            while tmp = tmp._parent
                if tmp is parent
                    return true
            false

        testNode = (node, watcher) ->
            inWatchers = node._inWatchers
            watcherUid = watcher.uid
            if (not inWatchers or not inWatchers[watcherUid]) and watcher.test(node)
                # add in node
                unless inWatchers
                    inWatchers = node._inWatchers = {}
                inWatchers[watcherUid] = true

                # add in watcher
                watcher.nodesToAdd.push node
                invalidateWatcher watcher
            else if inWatchers and inWatchers[watcherUid] and not watcher.test(node)
                # remove from node
                delete inWatchers[watcherUid]

                # remove from watcher
                utils.removeFromUnorderedArray watcher.nodes, node
                watcher.nodesToRemove.push node
                invalidateWatcher watcher
            return

        checkNodeRec = (node, watchersQueue, flags, hasForcedWatcher) ->
            checkWatchers = node._checkWatchers
            flags |= checkWatchers
            addedWatchersToQueue = 0

            # add node watchers to the queue
            if watchers = node._watchers
                for watcher in watchers
                    # only global watchers are saved into watchersQueue
                    unless watcher.watchElements
                        watchersQueue.push watcher
                        addedWatchersToQueue += 1

                        # mark as forced watcher
                        if not hasForcedWatcher and watcher.forceUpdate
                            hasForcedWatcher = true

                    # remove abandoned watcher nodes
                    watcherNode = watcher.node
                    nodes = watcher.nodes
                    i = n = nodes.length
                    while i-- > 0
                        childNode = nodes[i]
                        if childNode isnt watcherNode and not isChildOf(childNode, watcherNode)
                            # remove from node
                            delete childNode._inWatchers[watcher.uid]

                            # remove from watcher
                            nodes[i] = nodes[n - 1]
                            nodes.pop()
                            watcher.nodesToRemove.push childNode
                            invalidateWatcher watcher
                            n--

                    if watcher.watchElements
                        # for watcher with watchElement we're going to test
                        # all elements in any of them changed
                        anyElementChange = watcher.forceUpdate
                        unless anyElementChange
                            for element in watcher.watchElements
                                if element._checkWatchers & CHECK_WATCHERS_THIS
                                    anyElementChange = true
                                    break
                        if anyElementChange
                            for element in watcher.watchElements
                                testNode element, watcher
                            watcher.forceUpdate = false

            # test this node
            if hasForcedWatcher or flags & CHECK_WATCHERS_THIS
                for watcher in watchersQueue
                    if hasForcedWatcher and not watcher.forceUpdate and not (flags & CHECK_WATCHERS_THIS)
                        continue
                    testNode node, watcher

            # check recursively
            if flags & CHECK_WATCHERS_CHILDREN and node instanceof Tag
                for childNode in node.children
                    if hasForcedWatcher or flags & CHECK_WATCHERS_THIS or childNode._checkWatchers > 0
                        checkNodeRec childNode, watchersQueue, flags, hasForcedWatcher

            # remove added watchers from the queue
            if watchers
                for i in [0...addedWatchersToQueue] by 1
                    watcher = watchersQueue.pop()
                    if watcher.forceUpdate
                        watcher.forceUpdate = false

            # clear node
            node._checkWatchers = 0
            return

        updateWatchers = ->
            pending = false

            # by master nodes
            while masterNode = masterNodes.pop()
                unless masterNode._parent
                    checkNodeRec masterNode, updateWatchersQueue, 0, false

            # emit signals
            while watcher = watchersToUpdate.pop()
                {nodesToAdd, nodesToRemove} = watcher
                while node = nodesToRemove.pop()
                    watcher.emit 'onRemove', node
                while node = nodesToAdd.pop()
                    watcher.nodes.push node
                    watcher.emit 'onAdd', node
                watcher.nodesWillChange = false
            return

        (node, parent = node._parent) ->
            # mark this node
            checkWatchers = node._checkWatchers
            unless checkWatchers & CHECK_WATCHERS_THIS
                checkWatchers |= CHECK_WATCHERS_THIS
                if node instanceof Tag
                    checkWatchers |= CHECK_WATCHERS_CHILDREN
                node._checkWatchers = checkWatchers

            # mark parents
            tmp = node
            while parent
                tmp = parent
                if tmp._checkWatchers & CHECK_WATCHERS_CHILDREN
                    break
                tmp._checkWatchers |= CHECK_WATCHERS_CHILDREN

                parent = tmp._parent

            # mark as a master node
            unless parent
                unless tmp._checkWatchers & CHECK_WATCHERS_IS_MASTER_NODE
                    masterNodes.push tmp
                    tmp._checkWatchers |= CHECK_WATCHERS_IS_MASTER_NODE

            # run update
            unless pending
                pending = true
                eventLoop.setImmediate updateWatchers
            return

module.exports.getSelectorCommandsLength = (selector, beginQuery=0, endQuery=Infinity) ->
    sum = 0
    queries = getQueries selector, 0
    for query, i in queries
        if i < beginQuery
            continue
        if i >= endQuery
            break
        sum += query.length
    sum

module.exports.getSelectorPriority = (selector, beginQuery=0, endQuery=Infinity) ->
    sum = 0
    queries = getQueries selector, 0
    for query, i in queries
        if i < beginQuery
            continue
        if i >= endQuery
            break
        for func in query by 3
            sum += func.priority
    sum
