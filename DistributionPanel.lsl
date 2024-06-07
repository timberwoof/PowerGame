// Power Panel 
// Incremental build-up of Power Dustribution Panel 

integer POWER_CHANNEL = -654647;
integer clock_interval = 1;
float power_sourced = 1000; // how much power we are getting form sources
float power_capacity = 1000; // how much power we can transfer toal

string REQ = "-REQ";
string ACK = "-ACK";
string PING = "Ping";
string CONNECT = "Connect";
string DISCONNECT = "Disconnect";
string POWER = "Power";
string RESET = "Reset";

list device_keys;
list device_names;
list device_draws; // how much power each device wants

integer dialog_channel;
integer dialog_listen;
integer dialog_countdown;

integer DEBUG = TRUE;
sayDebug(string message) {
    if (DEBUG) {
        llSay(0,message);
    }
}

string CLOSE = "Close";
string mainMenu = "Main";
string menuIdentifier;
key menuAgentKey;
integer menuChannel;
integer menuListen;
integer menuTimeout;

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
    list buttons = [RESET, DISCONNECT];
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
    for (i = 0; i < llGetListLength(device_keys); i = i + 1) {
        llSay(0, llList2String(device_names, i) + ": " + (string)llList2Integer(device_draws, i)+" watts");
    }
}

add_device(key objectKey, string objectName) {
    integer e = llListFindList(device_keys, [objectKey]);
    if (e > -1) {
        sayDebug("device "+objectName+" was already in ist");
        device_keys = llDeleteSubList(device_keys, e, e);
        device_names = llDeleteSubList(device_names, e, e);
        device_draws = llDeleteSubList(device_draws, e, e);
    }
    device_keys = device_keys + [objectKey];
    device_names = device_names + [objectName];
    device_draws = device_draws + [0];
    llRegionSayTo(objectKey, POWER_CHANNEL, CONNECT+ACK);
    list_devices();
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
