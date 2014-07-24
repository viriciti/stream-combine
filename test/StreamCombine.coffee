assert       = require 'assert'
{ Readable } = require 'stream'

StreamCombine = require '../build/StreamCombine'

class TestStream extends Readable
	constructor: (@serie) ->
		super objectMode: true
		@push point for point in @serie
		@push null

	_read: ->

checkSeries = (series, expected, done) ->
	str = ''
	sb  = new StreamCombine (new TestStream serie for serie in series), 'id'
	sb.on 'data', (data) -> str += JSON.stringify data
	sb.on 'end', ->
		assert.equal str, expected
		done()

describe 'StreamCombine', ->

	describe 'constructor', ->
		describe 'when the streams argument is not defined', ->
			it 'should throw an error', (done) ->
				assert.throws ->
					new StreamCombine
				, /Streams argument is required/

				done()

		describe 'when streams is not an Array', ->
			it 'should throw an error', (done) ->
				assert.throws ->
					new StreamCombine {}
				, /Streams should be an Array/

				done()

		describe 'when the streams array is empty', ->
			it 'should throw an error', (done) ->
				assert.throws ->
					new StreamCombine []
				, /Streams array should not be empty/

				done()

		describe 'when the key argument is not defined', ->
			it 'should throw an error', (done) ->
				assert.throws ->
					new StreamCombine [1]
				, /Key argument is required/

				done()

	describe 'integration', ->
		describe 'one series of data', ->
			it 'should be equal as expected', (done) ->
				series   = [[ { id: 1, 11 }, { id: 2, 12 }, { id: 3, 13 }, { id: 4, 14 }, { id: 5, 15 } ]]

				expected = '{"data":[{"11":11,"id":1}],"id":1}{"data":[{"12":12,"id":2}],"id":2}{"data":[{"13":13,"id":3}],"id":3}{"data":[{"14":14,"id":4}],"id":4}{"data":[{"15":15,"id":5}],"id":5}'

				checkSeries series, expected, done

		describe 'two series of data - evenly distributed', ->
			it 'should be equal as expected', (done) ->
				series = []
				series.push [ { id: 1, 11 }, { id: 2, 12 }, { id: 3, 13 }, { id: 4, 14 }, { id: 5, 15 } ]
				series.push [ { id: 1, 11 }, { id: 2, 12 }, { id: 3, 13 }, { id: 4, 14 }, { id: 5, 15 } ]

				expected = '{"data":[{"11":11,"id":1},{"11":11,"id":1}],"id":1}{"data":[{"12":12,"id":2},{"12":12,"id":2}],"id":2}{"data":[{"13":13,"id":3},{"13":13,"id":3}],"id":3}{"data":[{"14":14,"id":4},{"14":14,"id":4}],"id":4}{"data":[{"15":15,"id":5},{"15":15,"id":5}],"id":5}'

				checkSeries series, expected, done

		describe 'two series of data - unevenly distributed', ->
			it 'should be equal as expected', (done) ->
				series = []
				series.push [ { id: 1, 11 }, { id: 2, 12 }, { id: 3, 13 },                { id: 5, 15 }                ]
				series.push [                { id: 2, 12 }, { id: 3, 13 }, { id: 4, 14 }, { id: 5, 15 }, { id: 5, 15 } ]

				expected = '{"data":[{"11":11,"id":1}],"id":1}{"data":[{"12":12,"id":2},{"12":12,"id":2}],"id":2}{"data":[{"13":13,"id":3},{"13":13,"id":3}],"id":3}{"data":[{"14":14,"id":4}],"id":4}{"data":[{"15":15,"id":5},{"15":15,"id":5}],"id":5}{"data":[{"15":15,"id":5}],"id":5}'

				checkSeries series, expected, done
