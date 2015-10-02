var Readable, StreamCombine, _,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

_ = require("underscore");

Readable = require("stream").Readable;

StreamCombine = (function(superClass) {
  extend(StreamCombine, superClass);

  function StreamCombine(streams, key) {
    var fn, i, index, j, len, ref, ref1, results, stream;
    this.streams = streams;
    this.key = key;
    StreamCombine.__super__.constructor.call(this, {
      objectMode: true
    });
    if (!this.streams) {
      throw new Error("Streams argument is required");
    }
    if (!Array.isArray(this.streams)) {
      throw new Error("Streams should be an Array");
    }
    if (!this.streams.length) {
      throw new Error("Streams array should not be empty");
    }
    if (this.key == null) {
      throw new Error("Key argument is required");
    }
    this.ended = (function() {
      var i, len, ref, results;
      ref = this.streams;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        stream = ref[i];
        results.push(false);
      }
      return results;
    }).call(this);
    this.current = (function() {
      var i, len, ref, results;
      ref = this.streams;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        stream = ref[i];
        results.push(null);
      }
      return results;
    }).call(this);
    this.indexes = (function() {
      results = [];
      for (var i = 0, ref = this.streams.length; 0 <= ref ? i < ref : i > ref; 0 <= ref ? i++ : i--){ results.push(i); }
      return results;
    }).apply(this);
    this.busy = false;
    ref1 = this.streams;
    fn = (function(_this) {
      return function(stream, index) {
        stream.on("error", function(error) {
          return _this.emit("error", error);
        });
        stream.on("end", _this.handleEnd.bind(_this, index));
        return stream.on("data", _this.handleData.bind(_this, index));
      };
    })(this);
    for (index = j = 0, len = ref1.length; j < len; index = ++j) {
      stream = ref1[index];
      fn(stream, index);
    }
  }

  StreamCombine.prototype._read = function() {
    if (this.busy) {
      return;
    }
    this.busy = true;
    return this.resumeStreams();
  };

  StreamCombine.prototype.getLowestKeyIndexes = function() {
    var i, index, keys, len, object, ref, skip;
    keys = [];
    skip = false;
    ref = this.current;
    for (index = i = 0, len = ref.length; i < len; index = ++i) {
      object = ref[index];
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

  StreamCombine.prototype.resumeStreams = function() {
    var i, index, len, reEvaluatePush, ref;
    reEvaluatePush = false;
    ref = this.indexes;
    for (i = 0, len = ref.length; i < len; i++) {
      index = ref[i];
      this.current[index] = null;
      if (this.ended[index]) {
        if (!reEvaluatePush) {
          reEvaluatePush = true;
        }
      } else {
        this.streams[index].resume();
      }
    }
    if (reEvaluatePush) {
      return this.evaluatePush();
    }
  };

  StreamCombine.prototype.evaluatePush = function() {
    var pushMore, send;
    this.indexes = this.getLowestKeyIndexes();
    if (!this.indexes.length) {
      return;
    }
    send = {
      data: _.map(this.indexes, (function(_this) {
        return function(index) {
          return _this.current[index];
        };
      })(this)),
      indexes: this.indexes
    };
    send[this.key] = this.lowest;
    pushMore = this.push(send);
    if (!pushMore) {
      this.busy = false;
      return;
    }
    return this.resumeStreams();
  };

  StreamCombine.prototype.handleData = function(index, object) {
    this.streams[index].pause();
    this.current[index] = object;
    return this.evaluatePush();
  };

  StreamCombine.prototype.handleEnd = function(index) {
    this.ended[index] = true;
    this.evaluatePush();
    if (_.every(this.ended)) {
      return this.push(null);
    }
  };

  return StreamCombine;

})(Readable);

module.exports = StreamCombine;
