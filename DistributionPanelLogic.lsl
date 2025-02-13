// Power Distribution Panel 
// This module is all about maintaining connecitons and doing calculations 

string debug_string = "Info";

// Global Constants and Variables for Power Distribution Oanel
integer MAX_POWER_CAPACITY = 10000; // 10kW how much power we can transfer total
integer power_switch_state;

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

string KNOWN = "Known";
string SOURCE = "Source";
string DRAIN = "Drain";
string KEY = "Key";
string NAME = "Name";
string DISTANCE = "Distance";
string CAPACITY = "Capacity";
string DEMAND = "Demand";
string RATE = "Rate";

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

setDebugLevel(integer new_debug_level) {
    debug_level = new_debug_level;
}

// ********************************
// Known Power Sources
integer num_known_sources = 0; // 1-based in numbering

delete_known_sources() {
    integer i;
    // Kill the hell out of them
    for (i = 0; i <= 100; i = i + 1) {
        llLinksetDataDelete(KNOWN+(string)i+KEY);
        llLinksetDataDelete(KNOWN+(string)i+NAME);
        llLinksetDataDelete(KNOWN+(string)i+POWER);
        llLinksetDataDelete(KNOWN+(string)i+DISTANCE);
    }
    num_known_sources = 0;
    llLinksetDataWrite("num_known_sources", (string)num_known_sources);
}

integer known_source_key_index(string source_key) {
    if (num_known_sources <= 0) {
        return -1;
    }
    integer i;
    for (i = 1; i <= num_known_sources; i = i + 1) {
        if (llLinksetDataRead(KNOWN+(string)i+KEY) == source_key) {
            return i;
        }
    }
    return -1;
}
string known_source_key(integer source_num) {
    return llLinksetDataRead(KNOWN+(string)source_num+KEY);
}
string known_source_name(integer source_num) {
    return llLinksetDataRead(KNOWN+(string)source_num+NAME);
}
integer known_source_power(integer source_num) {
    return (integer)llLinksetDataRead(KNOWN+(string)source_num+POWER);
}
integer known_source_distance(integer source_num) {
    return (integer)llLinksetDataRead(KNOWN+(string)source_num+DISTANCE);
}

add_known_source(string source_key, string source_name, integer source_power, float source_distance){
    string filter = llGetObjectDesc();
    if (llSubStringIndex(source_name, filter) == -1) {
        sayDebug(TRACE, "Ignored ping from " + source_name + " because its name did not contain " + filter);
        return;
    }

    num_known_sources = num_known_sources + 1;
    sayDebug (DEBUG, "add_known_source "+(string)num_known_sources+" "+source_name);
    llLinksetDataWrite(KNOWN+(string)num_known_sources+KEY, source_key); 
    llLinksetDataWrite(KNOWN+(string)num_known_sources+NAME, source_name); 
    llLinksetDataWrite(KNOWN+(string)num_known_sources+POWER, (string)source_power); 
    llLinksetDataWrite(KNOWN+(string)num_known_sources+DISTANCE, (string)source_distance); 
    llLinksetDataWrite("num_known_sources", (string)num_known_sources);
}

list known_source_distance_index; // local to Menu
sort_known_sources() {
    // sort the indexes list so we can present known sources in distance order
    known_source_distance_index = []; // zero-based
    integer i;
    for (i = 1; i <= num_known_sources; i = i + 1) {
        known_source_distance_index = known_source_distance_index + [i, known_source_distance(i)];
    }
    known_source_distance_index = llListSortStrided(known_source_distance_index, 2, 1, TRUE);
    //sayDebug(DEBUG,"sort_known_sources:"+(string)known_source_distance_index);
}

integer unsorted(integer i) {
    // given a sorted index, return the unsorted index
    return llList2Integer(known_source_distance_index, i*2-2);
}

free_sorted_sources() {
    known_source_distance_index = [];
}

