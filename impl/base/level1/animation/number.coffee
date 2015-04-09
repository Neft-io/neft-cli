'use strict'

utils = require 'utils'

module.exports = (impl) ->
	{Types} = impl
	{now} = Date

	pending = []
	nowTime = now()

	vsync = ->
		nowTime = now()

		i = 0; n = pending.length
		while i < n
			anim = pending[i]

			if anim._running and not anim._paused
				updateAnimation anim
				i++
			else
				pending[i] = utils.last(pending)
				pending.pop()
				n--

		requestAnimationFrame vsync
		return
	requestAnimationFrame? vsync

	updateAnimation = (anim) ->
		data = anim._impl

		progress = (nowTime - data.startTime) / anim._duration
		if progress < 0
			data.progress = 0
			return
		else if progress > 1
			progress = 1
		data.progress = progress
		running = progress isnt 1 or (anim._running and anim._loop and anim._when)

		val = (data.to - data.from) * progress + data.from
		target = anim._target
		if val is val and target # isNaN hack
			if not running or anim._updateProperty or not data.propertySetter
				anim._updatePending = true
				target[anim._property] = val
				anim._updatePending = false

				if progress is 1 and data.propertySetter
					impl[data.propertySetter].call target, val
			else
				impl[data.propertySetter].call target, val
				if anim._updateData
					target[data.internalPropertyName] = val

		if progress is 1
			if running
				data.startTime += anim._loopDelay + anim._duration
			else
				data.startTime = 0
				anim.running = false
		return

	DATA =
		type: 'number'
		startTime: 0
		pauseTime: 0
		from: 0
		to: 0

	DATA: DATA

	createData: impl.utils.createDataCloner 'PropertyAnimation', DATA

	create: (data) ->
		impl.Types.PropertyAnimation.create.call @, data

	startAnimation: do (_super = impl.startAnimation) -> ->
		_super.call @
		if @_impl.type is 'number'
			data = @_impl
			data.from = @_from
			data.to = @_to
			pending.push @

			data.startTime = nowTime
			updateAnimation @

			data.startTime += @_startDelay
		return

	stopAnimation: do (_super = impl.stopAnimation) -> ->
		_super.call @
		data = @_impl
		if data.type is 'number' and data.startTime isnt 0
			data.startTime = 0
			updateAnimation @
		return

	resumeAnimation: do (_super = impl.resumeAnimation) -> ->
		_super.call @
		if @_impl.type is 'number'
			data = @_impl
			pending.push @

			data.startTime += Date.now() - data.pauseTime
			data.pauseTime = 0
		return

	pauseAnimation: do (_super = impl.pauseAnimation) -> ->
		_super.call @
		data = @_impl
		if data.type is 'number'
			data.pauseTime = Date.now()
		return
