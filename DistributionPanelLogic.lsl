// Power Distribution Panel 
// This module is all about maintaining connecitons and doing calculations 

string logicVersion = "2025-02-03.1";
string debug_string = "Info";

// Common Constants for the Power System 
integer POWER_CHANNEL = -654647;
integer MONITOR_CHANNEL = -6546478;
integer clock_interval = 1;

string REQ = "-REQ";
string ACK = "-ACK";
string PING = "Ping";
string CONNECT = "Connect";
string DISCONNECT = "Disconnect";
string CONNECT_SOURCE = "Connect Src";
string DISCONNECT_SOURCE = "Disc Src";
string DISCONNECT_DRAIN = "Disc Drain";
string POWER = "Power";
string RESET = "Reset";
string NONE = "None";

// Global Constants and Variables for Power Distribution Oanel
integer MAX_POWER_CAPACITY = 10000; // 10kW how much power we can transfer total
integer power_switch_state;


// Sounds for Power Dstribution Panel
string kill_switch_1 = "4690245e-a161-87ce-e392-47e2a410d981";
string kill_switch_2 = "00800a8c-1ac2-ff0a-eed5-c1e37fef2317";

// *********************************
// Debug system
// Higher numbers are lower priority.
integer ERROR = 0;
integer WARN = 1;
integer INFO = 2;
integer DEBUG = 3;
integer TRACE = 4;
string DEBUG_LEVELS = "DebugLevels";
list debug_levels = ["Error", "Warming", "Info", "Debug", "Trace"];
integer debug_level = 2; // debug normally 2 info. 

sayDebug(integer message_level, string message) {
    message = "Logic "+llList2String(debug_levels, message_level) + ": " + message;
    if (message_level <= debug_level) {
        if (message_level <= WARN) {
            // warnings and errors on local chat and on Power Monitor HUD
            llShout(MONITOR_CHANNEL, message);
            llSay(0, message);
        } else {
            // everyting else just on Power Monitor HUD
            llSay(MONITOR_CHANNEL, message);
        }
    }
}

string formatDebug(integer message_level, string message) {
    string result = "";
    if (message_level <= debug_level) {
        result = message;
    }
    return result;
}

setDebugLevelByName(string debug_level_name) {
    debug_level = llListFindList(debug_levels, [debug_level_name]);
}

setDebugLevelByNumber(integer new_debug_level) {
    debug_level = new_debug_level;
    string debug_level_name = llList2String(debug_levels, debug_level);
}

// ********************************
// Known Power Sources
list known_source_keys;
list known_source_names;
list known_source_powers;
list known_source_distances;
list known_source_distance_index; // local to Menu
integer num_known_sources = 0;

read_known_sources() {
    known_source_keys = llJson2List(llLinksetDataRead("known_source_keys"));
    known_source_names = llJson2List(llLinksetDataRead("known_source_names"));
    known_source_powers = llJson2List(llLinksetDataRead("known_source_powers"));
    known_source_distances = llJson2List(llLinksetDataRead("known_source_distances"));
    num_known_sources = llGetListLength(known_source_keys);
}

write_known_sources() {
    num_known_sources = llGetListLength(known_source_keys);
    llLinksetDataWrite("num_known_sources", (string)num_known_sources);
    llLinksetDataWrite("known_source_keys", llList2Json(JSON_ARRAY, known_source_keys));
    llLinksetDataWrite("known_source_names", llList2Json(JSON_ARRAY, known_source_names));
    llLinksetDataWrite("known_source_powers", llList2Json(JSON_ARRAY, known_source_powers));
    llLinksetDataWrite("known_source_distances",llList2Json(JSON_ARRAY, known_source_distances));
}

initialize_known_sources() {
    known_source_keys = [];
    known_source_names = [];
    known_source_powers = [];
    known_source_distances = [];
    write_known_sources();
}

sort_known_sources() {
    // sort the indexes list so we can present known sources in distance order
    // used on ly in list report
    known_source_distance_index = [];
    integer i;
    for (i = 0; i < num_known_sources; i = i + 1) {
        known_source_distance_index = known_source_distance_index + [i, known_source_distance(i)];
    }
    known_source_distance_index = llListSortStrided(known_source_distance_index, 2, 1, TRUE);
}

integer unsorted(integer i) {
    // given a sorted index, return the unsorted index
    return llList2Integer(known_source_distance_index, i*2);
}

