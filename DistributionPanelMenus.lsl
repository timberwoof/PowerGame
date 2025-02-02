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

list known_sources = [];

get_known_sources() {
    // [key, name, power, distance]
    known_sources = llJson2List(llLinksetDataRead("known_sources"));
    //known_sources = llListSortStrided(known_sources, 4, 3, TRUE);
    // Can't do this. The indexes end up wrong in Logic.
    sayDebug(TRACE, "get_known_sources get_num_known_sources():"+(string)get_num_known_sources());
    sayDebug(TRACE, "get_known_sources known_sources:"+(string)known_sources);
}

release_known_sources() {
    known_sources = [];
}

key known_source_key(integer i) {
    get_known_sources();
    key result = llList2Key(known_sources, i*4);
    release_known_sources();
    return result;
}
string known_source_name(integer i) {
    return llList2String(known_sources, i*4+1);
}
integer known_source_power(integer i) {
    return llList2Integer(known_sources, i*4+2);
}
integer known_source_distance(integer i) {
    return llList2Integer(known_sources, i*4+3);
}

// conected Sources
// [key, name, capacity, rate]
integer get_num_connected_sources() {
    return (integer)llLinksetDataRead("num_connected_sources"); 
}

list connected_sources = [];

get_connected_sources() {
    connected_sources = llJson2List(llLinksetDataRead("connected_sources"));
    sayDebug(DEBUG, "get_connected_sources get_num_connected_sources():"+(string)get_num_connected_sources());
    sayDebug(DEBUG, "get_connected_sources connected_sources:"+(string)connected_sources);
}

release_connected_sources() {
    connected_sources = [];
}

key connected_source_key(integer i) {
    return llList2Key(connected_sources, i*4);
}
string connected_source_name(integer i) {
    return llList2String(connected_sources, i*4+1);
}
integer connected_source_capacity(integer i) {
    return llList2Integer(connected_sources, i*4+2);
}
integer connected_source_rate(integer i) {
    return llList2Integer(connected_sources, i*4+3);
}


// conected drains
// [key, name, demand, rate]
integer get_num_connected_drains() {
    return (integer)llLinksetDataRead("num_connected_drains"); 
}

list connected_drains = [];

get_connected_drains() {
    connected_drains = llJson2List(llLinksetDataRead("connected_drains"));
    sayDebug(DEBUG, "get_connected_drains get_num_connected_drains():"+(string)get_num_connected_drains());
    sayDebug(DEBUG, "get_connected_drains connected_drains:"+(string)connected_drains);
}

release_connected_drains() {
    connected_drains = [];
}

key connected_drain_key(integer i) {
    return llList2Key(connected_drains, i*4);
}
string connected_drain_name(integer i) {
    return llList2String(connected_drains, i*4+1);
}
integer connected_drain_demand(integer i) {
    return llList2Integer(connected_drains, i*4+2);
}
integer connected_drain_rate(integer i) {
    return llList2Integer(connected_drains, i*4+3);
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
    get_known_sources();
    
    // If this needs otbe put into sorted order, 
    // Then we need to make a local copy of this list 
    // with an additional item in each stride, the original index. 
    // The response must look up the original index. 
   
    string message = "Select Power Source:";
    integer i;
    list buttons = [];
    get_connected_sources();
    for (i = 0; i < get_num_known_sources() & i < 12; i = i + 1) {
        string item = "\n" + (string)i + ": " + known_source_name(i) + " (" +
            EngFormat(known_source_power(i)) + ") " + (string)known_source_distance(i) + "m";
        sayDebug(TRACE, item);
        if ((llStringLength(message) + llStringLength(item)) < 512) {
            message = message + item;
            buttons = buttons + [(string)i];
        }
    }
    release_known_sources();
    setUpMenu(CONNECT_SOURCE, whoClicked, message, buttons);    
}

presentDisonnectSourceMenu(key whoClicked) {
    string message = "Select Power Source to Disconnect:";
    integer i;
    list buttons = [];
    get_connected_sources();
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
    get_connected_drains();
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

default
{
    state_entry()
    {
        sayDebug(DEBUG, "state_entry");
        setDebugLevelByNumber(DEBUG);
        
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
                llRegionSayTo(known_source_key((integer)message), POWER_CHANNEL, CONNECT+REQ);
            } else if (menuIdentifier == DISCONNECT_SOURCE) {
                sayDebug(DEBUG, "listen DISCONNECT_SOURCE from "+name+": "+message);
                key source_key = connected_source_key((integer)message);
                llRegionSayTo(source_key, POWER_CHANNEL, DISCONNECT+REQ);
                llMessageLinked(LINK_SET, (integer)message, DISCONNECT_DRAIN, source_key);
            } else if (menuIdentifier == DISCONNECT_DRAIN) {
                sayDebug(DEBUG, "listen DISCONNECT_DRAIN from "+name+": "+message);
                key drain_key = connected_drain_key((integer)message);
                llRegionSayTo(drain_key, POWER_CHANNEL, DISCONNECT+ACK);
                llMessageLinked(LINK_SET, (integer)message, DISCONNECT+ACK, drain_key);
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
