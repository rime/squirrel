local kAccepted, kNoop = 1, 2
local OJC_CODE = "ojc"
local QUICK_ADD_TEXT = "快速加词"
local QUICK_ADD_NOTIFICATION = "SquirrelQuickAddWordNotification"
local QUICK_ADD_NOTIFICATION_OBJECT = "/Library/Input Methods/SquirrelFlypy.app"

local function flypy_open_quick_add_panel()
  os.execute([["/Library/Input Methods/SquirrelFlypy.app/Contents/MacOS/SquirrelFlypy" --quick-add-word >/dev/null 2>&1]])
end

function flypy_express_translator(input, seg)
  if input == OJC_CODE then
    local cand = Candidate("phrase", seg.start, seg._end, QUICK_ADD_TEXT, "")
    cand.quality = 1000
    yield(cand)
  end
end

local function flypy_selected_candidate(ctx, key)
  if key:ctrl() or key:alt() or key:super() or key:release() then
    return nil
  end
  local repr = key:repr()
  if repr == "space" or repr == "Return" or repr == "KP_Enter" then
    return ctx:get_selected_candidate()
  end
  local keycode = key.keycode
  if keycode >= 0x31 and keycode <= 0x39 then
    local index = keycode - 0x31
    local comp = ctx.composition
    if comp:empty() then
      return nil
    end
    local seg = comp:back()
    if not seg.menu then
      return nil
    end
    local page_size = ctx.engine.schema.page_size
    local selected = seg.selected_index
    local page_start = math.floor(selected / page_size) * page_size
    local abs_index = page_start + index
    seg.menu:prepare(abs_index + 1)
    if abs_index < seg.menu:candidate_count() then
      return seg:get_candidate_at(abs_index)
    end
  end
  return nil
end

local FlypyExpressProcessor = {}

function FlypyExpressProcessor.func(key, env)
  local ctx = env.engine.context
  if (not ctx:is_composing()) or ctx.input ~= OJC_CODE then
    return kNoop
  end
  local repr = key:repr()
  if repr == "space" or repr == "Return" or repr == "KP_Enter" then
    ctx:clear()
    flypy_open_quick_add_panel()
    return kAccepted
  end
  if repr == "1" then
    ctx:clear()
    flypy_open_quick_add_panel()
    return kAccepted
  end
  local cand = flypy_selected_candidate(ctx, key)
  if cand and cand.text == QUICK_ADD_TEXT then
    ctx:clear()
    flypy_open_quick_add_panel()
    return kAccepted
  end
  return kNoop
end

flypy_express_processor = FlypyExpressProcessor
return FlypyExpressProcessor
