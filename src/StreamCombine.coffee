_            = require "underscore"
{ Readable } = require "stream"

class StreamCombine extends Readable

	constructor: (@streams, @key) ->
		super objectMode: true

		throw new Error "Streams argument is required"      unless @streams
		throw new Error "Streams should be an Array"        unless Array.isArray @streams
		throw new Error "Streams array should not be empty" unless @streams.length
		throw new Error "Key argument is required"          unless @key?

		@ended   = (false for stream in @streams)
		@current = (null  for stream in @streams)
		@indexes = [0...@streams.length]
		@busy    = false

		for stream, index in @streams
			do (stream, index) =>
				stream.on "error", (error) => @emit "error", error
				stream.on "end",   @handleEnd.bind   @, index
				stream.on "data",  @handleData.bind  @, index

	_read: ->
		return if @busy

		@busy = true

		@resumeStreams()

	getLowestKeyIndexes: ->
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

	resumeStreams: ->
		reEvaluatePush = false

		for index in @indexes
			@current[index] = null
			if @ended[index]
				reEvaluatePush = true unless reEvaluatePush
			else
				@streams[index].resume()

		@evaluatePush() if reEvaluatePush

	evaluatePush: ->
		@indexes = @getLowestKeyIndexes()

		return unless @indexes.length

		send =
			data:    _.map @indexes, (index) => @current[index]
			indexes: @indexes
		send[@key] = @lowest

		pushMore = @push send

		unless pushMore
			@busy = false
			return

		@resumeStreams()

	handleData: (index, object) ->
		@streams[index].pause()
		@current[index] = object

		@evaluatePush()

	handleEnd: (index) ->
		@ended[index] = true

		@evaluatePush()

		@push null if _.every @ended

module.exports = StreamCombine