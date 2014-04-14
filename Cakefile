'use strict'

[fs, log, utils, cp] = ['fs-extra', 'log', 'utils', 'child_process'].map require
[bundle, links] = ['./cake/bundle.coffee', './cake/links.coffee'].map require

{assert} = console

option '-d', '--development', 'generate bundle for development'

OUT = './build/'
BUNDLE_OUT = "#{OUT}bundles/"
VIEWS_OUT = "#{OUT}views"
STYLES_OUT = "#{OUT}styles"
MODELS_OUT = "#{OUT}models"

initialized = false

###
Called on the beginning for all tasks
###
init = (opts) ->
	assert not initialized
	assert utils.isObject opts

	initialized = true

	# production mode
	if not opts.development
		log.warn "Production mode is not implemented yet"

###
Override global cake `task`.
Call `init()` on initialize and log tasks.
###
task = do (_super = global.task) -> (name, desc, callback) ->

	func = (opts, taskCallback) ->

		unless initialized then init opts

		onEnd = -> 
			log.end logtime
			taskCallback?()

		logtime = log.time name
		callback.call @, opts, onEnd

		onEnd() if callback.length < 2

	_super.call @, name, desc, func

	func

###
Build bundle file
###
build = (type, callback) ->

	assert ~['qml', 'browser'].indexOf type

	bundle (err, src) ->

		if err then return log.error err

		out = "#{BUNDLE_OUT}#{type}.js"
		fs.outputFileSync out, src

		log.ok "#{utils.capitalize(type)} bundle saved as `#{out}`"

		callback()

compileViewsTask = task 'compile:views', 'Compile HTML views into json format', ->

	[View] = ['view'].map require

	links input: './views', output: VIEWS_OUT, ext: '.json', (name, html, write) ->

		View.fromHTML name, html

		for path of View._files
			view = View.factory path
			json = JSON.stringify view, null, 4
			write json, path

		utils.clear View._files

	log.ok "Views has been successfully compiled"

compileStylesTask = task 'compile:styles', 'Compile SVG styles into json format', ->

	[svg2styles] = ['svg2styles'].map require

	links input: './styles', output: STYLES_OUT, ext: '.json', (name, svg, callback) ->

		svg2styles svg, null, (err, json) ->

			callback JSON.stringify json, null, 4

	log.ok "Styles has been successfully compiled"

compileTask = task 'compile', 'Compile views and styles', ->

	compileViewsTask()
	compileStylesTask()

linkModelsTask = task 'link:models', 'Generate list of models', ->

	links input: './models', output: MODELS_OUT, (name, file, callback) -> callback()

	log.ok "Models has been successfully linked"

linkTask = task 'link', 'Generate needed lists of existed files', ->

	linkModelsTask()

buildBrowserTask = task 'build:browser', 'Build bundle for browser environment', (opts, callback) ->

	build 'browser', callback

buildTask = task 'build', 'Build bundles for all supported environments', (opts, callback) ->

	buildBrowserTask opts, callback

allTask = task 'all', 'Compile, build and link', (opts, callback) ->

	compileTask opts
	linkTask opts
	buildTask opts, callback

runTask = task 'run', 'Compile, build, link and run index', (opts, callback) ->

	allTask opts, ->
		cp.fork './index.coffee'
		callback()