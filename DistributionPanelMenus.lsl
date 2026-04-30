// ****************************************
// DistributionPanelMenu
// Menu and Message Utilities
// This is all about communicating with the user.

string debug_string = "Info";

// constants
integer MONITOR_CHANNEL = -6546478;
integer POWER_CHANNEL = -654647;
integer ZapChannel = -106969;
string ZAPREQ = "Zap-REQ";
key guards = "b3947eb2-4151-bd6d-8c63-da967677bc69";

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
string SWITCH = "Switch";
string XP = "XP";

string dataScriptName = "DistributionPanelData";
string logicScriptName = "DistributionPanelLogic";

string MAIN = "Main";
string SUB = "Sub";
string panel_size;

string breaker_1 = "238d4742-c609-fe39-7094-259ca80a9a69";

// *********************************
// Debug system
// Higher numbers are lower priority.
integer ERROR = 0;
integer WARN = 1;
integer INFO = 2;
integer DEBUG = 3;
integer TRACE = 4;
string DEBUG_LEVEL = "DebugLevel";
list debug_levels = ["ERROR", "WARN", "INFO", "DEBUG", "TRACE"];
list debug_volumes = ["shout", "shout", "say", "whisper", "whisper"];
integer debug_level = 2; // debug normally 2 info. 

sayDebug(integer message_level, string message) {
    if (message_level <= debug_level) {
        string level = llList2String(debug_levels, message_level);
        string volume = llList2String(debug_volumes, message_level);
        string json = llList2Json(JSON_OBJECT, [level, "MENU: "+message]);
        if (volume == "shout") {
            llShout(MONITOR_CHANNEL, json);
        } else if (volume == "say") {
            llSay(MONITOR_CHANNEL, json);
        } else if (volume == "whisper") {
            llWhisper(MONITOR_CHANNEL, json);
        } 
    }
}

