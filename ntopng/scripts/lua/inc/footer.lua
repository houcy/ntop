--
-- (C) 2013 - ntop.org
--

require "os"

print [[
      <div id="footer">
      <hr>
   ]]


print [[
<div class="container-fluid">
<div class="row">
  <div class="col-xs-6 col-sm-4">&copy; 1998-]]
print(os.date("%Y"))
print [[ - <A HREF="http://www.ntop.org">ntop.org</A> <br><font color=lightgray>Generated by ntopng ]]

info = ntop.getInfo()
iface_id = interface.name2id(ifname)
is_historical = interface.isHistoricalInterface(iface_id)
print ("v."..info["version"].." </br>for user ")
print('<a href="/lua/admin/users.lua">'.._SESSION["user"].. '</a> and interface <a href="/lua/if_stats.lua?if_name='.. ifname..'">' .. ifname..'</a>')

key = 'ntopng.prefs.'..ifname..'.name'
custom_name = ntop.getCache(key)

if((custom_name ~= nil) and (custom_name ~= "")) then
   print(" (".. custom_name ..")")
end


print [[</font></div> <!-- End column 1 -->
  <div class="col-xs-6 col-sm-4">
  <div class="row">
      <div class="col-xs-6 col-sm-4">
    ]]
if not is_historical then
  key = 'ntopng.prefs.'..ifname..'.speed'
  maxSpeed = ntop.getCache(key)
  -- io.write(maxSpeed)
  if((maxSpeed == "") or (maxSpeed == nil)) then
     maxSpeed = 1000000000 -- 1 Gbit
  else
     maxSpeed = tonumber(maxSpeed)*1000000
  end

  addGauge('gauge', '/lua/set_if_prefs.lua', maxSpeed, 100, 50)
end
print [[
      </div>
      <div class="col-xs-6 col-sm-4">]]
if not is_historical then
 print [[  <A href="/lua/if_stats.lua"><span class="network-load-chart">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span></a> ]]
end
print [[
      </div>
    </div>
  </div><!-- End column 2 -->
  <!-- Optional: clear the XS cols if their content doesn't match in height -->
  <div class="clearfix visible-xs"></div>
  <div class="col-xs-6 col-sm-4">
    <div id="network-load">
  </div> <!-- End column 3 -->
</div>
</div>


<script>
// Updating charts.
]]