integer known_source_key_index(string source_key) {
    if (num_known_sources == 0) {
        return -1;
    }
    integer result = llListFindList(known_source_keys, [source_key]);
    return result;
}
string known_source_key(integer source_num) {
    return llList2Key(known_source_keys, source_num);
}
string known_source_name(integer source_num) {
    return llList2String(known_source_names, source_num);
}
integer known_source_power(integer source_num) {
    return llList2Integer(known_source_powers, source_num);
}
integer known_source_distance(integer source_num) {
    return llList2Integer(known_source_distances, source_num);
}

send_source_ping_req() {
    // Send a request for nearby power sources
    initialize_known_sources();
    llShout(POWER_CHANNEL, PING+REQ);
}

handle_source_ping_ack(string source_name, string source_key, integer source_power) {
    // add to our list of known sources
    //sayDebug (DEBUG, "handle_source_ping_ack("+source_name+") "+EngFormat(source_power));
    list source_details = llGetObjectDetails(source_key, [OBJECT_POS]);    
    vector source_position = llList2Vector(source_details, 0);
    integer source_distance = llFloor(llVecDist(llGetPos(), source_position));
    add_known_source(source_key, source_name, source_power, source_distance);
}

add_known_source(string source_key, string source_name, integer source_power, float source_distance){
    //sayDebug (DEBUG, "add_known_source");
    string filter = llGetObjectDesc();
    if (llSubStringIndex(source_name, filter) == -1) {
        sayDebug(INFO, "Ignored ping from " + source_name + " because its name did not contain " + filter);
        return;
    }
    
    integer source_num = known_source_key_index(source_key);
    if (source_num >= 0) {
        sayDebug(ERROR, "Ignored ping from " + source_name + " because it was already in the list at " + (string)source_num);
        return;
    }

    if (source_distance > 60) {
        sayDebug(INFO, "Ignored ping from "+source_name+ " because it was "+(string)source_distance+ "m away.");
        return;
    }

    if (num_known_sources >= 12) {
        sayDebug(INFO, "Ignored ping from "+source_name+ " because we already have 12 known sources.");
        return;
    }
    
    if(source_key) {
    } else {
        sayDebug(ERROR, "Ignored ping from "+source_name+" because key was malformed.");
        return;
    }

    known_source_keys = known_source_keys + [source_key]; 
    known_source_names = known_source_names + [source_name]; 
    known_source_powers = known_source_powers + [source_power]; 
    known_source_distances = known_source_distances + [source_distance]; 
    write_known_sources();
}

string list_known_sources() {
    string result;
    result = result + "\n-----\nKnown Power Sources: capacity, distance";
    sort_known_sources();
    integer sorted_source_num;
    if (num_known_sources > 0) {
        for (sorted_source_num = 0; 
            sorted_source_num < num_known_sources; 
            sorted_source_num = sorted_source_num + 1) {
            integer unsorted_index = unsorted(sorted_source_num);
            result = result + "\n" +  
                formatDebug(TRACE, "["+known_source_key(unsorted_index)+"] ")  +
                known_source_name(unsorted_index) + ": " +  
                EngFormat(known_source_power(unsorted_index))+", " + 
                (string)known_source_distance(unsorted_index)+"m";
        }
    known_source_distance_index = [];
    } else {
        result = result + "\n" +  "No Power Sources known.";
    }
    return result;
}

// **********************
// Conected Power Sources
list connected_source_keys; 
list connected_source_names; 
list connected_source_capacitys; 
list connected_source_rates; 
integer num_connected_sources = 0;

integer connected_source_power_capacity = 0;
integer connected_source_power_rate = 0;

read_connected_sources() {
    connected_source_keys = llJson2List(llLinksetDataRead("connected_source_keys"));
    connected_source_names = llJson2List(llLinksetDataRead("connected_source_names"));
    connected_source_capacitys = llJson2List(llLinksetDataRead("connected_source_capacitys"));
    connected_source_rates = llJson2List(llLinksetDataRead("connected_source_rates"));
    num_connected_sources = llGetListLength(connected_source_keys);
    calculate_source_power_capacity();
}

write_connected_sources() {
    num_connected_sources = llGetListLength(connected_source_keys);
    llLinksetDataWrite("num_connected_sources", (string)num_connected_sources);
    llLinksetDataWrite("connected_source_keys", llList2Json(JSON_ARRAY, connected_source_keys));
    llLinksetDataWrite("connected_source_names", llList2Json(JSON_ARRAY, connected_source_names));
    llLinksetDataWrite("connected_source_capacitys", llList2Json(JSON_ARRAY, connected_source_capacitys));
    llLinksetDataWrite("connected_source_rates", llList2Json(JSON_ARRAY, connected_source_rates));
}

