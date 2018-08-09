-- ftml - font test markup language
-- copyright 2016-2018 SIL International and released under the MIT/X11 license

local ftml = SILE.baseClass { id = "ftml" }

SILE.require("packages/counters")
SILE.require("packages/bidi")
SILE.require("packages/rules")

SU.debug("ftml", "font list loaded into SILE.scratch.ftmlfontlist: " .. SILE.scratch.ftmlfontlist)
-- Note: can't use the normal SILE.scratch.ftml.xxx namespace
-- because, when the command line is being read, the ftml class
-- hasn't yet been processed, so SILE.scratch.ftml has not yet been created.

SILE.scratch.ftml = {}
SILE.scratch.ftml = { head = {}, fontlist = {}, testgroup = {}, spaceused = {}, saveY = {} }  -- ### eventually revise

ftml:declareFrame("content", {
    left = "5%pw",
    right = "95%pw",
    top = "5%ph",
    bottom = "95%ph"
  })
ftml.pageTemplate.firstContentFrame = ftml.pageTemplate.frames["content"]

function ftml:init()
  SU.debug("ftml","entering ftml:init")
  SILE.settings.set("document.parindent",SILE.nodefactory.zeroGlue)
  SILE.settings.set("document.baselineskip",SILE.nodefactory.newVglue("1.2em"))
  SILE.settings.set("document.parskip",SILE.nodefactory.newVglue("0pt"))
  SILE.settings.set("document.spaceskip")
  SU.debug("ftml",colinfo)
  if colinfo then
    for i = 1,#colinfo do
      coltypesetter[i]:init(SILE.getFrame(colinfo[i].frame))
    end
  end
  SU.debug("ftml","exiting ftml:init")
  return SILE.baseClass:init()
end

function ftml:newPage()
  SILE.baseClass:newPage()
  local currenttypesetter = SILE.typesetter
  for i = 1, #colinfo do
    if coltypesetter[i] ~= currenttypesetter then
      coltypesetter:initFrame(SILE.getFrame(colinfo[i].frame))
    end
  end
  SILE.typesetter = currenttypesetter
end

