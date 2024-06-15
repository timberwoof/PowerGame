// Power Panel 
// Incremental build-up of Power Dustribution Panel 

integer POWER_CHANNEL = -654647;
integer MONITOR_CHANNEL = -6546478;
integer clock_interval = 1;

string REQ = "-REQ";
string ACK = "-ACK";
string PING = "Ping";
string STATUS = "Status";
string CONNECT = "Connect";
string DISCONNECT = "Disconnect";
string CONNECT_SOURCE = "Connect Src";
string DISCONNECT_SOURCE = "Disc Src";
string DISCONNECT_DRAIN = "Disc Drain";
string POWER = "Power";
string RESET = "Reset";
string NONE = "None";

list known_sources; // [key, name, power, distance]
integer num_known_sources = 0;
integer known_sources_are_sorted = FALSE;

list my_source_keys;
list my_source_names;
list my_source_power_capacities;
list my_source_power_supplies;
integer num_my_sources;
integer my_source_power_capacity = 0;
integer my_source_power_rate = 0; // how much power we are getting from sources
integer power_state;

list drain_keys;
list drain_names;
list drain_powers; // how much power each device wants
integer num_drains;
integer power_drain;

integer power_capacity = 10000000; // 10MW how much power we can transfer total

integer dialog_channel;
integer dialog_listen;
integer dialog_countdown;

string CLOSE = "Close";
string mainMenu = "Main";
string menuIdentifier;
key menuAgentKey;
integer menuChannel;
integer menuListen;
integer menuTimeout;

string kill_switch_1 = "4690245e-a161-87ce-e392-47e2a410d981";
string kill_switch_2 = "00800a8c-1ac2-ff0a-eed5-c1e37fef2317";

integer ERROR = 0;
integer WARN = 1;
integer INFO = 2;
integer DEBUG = 3;
integer TRACE = 4;
string DEBUG_LEVELS = "DebugLevels";
list debug_levels = ["Error", "Warming", "Info", "Debug", "Trace"];
integer debug_level = 2;
sayDebug(integer level, string message) {
    message = llList2String(debug_levels, level)+": "+message;
    if (level <= debug_level) {
        if (level <= WARN) {
            llShout(MONITOR_CHANNEL, message);
            llSay(0, message);
        } else if (level == INFO) {
            llSay(MONITOR_CHANNEL, message);
        } else {
            llWhisper(MONITOR_CHANNEL, message);
        }
    }
}

// ****************************************
// Menu and Message Utilities

string menuCheckbox(string title, integer onOff)
// make checkbox menu item out of a button title and boolean state
{
    string checkbox;
    if (onOff)
    {
        checkbox = "☒";
    }
    else
    {
        checkbox = "☐";
    }
    return checkbox + " " + title;
}

list menuRadioButton(string title, string match)
// make radio button menu item out of a button and the state text
{
    string radiobutton;
    if (title == match)
    {
        radiobutton = "●";
    }
    else
    {
        radiobutton = "○";
    }
    return [radiobutton + " " + title];
}

list menuButtonActive(string title, integer onOff)
// make a menu button be the text or the Inactive symbol
{
    string button;
    if (onOff)
    {
        button = title;
    }
    else
    {
        button = "["+title+"]";
    }
    return [button];
}

string trimMessageButton(string message) {
    string messageButtonsTrimmed = message;
    
    list LstripList = ["☒ ","☐ ","● ","○ "];
    integer i;
    for (i=0; i < llGetListLength(LstripList); i = i + 1) {
        string thing = llList2String(LstripList, i);
        integer whereThing = llSubStringIndex(messageButtonsTrimmed, thing);
        if (whereThing > -1) {
            integer thingLength = llStringLength(thing)-1;
            messageButtonsTrimmed = llDeleteSubString(messageButtonsTrimmed, whereThing, whereThing + thingLength);
        }
    }
    
    return messageButtonsTrimmed;
}

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

