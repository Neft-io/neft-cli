'use strict'

nmlParser = require './'

getObjectCode = (nml, path) ->
    ast = nmlParser.getAST nml
    for object in ast.objects
        nmlParser.transformClassNesting object
    nmlParser.getObjectCode ast: ast.objects[0], path: path

it 'parses Item', ->
    code = '''
        @Item {}
    '''
    expected = '''
        const _i0 = Item.New()
        _i0
        return { objects: {"_i0": _i0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'adds given file path', ->
    code = '''
        @Item {}
    '''
    expected = '''
        const _i0 = Item.New()
        _i0._path = "abc123"
        _i0
        return { objects: {"_i0": _i0}, item: _i0 }
    '''
    assert.is getObjectCode(code, 'abc123'), expected

it 'sets item id', ->
    code = '''
        @Item {
            id: abc123
        }
    '''
    expected = '''
        const abc123 = Item.New()
        _RendererObject.setOpts(abc123, {"id": "abc123"})
        return { objects: {"abc123": abc123}, item: abc123 }
    '''
    assert.is getObjectCode(code), expected

it 'sets item properties', ->
    code = '''
        @Item {
            property prop1
            property customProp
        }
    '''
    expected = '''
        const _i0 = Item.New()
        _RendererObject.createProperty(_i0, "prop1")
        _RendererObject.createProperty(_i0, "customProp")
        _i0
        return { objects: {"_i0": _i0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'sets item signals', ->
    code = '''
        @Item {
            signal signal1
            signal customSignal
        }
    '''
    expected = '''
        const _i0 = Item.New()
        _RendererObject.createSignal(_i0, "signal1")
        _RendererObject.createSignal(_i0, "customSignal")
        _i0
        return { objects: {"_i0": _i0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'sets item attributes', ->
    code = '''
        @Item {
            prop1: 123
        }
    '''
    expected = '''
        const _i0 = Item.New()
        _RendererObject.setOpts(_i0, {"prop1": 123})
        return { objects: {"_i0": _i0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'sets item object attributes', ->
    code = '''
        @Item {
            prop1: @Rectangle {
                color: 'red'
            }
        }
    '''
    expected = '''
        const _i1 = Item.New()
        const _i0 = Rectangle.New()
        _RendererObject.setOpts(_i1, {\
        "prop1": _RendererObject.setOpts(_i0, {"color": 'red'}), \
        "children": [_i0]})
        return { objects: {"_i1": _i1, "_i0": _i0}, item: _i1 }
    '''
    assert.is getObjectCode(code), expected

it 'parses Item with children', ->
    code = '''
        @Item {
            @Rectangle {
                color: 'red'
            }
        }
    '''
    expected = '''
        const _i1 = Item.New()
        const _i0 = Rectangle.New()
        _RendererObject.setOpts(_i1, {"children": [_RendererObject.setOpts(_i0, {"color": 'red'})]})
        return { objects: {"_i1": _i1, "_i0": _i0}, item: _i1 }
    '''
    assert.is getObjectCode(code), expected

it 'sets item functions', ->
    code = '''
        @Item {
            onEvent(param1, param2) {
                return param1 + param2;
            }
        }
    '''
    expected = '''
        const _i0 = Item.New()
        _RendererObject.setOpts(_i0, {"onEvent": function(param1,param2){
                return param1 + param2;
            }})
        return { objects: {"_i0": _i0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'sets item bindings', ->
    code = '''
        @Item {
            width: child.width

            @Rectangle {
                id: child
            }
        }
    '''
    expected = '''
        const _i0 = Item.New()
        const child = Rectangle.New()
        _RendererObject.setOpts(_i0, {"width": [function(){return child.width}, [[child,"width"]]], \
        "children": [_RendererObject.setOpts(child, {"id": "child"})]})
        return { objects: {"_i0": _i0, "child": child}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'sets item deep bindings', ->
    code = '''
        @Class {
            changes: {
                width: Renderer.width
            }
        }
    '''
    expected = '''
        const _i0 = Class.New()
        _RendererObject.setOpts(_i0, {"changes": {"width": [\
        function(){return Renderer.width}, [[Renderer,"width"]]]}})
        return { objects: {"_i0": _i0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'supports Renderer types in bindings', ->
    code = '''
        @NumberAnimation {
            updateProperty: PropertyAnimation.ALWAYS
        }
    '''
    expected = '''
        const _i0 = NumberAnimation.New()
        _RendererObject.setOpts(_i0, {"updateProperty": [function(){\
        return Renderer.PropertyAnimation.ALWAYS}, [[[Renderer,"PropertyAnimation"],"ALWAYS"]]]})
        return { objects: {"_i0": _i0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'supports Renderer namespaces in bindings', ->
    code = '''
        @Item {
            width: screen.navigationBar.height
        }
    '''
    expected = '''
        const _i0 = Item.New()
        _RendererObject.setOpts(_i0, {"width": [function(){\
        return Renderer.screen.navigationBar.height}, \
        [[[[Renderer,"screen"],"navigationBar"],"height"]]]})
        return { objects: {"_i0": _i0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'sets item anchors', ->
    code = '''
        @Item {
            anchors.left: previousSibling.horizontalCenter
        }
    '''
    expected = '''
        const _i0 = Item.New()
        _RendererObject.setOpts(_i0, {"anchors.left": ["previousSibling","horizontalCenter"]})
        return { objects: {"_i0": _i0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'parses conditions', ->
    code = '''
        @Item {
            if (this.width > 50) {
                height: Renderer.width
            }
        }
    '''
    expected = '''
        const _i0 = Item.New()
        const _r0 = Class.New()
        _RendererObject.setOpts(_i0, {"children": [\
        _RendererObject.setOpts(_r0, {\
        "running": [function(){return this.target.width > 50}, \
        [[["this","target"],"width"]]], \
        "changes": {"height": [function(){return Renderer.width}, [[Renderer,"width"]]]}\
        })\
        ]})
        return { objects: {"_i0": _i0, "_r0": _r0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'parses conditions returning value', ->
    code = '''
        @Item {
            if (Renderer.props.hover) {
                height: 100
            }
        }
    '''
    expected = '''
        const _i0 = Item.New()
        const _r0 = Class.New()
        _RendererObject.setOpts(_i0, {"children": [\
        _RendererObject.setOpts(_r0, {\
        "running": [function(){return Renderer.props.hover}, \
        [[[Renderer,"props"],"hover"]]], \
        "changes": {"height": 100}\
        })\
        ]})
        return { objects: {"_i0": _i0, "_r0": _r0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'parses selects', ->
    code = '''
        @Item {
            a > b {
                color: 'red'
            }
        }
    '''
    expected = '''
        const _i0 = Item.New()
        const _r0 = Class.New()
        _RendererObject.setOpts(_i0, {"children": [\
        _RendererObject.setOpts(_r0, {\
        "document.query": 'a > b', \
        "document.queryElements": __elements, \
        "changes": {"color": 'red'}\
        })\
        ]})
        return { objects: {"_i0": _i0, "_r0": _r0}, item: _i0 }
    '''
    assert.is getObjectCode(code), expected

it 'parses top level selects', ->
    code = '''
        a > b {
            color: 'red'
        }
    '''
    expected = '''
        const _r0 = Class.New()
        _RendererObject.setOpts(_r0, {\
        "document.query": 'a > b', \
        "document.queryElements": __elements, \
        "changes": {"color": 'red'}\
        })
        return { objects: {"_r0": _r0}, select: _r0 }
    '''
    assert.is getObjectCode(code), expected

it 'parses top level selects with nesting', ->
    code = '''
        a > b {
            color: 'red'

            @NumberAnimation {
                running: true
            }

            @Item {}
        }
    '''
    expected = '''
        const _r0 = Class.New()
        _RendererObject.setOpts(_r0, {"document.query": 'a > b', \
        "document.queryElements": __elements, \
        "changes": {"color": 'red'}, "nesting": function(){
        const _i0 = NumberAnimation.New()
        const _i1 = Item.New()
        return {"children": [_RendererObject.setOpts(_i0, {"running": true}), _i1]}
        }})
        return { objects: {"_r0": _r0}, select: _r0 }
    '''
    assert.is getObjectCode(code), expected

it 'items in custom properties become children', ->
    code = '''
        @Item {
            property background: @Rectangle {
                color: 'red'
            }
            @Image {}
        }
    '''
    expected = '''
        const _i2 = Item.New()
        const _i0 = Rectangle.New()
        const _i1 = Image.New()
        _RendererObject.createProperty(_i2, "background")
        _RendererObject.setOpts(_i2, {\
        "background": _RendererObject.setOpts(_i0, {"color": 'red'}), \
        "children": [_i0, _i1]\
        })
        return { objects: {"_i2": _i2, "_i0": _i0, "_i1": _i1}, item: _i2 }
    '''
    assert.is getObjectCode(code), expected

it 'items in custom properties of select become children', ->
    code = '''
        .foo {
            property background: @Rectangle {
                color: 'red'
            }
            @Item {}
        }
    '''
    expected = '''
        const _r0 = Class.New()
        _RendererObject.setOpts(_r0, {"document.query": '.foo', \
        "document.queryElements": __elements, \
        "customProperties": ["background"], \
        "nesting": function(){
        const _i0 = Rectangle.New()
        const _i1 = Item.New()
        return {"changes": {\
        "background": _RendererObject.setOpts(_i0, {"color": 'red'})}, \
        "children": [_i0, _i1]}
        }})
        return { objects: {"_r0": _r0}, select: _r0 }
    '''
    assert.is getObjectCode(code), expected

it 'sets select properties', ->
    code = '''
        .foo {
            property prop1
            property customProp: 5
        }
    '''
    expected = '''
        const _r0 = Class.New()
        _RendererObject.setOpts(_r0, {\
            "document.query": '.foo', \
            "document.queryElements": __elements, \
            "changes": {\
                "customProp": 5\
            }, \
            "customProperties": ["prop1","customProp"]\
        })
        return { objects: {"_r0": _r0}, select: _r0 }
    '''
    assert.is getObjectCode(code), expected

it 'sets select signals', ->
    code = '''
        .foo {
            signal onPlayerHit
            signal heal() {console.log(1)}
        }
    '''
    expected = '''
        const _r0 = Class.New()
        _RendererObject.setOpts(_r0, {\
            "document.query": '.foo', \
            "document.queryElements": __elements, \
            "changes": {\
                "heal": function(){console.log(1)}\
            }, \
            "customSignals": ["onPlayerHit","heal"]\
        })
        return { objects: {"_r0": _r0}, select: _r0 }
    '''
    assert.is getObjectCode(code), expected
