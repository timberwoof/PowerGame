// ****************************************
// Menu and Message Utilities
// This is all about communicting with the user.

// constants
integer MONITOR_CHANNEL = -6546478;
integer POWER_CHANNEL = -654647;

// interface to Novatech Sonic Screwdriver
integer SONIC_CHANNEL = -313331;    // Used by sonic screwdrivers. Do not change!


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
    message = "Menus "+llList2String(debug_levels, message_level) + ": " + message;
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

setDebugLevelByName(string debug_level_name) {
    sayDebug(TRACE,"setDebugLevelByName("+debug_level_name+")");
    debug_level = llListFindList(debug_levels, [debug_level_name]);
    sayDebug(TRACE,"setDebugLevelByName debug_level:"+(string)debug_level);
}

setDebugLevelByNumber(integer new_debug_level) {
    sayDebug(TRACE,"setDebugLevelByNumber("+(string)debug_level+")");
    debug_level = new_debug_level;
    string debug_level_name = llList2String(debug_levels, debug_level);
    sayDebug(TRACE,"setDebugLevelByNumber debug_level:"+debug_level_name);
}


// ******************************************
// source and drain data lists
// Stuff we need to know from the main script
integer power_state;

// Known Sources
// [key, name, power, distance]
integer get_num_known_sources() {
    return (integer)llLinksetDataRead("num_known_sources"); 
}

list known_source_keys;
list known_source_names;
list known_source_powers;
list known_source_distances;
integer num_known_sources = 0;

read_known_sources() {
    sayDebug(DEBUG,"read_known_sources");
    known_source_keys = llJson2List(llLinksetDataRead("known_source_keys"));
    known_source_names = llJson2List(llLinksetDataRead("known_source_names"));
    known_source_powers = llJson2List(llLinksetDataRead("known_source_powers"));
    known_source_distances = llJson2List(llLinksetDataRead("known_source_distances"));
    num_known_sources = llGetListLength(known_source_keys);
}

