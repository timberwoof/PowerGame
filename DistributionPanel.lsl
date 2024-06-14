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
list known_source_power_capacities;
integer num_known_sources;

list my_source_keys;
list my_source_names;
list my_source_power_capacities;
list my_source_power_supplies;
integer num_my_sources;
integer my_source_power_capacity = 0;
integer my_source_power_rate = 0; // how much power we are getting from sources
integer power_state;

list drain_keys;
list drain_names;
list drain_powers; // how much power each device wants
integer num_drains;
integer power_drain;

integer power_capacity = 10000000; // 10MW how much power we can transfer total

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

string kill_switch_1 = "4690245e-a161-87ce-e392-47e2a410d981";
string kill_switch_2 = "00800a8c-1ac2-ff0a-eed5-c1e37fef2317";

integer debug_state = FALSE;
sayDebug(string message) {
    if (debug_state) {
        llSay(0, message);
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
    string message = "Power Panel Main Menu";
    list buttons = [];
    buttons = buttons + STATUS;
    buttons = buttons + PING; 
    buttons = buttons + RESET; // *** might not be a good idea
    buttons = buttons + menuButtonActive(CONNECT_SOURCE, num_known_sources > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_SOURCE, num_my_sources > 0);
    buttons = buttons + menuButtonActive(DISCONNECT_DRAIN, num_drains > 0); 
    buttons = buttons + menuButtonActive(menuCheckbox("Power", power_state), num_known_sources > 0);
    buttons = buttons + menuCheckbox(DEBUG, debug_state);
    setUpMenu(mainMenu, whoClicked, message, buttons);
}

// ****************************************
// Power Menus

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


presentConnectSourceMenu(key whoClicked) {
    string message = "Select Power Distribution Panel to Connect To:";
    integer i;
    // list all the sources in distance order
    vector myPos = llGetPos();
    list sources;
    for (i = 0; i < num_known_sources & i <= 10; i = i + 1) {
        string source_name = llList2String(known_source_names, i);
        integer source_capacity = llList2Integer(known_source_power_capacities, i);
        key source_key = llList2Key(known_source_keys, i);
        list source_details = llGetObjectDetails(source_key, [OBJECT_POS]);    
        vector source_position = llList2Vector(source_details, 0);
        float source_distance = llVecDist(myPos, source_position);
        sources = sources + [source_name, source_capacity, source_distance];
    }
    
    // sort by distance, nearest first
    sources = llListSortStrided(sources, 3, 2, TRUE);
    
    // Set up the list in that order
    list buttons = [];
    string source_list = "Select from these sources:";
    integer source_list_length = llStringLength(source_list);
    for (i = 0; i < num_known_sources & i < 10; i = i + 1) {
        string source_name = llList2String(sources, i*3);
        integer source_capacity = llList2Integer(sources, i*3+1);
        integer source_distance = llFloor(llList2Float(sources, i*3+2));
        string item = (string)i + ": " + source_name + " (" + EngFormat(source_capacity) + ") " + (string)source_distance + "m";
        sayDebug(item);
        integer item_length = llStringLength(item);
        if (source_list_length + item_length <= 512) {
            source_list = source_list + "\n" + item;
            integer source_list_length = llStringLength(source_list);
            buttons = buttons + [(string)i];
        }
    }
    llInstantMessage(whoClicked, source_list);
    setUpMenu(CONNECT_SOURCE, whoClicked, source_list, buttons);    
}

presentDisonnectSourceMenu(key whoClicked) {
    string message = "Select Power Source to Disconnect:";
    integer i;
    list buttons = [];
    for (i = 0; i < num_my_sources; i = i + 1) {
        message = message + "\n" + (string)i + " " + llList2String(my_source_names, i) + " " + llList2String(my_source_power_capacities, i) + "W";
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
    llShout(POWER_CHANNEL, PING+REQ);
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
    known_source_power_capacities = known_source_power_capacities + [power]; 
    num_known_sources = llGetListLength(known_source_keys);
}

calculate_power_capacity() {
    num_my_sources = llGetListLength(my_source_keys);
    my_source_power_capacity = 0;
    integer i;
    for (i = i; i < num_my_sources; i = i + 1) {
        my_source_power_capacity = my_source_power_capacity + llList2Integer(my_source_power_capacities, i);
    }
    sayDebug("calculate_power_capacity:"+(string)my_source_power_capacity);
}

add_source(key objectKey, string objectName, integer source_rate) {
    // respond to Connect-ACK
    sayDebug("add_source:"+objectName+" "+EngFormat(source_rate));
    llPlaySound(kill_switch_1, 1);

    // Handle bad requests
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
    
    // register the source
    my_source_keys = my_source_keys + [objectKey];
    my_source_names = my_source_names + [objectName];
    my_source_power_capacities = my_source_power_capacities + source_rate;
    calculate_power_capacity();
}

remove_source(key objectKey, string objectName) {
    // Respond to Disonnect-ACK
    llPlaySound(kill_switch_1, 1);
    integer i = llListFindList(my_source_keys, [objectKey]);
    if (i > -1) {
        my_source_keys = llDeleteSubList(my_source_keys, i, i);
        my_source_names = llDeleteSubList(my_source_names, i, i);
        my_source_power_capacities = llDeleteSubList(my_source_power_capacities, i, i);        
        sayDebug("Source "+objectName+" was disconnected.");
    } else {
        sayDebug("Source "+objectName+" was not connected."); // warning
    }
    calculate_power_capacity();
}

add_drain(key objectKey, string objectName) {
    //Respond to Connect-REQ
    llPlaySound(kill_switch_1, 1);
    if (llListFindList(drain_keys, [objectKey]) > -1) {
        sayDebug(objectName+" was already connecred as a Drain. Reconnecting."); // warning
        llRegionSayTo(objectKey, POWER_CHANNEL, CONNECT+ACK+"["+EngFormat(power_capacity)+"]");
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
    llRegionSayTo(objectKey, POWER_CHANNEL, CONNECT+ACK+"["+EngFormat(power_capacity)+"]");
}

remove_drain(key objectKey, string objectName) {
    // respond to Disconnect-REQ
    llPlaySound(kill_switch_1, 1);
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
    sayDebug(objectName+" requests "+EngFormat(powerLevel));
    integer i;
    integer drain_num = -1;
    
    // find the drain's index in the list
    drain_num = llListFindList(drain_keys, [objectKey]);
    
    // update the drain's power draw
    if (drain_num > -1) {
        drain_powers = llListReplaceList(drain_powers, [powerLevel], drain_num, drain_num);
        
        // reclaculate total power drain
        power_drain = 0;
        integer i;
        num_drains = llGetListLength(drain_keys);
        for (i = i; i < num_drains; i = i + 1) {
            power_drain = power_drain + llList2Integer(drain_powers, i);
        }
        
        request_power();
    } else {
        sayDebug("object was not connected");
        powerLevel = 0;
    }
    
    if (!power_state) {
        sayDebug("power was off");
        powerLevel = 0;
    }
    llRegionSayTo(objectKey, POWER_CHANNEL, POWER+ACK+"["+(string)powerLevel+"]");
}

handle_power_ack(key source_key, string source_name, integer source_power) {
    sayDebug(source_name+" supplies "+EngFormat(source_power));
    integer object_num = llListFindList(my_source_keys, [source_key]);
    if (object_num < 0) {
        sayDebug(source_name+" was not in list of sources."); // error
        return;
    }
    my_source_power_supplies = llListReplaceList(my_source_power_supplies, [source_power], object_num, object_num);
    
    // reclaculate total power drain
    my_source_power_rate = 0;
    integer i;
    num_my_sources = llGetListLength(my_source_keys);
    for (i = i; i < num_my_sources; i = i + 1) {
        my_source_power_rate = my_source_power_rate + llList2Integer(my_source_power_supplies, i);
    }
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

list_known_sources(key operator) {
    string result;
    result = result + "\n" +  "Known Power Sources:";
    integer i;
    if (num_known_sources > 0) {
        for (i = 0; i < num_known_sources; i = i + 1) {
            result = result + "\n" +   llList2String(known_source_names, i) + ": " + EngFormat(llList2Integer(known_source_power_capacities, i));
        }
    } else {
        result = result + "\n" +  "No Power Sources Known. Do Ping";
    }
    llInstantMessage(operator, result);
}

list_my_sources(key operator) {
    string result;
    result = result + "\n" +  "Connected Power Sources:";
    integer i;
    if (num_my_sources > 0) {
        for (i = 0; i < num_my_sources; i = i + 1) {
            integer capacity = llList2Integer(my_source_power_capacities, i);
            integer supply = llList2Integer(my_source_power_supplies, i);
            result = result + "\n" +   llList2String(my_source_names, i) + " supplying " +  EngFormat(supply)+" of " + EngFormat(capacity) + "max";
        }
    } else {
        result = result + "\n" +  "No Power Sources Connected. Connect a power source.";
    }
    result = result + "\n" +   "Supply: "+EngFormat(my_source_power_rate)+" of "+EngFormat(my_source_power_capacity)+" maximum";
    llInstantMessage(operator, result);
}

list_drains(key operator) {
    string result;
    result = result + "\n" +  "Power Drains:";
    integer power_drain = 0;
    integer i;
    num_drains = llGetListLength(drain_keys);
    if (num_drains > 0) {
        for (i = 0; i < num_drains; i = i + 1) {
            power_drain = power_drain + llList2Integer(drain_powers, i);
            result = result + "\n" +   llList2String(drain_names, i) + ": " + EngFormat(llList2Integer(drain_powers, i));
        }
        result = result + "\n" +   "Total Power Drain: "+(string)power_drain;
    } else {
        result = result + "\n" +  "No Power Drains Connected.";
    }
    llInstantMessage(operator, result);
}

report_status(key operator) {
    string result;
    result = result + "\n" +  "Device Report for "+llGetObjectName()+":";
    result = result + "\n" +  "Maximum Power: "+ EngFormat(power_capacity);
    result = result + "\n" +  "Input Power: "+ EngFormat(my_source_power_rate);
    result = result + "\n" +  "Output Power: "+ EngFormat(power_drain);
    llInstantMessage(operator, result);
    list_known_sources(operator);
    list_my_sources(operator);
    list_drains(operator);
}

switch_power(integer new_power_state) {
    sayDebug("switch_power "+(string)new_power_state);
    llPlaySound(kill_switch_1, 1);
    power_state = new_power_state;
    integer i;
    if (power_state) {
        // switch on
        // request power from sourcs
        request_power();
        // grant power to drains
        for (i = 0; i < num_drains; i = i + 1) {
            key drain_key = llList2Key(drain_keys, i);
            integer rate = llList2Integer(drain_powers, i);
            llRegionSayTo(drain_key, POWER_CHANNEL, POWER+ACK+"["+(string)rate+"]");
        }
    } else {
        // cut power to all the drains
        for (i = 0; i < num_drains; i = i + 1) {
            key drain_key = llList2Key(drain_keys, i);
            llRegionSayTo(drain_key, POWER_CHANNEL, POWER+ACK+"[0]");
        }
        // cut power from all the sources
        for (i = 0; i < num_my_sources; i = i + 1) {
            key source_key = llList2Key(my_source_keys, i);
            llRegionSayTo(source_key, POWER_CHANNEL, POWER+REQ+"[0]");
        }
    }
}

toggle_power() {
    switch_power(!power_state);
}

monitor_power() {
    integer cut = FALSE;
    integer i;
    power_drain = 0;
    for (i = 0; i < num_drains; i = i + 1) {
        power_drain = power_drain + llList2Integer(drain_powers, i);
        sayDebug(llList2String(drain_names, i) + ": " + EngFormat(llList2Integer(drain_powers, i)));
    }

    if (power_drain > my_source_power_rate) {
        sayDebug("power_drain:"+EngFormat(power_drain)+" > my_source_power_rate:"+EngFormat(my_source_power_rate));
        cut = TRUE;
    }

    if (power_drain > my_source_power_capacity) {
        sayDebug("power_drain:"+EngFormat(power_drain)+" > my_source_power_capacity:"+EngFormat(my_source_power_capacity));
        cut = TRUE;
    }

    if (cut) {
        switch_power(FALSE);
    }
    
}

request_power() {
    // distribute the current power use over the sources we have connected
    sayDebug("request_power");
    integer i;
    
    // Gather up the power capacity of connected sources
    integer total_source_capacity = 0;
    for (i = 0; i < num_my_sources; i = i + 1) {
        total_source_capacity = total_source_capacity + llList2Integer(my_source_power_capacities, i);
    }
    sayDebug("request_power total_source_capacity:"+(string)total_source_capacity);
    
    // Distribute required power_drain evenly over the connected sources
    for (i = 0; i < num_my_sources; i = i + 1) {
        key source_key = llList2Key(my_source_keys, i);
        integer source_rate = llFloor(power_drain * llList2Integer(my_source_power_capacities, i) / total_source_capacity * 1.1);
        string source_name = llList2String(my_source_names, i);
        string source_message = POWER+REQ+"["+(string)source_rate+"]";
        sayDebug("request_power requesting "+(string)source_rate+" from "+source_name+"   "+source_message);
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
        send_ping_req();
        llSetTimerEvent(10);
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
                report_status(objectKey);
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
                toggle_power();
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
                handle_power_ack(objectKey, name, parameter);
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
        monitor_power();
    }
}
