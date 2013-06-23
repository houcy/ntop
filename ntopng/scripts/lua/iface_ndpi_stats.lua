--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.workingdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html')

ifname = _GET["if"]
interface.find("any")

if(_GET["host"] == nil) then
   stats = interface.getNdpiStats()
else
   stats = interface.getHostInfo(_GET["host"])
end

tot = 0
_ifstats = {}
for key, value in pairs(stats["ndpi"]) do
    --    print("->"..key.."\n")
   traffic = stats["ndpi"][key]["bytes.sent"] + stats["ndpi"][key]["bytes.rcvd"]
   _ifstats[traffic] = key
   --print(key.."="..traffic)
   tot = tot + traffic
end


-- Print up to this number of entries
max_num_entries = 5

-- Print entries whose value >= 5% of the total
threshold = (tot * 3) / 100


print "[\n"
num = 0
accumulate = 0
for key, value in pairsByKeys(_ifstats, rev) do
   if(key < threshold) then
     break
   end

   if(num > 0) then
      print ",\n"
   end

   print("\t { \"label\": \"" .. value .."\", \"value\": ".. key .." }")
   accumulate = accumulate + key
   num = num + 1

   if(num == max_num_entries) then
     break
end
end

if(tot == 0) then
   tot = 1
end

-- In case there is some leftover do print it as "Other"
if(accumulate < tot) then
   if(num > 0) then
      print (",\n")
   end

   print("\t { \"label\": \"Other\", \"value\": ".. (tot-accumulate) .." }")
end

print "\n]"

