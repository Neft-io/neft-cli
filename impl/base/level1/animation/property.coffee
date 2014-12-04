'use strict'

module.exports = (impl) ->
	{Types, items} = impl
	{Animation} = Types

	create: (animation) ->
		Animation.create animation

		target = animation._impl
		target.target = ''
		target.property = ''
		target.duration = 1000
		target.from = null
		target.to = null

	setPropertyAnimationTarget: (val) ->
		target = @_impl
		target.target = val
		if target.from is null and target.property
			target.from = @[target.property]

	setPropertyAnimationProperty: (val) ->
		target = @_impl
		target.property = val
		if target.from is null and target.target
			target.from = @[val]

	setPropertyAnimationDuration: (val) ->
		@_impl.duration = val

	setPropertyAnimationFrom: (val) ->
		@_impl.from = val

	setPropertyAnimationTo: (val) ->
		@_impl.to = val
