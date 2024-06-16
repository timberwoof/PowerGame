// Power Panel 
// Incremental build-up of Lamp Power Logicl 

integer POWER_CHANNEL = -654647;
integer clock_interval = 1;
integer power_ask = 100;
integer power_draw = 0;

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
string DEBUG = "Debug";
integer ON = TRUE;
integer OFF = FALSE;

list known_sources; // [key, name, power, distance]
integer num_known_sources = 0;
integer known_sources_are_sorted = FALSE;

key my_source_key;
string my_source_name;
integer my_source_power;
integer connected;
integer power_state;

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

integer debug_state = FALSE;
sayDebug(string message) {
    if (debug_state) {
        llSay(0,message);
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

// Known Sources
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
    list striplist = ["☒ ","☐ ","● ","○ "];
    integer i;
    for (i=0; i < llGetListLength(striplist); i = i + 1) {
        string thing = llList2String(striplist, i);
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
    sayDebug("setUpMenu "+identifier);    
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

presentMainMenu(key whoClicked) {
    string message = "Lamp Main Menu";
    list buttons = [];
    buttons = buttons + STATUS;
    buttons = buttons + PING; 
    buttons = buttons + menuButtonActive(CONNECT_SOURCE, num_known_sources > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_SOURCE, connected);
    buttons = buttons + menuButtonActive(menuCheckbox("Power", power_state), num_known_sources > 0);
    buttons = buttons + RESET;
    buttons = buttons + menuCheckbox(DEBUG, debug_state);
    setUpMenu(mainMenu, whoClicked, message, buttons);
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

send_ping_req() {
    sayDebug ("ping_req");
    num_known_sources = 0;
    known_sources = [];
    known_sources_are_sorted = FALSE;
    llShout(POWER_CHANNEL, PING+REQ);
}

add_known_source(string source_name, key source_key, integer source_power) {
    // respond to Ping-ACK
    sayDebug ("add_known_source("+source_name+") "+EngFormat(source_power));
    vector myPos = llGetPos();
    list source_details = llGetObjectDetails(source_key, [OBJECT_POS]);    
    vector source_position = llList2Vector(source_details, 0);
    integer source_distance = llFloor(llVecDist(myPos, source_position));
    // [key, name, power, distance]
    known_sources = known_sources + [source_key, source_name, source_power, source_distance]; 
    num_known_sources = num_known_sources + 1;
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


string power_state_to_string(integer power_state) {
    if (power_state) {
        return "On";
    } else {
        return "Off";
    }
}

report_status() {
    llSay(0, "Power: " + power_state_to_string(power_state) + ". " +
            "Consuming " + (string)power_draw + " watts " +
            "from power source " + my_source_name + ".");
}

set_power(integer new_power_state) {
    power_state = new_power_state;
    if (power_state) {
        llRegionSayTo(my_source_key, POWER_CHANNEL, POWER+REQ+"["+(string)power_ask+"]");
    } else {
        llRegionSayTo(my_source_key, POWER_CHANNEL, POWER+REQ+"[0]");
    }
}

toggle_power() {
    set_power(!power_state);
}

default
{
    state_entry()
    {
        sayDebug("state_entry");
        llSetTimerEvent(1);
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
        my_source_key = NULL_KEY;
        my_source_name = NONE;
        set_power(OFF);
        connected = FALSE;
        llMessageLinked(LINK_SET, power_draw, "Power", NULL_KEY);
        send_ping_req();
    }

    touch_start(integer total_number)
    {
        sayDebug("touch_start");
        key whoClicked  = llDetectedKey(0);
        presentMainMenu(whoClicked);
    }
    
    listen(integer channel, string name, key objectKey, string message )
    {
        sayDebug("listen name:"+name+" message:"+message);
        
        if (channel == menuChannel) {
            resetMenu();
            if (message == CLOSE) {
                sayDebug("listen Close");
            } else if (message == STATUS) {
                report_status();
            } else if (message == RESET) {
                llResetScript();
            } else if (message == PING) {
                send_ping_req();
            } else if (message == CONNECT_SOURCE) {
                presentConnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_SOURCE) {
                sayDebug("listen DISCONNECT from "+name+": "+message);
                llRegionSayTo(my_source_key, POWER_CHANNEL, DISCONNECT+REQ);
            } else if (menuIdentifier == CONNECT_SOURCE) {
                sayDebug("listen CONNECT from "+name+": "+message);
                llRegionSayTo(known_source_key((integer)message), POWER_CHANNEL, CONNECT+REQ);
            } else if (trimMessageButton(message) == POWER) {
                toggle_power();
            } else if (trimMessageButton(message) == DEBUG) {
                debug_state = !debug_state;
            } else if (trimMessageButton(message) == DEBUG) {
                debug_state = !debug_state;
            } else {
                sayDebug("listen did not handle "+menuIdentifier+":"+message);
            }
        } else if (channel == POWER_CHANNEL) {
            string trimmed_message = trimMessageParameters(message);
            integer parameter = getMessageParameter(message);
            if (trimmed_message == PING+ACK) {
                add_known_source(name, objectKey, parameter);
            } else if (trimmed_message == CONNECT+ACK) {
                my_source_key = objectKey;
                my_source_name = name;
                connected = TRUE;
                set_power(power_state); // does this even make sense?
            } else if (trimmed_message == DISCONNECT+ACK) {
                my_source_key = NULL_KEY;
                my_source_name = NONE;
                connected = FALSE;
                set_power(OFF);
            } else if (trimmed_message == POWER+ACK) {
                power_draw = getMessageParameter(message);
                power_state = (connected & (power_draw == power_ask));
                llMessageLinked(LINK_SET, power_draw, "Power", NULL_KEY);
                sayDebug("listen "+message+" "+(string)power_draw+" results in  power state:"+(string)power_state);
            }
        }
    }

    timer() {
        integer now = llFloor(llGetTime());
        if (now > menuTimeout) {
            resetMenu();
        }
    }
}
