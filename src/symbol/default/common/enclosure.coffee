intersects = (s1, s2) ->
  a1 = (s1[0] >= s2[0]) and (s1[0] <= s2[1])
  a2 = (s1[1] >= s2[0]) and (s1[1] <= s2[1])
  a3 = (s2[0] >= s1[0]) and (s2[0] <= s1[1])
  a4 = (s2[1] >= s1[0]) and (s2[1] <= s1[1])
  a1 or a2 or a3 or a4

pinTextWidth = (symbol, pin, space, visible) ->
  if visible then (symbol.textWidth(pin.name, 'pin') + space) else 0

module.exports = (symbol, element, icon) ->
  schematic = element.schematic
  settings = symbol.settings

  pitch = symbol.alignToGrid(settings.pitch ? 5)
  pinLength = symbol.alignToGrid(settings.pinLength ? 10)
  pinSpace = schematic.pinSpace ? settings.space.pin
  space = settings.space.default

  left = symbol.left
  right = symbol.right
  top = symbol.top
  bottom = symbol.bottom
  pins = element.pins

  width = pitch * (Math.max(top.length, bottom.length) + 1)
  height = pitch * (Math.max(left.length, right.length) + 1)

  leftX = -width/2
  rightX = width/2
  topY = -height/2
  bottomY = height/2

  rects = []

  if icon?
    rects.push
      x1: -icon.width/2
      y1: -icon.height/2
      x2: icon.width/2
      y2: icon.height/2

  if schematic.pinIcon?
    pinSpace += schematic.pinIcon.width
    pinIconWidth = schematic.pinIcon.width
    pinIconHeight = schematic.pinIcon.height

  # Pins on the top side
  dx = settings.fontSize.pin/2 + space
  y = topY
  topPins = []
  topRects = []
  x = -pitch*(top.length/2 - 0.5)
  for i in top
    if i is '-'
      x += pitch
      continue
    pin = pins[i]
    unless pin? then continue
    pin.x = x
    pin.length = pinLength
    pin.orientation = 'down'
    topPins.push pin

    h = pinTextWidth(symbol, pin, pinSpace, schematic.showPinNames)
    if y > (-h - space) then y = -h - space
    x1 = x - dx
    x2 = x + dx
    # Check whether pin rectangle intersects other rectangles
    for r in rects
      if intersects [x1, x2], [r.x1, r.x2]
        y1 = r.y1 - h - space
        if y > y1 then y = y1 # Make symbol higher
    x += pitch
    topRects.push
      x1: x1,
      y1: 0,
      x2: x2,
      y2: h

  topY = symbol.alignToGrid y, 'floor'

  for r in topRects
    r.y1 += topY
    r.y2 += topY
    rects.push r

  # Pins on the bottom side
  y = bottomY
  bottomPins = []
  bottomRects = []
  x = -pitch*(bottom.length/2 - 0.5)
  for i in bottom
    if i is '-'
      x += pitch
      continue
    pin = pins[i]
    unless pin? then continue
    pin.x = x
    pin.length = pinLength
    pin.orientation = 'up'
    bottomPins.push pin

    h = pinTextWidth(symbol, pin, pinSpace, schematic.showPinNames)
    if y < (h + space) then y = h + space
    x1 = x - dx
    x2 = x + dx
    # Check whether pin rectangle intersects other rectangles
    for r in rects
      if intersects [x1, x2], [r.x1, r.x2]
        y2 = r.y2 + h + space
        if y < y2 then y = y2 # Make symbol higher
    x += pitch
    bottomRects.push
      x1: x1,
      y1: -h,
      x2: x2,
      y2: 0

  bottomY = symbol.alignToGrid y, 'ceil'

  for r in bottomRects
    r.y1 += bottomY
    r.y2 += bottomY
    rects.push r

  # Pins on the left side
  x = leftX
  dy = settings.fontSize.pin/2 + space
  leftPins = []
  leftRects = []
  y = -pitch*(left.length/2 - 0.5)
  for i in left
    if i is '-'
      y += pitch
      continue
    pin = pins[i]
    unless pin? then continue
    pin.y = y
    pin.length = pinLength
    pin.orientation = 'right'
    leftPins.push pin

    w = pinTextWidth(symbol, pin, pinSpace, schematic.showPinNames)
    if x > (-w - space) then x = -w - space
    y1 = y - dy
    y2 = y + dy
    # Check whether pin rectangle intersects other rectangles
    for r in rects
      if intersects [y1, y2], [r.y1, r.y2]
        x1 = r.x1 - w - space
        if x > x1 then x = x1 # Make symbol wider
    y += pitch
    leftRects.push
      x1: 0,
      y1: y1,
      x2: w,
      y2: y2

  leftX = symbol.alignToGrid x, 'floor'

  for r in leftRects
    r.x1 += leftX
    r.x2 += leftX
    rects.push r

  # Pins on the right side
  x = rightX
  rightPins = []
  y = -pitch*(right.length/2 - 0.5)
  for i in right
    if i is '-'
      y += pitch
      continue
    pin = pins[i]
    unless pin? then continue
    pin.y = y
    pin.length = pinLength
    pin.orientation = 'left'
    rightPins.push pin

    w = pinTextWidth(symbol, pin, pinSpace, schematic.showPinNames)
    if x < (w + space) then x = w + space
    y1 = y - dy
    y2 = y + dy
    # Check whether pin rectangle intersects other rectangles
    for r in rects
      if intersects [y1, y2], [r.y1, r.y2]
        x2 = r.x2 + w + space
        if x < x2 then x = x2 # Make symbol wider
    y += pitch

  rightX = symbol.alignToGrid x, 'ceil'

  # Update box size
  width = rightX - leftX
  height = bottomY - topY

  width = symbol.alignToGrid width, 'ceil'
  height = symbol.alignToGrid height, 'ceil'

  # Box
  symbol
    .lineWidth settings.lineWidth.thick
    .rectangle 0, 0, width, height, settings.fill

  if icon? then icon.draw -leftX, -topY

  # Pins
  for pin in leftPins
    pin.x = -pinLength
    pin.y -= topY
    pin.space = pinSpace
    symbol.pin pin
    schematic.pinIcon?.draw pin.x + pinLength + pinIconWidth/2, pin.y

  for pin in rightPins
    pin.x = width + pinLength
    pin.y -= topY
    pin.space = pinSpace
    symbol.pin pin
    schematic.pinIcon?.draw pin.x - pinLength - pinIconWidth/2, pin.y

  for pin in topPins
    pin.x -= leftX
    pin.y = -pinLength
    pin.space = pinSpace
    symbol.pin pin
    schematic.pinIcon?.draw pin.x, pin.y + pinLength + pinIconHeight/2

  for pin in bottomPins
    pin.x -= leftX
    pin.y = height + pinLength
    pin.space = pinSpace
    symbol.pin pin
    schematic.pinIcon?.draw pin.x, pin.y - pinLength - pinIconHeight/2

  # Attributes
  attributeSpace = settings.space.attribute
  if element.parts? # Multi-part
    symbol
      .attribute 'refDes',
        x: 0
        y: -settings.fontSize.name - 2*attributeSpace
        halign: 'left'
        valign: 'bottom'
      .attribute 'name',
        x: 0
        y: -attributeSpace
        halign: 'left'
        valign: 'bottom'
  else
    if topPins.length > 0
      symbol
        .attribute 'refDes',
          x: 0
          y: -attributeSpace
          halign: 'left'
          valign: 'bottom'
    else
      symbol
        .attribute 'refDes',
          x: width/2
          y: -attributeSpace
          halign: 'center'
          valign: 'bottom'

    if bottomPins.length > 0
      symbol
        .attribute 'name',
          x: bottomPins[bottomPins.length - 1].x + attributeSpace
          y: height + attributeSpace
          halign: 'left'
          valign: 'top'
    else
      symbol
        .attribute 'name',
          x: width/2
          y: height + attributeSpace
          halign: 'center'
          valign: 'top'
