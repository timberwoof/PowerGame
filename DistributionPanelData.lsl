// Power Distribution Panel Connections
// This module is all about maintaining connecitons and doing calculations 

string debug_string = "Info";

// Common Constants for the Power System 
integer POWER_CHANNEL = -654647;
integer MONITOR_CHANNEL = -6546478;
float ping_ack_delay = 1; // pings come in fast and when they're over they're over
float src_ack_delay = 1; // source acks don't bounce around much.
float req_ack_delay = 1; // these come in fast if someone's moving around lights with sensors. 

float switch_delay = 0.0; // sleep between setting breakers in a loop
integer pingAcks = FALSE;
integer drainPowerReqs = FALSE;
integer sourcePowerAcks = FALSE;

string REQ = "-REQ";
string ACK = "-ACK";
string PING = "Ping";
string CONNECT = "Connect";
string DISCONNECT = "Disconnect";
string POWER = "Power";

string RESET = "Reset";
string NONE = "None";
string CONNECT_SOURCE = "Connect Src";
string DISCONNECT_SOURCE = "Disc Src";
string DISCONNECT_DRAIN = "Disc Drain";

string KNOWN = "Known";
string SOURCE = "Source";
string DRAIN = "Drain";
string KEY = "Key";
string NAME = "Name";
string DISTANCE = "Distance";
string CAPACITY = "Capacity";
string DEMAND = "Demand";
string RATE = "Rate";

// Sounds for Power Distribution Panel
string kill_switch_bonk = "4690245e-a161-87ce-e392-47e2a410d981";
string kill_switch_wheff = "00800a8c-1ac2-ff0a-eed5-c1e37fef2317";
string breaker_1 = "238d4742-c609-fe39-7094-259ca80a9a69";

// *********************************
// Debug system
// Higher numbers are lower priority.
integer ERROR = 0;
integer WARN = 1;
integer INFO = 2;
integer DEBUG = 3;
integer TRACE = 4;
string DEBUG_LEVELS = "DebugLevels";
list debug_levels = ["ERROR", "WARN", "INFO", "DEBUG", "TRACE"];
integer debug_level = 2; // debug normally 2 info. 