string list_known_sources() {
    string result;
    result = result + "\n-----\nKnown Power Sources: capacity, distance";
    if (num_known_sources > 0) {
        sort_known_sources();
        integer source_num;
        for (source_num = 1; source_num <= num_known_sources; source_num = source_num + 1) {
            integer unsorted_index = unsorted(source_num);
            result = result + "\n" + 
                formatDebug(TRACE, "["+known_source_key(unsorted_index)+"] ")  +
                known_source_name(unsorted_index) + ": " +  
                engFormat(known_source_power(unsorted_index))+", " + 
                (string)known_source_distance(unsorted_index)+"m";
        }
        free_sorted_sources();
    } else {
        result = result + "\n" +  "No Power Sources known.";
    }
    return result;
}

send_source_ping_req() {
    // Send a request for nearby power sources
    delete_known_sources();
    llShout(POWER_CHANNEL, PING+REQ);
}

handle_source_ping_ack(string source_name, string source_key, integer source_power) {
    // add to our list of known sources
    //sayDebug (DEBUG, "handle_source_ping_ack("+source_name+") "+engFormat(source_power));
    list source_details = llGetObjectDetails(source_key, [OBJECT_POS]);    
    vector source_position = llList2Vector(source_details, 0);
    integer source_distance = llFloor(llVecDist(llGetPos(), source_position));
    add_known_source(source_key, source_name, source_power, source_distance);
}

// **********************
// Conected Power Sources
integer num_connected_sources = 0;
integer connected_source_power_capacity = 0;
integer connected_source_power_rate = 0;

delete_connected_sources() {
    integer i;
    for (i = 0; i <= 100; i = i + 1) {
        llLinksetDataDelete(SOURCE+(string)i+KEY);
        llLinksetDataDelete(SOURCE+(string)i+NAME);
        llLinksetDataDelete(SOURCE+(string)i+CAPACITY);
        llLinksetDataDelete(SOURCE+(string)i+RATE);
    }
    num_connected_sources = 0;
    llLinksetDataWrite("num_connected_sources", (string)num_connected_sources);
    connected_source_power_capacity = 0;
    connected_source_power_rate = 0;
}

integer connected_source_key_index(string source_key) {
    if (num_connected_sources == 0) {
        return -1;
    }
    integer i;
    for (i = 1; i <= num_connected_sources; i = i + 1) {
        if (llLinksetDataRead(SOURCE+(string)i+KEY) == source_key) {
            return i;
        }
    }
    return -1;
}

string connected_source_key(integer source_num) {
    return llLinksetDataRead(SOURCE+(string)source_num+KEY);
}
string connected_source_name(integer source_num) {
    return llLinksetDataRead(SOURCE+(string)source_num+NAME);
}
integer connected_source_capacity(integer source_num) {
    return (integer)llLinksetDataRead(SOURCE+(string)source_num+CAPACITY);
}
integer connected_source_rate(integer source_num) {
    return (integer)llLinksetDataRead(SOURCE+(string)source_num+RATE);
}

add_connected_source(key source_key, string source_name, integer source_capacity, integer source_rate) {
    if (source_key) {
        sayDebug(DEBUG, "add_connected_source adding " + source_name);
        num_connected_sources = num_connected_sources + 1;
        llLinksetDataWrite(SOURCE+(string)num_connected_sources+KEY, source_key); 
        llLinksetDataWrite(SOURCE+(string)num_connected_sources+NAME, source_name); 
        llLinksetDataWrite(SOURCE+(string)num_connected_sources+CAPACITY, (string)source_capacity); 
        llLinksetDataWrite(SOURCE+(string)num_connected_sources+RATE, (string)0); 
        llLinksetDataWrite("num_connected_sources", (string)num_connected_sources);
        //sayDebug(DEBUG, list_connected_sources());
    //} else {
    //    sayDebug(ERROR, "add_connected_source " + source_name + " had invalid key.");
    }
}

