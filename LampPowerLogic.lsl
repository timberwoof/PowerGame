// Power Panel 
// Incremental build-up of Lamp Power Logicl 

integer POWER_CHANNEL = -654647;
integer MONITOR_CHANNEL = -6546478;
integer clock_interval = 1;
integer powerAsk = 100;
integer powerAck = 0;

string REQ = "-REQ";
string ACK = "-ACK";
string PING = "Ping";
string STATUS = "Status";
string CONNECT = "Connect";
string DISCONNECT = "Disconnect";
string SOURCE = "Source"; // power source
string POWER = "Power";
string RESET = "Reset";
string NONE = "None";
string DEBUG = "Debug";

string CEILING = "Ceiling";
string INTERIOR = "Interior";
string LOCKDOWN = "Lockdown";
string MARKER = "Marker";
string POINT = "Point"; // light source
string SENSOR = "Sensor";

integer OPTION_CEILING = 0;
integer OPTION_INTERIOR = -1;
integer OPTION_LOCKDOWN = 0;
integer OPTION_MARKER = -1;
integer OPTION_POINT = 0;
integer OPTION_SENSOR = 0;

integer ON = TRUE;
integer OFF = FALSE;

list known_sources; // [key, name, power, distance]
integer num_known_sources = 0;
integer known_sources_are_sorted = FALSE;

key my_source_key;
string my_source_name;
integer connected;
integer power_switch_state;

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

string LinksetDataRead(string symbol) {
    symbol = (string)llGetLinkNumber()+symbol;
    return llLinksetDataRead(symbol);
}

LinksetDataWrite(string symbol, string value) {
    symbol = (string)llGetLinkNumber()+symbol;
    llLinksetDataWrite(symbol, value);
}

integer OPTION_DEBUG = FALSE;
sayDebug(string message) {
    if (OPTION_DEBUG) {
        llSay(MONITOR_CHANNEL,"Logic "+message);
    }
}

toggle_debug_state() {
    OPTION_DEBUG = !OPTION_DEBUG;
    LinksetDataWrite(DEBUG, (string)OPTION_DEBUG);
    llMessageLinked(LINK_THIS, OPTION_DEBUG, DEBUG, NULL_KEY);
}

