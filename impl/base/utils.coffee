utils = require 'utils'

module.exports = (impl) ->

	INTEGER_PROPERTIES:
		__proto__: null
		x: true
		y: true
		width: true
		height: true

	SETTER_METHODS_NAMES:
		__proto__: null
		'x': 'setItemX'
		'y': 'setItemY'
		'width': 'setItemWidth'
		'height': 'setItemHeight'
		'opacity': 'setItemOpacity'
		'rotation': 'setItemRotation'
		'scale': 'setItemScale'

	grid: require './utils/grid'
	fill: require './utils/fill'

	createDataCloner: (extend, base) ->
		->
			obj = extend
			if base?
				extend = impl.Types[extend].DATA
				obj = utils.clone extend
				utils.merge obj, base
				utils.merge base, obj
			json = JSON.stringify obj
			func = Function "return #{json}"
			func