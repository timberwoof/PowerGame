// Power Panel 
// Incremental build-up of Power Dustribution Panel 

integer POWER_CHANNEL = -654647;
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
string DEBUG = "Debug";

list known_source_keys;
list known_source_names;
list known_source_powers;
integer num_known_sources;

list my_source_keys;
list my_source_names;
list my_source_powers;
integer num_my_sources;
integer power_state;

list drain_keys;
list drain_names;
list drain_powers; // how much power each device wants
integer num_drains;

integer source_rate = 1000; // how much power we are getting from sources
integer power_capacity = 1000; // how much power we can transfer toal
integer power_level = 0;
integer power_ask;
integer power_drain;

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

integer debug_state = TRUE;
sayDebug(string message) {
    if (debug_state) {
        llSay(0,message);
    }
}


// ****************************************
// Menus

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
    
    if (identifier != mainMenu) {
        buttons = buttons + [mainMenu];
    }
    buttons = buttons + [CLOSE];
    
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
    string message = "Power Panel Main Menu";
    list buttons = [];
    buttons = buttons + STATUS;
    buttons = buttons + PING; 
    buttons = buttons + menuButtonActive(CONNECT_SOURCE, num_known_sources > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_SOURCE, num_my_sources > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_DRAIN, num_drains > 0); 
    buttons = buttons + menuButtonActive(menuCheckbox("Power", power_state), num_known_sources > 0);
    buttons = buttons + RESET; // *** might not be a good idea
    buttons = buttons + menuCheckbox(DEBUG, debug_state);
    setUpMenu(mainMenu, whoClicked, message, buttons);
}

// ****************************************
// Power Menus

presentConnectSourceMenu(key whoClicked) {
    string message = "Select Power Distribution Panel to Connect To:";
    integer i;
    list buttons = [];
    for (i = 0; i < num_known_sources; i = i + 1) {
        message = message + "\n" + (string)i + " " + 
            llList2String(known_source_names, i) + " (" + 
            llList2String(known_source_powers, i) + " watts)";
        buttons = buttons + [(string)i];
    }
    setUpMenu(CONNECT_SOURCE, whoClicked, message, buttons);    
}