function ftml:endPage()
  SU.debug("ftml", "entering endPage")
  local currenttypesetter = SILE.typesetter
  for c = 1, #colinfo do
    local thispage = {}
    local t = coltypesetter[c]
    for i = 1, #t.state.outputQueue do
      thispage[i] = table.remove(t.state.outputQueue, 1)
    end
    SU.debug("ftml", tostring(#thispage))
    SU.debug("ftml", tostring(#t.state.outputQueue))
    t:outputLinesToPage(thispage)
  end
  SILE.typesetter = currenttypesetter
  return SILE.baseClass:endPage()
end

function ftml:finish()
  local currenttypesetter = SILE.typesetter
  for i = 1, #colinfo do
    if coltypesetter[i] ~= currenttypesetter then
      table.insert(coltypesetter[i].state.outputQueue, SILE.nodefactory.vfillGlue)
      coltypesetter[i]:chuck()
    end
  end
  SILE.baseClass:finish()
end

-- copied from plain class
SILE.registerCommand("vfill", function (options, content)
  SILE.typesetter:leaveHmode()
  SILE.typesetter:pushExplicitVglue(SILE.nodefactory.vfillGlue)
end, "Add huge vertical glue")

local function parsefontname(s)
  local num = 0
  s,num = string.gsub(s,"%s*Regular%s*$","")
  local reg = num == 1
  s,num = string.gsub(s,"%s*Italic%s*$","")
  local italic = num == 1
  s,num = string.gsub(s,"%s*Bold%s*$","")
  local bold = num == 1
  s,num = string.gsub(s,"%s+$","")
  s,num = string.gsub(s,"^%s+","")
  return s, reg, bold, italic
end

if SILE.scratch.ftmlfontlist and #SILE.scratch.ftmlfontlist > 0 then -- obtain font info from command line
  SILE.scratch.ftml.numfonts = #SILE.scratch.ftmlfontlist
  for i=1,SILE.scratch.ftml.numfonts do
    local fontspec = SILE.scratch.ftmlfontlist[i]
    SILE.scratch.ftml.fontlist[i] = {}
    if string.find(fontspec,"%.") then -- if . in string, must be filename
      SILE.scratch.ftml.fontlist[i].filename = fontspec
      SILE.scratch.ftml.fontlist[i].family = nil
    else -- must be font family name +- Bold +- Italic +- Regular
      local f, regular, bold, italic = parsefontname(fontspec)
      SILE.scratch.ftml.fontlist[i].filename = nil
      SILE.scratch.ftml.fontlist[i].family = f
      SILE.scratch.ftml.fontlist[i].bold = bold
      SILE.scratch.ftml.fontlist[i].italic = italic
      if (bold or italic) and regular then
        SU.debug("ftml", "Warning: Font specification has Regular as well as Bold or Italic")
        SILE.scratch.ftml.fontlist[i].bold = nil
        SILE.scratch.ftml.fontlist[i].italic = nil
      end
    end
  end
else -- get font info from fontsrc element (which hasn't yet been read)
  SILE.scratch.ftml.numfonts = 0 -- indicates that fontsrc needs to be used
  SU.debug("ftml", "Warning: No valid font specification on command line, fallback to fontsrc element")
end

local function getfeats(fs)
  flag = 0
  if fs then flag = 1 end
  featuretable = {}
  while(flag and #fs > 0) do
    fs, flag = string.gsub(fs, "^%s*'([^']+)'%s*(%d+)%s*,?%s*", 
    function(f,v) 
      if v == 0 then
        pref = "-"
        suff = ""
      else
        pref = "+"
        suff = "=" .. tostring(v)
      end
      table.insert(featuretable, pref .. f .. suff)
      return ""
    end)
  end
  return table.concat(featuretable, ",")
end

SILE.registerCommand("style", function (options, content)
  local name = options["name"]
  local feats = options["feats"]
  if feats then
    feats = getfeats(feats)
  else
    feats = ""
  end
  local lang = options["lang"] or ""
  SU.debug("ftml", "style element found: " .. name .. "/" .. feats .. "/" .. lang)
-- if name and name ~= "" then
  SILE.scratch.ftml.head.styles[name] = {feats = feats, lang = lang}
-- else
-- raise error/warning if name is missing
-- end
end)

SILE.registerCommand("head", function (options, content)
  local availablewidth = 90
  local marginwidth = 5
  local gutterwidth = 1
  local topmargin = 6
  local bottommargin = 90

  local head_comment = SILE.findInTree(content, "comment")
  if head_comment then SILE.scratch.ftml.head.comment = head_comment[1] end
  local head_fontscale = SILE.findInTree(content, "fontscale")
  if head_fontscale then 
    SILE.scratch.ftml.head.fontscale = head_fontscale[1]
  else
    SILE.scratch.ftml.head.fontscale = "100"
  end
  SILE.scratch.ftml.fontsize = math.floor(12*tonumber(SILE.scratch.ftml.head.fontscale)/50)/2.0
  local head_fontsrc = SILE.findInTree(content, "fontsrc")
  if head_fontsrc then SILE.scratch.ftml.head.fontsrc = head_fontsrc[1] end
  local head_title = SILE.findInTree(content, "title")
  if head_title then SILE.scratch.ftml.head.title = head_title[1] end
  local head_styles = SILE.findInTree(content, "styles")
  if head_styles then
    SILE.scratch.ftml.head.styles = {}
    SILE.process(head_styles) -- process the "style" elements contained in this "styles" element
  end
  local head_widths = SILE.findInTree(content, "widths")
  SILE.scratch.ftml.head.widths = {}
  if head_widths then -- perhaps else clause to set defaults if no widths element?
    for k,v in pairs(head_widths["attr"]) do
      if type(k) ~= "number" then
        SILE.scratch.ftml.head.widths[k] = v
      end
    end
  end

--[[
At this point 
  SILE.scratch.ftml.head.comment      contains comment text
  SILE.scratch.ftml.head.fontscale    contains fontscale text
  SILE.scratch.ftml.head.fontsrc      contains fontsrc text
  SILE.scratch.ftml.head.title        contains title text
  SILE.scratch.ftml.head.widths       contains a table with any or all of: .table, .label, .string, .stylename, .comment
  SILE.scratch.ftml.head.styles       contains a table with style info, indexed by stylename, which returns a table with keys "feats" and/or "lang"
--]]
-- begin debugging info
  if SILE.scratch.ftml.head.comment then SU.debug("ftml", "comment: " .. SILE.scratch.ftml.head.comment) end
  if SILE.scratch.ftml.head.fontscale then SU.debug("ftml", "fontscale: " .. SILE.scratch.ftml.head.fontscale) end
  if SILE.scratch.ftml.head.fontsrc then SU.debug("ftml", "fontsrc: " .. SILE.scratch.ftml.head.fontsrc) end
  if SILE.scratch.ftml.head.title then SU.debug("ftml", "title: " .. SILE.scratch.ftml.head.title) end
  if SILE.scratch.ftml.head.widths then 
    for k,v in pairs(SILE.scratch.ftml.head.widths) do
      SU.debug("ftml", k .. "=" .. v )
    end
  end
-- end debugging info

  if SILE.scratch.ftml.numfonts == 0 then -- get font from SILE.scratch.ftml.head.fontsrc
    SILE.scratch.ftml.numfonts = 1
    local fontspec = string.match(SILE.scratch.ftml.head.fontsrc,"^%s*local%((.+)%)")
    -- the above doesn't deal with possibility that fontspec has opening/closing quote/apostrophe pair inside parentheses
    -- for example: local("Gentium")
    if fontspec then
      local f, regular, bold, italic = parsefontname(fontspec)
      SILE.scratch.ftml.fontlist[1] = {}
      SILE.scratch.ftml.fontlist[1].filename = nil
      SILE.scratch.ftml.fontlist[1].family = f
      SILE.scratch.ftml.fontlist[1].bold = bold
      SILE.scratch.ftml.fontlist[1].italic = italic
      if (bold or italic) and regular then
        SU.debug("ftml", "Warning: Font specification has Regular as well as Bold or Italic")
        SILE.scratch.ftml.fontlist[1].bold = nil
        SILE.scratch.ftml.fontlist[1].italic = nil
      end
    else
      fontspec = string.match(SILE.scratch.ftml.head.fontsrc,"^%s*url%((.+)%)")
      if fontspec then
        SILE.scratch.ftml.fontlist[1].filename = fontspec
        SILE.scratch.ftml.fontlist[1].family = nil
      else
        SU.debug("ftml", "No font(s) on command line, nor in fontsrc element: " .. SILE.scratch.ftml.head.fontsrc) 
        SU.error("No valid font specification in fontsrc element")
      end
    end
  end

  local tablewidthstr = SILE.scratch.ftml.head.widths.table or "100%"
  local labelwidthstr = SILE.scratch.ftml.head.widths.label or "0%"
  local stringwidthstr = SILE.scratch.ftml.head.widths.string or "50%"
  local stylenamewidthstr = SILE.scratch.ftml.head.widths.stylename or "0%"
  local commentwidthstr = SILE.scratch.ftml.head.widths.comment or "0%"
  local tablewidth = string.match(tablewidthstr, "%d+")
  local labelwidth = string.match(labelwidthstr, "%d+")
  local stringwidth = string.match(stringwidthstr, "%d+")
  local stylenamewidth = string.match(stylenamewidthstr, "%d+")
  local commentwidth = string.match(commentwidthstr, "%d+")
  local totalwidth = labelwidth + (stringwidth * SILE.scratch.ftml.numfonts) + stylenamewidth + commentwidth
  tablewidth = math.min(tablewidth, 100)
  labelwidth = math.floor((tablewidth/100)*availablewidth*(labelwidth/totalwidth))
  stringwidth = math.floor((tablewidth/100)*availablewidth*(stringwidth/totalwidth))
  stylenamewidth = math.floor((tablewidth/100)*availablewidth*(stylenamewidth/totalwidth))
  commentwidth = math.floor((tablewidth/100)*availablewidth*(commentwidth/totalwidth))
  SU.debug("ftml", tostring(tablewidth))
  SU.debug("ftml", tostring(labelwidth))
  SU.debug("ftml", tostring(stringwidth))
  SU.debug("ftml", tostring(stylenamewidth))
  SU.debug("ftml", tostring(commentwidth))
  if SILE.scratch.ftml.head.styles then 
    for k,v in pairs(SILE.scratch.ftml.head.styles) do
      SU.debug("ftml", k .. "=" .. v)
    end
  end

  local leftmargin = 0
  local rightmargin = marginwidth - gutterwidth
  local colcount = 0
  colinfo = {}
  colindex = {}
  coltypesetter = {}
  if labelwidth > 0 then
    colcount = colcount + 1
    colindex["label"] = colcount
    leftmargin = rightmargin + gutterwidth
    rightmargin = leftmargin + labelwidth
    table.insert(colinfo, {name = "label", frame = "col"..tostring(colcount), left = leftmargin, right = rightmargin, top = topmargin, bottom = bottommargin} )
  end
  if stringwidth > 0 then -- but really shouldn't it be an error if stringwidth is zero?
    for fontcount = 1, SILE.scratch.ftml.numfonts do
      colcount = colcount + 1
      local stringindex = "string" ..tostring(fontcount)
      colindex[stringindex] = colcount
      leftmargin = rightmargin + gutterwidth
      rightmargin = leftmargin + stringwidth
      table.insert(colinfo, {name = stringindex, frame = "col"..tostring(colcount), left = leftmargin, right = rightmargin, top = topmargin, bottom = bottommargin} )
    end
  end
  if stylenamewidth > 0 then
    colcount = colcount + 1
    colindex["stylename"] = colcount
    leftmargin = rightmargin + gutterwidth
    rightmargin = leftmargin + stylenamewidth
    table.insert(colinfo, {name = "stylename", frame = "col"..tostring(colcount), left = leftmargin, right = rightmargin, top = topmargin, bottom = bottommargin} )
  end
  if commentwidth > 0 then
    colcount = colcount + 1
    colindex["comment"] = colcount
    leftmargin = rightmargin + gutterwidth
    rightmargin = leftmargin + commentwidth
    table.insert(colinfo, {name = "comment", frame = "col"..tostring(colcount), left = leftmargin, right = rightmargin, top = topmargin, bottom = bottommargin} )
  end

  SILE.scratch.ftml.framelist = {}
  for k,v in pairs(colinfo) do
    ftml:declareFrame(v.frame, {left=tostring(v.left).."%pw", right=tostring(v.right).."%pw", top=tostring(v.top).."%ph", bottom=tostring(v.bottom).."%ph"} )
    SILE.scratch.ftml.framelist[v.name] = v.frame
    coltypesetter[k] = SILE.typesetter {}
    coltypesetter[k].id = v.name
    coltypesetter[k]:init(SILE.getFrame(v.frame))
    coltypesetter[k].pageBuilder = function () end
  end
--[[
  SILE.call("showframe", {id="all"})
--]]
  for i,j in pairs(SILE.scratch.ftml.framelist) do SU.debug("ftml", i .. "=" .. j) end
  SU.debug("ftml", "framelist start")
  SU.debug("ftml", SILE.scratch.ftml.framelist)
  SU.debug("ftml", "framelist end")

end)


SILE.registerCommand("testgroup", function (options, content)
  SU.debug("ftml", "entering testgroup")
  SILE.scratch.ftml.testgroup = {}
  -- get label and background attributes from testgroup element; get comment subelement
  local testgroup_label = options["label"]
  local testgroup_background = options["background"] -- need to store for use at test level
  local testgroup_comment = SILE.findInTree(content, "comment")
  if testgroup_comment then testgroup_comment = testgroup_comment[1] end
  -- does comment element need to be removed from content to avoid being reprocessed?
  SU.debug("ftml", testgroup_label .. " " .. testgroup_background .. " " .. testgroup_comment)
  -- Need to output testgroup_label and testgroup_comment
  SILE.process(content)
  SU.debug("ftml", "exiting testgroup")
end)

SILE.registerCommand("test", function (options, content)
  SU.debug("ftml", "entering test")
  local row = #(SILE.scratch.ftml.testgroup)+1 -- add a row for each test element
  SILE.scratch.ftml.testgroup[row] = {}
--  SILE.scratch.ftml.line = {}
  local test_label = options["label"]
  local test_background = options["background"] -- or testgroup_background
  local test_rtl = options["rtl"]
  local test_stylename = options["stylename"]
  SU.debug('ftml', 'test_label=' .. test_label)
  SU.debug('ftml', 'test_background=' .. test_background)
  SU.debug('ftml', 'test_rtl=' .. test_rtl)
  SU.debug('ftml', 'test_stylename=' .. test_stylename)
  local test_comment_element = SILE.findInTree(content, "comment")
--  if test_comment_element then test_comment = test_comment_element[1] else test_comment = nil end
  SU.debug('ftml','test_comment=' .. test_comment)
  SILE.scratch.ftml.testgroup[row].label =      test_label      or ""
  SILE.scratch.ftml.testgroup[row].background = test_background or ""
--  SILE.scratch.ftml.testgroup[row].rtl =        test_rtl        or ""
  if test_rtl == "True" then
    SILE.scratch.ftml.testgroup[row].rtl = "RTL"
  else
    SILE.scratch.ftml.testgroup[row].rtl = "LTR"
  end
  SU.debug('ftml', '.rtl=' .. SILE.scratch.ftml.testgroup[row].rtl)
  SILE.scratch.ftml.testgroup[row].stylename =  test_stylename  or ""
  SILE.scratch.ftml.testgroup[row].comment =    test_comment    or ""
  SILE.process(content)
--  SU.debug('ftml', 'string=' .. SILE.scratch.ftml.testgroup[row].string)
--  SILE.repl()
--  SILE.call("col-label")
  SU.debug("ftml", "exiting test")
end)

local function expandslashu(s) -- given string s, expand any \uxxxx, \uxxxxx, \uxxxxxx characters and return new string
  local t = {}
  local i = 0
  local j = 0
  while true do
    i, j = string.find(s,"\\u%x%x%x%x%x?%x?",i+1)
    if i == nil then break end
    table.insert(t, {i,j})
  end
  if #t then -- if #t non-zero, then at least one \uxxxx sequence found
    news = ""
    startspan = 1
    for _, x in ipairs(t) do
      i = x[1]
      j = x[2]
      endspan = i-1
      news = news .. string.sub(s,startspan,endspan) .. SU.utf8char(tonumber("0x" .. string.sub(s,i+2,j)))
      startspan = j+1
    end
    news = news .. string.sub(s,startspan,-1)
    s = news
  end
  return s
end

SILE.registerCommand("string", function (options, content)
  SU.debug("ftml", "entering string")
  SILE.scratch.ftml.spaceused = {}
  local any_em_elements = (SILE.findInTree(content, 'em') ~= nil)
  SU.debug("ftml", "<em> elements found: " .. tostring(any_em_elements))
  SU.debug("ftml", "content: " .. content)
  SILE.scratch.ftml.spaceusedmax = 0
  SILE.scratch.ftml.stylename = SILE.scratch.ftml.testgroup[#(SILE.scratch.ftml.testgroup)].stylename
  SU.debug("ftml", "stylename: " .. SILE.scratch.ftml.stylename)
  --SILE.repl()
  if SILE.scratch.ftml.stylename and SILE.scratch.ftml.stylename ~= "" then
    SU.debug("ftml", SILE.scratch.ftml.head.styles[SILE.scratch.ftml.stylename].lang)
    SU.debug("ftml", SILE.scratch.ftml.head.styles[SILE.scratch.ftml.stylename].feats)
  end
  for c = 1,#colinfo do
    SILE.typesetter = coltypesetter[c]
    -- reset all columns to defaults
    SILE.settings.set("font.family", "Arial")
    SILE.settings.set("font.filename", "")
    SILE.settings.set("font.weight", 400)
    SILE.settings.set("font.style", "normal")
    SILE.settings.set("font.size", 8)
    SILE.settings.set("font.direction", "LTR")
    SILE.settings.set("font.features", "")
    SILE.settings.set("document.language", "en-US")
    local colname = colinfo[c].name -- label, stringX, stylename, comment
    if not string.find(colname, "string") then -- if colname doesn't contain "string"
      SILE.settings.set("linespacing.method", "fixed")
      SILE.settings.set("linespacing.fixed.baselinedistance", SILE.length.new({length=12, stretch=0, shrink=0}))
      local outputtext = SILE.scratch.ftml.testgroup[#(SILE.scratch.ftml.testgroup)][colname]
      if outputtext == "" then outputtext = SU.utf8char(160) end -- U+00A0 to hold place, otherwise Vglue disappears and spacing is off
      -- or try using SILE.typesetter:pushExplicitVglue
      SILE.typesetter:typeset(outputtext)
      -- SILE.typesetter:typeset(SILE.scratch.ftml.testgroup[#(SILE.scratch.ftml.testgroup)][colname])
    else -- string
      local fontnumstring,_ = string.gsub(colname,"string","")
      local fontnum = tonumber(fontnumstring)
      if SILE.scratch.ftml.fontlist[fontnum].filename then
        SILE.settings.set("font.filename", SILE.scratch.ftml.fontlist[fontnum].filename)
      elseif SILE.scratch.ftml.fontlist[fontnum].family then
        SILE.settings.set("font.family", SILE.scratch.ftml.fontlist[fontnum].family)
        if SILE.scratch.ftml.fontlist[fontnum].bold then
          SILE.settings.set("font.weight", 700)
        else
          SILE.settings.set("font.weight", 400)
        end
        if SILE.scratch.ftml.fontlist[fontnum].italic then
          SILE.settings.set("font.style", "italic")
        else
          SILE.settings.set("font.style", "normal")
        end
      end
      SILE.settings.set("font.size", SILE.scratch.ftml.fontsize)
      SILE.settings.set("linespacing.method", "fixed")
      SILE.settings.set("linespacing.fixed.baselinedistance", SILE.length.new({length=1.5*SILE.scratch.ftml.fontsize, stretch=0, shrink=0}))
      SILE.settings.set("font.direction", SILE.scratch.ftml.testgroup[#(SILE.scratch.ftml.testgroup)].rtl)
      SU.debug("ftml", SILE.scratch.ftml.stylename)
      if SILE.scratch.ftml.stylename and SILE.scratch.ftml.stylename ~= "" then
        SILE.settings.set("font.features", SILE.scratch.ftml.head.styles[SILE.scratch.ftml.stylename].feats)
        SILE.settings.set("document.language", SILE.scratch.ftml.head.styles[SILE.scratch.ftml.stylename].lang)
        SU.debug("ftml", SILE.scratch.ftml.head.styles[SILE.scratch.ftml.stylename].feats)
        SU.debug("ftml", SILE.settings.get("font.features"))
        SU.debug("ftml", SILE.scratch.ftml.head.styles[SILE.scratch.ftml.stylename].lang)
      end
      -- NOT supported: background color from SILE.scratch.ftml.testgroup[#(SILE.scratch.ftml.testgroup)].background
      if any_em_elements then
        for _, x in ipairs(content) do
          if type(x) == 'string' then
            -- output x in grey (with \u conv)
            SILE.call("color", {color='grey'}, {expandslashu(x)})
          elseif type(x) == 'table' and x.tag == 'em' then
            -- output x[1] normally (with \u conv)
            SILE.typesetter:typeset(expandslashu(x[1]))
          else
            -- ignore unknown stuff (or raise error)
          end
        end
      else -- output content[1] normally (with \u conversion)
        SILE.typesetter:typeset(expandslashu(content[1]))
      end
    end
    SILE.typesetter:leaveHmode()
    SU.debug("ftml", "just printed " .. colname)

    tempspace = SILE.pagebuilder.collateVboxes(SILE.typesetter.state.outputQueue).height
    if type(tempspace) == "table" then
      -- for k,v in pairs(tempspace) do SU.debug("ftml", k .. " " .. v .. " " .. tempspace[k]) end
      SILE.scratch.ftml.spaceused[c] = tempspace.length
    else
      SILE.scratch.ftml.spaceused[c] = tempspace
    end
--    SU.debug("ftml", type(SILE.scratch.ftml.spaceused[c]))
--    SU.debug("ftml", SILE.scratch.ftml.spaceused[c])
    if SILE.scratch.ftml.spaceused[c] > SILE.scratch.ftml.spaceusedmax then
      SILE.scratch.ftml.spaceusedmax = SILE.scratch.ftml.spaceused[c]
    end
  end
  SU.debug("ftml", SILE.scratch.ftml.spaceused)
  SILE.scratch.ftml.spaceusedmax = SILE.scratch.ftml.spaceusedmax + 0.4
--  SILE.scratch.ftml.spaceusedmax = SILE.scratch.ftml.spaceusedmax + 300 -- temp replacement for above (to make large row height)
  SU.debug("ftml", tostring(SILE.scratch.ftml.spaceusedmax))
  SU.debug("ftml", tostring(type(SILE.scratch.ftml.spaceusedmax)))

  for c = 1,#colinfo do
    SILE.typesetter = coltypesetter[c]
    SU.debug("ftml", tostring(c) .. ": " .. SILE.scratch.ftml.spaceused[c])
    SILE.typesetter:pushVglue({height=SILE.length.new({length=SILE.scratch.ftml.spaceusedmax - SILE.scratch.ftml.spaceused[c], stretch = 0, shrink = 0}) })
    SILE.typesetter:leaveHmode()
    SILE.call("hrule", {width=SILE.toPoints((colinfo[c].right - colinfo[c].left),"%pw"), height=0.5})
    SILE.typesetter:leaveHmode()
  end
  local pagebreakneeded = false  
  for c = 1,#colinfo do
    SU.debug("ftml", tostring(c))
    vlist = std.table.clone(coltypesetter[c].state.outputQueue)
    tar = coltypesetter[c]:pageTarget()
    SU.debug("ftml", vlist)
    SU.debug("ftml", tar)
    if SILE.pagebuilder.findBestBreak( {vboxlist=vlist, target=tar } ) then
      pagebreakneeded = true -- break if true?
    end
  end
  if pagebreakneeded then
    SU.debug("ftml","pagebreakneeded is true!")
    -- what is needed to output current page and start a new one?
  end
  SU.debug("ftml", "exiting string")
end)

return ftml
