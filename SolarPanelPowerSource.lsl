// Generic Power Source 
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
string DEBUG = "Debug";

list drain_keys;
list drain_names;
list drain_draws; // how much power each device wants

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

integer power_level = 0; // how much power is actuall being drawn

// These two values can be customized. 
// You can write code that sets these according to some parameter 
// or chnages them depending on the time of day. 
integer power_sourced = 1200; // how much power we are getting from sources
integer power_capacity = 1200; // how much power we can transfer to drains


// Solar Power Panel
rotation previousSunRot = <0,0,0,0>;
string trackmode = "SUN"; // or "CLOCK"
integer photovoltaicFace=1;
integer radiatorFace=3;
vector sun;
integer vertical=TRUE; // vertical ecliptic
integer link_panel = 999;

// *********************************
// Debug

integer debug_state = FALSE;
sayDebug(string message) {
    if (debug_state) {
        llOwnerSay(message);
    }
}

// *********************************
// Menu ane message utilities

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

string trimMessageButton(string message) 
// Remove the menu button prefixes 
{
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

string trimMessageParameters(string message) 
// remove the item in the brackets after an incoming message
{
    string messageTrimmed = message;
    integer whereLBracket = llSubStringIndex(message, "[") -1;
    if (whereLBracket > -1) {
        messageTrimmed = llGetSubString(message, 0, whereLBracket);
    }
    return messageTrimmed;
}

integer getMessageParameter(string message) 
// get the item in the brackets after an incoming message
{
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
    llDialog(avatarKey, message, buttons, menuChannel);
}

resetMenu() 
// Clean up after presenting a user dialog
{
    llListenRemove(menuListen);
    menuListen = 0;
    menuChannel = 0;
    menuAgentKey = "";
}

// ****************************
// Management Menus

presentMainMenu(key whoClicked) {
    string message = "Power Panel Main Menu";
    list buttons = [STATUS, RESET, DISCONNECT];
    setUpMenu(mainMenu, whoClicked, message, buttons);
}

presentDisonnectMenu(key whoClicked) {
    string message = "Select Power Consumer to Disconnect:";
    integer i;
    list buttons = [];
    for (i = 0; i < llGetListLength(drain_names); i = i + 1) {
        message = message + "\n" + (string)i + " " + llList2String(drain_names, i) + " " + llList2String(drain_draws, i) + "W";
        sayDebug("presentDisonnectMnu:"+message);
        buttons = buttons + [(string)i];
    }
    setUpMenu(DISCONNECT, whoClicked, message, buttons);    
}

list_devices() {
    integer i;
    integer num_devices = llGetListLength(drain_keys);
    if (num_devices > 0) {
        for (i = 0; i < num_devices; i = i + 1) {
            llSay(0, llList2String(drain_names, i) + ": " + (string)llList2Integer(drain_draws, i)+" watts");
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

// Ppwer Protocol 

add_drain(key objectKey, string objectName) 
// respond to Connect-REQ message
{
    integer i = llListFindList(drain_keys, [objectKey]);
    if (i > -1) {
        sayDebug("device "+objectName+" was already in list");
        drain_keys = llDeleteSubList(drain_keys, i, i);
        drain_names = llDeleteSubList(drain_names, i, i);
        drain_draws = llDeleteSubList(drain_draws, i, i);
    }
    drain_keys = drain_keys + [objectKey];
    drain_names = drain_names + [objectName];
    drain_draws = drain_draws + [0];
    llRegionSayTo(objectKey, POWER_CHANNEL, CONNECT+ACK+"["+(string)power_capacity+"]");
}

remove_device(key objectKey, string objectName) 
// Respond to Disconnect-REQ message
{
    integer i = llListFindList(drain_keys, [objectKey]);
    if (i > -1) {
        drain_keys = llDeleteSubList(drain_keys, i, i);
        drain_names = llDeleteSubList(drain_names, i, i);
        drain_draws = llDeleteSubList(drain_draws, i, i);        
    }
    llRegionSayTo(objectKey, POWER_CHANNEL, DISCONNECT+ACK);
}

integer calculate_power() 
// Add up the power drawn by all the drains (power distribution panels)
{
    integer power_draw = 0;
    integer i;
    for (i = i; i < llGetListLength(drain_draws); i = i + 1) {
        power_draw = power_draw + llList2Integer(drain_draws, i);
    }
    return power_draw;    
}

cut_all_power() 
// Switch off all outging power. 
// Sends Power-ACK[0] to all drains. 
{
    sayDebug("cut_all_power");
    integer i;
    for (i = i; i < llGetListLength(drain_keys); i = i + 1) {
        key objectKey = llList2Key(drain_keys, i);
        llRegionSayTo(objectKey, POWER_CHANNEL, POWER+ACK+"[0]");
    }    
}

handle_power_request(key objectKey, string objectName, integer powerLevel) 
// Respond to Power-REQ message
{
    sayDebug(objectName+" requests "+(string)powerLevel+" watts");
    integer i;
    integer object_num = -1;
    
    // find the device's index in the list
    object_num = llListFindList(drain_keys, [objectKey]);
    
    // update the bject's power draw
    if (object_num > -1) {
        drain_draws = llListReplaceList(drain_draws, [powerLevel], object_num,object_num);
        power_level = calculate_power();
        if ((power_level > power_sourced) | (power_level > power_capacity)) {
            cut_all_power();
        } else {
            llRegionSayTo(objectKey, POWER_CHANNEL, POWER+ACK+"["+(string)powerLevel+"]");
        }
    } else {
        sayDebug("object was not connected");
        llRegionSayTo(objectKey, POWER_CHANNEL, POWER+ACK+"[0]");
    }
}

// **************************
// Solar Power Panel

integer getLinkWithName(string name) {
    integer i = llGetLinkNumber() != 0;   // Start at zero (single prim) or 1 (two or more prims)
    integer x = llGetNumberOfPrims() + i; // [0, 1) or [1, llGetNumberOfPrims()]
    for (; i < x; ++i)
        if (llGetLinkName(i) == name) 
            return i; // Found it! Exit loop early with result
    return -1; // No prim with that name, return -1.
}


rotation Vec2Rot( vector FWD )
{
    FWD = llVecNorm( FWD );
    vector UP = < 0.0, 1.0, 0.0 >;
    vector LEFT = llVecNorm(UP % FWD);
    if (vertical) FWD = llVecNorm(LEFT % UP);
    else UP = llVecNorm(FWD % LEFT);
    return llAxes2Rot(FWD, LEFT, UP);
}

pointtosun(rotation therot)
{
    llSetLinkPrimitiveParams(link_panel, [PRIM_ROTATION, therot]);
    llSetLinkPrimitiveParams(link_panel, [PRIM_COLOR,photovoltaicFace,<1.0,1.0,1.0>,1.0]);
    llSetLinkPrimitiveParams(link_panel, [PRIM_GLOW,photovoltaicFace,0.2]);
    llSetLinkPrimitiveParams(link_panel, [PRIM_COLOR,radiatorFace,<0.7,0.7,0.7>,1.0]);
    llSetLinkPrimitiveParams(link_panel, [PRIM_GLOW,radiatorFace,0.0]);
}

radiate(rotation therot)
{
    llSetLinkPrimitiveParams(link_panel, [PRIM_ROTATION, therot]);
    llSetLinkPrimitiveParams(link_panel, [PRIM_COLOR,photovoltaicFace,<0.5,0.5,0.5>,1.0]);
    llSetLinkPrimitiveParams(link_panel, [PRIM_GLOW,photovoltaicFace,0.0]);
    llSetLinkPrimitiveParams(link_panel, [PRIM_COLOR,radiatorFace,<0.25,0.0,0.0>,1.0]);
    llSetLinkPrimitiveParams(link_panel, [PRIM_GLOW,radiatorFace,0.2]);
}

track() {
    sayDebug("Track");
    rotation myrot = llGetRot();
    rotation sunRot = llGetRegionSunRotation();

    if (previousSunRot == sunRot) {
        float time = (llGetUnixTime() % 14400) / 14400.0; // (Days)
        sayDebug("time:"+(string)time);
        float hours_per_day = 4.0;
        float Xangle = time  / hours_per_day * 2 * PI; // seconds to hours to raians 
        vector sunEuler = <Xangle, 0, 0>;
        sunRot = llEuler2Rot(sunEuler);
        vector div = sunEuler / myrot;
        sayDebug("myrot:"+(string)myrot+"  div:"+(string)div);
    }
    
    // above  below
    // 
    
    pointtosun(sunRot);
    //if (sunEuler.z > 0.10)
    //{
    //    pointtosun(sunRot);
    //}
    //else
    //{
    //    radiate(sunRot);
    //}
    previousSunRot = llGetRegionSunRotation();
}


default
{
    state_entry()
    {
        sayDebug("state_entry");
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
        
        link_panel = getLinkWithName("panel");
        vector panel_scale = llList2Vector(llGetLinkPrimitiveParams(link_panel, [PRIM_SIZE]),0);
        float area = panel_scale.x * panel_scale.z;
        power_capacity = llFloor(area * 1000);
        sayDebug("state_entry power_capacity:"+(string)power_capacity);
        previousSunRot = llGetRegionSunRotation();
        track();
        llSetTimerEvent(5);
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
                llRegionSayTo(llList2Key(drain_keys, (integer)message), POWER_CHANNEL, DISCONNECT+ACK);
            } else if (trimMessageButton(message) == DEBUG) {
                debug_state = !debug_state;
            } else {
                sayDebug("listen did not handle "+message);
            }
        } else if (channel == POWER_CHANNEL) {
            if (message == PING+REQ) {
                sayDebug("ping req");
                llRegionSayTo(objectKey, POWER_CHANNEL, PING+ACK+"["+(string)power_capacity+"]");
            } else if (message == CONNECT+REQ) {
                sayDebug("connect req");
                add_drain(objectKey, name);
            } else if (message == DISCONNECT+REQ) {
                sayDebug("disconnect req");
                remove_device(objectKey, name);
            } else if (trimMessageParameters(message) == POWER+REQ) {
                sayDebug("power req");
                handle_power_request(objectKey, name, getMessageParameter(message));
            } else {
                sayDebug("did not handle power channel message: "+message);
            }
        }
    }

    timer() {
        integer now = llFloor(llGetTime());
        if (now > menuTimeout) {
            resetMenu();
        }
    
        track();
    }
}
