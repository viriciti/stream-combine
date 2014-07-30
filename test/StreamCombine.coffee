_               = require 'underscore'
assert          = require 'assert'
async           = require 'async'
{ Readable }    = require 'stream'
{ MongoClient } = require 'mongodb'

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

randomTestData = ->
	data = []

	for i in [1..5000]
		prevId = data[data.length - 1]?._id or Math.ceil Math.random() * 10

		data.push
			_id:   prevId + Math.ceil Math.random() * 10
			value: Math.round(Math.random() * 1000)

	data


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

				expected = '{"data":[{"11":11,"id":1}],"indexes":[0],"id":1}{"data":[{"12":12,"id":2}],"indexes":[0],"id":2}{"data":[{"13":13,"id":3}],"indexes":[0],"id":3}{"data":[{"14":14,"id":4}],"indexes":[0],"id":4}{"data":[{"15":15,"id":5}],"indexes":[0],"id":5}'

				checkSeries series, expected, done

		describe 'two series of data - evenly distributed', ->
			it 'should be equal as expected', (done) ->
				series = []
				series.push [ { id: 1, 11 }, { id: 2, 12 }, { id: 3, 13 }, { id: 4, 14 }, { id: 5, 15 } ]
				series.push [ { id: 1, 11 }, { id: 2, 12 }, { id: 3, 13 }, { id: 4, 14 }, { id: 5, 15 } ]

				expected = '{"data":[{"11":11,"id":1},{"11":11,"id":1}],"indexes":[0,1],"id":1}{"data":[{"12":12,"id":2},{"12":12,"id":2}],"indexes":[0,1],"id":2}{"data":[{"13":13,"id":3},{"13":13,"id":3}],"indexes":[0,1],"id":3}{"data":[{"14":14,"id":4},{"14":14,"id":4}],"indexes":[0,1],"id":4}{"data":[{"15":15,"id":5},{"15":15,"id":5}],"indexes":[0,1],"id":5}'

				checkSeries series, expected, done

		describe 'two series of data - unevenly distributed', ->
			it 'should be equal as expected', (done) ->
				series = []
				series.push [ { id: 1, 11 }, { id: 2, 12 }, { id: 3, 13 },                { id: 5, 15 }                ]
				series.push [                { id: 2, 12 }, { id: 3, 13 }, { id: 4, 14 }, { id: 5, 15 }, { id: 5, 15 } ]

				expected = '{"data":[{"11":11,"id":1}],"indexes":[0],"id":1}{"data":[{"12":12,"id":2},{"12":12,"id":2}],"indexes":[0,1],"id":2}{"data":[{"13":13,"id":3},{"13":13,"id":3}],"indexes":[0,1],"id":3}{"data":[{"14":14,"id":4}],"indexes":[1],"id":4}{"data":[{"15":15,"id":5},{"15":15,"id":5}],"indexes":[0,1],"id":5}{"data":[{"15":15,"id":5}],"indexes":[1],"id":5}'

				checkSeries series, expected, done

	describe 'mongodb cursor streams', ->

		database        = null
		collectionNames = ("test-#{i}" for i in [1..40])

		before (done) ->
			@timeout 10000

			MongoClient.connect "mongodb://localhost:27017/stream-combine-test", (error, db) ->
				throw error if error

				database = db

				insertTestData = (collectionName, cb) ->
					testData = randomTestData()
					# console.log "Inserting #{testData.length} documents into collection #{collectionName}..."

					database.collection collectionName, (error, collection) ->
						return cb error if error

						collection.remove (error) ->
							return cb error if error

							collection.insert testData, (error) ->
								return cb error if error

								# console.log 'Done.'

								cb()

				async.each collectionNames, insertTestData, (error) ->
					throw error if error

					done()

		after (done) ->
			@timeout 10000

			database.dropDatabase (error) ->
				throw error if error

				database.close()

				done()

		describe 'stream all collections', ->
			it 'should work', (done) ->
				@timeout 10000

				streams = []

				addCollectionStream = (collectionName, cb) ->
					database.collection collectionName, (error, collection) ->
						return cb error if error

						streams.push collection.find().stream()

						cb()

				async.each collectionNames, addCollectionStream, (error) ->
					throw error if error

					sb  = new StreamCombine streams, '_id'
					sb.on 'data', (data) ->
					sb.on 'error', done
					sb.on 'end', ->
						done()

	# describe 'mongodb cursor streams - vems framework', ->

	# 	database        = null
	# 	collectionNames = null

	# 	before (done) ->
	# 		@timeout 10000

	# 		MongoClient.connect "mongodb://localhost:27017/vio_ret405", (error, db) ->
	# 			throw error if error

	# 			database = db

	# 			database.collectionNames (error, names) =>
	# 				return cb error if error

	# 				collectionNames = _.chain names
	# 					.pluck 'name'
	# 					.map (name) ->                # take the name of db.name
	# 						name
	# 							.split '.'
	# 							.pop()
	# 					.filter (name) ->             # not system.indexes
	# 						name isnt 'system.indexes'
	# 					.filter (name) ->
	# 						not isNaN parseInt name     # name should be an integer
	# 					.unique()                     # unique
	# 					.value()

	# 				done()

	# 	describe 'stream all collections', ->
	# 		it 'should work', (done) ->
	# 			@timeout 10000

	# 			streams = []

	# 			addCollectionStream = (collectionName, cb) ->
	# 				database.collection collectionName, (error, collection) ->
	# 					return cb error if error

	# 					streams.push collection.find().stream()

	# 					cb()

	# 			async.each collectionNames, addCollectionStream, (error) ->
	# 				throw error if error

	# 				count = 0

	# 				sb  = new StreamCombine streams, '_id'
	# 				sb.on 'data', (data) -> count++
	# 				sb.on 'error', done
	# 				sb.on 'end', ->
	# 					console.log "counted #{count}"
	# 					done()