initialize_connected_sources() {
    connected_source_keys = [];
    connected_source_names = [];
    connected_source_capacitys = [];
    connected_source_rates = [];
    write_connected_sources();
    calculate_source_power_capacity();
}

integer connected_source_key_index(string source_key) {
    integer result;
    if (num_connected_sources == 0) {
        result = -1;
    } else {
        result = llListFindList(connected_source_keys, [source_key]);
    }
    return result;
}

string connected_source_key(integer source_num) {
    return llList2Key(connected_source_keys, source_num);
}
string connected_source_name(integer source_num) {
    return llList2String(connected_source_names, source_num);
}
integer connected_source_capacity(integer source_num) {
    return llList2Integer(connected_source_capacitys, source_num);
}
integer connected_source_rate(integer source_num) {
    return llList2Integer(connected_source_rates, source_num);
}

calculate_source_power_capacity() {
    // Calculate the total we could receive from all the connected sources
    // Called by connect-ack and disconnect-ack
    //sayDebug(DEBUG, "calculate_source_power_capacity");
    connected_source_power_capacity = 0;
    integer source_num;
    for (source_num = 0; source_num < num_connected_sources; source_num = source_num + 1) {
        integer source_capacity = connected_source_capacity(source_num);
        connected_source_power_capacity = connected_source_power_capacity + source_capacity;
        //sayDebug(DEBUG, "calculate_source_power_capacity "+(string)i+": "+(string)source_capacity);
    }
    //sayDebug(DEBUG, "calculate_source_power_capacity:"+EngFormat(connected_source_power_capacity));
}

calculate_source_power_rate() {
    // Calculate the total we are receiving from all the sources
    connected_source_power_rate = 0;
    integer source_num;
    for (source_num = 0; source_num < num_connected_sources; source_num = source_num + 1) {
        integer source_rate = connected_source_rate(source_num);
        connected_source_power_rate = connected_source_power_rate + source_rate;
        //sayDebug(DEBUG, "calculate_source_power_rate "+(string)i+": "+(string)source_rate);
    }
    //sayDebug(DEBUG, "calculate_source_power_rate:"+EngFormat(connected_source_power_rate));
}

handle_source_connect_ack(string source_key, string objectName, integer source_capacity) {
    // a source said yes to power request.
    // Add it to our list of sources and recalculate power capacity
    //sayDebug(DEBUG, "handle_source_connect_ack("+objectName+"): "+EngFormat(source_capacity));

    // Handle bad requests
    if (known_source_key_index(source_key) < 0) {
        sayDebug(ERROR, objectName+" was not known."); // error
        return;
    }
    if (connected_source_key_index(source_key) >= 0) {
        sayDebug(WARN, objectName+" was already connected as a Source.");
        return;
    }
    if (llListFindList(connected_drain_keys, [source_key]) >= 0) {
        sayDebug(WARN, objectName+" was already connected as a Drain.");
        return;
    }
    
    // delete from known sources *** Enable this if we need to save space
    //integer index = known_source_key_index(source_key);
    //known_sources = llDeleteSubList(known_sources, index, index);
    //write_known_sources();
    
    // register the source
    llPlaySound(kill_switch_1, 1);
    connected_source_keys = connected_source_keys + [source_key];
    connected_source_names = connected_source_names + [objectName];
    connected_source_capacitys = connected_source_capacitys + [source_capacity];
    connected_source_rates = connected_source_rates + [0];
    write_connected_sources();
    calculate_source_power_capacity();
    request_power_from_sources();
    //sayDebug(INFO, "handle_source_connect_ack connected "+objectName);
}

handle_disconnect_ack(string source_key, string objectName) {
    // a source acknowledges disconnection
    // delete from list of sources and recalculate capacity
    //sayDebug(DEBUG, "handle_disconnect_ack("+(string)source_key+", "+objectName+")");

    integer source_num = connected_source_key_index(source_key);
    if (source_num > -1) {
        llPlaySound(kill_switch_1, 1);
        //sayDebug(DEBUG,"handle_disconnect_ack \""+connected_source_name(source_num)+"\"");
        //sayDebug(DEBUG,"handle_disconnect_ack1"+list_connected_sources());
        connected_source_keys = llDeleteSubList(connected_source_keys, source_num, source_num);
        connected_source_names = llDeleteSubList(connected_source_names, source_num, source_num);
        connected_source_capacitys = llDeleteSubList(connected_source_capacitys, source_num, source_num);
        connected_source_rates = llDeleteSubList(connected_source_rates, source_num, source_num);
        //sayDebug(DEBUG,"handle_disconnect_ack2"+list_connected_sources());
        write_connected_sources();
        calculate_source_power_capacity();
        calculate_source_power_rate();
        request_power_from_sources();
        sayDebug(INFO, "handle_disconnect_ack disconnected "+objectName);
    } else {
        sayDebug(WARN, "handle_disconnect_ack("+objectName+"): was not connected.");
    }
}

