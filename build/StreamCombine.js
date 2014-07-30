var Readable, StreamCombine, log, _,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

_ = require('underscore');

log = require('id-debug');

Readable = require('stream').Readable;

StreamCombine = (function(_super) {
  __extends(StreamCombine, _super);

  function StreamCombine(streams, key) {
    var index, stream, _fn, _i, _len, _ref;
    this.streams = streams;
    this.key = key;
    log.debug('StreamCombine#constructor');
    StreamCombine.__super__.constructor.call(this, {
      objectMode: true
    });
    if (!this.streams) {
      throw new Error('Streams argument is required');
    }
    if (!Array.isArray(this.streams)) {
      throw new Error('Streams should be an Array');
    }
    if (!this.streams.length) {
      throw new Error('Streams array should not be empty');
    }
    if (!this.key) {
      throw new Error('Key argument is required');
    }
    this.ended = (function() {
      var _i, _len, _ref, _results;
      _ref = this.streams;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        stream = _ref[_i];
        _results.push(false);
      }
      return _results;
    }).call(this);
    this.current = (function() {
      var _i, _len, _ref, _results;
      _ref = this.streams;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        stream = _ref[_i];
        _results.push(null);
      }
      return _results;
    }).call(this);
    this.indexes = [];
    _ref = this.streams;
    _fn = (function(_this) {
      return function(stream, index) {
        stream.on('data', _this.handleData.bind(_this, index));
        stream.on('end', _this.handleEnd.bind(_this, index));
        return stream.on('error', function(error) {
          return _this.emit('error', error);
        });
      };
    })(this);
    for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
      stream = _ref[index];
      _fn(stream, index);
    }
  }

  StreamCombine.prototype._read = function() {
    log.debug('StreamCombine#_read');
    this.resumeStreams(this.indexes);
    return this.indexes = [];
  };

  StreamCombine.prototype.getLowestKeyIndexes = function() {
    var index, keys, object, skip, _i, _len, _ref;
    log.debug('StreamCombine#getLowestKeyIndexes');
    keys = [];
    skip = false;
    _ref = this.current;
    for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
      object = _ref[index];
      if (object) {
        keys[index] = object[this.key];
      } else {
        if (this.ended[index]) {
          keys[index] = Infinity;
        } else {
          skip = true;
          break;
        }
      }
    }
    if (skip) {
      return [];
    }
    this.lowest = _.min(keys);
    return _.chain(this.current).map((function(_this) {
      return function(object, index) {
        if (object && object[_this.key] === _this.lowest) {
          return index;
        }
      };
    })(this)).filter(function(index) {
      return index != null;
    }).value();
  };

  StreamCombine.prototype.resumeStreams = function(indexes) {
    var index, _i, _len, _results;
    log.debug('StreamCombine#resumeStreams');
    _results = [];
    for (_i = 0, _len = indexes.length; _i < _len; _i++) {
      index = indexes[_i];
      this.current[index] = null;
      _results.push(this.streams[index].resume());
    }
    return _results;
  };

  StreamCombine.prototype.evaluatePush = function() {
    var result, send;
    log.debug('StreamCombine#evaluatePush');
    this.indexes = this.getLowestKeyIndexes();
    if (this.indexes.length) {
      send = {
        data: _.map(this.indexes, (function(_this) {
          return function(index) {
            return _this.current[index];
          };
        })(this)),
        indexes: this.indexes
      };
      send[this.key] = this.lowest;
      result = this.push(send);
      if (result) {
        this.resumeStreams(this.indexes);
        return this.indexes = [];
      }
    }
  };

  StreamCombine.prototype.handleData = function(index, object) {
    log.debug('StreamCombine#handleData');
    this.streams[index].pause();
    this.current[index] = object;
    return this.evaluatePush();
  };

  StreamCombine.prototype.handleEnd = function(index) {
    log.debug('StreamCombine#handleEnd');
    this.ended[index] = true;
    this.evaluatePush();
    if (_.every(this.ended, _.identity)) {
      return this.push(null);
    }
  };

  return StreamCombine;

})(Readable);

module.exports = StreamCombine;
