# stream-combine
Merges chronological time-based streams. 

## Dependencies
The module requires no dependencies, except for running the tests.

## Install
```bash
npm install stream-combine
```

## Usage
-----
Combine three time-serie streams, with common document key `_id` for unix time stamp.

```javascript
async.map([
  "time-series-1"
  "time-series-2"
  "time-series-3"
], (serie, cb) => {
  db.collection(serie, (error, collection) => {
    if error return cb error
    
    stream = collection
      .find _id: $gt: 12
      .sort _id: 1
      .stream()
    
    cb(null, stream)
}, (error, streams) => {
  (new StreamCombine streams, "_id").pipe someCSVStream
})
```

Or in flowing mode, with example of output object structure:
```javascript
(new StreamCombine streams, "_id").on("data", data => {
  console.log data
  // emits objects like
  // {
  //   indexes: [0, 2] 
  //   data:    [ { _id: 6, some-data-from-time-series-1 }, 
  //              { _id: 6, some-data-from-time-series-3 } ]
  // }
  // ...
})
```
where:
 - `_id` is the common time stamp of the next object in chronological order
 - `indexes` is the indexes of the streams that have the current time in common
 - `data` is the actual data of the common time step