delete_connected_source(integer source_num) {
    integer i;
    // From the source-to-be-deleted to the end, shift them down one. 
    for (i = source_num; i < num_connected_sources; i = i + 1) {
        llLinksetDataWrite(SOURCE+(string)i+KEY, connected_source_key(i+1)); 
        llLinksetDataWrite(SOURCE+(string)i+NAME, connected_source_name(i+1)); 
        llLinksetDataWrite(SOURCE+(string)i+CAPACITY, (string)connected_source_capacity(i+1)); 
        llLinksetDataWrite(SOURCE+(string)i+RATE, (string)connected_source_rate(i+1));  
    }
    num_connected_sources = num_connected_sources - 1;
    llLinksetDataWrite("num_connected_sources", (string)num_connected_sources);
}

calculate_source_power_capacity() {
    // Calculate the total we could receive from all the connected sources
    // Called by connect-ack and disconnect-ack
    //sayDebug(DEBUG, "calculate_source_power_capacity");
    connected_source_power_capacity = 0;
    integer source_num;
    for (source_num = 1; source_num <= num_connected_sources; source_num = source_num + 1) {
        integer source_capacity = connected_source_capacity(source_num);
        connected_source_power_capacity = connected_source_power_capacity + source_capacity;
        //sayDebug(DEBUG, "calculate_source_power_capacity "+(string)source_num+": "+(string)source_capacity);
    }
    sayDebug(DEBUG, "calculate_source_power_capacity:"+engFormat(connected_source_power_capacity));
}

calculate_source_power_rate() {
    // Calculate the total we are receiving from all the sources
    connected_source_power_rate = 0;
    integer source_num;
    for (source_num = 1; source_num <= num_connected_sources; source_num = source_num + 1) {
        connected_source_power_rate = connected_source_power_rate + connected_source_rate(source_num);
    }
    //sayDebug(DEBUG, "calculate_source_power_rate:"+engFormat(connected_source_power_rate));
}

handle_source_connect_ack(string source_key, string source_name, integer source_capacity) {
    // a source said yes to power request.
    // Add it to our list of sources and recalculate power capacity
    //sayDebug(DEBUG, "handle_source_connect_ack("+source_name+"): "+engFormat(source_capacity));

    // Handle bad requests
    if (known_source_key_index(source_key) < 0) {
        sayDebug(ERROR, source_name+" was not known."); // error
        return;
    }
    if (connected_source_key_index(source_key) >= 0) {
        sayDebug(WARN, source_name+" was already connected as a Source.");
        calculate_source_power_capacity();
        request_power_from_sources();
        return;
    }
    if (drain_key_index(source_key) >= 0) {
        sayDebug(WARN, source_name+" was already connected as a Drain.");
        // weird as hell but we need to defend against it.
        return;
    }
        
    // register the source
    llPlaySound(kill_switch_1, 1);
    sayDebug(DEBUG, "handle_source_connect_ack connecting "+source_name);
    add_connected_source(source_key, source_name, source_capacity, 0);
    calculate_source_power_capacity();
    request_power_from_sources();
}

handle_disconnect_ack(string source_key, string objectName) {
    // a source acknowledges disconnection
    // delete from list of sources and recalculate capacity
    //sayDebug(DEBUG, "handle_disconnect_ack("+(string)source_key+", "+objectName+")");

    integer source_num = connected_source_key_index(source_key);
    if (source_num > -1) {
        sayDebug(DEBUG, "handle_disconnect_ack disconnecting "+objectName);
        llPlaySound(kill_switch_1, 1);
        delete_connected_source(source_num);
        calculate_source_power_capacity();
        calculate_source_power_rate();
        request_power_from_sources();
    } else {
        sayDebug(DEBUG, "handle_disconnect_ack("+objectName+") was not connected.");
    }
}

handle_source_power_ack(string source_key, string source_name, integer source_power) {
    // a source provides power we requested
    // update the connected-Sources list with that power
    // if possinble, supply power to drains 
    
    sayDebug(DEBUG, "handle_source_power_ack("+source_name+", "+engFormat(source_power)+")");
    integer source_num = connected_source_key_index(source_key);
    // Update that source's supplied rate
    llLinksetDataWrite(SOURCE+(string)source_num+RATE, (string)source_power);
    
    // start the timer to call update_all_drain_powers();
    llSetTimerEvent(.5);
}