setUpMenu(string identifier, key avatarKey, string message, list buttons)
// wrapper to do all the calls that make a simple menu dialog.
// - adds required buttons such as Close or Main
// - displays the menu command on the alphanumeric display
// - sets up the menu channel, listen, and timer event 
// - calls llDialog
// parameters:
// identifier - sets menuIdentifier, the later context for the command
// avatarKey - uuid of who clicked
// message - text for top of blue menu dialog
// buttons - list of button texts
{
    //sayDebug("setUpMenu "+identifier);
    menuIdentifier = identifier;
    menuAgentKey = avatarKey; // remember who clicked
    menuChannel = -(llFloor(llFrand(10000)+1000));
    menuListen = llListen(menuChannel, "", avatarKey, "");
    menuTimeout = llFloor(llGetTime()) + 30;
    llDialog(avatarKey, message, buttons, menuChannel);
}

resetMenu() {
    llListenRemove(menuListen);
    menuListen = 0;
    menuChannel = 0;
    menuAgentKey = "";
}

// ****************************************
// Power Menus

presentMainMenu(key whoClicked) {
    string message = "Power Panel Main Menu";
    list buttons = [];
    buttons = buttons + STATUS;
    buttons = buttons + PING; 
    buttons = buttons + RESET;
    buttons = buttons + menuButtonActive(CONNECT_SOURCE, num_known_sources > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_SOURCE, num_my_sources > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_DRAIN, num_drains > 0); 
    buttons = buttons + menuButtonActive(menuCheckbox("Power", power_state), num_known_sources > 0);
    buttons = buttons + DEBUG_LEVELS;
    setUpMenu(mainMenu, whoClicked, message, buttons);
}

presentDebugLevelMenu(key whoClicked) {
    string message = "Set the Debug Level:";
    setUpMenu(DEBUG_LEVELS, whoClicked, message, debug_levels);
}

