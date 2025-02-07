'use strict'

assert = require '../../../../assert'
utils = require '../../../../util'
log = require '../../../../log'

log = log.scope 'Renderer', 'Font'

module.exports = (Renderer, Impl, itemUtils) -> (ctor) -> class Font extends itemUtils.DeepObject
    @__name__ = 'Font'

    itemUtils.defineProperty
        constructor: ctor
        name: 'font'
        defaultValue: null
        valueConstructor: Font
        developmentSetter: (val) ->
            if val?
                assert.isObject val
        setter: (_super) -> (val) ->
            _super.call @, val

            if utils.isObject(val)
                {font} = @
                font.family = val.family if val.family?
                font.pixelSize = val.pixelSize if val.pixelSize?
                font.weight = val.weight if val.weight?
                font.wordSpacing = val.wordSpacing if val.wordSpacing?
                font.letterSpacing = val.letterSpacing if val.letterSpacing?
                font.italic = val.italic if val.italic?
            return

    constructor: (ref) ->
        super ref
        @_family = 'sans-serif'
        @_pixelSize = 14
        @_weight = 0.4
        @_wordSpacing = 0
        @_letterSpacing = 0
        @_italic = false

        Object.preventExtensions @

    setFontFamilyImpl = Impl["set#{ctor.__name__}FontFamily"]
    reloadFontFamily = (font) ->
        name = Renderer.FontLoader.getInternalFontName font._family, font._weight, font._italic
        name ||= 'sans-serif'
        setFontFamilyImpl.call font._ref, name

    itemUtils.defineProperty
        constructor: @
        name: 'family'
        defaultValue: 'sans-serif'
        namespace: 'font'
        parentConstructor: ctor
        developmentSetter: (val) ->
            assert.isString val, "Font.family needs to be a string, but #{val} given"
        setter: (_super) -> (val) ->
            _super.call @, val
            reloadFontFamily @

    itemUtils.defineProperty
        constructor: @
        name: 'pixelSize'
        defaultValue: 14
        namespace: 'font'
        parentConstructor: ctor
        implementation: Impl["set#{ctor.__name__}FontPixelSize"]
        developmentSetter: (val) ->
            assert.isFloat val, "Font.pixelSize needs to be a float, but #{val} given"

    itemUtils.defineProperty
        constructor: @
        name: 'weight'
        defaultValue: 0.4
        namespace: 'font'
        parentConstructor: ctor
        developmentSetter: (val) ->
            assert.isFloat val, "Font.weight needs to be a float, but #{val} given"
            assert.operator val, '>=', 0, "Font.weight needs to be in range 0-1, #{val} given"
            assert.operator val, '<=', 1, "Font.weight needs to be in range 0-1, #{val} given"
        setter: (_super) -> (val) ->
            _super.call @, val
            reloadFontFamily @

    itemUtils.defineProperty
        constructor: @
        name: 'wordSpacing'
        defaultValue: 0
        namespace: 'font'
        parentConstructor: ctor
        implementation: Impl["set#{ctor.__name__}FontWordSpacing"]
        developmentSetter: (val) ->
            assert.isFloat val, "Font.wordSpacing needs to be a float, but #{val} given"

    itemUtils.defineProperty
        constructor: @
        name: 'letterSpacing'
        defaultValue: 0
        namespace: 'font'
        parentConstructor: ctor
        implementation: Impl["set#{ctor.__name__}FontLetterSpacing"]
        developmentSetter: (val) ->
            assert.isFloat val, "Font.letterSpacing needs to be a float, but #{val} given"

    itemUtils.defineProperty
        constructor: @
        name: 'italic'
        defaultValue: false
        namespace: 'font'
        parentConstructor: ctor
        developmentSetter: (val) ->
            assert.isBoolean val, "Font.italic needs to be a boolean, but #{val} given"
        setter: (_super) -> (val) ->
            _super.call @, val
            reloadFontFamily @

    toJSON: ->
        family: @family
        pixelSize: @pixelSize
        weight: @weight
        wordSpacing: @wordSpacing
        letterSpacing: @letterSpacing
        italic: @italic