integer known_source_key_index(string objectKey) {
    if (num_known_sources == 0) {
        return -1;
    }
    integer result = llListFindList(known_source_keys, [objectKey]);
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


// conected Sources
// [key, name, capacity, rate]
integer get_num_connected_sources() {
    return (integer)llLinksetDataRead("num_connected_sources"); 
}

list connected_source_keys; 
list connected_source_names; 
list connected_source_capacitys; 
list connected_source_rates; 
integer num_connected_sources = 0;

read_connected_sources() {
    //sayDebug(DEBUG,"read_connected_sources");
    connected_source_keys = llJson2List(llLinksetDataRead("connected_source_keys"));
    connected_source_names = llJson2List(llLinksetDataRead("connected_source_names"));
    connected_source_capacitys = llJson2List(llLinksetDataRead("connected_source_capacitys"));
    connected_source_rates = llJson2List(llLinksetDataRead("connected_source_rates"));
    num_connected_sources = llGetListLength(connected_source_keys);
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

// conected drains
// [key, name, demand, rate]
integer get_num_connected_drains() {
    return (integer)llLinksetDataRead("num_connected_drains"); 
}

list connected_drain_keys = []; 
list connected_drain_names = []; 
list connected_drain_demands = []; 
list connected_drain_rates = []; 
integer num_connected_drains = 0;

read_connected_drains() {
    connected_drain_keys = llJson2List(llLinksetDataRead("connected_drain_keys"));
    connected_drain_names = llJson2List(llLinksetDataRead("connected_drain_names"));
    connected_drain_demands = llJson2List(llLinksetDataRead("connected_drain_demands"));
    connected_drain_rates = llJson2List(llLinksetDataRead("connected_drain_rates"));
    num_connected_drains = llGetListLength(connected_drain_keys);
}

integer drain_key_index(string objectKey) {
    integer result;
    if (num_connected_drains == 0) {
        result = -1;
    } else {
        result = llListFindList(connected_drain_keys, [objectKey]);
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

// ****************************************************
// Constants and Variables for Second LIfe Dialog Boxes
string REQ = "-REQ";
string ACK = "-ACK";
string STATUS = "Status";
string PING = "Ping";
string CONNECT = "Connect";
string DISCONNECT = "Disconnect";
string CLOSE = "Close";
string POWER = "Power";
string RESET = "Reset";
string CONNECT_SOURCE = "Connect Src";
string DISCONNECT_SOURCE = "Disc Src";
string DISCONNECT_DRAIN = "Disc Drain";
string mainMenu = "Main";
integer dialog_channel;
integer dialog_listen;
integer dialog_countdown;
string menuIdentifier;
key menuAgentKey;
integer menuChannel;
integer menuListen;
integer menuTimeout;

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
    buttons = buttons + menuButtonActive(CONNECT_SOURCE, get_num_known_sources() > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_SOURCE, get_num_connected_sources() > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_DRAIN, get_num_connected_drains() > 0); 
    buttons = buttons + menuCheckbox("Power", power_state);
    buttons = buttons + DEBUG_LEVELS;
    setUpMenu(mainMenu, whoClicked, message, buttons);
}

presentDebugLevelMenu(key whoClicked) {
    string message = "Set the Debug Level:";
    string debug_level_text = llList2String(debug_levels, debug_level);
    list buttons = [];
    integer i;
    for (i = 0; i < llGetListLength(debug_levels); i = i + 1) {
        buttons = buttons + menuRadioButton(llList2String(debug_levels, i), debug_level_text);
    }
    setUpMenu(DEBUG_LEVELS, whoClicked, message, buttons);
}

presentConnectSourceMenu(key whoClicked) {
    read_known_sources();
    
    // If this needs otbe put into sorted order, 
    // Then we need to make a local copy of this list 
    // with an additional item in each stride, the original index. 
    // The response must look up the original index. 
   
    string message = "Select Power Source:";
    integer i;
    list buttons = [];
    for (i = 0; i < get_num_known_sources() & i < 12; i = i + 1) {
        string item = "\n" + (string)i + ": " + known_source_name(i) + " (" +
            EngFormat(known_source_power(i)) + ") " + (string)known_source_distance(i) + "m";
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
    read_connected_sources();
    for (i = 0; i < get_num_connected_sources(); i = i + 1) {
        message = message + "\n" + (string)i + " " + 
            connected_source_name(i) + " " + EngFormat(connected_source_capacity(i));
        buttons = buttons + [(string)i];
    }
    setUpMenu(DISCONNECT_SOURCE, whoClicked, message, buttons);    
}

presentDisonnectDrainMenu(key whoClicked) {
    string message = "Select Power Drain to Disconnect:";
    integer i;
    list buttons = [];
    read_connected_drains();
    for (i = 0; i < get_num_connected_drains(); i = i + 1) {
        message = message + "\n" + (string)i + " " + 
            connected_drain_name(i) + " " + EngFormat(connected_drain_demand(i));
        buttons = buttons + [(string)i];
    }
    setUpMenu(DISCONNECT_DRAIN, whoClicked, message, buttons);    
}


// ***********************************
// Reports

string power_state_to_string(integer power_state) {
    if (power_state) {
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

string formatDebug(integer message_level, string message) {
    string result = "";
    if (message_level <= debug_level) {
        result = message;
    }
    return result;
}

string list_known_sources() {
    string result;
    result = result + "\n-----\nKnown Power Sources: capacity, distance";
    read_known_sources();
    if (num_known_sources > 0) {
        integer source_num;
        for (source_num = 0; source_num < num_known_sources; source_num = source_num + 1) {
            result = result + "\n" +  
                formatDebug(TRACE, "["+known_source_key(source_num)+"] ")  +
                known_source_name(source_num) + ": " + 
                EngFormat(known_source_power(source_num))+", " + 
                (string)known_source_distance(source_num)+"m";
        }
    } else {
        result = result + "\n" +  "No Power Sources known.";
    }
    return result;
}

string list_connected_sources() {
    string result;
    result = result + "\n-----\nConnected Power Sources: (rate/capacity)";
    read_connected_sources();
    if (num_connected_sources > 0) {
        integer source_num;
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
    return result;
}

report_status(string objectKey) {
    string status;
    status = status + "\n" + "Device Report for "+llGetObjectName()+":";
    status = status + list_known_sources();
    status = status + list_connected_sources();
    status = status + "\n-----\n" + "Free Memory: " + (string)llGetFreeMemory();
    sayDebug(DEBUG, status);
}
default
{
    state_entry()
    {
        sayDebug(DEBUG, "state_entry");
        setDebugLevelByNumber(DEBUG);
        read_known_sources();
        read_connected_sources();
        
        // listen to Novatech sonic screwdriver
        llListen(SONIC_CHANNEL, "", "", "ccSonic");

        sayDebug(DEBUG, "state_entry done");
    }

    touch_start(integer total_number)
    {
        //sayDebug(DEBUG, "touch_start");
        key whoClicked = llDetectedKey(0);
        presentMainMenu(whoClicked);
    }
    
    listen( integer channel, string name, key objectKey, string message )
    {
        if (channel == menuChannel) {
            sayDebug(TRACE, "listen menuIdentifier:"+menuIdentifier+" name:"+name+" message:"+message);
            resetMenu();
            if (message == CLOSE) {
                sayDebug(TRACE, "listen Close");
            } else if (message == STATUS) {
                report_status(objectKey);
                llMessageLinked(LINK_SET, 0, STATUS, objectKey);
            } else if (message == RESET) {
                sayDebug(TRACE, "listen Reset");
                llMessageLinked(LINK_SET, 0, message, NULL_KEY);
                llResetScript();
            } else if (message == DEBUG_LEVELS) {
                presentDebugLevelMenu(objectKey);
            } else if (message == PING) {
                llMessageLinked(LINK_SET, 0, PING, objectKey);
            } else if (message == CONNECT_SOURCE) {
                presentConnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_SOURCE) {
                presentDisonnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_DRAIN) {
                presentDisonnectDrainMenu(objectKey);
            } else if (menuIdentifier == DEBUG_LEVELS) {
                setDebugLevelByName(trimMessageButton(message));
                llMessageLinked(LINK_SET, debug_level, DEBUG_LEVELS, NULL_KEY);
            } else if (menuIdentifier == CONNECT_SOURCE) {
                sayDebug(DEBUG, "listen CONNECT_SOURCE from "+name+": "+message);
                sayDebug(DEBUG,known_source_key((integer)message));
                sayDebug(DEBUG,known_source_name((integer)message));
                llRegionSayTo(known_source_key((integer)message), POWER_CHANNEL, CONNECT+REQ);
            } else if (menuIdentifier == DISCONNECT_SOURCE) {
                sayDebug(DEBUG, "listen DISCONNECT_SOURCE from "+name+": "+message);
                key source_key = connected_source_key((integer)message);
                llRegionSayTo(source_key, POWER_CHANNEL, DISCONNECT+REQ);
                llMessageLinked(LINK_SET, (integer)message, DISCONNECT+REQ, source_key);
            } else if (menuIdentifier == DISCONNECT_DRAIN) {
                sayDebug(DEBUG, "listen DISCONNECT_DRAIN from "+name+": "+message);
                key drain_key = connected_drain_key((integer)message);
                llRegionSayTo(drain_key, POWER_CHANNEL, DISCONNECT+REQ);
                llMessageLinked(LINK_SET, (integer)message, DISCONNECT+REQ, drain_key);
            } else if (trimMessageButton(message) == POWER) {
                power_state = !power_state;
                llMessageLinked(LINK_SET, power_state, POWER, NULL_KEY);
            } else if (message == "OK") {
                // OK
            } else {
                sayDebug(ERROR, "listen did not handle "+menuIdentifier+":"+message);
            }
        } else if (channel == SONIC_CHANNEL) {
            // If we get any message from a Novatech Sonic Sc rewdriver, toggle the power
            llRegionSayTo(objectKey, SONIC_CHANNEL, "ccSonicOK");
            power_state = !power_state;
            llMessageLinked(LINK_SET, power_state, POWER, NULL_KEY);
            llMessageLinked(LINK_SET, 0, STATUS, objectKey);
        }
    }
    timer() { 
        resetMenu();
    }

}