handle_source_power_ack(string source_key, string source_name, integer source_power) {
    // a source provides power we requested
    // update the connected-Sources list with that power
    //sayDebug(DEBUG, "handle_source_power_ack("+source_name+", "+EngFormat(source_power)+")");
    integer source_num = connected_source_key_index(source_key);
    if (source_num < 0) {
        sayDebug(ERROR, source_name+" was not in list of sources."); // error
        return;
    }
    //sayDebug(DEBUG,list_connected_sources());
    // Update that source's supplied rate
    connected_source_rates = llListReplaceList(connected_source_rates, [source_power], source_num, source_num);
    write_connected_sources();
    integer previous_power_rate = connected_source_power_rate;
    calculate_source_power_rate();
    //sayDebug(DEBUG,list_connected_sources());

    if (connected_source_power_rate < previous_power_rate) {
        // something got disconnected. Do we still have enough power? 
        //sayDebug(DEBUG, "handle_source_power_ack "+EngFormat(connected_drain_power_demand) + ">" +
        //    EngFormat(connected_source_power_capacity) );
        if (connected_drain_power_demand > connected_source_power_capacity) {
            cut_all_drain_power();
            return;
        }
    } else if (connected_source_power_capacity >= connected_drain_power_demand) {
        // send power-acks to all the drains
        // distribute the requested power to all the drains
        // *** this is probably inefficient
        //sayDebug(DEBUG, "handle_source_power_ack "+
        //    EngFormat(connected_source_power_capacity) + ">=" +
        //    EngFormat(connected_drain_power_demand) );
        integer drain_num;
        for (drain_num = 0; drain_num < num_connected_drains; drain_num = drain_num + 1) {
            integer demand = connected_drain_demand(drain_num);
            update_drain_power(drain_num, demand, demand);
            }
    
        // failure point. If our total power drain is more than we can get, we shut down.
        if (connected_drain_power_rate > connected_source_power_capacity) {
            cut_all_drain_power();
        }
    }
}

request_power_from_sources() {
    // distribute the current power demand over the sources we have connected
    //sayDebug(DEBUG, "request_power_from_sources("+EngFormat(connected_drain_power_demand)+")");
    
    //sayDebug(INFO, "request_power_from_sources("+EngFormat(connected_drain_power_demand)+")");
    //sayDebug(INFO, "request_power_from_sources connected_drain_power_demand:"+EngFormat(connected_drain_power_demand));
    //sayDebug(INFO, "request_power_from_sources source power:"+EngFormat(connected_source_power_capacity));
    
    // Distribute required connected_drain_power_demand evenly over the connected sources.
    if (num_connected_sources > 0) {
        // integer math doesn't always add up precisely
        // so add the rounding error to the first source. 
        integer distributed_power_demand = llFloor(connected_drain_power_demand / num_connected_sources);
        integer planned_demand = distributed_power_demand * num_connected_sources;
        integer delta = planned_demand - connected_drain_power_demand; // if negative, we're short some amount
        integer first_demand = distributed_power_demand - delta; // add it back in to make up for shortfall
    
        // send power requests to each source
        integer source_num;
        for (source_num = 0; source_num < num_connected_sources; source_num = source_num + 1) {
            string source_key = connected_source_key(source_num);
            if (source_num == 0) {
                //send power request to first source
                //sayDebug(DEBUG, "request_power_from_sources 1 "+
                //EngFormat(first_demand)+ " from " + connected_source_name(source_num));
                llRegionSayTo(source_key, POWER_CHANNEL, POWER+REQ+"["+(string)first_demand+"]");
            } else {
                // send power requests to other sources
                //sayDebug(DEBUG, "request_power_from_sources 2 "+
                //EngFormat(distributed_power_demand)+ " from " + connected_source_name(source_num));
                llRegionSayTo(source_key, POWER_CHANNEL, POWER+REQ+"["+(string)distributed_power_demand+"]");
            }
        }
        //sayDebug(DEBUG, "request_power_from_sources: Finshed");
    } else {
        //sayDebug(DEBUG, "request_power_from_sources: No connected sources");
    }
}

