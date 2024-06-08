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
string POWER = "Power";
string RESET = "Reset";
string NONE = "None";
string DEBUG = "Debug";
integer ON = TRUE;
integer OFF = FALSE;

list power_panel_keys;
list power_panel_names;
key my_power_panel_key;
string my_power_panel_name;
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
    string message = "Lamp Main Menu";
    list buttons = [];
    buttons = buttons + menuButtonActive(PING, !connected); 
    if (connected) {
        buttons = buttons + DISCONNECT; 
    } else {
        buttons = buttons + CONNECT; 
    }
    buttons = buttons + menuButtonActive(menuCheckbox("Power", power_state), connected);
    buttons = buttons + STATUS;
    buttons = buttons + menuButtonActive(RESET, !connected);
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

ping_req() {
    sayDebug ("ping_req");
    power_panel_keys = [];
    power_panel_names = [];
    llSay(POWER_CHANNEL, PING+REQ);
}

ping_ack(string name, key objectKey) {
    sayDebug ("ping_ack");
    power_panel_keys = power_panel_keys + [objectKey];
    power_panel_names = power_panel_names + [name];
}

presentConnectMenu(key whoClicked) {
    string message = "Select Power Distribution Panel to Connect To:";
    integer i;
    list buttons = [];
    for (i = 0; i < llGetListLength(power_panel_names); i = i + 1) {
        message = message + "\n" + (string)i + " " + llList2String(power_panel_names, i);
        sayDebug("presentConenctMenu:"+message);
        buttons = buttons + [(string)i];
    }
    setUpMenu(CONNECT, whoClicked, message, buttons);    
}

string power_state_to_string(integer power_state) {
    if (power_state) {
        return "On";
    } else {
        return "Off";
    }
}

report_status() {
    llSay(0,"Power: "+power_state_to_string(power_state)+". Consuming "+(string)power_draw+" watts from power source "+my_power_panel_name+".");
}

switch_power() {
    if (power_state) {
        llRegionSayTo(my_power_panel_key, POWER_CHANNEL, POWER+REQ+"[0]");
    } else {
        llRegionSayTo(my_power_panel_key, POWER_CHANNEL, POWER+REQ+"["+(string)power_ask+"]");
    }
}

default
{
    state_entry()
    {
        sayDebug("state_entry");
        llSetTimerEvent(1);
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
        my_power_panel_key = NULL_KEY;
        my_power_panel_name = NONE;
        power_state = OFF;
        connected = FALSE;
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
                ping_req();
            } else if (message == CONNECT) {
                presentConnectMenu(objectKey);
            } else if (message == DISCONNECT) {
                sayDebug("listen DISCONNECT from "+name+": "+message);
                llRegionSayTo(llList2Key(power_panel_keys, (integer)message), POWER_CHANNEL, DISCONNECT+REQ);
            } else if (menuIdentifier == CONNECT) {
                sayDebug("listen CONNECT from "+name+": "+message);
                llRegionSayTo(llList2Key(power_panel_keys, (integer)message), POWER_CHANNEL, CONNECT+REQ);
            } else if (trimMessageButton(message) == POWER) {
                switch_power();
            } else if (trimMessageButton(message) == DEBUG) {
                debug_state = !debug_state;
            } else {
                sayDebug("listen did not handle "+message);
            }
        } else if (channel == POWER_CHANNEL) {
            if (message == PING+ACK) {
                ping_ack(name, objectKey);
            } else if (message == CONNECT+ACK) {
                my_power_panel_key = objectKey;
                my_power_panel_name = name;
                connected = TRUE;
            } else if (message == DISCONNECT+ACK) {
                my_power_panel_key = NULL_KEY;
                my_power_panel_name = NONE;
                connected = FALSE;
            } else if (trimMessageParameters(message) == POWER+ACK) {
                power_draw = getMessageParameter(message);
                power_state = (connected & (power_draw == power_ask));
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