presentDisonnectSourceMenu(key whoClicked) {
    string message = "Select Power Source to Disconnect:";
    integer i;
    list buttons = [];
    for (i = 0; i < num_my_sources; i = i + 1) {
        message = message + "\n" + (string)i + " " + llList2String(my_source_names, i) + " " + llList2String(my_source_powers, i) + "W";
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
    sayDebug ("ping_req");
    known_source_keys = [];
    known_source_names = [];
    llSay(POWER_CHANNEL, PING+REQ);
}

respond_ping_req(key objectKey) {
    // respond to Ping-REQ
    llRegionSayTo(objectKey, POWER_CHANNEL, PING+ACK+"["+(string)power_capacity+"]");
}

add_known_source(string name, key objectKey, integer power) {
    // respond to Ping-ACK
    sayDebug ("add_known_source:"+name);
    known_source_keys = known_source_keys + [objectKey];
    known_source_names = known_source_names + [name];
    known_source_powers = known_source_powers + [power]; 
    num_known_sources = llGetListLength(known_source_keys);
}

add_source(key objectKey, string objectName, integer source_rate) {
    // respond to Connect-ACK
    sayDebug("add_source:"+objectName+" "+(string)source_rate+" watts");
    if (llListFindList(known_source_keys, [objectKey]) < 0) {
        sayDebug(objectName+" was not known."); // error
        return;
    }
    if (llListFindList(my_source_keys, [objectKey]) >= 0) {
        sayDebug(objectName+" was already connected as a Source."); // warning
        return;
    }
    if (llListFindList(drain_keys, [objectKey]) >= 0) {
        sayDebug(objectName+" was already connected as a Drain."); // warning
        return;
    }
    my_source_keys = my_source_keys + [objectKey];
    my_source_names = my_source_names + [objectName];
    my_source_powers = my_source_powers + source_rate;
    num_my_sources = llGetListLength(my_source_keys);
}

remove_source(key objectKey, string objectName) {
    // Respond to Disonnect-ACK
    integer i = llListFindList(my_source_keys, [objectKey]);
    if (i > -1) {
        my_source_keys = llDeleteSubList(my_source_keys, i, i);
        my_source_names = llDeleteSubList(my_source_names, i, i);
        my_source_powers = llDeleteSubList(my_source_powers, i, i);        
        sayDebug("Source "+objectName+" was disconnected.");
    } else {
        sayDebug("Source "+objectName+" was not connected."); // warning
    }
    num_my_sources = llGetListLength(my_source_keys);
}

add_drain(key objectKey, string objectName) {
    //Respond to Connect-REQ
    if (llListFindList(drain_keys, [objectKey]) > -1) {
        sayDebug(objectName+" was already connecred as a Drain. Reconnecting."); // warning
        llRegionSayTo(objectKey, POWER_CHANNEL, CONNECT+ACK+"["+(string)power_capacity+"]");
        return;
    }
    if (llListFindList(my_source_keys, [objectKey]) > -1) {
        sayDebug(objectName+" was already connecred as a Source."); // warning
        return;
    }
    drain_keys = drain_keys + [objectKey];
    drain_names = drain_names + [objectName];
    drain_powers = drain_powers + [0];
    num_drains = llGetListLength(drain_keys);
    llRegionSayTo(objectKey, POWER_CHANNEL, CONNECT+ACK+"["+(string)power_capacity+"]");
}

remove_drain(key objectKey, string objectName) {
    // respond to Disconnect-REQ
    integer i = llListFindList(drain_keys, [objectKey]);
    if (i > -1) {
        drain_keys = llDeleteSubList(drain_keys, i, i);
        drain_names = llDeleteSubList(drain_names, i, i);
        drain_powers = llDeleteSubList(drain_powers, i, i);        
        sayDebug("Drain "+objectName+" was disconnected."); // waning
    } else {
        sayDebug("Drain "+objectName+" was not connected."); // waning
    }
    num_drains = llGetListLength(drain_keys);
    llRegionSayTo(objectKey, POWER_CHANNEL, DISCONNECT+ACK);
}

handle_power_request(key objectKey, string objectName, integer powerLevel) {
    // Respond to Power-REQ
    sayDebug(objectName+" requests "+(string)powerLevel+" watts");
    integer i;
    integer object_num = -1;
    
    // find the device's index in the list
    object_num = llListFindList(drain_keys, [objectKey]);
    
    // update the bject's power draw
    if (object_num > -1) {
        drain_powers = llListReplaceList(drain_powers, [powerLevel], object_num,object_num);
        power_level = calculate_drain();
        if ((power_level > source_rate) | (power_level > power_capacity)) {
            cut_all_power();
        } else {
            report_power_use();
        }
    } else {
        sayDebug("object was not connected");
        powerLevel = 0;
    }
    llRegionSayTo(objectKey, POWER_CHANNEL, POWER+ACK+"["+(string)powerLevel+"]");
}

handle_power_ack(string message) {
    // Respond to Power-ACK
    power_drain = getMessageParameter(message);
    power_state = (num_known_sources & (power_drain == power_ask));
    sayDebug("listen "+message+" "+(string)power_drain+" results in  power state:"+(string)power_state);
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

report_status() {
    llSay(0,"*****");
    llSay(0,"Device Report for "+llGetObjectName()+":");
    llSay(0,"Maximum Power: "+ (string)power_capacity + " watts");
    llSay(0,"Input Power: "+ (string)source_rate + " watts");
    llSay(0,"Output Power: "+ (string)power_level + " watts");
    list_known_sources();
    list_my_sources();
    list_drains();
    llSay(0,"*****");
}


list_known_sources() {
    llSay(0,"-----");
    llSay(0,"Known Power Sources:");
    integer i;
    if (num_known_sources > 0) {
        for (i = 0; i < num_known_sources; i = i + 1) {
            llSay(0, llList2String(known_source_names, i) + ": " + (string)llList2Integer(known_source_powers, i)+" watts");
        }
    } else {
        llSay(0,"No Power Sources Known. Do Ping");
    }
}

list_my_sources() {
    llSay(0,"-----");
    llSay(0,"Connected Power Sources:");
    integer i;
    if (num_my_sources > 0) {
        for (i = 0; i < num_my_sources; i = i + 1) {
            llSay(0, llList2String(my_source_names, i) + ": " + (string)llList2Integer(my_source_powers, i)+" watts");
        }
    } else {
        llSay(0,"No Power Sources Connected. Connect a power source.");
    }
}

integer calculate_drain() {
    integer power_drain = 0;
    integer i;
    num_drains = llGetListLength(drain_keys);
    for (i = i; i < num_drains; i = i + 1) {
        power_drain = power_drain + llList2Integer(drain_powers, i);
    }
    return power_drain;    
}

list_drains() {
    llSay(0,"-----");
    llSay(0,"Power Drains:");
    integer power_drain = 0;
    integer i;
    num_drains = llGetListLength(drain_keys);
    if (num_drains > 0) {
        for (i = 0; i < num_drains; i = i + 1) {
            power_drain = power_drain + llList2Integer(drain_powers, i);
            llSay(0, llList2String(drain_names, i) + ": " + (string)llList2Integer(drain_powers, i)+" watts");
        }
        llSay(0, "Total Power Drain: "+(string)power_drain);
    } else {
        llSay(0,"No Power Drains Connected.");
    }
}

switch_power() {
    integer i;
    power_state = !power_state;
    if (power_state) {
        for (i = 0; i < num_my_sources; i = i + 1) {
            key source_key = llList2Key(my_source_keys, i);
            integer rate_request = llFloor(source_rate / num_my_sources * 1.1);
            llRegionSayTo(source_key, POWER_CHANNEL, POWER+REQ+"["+(string)rate_request+"]");
        }
        for (i = 0; i < num_drains; i = i + 1) {
            key drain_key = llList2Key(drain_keys, i);
            integer rate = llList2Integer(drain_powers, i);
            llRegionSayTo(drain_key, POWER_CHANNEL, POWER+ACK+"["+(string)rate+"]");
        }
    } else {
        for (i = 0; i < num_drains; i = i + 1) {
            key drain_key = llList2Key(drain_keys, i);
            llRegionSayTo(drain_key, POWER_CHANNEL, POWER+ACK+"[0]");
        }
        for (i = 0; i < num_my_sources; i = i + 1) {
            key source_key = llList2Key(my_source_keys, i);
            llRegionSayTo(source_key, POWER_CHANNEL, POWER+REQ+"[0]");
        }
    }
}

cut_all_power() {
    sayDebug("cut_all_power");
    integer i;
    for (i = i; i < num_drains; i = i + 1) {
        key objectKey = llList2Key(drain_keys, i);
        llRegionSayTo(objectKey, POWER_CHANNEL, POWER+ACK+"[0]");
    }
    // *** report zero power consumption to source
    
}

report_power_use() {
    // distribute the current power use over the sources we have connected
    integer i;
    integer total_source_capacity = 0;
    for (i = 0; i < num_my_sources; i = i + 1) {
        total_source_capacity = total_source_capacity + llList2Integer(my_source_powers, i);
    }
    for (i = 0; i < num_my_sources; i = i + 1) {
        key source_key = llList2Key(my_source_keys, i);
        integer source_rate = llFloor(power_level * llList2Integer(my_source_powers, i) / total_source_capacity * 1.1);
        string source_message = POWER+REQ+"["+(string)source_rate+"]";
        llRegionSayTo(source_key, POWER_CHANNEL, source_message);
    }    
}

default
{
    state_entry()
    {
        sayDebug("state_entry");
        llSetTimerEvent(1);
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
    }

    touch_start(integer total_number)
    {
        //sayDebug("touch_start");
        key whoClicked  = llDetectedKey(0);
        presentMainMenu(whoClicked);
    }
    
    listen( integer channel, string name, key objectKey, string message )
    {
        sayDebug("listen name:"+name+" message:"+message);
        if (channel == menuChannel) {
            resetMenu();
            if (message == CLOSE) {
                sayDebug("listen Close");
            } else if (message == STATUS) {
                report_status();
            } else if (message == RESET) {
                sayDebug("listen Reset");
                llResetScript();
            } else if (message == PING) {
                send_ping_req();
            } else if (message == CONNECT_SOURCE) {
                presentConnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_SOURCE) {
                presentDisonnectSourceMenu(objectKey);
            } else if (message == DISCONNECT_DRAIN) {
                presentDisonnectDrainMenu(objectKey);
            } else if (menuIdentifier == CONNECT_SOURCE) {
                sayDebug("listen CONNECT from "+name+": "+message);
                llRegionSayTo(llList2Key(known_source_keys, (integer)message), POWER_CHANNEL, CONNECT+REQ);
            } else if (menuIdentifier == DISCONNECT_SOURCE) {
                sayDebug("listen DISCONNECT from "+name+": "+message);
                llRegionSayTo(llList2Key(my_source_keys, (integer)message), POWER_CHANNEL, DISCONNECT+REQ);
            } else if (menuIdentifier == DISCONNECT_DRAIN) {
                sayDebug("listen DISCONNECT from "+name+": "+message);
                key drain_key = llList2Key(drain_keys, (integer)message);
                llRegionSayTo(drain_key, POWER_CHANNEL, DISCONNECT+ACK);
                remove_drain(drain_key, name);
            } else if (trimMessageButton(message) == POWER) {
                switch_power();
            } else if (trimMessageButton(message) == DEBUG) {
                debug_state = !debug_state;
            } else {
                sayDebug("listen did not handle "+menuIdentifier+":"+message);
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
                handle_power_ack(message);
            } else {
                sayDebug("did not handle power channel message:"+message);
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