string list_connected_sources() {
    string result;
    result = result + "\n-----\nConnected Power Sources: (rate/capacity)";
    integer source_num;
    if (num_connected_sources > 0) {
        for (source_num = 0; source_num < num_connected_sources; source_num = source_num + 1) {
            result = result + "\n" +  
                formatDebug(TRACE, "["+connected_source_key(source_num)+"] ")  +
                connected_source_name(source_num) + ": " +  
                EngFormat(connected_source_rate(source_num))+"/" + 
                EngFormat(connected_source_capacity(source_num));
        }
    } else {
        result = result + "\n" +  "No Power Sources Connected.";
    }
    result = result + "\n" +   "Total Supply: "+
        EngFormat(connected_source_power_rate)+"/"+
        EngFormat(connected_source_power_capacity);
    return result;
}

// *************************
// conected drains
list connected_drain_keys = []; 
list connected_drain_names = []; 
list connected_drain_demands = []; 
list connected_drain_rates = []; 
integer num_connected_drains = 0;
integer connected_drain_power_rate;
integer connected_drain_power_demand;

read_connected_drains() {
    connected_drain_keys = llJson2List(llLinksetDataRead("connected_drain_keys"));
    connected_drain_names = llJson2List(llLinksetDataRead("connected_drain_names"));
    connected_drain_demands = llJson2List(llLinksetDataRead("connected_drain_demands"));
    connected_drain_rates = llJson2List(llLinksetDataRead("connected_drain_rates"));
    num_connected_drains = llGetListLength(connected_drain_keys);
    flush_drains(FALSE);
}

write_connected_drains() {
    num_connected_drains = llGetListLength(connected_drain_keys); 
    llLinksetDataWrite("num_connected_drains", (string)num_connected_drains);
    llLinksetDataWrite("connected_drain_keys", llList2Json(JSON_ARRAY, connected_drain_keys));
    llLinksetDataWrite("connected_drain_names", llList2Json(JSON_ARRAY, connected_drain_names));
    llLinksetDataWrite("connected_drain_demands", llList2Json(JSON_ARRAY, connected_drain_demands));
    llLinksetDataWrite("connected_drain_rates", llList2Json(JSON_ARRAY, connected_drain_rates));
}

initialize_connected_drains() {
    connected_drain_keys = [];
    connected_drain_names = [];
    connected_drain_demands = [];
    connected_drain_rates = [];
    flush_drains(TRUE);
}

flush_drains(integer write) {
    //sayDebug(DEBUG,"flush_drains("+(string)write+")");
    if (write) {
        write_connected_drains();
    }
    calculate_drain_power_demand();
    calculate_drain_power_rate();
}

integer drain_key_index(string drain_key) {
    integer result;
    if (num_connected_drains == 0) {
        result = -1;
    } else {
        result = llListFindList(connected_drain_keys, [drain_key]);
    }
    return result;
}
string connected_drain_key(integer drain_num) {
    return llList2Key(connected_drain_keys, drain_num);
}
string connected_drain_name(integer drain_num) {
    return llList2String(connected_drain_names, drain_num);
}
integer connected_drain_demand(integer drain_num) {
    return llList2Integer(connected_drain_demands, drain_num);
}
integer connected_drain_rate(integer drain_num) {
    return llList2Integer(connected_drain_rates, drain_num);
}
add_drain(string drain_key, string name) {
    //sayDebug(DEBUG, "add_drain ("+drain_key+", "+name+", "+(string)demand+", "+(string)rate+")");
    if (drain_key) {
        connected_drain_keys = connected_drain_keys + [drain_key];
        connected_drain_names = connected_drain_names + [name];
        connected_drain_demands = connected_drain_demands + [0];
        connected_drain_rates = connected_drain_rates + [0];
        flush_drains(TRUE);
    } else {
        sayDebug(ERROR, "add_drain " + name + " had invalid key.");
    }
}
update_drain_power(integer drain_num, integer demand, integer rate) {
    //sayDebug(DEBUG,"update_drain_power before "+list_drains());
    connected_drain_demands = llListReplaceList(connected_drain_demands, [demand], drain_num, drain_num);
    connected_drain_rates = llListReplaceList(connected_drain_rates, [rate], drain_num, drain_num);
    flush_drains(TRUE);
    //sayDebug(DEBUG,"update_drain_power after "+list_drains());
    string message = POWER+ACK+"["+EngFormat(demand)+"]";
    //sayDebug(DEBUG, "handle_source_power_ack sending "+message+
    //" to " + connected_drain_name(drain_num));
    llRegionSayTo(connected_drain_key(drain_num), POWER_CHANNEL, message);
}

