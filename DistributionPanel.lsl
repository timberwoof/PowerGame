// Power Panel 
// Incremental build-up of Power Dustribution Panel 

integer POWER_CHANNEL = -654647;
integer clock_interval = 1;

string REQ = "-REQ";
string ACK = "-ACK";
string PING = "Ping";
string CONNECT = "Connect";
string DISCONNECT = "Disconnect";
string POWER = "Power";
string RESET = "Reset";
string STATUS = "Status";

list device_keys;
list device_names;
list device_draws; // how much power each device wants
integer power_sourced = 1000; // how much power we are getting from sources
integer power_capacity = 1000; // how much power we can transfer toal
integer power_level = 0;

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

integer DEBUG = TRUE;
sayDebug(string message) {
    if (DEBUG) {
        llSay(0,message);
    }
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
    list buttons = [STATUS, RESET, DISCONNECT];
    setUpMenu(mainMenu, whoClicked, message, buttons);
}

presentDisonnectMenu(key whoClicked) {
    string message = "Select Power Consumer to Disconnect:";
    integer i;
    list buttons = [];
    for (i = 0; i < llGetListLength(device_names); i = i + 1) {
        message = message + "\n" + (string)i + " " + llList2String(device_names, i) + " " + llList2String(device_draws, i) + "W";
        sayDebug("presentDisonnectMnu:"+message);
        buttons = buttons + [(string)i];
    }
    setUpMenu(DISCONNECT, whoClicked, message, buttons);    
}

list_devices() {
    integer i;
    integer num_devices = llGetListLength(device_keys);
    if (num_devices > 0) {
        for (i = 0; i < num_devices; i = i + 1) {
            llSay(0, llList2String(device_names, i) + ": " + (string)llList2Integer(device_draws, i)+" watts");
        }
    } else {
        llSay(0,"No devices connected.");
    }
}

report_status() {
    llSay(0,"Device Report:");
    llSay(0,"Maximum Power: "+ (string)power_capacity + " watts");
    llSay(0,"Input Power: "+ (string)power_sourced + " watts");
    llSay(0,"Output Power: "+ (string)power_level + " watts");
    list_devices();
}

add_device(key objectKey, string objectName) {
    integer i = llListFindList(device_keys, [objectKey]);
    if (i > -1) {
        sayDebug("device "+objectName+" was already in list");
        device_keys = llDeleteSubList(device_keys, i, i);
        device_names = llDeleteSubList(device_names, i, i);
        device_draws = llDeleteSubList(device_draws, i, i);
    }
    device_keys = device_keys + [objectKey];
    device_names = device_names + [objectName];
    device_draws = device_draws + [0];
    llRegionSayTo(objectKey, POWER_CHANNEL, CONNECT+ACK);
    list_devices();
}

remove_device(key objectKey, string objectName) {
    integer i = llListFindList(device_keys, [objectKey]);
    if (i > -1) {
        device_keys = llDeleteSubList(device_keys, i, i);
        device_names = llDeleteSubList(device_names, i, i);
        device_draws = llDeleteSubList(device_draws, i, i);        
    }
    llRegionSayTo(objectKey, POWER_CHANNEL, DISCONNECT+ACK);
}

integer calculate_power() {
    integer power_draw = 0;
    integer i;
    for (i = i; i < llGetListLength(device_draws); i = i + 1) {
        power_draw = power_draw + llList2Integer(device_draws, i);
    }
    return power_draw;    
}

cut_all_power() {
    sayDebug("cut_all_power");
    integer i;
    for (i = i; i < llGetListLength(device_keys); i = i + 1) {
        key objectKey = llList2Key(device_keys, i);
        llRegionSayTo(objectKey, POWER_CHANNEL, POWER+ACK+"[0]");
    }
    // *** report zero power consumption to source
    
}

handle_power_request(key objectKey, string objectName, integer powerLevel) {
    sayDebug(objectName+" requests "+(string)powerLevel+" watts");
    integer i;
    integer object_num = -1;
    
    // find the device's index in the list
    object_num = llListFindList(device_keys, [objectKey]);
    
    // update the bject's power draw
    if (object_num > -1) {
        device_draws = llListReplaceList(device_draws, [powerLevel], object_num,object_num);
        power_level = calculate_power();
        if ((power_level > power_sourced) | (power_level > power_capacity)) {
            cut_all_power();
        } else {
            llRegionSayTo(objectKey, POWER_CHANNEL, POWER+ACK+"["+(string)powerLevel+"]");
            // *** need to report power consumption to source
        }
    } else {
        sayDebug("object was not connected");
        llRegionSayTo(objectKey, POWER_CHANNEL, POWER+ACK+"[0]");
        // *** should send POWER+NACK but that hasn't been defined
    }
    report_status();
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
        sayDebug("touch_start");
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
            } else if (message == DISCONNECT) {
                presentDisonnectMenu(objectKey);
            } else if (menuIdentifier == DISCONNECT) {
                sayDebug("listen DISCONNECT from "+name+": "+message);
                llRegionSayTo(llList2Key(device_keys, (integer)message), POWER_CHANNEL, DISCONNECT+ACK);
            } else {
                sayDebug("listen did not handle "+message);
            }
        } else if (channel == POWER_CHANNEL) {
            if (message == PING+REQ) {
                sayDebug("ping req");
                llRegionSayTo(objectKey, POWER_CHANNEL, PING+ACK);
            } else if (message == CONNECT+REQ) {
                sayDebug("connect req");
                add_device(objectKey, name);
            } else if (message == DISCONNECT+REQ) {
                sayDebug("disconnect req");
                remove_device(objectKey, name);
            } else if (trimMessageParameters(message) == POWER+REQ) {
                sayDebug("power req");
                handle_power_request(objectKey, name, getMessageParameter(message));
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
