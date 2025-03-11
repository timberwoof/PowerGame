// ****************************************
// Menu and Message Utilities
// This is all about communicting with the user.

string debug_string = "Info";

// constants
integer MONITOR_CHANNEL = -6546478;
integer POWER_CHANNEL = -654647;
integer ZapChannel = -106969;
string ZAPREQ = "Zap-REQ";

// interface to Novatech Sonic Screwdriver
integer SONIC_CHANNEL = -313331;    // Used by sonic screwdrivers. Do not change!

string KNOWN = "Known";
string SOURCE = "Source";
string DRAIN = "Drain";
string KEY = "Key";
string NAME = "Name";
string DISTANCE = "Distance";
string CAPACITY = "Capacity";
string DEMAND = "Demand";
string RATE = "Rate";

string dataScriptName = "DistributionPanelData";
string logicScriptName = "DistributionPanelLogic";

// *********************************
// Debug system
// Higher numbers are lower priority.
integer ERROR = 0;
integer WARN = 1;
integer INFO = 2;
integer DEBUG = 3;
integer TRACE = 4;
string DEBUG_LEVELS = "DebugLevels";
list debug_levels = ["Error", "Warning", "Info", "Debug", "Trace"];
integer debug_level = 0;
sayDebug(integer message_level, string message) {
    message = "MENU "+llList2String(debug_levels, message_level) + ": " + message;
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

integer power_switch_state;

integer agentIsInGroup(key agent, key groupKey)
{
    list attachList = llGetAttachedList(agent);
    integer item;
    while(item < llGetListLength(attachList))
    {
        if(llList2Key(llGetObjectDetails(llList2Key(attachList, item), [OBJECT_GROUP]), 0) == groupKey) {
            sayDebug(TRACE, "agentIsInGroup passed group check");
            return TRUE;
        }
        item++;
    }
    sayDebug(WARN, "agentIsInGroup failed group check");
    return FALSE;
}

// Known Sources - needed to present "connect source" menu
integer get_num_known_sources() {
    return (integer)llLinksetDataRead("num_known_sources"); 
}

integer known_source_key_index(string source_key) {
    integer num_known_sources = get_num_known_sources();
    if (num_known_sources == 0) {
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

list known_source_distance_index; // local to Menu
sort_known_sources() {
    // sort the indexes list so we can present known sources in distance order
    known_source_distance_index = [];
    integer num_known_sources = get_num_known_sources();
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

// conected Sources - Needed for "Connect Source" and "Disconnect Source" menu. 
// [key, name, capacity, rate]
integer get_num_sources() {
    return (integer)llLinksetDataRead("num_sources"); 
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

// conected drains - Needed for "Disconnewct Drain" menu. 
// [key, name, demand, rate]
integer get_num_drains() {
    return (integer)llLinksetDataRead("num_drains"); 
}

integer drain_key_index(string drain_key) {
    if (get_num_drains() == 0) {
        return -1;
    }
    integer i;
    for (i = 1; i <= get_num_drains(); i = i + 1) {
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

// ****************************************************
// Constants and Variables for Second Life Dialog Boxes
string REQ = "-REQ";
string ACK = "-ACK";
string STATUS = "Status";
string PING = "Ping";
string CONNECT = "Connect";
string DISCONNECT = "Disconnect";
string CLOSE = "Close";
string POWER = "Power";
string RESET = "Reset";
string RESTART = "Restart";
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
integer DDmenuPage; // 0-based

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
    string message = "Power Panel Main Menu \n" +
        getScriptName(dataScriptName) + "\n" +
        getScriptName(logicScriptName) + "\n" +
        llGetScriptName();
    list buttons = [];
    // system management menu items
    buttons = buttons + DEBUG_LEVELS;
    buttons = buttons + RESTART;
    buttons = buttons + RESET;
    // power management menu items
    buttons = buttons + menuButtonActive(CONNECT_SOURCE, get_num_known_sources() > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_SOURCE, get_num_sources() > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_DRAIN, get_num_drains() > 0); 
    buttons = buttons + menuCheckbox("Power", power_switch_state);
    buttons = buttons + STATUS;
    buttons = buttons + PING; 
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
    sort_known_sources();
    // Sorts the index list
    // The response must look up the original index by calling unsorted()
    string message = "Select Power Source:";
    list buttons = [];
    integer source_num;
    for (source_num = 1; source_num <= get_num_known_sources() & source_num <= 12; source_num = source_num + 1) {
        integer unsorted_index = unsorted(source_num);
        string item = "\n" + (string)source_num + ": " + known_source_name(unsorted_index) + " (" +
            EngFormat(known_source_power(unsorted_index)) + ") " + (string)known_source_distance(unsorted_index) + "m";
        sayDebug(TRACE, item);
        if ((llStringLength(message) + llStringLength(item)) < 512) {
            message = message + item;
            buttons = buttons + [(string)source_num];
        }
    }
    setUpMenu(CONNECT_SOURCE, whoClicked, message, buttons);    
}

presentDisonnectSourceMenu(key whoClicked) {
    string message = "Select Power Source to Disconnect:";
    integer i;
    list buttons = [];
    for (i = 1; i <= get_num_sources(); i = i + 1) {
        message = message + "\n" + (string)i + " " + 
            connected_source_name(i) + " " + EngFormat(connected_source_capacity(i));
        buttons = buttons + [(string)i];
    }
    setUpMenu(DISCONNECT_SOURCE, whoClicked, message, buttons);    
}

presentDisonnectDrainMenu(key whoClicked, integer page) {
    string message = "Select Power Drain to Disconnect:";
    integer index;
    list buttons = [];
    integer startindex;
    integer endindex; 
    integer numCDrains = get_num_drains();
    DDmenuPage = page;
    if (numCDrains <= 12) {
        startindex = 1;
        endindex = numCDrains;
    } else {
        startindex = 1 + DDmenuPage * 9;
        endindex = 9 + DDmenuPage * 9;
        if (endindex > numCDrains) {
            endindex = numCDrains;
        }
        string left = "-";
        if (page > 0) {
            left = "<<";
        }
        string right = "-";
        if (page < llFloor(numCDrains / 9)) {
            right = ">>";
        }
        buttons = buttons + [left, mainMenu, right];
    }
    for (index = startindex; index <= endindex; index = index + 1) {
        message = message + "\n" + (string)index + " " + 
            connected_drain_name(index) + " " + EngFormat(connected_drain_demand(index));
        buttons = buttons + [(string)index];
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

report_status() {
    sayDebug(INFO, "======================");
    sayDebug(INFO, "Device Report for "+llGetObjectName());
    sayDebug(DEBUG, "Free Memory: " + (string)llGetFreeMemory());
}

// ***********************************
// Scripts

string getScriptName(string name) {
    integer numscripts = llGetInventoryNumber(INVENTORY_SCRIPT);
    integer i;
    for (i = 0; i < numscripts; i = i + 1) {
        string aScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        integer index = llSubStringIndex(aScriptName, name);
        if (index > -1) {
             return aScriptName;
        }
    }
    return "unknown";
}

resetScript(string scriptname) {
    if (!llGetScriptState(scriptname)) {
        sayDebug(WARN,"Script \"" + scriptname + "\" is not running.");
    }
    sayDebug(INFO,"Resetting script \"" + scriptname + "\"…");
    llResetOtherScript(scriptname);
    llSleep(2);
    if (!llGetScriptState(scriptname)) {
        sayDebug(INFO,"Attempting to restart script \"" + scriptname + "\"…");
        llSetScriptState(scriptname, TRUE);
        llSleep(4);
        if (!llGetScriptState(scriptname)) {
            sayDebug(ERROR,"Script \"" + scriptname + "\" is still not running after llSetScriptState(TRUE).");
        } else {
           sayDebug(INFO,"Successfully restarted script \"" + scriptname + "\"");
        }
    } else {
        sayDebug(INFO,"Successfully reset script \"" + scriptname + "\"");
    }
}

restartScripts() {
    resetScript(getScriptName(dataScriptName));
    resetScript(getScriptName(logicScriptName));
    llSleep(1);
    llResetScript();
}

default
{
    state_entry()
    {
        sayDebug(TRACE, "state_entry");
        debug_level = (integer)llLinksetDataRead(DEBUG_LEVELS);
        setDebugLevelByNumber(debug_level);
        power_switch_state = (integer)llLinksetDataRead("power_switch_state");
        
        // listen to Novatech sonic screwdriver
        llListen(SONIC_CHANNEL, "", "", "ccSonic");

        sayDebug(TRACE, "state_entry done");
    }

    touch_start(integer total_number)
    {
        //sayDebug(DEBUG, "touch_start");
        key whoClicked = llDetectedKey(0);
        key allowed = "b3947eb2-4151-bd6d-8c63-da967677bc69"; // guards
        if (agentIsInGroup(whoClicked, allowed)) {
            presentMainMenu(whoClicked);
        } else {
            llSay(-106969,(string)whoClicked);
            llRegionSayTo(whoClicked, POWER_CHANNEL, ZAPREQ+"[2]");
        }
    }
    
    listen( integer channel, string name, key objectKey, string message )
    {
        if (channel == menuChannel) {
            sayDebug(TRACE, "listen menuIdentifier:"+menuIdentifier+" name:"+name+" message:"+message);
            resetMenu();
            // Main Menu
            if (message == DEBUG_LEVELS) {
                presentDebugLevelMenu(objectKey);
            } else if (message == RESTART) {
                restartScripts();
            } else if (message == RESET) {
                sayDebug(WARN,"Resetting Data and Restarting Scripts.");
                llMessageLinked(LINK_SET, 0, "reset_data", NULL_KEY);
                llSleep(2);
                restartScripts();

            } else if (message == CONNECT_SOURCE) {
                presentConnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_SOURCE) {
                presentDisonnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_DRAIN) {
                presentDisonnectDrainMenu(objectKey, 0);
                
            } else if (trimMessageButton(message) == POWER) {
                power_switch_state = !power_switch_state;
                llMessageLinked(LINK_SET, power_switch_state, POWER, NULL_KEY);
            } else if (message == STATUS) {
                report_status();
                llMessageLinked(LINK_SET, 0, STATUS, objectKey);
            } else if (message == PING) {
                llMessageLinked(LINK_SET, 0, PING, objectKey);
                
            // menus with numeric buttons
            } else if (menuIdentifier == DEBUG_LEVELS) {
                setDebugLevelByName(trimMessageButton(message));
                llLinksetDataWrite(DEBUG_LEVELS, (string)debug_level);
                llMessageLinked(LINK_SET, debug_level, DEBUG_LEVELS, NULL_KEY);
            } else if (menuIdentifier == CONNECT_SOURCE) {
                sayDebug(DEBUG, "listen CONNECT_SOURCE from "+name+": "+message);
                llRegionSayTo(known_source_key(unsorted((integer)message)), POWER_CHANNEL, CONNECT+REQ);
            } else if (menuIdentifier == DISCONNECT_SOURCE) {
                sayDebug(DEBUG, "listen DISCONNECT_SOURCE from "+name+": "+message);
                key source_key = connected_source_key((integer)message);
                llRegionSayTo(source_key, POWER_CHANNEL, DISCONNECT+REQ);
                llMessageLinked(LINK_SET, (integer)message, "handle_disconnect_req", source_key);
            } else if (menuIdentifier == DISCONNECT_DRAIN) {
                sayDebug(DEBUG, "listen DISCONNECT_DRAIN from "+name+": "+message);
                key drain_key = connected_drain_key((integer)message);
                llRegionSayTo(drain_key, POWER_CHANNEL, DISCONNECT+REQ);
                llMessageLinked(LINK_SET, (integer)message, "handle_disconnect_req", drain_key);
            // Both these menus go into the same handler in Data
            // because Data can also receive generic DISCONNECT+ACKs 
            // that it won't know whether they are source or drain.
            // Separating them out here and making a deparate dispatcher is more complicated. 

            // menus with numeric buttons and long lists of things
            } else if (message == "<<") {
                presentDisonnectDrainMenu(objectKey, DDmenuPage-1);
            } else if (message == ">>") {
                presentDisonnectDrainMenu(objectKey, DDmenuPage+1);
            } else if (message == mainMenu) {
                presentMainMenu(objectKey);
                
            } else {
                sayDebug(ERROR, "listen did not handle "+menuIdentifier+":"+message);
            }
        } else if (channel == SONIC_CHANNEL) {
            // If we get any message from a Novatech Sonic Sc rewdriver, toggle the power
            sayDebug(WARN, "Sonic Screwdriver in use.");
            llRegionSayTo(objectKey, SONIC_CHANNEL, "ccSonicOK");
            power_switch_state = !power_switch_state;
            llMessageLinked(LINK_SET, power_switch_state, POWER, NULL_KEY);
            llMessageLinked(LINK_SET, 0, STATUS, objectKey);
        }
    }
    timer() { 
        resetMenu();
    }

}
