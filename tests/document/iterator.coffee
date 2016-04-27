'use strict'

View = Neft?.Document or require '../index.coffee.md'
{describe, it} = require 'neft-unit'
assert = require 'neft-assert'
{createView, renderParse} = require './utils'
Dict = require 'neft-dict'
List = require 'neft-list'

describe 'neft:each', ->
	it 'loops expected times', ->
		source = createView '<ul neft:each="[0,0]">1</ul>'
		view = source.clone()

		renderParse view
		assert.is view.node.stringify(), '<ul>11</ul>'

	it 'provides `attrs.item` property', ->
		source = createView '<ul neft:each="[1,2]">${attrs.item}</ul>'
		view = source.clone()

		renderParse view
		assert.is view.node.stringify(), '<ul>12</ul>'

	it 'provides `attrs.index` property', ->
		source = createView '<ul neft:each="[1,2]">${attrs.index}</ul>'
		view = source.clone()

		renderParse view
		assert.is view.node.stringify(), '<ul>01</ul>'

	it 'provides `attrs.each` property', ->
		source = createView '<ul neft:each="[1,2]">${attrs.each}</ul>'
		view = source.clone()

		renderParse view
		assert.is view.node.stringify(), '<ul>1,21,2</ul>'

	it 'supports runtime updates', ->
		source = createView '<ul neft:each="${attrs.arr}">${attrs.each[attrs.index]}</ul>'
		view = source.clone()

		attrs = arr: arr = new List [1, 2]

		renderParse view, attrs: attrs
		assert.is view.node.stringify(), '<ul>12</ul>'

		arr.insert 1, 'a'
		assert.is view.node.stringify(), '<ul>1a2</ul>'

		arr.pop 1
		assert.is view.node.stringify(), '<ul>12</ul>'

		arr.append 3
		assert.is view.node.stringify(), '<ul>123</ul>'

	it 'access global `attrs`', ->
		source = createView '<ul neft:each="[1,2]">${attrs.a}</ul>'
		view = source.clone()

		renderParse view,
			attrs: a: 'a'
		assert.is view.node.stringify(), '<ul>aa</ul>'

	it 'access `ids`', ->
		source = createView """
			<div id="a" prop="a" visible="false" />
			<ul neft:each="[1,2]">${ids.a.attrs.prop}</ul>
		"""
		view = source.clone()

		renderParse view
		assert.is view.node.stringify(), '<ul>aa</ul>'

	it 'access neft:fragment `attrs`', ->
		source = createView """
			<neft:fragment neft:name="a" a="a">
				<ul neft:each="[1,2]">${attrs.a}${attrs.b}</ul>
			</neft:fragment>
			<neft:use neft:fragment="a" b="b" />
		"""
		view = source.clone()

		renderParse view
		assert.is view.node.stringify(), '<ul>abab</ul>'

	it 'uses parent `this` context', ->
		source = createView """
			<neft:fragment neft:name="a">
				<neft:script>
					module.exports = function(){
						this.x = 1;
					}
				</neft:script>
				<ul neft:each="[1,2]">${this.x}</ul>
			</neft:fragment>
			${this.x}
			<neft:use neft:fragment="a" />
		"""
		view = source.clone()

		renderParse view
		assert.is view.node.stringify(), '<ul>11</ul>'
