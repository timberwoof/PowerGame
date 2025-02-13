// Mechanics Power Game HUD
// Should be able to...
// Ping nearby sources (20m or 5m range)
// List them in distance order
// Choose one to listen to
// Set its debug level (ERROR, WARN, INFO, DEBUG, TRACE)
// Receive its debug messages
//
// What shodul it not do
// Duplicate all the menu functionality of the device. 
// The device has its own control menus 
// 
// Side Effects
// Anyone in range of a device set to talk debug will receive the messages. 
// You only hear messages if you're close enough
//
// Error Levels
// ERROR - events that cause power shut down (shout)
// WARN - situations that will cause power shut down if not fixed (shout)
// INFO - normal operating messages: connections, disconnections (say)
// DEBUG - messages received (whisper)
// TRACE - nitty gritty defails (whisper)
//
// Device error levels
// ERROR - only report errors
// WARN - only report Warnings or higher
// INFO - only report info or higher
// DEBUG - only report debug or higher
// TRACE - report everything
// 
// Can't have every device in trace mode. 
// Trace and debug modes are remporary and 
// they only send messages to the one who requested them. 
//
// Messages are only sent on the reporting channel. 
//

integer MONITOR_CHANNEL = -6546478;
integer POWER_CHANNEL = -654647;

string CLOSE = "Close";
string mainMenu = "Main";
string menuIdentifier;
key menuAgentKey;
integer menuChannel;
integer menuListen;
integer menuTimeout;
integer pingTimeout;


string STATUS = "Status";
string REQ = "-REQ";
string ACK = "-ACK";
string PING = "Ping";
string RESET = "Reset";
string CONNECT_SOURCE = "Connect Src";
string DEBUG = "Debug";

list known_sources; // [key, name, power, distance]
integer num_known_sources = 0;
integer known_sources_are_sorted = FALSE;

integer debug_state = TRUE;
sayDebug(string message) {
    if (debug_state) {
        llOwnerSay(message);
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
    sayDebug("setUpMenu "+identifier);
    menuIdentifier = identifier;
    menuAgentKey = avatarKey; // remember who clicked
    menuChannel = -(llFloor(llFrand(10000)+1000));
    menuListen = llListen(menuChannel, "", avatarKey, "");
    menuTimeout = llFloor(llGetTime()) + 30;
    llSetTimerEvent(2);
    llDialog(avatarKey, message, buttons, menuChannel);
}

resetMenu() {
    llListenRemove(menuListen);
    llSetTimerEvent(0);
    menuListen = 0;
    menuChannel = 0;
    menuAgentKey = "";
    menuTimeout = 0;
}

presentMainMenu(key whoClicked) {
    string message = "Power HUD Main Menu";
    list buttons = [];
    buttons = buttons + STATUS;
    buttons = buttons + PING; 
    buttons = buttons + RESET; // *** might not be a good idea
    buttons = buttons + menuCheckbox(DEBUG, debug_state);
    setUpMenu(mainMenu, whoClicked, message, buttons);
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
        sayDebug(item);
        if ((llStringLength(message) + llStringLength(item)) < 512) {
            message = message + item;
            buttons = buttons + [(string)i];
        }
    }
    setUpMenu(CONNECT_SOURCE, whoClicked, message, buttons);    
}

send_ping_req() {
    sayDebug("send_ping_req");
    num_known_sources = 0;
    known_sources = [];
    known_sources_are_sorted = FALSE;
    llShout(POWER_CHANNEL, PING+REQ);
    llSetTimerEvent(2);
}

add_known_source(string source_name, key source_key, integer source_power) {
    // respond to Ping-ACK
    sayDebug("add_known_source");
    vector myPos = llGetPos();
    list source_details = llGetObjectDetails(source_key, [OBJECT_POS]);    
    vector source_position = llList2Vector(source_details, 0);
    integer source_distance = llFloor(llVecDist(myPos, source_position));
    known_sources = known_sources + [source_key, source_name, source_power, source_distance]; 
    num_known_sources = num_known_sources + 1;
    pingTimeout = llFloor(llGetTime()) + 1;
}


string list_known_sources() {
    string result;
    result = result + "\nNearest Known Power Sources: capacity, distance";
    if (num_known_sources > 0) {
        integer source_num;
        for (source_num = 1; 
            (source_num <= num_known_sources) & (source_num <= 20); 
            source_num = source_num + 1) {
            result = result + "\n" + 
                known_source_name(source_num) + ": " +  
                EngFormat(known_source_power(source_num))+", " + 
                (string)known_source_distance(source_num)+"m";
        }
    } else {
        result = result + "\n" +  "No Power Sources known. Issue a Ping.";
    }
    return result;
}


report_status() {
    llOwnerSay("Status");
    llOwnerSay(list_known_sources());
}


default
{
    state_entry()
    {
        sayDebug("state_entry");
        llListen(MONITOR_CHANNEL, "", NULL_KEY, "");
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
        menuTimeout = 0;
        pingTimeout = 0;
    }

    touch_start(integer total_number)
    {
        sayDebug("touch_start");
        key whoClicked  = llDetectedKey(0);
        presentMainMenu(whoClicked);
    }
    
    listen(integer channel, string name, key objectKey, string message)
    {
        if (channel == menuChannel) {
            sayDebug("listen menuChannel \""+name+"\" says \""+message+"\"");
            resetMenu();
            if (message == STATUS) {
                report_status();
            } else if (message == RESET) {
                sayDebug("listen Reset");
                llResetScript();
            } else if (message == PING) {
                send_ping_req();
            } else if (trimMessageButton(message) == DEBUG) {
                debug_state = !debug_state;
            } else if (message == CONNECT_SOURCE) {
                presentConnectSourceMenu(objectKey);
            } else {
                sayDebug("listen did not handle "+menuIdentifier+":"+message);
            }
        } else if (channel == POWER_CHANNEL) {
            sayDebug("listen power_channel \""+name+"\" says \""+message+"\"");
            string trimmed_message = trimMessageParameters(message);
            integer parameter = getMessageParameter(message);
            if (trimmed_message == PING+ACK) {
                add_known_source(name, objectKey, parameter);
            }
        } else if (channel == MONITOR_CHANNEL) {
            llOwnerSay(name+": "+message);
        }
    }

    timer() {
        integer now = llFloor(llGetTime());
        if ((menuTimeout > 0) & now >= menuTimeout) {
            resetMenu();
        }
        if ((pingTimeout > 0) & (now >= pingTimeout)) {
            known_sources = llListSortStrided(known_sources, 4, 3, TRUE);
            list_known_sources();
            pingTimeout = 0;
            llSetTimerEvent(0);
        }
    }
}