setDebugLevel(integer new_debug_level) {
    debug_level = new_debug_level;
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

sendXP(key agent, integer XP) {
    llRegionSayTo(agent, MONITOR_CHANNEL, llList2Json(JSON_OBJECT, ["XP", (string)XP]));
}

integer get_power_switch_state() {
    return (integer)llLinksetDataRead("power_switch_state");
}

set_power_switch_state(integer newState) {
    llLinksetDataWrite("power_switch_state", (string)newState);
    llMessageLinked(LINK_SET, newState, POWER, NULL_KEY);
    sayDebug(INFO,menuOnOffButton("Set Panel Power ", newState));
}

integer agentIsInGroup(key agent, key groupKey)
{
    list attachList = llGetAttachedList(agent);
    integer item;
    while(item < llGetListLength(attachList))
    {
        if(llList2Key(llGetObjectDetails(llList2Key(attachList, item), [OBJECT_GROUP]), 0) == groupKey) {
            return TRUE;
        }
        item++;
    }
    return FALSE;
}

// Known Sources - needed to present "connect source" menu
integer get_num_known_sources() {
    return (integer)llLinksetDataRead("num_known_sources"); 
}

integer get_known_source_key_index(string source_key) {
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
string get_known_source_key(integer source_num) {
    return llLinksetDataRead(KNOWN+(string)source_num+KEY);
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

list get_known_source_distance_index; // local to Menu
sort_known_sources() {
    // sort the indexes list so we can present known sources in distance order
    get_known_source_distance_index = [];
    integer num_known_sources = get_num_known_sources();
    integer i;
    for (i = 1; i <= num_known_sources; i = i + 1) {
        get_known_source_distance_index = get_known_source_distance_index + [i, get_known_source_distance(i)];
    }
    get_known_source_distance_index = llListSortStrided(get_known_source_distance_index, 2, 1, TRUE);
    //sayDebug(DEBUG,"sort_known_sources:"+(string)get_known_source_distance_index);
}

integer unsorted(integer i) {
    // given a sorted index, return the unsorted index
    return llList2Integer(get_known_source_distance_index, i*2-2);
}

// conected Sources - Needed for "Connect Source" and "Disconnect Source" menu. 
// [key, name, capacity, rate]
integer get_num_sources() {
    return (integer)llLinksetDataRead("num_sources"); 
}

string get_connected_source_key(integer source_num) {
    return llLinksetDataRead(SOURCE+(string)source_num+KEY);
}
string get_connected_source_name(integer source_num) {
    return llLinksetDataRead(SOURCE+(string)source_num+NAME);
}
integer get_connected_source_capacity(integer source_num) {
    return (integer)llLinksetDataRead(SOURCE+(string)source_num+CAPACITY);
}
integer get_connected_source_rate(integer source_num) {
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
integer get_drain_switch(integer drain_num) {
    return (integer)llLinksetDataRead(DRAIN+(string)drain_num+SWITCH);
}
set_drain_switch(integer drain_num, integer newState) {
    llLinksetDataWrite(DRAIN+(string)drain_num+SWITCH, (string)newState);
    llMessageLinked(LINK_SET, 0, "HandleBreaker", NULL_KEY);
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
string BREAKERS = "Breakers";
string mainMenu = "Main";
string rightArrow = "→️"; // ⇒ →    ⇥  ↘️ →
string leftArrow = "←"; // ⇐ ←  ⇤
integer dialog_channel;
integer dialog_listen;
integer dialog_countdown;
string menuIdentifier;
key menuAgentKey;
integer menuChannel;
integer menuListen;
integer menuTimeout;
integer DDMenuPage; // 0-based
integer DDMenuPages;

string menuCheckbox(string title, integer onOff)
// make checkbox menu item out of a button title and boolean state
{
    string checkbox;
    if (onOff) {
        return "☒ " + title;
    } else {
        return "☐ " + title;
    }
}

string onOffButton(integer onOff)
// make checkbox menu item out of a button title and boolean state
{
    string onOffButton;
    if (onOff) {
        return "●";
    } else {
        return "○";
    }
}


string menuOnOffButton(string title, integer onOff)
// make checkbox menu item out of a button title and boolean state
{
    return onOffButton(onOff) + " " + title;
}

string menuRadioButton(string title, string match)
// make radio button menu item out of a button and the state text
{
    return onOffButton(title == match) + " "  + title;
}

string menuButtonActive(string title, integer onOff)
// make a menu button be the text or the Inactive symbol
{
    string button;
    if (onOff) {
        return title;
    } else {
        return "["+title+"]";
    }
}

string trimMessageButton(string message) {
    string messageButtonsTrimmed = message;
    
    list LstripList = ["☒ ","☐ ","● ","○ ", "❋ ", "○ "];
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
    if (llStringLength(message) > 400) {
        sayDebug(WARN,"setUpMenu message ws too long. Truncating.");
        message = llGetSubString(message,0,400);
    }
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

presentMainMenu(key whoClicked, integer allowed) {
    string message = panel_size + " Power Panel\n";    
    list buttons = [];
    buttons = buttons + STATUS;
    buttons = buttons + menuButtonActive(DEBUG_LEVEL, allowed);
    buttons = buttons + menuButtonActive(RESET, allowed);
    buttons = buttons + menuButtonActive(CONNECT_SOURCE, (get_num_known_sources() > 0) & allowed);
    buttons = buttons + menuButtonActive(DISCONNECT_SOURCE, (get_num_sources() > 0) & allowed);
    buttons = buttons + menuButtonActive(DISCONNECT_DRAIN, (get_num_drains() > 0) & allowed); 
    buttons = buttons + menuButtonActive(menuOnOffButton(
                        "Power", get_power_switch_state()),
                        (panel_size == SUB) | allowed );
    buttons = buttons + menuButtonActive(BREAKERS, allowed);
    buttons = buttons + menuButtonActive(PING, allowed);

    //buttons = buttons + RESTART;
    setUpMenu(mainMenu, whoClicked, message, buttons);
}

handleMainMenu(key objectKey, string message) {
            if (message == STATUS) {
                integer ingroup = agentIsInGroup(objectKey, guards);
                report_status(ingroup);
                llMessageLinked(LINK_SET, ingroup, STATUS, objectKey);
                llSleep(2);
                sendXP(objectKey, 1);
            } else if (message == DEBUG_LEVEL) {
                presentDebugLevelMenu(objectKey);
            } else if (message == RESET) {
                sendXP(objectKey, 10);
                restartScripts();
                
            } else if (message == CONNECT_SOURCE) {
                presentConnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_SOURCE) {
                presentDisonnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_DRAIN) {
                presentDrainBreakerMenu(objectKey, 0, TRUE);
            } else if (trimMessageButton(message) == POWER) {
                set_power_switch_state(!get_power_switch_state());
                sendXP(objectKey, 10);
            } else if (message == BREAKERS) {
                presentDrainBreakerMenu(objectKey, 0, FALSE);
            } else if (message == PING) {
                llMessageLinked(LINK_SET, 0, PING, objectKey);
                sendXP(objectKey, 1);
            }

}


presentDebugLevelMenu(key whoClicked) {
    string message = "Set the Debug Level:";
    string debug_level_text = llList2String(debug_levels, debug_level);
    list buttons = [];
    integer i;
    for (i = 0; i < llGetListLength(debug_levels); i = i + 1) {
        buttons = buttons + menuRadioButton(llList2String(debug_levels, i), debug_level_text);
    }
    setUpMenu(DEBUG_LEVEL, whoClicked, message, buttons);
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
        string item = "\n" + (string)source_num + ": " + get_known_source_name(unsorted_index) + " (" +
            EngFormat(get_known_source_power(unsorted_index)) + ") " + (string)get_known_source_distance(unsorted_index) + "m";
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
            get_connected_source_name(i) + " " + EngFormat(get_connected_source_capacity(i));
        buttons = buttons + [(string)i];
    }
    setUpMenu(DISCONNECT_SOURCE, whoClicked, message, buttons);    
}

presentDrainBreakerMenu(key whoClicked, integer menuPage, integer disconnect) {
    // Handles Breaker ON/OFF and Breaker DISCONNECT
    string message = "Select Power Drain to Switch:";
    string identifier = BREAKERS;
    if (disconnect) {
        message = "Select Power Drain to Disconnect:";
        identifier = DISCONNECT_DRAIN;
    }
    
    list buttons = [];
    integer startindex;
    integer endindex; 
    integer numCDrains = get_num_drains();

    if (numCDrains <= 9) {
        // Buttons fit on one page
        DDMenuPages = 1;
        startindex = 1;
        endindex = numCDrains;
    } else {
        // need more than one page
        DDMenuPages = llCeil(numCDrains / 9 + 0.5);
        
        if (menuPage >= DDMenuPages) {
            DDMenuPage = 0; 
        } else if (menuPage < 0) {
            DDMenuPage = DDMenuPages-1;
        } else {
            DDMenuPage = menuPage;
        }

        startindex = 1 + DDMenuPage * 9;
        endindex = 9 + DDMenuPage * 9;
        if (endindex > numCDrains) {
            endindex = numCDrains;
        }
        buttons = buttons + [leftArrow, mainMenu, rightArrow];
    }

    integer index;
    for (index = startindex; index <= endindex; index = index + 1) {
        string switch = onOffButton(get_drain_switch(index));
        message = message + "\n" + (string)index +
            " " + switch + 
            " " + EngFormat(get_drain_demand(index)) +      
            " " + get_drain_name(index);
        buttons = buttons + [(string)index + " " + switch];
    }
    setUpMenu(identifier, whoClicked, message, buttons);    
}

handleBreaker(string message) {
    sayDebug(DEBUG, "HandleBreaker(\"" + message + "\")");
    llPlaySound(breaker_1, 1.0);
    integer drain_num = (integer)message;
    integer switch;
    if (llSubStringIndex(message, "●") > -1) {
        switch = FALSE;
    } else if (llSubStringIndex(message, "○") > -1) {
        switch = TRUE;
    } else {
        sayDebug(ERROR, "HandleBreaker(\"" + message + "\") did not contain correct symbol.");
    }
    sayDebug(DEBUG,menuOnOffButton("Set Breaker Power ", switch));
    set_drain_switch(drain_num, switch);
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

report_status(integer ingroup) {
    string status;
    status = status + "Device Report for "+llGetObjectName();
    status = status + "\nDebug Level:"+llList2String(debug_levels, debug_level);
    status = status + "\nScript Versions:";
    status = status + "\n" +getScriptName(dataScriptName);
    status = status + "\n" +getScriptName(logicScriptName);
    status = status + "\n" +llGetScriptName();
    status = status + "\nFree Memory: " + (string)llGetFreeMemory();
    if (ingroup) {
        sayDebug(DEBUG, status);
    } else {
        llWhisper(0, status);
    }
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

handleMenu(string name, key objectKey, string message) {
    sayDebug(TRACE, "listen menuIdentifier:"+menuIdentifier+" name:"+name+" message:"+message);
    resetMenu();
            
    if (menuIdentifier == mainMenu) {
        handleMainMenu(objectKey, message);
    } else if (menuIdentifier == DEBUG_LEVEL) {
        setDebugLevelByName(trimMessageButton(message));
        llLinksetDataWrite(DEBUG_LEVEL, (string)debug_level);
        llMessageLinked(LINK_SET, debug_level, DEBUG_LEVEL, NULL_KEY);
        sendXP(objectKey, 1);
    } else if (menuIdentifier == CONNECT_SOURCE) {
        sayDebug(DEBUG, "listen CONNECT_SOURCE from "+name+": "+message);
        llPlaySound(breaker_1, 1.0);
        llRegionSayTo(get_known_source_key(unsorted((integer)message)), POWER_CHANNEL, CONNECT+REQ);
        sayDebug(INFO, "Connected Source "+get_known_source_name((integer)message));
        sendXP(objectKey, 10);
    } else if (menuIdentifier == DISCONNECT_SOURCE) {
        llPlaySound(breaker_1, 1.0);
        sayDebug(DEBUG, "listen DISCONNECT_SOURCE from "+name+": "+message);
        key source_key = get_connected_source_key((integer)message);
        llRegionSayTo(source_key, POWER_CHANNEL, DISCONNECT+REQ);
        llMessageLinked(LINK_SET, (integer)message, "handle_disconnect_req", source_key);
        sayDebug(INFO, "Disonnected Source "+get_connected_source_name((integer)message));
        sendXP(objectKey, 10);

    // DISCONNECT_SOURCE and DISCONNECT_DRAIN go into the same handler in Data
    // because Data can also receive generic DISCONNECT+ACKs 
    // that it won't know whether they are source or drain.
    // Separating them out here and making a deparate dispatcher is more complicated. 
    } else if (menuIdentifier == DISCONNECT_DRAIN) {
        if (message == leftArrow) {
            presentDrainBreakerMenu(objectKey, DDMenuPage-1, TRUE);
        } else  if (message == rightArrow) {
            presentDrainBreakerMenu(objectKey, DDMenuPage+1, TRUE);
        } else if (message == mainMenu) {
            presentMainMenu(objectKey, TRUE);
        } else {
            sayDebug(DEBUG, "listen DISCONNECT_DRAIN from "+name+": "+message);
            llPlaySound(breaker_1, 1.0);
            key drain_key = get_drain_key((integer)message);
            llRegionSayTo(drain_key, POWER_CHANNEL, DISCONNECT+REQ);
            llMessageLinked(LINK_SET, (integer)message, "handle_disconnect_req", drain_key);
            sendXP(objectKey, 5);
            llSleep(1.0); // pause for linkset data write
            sayDebug(INFO, "Disonnected Drain "+get_drain_name((integer)message));
            presentDrainBreakerMenu(objectKey, 0, TRUE);
        }

    // DISCONNECT_SOURCE and DISCONNECT_DRAIN go into the same handler in Data
    // because Data can also receive generic DISCONNECT+ACKs 
    // that it won't know whether they are source or drain.
    // Separating them out here and making a deparate dispatcher is more complicated. 
    } else if (menuIdentifier == BREAKERS) {
        if (message == leftArrow) {
            presentDrainBreakerMenu(objectKey, DDMenuPage-1, FALSE);
        } else  if (message == rightArrow) {
            presentDrainBreakerMenu(objectKey, DDMenuPage+1, FALSE);
        } else if (message == mainMenu) {
            presentMainMenu(objectKey, TRUE);
        } else {
            handleBreaker(message);
            sendXP(objectKey, 2);
            presentDrainBreakerMenu(objectKey, 0, FALSE);
        }
    } else {
        sayDebug(ERROR, "listen did not handle "+menuIdentifier+":"+message);
    }
}


default
{
    state_entry()
    {
        sayDebug(TRACE, "state_entry");
        debug_level = (integer)llLinksetDataRead(DEBUG_LEVEL);
        setDebugLevelByNumber(debug_level);

        // make sure logic has figured out whether it's main or sub
        llSleep(0.2);
        panel_size = llLinksetDataRead("panel_size");
        
        // listen to Novatech sonic screwdriver
        llListen(SONIC_CHANNEL, "", "", "ccSonic");

        sayDebug(TRACE, "state_entry done");
    }

    touch_start(integer total_number)
    {
        //sayDebug(DEBUG, "touch_start");
        key whoClicked = llDetectedKey(0);
        presentMainMenu(whoClicked, agentIsInGroup(whoClicked, guards));
    }
    
    listen(integer channel, string name, key objectKey, string message)
    {
        if (channel == menuChannel) {
            handleMenu(name, objectKey, message);
        } else if (channel == SONIC_CHANNEL) {
            // If we get any message from a Novatech Sonic Screwdriver, toggle the power
            sayDebug(WARN, "Sonic Screwdriver in use.");
            llRegionSayTo(objectKey, SONIC_CHANNEL, "ccSonicOK");
            set_power_switch_state(!get_power_switch_state());
            llMessageLinked(LINK_SET, 0, STATUS, objectKey);
        }
    }
    timer() { 
        resetMenu();
    }

}
