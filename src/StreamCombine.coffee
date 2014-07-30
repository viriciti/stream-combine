_            = require 'underscore'
log          = require 'id-debug'
{ Readable } = require 'stream'

class StreamCombine extends Readable

	constructor: (@streams, @key) ->
		log.debug 'StreamCombine#constructor'

		super objectMode: true

		throw new Error 'Streams argument is required'      unless @streams
		throw new Error 'Streams should be an Array'        unless Array.isArray @streams
		throw new Error 'Streams array should not be empty' unless @streams.length
		throw new Error 'Key argument is required'          unless @key

		@ended   = (false for stream in @streams)
		@current = (null  for stream in @streams)
		@indexes = []

		for stream, index in @streams
			do (stream, index) =>
				stream.on 'data',  @handleData.bind  @, index
				stream.on 'end',   @handleEnd.bind   @, index
				stream.on 'error', (error) => @emit 'error', error

	_read: ->
		log.debug 'StreamCombine#_read'

		@resumeStreams @indexes
		@indexes = []

	getLowestKeyIndexes: ->
		log.debug 'StreamCombine#getLowestKeyIndexes'

		keys = []
		skip = false

		for object, index in @current
			if object
				keys[index] = object[@key]
			else
				if @ended[index]
					keys[index] = Infinity
				else
					skip = true
					break

		return [] if skip

		@lowest = _.min keys

		_.chain @current
			.map    (object, index) => index if object and object[@key] is @lowest
			.filter (index)         -> index?
			.value()

	resumeStreams: (indexes) ->
		log.debug 'StreamCombine#resumeStreams'

		for index in indexes
			@current[index] = null
			@streams[index].resume()

	evaluatePush: ->
		log.debug 'StreamCombine#evaluatePush'

		@indexes = @getLowestKeyIndexes()

		if @indexes.length
			send =
				data:    _.map @indexes, (index) => @current[index]
				indexes: @indexes
			send[@key] = @lowest

			result = @push send

			if result
				@resumeStreams @indexes
				@indexes = []

	handleData: (index, object) ->
		log.debug 'StreamCombine#handleData'

		@streams[index].pause()
		@current[index] = object

		@evaluatePush()

	handleEnd: (index) ->
		log.debug 'StreamCombine#handleEnd'

		@ended[index] = true

		@evaluatePush()

		@push null if _.every @ended, _.identity

module.exports = StreamCombine