handle_drain_ping_req(string drain_key) {
    // respond to ping with max power capacity
    //sayDebug(DEBUG, "handle_drain_ping_req");
    llRegionSayTo(drain_key, POWER_CHANNEL, PING+ACK+"["+(string)MAX_POWER_CAPACITY+"]");
}
handle_drain_connect_req(string drain_key, string objectName) {
    // a power drain wants power. 
    // add it to our list of power drains
    //sayDebug(DEBUG, "handle_drain_connect_req("+(string)drain_key+", "+objectName+")");
    llPlaySound(kill_switch_1, 1);
    if (drain_key_index(drain_key) > -1) {
        sayDebug(INFO, "Reconnecting Drain " + objectName);
        llRegionSayTo(drain_key, POWER_CHANNEL, CONNECT+ACK+"["+(string)MAX_POWER_CAPACITY+"]");
        return;
    }
    if (connected_source_key_index(drain_key) > -1) {
        sayDebug(WARN, objectName+" was already connecred as a Source.");
        return;
    }
    add_drain(drain_key, objectName);
    llRegionSayTo(drain_key, POWER_CHANNEL, CONNECT+ACK+"["+(string)MAX_POWER_CAPACITY+"]");
}

calculate_drain_power_demand() {
    // calculate the total power demanded by drains
    // Called by connect-req and disconnect-req
    connected_drain_power_demand = 0;
    integer drain_num;
    for (drain_num = 0; drain_num < num_connected_drains; drain_num = drain_num + 1) {
        connected_drain_power_demand = connected_drain_power_demand + connected_drain_demand(drain_num);
    }
    //sayDebug(DEBUG, "calculate_drain_power_demand() returns "+EngFormat(connected_drain_power_demand));
}

calculate_drain_power_rate() {
    // calculate the total power used by drains
    // Called by connect-req and disconnect-req
    connected_drain_power_rate = 0;
    integer drain_num;
    for (drain_num = 0; drain_num < num_connected_drains; drain_num = drain_num + 1) {
        connected_drain_power_rate = connected_drain_power_rate + connected_drain_rate(drain_num);
    }
    //sayDebug(DEBUG, "calculate_drain_power_rate() returns "+EngFormat(connected_drain_power_rate));
}

handle_disconnect_req(string objectKey, string objectName) {
    // a source or drain drain requests disconnect. 
    // Remove it from our list of drains. 
    //sayDebug(DEBUG, "handle_disconnect_req("+objectKey+", "+objectName+")");
    llPlaySound(kill_switch_1, 1);
    integer drain_num = drain_key_index(objectKey);
    integer source_num = connected_source_key_index(objectKey);
    if (drain_num > -1) {
        update_drain_power(drain_num, 0, 0);
        connected_drain_keys = llDeleteSubList(connected_drain_keys, drain_num, drain_num);
        connected_drain_names = llDeleteSubList(connected_drain_names, drain_num, drain_num);
        connected_drain_demands = llDeleteSubList(connected_drain_demands, drain_num, drain_num);
        connected_drain_rates = llDeleteSubList(connected_drain_rates, drain_num, drain_num);
        flush_drains(TRUE);
        request_power_from_sources();
        sayDebug(INFO, "Drain "+objectName+" was disconnected."); // warning
    } else if (source_num > -1) {
        connected_source_keys = llDeleteSubList(connected_source_keys, source_num, source_num);
        connected_source_names = llDeleteSubList(connected_source_names, source_num, source_num);
        connected_source_capacitys = llDeleteSubList(connected_source_capacitys, source_num, source_num);
        connected_source_rates = llDeleteSubList(connected_source_rates, source_num, source_num);
        write_connected_sources();
        request_power_from_sources();
        sayDebug(INFO, "source "+objectName+" was disconnected."); // warning
    } else {
        sayDebug(INFO, objectName+" was not connected."); // waning
    }
    llRegionSayTo(objectKey, POWER_CHANNEL, DISCONNECT+ACK);
}