setDebugLevel(string debug_level_name) {
    debug_level = llListFindList(debug_levels, [debug_level_name]);
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

// [key, name, power, distance]
key known_source_key(integer i) {
    return llList2Key(known_sources, i*4);
}
string known_source_name(integer i) {
    return llList2Key(known_sources, i*4+1);
}
integer known_source_power(integer i) {
    return llList2Integer(known_sources, i*4+2);
}
integer known_source_distance(integer i) {
    return llList2Integer(known_sources, i*4+3);
}

presentConnectSourceMenu(key whoClicked) {
    // sort by distance, nearest first
    if (!known_sources_are_sorted) {
        known_sources = llListSortStrided(known_sources, 4, 3, TRUE);
        known_sources_are_sorted = TRUE;
    }
    
    // Set up the list in that order
    list buttons = [];
    string message = "Select Power Source:";
    integer i;
    for (i = 0; i < num_known_sources & i < 12; i = i + 1) {
        /// [key, name, power, distance]
        string item = "\n" + (string)i + ": " + known_source_name(i) + " (" + EngFormat(known_source_power(i)) + ") " + (string)known_source_distance(i) + "m";
        sayDebug(TRACE, item);
        if ((llStringLength(message) + llStringLength(item)) < 512) {
            message = message + item;
            buttons = buttons + [(string)i];
        }
    }
    setUpMenu(CONNECT_SOURCE, whoClicked, message, buttons);    
}

presentDisonnectSourceMenu(key whoClicked) {
    string message = "Select Power Source to Disconnect:";
    integer i;
    list buttons = [];
    for (i = 0; i < num_my_sources; i = i + 1) {
        message = message + "\n" + (string)i + " " + llList2String(my_source_names, i) + " " + llList2String(my_source_power_capacities, i) + "W";
        buttons = buttons + [(string)i];
    }
    setUpMenu(DISCONNECT_SOURCE, whoClicked, message, buttons);    
}

presentDisonnectDrainMenu(key whoClicked) {
    string message = "Select Power Drain to Disconnect:";
    integer i;
    list buttons = [];
    for (i = 0; i < num_drains; i = i + 1) {
        message = message + "\n" + (string)i + " " + llList2String(drain_names, i) + " " + llList2String(drain_powers, i) + "W";
        buttons = buttons + [(string)i];
    }
    setUpMenu(DISCONNECT_DRAIN, whoClicked, message, buttons);    
}

// ****************************************
// Power Communications Protocol

send_ping_req() {
    sayDebug (DEBUG, "ping_req");
    num_known_sources = 0;
    known_sources = [];
    known_sources_are_sorted = FALSE;
    llShout(POWER_CHANNEL, PING+REQ);
}

respond_ping_req(key objectKey) {
    // respond to Ping-REQ
    llRegionSayTo(objectKey, POWER_CHANNEL, PING+ACK+"["+(string)power_capacity+"]"); // must not be formatted
}

add_known_source(string source_name, key source_key, integer source_power) {
    // respond to Ping-ACK
    sayDebug (INFO, "add_known_source("+source_name+") "+EngFormat(power_capacity));
    vector myPos = llGetPos();
    list source_details = llGetObjectDetails(source_key, [OBJECT_POS]);    
    vector source_position = llList2Vector(source_details, 0);
    integer source_distance = llFloor(llVecDist(myPos, source_position));
    // [key, name, power, distance]
    known_sources = known_sources + [source_key, source_name, source_power, source_distance]; 
    num_known_sources = num_known_sources + 1;
}

calculate_power_capacity() {
    num_my_sources = llGetListLength(my_source_keys);
    my_source_power_capacity = 0;
    integer i;
    for (i = i; i < num_my_sources; i = i + 1) {
        my_source_power_capacity = my_source_power_capacity + llList2Integer(my_source_power_capacities, i);
    }
    sayDebug(DEBUG, "calculate_power_capacity:"+EngFormat(my_source_power_capacity));
}

add_source(key objectKey, string objectName, integer source_rate) {
    // respond to Connect-ACK
    sayDebug(INFO, "add_source("+objectName+"): "+EngFormat(source_rate));
    llPlaySound(kill_switch_1, 1);

    // Handle bad requests
    // [key, name, power, distance]
    if (llListFindList(known_sources, [objectKey]) < 0) {
        sayDebug(ERROR, objectName+" was not known."); // error
        return;
    }
    if (llListFindList(my_source_keys, [objectKey]) >= 0) {
        sayDebug(WARN, objectName+" was already connected as a Source."); // warning
        return;
    }
    if (llListFindList(drain_keys, [objectKey]) >= 0) {
        sayDebug(WARN, objectName+" was already connected as a Drain."); // warning
        return;
    }
    
    // register the source
    my_source_keys = my_source_keys + [objectKey];
    my_source_names = my_source_names + [objectName];
    my_source_power_capacities = my_source_power_capacities + source_rate;
    calculate_power_capacity();
}

remove_source(key objectKey, string objectName) {
    // Respond to Disonnect-ACK
    llPlaySound(kill_switch_1, 1);
    integer i = llListFindList(my_source_keys, [objectKey]);
    if (i > -1) {
        my_source_keys = llDeleteSubList(my_source_keys, i, i);
        my_source_names = llDeleteSubList(my_source_names, i, i);
        my_source_power_capacities = llDeleteSubList(my_source_power_capacities, i, i);        
        sayDebug(INFO, "remove_source("+objectName+"): was disconnected.");
    } else {
        sayDebug(INFO, "remove_source("+objectName+"): was not connected."); // warning
    }
    calculate_power_capacity();
}

add_drain(key objectKey, string objectName) {
    //Respond to Connect-REQ
    llPlaySound(kill_switch_1, 1);
    if (llListFindList(drain_keys, [objectKey]) > -1) {
        sayDebug(TRACE, objectName+" was already connecred as a Drain. Reconnecting."); // warning
        llRegionSayTo(objectKey, POWER_CHANNEL, CONNECT+ACK+"["+EngFormat(power_capacity)+"]");
        return;
    }
    if (llListFindList(my_source_keys, [objectKey]) > -1) {
        sayDebug(INFO, objectName+" was already connecred as a Source."); // warning
        return;
    }
    drain_keys = drain_keys + [objectKey];
    drain_names = drain_names + [objectName];
    drain_powers = drain_powers + [0];
    num_drains = llGetListLength(drain_keys);
    llRegionSayTo(objectKey, POWER_CHANNEL, CONNECT+ACK+"["+EngFormat(power_capacity)+"]");
}

remove_drain(key objectKey, string objectName) {
    // respond to Disconnect-REQ
    llPlaySound(kill_switch_1, 1);
    integer i = llListFindList(drain_keys, [objectKey]);
    if (i > -1) {
        drain_keys = llDeleteSubList(drain_keys, i, i);
        drain_names = llDeleteSubList(drain_names, i, i);
        drain_powers = llDeleteSubList(drain_powers, i, i);        
        sayDebug(INFO, "Drain "+objectName+" was disconnected."); // waning
    } else {
        sayDebug(INFO, "Drain "+objectName+" was not connected."); // waning
    }
    num_drains = llGetListLength(drain_keys);
    llRegionSayTo(objectKey, POWER_CHANNEL, DISCONNECT+ACK);
}

handle_power_request(key objectKey, string objectName, integer powerLevel) {
    // Respond to Power-REQ
    sayDebug(DEBUG, objectName+" requests "+EngFormat(powerLevel));
    integer i;
    integer drain_num = -1;
    
    // find the drain's index in the list
    drain_num = llListFindList(drain_keys, [objectKey]);
    
    // update the drain's power draw
    if (drain_num > -1) {
        drain_powers = llListReplaceList(drain_powers, [powerLevel], drain_num, drain_num);
        
        // reclaculate total power drain
        power_drain = 0;
        integer i;
        num_drains = llGetListLength(drain_keys);
        for (i = i; i < num_drains; i = i + 1) {
            power_drain = power_drain + llList2Integer(drain_powers, i);
        }
        
        request_power();
    } else {
        sayDebug(DEBUG, "object was not connected");
        powerLevel = 0;
    }
    
    if (!power_state) {
        sayDebug(DEBUG, "power was off");
        powerLevel = 0;
    }
    llRegionSayTo(objectKey, POWER_CHANNEL, POWER+ACK+"["+(string)powerLevel+"]");
}

handle_power_ack(key source_key, string source_name, integer source_power) {
    sayDebug(INFO, "handle_power_ack("+source_name+", "+EngFormat(source_power)+")");
    integer object_num = llListFindList(my_source_keys, [source_key]);
    if (object_num < 0) {
        sayDebug(INFO, source_name+" was not in list of sources."); // error
        return;
    }
    my_source_power_supplies = llListReplaceList(my_source_power_supplies, [source_power], object_num, object_num);
    
    // reclaculate total power drain
    my_source_power_rate = 0;
    integer i;
    num_my_sources = llGetListLength(my_source_keys);
    for (i = i; i < num_my_sources; i = i + 1) {
        my_source_power_rate = my_source_power_rate + llList2Integer(my_source_power_supplies, i);
    }
}

// ****************************************
// Power State Management

string power_state_to_string(integer power_state) {
    if (power_state) {
        return "On";
    } else {
        return "Off";
    }
}

string list_known_sources() {
    // [key, name, power, distance]
    string result;
    result = result + "\n-----\nKnown Power Sources:";
    integer i;
    if (num_known_sources > 0) {
        for (i = 0; i < num_known_sources; i = i + 1) {
            result = result + "\n" +   known_source_name(i) + ": " + EngFormat(known_source_power(i));
        }
    } else {
        result = result + "\n" +  "No Power Sources Known.";
    }
    return result;
}

string list_my_sources() {
    string result;
    result = result + "\n-----\nConnected Power Sources:";
    integer i;
    if (num_my_sources > 0) {
        for (i = 0; i < num_my_sources; i = i + 1) {
            integer capacity = llList2Integer(my_source_power_capacities, i);
            integer supply = llList2Integer(my_source_power_supplies, i);
            result = result + "\n" +   llList2String(my_source_names, i) + ": " +  EngFormat(supply)+"/" + EngFormat(capacity);
        }
    } else {
        result = result + "\n" +  "No Power Sources Connected.";
    }
    result = result + "\n" +   "Total Supply: "+EngFormat(my_source_power_rate)+"/"+EngFormat(my_source_power_capacity);
    return result;
}

string list_drains() {
    string result;
    result = result + "\n-----\nPower Drains:";
    integer power_drain = 0;
    integer i;
    num_drains = llGetListLength(drain_keys);
    if (num_drains > 0) {
        for (i = 0; i < num_drains; i = i + 1) {
            power_drain = power_drain + llList2Integer(drain_powers, i);
            result = result + "\n" +   llList2String(drain_names, i) + ": " + EngFormat(llList2Integer(drain_powers, i));
        }
        result = result + "\n" +   "Total Power Drain: "+(string)power_drain;
    } else {
        result = result + "\n" +  "No Power Drains Connected.";
    }
    return result;
}

report_status(key whoClicked) {
    string status;
    status = status + "\n" + "Device Report for "+llGetObjectName()+":";
    status = status + "\n" + "Power: " + power_state_to_string(power_state);
    status = status + "\n" + "Maximum Power: "+ EngFormat(power_capacity);
    status = status + "\n" + "Input Power: "+ EngFormat(my_source_power_rate);
    status = status + "\n" + "Output Power: "+ EngFormat(power_drain);
    status = status + list_my_sources();
    status = status + list_drains();
    sayDebug(INFO, status);
    list buttons = [];
    setUpMenu("", whoClicked, status, buttons);
}

switch_power(integer new_power_state) {
    sayDebug(INFO, "switch_power("+power_state_to_string(new_power_state)+")");
    llPlaySound(kill_switch_1, 1);
    power_state = new_power_state;
    integer i;
    if (power_state) {
        // switch on
        // request power from sourcs
        request_power();
        // grant power to drains
        for (i = 0; i < num_drains; i = i + 1) {
            key drain_key = llList2Key(drain_keys, i);
            integer rate = llList2Integer(drain_powers, i);
            llRegionSayTo(drain_key, POWER_CHANNEL, POWER+ACK+"["+(string)rate+"]");
        }
    } else {
        // cut power to all the drains
        for (i = 0; i < num_drains; i = i + 1) {
            key drain_key = llList2Key(drain_keys, i);
            llRegionSayTo(drain_key, POWER_CHANNEL, POWER+ACK+"[0]");
        }
        // cut power from all the sources
        for (i = 0; i < num_my_sources; i = i + 1) {
            key source_key = llList2Key(my_source_keys, i);
            llRegionSayTo(source_key, POWER_CHANNEL, POWER+REQ+"[0]");
        }
    }
}

toggle_power() {
    switch_power(!power_state);
}

monitor_power() {
    integer cut = FALSE;
    integer i;
    power_drain = 0;
    for (i = 0; i < num_drains; i = i + 1) {
        power_drain = power_drain + llList2Integer(drain_powers, i);
        sayDebug(TRACE, llList2String(drain_names, i) + ": " + EngFormat(llList2Integer(drain_powers, i)));
    }

    if (power_drain > my_source_power_rate) {
        sayDebug(WARN, "power_drain:"+EngFormat(power_drain)+" > my_source_power_rate:"+EngFormat(my_source_power_rate));
        cut = TRUE;
    }

    if (power_drain > my_source_power_capacity) {
        sayDebug(WARN, "power_drain:"+EngFormat(power_drain)+" > my_source_power_capacity:"+EngFormat(my_source_power_capacity));
        cut = TRUE;
    }

    if (cut) {
        switch_power(FALSE);
    }
    
}

request_power() {
    // distribute the current power use over the sources we have connected
    integer i;
    
    // Gather up the power capacity of connected sources
    integer total_source_power = 0;
    for (i = 0; i < num_my_sources; i = i + 1) {
        total_source_power = total_source_power + llList2Integer(my_source_power_capacities, i);
    }
    sayDebug(INFO, "request_power("+EngFormat(total_source_power)+")");
    
    // Distribute required power_drain evenly over the connected sources
    for (i = 0; i < num_my_sources; i = i + 1) {
        key source_key = llList2Key(my_source_keys, i);
        integer source_rate = llFloor(power_drain * llList2Integer(my_source_power_capacities, i) / total_source_power * 1.1);
        string source_name = llList2String(my_source_names, i);
        string source_message = POWER+REQ+"["+(string)source_rate+"]";
        sayDebug(DEBUG, "request_power requesting "+EngFormat(source_rate)+" from "+source_name+": \""+source_message+"\"");
        llRegionSayTo(source_key, POWER_CHANNEL, source_message);
    }    
}

default
{
    state_entry()
    {
        sayDebug(INFO, "state_entry");
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
        send_ping_req();
        llSetTimerEvent(10);
    }

    touch_start(integer total_number)
    {
        //sayDebug(DEBUG, "touch_start");
        key whoClicked  = llDetectedKey(0);
        presentMainMenu(whoClicked);
    }
    
    listen( integer channel, string name, key objectKey, string message )
    {
        sayDebug(TRACE, "listen name:"+name+" message:"+message);
        if (channel == menuChannel) {
            resetMenu();
            if (message == CLOSE) {
                sayDebug(TRACE, "listen Close");
            } else if (message == STATUS) {
                report_status(objectKey);
            } else if (message == RESET) {
                sayDebug(TRACE, "listen Reset");
                llResetScript();
            } else if (message == DEBUG_LEVELS) {
                presentDebugLevelMenu(objectKey);
            } else if (message == PING) {
                send_ping_req();
            } else if (message == CONNECT_SOURCE) {
                presentConnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_SOURCE) {
                presentDisonnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_DRAIN) {
                presentDisonnectDrainMenu(objectKey);
            } else if (menuIdentifier == DEBUG_LEVELS) {
                setDebugLevel(message);
            } else if (menuIdentifier == CONNECT_SOURCE) {
                sayDebug(TRACE, "listen CONNECT from "+name+": "+message);
                llRegionSayTo(known_source_key((integer)message), POWER_CHANNEL, CONNECT+REQ);
            } else if (menuIdentifier == DISCONNECT_SOURCE) {
                sayDebug(TRACE, "listen DISCONNECT from "+name+": "+message);
                llRegionSayTo(llList2Key(my_source_keys, (integer)message), POWER_CHANNEL, DISCONNECT+REQ);
            } else if (menuIdentifier == DISCONNECT_DRAIN) {
                sayDebug(TRACE, "listen DISCONNECT from "+name+": "+message);
                key drain_key = llList2Key(drain_keys, (integer)message);
                llRegionSayTo(drain_key, POWER_CHANNEL, DISCONNECT+ACK);
                remove_drain(drain_key, name);
            } else if (trimMessageButton(message) == POWER) {
                toggle_power();
            } else if (llListFindList(debug_levels, [trimMessageButton(message)]) > -1) { 
                debug_level = llListFindList(debug_levels, [trimMessageButton(message)]);
            } else if (message == "OK") {
                // OK
            } else {
                sayDebug(ERROR, "listen did not handle "+menuIdentifier+":"+message);
            }
        } else if (channel == POWER_CHANNEL) {
            string trimmed_message = trimMessageParameters(message);
            integer parameter = getMessageParameter(message);
            if (message == PING+REQ) {
                respond_ping_req(objectKey);
            } else if (trimmed_message == PING+ACK) {
                add_known_source(name, objectKey, parameter);
            } else if (trimmed_message == CONNECT+REQ) {
                add_drain(objectKey, name);
            } else if (trimmed_message == CONNECT+ACK) {
                add_source(objectKey, name, parameter);
            } else if (trimmed_message == DISCONNECT+REQ) {
                remove_drain(objectKey, name);
            } else if (trimmed_message == DISCONNECT+ACK) {
                remove_source(objectKey, name);
            } else if (trimmed_message == POWER+REQ) {
                handle_power_request(objectKey, name, parameter);
            } else if (trimmed_message == POWER+ACK) {
                handle_power_ack(objectKey, name, parameter);
            } else {
                sayDebug(ERROR, "did not handle power channel message:"+message);
            }
        }
    }

    timer() {
        integer now = llFloor(llGetTime());
        if (now > menuTimeout) {
            resetMenu();
        }
        monitor_power();
    }
}
