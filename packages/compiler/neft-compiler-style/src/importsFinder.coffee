'use strict'

{Renderer} = require '@neft/core'
nmlAst = require './nmlAst'

class ImportsFinder
    constructor: (@objects) ->
        @usedTypes = @getUsedTypes()

    getUsedTypes: ->
        used =
            __proto__: null
            Class: true
            device: true
            navigator: true
            screen: true
        for object in @objects
            nmlAst.forEachLeaf
                ast: object, onlyType: nmlAst.OBJECT_TYPE, includeGiven: true,
                includeValues: true, deeply: true,
                (elem) -> used[elem.name] = true
        Object.keys used

    getDefaultImports: ->
        result = []
        for key in @usedTypes
            if Renderer[key]?
                result.push
                    name: key
                    ref: "Renderer.#{key}"
        result

    findAll: ->
        @getDefaultImports()

exports.getImports = ({objects}) ->
    new ImportsFinder(objects).findAll()
