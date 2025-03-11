// Power Distribution Panel Logic
// This module is all about maintaining connecitons and doing calculateulations 

string debug_string = "Info";

// Global Constants and Variables for Power Distribution Oanel
integer MAX_power_capacity = 1000000; // 1MW how much power we can transfer total
integer power_switch_state;

// Common Constants for the Power System 
integer POWER_CHANNEL = -654647;
integer MONITOR_CHANNEL = -6546478;
float source_ack_delay = 1; // source acks don't bounce around much.
float request_ack_delay = 1; // these come in fast if someone's moving around lights with sensors. 

float switch_delay = 0.0; // sleep between setting breakers in a loop
integer drainPowerReqs = FALSE;
integer sourcePowerAcks = FALSE;

string ACK = "-ACK";
string REQ = "-REQ";
string POWER = "Power";
string PING = "Ping";
string CONNECT = "Connect";
string DISCONNECT = "Disconnect";

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
    message = "LOGIC "+llList2String(debug_levels, message_level) + ": " + message;
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
integer get_known_source_key_index(string source_key) {
    integer num_known_sources = (integer)llLinksetDataRead("num_known_sources");
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

// **********************
// Conected Power Sources
integer source_power_capacity = 0;
integer source_power_rate = 0;

delete_sources() {
    integer i;
    for (i = 0; i <= 100; i = i + 1) {
        llLinksetDataDelete(SOURCE+(string)i+KEY);
        llLinksetDataDelete(SOURCE+(string)i+NAME);
        llLinksetDataDelete(SOURCE+(string)i+CAPACITY);
        llLinksetDataDelete(SOURCE+(string)i+RATE);
    }
    llLinksetDataWrite("num_sources", "0");
    source_power_capacity = 0;
    source_power_rate = 0;
}

integer get_num_sources() {
    return (integer)llLinksetDataRead("num_sources");
}

integer get_source_key_index(string source_key) {
    integer num_sources = get_num_sources();
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

handle_ping_request(key object_key, integer source_index){
    string message = POWER+REQ+"["+(string)get_source_rate(source_index)+"]";
    string object_name = get_source_name(source_index);
    sayDebug(DEBUG, "handle_ping_request sends \""+message+ "\" to "+object_name);
    llRegionSayTo(object_key, POWER_CHANNEL, message);
}

upsert_source(key source_key, string source_name, integer source_capacity, integer source_rate) {
    integer num_sources = get_num_sources();
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

calculate_source_power_capacity() {
    // calculateulate the total we could receive from all the connected sources
    // Called by connect-ack and DISCONNECT-ack
    sayDebug(DEBUG, "calculate_source_power_capacity");
    source_power_capacity = 0;
    integer source_num;
    integer num_sources = get_num_sources();
    for (source_num = 1; source_num <= num_sources; source_num = source_num + 1) {
        integer source_capacity = get_source_capacity(source_num);
        source_power_capacity = source_power_capacity + source_capacity;
        sayDebug(TRACE, "calculate_source_power_capacity "+(string)source_num+": "+(string)source_capacity);
    }
    llLinksetDataWrite("source_power_capacity",(string)source_power_capacity);
    sayDebug(DEBUG, "calculate_source_power_capacity() = "+engFormat(source_power_capacity));
}

calculate_source_power_rate() {
    // calculateulate the total we are receiving from all the sources
    source_power_rate = 0;
    integer source_num;
    integer num_sources = get_num_sources();
    for (source_num = 1; source_num <= num_sources; source_num = source_num + 1) {
        //sayDebug(TRACE, "calculate_source_power_rate " + get_source_name(source_num) + " " + engFormat(get_source_rate(source_num)));
        source_power_rate = source_power_rate + get_source_rate(source_num);
    }
    sayDebug(DEBUG, "calculate_source_power_rate() = "+engFormat(source_power_rate));
}

handle_source_connect_ack(string source_key, string source_name, integer source_capacity) {
    // a source said yes to connection request.
    // Add it to our list of sources and recalculateulate power capacity
    sayDebug(DEBUG, "handle_source_connect_ack("+source_name+"): "+engFormat(source_capacity));

    // Handle bad requests
    if (get_known_source_key_index(source_key) < 0) {
        sayDebug(WARN, "HSCA "+source_name+" was not known."); // error
        return;
    }
    if (get_drain_key_index(source_key) >= 0) {
        sayDebug(WARN, "HSCA "+source_name+" was already connected as a Drain.");
        // weird as hell but we need to defend against it.
        return;
    }        
    // register the source
    llPlaySound(breaker_1, 1);
    upsert_source(source_key, source_name, source_capacity, 0);
    calculate_source_power_capacity();
    request_power_from_sources(drain_power_demand);
    // calculate_source_power_rate when that's done
}

handle_disconnect_ack(string source_key) {
    // a source acknowledges disconnection
    // delete from list of sources and recalculateulate capacity
    //sayDebug(DEBUG, "HDA("+(string)source_key+", "+objectName+")");

    integer source_num = get_source_key_index(source_key);
    string objectName = llKey2Name(source_key);
    if (source_num > -1) {
        sayDebug(DEBUG, "handle_disconnect_ack disconnecting "+objectName);
        calculate_source_power_capacity();
        calculate_source_power_rate();
        request_power_from_sources(drain_power_demand);
    } else {
        sayDebug(DEBUG, "handle_disconnect_ack ("+objectName+") was not connected.");
    }
}

handle_source_power_ack(string source_key, string source_name, integer source_power) {
    // a source answers power request
    // update the connected-Sources list with that power
    // if possible, supply power to drains 
    
    sayDebug(DEBUG, "handle_source_power_ack("+source_name+", "+engFormat(source_power)+")");
    integer source_num = get_source_key_index(source_key);
    integer thatRate = get_source_rate(source_num);
    sayDebug(DEBUG, "handle_source_power_ack updates "+engFormat(thatRate)+" to "+engFormat(source_power));
    string symbol = SOURCE+(string)source_num+RATE;
    llLinksetDataWrite(symbol, (string)source_power);
    sourcePowerAcks = TRUE;
    llSetTimerEvent(source_ack_delay);
    // continues in update_drain_powers();
}

integer different_enough(integer a, integer b) {
    sayDebug(TRACE, "different_enough("+engFormat(a)+", "+engFormat(b)+")");
    integer change;
    // protect from division by zero
    if (a == 0) {
        if (b == 0) {
            change = FALSE;
        } else {
            change = TRUE;
        }
    } else {
        // change must exceed 10%
        float deltaRat = llFabs((float)(b - a) / (float)a);
        sayDebug(TRACE, "different_enough deltaRat="+(string)deltaRat);
        if (deltaRat > 0.1) {
            change = TRUE; 
        } else {
            change = FALSE;
        }
    }
    sayDebug(TRACE, "different_enough returns="+(string)change);
    return change;
}

request_power_from_sources(integer newPowerDemand) {
    // distribute the current power demand over the sources we have connected
    sayDebug(DEBUG, "request_power_from_sources("+engFormat(newPowerDemand)+")");
    
    // Distribute requested drain_power_demand evenly over the connected sources.
    integer num_sources = get_num_sources();
    if (num_sources > 0) {
        // integer math doesn't always add up precisely
        // so add the rounding error to the first source. 
        integer distributed_power_demand = llFloor(power_switch_state * newPowerDemand / num_sources);
        
        // calculateulatiuons broken up step by step: 
        //integer planned_demand = distributed_power_demand * num_sources;
        //integer delta = planned_demand - drain_power_demand; // if negative, we're short some amount
        //integer first_demand = distributed_power_demand - delta; // add it back in to make up for shortfall

        // send power requests to each source
        integer source_num;
        for (source_num = 1; source_num <= num_sources; source_num = source_num + 1) {
            string source_key = get_source_key(source_num);
            string source_name = get_source_name(source_num);
            sayDebug(TRACE, "request_power_from_sources "+source_name);
            integer request = distributed_power_demand;
            if (source_num == 1) {
                // special case to account for rounding error
                request = distributed_power_demand + newPowerDemand - (distributed_power_demand * num_sources);
            }
            // only ask if request has changed
            integer nowRate = get_source_rate(source_num);
            if (different_enough(nowRate, request)) {
                sayDebug(DEBUG, "request_power_from_sources "+engFormat(request));
                llRegionSayTo(source_key, POWER_CHANNEL, POWER+REQ+"["+(string)request+"]");
                llSleep(switch_delay);
            } else {
                sayDebug(DEBUG, "request_power_from_sources previous supply was "+engFormat(nowRate));
            }
        }
    } else {
        sayDebug(DEBUG, "request_power_from_sources: No connected sources");
    }
    // sources will return POWER_ACK handled by handle_source_power_ack()
}

// *************************
// conected drains
integer drain_power_rate;
integer drain_power_demand;

delete_drains() {
    integer i;
    for (i = 0; i <= 100; i = i + 1) {
        llLinksetDataDelete(DRAIN+(string)i+KEY);
        llLinksetDataDelete(DRAIN+(string)i+NAME);
        llLinksetDataDelete(DRAIN+(string)i+DEMAND);
        llLinksetDataDelete(DRAIN+(string)i+RATE);
    }
    llLinksetDataWrite("num_drains", "0"); 
    calculate_drain_power_demand();
    calculate_drain_power_rate();
}

integer get_num_drains() {
    return (integer)llLinksetDataRead("num_drains");
}

integer get_drain_key_index(string drain_key) {
    integer num_drains = get_num_drains();
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

upsert_drain(string drain_key, string drain_name) {
    sayDebug(TRACE, "upsert_drain ("+drain_key+", "+drain_name+")");
    integer index = get_drain_key_index(drain_key);
    integer num_drains = get_num_drains();
    if (index < 0) {
        // a new drain
        integer num_drains = num_drains + 1;
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
    integer num_drains = get_num_drains();
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

calculate_drain_power_demand() {
    // calculateulate the total power demanded by drains
    // Called by connect-request and disconnect-request
    drain_power_demand = 0;
    integer drain_num;
    integer num_drains = get_num_drains();
    for (drain_num = 1; drain_num <= num_drains; drain_num = drain_num + 1) {
        //sayDebug(TRACE, "calculate_drain_power_demand " + get_drain_name(drain_num) + " " + engFormat(get_drain_demand(drain_num)));
        drain_power_demand = drain_power_demand + get_drain_demand(drain_num);
    }
    sayDebug(DEBUG, "calculate_drain_power_demand with overhead: "+engFormat(drain_power_demand));
}

calculate_drain_power_rate() {
    // calculateulate the total power used by drains
    // Called by connect-request and disconnect-request
    drain_power_rate = 0;
    integer drain_num;
    integer num_drains = get_num_drains();
    for (drain_num = 1; drain_num <= num_drains; drain_num = drain_num + 1) {
        drain_power_rate = drain_power_rate + get_drain_rate(drain_num);
    }
    sayDebug(DEBUG, "calculate_drain_power_rate() = "+engFormat(drain_power_rate));
}

handle_drain_power_request(string drain_key, string objectName, integer powerRequest) {
    // a drain is asking for power. 
    sayDebug(DEBUG, "handle_drain_power_request("+objectName+", "+engFormat(powerRequest)+")");
    integer drain_num = get_drain_key_index(drain_key);
    if (drain_num > -1) {
        integer drain_power_now = (integer)llLinksetDataRead(DRAIN+(string)drain_num+RATE);
        if (different_enough(drain_power_now, powerRequest)) {
            llLinksetDataWrite(DRAIN+(string)drain_num+DEMAND, (string)powerRequest); 
            // start the timer to call calculate_drain_power_dmnd and request_power_from_sources;
            drainPowerReqs = TRUE;
            llSetTimerEvent(request_ack_delay);
        } else {
            sayDebug(TRACE,"handle_drain_power_request no change");
        }
    } else {
        sayDebug(ERROR,"handle_drain_power_request key not found"+drain_key+" "+objectName+" "+(string)powerRequest);
    }
}

update_drain_power_rate(integer drain_num, integer rate) {
    integer wasRate = (integer)llLinksetDataRead(DRAIN+(string)drain_num+RATE);
    if (rate != wasRate) {
        //sayDebug(TRACE,"update_drain_power_rate "+get_drain_name(drain_num)+" from "+engFormat(wasRate)+" to "+engFormat(rate));
        llLinksetDataWrite(DRAIN+(string)drain_num+RATE, (string)rate); 
        string message = POWER+ACK+"["+(string)rate+"]";
        llRegionSayTo(get_drain_key(drain_num), POWER_CHANNEL, message);
    }
}

cut_all_drain_power() 
// Switch off all outging power. 
// switch_power calls this. 
// Sends Power-ACK[0] to all drains. 
{
    sayDebug(DEBUG, "cut_all_drain_power");
    integer drain_num;
    integer num_drains = get_num_drains();
    for (drain_num = 1; drain_num <= num_drains; drain_num = drain_num + 1) {
        update_drain_power_rate(drain_num, 0);
        llSleep(switch_delay);
    }
    drain_power_rate = 0;
}

update_drain_powers() {
    // POWER+REQ -> handle_drain_power_request -> "drainPowerReqs" 
    //
    // Reason for Timer: 
    // When we get a source power update, we need to recalculateulate drain powers. 
    // This doesn't make any sense. POWER+REQ doesn't come in clusters. 
    // But these can come in clusters, so we want to do this only once. 
    // So instead of calling update_drain_power, set a timer event. 
    // Every update will resets the timer. 
    // When the timer runs out, we get called 
    //
    // update Logic:
    // If drain power demand exceeds what the panel can carry, we shut down.
    // If drain power demand exceeds what all the sources can supply, we shut down. 
    // If drain power demand exceeds what the sources are supplying, we ask for more power. 
    // If drain power demand can be supplied, then give each drain what it wants. 
    sayDebug(DEBUG,"update_drain_powers("+on_off_string(power_switch_state)+") drain_power_demand: "+ engFormat(drain_power_demand)); 
    integer num_drains = get_num_drains();
    if (power_switch_state) {
        if (drain_power_demand > MAX_power_capacity) {
            sayDebug(ERROR, "check_power_limits:"+
            " drain_power_demand "+engFormat(drain_power_demand) +
            " exceeds max panel capacity " + engFormat(MAX_power_capacity) + ". "+
            " Shutting down all drains.");
            switch_power(0);
        } else if (drain_power_demand > source_power_capacity) {
            sayDebug(WARN, "check_power_limits:"+
            " drain_power_demand "+engFormat(drain_power_demand) +
            " exceeds source_power_capacity " + engFormat(source_power_capacity) + ". "+
            " Shutting down all drains.");
            switch_power(0);
        } else if (source_power_rate == 0) {
            cut_all_drain_power();
        } else {
            if (different_enough(source_power_rate, drain_power_demand)) {
                sayDebug(DEBUG, "update_drain_powers requesting change in power");
                request_power_from_sources(drain_power_demand);
            }
            integer drain_num;
            for (drain_num = 1; drain_num <= num_drains; drain_num = drain_num + 1) {
                string drain_name = get_drain_name(drain_num);
                integer wasRate = get_drain_rate(drain_num);
                integer grant = llFloor(get_drain_demand(drain_num));
                if (different_enough(wasRate, grant)) {
                    sayDebug(DEBUG, "update_drain_powers "+drain_name+" update");
                    update_drain_power_rate(drain_num, grant);
                    llSleep(switch_delay);
                } else {
                    sayDebug(DEBUG, "update_drain_powers "+drain_name+" no change");                
                }
            }
        }
        calculate_drain_power_rate();
    } else {
        // power switch is off, so shut it all down. 
        cut_all_drain_power();
    }
}

switch_power(integer new_power_switch_state) {
    sayDebug(DEBUG, "switch_power("+on_off_string(new_power_switch_state)+")");
    power_switch_state = new_power_switch_state;
    if (new_power_switch_state) {
        llPlaySound(kill_switch_wheff, 1);
        request_power_from_sources(drain_power_demand);
        // When the source sends ack, we will then send power-acks to the drains. 
    } else {
        // Cut power to all the drains.
        // This is fine. This is what we want to to. 
        llPlaySound(kill_switch_bonk, 1);
        request_power_from_sources(0);
        cut_all_drain_power();
    }
    llLinksetDataWrite("power_switch_state",(string)power_switch_state);
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
    llSleep(0.2); // let Conn report first. 
    string status;
    status = status + "\nDevice Report for "+llGetObjectName()+":";
    status = status + "\nDebug Level:"+llList2String(debug_levels, debug_level);
    status = status + "\nFree Memory: " + (string)llGetFreeMemory();
    status = status + "\nPower: " + on_off_string(power_switch_state);
    status = status + "\nMaximum Power: "+ engFormat(MAX_power_capacity);
    status = status + "\nPower Demand: "+ engFormat(drain_power_demand);
    status = status + "\nInput Power: "+ engFormat(source_power_rate)+"/"+engFormat(source_power_capacity);
    status = status + "\nOutput Power: "+ engFormat(drain_power_rate)+ "/"+engFormat(drain_power_demand);
    sayDebug(INFO, status);
    status = "";
}

default
{
    state_entry()
    {
        debug_level = (integer)llLinksetDataRead(DEBUG_LEVELS);
        setDebugLevel(debug_level);
        sayDebug(DEBUG, "state_entry Sleep");
        llSleep(1);
        sayDebug(DEBUG, "state_entry Continue");
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
        power_switch_state = (integer)llLinksetDataRead("power_switch_state");
        calculate_drain_power_demand();
        calculate_source_power_capacity();
        calculate_source_power_rate();
        request_power_from_sources(drain_power_demand);
        sayDebug(DEBUG, "state_entry done. Free Memory: " + (string)llGetFreeMemory());
    }
    
    link_message(integer Sender, integer Number, string message, key objectKey) {
        sayDebug(TRACE, "link_message "+(string)Number+" "+message);
        if (message == "Status") {
            llSleep(0.2);
            report_status();
        } else if (message == "reset_data") {
            sayDebug(DEBUG,"Resetting Data");
            power_switch_state = FALSE;
            source_power_capacity = 0;
            source_power_rate = 0;
            drain_power_demand = 0;
        } else if (message == DEBUG_LEVELS) {
            setDebugLevel(Number);
        } else if (message == "Power") {
            switch_power(Number);
        // Data disconnected the device, 
        // So we recalculate appropriately. 
        } else if (message == "handle_disconnect_req_source") {
            request_power_from_sources(drain_power_demand);
            sayDebug(TRACE, "handle_disconnect_req_source drain succeeded.");
        } else if (message == "handle_disconnect_req_drain") {
            calculate_drain_power_demand();
            calculate_drain_power_rate();
            request_power_from_sources(drain_power_demand);
            sayDebug(TRACE, "handle_disconnect_req drain succeeded.");
    } else if (message == "handle_ping_request") {
            handle_ping_request(objectKey, Number);
        } else if (message == "delete_source") {
            request_power_from_sources(drain_power_demand);
        } else if (message == "calculate_source_power_capacity") {
            calculate_source_power_capacity();
        } else if (message = "handle_disconnect_ack") {
            handle_disconnect_ack(objectKey);
        } else {
            sayDebug(ERROR, "link_message did not handle message "+(string)Number+", "+message);
        }
    }

    listen(integer channel, string name, key objectKey, string message )
    {
        if (channel == POWER_CHANNEL) {
            string trimmed_message = trimMessageParameters(message);
            integer parameter = getMessageParameter(message);
            sayDebug(TRACE, "listen \""+name+"\" says \""+message + "\"");
            if (trimmed_message == POWER+REQ) {
                handle_drain_power_request(objectKey, name, parameter);
            } else if (trimmed_message == POWER+ACK) {
                handle_source_power_ack(objectKey, name, parameter);
            } else if (trimmed_message == PING+REQ) {
                sayDebug(TRACE, "listen ignored");
            } else if (trimmed_message == PING+ACK) {
                sayDebug(TRACE, "listen ignored");
            } else if (trimmed_message == CONNECT+REQ) {
                sayDebug(TRACE, "listen ignored");
            } else if (trimmed_message == CONNECT+ACK) {
                sayDebug(TRACE, "listen ignored");
            } else if (trimmed_message == DISCONNECT+REQ) {
                sayDebug(TRACE, "listen ignored");
            } else if (trimmed_message == DISCONNECT+ACK) {
                sayDebug(TRACE, "listen ignored");
            } else {
                sayDebug(ERROR, "listen did not handle power channel message:"+message);
            }
        }
    }
    
    timer() {
        //sayDebug(TRACE, "timer waiting for "+timer_waiting_for);
        
        // handle_drain_power_request
        if (drainPowerReqs) {
            // called after power requests have been handled
            sayDebug(TRACE, "timer() handles drainPowerReqs");
            drainPowerReqs = FALSE;
            calculate_drain_power_demand();
            update_drain_powers(); // distribute power over the drains
            request_power_from_sources(drain_power_demand);
            // this will come back as POWER+ACK and be handled in handle_source_power_ack()
        }
        
        // handle_source_power_ack
        if (sourcePowerAcks) {
            // Called after power acks have been handled. 
            sayDebug(TRACE, "timer() handles sourcePowerAcks");
            sourcePowerAcks = FALSE;
            calculate_source_power_rate();
            update_drain_powers();
        }
        
        if (!(drainPowerReqs | sourcePowerAcks)) {
            llSetTimerEvent(0);
        }
    }
}
