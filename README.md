stream-combine
==============

Merges chronological time-based streams.

Usage
-----
I.e. when you have 3 time serie streams, with common document key `_id` for unix time stamp.

```coffee-script
async.map [
  "time-series-1"
  "time-series-2"
  "time-series-3"
], (serie, cb) ->
  db.collection serie, (error, collection) ->
    return cb error if error
    
    stream = collection
      .find _id: $gt: 12
      .sort _id: 1
      .stream()
    
    cb null, stream
, (error, streams) ->
  (new StreamCombine streams, "_id").pipe someCSVStream
```

Or in flowing mode, with example of output object structure:
```coffee-script
(new StreamCombine streams, "_id").on "data", (data) ->
  console.log data
  # emits objects like
  # {
  #   _id:     6
  #   indexes: [0, 2] 
  #   data:    [ { _id: 6, some-data-from-time-series-1 }, { _id: 6, some-data-from-time-series-3 } ]
  # }
  # ...
```
where:

`_id` is the common time stamp of the next object in chronological order

`indexes` is the indexes of the streams that have the current time in common

`data` is the actual data of the common time step