request_power_from_sources() {
    // distribute the current power demand over the sources we have connected
    sayDebug(DEBUG, "request_power_from_sources("+engFormat(connected_drain_power_demand)+")");
    // Distribute required connected_drain_power_demand evenly over the connected sources.
    if (num_connected_sources > 0) {
        // integer math doesn't always add up precisely
        // so add the rounding error to the first source. 
        integer distributed_power_demand = llFloor(connected_drain_power_demand / num_connected_sources);
        
        // Calculatiuons broken up step by step: 
        //integer planned_demand = distributed_power_demand * num_connected_sources;
        //integer delta = planned_demand - connected_drain_power_demand; // if negative, we're short some amount
        //integer first_demand = distributed_power_demand - delta; // add it back in to make up for shortfall

        // send power requests to each source
        integer source_num;
        for (source_num = 1; source_num <= num_connected_sources; source_num = source_num + 1) {
            string source_key = connected_source_key(source_num);
            integer request = distributed_power_demand;
            if (source_num == 1) {
                request = distributed_power_demand + connected_drain_power_demand - (distributed_power_demand * num_connected_sources);
            }
            sayDebug(DEBUG, "request_power_from_sources requests "+engFormat(request)+" from "+connected_source_name(source_num));
            llRegionSayTo(source_key, POWER_CHANNEL, POWER+REQ+"["+(string)request+"]");
        }
    } else {
        sayDebug(DEBUG, "request_power_from_sources: No connected sources");
    }
}

string list_connected_sources() {
    string result;
    result = result + "\n-----\nConnected Power Sources: rate/capacity";
    integer source_num;
    if (num_connected_sources > 0) {
        for (source_num = 1; source_num <= num_connected_sources; source_num = source_num + 1) {
            result = result + "\n" +  
                formatDebug(TRACE, "["+connected_source_key(source_num)+"] ")  +
                connected_source_name(source_num) + ": " +  
                engFormat(connected_source_rate(source_num))+"/" + 
                engFormat(connected_source_capacity(source_num));
        }
    } else {
        result = result + "\n" +  "No Power Sources Connected.";
    }
    result = result + "\n" +   "Total Supply: "+
        engFormat(connected_source_power_rate)+"/"+
        engFormat(connected_source_power_capacity);
    return result;
}

// *************************
// conected drains
integer num_connected_drains = 0;
integer connected_drain_power_rate;
integer connected_drain_power_demand;

delete_connected_drains() {
    integer i;
    for (i = 0; i <= 100; i = i + 1) {
        llLinksetDataDelete(DRAIN+(string)i+KEY);
        llLinksetDataDelete(DRAIN+(string)i+NAME);
        llLinksetDataDelete(DRAIN+(string)i+DEMAND);
        llLinksetDataDelete(DRAIN+(string)i+RATE);
    }
    num_connected_drains = 0;
    llLinksetDataWrite("num_connected_drains", (string)num_connected_drains); 
    calculate_drain_power_demand();
    calculate_drain_power_rate();
}

integer drain_key_index(string drain_key) {
    if (num_connected_drains == 0) {
        return -1;
    }
    integer i;
    for (i = 1; i <= num_connected_drains; i = i + 1) {
        if (llLinksetDataRead(DRAIN+(string)i+KEY) == drain_key) {
            return i;
        }
    }
    return -1;
}
string connected_drain_key(integer drain_num) {
    return llLinksetDataRead(DRAIN+(string)drain_num+KEY);
}
string connected_drain_name(integer drain_num) {
    return llLinksetDataRead(DRAIN+(string)drain_num+NAME);
}
integer connected_drain_demand(integer drain_num) {
    return (integer)llLinksetDataRead(DRAIN+(string)drain_num+DEMAND);
}
integer connected_drain_rate(integer drain_num) {
    return (integer)llLinksetDataRead(DRAIN+(string)drain_num+RATE);
}