handle_drain_power_request(string drain_key, string objectName, integer powerRequest) {
    // a source is asking for power. 
    //sayDebug(DEBUG, "handle_drain_power_request ["+drain_key+"] "+objectName+" requests "+EngFormat(powerRequest));
    //sayDebug(DEBUG, "handle_drain_power_request "+list_drains());
    //sayDebug(DEBUG, "handle_drain_power_request power_switch_state:"+
    //    on_off_string(power_switch_state));
    //sayDebug(DEBUG, "handle_drain_power_request connected_source_power_capacity:" +
    //    EngFormat(connected_source_power_capacity));
    //sayDebug(DEBUG, "handle_drain_power_request powerRequest:" + EngFormat(powerRequest));
    integer drain_num = drain_key_index(drain_key);
    if (drain_num >= 0) {
        integer power_granted = 0;
        if (power_switch_state & connected_source_power_capacity >= powerRequest) {
            power_granted = powerRequest;
        } else {
            //sayDebug(DEBUG, "handle_drain_power_request denied. Power is " +
            //    on_off_string(power_switch_state) + ". " +
            //    "connected_source_power_capacity:" + EngFormat(connected_source_power_capacity) + "W");
        }
        update_drain_power(drain_num, powerRequest, power_granted);
        request_power_from_sources(); // this ill come back as POWER+ACK and be handled in handle_source_power_ack()
    } else {
        sayDebug(ERROR, "handle_drain_power_request object "+drain_key+" was not connected");
        return;
    }
}

cut_all_drain_power() 
// Switch off all outging power. 
// Sends Power-ACK[0] to all drains. 
{
    //sayDebug(DEBUG, "cut_all_power");
    integer drain_num;
    for (drain_num = drain_num; drain_num < num_connected_drains; drain_num = drain_num + 1) {
        llRegionSayTo(connected_drain_key(drain_num), POWER_CHANNEL, POWER+ACK+"[0]");
    }    
}

string list_drains() {
    string result;
    result = result + "\n-----\nPower Drains: (rate/demand)";
    connected_drain_power_rate = 0;
    connected_drain_power_demand = 0;
    integer drain_num;
    num_connected_drains = llGetListLength(connected_drain_keys); 
    if (num_connected_drains > 0) {
        for (drain_num = 0; drain_num < num_connected_drains; drain_num = drain_num + 1) {
            connected_drain_power_rate = connected_drain_power_rate + connected_drain_rate(drain_num);
            connected_drain_power_demand = connected_drain_power_demand + connected_drain_demand(drain_num);
            result = result + "\n" +  
                formatDebug(TRACE,  "["+connected_drain_key(drain_num)+"] ") +
                connected_drain_name(drain_num) + ": " + 
                EngFormat(connected_drain_rate(drain_num))+ "/" + 
                EngFormat(connected_drain_demand(drain_num));
        }
        result = result + "\n" +   "Total Power: "+
            EngFormat(connected_drain_power_rate)+ "/" + 
            EngFormat(connected_drain_power_demand);
    } else {
        result = result + "\n" +  "No Power Drains Connected.";
    }
    return result;
}

switch_power(integer new_power_switch_state) {
    //sayDebug(DEBUG, "switch_power("+on_off_string(new_power_switch_state)+")");
    llPlaySound(kill_switch_1, 1);
    power_switch_state = new_power_switch_state;
    integer drain_num;
    if (power_switch_state) {
        // switch on
        // request power from sourcs
        request_power_from_sources();
        // When the source sends ack, we will then send power-acks to the drains. 
    } else {
        // Cut power to all the drains.
        // This is fine. This is what we want to to. 
        for (drain_num = 0; drain_num < num_connected_drains; drain_num = drain_num + 1) {
            string drain_key = connected_drain_key(drain_num);
            llRegionSayTo(drain_key, POWER_CHANNEL, POWER+ACK+"[0]");
        }
        // Cut power from all the sources
        // This is fine., This is what we want to do. 
        for (drain_num = 0; drain_num < num_connected_sources; drain_num = drain_num + 1) {
            string source_key = connected_source_key(drain_num);
            llRegionSayTo(source_key, POWER_CHANNEL, POWER+REQ+"[0]");
        }
    }
}

monitor_power() {
    integer cut = FALSE;
    if (connected_drain_power_rate > connected_source_power_rate) {
        sayDebug(WARN, "connected_drain_power_rate:"+EngFormat(connected_drain_power_rate)+
            " > connected_source_power_rate:"+EngFormat(connected_source_power_rate));
        cut = TRUE;
    }

    if (connected_drain_power_rate > connected_source_power_capacity) {
        sayDebug(WARN, "connected_drain_power_rate:"+EngFormat(connected_drain_power_rate)+
            " > connected_source_power_capacity:"+EngFormat(connected_source_power_capacity));
        cut = TRUE;
    }

    if (cut) {
        switch_power(FALSE);
    }
}

