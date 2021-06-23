--
--------------------------------------------------------------------------------
--         FILE:  CodStepper.lua
--        USAGE:  As a plugin in the SciTE editor
--  DESCRIPTION:  Enables the use of breakpoints in Scite scripts
-- REQUIREMENTS:  See readme.txt for any configuration tips
--        NOTES:  If you intend on editing this script, I would suggest
--                familiarizing yourself with the various oddities that
--                come with LUA, though the only thing you'll really need
--                to keep in mind while editing this script is that LUA
--                indexing starts from 1, not 0
--       AUTHOR:  Adam Brewer (abrewer)
--        EMAIL:  abrewer@codonics.com
--      COMPANY:  Codonics
--      VERSION:  1.0
--      CREATED:  06/18/21
--         BUGS:  *1) No matter what, saving will always bring you
--                   back to the last breakpoint. This is likely
--                   a side-effect of how we find breakpoints (in
--                   the function GetBreakLines()), probably something
--                   to do with the fact that we use goToPos the way
--                   we do.
--                                                                
--                   * I've made a band-aid fix that simply returns
--                   the caret/cursor to its original position, but
--                   there is still scrolling that happens. Thus is life. 
--------------------------------------------------------------------------------
-- CONFIGURABLES
local PERFORMANCE_MODE = false -- Speeds up SciTE performance by executing some 
--                                things less frequently
local DEBUG = false
local RSC_DIR = 'C:\\Program Files (x86)\\AutoIt3\\SciTE\\lua\\CodStepper'
local BREAKMARK = ";<bkpt>"
local MARKER_NUMBER = 10
local MARKER_COLOR = {R=255, G=11, B=80, A=255}

--------------------------------------------------------------------------------
-- PROGRAM
local Buttons = {
   Run=1,
   Stop=2,
   ForceReplace=3,
   ForceRestore=4,
   BkptAtCursor=6,
   RemoveAllBkpts=7
}
local ButtonsInv = {}
for k,v in pairs(Buttons) do ButtonsInv[v]=k end

local DebugType = {
   Stepper="STEPPER",
   Markers="MARKERS"
}


local _PWAIT_CMD = "RunWait('" .. RSC_DIR .. "\\wait.exe', '" .. RSC_DIR .. "', @SW_HIDE)"

-- https://www.scintilla.org/SciTELua.html
-- https://github.com/mkottman/scite/blob/master/scite/src/SciTE.h

local function Color(r, g, b, a)
   return r | (g << 8) | (b << 16) | (a << 24)
end

local function Debug(debugStr, allowNewlines, forceOut, debugType)
   debugStr = tostring(debugStr)
   if debugType == nil then debugType = DebugType.Stepper end
   if allowNewlines ~= true then debugStr = tostring(debugStr:gsub("[\r\n]",'')) end
   if DEBUG or forceOut then print("[" .. debugType .." DEBUG] " .. debugStr) end
end

local function sleep(n)
  local t = os.clock()
  while os.clock() - t <= n do
    -- nothing
  end
end

-- Gets break line locations in current document
local function GetBreakLines()
   startingCaretPos = editor.CurrentPos
   lineTable = {}
   anchor = 0
   while true do 
      editor:GotoPos(anchor)
      editor:SearchAnchor()
      mark = editor:SearchNext(0, BREAKMARK)
      if mark == -1 then break end
      line = editor:LineFromPosition(mark)
      -- This check below may be unnecessary
      if line == lineTable[0] then break end
      Debug("Breakpoint location: Line #" .. line+1)
      table.insert(lineTable, line)
      anchor = mark+1
   end
   Debug("Returning caret to " .. startingCaretPos)
   editor:GotoPos(startingCaretPos)
   editor:VerticalCentreCaret()
   return lineTable
end

