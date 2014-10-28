'use strict'

utils = require 'utils'

queue = []
queueItems = {}
pending = false

updateItem = (item) ->
	{children} = item
	{columnsPositions, rowsPositions, gridType} = item._impl

	# get config
	if gridType is exports.ALL
		{children, columns, rows} = item
		columnSpacing = item.spacing.column
		rowSpacing = item.spacing.row
	else
		columnSpacing = rowSpacing = item.spacing

		if gridType is exports.COLUMN
			columns = 1
			rows = Infinity
		else
			columns = Infinity
			rows = 1

	# reset columns positions
	for column, i in columnsPositions
		columnsPositions[i] = 0

	# reset rows positions
	for row, i in rowsPositions
		rowsPositions[i] = 0

	# refresh widths
	for child, i in children
		column = i % columns
		row = Math.floor(i/columns) % rows

		# omit not visible children
		unless child.visible
			continue

		{width, height} = child

		columnsPositions[column] = Math.max (columnsPositions[column] or 0), width
		rowsPositions[row] = Math.max (rowsPositions[row] or 0), height

	# sum columns positions
	last = 0
	for column, i in columnsPositions
		val = columnsPositions[i]
		last = columnsPositions[i] += last + (if val then columnSpacing else 0)

	# sum rows positions
	last = 0
	for row, i in rowsPositions
		val = rowsPositions[i]
		last = rowsPositions[i] += last + (if val then rowSpacing else 0)

	# set positions
	for child, i in children
		column = i % columns
		row = Math.floor(i/columns) % rows

		if gridType & exports.ROW
			child.x = columnsPositions[column-1] or 0

		if gridType & exports.COLUMN
			child.y = rowsPositions[row-1] or 0

	# set item size
	item.width = Math.max 0, utils.last(columnsPositions) - columnSpacing
	item.height = Math.max 0, utils.last(rowsPositions) - rowSpacing

updateItems = ->
	pending = false
	while queue.length
		item = queue.pop()
		queueItems[item.__hash__] = false
		updateItem item
	null

update = ->
	if queueItems[@__hash__]
		return

	queueItems[@__hash__] = true
	queue.push @

	unless pending
		setImmediate updateItems
		pending = true

updateParent = ->
	update.call @parent

exports.COLUMN = 1<<0
exports.ROW = 1<<1
exports.ALL = (1<<2) - 1

exports.create = (item, type) ->
	storage = item._impl

	storage.gridType = type
	storage.columnsPositions = []
	storage.rowsPositions = []

	# update on children change
	item.onChildrenChanged update

	# update on each children size change
	item.children.onInserted (i, item) ->
		item.onWidthChanged updateParent
		item.onHeightChanged updateParent
	item.children.onPopped (i, item) ->
		item.onWidthChanged.disconnect updateParent
		item.onHeightChanged.disconnect updateParent

exports.update = update