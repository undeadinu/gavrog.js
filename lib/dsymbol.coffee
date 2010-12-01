if typeof(require) != 'undefined'
  require.paths.unshift("#{__dirname}/../../pazy.js/lib")
  pazy = require('indexed')

Set = pazy.IntSet
Map = pazy.IntMap


class DSymbol
  # -- the constructor receives the dimension and an initial set of elements

  constructor: (dimension, elms) ->
    @_dim  = dimension
    @_elms = (new Set()).with(elms...)
    @_idcs = (new Set()).with([0..dimension]...)
    @_ops  = (new Map() for i in [0..dimension])
    @_degs = (new Map() for i in [0...dimension])

  # -- the following six methods implement the common interface for
  #    all Delaney symbol classes.

  dimension: -> @_dim
  indices:   -> @_idcs
  size:      -> @_elms.size
  elements:  -> @_elms

  s: (i)     -> (D) => @_ops[i].get(D)

  m: (i, j)  ->
    switch j
      when i + 1 then (D) => @_degs[i].get(D)
      when i - 1 then (D) => @_degs[j].get(D)
      when i     then (D) -> 1
      else            (D) -> 2

  # -- some private helper methods

  create = (dimension, elements, indices, operations, degrees) ->
    ds = new DSymbol(dimension)
    ds._elms = elements
    ds._idcs = indices
    ds._ops  = operations
    ds._degs = degrees
    ds

  arrayWith = (a, i, x) -> (if j == i then x else a[j]) for j in [0...a.length]

  # -- the following methods will eventually go into a mix-in

  orbit: (i, j, D) ->
    symbol = this
    fixed = (x, fallback) -> if x? then x else fallback
    {
      each: (func) ->
        E = D
        loop
          for k in [i, j]
            func(E)
            E = fixed(symbol.s(k)(E), E)
          break if E == D
    }

  # -- the following methods are used to build DSymbols incrementally

  with_elements: (args...) ->
    create(@_dim, @_elms.with(args...), @_idcs, @_ops, @_degs)

  without_elements: (args...) ->
    create(@_dim, @_elms.without(args...), @_idcs, @_ops, @_degs)

  with_gluings: (i) ->
    (args...) =>
      [elms, op] = [@_elms, @_ops[i]]
      for spec in args
        [D, E] = [spec[0], if spec.length < 2 then spec[0] else spec[1]]
        [elms, op] = [elms.with(D), op.with([D, E])] if D?
        [elms, op] = [elms.with(E), op.with([E, D])] if E?
      create(@_dim, elms, @_idcs, arrayWith(@_ops, i, op), @_degs)

  without_gluings: (i) ->
    (args...) =>
      op = @_ops[i]
      for D in args
        op = op.without(D, op.get(D))
      create(@_dim, @_elms, @_idcs, arrayWith(@_ops, i, op), @_degs)

  with_degrees: (i) ->
    (args...) =>
      m = @_degs[i]
      for [D, val] in args when D? and @_elms.contains(D)
        @orbit(i, i + 1, D).each (E) -> m = m.with([E, val])
      create(@_dim, @_elms, @_idcs, @_ops, arrayWith(@_degs, i, m))

  without_degrees: (i) ->
    (args...) =>
      m = @_degs[i]
      for D in args when D? and @_elms.contains(D)
        @orbit(i, i + 1, D).each (E) -> m = m.without(E)
      create(@_dim, @_elms, @_idcs, @_ops, arrayWith(@_degs, i, m))


## -- Test code --

puts = require('sys').puts

ds = new DSymbol(2, [1..3]).
       with_gluings(0)([1], [2], [3]).
       with_gluings(1)([1,2], [3]).
       with_gluings(2)([1], [2,3]).
       with_degrees(0)([1,8], [3,4]).
       with_degrees(1)([1,3])

puts "Size      = #{ds.size()}"
puts "Dimension = #{ds.dimension()}"
puts "Elements  = #{ds.elements().toArray()}"
puts "Indices   = #{ds.indices().toArray()}"

puts ""
ds.indices().each (i) ->
  ds.elements().each (D) ->
    puts "s(#{i})(#{D}) = #{ds.s(i)(D)}"

ds.indices().without(ds.dimension()).each (i) ->
  ds.elements().each (D) ->
    puts "m(#{i},#{i+1})(#{D}) = #{ds.m(i,i+1)(D)}"

puts ""
puts "After undefining m(0)(1) and s(1)(1) and removing element 3:"
ds = ds.without_degrees(0)(1).without_gluings(1)(1).without_elements(3)

ds.indices().each (i) ->
  ds.elements().each (D) ->
    puts "s(#{i})(#{D}) = #{ds.s(i)(D)}"

ds.indices().without(ds.dimension()).each (i) ->
  ds.elements().each (D) ->
    puts "m(#{i},#{i+1})(#{D}) = #{ds.m(i,i+1)(D)}"

### -- End of test code --