local function ReplaceInDoc(findText, replaceText)
   editor:TargetWholeDocument()
   breakpoint = editor:SearchInTarget(findText)
   while breakpoint ~= -1 do
      editor:ReplaceTarget(replaceText)
      editor:TargetWholeDocument()
      breakpoint = editor:SearchInTarget(findText)
   end
end

local function BreakmarkReplace() ReplaceInDoc(BREAKMARK, _PWAIT_CMD) end
local function BreakmarkRestore() ReplaceInDoc(_PWAIT_CMD, BREAKMARK) end
local function RemoveAllBreakpoints() ReplaceInDoc(BREAKMARK, "") end

local function PlaceBreakpointAtCursor()
   editor:AddText("\n" .. BREAKMARK)
   UpdateBreakpointMarkerPositions()
end

--[[
function ConsumeWaitPIDS()
   local PIDS = {}
   local pid_cur_num = 0
   local file_name = RSC_DIR .. "\\" .. pid_cur_num .. "wait.pid"
   local pid_file = io.open(file_name,"r")
   local pid = 0
   while pid_file ~= nil do
      pid = pid_file:read("*a")
      table.insert(PIDS, pid)
      pid_cur_num = pid_cur_num + 1
      pid_file:close()
      os.remove(file_name)
      pid_file = io.open(file_name,"r")
   end
   return PIDS
end
--]]


local function MarkerAdd(line) editor:MarkerAdd(line, MARKER_NUMBER) end
local function MarkerDeleteAll() editor:MarkerDeleteAll(MARKER_NUMBER) end

function UpdateBreakpointMarkerPositions()
   lines = GetBreakLines()
   MarkerDeleteAll()
   for i=1, #lines do
      MarkerAdd(lines[i])
   end
end

local function MarkerInit()
   MARKER_COLOR = Color(MARKER_COLOR.R, MARKER_COLOR.G,
                        MARKER_COLOR.B, MARKER_COLOR.A)
   editor:MarkerDefine(MARKER_NUMBER,0)
   editor.MarkerFore[MARKER_NUMBER] = MARKER_COLOR
   editor.MarkerBack[MARKER_NUMBER] = MARKER_COLOR
   if DEBUG then MarkerAdd(1) end
   Debug("There should be a colored Marker on line 2", false, false, DebugType.Markers)
end

local function StepperInit()
   Debug("Hello from Adam (abrewer). Happy stepping!", false, true)
   Debug("Current BREAKMARK: " .. BREAKMARK, false, true)
   scite.StripShow("!'Stepper:'(Run)(Stop)(Force Replace)(Force Restore)\n!'Breakpoints:'(Place at Cursor)(Remove All)")

   CodStepperEventCLS = EventClass:new(Common)
   function CodStepperEventCLS:OnSave(path) UpdateBreakpointMarkerPositions() end
   function CodStepperEventCLS:OnKey(char) if not PERFORMANCE_MODE then UpdateBreakpointMarkerPositions() end end
end

-- On button clicked
function OnStrip(control, change)
   Debug("CHANGE: " .. change .. " CONTROL: " .. control .. " BUTTON: " .. ButtonsInv[control] .. "(".. control ..")")
   if change == 1 then
      if control == Buttons.Run then -- Run
         BreakmarkReplace()
         scite.MenuCommand(IDM_GO)
      elseif control == Buttons.Stop then -- Stop
         BreakmarkRestore()
         scite.MenuCommand(IDM_STOPEXECUTE)
      elseif control == Buttons.ForceReplace then -- Force Replace
         BreakmarkReplace()
      elseif control == Buttons.ForceRestore then -- Force Restore
         BreakmarkRestore()
      elseif control == Buttons.BkptAtCursor then -- Place at Cursor
         PlaceBreakpointAtCursor()
         UpdateBreakpointMarkerPositions()
      elseif control == Buttons.RemoveAllBkpts then -- Remove All
         RemoveAllBreakpoints()     
      end
   end
end

function CodStepperMain()
   MarkerInit()
   StepperInit()
end