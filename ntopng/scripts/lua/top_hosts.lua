--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html')


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

interface.find(ifname)
hosts_stats = interface.getHostsInfo()

max_num = 15
localhosts = {}
found = false
num = 0
for key, value in pairs(hosts_stats) do
   --print(hosts_stats[key]["name"].."<p>\n")

   if(hosts_stats[key]["localhost"] == true) then
      localhosts[key] = hosts_stats[key]
      found = true
      num = num + 1
   end
end

if(found) then

print [[

<hr>
<h2>Top Hosts</H2>

<script src="/js/cubism.v1.js"></script>
<div id="tophosts"></div>

<script>

var beginning =  (new Date).getTime();
var prev = {};

function fetchData(name) {
	var value = 0,
	values = [],	
	i = 0,
	last;
	return context.metric(function(start, stop, step, callback) {
	    start = +start, stop = +stop;
	    if (isNaN(last)) last = start;
	    while (last < stop) {
	      last += step;
	      if(stop < beginning) {
		value = 0;
	      values.push(value);
	      } else {
		d3.json("/lua/get_host_traffic.lua?host="+name, function(data) {
		    if(!data) return callback(new Error("unable to load data"));
		    if(prev[name] != undefined) {
		      values.push(data.value - prev[name]);
		    }
		    prev[name] = data.value;
		  });

	      }	     
	    }
	    callback(null, values = values.slice((start - stop) / step));
	  }, name);
      }

var width = 800;
var context = cubism.context()
.serverDelay(0)
.clientDelay(0) // specifies how long a delay we are prepared to wait before querying the server for new data points
.step(1e3)
.size(width);


]]

num = 0
for key, value in pairs(localhosts) do
   print('var host'..num..' = fetchData("' .. key ..'");\n');
   num = num+1
   if(num == max_num) then break end
end

print [[
d3.select("#tophosts").call(function(div) {
    div.append("div")
      .attr("class", "axis")
      .call(context.axis().orient("top"));
    div.selectAll(".horizon")
    .data([
]]

num = 0
for key, value in pairs(localhosts) do
   if(num > 0) then print(",") end
   print(' host'..num)
   num = num+1
   if(num == max_num) then break end
end

print [[
])
      .enter().append("div")
      .attr("class", "horizon")
      .call(context.horizon().extent([-20, 20])
	    .height(15) // Bar height
	 );

    div.append("div")
      .attr("class", "rule")
      .call(context.rule());
  });

// On mousemove, reposition the chart values to match the rule.
context.on("focus", function(i) {
        d3.selectAll(".value").style("right", i == null ? null : context.size() -i + "px");
  });


</script>

]]
else 
print("<div class=\"alert alert-error\"><img src=/img/warning.png> No results found</div>")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