// ***********************************
// String-Handling Stuff

string trimMessageParameters(string message) {
    string messageTrimmed = message;
    integer whereLBracket = llSubStringIndex(message, "[") -1;
    if (whereLBracket > -1) {
        messageTrimmed = llGetSubString(message, 0, whereLBracket);
    }
    return messageTrimmed;
}

integer getMessageParameter(string message) {
    integer whereLBracket = llSubStringIndex(message, "[") +1;
    integer whereRBracket = llSubStringIndex(message, "]") -1;
    string parameters = llGetSubString(message, whereLBracket, whereRBracket);
    return (integer)parameters;
}

string on_off_string(integer power_switch_state)  {
    if (power_switch_state) {
        return "On";
    } else {
        return "Off";
    }
}

string EngFormat(integer quantity) {
// present quantity in engineering notaiton with prefix
    list divisors = [1, 1000, 1000000];
    list prefixes = ["W", "kW", "MW"];
    integer index = llFloor(llLog10(quantity) /3);
    integer divisor = llList2Integer(divisors, index);
    string prefix = llList2String(prefixes, index);
    integer revisedQuantity = quantity / divisor;
    return (string)revisedQuantity+prefix;
}

report_status() {
    string status;
    status = status + "\n" + "Device Report for "+llGetObjectName()+":";
    status = status + "\n" + "Power: " + on_off_string(power_switch_state);
    status = status + "\n" + "Maximum Power: "+ EngFormat(MAX_POWER_CAPACITY);
    status = status + "\n" + "Input Power: "+ EngFormat(connected_source_power_rate);
    status = status + "\n" + "Output Power: "+ EngFormat(connected_drain_power_rate);
    status = status + list_known_sources();
    status = status + list_connected_sources();
    status = status + list_drains();
    status = status + "\n-----\n" + "Free Memory: " + (string)llGetFreeMemory();
    sayDebug(INFO, status);
}

default
{
    state_entry()
    {
        llLinksetDataWrite("LogicVersion",logicVersion);
        setDebugLevelByName(debug_string);
        //sayDebug(DEBUG, "state_entry");
        read_known_sources();
        read_connected_sources();
        read_connected_drains();
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
        //llSetTimerEvent(10);
        sayDebug(DEBUG, "state_entry done. Free Memory: " + (string)llGetFreeMemory());
    }
    
    link_message(integer Sender, integer Number, string message, key objectKey) {
        sayDebug(DEBUG, "link_message "+(string)Number+" "+message);
        if (message == "Status") {
            report_status();
        } else if (message == "Reset") {
            initialize_known_sources();
            initialize_connected_sources();
            initialize_connected_drains();
            llResetScript();
        } else if (message == DEBUG_LEVELS) {
            setDebugLevelByNumber(Number);
        } else if (message == PING) {
            send_source_ping_req();
        } else if (message == "Power") {
            switch_power(Number);
        } else if (message == DISCONNECT+REQ) {
            handle_disconnect_req(objectKey, "menu");
        } else if (message == DISCONNECT+ACK) {
            handle_disconnect_ack(objectKey, "menu");
        } else {
            sayDebug(ERROR, "did not handle link message "+(string)Number+", "+message);
        }
    }

    listen(integer channel, string name, key objectKey, string message )
    {
        if (channel == POWER_CHANNEL) {
            string trimmed_message = trimMessageParameters(message);
            integer parameter = getMessageParameter(message);
            sayDebug(DEBUG, "listen \""+name+"\" says \""+message + "\"");
            if (message == PING+REQ) {
                handle_drain_ping_req(objectKey);
            } else if (trimmed_message == PING+ACK) {
                handle_source_ping_ack(name, objectKey, parameter);
            } else if (trimmed_message == CONNECT+REQ) {
                handle_drain_connect_req(objectKey, name);
            } else if (trimmed_message == CONNECT+ACK) {
                handle_source_connect_ack(objectKey, name, parameter);
            } else if (trimmed_message == DISCONNECT+REQ) {
                handle_disconnect_req(objectKey, name);
            } else if (trimmed_message == DISCONNECT+ACK) {
                handle_disconnect_ack(objectKey, name);
            } else if (trimmed_message == POWER+REQ) {
                handle_drain_power_request(objectKey, name, parameter);
            } else if (trimmed_message == POWER+ACK) {
                handle_source_power_ack(objectKey, name, parameter);
            } else {
                sayDebug(ERROR, "did not handle power channel message:"+message);
            }
        }
    }

    timer() {
        //monitor_power();
    }
}
