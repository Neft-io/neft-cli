'use strict'

utils = require 'utils'
assert = require 'neft-assert'

test = (node, funcs, index, target, single) ->
	while index < funcs.length
		func = funcs[index]

		if func.isIterator
			func node, funcs, index+3, target
			return false
		else
			data1 = funcs[index + 1]
			data2 = funcs[index + 2]
			unless func(node, data1, data2)
				return false

		index += 3
	true

anyDescendant = (node, funcs, index, target, single) ->
	if children = node.children
		for child in children
			if test(child, funcs, index, target, single)
				target.push child
				if single
					return true

			if child.children
				if anyDescendant(child, funcs, index, target, single)
					if single
						return true
	false
anyDescendant.isIterator = true
anyDescendant.toString = -> 'anyDescendant'

anyChild = (node, funcs, index, target, single) ->
	if children = node.children
		for child in children
			if test(child, funcs, index, target, single)
				target.push child
				if single
					return true
	false
anyChild.isIterator = true
anyChild.toString = -> 'anyChild'

byName = (node, data1) ->
	node.name is data1
byName.isIterator = false
byName.toString = -> 'byName'

byAttr = (node, data1) ->
	node._attrs?.hasOwnProperty data1
byAttr.isIterator = false
byAttr.toString = -> 'byAttr'

byAttrValue = (node, data1, data2) ->
	if attrs = node._attrs
		val = attrs[data1]
		if typeof val is typeof data2
			val is data2
		else
			val+'' is data2+''
	else
		false
byAttrValue.isIterator = false
byAttrValue.toString = -> 'byAttrValue'

byAttrStartsWithValue = (node, data1, data2) ->
	node._attrs?[data1]?.indexOf?(data2) is 0
byAttrStartsWithValue.isIterator = false
byAttrStartsWithValue.toString = -> 'byAttrStartsWithValue'

byAttrEndsWithValue = (node, data1, data2) ->
	val = node._attrs?[data1]
	if typeof val is 'string'
		val.indexOf(data2, val.length - data2.length) isnt -1
	else
		false
byAttrEndsWithValue.isIterator = false
byAttrEndsWithValue.toString = -> 'byAttrEndsWithValue'

byAttrContainsValue = (node, data1, data2) ->
	node._attrs?[data1]?.indexOf?(data2) > -1
byAttrContainsValue.isIterator = false
byAttrContainsValue.toString = -> 'byAttrContainsValue'

TYPE = /^[a-zA-Z0-9|\-:_]+/
DEEP = /^([ ]*)>([ ]*)|^([ ]+)/
ATTR_SEARCH = /^\[([^\]]+?)\]/
ATTR_VALUE_SEARCH = /^\[([^=]+?)=([^\]]+?)\]/

STARTS_WITH = /\^$/
ENDS_WITH = /\$$/
CONTAINS = /\*$/
TRIM_ATTR_VALUE = /(?:'|")?([^'"]*)/

exports.queryAll = (selector, target=[], single=false) ->
	assert.isString selector
	assert.notLengthOf selector, 0
	assert.isArray target
	utils.clear target

	unless @children
		return target

	funcs = []
	queries = [funcs]
	sel = selector.trim()
	while sel.length
		if sel[0] is '*'
			sel = sel.slice 1
		else if exec = TYPE.exec(sel)
			sel = sel.slice exec[0].length
			name = exec[0]
			# name = name.replace ///|///g, ':'
			funcs.push byName, name, null
		else if exec = ATTR_VALUE_SEARCH.exec(sel)
			sel = sel.slice exec[0].length
			[_, name, val] = exec
			val = TRIM_ATTR_VALUE.exec(val)[1]

			if STARTS_WITH.test(name)
				func = byAttrStartsWithValue
			else if ENDS_WITH.test(name)
				func = byAttrEndsWithValue
			else if CONTAINS.test(name)
				func = byAttrContainsValue
			else
				func = byAttrValue

			if func isnt byAttrValue
				name = name.slice 0, -1

			funcs.push func, name, val
		else if exec = ATTR_SEARCH.exec(sel)
			sel = sel.slice exec[0].length
			funcs.push byAttr, exec[1], null
		else if exec = DEEP.exec(sel)
			sel = sel.slice exec[0].length
			deep = exec[0].trim()
			if deep is ''
				funcs.push anyDescendant, null, null
			else if deep is '>'
				funcs.push anyChild, null, null
		else if sel[0] is ','
			funcs = []
			queries.push funcs
			sel = sel.slice 1
			sel = sel.trim()
		else
			throw new Error "queryAll: unexpected selector '#{sel}' in '#{selector}'"

	for funcs in queries
		if anyDescendant(@, funcs, 0, target, single)
			if single
				break

	target

exports.query = (selector) ->
	exports.queryAll.call(@, selector, [], true)[0] or null
