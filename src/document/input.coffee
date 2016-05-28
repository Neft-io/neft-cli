'use strict'

utils = require 'src/utils'
assert = require 'src/assert'
log = require 'src/log'
signal = require 'src/signal'
Dict = require 'src/dict'
List = require 'src/list'
Binding = require 'src/binding'

assert = assert.scope 'View.Input'
log = log.scope 'View', 'Input'

class DocumentBinding extends Binding
    @New = (binding, ctx, target) ->
        target ?= new DocumentBinding binding, ctx
        Binding.New binding, ctx, target

    constructor: (binding, ctx) ->
        super binding, ctx
        @args = ctx.file.inputArgs
        `//<development>`
        @failed = false
        @failCheckPending = false
        `//</development>`

    getItemById: (item) ->
        if item is 'this'
            @ctx
        else if item is 'ids'
            @args[0]
        else if item is 'attrs'
            @args[1]
        else if item is 'state'
            @args[2]

    `//<development>`
    failCheckQueue = []
    failCheckQueuePending = false

    checkFails = ->
        while binding = failCheckQueue.pop()
            err = failCheckQueue.pop()
            if binding.failed
                log.error "Error in '#{binding.ctx.text}', file '#{binding.ctx.file.path}':\n#{err}"
            binding.failCheckPending = false
        failCheckQueuePending = false
        return

    onError: (err) ->
        @failed = true
        unless @failCheckPending
            @failCheckPending = true
            failCheckQueue.push err, @
        unless failCheckQueuePending
            failCheckQueuePending = true
            setImmediate checkFails
        return

    update: ->
        @failed = false
        super()
    `//</development>`

    getValue: ->
        @ctx.getValue()

    setValue: (val) ->
        @ctx.setValue val

module.exports = (File) -> class Input extends signal.Emitter
    {Element} = File
    {Tag} = Element

    @__name__ = 'Input'
    @__path__ = 'File.Input'

    JSON_CTOR_ID = @JSON_CTOR_ID = File.JSON_CTORS.push(Input) - 1

    i = 1
    JSON_NODE = @JSON_NODE = i++
    JSON_TEXT = @JSON_TEXT = i++
    JSON_BINDING = @JSON_BINDING = i++
    JSON_ARGS_LENGTH = @JSON_ARGS_LENGTH = i

    @_fromJSON = (file, arr, obj) ->
        unless obj
            node = file.node.getChildByAccessPath arr[JSON_NODE]
            obj = new Input file, node, arr[JSON_TEXT], arr[JSON_BINDING]
        obj

    RE = @RE = new RegExp '([^$]*)\\${([^}]*)}([^$]*)', 'gm'

    @test = (str) ->
        RE.lastIndex = 0
        RE.test str

    if utils.isServer
        @parse = require('./input/parser').parse

    createFunction = (func) ->
        new Function 'ids', 'attrs', 'state', func

    constructor: (@file, @node, @text, @binding) ->
        assert.instanceOf @file, File
        assert.instanceOf @node, File.Element
        assert.isString @text
        assert.isObject @binding

        super()

        @target = null
        @scope = null
        @binding.func ?= createFunction @binding.body

        `//<development>`
        if @constructor is Input
            Object.seal @
        `//</development>`

    signal.Emitter.createSignal @, 'onTargetChange'
    signal.Emitter.createSignal @, 'onScopeChange'

    registerBinding: do ->
        cache = Object.create null

        ->
            {binding} = @
            arr = cache[binding.body] ?= [binding.func, binding.connections]
            docBinding = DocumentBinding.New arr, this

            if binding.updateOnCreate
                docBinding.update()
            return

    render: ->
        oldTarget = @target
        oldScope = @scope
        @target = @file.context
        @scope = @file.scope
        if oldTarget isnt @target
            @onTargetChange.emit()
        if oldScope isnt @scope
            @onScopeChange.emit()
        return

    revert: ->
        return

    clone: (original, file) ->
        node = original.node.getCopiedElement @node, file.node

        new Input file, node, @text, @binding

    toJSON: (key, arr) ->
        unless arr
            arr = new Array JSON_ARGS_LENGTH
            arr[0] = JSON_CTOR_ID
        arr[JSON_NODE] = @node.getAccessPath @file.node
        arr[JSON_TEXT] = @text
        arr[JSON_BINDING] = @binding
        arr

    @Text = require('./input/text.coffee') File, @
    @Attr = require('./input/attr.coffee') File, @