handle_drain_ping_req(string drain_key) {
    // respond to ping with max power capacity
    //sayDebug(DEBUG, "handle_drain_ping_req");
    llRegionSayTo(drain_key, POWER_CHANNEL, PING+ACK+"["+(string)MAX_POWER_CAPACITY+"]");
}

add_drain(string drain_key, string drain_name) {
    sayDebug(DEBUG, "add_drain ("+drain_key+", "+drain_name+")");
    if (drain_key) {
        num_connected_drains = num_connected_drains + 1;
        llLinksetDataWrite(DRAIN+(string)num_connected_drains+KEY, drain_key); 
        llLinksetDataWrite(DRAIN+(string)num_connected_drains+NAME, drain_name); 
        llLinksetDataWrite(DRAIN+(string)num_connected_drains+DEMAND, "0"); 
        llLinksetDataWrite(DRAIN+(string)num_connected_drains+RATE, "0"); 
        llLinksetDataWrite("num_connected_drains", (string)num_connected_drains); 
    }
}
delete_drain(integer drain_num) {
    integer i;
    for (i = drain_num; i < num_connected_drains; i = i + 1) {
        llLinksetDataWrite(DRAIN+(string)i+KEY, connected_drain_key(i+1)); 
        llLinksetDataWrite(DRAIN+(string)i+NAME, connected_drain_name(i+1)); 
        llLinksetDataWrite(DRAIN+(string)i+DEMAND, (string)connected_drain_demand(i+1)); 
        llLinksetDataWrite(DRAIN+(string)i+RATE, (string)connected_drain_rate(i+1));  
    }
    llLinksetDataDelete(DRAIN+(string)num_connected_drains+KEY);
    llLinksetDataDelete(DRAIN+(string)num_connected_drains+NAME);
    llLinksetDataDelete(DRAIN+(string)num_connected_drains+DEMAND);
    llLinksetDataDelete(DRAIN+(string)num_connected_drains+RATE);
    num_connected_drains = num_connected_drains - 1;
    llLinksetDataWrite("num_connected_drains", (string)num_connected_drains); 
}

update_drain_power_rate(integer drain_num, integer rate) {
    sayDebug(DEBUG,"update_drain_power_rate "+connected_drain_name(drain_num)+" to "+engFormat(rate));
    llLinksetDataWrite(DRAIN+(string)drain_num+RATE, (string)rate); 
    string message = POWER+ACK+"["+(string)rate+"]";
    llRegionSayTo(connected_drain_key(drain_num), POWER_CHANNEL, message);
}

calculate_drain_power_demand() {
    // calculate the total power demanded by drains
    // Called by connect-req and disconnect-req
    connected_drain_power_demand = 0;
    integer drain_num;
    for (drain_num = 1; drain_num <= num_connected_drains; drain_num = drain_num + 1) {
        connected_drain_power_demand = connected_drain_power_demand + connected_drain_demand(drain_num);
    }
    sayDebug(DEBUG, "calculate_drain_power_demand() returns "+engFormat(connected_drain_power_demand));
}

calculate_drain_power_rate() {
    // calculate the total power used by drains
    // Called by connect-req and disconnect-req
    connected_drain_power_rate = 0;
    integer drain_num;
    for (drain_num = 1; drain_num <= num_connected_drains; drain_num = drain_num + 1) {
        connected_drain_power_rate = connected_drain_power_rate + connected_drain_rate(drain_num);
    }
    sayDebug(DEBUG, "calculate_drain_power_rate "+engFormat(connected_drain_power_rate));

    if (connected_drain_power_rate > connected_source_power_capacity) {
        sayDebug(WARN, "handle_source_power_ack drain rate"+
            engFormat(connected_drain_power_rate) + " > source rate" +
            engFormat(connected_source_power_rate) );
        switch_power(0);
        return;
    }
}