integer agentIsInGroup(key agent, key groupKey)
{
    list attachList = llGetAttachedList(agent);
    integer item;
    while(item < llGetListLength(attachList))
    {
        if(llList2Key(llGetObjectDetails(llList2Key(attachList, item), [OBJECT_GROUP]), 0) == groupKey) {
            sayDebug("agentIsInGroup passed group check");
            return TRUE;
        }
        item++;
    }
    llSay(0, "warning: agentIsInGroup failed group check");
    return FALSE;
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

list menuButtonTriState(string title, integer onOff)
// if onOff = -1, the option is not avaialble. 
// otherwise, treat it as normal onoff. 
{
    list buttons;
    if (onOff < 0) {
        buttons = menuButtonActive(title, OFF);
    } else {
        buttons = [menuCheckbox(title, onOff)];
    }
    return buttons;
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

presentMainMenu(key whoClicked) {
    string message = "Lamp Main Menu";
    list buttons = [];
    buttons = buttons + STATUS;
    buttons = buttons + PING; 
    buttons = buttons + menuCheckbox(SOURCE, connected);
    buttons = buttons + menuButtonActive(menuCheckbox("Power", power_switch_state), num_known_sources > 0);
    buttons = buttons + RESET;
    buttons = buttons + menuCheckbox(DEBUG, OPTION_DEBUG);
    buttons = buttons + menuButtonTriState(MARKER, OPTION_MARKER);
    buttons = buttons + menuButtonTriState(INTERIOR, OPTION_INTERIOR);
    buttons = buttons + menuCheckbox(POINT, OPTION_POINT);
    buttons = buttons + menuCheckbox(CEILING, OPTION_CEILING);
    buttons = buttons + menuCheckbox(LOCKDOWN, OPTION_LOCKDOWN);
    buttons = buttons + menuCheckbox(SENSOR, OPTION_SENSOR);
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
    //sayDebug ("add_known_source("+source_name+") "+EngFormat(source_power));
    vector myPos = llGetPos();
    list source_details = llGetObjectDetails(source_key, [OBJECT_POS]);    
    vector source_position = llList2Vector(source_details, 0);
    integer source_distance = llFloor(llVecDist(myPos, source_position));
    // [key, name, power, distance]
    known_sources = known_sources + [source_key, source_name, source_power, source_distance]; 
    num_known_sources = num_known_sources + 1;
}

presentConnectSourceMenu(key whoClicked) {
    sayDebug("presentConnectSourceMenu");
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
        if ((llStringLength(message) + llStringLength(item)) < 512) {
            message = message + item;
            buttons = buttons + [(string)i];
        }
    }
    setUpMenu(SOURCE, whoClicked, message, buttons);    
}


string power_state_to_string(integer power_state) {
    sayDebug("power_state_to_string("+(string)power_state+")");
    if (power_state) {
        return "On";
    } else {
        return "Off";
    }
}

report_status() {
    string status = "Lamp Logic Status\n" +
        "Power source: " + my_source_name + "\n" +
        "Power: " + power_state_to_string(power_switch_state) + "\n" +
        "Requested " + (string)powerAsk + " watts \n" +
        "Drawing " + (string)powerAck + " watts";
    llSay(MONITOR_CHANNEL, status);
}

set_power(integer new_power_state) {
    // called by toggle_power/
    // sends power switch state to the lamp, 
    // which calls back with a power ask
    power_switch_state = new_power_state;
    sayDebug("set_power llMessageLinked powerSwitch:"+(string)power_switch_state);
    llMessageLinked(LINK_THIS, power_switch_state, "powerSwitch", NULL_KEY);
}

toggle_power() {
    // Called by menu handler
    sayDebug("toggle_power()");
    set_power(!power_switch_state);
}

toggle_source(string name, key objectKey, string message) {
    sayDebug("toggle_source "+message+" connected:"+(string)connected);
    if (connected) {
        sayDebug("toggle_source "+DISCONNECT+REQ);
        llRegionSayTo(my_source_key, POWER_CHANNEL, DISCONNECT+REQ);
        LinksetDataWrite("my_source_key","");
        LinksetDataWrite("my_source_name",NONE);
    } else {
        sayDebug("toggle_source CONNECT");
        presentConnectSourceMenu(objectKey);
    }
}

default
{
    state_entry()
    {
        OPTION_DEBUG = (integer)LinksetDataRead(DEBUG);
        sayDebug("state_entry");
        OPTION_POINT = (integer)LinksetDataRead(POINT);        
        OPTION_CEILING = (integer)LinksetDataRead(CEILING);
        OPTION_LOCKDOWN = (integer)LinksetDataRead(LOCKDOWN);
        OPTION_MARKER = (integer)LinksetDataRead(MARKER);
        OPTION_INTERIOR = (integer)LinksetDataRead(INTERIOR);
        OPTION_SENSOR = (integer)LinksetDataRead(SENSOR);
        my_source_key = LinksetDataRead("my_source_key");
        my_source_name = LinksetDataRead("my_source_name");
        sayDebug("state_entry my_source_name:\""+my_source_name+"\"");
        llSetTimerEvent(1);
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
        powerAck = 0;
        powerAsk = 0;
        if (my_source_key) {
            connected = TRUE;
        } else {
            connected = FALSE;
        }
        sayDebug("state_entry llMessageLinked powerAck:"+(string)powerAck);
        llMessageLinked(LINK_THIS, powerAck, "powerAck", NULL_KEY);
        send_ping_req();
        report_status();
        sayDebug("state_entry done");
    }

    touch_start(integer total_number)
    {
        //sayDebug("touch_start");
        key whoClicked = llDetectedKey(0);
        key allowed = "b3947eb2-4151-bd6d-8c63-da967677bc69"; // guards
        if (agentIsInGroup(whoClicked, allowed)) {
            presentMainMenu(whoClicked);
        } else {
            llSay(-106969,(string)whoClicked);
            llRegionSayTo(whoClicked, POWER_CHANNEL, "Zap-REQ[2]");
        }
    }
    
    link_message(integer sender_num, integer num, string msg, key id) {
        //sayDebug("link_message("+msg+", "+(string)num+")");
        if (id == NULL_KEY) {
            return;
        } else if (msg == "Ask") {
            powerAsk = num;
            string message = POWER+REQ+"["+(string)powerAsk+"]";
            sayDebug("link_message sends \""+message+ "\" to "+my_source_name);
            llRegionSayTo(my_source_key, POWER_CHANNEL, message);
        } else if ((msg == "Debug") | (msg == "powerSwitch") | (msg == "powerAck") | (msg == "Status")) {
            // ignore as we send these 
        } else if (msg == CEILING) {
            OPTION_CEILING = num;
        } else if (msg == INTERIOR) {
            OPTION_INTERIOR = num;
        } else if (msg == MARKER) {
            OPTION_MARKER = num;
        } else if (msg == LOCKDOWN) {
            OPTION_LOCKDOWN = num;
        } else if (msg == POINT) {
            OPTION_POINT = num;
        } else if (msg == SENSOR) {
            OPTION_SENSOR = num;
        } else {
            sayDebug("error: link_message did not handle msg:"+msg+" "+(string)num);
        }
        //sayDebug("link_message done");
    }
    
    listen(integer channel, string name, key objectKey, string message )
    {        
        if (channel == menuChannel) {
            sayDebug("listen menuChannel name:"+name+" message:"+message);
            resetMenu();
            if (message == CLOSE) {
                sayDebug("listen Close");
            } else if (message == STATUS) {
                report_status();
                llMessageLinked(LINK_THIS, 0, "Status", NULL_KEY);
            } else if (message == RESET) {
                llMessageLinked(LINK_THIS, 0, "Reset", NULL_KEY);
                llSleep(1);
                llResetScript();
            } else if (message == PING) {
                send_ping_req();
            } else if (trimMessageButton(message) == SOURCE) {
                toggle_source(name, objectKey, message);
            } else if (menuIdentifier == SOURCE) {
                sayDebug("listen CONNECT from "+name+": "+message);
                llRegionSayTo(known_source_key((integer)message), POWER_CHANNEL, CONNECT+REQ);
            } else if (trimMessageButton(message) == POWER) {
                toggle_power();
            } else if (trimMessageButton(message) == DEBUG) {
                toggle_debug_state();
            } else if (trimMessageButton(message) == LOCKDOWN) {
                OPTION_LOCKDOWN = !OPTION_LOCKDOWN;
                llMessageLinked(LINK_THIS, OPTION_LOCKDOWN, LOCKDOWN, NULL_KEY);
            } else if (trimMessageButton(message) == SENSOR) {
                OPTION_SENSOR = !OPTION_SENSOR;
                llMessageLinked(LINK_THIS, OPTION_SENSOR, SENSOR, NULL_KEY);
            } else if (trimMessageButton(message) == INTERIOR) {
                OPTION_INTERIOR = !OPTION_INTERIOR;
                llMessageLinked(LINK_THIS, OPTION_INTERIOR, INTERIOR, NULL_KEY);
                if (OPTION_MARKER) {
                    OPTION_MARKER = OFF;
                    sayDebug("listen menuChannel INTERIOR");
                    llMessageLinked(LINK_THIS, OPTION_MARKER, MARKER, NULL_KEY);
                }
            } else if (trimMessageButton(message) == MARKER) {
                OPTION_MARKER = !OPTION_MARKER;
                sayDebug("listen menuChannel MARKER");
                llMessageLinked(LINK_THIS, OPTION_MARKER, MARKER, NULL_KEY);
                if (OPTION_INTERIOR) {
                    OPTION_INTERIOR = OFF;
                    llMessageLinked(LINK_THIS, OPTION_INTERIOR, INTERIOR, NULL_KEY);
                }
            } else if (trimMessageButton(message) == POINT) {
                OPTION_POINT = !OPTION_POINT;
                llMessageLinked(LINK_THIS, OPTION_POINT, POINT, NULL_KEY);
            } else if (trimMessageButton(message) == CEILING) {
                OPTION_CEILING = !OPTION_CEILING;
                llMessageLinked(LINK_THIS, OPTION_CEILING, CEILING, NULL_KEY);
            } else {
                sayDebug("listen did not handle "+menuIdentifier+":"+message);
            }
        } else if (channel == POWER_CHANNEL) {
            string trimmed_message = trimMessageParameters(message);
            integer parameter = getMessageParameter(message);
            if (trimmed_message == PING+ACK) {
                add_known_source(name, objectKey, parameter);
            } else if (trimmed_message == CONNECT+ACK) {
                sayDebug("listen powerChannel name:"+name+" message:"+message);
                my_source_key = objectKey;
                my_source_name = name;
                LinksetDataWrite("my_source_key", my_source_key);
                LinksetDataWrite("my_source_name", my_source_name);
                connected = TRUE;
            } else if (trimmed_message == DISCONNECT+ACK) {
                sayDebug("listen powerChannel name:"+name+" message:"+message);
                my_source_key = NULL_KEY;
                my_source_name = NONE;
                LinksetDataWrite("my_source_key", "");
                LinksetDataWrite("my_source_name", NONE);
                connected = FALSE;
                set_power(OFF);
            } else if (trimmed_message == POWER+ACK) {
                sayDebug("listen powerChannel name:"+name+" message:"+message);
                powerAck = getMessageParameter(message);
                if (connected) {
                    sayDebug("listen POWER-ACK sets powerAck to "+(string)powerAck);
                    llMessageLinked(LINK_THIS, powerAck, "powerAck", NULL_KEY);
                } else {
                    sayDebug("listen POWER-ACK not connected");
                    llMessageLinked(LINK_THIS, 0, "powerAck", NULL_KEY);
                }
            } else {
                sayDebug("listen ignored \""+message+"\"");
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
