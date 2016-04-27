'use strict'

View = Neft?.Document or require '../index.coffee.md'
{describe, it} = require 'neft-unit'
assert = require 'neft-assert'
{createView, renderParse} = require './utils'
Dict = require 'neft-dict'
List = require 'neft-list'

describe 'attributes', ->
	it 'are parsed to objects', ->
		data = a: 1
		json = JSON.stringify data
		view = createView "<a data='#{json}'></a>"

		assert.isEqual view.render().node.children[0].attrs.data, data

	it 'are parsed to arrays', ->
		data = [1, 2]
		json = JSON.stringify data
		view = createView "<a data='#{json}'></a>"

		assert.isEqual view.render().node.children[0].attrs.data, data

	it 'are parsed to Dicts', ->
		data = Dict a: 1
		json = "Dict({a: 1})"
		view = createView "<a data='#{json}'></a>"

		attrValue = view.render().node.children[0].attrs.data
		assert.instanceOf attrValue, Dict
		assert.isEqual attrValue, data

	it 'are parsed to Lists', ->
		data = List [1, 2]
		json = "List([1, 2])"
		view = createView "<a data='#{json}'></a>"

		attrValue = view.render().node.children[0].attrs.data
		assert.instanceOf attrValue, List
		assert.isEqual attrValue, data
