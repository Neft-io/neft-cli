'use strict'

utils = require 'utils'

{assert} = console

# platform specified
PlatformImpl = switch true
	when utils.isNode
		require './impl/node/index'
	when utils.isBrowser
		require './impl/browser/index'
	when utils.isQml
		require './impl/qml/index'
	when utils.isAndroid
		require './impl/android/index'

assert PlatformImpl
, "No networking implementation found"

module.exports = (Networking) ->
	PlatformImpl Networking