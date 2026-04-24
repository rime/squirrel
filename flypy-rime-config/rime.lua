local script_dir = rime_api and rime_api.get_user_data_dir and rime_api.get_user_data_dir() or ""
if script_dir and script_dir ~= "" then
  dofile(script_dir .. "/lua/flypy_express.lua")
else
  dofile("lua/flypy_express.lua")
end

function date_translator(input, seg)
   if (input == "orq") then
      --- Candidate(type, start, end, text, comment)
      yield(Candidate("date", seg.start, seg._end, os.date("%Y年%m月%d日"), ""))
      yield(Candidate("date", seg.start, seg._end, os.date("%Y-%m-%d"), " "))
   end
end

function time_translator(input, seg)
   if (input == "ouj") then
      local cand = Candidate("time", seg.start, seg._end, os.date("%H:%M"), " ")
      cand.quality = 1
      yield(cand)
   end
end

