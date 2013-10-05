/*
 *
 * (C) 2013 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"
#include "ewah.h"

/* *************************************** */

/* Daily duration */
ActivityStats::ActivityStats(time_t when) {
  _bitset = new EWAHBoolArray<u_int32_t>;

  begin_time  = (when == 0) ? time(NULL) : when;
  begin_time -= (begin_time % CONST_MAX_ACTIVITY_DURATION);
  begin_time += ntop->get_time_offset();

  wrap_time = begin_time + CONST_MAX_ACTIVITY_DURATION;

  last_set_time = 0;

  //ntop->getTrace()->traceEvent(TRACE_WARNING, "Wrap stats at %u/%s", wrap_time, ctime(&wrap_time));
}

/* *************************************** */

ActivityStats::~ActivityStats() {
  EWAHBoolArray<u_int32_t> *bitset = (EWAHBoolArray<u_int32_t>*)_bitset;

  delete bitset;
}

/* *************************************** */

void ActivityStats::reset() {
  EWAHBoolArray<u_int32_t> *bitset = (EWAHBoolArray<u_int32_t>*)_bitset;

  m.lock(__FILE__, __LINE__);
  bitset->reset();
  last_set_time = 0;
  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

/* when comes from time() and thus is in UTC whereas we must wrap in localtime */
void ActivityStats::set(time_t when) {
  EWAHBoolArray<u_int32_t> *bitset = (EWAHBoolArray<u_int32_t>*)_bitset;
  u_int16_t w;

  if(when > wrap_time) {
    reset();

    begin_time = wrap_time;
    wrap_time += CONST_MAX_ACTIVITY_DURATION;

    ntop->getTrace()->traceEvent(TRACE_INFO,
				 "Resetting stats [when: %u][begin_time: %u][wrap_time: %u]",
				 when, begin_time, wrap_time);
  }

  w = (when - begin_time) % CONST_MAX_ACTIVITY_DURATION;

  if(w == last_set_time) return;

  // ntop->getTrace()->traceEvent(TRACE_INFO, "%u\n", (unsigned int)w);

  m.lock(__FILE__, __LINE__);
  bitset->set((size_t)w);
  m.unlock(__FILE__, __LINE__);
  last_set_time = when;
};

/* *************************************** */

void ActivityStats::setDump(stringstream* dump) {
  EWAHBoolArray<u_int32_t> *bitset = (EWAHBoolArray<u_int32_t>*)_bitset;

  bitset->read(*dump);
}

/* *************************************** */

bool ActivityStats::dump(char* path) {
  EWAHBoolArray<u_int32_t> *bitset = (EWAHBoolArray<u_int32_t>*)_bitset;

  try {
    ofstream dumpFile(path);
    stringstream ss;

    m.lock(__FILE__, __LINE__);
    bitset->write(ss);
    m.unlock(__FILE__, __LINE__);

    dumpFile << ss.str();
    dumpFile.close();
    return(true);
  } catch(...) {
    return(false);
  }
}

/* *************************************** */

bool ActivityStats::readDump(char* path) {
  EWAHBoolArray<u_int32_t> *bitset = (EWAHBoolArray<u_int32_t>*)_bitset;

  /*
    We do not use "direct" bitset->read() as this is apparently creating
    crash problems.
   */
  try {
    ifstream dumpFile(path);
    stringstream ss;

    if(!dumpFile.is_open()) return(false);
    ss << dumpFile.rdbuf();

#if 0
    EWAHBoolArray<u_int32_t> tmp;

    if(!ss.str().empty()) tmp.read(ss);

    m.lock(__FILE__, __LINE__);
    bitset->reset();

    for(EWAHBoolArray<u_int32_t>::const_iterator i = tmp.begin(); i != tmp.end(); ++i)
      bitset->set((size_t)*i);

    m.unlock(__FILE__, __LINE__);
#else
    m.lock(__FILE__, __LINE__);
    bitset->reset();
    if(!ss.str().empty()) bitset->read(ss);
    m.unlock(__FILE__, __LINE__);
#endif

    dumpFile.close();
    return(true);
  } catch(...) {
    return(false);
  }

}

/* *************************************** */

json_object* ActivityStats::getJSONObject() {
  json_object *my_object;
  char buf[32];
  EWAHBoolArray<u_int32_t> *bitset = (EWAHBoolArray<u_int32_t>*)_bitset;
  u_int num = 0, last_dump = 0;
  my_object = json_object_new_object();

  m.lock(__FILE__, __LINE__);
  for(EWAHBoolArray<u_int32_t>::const_iterator i = bitset->begin(); i != bitset->end(); ++i) {
    /*
      As the bitmap has the time set in UTC we need to remove the timezone in order
      to represent the time as local time
    */

    /* Aggregate events at minute granularity */
    if(num == 0)
      num = 1, last_dump = *i;
    else {
      if((last_dump+60 /* 1 min */) > *i)
	num++;
      else {
	snprintf(buf, sizeof(buf), "%lu", begin_time+last_dump);
	json_object_object_add(my_object, buf, json_object_new_int(num));
	num = 1, last_dump = *i;
      }
    }
  }

  if(num > 0) {
    snprintf(buf, sizeof(buf), "%lu", begin_time+last_dump);
    json_object_object_add(my_object, buf, json_object_new_int(num));
  }
  m.unlock(__FILE__, __LINE__);

  return(my_object);
}

/* *************************************** */

char* ActivityStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* *************************************** */

void ActivityStats::deserialize(json_object *o) {
  EWAHBoolArray<u_int32_t> *bitset = (EWAHBoolArray<u_int32_t>*)_bitset;
  struct json_object_iterator it, itEnd;

  if(!o) return;

  /* Reset all */
  bitset->reset();

  it = json_object_iter_begin(o), itEnd = json_object_iter_end(o);

  while (!json_object_iter_equal(&it, &itEnd)) {
    char *key  = (char*)json_object_iter_peek_name(&it);
    u_int32_t when = atol(key);

    when %= CONST_MAX_ACTIVITY_DURATION;
    bitset->set(when);
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s=%d", key, 1);

    json_object_iter_next(&it);
  }
}