handle_drain_connect_req(string drain_key, string objectName) {
    // a power drain wants to connect. 
    // add it to our list of power drains
    sayDebug(DEBUG, "handle_drain_connect_req("+(string)drain_key+", "+objectName+")");
    llPlaySound(kill_switch_1, 1);
    if (drain_key_index(drain_key) > -1) {
        sayDebug(DEBUG, "Reconnecting Drain " + objectName);
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

handle_disconnect_req(string objectKey, string objectName) {
    // a source or drain drain requests disconnect. 
    // Remove it from our list of drains. 
    sayDebug(DEBUG, "handle_disconnect_req("+objectKey+", "+objectName+")");
    llPlaySound(kill_switch_1, 1);
    integer drain_num = drain_key_index(objectKey);
    integer source_num = connected_source_key_index(objectKey);
    if (drain_num > -1) {
        update_drain_power_rate(drain_num, 0);
        delete_drain(drain_num);
        calculate_drain_power_demand();
        calculate_drain_power_rate();
        request_power_from_sources();
        sayDebug(DEBUG, "handle_disconnect_req("+objectName+") succeeded.");
    } else if (source_num > -1) {
        delete_connected_source(source_num);
        request_power_from_sources();
        sayDebug(DEBUG, "handle_disconnect_req("+objectName+") succeeded.");
    }
    llRegionSayTo(objectKey, POWER_CHANNEL, DISCONNECT+ACK);
}

handle_drain_power_request(string drain_key, string objectName, integer powerRequest) {
    // a source is asking for power. 
    sayDebug(DEBUG, "handle_drain_power_request("+objectName+", "+engFormat(powerRequest)+")");
    integer drain_num = drain_key_index(drain_key);
    if (drain_num > 0) {
        llLinksetDataWrite(DRAIN+(string)drain_num+DEMAND, (string)powerRequest); 
        calculate_drain_power_demand();
        request_power_from_sources(); // this will come back as POWER+ACK and be handled in handle_source_power_ack()
    }
}

cut_all_drain_power() 
// Switch off all outging power. 
// switch_power calls this. 
// Sends Power-ACK[0] to all drains. 
{
    sayDebug(DEBUG, "cut_all_drain_power");
    integer drain_num;
    for (drain_num = 1; drain_num <= num_connected_drains; drain_num = drain_num + 1) {
        update_drain_power_rate(drain_num, 0);
    }    
}

update_all_drain_powers() {
    // When we get a source power update, we need to recalculate drain powers. 
    // But these can come in clusters, so we want to do this only once. 
    // So instead of calling update_drain_power, set a timer event. 
    // Every update will resets the timer. 
    // When the timer runs out, we get called and call update_drain_power_rate. 
    sayDebug(DEBUG,"update_all_drain_powers "+on_off_string(power_switch_state)); 
    calculate_drain_power_demand();
    calculate_source_power_rate();
    integer drain_num;
    if (power_switch_state) {
        if (connected_source_power_rate >= connected_drain_power_demand) {
            for (drain_num = 1; drain_num <= num_connected_drains; drain_num = drain_num + 1) {
                integer demand = connected_drain_demand(drain_num);
                integer rate = connected_drain_rate(drain_num);
                string name = connected_drain_name(drain_num);
                sayDebug(DEBUG, "update_all_drain_powers "+name+":"+engFormat(demand)+"/"+engFormat(rate));
                if (rate != demand) {
                    update_drain_power_rate(drain_num, demand);
                }
            }
        } else {
                sayDebug(DEBUG, "update_all_drain_powers not enough supplied power");
                cut_all_drain_power();
        }
    } else {
        sayDebug(DEBUG, "update_all_drain_powers off");
        cut_all_drain_power();
    }
    llSetTimerEvent(0); // we've handled all pending source power requests
    calculate_drain_power_rate();
}

string list_drains() {
    string result;
    result = result + "\n-----\nPower Drains: rate/demand";
    integer drain_num;
    if (num_connected_drains > 0) {
        for (drain_num = 1; drain_num <= num_connected_drains; drain_num = drain_num + 1) {
            result = result + "\n" +  
                formatDebug(TRACE,  "["+connected_drain_key(drain_num)+"] ") +
                connected_drain_name(drain_num) + ": " + 
                engFormat(connected_drain_rate(drain_num))+ "/" + 
                engFormat(connected_drain_demand(drain_num));
        }
        result = result + "\n" +   "Total Power: "+
            engFormat(connected_drain_power_rate)+ "/" + 
            engFormat(connected_drain_power_demand);
    } else {
        result = result + "\n" +  "No Power Drains Connected.";
    }
    return result;
}

switch_power(integer new_power_switch_state) {
    sayDebug(DEBUG, "switch_power("+on_off_string(new_power_switch_state)+")");
    llPlaySound(kill_switch_1, 1);
    power_switch_state = new_power_switch_state;
    llLinksetDataWrite("power_switch_state",(string)power_switch_state);
    integer drain_num;
    if (power_switch_state) {
        // switch on
        // request power from sourcs
        request_power_from_sources();
        // When the source sends ack, we will then send power-acks to the drains. 
    } else {
        // Cut power to all the drains.
        // This is fine. This is what we want to to. 
        cut_all_drain_power();
        // Cut power from all the sources
        // This is fine., This is what we want to do. 
        integer souce_num;
        for (souce_num = 1; souce_num <= num_connected_sources; souce_num = souce_num + 1) {
            string source_key = connected_source_key(souce_num);
            llRegionSayTo(source_key, POWER_CHANNEL, POWER+REQ+"[0]");
        }
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

string on_off_string(integer power_state)  {
    if (power_state) {
        return "On";
    } else {
        return "Off";
    }
}

string engFormat(integer quantity) {
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
    status = status + "\n" + "Debug Level:"+llList2String(debug_levels, debug_level);
    status = status + "\n" + "Power: " + on_off_string(power_switch_state);
    status = status + "\n" + "Maximum Power: "+ engFormat(MAX_POWER_CAPACITY);
    status = status + "\n" + "Input Power: "+ engFormat(connected_source_power_rate);
    status = status + "\n" + "Output Power: "+ engFormat(connected_drain_power_rate);
    status = status + list_known_sources();
    status = status + list_connected_sources();
    status = status + list_drains();
    sayDebug(INFO, status);
    status = "";
    sayDebug(INFO, "Free Memory: " + (string)llGetFreeMemory());
}

default
{
    state_entry()
    {
        debug_level = (integer)llLinksetDataRead(DEBUG_LEVELS);
        setDebugLevel(debug_level);
        sayDebug(DEBUG, "state_entry");
        
        // Script name is like "DistributionPanelLogic 2025-02-09"
        string logicScriptName = llGetScriptName();
        sayDebug(DEBUG, "state_entry logicScriptName:"+logicScriptName);
        llLinksetDataWrite("logicScriptName", logicScriptName);
        
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
        num_known_sources = (integer)llLinksetDataRead("num_known_sources");
        num_connected_sources = (integer)llLinksetDataRead("num_connected_sources");
        num_connected_drains = (integer)llLinksetDataRead("num_connected_drains");
        power_switch_state = (integer)llLinksetDataRead("power_switch_state");
        calculate_drain_power_demand();
        calculate_source_power_capacity();
        calculate_source_power_rate();
        request_power_from_sources();
        sayDebug(DEBUG, "state_entry done. Free Memory: " + (string)llGetFreeMemory());
    }
    
    link_message(integer Sender, integer Number, string message, key objectKey) {
        sayDebug(DEBUG, "link_message "+(string)Number+" "+message);
        if (message == "Status") {
            report_status();
        } else if (message == "Reset") {
            //sayDebug(DEBUG,"Resetting");
            delete_known_sources();
            delete_connected_sources();
            delete_connected_drains();
            llResetScript();
        } else if (message == DEBUG_LEVELS) {
            setDebugLevel(Number);
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
            //sayDebug(DEBUG, "listen \""+name+"\" says \""+message + "\"");
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
        // Called after power acks
        update_all_drain_powers();
    }
}