if is_historical then print('var is_historical = true;') else print('var is_historical = false;') end
print [[

var updatingChart = $(".network-load-chart").peity("line", { width: 64 });
var prev_bytes   = 0;
var prev_packets = 0;
var prev_epoch   = 0;

function addCommas(nStr) {
  nStr += '';
  var x = nStr.split('.');
  var x1 = x[0];
  var x2 = x.length > 1 ? '.' + x[1] : '';
  var rgx = /(\d+)(\d{3})/;
  while (rgx.test(x1)) {
    x1 = x1.replace(rgx, '$1' + ',' + '$2');
  }
  return x1 + x2;
}

function formatPackets(n) {
  return(addCommas(n)+" Pkts");
}

function bytesToVolume(bytes) {
  var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if (bytes == 0) return '0 Bytes';
  var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
  return (bytes / Math.pow(1024, i)).toFixed(2) + ' ' + sizes[i];
};

function bytesToVolumeAndLabel(bytes) {
  var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if (bytes == 0) return '0 Bytes';
  var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
  return [ (bytes / Math.pow(1024, i)).toFixed(2), sizes[i] ];
};

function bitsToSize(bits, factor) {
  var sizes = ['bps', 'Kbps', 'Mbps', 'Gbps', 'Tbps'];
  if (bits == 0) return '0 bps';
  var i = parseInt(Math.floor(Math.log(bits) / Math.log(1024)));
  if (i == 0) return bits + ' ' + sizes[i];
  return (bits / Math.pow(factor, i)).toFixed(2) + ' ' + sizes[i];
};

function bytesToSize(bytes) {
  return(bytesToSize(bytes*8));
}

function secondsToTime(seconds) {
   if(seconds < 1) {
      return("< 1 sec")
   }

   var days = Math.floor(seconds / 86400)
   var hours =  Math.floor((seconds / 3600) - (days * 24))
   var minutes = Math.floor((seconds / 60) - (days * 1440) - (hours * 60))
   var sec = seconds % 60
   var msg = ""

   if(days > 0) {
      years = Math.floor(days/365)

      if(years > 0) {
	 days = days % 365

	 msg = years + " year"
	 if(years > 1) {
	    msg = msg + "s"
	 }

	 msg = msg + ", "
      }
      msg = msg + days + " day"
      if(days > 1) { msg = msg + "s" }
      msg = msg + ", "
   }

   if(hours > 0) {
      msg = msg + hours + " ";
      if(hours > 1)
	 msg = msg + "hour"
      else
	 msg = msg + "hour"

      if(hours > 1) { msg = msg + "s" }
      msg = msg + ", "
   }

   if(minutes > 0) {
      msg = msg + minutes + " min";
   }

   if(sec > 0) {
      if((msg.length > 0) && (minutes > 0)) { msg = msg + ", " }
      msg = msg + sec + " sec";
   }

   return msg
}

Date.prototype.format = function(format) { //author: meizz
  var o = {
     "M+" : this.getMonth()+1, //month
     "d+" : this.getDate(),    //day
     "h+" : this.getHours(),   //hour
     "m+" : this.getMinutes(), //minute
     "s+" : this.getSeconds(), //second
     "q+" : Math.floor((this.getMonth()+3)/3),  //quarter
     "S" : this.getMilliseconds() //millisecond
  }

  if(/(y+)/.test(format)) format=format.replace(RegExp.$1,
						(this.getFullYear()+"").substr(4 - RegExp.$1.length));
  for(var k in o)if(new RegExp("("+ k +")").test(format))
    format = format.replace(RegExp.$1,
			    RegExp.$1.length==1 ? o[k] :
			    ("00"+ o[k]).substr((""+ o[k]).length));
  return format;
}


function epoch2Seen(epoch) {
  /* 08/01/13 15:12:37 [18 min, 13 sec ago] */
  var d = new Date(epoch*1000);
  var tdiff = Math.floor(((new Date()).getTime()/1000)-epoch);

  return(d.format("dd/MM/yyyy hh:mm:ss")+" ["+secondsToTime(tdiff)+" ago]");
}

setInterval(function() {
    $.ajax({
      type: 'GET',
	  url: '/lua/network_load.lua',
	  data: { },
	  /* error: function(content) { alert("JSON Error (session expired?): logging out"); window.location.replace("/lua/logout.lua");  }, */
	  success: function(content) {
	  var rsp;

	  try {
	    rsp = jQuery.parseJSON(content);

	    if(prev_bytes > 0) {

	      if (rsp.packets < prev_packets) {
	        prev_bytes   = rsp.bytes;
	        prev_packets = rsp.packets;
	      }

	      var values = updatingChart.text().split(",")
	      var bytes_diff = rsp.bytes-prev_bytes;
	      var packets_diff = rsp.packets-prev_packets;
	      var epoch_diff = rsp.epoch - prev_epoch;

	      if(epoch_diff > 0) {
		if(bytes_diff > 0) {
		  values.shift();
		  values.push(bytes_diff);
		  updatingChart.text(values.join(",")).change();
		}

		var pps = Math.floor(packets_diff / epoch_diff);
		var bps = Math.round((bytes_diff*8) / epoch_diff);
		var msg = ""+bitsToSize(bps, 1000)+" [" + addCommas(pps) + " pps]<br>";
		msg += "<i class=\"fa fa-time fa-lg\"></i>Uptime: "+rsp.uptime+"<br>";

		if(rsp.alerts > 0) {
		   msg += "&nbsp;<a href=/lua/show_alerts.lua><i class=\"fa fa-warning fa-lg\" style=\"color: #B94A48;\"></i> <span class=\"label label-danger\">"+rsp.alerts+" Alert";
		   if(rsp.alerts > 1) msg += "s";

		   msg += "</span></A><br>";
		}

		var alarm_threshold_low = 60;  /* 60% */
		var alarm_threshold_high = 90; /* 90% */
		var alert = 0;
            if (is_historical) msg = "";
    msg += "<a href=/lua/hosts_stats.lua>";
		if(rsp.hosts_pctg < alarm_threshold_low) {
		  msg += "<span class=\"label label-default\">";
		} else if(rsp.hosts_pctg < alarm_threshold_high) {
		  alert = 1;
		  msg += "<span class=\"label label-warning\">";
		} else {
		  alert = 1;
		  msg += "<span class=\"label label-danger\">";
		}

		msg += addCommas(rsp.num_hosts)+" Hosts</span></a> ";

    msg += "<a href=/lua/aggregated_hosts_stats.lua>";
		if(rsp.num_aggregations > 0) {
		   if(rsp.aggregations_pctg < alarm_threshold_low) {
		      msg += "<span class=\"label label-default\">";
		   } else if(rsp.aggregations_pctg < alarm_threshold_high) {
		      alert = 1;
		      msg += "<span class=\"label label-warning\">";
		   } else {
		      alert = 1;
		      msg += "<span class=\"label label-danger\">";
		   }

		   msg += addCommas(rsp.num_aggregations)+" Aggregations</span></a>";
		}

    msg += "&nbsp;<a href=/lua/flows_stats.lua>";
		if(rsp.flows_pctg < alarm_threshold_low) {
		  msg += "<span class=\"label label-default\">";
		} else if(rsp.flows_pctg < alarm_threshold_high) {
		   alert = 1;
		  msg += "<span class=\"label label-warning\">";
		} else {
		   alert = 1;
		  msg += "<span class=\"label label-danger\">";
		}

		msg += addCommas(rsp.num_flows)+" Flows </span> </a>";

		$('#network-load').html(msg);
		if (!is_historical) gauge.set(Math.min(bps, gauge.maxValue));

		if(alert) {
		   $('#toomany').html("<div class='alert alert-warning'><h4>Warning</h4>You have too many hosts/flows for your ntopng configuration and this will lead to packet drops and high CPU load. Please restart ntopng increasing -x and -X.</div>");
		}
	      }
	    } else {
	      /* $('#network-load').html("[No traffic (yet)]"); */
	    }

	    prev_bytes   = rsp.bytes;
	    prev_packets = rsp.packets;
	    prev_epoch   = rsp.epoch;

	  } catch(e) {
	     console.log(e);
	     /* alert("JSON Error (session expired?): logging out"); window.location.replace("/lua/logout.lua");  */
	  }
	}
      });
  }, 1000)
  //Enable tooltip without a fixer placement
  $(document).ready(function () { $("[rel='tooltip']").tooltip(); });
  $(document).ready(function () { $("a").tooltip({ 'selector': ''});});
  $(document).ready(function () { $("i").tooltip({ 'selector': ''});});

//Automatically open dropdown-menu
$(document).ready(function(){
    $('ul.nav li.dropdown').hover(function() {
      $(this).find('.dropdown-menu').stop(true, true).delay(150).fadeIn(100);
    }, function() {
      $(this).find('.dropdown-menu').stop(true, true).delay(150).fadeOut(100);
    });
});


</script>

    </div> <!-- / header main container -->

  </body>
	 </html> ]]
