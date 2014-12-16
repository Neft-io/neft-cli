'use strict'

utils = require 'utils'
PIXI = require '../pixi.lib.js'

if window+'' is '[object Window]'
	emptyTexture = PIXI.Texture.fromImage 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQIW2NkAAIAAAoAAggA9GkAAAAASUVORK5CYII='
	# emptyTexture = PIXI.Texture.fromImage 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIW2NkYGD4DwABCQEBtxmN7wAAAABJRU5ErkJggg=='

module.exports = (impl) ->
	{items} = impl

	if utils.isEmpty PIXI
		return require('../../base/level0/image') impl

	create: (item) ->
		impl.Types.Item.create item
		item._impl.contentElem = new PIXI.Sprite emptyTexture
		item._impl.elem.addChild item._impl.contentElem

	setImageSource: (val, callback) ->
		{contentElem, elem} = @_impl
		{width, height} = contentElem

		texture = PIXI.Texture.fromImage val
		contentElem.setTexture texture

		# BUG: size for SVG images is changing
		contentElem.width = width
		contentElem.height = height

		# TODO: implement callback

		impl._dirty = true