sayDebug(integer message_level, string message) {
    message = "DATA "+llList2String(debug_levels, message_level) + ": " + message;
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

setDebugLevel(integer new_debug_level) {
    debug_level = new_debug_level;
}

// ********************************
// Known Power Sources
integer num_known_sources = 0; // 1-based in numbering

delete_known_sources(integer warn) {
    if (warn) {
        sayDebug(WARN, "Deleting Known Sources.");
    }
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

integer get_known_source_key_index(string source_key) {
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
string get_known_source_name(integer source_num) {
    return llLinksetDataRead(KNOWN+(string)source_num+NAME);
}
integer get_known_source_power(integer source_num) {
    return (integer)llLinksetDataRead(KNOWN+(string)source_num+POWER);
}
integer get_known_source_distance(integer source_num) {
    return (integer)llLinksetDataRead(KNOWN+(string)source_num+DISTANCE);
}

add_known_source(string source_key, string source_name, integer source_power, float source_distance){
    string filter = llGetObjectDesc();
    if (llSubStringIndex(source_name, filter) == -1) {
        //sayDebug(TRACE, "AKS Ignored ping from " + source_name + " because its name did not contain " + filter);
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

list get_known_source_distance_index; // local to Menu
sort_known_sources() {
    // sort the indexes list so we can present known sources in distance order
    get_known_source_distance_index = []; // zero-based
    integer i;
    for (i = 1; i <= num_known_sources; i = i + 1) {
        get_known_source_distance_index = get_known_source_distance_index + [i, get_known_source_distance(i)];
    }
    get_known_source_distance_index = llListSortStrided(get_known_source_distance_index, 2, 1, TRUE);
    //sayDebug(DEBUG,"SKS:"+(string)get_known_source_distance_index);
}

integer unsorted(integer i) {
    // given a sorted index, return the unsorted index
    return llList2Integer(get_known_source_distance_index, i*2-2);
}

list_known_sources() {
    string result;
    result = result + "\nKnown Power Sources: capacity, distance";
    if (num_known_sources > 0) {
        sort_known_sources();
        integer source_num;
        if (num_known_sources > 12) {
            num_known_sources = 12;
        }
        for (source_num = 1; source_num <= num_known_sources; source_num = source_num + 1) {
            integer unsorted_index = unsorted(source_num);
            result = result + "\n" + 
                get_known_source_name(unsorted_index) + ": " + 
                engFormat(get_known_source_power(unsorted_index))+", " + 
                (string)get_known_source_distance(unsorted_index)+"m";
        }
        get_known_source_distance_index = [];
    } else {
        result = result + "\nNo Power Sources known.";
    }
   sayDebug(INFO, result);
   result = "";
}

send_source_ping_req() {
    // Send a request for nearby power sources
    delete_known_sources(0);
    llShout(POWER_CHANNEL, PING+REQ);
}

handle_source_ping_ack(string source_key, string source_name, integer source_power) {
    // add to our list of known sources
    sayDebug (TRACE, "handle_source_ping_ack("+source_name+") "+engFormat(source_power));
    list source_details = llGetObjectDetails(source_key, [OBJECT_POS]);    
    vector source_position = llList2Vector(source_details, 0);
    integer source_distance = llFloor(llVecDist(llGetPos(), source_position));
    add_known_source(source_key, source_name, source_power, source_distance);
    pingAcks = TRUE;
    llSetTimerEvent(ping_ack_delay);
}

// **********************
// Conected Power Sources
integer num_sources = 0;

delete_sources() {
    sayDebug(WARN,"Deleting Connected Sources.");
    integer i;
    for (i = 0; i <= 100; i = i + 1) {
        llLinksetDataDelete(SOURCE+(string)i+KEY);
        llLinksetDataDelete(SOURCE+(string)i+NAME);
        llLinksetDataDelete(SOURCE+(string)i+CAPACITY);
        llLinksetDataDelete(SOURCE+(string)i+RATE);
    }
    num_sources = 0;
    llLinksetDataWrite("num_sources", (string)num_sources);
}

integer get_source_key_index(string source_key) {
    if (num_sources == 0) {
        return -1;
    }
    integer i;
    for (i = 1; i <= num_sources; i = i + 1) {
        if (llLinksetDataRead(SOURCE+(string)i+KEY) == source_key) {
            return i;
        }
    }
    return -1;
}

string get_source_key(integer source_num) {
    return llLinksetDataRead(SOURCE+(string)source_num+KEY);
}
string get_source_name(integer source_num) {
    return llLinksetDataRead(SOURCE+(string)source_num+NAME);
}
integer get_source_capacity(integer source_num) {
    return (integer)llLinksetDataRead(SOURCE+(string)source_num+CAPACITY);
}
integer get_source_rate(integer source_num) {
    return (integer)llLinksetDataRead(SOURCE+(string)source_num+RATE);
}

upsert_source(key source_key, string source_name, integer source_capacity, integer source_rate) {
    integer index = get_source_key_index(source_key);
    if (index < 0) {
        num_sources = num_sources + 1;
        llLinksetDataWrite("num_sources", (string)num_sources);
        index = num_sources;
    }
    llLinksetDataWrite(SOURCE+(string)index+KEY, source_key); 
    llLinksetDataWrite(SOURCE+(string)index+NAME, source_name); 
    llLinksetDataWrite(SOURCE+(string)index+CAPACITY, (string)source_capacity); 
    llLinksetDataWrite(SOURCE+(string)index+RATE, (string)0); 
}

delete_source(integer source_num) {
    integer i;
    // From the source-to-be-deleted to the end, shift them down one. 
    for (i = source_num; i < num_sources; i = i + 1) {
        llLinksetDataWrite(SOURCE+(string)i+KEY, get_source_key(i+1)); 
        llLinksetDataWrite(SOURCE+(string)i+NAME, get_source_name(i+1)); 
        llLinksetDataWrite(SOURCE+(string)i+CAPACITY, (string)get_source_capacity(i+1)); 
        llLinksetDataWrite(SOURCE+(string)i+RATE, (string)get_source_rate(i+1));  
    }
    num_sources = num_sources - 1;
    llLinksetDataWrite("num_sources", (string)num_sources);
}

handle_source_connect_ack(string source_key, string source_name, integer source_capacity) {
    // a source said yes to connection request.
    // Add it to our list of sources and recalculate power capacity
    sayDebug(DEBUG, "handle_source_connect_ack("+source_name+"): "+engFormat(source_capacity));

    // Handle bad requests
    if (get_known_source_key_index(source_key) < 0) {
        sayDebug(WARN, "handle_source_connect_ack "+source_name+" was not known."); // error
        return;
    }
    if (get_drain_key_index(source_key) >= 0) {
        sayDebug(WARN, "handle_source_connect_ack "+source_name+" was already connected as a Drain.");
        // weird as hell but we need to defend against it.
        return;
    }        
    // register the source
    llPlaySound(breaker_1, 1);
    upsert_source(source_key, source_name, source_capacity, 0);
    calculate_source_power_capacity();
    // calculate_source_power_rate when that's done
}

handle_disconnect_ack(string source_key) {
    // a source acknowledges disconnection
    // delete from list of sources and recalculate capacity
    //sayDebug(DEBUG, "handle_disconnect_ack("+(string)source_key+", "+objectName+")");

    integer source_num = get_source_key_index(source_key);
    if (source_num > -1) {
        string sourceName = get_source_name(source_num);
        sayDebug(DEBUG, "handle_disconnect_ack disconnecting "+sourceName);
        llPlaySound(breaker_1, 1);
        delete_source(source_num);
        calculate_source_power_capacity();
        calculate_source_power_rate();
        llMessageLinked(LINK_SET, source_num, "handle_disconnect_ack", source_key);
    } else {
        sayDebug(WARN, "handle_disconnect_ack a source was not connected.");
    }
}

list_sources() {
    string result =  "\nConnected Power Sources: rate/capacity";
    integer source_num;
    if (num_sources > 0) {
        for (source_num = 1; source_num <= num_sources; source_num = source_num + 1) {
            result = result + "\n" + 
                get_source_name(source_num) + ": " + 
                engFormat(get_source_rate(source_num))+"/" + 
                engFormat(get_source_capacity(source_num));
        }
    } else {
        result = result + "\nNo Power Sources Connected.";
    }
   sayDebug(INFO, result);
   result = "";
}

// *************************
// conected drains
integer num_drains = 0;

delete_drains() {
    sayDebug(WARN,"Deleting Connected Drains.");
    integer i;
    for (i = 0; i <= 100; i = i + 1) {
        llLinksetDataDelete(DRAIN+(string)i+KEY);
        llLinksetDataDelete(DRAIN+(string)i+NAME);
        llLinksetDataDelete(DRAIN+(string)i+DEMAND);
        llLinksetDataDelete(DRAIN+(string)i+RATE);
    }
    num_drains = 0;
    llLinksetDataWrite("num_drains", (string)num_drains);
}

integer get_drain_key_index(string drain_key) {
    if (num_drains == 0) {
        return -1;
    }
    integer i;
    for (i = 1; i <= num_drains; i = i + 1) {
        if (llLinksetDataRead(DRAIN+(string)i+KEY) == drain_key) {
            return i;
        }
    }
    return -1;
}
string get_drain_key(integer drain_num) {
    return llLinksetDataRead(DRAIN+(string)drain_num+KEY);
}
string get_drain_name(integer drain_num) {
    return llLinksetDataRead(DRAIN+(string)drain_num+NAME);
}
integer get_drain_demand(integer drain_num) {
    return (integer)llLinksetDataRead(DRAIN+(string)drain_num+DEMAND);
}
integer get_drain_rate(integer drain_num) {
    return (integer)llLinksetDataRead(DRAIN+(string)drain_num+RATE);
}

handle_ping_req(string object_key, string object_name) {
    // respond to ping with max power capacity
    //sayDebug(DEBUG, "HPR");
    integer sourceIndex = get_source_key_index(object_key);
    if (sourceIndex > -1) {
        // if this ping was from a source I knew about
        // then make sure it knows about me.
        sayDebug(DEBUG, "handle_ping_req sends \""+CONNECT+REQ+ "\" to "+object_name);
        llRegionSayTo(object_key, POWER_CHANNEL, CONNECT+REQ);
        llSleep(1.0);
        llMessageLinked(LINK_SET, sourceIndex, "handle_ping_req", object_key);
    } else {
        // this came from a drain, so send it an ack
        string message = PING+ACK+"["+llLinksetDataRead("source_power_capacity")+"]";
        sayDebug(DEBUG, "handle_ping_req sends \""+message+ "\" to "+object_name);
        llRegionSayTo(object_key, POWER_CHANNEL, message);
    }

}

upsert_drain(string drain_key, string drain_name) {
    sayDebug(TRACE, "upsert_drain ("+drain_key+", "+drain_name+")");
    integer index = get_drain_key_index(drain_key);
    if (index < 0) {
        // a new drain
        num_drains = num_drains + 1;
        llLinksetDataWrite("num_drains", (string)num_drains);
        index = num_drains;
        llLinksetDataWrite(DRAIN+(string)index+DEMAND, "0"); 
        llLinksetDataWrite(DRAIN+(string)index+RATE, "0"); 
    }
    llLinksetDataWrite(DRAIN+(string)index+KEY, drain_key); 
    llLinksetDataWrite(DRAIN+(string)index+NAME, drain_name);
}

delete_drain(integer drain_num) {
    integer i;
    for (i = drain_num; i < num_drains; i = i + 1) {
        llLinksetDataWrite(DRAIN+(string)i+KEY, get_drain_key(i+1)); 
        llLinksetDataWrite(DRAIN+(string)i+NAME, get_drain_name(i+1)); 
        llLinksetDataWrite(DRAIN+(string)i+DEMAND, (string)get_drain_demand(i+1)); 
        llLinksetDataWrite(DRAIN+(string)i+RATE, (string)get_drain_rate(i+1));  
    }
    llLinksetDataDelete(DRAIN+(string)num_drains+KEY);
    llLinksetDataDelete(DRAIN+(string)num_drains+NAME);
    llLinksetDataDelete(DRAIN+(string)num_drains+DEMAND);
    llLinksetDataDelete(DRAIN+(string)num_drains+RATE);
    num_drains = num_drains - 1;
    llLinksetDataWrite("num_drains", (string)num_drains); 
}

handle_drain_connect_req(string drain_key, string objectName) {
    // a power drain wants to connect or reconnect
    // add it or update it in our list of power drains
    sayDebug(DEBUG, "handle_drain_connect_req("+objectName+")");//+(string)drain_key+", "
    llPlaySound(breaker_1, 1);
    if (get_source_key_index(drain_key) > -1) {
        sayDebug(WARN, objectName+" was already connected as a Source.");
    } else {
        upsert_drain(drain_key, objectName);    
        string message = CONNECT+ACK+"["+llLinksetDataRead("source_power_capacity")+"]";
        sayDebug(TRACE, "Sending Drain " + objectName + " \"" + message +"\"");
        llRegionSayTo(drain_key, POWER_CHANNEL, message);
    }
}

handle_disconnect_req(string objectKey) {
    // a source or drain drain requests disconnect. 
    // or a menu requested a disconnect. 
    // Remove it from our list of drains
    // and ask Logic to recalculate. 
    sayDebug(DEBUG, "handle_disconnect_req()");
    llPlaySound(breaker_1, 1);
    integer drain_num = get_drain_key_index(objectKey);
    integer source_num = get_source_key_index(objectKey);
    string objectName = llKey2Name(objectKey);
    if (drain_num > -1) {
        delete_drain(drain_num);
        llMessageLinked(LINK_SET, 0, "handle_disconnect_req_drain", NULL_KEY);
        sayDebug(DEBUG, "handle_disconnect_req drain ("+objectName+") succeeded.");
    } else if (source_num > -1) {
        delete_source(source_num);
        llMessageLinked(LINK_SET, 0, "handle_disconnect_req_source", NULL_KEY);
        sayDebug(WARN, "handle_disconnect_req source ("+objectName+") succeeded.");
    } else {
        sayDebug(WARN, "handle_disconnect_req unknown object ("+objectName+") attempted disconnect");
    }
    llRegionSayTo(objectKey, POWER_CHANNEL, DISCONNECT+ACK);
}

list_drains() {
    string result;
    result ="\nPower Drains: rate/demand";
    integer drain_num;
    if (num_drains > 0) {
        for (drain_num = 1; drain_num <= num_drains; drain_num = drain_num + 1) {
            result = result + "\n" + 
                get_drain_name(drain_num) + ": " + 
                engFormat(get_drain_rate(drain_num))+ "/" + 
                engFormat(get_drain_demand(drain_num));
        }
    } else {
        result = result + "\nNo Power Drains Connected.";
    }
    sayDebug(INFO, result);
    result = "";
}

// ***********************************
// Communications to Logic
req_power_from_sources(integer power) {
    llMessageLinked(LINK_SET, power, "req_power_from_sources", NULL_KEY);
}

calculate_source_power_rate() {
     llMessageLinked(LINK_SET, 1, "calculate_source_power_rate", NULL_KEY);
}

calculate_source_power_capacity(){
     llMessageLinked(LINK_SET, 1, "calculate_source_power_capacity", NULL_KEY);
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

string on_off_string(integer pwr_state)  {
    if (pwr_state) {
        return "On";
    } else {
        return "Off";
    }
}

string engFormat(integer quantity) {
// present quantity in engineering notation with suffix
    list divisors = [1.0, 1000.0, 1000000.0]; // force floating-point division ...
    list suffixes = ["W", "kW", "MW"];
    integer index = llFloor(llLog10(quantity) / 3);
    float divisor = llList2Float(divisors, index);
    string suffix = llList2String(suffixes, index);
    float scaledQuantity = quantity / divisor;  // ... because we don't want to lose precision here
    // limit it to 4 characters. 
    string formattedQuantity = llGetSubString((string)scaledQuantity, 0, 3);
    // chop off .0
    integer dotzero = llSubStringIndex(formattedQuantity, ".0");
    if (dotzero > 0) {
        formattedQuantity = formattedQuantity = llGetSubString(formattedQuantity, 0, dotzero-1);
    }
    // chop off a trailing .
    if (llGetSubString(formattedQuantity, -1, -1) == ".") {
        formattedQuantity = formattedQuantity = llGetSubString(formattedQuantity, 0, 2);
    }
    return formattedQuantity+suffix;
}

report_status() {
    string status;
    status = status + "\nDevice Report for "+llGetObjectName()+":";
    status = status + "\nDebug Level:"+llList2String(debug_levels, debug_level);
    status = status + "\nFree Memory: " + (string)llGetFreeMemory();
    sayDebug(INFO, status);
    list_known_sources();
    list_sources();
    list_drains();
}

default
{
    state_entry()
    {
        debug_level = (integer)llLinksetDataRead(DEBUG_LEVELS);
        setDebugLevel(debug_level);
        sayDebug(DEBUG, "state_entry");
        
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
        send_source_ping_req();
        num_known_sources = (integer)llLinksetDataRead("num_known_sources");
        num_sources = (integer)llLinksetDataRead("num_sources");
        num_drains = (integer)llLinksetDataRead("num_drains");
        sayDebug(DEBUG, "state_entry done. Free Memory: " + (string)llGetFreeMemory());
    }
    
    link_message(integer Sender, integer Number, string message, key objectKey) {
        sayDebug(TRACE, "link_message "+(string)Number+" "+message);
        if (message == "Status") {
            report_status();
        } else if (message == "reset_data") {
            sayDebug(DEBUG,"Resetting Data");
            delete_known_sources(1);
            delete_sources();
            delete_drains();
        } else if (message == DEBUG_LEVELS) {
            setDebugLevel(Number);
        } else if (message == PING) {
            send_source_ping_req();
            
        // menu requests - DISCONNECT+REQ could come from source or drain
        } else if (message == "handle_disconnect_req") {
            handle_disconnect_req(objectKey);

        // We ignore these because they are for Logic
        } else if (message == "Power") {
            sayDebug(TRACE, "link_message ignored");
        } else if (message == "handle_disconnect_ack") {
            sayDebug(TRACE, "link_message ignored");
        } else if (message == "calculate_source_power_capacity") {
            sayDebug(TRACE, "link_message ignored");
        } else if (message == "delete_drain") {
            sayDebug(TRACE, "link_message ignored");
        } else if (message == "handle_ping_req") {
            sayDebug(TRACE, "link_message ignored");
        // we send these once we know whether source or drain was disconnected.
        } else if (message == "handle_disconnect_req_drain") {
            sayDebug(TRACE, "link_message ignored");
        } else if (message == "handle_disconnect_req_source") {
            sayDebug(TRACE, "link_message ignored");
        } else {
            sayDebug(ERROR, "link_message did not handle link message "+(string)Number+", "+message);
        }
    }

    listen(integer channel, string name, key objectKey, string message )
    {
        if (channel == POWER_CHANNEL) {
            string trimmed_message = trimMessageParameters(message);
            integer parameter = getMessageParameter(message);
            sayDebug(TRACE, "listen \""+name+"\" says \""+message + "\"");
            if (message == PING+REQ) {
                handle_ping_req(objectKey, name);
            } else if (trimmed_message == PING+ACK) {
                handle_source_ping_ack(objectKey, name, parameter);
            } else if (trimmed_message == CONNECT+REQ) {
                handle_drain_connect_req(objectKey, name);
            } else if (trimmed_message == CONNECT+ACK) {
                handle_source_connect_ack(objectKey, name, parameter);
            } else if (trimmed_message == DISCONNECT+REQ) {
                handle_disconnect_req(objectKey); // don't know whether it was source or drain
            } else if (trimmed_message == DISCONNECT+ACK) {
                handle_disconnect_ack(objectKey);
            } else if (trimmed_message == POWER+ACK) {
                sayDebug(TRACE, "listen ignored");
            } else if (trimmed_message == POWER+REQ) {
                sayDebug(TRACE, "listen ignored");
            } else if (message == "delete_drain") {
                sayDebug(TRACE, "listen ignored");
            } else {
                sayDebug(TRACE, "listen did not handle power channel message:"+message);
            }
        }
    }
    
    timer() {
        //sayDebug(TRACE, "timer waiting for "+timer_waiting_for);
        // handle_souce_ping_ack
        if (pingAcks) {
            sayDebug(TRACE, "timer() handles pingAcks");
            pingAcks = FALSE;
            calculate_source_power_capacity();
        }
        
        if (!(pingAcks | drainPowerReqs | sourcePowerAcks)) {
            llSetTimerEvent(0);
        }
    }
}
