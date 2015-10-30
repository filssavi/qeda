QedaSymbol = require './qeda-symbol'
QedaPattern = require './qeda-pattern'

#
# Class for electronic component
#
class QedaElement
  #
  # Constructor
  #
  constructor: (@library, definition) ->
    @mergeObjects this, definition

    @refDes = 'REF' # Should be overriden in element handler
    @symbols = [] # Array of symbols (one for single part or several for multi-part)
    @patterns = [] # Array of possible land patterns

    @pins = [] # Array of pin objects
    @pinGroups = [] # Array of pin groups

    # Grid-array row letters
    @_letters = ['', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'R', 'T', 'U', 'V', 'W', 'Y']
    last = @_letters.length - 1
    for i in [1..last]
      for j in [i..last]
        @_letters.push @_letters[i] + @_letters[j]

    # Create pin objects
    for pinName of @pinout
      pinNumbers = @_pinNumbers @pinout[pinName]
      @pinGroups[pinName] = pinNumbers
      for pinNumber in pinNumbers
        unless @pins[pinNumber]?
          @pins[pinNumber] = @_pinObj pinNumber, pinName
        else
          @pins[pinNumber].name += '/' + pinName

    # Forming groups
    for key, value of @groups
      @pinGroups[key] = @_concatenateGroups value

    if @parts? # Multi-part element
      for name, part of @parts
        @symbols.push new QedaSymbol(this, name, part)
    else # Single-part element
      part = []
      if @groups?
        part.push key for key of @groups
      else
        part.push key for key of @pinout
      @symbols.push new QedaSymbol(this, @name, part)

    # Create land patterns
    unless Array.isArray @housing
      @housing = [@housing]
    for h in @housing
      if typeof h is 'object'
        @addPattern h
      else if typeof h is 'string'
        if @[h]? then @addPattern @[h]

  #
  # Add pattern
  #
  addPattern: (housing) ->
    unless housing.pattern?
      return
    @patterns.push new QedaPattern(this, housing)

  #
  # Calculate actual layouts
  #
  calculate: (gridSize) ->
    @_calculated ?= false
    if @_calculated then return

    # Apply elemend wide handler
    handler = require "./element/#{@library.elementStyle}"
    handler this

    # Symbols processing
    for symbol in @symbols
      # Apply symbol handler
      if @schematic?.symbol?
        for def in @library.symbolDefs
          cap = def.regexp.exec @schematic.symbol
          if cap
            handler = require "./symbol/#{@library.symbolStyle}/#{def.handler}"
            handler(symbol, cap[1..]...)
      # Calculate symbol dimensions
      symbol.calculate gridSize

    # Pattern processing
    for pattern in @patterns
      if pattern.housing?.outline?
        outline = pattern.housing.outline
        for def in @library.outlineDefs
          cap = def.regexp.exec outline
          if cap
            handler = require "./outline/#{def.handler}"
            handler(pattern.housing, cap[1..]...)
      @_convertDimensions pattern.housing
      for def in @library.patternDefs
        cap = def.regexp.exec pattern.name
        if cap
          handler = require "./pattern/#{@library.patternStyle}/#{def.handler}"
          handler(pattern, cap[1..]...)
    @_calculated = true

  #
  # Check whether number is float
  #
  isFloat: (n) ->
    Number(n) and (n % 1 isnt 0)

  #
  # Merge two objects
  #
  mergeObjects: (dest, src) ->
    for k, v of src
      if typeof v is 'object' and dest.hasOwnProperty k
        @mergeObjects dest[k], v
      else
        dest[k] = v

  _concatenateGroups: (groups) ->
    result = []
    unless Array.isArray groups then groups = [groups]
    for group in groups
      pinGroup = @pinGroups[group]
      if pinGroup? then result = result.concat pinGroup
    result

  #
  # Make dimensions more convenient
  #
  _convertDimensions: (housing) ->
    for key, value of housing
      if Array.isArray(value) and value.length > 0
        min = value[0]
        max = if value.length > 1 then value[1] else min
        nom = (max + min) / 2
        tol = max - min
        housing[key] = { min: min,  max: max,  nom: nom, tol: tol }

  #
  # Convert pin numbers definition to array
  #
  _pinNumbers: (inputs) ->
    numbers = []
    unless Array.isArray inputs then inputs = [inputs]
    for input in inputs
      if typeof input is 'number'
        numbers.push input.toString()
      else if typeof input is 'string'
        input = input.replace /\s+/g, ''
        subs = input.split ','
        for sub in subs
          cap = /([A-Z]*)(\d+)\.{2,3}([A-Z]*)(\d+)/.exec sub
          unless cap
            numbers.push sub
          else
            for i in [@_letters.indexOf(cap[1])..@_letters.indexOf(cap[3])] # TODO: Improve
              for j in [cap[2]..cap[4]]
                numbers.push @_letters[i] + j
    numbers

  #
  # Generate pin object
  #
  _pinObj: (number, name) ->
    obj =
      name: name
      number: number

    if @properties?
      props = ['bidir', 'ground', 'in', 'inverted', 'out', 'passive', 'power']
      for prop in props
        if @properties[prop]?
          pins = if Array.isArray @properties[prop] then @properties[prop] else [@properties[prop]]
          obj[prop] = (pins.indexOf(name) isnt -1)
    obj

module.exports = QedaElement
