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
string POWER = "Power";
string RESET = "Reset";

list devices;
list power_draws; // how much power each device wants

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
    list buttons = [RESET];
    setUpMenu(mainMenu, whoClicked, message, buttons);
}


default
{
    state_entry()
    {
        sayDebug("state_entry");
        llSetTimerEvent(1);
    }

    touch_start(integer total_number)
    {
        sayDebug("touch_start");
        key whoClicked  = llDetectedKey(0);
        presentMainMenu(whoClicked);
    }
    
    listen( integer channel, string name, key avatarKey, string message )
    {
        sayDebug("listen name:"+name+" message:"+message);
        if (message == CLOSE) {
            sayDebug("listen Close");
        } else if (message == RESET) {
            sayDebug("listen Reset");
            llResetScript();
        } else {
            sayDebug("listen did not handle "+message);
        }
    }

    timer() {
        integer now = llFloor(llGetTime());
        if (now > menuTimeout) {
            resetMenu();
        }
    }
}
